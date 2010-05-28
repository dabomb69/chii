sub command_randpass {
  use String::MkPasswd qw(mkpasswd);

  # for the masochisticly paranoid...
  sndtxt mkpasswd(
      -length     => 4000,
      -minnum     => 1000,
      -minlower   => 1000,   # minlower is increased if necessary
      -minupper   => 1000,
      -minspecial => 1000,
      -distribute => 1,
  );
   next;
}
