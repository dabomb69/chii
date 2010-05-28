#!/usr/bin/perl
use Net::DNS;
  sub command_lookup {
$host2find = substr($text,7);
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->search("$host2find");
  
  if ($query) {
      foreach my $rr ($query->answer) {
          next unless $rr->type eq "A";
          sndtxt $rr->address, "\n";
         # sndtxt $win;
}
  } else {
      sndtxt("query failed: ".$res->errorstring);
    #  sndtxt "query failed: ", $res->errorstring, "\n";
    #  sndtxt $fail;  
}
next;
}
