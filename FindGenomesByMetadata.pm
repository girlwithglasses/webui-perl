############################################################################
# FindGenomesByMetadata.pm - split from FindGenomes.pm
#  Handle the options under the "Find Metadata Genomes" tab menu.
#
# $Id: FindGenomesByMetadata.pm 33841 2015-07-29 20:48:56Z klchu $
############################################################################
package FindGenomesByMetadata;
my $section = "FindGenomes";
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use TermNode;
use TermNodeMgr;
use DataEntryUtil;
use GoldDataEntryUtil;
use Data::Dumper;
use TreeViewFrame;
use HtmlUtil;
use D3ChartUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $tmp_dir              = $env->{tmp_dir};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $img_internal         = $env->{img_internal};
my $include_metagenomes  = $env->{include_metagenomes};
my $use_img_gold         = $env->{use_img_gold};
my $YUI28                = $env->{yui_dir_28};
my $include_metagenomes  = $env->{include_metagenomes};

my $img_er_submit_url    = $env->{img_er_submit_url};
my $img_mer_submit_url   = $env->{img_mer_submit_url};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
	my $page = param("page");

    if ( $page eq "metadataForm" ) {
        my $id = param("id");
        my $tabName = param("tabName");
        if ($tabName =~ /operation/i ) {
            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq {
                <response>
                    <div id='$id'><![CDATA[ 
            };
            printMetadataCategoryOperationForm();
            print qq { 
                ]]></div>
                <name></name>
                </response>
            }; 
        }
        elsif ( $tabName =~ /chart/i ) {
            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq {
                <response>
                    <div id='$id'><![CDATA[ 
            };
            printMetadataCategoryChartForm();
            print qq { 
                ]]></div>
                <name></name>
                </response>
            }; 
	}
    }
	elsif ( $page eq "metadataCategoryChartResults" ||
		paramMatch("metadataCategoryChartResults") ne "" ) {
	    printMetadataCategoryChartResults ();
	}
}

############################################################################
# printMetadataCategorySearchForm - Print MetadataCategorySearchForm 
############################################################################
sub printMetadataCategorySearchForm {
    printStatusLine( "Loading ...", 1 );

    my $templateFile = "$base_dir/findGenomesByMetadata.html";
    my $rfh = newReadFileHandle( $templateFile, "printMetadataCategorySearchForm" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__optionList__/ ) {
            printCategoryOptionList();
        } elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        } else {
            print "$s\n";
        }
    }
    close $rfh;

    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printMetadataCategoryOperationForm - Print MetadataCategoryOperation Form 
