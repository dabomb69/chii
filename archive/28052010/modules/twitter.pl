sub command_tweet {

 use Net::Twitter::Lite;

  my $nt = Net::Twitter::Lite->new(
$user = "spartairc",
$password = "^kitari^"
  );

  my $result = eval { $nt->update('Hello, world!') };

  eval {
      my $statuses = $nt->friends_timeline({ since_id => $high_water, count => 100 });
      for my $status ( @$statuses ) {
          sndtxt "$status->{created_at} <$status->{user}{screen_name}> $status->{text}\n";
      }
  };
  warn "$@\n" if $@;
  next;
}
