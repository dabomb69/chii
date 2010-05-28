	open(SENDMAIL, "|/usr/lib/sendmail -oi -t -odq")
		or die "Can't fork for sendmail: $!\n";
	print SENDMAIL <<"EOF";
	From: User Originating Mail <me\@host>
	To: Final Destination <you\@spartairc\.co\.cc>
	Subject: A relevant subject line
	Body of the message goes here after the blank line
	in as many lines as you like.
	EOF
	close(SENDMAIL)     or warn "sendmail didn't close nicely";
