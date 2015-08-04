############################################################################
# ImgPwayCartDataEntry.pm - Data entry forms for IMG pways.
#   --imachen 10/03/2006
############################################################################
package ImgPwayCartDataEntry;
my $section = "ImgPwayCartDataEntry";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use ImgPwayCartStor;
use ImgRxnCartStor;
use DataEntryUtil;
use FuncUtil;
use FuncCartStor;


my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi = $env->{ inner_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };

my $contact_oid = getContactOid( );

my $max_item_count = 100;    # limit the number of returned IMG pways
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
    elsif( paramMatch( "addPathwayForm" ) ) {
        printAddUpdatePathwayForm( 0 );
    }
    elsif( paramMatch( "dbAddPathway" ) ne "" ) {
	my $new_oid = dbAddPathway();
	if ( $new_oid > 0 ) {
	    # add new oids to function cart
	    my $fc = new FuncCartStor( ); 
	    my @pway_oids = param( "pway_oid" );
	    push @pway_oids, ( $new_oid );
	    $fc->addImgPwayBatch( \@pway_oids );
	}

	# add to pathway cart too
        if ( $new_oid > 0 ) {
            my $ipc = new ImgPwayCartStor( );
            my @pway_oids = param( "pway_oid" );
            push @pway_oids, ( $new_oid );
            $ipc->addImgPwayBatch( \@pway_oids );
        } 

	# go to the index page
	$page = "index";
       }
    elsif( paramMatch( "updatePathwayForm" ) ) {
        printAddUpdatePathwayForm( 1 );
    }
    elsif( paramMatch( "dbUpdatePathway" ) ne "" ) {
        my $old_oid = dbUpdatePathway();
 
        if ( $old_oid > 0 ) { 
            # update pathway info
            my $fc = new FuncCartStor( ); 
            my @pway_oids = ( $old_oid ); 
            $fc->addImgPwayBatch( \@pway_oids );
        }

	# update pathway cart too
        if ( $old_oid > 0 ) {
            my $ipc = new ImgPwayCartStor( );
            my @pathway_oids = ( $old_oid );
            $ipc->addImgPwayBatch( \@pathway_oids );
        } 

	# go to the index page
	$page = "index";
    } 
    elsif( paramMatch( "confirmDeletePathwayForm" ) ne "" ) {
	printConfirmDeletePathwayForm( );
    }
    elsif( paramMatch( "dbDeletePathway" ) ne "" ) {
	my $old_oid = dbDeletePathway();
	if ( $old_oid > 0 ) {
	    my $fc = new FuncCartStor( ); 
	    my $recs = $fc->{ recs }; # get records 
	    my $selected = $fc->{ selected };
	    my $func_id = "IPWAY:" . FuncUtil::pwayOidPadded($old_oid);
	    delete $recs->{ $func_id };
	    delete $selected->{ $func_id };
	    $fc->save( );
	}

	# delete from pathway cart too
        if ( $old_oid > 0 ) {
            my $ipc = new ImgPwayCartStor( );
            my $recs = $ipc->{ recs }; # get records
            my $selected = $ipc->{ selected };
            delete $recs->{ $old_oid };
            delete $selected->{ $old_oid };
            $ipc->save( ); 
        } 

	# go to index page
	$page = "index";
    }
    elsif( paramMatch( "updatePwayRxnForm" ) ) {
        printUpdatePathwayReactionForm( 0 );
    }
    elsif( paramMatch( "connectPwayRxn" ) ) {
        printUpdatePathwayReactionForm( 1 );
    }
    elsif( paramMatch( "confirmUpdatePwayRxn" ) ne "" ) {
	printConfirmUpdatePwayRxnForm( );
    }
    elsif( paramMatch( "dbUpdatePwayRxn" ) ne "" ) {
	# perform database update
	dbUpdatePwayRxn();

	# go to the index page
	$page = "index";
    } 
    elsif( paramMatch( "searchRxnResults" ) ne "" ) {
	printSearchRxnResults();
    }
    elsif( paramMatch( "pwayRxnAssignment" ) ) {
        printUpdatePathwayReactionForm( 2 );
    }
    elsif ( paramMatch ( "fileUploadPwayRxnForm" ) ) {
	printFileUploadPwayRxnForm();
    }
    elsif ( paramMatch ( "validatePwayRxnFile" ) ) {
	printValidatePwayRxnForm();
    }
    elsif ( paramMatch( "dbPwayRxnFileUpload" ) ne "" ) {
	# perform actual upload
	dbPwayRxnFileUpload();

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
# printIndex - Show index entry to this section.
############################################################################
sub printIndex {
    printImgPwayCartPways( );
}

############################################################################
# printImgPwayCartPways - Show pways in IMG pway cart.
############################################################################
sub printImgPwayCartPways {
    print "<h1>IMG Pathway Curation Page</h1>\n";

    print "<meta http-equiv=\"norefresh\">\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.
 
    print "<h3>Note: This page only allows single IMG pathway selection.</h3>\n";

    print "<table class='img'>\n";

    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Pathway<br/>OID</th>\n";
    print "<th class='img'>Pathway Name</th>\n";
    print "<th class='img'>Batch</th>\n";

    my $cart = new ImgPwayCartStor( );
    my $recs = $cart->{ recs };
    my @pway_oids = sort( keys( %$recs ) );
    my @selected_pway_oids = param( "pway_oid" );
    my %selectedPwayOids;
    for my $pway_oid( @selected_pway_oids ) {
        $selectedPwayOids{ $pway_oid } = 1;
    }

    for my $pway_oid( @pway_oids ) {
	my $r = $recs->{ $pway_oid };
        my( $pway_oid, $pway, $batch_id ) = split( /\t/, $r );
	$pway_oid = sprintf( "%05d", $pway_oid );  # make even sized

	print "<tr class='img'>\n";

	print "<td class='img'>\n";
	print "<input type='radio' ";
	print "name='pway_oid' value='$pway_oid'/>\n";
	print "</td>\n";

	my $url = "$main_cgi?section=ImgPwayBrowser" . 
	   "&page=imgPwayDetail&pway_oid=$pway_oid";
	print "<td class='img'>" . alink( $url, $pway_oid ) . "</td>\n";

	print "<td class='img'>" . escHtml( $pway ) . "</td>\n";
	print "<td class='img'>$batch_id</td>\n";

	print "</tr>\n";
    }

    print "</table>\n";

    ## Set parameters. 
    print hiddenVar( "section", $section ); 
 
   # add New, Delete and Update IMG Pathway button
    print "<br/>\n";
    my $name = "_section_${section}_addPathwayForm";
    print submit( -name => $name,
		  -value => 'New IMG Pathway', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeletePathwayForm";
    print submit( -name => $name,
		  -value => 'Delete IMG Pathway', -class => 'medbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_updatePathwayForm";
    print submit( -name => $name,
		  -value => 'Update IMG Pathway', -class => 'medbutton' );

    # add Update Reactions button
    print "<h3>Pathway Reaction Curation</h3>\n";
    print "<p>Update (or delete) reactions associated with the selected pathway.</p>\n";

    my $name = "_section_${section}_updatePwayRxnForm"; 
    print submit( -name => $name, 
		  -value => 'Update Reactions', -class => 'medbutton' ); 

    print "<h3>Add Reactions from Reaction Cart</h3>\n";
    print "<p>Connect reactions in the IMG Reaction Cart to the selected pathway.</p>\n";

    my $name = "_section_${section}_connectPwayRxn";
    print submit( -name => $name,
		  -value => 'Connect Reactions', -class => 'medbutton' );

    print "<h3>Search Reactions to Add to Pathway</h3>\n";
    print "<p>Enter a keyword to search existing reactions to the selected pathway. Use % for wildcard.</p>\n";
    print "<input type='text' name='searchTerm' size='80' />\n";
    print "<br/>\n";

    my $name = "_section_${section}_searchRxnResults";
    print submit( -name => $name,
		  -value => 'Search Reactions', -class => 'medbutton' );

    print end_form( );
}

############################################################################
# printSearchRxnResults - Show results of term search.
############################################################################
sub printSearchRxnResults {

    print "<h1>Search IMG Reactions</h1>\n";
    
    printMainForm( );

    # get the select pathway information
    my $selectedPathways = param("selectedPathways");
    if ( $selectedPathways ne "" ) {
	# use the stored variable
    }
    else {
	# check pathway cart
	my $ipc = new ImgPwayCartStor( );
	my $recs = $ipc->{ recs }; # get records 
 
	my @pway_oids = sort{ $a <=> $b }keys( %$recs ); 
 
	# get selected pathway oids 
	my @selected_pway_oids = param( "pway_oid" ); 
	my %selected_pway_oids_h; 
	for my $pway_oid( @selected_pway_oids ) { 
	    $selected_pway_oids_h{ $pway_oid } = 1;
	} 

	# get selected pathway oids 
	for my $pathway_oid ( @selected_pway_oids ) {
	    $selectedPathways .= "$pathway_oid "; 
	}
    }
 
    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedPathways", $selectedPathways );
 
    # check whether any pathways are selected
    if ( $selectedPathways eq "" ) {
	webError ("No IMG pathway is selected.");
	return; 
    }

    # get search term
    my $searchTerm = param( "searchTerm" );

    print "<p>Enter a keyword to search existing reactions to the selected pathway. Use % for wildcard.</p>\n";
    print "<input type='text' name='searchTerm' value='" .
	escapeHTML($searchTerm) . "' size='80' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchRxnResults";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print "<br/>\n";

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
    my $lc_keyword = lc($searchTerm);

    printStatusLine( "Loading ...", 1 );

    # search reactions
    my $dbh = dbLogin();

    my $sql = qq{
	select rxn_oid, rxn_name, rxn_definition
	        from IMG_REACTION 
		    where lower(rxn_name) like ? 
		        or lower(rxn_definition) like ?
		    };

    my $cur = execSql ($dbh, $sql, $verbose, "%$lc_keyword%", "%$lc_keyword%");
    my $count = 0;
    print "<p>\n";

    for (;;) { 
	my ( $rxn_oid, $rxn_name, $rxn_def ) = $cur->fetchrow( );
	last if !$rxn_oid;

	$rxn_oid = FuncUtil::rxnOidPadded($rxn_oid);

        if ( !$rxn_name ) { 
            $rxn_name = "(null)"; 
        } 
 
        print "<input type='checkbox' name='rxn_oid' value='$rxn_oid' />\n"; 
        my $url = "$main_cgi?section=$section&page=imgRxnDetail&rxn_oid=$rxn_oid"; 
        print nbsp( 1 );
        print alink( $url, $rxn_oid ); 
        print nbsp( 1 ); 
 
        # print rxn_name 
        # print escapeHTML( $rxn_name ); 
        my $matchText = highlightMatchHTML2( $rxn_name, $searchTerm ); 
        print $matchText; 

        if ( $rxn_def ne "" ) {
	    print "<br/>\n";
            my $matchText = highlightMatchHTML2( $rxn_def, $searchTerm );
	    print nbsp( 7 );
            print " (Definition: $matchText)";
        } 
 

        print "<br/>\n";
	$count++;
    }

    $cur->finish();
    #$dbh->disconnect();
    print "</p>\n";

    if ( $count == 0 ) {
        printStatusLine( "$count reaction(s) found.", 2 );
        webError( "No IMG reactions matches the keyword." );
        return;
    }

    printStatusLine( "$count reaction(s) found.", 2 );

    print "<h3>Assign IMG Reactions to the Selected Pathway</h3>\n";
    my $pway_oid = $selectedPathways;
    $pway_oid =~ s/\s+$//;
    print "<p>Assign all selected IMG reactions to the selected pathway $pway_oid.</p>\n";
    # show button
    my $name = "_section_${section}_pwayRxnAssignment";
    print submit( -name => $name,
       -value => "Add Selected Reactions to Pathway", -class => "lgdefbutton" );
    print "\n";

    print end_form();
}

############################################################################
# printAddUpdatePathwayForm - add or update IMG pathway
############################################################################
sub printAddUpdatePathwayForm {
    my ( $update ) = @_;   # add or update

    if ( $update ) {
	print "<h1>Update IMG Pathway Page</h1>\n";
    }
    else {
	print "<h1>Add IMG Pathway Page</h1>\n";
    }

    printMainForm( );

    # add Add/Update, Reset and Cancel buttons
    if ( $update ) {
        my $name = "_section_${section}_dbUpdatePathway";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddPathway";
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

    # get the select pathway information
    # save selected term oids 
    my $ipc = new ImgPwayCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @pway_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected pathway oids 
    my @selected_pway_oids = param( "pway_oid" ); 
    my %selected_pway_oids_h; 
    for my $pway_oid( @selected_pway_oids ) { 
        $selected_pway_oids_h{ $pway_oid } = 1;
    } 
 
    ## Set parameters.
    print hiddenVar( "section", $section );
 
    # get selected pathway oids 
    # save pathway selections in a hidden variable 
    print "<input type='hidden' name='selectedPways' value='";
    for my $pathway_oid ( @selected_pway_oids ) {
        print "$pathway_oid "; 
    } 
    print "'>\n"; 

    my $pathway_oid = -1; 
    if ( $update ) {
	if ( scalar (@selected_pway_oids) > 0 ) { 
	    $pathway_oid = $selected_pway_oids[0]; 
	} 
	else { 
	    webError ("No IMG pathway is selected.");
	    return; 
	} 
    }

    # get pathway info from the database
    my $db_oid = "";
    my $db_name = ""; 
    my $db_handle = "";
    my $db_is_valid = "No";
    my @db_network = ( );

    my $dbh = dbLogin( ); 

    if ( $update ) {
	my $sql = qq{ 
	    select ip.pathway_oid, ip.pathway_name, ip.handle, ip.is_valid
		from img_pathway ip
		where ip.pathway_oid = $pathway_oid 
	    }; 
 
	my $cur = execSql( $dbh, $sql, $verbose ); 
	($db_oid, $db_name, $db_handle, $db_is_valid) = $cur->fetchrow( ); 
	$cur->finish( ); 

	$sql = qq{
	        select pnip.network_oid
		    from pathway_network_img_pathways pnip
		    where pnip.pathway = $pathway_oid
		};

	$cur = execSql( $dbh, $sql, $verbose );
	for (;;) { 
	    my ( $val ) = $cur->fetchrow( );
	    last if !$val;
 
	    push @db_network, ( $val );
	}
	$cur->finish( );
    }

    print "<h2>Pathway Information</h2>\n";
    
    print "<table class='img' border='1'>\n";

    # Pathway name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Pathway Name</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='pathwayName' value='" .
	escapeHTML($db_name) . "' size='60' maxLength='255'/>" . "</td>\n";
    print "</tr>\n";

    # handle
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Handle</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='handle' value='" .
	escapeHTML($db_handle) . "' size='60' maxLength='255'/>" . "</td>\n";
    print "</tr>\n";

    # is valid?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Valid?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='isValidSelection' class='img' size='2'>\n";
    for my $tt ( ('Yes', 'No') ) {
	print "        <option value='$tt'";
	if ( (uc $db_is_valid) eq (uc $tt) ) {
	    print " selected";
	}
	print ">$tt</option>\n";
    }
    print "     </select>\n";
    print "</td>\n</tr>\n";

    print "</table>\n";

    # display list of pathway network for selection
    print "<h3>Pathway Network Association</h3>\n";
    print "<p>Select the pathway network(s) for this pathway:</p>\n";

    print "<p>\n";
    my $sql = qq{
	select pn.network_oid, pn.network_name
	    from pathway_network pn
	    order by pn.network_name
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
	my ( $v1, $v2 ) = $cur->fetchrow( );
	last if !$v1;

	print "<input type='checkbox' name='network_oid_$v1' value='$v1' ";
	if ( WebUtil::inArray($v1, @db_network) ) {
	    print "checked ";
	}
	print ">\n";
	print nbsp( 1 );
	print escapeHTML($v2);
	print "<br/>\n";
    }
    $cur->finish( );
    #$dbh->disconnect();

    print end_form( );
}


############################################################################
# dbAddPathway - add a new pathway to the database 
############################################################################
sub dbAddPathway() { 
    # get input parameters
    my $pathway_name = param ('pathwayName');
    my $handle = param ('handle');
    my $is_valid = param ('isValidSelection');

    # get network oid
    my @network = ( );
    my $query = WebUtil::getCgi();
    my @all_params = $query->param;
    for my $p( @all_params ) {
	if ($p =~ /network_oid/) {
	    push @network, ( param($p) );
	}
    }

    # check input 
    chomp($pathway_name);
    if ( !$pathway_name || blankStr($pathway_name) ) { 
        webError ("Please enter a new pathway name.");
        return -1; 
    } 

    # login 
    my $dbh = dbLogin();
 
    # pathway already exist? 
    my $id2 = db_findID ($dbh, 'IMG_PATHWAY', 'PATHWAY_OID', 'PATHWAY_NAME', $pathway_name, '');
    if ( $id2 > 0 ) {
        #$dbh->disconnect();
        webError ("Pathway already exists. (PATHWAY_OID=$id2)");
        return -1;
    } 

    my @sqlList = (); 
 
    # get next oid
    my $new_pway_oid = db_findMaxID( $dbh, 'IMG_PATHWAY', 'PATHWAY_OID') + 1;
    #$dbh->disconnect(); 
 
    # prepare insertion 
    my $ins = "insert into IMG_PATHWAY (pathway_oid, pathway_name";
    my $s = $pathway_name; 
    $s =~ s/'/''/g;  # replace ' by ''
    my $vals = "values ($new_pway_oid, '". $s . "'";
 
    if ( $handle && length($handle) > 0 ) { 
        $handle =~ s/'/''/g;  # replace ' by '' 
        $ins .= ", handle";
        $vals .= ", '$handle'";
    }
 
    if ( $is_valid && length($is_valid) > 0 ) {
        $ins .= ", is_valid";
        $vals .= ", '$is_valid'";
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

    # add to PATHWAY_NETWORK_IMG_PATHWAYS
    for my $n1 ( @network ) {
	my $sql = "insert into PATHWAY_NETWORK_IMG_PATHWAYS " .
	    "(network_oid, pathway, mod_date, modified_by) " .
	    "values ($n1, $new_pway_oid, sysdate, $contact_oid) ";
	push @sqlList, ( $sql );
    }

    # perform database update 
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1];
        webError ("SQL Error: $sql");
        return -1;
    } 
    else { 
        return $new_pway_oid; 
    } 
}


############################################################################
# dbUpdatePathway - update pathway to the database 
############################################################################
sub dbUpdatePathway() { 
    # get input parameters
    my $pathway_oid = param ('selectedPways');
    my $pathway_name = param ('pathwayName');
    my $handle = param ('handle');
    my $is_valid = param ('isValidSelection');

    # get network oid
    my @network = ( );
    my $query = WebUtil::getCgi();
    my @all_params = $query->param;
    for my $p( @all_params ) {
	if ($p =~ /network_oid/) {
	    push @network, ( param($p) );
	}
    }

    # check input 
    chomp($pathway_name);
    if ( !$pathway_name || blankStr($pathway_name) ) { 
        webError ("Please enter a new pathway name.");
        return -1; 
    } 

    # check database
    # login
    my $dbh = dbLogin(); 

    # pathway already exist? 
    my $id2 = db_findID ($dbh, 'IMG_PATHWAY', 'PATHWAY_OID', 'PATHWAY_NAME', $pathway_name,
			 "pathway_oid <> $pathway_oid");
    if ( $id2 > 0 ) {
        #$dbh->disconnect();
        webError ("Pathway already exists. (PATHWAY_OID=$id2)");
        return -1;
    } 

    my $sql = "select pathway_oid, pathway_name, handle, is_valid " .
	"from img_pathway where pathway_oid = $pathway_oid";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $to_update = 0;
    for (;;) { 
        my ( $p_id, $name, $hdl, $valid ) = $cur->fetchrow( );
        last if !$p_id;
 
	if ( $name ne $pathway_name ||
	     $hdl ne $handle ||
	     $valid ne $is_valid ) {
	    $to_update = 1;
	}
    }
    $cur->finish();

    my @db_network = ();
    $sql = "select network_oid from PATHWAY_NETWORK_IMG_PATHWAYS where pathway = $pathway_oid";
    $cur = execSql( $dbh, $sql, $verbose );
    for (;;) { 
        my ( $n_id ) = $cur->fetchrow( );
        last if !$n_id;

	push @db_network, ( $n_id );
    }
    $cur->finish();

    my @sqlList = (); 
    my $sql;

    # prepare update
    $pathway_name =~ s/'/''/g;  # replace ' by ''
    $handle =~ s/'/''/g;  # replace ' by '' 

    if ( $to_update ) {
	$sql = "update IMG_PATHWAY set pathway_name = '$pathway_name',";
	$sql .= " handle = '$handle', is_valid = '$is_valid',";
	$sql .= " mod_date = sysdate, modified_by = $contact_oid";
	$sql .= " where pathway_oid = $pathway_oid";

	push @sqlList, ( $sql ); 
    }

    # delete from PATHWAY_NETWORK_IMG_PATHWAYS
    for my $n2 ( @db_network ) {
	if ( ! WebUtil::inArray($n2, @network) ) {
	    $sql = "delete from PATHWAY_NETWORK_IMG_PATHWAYS " .
		"where network_oid = $n2 and pathway = $pathway_oid";
	    push @sqlList, ( $sql );
	}
    }

    # add to PATHWAY_NETWORK_IMG_PATHWAYS
    for my $n1 ( @network ) {
	if ( ! WebUtil::inArray($n1, @db_network) ) {
	    $sql = "insert into PATHWAY_NETWORK_IMG_PATHWAYS " .
		"(network_oid, pathway, mod_date, modified_by) " .
		"values ($n1, $pathway_oid, sysdate, $contact_oid) ";
	    push @sqlList, ( $sql );
	}
    }

    if ( scalar(@sqlList) == 0 ) {
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
        return $pathway_oid; 
    } 
}


############################################################################
# printConfirmDeletePathwayForm - ask user to confirm deletion
############################################################################
sub printConfirmDeletePathwayForm {
    print "<h1>Delete IMG Pathway Page</h1>\n";

    printMainForm( );

    # get the select pathway information
    # save selected term oids
    my $ipc = new ImgPwayCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @pway_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected pathway oids
    my @selected_pway_oids = param( "pway_oid" ); 
    my %selected_pway_oids_h; 
    for my $pway_oid( @selected_pway_oids ) { 
        $selected_pway_oids_h{ $pway_oid } = 1;
    }
 
    ## Set parameters. 
    print hiddenVar( "section", $section );
 
    # get selected pathway oids 
    # save pathway selections in a hidden variable
    print "<input type='hidden' name='selectedPways' value='"; 
    for my $pathway_oid ( @selected_pway_oids ) {
        print "$pathway_oid "; 
    } 
    print "'>\n"; 

    my $pathway_oid = -1; 
    if ( scalar (@selected_pway_oids) > 0 ) { 
	$pathway_oid = $selected_pway_oids[0]; 
    } 
    else { 
	webError ("No IMG pathway is selected.");
	return; 
    } 

    ## Set parameters.
    print hiddenVar( "selectedPathways", $pathway_oid );

    print "<h2>Pathway $pathway_oid</h2>\n";

    print "<p><font color=\"red\"> ";
    print "Warning: The following pathway-reaction association, " .
	"and pathway-network association " .
	"will be deleted as well.</font></p>\n";

    my $dbh = dbLogin( );

    # show pathway-reaction association
    print "<h3>IMG Pathway - Reaction Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Pathway OID</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";
    print "<th class='img'>Reaction Order</th>\n";

    # IMG_PATHWAY_REACTIONS
    my $sql = qq{
	select ipr.pathway_oid, ipr.rxn, r.rxn_name, ipr.rxn_order
	    from img_pathway_reactions ipr, img_reaction r
	    where ipr.rxn = r.rxn_oid
	    and ipr.pathway_oid = ?
	    order by ipr.rxn_order
	};
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for( ;; ) {
	my( $p_oid, $r_oid, $r_name, $r_order ) = $cur->fetchrow( );
	last if !$p_oid;

	$r_oid = FuncUtil::rxnOidPadded($r_oid);
	print "<tr class='img'>\n";
        my $url = "$main_cgi?section=ImgPathway&page=imgPwayDetail&pway_oid=$pathway_oid";
        print "<td class='img'>" . alink( $url, $pathway_oid ) . "</td>\n";
	my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 
        print "<td class='img'>" . alink( $url, $r_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $r_name ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $r_order ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    # show pathway-network association
    print "<h3>IMG Pathway - Network Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Pathway OID</th>\n";
    print "<th class='img'>Network OID</th>\n";
    print "<th class='img'>Network Name</th>\n";

    # PATHWAY_NETWORK_IMG_PATHWAY_REACTIONS
    my $sql = qq{
	select pnip.pathway, pn.network_oid, pn.network_name
	    from pathway_network_img_pathways pnip, pathway_network pn
	    where pnip.pathway = ?
	    and pnip.network_oid = pn.network_oid
	    order by pn.network_oid
	};
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for( ;; ) {
	my( $p_oid, $n_oid, $n_name ) = $cur->fetchrow( );
	last if !$p_oid;

	$n_oid = sprintf("%05d", $n_oid);

	print "<tr class='img'>\n";
        my $url = "$main_cgi?section=ImgPathway&page=imgPwayDetail&pway_oid=$pathway_oid";
        print "<td class='img'>" . alink( $url, $pathway_oid ) . "</td>\n";
        print "<td class='img'>" . $n_oid  . "</td>\n";
        print "<td class='img'>" . escapeHTML( $n_name ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    #$dbh->disconnect();

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
# dbDeletePathway - delete an IMG pathway from the database
############################################################################
sub dbDeletePathway {
    # get the pathway oid
    my $old_oid = param( "selectedPathways" );
    if ( blankStr($old_oid) ) {
	webError ("No IMG pathway is selected.");
	return -1;
    }

    # prepare SQL
    my @sqlList = ();
    my $sql;

    # delete from IMG_REACTION_ASSOC_PATHS
    $sql = "delete from IMG_REACTION_ASSOC_PATHS where pathway = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_REACTIONS
    $sql = "delete from IMG_PATHWAY_REACTIONS where pathway_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_C_COMPONENTS
    $sql = "delete from IMG_PATHWAY_C_COMPONENTS where pathway_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_T_COMPONENTS
    $sql = "delete from IMG_PATHWAY_T_COMPONENTS where pathway_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_TAXONS
    $sql = "delete from IMG_PATHWAY_TAXONS where pathway_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_ASSERTIONS
    $sql = "delete from IMG_PATHWAY_ASSERTIONS where pathway_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from PATHWAY_NETWORK_IMG_PATHWAYS
    $sql = "delete from PATHWAY_NETWORK_IMG_PATHWAYS where pathway = $old_oid";
    push @sqlList, ( $sql );

    # update IMG_PATHWAY_HISTORY
    $sql = "update IMG_PATHWAY_HISTORY set pathway_oid = $old_oid, pathway = null where pathway = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY
    $sql = "delete from IMG_PATHWAY where pathway_oid = $old_oid";
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
# printUpdatePathwayReactionForm - update pathway-reaction
#
# connect_mode: 0 (update only), 1 (add from cart), 2 (add from selection)
############################################################################ 
sub printUpdatePathwayReactionForm { 
    my ( $connect_mode ) = @_;

    print "<h1>IMG Pathway Reaction Curation Page</h1>\n"; 
 
    printMainForm( );

    # get the select pathway information
    # save selected term oids
    my $ipc = new ImgPwayCartStor( );
    my $recs = $ipc->{ recs }; # get records 
 
    my @pway_oids = sort{ $a <=> $b }keys( %$recs ); 
 
    # get selected pathway oids
    my @selected_pway_oids;
    if ( param("selectedPathways") ) {
	@selected_pway_oids = split(/ /, param("selectedPathways"));
    }
    else {
	@selected_pway_oids = param( "pway_oid" ); 
    }

    my %selected_pway_oids_h; 
    for my $pway_oid( @selected_pway_oids ) { 
        $selected_pway_oids_h{ $pway_oid } = 1;
    }
 
    ## Set parameters. 
    print hiddenVar( "section", $section );
 
    # get selected pathway oids 
    # save pathway selections in a hidden variable
    print "<input type='hidden' name='selectedPways' value='"; 
    for my $pathway_oid ( @selected_pway_oids ) {
        print "$pathway_oid "; 
    } 
    print "'>\n"; 

    my $pathway_oid = -1; 
    if ( scalar (@selected_pway_oids) > 0 ) { 
	$pathway_oid = $selected_pway_oids[0]; 
    } 
    else { 
	webError ("No IMG pathway is selected.");
	return; 
    } 

    print "<p>Update reactions in this pathway. Click the \"Update Pathway-Reaction\" button to update information in the database. <br/>";
    print "<font color=\"red\">Only selected reactions will be associated with this pathway after update. Unselected reactions will be removed.</font></p>\n";


    # get pathway info from the database
    my $db_oid = "";
    my $db_name = ""; 
    my $db_handle = "";
    my %db_rxn;

    my $dbh = dbLogin( ); 
    my $sql = qq{ 
	select ip.pathway_oid, ip.pathway_name, ip.handle
	    from img_pathway ip
	    where ip.pathway_oid = ? 
	}; 
 
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid ); 
    ($db_oid, $db_name) = $cur->fetchrow( ); 
    $cur->finish( ); 

    print "<input type='hidden' name='selectedPwayName' value='" .
	escapeHTML( $db_name ) . "'>\n";

    print "<h2>Pathway $pathway_oid: " . escapeHTML( $db_name ) . "</h2>\n";

    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_confirmUpdatePwayRxn";
    print submit( -name => $name,
		  -value => 'Update Pathway-Reaction', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n";

    # pathway-reactions
    my $max_order = 0;
    $sql = qq{ 
	select ipr.pathway_oid, ipr.rxn_order, ipr.is_mandatory, ipr.rxn,
	       r.rxn_name, r.comments
	    from img_pathway_reactions ipr, img_reaction r
	    where ipr.pathway_oid = ?
	    and ipr.rxn = r.rxn_oid
	    order by ipr.rxn_order, ipr.rxn
	};
 
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for (;;) { 
	my ( $p_oid, $rxn_order, $is_man, $rxn, $rxn_name, $comm ) =
	    $cur->fetchrow( );
	last if !$p_oid;

	$rxn = FuncUtil::rxnOidPadded($rxn);
	if ( $rxn_order > $max_order ) {
	    $max_order = $rxn_order;
	}

	my $order2 = sprintf("%05d", $rxn_order);

	my $key = "$order2 $rxn";
	my $val = "$rxn_name\t$comm\t$rxn_order\t$is_man";

	$db_rxn{$key} = $val;
    } 
 
    #$dbh->disconnect(); 

    ## print reactions in a table
    print "<h3>Reactions in Pathway</h3>\n";

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " . 
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>Select</th>\n"; 
    print "<th class='img'>Reaction OID</th>\n"; 
    print "<th class='img'>Reaction Name</th>\n"; 

    print "<th class='img'>Mandatory?</th>\n"; 
    print "<th class='img'>Reaction Order</th>\n"; 
    for my $k ( sort (keys %db_rxn) ) {
	my ($order2, $rxn_oid) = split ( / /, $k);
	my $val = $db_rxn{$k};

	my ($rxn_name, $comm, $rxn_order, $is_man) = split( /\t/, $val);
        print "<tr class='img'>\n"; 
 
        # select? 
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='rxn_oid' value='$rxn_oid' checked />\n"; 
        print "</td>\n"; 
 
        # rxn_oid with url 
        my $url = "$main_cgi?section=ImgReaction" .
	    "&page=imgRxnDetail&rxn_oid=$rxn_oid";
        print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";

	# rxn_name
	print "<td class='img'>" . escapeHTML( $rxn_name ) . "</td>\n";
 
        # is mandatory
        my $man_name = "man_" . $rxn_order . "_" . $rxn_oid; 
        print "<td class='img'>\n"; 
        print "  <select name='$man_name' id='$man_name'>\n";
	if ( lc($is_man) eq "yes" ) {
	    print "     <option value='Yes' selected>Yes</option>\n";
	}
	else {
	    print "     <option value='Yes'>Yes</option>\n";
	}

	if ( lc($is_man) eq "no" ) {
	    print "     <option value='No' selected>No</option>\n"; 
	}
	else {
	    print "     <option value='No'>No</option>\n"; 
	}
        print "  </select>\n"; 
        print "</td>\n"; 

        # reaction order
        print "<td class='img'>\n";
	print "<input type='text' ";
	my $order_name = "order_" . $rxn_order . "_" . $rxn_oid;
	print "name='$order_name' id='$order_name' value='" .
	    escapeHTML( $rxn_order ) . "' size=4 maxLength=4 /> </td>\n";

	print "</tr>\n";
    }

    # set rxn_order
    my $rxn_order = $max_order;

    if ( $connect_mode == 1 ) {
	# load from IMG Reaction Cart
	my $include_all = 1;
	if ( param( "conn_mode" ) eq "selected" ) {
	    $include_all = 0;
	}

	my $irc = new ImgRxnCartStor( );
	my $recs = $irc->{ recs }; # get records 
	my @cart_rxn_oids = sort{ $a <=> $b }keys( %$recs ); 
	my $selected = $irc->{ selected };

	for my $r_oid ( @cart_rxn_oids ) {
	    my $r = $recs->{ $r_oid };
	    my( $rxn_oid, $rxn_name, $is_reversible, $modified_by, $batch_id ) =
		split( /\t/, $r );

	    $rxn_order++;

	    print "<tr class='img'>\n"; 
 
	    # select? 
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='rxn_oid' value='$rxn_oid' checked />\n"; 
	    print "</td>\n"; 
 
	    # rxn_oid with url 
	    my $url = "$main_cgi?section=ImgReaction" .
		"&page=imgRxnDetail&rxn_oid=$rxn_oid";
	    print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
 
	    # rxn_name
	    print "<td class='img'>" . escapeHTML( $rxn_name ) . "</td>\n";

	    # is mandatory
	    my $man_name = "man_" . $rxn_order . "_" . $rxn_oid; 
	    print "<td class='img'>\n"; 
	    print "  <select name='$man_name' id='$man_name'>\n";
	    print "     <option value='Yes' selected>Yes</option>\n";
	    print "     <option value='No'>No</option>\n"; 
	    print "  </select>\n"; 
	    print "</td>\n"; 

	    # reaction order
	    print "<td class='img'>\n";
	    print "<input type='text' ";
	    my $order_name = "order_" . $rxn_order . "_" . $rxn_oid;
	    print "name='$order_name' id='$order_name' value='" .
		$rxn_order . "' size=4 maxLength=4 /> </td>\n";

	    print "</tr>\n";
	}
    }
    elsif ( $connect_mode == 2 ) {
	# load from selection
	my @selected_rxn_oids = param("rxn_oid");

	my $dbh = dbLogin( ); 
	for my $rxn_oid ( @selected_rxn_oids ) {
	    $rxn_order++;

	    print "<tr class='img'>\n"; 
 
	    my $rxn_name = db_findVal($dbh, 'IMG_REACTION', 'rxn_oid', $rxn_oid,
				      'rxn_name', '');

	    # select? 
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='rxn_oid' value='$rxn_oid' checked />\n"; 
	    print "</td>\n"; 
 
	    # rxn_oid with url 
	    my $url = "$main_cgi?section=ImgReaction" .
		"&page=imgRxnDetail&rxn_oid=$rxn_oid";
	    print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
 
	    # rxn_name
	    print "<td class='img'>" . escapeHTML( $rxn_name ) . "</td>\n";

	    # is mandatory
	    my $man_name = "man_" . $rxn_order . "_" . $rxn_oid; 
	    print "<td class='img'>\n"; 
	    print "  <select name='$man_name' id='$man_name'>\n";
	    print "     <option value='Yes' selected>Yes</option>\n";
	    print "     <option value='No'>No</option>\n"; 
	    print "  </select>\n"; 
	    print "</td>\n"; 

	    # reaction order
	    print "<td class='img'>\n";
	    print "<input type='text' ";
	    my $order_name = "order_" . $rxn_order . "_" . $rxn_oid;
	    print "name='$order_name' id='$order_name' value='" .
		$rxn_order . "' size=4 maxLength=4 /> </td>\n";

	    print "</tr>\n";
	}

	#$dbh->disconnect();
    }

    print "</table>\n";

    print "<br/>\n";

    # print reaction names as hidden var
    for my $k ( sort (keys %db_rxn) ) {
	my ($order2, $rxn_oid) = split ( / /, $k);
	my $val = $db_rxn{$k};

	my ($rxn_name, $comm, $rxn_order, $is_man) = split( /\t/, $val);
	my $rn_tag = "rxnname_" . $rxn_order . "_" . $rxn_oid;
	my $r_name = escapeHTML( $rxn_name );
	print "<input type='hidden' name='$rn_tag' value='$r_name' />\n"; 
    }

    if ( $connect_mode == 1000 ) {
	my $rxn_order = $max_order;

	# load from IMG Reaction Cart
	my $irc = new ImgRxnCartStor( );
	my $recs = $irc->{ recs }; # get records 
 
	my @cart_rxn_oids = sort{ $a <=> $b }keys( %$recs ); 

	for my $r_oid ( @cart_rxn_oids ) {
	    my $r = $recs->{ $r_oid };
	    my( $rxn_oid, $rxn_name, $is_reversible, $modified_by, $batch_id ) =
		split( /\t/, $r );

	    $rxn_order++;
	    my $rn_tag = "rxnname_" . $rxn_order . "_" . $rxn_oid;
	    my $r_name = escapeHTML( $rxn_name );
	    print "<input type='hidden' name='$rn_tag' value='$r_name' />\n"; 
	}
    }

    print end_form( );
}


############################################################################ 
# printConfirmUpdatePwayRxnForm - confirm update pathway-reaction
############################################################################ 
sub printConfirmUpdatePwayRxnForm { 
    my ( $connect ) = @_;

    print "<h1>Confirm IMG Pathway Reaction Update Page</h1>\n"; 
 
    printMainForm( );

    my $pathway_oid = param("selectedPways");
    $pathway_oid =~ s/\s+$//;
    my $pathway_name = param("selectedPwayName");
    print "<h2>Pathway ($pathway_oid): " . escapeHTML($pathway_name) . "</h2>\n";

    if ( $pathway_oid eq "" ) {
	webError ("No IMG pathway is selected.");
	return; 
    } 

    ## Set parameters. 
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedPways", $pathway_oid );

    # show selected reactions
    print "<h3>Reactions in Pathway</h3>\n";

    print "<p>The selected pathway will be updated to be associated with the following reactions:</p>\n";

    print "<table class='img'>\n"; 
    print "<th class='img'>Reaction OID</th>\n"; 
    print "<th class='img'>Reaction Name</th>\n"; 

    print "<th class='img'>Mandatory?</th>\n"; 
    print "<th class='img'>Reaction Order</th>\n"; 

    my %rxn_data;
    my $dbh = dbLogin();

    my $query = WebUtil::getCgi();

    my @rxn_oids = param("rxn_oid");
    for my $rxn_oid ( @rxn_oids ) {
	print "<tr class='img'>\n"; 
 
	# rxn_oid with url 
	my $url = "$main_cgi?section=ImgReaction" .
	    "&page=imgRxnDetail&rxn_oid=$rxn_oid";
	print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
 
	for my $p ( $query->param() ) {
	    my ($lab, $ord, $id2) = split (/\_/, $p);
	    if ( $lab eq "order" && $id2 eq $rxn_oid ) {
		my $tag = "_" . $ord . "_" . $id2;

		my $rxn_name = db_findVal($dbh, 'IMG_REACTION', 'rxn_oid', $rxn_oid,
					  'rxn_name', '');
		print "<td class='img'>" . escapeHTML( $rxn_name ) . "</td>\n";

		my $man_tag = "man" . $tag;
		my $is_man = param($man_tag);
		print "<td class='img'>" . $is_man . "</td>\n";

		my $ord_tag = "order" . $tag;
		my $rxn_order = param($ord_tag);
		print "<td class='img'>" . escapeHTML($rxn_order) . "</td>\n";

		# check rxn_order (must be a positive integer)
		if ( isInt($rxn_order) ) {
		    # is integer
		    if ( $rxn_order <= 0 ) {
			print "</tr>\n";
			print "</table>\n";
			#$dbh->disconnect();
			webError ("Reaction order must be a positive integer. Input '$rxn_order' <= 0.");
			return;
		    }
		}
		else {
		    # not integer
		    print "</tr>\n";
		    print "</table>\n";
		    #$dbh->disconnect();
		    webError ("Reaction order must be an integer. Input '$rxn_order' is not an integer.");
		    return;
		}

		# save data
		my $key = sprintf("data_%6d_%4d", $rxn_oid, $rxn_order);
		my $val = "$rxn_oid\t$rxn_order\t$is_man";
		$rxn_data{$key} = $val;
	    }
	}

	print "</tr>\n";
    }

    print "</table>\n";
    #$dbh->disconnect();

    # using hidden parameters to save data
    for my $key (keys %rxn_data) {
	my $val = $rxn_data{$key};
	print hiddenVar( $key, $val );
    }
    
    # add Update and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbUpdatePwayRxn";
    print submit( -name => $name,
		  -value => 'Update Pathway-Reaction', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}

############################################################################ 
# dbUpdatePwayRxn - perform database update for pathway-reaction
############################################################################ 
sub dbUpdatePwayRxn {
    my $query = WebUtil::getCgi();

    # get pathway_oid
    my $pathway_oid = param("selectedPways");
    my @sqlList = (); 

    my $sql = "delete from IMG_PATHWAY_REACTIONS where pathway_oid = $pathway_oid";
    push @sqlList, ( $sql );

    for my $p ( $query->param() ) {
	my ($lab, $ord, $id2) = split (/\_/, $p);
	if ( $lab eq "data" ) {
	    # data item
	    my $val = param($p);
	    my ($rxn_oid, $rxn_order, $is_man) = split (/\t/, $val);

	    $sql = "insert into IMG_PATHWAY_REACTIONS " .
		"(pathway_oid, rxn_order, is_mandatory, rxn) " .
		"values (" . $pathway_oid . ", " . $rxn_order .
		", '" . $is_man . "', " . $rxn_oid . ")";
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
# printFileUploadPwayRxnForm
############################################################################
sub printFileUploadPwayRxnForm {
    print "<h1>Upload IMG Pathway - Reaction Associations from File</h1>\n";

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
    print "<li>Containing 4 columns: (1) IMG Pathway OID, (2) IMG Reaction OID, ";
    print "(3) Mandatory?: 'Yes' or 'No', (4) Reaction Order</li>\n";
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
    my $name = "_section_${section}_validatePwayRxnFile";
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
# printValidatePwayRxnForm
############################################################################
sub printValidatePwayRxnForm {
    print "<h1>IMG Pathway-Reaction File Validation Result</h1>\n";

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
    my $tmp_upload_file = $cgi_tmp_dir . "/upload.pwayrxn." . $sessionId . ".txt";

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
    my $name = "_section_${section}_dbPwayRxnFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Line No.</th>\n";
    print "<th class='img'>Pathway OID</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Mandatory?</th>\n";
    print "<th class='img'>Reaction Order</th>\n";
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
        my ($pathway_oid, $rxn_oid, $is_man, $rxn_order) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	my $msg = "";
	my $hasError = 0;

        print "<tr class='img'>\n";

	print "<td class='img'>" . $line_no . "</td>\n";

	# check pathway_oid
	$pathway_oid = strTrim($pathway_oid);
	if ( blankStr($pathway_oid) ) {
	    $hasError = 1;
	    $msg = "Error: Pathway OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $pathway_oid ) . "</td>\n";
	}
	elsif ( !isInt($pathway_oid) ) {
	    $hasError = 1;
	    $msg = "Error: Incorrect Pathway OID '" . escapeHTML($pathway_oid) .
		"'. ";
	    print "<td class='img'>" . escapeHTML( $pathway_oid ) . "</td>\n";
	}
	else {
	    my $cnt1 = db_findCount($dbh, 'IMG_PATHWAY', "pathway_oid = $pathway_oid");
	    if ( $cnt1 <= 0 ) {
		$hasError = 1;
		$msg = "Error: Pathway OID $pathway_oid is not in the database. ";
		print "<td class='img'>" . escapeHTML( $pathway_oid ) . "</td>\n";
	    }
	    else {
		# show hyperlink
		$pathway_oid = FuncUtil::pwayOidPadded($pathway_oid);
		my $url = "$main_cgi?section=ImgPwayBrowser" . 
		    "&page=imgPwayDetail&pway_oid=$pathway_oid";
		print "<td class='img'>" . alink( $url, $pathway_oid ) . "</td>\n";
	    }
	}

	# check rxn_oid
	$rxn_oid = strTrim($rxn_oid);
	if ( blankStr($rxn_oid) ) {
	    $hasError = 1;
	    $msg .= "Error: Reaction OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $rxn_oid ) . "</td>\n";
	}
	elsif ( !isInt($rxn_oid) ) {
	    $hasError = 1;
	    $msg .= "Error: Incorrect Reaction OID '" . escapeHTML($rxn_oid) .
		"'. ";
	    print "<td class='img'>" . escapeHTML( $rxn_oid ) . "</td>\n";
	}
	else {
	    my $cnt2 = db_findCount($dbh, 'IMG_REACTION', "rxn_oid = $rxn_oid");
	    if ( $cnt2 <= 0 ) {
		$hasError = 1;
		$msg .= "Error: Reaction OID $rxn_oid is not in the database. ";
		print "<td class='img'>" . escapeHTML( $rxn_oid ) . "</td>\n";
	    }
	    else {
		# show hyperlink
		$rxn_oid = FuncUtil::rxnOidPadded($rxn_oid);
		my $url = "$main_cgi?section=ImgReaction" . 
		    "&page=imgRxnDetail&rxn_oid=$rxn_oid";
		print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
	    }
	}

	# check mandatory?
	$is_man = strTrim($is_man);
	if ( $is_man =~ /^\s*"(.*)"$/ ) { 
	    ($is_man) = ($is_man =~ /^\s*"(.*)"$/);
	    $is_man = strTrim($is_man);
	}
	print "<td class='img'>" . escapeHTML( $is_man ) . "</td>\n";

	if ( blankStr($is_man) ) {
	    # it's ok to have blank
	}
	elsif ( lc($is_man) ne 'yes' &&
		lc($is_man) ne 'no' &&
		lc($is_man) ne 'unknown' ) {
	    $msg .= "Error: Mandatory field should be 'Yes' or 'No'. ";
	}

	# check rxn_order
	$rxn_order = strTrim($rxn_order);
	if ( $rxn_order =~ /^\s*"(.*)"$/ ) { 
	    ($rxn_order) = ($rxn_order =~ /^\s*"(.*)"$/);
	    $rxn_order = strTrim($rxn_order);
	}
	print "<td class='img'>" . escapeHTML( $rxn_order ) . "</td>\n";

	if ( blankStr($rxn_order) ) {
	    $hasError = 1;
	    $msg .= "Error: No reaction order is specified. ";
	}
	elsif ( ! isInt($rxn_order) ) {
	    $hasError = 1;
	    $msg .= "Error: Reaction order must be an integer. ";
	}

	if ( $hasError == 0 && $replace == 0 ) {
            # check whether pathway-reaction association already exist 
	    # with the same order
            my $cnt3 = db_findCount ($dbh, 'IMG_PATHWAY_REACTIONS', 
				     "pathway_oid = $pathway_oid " .
				     "and rxn = $rxn_oid " .
				     "and rxn_order = $rxn_order");

            if ( $cnt3 > 0 ) { 
                $msg .= "Error: Pathway-Reaction-Order association already exists."; 
            } 
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
    my $name = "_section_${section}_dbPwayRxnFileUpload";
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
# dbPwayRxnFileUpload - handle the actual data upload
############################################################################
sub dbPwayRxnFileUpload {
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

    my @rxn_oids;
    my @pathway_oids;

    my $line_no = 0;
    my $line;
    while ($line = <FILE>) {
	chomp($line);
        my ($pathway_oid, $rxn_oid, $is_man, $rxn_order) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	# check pathway_oid
	$pathway_oid = strTrim($pathway_oid);
	if ( blankStr($pathway_oid) ) {
	    next;
	}
	elsif ( !isInt($pathway_oid) ) {
	    next;
	}
	else {
	    my $cnt1 = db_findCount($dbh, 'IMG_PATHWAY', "pathway_oid = $pathway_oid");
	    if ( $cnt1 <= 0 ) {
		next;
	    }
	}

	# check rxn_oid
	$rxn_oid = strTrim($rxn_oid);
	if ( blankStr($rxn_oid) ) {
	    next;
	}
	elsif ( !isInt($rxn_oid) ) {
	    next;
	}
	else {
	    my $cnt2 = db_findCount($dbh, 'IMG_REACTION', "rxn_oid = $rxn_oid");
	    if ( $cnt2 <= 0 ) {
		next;
	    }
	}

	# check mandatory?
	$is_man = strTrim($is_man);
	if ( $is_man =~ /^\s*"(.*)"$/ ) { 
	    ($is_man) = ($is_man =~ /^\s*"(.*)"$/);
	    $is_man = strTrim($is_man);
	}
	if ( blankStr($is_man) ) {
	    # it's ok to have blank
	}
	elsif ( lc($is_man) ne 'yes' &&
		lc($is_man) ne 'no' &&
		lc($is_man) ne 'unknown' ) {
	    next;
	}

	# check rxn_order
	$rxn_order = strTrim($rxn_order);
	if ( $rxn_order =~ /^\s*"(.*)"$/ ) { 
	    ($rxn_order) = ($rxn_order =~ /^\s*"(.*)"$/);
	    $rxn_order = strTrim($rxn_order);
	}
	if ( blankStr($rxn_order) ) {
	    next;
	}
	elsif ( ! isInt($rxn_order) ) {
	    next;
	}

	# save pathway_oid
	if ( ! WebUtil::inArray($pathway_oid, @pathway_oids) ) {
	    push @pathway_oids, ( $pathway_oid );

	    # generate delete statement for replace mode
	    if ( $replace ) {
		$sql = "delete from IMG_PATHWAY_REACTIONS " .
		    "where pathway_oid = $pathway_oid";
		push @sqlList, ( $sql );
	    }
	}

	# save rxn_oid
	if ( ! WebUtil::inArray($rxn_oid, @rxn_oids) ) {
	    push @rxn_oids, ( $rxn_oid );
	}

	# database update
	$sql = "insert into IMG_PATHWAY_REACTIONS " .
	    "(pathway_oid, rxn, is_mandatory, rxn_order) ";
	$sql .= "values ($pathway_oid, $rxn_oid, ";
	if ( lc($is_man) eq 'yes' ) {
	    $sql .= "'Yes', ";
	}
	else {
	    $sql .= "'No', ";
	}
	$sql .= $rxn_order . ")";
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
	# update pathway cart
	if ( scalar(@pathway_oids) > 0 ) {
	    my $ipc = new ImgPwayCartStor( );
	    $ipc->addImgPwayBatch( \@pathway_oids );
	}

	# update reaction cart
	if ( scalar(@rxn_oids) > 0 ) {
	    my $irc = new ImgRxnCartStor( );
	    $irc->addImgRxnBatch( \@rxn_oids );
	}
    }
}


1;

