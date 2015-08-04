############################################################################
# ImgTermCartDataEntry.pm - Data entry through ImgTermCart entry point.
#   imachne 01/03/2007
#
#   View messages, e.g. for debugging, 
#       by openeing a window on durian, and doing 
#           % tail -f /var/log/apache/error.log 
############################################################################
package ImgTermCartDataEntry;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use ImgTermCartStor;
use ImgTermNodeMgr;
use ImgTermNode;
use DataEntryUtil;
use FuncUtil;
use ImgRxnCartStor;
use FuncCartStor;


my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };

my $section = "ImgTermCartDataEntry";
my $section_cgi = "$main_cgi?section=$section";

my $contact_oid = getContactOid( );

my $max_count = 200;
my $max_upload_line_count = 10000;



############################################################################
# dispatch - Dispatch to pages for this section.
############################################################################
sub dispatch {

    ## Should not get here.
    my $section = param( "section" );
    if( $section ne "ImgTermCartDataEntry" ) {
        webDie( "ImgTermCartDataEntry::dispatch: bad section '$section'\n" );
    }
    if( !$contact_oid ) {
        webError( "Please login in." );
    }

    my $page = param( "page" );
    ## Massage submit button to use same "page" convention.
    if( $page eq "" ) {
       if( paramMatch( "index" ) ne "" ) {
           $page = "index";
       }
       elsif( paramMatch( "addTermForm" ) ne "" ) {
           $page = "addTermForm";
       }
       elsif( paramMatch( "dbAddTerm" ) ne "" ) {
	   my $new_oid = dbAddTerm();
	   if ( $new_oid > 0 ) {
	       # add new oids to function cart
	       my $fc = new FuncCartStor( ); 
	       my @term_oids = param( "term_oid" );
	       push @term_oids, ( $new_oid );
	       $fc->addImgTermBatch( \@term_oids );
	   }

	   # add to term cart too
	   if ( $new_oid > 0 ) {
	       my $itc = new ImgTermCartStor( );
	       my @term_oids = param( "term_oid" );
	       push @term_oids, ( $new_oid );
	       $itc->addImgTermBatch( \@term_oids );
	   } 

	   # go to the index page
	   $page = "index";
       }
       elsif( paramMatch( "confirmDeleteTermForm" ) ne "" ) {
	   $page = "confirmDeleteTermForm";
       }
       elsif( paramMatch( "deleteTermForm" ) ne "" ) {
	   my $old_oid = dbDeleteTerm();
	   if ( $old_oid > 0 ) {
	       # remove the deleted term from function cart
	       my $fc = new FuncCartStor( ); 
	       my $recs = $fc->{ recs }; # get records 
	       my $selected = $fc->{ selected };
	       my $func_id = "ITERM:" . FuncUtil::termOidPadded($old_oid); 
	       delete $recs->{ $func_id };
	       delete $selected->{ $func_id };
	       $fc->save( );
	   }

	   # delete from term cart too
	   if ( $old_oid > 0 ) {
	       my $itc = new ImgTermCartStor( );
	       my $recs = $itc->{ recs }; # get records 
	       my $selected = $itc->{ selected };
	       delete $recs->{ $old_oid };
	       delete $selected->{ $old_oid }; 
	       $itc->save( ); 
	   } 

	   # go to the index page
	   $page = "index";
       }
       elsif( paramMatch( "updateTermForm" ) ne "" ) {
           $page = "updateTermForm";
       }
       elsif( paramMatch( "dbUpdateTerm" ) ne "" ) {
	   my $old_oid = dbUpdateTerm();
 
	   if ( $old_oid > 0 ) {
	       # update term info
	       my $fc = new FuncCartStor( ); 
	       my @term_oids = ( $old_oid );
	       $fc->addImgTermBatch( \@term_oids );
	   }

	   # update term cart too 
	   if ( $old_oid > 0 ) { 
	       my $itc = new ImgTermCartStor( ); 
	       my @term_oids = ( $old_oid ); 
	       $itc->addImgTermBatch( \@term_oids ); 
	   } 

	   # go to the index page
	   $page = "index";
       }
       elsif( paramMatch( "updateChildTermForm" ) ne "" ) {
           $page = "updateChildTermForm";
       }
       elsif( paramMatch( "dbUpdateChildTerm" ) ne "" ) {
	   my $term_oid = dbUpdateChildTerm();

           $page = "index";
       }
       elsif( paramMatch( "addTermRxnForm" ) ne "" ) {
	   $page = "searchRxnForm";
       }
       elsif( paramMatch( "searchRxnResultsForm" ) ne "" ) {
	   $page = "searchRxnResultsForm";
       }
       elsif( paramMatch( "termRxnAssignment" ) ne "" ) {
	   $page = "termRxnAssignment";
       }
       elsif( paramMatch( "dbAssignTermRxn" ) ne "" ) {
	   $page = "dbAssignTermRxn";
       }
       elsif( paramMatch( "deleteTermRxnForm" ) ne "" ) {
	   $page = "deleteTermRxnForm";
       } 
       elsif( paramMatch( "dbRemoveTermRxn" ) ne "" ) {
	   $page = "dbRemoveTermRxn";
       }
       elsif( paramMatch( "fileUploadTermRxnForm" ) ne "" ) {
	   $page = "fileUploadTermRxnForm";
       }
       elsif( paramMatch( "validateTermRxnFile" ) ne "" ) {
	   $page = "validateTermRxnFile";
       }
       elsif ( paramMatch( "dbTermRxnFileUpload" ) ne "" ) {
	   # perform actual upload
	   dbTermRxnFileUpload();

	   # show index page
	   $page = "index";
       }
   }
    webLog( "Dispatch to page '$page'\n" );

    # --es 09/30/2006 Save the error log only when needed now.
    #print STDERR "Dispatch to page '$page'\n";

    if( $page eq "index" ) {
        printIndex( );
    }
    elsif( $page eq "addTermForm" ) {
        printAddUpdateTermForm( 0 );
    }
    elsif( $page eq "confirmDeleteTermForm" ) {
	printConfirmDeleteTermForm( );
    }
    elsif( $page eq "updateTermForm" ) {
	printAddUpdateTermForm( 1 );
    }
    elsif( $page eq "updateChildTermForm" ) {
	printUpdateChildTermForm( );
    }
    elsif( $page eq "searchRxnForm" ) {
	printSearchRxnForm( );
    }
    elsif( $page eq "searchRxnResultsForm" ) {
	printSearchRxnResultsForm( );
    }
    elsif( $page eq "termRxnAssignment" ) {
	printTermRxnAssignment( );
    }
    elsif( $page eq "addTermRxnForm" ) {
	printAddTermRxnForm( );
    }
    elsif( $page eq "dbAssignTermRxn" ) {
	# add new term-reaction to database
	dbAssignTermRxn( );

	# back to IMG term cart index page
	setSessionParam( "lastCart", "imgTermCart" );
	my $itc = new ImgTermCartStor( );
	$itc->printImgTermCartForm( "load" );
    }
    elsif( $page eq "deleteTermRxnForm" ) {
	printDeleteTermRxnForm( );
    }
    elsif( $page eq "dbRemoveTermRxn" ) {
	# delete term-reaction from database
	dbRemoveTermRxn( );

	# back to IMG term cart index page
	setSessionParam( "lastCart", "imgTermCart" );
	my $itc = new ImgTermCartStor( );
	$itc->printImgTermCartForm( "load" );
    }
    elsif ( $page eq "fileUploadTermRxnForm" ) {
	printFileUploadTermRxnForm();
    }
    elsif ( $page eq "validateTermRxnFile" ) {
	printValidateTermRxnForm();
    }
    elsif ( $page eq "dbTermRxnFileUpload" ) {
	dbTermRxnFileUpload();

	# back to IMG term cart index page
	setSessionParam( "lastCart", "imgTermCart" );
	my $itc = new ImgTermCartStor( );
	$itc->printImgTermCartForm( "load" );
    }
    else {
        printIndex( );
    }
}


