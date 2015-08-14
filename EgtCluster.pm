############################################################################
# EgtCluster.pm - Does sample clustering given EGT (ecogenomic tags).
#     --es 12/22/2006
# $Id: EgtCluster.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package EgtCluster;
my $section = "EgtCluster";

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use DistanceTree;
use DrawTree;
use InnerTable;
use MetaUtil;
use OracleUtil;
use WebConfig;
use WebUtil;
use King;
use GenomeListJSON;

my $env = getEnv();
my $base_url = $env->{ base_url };
my $base_dir = $env->{ base_dir };
my $cgi_dir  = $env->{ cgi_dir };
my $cgi_url  = $env->{ cgi_url };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose  = $env->{ verbose };
my $tmp_dir  = $env->{ tmp_dir };
my $tmp_url  = $env->{ tmp_url };
my $cluster_bin = $env->{ cluster_bin };
my $r_bin = "R"; # $env->{ r_bin };
my $min_genome_selections = 2;
my $include_metagenomes = $env->{include_metagenomes};

my $in_file = $env->{in_file};
my $mer_data_dir = $env->{mer_data_dir};
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";
my $user_restricted_site = $env->{user_restricted_site};
my $YUI = $env->{yui_dir_28};

my $max_genome_selections = 2300;

## Correlation colors. Each position is 0.10 between 0.00 - 1.00.
my @corrColors = (
   "#eeeeee",
   "#dddddd",
   "#cccccc",
   "#bbbbbb",
   "#bbbbff",
   "#ffcccc",
   "#ffbbbb",
   "#ffff50",
   "yellow",
   "yellow",
);


############################################################################
# dispatch - Dispatch loop
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param( "page" );
    timeout( 60 * 30 );    # timeout in 30 minutes (from main.pl)

    if ( $page eq "clusterResults" ||
	 paramMatch( "clusterResults" ) ne "" ) {
       printClusterResults();
    } else {
       printClusterForm($numTaxon);
    }
}

