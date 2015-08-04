############################################################################
# ImgRxnCartStor
#   imachen 01/03/2007
###########################################################################
package ImgRxnCartStor;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use DataEntryUtil;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };

my $verbose = $env->{ verbose };

my $section = "ImgRxnCartStor";
my $section_cgi = "$main_cgi?section=$section";

my $max_rxn_batch = 250;
my $contact_oid = getContactOid( );



############################################################################
# dispatch - Dispatch pages for this section.
#   All page links to this same section should be in the form of
#
#   my $url = "$main_cgi?section=$section&page=..." 
#
############################################################################
sub dispatch {

    my $page = param( "page" );
    if( $page ne "" ) {
	# follow through
    }
    elsif ( paramMatch( "index" ) ne "" ) {
	$page = "index";
    }
    elsif ( paramMatch( "imgRxnCurationPage" ) ne "" ) {
	$page = "imgRxnCurationPage";
    }
    elsif( paramMatch( "addToImgRxnCart" ) ne "" ) {
	# add rxn_oid's to RxnCart
	my $irc = new ImgRxnCartStor( );
	# my @rxn_oids = param( "rxn_oid" );
	# $irc->addImgRxnBatch( \@rxn_oids );

	# show reaction cart
        $irc->printRxnCartForm( "add" );
    }
    elsif ( paramMatch( "deleteSelectedCartImgRxns" ) ne "" ) {
        # remove selected items from the cart
        my $irc = new ImgRxnCartStor( );
        $irc->webRemoveImgRxns( );
 
        # show the new index page
        $page = "index";
    } 
    elsif ( paramMatch( "ImgRxnCartDataEntry" ) ne "" ) {
	printImgRxnCurationPage( );
    }
    elsif ( paramMatch( "addRxnForm" ) ne "" ) {
	printAddUpdateRxnForm( 0 );
    }
    elsif ( paramMatch( "dbAddRxn" ) ne "" ) {
	my $new_oid = dbAddRxn();

	if ( $new_oid > 0 ) {
	    # add new oids to reaction cart
	    my $irc = new ImgRxnCartStor( ); 
	    my @rxn_oids = param( "rxn_oid" );
	    push @rxn_oids, ( $new_oid );
	    $irc->addImgRxnBatch( \@rxn_oids );
	}

	# go to the curation page
	$page = "imgRxnCurationPage";
    }
    elsif ( paramMatch( "confirmDeleteRxnForm" ) ne "" ) {
	printConfirmDeleteRxnForm( );
    }
    elsif ( paramMatch( "deleteRxnForm" ) ne "" ) {
	my $old_oid = dbDeleteRxn();
	if ( $old_oid > 0 ) {
	    my $irc = new ImgRxnCartStor( ); 
	    my $recs = $irc->{ recs }; # get records 
	    my $selected = $irc->{ selected };
	    delete $recs->{ $old_oid };
	    delete $selected->{ $old_oid };
	    $irc->save( );
	}

	# go to the curation page
	$page = "imgRxnCurationPage";
    }
    elsif ( paramMatch( "updateRxnForm" ) ne "" ) {
	printAddUpdateRxnForm( 1 );
    }
    elsif( paramMatch( "dbUpdateRxn" ) ne "" ) {
	my $old_oid = dbUpdateRxn();
 
	if ( $old_oid > 0 ) {
	    # update reaction info
	    my $irc = new ImgRxnCartStor( ); 
	    # my $recs = $irc->{ recs }; # get records 
	    # my @rxn_oids = sort{ $a <=> $b }keys( %$recs );
            my @rxn_oids = ( $old_oid );
	    $irc->addImgRxnBatch( \@rxn_oids );
	}

	# go to the curation page
	$page = "imgRxnCurationPage";
    }


    if( $page eq "index" ) {
	# root page
        printIndex( );
    }
    elsif ( $page eq "imgRxnCurationPage" ) {
	printImgRxnCurationPage( );
    }
    elsif ( $page eq "" ) {
	# do nothing
    }
    else {
        print "<h1>Invalid Page: $page</h1>\n";
    }
}

############################################################################
# printIndex - Show root page.
############################################################################
sub printIndex {
    my $irc = new ImgRxnCartStor( ); 
    $irc->printRxnCartForm();
}


