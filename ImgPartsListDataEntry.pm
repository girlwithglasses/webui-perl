############################################################################
# ImgPartsListDataEntry.pm - 
#   Data entry through ImgPartsListCart entry point.
#   --imachen 03/20/2007
############################################################################
package ImgPartsListDataEntry;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use DataEntryUtil;
use FuncUtil;
use FuncCartStor;
use ImgPartsListCartStor;
use ImgTermCartStor;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };

my $section = "ImgPartsListDataEntry";
my $section_cgi = "$main_cgi?section=$section";

my $contact_oid = getContactOid( );

my $max_count = 200;
my $max_upload_line_count = 10000;



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
    elsif( paramMatch( "addPartsListForm" ) ) {
        printAddUpdatePartsListForm( 0 );
    }
    elsif( paramMatch( "dbAddPartsList" ) ne "" ) {
	my $new_oid = dbAddPartsList();
	if ( $new_oid > 0 ) {
	        # add new oids to function cart
	    my $fc = new FuncCartStor( ); 
	    my @plist_oids = param( "parts_list_oid" );
	    push @plist_oids, ( $new_oid );
	    $fc->addImgPartsListBatch( \@plist_oids );
	}

	# add to parts list cart too
        if ( $new_oid > 0 ) {
            my $ipc = new ImgPartsListCartStor( );
            my @plist_oids = param( "plist_oid" );
            push @plist_oids, ( $new_oid );
            $ipc->addImgPartsListBatch( \@plist_oids );
        } 

	# go to the index page
	$page = "index";
    }
    elsif( paramMatch( "updatePartsListForm" ) ) {
        printAddUpdatePartsListForm( 1 );
    }
    elsif( paramMatch( "dbUpdatePartsList" ) ne "" ) {
        my $old_oid = dbUpdatePartsList();
 
        if ( $old_oid > 0 ) { 
            # update parts list info
            my $fc = new FuncCartStor( ); 
            my @pway_oids = ( $old_oid ); 
            $fc->addImgPartsListBatch( \@pway_oids );
        }

	# update parts list cart too
        if ( $old_oid > 0 ) {
            my $ipc = new ImgPartsListCartStor( );
            my @plist_oids = ( $old_oid );
            $ipc->addImgPartsListBatch( \@plist_oids );
        } 

	# go to the index page
	$page = "index";
    } 
    elsif( paramMatch( "confirmDeletePartsListForm" ) ne "" ) {
	printConfirmDeletePartsListForm( );
    }
    elsif( paramMatch( "dbDeletePartsList" ) ne "" ) {
	my $old_oid = dbDeletePartsList();
	if ( $old_oid > 0 ) {
	    my $fc = new FuncCartStor( ); 
	    my $recs = $fc->{ recs }; # get records 
	    my $selected = $fc->{ selected };
	    my $func_id = "PLIST:" . FuncUtil::partsListOidPadded($old_oid);
	    delete $recs->{ $func_id };
	    delete $selected->{ $func_id };
	    $fc->save( );
	}

	# delete from parts list cart too
        if ( $old_oid > 0 ) {
            my $ipc = new ImgPartsListCartStor( );
            my $recs = $ipc->{ recs }; # get records
            my $selected = $ipc->{ selected };
            delete $recs->{ $old_oid };
            delete $selected->{ $old_oid };
            $ipc->save( ); 
        } 

	# go to index page
	$page = "index";
    }
    elsif( paramMatch( "updatePartsListTermForm" ) ne "" ) {
        printUpdatePartsListTermForm( 0 );
    }
    elsif( paramMatch( "addPartsListTerm" ) ne "" ) {
        printUpdatePartsListTermForm( 1 );
    }
    elsif( paramMatch( "searchTermResults" ) ne "" ) {
	printSearchTermResults();
    }
    elsif( paramMatch( "partsListTermAssignment" ) ne "" ) {
        printUpdatePartsListTermForm( 2 );
    }
    elsif( paramMatch( "confirmUpdatePartsListTerm" ) ne "" ) {
	printConfirmUpdatePartsListTermForm( );
    }
    elsif( paramMatch( "dbUpdatePListTerm" ) ne "" ) {
	# perform database update
	dbUpdatePListTerm();

	# go to the index page
	$page = "index";
    } 
    elsif ( paramMatch ( "fileUploadPListTermForm" ) ) {
	printFileUploadPListTermForm();
    }
    elsif ( paramMatch ( "validatePListTermFile" ) ) {
	printValidatePListTermForm();
    }
    elsif ( paramMatch( "dbPListTermFileUpload" ) ne "" ) {
	# perform actual upload
	dbPListTermFileUpload();

	# show index page
	$page = "index";
    }

    if ( $page eq "index" ) {
        printIndex( ); 
    } 
    elsif ( $page eq "" ) {
        # do nothing
    } 
    else { 
        # printIndex( );
        print "<h1>Incorrect Page: $page</h1>\n"; 
    } 
}


