use strict;

use IPC::Open3;
use Irssi;
use Symbol;
use Config::Irssi::Parser;

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

sub find_server {
  my ($servers, $chatnet) = @_;
  foreach my $server (@{$servers}) {
    if($server->{chatnet} eq $chatnet) {
      return $server;
    }
  }
  Irssi::print("Couldn't find ChatNet");
  return;
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

Irssi::command_bind connect_keyring => sub {
  my ($chatnet) = @_;
  my ($chatnet, $only_auto) = @_;
  if(!$chatnet) {
    Irssi::print("no chatnet given");
    return;
  }

  my $cfg = load_config() or return;
  my $server = find_server($cfg->{servers}, $chatnet) or return;
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
};

autoconnect();