############################################################################
sub printMetadataCategoryOperationForm {
    printStatusLine( "Loading ...", 1 );

    printHint( "Expand tree to select or deselect values." );

    print start_form(
        -action => "$section_cgi",
        -class  => "alignleft",
        -name   => "metadataForm"
    );

    #printTreeViewMarkup();
    printCategoryContent();

    print "<br/>\n";
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "metadataCategoryOperationResults" );
    my $name = "_section_${section}_submit";
    print submit(
        -id    => "go",
        -name  => $name,
        -value => "Go",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print reset(
        -id    => "reset",
        -name  => "Reset",
        -value => "Reset",
        -class => "smbutton"
    );

    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printCategoryContent - Show category selection form.
############################################################################
sub printCategoryContent {

    printTableTop();

    print "<table id='metadataTable' class='img' width='350'>\n";

    my $dbh;
    if ($use_img_gold) {
        $dbh = WebUtil::dbGoldLogin();
    } else {
        $dbh = dbLogin();
    }

    my @categoryNames = getCategoryNames();
    my $numCategories = scalar(@categoryNames);
    #print "printCategoryContent() categoryNames=@categoryNames<br/>\n";

    my %categories    = ();
    if ($numCategories > 0) {
        print qq{
            <tr>
            <th class='img_liteText' colspan=2 nowrap>Project Metadata</th>
            </tr>
        };

        for ( my $i = 0 ; $i < $numCategories ; $i++ ) {
            my $selectionAttr = $categoryNames[$i];

            print "<tr>\n";
            print "<td class='img' nowrap>\n";
            print "<div id='$selectionAttr' class='ygtv-checkbox'>\n";
    
            my $jsObject="";
            if ($use_img_gold) {
                $jsObject = getCategoryRow_ImgGold( $dbh, $selectionAttr );
            } else {
                $jsObject = getCategoryRow( $dbh, $selectionAttr );
            }
            $categories{ $categoryNames[$i] } = $jsObject;
            #webLog("$jsObject\n");
            #print "$jsObject\n";
    
            print "</div></td>\n";
            printIntraCategoryOperator();            
            print "</tr>\n";
    
            if ( $i < $numCategories - 1 ) {
                printInterCategoryOperator();
            }
        }
    }
    #$dbh->disconnect();

    print "</table>\n";
    
    my $categoriesObj = "{'category' : [ ";
    for ( my $i = 0 ; $i < $numCategories ; $i++ ) {
        $categoriesObj .= "{name : '$categoryNames[$i]', ";
        #$categoriesObj .= "value : $categories{$categoryNames[$i]}}";
        $categoriesObj .= "value : [" . $categories{$categoryNames[$i]} . "]}";
        if ($i != $numCategories-1) {
            $categoriesObj .= ", ";
        }
    }
    $categoriesObj .= "]}";
    #webLog("$categoriesObj\n");
    #print "$categoriesObj\n";
    setJSObjects( $categoriesObj );
    
}

sub getCategoryNames {

    my @categoryNames = ();
    if ($use_img_gold) {
        my @names = DataEntryUtil::getGoldCondAttr();

	for my $n2 ( @names ) {
#	    if($include_metagenomes) {
		# see DataEntryUtil::getGoldCondAttr - ken
		if ( $n2 eq "date_collected" ||
		     $n2 eq "mrn" ) {
		    next;
		}
#	    }

	    if ( $n2 eq "contact_email" ||
		 $n2 eq "contact_name" ||
		 $n2 eq "project_info" ||
		 $n2 eq "sample_oid" ||
		 $n2 eq "iso_country" ) {
		next;
	    }

	    ## disable the following for the time being
	    ## because GOLD API returns null
	    if ( $n2 eq "cultured" ||
		 $n2 eq "funding_program" ||
		 $n2 eq "iso_country" ||
		 $n2 eq "sample_body_site" ||
		 $n2 eq "sample_body_subsite" ) {
		next;
	    }

	    ## disable the following; too many values
	    if ( $n2 eq "host_name" ||
		$n2 eq "latitude" ||
		$n2 eq "longitude" ) {
		next;
	    }

	    push @categoryNames, ( $n2 );
	}

        if(!$include_metagenomes) {
            splice(@categoryNames, 8, 4);  
            # remove 'ecosystem', 'ecosystem_category', 'ecosystem_type', 'ecosystem_subtype',
         } 
        
    } else {
        @categoryNames = ( "Phenotype", "Ecotype", "Disease", "Relevance" );
    }

    return (@categoryNames);
}

############################################################################
# getCategoryRow - get category row data
############################################################################
sub getCategoryRow {
	my ( $dbh, $selectionAttr ) = @_;

	my $selectionAttrLc = $selectionAttr;
	$selectionAttrLc =~ tr/A-Z/a-z/;
	my $mgr = new TermNodeMgr();
	$mgr->loadTree( $dbh, $selectionAttrLc );
	my $root = $mgr->getRoot();
	my $jsObject = $root->processJSObject($selectionAttrLc);
    my $hilitedAttr = '';
    if ( $selectionAttr eq "Ecotype" ) {
        $hilitedAttr = "<b>Habitat</b>";
    } else {
        $hilitedAttr = "<b>$selectionAttr</b>";
    }
    $jsObject =~ s/$selectionAttr/$hilitedAttr/i;

	return $jsObject;
}

############################################################################
# getCategoryRow_ImgGold - get category row data
############################################################################
sub getCategoryRow_ImgGold { 
    my ( $dbh, $selectionAttr ) = @_; 
 
    # get all options 
    my @cv_vals = (); 

    my %gold_table_h = getNewGoldTableNames();
    my %gold_field_h = getNewGoldFieldNames();

    my $table_name = "";
    my $fld_name = "";

    my $sql = DataEntryUtil::getGoldAttrCVQuery($selectionAttr);

    if ( $gold_table_h{$selectionAttr} ) {
	$table_name = $gold_table_h{$selectionAttr};
	$fld_name = $gold_field_h{$selectionAttr};
	$sql = "select distinct $fld_name from $table_name" .
	    "\@imgsg_dev where $fld_name is not null " .
	    "order by 1";
    }
    elsif ( $selectionAttr eq 'altitude' ||
	$selectionAttr eq 'biotic_rel' ||
	$selectionAttr eq 'cell_shape' ||
	$selectionAttr =~ /ecosystem/ ||
	$selectionAttr eq 'host_gender' ||
	$selectionAttr eq 'motility' ||
	$selectionAttr eq 'oxygen_req' ||
	$selectionAttr eq 'salinity' ||
	$selectionAttr eq 'sample_body_site' ||
	$selectionAttr eq 'sample_body_subsite' ||
	$selectionAttr eq 'sporulation' ||
	$selectionAttr eq 'temp_range' ||
	$selectionAttr eq 'funding_program' ) {
	$sql = "select distinct $selectionAttr from gold_sequencing_project\@imgsg_dev order by 1";
    }

    print "getCategoryRow_ImgGold \$sql: $sql<br/>\n"; 

    if ( !blankStr($sql) ) { 
	my $cur = execSql( $dbh, $sql, $verbose ); 
	my $cnt = 0; 
	for ( ; ; ) { 
	    my ($cv_val) = $cur->fetchrow(); 
	    last if !defined($cv_val); 
 
            $cv_val =~ s/\"/\\\"/gi; 
            #$cv_val =~ s/\'/\\\'/gi; 
	    push @cv_vals, ($cv_val); 
	    if ( $cnt > 10000 ) { 
		last; 
	    } 
	} 
	$cur->finish(); 
    }
 
    my $jsObject = packJSObject($selectionAttr, @cv_vals);
    return $jsObject; 
} 


sub packJSObject {
    my( $selectionAttr, @cv_vals ) = @_;
    my $disp_name = DataEntryUtil::getGoldAttrDisplayName($selectionAttr);
    $disp_name = "<b>".$disp_name."</b>";
    
    my $jsObject = "{level:0, label:'$disp_name', param:'$selectionAttr', children: [";
    my $nNodes = @cv_vals;
    my $count = 0;
    for my $cv_val (@cv_vals) {
        $jsObject .= "{";
        #$jsObject .= "term_oid:\"$cv_val\", ";
        $jsObject .= "label:\"$cv_val\"}";
        if ($count != $nNodes-1) {
            $jsObject .= ", ";
        }
        $count++;
    }
    $jsObject .= "]}";
    
    return $jsObject;
}

############################################################################
# printMetadataCategorySearchResults - 
# Print genome metadata category search results.
############################################################################
sub printMetadataCategorySearchResults {

    #### I am working here ???
    my $searchFilter = param("metadataCategorySearchFilter");
    my $searchTerm   = param("metadataCategorySearchTerm");
    #print "printMetadataCategorySearchResults() searchFilter: $searchFilter<br/>";
    #print "printMetadataCategorySearchResults() searchTerm: $searchTerm<br/>";
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    printMainForm();
    print "<h1>Genome Metadata Category Search Results</h1>\n";
    print hiddenVar( 'metadataCategorySearchTerm', $searchTerm );
    print hiddenVar( 'metadataCategorySearchFilter', $searchFilter );

    if ( ! $searchTerm || ! $searchFilter ) {
        printStatusLine( "Loaded.", 2 );
        print "<p>Please enter a search condition.</p>\n";
        print end_form();
        return;
    }

#    my ($gold_stamp_id2outColVal_href, $gold_id2outColVal_href, $submission_id2outColVal_href)
#        = GoldDataEntryUtil::getCategorySearchGoldAndSumissionIds($searchFilter, $searchTermLc);
    #print Dumper($gold_stamp_id2outColVal_href);
    #print " gold_stamp_id2outColVal_href<br/>\n";
    #print Dumper($gold_id2outColVal_href);
    #print " gold_id2outColVal_href<br/>\n";
    #print Dumper($submission_id2outColVal_href);
    #print " submission_id2outColVal_href<br/>\n";
    
#    my @gold_stamp_ids = keys %$gold_stamp_id2outColVal_href;
#    my @gold_ids = keys %$gold_id2outColVal_href;
#    my @submission_ids = keys %$submission_id2outColVal_href;

#    if ( scalar(@gold_stamp_ids) == 0 && scalar(@gold_ids) == 0 && scalar(@submission_ids) == 0 ) {
#        printStatusLine( "Loaded.", 2 );
#        print "<p>There are no genomes satisfying the condition.</p>\n";
#        print end_form();
#        return;
#    }

    my $dbh = dbLogin();

#    my $sample_gold_id_conds = GoldDataEntryUtil::getSampleGoldIdClause($dbh, @gold_ids);

#    my $gold_id_conds = GoldDataEntryUtil::getGoldIdClause($dbh, @gold_stamp_ids);
#    if ( !blankStr($sample_gold_id_conds) and !blankStr($gold_id_conds) ) {
#        $gold_id_conds = ' or ' . $gold_id_conds;
#    }
    
#    my $submission_id_conds = GoldDataEntryUtil::getSubmissionIdClause($dbh, @submission_ids);
#    if ( (!blankStr($sample_gold_id_conds) || !blankStr($gold_id_conds)) && !blankStr($submission_id_conds) ) {
#        $submission_id_conds = ' or ' . $submission_id_conds;
#    }

    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    ## build metadata search condition
    my $new_gold_conds = "";
    my $attr = $searchFilter;
    my %attr_val_h;
    if ( DataEntryUtil::isGoldSingleAttr($attr) ) {
	## single-valued
	$new_gold_conds = " tx.sequencing_gold_id in (select p.gold_id " .
	    "from gold_sequencing_project\@imgsg_dev p " .
	    "where lower($attr) like '%$searchTermLc%') ";

	my $sql2 = "select gold_id, $attr from gold_sequencing_project\@imgsg_dev " .
	    "where lower($attr) like '%$searchTermLc%' ";
	my $cur2 = execSql( $dbh, $sql2, $verbose ); 
	for (;;) {
	    my ($id2, $val2) = $cur2->fetchrow();
	    last if ! $id2;
	    $attr_val_h{$id2} = $val2;
	}
	$cur2->finish();
    }
    else {
	## set valued
	my %gold_table_h = getNewGoldTableNames();
	my %gold_field_h = getNewGoldFieldNames();
	if ( $gold_table_h{$attr} ) {
	    my $tbl_name2 = $gold_table_h{$attr};
	    my $fld_name2 = $gold_field_h{$attr};
	    $new_gold_conds = " tx.sequencing_gold_id in (select p.gold_id " .
		"from " . $tbl_name2 . "\@imgsg_dev p " .
		"where lower($fld_name2) like '%$searchTermLc%') ";

	    my $sql2 = "select gold_id, $fld_name2 from $tbl_name2" .
		"\@imgsg_dev " .
		"where lower($fld_name2) like '%$searchTermLc%' ";
	    my $cur2 = execSql( $dbh, $sql2, $verbose ); 
	    for (;;) {
		my ($id2, $val2) = $cur2->fetchrow();
		last if ! $id2;
		$attr_val_h{$id2} = $val2;
	    }
	    $cur2->finish();
	}
    }

    if ( ! $new_gold_conds ) {
        printStatusLine( "Loaded.", 2 );
        print "<p>Please enter a search condition.</p>\n";
        print end_form();
        return;
    }

#    my $sql = qq{
#        select distinct tx.taxon_oid, tx.taxon_display_name, tx.domain, tx.seq_status, 
#        tx.sequencing_gold_id, tx.analysis_project_id, tx.submission_id
#        from taxon tx
#        where 1 = 1
#        and (
#            $sample_gold_id_conds
#            $gold_id_conds
#            $submission_id_conds
#        )
#        $rclause
#        $imgClause
#        order by tx.taxon_display_name
#    };
 
   my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name, tx.domain, tx.seq_status, 
        tx.sequencing_gold_id, tx.analysis_project_id, tx.submission_id
        from taxon tx
        where $new_gold_conds
        $rclause
        $imgClause
        order by tx.taxon_display_name
    };

    #print "printMetadataCategorySearchResults() sql: $sql<br/>\n";
    #print "printMetadataCategorySearchResults() bindList: @bindList<br/>\n";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $txTableName = "GenomeImgGold";  # name of current instance of taxon table
    TaxonSearchUtil::printNotes();
    TaxonSearchUtil::printButtonFooter($txTableName);
    print "<br/>";

    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 3 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "char asc", "center", "",
             "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "",
             "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    $it->addColSpec( "GOLD Project ID", "char asc", "left" );
    $it->addColSpec( "GOLD Analysis Project ID", "char asc", "left" );
    $it->addColSpec( "Submission ID", "char asc", "left" );
    $it->addColSpec( DataEntryUtil::getGoldAttrDisplayName($searchFilter), "char asc" );

    my $count = 0;
    for ( ; ; ) {
        my ($taxon_oid, $taxon_display_name, $domain, $seq_status,
            $gold_sp_id, $gold_ap_id, $submission_id) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;

        my $row;
        $row .= $sd . "<input type='checkbox' name='taxon_filter_oid' "
            . "value='$taxon_oid' />\t";
    
        # domain and seq_status
        $row .= $domain . $sd . substr( $domain, 0, 1 ) . "\t";
        $row .= $seq_status . $sd . substr( $seq_status, 0, 1 ) . "\t";
        my $url =
            "$main_cgi?section=TaxonDetail"
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ( $gold_sp_id ) {
            my $url = HtmlUtil::getGoldUrl($gold_sp_id);
            my $goldId_url = alink( $url, $gold_sp_id );
            $row .= $gold_sp_id . $sd . $goldId_url . "\t";
        } 
        else { 
            $row .= $sd . "\t"; 
        } 

        if ( $gold_ap_id ) { 
            my $url = HtmlUtil::getGoldUrl($gold_ap_id); 
            my $goldId_url = alink( $url, $gold_ap_id ); 
            $row .= $gold_ap_id . $sd . $goldId_url . "\t"; 
        } 
        else { 
            $row .= $sd . "\t"; 
        } 

        if ( $submission_id ) {
            my $submit_base_url = $img_er_submit_url;
            $submit_base_url = $img_mer_submit_url if ( $domain eq "*Microbiome" );
            my $submission_url = alink( "$submit_base_url$submission_id", $submission_id );
            $row .= $submission_id . $sd . $submission_url . "\t";
        }
        else {
            $row .= $sd . "\t";
        }
    
        my $attrVal;
#        if ( $gold_stamp_id2outColVal_href->{$gold_id} ) {
#            $attrVal = $gold_stamp_id2outColVal_href->{$gold_id};
#        }
#        elsif ( $gold_id2outColVal_href->{$sample_gold_id} ) {
#            $attrVal = $gold_id2outColVal_href->{$sample_gold_id};            
#        }
#        elsif ( $submission_id2outColVal_href->{$submission_id} ) {
#            $attrVal = $submission_id2outColVal_href->{$submission_id};            
#        }
        
	$attrVal = $attr_val_h{$gold_sp_id};
        if ( $attrVal ne '' ) {
            my $nameMatchText = WebUtil::highlightMatchHTML2( $attrVal, $searchTerm );
            $row .= $attrVal . $sd . "$nameMatchText\t";
        }
        else {
            $row .= $sd . "\t";
        }

        $it->addRow($row);
    }

    if ( $count > 0 ) {
	$it->printOuterTable(1);
    }
    else {
        print "<p>There are no genomes satisfying the condition.</p>\n";
    }

    $cur->finish();
#    OracleUtil::truncTable($dbh, "gtt_func_id1") if ($sample_gold_id_conds =~ /gtt_func_id1/i);
#    OracleUtil::truncTable($dbh, "gtt_func_id2") if ($gold_id_conds =~ /gtt_func_id2/i);
#    OracleUtil::truncTable($dbh, "gtt_num_id3") if ($submission_id_conds =~ /gtt_num_id3/i);    
    #$dbh->disconnect();

    if ( $count > 10 ) {
        TaxonSearchUtil::printButtonFooter($txTableName);
        print "<br/>";
    }
    
    print hiddenVar( "page",    "message" );
    print hiddenVar( "message", "Genome selections saved and enabled." );

    printStatusLine( "$count genomes retrieved.", 2 );

    print end_form();
}

