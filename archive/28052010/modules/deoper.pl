sub command_deoper {
  if ($usermode !~ / SUPERADMIN /) {
	snd (":$uuid NOTICE $nickname :Access denied.");
	next;
	}
	$query = substr($text,7);
	snd(":$uuid MODE $query -o");
	snd(":$uuid PRIVMSG $ctrl :$query has been deopered.");
	next;
}