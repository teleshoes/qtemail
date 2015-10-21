#!/usr/bin/perl
use strict;
use warnings;
use lib "/opt/qtemail/lib";
#Module deps required below:
# Encode Mail::IMAPClient IO::Socket::SSL MIME::Parser
# Date::Parse Date::Format

BEGIN {
  require QtEmail::Shared;
  my $baseDir = "$ENV{HOME}/.cache/email";
  QtEmail::Shared::INIT_GVAR({
    EMAIL_DIR => $baseDir,
    HEADER_FIELDS => [qw(Date Subject From To CC BCC)],
    VERBOSE => 0,
    DATE_FORMAT => "%Y-%m-%d %H:%M:%S",
    MAX_BODIES_TO_CACHE => 100,

    EMAIL_SEARCH_EXEC => "/opt/qtemail/bin/email-search.pl",
    UPDATEDB_LIMIT => 100,

    SMTP_CLI_EXEC => "/opt/qtemail/bin/smtp-cli",
    TMP_DIR => "/var/tmp",

    UNREAD_COUNTS_FILE => "$baseDir/unread-counts",
    STATUS_LINE_FILE => "$baseDir/status-line",
    STATUS_SHORT_FILE => "$baseDir/status-short",

    HTML2TEXT_EXEC => "/usr/bin/html2text",

    IMAP_CLIENT_SETTINGS => {
      Peek => 1,
      Uid => 1,
      Ignoresizeerrors => 1,
    },
  });
}

use QtEmail::Shared qw(GET_GVAR MODIFY_GVAR);
use QtEmail::Config qw(
  getConfig formatConfig writeConfig
  formatSchemaSimple formatSchemaPretty
  getSecretsFile getSecretsPrefix
  getAccountConfigSchema getOptionsConfigSchema
  getAccReqConfigKeys getAccOptConfigKeys getOptionsConfigKeys
);

sub optFolder($$);

sub cmdUpdate($@);
sub cmdSmtp($$$$@);
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

sub setFlagStatus($$$$);
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
sub getCachedHeaderUids($$);
sub readCachedHeader($$$);
sub openFolder($$$);
sub getClient($);
sub getSocket($);
sub formatHeaderField($$);
sub formatDate($);
sub accImapFolder($$);
sub accFolderOrder($);
sub accEnsureFoldersParsed($);
sub getFolderName($);
sub parseFolders($);
sub parseCountIncludeFolderNames($);
sub hasWords($);

my $GVAR = QtEmail::Shared::GET_GVAR;

my $okCmds = join "|", qw(
  --update --header --body --body-plain --body-html --attachments
  --cache-all-bodies
  --smtp
  --mark-read --mark-unread
  --accounts --folders --print --summary --status-line --status-short
  --has-error --has-new-unread --has-unread
  --read-config --write-config --read-options --write-options
  --read-config-schema --read-options-schema
);

