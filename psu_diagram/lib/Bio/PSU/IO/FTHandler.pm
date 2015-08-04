=head1 NAME

Bio::PSU::IO::FTHandler - A class providing methods for parsing and
writing EMBL and Genbank feature tables

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This is a class which provides a methods for parsing and writing EMBL
and Genbank feature tables.

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

package Bio::PSU::IO::FTHandler;

use strict;
use Carp;
use Bio::PSU::IOWrap;
use Bio::PSU::IO::Tokenizer;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

{
    my $_tokens = [
		   { name   => 'DQUOTE',
		     regex  => qq!"[^"]*"! },

		   { name  => 'COLON',
		     regex => ':' },

		   { name  => 'FUZZY',
		     regex => '\(?\d+\.\d+\)?' },

		   { name  => 'JOIN',
		     regex => 'join\(|order\(' },

		   { name  => 'COMP',
		     regex => 'complement\(' },

		   { name  => 'RANGE',
		     regex => '[<>]?\d+' },

		   { name  => 'SEP',
		     regex => '\.\s?\.|\^|:' },

		   { name  => 'LEFTP',
		     regex => '\(' },

		   { name  => 'RIGHTP',
		     regex => '\)' },

		   { name  => 'COMMA',
		     regex => ',' },

		   { name  => 'SLASH',
		     regex => '\/' },

		   { name  => 'EQUALS',
		     regex => '=' },

		   { name  => 'TEXT',
		     regex => '[A-Za-z_\-\+\.\*\:\;\'\"\[\]\ ]+' },

		   { name  => 'NEWLINE',
		     regex => '\n' },

		   { name  => 'OTHER',
		     regex => '.+' }
		  ];

    my $unquoted = [qw(antidocon direction citation codon codon_start
                       cons_splice evidence label mod_base number organelle
                       rearranged rpt_type rpt_unit transl_except transl_table
                       usedin)];


    my $_class_defaults = { tokenizer => undef,
			    noprint   => [qw(no_width no_3prime no_5prime)],
			    unquoted  => $unquoted };

    my $_class_args     = { -tzr => [qw(add_tokenizer tokenizer)] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
    sub _tokens         { $_tokens         }
}

=head2 new

 Title   : new
 Usage   : $handler = Bio::PSU::IO::FTHandler->new;
         : $handler = Bio::PSU::IO::FTHandler->new(-tzr => $special);
 Function: Parses EMBL/Genbank feature tables after the leader
         : (e.g. FT + spaces, for EMBL) has been removed
 Returns : A Bio::PSU::IO::FTHandler object
 Args    : -tzr Bio::PSU::IO::Tokenizer object (optional) if you
         : want to override the default tokenizer

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

    $self->_check_args($args, scalar(caller));

    unless (defined $self->{tokenizer})
    {
	$self->add_tokenizer(Bio::PSU::IO::Tokenizer->new($self->_tokens))
    }
    return $self;
}

=head2 add_tokenizer

 Title   : add_tokenizer
 Usage   : $self->add_tokenizer($tokenizer);
 Function: Replaces the current tokenizer used within the FThandler
         : with a new one
 Returns : Nothing
 Args    : Bio::PSU::IO::Tokenizer object

=cut

sub add_tokenizer
{
    my ($self, $tokenizer) = @_;

    unless (ref($tokenizer) eq 'Bio::PSU::IO::Tokenizer')
    {
	$self->btrace("[$self] expected an Bio::PSU::IO::Tokenizer object as argument")
    }
    $self->{tokenizer} = $tokenizer;
}

=head2 parse_location

 Title   : parse_location
 Usage   : my @ranges = $self->parse_location($location_string);
 Function: Creates one or more Bio::PSU::Range objects from an EMBL
         : location
 Returns : A list of Bio::PSU::Range objects
 Args    : EMBL location (string)

=cut

