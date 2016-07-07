package QtEmail::Body;
use strict;
use warnings;
use lib "/opt/qtemail/lib";

use QtEmail::Shared qw(GET_GVAR);
use QtEmail::Config qw(getConfig);
use QtEmail::Folders qw(
  accImapFolder accFolderOrder accEnsureFoldersParsed
  getFolderName
  parseFolders parseCountIncludeFolderNames
);
use QtEmail::Client qw(
  openFolder
  getClient
);
use QtEmail::Cache qw(
  getCachedHeaderUids
  getCachedBodyUids

  readCachedBody
  readCachedHeader

  readCachedBodyPlain
  cacheBodyPlain
);
use QtEmail::Util qw(
  hasWords
);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  cmdBodyAttachments
  cmdCacheAllBodies

  cacheBodies
  getBody
  html2text
);

sub cmdBodyAttachments($$$$$$$$@);
sub cmdCacheAllBodies($$);

sub newMimeParser($);
sub cacheBodies($$$$@);
sub getHeaderFromBody($$);
sub getBody($$$);
sub writeAttachments($$);
sub parseMimeEntity($);
sub getHeaderFromBody($$);
sub html2text($);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub cmdBodyAttachments($$$$$$$$@){
  my ($modeBodyAttachments, $wantPlain, $wantHtml,
    $noDownload, $nulSep,
    $accName, $folderName, $destDir, @uids) = @_;
  my $config = getConfig();
  my $acc = $$config{accounts}{$accName};
  my $preferHtml = 0;
  $preferHtml = 1 if defined $$acc{prefer_html} and $$acc{prefer_html} =~ /true/i;
  $preferHtml = 0 if $wantPlain;
  $preferHtml = 1 if $wantHtml;
  die "Unknown account $accName\n" if not defined $acc;
  my $imapFolder = accImapFolder($acc, $folderName);
  die "Unknown folder $folderName\n" if not defined $imapFolder;

  my $c;
  my $f;
  my $mimeParser = undef;
  for my $uid(@uids){
    my $body = readCachedBody($accName, $folderName, $uid);
    if(not defined $body and $noDownload){
      print $nulSep ? "\0" : "\n";
      next;
    }
    if(not defined $body){
      if(not defined $c){
        $c = getClient($acc);
        die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;
      }
      if(not defined $f){
        my $f = openFolder($imapFolder, $c, 0);
        die "Error getting folder $folderName\n" if not defined $f;
      }
      cacheBodies($accName, $folderName, $c, undef, $uid);
      $body = readCachedBody($accName, $folderName, $uid);
    }
    if(not defined $body){
      die "No body found for $accName=>$folderName=>$uid\n";
    }
    if($modeBodyAttachments eq "body"){
      my $bodyFmt;
      if($wantPlain){
        my $cachedBodyPlain = readCachedBodyPlain($accName, $folderName, $uid);
        if(not defined $cachedBodyPlain){
          $mimeParser = newMimeParser($destDir) if not defined $mimeParser;
          my $bodyPlain = getBody($mimeParser, $body, $preferHtml);
          $bodyPlain = html2text $bodyPlain;
          cacheBodyPlain($accName, $folderName, $uid, $bodyPlain);
          $cachedBodyPlain = readCachedBodyPlain($accName, $folderName, $uid);
        }
        $bodyFmt = $cachedBodyPlain;
      }else{
        $mimeParser = newMimeParser($destDir) if not defined $mimeParser;
        $bodyFmt = getBody($mimeParser, $body, $preferHtml);
      }
      chomp $bodyFmt;
      print $bodyFmt;
      print $nulSep ? "\0" : "\n";
    }elsif($modeBodyAttachments eq "attachments"){
      $mimeParser = newMimeParser($destDir) if not defined $mimeParser;
      my @attachments = writeAttachments($mimeParser, $body);
      for my $attachment(@attachments){
        print " saved att: $attachment\n";
      }
    }
  }
  $c->close() if defined $c;
  $c->logout() if defined $c;
}

sub cmdCacheAllBodies($$){
  my ($accName, $folderName) = @_;
  my $config = getConfig();

  my $acc = $$config{accounts}{$accName};
  die "Unknown account $accName\n" if not defined $acc;
  my $c = getClient($acc);
  die "Could not authenticate $accName ($$acc{user})\n" if not defined $c;

  my $imapFolder = accImapFolder($acc, $folderName);
  die "Unknown folder $folderName\n" if not defined $imapFolder;
  my $f = openFolder($imapFolder, $c, 0);
  die "Error getting folder $folderName\n" if not defined $f;

  my @messages = $c->messages;
  cacheBodies($accName, $folderName, $c, undef, @messages);
}



sub newMimeParser($){
  my ($destDir) = @_;
  require MIME::Parser;
  my $mimeParser = MIME::Parser->new();
  $mimeParser->output_dir($destDir);
  return $mimeParser;
}

