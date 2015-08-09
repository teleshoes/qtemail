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

sub search($$$$$);
sub buildQuery($);
sub prettyPrintQueryStr($;$);
sub formatQuery($;$);
sub parseQueryStr($);
sub parseFlatQueryStr($);
sub escapeQueryStr($$);
sub unescapeQueryStr($$);
sub unescapeQuery($$);
sub reduceQuery($);
sub runQuery($$$@);

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

  $0 --format WORD [WORD WORD..]
    parse and format QUERY=\"WORD WORD WORD\" for testing

  $0 --search [OPTIONS] ACCOUNT_NAME WORD [WORD WORD..]
    print UIDs of emails matching QUERY=\"WORD WORD WORD ..\"

    OPTIONS:
      --folder=FOLDER_NAME
        use FOLDER_NAME instead of \"inbox\"
      --minuid=MIN_UID
        ignore all UIDs below MIN_UID
      --maxuid=MAX_UID
        ignore all UIDs above MAX_UID

    SEARCH FORMAT:
      -all words separated by spaces must match one of subject/date/from/to
        apple banana
        => emails where subject/from/to/date matches both 'apple' AND 'banana'
      -specify an individual field of subject/date/from/to with a '~'
        from~mary
        => emails from 'mary'
      -negate a header field query with '!~' instead of '~'
        from!~mary
        => emails from everyone EXCEPT 'mary'
      -specify that the body must match with a '~'
        body~bus
        => emails where the cached body matches 'bus'
      -negate a body query with '!~' instead of '~'
        body!~bus
        => emails where the cached body does NOT match 'bus'
      -specify disjunction with '++'
        from~mary ++ from~john ++ from~sue
        => emails from 'mary' PLUS emails from 'john' PLUS emails from 'sue'
      -group space or ++ separated words with parentheses
        (from~mary a) ++ (from~john b)
        => emails from 'mary' that match 'a' PLUS emails from 'john' that match 'b'
      -parentheses can nest arbitrarily deep
        (a ++ (b (c ++ d)))
        => emails that match 'a', PLUS emails that match 'b' AND match 'c' or 'd'
      -special characters can be escaped with backslash
        subject\\~fish\\ table
        => emails where subject/from/to/date matches 'subject~fish table'
      -doublequoted strings are treated as words
        \"this is a (single ++ w~ord)\"
        => emails where subject/from/to/date matches 'this is a (single ++ w~ord)'

    GRAMMAR:
      QUERY = <LIST_AND>
            | <LIST_OR>
            | <HEADER_QUERY>
            | <NEGATED_HEADER_QUERY>
            | <SIMPLE_HEADER_QUERY>
            | <BODY_QUERY>
            | <NEGATED_BODY_QUERY>
            | (<QUERY>)
        return emails that match this QUERY
      LIST_AND = <QUERY> <QUERY>
        return only emails that match both QUERYs
      LIST_OR = <QUERY> ++ <QUERY>
        return emails that match either QUERY or both
      HEADER_QUERY = <HEADER_FIELD>~<PATTERN>
        return emails where the indicated header field matches the pattern
      NEGATED_HEADER_QUERY = <HEADER_FIELD>!~<PATTERN>
        return emails where the indicated header field does NOT match the pattern
      SIMPLE_HEADER_QUERY = <PATTERN>
        return emails with at least one header field that matches the pattern
      BODY_QUERY = body~<PATTERN>
        return emails where the body matches the pattern
      NEGATED_BODY_QUERY = body!~<PATTERN>
        return emails where the body does NOT match the pattern
      HEADER_FIELD = subject | from | to | date | body
        restricts the fields that PATTERN can match
      PATTERN = <string> | <string>\"<string>\"<string>
        can be any string, supports doublequote quoting and backslash escaping

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
  }elsif($cmd =~ /^(--format)$/ and @_ >= 1){
    my $query = "@_";
    print prettyPrintQueryStr $query;
  }elsif($cmd =~ /^(--search)$/ and @_ >= 2){
    my $minUid = undef;
    my $maxUid = undef;
    my $folderName = "inbox";
    while(@_ > 0 and $_[0] =~ /^-/){
      my $arg = shift;
      if($arg =~ /^--folder=([a-z]+)$/){
        $folderName = $1;
      }elsif($arg =~ /^--minuid=(\d+)$/){
        $minUid = $1;
      }elsif($arg =~ /^--maxuid=(\d+)$/){
        $maxUid = $1;
      }else{
        die usage();
      }
    }
    my $accName = shift;
    die usage() if @_ == 0 or not defined $accName;
    my $query = "@_";
    my @uids = search $accName, $folderName, $minUid, $maxUid, $query;
    print (map { "$_\n" } @uids);
  }else{
    die usage();
  }
}

