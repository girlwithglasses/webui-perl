=head1 NAME

Bio::PSU::Range - Class representing a region of DNA, RNA or protein
sequence

=head1 SYNOPSIS

 use Bio::PSU::Range;

 my $range = Bio::PSU::Range->new(-start       => $start,
        			  -fuzzy_start => $fuzzy_start,
				  -end         => $end,
				  -fuzzy_end   => $fuzzy_end,
				  -strand      => $strand);

A range is usually referenced by a Bio::PSU::Feature object where it
describes the location of the feature (or perhaps just part of the
feature) on its parent sequence.

=head1 DESCRIPTION

A Bio::PSU::Range object represents a region of DNA, RNA or protein
sequence. Bio::PSU::Range objects reside within Bio::PSU::Feature objects
where they describe the region(s) belonging to the feature.

The class provides methods for setting and returning start, end,
strand etc.

=head1 METHODS

See below. Methods private to this module are prefixed by an
underscore.

=head1 AUTHOR

Keith James (kdj@sanger.ac.uk)

=head1 ACKNOWLEDGEMENTS

See Bio::PSU.pod

=head1 COPYRIGHT

Copyright (C) 2000 Keith James. All Rights Reserved.

=head1 DISCLAIMER

This module is provided "as is" without warranty of any kind. It
may redistributed under the same conditions as Perl itself.

=cut

package Bio::PSU::Range;

use strict;
use Carp;
use Bio::PSU::Cloner;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Cloner);

{
    my $_class_defaults = { start       => 1,
			    fuzzy_start => 0,
			    end         => 1,
			    fuzzy_end   => 0,
			    no_5prime   => 0,
			    no_3prime   => 0,
			    no_width    => 0,
			    strand      => 1 };

    my $_class_args = { -start       => [qw(start       start      )],
			-fuzzy_start => [qw(fuzzy_start fuzzy_start)],
			-end         => [qw(end         end        )],
			-fuzzy_end   => [qw(fuzzy_end   fuzzy_end  )],
			-no_5prime   => [qw(no_5prime   no_5prime  )],
			-no_3prime   => [qw(no_3prime   no_3prime  )],
			-no_width    => [qw(no_width    no_width   )],
			-strand      => [qw(strand      strand     )] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $range = Bio::PSU::Range->new(-start => 100, -end => 400);
 Function: Creates a Bio::PSU::Range object which represents a single
         : contiguous range of residues
 Returns : A new Bio::PSU::Range object
 Args    : -start, -fuzzy_start, -end, -fuzzy_end (integers)
         : -no_5prime, -no_3prime, -no_width (0 or 1),
         : -strand (-1, 0 or 1)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = {};
    bless($self, $class);

    my $_defaults = $self->_dcopy($self->_class_defaults);
    $self->_init($_defaults, $args);

    $self->_check_args($args);

    $self->{strand} ||= 0;
    return undef unless $self->_is_valid;

    return $self;
}

=head2 start

 Title   : start
 Usage   : $start = $range->start;
         : $range->start(234);
 Function: Returns or sets the start of a range
 Returns : Start as string
 Args    : Integer (optional)

=cut

sub start
{
    my ($self, $start) = @_;

    $self->{start} = $start if defined $start;
    return $self->{start};
}

=head2 fuzzy_start

 Title   : fuzzy_start
 Usage   : $fuzzy_start = $range->fuzzy_start;
         : $range->fuzzy_start(120);
 Function: Returns or sets the fuzzy start of a range
 Returns : Fuzzy start as string
 Args    : Integer (optional)

=cut

sub fuzzy_start
{
    my ($self, $fuzzy_start) = @_;

    $self->{fuzzy_start} = $fuzzy_start if defined $fuzzy_start;
    return $self->{fuzzy_start};
}

=head2 end

 Title   : end
 Usage   : $end = $range->end;
         : $range->end(340);
 Function: Returns or sets the end of a range
 Returns : End as string
 Args    : Integer (optional)

=cut

sub end
{
    my ($self, $end) = @_;

    $self->{end} = $end if defined $end;
    return $self->{end};
}

=head2 fuzzy_end

 Title   : fuzzy_end
 Usage   : $fuzzy_end = $range->fuzzy_end;
         : $range->fuzzy_end(420);
 Function: Returns or sets the fuzzy end of a range
 Returns : Fuzzy end as string
 Args    : Integer (optional)

=cut

sub fuzzy_end
{
    my ($self, $fuzzy_end) = @_;

    $self->{fuzzy_end} = $fuzzy_end if defined $fuzzy_end;
    return $self->{fuzzy_end};
}

=head2 no_5prime

 Title   : no_5prime
 Usage   : if ($range->no_5prime) { print "No 5 prime end\n" }
         : $range->no_5prime(1);
 Function: Returns or sets a flag indicating that the range extends
         : 5' of the indicated boundary (denoted by < or > in the
         : EMBL location string)
 Returns : 0 (or undef) or 1
 Args    : 0 or 1 (optional)

