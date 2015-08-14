###########################################################################
# MissingGenes - Module for searching for missing genes.
#
# $Id: MissingGenes.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package MissingGenes;
my $section = "MissingGenes";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use GzWrap;
use DataEntryUtil;
use FuncUtil;
use GeneCartStor;
use FuncCartStor;
use TaxonTarDir;

my $env              = getEnv();
my $main_cgi         = $env->{main_cgi};
my $section_cgi      = "$main_cgi?section=$section";
my $tmp_dir          = $env->{tmp_dir};
my $cgi_tmp_dir      = $env->{cgi_tmp_dir};
my $blast_data_dir   = $env->{blast_data_dir};
my $avagz_batch_dir  = $env->{avagz_batch_dir};
my $verbose          = $env->{verbose};
my $img_lite         = $env->{img_lite};
my $use_gene_priam   = $env->{use_gene_priam};
my $show_myimg_login = $env->{show_myimg_login};

############################################################################
# dispatch
############################################################################
sub dispatch {
    timeout( 60 * 20 );    # timeout in 20 minutes
    my $page = param("page");

    if ( $page eq 'taxonGenesWithPriam' ) {
        my $taxon_oid = param('taxon_oid');
        printGenesWithPriamInTaxon($taxon_oid);
    } elsif ( $page eq 'taxonGenesWithKO' ) {
        my $taxon_oid = param('taxon_oid');
        printGenesWithKOInTaxon($taxon_oid);
    } elsif ( paramMatch("addToGeneCart0") ) {
        # add to cart
        my @gene_oids = ();
        my @tge       = param('tax_gene_enzyme');
        my $gc        = new GeneCartStor();

        for my $t1 (@tge) {
            my ( $g1, $ec1 ) = split( /\,/, $t1 );
            push @gene_oids, ($g1);
        }
        $gc->addGeneBatch( \@gene_oids );
        $gc->printGeneCartForm( '', 1 );

    } elsif (    paramMatch("addToGeneCart2")
              || paramMatch("addToGeneCart3")
              || paramMatch("addToGeneCart4") )
    {

        # add to cart
        my @gene_oids     = ();
        my @gene_oid_hits = param("gene_oid_hit");
        my $gc            = new GeneCartStor();

        for my $t1 (@gene_oid_hits) {
            my ( $g1, $g2 ) = split( /\,/, $t1 );
            push @gene_oids, ($g1);
        }
        $gc->addGeneBatch( \@gene_oids );
        $gc->printGeneCartForm( '', 1 );

    } elsif ( paramMatch("genePriamList") ) {
        printGenePriamList();
    } elsif ( paramMatch("priamCandidatesList") ) {
        my $method_option = param('method_option');
        if ( $method_option eq 'priam' ) {
            printPriamCandidateList();
        } elsif ( $method_option eq 'both' ) {
            printCandidateList(1);
        } else {
            printCandidateList(0);
        }
    } elsif ( paramMatch("koEcCandidatesList") ) {
        my $method_option = param('method_option');
        if ( $method_option eq 'ko' ) {
            printKoEcCandidateList();
        } elsif ( $method_option eq 'both' ) {
            printCandidateList(1);
        } else {
            printCandidateList(0);
        }
    } elsif ( paramMatch("geneKOEnzymeList") ) {
        printGeneKOEnzymeList();
    } elsif ( paramMatch("candidatesList") ) {
        printCandidateList(0);
    } elsif ( paramMatch("addAssoc") ) {
        printGeneTermAssocForm();
    } elsif ( paramMatch("dbUpdateGeneTerm") ) {
        dbUpdateGeneTerm();

        # return to function profile
        my $disp_type = param('disp_type');
        if ( $disp_type eq 'kegg' ) {
            require KegMapp;
            KeggMap::printKeggMapMissingECByTaxonOid();
        } else {
            my $fc = new FuncCartStor();
            if ( $disp_type eq 'func_profile_s' ) {
                $fc->printFuncCartProfile_s();
            } else {
                $fc->printFuncCartProfile_t();
            }
        }
    } elsif ( paramMatch("similarity") ) {
        printSimilarityPage();
    } elsif ( paramMatch("addSimAssoc") ) {
        printSimGeneTermAssocForm();
    } elsif ( paramMatch("dbUpdateSimGeneTerm") ) {
        my $msg2 = dbUpdateSimGeneTerm();
        if ( !blankStr($msg2) ) {
            webError($msg2);
        }

        # return to taxon detail
        require TaxonDetail;
        TaxonDetail::printTaxonDetail();
    } elsif ( paramMatch("addMyImgEnzyme") ) {
        printMyImgGeneEnzymeForm();
    } elsif ( paramMatch("addMyGeneEnzyme") ) {
        printAddMyGeneEnzymeForm();
    } elsif ( paramMatch("dbUpdateMyImgGeneEnzyme") ) {
        dbUpdateMyImgGeneEnzyme();

        # return to function profile
        my $disp_type = param('disp_type');
        if ( $disp_type eq 'kegg' ) {
            require KeggMap;
            KeggMap::printKeggMapMissingECByTaxonOid();
        } else {
            my $fc = new FuncCartStor();
            if ( $disp_type eq 'func_profile_s' ) {
                $fc->printFuncCartProfile_s();
            } else {
                $fc->printFuncCartProfile_t();
            }
        }
    } elsif ( paramMatch("dbUpdMyGeneEnzyme") ) {
        dbUpdMyGeneEnzyme();

        # return to gene detail
        require GeneDetail;
        GeneDetail::printGeneDetail();
    } elsif ( paramMatch("dbUpdTaxonGeneKO") ) {
        dbUpdTaxonGeneKO();

        # go to MyIMG annotations
        require MyIMG;
        MyIMG::viewNewAnnotations();
    } elsif ( paramMatch("dbUpdTaxonGeneEnzyme") ) {
        dbUpdTaxonGeneEnzyme();

        # go to MyIMG annotations
        require MyIMG;
        MyIMG::viewNewAnnotations();
    } elsif ( paramMatch("findProdName") ) {
        printFindProdNamePage();
    } elsif ( paramMatch("dbAddMyImgProdName") ) {
        dbAddMyImgProdName();

        # go to MyIMG annotations
        require MyIMG;
        MyIMG::printUpdateGeneAnnotForm();
    } else {
        printCandidatesForm();
    }
}

############################################################################
# printSimilarityPage
############################################################################
sub printSimilarityPage {
    my @gene_oids = param("gene_oid");

    if ( scalar(@gene_oids) == 0 ) {
        webError("No gene was selected. Please select a gene.");
    }
    my $gene_oid = $gene_oids[0];

    my $dbh       = dbLogin();
    my $sessionId = getSessionId();

    printStatusLine( "Loading ...", 1 );

    printMainForm();
    print "<h1>Similarity Search Results</h1>\n";
    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );

    print "<h2>Candidate Gene (OID: $gene_oid): "
      . escapeHTML($product_name)
      . "</h2>\n";
    my $taxon_oid1 =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'taxon', '' );

    print hiddenVar( "gene_oid",  $gene_oid );
    print hiddenVar( "taxon_oid", $taxon_oid1 );

    my @homologRecs;
    require OtfBlast;
    printStartWorkingDiv();
    my $filterType =
      OtfBlast::genePageTopHits( $dbh, $gene_oid, \@homologRecs,
				 "", $img_lite, 1 );
    printEndWorkingDiv();

    my $count = @homologRecs;
    my $cnt1  = printSimRecords( \@homologRecs );
    #$dbh->disconnect();
    print end_form();
    printStatusLine( "$cnt1 top hits loaded.", 2 );
}

############################################################################
# printCandidatesForm - Find candidates for missing genes.
#    Fill in form.
#
# function can be ITERM or EC
############################################################################
sub printCandidatesForm {
    my $taxon_oid        = param("taxon_oid");
    my $otherTaxonOids   = param("otherTaxonOids");
    my @taxon_oids_other = split( /,/, $otherTaxonOids );

    # selected term func ID
    my $funcId = param("funcId");
    my $procId = param("procId");

    printMainForm();

    print hiddenVar( "taxon_oid",      $taxon_oid );
    print hiddenVar( "otherTaxonOids", $otherTaxonOids );
    print hiddenVar( "funcId",         $funcId );
    print hiddenVar( "procId",         $procId );

    if ( !$taxon_oid ) {
        webError("No taxon was selected. Please select a taxon.");
    }

    # all functions in the profile
    my $fc       = new FuncCartStor();
    my $selected = $fc->{selected};
    my @keys     = keys(%$selected);
    for my $i (@keys) {
        print hiddenVar( "func_id", $i );
    }

    # pathway_oid?
    my $pathway_oid = param("pathway_oid");
    if ($pathway_oid) {
        print hiddenVar( "pathway_oid", $pathway_oid );
    }
    my $map_id = param("map_id");
    if ($map_id) {
        print hiddenVar( "map_id", $map_id );
    }

    my $dbh = dbLogin();

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $tag, $term_oid ) = split( /:/, $funcId );
    my $func_name = "";
    if ( $tag eq 'ITERM' ) {
        $func_name = termOid2Term( $dbh, $term_oid );
    } elsif ( $tag eq 'EC' ) {
        $func_name = enzymeName( $dbh, $funcId );
    }

    print "<h1>Find Candidate Genes for Missing Function</h1>";
    my $url = 
        "$main_cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink($url, $taxon_name); 
    print "<b>$link</b>";

    my %lineage = db_getLineage( $dbh, $taxon_oid );
    print "<p>" . $lineage{'lineage'} . "</p>\n";

    print "<h2>Function: ($funcId) " . escapeHTML($func_name) . "</h2>\n";
    my $roi_label = param('roi_label');
    my $match_ko = "";
    if ( $roi_label ) {
	print hiddenVar( "roi_label",  $roi_label );
	$match_ko = 'KO:' . $roi_label;
    }
    if ( $funcId =~ /^EC/ ) {
	## show KO too
	my $sql2 = "select k.ko_id, k.ko_name, k.definition from ko_term k, ko_term_enzymes kte where kte.enzymes = ? and kte.ko_id = k.ko_id";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $funcId );
	for (;;) { 
	    my ($ko2, $name2, $def2) = $cur2->fetchrow();
	    last if ! $ko2; 

	    if ( $match_ko && ($match_ko ne $ko2) ) {
		next;
	    }
	    print "<p>$ko2 ($name2): $def2\n";
	}
	$cur2->finish(); 
    }

    # list options
    print "<p>\n";
    print "<input type='radio' name='method_option' value='homolog' ";
    if ( !$use_gene_priam ) {
        print "checked";
    }
    print "/> Using Homologs";
    if ( !$img_lite ) {
        print " or Orthologs<br/>\n";
    } else {
        print "<br/>\n";
    }
    print "<input type='radio' name='method_option' value='ko' "
      . "/> Using KO<br/>\n";
    print "<input type='radio' name='method_option' value='both' "
      . "checked/> Using Both<br/>\n";
    print "</p>\n";

    my $name = "_section_${section}_koEcCandidatesList";
    print submit(
                  -name  => $name,
                  -value => "Go",
                  -class => "smdefbutton"
    );

    #    else {
    #	print hiddenVar("method_option", "homolog");

    #	print "</p>\n";
    #	my $name = "_section_${section}_candidatesList";
    #	print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    #    }

    print nbsp(1);
    print reset( -class => "smbutton" );
    print "<br/>\n";
    print "<hr>\n";

    if ($img_lite) {
        print "<h4>Using Homologs</h4>\n";
    } else {
        print "<h4>Using Homologs or Orthologs</h4>\n";
    }

    print "<p>\n";
    print "This tool allows you to find genes associated with\n";
    if ( $tag eq 'ITERM' ) {
        print "IMG terms";
    } elsif ( $tag eq 'EC' ) {
        print "enzymes";
    }
    print " through homologs in other genomes.<br/>\n";
    print "Homologs from the query genome <i>"
      . escHtml($taxon_name)
      . "</i><br/>";
    print "has homologs in other genomes associated with <i>$funcId</i>.<br/>";
    print "These homologs have a reciprocal hits ";
    print "in the query genome,\n";
    print "which are listed as candidates for ";
    if ( $tag eq 'ITERM' ) {
        print "gene-term association.<br/>\n";
    } elsif ( $tag eq 'EC' ) {
        print "gene-enzyme association.<br/>\n";
    }
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    printOptionLabel("Database Search Options");

    my $check2 = "";
    if ($pathway_oid) {

        # no profile
        $check2 = "checked";
    } else {
        print "<input type='radio' name='database' "
	    . "value='profileTaxons' checked/>\n";
        print "Genomes in profile only (fast)<br/>\n";
    }
    print "<input type='radio' name='database' value='currSelect' $check2/>\n";
    print "Currently selected genomes (fast)<br/>\n";
    print "<input type='radio' name='database' value='all' />\n";
    print "Whole database (slow)<br/>\n";

    # add new selection based on taxon lineage
    for my $s1 ( 'domain', 'phylum', 'ir_class', 'ir_order', 'family',
	'genus' ) {
        my $val1 = $lineage{$s1};
        if ( $val1 && $val1 ne 'unclassified' ) {
            print "<input type='radio' name='database' value='$s1' />\n";
            print escapeHTML($val1) . "<br/>\n";
        }
    }
    print "</p>\n";

    if ($img_lite) {
        print hiddenVar( "sims", "homologs" );
    } else {
        print "<p>\n";
        printOptionLabel("Similarities");
        print "<input type='radio' name='sims' value='orthologs' checked/>\n";
        print "Orthologs (bi-directional best hits) (fast)<br/>\n";
        print "<input type='radio' name='sims' value='homologs' />\n";
        print "Homologs (slow for whole database)<br/>\n";
        print "</p>\n";
    }

    print "<p>\n";
    printOptionLabel("Percent Identity Cutoff");
    print nbsp(2);
    print popup_menu(
                      -name    => "minPercIdent",
                      -values  => [ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 ],
                      -default => 30
    );
    print "</p>\n";

    print "<p>\n";
    printOptionLabel("E-value cutoff");
    print nbsp(2);
    print popup_menu(
              -name   => "maxEvalue",
              -values => [ "1e-1", "1e-2", "1e-5", "1e-10", "1e-50", "1e-100" ],
              -default => "1e-2"
    );
    print "</p>\n";

    print "<p>\n";
    printOptionLabel("Maximum Homologs");
    print nbsp(2);
    print popup_menu( -name   => "maxHits",
                      -values => [ 100, 200, 500, 1000, 5000 ] );
    print "</p>\n";

    print "<hr>\n";
    print "<h4>Using KO</h4>\n";

    print "<p>\n";
    printOptionLabel("Percent Identity Cutoff");
    print nbsp(2);
    print popup_menu(
                      -name    => "koEcMinPercIdent",
                      -values  => [ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 ],
                      -default => 10
    );
    print "</p>\n";

    print "<p>\n";
    printOptionLabel("E-value cutoff");
    print nbsp(2);
    print popup_menu(
              -name   => "koEcMaxEvalue",
              -values => [ "1e-1", "1e-2", "1e-5", "1e-10", "1e-50", "1e-100" ],
              -default => "1e-2"
    );
    print "</p>\n";

    print "<p>\n";
    printOptionLabel("Bit-score cutoff");
    print nbsp(2);
    print popup_menu(
                      -name    => "koEcBitScore",
                      -values  => [ "0", "100", "1000", "10000", "20000" ],
                      -default => "0"
    );
    print "</p>\n";

    print "<p>\n";
    printOptionLabel("Percent Alignment Cutoff");
    print nbsp(2);
    print popup_menu(
                      -name    => "koEcMinPercSAlign",
                      -values  => [ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 ],
                      -default => 10
    );
    print "</p>\n";

    print end_form();
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# printOptionLabel
############################################################################
sub printOptionLabel {
    my ( $s, $footnote ) = @_;
    print "<b>";
    print "<font color='blue'>";
    print "$s";
    print "</font>";
    print "</b>";
    if ( $footnote ne "" ) {
        print "<sup>$footnote</sup>\n";
    }
    print ":<br/>\n";
}

############################################################################
# printCandidateList - Show list of candidates.
############################################################################
sub printCandidateList {
    my ($with_candidate_enzymes) = @_;

    my $sims = param("sims");

    if ( $sims eq "orthologs" ) {
        printOrthologCandidates($with_candidate_enzymes);
    } else {
        printHomologCandidates($with_candidate_enzymes);
    }
}

############################################################################
# printOrthologCandidates
############################################################################
sub printOrthologCandidates {
    my ($with_ko_ec) = @_;

    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId       = param("funcId");
    my $procId       = param("procId");
    my $database     = param("database");
    my $minPercIdent = param("minPercIdent");
    my $maxEvalue    = param("maxEvalue");
    my $maxHits      = param("maxHits");
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    print "<h1>Candidate Genes for Missing Function</h1>\n";

    my $dbh       = dbLogin();
    my $func_name = "";
    if ( $tag eq 'ITERM' ) {
        $func_name = termOid2Term( $dbh, $term_oid );
    } elsif ( $tag eq 'EC' ) {
        $func_name = enzymeName( $dbh, $funcId );
    }

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h3>Genome: " . escapeHTML($taxon_display_name) . "</h3>\n";
    print "<h3>Function: ($funcId) " . escapeHTML($func_name) . "</h3>\n";

    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "taxon_oid",      $taxon_oid );
    print hiddenVar( "otherTaxonOids", $otherTaxonOids );
    print hiddenVar( "funcId",         $funcId );
    print hiddenVar( "procId",         $procId );
    print hiddenVar( "minPercIdent",   $minPercIdent );
    print hiddenVar( "maxEvalue",      $maxEvalue );
    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    # pathway_oid?
    my $pathway_oid = param("pathway_oid");
    if ($pathway_oid) {
        print hiddenVar( "pathway_oid", $pathway_oid );
    }
    my $map_id = param("map_id");
    if ($map_id) {
        print hiddenVar( "map_id", $map_id );
    }

    my $taxonClause;
    $taxonClause = "and g2.taxon in( $otherTaxonOids )"
      if $otherTaxonOids ne "" && $database ne "all";
    $taxonClause = txsClause("g2.taxon", $dbh) if $database eq "all";
    my @bindList_txs = ();
    if (    $database eq 'domain'
         || $database eq 'phylum'
         || $database eq 'ir_class'
         || $database eq 'ir_order'
         || $database eq 'family' 
         || $database eq 'genus' )
    {
        my %lineage = db_getLineage( $dbh, $taxon_oid );
        if ( $lineage{$database} ) {
            my $val = $lineage{$database};
            $taxonClause = " and tx2.$database = ? ";
            push( @bindList_txs, $val );
        }
    }

    my $sql = "";
    my @binds = ();
    if ( $tag eq 'ITERM' ) {
        my $rclause   = WebUtil::urClause('tx2');
        my $imgClause = WebUtil::imgClause('tx2');
        $sql = qq{
            select g1.gene_oid, g1.gene_display_name, g1.aa_seq_length,
                g2.gene_oid, g2.gene_display_name, g2.aa_seq_length,
                tx2.taxon_oid, tx2.taxon_display_name,
                tx2.domain, tx2.seq_status,
                go.percent_identity, go.bit_score, go.evalue,
	        go.query_start, go.query_end,
	        go.subj_start, go.subj_end
            from gene g1, gene_orthologs go, gene g2, taxon tx2,
                gene_img_functions gif2
            where g1.gene_oid = go.gene_oid
                and go.ortholog = g2.gene_oid
                and go.query_taxon = ?
                and g2.taxon = tx2.taxon_oid
                and g2.gene_oid = gif2.gene_oid
                and g1.taxon = ?
                and gif2.function = ?
                and go.percent_identity >= ?
                and go.evalue <= ?
                $taxonClause   
                $rclause
                $imgClause
        };
	     @binds = ($taxon_oid, $taxon_oid, $term_oid, $minPercIdent, $maxEvalue);
    } elsif ( $tag eq 'EC' ) {
        my $rclause   = WebUtil::urClause('tx2');
        my $imgClause = WebUtil::imgClause('tx2');
        $sql = qq{
            select g1.gene_oid, g1.gene_display_name, g1.aa_seq_length,
                g2.gene_oid, g2.gene_display_name, g2.aa_seq_length,
                tx2.taxon_oid, tx2.taxon_display_name,
                tx2.domain, tx2.seq_status,
                go.percent_identity, go.bit_score, go.evalue,
                go.query_start, go.query_end,
                go.subj_start, go.subj_end
            from gene g1, gene_orthologs go, gene g2, taxon tx2,
                gene_ko_enzymes ge
            where g1.gene_oid = go.gene_oid
                and go.ortholog = g2.gene_oid
                and go.query_taxon = ?
                and g2.taxon = tx2.taxon_oid
                and g2.gene_oid = ge.gene_oid
                and g1.taxon = ?
                and ge.enzymes = ?
                and go.percent_identity >= ?
                and go.evalue <= ?
                $taxonClause
                $rclause
                $imgClause
        };
	@binds = ($taxon_oid, $taxon_oid, $funcId, $minPercIdent, $maxEvalue);
    } else {
        #$dbh->disconnect();
        return;
    }
    if (scalar(@bindList_txs) > 0) {
        push (@binds, @bindList_txs);     
    }

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my @recs;
    my $count = 0;
    for ( ; ; ) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = $cur->fetchrow();
        last if !$gene_oid1;
        last if $count > $maxHits;

        $count++;
        my $r;
        $r .= "$gene_oid1\t";
        $r .= "$gene_display_name1\t";
        $r .= "$aa_seq_length1\t";
        $r .= "$gene_oid2\t";

        #$r .= "$gene_display_name2\t";
        $r .= "$func_name\t";
        $r .= "$aa_seq_length2\t";
        $r .= "$taxon_oid2\t";
        $r .= "$taxon_display_name2\t";
        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        $r .= "$percent_identity\t";
        $r .= "$bit_score\t";
        $r .= "$evalue\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        push( @recs, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    # ko?
    if ($with_ko_ec) {
        my @ko_ec_recs = getKoEcRecords();
        my $count_h    = @recs;
        my $count_p    = @ko_ec_recs;
        my $cnt1       =
	    printRecordsWithKoEc( "Ortholog", $tag, \@recs, \@ko_ec_recs );
        print end_form();
        printStatusLine
	    ( "$cnt1 distinct hits loaded. "
	      . "($count_h total orthologs hits; $count_p KO hits)", 2 );
    } else {
        my $cnt1 = printRecords( "Ortholog", $tag, \@recs );

        print end_form();
        printStatusLine
	    ( "$cnt1 distinct hits loaded. ($count total hits)", 2 );
    }
}

