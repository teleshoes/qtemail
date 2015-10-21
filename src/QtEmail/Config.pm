package QtEmail::Config;
use strict;
use warnings;
use lib "/opt/qtemail/lib";
use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  getConfig formatConfig writeConfig
  formatSchemaSimple formatSchemaPretty
  getSecretsFile getSecretsPrefix
  getAccountConfigSchema getOptionsConfigSchema
  getAccReqConfigKeys getAccOptConfigKeys getOptionsConfigKeys
);

sub getConfig();
sub formatConfig($);
sub writeConfig($@);
sub formatSchemaSimple($);
sub formatSchemaPretty($$);
sub getSecretsFile();
sub getSecretsPrefix();
sub getAccountConfigSchema();
sub getOptionsConfigSchema();
sub getAccReqConfigKeys();
sub getAccOptConfigKeys();
sub getOptionsConfigKeys();
########
sub readSecrets();
sub validateSecrets($);
sub modifySecrets($$);
sub joinTrailingBackslashLines(@);

my $GVAR = QtEmail::Shared::GET_GVAR;

my $secretsFile = "$ENV{HOME}/.secrets";
my $secretsPrefix = "email";
my $accountConfigSchema = [
  ["user",            "REQ", "IMAP username, usually the full email address"],
  ["password",        "REQ", "password, stored with optional encrypt_cmd"],
  ["server",          "REQ", "IMAP server, e.g.: \"imap.gmail.com\""],
  ["port",            "REQ", "IMAP server port"],

  ["smtp_server",     "OPT", "SMTP server, e.g.: \"smtp.gmail.com\""],
  ["smtp_port",       "OPT", "SMTP server port"],
  ["ssl",             "OPT", "set to false to forcibly disable security"],
  ["inbox",           "OPT", "primary IMAP folder name (default=\"INBOX\")"],
  ["sent",            "OPT", "IMAP folder name to use for sent mail, e.g.:\"Sent\""],
  ["folders",         "OPT", "extra IMAP folders to fetch (sep=\":\")"],
  ["count_include",   "OPT", "FOLDER_NAMEs for counts (default=\"inbox\", sep=\":\")"],
  ["skip",            "OPT", "set to true to skip during --update"],
  ["body_cache_mode", "OPT", "one of [unread|all|none] (default=\"unread\")"],
  ["prefer_html",     "OPT", "prefer html over plaintext (default=\"false\")"],
  ["new_unread_cmd",  "OPT", "custom alert command"],
  ["update_interval", "OPT", "GUI: seconds between account updates"],
  ["refresh_interval","OPT", "GUI: seconds between account refresh"],
  ["filters",         "OPT", "GUI: list of filter-buttons, e.g.:\"s1=%a% s2=%b%\""],
];
my $optionsConfigSchema = [
  ["update_cmd",      "OPT", "command to run after all updates"],
  ["encrypt_cmd",     "OPT", "command to encrypt passwords on disk"],
  ["decrypt_cmd",     "OPT", "command to decrypt saved passwords"],
];
my $longDescriptions = {
  folders => ''
    . "the FOLDER_NAME used as the dir on the filesystem\n"
    . "has non-alphanumeric substrings replaced with _s\n"
    . "and all leading and trailing _s removed\n"
    . "e.g.:\n"
    . "  email.Z.folders = junk:[GMail]/Drafts:_12_/ponies\n"
    . "    =>  [\"junk\", \"gmail_drafts\", \"12_ponies\"]\n"
  ,
  count_include => ''
    . "list of FOLDER_NAMEs for account-wide unread/total counts\n"
    . "this controls what gets written to the global unread file,\n"
    . "  and what is returned by --accounts\n"
    . "note this is the FOLDER_NAME, and not the IMAP folder\n"
    . "e.g.:\n"
    . "  email.Z.sent = [GMail]/Sent Mail\n"
    . "  email.Z.folders = [GMail]/Spam:[GMail]/Drafts\n"
    . "  email.Z.count_include = inbox:gmail_spam:sent\n"
    . "    => included: INBOX, [GMail]/Spam, [GMail]/Sent Mail\n"
    . "       excluded: [GMail]/Drafts\n"
  ,
  body_cache_mode => ''
    . "controls which bodies get cached during --update\n"
    . "  (note: only caches the first MAX_BODIES_TO_CACHE=$$GVAR{MAX_BODIES_TO_CACHE})\n"
    . "unread: cache unread bodies (up to $$GVAR{MAX_BODIES_TO_CACHE})\n"
    . "all:    cache all bodies (up to $$GVAR{MAX_BODIES_TO_CACHE})\n"
    . "none:   do not cache bodies during --update\n"
  ,
  filters => ''
    . "each filter is separated by a space, and takes the form:\n"
    . "  <FILTER_NAME>=%<FILTER_STRING>%\n"
    . "FILTER_NAME:   the text of the button in the GUI\n"
    . "FILTER_STRING: query for $$GVAR{EMAIL_SEARCH_EXEC}\n"
    . "e.g.:\n"
    . "  email.Z.filters = mary=%from~\"mary sue\"% ok=%body!~viagra%\n"
    . "    => [\"mary\", \"ok\"]\n"
  ,
};

