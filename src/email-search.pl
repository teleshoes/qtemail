#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(time);

sub usage();
sub updateDb($$$);
sub createDb($$);
sub runSql($$$);
sub fetchHeaderRowMap($$$);
sub rowMapToInsert($);
sub getAllUids($$);
sub getCachedUids($$);

sub search($$$);
sub buildQuery($);
sub prettyPrintQueryStr($);
sub formatQuery($;$);
sub parseQueryStr($);
sub parseFlatQueryStr($);
sub escapeQueryStr($$);
sub unescapeQueryStr($$);
sub unescapeQuery($$);
sub reduceQuery($);

my $emailDir = "$ENV{HOME}/.cache/email";

my $emailTable = "email";
my @headerFields = qw(
  date
  from
  subject
  to
  raw_date
  raw_from
  raw_subject
  raw_to
);
my @cols = ("uid", map {"header_$_"} @headerFields);
my @colTypes = ("uid number", map {"header_$_ varchar"} @headerFields);
my $dbChunkSize = 100;

my $usageFormat = "Usage:
  $0 --updatedb ACCOUNT_NAME FOLDER_NAME LIMIT
    create sqlite database if it doesnt exist
    updates database incrementally

    LIMIT
      maximum number of headers to update at once
      can be 'all' or a positive integer

  $0 --search [--folder=FOLDER_NAME] ACCOUNT_NAME QUERY [QUERY QUERY..]
    print UIDs of emails matching \"QUERY QUERY QUERY\"

    SEARCH FORMAT:
      -all words separated by spaces must match one of subject/date/from/to
        apple banana
        => emails where subject/from/to/date matches both 'apple' AND 'banana'
      -you can specify an individual field of subject/date/from/to like this:
        from~mary
        => emails from 'mary'
      -you can specify that the body must match like this:
        body~bus
        => emails where the cached body matches 'bus'
      -you can specify disjunction with '++'
        from~mary ++ from~john ++ from~sue
        => emails from 'mary' PLUS emails from 'john' PLUS emails from 'sue'
      -you can group space or ++ separated words with parantheses
        (from~mary a) ++ (from~john b)
        => emails from 'mary' that match 'a' PLUS emails from 'john' that match 'b'
      -parantheses can nest arbitrarily deep
        (a ++ (b (c ++ d)))
        => emails that match 'a', PLUS emails that match 'b' AND match 'c' or 'd'
      -special characters can be escaped with backslash
        subject\\~fish\\ table
        => emails where subject/from/to/date matches 'subject~fish table'
      -doublequoted strings are treated as words
        \"this is a (single ++ w~ord)\"
        => emails where subject/from/to/date matches 'this is a (single ++ w~ord)'

    EXAMPLES:
      =====\n%s
";

sub main(@){
  my $cmd = shift;
  die usage() if not defined $cmd;
  if($cmd =~ /^(--updatedb)$/ and @_ == 3){
    my ($accName, $folderName, $limit) = @_;
    die usage() if $limit !~ /^(all|[1-9]\d+)$/;
    updateDb($accName, $folderName, $limit);
  }elsif($cmd =~ /^(--search)$/ and @_ >= 2){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my $accName = shift;
    die usage() if @_ == 0 or not defined $accName;
    my $query = "@_";
    my @uids = search $accName, $folderName, $query;
    print (map { "$_\n" } @uids);
  }else{
    die usage();
  }
}

sub usage(){
  my $examples = join '', map {prettyPrintQueryStr $_} (
    'from~mary',
    'mary smith',
    '((a b) ++ (c d) ++ (e f))',
    'subject~b ++ "subject~b"',
    '"a ++ b"',
  );
  return sprintf $usageFormat, $examples;
}