############################################################################
# new - New instance.
############################################################################
sub new {
    my( $myType, $baseUrl ) = @_;

    $baseUrl = "$section_cgi&page=imgRxnCart" if $baseUrl eq "";
    my $self = { };
    bless( $self, $myType );
    my $stateFile = $self->getStateFile( );
    if( -e $stateFile ) {
	$self = retrieve( $stateFile );
    }
    else {
	my %h1;
	my %h2;
	$self->{ recs } = \%h1;
	$self->{ selected } = \%h2;
	$self->{ baseUrl } = $baseUrl;
	$self->save( );
    }


    bless( $self, $myType );
    return $self;
}

############################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
    my( $self ) = @_;
    my $sessionId = getSessionId( );
    my $sessionFile = "$cgi_tmp_dir/imgRxnCart.$sessionId.stor";
}


############################################################################
# save - Save in persistent state.
############################################################################
sub save {
    my( $self ) = @_;
    store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# webAddImgRxns - Load IMG reaction cart from selections.
############################################################################
sub webAddImgRxns {
    my( $self ) = @_;
    my @rxn_oids = param( "rxn_oid" );
    $self->addImgRxnBatch( \@rxn_oids );
}


############################################################################
# addImgRxnBatch - Add reactions in a batch.
############################################################################
sub addImgRxnBatch {
    my( $self, $rxn_oids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "imgRxn" );
    
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $rxn_oid ( @$rxn_oids_ref ) {
	if( scalar( @batch ) > $max_rxn_batch ) {
	    $self->flushImgRxnBatch( $dbh, \@batch, $batch_id );
	    @batch = ( );
	}
	push( @batch, $rxn_oid );
	$selected->{ $rxn_oid } = 1;
    }

    $self->flushImgRxnBatch( $dbh, \@batch, $batch_id );
    ##$dbh->disconnect();
    $self->save( );
}


############################################################################
# flushImgRxnBatch  - Flush one batch.
############################################################################
sub flushImgRxnBatch {
    my( $self, $dbh, $rxn_oids_ref, $batch_id ) = @_;

    return if( scalar( @$rxn_oids_ref ) == 0 ); 
    my $rxn_oid_str = join( ',', @$rxn_oids_ref );

    my $recs = $self->{ recs };

    my $sql = qq{
        select ir.rxn_oid, ir.rxn_name, ir.is_reversible, c.name
	    from img_reaction ir, contact c
	    where ir.rxn_oid in( $rxn_oid_str )
	    and ir.modified_by = c.contact_oid
	};

    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
	my( $rxn_oid, $rxn_name, $is_reversible, $modified_by ) = $cur->fetchrow( );
	# print "<p>rxn: $rxn_oid, $rxn_name</p>\n";
	last  if !$rxn_oid;
	$rxn_oid = FuncUtil::rxnOidPadded( $rxn_oid );
	$count++;
	my $r = "$rxn_oid\t";
	$r .= "$rxn_name\t";
	$r .= "$is_reversible\t";
	$r .= "$modified_by\t";
	$r .= "$batch_id\t";
	$recs->{ $rxn_oid } = $r;
    }
}


############################################################################
# webRemoveImgRxns - Remove IMG reactions
############################################################################
sub webRemoveImgRxns {
    my( $self ) = @_;
    my @rxn_oids = param( "rxn_oid" );
    my $recs = $self->{ recs };
    my $selected = $self->{ selected };
    for my $rxn_oid( @rxn_oids ) {
	delete $recs->{ $rxn_oid };
	delete $selected->{ $rxn_oid };
    }
    $self->save( );
}


############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
    my( $self ) = @_;
    my @rxn_oids = param( "rxn_oid" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $rxn_oid( @rxn_oids ) {
	$selected->{ $rxn_oid } = 1;
    }
    $self->save( );
}



