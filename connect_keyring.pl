use strict;

use IPC::Open3;
use Irssi;
use Symbol;
use Config::Irssi::Parser;
use Data::Dumper;

sub load_config {
  my $cfg_file = "$ENV{HOME}/.irssi/config";
  open my $handle, $cfg_file;
  if(!$handle) {
    Irssi::print("Couldn't open file: $!");
    return;
  }

  my $p = new Config::Irssi::Parser;
  my $cfg = $p->parse($handle);
  if(!$cfg) {
    Irssi::print("Couldn't parse config file: $!");
    return;
  }

  close $handle;
  return $cfg;
}

sub find_password {
  my ($ring, $key) = @_;
  my ($stdin, $stdout, $stderr);
  $stderr = gensym();
  my $pid = open3($stdin, $stdout, $stderr, "python $ENV{HOME}/.irssi/scripts/gnomekeyring.py $ring $key");
  waitpid($pid, 0);

  if($? != 0) {
    Irssi::print("Couldn't get password");
    return;
  }

  my $password = join('', <$stdout>);
  chomp($password);
  return $password;
}

sub create_command {
  my ($server, $password) = @_;

  my $cmd = "connect ";
  if($server->{use_ssl} eq "yes") { $cmd .= "-ssl " }
  if($server->{ssl_verify} eq "yes") { $cmd .= "-ssl_verify " }
  if($server->{ssl_cert}) { $cmd .= "-ssl_cert=$server->{ssl_cert}" }
  if($server->{ssl_pkey}) { $cmd .= "-ssl_pkey=$server->{ssl_pkey} " }
  if($server->{ssl_cafile}) { $cmd .= "-ssl_cafile=$server->{ssl_cafile} " }
  if($server->{ssl_cacert}) { $cmd .= "-ssl_capath=$server->{ssl_cacert} " } # fixme
  if($server->{hostname}) { $cmd .= "-host=$server->{hostname} " }
  $cmd .= "$server->{address} ";
  $cmd .= "$server->{port} ";
  $cmd .= "$server->{nick}:$password ";
  $cmd .= "$server->{nick} ";

  return $cmd;
}

sub autoconnect {
  my $cfg = load_config() or return;
  foreach my $server (@{$cfg->{servers}}) {
    if($server->{autoconnect_keyring} eq "yes") {
      if(!$server->{keyring}) {
        Irssi::print("no keyring given");
        return;
      }
      if(!$server->{keyname}) {
        Irssi::print("no keyname given");
        return;
      }
      my $password = find_password($server->{keyring}, $server->{keyname}) or return;

      Irssi::command(create_command($server, $password));
    }
  }
}

sub print_help {
  print("KEYRING <keyring> <keyname> <command>
    replaces the string '<password>' in <command> with the password from the keyring and executes the command");
}

Irssi::command_bind keyring => sub {
  my ($args) = @_;
  my @argv = split(/ /, $args);
  my $argc = @argv;

  if($argc < 3) {
    print_help();
    return;
  }
  my $passwd = find_password($argv[0], $argv[1]) or return;
  my $cmd = join(" ", @argv[2..$#argv]);
  $cmd =~ s/\<password\>/$passwd/;
  Irssi::command($cmd);
};

autoconnect();

