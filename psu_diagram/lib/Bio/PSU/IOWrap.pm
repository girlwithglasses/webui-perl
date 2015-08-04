=head1 NAME

Bio::PSU::IOWrap - Class providing a simple wrapper to a filehandle
for line-by-line reading with a buffer

=head1 SYNOPSIS

 use Bio::PSU::IOWrap;

 use vars qw(@ISA);
 @ISA = qw(Bio::PSU::IOWrap);

=head1 DESCRIPTION

This is a class which provides methods for line-by-line reading from a
filehandle, with a buffer (which are in turn, contained in a
Bio::PSU::IO::BufferFH object)

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

package Bio::PSU::IOWrap;

use strict;
use Carp;
use Bio::PSU::Base;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Base);

{
    my $_class_defaults = {  bfh_obj => undef };
    my $_class_args     = { -bfh     => [qw(add_bfh bfh_obj)] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }

}

=head2 getline

 Title   : getline
 Usage   : N/A
 Function: Returns the next line from the filehandle if the
         : buffer is empty, otherwise it returns the buffer
         : and then empties it
 Returns : Line, or buffer contents
 Args    : None

=cut

sub getline
{
    my ($self) = @_;

    unless (defined $self->{bfh_obj})
    {
	$self->btrace("[$self] contains no Bio::PSU::IO::BufferFH object to read from")
    }
    return $self->{bfh_obj}->buffered_read;
}

=head2 putline

 Title   : putline
 Usage   : N/A
 Function: Prints the next line to the file/filehandle
 Returns : Nothing
 Args    : String to print

=cut

sub putline
{
    my ($self, $line) = @_;

    unless (defined $self->{bfh_obj})
    {
	$self->btrace("[$self] contains no Bio::PSU::IO::BufferFH object to write to")
    }
    $self->{bfh_obj}->write_line($line);
}

=head2 buffer

 Title   : buffer
 Usage   : N/A
 Function: Adds a line to the buffer
 Returns : The buffer contents
 Args    : String to add to the buffer (optional)

=cut

sub buffer
{
    my ($self, $line) = @_;

    unless (defined $self->{bfh_obj})
    {
	$self->btrace("[$self] contains no Bio::PSU::IO::BufferFH object to hold buffer")
    }
    $self->{bfh_obj}->buffer_line($line) if defined $line;
}

=head2 add_bfh

 Title   : add_bfh
 Usage   : $worker->add_bfh($my_bfh_obj);
 Function: Adds a Bio::PSU::IO::BufferFH (buffered filehandle)
         : object for this object to use for reading/writing
 Returns : Nothing
 Args    : A Bio::PSU::IO::BufferFH object

=cut

sub add_bfh
{
    my ($self, $bfh) = @_;

    unless (ref($bfh) eq 'Bio::PSU::IO::BufferFH')
    {
	$self->btrace("Wrong type of argument passed to constructor. You should pass a Bio::PSU::IOWrap::BufferFH object")
    }
    $self->{bfh_obj} = $bfh;
}

1;
