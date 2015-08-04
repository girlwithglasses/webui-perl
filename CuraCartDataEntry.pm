############################################################################
# CuraCartDataEntry.pm - Curation Cart Data Entry
#   --imachen 03/22/2007
#
# error log in: /home/img5/www-data/logs/web22.err.log
############################################################################
package CuraCartDataEntry;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use DataEntryUtil;
use FuncUtil;
use FuncCartStor;
use CuraCartStor;
use PwNwNode;
use PwNwNodeMgr;
use ImgTermNodeMgr;
use ImgTermNode;

my $section = "CuraCartDataEntry";
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi = $env->{ inner_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };
my $img_pheno_rule = $env->{ img_pheno_rule };
my $img_pheno_rule_saved = $env->{ img_pheno_rule_saved };

my $contact_oid = getContactOid( );

# my $max_item_count = 1000;  # limit the search result
my $max_upload_line_count = 10000;
my $max_cond_count = 5;
my $max_set_cond_count = 3;


############################################################################
# dispatch - Dispatch to pages for this section.
############################################################################
sub dispatch {

    if( !$contact_oid ) {
        webError( "Please login in." );
    }

    my $page = param( "page" );

    if ( $page ne "" ) {
	# follow through
    }
    elsif( paramMatch( "index" ) ) {
	$page = "index";
    }
    elsif( paramMatch( "searchToAddForm" ) ne "" ) {
        printSearchToAddForm( 0 );
    }
    elsif( paramMatch( "listAll" ) ne "" ) {
        printSearchToAddForm( 1 );
    }
    elsif( paramMatch( "advSearch" ) ne "" ) {
        printAdvancedSearchForm( );
    }
    elsif( paramMatch( "queryResult" ) ne "" ) {
        printAdvancedResultForm( );
    }
    elsif ( paramMatch( "addToCuraCart" ) ne "" ) {
	my $class_name = param ('class_name');
	my @oids = param ('search_id' );
	addToCurationCart ($class_name, \@oids);
	$page = "index";
    }
    elsif ( paramMatch( "addFuncIdToCuraCart" ) ne "" ) {
	my @func_ids = param ('func_id');
	addFuncIdToCurationCart (\@func_ids);
	$page = "index";
    }
    elsif( paramMatch( "addForm" ) ) {
	my $class_name = param('class_name');
	if ( $class_name eq 'PHENOTYPE_RULE' ||
	     $class_name eq 'PHENOTYPE_RULE AND' ) {
	    printAddPhenotypeRuleForm( 0, 0 );
	}
	elsif ( $class_name eq 'PHENOTYPE_RULE OR' ) {
	    printAddPhenotypeRuleForm( 0, 1 );
	}
	else {
	    printAddUpdateForm( 0 );
	}
    }
    elsif ( paramMatch( "dbAddItem" ) ne "" ) {
	my $class_name = param( 'class_name' );
	my $new_oid = dbAddItem();
	if ( $new_oid > 0 ) {
	        # add new oids to curation cart
	    my @oids = ( $new_oid );
	    addToCurationCart($class_name, \@oids);
	}

	# go to the curation page
	$page = "index";
    }
    elsif( paramMatch( "updateForm" ) ) {
	my $func_id = param('func_id');
	my $class_name = FuncUtil::funcIdToClassName($func_id);

	if ( $class_name eq 'PHENOTYPE_RULE' ) {
	    printAddPhenotypeRuleForm( 1 );
	}
	else {
	    printAddUpdateForm( 1 );
	}
    }
    elsif( paramMatch( "updateNpActivityForm" ) ) {
	printUpdateNpActivityForm( );
    }
    elsif ( paramMatch( "dbUpdateItem" ) ne "" ) {
	my $class_name = param( 'class_name' );
	my $obj_oid = dbUpdateItem();
	if ( $obj_oid > 0 ) {
	        # add new oids to curation cart
	    my @oids = ( $obj_oid );
	    addToCurationCart($class_name, \@oids);

	    # update function cart for consistency
	    if ( $class_name eq 'IMG_PARTS_LIST' ) {
		my $fc = new FuncCartStor( );
		$fc->addImgPartsListBatch( \@oids );
	    }
	    elsif ( $class_name eq 'IMG_PATHWAY' ) {
		my $fc = new FuncCartStor( );
		$fc->addImgPwayBatch( \@oids );
	    }
	    elsif ( $class_name eq 'IMG_TERM' ) {
		my $fc = new FuncCartStor( );
		$fc->addImgTermBatch( \@oids );
	    }
	}

	# go to the curation page
	$page = "index";
    }
    elsif ( paramMatch( "dbUpdateNpActivity" ) ne "" ) {
	dbUpdateNpActivity();

	# go to the curation page
	$page = "index";
    }
    elsif( paramMatch( "confirmDeleteForm" ) ne "" ) {
	printConfirmDeleteForm( );
    }
    elsif( paramMatch( "dbDeleteItem" ) ne "" ) {
	my $func_id = param( 'func_id' );
	my $old_oid = dbDeleteItem();
	# delete from function cart
	if ( $old_oid > 0 ) {
	    my $fc = new FuncCartStor( ); 
	    my $recs = $fc->{ recs }; # get records 
	    my $selected = $fc->{ selected };
	    delete $recs->{ $func_id };
	    delete $selected->{ $func_id };
	    $fc->save( );
	}

	# delete from curation cart too
        if ( $old_oid > 0 ) {
            my $cc = new CuraCartStor( );
            my $recs = $cc->{ recs }; # get records
            my $selected = $cc->{ selected };
            delete $recs->{ $func_id };
            delete $selected->{ $func_id };
            $cc->save( ); 
        } 

	# go to index page
	$page = "index";
    }
    elsif( paramMatch( "mergeForm" ) ) {
        printMergeForm( );
    }
    elsif ( paramMatch( "dbMergeTerm" ) ne "" ) {
	dbMergeTerm();

	# go to index page
	# $page = "index";
    }
    elsif ( paramMatch( "updateChildTermForm" ) ne "" ) {
	printUpdChildTermForm();
    }
    elsif ( paramMatch( "dbUpdateChildTerm" ) ne "" ) {
	dbUpdateChildTerm();

	# go to index page
	$page = "index";
    }
    elsif ( paramMatch( "updateAssocForm" ) ne "" ) {
	printUpdateAssocForm( 0 );
    }
    elsif ( paramMatch( "connectAssocForm" ) ne "" ) {
	printUpdateAssocForm( 1 );
    }
    elsif ( paramMatch( "searchAssocResultForm" ) ne "" ) {
	printSearchAssocResults( );
    }
    elsif ( paramMatch( "addToAssoc" ) ne "" ) {
	printUpdateAssocForm( 2 );
    }
    elsif ( paramMatch ("confirmUpdateAssocForm" ) ne "" ) {
	printConfirmUpdateAssocForm( );
    }
    elsif ( paramMatch ("dbUpdateAssoc" ) ne "" ) {
	dbUpdateAssoc();

	# go to index page
	$page = "index";
    }
    elsif ( paramMatch( "fileUploadForm" ) ne "" ) {
	printFileUploadForm( );
    }
    elsif ( paramMatch( "validateFile" ) ne "" ) {
	printValidateFileForm( );
    }
    elsif ( paramMatch( "dbFileUpload" ) ne "" ) {
	# perform actual upload
	dbFileUpload();

	# go to index page
	$page = "index";
    }
    elsif( paramMatch( "definePhenoRule" ) ) {
	printDefinePhenoRule();
    }
    elsif ( paramMatch( "dbAddPhenoRule" ) ne "" ) {
	my $class_name = 'PHENOTYPE_RULE';
	my $new_oid = dbAddPhenoRule();
	if ( $new_oid > 0 ) {
	    # add new oids to curation cart
	    my @oids = ( $new_oid );
	    addToCurationCart($class_name, \@oids);
	}

	# go to the curation page
	$page = "index";
    }
    elsif ( paramMatch( "dbUpdatePhenoRule" ) ne "" ) {
	my $class_name = 'PHENOTYPE_RULE';
	my $r_oid = dbUpdatePhenoRule();
	if ( $r_oid > 0 ) {
	    # add new oids to curation cart
	    my @oids = ( $r_oid );
	    addToCurationCart($class_name, \@oids);
	}

	# go to the curation page
	$page = "index";
    }

    if ( $page eq "index" ) {
	printIndex( );
    }
#    elsif( $page eq "PhenotypeRuleDetail" ) {
#	printPhenotypeRuleDetail();
#    }
#    elsif ( $page eq "showPhenoTaxons" ) {
#	printShowPhenoTaxons();
#    }
#    elsif ( $page eq "findPhenoTaxons" ) {
#	printFindPhenoTaxons();
#    }

##   move to ImgNetworkBrowser.pm
#    elsif ( $page eq "pathwayNetworkDetail" ) {
#	printPathwayNetworkDetail( );
#    }
    elsif ( $page eq "" ) {
	# do nothing
    }
    else {
        printIndex( );
#	print "<h1>Incorrect Page: $page</h1>\n";
    }
}

############################################################################
# printIndex - Show index entry to this section.
############################################################################
sub printIndex {
    my $cc = new CuraCartStor( );
    $cc->printCuraCartForm( );
}


############################################################################
# printNetworkNodeHtml - print network nodes only
#                        (for pathway/parts list - network selection
#                        or network parents selection)
############################################################################
sub printNetworkNodeHtml {
    my ($root, $class_name, $id0, $en, $selected_net_ref) = @_;

    my $type = $root->{ type };
    my $oid = $root->{ oid };
    my $name = $root->{ name };
    my $enabled = $en;

    # skip pathway node
    return if $type eq "pathway";

    # skip parts list node
    return if $type eq "parts_list";

    my $a = $root->{ children };
    my $nNodes = @$a;

    my $level = $root->getLevel( );
    print "<br/>\n" if $level == 1;
    print nbsp( ( $level - 1 ) * 4 );

    if ( $type eq 'network' && $oid ) {
	print sprintf( "%02d", $level );
	print nbsp( 1 );
	print "<b>" if $level == 1;
	$oid = FuncUtil::oidPadded( 'PATHWAY_NETWORK', $oid );
	print "<input type='checkbox' name='network_oid' value='$oid' ";
	if ( $class_name eq 'PATHWAY_NETWORK' && $id0 == $oid ) {
	    $enabled = 0;
	}
	if ( WebUtil::inIntArray($oid, @$selected_net_ref) ) {
	    print "checked ";
	}
	if ( !$enabled ) {
	    print "disabled ";
	}
	print "/>\n";
	print nbsp( 1 );
	print escHtml( $name );
	print "</b>" if $level == 1;
    }

    print "<br/>\n" if $level >= 1;

    for( my $i = 0; $i < $nNodes; $i++ ) {
	my $n2 = $root->{ children }->[ $i ];
	printNetworkNodeHtml( $n2, $class_name, $id0, $enabled,
			      $selected_net_ref );
    }
}


############################################################################
# addToCurationCart - add to curation cart
############################################################################
sub addToCurationCart {
    my ( $class_name, $oid_ref ) = @_;

    my @oids = @$oid_ref;
    my $cc = new CuraCartStor( );
    if ( $class_name eq 'IMG_COMPOUND' ||
	 $class_name eq 'IMG_REACTION' ||
	 $class_name eq 'PATHWAY_NETWORK' ) {
	$cc->addItemBatch( $class_name, \@oids );
    }
    elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
	$cc->addImgPartsListBatch( \@oids );
    }
    elsif ( $class_name eq 'IMG_PATHWAY' ) {
	$cc->addImgPwayBatch( \@oids );
    }
    elsif ( $class_name eq 'IMG_TERM' ) {
	$cc->addImgTermBatch( \@oids );
    }
    elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
	$cc->addPhenoRuleBatch( \@oids );
    }

#    $cc->printCuraCartForm( );
}

############################################################################
# addFuncIdToCurationCart - add func_id to curation cart
############################################################################
sub addFuncIdToCurationCart {
    my ( $id_ref ) = @_;

    my @func_ids = @$id_ref;
    my $cc = new CuraCartStor( );

    # separate func_ids to different classes
    my @all_classes = ( 'IMG_COMPOUND', 'IMG_PATHWAY', 'IMG_REACTION', 'IMG_TERM',
			'IMG_PARTS_LIST', 'PATHWAY_NETWORK' );
    for my $class_name ( @all_classes ) {
	my $class_tag = FuncUtil::classNameToTag($class_name);

	my @oids = ();

	for my $func_id ( @func_ids ) {
	    my ($tag, $oid) = split( /:/, $func_id );
	    if ( $tag eq $class_tag ) {
		push @oids, ( $oid );
	    }
	}

	if ( scalar(@oids) == 0 ) {
	    # nothing in this class
	    next;
	}

	# add to cart
	if ( $class_name eq 'IMG_COMPOUND' ||
	     $class_name eq 'IMG_REACTION' ||
	     $class_name eq 'PATHWAY_NETWORK' ) {
	    $cc->addItemBatch( $class_name, \@oids );
	}
	elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
	    $cc->addImgPartsListBatch( \@oids );
	}
	elsif ( $class_name eq 'IMG_PATHWAY' ) {
	    $cc->addImgPwayBatch( \@oids );
	}
	elsif ( $class_name eq 'IMG_TERM' ) {
	    $cc->addImgTermBatch( \@oids );
	}
    }
}


############################################################################
# printSearchToAddForm - search to add items to curation cart
#
# search_mode: 0 (keyword search), 1 (list all)
############################################################################
sub printSearchToAddForm {
    my ( $search_mode ) = @_;

    print "<h1>Search to Add to Curation Cart</h1>\n";
    
    printMainForm( );

    # get search term
    my $class_name = param( "class_name" );
    my $searchKey = param( "searchKey" );
    my $max_item_count = param ( 'max_item_count' );
    if ( blankStr($max_item_count) ) {
	$max_item_count = 1000;
    }

    print "<p>\n";
    print "Max number of returned items: ";
    print nbsp( 3 ); 
    print "<select name='max_item_count' class='img' size='1'>\n";
    for my $cnt0 ( 20, 50, 100, 200, 500, 800, 1000, 2000, 5000, 8000, 10000 ) {
	print "    <option value='$cnt0'";
	if ( $cnt0 eq $max_item_count ) {
	    print " selected ";
	}
	print ">$cnt0</option>\n";
    }
    print "</select>\n";
    print "<p/>\n";

    print "Enter Search Keyword.  Use % for wildcard.";
#    print "</p>\n";
    print "<br/>\n";
    print "<input type='text' name='searchKey' value='$searchKey' " .
	"size='60' maxLength='255' />\n";
    print nbsp( 3 ); 
    print "In Object Class: ";
    print nbsp( 1 ); 
    print "<select name='class_name' class='img' size='3'>\n";
    my @names = ('PATHWAY_NETWORK', 'IMG_COMPOUND',
		 'IMG_PARTS_LIST', 'IMG_PATHWAY',
		 'IMG_REACTION', 'IMG_TERM' );
    if ( $img_pheno_rule ) {
	push @names, ( 'PHENOTYPE_RULE' );
    }

    for my $cname ( @names ) {
	print "    <option value='$cname'";
	if ( $cname eq $class_name ) {
	    print " selected ";
	}

	if ( $cname eq 'PATHWAY_NETWORK' ) {
	    print ">FUNCTION_NETWORK</option>\n";
	}
	else {
	    print ">$cname</option>\n";
	}
    }
    print "</select>\n";

    # add buttons
    my $name = "_section_${section}_searchToAddForm";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    my $name = "_section_${section}_listAll";
    print submit( -name => $name,
		  -value => "List All", -class => "smbutton" );
    print nbsp( 1 ); 
    my $name = "_section_${section}_advSearch";
    print submit( -name => $name,
		  -value => "Advanced Search", -class => "smbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    if ( blankStr($class_name) ) {
	print end_form();
	return;
    }

    my $sql;
    my @bindList;
    if ( $search_mode ) {
	# list all
	$sql = FuncUtil::getListAllQuery($class_name);
    }
    else {
	# search
	if ( blankStr($searchKey) ) {
	    print end_form();
	    return;
	}

	$searchKey =~ s/^\s+//;
	$searchKey =~ s/\s+$//;

	($sql, @bindList) = FuncUtil::getSearchQuery ($class_name, $searchKey);
    }

    my $display_name = FuncUtil::classNameToDisplayName($class_name);
    my $def_attr = FuncUtil::getSearchDefAttr($class_name);

    if ( blankStr($sql) ) {
	print end_form();
	return;
    }

    # database search
    my $dbh = dbLogin( );

    printStatusLine( "Loading ...", 1 );

#    print "<p>SQL: $sql<br/>\n";
#    print "bindList: @bindList<br/></p>\n";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    my $count = 0;
    for( ;; ) {
        my( $result_oid, $result_name, $result_def ) = $cur->fetchrow( );
	last if !$result_oid;

	$count++;

	if ( $count == 1 ) {
	    print "<h2>Select " . $display_name . "s</h2>\n";
	    print "<p>The following list shows all $display_name" .
		"s that have names ";
	    if ( !blankStr($def_attr) ) {
		print 'or ' . lc($def_attr) . 's ';
	    }
	    print "matching the input search keyword.<br/>\n";
	    print "Click item(s) to add to Curation Cart.</p>\n";
	    print "<p>\n";

	    # show buttons
	    my $name = "_section_${section}_addToCuraCart";
	    print submit( -name => $name,
			  -value => "Add to Curation Cart", -class => "lgdefbutton" );
	    print nbsp( 1 );
	    print "<input type='button' name='selectAll' value='Select All' " .
		"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	    print nbsp( 1 );
	    print "<input type='button' name='clearAll' value='Clear All' " . 
		"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	    print nbsp( 1 );
	    my $name = "_section_${section}_index";
	    print submit( -name => $name,
			  -value => 'Cancel', -class => 'smbutton' );

	    print "<br/>\n";
	}

	if ( $count > $max_item_count ) {
	    last;
	}

	# show this reaction
	$result_oid = FuncUtil::oidPadded($class_name, $result_oid);
	print "<input type='checkbox' name='search_id' value='$result_oid' />\n";
	my $url = FuncUtil::getUrl($main_cgi, $class_name, $result_oid);
	print nbsp( 1 ); 
	print alink( $url, $result_oid ); 
	print nbsp( 1 ); 

	# print reaction name
	if ( blankStr($searchKey) ) {
	    print escapeHTML($result_name);
	}
	else {
	    my $matchText = highlightMatchHTML2($result_name, $searchKey); 
	    print $matchText; 
	}

	# print reaction definition
	if ( !blankStr($result_def) ) {
	    print "<br/>\n";
	    if ( blankStr($searchKey) ) {
		print nbsp( 7 );
		print "($def_attr: " . escapeHTML($result_name) . ")";
	    }
	    else {
		my $matchText = highlightMatchHTML2($result_def, $searchKey); 
		print nbsp( 7 );
		print "($def_attr: $matchText)"; 
	    }
	}

	print "<br/>\n"; 
    }
    $cur->finish( );

    ###$dbh->disconnect();

    if ( $count == 0 ) {
        printStatusLine( "$count item(s) found.", 2 );
        webError( 'No ' . $display_name . 's matches the keyword.' );
        return;
    }

    print "</p>\n";
    if ( $count > $max_item_count ) {
        printStatusLine( "Too many results. Only $max_item_count items displayed.", 2 );
    }
    else {
	printStatusLine( "$count item(s) found.", 2 );
    }

    # show buttons
    print "<br/><br/>\n";

    my $name = "_section_${section}_addToCuraCart";
    print submit( -name => $name,
		  -value => "Add to Curation Cart", -class => "lgdefbutton" );
    print nbsp( 1 );
    print "<input type='button' name='selectAll' value='Select All' " .
	"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " . 
	"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################
# printAddUpdateForm - add or update
############################################################################
sub printAddUpdateForm {
    my ( $update ) = @_;   # add or update

    my $func_id = "";
    my $class_name = "";
    my $display_name = "";

    if ( $update ) {
	$func_id = param('func_id');
	$display_name = FuncUtil::funcIdToDisplayName($func_id);
	$class_name = FuncUtil::funcIdToClassName($func_id);
	print "<h1>Update $display_name Page</h1>\n";
    }
    else {
	$class_name = param('class_name');
	$display_name = FuncUtil::classNameToDisplayName($class_name);
	print "<h1>Add $display_name Page</h1>\n";
    }

    printMainForm( );

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );

    # check id
    my $obj_oid = "";
    my %db_val;
    if ( $update ) {
	if ( blankStr($func_id) ) {
	    webError ("No object is selected.");
	    return; 
	}
	print hiddenVar( "func_id", $func_id );

	my ($tag, $id2) = split (/:/, $func_id);
	$obj_oid = $id2;

	%db_val = FuncUtil::getAttrValFromDB($class_name, $obj_oid);
    }


    # add Add/Update, Reset and Cancel buttons
    print "<p>\n";
    if ( $update ) {
        my $name = "_section_${section}_dbUpdateItem";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddItem";
	print submit( -name => $name,
		      -value => 'Add', -class => 'smdefbutton' );
    }

    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    # data in a table format
    my @attrs = FuncUtil::getAttributes($class_name);

    print "<h2>$display_name Information</h2>\n";

    if ( !blankStr($obj_oid) ) {
	print "<h3>Object ID: $obj_oid</h3>\n";
    }
    
    print "<table class='img' border='1'>\n";

    for my $attr ( @attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $const)
	    = split (/\t/, $attr);

	my $attr_val = "";
	if ( $db_val{$attr_name} ) {
	    $attr_val = $db_val{$attr_name};
	}

	# print "<p>Attr $attr_name: $attr_val;</p>\n";

	print "<tr class='img' >\n";
	print "  <th class='subhead' align='right'>$disp_name</th>\n";

	if ( $data_type =~ /\|/ ) {
	    # selection
	    my @selections = split (/\|/, $data_type);
	    print "  <td class='img'   align='left'>\n";
	    print "     <select name='$attr_name' class='img' size='$size'>\n";
	    for my $tt ( @selections ) {
		print "        <option value='$tt'";
		if ( (uc $attr_val) eq (uc $tt) ) {
		    print " selected";
		}
		print ">$tt</option>\n";
	    }
	    print "     </select></td>\n";
	}
	else {
	    my $disp_size = 60;
	    if ( $size < $disp_size ) {
		$disp_size = $size;
	    }
	    print "  <td class='img'   align='left'>" .
		"<input type='text' name='$attr_name' value='" .
		escapeHTML($attr_val) . "' size='$disp_size'" .
		" maxLength='$size'/>" . "</td>\n";
	}
	print "</tr>\n";
    }

    # class-specific
    if ( $class_name eq 'IMG_COMPOUND' ) {
	# get KEGG compounds
	my $kegg_cpds = "";
	if ( $update && !blankStr($obj_oid) ) {
	    my $dbh = dbLogin();
	    my $sql = qq{
		select ickc.compound
		    from img_compound_kegg_compounds ickc
		    where ickc.compound_oid = $obj_oid
		};

	    my $cur = execSql( $dbh, $sql, $verbose );
	    for (;;) { 
		my ( $val ) = $cur->fetchrow( );
		last if !$val;
 
		if ( !blankStr($val) ) {
		    if ( blankStr($kegg_cpds) ) {
			$kegg_cpds = $val;
		    }
		    else {
			$kegg_cpds .= " $val";
		    }
		}
	    }
	    $cur->finish( );
	    ###$dbh->disconnect();
	}

	print "<tr class='img' >\n";
	print "  <th class='subhead' align='right'>KEGG Compound ID(s)<br/>(Use blank to separate multiple ID's)</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='kegg_cpds' value='" .
	escapeHTML($kegg_cpds) . "' size='60' maxLength='1000' />" . "</td>\n";
	print "</tr>\n";
    }
    elsif ( $class_name eq 'IMG_TERM' ) {
	# get enzymes
	my $enzymes = "";
	if ( $update && !blankStr($obj_oid) ) {
	    my $dbh = dbLogin();
	    my $sql = qq{
		select ite.enzymes
		    from img_term_enzymes ite
		    where ite.term_oid = $obj_oid
		};

	    my $cur = execSql( $dbh, $sql, $verbose );
	    for (;;) { 
		my ( $val ) = $cur->fetchrow( );
		last if !$val;
 
		if ( !blankStr($val) ) {
		    if ( blankStr($enzymes) ) {
			$enzymes = $val;
		    }
		    else {
			$enzymes .= " $val";
		    }
		}
	    }
	    $cur->finish( );
	    ###$dbh->disconnect();
	}

	print "<tr class='img' >\n";
	print "  <th class='subhead' align='right'>EC Number(s)<br/>";
	print "(e.g., EC:1.2.3.4  EC:1.2.-.-)<br/>\n";
	print "(Use blank to separate multiple EC's)</th>\n";
	print "  <td class='img'   align='left'>" . 
	    "<input type='text' name='enzymes' value='" .
	    escapeHTML($enzymes) . "' size='60' maxLength='1000' />" .
	    "</td>\n";
	print "</tr>\n";
    }

    print "</table>\n";

    # additional, special attributes for classes
    if ( $class_name eq 'IMG_COMPOUND' ) {
	# aliases
	printSetValuedForm( $update, $class_name, $obj_oid );

	# ext_links
	printCompoundExtLinkForm( $update, $obj_oid );
    }
    elsif ( $class_name eq 'IMG_TERM' ) {
	# enzymes
	# printECForm( $update, $class_name, $obj_oid);

	# synonyms
	printSetValuedForm( $update, $class_name, $obj_oid );
    }
    elsif ( $class_name eq 'IMG_PATHWAY' ||
	    $class_name eq 'IMG_PARTS_LIST' ) {
	my @networks = ();
	if ( $update ) {
	    my $dbh = dbLogin();
	    if ( $class_name eq 'IMG_PATHWAY' ) {
		@networks = db_findSetVal($dbh,
					  'PATHWAY_NETWORK_IMG_PATHWAYS',
					  'pathway', $obj_oid,
					  'network_oid', '');
	    }
	    elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
		@networks = db_findSetVal($dbh,
					  'PATHWAY_NETWORK_PARTS_LISTS',
					  'parts_list', $obj_oid,
					  'network_oid', '');
	    }

	    ###$dbh->disconnect();
	}

	my $mgr = new PwNwNodeMgr( );
	$mgr->loadTree( );
	my $root = $mgr->{ root };

	print "<h2>Function Network Selection</h2>\n";
	if ( $class_name eq 'IMG_PARTS_LIST' ) {
	    print "<p>Please select function network(s) for this parts list.</p>\n";
	}
	else {
	    print "<p>Please select function network(s) for this pathway.</p>\n";
	}
	print "<p>\n";
	printNetworkNodeHtml ( $root, $class_name, $obj_oid, 1, \@networks );
    }
    elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
	my @network_parents = ();
	if ( $update ) {
	    my $dbh = dbLogin();
	    @network_parents = db_findSetVal($dbh,
					     'PATHWAY_NETWORK_PARENTS',
					     'network_oid', $obj_oid,
					     'parent', '');
	    ###$dbh->disconnect();
	}

	my $mgr = new PwNwNodeMgr( );
	$mgr->loadTree( );
	my $root = $mgr->{ root };
	print "<h2>Function Network Selection</h2>\n";
	print "<p>Please select network parent(s) for this function network.</p>\n";
	print "<p>\n";
	printNetworkNodeHtml ( $root, $class_name, $obj_oid, 1,
			       \@network_parents );
    }
    elsif ( $class_name eq 'IMG_REACTION' ) {
	print "<p><font color='purple'>Equation can be automatically filled in from Reaction - Compound association.</font>\n";
	print "<p><input type='checkbox' ";
        print "name='auto_eqn' value='1' checked />Automatically fill in Equation\n"; 

	printUpdateRxnAssoc ($func_id, "ITERM");
	printUpdateRxnAssoc ($func_id, "ICMPD");

	print "<input type='button' name='selectAll' value='Select All' " .
	    "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	print "<input type='button' name='clearAll' value='Clear All' " . 
	    "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	print "<p/>\n";
    }

    # add Add/Update, Reset and Cancel buttons
    print "<p>\n";
    if ( $update ) {
        my $name = "_section_${section}_dbUpdateItem";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddItem";
	print submit( -name => $name,
		      -value => 'Add', -class => 'smdefbutton' );
    }

    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    print end_form( );
}


