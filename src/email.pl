#!/usr/bin/perl
use strict;
use warnings;
use Mail::IMAPClient;
use IO::Socket::SSL;

sub mergeUnreadCounts($);
sub readUnreadCounts();
sub writeUnreadCounts($);
sub readUidFile($$);
sub writeUidFile($$@);
sub cacheAllHeaders($$$);
sub getCachedHeaderUids($);
sub readCachedHeader($$);
sub examineFolder($$);
sub getClient($);
sub getSocket($);
sub readSecrets();

my $secretsFile = "$ENV{HOME}/.secrets";
my @configKeys = qw(user password server port folder);
my @extraConfigKeys = qw(ssl);

my @headerFields = qw(Date Subject From);
my $unreadCountsFile = "$ENV{HOME}/.unread-counts";
my $emailDir = "$ENV{HOME}/.cache/email";

my $settings = {
  Peek => 1,
  Uid => 1,
};

my $usage = "
  $0 -h|--help
    show this message

  $0 [--update] [ACCOUNT_NAME ACCOUNT_NAME ...]
    print unread message headers, and write unread counts to $unreadCountsFile
    if accounts are specified, all but those are ignored
    {ignored or missing accounts are preserved in $unreadCountsFile}

    write the unread counts, one line per account, to $unreadCountsFile
    e.g.: 3:AOL
          6:GMAIL
          0:WORK_GMAIL

  $0 --print [ACCOUNT_NAME ACCOUNT_NAME ...]
    does not fetch anything, merely reads $unreadCountsFile
    format and print $unreadCountsFile
    the string is a space-separated list of the first character of
      each account name followed by the integer count
    no newline character is printed
    if the count is zero for a given account, it is omitted
    if accounts are specified, all but those are omitted
    e.g.: A3 G6

  $0 --is-empty [ACCOUNT_NAME ACCOUNT_NAME ...]
    does not fetch anything, merely reads $unreadCountsFile
    checks for any unread emails
    if accounts are specified, all but those are ignored
    print \"empty\" and exit with zero exit code if there are no unread emails
    otherwise, print \"not empty\" and exit with non-zero exit code
";

sub main(@){
  my $cmd = shift if @_ > 0 and $_[0] =~ /^(--update|--print|--is-empty)$/;
  $cmd = "--update" if not defined $cmd;

  die $usage if @_ > 0 and $_[0] =~ /^(-h|--help)$/;

  my @accNames = @_;
  my $accounts = readSecrets();
  @accNames = sort keys %$accounts if @accNames == 0;

  if($cmd =~ /^(--update)$/){
    my $counts = {};
    for my $accName(@accNames){
      my $acc = $$accounts{$accName};
      die "Unknown account $accName\n" if not defined $acc;
      my $c = getClient($acc);
      if(not defined $c or not $c->IsAuthenticated()){
        warn "Could not authenticate $$acc{name} ($$acc{user})\n";
        next;
      }
      my $f = examineFolder($acc, $c);
      if(not defined $f){
        warn "Error getting folder $$acc{folder}\n";
        next;
      }

      cacheAllHeaders($acc, $c, $f);

      my @unread = $c->unseen;
      $$counts{$accName} = @unread;

      my %oldUnread = map {$_ => 1} readUidFile $acc, "unread";
      writeUidFile $acc, "unread", @unread;
      my @newUnread = grep {not defined $oldUnread{$_}} @unread;
      writeUidFile $acc, "new-unread", @newUnread;

      for my $uid(@unread){
        my $hdr = readCachedHeader($acc, $uid);
        print "$accName $uid $$hdr{Date} $$hdr{From} $$hdr{Subject}\n"
      }
    }
    mergeUnreadCounts $counts;
  }elsif($cmd =~ /^(--print)/){
    my $counts = readUnreadCounts();
    my @fmts;
    for my $accName(@accNames){
      die "Unknown account $accName\n" if not defined $$counts{$accName};
      my $count = $$counts{$accName};
      push @fmts, substr($accName, 0, 1) . $count if $count > 0;
    }
    print "@fmts";
  }elsif($cmd =~ /^(--is-empty)/){
    my $counts = readUnreadCounts();
    my @fmts;
    for my $accName(@accNames){
      die "Unknown account $accName\n" if not defined $$counts{$accName};
      my $count = $$counts{$accName};
      if($count > 0){
        print "not empty\n";
        exit 1;
      }
    }
    print "empty\n";
    exit 0;
  }
}

