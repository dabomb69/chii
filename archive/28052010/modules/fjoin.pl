sub command_fjoin {
$query = substr($text,6);
snd (":$sid FJOIN $query ".time." + :ao,$uuid");
snd (":$sid FMODE $query ".time." +ao $uuid $uuid");
next;
}