############################################################################
# printIndex - This is the main IMG Term Cart Data Entry page
############################################################################
sub printIndex {
    print "<h1>IMG Term Curation Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    print "<h3>Note: This page only allows single IMG term selection.</h3>\n";

    # list all terms
    printCartTerms();
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );

    # add New, Delete and Update IMG Term button
    my $name = "_section_${section}_addTermForm";
    print submit( -name => $name,
       -value => 'New IMG Term', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteTermForm";
    print submit( -name => $name,
       -value => 'Delete IMG Term', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_updateTermForm";
    print submit( -name => $name,
       -value => 'Update IMG Term', -class => 'smbutton' );

    # update child terms
    print "<p>\n";
    print "Please enter a search term.<br/>\n";

    print "Filter: <input type='text' id='childTermFilter' name='childTermFilter' size='50' maxLength='1000' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_updateChildTermForm";
    print submit( -name => $name,
       -value => 'Update Child Terms', -class => 'smbutton' );
    print "</p>\n";

    print end_form( );
}


############################################################################
# printCartTerms - Show IMG terms in term cart.
############################################################################
sub printCartTerms {
 
    my $itc = new ImgTermCartStor( ); 
 
    my $recs = $itc->{ recs }; # get records 

    my @term_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are term_oids. 
        # But we want them sorted. 
 
    # get selected term oids
    my @selected_term_oids;
    if ( param( "selectedTerms") ) {
	# coming from other IMG Term Cart Data Entry pages
	my $s = param( "selectedTerms" );
	@selected_term_oids = split ( / /, $s);
    }
    else {
	# coming from IMG Term Cart
	@selected_term_oids = param( "term_oid" ); 
    }

    my %selected_term_oids_h; 
    for my $term_oid( @selected_term_oids ) { 
	$selected_term_oids_h{ $term_oid } = 1; 
    } 

    # print count 
    my $count = scalar( @term_oids ); 
    print "<p>\n"; 
    print "$count term(s) in cart\n"; 
    print "</p>\n"; 
 
    # get term data from database
    my $dbh = dbLogin( ); 
 
    # get IMG term info
    my %termTypes = getTermType($dbh, @term_oids);
    my %modifiedBy = getModifiedBy($dbh, @term_oids); 
    my %isValid = getIsValid($dbh, @term_oids); 

    #$dbh->disconnect(); 
 
    ### Print the records out in a table. 
    print "<table class='img'>\n"; 
    print "<th class='img'>Select for<br/>Delete/Update</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>Term</th>\n";
    print "<th class='img'>Term Type</th>\n";
    print "<th class='img'>Certified?</th>\n";
    print "<th class='img'>Modified by</th>\n";
    print "<th class='img'>Batch</th>\n";
    for my $term_oid ( @term_oids ) {
	my $i = $term_oid;

        my $r = $recs->{ $term_oid };
        my( $term_oid, $term, $batch_id ) = split( /\t/, $r );

        print "<tr class='img'>\n"; 
 

        print "<td class='img'>\n"; 
        print "<input type='radio' ";
        print "name='term_oid' value='$term_oid' />\n";
        print "</td>\n"; 
 
	# term_oid with url
        my $url = "$main_cgi?section=ImgTermBrowser" . 
	   "&page=imgTermDetail&term_oid=$term_oid";
        print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	# term
        print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	# term type
        if ( $termTypes{$term_oid} ) { 
            print "<td class='img'>" . escapeHTML($termTypes{$term_oid}) . "</td>\n";
        } 
        else { 
            print "<td class='img'>" . "" . "</td>\n"; 
        } 

	# is valid
        if ( $isValid{$term_oid} ) { 
            print "<td class='img'>" . escapeHTML($isValid{$term_oid}) . "</td>\n";
        } 
        else { 
            print "<td class='img'>" . "" . "</td>\n"; 
        } 

	# modified by
        if ( $modifiedBy{$term_oid} ) { 
            print "<td class='img'>" . escapeHTML($modifiedBy{$term_oid}) . "</td>\n";
        } 
        else { 
            print "<td class='img'>" . "" . "</td>\n"; 
        } 

	# batch_id
        print "<td class='img'>" . escapeHTML( $batch_id ) . "</td>\n";
        print "</tr>\n"; 
    } 
    print "</table>\n";
}


############################################################################
# printAddUpdateTermForm - add a new IMG term
############################################################################
sub printAddUpdateTermForm {
    my ( $update ) = @_;   # add or update

    if ( $update ) {
	print "<h1>Update IMG Term Page</h1>\n";
    }
    else {
	print "<h1>Add IMG Term Page</h1>\n";
    }

    printMainForm( );

    # add Add/Update, Reset and Cancel buttons
    if ( $update ) {
        my $name = "_section_${section}_dbUpdateTerm";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddTerm";
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

    # save selected term oids
    my $itc = new ImgTermCartStor( ); 
    my $recs = $itc->{ recs }; # get records 
 
    my @term_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are term_oids. 
        # But we want them sorted. 
 
    # get selected term oids
    my @selected_term_oids = param( "term_oid" ); 
    my %selected_term_oids_h; 
    for my $term_oid( @selected_term_oids ) { 
	$selected_term_oids_h{ $term_oid } = 1; 
    } 

    ## Set parameters.
    print hiddenVar( "section", $section );

    # get selected term oids
    # need to record all selected terms
    # save term selections in a hidden variable 
    print "<input type='hidden' name='selectedTerms' value='"; 
    for my $term_oid ( @selected_term_oids ) { 
        print "$term_oid "; 
    } 
    print "'>\n"; 

    my $update_term_oid = -1;
    if ( $update ) {
	if ( scalar (@selected_term_oids) > 0 ) {
	    $update_term_oid = $selected_term_oids[0];
	}
	else {
	    webError ("No IMG term is selected.");
	    return;
	}
    }

    # if it is update, then we need to get term info from the database
    my $db_term = "";
    my $db_term_type = "";
    my $db_def = "";
    my $db_comm = "";
    my @db_syn = ();
    if ( $update && $update_term_oid > 0 ) {
	my $dbh = dbLogin( );
	my $sql = qq{
	    select it.term, it.term_type, it.definition, it.comments
		from img_term it
		where it.term_oid = $update_term_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );
	($db_term, $db_term_type, $db_def, $db_comm) = $cur->fetchrow( );
	$cur->finish( );

	$sql = qq{
	    select its.synonyms
		from img_term_synonyms its
		where its.term_oid = $update_term_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) { 
	    my ( $val ) = $cur->fetchrow( );
	    last if !$val;
 
	    push @db_syn, ( $val );
	}

	#$dbh->disconnect();
    }

    print "<h2>Term Information</h2>\n";
    
    print "<table class='img' border='1'>\n";

    # New Term
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>New IMG Term</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='newTerm' value='" .
	escapeHTML($db_term) . "' size='60' maxLength='1000'/>" . "</td>\n";
    print "</tr>\n";

    # Term Type
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Term Type</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='termTypeSelection' class='img' size='3'>\n";
    for my $tt ( ('GENE PRODUCT', 'MODIFIED PROTEIN', 'PROTEIN COMPLEX') ) {
	print "        <option value='$tt'";
	if ( (uc $db_term_type) eq $tt ) {
	    print " selected";
	}
	print ">$tt</option>\n";
    }
    print "     </select>\n";
    print "</td>\n</tr>\n";

    # Definition
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Definition</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='termDef' value='" .
	escapeHTML($db_def) . "' size='60' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    # Comments
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Comment</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='termComments' value='" .
	escapeHTML($db_comm) . "' size='60' maxLength='1000' />" . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    # add synonyms
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
	$allSyn .= "\n" . escapeHTML($s);
    }

    print "<input type='hidden' id='allSynonyms' name='allSynonyms' value='$allSyn'>\n"; 

    print "<h2>Synonyms of this IMG Term</h2>\n";

    # add buttons of synonyms
    print "<p>\n";
    print "New Synonym: <input type='text' id='newSynonym' name='newSynonym' size='60' maxLength='1000' />\n";
    print "</p>\n";

    print "<input type='button' name='addSynonym' value='Add Synonym' " .
        "onClick='changeSynonym(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='deleteSynonym' value='Delete Synonym' " .
        "onClick='changeSynonym(2)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='updateSynonym' value='Update Synonym' " .
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

    print end_form( );
}


############################################################################
# printUpdateChildTermForm - add a new IMG term
############################################################################
sub printUpdateChildTermForm {
    print "<h1>Update Child Terms Page</h1>\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    # get the term oid
    my @selected_term_oids = param( "term_oid" ); 
    if ( scalar (@selected_term_oids) == 0 ) {
	@selected_term_oids = param( "selectedTerms" );
    }
    if ( scalar (@selected_term_oids) == 0 ) {
	webError ("No IMG term is selected.");
	return -1;
    }

    my $term_oid = $selected_term_oids[0];

    # get term name
    my $itc = new ImgTermCartStor( ); 
    my $recs = $itc->{ recs }; # get records 
    my $r = $recs->{ $term_oid }; 
    my( $t_oid, $term, $batch_id ) = split( /\t/, $r );

    print "<h2>IMG Term: ($t_oid) $term</h2>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedTerms", $term_oid );
#    print "<input type='hidden' name='selectedTerms' value='$term_oid '>\n"; 

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
    if ( $term_oid ) {
	my $dbh = dbLogin( );
	%childTerms = getChildTerms( $dbh, $term_oid );
	#$dbh->disconnect();
    }
    else {
	webError ("No IMG term is selected.");
	return -1;
    }

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
	printImgTermTree( $filterVal );
    }
    else {
	print "<p><font color='red'>Please enter a term in the Filter!</font></p>\n";
    }

    print end_form( );
}