############################################################################
# printReactionCartForm - Show form for showing reaction cart.
############################################################################
sub printRxnCartForm {
    my( $self, $load ) = @_;

    if( $load eq "add" ) {
	printStatusLine( "Loading ...", 1 );
	$self->webAddImgRxns( );
    }
    my $dbh = dbLogin( );
    my $contact_oid = getContactOid( );

    setSessionParam( "lastCart", "imgRxnCart" );
    printMainForm( );

    print "<h1>IMG Reaction Cart</h1>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );

    my $recs = $self->{ recs };
    my @rxn_oids = sort( keys( %$recs ) );
    my $count = @rxn_oids;
    if( $count == 0 ) {
	print "<p>\n";
	print "0 reactions in IMG Reaction cart.\n";
	print "</p>\n";
	printStatusLine( "0 reactions in cart", 2 );
    }

    if( isImgEditor( $dbh, $contact_oid ) ) {
	print "<h2>IMG Reaction Curation</h2>\n";
	print "<p>\n";
	print "Add, delete, and edit IMG reactions.<br/>\n";
	print "</p>\n";
        my $name = "_section_${section}_ImgRxnCartDataEntry";
	print submit( -name => $name,
		      -value => "IMG Reaction Curation", -class => "medbutton " );
	print "<br/>\n";
    }

    if( $count == 0 ) {
	##$dbh->disconnect();
        return;
    }

    print "<p>\n";
    print "$count reaction(s) in cart\n";
    print "</p>\n";

    my $name = "_section_${section}_deleteSelectedCartImgRxns";
    print submit( -name => $name,
		  -value => "Remove Selected", -class => 'smdefbutton' );
    print " ";
    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Selection</th>\n";
    $self->printSortHeaderLink( "Reaction<br/>Object<br/>ID", 0 );
    $self->printSortHeaderLink( "Reaction Name", 1 );
    $self->printSortHeaderLink( "Batch<sup>1</sup>", 2 );
    my @sortedRecs;
    my $sortIdx = param( "sortIdx" );
    $sortIdx = 2 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{ selected };
    for my $r( @sortedRecs ) {
	my( $rxn_oid, $rxn_name,  $is_reversible, $modified_by, $batch_id ) =
	    split( /\t/, $r );
	$rxn_oid = FuncUtil::rxnOidPadded( $rxn_oid );
	print "<tr class='img'>\n";
	print "<td class='checkbox'>\n";
	my $ck;
	$ck = "checked" if $selected->{ $rxn_oid } ne "";
       print "<input type='checkbox' name='rxn_oid' " . 
	   "value='$rxn_oid' $ck />\n";
	print "</td>\n";
	my $url = "$main_cgi?section=ImgReaction" . 
	   "&page=imgRxnDetail&rxn_oid=$rxn_oid";
	print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
	print "<td class='img'>" . escHtml( $rxn_name ) . "</td>\n";
	print "<td class='img'>$batch_id</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";
    print "<p>\n";
    print "1 - Each time a set of reactions is added to the cart, " .
	"a new distinguishing batch number is generated for the set.<br/>\n";
    print "</p>\n";
    printStatusLine( "$count reaction(s) in cart", 2 );

    print end_form( );
    ##$dbh->disconnect();
    $self->save( );
}


############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
    my( $self, $name, $sortIdx ) = @_;

    my $baseUrl = $self->{ baseUrl };
    my $url = $baseUrl;
    $url .= "&sortIdx=$sortIdx";
    print "<th class='img'>";
    print alink( $url, $name, "", 1 );
    print "</th>\n";
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my( $self, $sortIdx, $outRecs_ref ) = @_;
    my $recs = $self->{ recs };
    my @rxn_oids = keys( %$recs );
    my @a;
    my @idxVals;
    for my $rxn_oid ( @rxn_oids ) {
	my $rec = $recs->{ $rxn_oid };
	my @fields = split( /\t/, $rec );
	my $sortRec;
	my $sortFieldVal = $fields[ $sortIdx ];
	if( $sortIdx == 0 || $sortIdx == 2 ) {
	    $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $rxn_oid );
	}
	else {
	    $sortRec = sprintf( "%s\t%s", $sortFieldVal, $rxn_oid );
	}
	push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort( @idxVals );
    for my $i( @idxValsSorted ) {
	my( $idxVal, $rxn_oid ) = split( /\t/, $i );
	my $r = $recs->{ $rxn_oid };
	push( @$outRecs_ref, $r );
    }
}


############################################################################
############################################################################
# The following code is for data entry
############################################################################
############################################################################

