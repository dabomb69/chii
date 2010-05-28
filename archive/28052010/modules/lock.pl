$hlp{"LOCK"} = "Locks the specified nickname until UNLOCK is preformed on it.";
$hlp{"UNLOCK"} = "Unlocks a LOCKed nickname.";
sub command_lock {

  local $query = "";
  local @tokick;

  if (($usermode !~ / STAFF /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Access Denied.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt("Missing parameter.");
	snd("PRIVMSG $nickname :Incorrect usage.  Please see $botname, help lock.");
    next;  
  }


  $query = substr($text,5);
   $rand = int(rand(9000));

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

	snd("SVSHOLD $query 0 :Locked");
	snd("SANICK $query Guest$rand");
	snd("NOTICE $nickname :$query has been locked.");
	snd("PRIVMSG $ctrl :$query locked by $nickname");
  }
  next;
}

sub command_unlock {

  local $query = "";
  local @tokick;

  if (($usermode !~ / STAFF /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Access Denied.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt("Missing parameter.");
	snd("PRIVMSG $nickname :Incorrect usage.  Please see $botname, help lock.");
    next;  
  }


  $query = substr($text,7);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

	snd("SVSHOLD $query");
	snd("NOTICE $nickname :$query has been unlocked.");
	snd("PRIVMSG $ctrl :$query unlocked by $nickname");
  }
  next;
}