############################################################################
# printUpdateNpActivityForm
############################################################################
sub printUpdateNpActivityForm {
    my $func_id = param('func_id');
    if ( blankStr($func_id) ) {
	webError ("No object is selected.");
	return; 
    }

    my $class_name = FuncUtil::funcIdToClassName($func_id);

    if ( $class_name ne 'IMG_COMPOUND' ) {
	webError("Only IMG compound can have Secondary Metabolite activities. Please select a compound first.");
	return;
    }

    my $display_name = FuncUtil::funcIdToDisplayName($func_id);
    print "<h1>Update $display_name Secondary Metabolite Activity</h1>\n";

    printMainForm( );

    my ($tag, $obj_oid) = split (/:/, $func_id);
    if ( ! $obj_oid || ! isInt($obj_oid) ) {
	webError ("Incorrect IMG Compound Oid: $obj_oid.");
	return; 
    }

    my $dbh = dbLogin();
    my $sql = "select compound_name from img_compound where compound_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $obj_oid);
    my ($compound_name) = $cur->fetchrow();
    $cur->finish();

    print "<h2>IMG Compound $obj_oid: $compound_name</h2>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );
    print hiddenVar( "func_id", $func_id );

    # add Update, Reset and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbUpdateNpActivity";
    print submit( -name => $name,
		  -value => 'Update', -class => 'smdefbutton' );
    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## get existing SM activities
    my %db_act_h;
    $sql = "select compound_oid, activity from img_compound_activity\@img_ext " .
	"where compound_oid = ? and activity is not null";
    $cur = execSql( $dbh, $sql, $verbose, $obj_oid);
    for (;;) { 
	my ( $id2, $val ) = $cur->fetchrow( );
	last if ! $id2;

	$db_act_h{$val} = 1;
    }
    $cur->finish();

    ## show selection
    print "<p>Please select all Secondary Metabolite activities that apply.\n";
    print "<p>\n";

    $sql = "select cv_term, name from np_activity_cv\@img_ext order by 2, 1";
    $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
	my ( $val, $name ) = $cur->fetchrow( );
	last if ! $val;

	print "<input type='checkbox' ";
        print "name='np_act' value='" . $val . "' ";
	if ( $db_act_h{$val} ) {
	    print "checked";
	}
	print " />" . $name . " (" . $val . ")<br/>\n";
    }
    $cur->finish();

    my $name = "_section_${section}_dbUpdateNpActivity";
    print submit( -name => $name,
		  -value => 'Update', -class => 'smdefbutton' );
    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    print end_form( );
}


############################################################################
# printAddPhenotypeRuleForm - add/update phenotype rule
#
# update: = 1 if update
# r_type: = 0 for AND-rule, 1 for OR-rule
############################################################################
sub printAddPhenotypeRuleForm {
    my ( $update, $r_type ) = @_;

    my $func_id = "";
    my $class_name = "";
    my $display_name = "";
    my $rule_id = 0;
    my $rule_name = "";
    my $rule_cv_type = "";
    my $rule_cv_value = "";
    my $first_str = "";
    my $rule_type = "";

    if ( $update ) {
	$func_id = param('func_id');
	$display_name = FuncUtil::funcIdToDisplayName($func_id);
	$class_name = FuncUtil::funcIdToClassName($func_id);
	print "<h1>Update $display_name Page (ID: $func_id)</h1>\n";

	my $pref = "";
	($pref, $rule_id) = split(/\:/, $func_id);
    }
    else {
	$class_name = param('class_name');
	$display_name = FuncUtil::classNameToDisplayName($class_name);
	print "<h1>Add $display_name Page</h1>\n";
    }

    printMainForm( );

    my $dbh = dbLogin();

    if ( $update ) {
	my $sql2 = qq{
	    select name, cv_type, cv_value, rule_type
		from phenotype_rule
		where rule_id = $rule_id
	    };

	my $cur2 = execSql( $dbh, $sql2, $verbose );
	($rule_name, $rule_cv_type, $rule_cv_value, $rule_type ) =
	    $cur2->fetchrow( );
	$cur2->finish();

	if ( $rule_type =~ /OR/ ) {
	    $r_type = 1;
	}

	my $rule_disp_label = DataEntryUtil::getGoldAttrDisplayName($rule_cv_type);
	# print "<h4>Category: $rule_disp_label ($rule_cv_value)</h4>\n";
    }

#    print "<p><font color='red'><b>Under Construction ($r_type)</b></font>\n";

    my $name = "_section_${section}_definePhenoRule";
#    print submit( -name => $name,
#		  -value => 'Define Rule', -class => 'smdefbutton' );

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );
    if ( $rule_id ) {
	print hiddenVar( "func_id", $func_id );
	print hiddenVar( "rule_id", $rule_id );
    }

    my $sql = qq{
	select cv_type, cv_value
	    from img_gold_phenotype
	    order by 1, 2
	};

    my @all_category = ();
    my %cat_select;

    my $prev_type = "";
    my $str = "";

    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
	my ( $cv_type, $cv_val ) = $cur->fetchrow( );
	last if !$cv_type;

	if ( $cv_type ne $prev_type ) {
	    if ( ! blankStr($prev_type) && ! blankStr($str) ) {
		$str .= "</select>";
		$cat_select{$prev_type} = $str;
	    }

	    push @all_category, ( $cv_type );
	    $str = "<select name='cv_val' class='img' size='1' >"; 
	    $str .= "<option value=''></option>";

	    if ( $cv_type eq $rule_cv_type ) {
		$first_str = $str;
	    }

	    $prev_type = $cv_type;
	}
	else {
	}
	$str .= "<option value='$cv_val'>$cv_val</option>";

	if ( $cv_type eq $rule_cv_type ) {
	    if ( $cv_val eq $rule_cv_value ) {
		$first_str .= "<option value='$cv_val' selected >$cv_val</option>";
	    }
	    else {
		$first_str .= "<option value='$cv_val'>$cv_val</option>";
	    }
	}
    }

    if ( ! blankStr($prev_type) && ! blankStr($str) ) {
	$str .= "</select>";
	$cat_select{$prev_type} = $str;
    }
    if ( ! blankStr($first_str) ) {
	$first_str .= "</select>\n";
    }

    # javascript 
    print <<EOF;
        <script language="javascript" type="text/javascript"> 
	function showCatValues() { 
	    var fld = document.mainForm.cv_type.value; 
	    if ( fld == '' ) {
		document.getElementById('cat_value_div').innerHTML = "";
	    }
EOF

    for my $j ( @all_category ) {
	print "    else if ( fld == '$j' ) {\n";
	print "         document.getElementById('cat_value_div').innerHTML = " . $cat_select{$j} . ";\n";
	print "    }\n";
    }

	    print "}\n";
	    print "</script>\n";

    print "<p>Please enter a rule name, and then select a phenotype category and value to define rule:</p>\n";

    print "<table class='img'>\n";
    print "<tr><td class='img'>Rule Name</td>\n";
    print "<td class='img'>\n";
    print "<input type='text' name='name' value='$rule_name' size='60' maxLength='255' />\n";
    print "</td></tr>\n";
    print "<tr><td class='img'>Category</td>\n";
    print "<td class='img'>";
    print "<select name='cv_type' class='img' size='1' onChange='showCatValues()'>\n";
    for my $k ( @all_category ) {
	my $disp_label = DataEntryUtil::getGoldAttrDisplayName($k);
	print "    <option value='$k'";
	if ( $k eq $rule_cv_type ) {
	    print " selected ";
	}
	print ">" . $disp_label . "</option>\n";
    }
    print "</select></td>\n";

    print "<tr><td class='img'>Value</td>\n";
    print "<td class='img'>\n";
    print "<div id='cat_value_div'>\n";
    my $first_type = "";
    if ( $update ) {
	print $first_str;
    }
    else {
	if ( scalar(@all_category) > 0 ) {
	    $first_type = $all_category[0];
	}
	if ( $cat_select{$first_type} ) {
	    print $cat_select{$first_type};
	}
    }
    print "</div>\n";
    print "</td></table>\n";

    printRuleDescription($rule_id, $r_type);

#    $name = "_section_${section}_definePhenoRule";
#    print submit( -name => $name,
#		  -value => 'Define Rule', -class => 'smdefbutton' );

    print end_form();
}


############################################################################
# printAddPhenotypeRuleForm_old - add/update phenotype rule
############################################################################
sub printAddPhenotypeRuleForm_old {
    my ( $update ) = @_;

    my $func_id = "";
    my $class_name = "";
    my $display_name = "";
    my $rule_id = 0;
    my $rule_name = "";
    my $rule_cv_type = "";
    my $rule_cv_value = "";

    printMainForm( );

    if ( $update ) {
	$func_id = param('func_id');
	$display_name = FuncUtil::funcIdToDisplayName($func_id);
	$class_name = FuncUtil::funcIdToClassName($func_id);
	print "<h1>Update $display_name Page (ID: $func_id)</h1>\n";

	my $pref = "";
	($pref, $rule_id) = split(/\:/, $func_id);
    }
    else {
	$class_name = param('class_name');
	$display_name = FuncUtil::classNameToDisplayName($class_name);
	print "<h1>Add $display_name Page</h1>\n";
    }

    my $dbh = dbLogin();

    if ( $update ) {
	my $sql2 = qq{
	    select name, cv_type, cv_value
		from phenotype_rule
		where rule_id = $rule_id
	    };

	my $cur2 = execSql( $dbh, $sql2, $verbose );
	($rule_name, $rule_cv_type, $rule_cv_value ) = $cur2->fetchrow( );
	$cur2->finish();

	# print "<h4>Category: $rule_cv_type ($rule_cv_value)</h4>\n";
    }


    my $name = "_section_${section}_definePhenoRule";
    print submit( -name => $name,
		  -value => 'Define Rule', -class => 'smdefbutton' );

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );

    print "<p>Please enter a rule name, and then select a phenotype category and value to define rule:</p>\n";

    my $sql = qq{
	select cv_type, cv_value
	    from img_gold_phenotype
	    order by 1, 2
	};

    my $prev_type = "";

    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
	my ( $cv_type, $cv_val ) = $cur->fetchrow( );
	last if !$cv_type;

	if ( $cv_type ne $prev_type ) {
	    my $disp_label = DataEntryUtil::getGoldAttrDisplayName($cv_type);
	    print "<h4>Category: $disp_label</h4>\n";
	    $prev_type = $cv_type;
	}

	my $sel_val = $cv_type . '|' . $cv_val;
	print "<input type='radio' name='img_gold_pheno' value='$sel_val' ";
	if ( $update && $rule_cv_type eq $cv_type &&
	     $rule_cv_value eq $cv_val ) {
	    print " checked ";
	}
	print "/>";
	print escapeHTML($cv_val);
	print "\n";
	print "<br/>\n";
    }

    $name = "_section_${section}_definePhenoRule";
    print submit( -name => $name,
		  -value => 'Define Rule', -class => 'smdefbutton' );

    print end_form();
}


############################################################################
# printDefinePhenoRule
############################################################################
sub printDefinePhenoRule {
    print "<h1>Define Pathway Rule for Phenotype</h1>\n";

    printMainForm( );

    my $sel = param('img_gold_pheno');
    if ( blankStr($sel) ) {
	webError("Please select a phenotype first.");
	return;
    }
    my ( $cv_type, $cv_val ) = split(/\|/, $sel);
#    if ( blankStr($cv_type) || blankStr($cv_val) ) {
    if ( blankStr($cv_type) ) {
	webError("Please select a phenotype first.");
	return;
    }
    print hiddenVar('img_gold_pheno', $sel);

    my $disp_label = DataEntryUtil::getGoldAttrDisplayName($cv_type);
    print "<h4>Category $disp_label: " . escapeHTML($cv_val) .
	"</h4>\n";

    printRuleDescription( 0 );

    print end_form();
}

############################################################################
# printRuleDescription
############################################################################
sub printRuleDescription {
    my ($rule_id, $r_type) = @_;

    print hiddenVar('r_type', $r_type);

    my $desc = "";
    my $rule = "";
    if ( $rule_id ) {
	my $dbh2 = dbLogin();
	my $sql2 = qq{
	    select description, rule
		from phenotype_rule
		where rule_id = $rule_id
	    };

	my $cur2 = execSql( $dbh2, $sql2, $verbose );
	( $desc, $rule ) = $cur2->fetchrow( );
	$cur2->finish();
	#$dbh2->disconnect();
    }

    print "<p>\n";
    print "<b>Description:</b> ";
    print nbsp(2);
    print "<input type='text' name='descr' value='$desc' size='60' maxLength='255' />\n";

    my @rules = ();
    if ( ! blankStr($rule) ) {
	if ( $r_type ) {
	    @rules = split(/\|/, $rule);
	}
	else {
	    @rules = split(/\,/, $rule);
	}
    }

    print "<p><i>Please enter in the blanks either a pathway ID (e.g., 162) or a pathway ID preceded by '!' or 'not' (e.g., !162, not 162). The latter means that pathway is not present.</i>\n";

    for (my $i = 0; $i < 6; $i++) {
	my @components = ();
	if ( scalar(@rules) > $i ) {
	    my $r2 = $rules[$i];
	    $r2 =~ s/\(//;
	    $r2 =~ s/\)//;
	    if ( $r_type ) {
		@components = split(/\,/, $r2);
	    }
	    else {
		@components = split(/\|/, $r2);
	    }
	}

	print "<p>\n";

	if ( $i > 0 ) {
	    if ( $r_type ) {
		print nbsp(3) . "OR\n";
	    }
	    else {
		print nbsp(3) . "AND\n";
	    }
	}
	else {
	    print "<b>Pathway Rule:</b>\n";
	}

	for (my $j = 0; $j < 8; $j++) {
	    my $c2 = "";
	    if ( scalar(@components) > $j ) {
		$c2 = strTrim($components[$j]);
	    }

	    if ( $j == 0 ) {
		print " ( ";
	    }
	    else {
		if ( $r_type ) {
		    print " and ";
		}
		else {
		    print " or ";
		}
	    }

	    my $name = "rule|$i|$j";
	    print "<input type='text' name='$name' value='$c2' size='4' maxLength='8' />\n";
	}
	print " )\n";
    }

    if ( $rule_id ) {
	my $name = "_section_${section}_dbUpdatePhenoRule";
	print submit( -name => $name,
		      -value => 'Update Rule', -class => 'smdefbutton' );
    }
    else {
	my $name = "_section_${section}_dbAddPhenoRule";
	print submit( -name => $name,
		      -value => 'Add Rule', -class => 'smdefbutton' );
    }

    print "<hr>\n";

    print "<h5>All IMG Pathways:</h5>\n";

    my $dbh = dbLogin();
    my $sql = "select pathway_oid, pathway_name from img_pathway order by 2, 1";
    my $cur = execSql( $dbh, $sql, $verbose );

#    print "<select name='all_pathways' class='img' size='20'>\n";
    print "<textarea readonly='true' rows='12' cols='80'>\n";

    my $cnt = 0;
    my $text_val = "";

    for (;;) { 
	my ( $pathway_oid, $pathway_name ) = $cur->fetchrow( );
	last if !$pathway_oid;

	$cnt++;
	if ( $cnt > 2000 ) {
	    last;
	}

#	print "<option value='$pathway_oid'>" . $pathway_name .
#	    " (ID: $pathway_oid)</option>\n";

	$text_val .= $pathway_name . " (ID: $pathway_oid)\n";
    }
#    print "</select>\n";
    print "$text_val\n";
    print "</textarea>\n";
    $cur->finish();
    ###$dbh->disconnect();
}


############################################################################
# dbAddPhenoRule
############################################################################
sub dbAddPhenoRule {
    my $rule_name = param('name');
    my $cv_type = param('cv_type');
    my $cv_val = param('cv_val');
    my $r_type = param('r_type');
    my $sel = param('img_gold_pheno');
    if ( ! blankStr($sel) ) {
	( $cv_type, $cv_val ) = split(/\|/, $sel);
    }

    if ( blankStr($rule_name) ) {
	webError("Please enter a rule name.");
	return 0;
    }

#    if ( blankStr($cv_type) || blankStr($cv_val) ) {
    if ( blankStr($cv_type) ) {
	webError("Please select a category.");
	return 0;
    }

    # check all pathways
    my $rule = "";
    my $dbh = dbLogin(); 

    my $sep1 = "|";
    my $sep2 = ",";
    my $db_r_type = "IPWAY AND";

    if ( $r_type ) {
	# OR-rule
	$sep1 = ",";
	$sep2 = "|";
	$db_r_type = "IPWAY OR";
    }

    for (my $i = 0; $i < 6; $i++) {
	my $sub_rule = "";
	my $ipos = $i + 1;
	for (my $j = 0; $j < 8; $j++) {
	    my $jpos = $j + 1;
	    my $val = param("rule|$i|$j");
	    my $not_flag = 0;

	    if ( blankStr($val) ) {
		next;
	    }

	    $val = strTrim($val);
	    $val = lc($val);
	    my $pway_id = 0;
	    if ( $val =~ /\!(\s*)(\d+)/ ) {
		$pway_id = $2;
		$not_flag = 1;
	    }
	    elsif ( $val =~ /not(\s*)(\d+)/ ) {
		$pway_id = $2;
		$not_flag = 1;
	    }
	    elsif ( isInt($val) ) {
		$pway_id = $val;
	    }
	    else {
		###$dbh->disconnect();
		webError("Incorrect value '" . $val . 
			 "' at position ($ipos, $jpos)");
		return 0;
	    }

	    # check pathway oid
	    my $cnt0 = db_findCount ($dbh, 'img_pathway',
				     "pathway_oid = $pway_id");
	    if ( ! $cnt0 ) {
		###$dbh->disconnect();
		webError("Incorrect pathway ID '" . $pway_id .
			 "' at position ($ipos, $jpos)");
		return 0;
	    }

	    if ( ! blankStr($sub_rule) ) {
		$sub_rule .= $sep1;
	    }
	    if ( $not_flag ) {
		$sub_rule .= '!';
	    }
	    $sub_rule .= $pway_id;
	}  # end j

	if ( ! blankStr($sub_rule) ) {
	    if ( ! blankStr($rule) ) {
		$rule .= $sep2;
	    }
	    $rule .= '(' . $sub_rule . ')';
	}
    } # end i

    if ( blankStr($rule) ) {
	###$dbh->disconnect();
	webError ("No pathway rule has been defined.");
	return 0;
    }

    my @sqlList = ();

    # get next oid
    my $new_oid = db_findMaxID( $dbh, 'phenotype_rule', 'rule_id') + 1;
    ###$dbh->disconnect();

    # prepare insertion
    $rule_name =~ s/'/''/g;   # replace ' with ''
    $cv_type =~ s/'/''/g;   # replace ' with ''
    $cv_val =~ s/'/''/g;   # replace ' with ''
    my $descr = param('descr');
    if ( length($descr) > 255 ) {
	$descr = substr($descr, 0, 255);
    }
    $descr =~ s/'/''/g;   # replace ' with ''

    my $sql = "insert into phenotype_rule(rule_id, name, " .
	"cv_type, cv_value, description, rule, " .
	"add_date, mod_date, modified_by, rule_type) ";
    $sql .= "values ($new_oid, '$rule_name', '$cv_type', '$cv_val', " .
	"'$descr', '$rule', sysdate, sysdate, $contact_oid, '$db_r_type')";

    push @sqlList, ( $sql );

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return 0;
    }
    else {
	return $new_oid;
    }
}


