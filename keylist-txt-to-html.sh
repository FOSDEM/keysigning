#!/bin/bash

printf '<html><head><meta http-equiv="Content-Type" '
printf 'content="text/html;charset=UTF-8"><title>'
printf 'FOSDEM keysigning event keylist</title><style>'
printf '@media print { pre {page-break-inside: avoid;} }'
printf '</style></head><body><pre>'
perl -pe 'BEGIN {
		use HTML::Entities;
		binmode STDIN, ":encoding(UTF-8)";
		binmode STDOUT, ":encoding(UTF-8)";
	};
	$_=encode_entities($_, "<>&");
	s%--------------------------------------------------------------------------------%---------------------------------------------------------------------</pre><pre>%
	'
echo "</pre></body></html>"
