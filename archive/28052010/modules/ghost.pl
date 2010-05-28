###########
#  GHOST  #
###########
sub command_ghost {

  local $query = "";
  local @tokick;

  if (($usermode !~ / STAFF /) && ($nicklist{lc($nickname)} ne '@')) {
	snd (":$uuid NOTICE $nickname :Access denied.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt("Missing parameter.");
	snd(":$uuid NOTICE $nickname :Incorrect usage.  Please see $botname, help ghost.");
    next;  
  }

@letters=(A..Z);
$total=@letters;
$letter1 = $letters[rand $total];
$letter2 = $letters[rand $total];
$letter3 = $letters[rand $total];
$letter4 = $letters[rand $total];
$letter5 = $letters[rand $total];
$letter6 = $letters[rand $total];
$ghostid = "$letter1$letter2$letter3$letter4$letter5$letter6";
$guuid = "$sid$ghostid";
  $query = substr($text,6);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    snd(":$uuid KILL $query :Nick collision from $servname");
	snd (":$sid UID $guuid 1 $query $servname $servname  enforcer 127.0.0.1 1 +IHB :Held for nickname owner");
	snd (":$guuid JOIN $ctrl");
	snd (":$sid MODE $ctrl +v $query");
	snd (":$uuid PRIVMSG $ctrl :Enforced nickname $query has been assigned UUID $guuid");
	snd(":$uuid NOTICE $nickname :$query has been ghosted");
    snd(":$uuid PRIVMSG $ctrl :GHOST Command issued for $query from $hostmask");
 	sleep 30;
	snd(":$uuid KILL $query :Enforcer timeout"); 
}
  next;
}

###########
#  GHOST  #
###########
sub command_ghostlock {

  local $query = "";
  local @tokick;

  if (($usermode !~ / STAFF /) && ($nicklist{lc($nickname)} ne '@')) {
	snd (":$uuid NOTICE $nickname :Access denied.");
    next;
  }

  if (index($text," ") == -1) { 
	snd (":$uuid NOTICE $nickname :Missing Parameter.");
	snd(":$uuid PRIVMSG $nickname :Incorrect usage.  Please see $botname, help ghost.");
    next;  
  }


  $query = substr($text,10);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    snd(":$uuid SVSHOLD $query 30 :Nick collision from $servname");
	snd(":$uuid KILL $query :Nick collision from $servname");
	snd(":$uuid NOTICE $nickname :$query has been ghosted");
    snd(":$uuid PRIVMSG $ctrl :GHOSTLOCK Command issued for $query from $hostmask");
  }
  next;
}

