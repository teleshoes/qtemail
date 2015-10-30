package QtEmail::Smtp;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Config qw(getConfig);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  cmdSmtp
);

sub cmdSmtp($$$$@);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub cmdSmtp($$$$@){
  my ($accName, $subject, $body, $to, @args) = @_;
  my $config = getConfig();
  my $acc = $$config{accounts}{$accName};
  die "Unknown account $accName\n" if not defined $acc;
  exec $$GVAR{SMTP_CLI_EXEC},
    "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
    "--user=$$acc{user}", "--pass=$$acc{password}",
    "--from=$$acc{user}",
    "--subject=$subject", "--body-plain=$body", "--to=$to",
    @args;
}

1;
