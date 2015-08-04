
=head1 NAME

Bio::PSU::IO::Fasta::Search - Class representing a stream of
Bio::PSU::IO::Fasta::Result objects from Fasta or Fastx search output

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

This object parses the output of Fasta or Fastx searches (singly, or
concatenated into a stream) and produces a series of
Bio::PSU::IO::Fasta::Result objects which represent the result of
searching one query sequence against the database(s).

Each object will produce a list of Bio::PSU::IO::Fasta::Hit objects
representing the individual hits of the query sequence to various
subject sequences in the database.

The Fasta search should be run using the -m 10 command line switch
(this just produces a more easily parseable output).

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

package Bio::PSU::IO::Fasta::Search;

use strict;
use Carp;
use Bio::PSU::IOWrap;
use Bio::PSU::IO::Fasta::Result;
use Bio::PSU::IO::Fasta::Hit;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

=head2 new

 Title   : new
 Usage   : $search = Bio::PSU::IO::Fasta::Search->new(-bfh => $my_bfh)
 Function: Creates a new Fasta search object. This holds details
         : of a search
 Returns : A Bio::PSU::IO::Fasta::Search object
 Args    : A Bio::PSU::IO::BufferFH object

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = Bio::PSU::IOWrap->new($args);
    bless($self, $class);

    my $caller = caller;
    $self->_check_args($args, $caller);

    return $self;
}

=head2 next_result

 Title   : next_result
 Usage   : $result = $stream->next_result
 Function: Returns the next Bio::PSU::IO::Fasta::Result object
         : from the stream
 Returns : A Bio::PSU::IO::Fasta::Result object
 Args    : None

=cut

sub next_result
{
    my ($self) = @_;
    my $result;
    my ($lib_name, $lib_size, $lib_seqs, $mp_argv, $mp_name, $mp_ver,
	$pg_matrix, $pg_gopen, $pg_gext, $pg_ktup, $pg_optcut, $pg_cgap);

 LINE: while (1)
    {
	my $line = $self->getline;

	# Skip this block if we are at EOF
	last LINE unless defined $line;

	# Ignore blank lines
	next LINE if $line =~ /^$/;

	# Exit at the end of a report
	last LINE if $line =~ /^>>><<<$/;

	# Residue and sequence counts in header
	if ($line =~ /(\d+)\s+residues\s+in\s+(\d+)\s+sequences/)
	{
	    ($lib_size, $lib_seqs) = ($1, $2);
	    next LINE;
	}

	# Program details block
	if ($line =~ /^>>>.+vs\s+(\S+)\s+library$/)
	{
	    $lib_name = $1;

	PLINE: while (1)
	    {
		my $pline = $self->getline;

		if ($pline =~ /^>>/)
		{
		    $self->buffer($pline);

		    $result = Bio::PSU::IO::Fasta::Result->new
			(-database  => $lib_name,
			 -db_size   => $lib_size,
			 -db_seqs   => $lib_seqs,
			 -mp_argv   => $mp_argv,
			 -mp_name   => $mp_name,
			 -mp_ver    => $mp_ver,
			 -pg_matrix => $pg_matrix,
			 -pg_gopen  => $pg_gopen,
			 -pg_gext   => $pg_gext,
			 -pg_ktup   => $pg_ktup,
			 -pg_optcut => $pg_optcut,
			 -pg_cgap   => $pg_cgap,
			 -bfh       => $self->{bfh_obj});

		    last LINE;
		}

		if ($pline =~ /^; mp_argv:\s+(.*)/)
		{
		    $mp_argv = $1;
		    next PLINE;
		}

		if ($pline =~ /^; mp_name:\s+(\S+)/)
		{
		    $mp_name = $1;
		    next PLINE;
		}

		if ($pline =~ /^; mp_ver:\s+(.*)/)
		{
		    $mp_ver = $1;
		    next PLINE;
		}

		if ($pline =~ /^; pg_matrix:\s+(.*)/)
		{
		    $pg_matrix = $1;
		    next PLINE;
		}

		if ($pline =~ /^; pg_gap-pen:\s+(-?\d+) (-?\d+)/)
		{
		    ($pg_gopen, $pg_gext) = ($1, $2);
		    next PLINE;
		}

		if ($pline =~ /^; pg_ktup:\s+(\d+)/)
		{
		    $pg_ktup = $1;
		    next PLINE;
		}

		if ($pline =~ /^; pg_optcut:\s+(\d+)/)
		{
		    $pg_optcut = $1;
		    next PLINE;
		}

		if ($pline =~ /^; pg_cgap:\s+(\d+)/)
		{
		    $pg_cgap = $1;
		    next PLINE;
		}
	    }
	}
    }
    return $result;
}

1;