my $usage = "
  Simple IMAP client. {--smtp command is a convenience wrapper around smtp-cli}
  Configuration is in ".getSecretsFile()."
    Each config entry is one line of the format:
      ".getSecretsPrefix().".GLOBAL_OPTION_KEY = <value>
      or
      ".getSecretsPrefix().".ACCOUNT_NAME.ACCOUNT_CONFIG_KEY = <value>

    Account names can be any word characters (alphanumeric plus underscore)
    Lines that do not begin with \"".getSecretsPrefix().".\" are ignored.

    ACCOUNT_NAME:    the word following \"".getSecretsPrefix().".\" in ".getSecretsFile()."\n
    FOLDER_NAME:     \"inbox\", \"sent\" or one of the names from \"folders\"\n
    UID:             an IMAP UID {UIDVALIDITY is assumed to never change}\n
    GLOBAL_OPTION_KEY:\n" . formatSchemaPretty(getOptionsConfigSchema(), "      ") . "
    ACCOUNT_CONFIG_KEY:\n" . formatSchemaPretty(getAccountConfigSchema(), "      ") . "

  $0 -h|--help
    show this message

  $0 [--update] [--folder=FOLDER_NAME_FILTER] [ACCOUNT_NAME ACCOUNT_NAME ...]
    -for each account specified {or all non-skipped accounts if none are specified}:
      -login to IMAP server, or create file $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/error
      -for each FOLDER_NAME {or just FOLDER_NAME_FILTER if specified}:
        -fetch and write all message UIDs to
          $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/FOLDER_NAME/all
        -fetch and cache all message headers in
          $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/FOLDER_NAME/headers/UID
        -fetch and cache bodies according to body_cache_mode config
            all    => every header that was cached gets its body cached
            unread => every unread message gets its body cached
            none   => no bodies are cached
          $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/FOLDER_NAME/bodies/UID
        -fetch all unread messages and write their UIDs to
          $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/FOLDER_NAME/unread
        -write all message UIDs that are now in unread and were not before
          $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/FOLDER_NAME/new-unread
        -run $$GVAR{EMAIL_SEARCH_EXEC} --updatedb ACCOUNT_NAME FOLDER_NAME $$GVAR{UPDATEDB_LIMIT}
    -update global unread counts file $$GVAR{UNREAD_COUNTS_FILE}
      count the unread emails for each account in the folders in count_include
      the default is just to include the counts for \"inbox\"

      write the unread counts, one line per account, to $$GVAR{UNREAD_COUNTS_FILE}
      e.g.: 3:AOL
            6:GMAIL
            0:WORK_GMAIL

  $0 --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
    simple wrapper around smtp-cli. {you can add extra recipients with --to}
    calls:
      $$GVAR{SMTP_CLI_EXEC} \\
        --server=<smtp_server> --port=<smtp_port> \\
        --user=<user> --pass=<password> \\
        --from=<user> \\
        --subject=SUBJECT --body-plain=BODY \\
        --to=TO \\
        ARG ARG ..

  $0 --mark-read [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    login and mark the indicated message(s) as read

  $0 --mark-unread [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    login mark the indicated message(s) as unread

  $0 --accounts
    format and print information about each account
    \"ACCOUNT_NAME:<timestamp>:<relative_time>:<update_interval>s:<unread_count>/<total_count>:<error>\"

  $0 --folders ACCOUNT_NAME
    format and print information about each folder for the given account
    \"FOLDER_NAME:<unread_count>/<total_count>\"

  $0 --header [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    format and print the header of the indicated message(s)
    prints each of [@{$$GVAR{HEADER_FIELDS}}]
      one per line, formatted \"UID.FIELD: VALUE\"

  $0 --body [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    download, format and print the body of the indicated message(s)
    if -0 is specified, print a NUL character after each body instead of a newline
    if body is cached, skip download
    if body is not cached and --no-download is specified, use empty string for body
      instead of downloading the body
    if message has a plaintext and HTML component, only one is returned
    if prefer_html is true, HTML is returned, otherwise, plaintext

  $0 --body-plain [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    same as --body, but override prefer_html=false,
      and attempt to convert the result to plaintext if it appears to be HTML
      (uses $$GVAR{HTML2TEXT_EXEC} if available, or just strips out the tags)

  $0 --body-html [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    same as --body, but override prefer_html=true

  $0 --attachments [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_DIR UID [UID UID ...]
    download the body of the indicated message(s) and save any attachments to DEST_DIR
    if body is cached, skip download

  $0 --cache-all-bodies ACCOUNT_NAME FOLDER_NAME
    attempt to download the body of all uncached bodies

  $0 --print [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers and bodies
    fetches bodies like \"$0 --body-plain --no-download\",
      similarly converting HTML to plaintext
    formats whitespace in bodies, compressing multiple empty lines to a max of 2,
      and prepending every line with 2 spaces

  $0 --summary [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers

  $0 --status-line [ACCOUNT_NAME ACCOUNT_NAME ...]
    {cached in $$GVAR{STATUS_LINE_FILE} when $$GVAR{UNREAD_COUNTS_FILE} or error files change}
    does not fetch anything, merely reads $$GVAR{UNREAD_COUNTS_FILE}
    format and print $$GVAR{UNREAD_COUNTS_FILE}
    the string is a space-separated list of the first character of
      each account name followed by the integer count
    no newline character is printed
    if the count is zero for a given account, it is omitted
    if accounts are specified, all but those are omitted
    e.g.: A3 G6

  $0 --status-short [ACCOUNT_NAME ACCOUNT_NAME ...]
    {cached in $$GVAR{STATUS_SHORT_FILE} when $$GVAR{UNREAD_COUNTS_FILE} or error files change}
    does not fetch anything, merely reads $$GVAR{UNREAD_COUNTS_FILE}
    format and print $$GVAR{UNREAD_COUNTS_FILE}
    if accounts are specified, all but those are omitted
    omits accounts with unread-count of 0

    the string is two lines, each always containing exactly three characters
    no line can be longer than 3, and if it is shorter, it is left-padded with spaces
    each line ends in a newline character

    if any account has error, prints:
      \"ERR\", \"<total>\"
    if any account has more then 99 emails, prints
      \"big\", \"<total>\"
    if more than two accounts have a positive unread-count, prints:
      \"all\", \"<total>\"
    if exactly two accounts have a positive unread-count, prints:
      \"<acc><count>\", \"<acc><count>\"
    if exactly one account has a positive unread-count, prints:
      \"<acc><count>\", \"\"
    otherwise, prints:
      \"\", \"\"

    <total> = total of all unread counts if less than 1000, or '!!!' otherwise
    <acc> = first character of a given account name
    <count> = unread count for the indicated account

  $0 --has-error [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks if $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/error exists
    print \"yes\" and exit with zero exit code if it does
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-new-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any NEW unread emails, in any account
      {UIDs in $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/new-unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are new unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any unread emails, in any account
      {UIDs in $$GVAR{EMAIL_DIR}/ACCOUNT_NAME/unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --read-config ACCOUNT_NAME
    reads ".getSecretsFile()."
    for each line of the form \"".getSecretsPrefix().".ACCOUNT_NAME.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-config ACCOUNT_NAME KEY=VAL [KEY=VAL KEY=VAL]
    modifies ".getSecretsFile()."
    for each KEY/VAL pair:
      removes any line that matches \"".getSecretsPrefix().".ACCOUNT_NAME.KEY\\s*=\"
      adds a line at the end \"".getSecretsPrefix().".ACCOUNT_NAME.KEY = VAL\"

  $0 --read-options
    reads ".getSecretsFile()."
    for each line of the form \"".getSecretsPrefix().".KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-options KEY=VAL [KEY=VAL KEY=VAL]
    reads ".getSecretsFile()."
    for each line of the form \"".getSecretsPrefix().".KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --read-config-schema
    print the allowed keys and descriptions for account config entries
    formatted, one per line, like this:
    <KEY_NAME>=<DESC>
      KEY_NAME: one of: " .
        join(" ", (getAccReqConfigKeys(), getAccOptConfigKeys())) . "
      DESC:     text description

  $0 --read-options-schema
    print the allowed keys and descriptions for global option entries
    formatted, one per line, like this:
    <KEY_NAME>=<DESC>
      KEY_NAME: one of: " . join(" ", getOptionsConfigKeys()) . "
      DESC:     text description
";

sub main(@){
  my $cmd = @_ > 0 ? shift : "--update";

  if($cmd =~ /^(-h|--help)$/){
    print $usage;
  }elsif($cmd =~ /^(--update)$/ and @_ >= 0){
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderNameFilter = optFolder \@_, undef;
    my @accNames = @_;
    my $success = cmdUpdate($folderNameFilter, @accNames);
    my $exitCode = $success ? 0 : 1;
    exit $exitCode;
  }elsif($cmd =~ /^(--smtp)$/ and @_ >= 4){
    my ($accName, $subject, $body, $to, @args) = @_;
    cmdSmtp($accName, $subject, $body, $to, @args);
  }elsif($cmd =~ /^(--mark-read|--mark-unread)$/ and @_ >= 2){
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    my $readStatus = $cmd =~ /^(--mark-read)$/ ? 1 : 0;
    cmdMarkReadUnread($readStatus, $accName, $folderName, @uids);
  }elsif($cmd =~ /^(--accounts)$/ and @_ == 0){
    cmdAccounts();
  }elsif($cmd =~ /^(--folders)$/ and @_ == 1){
    my $accName = shift;
    cmdFolders($accName);
  }elsif($cmd =~ /^(--header)$/ and @_ >= 2){
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    cmdHeader($accName, $folderName, @uids);
  }elsif($cmd =~ /^(--body|--body-plain|--body-html|--attachments)$/ and @_ >= 2){
    my $modeBodyAttachments;
    if($cmd =~ /^(--body|--body-plain|--body-html)$/){
      $modeBodyAttachments = "body";
    }elsif($cmd =~ /^(--attachments)$/){
      $modeBodyAttachments = "attachments";
    }else{
      die "failed to parsed cmd: $cmd\n";
    }
    my $wantPlain = $cmd eq "--body-plain" ? 1 : 0;
    my $wantHtml = $cmd eq "--body-html" ? 1 : 0;

    my $config = getConfig();
    my $noDownload = 0;
    if($modeBodyAttachments eq "body" and @_ > 0 and $_[0] =~ /^--no-download$/){
      $noDownload = 1;
      shift;
    }
    my $nulSep = 0;
    if($modeBodyAttachments eq "body" and @_ > 0 and $_[0] =~ /^-0$/){
      $nulSep = 1;
      shift;
    }
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, $destDir, @uids);
    if($modeBodyAttachments eq "body"){
      ($accName, @uids) = @_;
      $destDir = $$GVAR{TMP_DIR};
      die $usage if not defined $accName or @uids == 0;
    }elsif($modeBodyAttachments eq "attachments"){
      ($accName, $destDir, @uids) = @_;
      die $usage if not defined $accName or @uids == 0
        or not defined $destDir or not -d $destDir;
    }

    cmdBodyAttachments($modeBodyAttachments, $wantPlain, $wantHtml,
      $noDownload, $nulSep,
      $accName, $folderName, $destDir, @uids);
  }elsif($cmd =~ /^(--cache-all-bodies)$/ and @_ == 2){
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my ($accName, $folderName) = @_;
    cmdCacheAllBodies($accName, $folderName);
  }elsif($cmd =~ /^(--print)$/ and @_ >= 0){
    my $folderName = optFolder \@_, "inbox";
    my @accNames = @_;
    cmdPrint($folderName, @accNames);
  }elsif($cmd =~ /^(--summary)$/ and @_ >= 0){
    my $folderName = optFolder \@_, "inbox";
    my @accNames = @_;
    cmdSummary($folderName, @accNames);
  }elsif($cmd =~ /^(--status-line|--status-short)$/ and @_ >= 0){
    my $modeLineStatus;
    if($cmd =~ /^(--status-line)$/){
      $modeLineStatus = "line";
    }elsif($cmd =~ /^(--status-short)$/){
      $modeLineStatus = "short";
    }else{
      die "failed to parsed cmd: $cmd\n";
    }
    my @accNames = @_;
    cmdStatus($modeLineStatus, @accNames);
  }elsif($cmd =~ /^(--has-error)$/ and @_ >= 0){
    my @accNames = @_;
    if(cmdHasError(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--has-new-unread)$/ and @_ >= 0){
    my @accNames = @_;
    if(cmdHasNewUnread(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--has-unread)$/ and @_ >= 0){
    my @accNames = @_;
    if(cmdHasUnread(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--read-config)$/ and @_ == 1){
    my $account = shift;
    cmdReadConfigOptions "account", $account;
  }elsif($cmd =~ /^(--read-options)$/ and @_ ==0){
    cmdReadConfigOptions "options", undef;
  }elsif($cmd =~ /^(--write-config)$/ and @_ >= 2){
    my $accName = shift;
    cmdWriteConfigOptions "account", $accName, @_;
  }elsif($cmd =~ /^(--write-options)$/ and @_ >= 1){
    cmdWriteConfigOptions "options", undef, @_;
  }elsif($cmd =~ /^(--read-config-schema)$/ and @_ == 0){
    cmdReadConfigOptionsSchema "account";
  }elsif($cmd =~ /^(--read-options-schema)$/ and @_ == 0){
    cmdReadConfigOptionsSchema "options";
  }else{
    die $usage;
  }
}

sub optFolder($$){
  my ($opts, $default) = @_;
  my $folder;
  if(@$opts > 0 and $$opts[0] =~ /^--folder=(\w+)$/){
    my $folder = $1;
    shift @$opts;
    return $folder;
  }else{
    return $default;
  }
}

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

sub cmdSmtp($$$$@){
  my ($accName, $subject, $body, $to, @args) = @_;
  my $config = getConfig();
  my $acc = $$config{accounts}{$accName};
  die "Unknown account $accName\n" if not defined $acc;
  exec $$GVAR{SMTP_CLI_EXEC},
    "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
    "--user=$$acc{user}", "--pass=$$acc{password}",
    "--from=$$acc{user}",
    "--subject=$subject", "--body-plain=$body", "--to=$to",
    @args;
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

sub setFlagStatus($$$$){
  my ($c, $uid, $flag, $status) = @_;
  if($status){
    print "$uid $flag => true\n" if $$GVAR{VERBOSE};
    $c->set_flag($flag, $uid) or die "FAILED: set $flag on $uid\n";
  }else{
    print "$uid $flag => false\n" if $$GVAR{VERBOSE};
    $c->unset_flag($flag, $uid) or die "FAILED: unset flag on $uid\n";
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


sub getCachedHeaderUids($$){
  my ($accName, $folderName) = @_;
  my $headersDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/headers";
  my @cachedHeaders = `cd "$headersDir"; ls`;
  chomp foreach @cachedHeaders;
  return @cachedHeaders;
}
sub getCachedBodyUids($$){
  my ($accName, $folderName) = @_;
  my $bodiesDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  opendir DIR, $bodiesDir or die "Could not list $bodiesDir\n";
  my @cachedBodies;
  while (my $file = readdir(DIR)) {
    next if $file eq "." or $file eq "..";
    die "malformed file: $bodiesDir/$file\n" if $file !~ /^\d+$/;
    push @cachedBodies, $file;
  }
  closedir DIR;
  chomp foreach @cachedBodies;
  return @cachedBodies;
}

sub readCachedBody($$$){
  my ($accName, $folderName, $uid) = @_;
  my $bodyFile = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies/$uid";
  if(not -f $bodyFile){
    return undef;
  }
  return `cat "$bodyFile"`;
}

sub readCachedHeader($$$){
  my ($accName, $folderName, $uid) = @_;
  my $hdrFile = "$$GVAR{EMAIL_DIR}/$accName/$folderName/headers/$uid";
  if(not -f $hdrFile){
    return undef;
  }
  my $header = {};
  open FH, "< $hdrFile";
  binmode FH, ':utf8';
  my @lines = <FH>;
  close FH;
  for my $line(@lines){
    if($line =~ /^(\w+): (.*)$/){
      $$header{$1} = $2;
    }else{
      warn "WARNING: malformed header line: $line\n";
    }
  }
  return $header;
}

sub openFolder($$$){
  my ($imapFolder, $c, $allowEditing) = @_;
  print "Opening folder: $imapFolder\n" if $$GVAR{VERBOSE};

  my @folders = $c->folders($imapFolder);
  if(@folders != 1){
    return undef;
  }

  my $f = $folders[0];
  if($allowEditing){
    $c->select($f) or $f = undef;
  }else{
    $c->examine($f) or $f = undef;
  }
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
    my $socket = getSocket($acc);
    return undef if not defined $socket;

    $network = {
      Socket => $socket,
    };
  }
  my $sep = "="x50;
  print "$sep\n$$acc{name}: logging in\n$sep\n" if $$GVAR{VERBOSE};
  require Mail::IMAPClient;
  my $c = Mail::IMAPClient->new(
    %$network,
    User     => $$acc{user},
    Password => $$acc{password},
    %{$$GVAR{IMAP_CLIENT_SETTINGS}},
  );
  return undef if not defined $c or not $c->IsAuthenticated();
  return $c;
}

sub getSocket($){
  my $acc = shift;
  require IO::Socket::SSL;
  return IO::Socket::SSL->new(
    PeerAddr => $$acc{server},
    PeerPort => $$acc{port},
  );
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

sub accImapFolder($$){
  my ($acc, $folderName) = @_;
  accEnsureFoldersParsed $acc;
  return $$acc{parsedFolders}{$folderName};
}
sub accFolderOrder($){
  my ($acc) = @_;
  accEnsureFoldersParsed $acc;
  return @{$$acc{parsedFolderOrder}};
}
sub accEnsureFoldersParsed($){
  my $acc = shift;
  return if defined $$acc{parsedFolders};

  my @nameFolderPairs = @{parseFolders $acc};
  $$acc{parsedFolders} = {};
  $$acc{parsedFolderOrder} = [];
  for my $nameFolderPair(@{parseFolders $acc}){
    my ($name, $folder) = @$nameFolderPair;
    $$acc{parsedFolders}{$name} = $folder;
    push @{$$acc{parsedFolderOrder}}, $name;
  }
}

sub getFolderName($){
  my $folder = shift;
  my $name = lc $folder;
  $name =~ s/[^a-z0-9]+/_/g;
  $name =~ s/^_+//;
  $name =~ s/_+$//;
  return $name;
}

sub parseFolders($){
  my $acc = shift;
  my $folders = [];

  my $folder = defined $$acc{inbox} ? $$acc{inbox} : "INBOX";
  my $name = "inbox";
  push @$folders, [$name, $folder];

  if(defined $$acc{sent}){
    my $folder = $$acc{sent};
    my $name = "sent";
    push @$folders, [$name, $folder];
  }
  if(defined $$acc{folders}){
    for my $folder(split /:/, $$acc{folders}){
      $folder =~ s/^\s*//;
      $folder =~ s/\s*$//;
      my $name = getFolderName $folder;
      push @$folders, [$name, $folder];
    }
  }
  return $folders;
}
sub parseCountIncludeFolderNames($){
  my $acc = shift;
  my $countInclude = $$acc{count_include};
  $countInclude = "inbox" if not defined $countInclude;

  my $countIncludeFolderNames = [split /:/, $countInclude];
  s/^\s*// foreach @$countIncludeFolderNames;
  s/\s*$// foreach @$countIncludeFolderNames;

  my $folders = parseFolders $acc;
  my $okFolderNames = join "|", map {$$_[0]} @$folders;

  my $seenFolderNames = {};
  for my $folderName(@$countIncludeFolderNames){
    if(defined $$seenFolderNames{$folderName}){
      die "ERROR: duplicate folder name in count_include: $folderName\n";
    }
    $$seenFolderNames{$folderName} = 1;
    if($folderName !~ /^($okFolderNames)$/){
      die "ERROR: count_include folder name '$folderName' not found in:\n"
        . "  [$okFolderNames]\n";
    }
  }

  return $countIncludeFolderNames;
}

sub hasWords($){
  my $msg = shift;
  $msg =~ s/\W+//g;
  return length($msg) > 0;
}

&main(@ARGV);
