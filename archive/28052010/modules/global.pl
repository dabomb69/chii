#####################
#  MESSAGE NOTICES  #
#####################
sub command_announce {
  if ($usermode !~ / SUPERADMIN /) {
    sndtxt ("Access denied.");
    next;
  }

  $announcement = substr($text,9);
  snd("SNOTICE $announcement");
  sleep 60;
  snd("SNOTICE $announcement");
  sleep 60;
  snd("SNOTICE $announcement");
  sleep 60;
  snd("SNOTICE $announcement");
  next;
}
######################
# Global
######################
sub command_global {
  if ($usermode !~ / GLOBAL /) {
	sndtxt ("Access denied.");
	next;
	}
	$global = substr($text,7);
	snd(":$uuid NOTICE \$* :\002[Global Message]\002 $global");
	snd(":$uuid PRIVMSG $ctrl :\002GLOBAL\002 $nickname");
	next;
}
