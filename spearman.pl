#!/usr/common/usg/languages/perl/5.16.0/bin/perl

# 10-2011 - Kostas Billis

use strict;
use warnings;
use Getopt::Long;
use Statistics::Descriptive;
use Statistics::RankCorrelation;


# perl spearman.pl 
#     --gff      $gff_file
#     --dir      $is_directional
#     --wigdir   $wig_dir          i.e. the genome's wig directory
#     --sampleA  $Asample_id        
#     --sampleB  $Bsample_id
#     --out      $tmp_out_file 

# http://www.wellesley.edu/Psychology/Psych205/spearman.html
#
# The correlation coefficient is a number between +1 and -1. It tells us about
# the magnitude and direction of the association between two variables.
# The MAGNITUDE is the strength of the correlation. The closer the correlation
# is to either +1 or -1, the stronger the correlation. If the correlation is 0
# or very close to 0, there is no association between the two variables. Here,
# we have a moderate correlation (r = -.392).
# 
# The DIRECTION of the correlation tells us how the two variables are related.
# If the correlation is positive, the two variables have a positive relation-
# ship (as one increases, the other also increases). If the correlation is 
# negative, the two variables have a negative relationship (as one increases,
# the other decreases). Here, we have a negative correlation (r = -.392). 
# As self-esteem increases, anxiety decreases.

# example files:
#
# my $gff_file = "/house/groupdirs/genome_biology/rna_seq/"
#              . "637000315/gff/637000315.gbk.gff 
# my $outfile = "./test_spearman.tab";
# my $wig_dir = "/house/groupdirs/genome_biology/rna_seq/"
#             . "637000315/wig/directional_lib/
#
# my $help;

my ($gff_file, $is_directional, $wig_dir,
    $Asample_id, $Bsample_id, $outfile, $help);

# GET OPTIONS
GetOptions( 'gff=s'     => \$gff_file,
	    'dir=s'     => \$is_directional,
	    'wigdir=s'  => \$wig_dir,
	    'sampleA=s' => \$Asample_id,
	    'sampleB=s' => \$Bsample_id,
	    'out=s'     => \$outfile,
	    'h|help'    => \$help
);

my $usage = <<'ENDHERE';
NAME
    spearman.pl
PURPOSE
    Use Wig file of 2 samples/conditions to find correlation.
    Divide genes in windows, find mean per window, estimate 
    spearman correlation of each gene between those two 
    samples/conditions.
INPUT
    --gff <*.gff3> : gene coordinates infile in GFF3 format (optional)
    --dir : Does this genome have directional libraries? 1=y or 2=n
    --wigdir : directory of the wigs for the genome
    --sampleA : provide the id of the sampleA 
    --sampleB : provide the id of the sampleA 
OUTPUT
    --out <> : Table of genes and spearman correlations
BY
    kbillis@lbl.gov
ENDHERE

if ($help) { print $usage; exit; }

####################################
# Get the required .wig files:
####################################
opendir (my $dh, $wig_dir) || die "can't opendir $wig_dir: $!"; 
my @sampleAwigs = 
    grep {/$Asample_id/ && (/cov.wig/ || /cor.wig/)} readdir($dh); 
closedir $dh; 
 
opendir(my $dh1, $wig_dir) || die "can't opendir $wig_dir: $!"; 
my @sampleBwigs = 
    grep {/$Bsample_id/ && (/cov.wig/ || /cor.wig/)} readdir($dh1); 
closedir $dh1; 

my %scaffolds; 
my @tmpSpearman; 
my @print_res; 
 
if ($#sampleBwigs != $#sampleAwigs) {
    print "error: number of sample wig files is not equal.\n";
    exit; 
} 
 
