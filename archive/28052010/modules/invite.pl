##########
# INVITE #
##########
sub command_invite {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Access Denied.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, invite [nick]\002 to invite [nick] to $channel.");
    next;  
  }

  $query = substr($text,7);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("I'm not going to invite myself, moron.");
      next;
    }

    snd("INVITE $query $channel");
  }
  next;
}