############################################################################
# printClusterForm - Show form for setting paramters for clustering.
############################################################################
sub printClusterForm {
    my ($numTaxon) = @_;

    my $description =
	"You may cluster samples (genomes) " .
	"based on similar functional profiles.<br/>" .
	"Proximity of grouping indicates the relative degree " .
	"of similarity of samples to each other.";

    WebUtil::printHeaderWithInfo
	("Genome Clustering", $description,
	 "show description for this tool",
	 "Genome Clustering Info", 0, "userGuide.pdf#page=52", "", "java");

    print "<p>$description</p>";

    printMainForm();

    if (0) { # currently not used
    print qq{
        Percent Identity: &nbsp; <select name="percentage" >
        <option value="30"
                title="Hits between 30% to 59%"> 30% to 59% </option>
        <option value="60"
                title="Hits between 60% to 89%"> 60% to 89% </option>
        <option value="90"  title="Any hits above 90%"> 90+ </option>
        <option selected="selected" value="30p"
                title="Any hits above 30%"> 30+ </option>
        <option value="60p" title="Any hits above 60%"> 60+ </option>
        </select>
        <br/>
        <br/>
    };
    }

    print "<p>\n";
    print "<font color='#003366'>"
	. "Please select $min_genome_selections to "
	. "$max_genome_selections genomes."
	. "</font>\n";
    print "</p>\n";

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
	( filename => "$base_dir/genomeJsonOneDiv.html" );
    $template->param( isolate      => 1 );
    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => 2300 );

    if ( $include_metagenomes ) {
	$template->param( include_metagenomes => 1 );
	$template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    print "<div style='width:300px; float:left;'>";
    print "<p>\n";
    print "<b>Clustering Type</b>:<br/>\n";
    print "<u>By Function</u>:<br/>\n";
    print "<input type='radio' name='func' value='cog' checked />";
    print "COG<br/>\n";
    print "<input type='radio' name='func' value='pfam' />";
    print "Pfam<br/>\n";
    print "<input type='radio' name='func' value='enzyme' />";
    print "KO<br/>\n";
    if (!$include_metagenomes) {
	print "<input type='radio' name='func' value='tigrfam' />";
	print "TIGRfam<br/>\n";
    }

    print "<u>By Taxonomy</u>:<br/>";
    print "<input type='radio' name='func' value='phylo_class' />";
    print "Class<br/>\n";
#    print "<input type='radio' name='func' value='phylo_order' />";
#    print "Order<br/>\n";
    print "<input type='radio' name='func' value='phylo_family' />";
    print "Family<br/>\n";
    print "<input type='radio' name='func' value='phylo_genus' />";
    print "Genus<br/>\n";

    if ($include_metagenomes) {
	print "<u>By Function Category</u>:<br/>";
	print "<input type='radio' name='func' value='cogcat' />";
	print "COG Categories<br/>\n";
	print "<input type='radio' name='func' value='cogpathw' />";
	print "COG Pathways<br/>\n";
	print "<input type='radio' name='func' value='keggcatko' />";
	print "KEGG Pathway Categories (KO)<br/>\n";
	print "<input type='radio' name='func' value='keggcatec' />";
	print "KEGG Pathway Categories (EC)<br/>\n";
	print "<input type='radio' name='func' value='keggpathwko' />";
	print "KEGG Pathways (KO)<br/>\n";
	print "<input type='radio' name='func' value='keggpathwec' />";
	print "KEGG Pathways (EC)<br/>\n";
	print "<input type='radio' name='func' value='pfamcat' />";
	print "Pfam Categories<br/>\n";
    }

    use FuncCartStor;
    my $fc = new FuncCartStor();
    my $recs = $fc->{recs};
    my @cart_keys = keys(%$recs);
    if (scalar @cart_keys > 0) {
        print "<br/>\n";
        print "<u>By Functions in Cart</u>:<br/>";
        print "<input type='radio' name='func' "
            . "value='cart_funcs' checked />\n";
        print "Use features from function cart ";
    }
    print "<br/>\n";
    print "</p>\n";
    print "</div>";

    print "<div style='width:300px; float:left;'>";
    print "<p>\n";
    print "<b>Clustering Method</b>:<br/>\n";
    print "<input type='radio' name='method' value='hier' checked />";
    print "Hierarchical Clustering<br/>\n";
    print "<input type='radio' name='method' value='pca' />";
    print "Principal Components Analysis (PCA)<br/>";

    if ($include_metagenomes) {
	print "<input type='radio' name='method' value='pcoa' />";
	print "Principal Coordinates Analysis (PCoA)<br/>";
	print "<input type='radio' name='method' value='nmds' />";
	print "Non-metric MultiDimensional Scaling (NMDS)<br/>";
    }

    print "<input type='radio' name='method' value='corrMap' />";
    print "Correlation Matrix<br/>";
    print "<br/>\n";
    print "<br/>\n";
    print "</p>\n";

    #my $oid_str = WebUtil::getTaxonFilterOidStr();
    #if ($oid_str ne "") {
    #	print "<p>\n";
    #	print "<input type='checkbox' name='only_cart_genomes' "
    #	    . "id='only_cart_genomes' checked />\n";
    #	print "Use only genomes from genome cart ";
    #	print "</p>\n";
    #}

    print hiddenVar( "section", $section );
    print hiddenVar( "page", "clusterResults" );

    my $name = "_section_${section}_clusterResults";
    GenomeListJSON::printHiddenInputType( $section, 'clusterResults' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
	( 'go', $name, 'Go', '', $section,
	  'clusterResults', 'smdefbutton', 'selectedGenome1', 2 );
    print $button;
    print nbsp( 1 );
    print reset( -class => "smbutton" );
    print "</div>";

    print end_form();
    GenomeListJSON::showGenomeCart($numTaxon);
}

############################################################################
# printClusterResults - Show cluster results.
############################################################################
sub printClusterResults {
    my $method = param( "method" );
    if( $method eq "pca" ) {
	printPcaResults();
    }
    elsif( $method eq "hier" ) {
	printHierResults();
    }
    elsif( $method eq "corrMap" ) {
	printCorrMapResults();
    }
    elsif( $method eq "pcoa" ) {
	printResults("pcoa");
    }
    elsif( $method eq "nmds" ) {
	printResults("nmds");
    }
}

############################################################################
# getInputFile - writes the input file for pca, pcoa, nmds
############################################################################
sub getInputFile {
    my ($dbh, $tmpInFile, $type_name) = @_;

    my %taxonProfiles;
    getProfileVectors( $dbh, \%taxonProfiles );
    if ($type_name eq "PCA") {
	normalizeProfileVectors( $dbh, \%taxonProfiles );
    }

    my $wfh = newWriteFileHandle( $tmpInFile, "inputFile-".$type_name );
    my @taxon_oids = sort( keys( %taxonProfiles ) );
    for my $taxon_oid( @taxon_oids ) {
        my $profile_ref = $taxonProfiles{ $taxon_oid };
        my @funcIds = sort( keys( %$profile_ref ) );

        print "<br/>$taxon_oid: " . scalar(@funcIds) . "\n";

        my $s;
        for my $i( @funcIds ) {
            my $cnt = $profile_ref->{ $i };
            $s .= "$cnt\t";
        }
        chop $s;
        print $wfh "$s\n";
    }
    close $wfh;
}

sub nameForFunction {
    my ($function) = @_;
    if ($function eq "cog") {
	return "COG";
    } elsif ($function eq "pfam") {
	return "Pfam";
    } elsif ($function eq "tigrfam") {
	return "TIGRfam";
    } elsif ($function eq "enzyme") {
	return "KO";
    } elsif( $function eq "phylo_class" ) {
	return "Taxonomy:Class";
    } elsif( $function eq "phylo_order" ) {
	return "Taxonomy:Order";
    } elsif( $function eq "phylo_family" ) {
	return "Taxonomy:Family";
    } elsif( $function eq "phylo_genus" ) {
	return "Taxonomy:Genus";
    } elsif( $function eq "cogcat") {
	return "COG Categories";
    } elsif( $function eq "cogpathw") {
	return "COG Pathways";
    } elsif( $function eq "keggcatko") {
	return "KEGG Pathway Categories (KO)";
    } elsif( $function eq "keggcatec" ) {
	return "KEGG Pathway Categories (EC)";
    } elsif( $function eq "keggpathwko" ) {
	return "KEGG Pathways (KO)";
    } elsif( $function eq "keggpathwec" ) {
	return "KEGG Pathways (EC)";
    } elsif( $function eq "pfamcat" ) {
	return "Pfam Categories";
    } elsif( $function eq "cart_funcs" ) {
	return "Functions in Cart";
    }
    return "";
}

############################################################################
# printResults - Runs PCA, PCoA, or NMDS and plots the results
############################################################################
sub printResults {
    my ($type) = @_;

    my $type_name;
    my $xlabel = "PC1";
    my $ylabel = "PC2";
    my $zlabel = "PC3";

    my $text;
    my $title;
    my $help;

    if ($type eq "pca") {
	$type_name = "PCA";
	$title = "Principal Component Analysis (PCA)";
	$text =
	    "Principal Components Analysis (PCA) allows points in high "
	  . "dimensional space to be projected into lower dimensions. "
	  . "This is done by a rotation of the axes such that the variance "
	  . "is maximized over the lower dimensions in the projection. "
	  . "Thus, the information content is maximized in the first "
	  . "two or three dimensions, where much of the information "
	  . "may be visualized in a plot.";
	$help = "Ordination.pdf#page=2";

    } elsif ($type eq "pcoa") {
	$type_name = "PCoA";
	$xlabel = "PCoA1"; $ylabel = "PCoA2"; $zlabel = "PCoA3";
	$title = "Principal Coordinates Analysis (PCoA)";
	$text =
	    "Principal Coordinates Analysis (PCoA) attempts to maximize "
	  . "the <u>linear correlation</u> of a matrix of dissimilarities. "
	  . "The dissimilarity metric used in this ordination is the "
	  . "Bray-Curtis index. The index is bound between 0 and 1. When "
	  . "two (meta)genomes have identical functional profiles, they "
	  . "have an index of 1. When they have no functions in common, "
	  . "they have an index of 0. The Bray-Curtis index is not altered "
	  . "by the inclusion of a third (meta)genome, nor by functions "
	  . "that are not found in either (meta)genome. PCoA attempts to "
	  . "preserve the information of this high-dimension dissimilarity "
	  . "matrix in a low dimensional space, such that it can be easily "
	  . "visualized. ";
	$help = "Ordination.pdf#page=4";

    } elsif ($type eq "nmds") {
	$type_name = "NMDS";
	$xlabel = "NMDS1"; $ylabel = "NMDS2"; $zlabel = "NMDS3";
	$title = "Non-metric MultiDimensional Scaling (NMDS)";
	$text =
	    "Nonmetric MultiDimensional Scaling (NMDS) attempts to "
	  . "maximize the <u>rank order correlation</u> of a matrix of "
	  . "dissimilarities. The dissimilarity metric used in this "
	  . "ordination is the Bray-Curtis index. The index is bound "
	  . "between 0 and 1. When two (meta)genomes "
	  . "have identical functional profiles, they have an index of 1. "
	  . "When they have no functions in common, they have an index of 0. "
	  . "The Bray-Curtis index is not altered by the inclusion of a third "
	  . "(meta)genome, nor by functions that are not found in either "
	  . "(meta)genome. NMDS attempts to preserve the information of this "
	  . "high-dimension dissimilarity matrix in a three-dimensional "
	  . "space, so that it can be easily visualized. ";
	$help = "Ordination.pdf#page=6";
    }

    WebUtil::printHeaderWithInfo
        ($title, $text, "show info about $type_name",
	 "$type_name Info", 0, $help);

    my @oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
	require GenomeCart;
	my $taxon_oids = GenomeCart::getAllGenomeOids();
	@oids = @$taxon_oids;
    } else {
	@oids = param("selectedGenome1");
    }
    my $nTaxons = @oids;
    if ( $nTaxons < $min_genome_selections ||
	 $nTaxons > $max_genome_selections ) {
        print "<p>$nTaxons genomes were selected.</p>";
        webError( "Please select $min_genome_selections " .
                  "to $max_genome_selections genomes.<br/>\n" );
    }

    my $function = param("func");
    my $func_name = nameForFunction($function);

    my $textStr = "$nTaxons genomes selected for analysis.";
    if ($usethem) {
        $textStr = "Using $nTaxons genomes in genome cart for analysis.";
    }

    if ( $type eq "pca" && $include_metagenomes && $nTaxons > 499 ) {
	$textStr .= " <font color='red'>This may take a while.</font>";
    } elsif ( $type eq "pcoa" && $nTaxons > 499 ) {
	$textStr .= " <font color='red'>This may take a while.</font>";
    } elsif ( $type eq "nmds" && $nTaxons > 99 ) {
	$textStr .= "<br/><font color='red'>Analysis may take a while, "
	          . "please consider using PCoA.</font>";
    }

    print "<p>\n";
    print "$textStr<br/>";
    print "Clustering is based on <u>$func_name</u> profiles "
        . "for selected genomes.<br/>";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    printStartWorkingDiv($type);
    print "<p>\n";

    # input file:
    my $sid = WebUtil::getSessionId();
    my $tmpInFile = "$tmp_dir/".$type."$$"."_".$sid.".in.tab.txt";
    getInputFile($dbh, $tmpInFile, $type_name);

    # output files:
    my $tmpOutFile = "$tmp_dir/".$type."$$"."_".$sid.".out.tab.txt";
    my $tmpSdevFile = "$tmp_dir/".$type."$$"."_".$sid.".sdev.tab.txt";

    # R command file
    my $metric = 'bray';
    my $tmpRcmdFile = "$tmp_dir/cmd$$"."_$type"."_".$sid.".r";
    my $wfh = newWriteFileHandle( $tmpRcmdFile, "printResults".$type_name );
    if ($type eq "pca") {
	print $wfh "t1 <- read.table('$tmpInFile', sep='\\t', header=F)\n";
	print $wfh "t2 <- as.matrix(t1)\n";
	print $wfh "r <- prcomp(t2)\n";
	print $wfh "write.table(r\$x, file='$tmpOutFile', sep='\\t', ";
	print $wfh "quote=F, row.names=F, col.names=F)\n";
	print $wfh "write.table(r\$sdev, file='$tmpSdevFile', sep='\\t', ";
	print $wfh "quote=F, row.names=F, col.names=F)\n";
    } elsif ($type eq "pcoa") {
	print $wfh "\# PCoA R Commands\n";
	print $wfh "\# You can download a tabbed delimited file from "
	         . "Compare Genomes->Abundance Profiles->Overview\n";
	print $wfh "\# The matrix should have genomes as rows and "
	         . "taxon/function as columns\n";
	print $wfh "library(vegan)\n";
	print $wfh "t1 <- read.table( '$tmpInFile', sep='\\t', header=F )\n";
	print $wfh "t2 <- as.matrix( t1 )\n";
	print $wfh "w_not_row_zeros=which(rowSums(t2)!=0)\n";
	print $wfh "w_not_col_zeros=which(colSums(t2)!=0)\n";
	print $wfh "t3=t2\n";
	print $wfh "if ((dim(t2)[1]-length(w_not_row_zeros)) > 0) {\n";
	print $wfh "  t3=t2[-which(rowSums(t2)==0),]\n";
	print $wfh "}\n";
	print $wfh "t4=t3\n";
	print $wfh "if ((dim(t2)[2]-length(w_not_col_zeros)) > 0) {\n";
	print $wfh "  t4=t3[,-which(colSums(t3)==0)]\n";
	print $wfh "}\n";
	print $wfh "dim_coords=3\n";
	print $wfh "cs=cmdscale(vegdist(t4,'$metric'),dim_coords)\n";
	print $wfh "big_cs=matrix(rep(0,dim(t2)[1]*dim_coords),";
	print $wfh "ncol=dim_coords)\n";
	print $wfh "big_cs[w_not_row_zeros,]=cs\n";
	print $wfh "\# Output the x, y, and z coordinates to a file\n";
	print $wfh "write.table(big_cs, file='$tmpOutFile', sep='\\t', ";
	print $wfh "quote=F, row.names=F, col.names=F)\n";
    } elsif ($type eq "nmds") {
	my $runs = "trymax=20";
	if ($nTaxons > 300) {
	    $runs = "trymax=5";
	}
	print $wfh "\# NMDS R Commands\n";
	print $wfh "\# You can download a tabbed delimited file from "
	         . "Compare Genomes->Abundance Profiles->Overview\n";
	print $wfh "\# The matrix should have genomes as rows and "
	         . "taxon/function as columns\n";
	print $wfh "library(vegan)\n";
	print $wfh "t1 <- read.table( '$tmpInFile', sep='\\t', header=F )\n";
	print $wfh "t2 <- as.matrix( t1 )\n";
	print $wfh "w_not_row_zeros=which(rowSums(t2)!=0)\n";
	print $wfh "w_not_col_zeros=which(colSums(t2)!=0)\n";
        print $wfh "t3=t2\n";
        print $wfh "if ((dim(t2)[1]-length(w_not_row_zeros)) > 0) {\n";
        print $wfh "  t3=t2[-which(rowSums(t2)==0),]\n";
        print $wfh "}\n";
	print $wfh "t4=t3\n";
        print $wfh "if ((dim(t2)[2]-length(w_not_col_zeros)) > 0) {\n";
        print $wfh "  t4=t3[,-which(colSums(t3)==0)]\n";
        print $wfh "}\n";
        print $wfh "dim_coords=3\n";
	print $wfh "ord=metaMDS(t4,distance='bray',";
	print $wfh "k=dim_coords,zerodist='add',$runs)\n";
	print $wfh "big_nmds=matrix(rep(0,dim(t2)[1]*dim_coords),";
	print $wfh "ncol=dim_coords)\n";
	print $wfh "big_nmds[w_not_row_zeros,]=";
	print $wfh "cbind(ord\$points[,1],ord\$points[,2],ord\$points[,3])\n";
	print $wfh "\# Output the x, y, and z coordinates to a file\n";
	print $wfh "write.table(big_nmds, file='$tmpOutFile', sep='\\t', ";
	print $wfh "quote=F, row.names=F, col.names=F)\n";
    }
    close $wfh;

    WebUtil::unsetEnvPath();
    print "<br/>Running $type_name ...<br/>\n";

    my $cmd = "$r_bin --slave < $tmpRcmdFile > /dev/null";
    webLog( "+ $cmd\n" );
    my $st = system( $cmd );
    WebUtil::resetEnvPath();
    print "</p>\n";
    printEndWorkingDiv($type);

    if ( ! (-e $tmpOutFile) ) {
        print "<p><font color='red'>No data to display. "
	    . "(no $tmpOutFile)</font></p>\n";
        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $taxonStr;
    my @taxon_oids = sort(@oids);
    if (OracleUtil::useTempTable($#taxon_oids + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@taxon_oids);
        $taxonStr = "select id from gtt_num_id";
    } else {
        $taxonStr = join(",", @taxon_oids);
    }

    my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name,
        tx.domain, tx.phylum, tx.ir_class, tx.genome_type
        from taxon tx
        where tx.taxon_oid in ($taxonStr)
        order by tx.domain, tx.phylum, tx.ir_class, tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %txNames;
    my %txLineage;
    my @orderedTxs;
    for( ;; ) {
        my( $taxon_oid, $taxon_name, $domain, $phylum, $class,
            $genome_type ) = $cur->fetchrow();
        last if !$taxon_oid;
        $txNames{ $taxon_oid } = $taxon_name;
        $txLineage{ $taxon_oid } = $domain.":".$phylum;
	if ($genome_type eq "metagenome") {
	    $txLineage{ $taxon_oid } = "Metagenome";
	}
        push @orderedTxs, $taxon_oid;
    }
    $cur->finish();
    #$dbh->disconnect();

    my $rfh = newReadFileHandle( $tmpOutFile, "printResults".$type_name );
    my $count = 0;
    my @recs;
    my @recs2;
    while( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;

        my $taxon_oid = $orderedTxs[ $count - 1 ];
        my $taxon_name = $txNames{ $taxon_oid };
        my $lineage = $txLineage{ $taxon_oid };
        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
            $url = "$main_cgi?section=MetaDetail"
		 . "&page=metaDetail&taxon_oid=$taxon_oid";
        }

        my $r = "$taxon_oid\t";
        $r .= "$taxon_name\t";
        $r .= "$url\t";

        my ($domain, $phylum) = split(":", $lineage);
        my $d = substr( $domain, 0, 1 );
        my $r2 = "$taxon_oid\t$taxon_name"."[$d]"."\t$lineage\t";

        my( @vals ) = split( /\t/, $s );
	my $idx = 0;
        for my $v( @vals ) {
            $v = sprintf( "%.3f", $v );
            $r .= "$v\t";
	    if ($idx < 3) {
		$r2 .= "$v\t";
	    }
	    $idx++;
        }
	$r2 .= "\t\t"; # for "connect" and "url1"
        push( @recs, $r );
        push( @recs2, $r2 );
    }
    close $rfh;

    print "<h2>3-D Plot of $xlabel, $ylabel, and $zlabel</h2>\n";
    print King::writeKingHeader
	("$tmp_url/cmd$$"."_$type"."_".$sid.".r", $type_name);
    print "<br/>";

    my $url_fragm1 = "section=TaxonDetail&page=taxonDetail&taxon_oid=";
    my $url_fragm2 = "section=GenomeCart&page=genomeCart&genomes=";

    King::writeKinInputFile(\@recs2, "$tmp_dir/".$type."$$"."_".$sid.".kin", 0,
			    $url_fragm1, $url_fragm2);
    King::writeKingApplet("$tmp_url/".$type."$$"."_".$sid.".kin");
    printStatusLine( "Loaded $nTaxons genomes.", 2 );
}

############################################################################
# printPcaResults - Run PCA and plot results.
############################################################################
sub printPcaResults {
    my @oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $taxon_oids = GenomeCart::getAllGenomeOids();
        @oids = @$taxon_oids;
    } else {
	@oids = param("selectedGenome1");
    }
    my $nTaxons = @oids;
    if( $nTaxons < $min_genome_selections ||
	$nTaxons > $max_genome_selections ) {
	print "<p>$nTaxons genomes were selected.</p>";
	webError( "Please select $min_genome_selections " .
		  "to $max_genome_selections genomes.<br/>\n" );
    }

    my $text =
	"Principal Components Analysis (PCA) allows points in high "
      . "dimensional space to be projected into lower dimensions. "
      . "This is done by a rotation of the axes such that the variance "
      . "is maximized over the lower dimensions in the projection. "
      . "Thus, the information content is maximized in the first "
      . "two or three dimensions, where much of the information "
      . "may be visualized in a plot.";

    WebUtil::printHeaderWithInfo
	("Principal Component Analysis (PCA)", $text,
	 "show info about PCA", "PCA Info", 0, "Ordination.pdf#page=2");

    my $function = param("func");
    my $func_name = nameForFunction($function);
    my $textStr = "$nTaxons genomes selected for analysis.";
    if ($usethem) {
        $textStr = "Using $nTaxons genomes in genome cart for analysis.";
    }
    if ( $include_metagenomes && $nTaxons > 499 ) {
        $textStr .= " <font color='red'>This may take a while.</font>";
    }
    print "<p>\n";
    print "$textStr<br/>";
    print "Clustering is based on <u>$func_name</u> profiles "
        . "for selected genomes.<br/>";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %taxon_in_file;
    if ( $in_file ) {
	my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
	my $cur2 = execSql( $dbh, $sql2, $verbose );
	for (;;) {
	    my ($t2) = $cur2->fetchrow();
	    last if !$t2;
	    $taxon_in_file{$t2} = 1;
	}
	$cur2->finish();
    }

    printStartWorkingDiv("pca");
    print "<p>\n";

    # input file:
    my $sid = WebUtil::getSessionId();
    my $tmpInFile = "$tmp_dir/pca$$"."_".$sid.".in.tab.txt";
    getInputFile($dbh, $tmpInFile, "PCA");

    ## Set up and run cluster
    my $tmpRcmdFile = "$tmp_dir/cmd$$"."_pca_".$sid.".r";
    my $tmpOutFile = "$tmp_dir/pca$$"."_".$sid.".out.tab.txt";
    my $tmpSdevFile = "$tmp_dir/pca$$"."_".$sid.".sdev.tab.txt";

    ## Write R command file (no row or column info; straight matrix)
    my $wfh = newWriteFileHandle( $tmpRcmdFile, "printPcaResults" );
    print $wfh "t1 <- read.table( '$tmpInFile', sep='\\t', header=F )\n";
    print $wfh "t2 <- as.matrix( t1 )\n";
    # --es 12/22/2006 Causes svd routine to bail
    #print $wfh "r <- prcomp( t2, scale=T )\n";
    print $wfh "r <- prcomp( t2 )\n";
    print $wfh "write.table( r\$x, file='$tmpOutFile', sep='\\t', ";
    print $wfh "quote=F, row.names=F, col.names=F )\n";
    print $wfh "write.table( r\$sdev, file='$tmpSdevFile', sep='\\t', ";
    print $wfh "quote=F, row.names=F, col.names=F )\n";
    close $wfh;

    WebUtil::unsetEnvPath();
    print "<br/>Running PCA ...<br/>\n";

    my $cmd = "$r_bin --slave < $tmpRcmdFile > /dev/null";
    webLog( "+ $cmd\n" );
    my $st = system( $cmd );
    WebUtil::resetEnvPath();
    print "</p>\n";
    printEndWorkingDiv("pca");

    if ( ! (-e $tmpOutFile) ) {
	print "<p><font color='red'>No data to display. "
	    . "(no $tmpOutFile)</font></p>\n";
	#$dbh->disconnect();
	printStatusLine( "Loaded.", 2 );
	return;
    }

    my $taxonStr;
    my @taxon_oids = sort(@oids);
    if (OracleUtil::useTempTable($#taxon_oids + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@taxon_oids);
	$taxonStr = "select id from gtt_num_id";
    } else {
	$taxonStr = join(",", @taxon_oids);
    }

    my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name,
        tx.domain, tx.phylum, tx.ir_class, tx.genome_type
        from taxon tx
        where tx.taxon_oid in ($taxonStr)
        order by tx.domain, tx.phylum, tx.ir_class, tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %txNames;
    my %txLineage;
    my @orderedTxs;
    for( ;; ) {
        my( $taxon_oid, $taxon_name, $domain, $phylum, $class,
	    $genome_type ) = $cur->fetchrow();
        last if !$taxon_oid;

	$txNames{ $taxon_oid } = $taxon_name;
	$txLineage{ $taxon_oid } = $domain.":".$phylum;
	if ($genome_type eq "metagenome") {
	    $txLineage{ $taxon_oid } = "Metagenome";
	}
	push @orderedTxs, $taxon_oid;
    }
    $cur->finish();

    my $rfh = newReadFileHandle( $tmpOutFile, "printPcaResults" );
    my $count = 0;
    my @recs;
    my @recs2;
    while( my $s = $rfh->getline() ) {
	chomp $s;
	$count++;

	my $taxon_oid = $orderedTxs[ $count - 1 ];
	my $taxon_name = $txNames{ $taxon_oid };
	my $lineage = $txLineage{ $taxon_oid };
	my $url = "$main_cgi?section=TaxonDetail" .
	    "&page=taxonDetail&taxon_oid=$taxon_oid";
	if ( $taxon_in_file{$taxon_oid} ) {
	    $taxon_name .= " (MER-FS)";
	    $url = "$main_cgi?section=MetaDetail"
		 . "&page=metaDetail&taxon_oid=$taxon_oid";
	}

	my $r = "$taxon_oid\t";
	$r .= "$taxon_name\t";
	$r .= "$url\t";

        my ($domain, $phylum) = split(":", $lineage);
	my $d = substr( $domain, 0, 1 );
	my $r2 = "$taxon_oid\t$taxon_name"."[$d]"."\t$lineage\t";

	my( @vals ) = split( /\t/, $s );
	my $idx = 0;
	for my $v( @vals ) {
	    $v = sprintf( "%.3f", $v );
	    $r .= "$v\t";
	    if ($idx < 3) {
		# add only the first 3 components
		$r2 .= "$v\t";
	    }
	    $idx++;
	}
	$r2 .= "\t\t"; # for "connect" and "url1"
	push( @recs, $r );
	push( @recs2, $r2 );
    }
    close $rfh;

    if ( ! (-e $tmpSdevFile) ) {
	print "<p><font color='red'>No data to display. "
	    . "(no sdev)</font></p>\n";
	#$dbh->disconnect();
	printStatusLine( "Loaded.", 2 );
	return;
    }
    my $rfh = newReadFileHandle( $tmpSdevFile, "printPcaResults" );
    my @vrecs;
    my $sum = 0;
    while( my $s = $rfh->getline() ) {
	chomp $s;
	my $var = $s * $s;
	push( @vrecs, $var );
	$sum += $var;
    }
    close $rfh;

    use TabHTML;
    TabHTML::printTabAPILinks("pcaTab");
    my @tabIndex = ( "#pcatab1", "#pcatab2", "#pcatab3", "#pcatab4" );
    my @tabNames = ( "3-D Plot", "2-D Plot", "Components", "Histogram" );
    TabHTML::printTabDiv("pcaTab", \@tabIndex, \@tabNames);
    print "<div id='pcatab1'>";

    if ( $sum > 0 ) {
	print "<h2>3-D Plot of PC1, PC2, and PC3</h2>\n";
	King::writeKingHeader("$tmp_url/cmd$$"."_pca_".$sid.".r", "PCA");
	print "<br/>";

	my $url_fragm1 = "section=TaxonDetail&page=taxonDetail&taxon_oid=";
	my $url_fragm2 = "section=GenomeCart&page=genomeCart&genomes=";

	King::writeKinInputFile(\@recs2, "$tmp_dir/pca$$"."_".$sid.".kin", 0,
				$url_fragm1, $url_fragm2);
	King::writeKingApplet("$tmp_url/pca$$"."_".$sid.".kin");
    }
    else {
	print "<p><font color='red'>No data to display.</font></p>\n";
    }

    print "</div>"; # end pcatab1

    print "<div id='pcatab2'>";
    if ( $sum > 0 ) {
        print "<h2>2-D Plot of PC1 and PC2</h2>\n";
        printHint
            ("- Mouse over a point to see genome information.<br/>\n" .
	     "- Click on a point to see genome details.<br/>\n");
        print "<br/>";

	my $plotname = "pca$$"."_".$sid;
        my $tmpPlotFile = "$tmp_dir/".$plotname.".png";
        my $tmpPlotUrl = "$tmp_url/".$plotname.".png";

        require PcaPlot;
        my $areas = PcaPlot::writeFile( \@recs, $tmpPlotFile );
        print "<img src='$tmpPlotUrl' usemap='#$plotname' border='1' ";
        print "alt='PCA Plot' />\n";
        print "<map name='$plotname'>\n";
        print $areas;
        print "</map>\n";

    } else {
        print "<p><font color='red'>No data to display.</font></p>\n";
    }
    print "</div>"; # end pcatab2

    print "<div id='pcatab3'>";
    print "<h2>Principal Components</h2>\n";
    print "<table class='img' border='1'>\n";
    my $count = 0;
    foreach my $rec( @recs ) {
	$count++;

	my( $taxon_oid, $taxon_name, $url, @vals ) = split( /\t/, $rec );
	if( $count == 1 ) {
	    print "<th class='img'>Taxon OID</th>\n";
	    print "<th class='img'>Genome</th>\n";
	    for( my $i = 0; $i < scalar(@vals); $i++ ) {
		last if $i > 9;
		printf "<th class='img'>PC%d</th>\n", $i + 1;
	    }
	}

	print "<tr class='img'>\n";
	print "<td class='img'>" . alink( $url, $taxon_oid ) . "</td>\n";
	print "<td class='img'>" . escHtml( $taxon_name ) . "</td>\n";

	my $idx = 0;
	foreach my $v( @vals ) {
	    last if $idx > 9;
	    print "<td class='img' align='right'>$v</td>\n";
	    $idx++;
	}
	print "</tr>\n";
    }
    print "</table>\n";
    print "</div>"; # end pcatab3

    print "<div id='pcatab4'>";
    print "<br/>\n";

    my $count = 0;
    print "<table class='img' border='1'>\n";
    print "<th class='img'>PC</th>\n";
    print "<th class='img'>Variance</th>\n";
    print "<th class='img'>Histogram</th>\n";
    foreach my $var( @vrecs ) {
	$count++;
	print "<tr class='img'>\n";
	print "<td class='img'>PC$count</td>\n";
	print "<td class='img' align='right'>$var</td>\n";
	my $perc = 0;
	$perc = $var / $sum if $sum > 0;
	print "<td class='img' align='left'>" .
	    histogramBar( $perc, 500 ) . "</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";
    print "</div>"; # end pcatab4
    TabHTML::printTabDivEnd();

    #$dbh->disconnect();
    printStatusLine( "Loaded $nTaxons genomes.", 2 );
}

############################################################################
# printHierResults - Print results of hierarchical clustering.
############################################################################
sub printHierResults {
    print "<h1>Hierarchical Clustering Results</h1>\n";

    my @oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $taxon_oids = GenomeCart::getAllGenomeOids();
        @oids = @$taxon_oids;
    } else {
	@oids = param("selectedGenome1");
    }
    my $nTaxons = @oids;
    if( $nTaxons < $min_genome_selections ||
	$nTaxons > $max_genome_selections ) {
	webError( "Please select $min_genome_selections " .
		  "to $max_genome_selections genomes.<br/>\n" );
    }

    my $count = $#oids + 1;
    printStatusLine( "Loading $count...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv("hier");
    print "<p>\n";
    my %taxonProfiles;
    getProfileVectors( $dbh, \%taxonProfiles );

    my $sid = WebUtil::getSessionId();
    ## Set up and run cluster
    my $tmpProfileFile = "$cgi_tmp_dir/profile$$"."_".$sid.".tab.txt";
    my $tmpClusterRoot = "$cgi_tmp_dir/cluster$$"."_".$sid;
    my $tmpClusterCdt = "$cgi_tmp_dir/cluster$$"."_".$sid.".cdt";
    my $tmpClusterGtr = "$cgi_tmp_dir/cluster$$"."_".$sid.".gtr";

    my $wfh = newWriteFileHandle( $tmpProfileFile, "printHierResults" );
    my $s = "id\t";
    my @taxon_oids = sort( keys( %taxonProfiles ) );
    my $profile_ref = $taxonProfiles{ $taxon_oids[ 0 ] };
    my @funcIds = sort( keys( %$profile_ref ) );
    for my $i( @funcIds ) {
	$s .= "$i\t";
    }
    chop $s;
    print $wfh "$s\n";

    for my $taxon_oid( @taxon_oids ) {
	my $profile_ref = $taxonProfiles{ $taxon_oid };
	my @funcIds = sort( keys( %$profile_ref ) );
	my $s;

	my $found = 0;
	for my $i( @funcIds ) {
	    my $cnt = $profile_ref->{ $i };
	    $s .= "$cnt\t";
	    $found = 1 if $cnt > 0;
	}
	next if !$found; # eliminate zero profiles
	chop $s;
	print $wfh "$taxon_oid\t";
	print $wfh "$s\n";
    }
    close $wfh;

    my $taxonStr;
    my @taxon_oids = sort(@oids);
    if (OracleUtil::useTempTable($#taxon_oids + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@taxon_oids);
        $taxonStr = "select id from gtt_num_id";
    } else {
        $taxonStr = join(",", @taxon_oids);
    }

    my %id2Rec;

    ## Taxon list
    my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name,
	       tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
	       tx.family, tx.genus
	from taxon tx
	where tx.taxon_oid in ($taxonStr)
	order by tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $taxon_oid, $name, $domain, $phylum, $class,
	    $order, $family, $genus ) = $cur->fetchrow();
	last if !$taxon_oid;
	$name =~ s/[^\w]/_/g;  # only alphanumeric chars allowed
	$domain =~ s/[^\w]/_/g;
	$phylum =~ s/[^\w]/_/g;
	$class  =~ s/[^\w]/_/g;
	$order  =~ s/[^\w]/_/g;
	$family =~ s/[^\w]/_/g;
	$genus  =~ s/[^\w]/_/g;

	my $highlight = 0;
	my $r = "$domain,$phylum,$class,$order,$family,$genus"
   	      . ":$name".":$taxon_oid\t";
	$r .= "$highlight\t";
	$r .= "\t";
	$r .= "$main_cgi?section=TaxonDetail" .
	       "&page=taxonDetail&taxon_oid=$taxon_oid\t";
	$id2Rec{ $taxon_oid } = $r;
    }
    $cur->finish();

    WebUtil::unsetEnvPath();
    runCmd( "$cluster_bin -g 1 -m s -f $tmpProfileFile -u $tmpClusterRoot" );
    WebUtil::resetEnvPath();
    print "</p>\n";

    printEndWorkingDiv("hier");

    # check if files are there
    if (! (-e $tmpClusterGtr) || ! (-e $tmpClusterCdt)) {
        print "<p><font color='red'>Could not create the necessary files. "
            . "(from $tmpProfileFile)</font></p>\n";
        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $dt = new DrawTree();
    $dt->loadGtrCdtFiles( $tmpClusterGtr, $tmpClusterCdt, \%id2Rec );

    my $func = param( "func" );
    my $func_name = nameForFunction($func);
    my $url = "http://www.phylosoft.org/archaeopteryx/";
#http://code.google.com/p/forester/
#https://sites.google.com/site/cmzmasek/home/software/archaeopteryx
    my $textStr = "$nTaxons genomes selected for analysis.";
    if ($usethem) {
	$textStr = "Using $nTaxons genomes in genome cart for analysis.";
    }

    print "<p>\n";
    print "$textStr<br/>";
    print "Clustering is based on <u>$func_name</u> profiles "
	. "for selected genomes.<br/>";
    print "The tree below is generated using the "
	. alink($url, "Archaeopteryx")." applet";
    print "</p>\n";

    my $xmlFile = $tmp_dir . "/treeXML$$"."_".$sid.".txt";
    $dt->toPhyloXML( $xmlFile );
    DistanceTree::printAptxApplet("treeXML$$"."_".$sid.".txt");

    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
    wunlink( $tmpProfileFile );
    wunlink( $tmpClusterCdt );
    wunlink( $tmpClusterGtr );
}

############################################################################
# printHierTransposed - Print transposed (functions clustered)
#   version of the data.  This is very SLOW for a large number of
#   rows (functions) that they to be hiearchically organized.
############################################################################
sub printHierTransposed {
    my( $dbh, $taxonProfiles_ref ) = @_;

    my $sid = WebUtil::getSessionId();
    ## Set up and run cluster
    my $tmpProfileFile = "$cgi_tmp_dir/profile$$"."_".$sid.".tab.txt";
    my $tmpClusterRoot = "$cgi_tmp_dir/cluster$$"."_".$sid;
    my $tmpClusterCdt = "$cgi_tmp_dir/cluster$$"."_".$sid.".cdt";
    my $tmpClusterGtr = "$cgi_tmp_dir/cluster$$"."_".$sid.".gtr";
    my $wfh = newWriteFileHandle( $tmpProfileFile, "printHierResults" );
    my $s = "id\t";
    my @taxon_oids = sort( keys( %$taxonProfiles_ref ) );
    for my $i( @taxon_oids ) {
	$s .= "$i\t";
    }
    chop $s;
    print $wfh "$s\n";
    my $profile_ref = $taxonProfiles_ref->{ $taxon_oids[ 0 ] };
    my @funcIds = sort( keys( %$profile_ref ) );
    for my $funcId( @funcIds ) {
	print $wfh "$funcId\t";
	my $s;
	for my $taxon_oid( @taxon_oids ) {
	    my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	    my $cnt = $profile_ref->{ $funcId };
	    $s .= "$cnt\t";
	}
	chop $s;
	print $wfh "$s\n";
    }
    close $wfh;
    WebUtil::unsetEnvPath();
    print "<p>\n";
    print "Clustering functions ...<br/>\n";
    print "</p>\n";
    runCmd( "$cluster_bin -g 1 -m s -f $tmpProfileFile -u $tmpClusterRoot" );
    WebUtil::resetEnvPath();
    print "</p>\n";

    my $dt = new DrawTree();
    $dt->loadGtrCdtFiles( $tmpClusterGtr, $tmpClusterCdt );
    my $tmpFile = "drawRect$$"."_".$sid.".png";
    my $outPath = "$tmp_dir/$tmpFile";
    my $outUrl = "$tmp_url/$tmpFile";
    my $root = $dt->{ root };
    my @leafs;
    $root->getLeafNodes( \@leafs );

    my @funcIds2;
    print "<p>\n";
    print "<pre>\n";
    for my $i( @leafs ) {
	my $geneIdx = $i->{ id };
	$geneIdx =~ s/GENE//;
	$geneIdx =~ s/X//;
	my $idx = int( $geneIdx );
	my $funcId = $funcIds[ $idx ];
	print "debug: funcId=$funcId\n";
	push( @funcIds2, $funcId );
    }
    for my $taxon_oid( @taxon_oids ) {
	my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	print "$taxon_oid ";
	for my $funcId( @funcIds2 ) {
	    my $cnt = $profile_ref->{ $funcId };
	    $cnt = 0 if $cnt eq "";
	    $cnt = sprintf( "%2d", $cnt );
	    print "$cnt ";
	}
	print "\n";
    }
    print "</pre>\n";
    print "</p>\n";

    wunlink( $tmpProfileFile );
    wunlink( $tmpClusterCdt );
    wunlink( $tmpClusterGtr );
}

############################################################################
# printCorrMapResults - Show correlation values.
############################################################################
sub printCorrMapResults {
    print "<h1>Correlation Matrix</h1>\n";

    my @oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
	require GenomeCart;
	my $taxon_oids = GenomeCart::getAllGenomeOids();
	@oids = @$taxon_oids;
    } else {
	@oids = param("selectedGenome1");
    }
    my $nTaxons = @oids;
    if( $nTaxons < $min_genome_selections ||
	$nTaxons > $max_genome_selections ) {
	webError( "Please select $min_genome_selections " .
		  "to $max_genome_selections genomes.<br/>\n" );
    }

    print "<p>\n";
    print "Correlation values (Pearson coefficient) are shown in cells.<br/>";
    print "Values generally range from 0.00 to 1.00 ";
    print "(1.00 is the highest correlation).<br/>\n";
    print "Negative values from 0.00 to -1.00 indicate anti-correlation.";
    print "</p>\n";

    printHint("Mouse over column abbreviation to see genome name.\n");

    my $function = param("func");
    my $func_name = nameForFunction($function);
    my $textStr = "$nTaxons genomes selected for analysis.";
    if ($usethem) {
	$textStr = "Using $nTaxons genomes in genome cart for analysis.";
    }

    print "<p>\n";
    print "$textStr<br/>";
    print "Clustering is based on <u>$func_name</u> profiles "
	. "for selected genomes.<br/>";
    print "</p>\n";

    print qq{
        <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
	</script>

	<script language='JavaScript' type='text/javascript'>
	function showCorrColors(type) {
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

    print "<p>";
    print "<div align='left' id='hidecolors' style='display: block;'>";
    print "<input type='button' class='smbutton' name='view'"
	. " value='Show Color Scheme'"
	. " onclick='showCorrColors(\"colors\")' />";
    print "</div>\n";

    print "<div align='left' id='showcolors' style='display: none;'>";
    print "<input type='button' class='smbutton' name='view'"
	. " value='Hide Color Scheme'"
	. " onclick='showCorrColors(\"nocolors\")' />";
    printCorrColorMap();
    print "</div>\n";
    print "</p>";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %taxonProfiles;
    printStartWorkingDiv("corrMap");
    print "<p>\n";
    getProfileVectors( $dbh, \%taxonProfiles );

    my @taxon_oids = sort( keys( %taxonProfiles ) );
    my $taxon_oid_str = join( ',', @taxon_oids );
    my %taxonOid2Name;
    my $sql = qq{
	select taxon_oid, taxon_display_name
	    from taxon
	    where taxon_oid in( $taxon_oid_str )
	    order by taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    @taxon_oids = ();
    for( ;; ) {
	my( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
	last if !$taxon_oid;
	$taxonOid2Name{ $taxon_oid } = $taxon_display_name;
	push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
	my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
	my $cur2 = execSql( $dbh, $sql2, $verbose );
	for (;;) {
	    my ($t2) = $cur2->fetchrow();
	    last if !$t2;
	    $taxon_in_file{$t2} = 1;
	}
	$cur2->finish();
    }

    my $nTaxons = @taxon_oids;
    my %corrMatrix;
    for( my $i = 0; $i < $nTaxons; $i++ ) {
	my $taxon_oid = $taxon_oids[ $i ];
	my $k = "$taxon_oid,$taxon_oid";
	$corrMatrix{ $k } = "1.00";
    }
    for( my $i = 0; $i < $nTaxons; $i++ ) {
	my $taxon_oid1 = $taxon_oids[ $i ];
	my $profile1 = $taxonProfiles{ $taxon_oid1 };
	my @x = profile2Array( $profile1 );
	for( my $j = $i + 1; $j < $nTaxons; $j++ ) {
	    my $taxon_oid2 = $taxon_oids[ $j ];
	    my $profile2 = $taxonProfiles{ $taxon_oid2 };
	    my @y = profile2Array( $profile2 );
	    my $r = pearsonCorr( \@x, \@y );
	    my $k1 = "$taxon_oid1,$taxon_oid2";
	    my $k2 = "$taxon_oid2,$taxon_oid1";
	    $corrMatrix{ $k1 } = $r;
	    $corrMatrix{ $k2 } = $r;
	}
    }
    print "</p>\n";
    printEndWorkingDiv("corrMap");

    print "<table class='img'>\n";
    print "<th class='img'>Genome</th>\n";

    for( my $i = 0; $i < $nTaxons; $i++ ) {
	my $taxon_oid = $taxon_oids[ $i ];
	my $taxon_name = $taxonOid2Name{ $taxon_oid };
	my $abbrName = WebUtil::abbrColName( $taxon_oid, $taxon_name, 1 );
	my $url2 =
	    "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
	if ( $taxon_in_file{$taxon_oid} ) {
	    $taxon_name .= " (MER-FS)";
	    $abbrName .= " (MER-FS)";
	    $url2 = "$main_cgi?section=MetaDetail"
		. "&page=metaDetail&taxon_oid=$taxon_oid";
	}

	my $link =  "<a href='$url2' title='$taxon_name'>$abbrName</a>";
	print "<th class='img'>$link</th>\n";
    }

    for( my $i = 0; $i < $nTaxons; $i++ ) {
	print "<tr class='img'>\n";
	my $taxon_oid1 = $taxon_oids[ $i ];
	my $taxon_name1 = $taxonOid2Name{ $taxon_oid1 };
	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
	if ( $taxon_in_file{$taxon_oid1} ) {
	    $taxon_name1 .= " (MER-FS)";
	    $url = "$main_cgi?section=MetaDetail&page=metaDetail";
	}
	$url .= "&taxon_oid=$taxon_oid1";
	print "<td class='img'>" . alink( $url, $taxon_name1 ) . "</td>\n";

	for( my $j = 0; $j < $nTaxons; $j++ ) {
	    my $taxon_oid2 = $taxon_oids[ $j ];
	    my $taxon_name2 = $taxonOid2Name{ $taxon_oid2 };
	    if ( $taxon_in_file{$taxon_oid2} ) {
		$taxon_name2 .= " (MER-FS)";
	    }
	    my $k = "$taxon_oid1,$taxon_oid2";
	    my $pearson_r = $corrMatrix{ $k };
	    $pearson_r = sprintf( "%.2f", $pearson_r );
	    my $color = getCorrColor( $pearson_r );
	    print "<td class='img' align='right' bgcolor='$color'>" .
	        "$pearson_r</td>\n";
	}
	print "</tr>\n";
    }
    print "</table>\n";

    #$dbh->disconnect();
    printStatusLine( "$nTaxons genomes loaded.", 2 );
}

############################################################################
# printCorrColorMap - Show legend for color map.
############################################################################
sub printCorrColorMap {
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Pearson R<br/>Color Legend</th>\n";

    my $style = "border-left: 1em solid white";

    print "<tr class='img'>\n";
    my $style = "border-left: 1em solid #fefefe";
    my $sp = nbsp( 10 );
    print "<td class='img' style='$style'>&le; 0$sp</td>\n";
    print "</tr>\n";

    my $nColors = @corrColors;
    for( my $i = 0; $i < $nColors; $i++ ) {
	my $next_i = $i + 1;
	my $color = $corrColors[ $i ];
	print "<tr class='img'>\n";
	my $style = "border-left: 1em solid $color";
	my $range = sprintf( "&gt; %.2f - &le; %.2f",
			     ( $i / 10 ), ( $next_i / 10 ) );
	print "<td class='img' style='$style'>$range</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";
}

############################################################################
# profile2Array - Get array from profile.
############################################################################
sub profile2Array {
    my( $profile_ref ) = @_;
    my @keys = sort( keys( %$profile_ref ) );
    my @a;
    for my $k( @keys ) {
	my $v = $profile_ref->{ $k };
	push( @a, $v );
    }
    return @a;
}

############################################################################
# getCorrColor - Get color for correlation values.
############################################################################
sub getCorrColor {
    my( $r ) = @_;
    my $r2 = int( $r * 10 );
    if ( $r2 <= 0 ) {
	return "white";
    }
    else {
	return $corrColors[ $r2 ];
    }
}

############################################################################
# getProfileVectors
############################################################################
sub getProfileVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    my $func = param( "func" );
    if( $func eq "cog" ) {
	getCogVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "pfam" ) {
	getPfamVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "enzyme" ) {
	getEnzymeVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "tigrfam" ) {
	getTigrfamVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "phylo_class" ) {
	getTaxonomyVectors( $dbh, $taxonProfiles_ref, "class" );
    }
    elsif( $func eq "phylo_order" ) {
	getTaxonomyVectors( $dbh, $taxonProfiles_ref, "order" );
    }
    elsif( $func eq "phylo_family" ) {
	getTaxonomyVectors( $dbh, $taxonProfiles_ref, "family" );
    }
    elsif( $func eq "phylo_genus" ) {
	getTaxonomyVectors( $dbh, $taxonProfiles_ref, "genus" );
    }
    elsif( $func eq "cogcat" ) {
	getCogCatVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "cogpathw" ) {
	getCogPathwVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "keggcatko" ) {
	getKeggCatVectors( $dbh, $taxonProfiles_ref, "ko" );
    }
    elsif( $func eq "keggcatec" ) {
	getKeggCatVectors( $dbh, $taxonProfiles_ref, "ec" );
    }
    elsif( $func eq "keggpathwko" ) {
	getKeggPathwVectors( $dbh, $taxonProfiles_ref, "ko" );
    }
    elsif( $func eq "keggpathwec" ) {
	getKeggPathwVectors( $dbh, $taxonProfiles_ref, "ec" );
    }
    elsif( $func eq "pfamcat" ) {
	getPfamCatVectors( $dbh, $taxonProfiles_ref );
    }
    elsif( $func eq "cart_funcs" ) {
	getFuncCartVectors( $dbh, $taxonProfiles_ref );
    }
}

sub getCountsQueryForFunc {
    my ($id) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $id =~ /^COG/ ) {
        $sql = qq{
            select gcg.cog, count( distinct gcg.gene_oid )
            from gene_cog_groups gcg, gene g
            where gcg.gene_oid = g.gene_oid
            and g.taxon = ?
            and gcg.cog = ?
            $rclause
            $imgClause
            group by gcg.cog
            order by gcg.cog
        };
    }
    elsif ( $id =~ /^KOG/ ) {
        $sql .= qq{
            select gkg.kog, count( distinct gkg.gene_oid )
            from gene_kog_groups gkg, gene g
            where gkg.gene_oid = g.gene_oid
            and g.taxon = ?
            and gkg.kog = ?
            $rclause
            $imgClause
            group by gkg.kog
            order by gkg.kog
        };
    }
    elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select gpf.pfam_family, count( distinct gpf.gene_oid )
            from gene_pfam_families gpf, gene g
            where gpf.gene_oid = g.gene_oid
            and g.taxon = ?
            and gpf.pfam_family = ?
            $rclause
            $imgClause
            group by gpf.pfam_family
            order by gpf.pfam_family
        };
    }
    elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select gtf.ext_accession, count( distinct gtf.gene_oid )
            from gene_tigrfams gtf, gene g
            where gtf.gene_oid = g.gene_oid
            and g.taxon = ?
            and gtf.ext_accession = ?
            $rclause
            $imgClause
            group by gtf.ext_accession
            order by gtf.ext_accession
        };
    }
    elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select ge.enzymes, count( distinct ge.gene_oid )
            from  gene_ko_enzymes ge, gene g
            where ge.gene_oid = g.gene_oid
            and g.taxon = ?
            and ge.enzymes = ?
            $rclause
            $imgClause
            group by ge.enzymes
            order by ge.enzymes
        };
    }
    elsif ( $id =~ /^KO:/ ) {
        $sql = qq{
            select gkt.ko_terms, count( distinct gkt.gene_oid )
            from gene_ko_terms gkt, gene g
            where gkt.gene_oid = g.gene_oid
            and g.taxon = ?
            and gkt.ko_terms = ?
            $rclause
            $imgClause
            group by gkt.ko_terms
            order by gkt.ko_terms
        };
    }
    elsif ( $id =~ /^MetaCyc:/ ) {
        $sql = qq{
            select bp.unique_id, count( distinct gb.gene_oid )
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
                 biocyc_reaction br, gene_biocyc_rxns gb, gene g
            where bp.unique_id = brp.in_pwys
            and brp.unique_id = br.unique_id
            and br.unique_id = gb.biocyc_rxn
            and br.ec_number = gb.ec_number
            and gb.gene_oid = g.gene_oid
            and g.taxon = ?
            and bp.unique_id = ?
            $rclause
            $imgClause
            group by bp.unique_id
            order by bp.unique_id
        };
    }

    return $sql;
}

