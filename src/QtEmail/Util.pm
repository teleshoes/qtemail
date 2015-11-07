package QtEmail::Util;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  hasWords
);

sub hasWords($);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub hasWords($){
  my $msg = shift;
  $msg =~ s/\W+//g;
  return length($msg) > 0;
}

1;