############################################################################
# printHomologCandidates
############################################################################
sub printHomologCandidates {
    my ($with_ko_ec) = @_;

    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId           = param("funcId");
    my $procId           = param("procId");
    my $database         = param("database");
    my $minPercIdent     = param("minPercIdent");
    my $maxEvalue        = param("maxEvalue");
    my $maxHits          = param("maxHits");
    my $koEcMinPercIdent = param("koEcMinPercIdent");
    my $koEcMaxEvalue    = param("koEcMaxEvalue");
    my $koEcBitScore     = param("koEcBitScore");
    my $koEcMinPercAlign = param("koEcMinPercSAlign");
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    print "<h1>Candidate Genes for Missing Function</h1>\n";

    my $dbh             = dbLogin();
    my $func_name       = "";
    my $taxon_func_cond = "";
    my @bindList_cond = ();
    if ( $tag eq 'ITERM' ) {
        $func_name       = termOid2Term( $dbh, $term_oid );
        $taxon_func_cond = qq{
	     and tx.taxon_oid in
		 (select distinct gif.taxon
			 from gene_img_functions gif
			 where gif.function = ? )
	     };
	     push(@bindList_cond, $term_oid);
    } elsif ( $tag eq 'EC' ) {
        $func_name       = enzymeName( $dbh, $funcId );
        $taxon_func_cond = qq{
	     and tx.taxon_oid in
		 (select distinct ge.taxon
			 from gene_ko_enzymes ge
			 where ge.enzymes = ? )
	     };
         push(@bindList_cond, $funcId);
    }

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );
    print "<h3>Genome: " . escapeHTML($taxon_display_name) . "</h3>\n";
    print "<h3>Function: ($funcId) " . escapeHTML($func_name) . "</h3>\n";

    my $roi_label = param('roi_label');
    my $match_ko = "";
    if ( $roi_label ) {
	print hiddenVar( "roi_label",  $roi_label );
	$match_ko = 'KO:' . $roi_label;
    }
    if ( $funcId =~ /^EC/ ) {
	## show KO too
	my $sql2 = "select k.ko_id, k.ko_name, k.definition from ko_term k, ko_term_enzymes kte where kte.enzymes = ? and kte.ko_id = k.ko_id";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $funcId );
	for (;;) { 
	    my ($ko2, $name2, $def2) = $cur2->fetchrow();
	    last if ! $ko2; 

	    if ( $match_ko && ($match_ko ne $ko2) ) {
		next;
	    }
	    print "<p>$ko2 ($name2): $def2\n";
	}
	$cur2->finish(); 
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "otherTaxonOids",   $otherTaxonOids );
    print hiddenVar( "funcId",           $funcId );
    print hiddenVar( "procId",           $procId );
    print hiddenVar( "minPercIdent",     $minPercIdent );
    print hiddenVar( "maxEvalue",        $maxEvalue );
    print hiddenVar( "koEcMinPercIdent", $koEcMinPercIdent );
    print hiddenVar( "koEcMaxEvalue",    $koEcMaxEvalue );
    print hiddenVar( "koEcBitScore",     $koEcBitScore );
    print hiddenVar( "koEcMinPercAlign", $koEcMinPercAlign );
    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    # pathway_oid?
    my $pathway_oid = param("pathway_oid");
    if ($pathway_oid) {
        print hiddenVar( "pathway_oid", $pathway_oid );
    }
    my $map_id = param("map_id");
    if ($map_id) {
        print hiddenVar( "map_id", $map_id );
    }

    my @taxon_oids;
    if ( $database eq "profileTaxons" && $otherTaxonOids ne "" ) {
        @taxon_oids = split( /,/, $otherTaxonOids );
    } elsif ( $database eq "currSelect" ) {
        ## Try user selections first
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
            select dt.id, tx.taxon_display_name
            from gtt_taxon_oid dt, taxon tx
            where dt.id = tx.taxon_oid
                $taxon_func_cond 
                $rclause
                $imgClause
            order by tx.taxon_display_name
	};

	# Read genome cart text file and insert into Oracle temp file
	require GenomeCart;
	GenomeCart::insertToGtt($dbh);
	
	my @bindList;
	if (scalar(@bindList_cond) > 0) {
	    push (@bindList, @bindList_cond);
	}

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;

            push( @taxon_oids, $taxon_oid );
        }
        $cur->finish();

        if ( scalar(@taxon_oids) == 0 ) {
            printStatusLine( "Error!", 2 );
            webError("No taxons were selected. Please select other options.");
        }
    } else {
        my @bindList = ();
        # whole database or taxon lineage selection
        my $lineage_cond = 
	    "tx.domain in( 'Bacteria', 'Archaea', 'Eukaryota' )";
        if ( $database ne 'all' ) {
            my %lineage = db_getLineage( $dbh, $taxon_oid );
            if ( $lineage{$database} ) {
                my $val = $lineage{$database};
                $lineage_cond = "tx.$database = ? ";
                push (@bindList, $val);
            }
        }

        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql = qq{
            select tx.taxon_oid, tx.taxon_display_name
            from taxon tx
            where $lineage_cond
                $taxon_func_cond
                $rclause
                $imgClause
            order by tx.taxon_display_name
        };
        if (scalar(@bindList_cond) > 0) {
            push (@bindList, @bindList_cond);
        }

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;
            push( @taxon_oids, $taxon_oid );
        }
        $cur->finish();
    }

    my @recs;
    printStartWorkingDiv();
    my $merfs_timeout_mins = $env->{merfs_timeout_mins};
    if ( ! $merfs_timeout_mins ) {
	$merfs_timeout_mins = 60;
    } 
    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = ""; 

    for my $taxon_oid2 (@taxon_oids) {
	if ( ( ( $merfs_timeout_mins * 60 ) - 
	       ( time() - $start_time ) ) < 60 ) {
	    $timeout_msg = 
		"Process takes too long to run " 
		. "-- stopped before genome $taxon_oid2. " 
		. "Only partial result is displayed."; 
	    last; 
	} 

        if ( $tag eq 'ITERM' ) {
            getHomologs( $dbh, $taxon_oid, $taxon_oid2, $funcId, $minPercIdent,
                         $maxEvalue, $maxHits, \@recs );
        } elsif ( $tag eq 'EC' ) {
            getHomologs_EC( $dbh, $taxon_oid, $taxon_oid2, $funcId,
                            $minPercIdent, $maxEvalue, $maxHits, \@recs );
        }
    }

    printEndWorkingDiv();
    if ( $timeout_msg ) {
	print "<p><font color='red'>Warning: " . $timeout_msg .
	    "</font>\n";
    }

    #$dbh->disconnect();

    # KO
    if ($with_ko_ec) {
        my @ko_ec_recs = getKoEcRecords();
        my $count_h    = @recs;
        my $count_p    = @ko_ec_recs;
        my $cnt1       =
          printRecordsWithKoEc( "Homolog", $tag, \@recs, \@ko_ec_recs );
        print end_form();
        printStatusLine(
"$cnt1 distinct hits loaded. ($count_h total homologs hits; $count_p KO hits)",
            2
        );
    } else {
        my $count = @recs;
        my $cnt1 = printRecords( "Homolog", $tag, \@recs );
        print end_form();
        printStatusLine( "$cnt1 distinct hits loaded. ($count total hits)", 2 );
    }
}

############################################################################
# getGeneHomologs - Get list of homologs for gene_oid
############################################################################
sub getGeneHomologs {
    my ( $dbh, $gene_oid, $taxon_oid1, $taxon_oid2, $minPercIdent, $maxEvalue,
         $maxHits, $recs_ref )
      = @_;

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid2 );

    my $sql = qq{
        select gif.gene_oid
    	from gene_img_functions gif
    	where gif.taxon = ?
    	minus select gene_oid from gene_fusion_components
    };
    my %subjGeneHasTerm;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid2 );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;

        $subjGeneHasTerm{$gene_oid} = 1;
    }
    $cur->finish();

#    my $fpath =
#      "$avagz_batch_dir/" . "$taxon_oid1/$taxon_oid1-$taxon_oid2.m8.txt.gz";
#    if ( -e $fpath ) {
#
#        # fine
#    } else {
#        print "0 hits found for <i>" . escHtml($taxon_name) . "</i>";
#        print "<br/>\n";
#        return;
#    }

#    my $rfh = newReadGzFileHandle( $fpath, "getGeneHomologs" );
#    if ( !$rfh ) {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }

    my @recs;
    my $count = 0;
#    while ( my $s = $rfh->getline() ) {
#        chomp $s;
    my @rows;
    TaxonTarDir::getGenomePairData( $taxon_oid1, $taxon_oid2, \@rows );
    my $nRows = @rows;
    if( $nRows == 0 ) {
        print "0 hits found for <i>" . escHtml( $taxon_name ) . "</i><br/>\n";
	return;
    }
    for my $s( @rows ) {
        my (
             $qid,       $sid,   $percIdent, $alen,
             $nMisMatch, $nGaps, $qstart,    $qend,
             $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $s );
        next if $evalue > $maxEvalue;
        next if $percIdent < $minPercIdent;
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        # check query gene oid
        if ( $qgene_oid > $gene_oid ) {
            last;
        } elsif ( $qgene_oid != $gene_oid ) {
            next;
        }

        #next if $queryGeneHasTerm{ $qgene_oid };
        next if !$subjGeneHasTerm{$sgene_oid};

        #	next if !reciprocalHit(
        #	    $taxon_oid2, $sid, $taxon_oid1, $qid,
        #	       $minPercIdent, $maxEvalue );
        $count++;
        my $sql = qq{
	    select g.gene_display_name
	    from gene g
	    where g.gene_oid = ?
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $qgene_oid );
        my ($gene_display_name1) = $cur->fetchrow();
        $cur->finish();

        #
        my $sql = qq{
	    select g.gene_display_name, 
	       tx.taxon_oid, tx.taxon_display_name,
	       tx.domain, tx.seq_status, it.term_oid, it.term
	    from gene g, taxon tx, gene_img_functions gif, img_term it
	    where g.gene_oid = ?
	    and gif.gene_oid = g.gene_oid
	    and gif.function = it.term_oid
	    and g.taxon = tx.taxon_oid
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $sgene_oid );
        my ( $gene_display_name2, $taxon_oid2, $taxon_display_name2, $domain2,
             $seq_status2, $term_oid2, $term2 )
          = $cur->fetchrow();
        #$cur->finish();
        my $nRecs = @$recs_ref;
        if ( $nRecs > $maxHits ) {
            last;
        }
        my $r;
        $r .= "$qgene_oid\t";
        $r .= "$gene_display_name1\t";
        $r .= "$qlen\t";
        $r .= "$sgene_oid\t";

        #$r .= "$gene_display_name2\t";
        $r .= "$term_oid2\t";
        $r .= "$term2\t";
        $r .= "$slen\t";
        $r .= "$taxon_oid2\t";
        $r .= "$taxon_display_name2\t";
        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        $r .= "$percIdent\t";
        $r .= "$bitScore\t";
        $r .= "$evalue\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        push( @$recs_ref, $r );
    }
#    $rfh->close();
    print "<font color='red'>" if $count > 0;
    print "$count hits found for <i>" . escHtml($taxon_name) . "</i>";
    print "</font>" if $count > 0;
    print "<br/>\n";
}

############################################################################
# printSimRecords - Print similarity records of output.
#
# (only allow single selection)
############################################################################
sub printSimRecords {
    my ($recs_ref) = @_;

    my $ortho_homo = "Homolog";

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "$ortho_homo Gene",     "number asc",  "left" );
    $it->addColSpec( "IMG Term OID",         "number asc",  "left" );
    $it->addColSpec( "IMG Term",             "char asc",    "left" );
    $it->addColSpec( "Domain",               "char asc",    "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",               "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",               "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec( "Alignment<br/>On<br/>Candidate");
    $it->addColSpec( "Alignment<br/>On<br/>$ortho_homo");
    $it->addColSpec( "E-value",              "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score",        "number desc", "right" );
    my $sd  = $it->getSdDelim();
    my $cnt = 0;
    my $dbh = dbLogin();
    my %term_h;

    # get the highest score N hits
    my $get_top_n = 1;
    my $top_n     = 20;
    my $min_score = 0;
    my %gene_score;
    if ($get_top_n) {
        for my $r0 (@$recs_ref) {
            my (
                 $gene_oid1,        $gene_oid2,   $taxon_oid2,
                 $percent_identity, $query_start, $query_end,
                 $subj_start,       $subj_end,    $evalue,
                 $bit_score,        $align_length
              )
              = split( /\t/, $r0 );
            next if $gene_oid1 == $gene_oid2;

            my $term_cnt =
              db_findCount( $dbh, 'gene_img_functions',
                            "gene_oid = ?", $gene_oid2 );
            if ( $term_cnt == 0 ) {

                # gene has no terms
                next;
            }

            if ( $gene_score{$bit_score} ) {
                my $cnt0 = $gene_score{$bit_score};
                $gene_score{$bit_score} = $cnt0 + 1;
            } else {
                $gene_score{$bit_score} = 1;
            }
        }

        sub reverse_num { $b <=> $a; }
        my @scores = sort reverse_num ( keys %gene_score );
        for my $key (@scores) {
            if ( $cnt >= $top_n ) {
                last;
            }

            $cnt += $gene_score{$key};
            $min_score = $key;
        }
    }

    $cnt = 0;
    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,        $gene_oid2,   $taxon_oid2,
             $percent_identity, $query_start, $query_end,
             $subj_start,       $subj_end,    $evalue,
             $bit_score,        $align_length
          )
          = split( /\t/, $r0 );
        next if $gene_oid1 == $gene_oid2;

        if ( $get_top_n && $bit_score < $min_score ) {
            next;
        }

        my @term_oids =
          db_findSetVal( $dbh, 'gene_img_functions', 'gene_oid', $gene_oid2,
                         'function', '' );
        if ( scalar(@term_oids) == 0 ) {
            # gene has no terms
            next;
        }

        my $all_term_oids = "";
        for my $term_oid2 (@term_oids) {
            if ( length($all_term_oids) == 0 ) {
                $all_term_oids = $term_oid2;
            } else {
                $all_term_oids .= "," . $term_oid2;
            }
        }

        my $domain2     = "";
        my $seq_status2 = "";

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $domain2 = substr( $domain2, 0, 1 );
        $seq_status2 = substr( $seq_status2, 0, 1 );
        $bit_score = sprintf( "%d", $bit_score );
        my $sel_type = 'checkbox';
        my $r;
        $r .=
            "$sd<input type='"
          . $sel_type
          . "' name='gene_oid_hit' "
          . "value='$gene_oid1,$gene_oid2,$all_term_oids' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid2";
        $r   .= $gene_oid2 . $sd . alink( $url, $gene_oid2 ) . "\t";
        # term oid and terms
        my $cell_sort    = "";
        my $cell_display = "";
        my $term_names    = "";
        for my $term_oid2 (@term_oids) {
            $term_oid2 = FuncUtil::termOidPadded($term_oid2);
            my $url2   = FuncUtil::getUrl( $main_cgi, 'IMG_TERM', $term_oid2 );
            $cell_sort    .= $term_oid2;
            $cell_display .= ", " if ($cell_display ne "");
            $cell_display .= alink( $url2, $term_oid2 );

            my $t2;
            if ( $term_h{$term_oid2} ) {
                $t2 = $term_h{$term_oid2};
            } else {
                $t2 = db_findVal( $dbh, 'img_term', 'term_oid', 
                         $term_oid2, 'term', '' );
                $term_h{$term_oid2} = $t2;
            }
            if ( length($term_names) == 0 ) {
                $term_names = $t2;
            } else {
                $term_names .= " | " . $t2;
            }
        }
        $r .= $cell_sort . $sd . $cell_display . "\t";
        $r .= "$term_names\t";

        my $sql2 = qq{
	     select t.taxon_name, substr(t.domain, 0, 1),
	     substr(t.seq_status, 0, 1)
		 from taxon t, gene g
		 where g.gene_oid = ?
		 and g.taxon = t.taxon_oid
	     };
        my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid2 );
        my ( $taxon_display_name2, $domain2, $seq_status2 )
	    = $cur2->fetchrow();

        $r .= "$domain2\t";
        $r .= "$seq_status2\t";

        my $aa_seq_length1 = geneOid2AASeqLength( $dbh, $gene_oid1 );
        my $aa_seq_length2 = geneOid2AASeqLength( $dbh, $gene_oid2 );

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid2";
        $r   .=
          $taxon_display_name2 . $sd
          . alink( $url, $taxon_display_name2 ) . "\t";

        $r .= "$percent_identity\t";
        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .=
          $sd . alignImage( $subj_start, $subj_end, $aa_seq_length2 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    WebUtil::printButtonFooter();

    $it->printOuterTable(1);

    my $name = "_section_${section}_addSimAssoc";

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    if ( canEditGeneTerm( $dbh, $contact_oid ) ) {
        print submit(
                      -name  => $name,
                      -value => "Add Term to Candidate Gene",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    WebUtil::printButtonFooter() if ( $cnt > 10 );

    return $cnt;
}

############################################################################
# printSimGeneTermAssocForm
############################################################################
sub printSimGeneTermAssocForm {

    printMainForm();

    print "<h1>Add Term to Candidate Gene</h1>\n";

    printStatusLine( "Loading ...", 1 );

    print "<p>\n";

    my $gene_oid      = param("gene_oid");
    my @gene_oid_hits = param("gene_oid_hit");
    my @term_oids     = ();
    for my $hit (@gene_oid_hits) {
        my ( $gene_oid1, $gene_oid2, @term_arr ) = split( /,/, $hit );
        for my $term_oid2 (@term_arr) {
            if ( ! WebUtil::inIntArray( $term_oid2, @term_oids ) ) {
                push @term_oids, ($term_oid2);
            }
        }
    }
    if ( scalar(@term_oids) == 0 ) {
        webError("No terms were selected. Please select a term.");
    }

    my $taxon_oid    = param("taxon_oid");
    my $minPercIdent = param("minPercIdent");
    my $maxEvalue    = param("maxEvalue");

    print hiddenVar( "taxon_oid",    $taxon_oid );
    print hiddenVar( "gene_oid",     $gene_oid );
    print hiddenVar( "minPercIdent", $minPercIdent );
    print hiddenVar( "maxEvalue",    $maxEvalue );

    my $dbh = dbLogin();

    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );
    print "<h3>Candidate Gene: " . escapeHTML($product_name) . "</h3>\n";

    # get IMG terms for gene_oid
    require GeneCartDataEntry;
    my %geneTerms = GeneCartDataEntry::getGeneImgTerms( $dbh, ($gene_oid) );

    print "<p>Add/Replace?  ";
    print nbsp(3);
    my $ar_name = "ar_" . $gene_oid;
    print "  <input type='radio' name='$ar_name' value='add' checked />Add\n";
    print nbsp(1);
    my $replace_opt = "disabled";
    if ( $geneTerms{$gene_oid} ) {
        $replace_opt = " ";
    }
    print "  <input type='radio' name='$ar_name' value='replace' "
      . $replace_opt
      . "/>Replace\n";
    print "</p>\n";

    # get all cell_loc values
    my @cell_locs = (' ');
    my $sql2      = "select loc_type from CELL_LOCALIZATION order by loc_type";
    my $cur2      = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ($c_loc) = $cur2->fetchrow();
        last if !$c_loc;

        push @cell_locs, ($c_loc);
    }
    $cur2->finish();

    # add java script function 'setEvidence'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setEvidence( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^ev_/ ) ) {\n";
    print "              e.selectedIndex = x;\n";
    print "             }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Gene Display Name</th>\n";
    print "<th class='img'>Genome</th>\n";
    print "<th class='img'>Old IMG Term(s)</th>\n";
    print "<th class='img'>New IMG Term</th>\n";

    print "<th class='img'>Evidence <br/>\n";
    print "<input type='button' value='Null' Class='tinybutton'\n";
    print "  onClick='setEvidence (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Experimental' Class='tinybutton'\n";
    print "  onClick='setEvidence (1)' />\n";
    print "<br/>\n";
    print "<input type='button' value='High' Class='tinybutton'\n";
    print "  onClick='setEvidence (2)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Inferred' Class='tinybutton'\n";
    print "  onClick='setEvidence (3)' />\n";
    print "</th>\n";

    print "<th class='img'>Confidence</th>\n";
    print "<th class='img'>Cell Localization</th>\n";

    for my $term_oid (@term_oids) {
        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='term_oid' value='$term_oid' $ck/>\n";
        print "</td>\n";

        # my $tax_oid = geneOid2TaxonOid( $dbh, $gene_oid );
        my $tax_oid          = $taxon_oid;
        my $tax_display_name = taxonOid2Name( $dbh, $tax_oid );
        my $desc             = geneOid2Name( $dbh, $gene_oid );

        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML($desc) . "</td>\n";
        print "<td class='img'>" . escapeHTML($tax_display_name) . "</td>\n";

        # print old IMG terms
        if ( $geneTerms{$gene_oid} ) {
            print "<td class='img'>" . "$geneTerms{$gene_oid}" . "</td>\n";
        } else {
            print "<td class='img'>" . "" . "</td>\n";
        }

        # print new IMG term
        my $new_term = termOid2Term( $dbh, $term_oid );

        print "<td class='img'>(OID: $term_oid) "
          . escapeHTML($new_term)
          . "</td>\n";

        # print evidence
        my $ev_name = "ev_" . $gene_oid;
        print "<td class='img'>\n";
        print "  <select name='$ev_name' id='$ev_name'>\n";
        print "     <option value='Null'>Null</option>\n";
        print "     <option value='Experimental'>Experimental</option>\n";
        print "     <option value='High'>High</option>\n";
        print "     <option value='Inferred'>Inferred</option>\n";
        print "  </select>\n";
        print "</td>\n";

        # print confidence
        my $cm_name = "cm_" . $gene_oid;
        print "<td class='img'>\n";
        print
          "  <input type='text' name='$cm_name' size='20' maxLength='255'/>\n";
        print "</td>\n";

        # cell_loc
        my $cl_name = "cell_" . $gene_oid;
        print "<td class='img'>\n";
        print "  <select name='$cl_name' id='$cl_name' class='img' size='1'>\n";
        for my $c2 (@cell_locs) {
            print "    <option value='$c2' />$c2</option>\n";
        }
        print "  </select>\n";
        print "</td>\n";

        print "</tr>\n";
    }
    print "</table>\n";

    print "</p>\n";
    printHint("Click '<u>Update Database</u>' to save your change(s) to the database. Only selected gene-term associations will be updated.\n");

    print "</p>\n";
    my $name = "_section_${section}_dbUpdateSimGeneTerm";
    print submit(
                  -name  => $name,
                  -value => "Update Database",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    print reset( -class => "medbutton" );
    print "<br/>\n";
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# getHomologs - Get list of homologs between pairs of taxons.
############################################################################
sub getHomologs {
    my ( $dbh, $taxon_oid1, $taxon_oid2, $funcId, $minPercIdent, $maxEvalue,
         $maxHits, $recs_ref )
      = @_;
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid2 );

#    my $sql = qq{
#        select gif.gene_oid
#	from gene_img_functions gif, gene g
#	where gif.function = ?
#	and gif.gene_oid = g.gene_oid
#	and g.taxon = ?
#    };
#    my %queryGeneHasTerm;
#    my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $taxon_oid1 );
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        $queryGeneHasTerm{$gene_oid} = 1;
#    }
#    $cur->finish();

    my $sql = qq{
        select gif.gene_oid
    	from gene_img_functions gif
    	where gif.function = ?
    	and gif.taxon = ?
    	minus select gene_oid from gene_fusion_components
    };
    my %subjGeneHasTerm;
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $taxon_oid2 );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;

        $subjGeneHasTerm{$gene_oid} = 1;
    }
    $cur->finish();

