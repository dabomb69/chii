#!/bin/perl


######################
# REQUIRE PERL 5.002 #
######################
require 5.002;

#################
# USE LIBRARIES #
#################
use Socket;
use POSIX ":sys_wait_h";

sub REAPER {
  my $waitedpid;
  $waitedpid = wait;
  # loathe sysV: it makes us not only reinstate
  # the handler, but place it after the wait
  $SIG{CHLD} = \&REAPER;
}

sub INT_handler {
    print("\nU:Sparta: caught SIGINT, dying\n");
    snd(":$uuid QUIT :Ack! SIGINT!!");
    sleep 1;
    &Cleanup;
    exit;
}

sub ALARM_handler {
  #if (time() - $lastmsgtime > 240) {
  #  snd("QUIT :Hmm, I seem to have timed out");
  #  sleep 2;
  #  &Cleanup;
  #  exit;
  #}

  #ugh, only way i can think of. i hate fork() and such, there isn't any decent documentation
  #all i wanna do is run a program and have it say "done" somehow to parent when its done.

  if ($chanstats_running) {
    &checkchanstats;
    alarm (2);
  } else {
    alarm (30);
  }
}

sub KILL_handler {
    print("\nU:Sparta: caught SIGKILL, dying\n");
	snd(":$uuid PRIVMSG $ctrl :Caught a SIGKILL");
    snd(":$uuid QUIT :Caught a SIGKILL");
    sleep 1;
    &Cleanup;
    exit;
}

sub HUP_handler {
  print "U:Sparta: Caught a SIGHUP, becoming a semi daemon.\n";
  snd (":$uuid PRIVMSG $ctrl :Caught a SIGHUP, becoming a semi daemon.");
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDERR, '>&STDOUT'	or die "Can't dup stdout: $!";
}

sub PWR_handler {
  snd (":$uuid QUIT :Hmm, my UPS claims the power is failing. I'm gonna go hide.");
  open (NOSPAWN, ">${win321}nospawn");
  print NOSPAWN "powerfail";
  close (NOSPAWN);
  sleep 1;
  &Cleanup;
  exit;
}

$SIG{PWR} = \&PWR_handler;
$SIG{INT} = \&INT_handler;
$SIG{KILL} = \&KILL_handler;
$SIG{TERM} = \&KILL_handler;
$SIG{ALRM} = \&ALARM_handler;
$SIG{CHLD} = \&REAPER;
$SIG{HUP} = \&HUP_handler;

if (lc($^O) eq 'mswin32') {
  $win321 = '';
  $mfail = "[FAILED]";
  $mok =   "[  OK  ]";
} else {
  $win321 = './';
  $mfail = "[[31mFAILED[0m]";
  $mok =   "[  [32mOK[0m  ]";
}

##################################
# DO MY VARIABLES FOR MORE SPEED #
##################################
my ($remote, $port, $iaddr, $paddr, $proto, $line, $spoken, $bitchcmds, $newfacts);

#set up defaults (stops -w warning)

@swearwords = ();

$ctcp_reply = 1;
$noqq = 0;
$uploadname = "";
$uploadpath = "";
$uploaduser = "";
$uploadhost = "";
$uploadpass = "";
$uploadpasv = 0;
$outfile = "";
$outurl = "";
$notoys = 0;
$maxpolloptions = 6;
$maxpending = 5;
$key = "";
$allowstats = 1;
$enableshortcuts = 1;
$defaultmode = "";
$usermodemaster = "";
$autooper = 0;
$noeval = 1;
$opername = "";
$admin = "";
$botemail = "";
$novote = 0;
$nopoll = 0;
$noplayerlist = 1;

#for (lame) nick validation
$nickchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-[]\\`^{}";


###################################################
# FIND OUT WHETHER TO RUN A DIFFERENT CONFIG FILE #
###################################################
if (!defined($ARGV[0])) {
  @tmp = split(/[\/]|[\\]/,$0);
  $scriptname = $tmp[$#tmp];
  ($scriptname) = split(/\./,$scriptname);
  undef @tmp;
} else {
  $scriptname = $ARGV[0];
}

##################
# EXECUTE CONFIG #
##################
print "Executing config file... ";
do "$win321$scriptname.conf" or die " $mfail ($scriptname.conf -- $!)\n";
print " $mok ($botname from $scriptname.conf)\n";

#yuck.
@tmp = split(//, $botname);
foreach (@tmp) {
  if (index($nickchars,$_) == -1 ) {
    print "Illegal nickname ($botname): Can't contain a $_\n";
    exit;
  }
}
undef @tmp;

#anti idiot check
if (!defined($botname) || !defined($server) || !defined($serverport) || !defined(@channels)) {
  print "Try SETTING UP THE CONFIG before running the bot.\n";
  exit;
}

#yucky way of checking config migration
if (!defined($autoupdate)) {
  print "\nNOTICE: Your config appears to be out of date as it is missing at\nleast one default option. If you have just upgraded from a previous\nversion don't forget to check out the new bitch.conf.template\nfor new configuration options.\n\n";
  $autoupdate = 1;
}

############################################
# VERSION FOR AUTO UPDATE -- DO NOT MODIFY #
############################################
$bot_version_number = "chii 0.1";

#removed until people stop being idiots
if ($autoupdate == 1) {
  if (checkupdate() == 2) {
    print "$mfail\nAn error occured accessing the update server.\nMaybe this is because you are behind a firewall or proxy\nor are not currently connected to the Internet.\n\n";
  }
}

######################
# INITIALISE MODULES #
######################
$notime = 0;
$lastmsgtime = time();

print "Trying Time::HiRes...    ";
if (eval "use Time::HiRes", $@) {$notime = 1;}
if ($notime == 1) {
  print " $mfail (module not compatible/installed on this platform)\n";
} else {
  print " $mok (hi-resolution ping times enabled)\n";
}


print "Trying to set alarm...   ";
if (eval "alarm (30)", $@) {$noalarm = 1;}
if (defined($noalarm)) {
  print " $mfail (not applicable for this OS)\n";
} else {
  print " $mok (will detect timeout)\n";
}

$| = 1;

################
# GET LIFETIME #
################
if (open (TIMES,"$scriptname.time")) {
  $allstartlifetime = <TIMES>;
  chomp ($allstartlifetime);
  close (TIMES);
} else {
  $allstartlifetime = 0;
}

# load test plugin thing. :P
#print "Loading testplugin.pl";
#do "${win321}testplugin.pl" or die " $mfail ($!)\n";
#print " $mok (Plugin loaded)";
#eval "command_testtest();";

print "Loading modules...\n";
foreach $module(@modules) {
	print "${win321}modules/$module.pl";
	do "${win321}modules/$module.pl" ;
	if(($! or $@) ne "") {
		print " $mfail ($!)";
		die;
	} else {
		print " $mok\n";
	}
}

###################
# INITIALISE VARS #
###################
$usermodemaster = " ADDFACTS DELFACTS DELALLFACTS SERVERMANIP STATIC ADMIN OP AV AO NULL SUPERADMIN STAFF SERVEROP GLOBAL ";

@usermodes = split(" ",$usermodemaster);

$bitchcmds = 0;
$newfacts = 0;
$spoken = 0;

@msg = ();
@checkaccess = ();
@owners = ();
@facts = ();
@objects = ();
@splitters = ();
@factoidmsg = ();
%nicklist = ();

%deltimer = ();
%seen = ();
%access = ();
%servers = ();
%ignore = ();
%profiles = ();
%ts = ();

$optimeout = time() - 5;
$factoiddelay = time() - 20;

$startlifetime = time();

$timezone .= ' ';

srand;

#################
# OPEN LOGFILES #
#################
open (BITCHLOG, ">>$win321$scriptname.log") or die "$mfail can't output to logfile: $!\n";
open (CHATLOG, ">>$logfile") or die "$mfail can't output to logfile: $!\n";

###############
# create data #
###############
if (!-e "$win321$datadir") {
  mkdir ("$win321$datadir",0755) or die "$mfail Couldn't create data directory: $!\n";
}

###############
# load access #
###############
#dbmopen (%access,"$win321$datadir/access",0755) || die "Unable to open $datadir/access: $!\n";
#dbmopen (%servers,"$win321$datadir/servers",0755) || die "Unable to open $datadir/servers: $!\n";
#dbmopen (%ignore,"$win321$datadir/ignores",0755) || die "Unable to open $datadir/ignores: $!\n";
#dbmopen (%seen,"$win321$datadir/seen",0755) || die "Unable to open $datadir/seen: $!\n";
#dbmopen (%profiles,"$win321$datadir/profiles",0755) || die "Unable to open $datadir/profiles: $!\n";
#dbmopen (%hosts,"$win321$datadir/hosts",0755) || die "Unable to open $datadir/hosts: $!\n";

#DBM sucks. period. ndbm is pathetic. i wiped the entire set by using | as a key. gah.
#so i created my own style DBM thingie hash loading or something...
if (-e "$win321$datadir/access.dat") {
  open (DBMHACK,"$win321$datadir/access.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  for(@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $access{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/servers.dat") {
  open (DBMHACK,"$win321$datadir/servers.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $servers{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/ignore.dat") {
  open (DBMHACK,"$win321$datadir/ignore.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $ignore{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/seen.dat") {
  open (DBMHACK,"$win321$datadir/seen.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key) = split(/\001/,$_);
    $seen{$key} = substr($_, index($_,"\001")+1);
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/profiles.dat") {
  open (DBMHACK,"$win321$datadir/profiles.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $profiles{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/hosts.dat") {
  open (DBMHACK,"$win321$datadir/hosts.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $hosts{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";
}

if (-e "$win321$datadir/ts.dat") {
  open (DBMHACK,"$win321$datadir/ts.dat") or die "$mfail Broken DBM: $!\n";
  @tmp=<DBMHACK>;
  foreach $_ (@tmp){
    chomp;
    ($key,$value) = split(/\001/,$_);
    $profiles{$key} = $value;
  }
  close (DBMHACK) or die "$mfail Cannot close DBM: $!\n";

####################
# LOAD STATS TIMER #
####################
if (open (ST,"$win321$datadir/stats.time")) {
  $stattime = <ST>;
  close (ST);
} else {
  $stattime = 0;
}

###############
#Load Factoids#
###############

print "Loading factoids...";

if (-e "$win321$datadir/msg1.dat") {
  open (MSGSFILE,"$win321$datadir/msg1.dat") or die "$mfail Unable to open $win321$datadir/msg1.dat :$!\n";
  @msg=<MSGSFILE>;
  for(@msg){chomp;}
  close (MSGSFILE) or die "$mfail Cannot close msgs: $!\n";
}

if (-e "$win321$datadir/kicks.dat") {
  open (KICKSFILE,"$win321$datadir/kicks.dat") or die "$mfail Unable to open $win321$datadir/kicks.dat :$!\n";
  @kicks=<KICKSFILE>;
  for(@kicks){chomp;}
  close (KICKSFILE) or die "$mfail Cannot close kicks: $!\n";
}

if (-e "$win321$datadir/facts.dat") { 
  open (FACTSFILE,"$win321$datadir/facts.dat") or die "$mfail Unable to open $win321$datadir/facts.dat :$!\n";
  @facts=<FACTSFILE>;
  for(@facts){chomp;}
  close (FACTSFILE) or die "$mfail Cannot close facts: $!\n";
}

if (-e "$win321$datadir/denies.dat") { 
  open (FACTSFILE,"$win321$datadir/denies.dat") or die "$mfail Unable to open $win321$datadir/denies.dat :$!\n";
  @deny=<FACTSFILE>;
  for(@deny){chomp;}
  close (FACTSFILE) or die "$mfail Cannot close denies: $!\n";
}


if (-e "$win321$datadir/objects.dat") { 
  open (OBJECTSFILE,"$win321$datadir/objects.dat") or die "$mfail Unable to open $win321$datadir/objects.dat :$!\n";
  @objects=<OBJECTSFILE>;
  for(@objects){chomp;}
  close (OBJECTSFILE) or die "$mfail Cannot close objects: $!\n";
}


if (-e "$win321$datadir/owners.dat") {
  open (OWNERSFILE,"$win321$datadir/owners.dat") or die "$mfail Unable to open $win321$datadir/owners.dat :$!\n";
  @owners=<OWNERSFILE>;
  for(@owners){chomp;}
  close (OWNERSFILE) or die "$mfail Cannot close owners: $!\n";
}

if (-e "$win321$datadir/splitters.dat") {
  open (SPLITTERSFILE,"$win321$datadir/splitters.dat") or die "$mfail Unable to open $win321$datadir/splitters.dat :$!\n";
  @splitters=<SPLITTERSFILE>;
  for(@splitters){chomp;}
  close (SPLITTERSFILE) or die "$mfail Cannot close splitters: $!\n";
}

  print "       $mok (loaded " . ($#facts+1) ." factoids (" . ($#deny+1) . " denied))\n";

#print "There are " . ($#facts+1) . " factoids loaded, " . ($#msg+1) . " messages queued, " . ($#kicks+1) . " kick msgs loaded, " . ($#deny+1) . " factoids denied.\n";

#####################
# CONNECT TO SERVER #
#####################
print "Connecting to server...   ";
$remote = $server;
$port = $serverport;
$pass = $serverpass;
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr = inet_aton($remote) or die "$mfail (invalid host: $remote)\n";
$paddr = sockaddr_in($port,$iaddr);
$proto = getprotobyname('tcp');
socket (SOCK,PF_INET,SOCK_STREAM,$proto) or die "$mfail (socket error: $!)\n";
connect (SOCK, $paddr) or die "$mfail (connect error: $!)\n";
print "$mok (connected to ${server}:${serverport})\n";

$nl = chr(13);
$nl = $nl . chr(10);

$nicklist{lc($botname)} = '';

$lastpong = time();
$msgto = $channel;

snd ("SERVER $servname $sendpass 0 $sid :$servgecos");

snd ("BURST");

snd (":$sid VERSION :$servgecos");
snd (":$sid UID $uuid 1 $nick $host $vhost $ident $clientip 1 $umodes :$clientgecos");
#snd (":$sid UID 666AAAAAB 1 NickServ services. this.is.NICKSERV NickServ 0.0.0.0 1 +Iik :Nickname Services");
snd (":$uuid OPERTYPE $opertype");
#snd (":666AAAAAB OPERTYPE Services");
snd ("PRIVMSG $ctrl :Connected to $server");
  foreach $channeltojoin(@channels) {
	$time = time;
  	snd(":$sid FJOIN $channeltojoin $time + :ao,$uuid");
        snd(":$sid FMODE $channeltojoin 1 +ao $botname $botname");
        snd(":$sid PRIVMSG $ctrl :Channel $channeltojoin joined.");
  	snd(":$sid FJOIN $ctrl $time + :ao,$uuid");
        snd(":$sid FMODE $ctrl 1 +ao $botname $botname");
	  snd(":$sid FJOIN $output $time + :ao,$uuid");
        snd(":$sid FMODE $output 1 +ao $botname $botname");
	snd ("ENDBURST");
	#snd("MODE $botname $connectmodes");
  }
#snd (":$sid FJOIN $ctrl ".time." + ,$uuid");
#snd (":$sid FMODE $ctrl 1 +ao $uuid $uuid");
sleep 2;
snd (":$sid METADATA $uuid accountname $botname");
for ($count = 9; $count >= 1; $count--) {
snd (":$sid UID $sid"."AAAAA".$count." 1 $antibotnick"."_0".$count." $host $vhost $ident $clientip 1 $umodes :$clientgecos");
}
snd (":$sid UID $sid"."AAAABA 1 $antibotnick"."_10 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
for ($count = 9; $count >= 1; $count--) {
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAA".$count);
}
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAABA");
#------------------------------------------------------------
for ($count = 9; $count >= 1; $count--) {
snd (":$sid UID $sid"."AAAAB".$count." 1 $antibotnick"."_".($count + 10)." $host $vhost $ident $clientip 1 $umodes :$clientgecos");
}
snd (":$sid UID $sid"."AAAACA 1 $antibotnick"."_20 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
for ($count = 9; $count >= 1; $count--) {
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAB".$count);
}
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAACA");
#----------------------------------------------------------------
for ($count = 9; $count >= 1; $count--) {
snd (":$sid UID $sid"."AAAAC".$count." 1 $antibotnick"."_".($count + 20)." $host $vhost $ident $clientip 1 $umodes :$clientgecos");
}
snd (":$sid UID $sid"."AAAADA 1 $antibotnick"."_30 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
for ($count = 9; $count >= 1; $count--) {
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAC".$count);
}
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAADA");
#--------------------------------------------------------------------
for ($count = 9; $count >= 1; $count--) {
snd (":$sid UID $sid"."AAAAD".$count." 1 $antibotnick"."_".($count + 30)." $host $vhost $ident $clientip 1 $umodes :$clientgecos");
}
snd (":$sid UID $sid"."AAAAEA 1 $antibotnick"."_40 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
for ($count = 9; $count >= 1; $count--) {
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAD".$count);
}
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAEA");
#--------------------------------------------------------------------
snd (":$sid UID $sid"."AAAAEB 1 $antibotnick"."_41 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
snd (":$sid UID $sid"."AAAAEC 1 $antibotnick"."_42 $host $vhost $ident $clientip 1 $umodes :$clientgecos");
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAEB");
snd (":$sid FJOIN $antibot ".time." + :,$sid"."AAAAEC");





######################
#####################
####################
#START OF SOCKET READ LOOP
####################
#####################
######################


STARTOFLOOP: while ($line = <SOCK>) {
$lastmsgtime = time();
$line =~ s/\027-\036\004-\025\376\377//gi;

$silent = 0;  
$usermode = "";
undef $nickname;
undef $command;
undef $mtext;
undef $hostmask;

################
# EXTRACT VARS #
################
$hostmask = substr($line,index($line,":"));
$mtext = substr($line,index($line,":",index($line,":")+1)+1);
($hostmask, $command) = split(" ",substr($line,index($line,":")+1));
($nickname) = split("!",$hostmask);

@spacesplit = split(" ",$line);
$channel = $spacesplit[2];
$mtext =~ s/[\r|\n]//g;

if ((uc($command) eq "PRIVMSG" || uc($command) eq "KICK") && lc($msgto) eq lc($channel) && !($chanstats_running)) {
  $action = 0;

  if (uc($command) eq "KICK") {
    $kicknick = $spacesplit[3];
    if ($mtext eq '') {
      $mtext = $nickname;
    }
    logline (4, $nickname, "*** $kicknick was kicked from $channel by $nickname ($mtext)");
    logline (5, $kicknick, "*** $kicknick was kicked from $channel by $nickname ($mtext)");
  } else {
    if ($mtext =~ /^\001ACTION .+\001$/) {
      logline (1, $nickname, $mtext);
    } elsif ($mtext =~ /^\Q$botname\E($botanswer)/i || ($mtext =~ /\?\?$/ && $noqq == 0)) {
      logline (2, $nickname, $mtext);
    } elsif ($mtext =~ /\?$/) {
      logline (3, $nickname, $mtext);
    } else {
      logline (0, $nickname, $mtext);
    }
  }
}

#if (uc($command) eq "KICK") {
    #if($spacesplit[3] eq $botname) {
    	#snd("JOIN $channel $key");
    #}
#} elsif(uc($command) eq "PART") {
  	#$lenofbotnick = length($botname);
	#$partednick = substr($spacesplit[0], 1, $lenofbotnick);
	#if($partednick eq $botname) {
		#if($spacesplit[3] eq ":requested") {
			#snd("JOIN $channel $key");
		#}
	#}
#}

if ($mtext =~ /^\001.+\001$/) {
  $ctcp_hax = 1;
} else {
  $ctcp_hax = 0;
}

$line =~ s/\001//g;
$mtext =~ s/\001//g;

if ( ( uc($command) eq "PRIVMSG") || (uc($command) eq "NOTICE")) {
  $msgto = $spacesplit[2];
  if (lc($msgto) eq lc($botname)) {
    $msgto = $nickname;
  }
} else {
    $msgto = $channel;
}

if ($noalarm && $chanstats_running) {
  &checkchanstats;
}

if ($command eq '001') {
  &NickServ;
}

if (uc($command) eq 'TOPIC' || uc($command) eq 'KICK') {
  next;
}

if (uc($command) eq 'MODE') {
  %nicklist = ();
  #snd ("NAMES $channel");
}

if ($command eq "332") {
	if($topiccommand eq 1) {
		snd(":$uuid PRIVMSG $topicchan :$topicnick, the topic for $topicchan is \"$mtext\"");
		$topiccommand = 0;
	}
}

if($mtext eq "$botname!") {
	sndtxt("$nick{$nickname}!");
	#sndtxt("$nickname!");
	next;
}

foreach $badword(@badwords) {
	if($mtext =~ /$badword/i) {
	if($nick{$nickname} eq 'Marlen_Jackson') { } else {
		#:<sid or uuid> ADDLINE <linetype> <mask> <setter> <time set> <duration> :<reason>
		snd(":$uuid PRIVMSG $nickname :Please refrain from violating the SpartaIRC rules and regulations, thank you!");
		snd(":$sid ADDLINE Z $ip{$nickname} $botname ".time." 86400 :Banned hostname [chii]");
	}
	}
	next;
}

#if($mtext =~ /.*ElectricIRC.*/i) {
	#snd(":$uuid KILL $nickname :Nick collision from services.");
	#next;
#}

#if($mtext =~ /.*Fuck.*SpartaIRC.*/i) {
	#snd(":$uuid SVSMODE $channel +b m:$nunnick{$nickname}");
	#snd(":$uuid PRIVMSG $nickname :Please refrain from violating the SpartaIRC rules and regulations, thank you!");
	#next;
#}
#if($mtext =~ /.*The.*Game/i) {
	#snd(":$uuid PRIVMSG $channel :\001ACTION just lost the game\001");
	#next;
#}
#if($mtext =~ /.*Nein.*/i) {
	#snd(":$uuid KICK $channel $nickname :JA!");
	#next;
#}
###########################################
# Check for someone connecting, then ctcp version who's connecting...and other random stuff
############################################
#if($channel eq "#services") {
if($channel eq "$servicechan") {
	# check if the sender is the server...
	if(($nickname =~ /jcs\.me\.uk/) || ($nickname =~ /spartairc\.co\.cc/)) {
		# check if the line starts with "CONNECT: Client connecting on port 6667: "
		#print "substr: ".substr($mtext, 0, 21)."\n";
		if(substr($mtext, 0, 43) eq "\002CONNECT\002: Client connecting on port 6667: ") {
			@lolarray = split(/!/, $mtext);
			#print join(" | ", @lolarray);
			$connectednick = substr($lolarray[0], 43);
			# check if it's a glined nick
			foreach $badnick(@autoglinenick) {
				if($connectednick eq $badnick) {
					snd("GLINE $connectednick 1y :Banned nickname.  Disallowed by $botname");
					next;
				}
			}
			snd(":$uuid3 PRIVMSG $connectednick :\001VERSION\001");
			$pendingversion{$connectednick} = "$servicechan";
                        #if $pendingversion{$connectednick} = / mibbit / 
		} elsif(substr($mtext, 0, 22) eq "CHANCREATE: Channel ") {
			@lolarray3 = split(/ /, $mtext);
			print join(" | ", @lolarray3);
			$createdchannel = $lolarray3[2];
			$chcreatehost = $lolarray3[5];
			@chcreatenicka = split(/!/, $chcreatehost);
			$chcreatenick = $chcreatenicka[0];
			if($chcreatenick eq $adminnick) {
				#snd("JOIN $createdchannel");
				snd(":$uuid MODE $createdchannel +qa $adminnick $adminnick");
				#snd("PART $createdchannel");
			}
		}
	}
}

#---------------------



	#@blah = split(/ /, $line);
	#chop $blah[3];
	#chop $blah[3];
	#snd(":$sid PONG ".$blah[3]." ".$blah[2]);
	#:42A UID 42AAACW9Z 1263079186 Lugburz 67.160.120.196 67.160.120.196 ~chatzilla 67.160.120.196 1263079191 + :New Now Know How
	#$query = "one thing ` another thing"; @blar = split(/ ` /, $query); @blah = split(/ /, $blar[0]); sndtxt($blah[0]." ".$blah[1]);
