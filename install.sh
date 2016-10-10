#!/bin/sh -
#
#  Shell script used to begin installation of the InfoWatcher program.
#
perl=''
dirs="`echo $PATH | sed -e 's/:/ /g'`"
for dir in $dirs ; do
	if [ -x "$dir/perl" ]; then
		perl="$dir/perl"
		exec $perl install.pl $perl
	fi
done

echo "I could not find the perl program."
echo "Where is it? "

read ans

if [ -d $ans ]; then
	perl="$ans/perl"
elif [ -x $ans ]; then
	perl="$ans"
else
	echo "The perl program is required for this package to run."
	echo "Find out where perl is located on this system and try again."
	exit (1)
fi

exec $perl install.pl $perl
