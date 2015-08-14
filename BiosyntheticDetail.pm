############################################################################
# BiosyntheticDetail - detail page for biosynthetic clusters
# $Id: BiosyntheticDetail.pm 33949 2015-08-09 07:37:16Z jinghuahuang $
############################################################################
package BiosyntheticDetail;
my $section = "BiosyntheticDetail";

use strict;
use POSIX qw(ceil floor);
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use NaturalProd;
use ImgTermNode; 
use ImgTermNodeMgr; 
use ImgPwayBrowser;
use ImgCompound;
use DataEntryUtil;
use FuncUtil;
use HtmlUtil;
use OracleUtil;
use MerFsUtil;
use MetaUtil;
use MetaGeneTable;
use WorkspaceUtil;
use TaxonDetailUtil;
use BcUtil;

my $env           = getEnv();
my $main_cgi      = $env->{main_cgi};
my $section_cgi   = "$main_cgi?section=$section";
my $inner_cgi     = $env->{inner_cgi};
my $tmp_url       = $env->{tmp_url};
my $tmp_dir       = $env->{tmp_dir};
my $verbose       = $env->{verbose};
my $base_dir      = $env->{base_dir};
my $base_url      = $env->{base_url};
my $ncbi_base_url = $env->{ncbi_entrez_base_url};
my $pfam_base_url = $env->{pfam_base_url};
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";
my $YUI           = $env->{yui_dir_28};
my $nvl           = getNvl();

my $enable_biocluster = $env->{enable_biocluster};
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $maxGeneProfileIds = 100; 
my $flank_length = 25000;
my $NA = "na";

sub dispatch {
    my $sid = getContactOid();
    my $page = param("page");    

    if ( $page eq "cluster_detail" ) {
    	printBioClusterDetail();
    } elsif ( $page eq "cluster_viewer" ) {
    	printBioClusterViewer();
    } elsif ( $page eq "reload_viewer" ) {
    	reloadViewer();
    } elsif ( $page eq "addBCNP" ||
	      paramMatch("addBCNP") ne "") {
    	printBCNPForm(0);
    } elsif ( $page eq "updateBCNP" ||
	      paramMatch("updateBCNP") ne "") {
    	printBCNPForm(1);
    } elsif ( $page eq "deleteBCNP" ||
	      paramMatch("deleteBCNP") ne "") {
    	printConfirmDeleteBCNPForm();
    } elsif ( $page eq "dbAddNP" ||
	      paramMatch("dbAddNP") ne "") {
    	my $msg = dbAddNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "dbUpdateNP" ||
	      paramMatch("dbUpdateNP") ne "") {
    	my $msg = dbUpdateNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "dbDeleteNP" ||
	      paramMatch("dbDeleteNP") ne "") {
    	my $msg = dbDeleteNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "addMyIMGBCNP" ||
	      paramMatch("addMyIMGBCNP") ne "") {
    	printMyIMGBCNPForm(0);
    } elsif ( $page eq "updateMyIMGBCNP" ||
	      paramMatch("updateMyIMGBCNP") ne "") {
    	printMyIMGBCNPForm(1);
    } elsif ( $page eq "deleteMyIMGBCNP" ||
	      paramMatch("deleteMyIMGBCNP") ne "") {
    	printConfirmDeleteMyIMGBCNPForm();
    } elsif ( $page eq "dbAddMyIMGNP" ||
	      paramMatch("dbAddMyIMGNP") ne "") {
    	my $msg = dbAddMyIMGNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "dbUpdateMyIMGNP" ||
	      paramMatch("dbUpdateMyIMGNP") ne "") {
    	my $msg = dbUpdateMyIMGNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "dbDeleteMyIMGNP" ||
	      paramMatch("dbDeleteMyIMGNP") ne "") {
    	my $msg = dbDeleteMyIMGNP();
    	if ( $msg ) {
    	    WebUtil::webError($msg);
    	}
    	else {
    	    printBioClusterDetail();
    	}
    } elsif ( $page eq "pathwayEvidence" ) {
    	my $pathway_oid = param('pathway_oid');
    	my $taxon_oid = param('taxon_oid');
    	my $cluster_id = param('cluster_id');
    	printClusterPathwayEvidence($pathway_oid, $taxon_oid, $cluster_id);
    } elsif ( $page eq "biosynthetic_clusters" ) {
        printBiosyntheticClusters();
    } elsif ( $page eq "cassette_box" ) {
	printBiosyntheticCassette();
    } elsif ( $page eq "biosynthetic_genes" ) {
        printBiosyntheticGenes();
    } elsif ( $page eq "bioClusterPfamList" ) {
    	my $taxon_oid = param('taxon_oid');
    	my $cluster_id = param('cluster_id');
    	printBioClusterPfamList($taxon_oid, $cluster_id);
    } elsif ( $page eq "bcGeneList" ||
	      paramMatch("bcGeneList") ne "") {
        printBioClusterGeneList("", "", "", 1);
    } elsif ( $page eq "pfamGeneList" ||
	      paramMatch("pfamGeneList") ne "") {
        printBCPfamGeneList();
    } elsif ( $page eq "bioClusterPathwayList" ) {
        my $taxon_oid = param('taxon_oid');
        my $cluster_id = param('cluster_id');
        printBioClusterPathwayList($taxon_oid, $cluster_id);
    } elsif ( $page eq "findSimilarBCGF" ||
	      paramMatch("findSimilarBCGF") ne "") {
        printSimilarBCGF();
    } elsif ( $page eq "pfamNeighborhood" ||
	      paramMatch("pfamNeighborhood") ne "") {
	my @sim_bc = param("bc_id");
	if ( scalar(@sim_bc) == 0 ) {
    	    WebUtil::webError("No clusters have been selected.");
	}
	printBioClusterViewer();
    } elsif ( $page eq "pfamDomain" ||
	      paramMatch("pfamDomain") ne "") {
	my @sim_bc = param("bc_id");
	if ( scalar(@sim_bc) == 0 ) {
    	    WebUtil::webError("No clusters have been selected.");
	}
	printPfamDomain();
    } elsif ( $page eq "selectedNeighborhoods" ||
	      paramMatch("selectedNeighborhoods") ne "") {
	viewNeighborhoodsForSelectedClusters();
    } elsif ( $page eq "addBCGenes" ||
	      paramMatch("addBCGenes") ne "") {
	addBCGenesToCart();
    } elsif ( $page eq "addBCScaffolds" ||
	      paramMatch("addBCScaffolds") ne "") {
	addBCScaffoldsToCart();
    } elsif ( $page eq "addGeneCart" ||
              paramMatch("addGeneCart") ne "" ) {
        addBCPfamGeneListToCart();
    } elsif ( $page eq "addToGeneCart" ||
	      paramMatch("addToGeneCart") ne "" ) {
        BcUtil::addSelectedToGeneCart();
    } elsif ( $page eq "addToScaffoldCart" ||
	      paramMatch("addToScaffoldCart") ne "" ) {
        BcUtil::addSelectedToScaffoldCart();
    } elsif ( $page eq "geneExport" ) {
	exportClusterGenes();
    } elsif ( $page eq "fasta" ) {
	printFastaForCluster();
    }
}

############################################################
# printBioClusterDetail
############################################################
sub printBioClusterDetail {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $mygene = param("gene_oid");

    print "<h1>Biosynthetic Cluster Detail</h1>";

    my $dbh = dbLogin();
    my $sql = qq{
        select bc.cluster_id, t.taxon_oid, t.in_file,
               $nvl(t.taxon_name, t.taxon_display_name)
    	from bio_cluster_new bc, taxon t
        where bc.cluster_id = ?
    	and bc.taxon = t.taxon_oid
    };
    my $cur;
    if ( $taxon_oid && isInt($taxon_oid) ) {
    	$sql .= " and bc.taxon = ? ";
    	$cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    } else {
    	$cur = execSql($dbh, $sql, $verbose, $cluster_id);
    }
    my ($id2, $taxon_oid2, $in_file, $taxon_name) = $cur->fetchrow();
    $cur->finish();
    if ( ! $id2 ) {
    	print "<h5>Error: Incorrect Biosynthetic Cluster ID</h5>\n";
    	return;
    }

    if ( !$taxon_oid || !isInt($taxon_oid) ) {
    	$taxon_oid = $taxon_oid2;
    }

    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>";

    $sql = qq{
        select c.compound_name
        from img_compound c, np_biosynthesis_source np
        where np.cluster_id = ?
        and np.compound_oid = c.compound_oid
    };
    $cur = execSql($dbh, $sql, $verbose, $cluster_id);
    my ($np_name) = $cur->fetchrow();
    $cur->finish();

    use TabHTML;
    TabHTML::printTabAPILinks("bioDetailTab");
    my @tabIndex = ("#biodetailtab1", "#biodetailtab2", 
		    "#biodetailtab3", "#biodetailtab4",
		    "#biodetailtab5", "#biodetailtab6",
		    "#biodetailtab7");

    my @tabNames = ("Biosynthetic Cluster", "Genes in Cluster",
		    "Cluster Neighborhood", "Secondary Metabolite",
		    "IMG Pathways", "Metacyc", "KEGG");

    TabHTML::printTabDiv("bioDetailTab", \@tabIndex, \@tabNames);

    my $sql = qq{
        select tx.taxon_display_name, tx.gold_id,
               bc.scaffold, scf.scaffold_name
        from bio_cluster_new bc, taxon tx, scaffold scf
        where bc.taxon = ?
        and bc.cluster_id = ?
        and bc.taxon = tx.taxon_oid
        and bc.scaffold = to_char(scf.scaffold_oid)
    };
    if ( $in_file eq 'Yes' ) {
    	$sql = qq{
            select tx.taxon_display_name, tx.gold_id,
                   bc.scaffold, bc.scaffold
            from bio_cluster_new bc, taxon tx
            where bc.taxon = ?
            and bc.cluster_id = ?
            and bc.taxon = tx.taxon_oid
        };
    }

    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $cluster_id);
    my ($taxon_display_name, $gold_id, $scaffold_oid, $scaffold_name)
	= $cur->fetchrow();

    print "<div id='biodetailtab1'>";
    print "<br/>";

    print start_form(-id     => "detail_frm",
                     -name   => "detailForm",
                     -action => "$main_cgi");

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Biosynthetic Cluster Information</font></th>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my $gold_link;
    if (!blankStr($gold_id)) {
        my $url = HtmlUtil::getGoldUrl($gold_id);
    	$gold_link = alink($url, "Project ID: $gold_id");
    }
    GeneDetail::printAttrRowRaw( "GOLD ID", $gold_link );
			   
    my $s_url = "$main_cgi?section=ScaffoldCart"
	      . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
    if ( $in_file eq 'Yes' ) {
	$s_url = "$main_cgi?section=MetaDetail" 
	       . "&page=metaScaffoldDetail&taxon_oid=$taxon_oid" 
	       . "&scaffold_oid=$scaffold_oid";
    }
    GeneDetail::printAttrRowRaw( "Scaffold", alink($s_url, $scaffold_name) );

    my ($min, $max) = getBioClusterMinMax($dbh, $cluster_id);
    my $seq_url = "$main_cgi?section=BiosyntheticDetail"
	        . "&page=fasta&taxon_oid=$taxon_oid&cluster_id=$cluster_id"
		. "&start=$min&end=$max&scaffold_oid=$scaffold_oid";
    GeneDetail::printAttrRowRaw
	( "DNA Sequence", alink($seq_url, "$min..$max") );

    my $v_url = "$main_cgi?section=BiosyntheticDetail"
	      . "&page=cluster_viewer&taxon_oid=$taxon_oid"
	      . "&type=bio&cluster_id=$cluster_id";
    #GeneDetail::printAttrRowRaw
    #	( "Cluster Viewer", alink($v_url, "neighborhood") );

    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    my @genbank_ids = ();
    $sql = qq{
        select bcd.cluster_id, bcd.genbank_acc, bcd.probability,
               bcd.evidence, bcd.bc_type, bcd.is_curated,
               bc.start_coord, bc.end_coord
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.cluster_id = ? 
        and bcd.cluster_id = bc.cluster_id
    };

    $cur = execSql($dbh, $sql, $verbose, $cluster_id);
    my $evid_type;
    my $prob;
    my $end; my $start;
    my $bctype;
    my $is_curated;
    for ( ;; ) {
    	my ($id2, $acc2, $prob2, $evid2, $bctype2, $curated2,
	    $start2, $end2) = $cur->fetchrow();
    	last if ! $id2;

	$evid_type = $evid2;
	$start = $start2;
	$end = $end2;
	$prob = sprintf( "%.2f", $prob2 );
	$bctype = $bctype2;
	$is_curated = $curated2;

	if (!blankStr($acc2)) {
	    $acc2 = alink("${ncbi_base_url}$acc2", $acc2);
	}
	push @genbank_ids, ( $acc2 );
    }
    $cur->finish();

    GeneDetail::printAttrRowRaw( 'EVIDENCE', $evid_type );
    GeneDetail::printAttrRowRaw( 'PROBABILITY', $prob );
    if ( $bctype ) {
	my $disp_type = translateBcType($dbh, $bctype);
	GeneDetail::printAttrRowRaw( 'BC_TYPE', $disp_type );
    }
    if ( $is_curated ) {
	GeneDetail::printAttrRowRaw( 'IS_CURATED?', $is_curated );
    }
    GeneDetail::printAttrRowRaw( 'START_ON_CHROMOSOME', $start );
    GeneDetail::printAttrRowRaw( 'END_ON_CHROMOSOME', $end );
    GeneDetail::printAttrRowRaw( 'GENBANK_ACC', join(", ", @genbank_ids) );

    my $pfam_count = getBioClusterPfamCount($cluster_id, $taxon_oid, $in_file);
    if ( $pfam_count ) {
    	my $url3 = "$main_cgi?section=BiosyntheticDetail"
    	    . "&page=bioClusterPfamList&taxon_oid=$taxon_oid"
    	    . "&type=bio&cluster_id=$cluster_id";
    	GeneDetail::printAttrRowRaw( "PFAM_COUNT",
				     alink($url3, $pfam_count) );
    } else {
    	GeneDetail::printAttrRowRaw( "PFAM_COUNT", 0);
    }
    my $gene_count = getGeneCountForCluster
	($dbh, $taxon_oid, $in_file, $cluster_id);
    GeneDetail::printAttrRowRaw( "GENE_COUNT", $gene_count);

    my $len = $end - $start + 1;
    GeneDetail::printAttrRowRaw( "LENGTH", $len . " bps" );

    # add Export links:
    my $export_url = $section_cgi."&page=geneExport"
	. "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    my $sid = getContactOid();
    my $track = "_gaq.push(['_trackEvent', 'Export', '$sid', 'img link ExportGenes']);";
    my $fna_url = $export_url . "&fasta=fna";
    my $fna_link = "<a href=javascript:setRange('$fna_url') " .
	           "onclick='$track'>fna</a>";
    my $faa_link = alink($export_url."&fasta=faa", "faa", "", "", "", $track);
    my $genbank_link = alink($export_url."&fasta=genbank", "genbank", "", "", "", $track);

    my $bps = nbsp(2);
    $bps .= "<input type='text' size='3' name='up_stream' value='-0'/>";
    $bps .= "bp upstream";
    $bps .= nbsp(2);
    $bps .= "<input type='text' size='3' name='down_stream' value='+0'/>";
    $bps .= "bp downstream";
    $bps .= "<br/>";

    print qq{
        <script language="JavaScript" type="text/javascript">
        function setRange(url) {
            for (var i=0; i<document.detailForm.elements.length; i++) {
                var el = document.detailForm.elements[i];
                if (el.type == "text") {
                    if (el.name == "up_stream") {
                        url = url+"&up_stream="+el.value;
                    } else if (el.name == "down_stream") {
                        url = url+"&down_stream="+el.value;
                    }
                }
            }
            window.location = url;
            return url;
        }
        </script>
    };

    GeneDetail::printAttrRowRaw("Export", 
        "$fna_link $bps" . "$faa_link" . "<br/>$genbank_link");

    print "</table>\n";
    print end_form();
    print "</div>"; # end biodetailtab1

    print "<div id='biodetailtab2'>";
    print "<h2>Genes in Cluster</h2>";
    printBioClusterGeneList($taxon_oid, $cluster_id);
    print "</div>"; # end biodetailtab2

    print "<div id='biodetailtab3'>";
    print "<h2>Cluster Neighborhood</h2>";
    printNeighborhoods($taxon_oid, $cluster_id, $in_file, $mygene);
    print "</div>"; # end biodetailtab3

    print "<div id='biodetailtab4'>";
    print "<h2>Secondary Metabolite</h2>";
    printBioClusterNPList($dbh, $cluster_id, $taxon_oid);
    ## MyIMG annotation
    printMyIMGBioClusterNPList($dbh, $cluster_id, $taxon_oid);
    print "</div>"; # end biodetailtab4

    print "<div id='biodetailtab5'>";
    if ( $in_file eq 'Yes' ) {
    	print "<h2>IMG Pathways</h2>\n"; 
    	print "<p>No IMG Pathways.\n";
    } else {
    	printClusterPathwayList( $dbh, $taxon_oid, $cluster_id, 0, $np_name );
    }
    print "</div>"; # end biodetailtab5

    print "<div id='biodetailtab6'>";
    if ( $in_file eq 'Yes' ) {
    	printClusterMetacycList_meta($taxon_oid, $cluster_id, $np_name);
    } else {
    	printClusterMetacycList($taxon_oid, $cluster_id, $np_name);
    }
    print "</div>"; # end biodetailtab6

    print "<div id='biodetailtab7'>";
    if ( $in_file eq 'Yes' ) {
    	printClusterKEGGList_meta($taxon_oid, $cluster_id);
    } else {
    	printClusterKEGGList($taxon_oid, $cluster_id);
    }
    print "</div>"; # end biodetailtab7

    TabHTML::printTabDivEnd();
}

sub translateBcType {
    my ($dbh, $bc_type) = @_;
    my %bc_typ_h; 
    my $sql2 = "select bc_code, bc_desc from bc_type"; 
    my $cur2 = execSql($dbh, $sql2, $verbose);
    for ( ;; ) {
        my ($bc_code, $bc_desc) = $cur2->fetchrow();
        last if !$bc_code;
        $bc_typ_h{$bc_code} = $bc_desc; 
    }
    $cur2->finish();

    my $str = ""; 
    for my $t2 ( split(/\;/, $bc_type) ) { 
        my $res2 = $t2; 
        if ( $bc_typ_h{$t2} ) {
            $res2 = $bc_typ_h{$t2};
        } 
 
        if ( $str ) { 
            $str .= ";" . $res2; 
        } 
        else { 
            $str = $res2; 
        } 
    } 
 
    return $str; 
}


sub getGeneCountForCluster {
    my ($dbh, $taxon_oid, $in_file, $cluster_id) = @_;

    my $sql = qq{
        select count(distinct g.gene_oid)
        from bio_cluster_features_new bcg, gene g
        where bcg.cluster_id = ?
        and g.taxon = ?
        and bcg.feature_id = g.gene_oid
        --and bcg.gene_oid = g.gene_oid
        and bcg.feature_type = 'gene'
    };
    if ($in_file eq 'Yes') {
        $sql = qq{
            select count(distinct bcg.feature_id)
            from bio_cluster_features_new bcg, bio_cluster_new bc
            where bcg.cluster_id = ?
            and bc.taxon = ?
            and bc.cluster_id = bcg.cluster_id
            and bcg.feature_type = 'gene'
        };
    }
    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    my ($count) = $cur->fetchrow();
    return $count;
}

sub printFastaForCluster {
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $scaffold_oid = param("scaffold_oid");
    my $start = param("start");
    my $end = param("end");

    my $dbh = dbLogin();
    my $sql = MerFsUtil::getSingleTaxonOidAndNameFileSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($tid2, $taxon_name, $in_file) = $cur->fetchrow();
    $cur->finish();

    my $seq;
    if ($in_file eq "Yes") {
	my $allseq = MetaUtil::getScaffoldFna
	    ($taxon_oid, "assembled", $scaffold_oid);
	$seq = MetaUtil::getSequence( $allseq, $start, $end );

    } else {
	my $sql = qq{
        select scf.ext_accession
        from scaffold scf
        where scf.taxon = ?
        and scf.scaffold_oid = ?
        and scf.ext_accession is not null
        };
	my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $scaffold_oid);
	my ($ext_accession) = $cur->fetchrow();
	
	my $taxon_lin_fna_dir = $env->{ taxon_lin_fna_dir };
	my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
	$seq = WebUtil::readLinearFasta
	    ($path, $ext_accession, $start, $end, "+");
    }

    print "<h1>FASTA Nucleic Acid Sequence</h1>";
    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
	     . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>";

    my $seq2 = WebUtil::wrapSeq($seq);
    print "<pre>\n";
    print $seq2;
    print "</pre>\n";
}

sub exportClusterGenes {
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $fasta = param("fasta");

    my $genes_aref = getBioClusterGeneList($taxon_oid, $cluster_id);

    if ( $fasta eq "genbank" ) {
        exportClusterGenbankFile($taxon_oid, $cluster_id, $genes_aref);
    }
    else {
        my $isAA = 0;
        $isAA = 1 if $fasta eq "faa";
    
        my $upstream = param("up_stream");
        my $downstream = param("down_stream");
    
        require GenerateArtemisFile;
        GenerateArtemisFile::processFastaFile($genes_aref, $isAA, 0, "gene");
    }
}

sub exportClusterGenbankFile {
    my ($taxon_oid, $cluster_id, $genes_aref) = @_;
    
    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    #Get cluster boundaries
    my $sql = qq{
        select a.attribute_value, b.attribute_value 
        from bio_cluster_data a, bio_cluster_data b 
        where a.cluster_id= ? 
        AND b.cluster_id= ?
        AND a.attribute_type ='START_ON_CHROMOSOME' 
        AND b.attribute_type='END_ON_CHROMOSOME'
    };
    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $cluster_id);
    my ($low, $high) = $cur->fetchrow();
    $cur->finish();
    #print "exportClusterGenbankFile() $low $high<br/>\n";

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$genes_aref );
    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag, 
            g.start_coord, g.end_coord, g.strand, g.cds_frag_coord, 
            g.scaffold, s.ext_accession, g.taxon
        from gene g, scaffold s
        where g.scaffold = s.scaffold_oid
        and g.gene_oid in ( $gene_oid_str )
    };

    my $cur = execSql($dbh, $sql, $verbose);

    my %scaf2geneData;
    for ( ;; ) {
        my ($gene_oid, $gene_display_name, $locus_tag, 
            $start_coord, $end_coord, $strand_sym, $cds_frag_coord, 
            $scaffold, $ext_accession, $taxon) = $cur->fetchrow();
        last if(!$gene_oid);

        my $g_start = $start_coord - $low + 1;
        my $g_end = $end_coord - $low + 1;                
        my $strand;
        if ( $strand_sym eq "+" ){
            $strand = 1;
        } elsif ( $strand_sym eq "-" ){
            $strand = -1;
        }
        else { 
            print "Error Reading Strand Information: $strand_sym\n"
        };

        my $geneData_href = $scaf2geneData{$ext_accession};
        if ( ! $geneData_href ) {
            my %geneData_h;
            $geneData_href = \%geneData_h;
            $scaf2geneData{$ext_accession} = $geneData_href;
        }
        if ( $cds_frag_coord !~ 'join'){
            $geneData_href->{$gene_oid} = {
                start => $g_start,
                end  => $g_end,
                strand => $strand,
                product => $gene_display_name,                    
            };
        }
        else {
            #Process Genes with split coordinates
            $geneData_href->{$gene_oid} = {
                coords => $cds_frag_coord,
                start => $g_start,
                end  => $g_end,
                strand => $strand,
                product => $gene_display_name,                    
            };
        }

    }    
    #print "exportClusterGenbankFile() scaf2geneData=<br/>\n";
    #print Dumper(\%scaf2geneData) . "<br/>\n";

    print "<h1>Export Biosynthetic Cluster Genebank File</h1>\n";
    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>";

    require SequenceExportUtil;
    SequenceExportUtil::exportGenbankFile($taxon_oid, \%scaf2geneData, $low, $high);
}


#########################################################################
# getBioClusterGeneList
#########################################################################
sub getBioClusterGeneList {
    my ($taxon_oid, $cluster_id) = @_;

    my $dbh = dbLogin();
    my $sql = "select genome_type, in_file from taxon where taxon_oid = ?";
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid);
    my ($genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    if ( $in_file eq "Yes" ) {
        $sql = qq{
            select distinct bcg.feature_id, bcg.feature_id, bcg.feature_id
            from bio_cluster_features_new bcg, bio_cluster_new bc
            where bcg.cluster_id = ?
            and bc.taxon = ?
            and bc.cluster_id = bcg.cluster_id
            and bcg.feature_type = 'gene'
        };
    }
    else {
        $sql = qq{
            select distinct bcg.feature_id, g.locus_tag, g.gene_display_name
            from bio_cluster_features_new bcg, gene g
            where bcg.cluster_id = ?
            and g.taxon = ?
            and bcg.feature_id = g.gene_oid
            and bcg.feature_type = 'gene'
        };
    }

    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    my @genes;
    for ( ;; ) {
        my ($gene_oid, $locus_tag, $gene_name) = $cur->fetchrow();
        last if(!$gene_oid);
	if ($in_file eq "Yes") {
	    push( @genes, $taxon_oid." assembled ".$gene_oid );
	} else {
	    push( @genes, $gene_oid );
	}
    }
    return \@genes;
}