############################################################################
# dbUpdatePhenoRule
############################################################################
sub dbUpdatePhenoRule {
    my $rule_id = param('rule_id');
    my $rule_name = param('name');
    my $cv_type = param('cv_type');
    my $cv_val = param('cv_val');
    my $r_type = param('r_type');
    my $sel = param('img_gold_pheno');
    if ( ! blankStr($sel) ) {
	( $cv_type, $cv_val ) = split(/\|/, $sel);
    }

    if ( ! $rule_id ) {
	webError("Please select a phenotype rule.");
	return 0;
    }
    if ( blankStr($rule_name) ) {
	webError("Please enter a rule name.");
	return 0;
    }

#    if ( blankStr($cv_type) || blankStr($cv_val) ) {
    if ( blankStr($cv_type) ) {
	webError("Please select a phenotype category.");
	return 0;
    }

    # check all pathways
    my $rule = "";
    my $dbh = dbLogin(); 

    my $sep1 = ",";
    my $sep2 = "|";

    if ( $r_type ) {
	$sep1 = "|";
	$sep2 = ",";
    }

    for (my $i = 0; $i < 6; $i++) {
	my $sub_rule = "";
	my $ipos = $i + 1;
	for (my $j = 0; $j < 8; $j++) {
	    my $jpos = $j + 1;
	    my $val = param("rule|$i|$j");
	    my $not_flag = 0;

	    if ( blankStr($val) ) {
		next;
	    }

	    $val = strTrim($val);
	    $val = lc($val);
	    my $pway_id = 0;
	    if ( $val =~ /\!(\s*)(\d+)/ ) {
		$pway_id = $2;
		$not_flag = 1;
	    }
	    elsif ( $val =~ /not(\s*)(\d+)/ ) {
		$pway_id = $2;
		$not_flag = 1;
	    }
	    elsif ( isInt($val) ) {
		$pway_id = $val;
	    }
	    else {
		###$dbh->disconnect();
		webError("Incorrect value '" . $val . 
			 "' at position ($ipos, $jpos)");
		return 0;
	    }

	    # check pathway oid
	    my $cnt0 = db_findCount ($dbh, 'img_pathway',
				     "pathway_oid = $pway_id");
	    if ( ! $cnt0 ) {
		###$dbh->disconnect();
		webError("Incorrect pathway ID '" . $pway_id .
			 "' at position ($ipos, $jpos)");
		return 0;
	    }

	    if ( ! blankStr($sub_rule) ) {
		$sub_rule .= $sep2;
	    }
	    if ( $not_flag ) {
		$sub_rule .= '!';
	    }
	    $sub_rule .= $pway_id;
	}  # end j

	if ( ! blankStr($sub_rule) ) {
	    if ( ! blankStr($rule) ) {
		$rule .= $sep1;
	    }
	    $rule .= '(' . $sub_rule . ')';
	}
    } # end i

    if ( blankStr($rule) ) {
	###$dbh->disconnect();
	webError ("No pathway rule has been defined.");
	return 0;
    }

    ###$dbh->disconnect();

    my @sqlList = ();

    # prepare update
    $rule_name =~ s/'/''/g;   # replace ' with ''
    $cv_type =~ s/'/''/g;   # replace ' with ''
    $cv_val =~ s/'/''/g;   # replace ' with ''
    my $descr = param('descr');
    if ( length($descr) > 255 ) {
	$descr = substr($descr, 0, 255);
    }
    $descr =~ s/'/''/g;   # replace ' with ''

    my $sql = qq{
	update phenotype_rule
	    set name = '$rule_name',
	    cv_type = '$cv_type',
	    cv_value = '$cv_val',
	    description = '$descr',
	    rule = '$rule',
	    mod_date = sysdate,
	    modified_by = $contact_oid
	    where rule_id = $rule_id
	};
    push @sqlList, ( $sql );

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return 0;
    }
    else {
	return $rule_id;
    }
}


############################################################################
# printECForm - for IMG_TERM.enzymes only
############################################################################
sub printECForm {
    my ( $update, $class_name, $obj_oid ) = @_;

    # check class name, just in case
    if ( $class_name ne 'IMG_TERM' ) {
	return;
    }

    my @db_ec = ();

    if ( $update && !blankStr($obj_oid) ) {
	my $dbh = dbLogin();
	my $sql = "select term_oid, enzymes from IMG_TERM_ENZYMES " .
	    "where term_oid = $obj_oid";
	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) { 
	    my ( $id2, $val ) = $cur->fetchrow( );
	    last if !$id2;
 
	    if ( !blankStr($val) ) {
		push @db_ec, ( $val );
	    }
	}
	$cur->finish();
	###$dbh->disconnect();
    }

    # add java script function 'changeEC' 
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function changeEC(x) {\n"; 
    print "   var ec = document.getElementById('ecSelect');\n";
    print "   var newec = document.getElementById('newEC');\n";

    print "   if ( x == 0 ) {\n";
    print "      ec.selectedIndex = -1;\n";
    print "      return;\n";
    print "      }\n"; 

    print "   if ( x == 1 && newec.value.length > 0 ) {\n";
    print "      var nOption = document.createElement(\"option\");\n";
    print "      nOption.value = newec.value;\n";
    print "      nOption.text = newec.value;\n";
    print "      ec.appendChild(nOption);\n";
    print "      }\n";

    print "   if ( x == 2 && ec.selectedIndex >= 0 ) {\n";
    print "      ec.remove(ec.selectedIndex);\n";
    print "      }\n"; 

    print "   if ( x == 3 && newec.value.length > 0 && ec.selectedIndex >= 0 ) {\n";
    print "      var uOption = ec.options[ec.selectedIndex];\n";
    print "      uOption.value = newec.value;\n";
    print "      uOption.text = newec.value;\n";
    print "      }\n";

    print "   var allEC = document.getElementById('allEC');\n";
    print "   allEC.value = \"\";\n";
    print "   for (var i = 0; i < ec.options.length; i++) {\n";
    print "       if ( i > 0 ) {\n";
    print "          allEC.value += \"\\n\";\n";
    print "          }\n";
    print "       allEC.value += ec.options[i].value;\n";
    print "       }\n";

    print "   }\n"; 

    print "\n</script>\n\n"; 

    my $allEC = '';
    for my $s ( @db_ec ) {
	if ( blankStr($allEC) ) {
	    $allEC = escapeHTML($s);
	}
	else {
	    $allEC .= "\n" . escapeHTML($s);
	}
    }

    print "<input type='hidden' id='allEC' name='allEC' value='$allEC'>\n"; 

    print "<h2>Enzymes of this IMG Term</h2>\n";

    # add buttons for EC
    print "<p>\n";
    print "New Enzyme: <input type='text' id='newEC' name='newEC' " .
	"size='30' maxLength='30' />";
    print nbsp( 2 );
    print "(e.g., 'EC:1.2.3.4' or 'EC:1.2.-.-')\n";
    print "</p>\n";

    print "<input type='button' name='addEC' value='Add Enzyme' " .
	"onClick='changeEC(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='deleteEC' value='Delete Enzyme' " .
	"onClick='changeEC(2)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='updateEC' value='Update Enzyme' " .
	"onClick='changeEC(3)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearSelection' value='Clear Enzyme Selection' " .
	"onClick='changeEC(0)' class='medbutton' />\n";
    print "<p>\n";

    # display list of enzymes
    print "<select id='ecSelect' name='ecSelect' class='img' size='10'";
    print " onChange='document.getElementById(\"newEC\").value=this.value' >\n";
    for my $s1 ( @db_ec ) {
	print "           <option value='$s1'>$s1</option>\n";
    }
    print "</select>\n";
}


############################################################################
# printSetValuedForm - for IMG_COMPOUND.aliases or IMG_TERM.synonyms
############################################################################
sub printSetValuedForm {
    my ( $update, $class_name, $obj_oid ) = @_;

    if ( $class_name ne 'IMG_COMPOUND' &&
	 $class_name ne 'IMG_TERM' ) {
	return;
    }

    my @db_syn = ();    # IMG_TERM.synonyms or IMG_COMPOUND.aliases

    if ( $update && !blankStr($obj_oid) ) {
	my $dbh = dbLogin();
	my $sql;
	if ( $class_name eq 'IMG_COMPOUND' ) {
	    $sql = "select compound_oid, aliases from IMG_COMPOUND_ALIASES " .
		"where compound_oid = $obj_oid";
	}
	else {
	    $sql = "select term_oid, synonyms from IMG_TERM_SYNONYMS " .
		"where term_oid = $obj_oid";
	}
	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) { 
	    my ( $id2, $val ) = $cur->fetchrow( );
	    last if !$id2;
 
	    if ( !blankStr($val) ) {
		push @db_syn, ( $val );
	    }
	}
	$cur->finish();
	###$dbh->disconnect();
    }

    # add java script function 'changeSynonym' 
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function changeSynonym(x) {\n"; 
    print "   var syn = document.getElementById('synonymSelect');\n";
    print "   var newsyn = document.getElementById('newSynonym');\n";

    print "   if ( x == 0 ) {\n";
    print "      syn.selectedIndex = -1;\n";
    print "      return;\n";
    print "      }\n"; 

    print "   if ( x == 1 && newsyn.value.length > 0 ) {\n";
    print "      var nOption = document.createElement(\"option\");\n";
    print "      nOption.value = newsyn.value;\n";
    print "      nOption.text = newsyn.value;\n";
    print "      syn.appendChild(nOption);\n";
    print "      }\n";

    print "   if ( x == 2 && syn.selectedIndex >= 0 ) {\n";
    print "      syn.remove(syn.selectedIndex);\n";
    print "      }\n"; 

    print "   if ( x == 3 && newsyn.value.length > 0 && syn.selectedIndex >= 0 ) {\n";
    print "      var uOption = syn.options[syn.selectedIndex];\n";
    print "      uOption.value = newsyn.value;\n";
    print "      uOption.text = newsyn.value;\n";
    print "      }\n";

    print "   var allSyn = document.getElementById('allSynonyms');\n";
    print "   allSyn.value = \"\";\n";
    print "   for (var i = 0; i < syn.options.length; i++) {\n";
    print "       if ( i > 0 ) {\n";
    print "          allSyn.value += \"\\n\";\n";
    print "          }\n";
    print "       allSyn.value += syn.options[i].value;\n";
    print "       }\n";

    print "   }\n"; 

    print "\n</script>\n\n"; 

    my $allSyn = '';
    for my $s ( @db_syn ) {
	if ( blankStr($allSyn) ) {
	    $allSyn = escapeHTML($s);
	}
	else {
	    $allSyn .= "\n" . escapeHTML($s);
	}
    }

    print "<input type='hidden' id='allSynonyms' name='allSynonyms' value='$allSyn'>\n"; 

    my $syn = "Synonym";
    my $syn_size = 1000;
    if ( $class_name eq 'IMG_COMPOUND' ) {
	$syn = "Alias";
	$syn_size = 255;
    }

    if ( $class_name eq 'IMG_COMPOUND' ) {
	print "<h2>Aliases of this IMG Compound</h2>\n";
    }
    else {
	print "<h2>Synonyms of this IMG Term</h2>\n";
    }

    # add buttons of synonyms
    print "<p>\n";
    print "New $syn: <input type='text' id='newSynonym' name='newSynonym' " .
	"size='60' maxLength='$syn_size' />\n";
    print "</p>\n";

    print "<input type='button' name='addSynonym' value='Add $syn' " .
	"onClick='changeSynonym(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='deleteSynonym' value='Delete $syn' " .
	"onClick='changeSynonym(2)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='updateSynonym' value='Update $syn' " .
	"onClick='changeSynonym(3)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearSelection' value='Clear Selection' " .
	"onClick='changeSynonym(0)' class='smbutton' />\n";
    print "<p>\n";

    # display list of synonyms
    print "<select id='synonymSelect' name='synonymSelect' class='img' size='10'";
    print " onChange='document.getElementById(\"newSynonym\").value=this.value' >\n";
    for my $s1 ( @db_syn ) {
	print "           <option value='$s1'>$s1</option>\n";
    }
    print "</select>\n";
}


############################################################################
# printCompoundExtLinkForm
############################################################################
sub printCompoundExtLinkForm {
    my ( $update, $obj_oid ) = @_;

    my @ext_db_names = ();
    my $dbh = dbLogin();
    my $sql = "select db_name from compound_ext_db\@img_ext order by 1";
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my ($db_name) = $cur->fetchrow();
	last if ! $db_name;
	push @ext_db_names, ( $db_name );
    }
    $cur->finish();

    my %db_val_h;
    my $val_cnt = 10;
    if ( $update && !blankStr($obj_oid) ) {
	my $sql = "select db_name, id from img_compound_ext_links " .
	    "where compound_oid = ? " .
	    "and db_name is not null and id is not null";
	my $cur = execSql( $dbh, $sql, $verbose, $obj_oid );
	for (;;) { 
	    my ( $db_name, $val ) = $cur->fetchrow( );
	    last if !$db_name;
 
	    if ( $db_val_h{$db_name} ) {
		$db_val_h{$db_name} .= "\t" . $val;
	    }
	    else {
		$db_val_h{$db_name} = $val;
	    }
	    $val_cnt++;
	}
	$cur->finish();
    }

    print hiddenVar('val_cnt', $val_cnt);

    print "<h2>External Links of this IMG Compound</h2>\n";

    print "<table class='img'>\n";
    print "<tr class='img'>\n";
    print "<th class='img'>DB Name</th>\n";
    print "<th class='img'>External ID</th>\n";
    print "</tr>\n";

    # show values in database
    my $i = 0;
    for my $key (keys %db_val_h) {
	my @arr = split(/\t/, $db_val_h{$key});
	for my $v2 ( @arr ) {
	    print "<tr class='img'><td class='img'>\n";
	    my $id = "ext_link_db_" . $i;
	    print "<select id='$id' name='$id' class='img' size='1'>\n";
	    print "  <option value=' '> </option>\n";
	    for my $name ( @ext_db_names ) {
		print "  <option value='" . $name . "'";
		if ( $name eq $key ) {
		    print " selected ";
		}
		print ">$name</option>\n";
	    }
	    print "</select></td>\n";
	    print "<td class='img'>";
	    my $id2 = "ext_link_id_" . $i;
	    print "<input type='text' id='$id2' name='$id2' ";
	    print " value='" . escapeHTML($v2) . "' size='30' maxLength='60' />\n";
	    print "</td></tr>\n";
	    $i++;
	}  # end for v2
    }  # end for key

    # external blank rows
    while ( $i < $val_cnt ) {
	print "<tr class='img'><td class='img'>\n";
	my $id = "ext_link_db_" . $i;
	print "<select id='$id' name='$id' class='img' size='1'>\n";
	print "  <option value=''></option>\n";
	for my $name ( @ext_db_names ) {
	    print "  <option value='" . $name . "'";
	    print ">$name</option>\n";
	}
	print "</select></td>\n";
	print "<td class='img'>";
	my $id2 = "ext_link_id_" . $i;
	print "<input type='text' id='$id2' name='$id2' ";
	print " value='' size='30' maxLength='60' />\n";
	print "</td></tr>\n";
	$i++;
    }

    print "</table>\n";
}


############################################################################
# dbAddItem - add new item to the databsae
############################################################################
sub dbAddItem() {
    # get class name and attribute definition
    my $class_name = param ('class_name' );
    my $oid_attr = FuncUtil::getOidAttr($class_name);
    my @attrs = FuncUtil::getAttributes($class_name);
    if ( blankStr($oid_attr) || scalar(@attrs) == 0 ) {
	return -1;
    }

    # get input parameters
    my %attr_val;
    for my $attr ( @attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $const) = split (/\t/, $attr);
	my $val = param ($attr_name);
	if ( !blankStr($val) ) {
	    $attr_val{$attr_name} = $val;
	}

	# check constraint
	if ( $const eq 'U' || $const eq 'Y' ) {
	    # not null
	    if ( !$val || blankStr($val) ) {
		webError ("Please enter a value for $disp_name.");
		return -1;
	    }

	    if ( $const eq 'U' ) {
		# check for uniqueness
		my $dbh = dbLogin(); 
		my $id2 = db_findID ($dbh, $class_name, $oid_attr,
				     $attr_name, $val, '');
		###$dbh->disconnect();
		if ( $id2 > 0 ) {
		    webError ("$disp_name already exists. ($oid_attr=$id2)");
		    return -1;
		}
	    }

	    if ( $data_type eq 'int' ) {
		# value needs to be an integer
		if ( !blankStr($val) && !isInt($val) ) {
		    webError ("$disp_name value must be an integer.");
		    return -1;
		}
	    }

	    if ( $data_type eq 'number' ) {
		# value needs to be a number
		if ( !blankStr($val) && !isNumber($val) ) {
		    webError ("$disp_name value must be a number.");
		    return -1;
		}
	    }
	}
    }  # end for $attr

    # class-specific
    if ( $class_name eq 'IMG_COMPOUND' ) {
	my $dbh = dbLogin();
	my $s = checkKeggCpds ($dbh, param('kegg_cpds'));
	if ( !blankStr($s) ) {
	    ###$dbh->disconnect();
	    webError ("Incorrect KEGG Compound ID: $s");
	    return -1;
	}
    }
    elsif ( $class_name eq 'IMG_TERM' ) {
	my $dbh = dbLogin();
	my $s = checkEnzymes ($dbh, param('enzymes'));
	if ( !blankStr($s) ) {
	    ###$dbh->disconnect();
	    webError ("Incorrect Enzyme EC Number: $s");
	    return -1;
	}
    }

    my @sqlList = ();

    # get next oid
    my $dbh = dbLogin(); 
    my $new_oid = db_findMaxID( $dbh, $class_name, $oid_attr) + 1;
    ###$dbh->disconnect();

    # prepare insertion
    my $ins = "insert into $class_name ($oid_attr";
    my $ival = " values ($new_oid";

    for my $attr ( @attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $const) = split (/\t/, $attr);
	if ( $attr_val{$attr_name} ) {
	    my $val = $attr_val{$attr_name};
	    $val = strTrim($val);
	    $val =~ s/'/''/g;   # replace ' with ''
	    $ins .= ", $attr_name";
	    if ( $data_type eq 'int' || $data_type eq 'number' ) {
		$ival .= ", $val";
	    }
	    else {
		$ival .= ", '$val'";
	    }
	}
    }

    # add_date, mod_date and modified_by
    if ( $contact_oid ) {
	$ins .= ", modified_by";
	$ival .= ", $contact_oid";
    }

    $ins .= ", add_date, mod_date) ";
    $ival .= ", sysdate, sysdate)";

    my $sql = $ins . $ival;
    push @sqlList, ( $sql );

    # IMG_COMPOUND
    if ( $class_name eq 'IMG_COMPOUND' ) {
	my @allKeggCpds = split (/ /, param('kegg_cpds'));

	for my $s ( @allKeggCpds ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_COMPOUND_KEGG_COMPOUNDS ";
		$sql .= "(compound_oid, compound, modified_by, mod_date)";
		$sql .= " values (" . $new_oid . ", '" . $s .
		    "', " . $contact_oid . ", sysdate)";

		push @sqlList, ( $sql );
	    }
	}

	# insert all aliases
	my @allSynonyms = split (/\n/, param('allSynonyms'));

	for my $s ( @allSynonyms ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_COMPOUND_ALIASES (compound_oid, aliases)";
		$sql .= " values (" . $new_oid . ", '" . $s;
		$sql .= "')";

		push @sqlList, ( $sql );
	    }
	}
    }

    # IMG_TERM
    if ( $class_name eq 'IMG_TERM' ) {
	# insert Ecs
	my @allECs = split (/ /, param('enzymes'));
	for my $s ( @allECs ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_TERM_ENZYMES ";
		$sql .= "(term_oid, enzymes)";
		$sql .= " values (" . $new_oid . ", '" . $s . "')";

		push @sqlList, ( $sql );
	    }
	}

	# insert all synonyms
	my @allSynonyms = split (/\n/, param('allSynonyms'));

	for my $s ( @allSynonyms ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, ";
		$sql .= "add_date, mod_date";
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}
		$sql .= ") values (" . $new_oid . ", '" . $s;
		$sql .= "', sysdate, sysdate";
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }

    # IMG_PATHWAY or PATHWAY_NETWORK
    if ( $class_name eq 'IMG_PATHWAY' ||
	 $class_name eq 'IMG_PARTS_LIST' ||
	 $class_name eq 'PATHWAY_NETWORK' ) {
	my @networks = param('network_oid');

	for my $s ( @networks ) {
	    if ( !blankStr($s) ) {
		if ( $class_name eq 'IMG_PATHWAY' ) {
		    $sql = "insert into PATHWAY_NETWORK_IMG_PATHWAYS ";
		    $sql .= "(network_oid, pathway, mod_date";
		}
		elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
		    $sql = "insert into PATHWAY_NETWORK_PARTS_LISTS ";
		    $sql .= "(network_oid, parts_list, mod_date";
		}
		else {
		    $sql = "insert into PATHWAY_NETWORK_PARENTS ";
		    $sql .= "(network_oid, parent, mod_date";
		}
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}

		if ( $class_name eq 'IMG_PATHWAY' ||
		     $class_name eq 'IMG_PARTS_LIST' ) {
		    $sql .= ") values ( $s, $new_oid, sysdate";
		}
		else {
		    $sql .= ") values ( $new_oid, $s, sysdate";
		}
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }

    if ( $class_name eq 'IMG_REACTION' ) {
	my @lhs = ();
	my @rhs = ();
	my $reverse = 0;
	my %stoich_h;
	my @selected = param('assoc_oid');
	my $cgi = WebUtil::getCgi();
	my @all_params = $cgi->param;
	for my $selected_id ( @selected ) {
	    my $is_catalyst = 0;
	    my ($selected_type, $selected_oid) = split(/\:/, $selected_id);
	    if ( ! isInt($selected_oid) ) {
		next;
	    }
	    my $ins = "";
	    my $val = "";
	    for my $p( @all_params ) {
		my ($p1, $p2, $p3, @rest) = split(/\:/, $p);
		if ( $p1 ne 'c_type' && $p1 ne 'stoich' &&
		     $p1 ne 'main_flag' && $p1 ne 'sub_cell_loc' ) {
		    next;
		}

		if ( $p2 eq $selected_type && $p3 eq $selected_oid ) {
		    my $s = param($p);

		    if ( $p1 eq 'stoich' ) {
			if ( ! $s ) {
			    $s = 1;
			}
			elsif ( ! isInt($s) ) {
			    $s = 1;
			}

			$stoich_h{"C" . $selected_oid} = $s;
		    }
		    elsif ( ! $s ) {
			next;
		    }
		    else {
			$s =~ s/'/''/g;    # replace ' with '', if any
			$s = "'" . $s . "'";
		    }

		    if ( $p1 eq 'c_type' ) {
			if ( $s =~ 'Catalyst' ) {
			    $is_catalyst = 1;
			}
			elsif ( $s =~ 'LHS' ) {
			    push @lhs, ( "C" . $selected_oid );
			}
			elsif ( $s =~ 'RHS' ) {
			    push @rhs, ( "C" . $selected_oid );
			}
		    }

		    if ( $ins ) {
			$ins .= ", " . $p1;
		    }
		    else {
			if ( $selected_type eq 'ITERM' ) {
			    $ins = "insert into img_reaction_t_components (rxn_oid, term, " .
				$p1;
			}
			elsif ( $selected_type eq 'ICMPD' ) {
			    $ins = "insert into img_reaction_c_components (rxn_oid, compound, " .
				$p1;
			}
		    }

		    if ( $val ) {
			$val .= ", " . $s;
		    }
		    else {
			$val = "values ($new_oid, $selected_oid, " . $s;
		    }
		}
	    }

	    if ( $is_catalyst ) {
		my $sql3 = "insert into img_reaction_catalysts (rxn_oid, catalysts) " .
		    "values ($new_oid, $selected_oid)";
		push @sqlList, ( $sql3 );
	    }
	    elsif ( $ins && $val ) {
		my $sql3 = $ins . ") " . $val . ")";
		push @sqlList, ( $sql3 );
	    }
	}  # end for my selected_id

	my $auto_eqn = param('auto_eqn');
	if ( $auto_eqn ) {
	    my $eqn = "";
	    my $direction = " <=> ";
	    if ( param('is_reversible') eq 'No' ) {
		$direction = " => ";
	    }
	    if ( scalar(@lhs) > 0 || scalar(@rhs) > 0 ) {
		my $is_first = 1;
		for my $s2 ( @lhs ) {
		    if ( $is_first ) {
			$is_first = 0;
		    }
		    else {
			$eqn .= " + ";
		    }
		    if ( $stoich_h{$s2} > 1 ) {
			$eqn .= $stoich_h{$s2} . " ";
		    }
		    $eqn .= $s2;
		}
		$eqn .= $direction;
		$is_first = 1;
		for my $s2 ( @rhs ) {
		    if ( $is_first ) {
			$is_first = 0;
		    }
		    else {
			$eqn .= " + ";
		    }
		    if ( $stoich_h{$s2} > 1 ) {
			$eqn .= $stoich_h{$s2} . " ";
		    }
		    $eqn .= $s2;
		}

		my $sql3 = "update img_reaction set rxn_equation = '" . $eqn . "' " .
		    "where rxn_oid = $new_oid";
		push @sqlList, ( $sql3 );
	    }
	}
    }

    if ( $class_name eq 'IMG_COMPOUND' ) {
	my @sqlList2 = dbUpdateCompoundExtLinks(0, $new_oid);
	if ( scalar(@sqlList2) > 0 ) {
	    push @sqlList, @sqlList2;
	}
    }

    my $debug_mode = 0;
    if ( $debug_mode ) {
	webError(join("<br/>", @sqlList));
	return -1;
    }

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $new_oid;
    }
}