sub getCountsQueryForFunc_new {
    my ($id) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $id =~ /^COG/ ) {
        $sql = qq{
            select g.cog, count( distinct g.gene_oid )
            from gene_cog_groups g
            where g.taxon = ?
            and g.cog = ?
            $rclause
            $imgClause
            group by g.cog
            order by g.cog
        };
    }
    elsif ( $id =~ /^KOG/ ) {
        $sql .= qq{
            select g.kog, count( distinct g.gene_oid )
            from gene_kog_groups g
            where g.taxon = ?
            and g.kog = ?
            $rclause
            $imgClause
            group by g.kog
            order by g.kog
        };
    }
    elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select g.pfam_family, count( distinct g.gene_oid )
            from gene_pfam_families g
            where g.taxon = ?
            and g.pfam_family = ?
            $rclause
            $imgClause
            group by g.pfam_family
            order by g.pfam_family
        };
    }
    elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select g.ext_accession, count( distinct g.gene_oid )
            from gene_tigrfams g
            where g.taxon = ?
            and g.ext_accession = ?
            $rclause
            $imgClause
            group by g.ext_accession
            order by g.ext_accession
        };
    }
    elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select g.enzymes, count( distinct g.gene_oid )
            from gene_ko_enzymes g
            where g.taxon = ?
            and g.enzymes = ?
            $rclause
            $imgClause
            group by g.enzymes
            order by g.enzymes
        };
    }
    elsif ( $id =~ /^KO:/ ) {
        $sql = qq{
            select g.ko_terms, count( distinct g.gene_oid )
            from gene_ko_terms g
            where g.taxon = ?
            and g.ko_terms = ?
            $rclause
            $imgClause
            group by g.ko_terms
            order by g.ko_terms
        };
    }
    elsif ( $id =~ /^MetaCyc:/ ) {
        $sql = qq{
            select brp.in_pwys, count( distinct g.gene_oid )
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
                 biocyc_reaction br, gene_biocyc_rxns g
            where brp.unique_id = br.unique_id
            and br.unique_id = g.biocyc_rxn
            and br.ec_number = g.ec_number
            and g.taxon = ?
            and brp.in_pwys = ?
            $rclause
            $imgClause
            group by bp.unique_id
            order by bp.unique_id
        };
    }

    return $sql;
}