sub parse_location
{
    my ($self, $location) = @_;
    my (@ranges, $range, @range_parts, @parens, $instruct, $error);

    $self->{tokenizer}->tokenize($location);

 TOKEN: while (1)
    {
	my $token = $self->{tokenizer}->next;

	unless (defined $token)
	{
	    # @parens will evaluate to non-zero unless the parentheses
	    # associated with complements and joins were successfully
	    # closed
	    if (@parens)
	    {
		carp "Unbalanced parentheses in feature location [$location]"
	    }
	    # Process any remaining location data
	    elsif (@range_parts)
	    {
		$range = $self->_build_range(@range_parts);
		push(@ranges, $range);
	    }
	    last TOKEN;
	}

    SWITCH:
	{
	    if ($token->name eq 'TEXT' or $token->name eq 'COLON')
	    {
		carp "Parsing of location [$location] is not supported: skipping feature";
		$error++;
		last TOKEN;
	    }

	    if ($token->name eq 'JOIN')
	    {
		push(@parens, 'join');
		last SWITCH;
	    }

	    if ($token->name eq 'COMP')
	    {
		push(@parens, 'comp');
		last SWITCH;
	    }

	    if ($token->name eq 'RANGE')
	    {
		push(@range_parts, $token->text);
		last SWITCH;
	    }

	    if ($token->name eq 'FUZZY')
	    {
		push(@range_parts, $token->text);
		last SWITCH;
	    }

	    if ($token->name eq 'SEP')
	    {
		push(@range_parts, $token->text);
		last SWITCH;
	    }

	    if ($token->name eq 'RIGHTP')
	    {
		$instruct = pop(@parens);

		if (@range_parts)
		{
		    $range = $self->_build_range(@range_parts);
		    push(@ranges, $range);
		}
		if ($instruct eq 'comp')
		{
		    foreach (@ranges)
		    {
			next unless defined;
			$_->strand(-1);
		    }
		}

		@range_parts = ();
		last SWITCH;
	    }

	    if ($token->name eq 'COMMA')
	    {
		if (@range_parts)
		{
		    $range = $self->_build_range(@range_parts);
		    push(@ranges, $range);
		}

		@range_parts = ();
		last SWITCH;
	    }

	    if ($token->name eq 'OTHER')
	    {
		carp "Error parsing location [$location] at: ", $token->text;
		$error++;
		last TOKEN;
	    }

	    my $nothing = 1;
	}
    }

    # If there is an error parsing one of the ranges we drop the whole
    # feature. Maybe we could keep the remaining ranges (if any)
    # and make a feature from that?
    @ranges = () if $error;

    return @ranges;
}


=head2 parse_qualifiers

 Title   : parse_qualifiers
 Usage   : my %quals = $self->parse_location($qualifier_block);
 Function: Creates a hash containing qualifier names as keys, indexing
         : anonymous lists of qualifier values. The argument is a
         : block of lines containing the qualifiers, with the leading
         : characters (FT + spaces in EMBL format, just spaces in
         : Genbank format) stripped off
 Returns : Hash of lists
 Args    : EMBL qualifier block (string)

=cut

sub parse_qualifiers
{
    my ($self, $qualifiers) = @_;
    my ($qual, $sep, $value, %qualifiers);

    $self->{tokenizer}->tokenize($qualifiers);

 TOKEN: while (1)
    {
	my $token = $self->{tokenizer}->next;

	# Add the last qualifier before exiting the loop
	unless (defined $token)
	{
	    $value =~ s/\s+$// if defined $value;
	    if (exists $qualifiers{$qual})
	    {
		push(@{$qualifiers{$qual}}, $value)
	    }
	    else
	    {
		$qualifiers{$qual} = [$value]
	    }
	    last TOKEN;
	}

    SWITCH:
	{
	    if ($token->name eq 'SLASH')
	    {
		if (defined $qual)
		{
		    $value =~ s/\s+$// if defined $value;
		    if (exists $qualifiers{$qual})
		    {
			push(@{$qualifiers{$qual}}, $value)
		    }
		    else
		    {
			$qualifiers{$qual} = [$value]
		    }

		    $qual  = undef;
		    $sep   = undef;
		    $value = undef;
		}
		last SWITCH;
	    }

	    if ($token->name eq 'EQUALS')
	    {
		if ($sep)
		{
		    $value .= $token->text
		}
		else
		{
		    $sep = $token->text
		}
		last SWITCH;
	    }

	    if ($token->name eq 'DQUOTE')
	    {
		my $quoted = $token->text;
		$quoted =~ s!^\"(.*)\"$!$1!;
		$value .= $quoted;
		last SWITCH;
	    }

	    # Fall-through condition
	    if ($sep)
	    {
		$value .= $token->text
	    }
	    else
	    {
		$qual .= $token->text
	    }
	}
    }
    return %qualifiers;
}

