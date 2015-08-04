package Bio::PSU::Utils::ExonPairMerger;

###################################
# version with transcripts exon pairs processing
# output :
#   * GFF  => geneid processing
#   * Embl => Artemis 
###################################

use strict;

use Cwd;
##########################################

use Data::Dumper;

use Carp;

# PSU modules for EMBL writing
use Bio::PSU::SeqFactory;
use Bio::PSU::Seq;
use Bio::PSU::Feature;

# $|=1;

#my $exonerateOutput = undef;
#my $runGeneid = 0;
#my $gffOutputFile  = undef;
#my $emblOutputFile = undef;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my $self     = {
		  exonerateOutput  => undef,
		  runGeneid        => 0,
		  emblOutputFile   => undef,
		  gffOutputFile    => undef,
		  curdir           => undef,
		  exonFeaturesPerGene => undef,
		  exonFeaturesPerTranscript => undef,
		  @_,
		 };
  bless ($self, $class);
  return $self;
}

sub setExonerateOutput {
  my $self = shift;
  my ($name) = @_;

  $self->{exonerateOutput} = $name;
}

sub getExonerateOutput {
  my $self = shift;  
  return $self->{exonerateOutput};
}

sub getEmblOutputFile {
  my $self = shift;
  return $self->{emblOutputFile};
}

sub setEmblOutputFile {
  my $self = shift;
  my ($name) = @_;
  
  $self->{emblOutputFile} = $name;
}

sub getGffOutputFile {
  my $self = shift;
  return $self->{gffOutputFile};
}

sub setGffOutputFile {
  my $self = shift;
  my ($name) = @_;
  
  $self->{gffOutputFile} = $name;
}

sub setRunGeneid {
  my $self = shift;
  my ($geneid) = @_;
  
  $self->{runGeneid} = $geneid;
}

sub getRunGeneid {
  my $self = shift;
  return $self->{runGeneid};
}

sub getCurdir {
  my $self = shift;
  return $self->{curdir};
}

sub setCurdir {
  my $self = shift;
  my ($curdir) = @_;
  
  $self->{curdir} = $curdir;
}

# array structure :
# array of hash references
# hash keys : ('exons', 'strand')
# exons value : an array of string, "exon\tstart\tend\n"

sub getExonFeaturesPerGene {
  my $self = shift;
  return @{$self->{exonFeaturesPerGene}};
}

sub getExonFeaturesPerTranscript {
  my $self = shift;
  return @{$self->{exonFeaturesPerTranscript}};
}

# @return the predicted gene features after merging 

sub run {
  my $self = shift;
  my $geneid = 0;
  my $seq_str = "";
  if (@_ > 0) {
    $seq_str = shift;
    $geneid = shift;
    # $self->{runGeneid} = $geneid;
  }
  my ($sequence_name, $genes_ref, $transcripts_ref) = getExonerateFeatures ($self->{exonerateOutput});
  my @genes        = @$genes_ref;
  my @transcripts  = @$transcripts_ref;
  my @new_features = ();

  my @new_genes = processGenes (@genes);

  push (@new_features, @new_genes);

  my @new_transcripts = processTranscripts (@transcripts);
  
  push (@new_features, @new_transcripts);

  writeEmblfeatures ($self->{curdir}, $self->{emblOutputFile}, $seq_str, @new_features);

  if ($geneid) {
    my @exonsFeatures = generateExonsFeatures ($sequence_name, @new_genes);
    writeExonsFeatures ($self->{gffOutputFile}, @exonsFeatures);
  }

  my @exonFeaturesPerGene = generateExonFeaturesPerEntity (@new_genes);
  $self->{exonFeaturesPerGene} = \@exonFeaturesPerGene;

  return @new_genes;
}

##################################################################

