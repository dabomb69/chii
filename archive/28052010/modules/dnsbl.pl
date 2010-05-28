sub command_dnsbl {
  use Net::DNS;
  my $host2find = substr($text,6);
  @revip = split(/\./, $host2find); 
  $tofind = $revip[3].".".$revip[2].".".$revip[1].".".$revip[0]; 
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->search("$tofind."."dnsbl.dronebl.org");
  if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          #sndtxt ($rr->address, "\n");
		  sndtxt "This IP is \002\003ON\003\002 the blacklist.";
      }
  } else {
	  sndtxt "This IP is not on the blacklist! Congrats!";
      #sndtxt("query failed: ".$res->errorstring);
  }
next;
}
