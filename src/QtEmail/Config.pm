package QtEmail::Config;
use strict;
use warnings;
use lib "/opt/qtemail/lib";
use QtEmail::Shared qw(GET_GVAR);

our @ISA = qw(Exporter);
use Exporter;
our @EXPORT = qw(
  getConfig
  getAccPassword
  formatConfig writeConfig
  formatSchemaSimple
  formatSchemaPretty
  getConfigFile getConfigPrefix
  getAccountConfigSchema getOptionsConfigSchema
  getAccReqConfigKeys getAccOptConfigKeys getAccMapConfigKeys
  getOptionsConfigKeys
);

sub getConfig();
sub getAccPassword($$);
sub formatConfig($;$);
sub writeConfig($@);
sub formatSchemaSimple($);
sub formatSchemaPretty($$);
sub getConfigFile();
sub getConfigPrefix();
sub getAccountConfigSchema();
sub getOptionsConfigSchema();
sub getAccReqConfigKeys();
sub getAccOptConfigKeys();
sub getAccMapConfigKeys();
sub getOptionsConfigKeys();
########
sub readConfig();
sub validateConfig($);
sub modifyConfigs($$);
sub joinMultilineConfigEntries(@);

my $GVAR = QtEmail::Shared::GET_GVAR;

my $configFile = "$ENV{HOME}/.config/qtemail/qtemail.conf";
my $configPrefix = "email";
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
  ["custom_cmd",      "OPT", "GUI: shell command to run when cmd button is pushed"],
  ["filterButtons",   "OPT", "GUI: comma-separated list of list of filter names to use in GUI"],

  ["filter",          "MAP", "list of named search filters: filter.NAME = SEARCH_QUERY"],
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
  custom_cmd => ''
    . "command is run using 'sh -c', after prepending some environment variables\n"
    . "the following vars are set:\n"
    . "  QTEMAIL_ACCOUNT_NAME   QTEMAIL_FOLDER_NAME   QTEMAIL_UID\n"
    . "e.g.:\n"
    . "  1) config:\n"
    . "    email.WORK.custom_cmd = email.pl --delete --folder=\$QTEMAIL_FOLDER_NAME \$QTEMAIL_ACCOUNT_NAME \$QTEMAIL_UID\n"
    . "  2) runs this shell script:\n"
    . "    sh -c 'QTEMAIL_ACCOUNT_NAME=\"WORK\"; \\\n"
    . "           QTEMAIL_FOLDER_NAME=\"inbox\"; \\\n"
    . "           QTEMAIL_UID=\"42506\"; \\\n"
    . "           email.pl --delete --folder=\$QTEMAIL_FOLDER_NAME \$QTEMAIL_ACCOUNT_NAME \$QTEMAIL_UID'\n"
    . "  3) which has the same effect as running:\n"
    . "    email.pl --delete --folder=inbox WORK 42506\n"
  ,
  filter => ''
    . "one filter per config line:\n"
    . "  email.Z.filter.FILTER_NAME = SEARCH_STRING\n"
    . "FILTER_NAME:   name to pass to $$GVAR{EMAIL_SEARCH_EXEC}\n"
    . "SEARCH_STRING: query that $$GVAR{EMAIL_SEARCH_EXEC} will use\n"
    . "e.g.:\n"
    . "  email.Z.filter.mary = from~mary.smith\@gmaul.com\n"
    . "  email.Z.filter.jenkins = \n"
    . "    subject~jenkins \n"
    . "    ++ \n"
    . "    subject~\"build failed\"\n"
    . "  email.Z.filter.urgent = urgent\n"
  ,
};

my @accReqConfigKeys = map {$$_[0]} grep {$$_[1] eq "REQ"} @$accountConfigSchema;
my @accOptConfigKeys = map {$$_[0]} grep {$$_[1] eq "OPT"} @$accountConfigSchema;
my @accMapConfigKeys = map {$$_[0]} grep {$$_[1] eq "MAP"} @$accountConfigSchema;
my %enums = (
  body_cache_mode => [qw(all unread none)],
);
my @optionsConfigKeys = map {$$_[0]} @$optionsConfigSchema;

sub getConfig(){
  my $config = readConfig();
  validateConfig $config;
  return $config;
}

sub getAccPassword($$){
  my ($acc, $options) = @_;
  my $pass = $$acc{password};
  my $decryptCmd = $$options{decrypt_cmd};

  if(defined $decryptCmd){
    chomp $decryptCmd;
    $pass =~ s/'/'\\''/g;
    $pass = `$decryptCmd '$pass'`;
    die "error decrypting password\n" if $? != 0;
    chomp $pass;
  }

  return $pass;
}

