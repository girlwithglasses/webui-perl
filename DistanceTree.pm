###########################################################################
# DistanceTree.pm - draws a radial phylogenetic tree
# $Id: DistanceTree.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package DistanceTree;
my $section = "DistanceTree";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use OracleUtil;
use WebConfig;
use WebUtil;
use GenomeListJSON;

$| = 1;

my $env = getEnv();
my $main_cgi = $env->{ main_cgi };
my $cgi_dir  = $env->{ cgi_dir };
my $cgi_url  = $env->{ cgi_url };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $tmp_url  = $env->{ tmp_url };
my $tmp_dir  = $env->{ tmp_dir };
my $taxon_fna_dir = $env->{ taxon_fna_dir };
my $verbose  = $env->{ verbose };
my $base_url = $env->{ base_url };
my $base_dir = $env->{ base_dir };
my $tool = lastPathTok( $0 );
my $include_metagenomes = $env->{include_metagenomes};

my $nvl = getNvl();
my $decorator_exe = $env->{ decorator_exe };
my $YUI = $env->{yui_dir_28};

my $ISOLATE_LIMIT = 1500;
my $META_LIMIT = 500;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)
    if ($page eq "tree") {
        printStatusLine("Loading ...", 1);

	my $phylip_url =
	    "http://evolution.genetics.washington.edu/phylip/doc/";
	my $link = "<a href=$phylip_url target=_blank>PHYLIP</a>";

	my $description =
	    "The tree is created using the alignment of 16S genes based on "
	  . "the SILVA database and dnadist and neighbor tools from the $link "
	  . "package. <br/>For cases where the exact gene sequence cannot be "
	  . "found in the SILVA database, the sequence with the highest "
	  . "similarity is selected.<br/>At least 3 genomes are required for "
	  . "a neighbor-joining run.";

	WebUtil::printHeaderWithInfo
	    ("Distance Tree", $description,
	     "show description for this tool",
	     "Distance Tree Info", 0, "DistanceTree.pdf", "", "java");

	printMainForm();

	my $limit_note = "If &gt;".$ISOLATE_LIMIT." genomes are selected, "
	    . "a precomputed newick file will be used instead.";
	if ($include_metagenomes) {
	    $limit_note = "If &gt;" . $ISOLATE_LIMIT . " isolate or &gt;"
		. $META_LIMIT . " meta genomes are selected, a precomputed "
		. "newick file will be used instead.";
	}

	print "<p>\n";
	print "<font color='#003366'>"
	    . "Please select at least 3 genomes for the tree. $limit_note<br/>"
	    . "<u>Note</u>: Isolate genomes and Metagenomes cannot be combined"
	    . " in one tree as these are computed differently.<br/>"
	    . "Only genomes with distance data are listed.<br>"
	    . "</font>\n";

	if ($include_metagenomes) {
	    print "<p>\n";
	    print "BLAST Percent Identity: &nbsp;";
	    print "<input type='radio' name='perc_identity' "
		. "value='30' checked='checked' />30+ &nbsp;";
	    print "<input type='radio' name='perc_identity' "
		. "value='60' />60+ &nbsp;";
	    print "<input type='radio' name='perc_identity' "
		. "value='90' />90+ &nbsp;";
	    print "</p>\n";
	}

	printForm();
	print end_form();
	GenomeListJSON::showGenomeCart($numTaxon);

    } elsif (paramMatch("phyloTree") ne "") {
	my $tx2cnt_href = getHomologHitCount();
	runTree($tx2cnt_href, "selected", "homologs");

    } elsif (paramMatch("runTree") ne "") {
        runTree();
    }
}