=cut

sub no_5prime
{
    my ($self, $value) = @_;

    if ($value)
    {
	if ($value == 1 || $value == 0)
	{
	    $self->{no_5prime} = $value
	}
	else
	{
	    carp "Invalid attempt to set [$self] no_5prime to $value (use 0 or 1)"
	}
    }
    return $self->{no_5prime};
}

=head2 no_3prime

 Title   : no_3prime
 Usage   : if ($range->no_3prime) { print "No 3 prime end\n" }
         : $range->no_3prime(1);
 Function: Returns or sets a flag indicating that the range extends
         : 3' of the indicated boundary (denoted by < or > in the
         : EMBL location string)
 Returns : 0 (or undef) or 1
 Args    : 0 or 1 (optional)

=cut

sub no_3prime
{
    my ($self, $value) = @_;

    if ($value)
    {
	if ($value == 1 || $value == 0)
	{
	    $self->{no_3prime} = $value;
	}
	else
	{
	    carp "Invalid attempt to set [$self] no_3prime to $value (use 0 or 1)"
	}
    }
    return $self->{no_3prime};
}

=head2 no_width

 Title   : no_width
 Usage   : if ($range->no_width) { print "Feature lies between bases\n" }
         : $range->no_width(1);
 Function: Returns or sets a flag indicating that the range lies between
         : bases (denoted by ^ in the EMBL location string)
 Returns : 0 (or undef) or 1
 Args    : 0 or 1 (optional)

=cut

sub no_width
{
    my ($self, $value) = @_;

    if ($value)
    {
	if ($value == 1 || $value == 0)
	{
	    $self->{no_width} = $value
	}
	else
	{
	    carp "Invalid attempt to set [$self] no_width to $value (use 0 or 1)"
	}
    }
    return $self->{no_width};
}

=head2 strand

 Title   : strand
 Usage   : $strand = $range->strand;
         : $range->strand(-1) if ($complement)
 Function: Returns or sets the strand of a range
 Returns : -1, 0 or 1
 Args    : -1, 0 or 1 (optional)

=cut

sub strand
{
    my ($self, $strand) = @_;

    if ($strand)
    {
	if ($strand == -1 || $strand == 0 || $strand == 1)
	{
	    $self->{strand} = $strand
	}
	else
	{
	    carp "Invalid attempt to set strand of $self to $strand (use -1, 0 or 1)"
	}
    }
    return $self->{strand};
}

=head2 overlaps

 Title   : overlaps
 Usage   : if ($range1->overlaps($range2)) { print "They overlap\n" }
         : if ($range1->overlaps(@ranges)) { print "They overlap\n" }
 Function: Returns true if a range overlaps one or more other ranges
 Returns : False or the number of ranges which overlap
 Args    : Bio::PSU::Range object(s)

=cut

