sub command_jupe {
  if ($usermode !~ / SUPERADMIN /) {
        sndtxt ("Access denied.");
       next;
        }
	$query = substr($text,5);
	$randno1 = int(rand(9));
	$randsid = int(rand(9));
	$randsid2 = int(rand(9));
	$letter1 = $letters[rand $total];
	$lolsid = $randno1.$randsid.$randsid2;
	$random = int(rand(9001));
	snd(":$uuid RSQUIT $query");
	snd(":$sid SERVER $query * $random $lolsid :Services juped server");
	snd(":$uuid PRIVMSG $ctrl :$query jupitered by $nickname");
	next;
}



sub command_unjupe {
  if ($usermode !~ / SUPERADMIN /) {
        sndtxt ("Access denied.");
       next;
        }

	$query = substr($text,7);
	snd(":$uuid SQUIT $query");
	snd(":$uuid PRIVMSG $ctrl :$query unjupitered by $nickname");
	next;
}
