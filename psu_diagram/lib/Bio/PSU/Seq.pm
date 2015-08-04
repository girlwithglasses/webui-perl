=head1 NAME

Bio::PSU::Seq - Class representing a biological sequence, including
features

=head1 SYNOPSIS

 use strict;
 use Bio::PSU::Seq;

 my $seq = Bio::PSU::Seq->new
     (-id   => 'my_seq',
      -desc => 'a made-up sequence',
      -str  => 'tatcttatttctagtcgtttggggatatcgatcacatgcgacgtta',
      -type => 'dna');

 printf("Length of %s is %d\n", $seq->id, $seq->length);

 my $subseq = $seq->subseq(4, 18);
 $subseq->id('my_subseq');

 printf("Length of %s is %d\n", $subseq->id, $subseq->length);

 print "Sequence:\n";
 print $seq->str, "\n";
 print $seq->revcom->str, "\n";

 print "Subsequence:\n";
 print $subseq->str, "\n";
 print $subseq->revcom->str, "\n";

=head1 DESCRIPTION

A Bio::PSU::Seq object represents a DNA, RNA or protein sequence. It
provides methods to get (or set) the actual sequence string and obtain
new Bio::PSU::Seq objects representing subsequences of itself.

It also provides methods for attaching and removing Bio::PSU::Feature objects
and for bookkeeping tasks such as setting/checking the sequence type,
length, id and description.

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

This module is provided "as is" without warranty of any kind. It may
be used, redistributed and/or modified under the same conditions as
Perl itself.

=cut

package Bio::PSU::Seq;

use strict;
use Carp;
use Bio::PSU::Cloner;
use Bio::PSU::Analyser;
use Bio::PSU::Translator;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Cloner Bio::PSU::Translator Bio::PSU::Analyser);

