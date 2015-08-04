=head1 NAME

Bio::PSU::IO::Blast::Hit - Object representing one Blast hit of a
query sequence to a database

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

This object represents a single Blast hit, consisting of one or
more HSPs.

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

package Bio::PSU::IO::Blast::Hit;

use strict;
use Bio::PSU::IOWrap;
use Bio::PSU::IO::Blast::HSP;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

{
    my $_class_defaults = { hitblock => undef,
			    q_id     => "",
			    q_len    => undef,
			    s_id     => "",
			    s_desc   => "",
			    s_len    => undef };

    my $_class_args     = { -hitblock => [qw(_defer hitblock)],
			    -q_id     => [qw(_defer q_id    )],
			    -q_len    => [qw(_defer q_len   )],
			    -s_id     => [qw(_defer s_id    )],
			    -s_len    => [qw(_defer s_len   )],
			    -s_desc   => [qw(_defer s_desc  )] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $hit = Bio::PSU::IO::Blast::Hit->new(-bfh =>
         : $buffered_fh, etc.);
 Function: Creates a new Blast hit object. This holds details
         : of a single hit, consisting of one or more HSPs
 Returns : A Bio::PSU::IO::Blast::Hit object
 Args    : -bfh Bio::PSU::BufferFH object, -q_id query id
         : (string), -q_len query length (integer), -s_id
         : subject id (string), -s_len subject length
         : (integer), -s_desc subject description (string)

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
	if (/^-hitblock$/) { $self->{hitblock} = $val; next }
	if (/^-q_id$/)     { $self->{q_id}     = $val; next }
	if (/^-q_len$/)    { $self->{q_len}    = $val; next }
	if (/^-s_id$/)     { $self->{s_id}     = $val; next }
	if (/^-s_len$/)    { $self->{s_len}    = $val; next }
	if (/^-s_desc$/)   { $self->{s_desc}   = $val; next }
    }

    $self->_check_args($args);

    return $self;
}

=head2 next_hsp

 Title   : next_hsp
 Usage   : while (my $hsp = $hit->next_hsp) { print $hsp->expect,
         : "\n" }
 Function: Returns the next Bio::PSU::IO::Blast::HSP object
         : of this hit
 Returns : Bio::PSU::IO::Blast::HSP object or undef
 Args    : None

=cut

