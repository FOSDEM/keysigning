#!/bin/sh

KEYRING="${1:-keyring.gpg}"
if [ ! -r "$KEYRING" ]; then
	echo "Could not read $KEYRING"
	echo
	echo "Usage: $0 keyring.gpg"
	exit 2
fi

TMPDIR="$( mktemp --tmpdir -d ksp-XXXXXXXX )"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup INT TERM
echo "Using $TMPDIR as temporary GNUPGHOME..." >&2

echo "Importing keyring..." >&2
gpg --homedir "$TMPDIR" -q --import "$KEYRING"

echo "Exporting HTML..." >&2

cat <<EOT
<html>
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8">
  <title>FOSDEM keysigning event keylist</title>
  <style>
   @media print { pre {page-break-inside: avoid;} }
  </style>
 </head>
 <body>
  <pre>
EOT

gpg --homedir "$TMPDIR" -q --fingerprint --list-key |
	tail -n +3 | # remove keyring name
	grep -v '^sub' | # Strip out subkeys
	perl -npe '$c = sprintf("%03d", ++$C);
		s/^pub/$c  [ ] Fingerprint OK        [ ] ID OK\npub/m or $C--' |
	sed -e 's/^uid\s*/uid /' | # Normalize spaces
	sed '$d' | # remove last line to end without a separator
	perl -pe 'BEGIN {
		       use HTML::Entities;
		       binmode STDIN, ":encoding(UTF-8)";
		       binmode STDOUT, ":encoding(UTF-8)";
	       };
	       $_=encode_entities($_, "<>&");' |
	sed -e 's%^$%---------------------------------------------------------------------</pre><pre>\n%' # Add separator

echo "</pre></body></html>"

echo "Done" >&2

cleanup