{
    my $_class_defaults = { id       => "",
                            acc      => "",
                            desc     => "",
                            org      => "",
                            str      => { val => undef, type => 'virtual' },
                            features => [] };

    my $_class_args = { -id       => [qw(id       id      )],
                        -acc      => [qw(acc      acc     )],
                        -desc     => [qw(desc     desc    )],
                        -org      => [qw(org      org     )],
                        -type     => [qw(_defer   type    )],
                        -str      => [qw(_setstr  str     )],
                        -features => [qw(features features)] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $seq = Bio::PSU::Seq->new(-id => $name, -str => $str);
 Function: Creates a new Bio::PSU::Seq object
 Returns : A Bio::PSU::Seq object
 Args    : -id, -desc, -type (strings), -str (string) containing
         : the sequence (DNA, RNA or protein)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = {};
    bless($self, $class);

    my $_defaults = $self->_dcopy($self->_class_defaults);
    my $deferred = $self->_init($_defaults, $args);

    # Defer setting sequence type until now. The type method
    # checks the sequence, so we must wait until the sequence
    # string is attached
    foreach (keys %$deferred)
    {
	my $val = delete $deferred->{$_};
	if (/^-type$/) { $self->type($val); next }
    }

    $self->_check_args($args);

    return $self;
}


=head2 id

 Title   : id
 Usage   : $seqid = $seq->id;
         : $seq->id("new_id");
 Function: Returns or sets the sequence id (which should not contain
         : spaces)
 Returns : String
 Args    : Sequence id (string, optional)

=cut

sub id
{
    my ($self, $id) = @_;

    $self->{id} = $id if defined $id;
    return $self->{id};
}

=head2 acc

 Title   : acc
 Usage   : $acc = $seq->acc;
         : $seq->acc("new_acc");
 Function: Returns or sets the sequence accession number
 Returns : String
 Args    : Sequence acc (string, optional)

=cut

sub acc
{
    my ($self, $acc) = @_;

    $self->{acc} = $acc if defined $acc;
    return $self->{acc};
}

=head2 desc

 Title   : desc
 Usage   : $desc = $seq->desc;
         : $seq->desc("New sequence description");
 Function: Returns or sets the sequence description
 Returns : String
 Args    : Sequence description (string, optional)

=cut

sub desc
{
    my ($self, $desc) = @_;

    $self->{desc} = $desc if defined $desc;
    return $self->{desc};
}

=head2 org

 Title   : org
 Usage   : $acc = $seq->org;
         : $seq->org("new_org");
 Function: Returns or sets the sequence source organism
 Returns : String
 Args    : Organism (string, optional)

=cut

sub org
{
    my ($self, $org) = @_;

    $self->{org} = $org if defined $org;
    return $self->{org};
}

=head2 type

 Title   : type
 Usage   : if ($seq->type eq 'virtual') { print "This contains a null
         : sequence\n" }
         : if ($is_dna) { $seq->type('dna') }
 Function: Returns or sets the sequence type. If the sequence type has
         : been set to virtual while there is a sequence present, the
         : method tries to guess the type.
 Returns : String (dna, rna, protein or virtual)
 Args    : Sequence type (string, optional)

=cut

sub type
{
    my ($self, $type) = @_;

    my @types = qw(dna rna protein virtual);
    if (defined $type)
    {
	if (! grep /$type/i, @types)
	{
	    carp "Invalid sequence type [$type]"
	}
	$self->{str}{type} = lc($type);
    }
    else
    {
	if ($self->str && $self->{str}{type} eq 'virtual')
	{
	    $self->{str}{type} = $self->_typeguess
	}
    }
    return $self->{str}{type};
}

=head2 str

 Title   : str
 Usage   : $str = $seq->str;
 Function: Returns the current sequence string. Having an undef
         : sequence string is allowed - this is taken to represent
         : a virtual sequence to which you can still attach
         : features.
 Returns : Sequence as string
 Args    : None

=cut

sub str
{
    my ($self) = @_;
    return $self->{str}{val};
}

=head2 subseq

 Title   : subseq
 Usage   : my $subseq_with_features    = $seq->subseq(20, 400);
         : my $subseq_without_features = $seq->subseq(20, 400, 0);
 Function: Creates a new Bio::PSU::Seq object representing a subsequence
         : of the parent. The methods required to trim features and
         : add them to the subsequence are alpha code and may well
         : contain bugs. Please check the output carefully,
         : especially for fuzzy ranges
 Returns : A Bio::PSU::Seq object
 Args    : Start and end coordinates of the subsequence (integers)

=cut

sub subseq
{
    my ($self, $start, $end, $add_features) = @_;
    my $subseq;

    $add_features = 1 unless (defined $add_features);

    if (! defined $self->str)
    {
        carp "Unable to make subseq object from [$self] as it has no sequence string defined"
    }
    elsif ($self->str eq "")
    {
        carp "Unable to make subseq object from [$self] as it has a zero length sequence string"
    }
    else
    {
        my $seqlen = $self->length;

        # Check for out-of-range coordinates
        if ($start > $end)
        {
            carp "start: $start is greater than end: $end when creating subseq from $self";
            ($start, $end) = ($end, $start);
        }
        if ($start < 1 or $start > $seqlen)
        {
            carp "start: $start is out of range (1..$seqlen) when creating subseq from $self";
            $start = 1;
        }
        if ($end < 1 or $end > $seqlen)
        {
            carp "end: $end is out of range (1..$seqlen) when creating subseq from $self";
            $end = $seqlen;
        }

        # Sequences are indexed from 1, while substr indexes from 0
        my $substr = substr($self->str, $start - 1, $end - $start + 1);
        # Append the subsequence coordinates to the description
        my $desc   = $self->desc;
        $desc ||= "";
        $desc   = sprintf "%s (%d..%d)", $desc, $start, $end;

        my @trimmed_features;
        if ($add_features)
        {
        FEATURE: foreach my $feature ($self->features)
            {
                # Ignore features which are entirely outside the subseq
                next FEATURE if $feature->end   < $start;
                next FEATURE if $feature->start > $end;

                my @trimmed_ranges;
            RANGE: foreach my $range ($feature->ranges)
                {
                    # Ignore ranges outside the subseq
                    if ($range->fuzzy_start)
                    {
                        next RANGE if $range->fuzzy_start > $end;
                    }
                    if ($range->fuzzy_end)
                    {
                        next RANGE if $range->fuzzy_end < $start;
                    }

                    next RANGE if $range->start > $end;
                    next RANGE if $range->end < $start;
                    my $trimmed_range = $range->clone;
                    $trimmed_range->_trim($start, $end);
                    push(@trimmed_ranges, $trimmed_range);
                }
                if (@trimmed_ranges)
                {
                    my $trimmed_feature = $feature->clone(-ranges => \@trimmed_ranges);
                    push(@trimmed_features, $trimmed_feature);
                }
            }
        }
        $subseq = Bio::PSU::Seq->new(-str => $substr, -type => $self->type);

        # Add trimmed features if required and features are present
        if ($add_features && @trimmed_features)
        {
            $subseq->features(@trimmed_features)
        }
    }
    return $subseq;
}

=head2 revcom

 Title   : revcom
 Usage   : $rev = $seq->revcom;
 Function: Returns the reverse complement of the current sequence
         : object
 Returns : Bio::PSU::Seq object
 Args    : None

=cut

sub revcom
{
    my ($self) = @_;
    my $seqlen = $self->length;

    if ($self->type eq 'protein')
    {
        carp "Unable to reverse complement [$self] as it is protein";
        return;
    }
    elsif ($self->type eq 'virtual')
    {
        carp "Unable to reverse complement [$self] as it is a virtual sequence";
        return;
    }

    my @rc_features;
    foreach my $feature ($self->features)
    {
        if ($feature->strand == 0)
        {
            carp "Unable to reverse complement [$feature] as is on strand 0";
            next;
        }

        my @rc_ranges;
        foreach my $range ($feature->ranges)
        {
            my $fuzzy_start = $range->fuzzy_start;
            my $start       = $range->start;
            my $end         = $range->end;
            my $fuzzy_end   = $range->fuzzy_end;
            my $strand      = $range->strand;

            my $rc_start  = $seqlen - $end + 1;
            my $rc_end    = $seqlen - $start + 1;
            my $rc_strand = - $strand;

            # Initially just swap start/end/strand
            my $rc_range = $range->new(-start  => $rc_start,
                                       -end    => $rc_end,
                                       -strand => $rc_strand);

            # Fuzzies are more complex
            if ($range->fuzzy_end)
            {
                my $rc_fuzzy_start = $seqlen - $fuzzy_end + 1;

                # Make sure fuzzy_start < start
                if ($rc_fuzzy_start > $rc_range->start)
                {
                    $rc_range->fuzzy_start($rc_start);
                    $rc_range->start($rc_fuzzy_start);
                }
                else
                {
                    $rc_range->fuzzy_start($rc_fuzzy_start)
                }
            }

            if ($fuzzy_start)
            {
                my $rc_fuzzy_end = $seqlen - $fuzzy_start + 1;

                # Make sure fuzzy_end > end
                if ($rc_fuzzy_end < $rc_range->end)
                {
                    $rc_range->fuzzy_end($rc_end);
                    $rc_range->start($rc_fuzzy_end);
                }
                else
                {
                    $rc_range->fuzzy_end($rc_fuzzy_end)
                }
            }

            if ($range->no_5prime) { $rc_range->no_5prime(1) }
            if ($range->no_3prime) { $rc_range->no_3prime(1) }
            if ($range->no_width)  { $rc_range->no_width(1)  }

            push(@rc_ranges, $rc_range);
        }

        my $rc_feature = $feature->clone(-ranges => \@rc_ranges);
        push(@rc_features, $rc_feature);
    }

    my $rc_str = $self->_rcstr;
    my $rc_seq = $self->clone(-str      => $rc_str,
                              -type     => $self->type,
                              -features => \@rc_features);
    return $rc_seq;
}

=head2 has_features

 Title   : has_features
 Usage   : if ($seq->has_features) { print "Seq has features\n" };
         : print "Seq has ", $seq->has_features, " features\n";
         : This method is just a convenience as you can get the
         : same effect by calling 'features' in a scalar context.
         : Also, it doesn't make a copy of the feature list
 Function: Returns the number of features on a Bio::PSU::Seq object
 Returns : Integer, or 0
 Args    : None

=cut

sub has_features
{
    my ($self) = @_;
    return scalar @{$self->{features}};
}

=head2 features

 Title   : features
 Usage   : $seq->features($feature1, $feature2, $feature3);
         : $seq->features(@features);
 Function: Returns or adds Bio::PSU::Feature objects to a
         : Bio::PSU::Seq object
 Returns : A list of Bio::PSU::Feature objects
 Args    : Bio::PSU::Feature objects, either as an array, or a
         : reference to a list (as used in the constructor)

=cut

sub features
{
    my ($self, @features) = @_;

    # Expand array references into a copy of the array
    @features = map { if (ref($_) eq 'ARRAY') { @$_ } else { $_ } } @features;

    foreach (@features)
    {
        if ($_->ranges)
        {
            my $reject;
            # Attach the feature to the sequence
            $_->{str} = $self->{str};

            # Check that the feature's ranges lie within the sequence
            foreach my $range ($_->ranges)
            {
                $reject++ unless ($_->_valid_range($range))
            }
            if ($reject)
            {
                $_->{str} = undef;
                carp "Unable to add [$_] to [$self] as it has invalid ranges";
            }
            else
            {
                push(@{$self->{features}}, $_)
            }
        }
        else
        {
            $self->btrace("Unable to add [$_] as it contains no ranges to specify its location")
        }
    }
    return @{$self->{features}};
}

=head2 _setstr

 Title   : _setstr
 Usage   : N/A
 Function: Used by the contructor to add the sequence string
 Returns : Nothing
 Args    : Sequence (string)

=cut

sub _setstr
{
    my ($self, $str) = @_;

    if (defined $str)
    {
	$self->{str}{val} = $str
    }
    else
    {
	$self->{str}{val} = $str;
	$self->type('virtual');
    }

    my @features = [$self->features];
    $self->{features} = [];
    $self->features(@features);
}

=head2 _typeguess

 Title   : _typeguess
 Usage   : N/A
 Function: Returns a sequence type determined by guessing from the
         : sequence composition.
 Returns : Sequence type as string (dna, rna, protein, virtual)
 Args    : None

=cut

sub _typeguess
{
    my ($self) = @_;
    my $type;

 CASE:
    {
        # If there is no sequence attached the type is virtual
        if (! defined $self->str)
        {
            $type = 'virtual';
            last CASE;
        }

        # If there is a zero-length sequence attached the type is virtual
        if ($self->length == 0)
        {
            $type = 'virtual';
            last CASE;
        }

        # Only RNA contains a IUPAC symbol 'U'
        if ($self->str =~ /u/i)
        {
            unless ($self->is_rna)
            {
                carp "[$self] appears to be RNA, but contains non-IUPAC symbols"
            }
            $type = 'rna';
            last CASE;
        }

        # Only protein contains the IUPAC symbols EFILPQZ or *
        if ($self->str =~ /[efilpqz\*]/i)
        {
            unless ($self->is_protein)
            {
                carp "[$self] appears to be protein, but contains non-IUPAC symbols"
            }
            $type = 'protein';
            last CASE;
        }

        # Otherwise we have to do some counting to guess
        my %composition = $self->composition;

        my $a = $composition{A} || 0;
        my $c = $composition{C} || 0;
        my $g = $composition{G} || 0;
        my $t = $composition{T} || 0;
        my $u = $composition{U} || 0;
        my $n = $composition{N} || 0;

    GUESS:
        {
            if (($a + $c + $g + $t + $n) / $self->length > 0.9 and $self->is_dna_iupac)
            {
                $type = 'dna';
                last GUESS;
            }
            if (($a + $c + $g + $u + $n) / $self->length > 0.9 and $self->is_rna)
            {
                $type = 'rna';
                last GUESS;
            }
            if ($self->is_protein)
            {
                $type = 'protein';
                last GUESS;
            }
            # Fallthrough condition
            $self->btrace("Unable to determine type of sequence attached to [$self]")
        } # end GUESS
    } # end CASE
    return $type;
}

=head2 _rcstr

 Title   : _rcstr
 Usage   : $rev = $seq->_rcstr;
 Function: Returns the reverse complement of the current sequence
         : string. This method is analagous to str
 Returns : String
 Args    : None

=cut

sub _rcstr
{
    my ($self) = @_;
    my $str = $self->str;

    # Uracil is converted to Thymine temporarily as otherwise there
    # would be two symbols (T, U) mapped to A in the same tr///
    # operation
    $str =~ tr/uU/tT/ if $self->type eq 'rna';
    $str =~ tr/acgtrymkswhbvdnxACGTRYMKSWHBVDNX/tgcayrkmswdvbhnxTGCAYRKMSWDVBHNX/;
    $str =~ tr/tT/uU/ if $self->type eq 'rna';

    return scalar reverse $str;
}

=head2 clone [inherited from Bio::PSU::Base]

 Title   : clone
 Usage   : $object = Bio::PSU::<object>->clone(args)
 Function: Creates a new Bio::PSU::<object> from an existing one. The
         : new object is a copy and is not a reference to the same
         : bit of memory as the cloning object. Object attributes
         : may be changed in the clone by passing arguments to the
         : clone method as if it were the constructor (new method).
 Returns : A Bio::PSU::<object>
 Args    : Same as for constructor

=cut

=head2 is_rna [inherited from Bio::PSU::Analyser]

 Title   : is_rna
 Usage   : if($seq->is_rna) { print "The sequence is RNA\n" }
 Function: Returns true if the sequence contains only valid RNA
         : residues
 Returns : 0 or 1
 Args    : None

=cut

=head2 is_dna [inherited from Bio::PSU::Analyser]

 Title   : is_dna
 Usage   : if($seq->is_dna) { print "The sequence is unambiguous
         : DNA\n" }
 Function: Returns true if the sequence contains only DNA
         : residues A, C, G & T
 Returns : 0 or 1
 Args    : None

=cut

=head2 is_dna_ambig [inherited from Bio::PSU::Analyser]

 Title   : is_dna_ambig
 Usage   : if($seq->is_dna_ambig) { print "The sequence is
         : ambiguous DNA\n" }
 Function: Returns true if the sequence contains only DNA residues
         : A, C, G, T & N
 Returns : 0 or 1
 Args    : None

=cut

=head2 is_dna_iupac [inherited from Bio::PSU::Analyser]

 Title   : is_dna_iupac
 Usage   : if($seq->is_dna_iupac) { print "The sequence is IUPAC
         : DNA\n" }
 Function: Returns true if the sequence contains only valid IUPAC DNA
         : residues
 Returns : 0 or 1
 Args    : None

=cut

=head2 is_protein [inherited from Bio::PSU::Analyser]

 Title   : is_protein
 Usage   : if($seq->is_protein) { print "The sequence is protein\n" }
 Function: Returns true if the sequence contains only unambiguous
         : single-letter amino acid codes
 Returns : 0 or 1
 Args    : None

=cut

=head2 is_protein_ambig [inherited from Bio::PSU::Analyser]

 Title   : is_protein_ambig
 Usage   : if($seq->is_protein_ambig) { print "The sequence is
         : ambiguous protein\n" }
 Function: Returns true if the sequence contains only single-letter
         : amino acid codes, including ambiguities
 Returns : 0 or 1
 Args    : None

=cut

=head2 length [inherited from Bio::PSU::Analyser]

 Title   : length
 Usage   : $seqlen = $seq->length;
 Function: Returns the length of the sequence
 Returns : Integer or undef if the sequence string is virtual
 Args    : None

=cut

=head2 composition [inherited from Bio::PSU::Analyser]

 Title   : composition
 Usage   : my %comp = $self->composition;
         : Then $a = $comp{A} to get a count of residue 'A'. If
         : you try $x = $comp{X} and there are no 'X' residues
         : in the sequence, the result will of course be undef
 Function: Returns a hash with the constituent residues of the
         : sequence as keys and their corresponding frequency
         : as values. All the keys are UPPER CASE.
 Returns : Hash
 Args    : None

=cut

=head2 translate [inherited from Bio::PSU::Translator]

 Title   : translate
 Usage   : $protein = $feature->translate;
         : $aa = $nt->translate(1);
 Function: Translates the sequence of both Bio::PSU::Seq and Bio::PSU::Feature
         : objects
 Returns : A new Bio::PSU::Seq object
 Args    : Translation table id number, frame and N-terminal flag,
         : in that order
         :
         : The translation table numbering system is the usual one;
         : 1, Standard; 2, Vertebrate mitochondrial; 3, Yeast
         : mitochondrial etc. The N-terminal flag determines
         : whether the first codon is treated as a start codon. Set
         : this to 0 if you don't want this (the default is 1)
         : If the caller is a Bio::PSU::Feature object, this method will
         : automatically honour any codon_start qualifiers it may
         : have. These override the frame argument to the method
         :
         : Translate is a 'lite' method and will return an amino
         : acid 'X' where there is an ambiguous base in a codon

=cut

1;


