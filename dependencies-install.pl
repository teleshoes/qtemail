#!/usr/bin/perl
use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename 'dirname';

my $QTEMAIL_DIR = dirname(abs_path $0);

sub main(@){
  my $control = "$QTEMAIL_DIR/debian/control";
  open FH, "< $control" or die "could not read $control\n$!\n";
  my $contents = join '', <FH>;
  close FH;

  my $depsCsv;
  if($contents =~ /^Depends: (.+)$/m){
    $depsCsv = $1;
  }
  my @deps = split /\s*,\s*/, $depsCsv;

  system "sudo", "apt-get", "install", @deps;
}

&main(@ARGV);
