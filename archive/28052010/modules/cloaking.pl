#####################
# Cloaking! :D
#####################
sub command_cloak {
	if($usermode !~ / STAFF /) {
		snd(":$uuid NOTICE $nickname :Access denied.");
		next;
	}
	
	$user = substr($text, 6);
	if(($user =~ /`/) or ($user =~ /\^/) or ($user =~ /\[/) or ($user =~ /\]/) or ($user =~ /\{/) or ($user =~ /\}/) or ($user =~ /\|/)) {
#		print "user contains speshul characters\n";
#		print "cloak is: ";
		$user = s/`//;
		$user = s/\^//;
		$user = s/\[//;
		$user = s/\]//;
		$user = s/\{//;
		$user = s/\}//;
		$user = s/\|//;
		$user = lc($user);
		$random_numbers = int(rand(1000));
#		print "unaffiliated/${user}/x-${random_numbers}\n";
		sndtxt("cloak is unaffiliated/$user/x-$random_numbers");
	} else {
		snd(":$uuid PRIVMSG NickServ :vhost $user unaffiliated/".lc($user));
		$user = lc($user);
		snd(":$uuid PRIVMSG $channel cloak is unaffiliated/${user}");
	}
	next;
}