sub cacheBodies($$$$@){
  my ($accName, $folderName, $c, $maxCap, @messages) = @_;
  my $bodiesDir = "$$GVAR{EMAIL_DIR}/$accName/$folderName/bodies";
  system "mkdir", "-p", $bodiesDir;

  local $| = 1;

  my %toSkip = map {$_ => 1} getCachedBodyUids($accName, $folderName);
  @messages = grep {not defined $toSkip{$_}} @messages;
  if(defined $maxCap and $maxCap > 0 and @messages > $maxCap){
    my $count = @messages;
    print "only caching $maxCap out of $count\n" if $$GVAR{VERBOSE};
    @messages = reverse @messages;
    @messages = splice @messages, 0, $maxCap;
    @messages = reverse @messages;
  }
  print "caching bodies for " . @messages . " messages\n" if $$GVAR{VERBOSE};
  my $total = @messages;
  my $count = 0;
  my $segment = int($total/20);
  $segment = 100 if $segment > 100;

  my $mimeParser = undef;
  my $mimeDestDir = $$GVAR{TMP_DIR};
  for my $uid(@messages){
    $count++;
    if($segment > 0 and $count % $segment == 0){
      my $pct = int(0.5 + 100*$count/$total);
      my $date = `date`;
      chomp $date;
      print "  {cached $count/$total bodies} $pct%  $date\n" if $$GVAR{VERBOSE};
    }
    my $body = $c->message_string($uid);
    $body = "" if not defined $body;
    if($body =~ /^\s*$/){
      if($body =~ /^\s*$/){
        warn "WARNING: no body found for $accName $folderName $uid\n";
      }
    }else{
      open FH, "> $bodiesDir/$uid" or die "Could not write $bodiesDir/$uid\n";
      print FH $body;
      close FH;

      $mimeParser = newMimeParser($mimeDestDir) if not defined $mimeParser;
      my $bodyPlain = getBody($mimeParser, $body, 0);
      $bodyPlain = html2text $bodyPlain;
      cacheBodyPlain($accName, $folderName, $uid, $bodyPlain);
    }
  }
}

sub getBody($$$){
  my ($mimeParser, $bodyString, $preferHtml) = @_;
  my $entity = $mimeParser->parse_data($bodyString);

  my @parts = parseMimeEntity($entity);
  my @text = map {$_->{handle}} grep {$_->{partType} eq "text"} @parts;
  my @html = map {$_->{handle}} grep {$_->{partType} eq "html"} @parts;
  my @atts = map {$_->{handle}} grep {$_->{partType} eq "attachment"} @parts;

  my $body = "";
  for my $isHtml($preferHtml ? (1, 0) : (0, 1)){
    my @strings = map {$_->as_string} ($isHtml ? @html : @text);
    my $fmt = join "\n", @strings;
    if(hasWords $fmt){
      $body .= $fmt;
      last;
    }
  }
  $body =~ s/\r\n/\n/g;
  chomp $body;
  $body .= "\n" if length($body) > 0;

  my $attachments = "";
  my $first = 1;
  for my $att(@atts){
    my $path = $att->path;
    my $attName = $path;
    $attName =~ s/.*\///;
    if($preferHtml){
      $attachments .= "<br/>" if $first;
      $attachments .= "<i>attachment: $attName</i><br/>";
    }else{
      $attachments .= "\n" if $first;
      $attachments .= "attachment: $attName\n";
    }
    $first = 0;
  }

  $mimeParser->filer->purge;
  return $attachments . $body;
}

sub writeAttachments($$){
  my ($mimeParser, $bodyString) = @_;
  my $entity = $mimeParser->parse_data($bodyString);
  my @parts = parseMimeEntity($entity);
  my @attachments;
  for my $part(@parts){
    my $partType = $$part{partType};
    my $path = $$part{handle}->path;
    if($partType eq "attachment"){
      push @attachments, $path;
    }else{
      unlink $path or warn "WARNING: could not remove file: $path\n";
    }
  }
  return @attachments;
}

sub parseMimeEntity($){
  my ($entity) = @_;
  my $count = $entity->parts;
  if($count > 0){
    my @parts;
    for(my $i=0; $i<$count; $i++){
      my @subParts = parseMimeEntity($entity->parts($i));
      @parts = (@parts, @subParts);
    }
    return @parts;
  }else{
    my $type = $entity->effective_type;
    my $handle = $entity->bodyhandle;
    my $disposition = $entity->head->mime_attr('content-disposition');
    my $partType;
    if($type eq "text/plain"){
      $partType = "text";
    }elsif($type eq "text/html"){
      $partType = "html";
    }elsif(defined $disposition and $disposition =~ /attachment/){
      $partType = "attachment";
    }else{
      $partType = "unknown";
    }
    return ({partType=>$partType, handle=>$handle});
  }
}

sub getHeaderFromBody($$){
  my ($mimeParser, $bodyString) = @_;
  my $entity = $mimeParser->parse_data($bodyString);

  my $head = $entity->head();

  #simulate Mail::IMAPClient::parse_headers using MIME::Parser
  #like:
  # my $c = Mail::IMAPClient->new();
  # my $headers = $c->parse_headers($uid, @{$$GVAR{HEADER_FIELDS}})
  # my $hdr = $$headers{$uid};
  # return $hdr;
  my $hdr = {};
  for my $field(@{$$GVAR{HEADER_FIELDS}}){
    my $rawVal = $head->get($field);
    if(defined $rawVal){
      chomp $rawVal;
      $$hdr{$field} = [$rawVal];
    }
  }

  $mimeParser->filer->purge;
  return $hdr;
}

sub html2text($){
  my ($html) = @_;
  if($html !~ /<(html|body|head|table)(\s+[^>]*)?>/){
    return $html;
  }
  if(-x $$GVAR{HTML2TEXT_EXEC}){
    my $tmpFile = "/tmp/email_tmp_" . int(time*1000) . ".html";
    open FH, "> $tmpFile" or die "Could not write to $tmpFile\n";
    print FH $html;
    close FH;
    my $text = `$$GVAR{HTML2TEXT_EXEC} $tmpFile`;
    system "rm", $tmpFile;
    return $text;
  }else{
    $html =~ s/<[^>]*>//g;
    $html =~ s/\n(\s*\n)+/\n/g;
    $html =~ s/^\s+//mg;
    return $html;
  }
}

1;
