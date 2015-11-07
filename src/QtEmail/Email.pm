package QtEmail::Email;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Config qw(
  getConfig
  formatConfig writeConfig
  formatSchemaSimple
  getAccountConfigSchema getOptionsConfigSchema
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
use QtEmail::Cache qw(
  getCachedHeaderUids
  getCachedBodyUids

  readCachedBody
  readCachedHeader
);
use QtEmail::Util qw(
  hasWords
);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  cmdUpdate
  cmdMarkReadUnread
  cmdAccounts
  cmdFolders
  cmdHeader
  cmdBodyAttachments
  cmdCacheAllBodies
  cmdPrint
  cmdSummary
  cmdStatus
  cmdHasError
  cmdHasNewUnread
  cmdHasUnread
  cmdReadConfigOptions
  cmdWriteConfigOptions
  cmdReadConfigOptionsSchema
);

sub cmdUpdate($@);
sub cmdMarkReadUnread($$$@);
sub cmdAccounts();
sub cmdFolders($);
sub cmdHeader($$@);
sub cmdBodyAttachments($$$$$$$$@);
sub cmdCacheAllBodies($$);
sub cmdPrint($@);
sub cmdSummary($@);
sub cmdStatus($@);
sub cmdHasError(@);
sub cmdHasNewUnread(@);
sub cmdHasUnread(@);
sub cmdReadConfigOptions($$);
sub cmdWriteConfigOptions($$@);
sub cmdReadConfigOptionsSchema($);

