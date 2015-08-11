#!/usr/bin/perl
use strict;
use warnings;

sub main(@){
  my $readme = `cat README`;
  $readme =~ s/\nUsage:\n.*//sg;
  my $emailUsage = `export HOME="~"; /opt/qtemail/bin/email.pl -h 2>&1`;
  $emailUsage =~ s/^Usage:\s*\n//;
  open FH, "> README";
  print FH "$readme\nUsage:\n$emailUsage";
  close FH;
}

&main(@ARGV);
