#!/bin/sh

# Update all keys in output/gpg by fetching from a keyserver
KEYSERVER="pool.sks-keyservers.net"

basedir=/var/ksp
gpghome=$basedir/output/gpg

# Make sure we really want to do this
if [ ! -d $gpghome ]; then
    echo Output directory does not exists, please run klist.sh first.
    exit 2
fi

NUMKEYS=$( ls -1 $basedir/keys | wc -l )
i=0
for key in $(ls -1tr $basedir/keys); do
	i=$(( $i + 1 ))
	# Skip files starting with !.
	[ "x${key%!*}" = "x" ] && continue
	/bin/echo -ne "$key $i/$NUMKEYS\r"
	gpg --homedir $gpghome -q --keyserver "$KEYSERVER" --recv-key $key 2>/dev/null
done
echo