############################################################################
# dbUpdateItem - update item to the databsae
############################################################################
sub dbUpdateItem() {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected for update.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and attribute definition
    my $class_name = param ('class_name' );
    my $oid_attr = FuncUtil::getOidAttr($class_name);
    my @attrs = FuncUtil::getAttributes($class_name);
    if ( blankStr($oid_attr) || scalar(@attrs) == 0 ) {
	return -1;
    }

    # get input parameters
    my %attr_val;
    for my $attr ( @attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $const) = split (/\t/, $attr);
	my $val = param ($attr_name);
	if ( !blankStr($val) ) {
	    $attr_val{$attr_name} = $val;
	}

	# check constraint
	if ( $const eq 'U' || $const eq 'Y' ) {
	    # not null
	    if ( !$val || blankStr($val) ) {
		webError ("Please enter a value for $disp_name.");
		return -1;
	    }

	    if ( $const eq 'U' ) {
		# check for uniqueness
		my $dbh = dbLogin(); 
		my $id2 = db_findID ($dbh, $class_name, $oid_attr,
				     $attr_name, $val,
				     "$oid_attr <> $obj_oid");
		###$dbh->disconnect();
		if ( $id2 > 0 ) {
		    webError ("$disp_name already exists. ($oid_attr=$id2)");
		    return -1;
		}
	    }

	    if ( $data_type eq 'int' ) {
		# value needs to be an integer
		if ( !blankStr($val) && !isInt($val) ) {
		    webError ("$disp_name value must be an integer.");
		    return -1;
		}
	    }

	    if ( $data_type eq 'number' ) {
		# value needs to be a number
		if ( !blankStr($val) && !isNumber($val) ) {
		    webError ("$disp_name value must be a number.");
		    return -1;
		}
	    }
	}
    }  # end for $attr

    # class-specific
    my $update_kegg = 0;
    my $update_ec = 0;
    my $update_syn = 0;
    my $update_pn = 0;
    my $update_rxn = 0;
    if ( $class_name eq 'IMG_COMPOUND' ) {
	my $dbh = dbLogin();
	my $s = checkKeggCpds ($dbh, param('kegg_cpds'));
	if ( !blankStr($s) ) {
	    ###$dbh->disconnect();
	    webError ("Incorrect KEGG Compound ID: $s");
	    return -1;
	}

	my @kegg_cpds = split (/ /, param('kegg_cpds'));
	$update_kegg = needUpdateSetValued ($dbh, 'IMG_COMPOUND_KEGG_COMPOUNDS',
					    'compound_oid', 'compound',
					    $obj_oid, \@kegg_cpds);

	my @aliases = split (/\n/, param('allSynonyms'));
	$update_syn = needUpdateSetValued ($dbh, 'IMG_COMPOUND_ALIASES',
					    'compound_oid', 'aliases',
					    $obj_oid, \@aliases);

	###$dbh->disconnect();
    }
    elsif ( $class_name eq 'IMG_TERM' ) {
	my $dbh = dbLogin();
	my $s = checkEnzymes ($dbh, param('enzymes'));
	if ( !blankStr($s) ) {
	    ###$dbh->disconnect();
	    webError ("Incorrect Enzyme EC Number: $s");
	    return -1;
	}

	my @ecs = split (/ /, param('enzymes'));
	$update_ec = needUpdateSetValued ($dbh, 'IMG_TERM_ENZYMES',
					    'term_oid', 'enzymes',
					    $obj_oid, \@ecs);

	my @aliases = split (/\n/, param('allSynonyms'));
	$update_syn = needUpdateSetValued ($dbh, 'IMG_TERM_SYNONYMS',
					    'term_oid', 'synonyms',
					    $obj_oid, \@aliases);
	###$dbh->disconnect();
    }
    elsif ( $class_name eq 'IMG_PATHWAY' ||
	    $class_name eq 'IMG_PARTS_LIST' ||
	    $class_name eq 'PATHWAY_NETWORK' ) {
	my @networks = param('network_oid');

	my $dbh = dbLogin();
	if ( $class_name eq 'IMG_PATHWAY' ) {
	    $update_pn = needUpdateSetValued ($dbh,
					      'PATHWAY_NETWORK_IMG_PATHWAYS',
					      'pathway', 'network_oid',
					      $obj_oid, \@networks);
	}
	elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
	    $update_pn = needUpdateSetValued ($dbh,
					      'PATHWAY_NETWORK_PARTS_LISTS',
					      'parts_list', 'network_oid',
					      $obj_oid, \@networks);
	}
	else {
	    $update_pn = needUpdateSetValued ($dbh,
					      'PATHWAY_NETWORK_PARENTS',
					      'network_oid', 'parent',
					      $obj_oid, \@networks);
	}
	###$dbh->disconnect();
    }
    elsif ( $class_name eq 'IMG_REACTION' ) {
	$update_rxn = 1;
    }

    # get attribute values from database
    my %db_val = FuncUtil::getAttrValFromDB($class_name, $obj_oid);

    # compare db_val and attr_val to see we really need to update
    my $to_update = 0;
    for my $key ( keys %db_val ) {
	if ( ! $attr_val{$key} ) {
	    $to_update = 1;
	    last;
	}

	if ( $attr_val{$key} ne $db_val{$key} ) {
	    $to_update = 1;
	    last;
	}
    }
    if ( $to_update == 0 ) {
	for my $key ( keys %attr_val ) {
	    if ( ! $db_val{$key} ) {
		$to_update = 1;
		last;
	    }

	    if ( $attr_val{$key} ne $db_val{$key} ) {
		$to_update = 1;
		last;
	    }
	}
    }

    if ( $to_update == 0 && $update_kegg == 0 && $update_syn == 0 &&
	 $update_pn == 0 && $update_ec == 0 && $update_rxn == 0 ) {
	return -1;
    }

    # prepare update
    my @sqlList = ();

    # prepare update
    my $sql;
    if ( $to_update ) {
	$sql = "update $class_name set ";
	my $is_first = 1;
	for my $attr ( @attrs ) {
	    my ($attr_name, $disp_name, $data_type, $size, $const) =
		split (/\t/, $attr);
	    my $val = '';
	    if ( $attr_val{$attr_name} ) {
		$val = $attr_val{$attr_name};
		$val = strTrim($val);
		$val =~ s/'/''/g;   # replace ' with ''
	    }

	    if ( $is_first ) {
		$is_first = 0;
	    }
	    else {
		$sql .= ", ";
	    }

	    if ( $data_type eq 'int' || $data_type eq 'number' ) {
		if ( blankStr($val) ) {
		    $sql .= "$attr_name = null";
		}
		else {
		    $sql .= "$attr_name = $val";
		}
	    }
	    else {
		$sql .= "$attr_name = '$val'";
	    }
	}

	# add_date, mod_date and modified_by
	if ( $contact_oid ) {
	    $sql .= ", modified_by = $contact_oid";
	}

	$sql .= ", mod_date = sysdate ";
	$sql .= "where $oid_attr = $obj_oid";

	push @sqlList, ( $sql );
    }

    # update all KEGG compounds?
    if ( $class_name eq 'IMG_COMPOUND' && $update_kegg == 1 ) {
	$sql = "delete from IMG_COMPOUND_KEGG_COMPOUNDS where compound_oid = $obj_oid";
	push @sqlList, ( $sql );
	my @allKeggCpds = split (/ /, param('kegg_cpds'));

	for my $s ( @allKeggCpds ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_COMPOUND_KEGG_COMPOUNDS ";
		$sql .= "(compound_oid, compound, modified_by, mod_date)";
		$sql .= " values (" . $obj_oid . ", '" . $s .
		    "', " . $contact_oid . ", sysdate)";

		push @sqlList, ( $sql );
	    }
	}
    }

    # update ECs?
    if ( $class_name eq 'IMG_TERM' && $update_ec == 1 ) {
	$sql = "delete from IMG_TERM_ENZYMES where term_oid = $obj_oid";
	push @sqlList, ( $sql );
	my @allECs = split (/ /, param('enzymes'));

	for my $s ( @allECs ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_TERM_ENZYMES ";
		$sql .= "(term_oid, enzymes)";
		$sql .= " values (" . $obj_oid . ", '" . $s . "')";

		push @sqlList, ( $sql );
	    }
	}
    }

    # update synonyms or aliases
    if ( $class_name eq 'IMG_COMPOUND' && $update_syn == 1 ) {
	$sql = "delete from IMG_COMPOUND_ALIASES where compound_oid = $obj_oid";
	push @sqlList, ( $sql );
	my @aliases = split (/\n/, param('allSynonyms'));

	for my $s ( @aliases ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_COMPOUND_ALIASES ";
		$sql .= "(compound_oid, aliases)";
		$sql .= " values (" . $obj_oid . ", '" . $s . "')";

		push @sqlList, ( $sql );
	    }
	}
    }
    elsif ( $class_name eq 'IMG_TERM' && $update_syn == 1 ) {
	$sql = "delete from IMG_TERM_SYNONYMS where term_oid = $obj_oid";
	push @sqlList, ( $sql );
	my @syns = split (/\n/, param('allSynonyms'));

	for my $s ( @syns ) {
	    if ( !blankStr($s) ) {
		$s =~ s/'/''/g;  # replace ' with ''
		$sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, ";
		$sql .= "add_date, mod_date";
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}
		$sql .= ") values (" . $obj_oid . ", '" . $s;
		$sql .= "', sysdate, sysdate";
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }
    elsif ( $class_name eq 'IMG_PATHWAY' && $update_pn == 1 ) {
	$sql = "delete from PATHWAY_NETWORK_IMG_PATHWAYS where pathway = $obj_oid";
	push @sqlList, ( $sql );
	my @networks = param('network_oid');

	for my $s ( @networks ) {
	    if ( $s ) {
		$sql = "insert into PATHWAY_NETWORK_IMG_PATHWAYS (network_oid, ";
		$sql .= "pathway, mod_date";
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}
		$sql .= ") values ($s, $obj_oid, sysdate";
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }
    elsif ( $class_name eq 'IMG_PARTS_LIST' && $update_pn == 1 ) {
	$sql = "delete from PATHWAY_NETWORK_PARTS_LISTS where parts_list = $obj_oid";
	push @sqlList, ( $sql );
	my @networks = param('network_oid');

	for my $s ( @networks ) {
	    if ( $s ) {
		$sql = "insert into PATHWAY_NETWORK_PARTS_LISTS (network_oid, ";
		$sql .= "parts_list, mod_date";
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}
		$sql .= ") values ($s, $obj_oid, sysdate";
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }
    elsif ( $class_name eq 'PATHWAY_NETWORK' && $update_pn == 1 ) {
	$sql = "delete from PATHWAY_NETWORK_PARENTS where network_oid = $obj_oid";
	push @sqlList, ( $sql );
	my @networks = param('network_oid');

	for my $s ( @networks ) {
	    if ( $s ) {
		$sql = "insert into PATHWAY_NETWORK_PARENTS (network_oid, ";
		$sql .= "parent, mod_date";
		if ( $contact_oid ) {
		    $sql .= ", modified_by";
		}
		$sql .= ") values ($obj_oid, $s, sysdate";
		if ( $contact_oid ) {
		    $sql .= ", $contact_oid )";
		}
		else {
		    $sql .= ")";
		}

		push @sqlList, ( $sql );
	    }
	}
    }
    elsif ( $class_name eq 'IMG_REACTION' && $update_rxn == 1 ) {
	$sql = "delete from img_reaction_c_components where rxn_oid = $obj_oid";
	push @sqlList, ( $sql );
	$sql = "delete from img_reaction_catalysts where rxn_oid = $obj_oid";
	push @sqlList, ( $sql );
	$sql = "delete from img_reaction_t_components where rxn_oid = $obj_oid";
	push @sqlList, ( $sql );

	my @lhs = ();
	my @rhs = ();
	my $reverse = 0;
	my %stoich_h;
	my @selected = param('assoc_oid');
	my $cgi = WebUtil::getCgi();
	my @all_params = $cgi->param;
	for my $selected_id ( @selected ) {
	    my $is_catalyst = 0;
	    my ($selected_type, $selected_oid) = split(/\:/, $selected_id);
	    if ( ! isInt($selected_oid) ) {
		next;
	    }
	    my $ins = "";
	    my $val = "";
	    for my $p( @all_params ) {
		my ($p1, $p2, $p3, @rest) = split(/\:/, $p);
		if ( $p1 ne 'c_type' && $p1 ne 'stoich' &&
		     $p1 ne 'main_flag' && $p1 ne 'sub_cell_loc' ) {
		    next;
		}

		if ( $p2 eq $selected_type && $p3 eq $selected_oid ) {
		    my $s = param($p);

		    if ( $p1 eq 'stoich' ) {
			if ( ! $s ) {
			    $s = 1;
			}
			elsif ( ! isInt($s) ) {
			    $s = 1;
			}

			$stoich_h{"C" . $selected_oid} = $s;
		    }
		    elsif ( ! $s ) {
			next;
		    }
		    else {
			$s =~ s/'/''/g;    # replace ' with '', if any
			$s = "'" . $s . "'";
		    }

		    if ( $p1 eq 'c_type' ) {
			if ( $s =~ 'Catalyst' ) {
			    $is_catalyst = 1;
			}
			elsif ( $s =~ 'LHS' ) {
			    push @lhs, ( "C" . $selected_oid );
			}
			elsif ( $s =~ 'RHS' ) {
			    push @rhs, ( "C" . $selected_oid );
			}
		    }

		    if ( $ins ) {
			$ins .= ", " . $p1;
		    }
		    else {
			if ( $selected_type eq 'ITERM' ) {
			    $ins = "insert into img_reaction_t_components (rxn_oid, term, " .
				$p1;
			}
			elsif ( $selected_type eq 'ICMPD' ) {
			    $ins = "insert into img_reaction_c_components (rxn_oid, compound, " .
				$p1;
			}
		    }

		    if ( $val ) {
			$val .= ", " . $s;
		    }
		    else {
			$val = "values ($obj_oid, $selected_oid, " . $s;
		    }
		}
	    }

	    if ( $is_catalyst ) {
		my $sql3 = "insert into img_reaction_catalysts (rxn_oid, catalysts) " .
		    "values ($obj_oid, $selected_oid)";
		push @sqlList, ( $sql3 );
	    }
	    elsif ( $ins && $val ) {
		my $sql3 = $ins . ") " . $val . ")";
		push @sqlList, ( $sql3 );
	    }
	}  # end for my selected_id

	my $auto_eqn = param('auto_eqn');
	if ( $auto_eqn ) {
	    my $eqn = "";
	    my $direction = " <=> ";
	    if ( param('is_reversible') eq 'No' ) {
		$direction = " => ";
	    }
	    if ( scalar(@lhs) > 0 || scalar(@rhs) > 0 ) {
		my $is_first = 1;
		for my $s2 ( @lhs ) {
		    if ( $is_first ) {
			$is_first = 0;
		    }
		    else {
			$eqn .= " + ";
		    }
		    if ( $stoich_h{$s2} > 1 ) {
			$eqn .= $stoich_h{$s2} . " ";
		    }
		    $eqn .= $s2;
		}
		$eqn .= $direction;
		$is_first = 1;
		for my $s2 ( @rhs ) {
		    if ( $is_first ) {
			$is_first = 0;
		    }
		    else {
			$eqn .= " + ";
		    }
		    if ( $stoich_h{$s2} > 1 ) {
			$eqn .= $stoich_h{$s2} . " ";
		    }
		    $eqn .= $s2;
		}

		my $sql3 = "update img_reaction set rxn_equation = '" . $eqn . "' " .
		    "where rxn_oid = $obj_oid";
		push @sqlList, ( $sql3 );
	    }
	}
    }

    if ( $class_name eq 'IMG_COMPOUND' ) {
	my @sqlList2 = dbUpdateCompoundExtLinks(1, $obj_oid);
	if ( scalar(@sqlList2) > 0 ) {
	    push @sqlList, @sqlList2;
	}
    }

    # perform database update
    my $debug_mode = 0;
    if ( $debug_mode ) {
	webError(join("<br/>", @sqlList));
	return 0;
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $obj_oid;
    }
}


####################################################################
# dbUpdateCompoundExtLinks
####################################################################
sub dbUpdateCompoundExtLinks {
    my ($update, $obj_oid) = @_;

    my @sqlList = ();
    if ( ! $obj_oid ) {
	return @sqlList;
    }

    if ( $update ) {
	my $sql = "delete from img_compound_ext_links where compound_oid = " .
	    $obj_oid;
	push @sqlList, ( $sql );
    }

    my $val_cnt = param('val_cnt');
    my $i = 0;
    while ( $i < $val_cnt ) {
	my $id = "ext_link_db_" . $i;
	my $ext_db = param($id);
	my $id2 = "ext_link_id_" . $i;
	my $ext_id = param($id2);
	if ( $ext_db && $ext_id ) {
	    $ext_db =~ s/'/''/g;
	    $ext_id =~ s/'/''/g;
	    my $sql = "insert into img_compound_ext_links " .
		"(compound_oid, db_name, id) values ($obj_oid, '" .
		$ext_db . "', '" . $ext_id . "')";
	    push @sqlList, ( $sql );
	}
	$i++;
    }

    return @sqlList;
}


####################################################################
# dbUpdateNpActivity
####################################################################
sub dbUpdateNpActivity {
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected for update.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);
    if ( ! $obj_oid ) {
	webError ("No compound is selected for update.");
	return -1;
    }

    my @sqlList = ();
    my $sql = "delete from img_compound_activity where compound_oid = " .
	$obj_oid;
    push @sqlList, ( $sql );

    my @activities = param('np_act');
    for my $a2 ( @activities ) {
	my $sql = "insert into img_compound_activity " .
	    "(compound_oid, activity) values ($obj_oid, '" .
		$a2 . "')";
	push @sqlList, ( $sql );
    }

    # perform database update
    my $debug_mode = 0;
    if ( $debug_mode ) {
	webError(join("<br/>", @sqlList));
	return 0;
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $obj_oid;
    }
}


############################################################################
# checkKeggCpds - check whether inputs are all KEGG compounds
############################################################################
sub checkKeggCpds {
    my ($dbh, $input_s) = @_;

    my $res = "";
    if ( blankStr($input_s) ) {
	return $res;
    }

    my @keys = split (/ /, $input_s);

    for my $k ( @keys ) {
	# skip blanks
	if ( blankStr($k) ) {
	    next;
	}

	#exec SQL
	my $sql = qq{
	        select c.ext_accession
		    from compound c
		    where c.ext_accession = ? 
		};

	my $cur = execSql( $dbh, $sql, $verbose, $k );

	my $c_id = "";

	for( ;; ) {
	    my( $val ) = $cur->fetchrow( );
	    last if !$val;

	    $c_id = $val;
	}
	$cur->finish();

	if ( blankStr($c_id) ) {
	    $res .= " " . $k;
	}
    }

    return $res;
}

############################################################################
# checkEnzymes - check enzyme EC number(s)
############################################################################
sub checkEnzymes {
    my ($dbh, $input_s) = @_;

    my $res = "";
    if ( blankStr($input_s) ) {
	return $res;
    }

    my @keys = split (/ /, $input_s);

    for my $k ( @keys ) {
	# skip blanks
	if ( blankStr($k) ) {
	    next;
	}

	# check EC number (e.g., EC:1.2.3.4 or EC:1.2.-.-)
	my ($k1, $k2) = split(/\:/, $k);
	if ( $k1 ne 'EC' ) {
	    $res = "($k does not start with 'EC:')";
	    return $res;
	}

	my @ecs = split(/\./, $k2);
	if ( scalar(@ecs) != 4 ) {
	    $res = "($k does not contain 4 numbers or '-')";
	    return $res;
	}

	for my $j (@ecs) {
	    if ( $j eq '-' ) {
		next;
	    }
	    elsif ( isInt($j) ) {
		if ( $j <= 0 ) {
		    $res = "($k contains incorrect component '$j')";
		    return $res;
		}
	    }
	    else {
		$res = "($k contains incorrect component '$j')";
		return $res;
	    }
	}
    }

    return $res;
}


############################################################################
# needUpdateSetValued - check whether we need to update set-valued attr
#
# 0: no
# 1: yes
############################################################################
sub needUpdateSetValued {
    my ($dbh, $tbl, $oid_attr, $set_attr, $oid, $new_ref) = @_;

    my @old_vals;
    my $sql = "select $oid_attr, $set_attr from $tbl " .
	"where $oid_attr = $oid";
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $id, $val ) = $cur->fetchrow( );
	last if !$id;

	if ( !blankStr($val) ) {
	    push @old_vals, ( $val );
	}
    }
    $cur->finish();

    for my $k ( @old_vals ) {
	# skip blanks
	if ( blankStr($k) ) {
	    next;
	}

	if ( !WebUtil::inArray($k, @$new_ref) ) {
	    return 1;
	}
    }

    for my $k ( @$new_ref ) {
	# skip blanks
	if ( blankStr($k) ) {
	    next;
	}

	if ( !WebUtil::inArray($k, @old_vals) ) {
	    return 1;
	}
    }

    return 0;
}


############################################################################
# printUpdChildTermForm - update child terms for an IMG term
############################################################################
sub printUpdChildTermForm {
    print "<h1>Update Child Terms Page</h1>\n";

    my $func_id = param('func_id');
    if ( blankStr($func_id) ) {
	webError (" No IMG Term has been selected.");
	return;
    }
		  
    my $display_name = FuncUtil::funcIdToDisplayName($func_id);
    my $class_name = FuncUtil::funcIdToClassName($func_id);

    if ( $class_name ne 'IMG_TERM' ) {
	webError ("No IMG Term has been selected. The current selection is an object of $display_name.");
	return;
    }

    printMainForm( );

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );
    print hiddenVar( "func_id", $func_id);

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    my ($tag, $term_oid) = split (/\:/, $func_id);

    my $dbh = dbLogin();
    my $term = db_findVal($dbh, 'IMG_TERM', 'term_oid', $term_oid, 'term', '');

    print "<h2>IMG Term: ($term_oid) $term</h2>\n";
    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbUpdateChildTerm";
    print submit( -name => $name,
		  -value => 'Update', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    # list all existing child terms
    print "<h3>Child Nodes of the IMG Term</h3>\n";

    my %childTerms;
    %childTerms = getChildTerms( $dbh, $term_oid );
    #$dbh->disconnect();

    my $allTermStr = '';

    print "<select id='childTerms' name='childTerms' class='img' size='6' >\n";

    for my $k ( keys %childTerms ) { 
	print "           <option value='$k'>" . $childTerms{ $k } . "</option>\n";
	$allTermStr .= $k . ' ';
    }
    print "</select>\n";

    print "<input type='hidden' id='allCTerms' name='allCTerms' value='$allTermStr'>\n"; 

    print "<p>\n";
    print "<input type='button' name='deleteChildTerm' value='Delete Child Term'" .
        "onClick='deleteSelectedChildTerms()' class='medbutton' />\n";
    print "</p>\n";

    # add java script function 'deleteSelectedChildTerms' 
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";

    print "function deleteSelectedChildTerms( ) {\n"; 
    print "   var f = document.mainForm;\n";
    print "   var allTerms = document.getElementById('allCTerms');\n";
    print "   var cTerms = document.getElementById( 'childTerms' );\n";
    print "   cTerms.remove(cTerms.selectedIndex);\n";
    print "   allTerms.value = \"\";\n";
    print "   for (var i = 0; i < cTerms.options.length; i++) {\n";
    print "       allTerms.value += cTerms.options[i].value + ' ';\n";
    print "       }\n";
    print "   }\n";

    print "\n</script>\n\n"; 

    # filter
    print "<p>\n";
    print "<h3>Search IMG Terms</h3>\n";
    my $filterVal = param ('childTermFilter');
    print "Please enter a search term.<br/>\n";
    print "Filter: <input type='text' id='childTermFilter' name='childTermFilter' ";
    print " value='" . escapeHTML($filterVal) . "' size='50' maxLength='1000' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_updateChildTermForm";
    print submit( -name => $name,
		  -value => 'Filter', -class => 'smbutton' );
    print "</p>\n";

    if ( ! blankStr( $filterVal ) ) {
	printImgTermTree( $filterVal, 'c' );
    }
    else {
	print "<p><font color='red'>Please enter a term in the Filter!</font></p>\n";
    }

    print end_form( );
}