#    my $fpath =
#      "$avagz_batch_dir/" . "$taxon_oid1/$taxon_oid1-$taxon_oid2.m8.txt.gz";
#    if ( -e $fpath ) {
#
#        # fine
#    } else {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }
#
#    my $rfh = newReadGzFileHandle( $fpath, "getHomologs" );
#    if ( !$rfh ) {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }

    my @recs;
    my $count = 0;
#    while ( my $s = $rfh->getline() ) {
#        chomp $s;
    my @rows;
    TaxonTarDir::getGenomePairData( $taxon_oid1, $taxon_oid2, \@rows );
    my $nRows = @rows;
    if( $nRows == 0 ) {
	return;
    }
    for my $s( @rows ) {
        my (
             $qid,       $sid,   $percIdent, $alen,
             $nMisMatch, $nGaps, $qstart,    $qend,
             $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $s );
        next if $evalue > $maxEvalue;
        next if $percIdent < $minPercIdent;
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        #next if $queryGeneHasTerm{ $qgene_oid };
        next if !$subjGeneHasTerm{$sgene_oid};
        next
          if !reciprocalHit( $taxon_oid2, $sid, $taxon_oid1, $qid,
                             $minPercIdent, $maxEvalue );
        $count++;
        my $sql = qq{
	    select g.gene_display_name
	    from gene g
	    where g.gene_oid = ?
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $qgene_oid );
        my ($gene_display_name1) = $cur->fetchrow();
        #$cur->finish();

        #
        my $sql = qq{
    	    select g.gene_display_name, 
    	       tx.taxon_oid, tx.taxon_display_name,
    	       tx.domain, tx.seq_status, it.term
    	    from gene g, taxon tx, gene_img_functions gif, img_term it
    	    where g.gene_oid = ?
    	    and gif.gene_oid = g.gene_oid
    	    and gif.function = it.term_oid
    	    and g.taxon = tx.taxon_oid
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $sgene_oid );
        my ( $gene_display_name2, $taxon_oid2, $taxon_display_name2, $domain2,
             $seq_status2, $term2 )
          = $cur->fetchrow();
        #$cur->finish();
        my $nRecs = @$recs_ref;
        if ( $nRecs > $maxHits ) {
            last;
        }
        my $r;
        $r .= "$qgene_oid\t";
        $r .= "$gene_display_name1\t";
        $r .= "$qlen\t";
        $r .= "$sgene_oid\t";

        #$r .= "$gene_display_name2\t";
        $r .= "$term2\t";
        $r .= "$slen\t";
        $r .= "$taxon_oid2\t";
        $r .= "$taxon_display_name2\t";
        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        $r .= "$percIdent\t";
        $r .= "$bitScore\t";
        $r .= "$evalue\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        push( @$recs_ref, $r );
    }
#    $rfh->close();
    print "<font color='red'>" if $count > 0;
    print "$count hits found for <i>" . escHtml($taxon_name) . "</i>";
    print "</font>" if $count > 0;
    print "<br/>\n";
}

############################################################################
# getHomologs_EC - Get list of homologs between pairs of taxons.
#                  (based on gene-enzyme)
############################################################################
sub getHomologs_EC {
    my ( $dbh, $taxon_oid1, $taxon_oid2, $funcId, $minPercIdent, $maxEvalue,
         $maxHits, $recs_ref )
      = @_;
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid2 );

#    my $sql = qq{
#        select ge.gene_oid
#	from gene_ko_enzymes ge, gene g
#	where ge.enzymes = ?
#	and ge.gene_oid = g.gene_oid
#	and g.taxon = ?
#    };
#    my %queryGeneHasEnzyme;
#    my $cur = execSql( $dbh, $sql, $verbose, $funcId, $taxon_oid1 );
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        $queryGeneHasEnzyme{$gene_oid} = 1;
#    }
#    $cur->finish();

    my $sql = qq{
        select ge.gene_oid
	from gene_ko_enzymes ge, gene g
	where ge.enzymes = ?
	and ge.gene_oid = g.gene_oid
	and g.taxon = ?
	minus select gene_oid from gene_fusion_components
    };

    my %subjGeneHasEnzyme;
    my $cur = execSql( $dbh, $sql, $verbose, $funcId, $taxon_oid2 );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;

        $subjGeneHasEnzyme{$gene_oid} = 1;
    }
    $cur->finish();

#    my $fpath =
#      "$avagz_batch_dir/" . "$taxon_oid1/$taxon_oid1-$taxon_oid2.m8.txt.gz";
#    if ( -e $fpath ) {
#
#        # fine
#    } else {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }
#
#    my $rfh = newReadGzFileHandle( $fpath, "getHomologs_EC" );
#    if ( !$rfh ) {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }

    my @recs;
    my $count = 0;
#    while ( my $s = $rfh->getline() ) {
#        chomp $s;
    my @rows;

    TaxonTarDir::getGenomePairData( $taxon_oid1, $taxon_oid2, \@rows );

    my $nRows = @rows;
    if( $nRows == 0 ) {
	return;
    }
    for my $s( @rows ) {
        my (
             $qid,       $sid,   $percIdent, $alen,
             $nMisMatch, $nGaps, $qstart,    $qend,
             $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $s );
        next if $evalue > $maxEvalue;
        next if $percIdent < $minPercIdent;
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        #next if $queryGeneHasEnzyme{ $qgene_oid };
        next if !$subjGeneHasEnzyme{$sgene_oid};
        next
          if !reciprocalHit( $taxon_oid2, $sid, $taxon_oid1, $qid,
                             $minPercIdent, $maxEvalue );
        $count++;
        my $sql = qq{
	    select g.gene_display_name
	    from gene g
	    where g.gene_oid = ?
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $qgene_oid );
        my ($gene_display_name1) = $cur->fetchrow();
        #$cur->finish();

        #
        my $sql = qq{
	    select g.gene_display_name, 
	       tx.taxon_oid, tx.taxon_display_name,
	       tx.domain, tx.seq_status, e.enzyme_name
	    from gene g, taxon tx, gene_ko_enzymes ge, enzyme e
	    where g.gene_oid = ?
	    and ge.gene_oid = g.gene_oid
	    and ge.enzymes = e.ec_number
	    and g.taxon = tx.taxon_oid
	    };
        my $cur = execSql( $dbh, $sql, $verbose, $sgene_oid );
        my ( $gene_display_name2, $taxon_oid2, $taxon_display_name2, $domain2,
             $seq_status2, $term2 )
          = $cur->fetchrow();
        #$cur->finish();
        my $nRecs = @$recs_ref;
        if ( $nRecs > $maxHits ) {
            last;
        }
        my $r;
        $r .= "$qgene_oid\t";
        $r .= "$gene_display_name1\t";
        $r .= "$qlen\t";
        $r .= "$sgene_oid\t";

        #$r .= "$gene_display_name2\t";
        $r .= "$term2\t";
        $r .= "$slen\t";
        $r .= "$taxon_oid2\t";
        $r .= "$taxon_display_name2\t";
        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        $r .= "$percIdent\t";
        $r .= "$bitScore\t";
        $r .= "$evalue\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        push( @$recs_ref, $r );
    }
    #$rfh->close();
    print "<font color='red'>" if $count > 0;
    print "$count hits found for <i>" . escHtml($taxon_name) . "</i>";
    print "</font>" if $count > 0;
    print "<br/>\n";
}

############################################################################
# reciprocalHit - Check for reciprocal hit.
############################################################################
sub reciprocalHit {
    my (
         $taxon_oid1, $gene_lid1,    $taxon_oid2,
         $gene_lid2,  $minPercIdent, $maxEvalue
      )
      = @_;

#    my $fpath =
#      "$avagz_batch_dir/" . "$taxon_oid1/$taxon_oid1-$taxon_oid2.m8.txt.gz";
#    if ( -e $fpath ) {
#
#        # fine
#    } else {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }
#
#    my $rfh = newReadGzFileHandle( $fpath, "getHomologs" );
#    if ( !$rfh ) {
#
#        # print "Error: File $fpath does not exist.\n<br/>\n";
#        return;
#    }

    my @recs;
    my $count = 0;
#    while ( my $s = $rfh->getline() ) {
#        chomp $s;
    my @rows;
    TaxonTarDir::getGenomePairData( $taxon_oid1, $taxon_oid2, \@rows );
    my $nRows = @rows;
    if( $nRows == 0 ) {
	return;
    }
    for my $s( @rows ) {
        my (
             $qid,       $sid,   $percIdent, $alen,
             $nMisMatch, $nGaps, $qstart,    $qend,
             $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $s );
        next if $percIdent < $minPercIdent;
        next if $evalue > $maxEvalue;
        if ( $qid eq $gene_lid1 && $sid eq $gene_lid2 ) {
            webLog("Reciprocal hit found for $qid-$sid\n");
            #$rfh->close();
            return 1;
        }
    }
    #$rfh->close();
    return 0;
}

############################################################################
# printRecords - Print records of output.
############################################################################
sub printRecords {
    my ( $ortho_homo, $tag, $recs_ref ) = @_;

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Gene",         "number asc", "left" );
    $it->addColSpec( "Candidate Gene Product", "char asc",   "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for Candidate Gene", "char asc", "left" );
    }
    $it->addColSpec( "$ortho_homo Gene", "number asc", "left" );
    $it->addColSpec( "$ortho_homo Gene Product<br/>(IMG Term)",
                     "char asc", "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for $ortho_homo Gene", "char asc", "left" );
    }

    $it->addColSpec( "Domain",               "char asc",    "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",               "char asc",    "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",               "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Candidate");
    $it->addColSpec("Alignment<br/>On<br/>$ortho_homo");
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;
    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );
        if ( $gene_score{$gene_oid1} ) {

            # already has some hit. compare.
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $bit_score > $score2 ) {

                # replace
                $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
            } else {

                # keep original one
            }
        } else {

            # new one
            $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
        }
    }

    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );

        if ( $gene_score{$gene_oid1} ) {
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $g2 == $gene_oid2 ) {

                # continue output
            } else {

                # skip
                next;
            }
        } else {

            # shouldn't happen
            next;
        }

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $domain2 = substr( $domain2, 0, 1 );
        $seq_status2 = substr( $seq_status2, 0, 1 );
        $bit_score = sprintf( "%d", $bit_score );
        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$gene_oid1,$gene_oid2' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid1";
        $r   .= $gene_oid1 . $sd . alink( $url, $gene_oid1 ) . "\t";
        $r   .= "$gene_display_name1\t";

        if ( $tag eq 'EC' ) {
            my $enzyme1 = getEnzymeForGene($gene_oid1);
            $r .= "$enzyme1\t";
        }

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid2";
        $r   .= $gene_oid2 . $sd . alink( $url, $gene_oid2 ) . "\t";
        $r   .= "$gene_display_name2\t";

        if ( $tag eq 'EC' ) {
            my $enzyme2 = getEnzymeForGene($gene_oid2);
            $r .= "$enzyme2\t";
        }

        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid2";
        $r   .=
          $taxon_display_name2 . $sd
          . alink( $url, $taxon_display_name2 ) . "\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .=
          $sd . alignImage( $subj_start, $subj_end, $aa_seq_length2 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    WebUtil::printButtonFooter() if ( $cnt > 10 );

    $it->printOuterTable(1);

    print "<p>\n";

    #     my $funcId =  param( "funcId" );
    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    if ( $tag eq 'ITERM'
         && canEditGeneTerm( $dbh, $contact_oid ) )
    {
        my $name = "_section_${section}_addAssoc";
        print submit(
                      -name  => $name,
                      -value => "Add Term to Candidate Gene(s)",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
        print "\n";
    } elsif ( $tag eq 'EC' && $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyImgEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
        print "\n";
    }

    my $name = "_section_${section}_addToGeneCart2";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);
    print "\n";

    WebUtil::printButtonFooterInLine();

    print "</p>\n";

    return $cnt;
}

############################################################################
# printGenePriamList
############################################################################
sub printGenePriamList {
    my $gene_oid = param("gene_oid");

    print "<h1>Candidate Enzymes Using PRIAM</h1>\n";

    my $dbh          = dbLogin();
    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );
    #$dbh->disconnect();
    print "<h3>Gene ($gene_oid): " . escapeHTML($product_name) . "</h3>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "gene_oid", $gene_oid );

    my @recs = getGenePriamRecords($gene_oid);
    my $cnt1 = printGenePriamRecords( \@recs );

    print end_form();
    printStatusLine( "$cnt1 candidate genes found.", 2 );
}

############################################################################
# printPriamCandidateList
############################################################################
sub printPriamCandidateList {
    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId            = param("funcId");
    my $procId            = param("procId");
    my $database          = param("database");
    my $minPercIdent      = param("minPercIdent");
    my $maxEvalue         = param("maxEvalue");
    my $priamMinPercIdent = param("priamMinPercIdent");
    my $priamMaxEvalue    = param("priamMaxEvalue");
    my $priamBitScore     = param("priamBitScore");
    my $priamMinPercAlign = param("priamMinPercSAlign");
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    print "<h1>Candidate Genes for Missing Enzyme Using PRIAM</h1>\n";

    my $dbh = dbLogin();

    my $func_name = "";
    if ( $tag eq 'EC' ) {
        $func_name = enzymeName( $dbh, $funcId );
    } else {
        #$dbh->disconnect();
        webError("This function is only applicable to enzymes.");
        return;
    }

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h3>Genome: " . escapeHTML($taxon_display_name) . "</h3>\n";
    print "<h3>Function: ($funcId) " . escapeHTML($func_name) . "</h3>\n";

    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "taxon_oid",         $taxon_oid );
    print hiddenVar( "otherTaxonOids",    $otherTaxonOids );
    print hiddenVar( "funcId",            $funcId );
    print hiddenVar( "procId",            $procId );
    print hiddenVar( "minPercIdent",      $minPercIdent );
    print hiddenVar( "maxEvalue",         $maxEvalue );
    print hiddenVar( "priamMinPercIdent", $priamMinPercIdent );
    print hiddenVar( "priamMaxEvalue",    $priamMaxEvalue );
    print hiddenVar( "priamBitScore",     $priamBitScore );
    print hiddenVar( "priamMinPercAlign", $priamMinPercAlign );
    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    # pathway_oid?
    my $pathway_oid = param("pathway_oid");
    if ($pathway_oid) {
        print hiddenVar( "pathway_oid", $pathway_oid );
    }
    my $map_id = param("map_id");
    if ($map_id) {
        print hiddenVar( "map_id", $map_id );
    }

    my @recs = getPriamRecords();

    my $cnt1 = printPriamRecords( \@recs );

    #$dbh->disconnect();
    print end_form();
    printStatusLine( "$cnt1 candidate genes found.", 2 );
}

############################################################################
# printPriamRecords - Print records of output from PRIAM results
############################################################################
sub printPriamRecords {
    my ($recs_ref) = @_;

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Gene",            "number asc",  "left" );
    $it->addColSpec( "Candidate Gene Product",    "char asc",    "left" );
    $it->addColSpec( "Enzyme for Candidate Gene", "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity",      "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Candidate");

    # need to hide this one for the time being, because the other
    # seq length is not stored in database
    #     $it->addColSpec( "Alignment<br/>On<br/>PRIAM Consensus" );

    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;

    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,    $gene_display_name1, $aa_seq_length1,
             $align_length, $percent_identity,   $bit_score,
             $evalue,       $query_start,        $query_end,
             $subj_start,   $subj_end
          )
          = split( /\t/, $r0 );

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $bit_score        = sprintf( "%d",   $bit_score );
        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$gene_oid1,$gene_oid1' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid1";
        $r   .= $gene_oid1 . $sd . alink( $url, $gene_oid1 ) . "\t";
        $r   .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($gene_oid1);
        $r .= "$enzyme1\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";

        # hide this one - align_length is not the correct seq length value
        # to use -- the length we need is not in database
        #	 $r .= $sd . alignImage(
        #	     $subj_start, $subj_end, $align_length ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);
    }
    $it->printOuterTable(1);

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();

    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyImgEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    # add to gene cart 3
    my $name = "_section_${section}_addToGeneCart3";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    return $cnt;
}

############################################################################
# getPriamRecords
# (This will be for EC only)
############################################################################
sub getPriamRecords {
    my ($taxon_oid) = param("taxon_oid");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId       = param("funcId");
    my $procId       = param("procId");
    my $database     = param("database");
    my $minPercIdent = param("priamMinPercIdent");
    my $maxEvalue    = param("priamMaxEvalue");
    my $bitScore     = param("priamBitScore");
    my $minPercAlign = param("priamMinPercSAlign");

    my ( $tag, $term_oid ) = split( /:/, $funcId );

    my @priam_recs;
    return @priam_recs; # v4.0

#    my $dbh = dbLogin();
#
#    # priam
#    my $taxonClause = "";
#    my $sql         = qq{
#	 select g1.gene_oid, g1.gene_display_name, g1.aa_seq_length,
#	 gpe.align_length,
#	 gpe.percent_identity, gpe.bit_score, gpe.evalue,
#	 gpe.query_start, gpe.query_end, gpe.subj_start, gpe.subj_end
#	     from gene g1, gene_priam_enzymes gpe
#	     where g1.gene_oid = gpe.gene_oid
#	     and g1.taxon = ?
#	     and gpe.enzymes = ?
#	     and gpe.percent_identity >= ?
#	     and gpe.evalue <= ?
#	     and gpe.bit_score >= ?
#         $taxonClause
#	 };
#
#    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $funcId, $minPercIdent, $maxEvalue, $bitScore );
#
#    for ( ; ; ) {
#        my (
#             $gene_oid1,    $gene_display_name1, $aa_seq_length1,
#             $align_length, $percent_identity,   $bit_score,
#             $evalue,       $query_start,        $query_end,
#             $subj_start,   $subj_end
#          )
#          = $cur->fetchrow();
#        last if !$gene_oid1;
#
#        # check percent alignment
#        if ( $aa_seq_length1 > 0 ) {
#            my $qfrac =
#              ( $query_end - $query_start + 1 ) * 100 / $aa_seq_length1;
#            if ( $qfrac < $minPercAlign ) {
#                next;
#            }
#        } else {
#            next;
#        }
#
#        # disregard fusion genes
#        if ( isFusionGene($gene_oid1) ) {
#            next;
#        }
#
#        my $r;
#        $r .= "$gene_oid1\t";
#        $r .= "$gene_display_name1\t";
#        $r .= "$aa_seq_length1\t";
#        $r .= "$align_length\t";
#        $r .= "$percent_identity\t";
#        $r .= "$bit_score\t";
#        $r .= "$evalue\t";
#        $r .= "$query_start\t";
#        $r .= "$query_end\t";
#        $r .= "$subj_start\t";
#        $r .= "$subj_end\t";
#        push( @priam_recs, $r );
#    }
#    $cur->finish();
#
#    return @priam_recs;
}

