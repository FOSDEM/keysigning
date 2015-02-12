#!/bin/sh

BASEDIR=/var/ksp
KEYDIR=$BASEDIR/keys
OUTDIR=$BASEDIR/output

if [ -d "$OUTDIR" ]; then
	echo "Output directory exists, delete it first" >&2
	exit 2
fi

mkdir -p "$OUTDIR/non-authoritative"

echo "Generating keyring..." >&2
$BASEDIR/bin/keydir-to-keyring.sh "$KEYDIR" > "$OUTDIR/non-authoritative/keyring.gpg"

echo "Generating output formats..." >&2
mkdir "$OUTDIR/non-authoritative/scripts"
cp -r "$BASEDIR/scripts/"* "$OUTDIR/non-authoritative/scripts/"
(
	cd "$OUTDIR/non-authoritative"
	for s in scripts/*; do
		fn="${s##*/}"
		fn="${fn%.*}"
		if [ -f "$s" -a -x "$s" ]; then $s > "$fn"; fi
	done
)
echo "Generating output formats done" >&2

# generate ksp-fosdem2015.txt
(
	"$BASEDIR/templates/keylist-head.sh"

	echo "-----BEGIN KEY LIST-----"
	echo

	cat "$OUTDIR/non-authoritative/keylist.txt"

	echo
	echo "-----END KEY LIST-----"
) > "$OUTDIR/ksp-fosdem$YEAR.txt"

cp "$BASEDIR/templates/README" "$OUTDIR/."
