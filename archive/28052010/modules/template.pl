sub command_example {
  if ($usermode !~ / ADDFACTS /) {
        sndtxt ("Access denied.");
       next;
        }
	$query = substr($text,8);
	snd(":$uuid PRIVMSG $channel :Ohai! Iz example command frum $nickname kthnxbai <3");
	next;
}



