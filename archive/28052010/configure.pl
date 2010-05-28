#!/usr/bin/perl
#
# nandBot Configuration/Upgrade tool
#
# Copyright (c) 2005 nandhp
#

use File::Copy;
use strict;

print <<END;
Welcome to nandBot.

This configuration wizard will guide you through the process of
setting up and configuring chii. This wizard will start by testing
the Perl modules available on your system. Please press ENTER to begin.

END
<STDIN>;

my $failed=0;
my $failedopt=0;

my @modules = qw/Socket Time::HiRes Net::DNS Net::FTP MIME::Base64 Digest::Adler32 Digest::MD5 Digest::Tiger Digest::SHA Digest::Skein Digest String::MkPasswd REST::Google::Translate Net::Twitter::Lite WWW::Wikipedia Yahoo::Search/;
my $isrequired = 1;
foreach my $m (@modules) {
    if ( $m == 1 ) {
	$isrequired = 0;
	next;
    }
    print "$m";
    print ' 'x(30-length($m));
    my $r = eval("use $m;1;");

    if ( !defined($r) || $@ || !$r ) {
	if ( $isrequired ) { print "not ok\n"; $failed++ }
	else { print "not ok (optional)\n"; $failedopt++ }
    }
    else {
	print "ok\n";
    }
}
if ( $failed ) {
    print "\nSome required perl modules are unavailable. Please install them from CPAN, your Linux package system or your Perl vendor.\n\nPress ENTER to quit the configuration wizard.";
    <STDIN>;
    exit(1);
}
elsif ( $failedopt ) {
    print "\nSome optional perl modules are unavailable. Some optional features may not work.\n\nDo you want to continue anyway? [Y]";
    exit(1) if <STDIN> =~ /n/i;
}

