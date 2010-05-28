 sub command_wiki {
 use WWW::Wikipedia;
  my $wiki = WWW::Wikipedia->new();

  ## search for 'perl' 
  my $result = $wiki->search( 'perl' );

  ## if the entry has some text print it out
  if ( $result->text() ) { 
      sndtxt $result->text();
  }

  ## list any related items we can look up 
  sndtxt join( "\n", $result->related() );
  next;
}
