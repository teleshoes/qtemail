#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use HTTP::Request;
use URI;
use JSON::XS;

my $SCOPE = "https://mail.google.com/";

#gmail-oauth-tokens.pl is Copyright 2021 by Elliot Wolk
#  it is largely based on https://metacpan.org/pod/Net::Google::OAuth
#  by Pavel Andryushin
#gmail-oauth-tokens.pl is free software; you can redistribute it and/or modify it
#  under the terms of either the GPLv2 (or, at your option, any later version)
#  or the "Artistic License"

sub main(@){
  die "Usage: $0 EMAIL_ADDRESS\n" if @_ != 1;
  my ($email) = @_;

  my ($clientID, $clientSecret);
  my $qtemailOpts = `email.pl --read-options`;
  if($qtemailOpts =~ /^client_id\s*=\s*(.+)$/m){
    $clientID = gpgSym($1);
  }
  if($qtemailOpts =~ /^client_secret\s*=\s*(.+)$/m){
    $clientSecret = gpgSym($1);
  }

  die "ERROR: could not obtain clientID\n" if not defined $clientID;
  die "ERROR: could not obtain clientSecret\n" if not defined $clientSecret;

  my $services = getOpenIdServices();
  my $authUrl = buildAuthUrl($$services{authorization_endpoint}, $clientID, $clientSecret, $SCOPE, $email);
  print "go to this URL in a browser, sign in and grant access:\n\n$authUrl\n\n";
  print "after you grant access, it will redirect you to a broken page\n";
  print "the broken page's URL has an auth code param embedded in it\n";
  print "  e.g.: http://localhost:8000/?state=uniq_state_3100&code=4/0AAAA-gggvblahblahblah&scope=https://mail.google.com/\n";
  print "\n";
  print "paste the actual URL of the broken page here: ";

  my $outputURL = <STDIN>;
  my $authCode = extractAuthCodeFromURL($outputURL);
  my $token = getTokenFromAuthCode($$services{token_endpoint}, $authCode, $clientID, $clientSecret);
  for my $key(sort keys %$token){
    print "$key - $$token{$key}\n";
  }

  my $refreshToken = $$token{refresh_token};
  die "ERROR: no refresh_token found\n" if not defined $refreshToken or $refreshToken =~ /^\s*$/;
  print "\n\ngpg refresh token:\n" . gpgSym($refreshToken) . "\n";
}

sub gpgSym($){
  my ($s) = @_;
  open CMD, "-|", "gpg-sym", $s;
  my $out = join '', <CMD>;
  close CMD;
  chomp $out;
  return $out;
}

sub buildAuthUrl($$$){
  my ($authEndpoint, $clientID, $clientSecret, $scope, $email) = @_;
  my $uri = URI->new($authEndpoint);
  $uri->query_form({
    'client_id'         => $clientID,
    'response_type'     => 'code',
    'scope'             => $scope,
    'redirect_uri'      => 'http://localhost:8000',
    'state'             => 'uniq_state_' . int(rand() * 100000),
    'login_hint'        => $email,
    'nonce'             => int(rand() * 1000000) . '-' . int(rand() * 1000000) . '-' . int(rand() * 1000000),
    'access_type'       => 'offline',
  });

  return $uri->as_string();
}

sub extractAuthCodeFromURL($){
  my ($redirectOutputURL) = @_;
  $redirectOutputURL =~ s/[\r\n]//g;
  $redirectOutputURL =~ s/^\s*//;
  $redirectOutputURL =~ s/\s*$//;

  my $uri = URI->new($redirectOutputURL) or die "Can't parse response: $redirectOutputURL";
  my %query_form = $uri->query_form();
  my $authCode = $query_form{code};
  if(not defined $authCode){
    die "Can't get 'code' from response url \"$redirectOutputURL\"";
  }
  return $authCode;
}

sub getTokenFromAuthCode($$$$){
  my ($tokenEndpoint, $authCode, $clientID, $clientSecret) = @_;
  return getToken($tokenEndpoint, $authCode, "authorization_code", $clientID, $clientSecret);
}
sub getTokenFromRefreshToken($$$$){
  my ($tokenEndpoint, $refreshToken, $clientID, $clientSecret) = @_;
  return getToken($tokenEndpoint, $refreshToken, "refresh_token", $clientID, $clientSecret);
}

sub getToken($$$$$){
  my ($tokenEndpoint, $authCodeOrRefreshToken, $grantType, $clientID, $clientSecret) = @_;

  my $params = {
    'client_id'     => $clientID,
    'client_secret' => $clientSecret,
    'redirect_uri'  => 'http://localhost:8000',
    'grant_type'    => $grantType,
    'access_type'   => 'offline',
  };
  if($grantType eq 'authorization_code'){
    $$params{code} = $authCodeOrRefreshToken;
  }elsif ($grantType eq 'refresh_token'){
    $$params{refresh_token} = $authCodeOrRefreshToken;
  }else{
    die "ERROR: unknown grant_type \"$grantType\"\n";
  }

  my $ua = LWP::UserAgent->new();
  my $response = $ua->post($tokenEndpoint, $params);
  my $response_code = $response->code;
  if($response_code != 200){
    die "Can't get token. Code: $response_code";
  }

  my $token = decode_json($response->content);

  return $token;
}

sub getOpenIdServices {
  my ($self) = @_;

  my $ua = LWP::UserAgent->new();
  my $request = $ua->get('https://accounts.google.com/.well-known/openid-configuration');
  my $response_code = $request->code;
  if ($response_code != 200) {
    die "Can't get list of OpenId services";
  }
  return decode_json($request->content);
}

&main(@ARGV);
