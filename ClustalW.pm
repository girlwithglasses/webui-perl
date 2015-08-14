############################################################################
# Run clustalw alignment and show direct results, results postprocessed
#   using secondary tools.  This is the perl wrapper for handling
#   the display forms pertaining to CLUSTAL W alignments.
#    --es 10/22/2004
#  $Id: ClustalW.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package ClustalW;

require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    loadGeneRec
    loadSeq
    writeSeq
    readAlnFile
    readDndFile
    printGeneRec
    printJalView
);

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use DistanceTree;
use DrawTree;
use MetaUtil;
use Time::localtime;
use GeneUtil;

$| = 1;
my $section = "ClustalW";
my $env = getEnv();
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $section_cgi = "$main_cgi?section=$section";
my $clustalw_bin = $env->{ clustalw_bin };
my $clustalo_bin = $env->{ clustalo_bin };
my $base_url = $env->{ base_url };
my $tmp_url = $env->{ tmp_url };
my $tmp_dir = $env->{ tmp_dir };
my $taxon_lin_fna_dir = $env->{ taxon_lin_fna_dir };
my $printDndTree_bin = $env->{ printDndTree_bin };
my $graphDndTree_bin = $env->{ graphDndTree_bin };
my $max_genes = 500;
my $max_genes_nuc = 200;
my $verbose = $env->{ verbose };
my $use_clustal_omega = 1;
my $YUI = $env->{yui_dir_28};


############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );
    timeout( 60 * 40 );    # timeout in 40 minutes (from main.pl)

    if ( $page eq "runClustalW" ||
	paramMatch( "runClustalW" ) ne "" ) {

	my $clustalref = "ClustalW";
	$clustalref = "Clustal Omega" if $use_clustal_omega;

	my $alignment =  param( "alignment" );
	my $type = "Protein";
	$type = "DNA" if ($alignment eq "nucleic");

	my $title = "$clustalref - $type Alignment of Selected Genes";
	my $help = "DistanceTree.pdf#page=6";

	my $url =
	"http://bioinformatics.oxfordjournals.org/cgi/content/abstract/btp033";
	my $text = "<a href=$url target=_blank>Jalview</a> ";
	$text .= "is a multiple alignment editor written in Java.<br/>";

	my $url = "http://www.clustal.org/clustal2/";
	$text .= "Sequence Alignment is perfomed using ";
	$text .= "<a href=$url target=_blank>$clustalref</a>.<br/>";

	my $url = "http://www.phylosoft.org/archaeopteryx/";
	$text .= "The phylogenetic tree is generated using the ";
	$text .= "<a href=$url target=_blank>Archaeopteryx</a> applet.";


	WebUtil::printHeaderWithInfo
	($title, $text, "show citations", "Citations", "", $help, "", "java");

	my( @gene_oids ) = param( "gene_oid" );
        runClustalw(\@gene_oids, $alignment);
    }
}

