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
for key in $(ls -1tr $basedir/keys); do
    # Skip files starting with !.
    [ "x${key%!*}" = "x" ] && continue
    gpg --homedir $gpghome -q --import $basedir/keys/$key
done

# Print each key neatly into the keylist.
(
    sh $basedir/klist.head

    gpg --homedir $gpghome -q --no-options --fingerprint --list-key |
	grep -v '^sub' |
	perl -npe '$c = sprintf("%03d", ++$C);
	    s/^pub/$c  [ ] Fingerprint OK        [ ] ID OK\npub/m or $C--' |
	grep -v '^uid.*jpeg image of size' |
	sed -e 's/^uid\s*/uid /' |
	sed -e 's/^$/--------------------------------------------------------------------------------\n/' |
	tail -n +3
) | perl $basedir/kstats.pl > $basedir/output/keylist.txt

# Generate a tarball too.
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
