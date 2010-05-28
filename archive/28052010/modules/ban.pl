###########
# KICKBAN #
###########
sub command_kickban {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can kickban users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, kickban [nick]\002 to kickban [nick] from $channel.");
    next;  
  }

  $query = substr($text,8);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {

    if (lc($query) eq lc($botname)) {
      sndtxt ("I'm not going to kickban myself, moron.");
      next;
    }

    snd("MODE $channel +b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1));
    snd("KICK $channel $query :$kicks[rand($#kicks)]");
  }
  next;
}


########### 
# JUSTBAN # 
########### 
sub command_ban { 
 
  local $query = ""; 
  local @tokick; 
 
  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) { 
    sndtxt ("Only users with access level OP can ban users."); 
    next; 
  } 
 
  if (index($text," ") == -1) {  
    sndtxt ("Missing parameter. Use \002${botname}, ban [nick]\002 to ban [nick] from $channel."); 
    next;   
  } 
 
 
  $query = substr($text,4); 
 
  @tokick = split(" ",$query); 
 
  foreach $query (@tokick) { 
 
    if (lc($query) eq lc($botname)) { 
      sndtxt ("I'm not going to ban myself, moron."); 
      next; 
    } 

    snd("MODE $channel +b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1)); 
  } 
  next; 
} 

########### 
# UN  BAN # 
########### 
sub command_unban { 
 
  local $query = ""; 
  local @tokick; 
 
  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) { 
    sndtxt ("Only users with access level OP can unban users."); 
    next; 
  } 
 
  if (index($text," ") == -1) {  
    sndtxt ("Missing parameter. Use \002${botname}, unban [nick]\002 to unban [nick] from $channel."); 
    next;   
  } 
 
  $query = substr($text,6); 
 
  @tokick = split(" ",$query); 
 
  foreach $query (@tokick) { 
 
  snd("MODE $channel -b *!*@" . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1)); 
  } 
  next; 
} 