sub overlaps
{
    my ($self, @ranges) = @_;

    my $s_start = $self->fuzzy_start || $self->start;
    my $s_end   = $self->fuzzy_end   || $self->end;

    my $count = 0;
    foreach my $range (@ranges)
    {
	my $r_start = $range->fuzzy_start || $range->start;
	my $r_end   = $range->fuzzy_end   || $range->end;

    CASE:
	{
	    # Test range spans this object's start
	    if (($r_start <= $s_start) && ($r_end >= $s_start))
	    {
		$count++;
		last CASE;
	    }

	    # Test range spans this object's end
	    if (($r_start <= $s_end) && ($r_end >= $s_end))
	    {
		$count++;
		last CASE;
	    }

	    # Test range lies entirely within this object
	    if (($r_start >= $s_start) && ($r_end <= $s_end))
	    {
		$count++;
		last CASE;
	    }

	     # Test range entirely contains this object
	    if (($r_start <= $s_start) && ($r_end >= $s_end))
	    {
		$count++;
		last CASE;
	    }
	}
    }
    return $count;
}

=head2 contains

 Title   : contains
 Usage   : if ($range1->contains($range2)) { print "1 contains 2\n" }
         : if ($range1->contains(@ranges)) { print "1 contains all\n" }
 Function: Returns true if a range contains one or more other ranges
 Returns : False or the number of ranges which are contained
 Args    : Bio::PSU::Range object(s)

=cut

sub contains
{
    my ($self, @ranges) = @_;

    my $s_start = $self->fuzzy_start || $self->start;
    my $s_end   = $self->fuzzy_end   || $self->end;

    my $count = 0;
    foreach my $range (@ranges)
    {
	my $r_start = $range->fuzzy_start || $range->start;
	my $r_end   = $range->fuzzy_end   || $range->end;

	# Test range lies entirely within this object
	if (($r_start >= $s_start) && ($r_end <= $s_end))
	{
	    $count++
	}
    }
    return $count;
}

=head2 _is_valid

 Title   : _is_valid
 Usage   : N/A
 Function: Checks that ranges have been given sensible starts and
         : ends. Fuzzy starts and ends must lie outside fixed starts
         : and ends. All starts must be less than their corresponding
         : ends. A fixed start may be equal to a fixed end (1 bp feature)
 Returns : undef or 1
 Args    : None

=cut

sub _is_valid
{
    my ($self) = @_;

    if ($self->fuzzy_start < 0)
    {
	carp "[$self] tried to set fuzzy_start to " .
	defined $self->fuzzy_start ? $self->fuzzy_start : "undef" .
	" (must be >= 1)";
	return;
    }

    if ($self->start < 0)
    {
	carp "[$self] tried to set start to " .
	defined $self->start ? $self->start : "undef" .
	" (must be >= 1)";
	return;
    }

    if ($self->end < 0)
    {
	carp "[$self] tried to set end to " .
	defined $self->end ? $self->end : "undef" .
	" (must be >= 1)";
	return;
    }

    if ($self->fuzzy_end < 0)
    {
	carp "[$self] tried to set fuzzy_end to " .
	defined $self->fuzzy_end ? $self->fuzzy_end : "undef" .
	" (must be >= 1)";
	return;
    }

    if ($self->fuzzy_start and $self->start)
    {
	unless ($self->fuzzy_start < $self->start)
	{
	    my $message = sprintf("[%s] has fuzzy_start <%d> greater than start <%d>",
				  $self,
				  $self->fuzzy_start,
				  $self->start);
	    carp $message;
	    return;
	}
    }

    if ($self->fuzzy_start and $self->fuzzy_end)
    {
	unless ($self->fuzzy_start < $self->fuzzy_end)
	{
	    my $message = sprintf("[%s] has fuzzy_start <%d> greater than fuzzy_end <%d>",
				  $self,
				  $self->fuzzy_start,
				  $self->fuzzy_end);
	    carp $message;
	    return;
	}
    }

    if ($self->start and $self->end)
    {
	unless ($self->start <= $self->end)
	{
	    my $message = sprintf("[%s] has start <%d> greater than end <%d>",
				  $self,
				  $self->start,
				  $self->end);
	    carp $message;
	    # Allow the one special case of a malformed range where start > end
	    # because they are produced by quite a number of programs
	    unless ($self->fuzzy_start || $self->fuzzy_end)
	    {
		my $swap_start = $self->start;
		my $swap_end   = $self->end;
		$self->start($swap_end);
		$self->end($swap_start);
		return 1;
	    }
	    return;
	}
    }

    if ($self->end and $self->fuzzy_end)
    {
	unless ($self->end < $self->fuzzy_end)
	{
	    my $message = sprintf("[%s] has end <%d> greater than fuzzy_end <%d>",
				  $self,
				  $self->end,
				  $self->fuzzy_end);
	    carp $message;
	    return;
	}
    }
    return 1;
}