##########################################################################
# printBioClusterGeneList
##########################################################################
sub printBioClusterGeneList {
    my ($taxon_oid, $cluster_id, $gene_aref, $show_title) = @_;
    $taxon_oid = param("taxon_oid") if $taxon_oid eq "";
    $cluster_id = param("cluster_id") if $cluster_id eq "";

    my $dbh = dbLogin();
    if ($show_title) {
    	my $sql = qq{
            select bc.cluster_id, t.taxon_oid, t.in_file,
                   $nvl(t.taxon_name, t.taxon_display_name)
            from bio_cluster_new bc, taxon t
            where bc.cluster_id = ?
            and bc.taxon = t.taxon_oid
        };
    	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
    	my ($id2, $taxon_oid2, $in_file, $taxon_name) = $cur->fetchrow();
    	$cur->finish();
    	if ( !$taxon_oid || !isInt($taxon_oid) ) {
    	    $taxon_oid = $taxon_oid2;
    	}
	
    	print "<h1>Genes in Cluster</h1>";
    	print "<p style='width: 650px;'>";
    	my $url1 = "$main_cgi?section=TaxonDetail"
    	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    	print "Genome: " . alink( $url1, $taxon_name );
    	print " (assembled)" if $in_file eq "Yes";
    	my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    	print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    	print "</p>";
    }

    my $sql = "select genome_type, in_file from taxon where taxon_oid = ?";
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid);
    my ($genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    my %bbh_gene;
    my %bbh_taxon;
    my %taxon_name_h;

    my $use_phylo_dist = 0;
    my $isTaxonInFile = 0;
    $isTaxonInFile = 1 if $in_file eq "Yes";

    print "<p>You may select genes to look for <u>similar clusters</u> based on Pfams associated with these gene(s).</p>";

    ## get best hit
    my $hint;
    if ( $isTaxonInFile || $genome_type eq 'metagenome' ) {
    	my $phyloDist_date = PhyloUtil::getPhyloDistDate( $dbh, $taxon_oid );
    	$hint = ""#"<b><font color='red'>PLEASE NOTE</font></b>: <br/>"
	      . "Best hit gene information is based on data that was " 
	      . "pre-computed on <b><font color='red'>" 
	      . $phyloDist_date . "</font></b>.<br/>";
    	# get best hit later in the code
    }
    elsif ( $use_phylo_dist ) {
    	my $phyloDist_date = PhyloUtil::getPhyloDistDate( $dbh, $taxon_oid );
    	$hint = ""#"<b><font color='red'>PLEASE NOTE</font></b>: <br/>"
	      . "Best hit gene information is based on data that was " 
	      . "pre-computed on <b><font color='red'>" 
	      . $phyloDist_date . "</font></b>.<br/>";

    	getBcBestHit_phylodist($dbh, $taxon_oid, $cluster_id, \%bbh_gene,
			       \%bbh_taxon, \%taxon_name_h);
    }
    else {
    	getBcBestHit_bbh($dbh, $taxon_oid, $cluster_id, \%bbh_gene,
			 \%bbh_taxon, \%taxon_name_h);
    }

    ## predicted or experimental?
    my $sql = "select evidence from bio_cluster_data_new " .
	      "where cluster_id = ? ";
    my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
    my ($evid_type) = $cur->fetchrow();
    $cur->finish();

    $hint .= "Pfam Info is based on <font color='darkgreen'>Pfams associated with genes</font> in this cluster.";

    printHint($hint);
    print "<br/>";

    ## get gene-pfam for isolates, not infile:
    my %gene_pfam_h;
    my $sql = qq{
        select distinct gpf.gene_oid, 1, 1,
               gpf.pfam_family, pf.description
        from bio_cluster_features_new bcg, pfam_family pf,
             gene_pfam_families gpf
        where bcg.cluster_id = ?
        and bcg.feature_type = 'gene'
        and bcg.gene_oid = gpf.gene_oid
        and gpf.pfam_family = pf.ext_accession
    };
    # for $infile, get genes for the cluster, then look in files:
    if (!$isTaxonInFile) {
	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
	for ( ;; ) {
	    my ($feature_id, $start_coord, $prob, $pfam_id, $pfam_name) =
		$cur->fetchrow();
	    last if(!$feature_id);
	    
	    my $str = "$start_coord\t$prob\t$pfam_id\t$pfam_name";
	    if ($gene_pfam_h{$feature_id}) {
		$gene_pfam_h{$feature_id} .= "\n" . $str;
	    }
	    else {
		$gene_pfam_h{$feature_id} = $str;
	    }
	}
	$cur->finish();
    }

    my $sql;
    if ( $isTaxonInFile ) {
    	$sql = qq{
            select distinct bcg.feature_id, bcg.feature_id, bcg.feature_id
            from bio_cluster_features_new bcg, bio_cluster_new bc
            where bcg.cluster_id = ?
            and bc.taxon = ?
            and bc.cluster_id = bcg.cluster_id
            and bcg.feature_type = 'gene'
        };
    }
    else {
        $sql = qq{
            select distinct bcg.feature_id, g.locus_tag, g.gene_display_name
            from bio_cluster_features_new bcg, gene g
            where bcg.cluster_id = ?
            and g.taxon = ?
            and bcg.feature_id = g.gene_oid
            and bcg.feature_type = 'gene'
        };
    }
    
    print start_form(-id     => "bcgenes_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");

    print hiddenVar('taxon_oid',  $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    print "<script src='$base_url/checkSelection.js'></script>\n";

    my $it = new InnerTable( 1, "bcgenes$$", "bcgenes", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Pfam Info", "asc", "left" );
    $it->addColSpec( "Best Hit Gene", "asc", "right" );
    $it->addColSpec( "Best Hit Genome", "asc", "left" );

    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    my $row = 0;
    for ( ;; ) {
        my ($gene_oid, $locus_tag, $gene_name) = $cur->fetchrow();
        last if(!$gene_oid);

    	if ( $gene_aref ) {
    	    push(@$gene_aref, $gene_oid);
    	}
    
        my $workspce_id = $gene_oid;
        if ( $isTaxonInFile ) {
            $workspce_id = "$taxon_oid assembled $gene_oid";
        }
        
    	my $r = $sd . "<input type='checkbox' name='gene_oid' "
    	            . "value='$workspce_id' /> \t"; 
    
    	my $url = "$main_cgi?section=GeneDetail"
    	        . "&page=geneDetail&gene_oid=$gene_oid"; 
    	if ( $isTaxonInFile ) {
    	    $url = "$main_cgi?section=MetaGeneDetail"
    	         . "&page=geneDetail&gene_oid=$gene_oid"
    		 . "&taxon_oid=$taxon_oid&data_type=assembled";
    	}
    	$r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
     	$r .= $locus_tag . $sd . $locus_tag . "\t";
    
    	if ( $isTaxonInFile ) {
    	    my ($n2, $src2) = MetaUtil::getGeneProdNameSource
    		($gene_oid, $taxon_oid, 'assembled');
    
    	    if ( $n2 ) {
    		$gene_name = $n2;
    	    }
    	    else {
    		$gene_name = 'hypothetical protein';
    	    }
    	}
    
     	$r .= $gene_name . $sd . $gene_name . "\t";
    
    	my $str = "";
	if ( $isTaxonInFile) {
	    my @pfamids = MetaUtil::getGenePfamId
    		($gene_oid, $taxon_oid, 'assembled');
	    my $pfam_names_ref = getPfamNames($dbh, \@pfamids);

	    foreach my $pfam_id (@pfamids) {
		my $ext_accession2 = $pfam_id;
		$ext_accession2 =~ s/pfam/PF/;
		my $url = "$pfam_base_url$ext_accession2";
		my $pfam_name = $pfam_names_ref->{ $pfam_id };
		if ( $str && $str ne "") {
		    $str .= "; ";
		}
		$str .= alink( $url, $pfam_id ) . " " . $pfam_name;
	    }
	}

    	my @lines = split(/\n/, $gene_pfam_h{$gene_oid});
    	foreach my $line ( @lines ) {
    	    my ($start_coord, $prob, $pfam_id, $pfam_name) = 
		split(/\t/, $line, 4);
    	    if ( $prob ) {
    		$prob = sprintf( "%.2f", $prob );
    	    }
    
    	    if ( $str && $str ne "") {
    		$str .= "; ";
    	    }
    
    	    if ( $pfam_id ) {
    		my $ext_accession2 = $pfam_id;
    		$ext_accession2 =~ s/pfam/PF/; 
    		my $url = "$pfam_base_url$ext_accession2";
    		$str .= alink( $url, $pfam_id ) . " " . $pfam_name;
    	    }
    	    else {
    		$str .= "-";
    	    }

	    if ( $evid_type eq 'Predicted' ) {
		$str .= " (prob: $prob, start_coord: $start_coord)";
	    }
    	}
     	$r .= $str . $sd . $str . "\t";
    
    	if ( $isTaxonInFile || $genome_type eq 'metagenome' ) {
    	    my $bbh = MetaUtil::getGeneBBH($taxon_oid, 'assembled', $gene_oid);
    	    if ( $bbh ) {
    		my ($id2, $perc, $homolog, $homo_taxon, @rest) =
    		    split(/\t/, $bbh);
    		$bbh_gene{$gene_oid} = $homolog;
    		$bbh_taxon{$gene_oid} = $homo_taxon;
    		if ( ! $taxon_name_h{$homo_taxon} ) {
    		    $taxon_name_h{$homo_taxon} = 
    			WebUtil::taxonOid2Name($dbh, $homo_taxon);
    		}
    	    }
    	}
    
    	if ( $bbh_gene{$gene_oid} ) {
    	    my $gene2 = $bbh_gene{$gene_oid};
    	    my $url2 = "$main_cgi?section=GeneDetail"
    	        . "&page=geneDetail&gene_oid=$gene2"; 
    	    $r .= $gene2 . $sd . alink( $url2, $gene2 ) . "\t";
    	}
    	else {
    	    $r .= "-" . $sd . "-" . "\t";
    	}
    
    	if ( $bbh_taxon{$gene_oid} ) {
    	    my $taxon2 = $bbh_taxon{$gene_oid};
    	    my $url2 = "$main_cgi?section=TaxonDetail"
    	        . "&page=taxonDetail&taxon_oid=$taxon2"; 
    	    $r .= $taxon_name_h{$taxon2} . $sd . 
    		alink( $url2, $taxon_name_h{$taxon2} ) . "\t";
    	}
    	else {
    	    $r .= "-" . $sd . "-" . "\t";
    	}

        $it->addRow($r); 
    	$row++;
    }
    $cur->finish();

    WebUtil::printGeneCartFooter("bcgenes") if $row > 10;
    #$it->hideAll() if $row < 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter("bcgenes");

    ## protein domain display
    my $super_user_flag = getSuperUser(); 
    if (0) { #if ( $super_user_flag eq 'Yes' ) {
        print "<div id='geneprotein'>"; 
        print "<h2>Find Similar Biosynthetic Clusters</h2>\n"; 
        print "<p><font color='red'>This feature is available for super users only.</font>\n"; 
        print "<p>Select one or more genes to search. " 
	    . "The result is based on Pfams associated with the selected gene(s).<br/>\n"; 
	my $name = "_section_BiosyntheticDetail_findSimilarBCGF"; 
        print submit( 
            -name  => $name, 
            -value => 'Find Similar Clusters', 
	    -class   => 'meddefbutton',
	    -onclick => "return validateGeneSelection(1, 'bcgenes_frm');"
	); 
        print "<br/>\n"; 
        print "</div>\n"; 

        print "<div id='geneprotein'>"; 
        print "<h2>Display Protein Domains of Selected Genes</h2>\n"; 
        print "<p><font color='red'>This feature is available for super users only.</font>\n"; 
        print "<p>Select 1 to $maxGeneProfileIds genes to view protein domains.<br/>\n"; 
        my $name = "_section_WorkspaceGeneSet_viewProteinDomain"; 
        print submit( 
            -name  => $name, 
            -value => 'View Protein Domains', 
            -class => 'meddefbutton' 
        ); 
        print "<br/>\n"; 
        print "</div>\n"; 
    } 

    print end_form();
    printStatusLine( "$row genes in cluster.", 2 ); 
}

sub getPfamNames {
    my ($dbh, $pfam_aref) = @_;
    my @pfams = @$pfam_aref;
    my $pfam_str = WebUtil::joinSqlQuoted(",", @pfams);
    my $sql = qq{
        select gpf.pfam_family, pf.description
        from gene_pfam_families gpf, pfam_family pf
        where gpf.pfam_family = pf.ext_accession
        and gpf.pfam_family in ($pfam_str)
    };
    my $cur = execSql($dbh, $sql, $verbose);
    my %pfam2name;
    for ( ;; ) {
	my ($pfam_id, $pfam_name) = $cur->fetchrow();
	last if !$pfam_id;
	$pfam2name{ $pfam_id } = $pfam_name;
    }
    $cur->finish();

    return \%pfam2name;
}

##########################################################################
# printBioClusterNPList
##########################################################################
sub printBioClusterNPList {
    my ($dbh, $cluster_id, $taxon_oid) = @_;

    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon'); 

    my $sql = qq{
        select npbs.cluster_id, bc.taxon, 
               npbs.compound_oid, cpd.compound_name,
               cpd.np_class, cpd.np_sub_class,
               npbs.ncbi_acc, npbs.ncbi_taxon,
               npbs.is_partial, c.name, npbs.mod_date
        from np_biosynthesis_source\@img_ext npbs, contact c,
             img_compound cpd, bio_cluster_new bc
        where npbs.cluster_id = ?
        and npbs.cluster_id = bc.cluster_id
        and npbs.compound_oid = cpd.compound_oid
        and npbs.modified_by = c.contact_oid (+)
    };

    my $cur;
    if ( $taxon_oid && isInt($taxon_oid) ) {
	$sql .= " and bc.taxon = ? ";
	$cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    }
    else {
	$cur = execSql($dbh, $sql, $verbose, $cluster_id);
    }

    print start_form(-id     => "bcNpList_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");
    print hiddenVar('taxon_oid',  $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    #my $it = new InnerTable( 1, "bcNpList$$", "bcNpList", 1 );
    my $it = new StaticInnerTable();
    my $super_user = getSuperUser(); 
    if ( $super_user eq 'Yes' ) {
	$it->addColSpec( "Select" );
    }
    $it->addColSpec( "Compound ID", "asc", "right" );
    $it->addColSpec( "Secondary Metabolite (SM) Name", "asc", "left" );
    $it->addColSpec( "SM Class", "asc", "left" );
    $it->addColSpec( "SM Subclass", "asc", "left" );
    $it->addColSpec( "NCBI Accession", "asc", "left" );
    $it->addColSpec( "NCBI Taxon ID", "number asc", "right" );
    $it->addColSpec( "Is Partial", "asc", "left" );
    $it->addColSpec( "Modified By", "asc", "left" );
    $it->addColSpec( "Mod Date", "asc", "left" );
    my $sd = $it->getSdDelim();

    my $row = 0;
    for ( ;; ) {
        my ($clu_id, $tx_id, $compound_oid, 
	    $compound_name, $np_class, $np_sub_class,
	    $ncbi_acc, $ncbi_taxon,
	    $is_partial, $modified_by, $mod_date) =
		$cur->fetchrow();
        last if(!$clu_id);

	my $r = "";
	if ( $super_user eq 'Yes' ) {
	    $r .= $sd . "<input type='radio' id='compound_oid' " .
		"name='compound_oid' " .
		"value='$compound_oid' /> \t"; 
	}

    	my $url = "$main_cgi?section=ImgCompound"
    	        . "&page=imgCpdDetail&compound_oid=$compound_oid"; 
    	$r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
     	$r .= $compound_name . $sd . $compound_name . "\t";
     	$r .= $np_class . $sd . $np_class . "\t";
     	$r .= $np_sub_class . $sd . $np_sub_class . "\t";
     	$r .= $ncbi_acc . $sd . $ncbi_acc . "\t";
     	$r .= $ncbi_taxon . $sd . $ncbi_taxon . "\t";
     	$r .= $is_partial . $sd . $is_partial . "\t";
     	$r .= $modified_by . $sd . $modified_by . "\t";
     	$r .= $mod_date . $sd . $mod_date . "\t";
    
        $it->addRow($r); 
    	$row++;
    }
    $cur->finish();

    if ( $row ) {
	#$it->hideAll() if $row < 10;
	$it->printOuterTable(1);
    }
    else {
	print "<p>This biosynthetic cluster has no known secondary metabolite.<br/>\n";
    }

    if ( $super_user eq 'Yes' ) {
	my $name = "_section_${section}_addBCNP";
	my $buttonLabel = "Add Secondary Metabolite";
	my $buttonClass = "meddefbutton";
	print submit( 
	    -name  => $name,
	    -value => $buttonLabel, 
	    -class => $buttonClass
	    ); 

	if ( $row ) {
	    my $name = "_section_${section}_updateBCNP";
	    my $buttonLabel = "Update Secondary Metabolite";
	    my $buttonClass = "medbutton";
            print nbsp(1);
	    print submit( 
                  -name  => $name,
                  -value => $buttonLabel, 
                  -class => $buttonClass
		); 

	    my $name = "_section_${section}_deleteBCNP";
	    my $buttonLabel = "Delete Secondary Metabolite";
	    my $buttonClass = "medbutton";
            print nbsp(1);
	    print submit( 
                  -name  => $name,
                  -value => $buttonLabel, 
                  -class => $buttonClass
		); 
	}
    }

    print end_form();

    return $row;
}

##########################################################################
# printMyIMGBioClusterNPList
##########################################################################
sub printMyIMGBioClusterNPList {
    my ($dbh, $cluster_id, $taxon_oid) = @_;

    my $contact_oid = getContactOid();
    if ( ! $contact_oid ) {
	return 0;
    }

    my $dbh = dbLogin();

    my $sql = "select img_group from contact where contact_oid = ? ";
    my $cur = execSql($dbh, $sql, $verbose, $contact_oid);
    my ($my_group) = $cur->fetchrow();
    $cur->finish();

    my $rclause   = WebUtil::urClause('np.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('np.taxon_oid'); 

    my $sql = qq{
        select np.cluster_id, np.taxon_oid, 
               np.compound_oid, cpd.compound_name,
               cpd.np_class, cpd.np_sub_class,
               np.ncbi_acc, np.ncbi_taxon,
               np.is_partial, np.is_public, np.comments,
               c.contact_oid, c.name, c.img_group, np.mod_date
        from myimg_bio_cluster_np\@img_ext np, contact c,
             img_compound cpd
        where np.cluster_id = ?
        and np.compound_oid = cpd.compound_oid
        and np.modified_by = c.contact_oid
        $rclause
        $imgClause
    };

    my $cur;
    if ( $taxon_oid && isInt($taxon_oid) ) {
	$sql .= " and np.taxon_oid = ? ";
	$cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    }
    else {
	$cur = execSql($dbh, $sql, $verbose, $cluster_id);
    }

    my $super_user = getSuperUser(); 

    print start_form(-id     => "myimgBcNpList_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");
    print hiddenVar('taxon_oid',  $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    #my $it = new InnerTable( 1, "myimgBcNpList$$", "myimgBcNpList", 1 );
    my $it = new StaticInnerTable();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Compound ID", "asc", "right" );
    $it->addColSpec( "Secondary Metabolite (SM) Name", "asc", "left" );
    $it->addColSpec( "SM Class", "asc", "left" );
    $it->addColSpec( "SM Subclass", "asc", "left" );
    $it->addColSpec( "NCBI Accession", "asc", "left" );
    $it->addColSpec( "NCBI Taxon ID", "number asc", "right" );
    $it->addColSpec( "Is Partial", "asc", "left" );
    $it->addColSpec( "Is Public", "asc", "left" );
    $it->addColSpec( "Comments", "asc", "left" );
    $it->addColSpec( "Modified By", "asc", "left" );
    $it->addColSpec( "Mod Date", "asc", "left" );
    my $sd = $it->getSdDelim();

    my $cnt = 0;
    my $row = 0;
    for ( ;; ) {
        my ($clu_id, $tx_id, $compound_oid, 
	    $compound_name, $np_class, $np_sub_class,
	    $ncbi_acc, $ncbi_taxon,
	    $is_partial, $is_public, $comments,
	    $modified_by_oid, $modified_by,
	    $img_group, $mod_date) =
		$cur->fetchrow();
        last if(!$clu_id);

	## check permission
	if ( $super_user eq 'Yes' ) {
	    # super user
	} elsif ( $is_public eq 'Yes' ) {
	    # public annotation
	} elsif ( $contact_oid == $modified_by_oid ) {
	    # my own annotation
	} elsif ( $my_group && $img_group &&
		($my_group == $img_group) ) {
	    # group annotation
	} else {
	    # no privilege
	    next;
	}

	my $r = "";

	if ( $contact_oid == $modified_by_oid ) {
	    # my annotation
	    $r .= $sd . "<input type='radio' id='myimg_bc_np' " .
		"name='myimg_bc_np' " .
		"value='$compound_oid,$tx_id,$clu_id' /> \t"; 
	    $cnt++;
	} else {
	    $r .= " " . $sd . " " . "\t";
	}

    	my $url = "$main_cgi?section=ImgCompound"
    	        . "&page=imgCpdDetail&compound_oid=$compound_oid"; 
    	$r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
     	$r .= $compound_name . $sd . $compound_name . "\t";
     	$r .= $np_class . $sd . $np_class . "\t";
     	$r .= $np_sub_class . $sd . $np_sub_class . "\t";
     	$r .= $ncbi_acc . $sd . $ncbi_acc . "\t";
     	$r .= $ncbi_taxon . $sd . $ncbi_taxon . "\t";
     	$r .= $is_partial . $sd . $is_partial . "\t";
     	$r .= $is_public . $sd . $is_public . "\t";
     	$r .= $comments . $sd . $comments . "\t";
     	$r .= $modified_by . $sd . $modified_by . "\t";
     	$r .= $mod_date . $sd . $mod_date . "\t";
    
        $it->addRow($r); 
    	$row++;
    }
    $cur->finish();

    print "<h2>MyIMG Annotations</h2>\n";

    if ( $row ) {
	#$it->hideAll() if $row < 10;
	$it->printOuterTable(1);
    }
    else {
	print "<p>There are no MyIMG annotations.<br/>\n";
    }

    my $name = "_section_${section}_addMyIMGBCNP";
	my $buttonLabel = "Add SM Annotation";
	my $buttonClass = "meddefbutton";
	print submit( 
	    -name  => $name,
	    -value => $buttonLabel, 
	    -class => $buttonClass
	    ); 

    if ( $cnt ) {
	my $name = "_section_${section}_updateMyIMGBCNP";
	my $buttonLabel = "Update Annotation";
	my $buttonClass = "medbutton";
	print nbsp(1);
	print submit( 
	    -name  => $name,
	    -value => $buttonLabel, 
	    -class => $buttonClass
	    ); 

	my $name = "_section_${section}_deleteMyIMGBCNP";
	my $buttonLabel = "Delete Annotation";
	my $buttonClass = "medbutton";
	print nbsp(1);
	print submit( 
	    -name  => $name,
	    -value => $buttonLabel, 
	    -class => $buttonClass
	    ); 
    }

    print end_form();
    return $row;
}


##########################################################################
# getBcBestHit_phylodist
##########################################################################
sub getBcBestHit_phylodist {
    my ($dbh, $taxon_oid, $cluster_id, $bbh_gene_h, $bbh_taxon_h,
	$taxon_name_h) = @_;

    my $sql = qq{
        select distinct dt.gene_oid, dt.homolog,
               t.taxon_oid, t.taxon_display_name
        from bio_cluster_features_new bcg, dt_phylum_dist_genes dt, taxon t
        where bcg.cluster_id = ?
        and dt.taxon_oid = ?
        and dt.homolog_taxon = t.taxon_oid
        and bcg.feature_id = dt.gene_oid
        --and bcg.gene_oid = dt.gene_oid
        and bcg.feature_type = 'gene'
    };

    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    for ( ;; ) {
        my ($gene_oid, $homolog, $homolog_taxon, $h_taxon_name) = 
	    $cur->fetchrow();
        last if(!$gene_oid);

	$bbh_gene_h->{$gene_oid} = $homolog;
	$bbh_taxon_h->{$gene_oid} = $homolog_taxon;
	if ( $homolog_taxon ) {
	    $taxon_name_h->{$homolog_taxon} = $h_taxon_name;
	}
    }
    $cur->finish();
}


###############################################################################
# getBcBestHit_bbh
###############################################################################
sub getBcBestHit_bbh {
    my ($dbh, $taxon_oid, $cluster_id, $bbh_gene_h, $bbh_taxon_h, 
	$taxon_name_h) = @_;

    my $bbh_dir = $env->{bbh_zfiles_dir};
    $taxon_oid = sanitizeInt($taxon_oid);
    my $bbh_file_name = $bbh_dir . "/" . $taxon_oid . ".zip";

    if ( ! blankStr($bbh_file_name) && (-e $bbh_file_name) ) { 
	# yes, we have file
    }
    else {
	return;
    }

    my %public_taxons;
    my $sql = qq{
	select taxon_oid, taxon_display_name
        from taxon
	where is_public = 'Yes'
	and obsolete_flag = 'No' 
	and genome_type = 'isolate'
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($taxon_oid, $taxon_name) = $cur->fetchrow();
        last if(!$taxon_oid);
	$public_taxons{$taxon_oid} = $taxon_name;
    }
    $cur->finish();

    unsetEnvPath();

    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name
        from bio_cluster_features_new bcg, gene g
        where bcg.cluster_id = ?
        and g.taxon = ?
        and bcg.feature_id = g.gene_oid
        --and bcg.gene_oid = g.gene_oid
        and bcg.feature_type = 'gene'
    };

    my $cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    for ( ;; ) {
        my ($gene_oid, $locus_tag, $gene_name) = $cur->fetchrow();
        last if(!$gene_oid);

	# open file
	my $rfh = newUnzipFileHandle
	    ( $bbh_file_name, $gene_oid, "getBBHZipFiles" ); 
	while ( my $s = $rfh->getline() ) { 
	    chomp $s; 
	    my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
		 $qstart, $qend, $sstart, $send, $evalue, $bitScore ) 
		= split( /\t/, $s ); 
	    my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
	    my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

	    if ( $staxon && $public_taxons{$staxon} ) {
		$bbh_gene_h->{$gene_oid} = $sgene_oid;
		$bbh_taxon_h->{$gene_oid} = $staxon;
		$taxon_name_h->{$staxon} = $public_taxons{$staxon};
		last;
	    }
	}  # end while
	close $rfh;

    }   # end for
    WebUtil::resetEnvPath();

    $cur->finish();
}

###############################################################################
# getBioClusterPfamCount
###############################################################################
sub getBioClusterPfamCount {
    my ($cluster_id, $taxon_oid, $in_file) = @_;
    if ( ! $cluster_id ) {
	return 0;
    }

    my $dbh = dbLogin();
    my $count = 0;

    if ($in_file eq "Yes") {
        my $sql = qq{
            select distinct bcg.feature_id
            from bio_cluster_features_new bcg
            where bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
        };
        my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
        my %cluster_pfams;
        for ( ;; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;

            my @pfamids = MetaUtil::getGenePfamId
                ($gene_oid, $taxon_oid, 'assembled');
            foreach my $pfam_id (@pfamids) {
                $cluster_pfams{ $pfam_id }++;
            }
        }
	$count = scalar keys %cluster_pfams;

    } else {
	my $sql = qq{
        select count (distinct gpf.pfam_family)
        from bio_cluster_features_new bcg, 
             gene_pfam_families gpf
        where bcg.cluster_id = ?
        and bcg.feature_type = 'gene'
        and bcg.gene_oid = gpf.gene_oid
        };
	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
	($count) = $cur->fetchrow();
	$cur->finish();
    }

    return $count;
}

###############################################################################
# printBioClusterPfamList
###############################################################################
sub printBioClusterPfamList {
    my ($taxon_oid, $cluster_id) = @_;
    if ( ! $taxon_oid || ! $cluster_id ) {
    	return;
    }

    printMainForm();
    print "<h1>Biosynthetic Cluster Pfam List</h1>\n";

    print hiddenVar('taxon_oid',  $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    my $dbh = dbLogin();
    my $sql = MerFsUtil::getSingleTaxonOidAndNameFileSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($tid2, $taxon_name, $in_file) = $cur->fetchrow();
    $cur->finish();
    if ( ! $tid2 ) {
        webError("You have no permission on taxon $taxon_oid.");
    }

    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>";

    my $hint = "Pfam Info is based on <font color='darkgreen'>"
	. "Pfams associated with genes</font> in this cluster.";
    printHint($hint);
    print "<br/>";

    my @rows;
    my $count = 0;
    my $sd = InnerTable::getSdDelim();

    if ($in_file eq "Yes") {
        my $sql = qq{
            select distinct bcg.feature_id
            from bio_cluster_features_new bcg
            where bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
        };
	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
	my %cluster_pfams;
	for ( ;; ) {
	    my ($gene_oid) = $cur->fetchrow();
	    last if !$gene_oid;
	    
	    my @pfamids = MetaUtil::getGenePfamId
		($gene_oid, $taxon_oid, 'assembled');
            foreach my $pfam_id (@pfamids) {
		$cluster_pfams{ $pfam_id }++;
            }
        }
	$cur->finish();

	my @pfamids = keys %cluster_pfams;
	my $pfam_names_ref = getPfamNames($dbh, \@pfamids);
	foreach my $pfam_id (@pfamids) {
            my $r;
            $r .= $sd .
                "<input type='checkbox' name='func_id' value='$pfam_id' /> \t";
	    
	    my $pfam_name = $pfam_names_ref->{ $pfam_id };
	    my $link = $pfam_name;
            if ( $pfam_id ) {
                my $ext_accession2 = $pfam_id;
                $ext_accession2 =~ s/pfam/PF/;
                my $url = "$pfam_base_url$ext_accession2";
                $link = alink( $url, $pfam_name );
            }


            $r .= "$pfam_id\t";
            $r .= $pfam_name . $sd . $link . "\t";

            my $url = "$section_cgi&page=pfamGeneList&ext_accession=$pfam_id";
            $url .= "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";

	    my $gene_count = $cluster_pfams{ $pfam_id };
            $r   .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";

            push @rows, $r;
	    $count++;
	}

    } else {
	my $sql = qq{
            select distinct gpf.pfam_family,
                   pf.description, count(distinct gpf.gene_oid)
            from bio_cluster_features_new bcg, pfam_family pf,
                 gene_pfam_families gpf
            where bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
            and bcg.gene_oid = gpf.gene_oid
            and gpf.pfam_family = pf.ext_accession
            group by gpf.pfam_family, pf.description
        };
	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
	for ( ;; ) {
	    my ($pfam_id, $pfam_name, $gene_count) = $cur->fetchrow();
	    last if !$pfam_id;

	    my $r; 
	    $r .= $sd .
		"<input type='checkbox' name='func_id' value='$pfam_id' /> \t"; 
	    my $link = $pfam_name;
	    if ( $pfam_id ) {
		my $ext_accession2 = $pfam_id;
		$ext_accession2 =~ s/pfam/PF/;
		my $url = "$pfam_base_url$ext_accession2";
		$link = alink( $url, $pfam_name );
	    }


	    $r .= "$pfam_id\t"; 
	    $r .= $pfam_name . $sd . $link . "\t";

	    my $url = "$section_cgi&page=pfamGeneList&ext_accession=$pfam_id";
	    $url .= "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
	    $r   .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";

	    push @rows, $r;
	    $count++;
	}
	$cur->finish();
    }

    my $name = "_section_${section}_pfamGeneList"; 
    TaxonDetailUtil::print3ColGeneCountTable
	( 'pfam', \@rows, 'Pfam ID', 'Pfam Name',
	  $section, $name, "List Genes" ); 

    printStatusLine( "$count Pfam retrieved.", 2 ); 
    print end_form(); 
}

###############################################################################
# printPfamGeneList - Show genes under one protein family
###############################################################################
sub printBCPfamGeneList {
    printStatusLine( "Loading ...", 1 ); 

    my $dbh = dbLogin();
    my ($taxon_oid, $isTaxonInFile, $pfam_ids_ref, $funcId2Name_href,
	$gene_oids_ref) = getBCPfamGeneList($dbh);

    my $count = scalar(@$gene_oids_ref); 
    if ( $count == 1 ) { 
        my $gene_oid = ${$gene_oids_ref}[0];
    	if ( $isTaxonInFile ) {
    	    use MetaGeneDetail;
    	    MetaGeneDetail::printGeneDetail($gene_oid);
    	}
    	else {
    	    use GeneDetail;
    	    GeneDetail::printGeneDetail($gene_oid); 
    	}
    	return 0;
    } 
 
    printMainForm();
    print "<h1>Pfam Genes</h1>\n"; 
    
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );

    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail" 
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url, $taxon_name );
    print " (assembled)" if $isTaxonInFile;
    print "<br/>Pfam: ";
    foreach my $pfam_id (@$pfam_ids_ref) {
        my $funcName = $funcId2Name_href->{$pfam_id};
        print $pfam_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>";
     
    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" ); 
    $it->addColSpec( "Gene Product Name", "asc", "left" );

    if ( $isTaxonInFile ) {
    	foreach my $ws_id ( @$gene_oids_ref ) {
    	    my ($t2, $d2, $g2) = split(/ /, $ws_id);
    	    my $url =
    		"$main_cgi?section=MetaGeneDetail"
    	      . "&page=metaGeneDetail&data_type=$d2"
	      . "&taxon_oid=$t2&gene_oid=$g2";
    	    my $r = $sd . "<input type='checkbox' name='gene_oid' value='$ws_id' />\t";
    	    $r .= $g2 . $sd . alink( $url, $g2 ) . "\t";
    	    $r .= $g2 . $sd . $g2 . "\t";
    	    my $gene_name = MetaUtil::getGeneProdName( $g2, $t2, $d2);
    	    $r .= $gene_name . $sd . $gene_name . "\t";
    
    	    $it->addRow($r);
    	}
    }
    else {
        HtmlUtil::flushGeneBatchSorting( $dbh, $gene_oids_ref, $it, '', 1 );
    }
 
    WebUtil::printGeneCartFooter() if $count > 10;
    $it->hideAll() if $count < 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();
 
    if ( $count > 0 ) { 
    	WorkspaceUtil::printSaveGeneToWorkspace('gene_oid'); 
    } 
 
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form(); 
} 

###############################################################################
# getPfamGeneList - get genes under one protein family
###############################################################################
sub getBCPfamGeneList {
    my ( $dbh ) = @_;
    
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    if ( ! $cluster_id || ! $taxon_oid ) {
        return;
    }

    my @pfam_ids = param("ext_accession");
    if ( scalar(@pfam_ids) <= 0 ) { 
        @pfam_ids = param("func_id"); 
    } 
 
    if ( scalar(@pfam_ids) == 0 ) { 
        webError("No Pfam has been selected."); 
    } 
 
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my @gene_oids;
    my %funcId2Name;

    if ($isTaxonInFile) {
	my %mypfams;
	foreach my $item (@pfam_ids) { $mypfams{$item} = 1 }

        my $funcIdsInClause = TaxonDetailUtil::fetchPfamId2NameHash
            ( $dbh, \@pfam_ids, \%funcId2Name, 0 );

        my $sql = qq{
            select distinct bcg.feature_id
            from bio_cluster_features_new bcg
            where bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
        };
        my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
        my $row = 0;
        my %cluster_pfams;
        GENE: for ( ;; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;

            my @pfamids = MetaUtil::getGenePfamId
                ($gene_oid, $taxon_oid, 'assembled');
            foreach my $pfam_id (@pfamids) {
                $cluster_pfams{ $pfam_id }++;
		if (exists $mypfams{ $pfam_id }) {
		    $gene_oid = "$taxon_oid assembled $gene_oid";
		    push @gene_oids, $gene_oid;
		    next GENE;
		}
            }
        }

    } else {
	my $funcIdsInClause = TaxonDetailUtil::fetchPfamId2NameHash
	    ( $dbh, \@pfam_ids, \%funcId2Name, 1 ); 
 
	my $sql = qq{
            select distinct gpf.gene_oid
            from bio_cluster_features_new bcg,
                 gene_pfam_families gpf
            where bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
            and bcg.gene_oid = gpf.gene_oid
            and gpf.pfam_family in ($funcIdsInClause)
        };
	my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
	my %done; 
	for ( ; ; ) {
	    my ($gene_oid) = $cur->fetchrow();
	    last if !$gene_oid; 
	    next if $done{$gene_oid} ne "";
	    push @gene_oids, $gene_oid; 
	    $done{$gene_oid} = 1; 
	} 
	$cur->finish(); 

	OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
	    if ( $funcIdsInClause =~ /gtt_func_id/i ); 
    }

    return ($taxon_oid, $isTaxonInFile, \@pfam_ids, \%funcId2Name, \@gene_oids);
}

###############################################################################
# addBCPfamGeneListToCart - add genes under one protein family to cart
###############################################################################
sub addBCPfamGeneListToCart {
    my $dbh = dbLogin();
    my ($taxon_oid, $isTaxonInFile, $pfam_ids_ref, $funcId2Name_href, $gene_oids_ref) 
	= getBCPfamGeneList($dbh);
 
    require CartUtil;
    CartUtil::callGeneCartToAdd( $gene_oids_ref );    
}

sub printMainJS {
    print qq {
    <script type="text/javascript">
    function reload(url, div) {
        var callback = {
            success: handleSuccess,
            argument: [div]
        };

        if (url != null && url != "") {
            var request = YAHOO.util.Connect.asyncRequest
                ('GET', url, callback);
        }
    }
    function handleSuccess(req) {
        var bodyText;
        try {
            div = req.argument[0];
            response = req.responseXML.documentElement;
            var maptext = response.getElementsByTagName
              ("maptext")[0].firstChild.data;
            bodyText = maptext;
        } catch(e) {
        }
        var el = document.getElementById(div);
        el.innerHTML = bodyText;
    }
    </script>
   };
}

sub reloadViewer {
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $in_file = param("in_file");
    my $mygene = param("gene_oid");
    my $colorBy = param("color");

    print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    print qq{
        <response>
            <maptext><![CDATA[
    };

    loadNeighborhoods($taxon_oid, $cluster_id, $in_file, $mygene, $colorBy);

    print qq{
            ]]></maptext>
            <imagemap></imagemap>
        </response>
    };
}

###############################################################################
# printNeighborhoods - print the cluster neighborhood and neighborhoods
#                      of similar clusters or those of gene hits
###############################################################################
sub printNeighborhoods {
    my ( $taxon_oid, $cluster_id, $in_file, $mygene, $colorBy ) = @_;
    $colorBy = "cog" if ($colorBy eq "");

    printMainForm();

    my $fnurl = "xml.cgi?section=$section&page=reload_viewer"
	      . "&taxon_oid=$taxon_oid&cluster_id=$cluster_id"
	      . "&in_file=$in_file&gene_oid=$mygene";
    my $funcall1 = "javascript:reload('$fnurl"."&color=bc', 'colordiv')";
    my $funcall2 = "javascript:reload('$fnurl"."&color=cog', 'colordiv')";
    my $funcall3 = "javascript:reload('$fnurl"."&color=kog', 'colordiv')";
    my $funcall4 = "javascript:reload('$fnurl"."&color=pfam', 'colordiv')";

    my $cogchk = "";
    my $kogchk = "";
    my $pfamchk = "";
    my $bcchk = "";
    $cogchk = "checked" if $colorBy eq "cog";
    $kogchk = "checked" if $colorBy eq "kog";
    $pfamchk = "checked" if $colorBy eq "pfam";
    $bcchk = "checked" if $colorBy eq "bc";

    if ($mygene ne "") {
	printMainJS();
	print "<p>";
	print "Color By:&nbsp;&nbsp;";
	print "<input type='radio' onclick=\"$funcall2\" name='colorby' value='cog' $cogchk />";
	print "COG";
	#print "<input type='radio' onclick=\"$funcall3\" name='colorby' value='kog' $kogchk />";
	#print "KOG";
	print "<input type='radio' onclick=\"$funcall4\" name='colorby' value='pfam' $pfamchk />";
	print "Pfam";
	#print "<input type='radio' onchange=\"$funcall1\" name='colorby' value='bc' $bcchk />";
	#print "BC Association";
	print "</p>";
    }

    print "<script src='$base_url/overlib.js'></script>\n";
    loadNeighborhoods($taxon_oid, $cluster_id, $in_file, $mygene, $colorBy);
}

sub loadNeighborhoods {
    my ( $taxon_oid, $cluster_id, $in_file, $mygene, $colorBy ) = @_;
    $colorBy = "cog" if ($colorBy eq "");

    # see: printSimilarBCGF
    my @sim_bcs = param("bc_id");

    my $dbh = dbLogin();

    my $gene_list = param("gene_list");
    my @cgenes = split(",", $gene_list) if $gene_list ne "";

    my ($clustergenes_aref, $cluster_h, $scaffold_info_href) =
	getAllInfoForCluster($dbh, $cluster_id, $taxon_oid, $in_file);
    my %scaffold_info = %$scaffold_info_href;
    my @clustergenes = @$clustergenes_aref;

    my $recs_ref;
    my $g2pfam_ref;
    if ( $in_file eq "Yes" ) {
	if ( @sim_bcs ne "" && scalar(@sim_bcs) > 0 ) {
	    ($recs_ref, $g2pfam_ref) = getBiosyntheticPfamHit
		($dbh, $taxon_oid, $cluster_id, \@sim_bcs, $gene_list);
	} else {
	    $recs_ref = getBiosyntheticBestHitMERFS
		($dbh, $taxon_oid, $cluster_id, $mygene) if $mygene ne "";
	}

    } else {
	if ( @sim_bcs ne "" && scalar(@sim_bcs) > 0 ) {
	    ($recs_ref, $g2pfam_ref) = getBiosyntheticPfamHit
		($dbh, $taxon_oid, $cluster_id, \@sim_bcs, $gene_list);
	} else {
	    $recs_ref = getBiosyntheticBestHit
		($dbh, $taxon_oid, $cluster_id, $mygene, 1) if $mygene ne "";
	}
    }

    my %taxon_in_file_h;
    my %taxon_name_h;
    my %genes_h;
    my %s2q; # map bbh to its cluster gene
    my @sortedScfs; # based on $hitnum -Anna ?
    foreach my $r (@$recs_ref) {
        my ( $tx, $gene_oid, $panelStrand, $q_gene, $hitnum ) 
	    = split( /\t/, $r );
        #TODO - ANNA - order by hitnum ###################################
	# same hit can map to diff cluster gene
	if ($s2q{ $gene_oid }) {
	    $s2q{ $gene_oid } .= "\t".$q_gene;
	} else {
	    $s2q{ $gene_oid } = $q_gene;
	}

	my $s2_in_file;
	my $s2_name;
	if ( $taxon_in_file_h{$tx} ) {
	    $s2_in_file = $taxon_in_file_h{$tx};
	    $s2_name = $taxon_name_h{$tx};
	}
	else {
	    my $sql2 = "select taxon_display_name, in_file " .
		       "from taxon where taxon_oid = ?";
	    my $cur2 = execSql($dbh, $sql2, $verbose, $tx);
	    ($s2_name, $s2_in_file) = $cur2->fetchrow();
	    $cur2->finish();
	    $taxon_in_file_h{$tx} = $s2_in_file;
	    $taxon_name_h{$tx} = $s2_name;
	}

	my ( $scaffold_oid, $scaffold_name, $topology, $scf_length, 
	     $start_coord, $end_coord, $strand );
	if ( $s2_in_file eq 'No' && isInt($gene_oid) ) {
	    ( $scaffold_oid, $scaffold_name, $topology, $scf_length, 
	      $start_coord, $end_coord, $strand )
		= getScaffoldInfo( $dbh, $gene_oid );
	}
	else {
	    $topology = 'linear';
	    my @vals = MetaUtil::getGeneInfo($gene_oid, $tx, 'assembled');
	    my $line = join("\t", @vals); 
	    if ( scalar(@vals) >= 7 ) {
		$start_coord = $vals[-4];
		$end_coord = $vals[-3];
		$strand = $vals[-2];
		$scaffold_oid = $vals[-1];
		$scaffold_name = $s2_name . ": " . $scaffold_oid;
		if ( $scaffold_oid ) {
		    my ($s2, $e2, $r2) = MetaUtil::getScaffoldCoord
			($tx, 'assembled', $scaffold_oid);
		    $scf_length = $e2 - $s2 + 1;
		}
	    }
	}
	next if !$scaffold_oid;

	my $item = "$gene_oid\t$start_coord\t$end_coord\t$panelStrand";
	$scaffold_info{ $scaffold_oid } 
	= $scaffold_name."\t".$tx."\t".$topology."\t".$scf_length;
	push @{$genes_h{ $scaffold_oid }}, $item;
	push @sortedScfs, $scaffold_oid; # to be sorted by hitnum -Anna
    }

    @clustergenes = @cgenes if @cgenes ne "" && (scalar @cgenes > 0);

    print "<div id='colordiv'>";
    my $title = "Biosynthetic Cluster";
    $title = uc($colorBy) if $colorBy ne "bc";
    if ( ! $cluster_id ) {
	$title = "Genome Fragment";
    }

    my $hint = "Mouse over a gene to see details (once page has loaded).<br>";
    if ( $cluster_id ) {
	$hint .= "Click on the red dashed box <font color='red'><b>- - -</b>"
	       . "</font> for functions associated with this cluster.<br>";
	$hint .= "Click on the black dashed box <b>- - -</b> for functions "
	       . "associated with a cluster for a best hit gene.<br>";
    }
    $hint .= "Genes are <font color='darkGreen'>colored</font> "
	   . "by <u>$title</u> association.<br>"
	   . "Light yellow colored genes have <b>no</b> $title association.";
    $hint .= "<br/>Cluster neighborhood is flanked on each side by at least "
	   . "10,000 additional base pairs.<br/>";

    my $curl = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    my $clink = alink($curl, $cluster_id);
    if ( ! $cluster_id ) {
	$clink = "genome fragment";
    }

    if ( @sim_bcs ne "" && scalar(@sim_bcs) > 0 ) {
	print "<p>*Showing neighborhoods of selected similar clusters "
	    . "<u>based on Pfam</u> of selected $clink cluster genes. "
	    . "<br/>Only the genes selected for similarity search are "
	    . "colored on the cluster.</p>\n";
    } elsif ( $mygene ne "" ) {
	my $gurl = "$main_cgi?section=GeneDetail"
	         . "&page=geneDetail&gene_oid=$mygene";
	$gurl = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
	      . "&taxon_oid=$taxon_oid&data_type=assembled&gene_oid=$mygene"
	      if $in_file eq "Yes";
	my $link = alink( $gurl, $mygene );;
	if ( $in_file eq "Yes" ) {
	    print "<p>Looking for best hit for cluster gene $link.<br/>" .
	    "Click on a different gene <u>in the cluster</u> to find " . 
	    "the best hit for that gene.</p>";
	} else {
	    print "<p>Looking for top 5 best hits for cluster gene $link." .
	    "<br/>Click on a different gene <u>in the cluster</u> to find " .
	    "the best hits for that gene. <br/>Best hits are ordered by " .
	    "descending bit score.</p>";
	}
    } else {
	print "<p>Click on a gene <u>in the cluster</u> to get the best " .
	"hits for that gene. <br/>Best hits are ordered by descending " .
	"bit score.</p>";
    }
    printHint($hint);

    printNeighborhoodPanels
        ($dbh, \@clustergenes, \%s2q, $cluster_h, \%scaffold_info,
	 \%genes_h, $cluster_id, $g2pfam_ref, \@sortedScfs, $mygene, $colorBy);
    print "</div>"; # colordiv for reloading

    print end_form();
}

sub getScaffoldInfo {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select scf.scaffold_oid, scf.scaffold_name, scf.mol_topology,
               ss.seq_length, g.start_coord, g.end_coord, g.strand
        from gene g, scaffold scf, scaffold_stats ss
        where g.gene_oid = ?
        and g.obsolete_flag = 'No'
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $scaffold_oid, $scaffold_name, $topology, $scf_length, 
	 $start_coord, $end_coord, $strand ) = $cur->fetchrow();
    $cur->finish();

    return ( $scaffold_oid, $scaffold_name, $topology, $scf_length, 
	     $start_coord, $end_coord, $strand );
}

sub printNeighborhoodPanels {
    my ( $dbh, $all_cluster_genes, $s2q_href, $cluster_href, $scf_info_href,
	 $genes_href, $cluster_id, $g2pfam_ref, $sorted_scf_ref, $mygene,
	 $colorBy ) = @_;

    use GD;
    use RNAStudies;
    my $im = new GD::Image( 10, 10 );
    my $color_array_file = $env->{ large_color_array_file };
    my @color_array = RNAStudies::loadMyColorArray($im, $color_array_file);

    my $idx = 0;
    my %color_hash;

    my $yellow = $im->colorClosest( 255, 250, 205 );
    my $white = $im->colorClosest( 255, 255, 255 );

    # assign diff color to each cluster gene first:
    foreach my $cg (@$all_cluster_genes) {
        if ($idx == 246) { $idx = 0; }

        my $color = $color_array[ $idx ];
        if ($color == $yellow || $color == $white) {
            $color = $color_array[ $idx % 100 + 136 ];
        }
        $color_hash{ $cg } = $color;
        $idx++;
    }

    # assign colors to best hits based on color of cluster gene:
    if ($s2q_href ne "") {
    my @keys = keys %$s2q_href;
    foreach my $key ( @keys ) { # all gene hits
	my @qgenes = split( /\t/, $s2q_href->{$key} );
	foreach my $q (@qgenes) {
	    $color_hash{ $key } = $color_hash{ $q };
	}
    }
    }

    # for mygene:
    my $mystart0 = -1;
    my $myend0   = -1;
    my $mystrand0;
    my $myscf;
    my $myscaffold_name;
    my $mytx;
    my $mytopology;
    my $myscf_length;
    my @myrecs;

    # cluster genes first:
    foreach my $scf (keys %$cluster_href) {
	my ($scaffold_name, $tx, $topology, $scf_length)
	    = split(/\t/, $scf_info_href->{ $scf });
	my @recs = $cluster_href->{ $scf };
	my @cluster_genes;

	foreach my $r (@recs) {
	    foreach my $i (@$r) {
		my ($gene_oid, $start, $end, $strand) = split( /\t/, $i );
		push (@cluster_genes, $gene_oid);
	    }
	}
	# find center gene:
	my $size = $#cluster_genes;
	my $middle = $size / 2;
	my $g = $cluster_genes[$middle];
	
	my $minstart = $scf_length;
	my $maxend = -1;
	my $start0 = -1;
	my $end0   = -1;
	my $strand0;
	foreach my $r (@recs) {
	    foreach my $i (@$r) {
		my ($gene_oid, $start, $end, $strand) = split( /\t/, $i );
		$minstart = $start if ($start < $minstart);
		$maxend = $end if ($end > $maxend);

		if ($gene_oid eq $g) {
		    $start0 = $start;
		    $end0 = $end;
		    $strand0 = $strand;
		}
		if ($gene_oid eq $mygene) {
		    $mystart0 = $start;
		    $myend0 = $end;
		    $mystrand0 = $strand;
		    $myscf = $scf;
		    $myscaffold_name = $scaffold_name;
		    $mytx = $tx;
		    $mytopology = $topology;
		    $myscf_length = $scf_length;
		    @myrecs = @recs;
		}
	    }
	}
	
	# add extra 10000 bps on each side of cluster:
	$maxend = $maxend + 10000;
	$maxend = $scf_length if $maxend > $scf_length;
	$minstart = $minstart - 10000;
	$minstart = 0 if $minstart < 0;

	print "<table>";

        my $clurl = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
        my $cluster_link = alink($clurl, $cluster_id);

	print "<p>Neighborhood for Cluster ID $cluster_link:</p>";
	if (($maxend - $minstart) > 2 * $flank_length) {
	    my $n = ceil(($maxend - $minstart)/(2 * $flank_length));
	    my $tmp_start = $minstart;
	    my $tmp_end = $tmp_start + 2 * $flank_length + 1;
	    for (my $i=0; $i<$n; $i++) {
		$tmp_end = $tmp_start + 2 * $flank_length + 1;
		printOneNeighborhood( $dbh, $g, \%color_hash,
				      $tmp_start, $tmp_end, $strand0,
				      $scf, $scaffold_name, $topology,
				      $scf_length, \@recs, $cluster_id, 
				      $tx, $g2pfam_ref, "", $colorBy );
		$tmp_start = $tmp_end;
	    }

	} else {
	    printOneNeighborhood( $dbh, $g, \%color_hash,
				  $minstart, $maxend, $strand0,
				  $scf, $scaffold_name, $topology,
				  $scf_length, \@recs, $cluster_id, 
				  $tx, $g2pfam_ref, "", $colorBy );
	}
	print "</table>";

	print "<hr size='3' color='#99CCFF' />";
        #print "<br/>\n";
    }

    return if $mygene eq "";

    # best hits: sorted by scaffold_name, case-insensitive
    # should be sorted by bit score i.e. hitnum -Anna
    #my @sortedScfs = sort{ "\L$scf_info_href->{$a}" cmp 
    #			   "\L$scf_info_href->{$b}" } keys (%$scf_info_href);
    my @sortedScfs = @$sorted_scf_ref; # sorted by bit score
    if ($mygene ne "" && scalar @sortedScfs < 1) {
	my $infile = MerFsUtil::isTaxonInFile($dbh, $mytx);
        my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail"
                 . "&gene_oid=$mygene";
        $gurl = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
              . "&taxon_oid=$mytx&data_type=assembled&gene_oid=$mygene"
              if $infile eq "Yes";
        my $link = alink( $gurl, $mygene );;

	print "<p>No hits found for cluster gene $link.</p>";
	return;
    }

    print "<table>";

    # print neighborhood for $mygene again if one is selected
    if ($mygene ne "") {
	printOneNeighborhood( $dbh, $mygene, \%color_hash,
			      $mystart0, $myend0, $mystrand0,
			      $myscf, $myscaffold_name, $mytopology,
			      $myscf_length, \@myrecs, "",
			      $mytx, $g2pfam_ref, $mygene, $colorBy );
    }

    foreach my $scf (@sortedScfs) {
        my ($scaffold_name, $tx, $topology, $scf_length)
            = split(/\t/, $scf_info_href->{ $scf });
	my @recs = $genes_href->{ $scf };

	next if !exists $genes_href->{$scf};
	my @scf_genes;

        foreach my $r (@recs) {
            foreach my $i (@$r) {
                my ($gene_oid, $start, $end, $strand) = split( /\t/, $i );
		push (@scf_genes, $gene_oid);
	    }
	}

        # find center gene:
        my $size = $#scf_genes;
        my $middle = $size / 2;
        my $g = $scf_genes[$middle];

	my $start0 = -1;
	my $end0   = -1;
	my $strand0;
	foreach my $r (@recs) {
            foreach my $i (@$r) {
		my ($gene_oid, $start, $end, $strand) = split( /\t/, $i );
                if ($gene_oid eq $g) {
                    $start0 = $start;
                    $end0 = $end;
		    $strand0 = $strand;
                    last;
                }
	    }
	}
        printOneNeighborhood( $dbh, $g, \%color_hash, 
			      $start0, $end0, $strand0, 
			      $scf, $scaffold_name, $topology,
                              $scf_length, \@recs, "", $tx, "", "", $colorBy );
        #print "<br/>\n";
    }
    print "</table>";
    print "</br>";

    if ($mygene ne "") {
	my $name = "_section_ScaffoldCart_addGeneScaffold";
	print submit(
	    -name  => $name,
	    -value => "Add Scaffolds of Selected Genes to Cart",
	    -class => 'lgbutton'
        );
	print nbsp(1);
	WebUtil::printGeneCartFooter() 
    }
}

sub printOneNeighborhood {
    my ( $dbh, $gene_oid0, $color_href, $start_coord0, $end_coord0, $strand0,
	 $scaffold_oid, $scaffold_name, $topology, $scf_seq_length, 
	 $genes_aref, $cluster_id0, $taxon_oid, $g2pfam_href, $mygene,
	 $colorBy ) = @_;

    my $mid_coord = int(($end_coord0 - $start_coord0) / 2) + $start_coord0 + 1;
    my $left_flank = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    my $min = 0; my $max = 0;
    if ($cluster_id0 ne "") {
	($min, $max) = getBioClusterMinMax($dbh, $cluster_id0);
    }

    my $clusterid;
    my %cluster_genes;
    my %drawn_genes;
    my @all_genes;
    my $infile = MerFsUtil::isTaxonInFile($dbh, $taxon_oid);

    if ($gene_oid0 eq $mygene) {
        my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail"
	         . "&gene_oid=$mygene";
        $gurl = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
              . "&taxon_oid=$taxon_oid&data_type=assembled&gene_oid=$mygene"
              if $infile eq "Yes";
        my $link = alink( $gurl, $mygene );;
	print "<p>You may select cluster gene $link and its best hit(s) into cart:";
	print "<br/>(Genes are colored by <b>".uc($colorBy)."</b>)</p>";
    }

    if (!$infile) {
	my $myOrder = "";
	if ( $strand0 eq "-" ) {
	    $myOrder = "desc";
	}

	my $sql = qq{
        select distinct g.gene_oid, g.gene_symbol, g.gene_display_name,
        g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
        g.aa_seq_length, bcf.cluster_id, g.scaffold, g.is_pseudogene,
        g.cds_frag_coord, dt.cog
        from gene g
        left join bio_cluster_features_new bcf
        on g.gene_oid = bcf.gene_oid and bcf.feature_type = 'gene'
        left join gene_cog_groups dt
        on g.gene_oid = dt.gene_oid
        where g.scaffold = ?
        and (( g.start_coord >= ? and g.end_coord <= ? )
           or (( g.end_coord + g.start_coord ) / 2 >= ?
           and ( g.end_coord + g.start_coord ) / 2 <= ? ))
        order by g.start_coord, g.end_coord, bcf.cluster_id $myOrder
        };

	if ($colorBy eq "pfam") {
	    $sql = qq{
            select distinct g.gene_oid, g.gene_symbol, g.gene_display_name,
            g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
            g.aa_seq_length, bcf.cluster_id, g.scaffold, g.is_pseudogene,
            g.cds_frag_coord, gp.pfam_family
            from gene g 
            left join bio_cluster_features_new bcf
            on g.gene_oid = bcf.gene_oid and bcf.feature_type = 'gene'
            left join gene_pfam_families gp on g.gene_oid = gp.gene_oid
            where g.scaffold = ?
            and (( g.start_coord >= ? and g.end_coord <= ? )
               or (( g.end_coord + g.start_coord ) / 2 >= ?
               and ( g.end_coord + g.start_coord ) / 2 <= ? ))
            order by g.start_coord, g.end_coord, bcf.cluster_id $myOrder
            };
	}
	my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid,
			   $left_flank, $right_flank,
			   $left_flank, $right_flank );

	my %gene2fn;
	my %gene2info;
	my @genes;
	for ( ;; ) {
	    my ($gene_oid, $gene_symbol, $gene_display_name, 
		$locus_type, $locus_tag, $start_coord, $end_coord, $strand,
		$aa_seq_length, $cluster_id, $scaffold,
		$is_pseudogene, $cds_frag_coord, $func_id) = $cur->fetchrow();
	    last if !$gene_oid;

	    if (!exists $gene2info{ $gene_oid }) {
		push @genes, $gene_oid;
	    }
	    push @{$gene2fn{ $gene_oid }}, $func_id;
	    $gene2info{ $gene_oid } = 
		     "$gene_oid\t$gene_symbol\t$gene_display_name\t"
		   . "$locus_type\t$locus_tag\t$start_coord\t"
		   . "$end_coord\t$strand\t$aa_seq_length\t$cluster_id\t"
		   . "$scaffold\t$is_pseudogene\t$cds_frag_coord";

	    if ($cluster_id eq $cluster_id0) {
		$cluster_genes{$gene_oid} = 1;
	    } else {
		$clusterid = $cluster_id;
	    }

	    $drawn_genes{"$start_coord-$end_coord"} = 0;
	}
	$cur->finish();

	foreach my $g1 (@genes) {
	    my $fnstr = join(", ", sort @{$gene2fn{ $g1 }});
	    my $item = $gene2info{ $g1 } . "\t" . $fnstr;
	    push @all_genes, $item;
	}

    } else {
	my @genes_on_s = MetaUtil::getScaffoldGenes
	    ($taxon_oid, "assembled", $scaffold_oid);

	if ($mygene ne "") {
	    my $sql = qq{
                select distinct bcg.cluster_id
                from bio_cluster_features_new bcg
                where bcg.feature_type = 'gene'
                and bcg.feature_id = ?
            };
	    my $cur = execSql( $dbh, $sql, $verbose, $mygene );
	    ( $clusterid ) = $cur->fetchrow();
	    # may actually be more than one cluster
	    $cur->finish();
	}
	
	foreach my $line (@genes_on_s) {
	    my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name,
		 $start_coord, $end_coord, $strand, $seq_id, $source ) =
		     split( /\t/, $line );
	    
	    my $fn_str;
	    if ($colorBy eq "pfam") {
		my @pfams = MetaUtil::getGenePfamId
		    ($gene_oid, $taxon_oid, "assembled");
		$fn_str = join( ", ", sort @pfams );
	    } else { # default to cog:
		my @cogs = MetaUtil::getGeneCogId
		    ($gene_oid, $taxon_oid, "assembled");
		$fn_str = join( ", ", sort @cogs );
	    }

	    my $aa_seq_length = int(($end_coord - $start_coord + 1) / 3);
	    push( @all_genes,
		  "$gene_oid\t\t$gene_display_name\t"
		. "$locus_type\t$locus_tag\t$start_coord\t"
		. "$end_coord\t$strand\t$aa_seq_length\t"
		. "\t$scaffold_oid\t\t\t$fn_str" );

	    $drawn_genes{"$start_coord-$end_coord"} = 0;
	}
    }

    # 25000 bp (flank_length) on each side of midline
    my ( $rf1, $rf2, $lf1, $lf2 );    # when circular and in boundry line
    my $in_boundry = 0;
    if ( $topology eq "circular" && $scf_seq_length/2 > $flank_length ) {
        if ( $left_flank <= 1 ) {
            my $left_flank2 = $scf_seq_length + $left_flank;
            $lf1        = $left_flank2;
            $rf1        = $scf_seq_length;
            $lf2        = 1;
            $rf2        = $right_flank;
            $in_boundry = 1;

        } elsif (    $left_flank <= $scf_seq_length
                  && $right_flank >= $scf_seq_length ) {

            my $right_flank2 = $right_flank - $scf_seq_length;
            $lf1        = $left_flank;
            $rf1        = $scf_seq_length;
            $lf2        = 1;
            $rf2        = $right_flank2;
            $in_boundry = 1;
        }
    }

    # create a plot - one scaffold / taxon per plot
    my $tag = "biosynthetic";
    my $panelStrand = $strand0;

    my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail";
    $gurl = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
	  . "&taxon_oid=$taxon_oid&data_type=assembled" if $infile;
    # click on gene in cluster to get hits for that gene only:
    $gurl = "$section_cgi&page=cluster_viewer&taxon_oid=$taxon_oid"
	  . "&cluster_id=$cluster_id0" if $cluster_id0 ne "";

    my $tx_url = "$main_cgi?section=TaxonDetail&page=taxonDetail"
	       . "&taxon_oid=$taxon_oid";
    my $scf_url = "$main_cgi?section=ScaffoldCart&page=scaffoldDetail"
	        . "&scaffold_oid=$scaffold_oid&taxon_oid=$taxon_oid";
    $scf_url = "$main_cgi?section=MetaDetail"
	     . "&page=metaScaffoldDetail&taxon_oid=$taxon_oid"
	     . "&scaffold_oid=$scaffold_oid" if $infile;

    my $args = {
        id => "gn.$tag.$scaffold_oid.$start_coord0.x.$end_coord0.$$",
        x_width                 => 850,
        start_coord             => $left_flank,
        end_coord               => $right_flank,
        coord_incr              => 5000,
        strand                  => $panelStrand,
        title                   => $scaffold_name,
        has_frame               => 1,
        gene_page_base_url      => $gurl,
        in_file                 => $infile,
        color_array_file        => $env->{large_color_array_file},
        tmp_dir                 => $tmp_dir,
        tmp_url                 => $tmp_url,
	scf_seq_length          => $scf_seq_length,
	topology                => $topology,
	in_boundry              => $in_boundry,
        tx_url                  => $scf_url
    };

    my $cassette_url = "$section_cgi&page=cassette_box&taxon_oid=$taxon_oid"
	             . "&infile=$infile&scaffold_oid=$scaffold_oid"
		     . "&cluster_id=$cluster_id0";
    my $clusturl = "$section_cgi&page=cluster_detail&cluster_id=$clusterid";
    $args->{cassette_base_url} = $cassette_url if $cluster_id0 ne "";
    $args->{cassette_base_url} = $clusturl if $clusterid ne "";

    my $sp = new GeneCassettePanel($args);
    #$sp->highlightGene($start_coord0, $end_coord0) if $gene_oid0 eq $mygene;
    
    my $color_array = $sp->{color_array};

    my $parts = 1;
    my ( @binds1, @binds2 );
    if ($in_boundry) {
        @binds1 = ( $scaffold_oid, $lf1, $rf1, $lf1, $rf1 );
        @binds2 = ( $scaffold_oid, $lf2, $rf2, $lf2, $rf2 );
        $parts  = 2;
    }

    foreach my $r (@all_genes) {
        my ( $gene_oid, $gene_symbol, $gene_display_name, 
	     $locus_type, $locus_tag, $start_coord, $end_coord, $strand,
	     $aa_seq_length, $cluster_id, $scaffold, $is_pseudogene, 
	     $cds_frag_coord, $func_id ) = split( /\t/, $r );
        if ( $drawn_genes{"$start_coord-$end_coord"} > 0
            && !( $start_coord >= $min
                  && $end_coord <= $max ) ) {
            next;
        }

	my $pfamLbl;
	my $pfams = $g2pfam_href->{ $gene_oid } if $g2pfam_href ne "";
	$pfamLbl = " PFAM: ".$pfams if $pfams && $pfams ne "";

        my $label = $gene_symbol;
        $label = $locus_tag         if $label eq "null" || $label eq "";
        $label = " gene $gene_oid " if $label eq "";
        $label .= " : $gene_display_name ";
        $label .= " $start_coord..$end_coord ";
	# ANNA: add hitnum and to which cluster gene ?

        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length} aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len} bp)";
        }
        $label .= " ${func_id} " if $func_id ne "";
	$label .= $pfamLbl;

        my $color = $sp->{color_yellow};
	if ($colorBy eq "bc" && exists $color_href->{$gene_oid}) {
	    $color = $color_href->{$gene_oid};
	}
        # All pseudo gene should be white - 2008-04-10 ken
        if ( uc($is_pseudogene) eq "YES" ) {
            $color = $sp->{color_white};
        }
	if ($colorBy eq "cog") {
	    $color = GeneCassette::getCogColor( $sp, $func_id );
	    if ($gene_oid eq $gene_oid0 && $cluster_id0 eq "") {
		$color = $sp->{color_red};
	    }
	}
	elsif ($colorBy eq "kog") {
	}
	elsif ($colorBy eq "pfam") {
            $color = GeneCassette::getPfamColor( $sp, $func_id );
            if ($gene_oid eq $gene_oid0 && $cluster_id0 eq "") {
                $color = $sp->{color_red};
            }
	}
        $color = $sp->{color_yellow} if $color eq "";

	use GeneUtil;
	my @coordLines = GeneUtil::getMultFragCoords
	    ( $dbh, $gene_oid, $cds_frag_coord );
	if ( scalar(@coordLines) > 1 ) {
	    foreach my $line (@coordLines) {
		my ( $frag_start, $frag_end ) = split( /\.\./, $line );
		my $tmp_label = $label . " $frag_start..$frag_end ";
		$sp->addGene( $gene_oid, $frag_start, $frag_end,
			      $strand, $color, $tmp_label );
	    }
	} else {
	    $sp->addGene( $gene_oid, $start_coord, $end_coord,
			  $strand, $color, $label );
	}
    }

    my $bracketType1 = "left";
    my $bracketType2 = "right";
    if ( $panelStrand eq "-" ) {
        $bracketType1 = "right";
        $bracketType2 = "left";
    }
    if ( $left_flank <= 1 ) {
#        if ( $topology eq "circular" ) {
#            $sp->addBracket( 1, "boundry" );
#        } else {
            $sp->addBracket( 1, $bracketType1 );
#        }
    }
    if ( $left_flank <= $scf_seq_length && $scf_seq_length <= $right_flank ) {
#        if ( $topology eq "circular" ) {
#            $sp->addBracket( $scf_seq_length, "boundry" );
#        } else {
            $sp->addBracket( $scf_seq_length, $bracketType2 );
#        }
    }

    # draw the dashed red box around the cluster only
    my $box_done = 0;
    if ( $cluster_id0 ne "" && $max > $start_coord0) {
	my $min_cassette_start = $start_coord0;
	$min_cassette_start = $min if $start_coord0 < $min;
	my $max_cassette_end = $end_coord0;
	$max_cassette_end = $max if $end_coord0 > $max;

	$sp->addCassetteBox
	    ($min_cassette_start, $max_cassette_end, $gene_oid0,
	     "cluster: $cluster_id0 ($min..$max)", 'bio');
	$box_done = 1;
    }

    if ($clusterid ne "" && !$box_done) { # find other clusters
	my $min2 = 0; my $max2 = 0;
	($min2, $max2) = getBioClusterMinMax($dbh, $clusterid);
	my $min_cassette_start = $start_coord0;
        $min_cassette_start = $min2;
        my $max_cassette_end = $end_coord0;
        $max_cassette_end = $max2;

	my $cbox_color = $sp->{color_black};
	$cbox_color = $sp->{color_red} if $mygene ne "";
        $sp->addCassetteBox
            ($min_cassette_start, $max_cassette_end, $gene_oid0,
	     "cluster: $clusterid ($min2..$max2)", 'bio', $cbox_color);
    }

    my $s = $sp->getMapHtml("overlib");
    if ($cluster_id0 eq "") { # for bbh neighborhoods
	print "<tr>";
	print "<td>";
	print "<input type='checkbox' name='gene_oid' value='$gene_oid0' />";
	print "</td><td>";
	print "$s\n";
	print "</td>";
	print "</tr>";
    } elsif ($mygene ne "") {
	print "<tr>";
	print "<td>";
	print "<input type='checkbox' name='gene_oid' value='$mygene' />";
	print "</td><td>";
	print "$s\n";
	print "</td>";
	print "</tr>";
    } else {
	print "$s\n"; # when no cluster gene is selected
    }
}