############################################################################
# printImgTermTree - Print term tree for img_term_iex search.
#
# (This subroutine was copied from FindFunctions, and then customized
#  to suit the Child Term search.)
############################################################################
sub printImgTermTree {
    my( $searchTerm ) = @_;

    if( blankStr( $searchTerm ) ) {
	webError( "Please enter a search term." );
    }

    # show search results
    print "<h4>Term Search Results</h4>\n";

    print "<p>Some term selections are blocked to prevent loops in the IMG term hierarchy.</p>\n";

    print "<input type='button' name='addSelect' value='Add Selected Terms' " .
        "onClick='addSelectedChildTerms()' class='meddefbutton' />\n";
    print nbsp( 1 ); 
    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 ); 
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 

    # add java script function 'addSelectedChildTerms' 
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
    my %ancestorNodes;
    my @selected_term_oids = param( "term_oid" );
    if ( scalar (@selected_term_oids) == 0 ) {
	@selected_term_oids = param( "selectedTerms" );
    }
    if ( scalar (@selected_term_oids) > 0 ) {
	my $t_id = $selected_term_oids[0];
	%ancestorNodes = getAllAncestorNodes ( $t_id );
    }

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
	require FindFunctions;
	FindFunctions::loadSearchTermOid2Html( $dbh, $n, \%termOid2Html );
	printSearchHtml2( $n, $searchTerm, \%ancestorNodes, \%termOid2Html );

	if( $nChildren > 0 ) {
	    print "<br/>\n";
	}
    }
    print "<p>\n";
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
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
    print "<input type='checkbox' id='$term_oid2' value='" . escapeHTML($term) . "'";
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
# dbAddTerm - add a new term to the database
############################################################################
sub dbAddTerm() {
    # get input parameters
    my $newTerm = param ('newTerm');
    my $termType = param ('termTypeSelection');
    my $def = param ('termDef');
    my $comm = param ('termComments');

    # check input
    chomp($newTerm);
    if ( !$newTerm || blankStr($newTerm) ) {
	webError ("Please enter a new term.");
	return -1;
    }

    # login
    my $dbh = dbLogin(); 

    # term already exist?
    my $id2 = db_findID ($dbh, 'IMG_TERM', 'TERM_OID', 'TERM', $newTerm, '');
    if ( $id2 > 0 ) {
	#$dbh->disconnect();
	webError ("Term already exists. (TERM_OID=$id2)");
	return -1;
    }

    my @sqlList = ();

    # get next oid
    my $new_term_oid = db_findMaxID( $dbh, 'IMG_TERM', 'TERM_OID') + 1;
    #$dbh->disconnect();

    # prepare insertion
    my $ins = "insert into IMG_TERM (term_oid, term";
    my $s = $newTerm;
    $s =~ s/'/''/g;  # replace ' with ''
    my $vals = "values ($new_term_oid, '". $s . "'";

    if ( $termType && length($termType) > 0 ) {
	$ins .= ", term_type";
	$vals .= ", '$termType'";
    }
    if ( $def && length($def) > 0 ) {
	$def =~ s/'/''/g;  # replace ' with ''
	$ins .= ", definition";
	$vals .= ", '$def'";
    }
    if ( $comm && length($comm) > 0 ) {
	$comm =~ s/'/''/g;  # replace ' with ''
	$ins .= ", comments";
	$vals .= ", '$comm'";
    }

    # modified by
    if ( $contact_oid ) {
	$ins .= ", modified_by";
	$vals .= ", $contact_oid";
    }

    $ins .= ", is_valid) ";
    $vals .= ", 'No')";

    my $sql = $ins . $vals;
    push @sqlList, ( $sql );

    # insert all synonyms
    my @allSynonyms = split (/\n/, param('allSynonyms'));

    for my $s ( @allSynonyms ) {
	if ( length($s) > 0 ) {
	   $s =~ s/'/''/g;  # replace ' with ''
           $sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, modified_by)";
	   $sql .= " values (" . $new_term_oid . ", '" . $s;
	   $sql .= "', " . $contact_oid . ")";
        }

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
	return $new_term_oid; 
    } 
}