############################################################################ 
# getChildTerms - get child terms of an IMG term
############################################################################ 
sub getChildTerms {
    my ($dbh, $term_oid) = @_; 
 
    my %h; 
 
    if ( ! $term_oid ) {
	return %h;
    }

    my $count = 0; 
 
    #exec SQL 
    my $sql = qq{ 
	select it.term_oid, it.term, itc.c_order
	        from img_term_children itc, img_term it
		    where itc.term_oid = $term_oid 
		        and itc.child = it.term_oid
			    order by itc.c_order
			}; 
 
    my $cur = execSql( $dbh, $sql, $verbose ); 
 
    for( ;; ) {
	my( $t_oid, $t_name, $t_order ) = $cur->fetchrow( ); 
	last if !$t_oid; 
 
	$h{ $t_oid } = $t_name;
    }  # end for loop 
  
    return %h; 
} 

    
############################################################################
# printImgTermTree - Print term tree for img_term_iex search.
#
# (This subroutine was copied from FindFunctions, and then customized
#  to suit the Child Term search.)
#
# type: c - child term; m - merge term
############################################################################
sub printImgTermTree {
    my ( $searchTerm, $type ) = @_;

    if( blankStr( $searchTerm ) ) {
	webError( "Please enter a search term." );
    }

    # show search results
    print "<h4>Term Search Results</h4>\n";

    print "<p>Some term selections are blocked to prevent loops in the IMG term hierarchy.</p>\n";

    if ( $type eq 'c' ) {
	print "<input type='button' name='addSelect' " .
	    "value='Add Selected Terms' " .
	    "onClick='addSelectedChildTerms()' class='meddefbutton' />\n";
    }
    elsif ( $type eq 'm' ) {
	print "<p>Please select IMG terms to be merged. Note that synonyms and enzymes of terms will be merged, but other links will not be preserved.</p>\n";

	my $name = "_section_${section}_dbMergeTerm";
	print submit( -name => $name,
		      -value => 'Merge', -class => 'smdefbutton' );
    }
    print nbsp( 1 ); 
    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 ); 
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 

    # add java script function 'addSelectedChildTerms' 
    if ( $type eq 'c' ) {
	print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
	print "function addSelectedChildTerms( ) {\n"; 
	print "   var f = document.mainForm;\n";
	print "   var cTerms = document.getElementById( 'childTerms' );\n";
	print "   for ( var i = 0; i < f.length; i++ ) {\n";
	print "       var e = f.elements[i];\n";
	print "       if ( e.type == 'checkbox' && e.checked == true ) {\n";
	print "          var found = 0;\n";
	print "          for ( var j = 0; j < cTerms.options.length && found == 0; j++ ) {\n";
	print "              if ( cTerms.options[j].value == e.id ) {\n";
	print "                 found = 1;\n";
	print "                 }\n";
	print "              }\n";
	print "          if ( found == 0 ) {\n";
	print "             var nOption = document.createElement(\"option\");\n";
	print "             nOption.value = e.id;\n";
	print "             nOption.text = e.value;\n";
	print "             cTerms.appendChild(nOption);\n";
	print "             }\n";
	print "          }\n";
	print "      }\n";
	print "   saveSelectedChildTerms();\n";
	print "   }\n"; 

	print "function saveSelectedChildTerms( ) {\n"; 
	print "   var allTerms = document.getElementById('allCTerms');\n";
	print "   var cTerms = document.getElementById( 'childTerms' );\n";
	print "   allTerms.value = \"\";\n";
	print "   for (var i = 0; i < cTerms.options.length; i++) {\n";
	print "       allTerms.value += cTerms.options[i].value + ' ';\n";
	print "       }\n";
	print "   }\n";

	print "\n</script>\n\n"; 
    }

    printStatusLine( "Loading ...", 1 );

    if( $searchTerm !~ /[a-zA-Z0-9]+/ ) {
	webError( "Search term should have some alphanumeric characters." );
    }
    $searchTerm =~ s/\r//g;
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my( $term, @junk ) = split( /\n/, $searchTerm );
    $searchTerm = $term;
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;

    # get the term oid
    my $func_id = param ('func_id');
    my ($tag, $t_oid) = split (/\:/, $func_id);

    my %ancestorNodes = getAllAncestorNodes ( $t_oid );

    my $dbh = dbLogin( );
    my $xtra;
    $xtra = "or it.term_oid = $searchTerm" if isInt( $searchTerm );
    my $sql = qq{
	select distinct it.term_oid, it.term
	        from img_term it
		    where lower( it.term ) like lower( '%$searchTerm%' ) $xtra
		        order by it.term
		    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @term_oids;
    for( ;; ) {
	my( $term_oid, $termn ) = $cur->fetchrow( );
	last if !$term_oid;
	push( @term_oids, $term_oid );
    }
    $cur->finish( );
    my $nTerms = @term_oids;
    if( $nTerms == 0 ) {
	print "<p>\n";
	print "No IMG terms found.\n";
	print "</p>\n";
	#$dbh->disconnect();
	printStatusLine( "0 terms retrieved.", 2 );
	return;
    }

    require ImgTermNode;
    require ImgTermNodeMgr;
    my $mgr = new ImgTermNodeMgr( );
    my $root = $mgr->loadTree( $dbh );
    my $count = 0;
    print "<p>\n";
    my %done;
    for my $term_oid( @term_oids ) {
	next if $done{ $term_oid };
	$count++;
	print "Result " . sprintf( "%03d:", $count ) . nbsp( 1 );
	my $n = $root->ImgTermNode::findNode( $term_oid );
	if( !defined( $n ) ) {
	    webLog( "printImgTermTree: cannot find term_oid='$term_oid'\n" );
	    next;
	}

	my $children = $n->{ children };
	my $nChildren = @$children;
       #if( $nChildren > 0 ) {
       # print "Term Node Tree<br/>\n";
       #}

	my @n_term_oids;
	$n->ImgTermNode::loadAllChildTermOids( \@n_term_oids );
	for my $i( @n_term_oids ) {
	    $done{ $i } = 1;
	          #$count++;
	}

	my %termOid2Html;
	#require FindFunctions;
	#FindFunctions::loadSearchTermOid2Html( $dbh, $n, \%termOid2Html );
	loadSearchTermOid2Html( $dbh, $n, \%termOid2Html );
	printSearchHtml2( $n, $searchTerm, \%ancestorNodes, \%termOid2Html );

	if( $nChildren > 0 ) {
	    print "<br/>\n";
	}
    }
    print "<p>\n";
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}


sub loadSearchTermOid2Html {
    my ( $dbh, $n, $termOid2Html_ref ) = @_;

    my @term_oids;
    $n->loadLeafTermOids( \@term_oids );
    my $nTerms   = @term_oids;
    my $term_oid = $n->{term_oid};
    if ( $nTerms > 1000 ) {
        webDie("loadSearchTermOid2Html: term_oid=$term_oid nTerms=$nTerms\n");
    }
    my $term_oid_str = join( ',', @term_oids );
    my $taxonClause  = txsClause("g.taxon", $dbh);
    my $rclause      = WebUtil::urClause("g.taxon");
    my $imgClause    = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql          = qq{
        select g.function, count( distinct g.gene_oid )
        from gene_img_functions g
        where g.function in( $term_oid_str )
        $taxonClause
        $rclause
        $imgClause
        group by g.function
        order by g.function
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $function, $cnt ) = $cur->fetchrow();
        last if !$function;
        my $s    = nbsp(1);
        my $link = 0;
        my $url  = "$section_cgi&page=imgTermGenes&term_oid=$function";
        $link = alink( $url, $cnt ) if $cnt > 0;
        $s .= "(" . $link . ")";
        $termOid2Html_ref->{$function} = $s;
    }
    $cur->finish();
}

############################################################################
# getAllAncestorNodes - get all ancestor nodes of this IMG term
#
# return a hash with all ancestors, including this term
############################################################################
sub getAllAncestorNodes {
    my ( $n_oid ) = @_;

    my %h;

    # starting from the current node
    my @idList = ( $n_oid );

    my $i = 0;
    while ( $i < scalar(@idList) ) {
	# get the Term oid
	my $n = $idList[$i];

	if ( ! $h{$n} ) {
	    # we haven't processed this node yet
	    # first, put it in %h
	    $h{$n} = $n;

	    # now, get all ancestors
	    my $dbh = dbLogin();

	    my $sql = "select term_oid from IMG_TERM_CHILDREN where child=$n";
            my $cur = execSql ($dbh, $sql, $verbose);

	    for (;;) { 
		my ( $val ) = $cur->fetchrow( );
		last if !$val;
 
		my $val2 = FuncUtil::termOidPadded( $val );

		# save this value to idList
		push @idList, ( $val2 );
	    }

	    ###$dbh->disconnect();
	}

	$i++;
    }

    return %h;
}


############################################################################
# printSearchHtml2 - Print HTML tree for a node.
#
# (This subroutine was copied from ImgTermNode.pm, and customized
#  for child term selection. All 'parent' and 'ancestor' nodes
#  are disabled to prevent loops in the term hierarchy.)
############################################################################
sub printSearchHtml2 {
    my( $node, $searchTerm, $ancestor_ref,
	$termOid2Html_ref, $notStartNode, $minusLevel ) = @_;

    my $term_oid = $node->{ term_oid };
    my $term = $node->{ term };
    my $level = $node->getLevel( );
    my $a = $node->{ children };
    my $nNodes = @$a;
    my $sp;
    $sp = nbsp( 2 ) x ( $level - $minusLevel ) if $notStartNode;

    print $sp;

    my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
    print "<input type='checkbox' name='term_oid' " .
	"id='$term_oid2' value='$term_oid2: " . escapeHTML($term) . "'";
    if ( $ancestor_ref->{$term_oid2} ) {
	print "disabled />";
    }
    else {
	print "/>";
    }

    if( $nNodes == 0 ) {
	print nbsp( 1 );
    }
    else {
	print "(Protein Complex)" . nbsp( 1 );
    }

    my $url = "$main_cgi?section=ImgTermBrowser" . 
	"&page=imgTermDetail&term_oid=$term_oid";
    my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
    print alink( $url, $term_oid2 );
    print nbsp( 1 );
   #print escapeHTML( $term );
    my $matchText = highlightMatchHTML2( $term, $searchTerm );
    print $matchText;
    my $xtra = $termOid2Html_ref->{ $term_oid };
    print $xtra;
    print "<br/>\n";

    for( my $i = 0; $i < $nNodes; $i++ ) {
	my $n2 = $a->[ $i ];
	my $level2 = 0;
	$level2 = $minusLevel if $notStartNode;
	printSearchHtml2( $n2, $searchTerm, $ancestor_ref, $termOid2Html_ref, 1, $level2 );
    }
}


############################################################################
# printMergeForm - merge term
############################################################################
sub printMergeForm {

    my $func_id = "";
    my $class_name = "";
    my $display_name = "";

    $func_id = param('func_id');
    $display_name = FuncUtil::funcIdToDisplayName($func_id);
    $class_name = FuncUtil::funcIdToClassName($func_id);
    my ($tag, $id2) = split (/:/, $func_id);

    print "<h1>Merge Other IMG Terms into Selected Term</h1>\n";
    my $dbh = dbLogin();
    my $term = termOid2Term($dbh, $id2);
    ###$dbh->disconnect();
    print "<h2>Term ($func_id): " . escapeHTML($term) . "</h2>\n";
    print "<p><font color='red'>Under Construction</font></p>\n";

    printMainForm( );

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "class_name", $class_name );

    # check id
    if ( blankStr($func_id) ) {
	webError ("No object is selected.");
	return; 
    }
    if ( $class_name ne 'IMG_TERM' ) {
	webError ("Only merging IMG terms is allowed. You must select an IMG term.");
	return;
    }
    print hiddenVar( "func_id", $func_id );

    # filter
    print "<p>\n";
    print "<h3>Search IMG Terms</h3>\n";
    my $filterVal = param ('mergeTermFilter');
    print "Please enter a search term.<br/>\n";
    print "Filter: <input type='text' id='mergeTermFilter' " .
	"name='mergeTermFilter' ";
    print " value='" . escapeHTML($filterVal) . "' size='50' maxLength='1000' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_mergeForm";
    print submit( -name => $name,
		  -value => 'Filter', -class => 'smbutton' );
    print "</p>\n";

    if ( ! blankStr( $filterVal ) ) {
	printImgTermTree( $filterVal, 'm' );
    }
    else {
	print "<p><font color='red'>Please enter a term in the Filter!</font></p>\n";
    }

    print "<p>\n"; # paragraph section puts text in proper font.

    print end_form( );
}


############################################################################
# dbUpdateChildTerm - update child terms of an IMG term in the database
############################################################################
sub dbUpdateChildTerm() {
    # get the term oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No IMG term is selected.");
	return -1;
    }
    my ($tag, $term_oid) = split (/\:/, $func_id);

    my @sqlList = ();

    # delete all child terms
    my $sql = "delete from IMG_TERM_CHILDREN where term_oid = $term_oid";
    push @sqlList, ( $sql );

    # insert new child terms
    my @allChildTerms = split (/ /, param('allCTerms'));
    my @termsAdded = ();

    my $cnt = 0;
    for my $s ( @allChildTerms ) {
	if ( length($s) > 0 && isInt($s)) {
	    if ( WebUtil::inArray($s, @termsAdded) ) {
		# duplicate
		next;
	    }

	    $sql = "insert into IMG_TERM_CHILDREN (term_oid, child, c_order) " .
		"values ($term_oid, $s, $cnt)";
	    push @sqlList, ( $sql );
	    $cnt++;
	}
    }

#    if ( scalar(@sqlList) > 0 ) {
#	for $sql ( @sqlList ) {
#	    print "<p>SQL: $sql</p>\n";
#	}
#    }

    # perform database update 
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 

    return $term_oid;
}


############################################################################ 
# printUpdateAssocForm - update association
#
# connect_mode: 0 (update only), 1 (add from cart), 2 (add from selection)
############################################################################ 
sub printUpdateAssocForm { 
    my ( $connect_mode ) = @_;

    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected in the Curation Cart.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and attribute definition
    my $class_name = FuncUtil::funcIdToClassName ($func_id);
    my $display_name = FuncUtil::funcIdToDisplayName ($func_id);
    my $assoc_type = FuncUtil::classNameToAssocType ($class_name);

    if ( blankStr($assoc_type) ) {
	webError ("No associations can be specified for $display_name.");
	return -1;
    }

    print "<h1>IMG $assoc_type Curation Page</h1>\n"; 
 
    printMainForm( );
    print hiddenVar( "func_id", $func_id );

    print "<p>Click the \"Update $assoc_type\" button to update information in the database. <br/>";
    print "<font color=\"red\">Only selected associations will be saved in the database after update. Unselected associations will be removed.</font></p>\n";

    my $dbh = dbLogin();
    my $obj_name = db_findVal($dbh, $class_name, FuncUtil::getOidAttr($class_name), $obj_oid,
			      FuncUtil::getNameAttr($class_name), '');;
    ###$dbh->disconnect();
    print "<h2>$display_name $obj_oid: " . escapeHTML( $obj_name ) . "</h2>\n";

    print hiddenVar( "func_name", escapeHTML( $obj_name ));

    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_confirmUpdateAssocForm";
    print submit( -name => $name,
		  -value => "Update $assoc_type", -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n";

    # get association data from database
    my $sql = FuncUtil::getAssocQuery($class_name, $obj_oid);
    my $assoc_class = FuncUtil::getAssocClass($class_name);
    if ( blankStr($sql) || blankStr($assoc_class) ) {
	return;
    }

    # print association data in a table
    print "<h3>$assoc_type Association</h3>\n";

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " . 
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<p/>\n";

    # get association attribute definition
    my @assoc_attrs = FuncUtil::getAssocAttributes($class_name);
    if ( scalar(@assoc_attrs) == 0 ) {
	return;
    }

    # get CV, if any
    my %cv;
    my @selects;
    for my $t ( @assoc_attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);
	if ( $data_type =~ /CV\:/ ) {
	    my ($t1, $t2, $t3) = split(/\:/, $data_type);
	    # select
	    @selects = ( "" );
	    my $dbh = dbLogin();
	    my $sql2 = "select $t3 from $t2";
	    my $cur2 = execSql( $dbh, $sql2, $verbose );
	    for (;;) { 
		my ($sel2) = $cur2->fetchrow( );
		last if !$sel2;

		push @selects, ( $sel2 );
	    }
	    $cur2->finish();
	    ###$dbh->disconnect();

	    $cv{$data_type} = [ @selects ];
	}
    }

    # add java script functions 'setFieldSelect'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setFieldSelect ( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.type == 'radio' ) {\n";
    print "              if ( e.value == x ) {\n";
    print "                   e.checked = true;\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>Select</th>\n"; 

    # table header
    for my $t ( @assoc_attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

	if ( $data_type =~ /\|/ ) {
	    # selection
	    my @selections = split (/\|/, $data_type);
	    print "<th class='img' width='$size'>$disp_name <br/>\n";

	    for my $t ( @selections ) {
		print "<input type='button' value='$t' Class='tinybutton'\n";
		print "  onClick='setFieldSelect (\"$t\")' />\n";
		print "<br/>\n";
	    }
	    print "</th>\n";
	}
	else {
	    # regular header
	    print "<th class='img'>$disp_name</th>\n"; 
	}
    }
    print "</tr>\n";

    my $max_order = 0;
    my @ids = ();

    my %saved_data;

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
	my @assoc_data = $cur->fetchrow( );
	last if !$assoc_data[0];

	my $assoc_oid = $assoc_data[0];
	$assoc_oid = FuncUtil::oidPadded($assoc_class, $assoc_oid);
	push @ids, ( $assoc_oid );

	# select? 
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='assoc_oid' value='$assoc_oid' checked />\n"; 
        print "</td>\n"; 
 
	my $i = 0;
	for my $t ( @assoc_attrs ) {
	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

	    if ( $i >= scalar(@assoc_data) ) {
		last;
	    }

	    my $attr_val = $assoc_data[$i];

	    # check max order
	    if ( $data_type eq 'order' ) {
		if ( isInt($attr_val) && $attr_val > $max_order ) {
		    $max_order = $attr_val;
		}
	    }

	    if ( $ed eq 'U' ) {
		# url
		$attr_val = FuncUtil::oidPadded($cl, $attr_val);
		my $url = FuncUtil::getUrl($main_cgi, $cl, $attr_val);
		print "<td class='img'>" . alink( $url, $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_oid"} = $attr_val;
	    }
	    elsif ( $ed eq 'N' ) {
		# display only; no editing
		print "<td class='img'>" . escapeHTML( $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_oid"} = $attr_val;
	    }
	    elsif ( $ed eq 'Y' ) {
		if ( $data_type =~ /\|/ ) {
		    # selection
		    my @selections = split (/\|/, $data_type);
		    my $bgcolor = '#eeeeee';
		    if ( !blankStr($cl) && $cl =~ /\#/ ) {
			$bgcolor = $cl;
		    }
		    my $j = 0;
		    print "  <td class='img' bgcolor='$bgcolor'>\n";
		    for my $tt ( @selections ) {
			if ( $j > 0 ) {
			    print "<br/>\n";
			}
			print "     <input type='radio' name='$attr_name:$assoc_oid' " .
			    "value='$tt'";
			if ( (uc $attr_val) eq (uc $tt) ) {
			    print " checked";
			}

			if ( length($tt) > 5 ) {
			    print "/><font size='-1'>$tt</font>\n";
			}
			else {
			    print "/>$tt\n";
			}
			$j++;
		    }
		    print "     </td>\n";
		}
		elsif ( $data_type =~ /CV\:/ ) {
		    # selects;
		    print "<td class='img'>\n";
		    if ( $cv{$data_type} ) {
			my @selects = @{ $cv{$data_type} };
			print "<select name='$attr_name:$assoc_oid' class='img' size='1'>\n";
			for my $val2 ( @selects ) {
			    print "    <option value='$val2'";
			    if ( $val2 eq $attr_val ) {
				print " selected ";
			    }
			    print ">$val2</option>\n";
			}
			print "</select>\n";
		    }
		    else {
			print "<input type='text' ";
			print "name='$attr_name:$assoc_oid' id='$attr_name:$assoc_oid' value='" .
			    "not found" . "' size=30 maxLength=30 />\n";
		    }
		    print "</td>\n";
		}
		else {
		    # text editing
		    print "<td class='img'>\n";
		    print "<input type='text' ";
		    print "name='$attr_name:$assoc_oid' id='$attr_name:$assoc_oid' value='" .
			$attr_val . "' size=$size maxLength=$size /> </td>\n";
		}
	    }
	    else {
		# default -- shouldn't get here
		print "<td class='img'></td>\n";
	    }

	    # next
	    $i++;
	}

	print "</tr>\n";
    }
    $cur->finish();
    ###$dbh->disconnect();

    if ( $connect_mode == 1 || $connect_mode == 2 ) {
	my %assoc_dt;

	if ( $connect_mode == 1 ) {
	    # load from cart
	    my $cart = new CuraCartStor( );
	    my $recs = $cart->{ recs }; 
	    my @keys = sort( keys( %$recs ) ); 

	    for my $key ( @keys ) { 
		next if ($class_name eq 'IMG_COMPOUND' && $key !~ /IREXN/);
		next if ($class_name eq 'IMG_PARTS_LIST' && $key !~ /ITERM/);
		next if ($class_name eq 'IMG_PATHWAY' && $key !~ /IREXN/);
		next if ($class_name eq 'IMG_REACTION' && $key !~ /ICMPD/);
		next if ($class_name eq 'IMG_TERM' && $key !~ /IREXN/);

		my $r = $recs->{ $key }; 
		my( $func_id, $func_name, $batch_id ) = split( /\t/, $r ); 
		my ($tag, $assoc_oid) = split (/:/, $func_id);
		$assoc_oid = FuncUtil::oidPadded($assoc_class, $assoc_oid);
		$assoc_dt{$assoc_oid} = $func_name;
	    }
	}
	else {
	    # load from search result
	    my @keys = param ( 'search_id' );
	    my $dbh = dbLogin();
	    for my $key ( @keys ) {
		my $assoc_oid = FuncUtil::oidPadded($assoc_class, $key);
		my $a_name = db_findVal($dbh, $assoc_class,
					FuncUtil::getOidAttr($assoc_class),
					$assoc_oid,
					FuncUtil::getNameAttr($assoc_class), '');;
		$assoc_dt{$assoc_oid} = $a_name;
	    }
	    ###$dbh->disconnect();
	}

	for my $assoc_oid ( keys %assoc_dt ) {
	    # skip duplicates
	    if ( WebUtil::inIntArray($assoc_oid, @ids) ) {
		    next;
	    }

	    my $func_name = $assoc_dt{$assoc_oid};

	    # select? 
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='assoc_oid' value='$assoc_oid' checked />\n"; 
	    print "</td>\n"; 

	    my @assoc_data = ( $assoc_oid, $func_name );

	    my $i = 0;
	    for my $t ( @assoc_attrs ) {
		my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

		my $attr_val = "";
		if ( $i < scalar(@assoc_data) ) {
		    $attr_val = $assoc_data[$i];
		}

		# get order
		if ( $data_type eq 'order' ) {
		    $max_order++;
		    $attr_val = $max_order;
		}

		# display attribute value
		if ( $ed eq 'U' ) {
		    # url
		    $attr_val = FuncUtil::oidPadded($cl, $attr_val);
		    my $url = FuncUtil::getUrl($main_cgi, $cl, $attr_val);
		    print "<td class='img'>" . alink( $url, $attr_val ) . "</td>\n";

		    $saved_data{"$attr_name:$assoc_oid"} = $attr_val;
		}
		elsif ( $ed eq 'N' ) {
		    # display only; no editing
		    print "<td class='img'>" . escapeHTML( $attr_val ) . "</td>\n";

		    $saved_data{"$attr_name:$assoc_oid"} = $attr_val;
		}
		elsif ( $ed eq 'Y' ) {
		    if ( $data_type =~ /\|/ ) {
			# selection
			my @selections = split (/\|/, $data_type);
			my $bgcolor = '#eeeeee';
			if ( !blankStr($cl) && $cl =~ /\#/ ) {
			    $bgcolor = $cl;
			}
			my $j = 0;
			print "  <td class='img' bgcolor='$bgcolor'>\n";
			for my $tt ( @selections ) {
			    if ( $j > 0 ) {
				print "<br/>\n";
			    }
			    print "     <input type='radio' name='$attr_name:$assoc_oid' " .
				"value='$tt'";
			    if ( (uc $attr_val) eq (uc $tt) ) {
				print " checked";
			    }

			    if ( length($tt) > 5 ) {
				print "/><font size='-1'>$tt</font>\n";
			    }
			    else {
				print "/>$tt\n";
			    }
			    $j++;
			}
			print "     </td>\n";
		    }
		    elsif ( $data_type =~ /CV\:/ ) {
			# selects;
			print "<td class='img'>\n";
			if ( $cv{$data_type} ) {
			    my @selects = @{ $cv{$data_type} };
			    print "<select name='$attr_name:$assoc_oid' class='img' size='1'>\n";
			    for my $val2 ( @selects ) {
				print "    <option value='$val2'";
				if ( $val2 eq $attr_val ) {
				    print " selected ";
				}
				print ">$val2</option>\n";
			    }
			    print "</select>\n";
			}
		    }
		    else {
			# text editing
			print "<td class='img'>\n";
			print "<input type='text' ";
			print "name='$attr_name:$assoc_oid' id='$attr_name:$assoc_oid' value='" .
			    $attr_val . "' size=$size maxLength=$size /> </td>\n";
		    }
		}
		else {
		    # default -- shouldn't get here
		    print "<td class='img'></td>\n";
		}

		# next
		$i++;
	    }

	    print "</tr>\n";
	}
    }

    print "</table>\n";

    print "<br/>\n";

    if ( $class_name eq 'IMG_TERM' ) {
	# additional message for term - reaction association
	print "<p>(Sub-cell localization is for Substrate or Product only.)</p>\n";
    }

    # print association data as hidden var
    for my $key ( keys %saved_data ) {
	my $val = $saved_data{$key};
	print hiddenVar( $key, escapeHTML( $val ));
    }

    print end_form( );
}

sub printUpdateRxnAssoc { 
    my ( $rxn_id, $func_type ) = @_;

    # get selected oid
    my $func_id = param ('func_id');
    my ($tag, $obj_oid) = split (/:/, $func_id);
    if ( blankStr($func_id) ) {
	$tag = "";
	$obj_oid = 0;
    }

    # get class name and attribute definition
    my $class_name = FuncUtil::funcIdToClassName ($func_type);
    $class_name = "IMG_REACTION";

    my $assoc_type = "Reaction - Compound";
    my $p_class = "IMG_COMPOUND";
    if ( $func_type eq 'ITERM' ) {
	$assoc_type = "Reaction - Term";
	$p_class = "IMG_TERM";
    }

    my $cart = new CuraCartStor( );
    my $recs = $cart->{ recs }; 
    my @keys = keys( %$recs );
    my %funcs;
    for my $k (@keys) {
	my ($k1, $k2) = split(/\:/, $k);
	if ( $k1 eq $func_type ) {
	    my $k2 = FuncUtil::oidPadded($p_class, $k2);
	    $funcs{$k2} = 1;
	}
    }

    if ( scalar(keys %funcs) == 0 ) {
	return;
    }

#    print "<h3>Associated $class_name</h3>\n"; 
#    printMainForm();

    my $dbh = dbLogin();
    print "<p>\n";

    # get association data from database
    my $sql = "";
    my @bindList = ();
    my ($tag, $rxn_oid) = split(/\:/, $rxn_id);
    if ( ! $rxn_oid ) {
	$rxn_oid = 0;
    }
    if ( $func_type eq 'ICMPD' ) {
	$sql = "select distinct c.compound_oid, c.compound_name, " .
	    "irc.c_type, irc.main_flag, irc.stoich, irc.sub_cell_loc " .
	    "from img_reaction_c_components irc, img_compound c where irc.rxn_oid = ? " .
	    "and irc.compound = c.compound_oid order by 1 ";
	@bindList = ( $rxn_oid );
    }
    elsif ( $func_type eq 'ITERM' ) {
	$sql = "select r1.catalysts, t1.term, 'Catalyst', 'No', 0, '' " .
	    "from img_reaction_catalysts r1, img_term t1 " .
	    "where r1.rxn_oid = ? and t1.term_oid = r1.catalysts " .
	    "union select r2.term, t2.term, r2.c_type, r2.main_flag, " .
	    "r2.stoich, r2.sub_cell_loc " .
	    "from img_reaction_t_components r2, img_term t2 " .
	    "where r2.rxn_oid = ? and t2.term_oid = r2.term order by 1 ";
	@bindList = ( $rxn_oid, $rxn_oid );
    }

    my $assoc_class = FuncUtil::getAssocClass($class_name);
    if ( $func_type eq 'ITERM' ) {
	$assoc_class = "IMG_TERM";
    }
    else {
	$assoc_class = "IMG_COMPOUND";
    }
    if ( blankStr($sql) || blankStr($assoc_class) ) {
	return;
    }

    # print association data in a table
    print "<h3>$assoc_type Association</h3>\n";

#    print "<input type='button' name='selectAll' value='Select All' " .
#        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
#    print "<input type='button' name='clearAll' value='Clear All' " . 
#        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
#    print "<p/>\n";

    # get association attribute definition
    my @assoc_attrs = ();
    if ( $func_type eq 'ICMPD' ) {
        push @assoc_attrs, ("compound\tCompound OID\tint\t5\tU\tIMG_COMPOUND");
        push @assoc_attrs, ("compound_name\tCompound Name\tchar\t60\tN\t");
        push @assoc_attrs, ("c_type\tLeft/Right?\tLHS|RHS\t60\tY\t#eed0d0"); 
        push @assoc_attrs, ("main_flag\tIs Main?\tYes|No|Unknown\t80\tY\t#aaaabb");
        push @assoc_attrs, ("stoich\tStoichiometry Value\tint\t4\tY\t"); 
        push @assoc_attrs,
          ( 
	    "sub_cell_loc\tSub-cell Localization\tCV:CELL_LOCALIZATION:loc_type\t200\tY\t"
          ); 
    }
    else {
        push @assoc_attrs, ("term_oid\tTerm OID\tint\t5\tU\tIMG_TERM");
        push @assoc_attrs, ("term\tTerm Name\tchar\t60\tN\t");
        push @assoc_attrs, 
          ( 
	    "c_type\tAssociation_Type\tCatalyst|Product|Substrate\t64\tY\t#99e009"
          ); 
        push @assoc_attrs, 
          ( 
	    "sub_cell_loc\tSub-cell Localization\tCV:CELL_LOCALIZATION:loc_type\t200\tY\t"
          ); 
    }
    if ( scalar(@assoc_attrs) == 0 ) {
	return;
    }

    # get CV, if any
    my %cv;
    my @selects;
    for my $t ( @assoc_attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);
	if ( $data_type =~ /CV\:/ ) {
	    my ($t1, $t2, $t3) = split(/\:/, $data_type);
	    # select
	    @selects = ( "" );
	    my $dbh = dbLogin();
	    my $sql2 = "select $t3 from $t2";
	    my $cur2 = execSql( $dbh, $sql2, $verbose );
	    for (;;) { 
		my ($sel2) = $cur2->fetchrow( );
		last if !$sel2;

		push @selects, ( $sel2 );
	    }
	    $cur2->finish();
	    ###$dbh->disconnect();

	    $cv{$data_type} = [ @selects ];
	}
    }

    # add java script functions 'setFieldSelect'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setFieldSelect ( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.type == 'radio' ) {\n";
    print "              if ( e.value == x ) {\n";
    print "                   e.checked = true;\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>Select</th>\n"; 

    # table header
    for my $t ( @assoc_attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

	if ( $data_type =~ /\|/ ) {
	    # selection
	    my @selections = split (/\|/, $data_type);
	    print "<th class='img' width='$size'>$disp_name <br/>\n";

	    for my $t ( @selections ) {
		print "<input type='button' value='$t' Class='tinybutton'\n";
		print "  onClick='setFieldSelect (\"$t\")' />\n";
		print "<br/>\n";
	    }
	    print "</th>\n";
	}
	else {
	    # regular header
	    print "<th class='img'>$disp_name</th>\n"; 
	}
    }
    print "</tr>\n";

    my $max_order = 0;
    my @ids = ();

    my %saved_data;

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @bindList );

