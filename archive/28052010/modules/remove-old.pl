##########
# REMOVE #
##########
sub command_remove {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can kick users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, remove [nick]\002 to remove [nick] from $channel.");
    next;  
  }

  $query = substr($text,7);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("I'm not going to remove myself, moron.");
      next;
    }

    snd("REMOVE $query :User removed from channel");
  }
  next;
}