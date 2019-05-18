use strict;

use IPC::Open3;
use Irssi;
use Symbol;


my $passwords;
my $help_passwd = '
PASSWD <passwd_id> <command>

  Replaces the string \'<password>\' with the password from passwd_id in command and executes the result.
  The passwd_id\'s are defined in \'~/.irssi/passwd\' (or in the file specified by the setting config_file in the section passwd).
  The format of the password file is \'passwd_id:command\\n\' where command writes the password to stdout
';

Irssi::settings_add_str('passwd', 'config_file', "$ENV{HOME}/.irssi/passwd");
passwd_init();

sub passwd_init {
  my $cfg_file = Irssi::settings_get_str('config_file');
  open my $handle, $cfg_file or return;

  my %cfg;
  while(<$handle>) {
    my $line = $_;
    if($line =~ /^\s*([a-zA-Z0-9_\-]+)\s*:(.*)$/) {
      my $key = $1;
      my $value = $2;
      $value =~ s/^\s*//;
      $cfg{$key} = $value;
      next;
    }
    if($line =~ /^\s*$/) {
      next;
    }
    Irssi::print("syntax error in file $cfg_file:$.", MSGLEVEL_CLIENTCRAP);
  }

  close $handle;
  $passwords = \%cfg;
}

sub passwd_get_password {
  my ($pw_key) = @_;
  my ($stdin, $stdout, $stderr);
  my $cmd = $passwords->{$pw_key};
  if(!$cmd) {
    Irssi::print("No command to get password $pw_key", MSGLEVEL_CLIENTCRAP);
    return;
  }

  $stderr = gensym();
  my $pid = open3($stdin, $stdout, $stderr, $cmd);
  waitpid($pid, 0);

  if($? != 0) {
    my $error = join('', <$stderr>);
    chomp($error);
    Irssi::print("Couldn't get password: $error", MSGLEVEL_CLIENTCRAP);
    return;
  }

  my $pw = join('', <$stdout>);
  chomp($pw);
  return $pw;
}

Irssi::signal_add_first('server connecting', sub {
  my ($server, @rest) = @_;
  if($server->{password} =~ /\<password:([a-zA-Z0-9]+)\>/) {
    my $password = passwd_get_password($1);
    $server->{password} =~ s/\<password:[a-zA-Z0-9]+\>/$password/;
    Irssi::Server::connection_set_key($server, 'password', $server->{password});
  }
  Irssi::signal_continue($server, @rest);
});

Irssi::command_bind('passwd', sub {
  my ($args, $server) = @_;
  my @argv = split(/ /, $args);
  my $argc = @argv;
  if($argc < 2) {
    Irssi::print('Too few arguments', MSGLEVEL_CLIENTCRAP);
    return;
  }
  my $cmd = join(' ', @argv[1..$argc-1]);
  my $pw = passwd_get_password(@argv[0]);
  $cmd =~ s/\<password\>/$pw/;
  $server->command($cmd);
});

Irssi::command_bind('help', sub {
  if($_[0] =~ /^\s*passwd\s*$/) {
    Irssi::print($help_passwd, MSGLEVEL_CLIENTCRAP);
    Irssi::signal_stop;
  }
});

Irssi::signal_add_first('complete word', sub {
  my ($strings, $window, $word, $linestart, $want_space) = @_;

  return if $linestart ne '/passwd';

  foreach my $key (keys %$passwords) {
    my $sub = substr($key, 0, length($word));
    if($sub eq $word) {
      push(@$strings, $key);
      $$want_space = 1;
    }
  }

  Irssi::signal_stop;
});