my @accReqConfigKeys = map {$$_[0]} grep {$$_[1] eq "REQ"} @$accountConfigSchema;
my @accOptConfigKeys = map {$$_[0]} grep {$$_[1] eq "OPT"} @$accountConfigSchema;
my %enums = (
  body_cache_mode => [qw(all unread none)],
);
my @optionsConfigKeys = map {$$_[0]} @$optionsConfigSchema;

sub getConfig(){
  my $config = readSecrets();
  validateSecrets $config;
  return $config;
}

sub formatConfig($){
  my $configGroup = shift;
  my $config = readSecrets;
  my $accounts = $$config{accounts};
  my $options = $$config{options};
  my $vals = defined $configGroup ? $$accounts{$configGroup} : $options;
  my $fmt = '';
  if(defined $vals){
    for my $key(sort keys %$vals){
      $fmt .= "$key=$$vals{$key}\n";
    }
  }
  return $fmt;
}

sub writeConfig($@){
  my ($configGroup, @keyVals) = @_;
  my $config = {};
  for my $keyVal(@keyVals){
    if($keyVal =~ /^(\w+)=(.*)$/){
      $$config{$1} = $2;
    }else{
      die "Malformed KEY=VAL entry: $keyVal\n";
    }
  }
  modifySecrets $configGroup, $config;
}

sub formatSchemaSimple($){
  my ($schema) = @_;
  my $fmt = '';
  for my $row(@$schema){
    my ($name, $reqOpt, $desc) = @$row;
    $fmt .= "$name=[$reqOpt] $desc\n";
  }
  return $fmt;
}

sub formatSchemaPretty($$){
  my ($schema, $indent) = @_;
  my $maxNameLen = 0;
  for my $nameLen(map {length $$_[0]} @$schema){
    $maxNameLen = $nameLen if $nameLen > $maxNameLen;
  }
  my $fmt = '';
  for my $row(@$schema){
    my ($name, $reqOpt, $desc) = @$row;
    my $sep = ' ' x (1 + $maxNameLen - length $name);
    my $prefix = $indent . $name . $sep;
    my $info = "[$reqOpt] $desc\n";
    if(defined $$longDescriptions{$name}){
      my $infoIndent = ' ' x (length $prefix);
      my @longLines = split /\n/, $$longDescriptions{$name};
      @longLines = map {"$infoIndent$_\n"} @longLines;
      $info .= join '', @longLines;
    }
    $fmt .= "$prefix$info";
  }
  return $fmt;
}

sub getSecretsFile(){
  return $secretsFile;
}
sub getSecretsPrefix(){
  return $secretsPrefix;
}
sub getAccountConfigSchema(){
  return $accountConfigSchema;
}
sub getOptionsConfigSchema(){
  return $optionsConfigSchema;
}
sub getAccReqConfigKeys(){
  return @accReqConfigKeys;
}
sub getAccOptConfigKeys(){
  return @accOptConfigKeys;
}
sub getOptionsConfigKeys(){
  return @optionsConfigKeys;
}

#######################

