package Modules::Info;
sub admin {
	main::snd(":$main::sid PUSH $main::nickname :256 $main::nickname :Administrative info for $servname");
	main::snd(":$main::sid PUSH $main::nickname :257 $main::nickname :Name - $adminreal");
	main::snd(":$main::sid PUSH $main::nickname :258 $main::nickname :main::nickname - $adminnick");
	main::snd(":$main::sid PUSH $main::nickname :259 $main::nickname :E-Mail - $adminmail");
}

sub motd {
	main::snd(":$main::sid PUSH $main::nickname :375 $main::nickname :$servname message of the day");
	main::snd(":$main::sid PUSH $main::nickname :372 $main::nickname :- This server is not a client server.");
	main::snd(":$main::sid PUSH $main::nickname :372 $main::nickname :- Please type /quote MOTD for information about this network.");
	main::snd(":$main::sid PUSH $main::nickname :372 $main::nickname :- If you must know more information about this service, please type /quote ADMIN $main::servname and message the administrator of this service.");
	main::snd(":$main::sid PUSH $main::nickname :372 $main::nickname :- Thanks for flying SpartaIRC!");
	main::snd(":$main::sid PUSH $main::nickname :372 $main::nickname :-			~ SpartaIRC Administration");
}

sub fail {
	main::snd(":$main::uuid PRIVMSG $main::channel :WHY THE FUCK AM I NOT WORKING?!?!?!?!?!?!? >_<");
}

sub init {
	PUSH $main::nickname :(@testmods, $mod);
	main::snd(":$main::uuid PRIVMSG $main::ctrl :Module Modules::".$main::mod." loaded.");
}

1;
