=head1 NAME

Bio::PSU::Base - Base class which provides constructor and other
utility methods

=head1 SYNOPSIS

 use Bio::PSU::Base;
 use vars qw(@ISA);

 @ISA = qw(Bio::PSU::Base);

=head1 DESCRIPTION

The Bio::PSU::Base class provides a constructor for other Bio::PSU
classes. It also provides the _init, _check_args, _dcopy and
_merge_hash internal methods used to setup objects.

This currently only works for objects which are blessed hashes. Any
class which inherits from Bio::PSU::Base needs to implement two
methods:

B<_class_defaults>

This should return a hash reference with the keys and corresponding
values being those the object should be initialised with. The _dcopy
method takes a copy to pass to the _init method. The other argument to
_init is the list of arguments (if any) which were supplied to the
constructor. It is _init which processes the arguments and initialises
values in the newly created object.

B<_class_args>

This should return a hash reference with the keys being the arguments
recognised by the constructor and the values being array
references. The arrays should contain two values; index 0 being the
method to call and index 1 being the hash key of the new object used
to store the resulting value.

The method specified by %_class_args is called with the argument
supplied to the constructor. Any arguments not in the %_class_args
hash are ignored so that when constructing an object which inherits
from another class, both it and its parent can be passed the same
argument list and they will each pick the ones they need, ignoring the
rest.

The argument list is passed by reference and the _check_args method
may be used at the end of the chain of initialisations to check for
unused arguments (probably invalid or misspelled).

e.g.

my $_class_defaults = { zap => undef,
                        zip => undef,
                        zop => undef };

my $_class_args = { -a => [qw(fee    zap)],
                    -b => [qw(bing   zip)],
                    -c => [qw(_defer zop)] };

sub _class_defaults { $_class_defaults }
sub _class_args     { $_class_args     }

$obj = Bio::PSU::object->new(-a => 'foo', -b => 'bar');

Now 'foo' will be passed to method fee by _init, while 'bar' will be
passed to method bing. The special token '_defer' indicates that the
_init method will not handle this argument and will return it to be
processed by a constructor which overrides the inherited one:

e.g. the constructor in Bio::PSU::IO::Blast::Result overrides the
one it inherits from Bio::PSU::Base

 sub new
 {
     my $proto = shift;
     my $class = ref($proto) || $proto;
     my $args  = ref $_[0] eq 'HASH' ? shift : { @args };

     my $self  = Bio::PSU::IOWrap->new($args);

     bless($self, $class);

     my $_defaults = $self->_dcopy(_class_defaults);
     $self->_merge_hash($_defaults);

     my $deferred  = $self->_init($self, $args);

     foreach (keys %$deferred)
     {
	 my $val = delete $deferred->{$_};
	 if (/^-database$/) { $self->{database} = $val; next }
	 if (/^-query$/)    { $self->{query}    = $val; next }
	 if (/^-type$/)     { $self->{type}     = $val; next }
     }

     $self->_check_args($args);

     return $self;
 }

The arguments not handled by _init are passed to the %deferred hash
where the constructor has its own way of initialising the object with
these values. A lot of these could be replaced with, say, a generic
set_attr method inherited from the Base class because all the
information required to set these attributes is present in the
%_class_args hash (i.e. the parameter and the hash key to index the
argument passed). This might be too slow.

Finally a call to the _check_args method will report any argument(s)
not used by any constructor. These will probably be invalid or
misspelled etc.

The values at index 1 in the anonymous array within %_class_args are
used when cloning objects. This process bypasses the normal _init
method and copies the hash values of an object directly. Arguments to
the clone method are used to set certain hash keys in the object back
to their defaults and then to call _init on them with new values. This
results in a clone with some (or possibly none) of its attributes
changed. The values at index 1 are simply the hash keys associated
with the arguments to the clone method, which are the same as those
allowed for the constructor.

In the example above, the object hash key 'zap' is set back to its
default value during a clone operation where an argument -a is passed.

e.g.

 $obj2 = Bio::PSU::object->clone(-a => 'fip')

Subsequently _init is called on the object and 'fip' will be passed to
the method fee (see the first example, above).

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
redistributed under the same conditions as Perl itself.

=cut

package Bio::PSU::Base;

