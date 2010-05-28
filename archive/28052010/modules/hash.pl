$hlp{"HASH"} = "Encodes text into the specified hash and gives the results. Supported hash types are: SHA1, SHA224, SHA256, SHA384, SHA512, MD5, Adler32, Skein256, Skein512, Skein1024, ";
$xmp{"HASH"} = "$botname, hash <hash type> <text to hash>";

#---------------------

sub command_hash {

	$query = substr($text,5);
		if ($query =~ /^sha1 /i) {
			use Digest::SHA qw(hmac_sha1_hex);
				$tohash = substr($query,5);
				sndtxt hmac_sha1_hex("$tohash", chr(0x0b) x 32), "\n";
				next;
 }
	    if ($query =~ /^sha256 /i) {
			use Digest::SHA qw(hmac_sha256_hex);
				$tohash = substr($query,7);
				sndtxt hmac_sha256_hex("$tohash", chr(0x0b) x 32), "\n";
				next;
 }
		if ($query =~ /^sha224 /i) {
			use Digest::SHA qw(hmac_sha224_hex);
				$tohash = substr($query,7);
				sndtxt hmac_sha224_hex("$tohash", chr(0x0b) x 32), "\n";
				next;
 }
		if ($query =~ /^sha384 /i) {
			use Digest::SHA qw(hmac_sha384_hex);
				$tohash = substr($query,7);
				sndtxt hmac_sha384_hex("$tohash", chr(0x0b) x 32), "\n";
				next;
 }
		if ($query =~ /^sha512 /i) {
			use Digest::SHA qw(hmac_sha512_hex);
				$tohash = substr($query,7);
				sndtxt hmac_sha512_hex("$tohash", chr(0x0b) x 32), "\n";
				next;
 }
		if ($query =~ /^md5 /i) {
		use Digest::MD5 qw(md5_hex);
			$tohash = substr($query,4);
			sndtxt md5_hex("$tohash"), "\n";
			next;
 }

		if ($query =~ /^adler32 /i) {
		use Digest::Adler32;
			$tohash = substr($query,8);
			$a32 = Digest::Adler32->new;
			$a32->add($tohash);
			sndtxt $a32->hexdigest, "\n";
			next;
 }
 		if ($query =~ /^blargag /i) {
		use Digest::Adler32;
		use Digest::MD5 qw(md5_hex);
		use Digest::SHA qw(hmac_sha512_hex);
		use Digest::Skein qw/ skein_512 skein_1024_hex /;
			$tohash = substr($query,8);
			$a32 = Digest::Adler32->new;
			$a32->add($tohash);
			$adler = $a32->hexdigest;
			$md5 = md5_hex("$adler");
			$sha512 = hmac_sha512_hex("$md5", chr(0x0b) x 32);
			$skein = skein_1024_hex('$sha512');
			sndtxt $skein;
			next;
 }
		if ($query =~ /^skein256 /i) {
		use Digest::Skein qw/ skein_256_hex /;
				$tohash = substr($query,9);
				sndtxt skein_512_hex('$tohash'), "\n";
				next;
 }
		if ($query =~ /^skein512 /i) {
		use Digest::Skein qw/ skein_512_hex /;
				$tohash = substr($query,9);
				sndtxt skein_512_hex('$tohash'), "\n";
				next;
 }
		if ($query =~ /^skein1024 /i) {
		use Digest::Skein qw/ skein_1024_hex /;
				$tohash = substr($query,10);
				sndtxt skein_1024_hex('$tohash'), "\n";
				next;
 }
		if ($query =~ /^whirlpool /i) {
		use Digest;
			$tohash = substr($query,10);
				$whirlpool = Digest->new( 'Whirlpool' );
				$whirlpool->add( "$tohash" );
				$hexdigest = $whirlpool->hexdigest;
				sndtxt $hexdigest;
				next;
 }
		if ($query =~ /^tiger /i) {
		use Digest::Tiger;
				$tohash = substr($query,6);
				$hexhash = Digest::Tiger::hexhash('$tohash');
				sndtxt $hexhash;
				next;
 }
}
