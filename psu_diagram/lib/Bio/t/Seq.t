# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..18\n"; use vars qw($loaded)}
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
#   Add systematic DNA/RNA/protein residue checking
#   Add subsequencing with features

# Create a new DNA sequence
my $dna = Bio::PSU::Seq->new
    (-id   => 'my_DNA',
     -desc => 'a DNA sequence',
     -str  => 'atgcttatttctagtcgtttggggatatcgatcacatgcgacgttac',
     -type => 'dna');

# Check type set correctly
if ($dna->is_dna)
{
    print "ok 2\n"
}
else
{
    print "not ok 2\n"
}

# Check sequence set correctly
if ($dna->str eq 'atgcttatttctagtcgtttggggatatcgatcacatgcgacgttac')
{
    print "ok 3\n"
}
else
{
    print "not ok 3\n"
}

# Check reverse-complement
if ($dna->revcom->str eq 'gtaacgtcgcatgtgatcgatatccccaaacgactagaaataagcat')
{
    print "ok 4\n"
}
else
{
    print "not ok 4\n"
}

# Check subsequence
if ($dna->subseq(4, 26)->str eq 'cttatttctagtcgtttggggat')
{
    print "ok 5\n"
}
else
{
    print "not ok 5\n"
}

# Create a new protein sequence
my $pro = $dna->translate;
if ($pro->is_protein)
{
    print "ok 6\n"
}
else
{
    print "not ok 6\n"
}

# Check the translation
if ($pro->str eq 'MLISSRLGISITCDV')
{
    print "ok 7\n"
}
else
{
    print "not ok 7\n"
}

# Check molwt of translation
if ($pro->molwt == 1608)
{
    print "ok 8\n"
}
else
{
    print "not ok 8\n"
}

# Check reverse-complement with features (10 features)
my $in = Bio::PSU::SeqFactory->make(-file => "t/feat_test.embl");
my $rc = Bio::PSU::SeqFactory->make(-file => "t/rcfeat_test.embl");

my $rc_seq = $in->next_seq->revcom;
my $rc_std = $rc->next_seq;

my @rcfeatures = $rc_seq->features;
my @rcstandard = $rc_std->features;

# Access to fuzzy_start and fuzzy_end are currently only supported
# at the Bio::PSU::Range level. It is important to check that these
# are correct
for (my $i = 0; $i < scalar @rcfeatures; $i++)
{
    my $equivalent = 0;
    $equivalent++ if (($rcfeatures[$i]->ranges)[0]->fuzzy_start ==
		      ($rcstandard[$i]->ranges)[0]->fuzzy_start);

    $equivalent++ if ($rcfeatures[$i]->start == $rcstandard[$i]->start);
    $equivalent++ if ($rcfeatures[$i]->end   == $rcstandard[$i]->end);

    $equivalent++ if (($rcfeatures[$i]->ranges)[-1]->fuzzy_end ==
		      ($rcstandard[$i]->ranges)[-1]->fuzzy_end);

    my $test = $i + 9;
    if ($equivalent == 4)
    {
	print "ok $test\n"
    }
    else
    {
	print "not ok $test\n"
    }
}
