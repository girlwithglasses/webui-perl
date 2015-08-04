=head1 NAME

Bio::PSU::IO::Token - An token object which contains a tag and
a value

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

A simple token object which contains two values; a tag (token
name) and the token itself.

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

package Bio::PSU::IO::Token;

use strict;

=head2 new

 Title   : new
 Usage   : $token = Bio::PSU::IO::Token->new(-name => $name, -text
         : => $val);
 Function: Creates a new Bio::PSU::IO::Token object
 Returns : Bio::PSU::IO::Token object
 Args    : -name, -text (strings)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = @_;

    my $self = [];

    $self->[0] = $args{'-name'};
    $self->[1] = $args{'-text'};

    bless($self, $class);
    return $self;
}

=head2 name

 Title   : name
 Usage   : $name = $token->name;
         : $token->name('LOCATION');
 Function: Returns or sets the token name
 Returns : String
 Args    : Token name as (string, optional)

=cut

sub name
{
    my ($self, $name) = @_;

    $self->[0] = $name if defined $name;
    return $self->[0];
}

=head2 text

 Title   : text
 Usage   : $text = $token->text;
         : $token->text($value);
 Function: Returns or sets the token text
 Returns : String
 Args    : Token text (string, optional)

=cut

sub text
{
    my ($self, $text) = @_;

    $self->[1] = $text if defined $text;
    return $self->[1];
}

1;
