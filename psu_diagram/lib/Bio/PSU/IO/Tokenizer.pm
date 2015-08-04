=head1 NAME

Bio::PSU::IO::Tokenizer - Class providing a series of Bio::PSU::IO::Token
objects from an input string

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

An Bio::PSU::IO::Tokenizer object requires a list of token definitions
and a string to work on. Its only option is full tokenization of the
string i.e. it breaks up the whole string and returns a list of
Bio::PSU::IO::Token objects. It needs some improvement with regard to
flexibility and performance.

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

package Bio::PSU::IO::Tokenizer;

use strict;
use Bio::PSU::IO::Token;

=head2 new

 Title   : new
 Usage   : $tokenizer = Bio::PSU::IO::Tokenizer->new(\@tokens)
 Function: Creates a new Bio::PSU::IO::Tokenizer object from
         : a set of token definitions (name + regular expression)
 Returns : An Bio::PSU::IO::Tokenizer object
 Args    : Reference to a list of hashes (token definitions)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

    $self->{pos}       = 0;
    $self->{tokendefs} = shift;
    $self->{tokens}    = [];

    bless($self, $class);

    $self->{matcher} = $self->_set_match;
    return $self;
}

=head2 tokenize

 Title   : tokenize
 Usage   : $tokenizer->tokenize($location);
 Function: Tokenizes a string into a list of Bio::PSU::IO::Token
         : objects held inside the tokenizer
 Returns : Number of tokens made
 Args    : String to be tokenized

=cut

sub tokenize
{
    my ($self, $block) = @_;

    $self->{block} = $block;
    my $sub = $self->{matcher};

    while (my $token = $sub->($self))
    {
	push(@{$self->{tokens}}, $token);
    }
    return scalar @{$self->{tokens}};
}

=head2 next

 Title   : next
 Usage   : $token = $tokenizer->next
 Function: Removes the next Bio::PSU::IO::Token object from
         : inside the tokenizer
 Returns : A Bio::PSU::IO::Token object
 Args    : None

=cut

sub next
{
    my ($self) = @_;

    return shift @{$self->{tokens}};
}

=head2 _make_token

 Title   : _make_token
 Usage   : N/A
 Function: Creates a new Bio::PSU::IO::Token object
 Returns : A Bio::PSU::IO::Token object
 Args    : Name and text of token to be created

=cut

sub _make_token
{
    my ($name, $text) = @_;

    my $token = Bio::PSU::IO::Token->new(-name => $name,
					 -text => $text);
    return $token;
}

=head2 _set_match

 Title   : _set_match
 Usage   : N/A
 Function: Returns a reference to an anonymous subroutine which
         : is created by eval-ing code generated on the fly
         : when the tokenizer is initialized. This allows the
         : /o (compile once) optimization of the regular
         : expressions. Without this, there is a big performance
         : penalty
 Returns : Reference to an anonymous sub
 Args    : None

=cut

sub _set_match
{
    my ($self) = @_;
    my $code = "";

    $code .= 'sub {';
    $code .= '$self = shift;';
    $code .= 'my ($text, $token);';
    $code .= 'CASE: {';

    # Insert the values of $_->{regex} and $_->{name} into the code
    # for each token matcher. A new case is added to the statement
    # for each token definition.
    foreach (@{$self->{tokendefs}})
    {
	$code .= 'if ($self->{block} =~ /\G(' . "$_->{regex}" . ')/cgos)';
	$code .= '{';
	$code .= '$token = _make_token(\'' . "$_->{name}" . '\', $1);';
	$code .= 'last CASE;';
	$code .= '}';
    }

    $code .= '}';
    $code .= 'return $token;';
    $code .= '}';

    my $sub = eval $code;
    return $sub;
}

1;


