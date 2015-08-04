=head1 NAME

Bio::PSU::Cloner - A class providing an inheritable clone method

=head1 SYNOPSIS

 use Bio::PSU::Cloner;

 use vars qw(@ISA);
 @ISA = qw(Bio::PSU::Cloner);

=head1 DESCRIPTION

Thi class provides a clone method inherited by other Bio::PSU objects
e.g. Bio::PSU::Seq, Bio::PSU::Feature and Bio::PSU::Range.

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

package Bio::PSU::Cloner;

use strict;
use Carp;
use Bio::PSU::Base;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Base);

=head2 clone

 Title   : clone
 Usage   : $object = Bio::PSU::<object>->clone(-arg => 'val')
 Function: Creates a new Bio::PSU::<object> from an existing one. The
         : new object is a copy and is not a reference to the same
         : bit of memory as the cloning object. Object attributes
         : may be changed in the clone by passing arguments to the
         : clone method as if it were the constructor (new method).
 Returns : A Bio::PSU::<object>
 Args    : Same as for constructor

=cut

sub clone
{
    my ($self, %args) = @_;
    my $class = ref($self);
    my $_class_args = $self->_class_args;
    my $_defaults = $self->_dcopy($self->_class_defaults);
    my $_no_dcopy = $self->_class_no_dcopy;
    my $clone = {};

 OBJKEY: foreach my $key (keys %$self)
    {
        # Skip this hash member if its contents are being supplied
        # as an arg to the clone method. Set it to the class default
        foreach my $arg (keys %args)
        {
            # Check that the key is allowed by checking $_class_args
            unless (exists $$_class_args{$arg})
            {
                $self->btrace("Invalid argument <$arg> supplied to clone method while cloning [$self]")
            }

            # Get the hash key by checking $_class_args
            my $objkey = $$_class_args{$arg}[1];

            # Set the key to the class default defined in $_defaults
            if ($objkey eq $key)
            {
                $clone->{$key} = $_defaults->{$key};
                next OBJKEY;
            }
        }

        # Otherwise take a copy for the clone, either by direct copying
        # if clones still need to maintain references to the same data
        # structures/objects as their parents, or otherwise by a _dcopy
        $clone->{$key} = exists $_no_dcopy->{$key} ? $self->{$key} : $self->_dcopy($self->{$key});
    }

    # Note that _init requires a hash reference
    my $newobj = bless({}, $class);
    $newobj->_init($clone, \%args);

    return $newobj;
}

1;
