#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 keys-dir/"
	exit 64 # EX_USAGE
fi

KEYS="$1"

if [ -t 1 ]; then
	echo "Refusing to output to stdout, please redirect" >&2
	exit 1
fi
if [ ! -d "$KEYS" ]; then
	echo "$KEYS is not a directory" >&2
	exit 1
fi
 
TMPDIR="$( mktemp --tmpdir -d ksp-XXXXXXXX )"
cleanup() {
        rm -rf "$TMPDIR"
}
trap cleanup INT TERM
echo "Using $TMPDIR as temporary GNUPGHOME..." >&2

printf "Importing keys...\r" >&2
N=$( ls -1 "$KEYS" | wc -l )
i=0
for key in $(ls -1tr "$KEYS"); do
    i=$(( $i + 1 ))
    # Skip files starting with !.
    [ "x${key%!*}" = "x" ] && continue
    printf "Importing keys $i/$N\r" >&2
    gpg --homedir "$TMPDIR" -q --import-options import-minimal --import "$KEYS/$key"
done
printf "                                   \r" >&2
echo "$N keys imported" >&2
gpg --homedir "$TMPDIR" -q --export

cleanup
