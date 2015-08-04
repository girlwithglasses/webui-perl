=head1 NAME

Bio::PSU::IO::Fasta::Hit - Object representing one Fasta or Fastx hit
of a query sequence to a database

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

This object represents a single Fasta or Fastx hit. The methods are
all self-explanatory; each returns a value for the hit as defined in
the Fasta documentation. As Fastx uses Smith-Waterman, the score,
ident and overlap are accessed using the same methods as for Fasta
(sw_score, ident and overlap).

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

package Bio::PSU::IO::Fasta::Hit;

use strict;
use Carp;
use Bio::PSU::Base;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Base);

{
    my $_class_defaults = { fa_frame   => undef,
                            fa_initn   => undef,
                            fa_init1   => undef,
                            fa_opt     => undef,
                            fa_zscore  => undef,
                            fa_expect  => undef,
                            fa_ident   => undef,
                            fa_overlap => undef,
                            sw_score   => undef,
                            sw_ident   => undef,
                            sw_overlap => undef,
                            consensus  => undef,
                            query      => { id               => undef,
                                            sq_type          => undef,
                                            sq_len           => undef,
                                            sq_offset        => undef,
                                            al_start         => undef,
                                            al_stop          => undef,
                                            al_residues      => undef,
                                            al_display_start => undef},
                            subject    => { id               => undef,
                                            desc             => undef,
                                            sq_type          => undef,
                                            sq_len           => undef,
                                            sq_offset        => undef,
                                            al_start         => undef,
                                            al_stop          => undef,
                                            al_residues      => undef,
                                            al_display_start => undef }};

    my $_class_args     = { -fa_frame   => [qw(_defer  fa_frame  )],
                            -fa_initn   => [qw(_defer  fa_initn  )],
                            -fa_init1   => [qw(_defer  fa_init1  )],
                            -fa_opt     => [qw(_defer  fa_opt    )],
                            -fa_zscore  => [qw(_defer  fa_zscore )],
                            -fa_expect  => [qw(_defer  fa_expect )],
                            -fa_ident   => [qw(_defer  fa_ident  )],
                            -fa_overlap => [qw(_defer  fa_overlap)],
                            -sw_score   => [qw(_defer  sw_score  )],
                            -sw_ident   => [qw(_defer  sw_ident  )],
                            -sw_overlap => [qw(_defer  sw_overlap)],
                            -consensus  => [qw(_defer  consensus )],
                            -q_dat      => [qw(_hitdat query     )],
                            -s_dat      => [qw(_hitdat subject   )] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $hit = Bio::PSU::IO::Fasta::Hit->new(-fa_frame =>
         : $fa_frame etc.)
 Function: Creates a new Fasta hit object. This holds details
         : of each hit
 Returns : A Bio::PSU::IO::Fasta::Hit object
 Args    : -fa_frame (string), -fa_initn (string), -fa_init1
         : (string), -fa_opt (string), -fa_zscore (string),
	 : -fa_expect (string), -fa_ident (integer),
         : -fa_overlap (string), -sw_score (string), -sw_ident
         : (integer), -sw_overlap (integer), -consensus
         : (string), -q_dat (hash), -s_dat (hash)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self  = {};
    bless($self, $class);

    my $_defaults = $self->_dcopy(_class_defaults);
    my $deferred  = $self->_init($_defaults, $args);

    foreach (keys %$deferred)
    {
        my $val = delete $deferred->{$_};
        if (/^-fa_frame$/)   { $self->{fa_frame}   = $val; next }
        if (/^-fa_initn$/)   { $self->{fa_initn}   = $val; next }
        if (/^-fa_opt$/)     { $self->{fa_opt}     = $val; next }
        if (/^-fa_zscore$/)  { $self->{fa_zscore}  = $val; next }
        if (/^-fa_expect$/)  { $self->{fa_expect}  = $val; next }
        if (/^-fa_ident$/)   { $self->{fa_ident}   = $val; next }
        if (/^-fa_overlap$/) { $self->{fa_overlap} = $val; next }
        if (/^-sw_score$/)   { $self->{sw_score}   = $val; next }
        if (/^-sw_ident$/)   { $self->{sw_ident}   = $val; next }
        if (/^-sw_overlap$/) { $self->{sw_overlap} = $val; next }
        if (/^-consensus$/)  { $self->{consensus}  = $val; next }
    }

    $self->_check_args($args);

    return $self;
}

=head2 _hitdat

 Title   : _hitdat
 Usage   : N/A
 Function: Inserts query and subject hit data into object
 Returns : Nothing
 Args    : Reference to a hash

=cut

sub _hitdat
{
    my ($self, $arg) = @_;

    my %hitdat = %$arg;

    my $name = delete $hitdat{name};

    foreach (keys %hitdat)
    {
        my $val = $hitdat{$_};
        $self->{$name}->{$_} = $val if defined $val;
        next;
    }
}

=head2 frame

 Title   : frame
 Usage   : $frame = $hit->frame;
 Function: Returns the frame of a hit
 Returns : String
 Args    : None

=cut

sub frame
{
    my ($self) = @_;
    return $self->{fa_frame};
}

=head2 expect

 Title   : expect
 Usage   : $expect = $hit->expect;
 Function: Returns the expect value of a hit
 Returns : String
 Args    : None

=cut

sub expect
{
    my ($self) = @_;
    return $self->{fa_expect};
}

=head2 opt

 Title   : opt
 Usage   : $opt = $hit->opt;
 Function: Returns the opt value of a hit
 Returns : String
 Args    : None

=cut

sub opt
{
    my ($self) = @_;
    return $self->{fa_opt};
}

=head2 zscore

 Title   : zscore
 Usage   : $zscore = $hit->zscore;
 Function: Returns the zscore value of a hit
 Returns : String
 Args    : None

=cut

sub zscore
{
    my ($self) = @_;
    return $self->{fa_zscore};
}

=head2 sw_score

 Title   : sw_score
 Usage   : $sw_score = $hit->sw_score;
 Function: Returns the sw_score value of a hit
 Returns : String
 Args    : None

=cut

sub sw_score
{
    my ($self) = @_;
    return $self->{sw_score};
}

=head2 percent

 Title   : percent
 Usage   : $ident = $hit->percent;
 Function: Returns the ident (% identity) of a hit
 Returns : Integer
 Args    : None

=cut

sub percent
{
    my ($self) = @_;
    my $ident = $self->{fa_ident};
    $ident  ||= $self->{sw_ident};

    return sprintf("%.1f", $ident * 100);
}

=head2 overlap

 Title   : overlap
 Usage   : $overlap = $hit->overlap;
 Function: Returns the overlap of a hit
 Returns : Integer
 Args    : None

=cut

sub overlap
{
    my ($self) = @_;
    my $overlap = $self->{fa_overlap};
    $overlap  ||= $self->{sw_overlap};
    return $overlap;
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
    return $self->{query}->{id};
}

=head2 q_type

 Title   : q_type
 Usage   : $query_name = $hit->q_type;
 Function: Returns the query sequence type
 Returns : String
 Args    : None

=cut

sub q_type
{
    my ($self) = @_;
    return $self->{query}->{sq_type};
}

=head2 q_len

 Title   : q_len
 Usage   : $query_len = $hit->q_len;
 Function: Returns the query length
 Returns : Integer
 Args    : None

=cut

sub q_len
{
    my ($self) = @_;
    return $self->{query}->{sq_len};
}

=head2 q_offset

 Title   : q_offset
 Usage   : $query_offset = $hit->q_offset;
 Function: Returns the query offset
 Returns : Integer
 Args    : None

=cut

sub q_offset
{
    my ($self) = @_;
    return $self->{query}->{sq_offset};
}

=head2 q_begin

 Title   : q_begin
 Usage   : $query_begin = $hit->q_begin;
 Function: Returns the query beginning
 Returns : Integer
 Args    : None

=cut

sub q_begin
{
    my ($self) = @_;
    return $self->{query}->{al_start};
}

=head2 q_end

 Title   : q_end
 Usage   : $query_end = $hit->q_end;
 Function: Returns the query end
 Returns : Integer
 Args    : None

=cut

sub q_end
{
    my ($self) = @_;
    return $self->{query}->{al_stop};
}

=head2 s_id

 Title   : s_id
 Usage   : $subject_name = $hit->s_id;
 Function: Returns the subject id
 Returns : String
 Args    : None

=cut

sub s_id
{
    my ($self) = @_;
    return $self->{subject}->{id};
}

=head2 s_desc

 Title   : s_desc
 Usage   : $subject_desc = $hit->s_desc;
 Function: Returns the subject description
 Returns : String
 Args    : None

=cut

sub s_desc
{
    my ($self) = @_;
    return $self->{subject}->{desc};
}

=head2 s_type

 Title   : s_type
 Usage   : $query_type = $hit->s_type;
 Function: Returns the subject sequence type
 Returns : String
 Args    : None

=cut

sub s_type
{
    my ($self) = @_;
    return $self->{subject}->{sq_type};
}

=head2 s_len

 Title   : s_len
 Usage   : $subject_len = $hit->s_len;
 Function: Returns the subject length
 Returns : Integer
 Args    : None

=cut

sub s_len
{
    my ($self) = @_;
    return $self->{subject}->{sq_len};
}

=head2 s_begin

 Title   : s_begin
 Usage   : $subject_begin = $hit->s_begin;
 Function: Returns the subject start
 Returns : Integer
 Args    : None

=cut

sub s_begin
{
    my ($self) = @_;
    return $self->{subject}->{al_start};
}

=head2 s_end

 Title   : s_end
 Usage   : $subject_end = $hit->s_end;
 Function: Returns the subject end
 Returns : Integer
 Args    : None

=cut

sub s_end
{
    my ($self) = @_;
    return $self->{subject}->{al_stop};
}

=head2 q_align

 Title   : q_align
 Usage   : $query_align = $hit->q_align;
 Function: Returns the query alignment string
 Returns : String
 Args    : None

=cut

sub q_align
{
    my ($self) = @_;
    return $self->{query}->{al_residues};
}

=head2 s_align

 Title   : s_align
 Usage   : $subject_align = $hit->s_align;
 Function: Returns the subject alignment string
 Returns : String
 Args    : None

=cut

sub s_align
{
    my ($self) = @_;
    return $self->{subject}->{al_residues};
}

=head2 q_dbegin

 Title   : q_dbegin
 Usage   : $query_align_start = $hit->q_dbegin;
 Function: Returns the query alignment string start
 Returns : Integer
 Args    : None

=cut

sub q_dbegin
{
    my ($self) = @_;
    return $self->{query}->{al_display_start};
}

=head2 s_dbegin

 Title   : s_alstart
 Usage   : $subject_align_start = $hit->s_dbegin;
 Function: Returns the subject alignment string start
 Returns : Integer
 Args    : None

=cut

sub s_dbegin
{
    my ($self) = @_;
    return $self->{subject}->{al_display_start};
}

=head2 consensus

 Title   : consensus
 Usage   : $consesus = $hit->consensus;
 Function: Returns the consensus string of the alignment
 Returns : String
 Args    : None

=cut

sub consensus
{
    my ($self) = @_;
    return $self->{consensus};
}

1;