#    print "<p>SQL 2: $sql\n";

    for (;;) { 
	my @assoc_data = $cur->fetchrow( );
	last if !$assoc_data[0];

#	print "<p>*** " . join(",", @assoc_data) . "\n";

	my $assoc_oid = $assoc_data[0];
	$assoc_oid = FuncUtil::oidPadded($assoc_class, $assoc_oid);
	$funcs{$assoc_oid} = 2;
	push @ids, ( $assoc_oid );

	# select? 
	my $assoc_func_id = $func_type . ':' . $assoc_oid;
        print "<td class='img'>\n";
        print "<input type='checkbox' ";
        print "name='assoc_oid' value='$assoc_func_id' checked />\n"; 
        print "</td>\n"; 
 
	my $i = 0;
	for my $t ( @assoc_attrs ) {
	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

	    if ( $i >= scalar(@assoc_data) ) {
		last;
	    }

	    my $attr_val = $assoc_data[$i];

	    # check max order
	    if ( $data_type eq 'order' ) {
		if ( isInt($attr_val) && $attr_val > $max_order ) {
		    $max_order = $attr_val;
		}
	    }

	    if ( $ed eq 'U' ) {
		# url
		my ($id1, $id2) = split(/\:/, $attr_val);
		if ( $id2 ) {
		    $attr_val = $id2;
		}
		$attr_val = FuncUtil::oidPadded($cl, $attr_val);
		my $url = FuncUtil::getUrl($main_cgi, $cl, $attr_val);
		print "<td class='img'>" . alink( $url, $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_func_id"} = $attr_val;
	    }
	    elsif ( $ed eq 'N' ) {
		# display only; no editing
		print "<td class='img'>" . escapeHTML( $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_func_id"} = $attr_val;
	    }
	    elsif ( $ed eq 'Y' ) {
		if ( $data_type =~ /\|/ ) {
		    # selection
		    my @selections = split (/\|/, $data_type);
		    my $bgcolor = '#eeeeee';
		    if ( !blankStr($cl) && $cl =~ /\#/ ) {
			$bgcolor = $cl;
		    }
		    my $j = 0;
		    print "  <td class='img' bgcolor='$bgcolor'>\n";
		    for my $tt ( @selections ) {
			if ( $j > 0 ) {
			    print "<br/>\n";
			}
			print "     <input type='radio' name='$attr_name:$assoc_func_id' " .
			    "value='$tt'";
			if ( (uc $attr_val) eq (uc $tt) ) {
			    print " checked";
			}

			if ( length($tt) > 5 ) {
			    print "/><font size='-1'>$tt</font>\n";
			}
			else {
			    print "/>$tt\n";
			}
			$j++;
		    }
		    print "     </td>\n";
		}
		elsif ( $data_type =~ /CV\:/ ) {
		    # selects;
		    print "<td class='img'>\n";
		    if ( $cv{$data_type} ) {
			my @selects = @{ $cv{$data_type} };
			print "<select name='$attr_name:$assoc_func_id' class='img' size='1'>\n";
			for my $val2 ( @selects ) {
			    print "    <option value='$val2'";
			    if ( $val2 eq $attr_val ) {
				print " selected ";
			    }
			    print ">$val2</option>\n";
			}
			print "</select>\n";
		    }
		    else {
			print "<input type='text' ";
			print "name='$attr_name:$assoc_func_id' id='$attr_name:$assoc_func_id' value='" .
			    "not found" . "' size=30 maxLength=30 />\n";
		    }
		    print "</td>\n";
		}
		else {
		    # text editing
		    print "<td class='img'>\n";
		    print "<input type='text' ";
		    print "name='$attr_name:$assoc_func_id' id='$attr_name:$assoc_func_id' value='" .
			$attr_val . "' size=$size maxLength=$size /> </td>\n";
		}
	    }
	    else {
		# default -- shouldn't get here
		print "<td class='img'></td>\n";
	    }

	    # next
	    $i++;
	}

	print "</tr>\n";
    }
    $cur->finish();
    ###$dbh->disconnect();

    my %assoc_dt;
    # show all selections
    for my $key ( sort (keys %funcs) ) {
	if ( $funcs{$key} > 1 ) {
	    next;
	}

	my $assoc_oid = FuncUtil::oidPadded($assoc_class, $key);
	my $a_name = db_findVal($dbh, $assoc_class,
				FuncUtil::getOidAttr($assoc_class),
				$assoc_oid,
				FuncUtil::getNameAttr($assoc_class), '');;
	$assoc_dt{$assoc_oid} = $a_name;
    }

    for my $assoc_oid ( keys %assoc_dt ) {
	my $func_name = $assoc_dt{$assoc_oid};
	my $assoc_func_id = $func_type . ':' . $assoc_oid;

	# select? 
	my $checked = "";
	if ( $funcs{$assoc_oid} > 1 ) {
	    $checked = "checked";
	}
	print "<td class='img'>\n";
	print "<input type='checkbox' ";
	print "name='assoc_oid' value='$assoc_func_id' $checked />\n"; 
	print "</td>\n"; 

	my @assoc_data = ( $assoc_func_id, $func_name );

	my $i = 0;
	for my $t ( @assoc_attrs ) {
	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);

	    my $attr_val = "";
	    if ( $i < scalar(@assoc_data) ) {
		$attr_val = $assoc_data[$i];
	    }

	    # get order
	    if ( $data_type eq 'order' ) {
		$max_order++;
		$attr_val = $max_order;
	    }

	    # display attribute value
	    if ( $ed eq 'U' ) {
		# url
		my ($id1, $id2) = split(/\:/, $attr_val);
		if ( $id2 ) {
		    $attr_val = $id2;
		}
		$attr_val = FuncUtil::oidPadded($cl, $attr_val);
		my $url = FuncUtil::getUrl($main_cgi, $cl, $attr_val);
		print "<td class='img'>" . alink( $url, $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_func_id"} = $attr_val;
	    }
	    elsif ( $ed eq 'N' ) {
		# display only; no editing
		print "<td class='img'>" . escapeHTML( $attr_val ) . "</td>\n";

		$saved_data{"$attr_name:$assoc_func_id"} = $attr_val;
	    }
	    elsif ( $ed eq 'Y' ) {
		if ( $data_type =~ /\|/ ) {
		    # selection
		    my @selections = split (/\|/, $data_type);
		    my $bgcolor = '#eeeeee';
		    if ( !blankStr($cl) && $cl =~ /\#/ ) {
			$bgcolor = $cl;
		    }
		    my $j = 0;
		    print "  <td class='img' bgcolor='$bgcolor'>\n";
		    for my $tt ( @selections ) {
			if ( $j > 0 ) {
			    print "<br/>\n";
			}
			print "     <input type='radio' name='$attr_name:$assoc_func_id' " .
			    "value='$tt'";
			if ( (uc $attr_val) eq (uc $tt) ) {
			    print " checked";
			}

			if ( length($tt) > 5 ) {
			    print "/><font size='-1'>$tt</font>\n";
			}
			else {
			    print "/>$tt\n";
			}
			$j++;
		    }
		    print "     </td>\n";
		}
		elsif ( $data_type =~ /CV\:/ ) {
		    # selects;
		    print "<td class='img'>\n";
		    if ( $cv{$data_type} ) {
			my @selects = @{ $cv{$data_type} };
			print "<select name='$attr_name:$assoc_func_id' class='img' size='1'>\n";
			for my $val2 ( @selects ) {
			    print "    <option value='$val2'";
			    if ( $val2 eq $attr_val ) {
				print " selected ";
			    }
			    print ">$val2</option>\n";
			}
			print "</select>\n";
		    }
		}
		else {
		    # text editing
		    print "<td class='img'>\n";
		    print "<input type='text' ";
		    print "name='$attr_name:$assoc_func_id' id='$attr_name:$assoc_func_id' value='" .
			$attr_val . "' size=$size maxLength=$size /> </td>\n";
		}
	    }
	    else {
		# default -- shouldn't get here
		print "<td class='img'></td>\n";
	    }

	    # next
	    $i++;
	}

	print "</tr>\n";
    }

    print "</table>\n";

    print "<br/>\n";

    if ( $class_name eq 'IMG_TERM' ) {
	# additional message for term - reaction association
	print "<p>(Sub-cell localization is for Substrate or Product only.)</p>\n";
    }

    # print association data as hidden var
    for my $key ( keys %saved_data ) {
	my $val = $saved_data{$key};
	print hiddenVar( $key, escapeHTML( $val ));
    }

#    print end_form( );
}

############################################################################
# printSearchAssocResults - Show results of association search.
############################################################################
sub printSearchAssocResults {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected in the Curation Cart.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and attribute definition
    my $class_name = FuncUtil::funcIdToClassName ($func_id);
    my $display_name = FuncUtil::funcIdToDisplayName ($func_id);
    my $assoc_type = FuncUtil::classNameToAssocType ($class_name);

    if ( blankStr($assoc_type) ) {
	webError ("No associations can be specified for $display_name.");
	return -1;
    }

    my $assoc_class = FuncUtil::getAssocClass($class_name);

    print "<h1>Search $assoc_class for $assoc_type Association</h1>\n"; 

    printMainForm( );
    print hiddenVar( "func_id", $func_id );

    print "<h2>$display_name ($obj_oid)</h2>\n";

    my $searchKey = param( "searchKey" );
    my $max_item_count = param ( 'max_item_count' );
    if ( blankStr($max_item_count) ) {
	$max_item_count = 1000;
    }

    print "<p>\n";
    print "Max number of returned items: ";
    print nbsp( 3 ); 
    print "<select name='max_item_count' class='img' size='1'>\n";
    for my $cnt0 ( 20, 50, 100, 200, 500, 800, 1000, 2000, 5000, 8000, 10000 ) {
	print "    <option value='$cnt0'";
	if ( $cnt0 eq $max_item_count ) {
	    print " selected ";
	}
	print ">$cnt0</option>\n";
    }
    print "</select>\n";
    print "<p/>\n";

    print "Enter Search Keyword.  Use % for wildcard.";
    print "<br/>\n";
    print "<input type='text' name='searchKey' value='$searchKey' " .
	"size='60' maxLength='255' />\n";

    # add buttons
    print "<p>\n";
    my $name = "_section_${section}_searchAssocResultForm";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    if( $searchKey eq "" ) {
        webError( "Please enter a keyword to search." );
	print end_form();
	return;
    }

    # SQL query
    my ($sql, @bindList) = FuncUtil::getSearchQuery($assoc_class, $searchKey);
    my $def_attr = FuncUtil::getSearchDefAttr($assoc_class);

    if ( blankStr($sql) ) {
	return;
    }

    my $assoc_display_name = FuncUtil::classNameToDisplayName($assoc_class);

    # database search
    my $dbh = dbLogin( );

    printStatusLine( "Loading ...", 1 );

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    my $count = 0;
    for( ;; ) {
        my( $result_oid, $result_name, $result_def ) = $cur->fetchrow( );
	last if !$result_oid;

	$count++;

	if ( $count == 1 ) {
	    print "<h2>Select " . $assoc_display_name . "s</h2>\n";
	    print "<p>The following list shows all $assoc_display_name" .
		"s that have names ";
	    if ( !blankStr($def_attr) ) {
		print 'or ' . lc($def_attr) . 's ';
	    }
	    print "matching the input search keyword.<br/>\n";
	    print "Click item(s) to add to Association</p>\n";
	    print "<p>\n";

	    # show buttons
	    my $name = "_section_${section}_addToAssoc";
	    print submit( -name => $name,
			  -value => "Add to Association", -class => "lgdefbutton" );
	    print nbsp( 1 );
	    print "<input type='button' name='selectAll' value='Select All' " .
		"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	    print nbsp( 1 );
	    print "<input type='button' name='clearAll' value='Clear All' " . 
		"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	    print nbsp( 1 );
	    my $name = "_section_${section}_index";
	    print submit( -name => $name,
			  -value => 'Cancel', -class => 'smbutton' );

	    print "<br/>\n";
	}

	if ( $count > $max_item_count ) {
	    last;
	}

	# show this result
	$result_oid = FuncUtil::oidPadded($class_name, $result_oid);
	print "<input type='checkbox' name='search_id' value='$result_oid' />\n";
	my $url = FuncUtil::getUrl($main_cgi, $assoc_class, $result_oid);
	print nbsp( 1 ); 
	print alink( $url, $result_oid ); 
	print nbsp( 1 ); 

	# print reaction name
	if ( blankStr($searchKey) ) {
	    print escapeHTML($result_name);
	}
	else {
	    my $matchText = highlightMatchHTML2($result_name, $searchKey); 
	    print $matchText; 
	}

	# print reaction definition
	if ( !blankStr($result_def) ) {
	    print "<br/>\n";
	    if ( blankStr($searchKey) ) {
		print nbsp( 7 );
		print "($def_attr: " . escapeHTML($result_name) . ")";
	    }
	    else {
		my $matchText = highlightMatchHTML2($result_def, $searchKey); 
		print nbsp( 7 );
		print "($def_attr: $matchText)"; 
	    }
	}

	print "<br/>\n"; 
    }
    $cur->finish( );

    ###$dbh->disconnect();

    if ( $count == 0 ) {
        printStatusLine( "$count item(s) found.", 2 );
        webError( 'No ' . $assoc_display_name . 's matches the keyword.' );
        return;
    }

    print "</p>\n";
    if ( $count > $max_item_count ) {
        printStatusLine( "Too many results. Only $max_item_count items displayed.", 2 );
    }
    else {
	printStatusLine( "$count item(s) found.", 2 );
    }

    # show buttons
    print "<br/><br/>\n";

    my $name = "_section_${section}_addToAssoc";
    print submit( -name => $name,
		  -value => "Add to Association", -class => "lgdefbutton" );
    print nbsp( 1 );
    print "<input type='button' name='selectAll' value='Select All' " .
	"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " . 
	"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################
# printAdvancedSearchForm - advanced search
############################################################################
sub printAdvancedSearchForm {
    print "<h1>Advanced Search</h1>\n";
    
    printMainForm( );

    # get parameters
    my $class_name = param( "class_name" );
    if ( blankStr($class_name) ) {
	webError("No class has been selected.");
	return;
    }

    my $max_item_count = param ( 'max_item_count' );
    if ( blankStr($max_item_count) ) {
	$max_item_count = 1000;
    }

    print "<p>\n";
    print "Max number of returned items: ";
    print nbsp( 3 ); 
    print "<select name='max_item_count' class='img' size='1'>\n";
    for my $cnt0 ( 20, 50, 100, 200, 500, 800, 1000, 2000, 5000, 8000, 10000 ) {
	print "    <option value='$cnt0'";
	if ( $cnt0 eq $max_item_count ) {
	    print " selected ";
	}
	print ">$cnt0</option>\n";
    }
    print "</select>\n";
    print "<p/>\n";

    my $display_name = FuncUtil::classNameToDisplayName($class_name);
    print "<h2>Class: $display_name</h2>\n";

    print hiddenVar( "class_name", $class_name );
    print hiddenVar( "max_item_count", $max_item_count );

    # get advanced search attributes
    my %attrs = FuncUtil::getAdvSearchAttributes($class_name);
    my @keys = keys %attrs;
    if ( scalar(@keys) == 0 ) {
	return;
    }

    my $i;
    for ($i = 0; $i < $max_cond_count; $i++) {
	# attribute
	my $label = "attr_" . $i;
	print "<select name='$label' class='img' size='1'>\n";
	print "   <option value='0'> </option>\n";
	for my $k ( sort @keys ) {
	    my ($disp_name, $t_name, $t_alias, $data_type, $cond) =
		split (/\t/, $attrs{$k});
	    print "   <option value='$k'>$disp_name</option>\n";
	}
	print "</select>\n";

	# comparator
	$label = "comp_" . $i;
	print nbsp( 1 ); 
	print "<select name='$label' class='img' size='1'>\n";
	print "   <option value='0'> </option>\n";
	for my $k ( '=', '!=', '>', '>=', '<', '<=',
		    'is null', 'is not null', 'match', 'not match' ) {
	    my $k2 = escapeHTML($k);
	    print "   <option value='$k2'>$k2</option>\n";
	}
	print "</select></td>\n";

	# value
	$label = "val_" . $i;
	print nbsp( 1 ); 
	print "<input type='text' name='$label' value='' " .
		"size='60' maxLength='255'/>\n";

	print "<br/>\n";
    }

    print "<h5>(Use 'DD-MON-YY' for Date format.)</h5>\n";

    # set-valued attributes
    my @set_rels = FuncUtil::getAdvSearchRelations($class_name);
    for my $s_rel ( @set_rels ) {
	my ( $r_name, $r_alias, $r_key, $r_display) = split(/\t/, $s_rel);

	print "<h3>Additional Condition on $r_display</h3>\n";

	my %s_attrs = FuncUtil::getAdvSearchSetAttrs($class_name, $r_name);
	my @keys = keys %s_attrs;
	if ( scalar(@keys) == 0 ) {
	    next;
	}

	my $i;
	for ($i = 0; $i < $max_set_cond_count; $i++) {
	    # attribute
	    my $label = "$r_name:attr_" . $i;
	    print "<select name='$label' class='img' size='1'>\n";
	    print "   <option value='0'> </option>\n";
	    for my $k ( sort @keys ) {
		my ($disp_name, $t_name, $t_alias, $data_type, $cond) =
		    split (/\t/, $s_attrs{$k});
		print "   <option value='$k'>$disp_name</option>\n";
	    }
	    print "</select>\n";

	    # comparator
	    $label = "$r_name:comp_" . $i;
	    print nbsp( 1 ); 
	    print "<select name='$label' class='img' size='1'>\n";
	    print "   <option value='0'> </option>\n";
	    for my $k ( '=', '!=', '>', '>=', '<', '<=',
			'is null', 'is not null', 'match', 'not match' ) {
		my $k2 = escapeHTML($k);
		print "   <option value='$k2'>$k2</option>\n";
	    }
	    print "</select></td>\n";

	    # value
	    $label = "$r_name:val_" . $i;
	    print nbsp( 1 ); 
	    print "<input type='text' name='$label' value='' " .
		"size='60' maxLength='255'/>\n";

	    print "<br/>\n";
	}
    }

    # print "<h5>(Use 'DD-MON-YY' for Date format.)</h5>\n";

    # add buttons
    print "<p>\n";
    my $name = "_section_${section}_queryResult";
    print submit( -name => $name,
		  -value => "Search", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################
# printAdvancedResultForm - advanced search result
############################################################################
sub printAdvancedResultForm {
    print "<h1>Advanced Search Results to Add to Curation Cart</h1>\n";
    
    printMainForm( );

    # get parameters
    my $class_name = param( "class_name" );
    my $max_item_count = param ( 'max_item_count' );

    if ( blankStr($class_name) ) {
	print end_form();
	return;
    }

    print hiddenVar( "class_name", $class_name );
    print hiddenVar( "max_item_count", $max_item_count );

    my $display_name = FuncUtil::classNameToDisplayName($class_name);

    # get advanced search attributes
    my %attrs = FuncUtil::getAdvSearchAttributes($class_name);
    my @keys = keys %attrs;
    if ( scalar(@keys) == 0 ) {
	return;
    }

    my $oid_attr = FuncUtil::getOidAttr($class_name);
    my $name_attr = FuncUtil::getNameAttr($class_name);
    if ( blankStr($oid_attr) || blankStr($name_attr) ) {
	return;
    }

    my @displays = ( "$display_name OID", "$display_name Name" );
    my @selects = ( "r0.$oid_attr", "r0.$name_attr" );
    my @froms = ( "$class_name r0" );
    my @wheres = ( );

    my $sql;

    my $i;
    for ($i = 0; $i < $max_cond_count; $i++) {
	# get each condition
	my $attr_name = param ("attr_" . $i);
	my $comp = param ("comp_" . $i);
	my $val = param ("val_" . $i);

	# check
	if ( blankStr($attr_name) || blankStr($comp) ) {
	    next;
	}
	if ( $comp ne 'is null' && $comp ne 'is not null' &&
	     blankStr($val) ) {
	    next;
	}
	if ( ! $attrs{$attr_name} ) {
	    next;
	}

	my $attr_def = $attrs{$attr_name};
	my ($disp_name, $t_name, $t_alias, $data_type, $cond) =
	    split (/\t/, $attr_def);

	# add to select?
	if ( ! WebUtil::inArray($attr_name, @selects) ) {
	    push @selects, ( $attr_name );
	    push @displays, ( $disp_name );
	}

	# add to from?
	my $s = "$t_name $t_alias";
	if ( ! WebUtil::inArray($s, @froms) ) {
	    push @froms, ( $s );

	    if ( !blankStr($cond) ) {
		push @wheres, ( $cond );
	    }
	}

	# where
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	if ( $comp eq 'is null' || $comp eq 'is not null' ) {
	    $s = "$attr_name $comp";
	    push @wheres, ( $s );
	}
	elsif ( $data_type eq 'int' || $data_type eq 'order' ) {
	    if ( ! isInt($val) || $comp eq 'match' || $comp eq 'not match' ) {
		webError("Incorrect query condition: $disp_name $comp $val.");
		return;
	    }

	    $s = "$attr_name $comp $val";
	    push @wheres, ( $s );
	}
	elsif ( $data_type eq 'number' ) {
	    if ( ! isNumber($val) || $comp eq 'match' || $comp eq 'not match' ) {
		webError("Incorrect query condition: $disp_name $comp $val.");
		return;
	    }

	    $s = "$attr_name $comp $val";
	    push @wheres, ( $s );
	}
	elsif ( $data_type eq 'char' || $data_type eq 'date' ) {
	    $val =~ s/'/''/g;  # replace ' with ''
	    if ( $comp eq 'match' ) {
		$val = uc($val);
		$s = "upper($attr_name) like '%" . $val . "%'";
	    }
	    elsif ( $comp eq 'not match' ) {
		$val = uc($val);
		$s = "upper($attr_name) not like '%" . $val . "%'";
	    }
	    else {
		$s = "$attr_name $comp '$val'";
	    }

	    push @wheres, ( $s );
	}
    }

    # set-valued attributes
    my $sql2;
    my @subqueries = ();
    my @set_rels = FuncUtil::getAdvSearchRelations($class_name);
    for my $s_rel ( @set_rels ) {
	my ( $r_name, $r_alias, $r_key, $r_display) = split(/\t/, $s_rel);

	my @from2 = ( "$r_name $r_alias" );
	my @where2 = ( );

	my %s_attrs = FuncUtil::getAdvSearchSetAttrs($class_name, $r_name);
	my @keys = keys %s_attrs;
	if ( scalar(@keys) == 0 ) {
	    next;
	}

	my $j;
	$sql2 = "";
	for ($j = 0; $j < $max_set_cond_count; $j++) {
	    # get each condition
	    my $attr_name = param ($r_name . ":attr_" . $j);
	    my $comp = param ($r_name . ":comp_" . $j);
	    my $val = param ($r_name . ":val_" . $j);

	    # print "<p>$attr_name, $comp, $val</p>\n";

	    # check
	    if ( blankStr($attr_name) || blankStr($comp) ) {
		next;
	    }
	    if ( $comp ne 'is null' && $comp ne 'is not null' &&
		 blankStr($val) ) {
		next;
	    }
	    if ( ! $s_attrs{$attr_name} ) {
		print "<p>Cannot find s_attrs for $attr_name.</p>\n";
		next;
	    }

	    my $attr_def = $s_attrs{$attr_name};
	    my ($disp_name, $t_name, $t_alias, $data_type, $cond) =
		split (/\t/, $attr_def);

	    # print "<p>$disp_name, $t_name, $t_alias, $data_type, $cond</p>\n";

	    # add to from2?
	    my $s2 = "$t_name $t_alias";
	    if ( ! WebUtil::inArray($s2, @from2) ) {
		push @from2, ( $s2 );
	    }
	    if ( !blankStr($cond) ) {
		push @where2, ( $cond );
	    }

	    # where
	    $val =~ s/^\s+//;
	    $val =~ s/\s+$//;
	    $s2 = "";
	    if ( $comp eq 'is null' || $comp eq 'is not null' ) {
		$s2 = "$attr_name $comp";
	    }
	    elsif ( $data_type eq 'int' || $data_type eq 'order' ) {
		$s2 = "$attr_name $comp $val";
		if ( ! isInt($val) || $comp eq 'match' ||
		     $comp eq 'not match' ) {
		    webError("Incorrect query condition: $disp_name $comp $val.");
		    return;
		}
	    }
	    elsif ( $data_type eq 'number' ) {
		$s2 = "$attr_name $comp $val";
		if ( ! isNumber($val) || $comp eq 'match' ||
		     $comp eq 'not match' ) {
		    webError("Incorrect query condition: $disp_name $comp $val.");
		    return;
		}
	    }
	    elsif ( $data_type eq 'char' || $data_type eq 'date' ) {
		$val =~ s/'/''/g;  # replace ' with ''
		if ( $comp eq 'match' ) {
		    $val = uc($val);
		    $s2 = "upper($attr_name) like '%" . $val . "%'";
		}
		elsif ( $comp eq 'not match' ) {
		    $val = uc($val);
		    $s2 = "upper($attr_name) not like '%" . $val . "%'";
		}
		else {
		    $s2 = "$attr_name $comp '$val'";
		}
	    }

	    # print "<p>s2: $s2</p>\n";

	    if ( !blankStr($s2) ) {
		push @where2, ( $s2 );
	    }
	}  # end for j loop

	if ( scalar(@where2) > 0 ) {
	    $sql2 = "select $r_alias.$r_key";
	    my $f2 = 1;
	    for my $s2 ( @from2 ) {
		if ( $f2 ) {
		    $f2 = 0;
		    $sql2 .= " from $s2";
		}
		else {
		    $sql2 .= ", $s2";
		}
	    }

	    $f2 = 1;
	    for my $s2 ( @where2 ) {
		if ( $f2 ) {
		    $f2 = 0;
		    $sql2 .= " where $s2";
		}
		else {
		    $sql2 .= " and $s2";
		}
	    }

	    # print "<p>SQL2: $sql2</p>\n";
	    if ( !blankStr($sql2) ) {
		push @subqueries, ( $sql2 );
	    }
	}
    }  # end r_sel loop

    # construct SQL
    my $is_first = 1;
    $sql = "select ";
    for my $s ( @selects ) {
	if ( $is_first ) {
	    $is_first = 0;
	}
	else {
	    $sql .= ", ";
	}
	$sql .= $s;
    }

    $is_first = 1;
    $sql .= " from ";
    for my $s ( @froms ) {
	if ( $is_first ) {
	    $is_first = 0;
	}
	else {
	    $sql .= ", ";
	}
	$sql .= $s;
    }

    $is_first = 1;
    for my $s ( @wheres ) {
	if ( $is_first ) {
	    $is_first = 0;
	    $sql .= " where ";
	}
	else {
	    $sql .= " and ";
	}
	$sql .= $s;
    }

    for my $sql2 ( @subqueries ) {
	if ( $is_first ) {
	    $is_first = 0;
	    $sql .= " where ";
	}
	else {
	    $sql .= " and ";
	}

	$sql .= "r0.$oid_attr in ( $sql2 )";
    }

    $sql .= " order by r0.$oid_attr";
    # print "<p>SQL: " . escapeHTML($sql) . "</p>\n";

    if ( blankStr($sql) ) {
	print end_form();
	return;
    }

    # database search
    my $dbh = dbLogin( );

    printStatusLine( "Loading ...", 1 );

    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    for( ;; ) {
        my @flds = $cur->fetchrow( );
	last if ( scalar(@flds) == 0 );

	my $result_oid = $flds[0];
	last if !$result_oid;

	$count++;

	if ( $count == 1 ) {
	    print "<h2>Select " . $display_name . "s</h2>\n";
	    print "<p>The following list shows all $display_name" .
		"s that statisfy the search condition.<br/>\n";
	    print "Click item(s) to add to Curation Cart.</p>\n";
	    print "<p>\n";

	    # show buttons
	    my $name = "_section_${section}_addToCuraCart";
	    print submit( -name => $name,
			  -value => "Add to Curation Cart", -class => "lgdefbutton" );
	    print nbsp( 1 );
	    print "<input type='button' name='selectAll' value='Select All' " .
		"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	    print nbsp( 1 );
	    print "<input type='button' name='clearAll' value='Clear All' " . 
		"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	    print nbsp( 1 );
	    my $name = "_section_${section}_index";
	    print submit( -name => $name,
			  -value => 'Cancel', -class => 'smbutton' );

	    print "<br/>\n";

	    print "<table class='img'>\n"; 
	    print "<th class='img'>Select</th>\n"; 
	    for my $s ( @displays ) {
		print "<th class='img'>$s</th>\n"; 
	    }
	    print "</tr>\n";
	}

	if ( $count > $max_item_count ) {
	    last;
	}

	# show this reaction
	$result_oid = FuncUtil::oidPadded($class_name, $result_oid);
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='search_id' value='$result_oid' />\n"; 
	print "</td>\n"; 

	for (my $j = 0; $j < scalar(@flds); $j++) {
	    my $f_val = $flds[$j];

	    if ( $j == 0 ) {
		$f_val = FuncUtil::oidPadded($class_name, $f_val);
		my $url = FuncUtil::getUrl($main_cgi, $class_name, $f_val);
		print "<td class='img'>" . alink( $url, $f_val ) . "</td>\n";
	    }
	    else {
		print "<td class='img'>" . escapeHTML($f_val) . "</td>\n";
	    }
	}
	print "<tr/>\n"; 
    }
    $cur->finish( );

    ###$dbh->disconnect();

    if ( $count == 0 ) {
        printStatusLine( "$count item(s) found.", 2 );
        webError( 'No ' . $display_name . 's satisfy the search condition.' );
        return;
    }
    else {
	print "</table>\n";
    }

    print "</p>\n";
    if ( $count > $max_item_count ) {
        printStatusLine( "Too many results. Only $max_item_count items displayed.", 2 );
    }
    else {
	printStatusLine( "$count item(s) found.", 2 );
    }

    # show buttons
    print "<br/><br/>\n";

    my $name = "_section_${section}_addToCuraCart";
    print submit( -name => $name,
		  -value => "Add to Curation Cart", -class => "lgdefbutton" );
    print nbsp( 1 );
    print "<input type='button' name='selectAll' value='Select All' " .
	"onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " . 
	"onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################ 
# printConfirmUpdateAssocForm - confirm update association
############################################################################ 
sub printConfirmUpdateAssocForm { 
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected in the Curation Cart.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and attribute definition
    my $class_name = FuncUtil::funcIdToClassName ($func_id);
    my $display_name = FuncUtil::funcIdToDisplayName ($func_id);
    my $assoc_type = FuncUtil::classNameToAssocType ($class_name);

    if ( blankStr($assoc_type) ) {
	webError ("No associations can be specified for $display_name.");
	return -1;
    }

    print "<h1>Confirm IMG $assoc_type Association Update Page</h1>\n"; 
 
    printMainForm( );

    ## Set parameters. 
    print hiddenVar( "section", $section );
    print hiddenVar( "func_id", $func_id );

    # show selected reactions
    my $func_name = param ('func_name');
    print "<h3>$display_name $obj_oid: $func_name</h3>\n";

    print "<p>The selected $display_name will be updated to include the following associations:</p>\n";

    # get association attribute definition
    my @assoc_attrs = FuncUtil::getAssocAttributes($class_name);
    if ( scalar(@assoc_attrs) == 0 ) {
	return;
    }

#    my @all_params = $query->param;
#    for my $p( @all_params ) {
#	print "<p>$p =>" . param($p) . "</p>\n";
#    }

    print "<table class='img'>\n"; 

    # table header
    for my $t ( @assoc_attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);
	    print "<th class='img'>$disp_name</th>\n"; 
    }
    print "</tr>\n";

    # table contents
    my @assoc_oids = param( 'assoc_oid' );
    my %update_data;
    my $err_msg = "";
    for my $assoc_oid ( @assoc_oids ) {
#	print "<th class='img'>$assoc_oid</th>\n";

	my $t_data = "$assoc_oid";

	for my $t ( @assoc_attrs ) {
	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) = split(/\t/, $t);
	    my $attr_val = param("$attr_name:$assoc_oid");

	    if ( $ed eq 'U' ) {
		my $url = FuncUtil::getUrl($main_cgi, $cl, $attr_val);
		print "<td class='img'>" . alink( $url, $attr_val ) . "</td>\n";
	    }
	    else {
		# input data checking
		if ( $data_type eq 'order' ) {
		    if ( blankStr($attr_val) || !isInt($attr_val) || $attr_val <= 0 ) {
			$err_msg = "$disp_name cannot be null, and must be a positive integer.";
		    }
		}
		elsif ( $data_type eq 'int' ) {
		    if ( !blankStr($attr_val) ) {
			if ( !isInt($attr_val) || $attr_val < 0 ) {
			    $err_msg = "$disp_name must be a positive integer or zero.";
			}
		    }
		}
		elsif ( $data_type eq 'number' ) {
		    if ( !blankStr($attr_val) ) {
			if ( !isNumber($attr_val) || $attr_val < 0 ) {
			    $err_msg = "$disp_name must be a positive number or zero.";
			}
		    }
		}

		if ( !blankStr($err_msg) ) {
		    print "<td class='img'><font color='red'>" . $attr_val . "</font></td>\n";
		    last;
		}
		else {
		    print "<td class='img'>" . $attr_val . "</td>\n";
		}

		$t_data .= "\t$attr_val";
	    }
	}

	print "</tr>\n";

	if ( !blankStr($err_msg) ) {
	    print "</table>\n";
	    webError($err_msg);
	    return -1;
	}

	$update_data{$assoc_oid} = $t_data;
    }

    print "</table>\n";

    # save data in hidden var
    for my $key (keys %update_data) {
	my $val = $update_data{$key};
	print hiddenVar( "update:$key", $val );
    }

    # additional messsage for term-reaction assoc
    if ( $class_name eq 'IMG_TERM' ) {
	print "<p>(Sub-cell localization value will be ignored for Catalyst.)</p>\n";
    }

    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbUpdateAssoc";
    print submit( -name => $name,
		  -value => "Update $assoc_type", -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}


############################################################################ 
# dbUpdateAssoc - perform database update for association
############################################################################ 
sub dbUpdateAssoc {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and attribute definition
    my $class_name = FuncUtil::funcIdToClassName ($func_id);
    my $table_name = FuncUtil::getAssocTable($class_name);
    my $table_key = FuncUtil::getAssocTableKey($class_name);
    if ( blankStr($class_name) || blankStr($table_name) ||
	 blankStr($table_key) ) {
	return -1;
    }

    my @assoc_attrs = FuncUtil::getAssocAttributes($class_name);
    if ( scalar(@assoc_attrs) == 0 ) {
	return -1;
    }

    my @sqlList;
    my $sql = "delete from $table_name where $table_key = $obj_oid";
    my $vals = "";
    push @sqlList, ( $sql );

    if ( $class_name eq 'IMG_TERM' ) {
	# one more deletion
	$sql = "delete from img_reaction_catalysts where catalysts = $obj_oid";
	push @sqlList, ( $sql );
    }

    my $query = WebUtil::getCgi();
    my $assoc_type = "";
    my @all_params = $query->param;
    for my $p( @all_params ) {
	if ( $p =~ /update/ ) {
	    my ($tag, $assoc_oid) = split (/\:/, $p);
#	    print "<p>$assoc_oid =>" . param($p) . "</p>\n";

	    my @t_data = split(/\t/, param($p));

	    my $i = 0;
	    $sql = "insert into $table_name ($table_key";
	    $vals = " values ($obj_oid";
	    for my $t ( @assoc_attrs ) {
		my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) =
		    split(/\t/, $t);
		if ( $ed eq 'N' ) {
		    # for display only
		    $i++;
		    next;
		}

		if ( $i >= scalar(@t_data) ) {
		    last;
		}

		if ( $data_type eq 'int' || $data_type eq 'order' ||
		    $data_type eq 'number' ) {
		    $sql .= ", $attr_name";
		    if ( blankStr($t_data[$i]) ) {
			$vals .= ", null";
		    }
		    else {
			$vals .= ", $t_data[$i]";
		    }
		}
		else {
		    my $s = $t_data[$i];
		    $s =~ s/'/''/g;  # replace ' with ''

		    # special case for IMG_TERM
		    if ( $class_name eq 'IMG_TERM' ) {
			if ( $s eq 'Substrate' ) {
			    $assoc_type = $s;
			    $s = 'LHS';
			}
			elsif ( $s eq 'Product' ) {
			    $assoc_type = $s;
			    $s = 'RHS';
			}
		    }

		    if ( $class_name eq 'IMG_TERM' && $s eq 'Catalyst' ) {
			$assoc_type = $s;
			$sql = "insert into img_reaction_catalysts (catalysts, rxn_oid";
		    }
		    elsif ( $class_name eq 'IMG_TERM' &&
			    $assoc_type eq 'Catalyst' &&
			    lc($attr_name) eq 'sub_cell_loc' ) {
			# ignore sub_cell_loc for Catalyst
		    }
		    else {
			$sql .= ", $attr_name";
			$vals .= ", '$s'";
		    }
		}

		$i++;
	    }

	    $sql .= ')' . $vals . ')';
	    push @sqlList, ( $sql );
	}  # update
    }

#    if ( scalar(@sqlList) > 0 ) {
#	for $sql ( @sqlList ) {
#	    print "<p>SQL: $sql</p>\n";
#	}
#    }

    # perform database update 
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 

    return $obj_oid;
}


############################################################################
# printFileUploadForm
############################################################################
sub printFileUploadForm {
    print "<h1>Upload Associations from File</h1>\n";

    my $file_type = param('file_type');
    if ( blankStr($file_type) ) {
	webError("No file type has been selected.");
	return;
    }

    # need a different ENCTYPE for file upload
    print start_form( -name => "mainForm",
		                        -enctype => "multipart/form-data",
		      -action => "$section_cgi" );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "file_type", $file_type );

    my $display_type = FuncUtil::getUploadDisplayType($file_type);
    print "<h2>File Type: $display_type</h2>\n";

    print "<p>The input file must satisfy the following requirements:</p>\n";
    print "<ul>\n";
    print "<li>Plain tab-delimited text file</li>\n";
    print "<li>No more than $max_upload_line_count lines</li>\n";

    if ( $file_type eq 'cr' ) {
	print "<li>File must contain the following fields: ";
	print "(1) IMG Compound Object ID, (2) IMG Reaction Object ID, (3) LHS or RHS, (4) Main: Yes or No, (5) Integer value for Stoichiometry.</li>\n";
    }
    elsif ( $file_type eq 'pt' ) {
	print "<li>File must contain the following fields: ";
	print "(1) IMG Parts List OID, (2) IMG Term OID, (3) Order</li>\n";
    }
    elsif ( $file_type eq 'pr' ) {
	print "<li>File must contain the following fields: ";
	print "(1) IMG Pathway OID, (2) IMG Reaction OID, (3) Mandatory?: 'Yes' or 'No', (4) Reaction Order</li>\n";
    }
    elsif ( $file_type eq 'tr' ) {
	print "<li>File must contain the following fields: ";
	print "(1) IMG Term OID, (2) IMG Reaction OID, (3) Association Type: 'Catalyst', 'Substrate', or 'Product'</li>\n";
    }
    print "</ul>\n";

    print "</p>\n";

    print "File Name: ";
    print nbsp( 1 );
    print "<input type='file' id='fileselect' name='fileselect' size='100' />\n";

    print "<p>\n";
    print "Mode: ";
    print nbsp( 1 );
    print "<input type='radio' name='upload_ar' value='add' checked />Add\n";
    print nbsp( 1 );
    print "<input type='radio' name='upload_ar' value='replace' />Replace\n";
    print "</p>\n";

    # set buttons
    print "<p>\n";
    my $name = "_section_${section}_validateFile";
    print submit( -name => $name,
		  -value => 'Open', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}

############################################################################
# printValidateFileForm - validate file before uploading
############################################################################
sub printValidateFileForm {
    print "<h1>File Validation Result</h1>\n";

    printMainForm( );

    my $file_type = param( 'file_type' );
    if ( blankStr($file_type) ) {
	webError("No file type is selected.");
	return;
    }

    my $display_type = FuncUtil::getUploadDisplayType($file_type);

    my $filename = param( "fileselect" );

    if ( blankStr($filename) ) {
	webError("No file name is provided.");
	return;
    }

    # add or replace?
    my $replace = 0;
    if ( param( "upload_ar" ) eq "replace" ) {
	$replace = 1;
    }

    print "<h2>$display_type File Name: $filename  (Mode: " .
	param( "upload_ar" ) . ")</h2>\n";
    print "<p>\n"; # paragraph section puts text in proper font.

    print "<p><font color=\"red\"> ";
    print "Warning: All data rows that have errors " .
	"will not be loaded. </font></p>\n";

    # tmp file name for file upload
    # need to explicitly spell out the file name, otherwise taint error
    my $sessionId = getSessionId( );
    my $tmp_upload_file = $cgi_tmp_dir . "/upload." . $sessionId . ".txt";
    if ( $file_type eq 'cr' ) {
	$tmp_upload_file = $cgi_tmp_dir . "/upload.cr." . $sessionId . ".txt";
    }
    elsif ( $file_type eq 'pt' ) {
	$tmp_upload_file = $cgi_tmp_dir . "/upload.pt." . $sessionId . ".txt";
    }
    elsif ( $file_type eq 'pr' ) {
	$tmp_upload_file = $cgi_tmp_dir . "/upload.pr." . $sessionId . ".txt";
    }
    elsif ( $file_type eq 'tr' ) {
	$tmp_upload_file = $cgi_tmp_dir . "/upload.tr." . $sessionId . ".txt";
    }

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "file_type", $file_type );
    print hiddenVar( "tmpUploadFile", $tmp_upload_file);
    print hiddenVar( "uploadMode", $replace);

    # get upload file attributes
    my @attrs = FuncUtil::getUploadAttributes($file_type);
    if ( scalar(@attrs) == 0 ) {
	return;
    }

    # save the uploaded file to a tmp file, because we need to parse the file
    # more than once
    if ( ! open( FILE, '>', $tmp_upload_file ) ) {
        webError( "Cannot open tmp file $tmp_upload_file.");
	return;
    }

    # show message
    printStatusLine( "Validating ...", 1 );

    my $line_no = 0;
    my $line;
    while ($line = <$filename>) {
	# we don't want to process large files
	if ( $line_no <= $max_upload_line_count ) {
	    print FILE $line;
	}

	$line_no++;
    }
    close (FILE);

    ## buttons
    my $name = "_section_${section}_dbFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    # print table header
    print "<table class='img'>\n";
    print "<th class='img'>Line No.</th>\n";
    for my $attr ( @attrs ) {
	my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) =
	    split(/\t/, $attr);
	print "<th class='img'>$disp_name</th>\n";
    }
    print "<th class='img'>Message</th>\n";

    # now read from tmp file
    if ( ! open( FILE, $tmp_upload_file ) ) {
	printStatusLine( "Failed.", 2 );
        webError( "Cannot open tmp file $tmp_upload_file.");
	return;
    }

    my $tname = FuncUtil::getUploadTable($file_type);
    my $attr1 = FuncUtil::getUploadAttr1($file_type);
    my $attr2 = FuncUtil::getUploadAttr2($file_type);

    my $dbh = dbLogin( );
    $line_no = 0;
    while ($line = <FILE>) {
	chomp($line);
	my @flds = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	my $msg = "";

	print "<tr class='img'>\n";
	print "<td class='img'>" . $line_no . "</td>\n";

	my $j = 0;
	for my $fld ( @flds ) {
	    # remove quotes, leading and trailing blanks
	    $fld = strTrim($fld);
	    if ( $fld =~ /^\s*"(.*)"$/ ) {
		($fld) = ($fld =~ /^\s*"(.*)"$/);
		$fld = strTrim($fld); 
	    } 

	    # get attribute definition
	    my $attr = '';
	    if ( $j < scalar(@attrs) ) {
		$attr = $attrs[$j];
	    }
	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) =
		split(/\t/, $attr);

	    if ( $ed eq 'U' ) {
		# oid and url
		if ( blankStr($fld) ) {
		    $msg .= "Error: $disp_name is blank. ";
		    print "<td class='img'>" . $fld . "</td>\n";
		}
		elsif ( isInt($fld) ) {
		    my $cl_key = FuncUtil::getOidAttr($cl);
		    my $cnt1 = 0;
		    if ( !blankStr($cl_key) ) {
			$cnt1 = db_findCount ($dbh, $cl, "$cl_key = $fld");
			if ( $cnt1 <= 0 ) {
			    $msg .= "Error: $disp_name '$fld' does not exist. ";
			    print "<td class='img'>" . $fld . "</td>\n";
			}
			else {
			    # show URL
			    $fld = FuncUtil::oidPadded($cl, $fld);
			    my $url = FuncUtil::getUrl($main_cgi, $cl, $fld);
			    print "<td class='img'>" . alink( $url, $fld ) . "</td>\n";
			}
		    }
		}
		else {
		    $msg .= "Error: $disp_name must be an integer. ";
		    print "<td class='img'>" . $fld . "</td>\n";
		}
	    }
	    else {
		# data type checking
		if ( blankStr($fld) ) {
		    if ( $ed eq 'R' ) {
			# required
			$msg .= "Error: $disp_name cannot be null. ";
		    }
		}
		elsif ( $data_type eq 'order' ) {
		    if ( !isInt($fld) || $fld <= 0 ) {
			$msg .= "Error: $disp_name must be a positive integer. ";
		    }
		}
		elsif ( $data_type eq 'int' ) {
		    if ( !isInt($fld) || $fld < 0 ) {
			$msg .= "Error: $disp_name must be a positive integer or zero. ";
		    }
		}
		elsif ( $data_type eq 'number' ) {
		    if ( !isNumber($fld) || $fld < 0 ) {
			$msg .= "Error: $disp_name must be a positive number or zero. ";
		    }
		}
		elsif ( $data_type =~ /\|/ ) {
		    # selection
		    my @selections = split (/\|/, $data_type);
		    my $found = 0;
		    for my $s2 ( @selections ) {
			if ( uc($s2) eq uc($fld) ) {
			    $found = 1;
			    last;
			}
		    }

		    if ( ! $found ) {
			$msg .= "Error: $disp_name must be in '$data_type'. ";
		    }
		}

		print "<td class='img'>" . escapeHTML($fld) . "</td>\n";
	    }

	    $j++;
	}

	while ( $j < scalar(@attrs) ) {
	    # pad blank fields
	    print "<td class='img'></td>\n";
	    $j++;
	}

	# check whether association already exists (for add mode)
	if ( $msg =~ /Error/ ) {
	    # already have error - no need to check
	}
	elsif ( $replace == 0 ) {
	    # add mode
	    my $cnt1 = 0;
	    my $id1 = 0;
	    if ( scalar(@flds) > 0 && isInt($flds[0]) ) {
		$id1 = $flds[0];
	    }
	    my $id2 = 0;
	    if ( scalar(@flds) > 1 && isInt($flds[1]) ) {
		$id2 = $flds[1];
	    }

	    if ( $file_type eq 'tr' ) {
		# special treatment for term - reaction???
		my $assoc_type = '';
		if ( scalar(@flds) > 2 ) {
		    $assoc_type = $flds[2];
		    if ( lc($assoc_type) eq 'catalyst' ) {
			$cnt1 = db_findCount($dbh, 'IMG_REACTION_CATALYSTS',
					     "catalysts = $id1 and rxn_oid = $id2");
		    }
		    else {
			$cnt1 = db_findCount($dbh, 'IMG_REACTION_T_COMPONENTS',
					     "term = $id1 and rxn_oid = $id2");
		    }
		}
	    }
	    else {
		$cnt1 = db_findCount($dbh, $tname,
				     "$attr1 = $id1 and $attr2 = $id2");
	    }

	    if ( $cnt1 > 0 ) {
		$msg .= "Error: $display_type association already exists. ";
	    }
	}

	# show error or warning?
	if ( $msg =~ /Error/ ) {
	    print "<td class='img'><font color='red'>" . escapeHTML( $msg ) .
		"</font></td>\n";
	}
	else {
	    print "<td class='img'>" . escapeHTML( $msg ) . "</td>\n";
	}

	print "</tr>\n";
    }

    print "</table>\n";
    print "<br/>\n";

    ###$dbh->disconnect();

    close (FILE);

    if ( $line_no >= $max_upload_line_count ) {
	printStatusLine( "File is too large. Only $max_upload_line_count lines were processed.", 2 );
    }
    else {
	printStatusLine( "Done.", 2 );
    }

    ## buttons
    my $name = "_section_${section}_dbFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print end_form( );
}