############################################################################
# printImgRxnCurationPage - Show curation main page.
############################################################################
sub printImgRxnCurationPage {
    print "<h1>IMG Reaction Curation Page</h1>\n";
    printMainForm( );

    print "<p>\n";

    print "<h3>Note: This page only allows single IMG reaction selection.</h3>\n";

    # list all reactions
    my $irc = new ImgRxnCartStor( );

    my $recs = $irc->{ recs }; # get records

    my @rxn_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are rxn_oids. 
        # But we want them sorted. 

    # print count 
    my $count = scalar( @rxn_oids ); 
    print "<p>\n"; 
    print "$count reaction(s) in cart\n"; 
    print "</p>\n"; 

    ### Print the records out in a table. 
    print "<table class='img'>\n"; 
    print "<th class='img'>Select for<br/>Delete/Update</th>\n";
    print "<th class='img'>Reaction ID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";
    print "<th class='img'>Is Reversible?</th>\n";
    print "<th class='img'>Modified by</th>\n";
    print "<th class='img'>Batch</th>\n";
    for my $rxn_oid ( @rxn_oids ) {
	my $i = $rxn_oid;

        my $r = $recs->{ $rxn_oid };
        my( $rxn_oid, $rxn_name, $is_reversible, $modified_by, $batch_id ) =
	    split( /\t/, $r );

        print "<tr class='img'>\n"; 

        print "<td class='img'>\n"; 
        print "<input type='radio' ";
        print "name='rxn_oid' value='$rxn_oid' />\n";
        print "</td>\n"; 
 
	# rxn_oid with url
	my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$rxn_oid";
        print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";

	# rxn_name
        print "<td class='img'>" . escapeHTML( $rxn_name ) . "</td>\n";

	# is reversible
	print "<td class='img'>" . escapeHTML( $is_reversible ) . "</td>\n";

	# modified by
	print "<td class='img'>" . escapeHTML( $modified_by ) . "</td>\n";

	# batch_id
        print "<td class='img'>" . escapeHTML( $batch_id ) . "</td>\n";
        print "</tr>\n"; 
    } 
    print "</table>\n";

    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );

    # add New, Delete and Update IMG Reaction button
    my $name = "_section_${section}_addRxnForm";
    print submit( -name => $name,
		  -value => 'New IMG Reaction', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteRxnForm";
    print submit( -name => $name,
		  -value => 'Delete IMG Reaction', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_updateRxnForm";
    print submit( -name => $name,
		  -value => 'Update IMG Reaction', -class => 'smbutton' );

    print "</p>\n";

    print end_form( );
}


############################################################################
# printAddUpdateRxnForm - add or update IMG reaction
############################################################################
sub printAddUpdateRxnForm {
    my ( $update ) = @_;   # add or update

    if ( $update ) {
	print "<h1>Update IMG Reaction Page</h1>\n";
    }
    else {
	print "<h1>Add IMG Reaction Page</h1>\n";
    }

    printMainForm( );

    # add Add/Update, Reset and Cancel buttons
    if ( $update ) {
        my $name = "_section_${section}_dbUpdateRxn";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddRxn";
	print submit( -name => $name,
		      -value => 'Add', -class => 'smdefbutton' );
    }

    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_imgRxnCurationPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    # save selected reaction oids
    my $irc = new ImgRxnCartStor( ); 
    my $recs = $irc->{ recs }; # get records 

    my @rxn_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are reaction_oids. 
        # But we want them sorted. 
 
    # get selected reaction oids
    my @selected_rxn_oids = param( "rxn_oid" ); 
    my %selected_rxn_oids_h; 
    for my $rxn_oid( @selected_rxn_oids ) { 
	$selected_rxn_oids_h{ $rxn_oid } = 1; 
    } 

    ## Set parameters.
    print hiddenVar( "section", $section );

    # get selected reaction oids
    # need to record all selected reactions
    # save reaction selections in a hidden variable 
    print "<input type='hidden' name='selectedRxns' value='"; 
    for my $rxn_oid ( @selected_rxn_oids ) { 
        print "$rxn_oid "; 
    } 
    print "'>\n"; 

    my $update_rxn_oid = -1;
    if ( $update ) {
	if ( scalar (@selected_rxn_oids) > 0 ) {
	    $update_rxn_oid = $selected_rxn_oids[0];
	}
	else {
	    webError ("No IMG reaction is selected.");
	    return;
	}
    }

    # if it is update, then we need to get reaction info from the database
    my $db_rxn_name = "";
    my $db_def = "";
    my $db_eqn = "";
    my $db_rev = "";
    my $db_comm = "";
    # my @db_syn = ();
    if ( $update && $update_rxn_oid > 0 ) {
	my $dbh = dbLogin( );
	my $sql = qq{
	        select ir.rxn_name, ir.rxn_definition, ir.rxn_equation,
		    ir.is_reversible, ir.comments
		    from img_reaction ir
		    where ir.rxn_oid = $update_rxn_oid
		};

	my $cur = execSql( $dbh, $sql, $verbose );
	($db_rxn_name, $db_def, $db_eqn, $db_rev, $db_comm) = $cur->fetchrow( );
	$cur->finish( );


	##$dbh->disconnect();
    }

    print "<h2>Reaction Information</h2>\n";
    
    print "<table class='img' border='1'>\n";

    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Reaction Name</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='newName' value='" .
	escapeHTML($db_rxn_name) . "' size='100' maxLength='1000'/>" . "</td>\n";
    print "</tr>\n";

    # Definition
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Definition</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='textarea' name='rxnDef' value='" .
	escapeHTML($db_def) . "' size='100' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    # Equation
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Equation</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='rxnEqn' value='" .
	escapeHTML($db_eqn) . "' size='100' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    # Is Reversible?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Reversible?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='revSelection' class='img' size='4'>\n";
    for my $tt ( ('', 'Yes', 'No', 'Unknown') ) {
	print "        <option value='$tt'";
	if ( (uc $db_rev) eq (uc $tt) ) {
	    print " selected";
	}
	print ">$tt</option>\n";
    }
    print "     </select>\n";
    print "</td>\n</tr>\n";

    # Comments
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Comment</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='rxnComments' value='" .
	escapeHTML($db_comm) . "' size='100' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    # add synonyms

    # end
    print end_form( );
}


############################################################################
# printConfirmDeleteRxnForm - ask user to confirm deletion
############################################################################
sub printConfirmDeleteRxnForm {
    print "<h1>Delete IMG Reaction Page</h1>\n";

    printMainForm( );

    # get the term oid
    my @selected_rxn_oids = param( "rxn_oid" ); 
    if ( scalar (@selected_rxn_oids) == 0 ) {
	@selected_rxn_oids = param( "selectedRxns" );
    }
    if ( scalar (@selected_rxn_oids) == 0 ) {
	webError ("No IMG reaction is selected.");
	return -1;
    }

    my $rxn_oid = $selected_rxn_oids[0];

    # get reaction name
    my $irc = new ImgRxnCartStor( ); 
    my $recs = $irc->{ recs }; # get records 
    my $r = $recs->{ $rxn_oid }; 
    my( $r_oid, $r_name, $r_rev, $r_mod, $batch_id ) = split( /\t/, $r );

    print "<h2>IMG Reaction: ($r_oid) $r_name</h2>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedRxns", $rxn_oid );

    print "<p><font color=\"red\" >";
    print "Warning: The following pathway-reaction association " .
	"and reaction-compound association " .
	"will be deleted as well.</font></p>\n";

    my $dbh = dbLogin( );

    # show pathway - reaction association
    print "<h3>IMG Pathway - Reaction Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Pathway OID</th>\n";
    print "<th class='img'>Pathway Name</th>\n";
    print "<th class='img'>Reaction Order</th>\n";
    print "<th class='img'>Is Mandatory?</th>\n";

    # IMG_PATHWAY_REACTIONS
    my $sql = qq{
	select p.pathway_oid, p.pathway_name, pr.rxn_order, pr.is_mandatory
	        from img_pathway p, img_pathway_reactions pr
		    where p.pathway_oid = pr.pathway_oid
		        and pr.rxn = $rxn_oid
		    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $p_oid, $p_name, $r_order, $r_man ) = $cur->fetchrow( );
	last if !$p_oid;

	$p_oid = FuncUtil::pwayOidPadded($p_oid);

	print "<tr class='img'>\n";
        my $url = "$main_cgi?section=ImgPwayBrowser" . 
	   "&page=imgPwayDetail&pway_oid=$p_oid";
        print "<td class='img'>" . alink( $url, $p_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $p_name ) . "</td>\n";
        print "<td class='img'>" . $r_order . "</td>\n";
        print "<td class='img'>" . escapeHTML( $r_man ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    # show reaction-compound association 
    print "<h3>IMG Reaction - Compound Association to be Deleted:</h3>\n"; 
 
    print "<table class='img'>\n"; 
    print "<th class='img'>Reaction OID</th>\n"; 
    print "<th class='img'>Compound OID</th>\n"; 
    print "<th class='img'>Compound Name</th>\n"; 
    print "<th class='img'>C_Type</th>\n"; 
 
    # IMG_REACTION_C_COMPONENTS 
    my $sql = qq{ 
        select ircc.rxn_oid, ircc.compound, c.compound_name, ircc.c_type 
                from img_compound c, img_reaction_c_components ircc 
                    where ircc.rxn_oid = $rxn_oid 
                        and ircc.compound = c.compound_oid 
                    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    for( ;; ) { 
        my( $r_oid, $c_oid, $c_name, $c_type ) = $cur->fetchrow( ); 
        last if !$c_oid; 

	$c_oid = FuncUtil::compoundOidPadded($c_oid);

        print "<tr class='img'>\n"; 
        my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$rxn_oid"; 
        print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n"; 
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$c_oid"; 
        print "<td class='img'>" . alink( $url, $c_oid ) . "</td>\n"; 
        print "<td class='img'>" . escapeHTML( $c_name ) . "</td>\n"; 
        print "<td class='img'>" . escapeHTML( $c_type ) . "</td>\n"; 
    } 
    $cur->finish( ); 
 
    print "</table>\n"; 

    ##$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_deleteRxnForm";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_imgRxnCurationPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n"; # paragraph section puts text in proper font.
}


############################################################################
# dbAddRxn - add a new reaction to the database
############################################################################
sub dbAddRxn() {
    # get input parameters
    my $rxn_name = param ('newName');
    my $rxn_def = param ('rxnDef');
    my $rxn_eqn = param ('rxnEqn');
    my $is_reversible = param ('revSelection');
    my $comm = param ('rxnComments');

    # check input
    chomp($rxn_name);
    if ( !$rxn_name || blankStr($rxn_name) ) {
	webError ("Please enter a new reaction name.");
	return -1;
    }

    # login
    my $dbh = dbLogin(); 

    my @sqlList = ();

    # get sysdate
    my $sql = "select sysdate from dual";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $sysdate = "";
    for (;;) { 
        my ( $d1 ) = $cur->fetchrow( );
        last if !$d1;
 
	$sysdate = $d1;
    }
    $cur->finish( );

    # get next oid
    my $new_rxn_oid = db_findMaxID( $dbh, 'IMG_REACTION', 'RXN_OID') + 1;
    #$dbh->disconnect();

    # prepare insertion
    my $ins = "insert into IMG_REACTION (rxn_oid, rxn_name";
    my $s = $rxn_name;
    $s =~ s/'/''/g;  # replace ' by ''
    my $vals = "values ($new_rxn_oid, '". $s . "'";

    if ( $rxn_def && length($rxn_def) > 0 ) {
	$rxn_def =~ s/'/''/g;  # replace ' by ''
	$ins .= ", rxn_definition";
	$vals .= ", '$rxn_def'";
    }

    if ( $rxn_eqn && length($rxn_eqn) > 0 ) {
	$rxn_eqn =~ s/'/''/g;  # replace ' by ''
	$ins .= ", rxn_equation";
	$vals .= ", '$rxn_eqn'";
    }

    if ( $is_reversible && length($is_reversible) > 0 ) {
	$ins .= ", is_reversible";
	$vals .= ", '$is_reversible'";
    }

    if ( $comm && length($comm) > 0 ) {
	$comm =~ s/'/''/g;  # replace ' by ''
	$ins .= ", comments";
	$vals .= ", '$comm'";
    }

    # modified by
    if ( $contact_oid ) {
	$ins .= ", modified_by";
	$vals .= ", $contact_oid";
    }

    # add_date, mod_date
    $ins .= ", add_date, mod_date) ";
    $vals .= ", '$sysdate', '$sysdate') ";

    $sql = $ins . $vals;
    push @sqlList, ( $sql );

    # insert all synonyms
#    my @allSynonyms = split (/\n/, param('allSynonyms'));

#    for my $s ( @allSynonyms ) {
# if ( length($s) > 0 ) {
#   $s =~ s/'/''/g;
#    $sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, modified_by)";
#   $sql .= " values (" . $new_term_oid . ", '" . $s;
#    $sql .= "', " . $contact_oid . ")";
#}

# push @sqlList, ( $sql );
# }

    # perform database update
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1]; 
        webError ("SQL Error: $sql");
        return -1; 
    } 
    else {
        return $new_rxn_oid; 
    } 
}