sub mergeUnreadCounts($){
  my $counts = shift;
  $counts = {%{readUnreadCounts()}, %$counts};
  writeUnreadCounts($counts);
}
sub readUnreadCounts(){
  my $counts = {};
  if(not -e $unreadCountsFile){
    return $counts;
  }
  open FH, "< $unreadCountsFile" or die "Could not read $unreadCountsFile\n";
  for my $line(<FH>){
    if($line =~ /^(\d+):(.*)/){
      $$counts{$2} = $1;
    }else{
      die "malformed $unreadCountsFile line: $line";
    }
  }
  return $counts;
}
sub writeUnreadCounts($){
  my $counts = shift;
  open FH, "> $unreadCountsFile" or die "Could not write $unreadCountsFile\n";
  for my $accName(sort keys %$counts){
    print FH "$$counts{$accName}:$accName\n";
  }
  close FH;
}

sub readUidFile($$){
  my ($acc, $fileName) = @_;
  my $dir = "$emailDir/$$acc{name}";

  if(not -f "$dir/$fileName"){
    return ();
  }else{
    my @uids = `cat "$dir/$fileName"`;
    chomp foreach @uids;
    return @uids;
  }
}

sub writeUidFile($$@){
  my ($acc, $fileName, @uids) = @_;
  my $dir = "$emailDir/$$acc{name}";
  system "mkdir", "-p", $dir;

  open FH, "> $dir/$fileName" or die "Could not write $dir/$fileName\n";
  print FH "$_\n" foreach @uids;
  close FH;
}

sub cacheAllHeaders($$$){
  my ($acc, $c, $f) = @_;
  print "fetching all message ids\n";
  my @messages = $c->messages;
  print "fetched " . @messages . " ids\n";

  my $dir = "$emailDir/$$acc{name}";
  writeUidFile $acc, "all", @messages;

  my $headersDir = "$dir/headers";
  system "mkdir", "-p", $headersDir;

  my %toSkip = map {$_ => 1} getCachedHeaderUids($acc);

  @messages = grep {not defined $toSkip{$_}} @messages;
  print "caching headers for " . @messages . " messages\n";

  my $headers = $c->parse_headers(\@messages, @headerFields);
  for my $uid(keys %$headers){
    my $hdr = $$headers{$uid};
    open FH, "> $headersDir/$uid";
    for my $field(sort @headerFields){
      my $vals = $$hdr{$field};
      my $val = "";
      if(not defined $vals or @$vals == 0){
        warn "WARNING: $uid has no field $field\n";
      }else{
        $val = $$vals[0];
      }
      if($val =~ s/\n/\\n/){
        warn "WARNING: newlines in $uid $field {replaced with \\n}\n";
      }
      print FH "$field: $val\n";
    }
    close FH;
  }
}

sub getCachedHeaderUids($){
  my $acc = shift;
  my $headersDir = "$emailDir/$$acc{name}/headers";
  my @cachedHeaders = `cd "$headersDir"; ls`;
  chomp foreach @cachedHeaders;
  return @cachedHeaders;
}

sub readCachedHeader($$){
  my ($acc, $uid) = @_;
  my $hdrFile = "$emailDir/$$acc{name}/headers/$uid";
  if(not -e $hdrFile){
    return undef;
  }
  my $header = {};
  my @lines = `cat "$hdrFile"`;
  for my $line(@lines){
    if($line =~ /^(\w+): (.*)$/){
      $$header{$1} = $2;
    }else{
      warn "WARNING: malformed header line: $line\n";
    }
  }
  return $header;
}

sub examineFolder($$){
  my ($acc, $c) = @_;
  my @folders = $c->folders($$acc{folder});
  if(@folders != 1){
    return undef;
  }

  my $f = $folders[0];
  $c->examine($f);
  return $f;
}

sub getClient($){
  my ($acc) = @_;
  my $network;
  if(defined $$acc{ssl} and $$acc{ssl} =~ /^false$/){
    $network = {
      Server => $$acc{server},
      Port => $$acc{port},
    };
  }else{
    $network = {
      Socket => getSocket($acc),
    };
  }
  print "$$acc{name}: logging in\n";
  return Mail::IMAPClient->new(
    %$network,
    User     => $$acc{user},
    Password => $$acc{password},
    %$settings,
  );
}

sub getSocket($){
  my $acc = shift;
  return IO::Socket::SSL->new(
    PeerAddr => $$acc{server},
    PeerPort => $$acc{port},
  );
}

sub readSecrets(){
  my @lines = `cat $secretsFile 2>/dev/null`;
  my $accounts = {};
  my $okConfigKeys = join "|", (@configKeys, @extraConfigKeys);
  for my $line(@lines){
    if($line =~ /^email\.(\w+)\.($okConfigKeys)\s*=\s*(.+)$/){
      $$accounts{$1} = {} if not defined $$accounts{$1};
      $$accounts{$1}{$2} = $3;
    }
  }
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    $$acc{name} = $accName;
    for my $key(sort @configKeys){
      die "Missing '$key' for '$accName' in $secretsFile\n" if not defined $$acc{$key};
    }
  }
  return $accounts;
}

&main(@ARGV);