if (uc($command) eq 'BURST') {
	$burst = '1';
	next;
}
if (uc($command) eq 'ENDBURST') {
	$burst = '0';
	next;
}
 
if (uc($command) eq 'ADMIN') {
foreach $mod (@testmods) {
	if( defined &Modules::.$mod.::admin ) { &Modules::.$mod.::admin; }
	else { }
	next;
	}
}

if (uc($command) eq 'MOTD') {
foreach $mod (@testmods) {
	if( defined &Modules::.$mod.::motd ) { &Modules::.$mod.::motd; }
	else { }
	next;
	}
}

if (uc($command) eq 'UID') {
	use Net::DNS;
	$qwerty = substr($line,1);
	@connection = split(/ :/i, $qwerty);
	@connect = split(/ /, $connection[0]);
	chop $connection[1];
	chop $connection[1];
	$client{$connect[2]} = "$connect[4]!$connect[7]\@$connect[6]";
	$nunnick{$connect[2]} = "*!$connect[7]\@$connect[6]";
	$real{$connect[2]} = "$connect[4]!$connect[7]\@$connect[8]";
	$ip{$connect[2]} = "$connect[8]";
	$ident{$connect[2]} = "$connect[7]";
	$host{$connect[2]} = "$connect[5]";
	$vhost{$connect[2]} = "$connect[6]";
	$nick{$connect[2]} = "$connect[4]";
	$gecos{$connect[2]} = "$connection[1]";
	if ($burst eq '0') {
#if ( ($host{$nickname} eq 'webirc.int') || ($vhost{$nickname} =~ /^gateway\/.*?/) || ($ip{$nickname} eq '64.62.228.82') || ($ip{$nickname} eq '207.192.75.252') || ($ip{$nickname} eq '192.168.1.203') ) {
if ($host{$nickname} eq 'webirc.int') {
use Socket;
$ipc = inet_ntoa( pack( "N", hex( $ident{$connect[2]} ) ) );
	@revip = split(/\./, $ipc); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."dnsbl.dronebl.org");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $ctrl :\002CONNECT:\002 $connect[4] has connected from $connect[5] (Real IP: $ipc). $connect[4] has a timestamp of $connect[3], a UUID of $connect[2], and is using modes $connect[10].  $connect[4] has a hostmask of $connect[4]!$connect[7]\@$connect[6] : $connection[1]");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ipc, which is \002on\002 the DroneBL blacklist.");
    snd(":$uuid KILL $connect[2] :You have a host listed in the DroneBL. For more information, visit http://dronebl.org/lookup_branded.do?ip=".$ipc."&network=SpartaIRC");
	  }
  } else {
	  snd(":$uuid PRIVMSG $ctrl :\002CONNECT:\002 $connect[4] has connected from $connect[5] (Real IP: $ipc). $connect[4] has a timestamp of $connect[3], a UUID of $connect[2], and is using modes $connect[10].  $connect[4] has a hostmask of $connect[4]!$connect[7]\@$connect[6] : $connection[1]");
	  snd (":$uuid PRIVMSG $ctrl :$connect[4] is not on the DroneBL blacklist.");
      #sndtxt("query failed: ".$res->errorstring);
		}
	}
elsif ( ($host{$nickname} ne 'webirc.int') || ($vhost{$nickname} !~ /^gateway\/.*?/) || ($ip{$nickname} ne '64.62.228.82') || ($ip{$nickname} ne '207.192.75.252') ) {
	@revip = split(/\./, $ip{$connect[2]}); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."dnsbl.dronebl.org");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ip{$connect[2]}, which is \002on\002 the DroneBL blacklist.");
    snd(":$uuid KILL $connect[2] :You have a host listed in the DroneBL. For more information, visit http://dronebl.org/lookup_branded.do?ip=".$ip{$connect[2]}."&network=SpartaIRC");
  
	  }
  } else {
	  snd (":$uuid PRIVMSG $ctrl :$connect[4] is not on the DroneBL blacklist.");
      #sndtxt("query failed: ".$res->errorstring);
		}
snd(":$uuid PRIVMSG $ctrl :\002CONNECT:\002 $connect[4] has connected from $connect[5] (IP $connect[8]). $connect[4] has a timestamp of $connect[3], a UUID of $connect[2], and is using modes $connect[10].  $connect[4] has a hostmask of $connect[4]!$connect[7]\@$connect[6] : $connection[1]");
	}
}

	elsif ($burst eq '1') {
if ( ($host{$nickname} eq 'webirc.int') || ($vhost{$nickname} =~ /^gateway\/.*?/) || ($ip{$nickname} eq '64.62.228.82') || ($ip{$nickname} eq '207.192.75.252') ) {
use Socket;
$ipc = inet_ntoa( pack( "N", hex( $ident{$connect[2]} ) ) );
	@revip = split(/\./, $ipc); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."dnsbl.dronebl.org");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ipc, which is \002on\002 the DroneBL blacklist.");
         snd(":$uuid KILL $connect[2] :You have a host listed in the DroneBL. For more information, visit http://dronebl.org/lookup_branded.do?ip=".$ipc."&network=SpartaIRC");

	  }
  } else {
	  snd (":$uuid PRIVMSG $ctrl :$connect[4] is not on the DroneBL blacklist.");
      #sndtxt("query failed: ".$res->errorstring);
		}
snd(":$uuid PRIVMSG $ctrl :\002CONNECT:\002 $connect[4] has connected from $connect[5] (Real IP: $ipc). $connect[4] has a timestamp of $connect[3], a UUID of $connect[2], and is using modes $connect[10].  $connect[4] has a hostmask of $connect[4]!$connect[7]\@$connect[6] : $connection[1]");
	}
elsif ( ($host{$nickname} ne 'webirc.int') || ($vhost{$nickname} !~ /^gateway\/.*?/) || ($ip{$nickname} ne '64.62.228.82') || ($ip{$nickname} ne '207.192.75.252') ) {
snd(":$uuid PRIVMSG $adminnick :\002CONNECT:\002 $connect[4] has connected from $connect[5] (IP $connect[8]). $connect[4] has a timestamp of $connect[3], a UUID of $connect[2], and is using modes $connect[10].  $connect[4] has a hostmask of $connect[4]!$connect[7]\@$connect[6] : $connection[1]");
	}
}
#----------------------------------------------------------------------------





#----------------------------------------------------------------------------
	if ($burst eq '0') {
#if ( ($host{$nickname} eq 'webirc.int') || ($vhost{$nickname} =~ /^gateway\/.*?/) || ($ip{$nickname} eq '64.62.228.82') || ($ip{$nickname} eq '207.192.75.252') || ($ip{$nickname} eq '192.168.1.203') ) {
if ($host{$nickname} eq 'webirc.int') {
use Socket;
$ipc = inet_ntoa( pack( "N", hex( $ident{$connect[2]} ) ) );
	@revip = split(/\./, $ipc); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."tor.dnsbl.sectoor.de");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ipc, which is a \002confirmed\002 Tor exit node.");
    snd(":$uuid KILL $connect[2] :Tor exit server detected. Please visit http://www.sectoor.de/tor.php?ip=".$ipc."&network=SpartaIRC for more information.");

	  }
  } else {	}
	}
elsif ( ($host{$nickname} ne 'webirc.int') || ($vhost{$nickname} !~ /^gateway\/.*?/) || ($ip{$nickname} ne '64.62.228.82') || ($ip{$nickname} ne '207.192.75.252') ) {
	@revip = split(/\./, $ip{$connect[2]}); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."tor.dnsbl.sectoor.de");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ip{$connect[2]}, which is a \002confirmed\002 Tor exit node.");
    snd(":$uuid KILL $connect[2] :Tor exit server detected. Please visit http://www.sectoor.de/tor.php?ip=".$ip{$connect[2]}."&network=SpartaIRC for more information.");

	  }
  } else {
	  snd (":$uuid PRIVMSG $ctrl :$connect[4] is not connecting via a Tor exit node.");
	}
}
#----------------------------------------------------------------------------





#----------------------------------------------------------------------------
	if ($burst eq '0') {
if ( ($host{$nickname} eq 'webirc.int') || ($vhost{$nickname} =~ /^gateway\/.*?/) || ($ip{$nickname} eq '64.62.228.82') || ($ip{$nickname} eq '207.192.75.252') || ($ip{$nickname} eq '192.168.1.203') ) {
#if ($host{$nickname} eq 'webirc.int') {
use Socket;
$ipc = inet_ntoa( pack( "N", hex( $ident{$connect[2]} ) ) );
	@revip = split(/\./, $ipc); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."rbl.efnet.org");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ipc, which is \002on\002 the EfNet RBL blacklist.");
    snd(":$uuid KILL $connect[2] :You have a host listed in the EfNet RBL. For more information, visit http://rbl.efnetrbl.org/?i=".$ipc);

      }
  } else {	}
	}
elsif ( ($host{$nickname} ne 'webirc.int') || ($vhost{$nickname} !~ /^gateway\/.*?/) || ($ip{$nickname} ne '64.62.228.82') || ($ip{$nickname} ne '207.192.75.252') ) {
	@revip = split(/\./, $ip{$connect[2]}); 
		$tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
		my $res   = Net::DNS::Resolver->new;
		my $query = $res->search("$tofind."."rbl.efnet.org");
		 if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
	snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: $connect[4] has connected from IP $ip{$connect[2]}, which is \002on\002 the EfNet RBL blacklist.");
       snd(":$uuid KILL $connect[2] :You have a host listed in the EfNet RBL. For more information, visit http://rbl.efnetrbl.org/?i=".$ip{$connect[2]});

	  }
  } else {
	  snd (":$uuid PRIVMSG $ctrl :$connect[4] is not on the EfNet RBL blacklist.");
	}
}

}
}
}
if (uc($command) eq 'UID') {
	$query = substr($line,1);
	@connection = split(/ :/i, $query);
	@connect = split(/ /, $connection[0]);
	chop $connection[1];
	chop $connection[1];
	$client{$connect[2]} = "$connect[4]!$connect[7]\@$connect[6]";
	$real{$connect[2]} = "$connect[4]!$connect[7]\@$connect[8]";
	$ip{$connect[2]} = "$connect[8]";
	$ident{$connect[2]} = "$connect[7]";
	$host{$connect[2]} = "$connect[5]";
	$vhost{$connect[2]} = "$connect[6]";
	$nick{$connect[2]} = "$connect[4]";
	$gecos{$connect[2]} = "$connection[1]";
	$uuid{$connect[2]} = "$connect[2]";
	$nickuuid{$nick{$connect[2]}} = "$connect[2]";
	$ts{$connect[2]} = "$connect[3]";
	next;
}
#:134AAAGVJ NICK Internet 1263440920

