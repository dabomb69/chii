sub command_crypt {
$query = substr($text,6);
	if ($query =~ /^blowfish /i) {
	use Crypt::Blowfish;
	$tohash = substr($query,9);
	@blowfish = split(/ /, $tohash); 
	$key = $blowfish[0]; 
	$plaintext = $blowfish[1];
		$cipher = new Crypt::Blowfish $key; 
		$ciphertext = $cipher->encrypt($plaintext);
		sndtxt $ciphertext;
		next;
 }
 
  	if ($query =~ /^base64 /i) {
	use MIME::Base64;
	$tohash = substr($query,7);
		$encoded = MIME::Base64::encode($tohash);
		sndtxt $encoded;
		next;
 }

}
 
#sub command_decrypt {
#$query = substr($text,8);
	#if ($query =~ /^blowfish /i) {
	#use Crypt::Blowfish;
	#$tohash = substr($query,9);
	#@blowfish = split(/ /, $tohash); 
	#$key = $blowfish[0]; 
	#$ciphertext = $blowfish[1];
		#my $cipher = new Crypt::Blowfish $key; 
		#my $plaintext = $cipher->decrypt($ciphertext);
		#sndtxt $plaintext;
		#next;
 #}

  
  	#if ($query =~ /^base64 /i) {
	#$tohash = substr($query,7);
		#$decoded = MIME::Base64::decode($tohash);
		#sndtxt $decoded;
		#next;
 #}
#}