=head2 _build_range

 Title   : _build_range
 Usage   : N/A
 Function: Creates a single Bio::PSU::Range object from a list of EMBL
         : location components (tokens produced by the tokenizer)
 Returns : A Bio::PSU::Range object
 Args    : A list of tokens (strings)

=cut

sub _build_range
{
    my ($self, $start, $sep, $end) = @_;

    my ($fuzzy_start, $fuzzy_end);
    my ($no_5prime, $no_3prime, $no_width);
    my $strand = 1;

    unless (defined $sep) { $sep = "" }
    unless (defined $end) { $end = $start }

    $start =~ s!\(\)!!;
    $end   =~ s!\(\)!!;

    $no_5prime = $start =~ s/<//;
    $no_3prime = $end   =~ s/>//;

    # Special case for ranges which are just <1 or >n
    # because we set $end = $start for single base ranges
    # above, which copies the < or > to the other coordinate
    $start =~ s/>//;
    $end   =~ s/<//;

    if ($sep eq '^') { $no_width = 1 }
    if ($sep eq '.')
    {
	$fuzzy_start = $start;
	$fuzzy_end   = $end;
	$start       = 0;
	$end         = 0;
    }

    if ($start =~ /(\d+)\.(\d+)/)
    {
	if (defined $sep)
	{
	    ($fuzzy_start, $start) = ($1, $2)
	}
	else
	{
	    ($start, $fuzzy_start) = (undef, $1)
	}
    }

    if ($end =~ /(\d+)\.(\d+)/)
    {
	if (defined $sep)
	{
	    ($end, $fuzzy_end) = ($1, $2)
	}
	else
	{
	    ($fuzzy_end, $end) = ($1, 0)
	}
    }

    my $range = Bio::PSU::Range->new(-start       => $start,
				     -fuzzy_start => $fuzzy_start,
				     -end         => $end,
				     -fuzzy_end   => $fuzzy_end,
				     -strand      => $strand);

    $no_5prime and $range->no_5prime(1);
    $no_3prime and $range->no_3prime(1);
    $no_width  and $range->no_width(1);

    return $range;
}

=head2 make_feature_block

 Title   : make_feature_block
 Usage   : print $self->make_feature_block($feature, $leader);
 Function: Creates a block of text representing a single feature
         : and returns it. The block looks like a chunk of EMBL
         : or Genbank feature table
 Returns : String
 Args    : A Bio::PSU::Feature object and a leader string (e.g. for
         : EMBL format this is 'FT' plus 19 spaces)

=cut