sub readSecrets(){
  my @lines = `cat $secretsFile 2>/dev/null`;
  my $accounts = {};
  my $accOrder = [];
  my $okAccReqConfigKeys = join "|", (@accReqConfigKeys, @accOptConfigKeys);
  my $okOptionsConfigKeys = join "|", (@optionsConfigKeys);
  my $optionsConfig = {};
  my $decryptCmd;
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.decrypt_cmd\s*=\s*(.*)$/s){
      $decryptCmd = $1;
      chomp $decryptCmd;
      last;
    }
  }

  @lines = joinTrailingBackslashLines(@lines);

  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.($okOptionsConfigKeys)\s*=\s*(.+)$/s){
      $$optionsConfig{$1} = $2;
    }elsif($line =~ /^$secretsPrefix\.(\w+)\.($okAccReqConfigKeys)\s*=\s*(.+)$/s){
      my ($accName, $key, $val)= ($1, $2, $3);
      if(not defined $$accounts{$accName}){
        $$accounts{$1} = {name => $accName};
        push @$accOrder, $accName;
      }
      if(defined $decryptCmd and $key =~ /password/){
        $val =~ s/'/'\\''/g;
        $val = `$decryptCmd '$val'`;
        die "error decrypting password\n" if $? != 0;
      }
      chomp $val;
      $$accounts{$accName}{$key} = $val;
    }elsif($line =~ /^$secretsPrefix\./){
      die "unknown config entry: $line";
    }
  }
  return {accounts => $accounts, accOrder => $accOrder, options => $optionsConfig};
}

sub validateSecrets($){
  my $config = shift;
  my $accounts = $$config{accounts};
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    for my $key(sort @accReqConfigKeys){
      die "Missing '$key' for '$accName' in $secretsFile\n" if not defined $$acc{$key};
    }
  }
}

sub modifySecrets($$){
  my ($configGroup, $config) = @_;
  my $prefix = "$secretsPrefix";
  if(defined $configGroup){
    if($configGroup !~ /^\w+$/){
      die "invalid account name, must be a word i.e.: \\w+\n";
    }
    $prefix .= ".$configGroup";
  }

  my @lines = `cat $secretsFile 2>/dev/null`;
  @lines = joinTrailingBackslashLines(@lines);

  my $encryptCmd;
  for my $line(@lines){
    if($line =~ /^$secretsPrefix\.encrypt_cmd\s*=\s*(.*)$/s){
      $encryptCmd = $1;
      chomp $encryptCmd;
      last;
    }
  }

  my %requiredConfigKeys = map {$_ => 1} @accReqConfigKeys;

  my $okConfigKeys = join "|", (@accReqConfigKeys, @accOptConfigKeys);
  my $okOptionsKeys = join "|", (@optionsConfigKeys);
  for my $key(sort keys %$config){
    if(defined $configGroup){
      die "Unknown config key: $key\n" if $key !~ /^($okConfigKeys)$/;
    }else{
      die "Unknown options key: $key\n" if $key !~ /^($okOptionsKeys)$/;
    }
    my $val = $$config{$key};
    my $valEmpty = $val =~ /^\s*$/;
    if($valEmpty){
      if(defined $configGroup and defined $requiredConfigKeys{$key}){
        die "must include '$key'\n";
      }
    }
    if(defined $encryptCmd and $key =~ /password/i){
      $val =~ s/'/'\\''/g;
      $val = `$encryptCmd '$val'`;
      die "error encrypting password\n" if $? != 0;
      chomp $val;
    }
    my $newLine = $valEmpty ? '' : "$prefix.$key = $val\n";
    my $found = 0;
    for my $line(@lines){
      if($line =~ s/^$prefix\.$key\s*=.*\n$/$newLine/s){
        $found = 1;
        last;
      }
    }
    if(not $valEmpty and defined $enums{$key}){
      my $okEnum = join '|', @{$enums{$key}};
      die "invalid $key: $val\nexpects: $okEnum" if $val !~ /^($okEnum)$/;
    }
    push @lines, $newLine if not $found;
  }

  open FH, "> $secretsFile" or die "Could not write $secretsFile\n";
  print FH @lines;
  close FH;
}

sub joinTrailingBackslashLines(@){
  my @oldLines = @_;
  my @lines;

  my $curLine = undef;
  for my $line(@oldLines){
    my $isBackslashLine = $line =~ /\\\s*\n?/;

    $curLine = '' if not defined $curLine;
    $curLine .= $line;

    if(not $isBackslashLine){
      push @lines, $curLine;
      $curLine = undef;
    }
  }
  push @lines, $curLine if defined $curLine;

  return @lines;
}

1;