sub updateDb($$$){
  my ($accName, $folderName, $limit) = @_;
  my $db = "$emailDir/$accName/$folderName/db";
  if(not -f $db){
    createDb $accName, $folderName;
  }
  die "missing database $db\n" if not -f $db;

  my @cachedUids = getCachedUids $accName, $folderName;
  my $cachedUidsCount = @cachedUids;

  my @allUids = getAllUids $accName, $folderName;
  my $allUidsCount = @allUids;

  my %isCachedUid = map {$_ => 1} @cachedUids;
  my @uncachedUids = reverse grep {not defined $isCachedUid{$_}} @allUids;
  my $uncachedUidsCount = @uncachedUids;

  $limit = $uncachedUidsCount if $limit =~ /^(all)$/;

  my @uidsToAdd = @uncachedUids;
  @uidsToAdd = @uidsToAdd[0 .. $limit-1] if @uidsToAdd > $limit;
  my $uidsToAddCount = @uidsToAdd;

  my $limitUidsToAddCount = @uidsToAdd;
  print "updatedb:"
    . " all:$allUidsCount"
    . " cached:$cachedUidsCount"
    . " uncached:$uncachedUidsCount"
    . " adding:$uidsToAddCount"
    . "\n";

  if($uidsToAddCount == 0){
    print "no UIDs to add\n";
    return;
  }

  my $msgChunk = int($uidsToAddCount/50);
  $msgChunk = 5 if $msgChunk < 5;

  my $count = 0;
  my @curInserts;
  for my $uid(@uidsToAdd){
    if($count % $msgChunk == 0 or $count == 0 or $count == $uidsToAddCount-1){
      my $pct = sprintf "%d", $count/$uidsToAddCount*100;
      print " $pct%";
    }
    my $rowMap = fetchHeaderRowMap $accName, $folderName, $uid;
    my $insert = rowMapToInsert $rowMap;
    push @curInserts, $insert;
    if(@curInserts >= $dbChunkSize){
      runSql $accName, $folderName, join ";\n", @curInserts;
      @curInserts = ();
    }
    $count++;
  }
  print "\n";
  if(@curInserts > 0){
    runSql $accName, $folderName, join ";\n", @curInserts;
    @curInserts = ();
  }
}

sub createDb($$){
  my ($accName, $folderName) = @_;
  my $db = "$emailDir/$accName/$folderName/db";
  die "database already exists $db\n" if -e $db;
  runSql $accName, $folderName,
    "create table $emailTable (" . join(", ", @colTypes) . ")";
}

sub runSql($$$){
  my ($accName, $folderName, $sql) = @_;
  my $db = "$emailDir/$accName/$folderName/db";

  $sql =~ s/\s*;\s*\n*$//;
  $sql = "$sql;\n";

  my $nowMillis = int(time*1000);
  my $tmpSqlFile = "/tmp/email-$accName-$folderName-$nowMillis.sql";
  open TMPFH, "> $tmpSqlFile";
  print TMPFH $sql;
  close TMPFH;

  my @cmd = ("sqlite3", $db, ".read $tmpSqlFile");
  open SQLITECMD, "-|", @cmd;
  my @lines = <SQLITECMD>;
  close SQLITECMD;
  die "error running @cmd\n" if $? != 0;

  system "rm", $tmpSqlFile;

  return join '', @lines;
}

sub fetchHeaderRowMap($$$){
  my ($accName, $folderName, $uid) = @_;
  my $hdr = `cat $emailDir/$accName/$folderName/headers/$uid`;
  my $rowMap = {};
  $$rowMap{"uid"} = $uid;
  for my $field(@headerFields){
    my $val = $1 if $hdr =~ /^$field:\s*(.*)$/im;
    $val =~ s/'/''/g;
    $val =~ s/\x00//g;
    $val =~ s/[\r\n]/ /g;
    $val = "'$val'";

    my $col = "header_$field";
    $$rowMap{$col} = $val;
  }
  return $rowMap;
}

sub rowMapToInsert($){
  my ($rowMap) = @_;

  my @cols = sort keys %$rowMap;
  my @vals = (map {$$rowMap{$_}} sort keys %$rowMap);
  return ""
    . "insert into $emailTable"
    . " (" . join(',', @cols) . ")"
    . " values(" . join(',', @vals) . ")"
    . ";"
    ;
}