foreach my $fileScaffold (@sampleBwigs) { 
    my @array_t = split(/\./ , $fileScaffold);
    my $scaf_tmp= $array_t[$#array_t-2];
 
    if (!exists $scaffolds{$scaf_tmp}) {
	$scaffolds{$scaf_tmp} = [ 1 ]; # store array with one value     
	@tmpSpearman = spearman
	    ($Asample_id, $Bsample_id, $gff_file,
	     $scaf_tmp, $wig_dir, $is_directional); 
	push(@print_res, @tmpSpearman);
	@tmpSpearman = ();
    }
} 

open(OUT, ">$outfile") or die($!); 
print OUT "chrGff\tgene\tgeneOID\tstrand\ttype\tlen\tSPEARMAN\t\n";
foreach my $print_tmp (@print_res) { 
    print OUT $print_tmp . "\n";
} 
close OUT; 

#####################
# Calculate spearman:
#####################
sub spearman { 
    my ($Asample_id_S, $Bsample_id_S, $gff_file_S, 
	$scaf_tmp_S, $wig_dir_S, $is_directional_S) = @_; 
    my $inACorwig = $wig_dir . $Asample_id_S . "." . $scaf_tmp_S . ".cor.wig"; 
    my $inACovwig = $wig_dir . $Asample_id_S . "." . $scaf_tmp_S . ".cov.wig"; 
    my $inBCorwig = $wig_dir . $Bsample_id_S . "." . $scaf_tmp_S . ".cor.wig"; 
    my $inBCovwig = $wig_dir . $Bsample_id_S . "." . $scaf_tmp_S . ".cov.wig"; 
    
    my $result; 
    my @spearman_res; 

    my @sampleACor; sample_Wig_S($inACorwig,\@sampleACor); # -              
    my @sampleACov; sample_Wig_S($inACovwig,\@sampleACov); # +              
    
    my @sampleBCor; sample_Wig_S($inBCorwig,\@sampleBCor); 
    my @sampleBCov; sample_Wig_S($inBCovwig,\@sampleBCov); 
 
    sub sample_Wig_S { 
	my ($infile1_, $array_ref) = @_; 
	open(WIG, "<$infile1_") or die("ERROR: Cannot open $infile1_\n"); 
	while (<WIG>) { 
	    chomp; 
	    if (/[abcxyz]/) { 
		# header
	    } else { 
		push(@$array_ref, $_) 
	    } 
	} 
	close WIG; 
    } 
    
    open(IN,  "<$gff_file_S")  or die($!); 
    
    my @prev_starts; 
    my @prev_ends; 
    my @geneCalled; 
    my $sqtotal = 0; 
    my $total = 0; 
    my $printStrand;
    my ($len, $readsCOV, $readsGC, $median, $average, $stddev); 
    my ($chrGff,$src,$type,$start,$end,$score,$strandG,$phase,
	$comment,$geneID, $prev_genOID, $geneOID); 

    while (<IN>) { 
        chomp; 
	
        ($chrGff,$src,$type,$start,$end,$score,
	 $strandG,$phase,$comment) = split(/\t/);

	if ( ($type eq 'CDS') && ($scaf_tmp_S eq $chrGff) ) {
	    my @geneCalled = split(/"/, $_);
	    $geneOID=$geneCalled[5];
	    my $gene = $geneCalled[1]; 
	    my @dataA; 
	    my @dataB;
	    
	    my $no_Directional_libraries = "+"; 
            $printStrand = $strandG; 

	    # if there are no directional libraries,
	    # ignore the strand of the gene
	    if ( $is_directional_S == 2 ) {
		$strandG = $no_Directional_libraries;
	    } 
	    
	    if ($strandG eq "+") { 
		push(@dataA, @sampleACov[$start-1..$end-1]);
		push(@dataB, @sampleBCov[$start-1..$end-1]);
	    }
	    elsif ($strandG eq "-") {
		push(@dataA, @sampleACor[$start-1..$end-1]);
		push(@dataB, @sampleBCor[$start-1..$end-1]);
	    } 
	    
	    if ((not (@dataA)) || (not (@dataB))) {
		exit;
	    }
 
	    ## for spearman correlation                             
	    my (@xx, @yy); 
	    $len = $end-$start; 
	    my $observations = 17;
	    my $every = int($len/$observations)-1;
	    
	    # for random observations, take 1st for and last push    
	    for (my $m=40; $m<$#dataA-40; $m=$m+$every ) {
		my (@xxA, @yyB);
		
		@xxA = @dataA[ $m-($every/2)..$m+($every/2) ];
		@yyB = @dataB[ $m-($every/2)..$m+($every/2) ];
		
		my $meanXXA = do { 
		    my $s;
		    $s += $_ for @xxA ; 
		    $s / scalar(@xxA)
		};
		
 
		my $meanYYB = do {
		    my $s;
		    $s += $_ for @yyB;
		    $s / scalar(@yyB)
		};
		
		push(@xx, $meanXXA); 
		push(@yy, $meanYYB); 
		
	    } 
 
            if ((@xx) && (@yy)) {
		my $x = [ @xx ]; 
		my $y = [ @yy ]; 
		my $c = Statistics::RankCorrelation->new($x, $y, sorted => 1); 
		my $n = $c->spearman; 
		$result = join("\t", $chrGff, $gene, $geneOID,
			       $printStrand, $type, $len, $n  ); 
		push(@spearman_res, $result);
	    }
	}
    } 
    close IN;  
    return @spearman_res; 
} 

exit;