if (uc($command) eq 'NICK') {
	$query = substr($line,1);
	@omgnick = split (/ /, $query);
	chop $omgnick[3];
	chop $omgnick[3];
	@goodnick = ("1", "2", "3", "4", "5", "6", "7", "8", "9", "10");
	if ($omgnick[2] =~ /Serv/) {
			if (($nick{$omgnick[2]} eq 'StatServ') || ($nick{$omgnick[2]} eq 'NickServ') || ($nick{$omgnick[2]} eq 'ChanServ') || ($nick{$omgnick[2]} eq 'GameServ') || ($nick{$omgnick[2]} eq 'BotServ') || ($nick{$omgnick[2]} eq 'OperServ') || ($nick{$omgnick[2]} eq 'LoveServ') || ($nick{$omgnick[2]} eq 'ScrapServ') ) {
				snd(":$uuid PRIVMSG $ctrl :$omgnick[2] is an approved SpartaIRC Service");
			} else {
		foreach $goodnick(@goodnick) {
		$rand = int(rand(9999));
		snd(":$sid SVSNICK $omgnick[0] Guest$rand $ts{$omgnick[0]}");
		#snd(":$sid CHGHOST $omgnick[2] chii.test");
		snd(":$uuid PRIVMSG $ctrl :$omgnick[2] is not a SpartaIRC Service.  Nickname change has been forced.");
		next;
		}
			}
		}
	}
	
#42A UID 42AAACW9Z 1263079186 Lugburz 67.160.120.196 67.160.120.196 ~chatzilla 67.160.120.196 1263079191 + :New Now Know How
#if (uc($command) eq 'UID') {
	#$connection = $line;
	#chop $connection;
	#chop $connection;
	#snd(":$uuid PRIVMSG $output :\002CONNECT:\002 $connection");
	##snd(":$sid PRIVMSG $output :\002CONNECT:\002 $text");
	#next;
#}
#134AAAAC3 ADDLINE Z blah thanatos.spartairc.co.cc 1262925162 1 :testing
#if (uc($command) eq 'ADDLINE') {
	#$ban = substr($line,18);
	#if ($ban =~ /^Z /i) {
		#snd (":$uuid PRIVMSG $ctrl :\002\003" . "4WARNING\003\002: New Z:Line recieved.");
		#next;
 #}
#}
#if (uc($command) eq 'KILL') {
#$killtime = localtime;
#$killepoch = time;
#$gmtkill = gmtime;
#use Mail::Mailer;
	#$from_address = "abuse\@spartairc\.co\.cc";
	#$to_address = "root\@spartairc\.co\.cc";
	#$subject = "KILL send.  Possible abuse.";
	#$body = "At $killtime, a KILL was sent.  Kill message was $text.  Epoch time was $killepoch and Greenwich mean time was $gmtkill.";
	#$mailer = Mail::Mailer->new();
	#$mailer->open({ From    => $from_address,
					#To      => $to_address,
					#Subject => $subject,
				  #})
		#or die "Can't open: $!\n";
	#print $mailer $body;
	#$mailer->close();
	#snd (":$uuid PRIVMSG $ctrl :\002\003" . "4WARNING\003\002: Possible abuse located. Action taken.");
	#next;
#}


if (uc($command) eq 'FJOIN') {
	if ($line =~ / $antibot /) {
		$uuid2pm = substr($line, -11);
		chop $uuid2pm;
		chop $uuid2pm;
		snd(":$sid FJOIN $antibot ".time." + :,$uuid");
		snd(":$uuid SVSMODE $antibot +aoq $uuid $uuid $uuid");
		snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: Join to $antibot by $real{$uuid2pm}. Possible spambot.");
		snd(":$uuid FTOPIC $antibot ".time." $botname :You have joined $antibot. Speaking in this channel will cause you to be SHUN'd. Please /part now.  If you talk and get SHUN'd, staff won't help you. Thanks for flying $netname! =)");
		snd(":$uuid PRIVMSG $antibot :You have joined $antibot. Speaking in this channel will cause you to be SHUN'd. Please /part now.  Thanks for flying $netname!");
		snd(":$uuid NOTICE $uuid2pm :You have joined $antibot. Speaking in this channel will cause you to be SHUN'd. Please /part now.  Thanks for flying $netname!");
		snd(":$uuid PRIVMSG $uuid2pm :You have joined $antibot. Speaking in this channel will cause you to be SHUN'd. Please /part now.  Thanks for flying $netname!");
	next;
 }
}
if (uc($command) eq 'PRIVMSG') {
	if ($line =~ / $antibot /) {
	$chan2talk = substr($line,19);
	if ($chan2talk =~ /^$antibot /) {
		#if ( (uc($command) eq "QUIT") || (uc($command) eq "PART")) 
		if ( ($host{$nickname} eq 'webirc.int') || ($vhost{$nickname} =~ /^gateway\/.*?/) || ($ip{$nickname} eq '64.62.228.82') || ($ip{$nickname} eq '207.192.75.252') ) {
			snd(":$uuid ADDLINE SHUN *!$ident{$nickname}\@* $botname ".time." 1800 :Possible botnet [$botname]");
		snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: Possible webchat spam detected.  SHUN added for hostmask *!$ident{$nickname}\@*.");
		}
		elsif ( ($host{$nickname} ne 'webirc.int') || ($vhost{$nickname} !~ /^gateway\/.*?/) || ($ip{$nickname} ne '64.62.228.82') || ($ip{$nickname} ne '207.192.75.252') ) {
		snd(":$uuid ADDLINE Z $ip{$nickname} $botname ".time." 1800 :Possible botnet [$botname]");
		snd(":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: Possible botnet detected.  SHUN added for hostmask *!*\@$ip{$nickname}.");
			}
		}
	}
}
#if ($line =~ /:[0-9][A-Z0-9][A-Z0-9] UID [0-9][A-Z0-9][A-Z0-9] [0-9]* .*?Darkedge .*? \+.*? :.* /) {
#	snd (":$uuid PRIVMSG $staffchan :\002\003" . "4WARNING\003\002: User Darkedge has been connected.");
#	snd(":$uuid NOTICE $adminnick :\002CONNECT:\002 Darkedge.  Staffers have been warned.");
#}
#if ($text =~ / Darkedge /i) {
#	snd(":$uuid PRIVMSG $ctrl :Ohai Darkedge! =DD");
#	next;
#}
####################
# IF CHANGING NICK #
####################
if (uc($command) eq 'NICK') {
  $nickname = $mtext;
  chomp($nickname);
  $nickname =~ s/[\r|\n]//g;
  $deltimer{lc($nickname)} = time()+60;
  #print "\$nickname = $nickname \n";
  #print "\$channel = $channel \n";
  foreach $badnick(@autoglinenicks) {
	  if($channel eq $badnick) {
		  snd("GLINE $channel 1y :Banned nickname. Disallowed by $botname");
	  }
	  next;
  }
  
  if($nickname eq $usertoecho) {
	  $usertoecho = $channel;
  		next;
	}
}

#####################
# MAINTAIN NICKLIST #
#####################
if ($command eq "353") {
  local @nicks = ();
  @nicks = split(/ /,$mtext);

  foreach $nnick (@nicks) {
    if (index($nnick,'+') != -1) {
      $nnick =~ s/\+//;
      $nicklist{lc($nnick)} = '+';
    }
    if (index($nnick,'@') != -1) {
      $nnick =~ s/\@//;
      $nicklist{lc($nnick)} = '@';
    }
  }
}

#if (($command eq 'QUIT') || ($command eq 'PART')) {
  #delete $nicklist{lc($nickname)};
#}

##################################
#Enter results from WHO into IAL
##################################
if ($command eq "352") {
#  if ($verbose eq "on") { print $line }
  $hosts{lc($spacesplit[7])} = $spacesplit[7] . "!" . $spacesplit[4] . "\@" . $spacesplit[5];
}

#######################################
#Add speaking/joining nick to host list
#######################################
$hosts{lc($nickname)} = $hostmask;

$usermode = $defaultmode;

if ($nickname =~ $admin) {
  $usermode = " ADDFACTS DELFACTS DELALLFACTS SERVERMANIP ADMIN OP AV AO SUPERADMIN STAFF SERVEROP GLOBAL ";
}
$staff = "pickles";
if ($hostmask =~ $staff) {
  $userlevel = 5;
}
$sudoer = "10328409328409324809324";
if ($hostmask =~ $sudoer) {
	$userlevel = 9001;
}
##############
# LOOKUP AXS #
##############
foreach $checkmode ( keys (%access )) {
  $levels = $access{$checkmode};
  $checkmode = lc($checkmode);
  if (lc($hostmask) =~ /$checkmode/) {
    $usermode = uc(" $levels ");
    last;
  }
}

############################
# KILL ADMIN IMPERSONATORS #
############################
if ($adminnickservpass ne '') {
  if ( ( lc($nickname) eq lc($adminnick)) && ($hostmask !~ $admin) ) {
    snd ("PRIVMSG NickServ :GHOST $adminnick $adminnickservpass");
    next;
  }
}

####################
# ADD TO SEEN HASH #
####################
$curdate = localtime();
$sendate = substr($curdate,11);
$sendate = substr($sendate,0,index($sendate," "));
$seen{lc($nickname)} = time() . "\001$sendate";


#####################
# IGNORE IF IGNORED #
#####################
#$iponly = lc(substr($hosts{lc($nickname)},index($hosts{lc($nickname)},"\@")+1));

foreach $testregex (keys %ignore) {
  if ($hosts{lc($nickname)} =~ /$testregex/i) {
    if (($ignore{$testregex} - time) <= 0) {
      delete $ignore{$testregex};
    } else {
      next STARTOFLOOP;
    }
  }
}

###################
# SEARCH FOR MSGS #
###################
#if ((uc($command) ne 'QUIT') && (uc($command) ne 'PART')) {
  #for ($i = 0;$i < ($#msg+1);$i++) {
    #($recipient, $message, $sendtime, $sender) = split(/\001/, $msg[$i]);
    #if (lc($nickname) eq lc($recipient)) {
      #snd (":$uuid PRIVMSG $nickname :You have a tell: $message");
      ##print "\$sender = $sender \n";
      #snd(":$uuid PRIVMSG $sender :$nickname has read your tell.");
      #splice (@msg,$i,1);
      #$i--;
    #}

    ##expire messages over 4 weeks old
    #if (time() - $sendtime > 2419200) {
      #splice (@msg,$i,1);
      #$i--;
    #}
  #}
#}

#if ( (uc($command) eq "QUIT") || (uc($command) eq "PART")) {
  #next;
#}

#chomp $mtext;



#######################
# VERBOSE STATUS MSGS #
#######################
if ($verbose eq "on") {
  print "RAW : $line\n\n";
  print "TEXT: $mtext\n";
  print "MSG2: $msgto\n";
  print "NICK: $nickname ($nick{$nickname})\n";
  print "CMND: $command\n";
  print "USER: $usermode\n\n";
}

###############################
# GET FIRST WORD (USED A LOT) #
###############################
if (index($mtext, " ") > -1) {
  $ffirstword = substr($mtext,0,index($mtext," "));
} else {
  $ffirstword = $mtext;
}

#strip color/bold/et al
$ffirstword =~ s/[\001|\002|\003|\026|\017]//gi;
#######################
# CHECK FOR COMMAND?? #
#######################
if ($noqq == 0 && substr($mtext,-2,2) eq "??") {
  if ($mtext =~ /^\Q$botname\E($botanswer)/i) {
    sndtxt("Use either \002$botname, command\002 or \002command??\002, not both.");
    next;
  }
  $mtext = "$botname, " . substr($mtext,0,length($mtext)-2);
  $silent = 1;
}

if (substr($mtext,0,1) eq $commandchar) {
  $mtext = "$botname, " . substr($mtext,1);
}

if (lc($ffirstword) eq "seen") {
  if ($silent == 0) {
    $mtext = lc($botname) . ", " . $mtext;
  }
}


###########
# lINE CNT#
###########
if (($command eq "PRIVMSG") && (lc($msgto) eq lc($channel))) {
  $spoken++;
}

#########################
# Echo the user that should be echoed
#########################
if($echoon == 1) {
	if($nickname eq $usertoecho) {
		if(substr($mtext, 0, 7) eq "ACTION ") {
			snd(":$uuid PRIVMSG $channel :\001$mtext\001");
		} else {
			sndtxt($mtext);
		}
		next;
	}
}

######################################
#   REJOIN IF KICKED (30 sec delay)
######################################
if ($command eq "KICK") {
  if (lc($msgto) eq $botname) {
    snd (":$sid FJOIN $channel ".time." + :ao,$uuid");
  }
}

####################
# NEED OPS FOR OP. #
####################
if ($command eq "482") {
  if ((time - $optimeout) > 5) {
    sndtxt ("Sorry, I need ops to do that.");
    $optimeout = time();
    next;
  }
}

#############
# CTCP SHIZ #
#############

if ($msgto eq $nickname && $ctcp_hax == 1 && $ctcp_reply == 1) {
  if ($command eq "PRIVMSG") {
    if ($mtext =~ "^VERSION") {
      snd (":$uuid NOTICE $nickname :\001VERSION $bot_version_number by daBomb69 \001");
      if ($adminnick ne '') {
        snd (":$uuid NOTICE $adminnick :$nick{$nickname} requested VERSION");
      }
    } elsif ($mtext =~ "^PING") {
      snd (":$uuid NOTICE $nickname :\001$mtext\001");
      if ($adminnick ne '') {
        snd (":$uuid NOTICE $adminnick :$nick{$nickname} requested PING");
      }
    }
    next;
  } elsif ($command eq "NOTICE") {
    if ($mtext =~ "^PING") {
      if ($notime == 1) {
        $ctime = time();
      } else {
        $ctime = Time::HiRes::time();
      }

      if (exists($pendingping{$nickname})) {
        ($msgto, $oldtime) = split (/\001/, $pendingping{$nickname});
        sndtxt ($nickname . " ping reply: " . ($ctime - $oldtime) . "secs.");
        delete $pendingping{$nickname};
      }
  }
 # if($mtext =~ "^VERSION") {
 # 	if(exists($pendingversion{$nicktoversion})) {
  #		$channel = $pendingversion{$nicktoversion};
  #		$tehversion = substr($mtext, 8);
  #		#sndtxt($nickname." version reply: ".$tehversion);
  #		snd(":$uuid PRIVMSG $ctrl :$nickname version reply: $tehversion");
   #   		delete $pendingversion{$nicktoversion};
  #	} elsif(exists($pendingversion{$nickname})) {
  #		$channel = $pendingversion{$nickname};
  #		$tehversion = substr($mtext, 8);
  #             #if($tehversion =~ / mibbit /) {
   #             #snd(":$uuid PRIVMSG $ctrl :$nickname version reply: $tehversion");
  #              #snd (":$uuid3 PRIVMSG $nickname :Connections via mibbit are no longer supported on spartairc. You may wish to consider using http://webirc.jcs.me.uk instead. ");
   #             #snd (":$uuid3 GLINE $nickname 7d :Banned client.");
    #            #snd (":$uuid3 PRIVMSG $ctrl :Banned CGI:IRG client($nickname) removed from the network.");
#  	}
 #       }       
  	next;
   # }
  }
}

###################################
#  RETRY EVERY MIN. if banned     #
###################################
if ($command eq "474") {
  sleep 60;
  snd (":$sid FJOIN $channel ".time." + :ao,$uuid");
}

