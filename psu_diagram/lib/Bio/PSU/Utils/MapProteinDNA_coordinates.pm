package Bio::PSU::Utils::MapProteinDNA_coordinates;

use strict;
use Data::Dumper;
use Carp;

use Bio::PSU::Range;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my $self     = {
		  sp_start => undef,
		  sp_end   => undef,
		  protein_length => undef,
		  gene_ranges    => undef,
		  @_,
		 };
  bless ($self, $class);
  return $self;
}

# mapping Protein => DNA coordinates

sub mapRange {
  my $self = shift;
  my $sp_start = $self->{sp_start};
  my $sp_end   = $self->{sp_end};
  my $protein_length = $self->{protein_length};
  my @ranges   = @{$self->{gene_ranges}};

  my $sp_start_origin = $sp_start;
  my $sp_end_origin   = $sp_end;
  my $strand = getStrand (@ranges);
  if ($strand == -1) {
    # + 1 to include the stop codon
    my $sp_start_tmp = $protein_length - $sp_end   + 1;
    $sp_end          = $protein_length - $sp_start + 1;
    $sp_start        = $sp_start_tmp;
  }
  $sp_start = 3 * ($sp_start - 1);
  $sp_end   = 3 * ($sp_end - 1);

  my $new_sp_start = -1;
  my $new_sp_end   = -1;
  my @new_ranges   = ();
  
  my $i = 0;
  my $found = 0;
  while ((not $found) && ($i<@ranges)) {
    my $range_start = $ranges[$i];
    if (is_in_range ($sp_start, $range_start)) {
      $new_sp_start = $range_start->start + $sp_start;

      # found the start location on the current exon, find the stop location now

      if (is_in_range ($sp_end, $range_start)) {
	# the SP domain is located within a unique exon
	$new_sp_end = $range_start->start + $sp_end;
	my $range = Bio::PSU::Range->new(-start  => $new_sp_start,
					 -end    => $new_sp_end,
					 -strand => $strand,
	 				);
	push (@new_ranges, $range);
	$found = 1;
      }
      else {
	# the SP domain covers several exons
	my $j = $i+1;
	my $range = Bio::PSU::Range->new(-start  => $new_sp_start,
					 -end    => $range_start->end,
					 -strand => $strand,
					);
	push (@new_ranges, $range);
	$sp_end = $sp_end - ($range_start->end - $range_start->start);

	while ((not $found) && ($j<@ranges)) {
	  my $range_end = $ranges[$j];
	  if (is_in_range ($sp_end, $range_end)) {
	    # found end location too
	    $new_sp_end = $range_end->start + $sp_end;
	    my $range = Bio::PSU::Range->new(-start  => $range_end->start,
					     -end    => $new_sp_end,
					     -strand => $strand,
					    );
	    push (@new_ranges, $range);
	    $found = 1;
	  }
	  else {
	    # an intermediary exon (start in previous exon and stop in a further one)
	    my $range = Bio::PSU::Range->new(-start  => $range_end->start,
					     -end    => $range_end->end,
					     -strand => $strand,
					    );
	    push (@new_ranges, $range);
	  }
	  $sp_end = $sp_end - ($range_end->end - $range_end->start);
	  $j++;
	}
      }
    }
    # get rid the length of the current exon, because we want to keep reference to the start of the following exon, not of the start of the protein
    $sp_start = $sp_start - ($range_start->end - $range_start->start);
    $i++;
  }
  
  return @new_ranges;
}

sub is_in_range {
  my ($sp_coordinate, $range) = @_;
  
  if ($sp_coordinate < ($range->end - $range->start)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub getStrand {
  my (@ranges) = @_;
  my $range = $ranges[0];

  return $range->{strand};
}