############################################################################
# printIndex - Show main index page.
############################################################################
sub printIndex {
   print "<h1>IMG Parts List Curation Page</h1>\n";

   print "<meta http-equiv=\"norefresh\">\n";
 
   printMainForm( );

   print "<p>\n"; # paragraph section puts text in proper font.
 
   print "<h3>Note: This page only allows single IMG parts list selection.</h3>\n";
 
   print "<table class='img'>\n";
 
   print "<th class='img'>Select</th>\n";
   print "<th class='img'>Parts List<br/>OID</th>\n";
   print "<th class='img'>Parts List Name</th>\n";
   print "<th class='img'>Batch</th>\n";

   my $cart = new ImgPartsListCartStor( ); 
   my $recs = $cart->{ recs }; 
   my @plist_oids = sort( keys( %$recs ) ); 
   my @selected_plist_oids = param( "parts_list_oid" );
   my %selectedPlistOids; 
   for my $plist_oid( @selected_plist_oids ) {
       $selectedPlistOids{ $plist_oid } = 1;
   } 

   for my $plist_oid( @plist_oids ) { 
       my $r = $recs->{ $plist_oid };
       my( $plist_oid, $plist_name, $batch_id ) = split( /\t/, $r );
       $plist_oid = FuncUtil::partsListOidPadded( $plist_oid );  # make even sized
 
       print "<tr class='img'>\n";
 
       print "<td class='img'>\n";
       print "<input type='radio' "; 
       print "name='parts_list_oid' value='$plist_oid'/>\n"; 

       print "</td>\n";
 
       my $url = "$main_cgi?section=ImgPartsListBrowser" .
	   "&page=partsListDetail&parts_list_oid=$plist_oid"; 

       print "<td class='img'>" . alink( $url, $plist_oid ) . "</td>\n";
 
       print "<td class='img'>" . escHtml( $plist_name ) . "</td>\n";
       print "<td class='img'>$batch_id</td>\n";
 
       print "</tr>\n"; 
   } 
 
   print "</table>\n"; 
 
    ## Set parameters. 
   print hiddenVar( "section", $section ); 
 
   # add New, Delete and Update IMG Parts List button 
   print "<br/>\n"; 
   my $name = "_section_${section}_addPartsListForm"; 
    print submit( -name => $name, 
                  -value => 'New IMG Parts List', -class => 'meddefbutton' ); 
   print nbsp( 1 ); 
   my $name = "_section_${section}_confirmDeletePartsListForm"; 
    print submit( -name => $name, 
                  -value => 'Delete IMG Parts List', -class => 'medbutton' ); 
   print nbsp( 1 ); 
   my $name = "_section_${section}_updatePartsListForm";
    print submit( -name => $name,
                  -value => 'Update IMG Parts List', -class => 'medbutton' );

    # add Update Terms buttons
    print "<h3>Parts List - Term Curation</h3>\n";
    print "<p>Update (or delete) IMG terms associated with the selected parts list.</p>\n";

    my $name = "_section_${section}_updatePartsListTermForm"; 
    print submit( -name => $name, 
		  -value => 'Update Terms', -class => 'medbutton' ); 

   print "<h3>Add Terms from IMG Term Cart</h3>\n";
   print "<p>Associate terms in the IMG Term Cart to the selected parts list.</p>\n";
   my $name = "_section_${section}_addPartsListTerm";
   print submit( -name => $name,
		 -value => 'Associate Terms', -class => 'medbutton' );

   print "<h3>Search Terms to Add to Parts List</h3>\n";
   print "<p>Enter a keyword to search existing terms to the selected parts list. Use % for wildcard.</p>\n";
   print "<input type='text' name='searchTerm' size='80' />\n";
   print "<br/>\n";

   my $name = "_section_${section}_searchTermResults";
   print submit( -name => $name,
		  -value => 'Search Terms', -class => 'medbutton' );

   print end_form( ); 
}

