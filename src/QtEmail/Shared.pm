package QtEmail::Shared;
use strict;
use warnings;
use Exporter;
our @EXPORT_OK = qw(INIT_GVAR GET_GVAR MODIFY_GVAR);

my $GVAR = {};

sub INIT_GVAR($){
  my $initGvar = shift;
  for my $key(keys %$initGvar){
    my $val = $$initGvar{$key};
    $$GVAR{$key} = $val;
  }
}

sub GET_GVAR(){
  return $GVAR;
}

sub MODIFY_GVAR($$){
  my ($key, $val) = @_;
  $$GVAR{$key} = $val;
}

1;