sub getCountsQueryForFunc_new1 {
    my ($id) = @_;

    my $rclause   = WebUtil::urClause('g.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

    my $sql;
    if ( $id =~ /^COG/ ) {
        $sql = qq{
            select /*+ result_cache */ g.cog, g.gene_count
            from mv_taxon_cog_stat g
            where g.taxon_oid = ?
            and g.cog = ?
            $rclause
            $imgClause
            order by g.cog
        };
    }
    elsif ( $id =~ /^KOG/ ) {
        $sql .= qq{
            select /*+ result_cache */ g.kog, g.gene_count
            from mv_taxon_kog_stat g
            where g.taxon_oid = ?
            and g.kog = ?
            $rclause
            $imgClause
            order by g.kog
        };
    }
    elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select /*+ result_cache */ g.pfam_family, g.gene_count
            from mv_taxon_pfam_stat g
            where g.taxon_oid = ?
            and g.pfam_family = ?
            $rclause
            $imgClause
            order by g.pfam_family
        };
    }
    elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select /*+ result_cache */ g.ext_accession, g.gene_count
            from mv_taxon_tfam_stat g
            where g.taxon_oid = ?
            and g.ext_accession = ?
            $rclause
            $imgClause
            order by g.ext_accession
        };
    }
    elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select /*+ result_cache */ g.enzyme, g.gene_count
            from mv_taxon_ec_stat g
            where g.taxon_oid = ?
            and g.enzyme = ?
            $rclause
            $imgClause
            order by g.enzyme
        };
    }
    elsif ( $id =~ /^KO:/ ) {
        $sql = qq{
            select /*+ result_cache */ g.ko_term, g.gene_count
            from mv_taxon_ko_stat g
            where g.taxon_oid = ?
            and g.ko_term = ?
            $rclause
            $imgClause
            order by g.ko_term
        };
    }
    elsif ( $id =~ /^MetaCyc:/ ) {
        $sql = qq{
            select /*+ result_cache */ g.pwy_id, g.gene_count
            from mv_taxon_metacyc_stat g
            where g.taxon = ?
            and g.pwy_id = ?
            $rclause
            $imgClause
            order by g.pwy_id
        };
    }

    return $sql;
}

