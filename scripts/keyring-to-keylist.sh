#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 keyring.gpg"
	exit 64 # EX_USAGE
fi
KEYRING="$1"

TMPDIR="$( mktemp --tmpdir -d ksp-XXXXXXXX )"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup INT TERM
echo "Using $TMPDIR as temporary GNUPGHOME..." >&2

echo "Importing keyring..." >&2
gpg --homedir "$TMPDIR" -q --import "$KEYRING"

echo "Exporting keylist..." >&2
gpg --homedir "$TMPDIR" -q --fingerprint --list-key |
	tail -n +3 | # remove keyring name
	grep -v '^sub' | # Strip out subkeys
	perl -npe '$c = sprintf("%03d", ++$C);
		s/^pub/$c  [ ] Fingerprint OK        [ ] ID OK\npub/m or $C--' |
	sed -e 's/^uid\s*/uid /' | # Normalize spaces
	sed '$d' | # remove last line to end without a separator
	sed -e 's/^$/--------------------------------------------------------------------------------\n/' # Add separator
	

echo "Done" >&2

cleanup