############################################################################
# dbUpdateRxn - update an IMG reaction in the database
############################################################################
sub dbUpdateRxn() {
    # get the reaction oid
    my @selected_rxn_oids = param( "selectedRxns" ); 
    if ( scalar (@selected_rxn_oids) == 0 ) {
	webError ("No IMG reaction is selected.");
	return -1;
    }
    my $rxn_oid = $selected_rxn_oids[0];

    # get input parameters
    my $rxn_name = param ('newName');
    my $rxn_def = param ('rxnDef');
    my $rxn_eqn = param ('rxnEqn');
    my $is_reversible = param ('revSelection');
    my $comm = param ('rxnComments');

    # check input
    if ( !$rxn_name || length($rxn_name) == 0 ) {
	webError ("Please enter a new reaction name.");
	return -1;
    }

    # check database
    # login
    my $dbh = dbLogin(); 

    my $sql = "select rxn_oid, rxn_name, rxn_definition, rxn_equation, " .
	"is_reversible, comments " .
	"from img_reaction where rxn_oid = $rxn_oid";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $to_update = 0;
    for (;;) { 
        my ( $r_id, $name, $def, $eqn, $rev, $co ) = $cur->fetchrow( );
        last if !$r_id;
 
	if ( $name ne $rxn_name ||
	     $def ne $rxn_def ||
	     $eqn ne $rxn_eqn ||
	     $rev ne $is_reversible ||
	     $co ne $comm ) {
	    $to_update = 1;
	}
    }

    if ( $to_update == 0 ) {
	#$dbh->disconnect();
	return -1;
    }

    # get sysdate
    $sql = "select sysdate from dual";
    $cur = execSql( $dbh, $sql, $verbose );

    my $sysdate = "";
    for (;;) { 
        my ( $d1 ) = $cur->fetchrow( );
        last if !$d1;
 
	$sysdate = $d1;
    }
    $cur->finish( );

    #$dbh->disconnect();

    my @sqlList = ();

    # prepare update
    $rxn_name =~ s/'/''/g;
    $rxn_def =~ s/'/''/g;
    $rxn_eqn =~ s/'/''/g;
    $comm =~ s/'/''/g;

    # update IMG_REACTION table
    my $sql = "update IMG_REACTION set rxn_name = '$rxn_name',";
    $sql .= " rxn_definition = '$rxn_def', rxn_equation = '$rxn_eqn',";
    $sql .= " is_reversible = '$is_reversible', comments = '$comm', ";
    $sql .= " mod_date = '$sysdate', modified_by = $contact_oid";
    $sql .= " where rxn_oid=$rxn_oid";

    push @sqlList, ( $sql );

    # perform database update
    my $err = db_sqlTrans( \@sqlList ); 
    if ( $err ) { 
        $sql = $sqlList[$err-1]; 
        webError ("SQL Error: $sql");
        return -1; 
    } 
    else {
        return $rxn_oid; 
    } 
}