sub getBioClusterMinMax {
    my ($dbh, $cluster_id) = @_;
    my $sql = qq{
        select bc.start_coord, bc.end_coord
        from bio_cluster_new bc
        where bc.cluster_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    my ( $min, $max ) = $cur->fetchrow();
    $cur->finish();

    return ($min, $max);
}

# for neighborhoods:
sub getBiosyntheticBestHit {
    my ( $dbh, $taxon_oid, $cluster_id, $mygene, $bbhlite ) = @_;
    $bbhlite = 0 if $bbhlite eq "";

    my $bbh_dir = $env->{bbh_zfiles_dir};
    $taxon_oid = sanitizeInt($taxon_oid);
    my $bbh_file_name = $bbh_dir . "/" . $taxon_oid . ".zip";

    if ( ! blankStr($bbh_file_name) && (-e $bbh_file_name) ) {
        # yes, we have file
    } else {
        return;
    }

    my $tclause   = txsClause( "tx", $dbh );
    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select tx.taxon_oid, tx.taxon_display_name
        from taxon tx
        where 1 = 1
        $rclause
        $imgClause
        $tclause
    };
    my %validTaxons;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid, $taxon_name) = $cur->fetchrow();
        last if !$taxon_oid;
        $validTaxons{$taxon_oid} = $taxon_name;
    }
    $cur->finish();

    my $sql = qq{
        select g.gene_oid, g.locus_tag, g.gene_display_name
        from gene g
        where g.taxon = ?
        and g.gene_oid = ?
    };
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $mygene);
    my ($gene_oid, $locus_tag, $gene_name) = $cur->fetchrow();
    $cur->finish();

    my @recs;
    my $numhits = 0;

    if ($bbhlite) {
	my @bbhRows = WebUtil::getBBHLiteRows( $gene_oid, \%validTaxons );
	foreach my $r (@bbhRows) {
	    my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
		 $qstart, $qend, $sstart, $send, $evalue, $bitScore )
		= split( /\t/, $r );
	    my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
	    my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
	    next if $slen > 1.3 * $qlen;
	    next if $slen < 0.7 * $qlen;

	    #print "<br/>ANNA: $qgene_oid,$sgene_oid bit score: $bitScore";
	    if ( $staxon && $validTaxons{$staxon} ) {
		$numhits++;
		last if $numhits > 5;

		use GeneCassette;
		my $strand1 = GeneCassette::getStrand( $dbh, $qgene_oid );
		my $strand2 = GeneCassette::getStrand( $dbh, $sgene_oid );
		my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
		my $rec =
		    "$staxon\t$sgene_oid\t$panelStrand\t$qgene_oid\t$numhits";
		push( @recs, $rec );
	    }
	}

    } else {
	unsetEnvPath();
	# open file
	my $rfh = newUnzipFileHandle
	    ( $bbh_file_name, $gene_oid, "getBBHZipFiles" );

	while ( my $s = $rfh->getline() ) {
	    chomp $s;
	    # file should be ordered by desc bit score already
	    my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
		 $qstart, $qend, $sstart, $send, $evalue, $bitScore )
		= split( /\t/, $s );
	    my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
	    my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
	    #print "<br/>ANNA: $qgene_oid,$sgene_oid bit score: $bitScore";
	    if ( $staxon && $validTaxons{$staxon} ) {
		$numhits++;
		last if $numhits > 5;

		use GeneCassette;
		my $strand1 = GeneCassette::getStrand( $dbh, $qgene_oid );
		my $strand2 = GeneCassette::getStrand( $dbh, $sgene_oid );
		my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
		my $rec = 
		    "$staxon\t$sgene_oid\t$panelStrand\t$qgene_oid\t$numhits";
		push( @recs, $rec );
	    }
	} # end while

	close $rfh;
	WebUtil::resetEnvPath();
    }

    return ( \@recs );
}

