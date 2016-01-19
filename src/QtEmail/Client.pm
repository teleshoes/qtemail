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

sub setFlagStatus($$$@);
sub openFolder($$$);
sub getClient($);
sub getSocket($);
sub isOldIMAPClientVersion();

my $IMAPCLIENT_OLD_MAJOR_VERSION = 3;
my $IMAPCLIENT_OLD_MINOR_VERSION = 31;

my $GVAR = QtEmail::Shared::GET_GVAR;

sub setFlagStatus($$$@){
  my ($c, $flag, $status, @uids) = @_;
  if($status){
    print "$flag => true [@uids]\n" if $$GVAR{VERBOSE};
    $c->set_flag($flag, @uids) or die "FAILED: set $flag on [@uids]\n";
  }else{
    print "$flag => false [@uids]\n" if $$GVAR{VERBOSE};
    $c->unset_flag($flag, @uids) or die "FAILED: unset $flag on [@uids]\n";
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

  my $user = $$acc{user};
  my $pass = $$acc{password};

  # quote password if Mail::IMAPClient version > 3.31
  if(not isOldIMAPClientVersion()){
    $pass = Mail::IMAPClient->Quote($pass);
  }

  my $c = Mail::IMAPClient->new(
    %$network,
    User     => $user,
    Password => $pass,
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

sub isOldIMAPClientVersion(){
  my $version = $Mail::IMAPClient::VERSION;
  my ($maj, $min) = split /\./, $version;

  my $oldMaj = $IMAPCLIENT_OLD_MAJOR_VERSION;
  my $oldMin = $IMAPCLIENT_OLD_MINOR_VERSION;

  if(not defined $maj or not defined $min or $maj !~ /^\d+$/ or $min !~ /^\d+$/){
    return 0;
  }elsif($maj < $oldMaj or ($maj == $oldMaj and $min <= $oldMin)){
    return 1;
  }else{
    return 0;
  }
}

1;
