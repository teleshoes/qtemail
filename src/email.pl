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
    VERBOSE => 0,
    DATE_FORMAT => "%Y-%m-%d %H:%M:%S",
    MAX_BODIES_TO_CACHE => 100,
    UPDATEDB_LIMIT => 100,

    EMAIL_SEARCH_EXEC => "/opt/qtemail/bin/email-search.pl",
    SMTP_CLI_EXEC => "/opt/qtemail/bin/smtp-cli",
    HTML2TEXT_EXEC => "/usr/bin/html2text",

    TMP_DIR => "/var/tmp",

    EMAIL_DIR => $baseDir,
    UNREAD_COUNTS_FILE => "$baseDir/unread-counts",
    STATUS_LINE_FILE => "$baseDir/status-line",
    STATUS_SHORT_FILE => "$baseDir/status-short",

    IMAP_CLIENT_SETTINGS => {
      Peek => 1,
      Uid => 1,
      Ignoresizeerrors => 1,
    },
    HEADER_FIELDS => [qw(Date Subject From To CC BCC)],
  });
}

use QtEmail::Shared qw(GET_GVAR MODIFY_GVAR);
use QtEmail::Config qw(
  getConfig
  formatSchemaPretty
  getConfigFile getConfigPrefix
  getAccountConfigSchema getOptionsConfigSchema
  getAccReqConfigKeys getAccOptConfigKeys getAccMapConfigKeys
  getOptionsConfigKeys
);

sub optFolder($$);

my $GVAR = QtEmail::Shared::GET_GVAR;

