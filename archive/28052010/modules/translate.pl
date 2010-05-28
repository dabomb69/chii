sub command_translate {
	use REST::Google::Translate;

	REST::Google::Translate->http_referer('http://example.com');

	my $res = REST::Google::Translate->new(
			q => 'hello world',
			langpair => 'auto|en'
	);

	die "response status failure" if $res->responseStatus != 200;

	my $translated = $res->responseData->translatedText;

	sndtxt "Translation: $translated";
	next;
}
