#!/bin/sh

BASEDIR=/var/ksp
KEYDIR=$BASEDIR/keys
OUTDIR=$BASEDIR/output

YEAR="$( date +%Y )"
YEAR_SPACES="$( date +%Y | sed 's/\(.\)/\1 /g' )"
HOMEWORK_BY="$(date --date="next sunday +4 months" +"%A %e %B %Y")"


if [ -d "$OUTDIR" ]; then
	echo "Output directory exists, delete it first" >&2
	exit 2
fi

mkdir "$OUTDIR"

echo "Generating keyring..." >&2
$BASEDIR/bin/keydir-to-keyring.sh "$KEYDIR" > "$OUTDIR/keyring.gpg"

# generate ksp-fosdem2015.txt
(
	cat <<EOT
                                        --Niels Laukens <niels@fosdem.org>


          F O S D E M   ${YEAR_SPACES}  K E Y S I G N I N G   E V E N T

                            List of Participants


Here's what you have to do with this file:

(0) Verify that the key-id and the fingerprint of your key(s) on this list
    match with your expectation.

(1) Print this UTF-8 encoded file to paper.
    Use e.g. paps(1) from http://paps.sf.net/.

(2) Compute this file's RIPEMD160 and SHA256 checksums.

      gpg --print-md RIPEMD160 ksp-fosdem${YEAR}.txt
      gpg --print-md SHA256 ksp-fosdem${YEAR}.txt

(3) Fill in the hash values on the printout.

(4) Bring the printout, a pen, and proof of identity to the keysigning event.
    You may find it useful to make a badge stating the number(s) of your key(s)
    on this list and the fact that you verified the fingerprints of your own
    key(s).  Also provide a place to mark that your hashes match.  Be on time
    to actually verify the hashes as they are announced!
    e.g.
       +----------------------------+
       | I am number 001            |
       | My key-id & fingerprint: ☑ |
       | The hashes:              ☐ |
       +----------------------------+

(5) Make sure that you finish your signing-work at home no later than
    ${HOMEWORK_BY}.  Please.

(6) Check https://fosdem.org/${YEAR}/keysigning for further announcements and
    updates.

(7) Please upload your keys to a reliable keyserver on a regular basis so we
    can make nice statistics!


RIPEMD160 Checksum: __ __ __ __  __ __ __ __  __ __ __ __  __ __ __ __

                    __ __ __ __  __ __ __ __  __ __ __ __  __ __ __ __

                    __ __ __ __  __ __ __ __                               [ ]


SHA256 Checksum:    __ __ __ __ __ __ __ __  __ __ __ __ __ __ __ __

                    __ __ __ __ __ __ __ __  __ __ __ __ __ __ __ __

                    __ __ __ __ __ __ __ __  __ __ __ __ __ __ __ __

                    __ __ __ __ __ __ __ __  __ __ __ __ __ __ __ __       [ ]



EOT
	echo "-----BEGIN KEY LIST-----"
	echo

	$BASEDIR/scripts/keyring-to-keylist.sh "$OUTDIR/keyring.gpg"

	echo
	echo "-----END KEY LIST-----"
) > "$OUTDIR/ksp-fosdem$YEAR.txt"
