#!/usr/bin/perl
use strict;
use warnings;

my $usage = "Usage:
";

sub main(@){
}

# -h|--help
# --update [--folder=FOLDER_NAME_FILTER] [ACCOUNT_NAME ACCOUNT_NAME ...]
# --smtp ACCOUNT_NAME SUBJECT BODY TO [ARG ARG ..]
# --mark-read [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
# --mark-unread [--folder=FOLDER_NAME] ACCOUNT_NAME UID [UID UID ...]
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
