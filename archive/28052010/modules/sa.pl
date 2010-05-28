sub command_sakill {
  if ($usermode !~ / STAFF /) {
	snd (":$uuid2 NOTICE $nickname :Access denied.");
	next;
	}
	$query = substr($text,7);
	snd(":$sid KILL $query :$netname (User killed)");
	snd("PRIVMSG $ctrl :$nickname SAKILLed $query");
	next;
}

sub command_sakick {

  local $query = "";
  local $chan2kick = "";
  local $tokick = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,5);
    if (index($query, " ") == -1) {
      snd (":$uuid NOTICE $nickname :Missing parameter");
      next;
    }
    $chan2kick = substr($query,0,index($query," "));
    $tokick  = substr($query,index($query," ")+1);
  
	snd(":$sid KICK $chan2kick $tokick :User removed from channel");
    snd("PRIVMSG $ctrl :$tokick kicked from $chan2kick by request of $nickname");
    next;
  } else {
    snd(":$uuid2 NOTICE $nickname :Access Denied.");
    next;
  }
}

sub command_sapart {

  local $query = "";
  local $chan2kick = "";
  local $tokick = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,5);
    if (index($query, " ") == -1) {
      snd (":$uuid NOTICE $nickname :Missing parameter");
      next;
    }
    $chan2kick = substr($query,0,index($query," "));
    $tokick  = substr($query,index($query," ")+1);

        snd(":$sid SVSPART $tokick $chantokick");
    snd(":$uuid PRIVMSG $ctrl :$tokick removed from $chan2kick by request of $nickname");
   next;
  } else {
    snd(":$uuid2 NOTICE $nickname :Access Denied.");
    next;
  }
}

sub command_saoper {
  if ($usermode !~ / SUPERADMIN /) {
	snd (":$uuid NOTICE $nickname :Access denied.");
	next;
	}
	$query = substr($text,7);
	#snd(":$nickname OPERTYPE $opertype");
	snd(":$sid SVSOPER $query $svsoper");
	snd("PRIVMSG $ctrl :$nickname force OPERed");
	next;
}

sub command_sajoin {

  local $query = "";
  local $chan2join = "";
  local $tojoin = "";

  if ($usermode =~ / STAFF /) {
    $query = substr($text,5);
    if (index($query, " ") == -1) {
      snd (":$uuid NOTICE $nickname :Missing parameter");
      next;
    }
    $chan2join = substr($query,0,index($query," "));
    $tojoin  = substr($query,index($query," ")+1);

        snd(":$sid SVSJOIN $tojoin $chantojoin");
    snd(":$uuid PRIVMSG $ctrl :$tojoin force joined to $chan2join by request of $nickname");
   next;
  } else {
    snd(":$uuid2 NOTICE $nickname :Access Denied.");
    next;
  }
}

sub command_samode {
  if ($usermode !~ / SUPERADMIN /) {
    sndtxt ("Access Denied.");
    next;
  }

  $query = substr($text,7);
  snd(":$uuid SVSMODE $query");
  snd(":$uuid PRIVMSG $ctrl :$nickname used SAMODE to set the mode(s): $query");
  next;
}


