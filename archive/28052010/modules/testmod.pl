sub command_testmod {
  if ($usermode !~ / SUPERADMIN /) {
        sndtxt ("Access denied.");
       next;
        }
	$query = substr($text,7);
	require "./modules/test.pm";
	&general_init;
	next;
}

sub command_testload {
	  if ($usermode !~ / SUPERADMIN /) {
        sndtxt ("Access denied.");
       next;
        }
    $mod = substr($text,9); 
    require "modules/$mod.pm";
    my $func = "Modules::" . $mod . "::init";
	eval $func;
	next;
}
