#!/usr/bin/perl
use strict;
use warnings;

sub run(@);

my $qmlDir = "/opt/email-gui/";

sub main(@){
  if(`whoami` ne "root\n"){
    print "rerunning as root\n";
    exec "sudo", $0, @ARGV;
  }
  my $prefix = shift;
  $prefix = "/usr/local" if not defined $prefix;
  my $binDir = "$prefix/bin";

  run "mkdir", "-p", $qmlDir;
  run "cp -ar qml/* $qmlDir";
  run "cp -ar src/* $binDir";
}

sub run(@){
  print "@_\n";
  system @_;
}

&main(@ARGV);
