=head1 NAME

Bio::PSU::IO::EMBL::Stream - Object providing a stream of
Bio::PSU::Seq objects from an EMBL format source

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

An Bio::PSU::IO::EMBL::Stream provides a next_seq method which get the
next EMBL entry from a stream and creates an Bio::PSU::Seq object from
it, which it returns. It also provides a write_seq method which
performs the reverse operation and will write a stream of EMBL entries
if provided with Bio::PSU::Seq objects.

Note that this is really designed to handle feature tables and not the
header fields such as references, database references etc. The ID,
accession number, description and organism are retained as free text,
if present. Other data are discarded.

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

package Bio::PSU::IO::EMBL::Stream;

use strict;
use Carp;
use Bio::PSU::IO::FTHandler;
use Bio::PSU::Feature;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IO::FTHandler);

{
    my $_class_defaults = {};
    my $_class_args     = {};

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $stream = Bio::PSU::IO::EMBL::Stream->new(-bfh => $bfh);
 Function: Reads EMBL format input via a filehandle which can be to
         : a file or a pipe from getz, efetch etc. You can use it
         : directly, but there is a Bio::PSU::SeqFactory object to do
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

    my $self  = Bio::PSU::IO::FTHandler->new($args);
    bless($self, $class);

    # Merge $self with defaults
    my $_defaults = $self->_dcopy($self->_class_defaults);
    $self->_merge_hash($_defaults);

    # Init using inherited data in $self
    $self->_init($self, $args);

    $self->_check_args($args);

    return $self;
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq;
 Function: Gets the next Bio::PSU::Seq object from the stream
 Returns : A Bio::PSU::Seq object
 Args    : None

=cut

sub next_seq
{
    my ($self) = @_;
    my ($id, $acc, $desc, $org, @features, @ranges, %qual, $seq, $str);

 LINE: while (1)
    {
        my $line = $self->getline;

        # Skip this block of we are at EOF
        last LINE unless defined $line;

        # Stop if we get an EOE marker
        last LINE if $line =~ /^\/\/$/;

        # Ignore blank lines
        next LINE if $line =~ /^\s*$/;

        # Record the ID, if present
        if ($line =~ /^ID\s{3}(\S+)\s*/) { $id = $1 }

        # Record the accession number, if present
        if ($line =~ /^AC\s{3}(\S+);/) { $acc = $1 }

        # Record the description, if present
        if ($line =~ /^DE\s{3}(.*)/) { $desc = $1 }

        # Record the organism, if present
        if ($line =~ /^OS\s{3}(.*)/) { $org = $1 }

        my ($key, $location, $qualifiers);

        # We are being facists and insisting that there are exactly 3 spaces
        # before a feature key and later, exactly 19 leading spaces within
        # a qualifier block

        if ($line =~ /^FT\s{3}(\S+)\s+(\S+)/)
        {
            ($key, $location) = ($1, $2);

        FTLINE: while (1)
            {
                my $ftline = $self->getline;

                # Skip this block if we are at EOF
                last FTLINE unless defined $ftline;

                # Gather the location line(s) - these don't start with a '/'
                # and appear before the qualifiers.
                if ($ftline =~ /^FT\s{19}([^\/].*)/ && ! $qualifiers)
                {
                    $location .= $1;
                    next FTLINE;
                }
                # Otherwise gather qualifier line(s)
                elsif ($ftline =~ /^FT\s{19}(.*)/)
                {
                    $qualifiers .= "$1 "
                }
                # Buffer the start of any new feature
                elsif ($ftline =~ /^FT\s{3}(\S+)\s+(\S+)/)
                {
                    $self->buffer($ftline);
                    last FTLINE;
                }
                # Or finish if there are no more matching lines
                else
                {
                    $self->buffer($ftline);
                    last FTLINE;
                }
            }

            @ranges = $self->parse_location($location);
            %qual   = defined $qualifiers ? $self->parse_qualifiers($qualifiers) : ();

            unless (@ranges)
            {
                carp "Unable to parse location of feature at $location";
                %qual = ();
                next LINE;
            }

            my $feature = Bio::PSU::Feature->new(-key    => $key,
                                                 -qual   => { %qual },
                                                 -ranges => [@ranges]);

            push(@features, $feature);
            next LINE;

        } # End FTLINE

        if ($line =~ /^SQ/)
        {

        SQLINE: while (1)
            {
                my $sqline = $self->getline;

                # Skip this block of we are at EOF or end of entry
                last LINE unless defined $sqline;
                last LINE if $sqline =~ /^\/\//;

                # If we buffer any non-sequence line here, we can cope
                # with bad files where there is no // before the next
                # EMBL entry

                # Strip out the numbering and spaces
                $sqline =~ s/[\d\s]//g;
                $str .= $sqline;
            } # End SQLINE
        }
    } # End LINE

    # Create a new sequence object if we have either a sequence or features.
    # We allow both sequence without features (of course) and features
    # without sequence
    if ($str or @features)
    {
        $seq = Bio::PSU::Seq->new(-id       => $id,
                                  -acc      => $acc,
                                  -desc     => $desc,
                                  -org      => $org,
                                  -str      => $str,
                                  -type     => 'dna',
                                  -features => \@features);
    }
    return $seq;
}

=head2 write_seq

 Title   : write_seq
 Usage   : $stream->write_seq($seq);
 Function: Writes the next Bio::PSU::Seq object to the stream
 Returns : Nothing
 Args    : A Bio::PSU::Seq object

=cut

sub write_seq
{
    my ($self, $seq) = @_;

    if (! defined $seq)
    {
        $self->btrace("Unable to write sequence. No Bio::PSU::Seq object supplied")
    }
    if (! ref($seq) or ! $seq->isa('Bio::PSU::Seq'))
    {
        $self->btrace("Unable to write [$seq] as it is not an Bio::PSU::Seq object")
    }

    my $id  = $seq->id;
    my $acc = $seq->acc;

    if (defined $id and $id !~ /^\s*$/)
    {
        $self->putline("ID   $id\n");
    }

    if (defined $acc and $acc !~ /^\s*$/)
    {
        $self->putline("AC   $acc\n");
    }

    if ($seq->has_features)
    {
        # print FH here if needed
        foreach my $feature ($seq->features)
        {
            $self->putline($self->make_feature_block($feature))
        }
    }

    if (defined $seq->str)
    {
        $self->_make_seq_block($seq->str)
    }
}

=head2 _make_seq_block

 Title   : _make_seq_block
 Usage   : N/A
 Function: Creates a block of text representing a sequence and
         : writes it to the filehandle associated with the object
 Returns : Nothing
 Args    : Sequence string

=cut

sub _make_seq_block
{
    my ($self, $str) = @_;
    my %composition = (a => 0,
                       c => 0,
                       g => 0,
                       t => 0);
    my $o = 0;

    $str = lc($str);
    while ($str =~ /(.)/g)
    {
        if (exists $composition{$1})
        {
            $composition{$1}++
        }
        else
        {
            $o++
        }
    }

    my $a = $composition{a};
    my $c = $composition{c};
    my $g = $composition{g};
    my $t = $composition{t};

    my $length = length($str);

    if ($length != ($a + $c + $g + $t + $o))
    {
        carp "Sum of individual base counts not equal to total bases\n"
    }

    $self->putline("SQ   Sequence $length BP; $a A; $c C; $g G; $t T; $o other;\n");

    while ($str =~ /(.{1,60})/g)
    {
        my $line = pack("A11" x 6, (unpack "a10" x 6, $1));
        my $form = sprintf "     %s%9d\n", $line, pos($str);
        $self->putline($form);
    }
    $self->putline("//\n");
}

1;

