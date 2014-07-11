#!/bin/awk -f

BEGIN { outputfile=ARGV[1]; text "" }
/P.Frequency *\-/ { if (text == "") { text = $2 }
		    else { text = text ", " $2 }
	for (i=3; i<NF; i++) {if ($i<0) { text = text ", " $i } }
	}
END { print outputfile " Imaginary frequencies: " text }
