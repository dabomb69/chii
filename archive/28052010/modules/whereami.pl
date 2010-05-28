sub command_whereami {
#  if ($usermode !~ / ADDFACTS /) {
#        sndtxt ("Access denied.");
 #       next;
#        }
        #$query = substr($text,8);
	#snd(":$uuid PRIVMSG $channel :Ohai! Iz example command frum $nickname kthnxbai <3");
        snd(":$uuid PRIVMSG $channel :Ohai! You're in $channel! Thanks for flying SpartaIRC!");
	next;
}