use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '0.04';

=head2 new

 Title   : new
 Usage   : $object = Bio::PSU::<class>->new(-arg => 'val');
 Function: Creates a new Bio::PSU object of <class>. This is the
         : default constructor which may be overridden by
         : classes inheriting from Bio::PSU::Base
 Returns : A Bio::PSU::<class> object
 Args    : Depends on those specified in $_class_args

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = {};
    bless($self, $class);

    my $_defaults = $self->_dcopy($self->_class_defaults);
    $self->_init($_defaults, $args);

    $self->_check_args($args, scalar(caller));

    return $self;
}

=head2 _init

 Title   : _init
 Usage   : N/A
 Function: Object initialisation from default values which may be
         : overridden by arguments supplied to the constructor. Any
         : arguments marked as not to be handled by this method
         : (indicated by the class_args hash containing the token
         : _defer) are returned
 Returns : Hash of deferred arguments
 Args    : Reference to a hash of defaults, plus the arguments to
         : the constructor

=cut

sub _init
{
    my ($self, $_defaults, $args) = @_;
    my $defer = {};

    %$self = %$_defaults;
    my $_class_args = $self->_class_args;

    foreach my $arg (keys %$args)
    {
	# Pass over arguments which this class does not recognise. A
	# class which inherits from this may use these arguments later.
	next unless exists $$_class_args{$arg};

	my $val = $args->{$arg};

	# Remove arguments which this class has explicitly indicated
	# that it will handle itself (my means of the _defer token)
	if ($$_class_args{$arg}[0] eq '_defer')
	{
	    $defer->{$arg} = $val;
	    delete($args->{$arg});
	    next;
	}

	my $code = '$self->' . $$_class_args{$arg}[0] . '($val)';
	eval $code;

	if ($@)
	{
	    $self->btrace("Error creating _init for [$self]':\n"
			  . "$@\n"
			  . "-" x 70, "\n"
			  . $code);
	}
	delete($args->{$arg});
    }
    return $defer;
}

=head2 _merge_hash

 Title   : _merge_hash
 Usage   : N/A
 Function: Object initialisation from default values while
         : preserving inherited data. Merges the class defaults
         : hash with $self. If the second argument is set to
         : true then defaults will be allowed to overwrite
         : inherited values
 Returns : Nothing
 Args    : Hash to merge and boolean (overwrite values, or not)

=cut

sub _merge_hash
{
    my ($self, $hash, $override) = @_;

 KEY: foreach my $key (keys %$hash)
    {
	if (exists $self->{$key})
	{
	    carp "[$self] tried to override $key with a default value" unless $override;
	    next KEY;
	}
	$self->{$key} = $self->_dcopy($hash->{$key});
    }
}

=head2 _dcopy

 Title   : _dcopy
 Usage   : N/A
 Function: Creates a deep copy of hash. The original code here was
         : similar in approach, but less flexible. Code from a post
         : on comp.lang.perl.moderated by Ned Konz was used for
         : pointers to improve my original attempt
 Returns : A hash containing copied values
 Args    : Hash to be copied

=cut

sub _dcopy
{
    my ($self, $value) = @_;
    my $type = ref($value);
    my $copy;

 CASE:
    {
	if (! $type)
	{
	    $copy = $value;
	    last CASE;
	}

	if ($type eq 'REF')
	{
	    $copy = \$self->_dcopy($$value);
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'SCALAR'))
	{
	    my $scalar = $$value;
	    $copy = \$scalar;
	    bless($copy, $type) if $type ne 'SCALAR';
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'HASH'))
	{
	    $copy = {};

	    if ($type ne 'HASH')
	    {
		# The hash has been blessed into some class,
		# so find which keys of instances of that class
		# we avoid using _dcopy on, so that we maintain
		# references, instead of making new copies
		my $_no_dcopy = $type->_class_no_dcopy;

		foreach (keys %$value)
		{
		    $copy->{$_} = exists $_no_dcopy->{$_} ? $value->{$_} : $self->_dcopy($value->{$_})
		}
	    }
	    else
	    {
		map { $copy->{$_} = $self->_dcopy($value->{$_}) } keys %$value
	    }

	    bless($copy, $type) if $type ne 'HASH';
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'ARRAY'))
	{
	    $copy = [];
	    @$copy = map { $self->_dcopy($_) } @$value;
	    bless($copy, $type) if $type ne 'ARRAY';
	    last CASE;
	}

	# Fall-through condition
	$self->btrace("Unable to clone element from [$self]: $value");
    }
    return $copy;
}