sub writeStatusFiles(@);
sub formatStatusLine($@);
sub formatStatusShort($@);
sub padtrim($$);
sub html2text($);
sub readGlobalUnreadCountsFile();
sub updateGlobalUnreadCountsFile($);
sub relTime($);
sub clearError($);
sub hasError($);
sub readError($);
sub writeError($$);
sub readLastUpdated($);
sub writeLastUpdated($);
sub readUidFileCounts($$$);
sub readUidFile($$$);
sub writeUidFile($$$@);
sub cacheAllHeaders($$$);
sub cacheHeader($$$$$$$);
sub cacheBodies($$$$@);
sub getHeaderFromBody($$);
sub getBody($$$);
sub writeAttachments($$);
sub parseMimeEntity($);
sub parseAttachments($);
sub formatHeaderField($$);
sub formatDate($);

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
    my $c = getClient($acc);
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

      my @newMessages = cacheAllHeaders($accName, $folderName, $c);

      my @unread = $c->unseen;

      my @toCache;
      my $bodyCacheMode = $$acc{body_cache_mode};
      $bodyCacheMode = 'unread' if not defined $bodyCacheMode;
      if($bodyCacheMode eq "all"){
        @toCache = @newMessages;
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

sub cmdMarkReadUnread($$$@){
  my ($readStatus, $accName, $folderName, @uids) = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  $folderName = "inbox" if not defined $folderName;
  my $acc = $$config{accounts}{$accName};
  die "Unknown account $accName\n" if not defined $acc;
  my $imapFolder = accImapFolder($acc, $folderName);
  die "Unknown folder $folderName\n" if not defined $imapFolder;
  my $c = getClient($acc);
  die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
  my $f = openFolder($imapFolder, $c, 1);
  die "Error getting folder $folderName\n" if not defined $f;
  for my $uid(@uids){
    setFlagStatus($c, $uid, "Seen", $readStatus);
  }
  my @unread = readUidFile $$acc{name}, $folderName, "unread";
  my %all = map {$_ => 1} readUidFile $$acc{name}, $folderName, "all";
  my %marked = map {$_ => 1} @uids;

  my %toUpdate = map {$_ => 1} grep {defined $all{$_}} keys %marked;
  @unread = grep {not defined $toUpdate{$_}} @unread;
  if(not $readStatus){
    @unread = (@unread, sort keys %toUpdate);
  }
  writeUidFile $$acc{name}, $folderName, "unread", @unread;
  updateGlobalUnreadCountsFile($config);
  writeStatusFiles(@accOrder);
  $c->close();
  $c->logout();
}

sub cmdAccounts(){
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  for my $accName(@accOrder){
    my $acc = $$config{accounts}{$accName};
    my @countIncludeFolderNames = @{parseCountIncludeFolderNames $acc};
    my $unreadCount = 0;
    my $totalCount = 0;
    my $lastUpdated = readLastUpdated $accName;
    my $lastUpdatedRel = relTime $lastUpdated;
    my $error = readError $accName;
    $error = "" if not defined $error;
    for my $folderName(@countIncludeFolderNames){
      $unreadCount += readUidFileCounts $accName, $folderName, "unread";
      $totalCount += readUidFileCounts $accName, $folderName, "all";
    }
    $lastUpdated = 0 if not defined $lastUpdated;
    my $updateInterval = $$config{accounts}{$accName}{update_interval};
    if(not defined $updateInterval){
      $updateInterval = 0;
    }
    $updateInterval .= "s";
    my $refreshInterval = $$config{accounts}{$accName}{refresh_interval};
    if(not defined $refreshInterval){
      $refreshInterval = 0;
    }
    $refreshInterval .= "s";
    print "$accName:$lastUpdated:$lastUpdatedRel:$updateInterval:$refreshInterval:$unreadCount/$totalCount:$error\n";
  }
}

sub cmdFolders($){
  my $accName = shift;
  my $config = getConfig();
  my $acc = $$config{accounts}{$accName};
  for my $folderName(accFolderOrder($acc)){
    my $unreadCount = readUidFileCounts $accName, $folderName, "unread";
    my $totalCount = readUidFileCounts $accName, $folderName, "all";
    printf "$folderName:$unreadCount/$totalCount\n";
  }
}

sub cmdHeader($$@){
  my ($accName, $folderName, @uids) = @_;
  my $config = getConfig();
  binmode STDOUT, ':utf8';
  for my $uid(@uids){
    my $hdr = readCachedHeader($accName, $folderName, $uid);
    die "Unknown message: $uid\n" if not defined $hdr;
    for my $field(@{$$GVAR{HEADER_FIELDS}}){
      print "$uid.$field: $$hdr{$field}\n";
    }
  }
}

sub cmdBodyAttachments($$$$$$$$@){
  my ($modeBodyAttachments, $wantPlain, $wantHtml,
    $noDownload, $nulSep,
    $accName, $folderName, $destDir, @uids) = @_;
  my $config = getConfig();
  my $acc = $$config{accounts}{$accName};
  my $preferHtml = 0;
  $preferHtml = 1 if defined $$acc{prefer_html} and $$acc{prefer_html} =~ /true/i;
  $preferHtml = 0 if $wantPlain;
  $preferHtml = 1 if $wantHtml;
  die "Unknown account $accName\n" if not defined $acc;
  my $imapFolder = accImapFolder($acc, $folderName);
  die "Unknown folder $folderName\n" if not defined $imapFolder;
  my $c;
  my $f;
  require MIME::Parser;
  my $mimeParser = MIME::Parser->new();
  $mimeParser->output_dir($destDir);
  for my $uid(@uids){
    my $body = readCachedBody($accName, $folderName, $uid);
    if(not defined $body and $noDownload){
      print $nulSep ? "\0" : "\n";
      next;
    }
    if(not defined $body){
      if(not defined $c){
        $c = getClient($acc);
        die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
      }
      if(not defined $f){
        my $f = openFolder($imapFolder, $c, 0);
        die "Error getting folder $folderName\n" if not defined $f;
      }
      cacheBodies($accName, $folderName, $c, undef, $uid);
      $body = readCachedBody($accName, $folderName, $uid);
    }
    if(not defined $body){
      die "No body found for $accName=>$folderName=>$uid\n";
    }
    if($modeBodyAttachments eq "body"){
      my $fmt = getBody($mimeParser, $body, $preferHtml);
      chomp $fmt;
      $fmt = html2text $fmt if $wantPlain;
      print $fmt;
      print $nulSep ? "\0" : "\n";
    }elsif($modeBodyAttachments eq "attachments"){
      my @attachments = writeAttachments($mimeParser, $body);
      for my $attachment(@attachments){
        print " saved att: $attachment\n";
      }
    }
  }
  $c->close() if defined $c;
  $c->logout() if defined $c;
}

sub cmdCacheAllBodies($$){
  my ($accName, $folderName) = @_;
  my $config = getConfig();

  my $acc = $$config{accounts}{$accName};
  die "Unknown account $accName\n" if not defined $acc;
  my $c = getClient($acc);
  die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;

  my $imapFolder = accImapFolder($acc, $folderName);
  die "Unknown folder $folderName\n" if not defined $imapFolder;
  my $f = openFolder($imapFolder, $c, 0);
  die "Error getting folder $folderName\n" if not defined $f;

  my @messages = $c->messages;
  cacheBodies($accName, $folderName, $c, undef, @messages);
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

sub cmdSummary($@){
  my ($folderName, @accNames) = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  for my $accName(@accNames){
    my @unread = readUidFile $accName, $folderName, "unread";
    for my $uid(@unread){
      my $hdr = readCachedHeader($accName, $folderName, $uid);
      print ""
        . "$accName"
        . " $$hdr{Date}"
        . " $$hdr{From}"
        . " $$hdr{To}"
        . " $$hdr{CC}"
        . " $$hdr{BCC}"
        . "\n"
        . "  $$hdr{Subject}"
        . "\n"
        ;
    }
  }
}

sub cmdStatus($@){
  my ($modeLineShort, @accNames) = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  my $counts = readGlobalUnreadCountsFile();
  if($modeLineShort eq "line"){
    print formatStatusLine($counts, @accNames);
  }elsif($modeLineShort eq "status"){
    print formatStatusShort($counts, @accNames);
  }
}

sub cmdHasError(@){
  my @accNames = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  for my $accName(@accNames){
    if(hasError $accName){
      return 1;
    }
  }
  return 0;
}

sub cmdHasNewUnread(@){
  my @accNames = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  my @fmts;
  for my $accName(@accNames){
    my $acc = $$config{accounts}{$accName};
    for my $folderName(accFolderOrder($acc)){
      my $unread = readUidFileCounts $accName, $folderName, "new-unread";
      if($unread > 0){
        return 1;
      }
    }
  }
  return 0;
}

sub cmdHasUnread(@){
  my @accNames = @_;
  my $config = getConfig();
  my @accOrder = @{$$config{accOrder}};
  @accNames = @accOrder if @accNames == 0;
  my @fmts;
  for my $accName(@accNames){
    my $acc = $$config{accounts}{$accName};
    for my $folderName(accFolderOrder($acc)){
      my $unread = readUidFileCounts $accName, $folderName, "unread";
      if($unread > 0){
        return 1;
      }
    }
  }
  return 0;
}

sub cmdReadConfigOptions($$){
  my ($modeAccountOptions, $account) = @_;
  if($modeAccountOptions eq "account" and defined $account){
    print formatConfig $account;
  }elsif($modeAccountOptions eq "options" and not defined $account){
    print formatConfig undef;
  }else{
    die "invalid read config/options mode: $modeAccountOptions\n";
  }
}

sub cmdWriteConfigOptions($$@){
  my ($modeAccountOptions, $account, @keyVals) = @_;
  if($modeAccountOptions eq "account" and defined $account){
    writeConfig $account, @keyVals;
  }elsif($modeAccountOptions eq "options" and not defined $account){
    writeConfig undef, @keyVals;
  }else{
    die "invalid write config/options mode: $modeAccountOptions\n";
  }
}

sub cmdReadConfigOptionsSchema($){
  my ($modeAccountOptions) = @_;
  if($modeAccountOptions eq "account"){
    print formatSchemaSimple getAccountConfigSchema();
  }elsif($modeAccountOptions eq "options"){
    print formatSchemaSimple getOptionsConfigSchema();
  }else{
    die "invalid read config/options schema mode: $modeAccountOptions\n";
  }
}

sub writeStatusFiles(@){
  my @accNames = @_;
  my $counts = readGlobalUnreadCountsFile();

  my $fmt;
  $fmt = formatStatusLine $counts, @accNames;
  open FH, "> $$GVAR{STATUS_LINE_FILE}" or die "Could not write $$GVAR{STATUS_LINE_FILE}\n";
  print FH $fmt;
  close FH;

  $fmt = formatStatusShort $counts, @accNames;
  open FH, "> $$GVAR{STATUS_SHORT_FILE}" or die "Could not write $$GVAR{STATUS_SHORT_FILE}\n";
  print FH $fmt;
  close FH;
}
sub formatStatusLine($@){
  my ($counts, @accNames) = @_;
  my @fmts;
  for my $accName(@accNames){
    die "Unknown account $accName\n" if not defined $$counts{$accName};
    my $count = $$counts{$accName};
    my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
    my $nameDisplay = substr($accName, 0, 1);
    my $fmt = $nameDisplay . $count;
    if(-f $errorFile){
      push @fmts, "$fmt!err";
    }else{
      push @fmts, $fmt if $count > 0;
    }
  }
  return "@fmts\n";
}
sub formatStatusShort($@){
  my ($counts, @accNames) = @_;
  my $isError = 0;
  my $isTooLarge = 0;
  my $total = 0;
  my @fmts;

  for my $accName(@accNames){
    die "Unknown account $accName\n" if not defined $$counts{$accName};
    my $count = $$counts{$accName};
    my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
    my $nameDisplay = substr($accName, 0, 1);
    my $fmt = $nameDisplay . $count;
    $isTooLarge = 1 if $count > 99;
    $isError = 1 if -f $errorFile;
    $total += $count;
    push @fmts, $fmt if $count > 0;
  }

  $total = "!!!" if $total > 999;

  my ($top, $bot);
  if($isError){
    ($top, $bot) = ("ERR", $total);
  }elsif($isTooLarge){
    ($top, $bot) = ("big", $total);
  }elsif(@fmts > 2){
    ($top, $bot) = ("all", $total);
  }else{
    ($top, $bot) = @fmts;
  }
  return (padtrim 3, $top) . "\n" . (padtrim 3, $bot) . "\n";
}
sub padtrim($$){
  my ($len, $s) = @_;
  $s = "" if not defined $s;
  $s = substr($s, 0, $len);
  $s = ' ' x ($len - length $s) . $s;
  return $s;
}
sub html2text($){
  my ($html) = @_;
  if($html !~ /<(html|body|head|table)(\s+[^>]*)?>/){
    return $html;
  }
  if(-x $$GVAR{HTML2TEXT_EXEC}){
    my $tmpFile = "/tmp/email_tmp_" . int(time*1000) . ".html";
    open FH, "> $tmpFile" or die "Could not write to $tmpFile\n";
    print FH $html;
    close FH;
    my $text = `$$GVAR{HTML2TEXT_EXEC} $tmpFile`;
    system "rm", $tmpFile;
    return $text;
  }else{
    $html =~ s/<[^>]*>//g;
    $html =~ s/\n(\s*\n)+/\n/g;
    $html =~ s/^\s+//mg;
    return $html;
  }
}

sub readGlobalUnreadCountsFile(){
  my $counts = {};
  if(not -e $$GVAR{UNREAD_COUNTS_FILE}){
    return $counts;
  }
  open FH, "< $$GVAR{UNREAD_COUNTS_FILE}" or die "Could not read $$GVAR{UNREAD_COUNTS_FILE}\n";
  for my $line(<FH>){
    if($line =~ /^(\d+):(.*)/){
      $$counts{$2} = $1;
    }else{
      die "malformed $$GVAR{UNREAD_COUNTS_FILE} line: $line";
    }
  }
  return $counts;
}
sub updateGlobalUnreadCountsFile($){
  my ($config) = @_;
  my @accOrder = @{$$config{accOrder}};

  my %counts = map {$_ => 0} @accOrder;
  for my $accName(@accOrder){
    my $acc = $$config{accounts}{$accName};
    my @countIncludeFolderNames = @{parseCountIncludeFolderNames $acc};
    for my $folderName(@countIncludeFolderNames){
      my $count = readUidFileCounts $accName, $folderName, "unread";
      $counts{$accName} += $count;
    }
  }

  open FH, "> $$GVAR{UNREAD_COUNTS_FILE}" or die "Could not write $$GVAR{UNREAD_COUNTS_FILE}\n";
  for my $accName(@accOrder){
    print FH "$counts{$accName}:$accName\n";
  }
  close FH;
}

sub relTime($){
  my ($time) = @_;
  return "never" if not defined $time;
  my $diff = time - $time;

  return "now" if $diff == 0;

  my $ago;
  if($diff > 0){
    $ago = "ago";
  }else{
    $diff = 0 - $diff;
    $ago = "in the future";
  }

  my @diffs = (
    [second  => int(0.5 + $diff)],
    [minute  => int(0.5 + $diff / 60)],
    [hour    => int(0.5 + $diff / 60 / 60)],
    [day     => int(0.5 + $diff / 60 / 60 / 24)],
    [month   => int(0.5 + $diff / 60 / 60 / 24 / 30.4)],
    [year    => int(0.5 + $diff / 60 / 60 / 24 / 365.25)],
  );
  my @diffUnits = map {$$_[0]} @diffs;
  my %diffVals = map {$$_[0] => $$_[1]} @diffs;

  for my $unit(reverse @diffUnits){
    my $val = $diffVals{$unit};
    if($val > 0){
      my $unit = $val == 1 ? $unit : "${unit}s";
      return "$val $unit $ago";
    }
  }
}

sub hasError($){
  my ($accName) = @_;
  my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
  return -f $errorFile;
}
sub clearError($){
  my ($accName) = @_;
  my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
  system "rm", "-f", $errorFile;
}
sub readError($){
  my ($accName) = @_;
  my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
  if(not -f $errorFile){
    return undef;
  }
  open FH, "< $errorFile" or die "Could not read $errorFile\n";
  my $error = join "", <FH>;
  close FH;
  return $error;
}
sub writeError($$){
  my ($accName, $msg) = @_;
  my $errorFile = "$$GVAR{EMAIL_DIR}/$accName/error";
  open FH, "> $errorFile" or die "Could not write to $errorFile\n";
  print FH $msg;
  close FH;
}

sub readLastUpdated($){
  my ($accName) = @_;
  my $f = "$$GVAR{EMAIL_DIR}/$accName/last_updated";
  if(not -f $f){
    return undef;
  }
  open FH, "< $f" or die "Could not read $f\n";
  my $time = <FH>;
  close FH;
  chomp $time;
  return $time;
}
sub writeLastUpdated($){
  my ($accName) = @_;
  my $f = "$$GVAR{EMAIL_DIR}/$accName/last_updated";
  open FH, "> $f" or die "Could not write to $f\n";
  print FH time . "\n";
  close FH;
}

sub readUidFileCounts($$$){
  my ($accName, $folderName, $fileName) = @_;
  my $dir = "$$GVAR{EMAIL_DIR}/$accName/$folderName";

  if(not -f "$dir/$fileName"){
    return 0;
  }else{
    my $count = `wc -l $dir/$fileName`;
    if($count =~ /^(\d+)/){
      return $1;
    }
    return 0
  }
}

sub readUidFile($$$){
  my ($accName, $folderName, $fileName) = @_;
  my $dir = "$$GVAR{EMAIL_DIR}/$accName/$folderName";

  if(not -f "$dir/$fileName"){
    return ();
  }else{
    my @uids = `cat "$dir/$fileName"`;
    chomp foreach @uids;
    return @uids;
  }
}
sub writeUidFile($$$@){
  my ($accName, $folderName, $fileName, @uids) = @_;
  my $dir = "$$GVAR{EMAIL_DIR}/$accName/$folderName";
  system "mkdir", "-p", $dir;

  open FH, "> $dir/$fileName" or die "Could not write $dir/$fileName\n";
  print FH "$_\n" foreach @uids;
  close FH;
}

sub cacheAllHeaders($$$){
  my ($accName, $folderName, $c) = @_;
  print "fetching all message ids\n" if $$GVAR{VERBOSE};
  my @messages = $c->messages;
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

  return @messages;
}

sub cacheHeader($$$$$$$){
  my ($hdr, $uid, $accName, $headersDir,
    $missingFields, $newlineFields, $nullFields) = @_;
  my @fmtLines;
  my @rawLines;
  for my $field(@{$$GVAR{HEADER_FIELDS}}){
    my $vals = $$hdr{$field};
    my $val;
    if(not defined $vals or @$vals == 0){
      $$missingFields{$field} = {} if not defined $$missingFields{$field};
      $$missingFields{$field}{$uid} = 1;
      warn "  $uid missing $field\n" unless $field =~ /^(CC|BCC)$/;
      $val = "";
    }else{
      die "FATAL: too many '$field' values for $uid in $accName\n" if @$vals != 1;
      $val = $$vals[0];
    }
    my $rawVal = $val;
    if($rawVal =~ s/\n/\\n/g){
      $$newlineFields{$field} = {} if not defined $$newlineFields{$field};
      $$newlineFields{$field}{$uid} = 1;
      warn "  $uid newlines in $field\n";
    }
    if($rawVal =~ s/\x00//g){
      $$nullFields{$field} = {} if not defined $$nullFields{$field};
      $$nullFields{$field}{$uid} = 1;
      warn "  $uid NULs in $field\n";
    }

    my $fmtVal = formatHeaderField($field, $rawVal);
    $fmtVal =~ s/\n+$//; #silently remove trailing newlines
    if($fmtVal =~ s/\n/\\n/g){
      $$newlineFields{$field} = {} if not defined $$newlineFields{$field};
      $$newlineFields{$field}{$uid} = 1;
      warn "  $uid newlines in $field\n";
    }
    if($fmtVal =~ s/\x00//g){
      $$nullFields{$field} = {} if not defined $$nullFields{$field};
      $$nullFields{$field}{$uid} = 1;
      warn "  $uid NULs in $field\n";
    }

    push @fmtLines, "$field: $fmtVal\n";
    push @rawLines, "raw_$field: $rawVal\n";
  }
  open FH, "> $headersDir/$uid";
  binmode FH, ':utf8';
  print FH (@fmtLines, @rawLines);
  close FH;
}

sub cacheBodies($$$$@){
  my ($accName, $folderName, $c, $maxCap, @messages) = @_;
  my $bodiesDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  local $| = 1;

  my %toSkip = map {$_ => 1} getCachedBodyUids($accName, $folderName);
  @messages = grep {not defined $toSkip{$_}} @messages;
  if(defined $maxCap and $maxCap > 0 and @messages > $maxCap){
    my $count = @messages;
    print "only caching $maxCap out of $count\n" if $$GVAR{VERBOSE};
    @messages = reverse @messages;
    @messages = splice @messages, 0, $maxCap;
    @messages = reverse @messages;
  }
  print "caching bodies for " . @messages . " messages\n" if $$GVAR{VERBOSE};
  my $total = @messages;
  my $count = 0;
  my $segment = int($total/20);
  $segment = 100 if $segment > 100;

  for my $uid(@messages){
    $count++;
    if($segment > 0 and $count % $segment == 0){
      my $pct = int(0.5 + 100*$count/$total);
      my $date = `date`;
      chomp $date;
      print "  {cached $count/$total bodies} $pct%  $date\n" if $$GVAR{VERBOSE};
    }
    my $body = $c->message_string($uid);
    $body = "" if not defined $body;
    if($body =~ /^\s*$/){
      if($body =~ /^\s*$/){
        warn "WARNING: no body found for $accName $folderName $uid\n";
      }
    }else{
      open FH, "> $bodiesDir/$uid" or die "Could not write $bodiesDir/$uid\n";
      print FH $body;
      close FH;
    }
  }
}

sub getHeaderFromBody($$){
  my ($mimeParser, $bodyString) = @_;
  my $entity = $mimeParser->parse_data($bodyString);

  my $head = $entity->head();

  #simulate Mail::IMAPClient::parse_headers using MIME::Parser
  #like:
  # my $c = Mail::IMAPClient->new();
  # my $headers = $c->parse_headers($uid, @{$$GVAR{HEADER_FIELDS}})
  # my $hdr = $$headers{$uid};
  # return $hdr;
  my $hdr = {};
  for my $field(@{$$GVAR{HEADER_FIELDS}}){
    my $rawVal = $head->get($field);
    if(defined $rawVal){
      chomp $rawVal;
      $$hdr{$field} = [$rawVal];
    }
  }

  $mimeParser->filer->purge;
  return $hdr;
}

sub getBody($$$){
  my ($mimeParser, $bodyString, $preferHtml) = @_;
  my $entity = $mimeParser->parse_data($bodyString);

  my @parts = parseMimeEntity($entity);
  my @text = map {$_->{handle}} grep {$_->{partType} eq "text"} @parts;
  my @html = map {$_->{handle}} grep {$_->{partType} eq "html"} @parts;
  my @atts = map {$_->{handle}} grep {$_->{partType} eq "attachment"} @parts;

  my $body = "";
  for my $isHtml($preferHtml ? (1, 0) : (0, 1)){
    my @strings = map {$_->as_string} ($isHtml ? @html : @text);
    my $fmt = join "\n", @strings;
    if(hasWords $fmt){
      $body .= $fmt;
      last;
    }
  }
  $body =~ s/\r\n/\n/g;
  chomp $body;
  $body .= "\n" if length($body) > 0;

  my $attachments = "";
  my $first = 1;
  for my $att(@atts){
    my $path = $att->path;
    my $attName = $path;
    $attName =~ s/.*\///;
    if($preferHtml){
      $attachments .= "<br/>" if $first;
      $attachments .= "<i>attachment: $attName</i><br/>";
    }else{
      $attachments .= "\n" if $first;
      $attachments .= "attachment: $attName\n";
    }
    $first = 0;
  }

  $mimeParser->filer->purge;
  return $attachments . $body;
}

sub writeAttachments($$){
  my ($mimeParser, $bodyString) = @_;
  my $entity = $mimeParser->parse_data($bodyString);
  my @parts = parseMimeEntity($entity);
  my @attachments;
  for my $part(@parts){
    my $partType = $$part{partType};
    my $path = $$part{handle}->path;
    if($partType eq "attachment"){
      push @attachments, $path;
    }else{
      unlink $path or warn "WARNING: could not remove file: $path\n";
    }
  }
  return @attachments;
}

sub parseMimeEntity($){
  my ($entity) = @_;
  my $count = $entity->parts;
  if($count > 0){
    my @parts;
    for(my $i=0; $i<$count; $i++){
      my @subParts = parseMimeEntity($entity->parts($i));
      @parts = (@parts, @subParts);
    }
    return @parts;
  }else{
    my $type = $entity->effective_type;
    my $handle = $entity->bodyhandle;
    my $disposition = $entity->head->mime_attr('content-disposition');
    my $partType;
    if($type eq "text/plain"){
      $partType = "text";
    }elsif($type eq "text/html"){
      $partType = "html";
    }elsif(defined $disposition and $disposition =~ /attachment/){
      $partType = "attachment";
    }else{
      $partType = "unknown";
    }
    return ({partType=>$partType, handle=>$handle});
  }
}


sub formatHeaderField($$){
  my ($field, $val) = @_;
  require Encode;
  $val = Encode::decode('MIME-Header', $val);
  if($field =~ /^(Date)$/){
    $val = formatDate($val);
  }
  return $val;
}

sub formatDate($){
  my $date = shift;
  require Date::Parse;
  my $d = Date::Parse::str2time($date);
  if(defined $d){
    require Date::Format;
    return Date::Format::time2str($$GVAR{DATE_FORMAT}, $d);
  }
  return $date;
}

1;
