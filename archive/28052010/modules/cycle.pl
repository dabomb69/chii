sub command_cycle {
  if ($usermode !~ / STAFF /) {
	snd (":$uuid NOTICE $nickname :Access denied.");
	next;
	}
	$query = $channel;
	snd(":$uuid PART $query :Cycling");
	snd(":$uuid JOIN $query");
	next;
}