# for neighborhoods:
sub getBiosyntheticBestHitMERFS {
    my ( $dbh, $taxon_oid, $cluster_id, $mygene ) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);
    $mygene = MetaUtil::sanitizeGeneId3($mygene);

    my %public_taxons;
    my $sql = qq{
        select taxon_oid, taxon_display_name
        from taxon
        where is_public = 'Yes'
        and obsolete_flag = 'No'
        and genome_type = 'isolate'
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($taxon_oid, $taxon_name) = $cur->fetchrow();
        last if(!$taxon_oid);
        $public_taxons{$taxon_oid} = $taxon_name;
    }
    $cur->finish();

    my @recs;
    my $numhits = 0;
    my $bbh = MetaUtil::getGeneBBH($taxon_oid, 'assembled', $mygene);
    if ( $bbh ) {
	my ($id2, $perc, $homolog, $homo_taxon, @rest) = split(/\t/, $bbh);
	if ( $homo_taxon && $public_taxons{$homo_taxon} ) {
	    $numhits++;
	    last if $numhits > 5;
	    my $rec = "$homo_taxon\t$homolog\t+\t$mygene\t$numhits";
	    push( @recs, $rec );
	}
    }

    return ( \@recs );
}

# shows the pfams, but may change to something else
sub printBiosyntheticCassette {
    my $cluster_id = param("cluster_id");
    my $scaffold_oid = param("scaffold_oid");
    my $taxon_oid = param("taxon_oid");
    my $infile = param("infile");

    printBioClusterPfamList($taxon_oid, $cluster_id);
}

sub printBioClusterViewer {
    my ($taxon_oid, $cluster_id, $mygene, $colorBy) = @_;
    if ($taxon_oid eq "") {
	$taxon_oid  = param("taxon_oid");
	$cluster_id = param("cluster_id");
	$mygene = param("gene_oid");
	$colorBy = param("color");
    }

    my $dbh = dbLogin();

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select $nvl(t.taxon_name, t.taxon_display_name),
               t.genome_type, t.in_file
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name, $genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    # check if the gene is in the cluster -anna
    if ($mygene ne "") {
	my $sql = qq{
            select bcg.feature_id
            from bio_cluster_features_new bcg, bio_cluster_new bc
            where bcg.cluster_id = ?
            and bc.taxon = ?
            and bc.cluster_id = bcg.cluster_id
            and bcg.feature_type = 'gene'
            and bcg.feature_id = ?
        };
	$cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid, $mygene);
	my ($gid) = $cur->fetchrow();
	if (!$gid || $gid ne $mygene) {
	    # gene not in cluster, redirect to gene page:
	    if ($in_file eq "Yes") {
		use MetaGeneDetail;
		MetaGeneDetail::printGeneDetail
		    ("$taxon_oid assembled $mygene");
	    } else {
		use GeneDetail;
		GeneDetail::printGeneDetail($mygene);
	    }
	}
    }

    print "<h1>Biosynthetic Cluster (BC) Neighborhood</h1>";
    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";

    if ( $cluster_id ) {
	my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
	print "<br/>Cluster ID: " . alink($url2, $cluster_id);
	print "</p>";
    }
    else {
	print "</p>";
	printNeighborhoods($taxon_oid, $cluster_id, $in_file);
	print end_form();
	return;
    }

    use TabHTML;
    TabHTML::printTabAPILinks("bioCassetteTab");
    my @tabIndex = ( "#biocassettetab1", "#biocassettetab2" );
    my @tabNames = ( "Cluster Neighborhood", "Genes in Cluster" );
    TabHTML::printTabDiv("bioCassetteTab", \@tabIndex, \@tabNames);

    print "<div id='biocassettetab1'>";
    ### FIXME: use bbh instead of orthologs
    printNeighborhoods($taxon_oid, $cluster_id, $in_file, $mygene, $colorBy);
    print "</div>"; # end biocassettetab1

    print "<div id='biocassettetab2'>";
    print "<h2>Genes in Cluster</h2>";
    printBioClusterGeneList($taxon_oid, $cluster_id);
    print "</div>"; # end biocassettetab2

    TabHTML::printTabDivEnd();
}

# for similar neighborhoods based on pfam
sub getBiosyntheticPfamHit {
    my ( $dbh, $taxon_oid, $cluster_id, $sim_aref, $gene_list ) = @_;

    # get all taxons user can access
    my %public_taxons;
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name
        from taxon t
        where 1 = 1
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($taxon_oid, $taxon_name) = $cur->fetchrow();
        last if(!$taxon_oid);
        $public_taxons{$taxon_oid} = $taxon_name;
    }
    $cur->finish();

    # get all genes in this cluster
    my @genes = split(/\,/, $gene_list);
    my $gene_cond;
    foreach my $g2 ( @genes ) {
	if ( $g2 =~ /^\'/ ) {
	    # already quoted
	}
	else {
	    $g2 = "'" . $g2 . "'";
	}
	if ( $gene_cond ) {
	    $gene_cond .= ", " . $g2;
	}
	else {
	    $gene_cond = $g2;
	}
    }

    my $sql2 = "select in_file from taxon where taxon_oid = ?";
    my $cur2 = execSql($dbh, $sql2, $verbose, $taxon_oid);
    my ($in_file) = $cur2->fetchrow();
    $cur2->finish();

    my $sql;
    my $cur;
    if ( $cluster_id ) {
	$sql = qq{
            select distinct g.gene_oid, g.locus_tag, g.gene_display_name
            from bio_cluster_features_new bcg, gene g
            where bcg.cluster_id = ?
            and g.taxon = ?
            and bcg.feature_id = g.gene_oid
            --and bcg.gene_oid = g.gene_oid
            and bcg.feature_type = 'gene'
            and bcg.feature_id in ($gene_cond)
        };
	if ( $in_file eq 'Yes' ) {
	    $sql = qq{
                select bcg.feature_id
                from bio_cluster_features_new bcg, bio_cluster_new bc
                where bcg.cluster_id = ?
                and bc.taxon = ?
                and bc.cluster_id = bcg.cluster_id
                and bcg.feature_type = 'gene'
                and bcg.feature_id in ($gene_cond)
            };
	}
 
	$cur = execSql($dbh, $sql, $verbose, $cluster_id, $taxon_oid);
    }
    else {
	$sql = qq{
            select g.gene_oid, g.locus_tag, g.gene_display_name
            from gene g
            where g.taxon = ?
            and g.gene_oid in ($gene_list)
        };
	$cur = execSql($dbh, $sql, $verbose, $taxon_oid);
    }

    my $pfam_sql = qq{
        select distinct gpf.pfam_family
        from gene_pfam_families gpf
        where gpf.gene_oid = ? 
    };

    my @recs;
    my %g2pfam; # map genes to pfams
    for ( ;; ) {
        my ($gene_oid, $locus_tag, $gene_name) = $cur->fetchrow();
        last if !$gene_oid;

	if ($in_file eq 'Yes') {
	    $locus_tag = $gene_oid;
	    $gene_name = $gene_oid;
	}

	# get BC pfam for this gene
	my @pfams;
	if ($in_file eq "Yes") {
            my @pfamids = MetaUtil::getGenePfamId
                ($gene_oid, $taxon_oid, 'assembled');
            foreach my $pfam_id (@pfamids) {
		push @pfams, $pfam_id;
            }
	} else {
	    my $pfamcur = execSql($dbh, $pfam_sql, $verbose, $gene_oid);
	    for ( ;; ) {
		my ($pfam2) = $pfamcur->fetchrow();
		last if ! $pfam2;
		push @pfams, $pfam2;
	    }
	    $pfamcur->finish();
	}

	next if scalar @pfams == 0;

	my $pfam_list = WebUtil::joinSqlQuoted(",", @pfams);
	$g2pfam{ $gene_oid } = join(", ", @pfams);

	foreach my $sim_bc ( @$sim_aref ) {
	    # get taxon of this cluster
            my $sql2 = "select taxon from bio_cluster_new where cluster_id = ?";
	    my $cur2 = execSql($dbh, $sql2, $verbose, $sim_bc);
	    my ($staxon) = $cur2->fetchrow();
	    $cur2->finish();

	    # get similar genes
	    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $staxon );
	    if ($isTaxonInFile) {
		next; #TODO -Anna
	    } 

	    my $sql = qq{
                select gpf.gene_oid, count(distinct gpf.pfam_family)
                from bio_cluster_features_new bcg,
                     gene_pfam_families gpf
                where bcg.cluster_id = ?
                and bcg.feature_type = 'gene'
                and bcg.gene_oid = gpf.gene_oid
                and gpf.pfam_family in ( $pfam_list )
                group by bcf.gene_oid
            };
	    $cur2 = execSql($dbh, $sql2, $verbose, $sim_bc);
	    my $numhits = 0;
	    for ( ;; ) {
		my ($sgene_oid, $cnt2) = $cur2->fetchrow();
		last if ! $sgene_oid;
		
		next if $cnt2 < scalar @pfams;
		
		if ( $staxon && $public_taxons{$staxon} ) {
		    $numhits++;

		    use GeneCassette;
		    my $strand1 = "+";
		    if ( isInt($gene_oid) ) {
			$strand1 = GeneCassette::getStrand($dbh, $gene_oid);
		    }
		    my $strand2 = "+";
		    if ( isInt($sgene_oid) ) {
			$strand2 = GeneCassette::getStrand($dbh, $sgene_oid);
		    }
		    my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
		    my $rec = 
		    "$staxon\t$sgene_oid\t$panelStrand\t$gene_oid\t$numhits";
		    push( @recs, $rec );
		}
	    }
	    $cur2->finish();

	}  # end for sim_bc
    }   # end for

    $cur->finish();

    return ( \@recs, \%g2pfam );
}


###########################################################################
# printBioClusterPathwayList: list all IMG pathways associated with
#                          genes in this cluster
###########################################################################
sub printBioClusterPathwayList {
    my ($taxon_oid, $cluster_id) = @_;
    if ( ! $taxon_oid || ! $cluster_id ) {
        return;
    }
    printStatusLine( "Loading ...", 1 );

    print "<h1>Biosynthetic Cluster IMG Pathway List</h1>\n";
    my $dbh = dbLogin();
    my $sql = MerFsUtil::getSingleTaxonOidAndNameFileSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($tid2, $taxon_name, $in_file) = $cur->fetchrow();
    $cur->finish();
    if ( ! $tid2 ) {
        webError("You have no permission on taxon $taxon_oid.");
    }

    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>";
    
    my $count = printClusterPathwayList( $dbh, $taxon_oid, $cluster_id, 1 );
    printStatusLine( "$count IMG Pathway retrieved.", 2 ); 
}

###########################################################################
# printClusterPathwayList: list all IMG pathways associated with
#                          genes in this cluster
###########################################################################
sub printClusterPathwayList {
    my ( $dbh, $taxon_oid, $cluster_id, $hideTitle, $keyword ) = @_;

    if ( ! $taxon_oid && ! $cluster_id ) {
        return;
    }

    if ( ! $hideTitle ) {
        print "<h2>IMG Pathways</h2>\n";         
    }

    my $rclause = WebUtil::urClause('gif.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('gif.taxon'); 

    my $db_id = $cluster_id;
    if ( ! $db_id ) {
	$db_id = $taxon_oid;
    }
    my %gene_term_h;
    my $sql = qq{
        select distinct bcf.gene_oid, gif.function
        from bio_cluster_features_new bcf, gene_img_functions gif
        where bcf.feature_type = 'gene'
        and bcf.cluster_id = ?
        and bcf.gene_oid = gif.gene_oid
        $rclause
        $imgClause
    };
    if ( ! $cluster_id ) {
	$sql = qq{
            select distinct gif.gene_oid, gif.function
            from gene_img_functions gif
            where gif.taxon = ?
            $rclause
            $imgClause
        };
    }
    my $cur = execSql( $dbh, $sql, $verbose, $db_id );
    for ( ;; ) {
        my ($gene_oid, $term_oid) = $cur->fetchrow();
        last if ! $gene_oid;

        my @all_terms = ImgPwayBrowser::findAllParentTerms($dbh, $term_oid, 1);
        foreach my $t2 ( @all_terms ) {
            if ( $gene_term_h{$gene_oid} ) {
                my $term_href = $gene_term_h{$gene_oid};
                $term_href->{$t2} = $t2;
            }
            else {
                my %h2;
                $h2{$t2} = $t2;
                $gene_term_h{$gene_oid} = \%h2;
            }
        }
    }
    $cur->finish();

    my %pway_name_h;
    my %pway_cnt_h;
    foreach my $gene_oid (keys %gene_term_h) {
        my $href = $gene_term_h{$gene_oid};
        if ( ! $href ) {
            next;
        }
        my @all_terms = (keys %$href);
        if ( scalar(@all_terms) == 0 ) {
            next;
        }
        my $term_list = join(", ", @all_terms );
        my $sql = qq{
            select ipw.pathway_oid, ipw.pathway_name
            from img_reaction_catalysts irc,
                 img_pathway_reactions ipr, img_pathway ipw
            where irc.catalysts in ( $term_list )
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            union
            select ipw.pathway_oid, ipw.pathway_name
            from img_reaction_t_components itc,
                 img_pathway_reactions ipr, img_pathway ipw
            where itc.term in ( $term_list )
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
        }; 
        my $cur = execSql( $dbh, $sql, $verbose );
    
        for ( ;; ) {
            my ($p_id, $p_name) = $cur->fetchrow();
            last if ! $p_id;
            
            $pway_name_h{$p_id} = $p_name;
            if ( $pway_cnt_h{$p_id} ) {
                $pway_cnt_h{$p_id} += 1;
            }
            else {
                $pway_cnt_h{$p_id} = 1;
            }
        }
        $cur->finish();
    }  # for gene_oid

    print start_form(-id     => "clusterPathways_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");

    print hiddenVar('taxon_oid',  $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    #my $it = new InnerTable( 0, "clusterPathways$$", "clusterPathways", 1 ); 
    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" ); 
    $it->addColSpec( "Pathway ID",   "asc",  "right" ); 
    $it->addColSpec( "Pathway Name", "asc",  "left" ); 
    $it->addColSpec( "Gene Count",   "desc", "right" ); 
 
    my $count = 0; 
    foreach my $pathway_oid (keys %pway_name_h) {
        my $pathway_name = $pway_name_h{$pathway_oid};
        my $gene_count = $pway_cnt_h{$pathway_oid};
        $count++; 
 
        my $r;
        $r .= $sd . "<input type='checkbox' name='func_id' "
	    . "value='IPWAY:$pathway_oid' /> \t";
	
        # pathway ID and name
        my $pway_oid = FuncUtil::pwayOidPadded($pathway_oid);
        my $pway_url = "$section_cgi&page=pathwayEvidence"
	    . "&pathway_oid=$pathway_oid"
	    . "&taxon_oid=$taxon_oid";
	if ( $cluster_id ) {
	    $pway_url .= "&cluster_id=$cluster_id"; 
	}
 
        $r .= $pathway_oid . $sd . alink( $pway_url, $pway_oid ) . "\t";
	if ( $keyword ) {
	    my $str = highlightMatchName($pathway_name, $keyword);
	    if ( $str ) {
		$pathway_name = $str;
	    }
	}
        $r .= $pathway_name . $sd . $pathway_name . "\t"; 
 
        # gene count
	my $url = "$main_cgi?section=ImgPwayBrowser&page=pwayAssocGeneList"
                . "&pway_oid=$pathway_oid&taxon_oid=$taxon_oid";
	if ( $cluster_id ) {
	    $url .= "&cluster_id=$cluster_id"; 
	}
        $r   .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";

        $it->addRow($r);
    } 
    $cur->finish();

    if ($count ) {
	#$it->hideAll() if $count < 10;
        $it->printOuterTable(1); 
    
        #my $name = "_section_FuncCartStor_addToFuncCart"; 
        my $name = "_section_FuncCartStor_addIpwayToFuncCart"; 
        my $buttonLabel = "Add Selected to Function Cart";
        my $buttonClass = "meddefbutton";
        print submit( 
	    -name  => $name,
	    -value => $buttonLabel, 
	    -class => $buttonClass
        ); 

    } else {
        print "<p>No IMG Pathways.\n";
    }

    print end_form();
    return $count;
}

###########################################################################
# printClusterMetacycList: list all Metacyc pathways associated with
#                          genes in this cluster
###########################################################################
sub printClusterMetacycList {
    my ($taxon_oid, $cluster_id, $keyword) = @_;

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');

    my $sql = qq{
        select bp.unique_id, bp.common_name, count(distinct bcf.feature_id)
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        biocyc_reaction br, gene_biocyc_rxns gb, 
        bio_cluster_features_new bcf, bio_cluster_new bc
        where bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.unique_id = gb.biocyc_rxn
        and br.ec_number = gb.ec_number
        and gb.gene_oid = bcf.gene_oid
        and bcf.feature_type = 'gene'
        and bc.cluster_id = ?
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = ?
        $rclause
        $imgClause
        group by bp.unique_id, bp.common_name
    };

    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );

    print "<h2>Metacyc Pathways</h2>"; 

    print start_form(-id     => "MetaCycPathways_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");

    #my $it = new InnerTable( 1, "MetaCycPathways$$", "MetaCycPathways", 0 );
    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "MetaCyc Pathway ID", "asc",  "left" );
    $it->addColSpec( "MetaCyc Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",         "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ( $uid, $category, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;

        my $row;
        $row .= $sd . "<input type='checkbox' name='func_id' "
	            . "value='MetaCyc:$uid' /> \t";

        my $pway_url = "$main_cgi?section=MetaCyc"
                     . "&page=detail&pathway_id=$uid"
		     . "&taxon_oid=$taxon_oid"
		     . "&cluster_id=$cluster_id";
        $row .= $uid . $sd . alink($pway_url, $uid) . "\t";

	if ( $keyword ) {
	    my $str = highlightMatchName($category, $keyword);
	    if ( $str ) {
		$category = $str;
	    }
	}
        $row .= $category . $sd . $category . "\t";

        my $url = "$main_cgi?section=TaxonDetail"
	        . "&page=metaCycGenes&unique_id=$uid"
		. "&taxon_oid=$taxon_oid"
		. "&cluster_id=$cluster_id";
        $row .= $gene_count . $sd . alink($url, $gene_count);
        $count++;

        $it->addRow($row);
    }
    $cur->finish();

    if ( $count ) {
	#$it->hideAll() if $count < 10;
        $it->printOuterTable(1);

	#my $name = "_section_${section}_metaCycGenes";
	my $name = "_section_FuncCartStor_addMetaCycToFuncCart";
        my $buttonLabel = "Add Selected to Function Cart";
        my $buttonClass = "meddefbutton";
        print submit(
                  -name  => $name,
                  -value => $buttonLabel,
                  -class => $buttonClass
	    );

    } else {
        print "<p>No Metacyc Pathways.\n";
    }

    print end_form();
}