sub usage(){
  my $examples = join '', map {prettyPrintQueryStr $_, "      "} (
    'from~mary',
    'mary smith',
    '((a b) ++ (c d) ++ (e f))',
    'subject~b ++ "subject~b"',
    'from!~bob ++ subject!~math',
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


sub search($$$$$){
  my ($accName, $folderName, $minUid, $maxUid, $queryStr) = @_;
  if($queryStr =~ /^\s*$/){
    return ();
  }
  my $query = buildQuery $queryStr;

  my @allUids = getAllUids $accName, $folderName;
  @allUids = grep {$_ >= $minUid} @allUids if defined $minUid;
  @allUids = grep {$_ <= $maxUid} @allUids if defined $maxUid;
  @allUids = sort @allUids;
  my @uids = runQuery $accName, $folderName, $query, @allUids;
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

sub prettyPrintQueryStr($;$){
  my ($queryStr, $indent) = @_;
  $indent = "" if not defined $indent;
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
    my $like = $$query{negated} ? "NOT LIKE" : "LIKE";
    $fmt .= $indent . "[@fields] $like $$query{content}\n";
  }elsif($$query{type} =~ /body/){
    my $content = $$query{content};
    my $like = $$query{negated} ? "NOT LIKE" : "LIKE";
    $fmt .= $indent . "[body] $like $$query{content}\n";
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
      my $negated;
      my $content;
      if($and =~ /(to|from|subject)(!?)~(.*)/i){
        $type = "header";
        @fields = (lc $1);
        $negated = $2 eq "!" ? 1 : 0;
        $content = $3;
      }elsif($and =~ /(body)(!?)~(.*)/i){
        $type = "body";
        @fields = ();
        $negated = $2 eq "!" ? 1 : 0;
        $content = $3;
      }else{
        $type = "header";
        @fields = qw(to from subject);
        $negated = 0;
        $content = $and;
      }
      push @{$$innerQuery{parts}}, {
        type => $type,
        fields => [@fields],
        negated => $negated,
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
  $queryStr =~ s/\\!/%bang%/g;
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
  $queryStr =~ s/%bang%/!/g;
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
    my @fields = @{$$query{fields}};
    my $negated = $$query{negated};
    my $content = $$query{content};
    if($content =~ /^\s*$/){
      return undef;
    }else{
      return {type => $type, fields => [@fields], negated => $negated, content => $content};
    }
  }else{
    die "unknown type: $type\n";
  }
}

sub runQuery($$$@){
  my ($accName, $folderName, $query, @uids) = @_;
  return () if @uids == 0;

  my $minUid = $uids[0];
  my $maxUid = $uids[-1];

  my $type = $$query{type};
  if($type =~ /and|or/){
    my @parts = @{$$query{parts}};
    if($type eq "and"){
      for my $part(@parts){
        @uids = runQuery $accName, $folderName, $part, @uids;
      }
    }elsif($type eq "or"){
      my @unknownUids = @uids;
      my @okUids;
      for my $part(@parts){
        my @newOkUids = runQuery $accName, $folderName, $part, @unknownUids;
        my %isOk = map {$_ => 1} @newOkUids;
        @unknownUids = grep {not defined $isOk{$_}} @unknownUids;
        @okUids = (@okUids, @newOkUids);
      }
      @uids = sort @okUids;
    }
  }elsif($type =~ /^(header)$/){
    my @fields = @{$$query{fields}};
    my $content = $$query{content};
    my @conds;
    $content =~ s/'/''/g;
    $content =~ s/\\/\\\\/g;
    $content =~ s/%/\\%/g;
    $content =~ s/_/\\_/g;
    my $like = $$query{negated} == 1 ? "not like" : "like";
    for my $field(@fields){
      push @conds, "header_$field $like '%$content%' escape '\\'";
    };
    my $sql = ""
      . " select uid"
      . " from email"
      . " where"
      . "   uid <= $maxUid"
      . "   and uid >= $minUid"
      . "   and (" . join(" or ", @conds) . ")"
      ;
    my $output = runSql $accName, $folderName, $sql;
    my @newUids = split /\n/, $output;
    my %okUids = map {$_ => 1} @uids;
    @newUids = grep {defined $okUids{$_}} @newUids;
    @uids = sort @newUids;
  }elsif($type =~ /^(body)$/){
    my @fields = @{$$query{fields}};
    my $content = $$query{content};
    my $regex = $content;
    my $dir = "$emailDir/$accName/$folderName/bodies";
    my @cmd = ("grep", "-i", "-l", $regex);
    if(@uids < 1000){
      push @cmd, "$dir/$_" foreach @uids;
    }else{
      @cmd = (@cmd, "-R", $dir);
    }
    open GREP, "-|", @cmd;
    my @newUids = <GREP>;
    close GREP;
    @newUids = map {/(\d+)$/; $1} @newUids;
    if(@uids < 1000){
      my %okUids = map {$_ => 1} @uids;
      @newUids = grep {defined $okUids{$_}} @newUids;
    }
    @uids = @newUids;
  }

  return @uids;
}

&main(@ARGV);
