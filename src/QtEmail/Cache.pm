package QtEmail::Cache;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  getCachedHeaderUids
  getCachedBodyUids

  readCachedBody
  readCachedHeader
);

sub getCachedHeaderUids($$);
sub getCachedBodyUids($$);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub getCachedHeaderUids($$){
  my ($accName, $folderName) = @_;
  my $headersDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/headers";
  my @cachedHeaders = `cd "$headersDir"; ls`;
  chomp foreach @cachedHeaders;
  return @cachedHeaders;
}
sub getCachedBodyUids($$){
  my ($accName, $folderName) = @_;
  my $bodiesDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  opendir DIR, $bodiesDir or die "Could not list $bodiesDir\n";
  my @cachedBodies;
  while (my $file = readdir(DIR)) {
    next if $file eq "." or $file eq "..";
    die "malformed file: $bodiesDir/$file\n" if $file !~ /^\d+$/;
    push @cachedBodies, $file;
  }
  closedir DIR;
  chomp foreach @cachedBodies;
  return @cachedBodies;
}

sub readCachedBody($$$){
  my ($accName, $folderName, $uid) = @_;
  my $bodyFile = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies/$uid";
  if(not -f $bodyFile){
    return undef;
  }
  return `cat "$bodyFile"`;
}

sub readCachedHeader($$$){
  my ($accName, $folderName, $uid) = @_;
  my $hdrFile = "$$GVAR{EMAIL_DIR}/$accName/$folderName/headers/$uid";
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

1;