############################################################################
# runClustalw - Run clustalw to show text alignments, start JalView
############################################################################
sub runClustalw {
    my ($genes, $alignment) = @_;
    my @gene_oids = @$genes;
    my $nGenes = @gene_oids;

    if ($nGenes < 2) {
	webError( "Please select at least 2 genes for alignment." );
    }
    if ($alignment eq "nucleic" &&
	$nGenes > $max_genes_nuc) {    # depends on alignment
	webError( "Please select no more than $max_genes_nuc genes " .
		  "for DNA alignment." );
    } else {
	if ( $nGenes > $max_genes ) {
	    webError( "Please select no more than $max_genes genes " .
		      "for protein alignment." );
	}
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my %geneRec;
    my %gene2Seq;
    my $gene_oid_str = join( ',', @gene_oids );
    loadGeneRec( $dbh, $gene_oid_str, \%geneRec );

    # Clustalw cannot handle long file paths
    # Need to go to the "current" directory
    chdir( $tmp_dir );
    my $tmpFastaFile = "genes$$.fa";
    my $tmpFastaDndFile = "genes$$.dnd";
    my $tmpDndFile = "clustalw$$.dnd";

    my $tmpAlnFile = "clustalw$$.aln"; # clustal format
    my $tmpStdOut = "clustalw$$.stdout";

    my $tmpFastaFile2 = "gids$$.fa";
    my $tmpFastaDndFile2 = "gids$$.dnd";

    # for PHYLIP format, the name/id MUST be exactly 10 chars long
    my $tmpPhyFile = "clustalw$$.phy"; # phylip format
    my $tmpStdOut2 = "clustalw_phy$$.stdout";

    if ($alignment eq "nucleic") {
	printClustalAlignFnaSeq( "$tmp_dir/$tmpFastaFile" );
	printClustalAlignFnaSeq( "$tmp_dir/$tmpFastaFile2", 1 );
    } else {
	loadSeq( $dbh, $gene_oid_str, \%gene2Seq );
	writeSeq( \@gene_oids, \%gene2Seq, \%geneRec,
		  "$tmp_dir/$tmpFastaFile" );
	writeSeq( \@gene_oids, \%gene2Seq, \%geneRec,
		  "$tmp_dir/$tmpFastaFile2", 1 );
    }

    printStartWorkingDiv();
    $clustalo_bin = "clustalo";

    my $cmd1; my $cmd2;
    if ($use_clustal_omega) {
	$cmd1 = "$clustalo_bin "
	    . "--infile=$tmpFastaFile "
	    . "--outfmt=clustal --outfile=$tmpAlnFile";
	$cmd2 = "$clustalo_bin "
	    . "--infile=$tmpFastaFile2 "
	    . "--outfmt=phylip --outfile=$tmpPhyFile";
    } else {
	$cmd1 = "$clustalw_bin "
	    . "-INFILE=$tmpFastaFile "
	    . "-OUTPUT=CLUSTAL > $tmpStdOut";
	$cmd2 = "$clustalw_bin "
	    . "-INFILE=$tmpFastaFile2 "
	    . "-OUTPUT=PHYLIP > $tmpStdOut2";
    }

    my $time0 = localtime->min();
    WebUtil::unsetEnvPath();

    print "<p>running CLUSTAL 1... $cmd1<br/>\n";
    webLog("$cmd1\n");
    my $st = system( $cmd1 );
    print "running CLUSTAL 2... $cmd2 <br/>\n";
    webLog("$cmd2\n");
    my $st2 = system( $cmd2 );

    WebUtil::resetEnvPath();
    print "<br/>done CLUSTAL";
    my $time1 = localtime->min();

    if ( $st != 0 ) {
	webLog( "runClustalw: system($cmd1) error: $st\n" );
    }

    if (!$use_clustal_omega) {
	print "<br/>reading ALN...";
	$tmpAlnFile = readAlnFile( $tmpStdOut );
	print "<br/>reading PHY...";
	$tmpPhyFile = readPhyFile( $tmpStdOut2 );
	$tmpDndFile = readDndFile( $tmpStdOut );
	webLog "tmpDndFile='$tmpDndFile'\n" if $verbose >= 1;
    }

    webLog "tmpAlnFile='$tmpAlnFile'\n" if $verbose >= 1;
    if ( !( -r $tmpAlnFile ) ) {
	#$dbh->disconnect();
	printEndWorkingDiv();
	webError( "Clustal cannot align sequences." );
    }

    printEndWorkingDiv();
    #print "<br/>computed in ".($time1 - $time0)." minutes";

    $tmpAlnFile = checkPath( $tmpAlnFile );
    $tmpPhyFile = checkPath( $tmpPhyFile );

    printMainForm();

    use TabHTML;
    TabHTML::printTabAPILinks("alignmentTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("alignmentTab");
        </script>
    };

    my @tabIndex = ( "#aligntab1", "#aligntab2", "#aligntab3" );
    my @tabNames = ( "Jalview Alignment",
                     "Analyzed Genes",
                     "Phylogenetic Tree" );

    TabHTML::printTabDiv("alignmentTab", \@tabIndex, \@tabNames);
    print "<div id='aligntab1'>";
    print "<h2>Jalview Alignment</h2>";
    printJalView( $tmpAlnFile, $nGenes, $alignment );
    print "</div>"; # end aligntab1

    print "<div id='aligntab2'>";
    print "<h2>Analyzed Genes</h2>";
    printShowGeneTable( \%geneRec );
    print "</div>"; # end aligntab2

    print "<div id='aligntab3'>";
    print "<h2>Phylogenetic Tree</h2>";

    # must have at least 3 items for a neighbor-joining run:
    if ($nGenes < 3) {
	printStatusLine( "$nGenes genes analyzed.", 2 );
	webError( "Must have at least 3 items for a neighbor-joining run." );
    }

    ### run PHYLIP's PROTDIST to get distance data ###
    my $distanceFile = "dist_matrix$$.txt";
    my $tmpDir = $cgi_tmp_dir."/protdist$$";
    my $logFile = "$tmpDir/logfile";

    WebUtil::unsetEnvPath();
    runCmd( "/bin/mkdir -p $tmpDir" );
    runCmd( "/bin/cp $tmpPhyFile $tmpDir/infile" );
    runCmd( "/bin/chmod 777 $tmpDir" );

    printStartWorkingDiv("working2");
    print "running PROTDIST...";

    chdir( $tmpDir );
    my $protdist_bin = $env->{protdist_bin};
    my $cmd = "/bin/echo Y | $protdist_bin > logfile";
    my $st = system( $cmd );
    chdir( $tmp_dir );

    if ($st == 0) {
	runCmd( "/bin/cp $tmpDir/outfile $distanceFile" );
    }
    runCmd( "/bin/rm -fr $tmpDir" );

    ### run PHYLIP's neighbor program ###
    my $newickFile = "newick$$.txt";
    my $tmpDir = $cgi_tmp_dir."/neighbor$$";
    my $logFile = "$tmpDir/logfile";

    runCmd( "/bin/mkdir -p $tmpDir" );
    runCmd( "/bin/cp $distanceFile $tmpDir/infile" );
    runCmd( "/bin/chmod 777 $tmpDir" );

    print "<br/>running NEIGHBOR...";

    chdir( $tmpDir );
    my $neighbor_bin = $env->{neighbor_bin};
    my $cmd = "/bin/echo Y | $neighbor_bin > logfile";
    my $st = system( $cmd );
    chdir( $tmp_dir );
    print "<br/>newick done";

    if ($st == 0) {
        # version 3.69 of neighbor seems to have renamed
        # the output file previously called outtree to treefile
        if (-e "$tmpDir/outtree") {
            runCmd( "/bin/cp $tmpDir/outtree $newickFile" );
        }
        elsif (-e "$tmpDir/treefile") {
            runCmd( "/bin/cp $tmpDir/treefile $newickFile" );
        }
    }
    runCmd( "/bin/rm -fr $tmpDir" );

    WebUtil::resetEnvPath();

    my %gid2Rec;
    loadDomainsRec( $dbh, $gene_oid_str, \%gid2Rec, $alignment );
    #$dbh->disconnect();
    print "<br/>domains loaded";

    my $newick = file2Str($newickFile);
    if ( blankStr($newick) ) {
	webError("Invalid newick '$newick' string.\n");
    }

    my %hash = ();   # placeholder
    my $dt = new DrawTree( $newick, \%hash, \%gid2Rec );

    my $xmlFile = "treeXML$$.txt";
    $dt->toPhyloXML( $xmlFile );
    print "<br/>phyloXML done";
    printEndWorkingDiv("working2");

    if ( $alignment eq "nucleic" ) {
	DistanceTree::printAptxApplet("treeXML$$.txt", "genes");
    } else {
	DistanceTree::printAptxApplet("treeXML$$.txt", "domains");
    }
    print "</div>"; # end aligntab3
    TabHTML::printTabDivEnd();

    print end_form();
    printStatusLine( "$nGenes genes analyzed.", 2 );

    wunlink( $tmpFastaFile );
    wunlink( $tmpFastaFile2 );
    wunlink( $tmpFastaDndFile );
    wunlink( $tmpFastaDndFile2 );
}

############################################################################
# loadDomainsRec - Load associated gene record information for phyloXML.
############################################################################
sub loadDomainsRec {
    my( $dbh, $gene_oid_str, $gid2rec_ref, $alignment ) = @_;

    my @gene_oids = split(/\,/, $gene_oid_str);
    my @db_genes = ();
    my @fs_genes = ();
    for my $gene_oid ( @gene_oids ) {
	if ( isInt($gene_oid) ) {
	    push @db_genes, ( $gene_oid );
	} else {
	    push @fs_genes, ( $gene_oid );
	}
    }

    my $db_gene_oid_str = "";
    if ( scalar(@db_genes) > 0 ) {
	$db_gene_oid_str = join(",", @db_genes);

	# load gene information:
	# instead use g.protein_seq_accid
	my $sql = qq{
            select g.gene_oid, g.locus_tag, g.gene_display_name,
	       tx.taxon_oid, tx.taxon_display_name,
	       tx.domain, tx.phylum, tx.ir_class,
	       tx.ir_order, tx.family, tx.genus,
	       g.dna_seq_length, g.aa_seq_length,
	       g.start_coord, g.end_coord, g.strand,
	       scf.ext_accession
	    from gene g, scaffold scf, taxon tx
            where g.scaffold = scf.scaffold_oid
	    and g.taxon = tx.taxon_oid
	    and g.gene_oid in( $db_gene_oid_str )
	    and g.start_coord > 0
	    and g.end_coord > 0
	    order by g.gene_oid
        };

	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $locus_tag, $gene_display_name,
		$taxon_oid, $taxon_display_name, $domain,
		$phylum, $class, $order, $family, $genus,
		$dna_seq_length, $aa_seq_length,
		$start_coord0, $end_coord0, $strand,
		$ext_accession ) = $cur->fetchrow();
	    last if !$gene_oid;

            # only alphanumeric chars allowed
	    $gene_display_name =~ s/[^\w]/_/g;
	    $domain =~ s/[^\w]/_/g;
	    $phylum =~ s/[^\w]/_/g;
	    $class  =~ s/[^\w]/_/g;
	    $order  =~ s/[^\w]/_/g;
	    $family =~ s/[^\w]/_/g;
	    $genus  =~ s/[^\w]/_/g;

	    my $url = "$main_cgi?section=GeneDetail"
		    . "&page=geneDetail&gene_oid=$gene_oid";
	    my $code = uc(substr($class, 0, 10));
	    my $lineage = "$domain,$phylum,$class,$order,$family,$genus";

	    $gene_display_name =~ s/:/-/g;
	    $taxon_display_name =~ s/:/-/g;
	    my $r = "$lineage:$code:$gene_oid:$gene_display_name"
		  . ":$taxon_oid:$taxon_display_name:$locus_tag"
		  . ":$dna_seq_length:$aa_seq_length"
		  . ":$start_coord0:$end_coord0:$ext_accession"."\t";
	    $r .= $url."\t";
	    $gid2rec_ref->{ $gene_oid } = $r;
	}
	$cur->finish();
    }

    my %taxon_info_h;
    if ( scalar(@fs_genes) > 0 ) {
	# MER-FS
	for my $gid (@fs_genes) {
	    my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $gid);

	    my ($gene_oid2, $locus_type, $locus_tag, $gene_display_name,
		$start_coord0, $end_coord0, $strand, $ext_accession) =
		    MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
	    my $dna_seq_length = $end_coord0 - $start_coord0 + 1;
	    if ( $start_coord0 > $end_coord0 ) {
		$dna_seq_length = $start_coord0 - $end_coord0 + 1;
	    }
	    my $seq2 = MetaUtil::getGeneFaa($gene_oid, $taxon_oid, $data_type);
	    $seq2 =~ s/\s+//g;
	    #$seq2 =~ s/\*//g;
	    my $aa_seq_length = length($seq2);

	    my $domain = "";
	    my $phylum = "";
	    my $class = "";
	    my $order = "";
	    my $family = "";
	    my $genus = "";
	    my $taxon_display_name = "";

	    if ( $taxon_info_h{$taxon_oid} ) {
		($domain, $phylum, $class, $order, $family, $genus,
		 $taxon_display_name) = split(/\t/, $taxon_info_h{$taxon_oid});
	    } else {
		my $sql =qq{
                    select domain, phylum, ir_class, ir_order,
                           family, genus, taxon_display_name
                      from taxon where taxon_oid = ?
                };

		my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
		($domain, $phylum, $class, $order, $family, $genus,
		 $taxon_display_name) = $cur->fetchrow();
		$cur->finish();
		$taxon_info_h{$taxon_oid} =
		    "$domain\t$phylum\t$class\t$order\t" .
		    "$family\t$genus\t$taxon_display_name";
	    }

	    if ( ! $class ) {
		$class = "Unclassified";
	    }
	    if ( ! $gene_display_name ) {
    		my ($gene_prod_name, $prod_src) =
		    MetaUtil::getGeneProdNameSource
		    ($gene_oid, $taxon_oid, $data_type);
    		$gene_display_name = $gene_prod_name;
	    }

	    # only alphanumeric chars allowed
	    $gene_display_name =~ s/[^\w]/_/g;
	    $domain =~ s/[^\w]/_/g;
	    $phylum =~ s/[^\w]/_/g;
	    $class  =~ s/[^\w]/_/g;
	    $order  =~ s/[^\w]/_/g;
	    $family =~ s/[^\w]/_/g;
	    $genus  =~ s/[^\w]/_/g;

	    $gene_display_name =~ s/:/-/g;
	    $taxon_display_name =~ s/:/-/g;

	    my @ids = split(/ /, $gid);
	    my $fullgid = $ids[0] ."-". $ids[1] ."-". $ids[2];
	    my $url = "$main_cgi?section=MetaGeneDetail"
		    . "&page=metaGeneDetail&gene_oid=$fullgid";
	    my $code = uc(substr($class, 0, 10));
	    $code = uc(substr($order.$family, 0, 10)) if $code eq "";
	    my $lineage = "$domain,$phylum,$class,$order,$family,$genus";

	    my $new_id = convertGeneOid($gene_oid);
	    my $r = "$lineage:$code:$gene_oid:$gene_display_name"
		  . ":$taxon_oid:$taxon_display_name:$locus_tag"
		  . ":$dna_seq_length:$aa_seq_length"
		  . ":$start_coord0:$end_coord0:$ext_accession"."\t";
	    $r .= $url."\t";
	    $gid2rec_ref->{ $new_id } = $r;
	}
    }

    if ( $alignment eq "nucleic" ) {
	return;
    }

    # load signal peptide domains:
    if ( $db_gene_oid_str ) {
	my $sql = qq{
	    select gsp.gene_oid, gsp.feature_type,
	       gsp.start_coord, gsp.end_coord
	    from gene_sig_peptides gsp
	    where gsp.gene_oid in ($db_gene_oid_str)
	    order by gsp.gene_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $feature,
		$start_coord, $end_coord ) = $cur->fetchrow();
	    last if !$gene_oid;

	    my $r = $gid2rec_ref->{ $gene_oid };
	    $r .= "SP:SP[$feature]".":$start_coord:$end_coord"."\t";
	    $gid2rec_ref->{ $gene_oid } = $r;
	}
	$cur->finish();

	# load transmembrane helices domains:
	my $sql = qq{
	   select gth.gene_oid, gth.feature_type,
               gth.start_coord, gth.end_coord
           from gene_tmhmm_hits gth
           where gth.gene_oid in ($db_gene_oid_str)
	   order by gth.gene_oid
           };
	$cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $feature,
		$start_coord, $end_coord ) = $cur->fetchrow();
	    last if !$gene_oid;

	    my $r = $gid2rec_ref->{ $gene_oid };
	    $r .= "TMH:TMH[$feature]".":$start_coord:$end_coord"."\t";
	    $gid2rec_ref->{ $gene_oid } = $r;
	}
	$cur->finish();

	# load COG domains:
	my $sql = qq{
           select distinct gcg.gene_oid,
              c.cog_id, c.cog_name,
              cf.function_code, cf.definition,
              gcg.query_start, gcg.query_end
            from cog_function cf, cog_functions cfs,
	      cog c, gene_cog_groups gcg
            where cf.function_code = cfs.functions
            and cfs.cog_id = c.cog_id
            and c.cog_id = gcg.cog
            and gcg.gene_oid in ($db_gene_oid_str)
            order by gcg.gene_oid, c.cog_id, gcg.query_start
            };
	$cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $cog_id, $cog_name, $fn_code, $fn_def,
		$q_start, $q_end ) = $cur->fetchrow();
	    last if !$gene_oid;

	    my $r = $gid2rec_ref->{ $gene_oid };
	    $r .= "COG:$cog_id"."[$fn_code]".":$q_start:$q_end"."\t";
	    $gid2rec_ref->{ $gene_oid } = $r;
	}
	$cur->finish();

	# load PFAM domains:
	my $sql = qq{
            select distinct gpf.gene_oid,
              pf.ext_accession, pf.name, pf.description,
              gpf.query_start, gpf.query_end
            from pfam_family pf, gene_pfam_families gpf
            where pf.ext_accession = gpf.pfam_family
            and gpf.gene_oid in ($db_gene_oid_str)
            order by pf.ext_accession, gpf.query_start
            };
	$cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $ext_accession, $pfname, $pfdesc,
		$q_start, $q_end ) = $cur->fetchrow();
	    last if !$gene_oid;

	    my $r = $gid2rec_ref->{ $gene_oid };
	    $r .= "PFAM:$ext_accession".":$q_start:$q_end"."\t";
	    $gid2rec_ref->{ $gene_oid } = $r;
	}
	$cur->finish();
    }

    if ( scalar(@fs_genes) > 0 ) {
    	for my $gid (@fs_genes) {
    	    my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $gid);
    	    my $new_id = convertGeneOid($gene_oid);

    	    # load COG
    	    my ($cogs_ref, $sdbFileExist) = MetaUtil::getGeneCogInfo($gene_oid, $taxon_oid, $data_type);
    	    for my $line ( @$cogs_ref ) {
        		my ($gid2, $cog_id, $perc_identity, $align_length,
        		    $q_start, $q_end, $s_start, $s_end, $evalue,
        		    $bit_score, $rank) = split(/\t/, $line);

        		my $sql2 = "select cfs.functions from cog_functions cfs "
        		         . "where cfs.cog_id=?";
        		my $cur2 = execSql( $dbh, $sql2, $verbose, $cog_id );
        		my ($fn_code) = $cur2->fetchrow();
        		$cur2->finish();
        		my $r = $gid2rec_ref->{ $new_id };
        		$r .= "COG:$cog_id"."[$fn_code]".":$q_start:$q_end"."\t";
        		$gid2rec_ref->{ $new_id } = $r;
    	    }

    	    # load Pfam
    	    my ($pfams_ref, $sdbFileExist) = MetaUtil::getGenePfamInfo($gene_oid, $taxon_oid, $data_type);
    	    for my $line ( @$pfams_ref ) {
        		my ($gid2, $ext_accession, $perc_identity,
        		    $q_start, $q_end, $s_start, $s_end, $evalue,
        		    $bit_score, $align) = split(/\t/, $line);

        		my $r = $gid2rec_ref->{ $new_id };
        		$r .= "PFAM:$ext_accession".":$q_start:$q_end"."\t";
        		$gid2rec_ref->{ $new_id } = $r;
    	    }
    	}
    }

    # load TIGRPFAM domains:
#    my $sql = qq{
#       select distinct gtf.gene_oid,
#              tf.ext_accession, tf.abbr_name||' - '||tf.expanded_name,
#              gtf.query_start, gtf.query_end
#         from tigrfam tf, gene_tigrfams gtf
#        where tf.ext_accession = gtf.ext_accession
#          and gtf.gene_oid in ($gene_oid_str)
#        order by tf.ext_accession, tf.abbr_name,
#                 tf.expanded_name, gtf.query_start
#    };
#    $cur = execSql( $dbh, $sql, $verbose );
#    for( ;; ) {
#        my( $gene_oid, $ext_accession, $tfname,
#            $q_start, $q_end ) = $cur->fetchrow();
#        last if !$gene_oid;
#
#        my $r = $gid2rec_ref->{ $gene_oid };
#        $r .= "TIGRPFAM:$ext_accession".":$q_start:$q_end"."\t";
#        $gid2rec_ref->{ $gene_oid } = $r;
#    }

}

############################################################################
# loadGeneRec - Load associated gene record information.
#   These are labels with what otherwise would be bare gene_oid's
#   integer identifiers.
############################################################################
sub loadGeneRec {
    my( $dbh, $gene_oid_str, $rec_ref ) = @_;

    my @gene_oids = split(/\,/, $gene_oid_str);
    my @db_genes = ();
    my @fs_genes = ();
    for my $gene_oid ( @gene_oids ) {
	if ( isInt($gene_oid) ) {
	    push @db_genes, ( $gene_oid );
	} else {
	    push @fs_genes, ( $gene_oid );
	}
    }

    if ( scalar(@db_genes) > 0 ) {
	my $db_gene_oid_str = join(",", @db_genes);
	my $sql = qq{
            select distinct g.gene_oid, b.display_name
	    from gene g, bin_scaffolds bs, bin b
	    where g.scaffold = bs.scaffold
	    and bs.bin_oid = b.bin_oid
	    and g.gene_oid in( $db_gene_oid_str )
	    and b.is_default = ?
            };
	my $cur = execSql( $dbh, $sql, $verbose, 'Yes');
	my %geneOid2BinNames;
	for( ;; ) {
	    my( $gene_oid, $bin_display_name ) = $cur->fetchrow();
	    last if !$gene_oid;
	    $geneOid2BinNames{ $gene_oid } .= "$bin_display_name, ";
	}
	$cur->finish();

	$sql = qq{
            select g.gene_oid, g.locus_tag, g.gene_display_name,
	    tx.taxon_oid, tx.taxon_display_name, scf.ext_accession
	    from gene g, taxon tx, scaffold scf
	    where g.taxon = tx.taxon_oid
	    and g.gene_oid in( $db_gene_oid_str )
	    and g.scaffold = scf.scaffold_oid
        };

	$cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gene_oid, $locus_tag, $gene_display_name,
		$taxon_oid, $taxon_display_name,
		$scf_ext_accession )  = $cur->fetchrow();
	    last if !$gene_oid;

	    my $bin_names = $geneOid2BinNames{ $gene_oid };
	    chop $bin_names;
	    chop $bin_names;

	    my $rec = "$gene_oid\t";
	    $rec .= "$locus_tag\t";
	    $rec .= "$gene_display_name\t";
	    $rec .= "$taxon_oid\t";
	    $rec .= "$taxon_display_name\t";
	    $rec .= "$scf_ext_accession\t";
	    $rec .= "$bin_names\tdatabase";
	    $rec_ref->{ $gene_oid } = $rec;
	}
	$cur->finish();
    }

    # MER-FS
    my %taxon_name_h;
    for my $g ( @fs_genes ) {
	my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $g);

	my ($gene_oid2, $locus_type, $locus_tag, $gene_display_name,
	    $start_coord, $end_coord, $strand, $scaffold_oid) =
		MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
	my ($gene_prod_name, $prod_src) =
	    MetaUtil::getGeneProdNameSource($gene_oid, $taxon_oid, $data_type);
	if ( $gene_prod_name ) {
	    $gene_display_name = $gene_prod_name;
	}
	my $taxon_name;
	if ( $taxon_name_h{$taxon_oid} ) {
	    $taxon_name = $taxon_name_h{$taxon_oid};
	} else {
	    my $sql = "select taxon_display_name "
		    . "from taxon where taxon_oid = ?";
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    ($taxon_name) = $cur->fetchrow();
	    $cur->finish();
	    $taxon_name_h{$taxon_oid} = $taxon_name;
	}

	my $rec = "$gene_oid\t";
	$rec .= "$locus_tag\t";
	$rec .= "$gene_display_name\t";
	$rec .= "$taxon_oid\t";
	$rec .= "$taxon_name\t";
	$rec .= "$scaffold_oid\t\t$data_type";
	$rec_ref->{ $g } = $rec;
    }
}

