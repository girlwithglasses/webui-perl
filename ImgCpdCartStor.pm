############################################################################
# ImgCpdCartStor
#   imachen 01/03/2007
###########################################################################
package ImgCpdCartStor;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use DataEntryUtil;
use FuncUtil;
use ImgRxnCartStor;


my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };

my $verbose = $env->{ verbose };

my $section = "ImgCpdCartStor";
my $section_cgi = "$main_cgi?section=$section";

my $contact_oid = getContactOid( );

my $max_compound_batch = 250;
my $max_upload_line_count = 10000;   # limit the number of lines in file upload



############################################################################
# dispatch - Dispatch pages for this section.
#   All page links to this same section should be in the form of
#
#   my $url = "$main_cgi?section=$section&page=..." 
#
############################################################################
sub dispatch {

#    my @all_params = $query->param;
#    for my $p( @all_params ) {
#	print "<p>param: $p" . " => " . param($p) . "</p>\n";
#    }

    my $page = param( "page" );

    if ( $page ne "" ) {
	# follow through
    }
    elsif( paramMatch("index") ne "" ) {
	$page = "index";
    }
    elsif ( paramMatch("imgCpdCurationPage") ne "" ) {
	$page = "imgCpdCurationPage";
    }
    elsif( paramMatch( "addToImgCpdCart" ) ne "" ) {
        # add compound_oid's to Compound Cart 
        my $icc = new ImgCpdCartStor( ); 
        $icc->printCpdCartForm( "add" ); 
    }
    elsif ( paramMatch( "deleteSelectedCartImgCpds" ) ne "" ) {
	# remove selected items from the cart
	my $icc = new ImgCpdCartStor( );
	$icc->webRemoveImgCpds( );

	# show the new index page
	$page = "index";
    }
    elsif( paramMatch( "ImgCpdRxnAssoc" ) ne "" ) {
	$page = "cpdRxnAssocPage";
    }
    elsif( paramMatch( "ImgCpdFileUpload" ) ne "" ) {
	printUploadFlatFileForm();
    }
    elsif( paramMatch( "validateFile" ) ne "" ) {
	printValidationResultForm();
    }
    elsif ( paramMatch( "dbFileUpload" ) ne "" ) {
	# perform actual upload
	dbFileUpload();

	# show the new index page
	$page = "index";
    }
    elsif( paramMatch( "ImgCpdDataEntry" ) ne "" ) {
	$page = "imgCpdCurationPage";
        # printImgCpdCurationPage( );
    }
    elsif ( paramMatch( "addCpdForm" ) ne "" ) {
	printAddUpdateCpdForm( 0 );
    }
    elsif ( paramMatch( "dbAddCompound" ) ne "" ) {
	my $new_oid = dbAddCompound();
	if ( $new_oid > 0 ) {
	    # add new oids to compound cart
	    my $icc = new ImgCpdCartStor( ); 
	    my @compound_oids = param( "compound_oid" );
	    push @compound_oids, ( $new_oid );
	    $icc->addImgCpdBatch( \@compound_oids );
	}

	# go to the curation page
	$page = "imgCpdCurationPage";
    }
    elsif ( paramMatch( "updateCpdForm" ) ne "" ) {
	printAddUpdateCpdForm( 1 );
    }
    elsif ( paramMatch("dbUpdateCompound") ne "" ) {
	my $old_oid = dbUpdateCompound();

	if ( $old_oid > 0 ) {
	    # update 
	    my $icc = new ImgCpdCartStor( ); 
	    # my $recs = $icc->{ recs }; # get records 
	    # my @compound_oids = sort{ $a <=> $b }keys( %$recs );
	    my @compound_oids = ( $old_oid );
	    $icc->addImgCpdBatch( \@compound_oids );
	}

	# my $p = "_section_" . $section . "_dbUpdateCompound";
	# print "<p>*** delete $p</p>\n";
	# $query->delete($p);

	# go to the curation page
	$page = "imgCpdCurationPage";
    }
    elsif( paramMatch( "confirmDeleteCpdForm" ) ne "" ) {
	printConfirmDeleteCpdForm( );
    }
    elsif( paramMatch( "deleteCpdForm" ) ne "" ) {
	my $old_oid = dbDeleteCompound();
	if ( $old_oid > 0 ) {
	    my $icc = new ImgCpdCartStor( ); 
	    my $recs = $icc->{ recs }; # get records 
	    my $selected = $icc->{ selected };
	    delete $recs->{ $old_oid };
	    delete $selected->{ $old_oid };
	    $icc->save( );
	}

	# go to the curation page
	$page = "imgCpdCurationPage";
    }
    elsif( paramMatch( "searchReactionForm" ) ne "" ) {
	printSearchReactionForm( );
    }
    elsif( paramMatch( "searchReactionResults" ) ne "" ) {
	printSearchReactionResults( );
    }
    elsif( paramMatch( "cpdRxnAssignment" ) ne "" ) {
	printCpdRxnAssignment( );
    }
    elsif ( paramMatch("dbUpdateCpdRxn") ne "" ) {
	# update database
	dbUpdateCpdRxn();

	# go back to compound-reaction assoc page
	$page = "cpdRxnAssocPage";
    }
    elsif( paramMatch( "confirmDeleteCpdRxn" ) ne "" ) {
	printConfirmDeleteCompoundReactions( );
    }
    elsif ( paramMatch("dbDeleteCpdRxn") ne "" ) {
	# delete database
	dbDeleteCpdRxn();

	# go back to compound-reaction assoc page
	$page = "cpdRxnAssocPage";
    }

    if ( $page eq "index" ) {
	printIndex( );
    }
    elsif ( $page eq "imgCpdCurationPage" ) {
        printImgCpdCurationPage( );
    }
    elsif ( $page eq "cpdRxnAssocPage" ) {
	printCpdRxnAssocPage( );
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
    my $icc = new ImgCpdCartStor( ); 
    $icc->printCpdCartForm();
}


############################################################################
# new - New instance.
############################################################################
sub new { 
    my( $myType, $baseUrl ) = @_;
 
    $baseUrl = "$section_cgi&page=imgCpdCart" if $baseUrl eq "";
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
    my $sessionFile = "$cgi_tmp_dir/imgCpdCart.$sessionId.stor"; 
} 


############################################################################
# save - Save in persistent state.
############################################################################
sub save { 
    my( $self ) = @_; 
    store( $self, checkTmpPath( $self->getStateFile( ) ) );
}
 
############################################################################
# webAddImgCpds - Load IMG compound cart from selections.
############################################################################
sub webAddImgCpds { 
    my( $self ) = @_; 
    my @compound_oids = param( "compound_oid" );
    $self->addImgCpdBatch( \@compound_oids );
} 
 

############################################################################ 
# addImgCpdBatch - Add compounds in a batch. 
############################################################################ 
sub addImgCpdBatch { 
    my( $self, $compound_oids_ref ) = @_; 

    my $dbh = dbLogin( ); 
    my @batch; 
    my $batch_id = getNextBatchId( "imgCpd" ); 

    $self->{ selected } = { }; 
    my $selected = $self->{ selected }; 
    for my $compound_oid ( @$compound_oids_ref ) { 
        if( scalar( @batch ) > $max_compound_batch ) { 
            $self->flushImgCpdBatch( $dbh, \@batch, $batch_id );
            @batch = ( ); 
        } 
        push( @batch, $compound_oid );
        $selected->{ $compound_oid } = 1; 
    } 
 
    $self->flushImgCpdBatch( $dbh, \@batch, $batch_id ); 
    #$dbh->disconnect(); 
    $self->save( ); 
} 


############################################################################ 
# flushImgCpdBatch  - Flush one batch. 
############################################################################ 
sub flushImgCpdBatch { 
    my( $self, $dbh, $compound_oids_ref, $batch_id ) = @_; 
 
    return if( scalar( @$compound_oids_ref ) == 0 ); 
    my $compound_oid_str = join( ',', @$compound_oids_ref ); 
 
    my $recs = $self->{ recs }; 
 
    my $sql = qq{ 
        select ic.compound_oid, ic.compound_name, ic.ext_accession, c.name 
            from img_compound ic, contact c 
            where ic.compound_oid in( $compound_oid_str ) 
            and ic.modified_by = c.contact_oid 
        }; 
 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my $count = 0; 
    my $selected = $self->{ selected }; 
    for( ;; ) { 
        my( $compound_oid, $compound_name, $ext_acc, $modified_by ) =
	    $cur->fetchrow( ); 
        last  if !$compound_oid; 

        $compound_oid = FuncUtil::compoundOidPadded( $compound_oid ); 
        $count++; 
        my $r = "$compound_oid\t";
        $r .= "$compound_name\t";
        $r .= "$ext_acc\t"; 
        $r .= "$modified_by\t"; 
        $r .= "$batch_id\t";
        $recs->{ $compound_oid } = $r;
    } 
} 


########################################################################### 
# webRemoveImgCpds - Remove IMG compounds
########################################################################### 
sub webRemoveImgCpds { 
    my( $self ) = @_; 
    my @compound_oids = param( "compound_oid" );
    my $recs = $self->{ recs }; 
    my $selected = $self->{ selected };
    for my $compound_oid( @compound_oids ) { 
        delete $recs->{ $compound_oid }; 
        delete $selected->{ $compound_oid };
    } 
    $self->save( );
} 


########################################################################### 
# saveSelected - Save selections. 
########################################################################### 
sub saveSelected {
    my( $self ) = @_; 
    my @compound_oids = param( "compound_oid" );
    $self->{ selected } = { }; 
    my $selected = $self->{ selected };
    for my $compound_oid( @compound_oids ) { 
        $selected->{ $compound_oid } = 1;
    } 
    $self->save( ); 
} 

 
########################################################################### 
# printCompoundCartForm - Show form for showing compound cart. 
########################################################################### 
sub printCpdCartForm { 
    my( $self, $load ) = @_; 
 
    if( $load eq "add" ) {
        printStatusLine( "Loading ...", 1 );
        $self->webAddImgCpds( ); 
    } 
    my $dbh = dbLogin( ); 
    my $contact_oid = getContactOid( );
 
    setSessionParam( "lastCart", "imgCpdCart" );
    printMainForm( ); 
 
    print "<h1>IMG Compound Cart</h1>\n";
 
    ## Set parameters. 
    print hiddenVar( "section", $section );

    my $recs = $self->{ recs }; 
    my @compound_oids = sort( keys( %$recs ) ); 
    my $count = @compound_oids;
    if( $count == 0 ) { 
        print "<p>\n"; 
        print "0 compounds in IMG Compound cart.\n"; 
        print "</p>\n";
        printStatusLine( "0 compounds in cart", 2 );
    } 
 
    if( $count == 0 ) { 
	if( isImgEditor( $dbh, $contact_oid ) ) {
	    printCurationFunctions($count);
	}

        #$dbh->disconnect();
        return; 
    }
 
    print "<p>\n"; 
    print "$count compound(s) in cart\n";
    print "</p>\n";
 
    my $name = "_section_${section}_deleteSelectedCartImgCpds";
    print submit( -name => $name,
                  -value => "Remove Selected", -class => 'smdefbutton' );
    print " "; 
    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
 
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Selection</th>\n";
    $self->printSortHeaderLink( "Compound<br/>Object<br/>ID", 0 );
    $self->printSortHeaderLink( "Compound Name", 1 );
    $self->printSortHeaderLink( "External<br/>Accession", 2 );
    $self->printSortHeaderLink( "Batch<sup>1</sup>", 3 );
    my @sortedRecs; 
    my $sortIdx = param( "sortIdx" );
    $sortIdx = 2 if $sortIdx eq ""; 
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{ selected }; 
    for my $r( @sortedRecs ) {
        my($compound_oid, $compound_name, $ext_acc, $modified_by, $batch_id) =
            split( /\t/, $r ); 
        $compound_oid = FuncUtil::compoundOidPadded( $compound_oid ); 
        print "<tr class='img'>\n";
        print "<td class='checkbox'>\n"; 
        my $ck; 
        $ck = "checked" if $selected->{ $compound_oid } ne "";
       print "<input type='checkbox' name='compound_oid' " . 
           "value='$compound_oid' $ck />\n";
        print "</td>\n";
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
        print "<td class='img'>" . alink( $url, $compound_oid ) . "</td>\n";
        print "<td class='img'>" . escHtml( $compound_name ) . "</td>\n";
        print "<td class='img'>" . escHtml( $ext_acc ) . "</td>\n";
        print "<td class='img'>$batch_id</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    print "<p>\n"; 
    print "1 - Each time a set of compounds is added to the cart, " .
        "a new distinguishing batch number is generated for the set.<br/>\n";
    print "</p>\n"; 
    printStatusLine( "$count compound(s) in cart", 2 ); 

    if( isImgEditor( $dbh, $contact_oid ) ) {
	printCurationFunctions($count);
    }

    print end_form( ); 
    #$dbh->disconnect(); 
    $self->save( ); 
} 


############################################################################
# printCurationFunctions - print compound-reaction association
#                          and IMG compound curation
############################################################################
sub printCurationFunctions {
    my ($count) = @_;

    # compound reaction association
    print "<h2>Compound Reaction Association</h2>\n";
    print "<p>\n";
    print "Associate IMG Compounds with IMG Reactions. Search for IMG Reactions. Enter new IMG Reactions or upload file with Compound/Reaction associations.";
    print "</p>\n";
    if ( $count > 0 ) {
        my $name = "_section_${section}_ImgCpdRxnAssoc";
	print submit( -name => $name,
		      -value => "Compound Reaction Association",
		      -class => "lgdefbutton" );
	print nbsp( 1 );
    }
    my $name = "_section_${section}_ImgCpdFileUpload";
    print submit( -name => $name,
		  -value => "File Upload",
		  -class => "medbutton" );
    print "<br/>\n";

    # compound curation
    print "<h2>IMG Compound Curation</h2>\n";
    print "<p>\n"; 
    print "Add, delete, and edit IMG compounds.<br/>\n";
    print "</p>\n";
    my $name = "_section_${section}_ImgCpdDataEntry";
    print submit( -name => $name,
		  -value => "IMG Compound Curation",
		  -class => "medbutton" );
    print "<br/>\n";
}


############################################################################
# printUploadFlatFileForm
############################################################################
sub printUploadFlatFileForm {
    print "<h1>Upload IMG Compound - Reaction Associations from File</h1>\n";

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
    print "<li>Containing 5 columns: (1) IMG Compound Object ID, " .
	"(2) IMG Reaction Object ID, (3) Left or Right, " .
	"(4) Main: Yes or No, (5) Integer value for Stoichiometry.</li>\n";
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
# printUploadFlatFileForm
############################################################################
sub printValidationResultForm {
    print "<h1>File Validation Result</h1>\n";

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
    my $tmp_upload_file = $cgi_tmp_dir . "/upload.cpdrxn." . $sessionId . ".txt";

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
    my $name = "_section_${section}_dbFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Line No.</th>\n";
    print "<th class='img'>Compound Object ID</th>\n";
    print "<th class='img'>Reaction Object ID</th>\n";
    print "<th class='img'>Left/Right?</th>\n";
    print "<th class='img'>Main?</th>\n";
    print "<th class='img'>Stoichiometry Value</th>\n";
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
        my ($cpd_oid, $rxn_oid, $lr, $sm, $sv) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	# remove quotes, leading and trailing blanks
	$cpd_oid = strTrim($cpd_oid);
	if ( $cpd_oid =~ /^\s*"(.*)"$/ ) {
	    ($cpd_oid) = ($cpd_oid =~ /^\s*"(.*)"$/);
	    $cpd_oid = strTrim($cpd_oid); 
	} 

	$rxn_oid = strTrim($rxn_oid);
	if ( $rxn_oid =~ /^\s*"(.*)"$/ ) {
	    ($rxn_oid) = ($rxn_oid =~ /^\s*"(.*)"$/);
	    $rxn_oid = strTrim($rxn_oid); 
	} 

	my $msg = "";

        print "<tr class='img'>\n";

	print "<td class='img'>" . $line_no . "</td>\n";

	# check cpd_oid
	my $hasError = 0;
	if ( blankStr($cpd_oid) ) {
	    $msg = "Error: Compound OID is blank. ";
	    $hasError = 1;
	    print "<td class='img'>" . $cpd_oid . "</td>\n";
	}
	elsif ( isInt($cpd_oid) ) {
	    my $cnt1 = db_findCount ($dbh, 'IMG_COMPOUND',
				     "compound_oid = $cpd_oid");
	    if ( $cnt1 <= 0 ) { 
		$msg = "Error: Compound OID '$cpd_oid' does not exist. ";
		$hasError = 1;
		print "<td class='img'>" . $cpd_oid . "</td>\n";
	    }
	    else {
		# show URL
	        my $url = "$main_cgi?section=ImgCompound" . 
		    "&page=imgCpdDetail&compound_oid=$cpd_oid";
		print "<td class='img'>" . alink( $url, $cpd_oid ) . "</td>\n";
	    }
	}
	else {
	    $msg = "Error: Compound Object ID must be an integer. ";
	    $hasError = 1;
	    print "<td class='img'>" . $cpd_oid . "</td>\n";
	}

	# check rxn_oid
	if ( blankStr($rxn_oid) ) {
	    $msg .= "Error: Reaction OID is blank. ";
	    $hasError = 1;
	    print "<td class='img'>" . $rxn_oid . "</td>\n";
	}
	elsif ( isInt($rxn_oid) ) {
	    my $cnt2 = db_findCount ($dbh, 'IMG_REACTION',
				       "rxn_oid = $rxn_oid");
	    if ( $cnt2 <= 0 ) { 
		$msg .= "Error: Reaction OID '$rxn_oid' does not exist. ";
		$hasError = 1;
		print "<td class='img'>" . $rxn_oid . "</td>\n";
	    }
	    else {
		# show URL
	        my $url = "$main_cgi?section=ImgReaction" . 
		    "&page=imgRxnDetail&rxn_oid=$rxn_oid";
		print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
	    }
	}
	else {
	    $msg = "Error: Reaction Object ID must be an integer. ";
	    $hasError = 1;
	    print "<td class='img'>" . $rxn_oid . "</td>\n";
	}

	if ( $hasError == 0 && $replace == 0 ) {
	    # check whether compound-reaction association already exist
	    my $cnt3 = db_findCount ($dbh, 'IMG_REACTION_C_COMPONENTS',
				     "compound = $cpd_oid and rxn_oid = $rxn_oid");
	    if ( $cnt3 > 0 ) {
		$msg .= "Error: Compound-Reaction association already exists.";
	    }
	}

	# Left or Right?
	$lr = strTrim($lr);
	print "<td class='img'>" . escapeHTML($lr) . "</td>\n";
	if ( blankStr($lr) ) {
	    $msg .= " Error: Must specify 'Left' or 'Right' of the reaction.";
	}
	elsif ( lc($lr) ne 'left' && lc($lr) ne 'right' ) {
	    $msg .= " Error: Incorrect keyword '$lr' -- " .
		"Must specify 'Left' or 'Right' of the reaction.";
	}

	# Stoichiometry or Main?
	$sm = strTrim($sm);
	print "<td class='img'>" . escapeHTML($sm) . "</td>\n";
	if ( blankStr($sm) ) {
	    # ok
	}
	elsif ( lc($sm) ne 'yes' && lc($sm) ne 'no' ) {
	    $msg .= " Error: Incorrect keyword for Main?: '$sm' -- " .
		"Must specify 'Yes' or 'No'.";
	}

	# Stoichiometry Value
	$sv = strTrim($sv);
	print "<td class='img'>" . escapeHTML($sv) . "</td>\n";
	if ( ! blankStr($sv) && ! isInt($sv) ) {
	    $msg .= " Error: Stoichiometry value must be an integer.";
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
    my $name = "_section_${section}_dbFileUpload";
    print submit( -name => $name,
		  -value => 'Upload', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print end_form();
}


############################################################################
# dbFileUpload - handle the actual data upload
############################################################################
sub dbFileUpload {
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
    my @cpd_oids;

    my $line_no = 0;
    my $line;
    while ($line = <FILE>) {
	chomp($line);
        my ($cpd_oid, $rxn_oid, $lr, $sm, $sv) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	# remove quotes, leading and trailing blanks
	$cpd_oid = strTrim($cpd_oid);
	if ( $cpd_oid =~ /^\s*"(.*)"$/ ) {
	    ($cpd_oid) = ($cpd_oid =~ /^\s*"(.*)"$/);
	    $cpd_oid = strTrim($cpd_oid); 
	} 

	$rxn_oid = strTrim($rxn_oid);
	if ( $rxn_oid =~ /^\s*"(.*)"$/ ) {
	    ($rxn_oid) = ($rxn_oid =~ /^\s*"(.*)"$/);
	    $rxn_oid = strTrim($rxn_oid); 
	} 

	# check cpd_oid
	if ( blankStr($cpd_oid) ) {
	    # next
	}
	elsif ( isInt($cpd_oid) ) {
	    my $cnt1 = db_findCount ($dbh, 'IMG_COMPOUND',
				     "compound_oid = $cpd_oid");
	    if ( $cnt1 <= 0 ) { 
		# compound oid does not exist
		next;
	    }
	}
	else {
	    next;
	}

	# check rxn_oid
	if ( blankStr($rxn_oid) ) {
	    next;
	}
	elsif ( isInt($rxn_oid) ) {
	    my $cnt2 = db_findCount ($dbh, 'IMG_REACTION',
				       "rxn_oid = $rxn_oid");
	    if ( $cnt2 <= 0 ) { 
		# rxn oid does not exist
		next;
	    }
	}
	else {
	    next;
	}

	# Left or Right?
	$lr = strTrim($lr);
	if ( blankStr($lr) ) {
	    next;
	}
	elsif ( lc($lr) ne 'left' && lc($lr) ne 'right' ) {
	    next;
	}

	# Stoichiometry or Main?
	$sm = strTrim($sm);
	if ( blankStr($sm) ) {
	    next;
	}
	elsif ( lc($sm) ne 'yes' && lc($sm) ne 'no' ) {
	    next;
	}

	# Stoichiometry value
	$sv = strTrim($sv);
	if ( !blankStr($sv) && !isInt($sv) ) {
	    next;
	}

	# check whether compound-reaction association already exist
	my $cnt1 = db_findCount ($dbh, 'IMG_REACTION_C_COMPONENTS',
				 "compound = $cpd_oid and rxn_oid = $rxn_oid");

	if ( $cnt1 > 0 && $replace == 0 ) {
	    # reject duplicate entries
	    next;
	}

	# save cpd_oid
	if ( ! WebUtil::inArray($cpd_oid, @cpd_oids) ) {
	    push @cpd_oids, ( $cpd_oid );

	    # generate delete statement for replace mode
	    if ( $replace ) {
		$sql = "delete from IMG_REACTION_C_COMPONENTS " .
		    "where compound = $cpd_oid";
		push @sqlList, ( $sql );
	    }
	}

	# save rxn_oid
	if ( ! WebUtil::inArray($rxn_oid, @rxn_oids) ) {
	    push @rxn_oids, ( $rxn_oid );
	}

	# generate insert statement
	my $has_sv = 0;
	if ( !blankStr($sv) && isInt($sv) ) {
	    $has_sv = 1;
	}

	$sql = "insert into IMG_REACTION_C_COMPONENTS";
	if ( $has_sv ) {
	    $sql .= " (rxn_oid, compound, c_type, main_flag, stoich)";
	}
	else {
	    $sql .= " (rxn_oid, compound, c_type, main_flag)";
	}
	$sql .= " values ($rxn_oid, $cpd_oid, ";

	# LHS or RHS
	if ( lc($lr) eq "left" ) {
	    $sql .= "'LHS'";
	}
	else {
	    $sql .= "'RHS'";
	}

	# Main?
	if ( lc($sm) eq 'yes' ) {
	    $sql .= ", 'Yes'";
	}
	elsif ( lc($sm) eq 'no' ) {
	    $sql .= ", 'No'";
	}
	else {
	    $sql .= ", ";
	}

	if ( $has_sv ) {
	    $sql .= ", $sv)";
	}
	else {
	    $sql .= ")";
	}
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
	# update compound cart
	if ( scalar(@cpd_oids) > 0 ) {
	    my $icc = new ImgCpdCartStor( );
	    $icc->addImgCpdBatch( \@cpd_oids );
	}

	# update reaction cart
	if ( scalar(@rxn_oids) > 0 ) {
	    my $irc = new ImgRxnCartStor( );
	    $irc->addImgRxnBatch( \@rxn_oids );
	}
    }

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
#   sortIdx - is column index to sort on, starting from 0. 
############################################################################ 
sub sortedRecsArray { 
    my( $self, $sortIdx, $outRecs_ref ) = @_; 
    my $recs = $self->{ recs }; 
    my @compound_oids = keys( %$recs ); 
    my @a; 
    my @idxVals; 
    for my $compound_oid ( @compound_oids ) { 
        my $rec = $recs->{ $compound_oid }; 
        my @fields = split( /\t/, $rec ); 
        my $sortRec; 
        my $sortFieldVal = $fields[ $sortIdx ]; 
        if( $sortIdx == 0 || $sortIdx == 2 ) { 
            $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $compound_oid ); 
        } 
        else { 
            $sortRec = sprintf( "%s\t%s", $sortFieldVal, $compound_oid ); 
        } 
        push( @idxVals, $sortRec ); 
    } 
    my @idxValsSorted = sort( @idxVals ); 
    for my $i( @idxValsSorted ) {
        my( $idxVal, $compound_oid ) = split( /\t/, $i );
        my $r = $recs->{ $compound_oid }; 
        push( @$outRecs_ref, $r ); 
    } 
} 


############################################################################ 
############################################################################
# The following code is for data entry 
############################################################################
############################################################################
 
############################################################################ 
# printImgCpdCurationPage - Show curation main page. 
############################################################################ 
sub printImgCpdCurationPage { 
    print "<h1>IMG Compound Curation Page</h1>\n"; 
    printMainForm( ); 
 
    print "<meta http-equiv=\"norefresh\">\n";
    print "<h3>Note: This page only allows single IMG Compound selection.</h3>\n";

    print "<p>\n"; 
 
    # list all compounds
    my $icc = new ImgCpdCartStor( ); 
 
    my $recs = $icc->{ recs }; # get records 
 
    my @compound_oids = sort{ $a <=> $b }keys( %$recs ); 
        # The keys for the records are compound_oids. 
        # But we want them sorted. 
 
    # print count 
    my $count = scalar( @compound_oids ); 
    print "<p>\n"; 
    print "$count compound(s) in cart\n"; 
    print "</p>\n";
 
    ### Print the records out in a table.
    print "<table class='img'>\n"; 
    print "<th class='img'>Select for<br/>Delete/Update</th>\n";
    print "<th class='img'>Compound ID</th>\n"; 
    print "<th class='img'>Compound Name</th>\n";
    print "<th class='img'>External Accession</th>\n";
    print "<th class='img'>Modified by</th>\n";
    print "<th class='img'>Batch</th>\n";
    for my $compound_oid ( @compound_oids ) {
        my $i = $compound_oid;
 
        my $r = $recs->{ $compound_oid }; 
        my( $compound_oid, $compound_name, $ext_acc, $modified_by,
	    $batch_id ) =
            split( /\t/, $r ); 
 
        print "<tr class='img'>\n";
  
        print "<td class='img'>\n"; 
        print "<input type='radio' "; 
        print "name='compound_oid' value='$compound_oid' />\n";
        print "</td>\n"; 
 
        # compound_oid with url
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
        print "<td class='img'>" . alink( $url, $compound_oid ) . "</td>\n";
 
        # compound_name
        print "<td class='img'>" . escapeHTML( $compound_name ) . "</td>\n";
 
        # ext accession
        print "<td class='img'>" . escapeHTML( $ext_acc ) . "</td>\n";
 
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

    # add New, Delete and Update IMG Compound button
    my $name = "_section_${section}_addCpdForm";
    print submit( -name => $name,
                  -value => 'New IMG Compound', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteCpdForm";
    print submit( -name => $name,
                  -value => 'Delete IMG Compound', -class => 'smbutton' ); 
    print nbsp( 1 ); 
    my $name = "_section_${section}_updateCpdForm";
    print submit( -name => $name,
                  -value => 'Update IMG Compound', -class => 'smbutton' );
 
    print "</p>\n"; 
 
    print end_form( ); 
} 


############################################################################
# printAddUpdateCpdForm - add or update an IMG compound
############################################################################
sub printAddUpdateCpdForm {
    my ( $update ) = @_;   # add or update

    if ( $update ) {
	print "<h1>Update IMG Compount Page</h1>\n";
    }
    else {
	print "<h1>Add IMG Compound Page</h1>\n";
    }

    printMainForm( );

    # add Add/Update, Reset and Cancel buttons
    if ( $update ) {
        my $name = "_section_${section}_dbUpdateCompound";
	print submit( -name => $name,
		      -value => 'Update', -class => 'smdefbutton' );
    }
    else {
        my $name = "_section_${section}_dbAddCompound";
	print submit( -name => $name,
		      -value => 'Add', -class => 'smdefbutton' );
    }

    print nbsp( 1 );
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_imgCpdCurationPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "<p>\n"; # paragraph section puts text in proper font.

    # save selected term oids
    my $icc = new ImgCpdCartStor( ); 
    my $recs = $icc->{ recs }; # get records 
 
    my @compound_oids = sort{ $a <=> $b }keys( %$recs );
 
    # get selected compound oids
    my @selected_cpd_oids = param( "compound_oid" ); 
    my %selected_cpd_oids_h; 
    for my $compound_oid( @selected_cpd_oids ) { 
	$selected_cpd_oids_h{ $compound_oid } = 1; 
    } 

    ## Set parameters.
    print hiddenVar( "section", $section );

    # get selected compound oids
    # need to record all selected compounds
    # save term selections in a hidden variable 
    print "<input type='hidden' name='selectedCompounds' value='"; 
    for my $compound_oid ( @selected_cpd_oids ) { 
        print "$compound_oid "; 
    } 
    print "'>\n"; 

    my $update_compound_oid = -1;
    if ( $update ) {
	if ( scalar (@selected_cpd_oids) > 0 ) {
	    $update_compound_oid = $selected_cpd_oids[0];
	}
	else {
	    webError ("No IMG compound is selected.");
	    return;
	}
    }

    # if it is update, then we need to get compound info from the database
    my $db_ext_acc = "";
    my $db_db_src = "";
    my $db_cpd_name= "";
    my $db_common_name = "";
    my $db_class = "";
    my $db_comp = "";
    my $db_formula = "";
    my $db_cas = "";
    my $db_status = "";
    my @db_aliases = ();
    my @db_sources = ("", "CHEBI", "KEGG LIGAND");

    my @db_kegg_cpds = ();

    # get all db_sources
    my $dbh = dbLogin( );
    my $sql;
    my $cur;

    # get compound info for "update"
    if ( $update && $update_compound_oid > 0 ) {
	$sql = qq{
	        select ic.ext_accession, ic.db_source, ic.compound_name,
		    ic.common_name, ic.class, ic.composition, ic.formula,
		    ic.cas_number, ic.status
		    from img_compound ic
		    where ic.compound_oid = ?
		};

	$cur = execSql( $dbh, $sql, $verbose, $update_compound_oid );
	($db_ext_acc, $db_db_src, $db_cpd_name, $db_common_name,
	 $db_class, $db_comp, $db_formula, $db_cas, $db_status) = $cur->fetchrow( );
	$cur->finish( );

	# aliases
	$sql = qq{
	        select ica.aliases
		    from img_compound_aliases ica
		    where ica.compound_oid = $update_compound_oid
		};

	$cur = execSql( $dbh, $sql, $verbose );
	for (;;) { 
	    my ( $val ) = $cur->fetchrow( );
	    last if !$val;
 
	    push @db_aliases, ( $val );
	}
	$cur->finish( );

	# KEGG compounds
	$sql = qq{
	        select ickc.compound
		    from img_compound_kegg_compounds ickc
		    where ickc.compound_oid = ?
		};

	$cur = execSql( $dbh, $sql, $verbose, $update_compound_oid );
	for (;;) { 
	    my ( $val ) = $cur->fetchrow( );
	    last if !$val;
 
	    push @db_kegg_cpds, ( $val );
	}
	$cur->finish( );
    }
    #$dbh->disconnect();

    print "<h2>Compound Information</h2>\n";
    
    print "<table class='img' border='1'>\n";

    # New compound
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>IMG Compound Name</th>\n";
    print "  <td class='img'   align='left'>" .
	"<input type='text' name='newCompound' value='" .
	escapeHTML($db_cpd_name) . "' size='60' maxLength='255'/>" . "</td>\n";
    print "</tr>\n";

    # DB Source
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>DB Source</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='dbSourceSelection' class='img' size='3'>\n";
    for my $tt ( @db_sources ) {
	print "        <option value='$tt'";
	if ( (uc $db_db_src) eq (uc $tt) ) {
	    print " selected";
	}
	print ">$tt</option>\n";
    }
    print "     </select>\n";
    print "</td>\n</tr>\n";

    # ext accession
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Ext Accession</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='extAcc' value='" .
	escapeHTML($db_ext_acc) . "' size='50' maxLength='50' />" . "</td>\n";
    print "</tr>\n";

    # Common name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Common Name</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='cmName' value='" .
	escapeHTML($db_common_name) . "' size='60' maxLength='255' />" . "</td>\n";
    print "</tr>\n";

    # Class
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Class</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='cls' value='" .
	escapeHTML($db_class) . "' size='60' maxLength='255' />" . "</td>\n";
    print "</tr>\n";

    # Composition
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Composition</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='comp' value='" .
	escapeHTML($db_comp) . "' size='60' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    # formula
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Formula</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='formula' value='" .
	escapeHTML($db_formula) . "' size='60' maxLength='4000' />" . "</td>\n";
    print "</tr>\n";

    # Cas number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>CAS Number</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='cas' value='" .
	escapeHTML($db_cas) . "' size='60' maxLength='255' />" . "</td>\n";
    print "</tr>\n";

    # status
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Status</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='status' value='" .
	escapeHTML($db_status) . "' size='10' maxLength='10' />" . "</td>\n";
    print "</tr>\n";

    # KEGG compounds
    my $kegg_cpds = "";
    for my $k1 ( @db_kegg_cpds ) {
	if ( length($kegg_cpds) == 0 ) {
	    $kegg_cpds = $k1;
	}
	else {
	    $kegg_cpds .= " " . $k1;
	}
    }
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>KEGG Compound ID(s)<br/>(Use blank to separate multiple ID's)</th>\n";
    print "  <td class='img'   align='left'>" . 
	"<input type='text' name='kegg_cpds' value='" .
	escapeHTML($kegg_cpds) . "' size='60' maxLength='1000' />" . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    # add aliases
    # add java script function 'changeAlias' 
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function changeAlias(x) {\n"; 
    print "   var ali = document.getElementById('aliasSelect');\n";
    print "   var newali = document.getElementById('newAlias');\n";

    print "   if ( x == 0 ) {\n";
    print "      ali.selectedIndex = -1;\n";
    print "      return;\n";
    print "      }\n"; 

    print "   if ( x == 1 && newali.value.length > 0 ) {\n";
    print "      var nOption = document.createElement(\"option\");\n";
    print "      nOption.value = newali.value;\n";
    print "      nOption.text = newali.value;\n";
    print "      ali.appendChild(nOption);\n";
    print "      }\n";

    print "   if ( x == 2 && ali.selectedIndex >= 0 ) {\n";
    print "      ali.remove(ali.selectedIndex);\n";
    print "      }\n"; 

    print "   if ( x == 3 && newali.value.length > 0 && ali.selectedIndex >= 0 ) {\n";
    print "      var uOption = ali.options[ali.selectedIndex];\n";
    print "      uOption.value = newali.value;\n";
    print "      uOption.text = newali.value;\n";
    print "      }\n";

    print "   var allAli = document.getElementById('allAliases');\n";
    print "   allAli.value = \"\";\n";
    print "   for (var i = 0; i < ali.options.length; i++) {\n";
    print "       if ( i > 0 ) {\n";
    print "          allAli.value += \"\\n\";\n";
    print "          }\n";
    print "       allAli.value += ali.options[i].value;\n";
    print "       }\n";

    print "   }\n"; 

    print "\n</script>\n\n"; 

    my $allAli = '';
    for my $s ( @db_aliases ) {
	$allAli .= "\n" . escapeHTML($s);
    }

    print "<input type='hidden' id='allAliases' name='allAliases' value='$allAli'>\n"; 

    print "<h2>Aliases of this IMG Compound</h2>\n";

    # add buttons of aliases
    print "<p>\n";
    print "New Alias: <input type='text' id='newAlias' name='newAlias' size='60' maxLength='255' />\n";
    print "</p>\n";

    print "<input type='button' name='addAlias' value='Add Alias' " .
        "onClick='changeAlias(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='deleteAlias' value='Delete Alias' " .
        "onClick='changeAlias(2)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='updateAlias' value='Update Alias' " .
        "onClick='changeAlias(3)' class='smbutton' />\n";
     print nbsp( 1 );
    print "<input type='button' name='clearSelection' value='Clear Selection' " .
        "onClick='changeAlias(0)' class='smbutton' />\n";
    print "<p>\n";

    # display list of aliases
    print "<select id='aliasSelect' name='aliasSelect' class='img' size='10'";
    print " onChange='document.getElementById(\"newAlias\").value=this.value' >\n";
    for my $s1 ( @db_aliases ) {
	print "           <option value='$s1'>$s1</option>\n";
    }
    print "</select>\n";

    print end_form( );
}


############################################################################
# dbAddCompound - add a new compound to the database
############################################################################
sub dbAddCompound() {
    # get input parameters
    my $newCompound = param ('newCompound');
    my $db_source = param ( 'dbSourceSelection' );
    my $ext_accession = param ('extAcc');
    my $common_name = param ('cmName');
    my $formula = param ('formula');
    my $comp = param ('comp');
    my $cls = param ( 'cls' );
    my $cas_number = param ( 'cas' );
    my $status = param ( 'status' );

    # check input
    chomp($newCompound);
    if ( !$newCompound || blankStr($newCompound) ) {
	webError ("Please enter a new compound name.");
	return -1;
    }

    # login
    my $dbh = dbLogin(); 

    # compound already exist?
    my $id2 = db_findID ($dbh, 'IMG_COMPOUND', 'COMPOUND_OID', 'COMPOUND_NAME',
			 $newCompound, '');
    if ( $id2 > 0 ) {
	#$dbh->disconnect();
	webError ("Compound already exists. (COMPOUND_OID=$id2)");
	return -1;
    }

    # check kegg compounds
    my $s = checkKeggCompounds ($dbh, param('kegg_cpds'));
    if ( !blankStr($s) ) {
	#$dbh->disconnect();
	webError ("Incorrect KEGG Compound ID");
	return -1;
    }

    my @sqlList = ();

    # get next oid
    my $new_cpd_oid = db_findMaxID( $dbh, 'IMG_COMPOUND', 'COMPOUND_OID') + 1;
    #$dbh->disconnect();

    # prepare insertion
    my $ins = "insert into IMG_COMPOUND (compound_oid, compound_name";
    my $s = $newCompound;
    $s =~ s/'/''/g;  # replace ' with ''
    my $vals = "values ($new_cpd_oid, '". $s . "'";

    if ( $db_source && length($db_source) > 0 ) {
	$ins .= ", db_source";
	$s = $db_source;
	$s =~ s/'/''/g;  # replace ' with ''
	$vals .= ", '$s'";
    }

    if ( $ext_accession && length($ext_accession) > 0 ) {
	$ext_accession =~ s/'/''/g;  # replace ' with ''
	$ins .= ", ext_accession";
	$vals .= ", '$ext_accession'";
    }


    if ( $common_name && length($common_name) > 0 ) {
	$common_name =~ s/'/''/g;  # replace ' with ''
	$ins .= ", common_name";
	$vals .= ", '$common_name'";
    }

    if ( $cls && length($cls) > 0 ) {
	$cls =~ s/'/''/g;  # replace ' with ''
	$ins .= ", class";
	$vals .= ", '$cls'";
    }

    if ( $comp && length($comp) > 0 ) {
	$comp =~ s/'/''/g;  # replace ' with ''
	$ins .= ", composition";
	$vals .= ", '$comp'";
    }

    if ( $formula && length($formula) > 0 ) {
	$formula =~ s/'/''/g;  # replace ' with ''
	$ins .= ", formula";
	$vals .= ", '$formula'";
    }

    if ( $cas_number && length($cas_number) > 0 ) {
	$cas_number =~ s/'/''/g;  # replace ' with ''
	$ins .= ", cas_number";
	$vals .= ", '$cas_number'";
    }

    if ( $status && length($status) > 0 ) {
	$status =~ s/'/''/g;  # replace ' with ''
	$ins .= ", status";
	$vals .= ", '$status'";
    }

    # modified by
    if ( $contact_oid ) {
	$ins .= ", modified_by";
	$vals .= ", $contact_oid";
    }

    $ins .= ", add_date, mod_date) ";
    $vals .= ", sysdate, sysdate)";

    my $sql = $ins . $vals;
    push @sqlList, ( $sql );

    # insert all KEGG compounds
    my @allKeggCpds = split (/ /, param('kegg_cpds'));

    for my $s ( @allKeggCpds ) {
	if ( length($s) > 0 ) {
	    $s =~ s/'/''/g;  # replace ' with ''
	    $sql = "insert into IMG_COMPOUND_KEGG_COMPOUNDS ";
	    $sql .= "(compound_oid, compound, modified_by, mod_date)";
	    $sql .= " values (" . $new_cpd_oid . ", '" . $s .
		"', " . $contact_oid . ", sysdate)";
	}

	push @sqlList, ( $sql );
    }

    # insert all aliases
    my @allAliases = split (/\n/, param('allAliases'));

    for my $s ( @allAliases ) {
	if ( length($s) > 0 ) {
	    $s =~ s/'/''/g;  # replace ' with ''
	    $sql = "insert into IMG_COMPOUND_ALIASES (compound_oid, aliases)";
	    $sql .= " values (" . $new_cpd_oid . ", '" . $s . "')";
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
	return $new_cpd_oid;
    }
}


############################################################################
# dbUpdateCompound - update compound information in the database
############################################################################
sub dbUpdateCompound() {
   # get the compound oid
    my @selected_cpd_oids = param( "selectedCompounds" ); 
    if ( scalar (@selected_cpd_oids) == 0 ) {
	webError ("No IMG compound is selected.");
	return -1;
    }
    my $compound_oid = $selected_cpd_oids[0];

    # get input parameters
    my $newCompound = param ('newCompound');
    my $db_source = param ( 'dbSourceSelection' );
    my $ext_accession = param ('extAcc');
    my $common_name = param ('cmName');
    my $formula = param ('formula');
    my $comp = param ('comp');
    my $cls = param ( 'cls' );
    my $cas_number = param ( 'cas' );
    my $status = param ( 'status' );

    # check input
    chomp($newCompound);
    if ( !$newCompound || blankStr($newCompound) ) {
	webError ("Please enter a new compound name.");
	return -1;
    }

    # login
    my $dbh = dbLogin(); 

    # compound already exist?
    my $id2 = db_findID ($dbh, 'IMG_COMPOUND', 'COMPOUND_OID', 'COMPOUND_NAME',
			 $newCompound, "compound_oid <> $compound_oid");
    if ( $id2 > 0 ) {
	#$dbh->disconnect();
	webError ("Compound already exists. (COMPOUND_OID=$id2)");
	return -1;
    }

    # check kegg compounds
    my $s = checkKeggCompounds ($dbh, param('kegg_cpds'));
    if ( !blankStr($s) ) {
	#$dbh->disconnect();
	webError ("Incorrect KEGG Compound ID");
	return -1;
    }

    #$dbh->disconnect();

    my @sqlList = ();

    # prepare update
    $newCompound =~ s/'/''/g;  # replace ' with ''
    $db_source =~ s/'/''/g;  # replace ' with ''
    $ext_accession =~ s/'/''/g;  # replace ' with ''
    $common_name =~ s/'/''/g;  # replace ' with ''
    $formula =~ s/'/''/g;  # replace ' with ''
    $comp =~ s/'/''/g;  # replace ' with ''
    $cls =~ s/'/''/g;  # replace ' with ''
    $cas_number =~ s/'/''/g;  # replace ' with ''
    $status =~ s/'/''/g;  # replace ' with ''

    # update IMG_COMPOUND table

    my $sql = "update IMG_COMPOUND set compound_name = '$newCompound',";
    $sql .= " db_source = '$db_source', ext_accession = '$ext_accession', ";
    $sql .= " common_name = '$common_name', formula = '$formula', ";
    $sql .= " composition = '$comp', class = '$cls', ";
    $sql .= " cas_number = '$cas_number', status = '$status', ";
    $sql .= " mod_date = sysdate, modified_by = $contact_oid ";
    $sql .= " where compound_oid = $compound_oid";

    push @sqlList, ( $sql );

    # update all KEGG compounds
    $sql = "delete from IMG_COMPOUND_KEGG_COMPOUNDS where compound_oid = $compound_oid";
    push @sqlList, ( $sql );
    my @allKeggCpds = split (/ /, param('kegg_cpds'));

    for my $s ( @allKeggCpds ) {
	if ( length($s) > 0 ) {
	    $s =~ s/'/''/g;  # replace ' with ''
	    $sql = "insert into IMG_COMPOUND_KEGG_COMPOUNDS ";
	    $sql .= "(compound_oid, compound, modified_by, mod_date)";
	    $sql .= " values (" . $compound_oid . ", '" . $s .
		"', " . $contact_oid . ", sysdate)";
	}

	push @sqlList, ( $sql );
    }

    # update aliases
    $sql = "delete from IMG_COMPOUND_ALIASES where compound_oid = $compound_oid";
    push @sqlList, ( $sql );

    my @allAliases = split (/\n/, param('allAliases'));

    for my $s ( @allAliases ) {
	if ( length($s) > 0 ) {
	    $s =~ s/'/''/g;  # replace ' with ''
	    $sql = "insert into IMG_COMPOUND_ALIASES (compound_oid, aliases)";
	    $sql .= " values (" . $compound_oid . ", '" . $s . "')";
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
	return $compound_oid;
    }
}


############################################################################
# printConfirmDeleteCpdForm - ask user to confirm deletion
############################################################################
sub printConfirmDeleteCpdForm {
    print "<h1>Delete IMG Compound Page</h1>\n";

    printMainForm( );

    # get the compound oid
    my @selected_cpd_oids = param( "compound_oid" ); 
    if ( scalar (@selected_cpd_oids) == 0 ) {
	@selected_cpd_oids = param( "selectedCompounds" );
    }
    if ( scalar (@selected_cpd_oids) == 0 ) {
	webError ("No IMG compound is selected.");
	return -1;
    }

    my $compound_oid = $selected_cpd_oids[0];

    # get compound info
    my $icc = new ImgCpdCartStor( ); 
    my $recs = $icc->{ recs }; # get records 
    my $r = $recs->{ $compound_oid }; 
    my( $c_oid, $cpd_name, $ext_acc, $modified_by, $batch_id ) = split( /\t/, $r );

    print "<h2>IMG Compound: ($c_oid) $cpd_name</h2>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print hiddenVar( "selectedCompounds", $compound_oid );

    print "<p><font color=\"red\"> ";
    print "Warning: The following compound-reaction association, " .
	"compound-pathway association and compound-pathway network association " .
	"will be deleted as well.</font></p>\n";

    my $dbh = dbLogin( );

    # show compound-reaction association
    print "<h3>IMG Compound - Reaction Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";
    print "<th class='img'>Compound OID</th>\n";
    print "<th class='img'>C_Type</th>\n";

    # IMG_REACTION_C_COMPONENTS
    my $sql = qq{
	select r.rxn_oid, r.rxn_name, ircc.compound, ircc.c_type
	        from img_reaction r, img_reaction_c_components ircc
		    where r.rxn_oid = ircc.rxn_oid
		        and ircc.compound = $compound_oid
		    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $r_oid, $r_name, $c_oid, $c_type ) = $cur->fetchrow( );
	last if !$r_oid;

	print "<tr class='img'>\n";
	my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 
        print "<td class='img'>" . alink( $url, $r_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $r_name ) . "</td>\n";
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$c_oid";
        print "<td class='img'>" . alink( $url, $c_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $c_type ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    # show compound-pathway association
    print "<h3>IMG Compound - Pathway Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Pathway OID</th>\n";
    print "<th class='img'>Pathway Name</th>\n";
    print "<th class='img'>Compound OID</th>\n";
    print "<th class='img'>C_Type</th>\n";

    # IMG_REACTION_C_COMPONENTS
    my $sql = qq{
	select p.pathway_oid, p.pathway_name, ipcc.compound, ipcc.c_type
	        from img_pathway p, img_pathway_c_components ipcc
		    where p.pathway_oid = ipcc.pathway_oid
		        and ipcc.compound = ?
		    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
	my( $p_oid, $p_name, $c_oid, $c_type ) = $cur->fetchrow( );
	last if !$p_oid;

	print "<tr class='img'>\n";
	my $url = "$main_cgi?page=imgPwayDetail&pway_oid=$p_oid"; 
        print "<td class='img'>" . alink( $url, $p_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $p_name ) . "</td>\n";
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$c_oid";
        print "<td class='img'>" . alink( $url, $c_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $c_type ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    # show compound-pathway network association
    print "<h3>IMG Compound - Pathway Network Association to be Deleted:</h3>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Network OID</th>\n";
    print "<th class='img'>Network Name</th>\n";
    print "<th class='img'>Compound OID</th>\n";
    print "<th class='img'>C_Type</th>\n";

    # IMG_REACTION_C_COMPONENTS
    my $sql = qq{
	select n.network_oid, n.network_name, pncc.compound, pncc.c_type
	        from pathway_network n, pathway_network_c_components pncc
		    where n.network_oid = pncc.network_oid
		        and pncc.compound = ?
		    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
	my( $n_oid, $n_name, $c_oid, $c_type ) = $cur->fetchrow( );
	last if !$n_oid;

	print "<tr class='img'>\n";
	# my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 
        # print "<td class='img'>" . alink( $url, $r_oid ) . "</td>\n";
        print "<td class='img'>" . $n_oid . "</td>\n";
        print "<td class='img'>" . escapeHTML( $n_name ) . "</td>\n";
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$c_oid";
        print "<td class='img'>" . alink( $url, $c_oid ) . "</td>\n";
        print "<td class='img'>" . escapeHTML( $c_type ) . "</td>\n";
    }
    $cur->finish( );

    print "</table>\n";

    #$dbh->disconnect();

    # add Delete and Cancel buttons
    print "<p>\n";
    my $name = "_section_${section}_deleteCpdForm";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_ImgCpdDataEntry";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    print "<p>\n"; # paragraph section puts text in proper font.
}


############################################################################
# dbDeleteCompound - delete an IMG compound from the database
############################################################################
sub dbDeleteCompound {
    # get the compound oid
    my $old_oid = param( "selectedCompounds" );
    if ( blankStr($old_oid) ) {
	webError ("No IMG compound is selected.");
	return -1;
    }

    # prepare SQL
    my @sqlList = ();

    # delete from IMG_REACTION_C_COMPONENTS
    my $sql = "delete from IMG_REACTION_C_COMPONENTS where compound = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_PATHWAY_C_COMPONENTS
    my $sql = "delete from IMG_PATHWAY_C_COMPONENTS where compound = $old_oid";
    push @sqlList, ( $sql );

    # delete from PATHWAY_NETWORK_C_COMPONENTS
    my $sql = "delete from PATHWAY_NETWORK_C_COMPONENTS where compound = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_COMPOUND_ALIASES
    $sql = "delete from IMG_COMPOUND_ALIASES where compound_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_COMPOUND_KEGG_COMPOUNDS
    $sql = "delete from IMG_COMPOUND_KEGG_COMPOUNDS where compound_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_COMPOUND_EXT_LINKS
    $sql = "delete from IMG_COMPOUND_EXT_LINKS where compound_oid = $old_oid";
    push @sqlList, ( $sql );

    # delete from IMG_COMPOUND
    $sql = "delete from IMG_COMPOUND where compound_oid = $old_oid";
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
# printCpdRxnAssocPage - print Compound-Reaction Association oage
############################################################################
sub printCpdRxnAssocPage {
    print "<h1>Compound Reaction Association Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print "</p>\n";

    # list all compounds
    printCartCompounds();
    print "<br/>\n";

    # IMG term
    print "<h2>Curate IMG Reaction for the Selected Compound(s)</h2>\n";

    #my $url = "$main_cgi?section=$section&page=searchTermForm";
    #print alink( $url, "Search Terms" ) . "<br/>\n";
    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchReactionForm";
    print submit( -name => $name,
		  -value => 'Add IMG Reaction', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteCpdRxn";
    print submit( -name => $name,
		  -value => 'Delete IMG Reaction(s)', -class => 'smbutton' );

    print "</p>\n";

    print "</p>\n";

    print end_form( );
}


############################################################################
# printCartCompounds - show all compounds in the cart
#                      (with reaction info)
############################################################################
sub printCartCompounds {

    my $icc = new ImgCpdCartStor( );

    my $recs = $icc->{ recs }; # get records

    my @compound_oids = sort{ $a <=> $b }keys( %$recs );

    my @selected_cpd_oids = param( "compound_oid" );
    my %selected_cpd_oids_h;
    for my $compound_oid( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    # print count
    my $count = scalar( @compound_oids );
    print "<p>\n";
    print "$count compound(s) in cart\n";
    print "</p>\n"; 

    my $dbh = dbLogin( );

    # get IMG reaction count for all compounds
    my %rxnCount = getImgRxnCount($dbh, @compound_oids);

    #$dbh->disconnect();

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Compound Object ID</th>\n";
    print "<th class='img'>Compound Name</th>\n";
    print "<th class='img'>External Accession</th>\n";
    print "<th class='img'>IMG Reaction Count</th>\n";
    print "<th class='img'>Batch</th>\n";
    for my $compound_oid ( @compound_oids ) {
	my $r = $recs->{ $compound_oid };
        my( $compound_oid, $compound_name, $ext_acc, $modified_by, $batch_id) =
	    split( /\t/, $r );
        print "<tr class='img'>\n";

	my $ck;
	$ck = "checked" if $selected_cpd_oids_h{ $compound_oid };
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='compound_oid' value='$compound_oid' $ck />\n";
	print "</td>\n";

        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
	print "<td class='img'>" . alink( $url, $compound_oid ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $compound_name ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $ext_acc ) . "</td>\n";

	# print IMG reaction count for this compound
	if ( $rxnCount{$compound_oid} ) {
	    print "<td class='img'>" . "$rxnCount{$compound_oid}" . "</td>\n";
	}
	else {
	    print "<td class='img'>" . "0" . "</td>\n";
	}

	print "<td class='img'>" . escapeHTML( $batch_id ) . "</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";
}


############################################################################
# getImgRxnCount - get IMG reaction count per compound
############################################################################
sub getImgRxnCount {
    my ($dbh, @keys) = @_;

    my %h;

    my $max_id_num = 20;
    my $count = 0;
    my $keyList = "";

    for my $k ( @keys ) {
	if ( $count == 0 ) {
	    $keyList = "$k";
	}
	else {
	    $keyList .= ", $k";
	}

	$count++;

	if ( $count >= $max_id_num ) {
	        #exec SQL
	    my $sql = qq{
		select compound, count(rxn_oid)
		        from img_reaction_c_components
			    where compound in ( $keyList )
			        group by compound
			    };

	    my $cur = execSql( $dbh, $sql, $verbose );

	    for( ;; ) {
		my( $c_oid, $r_cnt ) = $cur->fetchrow( );
		last if !$c_oid;

		$c_oid = FuncUtil::compoundOidPadded( $c_oid ); 
		$h{ $c_oid } = $r_cnt;
	    }

	    $count = 0;
	    $keyList = "";
	}  # end else
    }  #end for k loop

    # last batch
    if ( $count > 0 && length($keyList) > 0 ) {
	my $sql = qq{
	        select compound, count(rxn_oid)
		    from img_reaction_c_components
		    where compound in ( $keyList )
		    group by compound
		};

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $c_oid, $r_cnt ) = $cur->fetchrow( );
	    last if !$c_oid;

	    $c_oid = FuncUtil::compoundOidPadded( $c_oid ); 
	    $h{ $c_oid } = $r_cnt;
	}
    }

    return %h;
}


############################################################################
# printSearchReactionForm - Show search reaction form 
############################################################################
sub printSearchReactionForm {

    print "<h1>Search IMG Reactions</h1>\n";
    
    printMainForm( );

    # need to record all selected genes
    my $icc = new ImgCpdCartStor( );
    my $recs = $icc->{ recs }; # get records
    my @compound_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @compound_oids ) == 0 ) {
	webError( "There are no compounds in the IMG Compound Cart." );
	return;
    }

    my @selected_cpd_oids = param( "compound_oid" );
    my %selected_cpd_oids_h;
    for my $compound_oid( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    # save gene selections in a hidden variable
    print "<input type='hidden' name='selectedCompounds' value='";
    for my $compound_oid ( @selected_cpd_oids ) {
	print "$compound_oid ";
    }
    print "'>\n";

    print "<p>\n";
    print "Enter Search Term.  Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchReaction' size='80' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchReactionResults";
    print submit( -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    print end_form( );
}


############################################################################
# printSearchReactionResults - Show results of reaction search.
############################################################################
sub printSearchReactionResults {

    print "<h1>Search IMG Reactions</h1>\n";
    
    printMainForm( );

    # keep previous compound selection in a hidden variable to pass to next screen
    my $selectedCompounds = param ( "selectedCompounds" );
    print hiddenVar( "selectedCompounds", $selectedCompounds );

    # get search term
    my $searchReaction = param( "searchReaction" );

    print "<p>\n";
    print "Enter Search Keyword.  Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchReaction' value='$searchReaction' size='80' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchReactionResults";
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

    my $name = "_section_${section}_cpdRxnAssignment";
    print submit( -name => $name,
       -value => "Associate Compounds to Reaction", -class => "lgdefbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_ImgCpdRxnAssocPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################
# printCpdRxnAssignment - This is the page handling final compound -
#                           reaction assignment.
############################################################################
sub printCpdRxnAssignment {
    print "<h1>Compound Reaction Assignment Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_dbUpdateCpdRxn";
    print submit( -name => $name,
		  -value => 'Assign IMG Reactions', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_ImgCpdRxnAssocPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    # get selected IMG reaction
    my $rxn_oid = param ( "rxn_oid" );
    print hiddenVar ( "rxnSelection", $rxn_oid);

    printStatusLine( "Loading ...", 1 );

    # get all compounds in compound cart
    my $icc = new ImgCpdCartStor( );
    my $recs = $icc->{ recs }; # get records

    my @compound_oids = sort{ $a <=> $b }keys( %$recs );

   # get selected compounds
    my $selectedCompounds = param ( "selectedCompounds" );
    my @selected_cpd_oids = split / /, $selectedCompounds;
    my %selected_cpd_oids_h;
    for my $compound_oid( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    # print selected count
    my $count = @selected_cpd_oids;
    print "<p>\n";
    print "$count compound(s) selected\n";
    print "</p>\n"; 

    my $dbh = dbLogin( );

    # get new IMG reaction
    my $sql = "select rxn_oid, rxn_name from img_reaction where rxn_oid=$rxn_oid";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $new_rxn = "";

    for( ;; ) {
	my ( $r_oid, $r_name ) = $cur->fetchrow( );
	last if !$r_oid;

	if ( $r_name ne "" ) {
	    $new_rxn = $r_name;
	}
	else {
	    $new_rxn = $rxn_oid;
	}
    }
    $cur->finish();

    #$dbh->disconnect();

    # add java script functions 'setLeftRight' and 'setStoMain'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setLeftRight( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^lr_/ ) ) {\n";
    print "              if ( x == 0 ) {\n";
    print "                 if ( e.value == 'left' ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "              if ( x == 1 ) {\n";
    print "                 if ( e.value == 'right' ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "function setStoMain( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^sm_/ ) ) {\n";
    print "              if ( x == 0 ) {\n";
    print "                 if ( e.value == 'Yes' ) {\n";
    print "                      e.checked = true;\n";
    print "                    }\n";
    print "                 }\n";
    print "              if ( x == 1 ) {\n";
    print "                 if ( e.value == 'No' ) {\n";
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
    print "<th class='img'>Compound OID</th>\n";
    print "<th class='img'>Compound Name</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";

    print "<th class='img'>Left/Right? <br/>\n";
    print "<input type='button' value='Left' Class='tinybutton'\n";
    print "  onClick='setLeftRight (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='Right' Class='tinybutton'\n";
    print "  onClick='setLeftRight (1)' />\n";
    print "</th>\n";

    print "<th class='img'>Main_Flag<br/>\n";
    print "<input type='button' value='Yes' Class='tinybutton'\n";
    print "  onClick='setStoMain (0)' />\n";
    print "<br/>\n";
    print "<input type='button' value='No' Class='tinybutton'\n";
    print "  onClick='setStoMain (1)' />\n";
    print "</th>\n";

    print "<th class='img'>Stoichiometry Value</th>\n";

    # only list selected compounds
    for my $compound_oid ( @selected_cpd_oids ) {
	my $r = $recs->{ $compound_oid };
        my( $cpd_oid, $cpd_name, $ext_acc, $modified_by, $batch_id) =
	    split( /\t/, $r );
        print "<tr class='img'>\n";

	my $ck = "checked" if $selected_cpd_oids_h{ $compound_oid };
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='compound_oid' value='$compound_oid' $ck/>\n";
	print "</td>\n";

        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
	print "<td class='img'>" . alink( $url, $compound_oid ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $cpd_name ) . "</td>\n";

	# print new IMG reaction
        $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$rxn_oid";
	print "<td class='img'>" . alink( $url, $rxn_oid ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $new_rxn ) . "</td>\n";

	# print Left/Right
	my $lr_name = "lr_" . $compound_oid;
	print "<td class='img' bgcolor='#eed0d0'>\n";
	print "  <input type='radio' name='$lr_name' value='left'/>Left\n";
	print "<br/>\n";
	print "  <input type='radio' name='$lr_name' value='right'/>Right\n";
	print "</td>\n";

	# print Main?
	my $sm_name = "sm_" . $compound_oid;
	print "<td class='img' bgcolor='#aaaabb'>\n";
	print "  <input type='radio' name='$sm_name' value='Yes'/>Yes\n";
	print "<br/>\n";
	print "  <input type='radio' name='$sm_name' value='No'/>No\n";
	print "</td>\n";

	# stoich value
	my $sv_name = "sv_" . $compound_oid;
	print "<td class='img'>" .
	    "<input type='text' name='$sv_name' size='3' maxLengh='3'/>" .
	    "</td>\n";

	print "</tr>\n";
    }
    print "</table>\n";

    print "<br/>\n";

    printStatusLine( "Loaded.", 2 );

    print end_form( );
}


############################################################################
# dbUpdateCpdRxn - update compound-reaction in the database
############################################################################
sub dbUpdateCpdRxn() {
   # get the compound oids
    my $icc = new ImgCpdCartStor( );
    my $recs = $icc->{ recs }; # get records

    my @compound_oids = sort{ $a <=> $b }keys( %$recs );
    my @selected_cpd_oids = param( "compound_oid" );
    my %selected_cpd_oids_h;
    for my $compound_oid( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    my $rxn_oid = param ( "rxnSelection" );

    # check stoich value
    for my $compound_oid ( @selected_cpd_oids ) {
	# my $sm = param ("sm_" . $compound_oid);
	my $sv = param ("sv_" . $compound_oid);
	if ( !blankStr($sv) && !isInt($sv) ) {
	    webError( "Stoich value '" . escapeHTML($sv) . "' is not an integer." );
	    return 0;
	}
    }

    # prepare SQL
    my @sqlList = ();
    my $sql = "";
    my $ins = "";
    my $vals = "";

    for my $compound_oid ( @selected_cpd_oids ) {
	# insert
	$ins = "insert into IMG_REACTION_C_COMPONENTS (rxn_oid, compound";
	$vals = " values ($rxn_oid, $compound_oid";
	    
	# left/right
	my $lr = param ("lr_" . $compound_oid);
	if ( $lr eq 'left' ) {
	    $ins .= ", c_type";
	    $vals .= ", 'LHS'";
	}
	elsif ( $lr eq 'right' ) {
	    $ins .= ", c_type";
	    $vals .= ", 'RHS'";
	}

	# stoichiometry/main
	my $sm = param ("sm_" . $compound_oid);
	if ( $sm eq 'No' ) {
	    $ins .= ", main_flag";
	    $vals .= ", 'No'";
	}
	elsif ( $sm eq 'Yes' ) {
	    $ins .= ", main_flag";
	    $vals .= ", 'Yes'";
	}

	my $sv = param ("sv_" . $compound_oid);
	if ( ! blankStr($sv) && isInt($sv) ) {
	    $ins .= ", stoich";
	    $vals .= ", $sv";
	}

	$ins .= ")";
	$vals .= ")";

	$sql = $ins . $vals;
	push @sqlList, ($sql);
    }

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return 0;
   }
    else {
	return 1;
    }
}


############################################################################
# printConfirmDeleteCompoundReactions - ask for user confirmation 
#                        before deleting compound-reaction links
############################################################################
sub printConfirmDeleteCompoundReactions {
    print "<h1>Delete Related IMG Reactions for Selected Compounds</h1>\n";
    printMainForm( );

    print "<p>The selected compound-reaction associations will be deleted.</p>\n";

    print "<p>\n"; # paragraph section puts text in proper font.

    # get compound cart
    my $icc = new ImgCpdCartStor( );
    my $recs = $icc->{ recs }; # get records

    my @compound_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @compound_oids ) == 0 ) {
	webError( "There are no compounds in the IMG Compound Cart." );
	return;
    }

    my @selected_cpd_oids = param( "compound_oid" );
    my %selected_cpd_oids_h;
    for my $compound_oid ( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    # check whether there are any selections
    if ( scalar( @selected_cpd_oids ) == 0 ) {
	webError( "No compounds have been selected." );
	return;
    }

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_dbDeleteCpdRxn";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_ImgCpdRxnAssocPage";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Compound OID</th>\n";
    print "<th class='img'>Compound Name</th>\n";
    print "<th class='img'>Reaction OID</th>\n";
    print "<th class='img'>Reaction Name</th>\n";
    print "<th class='img'>Type</th>\n";

    my $dbh = dbLogin( );

    # get IMG reactions for all compounds
    # my %cpdRxns = getCpdRxns($dbh, @selected_cpd_oids);

    for my $compound_oid ( @selected_cpd_oids ) {
	my $r = $recs->{ $compound_oid };
        my( $compound_oid, $compound_name, $ext_acc, $modified_by,
	    $batch_id ) = split( /\t/, $r );

	my $sql = qq{
	    select ir.rxn_oid, ir.rxn_name, ircc.c_type
		from img_reaction_c_components ircc, img_reaction ir
		where ircc.compound = $compound_oid
		and ircc.rxn_oid = ir.rxn_oid
		order by ir.rxn_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );
	my $compound_oid = FuncUtil::compoundOidPadded($compound_oid);

	for( ;; ) {
	    my( $r_oid, $r_name, $c_type ) = $cur->fetchrow( );
	    last if !$r_oid;

	    # print compound
	    print "<tr class='img'>\n";

	    my $ck = "checked" if $selected_cpd_oids_h{ $compound_oid };
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='cpd_rxn_oid' value='$compound_oid|$r_oid' $ck />\n";
	    print "</td>\n";

	    my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
	    print "<td class='img'>" . alink( $url, $compound_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $compound_name ) . "</td>\n";

	    # print reaction
	    $r_oid = FuncUtil::rxnOidPadded($r_oid);
	    my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 
	    print "<td class='img'>" . alink( $url, $r_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $r_name ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $c_type ) . "</td>\n";

	    print "</tr>\n";
	}  # end for looppwd
	
    }
    print "</table>\n";
    print "<br/>\n";

    #$dbh->disconnect();

    print end_form( );
}


############################################################################
# dbDeleteCpdRxn - delete compound-reaction in the database
############################################################################
sub dbDeleteCpdRxn() {
   # get the compound oids
    my $icc = new ImgCpdCartStor( );
    my $recs = $icc->{ recs }; # get records

    my @compound_oids = sort{ $a <=> $b }keys( %$recs );
    my @cpd_rxn_oids = param( "cpd_rxn_oid" );
    my @selected_cpd_oids;
    for my $ids ( @cpd_rxn_oids ) {
	my ($c_oid, $r_oid) = split(/\|/, $ids);
	push @selected_cpd_oids, ( $c_oid);
    }
    my %selected_cpd_oids_h;
    for my $compound_oid( @selected_cpd_oids ) {
	$selected_cpd_oids_h{ $compound_oid } = 1;
    }

    # prepare SQL
    my @sqlList = ();
    my $sql = "";

    for my $ids ( @cpd_rxn_oids ) {
	my ($c_oid, $r_oid) = split(/\|/, $ids);

	$sql = "delete from IMG_REACTION_C_COMPONENTS " .
	    "where compound = $c_oid and rxn_oid = $r_oid";
	push @sqlList, ($sql);
    }

    # perform database update
    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
	$sql = $sqlList[$err-1];
	webError ("SQL Error: $sql");
	return 0;
   }
    else {
	return 1;
    }
}


############################################################################
# checkKeggCompounds - check whether inputs are all KEGG compounds
############################################################################
sub checkKeggCompounds {
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
# getCpdRxns - get IMG reactions for each compound
############################################################################
sub getCpdRxns {
    my ($dbh, @keys) = @_;

    my %h;

    my $max_id_num = 20;
    my $count = 0;
    my $keyList = "";

    for my $k ( @keys ) {
	if ( $count == 0 ) {
	    $keyList = "$k";
	}
	else {
	    $keyList .= ", $k";
	}

	$count++;

	if ( $count >= $max_id_num ) {
	        #exec SQL
	    my $sql = qq{
		select ircc.compound, ir.rxn_oid, ir.rxn_name, ircc.c_type
		        from img_reaction_c_components ircc, img_reaction ir
			    where ircc.compound in ( $keyList )
                    and ircc.rxn_oid = ir.rxn_oid
		        order by ircc.compound
		    };

	    my $cur = execSql( $dbh, $sql, $verbose );

	    my $prev_id = -1;

	    for( ;; ) {
		my( $c_oid, $r_oid, $r_name, $c_type ) = $cur->fetchrow( );
		last if !$c_oid;

		$c_oid = FuncUtil::compoundOidPadded($c_oid);
		$r_oid = FuncUtil::rxnOidPadded($r_oid);

		my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 

		my $rxn = alink( $url, $r_oid ) . " (" . escHtml($r_name) .
		    ") - " . escHtml( $c_type ) . "<br/>\n";

		if ( $prev_id == $c_oid ) {
		        # the same compound. append
		    $h{ $c_oid } .= $rxn;
		}
		else {
		        # a new compound
		    $h{ $c_oid } = $rxn;
		}

		$prev_id = $c_oid;
	    }

	    $count = 0;
	    $keyList = "";
	}  # end else
    }  #end for k loop

    # last batch
    if ( $count > 0 && length($keyList) > 0 ) {
	my $sql = qq{
		select ircc.compound, ir.rxn_oid, ir.rxn_name, ircc.c_type
		        from img_reaction_c_components ircc, img_reaction ir
			    where ircc.compound in ( $keyList )
                    and ircc.rxn_oid = ir.rxn_oid
		        order by ircc.compound
		};

	my $cur = execSql( $dbh, $sql, $verbose );

	my $prev_id = -1;

	for( ;; ) {
	    my( $c_oid, $r_oid, $r_name, $c_type ) = $cur->fetchrow( );
	    last if !$c_oid;

	    $c_oid = FuncUtil::compoundOidPadded($c_oid);
	    $r_oid = FuncUtil::rxnOidPadded($r_oid);

	    my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$r_oid"; 

	    my $rxn = alink( $url, $r_oid ) . " (" . escHtml($r_name) .
		") - " . escHtml( $c_type ) . "<br/>\n";

	    if ( $prev_id == $c_oid ) {
		# the same compound. append
		$h{ $c_oid } .= $rxn;
	    }
	    else {
		# a new compound
		$h{ $c_oid } = $rxn;
	    }

	    $prev_id = $c_oid;
	}
    }

    return %h;
}


1;