sub getFunctionType {
    my ($id) = @_;

    if ( $id =~ /^GO/ ) {
	return "go";
    }
    elsif ( $id =~ /^COG/ ) {
	return "cog";
    }
    elsif ( $id =~ /^KOG/ ) {
	return "kog";
    }
    elsif ( $id =~ /^pfam/ ) {
	return "pfam";
    }
    elsif ( $id =~ /^TIGR/ ) {
	return "tigr";
    }
    elsif ( $id =~ /^IPR/ ) {
	return "ipr";
    }
    elsif ( $id =~ /^EC:/ ) {
	return "ec";
    }
    elsif ( $id =~ /^TC:/ ) {
	return "tc";
    }
    elsif ( $id =~ /^KO:/ ) {
	return "ko";
    }
    elsif ( $id =~ /^MetaCyc:/ ) {
	return "metacyc";
    }
    elsif ( $id =~ /^IPWAY:/ ) {
	return "ipways";
    }
    elsif ( $id =~ /^PLIST:/ ) {
	return "plist";
    }
    elsif ( $id =~ /^ITERM:/ ) {
	return "iterm";
    }
    elsif ( $id =~ /^EGGNOG/ ) {
	return "eggnog";
    }
    return "";
}

############################################################################
# getFuncCartVectors - Get profile vectors for functions in cart only.
############################################################################
sub getFuncCartVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    # get functions in cart
    use FuncCartStor;
    my $fc = new FuncCartStor();
    my $recs = $fc->{recs};
    my @keys = sort keys(%$recs);

    my @fns;
    my %fn_types;
    my %cartfuncs;
    foreach my $k (@keys) {
        my $r = $recs->{$k};
        my ( $func_id, $func_name, undef ) = split( /\t/, $r );
	push @fns, $func_id;

	my $type = getFunctionType($func_id);
	next if ($type eq "");

	if (!defined($fn_types{$type})) {
	    $fn_types{ $type } = $func_id;
	} else {
	    $fn_types{ $type } .= "\t".$func_id;
	}
	$cartfuncs{ $func_id } = 0;
    }

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }

	print "Find profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

	my %profile = %cartfuncs;
	if ( $taxon_in_file{$taxon_oid} ) {
	    foreach my $fn_type (keys %fn_types) {
		# go through the list of fns in cart
		my @list = split("\t", $fn_types{ $fn_type });
		my %funcs = MetaUtil::getTaxonFuncCount($taxon_oid, '', $fn_type);
		foreach my $id (@list) {
		    $profile{ $id } = $funcs{$id};
		}
	    }
	}
	else {
	    foreach my $fnid (@fns) {
		my $sql = getCountsQueryForFunc($fnid);
		my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, "$fnid" );
		my( $id, $cnt ) = $cur->fetchrow();
		next if ( !defined($cartfuncs{ $id }) );
		$profile{ $id } = $cnt;
		$cur->finish();
	    }
	}

	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getCogVectors - Get profile vectors for COG.
