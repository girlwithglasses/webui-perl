# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..11\n"; use vars qw($loaded)}
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

# Get the features
my @features = $embl->next_seq->features;

# Check missing 5' end feature
if ($features[0]->start == 1 and $features[0]->end == 38)
{
    print "ok 2\n"
}
else
{
    print "not ok 2\n"
}

# Check zero-width feature
if ($features[1]->start == 20 and $features[1]->end == 39)
{
    print "ok 3\n"
}
else
{
    print "not ok 3\n"
}

# Check fuzzy start/end feature
if ($features[5]->start == 1260 and $features[5]->end == 1349)
{
    print "ok 4\n"
}
else
{
    print "not ok 4\n"
}

# Check fuzzy start feature
if ($features[7]->start == 1760 and $features[7]->end == 1780)
{
    print "ok 5\n"
}
else
{
    print "not ok 5\n"
}

# Check fuzzy end feature
if ($features[8]->start == 1800 and $features[8]->end == 1820)
{
    print "ok 6\n"
}
else
{
    print "not ok 6\n"
}

# Check missing 3' end feature
if ($features[9]->start == 1910 and $features[9]->end == 2100)
{
    print "ok 7\n"
}
else
{
    print "not ok 7\n"
}


# Check getting sequence of feature
if ($features[1]->str eq 'catggcggtgatttcccacg')
{
    print "ok 8\n"
}
else
{
    print "not ok 8\n"
}

# Check getting translation of spliced feature (implies DNA sequence is
# retrieved correctly). Using default translation table
if ($features[2]->translate->str eq 'MATARGPAGRQWRTPVAPAHTRADGHEKRGAPPARRGTPRTVVLSRRPVSACRPPPARPAGPAGSRRATGAAAAAVPRRSARHPDGPVPSPPRPGRASNAARPSRTYGSPWSVRASGSPETRRARPCPSTGRSGPGRYQPACSQSTSTGPAGDMRTLDSSASPWQNWPMPWRPPAWAMPCSSFCRSPRSRSVSSPSSWPACRCPDPPRSASAPAPEGAAGRTSGMPLSRAGCVPPRRGSGPLSTWPPPCCARSFRPGARSVRCAAAPARGRTRGRSGARRRSPCAVGPPGGRTGRFSR')
{
    print "ok 9\n"
}
else
{
    print "not ok 9\n"
}

# Check getting translation using non-default (bacterial: 11) table
# and GTG-start
if ($features[9]->translate(11)->str eq 'MRGNGHTTGAKSIPTACRGRPSGLRRSSPNSREWTSCSTDAAWWARAPRSPRAPHSAAPCTTG')
{
    print "ok 10\n"
}
else
{
    print "not ok 10\n"
}

# Check getting translation using non-default (bacterial: 11) table
# and GTG-start, but specifying that the first codon is not a start
if ($features[9]->translate(11, 1, 0)->str eq 'VRGNGHTTGAKSIPTACRGRPSGLRRSSPNSREWTSCSTDAAWWARAPRSPRAPHSAAPCTTG')
{
    print "ok 11\n"
}
else
{
    print "not ok 11\n"
}
