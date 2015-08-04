=head1 NAME

Bio::PSU::SeqFactory - Object which creates sequence I/O stream
objects for various file formats

=head1 SYNOPSIS

 use strict;
 use Bio::PSU::SeqFactory;

 my $file = shift;

 my $seqi = Bio::PSU::SeqFactory->make(-file => $file,    -format => 'embl');
 my $seqo = Bio::PSU::SeqFactory->make(-fh   => \*STDOUT, -format => 'embl');

 while (my $seq = $seqi->next_seq)
 {
    print "EMBL entry ", $seq->id, ":\n";
    print "Length ", $seq->length, "\n";

    if (my $fnum = $seq->has_features)
    {
	     print "It has $fnum features:\n";

	     foreach my $feature ($seq->features)
	     {
	         printf("\tType:%s (from %d to %d)\n",
	         $feature->key,
	         $feature->start,
	         $feature->end);
	     }
     }
     $seqo->write_seq($seq);
 }

=head1 DESCRIPTION

A Bio::PSU::SeqFactory object creates Bio::PSU::IO::<format>::Stream
objects for I/O of each supported sequence format. These objects
provide the relevant next_seq and write_seq methods to read and write
sequence entries.

Input may be from a file or filehandle (specified by the -fh or -file
arguments to the constructor). If using a file, EMBL and Fasta format
are detected, so the -format argument is optional.

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

package Bio::PSU::SeqFactory;

use strict;
use Carp;
use IO::File;
use Bio::PSU::IO::BufferFH;
use Bio::PSU::IO::Fasta::Stream;
use Bio::PSU::IO::EMBL::Stream;

=head2 make

 Title   : make
 Usage   : $stream = Bio::PSU::SeqFactory->make(-fh => \*FH, -format => 'embl');
         : $stream = Bio::PSU::SeqFactory->make(-file => ">foo", -format =>
         : 'fasta', -type => 'dna');
 Function: Creates a new Bio::PSU::SeqFactory stream to read or write Bio::PSU::Seq
         : objects. The file argument expects standard Perl mode strings
         : ("<", ">>" etc) as it uses the IO::File module. If the sequence
         : format is not specified, the SeqFactory tries to guess which
         : format to use by looking at the first line.
 Returns : Bio::PSU::IO::<format>::Stream object
 Args    : -fh (filehandle) or -file (filename) or -bfh
         : (Bio::PSU::IO::BufferFH object), -format (embl or fasta),
         : -type (dna, protein, rna, virtual). Sequence type is not
         : required for EMBL format (which is set to 'dna' by default),
         : but is advised for Fasta

=cut

sub make
{
    my $proto = shift;
    my %args = @_;

    my ($fh, $file, $bfh, $format, $type, $stream);

    %args = map { lc($_), $args{$_} } keys %args;
    foreach (keys %args)
    {
		my $val = $args{$_};
		if (/^-fh$/)     { $fh     = $val; next }
		if (/^-bfh$/)    { $bfh    = $val; next }
		if (/^-file$/)   { $file   = $val; next }
		if (/^-format$/) { $format = $val; next }
		if (/^-type$/)   { $type   = $val; next }
    }

    if (defined $fh and defined $bfh)
    {
		confess "SeqFactory accepts one of -file, -fh or -bfh at once"
    }

    if (defined $file)
    {
		if (defined $fh or defined $bfh)
		{
			confess "SeqFactory accepts one of -file, -fh or -bfh at once"
		}
		else
		{
			$fh = IO::File->new("$file");
			confess "Unable to open $file" unless defined $fh;
		}
    }

    $bfh = Bio::PSU::IO::BufferFH->new(-fh => $fh) unless defined $bfh;
    $format = _test_format($bfh) unless defined $format;

 CASE:
    {
		if ($format =~ /fasta/i)
		{
			$stream = Bio::PSU::IO::Fasta::Stream->new(-bfh  => $bfh,
													   -type => $type);
			last CASE;
		}
		if ($format =~ /embl/i)
		{
			$stream = Bio::PSU::IO::EMBL::Stream->new(-bfh => $bfh);
			last CASE;
		}

		if ($format =~ /auto_detect/i)
		{
			confess "Unable to auto detect sequence format";
		}

		carp "Invalid format [$format] supplied to SeqFactory";
		return;
    }
    return $stream;
}

=head2 _test_format

 Title   : _test_format
 Usage   : N/A
 Function: Reads the first informative line from the sequence
         : passing through an Bio::PSU::IO::BufferFH object and
         : tries to guess the sequence format
 Returns : Sequence type as string
 Args    : Bio::PSU::IO::BufferFH object

=cut

sub _test_format
{
    my ($bfh) = @_;

    my $format = 'auto_detect';

    while (my $line = $bfh->unbuffered_read)
    {
		if ($line !~ /^\s*$/)
		{
			$line =~ /^>/          and $format = 'fasta';
			$line =~ /^(ID|FH|FT)/ and $format = 'embl';
			$bfh->buffer_line($line);
			last;
		}
    }
    return $format;
}

1;
