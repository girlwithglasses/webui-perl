=head1 NAME

Bio::PSU::IO::Fasta::Result - Class representing the result of one
Fasta or Fastx search against a database

=head1 SYNOPSIS

See Bio::PSU::SearchFactory

=head1 DESCRIPTION

This object represents the result of one Fasta search. It makes
available details of the program version and settings, the database
and a method to return a list of Bio::PSU::IO::Fasta::Hit
objects. Fastx output is also parsed.

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

package Bio::PSU::IO::Fasta::Result;

use strict;
use Carp;
use Bio::PSU::IOWrap;
use Bio::PSU::IO::Fasta::Hit;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::IOWrap);

{
    my $_class_defaults = { database  => undef,
                            db_size   => undef,
                            db_seqs   => undef,
                            mp_argv   => undef,
                            mp_name   => undef,
                            mp_ver    => undef,
                            pg_matrix => undef,
                            pg_gopen  => undef,
                            pg_gext   => undef,
                            pg_ktup   => undef,
                            pg_optcut => undef,
                            pg_cgap   => undef };

    my $_class_args     = { -database  => [qw(_defer database )],
                            -db_size   => [qw(_defer db_size  )],
                            -db_seqs   => [qw(_defer db_seqs  )],
                            -mp_argv   => [qw(_defer mp_argv  )],
                            -mp_name   => [qw(_defer mp_name  )],
                            -mp_ver    => [qw(_defer mp_ver   )],
                            -pg_matrix => [qw(_defer pg_matrix)],
                            -pg_gopen  => [qw(_defer pg_gopen )],
                            -pg_gext   => [qw(_defer pg_gext  )],
                            -pg_ktup   => [qw(_defer pg_ktup  )],
                            -pg_optcut => [qw(_defer pg_optcut)],
                            -pg_cgap   => [qw(_defer pg_cgap  )] };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $result = Bio::PSU::IO::Fasta::Result->new(-database
         : => $lib_name, etc.);
 Function: Creates a new Fasta result object. This holds details
         : of the search conditions and a list of Hit objects
 Returns : A Bio::PSU::IO::Fasta::Result object
 Args    : -database (string), -db_size (integer), -db_seqs
         : (integer), -mp_argv (string), -mp_name (string),
         : -mp_ver (string), -pg_matrix (string), -pg_gopen
         : (string), -pg_gext (string), -pg_ktup (integer),
         : -pg_optcut (integer), -pg_cgap (integer), -bfh
         : (Bio::PSU::BufferFH object)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $args  = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $self = Bio::PSU::IOWrap->new($args);
    bless($self, $class);

    # Merge $self with defaults
    my $_defaults = $self->_dcopy($self->_class_defaults);
    $self->_merge_hash($_defaults);

    # Init using inherited data in $self
    my $deferred  = $self->_init($self, $args);

    foreach (keys %$deferred)
    {
        my $val = delete $deferred->{$_};
        if (/^-database$/)  { $self->{database}  = $val; next }
        if (/^-db_size$/)   { $self->{db_size}   = $val; next }
        if (/^-db_seqs$/)   { $self->{db_seqs}   = $val; next }
        if (/^-mp_argv$/)   { $self->{mp_argv}   = $val; next }
        if (/^-mp_name$/)   { $self->{mp_name}   = $val; next }
        if (/^-mp_ver$/)    { $self->{mp_ver}    = $val; next }
        if (/^-pg_matrix$/) { $self->{pg_matrix} = $val; next }
        if (/^-pg_gopen$/)  { $self->{pg_gopen}  = $val; next }
        if (/^-pg_gext$/)   { $self->{pg_gext}   = $val; next }
        if (/^-pg_ktup$/)   { $self->{pg_ktup}   = $val; next }
        if (/^-pg_optcut$/) { $self->{pg_optcut} = $val; next }
        if (/^-pg_cgap-$/)  { $self->{pg_cgap}   = $val; next }
    }

    $self->_check_args($args);

    return $self;
}

=head2 database

 Title   : database
 Usage   : $lib = $result->database;
 Function: Returns the search database name
 Returns : String
 Args    : None

=cut

sub database
{
    my ($self) = @_;
    return $self->{database};
}

=head2 db_size

 Title   : db_size
 Usage   : $size = $result->db_size;
 Function: Returns the search database size
 Returns : String
 Args    : None

=cut

sub db_size
{
    my ($self) = @_;
    return $self->{db_size};
}

=head2 db_seqs

 Title   : db_seqs
 Usage   : $seqs = $result->db_seqs;
 Function: Returns the number of sequences in the search database
 Returns : String
 Args    : None

=cut

sub db_seqs
{
    my ($self) = @_;
    return $self->{db_seqs};
}

=head2 next_hit

 Title   : hits
 Usage   : $hits = $result->next_hit;
 Function: Returns the next Hit object from the stream
 Returns : A Bio::PSU::IO::Fasta::Hit object
 Args    : None

=cut

