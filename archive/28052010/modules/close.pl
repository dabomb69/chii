sub command_close {
  if ($usermode !~ / STAFF /) {
	snd (":$uuid NOTICE $nickname :Access denied.");
	next;
	}
	$query = substr($text,6);
	snd(":$uuid JOIN $query");
	snd(":$uuid PRIVMSG OperServ :MODE $query +qao $botname $botname $botname");
	snd(":$uuid PRIVMSG $query :Attention all, $query is now being closed at request of SpartaIRC Staff.  Thanks for flying $netname!");
	sleep 10;
	snd(":$uuid CBAN $query 0 :Channel reserved by $botname");
	snd(":$uuid PRIVMSG OperServ :CLEARCHAN KICK $query Channel reserved by $botname");
	snd(":$uuid PRIVMSG ChanServ :FDROP $query");
	snd(":$uuid PRIVMSG ChanServ :REGISTER $query");
	snd(":$uuid PRIVMSG ChanServ :CLOSE $query ON Channel reserved by $botname");
	snd(":$uuid PRIVMSG ChanServ :MARK $query ON Channel closed by SpartaIRC Staff");
	snd("$uuid PRIVMSG $ctrl :$query closed by $nickname");
	next;
}