#!/usr/bin/perl

# Takes a GAMESS $DATA group in cartesian coord and
# outputs a $DATA group in ZMAT format
#
# Execute with ./cart2zmat_gamess.pl $file.zmat
# Will output to $file.zmat
#
# Makes use of modules from PerlMol collection (available at perlmol.org or cpan.org)
# so you need to have these modules in your main CPAN directory, or modify the 
# 'use lib' line below to add a directory which includes them to @INC.

use strict;
use warnings;
use lib join('/',$ENV{"NX"},"CPAN") ; # will require customization on your machine
use Chemistry::InternalCoords::Builder 'build_zmat';
use Chemistry::File::XYZ;
use Chemistry::File::InternalCoords;

my ($file,$ct,$chk,$line);
my (@coords);

$file = $ARGV[0];

open(INP, "$file");
open(TMP, ">coord.tmp");
open(XYZ, ">$file.xyz");
open(OUT, ">$file.zmat");

# Create .xyz file with cartesian coords
$ct = 0;
while (<INP>) {
  if (/[\w]+[\s]+[\d]+[\.]?[\d]*[\s]+-?[\d]?/) {
    s/^[\s]+//;
    @coords = split('\s+',$_);
    $ct++;
    $coords[0] = ucfirst("$coords[0]");
    print TMP "$coords[0]  $coords[2]  $coords[3]  $coords[4]\n";
  }
}

print XYZ " $ct\n\n";
system("cat coord.tmp >> $file.xyz");
system("rm coord.tmp");

close INP;
close TMP;
close XYZ;

# Read .xyz file and create Z-matrix
my $mol = Chemistry::Mol->read("$file.xyz");

$mol->write("zmat.tmp", format => 'zmat');

## Comment the following line out if you want to keep an .xyz file of the cartesian coords
system("rm $file.xyz");
##

# Recreate $DATA group with zmat coords    
open(INP, "$file");
open(ZMT, "zmat.tmp");
$chk = 0;
while (<INP>) {
  $chk = 1 if (/DATA/);
  next if ($chk && /[\w]+[\s]+-?[\d]+[\.]?[\d]*[\s]+-?[\d]+/);
  if ($chk && /END/) {
    while ($line = <ZMT>) {
      print OUT "$line";
    }
  }
  print OUT "$_";
}
system ("rm zmat.tmp");

close INP;
close OUT;