############################################################################
# printConfirmDeleteTermForm - ask user to confirm deletion
############################################################################
sub printConfirmDeleteTermForm {
    print "<h1>Delete IMG Term Page</h1>\n";

    printMainForm( );

    # get the term oid
    my @selected_term_oids = param( "term_oid" ); 
    if ( scalar (@selected_term_oids) == 0 ) {
	@selected_term_oids = param( "selectedTerms" );
    }
    if ( scalar (@selected_term_oids) == 0 ) {
	webError ("No IMG term is selected.");
	return -1;
    }

    my $term_oid = $selected_term_oids[0];

    # get term name
    my $itc = new ImgTermCartStor( ); 
    my $recs = $itc->{ recs }; # get records 
    my $r = $recs->{ $term_oid }; 
    my( $t_oid, $term, $batch_id ) = split( /\t/, $r );

    print "<h2>IMG Term: ($t_oid) $term</h2>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedTerms", $term_oid );

    print "<p><font color=\"red\">Warning: The following gene-term association and " .
	"IMG term parent-child relationship will be deleted as well.</font></p>\n";

    my $dbh = dbLogin( );

    # show gene - term association
    print "<h3>Gene - IMG Term Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Product Name</th>\n";
    print "<th class='img'>IMG Term</th>\n";

    # GENE_IMG_FUNCTIONS
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
	    select g.gene_oid, g.product_name, t.function
	    from gene g, gene_img_functions t
	    where g.gene_ oid = t.gene_oid
	    and t.function = ?
	    $rclause
	    $imgClause
	};
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    for( ;; ) {
	my( $g_oid, $g_name, $t_oid ) = $cur->fetchrow( );
	last if !$g_oid;

	print "<tr class='img'>\n";
        my $url = "$main_cgi?section=GeneDetail" . 
	   "&page=geneDetail&gene_oid=$g_oid";
        print "<td class='img'>" . alink( $url, $g_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $g_name ) . "</td>\n";
        $url = "$main_cgi?section=ImgTermBrowser" . 
	   "&page=imgTermDetail&term_oid=$t_oid";
        print "<td class='img'>" . alink( $url, $t_oid ) . "</td>\n";
    }
    $cur->finish( );


    print "</table>\n";

    # display IMG pathway - IMG term associations

    # display IMG term parent-child relationship
    print "<h3>IMG Term Parent-Child Relationship to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Parent Term OID</th>\n";
    print "<th class='img'>Parent Term Name</th>\n";
    print "<th class='img'>Child Term OID</th>\n";
    print "<th class='img'>Child Term Name</th>\n";

    $sql = qq{
	select t1.term_oid, t1.term, t2.term_oid, t2.term
	    from img_term t1, img_term t2, img_term_children c
	    where t1.term_oid = c.term_oid
	    and t2.term_oid = c.child
	    and (c.term_oid = ? or c.child = ?)
	};
    $cur = execSql( $dbh, $sql, $verbose, $term_oid, $term_oid );
    for( ;; ) {
	my( $p_oid, $p_name, $c_oid, $c_name ) = $cur->fetchrow( );
	last if !$p_oid;

	print "<tr class='img'>\n";
        my $url = "$main_cgi?section=ImgTermBrowser" .
	   "&page=imgTermDetail&term_oid=$p_oid";
        print "<td class='img'>" . alink( $url, $p_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $p_name ) . "</td>\n";
        $url = "$main_cgi?section=ImgTermBrowser" . 
	   "&page=imgTermDetail&term_oid=$c_oid";
        print "<td class='img'>" . alink( $url, $c_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $c_name ) . "</td>\n";
    }
    $cur->finish( );
    print "</table>\n";

    #$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_deleteTermForm";
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
# dbDeleteTerm - delete an IMG term from the database
############################################################################
sub dbDeleteTerm {
    # get the term oid
    my $old_oid = param( "selectedTerms" );
    if ( blankStr($old_oid) ) {
	webError ("No IMG term is selected.");
	return -1;
    }

    # prepare SQL
    my @sqlList = ();

    # delete from GENE_IMG_FUNCTIONS table
    my $sql = "delete from GENE_IMG_FUNCTIONS where function = $old_oid";
    push @sqlList, ( $sql );

    # Amy: GENE_ALT_IMG_FUNCTIONS is removed from IMG 2.5
    # delete from GENE_ALT_IMG_FUNCTIONS
#    my $sql = "delete from GENE_ALT_IMG_FUNCTIONS where function = $old_oid";
#    push @sqlList, ( $sql );

    # delete from MCL_CLUSTER_IMG_FUNCTIONS
    #my $sql = "delete from MCL_CLUSTER_IMG_FUNCTIONS where function = $old_oid";
    #push @sqlList, ( $sql );

    # delete from IMG_REACTION_CATALYSTS
    my $sql = "delete from IMG_REACTION_CATALYSTS where catalysts = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_REACTION_T_COMPONENTS
    my $sql = "delete from IMG_REACTION_T_COMPONENTS where term = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_T_COMPONENTS
    my $sql = "delete from IMG_PATHWAY_T_COMPONENTS where term = $old_oid";
    push @sqlList, ( $sql );

    # delete from PATHWAY_NETWORK_T_COMPONENTS
    my $sql = "delete from PATHWAY_NETWORK_T_COMPONENTS where term = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PARTS_LIST_IMG_TERMS
    my $sql = "delete from IMG_PARTS_LIST_IMG_TERMS where term = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_TERM_HISTORY
    my $sql = "delete from IMG_TERM_HISTORY where term = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_TERM_SYNONYMS table
    $sql = "delete from IMG_TERM_SYNONYMS where term_oid = $old_oid";
    push @sqlList, ( $sql );

    # make all children of this IMG term pointing to its parent
    # IMG_TERM_CHILDREN
    $sql = "delete from IMG_TERM_CHILDREN where term_oid = $old_oid or child = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_TERM table
    $sql = "delete from IMG_TERM where term_oid = $old_oid";
    push @sqlList, ( $sql );

#   for $sql ( @sqlList ) {
#       print "<p>SQL: $sql</p>\n";
#   }
#   return -1;

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
# dbUpdateTerm - update an IMG term in the database
############################################################################
sub dbUpdateTerm() {
    # get the term oid
    my @selected_term_oids = param( "selectedTerms" ); 
    if ( scalar (@selected_term_oids) == 0 ) {
	webError ("No IMG term is selected.");
	return -1;
    }
    my $term_oid = $selected_term_oids[0];

    # get input parameters
    my $newTerm = param ('newTerm');
    my $termType = param ('termTypeSelection');
    my $def = param ('termDef');
    my $comm = param ('termComments');

    # check input
    if ( !$newTerm || length($newTerm) == 0 ) {
	webError ("Please enter a new term.");
	return -1;
    }

    # login
    my $dbh = dbLogin(); 

    # term already exist?
    my $id2 = db_findID ($dbh, 'IMG_TERM', 'TERM_OID', 'TERM', $newTerm,
			 "term_oid <> $term_oid");
    if ( $id2 > 0 ) {
	#$dbh->disconnect();
	webError ("Term already exists. (TERM_OID=$id2)");
	return -1;
    }

    #$dbh->disconnect();

    my @sqlList = ();

    # prepare update
    $newTerm =~ s/'/''/g;
    $termType =~ s/'/''/g;
    $def =~ s/'/''/g;
    $comm =~ s/'/''/g;

    # update IMG_TERM table
    my $sql = "update IMG_TERM set term = '$newTerm', term_type = '$termType',";
    $sql .= " definition = '$def', comments = '$comm', modified_by = $contact_oid";
    $sql .= " where term_oid=$term_oid";
    $sql .= " and (term <> '$newTerm'";
    $sql .= " or term_type is null or term_type <> '$termType'";
    $sql .= " or definition is null or definition <> '$def'";
    $sql .= " or comments is null or comments <> '$comm')";

    push @sqlList, ( $sql );

    # update synonyms
    $sql = "delete from IMG_TERM_SYNONYMS where term_oid = $term_oid";
    push @sqlList, ( $sql );

    my @allSynonyms = split (/\n/, param('allSynonyms'));

    for my $s ( @allSynonyms ) {
	if ( length($s) > 0 ) {
	   $s =~ s/'/''/g;
           $sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, modified_by)";
	   $sql .= " values (" . $term_oid . ", '" . $s;
	   $sql .= "', " . $contact_oid . ")";
        }

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
        return $term_oid; 
    } 
}


