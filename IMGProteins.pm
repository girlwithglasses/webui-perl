############################################################################
# IMGProteins.pm - displays proteomic data
# $Id: IMGProteins.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package IMGProteins;
my $section = "IMGProteins";
my $study = "proteomics";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use GD;
use DrawTree; 
use DrawTreeNode; 
use ProfileHeatMap; 
use Storable;
use ChartUtil;

$| = 1;

my $env         = getEnv();
my $cgi_dir     = $env->{ cgi_dir }; 
my $cgi_url     = $env->{ cgi_url }; 
my $cgi_tmp_dir = $env->{ cgi_tmp_dir }; 
my $tmp_url     = $env->{ tmp_url };
my $tmp_dir     = $env->{ tmp_dir };
my $main_cgi    = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=IMGProteins";
my $verbose     = $env->{ verbose };
my $base_url    = $env->{ base_url };
my $cluster_bin = $env->{ cluster_bin }; 
my $R           = $env->{ r_bin }; 
my $nvl         = getNvl();

my $user_restricted_site  = $env->{ user_restricted_site };
my $color_array_file = $env->{ large_color_array_file };

my $batch_size = 60;
my $YUI = $env->{yui_dir_28};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    if ($page eq "proteomics" ||
	paramMatch("proteomics") ne "") {
        printOverview();
    }
    elsif ($page eq "sampledata") {
	printDataForSample();
    }
    elsif ($page eq "sample") {
	printProteinsForExperiment();
    }
    elsif ($page eq "peptides") {
	printPeptides();
    }
    elsif ($page eq "geneproteins") {
	printInfoForGene();
    }
    elsif ($page eq "genomestudies" ||
	   paramMatch("genomestudies") ne "") {
	printStudiesForGenome();
    }
    elsif ($page eq "genomeexperiments") {
	printExperiments();
    }
    elsif ($page eq "describeSamples" ||
	   paramMatch("describeSamples") ne "") {
	printDescribeSamples();
    }
    elsif ($page eq "compareSamples" ||
	   paramMatch("compareSamples") ne "") {
	printCompareSamples();
    }
    elsif ($page eq "describeClustered" ||
           paramMatch("describeClustered") ne "") {
        printDescribeSamples("describe_clustered");
    } 
    elsif ($page eq "clusterResults" ||
	   paramMatch("clusterResults") ne "") {
        printClusterResults(); 
    } 
    elsif ($page eq "clusterMapSort" || 
	   paramMatch("clusterMapSort") ne "") {
	printClusterMapSort();
    }
    elsif ($page eq "previewSamples" || 
           paramMatch("previewSamples") ne "") {
        printPreviewGraph();
    } 
    elsif ($page eq "samplePathways" || 
           paramMatch("samplePathways") ne "") { 
        printPathwaysForSample();
    } 
    elsif ($page eq "byFunction" ||
           paramMatch("byFunction") ne "") {
        printExpressionByFunction();
    } 
    elsif ($page eq "compareByFunction" ||
           paramMatch("compareByFunction") ne "") {
        printExpressionByFunction("pairwise");
    } 
    elsif ($page eq "geneGroup" || 
           paramMatch("geneGroup") ne "") {
        printGeneGroup(); 
    } 
}

