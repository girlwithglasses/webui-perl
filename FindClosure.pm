###########################################################################
# FindClosure
############################################################################
package FindClosure;

use strict;
use CGI qw( :standard);
use CGI::Session;
use Data::Dumper;
use DBI;
use InnerTable;
use WebConfig;
use WebUtil;
use DataEntryUtil;
use FuncUtil;
use ChartUtil;
use GeneCartStor;


$| = 1;

my $section              = "FindClosure";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $tmp_dir              = $env->{tmp_dir};
my $tmp_url  = $env->{tmp_url};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";

my $max_func = 5;
my $debug = 0;



############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $sid  = getContactOid();

    if ( $page eq "test" ) {
        # display list of user's save gene cart
    } elsif ( $page eq "listGenes" ) {
    	listGenes();
    } elsif ( $page eq "listFuncGenes" ) {
    	listFuncGenes();
    } elsif ( $page eq "addToFuncCart" ||
	      paramMatch("addToFuncCart") ne "" ) {
    	# add selected functions to Function Cart
    	my @func_ids = param('new_func_id');
    	if ( scalar(@func_ids) > 0 ) {
    	    require FuncCartStor;
    	    my $fc = new FuncCartStor();
    	    $fc->addFuncBatch( \@func_ids );
    	    $fc->printFuncCartForm( '', 1 );
    	}
    	else {
    	    webError("No functions have been selected.");
    	    return;
    	}
    } elsif ( paramMatch("saveFunctionCart") ) {
        # saveFunctionCart();
    } elsif(paramMatch("addGeneCart") ne "") { 
	my @gene_oids = param("gene_oid");
        my $gc = new GeneCartStor(); 

        $gc->addGeneBatch( \@gene_oids ); 
        $gc->printGeneCartForm( '', 1 ); 
    } elsif($page eq "listHistogramGenes" ||
	    paramMatch("listHistogramGenes") ne "") {
	my $range = param('range');
	my $gene_per_taxon = 0;
	if ( $range ) {
	    my ($r1, $r2) = split(/\:/, $range);
	    $gene_per_taxon = $r1;
	}

	if ( ! $gene_per_taxon ) {
	    webError("No row is selected.");
	    return;
	}

	printNextPage(2, $gene_per_taxon);
    } elsif(paramMatch("showGenes") ne "") {
	printNextPage(1);
    } elsif(paramMatch("showNext") ne "") {
	printNextPage();
    } else {
        printMainPage();
    }
}


############################################################################
# funcGeneCond
############################################################################
sub funcGeneCond {
    my ($gene_attr) = @_;

    my $rclause   = WebUtil::urClause('gg.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('gg.taxon');

    my $cond = qq{
      and $gene_attr in (
        select gg.gene_oid from gene gg 
        where gg.locus_type = 'CDS' 
        and gg.obsolete_flag = 'No' 
        and gg.taxon in (
          select tt.taxon_oid from taxon tt 
          where tt.domain in ('Archaea', 'Bacteria', 'Eukaryota')
        )
        $rclause 
        $imgClause
      )
    };

    return $cond;
}

############################################################################
# funcTaxonCond
############################################################################
sub funcTaxonCond {
    my ($taxon_attr) = @_;

    my $rclause   = WebUtil::urClause($taxon_attr);
    my $imgClause = WebUtil::imgClauseNoTaxon($taxon_attr);

    my $cond = qq{
      and $taxon_attr in (
          select tt.taxon_oid from taxon tt 
          where tt.domain in ('Archaea', 'Bacteria', 'Eukaryota')
      )
      $rclause 
      $imgClause
    };

    return $cond;
}


############################################################################
# printMainPage
############################################################################
sub printMainPage {
    my $sid = getContactOid();

    printMainForm();
    print "<h1>Find Functional Closure</h1>\n";

    print "<p>Analysis is based on isolate genomes only.\n";

    timeout( 60 * 15 );

    my @func_ids = param("func_id");
    if ( scalar(@func_ids) == 0 ) {
	print "<p>No function has been selected.\n";
	print end_form();
	return;
    }

    my $new_func = param("new_func");

    my $func_id = $func_ids[0];
    print "<h2>Selected function: $func_id</h2>\n";

    my $curr_func = "";
    my $cond0 = "";
    my $gf_name = "gene";
    my $gene_cnt_query = "";

    if ( $func_id =~ /^COG/ ) {
    	# COG function
    	$curr_func = 'COG';
    	print hiddenVar("cog_id", $func_id);
    	$gene_cnt_query = "select count(distinct gcg.gene_oid) from gene_cog_groups gcg where gcg.cog = '$func_id'" . funcTaxonCond("gcg.taxon");
    	$cond0 = "select gcg.gene_oid from gene_cog_groups gcg " .
	    "where gcg.cog = '$func_id'";
	$gf_name = "gene_cog_groups";
    }
    elsif ( $func_id =~ /^pfam/ ) {
    	# Pfam function
    	$curr_func = 'Pfam';
    	print hiddenVar("pfam_id", $func_id);
    	$gene_cnt_query = "select count(distinct gpf.gene_oid) from gene_pfam_families gpf where gpf.pfam_family = '$func_id'" . funcTaxonCond("gpf.taxon");
    	$cond0 = "select gpf.gene_oid from gene_pfam_families gpf " .
	    "where gpf.pfam_family = '$func_id'";
	$gf_name = "gene_pfam_families";
    }
    elsif ( $func_id =~ /^TIGR/ ) {
    	# TIGRfam function
    	$curr_func = 'TIGRfam';
    	print hiddenVar("tigrfam_id", $func_id);
    	$gene_cnt_query = "select count(distinct gt.gene_oid) from gene_tigrfams gt where gt.ext_accession = '$func_id'" . funcTaxonCond("gt.taxon");
    	$cond0 = "select gt.gene_oid from gene_tigrfams gt where gt.ext_accession = '$func_id'";
	$gf_name = "gene_tigrfams";
    }
    elsif ( $func_id =~ /^EC\:/ ) {
    	# KO function
    	$curr_func = 'EC';
    	print hiddenVar("ec_id", $func_id);
    	$gene_cnt_query = "select count(distinct gke.gene_oid) from gene_ko_enzymes gke where gke.enzymes = '$func_id'" . funcTaxonCond("gke.taxon");
    	$cond0 = "select gke.gene_oid from gene_ko_enzymes gke where gke.enzymes = '$func_id'";
	$gf_name = "gene_ko_enzymes";
    }
    elsif ( $func_id =~ /^KO/ ) {
    	# KO function
    	$curr_func = 'KO';
    	print hiddenVar("ko_id", $func_id);
    	$gene_cnt_query = "select count(distinct gkt.gene_oid) from gene_ko_terms gkt where gkt.ko_terms = '$func_id'" . funcTaxonCond("gkt.taxon");
    	$cond0 = "select gkt.gene_oid from gene_ko_terms gkt " .
	    "where gkt.ko_terms = '$func_id'";
	$gf_name = "gene_ko_terms";
    }
    elsif ( $func_id =~ /^ITERM\:/ ) {
    	# KO function
    	$curr_func = 'IMG Term';
    	print hiddenVar("term_id", $func_id);
    	my ($tag, $val) = split(/\:/, $func_id);
    	if ( ! $val || ! isInt($val) ) {
    	    $val = 0;
    	}
    	$gene_cnt_query = "select count(distinct gif.gene_oid) from gene_img_functions gif where gif.function = $val" . funcTaxonCond("gif.taxon");
    	$cond0 = "select gif.gene_oid from gene_img_functions gif " .
	    "where gif.function = $val";
	$gf_name = "gene_img_functions";
    }
    elsif ( $func_id =~ /^IPR/ ) {
    	# InterPro function
    	$curr_func = 'InterPro';
    	print hiddenVar("interpro_id", $func_id);
    	$gene_cnt_query = "select count(distinct gi.gene_oid) from gene_xref_families gi where gi.db_name = 'InterPro' and gi.id = '$func_id'" . funcTaxonCond("gi.taxon");
    	$cond0 = "select gi.gene_oid from gene_xref_families gi " .
	    "where gi.db_name = 'InterPro' and gi.id = '$func_id'";
	$gf_name = "gene_xref_families";
    }
    elsif ( $func_id =~ /^SEED/ ) {
    	# InterPro function
    	$curr_func = 'SEED';
    	print hiddenVar("seed_id", $func_id);
    	my $s2 = $func_id;
    	if ( length($s2) > 5 ) {
    	    $s2 = substr($s2, 5);
    	}
    	$gene_cnt_query = "select count(distinct gi.gene_oid) from gene_seed_names gi where gi.subsystem = '$s2'" . funcTaxonCond("gi.taxon");
    	$cond0 = "select gi.gene_oid from gene_xref_families gi " .
	    "where gi.db_name = 'InterPro' and gi.id = '$func_id'";
	$gf_name = "gene_xref_families";
    }
    else {
    	# unknown function
    	print "<p>Find Closure is not supported for this function type: $func_id.\n";
    	return;
    }


    if ( $curr_func eq $new_func ) {
	print hiddenVar("func_id", $func_id);

	print "<p>Please select a different function type: \n";

	print nbsp(1); 
	print "<select name='new_func' class='img' size=1>\n";
	print "<option value='COG'>COG</option>\n";
	print "<option value='EC'>EC</option>\n";
	print "<option value='KO'>KO</option>\n";
	print "<option value='Pfam'>Pfam</option>\n";
	print "<option value='TIGRfam'>TIGRfam</option>\n";
	print "<option value='IMG Term'>IMG Term</option>\n";
	print "<option value='InterPro'>InterPro</option>\n";
	print "<option value='SEED'>SEED Subsystem</option>\n";
	print "</select>\n";
	print "<p>\n";

	my $name = "_section_FindClosure_showMain"; 
	print submit( 
        -id    => "findClosure", 
        -name  => $name, 
        -value => "Find Closure", 
        -class => "medbutton " 
        ); 

	print end_form();
	return;
    }

    my $dbh = dbLogin();

    if ( $debug && $sid == 312 ) {
	print "<p>SQL: $gene_cnt_query\n";
    }

#    my $cur0 = execSql( $dbh, $gene_cnt_query, $verbose );
#    my ($gene_count) = $cur0->fetchrow();
#    $cur0->finish();

#    print "<p>Selected function gene count: $gene_count\n";

    # show curated association in IMG, if any
#    if ( $curr_func eq 'COG' && $new_func eq 'Pfam' ) {
#	print "<p>Curated COG and Pfam association in IMG:\n";
#	my @pfams = findPfam_C($dbh, $func_id, 0);
#    }

    print "<p>\n";
    my $h_cond = funcTaxonCond("g.taxon");
    if ( $cond0 ) {
	$h_cond = " and g.gene_oid in (" . $cond0 . ") ";
    }
    my $total_gene_count = showTaxonGeneCntHistogram($h_cond, $gf_name);

    my $sql = "";
    if ( $new_func eq 'COG' ) {
	$sql = "select f1.cog, count(distinct f1.gene_oid) from gene_cog_groups f1 " .
	    "where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") . " group by f1.cog ";
    }
    elsif ( $new_func eq 'Pfam' ) {
	$sql = "select f1.pfam_family, count(distinct f1.gene_oid) " .
	    "from gene_pfam_families f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") . " group by f1.pfam_family ";
    }
    elsif ( $new_func eq 'TIGRfam' ) {
	$sql = "select f1.ext_accession, count(distinct f1.gene_oid) " .
	    "from gene_tigrfams f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") . 
	    " group by f1.ext_accession ";
    }
    elsif ( $new_func eq 'IMG Term' ) {
	$sql = "select f1.function, count(distinct f1.gene_oid) " .
	    "from gene_img_functions f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") .
	    " group by f1.function ";
    }
    elsif ( $new_func eq 'EC' ) {
	$sql = "select f1.enzymes, count(distinct f1.gene_oid) " .
	    "from gene_ko_enzymes f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") .
	    " group by f1.enzymes ";
    }
    elsif ( $new_func eq 'KO' ) {
	$sql = "select f1.ko_terms, count(distinct f1.gene_oid) " .
	    "from gene_ko_terms f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") .
	    " group by f1.ko_terms ";
    }
    elsif ( $new_func eq 'InterPro' ) {
	$sql = "select f1.iprid, count(distinct f1.gene_oid) " .
	    "from gene_img_interpro_hits f1 where f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") .
	    " group by f1.iprid ";
    }
    elsif ( $new_func eq 'SEED' ) {
	$sql = "select 'SEED:' || f1.subsystem, count(distinct f1.gene_oid) " .
	    "from gene_seed_names f1 " .
	    "where f1.subsystem is not null and f1.gene_oid in ($cond0) " .
	    funcTaxonCond("f1.taxon") .
	    " group by 'SEED:' || f1.subsystem ";
    }

    if ( $sql ) {
	$sql .= " order by 2 desc";
    }

    my $row_cnt = 0;
    if ( $cond0 && $sql ) {
	if ( $debug && $sid == 312 ) {
	    print "<p>SQL 1: $sql\n";
	}

	print "<p>\n";
	my $it = new InnerTable( 1, "listGenes$$", "listGenes", 3 ); 
	my $sd = $it->getSdDelim();    # sort delimiter                                    
	$it->addColSpec("Selection"); 
	$it->addColSpec( "Function ID", "char asc","left" );
	$it->addColSpec( "Function Name", "char asc","left" );
	$it->addColSpec( "Count", "number desc", "right" );
	$it->addColSpec( "Percent", "number desc", "right" );

	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) {
	    my ($func2, $cnt2) = $cur->fetchrow();
	    last if ! $func2;

	    if ( $new_func eq 'IMG Term' && isInt($func2) ) {
		$func2 = "ITERM:" . FuncUtil::termOidPadded($func2);
	    }

	    my $name2 = $func2;
	    if ( $new_func eq 'SEED' ) {
		my ($s1, $s2) = split(/\:/, $func2);
		$name2 = $s2;
	    }
	    else {
		$name2 = getFunctionName($dbh, $func2);
	    }

	    my $row; 
 
	    $row .= $sd 
		. "<input type='checkbox' name='new_func_id' value='$func2' />\t"; 
	    $row .= $func2 . $sd . $func2 . "\t"; 
	    $row .= $name2 . $sd . $name2 . "\t"; 
	    $row .= $cnt2 . $sd . $cnt2 . "\t"; 

	    if ( $total_gene_count ) {
		my $perc = $cnt2 * 100.0 / $total_gene_count;
		$row .= sprintf("%.2f", $perc) . $sd .
		    sprintf("%.2f", $perc) . "\t";
	    }
	    else {
		$row .= "-" . $sd . "-" . "\t";
	    }

	    $it->addRow($row); 
	    $row_cnt++;
	    if ( $row_cnt >= 20 ) {
		last;
	    }
	}
	$cur->finish();
	if ( $row_cnt ) {
	    print "<p>Top $row_cnt $new_func functions displayed.\n";
	    $it->printOuterTable("no page");
	}
    }

    print hiddenVar("curr_func", $new_func);

    #$dbh->disconnect();

    if ( $row_cnt > $max_func ) {
	print "<h5>Select any functions to add to the Function Cart or to view gene list, or select from 1 to $max_func functions from the table to find closure.</h5>\n";
    }
    else {
	print "<h5>Select any functions to add to the Function Cart, to view gene list, or to find closure with a new function type.</h5>\n";
    }
    print "<p>\n";
    print "<input type='radio' name='all_any' value='union' checked>Any of the selected functions (union)\n";
    print "<input type='radio' name='all_any' value='intersect'>All of the selected functions (intersection)\n";

    print "<br/>\n";
    print "<input type='radio' name='all_any' value='not'>None of the selected functions (including no " . $new_func . "s).\n";
    print "<input type='radio' name='all_any' value='none'>No $new_func association.\n";

    print "<p>\n";
    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print nbsp(1); 
    my $name        = "_section_FindClosure_addToFuncCart"; 
    my $buttonLabel = "Add Selected to Function Cart"; 
    print submit(
        -name  => $name,
        -value => "Add Selected to Function Cart",
        -class => "meddefbutton" 
	); 
    print nbsp(1); 
    $name = "_section_FindClosure_showGenes"; 
    print submit( 
        -id    => "showGenes", 
        -name  => $name, 
        -value => "List Genes", 
        -class => "smbutton " 
        ); 

    print "<p>Select a different new function type to continue: \n";

    print nbsp(1); 
    print "<select name='new_func' class='img' size=1>\n";
    for my $f3 ( 'COG', 'EC', 'KO', 'Pfam', 'TIGRfam', 'IMG Term',
		 'InterPro', 'SEED' ) {
	if ( $f3 eq $curr_func || $f3 eq $new_func ) {
	    next;
	}
	print "<option value='$f3'>$f3</option>\n";
    }
    print "</select>\n";
    print nbsp(3) . "\n";

    $name = "_section_FindClosure_showNext"; 
    print submit( 
        -id    => "findClosure", 
        -name  => $name, 
        -value => "Find Closure", 
        -class => "meddefbutton " 
        ); 

    print end_form();
}