sub next_hsp
{
    my ($self) = @_;
    my ($hsp, @hsplines);
    my ($score, $bits, $expect, $pval, $length, $match, $positive,
        $q_strand, $s_strand, $q_frame, $s_frame);

 HSPLINE: while (1)
    {
        my $hspline = $self->getline;

        # Skip this block if we are at EOF
        last HSPLINE unless defined $hspline;

        # Ignore blank lines
        next HSPLINE if $hspline =~ /^\s*$/;

        # Exit at the end of the report (Matrix in NCBI Blast 2)
        if ($hspline =~ /^Parameters|^Matrix/)
        {
            $self->buffer($hspline);
            last HSPLINE;
        }

        # Exit at the next hit
        if ($hspline =~ /^>/)
        {
            $self->buffer($hspline);
            last HSPLINE;
        }

        # Return HSP when next HSP is reached
        if ($hspline =~ /Score =/)
        {
            if (defined $score)
            {
                # Return the Score line of the following HSP
                $self->buffer($hspline);
                last HSPLINE;
            }
        }

        # NCBI-BLAST scores
        if ($hspline =~ /Score =\s+(\S+) bits \((\d+)/)
        {
            ($score, $bits) = ($1, $2);

            if ($hspline =~ /Sum P\(\d+\) = (\S+)/)  { $pval   = $1 }
            if ($hspline =~ /P = (\S+)/)             { $pval   = $1 }
            if ($hspline =~ /Expect = (\S+)/)        { $expect = $1 }
            if ($hspline =~ /Expect\(\d+\) = (\S+)/) { $expect = $1 }
            $expect =~ s/,// if defined $expect;

            # Fix for buggy non-numeric e-value
            if (defined $expect && $expect =~ /^e/)
            {
                $expect = "1" . $expect;
            }

            $pval = $expect unless defined $pval;
            next HSPLINE;
        }

        # WU-BLAST scores
        if ($hspline =~ /Score = (\S+) \((\S+) bits\)/)
        {
            ($score, $bits) = ($1, $2);

            if ($hspline =~ /Sum P\(\d+\) = (\S+)/)  { $pval   = $1 }
            if ($hspline =~ /P = (\S+)/)             { $pval   = $1 }
            if ($hspline =~ /Expect = (\S+)/)        { $expect = $1 }
            if ($hspline =~ /Expect\(\d+\) = (\S+)/) { $expect = $1 }
            $expect =~ s/,// if defined $expect;
            $pval = $expect unless defined $pval;
            next HSPLINE;
        }

        # HSP length and identities
        if ($hspline =~ /Identities = (\d+)\/(\d+)/)
        {
            ($match, $length) = ($1, $2)
        }

        if ($hspline =~ /Positives = (\d+)\/\d+/)
        {
            $positive = $1;
            $positive = $match unless defined $positive;
        }

        # HSP strand for Blastn
        if ($hspline =~ /Strand = (\w+) \/ (\w+)/)
        {
            ($q_strand, $s_strand) = ($1, $2);
            $q_strand =~ s/Plus/1/;
            $q_strand =~ s/Minus/-1/;

            $s_strand =~ s/Plus/1/;
            $s_strand =~ s/Minus/-1/;
            next HSPLINE;
        }

        # HSP Frame for Blastx
        if ($hspline =~ /Frame = ([+\-])(\d)(?: \/ ([+\-])(\d))?/)
        {
            ($q_strand, $q_frame) = ($1, $2);
            $q_strand .= "1";

            if (defined $3)
            {
                ($s_strand, $s_frame) = ($3, $4);
                $s_strand .= "1";
            }
            next HSPLINE;
        }

        # Alignment lines
        if ($hspline =~ /^Query:.*/)
        {
            push(@hsplines, $hspline);
            push(@hsplines, $self->getline);
            push(@hsplines, $self->getline);
        }
    }

    if (@hsplines)
    {
        $hsp = _make_hsp(\@hsplines, $score, $bits, $expect, $pval,
                         $length, $match, $positive, $q_strand, $s_strand,
                         $q_frame, $s_frame) if defined $score;
    }
    return $hsp;
}

=head2 _make_hsp

 Title   : _make_hsp
 Usage   : N/A
 Function: Used to create an HSP object
 Returns : Bio::PSU::IO::Blast::HSP object
 Args    : Ref to array of hsp lines, score, bits, expect, pvalue,
         : length, match, positive, query strand, $subject strand

=cut

sub _make_hsp
{
    my ($hsplines, $score, $bits, $expect, $pval,
	$length, $match, $positive, $q_strand, $s_strand,
	$q_frame, $s_frame) = @_;

    my ($qbeg, $qend, $sbeg, $send) = (0, 0, 0, 0);
    my ($qline, $sline, $aline);
    my (@qlines, @slines, @alines);

    for (my $i = 0; $i < $#{$hsplines}; $i += 3)
    {
        # Query line
        $hsplines->[$i] =~ /^Query:\s+(\d+)\s*(\S+)\s*(\d+)/;
        $qbeg  = $1 unless $qbeg;
        $qline = $2;
        $qend  = $3;
        push(@qlines, $2);

        # Alignment line
        my $offset = index($hsplines->[$i], $qline);
        $aline = substr($hsplines->[$i+1], $offset, length($qline));
        push(@alines, $aline);

        # Subject line
        $hsplines->[$i+2] =~ /^Sbjct:\s+(\d+)\s*(\S+)\s*(\d+)/;
        $sbeg  = $1 unless $sbeg;
        $sline = $2;
        $send  = $3;
        push(@slines, $2);
    }

    my $percent = sprintf("%.0f", $match/$length * 100);

    my $hsp = Bio::PSU::IO::Blast::HSP->new
	(-score    => $score,
	 -bits     => $bits,
	 -expect   => $expect,
	 -pval     => $pval,
	 -match    => $match,
	 -length   => $length,
	 -positive => $positive,
	 -percent  => $percent,
	 -q_strand => $q_strand,
	 -q_frame  => $q_frame,
	 -q_begin  => $qbeg,
	 -q_end    => $qend,
	 -q_align  => join("\n", @qlines),
	 -s_strand => $s_strand,
	 -s_frame  => $s_frame,
	 -s_begin  => $sbeg,
	 -s_end    => $send,
	 -s_align  => join("\n", @slines),
	 -align    => join("\n", @alines));

    return $hsp;
}

=head2 q_id

 Title   : q_id
 Usage   : $query_name = $hit->q_id;
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
 Usage   : $query_length = $hit->q_len;
 Function: Returns the query length
 Returns : Integer
 Args    : None

=cut

sub q_len
{
    my ($self) = @_;
    return $self->{q_len};
}

=head2 s_id

 Title   : s_id
 Usage   : print "Hit is to: ", $hit->s_id, "\n";
 Function: Returns the subject id of this hit
 Returns : Subject id (string)
 Args    : None

=cut

sub s_id
{
    my ($self) = @_;
    return $self->{s_id};
}

=head2 s_desc

 Title   : s_desc
 Usage   : print "Hit is to: ", $hit->s_desc, "\n";
 Function: Returns the subject description of this hit
 Returns : Subject desc (string)
 Args    : None

=cut

sub s_desc
{
    my ($self) = @_;
    return $self->{s_desc};
}

=head2 s_len

 Title   : s_len
 Usage   : print "Hit is: ", $hit->s_len, " long\n";
 Function: Returns the subject length of this hit
 Returns : Subject length (integer)
 Args    : None

=cut

sub s_len
{
    my ($self) = @_;
    return $self->{s_len};
}

1;