=head2 _trim

 Title   : _trim
 Usage   : N/A
 Function: Trims a Bio::PSU::Range object given a new start and end
         : sequences coordinates as boundaries. This method is
         : alpha code and may well have bugs
 Returns : None
 Args    : New start and end (integers)

=cut

sub _trim
{
    my ($self, $new_start, $new_end) = @_;

    # If feature is 1 bp long it can't be trimmed!
    return if ($self->start == $self->end);

    # Trim any coords beyond the new end
    if ($self->start)
    {
        if ($new_end < $self->start) { $self->start($new_end) }
    }
    if ($self->end)
    {
        # Only put </> in for non-fuzzy ranges: is this correct?
        if ($new_end < $self->end)
        {
            $self->end($new_end);
            $self->_mark_trimmed(0, 1);
        }
    }
    if ($self->fuzzy_end)
    {
        if ($new_end < $self->fuzzy_end) { $self->fuzzy_end($new_end) }
    }

    # Check coords after trimming to remove redundant ones
    if ($self->fuzzy_start and $self->start == $self->end)
    {
        $self->start(0);
        $self->end(0);
        $self->fuzzy_end($new_end);
    }
    if ($self->fuzzy_end and $self->start == $self->end)
    {
        $self->start(0);
        $self->end(0);
    }
    if ($self->end == $self->fuzzy_end) { $self->fuzzy_end(0) }

    # Offset the ranges and trim any coords beyond the new start
    my $offset = $new_start - 1;
    my $offset_fuzzy_start = $self->fuzzy_start - $offset;
    my $offset_fuzzy_end   = $self->fuzzy_end   - $offset;
    my $offset_start       = $self->start       - $offset;
    my $offset_end         = $self->end         - $offset;
    if ($offset_fuzzy_start < 0) { $offset_fuzzy_start = 0 }
    if ($offset_fuzzy_end   < 0) { $offset_fuzzy_end   = 0 }

    # Only put </> in for non-fuzzy ranges: is this correct?
    if ($offset_start < 0)
    {
        $offset_start = 0;
        $self->_mark_trimmed(1, 0);
    }
    if ($offset_end < 0)
    {
        $offset_end = 0;
        $self->_mark_trimmed(1, 0);
    }

    $self->fuzzy_start($offset_fuzzy_start);
    $self->fuzzy_end($offset_fuzzy_end);
    $self->start($offset_start);
    $self->end($offset_end);

    if ($self->fuzzy_end and $self->start == 0 and $self->end == 0)
    {
        $self->fuzzy_start(1)
    }

    if ($self->end and $self->start == 0) { $self->start(1) }
}

=head2 _mark_trimmed

 Title   : _mark_trimmmed
 Usage   : N/A
 Function: Marks a Bio::PSU::Range object with no_3prime and/or
         : no_5prime tags according to which end(s) have been
         : removed
 Returns : None
 Args    : 0 or 1 for each end (trimmed/not trimmed)

=cut

sub _mark_trimmed
{
    my ($self, $t_start, $t_end) = @_;

    if ($t_start)
    {
        if ($self->strand == 1)
        {
            $self->no_5prime(1)
        }
        else
        {
            $self->no_3prime(1)
        }
    }

    if ($t_end)
    {
        if ($self->strand == 1)
        {
            $self->no_3prime(1)
        }
        else
        {
            $self->no_5prime(1)
        }
    }
}

=head2 clone [inherited from Bio::PSU::Cloner]

 Title   : clone
 Usage   : $object = Bio::PSU::<object>->clone(args)
 Function: Creates a new Bio::PSU::<object> from an existing one. The
         : new object is a copy and is not a reference to the same
         : bit of memory as the cloning object. Object attributes
         : may be changed in the clone by passing arguments to the
         : clone method as if it were the constructor (new method)
 Returns : A Bio::PSU::<object>
 Args    : Same as for constructor

=cut

1;