############################################################################
# dbUpdateChildTerm - update child terms of an IMG term in the database
############################################################################
sub dbUpdateChildTerm() {
    # get the term oid
    my @selected_term_oids = param( "selectedTerms" ); 
    if ( scalar (@selected_term_oids) == 0 ) {
	webError ("No IMG term is selected.");
	return -1;
    }
    my $term_oid = $selected_term_oids[0];

    my @sqlList = ();

    # delete all child terms
    my $sql = "delete from IMG_TERM_CHILDREN where term_oid = $term_oid";
    push @sqlList, ( $sql );

    # insert new child terms
    my @allChildTerms = split (/ /, param('allCTerms'));
    my $cnt = 0;
    for my $s ( @allChildTerms ) {
	if ( length($s) > 0 && isInt($s)) {
	    $sql = "insert into IMG_TERM_CHILDREN (term_oid, child, c_order) " .
		"values ($term_oid, $s, $cnt)";
	    push @sqlList, ( $sql );
	    $cnt++;
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
        return $term_oid; 
    } 
}


############################################################################
# db_findMaxID - find the max ID of a table 
############################################################################ 
sub xx_db_findMaxID {
    my ($dbh, $table_name, $attr_name) = @_;
 
    # SQL statement 
    my $sql = "select max($attr_name) from $table_name";
 
    my $cur = execSql( $dbh, $sql, $verbose );
 
    my $max_id = 0; 
    for (;;) { 
        my ( $val ) = $cur->fetchrow( );
        last if !$val;
 
        # set max ID
        $max_id = $val;
    }
 
    return $max_id; 
}


 
############################################################################ 
# db_findID - find ID given an attribute value 
############################################################################ 
sub xx_db_findID { 
    my ($dbh, $table_name, $id_name, $attr_name, $attr_val, $cond) = @_; 
 
    # SQL statement 
    my $s = $attr_val; 
    $s =~ s/'/''/g; 
    my $sql = "select $id_name from $table_name where $attr_name = '$s'"; 
    if ( $cond && length($cond) > 0 ) {
       #append condition
       $sql .= " and " . $cond;
    }
 
    my $cur = execSql( $dbh, $sql, $verbose ); 
 
    my $return_id = -1; 
    for (;;) { 
        my ( $val ) = $cur->fetchrow( ); 
        last if !$val; 
 
        $return_id = $val; 
    } 
 
    return $return_id; 
} 


############################################################################ 
# getIsValid - is the IMG term valid
############################################################################ 
sub getIsValid { 
    my ($dbh, @keys) = @_; 
 
    my %h; 
 
    my $count = 0; 
    my $isValid = ""; 
 
    for my $k ( @keys ) { 
        $isValid = ""; 
 
        #exec SQL 
        my $sql = qq{ 
            select it.term_oid, it.is_valid
                from img_term it
                where it.term_oid = $k 
            }; 
 
        my $cur = execSql( $dbh, $sql, $verbose ); 
 
        for($count = 0; ; $count++ ) { 
            my( $t_oid, $t_valid ) = $cur->fetchrow( ); 
            last if !$t_oid; 
 
	    $isValid = $t_valid;
        }  # end for loop 
 
        $h{ $k } = $isValid;
    }  #end for k loop 
 
    return %h; 
} 


############################################################################ 
# getModifiedBy - Modified By
############################################################################ 
sub getModifiedBy { 
    my ($dbh, @keys) = @_; 
 
    my %h; 
 
    my $modifiedBy = ""; 
 
    for my $k ( @keys ) { 
        $modifiedBy = ""; 
 
        #exec SQL 
        my $sql = qq{ 
            select it.term_oid, c.name
                from img_term it, contact c
                where it.term_oid = $k 
                and it.modified_by = c.contact_oid
            }; 
 
        my $cur = execSql( $dbh, $sql, $verbose ); 
 
        for( ;; ) { 
            my( $t_oid, $c_name ) = $cur->fetchrow( ); 
            last if !$t_oid; 
 
	    $modifiedBy = $c_name;
        }  # end for loop 
 
        $h{ $k } = $modifiedBy; 
    }  #end for k loop 
 
    return %h; 
} 

############################################################################ 
# getTermType - get term_type
############################################################################ 
sub getTermType { 
    my ($dbh, @keys) = @_; 
 
    my %h; 
    my $termType;

    for my $k ( @keys ) { 
	$termType = "";

        #exec SQL 
        my $sql = qq{ 
            select it.term_oid, it.term_type
                from img_term it
                where it.term_oid = $k 
            }; 
 
        my $cur = execSql( $dbh, $sql, $verbose ); 
 
	for ( ;; ) {
            my( $t_oid, $t_type ) = $cur->fetchrow( ); 
            last if !$t_oid; 
 
	    $termType = $t_type;
        }  # end for loop 
 
        $h{ $k } = $termType; 
    }  #end for k loop 
 
    return %h; 
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
# db_sqlTrans - perform an SQL transaction
############################################################################
sub xx_db_sqlTrans () {
    my @sqlList = @_;

    # login
    my $dbh = dbLogin(); 
    $dbh->{ AutoCommit } = 0;

    my $last_sql = "";

    # perform database update
    eval {
        for my $sql ( @sqlList ) { 
	    $last_sql = $sql;
            execSql ($dbh, $sql, $verbose);
        }
    }; 

    if ($@) {
	$dbh->rollback();
	#$dbh->disconnect();
	webError ("Incorrect SQL: $last_sql");
	return 0;
    }

    $dbh->commit();
    #$dbh->disconnect();

    return 1;
}


############################################################################
# getAllAncestorNodes - get all ancestor nodes of this IMG term
#
# return a hash with all ancestors, including this term
############################################################################
sub getAllAncestorNodes () {
    my ( $n_oid ) = @_;

    my %h;

    # starting from the current node
    my @idList = ( $n_oid );

    my $i = 0;
    while ( $i < scalar(@idList) ) {
	# get the Term oid
	my $n = $idList[$i];

#	print "<p>i=$i, Term $n</p>\n";

	if ( ! $h{$n} ) {
#	    print "<p>Term $n not processed yet</p>\n";
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
#		print "<p>Add ancestor $val</p>\n";

		# save this value to idList
		push @idList, ( $val2 );
	    }

	    #$dbh->disconnect();
	}

	$i++;
    }

    return %h;
}


# ???????

sub showAllSynonyms
{
    my $str = param ('allSynonyms');
    print "<p>$str</p>\n";
    my @allSynonyms = split (/\n/, $str);

    for my $s ( @allSynonyms ) {
	print "<p>Synonym: " . $s . "</p>\n";
    }
}


##
## Term - Reaction Curation
##

############################################################################
# printSearchRxnForm - Show search reaction form 
############################################################################
sub printSearchRxnForm {

    print "<h1>Search IMG Reactions</h1>\n";
    
    printMainForm( );

    my $section = param( "section" );

    ## Set parameters.
    print hiddenVar( "section", $section );

    # need to record all selected terms
    my $itc = new ImgTermCartStor( );
    my $recs = $itc->{ recs }; # get records
    my @term_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @term_oids ) == 0 ) {
	webError( "There are no terms in the IMG Term Cart." );
	return;
    }

    my @selected_term_oids = param( "term_oid" );
    my %selected_term_oids_h;
    for my $term_oid( @selected_term_oids ) {
	$selected_term_oids_h{ $term_oid } = 1;
    }

    # save term selections in a hidden variable
    print "<input type='hidden' name='selectedTerms' value='";
    for my $term_oid ( @selected_term_oids ) {
	print "$term_oid ";
    }
    print "'>\n";

    print "<p>\n";
    print "Enter a keyword to search reaction names or definitions. Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchReaction' size='80' />\n";
    print "<br/>\n";

    my $name = "_section_${section}_searchRxnResultsForm";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    print end_form( );
}

