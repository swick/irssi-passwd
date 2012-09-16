use strict;

use IPC::Open3;
use Irssi;
use Symbol;
use YAML;


Irssi::command_bind connectk => sub {
  my ($account) = @_;
  my $cfg_file = "$ENV{HOME}/.irssi/login";

  my $cfg = YAML::LoadFile($cfg_file);

  my $acc = $cfg->{$account};
  if(!$acc) {
    Irssi::print("no account $account in config file");
    return;
  }
  my $cmd = $acc->{cmd} or die("no cmd (connect command) in config file");
  my $ring = $acc->{ring} or die("no ring (keyring) in config file");
  my $key = $acc->{key} or die("no key in config file");

  # get password from $ring and $key
  my ($stdin, $stdout, $stderr);
  $stderr = gensym();
  my $pid = open3($stdin, $stdout, $stderr, "python $ENV{HOME}/.irssi/scripts/gnomekeyring.py $ring $key");
  waitpid($pid, 0);

  if($? != 0) {
    Irssi::print("can't get password for $account");
    return;
  }

  my $password = join('', <$stdout>);
  chomp($password);

  $cmd =~ s/<password(:[^>]*)?>/$password/;
 
  Irssi::command($cmd);
}
