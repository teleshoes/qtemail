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
sub mergeUnreadCounts($@);
sub readUnreadCounts();
sub writeUnreadCounts($@);
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
sub cacheBodies($$$@);
sub getBody($$$);
sub hasWords($);
sub parseBody($$);
sub writeAttachments($$);
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
sub readSecrets();
sub validateSecrets($);
sub modifySecrets($$);

my $secretsFile = "$ENV{HOME}/.secrets";
my $secretsPrefix = "email";
my @configKeys = qw(user password server port);
my @extraConfigKeys = qw(inbox sent folders ssl smtp_server smtp_port);

my @headerFields = qw(Date Subject From To);
my $unreadCountsFile = "$ENV{HOME}/.unread-counts";
my $emailDir = "$ENV{HOME}/.cache/email";

my $VERBOSE = 0;
my $DATE_FORMAT = "%Y-%m-%d %H:%M:%S";

my $settings = {
  Peek => 1,
  Uid => 1,
};

my $okCmds = join "|", qw(
  --update --header --body --body-html --attachments
  --smtp
  --mark-read --mark-unread
  --accounts --folders --print --summary --unread-line
  --has-error --has-new-unread --has-unread
  --read-config --write-config
);

my $usage = "
  Simple IMAP client. {--smtp command is a convenience wrapper around smtp-cli}
  Configuration is in $secretsFile
    Each line is one key of the format: $secretsPrefix.ACCOUNT_NAME.FIELD = value
    Account names can be any word characters (alphanumeric plus underscore)
    Other keys are ignored.
    required fields:
      user     {Required} IMAP username, usually the full email address
      password {Required} *password in plaintext*
      server   {Required} IMAP server
      port     {Required} IMAP server port
      ssl      {Optional} false to forcibly disable security
      inbox    {Optional} main IMAP folder name to use (default is \"INBOX\")
      sent     {Optional} IMAP folder name to use for sent mail
      folders  {Optional} colon-separated list of additional folders to fetch
        each folder has a FOLDER_NAME,
        which is the directory on the filesystem will be lowercase
        FOLDER_NAME is the folder, with all non-alphanumeric characters
          replaced with _s, and all leading and trailing _s removed
        e.g.:  junk:[GMail]/Drafts:_12_/ponies
               =>  [\"junk\", \"gmail_drafts\", \"12_ponies\"]

  ACCOUNT_NAME    the word following \"$secretsPrefix.\" in $secretsFile
  FOLDER_NAME     \"inbox\", \"sent\" or one of the names from \"folders\"
  UID             an IMAP UID {UIDVALIDITY is assumed to never change}

  $0 -h|--help
    show this message

  $0 [--update] [ACCOUNT_NAME ACCOUNT_NAME ...]
    -for each account specified, or all if none are specified:
      -login to IMAP server, or create file $emailDir/ACCOUNT_NAME/error
      -for each FOLDER_NAME:
        -fetch and write all message UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/all
        -fetch and cache all message headers in
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/headers/UID
        -fetch all unread messages and write their UIDs to
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/unread
        -write all message UIDs that are now in unread and were not before
          $emailDir/ACCOUNT_NAME/FOLDER_NAME/new-unread
    -update global unread counts file $unreadCountsFile
      ignored or missing accounts are preserved in $unreadCountsFile

      write the unread counts, one line per account, to $unreadCountsFile
      e.g.: 3:AOL
            6:GMAIL
            0:WORK_GMAIL

  $0 --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
    simple wrapper around smtp-cli. {you can add extra recipients with --to}
    calls:
      smtp-cli \\
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
    \"ACCOUNT_NAME:<timestamp>:<relative_time>:<unread_count>/<total_count>:<error>\"

  $0 --folders ACCOUNT_NAME
    format and print information about each folder for the given account
    \"FOLDER_NAME:<unread_count>/<total_count>\"

  $0 --header [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    format and print the header of the indicated message(s)
    prints each of [@headerFields]
      one per line, formatted \"UID.FIELD: VALUE\"

  $0 --body [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    download, format and print the body of the indicated message(s)
    if body is cached, skip download

  $0 --body-html [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
    same as --body, but prefer HTML instead of plaintext

  $0 --attachments [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_DIR UID [UID UID ...]
    download the body of the indicated message(s) and save any attachments to DEST_DIR
    if body is cached, skip download

  $0 --print [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers and bodies

  $0 --summary [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
    format and print cached unread message headers

  $0 --unread-line [ACCOUNT_NAME ACCOUNT_NAME ...]
    does not fetch anything, merely reads $unreadCountsFile
    format and print $unreadCountsFile
    the string is a space-separated list of the first character of
      each account name followed by the integer count
    no newline character is printed
    if the count is zero for a given account, it is omitted
    if accounts are specified, all but those are omitted
    e.g.: A3 G6

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
";

sub main(@){
  my $cmd = shift if @_ > 0 and $_[0] =~ /^($okCmds)$/;
  $cmd = "--update" if not defined $cmd;

  die $usage if @_ > 0 and $_[0] =~ /^(-h|--help)$/;

  if($cmd =~ /^(--read-config)$/){
    die $usage if @_ != 1;
    my $accName = shift;
    my $config = readSecrets;
    my $accounts = $$config{accounts};
    if(defined $$accounts{$accName}){
      my $acc = $$accounts{$accName};
      for my $key(keys %$acc){
        print "$key=$$acc{$key}\n";
      }
    }
    exit 0;
  }elsif($cmd =~ /^(--write-config)$/){
    my ($accName, @keyValPairs) = @_;
    die $usage if not defined $accName or @keyValPairs == 0;
    my $config = {};
    for my $keyValPair(@keyValPairs){
      if($keyValPair =~ /^(\w+)=(.*)$/){
        $$config{$1} = $2;
      }else{
        die "Malformed KEY=VAL pair: $keyValPair\n";
      }
    }
    modifySecrets $accName, $config;
    exit 0;
  }

  my $config = readSecrets();
  validateSecrets $config;
  my @accOrder = @{$$config{accOrder}};
  my $accounts = $$config{accounts};
  my %accFolders = map {$_ => parseFolders $$accounts{$_}} keys %$accounts;

  if($cmd =~ /^(--update)$/){
    $VERBOSE = 1;
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $counts = {};
    my $isError = 0;
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
        next;
      }

      my $folders = $accFolders{$accName};
      my $unreadCount = 0;
      for my $folderName(sort keys %$folders){
        my $imapFolder = $$folders{$folderName};
        my $f = openFolder($imapFolder, $c, 0);
        if(not defined $f){
          $isError = 1;
          my $msg = "ERROR: Could not open folder $folderName\n";
          warn $msg;
          writeError $accName, $msg;
          next;
        }

        cacheAllHeaders($accName, $folderName, $c);

        my @unread = $c->unseen;
        $unreadCount += @unread;

        cacheBodies($accName, $folderName, $c, @unread);

        $c->close();

        my %oldUnread = map {$_ => 1} readUidFile $accName, $folderName, "unread";
        writeUidFile $accName, $folderName, "unread", @unread;
        my @newUnread = grep {not defined $oldUnread{$_}} @unread;
        writeUidFile $accName, $folderName, "new-unread", @newUnread;

      }
      $c->logout();
      $$counts{$accName} = $unreadCount;
      writeLastUpdated $accName unless hasError $accName;
    }
    mergeUnreadCounts $counts, @accOrder;
    exit $isError ? 1 : 0;
  }elsif($cmd =~ /^(--smtp)$/){
    die $usage if @_ < 4;
    my ($accName, $subject, $body, $to, @args) = @_;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    exec "smtp-cli",
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
    my $count = @unread;
    mergeUnreadCounts {$accName => $count}, @accOrder;
    $c->close();
    $c->logout();
  }elsif($cmd =~ /^(--accounts)$/){
    die $usage if @_ != 0;
    for my $accName(@accOrder){
      my $folders = $accFolders{$accName};
      my $unreadCount = 0;
      my $totalCount = 0;
      my $lastUpdated = readLastUpdated $accName;
      my $lastUpdatedRel = relTime $lastUpdated;
      my $error = readError $accName;
      $error = "" if not defined $error;
      for my $folderName(sort keys %$folders){
        $unreadCount += readUidFileCounts $accName, $folderName, "unread";
        $totalCount += readUidFileCounts $accName, $folderName, "all";
      }
      $lastUpdated = 0 if not defined $lastUpdated;
      print "$accName:$lastUpdated:$lastUpdatedRel:$unreadCount/$totalCount:$error\n";
    }
  }elsif($cmd =~ /^(--folders)$/){
    die $usage if @_ != 1;
    my $accName = shift;
    my $folders = $accFolders{$accName};
    for my $folderName(sort keys %$folders){
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
  }elsif($cmd =~ /^(--body|--body-html|--attachments)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    die $usage if @_ < 2;
    my ($accName, $destDir, @uids);
    if($cmd =~ /^(--body|--body-html)/){
      ($accName, @uids) = @_;
      $destDir = "/tmp";
      die $usage if not defined $accName or @uids == 0;
    }elsif($cmd =~ /^(--attachments)$/){
      ($accName, $destDir, @uids) = @_;
      die $usage if not defined $accName or @uids == 0
        or not defined $destDir or not -d $destDir;
    }

    my $preferHtml = $cmd =~ /body-html/;
    my $acc = $$accounts{$accName};
    die "Unknown account $accName\n" if not defined $acc;
    my $imapFolder = $accFolders{$accName}{$folderName};
    die "Unknown folder $folderName\n" if not defined $imapFolder;
    my $c;
    my $f;
    my $mimeParser = MIME::Parser->new();
    $mimeParser->output_dir($destDir);
    for my $uid(@uids){
      my $body = readCachedBody($accName, $folderName, $uid);
      if(not defined $body){
        if(not defined $c){
          $c = getClient($acc);
          die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
        }
        if(not defined $f){
          my $f = openFolder($imapFolder, $c, 0);
          die "Error getting folder $folderName\n" if not defined $f;
        }
        cacheBodies($accName, $folderName, $c, $uid);
        $body = readCachedBody($accName, $folderName, $uid);
      }
      if(not defined $body){
        die "No body found for $accName=>$folderName=>$uid\n";
      }
      if($cmd =~ /^(--body|--body-html)/){
        my $fmt = getBody($mimeParser, $body, $preferHtml);
        chomp $fmt;
        print "$fmt\n";
      }elsif($cmd =~ /^(--attachments)$/){
        my @attachments = writeAttachments($mimeParser, $body);
        for my $attachment(@attachments){
          print " saved att: $attachment\n";
        }
      }
    }
    $c->close() if defined $c;
    $c->logout() if defined $c;
  }elsif($cmd =~ /^(--print)$/){
    my $folderName = "inbox";
    if(@_ > 0 and $_[0] =~ /^--folder=([a-z]+)$/){
      $folderName = $1;
      shift;
    }
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $mimeParser = MIME::Parser->new();
    binmode STDOUT, ':utf8';
    for my $accName(@accNames){
      my @unread = readUidFile $accName, $folderName, "unread";
      for my $uid(@unread){
        my $hdr = readCachedHeader($accName, $folderName, $uid);
        my $cachedBody = readCachedBody($accName, $folderName, $uid);
        my $body = getBody($mimeParser, $cachedBody, 0);
        $body = "" if not defined $body;
        $body = "[NO BODY]\n" if $body =~ /^\s*$/;
        $body =~ s/^/  /mg;
        print "\n"
          . "ACCOUNT: $accName\n"
          . "UID: $uid\n"
          . "DATE: $$hdr{Date}\n"
          . "FROM: $$hdr{From}\n"
          . "TO: $$hdr{To}\n"
          . "SUBJECT: $$hdr{Subject}\n"
          . "BODY:\n$body\n"
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
          . "\n"
          . "  $$hdr{Subject}"
          . "\n"
          ;
      }
    }
  }elsif($cmd =~ /^(--unread-line)$/){
    my @accNames = @_ == 0 ? @accOrder : @_;
    my $counts = readUnreadCounts();
    my @fmts;
    for my $accName(@accNames){
      die "Unknown account $accName\n" if not defined $$counts{$accName};
      my $count = $$counts{$accName};
      my $errorFile = "$emailDir/$accName/error";
      my $fmt = substr($accName, 0, 1) . $count;
      if(-f $errorFile){
        push @fmts, "$fmt!err";
      }else{
        push @fmts, $fmt if $count > 0;
      }
    }
    print "@fmts";
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
      for my $folderName(sort keys %$folders){
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
      for my $folderName(sort keys %$folders){
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

sub mergeUnreadCounts($@){
  my ($counts , @accOrder)= @_;
  $counts = {%{readUnreadCounts()}, %$counts};
  writeUnreadCounts($counts, @accOrder);
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
sub writeUnreadCounts($@){
  my ($counts , @accOrder)= @_;
  open FH, "> $unreadCountsFile" or die "Could not write $unreadCountsFile\n";
  for my $accName(@accOrder){
    print FH "$$counts{$accName}:$accName\n";
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

  for my $uid(keys %$headers){
    $count++;
    if($segment > 0 and $count % $segment == 0){
      my $pct = int(0.5 + 100*$count/$total);
      #print "\n" if $pct > 50 and $pct <= 55 and $VERBOSE;
      print "\n";
      print " $pct%" if $VERBOSE;
    }
    my $hdr = $$headers{$uid};
    my @fmtLines;
    my @rawLines;
    for my $field(sort @headerFields){
      my $vals = $$hdr{$field};
      my $val;
      if(not defined $vals or @$vals == 0){
        warn "\nWARNING: $uid has no field $field\n";
        $val = "";
      }else{
        $val = $$vals[0];
      }
      if($val =~ s/\n/\\n/){
        warn "\nWARNING: newlines in $uid $field {replaced with \\n}\n";
      }
      my $rawVal = $val;
      my $fmtVal = formatHeaderField($field, $val);
      push @fmtLines, "$field: $fmtVal\n";
      push @rawLines, "raw_$field: $rawVal\n";
    }
    open FH, "> $headersDir/$uid";
    binmode FH, ':utf8';
    print FH (@fmtLines, @rawLines);
    close FH;
  }
  print "\n" if $segment > 0 and $VERBOSE;
}

sub cacheBodies($$$@){
  my ($accName, $folderName, $c, @messages) = @_;
  my $bodiesDir = "$emailDir/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  my %toSkip = map {$_ => 1} getCachedBodyUids($accName, $folderName);
  @messages = grep {not defined $toSkip{$_}} @messages;
  print "caching bodies for " . @messages . " messages\n" if $VERBOSE;

  for my $uid(@messages){
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

sub getBody($$$){
  my ($mimeParser, $bodyString, $preferHtml) = @_;
  my $mimeBody = $mimeParser->parse_data($bodyString);

  for my $isHtml($preferHtml ? (1, 0) : (0, 1)){
    my $fmt = join "\n", parseBody($mimeBody, $isHtml);
    if(hasWords $fmt){
      $mimeParser->filer->purge;
      return $fmt;
    }
  }

  $mimeParser->filer->purge;
  return undef;
}

sub hasWords($){
  my $msg = shift;
  $msg =~ s/\W+//g;
  return length($msg) > 0;
}

sub parseBody($$){
  my ($entity, $html) = @_;
  my $count = $entity->parts;
  if($count > 0){
    my @parts;
    for(my $i=0; $i<$count; $i++){
      my @subParts = parseBody($entity->parts($i - 1), $html);
      @parts = (@parts, @subParts);
    }
    return @parts;
  }else{
    my $type = $entity->effective_type;
    if(not $html and $type eq "text/plain"){
      return ($entity->bodyhandle->as_string);
    }elsif($html and $type eq "text/html"){
      return ($entity->bodyhandle->as_string);
    }else{
      return ();
    }
  }
}

sub writeAttachments($$){
  my ($mimeParser, $bodyString) = @_;
  my $mimeBody = $mimeParser->parse_data($bodyString);
  my @attachments = parseAttachments($mimeBody);
  return @attachments;
}

sub parseAttachments($){
  my ($entity) = @_;
  my $count = $entity->parts;
  if($count > 0){
    my @parts;
    for(my $i=0; $i<$count; $i++){
      my @subParts = parseAttachments($entity->parts($i - 1));
      @parts = (@parts, @subParts);
    }
    return @parts;
  }else{
    my $path = $entity->bodyhandle ? $entity->bodyhandle->path : undef;
    my $disposition = $entity->head->mime_attr('content-disposition');
    if(defined $disposition and $disposition =~ /attachment/){
      return ($path);
    }else{
      unlink $path or warn "WARNING: could not remove file: $path\n";
      return ();
    }
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
  my @cachedBodies = `cd "$bodiesDir"; ls`;
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
  print "Opening folder $imapFolder\n" if $VERBOSE;

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
  print "$$acc{name}: logging in\n" if $VERBOSE;
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
  chomp $val;
  $val =~ s/\n/\\n/g;
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
  my $fs = {};

  my $f = defined $$acc{inbox} ? $$acc{inbox} : "INBOX";
  my $name = "inbox";
  die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
  $$fs{$name} = $f;

  if(defined $$acc{sent}){
    my $f = $$acc{sent};
    my $name = "sent";
    die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
    $$fs{$name} = $f;
  }
  if(defined $$acc{folders}){
    for my $f(split /:/, $$acc{folders}){
      $f =~ s/^\s*//;
      $f =~ s/\s*$//;
      my $name = getFolderName $f;
      die "DUPE FOLDER: $f and $$fs{$name}\n" if defined $$fs{$name};
      $$fs{$name} = $f;
    }
  }
  return $fs;
}

sub readSecrets(){
  my @lines = `cat $secretsFile 2>/dev/null`;
  my $accounts = {};
  my $accOrder = [];
  my $okConfigKeys = join "|", (@configKeys, @extraConfigKeys);
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.(\w+)\.($okConfigKeys)\s*=\s*(.+)$/){
      my ($accName, $key, $val)= ($1, $2, $3);
      if(not defined $$accounts{$accName}){
        $$accounts{$1} = {name => $accName};
        push @$accOrder, $accName;
      }
      $$accounts{$accName}{$key} = $val;
    }
  }
  return {accounts => $accounts, accOrder => $accOrder};
}

sub validateSecrets($){
  my $config = shift;
  my $accounts = $$config{accounts};
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    for my $key(sort @configKeys){
      die "Missing '$key' for '$accName' in $secretsFile\n" if not defined $$acc{$key};
    }
  }
}

sub modifySecrets($$){
  my ($accName, $config) = @_;
  die "invalid account name, must be a word i.e.: \\w+\n" if $accName !~ /^\w+$/;
  my @lines = `cat $secretsFile 2>/dev/null`;
  my @newLines;
  for my $line(@lines){
    my $skip = 0;
    for my $key(sort keys %$config){
      if($line =~ /^$secretsPrefix\.$accName\.$key\s*=/){
        $skip = 1;
        last;
      }
    }
    push @newLines, $line unless $skip;
  }

  my $okConfigKeys = join "|", (@configKeys, @extraConfigKeys);
  for my $key(sort keys %$config){
    die "Unknown config key: $key\n" if $key !~ /^($okConfigKeys)$/;
    push @newLines, "$secretsPrefix.$accName.$key = $$config{$key}\n";
  }

  open FH, "> $secretsFile" or die "Could not write $secretsFile\n";
  print FH @newLines;
  close FH;
}

&main(@ARGV);