############################################################################
# printRecordsWithPriam - Print records of output.
#
# (for both homologs/orthologs and priam)
############################################################################
sub printRecordsWithPriam {
    my ( $ortho_homo, $tag, $recs_ref, $priam_recs_ref ) = @_;

    my $nRecs      = @$recs_ref;
    my $nPriamRecs = @$priam_recs_ref;
    if ( $nRecs == 0 && $nPriamRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Gene",         "number asc", "left" );
    $it->addColSpec( "Candidate Gene Product", "char asc",   "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for Candidate Gene", "char asc", "left" );
    }
    $it->addColSpec( "$ortho_homo Gene", "number asc", "left" );
    $it->addColSpec( "$ortho_homo Gene Product<br/>(IMG Term)",
                     "char asc", "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for $ortho_homo Gene", "char asc", "left" );
    }

    $it->addColSpec( "Domain",               "char asc",    "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",               "char asc",     "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",               "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Candidate");
    $it->addColSpec("Alignment<br/>On<br/>$ortho_homo");
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );

    $it->addColSpec("Confirmed<br/>by PRIAM?");
    $it->addColSpec( "PRIAM Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("PRIAM Alignment<br/>On<br/>Candidate");
    $it->addColSpec( "PRIAM E-value",       "number asc",  "left" );
    $it->addColSpec( "PRIAM Bit<br/>Score", "number desc", "right" );

    my $sd = $it->getSdDelim();

    # organize PRIAM data
    my %priam_h;
    for my $r2 (@$priam_recs_ref) {
        my (
             $gene_oid1,    $gene_display_name1, $aa_seq_length1,
             $align_length, $percent_identity,   $bit_score,
             $evalue,       $query_start,        $query_end,
             $subj_start,   $subj_end
          )
          = split( /\t/, $r2 );
        $priam_h{$gene_oid1} =
"$gene_display_name1\t$query_start\t$query_end\t$aa_seq_length1\t$percent_identity\t$bit_score\t$evalue";
    }

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;
    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );
        if ( $gene_score{$gene_oid1} ) {

            # already has some hit. compare.
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $bit_score > $score2 ) {

                # replace
                $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
            } else {

                # keep original one
            }
        } else {

            # new one
            $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
        }
    }

    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );

        if ( $gene_score{$gene_oid1} ) {
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $g2 == $gene_oid2 ) {

                # continue output
            } else {

                # skip
                next;
            }
        } else {

            # shouldn't happen
            next;
        }

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $domain2 = substr( $domain2, 0, 1 );
        $seq_status2 = substr( $seq_status2, 0, 1 );
        $bit_score = sprintf( "%d", $bit_score );
        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$gene_oid1,$gene_oid2' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid1";
        $r   .= $gene_oid1 . $sd . alink( $url, $gene_oid1 ) . "\t";
        $r   .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($gene_oid1);
        $r .= "$enzyme1\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid2";
        $r   .= $gene_oid2 . $sd . alink( $url, $gene_oid2 ) . "\t";
        $r   .= "$gene_display_name2\t";

        my $enzyme2 = getEnzymeForGene($gene_oid2);
        $r .= "$enzyme2\t";

        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid2";
        $r   .=
          $taxon_display_name2 . $sd
          . alink( $url, $taxon_display_name2 ) . "\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .=
          $sd . alignImage( $subj_start, $subj_end, $aa_seq_length2 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";

        if ( $priam_h{$gene_oid1} ) {
            my (
                 $gene_name1,         $priam_query_start,
                 $priam_query_end,    $priam_aa_seq_length1,
                 $priam_percent_iden, $priam_bit_score,
                 $priam_evalue
              )
              = split( /\t/, $priam_h{$gene_oid1} );
            $priam_bit_score = sprintf( "%d",   $priam_bit_score );
            $priam_evalue    = sprintf( "%.2e", $priam_evalue );
            $r .= "Yes\t";
            $r .= "$priam_percent_iden\t";
            $r .= $sd
              . alignImage( $priam_query_start, $priam_query_end,
                            $priam_aa_seq_length1 )
              . "\t";
            $r .= "$priam_evalue\t";
            $r .= "$priam_bit_score\t";
        } else {
            $r .= "No\t\t\t\t\t";
        }
        $it->addRow($r);
    }

    # print the genes that only have priam hits
    for my $key ( keys %priam_h ) {
        if ( $gene_score{$key} ) {

            # skip
            next;
        }

        # display
        my (
             $gene_display_name1, $priam_query_start,
             $priam_query_end,    $priam_aa_seq_length1,
             $priam_percent_iden, $priam_bit_score,
             $priam_evalue
          )
          = split( /\t/, $priam_h{$key} );
        $priam_bit_score = sprintf( "%d",   $priam_bit_score );
        $priam_evalue    = sprintf( "%.2e", $priam_evalue );

        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$key,' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$key";
        $r   .= $key . $sd . alink( $url, $key ) . "\t";
        $r   .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($key);
        $r .= "$enzyme1\t";

        $r .= "\t\t\t\t\t\t\t\t\t\t\t";
        $r .= "Yes\t";
        $r .= "$priam_percent_iden\t";
        $r .= $sd
          . alignImage( $priam_query_start, $priam_query_end,
                        $priam_aa_seq_length1 )
          . "\t";
        $r .= "$priam_evalue\t";
        $r .= "$priam_bit_score\t";

        $it->addRow($r);
        $cnt++;
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    $it->printOuterTable(1);

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    if ( $tag eq 'ITERM'
         && canEditGeneTerm( $dbh, $contact_oid ) )
    {
        my $name = "_section_${section}_addAssoc";
        print submit(
                      -name  => $name,
                      -value => "Add Term to Candidate Gene(s)",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    } elsif ( $tag eq 'EC' && $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyImgEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    my $name = "_section_${section}_addToGeneCart4";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    return $cnt;
}

############################################################################
# getGenePriamRecords
############################################################################
sub getGenePriamRecords {
    my ($gene_oid) = @_;
    
    my @priam_recs;
    return @priam_recs; # v4.0

#    my $dbh = dbLogin();
#
#    # priam
#    my $sql = qq{
#	 select e1.ec_number, e1.enzyme_name, g1.aa_seq_length,
#	 gpe.align_length, gpe.percent_identity, gpe.bit_score, gpe.evalue,
#	 gpe.query_start, gpe.query_end, gpe.subj_start, gpe.subj_end
#	     from enzyme e1, gene_priam_enzymes gpe, gene g1
#	     where gpe.gene_oid = ?
#	     and gpe.gene_oid = g1.gene_oid
#	     and e1.ec_number = gpe.enzymes
#	 };
#
#    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
#
#    for ( ; ; ) {
#        my (
#             $ec_number,    $enzyme_name1,     $aa_seq_length1,
#             $align_length, $percent_identity, $bit_score,
#             $evalue,       $query_start,      $query_end,
#             $subj_start,   $subj_end
#          )
#          = $cur->fetchrow();
#        last if !$ec_number;
#
#        my $r;
#        $r .= "$ec_number\t";
#        $r .= "$enzyme_name1\t";
#        $r .= "$aa_seq_length1\t";
#        $r .= "$align_length\t";
#        $r .= "$percent_identity\t";
#        $r .= "$bit_score\t";
#        $r .= "$evalue\t";
#        $r .= "$query_start\t";
#        $r .= "$query_end\t";
#        $r .= "$subj_start\t";
#        $r .= "$subj_end\t";
#        push( @priam_recs, $r );
#    }
#    $cur->finish();
#    #$dbh->disconnect();
#
#    return @priam_recs;
}

############################################################################
# printGenePriamRecords - Print records of output from PRIAM results
############################################################################
sub printGenePriamRecords {
    my ($recs_ref) = @_;

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingEnzymes$$", "missingEnzymes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Enzyme",     "number asc",  "left" );
    $it->addColSpec( "Enzyme Name",          "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Candidate");

    # need to hide this one for the time being, because the other
    # seq length is not stored in database
    #     $it->addColSpec( "Alignment<br/>On<br/>PRIAM Consensus" );

    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;
    for my $r0 (@$recs_ref) {
        my (
             $ec_number,    $enzyme_name,      $aa_seq_length1,
             $align_length, $percent_identity, $bit_score,
             $evalue,       $query_start,      $query_end,
             $subj_start,   $subj_end
          )
          = split( /\t/, $r0 );

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $bit_score        = sprintf( "%d",   $bit_score );
        my $r;
        $r .=
            "$sd<input type='checkbox' name='ec_hit' "
          . "value='$ec_number' />\t";

        my $enzyme_base_url = $env->{enzyme_base_url};
        my $url             = "$enzyme_base_url$ec_number";

        $r .= $ec_number . $sd . alink( $url, $ec_number ) . "\t";
        $r .= "$enzyme_name\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);
    }
    $it->printOuterTable(1);

    my $contact_oid = getContactOid();
    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    # this should be add to function cart (enzyme)
    #    my $name = "_section_${section}_addToGeneCart5";
    #    print submit( -name => $name,
    #		 -value => "Add To Gene Cart 5", -class => 'smdefbutton' );
    #    print nbsp( 1 );

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    return $cnt;
}

############################################################################
# addGeneTermAssoc - Add gene term association.
############################################################################
sub addGeneTermAssoc {
    my $funcId = param("funcId");
    my $procId = param("procId");
    my ( $tag, $term_oid ) = split( /:/, $funcId );
    my @gene_oid_hits = param("gene_oid_hit");
    my %hits;
    for my $hit (@gene_oid_hits) {
        my ( $gene_oid1, $gene_oid2 ) = split( /,/, $hit );
        $hits{$gene_oid1} .= " $gene_oid2";
    }
    my @gene_oids = sort( keys(%hits) );
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        webError("No hits were selected. Please select a hit.");
    }

    my $contact_oid = getContactOid();

    return;

    my $dbh = dbLogin();
    print "<h1>Gene Term Assocication</h1>\n";
    if ( !isImgEditor( $dbh, $contact_oid ) ) {
        #$dbh->disconnect();
        webError("You do not have permission to modify IMG terms.");
        return;
    }

    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    for my $gene_oid (@gene_oids) {
        print "Adding gene <i>$gene_oid</i> to term <i>$funcId</i>\n";
        my $confidence = "Inferred from" . $hits{$gene_oid};
        addImgFunction( $dbh, $gene_oid, $term_oid, $contact_oid, $confidence,
                        $procId );
    }
    print "</p>\n";
    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# addImgFunction - Add to gene_img_function table and derived tables.
############################################################################
sub addImgFunction {
    my ( $dbh, $gene_oid, $term_oid, $contact_oid, $confidence, $procId ) = @_;

    my $taggedTermOid = "ITERM:" . FuncUtil::termOidPadded($term_oid);

    # Flush old stuff
    my $cur = execSql( $dbh, "commit work", $verbose );
    $cur->finish();

    # Start transaction
    my $cur = execSql( $dbh, "set transaction read write", $verbose );
    $cur->finish();

    my $sql = qq{
        select count(*)
    	from gene_img_functions
    	where gene_oid = ?
    	and function = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    if ( $cnt == 1 ) {
        print "<br/>\n";
        print nbsp(2);
        print "(Association already made.)<br/>\n";
        return;
    }

    my $sql = "select taxon, scaffold from gene where gene_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($taxon_oid, $scaffold_oid) = $cur->fetchrow();
    $cur->finish();

    $sql = qq{
        select max( f_order )
    	from gene_img_functions
    	where gene_oid = ?
    };
    $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($f_order) = $cur->fetchrow();
    $cur->finish();
    if ( $f_order eq "" ) {
        $f_order = 0;
    } else {
        $f_order++;
    }

    my $evidence = 'Missing Genes UI';

    my $sql = qq{
       insert into gene_img_functions(
           gene_oid, function, f_order, evidence, confidence, 
	      mod_date, modified_by, taxon, scaffold )
       values( $gene_oid, $term_oid, $f_order, '$evidence', '$confidence', 
           sysdate, $contact_oid, $taxon_oid, $scaffold_oid )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();

    my $cur = execSql( $dbh, "commit work", $verbose );
    $cur->finish();
}

############################################################################
# printCandidatesForm - Find candidates for missing genes.
#    Fill in form.
############################################################################
sub printGeneTermAssocForm {

    printMainForm();

    print "<h1>Add Term to Candidate Gene(s)</h1>\n";

    printStatusLine( "Loading ...", 1 );

    print "<p>\n";

    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId = param("funcId");
    my $procId = param("procId");
    my ( $tag, $term_oid ) = split( /:/, $funcId );
    my @gene_oid_hits = param("gene_oid_hit");
    my %hits;
    for my $hit (@gene_oid_hits) {
        my ( $gene_oid1, $gene_oid2 ) = split( /,/, $hit );
        $hits{$gene_oid1} .= " $gene_oid2";
    }
    my @gene_oids = sort( keys(%hits) );
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        webError("No genes were selected. Please select a gene.");
    }

    my $minPercIdent = param("minPercIdent");
    my $maxEvalue    = param("maxEvalue");

    #    my $orthologs = param("orthologs");

    print hiddenVar( "taxon_oid",      $taxon_oid );
    print hiddenVar( "otherTaxonOids", $otherTaxonOids );
    print hiddenVar( "funcId",         $funcId );

    #    print hiddenVar( "procId", $procId );

    # prepare hidden parameters for function profile
    print hiddenVar( "profileTaxonBinOid", "t:$taxon_oid" );
    my @taxon_oids_other = split( /,/, $otherTaxonOids );
    for my $tid (@taxon_oids_other) {
        print hiddenVar( "profileTaxonBinOid", "t:$tid" );
    }

    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }
    print hiddenVar( "minPercIdent", $minPercIdent );
    print hiddenVar( "maxEvalue",    $maxEvalue );

    #    if ( $orthologs ) {
    #	print hiddenVar( "orthologs", 1 );
    #    }

    my $dbh = dbLogin();

    # get new term
    my $new_term = termOid2Term( $dbh, $term_oid );
    print hiddenVar( "term_oid", $term_oid );

    # get IMG terms for all gene oids
    require GeneCartDataEntry;
    my %geneTerms = GeneCartDataEntry::getGeneImgTerms( $dbh, @gene_oids );

    # get all cell_loc values
    my @cell_locs = (' ');
    my $sql2      = "select loc_type from CELL_LOCALIZATION order by loc_type";
    my $cur2      = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ($c_loc) = $cur2->fetchrow();
        last if !$c_loc;

        push @cell_locs, ($c_loc);
    }
    $cur2->finish();

    # add java script function 'setEvidence'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setEvidence( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^ev_/ ) ) {\n";
    print "              e.selectedIndex = x;\n";
    print "             }\n";
    print "         }\n";
    print "   }\n";
    print "function setAddReplace( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^ar_/ ) ) {\n";
    print "              if ( x == 0 ) {\n";
    print "                 if ( e.value == 'add' && ! e.disabled ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "              if ( x == 1 ) {\n";
    print "                 if ( e.value == 'replace' && ! e.disabled ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Gene Display Name</th>\n";
    print "<th class='img'>Genome</th>\n";
    print "<th class='img'>Old IMG Term(s)</th>\n";
    print "<th class='img'>New IMG Term</th>\n";

    print "<th class='img'>Add/Replace\n";
    print "<input type='button' value='Add' Class='tinybutton'\n";
    print "  onClick='setAddReplace (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Replace' Class='tinybutton'\n";
    print "  onClick='setAddReplace (1)' />\n";
    print "</th>\n";

    print "<th class='img'>Evidence <br/>\n";
    print "<input type='button' value='Null' Class='tinybutton'\n";
    print "  onClick='setEvidence (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Experimental' Class='tinybutton'\n";
    print "  onClick='setEvidence (1)' />\n";
    print "<br/>\n";
    print "<input type='button' value='High' Class='tinybutton'\n";
    print "  onClick='setEvidence (2)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Inferred' Class='tinybutton'\n";
    print "  onClick='setEvidence (3)' />\n";
    print "</th>\n";

    print "<th class='img'>Confidence</th>\n";
    print "<th class='img'>Cell Localization</th>\n";

    for my $gene_oid (@gene_oids) {
        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='gene_oid' value='$gene_oid' $ck/>\n";
        print "</td>\n";

        my $tax_oid          = geneOid2TaxonOid( $dbh, $gene_oid );
        my $tax_display_name = taxonOid2Name( $dbh,    $tax_oid );
        my $desc             = geneOid2Name( $dbh,     $gene_oid );

        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML($desc) . "</td>\n";
        print "<td class='img'>" . escapeHTML($tax_display_name) . "</td>\n";

        # print old IMG terms
        my $ar = 0;
        if ( $geneTerms{$gene_oid} ) {
            print "<td class='img'>" . "$geneTerms{$gene_oid}" . "</td>\n";

            # check whether the same term already exist
            if (
                 db_findCount( $dbh, 'GENE_IMG_FUNCTIONS',
                               "gene_oid = ? and function = ? ",
			       $gene_oid, $term_oid  )
                 > 0
              )
            {
                $ar = 1;
            }
        } else {
            print "<td class='img'>" . "" . "</td>\n";
            $ar = 2;    # no old term. disable the Replace button below
        }

        # print new IMG term
        print "<td class='img'>" . escapeHTML($new_term) . "</td>\n";

        # print Add?/Replace?
        my $ar_name = "ar_" . $gene_oid;
        print "<td class='img' bgcolor='#eed0d0'>\n";
        if ( $ar == 1 ) {
            # replace only
            print
"  <input type='radio' name='$ar_name' value='add' disabled />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' checked />Replace\n";
        } elsif ( $ar == 2 ) {

            # add only
            print
"  <input type='radio' name='$ar_name' value='add' checked />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' disabled />Replace\n";
        } else {

            # both
            print
"  <input type='radio' name='$ar_name' value='add' checked />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' />Replace\n";
        }
        print "</td>\n";

        # print evidence
        my $ev_name = "ev_" . $gene_oid;
        print "<td class='img'>\n";
        print "  <select name='$ev_name' id='$ev_name'>\n";
        print "     <option value='Null'>Null</option>\n";
        print "     <option value='Experimental'>Experimental</option>\n";
        print "     <option value='High'>High</option>\n";
        print "     <option value='Inferred'>Inferred</option>\n";
        print "  </select>\n";
        print "</td>\n";

        # print confidence
        my $cm_name = "cm_" . $gene_oid;
        print "<td class='img'>\n";
        print
          "  <input type='text' name='$cm_name' size='20' maxLength='255'/>\n";
        print "</td>\n";

        # cell_loc
        my $cl_name = "cell_" . $gene_oid;
        print "<td class='img'>\n";
        print "  <select name='$cl_name' id='$cl_name' class='img' size='1'>\n";
        for my $c2 (@cell_locs) {
            print "    <option value='$c2' />$c2</option>\n";
        }
        print "  </select>\n";
        print "</td>\n";

        print "</tr>\n";
    }
    print "</table>\n";
    #$dbh->disconnect();

    print "<h4>Display New Results in:</h4>\n";
    print "<p>\n";
    print "<input type='radio' name='disp_type' "
	. "value='func_profile_s' checked />"
	. "Function Profile (view functions vs. genomes)\n";
    print "<br/>\n";
    print "<input type='radio' name='disp_type' "
	. "value='func_profile_t' />"
	. "Function Profile (view genomes vs. functions)\n";
    print "</p>\n";

    printHint("Click '<u>Update Database</u>' to save your change(s) to the database. Only selected gene-term associations will be updated.\n");

    print "</p>\n";
    my $name = "_section_${section}_dbUpdateGeneTerm";
    print submit(
                  -name  => $name,
                  -value => "Update Database",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    print reset( -class => "medbutton" );
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# dbUpdateGeneTerm - update gene term associations from the database
############################################################################
sub dbUpdateGeneTerm {

    #    my( $taxon_oid ) = param( "taxon_oid" );
    #    my $otherTaxonOids = param( "otherTaxonOids" );
    #    my $funcId =  param( "funcId" );

    my $term_oid  = param('term_oid');
    my @gene_oids = param('gene_oid');

    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {

        #	webError( "No genes were selected. Please select a gene." );
        return;
    }

    # login
    my $dbh = dbLogin();

    # get f_order
    require GeneCartDataEntry;
    my %f_order = GeneCartDataEntry::getFOrder( $dbh, @gene_oids );

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $ins         = "";
    my $vals        = "";
    my $contact_oid = getContactOid();

    for my $gene_oid (@gene_oids) {
        my $ar = param( "ar_" . $gene_oid );

        if ( $ar eq 'replace' ) {

            # delete
            $sql = "delete from GENE_IMG_FUNCTIONS where gene_oid = $gene_oid";
            push @sqlList, ($sql);

        } else {

            # check whether gene-term assoc is already there
            my $cnt =
              db_findCount( $dbh, 'gene_img_functions',
                            "gene_oid = ? and function = ?",
			    $gene_oid, $term_oid );
            if ( $cnt > 0 ) {
                next;
            }
        }

        # , evidence, confidence, modified_by)";

	# get taxon, scaffold
	my $sql2 = "select taxon, scaffold from gene where gene_oid = ?";
	my $cur2  = execSql( $dbh, $sql2, $verbose, $gene_oid );
	my ($taxon2, $scaffold2) = $cur2->fetchrow();
	$cur2->finish();

        # insert
        $ins  = "insert into gene_img_functions (gene_oid, taxon, scaffold, function, f_order";
        $vals = " values ($gene_oid, $taxon2, $scaffold2, $term_oid";

        # f_order
        my $next_order = 0;
        if ( $ar ne 'replace' && $f_order{$gene_oid} ) {
            $next_order = $f_order{$gene_oid};
        }

        $vals .= ", $next_order";

        # evidence
        my $ev = param( "ev_" . $gene_oid );
        if (    $ev eq 'Experimental'
             || $ev eq 'High'
             || $ev eq 'Inferred' )
        {
            $ins  .= ", evidence";
            $vals .= ", '" . $ev . "'";
        }

        # confidence
        my $cm = param( "cm_" . $gene_oid );
        if ( $cm && !blankStr($cm) ) {
            $cm =~ s/'/''/g;
            $ins  .= ", confidence";
            $vals .= ", '" . $cm . "'";
        }

        # cell_loc
        my $cl = param( "cell_" . $gene_oid );
        if ( $cl && !blankStr($cl) ) {
            $cl =~ s/'/''/g;
            $ins  .= ", cell_loc";
            $vals .= ", '" . $cl . "'";
        }

        # modified by
        if ($contact_oid) {
            $ins  .= ", modified_by";
            $vals .= ", " . $contact_oid;
        }

        # f_flag
        $ins  .= ", f_flag)";
        $vals .= ", 'M')";

        $sql = $ins . $vals;

        push @sqlList, ($sql);

    }    # end for gene_oid

    #$dbh->disconnect();

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        webError("SQL Error: $sql");
        return -1;
    } else {
        return $term_oid;
    }
}

############################################################################
# dbUpdateSimGeneTerm - update gene term associations from the database
############################################################################
sub dbUpdateSimGeneTerm {
    my @term_oids = param('term_oid');
    my $gene_oid  = param('gene_oid');

    # login
    my $dbh = dbLogin();

    # get f_order
    require GeneCartDataEntry;
    my %f_order = GeneCartDataEntry::getFOrder( $dbh, ($gene_oid) );

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $ins         = "";
    my $vals        = "";
    my $contact_oid = getContactOid();

    for my $term_oid (@term_oids) {
        my $ar = param( "ar_" . $gene_oid );

        if ( $ar eq 'replace' ) {

            # delete
            $sql = "delete from GENE_IMG_FUNCTIONS where gene_oid = $gene_oid";
            push @sqlList, ($sql);

        } else {

            # check whether gene-term assoc is already there
            my $cnt =
              db_findCount( $dbh, 'gene_img_functions',
                            "gene_oid = ? and function = ?",
			    $gene_oid, $term_oid );
            if ( $cnt > 0 ) {
                next;
            }
        }

        # , evidence, confidence, modified_by)";

	# get taxon, scaffold
	my $sql2 = "select taxon, scaffold from gene where gene_oid = ?";
	my $cur2  = execSql( $dbh, $sql2, $verbose, $gene_oid );
	my ($taxon2, $scaffold2) = $cur2->fetchrow();
	$cur2->finish();

        # insert
        $ins  = "insert into gene_img_functions (gene_oid, taxon, scaffold, function, f_order";
        $vals = " values ($gene_oid, $taxon2, $scaffold2, $term_oid";

        # f_order
        my $next_order = 0;
        if ( $ar ne 'replace' && $f_order{$gene_oid} ) {
            $next_order = $f_order{$gene_oid};
        }

        $vals .= ", $next_order";

        # increase next order
        $f_order{$gene_oid} = $next_order + 1;

        # evidence
        my $ev = param( "ev_" . $gene_oid );
        if (    $ev eq 'Experimental'
             || $ev eq 'High'
             || $ev eq 'Inferred' )
        {
            $ins  .= ", evidence";
            $vals .= ", '" . $ev . "'";
        }

        # confidence
        my $cm = param( "cm_" . $gene_oid );
        if ( $cm && !blankStr($cm) ) {
            $cm =~ s/'/''/g;
            $ins  .= ", confidence";
            $vals .= ", '" . $cm . "'";
        }

        # cell_loc
        my $cl = param( "cell_" . $gene_oid );
        if ( $cl && !blankStr($cl) ) {
            $cl =~ s/'/''/g;
            $ins  .= ", cell_loc";
            $vals .= ", '" . $cl . "'";
        }

        # modified by
        if ($contact_oid) {
            $ins  .= ", modified_by";
            $vals .= ", " . $contact_oid;
        }

        # f_flag
        $ins  .= ", f_flag)";
        $vals .= ", 'M')";

        $sql = $ins . $vals;

        push @sqlList, ($sql);

    }    # end for gene_oid

    #$dbh->disconnect();

    #    my $msg2 = "";
    #    for my $sql2 ( @sqlList ) {
    #	$msg2 .= "SQL: $sql2 ";
    #    }
    #    return $msg2;

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return $sql;
    } else {
        return "";
    }
}

##########################################################################
# isFusionGene - whether the gene is a fusion gene
##########################################################################
sub isFusionGene {
    my ($gene_oid) = @_;

    my $dbh = dbLogin();
    my $cnt =
      db_findCount( $dbh, 'gene_fusion_components', "gene_oid = $gene_oid" );
    #$dbh->disconnect();

    if ($cnt) {
        return 1;
    }

    return 0;
}

##########################################################################
# getMinScore
##########################################################################
sub getMinScore {
    my ($a_ref) = @_;

    my $min_score = 1000000;

    for my $k (@$a_ref) {
        if ( $k < $min_score ) {
            $min_score = $k;
        }
    }

    return $min_score;
}

##########################################################################
# getEnzymeForGene - get enzyme info from MyIMG first,
#                    then check gene_enzyme
##########################################################################
sub getEnzymeForGene {
    my ($gene_oid) = @_;

    my $dbh    = dbLogin();
    my $ec_val =
      db_findVal( $dbh, 'gene_myimg_functions', 'gene_oid', $gene_oid,
                  'ec_number', '' );
    if ( !blankStr($ec_val) ) {
        return $ec_val;
    }

    my @ec_vals =
      db_findSetVal( $dbh, 'gene_ko_enzymes', 'gene_oid', $gene_oid, 'enzymes',
                     '' );

    my $prev_ec = "";
    for my $s1 ( sort(@ec_vals) ) {
        if ( $s1 eq $prev_ec ) {

            # skip duplicates
            next;
        }

        $prev_ec = $s1;
        if ( blankStr($ec_val) ) {
            $ec_val = $s1;
        } else {
            $ec_val .= " " . $s1;
        }
    }

    return $ec_val;
}

############################################################################
# printMyImgGeneEnzymeForm
#    Fill in form.
############################################################################
sub printMyImgGeneEnzymeForm {

    printMainForm();

    print "<h1>Add Enzyme to Candidate Gene(s) in MyIMG Annotation</h1>\n";

    printStatusLine( "Loading ...", 1 );

    print "<p>\n";

    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId = param("funcId");
    my $procId = param("procId");

    #    my( $tag, $term_oid ) = split( /:/, $funcId );
    my @gene_oid_hits = param("gene_oid_hit");
    my %hits;
    for my $hit (@gene_oid_hits) {
        my ( $gene_oid1, $gene_oid2 ) = split( /,/, $hit );
        $hits{$gene_oid1} .= " $gene_oid2";
    }
    my @gene_oids = sort( keys(%hits) );
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        webError("No genes were selected. Please select a gene.");
    } elsif ( $nGenes > 1000 ) {
        webError("Please select no more than 1000 gene.");
    }

    my $contact_oid = getContactOid();

    my $minPercIdent = param("minPercIdent");
    my $maxEvalue    = param("maxEvalue");

    #    my $orthologs = param("orthologs");

    print hiddenVar( "taxon_oid",      $taxon_oid );
    print hiddenVar( "otherTaxonOids", $otherTaxonOids );
    print hiddenVar( "funcId",         $funcId );

    #    print hiddenVar( "procId", $procId );

    # prepare hidden parameters for function profile
    print hiddenVar( "profileTaxonBinOid", "t:$taxon_oid" );
    my @taxon_oids_other = split( /,/, $otherTaxonOids );
    for my $tid (@taxon_oids_other) {
        print hiddenVar( "profileTaxonBinOid", "t:$tid" );
    }

    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }
    print hiddenVar( "minPercIdent", $minPercIdent );
    print hiddenVar( "maxEvalue",    $maxEvalue );

    #    if ( $orthologs ) {
    #	print hiddenVar( "orthologs", 1 );
    #    }

    my $dbh = dbLogin();

    # get enzyme name
    my $func_name = enzymeName( $dbh, $funcId );

    # get MyIMG gene-enzyme for all genes
    my %gene_ec;
    my $sql2  = "select gene_oid, ec_number from gene_myimg_functions";
    my $cond2 = "";
    for my $g1 (@gene_oids) {
        if ( length($cond2) == 0 ) {
            $cond2 = " where gene_oid in ($g1";
        } else {
            $cond2 .= ", $g1";
        }
    }
    $sql2 .= $cond2 . ")";
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ( $g_id1, $ec1 ) = $cur2->fetchrow();
        last if !$g_id1;

        $gene_ec{$g_id1} = $ec1;
    }
    $cur2->finish();

    # add java script
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setAddReplace( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^ar_/ ) ) {\n";
    print "              if ( x == 0 ) {\n";
    print "                 if ( e.value == 'add' && ! e.disabled ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "              if ( x == 1 ) {\n";
    print "                 if ( e.value == 'replace' && ! e.disabled ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Gene Display Name</th>\n";
    print "<th class='img'>Genome</th>\n";
    print "<th class='img'>Old MyIMG Enzyme(s)</th>\n";
    print "<th class='img'>New MyIMG Enzyme</th>\n";

    print "<th class='img'>Add/Replace\n";
    print "<input type='button' value='Add' Class='tinybutton'\n";
    print "  onClick='setAddReplace (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Replace' Class='tinybutton'\n";
    print "  onClick='setAddReplace (1)' />\n";
    print "</th>\n";

    for my $gene_oid (@gene_oids) {
        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='gene_oid' value='$gene_oid' $ck/>\n";
        print "</td>\n";

        my $tax_oid          = geneOid2TaxonOid( $dbh, $gene_oid );
        my $tax_display_name = taxonOid2Name( $dbh,    $tax_oid );
        my $desc             = geneOid2Name( $dbh,     $gene_oid );

        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML($desc) . "</td>\n";
        print "<td class='img'>" . escapeHTML($tax_display_name) . "</td>\n";

        # print old MyIMG enzymes
        my $ar = 0;
        if ( $gene_ec{$gene_oid} ) {
            print "<td class='img'>" . "$gene_ec{$gene_oid}" . "</td>\n";

            # check whether the same enzyme already exist
            if ( $gene_ec{$gene_oid} =~ /$funcId/ ) {
                $ar = 1;
            }
        } else {
            print "<td class='img'>" . "" . "</td>\n";
            $ar = 2;    # no old enzyme. disable the Replace button below
        }

        # print new enzyme
        print "<td class='img'>" . escapeHTML($funcId) . "</td>\n";

        # print Add?/Replace?
        my $ar_name = "ar_" . $gene_oid;
        print "<td class='img' bgcolor='#eed0d0'>\n";
        if ( $ar == 1 ) {

            # replace only
            print
"  <input type='radio' name='$ar_name' value='add' disabled />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' checked />Replace\n";
        } elsif ( $ar == 2 ) {

            # add only
            print
"  <input type='radio' name='$ar_name' value='add' checked />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' disabled />Replace\n";
        } else {

            # both
            print
"  <input type='radio' name='$ar_name' value='add' checked />Add\n";
            print "<br/>\n";
            print
"  <input type='radio' name='$ar_name' value='replace' />Replace\n";
        }
        print "</td>\n";

        print "</tr>\n";
    }
    print "</table>\n";

    if ( param("pathway_oid") ) {

        # pathway
        print hiddenVar( "pathway_oid", param("pathway_oid") );
        print hiddenVar( "map_id",      param("map_id") );
        print hiddenVar( "disp_type",   "kegg" );
    } else {

        # profile
        print "<h4>Display New Results in:</h4>\n";
        print
"<input type='radio' name='disp_type' value='func_profile_s' checked />Function Profile (view functions vs. genomes)\n";
        print "<br/>\n";
        print
"<input type='radio' name='disp_type' value='func_profile_t' />Function Profile (view genomes vs. functions)\n";

        print "<br/>\n";
    }

    print "<p/>\n";

    printHint("Click '<u>Update MyIMG Annotation</u>' to save your change(s) to the database. Only selected gene-enzyme associations will be added to MyIMG annotation.\n");

    print "</p>\n";

    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_dbUpdateMyImgGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Update MyIMG Annotation",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print reset( -class => "medbutton" );
    }

    #$dbh->disconnect();
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printAddMyGeneEnzymeForm
# (add gene-enzyme to MyImg annotation -- from gene page)
############################################################################
sub printAddMyGeneEnzymeForm {

    printMainForm();

    print "<h1>Add Enzyme(s) to Selected Gene in MyIMG Annotation</h1>\n";

    print "<p>\n";

    my ($gene_oid) = param("gene_oid");
    print hiddenVar( "gene_oid", $gene_oid );

    my $dbh          = dbLogin();
    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );
    print "<h3>Gene ($gene_oid): " . escapeHTML($product_name) . "</h3>\n";

    my @ec_hits = param("ec_hit");
    if ( scalar(@ec_hits) == 0 ) {
        #$dbh->disconnect();
        webError("No enzymes were selected. Please select an enzyme.");
    }

    printStatusLine( "Loading ...", 1 );

    # get MyIMG gene-enzyme for selected gene
    my $contact_oid = getContactOid();
    my @myimg_enzymes = db_findSetVal(
                                       $dbh,
                                       'gene_myimg_enzymes',
                                       'gene_oid',
                                       $gene_oid,
                                       'ec_number',
                                       "modified_by = $contact_oid"
    );

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>EC Number</th>\n";
    print "<th class='img'>Enzyme Name</th>\n";

    for my $ec1 (@ec_hits) {
        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='ec_number' value='$ec1' $ck/>\n";
        print "</td>\n";

        my $enzyme_base_url = $env->{enzyme_base_url};
        my $url             = "$enzyme_base_url$ec1";
        print "<td class='img'>" . alink( $url, $ec1 ) . "</td>\n";

        my $sql2 = "select enzyme_name from enzyme where ec_number = '$ec1'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        my ($enzyme_name) = $cur2->fetchrow();
        $cur2->finish();
        print "<td class='img'>" . escapeHTML($enzyme_name) . "</td>\n";

        print "</td>\n";
        print "</tr>\n";
    }    # end for my ec1
    print "</table>\n";

    # add or replace
    print "<p>\n";
    print "Add or replace MyIMG gene-enzyme annotation:<br/>\n"; 
    print "  <input type='radio' name='ar_mygeneec' "
	. "value='add' checked />Add\n";
    print nbsp(2);
    if ( scalar(@myimg_enzymes) == 0 ) {
        print "  <input type='radio' name='ar_mygeneec' "
	    . "value='replace' disabled />Replace\n";
    } else {
        print "  <input type='radio' name='ar_mygeneec' "
	    . "value='replace' />Replace\n";
    }
    print "</p>\n";

    printHint("Click '<u>Update MyIMG Annotation</u>' to save your change(s) to the database. Only selected gene-enzyme associations will be added to MyIMG annotation.\n");

    if ($show_myimg_login) {
        my $name = "_section_${section}_dbUpdMyGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Update MyIMG Annotation",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print reset( -class => "medbutton" );
        print "<br/>\n";
    }

    #$dbh->disconnect();
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# dbUpdateMyImgGeneEnzyme - update gene-enzyme MyIMG annotation
############################################################################
sub dbUpdateMyImgGeneEnzyme {

    #    my( $taxon_oid ) = param( "taxon_oid" );

    my $funcId    = param('funcId');
    my @gene_oids = param('gene_oid');

    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {

        #webError( "No genes were selected. Please select a gene." );
        return;
    }

    # login
    my $dbh = dbLogin();

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $contact_oid = getContactOid();

    for my $gene_oid (@gene_oids) {
        my $ar = param( "ar_" . $gene_oid );

        if ( $ar eq 'replace' ) {

            # delete from gene_myimg_enzymes
            $sql =
                "delete from gene_myimg_enzymes "
              . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            # update gene_myimg_functions
            $sql =
                "update gene_myimg_functions "
              . "set ec_number = '"
              . $funcId . "' "
              . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            # insert into gene_myimg_enzymes
            $sql =
                "insert into gene_myimg_enzymes "
              . "(gene_oid, ec_number, modified_by, mod_date) "
              . "values ($gene_oid, '$funcId', $contact_oid, sysdate)";
            push @sqlList, ($sql);
        } else {

            # add
            my $cnt =
              db_findCount
	      ( $dbh, 'gene_myimg_functions',
		"gene_oid = $gene_oid and modified_by = $contact_oid" );

            my $ec_val = '';
            if ($cnt) {
                $ec_val =
                  db_findVal( $dbh, 'gene_myimg_functions', 'gene_oid',
                              $gene_oid, 'ec_number', '' );
            }

            my $to_update = 1;
            if ( blankStr($ec_val) ) {
                $ec_val = $funcId;
            } elsif ( $ec_val =~ /$funcId/ ) {

                # do nothing
                $to_update = 0;
            } else {
                $ec_val .= " " . $funcId;
            }

            if ($to_update) {
                if ($cnt) {

                    # update gene_myimg_functions
                    $sql =
                        "update gene_myimg_functions "
                      . "set ec_number = '"
                      . $ec_val . "' "
                      . "where gene_oid = $gene_oid "
                      . "and modified_by = $contact_oid";
                } else {

                    # insert
                    my $prod_name =
                      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid,
                                  'gene_display_name', '' );
                    $prod_name =~ s/'/''/g;    # replace ' with ''
                    $sql =
                        "insert into gene_myimg_functions "
                      . "(gene_oid, product_name, ec_number, "
                      . "modified_by, mod_date) "
                      . "values ($gene_oid, '$prod_name', '$ec_val', "
                      . "$contact_oid, sysdate)";
                }
                push @sqlList, ($sql);

                # insert into gene_myimg_enzymes
                $sql =
                    "insert into gene_myimg_enzymes "
                  . "(gene_oid, ec_number, modified_by, mod_date) "
                  . "values ($gene_oid, '$funcId', $contact_oid, sysdate)";
                push @sqlList, ($sql);
            }
        }

    }    # end for gene_oid

    #$dbh->disconnect();

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        webError("SQL Error: $sql");
        return -1;
    } else {
        return $funcId;
    }
}

