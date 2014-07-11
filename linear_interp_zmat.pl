#!/usr/bin/perl -w 

use strict;
use warnings;

# Reads an input file with the following format:
#    number_atoms  number_steps  !!! need at least 1 space at start of this line
#   title
#   $DATA1
#   ...
#   $END
#   $DATA2
#   ...
#   $END
# where the $DATA groups are in GAMESS Z-matrix format (COORD=ZMT in $CONTRL)
# and produces number_steps sets of $DATA groups for GAMESS input with
# linearly interpolated coordinates going from $DATA1 to $DATA2.
# Assumes C1 symmetry for the $DATA groups.
# Outputs geometries to linear_interp.out
#
# MAKE SURE THE INTERNAL COORD are exactly the same for both $DATA groups
# i.e. all bond, angles, and dihedrals are defined by the same atoms (& same order)
#
# execute with ./lininterp_zmat input_file
# output goes to input_file.out

my ($natoms,$nsteps,$line,$title,$i,$j);
my (@len1,@ang1,@dih1,@len2,@ang2,@dih2,@lenstep,@angstep,@dihstep);
my ($len_new,$ang_new,$dih_new);
my (@atoms,@nlen,@nang,@ndih,@line);
my $input = $ARGV[0];

open (INP, "$input");

$line = <INP>;
($_,$natoms,$nsteps) = split('\s+',$line);
$title = <INP>;
chomp $title;

while (<INP>) {
  if (/DATA1/) {
    <INP>;<INP>;
    for $i (1..$natoms) {
      $line = <INP>;
      @line = split('\s+',$line);
      ($atoms[$i],$nlen[$i],$len1[$i],$nang[$i],$ang1[$i],$ndih[$i],$dih1[$i]) = @line;
      ($ndih[$i],$dih1[$i]) = (0,0) if ($i<4);
      ($nang[$i],$ang1[$i]) = (0,0) if ($i<3);
      ($nlen[$i],$len1[$i]) = (0,0) if ($i<2);
    }
  }
  if (/DATA2/) {
    <INP>;<INP>;
    for $i (1..$natoms) {
      $line = <INP>;
      @line = split('\s+',$line);
      ($len2[$i],$ang2[$i],$dih2[$i]) = ($line[2],$line[4],$line[6]);
      $dih2[$i] = 0 if ($i<4);
      $ang2[$i] = 0 if ($i<3);
      $len2[$i] = 0 if ($i<2);
       
      $lenstep[$i] = ($len2[$i]-$len1[$i])/($nsteps+1);
      $angstep[$i] = ($ang2[$i]-$ang1[$i])/($nsteps+1);
      $dihstep[$i] = ($dih2[$i]-$dih1[$i])/($nsteps+1);
    }
  }
}

open (OUT, ">$input.out");

for $i (1..$nsteps) {
  print OUT " \$DATA\n$title step $i\nC1\n";
  for $j (1..$natoms) {
    $len_new = $len1[$j] + $i*$lenstep[$j];
    $ang_new = $ang1[$j] + $i*$angstep[$j];
    $dih_new = $dih1[$j] + $i*$dihstep[$j];
    print OUT "$atoms[$j]\n" if ($j == 1);
    print OUT "$atoms[$j] $nlen[$j] $len_new\n" if ($j == 2);
    print OUT "$atoms[$j] $nlen[$j] $len_new $nang[$j] $ang_new\n" if ($j == 3);
    print OUT "$atoms[$j] $nlen[$j] $len_new $nang[$j] $ang_new $ndih[$j] $dih_new\n" if ($j>3);
  }
  print OUT " \$END\n";
}

close OUT;
close INP;