###########################################################################
# printClusterMetacycList_meta: list all Metacyc pathways associated with
#                          genes in this cluster
# (for MER-FS)
###########################################################################
sub printClusterMetacycList_meta {
    my ($taxon_oid, $cluster_id, $keyword) = @_;

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');

    # get all genes in this cluster
    my @genes = ();
    my $sql = qq{
        select bcf.feature_id
        from bio_cluster_features_new bcf, bio_cluster_new bc
        where bc.cluster_id = ?
        and bcf.feature_type = 'gene'
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );
    for ( ;; ) {
    	my ($gene_id) = $cur->fetchrow();
    	last if ! $gene_id;
    	push @genes, ( $gene_id );
    }
    $cur->finish();

    my %metacyc_h;
    my %metacyc_name_h;
    foreach my $gene_oid ( @genes ) {
    	# get all enzymes of this gene
    	my @enzymes = MetaUtil::getGeneEc( $gene_oid, $taxon_oid, 'assembled' ); 
     
    	if ( scalar(@enzymes) == 0 ) { 
    	    next;
    	} 
     
    	my $enzyme_list = ""; 
    	foreach my $ec (@enzymes) { 
    	    if ($enzyme_list) { 
		$enzyme_list .= ", '" . $ec . "'"; 
    	    } else { 
		$enzyme_list = "'" . $ec . "'"; 
    	    } 
    	} 
    
    	my $sql = qq{
            select distinct bp.unique_id, bp.common_name
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
            biocyc_reaction br
            where bp.unique_id = brp.in_pwys
            and brp.unique_id = br.unique_id
            and br.ec_number in ( $enzyme_list )
        };
    
    	my $cur = execSql( $dbh, $sql, $verbose );
    	for ( ;; ) {
    	    my ($pathway_id, $pathway_name) = $cur->fetchrow();
    	    last if ! $pathway_id;
    
    	    $metacyc_name_h{$pathway_id} = $pathway_name;
    	    if ( $metacyc_h{$pathway_id} ) {
		$metacyc_h{$pathway_id} += 1;
    	    }
    	    else {
		$metacyc_h{$pathway_id} = 1;
    	    }
    	}
    }  # end for gene_oid

    print "<h2>Metacyc Pathways</h2>"; 
    print start_form(-id     => "MetaCycPathways_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");

    #my $it = new InnerTable( 1, "MetaCycPathways$$", "MetaCycPathways", 0 );
    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "MetaCyc Pathway ID", "asc",  "left" );
    $it->addColSpec( "MetaCyc Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",         "desc", "right" );

    my $count = 0;
    foreach my $uid (keys %metacyc_name_h) {
    	my $category = $metacyc_name_h{$uid};
    	my $gene_count = $metacyc_h{$uid};
        $count++;

        my $row;
        $row .= $sd . "<input type='checkbox' name='func_id' "
	            . "value='MetaCyc:$uid' /> \t";

        my $pway_url = "$main_cgi?section=MetaCyc"
                     . "&page=detail&pathway_id=$uid"
		     . "&taxon_oid=$taxon_oid"
		     . "&cluster_id=$cluster_id";
        $row .= $uid . $sd . alink($pway_url, $uid) . "\t";

	if ( $keyword ) {
	    my $str = highlightMatchName($category, $keyword);
	    if ( $str ) {
		$category = $str;
	    }
	}
        $row .= $category . $sd . $category . "\t";

        my $url = "$main_cgi?section=MetaDetail"
	        . "&page=metaCycGenes&unique_id=$uid"
		. "&taxon_oid=$taxon_oid&data_type=assembled"
		. "&cluster_id=$cluster_id";
        $row .= $gene_count . $sd . alink($url, $gene_count);
        $count++;

        $it->addRow($row);
    }
    $cur->finish();

    if ( $count ) {
	#$it->hideAll() if $count < 10;
        $it->printOuterTable(1);

	#my $name = "_section_${section}_metaCycGenes";
        my $name = "_section_FuncCartStor_addMetaCycToFuncCart";
        my $buttonLabel = "Add Selected to Function Cart";
        my $buttonClass = "meddefbutton";
        print submit(
                  -name  => $name,
                  -value => $buttonLabel,
                  -class => $buttonClass
	    );

    } else {
        print "<p>No Metacyc Pathways.\n";
    }

    print end_form();
}

###########################################################################
# printClusterKEGGList: list all KEGG categories associated with
#                       genes in this cluster
###########################################################################
sub printClusterKEGGList {
    my ($taxon_oid, $cluster_id) = @_;

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');

    my $sql = qq{
        select $nvl(pw.category, 'Unknown'), count( distinct bcf.feature_id )
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, bio_cluster_features_new bcf,
             bio_cluster_new bc
        where pw.pathway_oid = roi.pathway
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = gk.ko_terms
        and gk.gene_oid = bcf.gene_oid
        and bcf.feature_type = 'gene'
        and bcf.cluster_id = ?
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = ?
        $rclause
        $imgClause
        group by pw.category
        order by pw.category
    };

    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );

    print "<h2>KEGG Pathways</h2>";

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "KEGG Categories","asc",  "left" );
    $it->addColSpec( "Gene Count",     "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ( $category, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;

        my $catUrl = WebUtil::massageToUrl($category);
        my $url = "$main_cgi?section=TaxonDetail"
	        . "&page=keggCategoryGenes&category=$catUrl"
		. "&taxon_oid=$taxon_oid"
		. "&cluster_id=$cluster_id";

	my $row;
        $row .= escHtml($category) . "\t";
        $row .= $gene_count . $sd . alink($url, $gene_count) . "\t";
        $it->addRow($row);
	$count++;
    }

    $cur->finish();

    if ( $count ) {
	#$it->hideAll() if $count < 10;
        $it->printOuterTable(1);
    } else {
        print "<p>No KEGG Pathways.\n";
    }
}

###########################################################################
# printClusterKEGGList_meta: list all KEGG categories associated with
#                       genes in this cluster
# (for MER-FS)
###########################################################################
sub printClusterKEGGList_meta {
    my ($taxon_oid, $cluster_id) = @_;
    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');

    # get all genes in this cluster
    my @genes = ();
    my $sql = qq{
        select bcf.feature_id
        from bio_cluster_features_new bcf, bio_cluster_new bc
        where bc.cluster_id = ?
        and bcf.feature_type = 'gene'
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );
    for ( ;; ) {
	my ($gene_id) = $cur->fetchrow();
	last if ! $gene_id;
	push @genes, ( $gene_id );
    }
    $cur->finish();

    my %kegg_h;
    foreach my $gene_oid ( @genes ) {
	# get all KOs of this gene
	my @kos = MetaUtil::getGeneKoId( $gene_oid, $taxon_oid, 'assembled' ); 
	next if ( scalar(@kos) == 0 );
 
	my $ko_list = ""; 
	foreach my $ko_id (@kos) {
	    if ($ko_list) { 
		$ko_list .= ", '" . $ko_id . "'";
	    } else { 
		$ko_list = "'" . $ko_id . "'";
	    }
	} 

	my $sql = qq{
            select distinct $nvl(pw.category, 'Unknown')
            from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk
            where pw.pathway_oid = roi.pathway
            and roi.roi_id = rk.roi_id
            and rk.ko_terms in ( $ko_list )
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for ( ;; ) {
	    my ($category) = $cur->fetchrow();
	    last if ! $category;

	    if ( $kegg_h{$category} ) {
		$kegg_h{$category} += 1;
	    }
	    else {
		$kegg_h{$category} = 1;
	    }
	}
	$cur->finish();
    }

    print "<h2>KEGG Pathways</h2>";

    my $it = new StaticInnerTable();# 1, "keggcats$$", "keggcats", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "KEGG Categories","asc",  "left" );
    $it->addColSpec( "Gene Count",     "desc", "right" );

    my $count = 0;
    foreach my $category (sort keys %kegg_h) {
	my $gene_count = $kegg_h{$category};
        $count++;

        my $catUrl = WebUtil::massageToUrl($category);
        my $url = "$main_cgi?section=MetaDetail"
	        . "&page=keggCategoryGenes&category=$catUrl"
		. "&taxon_oid=$taxon_oid"
		. "&cluster_id=$cluster_id";

	my $row;
        $row .= escHtml($category) . "\t";
        $row .= $gene_count . $sd . alink($url, $gene_count) . "\t";
        $it->addRow($row);
	$count++;
    }

    $cur->finish();

    if ( $count ) {
	#$it->hideAll() if $count < 10;
        $it->printOuterTable(1);
    } else {
        print "<p>No KEGG Pathways.\n";
    }
}

############################################################################
# printClusterPathwayEvidence
############################################################################
sub printClusterPathwayEvidence {
    my ($pway_oid, $taxon_oid, $cluster_id) = @_;

    printMainForm();

    if ( $cluster_id ) {
	print "<h1>Biosynthetic Cluster Pathway</h1>\n";
    }
    else {
	print "<h1>Genome Pathway</h1>\n";
    }

    my $dbh = dbLogin();
    my $sql = "select pathway_name from img_pathway where pathway_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my ($pathway_name) = $cur->fetchrow();
    $cur->finish();

    my $p_url = "$main_cgi?section=ImgPwayBrowser"
	      . "&page=imgPwayDetail&pway_oid=$pway_oid"
	      . "&taxon_oid=$taxon_oid";
    if ( $cluster_id ) {
	$p_url .= "&cluster_id=$cluster_id";
    }
    print "<p>";
    print "Pathway: " . alink($p_url, "$pathway_name ($pway_oid)");

    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName($dbh, $taxon_oid);
    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<br/>Genome: " . alink( $url, $taxon_name ); 
    if ( $cluster_id ) {
	my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
	print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    }
    print "</p>"; 

    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);

    print "<h2>Evidence</h2>\n";

    my $sql = qq{
        select ir.rxn_oid, ipr.rxn_order, 
  	       ir.rxn_name, ir.rxn_definition
	from img_pathway_reactions ipr, img_reaction ir
        where ipr.pathway_oid = ?
	and ipr.rxn = ir.rxn_oid
	order by ipr.rxn_order, ipr.rxn
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my @reactions;
    my $old_rxn_order;
    my $subOrder = 0;
    my %rxnOid2SubOrder;
    for ( ;; ) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          $cur->fetchrow();
        last if !$rxn_oid;
        my $r = "$rxn_oid\t";
        $r .= "$rxn_order\t";
        $r .= "$rxn_name\t";
        $r .= "$rxn_definition\t";
        $subOrder = 0 if ( $old_rxn_order != $rxn_order );
        $rxnOid2SubOrder{$rxn_oid} = $subOrder++;
        push( @reactions, $r );
        $old_rxn_order = $rxn_order;
    }
    $cur->finish();
    if ( scalar(@reactions) == 0 ) {
        print "<p>\n";
        print "No reactions have been defined for this pathway.<br/>\n";
        print "</p>\n";
        return;
    }
    ## Massage order
    my $alphabet   = "abcdefghijklmnopqrstuvwxyz";
    my $nReactions = @reactions;
    for ( my $i = 0 ; $i < $nReactions ; $i++ ) {
        my $r_prev;
        $r_prev = $reactions[ $i - 1 ] if $i > 0;
        my (
             $rxn_oid_prev,   $rxn_order_prev, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_prev );
        my $subOrderPrev = $rxnOid2SubOrder{$rxn_oid_prev};

        my $r_curr = $reactions[$i];
        my (
             $rxn_oid_curr,   $rxn_order_curr, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_curr );
        my $subOrderCurr = $rxnOid2SubOrder{$rxn_oid_curr};

        my $r_next;
        $r_next = $reactions[ $i + 1 ] if $i < $nReactions - 1;
        my (
             $rxn_oid_next,   $rxn_order_next, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_next );
        my $subOrderNext = $rxnOid2SubOrder{$rxn_oid_next};

        if (    $rxn_order_curr eq $rxn_order_next
             || $rxn_order_curr eq $rxn_order_prev )
        {
            my $c = substr( $alphabet, $subOrderCurr, 1 );
            $rxnOid2SubOrder{$rxn_oid_curr} = $c;
        } else {
            $rxnOid2SubOrder{$rxn_oid_curr} = ".";
        }
    }
    my $sql = qq{
        select ipr.rxn rxn, irc.catalysts term_oid, 'catalyst', ''
	from img_pathway_reactions ipr, img_reaction_catalysts irc
        where ipr.rxn = irc.rxn_oid
	and ipr.pathway_oid = ?
	    union
        select ipr.rxn rxn, rtc.term term_oid, 'component', rtc.c_type
	from img_pathway_reactions ipr, img_reaction_t_components rtc
        where ipr.rxn = rtc.rxn_oid
	and ipr.pathway_oid = ?
	order by rxn, term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $pway_oid );
    my %rxn2TermOids;
    my %rxnTerm2Type;
    my @terms = ();
    for ( ;; ) {
        my ( $rxn, $term_oid, $r_type, $c_type ) = $cur->fetchrow();
        last if !$rxn;
        $rxn2TermOids{$rxn} .= "$term_oid ";
        push( @terms, $term_oid );
        my $k = "$rxn:$term_oid";
        my $type = "catalyst" if $r_type eq "catalyst";
        $type = $c_type if $r_type eq "component";
        $rxnTerm2Type{$k} = $type;
    }
    $cur->finish();

    print "<p>\n";
    print "You may select terms from the table below "
	. "and add them to the function cart.";
    print "</p>\n";
    WebUtil::printFuncCartFooterForEditor() if scalar @reactions > 10;

    print qq{
        <link rel="stylesheet" type="text/css"
         href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
    };

    print <<YUI;
    <div class='yui-dt'>
    <table style='font-size:12px'>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>Order</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>IMG Terms</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction Definition</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Gene IDs</span>
	    </div>
	</th>
	</tr>
YUI

    my $idx = 0;
    my $classStr;

    foreach my $r (@reactions) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          split( /\t/, $r );

	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";

        print "<tr class='$classStr'>\n";
        my $subOrder = $rxnOid2SubOrder{$rxn_oid};

        #my $taxonCount = $rxn2TaxonCount{ $rxn_oid };
        my $termOidStr = $rxn2TermOids{$rxn_oid};
        my @term_oids = sort( split( / /, $termOidStr ) );
        my @catalyst_term_oids;
        my @lhs_term_oids;
        my @rhs_term_oids;

        ## sort by LHS, catalyst, RHS
        my @sortRecs;
        foreach my $term_oid (@term_oids) {
            my $k    = "$rxn_oid:$term_oid";
            my $type = $rxnTerm2Type{$k};
            my $type2;
            if ( $type eq "catalyst" ) {
                $type2 = "M";    # sort in the middle between "LHS" and "RHS"
            } else {
                $type2 = $type;
            }
            my $r = "$type2\t$term_oid";
            push( @sortRecs, $r );
        }
        my @sortRecs2 = sort(@sortRecs);
        @term_oids = ();
        foreach my $sr (@sortRecs2) {
            my ( $type2, $term_oid ) = split( /\t/, $sr );
            push( @term_oids, $term_oid );
            if ( $type2 eq "M" || $type2 eq "" ) {
                push( @catalyst_term_oids, $term_oid );
            }
            if ( $type2 eq "LHS" ) {
                push( @lhs_term_oids, $term_oid );
            }
            if ( $type2 eq "RHS" ) {
                push( @rhs_term_oids, $term_oid );
            }
        }

        print "<td class='$classStr' style='text-align:right'>\n";
	print "<div class='yui-dt-liner'>\n";
	print $rxn_order . $subOrder;
	print "</div>\n";
	print "</td>\n";

        #print "<td class='img' align='right'>$rxn_oid</td>\n";
        my $nCatalysts = @catalyst_term_oids;
        my $nLhs       = @lhs_term_oids;
        my $nRhs       = @rhs_term_oids;
        my @term_oids  = @catalyst_term_oids;
        my $rhsOnly    = 0;
        if ( $nCatalysts == 0 && $nRhs > 0 && $nLhs == 0 ) {
            $rhsOnly = 1;
        }
        if ($rhsOnly) {
            @term_oids = @rhs_term_oids;
        }
        
        my %all_term_h; 
        my @all_term_oids;
        foreach my $term_oid (@catalyst_term_oids) {
            push( @all_term_oids, $term_oid );
            $all_term_h{$term_oid} = $term_oid;
        }
        foreach my $term_oid (@lhs_term_oids) {
            push( @all_term_oids, $term_oid );
            $all_term_h{$term_oid} = $term_oid;
        }
        foreach my $term_oid (@rhs_term_oids) {
            push( @all_term_oids, $term_oid );
            $all_term_h{$term_oid} = $term_oid;
        }
        # get all child terms
        foreach my $t2 (@all_term_oids) {
            my $term_list = ImgPwayBrowser::findAllChildTerms($dbh, $t2);
            if ( $term_list ) { 
                my @p_terms = split(/\t/, $term_list);
                for my $p2 (@p_terms) {
                    $all_term_h{$p2} = $p2;
                } 
            } 
        }   # end for t2 
        @all_term_oids = (keys %all_term_h); 
        
        ## IMG Terms
	print "<td class='$classStr' style='white-space:nowrap'>\n";
	print "<div class='yui-dt-liner'>\n";
        if ( $nCatalysts == 0 && $nLhs && $nRhs > 0 ) {
            print nbsp(1);
        } else {
            my $count = 0;
            foreach my $term_oid (@term_oids) {
                next if $term_oid eq "";
                $count++;
                my $n = $root->findNode($term_oid);
                if ( !defined($n) ) {
                    webLog(   "printReactionTerms: cannot find "
                            . "term_oid=$term_oid\n" );
                    next;
                }
                my $k    = "$rxn_oid:$term_oid";
                my $type = $rxnTerm2Type{$k};
                my %suffixMap;
                $suffixMap{$term_oid} = " ($type)"
                  if scalar(@term_oids) > 1;

                print "or<br/>\n" if $count > 1;
                $n->printHtml();
            }
        }
	print "</div>\n";
        print "</td>\n";

        ## Reaction Definition: Print LHS => RHS components
        my $c_rxn_definition = 
	    ImgPwayBrowser::getReactionCompounds( $dbh, $rxn_oid );
	my $rxn_url = "$main_cgi?section=ImgReaction"
              . "&page=imgRxnDetail&rxn_oid=$rxn_oid";
        if ( !blankStr($rxn_definition) ) {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n";
	    # print escHtml($rxn_definition);
	    print alink($rxn_url, $rxn_definition);
	    print "</div>\n";
	    print "</td>\n";
        } elsif ( !blankStr($c_rxn_definition) ) {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n";
            # print escHtml($c_rxn_definition);
	    print alink($rxn_url, $c_rxn_definition);
	    print "</div>\n";
	    print "</td>\n";
        } elsif ( $nLhs > 0 && $nRhs > 0 ) {
            my $url0 =
                "$main_cgi?section=ImgTermBrowser"
              . "&page=imgTermDetail&term_oid=";
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n";
            my $s;
            foreach my $term_oid (@lhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
            print " => <br/> ";

            my $s;
            foreach my $term_oid (@rhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
	    print "</div>\n";
            print "</td>\n";
        }
        ## Totally empty definition
        else {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n";
	    print nbsp(1);
	    print "</div>\n";
	    print "</td>\n";
        }
        print "<td class='$classStr' style='text-align:right'>\n";
	print "<div class='yui-dt-liner'>\n";
        printTermGenes( $dbh, $taxon_oid, $cluster_id, \@all_term_oids );
	print "</div>\n";
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }
    print "</table>\n";
    print "</div>\n";
    WebUtil::printFuncCartFooterForEditor();
}

sub printTermGenes {
    my ($dbh, $taxon_oid, $cluster_id, $term_oids_aref) = @_;

    my %done; 
    my $term_genes;

    foreach my $term_oid (@$term_oids_aref) { 
        my $rclause   = WebUtil::urClause('g.taxon'); 
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon'); 

	my $cur;
        my $sql = qq{
           select g.gene_oid
           from gene_img_functions g,
                bio_cluster_features_new bcg
           where g.function = ?
           and g.taxon = ?
           and g.gene_oid = bcg.feature_id
           --and g.gene_oid = bcg.gene_oid
           and bcg.feature_type = 'gene'
           and bcg.cluster_id = ?
           $rclause
           $imgClause
        }; 

	if ( $cluster_id ) {
	    $cur = execSql( $dbh, $sql, $verbose, $term_oid,
			    $taxon_oid, $cluster_id ); 
	}
	else {
	    $sql = qq{
                 select g.gene_oid
                 from gene_img_functions g
                 where g.function = ?
                 and g.taxon = ?
                 $rclause
                 $imgClause
                 };
	    $cur = execSql( $dbh, $sql, $verbose, $term_oid,
			    $taxon_oid );
	}

        for ( ;; ) { 
            my ($gene_oid) = $cur->fetchrow(); 
            last if !$gene_oid; 
            next if $done{$gene_oid}; 
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail"; 
            $url .= "&gene_oid=$gene_oid"; 
            print alink( $url, $gene_oid ) . "<br/>\n";
            $done{$gene_oid} = 1;
        } 
        $cur->finish(); 
    } 

    my @keys  = keys(%done);
    my $nKeys = @keys; 
    if ( $nKeys == 0 ) {
        print nbsp(1);
    } 
} 


##################################################################
# printBCNPForm: print form for NP addition or update
##################################################################
sub printBCNPForm {
    my ($upd) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $compound_oid = param("compound_oid");
    my $db_compound_oid = param("compound_oid");

    if ( $upd ) {
	print "<h1>Update Secondary Metabolite Information</h1>\n";
	if ( ! $compound_oid ) {
	    webError("No secondary metabolite has been selected.");
	    return;
	}
    }
    else {
	print "<h1>Add Secondary Metabolite Information</h1>\n";
    }
    printMainForm();

    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);
    print hiddenVar('db_compound_oid', $db_compound_oid);

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	return;
    }

    my $sql = qq{
        select tx.taxon_display_name, tx.gold_id,
               bc.scaffold, scf.scaffold_name
        from bio_cluster_new bc, taxon tx, scaffold scf
        where bc.taxon = ?
        and bc.cluster_id = ?
        and bc.taxon = tx.taxon_oid
        and bc.scaffold = to_char(scf.scaffold_oid)
    };

    my $dbh = dbLogin();
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $cluster_id);
    my ($taxon_display_name, $gold_id, $scaffold_oid, $scaffold_name)
	= $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Biosynthetic Cluster Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my $ncbi_acc = "";
    my $ncbi_taxon = "";

    my $np_class = "";
    my $np_sub_class = "";
    my $compound_name = "";
    my $is_partial;

    my $modified_by = "";
    my $mod_date = "";

    my $sql;
    my $cur;

    if ( $upd ) {
	$sql = qq{
            select cpd.compound_oid, cpd.compound_name,
                   cpd.np_class, cpd.np_sub_class,
                   np.ncbi_acc, np.ncbi_taxon,
                   np.is_partial, c.name, np.mod_date
            from np_biosynthesis_source\@img_ext np,
                 img_compound cpd, contact c
            where np.compound_oid = ?
            and np.cluster_id = ?
            and np.compound_oid = cpd.compound_oid
            and np.modified_by = c.contact_oid (+)
        };
	if ( $taxon_oid && isInt($taxon_oid) ) {
	    $sql .= " and np.taxon_oid = ? ";
	    $cur = execSql($dbh, $sql, $verbose, $compound_oid,
			   $cluster_id, $taxon_oid);
	}
	else {
	    $cur = execSql($dbh, $sql, $verbose, $compound_oid,
			   $cluster_id);
	}
	my $cid;
	($cid, $compound_name, $np_class, $np_sub_class,
	 $ncbi_acc, $ncbi_taxon, $is_partial,
	 $modified_by, $mod_date) =
	     $cur->fetchrow();
	$cur->finish();
    }

    if ( $compound_oid ) {
        my $url2 = "$main_cgi?section=$section&page=imgCpdDetail" .
	    "&compound_oid=$compound_oid"; 
	GeneDetail::printAttrRowRaw
	    ( "IMG Compound ID", alink($url2, $compound_oid) );
    }

    if ( $compound_name ) {
	GeneDetail::printAttrRowRaw
	    ( "Secondary Metabolite (SM) Name", $compound_name );
    }

    if ( $np_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Class", $np_class );
    }
    if ( $np_sub_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Subclass", $np_sub_class );
    }

    if ( $modified_by ) {
	GeneDetail::printAttrRowRaw
	    ( "Modified By", $modified_by );
    }
    if ( $mod_date ) {
	GeneDetail::printAttrRowRaw
	    ( "Mod Date", $mod_date );
    }

    print "</table>\n";

    print "<h5>Please enter the new secondary metabolite information:</h5>\n";

    my $it = new InnerTable( 1, "imgCompound$$", "imgCompound", 1 ); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" ); 
    $it->addColSpec( "Compound OID",   "number asc", "right" ); 
    $it->addColSpec( "Compound Name",   "char asc", "left" ); 
    $it->addColSpec( "DB Source", "char asc", "left" ); 
    $it->addColSpec( "Ext Accession", "char asc", "left" ); 
    $it->addColSpec( "Formula", "char asc", "left" ); 

    my $sql = "select c.compound_oid, c.ext_accession, c.db_source, " .
	"c.compound_name, c.formula from img_compound c";
    my $cur = execSql($dbh, $sql, $verbose);

    my $row = 0; 
    for ( ;; ) {
	my ($c_id, $c_ext_acc, $c_source, $c_name, $c_formula) =
	    $cur->fetchrow();
	last if ! $c_id;

	$c_id = sprintf( "%06d", $c_id ); 
        if ( !$c_name ) { 
            $c_name = "(null)"; 
        } 
 
        my $r = ""; 
	my $ck = "";
	if ( $c_id == $compound_oid ) {
	    $ck = "checked";
	}
	$r = $sd . 
	    "<input type='radio' name='compound_oid' value='$c_id' $ck />\t"; 
 
        my $url = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$c_id"; 
        $r .= $c_id . $sd . alink( $url, $c_id ) . "\t"; 
        $r .= $c_name . $sd . $c_name . "\t"; 
        $r .= $c_source . $sd . $c_source . "\t"; 
        my ($ex1, $ex2) = split(/\:/, $c_ext_acc);
        if ( $ex1 eq 'CHEBI' && isInt($ex2) ) {
            my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" .
                $ex2;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        elsif ( $c_source eq 'KEGG LIGAND' ) { 
            my $url3 = "http://www.kegg.jp/entry/" . $c_ext_acc;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        else { 
            $r .= $c_ext_acc . $sd . $c_ext_acc . "\t";
        } 
        $r .= $c_formula . $sd . $c_formula . "\t";
        $it->addRow($r); 
        $row++; 
    }
    $cur->finish();

    $it->hideAll() if $row < 10;
    $it->printOuterTable(1);

    print "<p>NCBI Accession: " . nbsp(2) . 
	"<input type='text' name='ncbi_acc' value = '$ncbi_acc' size='20' />\n";
    print "<p>NCBI Taxon: " . nbsp(2) . 
	"<input type='text' name='ncbi_taxon' value = '$ncbi_taxon' size='20' />\n";

    print "<p>Is Partial: " . nbsp(2);
    print "<select id='is_partial' name='is_partial' size='1'>\n";
    print "<option value='' ";
    if ( ! $is_partial ) {
	print " selected ";
    }
    print ">  </option>\n";

    foreach my $v2 ('No', 'Yes') {
	print "<option value='$v2' ";
	if ( $v2 eq $is_partial ) {
	    print " selected ";
	}
	print ">" . $v2 . "</option>\n";
    }
    print "</select>\n";

    print "<p>\n";
    my $name = "_section_${section}_dbAddNP";
    if ( $upd ) {
	$name = "_section_${section}_dbUpdateNP";
    }
    my $buttonLabel = "Update Database";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 

    print end_form();
}

##################################################################
# printBCNPForm_old: print form for NP addition or update
##################################################################
sub printBCNPForm_old {
    my ($upd) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    if ( $upd ) {
	print "<h1>Update Secondary Metabolite Information</h1>\n";
    }
    else {
	print "<h1>Add Secondary Metabolite Information</h1>\n";
    }
    printMainForm();

    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	webError("You do not have privilege to delete SM information.");
	return;
    }

    my $sql = qq{
        select tx.taxon_display_name, tx.gold_id,
               bc.scaffold, scf.scaffold_name
        from bio_cluster_new bc, taxon tx, scaffold scf
        where bc.taxon = ?
        and bc.cluster_id = ?
        and bc.taxon = tx.taxon_oid
        and bc.scaffold = to_char(scf.scaffold_oid)
    };

    my $dbh = dbLogin();
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $cluster_id);
    my ($taxon_display_name, $gold_id, $scaffold_oid, $scaffold_name)
	= $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Biosynthetic Cluster Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my $np_id = "";
    my $genbank_id = "";
    my $activity = "";
    my $evidence = "";
    my $project_oid;

    my $np_product_name = "";
    my $np_product_link = "";
    my $np_type = "";
    my $np_activity = "";
    my $img_compound_id;
    my $compound_name = "";

    if ( $upd ) {
	my $sql = qq{
            select np.np_id, np.project_oid, p.gold_stamp_id,
                   np.np_product_name, np.np_product_link,
                   np.np_type, np.activity,
                   np.genbank_id, np.evidence,
                   np.compound_oid, c.compound_name
            from natural_product\@img_ext np,
                 project_info\@imgsg_dev p,
                 img_compound c
            where np.project_oid = p.project_oid
            and np.cluster_id = ?
            and np.compound_oid = c.compound_oid (+)
        };
	my $cur = execSql($dbh, $sql, $verbose, $cluster_id);
	($np_id, $project_oid, $gold_id, $np_product_name,
	 $np_product_link, $np_type, $activity,
	 $genbank_id, $evidence,
	 $img_compound_id, $compound_name) =
	     $cur->fetchrow();
	$cur->finish();

	if ( $compound_name && ! $np_product_name ) {
	    $np_product_name = $compound_name;
	}
    }
    else {
	if ( $gold_id ) {
	    my $sql = "select p.project_oid from project_info\@imgsg_dev p " .
		"where p.gold_stamp_id = ? ";
	    my $cur = execSql($dbh, $sql, $verbose, $gold_id);
	    ($project_oid) = $cur->fetchrow();
	    $cur->finish();
	}
    }

    my $gold_link;
    if (!blankStr($gold_id)) {
        my $url = HtmlUtil::getGoldUrl($gold_id);
	   $gold_link = alink($url, "Project ID: $gold_id");
    }
    GeneDetail::printAttrRowRaw( "GOLD ID", $gold_link );
    if ( $project_oid ) {
	GeneDetail::printAttrRowRaw( "PROJECT_OID", $project_oid );
    }

    if ( $np_product_name ) {
	if ( $np_product_link ) {
	    GeneDetail::printAttrRowRaw
		( "Secondary Metabolite (SM) Name",
		  alink($np_product_link, $np_product_name) );
	}
	else {
	    GeneDetail::printAttrRowRaw
		( "Secondary Metabolite (SM) Name", $np_product_name );
	}
    }

    if ( $img_compound_id ) {
        my $url2 = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$img_compound_id"; 
	GeneDetail::printAttrRowRaw
	    ( "IMG Compound ID", alink($url2, $img_compound_id) );
    }
    if ( $compound_name ) {
	GeneDetail::printAttrRowRaw( "IMG Compound Name", $compound_name );
    }

    print "</table>\n";

    if ( $np_id ) {
	print hiddenVar('np_id', $np_id);
    }
    if ( $project_oid ) {
	print hiddenVar('project_oid', $project_oid);
    }

    print "<p>Please enter the new secondary metabolite information:\n";
    print "<p><input type='radio' name='np_mode' value='enter' />" .
	nbsp(2) . "Use Product Name: \n";
    print "<input type='text' name='newNpName' value='$np_product_name' " 
	. "size='60' maxLength='200' />\n";

    print "<p><input type='radio' name='np_mode' value='select' checked />" 
	. nbsp(2) . "<b>(Preferred)</b> Select From IMG Compound List:<br/>\n";

    my $it = new InnerTable( 1, "imgCompound$$", "imgCompound", 1 ); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" ); 
    $it->addColSpec( "Compound OID",   "number asc", "right" ); 
    $it->addColSpec( "Compound Name",   "char asc", "left" ); 
    $it->addColSpec( "DB Source", "char asc", "left" ); 
    $it->addColSpec( "Ext Accession", "char asc", "left" ); 
    $it->addColSpec( "Formula", "char asc", "left" ); 

    my $sql = "select c.compound_oid, c.ext_accession, c.db_source, " .
	"c.compound_name, c.formula from img_compound c";
    my $cur = execSql($dbh, $sql, $verbose);

    my $row = 0; 
    for ( ;; ) {
	my ($c_id, $c_ext_acc, $c_source, $c_name, $c_formula) =
	    $cur->fetchrow();
	last if ! $c_id;

	$c_id = sprintf( "%06d", $c_id ); 
        if ( !$c_name ) { 
            $c_name = "(null)"; 
        } 
 
        my $r = ""; 
	my $ck = "";
	if ( $c_id == $img_compound_id ) {
	    $ck = "checked";
	}
	$r = $sd .  "<input type='radio' name='compound_oid' value='$c_id' $ck />\t"; 
 
        my $url = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$c_id"; 
        $r .= $c_id . $sd . alink( $url, $c_id ) . "\t"; 
        $r .= $c_name . $sd . $c_name . "\t"; 
        $r .= $c_source . $sd . $c_source . "\t"; 
        my ($ex1, $ex2) = split(/\:/, $c_ext_acc);
        if ( $ex1 eq 'CHEBI' && isInt($ex2) ) {
            my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" .
                $ex2;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        elsif ( $c_source eq 'KEGG LIGAND' ) { 
            my $url3 = "http://www.kegg.jp/entry/" . $c_ext_acc;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        else { 
            $r .= $c_ext_acc . $sd . $c_ext_acc . "\t";
        } 
        $r .= $c_formula . $sd . $c_formula . "\t";
        $it->addRow($r); 
        $row++; 
    }
    $cur->finish();

    $it->hideAll() if $row < 10;
    $it->printOuterTable(1);

    print "<p>Evidence: " . nbsp(2);
    print "<select id='evidence' name='evidence' size='1'>\n";
    foreach my $v2 ('Experimental', 'Predicted') {
	print "<option value='$v2' ";
	if ( $v2 eq $evidence ) {
	    print " selected ";
	}
	print ">" . $v2 . "</option>\n";
    }
    print "</select>\n";

    print "<p>Genbank ID: " . nbsp(2) 
	. "<input type='text' name='newGenbankID' value = '$genbank_id' size='40' />\n";
    print "<p>Secondary Metabolite Link (URL): " . nbsp(2) 
	. "<input type='text' name='newNpLink' value = '$np_product_link' size='60' maxLength='255' />\n";
    print "<p>Secondary Metabolite Type: " . nbsp(2)
	. "<input type='text' name='newNpType' value = '$np_type' size='60' maxLength='128' />\n";
    print "<p>Secondary Metabolite Activity: " . nbsp(2) 
	. "<input type='text' name='newNpAct' value = '$activity' size='60' maxLength='500'/>\n";

    print "<p>\n";
    my $name = "_section_${section}_dbAddNP";
    if ( $upd ) {
	$name = "_section_${section}_dbUpdateNP";
    }
    my $buttonLabel = "Update Database";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 

    print end_form();
}

##################################################################
# printConfirmDeleteBCNPForm: print form for NP deletion
##################################################################
sub printConfirmDeleteBCNPForm {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $compound_oid = param("compound_oid");
    my $db_compound_oid = param("compound_oid");

    print "<h1>Confirm Deleting Secondary Metabolite Information</h1>\n";
    if ( ! $compound_oid ) {
	webError("No secondary metabolite has been selected.");
	return;
    }

    printMainForm();

    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);
    print hiddenVar('db_compound_oid', $db_compound_oid);
    print hiddenVar('compound_oid', $compound_oid);

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	webError("You do not have privilege to delete SM information.");
	return;
    }

    my $sql = qq{
        select tx.taxon_display_name, tx.gold_id,
               bc.scaffold, scf.scaffold_name
        from bio_cluster_new bc, taxon tx, scaffold scf
        where bc.taxon = ?
        and bc.cluster_id = ?
        and bc.taxon = tx.taxon_oid
        and bc.scaffold = to_char(scf.scaffold_oid)
    };

    my $dbh = dbLogin();
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $cluster_id);
    my ($taxon_display_name, $gold_id, $scaffold_oid, $scaffold_name)
	= $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Biosynthetic Cluster Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my $ncbi_acc = "";
    my $ncbi_taxon = "";

    my $np_class = "";
    my $np_sub_class = "";
    my $compound_name = "";
    my $is_partial;

    my $modified_by = "";
    my $mod_date = "";

    my $sql;
    my $cur;

    $sql = qq{
            select cpd.compound_oid, cpd.compound_name,
                   cpd.np_class, cpd.np_sub_class,
                   np.ncbi_acc, np.ncbi_taxon,
                   np.is_partial, c.name, np.mod_date
            from np_biosynthesis_source\@img_ext np,
                 img_compound cpd, contact c
            where np.compound_oid = ?
            and np.cluster_id = ?
            and np.compound_oid = cpd.compound_oid
            and np.modified_by = c.contact_oid (+)
        };
    if ( $taxon_oid && isInt($taxon_oid) ) {
	$sql .= " and np.taxon_oid = ? ";
	$cur = execSql($dbh, $sql, $verbose, $compound_oid,
		       $cluster_id, $taxon_oid);
    }
    else {
	$cur = execSql($dbh, $sql, $verbose, $compound_oid,
		       $cluster_id);
    }
    my $cid;
    ($cid, $compound_name, $np_class, $np_sub_class,
     $ncbi_acc, $ncbi_taxon, $is_partial,
     $modified_by, $mod_date) =
	 $cur->fetchrow();
    $cur->finish();

    if ( $compound_oid ) {
        my $url2 = "$main_cgi?section=$section&page=imgCpdDetail" .
	    "&compound_oid=$compound_oid"; 
	GeneDetail::printAttrRowRaw
	    ( "IMG Compound ID", alink($url2, $compound_oid) );
    }

    if ( $compound_name ) {
	GeneDetail::printAttrRowRaw
	    ( "Secondary Metabolite (SM) Name", $compound_name );
    }

    if ( $np_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Class", $np_class );
    }
    if ( $np_sub_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Subclass", $np_sub_class );
    }

    if ( $modified_by ) {
	GeneDetail::printAttrRowRaw
	    ( "Modified By", $modified_by );
    }
    if ( $mod_date ) {
	GeneDetail::printAttrRowRaw
	    ( "Mod Date", $mod_date );
    }

    print "</table>\n";

    print "<h5>Are you sure you want to delete this SM information?</h5>\n";

    print "<p>\n";
    my $name = "_section_${section}_dbDeleteNP";
    my $buttonLabel = "Yes, Update Database";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 

    print end_form();
}


