package QtEmail::UpdatePrint;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Config qw(getConfig);
use QtEmail::Email qw(
  writeStatusFiles
  formatStatusLine
  formatStatusShort
  padtrim
  readGlobalUnreadCountsFile
  updateGlobalUnreadCountsFile
  relTime
  clearError
  hasError
  readError
  writeError
  readLastUpdated
  writeLastUpdated
  readUidFileCounts
  readUidFile
  writeUidFile
  cacheHeader
  formatHeaderField
  formatDate
);
use QtEmail::Folders qw(
  accImapFolder accFolderOrder accEnsureFoldersParsed
  getFolderName
  parseFolders parseCountIncludeFolderNames
);
use QtEmail::Client qw(
  openFolder
  getClient
  setFlagStatus
);
use QtEmail::Body qw(
  cacheBodies
  getBody
  html2text
);
use QtEmail::Cache qw(
  getCachedHeaderUids
  getCachedBodyUids

  readCachedBody
  readCachedHeader
);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  cmdUpdate
  cmdPrint
);

sub cmdUpdate($@);
sub cmdPrint($@);

sub cacheAllHeaders($$$);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub cmdUpdate($@){
  my ($folderNameFilter, @accNames) = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  if(@accNames == 0){
    for my $accName(@accOrder){
      my $skip = $$config{accounts}{$accName}{skip};
      if(not defined $skip or $skip !~ /^true$/i){
        push @accNames, $accName;
      }
    }
  }

  my $success = 1;
  my @newUnreadCommands;
  for my $accName(@accNames){
    my $acc = $$config{accounts}{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    clearError $accName;
    my $c = getClient($acc, $$config{options});
    if(not defined $c){
      $success = 0;
      my $msg = "ERROR: Could not authenticate $$acc{name} ($$acc{user})\n";
      warn $msg;
      writeError $accName, $msg;
      writeStatusFiles(@accOrder);
      next;
    }

    my $hasNewUnread = 0;
    for my $folderName(accFolderOrder($acc)){
      if(defined $folderNameFilter and $folderName ne $folderNameFilter){
        print "skipping $folderName\n";
        next;
      }
      my $imapFolder = accImapFolder($acc, $folderName);
      my $f = openFolder($imapFolder, $c, 0);
      if(not defined $f){
        $success = 0;
        my $msg = "ERROR: Could not open folder $folderName\n";
        warn $msg;
        writeError $accName, $msg;
        writeStatusFiles(@accOrder);
        next;
      }

      my ($newMessages, $err) = cacheAllHeaders($accName, $folderName, $c);
      if(defined $err){
        warn $err;
        writeError $accName, $err;
        writeStatusFiles(@accOrder);
        next;
      }

      my @unread = $c->unseen;

      my @toCache;
      my $bodyCacheMode = $$acc{body_cache_mode};
      $bodyCacheMode = 'unread' if not defined $bodyCacheMode;
      if($bodyCacheMode eq "all"){
        @toCache = readUidFile $accName, $folderName, "all";
      }elsif($bodyCacheMode eq "unread"){
        @toCache = @unread;
      }elsif($bodyCacheMode eq "none"){
        @toCache = ();
      }

      cacheBodies($accName, $folderName, $c, $$GVAR{MAX_BODIES_TO_CACHE}, @toCache);

      $c->close();

      my %oldUnread = map {$_ => 1} readUidFile $accName, $folderName, "unread";
      writeUidFile $accName, $folderName, "unread", @unread;
      my @newUnread = grep {not defined $oldUnread{$_}} @unread;
      writeUidFile $accName, $folderName, "new-unread", @newUnread;
      $hasNewUnread = 1 if @newUnread > 0;

      print "running updatedb\n";
      system $$GVAR{EMAIL_SEARCH_EXEC}, "--updatedb", $accName, $folderName, $$GVAR{UPDATEDB_LIMIT};
      print "\n";
    }
    $c->logout();
    my $hasError = hasError $accName;
    if(not $hasError){
      writeLastUpdated $accName;
      if($hasNewUnread){
        my $cmd = $$acc{new_unread_cmd};
        push @newUnreadCommands, $cmd if defined $cmd and $cmd !~ /^\s*$/;
      }
    }
  }
  updateGlobalUnreadCountsFile($config);
  writeStatusFiles(@accOrder);
  if(defined $$config{options}{update_cmd}){
    my $cmd = $$config{options}{update_cmd};
    print "running update_cmd: $cmd\n";
    system "$cmd";
  }
  for my $cmd(@newUnreadCommands){
    print "running new_unread_cmd: $cmd\n";
    system "$cmd";
  }

  return $success;
}

sub cmdPrint($@){
  my ($folderName, @accNames) = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  require MIME::Parser;
  my $mimeParser = MIME::Parser->new();
  $mimeParser->output_dir($$GVAR{TMP_DIR});
  binmode STDOUT, ':utf8';
  for my $accName(@accNames){
    my @unread = readUidFile $accName, $folderName, "unread";
    for my $uid(@unread){
      my $hdr = readCachedHeader($accName, $folderName, $uid);
      my $cachedBody = readCachedBody($accName, $folderName, $uid);
      my $body = getBody($mimeParser, $cachedBody, 0);
      $body = "" if not defined $body;
      $body = "[NO BODY]" if $body =~ /^[ \t\n]*$/;
      $body = html2text($body);
      $body =~ s/^\n(\s*\n)*//;
      $body =~ s/\n(\s*\n)*$//;
      $body =~ s/\n\s*\n(\s*\n)+/\n\n/g;
      $body =~ s/^/  /mg;
      my $bodySep = "="x30;
      print "\n"
        . "ACCOUNT: $accName\n"
        . "UID: $uid\n"
        . "DATE: $$hdr{Date}\n"
        . "FROM: $$hdr{From}\n"
        . "TO: $$hdr{To}\n"
        . "CC: $$hdr{CC}\n"
        . "BCC: $$hdr{BCC}\n"
        . "SUBJECT: $$hdr{Subject}\n"
        . "BODY:\n$bodySep\n$body\n$bodySep\n"
        . "\n"
        ;
    }
  }
}

sub cacheAllHeaders($$$){
  my ($accName, $folderName, $c) = @_;
  print "fetching all message ids\n" if $$GVAR{VERBOSE};
  my @messages = $c->messages;
  for my $msg(@messages){
    if(not defined $msg or $msg !~ /^\d+$/){
      my $badMsgId = defined $msg ? $msg : "";
      my $err = "Error fetching headers (invalid message id: \"$badMsgId\")";
      return ([], $err);
    }
  }
  print "fetched " . @messages . " ids\n" if $$GVAR{VERBOSE};

  my $dir = "$$GVAR{EMAIL_DIR}/$accName/$folderName";
  writeUidFile $accName, $folderName, "remote", @messages;

  my $headersDir = "$dir/headers";
  system "mkdir", "-p", $headersDir;

  my %toSkip = map {$_ => 1} getCachedHeaderUids($accName, $folderName);

  @messages = grep {not defined $toSkip{$_}} @messages;
  my $total = @messages;

  print "downloading headers for $total messages\n" if $$GVAR{VERBOSE};
  my $headers = $c->parse_headers(\@messages, @{$$GVAR{HEADER_FIELDS}});

  print "encoding and formatting $total headers\n" if $$GVAR{VERBOSE};
  my $count = 0;
  my $segment = int($total/20);

  if($$GVAR{VERBOSE}){
    my $old_fh = select(STDOUT);
    $| = 1;
    select($old_fh);
  }

  my $missingFields = {};
  my $newlineFields = {};
  my $nullFields = {};
  for my $uid(keys %$headers){
    $count++;
    if(($segment > 0 and $count % $segment == 0) or $count == 1 or $count == $total){
      my $pct = int(0.5 + 100*$count/$total);
      print "#$pct%\n" if $$GVAR{VERBOSE};
    }
    my $hdr = $$headers{$uid};
    cacheHeader $hdr, $uid, $accName, $headersDir,
      $missingFields, $newlineFields, $nullFields;
  }

  for my $field(keys %$missingFields){
    next if $field =~ /^(CC|BCC)$/;
    my @uids = sort keys %{$$missingFields{$field}};
    warn "\n=====\nWARNING: missing '$field'\n@uids\n=====\n";
  }
  for my $field(keys %$newlineFields){
    my @uids = sort keys %{$$newlineFields{$field}};
    warn "\n=====\nWARNING: newlines in '$field':\n@uids\n=====\n";
  }
  for my $field(keys %$nullFields){
    my @uids = sort keys %{$$nullFields{$field}};
    warn "\n=====\nWARNING: NULs in '$field':\n@uids\n======\n";
  }
  print "\n" if $segment > 0 and $$GVAR{VERBOSE};

  my @cachedBodyUids = getCachedBodyUids($accName, $folderName);
  my %okCachedHeaderUids = map {$_ => 1} getCachedHeaderUids($accName, $folderName);
  for my $uid(@cachedBodyUids){
    if(not defined $okCachedHeaderUids{$uid}){
      warn "\n!!!!!\nDELETED MESSAGE: $uid is cached in bodies, but not on server\n";
      require MIME::Parser;
      my $mimeParser = MIME::Parser->new();
      $mimeParser->output_dir($$GVAR{TMP_DIR});

      my $cachedBody = readCachedBody($accName, $folderName, $uid);

      my $hdr = getHeaderFromBody($mimeParser, $cachedBody);
      cacheHeader $hdr, $uid, $accName, $headersDir, {}, {}, {};
      warn "  cached $uid using MIME entity in body cache\n\n";
      $okCachedHeaderUids{$uid} = 1;
    }
  }

  writeUidFile $accName, $folderName, "all", keys %okCachedHeaderUids;

  return ([@messages], undef);
}

1;