sub next_hit
{
    my ($self) = @_;

    my ($fa_frame, $fa_initn, $fa_init1, $fa_opt, $fa_zscore, $fa_expect,
        $fa_ident, $fa_overlap, $sw_score, $sw_ident, $sw_overlap,
        $consensus);
    my ($hit, %q_dat, %s_dat);

 HLINE: while (1)
    {
        my $hline = $self->getline;

        # Skip this block if we are at EOF
        last HLINE unless defined $hline;

        # Exit at the end of report
        return if ($hline =~ /^>>><<<$/);

        if ($hline =~ /^>>(.*)/)
        {
            my $s_desc;
            if (defined $1)
            {
                $s_desc = $1;
                $s_desc =~ s/\S*\s+(.*)/$1/;
            }
            $s_dat{s_desc} = $s_desc;
            next HLINE;
        }

        if ($hline =~ /^>/)
        {
            $self->buffer($hline);
            last HLINE;
        }

        if ($hline =~ /^; fa_frame:\s+(\S+)/)
        {
            $fa_frame = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_initn:\s+(\d+(\.\d+)?)/)
        {
            $fa_initn = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_init1:\s+(\d+(\.\d+)?)/)
        {
            $fa_init1 = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_opt:\s+(\d+(\.\d+)?)/)
        {
            $fa_opt = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_z-score:\s+(\d+(\.\d+)?)/)
        {
            $fa_zscore = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_expect:\s+(.*)/)
        {
            $fa_expect = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_ident:\s+(\d+(\.\d+)?)/)
        {
            $fa_ident = $1;
            next HLINE;
        }

        if ($hline =~ /^; fa_overlap:\s+(\d+)/)
        {
            $fa_overlap = $1;
            next HLINE;
        }

        if ($hline =~ /^; s[wx]_score:\s+(\d+(\.\d+)?)/)
        {
            $sw_score = $1;
            next HLINE;
        }

        if ($hline =~ /^; s[wx]_ident:\s+(\d+(\.\d+)?)/)
        {
            $sw_ident = $1;
            next HLINE;
        }

        if ($hline =~ /^; s[wx]_overlap:\s+(\d+)/)
        {
            $sw_overlap = $1;
            next HLINE;
        }
    }

    my $qsref = \%q_dat;

 QSLINE: while (1)
    {
        my $qsline = $self->getline;

        # Skip this block if we are at EOF
        last QSLINE unless defined $qsline;

        # Stop at next hit or end of report
        if ($qsline =~ /^>>/)
        {
            $self->buffer($qsline);

            $hit = Bio::PSU::IO::Fasta::Hit->new
                (-fa_frame   => $fa_frame,
                 -fa_initn   => $fa_initn,
                 -fa_init1   => $fa_init1,
                 -fa_opt     => $fa_opt,
                 -fa_zscore  => $fa_zscore,
                 -fa_expect  => $fa_expect,
                 -fa_ident   => $fa_ident,
                 -fa_overlap => $fa_overlap,
                 -sw_score   => $sw_score,
                 -sw_ident   => $sw_ident,
                 -sw_overlap => $sw_overlap,
                 -q_dat      => \%q_dat,
                 -s_dat      => \%s_dat,
                 -consensus  => $consensus);

            last QSLINE;
        }

        if ($qsline =~ /^>(\S*)/)
        {
            if (! exists $qsref->{name})
            {
                $qsref->{name} = 'query';
                $qsref->{id} = $1;
                next QSLINE;
            }
            else
            {
                $qsref = \%s_dat;
                $qsref->{name} = 'subject';
                $qsref->{id} = $1;

                if ($qsline =~ /^>\S+\s+(\S+)/)
                {
                    $qsref->{desc} = $1;
                }
                next QSLINE;
            }
        }

        if ($qsline =~ /^; sq_len:\s+(\d+)/)
        {
            $qsref->{sq_len} = $1;
            next QSLINE;
        }

        if ($qsline =~ /^; sq_offset:\s+(\d+)/)
        {
            $qsref->{sq_offset} = $1;
            next QSLINE;
        }

        if ($qsline =~ /^; sq_type:\s+(\d+)/)
        {
            $qsref->{sq_type} = $1;
            next QSLINE;
        }

        if ($qsline =~ /^; al_start:\s+(\d+)/)
        {
            $qsref->{al_start} = $1;
            next QSLINE;
        }

        if ($qsline =~ /^; al_stop:\s+(\d+)/)
        {
            $qsref->{al_stop} = $1;
            next QSLINE;
        }

        if ($qsline =~ /^; al_display_start:\s+(\d+)/)
        {
            $qsref->{al_display_start} = $1;

        ALINE: while (1)
            {
                my $aline = $self->getline;

                # Skip this block if we are at EOF
                last ALINE unless defined $aline;

                # Stop at consensus or next hit
                if ($aline =~ /^(>|;)/)
                {
                    $self->buffer($aline);
                    last ALINE;
                }

                $qsref->{al_residues} .= $aline;
            }
            next QSLINE;
        }

        if ($qsline =~ /^; al_cons:/)
        {
        CLINE: while (1)
            {
                my $cline = $self->getline;

                # Skip this block if we are at EOF
                last CLINE unless defined $cline;

                # Stop at next hit or end of report
                if ($cline =~ /^>>/)
                {
                    $self->buffer($cline);
                    last CLINE;
                }

                $consensus .= $cline;
            }
            next QSLINE;
        }
    }

    return $hit;
}

1;
