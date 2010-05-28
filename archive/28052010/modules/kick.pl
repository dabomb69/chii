$hlp{"KICK"} = "Kicks a user from a channel.";
#############
# OPER KICK #
#############
sub command_kick {

  local $query = "";
  local $tokick = "";
  local $chan2kick = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,5);
    if (index($query, " ") == -1) {
      sndtxt ("Missing parameter");
      next;
    }
    $tokick = substr($query,0,index($query," "));
    $chan2kick  = substr($query,index($query," ")+1);
  
	snd(":$uuid KICK $chan2kick $tokick :User removed from channel");
    snd("PRIVMSG $ctrl :$tokick kicked from $chan2kick by request of $nickname");
    next;
  } else {
    sndtxt("Denied.");
    next;
  }
}

$hlp{"KICK"} = "Kicks a user from a channel.";
#############
# OPER Test #
#############
sub command_variabletest {

  local $query = "";
  local $chan2kick = "";
  local $tokick = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,13);
    if (index($query, " ") == -1) {
      sndtxt ("Missing parameter");
      next;
    }
    $chan2kick = substr($query,0,index($query," "));
    $tokick  = substr($query,index($query," ")+1);
  
	#snd(":$uuid KICK $chan2kick $tokick :User removed from channel");
    #snd("PRIVMSG $ctrl :$tokick kicked from $chan2kick by request of $nickname");
    #snd(":$uuid PRIVMSG $ctrl :My variables are: Query is $query, Channel to kick is $chan2kick, and the user I would kick is $tokick");
	snd("PRIVMSG $ctrl :VARIABLES");
	snd("PRIVMSG $ctrl :\$line is $line");
	snd("PRIVMSG $ctrl :\$text is $text");
	snd("PRIVMSG $ctrl :\$query is $query");
	snd("PRIVMSG $ctrl :\$chan2kick is $chan2kick");
	snd("PRIVMSG $ctrl :\$tokick is $tokick");	
	next;
  } else {
    sndtxt("Denied.");
    next;
  }
}
