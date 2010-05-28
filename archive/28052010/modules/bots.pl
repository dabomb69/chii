sub command_q {
	
  if ($userlevel =~ / 1337 /) {
	snd (":$uuid PRIVMSG $channel :Access denied.");
	next;
	}
	$query = substr($text,2);
	$qid = "666AAAAAQ";
	if ((lc($query) eq "on")) {
	snd (":$sid UID $qid 1 Q QServ.spartairc.co.cc QServ.spartairc.co.cc TheQBot 127.0.0.1 1 +IHBrk :The Q Bot");
	snd (":$qid OPERTYPE $opertype");
	snd (":$sid FJOIN $ctrl ".time." + :ao,$qid");
	snd (":$sid FJOIN #lobby ".time." + :ao,$qid");
	snd (":$uuid PRIVMSG $ctrl :Network Service bot 'Q' is now online.");
	}
	if ((lc($query) eq "off")) {
	snd (":$qid QUIT :Shutting down");
	}
	next;
}

sub command_mylevel {
	snd (":$uuid PRIVMSG $channel :Your userlevel is $userlevel");
next;
}
sub command_sudo {
	if ($usermode != / SUPERADMIN /) {
		snd(":$uuid PRIVMSG $channel :nun4u!");
	next;
}
$hostmask = $sudoer;
snd("PRIVMSG $channel :U can haz sudo! :3");
next;
}
sub command_servicesoverride {
	snd (":$sid	METADATA $uuid accountname $botname");
	next;
}
