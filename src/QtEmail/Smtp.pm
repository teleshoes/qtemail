package QtEmail::Smtp;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Client qw(fetchAccOauthToken);
use QtEmail::Config qw(getConfig getAccPassword);

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
  my $options = $$config{options};
  die "Unknown account $accName\n" if not defined $acc;

  my $token = fetchAccOauthToken($acc, $options);

  if(defined $token){
    exec $$GVAR{SMTP_OAUTH_EXEC},
      "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
      "--user=$$acc{user}", "--auth-token=$token",
      "--subject=$subject", "--body=$body", "--plain",
      "--to=$to",
      @args;
  }else{
    my $pass = getAccPassword($acc, $options);
    exec $$GVAR{SMTP_CLI_EXEC},
      "--server=$$acc{smtp_server}", "--port=$$acc{smtp_port}",
      "--user=$$acc{user}", "--pass=$pass",
      "--from=$$acc{user}",
      "--subject=$subject", "--body-plain=$body", "--to=$to",
      @args;
  }
}

1;
