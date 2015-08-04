# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..12\n"; use vars qw($loaded)}
END {print "not ok 1\n" unless $loaded;}

use strict;
use lib '../';
use Bio::PSU::SeqFactory;

$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# To do:
#   Add fuzzy range features
#   Add zero-width features
#   Add other difficult features

# Read an EMBL file
my $embl = Bio::PSU::SeqFactory->make(-file => 't/feat_test.embl');
if ($embl)
{
    print "ok 2\n"
}
else
{
    print "not ok 2\n"
}

# Get a sequence from an EMBL stream
my $eseq = $embl->next_seq;

if (defined $eseq)
{
    print "ok 3\n"
}
else
{
    print "not ok 3\n"
}

# Test EMBL sequence type
if ($eseq->type eq 'dna')
{
    print "ok 4\n"
}
else
{
    print "not ok 4\n"
}

if ($eseq->length == 2100)
{
    print "ok 5\n"
}
else
{
    print "not ok 5\n"
}

# Test EMBL feature count
if ($eseq->has_features == 10)
{
    print "ok 6\n"
}
else
{
    print "not ok 6\n"
}

# Read a Fasta file
my $fasta = Bio::PSU::SeqFactory->make(-file => 't/seq_test.nt', -type => 'dna');
if ($fasta)
{
    print "ok 7\n"
}
else
{
    print "not ok 7\n"
}

# Get a sequence from the Fasta stream
my $fseq = $fasta->next_seq;

if (defined $fseq)
{
    print "ok 8\n"
}
else
{
    print "not ok 8\n"
}

# Test Fasta sequence type
if ($fseq->type eq 'dna')
{
    print "ok 9\n"
}
else
{
    print "not ok 9\n"
}

# Test Fasta id
if ($fseq->id eq 'seq_test')
{
    print "ok 10\n"
}
else
{
    print "not ok 10\n"
}

# Test Fasta desc
if ($fseq->desc eq 'A test sequence')
{
    print "ok 11\n"
}
else
{
    print "not ok 11\n"
}

# Test Fasta sequence length
if ($fseq->length == 2100)
{
    print "ok 12\n"
}
else
{
    print "not ok 12\n"
}
