sub command_ambur {
snd(":$sid SERVER eos.spartairc.co.cc * 1 777 :Sparta Project IRC");
snd(":777 BURST");
snd (":777 UID 777AAAAAA 1 Ambur 98.170.207.192 SpartaIRC/Staff/Ambur amber 98.170.207.192 1 +iw :Splappy");
snd(":777AAAAAA OPERTYPE IRCop");
snd(":777 FJOIN #lobby ".time." + :,666AAAAAA");
snd(":777 FJOIN #orgy ".time." + :,666AAAAAA");
snd(":777 FMODE #lobby 1 +ao Ambur Ambur");
snd(":777 FMODE #orgy 1 +h Ambur");
snd(":777 ENDBURST");
next;
}
