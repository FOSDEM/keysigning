#!/bin/sh

KEYRING="${1:-keyring.gpg}"
if [ ! -r "$KEYRING" ]; then
	echo "Could not read $KEYRING"
	echo
	echo "Usage: $0 keyring.gpg"
	exit 2
fi

TMPDIR="$( mktemp -d -t ksp-XXXXXXXX )"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup INT TERM

echo "Importing keyring..." >&2
gpg2 --homedir "$TMPDIR" -q --import "$KEYRING"

echo "Exporting text..." >&2
gpg2 --homedir "$TMPDIR" -q --fingerprint --list-key |
	tail -n +3 | # remove keyring name
	perl -pe '
		BEGIN { $C=0; }
		s/\[expired:/uc($&)/e;
		if( m/^pub/ ) {
			print "--------------------------------------------------------------------------------\n\n" unless $C==0;
			printf "%03d  [ ] Fingerprint OK        [ ] ID OK\n", ++$C;
		} elsif( m/^uid/ ) {
			s/^uid\s*(\[[^\]]+\][ \t]+)?/uid  /; # strip [trust]
		} elsif( m/^sub/ ) {
			$_=""; # Do not print
		} elsif( m/^$/ ) {
			$_=""; # Do not print
		}
	'

echo "Done" >&2

cleanup
