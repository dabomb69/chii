#############
# OPER KILL #
#############
sub command_kill {

  local $query = "";
  local $killnick = "";
  local $killmsg = "Nick collision from $servname";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,5);

    $killnick = $query;
    if (lc($killnick) eq lc($botname)) {
      sndtxt ("Access Denied.  $nickname, you are an utter moron.");
      snd("kill $nickname :You are a moron.");
      next;
    }
     if (lc($killnick) eq lc($adminnick)) {
      sndtxt ("Access Denied.  $nickname, $adminnick is awesomer than you.");
      snd("kill $nickname :You are a moron.");
      next;
    }
    snd(":$uuid KILL $killnick :$killmsg");
    snd("PRIVMSG $ctrl :$killnick killed by request of $nickname");
    next;
  } else {
    sndtxt("Denied.");
    next;
  }
}