############################################################################
# printNextPage
############################################################################
sub printNextPage {
    my ($show_genes, $gene_per_taxon) = @_;
    my $sid = getContactOid();

    printMainForm();

    if ( $show_genes ) {
	print "<h1>Genes with Selected Functions</h2>\n";
	if ( $sid ) {
	    my $superUser = getSuperUser();
	    if ( $superUser ne 'Yes' ) {
		print "<p><font color='red'>The list only shows genes that you have access privilege.</font>\n";
	    }
	}
    }
    else {
	print "<h1>Find Functional Closure</h1>\n";
    }

    print "<p>Analysis is based on isolate genomes only.\n";

    my $all_any = param('all_any');
    if ( ! $all_any ) {
	$all_any = 'union';
    }
    my $curr_func = param("curr_func");
    my $new_func = param("new_func");
#    print "<p>curr_func: $curr_func, new_func: $new_func\n";

    my @func_ids = param("new_func_id");
    if ( ! $show_genes ) {
	if ( scalar(@func_ids) == 0 ) {
	    if ( $all_any ne 'none' ) {
		print "<p>No function has been selected.\n";
		print end_form();
		return;
	    }
	}
	elsif ( scalar(@func_ids) > $max_func ) {
	    print "<p>Please select no more than $max_func functions.\n";
	    print end_form();
	    return;
	}
    }

    my $default_all_any = 'union';

    my @cog_ids = param('cog_id');
    my $cog_all_any = param('cog_all_any');
    if ( ! $cog_all_any ) {
	$cog_all_any = $default_all_any;
    }

    my @pfam_ids = param('pfam_id');
    my $pfam_all_any = param('pfam_all_any');
    if ( ! $pfam_all_any ) {
	$pfam_all_any = $default_all_any;
    }

    my @tigrfam_ids = param('tigrfam_id');
    my $tigrfam_all_any = param('tigrfam_all_any');
    if ( ! $tigrfam_all_any ) {
	$tigrfam_all_any = $default_all_any;
    }

    my @ko_ids = param('ko_id');
    my $ko_all_any = param('ko_all_any');
    if ( ! $ko_all_any ) {
	$ko_all_any = $default_all_any;
    }

    my @interpro_ids = param('interpro_id');
    my $interpro_all_any = param('interpro_all_any');
    if ( ! $interpro_all_any ) {
	$interpro_all_any = $default_all_any;
    }

    my @seed_ids = param('seed_id');
    my $seed_all_any = param('seed_all_any');
    if ( ! $seed_all_any ) {
	$seed_all_any = $default_all_any;
    }

    my @term_ids = param('term_id');
    my $term_all_any = param('term_all_any');
    if ( ! $term_all_any ) {
	$term_all_any = $default_all_any;
    }

    my @ec_ids = param('ec_id');
    my $ec_all_any = param('ec_all_any');
    if ( ! $ec_all_any ) {
	$ec_all_any = $default_all_any;
    }

    if ( $curr_func eq 'COG' ) {
	$cog_all_any = $all_any;
    }
    elsif ( $curr_func eq 'Pfam' ) {
	$pfam_all_any = $all_any;
    }
    elsif ( $curr_func eq 'TIGRfam' ) {
	$tigrfam_all_any = $all_any;
    }
    elsif ( $curr_func eq 'KO' ) {
	$ko_all_any = $all_any;
    }
    elsif ( $curr_func eq 'EC' ) {
	$ec_all_any = $all_any;
    }
    elsif ( $curr_func eq 'InterPro' ) {
	$interpro_all_any = $all_any;
    }
    elsif ( $curr_func eq 'IMG Term' ) {
	$term_all_any = $all_any;
    }
    elsif ( $curr_func eq 'SEED' ) {
	$seed_all_any = $all_any;
    }

    if ( $show_genes == 0 || ($show_genes == 1 && $all_any ne 'none') ) {
	# add new selection
	for my $func_id ( @func_ids ) {
	    if ( $func_id =~ /^COG/ ) {
		push @cog_ids, ( $func_id );
		# $cog_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^pfam/ ) {
		push @pfam_ids, ( $func_id );
		# $pfam_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^TIGR/ ) {
		push @tigrfam_ids, ( $func_id );
		# $tigrfam_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^KO/ ) {
		push @ko_ids, ( $func_id );
		# $ko_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^EC\:/ ) {
		push @ec_ids, ( $func_id );
		# $ec_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^ITERM\:/ ) {
		push @term_ids, ( $func_id );
		# $term_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^IPR/ ) {
		push @interpro_ids, ( $func_id );
		# $interpro_all_any = $all_any;
	    }
	    elsif ( $func_id =~ /^SEED/ ) {
		push @seed_ids, ( $func_id );
		# $seed_all_any = $all_any;
	    }
	}
    }

    print "<h2>Selected functions</h2>\n";
    if ( $cog_all_any eq 'none' ) {
	print "<p>No COG associations.\n";
    }
    elsif ( $cog_all_any eq 'not' ) {
	print "<p>COG: no " . join("," , @cog_ids) . "\n";
    }
    elsif ( scalar(@cog_ids) > 0 ) {
	print "<p>COG: " . join(is_and_or($cog_all_any) , @cog_ids) . "\n";
    }
    print hiddenVar('cog_all_any', $cog_all_any);

    if ( $pfam_all_any eq 'none' ) {
	print "<p>No Pfam associations.\n";
    }
    elsif ( $pfam_all_any eq 'not' ) {
	print "<p>Pfam: no " . join("," , @pfam_ids) . "\n";
    }
    elsif ( scalar(@pfam_ids) > 0 ) {
	print "<p>Pfam: " . join(is_and_or($pfam_all_any) , @pfam_ids) . "\n";
    }
    print hiddenVar('pfam_all_any', $pfam_all_any);

    if ( $tigrfam_all_any eq 'none' ) {
	print "<p>No TIGRfam associations.\n";
    }
    elsif ( $tigrfam_all_any eq 'not' ) {
	print "<p>TIGRfam: no " . join("," , @tigrfam_ids) . "\n";
    }
    elsif ( scalar(@tigrfam_ids) > 0 ) {
	print "<p>TIGRfam: " . join(is_and_or($tigrfam_all_any) , @tigrfam_ids) . "\n";
    }
    print hiddenVar('tigrfam_all_any', $tigrfam_all_any);

    if ( $ko_all_any eq 'none' ) {
	print "<p>No KO associations.\n";
    }
    elsif ( $ko_all_any eq 'not' ) {
	print "<p>KO: no " . join("," , @ko_ids) . "\n";
    }
    elsif ( scalar(@ko_ids) > 0 ) {
	print "<p>KO: " . join(is_and_or($ko_all_any) , @ko_ids) . "\n";
    }
    print hiddenVar('ko_all_any', $ko_all_any);

    if ( $term_all_any eq 'none' ) {
	print "<p>No IMG Term associations.\n";
    }
    elsif ( $term_all_any eq 'not' ) {
	print "<p>IMG Term: no " . join("," , @term_ids) . "\n";
    }
    elsif ( scalar(@term_ids) > 0 ) {
	print "<p>IMG Term: " . join(is_and_or($term_all_any) , @term_ids) . "\n";
    }
    print hiddenVar('term_all_any', $term_all_any);

    if ( $ec_all_any eq 'none' ) {
	print "<p>No Enzyme (EC) associations.\n";
    }
    elsif ( $ec_all_any eq 'not' ) {
	print "<p>Enzyme: no " . join("," , @ec_ids) . "\n";
    }
    elsif ( scalar(@ec_ids) > 0 ) {
	print "<p>Enzyme: " . join(is_and_or($ec_all_any) , @ec_ids) . "\n";
    }
    print hiddenVar('ec_all_any', $ec_all_any);

    if ( $interpro_all_any eq 'none' ) {
	print "<p>No InterPro associations.\n";
    }
    elsif ( $interpro_all_any eq 'not' ) {
	print "<p>InterPro: no " . join("," , @interpro_ids) . "\n";
    }
    elsif ( scalar(@interpro_ids) > 0 ) {
	print "<p>InterPro: " . join(is_and_or($interpro_all_any) , @interpro_ids) . "\n";
    }
    print hiddenVar('interpro_all_any', $interpro_all_any);

    if ( $seed_all_any eq 'none' ) {
	print "<p>No SEED Subsystem associations.\n";
    }
    elsif ( $seed_all_any eq 'not' ) {
	print "<p>SEED Subsystem: no " . join("," , @seed_ids) . "\n";
    }
    elsif ( scalar(@seed_ids) > 0 ) {
	print "<p>SEED Subsystem: " . join(is_and_or($seed_all_any) , @seed_ids) . "\n";
    }
    print hiddenVar('seed_all_any', $seed_all_any);

    if ( $gene_per_taxon ) {
	print "<p>Per genome gene count: $gene_per_taxon\n";
    }

    # COG condition
    my $cog_cond = "";
    my $c_cnt = 0; 
    if ( $cog_all_any eq 'none' ) {
	$cog_cond = "(select gcg0.gene_oid from gene gcg0) minus (select gcg1.gene_oid from gene_cog_groups gcg1)";
    }
    elsif ( $cog_all_any eq 'not' ) {
	$cog_cond = "(select gcg0.gene_oid from gene gcg0) minus (select gcg1.gene_oid from gene_cog_groups gcg1 where gcg1.cog in (";
	for my $cog ( @cog_ids ) { 
	    print hiddenVar('cog_id', $cog);
	    if ( $c_cnt ) {
		$cog_cond .= ",";
	    }
	    $cog_cond .= "'$cog'";
	    $c_cnt++;
	}
	if ( $c_cnt == 0 ) {
	    $cog_cond .= "'0'";
	}
	$cog_cond .= " ))";
    }
    else {
	for my $cog ( @cog_ids ) { 
	    print hiddenVar('cog_id', $cog);
	    my $t_name = "gcg" . $c_cnt;
	    my $c1_cond = "select $t_name.gene_oid from gene_cog_groups " .
		$t_name . " where $t_name.cog = '$cog'"; 
	    if ( $c_cnt ) { 
		$cog_cond .= " $cog_all_any " . $c1_cond;
	    }
	    else {
		$cog_cond = $c1_cond;
	    } 
 
	    $c_cnt++; 
	} 
    }
    if ( $cog_cond ) {
        $cog_cond = " and g.gene_oid in (" . $cog_cond . ") ";
    } 

    # Pfam condition
    my $pfam_cond = ""; 
    my $p_cnt = 0; 
    if ( $pfam_all_any eq 'none' ) {
	$pfam_cond = "(select gpf0.gene_oid from gene gpf0) minus (select gpf1.gene_oid from gene_pfam_families gpf1)";
    }
    elsif ( $pfam_all_any eq 'not' ) {
	$pfam_cond = "(select gpf0.gene_oid from gene gpf0) minus (select gpf1.gene_oid from gene_pfam_families gpf1 where gpf1.pfam_family in (";
	for my $pfam ( @pfam_ids ) { 
	    print hiddenVar('pfam_id', $pfam);
	    if ( $p_cnt ) {
		$pfam_cond .= ",";
	    }
	    $pfam_cond .= "'$pfam'";
	    $p_cnt++;
	}
	if ( $p_cnt == 0 ) {
	    $pfam_cond .= "'0'";
	}
	$pfam_cond .= " ))";
    }
    else {
	for my $pfam ( @pfam_ids ) { 
	    print hiddenVar('pfam_id', $pfam);
	    my $t_name = "gpf" . $p_cnt; 
	    my $p1_cond = "select $t_name.gene_oid from gene_pfam_families " .
		$t_name . " where $t_name.pfam_family = '$pfam'"; 
	    if ( $p_cnt ) { 
		$pfam_cond .= " $pfam_all_any " . $p1_cond; 
	    } 
	    else { 
		$pfam_cond = $p1_cond; 
	    } 
 
	    $p_cnt++;
	} 
    }
    if ( $pfam_cond ) { 
        $pfam_cond = " and g.gene_oid in (" . $pfam_cond . ") ";
    } 

    # TIGRfam condition
    my $tigrfam_cond = ""; 
    my $t_cnt = 0; 
    if ( $tigrfam_all_any eq 'none' ) {
	$tigrfam_cond = "(select gt0.gene_oid from gene gt0) minus (select gt1.gene_oid from gene_tigrfams gt1)";
    }
    else {
	for my $tigr ( @tigrfam_ids ) { 
	    print hiddenVar('tigrfam_id', $tigr);
	    my $t_name = "gt" . $t_cnt;
	    my $t1_cond = "select $t_name.gene_oid from gene_tigrfams " .
		$t_name . " where $t_name.ext_accession = '$tigr'"; 
	    if ( $t_cnt ) { 
		$tigrfam_cond .= " $tigrfam_all_any " . $t1_cond;
	    }
	    else { 
		$tigrfam_cond = $t1_cond;
	    } 
 
	    $t_cnt++; 
	} 
    }
    if ( $tigrfam_cond ) {
        $tigrfam_cond = " and g.gene_oid in (" . $tigrfam_cond . ") ";
    } 

    # KO condition
    my $ko_cond = "";
    my $k_cnt = 0; 
    if ( $ko_all_any eq 'none' ) {
	$ko_cond = "(select gkt0.gene_oid from gene gkt0) minus (select gkt1.gene_oid from gene_ko_terms gkt1)";
    }
    elsif ( $ko_all_any eq 'not' ) {
	$ko_cond = "(select gkt0.gene_oid from gene gkt0) minus (select gkt1.gene_oid from gene_ko_terms gkt1 where gkt1.ko_terms in (";
	for my $ko ( @ko_ids ) { 
	    print hiddenVar('ko_id', $ko);
	    if ( $k_cnt ) {
		$ko_cond .= ",";
	    }
	    $ko_cond .= "'$ko'";
	    $k_cnt++;
	}
	if ( $k_cnt == 0 ) {
	    $ko_cond .= "'0'";
	}
	$ko_cond .= " ))";
    }
    else {
	for my $ko ( @ko_ids ) { 
	    print hiddenVar('ko_id', $ko);
	    my $t_name = "gkt" . $k_cnt;
	    my $k1_cond = "select $t_name.gene_oid from gene_ko_terms " .
		$t_name . " where $t_name.ko_terms = '$ko'"; 
	    if ( $k_cnt ) { 
		$ko_cond .= " $ko_all_any " . $k1_cond;
	    }
	    else {
		$ko_cond = $k1_cond;
	    } 
 
	    $k_cnt++; 
	} 
    }
    if ( $ko_cond ) {
        $ko_cond = " and g.gene_oid in (" . $ko_cond . ") ";
    } 

    # IMG Term condition
    my $term_cond = ""; 
    my $m_cnt = 0; 
    if ( $term_all_any eq 'none' ) {
	$term_cond = "(select gif0.gene_oid from gene gif0) minus (select gif1.gene_oid from gene_img_functions gif1)";
    }
    elsif ( $term_all_any eq 'not' ) {
	$term_cond = "(select gif0.gene_oid from gene gif0) minus (select gif1.gene_oid from gene_img_functions gif1 where gif1.function in (";
	for my $term ( @term_ids ) { 
	    print hiddenVar('term_id', $term);
	    my ($tag0, $val0) = split(/\:/, $term);
	    if ( $m_cnt ) {
		$term_cond .= ",";
	    }
	    $term_cond .= "$val0";
	    $m_cnt++;
	}
	if ( $m_cnt == 0 ) {
	    $term_cond .= "0";
	}
	$term_cond .= " ))";
    }
    else {
	for my $term ( @term_ids ) { 
	    print hiddenVar('term_id', $term);
	    my ($tag0, $val0) = split(/\:/, $term);
	    my $t_name = "gif" . $m_cnt; 
	    my $m1_cond = "select $t_name.gene_oid from gene_img_functions " .
		$t_name . " where $t_name.function = $val0";
	    if ( $m_cnt ) { 
		$term_cond .= " $term_all_any " . $m1_cond;
	    } 
	    else {
		$term_cond = $m1_cond;
	    } 
 
	    $m_cnt++; 
	} 
    }
    if ( $term_cond ) {
        $term_cond = " and g.gene_oid in (" . $term_cond . ") ";
    } 

    # EC condition
    my $ec_cond = "";
    my $e_cnt = 0; 
    if ( $ec_all_any eq 'none' ) {
	$ec_cond = "(select gke0.gene_oid from gene gke0) minus (select gke1.gene_oid from gene_ko_enzymes gke1)";
    }
    elsif ( $ec_all_any eq 'not' ) {
	$ec_cond = "(select gke0.gene_oid from gene gke0) minus (select gke1.gene_oid from gene_ko_enzymes gke1 where gkt1.enzymes in (";
	for my $ec ( @ec_ids ) { 
	    print hiddenVar('ec_id', $ec);
	    if ( $e_cnt ) {
		$ec_cond .= ",";
	    }
	    $ec_cond .= "'$ec'";
	    $e_cnt++;
	}
	if ( $e_cnt == 0 ) {
	    $ec_cond .= "'0'";
	}
	$ec_cond .= " ))";
    }
    else {
	for my $ec ( @ec_ids ) { 
	    print hiddenVar('ec_id', $ec);
	    my $t_name = "gke" . $e_cnt;
	    my $e1_cond = "select $t_name.gene_oid from gene_ko_enzymes " .
		$t_name . " where $t_name.enzymes = '$ec'"; 
	    if ( $e_cnt ) { 
		$ec_cond .= " $ec_all_any " . $e1_cond;
	    }
	    else {
		$ec_cond = $e1_cond;
	    } 
 
	    $e_cnt++; 
	} 
    }
    if ( $ec_cond ) {
        $ec_cond = " and g.gene_oid in (" . $ec_cond . ") ";
    } 

    # InterPro condition
    my $interpro_cond = ""; 
    my $i_cnt = 0; 
    if ( $interpro_all_any eq 'none' ) {
    	$interpro_cond = "(select gi0.gene_oid from gene gi0) minus (select gi1.gene_oid from gene_xref_families gi1 where gi1.db_name = 'InterPro')";
    }
    elsif ( $interpro_all_any eq 'not' ) {
    	$interpro_cond = "(select gi0.gene_oid from gene gi0) minus (select gi1.gene_oid from gene_xref_families gi1 where gi1.db_name = 'InterPro' and gi1.id in (";
    	for my $interpro ( @interpro_ids ) { 
    	    print hiddenVar('interpro_id', $interpro);
    	    if ( $i_cnt ) {
        		$interpro_cond .= ",";
    	    }
    	    $interpro_cond .= "'$interpro'";
    	    $i_cnt++;
    	}
    	if ( $i_cnt == 0 ) {
    	    $interpro_cond .= "'0'";
    	}
    	$interpro_cond .= " ))";
    }
    else {
    	for my $interpro ( @interpro_ids ) { 
    	    print hiddenVar('interpro_id', $interpro);
    	    my $t_name = "gi" . $t_cnt;
    	    my $i1_cond = "select $t_name.gene_oid from gene_xref_families " .
    		$t_name . " where $t_name.db_name = 'InterPro' and $t_name.id = '$interpro'"; 
    	    if ( $i_cnt ) { 
        		$interpro_cond .= " $interpro_all_any " . $i1_cond;
    	    }
    	    else { 
        		$interpro_cond = $i1_cond;
    	    } 
     
    	    $i_cnt++; 
    	} 
    }
    if ( $interpro_cond ) {
        $interpro_cond = " and g.gene_oid in (" . $interpro_cond . ") ";
    } 

    ##### ?????
    # SEED condition
    my $seed_cond = ""; 
    my $s_cnt = 0; 
    if ( $seed_all_any eq 'none' ) {
	$seed_cond = "(select gi0.gene_oid from gene gi0) minus (select gi1.gene_oid from gene_seed_names gi1)";
    }
    elsif ( $seed_all_any eq 'not' ) {
	$seed_cond = "(select gi0.gene_oid from gene gi0) minus (select gi1.gene_oid from gene_seed_names gi1 where gi1.subsystem in (";
	for my $seed ( @seed_ids ) { 
	    print hiddenVar('seed_id', $seed);
	    if ( $s_cnt ) {
		$seed_cond .= ",";
	    }
	    my $s2 = $seed;
	    if ( $s2 =~ /SEED/ && length($s2) > 5 ) {
		$s2 = substr($s2, 5);
	    }
	    $seed_cond .= "'$s2'";
	    $s_cnt++;
	}
	if ( $s_cnt == 0 ) {
	    $seed_cond .= "'0'";
	}
	$seed_cond .= " ))";
    }
    else {
	for my $seed ( @seed_ids ) { 
	    print hiddenVar('seed_id', $seed);
	    my $s2 = $seed;
	    if ( $s2 =~ /SEED/ && length($s2) > 5 ) {
		$s2 = substr($s2, 5);
	    }
	    my $t_name = "gi" . $t_cnt;
	    my $i1_cond = "select $t_name.gene_oid from gene_seed_names " .
		$t_name . " where $t_name.subsystem = '$s2'"; 
	    if ( $s_cnt ) { 
		$seed_cond .= " $seed_all_any " . $i1_cond;
	    }
	    else { 
		$seed_cond = $i1_cond;
	    } 
 
	    $s_cnt++; 
	} 
    }
    if ( $seed_cond ) {
        $seed_cond = " and g.gene_oid in (" . $seed_cond . ") ";
    } 

    my $total_gene_count = 0;
    if ( ! $show_genes ) {
	print "<p>\n";
	my $h_cond = $cog_cond . $pfam_cond . $tigrfam_cond .
	    $ko_cond . $term_cond . $ec_cond . $interpro_cond . $seed_cond;
	$total_gene_count = showTaxonGeneCntHistogram($h_cond);
    }

    my $sql = "";
    my $g_cond = funcTaxonCond("g.taxon");

    my %taxon_h;
    if ( $show_genes ) {

	my $rclause = " ";
	my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

	if ( $gene_per_taxon ) {
	    my $sql2 = qq{
                 select g.taxon, count(*)
                 from gene g
                 where g.obsolete_flag = 'No'
                    and g.locus_type = 'CDS'
                    $rclause
                    $imgClause
                    $g_cond
                    $cog_cond
                    $pfam_cond
                    $tigrfam_cond
                    $ko_cond
                    $term_cond
                    $ec_cond
                    $interpro_cond
                    $seed_cond
                    group by g.taxon having count(*) = $gene_per_taxon
                 };
	    if ( $debug && $sid == 312 ) {
		print "<p>SQL2: $sql2\n";
	    }

	    my $dbh2 = dbLogin();
	    my $cur2 = execSql( $dbh2, $sql2, $verbose );
	    for (;;) {
		my ($t2, $t_cnt2) = $cur2->fetchrow();
		last if ! $t2;

		# print "<p>taxon: $t2\n";
		$taxon_h{$t2} = $t_cnt2;
	    }
	    $cur2->finish();
	    #$dbh2->disconnect();
	}

        my $rclause = " ";
        my $imgClause = WebUtil::imgClause('t');

	$sql = qq{
            select g.gene_oid, g.gene_display_name, t.taxon_oid, t.taxon_display_name
            from gene g, taxon t
            where g.obsolete_flag = 'No'
            and g.locus_type = 'CDS'
            and g.taxon = t.taxon_oid
            $rclause
            $imgClause
            $g_cond
            $cog_cond
            $pfam_cond
            $tigrfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            };
    }
    elsif ( $new_func eq 'COG' ) {
	$sql = qq{
            select g.cog, count(distinct g.gene_oid)
            from gene_cog_groups g
            where g.cog is not null
            $g_cond
            $pfam_cond
            $tigrfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            group by g.cog
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'Pfam' ) {
	$sql = qq{
	    select g.pfam_family, count(distinct g.gene_oid)
            from gene_pfam_families g
            where g.pfam_family is not null
            $g_cond
            $cog_cond
            $tigrfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            group by g.pfam_family
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'TIGRfam' ) {
	$sql = qq{
            select g.ext_accession, count(distinct g.gene_oid) 
            from gene_tigrfams g
            where g.ext_accession is not null
            $g_cond
            $cog_cond
            $pfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            group by g.ext_accession
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'KO' ) {
	$sql = qq{
            select g.ko_terms, count(distinct g.gene_oid) 
            from gene_ko_terms g
            where g.ko_terms is not null
            $g_cond
            $cog_cond
            $tigrfam_cond
            $pfam_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            group by g.ko_terms
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'EC' ) {
	$sql = qq{
            select g.enzymes, count(distinct g.gene_oid) 
            from gene_ko_enzymes g
            where g.enzymes is not null
            $g_cond
            $cog_cond
            $tigrfam_cond
            $pfam_cond
            $ko_cond
            $term_cond
            $interpro_cond
            $seed_cond
            group by g.enzymes
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'IMG Term' ) {
	$sql = qq{
            select g.function, count(distinct g.gene_oid) 
            from gene_img_functions g
            where g.function is not null
            $cog_cond
            $tigrfam_cond
            $pfam_cond
            $term_cond
            $ec_cond
            $interpro_cond
            $seed_cond
            $g_cond
            group by g.function
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'InterPro' ) {
	$sql = qq{
            select g.iprid, count(distinct g.gene_oid) 
            from gene_img_interpro_hits g
            where g.iprid is not null
            $g_cond
            $cog_cond
            $tigrfam_cond
            $pfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $seed_cond
            group by g.iprid
            order by 2 desc
            };
    }
    elsif ( $new_func eq 'SEED' ) {
	$sql = qq{
            select 'SEED:' || g.subsystem, count(distinct g.gene_oid) 
            from gene_seed_names g
            where g.subsystem is not null
            $g_cond
            $cog_cond
            $tigrfam_cond
            $pfam_cond
            $ko_cond
            $term_cond
            $ec_cond
            $interpro_cond
            group by 'SEED:' || g.subsystem
            order by 2 desc
            };
    }

    if ( $show_genes && $gene_per_taxon &&
	 scalar(keys %taxon_h) == 0 ) {
	$sql = "";
    }

    if ( $debug && $sid == 312 ) {
	print "<p>SQL 3: $sql\n";
    }

    my $row_cnt = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    if ( $sql ) {
	printStatusLine( "Loading ...", 1 );
	print "<p>\n";
	my $dbh = dbLogin();
	my $it = new InnerTable( 1, "listGenes$$", "listGenes", 3 ); 
	my $sd = $it->getSdDelim();    # sort delimiter                                    
	$it->addColSpec("Selection"); 

	if ( $show_genes ) {
	    $it->addColSpec( "Gene ID", "number asc","right" );
	    $it->addColSpec( "Gene Name", "char asc","left" );
	    $it->addColSpec( "Genome", "char asc","left" );
	}
	else {
	    $it->addColSpec( "Function ID", "char asc","left" );
	    $it->addColSpec( "Function Name", "char asc","left" );
	    $it->addColSpec( "Count", "number desc", "right" );
	    $it->addColSpec( "Percent", "number desc", "right" );
	}

	### FIX ME
	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) {
	    my ($val1, $val2, $val3, $val4) = $cur->fetchrow();
	    last if ! $val1;

	    if ( $gene_per_taxon ) {
		# check taxon gene count
		if ( ! $taxon_h{$val3} ) {
		    next;
		}
	    }

	    if ( $show_genes ) {
		if ( $row_cnt > $maxGeneListResults ) {
		    $trunc = 1;
		    last;
		}
	    }
	    else {
		if ( $row_cnt > 30 ) {
		    $trunc = 1;
		    last;
		}
	    }

	    my $row; 

	    if ( $show_genes ) {
		$row .= $sd 
		    . "<input type='checkbox' name='gene_oid' value='$val1' />\t"; 

		# gene oid
		my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
		$url .= "&gene_oid=$val1";
		$row  .= $val1 . $sd . alink( $url, $val1 ) . "\t";

		# gene name
		$row .= $val2 . $sd . $val2 . "\t";

		# genome
		my $url2 = "$main_cgi?section=TaxonDetail&page=taxonDetail"; 
		$url2 .= "&taxon_oid=$val3"; 
		$row .= $val4 . $sd . alink( $url2, $val4 ) . "\t";

		$it->addRow($row); 
		$row_cnt++;
	    }
	    else {
		if ( $new_func eq 'IMG Term' ) {
		    $val1 = "ITERM:" . FuncUtil::termOidPadded($val1);
		}
		$row .= $sd 
		    . "<input type='checkbox' name='new_func_id' value='$val1' />\t"; 
		$row .= $val1 . $sd . $val1 . "\t"; 
		my $name2 = $val1;
		if ( $new_func eq 'SEED' ) {
		    my ($s1, $s2) = split(/\:/, $val1);
		    $name2 = $s2;
		}
		else {
		    $name2 = getFunctionName($dbh, $val1);
		}

		$row .= $name2 . $sd . $name2 . "\t"; 
		$row .= $val2 . $sd . $val2 . "\t"; 

		if ( $total_gene_count ) {
		    my $perc = $val2 * 100.0 / $total_gene_count;
		    $row .= sprintf("%.2f", $perc) . $sd .
			sprintf("%.2f", $perc) . "\t";
		}
		else {
		    $row .= "-" . $sd . "-" . "\t";
		}

		$it->addRow($row); 
		$row_cnt++;
	    }
	}
	$cur->finish();

	if ( $row_cnt ) {
	    if ( $show_genes ) {
		$it->printOuterTable(1);
	    }
	    else {
		print "<p>Top $row_cnt $new_func functions displayed.\n";
		$it->printOuterTable("no page");
	    }
	}

	#$dbh->disconnect();
    }

    print hiddenVar("curr_func", $new_func);

    if ( $show_genes ) {
	if ( $trunc ) {
	    my $s = "Results limited to $maxGeneListResults genes.\n";
	    $s .= "( Go to " 
		. alink( $preferences_url, "Preferences" ) 
		. " to change \"Max. Gene List Results\". )\n";
	    printStatusLine( $s, 2 ); 
	} else {
	    printStatusLine( "$row_cnt gene(s) retrieved.", 2 ); 
	    print "<h5>No genes satisfy the selection condition.</h5>\n";
	} 

	if ( $row_cnt ) {
	    print submit( 
                -id  => "go3", 
                -name  => "_section_${section}_addGeneCart", 
                -value => "Add Selected to Gene Cart", 
		-class => "meddefbutton " );
	    print nbsp(1); 
	    print "<input type='button' name='selectAll' value='Select All' "
		. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
	    print nbsp(1); 
	    print "<input type='button' name='clearAll' value='Clear All' "
		. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	}

	print end_form();
	return;
    }

    # check remain function types
    my @remain_funcs = ();
    if ( $new_func ne 'COG' && scalar(@cog_ids) == 0 ) {
	push @remain_funcs, ( 'COG' );
    }
    if ( $new_func ne 'Pfam' && scalar(@pfam_ids) == 0 ) {
	push @remain_funcs, ( 'Pfam' );
    }
    if ( $new_func ne 'TIGRfam' && scalar(@tigrfam_ids) == 0 ) {
	push @remain_funcs, ( 'TIGRfam' );
    }
    if ( $new_func ne 'KO' && scalar(@ko_ids) == 0 ) {
	push @remain_funcs, ( 'KO' );
    }
    if ( $new_func ne 'IMG Term' && scalar(@term_ids) == 0 ) {
	push @remain_funcs, ( 'IMG Term' );
    }
    if ( $new_func ne 'InterPro' && scalar(@interpro_ids) == 0 ) {
	push @remain_funcs, ( 'InterPro' );
    }
    if ( $new_func ne 'SEED' && scalar(@seed_ids) == 0 ) {
	push @remain_funcs, ( 'SEED' );
    }

    if ( $row_cnt <= 0 ) {
	print "<h5>No genes satisfy the condition.</h5>\n";
	print end_form();
	return;
    }

    if ( scalar(@remain_funcs) == 0 ) {
	print "<p>Select any functions to add to the Function Cart or to view gene list.\n";
    }
    elsif ( $row_cnt > $max_func ) {
	print "<p>Select any functions to add to the Function Cart or to view gene list, or select from 1 to $max_func functions from the table to find closure.\n";
    }
    else {
	print "<p>Select any functions to add to the Function Cart, to view gene list, or to find closure with a new function type.\n";
    }

    print "<p>\n";
    print "<input type='radio' name='all_any' value='union' checked>Any of the selected functions.\n";
    print "<input type='radio' name='all_any' value='intersect'>All of the selected functions.\n";

    print "<br/>\n";
    print "<input type='radio' name='all_any' value='not'>None of the selected functions (including no " . $new_func . "s).\n";
    print "<input type='radio' name='all_any' value='none'>No $new_func association.\n";

    print "<p>\n";
    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print nbsp(1); 

    my $name        = "_section_FindClosure_addToFuncCart"; 
    my $buttonLabel = "Add Selected to Function Cart"; 
    print submit(
        -name  => $name,
        -value => "Add Selected to Function Cart",
        -class => "meddefbutton" 
	); 
    print nbsp(1); 
    $name = "_section_FindClosure_showGenes"; 
    print submit( 
        -id    => "showGenes", 
        -name  => $name, 
        -value => "List Genes", 
        -class => "smbutton " 
        ); 

    if ( scalar(@remain_funcs) > 0 ) {
	print "<p>Select a different new function type to continue: \n";

	print nbsp(1); 
	print "<select name='new_func' class='img' size=1>\n";
	for my $f3 ( @remain_funcs ) {
	    print "<option value='$f3'>$f3</option>\n";
	}
	print "</select>\n";
	print nbsp(3) . "\n";

	my $name = "_section_FindClosure_showNext"; 
	print submit( 
	    -id    => "findClosure", 
	    -name  => $name, 
	    -value => "Find Closure", 
	    -class => "medbutton " 
	    ); 
    }

    print end_form();
}


sub is_and_or {
    my ($op) = @_;

    if ( $op eq 'union' ) {
	return " or ";
    }
    elsif ( $op eq 'intersect' ) {
	return " and ";
    }
    else {
	return ",";
    }
}

############################################################################
# findTigrFam_CP: find TIGRfam using COG and Pfam
############################################################################
sub findTigrFam_CP {
    my ($dbh, $err_cut, $cog_id, $pfam_ref) = @_;

    my $pfam_str = join(',', @$pfam_ref);
    if ( ! $pfam_str ) {
	print "<p>No Pfam.\n";
	return;
    }

    print "<h4>Find TIGRFam from $cog_id and $pfam_str</h4>\n";

    my @terms = ();

    my $pfam_cond = "";
    my $p_cnt = 0;
    for my $pfam ( @$pfam_ref ) {
	my $t_name = "gpf" . $p_cnt;
	my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$pfam'";
	if ( $p_cnt ) {
	    $pfam_cond .= " intersect " . $p1_cond;
	}
	else {
	    $pfam_cond = $p1_cond;
	}

	$p_cnt++;
    }

    my $sql = qq{
	select count(distinct gcg.gene_oid)
	    from gene_cog_groups gcg
	    where gcg.cog = '$cog_id'
	    and gcg.gene_oid in ( $pfam_cond )
	};

    my $sid  = getContactOid();
    if ( $debug && $sid == 312 ) {
	print "*** SQL 4: $sql\n";
    }

    my $cur = execSql( $dbh, $sql, $verbose);
    my( $total_cnt ) = $cur->fetchrow( ); 

    $sql = qq{
	select gt.ext_accession, count(*) 
	    from gene_cog_groups gcg, gene_tigrfams gt
	    where gcg.cog = '$cog_id'
	    and gcg.gene_oid = gt.gene_oid
	    and gcg.gene_oid in ( $pfam_cond )
	    group by gt.ext_accession
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    my $total = 0;
    my %h_term;
    for (my $i = 0; $i < 10000; $i++) {
	my( $t_id, $t_cnt ) = $cur->fetchrow( ); 
	last if !$t_id;

	$h_term{$t_id} = $t_cnt;
	$total += $t_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	return @terms;
    }

    print "<p>Total gene count: $total_cnt\n";

    print "<table class='img'>\n";
    print "<th class='img'>TIGRFam</th>\n";
    print "<th class='img'>Name</th>\n";
    print "<th class='img'>number of genes</th>\n";
    print "<th class='img'>percentage</th>\n";

    for my $k (keys(%h_term) ) {
	my $t_name = getFunctionName($dbh, $k);
	my $t_cnt = $h_term{$k};
	my $perc = $t_cnt * 100.0 / $total_cnt;
	my $url2   = "$main_cgi?section=$section&page=listFuncGenes" .
	    "&func=";
	$url2 .= $cog_id . "," . $pfam_str . "," . $k;
	if ( $perc > $err_cut ) {
	    print "<tr><td class='img'>$k</td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'>" .
		alink($url2, $t_cnt) . "</td>\n";
	    print "<td class='img' align='right'>" . 
		sprintf("%.2f", $perc) ."</td></tr>\n";

	    push @terms, ( $k );
	}
	else {
	    print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'><font color='purple'>" .
		alink($url2, $t_cnt) . "</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" . 
		sprintf("%.2f", $perc) ."</font></td></tr>\n";
	}
    }
    print "</table>\n";

    return @terms;
}


############################################################################
# findKO_CPT: find KO using COG and Pfam and TIGRfam
############################################################################
sub findKO_CPT {
    my ($dbh, $err_cut, $cog_id, $pfam_ref, $tigr_ref) = @_;

    my $pfam_str = join(',', @$pfam_ref);
    my $tigr_str = join(',', @$tigr_ref);
    if ( blankStr($tigr_str) ) {
	$tigr_str = "(No TIGRFam)";
    }
    print "<h4>Find KO from $cog_id and $pfam_str and $tigr_str</h4>\n";

    my @terms = ();

    my $pfam_cond = "";
    my $p_cnt = 0;
    for my $pfam ( @$pfam_ref ) {
	my $t_name = "gpf" . $p_cnt;
	my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$pfam'";
	if ( $p_cnt ) {
	    $pfam_cond .= " intersect " . $p1_cond;
	}
	else {
	    $pfam_cond = $p1_cond;
	}

	$p_cnt++;
    }
    if ( $pfam_cond ) {
	$pfam_cond = " and gcg.gene_oid in (" . $pfam_cond . ") ";
    }

    my $tigrfam_cond = "";
    my $t_cnt = 0;
    for my $tigr ( @$tigr_ref ) {
	my $t_name = "gt" . $t_cnt;
	my $t1_cond = "select $t_name.gene_oid from gene_tigrfams $t_name where $t_name.ext_accession = '$tigr'";
	if ( $t_cnt ) {
	    $tigrfam_cond .= " intersect " . $t1_cond;
	}
	else {
	    $tigrfam_cond = $t1_cond;
	}

	$t_cnt++;
    }
    if ( $tigrfam_cond ) {
	$tigrfam_cond = " and gcg.gene_oid in (" . $tigrfam_cond . ") ";
    }

    my $sql = qq{
	select count(distinct gcg.gene_oid)
	    from gene_cog_groups gcg
	    where gcg.cog = '$cog_id'
	    $pfam_cond
	    $tigrfam_cond
	};

    my $sid  = getContactOid();
    if ( $debug && $sid == 312 ) {
	print "*** SQL 5: $sql\n";
    }
    my $cur = execSql( $dbh, $sql, $verbose);
    my( $total_cnt ) = $cur->fetchrow( ); 

    $sql = qq{
	select gkt.ko_terms, count(*) 
	    from gene_cog_groups gcg, gene_ko_terms gkt
	    where gcg.cog = '$cog_id'
	    and gcg.gene_oid = gkt.gene_oid
	    $pfam_cond
	    $tigrfam_cond
	    group by gkt.ko_terms
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    my $total = 0;
    my %h_term;
    for (my $i = 0; $i < 10000; $i++) {
	my( $t_id, $t_cnt ) = $cur->fetchrow( ); 
	last if !$t_id;

	$h_term{$t_id} = $t_cnt;
	$total += $t_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	return @terms;
    }

    print "<p>Total gene count: $total_cnt\n";

    print "<table class='img'>\n";
    print "<th class='img'>KO</th>\n";
    print "<th class='img'>Name</th>\n";
    print "<th class='img'>number of genes</th>\n";
    print "<th class='img'>percentage</th>\n";

    for my $k (keys(%h_term) ) {
	my $t_name = getFunctionName($dbh, $k);
	my $t_cnt = $h_term{$k};
	my $perc = $t_cnt * 100.0 / $total_cnt;
	my $url2   = "$main_cgi?section=$section&page=listFuncGenes" .
	    "&func=";
	$url2 .= $cog_id . "," . $pfam_str;
	if ( $tigr_str ) {
	    $url2 .= "," . $tigr_str;
	}
	$url2 .= "," . $k;
	if ( $perc > $err_cut ) {
	    print "<tr><td class='img'>$k</td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'>" .
		alink($url2, $t_cnt) . "</td>\n";
	    print "<td class='img' align='right'>" .
		sprintf("%.2f", $perc) ."</td></tr>\n";

	    push @terms, ( $k );
	}
	else {
	    print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'><font color='purple'>" .
		alink($url2, $t_cnt) . "</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" . 
		sprintf("%.2f", $perc) ."</font></td></tr>\n";
	}
    }
    print "</table>\n";

    return @terms;
}


#################################################################################
# findImgTerm_CPTK: find IMG Term using COG and Pfam and TIGRfam and KO
#################################################################################
sub findImgTerm_CPTK {
    my ($dbh, $err_cut, $cog_id, $pfam_ref, $tigr_ref, $ko_ref) = @_;

    my $pfam_str = join(',', @$pfam_ref);
    my $tigr_str = join(',', @$tigr_ref);
    if ( blankStr($tigr_str) ) {
	$tigr_str = "(No TIGRFam)";
    }
    my $ko_str = join(',', @$ko_ref);
    if ( blankStr($ko_str) ) {
	$ko_str = "(No KO)";
    }
    print "<h4>Find IMG Terms from $cog_id and $pfam_str and $tigr_str and $ko_str</h4>\n";

    my @terms = ();

    my $pfam_cond = "";
    my $p_cnt = 0;
    for my $pfam ( @$pfam_ref ) {
	my $t_name = "gpf" . $p_cnt;
	my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$pfam'";
	if ( $p_cnt ) {
	    $pfam_cond .= " intersect " . $p1_cond;
	}
	else {
	    $pfam_cond = $p1_cond;
	}

	$p_cnt++;
    }
    if ( $pfam_cond ) {
	$pfam_cond = " and gcg.gene_oid in (" . $pfam_cond . ") ";
    }

    my $tigrfam_cond = "";
    my $t_cnt = 0;
    for my $tigr ( @$tigr_ref ) {
	my $t_name = "gt" . $t_cnt;
	my $t1_cond = "select $t_name.gene_oid from gene_tigrfams $t_name where $t_name.ext_accession = '$tigr'";
	if ( $t_cnt ) {
	    $tigrfam_cond .= " intersect " . $t1_cond;
	}
	else {
	    $tigrfam_cond = $t1_cond;
	}

	$t_cnt++;
    }
    if ( $tigrfam_cond ) {
	$tigrfam_cond = " and gcg.gene_oid in (" . $tigrfam_cond . ") ";
    }

    my $ko_cond = "";
    my $k_cnt = 0;
    for my $ko ( @$ko_ref ) {
	my $t_name = "gkt" . $t_cnt;
	my $k1_cond = "select $t_name.gene_oid from gene_ko_terms $t_name where $t_name.ko_terms = '$ko'";
	if ( $k_cnt ) {
	    $ko_cond .= " intersect " . $k1_cond;
	}
	else {
	    $ko_cond = $k1_cond;
	}

	$k_cnt++;
    }
    if ( $ko_cond ) {
	$ko_cond = " and gcg.gene_oid in (" . $ko_cond . ") ";
    }

    my $sql = qq{
	select count(distinct gcg.gene_oid)
	    from gene_cog_groups gcg
	    where gcg.cog = '$cog_id'
	    $pfam_cond
	    $tigrfam_cond
	    $ko_cond
	};

    ## print "*** SQL: $sql\n";
    my $cur = execSql( $dbh, $sql, $verbose);
    my( $total_cnt ) = $cur->fetchrow( ); 

    $sql = qq{
	select gif.function, count(*) 
	    from gene_cog_groups gcg, gene_img_functions gif
	    where gcg.cog = '$cog_id'
	    and gcg.gene_oid = gif.gene_oid
	    $pfam_cond
	    $tigrfam_cond
	    $ko_cond
	    group by gif.function
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    my $total = 0;
    my %h_term;
    for (my $i = 0; $i < 10000; $i++) {
	my( $t_id, $t_cnt ) = $cur->fetchrow( ); 
	last if !$t_id;

	$h_term{$t_id} = $t_cnt;
	$total += $t_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	return @terms;
    }

    print "<p>Total gene count: $total_cnt\n";

    print "<table class='img'>\n";
    print "<th class='img'>IMG Term</th>\n";
    print "<th class='img'>Name</th>\n";
    print "<th class='img'>number of genes</th>\n";
    print "<th class='img'>percentage</th>\n";

    for my $k (keys(%h_term) ) {
	my $t_name = getFunctionName($dbh, $k);
	my $t_cnt = $h_term{$k};
	my $perc = $t_cnt * 100.0 / $total_cnt;
	my $url2   = "$main_cgi?section=$section&page=listFuncGenes" .
	    "&func=";
	$url2 .= $cog_id . "," . $pfam_str;
	if ( $tigr_str ) {
	    $url2 .= "," . $tigr_str;
	}
	if ( $ko_str ) {
	    $url2 .= "," . $ko_str;
	}
	$url2 .= "," . $k;
	if ( $perc > $err_cut ) {
	    print "<tr><td class='img'>$k</td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'>" .
		alink($url2, $t_cnt) . "</td>\n";
	    print "<td class='img' align='right'>" .
		sprintf("%.2f", $perc) ."</td></tr>\n";

	    push @terms, ( $k );
	}
	else {
	    print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
	    print "<td class='img'>$t_name</td>\n";
	    print "<td class='img' align='right'><font color='purple'>" .
		alink($url2, $t_cnt) . "</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" . 
		sprintf("%.2f", $perc) ."</font></td></tr>\n";
	}
    }
    print "</table>\n";

    return @terms;
}


##################################################################################
# showHistogram: find taxon count for COG, Pfam, TIGRfam, KO, IMG terms
##################################################################################
sub showHistogram {
    my ($dbh, $cog_id, $pfam_ref, $tigrfam_ref, $ko_ref, $term_ref) = @_;

    my $func_str = $cog_id;
    my $pfam_str = join(',', @$pfam_ref);
    if ( scalar(@$pfam_ref) > 0 ) {
	$func_str .= "," . $pfam_str;
    }

    my $pfam_cond = "";
    my $p_cnt = 0;
    for my $pfam ( @$pfam_ref ) {
	my $t_name = "gpf" . $p_cnt;
	my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$pfam'";
	if ( $p_cnt ) {
	    $pfam_cond .= " intersect " . $p1_cond;
	}
	else {
	    $pfam_cond = $p1_cond;
	}

	$p_cnt++;
    }
    if ( $pfam_cond ) {
	$pfam_cond = " and g.gene_oid in (" . $pfam_cond . ") ";
    }

    my $tigrfam_str = join(',', @$tigrfam_ref);
    if ( scalar(@$tigrfam_ref) > 0 ) {
	$func_str .= "," . $tigrfam_str;
    }

    my $tigrfam_cond = "";
    my $t_cnt = 0;
    for my $tigr ( @$tigrfam_ref ) {
	my $t_name = "gt" . $t_cnt;
	my $t1_cond = "select $t_name.gene_oid from gene_tigrfams $t_name where $t_name.ext_accession = '$tigr'";
	if ( $t_cnt ) {
	    $tigrfam_cond .= " intersect " . $t1_cond;
	}
	else {
	    $tigrfam_cond = $t1_cond;
	}

	$t_cnt++;
    }
    if ( $tigrfam_cond ) {
	$tigrfam_cond = " and g.gene_oid in (" . $tigrfam_cond . ") ";
    }

    my $ko_str = join(',', @$ko_ref);
    if ( scalar(@$ko_ref) > 0 ) {
	$func_str .= "," . $ko_str;
    }
    my $ko_cond = "";
    my $k_cnt = 0;
    for my $ko ( @$ko_ref ) {
	my $t_name = "gkt" . $k_cnt;
	my $k1_cond = "select $t_name.gene_oid from gene_ko_terms $t_name where $t_name.ko_terms = '$ko'";
	if ( $k_cnt ) {
	    $ko_cond .= " intersect " . $k1_cond;
	}
	else {
	    $ko_cond = $k1_cond;
	}

	$k_cnt++;
    }
    if ( $ko_cond ) {
	$ko_cond = " and g.gene_oid in (" . $ko_cond . ") ";
    }

    my $term_str = join(',', @$term_ref);
    if ( scalar(@$term_ref) > 0 ) {
	$func_str .= "," . $term_str;
    }
    my $term_cond = "";
    my $m_cnt = 0;
    for my $term ( @$term_ref ) {
	my $t_name = "gif" . $m_cnt;
	my $m1_cond = "select $t_name.gene_oid from gene_img_functions $t_name where $t_name.function = $term";
	if ( $m_cnt ) {
	    $term_cond .= " intersect " . $m1_cond;
	}
	else {
	    $term_cond = $m1_cond;
	}

	$m_cnt++;
    }
    if ( $term_cond ) {
	$term_cond = " and g.gene_oid in (" . $term_cond . ") ";
    }

    my $rclause   = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
	select g.taxon, count(distinct g.gene_oid) 
	    from gene g, gene_cog_groups gcg, taxon t
	    where gcg.cog = '$cog_id'
	    and g.gene_oid = gcg.gene_oid
	    and g.obsolete_flag = 'No'
            and g.locus_type = 'CDS'
	    and g.taxon = t.taxon_oid
	    and (t.is_pangenome is null or t.is_pangenome = 'No')
            $rclause
            $imgClause
	    $pfam_cond
	    $tigrfam_cond
	    $ko_cond
	    $term_cond
	    group by g.taxon
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    my $total = 0;
    my %binCount;
    for (my $i = 0; $i < 10000000; $i++) {
	my( $t_id, $t_cnt ) = $cur->fetchrow( ); 
	last if !$t_id;

	if ( $binCount{$t_cnt} ) {
	    $binCount{$t_cnt} += 1;
	}
	else {
	    $binCount{$t_cnt} = 1;
	}

	$total += $t_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	print "<h5>No Genomes Found. (You can change Error cut-off and try again.)</h5>\n";
	return 0;
    }

#    print "<table class='img'>\n";
#    print "<th class='img'>Copies of genes</th>\n";
#    print "<th class='img'>Number of taxons</th>\n";

#    my @keys = sort {$a <=> $b} (keys %binCount);
#    for my $k ( @keys ) {
#	my $t_cnt = $binCount{$k};
#	print "<tr><td class='img'>$k</td>\n";
#	print "<td class='img'>$t_cnt</td>\n";
#	print "</tr>\n";
#    }
#    print "</table>\n";

    my $url = ""; 
 
    # PREPARE THE BAR CHART 
    my $chart = ChartUtil::newBarChart(); 
    $chart->WIDTH(550); 
    $chart->HEIGHT(350); 
    $chart->DOMAIN_AXIS_LABEL("Genomes having n genes"); 
    $chart->RANGE_AXIS_LABEL("Number of genomes"); 
    $chart->INCLUDE_TOOLTIPS("yes"); 
 
    #    $chart->INCLUDE_URLS("yes"); 
    $chart->ITEM_URL( $url . "&chart=y" ); 
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes"); 
    $chart->COLOR_THEME("ORANGE"); 
    my @chartseries; 
    my @chartcategories; 
    my @chartdata; 
 
    # print "<h2>Scaffolds by Gene Count</h2>\n"; 

    print "<table width=780 border=0>\n"; 
    print "<tr>"; 
    print "<td valign=top>\n"; 
 
    print "<p>\n"; 
    print "<p>(Excluding Pangenomes)\n";
 
    print "<table class='img'  border='1'>\n";
#    print "<th class='img' >Select</th>\n"; 
    print "<th class='img' >" . "Gene Count" . "</th>\n";
    print "<th class='img' >No. of Genomes</th>\n";
 
    my @binKeys = reverse( sort { $a <=> $b } ( keys(%binCount) ) ); 
    my $cnt2 = 0;
    for my $k (@binKeys) {
	$cnt2++;
	if ( $cnt2 > 20 ) {
	    last;
	}

        my $nGenes = sprintf( "%d", $k );
#        my $url2   = "$url&gene_count=$nGenes&func=$func_str";
        my $url2   = "$main_cgi?section=$section&page=listGenes" .
	    "&gene_count=$nGenes&func=$func_str";
        my $binCnt = $binCount{$k};
        my $genes  = "genes";
        $genes = "gene" if $nGenes == 1;
 
        print "<tr>\n"; 
#        if ( $binCnt > 0 ) { 
#            print "<td class='img'><input type='radio' name='range' value='"
#              . $nGenes . ":" 
#              . $nGenes 
#              . "' /></td>\n"; 
#        } else { 
#            print "<td class='img'></td>\n";
#        } 
 
        print "<td class='img' align='right'>$nGenes</td>\n";
        print "<td class='img' align='right'>" .
	    alink($url2, $binCnt) . "</td>\n";
        print "</tr>\n";
 
        #       print "Genomes having $nGenes $genes ";
        #       print "(" . alink( $url2, $binCnt ) . ")<br/>\n";
        push @chartcategories, "$nGenes";
        push @chartdata,       $binCnt; 
    } 
    print "</table>\n"; 
    print "<br/>\n"; 
    if ( $cnt2 > 20 ) {
	print "<p><font color='red'>List is too long -- truncated at 20 entries.</font>\n";
	print "<br/>\n";
    }

    my $name = "_section_${section}_genomeGeneCount"; 
#    print "<p><font color='red'>Under Construction</font>\n";
#    print submit( 
#                  -name  => $name, 
#                  -value => "Go", 
#                  -class => "smdefbutton" 
#		  ); 
 
    print "</td><td valign=top align=right>\n"; 
 
    # display the bar chart 
    push @chartseries, "num genomes"; 
    $chart->SERIES_NAME( \@chartseries ); 
    $chart->CATEGORY_NAME( \@chartcategories ); 
    my $datastr = join( ",", @chartdata ); 
    my @datas = ($datastr); 
    $chart->DATA( \@datas ); 
    print "<td align=right valign=center>\n"; 
 
    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) { 
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printGenomeDistribution", 1 );
            while ( my $s = $FH->getline() ) {
                print $s; 
            } 
            close($FH); 
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX 
              . ".png' BORDER=0 "; 
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    } 
    print "</td></tr>\n";
    print "</table>\n";

    return $total;
}


##################################################################################
# showTaxonGeneCntHistogram: 
##################################################################################
sub showTaxonGeneCntHistogram {
    my ($cond, $gf_name) = @_;

    if ( ! $gf_name ) {
	$gf_name = "gene";
    }

    my $gene_cond = " ";
    if ( $gf_name eq 'gene' ) {
	$gene_cond = " and g.obsolete_flag = 'No' and g.locus_type = 'CDS' ";
    }

    printStartWorkingDiv();
    print "<p>Computing genome-gene count ...\n";
    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
	select g.taxon, count(distinct g.gene_oid) 
	    from $gf_name g
            where g.taxon in (select t9.taxon_oid from taxon t9 
                where t9.domain in ('Archaea', 'Bacteria', 'Eukaryota'))
            $gene_cond
            $rclause
            $imgClause
	    $cond
	    group by g.taxon
	};

    my $sid  = getContactOid();
    if ( $debug && $sid == 312 ) {
	print "<p>Histogram SQL: $sql\n";
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    printEndWorkingDiv();

    my $total = 0;
    my %binCount;
    for (my $i = 0; $i < 1000000; $i++) {
	my( $t_id, $t_cnt ) = $cur->fetchrow( ); 
	last if !$t_id;

	if ( $binCount{$t_cnt} ) {
	    $binCount{$t_cnt} += 1;
	}
	else {
	    $binCount{$t_cnt} = 1;
	}

	$total += $t_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	print "<h5>No Genomes Found.</h5>\n";
        #$dbh->disconnect();
	return 0;
    }

    print "<p>Selected function gene count: $total\n";

#    print "<table class='img'>\n";
#    print "<th class='img'>Copies of genes</th>\n";
#    print "<th class='img'>Number of taxons</th>\n";

#    my @keys = sort {$a <=> $b} (keys %binCount);
#    for my $k ( @keys ) {
#	my $t_cnt = $binCount{$k};
#	print "<tr><td class='img'>$k</td>\n";
#	print "<td class='img'>$t_cnt</td>\n";
#	print "</tr>\n";
#    }
#    print "</table>\n";

    my $url = ""; 
 
    # PREPARE THE BAR CHART 
    my $chart = ChartUtil::newBarChart(); 
    $chart->WIDTH(550); 
    $chart->HEIGHT(350); 
    $chart->DOMAIN_AXIS_LABEL("Genomes having n genes"); 
    $chart->RANGE_AXIS_LABEL("Number of genomes"); 
    $chart->INCLUDE_TOOLTIPS("yes"); 
 
    #    $chart->INCLUDE_URLS("yes"); 
    $chart->ITEM_URL( $url . "&chart=y" ); 
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes"); 
    $chart->COLOR_THEME("ORANGE"); 
    my @chartseries; 
    my @chartcategories; 
    my @chartdata; 
 
    print "<p>The following table lists number of genes in genomes that are annotated with the selected function(s).\n";

    print "<table width=780 border=0>\n"; 
    print "<tr>"; 
    print "<td valign=top>\n"; 
 
    print "<p>\n"; 
 
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Select</th>\n"; 
    print "<th class='img' >" . "Gene Count" . "</th>\n";
    print "<th class='img' >No. of Genomes</th>\n";
 
#    my @binKeys = reverse( sort { $a <=> $b } ( keys(%binCount) ) ); 
    my @binKeys = ( sort { $a <=> $b } ( keys(%binCount) ) ); 
    my $cnt2 = 0;
    for my $k (@binKeys) {
	$cnt2++;
	if ( $cnt2 > 20 ) {
	    last;
	}

        my $nGenes = sprintf( "%d", $k );
#        my $url2   = "$url&gene_count=$nGenes&func=$func_str";
#        my $url2   = "$main_cgi?section=$section&page=listGenes" .
#	    "&gene_count=$nGenes&func=$func_str";
        my $binCnt = $binCount{$k};
        my $genes  = "genes";
        $genes = "gene" if $nGenes == 1;
 
        print "<tr>\n"; 
        if ( $binCnt > 0 ) { 
            print "<td class='img'><input type='radio' name='range' value='"
              . $nGenes . ":" 
              . $nGenes 
              . "' /></td>\n"; 
        } else { 
            print "<td class='img'></td>\n";
        } 
 
        print "<td class='img' align='right'>$nGenes</td>\n";
        print "<td class='img' align='right'>" .
	    $binCnt . "</td>\n";
#	    alink($url2, $binCnt) . "</td>\n";
        print "</tr>\n";
 
        #       print "Genomes having $nGenes $genes ";
        #       print "(" . alink( $url2, $binCnt ) . ")<br/>\n";
        push @chartcategories, "$nGenes";
        push @chartdata,       $binCnt; 
    } 

    print "</table>\n"; 
    print "<br/>\n"; 
    if ( $cnt2 > 20 ) {
	print "<p><font color='red'>List is too long -- truncated at 20 entries.</font>\n";
	print "<br/>\n";
    }

    my $name = "_section_${section}_listHistogramGenes"; 
    print submit( 
                  -name  => $name, 
                  -value => "Show Detail", 
                  -class => "smdefbutton" 
		  ); 
 
    print "</td><td valign=top align=right>\n"; 
 
    # display the bar chart 
    push @chartseries, "num genomes"; 
    $chart->SERIES_NAME( \@chartseries ); 
    $chart->CATEGORY_NAME( \@chartcategories ); 
    my $datastr = join( ",", @chartdata ); 
    my @datas = ($datastr); 
    $chart->DATA( \@datas ); 
    print "<td align=right valign=center>\n"; 
 
    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) { 
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printGenomeDistribution", 1 );
            while ( my $s = $FH->getline() ) {
                print $s; 
            } 
            close($FH); 
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX 
              . ".png' BORDER=0 "; 
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    } 
    print "</td></tr>\n";
    print "</table>\n";

    #$dbh->disconnect();
    return $total;
}


############################################################################
# findImgTerm_CP: find IMG terms using COG and Pfam
############################################################################
sub findImgTerm_CP {
    my ($dbh, $cog_id, $pfam_id, $err_cut) = @_;

    print "<h4>Find IMG Terms from $cog_id and $pfam_id</h4>\n";

    my @terms = ();

    my $sql = qq{
	select gif.function, count(*) 
	    from gene_cog_groups gcg, gene_img_functions gif, gene_pfam_families gpf 
	    where gcg.cog = ?
	    and gcg.gene_oid = gif.gene_oid 
	    and gpf.pfam_family = ?
	    and gpf.gene_oid = gif.gene_oid 
	    group by gif.function 
	};

    my $cur = execSql( $dbh, $sql, $verbose, $cog_id, $pfam_id ); 
    my $total = 0;
    my %h_term;
    for (my $i = 0; $i < 1000; $i++) {
	my( $term_oid, $term_cnt ) = $cur->fetchrow( ); 
	last if !$term_oid;

	$h_term{$term_oid} = $term_cnt;
	$total += $term_cnt;
    }
    $cur->finish();

    if ( $total == 0 ) {
	return @terms;
    }

    print "<table class='img'>\n";
    print "<th class='img'>IMG Term</th>\n";
    print "<th class='img'>number of genes</th>\n";
    print "<th class='img'>percentage</th>\n";

    for my $k (keys(%h_term) ) {
	my $t_cnt = $h_term{$k};
	my $perc = $t_cnt * 100.0 / $total;
	if ( $perc > $err_cut ) {
	    print "<tr><td class='img'>$k</td>\n";
	    print "<td class='img' align='right'>$t_cnt</td>\n";
	    print "<td class='img' align='right'>" .
		sprintf("%.2f", $perc) ."</td></tr>\n";

	    push @terms, ( $k );
	}
	else {
	    print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>$t_cnt</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" . 
		sprintf("%.2f", $perc) ."</font></td></tr>\n";
	}
    }
    print "</table>\n";

    return @terms;
}

############################################################################
# findPfam_C: find pfam from COG
############################################################################
sub findPfam_C {
    my ($dbh, $cog_id, $err_cut) = @_;

    my @pfams = ();

    # check pfam_family_cogs table first
    my $sql = qq{ 
	select ext_accession
	    from pfam_family_cogs
	    where cog = ? 
	}; 
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id ); 
    for (my $j; $j < 1000; $j++) {
	my( $pfam_id ) = $cur->fetchrow( ); 
	last if !$pfam_id;

	push @pfams, ( $pfam_id );
    }
    $cur->finish();

    if ( scalar(@pfams) > 0 ) {
	printSet("From PFAM_FAMILY_COGS table", @pfams);

	print "<table class='img'>\n";
	print "<th class='img'>pfam</th>\n";
	print "<th class='img'>Name</th>\n";

	for my $p2 ( @pfams ) {
	    my $name2 = getFunctionName($dbh, $p2);
	    print "<tr>\n";
	    print "<td class='img'>$p2</td><td class='img'>";
	    print escapeHTML($name2) . "</td></tr>\n";
	}
	print "</table>\n";

	return @pfams;
    }

    # go through genes
    $sql = qq{
	select count(*)
	    from gene_cog_groups t1
	    where t1.cog = ?
	};
    $cur = execSql( $dbh, $sql, $verbose, $cog_id ); 
    my( $total ) = $cur->fetchrow( ); 
    $cur->finish();

    $sql = qq{
	select t2.pfam_family, count(*) 
	    from gene_cog_groups t1, gene_pfam_families t2
	    where t1.cog = ?
	    and t1.gene_oid = t2.gene_oid 
	    group by t2.pfam_family
	};

    # print "<p>SQL: $sql\n";

    $cur = execSql( $dbh, $sql, $verbose, $cog_id ); 
    my %h_item;
    my $p_total = 0;
    for (my $i = 0; $i < 1000; $i++) {
	my( $item_oid, $item_cnt ) = $cur->fetchrow( ); 
	last if !$item_oid;

	$h_item{$item_oid} = $item_cnt;
	$p_total += $item_cnt;
    }
    $cur->finish();

    if ( $p_total == 0 ) {
	return @pfams;
    }

    print "<table class='img'>\n";
    print "<th class='img'>pfam</th>\n";
    print "<th class='img'>Name</th>\n";
    print "<th class='img'>number of genes</th>\n";
    print "<th class='img'>percentage</th>\n";

    for my $k (keys(%h_item) ) {
	my $name = getFunctionName($dbh, $k);
	my $t_cnt = $h_item{$k};
	my $perc = $t_cnt * 100.0 / $total;
	my $url2   = "$main_cgi?section=$section&page=listFuncGenes" .
	    "&func=" . $cog_id . "," . $k;

	if ( $perc > $err_cut ) {
	    print "<tr><td class='img'>$k</td>\n";
	    print "<td class='img'>" . escapeHTML($name) . "</td>\n";
	    print "<td class='img' align='right'>" .
		alink($url2, $t_cnt) . "</td>\n";
	    print "<td class='img' align='right'>" . 
		sprintf("%.2f", $perc) ."</td></tr>\n";
	    push @pfams, ( $k );
	}
	else {
	    print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
	    print "<td class='img'><font color='purple'>" .
		escapeHTML($name) . "</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" .
		alink($url2, $t_cnt) . "</font></td>\n";
	    print "<td class='img' align='right'><font color='purple'>" . 
		sprintf("%.2f", $perc) ."</font></td></tr>\n";
	}
    }
    print "</table>\n";

    return @pfams;
}




############################################################################
# findNewFunction
############################################################################
sub findNewFunction {
    my ($dbh, $id, $err_cut) = @_;

    my @func_types = ( 'COG', 'pfam', 'TIGR', 'KO', 'ImgTerm' );

    my $my_type = 'ImgTerm';
    my $my_table = 'gene_img_functions';
    my $my_field = 'function';

    my @items = ();

    if ( $id =~ /COG/ ) {
	$my_type = 'COG';
	$my_table = 'gene_cog_groups';
	$my_field = 'cog';
    }
    elsif ( $id =~ /pfam/ ) {
	$my_type = 'pfam';
	$my_table = 'gene_pfam_families';
	$my_field = 'pfam_family';
    }
    elsif ( $id =~ /TIGR/ ) {
	$my_type = 'TIGR';
	$my_table = 'gene_tigrfams';
	$my_field = 'ext_accession';
    }
    elsif ( $id =~ /KO/ ) {
	$my_type = 'KO';
	$my_table = 'gene_ko_terms';
	$my_field = 'ko_terms';
    }

    print "<h4>Find Additional Functions from $my_type $id</h4>\n";

    for my $f1 ( @func_types ) {
	if ( $f1 eq $my_type ) {
	    next;
	}

	print "<h5>Find $f1 from $my_type</h5>\n";
    
	my $select_table = 'gene_img_functions';
	my $select_field = 'function';

	if ( $f1 eq 'COG' ) {
	    $select_table = 'gene_cog_groups';
	    $select_field = 'cog';
	}
	elsif ( $f1 eq 'pfam' ) {
	    $select_table = 'gene_pfam_families';
	    $select_field = 'pfam_family';
	}
	elsif ( $f1 eq 'TIGR' ) {
	    $select_table = 'gene_tigrfams';
	    $select_field = 'ext_accession';
	}
	elsif ( $f1 eq 'KO' ) {
	    $select_table = 'gene_ko_terms';
	    $select_field = 'ko_terms';
	}

	my $sql = qq{
	    select t2.$select_field, count(*) 
	    from $my_table t1, $select_table t2
	    where t1.$my_field = ?
	    and t1.gene_oid = t2.gene_oid 
	    group by t2.$select_field
	};

	# print "<p>SQL: $sql\n";

	my $cur = execSql( $dbh, $sql, $verbose, $id ); 
	my $total = 0;
	my %h_item;
	for (my $i = 0; $i < 1000; $i++) {
	    my( $item_oid, $item_cnt ) = $cur->fetchrow( ); 
	    last if !$item_oid;

	    $h_item{$item_oid} = $item_cnt;
	    $total += $item_cnt;
	}
	$cur->finish();

	if ( $total == 0 ) {
	    return @items;
	}

	print "<table class='img'>\n";
	print "<th class='img'>$f1</th>\n";
	print "<th class='img'>number of genes</th>\n";
	print "<th class='img'>percentage</th>\n";

	for my $k (keys(%h_item) ) {
	    my $t_cnt = $h_item{$k};
	    my $perc = $t_cnt * 100.0 / $total;
	    if ( $perc > $err_cut ) {
		print "<tr><td class='img'>$k</td>\n";
		print "<td class='img' align='right'>$t_cnt</td>\n";
		print "<td class='img' align='right'>" . 
		    sprintf("%.2f", $perc) ."</td></tr>\n";
		push @items, ( $k );
	    }
	    else {
		print "<tr><td class='img'><font color='purple'>$k</font></td>\n";
		print "<td class='img' align='right'><font color='purple'>$t_cnt</font></td>\n";
		print "<td class='img' align='right'><font color='purple'>" . 
		    sprintf("%.2f", $perc) ."</font></td></tr>\n";
	    }
	}

	print "</table>\n";
    }

    return @items;
}


sub printSet {
    my ($title, @set) = @_;

    print "<p>$title: {";
    my $first = 1;
    for my $c2 ( @set ) {
	if ( $first ) {
	    $first = 0;
	}
	else {
	    print ", ";
	}

	if ( isInt($c2) ) {
	    print "IMG" . $c2;
	}
	else {
	    print $c2;
	}
    }

    print "} (size: " . scalar(@set) . ")\n";
}


sub getFunctionName {
    my ($dbh, $id) = @_;

    my $name = $id;
    my $sql = "";

    if ( isInt($id) ) {
	# IMG term
	$sql = "select term_oid, term from img_term where term_oid = ?";
    }
    elsif ( $id =~ /^ITERM/ ) {
	# IMG term
	my ( $a1, $a2 ) = split(/\:/, $id);
	$id = $a2;
	$sql = "select term_oid, term from img_term where term_oid = ?";
    }
    elsif ( $id =~ /^COG/ ) {
	# COG
	$sql = "select cog_id, cog_name from cog where cog_id = ?";
    }
    elsif ( $id =~ /^pfam/ ) {
	# pfam
#	$sql = "select ext_accession, name from pfam_family where ext_accession = ?";
	$sql = "select ext_accession, description from pfam_family where ext_accession = ?";
    }
    elsif ( $id =~ /^TIGR/ ) {
	# TIGRFam
	$sql = "select ext_accession, expanded_name from tigrfam where ext_accession = ?";
    }
    elsif ( $id =~ /^KO/ ) {
	# KO
	$sql = "select ko_id, nvl(definition, ko_name) from ko_term where ko_id = ?";
    }
    elsif ( $id =~ /^IPR/ ) {
	$sql = "select ext_accession, name from interpro where ext_accession = ?";
    }

    if ( $sql ) {
	my $cur = execSql( $dbh, $sql, $verbose, $id ); 
	my( $id2, $name2 ) = $cur->fetchrow( ); 
	$cur->finish();
	if ( $id2 ) {
	    $name = $name2;
	}
    }

    return $name;
}



############################################################################
# listFuncGenes
############################################################################
sub listFuncGenes {
    my $contact_oid = getContactOid();

    printMainForm();

    print "<h1>List Genes with All Specified Functions</h1>\n";

    my $func_str = param("func");
    my @func_ids = split(/\,/, $func_str);
    if ( scalar(@func_ids) == 0 ) {
	print "<p>No function has been selected.\n";
	print end_form();
	return;
    }

    my $func_display = "";

    my $cog_id = "";
    my $pfam_cond = "";
    my $p_cnt = 0;
    my $tigrfam_cond = "";
    my $t_cnt = 0;
    my $ko_cond = "";
    my $k_cnt = 0;
    my $term_cond = "";
    my $m_cnt = 0;

    for my $func_id ( @func_ids ) {
	my $s2 = $func_id;
	if ( isInt($s2) ) {
	    $s2 = "IMG" . $s2;
	}
	if ( $func_display ) {
	    $func_display .= "," . $s2;
	}
	else {
	    $func_display = $s2;
	}

	if ( $func_id =~ /^COG/ ) {
	    $cog_id = $func_id;
	}
	elsif ( $func_id =~ /^pfam/ ) {
	    my $t_name = "gpf" . $p_cnt;
	    my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$func_id'";
	    if ( $p_cnt > 0 ) {
		$pfam_cond .= " intersect " . $p1_cond;
	    }
	    else {
		$pfam_cond = $p1_cond;
	    }

	    $p_cnt++;
	}
	elsif ( $func_id =~ /^TIGR/ ) {
	    my $t_name = "gt" . $t_cnt;
	    my $t1_cond = "select $t_name.gene_oid from gene_tigrfams $t_name where $t_name.ext_accession = '$func_id'";
	    if ( $t_cnt > 0 ) {
		$tigrfam_cond .= " intersect " . $t1_cond;
	    }
	    else {
		$tigrfam_cond = $t1_cond;
	    }

	    $t_cnt++;
	}
	elsif ( $func_id =~ /^KO/ ) {
	    my $t_name = "gkt" . $k_cnt;
	    my $k1_cond = "select $t_name.gene_oid from gene_ko_terms $t_name where $t_name.ko_terms = '$func_id'";
	    if ( $k_cnt > 0 ) {
		$ko_cond .= " intersect " . $k1_cond;
	    }
	    else {
		$ko_cond = $k1_cond;
	    }

	    $k_cnt++;
	}
	elsif ( isInt($func_id) ) {
	    my $t_name = "gif" . $p_cnt;
	    my $m1_cond = "select $t_name.gene_oid from gene_img_functions $t_name where $t_name.function = $func_id";
	    if ( $m_cnt > 0 ) {
		$term_cond .= " intersect " . $m1_cond;
	    }
	    else {
		$term_cond = $m1_cond;
	    }

	    $m_cnt++;
	}
    }   # end for my func_id

    if ( $pfam_cond ) {
	$pfam_cond = " and g.gene_oid in (" . $pfam_cond . ") ";
    }

    if ( $tigrfam_cond ) {
	$tigrfam_cond = " and g.gene_oid in (" . $tigrfam_cond . ") ";
    }

    if ( $ko_cond ) {
	$ko_cond = " and g.gene_oid in (" . $ko_cond . ") ";
    }

    if ( $term_cond ) {
	$term_cond = " and g.gene_oid in (" . $term_cond . ") ";
    }

    print "<h3>Functions: $func_display</h3>\n";

    if ( !$cog_id ) {
	print end_form();
	return;
    }

    printStatusLine ("Loading ...", 1);

    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $total_cnt = 0;
    my $sql = qq{
	select g.gene_oid, g.gene_display_name, g.taxon,
	t.taxon_display_name
	    from gene g, gene_cog_groups gcg, taxon t
	    where gcg.cog = '$cog_id'
	    and g.gene_oid = gcg.gene_oid
	    and g.obsolete_flag = 'No'
            and g.locus_type = 'CDS'
	    and g.taxon = t.taxon_oid
	    and (t.is_pangenome is null or t.is_pangenome = 'No')
            $rclause
            $imgClause
	    $pfam_cond
	    $tigrfam_cond
	    $ko_cond
	    $term_cond
	};

    # print "<p>SQL: $sql\n";

    my $it = new InnerTable( 1, "listGenes$$", "listGenes", 3 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Selection"); 
    $it->addColSpec( "Gene ID", "number asc", "right" );
    $it->addColSpec( "Gene Name", "char asc","left" );
    $it->addColSpec( "Organism Name", "char asc", "left" );

    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my( $gene_oid, $gene_name, $taxon_oid, $taxon_display_name ) =
	    $cur->fetchrow( ); 
	last if !$gene_oid;
	last if !$taxon_oid;

	my $row; 
 
	$row .= $sd 
	    . "<input type='checkbox' name='gene_oid' value='$gene_oid' checked />\t"; 
	my $gene_url = 
	    "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid"; 
	$row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ) . "\t"; 
	$row .= $gene_name . $sd . escHtml($gene_name) . "\t"; 

	my $taxon_url = "$main_cgi?section=TaxonDetail" .
	    "&page=taxonDetail&taxon_oid=$taxon_oid";
	$row .= $taxon_display_name . $sd .
	    alink( $taxon_url, $taxon_display_name ) . "\t";

	$it->addRow($row);
	$total_cnt++;
    }
    $cur->finish();

    #$dbh->disconnect();

    $it->printOuterTable(1);

    printStatusLine( "$total_cnt genes loaded.", 2 );

    print submit( 
                -id  => "go3", 
                -name  => "_section_${section}_addGeneCart", 
                -value => "Add Selected to Gene Cart", 
		  -class => "meddefbutton " );
    print nbsp(1); 
    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
 

    print end_form();
}
 

############################################################################
# listGenes
############################################################################
sub listGenes {
    my $contact_oid = getContactOid();

    printMainForm();

    print "<h1>List Genes with All Specified Functions</h1>\n";

    my $func_str = param("func");
    my @func_ids = split(/\,/, $func_str);
    if ( scalar(@func_ids) == 0 ) {
	print "<p>No function has been selected.\n";
	print end_form();
	return;
    }

    my $gene_count = param("gene_count");

    my $func_display = "";

    my $cog_id = "";
    my $pfam_cond = "";
    my $p_cnt = 0;
    my $tigrfam_cond = "";
    my $t_cnt = 0;
    my $ko_cond = "";
    my $k_cnt = 0;
    my $term_cond = "";
    my $m_cnt = 0;

    for my $func_id ( @func_ids ) {
	my $s2 = $func_id;
	if ( isInt($s2) ) {
	    $s2 = "IMG" . $s2;
	}
	if ( $func_display ) {
	    $func_display .= "," . $s2;
	}
	else {
	    $func_display = $s2;
	}

	if ( $func_id =~ /^COG/ ) {
	    $cog_id = $func_id;
	}
	elsif ( $func_id =~ /^pfam/ ) {
	    my $t_name = "gpf" . $p_cnt;
	    my $p1_cond = "select $t_name.gene_oid from gene_pfam_families $t_name where $t_name.pfam_family = '$func_id'";
	    if ( $p_cnt > 0 ) {
		$pfam_cond .= " intersect " . $p1_cond;
	    }
	    else {
		$pfam_cond = $p1_cond;
	    }

	    $p_cnt++;
	}
	elsif ( $func_id =~ /^TIGR/ ) {
	    my $t_name = "gt" . $t_cnt;
	    my $t1_cond = "select $t_name.gene_oid from gene_tigrfams $t_name where $t_name.ext_accession = '$func_id'";
	    if ( $t_cnt > 0 ) {
		$tigrfam_cond .= " intersect " . $t1_cond;
	    }
	    else {
		$tigrfam_cond = $t1_cond;
	    }

	    $t_cnt++;
	}
	elsif ( $func_id =~ /^KO/ ) {
	    my $t_name = "gkt" . $k_cnt;
	    my $k1_cond = "select $t_name.gene_oid from gene_ko_terms $t_name where $t_name.ko_terms = '$func_id'";
	    if ( $k_cnt > 0 ) {
		$ko_cond .= " intersect " . $k1_cond;
	    }
	    else {
		$ko_cond = $k1_cond;
	    }

	    $k_cnt++;
	}
	elsif ( isInt($func_id) ) {
	    my $t_name = "gif" . $p_cnt;
	    my $m1_cond = "select $t_name.gene_oid from gene_img_functions $t_name where $t_name.function = $func_id";
	    if ( $m_cnt > 0 ) {
		$term_cond .= " intersect " . $m1_cond;
	    }
	    else {
		$term_cond = $m1_cond;
	    }

	    $m_cnt++;
	}
    }   # end for my func_id

    if ( $pfam_cond ) {
	$pfam_cond = " and g.gene_oid in (" . $pfam_cond . ") ";
    }

    if ( $tigrfam_cond ) {
	$tigrfam_cond = " and g.gene_oid in (" . $tigrfam_cond . ") ";
    }

    if ( $ko_cond ) {
	$ko_cond = " and g.gene_oid in (" . $ko_cond . ") ";
    }

    if ( $term_cond ) {
	$term_cond = " and g.gene_oid in (" . $term_cond . ") ";
    }

    print "<h3>Functions: $func_display</h3>\n";
    print "<h4>Gene Count (per genome): $gene_count</h4>\n";

    if ( !$cog_id ) {
	print end_form();
	return;
    }

    printStatusLine ("Loading ...", 1);

    my $rclause   = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
	select g.taxon, count(distinct g.gene_oid) 
	    from gene g, gene_cog_groups gcg, taxon t
	    where gcg.cog = '$cog_id'
	    and g.gene_oid = gcg.gene_oid
	    and g.obsolete_flag = 'No'
            and g.locus_type = 'CDS'
	    and g.taxon = t.taxon_oid
	    and (t.is_pangenome is null or t.is_pangenome = 'No')
            $rclause
	    $imgClause
            $pfam_cond
	    $tigrfam_cond
	    $ko_cond
	    $term_cond
	    group by g.taxon
	    having count(distinct g.gene_oid) = $gene_count
	    order by 1
	};

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    my $j = 0;
    my @taxon_list;
    my $taxon_str = "";
    for (;;) {
	my( $taxon_oid, $count ) = $cur->fetchrow( ); 
	last if !$taxon_oid;

	if ( $taxon_str ) {
	    $taxon_str .= "," . $taxon_oid;
	}
	else {
	    $taxon_str = $taxon_oid;
	}

	$j++;
	if ( $j >= 1000 ) {
	    push @taxon_list, ( $taxon_str );
	    $taxon_str = "";
	    $j = 0;
	}
    }
    $cur->finish();
    if ( $taxon_str ) {
	push @taxon_list, ( $taxon_str );
    }

    my $it = new InnerTable( 1, "listGenes$$", "listGenes", 3 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Selection"); 
    $it->addColSpec( "Gene ID", "number asc", "right" );
    $it->addColSpec( "Gene Name", "char asc","left" );
    $it->addColSpec( "Organism Name", "char asc", "left" );

    my $rclause   = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $total_cnt = 0;
    for $taxon_str ( @taxon_list ) {
	$sql = qq{
	    select g.gene_oid, g.gene_display_name, g.taxon,
	    t.taxon_display_name
		from gene g, gene_cog_groups gcg, taxon t
		where gcg.cog = '$cog_id'
		and g.gene_oid = gcg.gene_oid
		and g.obsolete_flag = 'No'
                and g.locus_type = 'CDS'
		and g.taxon = t.taxon_oid
		and (t.is_pangenome is null or t.is_pangenome = 'No')
                $rclause
                $imgClause
		$pfam_cond
		$tigrfam_cond
		$ko_cond
		$term_cond
		and g.taxon in ( $taxon_str )
	    };

	$cur = execSql( $dbh, $sql, $verbose );
	for (;;) {
	    my( $gene_oid, $gene_name, $taxon_oid, $taxon_display_name ) =
		$cur->fetchrow( ); 
	    last if !$gene_oid;
	    last if !$taxon_oid;

	    my $row; 
 
	    $row .= $sd 
		. "<input type='checkbox' name='gene_oid' value='$gene_oid' checked />\t"; 
	    my $gene_url = 
		"$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid"; 
	    $row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ) . "\t"; 
	    $row .= $gene_name . $sd . escHtml($gene_name) . "\t"; 

	    my $taxon_url = "$main_cgi?section=TaxonDetail" .
		"&page=taxonDetail&taxon_oid=$taxon_oid";
	    $row .= $taxon_display_name . $sd .
		alink( $taxon_url, $taxon_display_name ) . "\t";

	    $it->addRow($row);
	    $total_cnt++;
	}
	$cur->finish();
    }  # end for taxon_str

    #$dbh->disconnect();

    $it->printOuterTable(1);

    printStatusLine( "$total_cnt genes loaded.", 2 );

    print submit( 
                -id  => "go3", 
                -name  => "_section_${section}_addGeneCart", 
                -value => "Add Selected to Gene Cart", 
		  -class => "meddefbutton " );
    print nbsp(1); 
    print "<input type='button' name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
 

    print end_form();
}
 



1;