############################################################################
# dbAddNP: SQL insertion
############################################################################
sub dbAddNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	$msg = "Error: You do not have privilege to update SM information.";
	return $msg;
    }

    if ( ! $cluster_id || ! $taxon_oid ) {
	$msg = "Error: Incomplete Data. SM info cannot be updated.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }


    my $ncbi_taxon = param('ncbi_taxon');
    if ( $ncbi_taxon && ! isInt($ncbi_taxon) ) {
	$msg = "Incorrect NCBI Taxon ID -- must be an integer.";
	return $msg;
    }

    my $dbh = dbLogin();
    my $sql1 = "select count(*) from np_biosynthesis_source " .
	"where cluster_id = ? and taxon_oid = ? and compound_oid = ? ";
    my $cur1 = execSql($dbh, $sql1, $verbose, $cluster_id,
		       $taxon_oid, $compound_oid);
    my ($cnt1) = $cur1->fetchrow();
    $cur1->finish();

    if ( $cnt1 ) {
	$msg = "The biosynthetic cluster already has this secondary metabolite.";
	return $msg;
    }

    my $contact_oid = WebUtil::getContactOid();

    my $ncbi_acc = param('ncbi_acc');
    my $ncbi_taxon = param('ncbi_taxon');
    my $is_partial = param('is_partial');

    $cluster_id =~ s/'/''/g;   # replace ' with ''
    $ncbi_acc =~ s/'/''/g;     # replace ' with ''

    my $sql = "insert into np_biosynthesis_source (cluster_id, " .
	"taxon_oid, compound_oid, ncbi_acc, ncbi_taxon, " .
	"is_partial, modified_by, mod_date) values (" .
	"'". $cluster_id . "', $taxon_oid, $compound_oid";
    if ( $ncbi_acc ) {
	$sql .= ", '" . $ncbi_acc . "'";
    }
    else {
	$sql .= ", null";
    }
    if ( $ncbi_taxon ) {
	$sql .= ", " . $ncbi_taxon;
    }
    else {
	$sql .= ", null";
    }
    if ( $is_partial ) {
	$sql .= ", '" . $is_partial . "'";
    }
    else {
	$sql .= ", null";
    }

    # modified_by, mod_date
    $sql .= ", $contact_oid, sysdate)";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbAddNP_old: SQL insertion
############################################################################
sub dbAddNP_old {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $project_oid = param('project_oid');

    my $dbh = dbLogin();
    my $sql1 = "select max(np_id) from natural_product";
    my $cur1 = execSql($dbh, $sql1, $verbose);
    my ($np_id) = $cur1->fetchrow();
    $cur1->finish();
    $np_id++;

    if ( ! $np_id ) {
	$msg = "Error: Incorrect database information. SM info cannot be updated.";
	return $msg;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $taxon_oid ) {
	$taxon_oid = 0;
    }
    if ( ! $project_oid ) {
	$project_oid = 0;
    }

    my $evidence = param('evidence');
    my $genbank_id = param('newGenbankID');

    $cluster_id =~ s/'/''/g;   # replace ' with ''
    my $sql = "insert into natural_product (np_id, " .
	"project_oid, taxon, cluster_id, genbank_id, evidence, " .
	"np_product_name, compound_oid, np_product_link, np_type, activity, " .
	"modified_by, mod_date) values ($np_id, $project_oid, " .
	"$taxon_oid, '" . $cluster_id . "', ";

    # genbank_id
    if ( $genbank_id ) {
	$genbank_id =~ s/'/''/g;   # replace ' with ''
	$sql .= "'" . $genbank_id . "'";
    }
    else {
	$sql .= "null";
    }

    # evidence
    $sql .= ", '$evidence', ";

    # np_product_name, compound_oid
    my $np_mode = param('np_mode');
    my $compound_oid = param('compound_oid');
    my $np_name = param('newNpName');
    if ( $np_mode eq 'select' ) {
	if ( ! $compound_oid ) {
	    $msg = "Error: No IMG Compound is selected.";
	    return $msg;
	}

	my $sql3 = "select compound_name from img_compound where compound_oid = ? ";
	my $cur3 = execSql($dbh, $sql3, $verbose, $compound_oid);
	($np_name) = $cur3->fetchrow();
	$cur3->finish();

	$np_name =~ s/'/''/g;    # replace ' with ''
	$sql .= "'$np_name', $compound_oid";
    }
    else {
	if ( ! $np_name ) {
	    $msg = "Error: No Secondary Metabolite Name.";
	    return $msg;
	}

	$np_name =~ s/'/''/g;    # replace ' with ''
	$sql .= "'$np_name', null";
    }

    my $np_type = param('newNpType');
    my $np_activity = param('newNpAct');
    my $natural_product_link = param('newNpLink');

    # np_product_link
    if ( $natural_product_link ) {
	$natural_product_link =~ s/'/''/g;   # replace ' with ''
	$sql .= ", '" . $natural_product_link . "'";
    }
    else {
	$sql .= ", null";
    }

    # np_type
    if ( $np_type ) {
	$np_type =~ s/'/''/g;   # replace ' with ''
	$sql .= ", '" . $np_type . "'";
    }
    else {
	$sql .= ", null";
    }

    # activity
    if ( $np_activity ) {
	$np_activity =~ s/'/''/g;   # replace ' with ''
	$sql .= ", '" . $np_activity . "', ";
    }
    else {
	$sql .= ", null, ";
    }

    # modified_by, mod_date
    $sql .= "$contact_oid, sysdate)";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbUpdateNP: SQL update
############################################################################
sub dbUpdateNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');
    my $db_compound_oid = param('db_compound_oid');

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	$msg = "Error: You do not have privilege to update SM information.";
	return $msg;
    }

    if ( ! $cluster_id || ! $taxon_oid || ! $db_compound_oid ) {
	$msg = "Error: Incomplete Data. SM info cannot be updated.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }


    my $ncbi_taxon = param('ncbi_taxon');
    if ( $ncbi_taxon && ! isInt($ncbi_taxon) ) {
	$msg = "Incorrect NCBI Taxon ID -- must be an integer.";
	return $msg;
    }

    my $dbh = dbLogin();
    my $cnt1 = 0;
    if ( $compound_oid != $db_compound_oid ) {
	my $sql1 = "select count(*) from np_biosynthesis_source " .
	    "where cluster_id = ? and taxon_oid = ? and compound_oid = ? ";
	my $cur1 = execSql($dbh, $sql1, $verbose, $cluster_id,
			   $taxon_oid, $compound_oid);
	($cnt1) = $cur1->fetchrow();
	$cur1->finish();
    }

    if ( $cnt1 ) {
	$msg = "The biosynthetic cluster already has this secondary metabolite.";
	return $msg;
    }

    my $contact_oid = WebUtil::getContactOid();

    my $ncbi_acc = param('ncbi_acc');
    my $ncbi_taxon = param('ncbi_taxon');
    my $is_partial = param('is_partial');

    $cluster_id =~ s/'/''/g;   # replace ' with ''
    $ncbi_acc =~ s/'/''/g;   # replace ' with ''

    my $sql = "update np_biosynthesis_source " .
	"set compound_oid = $compound_oid";
    if ( $ncbi_acc ) {
	$sql .= ", ncbi_acc = '" . $ncbi_acc . "'";
    }
    else {
	$sql .= ", ncbi_acc = null";
    }
    if ( $ncbi_taxon ) {
	$sql .= ", ncbi_taxon = " . $ncbi_taxon;
    }
    else {
	$sql .= ", ncbi_taxon = null";
    }
    if ( $is_partial ) {
	$sql .= ", is_partial = '" . $is_partial . "'";
    }
    else {
	$sql .= ", is_partial = null";
    }

    # modified_by, mod_date
    my $db_cluster_id = $cluster_id;
    $db_cluster_id =~ s/'/''/g;   # replace ' with '' if any
    $sql .= ", modified_by = $contact_oid, mod_date = sysdate ";
    $sql .= " where taxon_oid = $taxon_oid " .
	"and cluster_id = '" . $cluster_id . "'" .
	"and compound_oid = $db_compound_oid";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbUpdateNP_old: SQL update
############################################################################
sub dbUpdateNP_old {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $np_id = param('np_id');

    if ( ! $np_id ) {
	$msg = "Error: Incorrect database information. SM info cannot be updated.";
	return $msg;
    }

    my $sql = "update natural_product";
    my $contact_oid = WebUtil::getContactOid();
    $sql .= " set modified_by = $contact_oid, mod_date = sysdate";

    # np_product_name, compound_oid
    $sql .= ", np_product_name = '";
    my $np_mode = param('np_mode');
    my $compound_oid = param('compound_oid');
    my $np_name = param('newNpName');
    if ( $np_mode eq 'select' ) {
	if ( ! $compound_oid ) {
	    $msg = "Error: No IMG Compound is selected.";
	    return $msg;
	}

	my $dbh = dbLogin();
	my $sql3 = "select compound_name from img_compound where compound_oid = ? ";
	my $cur3 = execSql($dbh, $sql3, $verbose, $compound_oid);
	($np_name) = $cur3->fetchrow();
	$cur3->finish();

	$np_name =~ s/'/''/g;    # replace ' with ''
	$sql .= $np_name . "', img_compound_id = $compound_oid";
    }
    else {
	if ( ! $np_name ) {
	    $msg = "Error: No Secondary Metabolite Name.";
	    return $msg;
	}

	$np_name =~ s/'/''/g;    # replace ' with ''
	$sql .= $np_name . "', img_compound_id = null";
    }

    my $evidence = param('evidence');
    my $genbank_id = param('newGenbankID');
    my $np_type = param('newNpType');
    my $np_activity = param('newNpAct');
    my $natural_product_link = param('newNpLink');

    # evidence
    $sql .= ", evidence = '" . $evidence . "'";

    # genbank_id
    if ( $genbank_id ) {
	$genbank_id =~ s/'/''/g;   # replace ' with ''
	$sql .= ", genbank_id = '" . $genbank_id . "'";
    }
    else {
	$sql .= ", genbank_id = null";
    }

    # np_product_link
    if ( $natural_product_link ) {
	$natural_product_link =~ s/'/''/g;   # replace ' with ''
	$sql .= ", natural_product_link = '" . $natural_product_link . "'";
    }
    else {
	$sql .= ", natural_product_link = null";
    }

    # np_type
    if ( $np_type ) {
	$np_type =~ s/'/''/g;   # replace ' with ''
	$sql .= ", np_type = '" . $np_type . "'";
    }
    else {
	$sql .= ", np_type = null";
    }

    # activity
    if ( $np_activity ) {
	$np_activity =~ s/'/''/g;   # replace ' with ''
	$sql .= ", activity = '" . $np_activity . "'";
    }
    else {
	$sql .= ", activity = null";
    }

    $sql .= " where np_id = $np_id";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbDeleteNP: SQL deletion
############################################################################
sub dbDeleteNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');
    my $db_compound_oid = param('db_compound_oid');

    my $super_user = getSuperUser();
    if ( $super_user ne 'Yes' ) {
	$msg = "Error: You do not have privilege to update SM information.";
	return $msg;
    }

    if ( ! $cluster_id || ! $taxon_oid ) {
	$msg = "Error: Incomplete Data. SM info cannot be updated.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $db_compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }

    my $sql = "delete from np_biosynthesis_source ";
    $sql .= " where taxon_oid = $taxon_oid " .
	"and cluster_id = '" . $cluster_id . "'" .
	"and compound_oid = $db_compound_oid";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}


##################################################################
# printMyIMGBCNPForm: print form for MyIMG NP info 
#                     addition or update
##################################################################
sub printMyIMGBCNPForm {
    my ($upd) = @_;

    my $myimg_bc_np = param("myimg_bc_np");
    my ($compound_oid, $taxon_oid, $cluster_id) =
	split(/\,/, $myimg_bc_np);
    my $db_compound_oid = $compound_oid;

    $taxon_oid = param('taxon_oid');
    $cluster_id = param('cluster_id');

    if ( $upd ) {
	print "<h1>Update MyIMG SM Annotation</h1>\n";
	if ( ! $compound_oid ) {
	    webError("No annotation has been selected.");
	    return;
	}
    }
    else {
	print "<h1>Add MyIMG SM Annotation</h1>\n";
    }
    printMainForm();

    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);
    print hiddenVar('db_compound_oid', $db_compound_oid);

    my $contact_oid = WebUtil::getContactOid();

    my $sql = qq{
        select tx.taxon_display_name
        from taxon tx
        where tx.taxon_oid = ?
    };

    my $dbh = dbLogin();
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid);
    my ($taxon_display_name) = $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Biosynthetic Cluster Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my $ncbi_acc = "";
    my $ncbi_taxon = "";

    my $np_class = "";
    my $np_sub_class = "";
    my $compound_name = "";
    my $is_partial;
    my $is_public;
    my $comments = "";
    my $mod_date = "";

    my $sql;
    my $cur;

    if ( $upd ) {
	$sql = qq{
            select cpd.compound_oid, cpd.compound_name,
                   cpd.np_class, cpd.np_sub_class,
                   np.ncbi_acc, np.ncbi_taxon,
                   np.is_partial, np.is_public,
                   np.comments, np.mod_date
            from myimg_bio_cluster_np\@img_ext np,
                 img_compound cpd
            where np.compound_oid = ?
            and np.cluster_id = ?
            and np.compound_oid = cpd.compound_oid
            and np.modified_by = ?
        };
	if ( $taxon_oid && isInt($taxon_oid) ) {
	    $sql .= " and np.taxon_oid = ? ";
	    $cur = execSql($dbh, $sql, $verbose, $compound_oid,
			   $cluster_id, $contact_oid, $taxon_oid);
	}
	else {
	    $cur = execSql($dbh, $sql, $verbose, $compound_oid,
			   $cluster_id, $contact_oid);
	}
	my $cid;
	($cid, $compound_name, $np_class, $np_sub_class,
	 $ncbi_acc, $ncbi_taxon, $is_partial, $is_public,
	 $comments, $mod_date) =
	     $cur->fetchrow();
	$cur->finish();
    }

    if ( $compound_oid ) {
        my $url2 = "$main_cgi?section=$section&page=imgCpdDetail" .
	    "&compound_oid=$compound_oid"; 
	GeneDetail::printAttrRowRaw
	    ( "IMG Compound ID", alink($url2, $compound_oid) );
    }

    if ( $compound_name ) {
	GeneDetail::printAttrRowRaw
	    ( "Secondary Metabolite (SM) Name", $compound_name );
    }

    if ( $np_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Class", $np_class );
    }
    if ( $np_sub_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Subclass", $np_sub_class );
    }

    if ( $mod_date ) {
	GeneDetail::printAttrRowRaw
	    ( "Mod Date", $mod_date );
    }

    print "</table>\n";

    print "<h5>Please enter the new secondary metabolite annotation:</h5>\n";

    my $it = new InnerTable( 1, "imgCompound$$", "imgCompound", 1 ); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Select" ); 
    $it->addColSpec( "Compound OID",   "number asc", "right" ); 
    $it->addColSpec( "Compound Name",   "char asc", "left" ); 
    $it->addColSpec( "DB Source", "char asc", "left" ); 
    $it->addColSpec( "Ext Accession", "char asc", "left" ); 
    $it->addColSpec( "Formula", "char asc", "left" ); 

    my $sql = "select c.compound_oid, c.ext_accession, c.db_source, " .
	"c.compound_name, c.formula from img_compound c";
    my $cur = execSql($dbh, $sql, $verbose);

    my $row = 0; 
    for ( ;; ) {
	my ($c_id, $c_ext_acc, $c_source, $c_name, $c_formula) =
	    $cur->fetchrow();
	last if ! $c_id;

	$c_id = sprintf( "%06d", $c_id ); 
        if ( !$c_name ) { 
            $c_name = "(null)"; 
        } 
 
        my $r = ""; 
	my $ck = "";
	if ( $c_id == $compound_oid ) {
	    $ck = "checked";
	}
	$r = $sd .  "<input type='radio' name='compound_oid' value='$c_id' $ck />\t"; 
 
        my $url = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$c_id"; 
        $r .= $c_id . $sd . alink( $url, $c_id ) . "\t"; 
        $r .= $c_name . $sd . $c_name . "\t"; 
        $r .= $c_source . $sd . $c_source . "\t"; 
        my ($ex1, $ex2) = split(/\:/, $c_ext_acc);
        if ( $ex1 eq 'CHEBI' && isInt($ex2) ) {
            my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" .
                $ex2;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        elsif ( $c_source eq 'KEGG LIGAND' ) { 
            my $url3 = "http://www.kegg.jp/entry/" . $c_ext_acc;
            $r .= $c_ext_acc . $sd . alink($url3, $c_ext_acc) . "\t";
        } 
        else { 
            $r .= $c_ext_acc . $sd . $c_ext_acc . "\t";
        } 
        $r .= $c_formula . $sd . $c_formula . "\t";
        $it->addRow($r); 
        $row++; 
    }
    $cur->finish();

    $it->hideAll() if $row < 10;
    $it->printOuterTable(1);

    print "<p>NCBI Accession: " . nbsp(2) 
	. "<input type='text' name='ncbi_acc' value = '$ncbi_acc' size='20' />\n";
    print "<p>NCBI Taxon: " . nbsp(2) 
	. "<input type='text' name='ncbi_taxon' value = '$ncbi_taxon' size='20' />\n";

    print "<p>Is Partial: " . nbsp(2);
    print "<select id='is_partial' name='is_partial' size='1'>\n";
    print "<option value='' ";
    if ( ! $is_partial ) {
	print " selected ";
    }
    print ">  </option>\n";

    foreach my $v2 ('No', 'Yes') {
	print "<option value='$v2' ";
	if ( $v2 eq $is_partial ) {
	    print " selected ";
	}
	print ">" . $v2 . "</option>\n";
    }
    print "</select>\n";

    print "<p>Is Public: " . nbsp(2);
    print "<select id='is_public' name='is_public' size='1'>\n";

    foreach my $v2 ('No', 'Yes') {
	print "<option value='$v2' ";
	if ( $v2 eq $is_public ) {
	    print " selected ";
	}
	print ">" . $v2 . "</option>\n";
    }
    print "</select>\n";

    print "<p>Comments: " . nbsp(2) 
	. "<input type='text' name='comments' value = '$comments' size='60' maxLength='255'/>\n";

    print "<p>\n";
    my $name = "_section_${section}_dbAddMyIMGNP";
    if ( $upd ) {
	$name = "_section_${section}_dbUpdateMyIMGNP";
    }
    my $buttonLabel = "Update Database";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 

    print end_form();
}

##################################################################
# printConfirmDeleteMyIMGBCNPForm: print form for MyIMG deletion
##################################################################
sub printConfirmDeleteMyIMGBCNPForm {
    my $myimg_bc_np = param("myimg_bc_np");
    my ($compound_oid, $taxon_oid, $cluster_id) =
	split(/\,/, $myimg_bc_np);

    print "<h1>Confirm Deleting MyIMG Secondary Metabolite Annotation</h1>\n";
    if ( ! $compound_oid || ! $taxon_oid || ! $cluster_id ) {
	webError("No MyIMG SM annotation has been selected.");
	return;
    }

    printMainForm();

    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);
    print hiddenVar('db_compound_oid', $compound_oid);
    print hiddenVar('compound_oid', $compound_oid);

    my $contact_oid = WebUtil::getContactOid();

    my $sql = qq{
        select np.cluster_id, np.taxon_oid, tx.taxon_display_name,
               np.compound_oid, cpd.compound_name,
               cpd.np_class, cpd.np_sub_class,
               np.ncbi_acc, np.ncbi_taxon, 
               np.comments, np.mod_date
        from myimg_bio_cluster_np np, img_compound cpd,
             taxon tx
        where np.cluster_id = ?
        and np.taxon_oid = ?
        and np.compound_oid = ?
        and np.modified_by = ?
        and np.compound_oid = cpd.compound_oid
        and np.taxon_oid = tx.taxon_oid
    };

    my $dbh = dbLogin();
    my $cur = execSql($dbh, $sql, $verbose, $cluster_id,
		      $taxon_oid, $compound_oid, $contact_oid);
    my ($c_id, $tx_id, $taxon_display_name,
	$cpd_id, $compound_name, $np_class, $np_sub_class,
	$ncbi_acc, $ncbi_taxon,	$comments, $mod_date) =
	$cur->fetchrow();
    $cur->finish();

    if ( ! $c_id || ! $tx_id || ! $cpd_id ) {
	webError("No MyIMG SM annotation has been selected.");
	return;
    }

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "MyIMG SM Annotation</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Cluster ID", $cluster_id );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    if ( $compound_oid ) {
        my $url2 = "$main_cgi?section=$section&page=imgCpdDetail" .
	    "&compound_oid=$compound_oid"; 
	GeneDetail::printAttrRowRaw
	    ( "IMG Compound ID", alink($url2, $compound_oid) );
    }

    if ( $compound_name ) {
	GeneDetail::printAttrRowRaw
	    ( "Secondary Metabolite (SM) Name", $compound_name );
    }

    if ( $np_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Class", $np_class );
    }
    if ( $np_sub_class ) {
	GeneDetail::printAttrRowRaw
	    ( "SM Subclass", $np_sub_class );
    }

    if ( $ncbi_acc ) {
	GeneDetail::printAttrRowRaw
	    ( "NCBI Accession", $ncbi_acc );
    }
    if ( $ncbi_taxon ) {
	GeneDetail::printAttrRowRaw
	    ( "NCBI Taxon ID", $ncbi_taxon );
    }

    if ( $comments ) {
	GeneDetail::printAttrRowRaw
	    ( "Comments", $comments );
    }

    if ( $mod_date ) {
	GeneDetail::printAttrRowRaw
	    ( "Mod Date", $mod_date );
    }

    print "</table>\n";

    print "<h5>Are you sure you want to delete this MyIMG SM annotation?</h5>\n";

    print "<p>\n";
    my $name = "_section_${section}_dbDeleteMyIMGNP";
    my $buttonLabel = "Yes, Delete Annotation";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 

    print end_form();
}