############################################################################
# dbFileUpload - handle the actual data upload
############################################################################
sub dbFileUpload {
    ## Get parameters.
    my $file_type = param( "file_type" );
    my $tmp_upload_file = param( "tmpUploadFile" );
    my $replace = param( "uploadMode" );

    # get upload file attributes
    my @attrs = FuncUtil::getUploadAttributes($file_type);
    if ( scalar(@attrs) == 0 ) {
	return;
    }

    # open file
    if ( ! open( FILE, $tmp_upload_file ) ) {
        webError( "Cannot open tmp file $tmp_upload_file.");
	return 0;
    }

    my $tname = FuncUtil::getUploadTable($file_type);
    my $attr1 = FuncUtil::getUploadAttr1($file_type);
    my $attr2 = FuncUtil::getUploadAttr2($file_type);

    my $dbh = dbLogin( );
    my @sqlList = ( );
    my $sql;
    my $ins1;
    my $ins2;

    my @oids_1;
    my @oids_2;

    my $line_no = 0;
    my $line;
    my $has_err = 0;
    while ($line = <FILE>) {
	chomp($line);
	my @flds = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	$has_err = 0;
	$ins1 = "insert into $tname (";
	$ins2 = " values (";

	my $j = 0;
	for my $fld ( @flds ) {
	    # remove quotes, leading and trailing blanks
	    $fld = strTrim($fld);
	    if ( $fld =~ /^\s*"(.*)"$/ ) {
		($fld) = ($fld =~ /^\s*"(.*)"$/);
		$fld = strTrim($fld); 
	    } 

	    # get attribute definition
	    my $attr = '';
	    if ( $j < scalar(@attrs) ) {
		$attr = $attrs[$j];
	    }

	    my ($attr_name, $disp_name, $data_type, $size, $ed, $cl) =
		split(/\t/, $attr);

	    if ( $ed eq 'U' ) {
		# oid and url
		if ( blankStr($fld) ) {
		    $has_err = 1;
		    last;
		}
		elsif ( isInt($fld) ) {
		    my $cl_key = FuncUtil::getOidAttr($cl);
		    my $cnt1 = 0;
		    if ( !blankStr($cl_key) ) {
			$cnt1 = db_findCount ($dbh, $cl, "$cl_key = $fld");
			if ( $cnt1 <= 0 ) {
			    $has_err = 1;
			    last;
			}
		    }
		}
		else {
		    $has_err = 1;
		    last;
		}
	    }
	    else {
		# data type checking
		if ( blankStr($fld) ) {
		    if ( $ed eq 'R' ) {
			# required
			$has_err = 1;
			last;
		    }
		}
		elsif ( $data_type eq 'order' ) {
		    if ( !isInt($fld) || $fld <= 0 ) {
			$has_err = 1;
			last;
		    }
		}
		elsif ( $data_type eq 'int' ) {
		    if ( !isInt($fld) || $fld < 0 ) {
			$has_err = 1;
			#last;
		    }
		}
		elsif ( $data_type eq 'number' ) {
		    if ( !isNumber($fld) || $fld < 0 ) {
			$has_err = 1;
			#last;
		    }
		}
		elsif ( $data_type =~ /\|/ ) {
		    # selection
		    my @selections = split (/\|/, $data_type);
		    my $found = 0;
		    for my $s2 ( @selections ) {
			if ( uc($s2) eq uc($fld) ) {
			    $found = 1;
			    $fld = $s2;  # change to proper case
			    last;
			}
		    }

		    if ( ! $found ) {
			$has_err = 1;
			last;
		    }
		}
	    }

	    if ( $j > 0 ) {
		$ins1 .= ", ";
		$ins2 .= ", ";
	    }

	    $ins1 .= $attr_name;
	    if ( $ed eq 'U' || $data_type eq 'order' || 
		 $data_type eq 'int' || $data_type eq 'number' ) {
		if ( blankStr($fld) ) {
		    $ins2 .= "null";
		}
		else {
		    $ins2 .= $fld;
		}
	    }
	    else {
		my $s2 = $fld;
		$s2 =~ s/'/''/g;  # replace ' with ''
		$ins2 .= "'$s2'";
	    }

	    $j++;
	}

	if ( $has_err ) {
	    next;
	}

	# check whether association already exists
	my $id1 = 0;
	if ( scalar(@flds) > 0 && isInt($flds[0]) ) {
	    $id1 = $flds[0];
	}
	my $id2 = 0;
	if ( scalar(@flds) > 1 && isInt($flds[1]) ) {
	    $id2 = $flds[1];
	}

	if ( $id1 == 0 || $id2 == 0 ) {
	    next;
	}

	my $cnt1 = db_findCount($dbh, $tname,
				"$attr1 = $id1 and $attr2 = $id2");

	# generate SQL delete statement
	# (note that we only want to generate one delete statement per oid
	if ( $replace ) {
	    # replace mode
	    if ( WebUtil::inIntArray($id1, @oids_1) ) {
		# already generate delete statement
		# do nothing here
	    }
	    else {
		if ( $file_type eq 'tr' ) {
		    # special treatment for term - reaction
		    $sql = "delete from IMG_REACTION_T_COMPONENTS where term = $id1";
		    push @sqlList, ( $sql );
		    $sql = "delete from IMG_REACTION_CATALYSTS where catalysts = $id1";
		    push @sqlList, ( $sql );
		}
		else {
		    $sql = "delete from $tname where $attr1 = $id1";
		    push @sqlList, ( $sql );
		}
	    }
	}
	else {
	    # add mode
	    if ( $cnt1 > 0 ) {
		#duplicate entry
		next;
	    }
	}

	# save ids to be add to carts
	push @oids_1, ( $id1 );
	push @oids_2, ( $id2 );

	# generate SQL insert statements
	if ( $file_type eq 'tr' ) {
	    # special treatment for term - reaction
	    my $assoc_type = '';
	    if ( scalar(@flds) > 2 ) {
		$assoc_type = $flds[2];
	    }

	    if ( lc($assoc_type) eq 'catalyst' ) {
		$sql = "insert into IMG_REACTION_CATALYSTS (rxn_oid, catalysts) ";
		$sql .= "values ($id2, $id1)";
		push @sqlList, ( $sql );
	    }
	    elsif ( lc($assoc_type) eq 'substrate' ||
		    lc($assoc_type) eq 'product' ) {
		$sql = "insert into IMG_REACTION_T_COMPONENTS (rxn_oid, term, c_type) ";
		$sql .= "values ($id2, $id1, ";
		if ( lc($assoc_type) eq 'substrate' ) {
		    $sql .= "'LHS')";
		}
		else {
		    $sql .= "'RHS')";
		}
		push @sqlList, ( $sql );
	    }
	}
	else {
	    $sql = $ins1 . ')' . $ins2 . ')';
	    push @sqlList, ( $sql );
	}
    }

    ###$dbh->disconnect();

    close (FILE);

    # perform database update and update curation cart contents
#    for $sql ( @sqlList ) {
#	print "<p>SQL: $sql</p>\n";
#    }

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }


    # update carts
    my $cname1;
    my $cname2;

    if ( $file_type eq 'cr' ) {
	$cname1 = 'IMG_COMPOUND';
	$cname2 = 'IMG_REACTION';
    }
    elsif ( $file_type eq 'pt' ) {
	$cname1 = 'IMG_PARTS_LIST';
	$cname2 = 'IMG_TERM';
    }
    elsif ( $file_type eq 'pr' ) {
	$cname1 = 'IMG_PATHWAY';
	$cname2 = 'IMG_REACTION';
    }
    elsif ( $file_type eq 'tr' ) {
	$cname1 = 'IMG_TERM';
	$cname2 = 'IMG_REACTION';
    }

    if ( scalar(@oids_1) ) {
	addToCurationCart ($cname1, \@oids_1);
    }

    if ( scalar(@oids_2) ) {
	addToCurationCart ($cname2, \@oids_2);
    }
}