############################################################################
# writeSeq - Write sequence from hash.  Utility function to write
#   out temporary FASTA file for clustalw.
############################################################################
sub writeSeq {
    my( $gene_oid_ref, $gene2Seq_ref, $geneRec_ref,
	$outFile, $idonly ) = @_;
    $idonly = 0 if $idonly eq "";

    my $wfh = newWriteFileHandle( $outFile, "writeSeq" );
    for my $gid( @$gene_oid_ref ) {
	my( $gene_oid, $locus_tag, undef ) =
	    split( /\t/, $geneRec_ref->{ $gid } );

	my $seq  = $gene2Seq_ref->{ $gid };
	my $seq2 = wrapSeq( $seq );
	my $x;
	$x = ".$locus_tag" if ($locus_tag ne "" && !$idonly);

	my @ids = split(/ /, $gid);
	my $display_id = convertGeneOid($ids[-1]);

	if (!isInt($gid) && !$idonly && $use_clustal_omega) {
	    # cannot do this with ClustalW, because of the
	    # 30 char limit for sequence name
	    my $fullgid = $ids[0] ."-". $ids[1] ."-". $ids[2];
	    print $wfh ">$fullgid\n";
	} else {
	    print $wfh ">$display_id$x\n";
	}
	print $wfh "$seq2\n";
    }
    close $wfh;
}


