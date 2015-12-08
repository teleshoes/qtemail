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
  cmdMarkReadUnread
  cmdAccounts
  cmdFolders
  cmdHeader
  cmdSummary
  cmdStatus
  cmdHasError
  cmdHasNewUnread
  cmdHasUnread
  cmdReadConfigOptions
  cmdWriteConfigOptions
  cmdReadConfigOptionsSchema

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
  warnMsg
  readLastUpdated
  writeLastUpdated
  readUidFileCounts
  readUidFile
  writeUidFile
  cacheHeader
  formatHeaderField
  formatDate
);

sub cmdMarkReadUnread($$$@);
sub cmdAccounts();
sub cmdFolders($);
sub cmdHeader($$@);
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
sub cacheHeader($$$$$$$);
sub formatHeaderField($$);
sub formatDate($);

my $GVAR = QtEmail::Shared::GET_GVAR;

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
sub warnMsg($){
  my ($msg) = @_;
  warn $msg;
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
      warnMsg "  $accName $uid missing '$field'\n" unless $field =~ /^(CC|BCC)$/;
      $val = "";
    }else{
      if(@$vals > 1){
        warn "  $accName $uid too many '$field' values (using first):\n" .
          (join '', map {"    \"$_\"\n"} @$vals);
      }
      $val = $$vals[0];
    }
    my $rawVal = $val;
    if($rawVal =~ s/\n/\\n/g){
      $$newlineFields{$field} = {} if not defined $$newlineFields{$field};
      $$newlineFields{$field}{$uid} = 1;
      warnMsg "  $uid newlines in $field\n";
    }
    if($rawVal =~ s/\x00//g){
      $$nullFields{$field} = {} if not defined $$nullFields{$field};
      $$nullFields{$field}{$uid} = 1;
      warnMsg "  $uid NULs in $field\n";
    }

    my $fmtVal = formatHeaderField($field, $rawVal);
    $fmtVal =~ s/\n+$//; #silently remove trailing newlines
    if($fmtVal =~ s/\n/\\n/g){
      $$newlineFields{$field} = {} if not defined $$newlineFields{$field};
      $$newlineFields{$field}{$uid} = 1;
      warnMsg "  $uid newlines in $field\n";
    }
    if($fmtVal =~ s/\x00//g){
      $$nullFields{$field} = {} if not defined $$nullFields{$field};
      $$nullFields{$field}{$uid} = 1;
      warnMsg "  $uid NULs in $field\n";
    }

    push @fmtLines, "$field: $fmtVal\n";
    push @rawLines, "raw_$field: $rawVal\n";
  }
  open FH, "> $headersDir/$uid";
  binmode FH, ':utf8';
  print FH (@fmtLines, @rawLines);
  close FH;
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