############################################################################
# printMetadataCategoryOperationResults - 
# Print genome metadata category operation result.
############################################################################
sub printMetadataCategoryOperationResults {
    if ($use_img_gold) {
        printOrgCategoryResults_ImgGold();
    } else {
        printOrgCategoryResults();
    }
}

############################################################################
# printOrgCategoryResults - Print genome category result search.
############################################################################
sub printOrgCategoryResults { 
 
    my $dbh = dbLogin(); 
 
    printMainForm(); 

    # rename Categories to Metadata - ken 
    print "<h1>Genome Metadata Search Results</h1>\n"; 
 
    printStatusLine( "Loading ...", 1 ); 
 
    ## Map all taxon_oid's to name.  Also, get list of all taoxn_oids. 
    my %taxonOid2Name; 
    my %uniqueTaxonOids;
    
    my ($sql, @bindList) = QueryUtil::getAllTaxonOidAndNameBindSql();
    #print "printOrgCategoryResults \$sql: $sql<br/>";
    #print "\@bindList: @bindList<br/>\n";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOid2Name{$taxon_oid}   = $taxon_display_name;
        $uniqueTaxonOids{$taxon_oid} = $taxon_oid;
    } 
    $cur->finish(); 
 
    my @phenotype_oids = processParamValue(param("phenotype_oid"));
    my @ecotype_oids   = processParamValue(param("ecotype_oid"));
    my @disease_oids   = processParamValue(param("disease_oid"));
    my @relevance_oids = processParamValue(param("relevance_oid"));
 
    my $nPhenotypes = @phenotype_oids; 
    my $nEcotypes   = @ecotype_oids;
    my $nDiseases   = @disease_oids;
    my $nRelevances = @relevance_oids;
    if ( $nPhenotypes + $nEcotypes + $nDiseases + $nRelevances == 0 ) {
        webError("Please select a category value.");
    }
    if ( $nPhenotypes + $nEcotypes + $nDiseases + $nRelevances > 1000 ) {
        webError("Too many category values selected.  Please select < 1000.");
    }
    my $phenotypeMgr = new TermNodeMgr();
    my $ecotypeMgr   = new TermNodeMgr();
    my $diseaseMgr   = new TermNodeMgr(); 
    my $relevanceMgr = new TermNodeMgr();
    if ( $nPhenotypes > 0 ) {
        my %uniqueTaxonOids2; 
        loadTermMgr( $dbh, $phenotypeMgr, "phenotype", \@phenotype_oids,
             \%uniqueTaxonOids2 ); 
        intersectHash( \%uniqueTaxonOids, \%uniqueTaxonOids2 );
    } 
    if ( $nEcotypes > 0 ) {
        my %uniqueTaxonOids2;
        loadTermMgr( $dbh, $ecotypeMgr, "ecotype", \@ecotype_oids,
             \%uniqueTaxonOids2 );
        intersectHash( \%uniqueTaxonOids, \%uniqueTaxonOids2 ); 
    } 
    if ( $nDiseases > 0 ) { 
        my %uniqueTaxonOids2; 
        loadTermMgr( $dbh, $diseaseMgr, "disease", \@disease_oids,
             \%uniqueTaxonOids2 );
        intersectHash( \%uniqueTaxonOids, \%uniqueTaxonOids2 );
    } 
    if ( $nRelevances > 0 ) { 
        my %uniqueTaxonOids2; 
        loadTermMgr( $dbh, $relevanceMgr, "relevance", \@relevance_oids, 
             \%uniqueTaxonOids2 ); 
        intersectHash( \%uniqueTaxonOids, \%uniqueTaxonOids2 ); 
    } 
    my @taxon_oids = keys(%uniqueTaxonOids); 
    my $nTaxons    = @taxon_oids; 
    if ( $nTaxons == 0 ) { 
        print "<p>\n"; 
        print "No results were found from query.\n"; 
        print "</p>\n"; 
        printStatusLine( "0 genomes found.", 2 ); 
        #$dbh->disconnect(); 
        return; 
    } 
 
    ## Sort by taxon.taxon_display_name 
    my @recs; 
    my @taxon_oids = keys(%uniqueTaxonOids);
    for my $taxon_oid (@taxon_oids) { 
        my $taxon_display_name = $taxonOid2Name{$taxon_oid};
        my $r                  = "$taxon_display_name\t"; 
        $r .= "$taxon_oid\t";
        push( @recs, $r ); 
    } 
    my @recs2 = sort(@recs); 
    my @taxon_oids_sorted; 
    for my $r (@recs2) { 
        my ( $taxon_display_name, $taxon_oid ) = split( /\t/, $r );
        push( @taxon_oids_sorted, $taxon_oid );
    } 
 
    my %phenotypeRecs; 
    if ( $nPhenotypes > 0 ) { 
        $phenotypeMgr->expandTermOids( \@phenotype_oids ); 
        $phenotypeMgr->highlightTermAttrs( $dbh, "phenotype", 
                       \@taxon_oids_sorted, \@phenotype_oids, \%phenotypeRecs ); 
    } 
    my %ecotypeRecs; 
    if ( $nEcotypes > 0 ) { 
        $ecotypeMgr->expandTermOids( \@ecotype_oids ); 
        $ecotypeMgr->highlightTermAttrs( $dbh, "ecotype", \@taxon_oids_sorted, 
                     \@ecotype_oids, \%ecotypeRecs ); 
    } 
    my %diseaseRecs; 
    if ( $nDiseases > 0 ) { 
        $diseaseMgr->expandTermOids( \@disease_oids ); 
        $diseaseMgr->highlightTermAttrs( $dbh, "disease", \@taxon_oids_sorted, 
                     \@disease_oids, \%diseaseRecs ); 
    } 
    my %relevanceRecs;
    if ( $nRelevances > 0 ) {
        $relevanceMgr->expandTermOids( \@relevance_oids );
        $relevanceMgr->highlightTermAttrs( $dbh, "relevance",
                       \@taxon_oids_sorted, \@relevance_oids, \%relevanceRecs );
    } 
 
    my $txTableName = "GenomeMetadata";  # name of current instance of taxon table
    TaxonSearchUtil::printNotes(); 
    TaxonSearchUtil::printButtonFooter($txTableName);
    print "<br/>";

