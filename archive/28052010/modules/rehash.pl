sub command_hashbrowns {
  #if ($usermode !~ / GLOBAL /) {
   #     sndtxt ("Access denied.");
    #    next;
     #   }
      #  $global = substr($text,7);
        snd(":$uuid REHASH *");
        snd(":$uuid PRIVMSG $ctrl :SERVER REHASH: \002$nickname\002");
        next;
}





