package QtEmail::Client;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use MIME::Base64;

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Config qw(
  getAccPassword
  getAccRefreshOauthToken
  getClientID
  getClientSecret
);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  openFolder
  getClient
  setFlagStatus
  deleteMessages
  moveMessages
);

sub setFlagStatus($$$@);
sub deleteMessages($@);
sub moveMessages($$@);
sub openFolder($$$);
sub getClient($$);
sub getSocket($);
sub isOldIMAPClientVersion();
sub fetchOauthToken($$$);

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

sub deleteMessages($@){
  my ($c, @uids) = @_;
  my $success = $c->delete_message(\@uids);
  die "Error deleting messages: @uids\n" if not defined $success;
}

sub moveMessages($$@){
  my ($c, $destImapFolder, @uids) = @_;
  my $success = $c->move($destImapFolder, \@uids);
  die "Error moving messages to $destImapFolder: @uids\n" if not defined $success;
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

sub getClient($$){
  my ($acc, $options) = @_;
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
  my $pass = getAccPassword($acc, $options);

  my $refreshOauthToken = getAccRefreshOauthToken($acc, $options);
  my $clientID = getClientID($options);
  my $clientSecret = getClientSecret($options);
  my $oauthToken;
  if(defined $refreshOauthToken and defined $clientID and defined $clientSecret){
    $oauthToken = fetchOauthToken($refreshOauthToken, $clientID, $clientSecret);
  }

  # quote password if Mail::IMAPClient version > 3.31
  if(not isOldIMAPClientVersion()){
    $pass = Mail::IMAPClient->Quote($pass);
  }

  my $c = Mail::IMAPClient->new(
    %$network,
    %{$$GVAR{IMAP_CLIENT_SETTINGS}},
  );

  if(defined $oauthToken){
    my $oauthSign = encode_base64("user=$user\x01auth=Bearer $oauthToken\x01\x01", '');
    my $authSub = sub { return $oauthSign; };
    $c->User($user);
    $c->Authmechanism("XOAUTH2");
    $c->Authcallback($authSub);
    if(not $c->login()){
      print STDERR "WARNING: could not authenticate with XOAUTH2 - " . $c->LastError . "\n";
      $c->User(undef);
      $c->Authmechanism(undef);
      $c->Authcallback(undef);
    }
  }

  if(not $c->IsAuthenticated()){
    $c->User($user);
    $c->Password($pass);
    if(not $c->login()){
      print STDERR "ERROR: could not authenticate with password - " . $c->LastError . "\n";
    }
  }

  if(not $c->IsAuthenticated){
    $c = undef;
  }

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

sub fetchOauthToken($$$){
  my ($refreshOauthToken, $clientID, $clientSecret) = @_;
  my $tokenEndpoint = "https://oauth2.googleapis.com/token";

  my $params = {
    client_id     => $clientID,
    client_secret => $clientSecret,
    grant_type    => "refresh_token",
    refresh_token => $refreshOauthToken,
  };

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new();
  my $response = $ua->post($tokenEndpoint, $params);

  if($response->content =~ /"access_token"\s*:\s*"([^"]+)"/){
    return $1;
  }else{
    print STDERR "WARNING: could not obtain OAUTH token\n"
      . $response->code . "\n" . $response->content . "\n";
    return undef;
  }
}

1;