#### BEGIN updated table using InnerTable +BSJ 03/19/10

    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Select" );
    $it->addColSpec( "Genome Name", "char asc" );
    $it->addColSpec( "Phenotype", "char asc" ) if $nPhenotypes > 0;

    # rename Ecotype to Habitat - ken
    $it->addColSpec( "Habitat", "char asc" )   if $nEcotypes > 0;
    $it->addColSpec( "Disease", "char asc" )   if $nDiseases > 0;
    $it->addColSpec( "Relevance", "char asc" ) if $nRelevances > 0;

    my $count = 0;
    for my $taxon_oid (@taxon_oids_sorted) {
        my $taxon_display_name = $taxonOid2Name{$taxon_oid};
	my $row;
        $count++;

	$row .= $sd . "<input type='checkbox' name='taxon_filter_oid' "
	    . "value='$taxon_oid' />\t";

        my $url =
            "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
	$row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ( $nPhenotypes > 0 ) {
            my $termRec = $phenotypeRecs{$taxon_oid};
            my ( $x1, $x2, $line ) = split( /\t/, $termRec );
	    $row .= $relevanceMgr->getTermAttrs4Taxon($dbh, "phenotype", $taxon_oid);
	    $row .= $sd . $line . "\t";
        }
        if ( $nEcotypes > 0 ) {
            my $termRec = $ecotypeRecs{$taxon_oid};
            my ( $x1, $x2, $line ) = split( /\t/, $termRec );
	    $row .= $relevanceMgr->getTermAttrs4Taxon($dbh, "ecotype", $taxon_oid);
	    $row .= $sd . $line . "\t";
        }
        if ( $nDiseases > 0 ) {
            my $termRec = $diseaseRecs{$taxon_oid};
            my ( $x1, $x2, $line ) = split( /\t/, $termRec );
	    $row .= $relevanceMgr->getTermAttrs4Taxon($dbh, "disease", $taxon_oid);
	    $row .= $sd . $line . "\t";
        }
        if ( $nRelevances > 0 ) {
            my $termRec = $relevanceRecs{$taxon_oid};
            my ( $x1, $x2, $line ) = split( /\t/, $termRec );
	    $row .= $relevanceMgr->getTermAttrs4Taxon($dbh, "relevance", $taxon_oid);
	    $row .= $sd . $line . "\t";
        }
	$it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table using InnerTable +BSJ 03/19/10

    if ( $count > 10 ) {
        TaxonSearchUtil::printButtonFooter($txTableName);
        print "<br/>";
    }
    print hiddenVar( "page",    "message" );
    print hiddenVar( "message", "Genome selections saved and enabled." );
    printStatusLine( "$count genomes retrieved.", 2 );
    #$dbh->disconnect();
    print end_form();
}

sub getNewGoldTableNames {
    my %table_h;

    $table_h{'cell_arrangement'} = 'gold_sp_cell_arrangement';
    $table_h{'disease'} = 'gold_sp_disease';
    $table_h{'diseases'} = 'gold_sp_disease';
    $table_h{'energy_source'} = 'gold_sp_energy_source';
    $table_h{'habitat'} = 'gold_sp_habitat';
    $table_h{'metabolism'} = 'gold_sp_metabolism';
    $table_h{'phenotype'} = 'gold_sp_phenotype';
    $table_h{'phenotypes'} = 'gold_sp_phenotype';
    $table_h{'relevance'} = 'gold_sp_relevance';
    $table_h{'project_relevance'} = 'gold_sp_relevance';
    $table_h{'seq_method'} = 'gold_sp_seq_method';
    $table_h{'seq_center'} = 'gold_sp_seq_center';

    return %table_h;
}

sub getNewGoldFieldNames {
    my %field_h;

    $field_h{'cell_arrangement'} = 'cell_arrangement';
    $field_h{'disease'} = 'disease';
    $field_h{'diseases'} = 'disease';
    $field_h{'energy_source'} = 'energy_source';
    $field_h{'habitat'} = 'habitat';
    $field_h{'metabolism'} = 'metabolism';
    $field_h{'phenotype'} = 'phenotype';
    $field_h{'phenotypes'} = 'phenotype';
    $field_h{'relevance'} = 'relevance';
    $field_h{'project_relevance'} = 'relevance';
    $field_h{'seq_method'} = 'seq_method';
    $field_h{'seq_center'} = 'name';

    return %field_h;
}