############################################################################
# dbAddMyIMGNP: SQL insertion
############################################################################
sub dbAddMyIMGNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');

    if ( ! $cluster_id || ! $taxon_oid ) {
	$msg = "Error: Incomplete Data. SM annotation cannot be added.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }


    my $ncbi_taxon = param('ncbi_taxon');
    if ( $ncbi_taxon && ! isInt($ncbi_taxon) ) {
	$msg = "Incorrect NCBI Taxon ID -- must be an integer.";
	return $msg;
    }

    my $contact_oid = getContactOid();

    my $dbh = dbLogin();
    my $sql1 = "select count(*) from myimg_bio_cluster_np " .
	"where cluster_id = ? and taxon_oid = ? " .
	"and compound_oid = ? and modified_by = ? ";
    my $cur1 = execSql($dbh, $sql1, $verbose, $cluster_id,
		       $taxon_oid, $compound_oid, $contact_oid);
    my ($cnt1) = $cur1->fetchrow();
    $cur1->finish();

    if ( $cnt1 ) {
	$msg = "There is already an annotation with this cluster and SM.";
	return $msg;
    }

    my $ncbi_acc = param('ncbi_acc');
    my $ncbi_taxon = param('ncbi_taxon');
    my $is_partial = param('is_partial');
    my $is_public = param('is_public');
    my $comments = param('comments');

    $cluster_id =~ s/'/''/g;   # replace ' with ''
    $ncbi_acc =~ s/'/''/g;   # replace ' with ''
    if ( length($comments) > 255 ) {
	$comments = substr( $comments, 0, 255 ); 
    }
    $comments =~ s/'/''/g;   # replace ' with ''

    my $sql = "insert into myimg_bio_cluster_np (cluster_id, " .
	"taxon_oid, compound_oid, ncbi_acc, ncbi_taxon, " .
	"is_partial, is_public, comments, " .
	"modified_by, mod_date) values (" .
	"'". $cluster_id . "', $taxon_oid, $compound_oid";
    if ( $ncbi_acc ) {
	$sql .= ", '" . $ncbi_acc . "'";
    }
    else {
	$sql .= ", null";
    }
    if ( $ncbi_taxon ) {
	$sql .= ", " . $ncbi_taxon;
    }
    else {
	$sql .= ", null";
    }

    if ( $is_partial ) {
	$sql .= ", '" . $is_partial . "'";
    }
    else {
	$sql .= ", null";
    }
    if ( $is_public ) {
	$sql .= ", '" . $is_public . "'";
    }
    else {
	$sql .= ", null";
    }

    if ( $comments ) {
	$sql .= ", '" . $comments . "'";
    }
    else {
	$sql .= ", null";
    }

    # modified_by, mod_date
    $sql .= ", $contact_oid, sysdate)";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbUpdateMyIMGNP: SQL update
############################################################################
sub dbUpdateMyIMGNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');
    my $db_compound_oid = param('db_compound_oid');

    my $contact_oid = getContactOid();

    if ( ! $cluster_id || ! $taxon_oid || ! $db_compound_oid ) {
	$msg = "Error: Incomplete Data. SM annotation cannot be updated.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }


    my $ncbi_taxon = param('ncbi_taxon');
    if ( $ncbi_taxon && ! isInt($ncbi_taxon) ) {
	$msg = "Incorrect NCBI Taxon ID -- must be an integer.";
	return $msg;
    }

    my $dbh = dbLogin();
    my $cnt1 = 0;
    if ( $compound_oid != $db_compound_oid ) {
	my $sql1 = "select count(*) from myimg_bio_cluster_np " .
	    "where cluster_id = ? and taxon_oid = ? " .
	    "and compound_oid = ? and modified_by = ? ";
	my $cur1 = execSql($dbh, $sql1, $verbose, $cluster_id,
			   $taxon_oid, $compound_oid, $contact_oid);
	($cnt1) = $cur1->fetchrow();
	$cur1->finish();
    }

    if ( $cnt1 ) {
	$msg = "There is already an annotation with this cluster and selected SM.";
	return $msg;
    }

    my $ncbi_acc = param('ncbi_acc');
    my $ncbi_taxon = param('ncbi_taxon');
    my $is_partial = param('is_partial');
    my $is_public = param('is_public');
    my $comments = param('comments');

    $cluster_id =~ s/'/''/g;   # replace ' with ''
    $ncbi_acc =~ s/'/''/g;   # replace ' with ''
    if ( length($comments) > 255 ) {
	$comments = substr( $comments, 0, 255 ); 
    }
    $comments =~ s/'/''/g;   # replace ' with ''

    my $sql = "update myimg_bio_cluster_np " .
	"set compound_oid = $compound_oid";
    if ( $ncbi_acc ) {
	$sql .= ", ncbi_acc = '" . $ncbi_acc . "'";
    }
    else {
	$sql .= ", ncbi_acc = null";
    }
    if ( $ncbi_taxon ) {
	$sql .= ", ncbi_taxon = " . $ncbi_taxon;
    }
    else {
	$sql .= ", ncbi_taxon = null";
    }

    if ( $is_partial ) {
	$sql .= ", is_partial = '" . $is_partial . "'";
    }
    else {
	$sql .= ", is_partial = null";
    }
    if ( $is_public ) {
	$sql .= ", is_public = '" . $is_public . "'";
    }
    else {
	$sql .= ", is_public = null";
    }

    if ( $comments ) {
	$sql .= ", comments = '" . $comments . "'";
    }
    else {
	$sql .= ", comments = null";
    }

    # modified_by, mod_date
    my $db_cluster_id = $cluster_id;
    $db_cluster_id =~ s/'/''/g;   # replace ' with '' if any
    $sql .= ", mod_date = sysdate ";
    $sql .= " where taxon_oid = $taxon_oid " .
	"and cluster_id = '" . $cluster_id . "'" .
	"and compound_oid = $db_compound_oid " .
	"and modified_by = $contact_oid ";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

############################################################################
# dbDeleteMyIMGNP: SQL deletion
############################################################################
sub dbDeleteMyIMGNP {
    my $msg = "";
    my $cluster_id = param('cluster_id');
    my $taxon_oid = param('taxon_oid');
    my $compound_oid = param('compound_oid');
    my $db_compound_oid = param('db_compound_oid');

    my $contact_oid = getContactOid();

    if ( ! $cluster_id || ! $taxon_oid || ! $contact_oid ) {
	$msg = "Error: Incomplete Data. SM annotation cannot be deleted.";
	return $msg;
    }

    if ( ! isInt($taxon_oid) ) {
	$msg = "Incorrect taxon OID.";
	return $msg;
    }

    if ( ! $db_compound_oid ) {
	$msg = "No compound has been selected.";
	return $msg;
    }

    my $sql = "delete from myimg_bio_cluster_np ";
    $sql .= " where taxon_oid = $taxon_oid " .
	"and cluster_id = '" . $cluster_id . "'" .
	"and compound_oid = $db_compound_oid " .
	"and modified_by = $contact_oid ";

    # perform database update
    my @sqlList = ( $sql );
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) { 
        my $sql3 = $sqlList[ $err - 1 ];
	$msg = "SQL Error: " . $sql3;
	return $msg;
    } 

    return "";
}

###########################################################################
# printBiosyntheticClusters (moved from TaxonDetail.pm)
###########################################################################
sub printBiosyntheticClusters {
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }
        
    my $taxon_oid = param("taxon_oid");
    my $dbh = dbLogin();
    processBiosyntheticClusters( $dbh, $taxon_oid, '', '',
				 "Biosynthetic Clusters for Genome" );
}

###########################################################################
# processBiosyntheticClusters
# input either ($taxon_id and/or $cluster_ids_ref) or $clusterId2taxons_href
###########################################################################
sub processBiosyntheticClusters {
    my ( $dbh, $taxon_id, $cluster_ids_ref, $clusterId2taxons_href, 
	 $title, $subTitle ) = @_;
    
    if ( !$taxon_id && $cluster_ids_ref eq '' &&
	 $clusterId2taxons_href eq '' ) {
        webError("No Biosynthetic Cluster or Taxon!");
    }

    printStartWorkingDiv();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $taxon_clause;
    my @binds;
    my %validateTaxon2;
    if ( $taxon_id ) {
        $taxon_clause = " and g.taxon = ? ";
        push(@binds, $taxon_id);
        $validateTaxon2{$taxon_id} = $taxon_id;
    }
    elsif ( $clusterId2taxons_href ) {
        #print "processBiosyntheticClusters() clusterId2taxons_href=<br/>\n";
        #print Dumper($clusterId2taxons_href) . "<br/>\n";
        my @taxon_ids;
        foreach my $key (%$clusterId2taxons_href) {
            my $taxons_ref = $clusterId2taxons_href->{$key};
            push(@taxon_ids, @$taxons_ref) if ( $taxons_ref );
        }
        %validateTaxon2 = WebUtil::array2Hash(@taxon_ids);
    }

    if ( $clusterId2taxons_href ) {
        my @clusterIds = keys %$clusterId2taxons_href;
        $cluster_ids_ref = \@clusterIds;
    }
    
    my $cluster_ids_clause;
    if ( $cluster_ids_ref && scalar(@$cluster_ids_ref) > 0 ) {
        my $cluster_ids_str = 
	    OracleUtil::getFuncIdsInClause( $dbh, @$cluster_ids_ref );
        $cluster_ids_clause = " and g.cluster_id in ($cluster_ids_str) ";
    }

    print "<br/>Getting gene count per cluster...<br/>\n";
    my $cacheFile01 = "allGeneCountPerCluster01";
    my $sql = qq{
        select g.cluster_id, g.taxon, g.scaffold, 
               count(distinct bcf.feature_id), count(distinct bcf.pfam_id)
        from bio_cluster_features_new bcf, bio_cluster_new g
        where bcf.feature_type = 'gene'
        and g.cluster_id = bcf.cluster_id
        $cluster_ids_clause
        $taxon_clause
        $rclause
        $imgClause
        group by g.cluster_id, g.taxon, g.scaffold
    };
    
    my %validateTaxons = WebUtil::getAllTaxonsHashed($dbh); 
    my %validateClusters;
    if ($cluster_ids_ref ne '') {
        %validateClusters = WebUtil::array2Hash(@$cluster_ids_ref);
    }
    my $aref = OracleUtil::execSqlCached
	( $dbh, $sql, 'allGeneCountPerCluster01', 1, @binds );
    
    my %taxons_h;
    my %bcid2taxon;
    my %bcid2scaffold;
    my %bcid2geneCnt;
    my %bcid2pfamCnt;

    foreach my $inner_aref (@$aref) {
        my ($cluster_id, $taxon_oid, $scaffold_oid, $gene_count, $pfam_count)
	    = @$inner_aref;
        last if !$cluster_id;
        next if ($taxon_id ne '' && $taxon_id ne $taxon_oid);
        next if ($cluster_ids_ref ne '' &&
		 !exists $validateClusters{$cluster_id});
        next if ($clusterId2taxons_href ne '' 
		 && !exists $clusterId2taxons_href->{$cluster_id});
        next if (!exists $validateTaxons{$taxon_oid});
        # TODO validate taxons
        
        #if ( $clusterId2taxons_href ) {
        #    my $taxons_ref = $clusterId2taxons_href->{$cluster_id};
        #    next if ( !WebUtil::inArray($taxon_oid, @$taxons_ref) );
        #}

        $bcid2taxon{$cluster_id} = $taxon_oid;
        $taxons_h{$taxon_oid} = 1;
        $bcid2scaffold{$cluster_id} = $scaffold_oid;
        $bcid2geneCnt{$cluster_id} = $gene_count;        
        $bcid2pfamCnt{$cluster_id} = $pfam_count;
    }
    
    my @taxon_oids = keys %taxons_h;
    my ($taxon2name_href, $taxon_in_file_href, $taxon_db_href, $taxon_oids_str)
        = QueryUtil::fetchTaxonsOidAndNameFile($dbh, \@taxon_oids);

    print "Getting pfam count per cluster (isolate taxons) ...<br/>\n";
    ## count experimental
    $sql = qq{
        select g.cluster_id, count(distinct gpf.pfam_family)
        from bio_cluster_new g, bio_cluster_features_new bcf,
             gene_pfam_families gpf
        where g.cluster_id = bcf.cluster_id
        and bcf.gene_oid = gpf.gene_oid
        and g.taxon = gpf.taxon
        $cluster_ids_clause
        $taxon_clause
        $rclause
        $imgClause
        group by g.cluster_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ;; ) {
    my ( $bc_id, $cnt ) = $cur->fetchrow();
        last if !$bc_id;
        $bcid2pfamCnt{$bc_id} = $cnt;
    }
    $cur->finish();

    print "Getting biosynthetic cluster attributes...<br/>\n";

    $sql = qq{
        select bcd.cluster_id, bcd.genbank_acc, bcd.probability,
               bcd.evidence, bcd.bc_type, g.start_coord, g.end_coord
        from bio_cluster_data_new bcd, bio_cluster_new g
        where bcd.cluster_id = g.cluster_id
        $cluster_ids_clause
        $taxon_clause
        $rclause
        $imgClause
    };

    my %bcid2genbankAcc;
    my %bcid2bcType;
    my %bcid2evidence;
    my %bcid2prob;
    my %bcid2startCoord;
    my %bcid2endCoord;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ;; ) {
        my ( $bc_id, $acc2, $prob2, $evid2, $bc_type2, 
	     $start2, $end2 ) = $cur->fetchrow();
        last if !$bc_id;

	$bcid2genbankAcc{$bc_id} = $acc2;
	$bcid2bcType{$bc_id} = $bc_type2;
	$bcid2prob{$bc_id} = sprintf( "%.2f", $prob2 );
	$bcid2evidence{$bc_id} = $evid2;
	$bcid2startCoord{$bc_id} = $start2;
	$bcid2endCoord{$bc_id} = $end2;
    }
    $cur->finish();

    print "Getting secondary metabolites ...<br/>\n";
    $sql = qq{
        select distinct np.compound_oid, np.cluster_id, np.ncbi_acc, c.compound_name
        from np_biosynthesis_source np, img_compound c, bio_cluster_new g
        where np.cluster_id = g.cluster_id
        and np.compound_oid = c.compound_oid
        $cluster_ids_clause
        $taxon_clause
        $rclause
        $imgClause
    };

    my %bcid2np;
    my %genbankId2np;    
    my %npId2name;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ;; ) {
        my ( $np_id, $bc_id, $genbank_id, $np_name )
            = $cur->fetchrow();
        last if !$np_id;

        if ( $bc_id ) {
            my $nps_ref = $bcid2np{$bc_id};
            if ( $nps_ref ) {
                push(@$nps_ref, $np_id);
            }
            else {
                my @nps = ($np_id);
                $bcid2np{$bc_id} = \@nps;
            }
        }
        if ( $genbank_id ) {
            my $nps_ref = $genbankId2np{$genbank_id};
            if ( $nps_ref ) {
                push(@$nps_ref, $np_id);
            }
            else {
                my @nps = ($np_id);
                $genbankId2np{$genbank_id} = \@nps;
            }
        }
        $npId2name{$np_id} = $np_name;
    }
    $cur->finish();

    #print "Getting IMG Pathways ...<br/>\n";
    #my %bcid2pwids = getBcPathwayList
    #( $dbh, $cluster_ids_clause, $taxon_clause, 
    #  \@binds, $rclause, $imgClause );

    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
        if ( $cluster_ids_clause =~ /gtt_func_id/i ); 

    printEndWorkingDiv();

    print start_form(-id     => "processbc_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    print "<h1>$title</h1>" if $title;

    my $hideTaxonCol = 0;
    if ( scalar(@taxon_oids) == 1 ) {
        my $taxon_oid = @taxon_oids[0];
        my $taxon_name = $taxon2name_href->{$taxon_oid};
        if ( $taxon_in_file_href->{$taxon_oid} ) {
            $taxon_name = HtmlUtil::printMetaTaxonName
           ( $taxon_oid, $taxon_name, 'assembled', 1 );
        } else {
            HtmlUtil::printTaxonName( $taxon_oid, $taxon_name, 1 );        
        }     
        $hideTaxonCol = 1;
	
        print "<br/>$subTitle" if $subTitle;
	print "</p>";

    } else {
	print "<p>$subTitle</p>" if $subTitle;
    }

    my $hint =
        "Click on a \"Cluster ID\" to see cluster details.<br/>"
      . "Click on a \"Gene Count\" to see the gene neighborhood "
      . "for the cluster.";
    printHint($hint);
    print "<br/>";

    print "<script src='$base_url/checkSelection.js'></script>\n";

    my $it = new InnerTable( 1, "processbc$$", "processbc", 1 );
    my $sd = $it->getSdDelim();
    my $disp = "right";
    if ( scalar(keys %$taxon_in_file_href) > 0 ) {
        $disp = "left";
    }
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",    "asc",  $disp );
    $it->addColSpec( "Gene Count",    "desc", "right" );
    if ( !$hideTaxonCol ) {
        $it->addColSpec( "Genome Name",     "asc",  "left" );
    }
    $it->addColSpec( "Scaffold",        "asc",  $disp );
    $it->addColSpec( "Start Coord",     "asc",  "right" );
    $it->addColSpec( "End Coord",       "asc",  "right" );
    $it->addColSpec( "Scaffold Length", "asc",  "right" );
    $it->addColSpec( "Genbank ID",      "asc",  "left" );
    $it->addColSpec( "Evidence Type",   "asc",  "left" );
    $it->addColSpec( "Prediction Probability",   "desc", "right" );
    $it->addColSpec( "Biosynthetic Cluster Type", "asc",  "left" );
    $it->addColSpec( "Secondary Metabolite", "asc", "left" );
    $it->addColSpec( "Pfam Count",      "asc",  "right" );
    #$it->addColSpec( "IMG Pathway Count", "desc", "right" );

    my @cluster_ids_all;
    if ( $cluster_ids_ref ) {
        @cluster_ids_all = @$cluster_ids_ref;
    }
    elsif ( $clusterId2taxons_href ) {
        @cluster_ids_all = keys %$clusterId2taxons_href;
    }
    else {
        @cluster_ids_all = keys %bcid2taxon;
    }

    my $cnt = 0;
    foreach my $cluster_id ( @cluster_ids_all ) {
        $cnt++;

        my $r;
        my $tmp =
	    "<input type='checkbox' name='bc_id' value='$cluster_id' />\n";
        $r .= $sd . $tmp . "\t";

        my $url1 = 
            "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
        $r .= $cluster_id . $sd . alink( $url1, $cluster_id ) . "\t";

        my $taxon_oid = $bcid2taxon{$cluster_id};
        if ( !$taxon_oid && $clusterId2taxons_href ) {
            my $taxons_ref = $clusterId2taxons_href->{$cluster_id};
            $taxon_oid = @$taxons_ref[0];
        }

        my $gene_count = $bcid2geneCnt{$cluster_id};
        if ( $gene_count > 0 ) {
            my $url2 =
                "$section_cgi&page=cluster_viewer&taxon_oid=$taxon_oid"
              . "&type=bio&cluster_id=$cluster_id&genecount=$gene_count";
            $r .= $gene_count . $sd . alink( $url2, $gene_count ) . "\t";
        }
        else {
            $r .=  $sd . "\t";
        }

        my $taxon_name;
        if ( !$hideTaxonCol ) {
            $taxon_name = $taxon2name_href->{$taxon_oid};
        }
        
        my $scaffold_oid = $bcid2scaffold{$cluster_id};
        my $t_url;
        my $s_url;

        if ( $taxon_in_file_href->{$taxon_oid} ) {
            if ( !$hideTaxonCol ) {
                $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType
            ( $taxon_name, 'assembled' );
                $t_url = "$main_cgi?section=MetaDetail&taxon_oid=$taxon_oid";
            }
            $s_url = "$main_cgi?section=MetaDetail" .
            "&page=metaScaffoldDetail&taxon_oid=$taxon_oid" .
            "&scaffold_oid=$scaffold_oid";
        }
        else {
            if ( !$hideTaxonCol ) {
                $t_url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
            }
            $s_url = "$main_cgi?section=ScaffoldCart" .
              "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
        }
        if ( !$hideTaxonCol ) {
            $r .= $taxon_name . $sd . alink( $t_url, $taxon_name ) . "\t";
        }
        $r .= $scaffold_oid . $sd . alink( $s_url, $scaffold_oid ) . "\t";

        my $start_coord = $bcid2startCoord{$cluster_id};
        $r .= $start_coord . $sd . $start_coord . "\t";

        my $end_coord = $bcid2endCoord{$cluster_id};
        $r .= $end_coord . $sd . $end_coord . "\t";

	my $scf_length = $end_coord - $start_coord + 1;
        $r .= $scf_length . $sd . $scf_length . "\t";

        my $genbank_id = $bcid2genbankAcc{$cluster_id};
        if ( $genbank_id ) {
            $r .= $genbank_id . $sd . 
            alink("${ncbi_base_url}$genbank_id", $genbank_id) . "\t";
        }
        else {
            $r .= $genbank_id . $sd . $genbank_id . "\t";
        }

        my $evidence = $bcid2evidence{$cluster_id};
        $r .= $evidence . $sd . $evidence . "\t";

        my $probablity = $bcid2prob{$cluster_id};
        $r .= $probablity . $sd . $probablity . "\t";

        my $bcType = $bcid2bcType{$cluster_id};
        $r .= $bcType . $sd . $bcType . "\t";

        # Secondary Metabolite link
        my $nps_ref = $bcid2np{$cluster_id};
        if ( ! $nps_ref ) {
            $nps_ref = $genbankId2np{$genbank_id};
        }
        my ($np_ids, $np_links);
        my $i = 0;
        for my $np ( @$nps_ref ) {
            if ( $i > 0 ) {
                $np_links .= '<br/>';
            }
            $np_ids .= $np;
            my $nplink = "$main_cgi?section=ImgCompound"
                . "&page=imgCpdDetail&compound_oid=$np";
            $np_links .= alink( $nplink, $np );
            my $np_name = $npId2name{$np};
            $np_links .= "  $np_name";
            $i++;
        }
        $r .= $np_ids . $sd . $np_links . "\t";

        my $pfam_count = $bcid2pfamCnt{$cluster_id};
        if ( $pfam_count > 0 ) {
            my $url3 =
            "$section_cgi&page=bioClusterPfamList&taxon_oid=$taxon_oid"
            . "&type=bio&cluster_id=$cluster_id";
            $r .= $pfam_count . $sd . alink( $url3, $pfam_count ) . "\t";
        }
        else {
            $r .= $sd . "\t";
        }
 
        # img pathway count link
        #my $pw_count = $bcid2pwidCnt{$cluster_id};
#        my $pwids_href = $bcid2pwids{$cluster_id};
#        my $pw_count = scalar(keys %$pwids_href);
#        if ( $pw_count > 0 ) {
#            my $url4 =
#            "$section_cgi&page=bioClusterPathwayList&taxon_oid=$taxon_oid"
#            . "&cluster_id=$cluster_id";
#            $r .= $pw_count . $sd . alink( $url4, $pw_count ) . "\t";
#        }
#        else {
#            $r .= $sd . "\t";
#        }

        $it->addRow($r);
    }

    if ( $cnt > 10 ) {
        BcUtil::printTableFooter("processbc");
    }
    $it->printOuterTable(1);
    BcUtil::printTableFooter("processbc");

    print end_form();
    printStatusLine( "$cnt Biosynthetic Clusters retrieved.", 2 );
    
    return $cnt;
}

sub getBcPathwayList {
    my ( $dbh, $cluster_ids_clause, $taxon_clause, $binds_ref, 
	 $rclause, $imgClause ) = @_;

    #if ( ! $rclause ) {
    #    $rclause   = WebUtil::urClause('g.taxon');        
    #}
    #if ( ! $imgClause ) {
    #    $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    #}

    my $sql = qq{
        select distinct g.cluster_id, gif.function
        from bio_cluster_new g, bio_cluster_features_new bcf, 
             gene_img_functions gif
        where g.cluster_id = bcf.cluster_id
        and bcf.feature_type = 'gene'
        and bcf.gene_oid = gif.gene_oid
        $cluster_ids_clause
        $taxon_clause
    };
    #$rclause
    #$imgClause

    #print "getBcPathwayList() IMG Pathways sql=$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, @$binds_ref );
    my %bcid2term;
    my %terms_h;
    for ( ;; ) {
        my ($bcid, $term_oid) = $cur->fetchrow();
        last if ! $bcid;
        if ( $bcid2term{$bcid} ) {
            my $term_href = $bcid2term{$bcid};
            $term_href->{$term_oid} = 1;
        }
        else {
            my %h2;
            $h2{$term_oid} = 1;
            $bcid2term{$bcid} = \%h2;
        }
        $terms_h{$term_oid} = 1;
    }
    $cur->finish();

    my %term2allTerms;    
    my %allTerms_h;    
    foreach my $term_oid (keys %terms_h) {
        my @all_terms = ImgPwayBrowser::findAllParentTerms($dbh, $term_oid, 1);
        $term2allTerms{$term_oid} = \@all_terms;
        foreach my $newTerm (@all_terms) {
            $allTerms_h{$newTerm} = 1;
        }
    }
    my @allTerms = keys %allTerms_h;

    my %bcid2pwids;
    if ( scalar(@allTerms) > 0 ) {
        my $term_oids_str = OracleUtil::getNumberIdsInClause1( $dbh, @allTerms );
        $sql = qq{
            select irc.catalysts, ipr.pathway_oid
            from img_reaction_catalysts irc, img_pathway_reactions ipr
            where irc.catalysts in ( $term_oids_str )
            and irc.rxn_oid = ipr.rxn
            union
            select itc.term, ipr.pathway_oid
            from img_reaction_t_components itc, img_pathway_reactions ipr
            where itc.term in ( $term_oids_str )
            and itc.rxn_oid = ipr.rxn
        };
        #print "getBcPathwayList() all related IMG Pathways sql=$sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        my %term2pwids;
        for ( ;; ) {
            my ($newTerm, $pwid) = $cur->fetchrow();
            last if ! $newTerm;

            if ( $term2pwids{$newTerm} ) {
                my $pwid_href = $term2pwids{$newTerm};
                $pwid_href->{$pwid} = 1;
            }
            else {
                my %h2;
                $h2{$pwid} = 1;
                $term2pwids{$newTerm} = \%h2;
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num1_id" ) 
            if ( $term_oids_str =~ /gtt_num1_id/i ); 
        
        foreach my $bcid ( keys %bcid2term ) {
            my %bcid_pwids_h;
            my $term_href = $bcid2term{$bcid};
            foreach my $term_oid ( keys %$term_href ) {
                my $all_terms_ref = $term2allTerms{$term_oid};
                foreach my $newTerm (@$all_terms_ref) {
                    my $pwid_href = $term2pwids{$newTerm};
                    foreach my $pwid (keys %$pwid_href) {
                        $bcid_pwids_h{$pwid} = 1;
                    }
                }
            }
            $bcid2pwids{$bcid} = \%bcid_pwids_h;
        }
    }
    
    return %bcid2pwids;
}

###########################################################################
# printBiosyntheticGenes (moved from TaxobDetail.pm)
###########################################################################
sub printBiosyntheticGenes {
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }
    
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    if ( $isTaxonInFile ) {
        printBiosyntheticMetaGenes();
    }
    else {
        printBiosyntheticIsolateGenes();
    }
}

###########################################################################
# printBiosyntheticMetaGenes
###########################################################################
sub printBiosyntheticMetaGenes {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }        

    my @bc_ids_uncleaned = param("bc_id");
    if ( scalar(@bc_ids_uncleaned) <= 0 ) {
        @bc_ids_uncleaned = param("cluster_id");
        if ( scalar(@bc_ids_uncleaned) <= 0 ) {
            @bc_ids_uncleaned = param("func_id");
        }
    }
    my @bc_ids;
    foreach my $id (@bc_ids_uncleaned) {
        if ( $id =~ /^BC:/ ) {
            $id =~ s/^BC://;
        }
        push( @bc_ids, $id );
    }    

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>Biosynthetic Cluster Genes</h1>";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    $taxon_name = HtmlUtil::printMetaTaxonName
	( $taxon_oid, $taxon_name, $data_type );
    
    my $cluster_url_base = "main.cgi?section=BiosyntheticDetail"
	                 . "&page=cluster_detail&cluster_id="; 
    if ( scalar(@bc_ids) == 1 ) {
        print "<p>";
        foreach my $bc_id (@bc_ids) {
            my $url = "$cluster_url_base$bc_id"; 
            print alink($url, $bc_id) . "<br/>\n"; 
        }
        print "</p>\n";
    }

    my @meta_gene_oids;
    my %genes_h;
    my %gene2cluster_h;
    my %gene2name_h;
    if ( $data_type ne 'unassembled' ) {
        $data_type = 'assembled';

        my $idClause;
        if ( scalar(@bc_ids) > 0 ) {
            my $funcIdsInClause = 
		OracleUtil::getFuncIdsInClause( $dbh, @bc_ids );
            $idClause = " and g.cluster_id in ($funcIdsInClause) ";
        }
    
        # get bc genes
        my $sql = qq{
            select distinct bcf.feature_id, g.cluster_id
            from bio_cluster_features_new bcf, bio_cluster_new g
            where bcf.feature_type = 'gene'
            and bcf.cluster_id = g.cluster_id
            and g.taxon = ?
            $idClause
        };
        #print "printBiosyntheticMetaGenes() sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ;; ) {
            my ($feature_id, $cluster_id) = $cur->fetchrow();
            last if !$feature_id;
            
            my $workspace_id = "$taxon_oid $data_type $feature_id";
            if ( ! $genes_h{$workspace_id} ) {
                push(@meta_gene_oids, $feature_id);
                $genes_h{$workspace_id} = 1;
                $gene2cluster_h{$workspace_id} = $cluster_id;                
            }
        }
        $cur->finish();
    
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
	    if ( $idClause =~ /gtt_func_id/i );

        if ( scalar(@meta_gene_oids) > 0 ) {
            %gene2name_h = MetaUtil::getGeneProdNamesForTaxonGenes
		($taxon_oid, $data_type, \@meta_gene_oids);            
        }

    }

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    if ( scalar(@bc_ids) != 1 ) {
        $it->addColSpec( "Cluster ID",    "asc", "left" );        
    }

    my $select_id_name = "gene_oid";
    my $gene_count = 0;
    my $trunc      = 0;

    foreach my $workspace_id ( keys %genes_h ) {
        my ( $t2, $d2, $gene_oid ) = split( / /, $workspace_id );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />" . "\t";
        my $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
	        . "&gene_oid=$gene_oid" 
		. "&taxon_oid=$t2&data_type=$d2";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
        
        my $gene_name = $gene2name_h{$gene_oid};
        $r .= $gene_name . $sd . $gene_name . "\t";

        if ( scalar(@bc_ids) != 1 ) {
            my $cluster_id = $gene2cluster_h{$workspace_id};
            my $cluster_url = "$cluster_url_base$cluster_id";
            $r .= $cluster_id . $sd . alink($cluster_url, $cluster_id) . "\t";
        }

        $it->addRow($r);

        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }

    if ( $gene_count == 0 ) {
        print "<p><font color='red'>"
          . "Could not find genes for Biosynthetic Cluster @bc_ids "
          . "</font></p>";
        print end_form();
        return;
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->hideAll() if $gene_count < 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    my $s;
    if ($trunc) {
        $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) 
	    . " to change \"Max. Gene List Results\". )\n";
    } else {
        $s = "$gene_count gene(s) loaded";
    }

    printStatusLine( $s, 2 );
    print end_form();
}


