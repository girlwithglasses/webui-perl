=head1 NAME

Bio::PSU::TranslationTable - Class providing methods to translate
a codon using various translation tables

=head1 SYNOPSIS

 use strict;
 use Bio::PSU::TranslationTable;

 my $id = 11 # Bacterial translation table ID

 my $table = Bio::PSU::TranslationTable->new(-id => $id);

 my $rna = "gug";

 # Translate as a normal codon (i.e. returns 'V')
 my $aa1  = $table->translate_codon($rna);

 # Translate as a start codon (i.e. returns 'M')
 my $aa2  = table->start_codon($rna);

=head1 DESCRIPTION

A Bio::PSU::TranslationTable object will translate a codon using one
of the available translation tables. It is initialised with a
particular table and then uses that table for all its translations.
It is mainly for implementing translation methods in other objects,
but could be used directly.

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

package Bio::PSU::TranslationTable;

use strict;
use Carp;

{
    my @nt = qw(u c a g);
    my @tables = ();
    my %codons = ();

    while (<DATA>)
    {
	next if /^$/;
	/^(\d+)\s+(.*)/ and do
	{
	    my ($id, $name) = ($1, $2);
	    my $trans = <DATA>;
	    my $start = <DATA>;

	    my @aa  = split('', $trans);
	    my @met = split('', $start);

	    $tables[$id] = {id   => $id,
			    name => $name,
			    aa   => \@aa,
			    met  => \@met};
	}
    }

    my $index = 0;
    for my $i (0..3)
    {
	for my $j (0..3)
	{
	    for my $k (0..3)
	    {
		$codons{$nt[$i] . $nt[$j] . $nt[$k]} = $index++
	    }
	}
      }

    sub _valid_tables
    {
	my ($self) = @_;
	my @valid = ();

	foreach (@tables)
	{
	    push(@valid, $_->{id}) if defined $_->{id}
	}
	return @valid;
    }

    sub _set_table
    {
	my ($self, $id) = @_;
	$self->{table_id} = $tables[$id];
    }

    sub _set_codons
    {
	my ($self) = @_;
	$self->{codons} = \%codons;
    }
}

=head2 new

 Title   : new
 Usage   : $table = Bio::PSU::TranslationTable->new(-id => 1);
 Function: Creates a new Bio::PSU::TranslationTable object
 Returns : Bio::PSU::TranslationTable object
 Args    : -id integer (standard translation table number)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    my @args = @_;

    my $_defaults = {id => 1};

    bless($self, $class);

    $self->_init($_defaults, @args);
    return $self;
}

=head2 _init

 Title   : _init
 Usage   : N/A
 Function: Object initialisation from default values which may be
         : overridden by arguments supplied to the constructor
 Returns : Nothing
 Args    : reference to a hash of defaults, plus the arguments to
         : the constructor

=cut

sub _init
{
    my ($self, $_defaults, %args) = @_;

    %$self = %$_defaults;

    $self->_set_codons;

    foreach (keys %args)
    {
	my $val = $args{$_};
	if (/^-id$/) 
	{
	    unless (grep /^$val$/, $self->_valid_tables)
	    {
		carp "Invalid translation table [$val] requested: reverting to table 1";
		$val = 1;
	    }
	    $self->_set_table($val);
	    next;
	}
	else
	{
	    $self->_set_table(1)
	}
    }
}

=head2 translate_codon

 Title   : translate_codon
 Usage   : $aa = $table->translate_codon('ATG');
 Function: Translates a single codon using whatever translation
         : table the object was initialised with
 Returns : Amino acid string
 Args    : Codon (string)

=cut

sub translate_codon
{
    my ($self, $codon) = @_;

    my $codon_index;
    if (exists ${$self->{codons}}{$codon})
    {
	$codon_index = ${$self->{codons}}{$codon}
    }
    return 'X' unless defined $codon_index;

    return ${$self->{table_id}}{aa}[$codon_index];
}

=head2 start_codon

 Title   : start_codon
 Usage   : $aa = $table->start_codon('ATG');
 Function: Translates a single codon using whatever translation
         : table the object was initialised with. Additionally,
         : this method returns 'M' (Met) if the translation
         : table specifies a start codon
 Returns : Amino acid string
 Args    : Codon (string)

=cut

sub start_codon
{
    my ($self, $codon) = @_;

    my $codon_index;
    if (exists ${$self->{codons}}{$codon})
    {
	$codon_index = ${$self->{codons}}{$codon}
    }
    return 'X' unless defined $codon_index;

    my $start_codon = ${$self->{table_id}}{met}[$codon_index];

    if ($start_codon ne '_')
    {
	return $start_codon
    }
    else
    {
	return ${$self->{table_id}}{aa}[$codon_index]
    }
}

1;

__DATA__

1 Standard
FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
___M_______________M_______________M____________________________

2 Vertebrate Mitochondrial
FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSS**VVVVAAAADDEEGGGG
________________________________MMMM_______________M____________

3 Yeast Mitochondrial
FFLLSSSSYY**CCWWTTTTPPPPHHQQRRRRIIMMTTTTNNKKSSRRVVVVAAAADDEEGGGG
__________________________________MM____________________________

11 Bacterial
FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
___M_______________M____________MMMM_______________M____________