############################################################################
# loadSeq - Get amino acid sequence from database.
############################################################################
sub loadSeq {
    my( $dbh, $gene_oid_str, $gene2Seq_ref ) = @_;

    my @gene_oids = split(/\,/, $gene_oid_str);
    my @db_genes = ();
    my @fs_genes = ();
    for my $gene_oid ( @gene_oids ) {
	if ( isInt($gene_oid) ) {
	    push @db_genes, ( $gene_oid );
	}
	else {
	    push @fs_genes, ( $gene_oid );
	}
    }

    if ( scalar(@db_genes) > 0 ) {
	my $db_gene_oid_str = join(",", @db_genes);
	my $sql = qq{
	    select g.gene_oid, g.aa_residue
  	    from gene g
	    where g.gene_oid in( $db_gene_oid_str )
            };
	my $cur = execSql( $dbh, $sql, $verbose );
	my $badGenes;
	for( ;; ) {
	    my( $gene_oid, $aa_residue )  = $cur->fetchrow();
	    last if !$gene_oid;
	    my $seq = $aa_residue;
	    if ( blankStr( $seq ) ) {
		$badGenes .= "$gene_oid,";
	    }
	    $seq =~ s/\s+//g;
	    $gene2Seq_ref->{ $gene_oid } = $seq;
	}
	$cur->finish();
	chop $badGenes;
	if ( !blankStr( $badGenes ) ) {
	    printStatusLine( "Error.", 2 );
	    webError( "Amino Acid sequences expected for gene(s) $badGenes. "
		    . "( Check for RNA, Pseudogene, or gene without a "
		    . "protein sequence. )"  );
	}
    }

    if ( scalar(@fs_genes) > 0 ) {
	for my $gid ( @fs_genes ) {
	    my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $gid);
	    my $seq = MetaUtil::getGeneFaa($gene_oid, $taxon_oid, $data_type);
	    $gene2Seq_ref->{ $gid } = $seq;
	}
    }
}

############################################################################
# printDndTree - Show alignment tree from clustalw output.
############################################################################
sub printDndTree {
   my( $inFile, $geneRec_ref ) = @_;
   $inFile = checkPath( $inFile );
   my $cmd = "$printDndTree_bin $inFile";
   WebUtil::unsetEnvPath();
   my $cfh = newCmdFileHandle( $cmd, "printDndTree" );
   while( my $s = $cfh->getline() ) {
      chomp $s;
      $s =~ s/^\s+//;
      if ( $s =~ />>>/ ) {
	 print ">>> <b>Alignment \"Tree\"</b> ";
	 print "{ In Outline form with level, (distance), ";
	 print "Gene ID, product name, and [species]  }.\n";
         next;
      }
      my( $level, $distance, $id ) = split( / /, $s );
      $id =~ s/lcl\|//;
      my $indent = "   " x $level;
      my $rec = $geneRec_ref->{ $id };
      my( $gene_oid, $gene_display_name, $genus, $species )
	  = split( /\t/, $rec );
      my $distStr = "<font color='black'>($distance)</font>";
      $distStr = "<font color='red'>($distance)</font>" if
         $distance >= 0.39;
      print "<font color='black'>$indent $level</font> $distStr ";
      print "<font color='green'>$gene_oid</font> ";
      print "$gene_display_name [$genus $species]\n";
   }
   close $cfh;
   WebUtil::resetEnvPath();
}

############################################################################
# graphDndTree - Show alignment tree from clustalw output.
############################################################################
sub graphDndTree {
   my( $inFile, $geneRec_ref ) = @_;
   my $cmd = "$graphDndTree_bin $inFile";
   $inFile = checkPath( $inFile );
   WebUtil::unsetEnvPath();
   my $cfh = newCmdFileHandle( $cmd, "graphDndTree" );
   my $args = { };
   my $dt = new DrawTree( $args );

   while( my $s = $cfh->getline() ) {
      chomp $s;
      $s =~ s/^\s+//;
      my( $level, $distance, $id, $coords, $parentStr ) = split( / /, $s );
      $id =~ s/lcl\|//;
      my( $parent_tag, $parent_val ) = split( /=/, $parentStr );
      $coords =~ s/\(//;
      $coords =~ s/\)//;
      my( $x, $y ) = split( /,/, $coords);
      my $rec = $geneRec_ref->{ $id };
      my( $gene_oid, $gene_display_name, $genus, $species )
	  = split( /\t/, $rec );

      #print "level=$level distance=$distance coords='$coords' ";
      #print "id='$id' parent='$parent_val' ";
      #print "x=$x y=$y gene_oid='$gene_oid' ";
      #print "gene_display_name='$gene_display_name' ";
      #print "genus='$genus' species='$species'<br>\n";

      my $desc;
      if ( $gene_oid ne "" ) {
	 my $sp;
	 if ( $genus ne "" && $species ne "" ) {
	   $sp = " [$genus $species]";
	 }
         $desc = "$gene_oid $gene_display_name$sp";
      }
      my $grec = "$id\t";
      $grec .= "$parent_val\t";
      $grec .= "$desc\t";
      $grec .= "$x\t";
      $grec .= "$y\n";
      $dt->addNode( $id, $parent_val, $desc, $x, $y );
   }
   close $cfh;
   WebUtil::resetEnvPath();

   my $drawTreeFile = "drawTree$$.png";
   my $outFile = "$tmp_dir/$drawTreeFile";
   my $outUrl = "$tmp_url/$drawTreeFile";
   $dt->drawTree( $outFile );
   print "<img src='$outUrl' border='0' alt='geneTree' />\n";
}

############################################################################
# printShowGeneTable - Show/Hide the gene table
############################################################################
sub printShowGeneTable {
    my( $geneRec_ref ) = @_;
    if (0) {  # not needed with tab layout
    print qq{
	<script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
	</script>

	<script language='JavaScript' type='text/javascript'>
	function showTable(type) {
	    if (type == 'slim') {
		document.getElementById('showtable').style.display = 'none';
		document.getElementById('hidetable').style.display = 'block';
	    } else {
		document.getElementById('showtable').style.display = 'block';
		document.getElementById('hidetable').style.display = 'none';
	    }
	}

	YAHOO.util.Event.onDOMReady(function () {
	    showTable('slim');
	});
	</script>
    };
    }

    #print "<div id='hidetable' style='display: block;'>";
    #print "<input type='button' class='medbutton' name='view'"
    #	. " value='Show Gene Table'"
    #	. " onclick='showTable(\"full\")' />";
    #print "</div>\n";

    #print "<div id='showtable' style='display: block;'>";
    #print "<input type='button' class='medbutton' name='view'"
    #	. " value='Hide Gene Table'"
    #	. " onclick='showTable(\"slim\")' />";
    printGeneRec($geneRec_ref);
    #print "</div>\n";
}