############################################################################
# printOrgCategoryResults_ImgGold - Print genome category result search.
############################################################################
sub printOrgCategoryResults_ImgGold {

    printMainForm();

    # rename Categories to Metadata - ken
    print "<h1>Genome Metadata Search Results</h1>\n";

    # check user input
    print "<h3>Search Condition</h3>\n";
    my $genome_type = param('genome_type');
    if ( $genome_type ) {
	if ( $genome_type eq 'isolate' ||
	     $genome_type eq 'metagenome' ) {
	    print "<h5>Genome Type: $genome_type</h5>\n";
	}
	else {
	    $genome_type = "";
	    print "<h5>Genome Type: both isolate and metagenome</h5>\n";
	}
    }
    print "<p>\n";

    my @cond_attrs = getCategoryNames();
         
    my @single_select;
    my @set_select;
    my $domain_cond = "";
    for my $attr (@cond_attrs) {
        my @vals = processParamValue(param($attr));

        if ( scalar(@vals) > 0 ) {
	    if ( scalar(@vals) > 1000 ) {
		## Add this just in case -- it shouldn't happen though
		webError("Please select no more than 1000 category values.");
		return;
	    }

            if ( DataEntryUtil::isGoldSingleAttr($attr) ) {
                push(@single_select, $attr);
            }
            else {
                # set valued
                push(@set_select, $attr);
            }
        }
    }

    my $domain_cond = "";
    if ( param('domain') ) {
        my @vals = processParamValue(param('domain'));
	$domain_cond = " tx.domain in ('" . join("','", @vals) . "')";
    }

    if ( scalar(@single_select) == 0 && scalar(@set_select) == 0 &&
	! $domain_cond ) {
        webError("Please select a category value.");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    ## Amy: Comment out the old code that use the old IMG-GOLD
    ##      We now use new GOLD tables
#    my ($gold_stamp_id2outColVals_href, $gold_id2outColVals_href, $submission_id2outColVals_href, $outputAttrs_ref)
#        = GoldDataEntryUtil::getCategoryOperationGoldAndSumissionIds(1, @cond_attrs);
#    my @gold_stamp_ids = keys %$gold_stamp_id2outColVals_href;
#    my @gold_ids = keys %$gold_id2outColVals_href;
#    my @submission_ids = keys %$submission_id2outColVals_href;

#    if ( scalar(@gold_stamp_ids) == 0 && scalar(@gold_ids) == 0 && scalar(@submission_ids) == 0 && ! $domain_cond ) {
#        printStatusLine( "Loaded.", 2 );
#        print "<p>There are no genomes satisfying the condition.</p>\n";
#        print end_form();
#        return;
#    }

    my $dbh = dbLogin();

#    my $sample_gold_id_conds = GoldDataEntryUtil::getSampleGoldIdClause($dbh, @gold_ids);

#    my $gold_id_conds = GoldDataEntryUtil::getGoldIdClause($dbh, @gold_stamp_ids);
#    if ( !blankStr($sample_gold_id_conds) and !blankStr($gold_id_conds) ) {
#        $gold_id_conds = ' or ' . $gold_id_conds;
#    }

###    my $submission_id_conds = GoldDataEntryUtil::getSubmissionIdClause($dbh, @submission_ids);
###    if ( (!blankStr($sample_gold_id_conds) || !blankStr($gold_id_conds)) && !blankStr($submission_id_conds) ) {
###        $submission_id_conds = ' or ' . $submission_id_conds;
###    }
#    my $submission_id_conds = '';

    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    ## build metadata query conditions
    my $new_gold_conds = "";
    my @outputAttrs = ();
    if ( scalar(@single_select) > 0 ) {
	for my $attr1 ( @single_select ) {
	    push @outputAttrs, ( $attr1 );
	    my @vals = processParamValue(param($attr1));
	    my $cond1 = "p.$attr1 in ('" . join("', '", @vals) . "') ";
	    if ( $attr1 eq 'type_strain' || $attr1 eq 'mrn' ||
		 $attr1 eq 'date_collected' || $attr1 eq 'geo_location' ||
		 $attr1 eq 'culture_type' || $attr1 eq 'isolation' ) {
		$cond1 = "p.$attr1 is not null ";
	    }
	    if ( $new_gold_conds ) {
		$new_gold_conds .= "and " . $cond1;
	    }
	    else {
		$new_gold_conds = " and tx.sequencing_gold_id in " .
		    "(select p.gold_id from gold_sequencing_project\@imgsg_dev p " .
		    "where $cond1 ";
	    }
	}
    }
    if ( $new_gold_conds ) {
	$new_gold_conds .= ") ";
    }

    my %gold_table_h = getNewGoldTableNames();
    my %gold_field_h = getNewGoldFieldNames();
    if ( scalar(@set_select) > 0 ) {
	for my $attr1 ( @set_select ) {
	    if ( ! $gold_table_h{$attr1} ) {
		webError ("ERROR: Cannot find $attr1");
		return;
	    }

	    push @outputAttrs, ( $attr1 );
	    my @vals = processParamValue(param($attr1));
	    $new_gold_conds .= " and tx.sequencing_gold_id in " .
		"(select gold_id from " . $gold_table_h{$attr1} .
		"\@imgsg_dev " .
		" where " . $gold_field_h{$attr1} .
		" in ('" . join("', '", @vals) . "')) ";
	}
    }

    ## single-valued fields
    my %meta1_h;
    if ( scalar(@single_select) > 0 ) {
	my $sql2 = "";
	for my $attr1 ( @single_select ) {
	    if ( $sql2 ) {
		$sql2 .= ", p." . $attr1;
	    }
	    else {
		$sql2 = "select p.gold_id, p." . $attr1;
	    }
	}

	if ( $sql2 ) {
	    $sql2 .= " from gold_sequencing_project\@imgsg_dev p " .
		"where p.gold_id in (select t.sequencing_gold_id " .
		"from taxon t where t.obsolete_flag = 'No'";
	    if ( $genome_type ) {
		$sql2 .= " and t.genome_type = '" . $genome_type . "') ";
	    }
	    else {
		$sql2 .= ") ";
	    }

	    my $cur2 = execSql( $dbh, $sql2, $verbose );
	    for ( ; ; ) {
		my ($gold_id, @rest) = $cur2->fetchrow();
		last if ! $gold_id;
		$meta1_h{$gold_id} = \@rest;
	    }
	    $cur2->finish();
	}
    }

    ## multi-valued fields
    if ( scalar(@set_select) > 0 ) {
	for my $attr1 ( @set_select ) {
	    if ( ! $gold_table_h{$attr1} ) {
		print "<p>ERROR: Cannot find $attr1\n";
		next;
	    }

	    my @vals = processParamValue(param($attr1));
	    my $sql2 = "select p.gold_id, p." .
		$gold_field_h{$attr1} . " from " .
		$gold_table_h{$attr1} . "\@imgsg_dev p " .
		"where " . $gold_field_h{$attr1} . 
		" in ('" . join("', '", @vals) . "') " .
		"order by 1, 2";
	    my $cur2 = execSql( $dbh, $sql2, $verbose );
	    my $prev_id = "";
	    for ( ; ; ) {
		my ($gold_id, $fld_val) = $cur2->fetchrow();
		last if ! $gold_id;

		if ( $gold_id eq $prev_id ) {
		    next;
		}

		my $arr_h = $meta1_h{$gold_id};
		if ( $arr_h ) {
		    push @$arr_h, ( $fld_val );
		}
		else {
		    my @new_arr = ( $fld_val );
		    $meta1_h{$gold_id} = \@new_arr;
		}

		$prev_id = $gold_id;
	    }
	    $cur2->finish();
	}
    }

    my $genome_type_cond = " 1 = 1 ";
    if ( $genome_type ) {
	$genome_type_cond = " tx.genome_type = '" . $genome_type . "'";
    }
#    my $sql = qq{
#        select distinct tx.taxon_oid, tx.taxon_display_name, tx.domain, tx.seq_status, 
#        tx.sequencing_gold_id, tx.analysis_project_id, tx.submission_id
#        from taxon tx
#        where $genome_type_cond
#        and (
#            $sample_gold_id_conds
#            $gold_id_conds
#            $submission_id_conds
#        )
#        $rclause
#        $imgClause
#        order by tx.taxon_display_name
#    };

    my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name, tx.domain, tx.seq_status, 
        tx.sequencing_gold_id, tx.analysis_project_id, tx.submission_id
        from taxon tx
        where $genome_type_cond
        $new_gold_conds
        $rclause
        $imgClause
        order by tx.taxon_display_name
    };

    if ( $domain_cond ) {
	$sql = qq{
            select distinct tx.taxon_oid, tx.taxon_display_name, 
                   tx.domain, tx.seq_status, 
                   tx.sequencing_gold_id, tx.analysis_project_id, tx.submission_id
            from taxon tx
            where $domain_cond
            $rclause
            $imgClause
            order by tx.taxon_display_name
            };
    }

##    print "<p>SQL 2: $sql\n";

    #print "printOrgCategoryResults_ImgGold() sql: $sql<br/>\n";
    #print "printOrgCategoryResults_ImgGold() bindList: @bindList<br/>\n";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $txTableName = "GenomeImgGold";  # name of current instance of taxon table
    TaxonSearchUtil::printNotes();
    TaxonSearchUtil::printButtonFooter($txTableName);
    print "<br/>";

    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 3 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    $it->addColSpec( "GOLD Project ID", "char asc", "left" );
    $it->addColSpec( "GOLD Analysis Project ID", "char asc", "left" );
    $it->addColSpec( "Submission ID", "char asc", "left" );

#    for my $outputAttr ( @$outputAttrs_ref ) {
    for my $outputAttr ( @outputAttrs ) {
        $it->addColSpec( DataEntryUtil::getGoldAttrDisplayName($outputAttr), "char asc" );
    }

    my $count = 0;
    for ( ; ; ) {
        my ($taxon_oid, $taxon_display_name, $domain, $seq_status,
            $gold_sp_id, $gold_ap_id, $submission_id) = $cur->fetchrow();
        last if !$taxon_oid;
		$count++;

		my $row;
		$row .= $sd . "<input type='checkbox' name='taxon_filter_oid' "
		    . "value='$taxon_oid' />\t";
	
		# domain and seq_status
		$row .= $domain . $sd . substr( $domain, 0, 1 ) . "\t";
		$row .= $seq_status . $sd . substr( $seq_status, 0, 1 ) . "\t";
		my $url =
		    "$main_cgi?section=TaxonDetail"
		    . "&page=taxonDetail&taxon_oid=$taxon_oid";
		$row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ( $gold_sp_id ) {
            my $url = HtmlUtil::getGoldUrl($gold_sp_id);
            my $goldId_url = alink( $url, $gold_sp_id );
            $row .= $gold_sp_id . $sd . $goldId_url . "\t";
        }
        else {
            $row .= $sd . "\t";
        }

        if ( $gold_ap_id ) {
            my $url = HtmlUtil::getGoldUrl($gold_ap_id);
            my $goldId_url = alink( $url, $gold_ap_id );
            $row .= $gold_ap_id . $sd . $goldId_url . "\t";
        }
        else {
            $row .= $sd . "\t";
        }

        if ( $submission_id ) {
            my $submit_base_url = $img_er_submit_url;
            $submit_base_url = $img_mer_submit_url if ( $domain eq "*Microbiome" );
            my $submission_url = alink( "$submit_base_url$submission_id", $submission_id );
            $row .= $submission_id . $sd . $submission_url . "\t";
        }
        else {
            $row .= $sd . "\t";
        }

	### FIXME
        my $attrVals_ref;
#        if ( $gold_stamp_id2outColVals_href->{$gold_sp_id} ) {
#            $attrVals_ref = $gold_stamp_id2outColVals_href->{$gold_sp_id};
#        }
#        elsif ( $gold_id2outColVals_href->{$gold_ap_id} ) {
#            $attrVals_ref = $gold_id2outColVals_href->{$gold_ap_id};            
#        }
#        elsif ( $submission_id2outColVals_href->{$submission_id} ) {
#            $attrVals_ref = $submission_id2outColVals_href->{$submission_id};
#        }

        if ( $meta1_h{$gold_sp_id} ) {
	    $attrVals_ref = $meta1_h{$gold_sp_id};
	}
        if ( $attrVals_ref ) {
            my @attrVals = @$attrVals_ref;
            if (scalar(@attrVals) > 0) {
                foreach my $attrVal (@attrVals) {
                    if ($attrVal ne '') {
                        $row .= $attrVal . $sd;
                        $row .= "<span style='color:green;font-weight:bold;'>";
                        $row .= escapeHTML($attrVal);
                        $row .= "</span>\t";
                    }
                    else {
                        $row .= $sd . "\t";                        
                    }
                    
                }   
            }            
        }

		$it->addRow($row);
    }

    if ( $count > 0 ) {
	$it->printOuterTable(1);
    }
    else {
        print "<p>There are no genomes satisfying the condition.</p>\n";
    }

    $cur->finish();
#    OracleUtil::truncTable($dbh, "gtt_func_id1") if ($sample_gold_id_conds =~ /gtt_func_id1/i);
#    OracleUtil::truncTable($dbh, "gtt_func_id2") if ($gold_id_conds =~ /gtt_func_id2/i);
#    OracleUtil::truncTable($dbh, "gtt_num_id3") if ($submission_id_conds =~ /gtt_num_id3/i);    
    #$dbh->disconnect();

    if ( $count > 10 ) {
        TaxonSearchUtil::printButtonFooter($txTableName);
        print "<br/>";
    }
    print hiddenVar( "page",    "message" );
    print hiddenVar( "message", "Genome selections saved and enabled." );

    printStatusLine( "$count genomes retrieved.", 2 );

    print end_form();
}

