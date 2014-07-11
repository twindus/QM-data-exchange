#!/usr/bin/awk -f
#Script to extract coordinates from NWChem output files

BEGIN { begin = ""; text = "" }

/Transition State Search/ { save = 1 ; geom = 0 }
/Analytic Hessian/ { save = 0 }
/Finite-difference Hessian/ { save = 0 }
/Energy Minimization/ { save = 1 ; geom = 0 }
/NWChem Geometry Optimization/ { save = 1; geom = 0}

/^ ---- ---------------- ---------- -------------- -------------- --------------$/ {
    geom = geom + 1;
    if (save == 1 && (geom == desired_geometry || desired_geometry == "")) {
	text = "";
	begin = "";
    }
}



/^ +[0-9]+ +[A-Z][a-z]* +[0-9]+\.[0.9]+ +\-*[0-9]+\.[0-9]+ +\-*[0-9]+\.[0-9]+ +\-*[0-9]+\.[0-9]+ *$/ {
    if (save == 1 && (geom == desired_geometry || desired_geometry == "")) {
			text = text begin "  " $2 "  " $4 "  " $5 "  " $6 "" ;
			begin ="\n"
     			}
}

END { print text }
