#!/usr/bin/perl -w

# Generate a bar graph for interaction energy of a given fragment with
# a set of others.

# Uses Gnuplot.

use strict;
# some magic to have basedir($0)/perlmod in Perl module path
use File::Basename qw();
use lib File::Basename::dirname($0).'/perlmod';

use local::FMO::ReadPieda;

sub Help {
  my $msg=shift;
  die <<"EOF";
$msg
Usage:
$0 --frag[ment] frg --fmo[input] fmo.out --out[put] outfile \
   [--en[ergy] en1:en2:....] [--nei[ghbors]] \
   [--thresh[old] thr] [--every m:n] \
   [--showtot[=thr]] \
   [--map mapfile.txt] \
   [--revmap] \
   [fragments....]
where:
  --fragment: what fragment to interact with
  --fmoinput: where to read FMO from
  --output: the basename for the output files
  --energy: energy contributions (default ETOT, possible: @{[local::FMO::ReadPieda->fields()]})
  --neighbors: include neighbor contributions (default don't)
  --threshold: label only fragments with contributions above threshold
               (default 0)
  --every m:n : label fragments frg: (frg%m)==n (default 5:0)
  --showtot[=thr] : show the total energy above threshold thr (default 0) as vertical lines
  --oldcolors : use old (dynamically assigned) colors
  --nonegcolors | --nonc : make the "negative" colors the same as positive
  --notitles : do not put labels on axes
  --map : perform mapping of the input fragment numbers according to the mapfile.txt [see below] prior to plotting
  --revmap : first reverse-map the input arguments based on the mapping file given in --map
  fragments: the other fragments to interact with (default all)

  The mapping file is used to map between, e.g., "crystal" and "equilibrated" (1-based) fragment numbering;
  *** it affects only plot labelling, not energies! ***  and has the format:
   # comment
   input_fragment_number  fragment_number_on_the_plot
   ...
EOF
}

my ($fmo_log,$threshold,$showtot,$toten_thr,$every,$ekeys,$oldcolors,$nonc,$notitles,
    $frag1,$outbase,$nei,$mapfile,$revmapflag,@other_frags_arg);

# For documentation purposes:
my $cmdline="$0 ".join(" ",map {"'$_'"} @ARGV);

# Parsing arguments
while (@ARGV) {
  my $opt=shift(@ARGV);
  if ($opt!~/^--/) { push @other_frags_arg,$opt; next; }
  $opt=~s/^--//;
  if ($opt=~/^frag(ment)?$/) { $frag1=shift(@ARGV); next; }
  if ($opt=~/^fmo(input)?$/) { $fmo_log=shift(@ARGV); next; }
  if ($opt=~/^out(put)?$/) { $outbase=shift(@ARGV); next; }
  if ($opt=~/^en(ergy)?$/) { $ekeys=shift(@ARGV); next; }
  if ($opt=~/^nei(ghbors)?$/) { $nei=1; next; }
  if ($opt=~/^thresh(old)?$/) { $threshold=shift(@ARGV); next; }
  if ($opt=~/^every$/) { $every=shift(@ARGV); next; }
  if ($opt=~/^showtot(=(\S+))?$/) { $showtot=1; $toten_thr=defined($2)?($2+0):0; next; }
  if ($opt=~/^oldcolors$/) { $oldcolors=1; next; }
  if ($opt=~/^nonegcolors$/ or $opt=~/^nonc$/) { $nonc=1; next; }
  if ($opt=~/^notitles$/) { $notitles=1; next; }
  if ($opt=~/^map$/) { $mapfile=shift(@ARGV); next; }
  if ($opt=~/^revmap$/) { $revmapflag=1; next; }
  Help("Unknown option '$opt'");
}

# Check missing, set defaults
Help("No fmo file given") if !defined($fmo_log);
Help("No 1st fragment given") if !defined($frag1);
Help("No output base name given") if !defined($outbase);
Help("--revmap options requires --map option") if (defined($revmapflag) && !defined($mapfile));

$ekeys=':' if !defined($ekeys);
$showtot=0 if !defined($showtot);
$threshold=0 if !defined($threshold);
$oldcolors=0 if !defined($oldcolors);
$nonc=0 if !defined($nonc);
$notitles=0 if !defined($notitles);
my ($every1,$every2)=(5,0);
if ($every && $every=~/(\d+)(:(\d+))?/) {
  $every1=$1;
  $every2=$3||0;
}

my $fmo=local::FMO::ReadPieda->read($fmo_log);
my @dist=$fmo->distance();

my @ekeys=split /:/,$ekeys;
@ekeys=sort grep {/^E/&&!/^ETOT/} $fmo->fields() if !@ekeys;

# my %ecolor;
# my ($h,$s,$b)=(10,1,1);
# for my $k (@ekeys) {
#   $ecolor{$k}=local::BarJGraph->hsv($h,$s,$b);
#   $h+=50;
# }

my %ecolor;
if ($oldcolors) {
  my @keys=qw(ETOT EES EEX ECT EDISP EDIMER EDPOL);
  my $n=@keys;
  for (my $i=0; $i<$n; $i++) {
    $ecolor{POS}{$keys[$i]}="palette frac ".((2*$n-$i)/(2*$n));
    $ecolor{NEG}{$keys[$i]}="palette frac ".($i/(2*$n));
  }
  $ecolor{POS}{UNKNOWN}="rgbcolor '#AAAAAA'";
  $ecolor{NEG}{UNKNOWN}="rgbcolor '#444444'";
} else { # "new" distinct colors:
  if ($nonc) { # no negative colors
    %ecolor=(
             POS=>{
                   EES    =>  "rgbcolor '#803E75'",
                   ECT    =>  "rgbcolor '#A6BDD7'",
                   EDISP  =>  "rgbcolor '#CEA262'",
                   EEX     => "rgbcolor '#F13A13'",
                   EDPOL  =>  "rgbcolor '#007D34'",
                   # the following 3 contributions are rarely, if ever, used with others
                   ETOT    => "rgbcolor '#FF0000'",
                   EDIMER  => "rgbcolor '#AAAA00'", # FIXME: dark yellow?
                   UNKNOWN => "rgbcolor '#AAAAAA'",
                  }
            );
    $ecolor{NEG}=$ecolor{POS};
  } else { # distinct positive and negative colors
    %ecolor=(
             POS=>{
                   EES     => "rgbcolor '#FFB300'",
                   ECT     => "rgbcolor '#FF6800'",
                   EDISP   => "rgbcolor '#C10020'",
                   EEX     => "rgbcolor '#F13A13'",
                   EDPOL   => "rgbcolor '#FF7A5C'",
                   # the following 3 contributions are rarely, if ever, used with others
                   ETOT    => "rgbcolor '#FF0000'",
                   EDIMER  => "rgbcolor '#AAAA00'", # FIXME: dark yellow?
                   UNKNOWN => "rgbcolor '#AAAAAA'",
                  },
             NEG=>{
                   EES    =>  "rgbcolor '#803E75'",
                   ECT    =>  "rgbcolor '#A6BDD7'",
                   EDISP  =>  "rgbcolor '#CEA262'",
                   EEX    =>  "rgbcolor '#00538A'",
                   EDPOL  =>  "rgbcolor '#007D34'",
                   # the following 3 contributions are rarely, if ever, used with others
                   ETOT   =>  "rgbcolor '#0000FF'",
                   EDIMER =>  "rgbcolor '#00FF00'",
                   UNKNOWN => "rgbcolor '#444444'",
                  },
            );
  } # endif (distinct positive/negative)
} # endif (new distinct colors)

my $nfrags=$fmo->size();

if ($frag1<1 || $frag1>$nfrags) {
  die "Frag1=$frag1 is out of range.\n";
}

# Process the mapfile (if any), prepare the map
my %fragmap=();
my %revfragmap=();
if (defined($mapfile)) {
  open(my $fd,"<$mapfile") || die "Can't open mapfile '$mapfile': $!\n";
  while (<$fd>) {
    next if /^\s*#/ || /^\s*$/; # skip comments and empty lines
    chomp;
    my ($input_fg,$plot_fg)=split " ",$_;
    $input_fg+=0;
    $plot_fg+=0;
    if ($input_fg<=0 || $plot_fg<=0 || $input_fg>$nfrags || $plot_fg>$nfrags) {
      die "Wrong format (0-based? not a number? out of range?) in '$mapfile' -- stopped";
    }
    die "Duplicate mapping $input_fg -> $plot_fg\n" if exists $fragmap{$input_fg-1};
    $fragmap{$input_fg-1}=$plot_fg-1;
    $revfragmap{$plot_fg-1}=$input_fg-1;
  }
  close($fd);
  for (1..$nfrags) {
    die "No mapping for $_\n" if !exists $fragmap{$_-1};
  }
#  if (!%fragmap) {
#    warn "WARNING: The mapfile '$mapfile' looks empty??\n";
#  }
}


my @other_frags;
foreach my $f (@other_frags_arg) {
  my @ff;
  if ($f=~/^(\d+)-(\d+)$/) {
    push @ff, ($1..$2);
  } elsif ($f=~/^(\d+)-$/) {
    push @ff, ($1..$nfrags);
  }
  else {
    push @ff,$f;
  }
  for (@ff) {
    if ($_<1 or $_>$nfrags) {
      warn("Fragment $_ is out of range, skipped.\n");
      next;
    }
    push @other_frags,($_-1);
  }
}
$frag1--;
@other_frags=(0..$nfrags-1) if (!@other_frags);

if ($revmapflag) { # reverse-map input fragment numbers
  @other_frags = @revfragmap{@other_frags};
  $frag1=$revfragmap{$frag1};
  for (@other_frags,$frag1) {
    die "Undefined fragments after reverse mapping: check mapping file!\n" if !defined($_);
  }
  print STDERR "DEBUG: rev-mapped 0-based input fragments are: $frag1 vs. @other_frags\n";
}

# Sort according to the mapping, if given:
if (%fragmap) {
  @other_frags=sort { (exists($fragmap{$a})?$fragmap{$a}:$a) <=> (exists($fragmap{$b})?$fragmap{$b}:$b) } @other_frags;
} else {
  @other_frags=sort {$a<=>$b} @other_frags;
}
# Detect "seam" fragments, that is, "5" and "7" in "1-5,7-10..."
# take mapping into account!
my %seams;
for (my $i=1; $i<@other_frags-1; $i++) {
  # labels for this fragment and its neighbors:
  my ($left,$this,$right)=map {exists($fragmap{$_})?$fragmap{$_}:$_} @other_frags[$i-1,$i,$i+1];
  if ($this!=$left+1) { $seams{$other_frags[$i]}=$i-0.5; }
  if ($this!=$right-1) { $seams{$other_frags[$i]}=$i+0.5; }
}

#Keep relevant energy contributions in array @{$energy{$ekey}}.
#That is, the length of the array is the same as @other_frags,
#and $energy{$ekey}[$i] is the energy for $other_frags[$i].
my %energy;
for my $k (@ekeys,'ETOT') {
  my @en=$fmo->energy($k);
  if (!@en) {
    warn("Energy contribution $k is absent, skipped.\n");
    next;
  }
  $energy{$k}=[@{$en[$frag1]}[@other_frags]];
}
@ekeys=grep {exists $energy{$_}} @ekeys; # leave only valid ekeys

# Plot command for GNUPLOT
my $plot_cmd="";
for (my $i=0; $i<@ekeys; $i++) {
  my $key=$ekeys[$i];
  $plot_cmd.=($i==0)?"plot dataname ":', "" ';
  my $c=$i+2;
  my $lc='lc '.($ecolor{POS}{$key}||$ecolor{POS}{UNKNOWN});
  my $col="((\$$c>=0)?\$$c:0)";
  #  $col.=':xtic(1)' if ($i==0);
  $plot_cmd.="us $col $lc  title ";
  $plot_cmd.=($nonc)?"'$key'":"'$key positive'";
  $col="((\$$c<0)?\$$c:0)";
  $lc='lc '.($ecolor{NEG}{$key}||$ecolor{NEG}{UNKNOWN});
  $plot_cmd.=", '' us $col $lc title ";
  $plot_cmd.=($nonc)?"''":"'$key negative'";
}

# Prepare data, do some analysis
my $data='';
my @toten;
my @xtics;
my $frag1_idx; # index of the $frag1, if present
for (my $i=0; $i<@other_frags; $i++) {
  my $frg=$other_frags[$i];
  my $frglabel=exists($fragmap{$frg})?$fragmap{$frg}:$frg;

  $frag1_idx=$i if $frag1==$frg; # is the reference fragment on the plot?

  $data.= "#".($frg+1);
  # bar if not diagonal and (neighbors ok or not a neighbor)
  my $has_bar=
    defined($dist[$frag1][$frg])
      &&  ($nei || $dist[$frag1][$frg]!=0);

  my $above_thr;
  for my $k (@ekeys) {
    my $y=($has_bar)?$energy{$k}[$i]:0;
    $data.= " $y";
    $above_thr=1 if abs($y)>=$threshold;
  }
  if ( $showtot && $has_bar && (abs(my $e=$energy{ETOT}[$i])>$toten_thr) ) {
    push @toten,[ $i, $e ];
  }
  my $xlabel=(($frg==$frag1)||(exists $seams{$frg})||($above_thr && (($frglabel+1) % $every1 == $every2)))?
    ($frglabel+1) : '';
  push @xtics,"'$xlabel' $i";
  $data.="\n";
}

# form proper xtics command:
my $xtics=(@xtics)? ("set xtics (".join(",",@xtics).")") : '';

# Marking of the $frag1
my $mark_frag='';
if (defined($frag1_idx)) {
  $mark_frag="set arrow 1 from ".($frag1_idx).",0 rto 0,character -3 backhead";
}

# Marking of the seams:
my $seams='';
{
  my $i=10;
  while (my ($frag,$x)=each %seams) {
    $seams.= "set arrow $i from first $x, graph 0 rto 0, graph 1 nohead lt 2 lw 4 lc rgbcolor '#000000'\n";
    $i++;
  }
}

# Marking of the total energy:
my $totens='';
for (my $i=0; $i<@toten; $i++) {
  my ($x,$y)=@{$toten[$i]};
  $totens.= "set arrow ".(100+$i)." from first $x,0 rto 0,$y nohead lw 3 front\n";
}

my $titles=$notitles?"":<<"EOF";
set xlabel "Fragment Index"
set ylabel "Energy in kcal/mol"
EOF

# GNUPLOT output, main script
my $gpfile=$outbase.".gnuplot";
open(OUTFILE,">$gpfile") || die "Cannot open '$gpfile': $!\n";
print OUTFILE <<"EOF";
#!/usr/bin/gnuplot
myname='$gpfile'
epsname='$outbase.eps'
pngname='$outbase.png'
barwidth=0.75

dataname="<sed -ne '/^##GNUPLOTDATA/,\$ s/^#//p' ".myname
set style data hist
set style hist rows
set style fill solid noborder
set boxwidth barwidth relative

set key out

set palette rgbformulae 33,13,10
unset colorbox
unset arrow

# set colors
# put labels, titles, whatever
$titles

# X-Tics (if any)
set ytics nomirror
unset xtics
set xtics nomirror
$xtics

# Total energies (if requested):
$totens

# Mark the reference fragment, if present
$mark_frag

# Mark seams:
$seams

# Mark x-axis
set arrow 2 from graph 0, first 0 to graph 1, first 0 nohead

# Plotting
$plot_cmd

# Postscript output
set term push
set term post eps color enh size 8,4 "Helvetica, 20"
set out epsname
replot
set out
set term pop
system("convert -units PixelsPerInch -density 300x300 $outbase.eps $outbase.png")

##The command line was:
##$cmdline
##GNUPLOTDATA
$data
EOF

close(OUTFILE);