############################################################################
# printGeneRec - Print out the entire gene record with function
#   information.
############################################################################
sub printGeneRec {
   my( $geneRec_ref, $keys_ref ) = @_;

   my @keys = sort{  $a <=> $b }( keys( %$geneRec_ref ) );
   if (defined $keys_ref) {
       @keys = @$keys_ref;
   }

   my $it = new InnerTable(1, "clustalw$$", "clustalw", 0);
   my $sd = $it->getSdDelim();
   $it->addColSpec( "Gene ID", "asc", "right" );
   $it->addColSpec( "Locus Tag", "asc", "left" );
   $it->addColSpec( "Product Name", "asc", "left" );
   $it->addColSpec( "Scaffold ID", "asc", "left" );
   $it->addColSpec( "Genome", "asc", "left" );

   for my $k( @keys ) {
      my $rec = $geneRec_ref->{ $k };
      my( $gene_oid, $locus_tag, $gene_display_name,
	  $taxon_oid, $taxon_display_name,
	  $scf_ext_accession,
          $bin_names, $data_type ) = split( /\t/, $rec );

      my $scf_id2 = $scf_ext_accession;
      $scf_id2 .= " (bin(s): $bin_names)"
         if $bin_names ne "";

      my $url1 = "$main_cgi?section=GeneDetail"
	       . "&page=geneDetail&gene_oid=$gene_oid";
      my $url2 = "$main_cgi?section=TaxonDetail"
	       . "&page=taxonDetail&taxon_oid=$taxon_oid";

      if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
	  $url1 = "$main_cgi?section=MetaGeneDetail"
	        . "&page=metaGeneDetail&gene_oid=$gene_oid"
	        . "&taxon_oid=$taxon_oid&data_type=$data_type";
	  $url2 = "$main_cgi?section=MetaDetail"
	        . "&page=metaDetail&taxon_oid=$taxon_oid";
      }

      my $row;
      $row .= $gene_oid.$sd.alink($url1, $gene_oid)."\t";
      $row .= $locus_tag."\t";
      $row .= $gene_display_name."\t";
      $row .= escHtml($scf_id2)."\t";
      $row .= $taxon_display_name.$sd.alink($url2, $taxon_display_name)."\t";
      $it->addRow($row);
   }
   $it->printOuterTable(1);
}

############################################################################
# printJalView - Show JalView'er
############################################################################
sub printJalView {
   my( $alnFile, $nGenes, $alignment ) = @_;
   my $fileName = lastPathTok( $alnFile );
   my $alnFileUrl = "$tmp_url/$fileName";

   my $height;
   if ($nGenes > 20) {
       $height = 500;
   } else {
       $height = 200 + (25 * $nGenes);
   }

   my $clustalw_url = "http://www.clustal.org/clustalw2/";
   my $clustalo_url = "http://www.clustal.org/omega/";
   my $url = "http://www.jalview.org/";
   print "<p>\n";
   if ($use_clustal_omega) {
       print alink($clustalo_url, "Clustal Omega", "_blank")
       . " sequence alignment below is displayed using the "
       . alink($url, "Jalview", "_blank")." applet.";
   } else {
       print alink($clustalw_url, "ClustalW", "_blank")
       . " sequence alignment below is displayed using the "
       . alink($url, "Jalview", "_blank")." applet.";
   }
   print "<br/>Click on the id in Jalview to display the gene page in IMG.";
   print "</p>\n";

   my $gurl = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=";

   my $colors = "Clustal";
   $colors = "Nucleotide" if $alignment eq "nucleic";

   print qq{
        <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
        </script>

        <script language='JavaScript' type='text/javascript'>
        function showApplet(type) {
            if (type == 'jalviewapplet') {
              document.getElementById('showjalview').style.display = 'block';
              document.getElementById('hidejalview').style.display = 'none';
            }
        }
        </script>
   };

   print "<div id='hidejalview' style='display: block;'>";
   print "<input type='button' class='medbutton' name='view'"
       . " value='Launch in separate window'"
       . " onclick='showApplet(\"jalviewapplet\")' />";
   print "</div>\n";

   print "<div id='showjalview' style='display: none;'>";
   print "<applet code='jalview.bin.JalviewLite'\n";
   print "  archive='$base_url/jalviewApplet.jar'\n";
   print "  width='100' height='40'>\n";
   print "  <param name='file' value='$alnFileUrl'>\n";
   print "  <param name='label' value='Launch Jalview'>\n";
   print "  <param name='linkUrl' value='$gurl'>\n";
   print "  <param name='defaultColour' value='$colors'>\n";
   print "</applet>\n";
   print "</div>\n";

   printColorScheme( $alignment );

   print "<applet code='jalview.bin.JalviewLite'\n";
   print "  archive='$base_url/jalviewApplet.jar'\n";
   print "  width='800' height='$height'>\n";
   print "  <param name='file' value='$alnFileUrl'>\n";
   print "  <param name='embedded' value='true'>\n";
#   print "  <param name='tree' value='$newickFile'>\n";
   print "  <param name='linkUrl' value='$gurl'>\n";
   print "  <param name='defaultColour' value='$colors'>\n";
   print "</applet>\n";
}

############################################################################
# printColorScheme - Show/Hide color scheme for jalview
############################################################################
sub printColorScheme {
    my( $alignment ) = @_;
    print qq{
	<script type='text/javascript'
	    src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
	</script>

	<script language='JavaScript' type='text/javascript'>
	function showColors(type) {
	    if (type == 'nocolors') {
		document.getElementById('showcolors').style.display = 'none';
		document.getElementById('hidecolors').style.display = 'block';
	    } else {
		document.getElementById('showcolors').style.display = 'block';
		document.getElementById('hidecolors').style.display = 'none';
	    }
	}
	</script>
    };

    print "<div id='hidecolors' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
	. " value='Show Color Scheme'"
	. " onclick='showColors(\"colors\")' />";
    print "</div>\n";

    print "<div id='showcolors' style='display: none;'>";
    print "<input type='button' class='medbutton' name='view'"
	. " value='Hide Color Scheme'"
	. " onclick='showColors(\"nocolors\")' />";
    print "<p>";
    if ( $alignment eq "nucleic" ) {
	print "<image src='$base_url/images/jalview-nucleotides.jpg' "
	    . "width='220' height='30' />\n";
    } else {
	print "<image src='$base_url/images/jalview-colors.jpg' "
	    . "width='440' height='200' />\n";
    }
    print "</p>";
    print "</div>\n";
    print "<br/>";
}

############################################################################
# printAtvButton - Show "A Tree Viewer" button. (Not used.)
############################################################################
sub printAtvButton {
    my( $dndFilePath ) = @_;

    print "<br/>/p\n";
    print "[ ";
    my $fileName = lastPathTok( $dndFilePath );
    my $url = "atv.cgi?dndFilePath=$fileName";
    print "<font color='green'>\n";
    print "<b>\n";
    print alink( $url, "Run A Tree Viewer (ATV)", "2" );
    print "</b>\n";
    print "</font>\n";
    print " ]";
    print "<br/>/p\n";
}