############################################################################
# printSearchRxnResultsForm - Show results of reaction search.
############################################################################
sub printSearchRxnResultsForm {

    print "<h1>Search IMG Reactions</h1>\n";
 
    printMainForm( );
 
    # keep previous term selection in a hidden variable to pass to next screen
    my $selectedTerms = param ( "selectedTerms" );
    print hiddenVar( "selectedTerms", $selectedTerms );
 
    # get search term 
    my $searchReaction = param( "searchReaction" );

    print "<p>\n"; 
    print "Enter a keyword to search reaction names or definitions. Use % for wildcard.\n";
    print "</p>\n"; 
    print "<input type='text' name='searchReaction' value='$searchReaction' size='80\
' />\n";
    print "<br/>\n";

 
    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchRxnResultsForm";
    print submit( -name => $name, 
                  -value => "Go", -class => "smdefbutton" ); 
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
 
    if( $searchReaction eq "" ) { 
        webError( "Please enter a keyword to search." ); 
        print end_form(); 
        return; 
    } 
 
    my $dbh = dbLogin( );
 
    ## Massage for SQL.
    #  Get rid of preceding and lagging spaces.
    #  Escape SQL quotes. 
    $searchReaction =~ s/^\s+//; 
    $searchReaction =~ s/\s+$//; 
    my $searchTermLc = lc($searchReaction);
 
    printStatusLine( "Loading ...", 1 );
 
    # search reactions
    my $sql = qq{ 
        select ir.rxn_oid, ir.rxn_name, ir.rxn_definition
            from img_reaction ir 
            where lower( ir.rxn_name ) like ? 
            or lower( ir.rxn_definition ) like ? 
        };
 
    my $cur = execSql( $dbh, $sql, $verbose, "%$searchTermLc%", "%$searchTermLc%" );
    my $count = 0;
    for( ;; ) { 
        my( $rxn_oid, $rxn_name, $rxn_def ) = $cur->fetchrow( ); 
        last if !$rxn_oid; 
 
        $count++; 
 
        if ( $count == 1 ) { 
            print "<h2>Select IMG Reactions</h2>\n"; 
	    print "<p>The following list shows all IMG reactions that have names or definitions matching the input search term.<br/>\n"; 
            print "Click on an IMG reaction to select.</p>\n"; 
            print "<p>\n"; 
        } 
 
        # show this reaction 
        $rxn_oid = FuncUtil::rxnOidPadded($rxn_oid); 
        print "<input type='radio' name='rxn_oid' value='$rxn_oid' />\n"; 
	    my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$rxn_oid";
        print nbsp( 1 ); 
        print alink( $url, $rxn_oid ); 
        print nbsp( 1 ); 
 
        # print reaction name 
        my $matchText = highlightMatchHTML2( $rxn_name, $searchReaction );
        print $matchText; 
 
        # print reaction definition
        if ( $rxn_def ne "" ) { 
            print "<br/>\n";
            $matchText = highlightMatchHTML2( $rxn_def, $searchReaction );
            print nbsp( 7 );
            print "(Definition: $matchText)"; 
        } 
 
 
        print "<br/>\n"; 
    }
    $cur->finish( );
 
    #$dbh->disconnect(); 
 
    if ( $count == 0 ) { 
        printStatusLine( "$count reaction(s) found.", 2 ); 
        webError( "No IMG reactions matches the keyword." ); 
        return; 
    } 
 
    print "</p>\n"; 
    printStatusLine( "$count term(s) found.", 2 );
 
    # show button 
    print "<br/><br/>\n";
 
    my $name = "_section_${section}_termRxnAssignment";
    print submit( -name => $name,
		  -value => "Associate Terms to Reaction", -class => "lgdefbutton" );
    print nbsp( 1 ); 
    my $name = "_section_${section}_index"; 
    print submit( -name => $name,
                  -value => 'Cancel', -class => 'smbutton' );
 
    print end_form(); 
} 


############################################################################
# printTermRxnAssignment - This is the page handling final term
#                          - reaction assignment.
############################################################################
sub printTermRxnAssignment {
    print "<h1>IMG Term - Reaction Assignment Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    my $section = param("section");
    print hiddenVar( "section", $section );

    # keep previous term selection in a hidden variable to pass to next screen
    my $selectedTerms = param ( "selectedTerms" );
    print hiddenVar( "selectedTerms", $selectedTerms );

    # get selected IMG reactionn
#    my $rxn_oid = param ( "rxnSelection" );
    my $rxn_oid = param ( "rxn_oid" );
    print hiddenVar ( "rxnSelection", $rxn_oid);

    if ( blankStr($rxn_oid) ) {
        webError( "No IMG reaction has been selected.");
	return;
    }

    my $name = "_section_${section}_dbAssignTermRxn";
    print submit( -name => $name,
		  -value => 'Assign IMG Reactions', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    # get all terms in the term cart
    # need to record all selected terms
    my $itc = new ImgTermCartStor( );
    my $recs = $itc->{ recs }; # get records
    my @term_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @term_oids ) == 0 ) {
	webError( "There are no terms in the IMG Term Cart." );
	return;
    }

