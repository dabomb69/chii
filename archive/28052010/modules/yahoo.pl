sub command_search {
 use Yahoo::Search;
 $query = substr($text,7);
 my @Results = Yahoo::Search->Results(Doc => "$query",
                                      AppId => "GTZRlRrV34H.bJc_rS5ah1IiYF0DexDZMpWLHgT9T9J_uyFaIQAuRQorAo6ZEx6XtwRVvTyfrHCREA--",
                                      # The following args are optional.
                                      # (Values shown are package defaults).
                                      Mode         => 'all', # all words
                                      Start        => 0,
                                      Count        => 50,
                                      Type         => 'any', # all types
                                      AllowAdult   => 1, # no porn, please
                                      AllowSimilar => 0, # no dups, please
                                      Language     => undef,
                                     );
 warn $@ if $@; # report any errors

 for my $Result (@Results)
 {
	 $Resultno = $Result->I + 1;
	 $Resulturl = $Result->Url;
	 $Resultclick = $Result->ClickUrl;
	 $Resultsummary = $Result->Summary;
	 $Resulttitle = $Result->Title;
	 $ResultCacheUrl = $Result->CacheUrl;
     #sndtxt "Result: #%d\n",  #$Result->I + 1,
     #sndtxt "Url:%s\n",       #$Result->Url;
     #sndtxt "%s\n",           #$Result->ClickUrl;
     #sndtxt "Summary: %s\n",  #$Result->Summary;
     #sndtxt "Title: %s\n",    #$Result->Title;
     #sndtxt "In Cache: %s\n", #$Result->CacheUrl;
	 sndtxt "Result: $Resultno",  #$Result->I + 1,
     sndtxt "Url: $Resulturl",       #$Result->Url;
     sndtxt "$Resultclick",           #$Result->ClickUrl;
     sndtxt "Summary: $Resultsummary",  #$Result->Summary;
     sndtxt "Title: $Resulttitle",    #$Result->Title;
     sndtxt "In Cache: $ResultCacheUrl", #$Result->CacheUrl;
     sndtxt "\n";

}
 next;
}
sub command_image {
 use Yahoo::Search;
 $query = substr($text,6);
 my @Results = Yahoo::Search->Results(Image => "$query",
                                      AppId => "GTZRlRrV34H.bJc_rS5ah1IiYF0DexDZMpWLHgT9T9J_uyFaIQAuRQorAo6ZEx6XtwRVvTyfrHCREA--",
                                      # The following args are optional.
                                      # (Values shown are package defaults).
                                      Mode         => 'all', # all words
                                      Start        => 0,
                                      Count        => 5,
                                      Type         => 'any', # all types
                                      AllowAdult   => 1, # no porn, please
                                      #AllowSimilar => 0, # no dups, please
                                      #Language     => undef,
                                     );
 warn $@ if $@; # report any errors

 for my $Result (@Results)
 {
	 $Resultno = $Result->I + 1;
	 $Resulturl = $Result->Url;
	 $Resultclick = $Result->ClickUrl;
	 $Resultsummary = $Result->Summary;
	 $Resulttitle = $Result->Title;
	 $ResultCacheUrl = $Result->CacheUrl;
     #sndtxt "Result: #%d\n",  #$Result->I + 1,
     #sndtxt "Url:%s\n",       #$Result->Url;
     #sndtxt "%s\n",           #$Result->ClickUrl;
     #sndtxt "Summary: %s\n",  #$Result->Summary;
     #sndtxt "Title: %s\n",    #$Result->Title;
     #sndtxt "In Cache: %s\n", #$Result->CacheUrl;
	 #sndtxt "Result: $Resultno",  #$Result->I + 1,
     sndtxt "Url: $Resulturl",       #$Result->Url;
     #sndtxt "$Resultclick",           #$Result->ClickUrl;
     #sndtxt "Summary: $Resultsummary",  #$Result->Summary;
     sndtxt "Title: $Resulttitle",    #$Result->Title;
     #sndtxt "In Cache: $ResultCacheUrl", #$Result->CacheUrl;
     sndtxt "\n";

}
 next;
}