sub getAllUids($$){
  my ($accName, $folderName) = @_;
  my $file = "$emailDir/$accName/$folderName/all";

  return () if not -f $file;

  my @uids = `cat "$file"`;
  chomp foreach @uids;
  return @uids;
}

sub getCachedUids($$){
  my ($accName, $folderName) = @_;
  my $output = runSql $accName, $folderName, "select uid from $emailTable";
  my @uids = split /\n/, $output;
  return @uids;
}


sub search($$$){
  my ($accName, $folderName, $queryStr) = @_;
  if($queryStr =~ /^\s*$/){
    return ();
  }
  my $query = buildQuery $queryStr;

  my @allUids = getAllUids $accName, $folderName;
  return @uids;
}

sub buildQuery($){
  my ($queryStr) = @_;
  my $quotes = {};
  $queryStr = escapeQueryStr $queryStr, $quotes;

  my $query = parseQueryStr $queryStr;
  $query = unescapeQuery $query, $quotes;
  $query = reduceQuery $query;
  return $query;
}

sub prettyPrintQueryStr($){
  my ($queryStr) = @_;
  my $indent = "      ";
  my $query = buildQuery $queryStr;
  my $fmt = "$indent$queryStr\n";
  $fmt .= formatQuery $query, $indent . "  ";
  $fmt .= "$indent=====\n";
  return $fmt;
}

sub formatQuery($;$){
  my ($query, $indent) = @_;
  $indent = "" if not defined $indent;
  my $fmt = "";

  my $noDashIndent = $indent;
  $noDashIndent =~ s/-/ /g;

  my $type = $$query{type};
  if($type =~ /and|or/){
    my $typeFmt = $type eq "and" ? "ALL" : "ANY";
    my $typeFmtSpacer = ' ' x length($typeFmt);
    my @parts = @{$$query{parts}};
    $fmt .= "$indent$typeFmt(\n";
    my $newIndent = $noDashIndent . $typeFmtSpacer . "|--";
    for my $part(@parts){
      $fmt .= formatQuery $part, $newIndent;
    }
    $fmt .= $noDashIndent . "$typeFmtSpacer)\n";
  }elsif($$query{type} =~ /header/){
    my $content = $$query{content};
    my @fields = @{$$query{fields}};
    $fmt .= $indent . "[@fields] LIKE $$query{content}\n";
  }elsif($$query{type} =~ /body/){
    my $content = $$query{content};
    $fmt .= $indent . "[body] LIKE $$query{content}\n";
  }
  return $fmt;
}

sub parseQueryStr($){
  my ($queryStr) = @_;

  if($queryStr !~ /\(.*\)/){
    return parseFlatQueryStr $queryStr;
  }

  my @orGroups;
  my @parensGroups;
  my $cur = "";
  my $parens = 0;
  for my $ch(split //, $queryStr){
    if($ch eq "("){
      if($parens == 0){
        push @parensGroups, $cur;
        $cur = "";
      }else{
        $cur .= $ch;
      }
      $parens++;
    }elsif($ch eq ")"){
      $parens--;
      if($parens == 0){
        push @parensGroups, $cur;
        $cur = "";
      }else{
        $cur .= $ch;
      }
      $parens = 0 if $parens < 0; #ignore unmatched ')'
    }elsif($ch eq "+"){
      if($parens == 0){
        push @parensGroups, $cur;
        $cur = "";
        push @orGroups, [@parensGroups];
        @parensGroups = ();
      }else{
        $cur .= $ch;
      }
    }else{
      $cur .= $ch;
    }
  }
  push @parensGroups, $cur; #ignore unmatched '('
  push @orGroups, [@parensGroups];

  my $outerQuery = {type => "or", parts => []};
  for my $orGroup(@orGroups){
    next if @$orGroup == 0;
    my $innerQuery = {type => "and", parts => []};
    for my $parensGroup(@$orGroup){
      next if length $parensGroup == 0;
      push @{$$innerQuery{parts}}, parseQueryStr $parensGroup;
    }
    push @{$$outerQuery{parts}}, $innerQuery;
  }

  return $outerQuery;
}