#    my @selected_term_oids = param( "term_oid" );
    my @selected_term_oids = split (/ /, param( "selectedTerms" ));
    my %selected_term_oids_h;
    for my $term_oid( @selected_term_oids ) {
	$selected_term_oids_h{ $term_oid } = 1;
    }

    # save term selections in a hidden variable
    print "<input type='hidden' name='selectedTerms' value='";
    for my $term_oid ( @selected_term_oids ) {
	print "$term_oid ";
    }
    print "'>\n";

    # print selected count
    my $count = @selected_term_oids;
    print "<p>\n";
    print "$count term(s) selected\n";
    print "</p>\n"; 

    # add java script function 'setAssocType'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setAssocType( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^at_/ ) ) {\n";
    print "              e.selectedIndex = x;\n";
    print "             }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Term OID</th>\n";
    print "<th class='img'>Term</th>\n";
    print "<th class='img'>Reaction OID</th>\n";

    print "<th class='img'>Association Type<br/>\n";
    print "<input type='button' value='Catalyst' Class='tinybutton'\n";
    print "  onClick='setAssocType (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Substrate' Class='tinybutton'\n";
    print "  onClick='setAssocType (1)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Product' Class='tinybutton'\n";
    print "  onClick='setAssocType (2)' />\n";
    print "</th>\n";

    # only list selected terms
    for my $term_oid ( @selected_term_oids ) {
	my $r = $recs->{ $term_oid };
	my( $t_oid, $term, $batch_id ) = split( /\t/, $r );

        print "<tr class='img'>\n";

	my $ck = "checked" if $selected_term_oids_h{ $term_oid };
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='term_oid' value='$term_oid' $ck/>\n";
	print "</td>\n";

        my $url = "$main_cgi?section=ImgTermBrowser" . 
	   "&page=imgTermDetail&term_oid=$term_oid";
	print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	# print reaction
	$url = "$main_cgi?section=ImgReaction" . 
	    "&page=imgRxnDetail&rxn_oid=$rxn_oid";
	print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";

	# print association type
	my $at_name = "at_" . $term_oid;
	print "<td class='img'>\n";
	print "  <select name='$at_name' id='$at_name'>\n";
	print "     <option value='Catalyst'>Catalyst</option>\n";
	print "     <option value='Substrate'>Substrate</option>\n";
	print "     <option value='Product'>Product</option>\n";
	print "  </select>\n";
	print "</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";

    print "<br/>\n";

    printStatusLine( "Loaded.", 2 );

    print end_form( );
}


############################################################################
# dbAssignTermRxn - add term-reaction association into database
############################################################################
sub dbAssignTermRxn {

    # get all terms in the term cart
    # need to record all selected terms
    my $itc = new ImgTermCartStor( );
    my $recs = $itc->{ recs }; # get records
    my @term_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @term_oids ) == 0 ) {
	webError( "There are no terms in the IMG Term Cart." );
	return;
    }

    # my @selected_term_oids = split (/ /, param( "selectedTerms" ));
    my @selected_term_oids = param( "term_oid" );
    my %selected_term_oids_h;
    for my $term_oid( @selected_term_oids ) {
	$selected_term_oids_h{ $term_oid } = 1;
    }

    if ( scalar(@selected_term_oids) == 0 ) {
        webError( "No IMG terms have been selected.");
	return;
    }

    # get rxn_oid
    my $rxn_oid = param ( "rxnSelection" );

    # prepare SQL
    my @sqlList = ();
    my $sql = "";

    for my $term_oid ( @selected_term_oids ) {
	# selected
	my $at = param ("at_" . $term_oid);

	if ( $at eq 'Catalyst' ) {
	    $sql = "insert into IMG_REACTION_CATALYSTS (rxn_oid, catalysts) ".
		"values ($rxn_oid, $term_oid)";
	    push @sqlList, ( $sql );
	}
	elsif ( $at eq 'Substrate' ) {
	    $sql = "insert into IMG_REACTION_T_COMPONENTS (rxn_oid, c_type, term) ".
		"values ($rxn_oid, 'LHS', $term_oid)";
	    push @sqlList, ( $sql );
	}
	elsif ( $at eq 'Product' ) {
	    $sql = "insert into IMG_REACTION_T_COMPONENTS (rxn_oid, c_type, term) ".
		"values ($rxn_oid, 'RHS', $term_oid)";
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
# printDeleteTermRxnForm - ask user to confirm term-reaction deletion
############################################################################
sub printDeleteTermRxnForm {
    print "<h1>Delete IMG Term - Reaction Page</h1>\n";

    printMainForm( );

    # get the term oid
    my @selected_term_oids = param( "term_oid" ); 
    if ( scalar (@selected_term_oids) == 0 ) {
	@selected_term_oids = param( "selectedTerms" );
    }
    if ( scalar (@selected_term_oids) == 0 ) {
	webError ("No IMG term is selected.");
	return -1;
    }

    ## Set parameters.
    print hiddenVar( "section", $section );

    print "<p><font color=\"red\">Warning: All selected IMG term-reaction associations " .
	"will be deleted.</font></p>\n";

    # get IMG term cart
    my $itc = new ImgTermCartStor( ); 
    my $recs = $itc->{ recs }; # get records 


    my $dbh = dbLogin( );

    # show gene - term association
    print "<h3>IMG Term - Reaction Association to be Deleted:</h3>\n";

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 ); 
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 

    print "<p>(Note: Only IMG terms that are associated with reactions can be selected.)</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Term OID</th>\n";
    print "<th class='img'>Term</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";
    
    for my $term_oid ( @selected_term_oids ) {
	# get term name
	my $r = $recs->{ $term_oid }; 
	my( $t_oid, $term, $batch_id ) = split( /\t/, $r );

	# find all reactions
	my $sql = qq{
	    select irtc.term, r.rxn_oid, r.rxn_name
		from img_reaction r, img_reaction_t_components irtc
		where r.rxn_oid = irtc.rxn_oid
		and irtc.term = ?
	    union select irc.catalysts, r.rxn_oid, r.rxn_name
		from img_reaction r, img_reaction_catalysts irc
		where r.rxn_oid = irc.rxn_oid
		and irc.catalysts = ?
	    };
	my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $term_oid );

	for( ;; ) {
	    my( $t_oid, $r_oid, $r_name ) = $cur->fetchrow( );
	    last if !$t_oid;

	    $r_oid = FuncUtil::rxnOidPadded($r_oid);

	    print "<tr class='img'>\n";

	    # select
	    print "<td class='checkbox'>\n"; 
	    print "<input type='checkbox' ";
	    print "name='term_rxn_oid' value='$term_oid|$r_oid' checked />\n";
	    print "</td>\n"; 

	    # term_oid
	    my $url = "$main_cgi?section=ImgTermBrowser" .
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	    # term
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	    # reaction oid
	    my $url = "$main_cgi?section=ImgReaction" .
		"&page=imgRxnDetail&rxn_oid=$r_oid";
	    print "<td class='img'>" . alink( $url, $r_oid ) . "</td>\n";

	    # reaction name
	    print "<td class='img'>" . escapeHTML( $r_name ) . "</td>\n";
	}
	$cur->finish( );

    }  # end for term_oid

    print "</table>\n";

    #$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_dbRemoveTermRxn";
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
# dbRemoveTermRxn - remove term-reaction association from database
############################################################################
sub dbRemoveTermRxn {

    # get all terms in the term cart
    # need to record all selected terms
    my $itc = new ImgTermCartStor( );
    my $recs = $itc->{ recs }; # get records
    my @term_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @term_oids ) == 0 ) {
	webError( "There are no terms in the IMG Term Cart." );
	return;
    }

    my @selected_term_rxn_oids = param( "term_rxn_oid" );
    if ( scalar(@selected_term_rxn_oids) == 0 ) {
        webError( "No IMG term-reaction associations have been selected.");
	return;
    }

    # prepare SQL
    my @sqlList = ();
    my $sql = "";

    for my $ids ( @selected_term_rxn_oids ) {
	my ($term_oid, $rxn_oid) = split (/\|/, $ids);
	$sql = "delete from IMG_REACTION_CATALYSTS where rxn_oid = $rxn_oid and catalysts = $term_oid";
	push @sqlList, ( $sql );

	$sql = "delete from IMG_REACTION_T_COMPONENTS where rxn_oid = $rxn_oid and term = $term_oid";
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
        return 1;
    } 
}


