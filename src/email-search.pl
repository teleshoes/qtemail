#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(time);

sub updateDb($$$);
sub createDb($$);
sub runSql($$$);

my $emailDir = "$ENV{HOME}/.cache/email";

my $emailTable = "email";
my @headerFields = qw(
  date
  from
  subject
  to
  raw_date
  raw_from
  raw_subject
  raw_to
);
my @cols = ("uid", map {"header_$_"} @headerFields);
my @colTypes = ("uid number", map {"header_$_ varchar"} @headerFields);

my $usage = "Usage:
  $0 --updatedb ACCOUNT_NAME FOLDER_NAME LIMIT
    create sqlite database if it doesnt exist
    updates database incrementally

    LIMIT
      maximum number of headers to update at once
      can be 'all' or a positive integer
";

sub main(@){
  my $cmd = shift;
  die $usage if not defined $cmd;
  if($cmd =~ /^(--updatedb)$/ and @_ == 3){
    my ($accName, $folderName, $limit) = @_;
    die $usage if $limit !~ /^(all|[1-9]\d+)$/;
    updateDb($accName, $folderName, $limit);
  }else{
    die $usage;
  }
}

sub updateDb($$$){
  my ($accName, $folderName, $limit) = @_;
  my $db = "$emailDir/$accName/$folderName/db";
  if(not -f $db){
    createDb $accName, $folderName;
  }
  die "missing database $db\n" if not -f $db;
}

sub createDb($$){
  my ($accName, $folderName) = @_;
  my $db = "$emailDir/$accName/$folderName/db";
  die "database already exists $db\n" if -e $db;
  runSql $accName, $folderName,
    "create table $emailTable (" . join(", ", @colTypes) . ")";
}

sub runSql($$$){
  my ($accName, $folderName, $sql) = @_;
  my $db = "$emailDir/$accName/$folderName/db";

  $sql =~ s/\s*;\s*\n*$//;
  $sql = "$sql;\n";

  my $nowMillis = int(time*1000);
  my $tmpSqlFile = "/tmp/email-$accName-$folderName-$nowMillis.sql";
  open TMPFH, "> $tmpSqlFile";
  print TMPFH $sql;
  close TMPFH;

  my @cmd = ("sqlite3", $db, ".read $tmpSqlFile");
  open SQLITECMD, "-|", @cmd;
  my @lines = <SQLITECMD>;
  close SQLITECMD;
  die "error running @cmd\n" if $? != 0;

  system "rm", $tmpSqlFile;

  return join '', @lines;
}

&main(@ARGV);
