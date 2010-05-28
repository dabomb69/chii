sub command_svsnick {
  if ($usermode !~ / SUPERADMIN /) {
        sndtxt ("Access denied.");
        next;
        }
        $query = substr($text,8);
	$time = time;
	snd(":$sid SVSNICK $query $time");
        next;
}



