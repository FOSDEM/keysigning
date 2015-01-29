#!/bin/sh

#
# Generates a keylist and a tarball.
# Based on pkk-generate-list as shipped with
# pgp-kspkeyserver (http://mdcc.cx/pgp-kspkeyserver/).
#

basedir=/var/ksp

# Make sure we really want to do this
if [ -d $basedir/output ]; then
    echo Output directory exists, delete it first.
    exit 2
fi

gpghome=$basedir/output/gpg
mkdir -p $gpghome
chmod 700 $gpghome

# Import all keys into a clean gpg keyring.
printf "Importing keys...\r"
N=$( ls -1 $basedir/keys | wc -l )
i=0
for key in $(ls -1tr $basedir/keys); do
    i=$(( $i + 1 ))
    # Skip files starting with !.
    [ "x${key%!*}" = "x" ] && continue
    printf "Importing keys $i/$N\r";
    gpg --homedir $gpghome -q --import $basedir/keys/$key
done
echo "$N keys imported     "

# Print each key neatly into the keylist.
echo "Generating list..."
SEPARATOR="--------------------------------------------------------------------------------"
(
    $basedir/klist.head.sh

    gpg --homedir $gpghome -q --no-options --fingerprint --list-key |
	grep -v '^sub' |
	perl -npe '$c = sprintf("%03d", ++$C);
	    s/^pub/$c  [ ] Fingerprint OK        [ ] ID OK\npub/m or $C--' |
	grep -v '^uid.*jpeg image of size' |
	sed -e 's/^uid\s*/uid /' |
	sed -e 's/^$/'$SEPARATOR'\n/' |
	tail -n +3
) | perl $basedir/kstats.pl > $basedir/output/keylist.txt

# Generate a tarball too.
echo "Generating tarball"
gpg --homedir $gpghome -q --no-options --armor --export \
    --export-options export-clean | bzip2 > $basedir/output/keyring.asc.bz2

# And a list of hashes - don't publish before the event!
(
    cd $basedir/output
    gpg --print-mds keylist.txt > hashes.txt
)

echo
echo
echo "Don't forget to generate and publish a detached signature too!"
echo "Use: gpg --detach-sign --armor"
echo
echo
echo "Do *not* publish hashes.txt before the event!"
