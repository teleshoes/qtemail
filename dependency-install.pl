#!/usr/bin/perl
use strict;
use warnings;

sub run(@);

my @deps = qw(
  python-pyside
  libmail-imapclient-perl
  libmime-tools-perl
  libio-socket-ssl-perl
);

sub main(@){
  run "sudo", "apt-get", "install", @deps;
}

sub run(@){
  print "@_\n";
  system @_;
}

&main(@ARGV);
