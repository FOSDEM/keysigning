#!/bin/sh

BASEDIR=/var/ksp
KEYDIR=$BASEDIR/keys
OUTDIR=$BASEDIR/output

YEAR="$( date +%Y )"
HOMEWORK_BY="$(date --date="next sunday +4 months" +"%A %e %B %Y")"

if [ -d "$OUTDIR" ]; then
	echo "Output directory exists, delete it first" >&2
	exit 2
fi

mkdir -p "$OUTDIR/non-authoritative"

echo "Generating keyring..." >&2
$BASEDIR/bin/keydir-to-keyring.sh "$KEYDIR" > "$OUTDIR/non-authoritative/keyring.gpg"

echo "Generating output formats..." >&2
mkdir "$OUTDIR/non-authoritative/scripts"
cp "$BASEDIR/scripts/"* "$OUTDIR/non-authoritative/scripts/"
(
	cd "$OUTDIR/non-authoritative"
	for s in scripts/*; do
		fn="${s##*/}"
		fn="${fn%.*}"
		$s > "$fn"
	done
)
echo "Generating output formats done" >&2

# generate ksp-fosdem2015.txt
(
	YEAR_SPACES="$( echo "$YEAR" | sed 's/\(.\)/\1 /g' )"
	cat <<EOT
                                        --Niels Laukens <niels@fosdem.org>


          F O S D E M   ${YEAR_SPACES}   K E Y S I G N I N G   E V E N T

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

	cat "$OUTDIR/non-authoritative/keylist.txt"

	echo
	echo "-----END KEY LIST-----"
) > "$OUTDIR/ksp-fosdem$YEAR.txt"

cat > "$OUTDIR/README" <<'EOT'
Welcome to the FOSDEM key signing event server.

Here you can download the official key list for the event.  The only
official file is the "ksp-fosdem${YEAR}.txt" file in the root directory.
This will be the file of which the hashes will be compared at the event
itself.

Besides this official list, we also provide non-authoritative files that may
make your life easier.  It is up to you, the participant, to verify that
these files actually contain the same information than the official list:
e.g. for the `keyring.gpg` file, you could run the `keylist.txt.sh` script
and verify that the output similar enough to the official list.  Note that
different GnuPG version may output slightly different output.  In
particular, GnuPG older than version 2.1 uses a different key format [1].

[1] https://www.gnupg.org/faq/whats-new-in-2.1.html#keylist
EOT
