#!/usr/bin/perl
use strict;
use warnings;

sub email(@);
sub getAccounts(@);

my $usage = "Usage:
  $0 --email COMP_LINE COMP_POINT
     print a list of words for bash completion for email.pl, one per line

  COMP_LINE  - the full cmdline as a string
  COMP_POINT - the cursor position in the cmdline
";

my $EMAIL_EXEC = "/opt/qtemail/bin/email.pl";

sub main(@){
  my $script = shift;
  die $usage if not defined $script or @_ != 2;

  my @words;
  if($script =~ /^(--email)$/){
    @words = email $_[0], $_[1];
  }else{
    die $usage;
  }
  print map {"$_\n"} @words;
}

sub email(@){
  my ($cmdLine, $pos) = @_;
  my $cmd = substr $cmdLine, 0, $pos;
  my $isNewWord = $cmd =~ /\s$/;
  $cmd =~ s/^\s+//;
  $cmd =~ s/\s+$//;

  my @words = split /\s+/, $cmd;
  shift @words;
  my $cur = pop @words if not $isNewWord;

  my $cmdArg = shift @words;
  $cmdArg = "" if not defined $cmdArg;
  my @opts;
  push @opts, shift @words while @words > 0 and $words[0] =~ /^-/;
  my @args = @words;

  my @complete;

  my @cmdArgs = qw(
    -h --help
    --update --header --body --body-plain --body-html --attachments
    --cache-all-bodies
    --smtp
    --mark-read --mark-unread --delete --move
    --accounts --folders --print --summary --status-line --status-short
    --has-error --has-new-unread --has-unread
    --read-config --write-config --read-options --write-options
    --read-config-schema --read-options-schema
  );
  my @configOpts = map {"$_="} qw(
    user password server sent port ssl smtp_server smtp_port
    new_unread_cmd updateInterval refreshInterval
    preferHtml bodyCacheMode
    filters skip
  );
  my @optionOpts = map {"$_="} qw(
    update_cmd encrypt_cmd decrypt_cmd
  );

  my @folderOptExamples = qw(--folder=inbox --folder=sent);
  my @folderArgExamples = qw(inbox sent);
  my @accountExamples = qw(GMAIL YAHOO);
  my @uidExamples = qw(10000 20000 30000 40000 50000);
  my @subjectExamples = ("1subject", "2subject");
  my @bodyExamples = ("1body", "2body");
  my @toExamples = ("1email-to", "2email-to");
  my @smtpArgExamples = ("--to=", "--cc=", "--bcc=");

  if($cmdArg eq "" and @opts == 0 and @args == 0){
    @complete = (@complete, @cmdArgs);
  }

  my $okFolderCmdArgs = join "|", qw(
    --update --mark-read --mark-unread --delete --move --header --attachments --print --summary
  );
  if(@opts == 0 and @args == 0 and $cmdArg =~ /^($okFolderCmdArgs)$/){
    @complete = (@complete, @folderOptExamples);
  }

  if($cmdArg =~ /^(--body|--body-plain|body-html)$/ and @args == 0){
    if(@opts == 0){
      @complete = (@complete, "--no-download", "-0", @folderOptExamples);
    }elsif(@opts == 1 and $opts[0] =~ /^(--no-download)$/){
      @complete = (@complete, "-0", @folderOptExamples);
    }elsif(@opts == 1 and $opts[0] =~ /^(-0)$/){
      @complete = (@complete, @folderOptExamples);
    }elsif(@opts == 2 and $opts[0] =~ /^(--no-download)$/ and $opts[1] =~ /^(-0)$/){
      @complete = (@complete, @folderOptExamples);
    }
  }

  my $okAccList = join "|", qw(
    --update --print --summary --status-line --status-short
    --has-error --has-new-unread --has-unread
  );
  if($cmdArg =~ /^($okAccList)$/){
    @complete = (@complete, getAccounts(@accountExamples));
  }

  if($cmdArg =~ /^(--move)$/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }elsif(@args == 1){
      @complete = (@complete, @folderArgExamples);
    }else{
      @complete = (@complete, @uidExamples);
    }
  }

  my $okAccUidList = join "|", qw(
    --mark-read --mark-unread --delete --header --body --body-plain --body-html --attachments
  );
  if($cmdArg =~ /^($okAccUidList)/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }else{
      @complete = (@complete, @uidExamples);
    }
  }

  if($cmdArg =~ /^(--smtp)$/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }elsif(@args == 1){
      @complete = (@complete, @subjectExamples);
    }elsif(@args == 2){
      @complete = (@complete, @bodyExamples);
    }elsif(@args == 3){
      @complete = (@complete, @toExamples);
    }elsif(@args == 4){
      @complete = (@complete, @smtpArgExamples);
    }
  }

  if($cmdArg =~ /^(--cache-all-bodies)$/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }elsif(@args == 1){
      @complete = (@complete, @folderArgExamples);
    }
  }

  if($cmdArg =~ /^(--folders|--read-config)$/ and @args == 0){
    @complete = (@complete, getAccounts(@accountExamples));
  }

  if($cmdArg =~ /^(--write-config)$/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }else{
      @complete = (@complete, @configOpts);
    }
  }

  if($cmdArg =~ /^(--write-options)$/){
    if(@args == 0){
      @complete = (@complete, getAccounts(@accountExamples));
    }else{
      @complete = (@complete, @optionOpts);
    }
  }

  return @complete;
}

sub getAccounts(@){
  my @accountExamples = @_;
  my @lines = `$EMAIL_EXEC --accounts 2>/dev/null | sed s/:.*//`;
  chomp foreach @lines;
  if(@lines == 0){
    return @accountExamples;
  }else{
    return @lines;
  }
}

# -h|--help
# --update [--folder=FOLDER_NAME_FILTER] [ACCOUNT_NAME ACCOUNT_NAME ...]
# --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
# --mark-read [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --mark-unread [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --delete [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --move [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_FOLDER_NAME UID [UID UID ...]
# --accounts
# --folders ACCOUNT_NAME
# --header [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --body [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --body-plain [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --body-html [--no-download] [-0] [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --attachments [--folder=FOLDER_NAME] ACCOUNT_NAME DEST_DIR UID [UID UID ...]
# --cache-all-bodies ACCOUNT_NAME FOLDER_NAME
# --print [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
# --summary [--folder=FOLDER_NAME] [ACCOUNT_NAME ACCOUNT_NAME ...]
# --status-line [ACCOUNT_NAME ACCOUNT_NAME ...]
# --status-short [ACCOUNT_NAME ACCOUNT_NAME ...]
# --has-error [ACCOUNT_NAME ACCOUNT_NAME ...]
# --has-new-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
# --has-unread [ACCOUNT_NAME ACCOUNT_NAME ...]
# --read-config ACCOUNT_NAME
# --write-config ACCOUNT_NAME KEY=VAL [KEY=VAL KEY=VAL]
# --read-options
# --write-options KEY=VAL [KEY=VAL KEY=VAL]

&main(@ARGV);
