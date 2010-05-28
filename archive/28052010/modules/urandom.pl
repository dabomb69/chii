sub command_urandom {
$urandom = exec 'cat /dev/urandom';
snd(":$uuid PRIVMSG $channel :$urandom");
next;
}
