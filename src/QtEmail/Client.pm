package QtEmail::Client;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  openFolder
  getClient
  setFlagStatus
);

sub setFlagStatus($$$$);
sub openFolder($$$);
sub getClient($);
sub getSocket($);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub setFlagStatus($$$$){
  my ($c, $uid, $flag, $status) = @_;
  if($status){
    print "$uid $flag => true\n" if $$GVAR{VERBOSE};
    $c->set_flag($flag, $uid) or die "FAILED: set $flag on $uid\n";
  }else{
    print "$uid $flag => false\n" if $$GVAR{VERBOSE};
    $c->unset_flag($flag, $uid) or die "FAILED: unset flag on $uid\n";
  }
}

sub openFolder($$$){
  my ($imapFolder, $c, $allowEditing) = @_;
  print "Opening folder: $imapFolder\n" if $$GVAR{VERBOSE};

  my @folders = $c->folders($imapFolder);
  if(@folders != 1){
    return undef;
  }

  my $f = $folders[0];
  if($allowEditing){
    $c->select($f) or $f = undef;
  }else{
    $c->examine($f) or $f = undef;
  }
  return $f;
}

sub getClient($){
  my ($acc) = @_;
  my $network;
  if(defined $$acc{ssl} and $$acc{ssl} =~ /^false$/){
    $network = {
      Server => $$acc{server},
      Port => $$acc{port},
    };
  }else{
    my $socket = getSocket($acc);
    return undef if not defined $socket;

    $network = {
      Socket => $socket,
    };
  }
  my $sep = "="x50;
  print "$sep\n$$acc{name}: logging in\n$sep\n" if $$GVAR{VERBOSE};
  require Mail::IMAPClient;
  my $c = Mail::IMAPClient->new(
    %$network,
    User     => $$acc{user},
    Password => Mail::IMAPClient->Quote($$acc{password}),
    %{$$GVAR{IMAP_CLIENT_SETTINGS}},
  );
  return undef if not defined $c or not $c->IsAuthenticated();
  return $c;
}

sub getSocket($){
  my $acc = shift;
  require IO::Socket::SSL;
  return IO::Socket::SSL->new(
    PeerAddr => $$acc{server},
    PeerPort => $$acc{port},
  );
}

1;
