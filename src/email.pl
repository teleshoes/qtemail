#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use Mail::IMAPClient;
use IO::Socket::SSL;
use MIME::Parser;
use Date::Parse qw(str2time);
use Date::Format qw(time2str);

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
sub getFolderName($);
sub parseFolders($);
sub parseCountIncludeFolderNames($);
sub hasWords($);
sub formatSchemaSimple($);
sub formatSchemaPretty($$);
sub readSecrets();
sub validateSecrets($);
sub modifySecrets($$);

my $VERBOSE = 0;
my $DATE_FORMAT = "%Y-%m-%d %H:%M:%S";
my $MAX_BODIES_TO_CACHE = 100;

my $EMAIL_SEARCH_EXEC = "/opt/qtemail/bin/email-search.pl";
my $UPDATEDB_LIMIT = 100;

my $SMTP_CLI_EXEC = "/opt/qtemail/bin/smtp-cli";
my $TMP_DIR = "/var/tmp";

my $secretsFile = "$ENV{HOME}/.secrets";
my $secretsPrefix = "email";
my $accountConfigSchema = [
  ["user",            "REQ", "IMAP username, usually the full email address"],
  ["password",        "REQ", "password, stored with optional encrypt_cmd"],
  ["server",          "REQ", "IMAP server, e.g.: \"imap.gmail.com\""],
  ["port",            "REQ", "IMAP server port"],

  ["smtp_server",     "OPT", "SMTP server, e.g.: \"smtp.gmail.com\""],
  ["smtp_port",       "OPT", "SMTP server port"],
  ["ssl",             "OPT", "set to false to forcibly disable security"],
  ["inbox",           "OPT", "primary IMAP folder name (default=\"INBOX\")"],
  ["sent",            "OPT", "IMAP folder name to use for sent mail, e.g.:\"Sent\""],
  ["folders",         "OPT", "extra IMAP folders to fetch (sep=\":\")"],
  ["count_include",   "OPT", "FOLDER_NAMEs for counts (default=\"inbox\", sep=\":\")"],
  ["skip",            "OPT", "set to true to skip during --update"],
  ["body_cache_mode", "OPT", "one of [unread|all|none] (default=\"unread\")"],
  ["prefer_html",     "OPT", "prefer html over plaintext (default=\"false\")"],
  ["new_unread_cmd",  "OPT", "custom alert command"],
  ["update_interval", "OPT", "GUI: seconds between account updates"],
  ["refresh_interval","OPT", "GUI: seconds between account refresh"],
  ["filters",         "OPT", "GUI: list of filter-buttons, e.g.:\"s1=%a% s2=%b%\""],
];
my $optionsConfigSchema = [
  ["update_cmd",      "OPT", "command to run after all updates"],
  ["encrypt_cmd",     "OPT", "command to encrypt passwords on disk"],
  ["decrypt_cmd",     "OPT", "command to decrypt saved passwords"],
];
my $longDescriptions = {
  folders => ''
    . "the FOLDER_NAME used as the dir on the filesystem\n"
    . "has non-alphanumeric substrings replaced with _s\n"
    . "and all leading and trailing _s removed\n"
    . "e.g.:\n"
    . "  email.Z.folders = junk:[GMail]/Drafts:_12_/ponies\n"
    . "    =>  [\"junk\", \"gmail_drafts\", \"12_ponies\"]\n"
  ,
  count_include => ''
    . "list of FOLDER_NAMEs for account-wide unread/total counts\n"
    . "this controls what gets written to the global unread file,\n"
    . "  and what is returned by --accounts\n"
    . "note this is the FOLDER_NAME, and not the IMAP folder\n"
    . "e.g.:\n"
    . "  email.Z.sent = [GMail]/Sent Mail\n"
    . "  email.Z.folders = [GMail]/Spam:[GMail]/Drafts\n"
    . "  email.Z.count_include = inbox:gmail_spam:sent\n"
    . "    => included: INBOX, [GMail]/Spam, [GMail]/Sent Mail\n"
    . "       excluded: [GMail]/Drafts\n"
  ,
  body_cache_mode => ''
    . "controls which bodies get cached during --update\n"
    . "  (note: only caches the first MAX_BODIES_TO_CACHE=$MAX_BODIES_TO_CACHE)\n"
    . "unread: cache unread bodies (up to $MAX_BODIES_TO_CACHE)\n"
    . "all:    cache all bodies (up to $MAX_BODIES_TO_CACHE)\n"
    . "none:   do not cache bodies during --update\n"
  ,
  filters => ''
    . "each filter is separated by a space, and takes the form:\n"
    . "  <FILTER_NAME>=%<FILTER_STRING>%\n"
    . "FILTER_NAME:   the text of the button in the GUI\n"
    . "FILTER_STRING: query for $EMAIL_SEARCH_EXEC\n"
    . "e.g.:\n"
    . "  email.Z.filters = mary=%from~\"mary sue\"% ok=%body!~viagra%\n"
    . "    => [\"mary\", \"ok\"]\n"
  ,
};