############################################################################
# dbUpdMyGeneEnzyme - update gene-enzyme MyIMG annotation
# (for a single gene)
############################################################################
sub dbUpdMyGeneEnzyme {
    my $gene_oid   = param('gene_oid');
    my @ec_numbers = param('ec_number');

    if ( scalar(@ec_numbers) == 0 ) {
        return;
    }

    my $ec_str = "";
    for my $ec1 (@ec_numbers) {
        if ( length($ec_str) == 0 ) {
            $ec_str = $ec1;
        } else {
            $ec_str .= " " . $ec1;
        }
    }

    # login
    my $dbh = dbLogin();

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $contact_oid = getContactOid();

    my $ar = param('ar_mygeneec');

    if ( $ar eq 'replace' ) {

        # delete from gene_myimg_enzymes
        $sql =
            "delete from gene_myimg_enzymes "
          . "where gene_oid = $gene_oid and modified_by = $contact_oid";
        push @sqlList, ($sql);

        # update gene_myimg_functions
        $sql =
            "update gene_myimg_functions "
          . "set ec_number = '"
          . $ec_str . "' "
          . "where gene_oid = $gene_oid and modified_by = $contact_oid";
        push @sqlList, ($sql);

        # insert into gene_myimg_enzymes
        for my $ec1 (@ec_numbers) {
            $sql =
                "insert into gene_myimg_enzymes "
              . "(gene_oid, ec_number, modified_by, mod_date) "
              . "values ($gene_oid, '$ec1', $contact_oid, sysdate)";
            push @sqlList, ($sql);
        }
    } else {

        # add
        my $to_update     = 0;
        my @myimg_enzymes =
          db_findSetVal( $dbh, 'gene_myimg_enzymes', 'gene_oid', $gene_oid,
                         'ec_number', "modified_by = $contact_oid" );

        for my $ec2 (@myimg_enzymes) {
            if ( WebUtil::inArray( $ec2, @ec_numbers ) ) {

                # already there
            } else {
                $to_update = 1;
                push @ec_numbers, ($ec2);
                $ec_str .= " " . $ec2;
            }
        }    # end for my ec2

        # gene has myimg annotation?
        my $cnt =
          db_findCount
	  ( $dbh, 'gene_myimg_functions',
	    "gene_oid = $gene_oid and modified_by = $contact_oid" );

        if ($cnt) {

            # update gene_myimg_functions
            $sql =
                "update gene_myimg_functions "
              . "set ec_number = '"
              . $ec_str . "' "
              . "where gene_oid = $gene_oid "
              . "and modified_by = $contact_oid";
        } else {

            # insert
            my $prod_name =
              db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid,
                          'gene_display_name', '' );
            $prod_name =~ s/'/''/g;    # replace ' with ''
            $sql =
                "insert into gene_myimg_functions "
              . "(gene_oid, product_name, ec_number, "
              . "modified_by, mod_date) "
              . "values ($gene_oid, '$prod_name', '$ec_str', "
              . "$contact_oid, sysdate)";
        }
        push @sqlList, ($sql);

        # insert into gene_myimg_enzymes
        for my $ec1 (@ec_numbers) {
            if ( WebUtil::inArray( $ec1, @myimg_enzymes ) ) {

                # already there
            } else {
                $sql =
                    "insert into gene_myimg_enzymes "
                  . "(gene_oid, ec_number, modified_by, mod_date) "
                  . "values ($gene_oid, '$ec1', $contact_oid, sysdate)";
                push @sqlList, ($sql);
            }
        }

    }    # end for gene_oid

    #$dbh->disconnect();

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        webError("SQL Error: $sql");
        return -1;
    } else {
        return $gene_oid;
    }
}

