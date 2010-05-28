##############
# SAMODE     #
##############
sub command_mode {
  if ($usermode !~ / STAFF /) {
    sndtxt ("Access Denied.");
    next;
  }

  $query = substr($text,5);
  snd(":$uuid MODE $query");
  snd(":$uuid PRIVMSG $ctrl :$nickname used SAMODE to set the mode(s): $query");
  next;
}