############################################################################
# massageDndIds - Massage DND Id's for ATV (not used).
############################################################################
sub massageDndIds {
    my( $dndFile, $geneRec_ref ) = @_;
    my $str = file2Str( $dndFile );
    $str =~ s/\(/ ( /g;
    $str =~ s/\)/ ) /g;
    $str =~ s/,/ , /g;
    $str =~ s/:/ : /g;
    $str =~ s/\s+/ /g;
    webLog "original DND: '$str'\n" if $verbose >= 1;

    my @toks = split( / /, $str );
    my $nToks = @toks;
    my $str2;
    for( my $i = 0; $i < $nToks; $i++ ) {
	my $currTok = $toks[ $i ];
	my $nextTok = $toks[ $i+1 ];
	if ( $nextTok eq ":" ) {
	    my $rec = $geneRec_ref->{ $currTok };
	    my( $gene_oid, $gene_display_name, $genus, $species )
		= split( /\t/, $rec );

	    if ( $gene_oid ne "" ) {
		$currTok = "$gene_oid $gene_display_name { $genus $species }";
		$currTok =~ s/\s+/_/g;
		$currTok =~ s/\(/_/g;
		$currTok =~ s/\)/_/g;
		$currTok =~ s/,/_/g;
		$currTok =~ s/;/_/g;
		$currTok =~ s/-/_/g;
	    }
	}
	$str2 .= " $currTok ";
    }
    webLog "dndFileRevised: '$str2'\n" if $verbose >= 1;
    my $outFile = "$dndFile.atv";
    str2File( $str2, $outFile );
    return $outFile;
}

############################################################################
# readAlnFile - Get alignment file from standard output of clustalw.
############################################################################
sub readAlnFile {
    my( $inFile ) = @_;
    print "<p>Aln: $inFile\n";

    my $rfh = newReadFileHandle( $inFile, "readAlnFile" );
    my $alnFile;
    while( my $s = $rfh->getline() ) {
	chop $s;

	next if $s !~ /^CLUSTAL-Alignment file created/;
	$s =~ s/\s+/ /g;
	my( $clustalw, $file, $created, $path ) = split( / /, $s );
	$path =~ s/\[//g;
	$path =~ s/\]//g;
	$alnFile = $path;
    }
    close $rfh;
    return $alnFile;
}

############################################################################
# readPhyFile - Get alignment file from standard output of clustalw.
############################################################################
sub readPhyFile {
    my( $inFile ) = @_;
    my $rfh = newReadFileHandle( $inFile, "readPhyFile" );
    my $phyFile;
    while( my $s = $rfh->getline() ) {
	chop $s;

	next if $s !~ /^PHYLIP-Alignment file created/;
	$s =~ s/\s+/ /g;
	my( $phylip, $file, $created, $path ) = split( / /, $s );
	$path =~ s/\[//g;
	$path =~ s/\]//g;
	$phyFile = $path;
    }
    close $rfh;
    return $phyFile;
}

############################################################################
# readDndFile - Read DND file from standard output of clustalw.
############################################################################
sub readDndFile {
    my( $inFile ) = @_;
    my $rfh = newReadFileHandle( $inFile, "readDndFile" );
    my $dndFile;
    while( my $s = $rfh->getline() ) {
       chop $s;
       $s =~ s/\s+/ /g;
       next if $s !~ /^Guide tree file created:/;
       my( $guide, $tree, $file, $created, $path ) = split( / /, $s );
       $path =~ s/\[//g;
       $path =~ s/\]//g;
       $dndFile = $path;
    }
    close $rfh;
    return $dndFile;
}

############################################################################
# printMviewCodes - Print AA residue equivalence codes for
#  Mview output lengend.
############################################################################
sub printMviewCodes {
    print "<p>\n";
    print "Mview equivalence class codes\n";
    print "</p>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Code</th>\n";
    print "<th class='img' >Equivalence Class</th>\n";

    my %colors = (
	"red" => "#ff1111",
	"bright-red" => "#cc0000",
	"blue" => "#1155ff",
	"bright-blue" => "#0033ff",
	"dull-blue" => "#0099ff",
	"green" => "#11dd11",
	"bright-green" => "#33cc00",
	"dark-green" => "#009900",
	"cyan" => "#11ffff",
	"yellow" => "#ffff11",
	"orange" => "#ff7f11",
	"pink" => "#ff11ff",
	"purple" => "#6611cc",
	"dull-blue" => "#197fe5",
	"dark-gray"  => "#666666",
	"light-gray" => "#999999",
	);
    printMviewCode( "*", $colors{ "dark-gray" }, "mismatch" );
    printMviewCode( "+", $colors{ "bright-red" }, "positive charge" );
    printMviewCode( "-", $colors{ "bright-blue" }, "negative charge" );
    printMviewCode( "a", $colors{ "dark-green" }, "aromatic" );
    printMviewCode( "c", $colors{ "purple" }, "charged" );
    printMviewCode( "h", $colors{ "bright-green" }, "hydrophobic" );
    printMviewCode( "l", $colors{ "bright-green" }, "aliphatic" );
    printMviewCode( "o", $colors{ "dull-blue" }, "alchohol" );
    printMviewCode( "p", $colors{ "dull-blue" }, "polar" );
    printMviewCode( "s", $colors{ "bright-green" }, "small" );
    printMviewCode( "t", $colors{ "bright-green" }, "turnlike" );
    printMviewCode( "u", $colors{ "bright-green" }, "tiny" );
    print "</table>\n";
}

############################################################################
# printMviewCode -  Print one Mview equivalence code.
############################################################################
sub printMviewCode {
    my( $code, $color, $label ) = @_;
    print "<tr class='img' >\n";
    print "   <td class='img' ><font color='$color'>$code</font></td>\n";
    print "   <td class='img' >$label</td>\n";
    print "</tr>\n";
}