############################################################################
# printGeneWithPriamInTaxon
############################################################################
sub printGenesWithPriamInTaxon {
    my ($taxon_oid) = @_;

    return; # v4.0
    
    printMainForm();

    print "<h1>Genes w/o enzymes but with candidate KO based enzymes</h1>\n";
    if ( !$taxon_oid ) {
        webError("No genome is selected.");
    }

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    my $url = 
        "$main_cgi?section=TaxonDetail" 
      . "&page=taxonDetail&taxon_oid=$taxon_oid"; 
    my $link = alink($url, $taxon_name); 
 
    print "<b>$link</b>"; 
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    # get MyIMG gene-enzyme for selected gene
    my $contact_oid = getContactOid();

    my $sql = qq{
	select g.gene_oid, g.gene_display_name, g.aa_seq_length,
	e.ec_number, e.enzyme_name,
	gpe.bit_score, gpe.percent_identity, gpe.evalue, 
	gpe.query_start, gpe.query_end, gpe.subj_start, gpe.subj_end
	    from gene g, gene_priam_enzymes gpe, enzyme e
	    where g.taxon = ?
	    and g.gene_oid = gpe.gene_oid
	    and gpe.enzymes = e.ec_number
	    and g.gene_oid not in
	    (select g2.gene_oid
	     from gene g2, gene_ko_enzymes ge
	     where g2.taxon = ?
	     and g2.gene_oid = ge.gene_oid)
	    order by 1 asc, 6 desc
	};
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );

    if ($show_myimg_login) {
        # add or replace
        print "<p>\n";
        print "Add or replace MyIMG gene-enzyme annotation:<br/>\n"; 
        print "  <input type='radio' name='ar_taxgeneec' "
	    . "value='add' checked />Add\n";
        print nbsp(2);
        print "  <input type='radio' name='ar_taxgeneec' "
	    . "value='replace' />Replace\n";
        print "</p>\n";

        printHint("Click '<u>Update MyIMG Annotation</u>' to save your change(s) to the database. Only selected gene-enzyme associations will be added to MyIMG annotation.\n");
    }

    if ($show_myimg_login) {
        my $name = "_section_${section}_dbUpdTaxonGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Update MyIMG Annotation",
                      -class => "meddefbutton"
        );
        print nbsp(1);

        #	print reset( -class => "smbutton" );
        #	print nbsp( 1 );
    }

    my $name = "_section_${section}_addToGeneCart0";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    ### Print the records out in a table.
    my $it = new InnerTable( 0, "taxonGenePriam$$", "taxonGenePriam", 9 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",       "number asc",  "left" );
    $it->addColSpec( "Product Name",         "char asc",    "left" );
    $it->addColSpec( "EC Number",            "char asc",    "left" );
    $it->addColSpec( "Enzyme Name",          "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Gene");
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    my $prev_gene = 0;
    my $cnt       = 0;
    for ( ; ; ) {
        my (
             $g1,          $gname,     $aa_seq_length,    $ec1,
             $ename,       $bit_score, $percent_identity, $evalue,
             $query_start, $query_end, $subj_start,       $subj_end
          )
          = $cur->fetchrow();
        last if !$g1;

        $cnt++;
        if ( $cnt > 1000000 ) {
            last;
        }

        if ( $g1 == $prev_gene ) {
            next;
        }

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );

        my $sel_type = 'checkbox';
        my $r;
        $r .=
            "$sd<input type='"
          . $sel_type
          . "' name='tax_gene_enzyme' "
          . "value='$g1,$ec1' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$g1";
        $r   .= $g1 . $sd . alink( $url, $g1 ) . "\t";
        $r   .= "$gname\t";

        my $enzyme_base_url = $env->{enzyme_base_url};
        my $url             = "$enzyme_base_url$ec1";
        $r .= $ec1 . $sd . alink( $url, $ec1 ) . "\t";
        $r .= "$ename\t";

        # scores
        $r .= "$percent_identity\t";
        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length ) . "\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);

        # save prev
        $prev_gene = $g1;
    }    # end for
    $cur->finish();

    $it->printOuterTable(1);

    if ($show_myimg_login) {
        my $name = "_section_${section}_dbUpdTaxonGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Update MyIMG Annotation",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print reset( -class => "smbutton" );
        print nbsp(1);
    }

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print end_form();
    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
}

############################################################################
# printGeneWithKOInTaxon
############################################################################
sub printGenesWithKOInTaxon {
    my ($taxon_oid) = @_;

    if ( !$taxon_oid ) {
        webError("No genome is selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>Genes w/o enzymes but with candidate KO based enzymes</h1>\n";
    my $url = 
        "$main_cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    my $link = alink($url, $taxon_name);
    print "<b>$link</b>";

    # get MyIMG gene-enzyme for selected gene
    #my $contact_oid = getContactOid();

#    my $sql = qq{
#    	select g.gene_oid, g.gene_display_name, g.aa_seq_length,
#    	gckt.ko_terms, ko.definition,
#    	gckt.bit_score, gckt.percent_identity, gckt.evalue, 
#    	gckt.query_start, gckt.query_end, 
#    	gckt.subj_start, gckt.subj_end
#	    from (select g2.gene_oid gene_oid
#		  from gene g2
#		  where g2.taxon = ?
#		  and g2.obsolete_flag = 'No'
#		  minus 
#		  select gkt.gene_oid
#		  from gene_ko_terms gkt, ko_term_enzymes kte
#		  where gkt.ko_terms = kte.ko_id) g3,
#		  gene g, gene_candidate_ko_terms gckt,
#		  ko_term_enzymes kte2, ko_term ko
#	    where g.gene_oid = g3.gene_oid
#	    and g.gene_oid = gckt.gene_oid
#	    and gckt.ko_terms = kte2.ko_id
#	    and gckt.ko_terms = ko.ko_id (+)
#	    order by 1 asc, 6 desc
#	};
    my $sql = QueryUtil::getSingleTaxonNoEnzymeWithKOGenesSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    if ($show_myimg_login) {
        # add or replace
        print "<p>\n";
        print "Add or replace MyIMG gene-enzyme annotation:<br/>\n";
        print "  <input type='radio' name='ar_taxgeneec' "
	    . "value='add' checked />Add\n";
        print nbsp(2);
        print "  <input type='radio' name='ar_taxgeneec' "
	    . "value='replace' />Replace\n";
        print "</p>\n";

        printHint("Click '<u>Update MyIMG Annotation</u>' to save your change(s) to the database. " .
		  "Only enzymes associated with the selected gene-KO items will be added to MyIMG annotation.\n");
    }

    print "<p>";
    if ($show_myimg_login) {
        my $name = "_section_${section}_dbUpdTaxonGeneKO";
        print submit(
              -name  => $name,
              -value => "Update MyIMG Annotation",
              -class => "meddefbutton"
        );
        print nbsp(1);
    }

    my $name = "_section_${section}_addToGeneCart0";
    print submit(
          -name  => $name,
          -value => "Add To Gene Cart",
          -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    ### Print the records out in a table.
    my $it = new InnerTable( 0, "taxonGenePriam$$", "taxonGenePriam", 9 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",       "number asc",  "left" );
    $it->addColSpec( "Product Name",         "char asc",    "left" );
    $it->addColSpec( "KO ID",                "char asc",    "left" );
    $it->addColSpec( "KO<br/>Definition",    "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Gene");
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    my $prev_gene = 0;
    my $cnt       = 0;
    for ( ; ; ) {
        my (
             $g1,          $gname,     $aa_seq_length,    $ko1,
             $ename,       $bit_score, $percent_identity, $evalue,
             $query_start, $query_end, $subj_start,       $subj_end
          )
          = $cur->fetchrow();
        last if !$g1;

        if ( $g1 == $prev_gene ) {
            next;
        }
        $cnt++;
        if ( $cnt > 10000000 ) {
            last;
        }

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );

        my $sel_type = 'checkbox';
        my $r;
        $r .=
            "$sd<input type='"
          . $sel_type
          . "' name='tax_gene_enzyme' "
          . "value='$g1,$ko1' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$g1";
        $r   .= $g1 . $sd . alink( $url, $g1 ) . "\t";
        $r   .= "$gname\t";

        my $enzyme_base_url = $env->{enzyme_base_url};
        my $url             = "$enzyme_base_url$ko1";
        $r .= $ko1 . $sd . alink( $url, $ko1 ) . "\t";
        $r .= "$ename\t";

        # scores
        $r .= "$percent_identity\t";
        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length ) . "\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);

        # save prev
        $prev_gene = $g1;
    } 
    $cur->finish();

    $it->printOuterTable(1);

    if ($show_myimg_login) {
        my $name = "_section_${section}_dbUpdTaxonGeneKO";
        print submit(
                      -name  => $name,
                      -value => "Update MyIMG Annotation",
                      -class => "meddefbutton"
        );
        print nbsp(1);
    }

    my $name = "_section_${section}_addToGeneCart0";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "</p>";

    #if ($cnt > 0) {
    #    my $select_id_name = 'gene_oid';
    #    WorkspaceUtil::printSaveGeneToWorkspace_withAllNoEnzymeWithKOGenes($select_id_name);            
    #}

    printStatusLine( "Loaded. (count: $cnt)", 2 );
    print end_form();
}

############################################################################
# dbUpdGeneEnzyme - update gene-enzyme MyIMG annotation
#
# (for selected genes in a taxon)
############################################################################
sub dbUpdTaxonGeneEnzyme {
    my $taxon_oid = param('taxon_oid');
    my @gene_ecs  = param('tax_gene_enzyme');

    if ( scalar(@gene_ecs) == 0 ) {
        return;
    }

    my $dbh = dbLogin();

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $contact_oid = getContactOid();

    my $ar = param('ar_taxgeneec');

    for my $gene_ec (@gene_ecs) {
        my ( $gene_oid, $ec_number ) = split( /\,/, $gene_ec );

        my $gene_ar = $ar;
        my $cnt     =
          db_findCount
	  ( $dbh, 'gene_myimg_functions',
	    "gene_oid = $gene_oid and modified_by = $contact_oid" );

        if ( $cnt == 0 ) {
            # add
            $gene_ar = 'add';
        }

        if ( $gene_ar eq 'replace' ) {
            # delete from gene_myimg_enzymes
            $sql =
                "delete from gene_myimg_enzymes "
              . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            # update gene_myimg_functions
            $sql =
                "update gene_myimg_functions "
              . "set ec_number = '"
              . $ec_number . "' "
              . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            # insert into gene_myimg_enzymes
            $sql =
                "insert into gene_myimg_enzymes "
              . "(gene_oid, ec_number, modified_by, mod_date) "
              . "values ($gene_oid, '$ec_number', $contact_oid, sysdate)";
            push @sqlList, ($sql);

        } else {
            # add
            my $to_update     = 0;
            my @myimg_enzymes =
              db_findSetVal( $dbh, 'gene_myimg_enzymes', 'gene_oid', $gene_oid,
                             'ec_number', "modified_by = $contact_oid" );

            if ( WebUtil::inArray( $ec_number, @myimg_enzymes ) ) {
                # already there
            } else {
                $to_update = 1;
            }

            # gene has myimg annotation?
            my $sql2 = qq{
		select gene_oid, ec_number
		    from gene_myimg_functions
		    where gene_oid = ? and modified_by = ?
		};
            my $cur2 = execSql
		( $dbh, $sql2, $verbose, $gene_oid, $contact_oid );
            my ( $g2, $ec_str ) = $cur2->fetchrow();
            #$cur2->finish();

            if ($to_update) {
                if ($g2) {
                    # update gene_myimg_functions
                    if ( blankStr($ec_str) ) {
                        $ec_str = $ec_number;
                    } else {
                        $ec_str .= " " . $ec_number;
                    }
                    $sql =
                        "update gene_myimg_functions "
                      . "set ec_number = '"
                      . $ec_str . "' "
                      . "where gene_oid = $gene_oid "
                      . "and modified_by = $contact_oid";

                } else {
                    # insert
                    my $prod_name =
                      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid,
                                  'gene_display_name', '' );
                    $prod_name =~ s/'/''/g;    # replace ' with ''
                    $sql =
                        "insert into gene_myimg_functions "
                      . "(gene_oid, product_name, ec_number, "
                      . "modified_by, mod_date) "
                      . "values ($gene_oid, '$prod_name', '$ec_number', "
                      . "$contact_oid, sysdate)";
                }
                push @sqlList, ($sql);
            }

            # insert into gene_myimg_enzymes?
            if ($to_update) {
                $sql =
                    "insert into gene_myimg_enzymes "
                  . "(gene_oid, ec_number, modified_by, mod_date) "
                  . "values ($gene_oid, '$ec_number', $contact_oid, sysdate)";
                push @sqlList, ($sql);
            }
        }
    }    # end for gene_ec

    #$dbh->disconnect();

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    my $err = 0;
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        webError("SQL Error: $sql");
        return -1;
    } else {
        return 1;
    }

}

############################################################################
# dbUpdTaxonGeneKO - update gene-enzyme MyIMG annotation (using KO)
#
# (for selected genes in a taxon)
############################################################################
sub dbUpdTaxonGeneKO {
    my $taxon_oid = param('taxon_oid');
    my @gene_kos  = param('tax_gene_enzyme');

    if ( scalar(@gene_kos) == 0 ) {
        return;
    }

    my $dbh = dbLogin();

    # prepare SQL
    my @sqlList     = ();
    my $sql         = "";
    my $contact_oid = getContactOid();

    my $ar = param('ar_taxgeneec');

    for my $gene_ko (@gene_kos) {
        my ( $gene_oid, $ko_id ) = split( /\,/, $gene_ko );

        my @ecs  = ();
        my $sql2 = "select enzymes from ko_term_enzymes where ko_id = ?";
        my $cur2 = execSql( $dbh, $sql2, $verbose, $ko_id );
        for ( ; ; ) {
            my ($ec_number) = $cur2->fetchrow();
            last if !$ec_number;
            push @ecs, ($ec_number);
        }
        #$cur2->finish();

        my $gene_ar = $ar;
        my $cnt     =
          db_findCount
	  ( $dbh, 'gene_myimg_functions',
	    "gene_oid = $gene_oid and modified_by = $contact_oid" );

        if ( $cnt == 0 ) {
            # add
            $gene_ar = 'add';
        }

        if ( $gene_ar eq 'replace' ) {
            # delete from gene_myimg_enzymes
            $sql =
                "delete from gene_myimg_enzymes "
              . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            # update gene_myimg_functions
            for my $ec_number (@ecs) {
                $sql =
                    "update gene_myimg_functions "
                  . "set ec_number = '"
                  . $ec_number . "' "
                  . "where gene_oid = $gene_oid and modified_by = $contact_oid";
                push @sqlList, ($sql);

                # insert into gene_myimg_enzymes
                $sql =
                    "insert into gene_myimg_enzymes "
                  . "(gene_oid, ec_number, modified_by, mod_date) "
                  . "values ($gene_oid, '$ec_number', $contact_oid, sysdate)";
                push @sqlList, ($sql);
            }

        } else {
            # add
            for my $ec_number (@ecs) {
                my $to_update = 0;
                my @myimg_enzymes = db_findSetVal(
                                       $dbh,        'gene_myimg_enzymes',
                                       'gene_oid',  $gene_oid,
                                       'ec_number', "modified_by = $contact_oid"
                );

                if ( WebUtil::inArray( $ec_number, @myimg_enzymes ) ) {
                    # already there
                } else {
                    $to_update = 1;
                }

                # gene has myimg annotation?
                my $sql2 = qq{
		    select gene_oid, ec_number
			from gene_myimg_functions
			where gene_oid = ? and modified_by = ?
		    };
                my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid, $contact_oid );
                my ( $g2, $ec_str ) = $cur2->fetchrow();
                #$cur2->finish();

                if ($to_update) {
                    if ($g2) {
                        # update gene_myimg_functions
                        if ( blankStr($ec_str) ) {
                            $ec_str = $ec_number;
                        } else {
                            $ec_str .= " " . $ec_number;
                        }
                        $sql =
                            "update gene_myimg_functions "
                          . "set ec_number = '"
                          . $ec_str . "' "
                          . "where gene_oid = $gene_oid "
                          . "and modified_by = $contact_oid";
                    } else {

                        # insert
                        my $prod_name =
                          db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid,
                                      'gene_display_name', '' );
                        $prod_name =~ s/'/''/g;    # replace ' with ''
                        $sql =
                            "insert into gene_myimg_functions "
                          . "(gene_oid, product_name, ec_number, "
                          . "modified_by, mod_date) "
                          . "values ($gene_oid, '$prod_name', "
                          . "'$ec_number', "
                          . "$contact_oid, sysdate)";
                    }
                    push @sqlList, ($sql);
                }

                # insert into gene_myimg_enzymes?
                if ($to_update) {
                    $sql =
                        "insert into gene_myimg_enzymes "
                      . "(gene_oid, ec_number, modified_by, mod_date) "
                      . "values ($gene_oid, '$ec_number', $contact_oid, sysdate)";
                    push @sqlList, ($sql);
                }
            }
        }
    }    # end for gene_ec

    #$dbh->disconnect();

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        webError("SQL Error: $sql");
        return -1;
    } else {
        return 1;
    }

}

############################################################################
# printFindProdNamePage
############################################################################
sub printFindProdNamePage {
    my $gene_oid = param("gene_oid");
    my $disp_opt = param("findProdNameOption");

    if ( !$gene_oid ) {
        webError("No gene was selected. Please select a gene.");
    }

    my $contact_oid = getContactOid();

    my $dbh       = dbLogin();
    my $sessionId = getSessionId();

    printStatusLine( "Loading ...", 1 );

    printMainForm();
    print "<h1>Candidate Product Names for Query Gene (OID: $gene_oid)</h1>\n";

    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );

    #    print "<h2>Query Gene (OID: $gene_oid): " .
    #	escapeHTML($product_name) . "</h2>\n";
    print hidden( 'gene_oid', $gene_oid );

    my $taxon_oid1 =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'taxon', '' );

    print hiddenVar( "gene_oid",  $gene_oid );
    print hiddenVar( "taxon_oid", $taxon_oid1 );

    # show more info for this gene
    print "<table class='img'>\n";

    # taxon
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid1, 0 );
    print "<tr class='img'>\n";
    print "<td class='img'><b>Genome Name</b></td>\n";
    print "  <td class='img'   align='left'>"
      . escapeHTML($taxon_name)
      . "</td>\n";
    print "</tr>\n";

    # gene product name
    print "<tr class='img'>\n";
    print "<td class='img'><b>Gene Product Name</b></td>\n";
    print "  <td class='img'   align='left'>"
      . escapeHTML($product_name)
      . "</td>\n";
    print "</tr>\n";

    # IMG term, if any
    my $term_sql = qq{
	select gif.gene_oid, t.term
	    from gene_img_functions gif, img_term t
	    where gif.gene_oid = ?
	    and gif.function = t.term_oid
	};
    my $terms = db_getValues2( $dbh, $term_sql, "",$gene_oid );
    if ( !blankStr($terms) ) {
        print "<tr class='img'>\n";
        print "<td class='img'><b>IMG Term(s)</b></td>\n";
        print "  <td class='img'   align='left'>"
          . escapeHTML($terms)
          . "</td>\n";
        print "</tr>\n";
    }

    # TIGRfam, if any
    my $tigr_sql = qq{
	select gxf.gene_oid, gxf.description,
	tigr.ext_accession, tigr.isology_type
	    from gene_xref_families gxf, tigrfam tigr 
	    where gxf.gene_oid = ?
	    and gxf.db_name = 'TIGRFam' 
	    and gxf.id = tigr.ext_accession
	};
    my $tigrfam = db_getValues2( $dbh, $tigr_sql, "",$gene_oid );
    if ( !blankStr($tigrfam) ) {
        print "<tr class='img'>\n";
        print "<td class='img'><b>TIGRfam</b></td>\n";
        print "  <td class='img'   align='left'>"
          . escapeHTML($tigrfam)
          . "</td>\n";
        print "</tr>\n";
    }

    # COG, if any
    my $cog_sql = qq{
	select g.gene_oid, c.cog_name
	    from gene_cog_groups g, cog c
	    where g.gene_oid = ?
	    and g.cog = c.cog_id
	};
    my $cog = db_getValues2( $dbh, $cog_sql, "",$gene_oid );
    if ( !blankStr($cog) ) {
        print "<tr class='img'>\n";
        print "<td class='img'><b>COG</b></td>\n";
        print "  <td class='img'   align='left'>"
          . escapeHTML($cog)
          . "</td>\n";
        print "</tr>\n";
    }

    # Pfam
    my $pfam_sql = qq{
	select g.gene_oid, p.description
	    from gene_pfam_families g, pfam_family p
	    where g.gene_oid = ?
	    and g.pfam_family = p.ext_accession
	};
    my $pfam = db_getValues2( $dbh, $pfam_sql, "",$gene_oid );
    if ( !blankStr($pfam) ) {
        print "<tr class='img'>\n";
        print "<td class='img'><b>Pfam</b></td>\n";
        print "  <td class='img'   align='left'>"
          . escapeHTML($pfam)
          . "</td>\n";
        print "</tr>\n";
    }

    # KO
    my $ko_sql = qq{
	select g.gene_oid, ko.definition
	    from gene_ko_terms g, ko_term ko
	    where g.gene_oid = ?
	    and g.ko_terms = ko.ko_id
	};
    my $ko = db_getValues2( $dbh, $ko_sql, "",$gene_oid );
    if ( !blankStr($ko) ) {
        print "<tr class='img'>\n";
        print "<td class='img'><b>KEGG Orthology (KO)</b></td>\n";
        print "  <td class='img'   align='left'>" . escapeHTML($ko) . "</td>\n";
        print "</tr>\n";
    }

    # MyIMG, if any
    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $myimg_name =
          db_findVal( $dbh, 'gene_myimg_functions', 'gene_oid', $gene_oid,
                      'product_name', '' );
        if ( !blankStr($myimg_name) ) {
            print "<tr class='img'>\n";
            print "<td class='img'><b>MyIMG Annotation</b></td>\n";
            print "  <td class='img'   align='left'>"
              . escapeHTML($myimg_name)
              . "</td>\n";
            print "</tr>\n";
        }
    }

    print "</table>\n";

    my @homologRecs;
    require OtfBlast;
    printStartWorkingDiv();
    my $filterType =
      OtfBlast::genePageTopHits( $dbh, $gene_oid, \@homologRecs,
				 "", $img_lite, 1 );
    printEndWorkingDiv();

    my $count = @homologRecs;
    my $cnt1  = printProdNameRecords( \@homologRecs );
    #$dbh->disconnect();
    print end_form();
    printStatusLine( "$cnt1 top hits loaded.", 2 );
}