############################################################################
# printConfirmDeleteForm - ask user to confirm deletion
############################################################################
sub printConfirmDeleteForm {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected for deletion.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and class info
    my $class_name = FuncUtil::funcIdToClassName($func_id);
    my $display_name = FuncUtil::classNameToDisplayName($class_name);

    print "<h1>Delete $display_name Page</h1>\n";

    printMainForm( );

    ## Set parameters.
    print hiddenVar( "func_id", $func_id );

    print "<h2>$display_name $obj_oid</h2>\n";

    my @del_tables = FuncUtil::getDeleteTables ($class_name);

    if ( scalar(@del_tables) == 0 ) {
	return;
    }

    if ( scalar(@del_tables) > 1 ) {
	print "<p><font color=\"red\"> ";
	print "Warning: The following $display_name associations ".
	    "will be deleted as well.</font></p>\n";
    }

    my $dbh = dbLogin();

    for my $t ( @del_tables ) {
	my ($tbl1, $label, $a1, $tbl2, $a2, $order_attr) =
	    split (/\t/, $t);
	if ( blankStr($label) ) {
	    next;
	}
	print "<h3>$label Association to be Deleted:</h3>\n";

	my ($attr1, $disp1) = split (/:/, $a1);
	if ( blankStr($disp1) ) {
	    $disp1 = $attr1;
	}
	my ($attr2, $disp2) = split (/:/, $a2);
	if ( blankStr($disp2) ) {
	    $disp2 = $attr2;
	}

	print "<table class='img'>\n";
	print "<th class='img'>$disp1</th>\n";
	print "<th class='img'>$disp2</th>\n";

	my $sql = "select $attr1, $attr2 from $tbl1 where $attr1 = $obj_oid";
	if ( !blankStr($order_attr) ) {
	    $sql .= " order by $order_attr";
	}

	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $id1, $id2 ) = $cur->fetchrow( );
	    last if !$id1;

	    $id1 = FuncUtil::oidPadded($class_name, $id1);
	    $id2 = FuncUtil::oidPadded($tbl2, $id2);

	    print "<tr class='img'>\n";
	    my $url = FuncUtil::getUrl($main_cgi, $class_name, $id1);
	    if ( !blankStr($url) ) {
		print "<td class='img'>" . alink( $url, $id1 ) . "</td>\n";
	    }
	    else {
		print "<td class='img'>" . escapeHTML($id1) . "</td>\n";
	    }
	    $url = FuncUtil::getUrl($main_cgi, $tbl2, $id2);
	    if ( !blankStr($url) ) {
		print "<td class='img'>" . alink( $url, $id2 ) . "</td>\n";
	    }
	    else {
		print "<td class='img'>" . escapeHTML($id2) . "</td>\n";
	    }
	}
	$cur->finish( );

	print "</table>\n";
    }

    ###$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbDeleteItem";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n"; # paragraph section puts text in proper font.
}

############################################################################
# dbDeleteItem - delete from database
############################################################################
sub dbDeleteItem {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected for deletion.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and class info
    my $class_name = FuncUtil::funcIdToClassName($func_id);

    # prepare SQL
    my @sqlList = ();
    my $sql;

    my @del_tables = FuncUtil::getDeleteTables ($class_name);

    if ( scalar(@del_tables) == 0 ) {
	return -1;
    }

    for my $t ( @del_tables ) {
	my ($tbl1, $label, $a1, $tbl2, $a2, $order_attr) =
	    split (/\t/, $t);

	my ($attr1, $disp1) = split (/:/, $a1);
	my ($attr2, $disp2) = split (/:/, $a2);

	$sql = "delete from $tbl1 where $attr1 = $obj_oid";
	push @sqlList, ( $sql );
    }

#    if ( scalar(@sqlList) > 0 ) {
#	for $sql (@sqlList) {
#	    print "<p>SQL: $sql</p>\n";
#	}
#	return -1;
#    }

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        $sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $obj_oid;
    }
}


############################################################################
# dbMergeTerm - merge terms in the database
############################################################################
sub dbMergeTerm {
    # get selected oid
    my $func_id = param ('func_id');
    if ( blankStr($func_id) ) {
	webError ("No item is selected for merging.");
	return -1;
    }
    my ($tag, $obj_oid) = split (/:/, $func_id);

    # get class name and class info
    my $class_name = FuncUtil::funcIdToClassName($func_id);
    if ( $class_name ne 'IMG_TERM' ) {
	webError ("Selected object is not an IMG term.");
	return -1;
    }

    print "<p>Term: $obj_oid</p>\n";

    my @mergedTerms = param('term_oid');
    my $m_list = "";
    for my $m0 ( @mergedTerms ) {
	print "<p>*** $m0</p>\n";
	my ($t_oid, $rest) = split(/\:/, $m0);

	if ( length($m_list) == 0 ) {
	    $m_list = $t_oid;
	}
	else {
	    $m_list .= ", " . $t_oid;
	}
    }
    print "<p>M terms: $m_list</p>\n";

    if ( scalar(@mergedTerms) == 0 ) {
	webError("No terms have been selected for merging.");
    }
    elsif ( scalar(@mergedTerms) > 1000 ) {
	webError("Too many terms have been selected. Maximum is 1000.");
    }

    # prepare SQL
    my @sqlList = ();
    my $sql;

    # update img_term_synonyms
    $sql = qq{
	insert into img_term_synonyms (term_oid, synonyms, add_date,
				       modified_by)
	    select $obj_oid, its1.synonyms, sysdate, $contact_oid
	    from img_term_synonyms its 1
	    where its1.term_oid in ($m_list )
	    minus select its2.term_oid, its2.synonyms, sysdate, $contact_oid
	    from img_term_synonyms its2
	    where its2.term_oid = $obj_oid
	};
    push @sqlList, ( $sql );

    # update img_term_enzymes
    $sql = qq{
	insert into img_term_enzymes (term_oid, enzymes)
	    select $obj_oid, ite1.enzymes
	    from img_term_enzymes ite1
	    where ite1.term_oid in ($m_list )
	    minus select ite2.term_oid, ite2.enzymes
	    from img_term_enzymes ite2
	    where ite2.term_oid = $obj_oid
	};
    push @sqlList, ( $sql );

    # delete merged terms
    my @del_tables = FuncUtil::getDeleteTables ($class_name);

    if ( scalar(@del_tables) == 0 ) {
	return -1;
    }

    for my $t ( @del_tables ) {
	my ($tbl1, $label, $a1, $tbl2, $a2, $order_attr) =
	    split (/\t/, $t);

	my ($attr1, $disp1) = split (/:/, $a1);
	my ($attr2, $disp2) = split (/:/, $a2);

	$sql = "delete from $tbl1 where $attr1 in (" . $m_list . ")";
	push @sqlList, ( $sql );
    }

    if ( scalar(@sqlList) > 0 ) {
	for $sql (@sqlList) {
	    print "<p>SQL: $sql</p>\n";
	}
	return -1;
    }

    # perform database update
#    my $err = db_sqlTrans( \@sqlList );
    my $err = 0;
    if ( $err ) {
        $sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $obj_oid;
    }
}



1;
