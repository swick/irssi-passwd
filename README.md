# Discontinued!

This repo is not being maintained anymore. Further development is happening here: https://github.com/gandalf3/irssi-passwd

# irssi-passwd
the script receives passwords from other scripts (like gnomekeyring.py) and uses them to connect to a server or in any command

## warning
The passwd.pl script needs a modified version if irssi. Apply the patch irssi-connection-set-key.patch, then compile and install.

    cd path/to/irssi_src
    patch -p1 < path/to/irssi-connection-set-key.patch
    ./autogen.sh
    make
    sudo make install


## install
move passwd.pl to ~/.irssi/scripts
create a symlink in ~/.irssi/scripts/autorun/ to ~/.irssi/scripts/passwd.pl

## configure
The default config file is ~/.irssi/passwd and can be changed with the setting config_file in the passwd section.
In the config file you can store a command which will print the password for the password\_id to stdout.
The password\_id ([a-zA-Z0-9_\\-]+) and the command are seperated by a : (colon), each pair is seperated by a newline:

    example_id      : echo "mypassword"
    example_keyring : python ~/.irssi/scripts/gnomekeyring.py mykeyring nameofthekey


## use

### /passwd

    /passwd password_id irc_command

will replace the string &lt;password> in irc\_command with the password received from the command associated with password\_id. irc\_command is executed at the end.

    /passwd example_id /echo <password>

The script looks up the command associated with example\_id in the config file (echo "mypassword"), execute it and replace &lt;password> with the output ("mypassword").
The result (/echo "mypassword") is executed.

    /passwd example_keyring /msg NickServ identify <password>

Here the script will identify your nick with the password from the gnome keyring.

### irssi server config 

If the script is loaded it will automatically replace &lt;password:password\_id> in the server config with the value received from to command associated with password\_id
when the server is connecting.

    {
      address = "irc.freenode.net";
      chatnet = "Freenode";
      password = "user:<password:example_id>";
      autoconnect = "yes";
    }

Assuming the following config, irssi will automatically connect to irc.freenode.net, replace "user:&lt;password:example\_id>" with "user:mypassword" and login.