############################################################################
# printProdNameRecords - Print find prod name result records
#
# (only allow single selection)
############################################################################
sub printProdNameRecords {
    my ($recs_ref) = @_;

    my $contact_oid = getContactOid();
    my $disp_opt    = param("findProdNameOption");
    my $ortho_homo  = "Homolog";

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }

    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    if ( $show_myimg_login && $contact_oid > 0 ) {
        $it->addColSpec("Select");
    }
    $it->addColSpec( "$ortho_homo Gene",         "number asc",  "left" );
    $it->addColSpec( "$ortho_homo Product Name", "char asc",    "left" );
    $it->addColSpec( "IMG Term OID",             "number asc",  "left" );
    $it->addColSpec( "IMG Term",                 "char asc",    "left" );
    $it->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome", "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity",     "number desc", "right" );
    $it->addColSpec( "Alignment<br/>On<br/>Query Gene" );
    $it->addColSpec( "Alignment<br/>On<br/>$ortho_homo Gene" );
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );

    $it->addColSpec( "TIGRfam", "char asc", "left" );
    $it->addColSpec( "COG",     "char asc", "left" );
    $it->addColSpec( "Pfam",    "char asc", "left" );
    $it->addColSpec( "KO Term", "char asc", "left" );

    my $sd  = $it->getSdDelim();
    my $cnt = 0;
    my $dbh = dbLogin();
    my %term_h;

    # get the highest score N hits
    my $get_top_n = 1;
    my $top_n     = 20;
    my $min_score = 0;
    my %gene_score;
    if ($get_top_n) {
        my $sql1 = "select gene_display_name from gene where gene_oid = ?";
        #my $sql2 = "select count(*) from gene_img_functions where gene_oid = ?";
        my $cur1 = prepSql($dbh, $sql1, $verbose);
        #my $cur2 = prepSql($dbh, $sql2, $verbose);
        
        for my $r0 (@$recs_ref) {
            my (
                 $gene_oid1,        $gene_oid2,   $taxon_oid2,
                 $percent_identity, $query_start, $query_end,
                 $subj_start,       $subj_end,    $evalue,
                 $bit_score,        $align_length
              )
              = split( /\t/, $r0 );
            next if $gene_oid1 == $gene_oid2;

            #webLog("$gene_oid2 \n");
            execStmt($cur1, $gene_oid2);
            my ($prod_name2) = $cur1->fetchrow();
#            my $prod_name2 = 
#              db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid2,
#                          'gene_display_name', '' );
            if ( $disp_opt eq 'hideHypothetical' ) {
                my $lc_name2 = lc($prod_name2);
                if ( $lc_name2 =~ /hypothetical protein/ ) {
                    next;
                }
            }

            #execStmt($cur2, $gene_oid2);
            #my ($term_cnt) = $cur2->fetchrow();
#            my $term_cnt =
#              db_findCount( $dbh, 'gene_img_functions',
#                            "gene_oid = ? ", $gene_oid2 );
            #if ( $term_cnt == 0 ) {

                # gene has no terms
                #		 next;
            #}

            if ( $gene_score{$bit_score} ) {
                my $cnt0 = $gene_score{$bit_score};
                $gene_score{$bit_score} = $cnt0 + 1;
            } else {
                $gene_score{$bit_score} = 1;
            }
        }
        $cur1->finish();
        #$cur2->finish();

        sub reverse_num { $b <=> $a; }
        my @scores = sort reverse_num ( keys %gene_score );
        for my $key (@scores) {
            if ( $cnt >= $top_n ) {
                last;
            }

            $cnt += $gene_score{$key};
            $min_score = $key;
        }
    }

    $cnt = 0;
    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,        $gene_oid2,   $taxon_oid2,
             $percent_identity, $query_start, $query_end,
             $subj_start,       $subj_end,    $evalue,
             $bit_score,        $align_length
          )
          = split( /\t/, $r0 );
        next if $gene_oid1 == $gene_oid2;

        if ( $get_top_n && $bit_score < $min_score ) {
            next;
        }

        my $prod_name2 =
          db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid2, 'gene_display_name',
                      '' );
        if ( $disp_opt eq 'hideHypothetical' ) {
            my $lc_name2 = lc($prod_name2);
            if ( $lc_name2 =~ /hypothetical protein/ ) {
                next;
            }
        }

        my @term_oids =
          db_findSetVal( $dbh, 'gene_img_functions', 'gene_oid', $gene_oid2,
                         'function', '' );
        if ( scalar(@term_oids) == 0 ) {

            # gene has no terms
            #	     next;
        }

        my $all_term_oids = "";
        for my $term_oid2 (@term_oids) {
            if ( length($all_term_oids) == 0 ) {
                $all_term_oids = $term_oid2;
            } else {
                $all_term_oids .= "," . $term_oid2;
            }
        }

        my $domain2     = "";
        my $seq_status2 = "";

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $domain2 = substr( $domain2, 0, 1 );
        $seq_status2 = substr( $seq_status2, 0, 1 );
        $bit_score = sprintf( "%d", $bit_score );

        #	 my $sel_type = 'checkbox';
        my $sel_type = 'radio';

        my $r;
        if ( $show_myimg_login && $contact_oid > 0 ) {
            $r .=
                "$sd<input type='"
              . $sel_type
              . "' name='gene_oid_hit' "
              . "value='$gene_oid1,$gene_oid2,$all_term_oids' />\t";
        }

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid2";
        $r   .= $gene_oid2 . $sd . alink( $url, $gene_oid2 ) . "\t";

        # gene product name
        $r .= "$prod_name2\t";

        # term oid and terms
        my $term_names = "";
        for my $term_oid2 (@term_oids) {
            $term_oid2 = FuncUtil::termOidPadded($term_oid2);
            my $url2 = FuncUtil::getUrl( $main_cgi, 'IMG_TERM', $term_oid2 );
            $r .= $term_oid2 . $sd . alink( $url2, $term_oid2 ) . " ";

            my $t2;
            if ( $term_h{$term_oid2} ) {
                $t2 = $term_h{$term_oid2};
            } else {
                $t2 =
                  db_findVal( $dbh, 'img_term', 'term_oid', $term_oid2, 'term',
                              '' );
                $term_h{$term_oid2} = $t2;
            }

            if ( length($term_names) == 0 ) {
                $term_names = $t2;
            } else {
                $term_names .= " | " . $t2;
            }
        }
        $r .= "\t";
        $r .= "$term_names\t";

        my $sql2 = qq{
	     select t.taxon_name, substr(t.domain, 0, 1),
	     substr(t.seq_status, 0, 1)
		 from taxon t, gene g
		 where g.gene_oid = ?
		 and g.taxon = t.taxon_oid
	     };
        my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid2 );
        my ( $taxon_display_name2, $domain2, $seq_status2 ) = $cur2->fetchrow();
        #$cur2->finish();

        $r .= "$domain2\t";
        $r .= "$seq_status2\t";

        my $aa_seq_length1 = geneOid2AASeqLength( $dbh, $gene_oid1 );
        my $aa_seq_length2 = geneOid2AASeqLength( $dbh, $gene_oid2 );

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid2";
        $r   .=
          $taxon_display_name2 . $sd
          . alink( $url, $taxon_display_name2 ) . "\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .=
          $sd . alignImage( $subj_start, $subj_end, $aa_seq_length2 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";

        # TIGRfam
        my $tigr_sql = qq{
            select gxf.gene_oid, gxf.description,
            tigr.ext_accession, tigr.isology_type
                from gene_xref_families gxf, tigrfam tigr 
                where gxf.gene_oid = ?
                and gxf.db_name = 'TIGRFam' 
                and gxf.id = tigr.ext_accession
            };
        my $tigrfam = db_getValues2( $dbh, $tigr_sql, "",$gene_oid2 );
        $r .= "$tigrfam\t";

        # COG
        my $cog_sql = qq{
            select g.gene_oid, c.cog_name
                from gene_cog_groups g, cog c
                where g.gene_oid = ?
                and g.cog = c.cog_id
            };
        my $cog = db_getValues2( $dbh, $cog_sql,"",$gene_oid2 );
        $r .= "$cog\t";

        # Pfam
        my $pfam_sql = qq{
            select g.gene_oid, p.description
                from gene_pfam_families g, pfam_family p
                where g.gene_oid = ?
                and g.pfam_family = p.ext_accession
            };
        my $pfam = db_getValues2( $dbh, $pfam_sql, "",$gene_oid2 );
        $r .= "$pfam\t";

        my $ko_sql = qq{
	     select g.gene_oid, ko.definition
		 from gene_ko_terms g, ko_term ko
		 where g.gene_oid = ?
		 and g.ko_terms = ko.ko_id
	     };
        my $ko = db_getValues2( $dbh, $ko_sql, "",$gene_oid2 );
        $r .= "$ko\t";

        $it->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    $it->printOuterTable(1);

    if ( $cnt == 0 ) {
        return $cnt;
    }

    # show button
    if ( $show_myimg_login && $contact_oid > 0 ) {
        print "<p>\n";
        print "Add or replace MyIMG annotation by the selected gene.<br/>\n";
        print "  <input type='radio' name='ar_myimgprod' "
	    . "value='add' checked />Add\n";
        print nbsp(2);
        print "  <input type='radio' name='ar_myimgprod' "
	    . "value='replace' />Replace\n";
	print "</p>";

        print "<p>Use selected gene:\n";
        print "<select name='fld_myimgprod' class='img' size='1'>\n";
        print "    <option value='prod_name' selected>"
	    . "Gene Product Name</option>\n";
        print "    <option value='term'>IMG Term</option>\n";
        print "    <option value='tigrfam'>TIGRfam</option>\n";
        print "    <option value='cog'>COG</option>\n";
        print "    <option value='pfam'>Pfam</option>\n";
        print "    <option value='ko'>KO Term</option>\n";
        print "</select>\n";
        print "<p>\n";

        my $name = "_section_${section}_dbAddMyImgProdName";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
    }

    return $cnt;
}

############################################################################
# dbAddMyImgProdName
############################################################################
sub dbAddMyImgProdName {
    my $gene_oid_hit = param('gene_oid_hit');

    if ( !$gene_oid_hit ) {
        webError("No gene was selected. Please select a gene.");
        return;
    }

    my ( $gene_oid, $gene_oid2, $all_term_oids ) = split( /\,/, $gene_oid_hit );
    if ( !$gene_oid || !$gene_oid2 ) {
        webError("No gene was selected. Please select a gene.");
        return;
    }

    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Incorrect login.");
        return;
    }

    # login
    my $dbh       = dbLogin();
    my $myimg_cnt =
      db_findCount( $dbh, 'gene_myimg_functions',
                    "gene_oid = $gene_oid and modified_by = $contact_oid" );

    my $ar_myimgprod  = param('ar_myimgprod');
    my $fld_myimgprod = param('fld_myimgprod');

    my $new_prod_name = "";
    if ( $fld_myimgprod eq 'term' ) {
        my $term_sql = qq{
    	    select gif.gene_oid, t.term
    		from gene_img_functions gif, img_term t
    		where gif.gene_oid = ?
    		and gif.function = t.term_oid
	    };
        $new_prod_name = db_getValues2( $dbh, $term_sql, "", $gene_oid2 );
        if ( blankStr($new_prod_name) ) {
            webError("No IMG terms for selected gene $gene_oid2");
            return;
        }
    } elsif ( $fld_myimgprod eq 'tigrfam' ) {
        my $tigr_sql = qq{
    	    select gxf.gene_oid, gxf.description,
    	    tigr.ext_accession, tigr.isology_type
    		from gene_xref_families gxf, tigrfam tigr 
    		where gxf.gene_oid = ?
    		and gxf.db_name = 'TIGRFam' 
    		and gxf.id = tigr.ext_accession
	    };
        $new_prod_name = db_getValues2( $dbh, $tigr_sql, "",$gene_oid2 );
        if ( blankStr($new_prod_name) ) {
            webError("No TIGRfam for selected gene $gene_oid2");
            return;
        }
    } elsif ( $fld_myimgprod eq 'cog' ) {
        my $cog_sql = qq{
	    select g.gene_oid, c.cog_name
		from gene_cog_groups g, cog c
		where g.gene_oid = ?
		and g.cog = c.cog_id
	    };
        $new_prod_name = db_getValues2( $dbh, $cog_sql, "", $gene_oid2 );
        if ( blankStr($new_prod_name) ) {
            webError("No COG for selected gene $gene_oid2");
            return;
        }
    } elsif ( $fld_myimgprod eq 'pfam' ) {
        my $pfam_sql = qq{
	    select g.gene_oid, p.description
		from gene_pfam_families g, pfam_family p
		where g.gene_oid = ?
		and g.pfam_family = p.ext_accession
	    };
        $new_prod_name = db_getValues2( $dbh, $pfam_sql, "", $gene_oid2 );
        if ( blankStr($new_prod_name) ) {
            webError("No Pfam for selected gene $gene_oid2");
            return;
        }
    } elsif ( $fld_myimgprod eq 'ko' ) {
        my $ko_sql = qq{
	    select g.gene_oid, ko.definition
		from gene_ko_terms g, ko_term ko
		where g.gene_oid = ?
		and g.ko_terms = ko.ko_id
	    };
        $new_prod_name = db_getValues2( $dbh, $ko_sql, "",$gene_oid2 );
        if ( blankStr($new_prod_name) ) {
            webError("No KO Term for selected gene $gene_oid2");
            return;
        }
    } else {

        # prod name
        $new_prod_name =
          db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid2, 'gene_display_name',
                      '' );
        if ( blankStr($new_prod_name) ) {
            webError("No gene product name for selected gene $gene_oid2");
            return;
        }
    }

    # prepare SQL
    my @sqlList = ();
    my $sql     = "";

    if ( $myimg_cnt > 0 ) {

        # there is an myimg annot
        my $myimg_name =
          db_findVal( $dbh, 'gene_myimg_functions', 'gene_oid', $gene_oid,
                      'product_name', '' );
        if ( $ar_myimgprod ne 'replace' && !blankStr($myimg_name) ) {
            $new_prod_name = $myimg_name . '; ' . $new_prod_name;
        }

        if ( length($new_prod_name) > 1000 ) {
            $new_prod_name = substr( $new_prod_name, 0, 1000 );
        }
        $new_prod_name =~ s/'/''/g;    # replace ' with ''

        $sql =
"update gene_myimg_functions set product_name = '$new_prod_name', mod_date = sysdate where gene_oid = $gene_oid and modified_by = $contact_oid";
    } else {
        if ( length($new_prod_name) > 1000 ) {
            $new_prod_name = substr( $new_prod_name, 0, 1000 );
        }
        $new_prod_name =~ s/'/''/g;    # replace ' with ''
        $sql =
"insert into gene_myimg_functions (gene_oid, product_name, modified_by, mod_date) values ($gene_oid, '$new_prod_name', $contact_oid, sysdate)";
    }

    #$dbh->disconnect();

    #    webError("SQL: " . $sql);

    # perform database update
    push @sqlList, ($sql);
    my $err = db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return $sql;
    } else {
        return "";
    }
}

### KO
############################################################################
# printKoEcCandidateList
############################################################################
sub printKoEcCandidateList {
    my ($taxon_oid) = param("taxon_oid");
    my $otherTaxonOids = param("otherTaxonOids");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId           = param("funcId");
    my $procId           = param("procId");
    my $database         = param("database");
    my $minPercIdent     = param("minPercIdent");
    my $maxEvalue        = param("maxEvalue");
    my $koEcMinPercIdent = param("koEcMinPercIdent");
    my $koEcMaxEvalue    = param("koEcMaxEvalue");
    my $koEcBitScore     = param("koEcBitScore");
    my $koEcMinPercAlign = param("koEcMinPercSAlign");
    my ( $tag, $term_oid ) = split( /:/, $funcId );

    print "<h1>Candidate Genes for Missing Enzyme Using KO</h1>\n";

    my $dbh = dbLogin();

    my $func_name = "";
    if ( $tag eq 'EC' ) {
        $func_name = enzymeName( $dbh, $funcId );
    } else {
        #$dbh->disconnect();
        webError("This function is only applicable to enzymes.");
        return;
    }

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h3>Genome: " . escapeHTML($taxon_display_name) . "</h3>\n";
    print "<h3>Function: ($funcId) " . escapeHTML($func_name) . "</h3>\n";

    my $roi_label = param('roi_label');
    my $match_ko = "";
    if ( $roi_label ) {
	print hiddenVar( "roi_label",  $roi_label );
	$match_ko = 'KO:' . $roi_label;
    }

    if ( $funcId =~ /^EC/ ) {
	## show KO too
	my $sql2 = "select k.ko_id, k.ko_name, k.definition from ko_term k, ko_term_enzymes kte where kte.enzymes = ? and kte.ko_id = k.ko_id";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $funcId );
	for (;;) { 
	    my ($ko2, $name2, $def2) = $cur2->fetchrow();
	    last if ! $ko2; 

	    if ( $match_ko && ($match_ko ne $ko2) ) {
		next;
	    }
	    print "<p>$ko2 ($name2): $def2\n";
	}
	$cur2->finish(); 
    }

    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "otherTaxonOids",   $otherTaxonOids );
    print hiddenVar( "funcId",           $funcId );
    print hiddenVar( "procId",           $procId );
    print hiddenVar( "minPercIdent",     $minPercIdent );
    print hiddenVar( "maxEvalue",        $maxEvalue );
    print hiddenVar( "koEcMinPercIdent", $koEcMinPercIdent );
    print hiddenVar( "koEcMaxEvalue",    $koEcMaxEvalue );
    print hiddenVar( "koEcBitScore",     $koEcBitScore );
    print hiddenVar( "koEcMinPercAlign", $koEcMinPercAlign );
    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    # pathway_oid?
    my $pathway_oid = param("pathway_oid");
    if ($pathway_oid) {
        print hiddenVar( "pathway_oid", $pathway_oid );
    }
    my $map_id = param("map_id");
    if ($map_id) {
        print hiddenVar( "map_id", $map_id );
    }

    my @recs = getKoEcRecords();

    my $cnt1 = printKoEcRecords( \@recs );

    #$dbh->disconnect();
    print end_form();
    printStatusLine( "$cnt1 candidate genes found.", 2 );
}

