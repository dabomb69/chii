############
#   OP     #
############
sub command_op {
  
  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can +o users.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,3);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd(":$uuid MODE $channel +o $query");
  }
  next;
}
############
#   DEOP     #
############
sub command_deop {
  
  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can -o users.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,5);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd(":$uuid MODE $channel -o $query");
  }
  next;
}

