sub command_randkick {
  if ($usermode !~ / OP /) {
        sndtxt ("Access denied.");
       next;
        }
	snd(":$uuid KICK $channel Heather :Random user kicked from channel");
	next;
}