my @accConfigKeys = map {$$_[0]} grep {$$_[1] eq "REQ"} @$accountConfigSchema;
my @accExtraConfigKeys = map {$$_[0]} grep {$$_[1] eq "OPT"} @$accountConfigSchema;
my %enums = (
  body_cache_mode => [qw(all unread none)],
);
my @optionsConfigKeys = map {$$_[0]} @$optionsConfigSchema;

my @headerFields = qw(Date Subject From To CC BCC);
my $emailDir = "$ENV{HOME}/.cache/email";
my $unreadCountsFile = "$emailDir/unread-counts";
my $statusLineFile = "$emailDir/status-line";
my $statusShortFile = "$emailDir/status-short";

my $html2textExec = "/usr/bin/html2text";

my $settings = {
  Peek => 1,
  Uid => 1,
  Ignoresizeerrors => 1,
};

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
  Configuration is in $secretsFile
    Each config entry is one line of the format:
      $secretsPrefix.GLOBAL_OPTION_KEY = <value>
      or
      $secretsPrefix.ACCOUNT_NAME.ACCOUNT_CONFIG_KEY = <value>

    Account names can be any word characters (alphanumeric plus underscore)
    Lines that do not begin with \"$secretsPrefix.\" are ignored.

    ACCOUNT_NAME:    the word following \"$secretsPrefix.\" in $secretsFile\n
    FOLDER_NAME:     \"inbox\", \"sent\" or one of the names from \"folders\"\n
    UID:             an IMAP UID {UIDVALIDITY is assumed to never change}\n
    GLOBAL_OPTION_KEY:\n" . formatSchemaPretty($optionsConfigSchema, "      ") . "
    ACCOUNT_CONFIG_KEY:\n" . formatSchemaPretty($accountConfigSchema, "      ") . "

  $0 -h|--help
    show this message

  $0 [--update] [--folder=FOLDER_NAME_FILTER] [ACCOUNT_NAME ACCOUNT_NAME ...]
    -for each account specified {or all non-skipped accounts if none are specified}:
      -login to IMAP server, or create file $emailDir/ACCOUNT_NAME/error
      -for each FOLDER_NAME {or just FOLDER_NAME_FILTER if specified}:
        -fetch and write all message UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/all
        -fetch and cache all message headers in
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/headers/UID
        -fetch and cache bodies according to body_cache_mode config
            all    => every header that was cached gets its body cached
            unread => every unread message gets its body cached
            none   => no bodies are cached
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/bodies/UID
        -fetch all unread messages and write their UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/unread
        -write all message UIDs that are now in unread and were not before
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/new-unread
        -run $EMAIL_SEARCH_EXEC --updatedb ACCOUNT_NAME FOLDER_NAME $UPDATEDB_LIMIT
    -update global unread counts file $unreadCountsFile
      count the unread emails for each account in the folders in count_include
      the default is just to include the counts for \"inbox\"

      write the unread counts, one line per account, to $unreadCountsFile
      e.g.: 3:AOL
            6:GMAIL
            0:WORK_GMAIL

  $0 --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
    simple wrapper around smtp-cli. {you can add extra recipients with --to}
    calls:
      $SMTP_CLI_EXEC \\
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
    prints each of [@headerFields]
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
      (uses $html2textExec if available, or just strips out the tags)

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
    {cached in $statusLineFile when $unreadCountsFile or error files change}
    does not fetch anything, merely reads $unreadCountsFile
    format and print $unreadCountsFile
    the string is a space-separated list of the first character of
      each account name followed by the integer count
    no newline character is printed
    if the count is zero for a given account, it is omitted
    if accounts are specified, all but those are omitted
    e.g.: A3 G6

  $0 --status-short [ACCOUNT_NAME ACCOUNT_NAME ...]
    {cached in $statusShortFile when $unreadCountsFile or error files change}
    does not fetch anything, merely reads $unreadCountsFile
    format and print $unreadCountsFile
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
    checks if $emailDir/ACCOUNT_NAME/error exists
    print \"yes\" and exit with zero exit code if it does
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-new-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any NEW unread emails, in any account
      {UIDs in $emailDir/ACCOUNT_NAME/new-unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are new unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --has-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
    checks for any unread emails, in any account
      {UIDs in $emailDir/ACCOUNT_NAME/unread}
    if accounts are specified, all but those are ignored
    print \"yes\" and exit with zero exit code if there are unread emails
    otherwise, print \"no\" and exit with non-zero exit code

  $0 --read-config ACCOUNT_NAME
    reads $secretsFile
    for each line of the form \"$secretsPrefix.ACCOUNT_NAME.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-config ACCOUNT_NAME KEY=VAL [KEY=VAL KEY=VAL]
    modifies $secretsFile
    for each KEY/VAL pair:
      removes any line that matches \"$secretsPrefix.ACCOUNT_NAME.KEY\\s*=\"
      adds a line at the end \"$secretsPrefix.ACCOUNT_NAME.KEY = VAL\"

  $0 --read-options
    reads $secretsFile
    for each line of the form \"$secretsPrefix.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --write-options KEY=VAL [KEY=VAL KEY=VAL]
    reads $secretsFile
    for each line of the form \"$secretsPrefix.KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --read-config-schema
    print the allowed keys and descriptions for account config entries
    formatted, one per line, like this:
    <KEY_NAME>=<DESC>
      KEY_NAME: one of: @accConfigKeys @accExtraConfigKeys
      DESC:     text description

  $0 --read-config-schema
    print the allowed keys and descriptions for account config entries
    formatted, one per line, like this:
    <KEY_NAME>=<DESC>
      KEY_NAME: one of: @optionsConfigKeys
      DESC:     text description
";

sub main(@){
  my $cmd = shift if @_ > 0 and $_[0] =~ /^($okCmds)$/;
  $cmd = "--update" if not defined $cmd;

  die $usage if @_ > 0 and $_[0] =~ /^(-h|--help)$/;

  if($cmd =~ /^(--read-config|--read-options)$/){
    my $configGroup;
    if($cmd eq "--read-config"){
      die $usage if @_ != 1;
      $configGroup = shift;
    }elsif($cmd eq "--read-options"){
      die $usage if @_ != 0;
      $configGroup = undef;
    }
    my $config = readSecrets;
    my $accounts = $$config{accounts};
    my $options = $$config{options};
    my $vals = defined $configGroup ? $$accounts{$configGroup} : $options;
    if(defined $vals){
      for my $key(sort keys %$vals){
        print "$key=$$vals{$key}\n";
      }
    }
    exit 0;
  }elsif($cmd =~ /^(--write-config|--write-options)$/){
    my $configGroup;
    if($cmd eq "--write-config"){
      die $usage if @_ < 2;
      $configGroup = shift;
    }elsif($cmd eq "--write-options"){
      die $usage if @_ < 1;
      $configGroup = undef;
    }
    my @keyValPairs = @_;
    my $config = {};
    for my $keyValPair(@keyValPairs){
      if($keyValPair =~ /^(\w+)=(.*)$/){
        $$config{$1} = $2;
      }else{
        die "Malformed KEY=VAL pair: $keyValPair\n";
      }
    }
    modifySecrets $configGroup, $config;
    exit 0;
  }elsif($cmd =~ /^(--read-config-schema|--read-options-schema)$/){
    my $schema;
    $schema = $accountConfigSchema if $cmd =~ /--read-config-schema/;
    $schema = $optionsConfigSchema if $cmd =~ /--read-options-schema/;
    print formatSchemaSimple $schema;
    exit 0;
  }

  my $config = readSecrets();
  validateSecrets $config;
  my @accOrder = @{$$config{accOrder}};
  my $accounts = $$config{accounts};
  my %accNameFolderPairs = map {$_ => parseFolders $$accounts{$_}} keys %$accounts;
  my %accFolders;
  my %accFolderOrder;
  for my $acc(keys %$accounts){
    my @nameFolderPairs = @{$accNameFolderPairs{$acc}};
    $accFolders{$acc} = {map {$$_[0] => $$_[1]} @nameFolderPairs};
    $accFolderOrder{$acc} = [map {$$_[0]} @nameFolderPairs];
  }

  if($cmd =~ /^(--update)$/){
    $VERBOSE = 1;
    my $folderNameFilter;
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderNameFilter = $1;
      shift;
    }
    my @accNames;
    if(@_ == 0){
      for my $accName(@accOrder){
        my $skip = $$accounts{$accName}{skip};
        if(not defined $skip or $skip !~ /^true$/i){
          push @accNames, $accName;
        }
      }
    }else{
      @accNames = @_;
    }

    my $isError = 0;
    my @newUnreadCommands;
    for my $accName(@accNames){
      my $acc = $$accounts{$accName};
      die "Unknown account $accName\n" if not defined $acc;
      clearError $accName;
      my $c = getClient($acc);
      if(not defined $c){
        $isError = 1;
        my $msg = "ERROR: Could not authenticate $$acc{name} ($$acc{user})\n";
        warn $msg;
        writeError $accName, $msg;
        writeStatusFiles(@accOrder);
        next;
      }

      my $folders = $accFolders{$accName};
      my @folderOrder = @{$accFolderOrder{$accName}};
      my $hasNewUnread = 0;
      for my $folderName(@folderOrder){
        if(defined $folderNameFilter and $folderName ne $folderNameFilter){
          print "skipping $folderName\n";
          next;
        }
        my $imapFolder = $$folders{$folderName};
        my $f = openFolder($imapFolder, $c, 0);
        if(not defined $f){
          $isError = 1;
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

        cacheBodies($accName, $folderName, $c, $MAX_BODIES_TO_CACHE, @toCache);

        $c->close();

        my %oldUnread = map {$_ => 1} readUidFile $accName, $folderName, "unread";
        writeUidFile $accName, $folderName, "unread", @unread;
        my @newUnread = grep {not defined $oldUnread{$_}} @unread;
        writeUidFile $accName, $folderName, "new-unread", @newUnread;
        $hasNewUnread = 1 if @newUnread > 0;

        print "running updatedb\n";
        system $EMAIL_SEARCH_EXEC, "--updatedb", $accName, $folderName, $UPDATEDB_LIMIT;
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
    exit $isError ? 1 : 0;
  }elsif($cmd =~ /^(--smtp)$/){
    die $usage if @_ < 4;
    my ($accName, $subject, $body, $to, @args) = @_;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    exec $SMTP_CLI_EXEC,
      "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
      "--user=$$acc{user}", "--pass=$$acc{password}",
      "--from=$$acc{user}",
      "--subject=$subject", "--body-plain=$body", "--to=$to",
      @args;
  }elsif($cmd =~ /^(--mark-read|--mark-unread)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    $VERBOSE = 1;
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    my $readStatus = $cmd =~ /^(--mark-read)$/ ? 1 : 0;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    my $imapFolder = $accFolders{$accName}{$folderName};
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
  }elsif($cmd =~ /^(--accounts)$/){
    die $usage if @_ != 0;
    for my $accName(@accOrder){
      my $acc = $$accounts{$accName};
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
      my $updateInterval = $$accounts{$accName}{update_interval};
      if(not defined $updateInterval){
        $updateInterval = 0;
      }
      $updateInterval .= "s";
      my $refreshInterval = $$accounts{$accName}{refresh_interval};
      if(not defined $refreshInterval){
        $refreshInterval = 0;
      }
      $refreshInterval .= "s";
      print "$accName:$lastUpdated:$lastUpdatedRel:$updateInterval:$refreshInterval:$unreadCount/$totalCount:$error\n";
    }
  }elsif($cmd =~ /^(--folders)$/){
    die $usage if @_ != 1;
    my $accName = shift;
    my $folders = $accFolders{$accName};
    my @folderOrder = @{$accFolderOrder{$accName}};
    for my $folderName(@folderOrder){
      my $unreadCount = readUidFileCounts $accName, $folderName, "unread";
      my $totalCount = readUidFileCounts $accName, $folderName, "all";
      printf "$folderName:$unreadCount/$totalCount\n";
    }
  }elsif($cmd =~ /^(--header)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    binmode STDOUT, ':utf8';
    for my $uid(@uids){
      my $hdr = readCachedHeader($accName, $folderName, $uid);
      die "Unknown message: $uid\n" if not defined $hdr;
      for my $field(@headerFields){
        print "$uid.$field: $$hdr{$field}\n";
      }
    }
  }elsif($cmd =~ /^(--body|--body-plain|--body-html|--attachments)$/){
    my $folderName = "inbox";
    my $noDownload = 0;
    my $nulSep = 0;
    if($cmd =~ /^--body/ and @_ > 0 and $_[0] =~ /^--no-download$/){
      $noDownload = 1;
      shift;
    }
    if($cmd =~ /^--body/ and @_ > 0 and $_[0] =~ /^-0$/){
      $nulSep = 1;
      shift;
    }
    if(@_ > 0 and $_[0] =~ /^--folder=([a-zA-Z_]+)$/){
      $folderName = $1;
      shift;
    }
    die $usage if @_ < 2;
    my ($accName, $destDir, @uids);
    if($cmd =~ /^(--body|--body-plain|--body-html)/){
      ($accName, @uids) = @_;
      $destDir = $TMP_DIR;
      die $usage if not defined $accName or @uids == 0;
    }elsif($cmd =~ /^(--attachments)$/){
      ($accName, $destDir, @uids) = @_;
      die $usage if not defined $accName or @uids == 0
        or not defined $destDir or not -d $destDir;
    }

    my $acc = $$accounts{$accName};
    my $preferHtml = 0;
    $preferHtml = 1 if defined $$acc{prefer_html} and $$acc{prefer_html} =~ /true/i;
    $preferHtml = 0 if $cmd eq "--body-plain";
    $preferHtml = 1 if $cmd eq "--body-html";
    die "Unknown account $accName\n" if not defined $acc;
    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $c;
    my $f;
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
      if($cmd =~ /^(--body|--body-plain|--body-html)$/){
        my $fmt = getBody($mimeParser, $body, $preferHtml);
        chomp $fmt;
        $fmt = html2text $fmt if $cmd =~ /^(--body-plain)$/;
        print $fmt;
        print $nulSep ? "\0" : "\n";
      }elsif($cmd =~ /^(--attachments)$/){
        my @attachments = writeAttachments($mimeParser, $body);
        for my $attachment(@attachments){
          print " saved att: $attachment\n";
        }
      }
    }
    $c->close() if defined $c;
    $c->logout() if defined $c;
  }elsif($cmd =~ /^(--cache-all-bodies)$/){
    $VERBOSE = 1;
    die $usage if @_ != 2;
    my ($accName, $folderName) = @_;

    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    my $c = getClient($acc);
    die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;

    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $f = openFolder($imapFolder, $c, 0);
    die "Error getting folder $folderName\n" if not defined $f;

    my @messages = $c->messages;
    cacheBodies($accName, $folderName, $c, undef, @messages);
  }elsif($cmd =~ /^(--print)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $mimeParser = MIME::Parser->new();
    $mimeParser->output_dir($TMP_DIR);
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
  }elsif($cmd =~ /^(--summary)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my @accNames = @_ == 0 ? @accOrder : @_;
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
  }elsif($cmd =~ /^(--status-line|--status-short)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $counts = readGlobalUnreadCountsFile();
    if($cmd eq "--status-line"){
      print formatStatusLine($counts, @accNames);
    }elsif($cmd eq "--status-short"){
      print formatStatusShort($counts, @accNames);
    }
  }elsif($cmd =~ /^(--has-error)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    for my $accName(@accNames){
      if(hasError $accName){
        print "yes\n";
        exit 0;
      }
    }
    print "no\n";
    exit 1;
  }elsif($cmd =~ /^(--has-new-unread)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my @fmts;
    for my $accName(@accNames){
      my $folders = $accFolders{$accName};
      my @folderOrder = @{$accFolderOrder{$accName}};
      for my $folderName(@folderOrder){
        my $unread = readUidFileCounts $accName, $folderName, "new-unread";
        if($unread > 0){
          print "yes\n";
          exit 0;
        }
      }
    }
    print "no\n";
    exit 1;
  }elsif($cmd =~ /^(--has-unread)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my @fmts;
    for my $accName(@accNames){
      my $folders = $accFolders{$accName};
      my @folderOrder = @{$accFolderOrder{$accName}};
      for my $folderName(@folderOrder){
        my $unread = readUidFileCounts $accName, $folderName, "unread";
        if($unread > 0){
          print "yes\n";
          exit 0;
        }
      }
    }
    print "no\n";
    exit 1;
  }
}

sub setFlagStatus($$$$){
  my ($c, $uid, $flag, $status) = @_;
  if($status){
    print "$uid $flag => true\n" if $VERBOSE;
    $c->set_flag($flag, $uid) or die "FAILED: set $flag on $uid\n";
  }else{
    print "$uid $flag => false\n" if $VERBOSE;
    $c->unset_flag($flag, $uid) or die "FAILED: unset flag on $uid\n";
  }
}

sub writeStatusFiles(@){
  my @accNames = @_;
  my $counts = readGlobalUnreadCountsFile();

  my $fmt;
  $fmt = formatStatusLine $counts, @accNames;
  open FH, "> $statusLineFile" or die "Could not write $statusLineFile\n";
  print FH $fmt;
  close FH;

  $fmt = formatStatusShort $counts, @accNames;
  open FH, "> $statusShortFile" or die "Could not write $statusShortFile\n";
  print FH $fmt;
  close FH;
}
sub formatStatusLine($@){
  my ($counts, @accNames) = @_;
  my @fmts;
  for my $accName(@accNames){
    die "Unknown account $accName\n" if not defined $$counts{$accName};
    my $count = $$counts{$accName};
    my $errorFile = "$emailDir/$accName/error";
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
    my $errorFile = "$emailDir/$accName/error";
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
  if(-x $html2textExec){
    my $tmpFile = "/tmp/email_tmp_" . int(time*1000) . ".html";
    open FH, "> $tmpFile" or die "Could not write to $tmpFile\n";
    print FH $html;
    close FH;
    my $text = `$html2textExec $tmpFile`;
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

  open FH, "> $unreadCountsFile" or die "Could not write $unreadCountsFile\n";
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
  my $errorFile = "$emailDir/$accName/error";
  return -f $errorFile;
}
sub clearError($){
  my ($accName) = @_;
  my $errorFile = "$emailDir/$accName/error";
  system "rm", "-f", $errorFile;
}
sub readError($){
  my ($accName) = @_;
  my $errorFile = "$emailDir/$accName/error";
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
  my $errorFile = "$emailDir/$accName/error";
  open FH, "> $errorFile" or die "Could not write to $errorFile\n";
  print FH $msg;
  close FH;
}

sub readLastUpdated($){
  my ($accName) = @_;
  my $f = "$emailDir/$accName/last_updated";
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
  my $f = "$emailDir/$accName/last_updated";
  open FH, "> $f" or die "Could not write to $f\n";
  print FH time . "\n";
  close FH;
}

sub readUidFileCounts($$$){
  my ($accName, $folderName, $fileName) = @_;
  my $dir = "$emailDir/$accName/$folderName";

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
  my $dir = "$emailDir/$accName/$folderName";

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
  my $dir = "$emailDir/$accName/$folderName";
  system "mkdir", "-p", $dir;

  open FH, "> $dir/$fileName" or die "Could not write $dir/$fileName\n";
  print FH "$_\n" foreach @uids;
  close FH;
}

sub cacheAllHeaders($$$){
  my ($accName, $folderName, $c) = @_;
  print "fetching all message ids\n" if $VERBOSE;
  my @messages = $c->messages;
  print "fetched " . @messages . " ids\n" if $VERBOSE;

  my $dir = "$emailDir/$accName/$folderName";
  writeUidFile $accName, $folderName, "all", @messages;

  my $headersDir = "$dir/headers";
  system "mkdir", "-p", $headersDir;

  my %toSkip = map {$_ => 1} getCachedHeaderUids($accName, $folderName);

  @messages = grep {not defined $toSkip{$_}} @messages;
  my $total = @messages;

  print "downloading headers for $total messages\n" if $VERBOSE;
  my $headers = $c->parse_headers(\@messages, @headerFields);

  print "encoding and formatting $total headers\n" if $VERBOSE;
  my $count = 0;
  my $segment = int($total/20);

  if($VERBOSE){
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
      print "#$pct%\n" if $VERBOSE;
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
  print "\n" if $segment > 0 and $VERBOSE;

  my @cachedBodyUids = getCachedBodyUids($accName, $folderName);
  my %okCachedHeaderUids = map {$_ => 1} getCachedHeaderUids($accName, $folderName);
  for my $uid(@cachedBodyUids){
    if(not defined $okCachedHeaderUids{$uid}){
      warn "\n!!!!!\nDELETED MESSAGE: $uid is cached in bodies, but not on server\n";
      my $mimeParser = MIME::Parser->new();
      $mimeParser->output_dir($TMP_DIR);

      my $cachedBody = readCachedBody($accName, $folderName, $uid);

      my $hdr = getHeaderFromBody($mimeParser, $cachedBody);
      cacheHeader $hdr, $uid, $accName, $headersDir, {}, {}, {};
      warn "  cached $uid using MIME entity in body cache\n\n";
    }
  }

  return @messages;
}

sub cacheHeader($$$$$$$){
  my ($hdr, $uid, $accName, $headersDir,
    $missingFields, $newlineFields, $nullFields) = @_;
  my @fmtLines;
  my @rawLines;
  for my $field(@headerFields){
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
  my $bodiesDir = "$emailDir/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  local $| = 1;

  my %toSkip = map {$_ => 1} getCachedBodyUids($accName, $folderName);
  @messages = grep {not defined $toSkip{$_}} @messages;
  if(defined $maxCap and $maxCap > 0 and @messages > $maxCap){
    my $count = @messages;
    print "only caching $maxCap out of $count\n" if $VERBOSE;
    @messages = reverse @messages;
    @messages = splice @messages, 0, $maxCap;
    @messages = reverse @messages;
  }
  print "caching bodies for " . @messages . " messages\n" if $VERBOSE;
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
      print "  {cached $count/$total bodies} $pct%  $date\n" if $VERBOSE;
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
  # my $headers = $c->parse_headers($uid, @headerFields)
  # my $hdr = $$headers{$uid};
  # return $hdr;
  my $hdr = {};
  for my $field(@headerFields){
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
  my $headersDir = "$emailDir/$accName/$folderName/headers";
  my @cachedHeaders = `cd "$headersDir"; ls`;
  chomp foreach @cachedHeaders;
  return @cachedHeaders;
}
sub getCachedBodyUids($$){
  my ($accName, $folderName) = @_;
  my $bodiesDir = "$emailDir/$accName/$folderName/bodies";
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
  my $bodyFile = "$emailDir/$accName/$folderName/bodies/$uid";
  if(not -f $bodyFile){
    return undef;
  }
  return `cat "$bodyFile"`;
}

sub readCachedHeader($$$){
  my ($accName, $folderName, $uid) = @_;
  my $hdrFile = "$emailDir/$accName/$folderName/headers/$uid";
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
  print "Opening folder: $imapFolder\n" if $VERBOSE;

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
  print "$sep\n$$acc{name}: logging in\n$sep\n" if $VERBOSE;
  my $c = Mail::IMAPClient->new(
    %$network,
    User     => $$acc{user},
    Password => $$acc{password},
    %$settings,
  );
  return undef if not defined $c or not $c->IsAuthenticated();
  return $c;
}

sub getSocket($){
  my $acc = shift;
  return IO::Socket::SSL->new(
    PeerAddr => $$acc{server},
    PeerPort => $$acc{port},
  );
}

sub formatHeaderField($$){
  my ($field, $val) = @_;
  $val = decode('MIME-Header', $val);
  if($field =~ /^(Date)$/){
    $val = formatDate($val);
  }
  return $val;
}

sub formatDate($){
  my $date = shift;
  my $d = str2time($date);
  if(defined $d){
    return time2str($DATE_FORMAT, $d);
  }
  return $date;
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

sub formatSchemaSimple($){
  my ($schema) = @_;
  my $fmt = '';
  for my $row(@$schema){
    my ($name, $reqOpt, $desc) = @$row;
    $fmt .= "$name=[$reqOpt] $desc\n";
  }
  return $fmt;
}
sub formatSchemaPretty($$){
  my ($schema, $indent) = @_;
  my $maxNameLen = 0;
  for my $nameLen(map {length $$_[0]} @$schema){
    $maxNameLen = $nameLen if $nameLen > $maxNameLen;
  }
  my $fmt = '';
  for my $row(@$schema){
    my ($name, $reqOpt, $desc) = @$row;
    my $sep = ' ' x (1 + $maxNameLen - length $name);
    my $prefix = $indent . $name . $sep;
    my $info = "[$reqOpt] $desc\n";
    if(defined $$longDescriptions{$name}){
      my $infoIndent = ' ' x (length $prefix);
      my @longLines = split /\n/, $$longDescriptions{$name};
      @longLines = map {"$infoIndent$_\n"} @longLines;
      $info .= join '', @longLines;
    }
    $fmt .= "$prefix$info";
  }
  return $fmt;
}

sub joinTrailingBackslashLines(@){
  my @oldLines = @_;
  my @lines;

  my $curLine = undef;
  for my $line(@oldLines){
    my $isBackslashLine = $line =~ /\\\s*\n?/;

    $curLine = '' if not defined $curLine;
    $curLine .= $line;

    if(not $isBackslashLine){
      push @lines, $curLine;
      $curLine = undef;
    }
  }
  push @lines, $curLine if defined $curLine;

  return @lines;
}

sub readSecrets(){
  my @lines = `cat $secretsFile 2>/dev/null`;
  my $accounts = {};
  my $accOrder = [];
  my $okAccConfigKeys = join "|", (@accConfigKeys, @accExtraConfigKeys);
  my $okOptionsConfigKeys = join "|", (@optionsConfigKeys);
  my $optionsConfig = {};
  my $decryptCmd;
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.decrypt_cmd\s*=\s*(.*)$/){
      $decryptCmd = $1;
      last;
    }
  }

  @lines = joinTrailingBackslashLines(@lines);

  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.($okOptionsConfigKeys)\s*=\s*(.+)$/s){
      $$optionsConfig{$1} = $2;
    }elsif($line =~ /^$secretsPrefix\.(\w+)\.($okAccConfigKeys)\s*=\s*(.+)$/s){
      my ($accName, $key, $val)= ($1, $2, $3);
      if(not defined $$accounts{$accName}){
        $$accounts{$1} = {name => $accName};
        push @$accOrder, $accName;
      }
      if(defined $decryptCmd and $key =~ /password/){
        $val =~ s/'/'\\''/g;
        $val = `$decryptCmd '$val'`;
        die "error encrypting password\n" if $? != 0;
      }
      chomp $val;
      $$accounts{$accName}{$key} = $val;
    }elsif($line =~ /^$secretsPrefix\./){
      die "unknown config entry: $line";
    }
  }
  return {accounts => $accounts, accOrder => $accOrder, options => $optionsConfig};
}

sub validateSecrets($){
  my $config = shift;
  my $accounts = $$config{accounts};
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    for my $key(sort @accConfigKeys){
      die "Missing '$key' for '$accName' in $secretsFile\n" if not defined $$acc{$key};
    }
  }
}

sub modifySecrets($$){
  my ($configGroup, $config) = @_;
  my $prefix = "$secretsPrefix";
  if(defined $configGroup){
    if($configGroup !~ /^\w+$/){
      die "invalid account name, must be a word i.e.: \\w+\n";
    }
    $prefix .= ".$configGroup";
  }

  my @lines = `cat $secretsFile 2>/dev/null`;
  @lines = joinTrailingBackslashLines(@lines);

  my $encryptCmd;
  for my $line(@lines){
    if(not defined $encryptCmd and $line =~ /^$secretsPrefix\.encrypt_cmd\s*=\s*(.*)$/s){
      $encryptCmd = $1;
    }
  }

  my %requiredConfigKeys = map {$_ => 1} @accConfigKeys;

  my $okConfigKeys = join "|", (@accConfigKeys, @accExtraConfigKeys);
  my $okOptionsKeys = join "|", (@optionsConfigKeys);
  for my $key(sort keys %$config){
    if(defined $configGroup){
      die "Unknown config key: $key\n" if $key !~ /^($okConfigKeys)$/;
    }else{
      die "Unknown options key: $key\n" if $key !~ /^($okOptionsKeys)$/;
    }
    my $val = $$config{$key};
    my $valEmpty = $val =~ /^\s*$/;
    if($valEmpty){
      if(defined $configGroup and defined $requiredConfigKeys{$key}){
        die "must include '$key'\n";
      }
    }
    if(defined $encryptCmd and $key =~ /password/i){
      $val =~ s/'/'\\''/g;
      $val = `$encryptCmd '$val'`;
      die "error encrypting password\n" if $? != 0;
      chomp $val;
    }
    my $newLine = $valEmpty ? '' : "$prefix.$key = $val\n";
    my $found = 0;
    for my $line(@lines){
      if($line =~ s/^$prefix\.$key\s*=.*\n$/$newLine/s){
        $found = 1;
        last;
      }
    }
    if(not $valEmpty and defined $enums{$key}){
      my $okEnum = join '|', @{$enums{$key}};
      die "invalid $key: $val\nexpects: $okEnum" if $val !~ /^($okEnum)$/;
    }
    push @lines, $newLine if not $found;
  }

  open FH, "> $secretsFile" or die "Could not write $secretsFile\n";
  print FH @lines;
  close FH;
}

&main(@ARGV);