############################################################################
# printFileUploadTermRxnForm
############################################################################
sub printFileUploadTermRxnForm {
    print "<h1>Upload IMG Term - Reaction Associations from File</h1>\n";

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
    print "<li>Containing 3 columns: (1) IMG Term OID, (2) IMG Reaction OID, ";
    print "(3) Association Type: 'Catalyst', 'Substrate', or 'Product'</li>\n";
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
    my $name = "_section_${section}_validateTermRxnFile";
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
# printValidateTermRxnForm
############################################################################
sub printValidateTermRxnForm {
    print "<h1>Term-Reaction File Validation Result</h1>\n";

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
    my $tmp_upload_file = $cgi_tmp_dir . "/upload.termrxn." . $sessionId . ".txt";

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
    my $name = "_section_${section}_dbTermRxnFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Line No.</th>\n";
    print "<th class='img'>Term OID</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Association Type</th>\n";
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
        my ($term_oid, $rxn_oid, $assoc_type) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	my $msg = "";

        print "<tr class='img'>\n";

	print "<td class='img'>" . $line_no . "</td>\n";

	# check term_oid
	$term_oid = strTrim($term_oid);
	if ( blankStr($term_oid) ) {
	    $msg = "Error: Term OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $term_oid ) . "</td>\n";
	}
	elsif ( !isInt($term_oid) ) {
	    $msg = "Error: Incorrect Term OID '" . escapeHTML($term_oid) .
		"'. ";
	    print "<td class='img'>" . escapeHTML( $term_oid ) . "</td>\n";
	}
	else {
	    my $cnt1 = db_findCount($dbh, 'IMG_TERM', "term_oid = $term_oid");
	    if ( $cnt1 <= 0 ) {
		$msg = "Error: Term OID $term_oid is not in the database. ";
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

	# check rxn_oid
	$rxn_oid = strTrim($rxn_oid);
	if ( blankStr($rxn_oid) ) {
	    $msg .= "Error: Reaction OID is blank. ";
	    print "<td class='img'>" . escapeHTML( $rxn_oid ) . "</td>\n";
	}
	elsif ( !isInt($rxn_oid) ) {
	    $msg .= "Error: Incorrect Reaction OID '" . escapeHTML($rxn_oid) .
		"'. ";
	    print "<td class='img'>" . escapeHTML( $rxn_oid ) . "</td>\n";
	}
	else {
	    my $cnt2 = db_findCount($dbh, 'IMG_REACTION', "rxn_oid = $rxn_oid");
	    if ( $cnt2 <= 0 ) {
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

	# check association type
	$assoc_type = strTrim($assoc_type);
	if ( $assoc_type =~ /^\s*"(.*)"$/ ) { 
	    ($assoc_type) = ($assoc_type =~ /^\s*"(.*)"$/);
	    $assoc_type = strTrim($assoc_type);
	}
	print "<td class='img'>" . escapeHTML( $assoc_type ) . "</td>\n";

	if ( blankStr($assoc_type) ) {
	    $msg .= "Error: No association type is specified. ";
	}
	elsif ( lc($assoc_type) ne 'catalyst' &&
		lc($assoc_type) ne 'substrate' &&
		lc($assoc_type) ne 'product' ) {
	    $msg .= "Error: Incorrect association type '" .
		escapeHTML($assoc_type) . "'. ";
	}

	if ( $replace == 0 ) {
	    # check whether term-reaction association is already in the database
	    my $cnt3 = db_findCount($dbh, "IMG_REACTION_CATALYSTS",
				    "rxn_oid = $rxn_oid and catalysts = $term_oid");
	    if ( $cnt3 > 0 ) {
		$msg .= "Error: Term-Reaction association already exists. ";
	    }
	    else {
		$cnt3 = db_findCount($dbh, 'IMG_REACTION_T_COMPONENTS',
				     "rxn_oid = $rxn_oid and term = $term_oid");
		if ( $cnt3 > 0 ) {
		    $msg .= "Error: Term-Reaction association already exists. ";
		}
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
    my $name = "_section_${section}_dbTermRxnFileUpload";
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
# dbTermRxnFileUpload - handle the actual data upload
############################################################################
sub dbTermRxnFileUpload {
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
    my @term_oids;

    my $line_no = 0;
    my $line;
    while ($line = <FILE>) {
	chomp($line);
        my ($term_oid, $rxn_oid, $assoc_type) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
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
	    my $cnt1 = db_findCount($dbh, 'IMG_TERM', "term_oid = $term_oid");
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

	# check association type
	$assoc_type = strTrim($assoc_type);
	if ( $assoc_type =~ /^\s*"(.*)"$/ ) { 
	    ($assoc_type) = ($assoc_type =~ /^\s*"(.*)"$/);
	    $assoc_type = strTrim($assoc_type);
	}
	if ( blankStr($assoc_type) ) {
	    next;
	}
	elsif ( lc($assoc_type) ne 'catalyst' &&
		lc($assoc_type) ne 'substrate' &&
		lc($assoc_type) ne 'product' ) {
	    next;
	}

	if ( $replace == 0 ) {
	    # check whether term-reaction association is already in the database
	    my $cnt3 = db_findCount($dbh, "IMG_REACTION_CATALYSTS",
				    "rxn_oid = $rxn_oid and catalysts = $term_oid");
	    if ( $cnt3 > 0 ) {
		# reject duplicate
		next;
	    }
	}

	# save term_oid
	if ( ! WebUtil::inArray($term_oid, @term_oids) ) {
	    push @term_oids, ( $term_oid );

	    # generate delete statement for replace mode
	    if ( $replace ) {
		$sql = "delete from IMG_REACTION_T_COMPONENTS " .
		    "where term = $term_oid";
		push @sqlList, ( $sql );
		$sql = "delete from IMG_REACTION_CATALYSTS " .
		    "where catalysts = $term_oid";
		push @sqlList, ( $sql );
	    }
	}

	# save rxn_oid
	if ( ! WebUtil::inArray($rxn_oid, @rxn_oids) ) {
	    push @rxn_oids, ( $rxn_oid );
	}

	# database update
	if ( lc($assoc_type) eq 'catalyst' ) {
	    $sql = "insert into IMG_REACTION_CATALYSTS (rxn_oid, catalysts) ";
	    $sql .= "values ($rxn_oid, $term_oid)";
	    push @sqlList, ( $sql );
	}
	elsif ( lc($assoc_type) eq 'substrate' ||
		lc($assoc_type) eq 'product' ) {
	    $sql = "insert into IMG_REACTION_T_COMPONENTS (rxn_oid, term, c_type) ";
	    $sql .= "values ($rxn_oid, $term_oid, ";
	    if ( lc($assoc_type) eq 'substrate' ) {
		$sql .= "'LHS')";
	    }
	    else {
		$sql .= "'RHS')";
	    }
	    push @sqlList, ( $sql );
	}
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
	# update term cart
	if ( scalar(@term_oids) > 0 ) {
	    my $itc = new ImgTermCartStor( );
	    $itc->addImgTermBatch( \@term_oids );
	}

	# update reaction cart
	if ( scalar(@rxn_oids) > 0 ) {
	    my $irc = new ImgRxnCartStor( );
	    $irc->addImgRxnBatch( \@rxn_oids );
	}
    }
}



1;



