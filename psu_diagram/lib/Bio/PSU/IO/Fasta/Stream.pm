=head1 NAME

Bio::PSU::IO::Fasta::Stream - Object providing a stream of Bio::PSU::Seq
objects from an Fasta format source

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

A Bio::PSU::IO::Fasta::Stream provides a next_seq method which returns
a Bio::PSU::Seq object. It also provides a write_seq method which
performs the reverse operation and will write a stream of Fasta
sequences if provided with Bio::PSU::Seq objects.

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

package Bio::PSU::IO::Fasta::Stream;

use strict;
use Carp;
use Bio::PSU::IOWrap;
use Bio::PSU::Seq;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

{
    my $_class_defaults = {};
    my $_class_args     = { -type => [qw(type type)] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $stream = Bio::PSU::IO::Fasta::Stream->new(-bfh => $bfh);
 Function: Reads Fasta format input via a filehandle which can be to
         : a file or a pipe from getz, efetch etc. You can use it
         : directly, but there is a Bio::PSU::Seqfactory object to do
         : this for you. The filehandle is wrapped in an
         : Bio::PSU::IO::BufferFH object
 Returns : A stream of Bio::PSU::Seq objects
 Args    : A Bio::PSU::IO::BufferFH object

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
    $self->_init($self, $args);

    return $self;
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq;
 Function: Returns the next Seq object from a stream. Being
         : Fasta format, there are no features
 Returns : A Bio::PSU::Seq object
 Args    : None

=cut

sub next_seq
{
    my ($self) = @_;
    my ($header, $seq);

    # Default values if none can be found
    my ($id, $desc, $str) = ("no_id", "no desc", "");

 LINE: while (1)
    {
	my $line = $self->getline;

	# Skip this block of we are at EOF
	last LINE unless defined $line;

	# Skip any blank lines
	next LINE if $line =~ /^$/;

	# If the line is a header
	if ($line =~ /^>/)
	{
	    # If we already have a header, the new one belongs to the next sequence.
	    # We put the new header back into the buffer for the next pass.
	    if (defined $header)
	    {
		$self->buffer($line);
		last LINE; # The sequence is finished
	    }
	    else
	    {
		$header = $line;
		next LINE; # The sequence is starting
	    }
	}
	# If we get this far we have sequence to store
	$str .= $line;
    }

    # If we got a header we make a sequence object to return
    if (defined $header)
    {
	if ($header =~ /^>(\S+)(.*)/)
	{
	    ($id, $desc) = ($1, $2);
	    $desc =~ s/^\s+//;
	}

	# Remove any spaces
	$str =~ s/\s//g;

	$seq = Bio::PSU::Seq->new(-id   => $id,
				  -desc => $desc,
				  -str  => $str,
				  -type => $self->type);
    }

    # This is undef unless we had a header
    return $seq;
}

=head2 write_seq

 Title   : write_seq
 Usage   : $stream->write_seq($seq);
 Function: Writes a Seq object to a stream. Being
         : Fasta format, features are ignored
 Returns : Nothing
 Args    : A Bio::PSU::Seq object

=cut

sub write_seq
{
    my ($self, $seq) = @_;

    if (! defined $seq)
    {
	$self->btrace("Unable to write sequence. No sequence supplied")
    }
    if (! ref($seq) or ! $seq->isa('Bio::PSU::Seq'))
    {
	$self->btrace("Unable to write [$seq] as it is not an Bio::PSU::Seq object")
    }

    my $header = sprintf ">%s %s\n", $seq->id, $seq->desc;
    $self->putline($header);

    my $str = $seq->str;

    unless (defined $str)
    {
	carp "[$self] skipping write of Fasta format ", $seq->id, " as it contains no sequence";
	return;
    }

    while ($str=~ /(.{1,60})/g)
    {
	$self->putline("$1\n")
    }
    return 1;
}

=head2 type

 Title   : type
 Usage   : $stream->type($type);
 Function: Explicitly sets the sequence type being read for
         : passing on to the Bio::PSU::Seq object. The content of
         : this variable is validated when the Bio::PSU::Seq object
         : is created, so we don't worry about it here
 Returns : Sequence type (string)
 Args    : Seq type (string)

=cut

sub type
{
    my ($self, $type) = @_;

    $self->{type} = $type if defined $type;
    return $self->{type};
}

1;