sub parseFlatQueryStr($){
  my $flatQueryStr = shift;
  my @ors = split /\+/, $flatQueryStr;
  my $outerQuery = {type => "or", parts=>[]};
  for my $or(@ors){
    my $innerQuery = {type => "and", parts=>[]};
    my @ands = split /\s+/, $or;
    for my $and(@ands){
      my $type;
      my @fields;
      my $content;
      if($and =~ /(to|from|subject)~(.*)/i){
        $type = "header";
        @fields = (lc $1);
        $content = $2;
      }elsif($and =~ /(body)~(.*)/i){
        $type = "body";
        @fields = ();
        $content = $2;
      }else{
        $type = "header";
        @fields = qw(to from subject);
        $content = $and;
      }
      push @{$$innerQuery{parts}}, {
        type => $type,
        fields => [@fields],
        content => $content,
      };
    }
    push @{$$outerQuery{parts}}, $innerQuery;
  }
  return $outerQuery;
}

sub escapeQueryStr($$){
  my ($queryStr, $quotes) = @_;
  $queryStr =~ s/[\t\n\r]/ /g;
  $queryStr =~ s/%/%boing%/g;
  $queryStr =~ s/\\ /%ws%/g;
  $queryStr =~ s/\\\+/%plus%/g;
  $queryStr =~ s/\\~/%tilde%/g;
  $queryStr =~ s/\\"/%dblquote%/g;

  my %quotes;
  my $quoteId = 0;
  while($queryStr =~ s/"([^"]*)"/%quote$quoteId%/){
    $$quotes{"quote$quoteId"} = $1;
    $quoteId++;
  }

  $queryStr =~ s/\+\+/%or%/g;
  $queryStr =~ s/\+/%plus%/g;
  $queryStr =~ s/%or%/+/g;

  return $queryStr;
}
sub unescapeQueryStr($$){
  my ($queryStr, $quotes) = @_;
  $queryStr =~ s/%(quote\d+)%/$$quotes{$1}/g;

  $queryStr =~ s/%dblquote%/"/g;
  $queryStr =~ s/%tilde%/~/g;
  $queryStr =~ s/%plus%/+/g;
  $queryStr =~ s/%ws%/ /g;
  $queryStr =~ s/%boing%/%/g;

  return $queryStr;
}

sub unescapeQuery($$){
  my ($query, $quotes) = @_;
  my $type = $$query{type};
  if($type =~ /^(and|or)$/){
    my @parts = @{$$query{parts}};
    @parts = map {unescapeQuery $_, $quotes} @parts;
    $$query{parts} = [@parts];
  }elsif($type =~ /^(header|body)$/){
    $$query{content} = unescapeQueryStr $$query{content}, $quotes;
  }else{
    die "unknown type: $type\n";
  }
  return $query;
}

sub reduceQuery($){
  my ($query) = @_;

  my $type = $$query{type};
  if($type =~ /and|or/){
    my @parts = @{$$query{parts}};
    @parts = map {reduceQuery $_} @parts;
    @parts = grep {defined $_} @parts;

    # a OR (b OR c) == a OR b OR c
    my @newParts;
    for my $part(@parts){
      my $partType = $$part{type};
      if($partType eq $type){
        my @partParts = @{$$part{parts}};
        @partParts = map {reduceQuery $_} @partParts;
        @partParts = grep {defined $_} @partParts;
        @newParts = (@newParts, @partParts);
      }else{
        push @newParts, $part;
      }
    }
    @parts = @newParts;

    if(@parts == 0){
      return undef;
    }elsif(@parts == 1){
      return $parts[0];
    }else{
      return {type => $type, parts => [@parts]};
    }
  }elsif($type =~ /^(header|body)$/){
    my $content = $$query{content};
    my @fields = @{$$query{fields}};
    if($content =~ /^\s*$/){
      return undef;
    }else{
      return {type => $type, fields => [@fields], content => $content};
    }
  }else{
    die "unknown type: $type\n";
  }
}

&main(@ARGV);
