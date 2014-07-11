#!/usr/bin/perl -wc

use strict;

use IO::File;

# Reads PIEDA information from GAMESS-formatted output (made by Facio)

=pod

Usage:

use local::FMO::ReadPieda;

my $obj=FMO::ReadPieda->read(\*FILE);
my $obj=FMO::ReadPieda->read($filename);

my @energy_total=$obj->energy(); # returns reference a copy
my @distances=$obj->distance(); # returns reference a copy

$interaction_ij=$energy_total[$ifrag][$jfrag]; # symmetrical, with undef on the diagonal

=cut

package local::FMO::ReadPieda;

# Forward declarations for a few internal subs:

sub _copy_field;
sub _check_array;

# Contents of PIEDA analysis columns:
my %PiedaCol=(
               DISTANCE => 4,   # the interfragment distance relative to van-der-Waals radii, -1 if not known
               EDIMER => 6,     # EIJ-EI-EJ
               EDPOL => 7,      # dDIJ*VIJ: density polarisation contribution
               ETOT => 8,       # total
               EES => 9,        # Ees [electrostatic??]
               EEX => 10,       # Eex [exchange??]
               ECT => 11,       # Ect+mix [charge transfer??]
               EDISP=>12,       # Edisp [dispersion??]
               QIJ => 5,        # Q(I->J) is the charge transfer amount, printed as zero if not available,
                                #   Positive values correspond to I in IJ having extra negative charge
              );

# Constructor:

sub read { # ($class, $fn_or_fd --> $obj)
  my $self=shift;
  my $class=ref($self)||$self;
  my $fd=shift;
  my $fn;
  if (!ref($fd)) {
    $fn=$fd;
    $fd=IO::File->new;
    $fd->open($fn) || die "Cannot open '$fn': $!\nStopped";
  }

  my %fld=();
  my %pieda_col=%PiedaCol; # local copy of the table of possible contributions (we may remove dispersion later)
  while (<$fd>) {
    tr/\r\n//d;
    # search for the header, and process till the empty line
    if (my $ln=(/I *J *DL *Z *R *Q\(I\-\>J\) *EIJ-EI-EJ *dDIJ\*VIJ *total *Ees *Eex *Ect\+mix( *Edisp)?/../^ *$/)) {
      if ($ln==1 && !$1) { # if there's no dispersion in the header...
        delete $pieda_col{EDISP}; # ... do not expect dispersion contribution.
        next;
      }
      next if !/^ *\d/; # skip whatever does not start with a digit

      my @f=split " ",$_;
      my ($i,$j)=@f[0,1];
      $i--; $j--;
      while (my ($ck,$cv)=each %pieda_col) {
        $fld{$ck}[$i][$j]=$fld{$ck}[$j][$i]=$f[$cv];
      }
    }
  }
  $fd->close() if defined($fn);

  # Checking that all pairs are there:
  my $size=@{$fld{DISTANCE}};
  die "Could not read anything!\n" if !$size;
  foreach my $ck (keys %pieda_col) {
    $fld{$ck}[$size-1][$size-1]=undef;
    _check_array($fld{$ck},$size,$ck);
  }

  my $newobj={FIELDS=>\%fld, SIZE=>$size};

  return bless($newobj,$class);
}

# WARNING: not a method! to be called directly rather than via OO syntax
sub _copy_field { # ($obj,$field_name --> $2d_array_copy_ref)
  my $obj=shift;
  my $name=shift;

  return [ map { [@$_] } @{$obj->{FIELDS}{$name}} ];
}

sub _check_array { # ($2d_arr_ref,$expected_size,$arr_name)
  my $arr=shift;
  my $size=shift;
  my $name=shift;

  my $n=@$arr;
  warn "Array $name has wrong size ($size expected, $n found)!\n" if $size!=$n;
  for (my $i=0; $i<$n; $i++) {
    my $row=$arr->[$i];
    warn "Row $i of $name array is missing!\n" if !$row;
    my $rowlen=@$row;
    warn "Row $i of $name has incorrect length ($n expected, $rowlen found)!\n" if ($n!=$rowlen);
    for (my $j=0; $j<$rowlen; $j++) {
      warn "Element ($i,$j) of $name array is missing!\n" if ($i!=$j) && !defined($row->[$j]);
    }
  }
}

# Total energy or other named field accessor:
sub energy { ## energy() or energy('EES'); empty argument means 'total energy'; returns empty array if not found
  my $self=shift;
  my $nm=shift||'ETOT';
  return () if !exists $self->{FIELDS}{$nm};
  return @{_copy_field($self,$nm)};
}

# Distance accessor:
sub distance {
  my $self=shift;
  return @{_copy_field($self,'DISTANCE')};
}


# Size accessor:
sub size {
  my $self=shift;
  return $self->{SIZE};
}

# List of fields accessor (all possible fields as a class method, actual fileds as an object method)
sub fields { # ( --> @fields)
  my $self=shift;
  if (!ref($self)) {
    return keys %PiedaCol;
  } else {
    return keys %{$self->{FIELDS}};
  }
}

1;