############################################################################
# loadTermMgr - Load term manager.  Convenience wrapper for reptition.
############################################################################
sub loadTermMgr {
	my ( $dbh, $mgr, $type, $termOids_ref, $uniqueTaxonOids_ref ) = @_;
	my @outRecs;
	$mgr->loadTree( $dbh, $type );
	$mgr->findTaxons( $dbh, $type, $termOids_ref, \@outRecs );
	for my $r (@outRecs) {
		my ( $taxon_oid, undef ) = split( /\t/, $r );
		$uniqueTaxonOids_ref->{$taxon_oid} = $taxon_oid;
	}
}

############################################################################
# intersectHash - Intersect values from 2nd hash to first.
#  Store results in first hash.
############################################################################
sub intersectHash {
	my ( $h1_ref, $h2_ref ) = @_;
	my %h3;
	my @keys = keys(%$h2_ref);
	for my $k (@keys) {
		my $x = $h1_ref->{$k};
		next if $x eq "";
		$h3{$k} = $k;
	}
	%$h1_ref = %h3;
}

sub printTreeViewMarkup {
    printTreeMarkup();
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/metadataTree.js'>
        </script>
        <script type="text/javascript">
            setUrl("xml.cgi?section=FindGenomesByMetadata&page=metadataForm");
        </script>
    };
}

sub printTableTop {

    my $or = hiliteWordInColor( 'or', '#cc9966' );
    my $and = hiliteWordInColor( 'and', '#cc9966' );

    print qq{
        <p>
        <span>
        Select category search values.
        </span>
        <br/>
        <input type='button' class='actionbutton' id='expand' name='expand' value='Expand All Categories'>
        <input type='button' class='actionbutton' id='collapse' name='collapse' value='Collapse All Categories'>
        <br/>
        <span>
        ($and: inter-category intersection;&nbsp;&nbsp;$or: intra-category union)
        </span>
        </p>
    };

}

sub hiliteWordInColor {
    my ( $s, $color ) = @_;
    if ( $color ne "" ) {
        $s = "<font color='$color'>".$s."</font>";
    }
    return $s;
}

sub printInterCategoryOperator {
    my $operator = hiliteWordInColor( 'and', '#cc9966' );
	print qq{
        <tr class='img'>
            <td class='img' align='center', colspan=2>$operator</td>
        </tr>
    };
}

sub printIntraCategoryOperator {
    my $operator = hiliteWordInColor( 'or', '#cc9966' );
    print "<td class='img' align='center'>$operator</td>";
}

sub printCategoryLabel {
    my ( $selectionAttr, $jsObject ) = @_;

    if (!$use_img_gold) {
	    my $hilitedAttr = '';
	    if ( $selectionAttr eq "Ecotype" ) {
	        $hilitedAttr = "<b>Habitat</b>";
	    }
	    else {
	        $hilitedAttr = "<b>$selectionAttr</b>";
	    }
	    $jsObject =~ s/$selectionAttr/$hilitedAttr/i;
    }
    return $jsObject;
}

