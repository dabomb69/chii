sub command_fmode {
$query = substr($text,6);
snd (":$sid FMODE $query ".time." +ao $botname $botname");
next;
}