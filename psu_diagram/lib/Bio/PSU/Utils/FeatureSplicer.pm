package Bio::PSU::Utils::FeatureSplicer;

use strict;
use Carp;
use Bio::PSU::Feature;

=head2 make_spliced_annotation

 Title   : make_spliced_annotation
 Usage   : $feature = make_spliced_annotation($cds, $start_aa,
         : $length)
 Function: Creates a new feature representing a CDS motif with
         : DNA-centric coordinates and appropriate splicing.
 Example :
 Returns : Bio::PSU::Feature
 Args    : Bio::PSU::Feature (the CDS), the amino acid coordinate
         : of the hit start with respect to the start of the CDS,
         : the length of the hit in amino acids

=cut

sub make_spliced_annotation
{
    my ($self, $f, $hit_start, $hit_remaining) = @_;

    my $warning;

    # Assumes last 3 bases of translation are a stop codon, therefore
    # subtract 1
    my $f_aa = (($f->end - $f->start + 1) / 3) - 1;

    # Fail if start is out of range
    if ($hit_start < 1 or $hit_start > $f_aa)
    {
		my $message = "Unable to add annotation: hit start (" .
			$hit_start .
				" aa) is outside feature (length $f_aa aa)";

		$self->btrace($message);
		# warn $message;
		# return;
    }
    # Warn and clip end if end is out of range
    elsif (($hit_start + $hit_remaining - 1) > $f_aa)
    {
		print STDERR ("Clipping annotation: hit end (",
					  $hit_start + $hit_remaining - 1,
					  " aa) is outside feature at [",
					  $f->start, "..", $f->end,
					  "] (length $f_aa aa)\n");

		$warning = sprintf("This hit extended beyond the end of the feature by %d aa and was clipped.",
						   $hit_start + $hit_remaining - 1 - $f_aa);

		$hit_remaining = $f_aa - $hit_start + 1;
    }

    my $strand = $f->strand;
    my @f_ranges;
    my @n_ranges;

    if ($strand == 1)
    {
		@f_ranges = $f->ranges
    }
    elsif ($strand == -1)
    {
		@f_ranges = reverse $f->ranges
    }
    else
    {
		confess "Unable to add annotation; feature strand is not set";
    }

    # Convert length of hit to base pairs
    $hit_remaining *= 3;

    # This is the absolute DNA-centric coordinate of the start of the
    # hit. This is what we want to find initally.
    my $hit_bp;

    # This is the running total of codons/amino acids
    my $aa = 0;

    # This is the current total of partial codons to keep track of the
    # phase between one exon and the next
    my $nt = 0;

    for my $range_index (0..$#f_ranges)
    {
		my $r   = $f_ranges[$range_index];
		my $len = $r->end - $r->start + 1;

	if (! $hit_bp)
	{
	    # Calculate aa and for this exon and phase for next
	    # exon
	    $aa += int($len / 3);
	    $nt +=     $len % 3;

	    if (int $nt / 3)
	    {
			$aa += int($nt / 3);
			$nt  = $nt % 3;
	    }

	    # If the aa counted so far is less than the start aa
	    # of the hit, continue to the next exon
	    next if $aa < $hit_start;

	    # Number of codons between the hit start and the end
	    # of the exon
	    my $codons_to_end = ($aa - $hit_start + 1);

	    # Number of bases between the hit start and the end of
	    # the exon (takes into account partial codons)
	    my $bp_to_end     = ($codons_to_end * 3) + $nt;

	    # The DNA-centric coordinate of the hit start. As we
	    # know the absolute coordinate of the end of the exon,
	    # we use this to fix the absolute hit position

	    $hit_bp = ($strand == 1) ? ($r->end - $bp_to_end + 1) : ($r->start + $bp_to_end - 1);

	    # Does the hit fit entirely within the rest of the
	    # exon?
	    if ($bp_to_end >= $hit_remaining)
	    {
			push(@n_ranges, $strand == 1

				 ? Bio::PSU::Range->new(-start  => $hit_bp,
										-end    => $hit_bp + $hit_remaining - 1,
										-strand => 1)

				 : Bio::PSU::Range->new(-start  => $hit_bp - $hit_remaining + 1,
										-end    => $hit_bp,
										-strand => -1));
			# We are done
			last;
	    }
	    # Otherwise we make a range from the hit start up to
	    # the end of the exon and consume that amount of the
	    # hit length
	    else
	    {
			push(@n_ranges, $strand == 1

				 ? Bio::PSU::Range->new(-start  => $hit_bp,
										-end    => $r->end,
										-strand => 1)

				 : Bio::PSU::Range->new(-start  => $r->start,
										-end    => $hit_bp,
										-strand => -1));

			$hit_remaining -= $bp_to_end;
			# Continue to the next exon(s) to consume the rest
			# of the hit length
			next;
		}
	}
		else
		{
			# Here we have determined the DNA-centric coordinate
			# of the hit start in a previous exon
			my $range_len = $r->end - $r->start + 1;

			# Does the hit fit entirely within this exon?
			if ($range_len >= $hit_remaining)
			{
				push(@n_ranges, $strand == 1

					 ? Bio::PSU::Range->new(-start  => $r->start,
											-end    => $r->start + $hit_remaining - 1,
											-strand => 1)

					 : Bio::PSU::Range->new(-start  => $r->end - $hit_remaining + 1,
											-end    => $r->end,
											-strand => -1));
				# We are done
				last;
			}
			else
			{
				push(@n_ranges, Bio::PSU::Range->new(-start  => $r->start,
													 -end    => $r->end,
													 -strand => $strand));

				$hit_remaining -= $range_len;
				# Continue to the next exon(s) to consume the rest
				# of the hit length
				next;
			}
		}
    }

    # Return a new feature created with these ranges
    my $annotation = Bio::PSU::Feature->new(-key    => 'misc_feature',
											-ranges => \@n_ranges);

    $annotation->qadd('note', $warning) if defined $warning;
    return $annotation;
}

1;