###########################################################################
# printBiosyntheticIsolateGenes
###########################################################################
sub printBiosyntheticIsolateGenes {
    my $taxon_oid = param("taxon_oid");

    my ($sql, $extrasql) = QueryUtil::getSingleTaxonBiosyntheticGenesSqls($taxon_oid);
    my $url = "$main_cgi?section=BiosyntheticDetail" 
        . "&page=cluster_detail&cluster_id=";    
    TaxonDetailUtil::printGeneListSectionSorting2($taxon_oid, $sql, 
        "Biosynthetic Cluster Genes", 1, "Cluster ID", $extrasql, $url);
}

###########################################################################
# printSimilarBCGF
###########################################################################
sub printSimilarBCGF {
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }
    
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    # get selected genes
    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
	webError("Please select one or more genes from the list.");
    }
    elsif ( scalar(@gene_oids) > 1000 ) {
	webError("Too many genes!");
    }

    print start_form(-id     => "bcsimilar_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi");

    my $gene_list = "";
    foreach my $gene_oid ( @gene_oids ) {
	print hiddenVar('gene_oid', $gene_oid);
	my ($t2, $d2, $g2) = split(/ /, $gene_oid);
	if ( $g2 ) {
	    $gene_oid = $g2;
	}

	if ( $gene_list ) {
	    $gene_list .= ", '" . $gene_oid . "'";
	} else {
	    $gene_list = "'" . $gene_oid . "'";
	}
    }
    my $gene_oid_list = join(", ", @gene_oids);

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    print "<h1>Similar Biosynthetic Clusters</h1>\n";

    my $glist = join(",", @gene_oids);
    print hiddenVar('taxon_oid', $taxon_oid);
    print hiddenVar('cluster_id', $cluster_id);
    print hiddenVar('gene_list', $glist);

    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName($dbh, $taxon_oid);
    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Genome: " . alink( $url, $taxon_name ); 
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    print "</p>"; 

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    } 

    ## get selected pfams
    my @pfam_ids;
    my $sql = qq{
        select distinct gpf.pfam_family
        from gene_pfam_families gpf
        where gpf.gene_oid in ( $gene_oid_list )
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($pfam_id) = $cur->fetchrow();
        last if(!$pfam_id);
	push @pfam_ids, ( $pfam_id );
    }
    $cur->finish();
    if ( scalar(@pfam_ids) == 0 ) {
	webError("The selected genes have no Pfams.");
    }
    elsif ( scalar(@pfam_ids) > 1000 ) {
	webError("There are too many Pfams!");
    }

    my $pfam_list0 = join(", ", sort @pfam_ids);
    my $pfam_list = WebUtil::joinSqlQuoted(",", @pfam_ids);
    my $pfam_cnt = scalar(@pfam_ids);

    my $hint;
    $hint = "The result is based on <u>Pfams of selected genes</u>. "
	  . "All of these pfams have to be present in a cluster for it "
	  . "to be considered similar to the one being queried: ";
    $hint .= "<br/>" if $pfam_cnt > 2;
    $hint .= $pfam_list0;
    printHint($hint);

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    ## get clusters
    print "<p>Checking isolate biosynthetic clusters ...\n";
    my @clusters;
    $sql = qq{
        select bcf.cluster_id, count(distinct gpf.pfam_family)
        from bio_cluster_features_new bcf,
             gene_pfam_families gpf
	where bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and gpf.pfam_family in ( $pfam_list )
        group by bcf.cluster_id
        having count(distinct gpf.pfam_family) >= $pfam_cnt
    };
    $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($bc_id, $p_cnt) = $cur->fetchrow();
        last if(!$bc_id);
	push @clusters, ( $bc_id );
    }
    $cur->finish();

    #ANNA: FIXME:
    print "<p>Checking metagenome biosynthetic clusters ...\n";
    $sql = qq{
        select bcf.cluster_id, count(distinct gpf.pfam_family)
        from bio_cluster_features_new bcf,
             gene_pfam_families gpf
        where bcf.feature_type = 'gene'
        and bcf.feature_id = gpf.gene_oid
        and gpf.pfam_family in ( $pfam_list )
        group by bcf.cluster_id
        having count(distinct gpf.pfam_family) >= $pfam_cnt
    };
    $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($bc_id, $p_cnt) = $cur->fetchrow();
        last if(!$bc_id);
        push @clusters, ( $bc_id );
    }
    $cur->finish();

    my %np_list_h;
    my $sql3 = qq{
        select np.cluster_id, c.compound_name 
	from np_biosynthesis_source np, img_compound c 
	where np.compound_oid = c.compound_oid 
	order by 1, 2
    };
    my $cur3 = execSql($dbh, $sql3, $verbose);
    for ( ;; ) {
	my ($cl_id, $c_name) = $cur3->fetchrow();
	last if ! $cl_id;

	if ( $np_list_h{$cl_id} ) {
	    $np_list_h{$cl_id} .= ", " . $c_name;
	}
	else {
	    $np_list_h{$cl_id} = $c_name;
	}
    }
    $cur3->finish();

    print "<p>Getting info for clusters ...";

    my %bc2type;
    my %bc2evidence;
    my %bc2probability;
    my %bc2genbank;

    my $cluster_str = "";
    if (scalar(@clusters) > 0 ) {
        my $funcIdsInClause =
	    OracleUtil::getFuncIdsInClause( $dbh, @clusters );
        $cluster_str = " in ($funcIdsInClause) ";
    }

    my $clusterClause = " where bcd.cluster_id $cluster_str ";
    my $sql = qq{
        select bcd.cluster_id, bcd.attribute_type, bcd.attribute_value
        from bio_cluster_data_new bcd
        $clusterClause
    };

    $sql = qq{
        select bcd.cluster_id, bcd.genbank_acc, bcd.probability,
               bcd.evidence, bcd.bc_type
        from bio_cluster_data_new bcd
        where bcd.cluster_id = ? 
        $clusterClause
    };

    $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($id2, $acc2, $prob2, $evid2, $bc_type2 ) =
	    $cur->fetchrow();
        last if ! $id2;

	$bc2genbank{ $id2 } = $acc2;
	$prob2 = sprintf( "%.2f", $prob2 );
	$bc2probability{ $id2 } = $prob2;
	$bc2evidence{ $id2 } = $evid2;
	$bc2type{ $id2 } = $bc_type2;
    }
    $cur->finish();

    my %bc2len;
    my $clusterClause = " and mlen.cluster_id $cluster_str ";
    my $sql = qq{
        select mlen.cluster_id, mlen.seqlen
        from mv_bio_cluster_seqlen mlen
        where mlen.seqlen is not null
        $clusterClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
	my ($cluster_id, $len) = $cur->fetchrow();
	last if !$cluster_id;
	$bc2len{$cluster_id} = $len;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $clusterClause =~ /gtt_func_id/i );

    print "<p>Preparing output ...\n";

    my $it = new InnerTable( 1, "bcsimilar$$", "bcsimilar", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "desc", "left" );
    $it->addColSpec( "BC Type",     "desc", "left" );
    $it->addColSpec( "Evidence",    "desc", "left" );
    $it->addColSpec( "Probability", "asc",  "right" );
    $it->addColSpec( "Length",      "asc",  "right" );
    $it->addColSpec( "Genbank Acc", "desc", "left" );
    $it->addColSpec( "Pfam Count",  "asc",  "right" );
    $it->addColSpec( "Gene Count",  "asc",  "right" );
    $it->addColSpec( "Secondary Metabolite", "asc", "left" );

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');

    my $bc_taxon_sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
	from taxon t, bio_cluster_new bc
	where bc.cluster_id = ? 
	and bc.taxon = t.taxon_oid 
	$rclause 
        $imgClause
    };
    my $gf_taxon_sql = qq{
        select t.taxon_oid, t.taxon_display_name 
	from taxon t where t.taxon_oid = ? 
    };

    my $count = 0;
    foreach my $bc_id ( @clusters ) {
        if ( $bc_id eq $cluster_id ) {
           # the same one
           next;
        }

	my $cur2 = execSql($dbh, $bc_taxon_sql, $verbose, $bc_id);
	my ($t_id, $t_name, $in_file) = $cur2->fetchrow();
	$cur2->finish();

	if ( ! $t_id ) {
	    next;
	}

	my $cluster_url = "$section_cgi&page=cluster_detail" 
	                . "&cluster_id=$bc_id"; 

        my $r .= $sd . 
	    "<input type='checkbox' name='bc_id' value='$bc_id' />" . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail"
	              . "&page=taxonDetail&taxon_oid=$t_id";
        $r .= $bc_id . $sd . alink( $cluster_url, $bc_id ) . "\t";
        $r .= $t_name . $sd . alink( $taxon_url, $t_name ) . "\t";

	# bc type:
	my $bc_type = $bc2type{ $bc_id };
	my $bc_t = WebUtil::massageToUrl2($bc_type);
        my $type_url = "$main_cgi?section=BiosyntheticStats"
	    . "&page=clustersByBCType&bc_type=$bc_t";
        my $link = $bc_type;
        if (!blankStr($bc_type)) {
            $link = alink($type_url, $bc_type);
        }
        $r .= $bc_type . $sd . $link . "\t";

	# evidence:
	my $evidence = $bc2evidence{ $bc_id };
        $r .= $evidence . "\t";

	# probability:
	my $probability = $bc2probability{ $bc_id };
        $r .= $probability . "\t";

	# length:
	my $len = $bc2len{ $bc_id };
	$r .= $len . "\t";

	# genbank id:
	my $genbank = $bc2genbank{ $bc_id };
	my $link = $genbank;
	if (!blankStr($genbank)) {
	    $link = alink("${ncbi_base_url}$genbank", $genbank);
	}
	$r .= $genbank . $sd . $link . "\t"; #genbank acc

	# pfam count:
	my $pfam_count = getBioClusterPfamCount($bc_id, $t_id, $in_file);
	my $link = $pfam_count;
	if ( $pfam_count ) {
	    my $pfamurl = "$main_cgi?section=BiosyntheticDetail"
		. "&page=bioClusterPfamList&taxon_oid=$t_id"
		. "&cluster_id=$bc_id";
	    $link = alink($pfamurl, $pfam_count);
	}
	$r .= $pfam_count . $sd . $link . "\t";

	# gene count:
	my $gene_count = getGeneCountForCluster($dbh, $t_id, $in_file, $bc_id);
	my $link = $gene_count;
	if ($gene_count) {
	    my $bcgenes_url = "$section_cgi&page=bcGeneList"
		. "&taxon_oid=$t_id&cluster_id=$bc_id";
	    $link = alink($bcgenes_url, $gene_count);
	} 
	$r .= $gene_count . $sd . $link . "\t";

        my $np_name = $np_list_h{$bc_id};
	if ( ! $np_name ) {
	    $np_name = "-";
	}
        $r .= $np_name . $sd . $np_name . "\t";

        $it->addRow($r);
	$count++;
    }

    printEndWorkingDiv();
    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    if ( $count == 0 ) {
        print "<p><font color='red'>"
	    . "No similar biosynthetic clusters found for the selected genes." 
	    . "</font></p>";
        print end_form();
        return;
    }

    print "<p>";
    print "<input type='checkbox' name='bc_id' value='$cluster_id' />";
    print nbsp(1);
    my $link = alink( $url2, $cluster_id );
    print "Add query cluster $link to those selected below";
    print "</p>";

    print "<script src='$base_url/checkSelection.js'></script>\n";
    printPfamFooter("bcsimilar") if $count > 10;
    $it->hideAll() if $count < 10;
    $it->printOuterTable(1);

    my $s = $count . " item(s) loaded.";
    printStatusLine( $s, 2 );
    printPfamFooter("bcsimilar");
    print end_form();
}

sub printPfamFooter {
    my ($myform) = @_;

    if (0) { # not needed right now -anna
    my $name = "_section_${section}_pfamNeighborhood";
    my $buttonLabel = "Show Neighborhood";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 
    print nbsp(1); 
    my $name = "_section_${section}_pfamDomain";
    my $buttonLabel = "Show Protein Domain";
    my $buttonClass = "meddefbutton";
    print submit( 
	-name  => $name,
	-value => $buttonLabel, 
	-class => $buttonClass
    ); 
    print nbsp(1); 
    }
    my $name = "_section_${section}_addBCGenes";
    my $buttonClass = "meddefbutton";
    print submit(
	-name  => $name,
	-value => "Add Genes of Selected Clusters to Cart",
	-class => $buttonClass,
	-onclick => "return validateBCSelection(1, \"$myform\");"
    );
    print nbsp(1);
    my $name = "_section_${section}_addBCScaffolds";
    my $buttonClass = "meddefbutton";
    print submit(
        -name  => $name,
        -value => "Add Scaffolds of Selected Clusters to Cart",
        -class => $buttonClass,
	-onclick => "return validateBCSelection(1, \"$myform\");"
    );
    print nbsp(1);

    #print "<br>\n";
    print "<input type='button' name='selectAll' value='Select All' " 
	. "onClick='selectAllCheckBoxes(1)' class='smbutton' />"; 
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' " 
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />"; 
}

sub addBCGenesToCart {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my @sim_bc = param("bc_id");
    if (scalar(@sim_bc) == 0) {
        WebUtil::webError("No clusters have been selected.");
    }

    my $sim_bc_str = WebUtil::joinSqlQuoted(",", @sim_bc);

    my $dbh = dbLogin();
    my $sql = qq{
        select distinct bcf.feature_id
        from bio_cluster_features_new bcf
        where bcf.cluster_id in ($sim_bc_str)
        and bcf.feature_type = 'gene'
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @genes;
    for ( ;; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        push @genes, $gene_oid;
    }
    $cur->finish();

    require GeneCartStor;
    my $gc = new GeneCartStor();
    $gc->addGeneBatch(\@genes);
    $gc->printGeneCartForm("", 1);
}

sub addBCScaffoldsToCart {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my @bc = param("bc_id");
    if (scalar(@bc) == 0) {
	WebUtil::webError("No clusters have been selected.");
    }

    my $bc_str = WebUtil::joinSqlQuoted(",", @bc);

    my $dbh = dbLogin();
    my $sql = qq{
        select distinct bc.scaffold
        from bio_cluster_new bc
        where bc.cluster_id in ($bc_str)
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @scaffolds;
    for ( ;; ) {
	my ($scaffold_oid) = $cur->fetchrow();
	last if !$scaffold_oid;
	push @scaffolds, $scaffold_oid;
    }
    $cur->finish();

    use ScaffoldCart;
    ScaffoldCart::addToScaffoldCart(\@scaffolds);
    ScaffoldCart::printIndex();
}

sub viewNeighborhoodsForSelectedClusters {
    my @bc = param("bc_id");
    if (scalar(@bc) == 0) {
	WebUtil::webError("No clusters have been selected.");
    }

    printMainForm();

    print "<h1>Neighborhoods for Selected Biosynthetic Clusters</h1>";
    my $hint = "Mouse over a gene to see details (once page has loaded).<br>";
    $hint .= "Click on the red dashed box <font color='red'><b>- - -</b>"
	   . "</font> for functions associated with a cluster.<br>";
    $hint .= "Genes are <font color='darkGreen'>colored</font> "
           . "by <u>COG</u> association.<br>"
           . "Light yellow colored genes have <b>no</b> COG association.";
    $hint .= "<br/>Cluster neighborhood is flanked on each side by at least "
	   . "10,000 additional base pairs.<br/>";
    printHint($hint);

    my $dbh = dbLogin();
    my $bc_str = WebUtil::joinSqlQuoted(",", @bc);
    my $bc_cnt = scalar @bc;

    print "<div style='width: 950px;'>";
    my $sql = qq{
        select bc.cluster_id, tx.taxon_oid, tx.in_file
        from taxon tx, bio_cluster_new bc
        where bc.cluster_id in ($bc_str)
        and bc.taxon = tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
	my ($cluster_id, $taxon_oid, $in_file) = $cur->fetchrow();
	last if !$cluster_id;
	my ($clustergenes, $cluster_h, $scaffold_info) =
	    getAllInfoForCluster($dbh, $cluster_id, $taxon_oid, $in_file);

	printNeighborhoodPanels
	    ($dbh, $clustergenes, "", $cluster_h, $scaffold_info,
	     "", $cluster_id, "", "", "", "cog", "nolink");
    }
    $cur->finish();
    print "</div>";

    print end_form();
    printStatusLine( $bc_cnt . " cluster neighborhoods.", 2 ); 
}

sub getAllInfoForCluster {
    my ($dbh, $cluster_id, $taxon_oid, $in_file) = @_;
    my %scaffold_info;
    my %cluster_h;
    my %cluster_genes;

    if ( $in_file eq "Yes" ) {
        my $sql = qq{
            select distinct bc.scaffold, bcf.feature_id
            from bio_cluster_features_new bcf, bio_cluster_new bc
            where bc.taxon = ?
            and bc.cluster_id = ?
            and bc.cluster_id = bcf.cluster_id
            and bcf.feature_type = 'gene'
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $cluster_id );

        my %scf2genes;
        for ( ;; ) {
            my ($scaffold_oid, $gene) = $cur->fetchrow();
            last if !$scaffold_oid;

            if ($scf2genes{ $scaffold_oid }) {
                $scf2genes{ $scaffold_oid } .= "\t".$gene;
            } else {
                $scf2genes{ $scaffold_oid } = $gene;
            }
        }
        $cur->finish();
        my @metascaffolds = keys %scf2genes;
        foreach my $scf (@metascaffolds) {
            my $scf_gene_str = $scf2genes{ $scf };
            my @scfgenes = split(/\t/, $scf_gene_str);
            my ($scf_length, $gc, $n_genes) =
                getScaffoldStats($taxon_oid, "assembled", $scf);

            my @genes_on_s = MetaUtil::getScaffoldGenes
                ($taxon_oid, "assembled", $scf);
            my $topology = "linear";

            foreach my $line (@genes_on_s) {
                my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name,
                     $start_coord, $end_coord, $strand, $seq_id, $source ) =
                         split( /\t/, $line );

                my $found = 0;
	        CLUSTER: foreach my $g (@scfgenes) {
		  if ($g eq $gene_oid) {
		      $found = 1 ;
		      last CLUSTER;
		  }
		}
                next if !$found; # not a cluster gene

                my $item = "$gene_oid\t$start_coord\t$end_coord\t+";
                $scaffold_info{ $scf }
                = $scf."\t".$taxon_oid."\t".$topology."\t".$scf_length;
                push @{$cluster_h{ $scf }}, $item;
                $cluster_genes{ $gene_oid } = 1;
            }
        }

    } else {
        my $id2 = $cluster_id;
        my $sql = qq{
            select g.gene_oid, g.start_coord, g.end_coord, g.scaffold
            from gene g
            left join bio_cluster_features_new bcg on g.gene_oid = bcg.feature_id
            where bcg.feature_type = 'gene'
            and bcg.cluster_id = ?
        };
        if ( ! $cluster_id ) {
            $id2 = $taxon_oid;
            $sql = qq{
               select g.gene_oid, g.start_coord, g.end_coord, g.scaffold
               from gene g
               where g.taxon = ?
            };
        }
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );

        for ( ;; ) {
            my ($gene_oid, $start_coord, $end_coord, $scaffold)
                = $cur->fetchrow();
            last if !$gene_oid;

            my ( $scaffold_oid, $scaffold_name, $topology, $scf_length,
                 $start_coord, $end_coord, $strand )
                = getScaffoldInfo( $dbh, $gene_oid );
            next if !$scaffold_oid;

            my $item = "$gene_oid\t$start_coord\t$end_coord\t+";
            $scaffold_info{ $scaffold_oid }
            = $scaffold_name."\t".$taxon_oid."\t".$topology."\t".$scf_length;
            push @{$cluster_h{ $scaffold }}, $item;
            $cluster_genes{ $gene_oid } = 1;
        }
        $cur->finish();
    }

    my @clustergenes = keys %cluster_genes;
    return (\@clustergenes, \%cluster_h, \%scaffold_info);
}

############################################################
# printPfamDomain: print pfam domains of simialr BCs
############################################################
sub printPfamDomain {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    if ( $cluster_id ) {
	print "<h1>Biosynthetic Cluster Protein Domain</h1>";
    } else {
	print "<h1>Protein Domain</h1>";
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select $nvl(t.taxon_name, t.taxon_display_name),
               t.genome_type, t.in_file
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name, $genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    print "<p style='width: 650px;'>";
    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url1, $taxon_name );
    print " (assembled)" if $in_file eq "Yes";

    if ( $cluster_id ) {
	my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";
	print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    }
    print "</p>";

    my $max_cnt = 100;
    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) > $max_cnt ) {
        print "<p><font color='red'>Too many genes -- only $max_cnt genes can be displayed.</font></p>\n";
    }

    my @batch_genes = ();
    my $cnt = 0;
    my $g_list = "";
    foreach my $g2 ( @gene_oids ) {
	if ( $cnt >= $max_cnt ) {
	    last;
	}
	push @batch_genes, ( $g2 );
	$cnt++;
    }

    my @sim_bc = param("bc_id");

    my $dbh = dbLogin();
    print "<table class='img'>\n";
    print "<tr class='highlight'>\n"; 
    my $url2 = "$section_cgi&page=cluster_detail&cluster_id=$cluster_id";

    print "<th class='img'>";
    print alink($url2, $cluster_id) . "<br/>\n";
    print alink($url1, $taxon_name);
    print "</th>\n"; 

    foreach my $bc2 ( @sim_bc ) {
	my $bc_sql = "select t.taxon_oid, t.taxon_display_name " .
	    "from taxon t, bio_cluster_new bc " .
	    "where bc.cluster_id = ? and bc.taxon = t.taxon_oid";
	my $cur = execSql( $dbh, $bc_sql, $verbose, $bc2 );
	my ($bc_taxon, $bc_taxon_name) = $cur->fetchrow();
	$cur->finish();

	print "<th class='img'>";
	my $bc_url = "$section_cgi&page=cluster_detail&cluster_id=$bc2";
	print alink($bc_url, $bc2) . "<br/>\n";

	my $url1 = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$bc_taxon";
	print alink( $url1, $bc_taxon_name );
	print "</th>\n"; 
    }
    print "</tr>\n";

    my %pfam_name_h;
    my $pfam_sql = "select ext_accession, name from pfam_family ";
    my $cur = execSql( $dbh, $pfam_sql, $verbose );
    for ( ;; ) {
	my ($pfam_id, $pfam_name) = $cur->fetchrow();
	last if ! $pfam_id;
	$pfam_name_h{$pfam_id} = $pfam_name;
    }
    $cur->finish();

    my $locus_tag_sql = "select locus_tag from gene where gene_oid = ?";

    foreach my $g2 ( @batch_genes ) {
	my $locus_tag = $g2;
	my @pfams = findGenePfams($dbh, $g2);

	print "<tr class='img'>\n";
	print "<td class='img'>\n";
	print "<table class='img'>\n";
	print "<th class='img' bgcolor='lightblue'>";
	if ( isInt($g2) ) {
	    my $locus_cur = execSql( $dbh, $locus_tag_sql, $verbose,
		$g2);
	    ($locus_tag) = $locus_cur->fetchrow();
	    $locus_cur->finish();
	    my $g_url = "$main_cgi?section=GeneDetail&page=geneDetail"
	        . "&gene_oid=$g2"; 
	    print alink($g_url, $g2);
	    if ( ! $locus_tag ) {
		$locus_tag = "no locus tag";
	    }
	    print "<br/>($locus_tag)\n";
	}
	else {
	    my ($t3, $d3, $g3) = split(/ /, $g2);
	    my $g_url = "$main_cgi?section=MetaGeneDetail" .
		"&page=metaGeneDetail&gene_oid=$g3" .
		"&taxon_oid=$t3&data_type=$d3";
	    print alink($g_url, $g3);
	}
	print "</th>\n";
	print "<tr class='img'><td class='img'>";
	foreach my $pfam3 ( @pfams ) {
	    print $pfam_name_h{$pfam3} . "<br/>\n";
	}
	print "</td></tr></table>\n";
	print "</td>\n";

	if ( scalar(@pfams) == 0 ) {
	    print "</tr>\n";
	    next;
	}

	foreach my $bc2 ( @sim_bc ) {
	    my %match_genes =
		findBCGenesWithPfams($dbh, $bc2, \@pfams);
	    print "<td class='img'>\n";
	    my @keys = (keys %match_genes);
	    print "<table><tr>\n";

	    # order to show best matches first
	    my %checked_h;
	    my @keys_ordered = ();
	    foreach my $k2 ( @keys ) {
		my @pfam2 = split(/\t/, $match_genes{$k2});
		if ( scalar(@pfam2) == scalar(@pfams) ) {
		    push @keys_ordered, ( $k2 );
		    $checked_h{$k2} = 1;
		}
	    }
	    foreach my $k2 ( @keys ) {
		if ( $checked_h{$k2} ) {
		    next;
		}
		push @keys_ordered, ( $k2 );
		$checked_h{$k2} = 1;
	    }

	    # show rest matches
	    foreach my $k2 ( @keys_ordered ) {
		print "<td>\n";
		print "<table class='img'>\n";
		print "<th class='img' bgcolor='lightblue'>";

		if ( isInt($k2) ) {
		    my $locus_cur = execSql( $dbh, $locus_tag_sql, $verbose,
					     $k2);
		    ($locus_tag) = $locus_cur->fetchrow();
		    $locus_cur->finish();
		    my $g_url = "$main_cgi?section=GeneDetail&page=geneDetail"
			. "&gene_oid=$k2"; 
		    print alink($g_url, $k2);
		    if ( ! $locus_tag ) {
			$locus_tag = "no locus tag";
		    }
		    print "<br/>($locus_tag)\n";
		}
		else {
		    my ($t3, $d3, $g3) = split(/ /, $k2);
		    my $g_url = "$main_cgi?section=MetaGeneDetail" .
			"&page=metaGeneDetail&gene_oid=$g3" .
			"&taxon_oid=$t3&data_type=$d3";
		    print alink($g_url, $g3);
		}
		print "</th>\n";

		print "<tr class='img'><td class='img'>";
		my @pfam2 = split(/\t/, $match_genes{$k2});
		foreach my $p2 ( @pfam2 ) {
		    print $pfam_name_h{$p2} . "<br/>\n";
		}
		print "</td></tr>\n";
		print "</table>\n";
		print "</td>\n";
	    }   # end for k2
	    print "</tr></table>\n";

	    print "</td>\n";
	}

	print "</tr>\n";
    }

    print "</table>\n";
    print end_form();
}


#############################################################
# findGenePfams: get all pfams (ordered) for gene g2
#############################################################
sub findGenePfams {
    my ($dbh, $g2) = @_;

    my @pfams = ();
    if ( isInt($g2) ) {
	my ($sql2, @bindList) = 
	    FunctionAlignmentUtil::getPfamSqlForGene($g2, undef,
						     "", ""); 
	my ($cnt, $recs_ref, $doHmm) = 
	    FunctionAlignmentUtil::execPfamSearch( $dbh, $sql2,
						   \@bindList);

	foreach my $r3 ( @$recs_ref ) {
	    my ($g3, $pfam3, @rest) = split(/\t/, $r3);
	    push @pfams, ( $pfam3 );
	}
    }
    else { 
	my @recs = (); 
	my ($t3, $d3, $g3) = split(/ /, $g2); 
	if ( isInt($t3) ) {
	    @pfams = MetaUtil::getGenePfamId($g3, $t3, $d3);
	}
    }

    return @pfams;
}

##############################################################
# findBCGenesWithPfams: find BC gene with pfam_aref
##############################################################
sub findBCGenesWithPfams {
    my ($dbh, $cluster_id, $pfam_aref) = @_;

    my $threshold = scalar(@$pfam_aref);

    my $sql = qq{
        select t.taxon_oid, t.in_file 
	from taxon t, bio_cluster_new bc 
	where bc.cluster_id = ? 
        and bc.taxon = t.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    my ($taxon_oid, $in_file) = $cur->fetchrow();
    $cur->finish();

    my %match_genes;
    my %good_match_genes;
    my $good_match = 0;
    my $sql = qq{
        select distinct feature_id 
        from bio_cluster_features_new 
	where cluster_id = ? 
        and feature_type = 'gene'
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    for ( ;; ) {
	my ($gene_oid) = $cur->fetchrow();
	last if ! $gene_oid;

	my $workspace_id = $gene_oid;
	if ( $in_file eq 'Yes' ) {
	    $workspace_id = "$taxon_oid assembled $gene_oid";
	}
	my @pfams = findGenePfams($dbh, $workspace_id);
	if ( scalar(@pfams) > 0 ) {
	    my $score = getScore(\@pfams, $pfam_aref);

	    if ( $score >= ($threshold / 2.0) &&
		scalar(@pfams) <= ($threshold * 2.0) ) {
		$good_match = 1;
		$good_match_genes{$workspace_id} = join("\t", @pfams);
	    }
	    if ( $score > 0 ) {
		$match_genes{$workspace_id} = join("\t", @pfams);
	    }
	}
    }
    $cur->finish();

    if ( $good_match ) {
	return %good_match_genes;
    }
    else {
	return %match_genes;
    }
}

#########################################################
# getScore: return how many elements in aref1 
#           that are also in aref2
#########################################################
sub getScore {
    my ($aref1, $aref2) = @_;
    my %h2;
    foreach my $s2 ( @$aref2 ) {
	$h2{$s2} = 1;
    }

    my $score = 0;
    foreach my $s1 ( @$aref1 ) {
	if ( $h2{$s1} ) {
	    $score++;
	}
    }

    return $score;
}

sub highlightMatchName { 
    my ( $str, $matchStr ) = @_; 
    my $str_u      = $str; 
    my $matchStr_u = $matchStr; 
    $str_u      =~ tr/a-z/A-Z/;
    $matchStr_u =~ tr/a-z/A-Z/;
 
    my $idx = index( $str_u, $matchStr_u );
    my $targetMatchStr = substr( $str, $idx, length($matchStr) );

    return "" if $idx < 0; 
    my $part1 = escHtml( substr( $str, 0, $idx ) ); 
    if ( $idx <= 0 ) {
	$part1 = "";
    }
    my $part2 = escHtml($targetMatchStr); 
    my $part3 = escHtml( substr( $str, $idx + length($matchStr) ) ); 
    return $part1 . "<font color='red'><b>" . $part2 . "</b></font>" . $part3; 
} 


1;