############################################################################
# printClustalAlignFnaSeq - Show FASTA nucleic acid sequence for alignment.
############################################################################
sub printClustalAlignFnaSeq {
    my( $outFile, $idonly ) = @_;

    $idonly = 0 if $idonly eq "";
    my $wfh = newWriteFileHandle( $outFile, "printAlignFnaSeq" );

    my @gene_oids = param( "gene_oid" );
    my $up_stream = param( "align_up_stream" );
    my $down_stream = param( "align_down_stream" );
    my $up_stream_int = sprintf( "%d", $up_stream );
    my $down_stream_int = sprintf( "%d", $down_stream );
    $up_stream =~ s/\s+//g;
    $down_stream =~ s/\s+//g;

    if ( scalar(@gene_oids) == 0 ) {
    	print "<p>\n";
    	webError( "Select genes first." );
    }

    my @db_genes = ();
    my @fs_genes = ();
    for my $gene_oid ( @gene_oids ) {
    	if ( isInt($gene_oid) ) {
    	    push @db_genes, ( $gene_oid );
    	} else {
    	    push @fs_genes, ( $gene_oid );
    	}
    }

    if ($up_stream_int > 0 || !isInt( $up_stream )) {
    	print "<p>\n";
    	webError( "Expected negative integer for up stream." );
    }
    if ($down_stream_int < 0 || !isInt( $down_stream )) {
    	print "<p>\n";
    	webError( "Expected positive integer for down stream." );
    }

    my %records;
    my $dbh = dbLogin();
    if ( scalar(@db_genes) > 0 ) {
    	my $db_gene_oid_str = join( ',', @db_genes );
    	my $sql = qq{
            select g.gene_oid, g.locus_tag, g.gene_display_name,
 	           tx.taxon_oid, tx.genus, tx.species,
               g.start_coord, g.end_coord, g.strand, g.cds_frag_coord,
               scf.ext_accession
              from gene g, scaffold scf, taxon tx
             where g.scaffold = scf.scaffold_oid
               and g.taxon = tx.taxon_oid
               and g.gene_oid in( $db_gene_oid_str )
	       and g.start_coord > 0
	       and g.end_coord > 0
        };
    	my $cur = execSql( $dbh, $sql, $verbose );
    	for( ;; ) {
    	    my( $gene_oid, $locus_tag,
    		$gene_display_name, $taxon_oid, $genus, $species,
    		$start_coord0, $end_coord0, $strand, $cds_frag_coord,
    		$ext_accession ) = $cur->fetchrow();
    	    last if !$gene_oid;

    	    my $rec =
    		$gene_oid."\t".$locus_tag."\t".
    		$gene_display_name."\t".$taxon_oid."\t".$genus."\t".$species."\t".
    		$start_coord0."\t".$end_coord0."\t".$strand."\t". $cds_frag_coord."\t".
    		$ext_accession;
    	    $records{$gene_oid} = $rec;
    	}
    	$cur->finish();
    }

    my %taxon_info_h;
    for my $g ( @fs_genes ) {
    	my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $g);

    	my ($gene_oid2, $locus_type, $locus_tag, $gene_display_name,
    	    $start_coord, $end_coord, $strand, $scaffold_oid) =
    		MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
    	my ($gene_prod_name, $prod_src) =
    	    MetaUtil::getGeneProdNameSource($gene_oid, $taxon_oid, $data_type);
    	if ( $gene_prod_name ) {
    	    $gene_display_name = $gene_prod_name;
    	}

    	my $genus = "";
    	my $species = "";
    	if ( $taxon_info_h{$taxon_oid} ) {
    	    ($genus, $species) = split(/\t/, $taxon_info_h{$taxon_oid});
    	} else {
    	    my $sql = "select genus, species from taxon where taxon_oid = ?";
    	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    	    ($genus, $species) = $cur->fetchrow();
    	    $cur->finish();
    	    $taxon_info_h{$taxon_oid} = "$genus\t$species";
    	}
    	my $rec = "$g\t$locus_tag\t$gene_display_name\t$taxon_oid\t$genus\t" .
    	    "$species\t$start_coord\t$end_coord\t$strand\t\t$scaffold_oid";
    	my $new_id = convertGeneOid($gene_oid);
    	$records{$new_id} = $rec;
    }
    #$dbh->disconnect();

    for my $gid (@gene_oids) {
    	my $new_id = convertGeneOid($gid);
        my $str = $records{$new_id};

        next if (!defined $str || $str eq "");
    	my( $gene_oid, $locus_tag,
    	    $gene_display_name, $taxon_oid, $genus, $species,
    	    $start_coord0, $end_coord0, $strand, $cds_frag_coord,
    	    $ext_accession )
    	    = split("\t",$str);

    	# Reverse convention for reverse strand
    	my $start_coord = $start_coord0 + $up_stream;
    	$start_coord = 1 if $start_coord < 1;
    	my $end_coord = $end_coord0 + $down_stream;
    	if ( $strand eq "-" ) {
               $start_coord = $start_coord0 - $down_stream;
               $end_coord = $end_coord0 - $up_stream;
    	}
    	webLog "$ext_accession: $start_coord..$end_coord ($strand)\n"
                 if $verbose >= 1;

    	my $x;
    	$x = ".$locus_tag" if ($locus_tag ne "" && !$idonly);

    	if ( !isInt($gene_oid) && !$idonly && $use_clustal_omega) {
    	    # cannot do this with ClustalW, because of the
    	    # 30 char limit for sequence name
    	    my @ids = split(/ /, $gid);
    	    my $fullgid = $ids[0] ."-". $ids[1] ."-". $ids[2];
    	    print $wfh ">$fullgid\n";
    	} else {
    	    print $wfh ">$new_id$x\n";
    	}

        my @coordLines;
    	my $seq1 = "";
    	my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    	if ( isInt($gene_oid) ) {
            @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
            my @adjustedCoordsLines = GeneUtil::adjustMultFragCoordsLine( \@coordLines, $strand, $up_stream, $down_stream );
    	    $seq1 = WebUtil::readLinearFasta( $path, $ext_accession,
    				     $start_coord, $end_coord, $strand, \@adjustedCoordsLines );
    	} else {
    	    # MER-FS
    	    my ($taxon_oid, $data_type, $gid2) = split(/ /, $gid);
    	    my $line = MetaUtil::getScaffoldFna($taxon_oid, $data_type, $ext_accession);
    	    if ( $line ) {
    		if ( $strand eq '-' ) {
    		    $seq1 = getSequence($line, $end_coord0, $start_coord0);
    		} else {
    		    $seq1 = getSequence($line, $start_coord0, $end_coord0);
    		}
    	    }
    	}

    	if ( blankStr( $seq1 ) ) {
    	    webLog( "naSeq.cgi: no sequence for '$path' " .
    		    "$start_coord..$end_coord ($strand)\n" );
    	    next;
    	}

    	my $us_len = $start_coord0 - $start_coord; # upstream length
    	$us_len = $end_coord - $end_coord0 if $strand eq "-";
    	$us_len = 0 if $us_len < 0;

        my $dna_len;
        if ( scalar(@coordLines) > 1 ) {
            $dna_len = GeneUtil::getMultFragCoordsLength(@coordLines);
        }
        else {
            $dna_len = $end_coord0 - $start_coord0 + 1;
        }

    	my $dna_len1 = 3;  # start codon
    	my $dna_len2 = $dna_len - 6; # middle
    	my $dna_len3 = 3;  # end codon

    	# Set critical coordinates from segment lengths
    	my $c0 = 1;
    	my $c1 = $c0 + $us_len;
    	my $c2 = $c1 + $dna_len1;
    	my $c3 = $c2 + $dna_len2;
    	my $c4 = $c3 + $dna_len3;
    	my $c1StartCodon = 0;
    	my $startCodon0 = substr( $seq1, $c1 - 1, 3 );
    	$c1StartCodon = 1 if isStartCodon( $startCodon0 );
    	my $stopCodon0 = substr( $seq1, $c3 - 1, 3 );
    	my $c3StopCodon = 0;
    	$c3StopCodon = 1 if isStopCodon( $stopCodon0 );

    	if ( $verbose >= 1 ) {
            webLog "up_stream=$up_stream ";
    	    webLog "start_coord0=$start_coord0 ";
            webLog "start_coord=$start_coord\n";
            webLog "end_coord=$end_coord ";
    	    webLog "end_coord0=$end_coord0 ";
            webLog "c0=$c0 c1=$c1 c2=$c2 c3=$c3 c4=$c4\n";
    	    webLog "startCodon0='$startCodon0' "
    	        . "c1StartCodon=$c1StartCodon\n";
    	    webLog "stopCodon0 ='$stopCodon0' c3StopCodon=$c3StopCodon\n";
    	}

    	my @bases = split( //, $seq1 );
    	my $baseCount = 0;
    	my $maxWrapCount = 50;
    	my $wrapCount = 0;
    	for my $b( @bases ) {
    	    $wrapCount++;
    	    print $wfh $b;
    	    if ( $wrapCount >= $maxWrapCount ) {
        		print $wfh "\n";
        		$wrapCount = 0;
    	    }
    	}
    	print $wfh "\n";
    }

    close $wfh;
}


#######################################################################
# convertGeneOid - convert gene_oid to no more than 10 chars
#######################################################################
sub convertGeneOid {
    my ($gene_oid) = @_;
    if ( ! $gene_oid ) {
	return "0";
    }

    $gene_oid =~ s/ /\_/g;
    my @v = split(/\_/, $gene_oid);
    my $new_id = $v[-1];
    if ( length($new_id) > 10 ) {
	$new_id = substr($new_id, length($new_id)-10);
    }

    return $new_id;
}



1;

