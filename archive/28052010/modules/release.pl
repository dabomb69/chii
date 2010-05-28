###########
# RELEASE #
###########
sub command_release {

  local $query = "";
  local @tokick;
  $rand = int(rand(9000));

  if (($usermode !~ / STAFF /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Access Denied.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt("Missing parameter.");
	snd("PRIVMSG $nickname :Incorrect usage.  Please see $botname, help release.");
    next;  
  }


  $query = substr($text,8);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    snd("SVSNICK $query Guest$rand ".time);
	snd(":$uuid NOTICE $nickname :$query has been released.");
    snd(":$uuid PRIVMSG $ctrl :RELEASE Command issued from $nickname@" . substr($hosts{lc($nickname)},index($hosts{lc($nickname)},"\@")+1));
  }
  next;
}
