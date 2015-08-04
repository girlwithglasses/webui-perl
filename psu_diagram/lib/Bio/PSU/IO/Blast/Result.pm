=head1 NAME

Bio::PSU::IO::Blast::Result - Object representing the result
of one Blast search against a library

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

This object represents the result of one Blast search. It makes
available details of the program version and settings, the database
and a method to return Bio::PSU::IO::Blast::Hit objects.

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

package Bio::PSU::IO::Blast::Result;

use strict;
use Carp;
use Bio::PSU::IOWrap;
use Bio::PSU::IO::Blast::Hit;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

{
    my $_class_defaults = { database => undef,
			    q_id     => undef,
			    q_len    => undef,
			    type     => undef };

    my $_class_args     = { -database => [qw(_defer database)],
			    -q_id     => [qw(_defer q_id    )],
			    -q_len    => [qw(_defer q_len   )],
			    -type     => [qw(_defer type    )] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}


=head2 new

 Title   : new
 Usage   : $result = Bio::PSU::IO::Blast::Result->new(-bfh =>
         : $buffered_fh, -database => $db,
         : -q_id => $qname, -type => 'BLASTN');
 Function: Creates a new Blast result object. This holds details
         : of the search conditions and provides access to Hit
         : objects
 Returns : A Bio::PSU::IO::Blast::Result object
 Args    : -bfh Bio::PSU::BufferFH object, -database (string),
         : -q_id (string), -type (string) (e.g. BLASTN/P/X)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = Bio::PSU::IOWrap->new($args);
    bless($self, $class);

    # Merge $self with defaults
    my $_defaults = $self->_dcopy($self->_class_defaults);
    $self->_merge_hash($_defaults);

    # Init using inherited data in $self
    my $deferred  = $self->_init($self, $args);

    foreach (keys %$deferred)
    {
	my $val = delete $deferred->{$_};
	if (/^-database$/) { $self->{database} = $val; next }
	if (/^-q_id$/)     { $self->{q_id}     = $val; next }
	if (/^-q_len$/)    { $self->{q_len}    = $val; next }
	if (/^-type$/)     { $self->{type}     = $val; next }
    }

    $self->_check_args($args);

    return $self;
}

=head2 next_hit

 Title   : next_hit
 Usage   : $hit = $result->next_hit;
 Function: Returns the next Hit object from the stream
 Returns : A Bio::PSU::IO::Fasta::Hit object
 Args    : None

=cut

sub next_hit
{
    my ($self) = @_;
    my ($hit, @hitblock);

 HITLINE: while (1)
    {
	my $hitline = $self->getline;

	# Skip this block if we are at EOF
	last HITLINE unless defined $hitline;

	# Ignore blank lines
	next HITLINE if $hitline =~ /^\s*$/;

	# Exit at the start of a new report
	if ($hitline =~ /^T?BLAST/)
	{
	    $self->buffer($hitline);
	    last HITLINE;
	}

	# Get the first line of the next hit
	if ($hitline =~ /^>/)
	{
	    push(@hitblock, $hitline);

	    # Get the remainder of the hit
	HIT: while (1)
	    {
		$hitline = $self->getline;

		if ($hitline =~ /Score =/)
		{
		    $self->buffer($hitline);
		    last HITLINE;
		}
		push(@hitblock, $hitline) unless $hitline =~ /^\s*$/;
	    }
	}
    }

    if (@hitblock)
    {
	my ($s_id, $s_desc, $s_len);

	while (my $line = shift @hitblock)
	{
	    if ($line =~ /^>(\S+)\s+(.*)/)
	    {
		($s_id, $s_desc) = ($1, $2);
		next;
	    }
	    elsif ($line =~ /^>(\S+)/)
	    {
		$s_id   = $1;
		$s_desc = "none";
		next;
	    }

	    if ($line =~ /^\s+Length = (\S+)/)
	    {
		$s_len  = $1;
		$s_len  =~ s/,//g;

		$s_desc =~ s/\s+/ /g;
		$s_desc =~ s/\n//g;
		last;
	    }
	    else
	    {
		$s_desc .= $line
	    }
	}

	$hit = Bio::PSU::IO::Blast::Hit->new
	    (-q_id     => $self->{q_id},
	     -q_len    => $self->{q_len},
	     -s_id     => $s_id,
	     -s_len    => $s_len,
	     -s_desc   => $s_desc,
	     -bfh      => $self->{bfh_obj});
    }

    return $hit;
}

=head2 q_id

 Title   : q_id
 Usage   : $query_name = $result->q_id;
 Function: Returns the query id
 Returns : String
 Args    : None

=cut

sub q_id
{
    my ($self) = @_;
    return $self->{q_id};
}

=head2 q_len

 Title   : q_len
 Usage   : $query_length = $result->q_len;
 Function: Returns the query length
 Returns : Integer
 Args    : None

=cut

sub q_len
{
    my ($self) = @_;
    return $self->{q_len};
}

=head2 database

 Title   : database
 Usage   : $database = $result->database;
 Function: Returns the database name
 Returns : String
 Args    : None

=cut

sub database
{
    my ($self) = @_;
    return $self->{database};
}

=head2 type

 Title   : type
 Usage   : $type = $result->type;
 Function: Returns the type of Blast search
 Returns : String
 Args    : None

=cut

sub type
{
    my ($self) = @_;
    return $self->{type};
}

1;