sub setJSObjects {
    my ( $categoriesObj ) = @_;

    print qq{
        <script type="text/javascript" id="evalMe">
           setJSObjects($categoriesObj);
           treeInit();
        </script>
    };
}


############################################################################
# printCategoryOptionList - Print option list for categories.
############################################################################
sub printCategoryOptionList {

    my @categoryNames = getCategoryNames();
    for my $selectionAttr (@categoryNames) {
        my $disp_name = DataEntryUtil::getGoldAttrDisplayName($selectionAttr);
        print qq{
           <option value="$selectionAttr">$disp_name</option>
        };
    }
}

############################################################################
# printPageHint - Print this page's hint.
############################################################################
sub printPageHint {
    printWideHint(
        qq{
            All searches treat the keyword as a substring 
            (a word or part of a word).  <br />
            The search should contain some alphanumeric characters.<br/>
            Use an underscore (_) as a single-character wildcard. <br />
            Use % to match zero or more characters.  <br />
            All matches are case insensitive. <br />
        }
    );
}



############################################################################
# printMetadataCategoryChartForm - Print MetadataCategoryChartForm 
############################################################################
sub printMetadataCategoryChartForm {
    printMainForm();
    print "<h2>Metadata Category Bar Chart Display</h2>\n";

    printMetaCateFieldSelection();

    print end_form();
}

sub printMetaCateFieldSelection () {
    my $bar_select = param('bar_field');

    my %attr_h;
    $attr_h{'altitude'} = 'Altitude / Depth';
    $attr_h{'biotic_rel'} = 'Biotic Relationships';
    $attr_h{'cell_arrangement'} = 'Cell Arrangement';
    $attr_h{'cell_shape'} = 'Cell Shape';
    $attr_h{'diseases'} = 'Disease';
    $attr_h{'domain'} = 'Domain';
    $attr_h{'ecosystem'} = 'Ecosystem';
    if ( $include_metagenomes ) {
	$attr_h{'ecosystem_*metagenome'} = 'Ecosystem (metagenomes only)';
    }
    $attr_h{'ecosystem_category'} = 'Ecosystem Category';
    if ( $include_metagenomes ) {
	$attr_h{'ecosystem_category_*metagenome'} = 'Ecosystem Category (metagenomes only)';
    }
    $attr_h{'energy_source'} = 'Energy Source';
    $attr_h{'gram_stain'} = 'Gram Staining';
    $attr_h{'habitat'} = 'Habitat';
## GOLD API returns null
##    $attr_h{'iso_country'} = 'Isolation Country';
    $attr_h{'metabolism'} = 'Metabolism';
    $attr_h{'motility'} = 'Motility';
    $attr_h{'oxygen_req'} = 'Oxygen Requirement';
    $attr_h{'phenotypes'} = 'Phenotype';
    $attr_h{'temp_range'} = 'Temperature Range';
    $attr_h{'salinity'} = 'Salinity';
    $attr_h{'sporulation'} = 'Sporulation';

    print "Metadata Category: ";
    print nbsp(2);
    print "<select id='bar_field' name='bar_field'>\n";
    print "<option value=''></option>\n";
    for my $x ( sort(keys (%attr_h)) ) {
	print "<option value='$x' ";
	if ( $x eq $bar_select ) {
	    print " selected ";
	}
	print ">" . $attr_h{$x} . "</option>\n";
    }
    print "</select>\n";

    print nbsp(3);
    my $name = "_section_FindGenomes_metadataCategoryChartResults";
    print submit(
        -id    => "go",
        -name  => $name,
        -value => "Show Chart",
        -class => "smdefbutton"
    );
}


############################################################################
# printMetadataCategoryChartResults - 
# Print genome metadata category operation result.
############################################################################
sub printMetadataCategoryChartResults {
    my $bar_select = param('bar_field');

    printMainForm();

    printMetaCateFieldSelection();

    if ( ! $bar_select ) {
    	print "<h4>Please select a field for chart display.</h4>\n";
    	print end_form();
    	return;
    }

    if ( $bar_select eq 'domain' ) {
    	printDomainChartResults();
    	return;
    }
    elsif ( $bar_select =~ /ecosystem\_category/ ) {
    	printEcosystemCategoryChartResults();
    	return;
    }

    print "<h3>Metadata Category Bar Chart</h3>\n";

    my $fld_type = getMetaFieldType($bar_select);
    if ( $fld_type == 1 && $include_metagenomes ) {
    	print "<h5>The graph shows isolate genomes only.</h5>\n";
    }
    elsif ( $fld_type == 2 ) {
    	print "<h5>The graph shows metagenomes only.</h5>\n";
    }

    my $data = "";
    my $dbh = dbLogin();
    my ($sql, @bindList) = getMetadataCategoryQuery($bar_select);

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    my $cnt = 0;
    for (;;) {
    	my ($name, $val) = $cur->fetchrow();
    	last if ! $name && length($name) == 0 ;
    
    	if ( $data ) {
    	    $data .= ",";
    	}
    	else {
    	    $data = "[";
    	}
    	$data .= "{\"title\": \"" . $name . "\", \"count\": " . $val .
	         ", \"subtitle\": \"" . $name . "\", \"label\": " . $val . "}";

    	$cnt++;
    	if ( $cnt > 6000 ) {
    	    # just in case
    	    last;
    	}
    }
    $cur->finish();
    if ( $data ) {
    	$data .= "]";
    }

    if ( $data ) {
    	#print "<p>Data: $data\n";
    	my $url2 = "$main_cgi?section=FindGenomes"
    	    . "&page=metadataCategoryOperationResults&" ;
    	if ( $fld_type == 1 && $include_metagenomes ) {
    	    $url2 .= "genome_type=isolate&";
    	}
    	elsif ( $fld_type == 2 ) {
    	    $url2 .= "genome_type=metagenome&";
    	}
    	my $url_fld = $bar_select;
    	if ( $bar_select eq 'ecosystem_*metagenome' ) {
    	    $url_fld = 'ecosystem';
    	}
    	$url2 .= $url_fld . "=";
    
    	D3ChartUtil::printHBarChart($data, $url2, "");
    }

    print end_form();
}


sub printEcosystemCategoryChartResults {
    my $field_name = 'ecosystem_category';
    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    print "<h2>Metadata Category Bar Chart Display</h2>\n";

    my $bar_select = param('bar_field');
    my $genome_type = "";
    my $genome_type_cond = "";
    if ( $bar_select =~ /metagenome/ ) {
    	print "<h5>The graph shows metagenomes only.</h5>\n";
    	$genome_type_cond = " and tx.genome_type = 'metagenome' ";
    	$genome_type = 'metagenome';
    }

    my $dbh = dbLogin();
    my $sql = "select distinct ecosystem from gold_sequencing_project\@imgsg_dev where ecosystem is not null";
    my $cur = execSql( $dbh, $sql, $verbose );
    my @ecosystems = ();
    for (;;) {
    	my ($val) = $cur->fetchrow();
    	last if ! $val;
    
    	push @ecosystems, ( $val );
    }
    $cur->finish();

    for my $x ( sort @ecosystems ) {
    	$sql = qq{
           select new.name, count(distinct new.t_oid)
           from
            (select s.$field_name name, tx.taxon_oid t_oid
            from taxon tx, gold_sequencing_project\@imgsg_dev s
            where tx.sequencing_gold_id = s.gold_id
            and s.ecosystem = ?
            and s.$field_name is not null
            $genome_type_cond
            $rclause
            $imgClause) new
           group by new.name
           order by 1
        };

    	my $cur = execSql( $dbh, $sql, $verbose, $x );
    	my $data = "";
    	my $cnt = 0;
    	for (;;) {
    	    my ($name, $val) = $cur->fetchrow();
    	    last if ! $name;
    
    	    if ( $data ) {
		$data .= ",";
    	    }
    	    else {
		$data = "[";
    	    }
	    $data .= "{\"title\": \"" . $name . "\", \"count\": " . $val .
		     ", \"subtitle\": \"" . $name . "\", \"label\": " . $val . "}";
    
    	    $cnt++;
    	    if ( $cnt > 6000 ) {
		# just in case
		last;
    	    }
    	}
    	$cur->finish();
    	if ( $data ) {
    	    $data .= "]";
    	}
    
    	if ( $data ) {
    	    my $url2 = "$main_cgi?section=FindGenomes"
    		. "&page=metadataCategoryOperationResults&";
    	    if ( $genome_type ) {
        		$url2 .= "genome_type=" . $genome_type . "&";
    	    }
    	    $url2 .= "ecosystem=$x&"
    		. $field_name . "=";
    	    my $additional_text = "[\"" . $x . "\"]";
    	    D3ChartUtil::printHBarChart($data, $url2, $additional_text, $x);
    	    #D3ChartUtil::printDonutChart($data, $url2, $additional_text);
    	}
    }   # end for x
}