print "\n\n";
print "Please select one:\n";
print "   1. Upgrade from old installation\n";
print "   2. Import from Legacy nandBot 0.5x\n";
print "   3. Don't import anything\n";
print "\n";
print "   0. Quit\n";
print "\n";
my $r;
while ( 1 ) {
    print "Your choice? [3] ";
    $r = <STDIN>;$r =~ s/\D+//g;
    if ( $r >= 0 && $r <= 3 ) { last }
}
print "\n\n";
if ( $r == 0 && $r ne '' ) {
    exit(1);
}
elsif ( $r == 1 || $r == 2 ) {
    print "Upgrade from old installation\n";
    my $dir = '';
    my $legacy = 0;
    while ( !$dir ) {
	print "Where is your old configuration? ";
	$dir = <STDIN>;
	$dir =~ s/[\r\n]//g;
	if ( !-f "$dir/nandbot.pl" ) {
	    print "That is not a valid nandBot installation directory\n";
	    $dir = '';
	}
	elsif ( !-f "$dir/nblang.pm" ) {
	    print "Upgrading from Legacy nandBot\n";
	    $legacy = 1;
	    #exit(1);
	}
    }
    if ( !$legacy ) {
	print "Copying nandbot.conf...";
	rename "nandbot.conf", "nandbot.conf.backup";
	copy("$dir/nandbot.conf","./nandbot.conf");
	print "done.\nCopying nandbot.db...";
	rename "nandbot.db", "nandbot.db.backup";
	copy("$dir/nandbot.db","./nandbot.db");
	print "done.\n\n\n";
	print "We will now attempt to upgrade your database. Your database\nmust be upgraded before it can be used.\n";
	exit(1) if `perl upgradedb.pl` =~ /^no/;
	system 'perl','setaccess.pl','-prompt';
    }
    else {
	print "Importing legacy configuration\n";
	print "Attempting migration of nandbot.conf...\n";
	rename "nandbot.conf", "nandbot.conf.backup";
	open OLDCFG, "$dir/nandbot.conf";
	open NEWCFG, ">nandbot.conf";
	print NEWCFG "; This configuration file was automatically migrated\n";
	print NEWCFG "; from a Legacy nandBot installation by configure.pl\n";
	print NEWCFG "; at ".scalar(localtime)."\n\n";

	print "nandBot 2.0 is multi-lingual\nThe following languages are available:\n";
	opendir DIR,"nblang";
	while (my $x = readdir DIR) {
	    next if $x =~ /^\./|| !-f "nblang/$x";
	    $x =~ s/_/-/g;
	    $x =~ s/\.pm$//g;
	    print "    $x\n";
	}
	closedir DIR;
	my $lang = ask("What language would you like nandBot to use?","en");
	print NEWCFG "lang=$lang\n\n";
	print "\n\n";
	print "Continuing migration...\n";
	while (<OLDCFG>) {
	    print NEWCFG $_;
	}
	print "Migrating serverlist...\n";
	close OLDCFG;
	open OLDCFG, "$dir/serverlist";
	my @servers = ();
	while (<OLDCFG>) {
	    s/[\r\n]//g;
	    push @servers, $_;
	}
	print NEWCFG "servers=".join(',',@servers)."\n";
	close NEWCFG;
	print "nandbot.conf saved.\n";
	print "\nWe will now create a new database file to store the users\n";
	print "and factoids in.\n";
	rename "nandbot.db", "nandbot.db.backup";
	exit(1) if `perl upgradedb.pl` =~ /^no/;

	print "\nNow that that is out of the way, I will begin importing. Please be patient.\nPlease be aware that IRCPoints are not currently supported. However they will be migrated.\n";
	$| = 1;

	my $db_handle = DBI->connect("dbi:SQLite:dbname=nandbot.db","","");

	opendir DATADIR, "$dir/data";
	while (my $file = readdir DATADIR ) {
	    next unless -f "$dir/data/$file";
	    next if $file =~ /^\./;
	    if ( $file =~ /^(.+)\.users$/i ) {
		print '.';
		my %user = ();
		$user{nick}=$1;
		open FILE, "$dir/data/$file";
		while (<FILE>) {
		    m/^(.+?)=(.+?)[\r\n]*$/i;
		    $user{$1}=$2;
		}
		$user{seenmsg} = $user{seentxt};
		$user{ircpoints} = $user{points};
		delete $user{unsaved};
		delete $user{kickstats};
		delete $user{seentext};
		delete $user{seentxt};
		delete $user{points};
		delete $user{angeroptout};
		my $newuser = $db_handle->prepare(q{insert into users (id,nick) values (NULL, lower(?))});
		$newuser->execute($user{nick});

		# Dynamicly build an UPDATE line.
		my @a = ();
		my $str = '';
		foreach ( keys %user ) {
		    $str .= "$_=?, ";
		    push @a, $user{$_};
		}
		$str =~ s/,\s*$//g;
		push @a, $user{nick};
		my $updateuser = $db_handle->prepare('update users set '.$str.' where nick=?');
		# Execute!
		$updateuser->execute(@a);
	    }
	    elsif ( $file =~ /^(.+)\.facts$/i ) {
		print '#';
		my %fact = ();
		$fact{name}=$1;
		open FILE, "$dir/data/$file";
		while (<FILE>) {
		    m/^(.+?)=(.+?)[\r\n]*$/i;
		    $fact{$1}=$2;
		}
		$fact{locked} = '' if $fact{locked} eq 'notlocked';
		$fact{kind} = 'is';
		$fact{created} = time;
		$fact{modified} = time;
		$fact{mods} = 0;
		$fact{reader} = '';
		$fact{lastread} = time;
		$fact{reads} = 0;
		delete $fact{unsaved};
		delete $fact{forgot};
		delete $fact{dunno};
		delete $fact{targetwait};
		delete $fact{creato};
		my $newuser = $db_handle->prepare(q{insert into facts (id,name) values (NULL, lower(?))});
		$newuser->execute($fact{name});

		# Dynamicly build an UPDATE line.
		my @a = ();
		my $str = '';
		foreach ( keys %fact ) {
		    $str .= "$_=?, ";
		    push @a, $fact{$_};
		}
		$str =~ s/,\s*$//g;
		push @a, $fact{name};
		my $updateuser = $db_handle->prepare('update facts set '.$str.' where name=?');
		# Execute!
		$updateuser->execute(@a);
	    }
	    else { print '?' }
	}
	print "\n\nAll done!\n\n";
    }
}
elsif ( $r == 3 || $r eq '' ) {
    print "Don't import anything\n\n";
    print "We will now attempt to upgrade your database. Your database\nmust be upgraded before it can be used.\n";
    exit(1) if `perl upgradedb.pl` =~ /^no/;
    print "\n\n";
    my $newconf = 0;
    if ( -f "nandbot.conf" ) {
	print "You already have a nandbot.conf file.\nWould you like to create a new configuration? [N] ";
	$newconf = 1 if <STDIN> =~ /y/i;
    }
    else {
	print "You do not have a nandbot.conf file. We will have to create one\nfor you.";
	$newconf = 1;
    }

    if ( $newconf ) {
	print "\n\n";
	unlink "nandbot.conf.backup";
	rename "nandbot.conf", "nandbot.conf.backup";
	my @config=();
	push @config, "; This configuration file automatically generated by",
	  "; configure.pl at ".scalar(localtime),"";

	print "The following languages are available:\n";
	opendir DIR,"nblang";
	while (my $x = readdir DIR) {
	    next if $x =~ /^\./|| !-f "nblang/$x";
	    $x =~ s/_/-/g;
	    $x =~ s/\.pm$//g;
	    print "    $x\n";
	}
	closedir DIR;
	my $lang = ask("What language would you like nandBot to use?","en");
	push @config, "lang=$lang",'';
	print "\n\n";


	my $nick = ask("What is this nandBot's nickname going to be?","nandBot");
	push @config, "nick=$nick";
	my $ownernick = ask("What is you (the owner)'s IRC nickname?");
	print "\n";
	my $owneremail = ask("What is your email address? This will be put in nandBot's realname field as a way to contact you.\nPress enter if you don't want one:");
	my $owner = $ownernick;
	$owner .= " <$owneremail>" if $owneremail;
	push @config, "owner=$owner";

#	print "Now please choose an unimportant password to use for authenticating to nandBot.\n";
#	my $pass = ask("Password:");
	system 'perl','setaccess.pl',$ownernick,'10';

	print "\n\n\nNow this is the nasty part of the configuration.\nI need a list of rooms to auto-join on connect, and rooms I can talk in.\n\n";
	print "Press enter when there are no more.\n";

	while (1) {
	    print "\n";
	    my $r  = ask("Room:");
	    last unless $r;
	    my $aj = ask("Auto-Join: ","y","1,0,y=1,n=0,yes=1,no=0");
	    my $ct = ask("Can I talk?","y","1,0,y=1,n=0,yes=1,no=0");
	    push @config, "$r=$aj,$ct";
	}

	print "\n\n\nNow, who are my neighbors? I can consult my neighbors when someone asks me\nabout a factoid, and I'm clueless.\n\nMy neighbors must be other bots that understand the infobot inter-bot protocol. infobot, blootbot, nandBot, and mozbot all understand this protocol.\n\nPress enter when there are no more.\n";

	my @bots = ();
	while (1) {
	    my $b = ask("Neighbor's nick:");
	    last unless $b;
	    push @bots, $b;
	}
	push @config, "neighbors=".join(',',@bots);
	print "\n\n\nWhat IRC servers can I connect to? I need at least one:\n";
	my @servers = ();
	while (1) {
	    my $b = ask("Server:");
	    last unless $b;
	    push @servers, $b;
	}
	push @config, "servers=".join(',',@servers);
	print "\nThank you. Saving nandbot.conf...\n";
	open OUTFILE, ">nandbot.conf" or die "Error opening nandbot.conf: $!";
	print OUTFILE join("\n",@config);
	close OUTFILE;
    }
}
print "\n<<<<<<<<<<<<<  CONFIGURATION COMPLETED WITH NO ERRORS  >>>>>>>>>>>>>\n";
print "You may now run nandbot.pl to start nandBot.\nThank you for choosing nandBot.\n";

sub ask {
    my ($q,$d,$c) = @_;
    $d ||= "";
  Retry:
    print "$q";
    print " \[$d\]" if $d;
    print " ";
    my $a = <STDIN>;
    $a =~ s/[\r\n]//g;
    $a = $d unless $a;
    if ( $c ) {
	$a = lc $a;
	if ( $a =~ /^q|quit$/ ) {
	    exit 0;
	}
	elsif ( $c !~ m@(^|,)($a=([^,]+)(,|$)|$a(,|$))@ ) {
	    print "\nPlease try again\n";
	    goto Retry;
	}
	else {
	    $a = $3 if defined $3;
	}
    }
    return $a;
}