=head2 _check_args

 Title   : _check_args
 Usage   : N/A
 Function: Warns if arguments have been passed to constructor(s)
         : and subsequently not used (i.e. are probably invalid
         : or misspelled). The caller argument to _check_args is
         : necessary if other classes inherit the constructor.
 Returns : Nothing
 Args    : Reference to args hash, caller as scalar (optional)

=cut

sub _check_args
{
    my ($self, $args, $caller) = @_;
    my $package = ref $self;

    if (defined $caller)
    {
	return unless ($caller eq 'main' or $caller eq $package)
    }

    foreach (keys %$args)
    {
	carp "Invalid arg <$_> passed to constructor of [$self]"
    }
}

=head2 _class_defaults [abstract method]

 Title   : _class_defaults
 Usage   : N/A
 Function: Accesses the hash of default values for object
         : that class
 Returns : Hash reference
 Args    : None

=cut

sub _class_defaults
{
    my ($self) = @_;
    my $package = ref $self;

    $self->btrace("$package has not implemented the _class_defaults method");
}

=head2 _class_args [abstract method]

 Title   : _class_args
 Usage   : N/A
 Function: Accesses the hash of default arguments accepted
         : by the constructor of that class. The hash also
         : contains details of what hash key in the object
         : is used to store that data, and what method (if
         : any) is used to put it there
 Returns : Hash reference
 Args    : None

=cut

sub _class_args
{
    my ($self) = @_;
    my $package = ref $self;

    $self->btrace("$package has not implemented the _class_args method");
}

=head2 _class_no_dcopy

 Title   : _class_no_dcopy
 Usage   : N/A
 Function: Contains any object hash keys which should be skipped
         : during _dcopy operations. e.g. When cloning a feature
         : one does not want the _dcopy to follow the hash reference
         : at key 'str' because this would create a new copy of the
         : parent sequence for each feature cloned. These values
         : simply copied so that, taking features as a example,
         : all the clones still reference the same sequence as their
         : templates
 Returns : Hash reference
 Args    : None

=cut

sub _class_no_dcopy
{
    my ($self) = @_;

    # Unless overridden this method return a reference to an empty
    # hash, indicating that there are no hash keys which should
    # be skipped
    return {};
}

=head2 btrace

 Title   : btrace
 Usage   : $self->btrace("This is why we died here")
 Function: Prints a nicer stack backtrace than confess.
         : Installed into UNIVESRAL, so available to all
         : classes
 Returns : Nothing
 Args    : Message to report on exit

=cut

sub UNIVERSAL::btrace
{
    my ($self, $message) = @_;

    my ($i, $stack, $reason, $script, $p, $f, $l, $s, $h);
    my (@a, @stacktrace, @stackargs);

    require Text::Wrap;
    package DB;

    while (@a = caller($i++))
    {
	($p, $f, $l, $s, $h) = @a;

	my @args = map { defined $_ ? $_ : "undef" } @DB::args;

	@args = map { length($_) < 50 ? $_ : substr($_, 0, 47). "..." } @args;

	my $a = @args ? join(", ", @args) : "";

	if ($i == 1)
	{
	    $reason = sprintf("%s at %s line %d\n", $message, $p, $l);
	    next;
	}

 	push(@stacktrace, sprintf("%s called %s [at line %d]", $p, $s, $l));

	push(@stackargs, "ARGS: ($a)");

	$script = $f;
    }

    $Text::Wrap::columns = 80;

    print STDERR "BACKTRACE from $script\n", "-" x 80, "\n";

    for (my $j = 0; $j < @stacktrace; $j++)
    {
	print STDERR Text::Wrap::wrap("$j ", "  ", $stacktrace[$j]), "\n";
	print STDERR Text::Wrap::wrap("  ", "  ", $stackargs[$j]), "\n";
    }

    print STDERR "-" x 80, "\n";

    die Text::Wrap::wrap("\n", "", $reason, "\n");
}

1;
