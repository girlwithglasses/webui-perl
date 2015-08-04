=head1 NAME

Bio::PSU::SearchFactory - Object which creates sequence I/O stream
objects for various search programs

=head1 SYNOPSIS

 use strict;
 use Bio::PSU::SearchFactory;

 my $file = shift;
 my $blast = Bio::PSU::SearchFactory->make(-fh      => \*STDIN,
				          -program => 'blast');

 while (my $result = $blast->next_result)
 {
     printf("type %s, query %s, db %s\n",
	    $result->type,
	    $result->q_id,
	    $result->database);

     while (my $hit = $result->next_hit)
     {
	 printf("\tsubject: id %s,  desc %s, len %s\n",
	        $hit->s_id,
	        $hit->s_desc,
	        $hit->s_len);

	 while (my $hsp = $hit->next_hsp)
	 {
	     printf("\t\tscore %s, expect %s, percent %s\n",
		    $hsp->score,
		    $hsp->expect,
		    $hsp->percent);

	     printf("\t\tquery start %d, q end %s\n",
		    $hsp->q_begin,
		    $hsp->q_end);

	     printf("\t\tsubject start %d, s end %s\n",
		    $hsp->s_begin,
		    $hsp->s_end);
	 }
     }
 }

=head1 DESCRIPTION

A Bio::PSU::SearchFactory object creates
Bio::PSU::IO::<format>::Search objects for I/O of each supported
search program. These objects provide the relevant next_result methods
to read search results. Formats currently supported are Wu and NCBI
(T)BlastN/P/X versions 1 and 2, Fasta3 (-m 10 output). Fastx support
will be in the next release.

Both Blast and Fasta support work on the same principle. The 'make'
method accepts either a file or filehandle as the source of the search
program output and returns a Search object. The format of a typical
script would then be:

For Blast ($blast is a Search object):

 while (my $result = $blast->next_result)
 {
     ...
     while (my $hit = $result->next_hit)
     {
         ...
         while (my $hsp = $hit->next_hsp)
	 {
             ...
         }
     }
 }


For Fasta ($fasta is a Search object):

 while (my $result = $fasta->next_result)
 {
     ...
     while (my $hit = $result->next_hit)
     {
         ...
     }
 }

See the relevant module documentation for the methods available to
each object.

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

package Bio::PSU::SearchFactory;

use strict;
use Carp;
use IO::File;
use Bio::PSU::IO::BufferFH;
use Bio::PSU::IO::Fasta::Search;
use Bio::PSU::IO::Blast::Search;

=head2 make

 Title   : make
 Usage   : $search = Bio::PSU::SearchFactory->make(-fh => \*FH, -program =>
         : 'fasta');
         : $search = Bio::PSU::SearchFactory->make(-file => "foo", -program =>
         : 'blast');
 Function: Creates a new Bio::PSU::SearchFactory stream to read
         : Bio::PSU::IO::<format>::Search objects. The stream of Blast or
         : Fasta reports may come from a file (e.g. previously run
         : searches) or a filehandle (e.g. a pipe opened from a running
         : search program).
 Returns : Bio::PSU::IO::<format>::Search object
 Args    : -fh (filehandle) or -file (filename) or -bfh
         : (Bio::PSU::IO::BufferFH object), -program (blast or fasta)

=cut

sub make
{
    my $proto = shift;
    my %args = @_;

    my ($fh, $bfh, $file, $program, $stream);

    %args = map { lc($_), $args{$_} } keys %args;
    foreach (keys %args)
    {
        my $val = $args{$_};
        if (/^-fh$/)      { $fh      = $val; next }
        if (/^-bfh$/)     { $bfh     = $val; next }
        if (/^-file$/)    { $file    = $val; next }
        if (/^-program$/) { $program = $val; next }
    }

    if (defined $fh and defined $bfh)
    {
        confess "SearchFactory accepts one of -file, -fh or -bfh at once"
    }

    if (defined $file)
    {
        if (defined $fh)
        {
	    	confess "SearchFactory accepts one of -file, -fh or -bfh at once"
        }
        else
        {
            $fh = IO::File->new("$file");
            confess "Unable to open $file" unless defined $fh;
        }
    }

    unless (defined $program)
    {
        carp "You need to supply a program to SearchFactory";
        return;
    }

    $bfh = Bio::PSU::IO::BufferFH->new(-fh => $fh) unless defined $bfh;

 CASE:
    {
        if ($program =~ /fasta/i)
        {
            $stream = Bio::PSU::IO::Fasta::Search->new(-bfh => $bfh);
            last CASE;
        }
        if ($program =~ /blast/i)
        {
            $stream = Bio::PSU::IO::Blast::Search->new(-bfh => $bfh);
            last CASE;
        }

        carp "Invalid program [$program] supplied to SearchFactory";
        return;
    }
    return $stream;
}

1;
