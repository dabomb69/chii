#!/bin/sh
rm -f ./nospawn
while [ 1 ]
do
	if [ -e ./nospawn ]
	then
		echo "The file 'nospawn' exists. This indicates U:Sparta has told the infinite spawner to stop running, either due to a power failure or a 'quit' command. Spawner is now exiting."
		rm -f ./nospawn
		exit
	fi
	perl chii.pl 
done