sub make_feature_block
{
    my ($self, $feat, $leader) = @_;
    my @loc;
    my @qnames = $feat->qnames;

    foreach my $range ($feat->ranges)
    {
	my ($start, $end, $sep);
	my ($startmod, $endmod) = ("", "");

	# Range start/fuzzy start
	if ($range->fuzzy_start)
	{
	    if ($range->start)
	    {
		$start = sprintf "(%s.%s)", $range->start, $range->fuzzy_start
	    }
	    else
	    {
		$start = $range->fuzzy_start;
		$sep = ".";
	    }
	}
	else
	{
	    $start = $range->start
	}

	# Range end/fuzzy end
	if ($range->fuzzy_end)
	{
	    if ($range->end)
	    {
		$end = sprintf "(%s.%s)", $range->fuzzy_end, $range->end
	    }
	    else
	    {
		$end = $range->fuzzy_end;
		$sep = ".";
	    }
	}
	else
	{
	    $end = $range->end
	}

	if ($range->no_width) { $sep = "^" } else { $sep = ".." }

	# Set the location modifiers for features running off of the entry
	if ($range->no_5prime)
	{
	    if    ($range->strand ==  1) { $startmod = '<' }
	    elsif ($range->strand == -1) { $endmod   = '>' }
	}

	if ($range->no_3prime)
	{
	    if    ($range->strand ==  1) { $endmod   = '>' }
	    elsif ($range->strand == -1) { $startmod = '<' }
	}

	# Not sure if the endmod is the right side of the 1bp feature here
	if ($start eq $end)
	{
	    push(@loc, "$startmod$endmod$start")
	}
	else
	{
	    push(@loc, "$startmod$start$sep$endmod$end")
	}
    }

    my $location = join(',', @loc);

    # If there is more than one range
    if (scalar @loc > 1) { $location = "join($location)" }

    # Check strand settings
    if ($feat->strand == 0)
    {
	carp "[$feat] is on strand 0 (not supported by EMBL format): using forward strand"
    }
    elsif ($feat->strand == -1)
    {
	$location = "complement($location)"
    }

    # Default to EMBL style leader if none is defined
    $leader     ||= "FT" . " " x 19;
    my $locleader = $leader;

    my $key = $feat->key;
    if ($key) { substr($locleader, 5, length($key)) = $key }
    my $locblock = $self->_wrap($locleader, $leader, $location, ',');

    my @qualblocks;

 QNAME: foreach my $qname ($feat->qnames)
    {
	# Exclude qualifiers we don't want to print
	next QNAME if grep /^$qname$/, @{$self->{noprint}};

	my $printquoted = 0;
	$printquoted++ unless grep /^$qname$/, @{$self->{unquoted}};

	my @values = $feat->qvalues("^$qname\$");

	# Some qualifiers (like /pseudo) have no value
	unless (@values)
	{
	    my $qualifier = "/$qname";
	    # No qualifier name should be this long, but let's wrap anyway
	    push(@qualblocks, $self->_wrap($leader, $leader, $qualifier, ' ' ));
	}

	foreach my $qvalue (@values)
	{
	    $qvalue =~ s!(^.*$)!\"$1\"! if $printquoted;
	    my $qualifier = qq!/$qname=$qvalue!;

	    push(@qualblocks, $self->_wrap($leader, $leader, $qualifier, ' ' ));
	}
    }

    my $qualblock = join('', @qualblocks);

    return "$locblock$qualblock";
}

=head2 _wrap

 Title   : _wrap
 Usage   : N/A
 Function: Wraps text for printing EMBL feature tables. Text::Wrap
         : is not used here because it unexpands spaces into tabs.
         : Words longer than the line are broken (this is something
         : that the Bioperl SeqIO::embl module doesn't handle at
         : the moment)
 Returns : String
 Args    : Leader (first line), leader (subsequent lines), text to
         : be wrapped, separating character to wrap on

=cut

sub _wrap
{
    my ($self, $locleader, $leader, $text, $sep) = @_;
    my @lines;

    my @chunks = split($sep, $text);

    for my $i (0..$#chunks)
    {
	next unless length($chunks[$i]) >= 57;
	my @extra;
	while ($chunks[$i] =~ /(.{1,57})/g)
	{
	    push(@extra, $1)
	}
	splice(@chunks, $i, 1, @extra);
    }
    $text = join($sep, @chunks);
    $text =~ s!^\s+!!;
    $text =~ s!\s+$!!;
    $text =~ s!^"\s+!\"!;
    $text =~ s!\s+\"$!\"!;

    while ($text =~ /(.{1,58})($sep|$)/g)
    {
	my $term = $2;
	$term = "" if $term eq ' ';
	push(@lines, $1.$term)
    }

    my $first   = shift @lines;
    my $wrapped = "$locleader$first\n";

    foreach (@lines)
    {
	$wrapped .= "$leader$_\n"
    }
    return $wrapped;
}

1;