############################################################################
# printOverview - prints all the proteomics experiments in IMG
############################################################################
sub printOverview {
    my $dbh = dbLogin(); 

    my $sql = qq{ 
        select distinct pig.gene, p.experiment 
        from ms_protein_img_genes pig, ms_protein p
        where pig.protein_oid = p.protein_oid
        and p.protein_oid > 0 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %geneCntHash; 
    for ( ;; ) { 
        my ($gene, $exp) = $cur->fetchrow(); 
        last if !$exp; 
        $geneCntHash{ $exp }++; 
    } 
    $cur->finish(); 

    my $imgClause = WebUtil::imgClause("tx"); 
    my $expClause = expClause("e"); 
    my $sql = qq{ 
        select distinct 
            e.exp_oid,
            e.exp_name, 
            e.protein_count,
            e.peptide_count,
            count(s.sample_oid) 
        from ms_experiment e, taxon tx, ms_sample s
	where e.exp_oid = s.experiment
	and s.IMG_taxon_oid = tx.taxon_oid
	and tx.is_public = 'Yes'
        $expClause
        $imgClause
        group by e.exp_oid, e.exp_name, e.protein_count, e.peptide_count
        order by e.exp_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 

    print "<h1>Protein Expression Studies</h1>\n"; 
    my $it = new InnerTable(1, "allstudies$$", "allstudies", 0);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Study ID", "asc", "right" );
    $it->addColSpec( "Study Name", "asc", "left" );
    $it->addColSpec( "Total<br/>Samples", "desc", "right" );
    $it->addColSpec( "Expressed<br/>Genes", "desc", "right" );
    $it->addColSpec( "Peptides<br/>Observed", "desc", "right" );

    for ( ;; ) { 
        my ($exp_oid, $experiment, 
	    $pcount, $ppcount, $num_samples) = $cur->fetchrow(); 
        last if !$exp_oid;

	my $url = "$section_cgi&page=genomeexperiments&exp_oid=$exp_oid";
        my $row; 
        $row .= $exp_oid."\t"; 
        $row .= $experiment.$sd.alink($url, $experiment)."\t";
	$row .= $num_samples."\t";
        $row .= $geneCntHash{$exp_oid}."\t"; 
        $row .= $ppcount."\t";
        $it->addRow($row); 
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    #$dbh->disconnect();
}

############################################################################
# printGeneCartFooter - prints the table buttons
############################################################################
sub printGeneCartFooter {
    my ( $name ) = @_;
    my $id0 = "";
    my $id1 = "";
    if ($name ne "") {
	$id0 = "id=$name"."0";
	$id1 = "id=$name"."1";
    }

    print hiddenVar( "from", "proteomics" );
    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit( -name  => $name,
                  -value => "Add Selections To Gene Cart",
                  -class => "meddefbutton" );
    print nbsp( 1 ); 
    print "<input $id1 " .
	"type='button' name='selectAll' value='Select All' " . 
        "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp( 1 );
    print "<input $id0 " .
	"type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
}

############################################################################ 
# printDataForSample - prints info for one sample of an experiment 
############################################################################ 
sub printDataForSample { 
    my $sample = param("sample"); 
    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1);
 
    my $sql = qq{ 
        select s.description, e.exp_oid,
               e.exp_name, e.project_name,
	       s.IMG_taxon_oid
        from ms_sample s, ms_experiment e 
        where s.sample_oid = ?
        and s.experiment = e.exp_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample ); 
    my ($sample_desc, $exp_oid, $exp_name, 
	$project_name, $taxon_oid) = $cur->fetchrow(); 
    $cur->finish(); 
 
    my $sql = qq{ 
        select round(sum(dt.coverage), 4) 
          from dt_img_gene_prot_pep_sample dt 
         where dt.sample_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample );
    my ($total) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{ 
        select distinct 
            dt.gene_oid, dt.gene_display_name,
	    g.locus_tag, g.product_name,
	    dt.gene_seq_length,
            count(dt.peptide_oid), 
            sum(dt.pep_spectral_cnt),
            round(sum(dt.coverage)/$total, 7)
        from dt_img_gene_prot_pep_sample dt, gene g
        where dt.sample_oid = ?
	and g.gene_oid = dt.gene_oid
        group by (dt.gene_oid, dt.gene_display_name, 
		  g.locus_tag, g.product_name, 
		  dt.gene_seq_length)
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample ); 
 
    print "<h1>Protein Expression Data for Sample</h1>\n";
    print "<p>$sample_desc</p>\n";

    my $url = "$main_cgi?section=TaxonDetail&page=scaffolds"
	. "&taxon_oid=$taxon_oid&study=$study&sample=$sample";
    print buttonUrl( $url, "Chromosome Viewer", "smbutton" );
    print "<br/>";

    print "<span style='font-size: 12px; "
	. "font-family: Arial, Helvetica, sans-serif;'>\n";
    my $url = "$section_cgi&page=genomeexperiments"
	. "&exp_oid=$exp_oid&taxon_oid=$taxon_oid"; 
    print alink($url, $exp_name)."\n"; 
    #print "<br/>[$project_name]\n";
    print "</span>\n";

    printMainForm(); 
    printGeneCartFooter();

    my $it = new InnerTable(1, "protsampledata$$", "protsampledata", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Product Name", "asc", "left" );
    $it->addColSpec( "AA Seq<br/>Length", "desc", "right" );
    $it->addColSpec( "Peptide<br/>Count", "desc", "right" );
    $it->addColSpec( "Total Observed<br/>Peptides<sup>1</sup>",
		     "desc", "right" ); 
    $it->addColSpec( "Normalized Coverage<br/>(NSAF)<sup>2</sup>", 
                     "desc", "right" ); 

    my $count;
    for ( ;; ) { 
        my ($gene, $gene_name, $locus_tag, $product,
	    $gene_seq_length, $pepCount, $specCount, $coverage)
            = $cur->fetchrow();
        last if !$gene;
 
        my $url1 = "$main_cgi?section=GeneDetail" 
                 . "&page=geneDetail&gene_oid=$gene"; 
        my $url2 = "$section_cgi&page=peptides&gene_oid=$gene&sample=$sample"; 
 
	my $row;
        my $row = $sd."<input type='checkbox' "
	        . "name='gene_oid' value='$gene'/>\t"; 
	$row .= $gene.$sd.alink($url1, $gene)."\t";
	$row .= $locus_tag."\t";
	$row .= $product."\t";
	$row .= $gene_seq_length."\t";
	$row .= $pepCount.$sd.alink($url2, $pepCount)."\t";
	$row .= $specCount."\t";
	$row .= sprintf("%.7f", $coverage)."\t";
        $it->addRow($row);      
	$count++;
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    #$dbh->disconnect(); 

    printGeneCartFooter();
    print end_form();
    printNotes("samplegenes");
    printStatusLine("$count Genes Loaded.", 2);
} 

############################################################################
# printNotes - print footnotes for tables
############################################################################
sub printNotes {
    my ( $which_page ) = @_;

    my $obsPep = "<u>Total Observed Peptides</u> is the sum of all " 
               . "spectral counts for each gene.\n"; 
    my $obsGenes = "Percent observed genes per sample is from total protein " 
	         . "coding genes for the genome."; 
    my $coverage = 
	"After each experiment, peptides are generated for each gene.<br/>"
	. nbsp(3)
	. "<u>Coverage</u> for a gene is defined as the count of " 
	. "these peptides divided by the size of the gene.\n";
    my $totalCoverage = 
	"<u>Total Coverage (SAF)</u> is the sum of coverages for all " 
	. "the genes in the given experiment.\n"; 

    my $nsaf = alink
	("http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1815300/?tool=pubmed",
	 "NSAF"); 
    my $normCoverage = 
	"<u>Normalized Coverage</u> (".$nsaf.") is the coverage for a gene " 
	. "in the given experiment divided by the total coverage <br/>"
	. nbsp(3)
	. "of all genes in that experiment.\n";

    print "<br/>";
    print "<b>Notes</b>:<br/>\n"; 
    print "<p>\n"; 
    if ($which_page eq "studysamples") {
	print "1 - ";
	print $coverage;
	print "<br/>\n"; 
	print nbsp(3);
	print $totalCoverage;
	print "<br/>\n"; 
	print "2 - "; 
	print $obsGenes;
    } elsif ($which_page eq "samplegenes") {	
	print "1 - "; 
	print $obsPep;
	print "<br/>\n"; 
	print "2 - "; 
	print $coverage;
	print "<br/>\n"; 
	print nbsp(3);
	print $normCoverage;
    }

    # User's Guide PDF file:
    #print "<br/>";
    #my $url = "$base_url/doc/releaseNotes.pdf#page=9";
    #print alink($url, "see User's Guide");

    print "</p>\n"; 
}

############################################################################
# printProteinsForExperiment - prints info for one sample of an experiment
############################################################################
sub printProteinsForExperiment { 
    my $sample = param("sample"); 
    my $dbh = dbLogin(); 
 
    my $sql = qq{ 
        select s.description,
               e.exp_name
        from ms_sample s, ms_experiment e
        where s.sample_oid = ?
        and s.experiment = e.exp_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample );
    my ($sample_desc, $exp_name) = $cur->fetchrow();
    $cur->finish(); 
 
    my $sql = qq{
        select distinct 
            pig.genome,
	    pig.gene,
	    g.gene_display_name,
	    g.locus_tag,
	    g.DNA_seq_length,
	    g.AA_seq_length,
	    tx.taxon_name,
	    tx.seq_status,
	    p.protein_oid,
            p.description 
        from ms_protein_img_genes pig, ms_protein p, taxon tx, gene g
        where p.sample = ?
        and pig.protein_oid = p.protein_oid 
        and pig.protein_oid > 0 
	and pig.genome = tx.taxon_oid
        and pig.genome is not NULL 
	and pig.gene = g.gene_oid
	order by p.protein_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample ); 
 
    print "<h1>Sample</h1>\n"; 
    print "<h2>$sample_desc [$exp_name]</h2>\n"; 
    print "<table class='img'>\n"; 
    print "<th class='img' >Protein ID</th>\n"; 
    print "<th class='img' >Protein Description</th>\n"; 
    print "<th class='img' >Gene</th>\n"; 
    print "<th class='img' >Genome</th>\n"; 

    for ( ;; ) { 
        my ($genome, $gene, $gene_name, $locus_tag, $dna_seq_length,
	    $aa_seq_length, $taxon_name, $seq_status, $poid, $desc)
	    = $cur->fetchrow(); 
        last if !$poid; 
 
        my $url1 = "$section_cgi&page=peptides&protein=$poid"; 
        my $url3 = "$main_cgi?section=TaxonDetail"
	          ."&page=taxonDetail&taxon_oid=$genome";

        my $url4 = "$main_cgi?section=GeneDetail" 
                 . "&page=geneDetail&gene_oid=$gene"; 
 
        print "<tr class='img' >\n"; 
        print "<td class='img' align='right' >$poid</td>\n"; 
        print "<td class='img' >$desc "
	    . alink($url1, "[see peptides]")."</td>\n";
        print "<td class='img' >$gene_name "
	    . alink($url4, $gene)
	    . " $locus_tag ".$dna_seq_length."bp ".$aa_seq_length."aa</td>\n";
        print "<td class='img' >$taxon_name "
	    . alink($url3, $genome)." [$seq_status]</td>\n";
        print "</tr>\n";
    }
    $cur->finish();
    print "</table>\n";
 
    #$dbh->disconnect();
}

############################################################################
# printPeptides - prints the amino acid sequence for a given gene 
#          where segments that correspond to peptides associated with 
#          this protein are colored in red
############################################################################
sub printPeptides {
    my $protein = param("protein");
    my $gene = param("gene_oid");
    my $sample = param("sample");
    my $dbh = dbLogin();

    my $sql;
    my @binds = ();
    if ($protein ne "") {
	$sql = "select description "
	     . "from ms_protein where protein_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $protein );
	my ($protein_desc) = $cur->fetchrow();
	$cur->finish(); 

	$sql = qq{
	    select distinct 
		pep.peptide_oid, 
		pep.peptide_seq
	    from ms_peptide pep, ms_protein p
	    where pep.protein = p.protein_oid
	    and p.protein_oid = ?
	    order by pep.peptide_oid
	};
	
	@binds = ($protein);
	print "<h1>Peptides for Protein ($protein)</h1>\n";
	print "<h2>$protein_desc</h2>\n";
    }
    elsif ($sample ne "") {
        $sql = "select description "
            . "from ms_sample where sample_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $sample );
        my ($sample_desc) = $cur->fetchrow();
        $cur->finish();

	$sql = qq{ 
	    select distinct 
		   pep.peptide_oid, 
		   pep.peptide_seq
	      from ms_peptide pep, ms_protein p, 
		   ms_protein_img_genes pig
	     where pep.protein = p.protein_oid
	       and p.sample = ?
	       and p.protein_oid = pig.protein_oid 
	       and pig.protein_oid > 0 
	       and pig.gene = ?
	  order by pep.peptide_oid 
	};

	@binds = ($sample, $gene);
        print "<h1>Peptides for Gene and Sample</h1>\n";
	my $url = "$section_cgi&page=sampledata&sample=$sample";
	print "<p/>";
	print "<span style='font-size: 12px; "
	     ."font-family: Arial, Helvetica, sans-serif;'>\n";
	print alink($url, $sample_desc)."\n";
	print "</span>\n";

    } else {
	return;
    }

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my @peptide_ids;
    my @peptide_seqs;
    for ( ;; ) { 
        my ($oid, $seq) = $cur->fetchrow();
        last if !$oid; 
        push @peptide_ids, $oid;
        push @peptide_seqs, $seq;
    } 
    $cur->finish(); 

    if ($gene ne "") {
	printGeneMainFaa($dbh, $gene, \@peptide_seqs, \@peptide_ids);
    }

    my $it = new InnerTable(1, "peptides$$", "peptides", 0);
    my $sd = $it->getSdDelim();
    my $it = new InnerTable(1, "allstudies$$", "allstudies", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Peptide ID", "asc", "right" );
    $it->addColSpec( "Peptide Seq", "asc", "left" );

    my $idx = 0;
    for my $oid (@peptide_ids) { 
        my $row; 
        $row .= $oid."\t"; 
        $row .= $peptide_seqs[$idx]."\t"; 
        $it->addRow($row);
	$idx++;
    } 
    $it->printOuterTable(1);
    #$dbh->disconnect();
}

############################################################################
# printInfoForGene - links gene page to proteomics data;
#        displays proteins mapped to the given gene and 
#        the experimental samples in which these were found
############################################################################
sub printInfoForGene { 
    my $gene = param("gene_oid"); 
    my $dbh = dbLogin(); 

    print "<h1>Proteomic Data for Gene</h1>\n"; 

    # print the protein sequence for this gene
    # with all associated peptides colored in red
    my $sql = qq{ 
        select distinct 
               pep.peptide_oid, 
               pep.peptide_seq 
          from ms_peptide pep, ms_protein p, 
               ms_protein_img_genes pig
         where pep.protein = p.protein_oid 
           and pig.protein_oid = p.protein_oid
           and p.protein_oid > 0
           and pig.gene = ?
         order by pep.peptide_oid 
     }; 
    my $cur = execSql( $dbh, $sql, $verbose, $gene ); 
  
    my @peptide_ids; 
    my @peptide_seqs; 
    for ( ;; ) { 
        my ($oid, $seq) = $cur->fetchrow(); 
        last if !$oid; 
        push @peptide_ids, $oid; 
        push @peptide_seqs, $seq; 
    } 
    $cur->finish(); 
 
    if ($gene ne "") { 
        printGeneMainFaa($dbh, $gene, \@peptide_seqs, \@peptide_ids); 
    } 

    my $sql = qq{ 
        select distinct pp.peptide_oid, p.sample
        from ms_protein_img_genes pig, ms_protein p,
             ms_peptide pp 
        where pig.gene = ?
        and pig.protein_oid = p.protein_oid 
        and p.protein_oid = pp.protein
        and p.protein_oid > 0 
      order by pig.gene 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $gene );
    my %peptideCntHash;
    for ( ;; ) { 
        my ($peptide, $sample) = $cur->fetchrow(); 
        last if !$sample; 
        $peptideCntHash{ $sample }++;
    } 
    $cur->finish(); 

    my $sql = qq{ 
        select 
            s.sample_oid,
            s.description,
	    e.exp_oid,
            e.exp_name
        from ms_protein_img_genes pig, ms_protein p, 
             ms_sample s, ms_experiment e
        where pig.gene = ?
        and p.sample = s.sample_oid 
        and pig.protein_oid = p.protein_oid 
        and p.protein_oid > 0 
        and p.experiment = e.exp_oid
        and s.sample_oid > 0
        order by s.sample_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $gene ); 
 
    my $it = new InnerTable(1, "protgenedata$$", "protgenedata", 0); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Sample ID", "asc", "right" );
    $it->addColSpec( "Description", "asc", "left" ); 
    $it->addColSpec( "Peptide Count", "desc", "right" ); 
    $it->addColSpec( "Study", "asc", "left" ); 

    for ( ;; ) { 
        my ($sample, $sample_desc,
	    $exp_oid, $exp_name) = $cur->fetchrow(); 
        last if !$sample; 

	my $url1 = "$section_cgi&page=peptides&gene_oid=$gene&sample=$sample";

        my $row;
        $row .= $sample."\t"; 
        $row .= $sample_desc."\t"; 
        $row .= $peptideCntHash{$sample}.$sd
	    .alink($url1, $peptideCntHash{$sample})."\t";
        $row .= $exp_name."\t"; 
        $it->addRow($row); 
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    #$dbh->disconnect(); 
} 

############################################################################ 
# printStudiesForGenome - prints all studies that use a given genome
############################################################################ 
sub printStudiesForGenome { 
    my $taxon_oid = param("taxon_oid");
    my $dbh = dbLogin(); 

    my $sql = qq{ 
        select taxon_name 
        from taxon
        where taxon_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    my ($taxon_name) = $cur->fetchrow(); 
    $cur->finish(); 
 
    my $sql = qq{
	select sum( cds_genes )
        from taxon_stats dts
	where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    my ($cds_genes) = $cur->fetchrow(); 
    $cur->finish(); 

    my $sql = qq{ 
        select distinct pig.gene, p.experiment
        from ms_protein_img_genes pig, ms_protein p
        where pig.protein_oid = p.protein_oid 
        and p.protein_oid > 0 
	and pig.genome = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    my %geneCntHash;
    for ( ;; ) { 
        my ($gene, $exp) = $cur->fetchrow();
        last if !$exp;
        $geneCntHash{ $exp }++; 
    } 
    $cur->finish(); 

    my $sql = qq{ 
        select distinct 
            e.exp_oid, 
            e.exp_name, 
            e.protein_count, 
            e.peptide_count,
            count(s.sample_oid)
        from ms_experiment e, ms_sample s, taxon tx 
        where e.exp_oid = s.experiment 
        and s.IMG_taxon_oid = tx.taxon_oid 
        and tx.is_public = 'Yes' 
        and tx.taxon_oid = ?
        group by e.exp_oid, e.exp_name, e.protein_count, e.peptide_count
        order by e.exp_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
 
    my $url = "$main_cgi?section=TaxonDetail"
	."&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<h1>Protein Expression Studies</h1>\n"; 
    print "<p>".alink($url, $taxon_name)."</p>\n"; 
    #print "<p>Protein Coding Genes: $cds_genes</p>";
    print "<p/>";

    my $it = new InnerTable(1, "protstudies$$", "protstudies", 0);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Study ID", "asc", "right" ); 
    $it->addColSpec( "Study Name", "asc", "left" );
    $it->addColSpec( "Total<br/>Samples", "desc", "right" );
    $it->addColSpec( "Protein Coding<br/>Genes", "", "right" );
    $it->addColSpec( "Expressed<br/>Genes", "desc", "right" );
    $it->addColSpec( "Peptides<br/>Observed", "desc", "right" );

    for ( ;; ) { 
        my ($exp_oid, $experiment, 
            $pcount, $ppcount, $num_samples) = $cur->fetchrow(); 
        last if !$exp_oid; 
 
        my $url = "$section_cgi&page=genomeexperiments"
	        . "&exp_oid=$exp_oid"
	        . "&taxon_oid=$taxon_oid"; 

        my $row;
        $row .= $exp_oid."\t"; 
        $row .= $experiment.$sd.alink($url, $experiment)."\t"; 
	$row .= $num_samples."\t";
        $row .= $cds_genes."\t"; 
        $row .= $geneCntHash{$exp_oid}."\t"; 
        $row .= $ppcount."\t"; 
        $it->addRow($row); 
    } 
    $cur->finish(); 
    $it->printOuterTable(1);
    #$dbh->disconnect(); 
} 

############################################################################
# printSelectOneSample - prints a table of all samples for the genome
#        where the entries are exclusively selectable (radiobuttons)
############################################################################
sub printSelectOneSample {
    my ($taxon_oid) = @_;
    if ($taxon_oid eq "") {
	$taxon_oid = param("taxon_oid"); 
    }

    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1); 

    my $sql = qq{ 
        select dt.taxon, dt.exp_oid, dt.sample_oid, dt.sample_desc,
	       count(distinct dt.gene_oid),
	       count(distinct dt.peptide_oid), 
	       round(sum(dt.coverage), 2), 
	       round(avg(dt.coverage), 5)
	  from dt_img_gene_prot_pep_sample dt 
         where dt.taxon = ? 
	   and dt.sample_oid > 0 
      group by dt.taxon, dt.exp_oid, dt.sample_oid, dt.sample_desc
      order by dt.taxon, dt.exp_oid, dt.sample_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable(1, "protexps$$", "protexps", 1); 
    $it->{pageSize} = 10;
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Choose" );
    $it->addColSpec( "Sample ID", "asc", "right" );
    $it->addColSpec( "Sample Name","asc", "left" );
    $it->addColSpec( "Experiment ID", "asc", "right" );
    $it->addColSpec( "Gene Count", "desc", "right" );
    $it->addColSpec( "Peptide Count", "desc", "right" );
    $it->addColSpec( "Total Coverage<sup>1</sup>", "desc", "right" ); 
    $it->addColSpec( "Average Coverage", "desc", "right" ); 

    my $count; 
    for ( ;; ) { 
        my ($taxon, $expid, $sample, $desc, $geneCount, $peptideCount, 
            $coverage, $avg) = $cur->fetchrow(); 
        last if !$sample; 

        my $url = "$section_cgi&page=sampledata&sample=$sample"; 

        my $row; 
        my $row = $sd."<input type='radio' "
                . "onclick='setStudy(\"$study\")' "
		. "name='exp_samples' value='$sample'/>\t";
        $row .= $sample."\t"; 
        $row .= $desc.$sd.alink($url, $desc)."\t";
        $row .= $expid."\t"; 
        $row .= $geneCount."\t"; 
        $row .= $peptideCount."\t"; 
        $row .= $coverage."\t"; 
        $row .= $avg."\t";
        $it->addRow($row);
        $count++; 
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    #$dbh->disconnect();
}

############################################################################
# printExperiments - prints all experiments for the genome
############################################################################
sub printExperiments { 
    my $taxon_oid = param("taxon_oid"); 
    my $exp_oid = param("exp_oid");
    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1);
 
    my $expClause = expClause("e");
    my $sql = qq{ 
        select e.exp_name, e.project_name, 
               e.description, e.exp_contact, 
               eel.custom_url, e.ext_accession 
        from ms_experiment e
	left outer join ms_experiment_ext_links eel 
	on e.exp_oid = eel.exp_oid
        where e.exp_oid = ?
	$expClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
    my ($exp_name, $project_name, 
	$exp_desc, $exp_contact, $curl, $accession) = $cur->fetchrow();
    $cur->finish(); 

    if ($exp_name eq "") { 
	printStatusLine( "unauthorized user", 2 );
        printMessage( "You do not have permission to view this experiment." );
        return; 
    } 
 
    my $sql = qq{
	select publications
	from ms_experiment_publications
	where exp_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
    my ($publications) = $cur->fetchrow();
    $cur->finish();

    # get the study description: 
    my $text = "<b>$exp_name</b><br/><b>Synopsis: </b>$exp_desc" 
        . "<br/><b>Publication: </b>$publications<br/><br/>" 
        . "<b>Contacts: </b>"; 
    if ($curl ne "") { 
        $text .= "<a href=$curl target=_blank>$curl</a>";
    } 
    #$text .= "<br/>$exp_contact"; 

    WebUtil::printHeaderWithInfo 
        ("Protein Expression Study", $text, "show description for this study",
         "Study Description", 0, "Proteomics.pdf");
 
    my $taxon_name;
    if ($taxon_oid eq "") {
	my $sql = qq{
            select distinct s.IMG_taxon_oid
            from ms_sample s
            where s.experiment = ?
        };
	my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
	my @alltx;
	for ( ;; ) {
	    my ($taxon) = $cur->fetchrow();
	    last if !$taxon;
	    push (@alltx, $taxon);
	}
	if (scalar @alltx == 1) {
	    $taxon_oid = $alltx[0];
	}
    }

    if ($taxon_oid ne "") {
	my $sql = qq{ 
	    select taxon_name
	      from taxon
	     where taxon_oid = ?
	}; 
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
	($taxon_name) = $cur->fetchrow(); 
	$cur->finish(); 

        my $url = "$main_cgi?section=TaxonDetail"
            ."&page=taxonDetail&taxon_oid=$taxon_oid";
	print "<p>".alink($url, $taxon_name, "_blank"); 
	print "<br/><u>Study</u>: $exp_name</p>\n";
    }

    setLinkTarget("_blank"); 
    printMainForm();

    use TabHTML; 
    TabHTML::printTabAPILinks("experimentsTab", 1); 
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("experimentsTab");
        </script>
    }; 

    my @tabIndex = ( "#exptab1", "#exptab2", 
                     "#exptab4", "#exptab4" ); 
    my @tabNames = ( "Select Samples", 
                     "Single Sample Analysis", 
                     "Pairwise Sample Analysis", 
                     "Multiple Sample Analysis" ); 
    TabHTML::printTabDiv("experimentsTab", \@tabIndex, \@tabNames); 
 
    print "<div id='exptab1'>"; 

    # get the protein coding genes for taxon for experiment
    my $sql = qq{
        select distinct dt.taxon
	from dt_img_gene_prot_pep_sample dt
	where dt.exp_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid ); 
    my %taxon2cds;
    for ( ;; ) { 
        my ($taxon) = $cur->fetchrow();
        last if !$taxon; 
        $taxon2cds{ $taxon } = 0;
    }
    $cur->finish();

    foreach my $taxon0 (keys( %taxon2cds )) {
	my $sql = qq{ 
	    select count(distinct g.gene_oid)
	    from gene g 
	    where g.taxon = ?
	    and g.locus_type = 'CDS' 
	    and g.obsolete_flag = 'No'
	}; 
	my $cur = execSql( $dbh, $sql, $verbose, $taxon0 );
	for ( ;; ) { 
	    my ($cds) = $cur->fetchrow(); 
	    last if !$cds; 
	    $taxon2cds{ $taxon0 } = $cds; 
	}
	$cur->finish(); 
    }

    my $sql = qq{
	select dt.taxon, dt.sample_oid, dt.sample_desc,
	       count(distinct dt.gene_oid),
	       count(distinct dt.peptide_oid),
	       round(sum(dt.coverage), 2),
	       round(avg(dt.coverage), 5)
	  from dt_img_gene_prot_pep_sample dt
	 where dt.exp_oid = ?
	   and dt.sample_oid > 0
      group by dt.taxon, dt.sample_oid, dt.sample_desc
      order by dt.taxon, dt.sample_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );  

    my $it = new InnerTable(1, "protexps$$", "protexps", 1);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Sample ID", "asc", "right" );
    $it->addColSpec( "Sample Name","asc", "left" );
    $it->addColSpec( "Gene<br/>Count", "desc", "right" );
    $it->addColSpec( "Peptide<br/>Count", "desc", "right" );
    $it->addColSpec( "Total<sup>1</sup><br/>Coverage", "desc", "right" );
    $it->addColSpec( "Average<br/>Coverage", "desc", "right" );
    $it->addColSpec( "Percent<sup>2</sup><br/>Observed Genes", "desc", "right" );

    my $count;
    for ( ;; ) { 
	my ($taxon, $sample, $desc, $geneCount, $peptideCount,
	    $coverage, $avg) = $cur->fetchrow();
        last if !$sample; 
 
	my $url = "$section_cgi&page=sampledata&sample=$sample";
	my $cds_genes = $taxon2cds{ $taxon };
	my $observed = "";
	if ($cds_genes ne 0) {
	    $observed = sprintf("%.2f%%", ($geneCount/$cds_genes)*100);
	}
	my $row;
        my $row = $sd."<input type='checkbox' "
	        . "name='exp_samples' value='$sample' />\t"; 
        $row .= $sample."\t";
        #$row .= $desc.$sd.alink($url, $desc)."\t"; 
	$row .= $desc.$sd
	    ."<a href='$url' id='link$sample'>".escHtml($desc)."</a>"."\t";

	$row .= $geneCount."\t";
	$row .= $peptideCount."\t";
	$row .= $coverage."\t";
	$row .= $avg."\t";
	$row .= $observed."\t";
        $it->addRow($row); 
	$count++;
    } 
    $cur->finish(); 

    if ($count > 10) {
	print "<input type=button name='selectAll' value='Select All' "
	    . "onClick='selectAllByName(\"exp_samples\", 1)' "
	    . "class='smbutton' />\n"; 
	print nbsp( 1 ); 
	print "<input type='button' name='clearAll' value='Clear All' " 
	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 
    }
    $it->printOuterTable("nopage");
    print "<input type=button name='selectAll' value='Select All' "
	. "onClick='selectAllByName(\"exp_samples\", 1)' "
	. "class='smbutton' />\n";
    print nbsp( 1 ); 
    print "<input type='button' name='clearAll' value='Clear All' "
        . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    #$dbh->disconnect(); 
    printNotes("studysamples");
    print "</div>"; # end exptab1
 
    print "<div id='exptab2'>";
    print "<h2>Describe Sample</h2>"; 
    print "<p>You may select a sample to view its gene expression and the "
        . "associated functions.<br/>"; 
    print "Choose <font color='blue'><u>Pathways</font></u> to see a list of "
	. "pathways in which genes from this sample are found to participate.";
    print "<br/>Choose <font color='blue'><u>Chromosome Viewer</font></u> "
        . "to view the chromosome colored by expression values for the "
        . "selected sample.";
    print "</p>\n";

    use GeneCartStor;
    my $gc = new GeneCartStor(); 
    my $recs = $gc->readCartFile(); # get records
    my @cart_keys = keys(%$recs);
 
    print qq{ 
        <script language='JavaScript' type='text/javascript'> 
        function checkIt(item) { 
            var checked = document.getElementById(item).checked; 
            if (checked == true) { 
              document.mainForm.describe_cart_genes_1.checked = true; 
              document.mainForm.describe_cart_genes.checked = true; 
              document.mainForm.cluster_cart_genes.checked = true; 
            } else { 
              document.mainForm.describe_cart_genes_1.checked = false; 
              document.mainForm.describe_cart_genes.checked = false; 
              document.mainForm.cluster_cart_genes.checked = false; 
            } 
        } 

        function validateSampleSelection(num, ismin) {
            var startElement = document.getElementById("protexps");
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var e = els[i];

                if (e.type == "checkbox" &&
                    e.name == "exp_samples" &&
                    e.checked == true) {
                    count++;
                }
            }

            if (count < num) {
                var txt = "";
                if (ismin == 1) {
                    txt = " at least";
                }
                if (num == 1) {
                    alert("Please select"+txt+" 1 sample");
                } else {
                    alert("Please select"+txt+" "+num+" samples");
                }
                return false;
            }

            return true;
        }
        </script> 
    }; 
 
    print "<p>\n"; 
    print "<input type='checkbox' name='describe_cart_genes_1' "
        . "id='describe_cart_genes_1' "
        . "onclick='checkIt(\"describe_cart_genes_1\")' />\n"; 
    print "Use only genes from gene cart ";
    print "</p>\n";
 
    print hiddenVar( "section",   $section ); 
    print hiddenVar( "study",     $study );
    print hiddenVar( "exp_oid",   $exp_oid );
    print hiddenVar( "exp_name",  $exp_name );
    print hiddenVar( "taxon_oid", $taxon_oid );

    print hiddenVar( "taxon_oid", $taxon_oid ); 
    my $name = "_section_${section}_describeSamples"; 
    print submit( -name    => $name, 
                  -value   => "Gene Expression Summary", 
                  -class   => "smdefbutton", 
                  -onclick => "return validateSampleSelection(1);" );
    print nbsp(1); 
    my $name = "_section_${section}_samplePathways";
    print submit( -name    => $name, 
                  -value   => "Pathways", 
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1);" );
    print nbsp(1);  
    my $name = "_section_TaxonDetail_scaffolds";
    print submit( -name    => $name,
                  -value   => "Chromosome Viewer",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1);" );

    print "</div>"; # end exptab2
 
    print "<div id='exptab3'>"; 
    print "<h2>Find Up/Down Regulated Genes</h2>"; 
 
    print "<p>\n";
    print "You may select 2 samples to identify genes " 
        . "that are up or down regulated.<br/>\n"
        . "Choose <font color='blue'><u>Compare by Function</u></font> "
        . "to see whether genes participating in a given <br/>function "
        . "have been up- or down- regulated between the 2 samples "
        . "as a group. "; 
    print "</p>\n"; 

    print "<p>\n";
    print "<b>Reference</b>:<br/>\n";
    print "<input type='radio' name='reference' id='reference1' "
	. "value='1' checked />";
    print "<label id='ref1' for='reference1'> "
	. "Use 1 as reference</label><br/>\n";
    print "<input type='radio' name='reference' id='reference2' "
	. "value='2' />";
    print "<label id='ref2' for='reference2'> "
	. "Use 2 as reference</label><br/>\n";
    print "</p>\n";

    print qq{
        <script language="JavaScript" type="text/javascript">
	function setReference() { 
	    var ref1 = "Use 1 as reference";
	    var ref2 = "Use 2 as reference";
	    var checks = 0;
	    for (var i=0; i<document.mainForm.elements.length; i++) {
		var el = document.mainForm.elements[i]; 
		if (el.type == "checkbox" && el.checked) {
		    var value = el.value;
		    var ref = document.getElementById('link'+value).innerHTML;
		    if (checks == 0) ref1 = ref;
		    if (checks == 1) ref2 = ref;
		    checks++;
		}
		if (checks > 1) break;
	    }
	    document.getElementById('ref1').innerHTML=ref1;
	    document.getElementById('ref2').innerHTML=ref2;
	} 
        </script> 
    };
    
    print "<p>\n";
    print "<b>Metric</b>:<br/>\n";
        print "<input type='radio' name='metric' "
            . "value='logR' checked />"
	    . "logR=log2(query / reference)"
	    . "<br/>\n";
        print "<input type='radio' name='metric' "
            . "value='RelDiff' />"
	    . "RelDiff=2(query - reference)/(query + reference)"
	    . "<br/>\n";
    print "</p>\n";

    print "<p>\n"; 
    print "<b>Threshold</b>: "; 
    print "<input type='text' name='threshold' " 
        . "size='1' maxLength=10 value='1' />\n"; 
    print "(default=1)"; 
    print "</p>\n"; 

    print hiddenVar( "section",   $section );
    print hiddenVar( "exp_oid",   $exp_oid ); 
    print hiddenVar( "taxon_oid", $taxon_oid );

    ######### for preview graph
    print "<script src='$base_url/imgCharts.js'></script>\n";
    print qq{ 
        <link rel="stylesheet" type="text/css" 
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    print qq{
        <script language='JavaScript' type='text/javascript'>
	function initPanel() { 
	    if (!YAHOO.example.container.panel1) {
                YAHOO.example.container.panel1 = new YAHOO.widget.Panel 
                    ("panel1", { 
                      visible:false, 
                      //fixedcenter:true, 
                      dragOnly:true, 
                      underlay:"none",
                      zindex:"10", 
                      context:['anchor1','bl','tr']
		      } );
                YAHOO.example.container.panel1.render();
                //alert("initPanel");
            }
	} 

        function getURL(url) {
            var startElement = document.getElementById("protexps");
            var els = startElement.getElementsByTagName('input');
            var ref = 1;
            var sampleA = "";
            var sampleB = "";

            for (var i = 0; i < els.length; i++) {
                var e = els[i];
 
                if (e.type == "checkbox" && 
                    e.name == "exp_samples" && 
                    e.checked == true) { 
		    if (sampleA == null || sampleA.length == 0) {
			sampleA = e.value;
		    } else {
			sampleB = e.value; 
                        break;
		    } 
		}
	    }

            var els2 = document.getElementsByName('reference');
            for (var i = 0; i < els2.length; i++) {
                var e = els2[i];
		if (e.type == "radio" && 
		    e.name == "reference" &&
		    e.checked == true) { 
		    ref = e.value;
		} 
	    }
	    if (ref == 2) {
		return url+"&sample1="+sampleB+"&sample2="+sampleA; 
	    }
	    return url+"&sample1="+sampleA+"&sample2="+sampleB; 
	}
        </script> 
    };

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{ 
        <script type='text/javascript'>
	YAHOO.namespace("example.container");
        //YAHOO.util.Event.addListener(window, "load", initPanel());
	YAHOO.util.Event.on("anchor1", "click", initPanel());
        </script>
	};
    print "</div>\n";
    ######### end preview div

    my $url = "xml.cgi?section=IMGProteins&page=previewSamples";
    $url .= "&taxon_oid=$taxon_oid";

    print "<input type='BUTTON' id='anchor1' value='Preview' class='smbutton' "
	. "onclick=javascript:showImage(getURL('$url')) />";

    print nbsp(1); 
    my $name = "_section_${section}_compareSamples";
    print submit( -name    => $name,
                  -value   => "Compare",
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(2);" );
    print nbsp(1);
    my $name = "_section_${section}_compareByFunction"; 
    print submit( -name    => $name, 
                  -value   => "Compare by Function", 
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(2);" );

    print "</div>"; # end exptab3
 
    print "<div id='exptab4'>"; 
    print "<h2>Describe Samples</h2>"; 
 
    print "<p>\n";
    print "You may select samples to compare and describe. If you choose "
        . "to first cluster the samples<br/> to have the results colored "
        . "by the cluster grouping, go to <font color='blue'><u>"
        . "Map Clusters to Pathways</u></font> below.<br/>"
        . "Choose <font color='blue'><u>Expression by Function</u></font> "
        . "to see, for each selected sample, the average expression<br/>"
        . "of genes participating in a given function as a group.";
    print "</p>\n"; 

    my $gc = new GeneCartStor();
    my $recs = $gc->readCartFile(); # get records
    my @cart_keys = keys(%$recs); 
 
    print "<p>\n";
    print "<input type='checkbox' name='describe_cart_genes' "
        . "id='describe_cart_genes' " 
        . "onclick='checkIt(\"describe_cart_genes\")' />\n"; 
    print "Use only genes from gene cart ";
    print "</p>\n";
 
    print hiddenVar( "section",   $section );
    print hiddenVar( "exp_oid",   $exp_oid );
    print hiddenVar( "exp_name",  $exp_name ); 
    print hiddenVar( "taxon_oid", $taxon_oid );
    my $name = "_section_${section}_describeSamples";
    print submit( -name    => $name, 
                  -value   => "Gene Expression Summary", 
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(1,1);" );
    print nbsp(1); 
    my $name = "_section_${section}_byFunction"; 
    print submit( -name    => $name, 
                  -value   => "Expression by Function", 
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1,1);" );
 
    print "<h2>Cluster Samples</h2>"; 
    print "<p>\n"; 
    print "You may select samples and cluster them based on the ";
    print "coverage of the expressed genes.<br/>\n";
    print "Proximity of grouping indicates the relative degree ";
    print "of similarity of samples to each other.<br/>\n";
    print "</p>\n"; 
 
    print "<p>\n";
    print "<b>Clustering Method</b>:<br/>\n"; 
    print "<input type='radio' name='method' "
	. "value='m' checked />Pairwise complete-linkage (default)<br/>\n";
    print "<input type='radio' name='method' "
	. "value='s' />Pairwise single-linkage<br/>\n"; 
    #print "<input type='radio' name='method' "
    #	. "value='c' />Pairwise centroid-linkage<br/>\n"; 
    print "<input type='radio' name='method' "
	. "value='a' />Pairwise average-linkage<br/>\n"; 
    print "</p>\n"; 
    
    print "<p>\n"; 
    print "<b>Distance Measure</b>:<br/>\n";
    #print "<input type='radio' name='correlation' "
    #	. "value='0' />No gene clustering<br/>\n";
    #print "<input type='radio' name='correlation' "
    #	. "value='1' />Uncentered correlation<br/>\n";
    print "<input type='radio' name='correlation' "
	. "value='2' checked />Pearson correlation (default)<br/>\n";
    #print "<input type='radio' name='correlation' "
    #	. "value='3' />Uncentered correlation, absolute value<br/>\n";
    #print "<input type='radio' name='correlation' "
    #	. "value='4' />Pearson correlation, absolute value<br/>\n";
    print "<input type='radio' name='correlation' "
	. "value='5' />Spearman's rank correlation<br/>\n";
    #print "<input type='radio' name='correlation' "
    #	. "value='6' />Kendall's tau<br/>\n";
    print "<input type='radio' name='correlation' "
	. "value='7' />Euclidean distance<br/>\n";
    print "<input type='radio' name='correlation' "
	. "value='8' />City-block distance (Manhattan)<br/>\n";
    print "</p>\n"; 

    my $max_length = length($count);
    print "<p>\n";
    print "<b>Minimum number of samples in which a gene should "
	. "appear in order to be included</b>: ";
    print "<input type='text' name='min_num' "
	. "size='1' maxLength=$max_length value='3' />\n";
    print "(default=3)";
    print "</p>\n";

    print "<p>\n";
    print "Cut-off threshold (for cluster groupings): "
        . "<input type='text' name='cluster_threshold' "
        . "size='1' maxLength='10' value='0.8' />\n";
    print "(default=0.8)"; 
    print "</p>\n"; 

    #if (scalar @cart_keys > 0) {
	print "<p>\n"; 
        print "<input type='checkbox' name='cluster_cart_genes' "
            . "id='cluster_cart_genes' "
            . "onclick='checkIt(\"cluster_cart_genes\")' />\n";
	print "Use only genes from gene cart "; 
	print "</p>\n"; 
    #}

    print hiddenVar( "section", $section ); 
    print hiddenVar( "exp_oid", $exp_oid );
    
    my $name = "_section_${section}_clusterResults"; 
    print submit( -name    => $name, 
		  -value   => "Cluster", 
		  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(3,1);" );
    print nbsp(1); 
    my $name = "_section_${section}_describeClustered"; 
    print submit( -name    => $name, 
                  -value   => "Map Clusters to Pathways", 
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(3,1);" );

    print "</div>\n"; # end exptab4

    TabHTML::printTabDivEnd(); 

    print qq{
        <script type='text/javascript'>
        tabview1.addListener
            ("activeIndexChange", function(e) {
            if (e.newValue == 2) {
                setReference();
            }
        });
        </script>
    }; 

    print end_form();
    printStatusLine("$count Sample(s) Loaded.", 2);
} 

############################################################################
# printPreviewGraph - compares 2 selected samples to identify genes
#                     that are up or down regulated 
############################################################################
sub printPreviewGraph { 
    my $taxon_oid = param("taxon_oid");
    my $sample1 = param("sample1");
    my $sample2 = param("sample2");
    #webLog "PREVIEW: $sample1 $sample2 $taxon_oid";

    if ($sample1 eq "" || $sample2 eq "") { 
        my $header = "Preview";
        my $body = "Please select 2 samples.";
	my $script = "$base_url/overlib.js";
 
        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq { 
            <response>
                <header>$header</header>
                <text>$body</text>
		<script>$script</script>
            </response>
        };
        return;
    } 
 
    my $sample_oid_str = $sample1.",".$sample2;
    my @sample_oids = ($sample1, $sample2);
    my $dbh = dbLogin(); 

    ## Template 
    my $sql = qq{
        select distinct dt.gene_oid
        from dt_img_gene_prot_pep_sample dt
        where dt.sample_oid in ($sample_oid_str)
        order by dt.gene_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %template;
    for( ;; ) { 
        my( $gid ) = $cur->fetchrow();
        last if !$gid; 
        $template{ $gid } = 0;
    } 
    $cur->finish();
    my @geneIds = sort( keys( %template ) );

    my %sampleProfiles; 
    my %geneInfo; 

    my $sql = qq{ 
        select distinct g.gene_oid, g.locus_tag, 
        g.gene_display_name, round(sum(dt.coverage), 7) 
        from dt_img_gene_prot_pep_sample dt, gene g 
        where dt.sample_oid = ? 
        and dt.gene_oid = g.gene_oid 
        group by (g.gene_oid, g.locus_tag, g.gene_display_name)
    };
    foreach my $sample_oid( @sample_oids ) { 
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
        my %profile = %template; 
        for ( ;; ) { 
            my ( $gid, $locus_tag, $name, $coverage ) 
                = $cur->fetchrow();
            last if !$gid; 
            $profile{ $gid } = $coverage;
            $geneInfo{ $gid } = $locus_tag."\t".$name;
        } 
        $cur->finish();
        $sampleProfiles{ $sample_oid } = \%profile;
    } 
 
    #$dbh->disconnect(); 

    my @logR_data;
    my @relDiff_data;
    foreach my $gene( @geneIds ) { 
        my $profile1 = $sampleProfiles{ $sample1 }; 
	my $profile2 = $sampleProfiles{ $sample2 }; 
	my $coverage1 = $profile1->{ $gene }; # ref coverage 
	my $coverage2 = $profile2->{ $gene }; 
	if ($coverage1 eq "0" || $coverage2 eq "0") { 
	    next; 
	} 
	
	$coverage1 = sprintf("%.7f", $coverage1); 
	$coverage2 = sprintf("%.7f", $coverage2); 
 
	# logR
        if (abs($coverage1) == $coverage1 && 
            abs($coverage2) == $coverage2 &&
            abs($coverage1) > 0 && 
            abs($coverage2) > 0) { 
	    my $delta1 = log($coverage2/$coverage1)/log(2); 
	    $delta1 = sprintf("%.5f", $delta1);
	    push @logR_data, $delta1;
	}

	# RelDiff
	my $delta2 = 2*($coverage2 - $coverage1)/($coverage2 + $coverage1);
	$delta2 = sprintf("%.5f", $delta2);
	push @relDiff_data, $delta2;
    } 

    # CHART for distribution #################### 
    my $chart = ChartUtil::newHistogramChart(); 
    $chart->WIDTH(400); 
    $chart->HEIGHT(300); 
    $chart->INCLUDE_TOOLTIPS("yes"); 
    $chart->INCLUDE_LEGEND("yes"); 
    $chart->DOMAIN_AXIS_LABEL("Metric");
    $chart->RANGE_AXIS_LABEL("Gene Count");
    
    my @chartseries; 
    push @chartseries, "logR"; 
    push @chartseries, "RelDiff";
    $chart->SERIES_NAME(\@chartseries); 
    my $datastr1 = join(",", @logR_data); 
    my $datastr2 = join(",", @relDiff_data); 
    my @datas = ($datastr1, $datastr2); 
    $chart->DATA(\@datas); 
    
    my $name = "Difference in expression between 2 samples";
    my $st = -1; 
    if ($env->{ chart_exe } ne "") { 
        $st = ChartUtil::generateChart($chart); 
    }    
    if ($env->{ chart_exe } ne "") { 
	if ($st == 0) {
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png"; 
            my $imagemap = "#".$chart->FILE_PREFIX;
            my $script = "$base_url/overlib.js";
	    my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq { 
                <response> 
                    <header>$name</header> 
                    <script>$script</script> 
                    <maptext><![CDATA[
            };
 
            my $FH = newReadFileHandle
                ($chart->FILEPATH_PREFIX.".html", "proteomics-histogram", 1);
            while (my $s = $FH->getline()) {
                print $s;
            } 
            close ($FH);
 
            print qq { 
                    ]]></maptext> 
 		    <text>Reference: $sample1 Query: $sample2<br/>\n</text>
                    <url>$url</url>
                    <imagemap>$imagemap</imagemap>
                    <width>$width</width> 
                    <height>$height</height> 
                </response> 
            }; 
	}
    } 
    # END CHART ##################################
}

############################################################################
# printCompareSamples - compares 2 selected samples to identify genes
#                     that are up or down regulated
############################################################################
sub printCompareSamples { 
    my @sample_oids = param("exp_samples"); 
    my $nSamples = @sample_oids; 
    my $exp_oid = param("exp_oid"); 
    my $exp_name = param("exp_name"); 
    my $taxon_oid = param("taxon_oid"); 
    if ($nSamples < 2) { 
        webError( "Please select 2 samples." );
    } 
 
    my $reference = param( "reference" );
    my $threshold = param( "threshold" );
    my $metric = param( "metric" );

    my $sample1 = @sample_oids[0];
    my $sample2 = @sample_oids[1];
    if ( $reference eq "2" ) {
	$sample1 = @sample_oids[1];
	$sample2 = @sample_oids[0];
    }
    my $sample_oid_str = $sample1.",".$sample2;
    @sample_oids = ($sample1, $sample2);
    printStatusLine("Loading ...", 1);

    my $dbh = dbLogin(); 

    print "<h1>Up/Down Regulation</h1>\n";
    my $url = "$section_cgi&page=genomeexperiments"
	    . "&exp_oid=$exp_oid&taxon_oid=$taxon_oid"; 
    print "<span style='font-size: 12px; " 
	. "font-family: Arial, Helvetica, sans-serif;'>\n"; 
    print alink($url, $exp_name)."\n"; 
    print "</span>\n"; 

    ### sample names 
    my %sampleNames;
    my $sql = qq{ 
        select distinct s.sample_oid, s.description
        from ms_sample s
        where s.sample_oid in ($sample_oid_str) 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) { 
        my( $sid, $sname ) = $cur->fetchrow(); 
        last if !$sid; 
        $sampleNames{ $sid } = $sname; 
    } 
    $cur->finish(); 

    my $url = "$section_cgi&page=sampledata&sample=";
    print "<p>\n"; 
    print "Reference sample: ".alink($url.$sample1, $sampleNames{$sample1});
    print "<br/>";
    print "Query sample: ".alink($url.$sample2, $sampleNames{$sample2});
    print "</p>\n";

    printHint 
      ("Click on a tab to select up- or down- regulated genes ".
       "to add to gene cart<br/>".
       "Difference in expression levels is computed using the <u>".
       $metric."</u> metric<br/>".
       "Expression levels differ by a <u>threshold</u>: ".$threshold );

    if ($taxon_oid ne "") {
	### genome name
	my $sql = qq{ 
	    select taxon_name 
            from taxon
            where taxon_oid = ? 
	}; 
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my ($taxon_name) = $cur->fetchrow(); 
	$cur->finish(); 
	
	my $url = "$main_cgi?section=TaxonDetail"
	    ."&page=taxonDetail&taxon_oid=$taxon_oid";
	print "<p>".alink($url, $taxon_name)."</br></p>\n";
    } else {
	print "<br/>";
    }

    ## Template 
    my $sql = qq{ 
        select distinct dt.gene_oid 
        from dt_img_gene_prot_pep_sample dt 
        where dt.sample_oid in ($sample_oid_str) 
        order by dt.gene_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %template; 
    for( ;; ) { 
        my( $gid ) = $cur->fetchrow(); 
        last if !$gid;
        $template{ $gid } = 0; 
    } 
    $cur->finish(); 
    my @geneIds = sort( keys( %template ) );
 
    my %sampleProfiles; 
    my %geneInfo; 

    my $sql = qq{ 
        select distinct g.gene_oid, g.locus_tag,
        g.gene_display_name, round(sum(dt.coverage), 7)
        from dt_img_gene_prot_pep_sample dt, gene g
        where dt.sample_oid = ?
        and dt.gene_oid = g.gene_oid
        group by (g.gene_oid, g.locus_tag, g.gene_display_name)
    }; 
    foreach my $sample_oid( @sample_oids ) {
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
        my %profile = %template; 
        for ( ;; ) { 
            my ( $gid, $locus_tag, $name, $coverage )
                = $cur->fetchrow(); 
            last if !$gid; 
            $profile{ $gid } = $coverage;
            $geneInfo{ $gid } = $locus_tag."\t".$name;
        } 
        $cur->finish(); 
        $sampleProfiles{ $sample_oid } = \%profile; 
    }

    #$dbh->disconnect();

    use TabHTML;
    TabHTML::printTabAPILinks("imgTab");
    my @tabIndex = ( "#tab1", "#tab2" );
    my @tabNames = ( "Up-regulated Genes", "Down-regulated Genes" );
    TabHTML::printTabDiv("imgTab", \@tabIndex, \@tabNames);

    foreach my $tab (@tabIndex) {
	my $a = "tab1";
	$a = "tab2" if $tab eq "#tab2";

	print "<div id='$a'><p>\n"; 
        # For separate tables in multiple tabs, set the form id to be the 
        # InnerTable table name (3rd argument) followed by "_frm" :
        print start_form( -id     => $a."genes_frm", 
			  -name   => "mainForm", 
			  -action => "$main_cgi" ); 
	
	my $it = new InnerTable(1, $a."genes$$", $a."genes", 6); 
	my $sd = $it->getSdDelim(); 
	$it->addColSpec( "Select" ); 
	$it->addColSpec( "Gene ID", "asc", "right" ); 
	$it->addColSpec( "Locus Tag", "asc", "left" ); 
	$it->addColSpec( "Product Name", "asc", "left" ); 
	$it->addColSpec( $sample1, "desc", "right", "",
			 $sampleNames{$sample1} ); 
	$it->addColSpec( $sample2, "desc", "right", "",
			 $sampleNames{$sample2} ); 
	if ($a eq "tab1") {
	    $it->addColSpec( $metric, "desc", "right" ); 
	} else {
	    $it->addColSpec( $metric, "asc", "right" ); 
	}
 
	my $count;
	foreach my $gene( @geneIds ) {
	    my $url1 = 
		"$main_cgi?section=GeneDetail"
		. "&page=geneDetail&gene_oid=$gene";
	    
	    my $row; 
	    my $row = $sd."<input type='checkbox' "
		. "name='gene_oid' value='$gene'/>\t";
	    $row .= $gene.$sd.alink($url1, $gene)."\t"; 
	    
	    my ($locus, $product) = split('\t', $geneInfo{$gene});
	    $row .= $locus.$sd.$locus."\t"; 
	    $row .= $product.$sd.$product."\t";
	    
	    my $profile1 = $sampleProfiles{ $sample1 };
	    my $profile2 = $sampleProfiles{ $sample2 };
	    my $coverage1 = $profile1->{ $gene }; # ref coverage 
	    my $coverage2 = $profile2->{ $gene };
	    if ($coverage1 eq "0" || $coverage2 eq "0") {
		next;
	    }
	    
	    $coverage1 = sprintf("%.7f", $coverage1);
	    $coverage2 = sprintf("%.7f", $coverage2);
	    $row .= $coverage1.$sd.$coverage1."\t";
	    $row .= $coverage2.$sd.$coverage2."\t";
	    
	    my $delta;
	    if ($metric eq "logR") {
		if (abs($coverage1) == $coverage1 && 
		    abs($coverage2) == $coverage2 &&
		    abs($coverage1) > 0 && 
		    abs($coverage2) > 0) { 
		    $delta = log($coverage2/$coverage1)/log(2);
		}
	    } elsif ($metric eq "RelDiff") {
		$delta = 2*($coverage2 - $coverage1)/($coverage2 + $coverage1);
	    }
	    $delta = sprintf("%.5f", $delta);
	    next if ($a eq "tab1" &&
		     ($delta < $threshold)); # for up-regulation
	    next if ($a eq "tab2" &&
		     ($delta > -1*$threshold)); # for down-regulation
	    $row .= $delta.$sd.$delta."\t";
	    
	    $it->addRow($row); 
	    $count++;
	} 

	printGeneCartFooter($a."genes") if ($count > 10);
	$it->printOuterTable(1);  
	printGeneCartFooter($a."genes");

	print end_form();
	print "</p></div>\n";
    }

    TabHTML::printTabDivEnd(); 
    printStatusLine("Loaded.", 2); 
}

############################################################################
# printExpressionByFunction - compares selected samples per gene group:
#                     COG function, KEGG pathways, KEGG modules, etc.
############################################################################ 
sub printExpressionByFunction { 
    my ($pairwise)= @_; 
    my @sample_oids = param("exp_samples"); 
    my $nSamples = scalar (@sample_oids); 
    my $exp_oid = param("exp_oid"); 
    my $exp_name = param("exp_name"); 
    my $taxon_oid = param("taxon_oid"); 
 
    if ($pairwise ne "") {
	if ($nSamples < 2) { 
	    webError( "Please select 2 samples." ); 
	}
	my @samples = (@sample_oids[0], @sample_oids[1]);
        my $reference = param( "reference" );
        if ( $reference eq "2" ) { 
            @samples = (@sample_oids[1], @sample_oids[0]); 
        } 
	@sample_oids = @samples;
	$nSamples = 2;
    } 
    if ($nSamples < 1) { 
        webError( "Please select at least 1 sample." ); 
    } 
 
    my $cart_genes = param("describe_cart_genes");
    my @cart_gene_oids; 
    if ($cart_genes) { 
        use GeneCartStor;
        my $gc = new GeneCartStor();
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs);
        if (scalar @cart_gene_oids < 1) {
            webError( "Your Gene Cart is empty." ); 
        } 
    } 
 
    my $sample_oid_str = join(',', @sample_oids);
    printStatusLine("Loading ...", 1); 
    my $dbh = dbLogin(); 

    my %sampleNames;
    my $sql = qq{
        select distinct s.sample_oid, s.description
        from ms_sample s
        where s.sample_oid in ($sample_oid_str)
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    for( ;; ) { 
        my( $sid, $sname ) = $cur->fetchrow(); 
        last if !$sid; 
        $sampleNames{ $sid } = $sname; 
    } 
    $cur->finish(); 

    ## Template
    my $sql = qq{
        select distinct dt.gene_oid,
        g.gene_display_name, g.locus_tag, g.product_name,
        g.DNA_seq_length, gcg.cassette_oid
        from dt_img_gene_prot_pep_sample dt, gene g
        left join gene_cassette_genes gcg on gcg.gene = g.gene_oid
        where dt.sample_oid in ($sample_oid_str)
        and dt.gene_oid = g.gene_oid
        order by dt.gene_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    my %template; 
    my %geneProfile;
    for( ;; ) { 
        my( $gid, $gene_name, $locus_tag, $product, 
            $dna_seq_length, $cassette ) = $cur->fetchrow();
        last if !$gid; 
        $template{ $gid } = 0; 
        $geneProfile{ $gid } =
            "$gene_name\t$locus_tag\t$product\t$dna_seq_length\t$cassette";
    } 
    $cur->finish();
    my @geneIds = sort( keys( %template ) );
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
        @geneIds = @cart_gene_oids; 
    } 
 
    # get the coverage
    my %sampleProfiles; 

    my $sql = qq{
        select distinct g.gene_oid,
        round(sum(dt.coverage), 7)
        from dt_img_gene_prot_pep_sample dt, gene g
        where dt.sample_oid = ?
        and dt.gene_oid = g.gene_oid
        group by g.gene_oid
    }; 
    foreach my $sample_oid( @sample_oids ) {
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
        my %profile = %template;
        for ( ;; ) { 
            my ( $gid, $coverage ) = $cur->fetchrow();
            last if !$gid;
            $profile{ $gid } = $coverage;
        } 
        $cur->finish(); 
        $sampleProfiles{ $sample_oid } = \%profile;
    } 

    print "<h1>Expression by Function for Selected Samples</h1>\n"; 
    print "<span style='font-size: 12px; " 
        . "font-family: Arial, Helvetica, sans-serif;'>\n"; 
    my $url = "$section_cgi&page=experiments" 
        . "&exp_oid=$exp_oid&taxon_oid=$taxon_oid"; 
    print alink($url, $exp_name, "_blank")."\n"; 
    print "</span>\n"; 
 
    my $hint = 
        "Click on a tab to select grouping of genes " 
      . "by kegg or by cog function. " 
      . "For each sample, the sum of normalized expression values " 
      . "for each group of genes is displayed." 
      . "<br/>Analyzing $nSamples sample(s)."; 
    if ($cart_genes && (scalar @cart_gene_oids > 0)) { 
        $hint .= "<br/>*Showing only genes from gene cart"; 
    } 
    printHint($hint); 
 
    if ($taxon_oid ne "") { 
        my $sql = qq{
            select taxon_name
            from taxon
            where taxon_oid = ?
        }; 
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
        my ($taxon_name) = $cur->fetchrow(); 
        $cur->finish(); 
 
        my $url = "$main_cgi?section=TaxonDetail" 
            ."&page=taxonDetail&taxon_oid=$taxon_oid"; 
        print "<p>".alink($url, $taxon_name, "_blank")."</p>\n"; 
    } else { 
        print "<br/>"; 
    } 

    my $sql = qq{
        select dt.sample_oid, gkmp.gene_oid, pw.pathway_name, pw.image_id
        from kegg_pathway pw, dt_img_gene_prot_pep_sample dt, 
             dt_gene_ko_module_pwys gkmp
        where pw.pathway_oid = gkmp.pathway_oid
        and dt.sample_oid in ($sample_oid_str)
        and dt.gene_oid = gkmp.gene_oid
        order by dt.sample_oid, gkmp.gene_oid, pw.pathway_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
 
    my %done; 
    my %pathw2genes; 
    for( ;; ) { 
        my( $sample, $gene_oid, $pathway_name, $image_id )
            = $cur->fetchrow( ); 
        last if !$gene_oid; 
        next if ($image_id eq 'map01100'); 
        next if $done{ "$sample"."$gene_oid"."$image_id" };
 
        $pathw2genes{ $sample.$image_id } .= $gene_oid."\t";
        $done{ "$sample"."$gene_oid"."$image_id" } = 1;
    } 
    $cur->finish(); 
 
    # get the genes for each cog
    my $sql = qq{
        select dt.sample_oid, gcg.gene_oid, cf.function_code, cf.definition
        from gene_cog_groups gcg, cog c,
             cog_functions cfs, cog_function cf,
             dt_img_gene_prot_pep_sample dt, ms_sample s
        where gcg.gene_oid = dt.gene_oid
        and gcg.cog = c.cog_id
        and c.cog_id = cfs.cog_id
        and cfs.functions = cf.function_code
        and dt.sample_oid in ($sample_oid_str)
        and dt.sample_oid = s.sample_oid
        and s.IMG_taxon_oid = gcg.taxon
        order by dt.sample_oid, gcg.gene_oid, cf.function_code
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %done; 
    my %cog2genes; 
    for ( ;; ) { 
        my ( $sample, $gene_oid, $cog_fn, $cog_def ) = $cur->fetchrow(); 
        last if !$gene_oid; 
        next if $done{ "$sample"."$gene_oid"."$cog_fn" }; 
        $cog2genes{ $sample.$cog_fn } .= $gene_oid."\t"; 
        $done{ "$sample"."$gene_oid"."$cog_fn" } = 1; 
    } 
    $cur->finish(); 
 
    my $kegg_sql = qq{
        select pw.pathway_name, pw.image_id,
               count (distinct gkmp.gene_oid)
        from kegg_pathway pw, 
             dt_img_gene_prot_pep_sample dt,
             dt_gene_ko_module_pwys gkmp
        where pw.pathway_oid = gkmp.pathway_oid
        and dt.sample_oid in ($sample_oid_str)
        and dt.gene_oid = gkmp.gene_oid
        group by pw.pathway_name, pw.image_id
        order by pw.pathway_name, pw.image_id
    };
 
    my $cog_sql = qq{
        select cf.function_code, cf.definition, 
               count(distinct gcg.gene_oid)
        from gene_cog_groups gcg, cog c,
             cog_functions cfs, cog_function cf,
             dt_img_gene_prot_pep_sample dt, ms_sample s
        where gcg.gene_oid = dt.gene_oid
        and gcg.cog = c.cog_id
        and c.cog_id = cfs.cog_id
        and cfs.functions = cf.function_code
        and dt.sample_oid in ($sample_oid_str)
        and dt.sample_oid = s.sample_oid
        and s.IMG_taxon_oid = gcg.taxon
        group by cf.function_code, cf.definition
        order by cf.function_code, cf.definition
    }; 
 
    my $metric = param( "metric" ); 
    my $total1; # ref
    my $total2; 
 
    use TabHTML; 
    TabHTML::printTabAPILinks("imgTab"); 
    my @tabIndex = ( "#tab1", "#tab2" ); 
    my @tabNames = ( "By KEGG", "By COG" ); 
    TabHTML::printTabDiv("imgTab", \@tabIndex, \@tabNames); 
 
    print "<div id='tab1'><p>\n"; 
    my $it = new InnerTable(1, "bykeggfunc$$", "bykeggfunc", 0); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "KEGG Pathway", "asc", "left", "", "", "wrap" ); 
    $it->addColSpec( "Total<br/>Gene Count", "asc", "right" ); 
    foreach my $s( @sample_oids ) { 
        $it->addColSpec( "Gene Count<br/>[sample: $s]", "asc", "right" );
	$it->addColSpec 
	    ( "Average Expression<br/>".$sampleNames{$s}." [".$s."]", 
	      "desc", "right", "", 
	      "Average Normalized Coverage for: " 
	      . $sampleNames{$s}, "wrap" ); 
    }
    if ($pairwise ne "") { 
        $it->addColSpec( $metric, "desc", "right" );
    } 
 
    my $cur = execSql( $dbh, $kegg_sql, $verbose );
    for( ;; ) {
        my( $pathway, $image_id, $gene_count )
            = $cur->fetchrow( ); 
        next if ($image_id eq 'map01100');
        last if !$image_id; 
 
        my $url = "$main_cgi?section=PathwayMaps"
            . "&page=keggMapSamples&map_id=$image_id"
            . "&study=$study&samples=$sample_oid_str";
 
        my $row; 
        $row .= $pathway.$sd.alink($url, $pathway, "_blank", 0, 1)."\t";
        $row .= $gene_count."\t"; 
 
        my $idx=0;
        foreach my $s( @sample_oids ) {
            my $geneStr = $pathw2genes{ $s.$image_id }; 
            chop $geneStr; 
 
            my $group_url =  "$section_cgi&page=geneGroup" 
                . "&exp_oid=$exp_oid&sample=$s"
                . "&taxon_oid=$taxon_oid&fn_id=$image_id&fn=kegg"; 
            my @gene_group = split("\t", $geneStr);
            my $group_count = scalar(@gene_group);
	    if ($group_count == 0) {
		$row .= $group_count."\t";
	    } else {
		$row .= $group_count.$sd 
		    .alink($group_url, $group_count, "_blank", 0, 1)."\t";
	    }

            my $total = 0; 
            my $profile = $sampleProfiles{ $s };
	    GENE: foreach my $gene( @gene_group ) {
		my $coverage = $profile->{ $gene }; # coverage
		if ($coverage eq "0" || $coverage eq "") {
		    next GENE;
		} else { 
		    $coverage = sprintf("%.7f", $coverage);
		}
		$total = $coverage + $total; 
	    } 
 
	    if ($group_count == 0) {
		$row .= "0\t";
	    } else {
		my $average = $total/$group_count;
		$average = sprintf("%.7f", $average);
		$row .= "$average\t";
	    }

            if ($pairwise ne "") { 
		if ($idx == 0) {
		    $total1 = $total;
		} else {
		    $total2 = $total;
		}
            }
            $idx++;
        } 
 
        if ($pairwise ne "") {
            my $delta;
	    if ($total1 == 0 || $total2 == 0) {
	    } else {
		if ($metric eq "logR") { 
		    if (abs($total1) == $total1 && 
			abs($total2) == $total2 &&
			abs($total1) > 0 && abs($total2) > 0) { 
			$delta = log($total2/$total1)/log(2);
		    } 
		} elsif ($metric eq "RelDiff") {
		    $delta = 2*($total2 - $total1)/($total2 + $total1);
		} 
		$delta = sprintf("%.5f", $delta); 
	    }
            $row .= "$delta\t"; 
        } 
        $it->addRow($row);
    } 
    $cur->finish(); 
    $it->printOuterTable(1);
    print "</p></div>\n"; # keggs div
 
    print "<div id='tab1'><p>\n"; 
    my $cur = execSql( $dbh, $cog_sql, $verbose );
 
    my $it = new InnerTable(1, "bycogfunc$$", "bycogfunc", 0); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "COG Function", "asc", "left", "", "", "wrap" ); 
    $it->addColSpec( "Total<br/>Gene Count", "asc", "right" ); 
    foreach my $s( @sample_oids ) { 
        $it->addColSpec( "Gene Count<br/>[sample: $s]", "asc", "right" ); 
	$it->addColSpec 
	    ( "Average Expression<br/>".$sampleNames{$s}." [".$s."]", 
	      "desc", "right", "", 
	      "Average Normalized Coverage for: " 
	      . $sampleNames{$s}, "wrap" ); 
    } 
    if ($pairwise ne "") { 
        $it->addColSpec( $metric, "desc", "right" ); 
    } 
 
    for( ;; ) { 
        my ( $cog_fn, $cog_def, $gene_count ) = $cur->fetchrow(); 
        last if !$cog_fn; 
 
        my $url = "$main_cgi?section=CogCategoryDetail" 
            . "&page=cogCategoryDetail&function_code=$cog_fn"; 
 
        my $row; 
        #$row .= $cog_def.$sd.alink($url, $cog_def, "_blank", 0, 1)."\t";
        $row .= $cog_def.$sd.alink($url, $cog_fn, "_blank") 
              . " - ".$cog_def."\t"; 
        $row .= $gene_count."\t"; 
 
        my $idx=0; 
        foreach my $s( @sample_oids ) { 
            my $geneStr = $cog2genes{ $s.$cog_fn }; 
            chop $geneStr; 
 
            my $group_url =  "$section_cgi&page=geneGroup" 
                . "&exp_oid=$exp_oid&sample=$s" 
                . "&taxon_oid=$taxon_oid&fn_id=$cog_fn&fn=cog"; 
            my @gene_group = split("\t", $geneStr); 
            my $group_count = scalar(@gene_group); 
            if ($group_count == 0) {
                $row .= $group_count."\t";
            } else { 
		$row .= $group_count.$sd 
		    .alink($group_url, $group_count, "_blank", 0, 1)."\t"; 
	    }

	    my $profile = $sampleProfiles{ $s }; 
            my $total=0; 
            GENE: foreach my $gene( @gene_group ) {
		my $coverage = $profile->{ $gene }; # coverage  
                if ($coverage eq "0" || $coverage eq "") { 
                    next GENE if ($nSamples == 1 || $pairwise ne ""); 
                    $coverage = sprintf("%.7f", $coverage); 
                } else { 
                    $coverage = sprintf("%.7f", $coverage); 
                } 
                $total = $coverage + $total; 
            } 
 
            if ($group_count == 0) { 
                $row .= "0\t";
            } else { 
		# need to change to average expression sprintf
		my $average = $total/$group_count; 
		$average = sprintf("%.7f", $average); 
		$row .= "$average\t"; 
	    }

            if ($pairwise ne "") { 
		if ($idx == 0) {
		    $total1 = $total;
		} else {
		    $total2 = $total;
		}
            } 
            $idx++; 
        } 
 
        if ($pairwise ne "") { 
            my $delta; 
	    if ($total1 == 0 || $total2 == 0) {
	    } else {
		if ($metric eq "logR") { 
		    if (abs($total1) == $total1 && 
			abs($total2) == $total2 &&
			abs($total1) > 0 && abs($total2) > 0) { 
			$delta = log($total2/$total1)/log(2); 
		    } 
		} elsif ($metric eq "RelDiff") { 
		    $delta = 2*($total2 - $total1)/($total2 + $total1); 
		} 
		$delta = sprintf("%.5f", $delta); 
	    }
            $row .= "$delta\t"; 
        } 
        $it->addRow($row); 
    } 
    $cur->finish(); 
 
    $it->printOuterTable(1); 
    print "</p></div>\n"; # cogs div
 
    #$dbh->disconnect(); 
    TabHTML::printTabDivEnd(); 
    printNotes("studysamples"); 
    printStatusLine("Loaded.", 2); 
}

############################################################################
# printGeneGroup - prints a table of genes with gene info
############################################################################
sub printGeneGroup { 
    my $taxon_oid = param("taxon_oid"); 
    my $sample = param("sample"); 
    my $exp_oid = param("exp_oid"); 
    my $fn_id = param("fn_id"); 
    my $fn = param("fn"); 
 
    printStatusLine("Loading ...", 1); 
    my $dbh = dbLogin(); 
 
    my $sql = qq{ 
        select s.description, e.exp_name, tx.taxon_name
        from ms_sample s, ms_experiment e, taxon tx
        where s.experiment = e.exp_oid
        and s.IMG_taxon_oid = tx.taxon_oid
        and s.sample_oid = ?
        and e.exp_oid = ?
        and s.IMG_taxon_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample, $exp_oid, $taxon_oid ); 
    my ($sample_desc, $exp_name, $taxon_name) = $cur->fetchrow(); 
    $cur->finish(); 
 
    my $sql; 
    my $fn_str; 
    if ($fn eq "kegg") { 
        my $kegg_sql = qq{
            select pw.pathway_name
            from kegg_pathway pw
            where pw.image_id = ?
        }; 
        my $cur = execSql( $dbh, $kegg_sql, $verbose, $fn_id ); 
        my ($pathway_name) = $cur->fetchrow(); 
        $cur->finish(); 
 
        $fn_str = "Function (KEGG): $pathway_name"; 
 
        $sql = qq{
        select distinct g.gene_oid, g.gene_display_name,
        g.locus_tag, g.product_name, g.DNA_seq_length
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk,
             gene g, dt_img_gene_prot_pep_sample dt, gene_ko_terms gkt
        where pw.pathway_oid = roi.pathway
        and roi.roi_id = irk.roi_id
        and irk.ko_terms = gkt.ko_terms
        and gkt.gene_oid = g.gene_oid
        and pw.image_id = ?
        and dt.sample_oid = ?
        and dt.gene_oid = g.gene_oid
        }; 
 
    } elsif ($fn eq "cog") { 
        my $cog_sql = qq{
            select cf.definition
            from cog_function cf
            where cf.function_code = ?
        }; 
        my $cur = execSql( $dbh, $cog_sql, $verbose, $fn_id ); 
        my ($definition) = $cur->fetchrow(); 
        $cur->finish(); 
 
        $fn_str = "Function (COG): $definition"; 
 
        $sql = qq{
        select distinct g.gene_oid, g.gene_display_name,
        g.locus_tag, g.product_name, g.DNA_seq_length
        from gene g, gene_cog_groups gcg, cog c,
             cog_functions cfs, cog_function cf,
             dt_img_gene_prot_pep_sample dt
        where g.gene_oid = dt.gene_oid
        and g.gene_oid = gcg.gene_oid
        and gcg.cog = c.cog_id
        and c.cog_id = cfs.cog_id
        and cfs.functions = ?
        and dt.sample_oid = ?
        }; 
    } 
 
    print "<h1>RNASeq Expression for Function</h1>\n"; 
    my $url = "$section_cgi&page=sampledata&sample=$sample"; 
    print "<p>Sample: ".alink($url, $sample_desc, "_blank"); 
    print "<br/>\n"; 
 
    print "$fn_str<br/>"; 
    my $url = "$section_cgi&page=experiments" 
        . "&exp_oid=$exp_oid&taxon_oid=$taxon_oid"; 
    print "Study: ".alink($url, $exp_name, "_blank")."</p>\n"; 
 
    my $cur = execSql( $dbh, $sql, $verbose, $fn_id, $sample ); 
 
    printMainForm(); 
 
    my $it = new InnerTable(1, "genegroupfn$$", "genegroupfn", 1); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" ); 
    $it->addColSpec( "Gene ID", "asc", "right" ); 
    $it->addColSpec( "Locus Tag", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Product Name", "asc", "left" ); 
 
    for ( ;; ) { 
        my ($gene, $gene_name, $locus_tag, $product, $dna_seq_length)
            = $cur->fetchrow(); 
        last if !$gene;
 
        my $url1 = "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene"; 
 
        my $row; 
        my $row = $sd."<input type='checkbox' " 
            . "name='gene_oid' value='$gene'/>\t"; 
        $row .= $gene.$sd.alink($url1, $gene, "_blank")."\t"; 
        $row .= $locus_tag."\t"; 
        $row .= $product."\t"; 
        $row .= $dna_seq_length."\t"; 
        $it->addRow($row); 
    } 
    $cur->finish();
    #$dbh->disconnect();
 
    printGeneCartFooter(); 
    $it->printOuterTable(1); 
    printGeneCartFooter(); 
 
    print end_form();
    printStatusLine("Loaded.", 2);
}

############################################################################ 
# printDescribeSamples - compares selected samples per gene: coverage,
#                     COG function, KEGG pathways
############################################################################ 
sub printDescribeSamples { 
    my ($describe_clustered) = @_; 
    my @sample_oids = param("exp_samples"); 
    my $nSamples = @sample_oids; 
    my $exp_oid = param("exp_oid"); 
    my $exp_name = param("exp_name"); 
    my $taxon_oid = param("taxon_oid"); 
    my $min_abundance = param("min_num");
    if ($min_abundance < 3 || $min_abundance > $nSamples) {
        $min_abundance = 3; 
    }

    if ($describe_clustered ne "") {
        if ($nSamples < 3) { 
            webError( "Please select at least 3 samples." ); 
        } 
    } else { 
        if ($nSamples < 1) {
            webError( "Please select at least 1 sample." );
        }
    } 

    my $cart_genes = param("describe_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) {
	use GeneCartStor; 
	my $gc = new GeneCartStor(); 
	my $recs = $gc->readCartFile(); # get records
	@cart_gene_oids = sort { $a <=> $b } keys(%$recs);
	if (scalar @cart_gene_oids < 1) {
	    webError( "Your Gene Cart is empty." );
	}
    }

    my $sample_oid_str = join(',', @sample_oids);
    printStatusLine("Loading ...", 1); 
    my $dbh = dbLogin(); 

    my %sampleNames; 
    my $sql = qq{ 
        select distinct s.sample_oid, s.description 
	from ms_sample s 
	where s.sample_oid in ($sample_oid_str)
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) { 
        my( $sid, $sname ) = $cur->fetchrow();
        last if !$sid;
        $sampleNames{ $sid } = $sname; 
    } 
    $cur->finish();

    if ( $nSamples == 1 && $taxon_oid ne "") {
	print "<h1>Protein Expression Data for Selected Sample</h1>"; 
	my $url = "$main_cgi?section=IMGProteins" 
	    . "&page=sampledata&sample=@sample_oids[0]"; 
	print "<p>".alink($url, $sampleNames{ $sample_oid_str })."</p>\n"; 

        if ($cart_genes && (scalar @cart_gene_oids > 0)) {
            print "<p>*Showing only genes from gene cart</p>";
        }
	my $url = "$main_cgi?section=TaxonDetail&page=scaffolds"
	    . "&taxon_oid=$taxon_oid&study=$study&sample=@sample_oids[0]";
	print buttonUrl( $url, "Chromosome Viewer", "smbutton" );
	print "<br/>";

    } else {
	print "<h1>Protein Expression Data for Selected Samples</h1>\n"; 
	print "<p>\n"; 
	print "$nSamples sample(s) selected"; 
	if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	    print "<br/>*Showing only genes from gene cart";
	} 
	print "</p>\n"; 
    }

    print "<span style='font-size: 12px; "
        . "font-family: Arial, Helvetica, sans-serif;'>\n";
    my $url = "$section_cgi&page=genomeexperiments"
            . "&exp_oid=$exp_oid&taxon_oid=$taxon_oid"; 
    print alink($url, $exp_name, "_blank")."\n";
    print "</span>\n"; 
    print "<br/>";

    my $tmpOutputFileName; 
    my %clusteredData; 
    my %uniqueClusters; 
    my %color_hash; 
    my @color_array; 
    my $im = new GD::Image( 10, 10 ); 
 
    if ($describe_clustered ne "") { 
        my $threshold = param("cluster_threshold");
        if ($threshold eq "") {
            $threshold = 0.8; 
        } 
        my $method = param("method");
        $method =~ /([msca])/;
        $method = $1; 
        if ($method eq "") { 
            $method = "m"; 
        } 
        # new clustering method : need to map
        # params from Cluster 3.0 to those used by hclust
        if ($method eq "m") { 
            $method = "complete";
        } elsif ($method eq "s") { 
            $method = "single";
        } elsif ($method eq "c") { 
            $method = "centroid"; 
        } elsif ($method eq "a") { 
            $method = "average"; 
        } 
        $method = checkPath($method);
 
        my $correlation = param("correlation"); 
        $correlation =~ /([0-8])/; 
        $correlation = $1; 
        if ($correlation eq "") { 
            $correlation = 2; 
        } 
        if ($correlation eq "2") { 
            $correlation = "pearson"; 
        } elsif ($correlation eq "5") { 
            $correlation = "spearman"; 
        } elsif ($correlation eq "7") { 
            $correlation = "euclidean"; 
        } elsif ($correlation eq "8") { 
            $correlation = "manhattan"; 
        } 
        $correlation = checkPath($correlation); 
 
        print "<p>\n"; 
        if ($nSamples < 8) { 
            print "<u>Note</u>: selecting too few conditions may result " 
                . "in skewed clusters.<br/>"; 
        } 

	print "Each gene is set to appear in at least "
	    . "$min_abundance (out of $nSamples) samples.<br/>";
        print "Clustering samples (and genes) ... using log values<br/>\n"; 
        print "Cut-off threshold set to: $threshold"; 
        print "</p>"; 
 
        # make a CDT file:
        my $inputFile = makeProfileFile
	    ($dbh, $sample_oid_str, \@cart_gene_oids); 

        my $program = "$cgi_dir/bin/hclust2CDT_cutTree.R"; 
        my $groups = 1; 
        my $inputFileRoot = "$tmp_dir/cluster$$"; 
        $threshold = checkPath($threshold); 
 
        printStartWorkingDiv(); ############
        WebUtil::unsetEnvPath(); 
        my $env = "PATH='/bin:/usr/bin'; export PATH"; 
        my $cmd ="$env; $R --slave --args " 
               . "$inputFile $correlation $method $groups " 
	       . "$threshold $inputFileRoot 2 " 
	       . "< $program > /dev/null"; 
        print "<br/>Command: $cmd"; 
        my $st = system($cmd); 
        WebUtil::resetEnvPath(); 
 
        if ($st != 0) {
            printEndWorkingDiv();
	    if ($nSamples < 5) {
		webError( "Problem running R script: $program. <br/>"
			. "Try selecting a larger number of samples." );
	    }
            webError( "Problem running R script: $program." );
        }

        $tmpOutputFileName = "cluster$$.groups.txt"; 
        my $tmpOutputFile = "$tmp_dir/cluster$$.groups.txt"; 
 
        my $rfh = newReadFileHandle 
            ( $tmpOutputFile, "describeClustered" ); 
        my $i = 0; 
        while( my $s = $rfh->getline() ) { 
            $i++; 
            next if $i == 1; 
            chomp $s; 
 
            my( $gid, $value ) = split( / /, $s ); 
            $gid =~ s/"//g; 
            $clusteredData{ $gid } = $value; 
            $uniqueClusters{ $value } = 1; 
        } 
        close $rfh; 

	use RNAStudies;
        my $colors; 
        @color_array = RNAStudies::loadMyColorArray($im, $color_array_file); 
        print "Loading colors...<br/>"; #####

        my @clusters = sort keys( %uniqueClusters ); 
        my $nClusters = scalar @clusters; 
        my $n = ceil($nClusters/255); 
        my $i = 0; 
        foreach my $cluster (@clusters) { 
            if ($i == 246) { $i = 0; } 
            $color_hash{ $cluster } = $color_array[ $i ]; 
            $i++; 
        } 
        print "Querying for data...<br/>"; #####
        printEndWorkingDiv(); 
    } 

    ## Template 
    my $sql = qq{ 
        select distinct dt.gene_oid, dt.sample_oid, 
        g.gene_display_name, g.locus_tag, g.product_name, 
        g.DNA_seq_length, gcg.cassette_oid
        from dt_img_gene_prot_pep_sample dt, gene g
        left join gene_cassette_genes gcg on gcg.gene = g.gene_oid
        where dt.sample_oid in ($sample_oid_str)
        and dt.coverage > 0.000
        and dt.gene_oid = g.gene_oid
        order by dt.gene_oid 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );

    my %template;
    my %template0;
    my %geneProfile;
    for( ;; ) { 
        my( $gid, $sample, $gene_name, $locus_tag, $product,
	    $dna_seq_length, $cassette ) = $cur->fetchrow();
        last if !$gid;
        if ( !defined($template{ $gid }) ) {
            $template{ $gid } = 0;
        } 
        $template{ $gid }++;
	$template0{ $gid } = 0;
	$geneProfile{ $gid } = 
	    "$gene_name\t$locus_tag\t$product\t$dna_seq_length\t$cassette";
    } 
    $cur->finish();

    if ($describe_clustered ne "") {
	my %template2;
	my @gids = sort( keys( %template ) );
	foreach my $i( @gids ) { 
	    if ($template{ $i } < $min_abundance) { next; } 
	    $template2{ $i } = 0; 
	} 
	%template = %template2;
    } else {
	%template = %template0;
    }

    my @geneIds = sort( keys( %template ) ); 
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	@geneIds = @cart_gene_oids;
    }

    # get the coverage
    my %sampleProfiles; 
    my $sql = qq{
        select distinct g.gene_oid,
	round(sum(dt.coverage), 7)
        from dt_img_gene_prot_pep_sample dt, gene g
        where dt.sample_oid = ?
        and dt.gene_oid = g.gene_oid 
        and dt.coverage > 0.000
        group by g.gene_oid
    }; 
    foreach my $sample_oid( @sample_oids ) { 
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid ); 
        my %profile = %template; 
        for ( ;; ) { 
            my ( $gid, $coverage ) = $cur->fetchrow();
            last if !$gid; 
	    $profile{ $gid } = $coverage;
        } 
        $cur->finish();
        $sampleProfiles{ $sample_oid } = \%profile;
    } 

    # get the kegg pathways 
    my $sql = qq{
	select distinct gkmp.gene_oid, 
	       pw.pathway_name, pw.image_id,
               km.module_name, km.module_id,
               kte.enzymes
        from kegg_pathway pw,
	     dt_img_gene_prot_pep_sample dt,
             dt_gene_ko_module_pwys gkmp
        left join kegg_module km on km.module_id = gkmp.module_id
        left join ko_term_enzymes kte on kte.ko_id = gkmp.ko_terms
        where pw.pathway_oid = gkmp.pathway_oid
	and dt.sample_oid in ($sample_oid_str)
	and dt.gene_oid = gkmp.gene_oid 
	order by gkmp.gene_oid, km.module_name, pw.pathway_name
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );

    my %done; 
    my %gene2pathw; 
    my %gene2module;
    my %gene2ec;
    for( ;; ) { 
	my( $gene_oid, $pathway_name, $image_id, $module, $module_id, $ec )
	    = $cur->fetchrow( ); 
	last if !$gene_oid; 
	next if ($image_id eq 'map01100');
	next if $done{ "$gene_oid"."$image_id"."$module" };

	$gene2ec{ $gene_oid } = $ec;
	$gene2module{ $gene_oid } = 
	    $module."\t".$pathway_name."\t".$image_id."#";
	$gene2pathw{ $gene_oid } .= $pathway_name."\t".$image_id."#";
	$done{ "$gene_oid"."$image_id"."$module" } = 1;
    } 
    $cur->finish(); 

    # get the cogs
    my $sql = qq{ 
	select gcg.gene_oid, cf.function_code, cf.definition
        from gene_cog_groups gcg, cog c, 
	     cog_functions cfs, cog_function cf,
             dt_img_gene_prot_pep_sample dt, ms_sample s
        where gcg.gene_oid = dt.gene_oid
	and gcg.cog = c.cog_id 
	and c.cog_id = cfs.cog_id 
	and cfs.functions = cf.function_code 
	and dt.sample_oid in ($sample_oid_str) 
        and dt.sample_oid = s.sample_oid
        and s.IMG_taxon_oid = gcg.taxon
	order by gcg.gene_oid, cf.function_code
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    my %done;
    my %gene2cog;
    for ( ;; ) { 
        my ( $gene_oid, $cog_fn, $cog_fn_def ) = $cur->fetchrow(); 
        last if !$gene_oid; 
	next if $done{ "$gene_oid"."$cog_fn" };
        $gene2cog{ $gene_oid } .= $cog_fn."\t".$cog_fn_def."#"; 
	$done{ "$gene_oid"."$cog_fn" } = 1;
    } 
    $cur->finish();

    printMainForm(); 

    my $it = new InnerTable(1, "descsamples$$", "descsamples", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Product Name", "asc", "left" ); 
    if ($describe_clustered ne "") { 
        $it->addColSpec( "Cluster ID", "asc", "right", "", "", "wrap" );
    } 
    foreach my $s(@sample_oids) {
	$it->addColSpec 
	    ( $sampleNames{$s}." [".$s."]", "desc", "right", "", 
	      "Normalized Coverage for: " . $sampleNames{$s}, "wrap" ); 
        #$it->addColSpec( $s, "desc", "right", "", $sampleNames{$s} );
    }
    $it->addColSpec( "Cassette ID", "asc", "right", "", "", "wrap" );
    $it->addColSpec( "COG function", "asc", "left" );
    $it->addColSpec( "KEGG pathway", "asc", "left" );
    $it->addColSpec( "EC Number", "asc", "left" ); 
    $it->addColSpec( "KEGG module", "asc", "left" );

    my $count;
    GENE: foreach my $gene( @geneIds ) {
        my $url1 = 
            "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene"; 
 
        my $row; 
        my $row = $sd."<input type='checkbox' "
	    . "name='gene_oid' value='$gene'/>\t";
        $row .= $gene.$sd.alink($url1, $gene)."\t"; 

        my ($product, $locus, $dna_seq_length, $cassette)
            = split('\t', $geneProfile{$gene}); 
        $row .= $locus.$sd.$locus."\t"; 
        $row .= $product.$sd.$product."\t"; 

        if ($describe_clustered ne "") {
            my $clusterid = $clusteredData{ $gene }; 
            my $color  = $color_hash{ $clusterid };
            my ( $r, $g, $b ) = $im->rgb( $color );
 
            $row .= $clusterid.$sd;
            $row .= "<span style='border-right:1em solid rgb($r, $g, $b); "
                 . "padding-right:0.5em; margin-right:0.5em'> " 
                 . "$clusterid</span>"; 
            $row .= "\t";
        } 

        foreach my $sid (@sample_oids) {
            my $profile = $sampleProfiles{ $sid };
            my $coverage = $profile->{ $gene }; # coverage

	    if ($coverage eq "0" || $coverage eq "") {
		next GENE if ($nSamples == 1);
		$coverage = sprintf("%.7f", $coverage);

		$row .= $coverage.$sd.
		    "<span style='background-color:lightgray; ";
		#$row .= "padding:4px 10px;";
		$row .= "'>";
		$row .= $coverage;
		$row .= "</span>\t"; 
	    } else {
		$coverage = sprintf("%.7f", $coverage);
		$row .= $coverage.$sd.$coverage."\t"; 
	    }
        } 

	my $url4 = "$main_cgi?section=GeneCassette"
	    . "&page=cassetteBox&gene_oid=$gene&cassette_oid=$cassette";
	$row .= $cassette.$sd.alink($url4, $cassette, "_blank")."\t";

	my $allcogs = $gene2cog{ $gene };
	my @cogs = split('#', $allcogs);
	my $s;
	foreach my $item(@cogs) {
	    my ($c, $desc) = split('\t', $item);
	    my $url2 = "$main_cgi?section=CogCategoryDetail"
		. "&page=cogCategoryDetail&function_code=$c";
	    $s .= alink($url2, $c, "_blank")." - ".$desc."<br/>";
	}
	chop $s;
	$row .= $s.$sd.$s."\t";

	my $allpathw = $gene2pathw{ $gene };
	my @pathways = split('#', $allpathw);
        my %set; 
        @set{@pathways} = (); 
        my @unique_pathways = keys %set; 
 
	my $s;
	foreach my $item(@unique_pathways) {
	    my ($p, $im) = split('\t', $item);
	    my $url3 = "$main_cgi?section=PathwayMaps"
		. "&page=keggMapSamples&map_id=$im"
		. "&study=$study&samples=$sample_oid_str";
            if ($describe_clustered ne "") {
                $url3 .= "&file=$tmpOutputFileName";
                $url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
            } 
	    $s .= alink($url3, $p, "_blank", 0, 1)."<br/>";
	}
	chop $s;
        $row .= $s.$sd.$s."\t"; 

        my $ec = $gene2ec{ $gene };
        $row .= $ec.$sd.$ec."\t"; 
 
        my $allmodules = $gene2module{ $gene };
        my @keggmodules = split('#', $allmodules); 

        my $s; 
        my $module0;
        my @images; 
        foreach my $item(@keggmodules) {
            my ($m, $p, $im) = split('\t', $item);
            next if $m eq ""; 
 
            if ($module0 eq "") {
                $module0 = $m;
            } 
            if ($module0 ne $m) { 
                if (scalar @images == 1) { 
                    my $url3 = "$main_cgi?section=PathwayMaps"
                        . "&page=keggMapSamples&map_id=$images[0]"
                        . "&study=$study&samples=$sample_oid_str";
		    if ($describe_clustered ne "") { 
			$url3 .= "&file=$tmpOutputFileName";
			$url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
		    }
                    $s .= alink($url3, $module0, "_blank", 0, 1)."<br/>";
                } elsif (scalar @images > 1) {
                    my $imageStr; 
                    foreach my $image (sort @images) { 
                        my $url3 = "$main_cgi?section=PathwayMaps"
                            . "&page=keggMapSamples&map_id=$image"
                            . "&study=$study&samples=$sample_oid_str";
			if ($describe_clustered ne "") { 
			    $url3 .= "&file=$tmpOutputFileName";
			    $url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
			}
			if ($imageStr ne "") { 
                            $imageStr .= ", "; 
                        } 
                        $imageStr .= alink($url3, $image, "_blank", 0, 1); 
                    } 
                    $s .= $module0." ($imageStr) <br/>"; 
                } 
                $module0 = $m; 
                @images = (); 
            } 
            if ($module0 eq $m) { 
                push @images, $im; 
            } 
        } 
	if (scalar @images == 1) { 
            my $url3 = "$main_cgi?section=PathwayMaps" 
                . "&page=keggMapSamples&map_id=$images[0]" 
                . "&study=$study&samples=$sample_oid_str"; 
            if ($describe_clustered ne "") { 
		$url3 .= "&file=$tmpOutputFileName";
		$url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
	    }
            $s .= alink($url3, $module0, "_blank", 0, 1)."<br/>"; 
        } elsif (scalar @images > 1) { 
            my $imageStr; 
            foreach my $image (sort @images) { 
                my $url3 = "$main_cgi?section=PathwayMaps" 
                    . "&page=keggMapSamples&map_id=$image" 
                    . "&study=$study&samples=$sample_oid_str"; 
		if ($describe_clustered ne "") { 
		    $url3 .= "&file=$tmpOutputFileName";
		    $url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
		}
                if ($imageStr ne "") { 
                    $imageStr .= ", "; 
                } 
                $imageStr .= alink($url3, $image, "_blank", 0, 1); 
            } 
            $s .= $module0." ($imageStr) <br/>"; 
        } 
        chop $s; 
        $row .= $s.$sd.$s."\t"; 

        $it->addRow($row); 
        $count++; 
    } 
    printGeneCartFooter() if ($count > 10);
    $it->printOuterTable(1); 
    printGeneCartFooter();

    #$dbh->disconnect(); 
    print end_form(); 
    printStatusLine("$count Genes Loaded.", 2); 
}

############################################################################
# makeProfileFile - makes an input profile file
#             for R program that computes cluster groupings
############################################################################
sub makeProfileFile { 
    my ($dbh, $sample_oid_str, $cart_genes) = @_; 
    my @cart_gene_oids = @$cart_genes;
    my @sample_oids = split(",", $sample_oid_str);
    my $nSamples = scalar(@sample_oids);

    my $min_abundance = param("min_num");
    if ($min_abundance < 3 || $min_abundance > $nSamples) {
        $min_abundance = 3; 
    } 
 
    ## Template  
    my $sql = qq{
        select distinct dt.gene_oid, dt.sample_oid
        from dt_img_gene_prot_pep_sample dt
        where dt.sample_oid in ($sample_oid_str)
        order by dt.gene_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %template; 
    for( ;; ) { 
        my( $gid ) = $cur->fetchrow(); 
        last if !$gid; 
        if ( !defined($template{ $gid }) ) { 
            $template{ $gid } = 0; 
        } 
        $template{ $gid }++; 
    } 
    $cur->finish(); 

    my %template2;
    my @gids = sort( keys( %template ) );
    foreach my $i( @gids ) {
        if ($template{ $i } < $min_abundance) { next; } 
        $template2{ $i } = 0; 
    } 

    # get the coverage
    my %sampleProfiles; 
    my $sql = qq{
	select distinct g.gene_oid,
	round(sum(dt.coverage), 7)
        from dt_img_gene_prot_pep_sample dt, gene g
	where dt.sample_oid = ?
	and dt.gene_oid = g.gene_oid
	group by g.gene_oid
    }; 
    foreach my $sample_oid( @sample_oids ) {
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
        my %profile = %template2; 
        for ( ;; ) { 
            my ( $gid, $coverage ) = $cur->fetchrow();
            last if !$gid;
	    next if ( !defined($template2{ $gid }) );
	    next if ( $template{ $gid } < $min_abundance );
            $profile{ $gid } = $coverage;
        } 
        $cur->finish(); 
        $sampleProfiles{ $sample_oid } = \%profile;
    } 

    ## Set up and run cluster
    my $tmpProfileFile = "$tmp_dir/profile$$.tab.txt"; 
    my $tmpClusterRoot = "$tmp_dir/cluster$$"; 
    my $tmpClusterCdt = "$tmp_dir/cluster$$.cdt"; 
    my $tmpClusterGtr = "$tmp_dir/cluster$$.gtr"; 
    my $tmpClusterAtr = "$tmp_dir/cluster$$.atr"; 
 
    my $wfh = newWriteFileHandle( $tmpProfileFile, "printClusterResults" ); 
    my $s = "gene_oid\t"; 
    for my $i( @sample_oids ) { 
        $s .= "$i\t"; 
    } 
    chop $s; 
    print $wfh "$s\n"; 
 
    my @geneIds = sort( keys( %template2 ) ); 
    if (scalar @cart_gene_oids > 0) { 
        @geneIds = @cart_gene_oids; 
    } 
    for my $i( @geneIds ) { 
        print $wfh "$i\t"; 
        my $s; 
        for my $sample_oid( @sample_oids ) { 
            my $profile_ref = $sampleProfiles{ $sample_oid }; 
            my $nsaf = $profile_ref->{ $i };
            #my $nsaf = $profile_ref->{ $i }*10**3; # otherwise hclust fails
            $s .= "$nsaf\t"; 
        } 
        chop $s; 
        print $wfh "$s\n"; 
    } 
    close $wfh; 

    return $tmpProfileFile; 
}

############################################################################
# printPathwaysForSample - list of all pathways for the sample
############################################################################
sub printPathwaysForSample { 
    my @sample_oids = param("exp_samples"); 
    my $nSamples = @sample_oids; 
    my $exp_oid = param("exp_oid"); 
    my $exp_name = param("exp_name"); 
    my $taxon_oid = param("taxon_oid"); 
    my $normalization = "coverage"; 
 
    if ($nSamples < 1) { 
        webError( "Please select 1 sample." ); 
    } 
 
    my $cart_genes = param("describe_cart_genes"); 
    my @cart_gene_oids; 
    if ($cart_genes) { 
        use GeneCartStor; 
        my $gc = new GeneCartStor(); 
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs); 
        if (scalar @cart_gene_oids < 1) { 
            webError( "Your Gene Cart is empty." ); 
        } 
    } 
 
    printStatusLine("Loading ...", 1); 
    my $dbh = dbLogin(); 
 
    my $sql = qq{
        select s.description
        from ms_sample s
        where s.sample_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, @sample_oids[0] ); 
    my ($sample_desc) = $cur->fetchrow(); 
    $cur->finish(); 
 
    print "<h1>Pathways for Sample</h1>"; 
    my $url = "$section_cgi&page=sampledata&sample=@sample_oids[0]"; 
    print "<p>".alink($url, $sample_desc, "_blank"); 
    print "</p>\n"; 
 
    if ($cart_genes && (scalar @cart_gene_oids > 0)) { 
        printHint("The number of genes from gene cart that are found to " 
		. "participate in any given pathway is shown in parentheses.");
        print "<p>*Showing counts for genes from gene cart only</p>"; 
    } else { 
        printHint("The number of genes from this sample that are found to " 
		. "participate in any given pathway is shown in parentheses.");
        print "<br/>"; 
    } 

    # removed module query see cvs version 1.74
    my $sql = qq{
        select distinct pw.pathway_name, pw.image_id, gkmp.gene_oid
        from kegg_pathway pw, dt_img_gene_prot_pep_sample dt, 
             dt_gene_ko_module_pwys gkmp
        where pw.pathway_oid = gkmp.pathway_oid
        and dt.sample_oid = ?
        and dt.gene_oid = gkmp.gene_oid
        order by pw.pathway_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, @sample_oids[0] ); 
 
    my %ids;
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
        foreach my $id (@cart_gene_oids) {
            $ids{ $id } = 1
        }
    }

    my %pathway2count;
    for( ;; ) { 
        my( $pathway_name, $image_id, $gid ) = $cur->fetchrow(); 
        last if !$gid;
        next if ($image_id eq 'map01100');
        if ($cart_genes && (scalar @cart_gene_oids > 0)) {
            next if (!exists $ids{ $gid }) ;
        } 

	my $key2 = $pathway_name."\t".$image_id;
	if ( !defined($pathway2count{ $key2 }) ) {
	    $pathway2count{ $key2 } = 0;
	}
	$pathway2count{ $key2 }++;
    } 
    $cur->finish(); 

    my @pathways = sort keys(%pathway2count);
    my $nPathways = scalar @pathways; 
 
    print qq{
        <table border=0>
        <tr>
        <td nowrap>
    }; 
    foreach my $item(@pathways) {
        my ($p, $im) = split('\t', $item);
        my $count1 = $pathway2count{ $item };
        my $url = "$main_cgi?section=PathwayMaps"
            . "&page=keggMapSamples&map_id=$im"
            . "&study=$study&samples=@sample_oids[0]";
        print alink( $url, $p, "_blank", 0, 1 ) . " ($count1)<br/>\n";
    } 
    print qq{
        </td>
        </tr>
        </table>
        </p>
    }; 
 
    #$dbh->disconnect(); 
    print end_form(); 
    printStatusLine("$nPathways pathways loaded.", 2);
}

############################################################################
# printClusterResults - clusters samples based on the relative abundance 
#                       (NSAF) of the expressed genes.
############################################################################
sub printClusterResults {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids; 
    my $exp_oid = param("exp_oid");
    my $method = param("method");
    my $correlation = param("correlation");
    my $min_abundance = param("min_num");

    if ($nSamples < 2) {
        webError( "Please select at least 2 samples." );
    }
    if ($min_abundance < 3 ||
	$min_abundance > $nSamples) {
	$min_abundance = 3;
    }
 
    my $cart_genes = param("cluster_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) { 
        use GeneCartStor;
        my $gc = new GeneCartStor(); 
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs);
	if (scalar @cart_gene_oids < 1) {
	    webError( "Your Gene Cart is empty." );
	}
    } 

    $correlation =~ /([0-8])/;
    $correlation = $1; 

    $method =~ /([msca])/;
    $method = $1; 

    if ($method eq "") {
	$method = "m";
    }
    if ($correlation eq "") {
	$correlation = 2;
    }

    print "<h1>Cluster Results for Selected Samples</h1>\n";
    print "<p>\n";
    print "Each gene in the heat map is set to appear in "
	. "at least $min_abundance (out of $nSamples) samples.";
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	print "<br/>*Showing only genes from gene cart"; 
    } 
    print "</p>\n";

    printHint
      ("Click on a <font color='blue'><b>sample</b></font> on the left ".
       "to sort the row based on descending coverage values.<br/>\n".
       "Mouse over sample or gene labels to see names, click to see details.<br/>\n".
       "Mouse over parent tree nodes to see distances.<br/>\n".
       "Mouse over heat map to see: <font color='red'>normalized values ".
       "(original values) [sampleid:geneid]</font>.<br/>\n");
    
    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    ## Template 
    my $sample_oid_str = join(',', @sample_oids);
    my $sql = qq{
	select distinct dt.gene_oid, dt.sample_oid
        from dt_img_gene_prot_pep_sample dt
	where dt.sample_oid in ($sample_oid_str)
	order by dt.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %template; 
    for( ;; ) { 
	my( $gid ) = $cur->fetchrow(); 
	last if !$gid;
	if ( !defined($template{ $gid }) ) {
	    $template{ $gid } = 0;
	}
	$template{ $gid }++;
    }
    $cur->finish();

    my %template2;
    my @gids = sort( keys( %template ) ); 
    for my $i( @gids ) { 
        if ($template{ $i } < $min_abundance) { next; } 
	$template2{ $i } = 0;
    }

    my %rowDict; 
    my %sampleNames;

    my $sql = qq{
        select distinct s.sample_oid, s.description 
        from ms_sample s 
	where s.sample_oid in ($sample_oid_str)
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    for( ;; ) {
        my( $sid, $sname ) = $cur->fetchrow();
        last if !$sid; 
        my $surl = "$section_cgi&page=sampledata&sample=$sid"; 
        $rowDict{ $sid } = $sname."\t".$surl;
        $sampleNames{ $sid } = $sname;
    } 
    $cur->finish();

    print "<p>\n"; 

    my $count = 0;
    my %colDict;
    my %origSampleProfiles;

    for my $sample_oid( @sample_oids ) { 
	if ($count == 0) {
	    print "Find profile for <i>sample(s)</i> $sample_oid"; 
	} else {
	    print ", $sample_oid";
	}
	$count++;

	# get the kegg pathways
	my $sql = qq{
	    select distinct gkmp.gene_oid, pw.pathway_name, pw.image_id
	    from kegg_pathway pw, dt_img_gene_prot_pep_sample dt,
                 dt_gene_ko_module_pwys gkmp
	    where pw.pathway_oid = gkmp.pathway_oid
            and dt.sample_oid = ? 
            and dt.gene_oid = gkmp.gene_oid
	    order by gkmp.gene_oid, pw.pathway_name
	};

	my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
	my %done;
	my %gene2pathw;
	for( ;; ) {
	    my( $gene_oid, $pathway_name, $image_id ) = $cur->fetchrow( );
	    last if !$pathway_name;
	    next if $done{ "$gene_oid"."$image_id" };
            if ($template{ $gene_oid } < $min_abundance) { next; }

	    $gene2pathw{$gene_oid} .= $pathway_name.",";
	    $done{ "$gene_oid"."$image_id" } = 1;
	}

	# get coverage
        my $sql = qq{
            select distinct 
                dt.gene_oid, dt.gene_display_name,
		g.locus_tag, round(sum(dt.coverage), 7)
            from dt_img_gene_prot_pep_sample dt, gene g
            where dt.sample_oid = ?
	    and   dt.gene_oid = g.gene_oid
            group by (dt.gene_oid, dt.gene_display_name, g.locus_tag)
        }; 
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );

	my %profile = %template2; 
        for ( ;; ) {
            my ( $gid, $name, $locus_tag, $nsaf ) = $cur->fetchrow();
            last if !$gid; 

	    my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail"
		. "&gene_oid=$gid"; 

	    my $pathwstr = $gene2pathw{ $gid };
	    chop $pathwstr;
	    #$pathwstr = "[".$pathwstr."]" if $pathwstr ne "";
	    if ($template{ $gid } < $min_abundance) { next; }
            $profile{ $gid } = $nsaf; # gene to nsaf mapping
            $colDict{ $gid } = $locus_tag 
		. " [".$name."] [".$pathwstr."]\t".$gurl; 
        } 
        $cur->finish(); 
        $origSampleProfiles{ $sample_oid } = \%profile;
    }
    if ($count > 0) {
	print " ...<br/>\n";
    }
    #$dbh->disconnect();

    ## Set up and run cluster
    my $tmpProfileFile = "$tmp_dir/profile$$.tab.txt";
    my $tmpClusterRoot = "$tmp_dir/cluster$$";
    my $tmpClusterCdt = "$tmp_dir/cluster$$.cdt";
    my $tmpClusterGtr = "$tmp_dir/cluster$$.gtr"; 
    my $tmpClusterAtr = "$tmp_dir/cluster$$.atr"; 
    
    my $wfh = newWriteFileHandle( $tmpProfileFile, "printClusterResults" );
    my $s = "gene_oid\tNAME\t"; 
    my @sample_oids = sort( keys( %origSampleProfiles ) ); 
    for my $i( @sample_oids ) { 
        $s .= "$i\t"; 
    }
    chop $s; 
    print $wfh "$s\n";

    my @geneIds = sort( keys( %template2 ) );
    if ($cart_genes && (scalar @cart_gene_oids > 0)) { 
        @geneIds = @cart_gene_oids; 
    } 
    my $nGenes = @geneIds;

    for my $i( @geneIds ) { 
	my @items = split( /\t/, $colDict{ $i } );
        print $wfh "$i\t" . "$i - $items[0]\t"; 
        my $s; 
	for my $sample_oid( @sample_oids ) { 
	    my $profile_ref = $origSampleProfiles{ $sample_oid }; 
            my $nsaf = $profile_ref->{ $i }; 
            $s .= "$nsaf\t"; 
        } 
        chop $s; 
        print $wfh "$s\n"; 
    } 
    close $wfh; 
    
    my $stateFile = "prot_samples_heatMap$$"; 
    my %sid2Rec; 
    for my $sample_oid( @sample_oids ) { 
        my $url = "$main_cgi?section=$section&page=clusterMapSort";
        $url .= "&stateFile=$stateFile";
        $url .= "&sortId=$sample_oid";

	my @sampleinfo = split(/\t/, $rowDict{ $sample_oid });
	my $highlight = 0; 
	my $r = "$sample_oid\t"; 
	$r .= "$highlight\t"; 
	$r .= "Sort row on coverage of genes found in sample: "
	    . "$sample_oid - ".$sampleinfo[0]."\t";
	$r .= "$url\t"; 
	$sid2Rec{ $sample_oid } = $r; 
    } 
    
    my %gid2Rec;
    for my $gid( @geneIds ) {
        my $url = 
            "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gid";
 
        my $highlight = 0;
        my $r = "$gid\t";
        $r .= "$highlight\t"; 
	$r .= $colDict{ $gid }."\t";
        $r .= "$url\t";
        $gid2Rec{ $gid } = $r;
    } 

    WebUtil::unsetEnvPath(); 
    print "Clustering samples (and genes) ... using log values<br/>\n";
    $correlation = checkPath($correlation);
    $method = checkPath($method);

    runCmd( "$cluster_bin -ng -l "
	  . "-g $correlation -e $correlation -m $method "
	  . "-cg a -ca a "
	  . "-f $tmpProfileFile -u $tmpClusterRoot" );
    WebUtil::resetEnvPath(); 
    print "</p>\n"; 

    # preset the urls for Java TreeView:
    my $gurl = "$cgi_url/$main_cgi?section=GeneDetail"
	. "&amp;page=geneDetail&amp;gene_oid=HEADER";
    my $surl = "$cgi_url/$main_cgi?section=IMGProteins"
	. "&amp;page=sampledata&amp;sample=HEADER"; 

    my $s = "<DocumentConfig>\n"
	."<UrlExtractor urlTemplate='$gurl' index='1' isEnabled='1'/>\n"
	."<ArrayUrlExtractor urlTemplate='$surl' index='0' isEnabled='1'/>\n"
	."</DocumentConfig>";

    my $tmpClusterJtvFile = "$tmp_dir/cluster$$.jtv";
    my $wfh = newWriteFileHandle( $tmpClusterJtvFile, "printClusterResults" );
    print $wfh "$s\n"; 
    close $wfh;

    require DrawTree;
    require DrawTreeNode; 
    my $dt = new DrawTree();

    # display the cluster tree for samples:
    $dt->loadAtrCdtFiles( $tmpClusterAtr, $tmpClusterCdt, \%sid2Rec );
    my $tmpFile = "drawTree$$.png"; 
    my $outPath = "$tmp_dir/$tmpFile"; 
    my $outUrl = "$tmp_url/$tmpFile"; 
    $dt->drawAlignedToFile( $outPath ); 
    my $treemap = $dt->getMap( $outUrl, 0 ); 

    my $rfh = newReadFileHandle( $tmpClusterCdt, "printClusterResults" );
    my $count1 = 0;
    my %normData;
    my %normSampleData;
    my @allSamples;
    my @allGenes;
    while( my $s = $rfh->getline() ) {
	chomp $s; 
	$count1++; 
	if ($count1 == 1) { 
	    @allSamples = split( /\t/, $s ); 
	    splice(@allSamples, 0, 4); # starts with the 4th element
	}

	next if $count1 < 4; 
	my( $idx, $gid, $name, $weightx, $values ) = split( /\t/, $s, 5 ); 
	push( @allGenes, $gid );

	# values are ordered by the allSamples
	$normData{ $gid } = $values; 

	# values of all genes for each sample
	# ordered by @allGenes
        my $x = 0; 
	my $nSamples = @allSamples;
        foreach my $sid (@allSamples) {
            my @geneData = split(/\t/, $values);
            my $cellVal = $geneData[$x]; # coverage
	    if ($cellVal eq "") {
		$cellVal = "undef"; # logged data has empty values
	    }
            $normSampleData{ $sid } .= "$cellVal\t";
            $x++; 
        } 
    } 
    close $rfh; 

    my %normSampleProfiles;
    for my $sid( @allSamples ) { 
        my $values = $normSampleData{ $sid };
        chop $values;
        my @geneData = split(/\t/, $values);

        my %profile; ## = %template2;
        @profile{ @allGenes } = @geneData;
        $normSampleProfiles{ $sid } = \%profile;
    } 

    my $ids = $dt->getIds(); # same as allSamples
    my $state = { 
        geneIds      => \@allGenes, 
        sampleOids   => \@$ids,
        normProfiles => \%normSampleProfiles, 
        origProfiles => \%origSampleProfiles, 
        rowDict      => \%rowDict,
        colDict      => \%colDict,
	treeMap      => $treemap,
	cdtFileName  => "cluster$$",
        stateFile    => $stateFile,
    }; 
    store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );
    printClusterMap($state);
    
    printStatusLine( "Loaded.", 2 );
    printHint("Mouse over heat map to see coverage value ".
	      "of the gene in the given sample.<br/>\n"); 
}

############################################################################
# printClusterMapSort - print the heat map and the sample cluster tree with
#    genes sorted based on descending order of values for the given sample
############################################################################
sub printClusterMapSort {
    my $stateFile = param("stateFile");
    my $sortId = param("sortId");
    my $path = "$cgi_tmp_dir/$stateFile";
    if (!( -e $path )) {
        webError("Your session has expired. Please start over again.");
    }
    webLog "retrieve '$path' " . currDateTime() . "\n"
	if $verbose >= 1;
    my $state = retrieve($path);
    if ( !defined($state) ) {
        webLog("printClusterMapSort: bad state from '$stateFile'\n");
        webError("Your session has expired. Please start over again.");
    }

    my $normProfiles_ref = $state->{normProfiles};
    my $stateFile2       = $state->{stateFile};

    if ( $stateFile2 ne $stateFile ) {
        webLog( "printClusterMapSort: stateFile mismatch "
		. "'$stateFile2' vs. '$stateFile'\n" );
        WebUtil::webExit(-1);
    }
    webLog "retrieved done " . currDateTime() . "\n"
	if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    if ($sortId ne "") {
	my $profile_ref = $normProfiles_ref->{ $sortId }; 
	my %profile = %$profile_ref; 
	my @sortedGenes = sort{ $profile{$b} <=> $profile{$a} } keys %profile; 
	$state->{geneIds} = \@sortedGenes;

	print "<h1>Sorted Cluster Results</h1>";
	print "<p>\n";
	print "Genes are now sorted on coverage values high->low for "
	    . "sample $sortId. <br/>Genes are no longer in clustered order.";
	print "</p>\n";

	printMainForm(); 
	print hiddenVar( "sortId", "" ); 
	print hiddenVar( "stateFile", $stateFile ); 
	my $name = "_section_${section}_clusterMapSort";
	print submit( -name  => $name, 
		      -value => "Restore Original Order",
		      -class => "smdefbutton" );
	print "<br/>\n"; 
	print end_form();

    } else {
        print "<h1>Restored Cluster Results</h1>";
	print "<p>\n";
        print "Genes are again in clustered order."; 
	print "</p>\n";
 
	printHint 
	  ("Click on a <font color='blue'><b>sample</b></font> on the left ".
	   "to sort the row based on descending coverage values.<br/>\n".
	   "Mouse over sample or gene labels to see names, click to see details.<br/>\n".
	   "Mouse over parent tree nodes to see distances.<br/>\n".
	   "Mouse over heat map to see: <font color='red'>normalized values ".
	   "(original values) [sampleid:geneid]</font>.<br/>\n"); 
    }

    printClusterMap($state, $sortId);
    printStatusLine( "Loaded.", 2 );
}

############################################################################ 
# printClusterMap - print the heat map and the sample cluster tree
############################################################################ 
sub printClusterMap {
    my ($state, $sortId) = @_;
    my $geneIds_ref      = $state->{geneIds};   
    my $sampleOids_ref   = $state->{sampleOids};
    my $normProfiles_ref = $state->{normProfiles};   
    my $origProfiles_ref = $state->{origProfiles};
    my $rowDict_ref      = $state->{rowDict};
    my $colDict_ref      = $state->{colDict}; 
    my $treemap          = $state->{treeMap};
    my $cdtFileName      = $state->{cdtFileName};
    my $stateFile        = $state->{stateFile};

    my @allGenes = @$geneIds_ref;
    my $nGenes = @allGenes;

    if ($sortId eq "") {
	# call the Java TreeView applet: 
	my $archive = "$base_url/TreeViewApplet.jar," 
	             ."$base_url/nanoxml-2.2.2.jar," 
	             ."$base_url/Dendrogram.jar"; 
	print qq{ 
	    <APPLET code="edu/stanford/genetics/treeview/applet/ButtonApplet.class"
		archive="$archive" 
		width='250' height='50'>
	    <PARAM name="cdtFile" value="$tmp_url/$cdtFileName.cdt">
	    <PARAM name="cdtName" value="with Java TreeView">
	    <PARAM name="jtvFile" value="$tmp_url/$cdtFileName.jtv">
	    <PARAM name="styleName" value="linked">
	    <PARAM name="plugins" value="edu.stanford.genetics.treeview.plugin.dendroview.DendrogramFactory"> 
	    </APPLET> 
	}; 
    }

    my $idx = 0;
    my $count = 0;
    print "<table border='0'>\n"; 
    while ($idx < $nGenes) {
        $count++;
        my $max = $batch_size + $idx; 
        if ($max > $nGenes) {
            $max = $nGenes; 
        } 
        my @genes = @allGenes[$idx..($max - 1)]; 

        my %table;
        for my $sid (@$sampleOids_ref) {
            my $profile = $origProfiles_ref->{ $sid };
            my $s;
            for my $gid (@genes) {
                my $cellVal = $profile->{ $gid }; # coverage
                $s .= "$cellVal\t";
            } 
            chop $s;
            $table{ $sid } = $s;
        }
        
        my %normalizedTable;
        foreach my $sid (@$sampleOids_ref) {
            my $profile = $normProfiles_ref->{ $sid };
            my $s;
            for my $gid (@genes) {
                my $cellVal = $profile->{ $gid }; # coverage
                $s .= "$cellVal\t";
            } 
            chop $s;
            $normalizedTable{ $sid } = $s;   # with normalized values
        }
        
        my $stateFile = "prot_samples_${count}_heatMap$$"; 
	if ($sortId ne "") {
	    $stateFile = $stateFile. "_${sortId}";
	}

        my $state = { 
            geneIds    => \@genes, 
            normTable  => \%normalizedTable, 
            table      => \%table, 
            sampleOids => \@$sampleOids_ref,
            rowDict    => \%$rowDict_ref,
            colDict    => \%$colDict_ref,
            stateFile  => $stateFile,
        }; 
        store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );
        
        print "<tr>\n";
        print "<td valign='top'>\n"; 
        print "$treemap\n"; 
        print "</td>\n"; 
        print "<td valign='top'>\n"; 
        printHeatMapSection($count, $idx, $state);
        print "</td>\n";
        print "</tr>\n"; 

        $idx = $idx + $batch_size;
    }
    print "</table>\n"; 
}

############################################################################ 
# printHeatMapSection - Generates one heat map section.
############################################################################ 
sub printHeatMapSection { 
    my ($cntId, $idx, $state) = @_; 

    my $geneIds_ref    = $state->{geneIds}; 
    my $normTable_ref  = $state->{normTable}; 
    my $table_ref      = $state->{table}; 
    my $sampleOids_ref = $state->{sampleOids}; 
    my $rowDict_ref    = $state->{rowDict}; 
    my $colDict_ref    = $state->{colDict}; 
    my $stateFile      = $state->{stateFile}; 

    my $id      = "${cntId}_prot_samples_heatMap$$"; 
    my $outFile = "$tmp_dir/$id.png"; 
    my $n_rows  = @$sampleOids_ref; 
    my $n_cols  = @$geneIds_ref; 

    my $args = { 
	id         => $id, 
	n_rows     => $n_rows, 
	n_cols     => $n_cols, 
	image_file => $outFile, 
	taxon_aref => $sampleOids_ref,
	use_colors => "all"
    }; 
    my $hm = new ProfileHeatMap($args);
    my $html = 
	$hm->drawSpecial
	( $table_ref, $sampleOids_ref, $geneIds_ref, $rowDict_ref, 
	  $colDict_ref, $normTable_ref, $stateFile ); 
    $hm->printToFile(); 
    print "$html\n"; 
} 

############################################################################
# printGeneMainFaa - prints the amino acid sequence for the specified gene,
#                    highlighting the specified peptides in red
############################################################################
sub printGeneMainFaa { 
    my ($dbh, $gene_oid, $peptides, $peptide_ids) = @_; 

    printHint("<font color='red'>red</font> "
	    . "indicates alignment of peptide on gene.<br/>");

    my $sql = qq{ 
        select g.gene_oid, g.gene_display_name,
	       g.protein_seq_accid, g.aa_residue, scf.scaffold_name 
	from  gene g, taxon tx, scaffold scf 
	where g.gene_oid = ?
	and g.taxon = tx.taxon_oid 
	and g.scaffold = scf.scaffold_oid 
	and g.aa_residue is not null 
	and g.aa_seq_length > 0 
    }; 

    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid ); 
    for( ;; ) { 
	my( $gene_oid, $gene_display_name,
	    $protein_seq_accid, $aa_residue, $scaffold_name )
	    = $cur->fetchrow(); 
	last if !$gene_oid; 

        my $url = 
            "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene_oid"; 

	my $ids; 
	$ids .= "$protein_seq_accid " if !blankStr( $protein_seq_accid ); 
	print "<pre>\n"; 
	print "<font color='blue'>"; 
	print ">Gene: ".alink($url, $gene_oid)
	    ." $ids$gene_display_name <br/> [$scaffold_name]"; 
	print "</font>\n"; 
	print "</pre>\n"; 

	showPeptideAlignments($gene_oid, $aa_residue, $peptides, $peptide_ids);
    } 
    $cur->finish(); 
} 

sub showPeptideAlignments { 
    my ($gene_oid, $aa_residue, $peptides, $peptide_ids) = @_; 
 
    print qq{ 
        <script language='JavaScript' type='text/javascript'>
        function showView(type) {
	if (type == 'graphical') {
	    document.getElementById('sequenceView').style.display = 'none';
	    document.getElementById('graphicalView').style.display = 'block';
	} else { 
	    document.getElementById('sequenceView').style.display = 'block';
	    document.getElementById('graphicalView').style.display = 'none';
	} 
        } 
        </script> 
    };
 
    print "<div id='sequenceView' style='display: block;'>";
    writeDiv("sequence", $gene_oid, $aa_residue, $peptides, $peptide_ids); 
    print "</div>\n";
 
    print "<div id='graphicalView' style='display: none;'>"; 
    writeDiv("graphical", $gene_oid, $aa_residue, $peptides, $peptide_ids); 
    print "</div>\n"; 
}

sub writeDiv {
    my ($which, $gene_oid, $aa_residue, $peptides, $peptide_ids) = @_;

    if ($which eq "sequence") { 
	print "<input type='button' class='medbutton' name='view'" 
	    . " value='Graphical View'" 
	    . " onclick='showView(\"graphical\")' />"; 
	print "<pre>\n"; 
	printSequence($aa_residue, $peptides);
	print "</pre>\n"; 
    } elsif ($which eq "graphical") { 
	print "<input type='button' class='medbutton' name='view'"
	    . " value='Sequence View'"
	    . " onclick='showView(\"sequence\")' />";
	print "<br/>";
	printGraphicalSequence
	    ($gene_oid, $aa_residue, $peptides, $peptide_ids);
	print "<br/>";
    } 
}

############################################################################
# printSequence - prints the specified amino acid sequence, in chunks of 
# 10aa, with 5 chunks per line, highlighting the specified peptides in red
############################################################################
sub printSequence {
    my ($seq, $peptides_ref) = @_;
    my @peptides = @$peptides_ref;
    my $seq_len = length( $seq );
    my @seqarray = split( //, $seq );

    my $i = 0;
    while ( $i < $seq_len ) {
	if ($i % 50 == 0) {
	    if ($i > 0) {
		print "\n";
	    } 
	} elsif ($i % 10 == 0) {
	    print " ";
	}
	my $size = 0;
	my $mypeptide;
	for my $peptide (@peptides) {
	    my $plen = length( $peptide );
	    my $str = substr( $seq, $i, $plen );
	    if ( $str eq $peptide ) {
		if ($size < $plen) {
		    $size = $plen;
		    $mypeptide = $peptide;
		}
	    }
	}
	if ( $size > 0 ) {
	    my @peptidearray = split( //, $mypeptide);
	    print "<font color='red'>";
	    for (my $j=0; $j<$size; $j++) {
		if ($j > 0) {
		    if ($i % 50 == 0) {
			if ($i > 0) {
			    print "\n";
			}
		    } elsif ($i % 10 == 0) {
			print " ";
		    }
	        }
		print $peptidearray[$j];
		$i++;
	    }
	    print "</font>";
	} else {
	    print $seqarray[$i];
	    $i++;
	}
    }
}

############################################################################
# printGraphicalSequence - prints the specified amino acid sequence,
# in graphical view, showing peptide alignments
############################################################################
sub printGraphicalSequence { 
    my ($gene_oid, $seq, $peptides_ref, $peptide_ids_ref) = @_; 
    my @peptides = @$peptides_ref; 
    my @peptide_ids = @$peptide_ids_ref;
    my $seq_len = length( $seq ); 

    my $start;
    my $end;
    my @recs; 
    my $i = 0;
    while ( $i < $seq_len ) {
	my $idx = 0;
	for my $peptide (@peptides) {
	    my $plen = length( $peptide );
	    my $str = substr( $seq, $i, $plen );
	    if ( $str eq $peptide ) {
		my $start = $i;
		my $end = $i + $plen - 1;

		my $r;
		$r .= $peptide_ids[$idx]."\t"; 
		$r .= "$peptide\t"; 
		$r .= "$start\t"; 
		$r .= "$end\t"; 
		push( @recs, $r ); 
	    }
	    $idx++;
	}
	$i++;
    }

    my $n = @recs;
    my $vert_spacing = 14;
    my $y = $vert_spacing;
    my $total_height = $vert_spacing * ($n + 3);
    my $total_width = 720; #820;
    my $im = new GD::Image( $total_width, $total_height );

    my $white = $im->colorAllocate( 255, 255, 255 );
    my $black = $im->colorAllocate( 0, 0, 0 );
    my $blue = $im->colorAllocate( 0, 0, 170 );
    my $red = $im->colorAllocate( 255, 0, 0 );
    my $yellow = $im->colorAllocate( 255, 255, 192 );

    $im->transparent( $white );
    $im->interlaced( 'true' );

    my $x_offset = 10;
    my $graph_width = 500; #600;
    my $graph_y_offset = 5;
    my $text_x_start = 520; #620;

    my @id_ys;
    my @lineCoords;

    ## Query gene
    my $w = 1.0 * $graph_width;
    my $x1 = $x_offset;
    my $x2 = $w + $x_offset;
    my $y2 = $y + $graph_y_offset;
    my $y1a = $y2 - 0.5;
    my $y2a = $y2 + 0.5;
    $im->filledRectangle( $x1, $y1a, $x2, $y2a, $blue );
    $im->string( gdSmallFont, $text_x_start, $y, "Gene ($gene_oid)", $blue );
    my $id = "gene_oid=$gene_oid";
    push( @id_ys, "$y\t$id" );
    my $y1b = $y2-3;
    my $y2b = $y2+3;
    my $r = "$x1\t$y1b\t$x2\t$y2b\t$id\t\t\t";
    push( @lineCoords, $r );

    ## Hits
    for my $r( @recs ) {
        $y += $vert_spacing;
        my( $id, $name, $query_start, $query_end ) = split( /\t/, $r );
        my $y2 = $y + $graph_y_offset;
        my $x1 = $x_offset + ( ( $query_start / $seq_len ) * $graph_width );
        my $x2 = $x_offset + ( ( $query_end / $seq_len ) * $graph_width );
        my $color = $red;
        my $y1a = $y2 - 0.5;
        my $y2a = $y2 + 0.5;
        my $y1b = $y2-3;
        my $y2b = $y2+3;
        $im->filledRectangle( $x1, $y1a, $x2, $y2a, $color );
        my $r = "$x1\t$y1b\t$x2\t$y2b\t$id\t$name";
        push( @lineCoords, $r );

        my $label = "$id";
	if ($name ne "" && length($name) < 22) {
	    $label .= " - $name";
	} elsif ($name ne "") {
	    $label .= " - ".substr($name, 0, 20);
	    $label .= "...";
	}
        $im->string( gdSmallFont, $text_x_start, $y, $label, $red );
        push( @id_ys, "$y\t$id\t$name" );
    }

    my $map;
    for my $i( @lineCoords ) {
       my( $x1, $y1, $x2, $y2, $id, $name ) = split( /\t/, $i );
       $map .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' "; 
       $map .= "title='$name ($id)'>\n";
    }
    for my $i( @id_ys ) {
	my( $y, $id, $desc ) = split( /\t/, $i );
	my $x1 = $text_x_start;
	my $y1 = $y;
	my $x2 = $x1 + 200;
	my $y2 = $y1 + 10;

	$map .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
	$map .= "title='$desc ($id)'>\n";
    }

    my $imageFile = "$gene_oid.$$.peptides.png";
    my $tmpOutFile = "$tmp_dir/$imageFile";
    my $tmpOutUrl = "$tmp_url/$imageFile";
    wunlink( $tmpOutFile );

    my $wfh = newWriteFileHandle( $tmpOutFile, "printGraphicalSequence" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    my $height = $total_height;
    if ($total_height > 200) {
	$height = 200;
    }

    print "<div class='scroll-body'
            style='height: $height"."px; 
                   width: 750px; overflow: auto; 
                   border: 2px solid #99CCFF;'>";
    print "<image src='$tmpOutUrl' usemap='#peptidesmap' border='0' />\n";
    print "<map name='peptidesmap'>\n";
    print $map;
    print "</map>\n";
    print "</div>\n";
}
 
sub expClause {
    my ($alias) = @_;
 
    return "" if !$user_restricted_site;
    my $super_user = getSuperUser();
    return "" if ( $super_user eq "Yes" );
    my $contact_oid = getContactOid();
    return "" if !$contact_oid;
 
    my $exp_oid_attr = "exp_oid";
    $exp_oid_attr = "$alias.exp_oid"
        if $alias ne ""
        && $alias ne "exp_oid"
        && $alias !~ /\./;
 
    $exp_oid_attr = $alias
        if $alias ne ""
        && $alias ne "exp_oid" 
        && $alias =~ /\./; 
 
    my $clause = qq{ 
        and $exp_oid_attr in 
            ( select exp.exp_oid 
              from ms_experiment exp 
              where exp.is_public = 'Yes' 
              union all 
              select cpp.protexp_permissions 
              from contact_protexp_permissions cpp 
              where cpp.contact_oid = $contact_oid 
            ) 
        }; 
 
    return $clause; 
} 

1;