############################################################################
# dbDeleteRxn - delete an IMG reaction from the database
############################################################################
sub dbDeleteRxn {
    # get the reaction oid
    my @selected_rxn_oids = param( "selectedRxns" ); 
    if ( scalar (@selected_rxn_oids) == 0 ) {
	webError ("No IMG reaction is selected.");
	return -1;
    }
    my $rxn_oid = $selected_rxn_oids[0];
    my $old_oid = $rxn_oid;

    # prepare SQL
    my @sqlList = ();

    # delete from IMG_REACTION_ASSOC_RXNS
    my $sql = "delete from IMG_REACTION_ASSOC_RXNS where rxn_oid = $old_oid or rxn = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_ASSOC_PATHS
    my $sql = "delete from IMG_REACTION_ASSOC_PATHS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_ASSOC_NETWORKS
    my $sql = "delete from IMG_REACTION_ASSOC_NETWORKS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_CATALYSTS
    my $sql = "delete from IMG_REACTION_CATALYSTS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_C_COMPONENTS
    my $sql = "delete from IMG_REACTION_C_COMPONENTS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_T_COMPONENTS
    my $sql = "delete from IMG_REACTION_T_COMPONENTS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_EXT_LINKS
    my $sql = "delete from IMG_REACTION_EXT_LINKS where rxn_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_REACTIONS
    my $sql = "delete from IMG_PATHWAY_REACTIONS where rxn = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION
    $sql = "delete from IMG_REACTION where rxn_oid = $old_oid";
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

1;
