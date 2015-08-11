#!/usr/bin/perl
use strict;
use warnings;

sub main(@){
  my $readme = `cat README`;
  $readme =~ s/\nUsage:\n.*//sg;
  my $emailUsage = `export HOME="~"; /opt/qtemail/bin/email.pl -h 2>&1`;
  $emailUsage =~ s/^(Usage:)?(\s*\n)*//;
  $emailUsage =~ s/\n*$/\n/;
  my $emailSearchUsage = `export HOME="~"; /opt/qtemail/bin/email-search.pl -h 2>&1`;
  $emailSearchUsage =~ s/^(Usage:)?(\s*\n)*//;
  $emailSearchUsage =~ s/\n*$/\n/;
  open FH, "> README";
  print FH "$readme\nUsage:\n";
  print FH "===== email.pl =====\n\n";
  print FH $emailUsage;
  print FH "\n";
  print FH "===== email-search.pl =====\n\n";
  print FH $emailSearchUsage;
  close FH;
}

&main(@ARGV);
