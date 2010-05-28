sub command_whoami {
       snd(":$uuid PRIVMSG $channel :You are $nickname");
        next;
}

sub command_whoareyou {
	snd(":$uuid PRIVMSG $channel :I am $uuid");
next;
}

sub command_userinfo {
	snd(":$uuid PRIVMSG $channel :You are $nickname. I see your hostmask as $hostmask.");
next;
}