sub printDomainChartResults {
    my $field_name = 'domain';
    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    TaxonSearchUtil::printNotes();
    ##WebUtil::printHint("Some domains may be hidden. Please check your MyIMG preference.");
    print "<h2>Domain Pie Chart Display</h2>\n";

    my $dbh = dbLogin();
    my $sql = qq{
       select tx.domain, count(*)
       from taxon tx
       where 1 = 1
       $rclause
       $imgClause
       group by tx.domain
       order by 1
    };

    my $cnt = 0;
    my $hideViruses = getSessionParam("hideViruses"); 
    my $hidePlasmids = getSessionParam("hidePlasmids");
    my $hideGFragment = getSessionParam("hideGFragment");
    my %domain_h;
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    for (;;) {
    	my ($domain, $val) = $cur->fetchrow();
    	last if ! $domain;

    	if ( $domain eq '*Microbiome' ) {
    	    if ( ! $include_metagenomes ) {
    		next;
    	    }
    	}
    	elsif ( $domain =~ /Virus/ ) {
    	    if ( $hideViruses eq "Yes" ) {
    		next;
    	    }
    	    $domain = 'Virus';
    	}
    	elsif ( $domain =~ /Plasmid/ ) {
    	    if ( $hidePlasmids eq "Yes" ) {
    		next;
    	    }
    	    $domain = 'Plasmid';
    	}
    	elsif ( $domain =~ /GFragment/ ) {
    	    if ( $hideGFragment eq "Yes" ) {
    		next;
    	    }
    	    $domain = 'GFragment';
    	}
    
    	if ( $domain_h{$domain} ) {
    	    $domain_h{$domain} += $val;
    	}
    	else {
    	    $domain_h{$domain} = $val;
    	}
    	$cnt += $val;
    }
    $cur->finish();

    if ( ! $cnt ) {
    	## avoid devide by zero
    	$cnt = 1;
    }
    my $data = "";
    for my $key (sort (keys %domain_h)) {
    	my $val = $domain_h{$key};
    	if ( $data ) {
    	    $data .= ",";
    	}
    	else {
    	    $data = "[";
    	}
    	my $id = substr($key, 0, 1);
    	$data .= "{\"id\": \"" . $id . "\", \"count\": " . $val .
	         ", \"name\": \"" . $key . "\", \"urlfragm\": \"" . $key .
		 "\", \"percent\": " . 
		 sprintf("%.2f", ($val * 100 / $cnt)) . "}";

    	#$data .= "{\"id\": \"" . $id . "\", \"name\": \"" . $key . 
    	#    "\", \"urlid\": \"" . $key . 
    	#    "\", \"count\": " . $val . 
    	#    ", \"percent\": " . 
    	#    sprintf("%.2f", ($val * 100 / $cnt)) . "}";
    }
    if ( $data ) {
    	$data .= "]";
    }

    if ( $data ) {
    	my $url2 = "$main_cgi?section=TaxonList&page=taxonListAlpha&domain=";
    	D3ChartUtil::printPieChart($data, $url2, $url2, "");
    }
}


sub getMetadataCategoryQuery {
    my ($field_name) = @_;

    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $fld_type = getMetaFieldType($field_name);
    my $genome_type_cond = "";
    if ( $fld_type == 1 && $include_metagenomes ) {
    	$genome_type_cond = " and tx.genome_type = 'isolate' ";
    }
    elsif ( $fld_type == 2 ) {
    	$genome_type_cond = " and tx.genome_type = 'metagenome' ";
    }

    $field_name =~ s/\_\*metagenome//;

    if ( $field_name eq 'diseases' ) {
    	$field_name = 'disease';
    }
    elsif ( $field_name eq 'phenotypes' ) {
    	$field_name = 'phenotype';
    }
    elsif ( $field_name eq 'project_relevance' ) {
    	$field_name = 'relevance';
    }

    my $sql = "";

    if ( $field_name eq 'domain' ) {
        $sql = qq{
            select tx.domain, count(*)
            from taxon tx
            where tx.domain is not null
            $rclause
            $imgClause
            group by tx.domain
            order by 1
        };
    }
    elsif ( $field_name eq 'cell_arrangement' ||
	    $field_name eq 'disease' ||
	    $field_name eq 'energy_source' ||
	    $field_name eq 'habitat' ||
	    $field_name eq 'metabolism' ||
	    $field_name eq 'phenotype' ||
	    $field_name eq 'relevance' ||
	    $field_name eq 'seq_method' ) {
    	my $table_name = "gold_sp_" . $field_name . "\@imgsg_dev";
    	$sql = qq{
           select p2.$field_name, count(distinct tx.taxon_oid)
            from taxon tx, $table_name p2
            where tx.sequencing_gold_id = p2.gold_id
            and p2.$field_name is not null
            $rclause
            $imgClause
            $genome_type_cond
           group by p2.$field_name
           order by 1
        };
    }
    elsif ( $field_name eq 'diseases' ||
    	$field_name eq 'energy_source' ||
    	$field_name eq 'metabolism' ||
    	$field_name eq 'phenotypes' ) {
    	my $table_name1 = "project_info_" . $field_name . "\@imgsg_dev";
    	my $table_name2 = "env_sample_" . $field_name . "\@imgsg_dev";
    	my $field_name2 = $field_name;
    	if ( $field_name eq 'habitat' ) {
    	    $field_name2 = 'habitat_type';
    	    $table_name2 = "env_sample_habitat_type\@imgsg_dev";
    	}
    	$sql = qq{
           select new.name, count(distinct new.t_oid)
           from
           (select p2.$field_name name, tx.taxon_oid t_oid
            from taxon tx, project_info p, $table_name1 p2
            where tx.gold_id = p.gold_stamp_id
            and p.project_oid = p2.project_oid
            and p2.$field_name is not null
            and p2.$field_name not in ('None', 'Unknown')
            $rclause
            $imgClause union
            select s2.$field_name2 name, tx.taxon_oid t_oid
            from taxon tx, env_sample s, $table_name2 s2
            where tx.sample_gold_id = s.gold_id
            and s.sample_oid = s2.sample_oid
            and s2.$field_name2 is not null
            and s2.$field_name2 not in ('None', 'Unknown')
            $rclause
            $imgClause) new
           group by new.name
           order by 1
        };
    }
    else {
    	$sql = qq{
           select p.$field_name, count(distinct tx.taxon_oid)
            from taxon tx, gold_sequencing_project\@imgsg_dev p
            where tx.sequencing_gold_id = p.gold_id
            and p.$field_name is not null
            $rclause
            $imgClause
            $genome_type_cond
           group by p.$field_name
           order by 1
        };
    }

    return ($sql, @bindList);
}


sub getMetaFieldType {
    my ($fld_name) = @_;

    if ( $fld_name eq 'biotic_rel' ||
	 $fld_name eq 'cell_arrangement' ||
	 $fld_name eq 'cell_shape' ||
	 $fld_name eq 'gram_stain' || 
	 $fld_name eq 'motility' ||
	 $fld_name eq 'sporulation' ) {
	return 1;
    }
    elsif ( $fld_name =~ /metagenome/ ) {
	return 2;
    }
    else {
	return 3;
    }
}


1;

