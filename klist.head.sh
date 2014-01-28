#!/bin/bash

# Generate klist.head

YEAR="$( date +%Y )"
YEAR_SPACES="$( date +%Y | sed 's/\(.\)/\1 /g' )"
HOMEWORK_BY="$(date --date="next sunday +4 months" +"%A %e %B %Y")"

cat > klist.head <<EOT
                                        --Niels Laukens <niels@fosdem.org>


          F O S D E M   ${YEAR_SPACES}  K E Y S I G N I N G   E V E N T

                            List of Participants


Here's what you have to do with this file:

(0) Verify that the key-id and the fingerprint of your
    key(s) on this list match with your expectation.

(1) Print this UTF-8 encoded file to paper.
    Use e.g. paps(1) from http://paps.sf.net/.

(2) Compute this file's SHA256 and RIPEMD160 checksums.

      gpg --print-md SHA256 ksp-fosdem${YEAR}.txt
      gpg --print-md RIPEMD160 ksp-fosdem${YEAR}.txt

(3) Fill in the hash values on the printout.

(4) Bring the printout, a pen, and proof of identity to
    the keysigning event. (and be on time!).

(5) Make sure that you finish your signing-work at home
    no later than ${HOMEWORK_BY}.  Please.

(6) Check https://fosdem.org/${YEAR}/keysigning for further
    announcements and updates.

(7) Please upload your keys to a reliable keyserver on
    a regular basis so we can make nice statistics!


RIPEMD160 Checksum: _ _ _ _  _ _ _ _  _ _ _ _  _ _ _ _  _ _ _ _

                    _ _ _ _  _ _ _ _  _ _ _ _  _ _ _ _  _ _ _ _             [ ]


SHA256 Checksum:    _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _

                    _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _

                    _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _                        [ ]






EOT