############################################################################
sub getCogVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select c.cog_id
       from cog c
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow();
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	if ( $taxon_in_file{$taxon_oid} ) {
	    $taxon_name .= " (MER-FS)";
	}
	print "Find cog profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

	if ( $taxon_in_file{$taxon_oid} ) {
	    # MER-FS
	    my %funcs = MetaUtil::getTaxonFuncCount($taxon_oid, '', 'cog');
	    my %profile = %tpl;
	    foreach my $id (keys %funcs) {
		$profile{ $id } = $funcs{$id};
	    }
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
	else {
	    my $sql = qq{
	       select gcg.cog, count( distinct gcg.gene_oid )
	       from gene_cog_groups gcg
	       where gcg.taxon = ?
	       group by gcg.cog
	       order by gcg.cog
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getCogCatVectors - Get profile vectors for COG categories.
############################################################################
sub getCogCatVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select cf.function_code
       from cog_function cf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow();
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish();

#    my @keys = keys %tpl;
#    my $keystr = join(",", @keys);
#    webLog "\nANNA CATEGORIES cogcat: $keystr";

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
	print "Find cog category profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

	if ( $taxon_in_file{$taxon_oid} ) {
	    # MER-FS
	    my %profile = %tpl;
            MetaUtil::getTaxonCategories($taxon_oid, '', "cog", \%profile);
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;

	} else {
	    # MER-DB
	    my $sql = qq{
	       select cf.functions, count( distinct gcg.gene_oid )
	       from gene_cog_groups gcg, cog_functions cf
	       where gcg.taxon = ?
	       and cf.cog_id = gcg.cog
	       group by cf.functions
	       order by cf.functions
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getCogPathwVectors - Get profile vectors for COG Pathway Categories
############################################################################
sub getCogPathwVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select cog_pathway_oid
       from cog_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
	my( $id ) = $cur->fetchrow();
	last if !$id;
	$tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

#    my @keys = keys %tpl;
#    my $keystr = join(",", @keys);
#    webLog "\nANNA COGPATHWAYS cogpathw: $keystr";

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
        print "Find cogpathw profile for <i>" . escHtml( $taxon_name );
        print "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
            my %profile0 = %tpl;
            my %profile = MetaUtil::getTaxonCate2
		($taxon_oid, '', "cog_pathway", \%profile0);
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;

        } else {
    	    # MER-DB
    	    my $sql = qq{
                select cpcm.cog_pathway_oid, count( distinct gcg.gene_oid )
                from gene_cog_groups gcg, cog_pathway_cog_members cpcm
                where gcg.taxon = ?
                and gcg.cog = cpcm.cog_members
                group by cpcm.cog_pathway_oid
                order by cpcm.cog_pathway_oid
    	    };
            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            my %profile = %tpl;
            for( ;; ) {
                my( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                next if ( !defined($tpl{ $id }) );
                $profile{ $id } = $cnt;
            }
            $cur->finish();
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;
        }
    }
}

############################################################################
# getKeggCatVectors - Get profile vectors for KEGG Categories via KO or EC
############################################################################
sub getKeggCatVectors {
    my( $dbh, $taxonProfiles_ref, $type ) = @_;

    ## Template
    my $sql = qq{
       select distinct category, min(pathway_oid)
       from kegg_pathway
       group by category
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
	my( $fncat, $id ) = $cur->fetchrow();
	last if !$fncat;
	$tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

#    my @keys = keys %tpl;
#    my $keystr = join(",", @keys);
#    webLog "\nANNA CATEGORIES keggcat$type: $keystr";

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	if ( $taxon_in_file{$taxon_oid} ) {
	    $taxon_name .= " (MER-FS)";
	}
	print "Find keggcat $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

	if ( $taxon_in_file{$taxon_oid} ) {
	    # MER-FS
            my %profile0 = %tpl;
            my %profile = MetaUtil::getTaxonCate2
		($taxon_oid, '', "kegg_category_".$type, \%profile0);
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;

	} else {
	    my $sql = "";
            if ($type eq "ko") {
         	$sql = qq{
                select kp.category, count(distinct g.gene_oid),
                       min(kp.pathway_oid)
                from gene g, gene_ko_terms gk,
                     image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
                and g.gene_oid = gk.gene_oid
                and gk.ko_terms = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = kp.pathway_oid
                group by kp.category
		};
            } elsif ($type eq "ec") {
		$sql = qq{
                select kp.category, count(distinct g.gene_oid),
                       min(kp.pathway_oid)
                from gene g, gene_ko_enzymes ge,
                     image_roi_ko_terms irkt, ko_term_enzymes kte,
                     image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
                and g.gene_oid = ge.gene_oid
                and ge.enzymes = kte.enzymes
                and ir.roi_id = irkt.roi_id
                and irkt.ko_terms = kte.ko_id
                and ir.pathway = kp.pathway_oid
                group by kp.category
		};
	    }
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $fncat, $cnt, $id ) = $cur->fetchrow();
		last if !$fncat;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getKeggPathwVectors - Get profile vectors for KEGG Pathways via KO or EC
############################################################################
sub getKeggPathwVectors {
    my( $dbh, $taxonProfiles_ref, $type ) = @_;

    ## Template
    my $sql = qq{
       select distinct pathway_oid
       from kegg_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
	my( $id ) = $cur->fetchrow();
	last if !$id;
	$tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

#    my @keys = keys %tpl;
#    my $keystr = join(",", @keys);
#    webLog "\nANNA KEGGCATPATHWAYS keggpathw$type: $keystr";

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	if ( $taxon_in_file{$taxon_oid} ) {
	    $taxon_name .= " (MER-FS)";
	}
	print "Find keggpathw $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

	if ( $taxon_in_file{$taxon_oid} ) {
	    # MER-FS
            my %profile0 = %tpl;
            my %profile = MetaUtil::getTaxonCate2
		($taxon_oid, '', "kegg_pathway_".$type, \%profile0);
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;

	} else {
	    my $sql = "";
	    if ($type eq "ko") {
		$sql = qq{
                select kp.pathway_oid, count(distinct g.gene_oid)
                from gene g, gene_ko_terms gk, image_roi_ko_terms rk,
                     image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.gene_oid = gk.gene_oid
                and gk.ko_terms = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = kp.pathway_oid
                group by kp.pathway_oid
                order by kp.pathway_oid
 	        };
	    } elsif ($type eq "ec") {
		$sql = qq{
                select kp.pathway_oid, count(distinct g.gene_oid)
                from gene g, gene_ko_enzymes ge,
                     image_roi_ko_terms irkt, ko_term_enzymes kte,
                     image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.gene_oid = ge.gene_oid
                and ge.enzymes = kte.enzymes
                and ir.roi_id = irkt.roi_id
                and irkt.ko_terms = kte.ko_id
                and ir.pathway = kp.pathway_oid
                group by kp.pathway_oid
                order by kp.pathway_oid
                };
	    }
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getPfamVectors - Get profile vectors for Pfams.
############################################################################
sub getPfamVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select pf.ext_accession
       from pfam_family pf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow();
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
	print "Find pfam profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
            my %funcs = MetaUtil::getTaxonFuncCount($taxon_oid, '', 'pfam');
            my %profile = %tpl;
            foreach my $id (keys %funcs) {
		next if ( !defined($tpl{ $id }) );
                $profile{ $id } = $funcs{$id};
            }
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;
        }
	else {
	    my $sql = qq{
	       select gpf.pfam_family, count( distinct gpf.gene_oid )
	       from gene g, gene_pfam_families gpf
	       where g.gene_oid = gpf.gene_oid
	       and g.taxon = ?
	       group by gpf.pfam_family
	       order by gpf.pfam_family
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getPfamCatVectors - Get profile vectors for Pfam Categories
############################################################################
sub getPfamCatVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
        select function_code
        from cog_function
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
	my( $id ) = $cur->fetchrow();
	last if !$id;
	$tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

#    my @keys = keys %tpl;
#    my $keystr = join(",", @keys);
#    webLog "\nANNA PFAMCAT pfamcat: $keystr";

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
        print "Find pfamcat profile for <i>" . escHtml( $taxon_name );
        print "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
            my %profile = %tpl;
            MetaUtil::getTaxonCategories($taxon_oid, '', "pfam", \%profile);
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;

        } else {
	    # MER-DB
            my $sql = qq{
                select cf.function_code,
                       count(distinct gpf.gene_oid)
                from gene g, gene_pfam_families gpf, pfam_family_cogs pfc,
                cog_function cf, cog_pathway cp
                where g.gene_oid = gpf.gene_oid
                and g.taxon = ?
                and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
                and gpf.pfam_family = pfc.ext_accession
                and pfc.functions = cf.function_code
                and cf.function_code = cp.function
                group by cf.function_code
                order by cf.function_code
            };

            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            my %profile = %tpl;
            for( ;; ) {
                my( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                next if ( !defined($tpl{ $id }) );
                $profile{ $id } = $cnt;
            }
            $cur->finish();
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;
        }
    }
}

############################################################################
# getEnzymeVectors - Get profile vectors for enzymes.
############################################################################
sub getEnzymeVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select ez.ec_number
       from enzyme ez
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow();
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
	print "Find enzyme profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
            my %funcs = MetaUtil::getTaxonFuncCount($taxon_oid, '', 'enzyme');
            my %profile = %tpl;
            for my $id (keys %funcs) {
		next if ( !defined($tpl{ $id }) );
                $profile{ $id } = $funcs{$id};
            }
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;

        } else {
	    my $sql = qq{
	       select ge.enzymes, count( distinct ge.gene_oid )
	       from gene g, gene_ko_enzymes ge
	       where g.gene_oid = ge.gene_oid
	       and g.taxon = ?
	       group by ge.enzymes
	       order by ge.enzymes
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getTigrfamVectors - Get profile vectors for TIGRfams.
############################################################################
sub getTigrfamVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select tf.ext_accession
       from tigrfam tf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow();
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish();

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
	print "Find tigrfam profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
            my %funcs = MetaUtil::getTaxonFuncCount($taxon_oid, '', 'tigrfam');
            my %profile = %tpl;
            for my $id (keys %funcs) {
		next if ( !defined($tpl{ $id }) );
                $profile{ $id } = $funcs{$id};
            }
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;
        }
        else {
	    my $sql = qq{
	       select gtf.ext_accession, count( distinct gtf.gene_oid )
 	       from gene g, gene_tigrfams gtf
	       where g.gene_oid = gtf.gene_oid
	       and g.taxon = ?
	       group by gtf.ext_accession
	       order by gtf.ext_accession
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    for( ;; ) {
		my( $id, $cnt ) = $cur->fetchrow();
		last if !$id;
		next if ( !defined($tpl{ $id }) );
		$profile{ $id } = $cnt;
	    }
	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# getTaxonomyVectors - Get profile vectors for phylo family
############################################################################
sub getTaxonomyVectors {
    my( $dbh, $taxonProfiles_ref, $txcat ) = @_;

    my %taxon_in_file;
    if ( $in_file ) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for (;;) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my $nvl = WebUtil::getNvl();
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $unknown = "unclassified";

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses    = "Yes" if !$hideViruses;
    my $virusClause = "and t.domain not like 'Vir%'"
        if $hideViruses eq "Yes";

    my $sql = qq{
          select t.taxon_oid, t.domain, t.phylum,
                 $nvl(t.ir_class, '$unknown'),
                 $nvl(t.ir_order, '$unknown'),
                 $nvl(t.family,   '$unknown'),
                 $nvl(t.genus,    '$unknown')
          from taxon t
          where 1 = 1
          $rclause
          $imgClause
    };

    my $items = "";
    my $orderby = "";
    if ($txcat eq "class") {
	$items = "t.phylum || ' ' || t.ir_class ";
	$orderby = "t.phylum, t.ir_class";
    } elsif ($txcat eq "order") {
	$items = "t.phylum || ' ' || t.ir_class ";
	$orderby = "t.phylum, t.ir_class, t.ir_order";
    } elsif ($txcat eq "family") {
	$items = "t.phylum || ' ' || t.ir_class "
	       . "|| ' ' || t.family ";
	$orderby = "t.phylum, t.ir_class, "
	         . "t.ir_order, t.family";
    } elsif ($txcat eq "genus") {
	$items = "t.phylum || ' ' || t.ir_class "
	       . "|| ' ' || t.family || ' ' || t.genus ";
	$orderby = "t.phylum, t.ir_class, "
	         . "t.ir_order, t.family, t.genus";
    }

    ## Template
    my $sql = qq{
        select distinct t.domain, $items from taxon t
	where t.domain in ('Archaea','Bacteria','Eukaryota','Viruses')
        $rclause $imgClause $virusClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %tpl;
    my %tpl2;
    for( ;; ) {
	my( $domain, $taxonomy ) = $cur->fetchrow();
	last if !$taxonomy;
	$tpl{ $taxonomy } = 0;
	$tpl2{ $domain . " " . $taxonomy } = 0;
    }
    $cur->finish();

    my @taxon_oids;
    my $usethem = param("only_cart_genomes");
    if ($usethem) {
        require GenomeCart;
        my $oids = GenomeCart::getAllGenomeOids();
        @taxon_oids = @$oids;
    } else {
	@taxon_oids = param("selectedGenome1");
    }

    my @lineages = sort (keys %tpl2);
    foreach my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $taxon_name .= " (MER-FS)";
        }
	print "Find <u>phylo-$txcat</u> profile for <i>"
	    . escHtml( $taxon_name )
	    . "</i> ...<br/>\n";

        if ( $taxon_in_file{$taxon_oid} ) {
            # MER-FS
	    my %profile = %tpl;
	    foreach my $p (@lineages) {
		my ( $domain, $phylum, $ir_class, $family, $genus )
		    = split(" ", $p);
		my ($domain, @rest) = split(" ", $p);
		my $lineage = join(" ", @rest);

		print "&nbsp;&nbsp;processing $taxon_oid [$lineage] ...<br/>";
		my $cnt = MetaUtil::getPhyloGeneCounts
		    ($taxon_oid, 'assembled', $domain, $phylum,
		     $ir_class, $family, $genus);
		next if !$cnt;
		$profile{ $lineage } = $cnt;
            }
            $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	    print "<br/>";
        }
        else {
	    my $sql = qq{
	      select distinct $items,
              count(distinct dt.homolog)
              from dt_phylum_dist_genes dt, taxon t
              where dt.percent_identity >= 30
              and dt.taxon_oid = ?
              and dt.homolog_taxon = t.taxon_oid
              $rclause
              $imgClause
              group by $items
              order by $items
            };

	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my %profile = %tpl;
	    my $i = 0;
	    for( ;; ) {
		my( $taxonomy, $cnt ) = $cur->fetchrow();
		last if !$taxonomy;
		next if ( !defined($tpl{ $taxonomy }) );
		$profile{ $taxonomy } = $cnt;
		$i++;
	    }

	    $cur->finish();
	    $taxonProfiles_ref->{ $taxon_oid } = \%profile;
	}
    }
}

############################################################################
# normalizeProfileVectors - Normalize value by genome size.
############################################################################
sub normalizeProfileVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    print "<p>Normalizing profiles by genome size ...<br/>\n";
    my @taxon_oids = sort( keys( %$taxonProfiles_ref ) );
    my $nTaxons = scalar @taxon_oids;
    print "$nTaxons genomes total ...<br/>\n";
    for my $taxon_oid( @taxon_oids ) {
        my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	normalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref );
    }
}

############################################################################
# normalizeTaxonProfile - Normalize profile for one taxon.
############################################################################
sub normalizeTaxonProfile {
    my( $dbh, $taxon_oid, $profile_ref ) = @_;

    my $sql = qq{
       select total_gene_count
       from taxon_stats
       where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my( $total_gene_count ) = $cur->fetchrow();
    $cur->finish();

    if( $total_gene_count == 0 ) {
       webLog( "normalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       warn( "normalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       return;
    }
    my @keys = sort( keys( %$profile_ref ) );
    for my $k( @keys ) {
       my $cnt = $profile_ref->{ $k };
       my $v = ( $cnt / $total_gene_count ) * 1000;
       $profile_ref->{ $k } = $v;
    }
}


1;