############################################################################
# printAddUpdatePartsListForm - add or update IMG parts list
############################################################################
sub printAddUpdatePartsListForm {
    my ( $update ) = @_;   # add or update

    if ( $update ) {
	print "<h1>Update IMG Parts List Page</h1>\n";
    }
    else {
	print "<h1>Add IMG Parts List Page</h1>\n";
    }

    printMainForm( );

    # get the select parts list information
    my $ipc = new ImgPartsListCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @plist_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected parts list oids 
    my @selected_plist_oids = param( "parts_list_oid" ); 
    my %selected_plist_oids_h; 
    for my $plist_oid( @selected_plist_oids ) { 
        $selected_plist_oids_h{ $plist_oid } = 1;
    } 
 
    ## Set parameters.
    print hiddenVar( "section", $section );
 
    # get selected parts list oids 
    # save parts list selections in a hidden variable 
    print "<input type='hidden' name='selectedPList' value='";
    for my $plist_oid ( @selected_plist_oids ) {
        print "$plist_oid "; 
    } 
    print "'>\n"; 

    my $plist_oid = -1; 
    if ( $update ) {
	if ( scalar (@selected_plist_oids) > 0 ) { 
	    $plist_oid = $selected_plist_oids[0]; 
	} 
	else { 
	    webError ("No IMG parts list is selected.");
	    return; 
	} 
    }

    # add Add/Update, Reset and Cancel buttons
    if ( $update ) {
        my $name = "_section_${section}_dbUpdatePartsList";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddPartsList";
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

    # get parts list info from the database
    my $db_oid = "";
    my $db_name = ""; 
    my $db_def = "";

    if ( $update ) {
	my $dbh = dbLogin( ); 
	my $sql = qq{ 
	        select ipl.parts_list_oid, ipl.parts_list_name, ipl.definition
		    from img_parts_list ipl
		    where ipl.parts_list_oid = ? 
		}; 
 
	my $cur = execSql( $dbh, $sql, $verbose, $plist_oid ); 
	($db_oid, $db_name, $db_def) = $cur->fetchrow( ); 
	$cur->finish( ); 
    }

    print "<h2>Parts List Information</h2>\n";

    if ( $update ) {
	$plist_oid = FuncUtil::partsListOidPadded ( $plist_oid );  # make even sized
	print "<h4>Parts List OID: $plist_oid</h4>\n";
    }

    print "<table class='img' border='1'>\n";

    # Parts list name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Parts List Name</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='plistName' value='" .
	escapeHTML($db_name) . "' size='60' maxLength='500'/>" . "</td>\n";
    print "</tr>\n";

    # definition
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Definition</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='def' value='" .
	escapeHTML($db_def) . "' size='60' maxLength='4000'/>" . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    print end_form( );
}

############################################################################
# printConfirmDeletePartsListForm - ask user to confirm deletion
############################################################################
sub printConfirmDeletePartsListForm {
    print "<h1>Delete IMG Parts List Page</h1>\n";

    printMainForm( );

    # get the select parts list information
    # save selected term oids
    my $ipc = new ImgPartsListCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @plist_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected pathway oids
    my @selected_plist_oids = param( "parts_list_oid" ); 
    my %selected_plist_oids_h; 
    for my $plist_oid( @selected_plist_oids ) { 
        $selected_plist_oids_h{ $plist_oid } = 1;
    }
 
    ## Set parameters. 
    print hiddenVar( "section", $section );
 
    # get selected pathway oids 
    # save parts list selections in a hidden variable
    print "<input type='hidden' name='selectedPList' value='"; 
    for my $plist_oid ( @selected_plist_oids ) {
        print "$plist_oid "; 
    } 
    print "'>\n"; 

    my $plist_oid = -1; 
    if ( scalar (@selected_plist_oids) > 0 ) { 
	$plist_oid = $selected_plist_oids[0]; 
    } 
    else { 
	webError ("No IMG parts list is selected.");
	return; 
    } 

    ## Set parameters.
    print hiddenVar( "selectedPList", $plist_oid );

    print "<h2>Parts List $plist_oid</h2>\n";

    print "<p><font color=\"red\"> ";
    print "Warning: The following parts list-term association " .
	"will be deleted as well.</font></p>\n";

    my $dbh = dbLogin( );

    # show parts list-term association
    print "<h3>IMG Parts List - Term Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Parts List OID</th>\n";
    print "<th class='img'>List Order</th>\n";
    print "<th class='img'>Term OID</th>\n";
    print "<th class='img'>Term Name</th>\n";

    # IMG_PARTS_LIST_IMG_TERMS
    my $sql = qq{
	select ipt.parts_list_oid, ipt.list_order, ipt.term, t.term
	        from img_parts_list_img_terms ipt, img_term t
		    where ipt.term = t.term_oid
		        and ipt.parts_list_oid = ?
			    order by ipt.list_order
			};
    my $cur = execSql( $dbh, $sql, $verbose, $plist_oid );
    for( ;; ) {
	my( $p_oid, $l_order, $t_oid, $term ) = $cur->fetchrow( );
	last if !$p_oid;

	$t_oid = FuncUtil::termOidPadded($t_oid);
	print "<tr class='img'>\n";
	my $url = "$main_cgi?section=ImgPartsListBrowser" .
	   "&page=partsListDetail&parts_list_oid=$plist_oid"; 
        print "<td class='img'>" . alink( $url, $plist_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $l_order ) . "</td>\n";
        my $url = "$main_cgi?section=ImgTermBrowser" .
	    "&page=imgTermDetail&term_oid=$t_oid";
        print "<td class='img'>" . alink( $url, $t_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    ##$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbDeletePathway";
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
# printUpdatePartsListTermForm - update parts list - term
#
# connect_mode: 0 (update only), 1 (add from cart), 2 (add from selection)
############################################################################ 
sub printUpdatePartsListTermForm { 
    my ( $connect_mode ) = @_;

    print "<h1>IMG Parts List - Term Curation Page</h1>\n"; 
 
    printMainForm( );

    # get the select parts list information
    # save selected term oids
    my $ipc = new ImgPartsListCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @plist_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected parts list oids
    my @selected_plist_oids;
    if ( param("selectedPList") ) {
	@selected_plist_oids = split(/ /, param("selectedPList"));
    }
    else {
	@selected_plist_oids = param( "parts_list_oid" ); 
    }

    my %selected_plist_oids_h; 
    for my $plist_oid( @selected_plist_oids ) { 
        $selected_plist_oids_h{ $plist_oid } = 1;
    }
 
    ## Set parameters. 
    print hiddenVar( "section", $section );
 
    # get selected parts list oids 
    # save parts list selections in a hidden variable
    print "<input type='hidden' name='selectedPList' value='"; 
    for my $plist_oid ( @selected_plist_oids ) {
        print "$plist_oid "; 
    } 
    print "'>\n"; 

    my $plist_oid = -1; 
    if ( scalar (@selected_plist_oids) > 0 ) { 
	$plist_oid = $selected_plist_oids[0]; 
    } 
    else { 
	webError ("No IMG parts list is selected.");
	return; 
    } 

    print "<p>Update terms associated with this parts list. Click the \"Update Parts List - Term\" button to update information in the database. <br/>";
    print "<font color=\"red\">Only selected terms will be associated with this parts list after update. Unselected terms will be removed.</font></p>\n";

    # get parts list info from the database
    my $db_oid = "";
    my $db_name = ""; 
    my $db_def = "";
    my %db_term;

    my $dbh = dbLogin( ); 
    my $sql = qq{ 
	select ipl.parts_list_oid, ipl.parts_list_name, ipl.definition
	        from img_parts_list ipl
		    where ipl.parts_list_oid = ? 
		}; 
 
    my $cur = execSql( $dbh, $sql, $verbose, $plist_oid ); 
    ($db_oid, $db_name, $db_def) = $cur->fetchrow( ); 
    $cur->finish( ); 

    print "<input type='hidden' name='selectedPListName' value='" .
	escapeHTML( $db_name ) . "'>\n";

    print "<h2>Parts List $plist_oid: " . escapeHTML( $db_name ) . "</h2>\n";

    # check whether there are data or not
    my $cnt2 = db_findCount($dbh, 'IMG_PARTS_LIST_IMG_TERMS',
			    "parts_list_oid = $plist_oid");
    if ( $connect_mode == 0 ) {
	if ( $cnt2 <= 0 ) {
	    my $name = "_section_${section}_index";
	    print submit( -name => $name,
			  -value => 'Cancel', -class => 'smbutton' );
	    print "</p>\n";
	    #$dbh->disconnect();

	    webError ("No IMG terms are associated with this part list.");
	    return;
	}
    }

    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_confirmUpdatePartsListTerm";
    print submit( -name => $name,
		  -value => 'Update Parts List - Term', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n";

   # parts list - term
    my $max_order = 0;
    $sql = qq{ 
	select ipt.parts_list_oid, ipt.list_order, ipt.term, t.term
	    from img_parts_list_img_terms ipt, img_term t
	    where ipt.parts_list_oid = ?
	    and ipt.term = t.term_oid
	    order by ipt.list_order, ipt.term
	};
 
    my $cur = execSql( $dbh, $sql, $verbose, $plist_oid );
    for (;;) { 
	my ( $p_oid, $l_order, $t_oid, $term ) =
	    $cur->fetchrow( );
	last if !$p_oid;

	$t_oid = FuncUtil::termOidPadded($t_oid);
	if ( $l_order > $max_order ) {
	    $max_order = $l_order;
	}

	my $order2 = sprintf("%05d", $l_order);

	my $key = "$order2 $t_oid";
	my $val = "$l_order\t$t_oid\t$term";

	$db_term{$key} = $val;
    } 
 
    ##$dbh->disconnect(); 

    ## print terms in a table
    print "<h3>Terms associated with Parts List</h3>\n";

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " . 
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>Select</th>\n"; 
    print "<th class='img'>List Order</th>\n"; 
    print "<th class='img'>Term OID</th>\n"; 
    print "<th class='img'>Term</th>\n"; 

    for my $k ( sort (keys %db_term) ) {
	my ($order2, $t_oid) = split ( / /, $k);
	my $val = $db_term{$k};

	my ($l_order, $t_oid, $term) = split( /\t/, $val);
        print "<tr class='img'>\n"; 
 
        # select? 
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='term_oid' value='$t_oid' checked />\n"; 
        print "</td>\n"; 

        # list order
        print "<td class='img'>\n";
	print "<input type='text' ";
	my $order_name = "order_" . $l_order . "_" . $t_oid;
	print "name='$order_name' id='$order_name' value='" .
	    escapeHTML( $l_order ) . "' size=4 maxLength=4 /> </td>\n";
 
        # t_oid with url 
        my $url = "$main_cgi?section=ImgTermBrowser" .
	    "&page=imgTermDetail&term_oid=$t_oid";
        print "<td class='img'>" . alink( $url, $t_oid ) . "</td>\n";

	# term
	print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	print "</tr>\n";
    }

    # set list_order
    my $list_order = $max_order;

    if ( $connect_mode == 1 ) {
	# load from IMG Term Cart
	my $include_all = 1;
	if ( param( "conn_mode" ) eq "selected" ) {
	    $include_all = 0;
	}

	my $cart = new FuncCartStor( );
	my $recs = $cart->{ recs }; # get records 
	my @cart_oids = sort{ $a <=> $b }keys( %$recs ); 
	my $selected = $cart->{ selected };

	for my $c_oid ( @cart_oids ) {
	    next if $c_oid !~ /ITERM/;   # only wants terms

	    my $r = $recs->{ $c_oid };
	    my( $c_oid, $term, $batch_id ) = split( /\t/, $r );

	    my ( $tag, $t_oid ) = split (/:/, $c_oid);

	    $list_order++;

	    print "<tr class='img'>\n"; 
 
	    # select? 
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='term_oid' value='$t_oid' checked />\n"; 
	    print "</td>\n"; 

	    # list order
	    print "<td class='img'>\n";
	    print "<input type='text' ";
	    my $order_name = "order_" . $list_order . "_" . $t_oid;
	    print "name='$order_name' id='$order_name' value='" .
		$list_order . "' size=4 maxLength=4 /> </td>\n";
 
	    # t_oid with url 
	    my $url = "$main_cgi?section=ImgTermBrowser" .
		"&page=imgTermDetail&term_oid=$t_oid";
	    print "<td class='img'>" . alink( $url, $t_oid ) . "</td>\n";
 
	    # term
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	    print "</tr>\n";
	}
    }
    elsif ( $connect_mode == 2 ) {
	# load from selection
	my @selected_term_oids = param("termSelection");

	my $dbh = dbLogin( ); 
	for my $t_oid ( @selected_term_oids ) {
	    $list_order++;

	    print "<tr class='img'>\n"; 
 
	    my $term = db_findVal($dbh, 'IMG_TERM', 'term_oid', $t_oid,
					  'term', '');

	    # select? 
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='term_oid' value='$t_oid' checked />\n"; 
	    print "</td>\n"; 

	    # list order
	    print "<td class='img'>\n";
	    print "<input type='text' ";
	    my $order_name = "order_" . $list_order . "_" . $t_oid;
	    print "name='$order_name' id='$order_name' value='" .
		$list_order . "' size=4 maxLength=4 /> </td>\n";
 
	    # t_oid with url 
	    my $url = "$main_cgi?section=ImgTermBrowser" .
		"&page=imgTermDetail&term_oid=$t_oid";
	    print "<td class='img'>" . alink( $url, $t_oid ) . "</td>\n";
 
	    # term
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	    print "</tr>\n";
	}

	#$dbh->disconnect();
    }

    print "</table>\n";

    print "<br/>\n";

    # print term names as hidden var
    for my $k ( sort (keys %db_term) ) {
	my ($order2, $t_oid) = split ( / /, $k);
	my $val = $db_term{$k};

	my ($list_order, $t_oid, $term) = split( /\t/, $val);
	my $tn_tag = "termname_" . $list_order . "_" . $t_oid;
	my $t_name = escapeHTML( $term );
	print "<input type='hidden' name='$tn_tag' value='$t_name' />\n"; 
    }

    if ( $connect_mode == 1000 ) {
	my $list_order = $max_order;

	# load from IMG Term Cart
	my $cart = new ImgTermCartStor( );
	my $recs = $cart->{ recs }; # get records 
 
	my @cart_term_oids = sort{ $a <=> $b }keys( %$recs ); 

	for my $t_oid ( @cart_term_oids ) {
	    my $r = $recs->{ $t_oid };
	    my( $t_oid, $term, $batch_id ) = split( /\t/, $r );

	    $list_order++;
	    my $tn_tag = "termname_" . $list_order . "_" . $t_oid;
	    my $t_name = escapeHTML( $term );
	    print "<input type='hidden' name='$tn_tag' value='$t_name' />\n"; 
	}
    }

    print end_form( );
}

############################################################################
# printSearchTermResults - Show results of term search.
############################################################################
sub printSearchTermResults {

    print "<h1>Search IMG Terms (and their synonyms)</h1>\n";
    
    printMainForm( );

    # keep previous parts list selection in a hidden variable
    my $selectedPList = param ( "parts_list_oid" );
    print hiddenVar( "parts_list_oid", $selectedPList );

    # get search term
    my $searchTerm = param( "searchTerm" );

    print "<p>\n";
    print "Enter Search Term.  Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchTerm' value='$searchTerm' size='80' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchTermResults";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    if( $searchTerm eq "" ) {
        webError( "Please enter a term." );
	print end_form();
	return;
    }

    my $dbh = dbLogin( );

    ## Massage for SQL.
    #  Get rid of preceding and lagging spaces.
    #  Escape SQL quotes.  
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    printStatusLine( "Loading ...", 1 );

    # search terms
    my %imgTerms = db_searchIMGTermSynonym ($dbh, $searchTermLc, $max_count);

    my $count = 0;
    for my $k ( keys %imgTerms ) {
         $count++;
    }

    if ( $count == 0 ) {
        ##$dbh->disconnect();
        printStatusLine( "$count term(s) found.", 2 );
        webError( "No IMG terms matches the keyword." );
        return;
    }

    # retrieve all synonyms
    my @keys = keys( %imgTerms );
    my %imgSynonyms = db_getSynonyms ($dbh, @keys);

    #$dbh->disconnect();

    print "<h2>Select IMG Terms</h2>\n";
    print "<p>The following list shows all IMG terms that have terms or synonyms matching the input search term.<br/>\n";
    print "Click on an IMG term to see synonyms of this term.</p>\n";

    # make a single list selection for terms
    print "<select name='termSelection' class='img'";
    print " onChange='showSynonyms()' ";
    print " width='60' size='10'>\n";

    # sort terms
    for my $term_oid ( sort keys %imgTerms ) {
print "<option value='$term_oid'>";
        print highlightMatchHTML2( $imgTerms{$term_oid}, $searchTerm );
        print "</option>\n";
    }

    print "</select>\n";
    if ( $count < $max_count ) {
        printStatusLine( "$count term(s) found.", 2 );
    }
    else {
        printStatusLine( "Only $count terms displayed.", 2 );
    }

    ## Set parameters.
    # print hiddenVar( "section", $section );

    # show button
    print "<br/><br/>\n";
    my $name = "_section_${section}_partsListTermAssignment";
    print submit( -name => $name,
       -value => "Associate Term and Parts List", -class => "lgdefbutton" );
    print "\n";

    for my $key ( keys %imgSynonyms ) {
        my $s = $imgSynonyms{$key};

        print "<input type=\"hidden\" id=\"$key\" value=\"";
        my @s = split(/\n/, $imgSynonyms{$key});
        for my $s1 ( @s ) {
            my $s2 = highlightMatchHTML2 ( escapeHTML($s1), $searchTerm );
            print "$s2<br/>\n";
        }
        print "\">\n";
    }

    # show synonyms
    print "<h2>View Synonyms for Selected IMG Term</h2>\n";   
    print "<div id='synonyms' name='synonyms' " .
          "style='background-color: #eee; overflow: scroll; " .
	"width: 560px; height:160px'></div>\n";

    # add java script function 'showSynonym'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function showSynonyms() {\n";
    print "   var termOid = document.mainForm.termSelection.value;\n";

    print "   document.getElementById('synonyms').innerHTML = \"\";\n";
    print "   document.getElementById('synonyms').innerHTML = document.getElementById(termOid).value;\n";

    print "   }\n";
    print "\n</script>\n\n";

    print end_form();
}

############################################################################
# db_searchIMGTermSynonym - search IMG terms and synonyms that match
#                        the searchTerm
#
# (return IMG term oid => term hash)
############################################################################
sub db_searchIMGTermSynonym {
    my ( $dbh, $searchTermLc, $max_count ) = @_;

    my %h;

    # search IMG terms first
    my $sql = qq{
        select it.term_oid, it.term
        from img_term it
        where lower( it.term ) like '%$searchTermLc%'
    };

    my $cur = execSql( $dbh, $sql, $verbose  );
    my $count = 0;
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;

        # save term_oid and term
        if ( $count < $max_count ) {
            $term_oid = sprintf( "%05d", $term_oid );
            $h{$term_oid} = "$term_oid $term";
            $count++;
        }
    }
    $cur->finish();

    # search synonyms only when max_count is not reached
    if ( $count >= $max_count ) {
        return %h;
    }

    # search synonyms
    my $sql2 = qq{
        select it.term_oid, it.term, its.synonyms
        from img_term it, img_term_synonyms its
        where it.term_oid = its.term_oid
        and lower( its.synonyms ) like '%$searchTermLc%'
    };

    my $cur2 = execSql( $dbh, $sql2, $verbose);

    for ( ; ; ) {
        my ( $term_oid, $term, $synonym ) = $cur2->fetchrow();
        last if !$term_oid;

        # save term_oid and term
        $term_oid = sprintf( "%05d", $term_oid );

        if ( $count < $max_count
             && !( $h{$term_oid} ) )
        {
            $h{$term_oid} = "$term_oid $term";
            $count++;
        }
    }

    $cur2->finish();

    return %h;
}


############################################################################
# db_getSynonyms - retrieve all synonyms for a list of IMG term oids
############################################################################
sub db_getSynonyms {
    my ( $dbh, @keys ) = @_;

    my %h;

    for my $key (@keys) {
        my $sql = qq{
            select term_oid, synonyms
            from img_term_synonyms
            where term_oid = ?
                order by synonyms
        };

        my $cur = execSql( $dbh, $sql, $verbose, $key );

        my $synonymString = "";
        my $first         = 1;

        for ( ; ; ) {
            my ( $term_oid, $synonym ) = $cur->fetchrow();
            last if !$term_oid;

            $term_oid = sprintf( "%05d", $term_oid );

            my $s = $synonym;

            if ($first) {
                $first         = 0;
                $synonymString = $s;
            } else {
                $synonymString .= ( "\n" . $s );
            }
        }

        if ( !$first ) {
            $h{$key} = $synonymString;
        }

        $cur->finish();
    }

    return %h;
}


############################################################################
# dbAddPartsList - add a new parts list to the database 
############################################################################
sub dbAddPartsList() { 
    # get input parameters
    my $parts_list_name = param ('plistName');
    my $def = param ('def');
 
    # check input 
    chomp($parts_list_name);
    if ( !$parts_list_name || blankStr($parts_list_name) ) { 
        webError ("Please enter a new parts list name.");
        return -1; 
    } 

    # login 
    my $dbh = dbLogin();
 
    # parts list already exist? 
    my $id2 = db_findID ($dbh, 'IMG_PARTS_LIST', 'PARTS_LIST_OID',
			 'PARTS_LIST_NAME', $parts_list_name, '');
    if ( $id2 > 0 ) {
        #$dbh->disconnect();
        webError ("Parts list already exists. (PARTS_LIST_OID=$id2)");
        return -1;
    } 

    my @sqlList = (); 
 
    # get next oid
    my $new_plist_oid = db_findMaxID( $dbh, 'IMG_PARTS_LIST',
				      'PARTS_LIST_OID') + 1;
    #$dbh->disconnect(); 
 
    # prepare insertion 
    my $ins = "insert into IMG_PARTS_LIST (parts_list_oid, parts_list_name";
    my $s = $parts_list_name; 
    $s =~ s/'/''/g;  # replace ' by ''
    my $vals = "values ($new_plist_oid, '". $s . "'";
 
    if ( $def && length($def) > 0 ) { 
        $def =~ s/'/''/g;  # replace ' by '' 
        $ins .= ", definition";
        $vals .= ", '$def'";
    }
 
    # modified by 
    if ( $contact_oid ) { 
        $ins .= ", modified_by";
        $vals .= ", $contact_oid";
    } 
 
    # add_date, mod_date
    $ins .= ", add_date, mod_date) "; 
    $vals .= ", sysdate, sysdate) "; 
 
    my $sql = $ins . $vals; 
    push @sqlList, ( $sql ); 

    # perform database update 
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 
    else { 
        return $new_plist_oid; 
    } 
}

############################################################################
# dbUpdatePartsList - update parts list
############################################################################
sub dbUpdatePartsList() { 
    # get input parameters
    my $parts_list_oid = param ('selectedPList');
    my $parts_list_name = param ('plistName');
    my $def = param ('def');
 
    # check input 
    chomp($parts_list_name);
    if ( !$parts_list_name || blankStr($parts_list_name) ) { 
        webError ("Please enter a new parts list name.");
        return -1; 
    } 

    # login 
    my $dbh = dbLogin();
 
    # parts list already exist? 
    my $id2 = db_findID ($dbh, 'IMG_PARTS_LIST', 'PARTS_LIST_OID',
			 'PARTS_LIST_NAME', $parts_list_name,
			 "parts_list_oid <> $parts_list_oid");
    if ( $id2 > 0 ) {
        #$dbh->disconnect();
        webError ("Parts list already exists. (PARTS_LIST_OID=$id2)");
        return -1;
    } 

    my $sql = "select parts_list_oid, parts_list_name, definition " .
	"from img_parts_list where parts_list_oid = $parts_list_oid";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $to_update = 0;
    for (;;) { 
        my ( $p_id, $name, $de ) = $cur->fetchrow( );
        last if !$p_id;
 
	if ( $name ne $parts_list_name || $de ne $def ) {
	    $to_update = 1;
	}
    }

    if ( $to_update == 0 ) {
	#$dbh->disconnect();
	return -1;
    }

    my @sqlList = (); 
 
    # prepare update
    $parts_list_name =~ s/'/''/g;  # replace ' by ''
    $def =~ s/'/''/g;  # replace ' by '' 

    my $sql = "update IMG_PARTS_LIST set parts_list_name = '$parts_list_name',";
    $sql .= " definition = '$def',";
    $sql .= " mod_date = sysdate, modified_by = $contact_oid";
    $sql .= " where parts_list_oid = $parts_list_oid";

    push @sqlList, ( $sql ); 
 
    # perform database update  
   my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 
    else { 
        return $parts_list_oid; 
    } 
}


############################################################################
# dbDeletePartsList - delete parts list
############################################################################
sub dbDeletePartsList() { 
    # get parts list oid
    my $old_oid = param ('selectedPList');
    if ( blankStr($old_oid) ) {
	webError ("No IMG parts list is selected.");
	return -1;
    }

    my @sqlList = ();
    my $sql;

    # delete from IMG_PARTS_LIST_IMG_TERMS
    $sql = "delete from IMG_PARTS_LIST_IMG_TERMS where parts_list_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PARTS_LIST
    $sql = "delete from IMG_PARTS_LIST where parts_list_oid = $old_oid";
    push @sqlList, ( $sql );

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	return $old_oid;
    }
}

############################################################################ 
# printConfirmUpdatePartsListTermForm - confirm update parts list-term
############################################################################ 
sub printConfirmUpdatePartsListTermForm { 
    my ( $connect ) = @_;

    print "<h1>Confirm IMG Parts List - Term Update Page</h1>\n"; 
 
    printMainForm( );

    my $parts_list_oid = param("selectedPList");
    $parts_list_oid =~ s/\s+$//;
    my $parts_list_name = param("selectedPListName");
    print "<h2>Parts List ($parts_list_oid): " . escapeHTML($parts_list_name) .
	"</h2>\n";

    if ( $parts_list_oid eq "" ) {
	webError ("No IMG parts list is selected.");
	return; 
    } 

    ## Set parameters. 
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedPList", $parts_list_oid );

    # show selected reactions
    print "<h3>Terms associated with Parts List</h3>\n";

    print "<p>The selected parts list will be updated to be associated with the following terms:</p>\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>List Order</th>\n"; 
    print "<th class='img'>Term OID</th>\n"; 
    print "<th class='img'>Term</th>\n"; 

    my %term_data;
    my $dbh = dbLogin();

    my $query = WebUtil::getCgi();

    my @term_oids = param("term_oid");
    for my $term_oid ( @term_oids ) {
	print "<tr class='img'>\n"; 
 
	for my $p ( $query->param() ) {
	    my ($lab, $ord, $id2) = split (/\_/, $p);
	    if ( $lab eq "order" && $id2 eq $term_oid ) {
		my $tag = "_" . $ord . "_" . $id2;

		my $ord_tag = "order" . $tag;
		my $list_order = param($ord_tag);
		print "<td class='img'>" . escapeHTML($list_order) . "</td>\n";

		# term_oid with url 
		my $url = "$main_cgi?section=ImgTermBrowser" .
		    "&page=imgTermDetail&term_oid=$term_oid";
		print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
 
		my $term = db_findVal($dbh, 'IMG_TERM', 'term_oid', $term_oid,
					  'term', '');
		print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

		# check list_order (must be a positive integer)
		if ( isInt($list_order) ) {
		    # is integer
		    if ( $list_order <= 0 ) {
			print "</tr>\n";
			print "</table>\n";
			#$dbh->disconnect();
			webError ("List order must be a positive integer. Input '$list_order' <= 0.");
			return;
		    }
		}
		else {
		    # not integer
		    print "</tr>\n";
		    print "</table>\n";
		    #$dbh->disconnect();
		    webError ("List order must be an integer. Input '$list_order' is not an integer.");
		    return;
		}

		# save data
		my $key = sprintf("data_%6d_%4d", $term_oid, $list_order);
		my $val = "$term_oid\t$list_order";
		$term_data{$key} = $val;
	    }
	}

	print "</tr>\n";
    }

    print "</table>\n";
    #$dbh->disconnect();

    # using hidden parameters to save data
    for my $key (keys %term_data) {
	my $val = $term_data{$key};
	print hiddenVar( $key, $val );
    }
    
    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbUpdatePListTerm";
    print submit( -name => $name,
		  -value => 'Update Parts List - Term', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}

############################################################################ 
# dbUpdatePListTerm - perform database update for parts list - term
############################################################################ 
sub dbUpdatePListTerm {
    my $query = WebUtil::getCgi();

    # get parts list oid
    my $parts_list_oid = param("selectedPList");
    my @sqlList = (); 

    my $sql = "delete from IMG_PARTS_LIST_IMG_TERMS " .
	"where parts_list_oid = $parts_list_oid";
    push @sqlList, ( $sql );

    for my $p ( $query->param() ) {
	my ($lab, $ord, $id2) = split (/\_/, $p);
	if ( $lab eq "data" ) {
	    # data item
	    my $val = param($p);
	    my ($term_oid, $list_order) = split (/\t/, $val);

	    $sql = "insert into IMG_PARTS_LIST_IMG_TERMS " .
		    "(parts_list_oid, list_order, term) " .
		    "values (" . $parts_list_oid . ", " . $list_order .
		    ", " . $term_oid . ")";
	    push @sqlList, ( $sql );
	}
    }

   
    # perform database update 
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 
    else { 
        return 1;
    } 
}


############################################################################
# printFileUploadPListTermForm
############################################################################
sub printFileUploadPListTermForm {
    print "<h1>Upload IMG Parts List - Term Associations from File</h1>\n";

    # need a different ENCTYPE for file upload
    print start_form( -name => "mainForm",
		      -enctype => "multipart/form-data",
		      -action => "$section_cgi" );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );

    print "<p>The input file must satisfy the following requirements:</p>\n";
    print "<ul>\n";
    print "<li>Plain tab-delimited text file</li>\n";
    print "<li>Containing 3 columns: (1) IMG Parts List OID, (2) IMG Term OID, ";
    print "(3) Order</li>\n";
    print "<li>No more than $max_upload_line_count lines</li>\n";
    print "</ul>\n";

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
    my $name = "_section_${section}_validatePListTermFile";
    print submit( -name => $name,
		  -value => 'Open', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_ImgPartsListCartStor_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}

############################################################################
# printValidatePListTermForm
############################################################################
sub printValidatePListTermForm {
    print "<h1>IMG Parts List - Term File Validation Result</h1>\n";

    printMainForm( );

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

    print "<h2>File Name: $filename  (Mode: " . param( "upload_ar" ) . ")</h2>\n";
    print "<p>\n"; # paragraph section puts text in proper font.

    print "<p><font color=\"red\"> ";
    print "Warning: All data rows that have errors " .
        "will not be loaded. </font></p>\n";

    # tmp file name for file upload
    my $sessionId = getSessionId( );
    my $tmp_upload_file = $cgi_tmp_dir . "/upload.plistterm." . $sessionId . ".txt";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "tmpUploadFile", $tmp_upload_file);
    print hiddenVar( "uploadMode", $replace);

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
    my $name = "_section_${section}_dbPListTermFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Line No.</th>\n";
    print "<th class='img'>Parts List OID</th>\n";
    print "<th class='img'>Term OID</th>\n";
    print "<th class='img'>Order</th>\n";
    print "<th class='img'>Message</th>\n";

    # now read from tmp file
    if ( ! open( FILE, $tmp_upload_file ) ) {
	printStatusLine( "Failed.", 2 );
        webError( "Cannot open tmp file $tmp_upload_file.");
	return;
    }

    my $dbh = dbLogin( );

    $line_no = 0;
    while ($line = <FILE>) {
	chomp($line);
        my ($parts_list_oid, $term_oid, $list_order) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	my $msg = "";
	my $hasError = 0;

        print "<tr class='img'>\n";

	print "<td class='img'>" . $line_no . "</td>\n";

	# check parts_list_oid
	$parts_list_oid = strTrim($parts_list_oid);
	if ( blankStr($parts_list_oid) ) {
	    $hasError = 1;
	    $msg = "Error: Parts List OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $parts_list_oid ) .
		"</td>\n";
	}
	elsif ( !isInt($parts_list_oid) ) {
	    $hasError = 1;
	    $msg = "Error: Incorrect Parts List OID '" .
		escapeHTML($parts_list_oid) . "'. ";
	    print "<td class='img'>" . escapeHTML( $parts_list_oid ) . "</td>\n";
	}
	else {
	    my $cnt1 = db_findCount($dbh, 'IMG_PARTS_LIST',
				    "parts_list_oid = $parts_list_oid");
	    if ( $cnt1 <= 0 ) {
		$hasError = 1;
		$msg = "Error: Parts List OID $parts_list_oid is not in the database. ";
		print "<td class='img'>" . escapeHTML( $parts_list_oid ) . "</td>\n";
	    }
	    else {
		# show hyperlink
		$parts_list_oid = FuncUtil::partsListOidPadded($parts_list_oid);
		my $url = "$main_cgi?section=ImgPartsListBrowser" .
		    "&page=partsListDetail&parts_list_oid=$parts_list_oid";
		print "<td class='img'>" . alink( $url, $parts_list_oid ) . "</td>\n";
	    }
	}

	# check term_oid
	$term_oid = strTrim($term_oid);
	if ( blankStr($term_oid) ) {
	    $hasError = 1;
	    $msg .= "Error: Term OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $term_oid ) . "</td>\n";
	}
	elsif ( !isInt($term_oid) ) {
	    $hasError = 1;
	    $msg .= "Error: Incorrect Term OID '" . escapeHTML($term_oid) .
		    "'. ";
	    print "<td class='img'>" . escapeHTML( $term_oid ) . "</td>\n";
	}
	else {
	    my $cnt2 = db_findCount($dbh, 'IMG_TERM', "term_oid = $term_oid");
	    if ( $cnt2 <= 0 ) {
		$hasError = 1;
		$msg .= "Error: Term OID $term_oid is not in the database. ";
		print "<td class='img'>" . escapeHTML( $term_oid ) . "</td>\n";
	    }
	    else {
		# show hyperlink
		$term_oid = FuncUtil::termOidPadded($term_oid);
		my $url = "$main_cgi?section=ImgTermBrowser" .
		    "&page=imgTermDetail&term_oid=$term_oid";
		print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
	    }
	}

	# check order
	$list_order = strTrim($list_order);
	if ( $list_order =~ /^\s*"(.*)"$/ ) { 
	    ($list_order) = ($list_order =~ /^\s*"(.*)"$/);
	    $list_order = strTrim($list_order);
	}
	print "<td class='img'>" . escapeHTML( $list_order ) . "</td>\n";

	if ( blankStr($list_order) ) {
	    $hasError = 1;
	    $msg .= "Error: No order is specified. ";
	}
	elsif ( ! isInt($list_order) ) {
	    $hasError = 1;
	    $msg .= "Error: Order must be an integer. ";
	}

	if ( $hasError == 0 && $replace == 0 ) {
            # check whether pathway-reaction association already exist 
	    # with the same order
            my $cnt3 = db_findCount ($dbh, 'IMG_PARTS_LIST_IMG_TERMS', 
				     "parts_list_oid = $parts_list_oid " .
				     "and term = $term_oid " .
				     "and list_order = $list_order");

            if ( $cnt3 > 0 ) { 
                $msg .= "Error: PartsList-Term-Order association already exists."; 
            } 

	    $hasError = 1;
	}

	# error or warning?
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

    #$dbh->disconnect();

    close (FILE);

    if ( $line_no >= $max_upload_line_count ) {
	printStatusLine( "File is too large. Only $max_upload_line_count lines were processed.", 2 );
    }
    else {
	printStatusLine( "Done.", 2 );
    }

    ## buttons
    my $name = "_section_${section}_dbPListTermFileUpload";
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
# dbPListTermFileUpload - handle the actual data upload
############################################################################
sub dbPListTermFileUpload {
    ## Get parameters.
    my $session = param( "section" );
    my $tmp_upload_file = param( "tmpUploadFile" );
    my $replace = param( "uploadMode" );

    # open file
    if ( ! open( FILE, $tmp_upload_file ) ) {
        webError( "Cannot open tmp file $tmp_upload_file.");
	return 0;
    }

    my $dbh = dbLogin( );
    my @sqlList = ( );
    my $sql;

    my @parts_list_oids;
    my @term_oids;

    my $line_no = 0;
    my $line;
    while ($line = <FILE>) {
	chomp($line);
        my ($parts_list_oid, $term_oid, $list_order) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	# check parts_list_oid
	$parts_list_oid = strTrim($parts_list_oid);
	if ( blankStr($parts_list_oid) ) {
	    next;
	}
	elsif ( !isInt($parts_list_oid) ) {
	    next;
	}
	else {
	    my $cnt1 = db_findCount($dbh, 'IMG_PARTS_LIST',
				    "parts_list_oid = $parts_list_oid");
	    if ( $cnt1 <= 0 ) {
		next;
	    }
	}

	# check term_oid
	$term_oid = strTrim($term_oid);
	if ( blankStr($term_oid) ) {
	    next;
	}
	elsif ( !isInt($term_oid) ) {
	    next;
	}
	else {
	    my $cnt2 = db_findCount($dbh, 'IMG_TERM', "term_oid = $term_oid");
	    if ( $cnt2 <= 0 ) {
		next;
	    }
	}

	# check list_order
	$list_order = strTrim($list_order);
	if ( $list_order =~ /^\s*"(.*)"$/ ) { 
	    ($list_order) = ($list_order =~ /^\s*"(.*)"$/);
	    $list_order = strTrim($list_order);
	}
	if ( blankStr($list_order) ) {
	    next;
	}
	elsif ( ! isInt($list_order) ) {
	    next;
	}

	# check whether pathway-reaction association already exist 
	# with the same order
	my $cnt3 = db_findCount ($dbh, 'IMG_PARTS_LIST_IMG_TERMS', 
				 "parts_list_oid = $parts_list_oid " .
				 "and term = $term_oid " .
				 "and list_order = $list_order");
	if ( $cnt3 > 0 ) { 
	    next;
	}

	# save parts_list_oid
	if ( ! WebUtil::inArray($parts_list_oid, @parts_list_oids) ) {
	    push @parts_list_oids, ( $parts_list_oid );

	    # generate delete statement for replace mode
	    if ( $replace ) {
		$sql = "delete from IMG_PARTS_LIST_IMG_TERMS " .
		    "where parts_list_oid = $parts_list_oid";
		push @sqlList, ( $sql );
	    }
	}

	# save term_oid
	if ( ! WebUtil::inArray($term_oid, @term_oids) ) {
	    push @term_oids, ( $term_oid );
	}

	# database update
	$sql = "insert into IMG_PARTS_LIST_IMG_TERMS " .
	    "(parts_list_oid, term, list_order) ";
	$sql .= "values ($parts_list_oid, $term_oid, $list_order)";
	push @sqlList, ( $sql );
    }

    #$dbh->disconnect();

    close (FILE);

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return -1;
    }
    else {
	# update parts list cart
	if ( scalar(@parts_list_oids) > 0 ) {
	    my $ipc = new ImgPartsListCartStor( );
	    $ipc->addImgPartsListBatch( \@parts_list_oids );
	}

	# update function cart and term cart
	if ( scalar(@term_oids) > 0 ) {
	    my $fc = new FuncCartStor( ); 
	    $fc->addImgTermBatch( \@term_oids );

	    my $itc = new ImgTermCartStor( );
	    $itc->addImgTermBatch( \@term_oids );
	}
    }
}


1;
