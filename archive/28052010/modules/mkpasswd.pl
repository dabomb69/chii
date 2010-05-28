sub command_mkpasswd {
  if ($usermode !~ / STAFF /) {
        sndtxt ("Access denied.");
       next;
        }
	$query = substr($text,9);
			use Digest::SHA qw(hmac_sha256_hex);
				sndtxt hmac_sha256_hex("$query", chr(0x0b) x 32), "\n";
	next;
}
