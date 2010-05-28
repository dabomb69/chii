sub command_mailtest {
use Mail::Mailer;
	$from_address = "abuse\@Chaos";
	$to_address = "root\@spartairc\.co\.cc";
	$subject = "Mail Test";
	$body = "This is a test of Perl's Mail::Mailer module!";
	$mailer = Mail::Mailer->new();
	$mailer->open({ From    => $from_address,
					To      => $to_address,
					Subject => $subject,
				  })
		or die "Can't open: $!\n";
	print $mailer $body;
	$mailer->close();
	next;
}
