package QtEmail::Folders;
use strict;
use warnings;
use lib "/opt/qtemail/lib";
use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  accImapFolder accFolderOrder accEnsureFoldersParsed
  getFolderName
  parseFolders parseCountIncludeFolderNames
);

sub accImapFolder($$);
sub accFolderOrder($);
sub accEnsureFoldersParsed($);
sub getFolderName($);
sub parseFolders($);
sub parseCountIncludeFolderNames($);

my $GVAR = QtEmail::Shared::GET_GVAR;

sub accImapFolder($$){
  my ($acc, $folderName) = @_;
  accEnsureFoldersParsed $acc;
  return $$acc{parsedFolders}{$folderName};
}
sub accFolderOrder($){
  my ($acc) = @_;
  accEnsureFoldersParsed $acc;
  return @{$$acc{parsedFolderOrder}};
}
sub accEnsureFoldersParsed($){
  my $acc = shift;
  return if defined $$acc{parsedFolders};

  my @nameFolderPairs = @{parseFolders $acc};
  $$acc{parsedFolders} = {};
  $$acc{parsedFolderOrder} = [];
  for my $nameFolderPair(@{parseFolders $acc}){
    my ($name, $folder) = @$nameFolderPair;
    $$acc{parsedFolders}{$name} = $folder;
    push @{$$acc{parsedFolderOrder}}, $name;
  }
}

sub getFolderName($){
  my $folder = shift;
  my $name = lc $folder;
  $name =~ s/[^a-z0-9]+/_/g;
  $name =~ s/^_+//;
  $name =~ s/_+$//;
  return $name;
}

sub parseFolders($){
  my $acc = shift;
  my $folders = [];

  my $folder = defined $$acc{inbox} ? $$acc{inbox} : "INBOX";
  my $name = "inbox";
  push @$folders, [$name, $folder];

  if(defined $$acc{sent}){
    my $folder = $$acc{sent};
    my $name = "sent";
    push @$folders, [$name, $folder];
  }
  if(defined $$acc{folders}){
    for my $folder(split /:/, $$acc{folders}){
      $folder =~ s/^\s*//;
      $folder =~ s/\s*$//;
      my $name = getFolderName $folder;
      push @$folders, [$name, $folder];
    }
  }
  return $folders;
}
sub parseCountIncludeFolderNames($){
  my $acc = shift;
  my $countInclude = $$acc{count_include};
  $countInclude = "inbox" if not defined $countInclude;

  my $countIncludeFolderNames = [split /:/, $countInclude];
  s/^\s*// foreach @$countIncludeFolderNames;
  s/\s*$// foreach @$countIncludeFolderNames;

  my $folders = parseFolders $acc;
  my $okFolderNames = join "|", map {$$_[0]} @$folders;

  my $seenFolderNames = {};
  for my $folderName(@$countIncludeFolderNames){
    if(defined $$seenFolderNames{$folderName}){
      die "ERROR: duplicate folder name in count_include: $folderName\n";
    }
    $$seenFolderNames{$folderName} = 1;
    if($folderName !~ /^($okFolderNames)$/){
      die "ERROR: count_include folder name '$folderName' not found in:\n"
        . "  [$okFolderNames]\n";
    }
  }

  return $countIncludeFolderNames;
}

1;