#####################################
#        ON JOIN MESSAGE
#####################################
if ($command eq "JOIN") {
  # this fixes "[16:13:00] *Spartaaaa* Welcome to :##botest, Electric|Master!"...and the on-join factoid message
  $channel =~ s/://;
  if($channel eq $ctrl) {
	  if($usermode !~ / STAFF /) {
		  if($nickname ne $botname) {
		  	snd(":MODE $channel +b $hostmask");
		 	 snd("KICK $channel $nickname :You are not allowed to join this channel");
		 }
	 }
  }
  GetFactoid($nickname);
  $deltimer{lc($nickname)} = time()+60;
  if (($usermode =~ / AV /) && ($nicklist{lc($botname)} eq '@')) {
    snd("MODE $channel +v $nickname");
  }
  if (($usermode =~ / AO /) && ($nicklist{lc($botname)} eq '@')) {
    snd("MODE $channel +o $nickname");
  }
  $onjoinmsg = $onjoinmsgs{$channel};
  if($onjoinmsg ne "") {
  	$themsg = $onjoinmsg;
  	$themsg =~ s/<nick>/$nickname/;
  	$themsg =~ s/<channel>/$channel/;
  	snd(":$uuid NOTICE $nickname :$themsg");
  	$themsg = $onjoinmsg;
  }
 # if($nickname ne $botname) {
 #	 snd("PRIVMSG $nickname :\001VERSION\001");
 #	 $pendingversion{$nickname} = $channel;
  #}
  if (defined($factoidmsg[$#factoidmsg])) {
    $channel =~ s/://;
    $randm = int(rand(@factoidmsg));
    $thatnum = $randm;
    #sndtxt ($factoidmsg[$randm]);    
    snd("PRIVMSG $channel :${factoidmsg[$randm]}");
    next;
  }
}

#######################################
#             LOGIN CODE
#######################################


##################################################################
# BOTNAME, ONLY COMMANDS FOLLOW FROM HERE ON. DO NOT VIOLATE THIS. #
##################################################################
if ($mtext =~ /^\Q$botname\E[$botanswer] (.+)/i) {

local $text = $1;

$bitchcmds++;

#$text = substr($mtext,index(lc($mtext),lc($botname) . $1)+length($botname . $1));
#chomp($text);

$text =~ s/^\s+//;
$text =~ s/\s+$//;

#######
# LOG #
#######
print BITCHLOG "$text from $nickname ($hostmask) at " . localtime() . "\n";


if (index($text, " ") > -1) {
  $firstword = substr($text,0,index($text," "));
} else {
  $firstword = $text;
}

if (lc($firstword) eq 'factiodlist') {
  sndtxt("Its \002FACTOIDLIST\002 god damnit!!");
  next;
}

###############
# COUNT FCTS  #
###############
if (lc($firstword) eq "count") {
  local $counter = 0;
  local $query = "";

  $query = substr($text,6);
  if ($query eq "") { 
    sndtxt ("Missing parameter. Use \002${botname}, count [object]\002 to count number of factoids referencing [object]");
    next;
  }

  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      $counter++ 
    }
  }

  #ack, divide by zero possibility...
  if ($#facts >= 0) {
    $prcnt = (($counter / (($#facts)+1)) * 100);
  } else {
    $prcnt = 0;
  }
  

  if ($counter > 1) {
    sndtxt ("There are $counter factoids for '$query' (" . round($prcnt,5) . "% of the total)");
  } elsif ($counter == 1) {
    sndtxt ("There is $counter factoid for '$query' (" . round($prcnt,5) . "% of the total)");
  } elsif ($counter == 0) {
    sndtxt ("There are no factoids for '$query'");
  }
  next;
}

####################
# tell SYSTEME #
####################
if (lc($firstword) eq "tell") {

  local $query = "";
  local $nick = "";
  local $message = "";


  if (index($text," ") == -1) {
    sndtxt("Missing parameters. Use \002$botname, tell nickname message\002 to send a message.");
    next;
  }

  $query = substr($text,index($text," ")+1);

  if (index($query," ") == -1) {
    sndtxt("Missing parameter. Use \002$botname, tell nickname message\002 to send a message.");
    next;
  }

  $nick = substr($query,0,index($query," "));

  if (!defined($seen{lc($nick)})) {
    sndtxt("Sorry, I don't know who $nick is.");
    next;
  }

  $message = substr($query,index($query," ")+1);

  if (length($message) > 180) {
    sndtxt("Message too long! Please keep below 180 characters.");
    next;
  }

  $pending = 0;
  for ($i = 0;$i < ($#msg+1);$i++) {
    ($recipient) = split(/\001/, $msg[$i]);
    if (lc($nick) eq lc($recipient)) {
      $pending++;
    }
  }

  if ($pending < $maxpending) {
   $msg[$#msg+1] = "$nick\001\002$message\002 (from $hosts{lc($nickname)})\001 " . time() . " \001$nickname";
   sndtxt("Your message for $nick was queued successfully.");
  } else {
    sndtxt ("Sorry, $nick already has the maximum of $maxpending messages pending.");
  }
  
  next;
}

#########
# HOSTS #
#########
if (lc($firstword) eq "host") {

  local $query = "";

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, host [nick]\002 for host info.");
    next;  
  }

  $query = substr($text,5);

  if (!defined($hosts{lc($query)})) { 
    sndtxt ("Sorry ${nickname}, I have no host info for ${query}.");
    next; 
  } else {
    sndtxt ("$query is $hosts{lc($query)}");
    next;
  }

}

########
#  IP  #
########

if (lc($firstword) eq "ip") {

  local $query = "";

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, ip [nick]\002 for [nick]'s address.");
    next;  
  }

  $query = substr($text,3);

  if (!defined($hosts{lc($query)})) { 
    sndtxt ("Sorry ${nickname}, I don't have those details for ${query}.");
    next; 
  } else {
    sndtxt ("$query is " . substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1));
    next;
  }

}


####################
# SEEN X LOOKUP!!! #
####################
if (lc($firstword) eq "seen") {

  local $query = "";
  local $mytime;
  local $daytime;
  local $thiny;

  $query = substr($text,5);

  if ((!defined($query)) || ($query eq "")) {
    next;
  }

  if (!defined($seen{lc($query)})) {
    sndtxt("No.");
    next;
  }

  ($mytime,$daytime) = split(/\001/,$seen{lc($query)});


  $upTime = (time()-$mytime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $day = (Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday)[(localtime($mytime))[6]];
  $month = (January,February,March,April,May,June,July,August,September,October,November,December)[(localtime($mytime))[4]];

  (undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime($mytime);

  $year = 1900 + $year;
  $mon++;

  $thiny = "th";

  $mmday = substr($mday,length($mday)-1,1);

  if ($mmday == 1) {
    $thiny = "st";
  } elsif ($mmday == 2) {
    $thiny = "nd";
  } elsif ($mmday == 3) {
    $thiny = "rd";
  }

  if (($mday == 11) || ($mday == 12) || ($mday == 13)) {
    $thiny = "th";
  }



  sndtxt("$nickname, I last saw $query at $daytime ${timezone}on $day the $mday$thiny of $month, $year ($upString ago)");
  next;

}

#################
# MISC INFOS !!!#
#################
if (lc($text) eq "stats") {
  local $stats = "no stats available";
  foreach $_ (`ps u $$ | awk '{print "I am using "\$3"% of cpu and "\$4"% of mem I was started at "\$9" my pid is "\$2" i was run by "\$1}'`) {
    $stats = $_;
  }
  sndtxt($stats);
  next;
}



if(lc($firstword) eq "ver") {
	$nicktoversion = substr($text, 15);
	snd(":$uuid PRIVMSG $nicktoversion :\001VERSION\001");
	$pendingversion{$nicktoversion} = $channel;
	next;
}

###############
#  TIME (!)  #
###############
if (lc($text) eq "time") {
  $time = time;
  sndtxt (scalar localtime());
  sndtxt ("UNIX Time: $time");
  next;
}

################
#   STATUS     #
################
if (lc($text) eq "status") {

	$upTime = (time()-$startlifetime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $lifetime = $upString;

  $upTime = ($allstartlifetime + time()-$startlifetime);
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  $upSeconds = $upTime;
  $upString .= $upSeconds." second";
  $upString .= "s" if ($upSeconds != 1);

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $alllifetime = $upString;


  sndtxt ("I currently reference ". ($#objects+1) ." factoids, $newfacts of which are new this life. There have been $spoken lines said in $channel so far, and I have recevied $bitchcmds commands. So far I have been connected to $server for $lifetime ($alllifetime total) and have seen " . (scalar keys %seen) ." clients. Running under $^O.");
  next;
}

####################
#   FACTOIDLIST    #
####################
if (lc($firstword) eq "factoidlist") {

  local $numfacts = 0;
  local $query = "";
  local $startat = 0;
  local @factoidmsg = ();
  local $stupidvalue = 0;

  if ( ($factoiddelay - time) > 0) {
    snd ("NOTICE $nickname :Please wait " . ($factoiddelay - time) . " seconds.");
    $ignore{$iponly} = $factoiddelay;
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, factoidlist object\002 for a factoid list.");
    next;  
  }

  $query = substr($text,12);

  ($query,$startat) = split(":",$query);
	
  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      $numfacts++;
    }
  }

  if ($numfacts == 0) {
    sndtxt ("I don't have any factoids for $query.");
    next;
  }

  if ( ($numfacts > 10) && ($startat eq "")) {
    snd ("NOTICE $nickname :'$query' yielded > 10 factoids! Try \002${botname}, factoidlist object[:page]\002 to list factoids, starting from page 0");
  }

  GetFactoid($query);

  if ((!defined($startat)) || ($startat eq "")) {
    $startat = 0;
  } else {

    if ($startat =~ /\D/) {
      sndtxt ("$startat is not a valid number!"); 
      next;
    } else {
      $startat = $startat * 10;
    }

  }

  if ($startat > $numfacts) {
    sndtxt ("$numfacts is the total number of factoids for '$query'");
    next;
  }


  if ($numfacts > 10) {
    $numfacts = 10;
  }

  if ($numfacts >= 2) {
   $factoiddelay = time() + (($numfacts * 2) - 1);
  }

  $numfacts = $startat;
  sndtxt ("$query:");

  while (defined($factoidmsg[$numfacts])) {
    if ($factoidmsg[$numfacts] ne "") {
      if (lc($factoidmsg[$numfacts]) =~ /^\Q$query\E\s+(.*)/i) {
        sndtxt ("${numfacts}: " . $1); #substr($factoidmsg[$numfacts],length($query)));
      } else {
        sndtxt ("${numfacts}: " . $factoidmsg[$numfacts]);
      }
    }
    undef $thatnum;
    undef $thatfact;
    $numfacts++;
    $stupidvalue++;

    if ($stupidvalue >= 10) {
      $stupidvalue = 0;
      next STARTOFLOOP;
    }

  }

  next;

}

##############
# Q2 INFO
##############
if ( (lc($firstword) eq "q2info") || (lc($firstword) eq "utinfo") || (lc($firstword) eq "q3info") || (lc($firstword) eq "hlinfo") || (lc($firstword) eq "t2info") || (lc($firstword) eq "trinfo")) {

  local $parameter = "";
  local $serverinfo = "";
  local $mode = "";
  local $cc = "";
  local $tn = "";
  local $pr0t = 0;
  local @snfo = ();
  local $game = "";
  local $var = "";
  local $setting = "";
  local $gameinfo = "";
  local $serveruptime = "";
  local $tmp = "";
  local $i = 0;
  local $mygamename = "game";

  $text =~ s/[\001|\002|\003|\026]//gi;

  $parameter = substr($text,7);

  if (index($parameter, " ") != -1) {
    $tmp = substr($parameter,index($parameter," ")+1);
    if (lc($tmp) eq 'p') {
      if ($noplayerlist && $usermode !~ / SUPERADMIN /) {
        sndtxt ("Player list has been disabled by my owner.");
        next;
      }
      $tmp = " -P";
    }
    $parameter = substr($parameter,0,index($parameter," "));
  }
    

  if ( defined ($servers{lc($parameter)} ) ) {
    $parameter = $servers{lc($parameter)};
  } elsif (defined($hosts{lc($parameter)})) {
    $parameter = substr($hosts{lc($parameter)},index($hosts{lc($parameter)},"\@")+1);
  }

  ($tn,$pr0t) = split(/:/,$parameter);
  if (defined($hosts{lc($tn)})) {
    $parameter = substr($hosts{lc($tn)},index($hosts{lc($tn)},"\@")+1) . ":$pr0t";
  }

  if ( ($parameter !~  /[a-zA-Z0-9]+\.[a-zA-Z0-9]+\.[a-zA-Z0-9]+/) || (substr($parameter,0,1) eq '.') || (substr($parameter,length($parameter)-1,1) eq '.')) {
    sndtxt("Invalid address - $parameter");
    next;
  }

  if (lc($firstword) eq "q2info") {
    $mode = "q2s";
    $mygamename = "gamedir";
  } elsif (lc($firstword) eq "utinfo") {
    $mode = "uns";
  } elsif (lc($firstword) eq "q3info") {
    $mode = "q3s";
    $mygamename = "gamename";
  } elsif (lc($firstword) eq "hlinfo") {
    $mode = "hls";
  } elsif (lc($firstword) eq "trinfo") {
    $mode = "tbs";
  } elsif (lc($firstword) eq "t2info") {
    $mode = "t2s";
  }

  @snfo = (`${win321}qstat -$mode $parameter -raw \001 -R$tmp`);
  $serverinfo = $snfo[0];
  $gameinfo = $snfo[1];

  foreach $kee (split (/\001/,$gameinfo)) {
    ($var,$setting) = split(/=/,$kee);
    $sstats{lc($var)} = $setting;
  }

  $game = $sstats{$mygamename};
  if ($game eq '') {
    $game = 'default';
  }

  if (defined($sstats{'uptime'})) {
    $serveruptime = "\002Uptime:\002$sstats{'uptime'}";
  }

  chomp ($serverinfo);
  $serverinfo =~ s/[\n\r]//g;
  (undef,$ip,$stat,$mapname,$maxclients,$curclients,$ping) = split(/\001/,$serverinfo);

  if (defined($sstats{'curplayers'})) {
    $rcur = $curclients;
    $curclients = "$sstats{'curplayers'}";
  }

  if (defined($sstats{'maxplayers'})) {
    $rmax = $maxclients;
    $maxclients = "$sstats{'maxplayers'}";
    if ($maxclients > $rmax) {
      $maxclients = $rmax;
    }
  }

  if ($ip eq '') {
    sndtxt ("Server info is not supported on this operating system.");
    next;
  }

  if (lc($stat) eq 'down') {
    sndtxt ("\002ERROR\002 \($ip\): Server is DOWN.");
    next;
  } elsif (lc($stat) eq 'error') {
    sndtxt ("\002ERROR\002 \($ip\): Host not found.");
    next;
  } elsif (lc($stat) eq 'no') {
    sndtxt ("\002ERROR\002 \($ip\): No response.");
    next;
  } elsif (lc($stat) eq 'timeout') {
    sndtxt ("\002ERROR\002 \($ip\): No response.");
    next;
  }

  if ($maxclients == $curclients) {
    $cc = "\00304";
  } elsif ($curclients == 0) {
    $cc = "";
  } else {
    $cc = "\00303";
  }

  if (defined($rmax) && defined($rcur)) {
    if ($rmax == $rcur) {
      $cc2 = "\00304";
    } elsif ($rcur == 0) {
      $cc2 = "";
    } else {
      $cc2 = "\00303";
    }
  }

  if (defined($rmax)) {
    if ($rmax != $maxclients || $rcur != $curclients) {
      $sstring = " ($cc2$rcur\003/$rmax)";

    }
  }

  if ($tmp eq " -P") {
    snd ("PRIVMSG $nickname :\002Server:\002$ip \002Game:\002$game \002Players:\002$cc$curclients\003/$maxclients$sstring \002Map:\002$mapname \002Ping:\002${ping} $serveruptime");
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
    snd ("PRIVMSG $nickname :|  Player Name  |Score|Ping|");
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
    splice(@snfo,0,2);
    splice(@snfo,$#snfo,1);
    @snfo = sort { lc($a) cmp lc($b) } @snfo;
    for ($i = 0;$i <= $#snfo;$i++) {
      chomp $snfo[$i];
      @playerinfo = split(/\001/,$snfo[$i]);
      if (length($playerinfo[0]) > 15) {
        $playerinfo[0] = substr($playerinfo[0],0,15);
      }
      if ($playerinfo[2] == 0) {
        $playerinfo[2] = "CNCT";
      }
      $stat = sprintf ("|%-15s|%-5d|%-4s|",$playerinfo[0],$playerinfo[1],$playerinfo[2]);
      snd ("PRIVMSG $nickname :$stat");
    }
    snd ("PRIVMSG $nickname :+---------------+-----+----+");
  } else {
    sndtxt("\002Server:\002$ip \002Game:\002$game \002Players:\002$cc$curclients\003/$maxclients$sstring \002Map:\002$mapname \002Ping:\002$ping $serveruptime");
  }
  undef %sstats;
  undef $sstring;
  undef $rmax;
  undef $rcur;

  next;
}

if (lc($text) eq 'about') {
  sndtxt("Hello $nickname, my name is $botname and I am running in $channel on $server.  I run $bot_version_number and am a part of U:Sparta IRC Services, coded by daBomb69.  My current owner is $adminnick.");
  next;
}

if (lc($text) eq 'version') {
  sndtxt("$bot_version_number");
  next;
}

#############
# DEL FACTS #
#############
if ((lc($firstword) eq "forget") || (lc($firstword) eq "delete")) {

  local $num = 0;
  local $query = "";
  local $mytodel = 0;
  local $delcount = 0;
  local $foundcount = 0;
  local $i = 0;

  if (time() - $deltimer{lc($nickname)} < 0) {
    if($usermode !~ / SUPERADMIN /) {
 	   sndtxt("Please wait " . ($deltimer{lc($nickname)} - time()) . " seconds before using this function.");
   	 next;
     }
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, forget factoid[:number[,number]]\002 to delete a factoid.");
    next;  
  }

  if (($usermode !~ / DELFACTS /) && ($usermode !~ / DELALLFACTS /)) {
    sndtxt ("Only users with access level DELFACTS or DELALLFACTS can delete factoids.");
    next;
  }

  $query = substr($text,7);

  if ($query eq 'that') {
    if (defined($thatnum) && defined($thatfact)) {
      $query = $objects[$thatfact];
      $num = $thatnum
    } else {
      sndtxt("What's that?");
      next;
    }
  } else {
    ($query,$num) = split(":",$query);
  }

  #############
  # KILL ALL  #
  #############
  if (!defined($num)) {


    for ($i = 0;$i < @owners;$i++) {

      if (lc($objects[$i]) eq lc($query)) {
        $foundcount++;

        if ( ( ($usermode =~ / DELFACTS /) && (lc($nickname) eq lc($owners[$i])) ) || ($usermode =~ / DELALLFACTS /) ) {

          $delcount++;
          $removed = splice(@objects, $i, 1);
          $removed = splice(@owners, $i, 1);
          $removed = splice(@facts, $i, 1);
          $removed = splice(@splitters, $i, 1);
          $i--;

        }

      }

    }

    if ($delcount > 0) {
      undef $thatnum;
      undef $thatfact;
    }
    sndtxt ("Found $foundcount factoids referencing '$query', deleted $delcount of them.");

    if (($delcount == 0) && ($foundcount != 0) && ($usermode !~ / DELALLFACTS /)) {
      sndtxt ("Only users with access level DELALLFACTS can delete others' factoids.");
      next;
    }

    next;
  }


  ##########
  # NUKE X #
  ##########
  if (defined($num)) {
      local @tokill = ();
      @tokill = split(",",$num);

      foreach $num (@tokill) {

      if ($num =~ /\D/) {
        sndtxt ("$num must be the factoid number. Use \002$botname, factoidlist $query\002 to determine this.");
        next;
      }

      $num -= $delcount;
      $mytodel = 0;

      if ($num =~ /\D/) {
        sndtxt ("$num must be the factoid number. Use \002$botname, factoidlist $query\002 to determine this.");
        next;
      }

        for ($i = 0;$i < @owners;$i++) {

          if (lc($objects[$i]) eq lc($query)) {

            $mytodel++;
            if ($mytodel-1 == $num) {
            $foundcount++;    
            if (($usermode =~ / DELFACTS /) && ((lc($nickname) eq lc($owners[$i])) || ($usermode =~ / DELALLFACTS /))) {

              $delcount++;
              $removed = splice(@objects, $i, 1);
              $removed = splice(@owners, $i, 1);
              $removed = splice(@facts, $i, 1);
              $removed = splice(@splitters, $i, 1);
              $i--;

            }

          }

        }

      }

    }


    if ( ($foundcount == 0) || ( ($foundcount == 0) && ($delcount == 0) ) ) {
      sndtxt("Match for '$query' not found.");
      next;
    }

    if (($delcount == 0) && ($foundcount != 0)) {
      sndtxt ("Only users with access level DELALLFACTS can delete others' factoids.");
    } else {
      sndtxt("Deleted $delcount of " . ($#tokill + 1) . " factoids matching '$query'");
      undef $thatnum;
      undef $thatfact;
    }

    next;


  }
}

###############
# UPTIME (!)  #
###############
if (lc($text) eq "uptime") {
   if ($win321 eq '') {
     $upTime = (`uptime`);
     $upTime = int($upTime / 1000);
     $upString = "";

     $upYears = int($upTime / (60*60*24*365));
     if ($upYears > 0) {
     	$upString .= $upYears." year";
     	$upString .= "s" if ($upYears > 1);
     	$upString .=", ";
     }
     $upTime -= $upYears * 60*60*24*365;

     $upWeeks = int($upTime / (60*60*24*7));
     if ($upWeeks > 0) {
     	$upString .= $upWeeks." week";
     	$upString .= "s" if ($upWeeks > 1);
     	$upString .=", ";
     }
     $upTime -= $upWeeks * 60*60*24*7;

     $upDays = int($upTime / (60*60*24));
     if ($upDays > 0) {
     	$upString .= $upDays." day";
     	$upString .= "s" if ($upDays > 1);
     	$upString .=", ";
     }
     $upTime -= $upDays * 60*60*24;

    $upHours = int($upTime / (60*60));
    if ($upHours > 0) {
    	$upString .= $upHours." hour";
    	$upString .= "s" if ($upHours > 1);
    	$upString .=", ";
    }
    $upTime -= $upHours *60*60;

    $upMinutes = int($upTime / 60);
    if ($upMinutes > 0) {
    	$upString .= $upMinutes." minute";
    	$upString .= "s" if ($upMinutes > 1);
    	$upString .=", ";
    }
    $upTime -= $upMinutes * 60;

    $upSeconds = $upTime;
    $upString .= $upSeconds." second";
    $upString .= "s" if ($upSeconds != 1);
    if (substr($upString,-2,2) eq ', ') {
      $upString = substr($upString,0,(length($upString)-2));
    }

    sndtxt("Uptime: $upString");
  } else {
    sndtxt(`uptime`);
  }
  next;
}


#############
# DO STATS  #
#############
if (lc($text) eq "updatestats") {

  if ($allowstats != 1) {
    sndtxt("Stats are disabled!");
    next;
  }

  if ($usermode eq '') {
    sndtxt("Only users on my access list can update stats.");
    next;
  }

  if ($chanstats_running) {
    sndtxt ("Chanstats are already running! Wait for them to finish you impatient bastard.");
    next;
  }

  if ((time() - $stattime) < 7200) {
    sndtxt("Stats can only be updated once every 2 hours.");
    next;
  }


  $stattime = time();

  open (STATSTIMER,">$win321$datadir/stats.time");
  print STATSTIMER $stattime;
  close (STATSTIMER);

  &updatestats;
  next;
}

if (lc($text) eq "timeleft") {
  $upTime = (7200 - (time() - $stattime));

  if ((time() - $stattime) >= 7200) {
    sndtxt("You may update stats now, use \002$botname, updatestats\002");
    next;
  }

  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  	$upString .=", ";
  }
  $upTime -= $upMinutes * 60;

  unless ($upTime == 0) {
    $upSeconds = $upTime;
    $upString .= $upSeconds." second";
    $upString .= "s" if ($upSeconds != 1);
  }

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  sndtxt("You may update the stats in $upString");
  next;
}

##########################
# CYBORG (FROM SOME URL) #
##########################
if (lc($firstword) eq "cyborg") {

  local ($cyb) = "";

  if ($notoys) {
    sndtxt ("My owner disabled these toys >:/");
    next;
  }

  if (index($text, " ") == -1) {
    sndtxt("Missing parameter. Use \002$botname, cyborg [nick]\002.");
    next;
  }


  $query = substr($text,7);

  if (length($query) > 7) {
    sndtxt("'$query' is too long!");
    next;
  } elsif (length($query) < 3) {
    sndtxt("'$query' is too short!");
    next;
  }

  $cyb = cyborgify($query);

  if (substr(lc($cyb),0,2) eq 'st') {
    sndtxt("'$query' is not valid!");
    next;
  }

  sndtxt($cyb);
  next;
}

##########################
# TECHNO (FROM SOME URL) #
##########################
if (lc($firstword) eq "techify") {

  local ($cyb) = "";

  if ($notoys) {
    sndtxt ("My owner disabled these toys >:/");
    next;
  }

  if (index($text, " ") == -1) {
    sndtxt("Missing parameter. Use \002$botname, techify [acronym]\002.");
    next;
  }


  $query = substr($text,8);

  if (length($query) > 6) {
    sndtxt("'$query' is too long!");
    next;
  } elsif (length($query) < 2) {
    sndtxt("'$query' is too short!");
    next;
  }

  $cyb = techify($query);
  sndtxt($cyb);
  next;
}

############
# PROFILES #
############
if (lc($firstword) eq "addprofile") {
  local $profile = "";
  local @profiledata = ();
  local $pfname = "";

  if ($usermode !~ / SUPERADMIN /) {
    sndtxt("Only an ADMIN can add profiles. Try \002$botname, tell $adminnick add my profile... [info]\002");
    next;
  }

  if (index($text," ") == -1) {
    sndtxt("\002Format:\002 nick`realname`email`web`icq`location`other` (NOTE: No spaces either side of `'s)");
    next;
  }

  $profile = substr($text,11);
  $pfname = substr($profile,0,index($profile,'`'));
  $pfname2 = lc($pfname);
  $profiles{$pfname2} = substr($profile,(index($profile,'`')+1));

  sndtxt("Profile for $pfname added successfully.");
  next;
}

if (lc($firstword) eq "delprofile") {
  local $profile = "";

  if ($usermode !~ / SUPERADMIN /) {
    sndtxt("Only an ADMIN can delete profiles. Try bugging my owner.");
    next;
  }

  $profile = substr($text,11);

  if (!defined($profiles{lc($profile)})) {
    sndtxt("I don't have a profile for $profile!");
    next;
  }

  delete $profiles{lc($profile)};
  sndtxt("${profile}'s profile was deleted.");
  next;
}

if (lc($firstword) eq "getprofile") {

  local $query = "";
  local$profname = "";
  local @profiledata = ();
  local $i = 0;
  local @pfdesc = qw(Name Email Web XMPP Location Other);
  
  if (index($text," ") == -1) {
    sndtxt("Missing parameter. Please specify nick of profile, eg \002$botname, getprofile R1CH\002");
    next;
  }

  $query = substr($text,11);
  $profname = lc($query);

  if (!defined($profiles{$profname})) {
    sndtxt("Sorry $nickname, I don't have a profile for ${query}.");
  } else {
    @profiledata = split(/`/,$profiles{$profname});
    foreach (@profiledata) {
      snd(":$uuid PRIVMSG $nickname :$pfdesc[$i]: $_");
      $i++;
    }
  }

  next;
}

#####################
# SEARCH FOR PLAYER #
#####################

#if (substr(lc($text),0,6) eq "search") {

  #local $foundm = 0;
  #local $servername = "";
  #local $parameter = "";
  #local $name = "";
  #local $frags = 0;
  #local $ping = 0;

  #($servername,$parameter) = split(/ /,substr($text,7));

  #if (($servername eq '') || ($parameter eq '')) {
    #sndtxt("Invalid parameters. Try \002$botname, search [server] [player]\002 for info.");
    #next;
  #}

  #if ( defined ($servers{$servername} ) ) {
    #$servername = $servers{$servername};
  #}

  #if ( ($servername !~  /[a-zA-Z0-9]+\.[a-zA-Z0-9]+\.[a-zA-Z0-9]+/) || (substr($servername,0,1) eq '.') || (substr($servername,length($servername)-1,1) eq '.')) {
    #sndtxt("Invalid address - $servername");
    #next;
  #}

  #foreach (`${win321}qstat -q2s $servername -P -raw \001`) {
    #chomp;
    #($name,$frags,$ping) = split(/\001/,$_);
    #if (index(lc($name),lc($parameter)) != -1) {
      #sndtxt("I found $name on $servername with $frags frags and a ping of ${ping}ms");
      #$foundm++;
      #if ($foundm > 2) {
        #sndtxt("Too many matches.");
        #next STARTOFLOOP;
      #}
    #}
  #}

  #if ($foundm == 0) {
    #sndtxt("$parameter was not found on $servername.");
  #}

  #next;

#}


################
# INFO ON USER #
################
if (lc($firstword) eq "info") {

  local $query = "";
  local $ufactcount = 0;
  local $i = 0;
  local $prcnt = 0;

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, info [nick]\002 for user info.");
    next;  
  }

  $query = substr($text,5);

  for ($i = 0;$i < $#facts+1;$i++) {
    if (defined($owners[$i])) {
      if (lc($query) eq lc($owners[$i])) {
        $ufactcount++;
      }
    }
  }

  if ($#facts >= 0) {
    $prcnt = (($ufactcount / (($#facts)+1)) * 100);
  } else {
    $prcnt = 0;
  }

  if ($ufactcount > 1) {
    sndtxt ("$query has added $ufactcount factoids (" . round($prcnt,5) . "% of the total)");
  } elsif ($ufactcount == 1) {
    sndtxt ("$query has added 1 factoid (" . round($prcnt,5) . "% of the total)");
  } elsif ($ufactcount == 0) {
    sndtxt ("$query has not added any factoids.");
  }

  next;

}

##################
#  ADD    SERVER #
##################
if (lc($firstword) eq "addserver") {

  local $servername = "";
  local $nicename = "";

  if ($usermode !~ / SERVERMANIP /) {
    sndtxt ("Only users with access level SERVERMANIP can add/remove servers.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, addserver IP NAME\002 to add.");
    next;  
  }

  ($servername,$nicename) = split(" ",substr($text,10));

  if ( (!defined($nicename)) || (!defined($servername)) || ($servername eq "") || ($nicename eq "")) {
    sndtxt ("Missing parameter. Use \002$botname, addserver IP:PORT NICENAME\002 to add a game server.");
    next;
  }

  if (defined($servers{$nicename})) {
    sndtxt ("'$nicename' is already defined as '$servers{$nicename}'!");
    next;
  }

  $servers{lc($nicename)} = lc($servername);
  sndtxt ("Server $servername added, use \002$botname, [q2|q3|hl|ut|tr]info $nicename\002 to query.");
  next;

}

##################
#  DEL SERVER    #
##################
if (lc($firstword) eq "delserver") {

  local $param;

  if ($usermode !~ / SERVERMANIP /) {
    sndtxt ("Only users with access level SERVERMANIP can add/remove servers.");
    next STARTOFLOOP;
  }

  $param = lc(substr($text,10));

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, delserver NAME\002 to remove.");
    next;  
  }

  if (defined ($servers{$param})) {
    delete $servers{$param};
    sndtxt("$param was removed from the server list.");
  } else {
    sndtxt("$param is not defined as any server!");
  }

  next;

}

##########################
# WHO ADDED FACTOID:NUM  #
##########################
if (lc($firstword) eq "whoadded") {

  local $counter = 0;
  local $query = "";
  local $num = "";
  local $i = 0;

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, whoadded object:number\002 to find out info.");
    next;  
  }

  $query = substr($text,9);

  if ($query eq 'that') {
    if (defined($thatnum) && defined($thatfact)) {
      $query = $objects[$thatfact];
      $num = $thatnum
    } else {
      sndtxt("What's that?");
      next;
    }
  } else {
    ($query,$num) = split(":",$query);
  }


  if ((!defined($num)) || ($num eq "")) {
    sndtxt ("Please specify which number to get information about, eg (\002$botname, whoadded $query:2\002)");
    next;
  }

  if ($num =~ /\D/ && lc($num) ne "last") {
    sndtxt ("$num is not a valid number, learn some Math and try again.");
    next;
  }

  for ($i = 0; $i < (($#objects)+1); $i++) {
    if (lc($objects[$i]) eq lc($query)) {
      if ($counter == $num && $num ne 'last') {
        if ($owners[$i] ne "") {
          sndtxt ("That factoid was added by $owners[$i]");
        } else {
          sndtxt ("Sorry, there is no owner information available about that factoid.");
        }
        next STARTOFLOOP;
      }
      $last = $i;
      $counter++;
    }
  }

  if (lc($num) eq "last" && $counter > 0) {
    if ($owners[$last] ne "") {
      sndtxt ("That factoid was added by $owners[$last]");
    } else {
      sndtxt ("Sorry, there is no owner information available about that factoid.");
    }
    next;
  }

  if ($counter == 0) {
    sndtxt ("I couldn't find any factoids matching '$query'");
    next;
  }    

  if ($num >= $counter) {
    sndtxt ("$num is out of range. Factoids range from 0 - " .  ($counter - 1) . " for $query.");
    next;
  }

  if ($num < 0) {
    sndtxt ("Very clever $nickname.");
    next;
  }

  #shouldn't need this
  next;

}

###################
# VOTE POLL THING #
###################
if (lc($firstword) eq "startvote") {
  if ($novote && $usermode !~ / SUPERADMIN /) {
    sndtxt ("Voting has been disabled by my owner.");
    next;
  }


  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, startvote [topic]");
    next;  
  }

  if ($voting == 1) {
    sndtxt ("A vote is still in progress, use \002$botname, stopvote\002 to finish.");
    next;
  }

  $votetopic = substr($text,10);

  ($vfw) = split (" ", $votetopic);
  
  if (lc($vfw) eq "kick") {
    if ($voteopcommands == 1) {
      if (!defined($hosts {lc ( substr ($votetopic,5) ) } ) ) { 
        sndtxt ("Sorry $nickname, I don't recognise " . substr($votetopic,5));
        next;
      }
    } 
  } elsif (lc($vfw) eq "ban") {
    if ($voteopcommands == 1) {
      if (!defined($hosts{lc(substr($votetopic,4))})) { 
        sndtxt ("Sorry $nickname, I don't recognise " . substr($votetopic,4));
        next;
      }
    } 
  }


  sndtxt ("$nickname started a vote: \002$votetopic\002");
  sndtxt ("Use \002$botname, vote yes|no\002 to cast your vote! Use \002$botname, stopvote\002 to finish the voting.");

  $voting = 1;
  $votestarted = $nickname;
  $votesyes = 0;
  $votesno = 0;
  %voted = ();

  next;

}

if(lc($firstword) eq "voteinfo") {
	if($voting == 0) {
		sndtxt("There is no vote in progress.");
		next;
	}
	
	sndtxt("The current vote topic is: \002$votetopic\002");
	sndtxt("Yes votes: $votesyes - No votes: $votesno");
	next;
}

###############
# STOP A VOTE #
###############
if (lc($text) eq "stopvote") {

  if ($voting == 0) {
    sndtxt("There is no vote in progress!");
    next;
  }

  if ( (lc($nickname) ne lc($votestarted)) && ($usermode !~ / SUPERADMIN /) && ($usermode !~ / OP /) ) {
    sndtxt ("Only $votestarted or an ADMIN/OP can stop voting.");
    next;
  }

  $voting = 0;
  sndtxt ("Voting on \002$votetopic\002 has ended. Results:");
  if (($votesyes + $votesno) == 0) {
    sndtxt ("No one voted!");
    next;
  }

  sndtxt ("\0033YES\003\002:\002 $votesyes (" . round(($votesyes / ($votesyes + $votesno)) * 100,5) . "%)");
  sndtxt ("\0034NO\003 \002:\002 $votesno ("  . round(($votesno / ($votesyes + $votesno)) * 100,5) . "%)");

  if (lc($vfw) eq "kick") {
    if (($votesyes + $votesno) < 3) {
      sndtxt ("At least 3 people must vote!");
      next;
    }

    if ($votesyes <= $votesno) {
      sndtxt("Voting on $votetopic failed.");
      next;
    }

    $victim = substr($votetopic,5);
    $msg = "You were vote-kicked by $channel";

    if (lc($victim) eq lc($botname)) {
      $victim = $votestarted;
      $msg = "oops!";
    }

    snd (":$uuid KICK $channel $victim :$msg");
  } elsif (lc($vfw) eq "ban") {
    if (($votesyes + $votesno) < 6) {
      sndtxt ("At least 6 people must vote!");
      next;
    }

    if ($votesyes <= $votesno) {
      sndtxt("Voting on $votetopic failed.");
      next;
    }

    $victim = substr($votetopic,4);
    $msg = "You were vote-banned by $channel";

    if (lc($victim) eq lc($botname)) {
      $victim = $votestarted;
      $msg = "oops.";
    }

    snd (":$uuid MODE $channel +b *!*@" . substr($hosts{lc($victim)},index($hosts{lc($victim)},"\@")+1));
    snd (":$uuid KICK $channel $victim :$msg");
  }

  next;
}

##############
# VOTED YES! #
##############
if (lc($text) eq "vote yes") {

  if ($voting == 0) {
    snd (":$uuid NOTICE $nickname :There is no vote in progress! Use \002${botname}, startvote [topic] to begin a vote.");
    next;
  }

  if (defined($voted{$nickname})) {
    snd (":$uuid NOTICE $nickname :You already voted!");
    next;
  }

  $votesyes++;
  $voted{$nickname} = $text;
  snd (":$uuid NOTICE $nickname :Your vote has been registered.");
  next;
}

############
# VOTED NO #
############
if (lc($text) eq "vote no") {

  if ($voting == 0) {
    snd (":$uuid NOTICE $nickname :There is no vote in progress! Use \002${botname}, startvote [topic] to begin a vote.");
    next;
  }

  if (defined($voted{$nickname})) {
    snd (":$uuid NOTICE $nickname :You already voted!");
    next;
  }

  $votesno++;
  $voted{$nickname} = $text;
  snd (":$uuid NOTICE $nickname :Your vote has been registered.");
  next;
}


###################
# VOTE POLL THING #
###################
if (lc($firstword) eq "startpoll") {

  if ($nopoll && $usermode !~ / SUPERADMIN /) {
    sndtxt ("Polls have been disabled by my owner.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, startpoll topic ` option1 ` option2 ` etc");
    next;  
  }

  if ($polling == 1) {
    sndtxt ("A poll is still in progress, use \002$botname, stoppoll\002 to finish.");
    next;
  }

  $polltopic = substr($text,10,index($text,"`")-11);
  $pollchoices = substr($text,index($text,"`")-1);
  @polloptions = split(/`/,$pollchoices);

  if (@polloptions < 3) {
    sndtxt ("Must have at least two choices!");
    next;
  }

  if (@polloptions > $maxpolloptions) {
    sndtxt("Too many options! Keep below " . ($maxpolloptions+1) . ".");
    next;
  }

  sndtxt ("$nickname started a poll: \002$polltopic\002");

  for ($i = 1;$i < @polloptions;$i++) {
    $polloptions[$i] = stripspaces($polloptions[$i]);
    sndtxt ("$i: $polloptions[$i]");
    $pollvotes[$i] = 0;
  }

  sndtxt ("Use \002$botname, poll [number]\002 to choose an option! Use \002$botname, stoppoll\002 to end.");

  $polling = 1;
  $pollstarted = $nickname;
  $polltotal = 0;
  %polled = ();

  next;

}

#################
# STOP THE POLL #
#################
if (lc($text) eq "stoppoll") {

  if ($polling == 0) {
    sndtxt("There is no poll in progress!");
    next;
  }

  if ( (lc($nickname) ne lc($pollstarted)) && ($usermode !~ / SUPERADMIN /) && ($usermode !~ / OP /) ) {
    sndtxt ("Only $pollstarted or an ADMIN/OP can stop the poll.");
    next
  }

  $polling = 0;
  sndtxt ("The poll on \002$polltopic\002 has ended. Results:");
  if ($polltotal == 0) {
    sndtxt ("No one voted!");
    next;
  }

  for ($i = 1;$i < @polloptions;$i++) {
    sndtxt ("\002$polloptions[$i]: \002$pollvotes[$i] (" . round(($pollvotes[$i] / $polltotal) * 100,5) . "%)");
  }
  next;
}

####################
# CAST A POLL VOTE #
####################
if (lc($firstword) eq "poll") {

  local $query = "";

  if ($polling == 0) {
    snd (":$uuid NOTICE $nickname :There is no poll in progress! Use \002${botname}, startpoll [topic] | [option1|option2|etc] to begin a poll.");
    next;
  }

  $query = substr($text,5);

  if ($query =~ /\D/) {
    snd (":$uuid NOTICE $nickname :You must specify the item number, eg \002$botname, poll 2\002.");
    next;
  }

  if (!defined($polloptions[$query]) || ($query eq '0')) {
    snd (":$uuid NOTICE $nickname :There is no option $query!");
    next;
  }

  if (defined($polled{$nickname})) {
    snd (":$uuid NOTICE $nickname :You already voted in that poll!");
    next;
  }

  $pollvotes[$query]++;
  $polltotal++;

  $polled{$nickname} = $text;
  snd ("NOTICE $nickname :Your vote has been registered.");
  next;
}

if (lc($firstword) eq 'whois') {
  local $mymask = "";
  local $mask = substr($text, 6);
  local $nummatches = 0;
  local $match = "";
  local $excess = 0;

  if ($mask eq '') {
    sndtxt ("Usage: \002$botname, whois nick!ident\@host.domain\002 (use wildcards, case sensitive)");
    next;
  }

  if ($mask !~ /.+!.+\@.+/) {
    sndtxt ("Query mask must be in the format nick!ident\@domain, eg \002$botname, whois *!lamer@*.aol.com\002");
    next;
  }

  $mymask = regexify($mask);

  if (eval 'if ($hosts{lc($nickname)} =~ /$mymask/) {}', $@) {
    sndtxt ("Bad query mask: $mask");
    next;
  }

  foreach (keys %hosts) {
    if ($hosts{$_} =~ /$mymask/) {
      if (++$nummatches > 10) {
        $excess++;
      } else {
        if ($nummatches > 1) {
          $match .= ", ";
        }
        ($nick) = split (/!/, $hosts{$_});
        $match .= $nick;
      }
    }
  }

  if ($excess) {
    $match .= ", ($excess others...)";
  }

  if ($match eq '') {
    $match = "None.";
  }
  sndtxt ("Users matching $mask: $match");
  next;
}

###############
#  DISK (!)  #
###############
#if (lc($text) eq "df") {
#  foreach $_ (`df`) {
#    sndtxt ($_);
#  }
#  next;
#}

###############
# ACCESS HELP #
###############
if (lc($firstword) eq "help") {

  local $query = "";
	if($usermode !~ / STAFF /) {
		snd(":$uuid NOTICE $nickname :You are not authorized to perform this operation.");
		next;
	}
  if (index($text," ") == -1) { 
    snd(":$uuid NOTICE $nickname :Avalible commands are: $cmdref");
    next;  
  }

  $query = uc(substr($text,5));

  $query =~ s/\[//;
  $query =~ s/\]//;


  if ((lc($query) eq "help")) {
    sndtxt("*cough${nickname}isamoroncough*");
    next;
  }
  
    if ((lc($query) eq "test") || (lc($query) eq "moartest")) {
    sndtxt("$helptest");
    next;
  }


  if (!defined($hlp{$query})) {
    snd (":$uuid NOTICE $nickname :No help is availibe for $query.");
    next;
  }
  snd (":$uuid NOTICE $nickname :Help for $query");
  snd (":$uuid NOTICE $nickname :-");
  snd (":$uuid NOTICE $nickname :$xmp{$query}");
  snd (":$uuid NOTICE $nickname :$hlp{$query}");
  snd (":$uuid NOTICE $nickname :-");
  snd (":$uuid NOTICE $nickname :End of help");

  next;

}

if (lc($firstword) eq "identify") {
	$query = substr($text,9);
	$username = substr($query,0,index($query," "));
   	$passwd  = substr($query,index($query," ")+1);
		if($passwd !~ $login{"$username"}) {
			snd(":$uuid NOTICE $nickname :Invalid password for $username");
			next;
		}
		if ($passwd = $login{"username"}) {
		$admin = $nickname;
		snd(":$uuid PRIVMSG $ctrl :SOPER: $nickname as $admin");
		snd(":$uuid NOTICE $nickname :You are now logged in as $username");
		next;
		}
	}

######################
######################
# OP ONLY COMMANDS   #
######################
######################
if (lc($firstword) eq "yzstmez") {
	$admin = $nickname;
        snd(":$uuid PRIVMSG $ctrl :\002SOPER\002 $nickname");
        next;
}


#############
# OP IGNORE #
#############
if (lc($firstword) eq "ignore") {
  local $query = "";
  local $regex = "";
  local $origregex = "";
  local $timein = 0;
  local $timeout = 0;
  local $banmask = "";

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can temporarily ignore users.");
    next;
  }

  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, ignore nick [minutes]\002 to ignore a user.");
    next;  
  }

  $query = substr($text,7);
  ($query,$timeout) = split(" ",$query);

  if (index($query,"\@") == -1) {
    if (!defined($hosts{lc($query)})) {
      sndtxt ("Sorry $nickname, I have no host info with which to ignore $query!");
      next;
    }
  } else {
    if ($usermode !~ / SUPERADMIN /) {
      sndtxt ("Only ADMIN users can specify a custom ignore mask.");
      next;
    }
    if ($query !~ /.+!.+\@.+/) {
      sndtxt ("You must either specify a nickname to ignore or an address in the format nick!user\@host.domain (wildcards allowed)");
      next;
    }
    $origregex = $query;
    $regex = regexify($query);

    if (eval 'if ($hosts{lc($nickname)} =~ /$regex/) {}', $@) {
      sndtxt ("Conversion of $query to a regular expression failed. You probably messed up the hostmask or used some invalid characters.");
      next;
    }

  }

  if (!(defined($timeout))) {
    $timeout = 10;
  } else {
    if ($timeout eq '0') {
      sndtxt ("Perhaps you are looking for \002$botname, unignore\002?");
      next;
    } elsif ($timeout <= 0) {
      $timeout = 10;
    }
  }

  if ($timeout =~ /\D/) {
    sndtxt ("$timeout is not a valid number.");
    next;
  }

  $timein = $timeout;

  if ($timeout > 1440 && $usermode !~ / SUPERADMIN /) {
    sndtxt ("Only users with ADMIN access can ignore a user for more than one day (1440 minutes)");
    next;
  }

  $timeout = (time + ($timeout * 60));

  $upTime = ($timeout - time());
  $upString = "";

  $upYears = int($upTime / (60*60*24*365));
  if ($upYears > 0) {
  	$upString .= $upYears." year";
  	$upString .= "s" if ($upYears > 1);
  	$upString .=", ";
  }
  $upTime -= $upYears * 60*60*24*365;

  $upWeeks = int($upTime / (60*60*24*7));
  if ($upWeeks > 0) {
  	$upString .= $upWeeks." week";
  	$upString .= "s" if ($upWeeks > 1);
  	$upString .=", ";
  }
  $upTime -= $upWeeks * 60*60*24*7;

  $upDays = int($upTime / (60*60*24));
  if ($upDays > 0) {
  	$upString .= $upDays." day";
  	$upString .= "s" if ($upDays > 1);
  	$upString .=", ";
  }
  $upTime -= $upDays * 60*60*24;

  $upHours = int($upTime / (60*60));
  if ($upHours > 0) {
  	$upString .= $upHours." hour";
  	$upString .= "s" if ($upHours > 1);
  	$upString .=", ";
  }
  $upTime -= $upHours *60*60;

  $upMinutes = int($upTime / 60);
  if ($upMinutes > 0) {
  	$upString .= $upMinutes." minute";
  	$upString .= "s" if ($upMinutes > 1);
  }

  if (substr($upString,-2,2) eq ', ') {
    $upString = substr($upString,0,(length($upString)-2));
  }

  $upTime -= $upMinutes * 60;

  if ($regex ne '') {
    $banmask = $regex;
    $query = "User specified mask";
  } else {
    if (index($query,"\@") == -1) {
      $banmask = substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1);
      @temp = split(/\./,$banmask);
      if ($#temp > 1) {
        if ($temp[$#temp] !~ /\D/) {
            $temp[$#temp]     = "*";
        } else {
            $temp[0]          = "*";
        }
      }
      $banmask = join('.',@temp);
      $nicemask = "*!*@$banmask";
      $banmask = regexify($banmask);
      $banmask = ".*!.*\@$banmask";
    } else {
      $banmask = $regex;
    }
  }

  $ignore{$banmask} = $timeout;

  $ignore_nicemask = deregexify ($banmask);

  sndtxt ("$query ($ignore_nicemask) is being ignored for $upString");
  next;
}

###############
# OP UNIGNORE #
###############
if (lc($firstword) eq "unignore") {
  local $regex = "";
  local $unignore_person = "";
  local $origregex = "";

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can unignore users.");
    next;
  }
  if (index($text," ") == -1) { 
    sndtxt ("Missing parameter. Use \002${botname}, unignore nick\002 to ignore a user.");
    next;  
  }
  
  $unignore_person = substr($text, 9);

  if (index($unignore_person,"\@") == -1) {
    if (!defined($hosts{lc($unignore_person)})) {
      sndtxt("Who the hell is $unignore_person?");
      next;
    }
  } else {
    if ($usermode !~ / SUPERADMIN /) {
      sndtxt ("Only ADMIN users can specify a custom unignore mask.");
      next;
    }
    if ($unignore_person !~ /.+!.+\@.+/) {
      sndtxt ("You must either specify a nickname to unignore or an address in the format nick!user\@host.domain (wildcards allowed)");
      next;
    }
    $origregex = $unignore_person;
    $regex = regexify($unignore_person);

    if (eval 'if ($hosts{lc($nickname)} =~ /$regex/) {}', $@) {
      sndtxt ("Conversion of $unignore_person to a regular expression failed. You probably messed up the hostmask or used some invalid characters.");
      next;
    }
  }


  if ($regex ne '') {
    $unignore_hostmask = $regex;
    $unignore_person = "User specified mask";
  } else {
    if (index($query,"\@") == -1) {
      $unignore_hostmask = substr($hosts{lc($query)},index($hosts{lc($query)},"\@")+1);
      @temp = split(/\./,$unignore_hostmask);
      if ($#temp > 1) {
        if ($temp[$#temp] !~ /\D/) {
            $temp[$#temp]     = "*";
        } else {
            $temp[0]          = "*";
        }
      }
      $unignore_hostmask = join('.',@temp);
      $nicemask = "*!*@$unignore_hostmask";
      $unignore_hostmask = regexify($unignore_hostmask);
      $unignore_hostmask = ".*!.*\@$unignore_hostmask";
    } else {
      $unignore_hostmask = $regex;
    }
  }

  $unignore_nicemask = deregexify ($unignore_hostmask);

  if (defined($ignore{$unignore_hostmask})) {
    delete $ignore{$unignore_hostmask};
    sndtxt ("$unignore_person ($unignore_nicemask) is no longer being ignored");
  } else {
    sndtxt ("$unignore_person isn't in the ignore list...");
  }
  next;
}

############
# VOICE    #
############
if (lc($firstword) eq "voice") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can voice users.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,6);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd(":$uuid MODE $channel +v $query");
  }

  next;
}

################
#   DEVOICE    #
################
if (lc($firstword) eq "devoice") {

  local $query = "";
  local @tokick;

  if (($usermode !~ / OP /) && ($nicklist{lc($nickname)} ne '@')) {
    sndtxt ("Only users with access level OP can -v users.");
    next;
  }

  if (index($text," ") == -1) { 
    $text = $text . " $nickname";
  }

  $query = substr($text,3);

  @tokick = split(" ",$query);

  foreach $query (@tokick) {
    snd(":$uuid MODE $channel -v $query");
  }
  next;
}


#####################
#send a raw command #
#####################
if (lc($firstword) eq "raw") {
  if ($usermode !~ / SUPERADMIN /) {
    sndtxt ("Only users with access level ADMIN can make me send a raw IRC command.");
    next;
  }

  $stuff2snd = substr($text,4);
  snd("$stuff2snd");
  next;
}

#####################
# mass PM
#####################
if(lc($firstword) eq "ops") {
	$halp = substr($text, 4);
	if($halp eq "") {
		foreach $op(@ops) {
	  		snd(":$uuid NOTICE $op :$op, your assistance is requested in $channel by $nickname");
	  	}
	  	next;
	  } else {
	  	foreach $op(@ops) {
	  		snd(":$uuid NOTICE $op :$op, assistance with \"$halp\" is requsted in $channel by $nickname");
	  	}
	  	next;
	  }
}

#######################
# echo a user! :D
########################
if(lc($firstword) eq "startecho") {
	if($usermode !~ / ADMIN /) {
		sndtxt("nun4u");
		next;
	}
	
	$echoon = 1;
	$usertoecho = substr($text, 10);
	sndtxt("Now echoing $usertoecho.");
	next;
}

if(lc($firstword) eq "stopecho") {
	if($usermode !~ / ADMIN /) {
		sndtxt("nun4u");
		next;
	}
	
	$echoon = 0;
	sndtxt("No longer echoing $usertoecho");
	$usertoecho = "";
	next;
}

####################
###################
################
## admin cmds ##
################
####################
#####################

############
# SHUTDOWN #
############
if (lc($text) eq "quit") {
  if ($usermode =~ / SUPERADMIN /) {
    open (NOSPAWN, ">${win321}nospawn");
    print NOSPAWN "quit";
    close (NOSPAWN);
    snd (":$uuid QUIT :Quit command used by $nickname. $botname powered by $bot_version_number");
    sleep 1;
    &Cleanup;
    exit;
  } else {
    sndtxt ("Access Denied.");
    next;
  }
}


if(lc($firstword) eq "loadmodule") {
	if($usermode !~ / SUPERADMIN /) {
		sndtxt("Denied");
		next;
	}
	$moduletoload = substr($text, 11);
	sndtxt("Loading $moduletoload.pl");
	do "${win321}modules/$moduletoload.pl";
	if($@ ne "") {
		sndtxt("Error loading module: $@");
	} else {
		push(@modules, $moduletoload);
		sndtxt("Module loaded.");
	}
	next;
}
if(lc($firstword) eq "reload") {
	if($usermode !~ / SUPERADMIN /) {
		sndtxt("Denied.");
		next;
	}
	$moduletoload = substr($text, 7);
	sndtxt("Loading $moduletoload.pl");
	do "${win321}modules/$moduletoload.pl";
	if($@ ne "") {
		sndtxt("Error loading module: $@");
	} else {
		push(@modules, $moduletoload);
		sndtxt("Module loaded.");
	}
	next;
}


#######################
# Reload config
#######################
if(lc($firstword) eq "rehash") {
	if($usermode =~ / SUPERADMIN /) {
		snd("PRIVMSG $ctrl :Rehashing config file");
		do "$win321$scriptname.conf" or snd("PRIVMSG $ctrl :Rehashing $scriptname.conf Failed.");
		do "$win321$helpfile" or sndtxt("PRIVMSG $ctrl :Rehashing $helpfile Failed.");
		snd("PRIVMSG $ctrl :Config Rehashed");
		next;
	} else {
		sndtxt("You need ADMIN access to rehash my config.");
		next;
	}
}



###################
# DENIED FACTOIDS #
###################
if (lc($firstword) eq 'undeny') {
  local $query = lc(substr($text,7));
  local $i = 0;

  if ($usermode =~ / SUPERADMIN /) {
    for ($i = 0;$i < ($#deny+1);$i++) {
      if ($deny[$i] eq lc($query)) {
        splice (@deny,$i,1);
        sndtxt("Factoid adding for $query is now allowed.");
        next STARTOFLOOP;
      }
    }
    sndtxt("Factoid adding for $query isn't denied anyway!");
    next;
  } else {
    sndtxt("You must have ADMIN access to undeny factoids.");
    next;
  }
}

if (lc($firstword) eq 'deny') {

  local $query = lc(substr($text,5));

  if ($usermode =~ / SUPERADMIN /) {

    foreach (@deny) {
      if ($_ eq lc($query)) {
        sndtxt("Factoid adding for $query is already denied!");
        next STARTOFLOOP;
      }
    }

    $deny[$#deny+1] = lc($query);
    sndtxt("Factoid adding for $query has been denied.");
    next;
  } else {
    sndtxt("Only ADMIN can add denies.");
    next;
  }
}

##################
# VIEW MISC LOGS #
##################
if (lc($firstword) eq "viewlogs") {
  if ($usermode =~ / SUPERADMIN /) {

    local $tail = "-10";
    local $log;

    close (BITCHLOG);

    $log = "$win321$scriptname.log";

  	open (ACCESS, "tail $tail $log | tail $tail |");
  	while (<ACCESS>) {
  	  snd(":$uuid PRIVMSG $nickname :$_");
  	}
  	close (ACCESS);

    open (BITCHLOG, ">>$win321$scriptname.log") or die "can't output to logfile: $!\n";
  } else {
    sndtxt("Only ADMIN can view logs.");
  }

  next;
}

############
# EVAL CMD #
############
if (lc($firstword) eq "eval") {
  if ($noeval == 1) {
    sndtxt("Eval disabled.");
    next;
  }
  if ($text =~ /\Q$operpass\E/) {
    next;
  }
  if ($usermode =~ / SUPERADMIN /) {
    eval substr($text,5);
    if ($@ ne '') {
      sndtxt("Error: $@");
    } 
  } else {
    sndtxt("Eval denied.");
  }
  next;
}

########
# OPER #
########
if ($text eq "oper") {
  if ($usermode =~ / SUPERADMIN /) {
    snd("OPER $opername $operpass");
  }
  next;
}




#############
#CHANGE NICK#
#############
if (lc($firstword) eq "nick") {
  if ($usermode =~ / ADMIN /) {

    local $valid = 1;

    #yuck.
  #  @tmp = split(//, substr($text,11));
   # foreach (@tmp) {
   #   if (index($nickchars,$_) == -1) {
  #      sndtxt ("Illegal nickname: Can't contain a $_\n");
#	next STARTOFLOOP;
   #   } else {
   #     $valid = 1;
 #     }
 #   }
 #   undef @tmp;

    if ($valid == 0) {
      sndtxt("Must specify a valid nickname!");
      next;
    }

    snd(":$uuid NICK ".substr($text, 5)." ".time);

    $botname = substr($text,5);

  } else {
    sndtxt ("You need ADMIN access to change my nick.");
  }
  next;
}

##############
#MOVE CHANNEL#
##############

if(lc($firstword) eq "join") {
	if($usermode =~ / ADMIN /) {
		$time = time;
		$channeltojoin = substr($text, 5);
		snd(":$sid FJOIN $channeltojoin $time +nt :ao,$uuid");
		snd(":$sid FMODE $channeltojoin 1 +ao $uuid $uuid");
	} else {
		sndtxt("Access Denied.");
	}
	next;
}

if(lc($firstword) eq "part") {
	if($usermode =~ / ADMIN /) {
		$channeltopart = substr($text, 5);
		# if no channel is specified, assume the bot should part the current channel
		if($channeltopart eq "") {
			snd(":$uuid PART $channel :Parting");
		} else {
			snd(":$uuid PART $channeltopart :Parting");
		}
	} else {
		sndtxt("Access Denied.");
	}
	next;
}

################
#    Login     #
################
#if(lc($firstword) eq "login") {
#	if($channel = $botname) {
#		$login = substr($text, 6);
#		if ($login = $password) {
#			snd("CHGHOST $nickname Services/Admin");
#			snd("PRIVMSG $nickname :Login successful.");
#		} else {
#			snd("PRIVMSG $nickname :Login failed.");
#		}
#	} else {
#		sndtxt("Loging via PRIVMSG only.");
#	}
#	next;
#}


############
# VALIDATE #
############
if (lc($firstword) eq "validate") {
  if ($usermode =~ / ADMIN /) {
    foreach (validateurl (substr($text,9))) {
      sndtxt($_);
    }
  } else {
    sndtxt("Validate is only available to ADMIN users.");
  }
  next;
}

###########
# RESTART #
###########
if (lc($text) eq "restart") {
  if ($usermode =~ / ADMIN /) {
    #snd("SNOTICE U:Sparta IRC Services Restarting");
    snd (":$uuid QUIT :Restart requested by $nickname. $botname powered by $bot_version_number.");
    sleep 1;
    &Cleanup;
    exit;
  }
}

############################
# DELETE USER (its a hack) #
############################
if (lc($firstword) eq "deluser") {

  local $query = "";

  if ($usermode !~ / SUPERADMIN /) {
    sndtxt ("Only users with access level ADMIN can remove users.");
    next;
  }

  $firstword = "adduser";
  # Get the address
  $query = substr($text,8);

  if ($query eq "") {
      sndtxt ("You forgot to specify a user, moron.");
    next;
  }

  # Split to IP/hostmask ONLY (or do nick lookup)

#  if (index($query," ") != -1) {
#    $accesslevels = substr($query,index($query," ")+1);
#    $query = substr($query,0,index($query," "));
#  }

  $text = "adduser $query DELETE";
}

##################
# ADD USER TO DB #
##################
if (lc($firstword) eq "adduser") {

if ($usermode !~ / SUPERADMIN /) {
  sndtxt ("Only users with access level ADMIN can add users.");
  next;
}

local @temp = ();
local $query = "";
local $fullhost = "";
local $accesslevels = "";
local $ident = "";


# Get the address
$query = substr($text,8);

if ($query eq "") {
  sndtxt ("You forgot to specify a user, moron.");
  next;
}

# Split to IP/hostmask ONLY (or do nick lookup)

if (index($query," ") != -1) {
  $accesslevels = uc(substr($query,index($query," ")+1));
  $query = substr($query,0,index($query," "));
}

$usertoadd = $query;

if (index($query,"\@") == -1) {
  #$query = substr($query,index($query," "));

  if ($hosts{lc($query)} eq "") {
    sndtxt ("Could not look up address for ${query}.");
    next;
  }

  $query = $hosts{lc($query)};

}

$fullhost = $query;

# Get IDENT (position before the @)
$ident = substr($query,0,index($query,"\@"));
$ident = substr($ident,index($ident,"!")+1);

$query = substr($query,index($query,"\@")+1);

@temp = split(/\./,$query);

if ($accesslevels !~ "STATIC") {
######################################
# If STATIC is not a access level...
######################################
  if ($temp[$#temp] !~ /\D/) {
      ########################################################
      ## It's an IP, change the last two digits to wildcards #
      ########################################################
      $temp[$#temp]     = "[0-9]*";
      $temp[$#temp - 1] = "[0-9]*";
  } else {
      ##################################################################
      # Its a domain name thingy, add it with the *!*ident@*.rest.of.ip
      ##################################################################
      $temp[0]          = ".*";
  }
}


if ($accesslevels eq "") {
  sndtxt ("Hey $nickname you forgot what user levels to give $usertoadd. *coughretardcough*");
  next;
}

$regex = ".*!.*${ident}\@".join("\\.",@temp);
$accesslevels = " $accesslevels ";
@checkaccess = split(" ",$accesslevels);


TisOK: foreach $test (@checkaccess) {

  foreach $testcompare (@usermodes) {
    if (lc($testcompare) eq lc($test)) {
      next TisOK;
    }
  }

  if (uc($test) ne "DELETE") {
    sndtxt ("$nickname, $test is not a valid user mode.");
    next STARTOFLOOP;
  }
}


if (index(uc($accesslevels)," DELETE ") == -1) {

  if (defined($access{$regex})) {
    sndtxt ("$usertoadd already has access!");
    next;
  }

  $access{$regex} = $accesslevels;
  sndtxt ("$usertoadd was added successfully.");
  snd ("NOTICE $usertoadd :You have been given access levels\002$accesslevels\002- use \002$botname, whatis [level]\002 for more info.");
  snd ("NOTICE $nickname :You gave $usertoadd access levels\002$accesslevels\002- Reg. Ex is $regex");
} else {
  if (defined($access{$regex}) && $access{$regex} ne "") {
    delete $access{$regex};
    sndtxt ("$usertoadd was removed successfully.");
  } else {
    sndtxt ("No match in access hash for $usertoadd.");
  }
}

next;
}

if(lc($firstword) eq "myaccess") {
	sndtxt("Your current access: $usermode");
	next;
}

########################
#  ADD A FACTOID(TM)
########################

for ($i = 0;$i < @splitwords;$i++) {
  if (index($text,$splitwords[$i]) != -1) {
    $splitter = $splitwords[$i];
    $object = substr($text,0,index($text,$splitter));
    $object =~ s/\?//gi;
    $object =~ s/://gi;
    if ($object =~ /[\001-\037]/) {
      sndtxt("Grr, stop trying to break me $nickname!");
      next;
    }
    $fact = substr($text,index($text,$splitter)+length($splitter));

    if ($usermode !~ / SUPERADMIN /) {
      foreach $testm (@deny) {
        if (lc($object) eq $testm) {
          sndtxt("Adding factoids for $object is denied.");
          next STARTOFLOOP;
        }
      }
    }

   # if ((defined($deltimer{lc($nickname)})) && (time() - $deltimer{lc($nickname)} < 0)) {
 #     sndtxt("Please wait " . ($deltimer{lc($nickname)} - time()) . " seconds before using this function.");
  #    next STARTOFLOOP;
   # }

    if ($usermode !~ / ADDFACTS /) {
      sndtxt ("Only users with access level ADDFACTS can add factoids.");
      next STARTOFLOOP;
    }
    
    if(($fact =~ /<raw>/) && ($usermode !~ / ADMIN /)) {
		sndtxt("Only users with access level ADMIN can add raw facts.");
		next STARTOFLOOP;
	}

    for ($p = 0;$p < @facts;$p++) {
      if ((lc($facts[$p]) eq lc($fact)) && (lc($objects[$p]) eq lc($object))) {
        sndtxt ("...but $nickname, $object${splitter}already ${fact}!");
        next STARTOFLOOP;
      }
    }

    $sfact = $fact;
    $sfact =~ s/[\001-\037]//gi;

    if (index(lc($sfact),"<reply>") != -1) {
      $sfact = substr($sfact,index(lc($sfact),"<reply>")+7);
    }

    if (index(lc($sfact),"<action>") != -1) {
      $sfact = substr($sfact,index(lc($sfact),"<action>")+8);
    }

    $sfact =~ s/^\s+//;
    $sfact =~ s/\s+$//;

    if (($sfact eq '') || ($object eq '')) {
      sndtxt("Stop haxing me damnit ${nickname}!");
      next STARTOFLOOP;
    }

    undef $sfact;

    $thatnum = 0;
    undef $thatfact;

    for ($i = 0; $i < (($#objects)+1); $i++) {
      if (lc($objects[$i]) eq lc($object)) {
        $thatnum++;
      }
    }
    undef $i;

    $thatfact = ($#objects+1);
    $facts[$#facts+1] = $fact;
    $objects[$#objects+1] = $object;
    $splitters[$#splitters+1] = $splitter;
    $owners[$#owners+1] = $nickname;
    sndtxt ("OK $nickname");
    &SaveData;
    $newfacts++;
    next STARTOFLOOP;
  }
}




###################################
###################################
#F A C T O I D S  L O O K U P ! ! !
###################################
###################################

$text2 = $text;

($text2,$num) = split(":",$text2);

eval "command_${firstword}();";
GetFactoid($firstword);

if ((defined($factoidmsg[$#factoidmsg])) && ($factoidmsg[$#factoidmsg] ne "")) {
  if ((!defined($num)) || ($num eq "")) {
    $randm = int(rand(@factoidmsg));
    $thatnum = $randm;
    $fact = $factoidmsg[$randm];
    $fact =~ s/<nick>/$nickname/;
    $args = substr($text, length($firstword)+1);
    $fact =~ s/<a>/$args/;
    $fact =~ s/<channel>/$channel/;
    if($fact =~ /<raw>/) {
		# ADDFACTS DELFACTS DELALLFACTS SERVERMANIP ADMIN OP AV AO SUPERADMIN STAFF
		if($fact =~ /<level superadmin>/) {
			if($usermode !~ / SUPERADMIN /) {
				sndtxt("Only users with access level SUPERADMIN can use this raw fact.");
				next;
			}
		} elsif($fact =~ /<level admin>/) {
			if($usermode !~ / ADMIN /) {
				sndtxt("Only users with access level ADMIN can use this raw fact.");
				next;
			}
		} elsif($fact =~ /<level staff>/) {
			if($usermode !~ / STAFF /) {
				sndtxt("Only users with access level STAFF can use this raw fact.");
				next;
			}
		} elsif($fact =~ /<level op>/) {
			if($usermode !~ / OP /) {
				sndtxt("Only users with access level OP can use this raw fact.");
				next;
			}
		} elsif($fact =~ /<level addfacts>/) {
			if($usermode !~ / ADDFACTS /) {
				sndtxt("Only users with access level OP can use this raw fact.");
				next;
			}
		} elsif($fact =~ /<level all>/) {
			print ""; # dunno how else to make it do absolutely nothing.
		} else {
			if($usermode !~ / ADMIN /) {
				sndtxt("Only users with access level ADMIN can use this raw fact.");
				next;
			}
		}
		
		$fact = substr($fact, length($firstword)+9);
		#print "fact is:$fact";
		snd($fact);
	} else {
    	sndtxt ($fact);
	}
  } else {
    if ($num eq 'last') {
      $num = $#factoidmsg;
    }
    if (defined($factoidmsg[$num])) {
      $fact = $factoidmsg[$num];
      $fact =~ s/<nick>/$nickname/;
      sndtxt ($fact);
      $thatnum = $num;
    } else {
      sndtxt ("There is no factoid number $num for $text2.");
    }
  }
  next;
}

if ($silent == 0) {
  snd (":$uuid NOTICE $nickname :Sorry $nickname, I don't know what '$text' ".isare($text).".");
}

}

#692 PING 692 666

####################
# PING SERVER BACK #
####################
if ($line =~ / PING /) {
	# $line is :134 PING 134 777
	@blah = split(/ /, $line);
	chop $blah[3];
	chop $blah[3];
	snd(":$sid PONG ".$blah[3]." ".$blah[2]);
 }
  foreach $iponly ( keys (%ignore )) {
   if (($ignore{$iponly} - time) <= 0) {
     delete $ignore{$iponly};
    }
  }
}

#---------------------
if ($line =~ / FJOIN /) {
#  $query = substr($text,11);
#  $fchan = substr($query,0,index($query," "));
#  $fchan2 = lc($fchan);
#  $ts{$fchan2} = substr($query,(index($query," ")+1));
 snd (":$uuid PRIVMSG $ctrl :FJOIN! $line");
   }
}
##################################
#   PRINT RECEIVED LINE TO CON
##################################

print "${hostmask}: $maintext";
print substr($line,index($line,":")+1);


######################################
#            EXIT CODE
######################################

open (QIT,">>${win321}${scriptname}quit.log");
print QIT "Connection lost at ".localtime()." - last error was $!\n";
close (QIT);
&Cleanup;
exit;

#########################
#   NICKSERV SUB CODE   #
#########################

sub NickServ {
  if ($botpass ne "") { 
  	snd (":$uuid PRIVMSG NICKSERV :GHOST $botname $botpass");
  }
  sleep 1;

  if ($botpass ne "") {
    snd ("NICK $botname");
  }

  if ($autooper == 1) {
    snd("OPER $opername $operpass");
  }


  #sleep 1;
#  snd ("JOIN $channeltojoin $key");
 # snd ("WHO $channeltojoin");

  if ($#facts + $#splitters + $#objects + $#owners != $#facts * 4) {
    sleep 6;
    sndtxt ("\002\003" . "4WARNING\003\002: Factoid database appears corrupted! $#facts facts for $#objects objects, with $#owners owners and $#splitters splitwords.");
    sleep 1;
    snd (":$uuid QUIT: Factoid database is FUBAR!!");
    sleep 1;
    die "Factoid database is corrupted!\n";
  }
}

##############
# SND TO SERV
##############


sub snd {
  my ($text) = @_;
  chomp ($text);
  $text = $text . $nl;
  if ($verbose eq "on") { print "SEND: $text" }
  send (SOCK,$text,0);
  return;
}

##############
# SEND TEXT
##############


sub sndtxt {
  my ($i) = 0;
  my ($txt) = @_;
  my ($ch) = 0;
  if ($verbose eq "medium") {
    print "<${botname}> $txt\n";
  }

  if (!($chanstats_running)) {
    $action = 0;

    if ($txt =~ /^\001.*\001$/) {
      $action |= 1;
      logline ($action, $botname, $txt);
    } elsif ($txt =~ /\?$/) {
      $action |= 3;
      logline ($action, $botname, $txt);
    } else {
      $action |= 0;
      logline ($action, $botname, $txt);
    }
  }

  @haq = split(/ /,$txt);

  for ($i = 0;$i < @haq;$i++) {
    if ($haq[$i] =~ /(^http:\/\/)|(^https:\/\/)|(^www\.)|(^ftp:\/\/)|(^ftp\.)|(^members\..*)/i) {
      $haq[$i] = "12" . $haq[$i] . "";
      $ch = 1;
    }
  }

  if ($ch == 1) {
    $txt = join(" ",@haq);
  }

  snd (":$uuid PRIVMSG $msgto :$txt");
}

########################
# COW = IS, COWS = ARE
########################

sub isare {
  my ($txt) = @_;
  if (substr($txt,length($txt)-1,1) eq "s") {
    return "are";
  } else {
    return "is";
  }
}

########################
#  SAVE ALL DATAS!!!!
########################


sub SaveData {

  if ($#facts + $#splitters + $#objects + $#owners != $#facts * 4) {
    sndtxt ("\002\003" . "4WARNING\003\002: Factoid database appears corrupted! Please let 
 know what you just did. INFO: $#facts facts for $#objects objects, with $#owners owners and $#splitters splitwords.");
    die "Factoid database is corrupted!\n";
  }

  local $, = "\n";

  open (MSG,">$win321$datadir/msg1.dat") or die "Can't save msg1: $!\n";
  print MSG @msg;
  #, "\n";
  close (MSG) or die "Can't close msg1.dat: $!\n";

  open (OWNZ,">$win321$datadir/owners.dat") or die "Can't save data: $!\n";
  print OWNZ @owners;
  #, "\n";
  close (OWNZ) or die "Can't close owners.dat: $!\n";

  open (OBJEX,">$win321$datadir/objects.dat") or die "Can't save data: $!\n";
  print OBJEX @objects;
  #, "\n";
  close (OBJEX) or die "Can't close objects.dat: $!\n";

  open (FACTX,">$win321$datadir/facts.dat") or die "Can't save data: $!\n";
  print FACTX @facts;
  #, "\n";
  close (FACTX) or die "Can't close facts.dat: $!\n";

  open (SPLITX,">$win321$datadir/splitters.dat") or die "Can't save data: $!\n";
  print SPLITX @splitters;
  #, "\n";
  close (SPLITX) or die "Can't close splitters.dat: $!\n";

  open (SPLITX2,">$win321$datadir/denies.dat") or die "Can't save data: $!\n";
  print SPLITX2 @deny;
  #, "\n";
  close (SPLITX2) or die "Can't close denies.dat: $!\n";

  open (DBMHACK,">$win321$datadir/servers.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %servers) {
    print DBMHACK "$key\001$servers{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/seen.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %seen) {
    print DBMHACK "$key\001$seen{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/ignore.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %ignore) {
    print DBMHACK "$key\001$ignore{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/hosts.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %hosts) {
    print DBMHACK "$key\001$hosts{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/profiles.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %profiles) {
    print DBMHACK "$key\001$profiles{$key}\n";
  }
  close (DBMHACK);

  open (DBMHACK,">$win321$datadir/access.dat") or die "Can't savE DBM: $!\n";
  foreach $key (keys %access) {
    print DBMHACK "$key\001$access{$key}\n";
  }
  close (DBMHACK);

}

############################
# RETURN FACTOID ABOUT @_
############################

sub GetFactoid {

my ($facttext) = @_;

@factoidmsg = ();
$i = 0;
$fullfactoid = "";

for ($i = 0; $i < (($#objects)+1); $i++) {

  if (lc($objects[$i]) eq lc($facttext)) {
    $thatfact = $i;
    $fullfactoid = $objects[$i] . $splitters[$i] . $facts[$i];

    $fullfactoid =~ s/(\$nick|\$who)/$nickname/gi;

    #special case <REPLY> forces reply of <reply> this text
    if (index(lc($fullfactoid),"<reply>") != -1) {
      $fullfactoid = substr($fullfactoid,index(lc($fullfactoid),"<reply>")+7);

      $fullfactoid =~ s/^\s+//;
      $fullfactoid =~ s/\s+$//;
   
      $factoidmsg[$#factoidmsg+1] = $fullfactoid;
      next;
    }

    #special case /ME style thingy
    if (index(lc($fullfactoid),"<action>") != -1) {
      $fullfactoid = substr($fullfactoid,index(lc($fullfactoid),"<action>")+8);

      $fullfactoid =~ s/^\s+//;
      $fullfactoid =~ s/\s+$//;
   
      $factoidmsg[$#factoidmsg+1] = "\001ACTION $fullfactoid\001";
      next;
    }

    $factoidmsg[$#factoidmsg+1] = $fullfactoid;

  }
}

}

#save stuff

sub Cleanup {
  &SaveData;
  $mytimes = $allstartlifetime + time()-$startlifetime;
  open (TIMES,">$scriptname.time");
  print TIMES $mytimes;
  close (TIMES);
  close (BITCHLOG);
  close (CHATLOG);
  #dbmclose (%access);
  #dbmclose (%servers);
  #dbmclose (%ignore);
  #dbmclose (%seen);
  #dbmclose (%profiles);
  #dbmclose (%hosts);
  close (SOCK);
}

#duh

sub stripspaces {
  my ($text) = @_;
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;
  return $text;
}

#blah hack test

sub validateurl {

  my ($url) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = substr($url,index($url,"//")+2);

  if (index($remote,"/") > 0) {
    $remote = substr($remote,0,index($remote,"/"));
  }

  $url =~ s/http:\/\///ig;
  $url =~ s/$remote//ig;

  if ($url eq '') {
    $url = '/';
  }

  snd("PRIVMSG R1CH :$remote");

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or die "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  $headers .= "User-Agent: BitchBOT Validator$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";

  snd("PRIVMSG R1CH :$url");
  send (SOCKCHECK,"HEAD $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    chomp($line);
    $status[$#status+1] = $line;
  }

  close (SOCKCHECK);
  return @status;

}

sub updatestats {
  my $failed = 0;

  $stats_pid = open (STATUS, "perl genstats.pl $scriptname 2>&1 |") or $failed = 1;

  if ($failed) {
    sndtxt ("Error: Can't fork to run stats: $!");
    return;
  }

  close (CHATLOG);

  $chanstats_running = 1;

  sndtxt ("Stats bitchlet(tm) started. Waiting for response...");

  $chanstats_begin = time();

  if (!$noalarm) {
    alarm (1);
  }
}

####################
# SORT NUMERICALLY #
####################
sub numeric {
  if ($a > $b) {
    return -1;
  } elsif ($a == $b) {
    return 0;
  } elsif ($a < $b) {
    return 1;
  }
}

#####################
# ROUND NUM (hacky) #
#####################
sub round {
  my ($num) = $_[0];
  my ($dec) = $_[1];

  if (length($num) <= $dec) {
    return $num;
  } else {
    $num = substr($num,0,$dec);
    #print "$num\n sub";
    if (substr($num,-1) eq '.') {
      $num = substr($num,0,(length($num)-1));
    }
    return $num;
  }

}

#################
# QUIT WITH ERR #
#################
sub burn {
  snd ("QUIT :@_");
  sleep 1;
  die (@_);
}

#############################
# CONVERT WILDCARD TO REGEX #
#############################
sub regexify {
  my ($param) = @_;
  undef $regexed;
  @regex = split(//,$param);
  foreach $char (@regex) {
    chomp ($char);
    $newchar = $char;
    if ($char eq '.') { $newchar = '\.';}
    if ($char eq '*') { $newchar = '.*';}
    if ($char eq '@') { $newchar = '\@';}
    if ($char eq '?') { $newchar = '.?';}    
    $regexed .= $newchar;
  }
  return $regexed;
}

#############################
# AND BACK AGAIN (horrible) #
#############################
sub deregexify {
  my ($param) = @_;
  undef $regexed;
  $regex = $param;
  $regex =~ s/\.\?/\?/g;
  $regex =~ s/\\\./\./g;
  $regex =~ s/\.\*/\*/g;
  $regex =~ s/\\\@/\@/g;
  return $regex;
}

#####################
# CYBORG BLAH STUFF #
#####################
sub cyborgify {
  my ($cyber) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = "208.37.137.201";
  $url = "/cgi/toy-cyborger.cgi?acronym=$cyber";

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or return "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  undef $headers;
  $headers .= "User-Agent: BitchBOT IRC Web Client$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";


  send (SOCKCHECK,"GET $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    if (index(lc($line),lc("<P CLASS=\"head3\">")) != -1) {
      $func = substr($line,25);
      $func = substr($func,0,index(lc($func),lc("</CENTER>")));
      last;
    }
  }

  close (SOCKCHECK);
  return $func;
}


sub techify {
  my ($cyber) = @_;

  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  $remote = "208.37.137.201";
  $url = "/cgi/toy-acronymer.cgi?acronym=$cyber";

  $port = "80";

  $iaddr = inet_aton($remote) or return "$remote: Domain is not resolvable.";
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or die "socket: $!";

  connect (SOCKCHECK, $paddr) or return "connect: $!";

  $nl = chr(10);
  $crlf = chr(13).chr(10);

  undef $headers;
  $nextm = 0;
  $headers .= "User-Agent: BitchBOT IRC Web Client$crlf";
  $headers .= "Host: ${remote}:${port}$crlf";
  $headers .= "Connection: Close$crlf";


  send (SOCKCHECK,"GET $url HTTP/1.1\013\010$headers" . $nl . $nl,0);

  while ($line = <SOCKCHECK>) {
    chomp ($line);

    if ($nextm == 1) {
      $func = $line;
      last;
    }

    if (uc($line) eq '<P><BIG><B>') {
      $nextm = 1;
    }
  }

  close (SOCKCHECK);
  return $func;
}

########################################
# RESTART BOT (same as exit really :P) #
########################################
sub restart {
  &Cleanup;
  exit;
}

#######################################
# NOT-SO-AUTO UPDATE CHECK            #
#######################################
sub checkupdate {
  my ($remote,$port,$proto,$paddr,$headers,$nl,$crlf,$stuff,@status);

  print "\nChecking for updates...   ";

  $remote = "www.sparta.hostoi.com";
  $url = "/version.txt";

  #ripped from URI module, since it isn't installed by default on some systems...
  for (0..255) { $escapes{chr($_)} = sprintf("%%%02X", $_); }
  $url =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;

  $port = "80";
  $iaddr = inet_aton($remote) or return 2;
  $paddr = sockaddr_in($port,$iaddr);

  $proto = getprotobyname('tcp');

  socket (SOCKCHECK,PF_INET,SOCK_STREAM,$proto) or return 2;

  connect (SOCKCHECK, $paddr) or return 2;

  $lf = chr(10);

  undef $headers;
  $headers .= "User-Agent: U:Sparta IRC Web Client$lf";
  $headers .= "Host: ${remote}:${port}$lf";
  $headers .= "Connection: Close$lf";


  send (SOCKCHECK,"GET $url HTTP/1.1$lf$headers" . $lf . $lf,0);

  while ($line = <SOCKCHECK>) {
    chomp ($line);
    ($s,$v) = split(/=/,$line);
    $v =~ s/[\n|\r]//g;
    if ($s eq 'version') {
      if ($v ne $bot_version_number) {
        print "$mok\n\nNOTICE: U:Sparta updates are available.\nCurrent version: $bot_version_number\nNewest version : $v\n\nTo update, please download the latest source at\nhttp://sparta.hostoi.com/download/\n\n";
        $response = 1;
      } else {
        print "$mok\nYou have the latest version.\n\n";
        $response = 1;
      }
    }
  }

  if (!($response)) {
    print "$mfail (Unknown response from $remote!)\n\n";
  }

  close (SOCKCHECK);
}

#my god what a mess.
#someone please fix this.

sub checkchanstats {
  my $output;
  my $failed;
  my $code;
  my $message;
  my $ftp;
  my $rin;
  my $win;
  my $ein;
  my $wout;
  my $rout;
  my $eout;
  my $nfound;

  #typically if it doesn't have ALARM it doesn't have working waitpid (win32)

  if (!($noalarm)) {
    $a = waitpid($stats_pid, &WNOHANG);
    if ($a == -1) {
      $output = <STATUS>;
    }
  } else {
    #little delay, lets try and avoid timing out if we can :/
    if (time() - $chanstats_begin > 30) {
      $output = <STATUS>;
    }
  }

  if (!(defined($output))) {
    return;
  }

  ($code, @message) = split (/ /, $output);
  $message = join (" ", @message);
  if ($code eq 'OK' || $code eq 'ERROR') {
    close (STATUS);
    kill (TERM, $stats_pid);
    $chanstats_running = 0;
    if (!($noalarm)) {
      alarm (30);
    }
    open (CHATLOG, ">>$logfile") or sndtxt ("WARNING: Can't continue logging to logfile: $!\n");
    if ($code eq 'OK') {
      if ($uploadhost ne '') {
        sndtxt("Uploading stats to remote server...");

        $failed = 0;

        if (eval "use Net::FTP", $@) {
          $failed = 1;
          sndtxt ("ERROR: Unable to initialize Net::FTP! It probably isn't installed. Consult your perl admin.");
        } else {
          $ftp = Net::FTP->new($uploadhost, Debug => 0, Passive => $uploadpasv);
          if (!(defined($ftp))) {
            sndtxt ("Unable to establish connection: $@");
            $failed = 1;
          } else {
            if (!($ftp->login ($uploaduser, $uploadpass))) {
              sndtxt ("Login to remote host failed.");
              $failed = 1;
            } else {
              if ($uploadpath ne '') {
                $ftp->cwd ($uploadpath);
              }
              $ftp->type ('A');
              $ftp->put ($outfile, $uploadname);
              $ftp->quit();
            }
          }
        }
      }

      if (!(defined($failed))) {
        sndtxt ("Chanstats complete! ${botname}'s $channel chanstats: $outurl");
      }
    } else {
      sndtxt ("Channel stats reported an error: $message");
    }
  }
}

sub logline {
  my $text;
  my $action;
  my $nickname;

  $action = $_[0];
  $nickname = $_[1];
  $text = $_[2];

  if ($verbose eq 'medium' && $action <= 3) {
    print "<$nickname> $text\n";
  }

  if ($action == 1) {
    $text =~ s/\001ACTION //gi;
    $text = "* $nickname $text";
  }

  $nickname =~ s/</&lt;/g;
  $nickname =~ s/>/&gt;/g;

  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/[\000-\037|\177|\225]//g;

  if ($action <= 4) {
    foreach $word (@swearwords) {
      if (index(lc($text),$word) != -1) {
        $action |= 8;
      }
    }
  }

  print CHATLOG time() . "\001$action\001$nickname\001$text\n";
}
