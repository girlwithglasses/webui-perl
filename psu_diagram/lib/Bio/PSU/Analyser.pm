=head1 NAME

Bio::PSU::Analyser - A class providing inheritable methods which allow
objects to calculate statistics about themselves

=head1 SYNOPSIS

 use Bio::PSU::Analyser;

 use vars qw(@ISA);
 @ISA = qw(Bio::PSU::Analyser);

=head1 DESCRIPTION

This class provides various methods which are inherited by objects
which need to calculate various statistics about themselves
e.g. sequence composition, molecular weight.

If these methods become more complex the molecular weight tables
and calculations will be moved out to another object.

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

package Bio::PSU::Analyser;

use strict;
use Carp;

=head2 composition

 Title   : composition
 Usage   : my %comp = $self->composition;
         : Then $a = $comp{A} to get a count of residue 'A'. If
         : you try $x = $comp{x} and there are no 'x' residues
         : in the sequence, the result will of course be undef
 Function: Returns a hash with the constituent residues of the
         : sequence as keys and their corresponding frequency
         : as values. All the keys are UPPER CASE
 Returns : Hash
 Args    : None

=cut

sub composition
{
    my ($self) = @_;
    my %composition;

    unless ($self->can('str'))
    {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    my $str = $self->str;
    $str    = uc($str);
    while ($str =~ /(.)/g)
    {
	$composition{$1}++
    }
    return %composition;
}

=head2 codons

 Title   : codons
 Usage   : my %codons = $self->codons;
         : Then $atg = $codons{ATG} to get a count of codons
         : 'ATG'. If you try $x = $codons{x} and there are no
         : 'x' codonss in the sequence, the result will of
         : course be undef
 Function: Returns a hash with the constituent codons of the
         : sequence as keys and their corresponding frequency
         : as values. All the keys are UPPER CASE
 Returns : Hash
 Args    : None

=cut

sub codons
{
    my ($self) = @_;
    my %codons;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }
    unless ($self->is_dna || $self->is_dna_ambig || $self->is_dna_iupac || $self->is_rna)
    {
	carp "Sequence must be DNA or RNA to report codons";
	return;
    }

    my $str = $self->str;
    $str    = uc($str);
    while ($str =~ /(.{3})/g)
    {
	$codons{$1}++
    }
    return %codons;
}


=head2 molwt

 Title   : molwt
 Usage   : $molwt = $seq->molwt;
 Function: Calculates the molecular weight of a protein sequence.
         : Currently supports only unambiguous protein sequence
 Returns : Molecular weight (integer)
 Args    : None

=cut

sub molwt
{
    my ($self) = @_;
    my $mwt = 0;
    my $water = 18.015;
    my %aa_mwts = (A => 89.09,
		   R => 174.21,
		   N => 132.12,
		   D => 133.1,
		   C => 121.15,
		   Q => 146.15,
		   E => 147.13,
		   G => 75.07,
		   H => 155.16,
		   I => 131.18,
		   L => 131.18,
		   K => 146.19,
		   M => 149.22,
		   F => 165.19,
		   P => 115.13,
		   S => 105.09,
		   T => 119.12,
		   W => 204.22,
		   Y => 181.19,
		   V => 117.15);

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }
    unless ($self->is_protein)
    {
	carp "Molwt calculation currently only supported for unambiguous protein sequence";
	return;
    }

    my $str = $self->str;
    $str = uc($str);
    while ($str =~ /(.)/g)
    {
	next if $1 =~ /\*/;
	$mwt += $aa_mwts{$1};
    }
    $mwt -= $water * ($self->length - 1);

    return sprintf("%.0f", $mwt);
}

=head2 is_rna

 Title   : is_rna
 Usage   : if($seq->is_rna) { print "The sequence is RNA\n" }
 Function: Returns true if the sequence contains only valid RNA
         : residues
 Returns : undef or 1
 Args    : None

=cut

sub is_rna
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^acgu]/i and return;
    return 1;
}

=head2 is_dna

 Title   : is_dna
 Usage   : if($seq->is_dna) { print "The sequence is unambguous
         : DNA\n" }
 Function: Returns true if the sequence contains only DNA
         : residues A, C, G & T
 Returns : undef or 1
 Args    : None

=cut

sub is_dna
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^acgt]/i and return;
    return 1;
}

=head2 is_dna_ambig

 Title   : is_dna_ambig
 Usage   : if($seq->is_dna_ambig) { print "The sequence is
         : ambiguous DNA\n" }
 Function: Returns true if the sequence contains only DNA residues
         : A, C, G, T & N
 Returns : undef or 1
 Args    : None

=cut

sub is_dna_ambig
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^acgtn]/i and return;
    return 1;
}

=head2 is_dna_iupac

 Title   : is_dna_iupac
 Usage   : if($seq->is_dna_iupac) { print "The sequence is IUPAC
         : DNA\n" }
 Function: Returns true if the sequence contains only valid IUPAC DNA
         : residues
 Returns : undef or 1
 Args    : None

=cut

sub is_dna_iupac
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^acgtnmrwsykvhdbx]/i and return;
    return 1;
}

=head2 is_protein

 Title   : is_protein
 Usage   : if($seq->is_protein) { print "The sequence is protein\n" }
 Function: Returns true if the sequence contains only unambiguous
         : single-letter amino acid codes
 Returns : undef or 1
 Args    : None

=cut

sub is_protein
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^acdefghiklmnpqrstvwy\*]/i and return;
    return 1;
}

=head2 is_protein_ambig

 Title   : is_protein_ambig
 Usage   : if($seq->is_protein_ambig) { print "The sequence is
         : ambiguous protein\n" }
 Function: Returns true if the sequence contains only single-letter
         : amino acid codes, including ambiguities
 Returns : undef or 1
 Args    : None

=cut

sub is_protein_ambig
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    $self->str =~ /[^abcdefghiklmnpqrstvwxyz\*]/i and return;
    return 1;
}


=head2 length

 Title   : length
 Usage   : $seqlen = $seq->length;
 Function: Returns the length of the sequence
 Returns : Integer or undef if the sequence string is virtual
 Args    : None

=cut

sub length
{
    my ($self) = @_;

    unless ($self->can('str'))
      {
	carp "[$self] has no str() method; unable to access sequence";
	return;
    }

    my $str  = $self->str;
    my $length;

    if (defined $str)
    {
	$str =~ s/\.\-//g;
	$length = CORE::length($str);
    }
    return $length;
}

1;