sub formatConfig($;$){
  my ($configGroup, $singleKey) = @_;
  my $config = readConfig;
  my $accounts = $$config{accounts};
  my $options = $$config{options};
  my $vals = defined $configGroup ? $$accounts{$configGroup} : $options;
  my $fmt = '';
  if(defined $vals){
    for my $key(sort keys %$vals){
      my $val;
      if(defined $configGroup and $key =~ /password/){
        my $acc = $$accounts{$configGroup};
        $val = getAccPassword($acc, $options);
      }else{
        $val = $$vals{$key};
        chomp $val;
      }

      $val =~ s/\n/\\n/g;

      if(not defined $singleKey){
        $fmt .= "$key=$val\n";
      }elsif($key eq $singleKey){
        $fmt .= "$val\n";
      }
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
  modifyConfig $configGroup, $config;
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

sub getConfigFile(){
  return $configFile;
}
sub getConfigPrefix(){
  return $configPrefix;
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
sub getAccMapConfigKeys(){
  return @accMapConfigKeys;
}
sub getOptionsConfigKeys(){
  return @optionsConfigKeys;
}

#######################

sub readConfig(){
  my @lines = `cat $configFile 2>/dev/null`;
  my $accounts = {};
  my $accOrder = [];

  my $okAccReqConfigKeys = join "|", @accReqConfigKeys;
  my $okAccOptConfigKeys = join "|", @accOptConfigKeys;
  my $okAccMapConfigKeys = join "|", @accMapConfigKeys;
  my $okAccConfigKeys = ""
    . "(?:(?:$okAccReqConfigKeys)"
    .   "|(?:$okAccOptConfigKeys)"
    .   "|(?:(?:$okAccMapConfigKeys)\\.\\w+)"
    . ")"
    ;

  my $okOptionsConfigKeys = join "|", @optionsConfigKeys;
  my $optionsConfig = {};

  my @entries = joinMultilineConfigEntries(@lines);

  for my $entry(@entries){
    if($entry =~ /^$configPrefix\.($okOptionsConfigKeys)\s*=\s*(.+)$/s){
      $$optionsConfig{$1} = $2;
    }elsif($entry =~ /^$configPrefix\.(\w+)\.($okAccConfigKeys)\s*=\s*(.+)$/s){
      my ($accName, $key, $val)= ($1, $2, $3);
      if(not defined $$accounts{$accName}){
        $$accounts{$1} = {name => $accName};
        push @$accOrder, $accName;
      }
      chomp $val;
      $$accounts{$accName}{$key} = $val;
    }elsif($entry =~ /^$configPrefix\./){
      die "unknown config entry: $entry";
    }
  }
  return {accounts => $accounts, accOrder => $accOrder, options => $optionsConfig};
}

sub validateConfig($){
  my $config = shift;
  my $accounts = $$config{accounts};
  for my $accName(keys %$accounts){
    my $acc = $$accounts{$accName};
    for my $key(sort @accReqConfigKeys){
      die "Missing '$key' for '$accName' in $configFile\n" if not defined $$acc{$key};
    }
  }
}

sub modifyConfig($$){
  my ($configGroup, $config) = @_;
  my $prefix = "$configPrefix";
  if(defined $configGroup){
    if($configGroup !~ /^\w+$/){
      die "invalid account name, must be a word i.e.: \\w+\n";
    }
    $prefix .= ".$configGroup";
  }

  my @lines = `cat $configFile 2>/dev/null`;
  my @entries = joinMultilineConfigEntries(@lines);

  my $encryptCmd;
  for my $entry(@entries){
    if($entry =~ /^$configPrefix\.encrypt_cmd\s*=\s*(.*)$/s){
      $encryptCmd = $1;
      chomp $encryptCmd;
      last;
    }
  }

  my %requiredConfigKeys = map {$_ => 1} @accReqConfigKeys;

  my $okAccReqConfigKeys = join "|", @accReqConfigKeys;
  my $okAccOptConfigKeys = join "|", @accOptConfigKeys;
  my $okAccMapConfigKeys = join "|", @accMapConfigKeys;
  my $okAccConfigKeys = ""
    . "(?:(?:$okAccReqConfigKeys)"
    .   "|(?:$okAccOptConfigKeys)"
    .   "|(?:(?:$okAccMapConfigKeys)\\.\\w+)"
    . ")"
    ;
  my $okOptionsConfigKeys = join "|", @optionsConfigKeys;

  for my $key(sort keys %$config){
    if(defined $configGroup){
      die "Unknown config key: $key\n" if $key !~ /^($okAccConfigKeys)$/;
    }else{
      die "Unknown options key: $key\n" if $key !~ /^($okOptionsConfigKeys)$/;
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
    my $newEntry = $valEmpty ? '' : "$prefix.$key = $val\n";
    my $found = 0;
    for my $entry(@entries){
      if($entry =~ s/^$prefix\.$key\s*=.*\n$/$newEntry/s){
        $found = 1;
        last;
      }
    }
    if(not $valEmpty and defined $enums{$key}){
      my $okEnum = join '|', @{$enums{$key}};
      die "invalid $key: $val\nexpects: $okEnum" if $val !~ /^($okEnum)$/;
    }
    push @entries, $newEntry if not $found;
  }

  open FH, "> $configFile" or die "Could not write $configFile\n";
  print FH @entries;
  close FH;
}

sub joinMultilineConfigEntries(@){
  my @lines = @_;
  my @entries;

  my $curEntry = "";
  for my $line(@lines){
    my $isContinuation;
    if($line =~ /^\s+/ or $curEntry =~ /\\$/){
      $isContinuation = 1;
    }else{
      $isContinuation = 0;
    }

    $line =~ s/(\s|\r|\n|\x00)+$//;

    if($isContinuation){
      $curEntry =~ s/\\$//;
      $curEntry .= "\n$line";
    }else{
      push @entries, $curEntry if defined $curEntry;
      $curEntry = $line;
    }
  }
  push @entries, $curEntry if defined $curEntry;

  return @entries;
}

1;
