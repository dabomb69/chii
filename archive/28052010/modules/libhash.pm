#!/usr/bin/perl
use Digest; #Preinstalled in most recent Perl distros
use Digest::Adler32; # cpan -i Digest::Adler32
use Digest::MD5 qw(md5_hex); #Preinstalled
use Digest::Tiger; # cpan -i Digest::Tiger
use Digest::SHA qw/ hmac_sha256_hex hmac_sha1_hex hmac_sha384_hex hmac_sha512_hex /; #Preinstalled
use Digest::Skein qw/ skein_256_hex skein_512_hex skein_1024_hex /; # cpan -i Digest::Skein

#Adler32 Hash Command
sub adler32 {
	if ($tohash =~ /^adler32 /i) {
		$tohash = substr($tohash,8);
		$a32 = Digest::Adler32->new;

 # add stuff
		$a32->add($tohash);

 # get digest
			sndtxt "Adler32: ", $a32->hexdigest, "\n";
		$tohash = $a32->hexdigest;
next;
	}
}

#MD5 Hash
sub md5 {
	if ($tohash =~ /^md5 /i) {
		$tohash = substr($tohash,4);
			sndtxt "MD5: ", md5_hex("$tohash"), "\n";
		$tohash = md5_hex("$tohash");
next;
	}
}

#SHA1 Hash
sub sha1 {
	if ($tohash =~ /^sha1 /i) {
		$tohash = substr($tohash,5);
			sndtxt hmac_sha1_hex("$tohash", chr(0x0b) x 32), "\n";
		$tohash = hmac_sha1_hex("$tohash", chr(0x0b) x 32);
next;
	}
}

#SHA256 Hash
sub sha256 {
	if ($tohash =~ /^sha256 /i) {
		$tohash = substr($tohash,7);
			sndtxt hmac_sha256_hex("$tohash", chr(0x0b) x 32), "\n";
		$tohash = hmac_sha256_hex("$tohash", chr(0x0b) x 32);
next;
	}
}

#SHA384 Hash
sub sha1 {
	if ($tohash =~ /^sha384 /i) {
		$tohash = substr($tohash,7);
			sndtxt hmac_sha384_hex("$tohash", chr(0x0b) x 32), "\n";
		$tohash = hmac_sha384_hex("$tohash", chr(0x0b) x 32);
next;
	}
}

#SHA512 Hash
sub sha1 {
	if ($tohash =~ /^sha512 /i) {
		$tohash = substr($tohash,7);
			sndtxt hmac_sha512_hex("$tohash", chr(0x0b) x 32), "\n";
		$tohash = hmac_sha512_hex("$tohash", chr(0x0b) x 32);
next;
	}
}