my $usage = "
  Simple IMAP client. {--smtp command is a convenience wrapper around smtp-cli}
  Configuration is in ".getConfigFile()."
    Each config entry is one line of the format:
      ".getConfigPrefix().".GLOBAL_OPTION_KEY = <value>
      or
      ".getConfigPrefix().".ACCOUNT_NAME.ACCOUNT_CONFIG_KEY = <value>

    Account names can be any word characters (alphanumeric plus underscore)
    Lines that do not begin with \"".getConfigPrefix().".\" are ignored.

    ACCOUNT_NAME:    the word following \"".getConfigPrefix().".\" in ".getConfigFile()."\n
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

  $0 --delete [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    delete the indicated messages (from IMAP server AND local cache)

  $0 --delete-local [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    delete the indicated messages from the local cache ONLY
    (does not delete from IMAP server)

  $0 --move [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_FOLDER_NAME UID [UID UID ...]
    move the indicated messages on the IMAP server from FOLDER_NAME to DEST_FOLDER_NAME
    this deletes the indicated messages from the local cache.
    this does NOT, however, download the newly moved messages in DEST_FOLDER_NAME;
      you need to update DEST_FOLDER_NAME to fetch them from the IMAP server

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

  $0 --print-uid-headers [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ..]
    format and print message headers for the given UIDs

  $0 --print-uid-bodies [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ..]
    format and print message headers and bodies for the given UIDs

  $0 --print-uid-short [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ..]
    format and print one-line header summaries for the given UIDs

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

  $0 --get-config-val ACCOUNT_NAME KEY
    reads ".getConfigFile()."
    find a line of the form \"".getConfigPrefix().".ACCOUNT_NAME.KEY\\s*=\\s*VAL\"
      and print \"VAL\"

  $0 --read-config ACCOUNT_NAME
    reads ".getConfigFile()."
    for each line of the form \"".getConfigPrefix().".ACCOUNT_NAME.KEY\\s*=\\s*VAL\"
      print \"KEY=VAL\"

  $0 --write-config ACCOUNT_NAME KEY=VAL [KEY=VAL KEY=VAL]
    modifies ".getConfigFile()."
    for each KEY/VAL pair:
      removes any line that matches \"".getConfigPrefix().".ACCOUNT_NAME.KEY\\s*=\"
      adds a line at the end \"".getConfigPrefix().".ACCOUNT_NAME.KEY = VAL\"

  $0 --get-option-val KEY
    reads ".getConfigFile()."
    find a line of the form \"".getConfigPrefix().".KEY\\s*=\\s*VAL\"
      and print \"VAL\"

  $0 --read-options
    reads ".getConfigFile()."
    for each line of the form \"".getConfigPrefix().".KEY\\s*=\\s*VAL\"
      print \"KEY=VAL\"

  $0 --write-options KEY=VAL [KEY=VAL KEY=VAL]
    reads ".getConfigFile()."
    for each line of the form \"".getConfigPrefix().".KEY\\s*=\\s*VAL\"
      print KEY=VAL

  $0 --read-config-schema
    print the allowed keys and descriptions for account config entries
    formatted, one per line, like this:
    <KEY_NAME>=<DESC>
      KEY_NAME: one of:
        REQUIRED: " . join(" ", getAccReqConfigKeys()) . "
        OPTIONAL: " . join(" ", getAccOptConfigKeys()) . "
        MAPPED:   " . join(" ", map{"$_.NAME"} getAccMapConfigKeys()) . "
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
    require QtEmail::UpdatePrint;
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderNameFilter = optFolder \@_, undef;
    my @accNames = @_;
    my $success = QtEmail::UpdatePrint::cmdUpdate($folderNameFilter, @accNames);
    my $exitCode = $success ? 0 : 1;
    exit $exitCode;
  }elsif($cmd =~ /^(--smtp)$/ and @_ >= 4){
    require QtEmail::Smtp;
    my ($accName, $subject, $body, $to, @args) = @_;
    QtEmail::Smtp::cmdSmtp($accName, $subject, $body, $to, @args);
  }elsif($cmd =~ /^(--mark-read|--mark-unread)$/ and @_ >= 2){
    require QtEmail::Email;
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    my $readStatus = $cmd =~ /^(--mark-read)$/ ? 1 : 0;
    QtEmail::Email::cmdMarkReadUnread($readStatus, $accName, $folderName, @uids);
  }elsif($cmd =~ /^(--delete|--delete-local)$/ and @_ >= 2){
    require QtEmail::Email;
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    my $localOnly = ($cmd eq "--delete-local") ? 1 : 0;
    QtEmail::Email::cmdDelete($accName, $folderName, $localOnly, @uids);
  }elsif($cmd =~ /^(--move)$/ and @_ >= 3){
    require QtEmail::Email;
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 3;
    my ($accName, $destFolderName, @uids) = @_;
    QtEmail::Email::cmdMove($accName, $folderName, $destFolderName,  @uids);
  }elsif($cmd =~ /^(--accounts)$/ and @_ == 0){
    require QtEmail::Email;
    QtEmail::Email::cmdAccounts();
  }elsif($cmd =~ /^(--folders)$/ and @_ == 1){
    require QtEmail::Email;
    my $accName = shift;
    QtEmail::Email::cmdFolders($accName);
  }elsif($cmd =~ /^(--header)$/ and @_ >= 2){
    require QtEmail::Email;
    my $folderName = optFolder \@_, "inbox";
    die $usage if @_ < 2;
    my ($accName, @uids) = @_;
    QtEmail::Email::cmdHeader($accName, $folderName, @uids);
  }elsif($cmd =~ /^(--body|--body-plain|--body-html|--attachments)$/ and @_ >= 2){
    require QtEmail::Body;
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

    QtEmail::Body::cmdBodyAttachments($modeBodyAttachments, $wantPlain, $wantHtml,
      $noDownload, $nulSep,
      $accName, $folderName, $destDir, @uids);
  }elsif($cmd =~ /^(--cache-all-bodies)$/ and @_ == 2){
    require QtEmail::Body;
    QtEmail::Shared::MODIFY_GVAR('VERBOSE', 1);
    my ($accName, $folderName) = @_;
    QtEmail::Body::cmdCacheAllBodies($accName, $folderName);
  }elsif($cmd =~ /^(--print)$/ and @_ >= 0){
    require QtEmail::UpdatePrint;
    my $folderName = optFolder \@_, "inbox";
    my @accNames = @_;
    QtEmail::UpdatePrint::cmdPrint($folderName, @accNames);
  }elsif($cmd =~ /^--print-uid-(headers|bodies|short)$/ and @_ >= 0){
    my $formatType = $1;
    require QtEmail::UpdatePrint;
    my $folderName = optFolder \@_, "inbox";
    my ($accName, @uids) = @_;
    die "$usage\nmissing account name\n" if not defined $accName;
    die "$usage\nmust specify at least one UID\n" if @uids == 0;
    QtEmail::UpdatePrint::cmdPrintUids($accName, $folderName, $formatType, @uids);
  }elsif($cmd =~ /^(--summary)$/ and @_ >= 0){
    require QtEmail::Email;
    my $folderName = optFolder \@_, "inbox";
    my @accNames = @_;
    QtEmail::Email::cmdSummary($folderName, @accNames);
  }elsif($cmd =~ /^(--status-line|--status-short)$/ and @_ >= 0){
    require QtEmail::Email;
    my $modeLineStatus;
    if($cmd =~ /^(--status-line)$/){
      $modeLineStatus = "line";
    }elsif($cmd =~ /^(--status-short)$/){
      $modeLineStatus = "short";
    }else{
      die "failed to parsed cmd: $cmd\n";
    }
    my @accNames = @_;
    QtEmail::Email::cmdStatus($modeLineStatus, @accNames);
  }elsif($cmd =~ /^(--has-error)$/ and @_ >= 0){
    require QtEmail::Email;
    my @accNames = @_;
    if(QtEmail::Email::cmdHasError(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--has-new-unread)$/ and @_ >= 0){
    require QtEmail::Email;
    my @accNames = @_;
    if(QtEmail::Email::cmdHasNewUnread(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--has-unread)$/ and @_ >= 0){
    require QtEmail::Email;
    my @accNames = @_;
    if(QtEmail::Email::cmdHasUnread(@accNames)){
      print "yes\n";
      exit 0;
    }else{
      print "no\n";
      exit 1;
    }
  }elsif($cmd =~ /^(--get-config-val)$/ and @_ == 2){
    require QtEmail::Email;
    my ($account, $singleKey) = @_;
    QtEmail::Email::cmdReadConfigOptions("account", $account, $singleKey);
  }elsif($cmd =~ /^(--read-config)$/ and @_ == 1){
    require QtEmail::Email;
    my $account = shift;
    QtEmail::Email::cmdReadConfigOptions("account", $account);
  }elsif($cmd =~ /^(--write-config)$/ and @_ >= 2){
    require QtEmail::Email;
    my $accName = shift;
    QtEmail::Email::cmdWriteConfigOptions("account", $accName, @_);
  }elsif($cmd =~ /^(--get-option-val)$/ and @_ == 1){
    require QtEmail::Email;
    my ($singleKey) = @_;
    QtEmail::Email::cmdReadConfigOptions("options", undef, $singleKey);
  }elsif($cmd =~ /^(--read-options)$/ and @_ ==0){
    require QtEmail::Email;
    QtEmail::Email::cmdReadConfigOptions("options", undef);
  }elsif($cmd =~ /^(--write-options)$/ and @_ >= 1){
    require QtEmail::Email;
    QtEmail::Email::cmdWriteConfigOptions("options", undef, @_);
  }elsif($cmd =~ /^(--read-config-schema)$/ and @_ == 0){
    require QtEmail::Email;
    QtEmail::Email::cmdReadConfigOptionsSchema("account");
  }elsif($cmd =~ /^(--read-options-schema)$/ and @_ == 0){
    require QtEmail::Email;
    QtEmail::Email::cmdReadConfigOptionsSchema("options");
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

&main(@ARGV);