############################################################################
# getKoEcRecords
# (This will be for EC only)
############################################################################
sub getKoEcRecords {
    my ($taxon_oid) = param("taxon_oid");

    # all functions in the profile
    my @func_ids = param("func_id");

    # selected term func ID
    my $funcId       = param("funcId");
    my $procId       = param("procId");
    my $database     = param("database");
    my $minPercIdent = param("koEcMinPercIdent");
    my $maxEvalue    = param("koEcMaxEvalue");
    my $bitScore     = param("koEcBitScore");
    my $minPercAlign = param("koEcMinPercSAlign");

    my ( $tag, $term_oid ) = split( /:/, $funcId );

    my $dbh = dbLogin();

    # ko
    my $taxonClause = "";
    my $sql         = qq{
	 select g1.gene_oid, g1.gene_display_name,
	 kt.ko_id, kt.definition,
	 g1.aa_seq_length, gckt.align_length, gckt.percent_identity,
	 gckt.bit_score, gckt.evalue,
	 gckt.query_start, gckt.query_end, gckt.subj_start, gckt.subj_end
	     from gene g1, gene_candidate_ko_terms gckt,
	     ko_term kt, ko_term_enzymes kte
	     where g1.gene_oid = gckt.gene_oid
	     and g1.taxon = ?
	     and gckt.ko_terms = kt.ko_id
	     and gckt.ko_terms = kte.ko_id
	     and kte.enzymes = ?
	     and gckt.percent_identity >= ?
	     and gckt.evalue <= ?
	     and gckt.bit_score >= ?
         $taxonClause
	 };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $funcId, $minPercIdent, $maxEvalue, $bitScore );
    my @ko_ec_recs;
    for ( ; ; ) {
        my (
             $gene_oid1,        $gene_display_name1, $ko_id,
             $ko_def,           $aa_seq_length1,     $align_length,
             $percent_identity, $bit_score,          $evalue,
             $query_start,      $query_end,          $subj_start,
             $subj_end
          )
          = $cur->fetchrow();
        last if !$gene_oid1;

        # check percent alignment
        if ( $aa_seq_length1 > 0 ) {
            my $qfrac =
              ( $query_end - $query_start + 1 ) * 100 / $aa_seq_length1;
            if ( $qfrac < $minPercAlign ) {
                next;
            }
        } else {
            next;
        }

        my $r;
        $r .= "$gene_oid1\t";
        $r .= "$gene_display_name1\t";
        $r .= "$ko_id\t$ko_def\t";
        $r .= "$aa_seq_length1\t";
        $r .= "$align_length\t";
        $r .= "$percent_identity\t";
        $r .= "$bit_score\t";
        $r .= "$evalue\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        push( @ko_ec_recs, $r );
    }
    $cur->finish();

    return @ko_ec_recs;
}

############################################################################
# printRecordsWithKoEc - Print records of output.
#
# (for both homologs/orthologs and KO)
############################################################################
sub printRecordsWithKoEc {
    my ( $ortho_homo, $tag, $recs_ref, $ko_ec_recs_ref ) = @_;

    my $nRecs     = @$recs_ref;
    my $nKoEcRecs = @$ko_ec_recs_ref;
    if ( $nRecs == 0 && $nKoEcRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Gene",         "number asc", "left" );
    $it->addColSpec( "Candidate Gene Product", "char asc",   "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for Candidate Gene", "char asc", "left" );
    }
    $it->addColSpec( "$ortho_homo Gene", "number asc", "left" );
    $it->addColSpec( "$ortho_homo Gene Product<br/>(IMG Term)",
                     "char asc", "left" );
    if ( $tag eq 'EC' ) {
        $it->addColSpec( "Enzyme for $ortho_homo Gene", "char asc", "left" );
    }

    $it->addColSpec( "Domain",               "char asc",    "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",               "char asc",    "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",               "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec( "Alignment<br/>On<br/>Candidate");
    $it->addColSpec( "Alignment<br/>On<br/>$ortho_homo");
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );

    $it->addColSpec("Confirmed<br/>by KO?");
    $it->addColSpec( "KO ID",                           "number asc", "left" );
    $it->addColSpec( "KO Definition",                   "char asc",   "left" );
    $it->addColSpec( "Enzymes associated with this KO", "char asc",   "left" );
    $it->addColSpec( "KO Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("KO Alignment<br/>On<br/>Candidate");
    $it->addColSpec( "KO E-value",       "number asc",  "left" );
    $it->addColSpec( "KO Bit<br/>Score", "number desc", "right" );

    my $sd = $it->getSdDelim();

    # organize KO data
    my %ko_ec_h;
    for my $r2 (@$ko_ec_recs_ref) {
        my (
             $gene_oid1,        $gene_display_name1, $ko_id,
             $ko_def,           $aa_seq_length1,     $align_length,
             $percent_identity, $bit_score,          $evalue,
             $query_start,      $query_end,          $subj_start,
             $subj_end
          )
          = split( /\t/, $r2 );
        $ko_ec_h{$gene_oid1} =
"$gene_display_name1\t$ko_id\t$ko_def\t$query_start\t$query_end\t$aa_seq_length1\t$percent_identity\t$bit_score\t$evalue";
    }

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;
    my $dbh             = dbLogin();
    my $enzyme_base_url = $env->{enzyme_base_url};

    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );
        if ( $gene_score{$gene_oid1} ) {

            # already has some hit. compare.
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $bit_score > $score2 ) {

                # replace
                $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
            } else {

                # keep original one
            }
        } else {

            # new one
            $gene_score{$gene_oid1} = $gene_oid2 . "," . $bit_score;
        }
    }

    for my $r0 (@$recs_ref) {
        my (
             $gene_oid1,   $gene_display_name1,  $aa_seq_length1,
             $gene_oid2,   $gene_display_name2,  $aa_seq_length2,
             $taxon_oid2,  $taxon_display_name2, $domain2,
             $seq_status2, $percent_identity,    $bit_score,
             $evalue,      $query_start,         $query_end,
             $subj_start,  $subj_end
          )
          = split( /\t/, $r0 );

        if ( $gene_score{$gene_oid1} ) {
            my ( $g2, $score2 ) = split( /,/, $gene_score{$gene_oid1} );
            if ( $g2 == $gene_oid2 ) {

                # continue output
            } else {

                # skip
                next;
            }
        } else {

            # shouldn't happen
            next;
        }

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $domain2 = substr( $domain2, 0, 1 );
        $seq_status2 = substr( $seq_status2, 0, 1 );
        $bit_score = sprintf( "%d", $bit_score );
        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$gene_oid1,$gene_oid2' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid1";
        $r   .= $gene_oid1 . $sd . alink( $url, $gene_oid1 ) . "\t";
        $r   .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($gene_oid1);
        $r .= "$enzyme1\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid2";
        $r   .= $gene_oid2 . $sd . alink( $url, $gene_oid2 ) . "\t";
        $r   .= "$gene_display_name2\t";

        my $enzyme2 = getEnzymeForGene($gene_oid2);
        $r .= "$enzyme2\t";

        $r .= "$domain2\t";
        $r .= "$seq_status2\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid2";
        $r   .=
          $taxon_display_name2 . $sd
          . alink( $url, $taxon_display_name2 ) . "\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .=
          $sd . alignImage( $subj_start, $subj_end, $aa_seq_length2 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";

        if ( $ko_ec_h{$gene_oid1} ) {
            my (
                 $gene_name1,         $ko_id,
                 $ko_def,             $ko_ec_query_start,
                 $ko_ec_query_end,    $ko_ec_aa_seq_length1,
                 $ko_ec_percent_iden, $ko_ec_bit_score,
                 $ko_ec_evalue
              )
              = split( /\t/, $ko_ec_h{$gene_oid1} );
            $ko_ec_bit_score = sprintf( "%d",   $ko_ec_bit_score );
            $ko_ec_evalue    = sprintf( "%.2e", $ko_ec_evalue );
            $r .= "Yes\t";
            my $ko_url =
                "main.cgi?section=KeggPathwayDetail&page=koterm2"
              . "&ko_id=$ko_id";
            $r .= $ko_id . $sd . alink( $ko_url, $ko_id ) . "\t";
            $r .= "$ko_def\t";

            # enzymes associated with ko
            my $sql2 =
                "select ko_id, enzymes from ko_term_enzymes "
              . "where ko_id = '"
              . $ko_id . "'";
            my @ko_enzymes = db_getValues( $dbh, $sql2 );
            my $ko_enzyme_list = '';
            for my $val2 (@ko_enzymes) {
                my ( $val2_id, $val2_ec ) = split( /\t/, $val2 );

                # my $url2 = "$enzyme_base_url$val2_ec";
                # $val2_ec = $val2_ec . $sd . alink( $url2, $val2_ec );

                if ( blankStr($ko_enzyme_list) ) {
                    $ko_enzyme_list = $val2_ec;
                } else {
                    $ko_enzyme_list .= ", " . $val2_ec;
                }
            }
            $r .= "$ko_enzyme_list\t";

            $r .= "$ko_ec_percent_iden\t";
            $r .= $sd
              . alignImage( $ko_ec_query_start, $ko_ec_query_end,
                            $ko_ec_aa_seq_length1 )
              . "\t";
            $r .= "$ko_ec_evalue\t";
            $r .= "$ko_ec_bit_score\t";
        } else {
            $r .= "No\t\t\t\t\t";
        }
        $it->addRow($r);
    }

    # print the genes that only have KO hits
    for my $key ( keys %ko_ec_h ) {
        if ( $gene_score{$key} ) {

            # skip
            next;
        }

        # display
        my (
             $gene_display_name1, $ko_id,
             $ko_def,             $ko_ec_query_start,
             $ko_ec_query_end,    $ko_ec_aa_seq_length1,
             $ko_ec_percent_iden, $ko_ec_bit_score,
             $ko_ec_evalue
          )
          = split( /\t/, $ko_ec_h{$key} );
        $ko_ec_bit_score = sprintf( "%d",   $ko_ec_bit_score );
        $ko_ec_evalue    = sprintf( "%.2e", $ko_ec_evalue );

        my $r;
        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$key,' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$key";
        $r   .= $key . $sd . alink( $url, $key ) . "\t";
        $r   .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($key);
        $r .= "$enzyme1\t";

        $r .= "\t\t\t\t\t\t\t\t\t\t\t";
        $r .= "Yes\t";
        my $ko_url =
          "main.cgi?section=KeggPathwayDetail&page=koterm2" . "&ko_id=$ko_id";
        $r .= $ko_id . $sd . alink( $ko_url, $ko_id ) . "\t";
        $r .= "$ko_def\t";

        # enzymes associated with ko
        my $sql2 =
            "select ko_id, enzymes from ko_term_enzymes "
          . "where ko_id = '"
          . $ko_id . "'";
        my @ko_enzymes = db_getValues( $dbh, $sql2 );
        my $ko_enzyme_list = '';
        for my $val2 (@ko_enzymes) {
            my ( $val2_id, $val2_ec ) = split( /\t/, $val2 );

            # my $url2 = "$enzyme_base_url$val2_ec";
            # $val2_ec = $val2_ec . $sd . alink( $url2, $val2_ec );

            if ( blankStr($ko_enzyme_list) ) {
                $ko_enzyme_list = $val2_ec;
            } else {
                $ko_enzyme_list .= ", " . $val2_ec;
            }
        }
        $r .= "$ko_enzyme_list\t";

        $r .= "$ko_ec_percent_iden\t";
        $r .= $sd
          . alignImage( $ko_ec_query_start, $ko_ec_query_end,
                        $ko_ec_aa_seq_length1 )
          . "\t";
        $r .= "$ko_ec_evalue\t";
        $r .= "$ko_ec_bit_score\t";

        $it->addRow($r);
        $cnt++;
    }
    #$dbh->disconnect();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    $it->printOuterTable(1);

    print "<p>\n";

    #     my $funcId =  param( "funcId" );
    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    if ( $tag eq 'ITERM'
         && canEditGeneTerm( $dbh, $contact_oid ) )
    {
        my $name = "_section_${section}_addAssoc";
        print submit(
                      -name  => $name,
                      -value => "Add Term to Candidate Gene(s)",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    } elsif ( $tag eq 'EC' && $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyImgEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    my $name = "_section_${section}_addToGeneCart4";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";

    return $cnt;
}

############################################################################
# printKoEcRecords - Print records of output.
#
# (for KO only)
############################################################################
sub printKoEcRecords {
    my ($ko_ec_recs_ref) = @_;

    my $nKoEcRecs = @$ko_ec_recs_ref;
    if ( $nKoEcRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }
    my $it = new InnerTable( 0, "missingGenes$$", "missingGenes", 12 );
    $it->addColSpec("Select");
    $it->addColSpec( "Candidate Gene",            "number asc", "left" );
    $it->addColSpec( "Candidate Gene Product",    "char asc",   "left" );
    $it->addColSpec( "Enzyme for Candidate Gene", "char asc",   "left" );

    $it->addColSpec("Confirmed<br/>by KO?");
    $it->addColSpec( "KO ID",                           "number asc", "left" );
    $it->addColSpec( "KO Definition",                   "char asc",   "left" );
    $it->addColSpec( "Enzymes associated with this KO", "char asc",   "left" );
    $it->addColSpec( "KO Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("KO Alignment<br/>On<br/>Candidate");
    $it->addColSpec( "KO E-value",       "number asc",  "left" );
    $it->addColSpec( "KO Bit<br/>Score", "number desc", "right" );

    my $sd = $it->getSdDelim();

    # organize KO data
    my $cnt             = 0;
    my $dbh             = dbLogin();
    my $enzyme_base_url = $env->{enzyme_base_url};

    for my $r2 (@$ko_ec_recs_ref) {
        my (
             $gene_oid1,        $gene_display_name1, $ko_id,
             $ko_def,           $aa_seq_length1,     $align_length,
             $percent_identity, $ko_ec_bit_score,    $ko_ec_evalue,
             $query_start,      $query_end,          $subj_start,
             $subj_end
          )
          = split( /\t/, $r2 );

        $ko_ec_bit_score = sprintf( "%d",   $ko_ec_bit_score );
        $ko_ec_evalue    = sprintf( "%.2e", $ko_ec_evalue );

        $cnt++;
        my $r;

        $r .=
            "$sd<input type='checkbox' name='gene_oid_hit' "
          . "value='$gene_oid1' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid1";
        $r   .= $gene_oid1 . $sd . alink( $url, $gene_oid1 ) . "\t";

        $r .= "$gene_display_name1\t";

        my $enzyme1 = getEnzymeForGene($gene_oid1);
        $r .= "$enzyme1\t";

        $r .= "Yes\t";
        my $ko_url =
          "main.cgi?section=KeggPathwayDetail&page=koterm2" . "&ko_id=$ko_id";
        $r .= $ko_id . $sd . alink( $ko_url, $ko_id ) . "\t";
        $r .= "$ko_def\t";

        # enzymes associated with ko
        my $sql2 =
            "select ko_id, enzymes from ko_term_enzymes "
          . "where ko_id = '"
          . $ko_id . "'";
        my @ko_enzymes = db_getValues( $dbh, $sql2 );
        my $ko_enzyme_list = '';
        for my $val2 (@ko_enzymes) {
            my ( $val2_id, $val2_ec ) = split( /\t/, $val2 );

            # my $url2 = "$enzyme_base_url$val2_ec";
            # $val2_ec = $val2_ec . $sd . alink( $url2, $val2_ec );

            if ( blankStr($ko_enzyme_list) ) {
                $ko_enzyme_list = $val2_ec;
            } else {
                $ko_enzyme_list .= ", " . $val2_ec;
            }
        }
        $r .= "$ko_enzyme_list\t";

        $r .= "$percent_identity\t";
        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";
        $r .= "$ko_ec_evalue\t";
        $r .= "$ko_ec_bit_score\t";

        $it->addRow($r);
    }
    #$dbh->disconnect();

    $it->printOuterTable(1);

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();

    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyImgEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    my $name = "_section_${section}_addToGeneCart4";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => 'smdefbutton'
    );
    print nbsp(1);

    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    return $cnt;
}

############################################################################
# printGeneKOEnzymeList
############################################################################
sub printGeneKOEnzymeList {
    my $gene_oid = param("gene_oid");

    print "<h1>Candidate Enzymes Using Kegg Onthology (KO)</h1>\n";

    my $dbh          = dbLogin();
    my $product_name =
      db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name',
                  '' );
    #$dbh->disconnect();
    print "<h3>Gene ($gene_oid): " . escapeHTML($product_name) . "</h3>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( "gene_oid", $gene_oid );

    my @recs = getGeneKOEnzymeRecords($gene_oid);
    my $cnt1 = printGeneKOEnzymeRecords( \@recs );

    print end_form();
    printStatusLine( "$cnt1 candidate enzymes found.", 2 );
}

############################################################################
# getGeneKOEnzymeRecords
############################################################################
sub getGeneKOEnzymeRecords {
    my ($gene_oid) = @_;

    my $dbh = dbLogin();

    # candidate ko enzymes
    my $sql = qq{
	 select e1.ec_number, e1.enzyme_name, 
	 kt.ko_id, kt.definition, g1.aa_seq_length,
	 gckt.align_length, gckt.percent_identity,
	 gckt.bit_score, gckt.evalue,
	 gckt.query_start, gckt.query_end, 
	 gckt.subj_start, gckt.subj_end
	     from enzyme e1, gene_candidate_ko_terms gckt,
	     ko_term kt, ko_term_enzymes kte, gene g1
	     where gckt.gene_oid = ?
	     and gckt.gene_oid = g1.gene_oid
	     and kt.ko_id = gckt.ko_terms
	     and gckt.ko_terms = kte.ko_id
	     and e1.ec_number = kte.enzymes
	     and gckt.bit_score >= 0
	 };

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @ko_ec_recs;
    for ( ; ; ) {
        my (
             $ec_number,        $enzyme_name1,   $ko_id,
             $ko_def,           $aa_seq_length1, $align_length,
             $percent_identity, $bit_score,      $evalue,
             $query_start,      $query_end,      $subj_start,
             $subj_end
          )
          = $cur->fetchrow();
        last if !$ec_number;

        my $r;
        $r .= "$ec_number\t";
        $r .= "$enzyme_name1\t";
        $r .= "$ko_id\t";
        $r .= "$ko_def\t";
        $r .= "$aa_seq_length1\t";
        $r .= "$align_length\t";
        $r .= "$percent_identity\t";
        $r .= "$bit_score\t";
        $r .= "$evalue\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        push( @ko_ec_recs, $r );
    }
    $cur->finish();

    return @ko_ec_recs;
}

############################################################################
# printGeneKOEnzymeRecords - Print records of output from KO results
############################################################################
sub printGeneKOEnzymeRecords {
    my ($recs_ref) = @_;

    my $nRecs = @$recs_ref;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        printMessage("No candidates found.<br/>\n");
        print "</p>\n";
        return 0;
    }

    my $contact_oid = getContactOid();

    my $it = new InnerTable( 0, "missingEnzymes$$", "missingEnzymes", 12 );
    if ( $show_myimg_login && $contact_oid > 0 ) {
        $it->addColSpec("Select");
    }
    $it->addColSpec( "Candidate Enzyme",                "number asc", "left" );
    $it->addColSpec( "Enzyme Name",                     "char asc",   "left" );
    $it->addColSpec( "KO ID",                           "number asc", "left" );
    $it->addColSpec( "KO Defnition",                    "char asc",   "left" );
    $it->addColSpec( "Enzymes associated with this KO", "char asc",   "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Candidate");

    # need to hide this one for the time being, because the other
    # seq length is not stored in database
    #     $it->addColSpec( "Alignment<br/>On<br/>KO Result" );

    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    my $sd = $it->getSdDelim();

    # get the highest score hits
    my $cnt = 0;
    my %gene_score;
    my $dbh = dbLogin();
    for my $r0 (@$recs_ref) {
        my (
             $ec_number,        $enzyme_name,    $ko_id,
             $ko_def,           $aa_seq_length1, $align_length,
             $percent_identity, $bit_score,      $evalue,
             $query_start,      $query_end,      $subj_start,
             $subj_end
          )
          = split( /\t/, $r0 );

        $cnt++;

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.2e", $evalue );
        $bit_score        = sprintf( "%d",   $bit_score );
        my $r;
        if ( $show_myimg_login && $contact_oid > 0 ) {
            $r .=
                "$sd<input type='checkbox' name='ec_hit' "
              . "value='$ec_number' />\t";
        }

        my $enzyme_base_url = $env->{enzyme_base_url};
        my $url             = "$enzyme_base_url$ec_number";

        $r .= $ec_number . $sd . alink( $url, $ec_number ) . "\t";
        $r .= "$enzyme_name\t";

        my $ko_url =
          "main.cgi?section=KeggPathwayDetail&page=koterm2" . "&ko_id=$ko_id";
        $r .= $ko_id . $sd . alink( $ko_url, $ko_id ) . "\t";
        $r .= "$ko_def\t";

        # enzymes associated with ko
        my $sql2 =
            "select ko_id, enzymes from ko_term_enzymes "
          . "where ko_id = '"
          . $ko_id . "'";
        my @ko_enzymes = db_getValues( $dbh, $sql2 );
        my $ko_enzyme_list = '';
        for my $val2 (@ko_enzymes) {
            my ( $val2_id, $val2_ec ) = split( /\t/, $val2 );

            # my $url2 = "$enzyme_base_url$val2_ec";
            # $val2_ec = $val2_ec . $sd . alink( $url2, $val2_ec );

            if ( blankStr($ko_enzyme_list) ) {
                $ko_enzyme_list = $val2_ec;
            } else {
                $ko_enzyme_list .= ", " . $val2_ec;
            }
        }
        $r .= "$ko_enzyme_list\t";

        $r .= "$percent_identity\t";

        $r .=
          $sd . alignImage( $query_start, $query_end, $aa_seq_length1 ) . "\t";

        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $it->addRow($r);
    }
    #$dbh->disconnect();

    $it->printOuterTable(1);

    my $dbh = dbLogin();

    if ( $show_myimg_login && $contact_oid > 0 ) {
        my $name = "_section_${section}_addMyGeneEnzyme";
        print submit(
                      -name  => $name,
                      -value => "Add to MyIMG Annotation",
                      -class => "lgdefbutton"
        );
        print nbsp(1);
    }

    # this should be add to function cart (enzyme)
    #    my $name = "_section_${section}_addToGeneCart5";
    #    print submit( -name => $name,
    #		 -value => "Add To Gene Cart 5", -class => 'smdefbutton' );
    #    print nbsp( 1 );

    if ( $show_myimg_login && $contact_oid > 0 ) {
        print "<input type='button' name='selectAll' value='Select All' "
          . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All' "
          . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
        print "<br/>\n";
    }

    return $cnt;
}

1;
