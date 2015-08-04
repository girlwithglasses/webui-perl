package Pathogens::Artemis;

# purpose: routines for dealing with files that have been generated by Artemis

use vars qw(@ISA @EXPORT);
use Exporter;
use Carp;
use strict;

@ISA = qw(Exporter);

@EXPORT = qw(get_colour_from_number get_qualifier_value get_feature_colour);

my %colours = (# white
               "0", "1 1 1",
               # dark grey
               "1", "0.39 0.39 0.39",
               # red
               "2", "1 0 0",
               # green
               "3", "0 1 0",
               # blue
               "4", "0 0 1",
               # cyan
               "5", "0 1 1",
               # magenta
               "6", "1 0 1",
               # yellow
               "7", "1 1 0",
               # pale green
               "8", "0.60 0.98 0.60",
               # light sky blue
               "9", "0.53 0.81 0.98",
               # orange
               "10", "1 0.65 0",
               # brown
               "11", "0.78 0.59 0.39",
               # pink
               "12", "1 0.78 0.78",
               # light grey
               "13", "0.70 0.70 0.70",
               # black
               "14", "0 0 0",
               # reds:
               "15", "1 0.25 0.25",
               "16", "1 0.5 0.5",
               "17", "1 0.75 0.75",
               "999", "0 0 0",
              );

my %key_colour_hash = (
                "CDS", 5,
                "cds?", 7,
                "BLASTCDS", 2,
                "BLASTN_HIT", 6,
                "CRUNCH_D", 2,
                "source", 0,
                "prim_tran", 0,
                "stem_loop", 2,
                "misc_feature", 3,
                "misc_RNA", 12,
                "delta", 3,
                "LTR", 4,
                "repeat_region", 9,
                "repeat_unit", 9,
                "terminator", 3,
                "promoter", 3,
                "intron", 1,
                "exon", 7,
                "mRNA", 1,
                "tRNA", 8,
                "TATA", 3,
                "bldA", 2,
                "GFF", 11);


sub get_qualifier_value
{
  my $feature = shift;
  my $qualifier_name = shift;

  my %feature_hash = %$feature;

  my $return_value = undef;

  for my $qual (@{$feature_hash{qualifierList}}) {
    if ($qual->{name} eq $qualifier_name) {
      $return_value = $qual->{value};
    }
  }
  
  if (defined $return_value) {
    $return_value =~ s/^\s*//;
    $return_value =~ s/\s*$//;
  }
  $return_value;
}

sub get_colour_from_number
{
  my $number = shift;

  $number += 0;               # remove leading zeros
  if (exists $colours{$number}) {
    return $colours{$number};
  } else {
    return undef;
  }
}


# given an Artemis feature return a RGB colour to use to draw it

sub get_feature_colour
{
  my $feature = shift;

  my $number;

  if (ref $feature eq "Bio::PSU::Feature") {
    $number = $feature->colour;
  } else {
    $number = get_qualifier_value ($feature, "colour");
  }

  my $number_colour;

  if (defined $number && 
      defined ($number_colour = get_colour_from_number ($number))) {
    return $number_colour;
  } else {
    # try the default
    if (exists $key_colour_hash{$feature->key ()}) {
      my $key_number = $key_colour_hash{$feature->key ()};

      if (defined $key_number) {
        my $key_colour = get_colour_from_number ($key_number);

        if (defined $key_colour) {
          return $key_colour;
        }
      }
    }
  }
  return "0 0 0";
}
