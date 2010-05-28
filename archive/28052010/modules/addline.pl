$hlp{"ADDLINE"} = "Adds a Q/K/G/Z/E:Line to the specified hostmask";
#############
#  ADDLINE  #
#############
sub command_addline {

  local $query = "";
  local $linetype = "";
  local $nick = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,8);
    if (index($query, " ") == -1) {
      sndtxt ("Missing parameter");
      next;
    }
    $linetype = substr($query,0,index($query," "));
    $nick = substr($query,index($query," ")+1);
	
	snd("ADDLINE $linetype $nick $botname ".time." 0 :Requested by SpartaIRC Staff");
    snd(":$uuid PRIVMSG $ctrl :$nick has been added to the XLINE database under line $linetype by $nickname");
    next;
  } else {
    sndtxt("Denied.");
    next;
  }
}