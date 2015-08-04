package Pathogens::Embl;

# $Header: /scratch/svn-conversion/img_dev/v2/webUI/webui.cgi/psu_diagram/lib/Pathogens/Embl.pm,v 1.1 2013-03-27 20:41:20 jinghuahuang Exp $

# purpose: Routines for handling EMBL entries (for use with the Sanger EMBL
# purpose: modules)

use vars qw(@ISA @EXPORT);
use Exporter;
use Carp;
use strict;

use Range;

@ISA = qw(Exporter);
@EXPORT = qw(get_exon_ranges);

# returns an array containing a complement flag and then a Range for each exon
# ie. for the location "join(complement(1..100),complement(200..400))" the
# return array will be (1, new Range (1,100), new Range (200,400))
sub get_exon_ranges
{
  my $location = shift;

  my @return_vector = ();

  my $complement_flag = 0;

  if ($location =~ s/complement\(([^\)]+)\)/$1/g) {
    $complement_flag = 1;
  }

  $location =~ s/join\(([^\)]*)\)/$1/g;

  my @join_bits = split (',',$location);

  # sort the join ranges into ascending order
  @join_bits =
  sort {
    my ($astart) = $a =~ /^\s*(\d+)/;
    my ($bstart) = $b =~ /^\s*(\d+)/;
    $astart <=> $bstart;
  } @join_bits;

  for (my $i = 0 ; $i < @join_bits ; ++$i) {
    my $exon_range = $join_bits[$i];

    my $start_of_exon;
    my $end_of_exon;

    if ($exon_range =~
        m/<?(\d+)
          (?:\.\.
           >?
           (\d+))?/x) {

      $start_of_exon = $1;
      if (defined $2) {
        $end_of_exon = $2;
      } else {
        $end_of_exon = $1;
      }

      if ($start_of_exon > $end_of_exon) {
        ($start_of_exon, $end_of_exon) = ($end_of_exon, $start_of_exon);
      }

      push @return_vector, new Range ($start_of_exon, $end_of_exon);
    }
  }

  if ($complement_flag) {
    return ($complement_flag,reverse @return_vector);
  } else {
    return ($complement_flag,@return_vector);
  }
}