sub printForm {
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
	( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 0 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => -1 );
    $template->param( from        => 'DistanceTree' );

    if ( $include_metagenomes ) {
	$template->param( selectedGenome1Title => 'Isolates or Metagenomes (not both)' );
	$template->param( include_metagenomes => 1 );
	$template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    my $name = "_section_DistanceTree_runTree";
    GenomeListJSON::printHiddenInputType( $section, 'runTree' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
	( 'go', $name, 'Generate Tree', '', $section,
	  'runTree', 'meddefbutton', 'selectedGenome1', 3 );
    print $button;
}

############################################################################
# temporary placement of this subroutine
############################################################################
sub getHomologHitCount {
    #my ($dbh) = @_;
    my $xlogSource = param("xlogSource");
    my $gene_oid = param("genePageGeneOid");

    if ( blankStr($gene_oid) ) {
        webError( "Query gene cannot be NULL." );
    }

    my $dbh = dbLogin();
    my %taxon2count;
    my $taxon = getTaxonOid4GeneOid( $dbh, $gene_oid );
    $taxon2count{ $taxon }++;

    if ( $xlogSource eq "fusionComponents" ) {
        my $sql = qq{
            select distinct gfc.taxon
            from gene_all_fusion_components gfc
            where gfc.gene_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ;; ) {
            my ($taxon) = $cur->fetchrow();
            last if !$taxon;
            $taxon2count{ $taxon }++;
        }
        $cur->finish();
    } elsif ( $xlogSource eq "otfBlast" ) {
        my $inFile   = "$cgi_tmp_dir/otfTaxonsHit.$gene_oid.txt";
        if ( !( -e $inFile ) ) {
            webError("Session expired.  Please refresh gene page.");
        }
        my $rfh = newReadFileHandle( $inFile, "getHomologHitCount" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            $taxon2count{ $s }++;
        }
        close $rfh;
    } else {
	my %validTaxons = WebUtil::getAllTaxonsHashed($dbh);
	my @rows = getBBHZipRows( $dbh, $gene_oid, \%validTaxons );
	for my $row (@rows) {
	    my ( $qid, $sid, @ignore )
		= split( /\t/, $row );
	    my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
	    $taxon2count{ $staxon }++;
	}

        #my $sql = qq{
        #    select go.taxon
        #    from gene_orthologs go
        #    where go.gene_oid = ?
        #};
        #my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        #for ( ;; ) {
        #    my ($taxon) = $cur->fetchrow();
        #    last if !$taxon;
        #    $taxon2count{ $taxon }++;
        #}
        #$cur->finish();
    }
    #$dbh->disconnect();
    return \%taxon2count;
}

############################################################################
# runTree - creates the circular phylogenetic tree for selected genomes
#    that have distance data. Alternatively, this method can receive
#    parameters: $taxon_selection - which can be either "all" or "selected"
#    genomes to include, and $taxon2cnt_href - which is a mapping of genes
#    to gene count, used for specifying how to group genomes for coloring
############################################################################
sub runTree {
    my( $taxon2cnt_href, $taxon_selection, $type, $noTitle, $metag ) = @_;

    # try to get params from submit:
    if ($taxon2cnt_href eq "") {
	my $txstr = param("taxon2cnt");
	my @items = split(",", $txstr);
	foreach my $i (@items) {
	    my ($tx, $cnt) = split("\t", $i);
	    $taxon2cnt_href->{ $tx } = $cnt;
	}
	$taxon_selection = param("taxon_selection");
	$type = param("type");
    }

    $noTitle = 0 if $noTitle eq "";
    my @oids = param("selectedGenome1");
    my $nTaxons0 = @oids;

    if ( $nTaxons0 < 3 &&
	 $taxon_selection eq "" ) {
	webError( "Please select at least 3 genomes." );
    }

    my $dbh = dbLogin();
    if ( $taxon_selection eq "all" ) {
	my %alltaxons = WebUtil::getAllTaxonsHashed( $dbh );
	@oids = sort( keys( %alltaxons ) );
    }
    elsif ( $taxon_selection eq "selected" ) {
	my %alltaxons = WebUtil::getSelectedTaxonsHashed( $dbh );
	@oids = sort( keys( %alltaxons ) );
    }

    my $taxonStr;
    if (OracleUtil::useTempTable($#oids + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@oids);
        $taxonStr = "select id from gtt_num_id";
    } else {
        $taxonStr = join(",", @oids);
    }

    my $sql = qq{
        select max(tx.distmatrix_date)
        from taxon tx
        where tx.taxon_oid in ($taxonStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($timestamp) = $cur->fetchrow();

    my $description =
	  "Distance data is computed for all genomes and stored in the "
	. "database. This data is periodically recomputed to include "
	. "new genomes. Of the selected genomes, only those with distance "
	. "data are added to the matrix. ";
    if (!$noTitle) {
	my $title = "Phylogenetic Tree for All Genomes";
	if ($taxon_selection eq "" || $taxon_selection eq "selected") {
	    $title = "Phylogenetic Tree for Selected Genomes";
	}

        WebUtil::printHeaderWithInfo
            ($title, $description,
             "show info for this tool",
             "Distance Tree Info", 0, "DistanceTree.pdf", "", "java");
    }

    print "<p style='width: 650px;'>";
    print $description;
    print "</p>";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv("runTree");
    print "<p>[This may take time] " . (scalar @oids) . " genomes selected";

    my %taxonNames;
    my @taxon_oids;
    my @m_taxon_oids;

    my $mapFile = $tmp_dir . "/table$$.map";
    my $wfh = newWriteFileHandle( $mapFile, "runTree" );

    print "<br/>Getting info for genomes.";

    my $sql = qq{
	select distinct tx.taxon_oid, tx.taxon_display_name,
	       tx.domain, tx.genome_type,
               tx.phylum, $nvl(tx.ir_class, 'unknown'),
               $nvl(tx.ir_order, 'unknown'),
	       tx.family, tx.genus
	from taxon tx
        where tx.taxon_oid in ($taxonStr)
	order by tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
	my( $taxon_oid, $name, $domain, $genome_type, $phylum, $class,
	    $order, $family, $genus ) = $cur->fetchrow();
	last if !$taxon_oid;

	if ($genome_type eq "metagenome") {
	    push( @m_taxon_oids, $taxon_oid );
	} else {
	    push( @taxon_oids, $taxon_oid );
	}
	$taxonNames{ $taxon_oid } = $name;

	my $code;
	my $cnt = $taxon2cnt_href->{ $taxon_oid };

	if ( $type eq "" ) {
	    $code = uc(substr($class, 0, 10));
	} elsif ($type eq "homologs") {
	    if ( $cnt eq "" ) {
		$cnt = "0";
	    }
	    if ($cnt > 2) {
		$code = "above_2";
	    } else {
		$code = "count_$cnt";
	    }
	    $name = $name . "_" . $cnt;
	} elsif ($type eq "counts") {
	    if ($cnt eq "") {
		$cnt = "0";
	    }
	    $code = uc(substr($class, 0, 10));
	    $name = $name . "_" . $cnt;
	}
	#$code = ~ s/s+/ /g;
	$code =~ s/[^\w]/_/g;	# only alphanumeric chars allowed
	print $wfh "$taxon_oid\t"
	    . "TAXONOMY_CODE:$code\t"
	    . "TAXONOMY_ID:$taxon_oid\t"
	    . "TAXONOMY_ID_PROVIDER:img\t"
	    . "TAXONOMY_SN:$name\t"
	    . "TAXONOMY_CN:$domain,$phylum,$class,$order,$family,$genus\n";
    }
    $cur->finish();
    close $wfh;

    my $nTaxons = scalar @taxon_oids;
    my $n_mTaxons = scalar @m_taxon_oids;
    my $newickFile;
    my $note;
    my $limit_note;

    if ($nTaxons > 2 && $n_mTaxons > 2) {
	$note = "<u>Note</u>: Isolate genomes and Metagenomes cannot be "
	      . "combined in one tree as these are computed differently.<br/>";
	$taxon_selection = "all"
	    if $n_mTaxons > $META_LIMIT &&
	       $nTaxons > $ISOLATE_LIMIT;
    } else {
	if ($n_mTaxons > $META_LIMIT) {
	    $limit_note = "A precomputed newick file of all metagenomes is used since >".$META_LIMIT." metagenomes were selected.<br/>";
	}

	if ($taxon_selection = "selected"
	    && $nTaxons > $ISOLATE_LIMIT) {
	    $limit_note = "A precomputed newick file of all isolate genomes is used since >".$ISOLATE_LIMIT." genomes were selected.<br/>";
	}

	$taxon_selection = "all"
	    if $n_mTaxons > $META_LIMIT ||
	       $nTaxons > $ISOLATE_LIMIT;
    }

    my $perc = param("perc_identity"); # only metagenomes
    my $itxFile;
    if ($taxon_selection ne "all") {
	my $matrixFile;

	if ($include_metagenomes && $perc ne "" && scalar @m_taxon_oids > 2) {
	    $nTaxons = @m_taxon_oids;
	    ($matrixFile, $nTaxons, $itxFile) =
		getUnifracDistMatrix(\@m_taxon_oids, $perc);

	    if (!$matrixFile) {
		if (scalar @taxon_oids > 2) {
		    $perc = ""; # clear this - not needed for isolates
		    ($matrixFile, $nTaxons, $itxFile) =
			getDistMatrixFile($dbh, \@taxon_oids);
		    return if !$matrixFile;
		} else {
		    printStatusLine( "No distance data.", 2 );
		    printEndWorkingDiv("runTree");

		    my $link = "metagenomes";
		    if (-e $itxFile) {
			$link = alink("$tmp_url/invalid_taxons$$.txt",
				      "metagenomes", "_blank");
		    }
		    print "<p>The $link you selected do <u>not</u> have "
			. "distance data computed. Please select at least "
			. "3 metagenomes "
                        . "<font color='red'>with distance data.</font>";
		    print "</p>";
		    return;
		}

	    } else {
		my $unifrac_file = "/global/projectb/sandbox/IMG_web/"
		    . "img_web_data/distance_tree/fs_unifrac_dist_";
		$unifrac_file .= $perc.".txt";
		if (-e $unifrac_file) {
		    use File::stat;
		    my $sb = stat($unifrac_file);
		    $timestamp = localtime($sb->mtime); # last modified date
		}
	    }

	} else {
	    $perc = ""; # clear this - not needed for isolates
	    ($matrixFile, $nTaxons, $itxFile)
		= getDistMatrixFile($dbh, \@taxon_oids);
	    return if !$matrixFile;
	}

	print "<br/>Running neighbor to create a newick file [$nTaxons]";
	$newickFile = getNewickFile($matrixFile);

    } else {
	if ($include_metagenomes &&
	    $perc ne "" && scalar @m_taxon_oids > $META_LIMIT) {
	    # too many metagenomes selected, get a precomputed newick file
	    #$newickFile = $tmp_dir . "/unifrac_newick$$.txt";
	    #my $newick_all = $env->{unifrac_newick_all};
	    #runCmd( "/bin/cp $newick_all $newickFile" );
	    #if (-e $unifrac_file) {
	    #	use File::stat;
	    #	my $sb = stat($unifrac_file);
	    #	$timestamp = localtime($sb->mtime); # last modified date
	    #}

	    printEndWorkingDiv("runTree");
	    #print "<p>".$limit_note."</p>";
	    webError( "Please select no more than $META_LIMIT metagenomes." );
	    return; # for now ...
	}

	$newickFile = $tmp_dir . "/newick$$.txt";
	my $newick_all = $env->{newick_all};
	runCmd( "/bin/cp $newick_all $newickFile" );
	if (-e $newickFile) {
	    use File::stat;
	    my $sb = stat($newickFile);
	    $timestamp = localtime($sb->mtime); # last modified date
	}
    }

    my $cwd = "`pwd`";

    # decorate and convert newick file to phyloXML
    print "<br/>Converting to phyloXML";
    chdir( $tmp_dir );
    my $decoratedFile = $tmp_dir . "/decorated$$.txt";
    my $cmd = $decorator_exe." ".$newickFile." ".$mapFile." ".$decoratedFile;
    my $st = runCmdNoExit($cmd);

    chdir( $cwd );

    printEndWorkingDiv("runTree");

    my $gene_oid = param("genePageGeneOid");
    if ($taxon_selection ne "" && $gene_oid ne "") {
        my $url =
            "$main_cgi?section=GeneDetail&page=geneDetail"
	    . "&gene_oid=$gene_oid";
        my $link = alink( $url, $gene_oid );
        print "<p>Displaying homologs for gene: ".$link."<br/>";
	print " [ homolog counts: "
	    . "<font color=\"#999966\"><b>0</b></font>, "
	    . "<font color=\"#6633FF\"><b>1</b></font>, "
	    . "<font color=\"#009933\"><b>2</b></font>, "
	    . "<font color=\"#FF0066\"><b>>2</b></font> ]";
	print "<br/>\n";
	print "</p>";
    }

    print "<p>\n";
    if ($nTaxons != $nTaxons0) {
	my $m = "isolate ";
	$m = "meta" if $perc ne "";
        print "$nTaxons $m"."genomes were analyzed ";
        if ($taxon_selection eq "") {
            print "(out of $nTaxons0 that were selected).";
	    if (-e $itxFile) {
		print "&nbsp;View list of selected "
		    . alink("$tmp_url/invalid_taxons$$.txt",
			    $m."genomes with no distance data", "_blank")
		    . ".";
	    }
        }
        print "<br/>\n";
    }
    print $note;
    print $limit_note;

    if ($include_metagenomes && $perc ne "" && scalar @m_taxon_oids > 2) {
	print "BLAST Percent Identity used: ".$perc."+"."<br/>";
    }
    print "Last computed on: <font color='red'>$timestamp</font>";
    print "<br/><br/>";

    my $url = "http://www.phylosoft.org/archaeopteryx/";
    print "The tree below is generated using the "
        . alink($url, "Archaeopteryx")." applet";
    print "</p>\n";

    if (!(-e $newickFile)) {
	print "<p>\n";
	my $url = "$base_url/tmp/table$$.map";
	print alink($url, "View map file", "_blank");
	print "</p>\n";
	webError( "Could not create the required newick input file: " );
    }
    if (!(-e $decoratedFile)) {
	print "<p>\n";
	my $url = "$base_url/tmp/newick$$.txt";
	print alink($url, "View newick", "_blank");
	print "</p>\n";
	webError( "Could not create the required phyloXML input file: " );
    }
    printAptxApplet("decorated$$.txt");
    printStatusLine("Done - $nTaxons genomes analyzed.", 2);
}

############################################################################
# getDistMatrixFile - creates a distance matrix for the specified taxons
############################################################################
sub getDistMatrixFile {
    my ($dbh, $oids) = @_;
    my @taxon_oids = @$oids;
    #my $nTaxons = scalar @taxon_oids;

    my $taxonStr;
    if (OracleUtil::useTempTable($#taxon_oids + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@taxon_oids);
        $taxonStr = "select id from gtt_num_id";
    } else {
        $taxonStr = join(",", @taxon_oids);
    }

    ## Matrix
    my $count = 0;
    my %matrix;

    # first validate that a given taxon has distance data
    print "<br/>Validating distance data for genomes";
    my $sql = qq{
        select distinct tm.taxon_oid, tm.distance
        from taxon_dist_matrix tm
        where tm.taxon_oid in ($taxonStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %valid_ids;
    for ( ;; ) {
        my( $taxon_oid, $distance ) = $cur->fetchrow();
        last if !$taxon_oid;
        $valid_ids{ $taxon_oid } = 1;
    }
    $cur->finish();

    print "<br/>Computing distance matrix for genomes ";
    my @validIds = sort keys %valid_ids;
    my $nTaxons = scalar @validIds;

    my $txFile = $tmp_dir . "/invalid_taxons$$.txt";
    if (scalar @taxon_oids != $nTaxons) {
        # write out the list of invalid taxons
        my $wfh = newWriteFileHandle( $txFile, $tool );
        foreach my $tx (@taxon_oids) {
            if (!exists $valid_ids{ $tx }) {
                print $wfh "$tx\n";
            }
        }
        close $wfh;
    }

    if ( $nTaxons < 3 ) {
        printStatusLine( "No distance data.", 2 );
	printEndWorkingDiv("runTree");

	my $link = "genomes";
	if (-e $txFile) {
	    $link = alink("$tmp_url/invalid_taxons$$.txt",
			  "genomes", "_blank");
	}
	print "<p>The $link you selected do <u>not</u> have "
	    . "distance data computed. Please select at least "
	    . "3 genomes <font color='red'>with distance data.</font>";
	print "</p>";

	return (0, 0, $txFile);
    }

    my $taxonStr;
    if (OracleUtil::useTempTable($#validIds + 1)) {
	OracleUtil::insertDataArray($dbh, "gtt_num_id", \@validIds);
        $taxonStr = "select id from gtt_num_id";
    } else {
        $taxonStr = join(",", @validIds);
    }

    my $sql = qq{
	select distinct tm.taxon_oid,
	       tm.paired_taxon, tm.distance
        from taxon_dist_matrix tm, taxon tx
	where tx.taxon_oid = tm.taxon_oid
        and tx.taxon_oid in ($taxonStr)
        and tm.paired_taxon in ($taxonStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
	my( $taxon_oid, $paired_taxon, $distance )
	    = $cur->fetchrow();
	last if !$taxon_oid;
	$count++;

	my $k1 = "$taxon_oid,$paired_taxon";
	my $k2 = "$paired_taxon,$taxon_oid";
	$matrix{ $k1 } = $distance;
	$matrix{ $k2 } = $distance;
	if ($count % 10000 == 0 && $count > 1) {
	    print " . ";
	}
    }
    $cur->finish();

    ## write out the distance matrices for taxons
    my $outFile = $tmp_dir . "/dist_matrix$$.txt";
    my $wfh = newWriteFileHandle( $outFile, $tool );
    print $wfh "$nTaxons\n";

    print "<br/>Writing the distance matrix to a file";
    for ( my $i = 0; $i < $nTaxons; $i++ ) {
	my $taxon_oid1 = $validIds[ $i ];
	printf $wfh "%-15s", $taxon_oid1;
	for ( my $j = 0; $j < $nTaxons; $j++ ) {
	    my $taxon_oid2 = $validIds[ $j ];
	    my $k = "$taxon_oid1,$taxon_oid2";
	    my $dist = $matrix{ $k };
	    if ( $dist eq "" ) {
		warn( "$tool: $k: cannot find distance\n" )
		    if $verbose >= 2;
		$dist = 0;
	    }
	    printf $wfh " %6.2f", $dist;
	}
	if ($i % 100 == 0 && $i > 1) {
	    print " . ";
	}
	print $wfh "\n";
    }
    close $wfh;

    return ($outFile, $nTaxons, $txFile);
}

############################################################################
# getUnifracDistMatrix - creates a distance matrix for the specified taxons
#     by reading the data from unifrac files based on BLAST percent identity
############################################################################
sub getUnifracDistMatrix {
    my ($oids, $perc_identity) = @_;
    my @taxon_oids = @$oids;
    my $nTaxons = scalar @taxon_oids;

    print "<br/>Reading distance matrix for metagenomes";
    # e.g. fs_unifrac_dist_30.txt
    # format: taxon_oid1 taxon_oid2 unifrac_dist
    my $unifrac_file = "/global/projectb/sandbox/IMG_web/"
	             . "img_web_data/distance_tree/fs_unifrac_dist_";
    $unifrac_file .= $perc_identity.".txt";
    if (!(-e $unifrac_file)) {
	printEndWorkingDiv("runTree");
        webError( "Cannot find the file $unifrac_file." );
    }
    if (!(-r $unifrac_file)) {
	printEndWorkingDiv("runTree");
        webError( "The file $unifrac_file cannot be read." );
    }

    my $rfh = newReadFileHandle( $unifrac_file, "unifrac_dist_file", 1 );

    my %matrix;
    my $count = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
	$count++;

	my ($tx1, $tx2, $distance) = split( /\t/, $s );
        my $k1 = "$tx1,$tx2";
        my $k2 = "$tx2,$tx1";
        $matrix{ $k1 } = $distance;
        $matrix{ $k2 } = $distance;
        if ($count % 10000 == 0 && $count > 1) {
            print " . ";
        }
    }

    my %valid_ids;
    print "<br/>Checking distance data for taxons";
    for ( my $i = 0; $i < $nTaxons; $i++ ) {
	my $taxon_oid1 = $taxon_oids[ $i ];
	for ( my $j = 0; $j < $nTaxons; $j++ ) {
	    my $taxon_oid2 = $taxon_oids[ $j ];
	    my $k = "$taxon_oid1,$taxon_oid2";
	    my $dist = $matrix{ $k };
	    if ( $dist eq "" || $dist eq "NA" || $dist eq "NaN" ) {
		warn( "$tool: $k: cannot find distance\n" )
		    if $verbose >= 2;
		next;
	    }
	    $valid_ids{ $taxon_oid1 } = 1;
	}
	if ($i % 100 == 0 && $i > 1) {
	    print " . ";
	}
    }

    my @validIds = sort keys %valid_ids;
    my $nTaxons = scalar @validIds;

    my $txFile = $tmp_dir . "/invalid_taxons$$.txt";
    if (scalar @taxon_oids != $nTaxons) {
        # write out the list of invalid taxons
        my $wfh = newWriteFileHandle( $txFile, $tool );
        foreach my $tx (@taxon_oids) {
            if (!exists $valid_ids{ $tx }) {
                print $wfh "$tx\n";
            }
        }
        close $wfh;
    }

    if ( $nTaxons < 3 ) {
	return (0, 0, $txFile);
    }

    ## write out the distance matrices for taxons
    my $outFile = $tmp_dir . "/dist_matrix$$.txt";
    my $wfh = newWriteFileHandle( $outFile, $tool );
    print $wfh "$nTaxons\n";

    print "<br/>Writing the distance matrix to a file";
    for ( my $i = 0; $i < $nTaxons; $i++ ) {
        my $taxon_oid1 = $validIds[ $i ];
        printf $wfh "%-15s", $taxon_oid1;
        for ( my $j = 0; $j < $nTaxons; $j++ ) {
            my $taxon_oid2 = $validIds[ $j ];
            my $k = "$taxon_oid1,$taxon_oid2";
            my $dist = $matrix{ $k };
            printf $wfh " %6.2f", $dist;
        }
        if ($i % 100 == 0 && $i > 1) {
            print " . ";
        }
        print $wfh "\n";
    }
    close $wfh;

    return ($outFile, $nTaxons, $txFile);
}

############################################################################
# getNewickFile - creates a newick-formatted file using the neighbor
#      program from a distance matrix of genomes
############################################################################
sub getNewickFile {
    my ($matrixFile) = @_;

    ## run the neighbor program
    my $newickFile = $tmp_dir . "/newick$$.txt";
    my $cwd = "`pwd`";

    my $inFile = $tmp_dir . "/infile";
    my $treeFile = $tmp_dir . "/tree$$.txt";

    my $neighbor_bin = $env->{neighbor_bin};

    my $tmpDir = $cgi_tmp_dir."/neighbor$$";
    my $logFile = "$tmpDir/logfile";
    WebUtil::unsetEnvPath();

    runCmd( "/bin/mkdir -p $tmpDir" );
    runCmd( "/bin/cp $matrixFile $tmpDir/infile" );
    runCmd( "/bin/chmod 777 $tmpDir" );

    chdir( $tmpDir );
    my $cmd = "/bin/echo Y | $neighbor_bin > logfile";
    my $st = system( $cmd );
    chdir( $cwd );

    if ($st == 0) {
	runCmd( "/bin/cp $tmpDir/outfile $treeFile" );
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
    return $newickFile;
}

############################################################################
# printAptxApplet - creates the applet with the specified phyloXML file
############################################################################
sub printAptxApplet {
    my( $treeFile, $type ) = @_;

    my $configFile = $tmp_dir . "/aptx$$.config";
    my $jnlpEFile = $tmp_dir . "/aptxE$$.jnlp";
    my $jnlpAFile = $tmp_dir . "/aptxA$$.jnlp";
    runCmd( "/bin/cp $cgi_dir/aptx.txt $configFile" );
    runCmd( "/bin/cp $cgi_dir/jnlpE.txt $jnlpEFile" );
    runCmd( "/bin/cp $cgi_dir/jnlpA.txt $jnlpAFile" );
    runCmd( "/bin/cp $base_dir/forester.jar $tmp_dir/forester.jar" );

    my $url1 = "$cgi_url/$main_cgi?section=TaxonDetail"
	. "&page=taxonDetail&taxon_oid=";
    my $url2 = "$cgi_url/$main_cgi?section=GeneDetail"
	. "&page=geneDetail&gene_oid=";
    my $url3 = "$cgi_url/$main_cgi?section=GeneCartStor"
	. "&page=showGeneCart&genes=";

    my $afh = newAppendFileHandle( $configFile, "runTree" );
    #print $afh "\nweb_link: ".$url1."\timg\timg\n";

    if ($type eq "domains") {
	print $afh "\n#  Additional parameters for IMG domains:\n";
	print $afh "#  --------------------------------------\n";
	print $afh "web_link: ".$url2."\timgDomains\timgDomains\n";
	print $afh "web_link: ".$url3."\timgGenes\timgGenes\n";
	print $afh "phylogeny_graphics_type:       rectangular\n";
	print $afh "show_domain_architectures:     display   yes\n";
	print $afh "show_gene_names:               display   no\n";
	print $afh "show_sequence_acc:             display   no\n";
	print $afh "show_taxonomy_code:            display   yes\n";
	print $afh "show_taxonomy_names:           display   no\n";
	print $afh "display_color:                 background   0x000000\n";
    } elsif ($type eq "genes") {
        print $afh "\n#  Additional parameters for IMG genes:\n";
        print $afh "#  --------------------------------------\n";
	print $afh "web_link: ".$url2."\timgDomains\timgDomains\n";
        print $afh "web_link: ".$url3."\timgGenes\timgGenes\n";
    } else {
	print $afh "\nweb_link: ".$url1."\timg\timg\n";
    }
    close $afh;

    WebUtil::resetEnvPath();

    print qq{
        <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
        </script>

        <script language='JavaScript' type='text/javascript'>
        function showAptx(type, base_url, num, treefile) {
	    var html =
		'<p><APPLET code="org.forester.archaeopteryx.ArchaeopteryxA.class" '+
		'archive="'+base_url+'/tmp/forester.jar" '+
		'codebase="'+base_url+'" '+
		'jnlp_href="'+base_url+'/tmp/aptxA'+num+'.jnlp" '+
		'width="200" height="40"> '+
                '<param name="java_arguments" value="-Xmx256m"> '+
                '<param name="url_of_tree_to_load" '+
		'value="'+treefile+'"> '+
                '<param name="config_file" '+
		'value="'+base_url+'/tmp/aptx'+num+'.config"> '+
                '<param name="exported_name" '+
		'value="exported'+num+'">'+
		'</APPLET></p>';

            if (type == 'aptxapplet') {
                document.getElementById('showapplet').innerHTML = html;
		document.getElementById('showapplet').style.display = 'block';
		document.getElementById('hideapplet').style.display = 'none';
	    }
        }
        </script>
    };

    print "<div id='hideapplet' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
        . " value='Launch in separate window'"
        . " onclick='showAptx(\"aptxapplet\", \"$base_url\", "
	. "\"$$\", \"$base_url/tmp/$treeFile\")' />";
    print "</div>\n";

    print "<div id='showapplet' style='display: none;'>";
    print "</div>\n";

    print "<p>";
    #print "Use mouse wheel + SHIFT to rotate the circular tree\n<br/>";
    my $url = "$base_url/tmp/$treeFile";
    print alink($url, "View phyloXML", "_blank");
    print "</p>\n";

    # Launch applet using JNLP (Java Network Launch Protocol)
    print qq{
	<applet archive="$base_url/tmp/forester.jar"
	        code="org.forester.archaeopteryx.ArchaeopteryxE.class"
                width="800" height="600"
	        codebase="$base_url"
	        jnlp_href="$base_url/tmp/aptxE$$.jnlp">
	<param name="java_arguments" value="-Xmx256m">
        <param name="url_of_tree_to_load"
               value="$base_url/tmp/$treeFile">
        <param name="config_file"
               value="$base_url/tmp/aptx$$.config">
        <param name="exported_name"
               value="exported$$">
        </applet>
    };
}


1;