sub getExonerateFeatures {
  my ($exonerateOutput) = @_;
  # open GFF Input File
  
  open GFF, "$exonerateOutput";
  my $new_seq_obj = Bio::PSU::Seq->new (
					-type => "dna"
				       );
  
  # to know when we are parsing information about a new gene
  # => close the current CDS feature and open a new one
  my $new_gene = 0;
  
  my $strand = 0;
  my $score  = -1;
  my $percent_id = -1;
  my $cdna_seq_name = "";
  my $sequence_name = "";
  
  my @transcripts  = ();
  my @genes  = ();
  my @ranges = ();
  
  while (<GFF>) {
    
    next if ($_ =~ /^#/);
	     
    my $feature = $_;
	     
    # print STDERR "feature line before gene matching: $feature\n";
	     
    if ($feature =~ /gene\t/) {
    
      # if a new gene has been parsed previously
      # generate a new transcript feature

      if ($new_gene == 1) {
	
	# the transcript feature
	
	my $transcript = Bio::PSU::Feature->new(
						-key    => 'CDS',
						-ranges => [@ranges]
					       );
	$transcript->qadd ('ESTs', "$cdna_seq_name");
	$transcript->qadd ('percent_id', $percent_id);
	$transcript->qadd ('score', $score);
	push (@transcripts, $transcript);

	# the gene feature
	
	my $gene  = Bio::PSU::Feature->new(
					   -key    => 'gene',
					   -ranges => [@ranges]
					  );
	$gene->qadd ('ESTs', "$cdna_seq_name");
	$gene->qadd ('percent_id', $percent_id);
	$gene->qadd ('score', $score);
	push (@genes, $gene);
	
	# reinit @ranges array
	@ranges = ();
      }
      
      $new_gene  = 1;

      # print STDERR "feature line after gene matching: $feature\n";
      # $feature =~ /(\w+)\t+(\S+)\t+(\w+)\t+(\d+)\t+(\d+)\t+(\S+)\t+(\+|-)\t+(.+)/;

      $feature =~ /(\S+)\t+(\w+)\t+(\w+)\t+(\d+)\t+(\d+)\t+(\S+)\t+(\+|-)\t+(.+)/;
      
      $cdna_seq_name = $1;
      $score         = $6;
      $strand        = 0;
      
      if ($7 =~ /\+/) {
	$strand = 1;
      }
      elsif ($7 =~ /-/) {
	$strand = -1;
      }
      
      $feature =~ /.+query\t+(.+)\t+;\t+percent_id\t+(.+)/;
      $sequence_name = $1;
      $percent_id    = $2;
      $sequence_name =~ s/\"//g;
      $sequence_name =~ s/\;//g;
      
      # print STDERR "seq name, %: $sequence_name, $percent_id\n";
      
      next;
    }

    # print STDERR "feature line before exon matching: $feature\n";

    if ($feature =~ /exonerate\t+exon/) {
	       
      # print STDERR "feature line : $feature\n";
      $feature =~ /.+\t+(\d+)\t+(\d+)\t+.+/;

      my $start = $1;
      my $end   = $2;

      # print STDERR "start, end, strand: $start, $end, $strand\n";

      my $range = Bio::PSU::Range->new(-start       => $start,
				       -end         => $end,
				       -strand      => $strand);
      push (@ranges, $range);
    }
  }
  # $gffio->close();
  close GFF;

  if ($new_gene == 1) {
  
    # the transcript feature

    # CDS and transcript are actually the same
    # except the fact that transcripts are going to be processed by linking exon pairs.
    
    my $transcript = Bio::PSU::Feature->new(
					    -key    => 'CDS',
					    -ranges => [@ranges]
					   );
    $transcript->qadd ('ESTs', "$cdna_seq_name");
    $transcript->qadd ('percent_id', $percent_id);
    $transcript->qadd ('score', $score);
    push (@transcripts, $transcript);
    
    # the gene feature

    my $gene  = Bio::PSU::Feature->new(
				       -key    => 'gene',
				       -ranges => [@ranges]
				      );
    $gene->qadd ('ESTs', "$cdna_seq_name");
    $gene->qadd ('percent_id', $percent_id);
    $gene->qadd ('score', $score);
    push (@genes, $gene);
    
  }

  return ($sequence_name, \@genes, \@transcripts);

}


sub processGenes {

  my (@genes) = @_;

  # Gene Features merging into a unique gene model

  # loop on the genes minus those who have been merged
  
  my @new_genes = ();
  
  while (@genes) {
    my $gene1 = splice (@genes,0,1);
    my $i = 0;
    my $merging_number = 1;
    my $nb_loops = 0;
    my $nb_genes = @genes;
    
    # loop on @genes minus gene1
    
    while ($i < $nb_genes) {
      # remove the first gene of the gene array and process it
      my $gene2  = splice (@genes,0,1);
      if (can_do_complete_merge ($gene1, $gene2)) {
	
	$gene1 = merge ($gene1, $gene2, "gene");
	
	# how many merges have been done so far on this gene
	$merging_number++;
	
	$i++;
      }
      else {
	# reprocess gene2 later => add it at the end of the array
	push (@genes, $gene2);
	# incremente $i if a gene has been already processed, ie added at the end of the array, ie when the set of genes has been already processed once
	# otherwise infinite loop
	if ($nb_loops >= ($nb_genes)) {
	  $i++;
	}
      }
      $nb_loops++;
    }
    
    # ponderate the score and the percent_id by the number of merged genes
  
    my @a_tmp = $gene1->qvalues ('score');
    my $score = $a_tmp[0];
    $score = $score/$merging_number;
    @a_tmp = $gene1->qvalues ('percent_id');
    my $percent_id = $a_tmp[0];
    $percent_id = $percent_id/$merging_number;
    $gene1->qremove ('score');
    $gene1->qremove ('percent_id');
    $gene1->qadd ('percent_id', $percent_id);
    $gene1->qadd ('score', $score);
  
    my @values = $gene1->qvalues ('ESTs');
    my $name1  = $values[0];
    
    # print STDERR "\n\tadd new gene - $name1 - into the genes list\n\n";
    
    push (@new_genes, $gene1);
  }
  
  return @new_genes;
} 

 
sub processTranscripts {

  my (@transcripts) = @_;

  # Transcript Features merging by exon pairs processing
  
  # loop on the transcripts minus those who have been merged
  
  my @new_transcripts = ();
  
  while (@transcripts) {
    my $transcript1 = splice (@transcripts,0,1);
    my $i = 0;
    my $merging_number = 1;
    my $nb_loops = 0;
    my $nb_transcripts = @transcripts;
    
    # loop on @transcripts minus transcript1
    
    while ($i < $nb_transcripts) {
      # remove the first transcript of the transcript array and process it
      my $transcript2  = splice (@transcripts,0,1);
      if (can_merge ($transcript1, $transcript2)) {
	
	$transcript1 = merge ($transcript1, $transcript2, "CDS");
	
	# how many merges have been done so far on this transcript
	$merging_number++;
	
	$i++;
      }
      else {
	# reprocess transcript2 later => add it at the end of the array
	push (@transcripts, $transcript2);
	# incremente $i if a transcript has been already processed, ie added at the end of the array, ie when the set of transcripts has been already processed once
	# otherwise infinite loop
	if ($nb_loops >= ($nb_transcripts)) {
	  $i++;
	}
      }
      $nb_loops++;
    }
    
    # ponderate the score and the percent_id by the number of merged transcripts
    
    my @a_tmp = $transcript1->qvalues ('score');
    my $score = $a_tmp[0];
    $score = $score/$merging_number;
    @a_tmp = $transcript1->qvalues ('percent_id');
    my $percent_id = $a_tmp[0];
    $percent_id = $percent_id/$merging_number;
    $transcript1->qremove ('score');
    $transcript1->qremove ('percent_id');
    $transcript1->qadd ('percent_id', $percent_id);
    $transcript1->qadd ('score', $score);
    
    my @values = $transcript1->qvalues ('ESTs');
    my $name1  = $values[0];
    
    # print STDERR "\n\tadd new transcript - $name1 - into the transcripts list\n\n";
    
    push (@new_transcripts, $transcript1);
  }
  
  return @new_transcripts;
}


sub writeEmblfeatures {

  my ($curdir, $emblOutputFile, $seq_str, @emblFeatures) = @_;

  # done => attach the generated features to a sequence object

  my $new_seq_obj = Bio::PSU::Seq->new (
					-type => 'dna',
					-str  => $seq_str
				       );
  $new_seq_obj->features (@emblFeatures);
  
  # copy this seq obj into a new file
  
  # my $embl_output_file_path = $curdir . '/' . $emblOutputFile;
  # if path already included !!!
  my $embl_output_file_path = $emblOutputFile;

  my $new_output_obj = undef;
  
  # always in an EMBL format
  
  $new_output_obj = Bio::PSU::SeqFactory->make(
					       -file   => ">$embl_output_file_path",
					       -format => 'embl'
					      );
  $new_output_obj->write_seq($new_seq_obj);
}

# generate a set of GFF exon features from the set of features (gene features or transcript features)

sub generateExonsFeatures {
  my ($sequence_name, @set) = @_;
  my @exonsFeatures = ();
  my $source = "exonerate";
  my $score = ".";
  my $frame = ".";
  
  # sort based on feature->ranges[0]->start value
  # so assume that foreach feature, the ranges are already sorted
  
  @set = sortFeatures (@set);
    
  foreach my $feature (@set) {
    my @ranges = sortRanges ($feature->ranges);
    my @values = $feature->qvalues ('ESTs');
    my $ESTs   = $values[0];
    my $attributes = "ESTs \"$ESTs\"";
    my $i = 0;
    
    foreach my $range (@ranges) {
      my $start  = $range->start;
      my $end    = $range->end;
      my $strand = $range->strand;
      
      # convert Exon feature into First - Internal - Terminal

      my $feature_name = "";

      # if a unique exon => Terminal
      
      if (@ranges == 1) {
	$feature_name = "Terminal";
      }
      elsif ($i != 0 && $i != @ranges) {
	$feature_name = "Internal";
      }
      else {
	# more complicate because can be an unfinished sequence !!
	# and so the last or first exon can be actually an Internal exon

	if (($i==0 && $strand==1) || ($i==@ranges-1 && $strand==-1)) { 
	  $feature_name = "First";
	}
	else {
	  $feature_name = "Terminal";
	}
      }
      
      if ($strand == 1) {
	$strand = "+";
      }
      else {
	$strand = "-";
      }
      
      my $gff_feature = "$sequence_name\t$source\t$feature_name\t$start\t$end\t$score\t$strand\t$frame\t$attributes";
      push (@exonsFeatures, $gff_feature);

      # if First or Last Exon, add another feature - Internal Exon
      
      # if ($feature_name =~ /First|Terminal/) {
      # $feature_name = "Internal";
      # $gff_feature = "$sequence_name\t$source\t$feature_name\t$start\t$end\t$score\t$strand\t$frame\t$attributes";
      # push (@exonsFeatures, $gff_feature);
      # }
      
      $i++;
    }
  }

  return @exonsFeatures;
}


# generate a set of Genomewise exon features from a set of features (gene features or transcript features)
# syntax : exon start end
# classify by the strand

sub generateExonFeaturesPerEntity {
  my (@set) = @_;
  my @exonFeaturesPerEntity = ();
  
  # sort based on feature->ranges[0]->start value
  # so assume that foreach feature, the ranges are already sorted
  
  @set = sortFeatures (@set);
    
  foreach my $feature (@set) {
    my @ranges = sortRanges ($feature->ranges);
    my $strand = 0;
    my @exons = ();

    foreach my $range (@ranges) {
      my $start  = $range->start;
      my $end    = $range->end;
      $strand = $range->strand;
      my $exonFeature = "exon\t$start\t$end\n";
     
      push (@exons, $exonFeature);
    }

    my %entity = (
		  'exons' => \@exons,
		  'strand'  => $strand,
		 );
    
    push (@exonFeaturesPerEntity, \%entity);
  }

  # print STDERR "dump: " . Dumper (@exonFeaturesPerEntity) . "\n";

  return @exonFeaturesPerEntity;
}


sub writeExonsFeatures {
  my ($gffOutputFile, @exonsFeatures) = @_;

  # copy these features into a GFF output file

  open (OUTGFF, ">$gffOutputFile") or die "can't open file, $gffOutputFile\n";

  foreach my $feature (@exonsFeatures) {
    print OUTGFF "$feature\n";
  }

  close OUTGFF;
}


sub getGeneRange {
  my (@ranges) = @_;
  my $start = 1000000000000;
  my $end = -1;
  my $strand = 0;

  foreach my $range (@ranges) {
    $strand = $range->strand();
    $start  = min ($start, $range->start);
    $end    = max ($end, $range->end);
  }
  
  # print STDERR "start, end, strand: $start, $end, $strand\n";

  my $range = Bio::PSU::Range->new(-start       => $start,
				   -end         => $end,
				   -strand      => $strand
				  );
  return $range;
}


sub getRange {
  my ($range1, $range2) = @_;

  my $strand = $range1->strand;
  my $start  = min ($range1->start, $range2->start);
  my $end    = max ($range1->end, $range2->end);

  # print STDERR "start, end, strand: $start, $end, $strand\n";

  my $range = Bio::PSU::Range->new(-start       => $start,
				   -end         => $end,
				   -strand      => $strand
				  );
  return $range;
}


sub min {
  my ($int1, $int2) = @_;
  my $min = -1;

  if ($int1 < $int2) {
    $min = $int1;
  }
  else {
    $min = $int2;
  }

  return $min;
}


sub max {
  my ($int1, $int2) = @_;
  my $max = -1;

  if ($int1 > $int2) {
    $max = $int1;
  }
  else {
    $max = $int2;
  }

  return $max;
}


sub remove {
  my ($index, @genes) = @_;
  my @new_genes = ();
  my $i = 0;

  while (@genes) {
    my $gene = pop (@genes);
    if ($i == $index) {
      push (@new_genes, @genes);
      last;
    }
    else {
      push (@new_genes, $gene);
    }
    $i++;
  }

  return @new_genes;
}


sub can_merge {
  my ($tr1, $tr2) = @_;

  # true if (
  #          tr1 and tr2 share at least one overlaping exon
  #          and no 5' gap
  #          and no 3' gap
  #         )

  my @values = $tr1->qvalues ('ESTs');
  my $name1  = $values[0];
  @values = $tr2->qvalues ('ESTs');
  my $name2 = $values[0];

  # print STDERR "tr1 - $name1 - tr2 - $name2 - can be merged ? ";
  my $display = 0;
  if ($name2 =~ /CONTIG586/) {
    $display = 1;
  }
  $display = 0;

  if (overlap ($tr1, $tr2)
      && (not (fiveprimegap ($tr1, $tr2, $display)))
      && (not (threeprimegap ($tr1, $tr2, $display)))
     ) {
    # print STDERR "yes\n";
    return 1;
  }
  else { 
    # print STDERR "no\n";
    return 0; 
  }
}

# gap or not gap, do the merging. 
# Consequence: generate a unique gene structure

sub can_do_complete_merge {
  my ($tr1, $tr2) = @_;

  # true if (
  #          tr1 and tr2 share at least one overlaping exon
  #         )

  my @values = $tr1->qvalues ('ESTs');
  my $name1  = $values[0];
  @values = $tr2->qvalues ('ESTs');
  my $name2 = $values[0];

  # print STDERR "tr1 - $name1 - tr2 - $name2 - can be merged ? ";
  my $display = 0;
  if ($name2 =~ /CONTIG586/) {
    $display = 1;
  }
  $display = 0;

  if (overlap ($tr1, $tr2)) {
    # print STDERR "yes\n";
    return 1;
  }
  else {
    # print STDERR "no\n";
    return 0;
  }
}


sub merge {
  my ($transcript1, $transcript2, $feature_name) = @_;

  my @ranges1 = $transcript1->ranges;
  my @ranges2 = $transcript2->ranges;
  my @new_ranges = getMergedRanges (\@ranges1, \@ranges2);
  
  # update score, percent_id and ESTs information
  
  # score
  my @a_tmp = $transcript1->qvalues ('score');
  my $score1 = $a_tmp[0];
  @a_tmp = $transcript2->qvalues ('score');
  my $score2 = $a_tmp[0];
  my $score = $score1 + $score2;
  # percent_id
  @a_tmp = $transcript1->qvalues ('percent_id');
  my $percent1 = $a_tmp[0];
  @a_tmp = $transcript2->qvalues ('percent_id');
  my $percent2 = $a_tmp[0];
  my $percent_id = $percent1 + $percent2;
  # ESTs sequences
  @a_tmp = $transcript1->qvalues ('ESTs');
  my $est = $a_tmp[0];
  @a_tmp = $transcript2->qvalues ('ESTs');
  my $est2 = $a_tmp[0];
  # if the contig, est2, is not in the est list, add it
  if (not $est2 =~ /$est/) {
    $est = "$est, $est2";
  }

  # the new transcript feature
  
  my $new_transcript = Bio::PSU::Feature->new(
					      -key    => "$feature_name",
					      -ranges => [@new_ranges]
					     );
  $new_transcript->qadd ('ESTs', $est);
  $new_transcript->qadd ('percent_id', $percent_id);
  $new_transcript->qadd ('score', $score);

  return $new_transcript;
}


sub overlap {
  my ($transcript1, $transcript2) = @_;
  my @ranges1 = $transcript1->ranges;
  my @ranges2 = $transcript2->ranges;
  
  # if on different strand - they don't overlap
  my $range1 = $ranges1[0];
  my $range2 = $ranges2[0];
  if ($range1->strand != $range2->strand) {
    return 0;
  }

  # print STDERR "ranges in overlap: @ranges2\n";

  foreach my $range (@ranges1) {
    if ($range->overlaps (@ranges2)) {
      return 1;
    }
  }
  return 0;
}

# whatever any exon pair, true if there is a gap upstream from them

sub fiveprimegap {
  my ($tr1, $tr2, $display) = @_;
  
  my @ranges1 = sortRanges ($tr1->ranges);
  my @ranges2 = sortRanges ($tr2->ranges);
  my $i1 = 0;

  # print STDERR "ranges in fiveprimegap: @ranges2\n";

  while ($i1 < @ranges1) {
    my $range1 = $ranges1[$i1];
    if ($range1->overlaps (@ranges2)) {
      my $i2 = 0;
      while ($i2 < @ranges2) {
	# print STDERR "i2, range[i2] in fiveprimegap: $i2, " . $ranges2[$i2] . "\n";
	if ($range1->overlaps ($ranges2[$i2])) {

	  if ($display) {
	    print STDERR "overlap on " . $range1->start . ".." . $range1->end . "\n";
	  }

	  my $j1 = $i1-1;
	  my $j2 = $i2-1;
	  while ($j1>=0 && $j2>=0) {
	    # print STDERR "range[j2] in fiveprimegap: " . $ranges2[$j2] . "\n";
	    if (not $ranges1[$j1]->overlaps ($ranges2[$j2])) {

	      if ($display) {
		print STDERR "fiveprimegap found...\n";
	      }
	      
	      return 1;
	    }
	    $j1--;
	    $j2--;
	  }
	}
	$i2++;
      }
    }
    $i1++;
  }
  # no 5' gap - actually because no exon pair or because they all overlap each other upstream any exon pair
  return 0;
}

# whatever two overlaping exons, true if there is a gap downstream from them

sub threeprimegap {
  my ($tr1, $tr2, $display) = @_;
  
  my @ranges1 = sortRanges ($tr1->ranges);
  my @ranges2 = sortRanges ($tr2->ranges);

  my $i1 = 0;

  # print STDERR "ranges2 in threeprimegap: @ranges2\n";

  while ($i1 < @ranges1) {
    my $range1 = $ranges1[$i1];
    if ($range1->overlaps (@ranges2)) {
      my $i2 = 0;
      while ($i2 < @ranges2) {
	# print STDERR "range2[i2] in threeprimegap: " . $ranges2[$i2] . "\n";

	if ($display) {
	    print STDERR "overlap on " . $range1->start . ".." . $range1->end . "\n";
	  }

	if ($range1->overlaps ($ranges2[$i2])) {
	  my $j1 = $i1+1;
	  my $j2 = $i2+1;
	  while ($j1<@ranges1 && $j2<@ranges2) {
	    # print STDERR "range[j2] in threeprimegap: " . $ranges2[$j2] . "\n";
	    if (not $ranges1[$j1]->overlaps ($ranges2[$j2])) {

	      if ($display) {
		print STDERR "threeprimegap found...\n";
	      }

	      return 1;
	    }
	    $j1++;
	    $j2++;
	  }
	}
	$i2++;
      }
    }
    $i1++;
  }
  # no 3' gap - actually because no exon pair or because they all overlap each other dowstream any exon pair
  return 0;
}


sub getMergedRanges {
  my ($ranges1_ref, $ranges2_ref) = @_;
  my @ranges1 = @$ranges1_ref;
  my @ranges2 = @$ranges2_ref;

  @ranges1 = sortRanges (@ranges1);
  @ranges2 = sortRanges (@ranges2);

  my $nb_ranges1 = @ranges1;
  my $nb_ranges2 = @ranges2;

  my @new_ranges = ();
  my $i1 = 0;
  my $i2 = 0;

  while ($i1<@ranges1 && $i2<@ranges2) {
    my $range1 = $ranges1[$i1];
    my $range2 = $ranges2[$i2];

    my $new_range = undef;
    
    if ($range1->overlaps($range2)) {
      # if range conflict - doesn't start and/or end at the same coordinate
      my $conflict = has_conflict (\@ranges1, \@ranges2, $i1, $i2);
      if ($conflict) {
	$new_range = getInternalRange (\@ranges1, \@ranges2, $i1, $i2);
      }
      else {
	# get min/max range
	$new_range = getRange ($range1, $range2);
      }
      $i1++;
      $i2++;
    }
    elsif ($range1->start < $range2->start) {
      $new_range = $range1;
      $i1++;
    }
    else {
      $new_range = $range2;
      $i2++;
    }

    push (@new_ranges, $new_range);
  }

  if ($i1 < $nb_ranges1) {
    push (@new_ranges, splice (@ranges1, $i1, $nb_ranges1));
  }
  else {
    push (@new_ranges, splice (@ranges2, $i2, $nb_ranges2));
  }

  # merge contiguous overlapping ranges within the same ranges

  @new_ranges = mergeOverlappingRanges (@new_ranges);

  return @new_ranges;
}


# Merge overlapping contiguous ranges within the same feature

sub mergeOverlappingRanges {
  my (@ranges) = @_;
  my $i = 0;
  my @new_ranges = ();

  while (@ranges) {
    my $range1      = splice (@ranges,0,1);
    if ($range1->overlaps (@ranges)) {
      my $range2    = splice (@ranges,0,1);
      my $start     = min ($range1->start, $range2->start);
      my $end       = max ($range1->end, $range2->end);
      my $strand    = $range1->strand;
      my $new_range = Bio::PSU::Range->new(
					   -start       => $start,
					   -end         => $end,
					   -strand      => $strand
					  );
      push (@new_ranges, $new_range);
    }
    else {
      push (@new_ranges, $range1);
    }
    $i++;
  }

  return @new_ranges;
}


sub sortRanges {
  my (@ranges) = @_;

  my @new_ranges = sort { $a->start <=> $b->start } @ranges;

  return @new_ranges;
}


sub has_conflict {
  my ($ranges1_ref, $ranges2_ref, $i1, $i2) = @_;
  my @ranges1 = @$ranges1_ref;
  my @ranges2 = @$ranges2_ref;
  my $conflict = 0;
  
  if (
      ($i1==@ranges1-1 xor $i2==@ranges2-1) || ($i1==0 xor $i2==0)
     ) {
    $conflict = 1;
  }
  
  return $conflict;
}


sub getInternalRange {
  my ($ranges1_ref, $ranges2_ref, $i1, $i2) = @_;
  my @ranges1 = @$ranges1_ref;
  my @ranges2 = @$ranges2_ref;
  
  my $range1 = $ranges1[$i1];
  my $range2 = $ranges2[$i2];

  my $start  = -1;
  my $end   = -1;
  my $strand = $range1->strand;

  # end coordinate

  if ($i1==@ranges1-1 xor $i2==@ranges2-1) {
    if ($i1!=@ranges1-1) {
      # if $range1 is internal and $range2 is not => end = $range1->end
      # else end = $range2->end
      $end = $range1->end;
    }
    else {
      $end = $range2->end;
    }
  }
  else {
    # they're both internal
    # otherwise min/max policy
    $end = max ($range1->end, $range2->end);
  }

  # start coordinate

  if ($i1==0 xor $i2==0) {
    if ($i1!=0) {
      # if $range1 is internal and $range2 is not => start = $range1->start
      # else start = $range2->start
      $start = $range1->start;
    }
    else {
      $start = $range2->start;
    }
  }
  else {
    # they're both internal
    # otherwise min/max policy
    $start = min ($range1->start, $range2->start);
  }

  my $new_range = Bio::PSU::Range->new(-start       => $start,
				       -end         => $end,
				       -strand      => $strand
				      );
  
  return $new_range;
}


sub sortFeatures {
  my (@old_features) = @_;
  my @new_features   = ();
  
  my $feature = undef;

  while (@old_features) {
    ($feature, @old_features) = minFeature (@old_features);
    push (@new_features, $feature);
  }

  return @new_features;
}

sub minFeature {
  my (@old_features) = @_;
  my $min_feature    = $old_features[0];
  my $index = 0;
  my $i = 1;

  while ($i < @old_features) {
    my $old_feature = $old_features[$i];
    my @old_ranges  = $old_feature->ranges;
    my $old_range   = $old_ranges[0];
    my @min_ranges  = $min_feature->ranges;
    my $min_range   = $min_ranges[0];
    if ($old_range->start < $min_range->start) {
      $min_feature = $old_feature;
      $index = $i;
    }
    $i++;
  }
  splice (@old_features, $index, 1);
  return ($min_feature, @old_features);
}
