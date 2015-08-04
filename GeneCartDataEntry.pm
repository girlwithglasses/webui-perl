###########################################################################
# GeneCartDataEntry.pm - Data entry through GeneCart entry point.
#   imachen 01/03/2007
# 
# Notes to Amy on developing on durian:
#   1.  You can view messages, e.g. for debugging, 
#       by openeing a window on durian, and doing
#           % tail -f /var/log/apache/error.log
#       If you 
#           print STDERR "my debugging/error statement\n"
#       in Perl, you can see messages there.
#   2.  Similarly you can use the webLog( "..." ) function
#       to view application log entries in the file specified
#       by WebConfig.pm: $e->{ web_log_file }.
#
############################################################################
package GeneCartDataEntry;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use GeneCartStor;
use ImgTermCartStor;
use DataEntryUtil;
use FuncUtil;


my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };
my $img_lite = $env->{ img_lite };

my $section = "GeneCartDataEntry";
my $section_cgi = "$main_cgi?section=$section";

my $contact_oid = getContactOid( );

my $max_item_count = 200;    # limit the number of returned IMG terms
my $max_upload_line_count = 10000;    # limit the number of lines in file upload

my $max_cond_count = 5;
my $max_set_cond_count = 3;


############################################################################
# dispatch - Dispatch to pages for this section.
############################################################################
sub dispatch {

    ## Should not get here.
    my $section = param( "section" );
    if( $section ne "GeneCartDataEntry" ) {
        webDie( "GeneCartDataEntry::dispatch: bad section '$section'\n" );
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
       elsif( paramMatch( "searchTermForm" ) ne "" ) {
           $page = "searchTermForm";
       }
       elsif( paramMatch( "searchTermResults" ) ne "" ) {
           $page = "searchTermResults";
       }
       elsif( paramMatch( "geneTermAssignment" ) ne "" ) {
           $page = "geneTermAssignment";
       }
       elsif( paramMatch( "dbUpdateGeneTerms" ) ne "" ) {
           dbUpdateGeneTerms();

    	   # update Gene Product Name
    	   my $gc = new GeneCartStor( );
    	   $gc->webAddGenes();
    
    	   # return to the index page
    	   $page = "index";
       }
       elsif( paramMatch( "deleteGeneTerms" ) ne "" ) {
           $page = "deleteGeneTerms";
       }
       elsif( paramMatch( "dbDeleteGeneTerms" ) ne "" ) {
           dbDeleteGeneTerms ();

    	   # update Gene Product Name
    	   my $gc = new GeneCartStor( );
    	   $gc->webAddGenes();
    
    	   # return to the index page
    	   $page = "index";
       }
       elsif( paramMatch( "fileUpload" ) ne "" ) {
           $page = "fileUpload";
       }
       elsif( paramMatch( "validateFile" ) ne "" ) {
           $page = "validateFile";
       }
       elsif( paramMatch( "dbFileUpload" ) ne "" ) {
           dbFileUpload();

    	   # return to the index page
    	   $page = "index";
       }
       elsif( paramMatch( "UpdDelGeneTerms" ) ne "" ) {
    	   $page = "batchCuration";
       }
       elsif( paramMatch( "batchCuration" ) ne "" ) {
           $page = "batchCuration";
       }
       elsif( paramMatch( "confirmGeneTermUpdate" ) ne "" ) {
    	   $page = "confirmGeneTermUpdate";
       }
       elsif( paramMatch( "dbBatchUpdate" ) ne "" ) {
    	   dbBatchUpdate();
    
    	   # update Gene Product Name
    	   my $gc = new GeneCartStor( );
    	   $gc->webAddGenes();
    
    	   $page = "index";
       }
       elsif( paramMatch( "advGeneSearch" ) ne "" ) {
    	   $page = "advGeneSearch";
       }
       elsif( paramMatch( "geneQueryResult" ) ne "" ) {
    	   $page = "geneQueryResult";
       }
       elsif( paramMatch( "addToGeneCart" ) ne "" ) {
    	   # add to cart
    	   my $gc = new GeneCartStor( );
    	   $gc->webAddGenes();
    
    	   $page = "index";
       }
       elsif( paramMatch( "inferTerm" ) ne "" ) {
    	   $page = "inferTerm";
       }
       elsif( paramMatch( "addInferredTerm" ) ne "" ) {
    	   $page = "confirmAddInfer";
       } 
       elsif( paramMatch( "replaceInferredTerm" ) ne "" ) {
    	   $page = "confirmReplaceInfer";
       }
       elsif( paramMatch( "dbAddInferredTerm" ) ne "" ) {
    	   my $to_update = param('to_update');
    	   dbAddInferredTerms($to_update);
    
    	   $page = "index";
       } 
   }
    webLog( "Dispatch to page '$page'\n" );

    # --es 09/30/2006 Save the error log only when needed now.
    #print STDERR "Dispatch to page '$page'\n";

    if( $page eq "index" ) {
        printIndex( );
    }
    elsif( $page eq "cartGenes" ) {
        printCartGenes( );
    }
    elsif( $page eq "searchTermForm" ) {
        printSearchTermForm( );
    }
    elsif( $page eq "searchTermResults" ) {
        printSearchTermResults( );
    }
    elsif( $page eq "insertTermForm" ) {
        printInsertTermForm( );
    }
    elsif( $page eq "insertTermResults" ) {
        printInsertTermResults( );
    }
    elsif( $page eq "geneTermAssignment" ) {
        printGeneTermAssignment( );
    }
    elsif( $page eq "deleteGeneTerms" ) {
        printDeleteGeneTerms( );
    }
    elsif( $page eq "fileUpload" ) {
        printUploadFlatFileForm( );
    }
    elsif( $page eq "validateFile" ) {
    	printValidationResultForm();
    }
    elsif( $page eq "batchCuration" ) {
    	printEditGeneTerms ( );
    }
    elsif( $page eq "confirmGeneTermUpdate" ) {
    	printConfirmGeneTermUpdateForm();
    }
    elsif( $page eq "advGeneSearch" ) {
    	printAdvancedGeneSearchForm ( );
    }
    elsif( $page eq "geneQueryResult" ) {
    	printGeneQueryResultForm ( );
    }
    elsif( $page eq "inferTerm" ) {
    	printInferTermResultForm ( );
    }
    elsif( $page eq "confirmAddInfer" ) {
    	printConfirmAddUpdateInfer(0);
    }
    elsif( $page eq "confirmReplaceInfer" ) {
    	printConfirmAddUpdateInfer(1);
    }
    else {
        # printIndex( );
    	print "<h1>Incorrect Page: $page</h1>\n";
    }
}


############################################################################
# printIndex - This is the main Gene Cart Data Entry page
############################################################################
sub printIndex {
    print "<h1>Gene Curation Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    # my $url = "$main_cgi?section=$section&page=cartGenes";
    # print alink( $url, "Genes in Gene Cart" ) . "<br/>\n";

    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print "</p>\n";

    # list all genes
    printCartGenes();
    print "<br/>\n";

    # IMG term
    print "<h2>Curate IMG Term for the Selected Gene(s)</h2>\n";

    #my $url = "$main_cgi?section=$section&page=searchTermForm";
    #print alink( $url, "Search Terms" ) . "<br/>\n";
    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchTermForm";
    print submit( -name => $name,
		  -value => 'Add IMG Term', -class => 'smdefbutton' );
#    print nbsp( 1 );
#    my $name = "_section_${section}_deleteGeneTerms";
#    print submit( -name => $name,
#		  -value => 'Delete IMG Term(s)', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_UpdDelGeneTerms";
    print submit( -name => $name,
		  -value => 'Update/Delete IMG Term(s)', -class => 'medbutton' );

    print "</p>\n";

    # file upload
    if ( isImgEditorWrap() ) {
    	print "<h2>Upload Gene - IMG Term Associations from a File</h2>\n";
    
    	print "<p>\n";
    	my $name = "_section_${section}_fileUpload";
    	print submit( -name => $name,
    		      -value => 'File Upload', -class => 'smbutton' );
    	print "</p>\n";
    }

    # search similarity
    print "<h2>Gene Similarity Search</h2>\n";

    print "<p>Use gene-term information of ";
    if ( ! $img_lite ) {
    	print "ortholog or ";
    }
    print "homolog genes to infer terms for the selected gene. <b>Note that only the first selected gene is applied.</b>\n";

    print "<p>\n";
    if ( ! $img_lite ) {
    	my $name = "_section_${section}_inferTerm";
    	print submit( -name => $name,
    		      -value => 'Search Ortholog Genes', -class => 'medbutton' );
    	print nbsp( 1 );
    }
    my $name = "_section_MissingGenes_similarity";
    print submit( -name => $name,
		      -value => 'Search Homolog Genes', -class => 'medbutton' );
    print "</p>\n";

    # gene-term curation
    if ( isImgEditorWrap() ) {
    	print "<h2>Search Genes for Gene - Term Curation</h2>\n";
    
    	print "<p>Use advanced search function to find genes for gene-term curation.</p>\n";
    
    	print "<p>\n";
    	my $name = "_section_${section}_advGeneSearch";
    	print submit( -name => $name,
    		      -value => 'Search', -class => 'smbutton' );
    	print "</p>\n";
    }

    print end_form( );
}


############################################################################
# printCartGenes - Show genes in gene cart.
############################################################################
sub printCartGenes {

    my $gc = new GeneCartStor( );

    my $recs = $gc->readCartFile(); # get records
    #my @gene_oids = sort{ $a <=> $b }keys( %$recs );
    # The keys for the records are gene_oids.
	# But we want them sorted.
	my @db_gene_oids = $gc->getDbGeneOids();
    my @gene_oids = sort { $a <=> $b } @db_gene_oids;

    ## --es 09/30/2006 Retrieve selections from previous form's
    #    checkboxes having the name 'gene_oid', of which there are many,
    #    hence, an array.  We make a hash for easy lookup for selection.
    my @selected_gene_oids = param( "gene_oid" );
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
    }

    # print count
    my $count = scalar( @gene_oids );
    print "<p>\n";
    print "$count database gene(s) in cart\n";
    print "</p>\n"; 

    #temp block none-database genes
    if ( $count == 0 ) {
        webError("There are no database genes in the cart.");
    }

    my $dbh = dbLogin( );

    # get IMG term count for all gene oids
    my %termCount = getImgTermCount($dbh, @gene_oids);

    # get COG data for all gene oids
    my %cogData = getCOG($dbh, @gene_oids);

    # get Pfam data for all gene oids
    my %pfamData = getPfam($dbh, @gene_oids);

    # get TIGRfam data for all gene oids
    my %tigrfamData = getTIGRfam($dbh, @gene_oids);

    ##$dbh->disconnect();

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Product Name</th>\n";
    print "<th class='img'>IMG Term Count</th>\n";
    print "<th class='img'>Genome</th>\n";
    print "<th class='img'>COG</th>\n";
    print "<th class='img'>Pfam</th>\n";
    print "<th class='img'>TIGRfam</th>\n";
    print "<th class='img'>Batch</th>\n";
    for my $gene_oid ( @gene_oids ) {
    	my $r = $recs->{ $gene_oid };
        my( $gene_oid, $locus_tag, $desc, $desc_orig, 
	       $taxon_oid, $taxon_display_name, $batch_id, $scaffold_oid, 
	       @outColVals ) = split( /\t/, $r );

        print "<tr class='img'>\n";
    
    	## --es 09/30/2006 add checkbox and illustration 
    	#   for selected genes from cart.  Previous selections
    	#   are checked.
    	my $ck;
    	$ck = "checked" if $selected_gene_oids_h{ $gene_oid };
    	print "<td class='checkbox'>\n";
    	print "<input type='checkbox' ";
    	print "name='gene_oid' value='$gene_oid' $ck />\n";
    	print "</td>\n";
    
    	my $url = "$main_cgi?section=GeneDetail" . 
    	   "&page=geneDetail&gene_oid=$gene_oid";
    	print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
    	print "<td class='img'>" . escapeHTML( $desc ) . "</td>\n";
    
    	# print IMG term count for this gene
    	if ( $termCount{$gene_oid} ) {
    	    print "<td class='img'>" . "$termCount{$gene_oid}" . "</td>\n";
    	}
    	else {
    	    print "<td class='img'>" . "0" . "</td>\n";
    	}
    
    	print "<td class='img'>" . 
    	    escapeHTML( $taxon_display_name ) . "</td>\n";
    
    	# print COG info
    	if ( $cogData{$gene_oid} ) {
    	    print "<td class='img'>" . escapeHTML($cogData{$gene_oid}) .
    		"</td>\n";
    	}
    	else {
    	    print "<td class='img'>" . "" . "</td>\n";
    	}
    
    	# print Pfam info
    	if ( $pfamData{$gene_oid} ) {
    	    print "<td class='img'>" . escapeHTML($pfamData{$gene_oid}) .
    		"</td>\n";
    	}
    	else {
    	    print "<td class='img'>" . "" . "</td>\n";
    	}
    
    	# print TIGRfam info
    	if ( $tigrfamData{$gene_oid} ) {
    	    print "<td class='img'>" . escapeHTML($tigrfamData{$gene_oid}) .
    		"</td>\n";
    	}
    	else {
    	    print "<td class='img'>" . "" . "</td>\n";
    	}
    
    	print "<td class='img'>" . escapeHTML( $batch_id ) . "</td>\n";
    	print "</tr>\n";
    }
    print "</table>\n";
}


############################################################################
# printSearchTermForm - Show search term form 
############################################################################
sub printSearchTermForm {

    print "<h1>Search IMG Terms (and their synonyms)</h1>\n";
    
    printMainForm( );

    # need to record all selected genes
    my $gc = new GeneCartStor( );
    my $recs = $gc->readCartFile(); # get records
    my @gene_oids = sort{ $a <=> $b }keys( %$recs );

    # check whether the cart is empty
    if ( scalar( @gene_oids ) == 0 ) {
    	webError( "There are no genes in the Gene Cart." );
    	return;
    }

    my @selected_gene_oids = param( "gene_oid" );
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
    }

    # save gene selections in a hidden variable
    print "<input type='hidden' name='selectedGenes' value='";
    for my $gene_oid ( @selected_gene_oids ) {
    	print "$gene_oid ";
    }
    print "'>\n";

    print "<p>\n";
    print "Enter Search Term.  Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchTerm' size='80' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_searchTermResults";
    print submit( -name => $name,
       -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 ); 
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    print end_form( );
}

############################################################################
# printSearchTermResults - Show results of term search.
############################################################################
sub printSearchTermResults {

    print "<h1>Search IMG Terms (and their synonyms)</h1>\n";
    
    printMainForm( );

    # keep previous gene selection in a hidden variable to pass to next screen
    my $selectedGenes = param ( "selectedGenes" );
    print hiddenVar( "selectedGenes", $selectedGenes );

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
    my %imgTerms = searchIMGTermSynonym ($dbh, $searchTermLc, $max_item_count);

    my $count = 0;
    for my $k ( keys %imgTerms ) {
         $count++;
    }

    if ( $count == 0 ) {
        #$dbh->disconnect( );
        printStatusLine( "$count term(s) found.", 2 );
        webError( "No IMG terms matches the keyword." );
        return;
    }

    # retrieve all synonyms
    my @keys = keys( %imgTerms );
    my %imgSynonyms = getSynonyms ($dbh, @keys);

    ##$dbh->disconnect();

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
    if ( $count < $max_item_count ) {
        printStatusLine( "$count term(s) found.", 2 );
    }
    else {
        printStatusLine( "Only $count terms displayed.", 2 );
    }

    ## Set parameters.
    # print hiddenVar( "section", $section );

    # show button
    print "<br/><br/>\n";
    my $name = "_section_${section}_geneTermAssignment";
    print submit( -name => $name,
       -value => "Add Selected Genes to Selected IMG Term", -class => "lgdefbutton" );
    print "\n";

    for my $key ( keys %imgSynonyms ) {
        my $s = $imgSynonyms{$key};

#        print "<input type=\"hidden\" id=\"$key\" value=\"$s\">\n";

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
#    print "<textarea id='synonyms' name='synonyms' " .
#          "rows='6' cols='80' readonly></textarea>\n";
    print "<div id='synonyms' name='synonyms' " .
          "style='background-color: #eee; overflow: scroll; " .
          "width: 560px; height:160px'></div>\n";

    # add java script function 'showSynonym'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function showSynonyms() {\n";
    print "   var termOid = document.mainForm.termSelection.value;\n";

#    print "   document.getElementById('synonyms').value = \"\";\n";
#    print "   document.getElementById('synonyms').value = document.getElementById(termOid).value;\n";

    print "   document.getElementById('synonyms').innerHTML = \"\";\n";
    print "   document.getElementById('synonyms').innerHTML = document.getElementById(termOid).value;\n";

    print "   }\n";
    print "\n</script>\n\n";

    print end_form();
}


############################################################################
# printGeneTermAssignment - This is the page handling final gene - term
#                           assignment.
############################################################################
sub printGeneTermAssignment {
    print "<h1>Gene Term Assignment Page</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_dbUpdateGeneTerms";
    print submit( -name => $name,
       -value => 'Assign IMG Terms', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
       -value => 'Cancel', -class => 'smbutton' );
    print "</p>\n";

    # get selected IMG term
    my $term_oid = param ( "termSelection" );
    print hiddenVar ( "termSelection", $term_oid);

    printStatusLine( "Loading ...", 1 );

    # get all genes in the gene cart
    my $gc = new GeneCartStor( );
    my $recs = $gc->readCartFile(); # get records

    my @gene_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are gene_oids.
	# But we want them sorted.

    # get selected genes
    my $selectedGenes = param ( "selectedGenes" );
    my @selected_gene_oids = split(/ /, $selectedGenes);
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
    }

    # print selected count
    my $count = @selected_gene_oids;
    print "<p>\n";
    print "$count gene(s) selected\n";
    print "</p>\n"; 

    my $dbh = dbLogin( );

    # get new IMG term
    my $new_term = getImgTerm($dbh, $term_oid);

    # get IMG terms for all gene oids
    my %geneTerms = getGeneImgTerms($dbh, @selected_gene_oids); # @gene_oids);

    # get all cell_loc values
    my @cell_locs = ( ' ' ) ;
    my $sql2 = "select loc_type from CELL_LOCALIZATION order by loc_type";
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for( ;; ) {
	my( $c_loc ) = $cur2->fetchrow( );
	last if !$c_loc;

	push @cell_locs, ( $c_loc );
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
    print "<th class='img'>Product Name</th>\n";
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

    # only list selected genes
    for my $gene_oid ( @selected_gene_oids ) {
	my $r = $recs->{ $gene_oid };
        my( $gene_oid, $locus_tag, $desc, $desc_orig, 
           $taxon_oid, $taxon_display_name, $batch_id, $scaffold_oid,
	       @outColVals ) = split( /\t/, $r );
        print "<tr class='img'>\n";

	my $ck = "checked" if $selected_gene_oids_h{ $gene_oid };
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='gene_oid' value='$gene_oid' $ck/>\n";
	print "</td>\n";

	my $url = "$main_cgi?section=GeneDetail" . 
	   "&page=geneDetail&gene_oid=$gene_oid";
	print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
	print "<td class='img'>" . escapeHTML( $desc ) . "</td>\n";
	print "<td class='img'>" . 
	    escapeHTML( $taxon_display_name ) . "</td>\n";

	# print old IMG terms
	my $ar = 0;
	if ( $geneTerms{$gene_oid} ) {
	    print "<td class='img'>" . "$geneTerms{$gene_oid}" . "</td>\n";

	    # check whether the same term already exist
	    if ( db_findCount($dbh, 'GENE_IMG_FUNCTIONS',
		      "gene_oid = $gene_oid and function = $term_oid") > 0 ) {
		$ar = 1;
	    }
	}
	else {
	    print "<td class='img'>" . "" . "</td>\n";
	    $ar = 2;   # no old term. disable the Replace button below
	}

	# print new IMG term
	print "<td class='img'>" . escapeHTML( $new_term ) . "</td>\n";

	# print Add?/Replace?
	my $ar_name = "ar_" . $gene_oid;
	print "<td class='img' bgcolor='#eed0d0'>\n";
	if ( $ar == 1 ) {
	    # replace only
	    print "  <input type='radio' name='$ar_name' value='add' disabled />Add\n";
	    print "<br/>\n";
	    print "  <input type='radio' name='$ar_name' value='replace' checked />Replace\n";
	}
	elsif ( $ar == 2 ) {
	    # add only
	    print "  <input type='radio' name='$ar_name' value='add' checked />Add\n";
	    print "<br/>\n";
	    print "  <input type='radio' name='$ar_name' value='replace' disabled />Replace\n";
	}
	else {
	    # both
	    print "  <input type='radio' name='$ar_name' value='add' checked />Add\n";
	    print "<br/>\n";
	    print "  <input type='radio' name='$ar_name' value='replace' />Replace\n";
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
	print "  <input type='text' name='$cm_name' size='20' maxLength='255'/>\n";
	print "</td>\n";

	# cell_loc
	my $cl_name = "cell_" . $gene_oid;
	print "<td class='img'>\n";
	print "  <select name='$cl_name' id='$cl_name' class='img' size='1'>\n";
	for my $c2 ( @cell_locs ) {
	    print "    <option value='$c2' />$c2</option>\n";
	}
	print "  </select>\n";
	print "</td>\n";

	print "</tr>\n";
    }
    print "</table>\n";

    print "<br/>\n";

    printStatusLine( "Loaded.", 2 );

    ##$dbh->disconnect();

    print end_form( );
}

############################################################################
# printDeleteGeneTerms - ask for user confirmation before deleting
#                        gene term links
############################################################################
sub printDeleteGeneTerms {
    print "<h1>Delete Related IMG Terms for Genes</h1>\n";
    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    # get gene cart
    my $gc = new GeneCartStor( );
    my $recs = $gc->readCartFile(); # get records

    my @gene_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are gene_oids.
	# But we want them sorted.

    # check whether the cart is empty
    if ( scalar( @gene_oids ) == 0 ) {
	webError( "There are no genes in the Gene Cart." );
	return;
    }

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_dbDeleteGeneTerms";
    print submit( -name => $name,
       -value => 'Delete', -class => 'smdefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
       -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    # list all selected genes and associated IMG terms
    ## --es 09/30/2006 Retrieve selections from previous form's
    #    checkboxes having the name 'gene_oid', of which there are many,
    #    hence, an array.  We make a hash for easy lookup for selection.
    my @selected_gene_oids = param( "gene_oid" );
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
       print hiddenVar( "gene_oid", $gene_oid );
    }

    my $dbh = dbLogin( );

    # get IMG terms for all gene oids
#    my %geneTerms = getGeneImgTerms($dbh, @selected_gene_oids);

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Product Name</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>IMG Term</th>\n";

    for my $gene_oid ( @selected_gene_oids ) {
	my $r = $recs->{ $gene_oid };
        my( $gene_oid, $locus_tag, $desc, $desc_orig, 
           $taxon_oid, $taxon_display_name, $batch_id, $scaffold_oid,
	       @outColVals ) = split( /\t/, $r );
        print "<tr class='img'>\n";

	# get all terms associated with this gene
	my $sql = qq{
	    select g.gene_oid, g.function, t.term
		from gene_img_functions g, img_term t
		where g.gene_oid = $gene_oid
		and g.function = t.term_oid
	};

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $g_oid, $term_oid, $term ) = $cur->fetchrow( );
	    last if !$g_oid;
	    $term_oid = FuncUtil::termOidPadded( $term_oid );

	    my $ck = "checked" if $selected_gene_oids_h{ $gene_oid }; # && $geneTerms{$gene_oid};
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='gene_term' value='$gene_oid|$term_oid' $ck />\n";
	    print "</td>\n";

	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $desc ) . "</td>\n";

	    # print IMG terms for this gene
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	    print "</tr>\n";
	}
	$cur->finish();
    }
    print "</table>\n";
    print "<br/>\n";

    ##$dbh->disconnect();

    print end_form( );
}


############################################################################
# printEditGeneTerms - for editing gene - term associations
#                        gene term links
############################################################################
sub printEditGeneTerms {
    print "<h1>Update/Delete Gene - Term Associations</h1>\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    # get gene cart
    my $gc = new GeneCartStor( );
    my $recs = $gc->readCartFile(); # get records

    my @gene_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are gene_oids.
	# But we want them sorted.

    # check whether the cart is empty
    if ( scalar( @gene_oids ) == 0 ) {
	webError( "There are no genes in the Gene Cart." );
	return;
    }

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_confirmGeneTermUpdate";
    print submit( -name => $name,
       -value => 'Update Database', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
       -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    # list all selected genes and associated IMG terms
    ## --es 09/30/2006 Retrieve selections from previous form's
    #    checkboxes having the name 'gene_oid', of which there are many,
    #    hence, an array.  We make a hash for easy lookup for selection.
    my @selected_gene_oids = param( "gene_oid" );
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
       print hiddenVar( "gene_oid", $gene_oid );
    }

    my $dbh = dbLogin( );

    # get IMG terms for all gene oids
#    my %geneTerms = getGeneImgTerms($dbh, @selected_gene_oids);

    # select all cell_loc values from database
    my @cell_locs = ( ' ' );
    my $sql2 = "select loc_type from CELL_LOCALIZATION order by loc_type";
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for( ;; ) {
	my( $c_loc ) = $cur2->fetchrow( );
	last if !$c_loc;

	push @cell_locs, ( $c_loc );
    }
    $cur2->finish();

    # add java script functions 'setEditSelect'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setEditSelect ( x ) {\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^op/ ) && e.length == 3 ) {\n";
    print "              if ( x == 'NoChange' ) {\n";
    print "                   e.selectedIndex = 0;\n";
    print "                 }\n";
    print "              if ( x == 'Update' ) {\n";
    print "                   e.selectedIndex = 1;\n";
    print "                 }\n";
    print "              if ( x == 'Delete' ) {\n";
    print "                   e.selectedIndex = 2;\n";
    print "                 }\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    # add java script functions 'setFflagSelect'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setFflagSelect ( x ) {\n";
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

    # add java script functions 'setCellLocSelect'
    print "\n<script language=\"javascript\" type=\"text/javascript\">\n\n";
    print "function setCellLocSelect ( ) {\n";
    print "   var allc = document.getElementById('allCellLoc');\n";
    print "   var f = document.mainForm;\n";
    print "   for ( var i = 0; i < f.length; i++ ) {\n";
    print "         var e = f.elements[ i ];\n";
    print "         if ( e.name.match( /^cell/ ) ) {\n";
    print "              e.selectedIndex = allc.selectedIndex;\n";
    print "            }\n";
    print "         }\n";
    print "   }\n";
    print "\n</script>\n\n";

    ### Print the records out in a table.
    print "<table class='img'>\n";
#    print "<th class='img'>Select</th>\n";

    print "<th class='img' width='3'>Update_Record?<br/>\n";

    for my $t ( 'NoChange', 'Update', 'Delete' ) {
	print "<input type='button' value='$t' Class='tinybutton'\n";
	print "  onClick='setEditSelect (\"$t\")' />\n";
	print "<br/>\n";
    }
    print "</th>\n";

    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Product Name</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>IMG Term</th>\n";

    print "<th class='img'>Term_Flag <br/>";
    for my $t ( 'M', 'C', 'P' ) {
	print "<input type='button' value='$t' Class='tinybutton'\n";
	print "  onClick='setFflagSelect (\"$t\")' />\n";
	print "<br/>\n";
    }
    print "</th>\n";

    print "<th class='img'>F_Order</th>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Confidence</th>\n";
    print "<th class='img'>Cell Localization";
    print "  <select id='allCellLoc' name='allCellLoc' class='img' size='1'>\n";
    for my $c0 ( @cell_locs ) {
	print "    <option value='$c0' />$c0</option>\n";
    }
    print "  </select>\n";
    print "<br/><input type='button' value='Set' Class='tinybutton'\n";
    print "  onClick='setCellLocSelect ()' />\n";
    print "<br/>\n";
    print "</th>\n";

    for my $gene_oid ( @selected_gene_oids ) {
	my $r = $recs->{ $gene_oid };
        my( $gene_oid, $locus_tag, $desc, $desc_orig, 
	       $taxon_oid, $taxon_display_name, $batch_id, $scaffold_oid,
	       @outColVals ) = split( /\t/, $r );
	    
        print "<tr class='img'>\n";

	# get all terms associated with this gene
	my $sql = qq{
	    select g.gene_oid, g.function, t.term,
	        g.f_flag, g.f_order, g.evidence, g.confidence,
	        g.cell_loc
		from gene_img_functions g, img_term t
		where g.gene_oid = $gene_oid
		and g.function = t.term_oid
	};

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $g_oid, $term_oid, $term, $f_flag, $f_order,
		$evid, $conf, $cell_loc )
		= $cur->fetchrow( );
	    last if !$g_oid;
	    $term_oid = FuncUtil::termOidPadded( $term_oid );

	    print "<td class='img'>\n";
	    print "  <select name='op|$gene_oid|$term_oid' class='img' size='1'>\n";
	    print "    <option value='NoChange' selected />NoChange</option>\n";
	    print "    <option value='Update' />Update</option>\n";
	    print "    <option value='Delete' />Delete</option>\n";
	    print "  </select>\n";
	    print "</td>\n";

	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $desc ) . "</td>\n";

	    # print IMG terms for this gene
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";

	    # f_flag
	    print "<td class='img' bgcolor='#92c759'>\n";
	    my $j = 0;
	    for my $tt ( 'M', 'C', 'P' ) {
		if ( $j > 0 ) {
		    print "<br/>\n";
		}
		print "  <input type='radio' name='f_flag|$gene_oid|$term_oid' " .
		    "value='$tt'";
		if ( (uc $f_flag) eq (uc $tt) ) {
		    print " checked";
		}
		print "/>$tt\n";
		$j++;
	    }
	    print "</td>\n";

	    # f_order
	    print "<td class='img' align='left'>" .
		"<input type='text' name='f_order|$gene_oid|$term_oid' " .
		"value='" . escapeHTML( $f_order ) . "' size='4' " .
		"maxlength='4'/>" . "</td>\n";

	    # evidence
	    print "<td class='img' align='left'>" .
		"<input type='text' name='evid|$gene_oid|$term_oid' " .
		"value='" . escapeHTML( $evid ) . "' size='15' " .
		"maxlength='255'/>" . "</td>\n";

	    # confidence
	    print "<td class='img' align='left'>" .
		"<input type='text' name='conf|$gene_oid|$term_oid' " .
		"value='" . escapeHTML( $conf ) . "' size='25' " .
		"maxlength='255'/>" . "</td>\n";

	    # cell_loc
	    print "<td class='img'>\n";
	    print "  <select name='cell_loc|$gene_oid|$term_oid' class='img' size='1'>\n";

	    for my $c2 ( @cell_locs ) {
		print "    <option value='$c2'";
		if ( $c2 eq $cell_loc ) {
		    print " selected";
		}
		elsif ( blankStr($c2) && blankStr($cell_loc) ) {
		    print " selected";
		}
		print " />$c2</option>\n";
	    }
	    print "  </select>\n";
	    print "</td>\n";

	    print "</tr>\n";
	}
	$cur->finish();
    }
    print "</table>\n";
    print "<br/>\n";

    ##$dbh->disconnect();

    # add buttons
    my $name = "_section_${section}_confirmGeneTermUpdate";
    print submit( -name => $name,
       -value => 'Update Database', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
       -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    print end_form( );
}



############################################################################
# printConfirmGeneTermUpdateForm - confirm gene-term update
############################################################################
sub printConfirmGeneTermUpdateForm {

    print "<h1>Confirm Gene - Term Associations Update</h1>\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );
    my $name = "_section_${section}_dbBatchUpdate";
    print submit( -name => $name,
       -value => 'Update Database', -class => 'meddefbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_index";
    print submit( -name => $name,
       -value => 'Cancel', -class => 'smbutton' );

    print "</p>\n";

    # show table header
    print "<table class='img'>\n";
    print "<th class='img'>Update/Delete</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>Term_Flag </th>";
    print "<th class='img'>F_Order</th>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Confidence</th>\n";
    print "<th class='img'>Cell Localization</th>\n";
    print "</tr>\n";

    #my $query = WebUtil::getCgi();
    my @all_params = param(); #$query->param;
    for my $p( @all_params ) {
	if ( $p =~ /^op\|/ ) {
	    my ($tag, $gene_oid, $term_oid) = split(/\|/, $p);

	    my $op = param($p);
	    if ( $op ne 'Update' && $op ne 'Delete' ) {
		next;
	    }

	    print hiddenVar( $p, $op );
	    print hiddenVar ( 'gene_oid', $gene_oid );

	    # update or delete
	    print "<td class='img'>" . $op . "</td>\n";

	    # gene oid
	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

	    # print IMG terms for this gene
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	    # other attribute values
	    for my $tag2 ( 'f_flag', 'f_order', 'evid', 'conf', 'cell_loc' ) {
		my $p2 = "$tag2|$gene_oid|$term_oid";
		my $val2 = param($p2);
		print "<td class='img'>" . escapeHTML($val2) . "</td>\n";

		if ( $op eq 'Update' && $tag2 eq 'f_order' ) {
		    # check f_order
		    if ( !isInt($val2) ) {
			print "</tr></table>\n";
			webError("F_order ($val2) must be an integer.");
			return;
		    }
		    elsif ( $val2 < 0 ) {
			print "</tr></table>\n";
			webError("F_order ($val2) cannot be negative.");
			return;
		    }
		}

		if ( $op eq 'Update' && !blankStr($val2) ) {
		    print hiddenVar($p2, $val2);
		}
	    }

	    print "</tr>\n";
	}
    }

    print "</table>\n";

    print end_form( );
}


############################################################################
# dbBatchUpdate - batch update gene-term associations
############################################################################
sub dbBatchUpdate {

    my @sqlList = ();
    my $sql;

   # my $query = WebUtil::getCgi();
    my @all_params = param(); #$query->param;
    for my $p( @all_params ) {
    	if ( $p =~ /^op\|/ ) {
    	    my ($tag, $gene_oid, $term_oid) = split(/\|/, $p);
    
    	    my $op = param($p);
    	    if ( $op ne 'Update' && $op ne 'Delete' ) {
        		next;
    	    }
    
    	    if ( $op eq 'Update' ) {
        		$sql = "update GENE_IMG_FUNCTIONS set ";
        
        		# f_flag
        		my $p2 = "f_flag|$gene_oid|$term_oid";
        		my $val2 = param($p2);
        		if ( blankStr($val2) ) {
        		    $sql .= "f_flag = 'M'";
        		}
        		else {
        		    $sql .= "f_flag = '$val2'";
        		}
        
        		# f_order
        		$p2 = "f_order|$gene_oid|$term_oid";
        		$val2 = param($p2);
        		if ( blankStr($val2) ) {
        		    $sql .= ", f_order = 0";
        		}
        		else {
        		    $sql .= ", f_order = $val2";
        		}
        
        		# evidence
        		$p2 = "evid|$gene_oid|$term_oid";
        		$val2 = param($p2);
        		if ( blankStr($val2) ) {
        		    $sql .= ", evidence = null";
        		}
        		else {
        		    $val2 =~ s/'/''/g;  # replace ' with ''
        		    $sql .= ", evidence = '$val2'";
        		}
        
        		# confidence
        		$p2 = "conf|$gene_oid|$term_oid";
        		$val2 = param($p2);
        		if ( blankStr($val2) ) {
        		    $sql .= ", confidence = null";
        		}
        		else {
        		    $val2 =~ s/'/''/g;  # replace ' with ''
        		    $sql .= ", confidence = '$val2'";
        		}
        
        		# cell_loc
        		$p2 = "cell_loc|$gene_oid|$term_oid";
        		$val2 = param($p2);
        		if ( blankStr($val2) ) {
        		    $sql .= ", cell_loc = null";
        		}
        		else {
        		    $val2 =~ s/'/''/g;  # replace ' with ''
        		    $sql .= ", cell_loc = '$val2'";
        		}
        
        		# mod_date and modified_by
        		if ( $contact_oid ) {
        		    $sql .= ", modified_by = $contact_oid";
        		}
        		$sql .= ", mod_date = sysdate ";
        		$sql .= "where gene_oid = $gene_oid and function = $term_oid";
        		push @sqlList, ( $sql );
    	    }
    	    elsif ( $op eq 'Delete' ) {
        		# delete from synonym?
        		my $dbh = dbLogin();
        		my ($found, $prod, $new_gene_oid) =
        		    checkGeneOid ( $dbh, $gene_oid );
        		if ( ! isPseudo($prod) && ! $img_lite ) {
        		    # we are going to use case-insensitive comparison
        		    # so change the product to lower case
        		    my $product = lc $prod;
        		    $product =~ s/'/''/g;   # replace ' with ''
        
        		    if ( ! $img_lite &&
        			 deleteGeneProdFromSynonym($dbh, $gene_oid, $product,
        						   $term_oid) ) {
            			$sql = "delete from IMG_TERM_SYNONYMS where term_oid = $term_oid ";
            			$sql .= "and lower(synonyms) = '" . $product . "' ";
            			push @sqlList, ( $sql );
        		    }
        		}
        		##$dbh->disconnect();
        
        		$sql = "delete from GENE_IMG_FUNCTIONS where " .
        		    "gene_oid = $gene_oid and function = $term_oid";
        		push @sqlList, ( $sql );
        
    	    }
    	}
    }

#    for $sql ( @sqlList ) {
#	print "<p>SQL: $sql</p>\n";
#    }

    # perform database update
    if ( scalar(@sqlList) > 0 ) {
	db_sqlTrans_2( @sqlList );
    }
}


############################################################################
# printAdvancedGeneSearchForm - advanced gene search
############################################################################
sub printAdvancedGeneSearchForm {
    print "<h1>Advanced Gene Search</h1>\n";

    my $class_name = "GENE";

    printMainForm( );

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
    my $name = "_section_${section}_geneQueryResult";
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
# printGeneQueryResultForm - advanced gene search result
############################################################################
sub printGeneQueryResultForm {
    print "<h1>Advanced Gene Search Results</h1>\n";
    
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

    my @displays = ( "$display_name OID", "Product Name" );
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
	    print "Click item(s) to add to Gene Curation Cart.</p>\n";
	    print "<p>\n";

	        # show buttons
	    my $name = "_section_${section}_addToGeneCart";
	        print submit( -name => $name,
			      -value => "Add to Gene Curation Cart",
			      -class => "lgdefbutton" );
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

	# show this gene
	$result_oid = FuncUtil::oidPadded($class_name, $result_oid);
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' ";
	print "name='gene_oid' value='$result_oid' />\n"; 
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

    ##$dbh->disconnect();

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

    my $name = "_section_${section}_addToGeneCart";
    print submit( -name => $name,
		  -value => "Add to Gene Curation Cart",
		  -class => "lgdefbutton" );
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
# printInferTermResultForm - show infer term based on ortholog
############################################################################
sub printInferTermResultForm {

    print "<h1>Infer Term from Ortholog Genes</h1>\n";
    # print "<h3><font color='red'>Under Construction</font></h3>\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    ## Set parameters.
    print hiddenVar( "section", $section );
    print "</p>\n";

    # get gene_oid
    my @selected_gene_oids = param( "gene_oid" );
    if ( scalar(@selected_gene_oids) == 0 ) {
	webError("No gene has been selected.");
	return;
    }
    my $gene_oid = $selected_gene_oids[0];

    print "<p>This pages shows existing gene-term associations for gene $gene_oid, and possible new gene-term associations inferred from gene ortholog information.</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $cnt0 = 0;

    my $dbh = dbLogin();

    my $sql = "select function, f_flag, f_order, evidence, confidence " .
	"from GENE_IMG_FUNCTIONS where gene_oid = $gene_oid";
    my $cur = execSql( $dbh, $sql, $verbose ); 

    my @old_gene_terms = ();

    for (;;) { 
        my ( $term_oid, $f_flag, $f_order, $evid, $conf ) = $cur->fetchrow( );
        last if !$term_oid;

	if ( $cnt0 == 0 ) {
	    # first
	    # show table header
	    print "<h2>Existing Gene - Term Associations for Gene $gene_oid</h2>\n";

	    print "<table class='img'>\n";
	    print "<th class='img'>Gene ID</th>\n";
	    print "<th class='img'>Term Object ID</th>\n";
	    print "<th class='img'>Term_Flag </th>";
	    print "<th class='img'>F_Order</th>\n";
	    print "<th class='img'>Evidence</th>\n";
	    print "<th class='img'>Confidence</th>\n";
	    print "</tr>\n";
	}

	$cnt0++;

	# gene oid
	my $url = "$main_cgi?section=GeneDetail" . 
	    "&page=geneDetail&gene_oid=$gene_oid";
	print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

	# print IMG terms for this gene
	$term_oid = FuncUtil::termOidPadded( $term_oid );
	my $url = "$main_cgi?section=ImgTermBrowser" . 
	    "&page=imgTermDetail&term_oid=$term_oid";
	print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	# save old gene terms
	push @old_gene_terms, ( "old|$gene_oid|$term_oid" );

	# f_flag
	print "<td class='img'>" . escapeHTML($f_flag) . "</td>\n";

	# f_order
	print "<td class='img'>" . escapeHTML($f_order) . "</td>\n";

	# evidence
	print "<td class='img'>" . escapeHTML($evid) . "</td>\n";

	# confidence
	print "<td class='img'>" . escapeHTML($conf) . "</td>\n";

	print "</tr>\n";
    }
    $cur->finish();

    if ( $cnt0 > 0 ) {
	print "</table>\n";
    }
    else {
	print "<h2>No Existing Gene - Term Associations for Gene $gene_oid</h2>\n";
    }

    print hiddenVar( "gene_oid", $gene_oid );
    print hiddenVar( "old_gene_term_count", $cnt0 );

    for my $s3 ( @old_gene_terms ) {
	print hiddenVar( $s3, $s3 );
    }

    # infer IMG terms
    my $count = 0;
    my $msg = "";
    my @infer_results = inferGeneTerms($dbh, $gene_oid);

    # show table header
    print "<h2>Inferred IMG Term(s) from Ortholog Genes</h2>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>Term_Flag </th>";
    print "<th class='img'>F_Order</th>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Confidence</th>\n";
    print "</tr>\n";

    if ( scalar(@infer_results) > 0 ) {
	$msg = $infer_results[0];

	my $i2 = 1;
	while ( $i2 < scalar(@infer_results) ) {
	    my $s2 = $infer_results[$i2];
	    my ($f1, $f2, $f3, $f4, $f5, $f6) = split(/\t/, $s2);

	    # select
	    print "<tr class='img'>\n";
	    print "<td class='checkbox'>\n";
	    print "<input type='checkbox' ";
	    print "name='new|$f1|$f2' value='$f1|f2' checked />\n";
	    print "</td>\n";

	    # gene oid
	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$f1";
	    print "<td class='img'>" . alink( $url, $f1 ) . "</td>\n";

	    # term_oid
	    $f2 = FuncUtil::termOidPadded( $f2 );
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$f2";
	    print "<td class='img'>" . alink( $url, $f2 ) . "</td>\n";

	    # f_flag
	    print "<td class='img' bgcolor='#92c759'>\n";
	    my $j = 0;
	    for my $tt ( 'M', 'C', 'P' ) {
		if ( $j > 0 ) {
		    print "<br/>\n";
		}
		print "  <input type='radio' name='f_flag|$f1|$f2' " .
		    "value='$tt'";
		if ( (uc $f3) eq (uc $tt) ) {
		    print " checked";
		}
		print "/>$tt\n";
		$j++;
	    }
	    print "</td>\n";

	    # f_order
	    print "<td class='img' align='left'>" .
		"<input type='text' name='f_order|$f1|$f2' " .
		"value='" . escapeHTML( $f4 ) . "' size='4' " .
		"maxlength='4'/>" . "</td>\n";

	    # evidence
	    print "<td class='img' align='left'>" .
		"<input type='text' name='evid|$f1|$f2' " .
		"value='" . escapeHTML( $f5 ) . "' size='15' " .
		"maxlength='255'/>" . "</td>\n";

	    # confidence
	    print "<td class='img' align='left'>" .
		"<input type='text' name='conf|$f1|$f2' " .
		"value='" . escapeHTML( $f6 ) . "' size='50' " .
		"maxlength='255'/>" . "</td>\n";

	    print "</tr>\n";

	    $count++;
	    $i2++;
	}
    }

    print "</table>\n";

    ##$dbh->disconnect();

    printStatusLine( "$count item(s) found.", 2 );

    if ( $count == 0 ) {
	print "<p>No IMG terms are found for this gene based on orthlog genes.</p>\n";
    }
    if ( $msg ne "" ) {
	print "<p>$msg</p>\n";
    }

    # show buttons
    print "<br/>\n";

    if ( $count > 0 ) {
	my $name = "_section_${section}_addInferredTerm";
	print submit( -name => $name,
		      -value => "Add Gene-Terms",
		      -class => "smdefbutton" );
	print nbsp( 1 );
	my $name = "_section_${section}_replaceInferredTerm";
	print submit( -name => $name,
		      -value => "Replace Gene-Terms",
		      -class => "smbutton" );
	print nbsp( 1 );
	print "<input type='button' name='selectAll' value='Select All' " .
	    "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	print nbsp( 1 );
	print "<input type='button' name='clearAll' value='Clear All' " . 
	    "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	print nbsp( 1 );
    }

    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form( );
}


############################################################################
# inferGeneTerms
############################################################################
sub inferGeneTerms {
    my ($dbh, $gene_oid) = @_;

    my $max_hit = 5;
    my $extend_hit = 10;

    my @res = ();
    my $msg = "";

    # get aa_seq_length of this gene
    my $aa_seq_length = getAASeqLength($dbh, $gene_oid);

    # get top max_hit and extend_hit BBH genes
    my $has_25_percent_identity = 0; 
    my $sql = "select ortholog, subj_start, subj_end, " .
	"query_start, query_end, bit_score, percent_identity " . 
	"from GENE_ORTHOLOGS where gene_oid=$gene_oid"; 
    $sql .= " order by bit_score desc";

    # print "<p>SQL: $sql</p>\n";

    # get the top n hit
    my @bbh_genes = (); 
    my $g_id = 0;
    my $i;

    my $cur = execSql( $dbh, $sql, $verbose ); 
 
    for ($i = 1; $i <= $extend_hit; $i++) { 
	my ( $ortho_id, $sb, $se, $qb, $qe, $score, $perc ) =
	    $cur->fetchrow( ); 
	last if !$ortho_id; 

	# check percent_identity 
	if ( $i <= $max_hit && $perc >= 25.0 ) { 
	    $has_25_percent_identity = 1; 
 	} 
 
	# get percentage for query gene 
	my $p1 = ($qe - $qb + 1) / $aa_seq_length; 
 
	if ( $p1 >= 0.7 ) { 
	    my $ortho_aa_seq_length = getAASeqLength($dbh, $ortho_id);
	    my $p2 = ($se - $sb + 1) / $ortho_aa_seq_length;
 
	    if ( $p2 >= 0.7 ) { 
		# check aa_seq_length ratio
		my $ratio = 0; 
		if ( $aa_seq_length <= 0 || $ortho_aa_seq_length <= 0 ) {
		    # to avoid divide by zero (shouldn't happen)
		    last;
		} 
		elsif ( $aa_seq_length >= $ortho_aa_seq_length ) {
		    $ratio = $ortho_aa_seq_length / $aa_seq_length;
		} 
		else { 
		    $ratio = $aa_seq_length / $ortho_aa_seq_length;
		}
 
		if ( $ratio < 0.70 ) { 
		    last; 
		} 
 
		push @bbh_genes, ( $ortho_id );
	    } 
	    else {
		# stop
		last;
	    } 
	} 
	else { 
	    # stop 
	    last; 
	} 
    }  # end for
    $cur->finish();
 
    if ( scalar(@bbh_genes) < $max_hit ) { 
	# not enough hit 
	if ( scalar(@bbh_genes) == 0 ) {
	    $msg = "No qualified orthologs are found.";
	}
	else {
	    $msg = "Only " . scalar(@bbh_genes) .
		" qualified orthologs are found.";
	}
	push @res, ( $msg );
	return @res;
    }
    elsif ( $has_25_percent_identity < 1 ) {
	# does not satisfy the 25% identity rule
	$msg = "Gene does not satisfy the 25 percent identity rule.";
	push @res, ( $msg );
	return @res;
    } 
 
    my $t_id = 0; 
    my $confid = "";
    my $f_flag = "";
    # check IMG_TERM 
    # select all terms associated with bbh_genes 
    my $is_first = 1; 
    $sql = "select gene_oid, function, f_flag from GENE_IMG_FUNCTIONS " . 
	"where gene_oid in ("; 
    for $g_id ( @bbh_genes ) { 
	if ( $is_first ) { 
	    $sql .= $g_id; 
	    $is_first = 0; 
	} 
	else { 
	    $sql .= ", $g_id"; 
	} 
    } 
#       $sql .= ") and f_flag = 'M' order by gene_oid, function"; 
    $sql .= ") order by gene_oid, function"; 

    # print "<p>SQL: $sql</p>\n";

    $cur = execSql( $dbh, $sql, $verbose ); 
 
    my @prop_terms = ();       # terms for progation
    my %bbh_terms; 
    my %cp_terms; 
    my $t_flag;
    my $f_order = 0;

    # retrieve all gene-term info from database for gene_oid and BBH genes 
    for (;;) { 
	( $g_id, $t_id, $t_flag ) = $cur->fetchrow( ); 
	last if !$g_id; 

	if ( $t_flag eq 'M' ) { 
	    # M-flag 
	    if ( $bbh_terms{$g_id} ) { 
		$bbh_terms{$g_id} .= " " . $t_id; 
	    } 
	    else { 
		$bbh_terms{$g_id} = $t_id; 
	    } 
	} 
	else { 
	    # C-flag or P-flag 
	    if ( $cp_terms{$g_id} ) { 
		$cp_terms{$g_id} .= " " . $t_id; 
	    } 
	    else { 
		$cp_terms{$g_id} = $t_id; 
	    } 
	} 
    }  # end for 

    # check terms for all BBH genes 
    my $cnt = 0; 
    my $total = 0; 
    $is_first = 1; 

    for my $key ( @bbh_genes ) { 
	$total++; 

	# skip this gene if there are no terms 
	if ( ! $bbh_terms{$key} ) { 
	    if ( $total == $max_hit ) { 
		if ( $cnt > 1 ) { 
		    # we can stop at $max_hit if IMG terms are found 
		    last; 
		} 
		elsif ( $cnt <= 0 ) { 
		    # No terms associated with top $max_hit genes. don't proceed 
		    last; 
		}
	    } 
 
	    next; 
	} 
 
	if ( $is_first ) { 
	    @prop_terms = split (/ /, $bbh_terms{$key});
	    if ( scalar(@prop_terms) > 0 ) {
		$is_first = 0; 
		$cnt++;
		$confid = "Inferred term from ortholog(s) $key";
	    } 
	} 
	else { 
	    # next term 
	    my @terms = split (/ /, $bbh_terms{$key});
	    if ( scalar(@prop_terms) > 0 && scalar(@terms) > 0 ) {
		if ( WebUtil::isSubset(\@prop_terms, \@terms) &&
		     WebUtil::isSubset(\@terms, \@prop_terms) ) {
		    $cnt++; 
		    $confid .= " $key"; 
		}
		else {
		    $cnt = -1; 
		    last;
		}
	    } 
	} 

	# check when reach $max_hit
	if ( $total == $max_hit ) {
	    if ( $cnt > 1 ) {
		# we can stop at $max_hit if IMG terms are found
		last; 
	    } 
	    elsif ( $cnt <= 0 ) {
		# No terms associated with top $max_hit genes. don't proceed
		last; 
	    } 
	} 
    }  # end for key 
 
    # run confirmation when cnt > 0 
    my $msg2 = "";
    if ( $cnt > 0 && $total >= $max_hit ) { 
#       if ( $cnt > 1 && $total >= $max_hit ) { 
	# propagate terms 
	if ( $cnt == $total ) { 
	    $f_flag = 'C'; 
	} 
	else { 
	    $f_flag = 'P'; 
	} 
 
	my $cp_cnt = 0; 
	my @confirm2 = (); 
	my @conflict2 = ();
	for my $key2 ( @bbh_genes ) {
	    if ( $cp_cnt >= $total ) {
		last; 
	    } 
	    $cp_cnt++; 
 
	    # skip this gene if there are no terms
	    if ( ! $cp_terms{$key2} ) {
		next; 
	    } 
 
	    my @cpts = split (/ /, $cp_terms{$key2});
	    for my $t2 ( @cpts ) { 
		if ( WebUtil::inArray ($t2, @prop_terms) ) {
		    if ( ! WebUtil::inArray($t2, @confirm2) ) { 
			    push @confirm2, ( $t2 );
		    } 
		}
		else {
		    if ( ! WebUtil::inArray($t2, @conflict2) ) {
			    $msg2 .= " Term $t2, Gene $key2.";
			    push @conflict2, ( $t2 );
		    } 
		} 
	    }
	} 

	if ( scalar(@prop_terms) == 0 ) {
	    $msg = "No terms are associated with top-hit ortholog genes.";
	    push @res, ( $msg );
	    return @res;
	}

	if ( scalar(@conflict2) > 0 ) { 
	    $msg = "Top-hit BBH genes:";
	    for my $s3 ( @bbh_genes ) {
		$msg .= " $s3";
	    }
	    $msg .= ". ";
	    $msg .= "Proposed term(s):";
	    for my $s3 ( @prop_terms ) {
		$msg .= " $s3";
	    }
	    $msg .= ". Gene-term not propagated due to conflict C/P term(s):";
	    $msg .= $msg2;
	    push @res, ( $msg );
	    return @res;
	}
 
	if ( $cnt <= 1 ) { 
	    $msg = "Gene-term not propagated due to insufficient M term(s).";
	    push @res, ( $msg );
	    return @res;
	} 
 
	# propagate IMG terms 
	$msg = scalar(@prop_terms) . " IMG terms found.";
	push @res, ( $msg );

	for $t_id ( @prop_terms ) { 
	    my $s = "$gene_oid\t$t_id\t$f_flag\t$f_order\tInferred\t$confid";
	    push @res, ( $s );
	}
    }
    else {
	# No terms associated with top $max_hit genes. don't proceed
	if ( $cnt == 0 ) {
	    $msg = "No terms are associated with top-hit ortholog genes";
	}
	else {
	    $msg = "Gene does not have enough top-hit orthologs for inference.";
	}
	push @res, ( $msg );
    }

    return @res;
}

############################################################################ 
# getAASeqLength - get aa_seq_length of $gene_oid 
############################################################################ 
sub getAASeqLength { 
    my ($dbh, $gene_oid) = @_; 
 
    my %h; 
    my $len = 0; 
 
    #exec SQL
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
 
    my $sql = qq{
        select g.aa_seq_length 
        from GENE g 
        where g.gene_oid = $gene_oid
        $rclause
        $imgClause
    }; 
 
    my $cur = execSql( $dbh, $sql, $verbose ); 
 
    for( ;; ) { 
        my ( $db_val ) = $cur->fetchrow( ); 
        last if !$db_val; 
 
        # get aa_seq_length 
        $len = $db_val; 
    }  # end for loop 
 
    return $len; 
} 


############################################################################
# printConfirmAddUpdateInfer
############################################################################
sub printConfirmAddUpdateInfer {
    my ( $to_update ) = @_;

    print "<h1>Confirm Gene-Term Association Update</h1>\n";
    # print "<h3><font color='red'>Under Construction</font></h3>\n";

    printMainForm( );

    print "<p>\n"; # paragraph section puts text in proper font.

    my $gene_oid = param('gene_oid');
    print hiddenVar( 'gene_oid', $gene_oid );
    my $old_count = param('old_gene_term_count');
    print hiddenVar( 'old_gene_term_count', $old_count );

    print hiddenVar( 'to_update', $to_update );

    # show table header
    print "<h2>IMG Term(s) Associated with Gene $gene_oid</h2>\n";

    print "<p>Gene will be associated with the following IMG terms after database update:</p>\n";

    print "<table class='img'>\n";
    print "<th class='img'>Existing/New</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Term Object ID</th>\n";
    print "<th class='img'>Term_Flag </th>";
    print "<th class='img'>F_Order</th>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Confidence</th>\n";
    print "</tr>\n";

    if ( $to_update == 0 ) {
	# show old data
	my $dbh = dbLogin();
	my $sql = "select function, f_flag, f_order, evidence, confidence " .
	    "from GENE_IMG_FUNCTIONS where gene_oid = $gene_oid";
	my $cur = execSql( $dbh, $sql, $verbose ); 

	for (;;) { 
	    my ( $term_oid, $f_flag, $f_order, $evid, $conf ) = $cur->fetchrow( );
	    last if !$term_oid;

	    print "<td class='img'>Existing</td>\n";

	    # gene oid
	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

	    # print IMG terms for this gene
	    $term_oid = FuncUtil::termOidPadded( $term_oid );
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	    # f_flag
	    print "<td class='img'>" . escapeHTML($f_flag) . "</td>\n";

	    # f_order
	    print "<td class='img'>" . escapeHTML($f_order) . "</td>\n";

	    # evidence
	    print "<td class='img'>" . escapeHTML($evid) . "</td>\n";

	    # confidence
	    print "<td class='img'>" . escapeHTML($conf) . "</td>\n";

	    print "</tr>\n";
	}
	$cur->finish();
	##$dbh->disconnect();
    }

    # show new data
    #my $query = WebUtil::getCgi();
    my @all_params = param(); #query->param;
    for my $p( @all_params ) {
	if ( $p =~ /^new\|/ ) {
	    my ($tag, $g_oid, $term_oid) = split(/\|/, $p);

	    $term_oid = FuncUtil::termOidPadded( $term_oid );

	    # check whether it's duplicate
	    if ( $to_update == 0 ) {
		my $s = "old|$g_oid|$term_oid";
		if ( param($s) ) {
		    # duplicate
		    next;
		}
	    }

	    print "<td class='img'>New</td>\n";

	    # gene oid
	    my $url = "$main_cgi?section=GeneDetail" . 
		"&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

	    # term_oid
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
		"&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";

	    # check input data
	    # f_flag
	    my $f_flag = param ("f_flag|$gene_oid|$term_oid");
	    print "<td class='img'>" . escapeHTML($f_flag) . "</td>\n";

	    if ( blankStr($f_flag) ) {
		print "</tr></table>\n";
		webError("Term_flag for term $term_oid is not specified.");
		return;
	    }

	    # f_order
	    my $f_order = param ("f_order|$gene_oid|$term_oid");
	    print "<td class='img'>" . escapeHTML($f_order) . "</td>\n";

	    if ( blankStr($f_order) ) {
		print "</tr></table>\n";
		webError("F_order for term $term_oid is not specified.");
		return;
	    }
	    elsif ( !isInt($f_order) ) {
		print "</tr></table>\n";
		webError("F_order for term $term_oid is not an integer.");
		return;
	    }
	    elsif ( $f_order < 0 ) {
		print "</tr></table>\n";
		webError("F_order for term $term_oid is negative.");
		return;
	    }

	    # evidence
	    my $evid = param ("evid|$gene_oid|$term_oid");
	    print "<td class='img'>" . escapeHTML($evid) . "</td>\n";

	    # confidence
	    my $conf = param ("conf|$gene_oid|$term_oid");
	    print "<td class='img'>" . escapeHTML($conf) . "</td>\n";

	    print "</tr>\n";
	}
    }
    print "</table>\n";

    # pass parameters as hidden variables
    my $count = 0;
    #my $query = WebUtil::getCgi();
    my @all_params = param(); #$query->param;
    for my $p( @all_params ) {
	if ( $p =~ /^new\|/ ) {
	    my ($tag, $g_oid, $term_oid) = split(/\|/, $p);

	    $term_oid = FuncUtil::termOidPadded( $term_oid );

	    # check whether it's duplicate
	    if ( $to_update == 0 ) {
		my $s = "old|$g_oid|$term_oid";
		if ( param($s) ) {
		    # duplicate
		    next;
		}
	    }

	    my $s2 = "new|$gene_oid|$term_oid";
	    print hiddenVar($s2, $s2);

	    # f_flag
	    my $f_flag = param ("f_flag|$gene_oid|$term_oid");
	    print hiddenVar( "f_flag|$gene_oid|$term_oid", $f_flag);

	    # f_order
	    my $f_order = param ("f_order|$gene_oid|$term_oid");
	    print hiddenVar( "f_order|$gene_oid|$term_oid", $f_order);

	    # evidence
	    my $evid = param ("evid|$gene_oid|$term_oid");
	    if ( !blankStr($evid) ) {
		print hiddenVar( "evid|$gene_oid|$term_oid", $evid);
	    }

	    # confidence
	    my $conf = param ("conf|$gene_oid|$term_oid");
	    if ( !blankStr($conf) ) {
		print hiddenVar( "conf|$gene_oid|$term_oid", $conf);
	    }

	    $count++;
	}
    }

    # show buttons
    print "<br/>\n";

    if ( $old_count > 0 || $count > 0 ) {
	my $name = "_section_${section}_dbAddInferredTerm";
	print submit( -name => $name,
		      -value => "Update Database",
		      -class => "meddefbutton" );
	print nbsp( 1 );
    }

    my $name = "_section_${section}_index";
    print submit( -name => $name,
		  -value => 'Cancel', -class => 'smbutton' );

    print end_form();
}


############################################################################
# dbAddInferredTerms
############################################################################
sub dbAddInferredTerms {
    my ( $to_update ) = @_;

    my $gene_oid = param('gene_oid');
    my $old_count = param('old_gene_term_count');

    my $dbh2 = dbLogin();
    my $sql2 = "select taxon, scaffold from gene where gene_oid = ?";
    my $cur2 = execSql( $dbh2, $sql2, $verbose, $gene_oid );
    my ($taxon2, $scaffold2) = $cur2->fetchrow();
    $cur2->finish();
    #$dbh2->disconnect();

    my $sql;
    my @sqlList = ();

    # delete old data if update
    if ( $to_update && $old_count > 0 ) {
    	$sql = "delete from gene_img_functions where gene_oid = $gene_oid";
    	push @sqlList, ( $sql );    
    }

    # insert new data
   # my $query = WebUtil::getCgi();
    my @all_params = param(); #$query->param;
    for my $p( @all_params ) {
	if ( $p =~ /^new\|/ ) {
	    my ($tag, $g_oid, $term_oid) = split(/\|/, $p);

	    $term_oid = FuncUtil::termOidPadded( $term_oid );

	    my $f_flag = param ("f_flag|$gene_oid|$term_oid");
	    my $f_order = param ("f_order|$gene_oid|$term_oid");
	    my $evid = param ("evid|$gene_oid|$term_oid");
	    my $conf = param ("conf|$gene_oid|$term_oid");

	    $sql = "insert into gene_img_functions " .
		"(gene_oid, taxon, scaffold, function, f_flag, f_order, ";
	    if ( !blankStr($evid) ) {
    		$sql .= "evidence, ";
		}
	    if ( !blankStr($conf) ) {
    		$sql .= "confidence, ";
	    }
	    if ( $contact_oid ) {
    		$sql .= "modified_by, ";
	    }
	    $sql .= "mod_date) values ($gene_oid, $taxon2, $scaffold2, " .
		"$term_oid, '$f_flag', $f_order, ";
	    if ( !blankStr($evid) ) {
    		$evid =~ s/'/''/g;  # replace ' with ''
    		$sql .= "'$evid', ";
		}
	    if ( !blankStr($conf) ) {
    		$conf =~ s/'/''/g;  # replace ' with ''
    		$sql .= "'$conf', ";
	    }
	    if ( $contact_oid ) {
    		$sql .= "$contact_oid, ";
	    }
	    $sql .= "sysdate)";

	    push @sqlList, ( $sql );

	}
    }

#    for $sql ( @sqlList ) {
#	print "<p>SQL: $sql</p>\n";
#    }

    # perform database update
    if ( scalar(@sqlList) > 0 ) {
	db_sqlTrans_2( @sqlList );
    }
}


############################################################################
# printUploadFlatFileForm
############################################################################
sub printUploadFlatFileForm {
    print "<h1>Upload Gene - IMG Term Associations from File</h1>\n";

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
    print "<li>Containing 2 columns: (1) Gene ID, (2) Term or Synonym</li>\n";
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

    # tmp file name for file upload
    my $sessionId = getSessionId( );
    my $tmp_upload_file = $cgi_tmp_dir . "/upload." . $sessionId . ".txt";

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
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Term/Synonym</th>\n";
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
        my ($gene_oid, $term) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	if ( $line_no > $max_upload_line_count ) {
	    next;
	}

	my $msg = "";

        print "<tr class='img'>\n";

	print "<td class='img'>" . $line_no . "</td>\n";

	# check gene_oid
	my $hasError = 0;
	if ( isInt($gene_oid) ) {
	    my ($found, $product, $new_gene_oid)
                = checkGeneOid($dbh, $gene_oid); 
	    if ( ! $found ) { 
		$msg = "Error: Gene ID '$gene_oid' does not exist.";
		$hasError = 1;
	    }

	    if ( $new_gene_oid ne $gene_oid ) {
		$msg = "Warning: Input Gene ID '$gene_oid' is mapped to '$new_gene_oid'.";
		$gene_oid = $new_gene_oid;
	    }
	}
	else {
	    $msg = "Error: Gene ID must be an integer.";
	    $hasError = 1;
	}

	if ( $hasError ) {
	    # incorrect gene OID
	    print "<td class='img'>" . $gene_oid . "</td>\n";
	}
	else {
	    # correct gene OID
	    my $url = "$main_cgi?section=GeneDetail" . 
	       "&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
	}

	my $term_oid = -1;
	if ( $hasError == 0 ) {
	    # check term only if gene OID is correct
	    # remove quotes, leading and trailing blanks
	    my $term0 = strTrim($term);
	    if ( $term0 =~ /^\s*"(.*)"$/ ) { 
		($term0) = ($term0 =~ /^\s*"(.*)"$/);
		$term0 = strTrim($term0);
	    }

	    # check term
	    if ( blankStr($term0) ) {
		if ( length($msg) > 0 ) {
		    $msg .= "  Error: Term is blank.";
		}
		else {
		    $msg = "Error: Term is blank.";
		}
	    }
	    else {
		$term_oid = findIdForTermSynonym($dbh, $term0);
		if ( $term_oid < 0 ) {
		    if ( length($msg) > 0 ) {
			$msg .= "  Warning: Term/synonym is not in the database.";
		    }
		    else {
			$msg = "Warning: Term/synonym is not in the database.";
		    }
		}
		else {
		    # check whether gene-term association is already in the database
		    my %cond_h; 
		    $cond_h{"gene_oid"} = $gene_oid;
		    $cond_h{"function"} = $term_oid; 
		    if ( isInDatabase( $dbh, "GENE_IMG_FUNCTIONS", "gene_oid", 
				       \%cond_h) ) {
			if ( length($msg) > 0 ) {
			    $msg .= "  Warning: Gene-Term association already exists.";
			}
			else {
			    $msg = "Warning: Gene-Term association already exists.";
			}
		    }
		}
	    }
	}

	if ( $term_oid < 0 ) {
	    # show input term
	    print "<td class='img'>" . escapeHTML( $term ) . "</td>\n";
	}
	else {
	    # show hyperlink
	    my $url = "$main_cgi?section=ImgTermBrowser" . 
	       "&page=imgTermDetail&term_oid=$term_oid";
	    print "<td class='img'>" . alink( $url, $term ) . "</td>\n";
	}

	# error or warning?
	if ( $msg =~ /^Error/ ) {
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

    ##$dbh->disconnect();

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

    my @new_gene_oids = ( );
    my @new_term_oids = ( );

    # some variables needed during processing
    my $max_term_oid = findMaxID( $dbh, "IMG_TERM", "term_oid");
    my %term_h; 
    my %f_order_h;
 
    my %gene_term_data; 
    my %term_data; 
    my %synonym_data; 
 
    my $key; 
    my $val;
 
    my $line_no = 0;
    my $line;
    while ($line = <FILE>) {
        my ($gene_oid, $term) = split (/\t/, $line);
	$line_no++;

	# we don't want to process large files
	next if ( $line_no > $max_upload_line_count );

        # check Gene OID 
        next if ( isInt($gene_oid) == 0 );

        my ($found, $product, $new_gene_oid)
             = checkGeneOid($dbh, $gene_oid);

        next if ( ! $found );
	$gene_oid = $new_gene_oid;

	# save gene_oid into @new_gene_oids
        if ( ! WebUtil::inArray( $gene_oid, @new_gene_oids ) ) {
	    push @new_gene_oids, ( $gene_oid );
	}

        # get f_order
        if ( ! $f_order_h{$gene_oid} ) {
            if ( $replace ) {
                # replace mode - start with 0
                $f_order_h{$gene_oid} = 0;
            } 
            else { 
                # add mode - check database to get next f_order 
                my $j = getFOrder1( $dbh, $gene_oid ); 
                $f_order_h{$gene_oid} = $j; 
            } 
        } 

        # check term 
        # remove leading, trailing spaces, and double quotes 
	my $term0 = strTrim($term);
	if ( $term0 =~ /^\s*"(.*)"$/ ) { 
	    ($term0) = ($term0 =~ /^\s*"(.*)"$/);
	    $term0 = strTrim($term0);
	}

        next if ( length($term0) == 0 );
 
        my $lc_term = lc $term0; 
        if ( $term_h{$lc_term} ) { 
            # already there 
            my $term_oid = $term_h{$lc_term}; 
            my %cond_h; 
            $cond_h{"term_oid"} = $term_oid; 
            my $s1 = $product;
            $s1 =~ s/'/''/g;
            $cond_h{"lower(synonyms)"} = "'" . (lc $s1) . "'";

            if ( ! isPseudo($product) && ! $img_lite &&
                 ! isInDatabase( $dbh, "IMG_TERM_SYNONYMS", "synonyms", \%cond_h) ) {
                # add to IMG_TERM_SYNONYMS 
                $key = "$term_oid $product"; 
                if ( ! $synonym_data{$key} ) { 
                    $val = "$term_oid\t$product\t$contact_oid"; 
                    $synonym_data{$key} = $val; 
                }
            } 
 
            # add to GENE_IMG_FUNCTIONS
            $key = "$gene_oid $term_oid";
            if ( ! $gene_term_data{$key} ) {
                # check database to see whether the association is already there
                my %cond_h; 
                $cond_h{"gene_oid"} = $gene_oid;
                $cond_h{"function"} = $term_oid; 
                if ( ! isInDatabase( $dbh, "GENE_IMG_FUNCTIONS", "gene_oid", \%cond_h) ) {
                    # add 
                    my $f_order = $f_order_h{$gene_oid};
                    $val = "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM";
                    $gene_term_data{$key} = $val; 
                    $f_order_h{$gene_oid} = $f_order++;
                }
            }
        } 
        else { 
	    my $term_oid = findIdForTermSynonym($dbh, $term0);
            if ( $term_oid < 0 ) {
                # new term
                $max_term_oid++; 
                $term_oid = $max_term_oid;
 
                # save the new term_oid in @new_term_oids
	        push @new_term_oids, ( $term_oid );

                # add to IMG_TERM and IMG_TERM_SYNONYMS
                $key = $term_oid;
                $val = "$term_oid\t$term0\tGENE PRODUCT\t$contact_oid\tNo";
                $term_data{$key} = $val; 
 
                if ( ! isPseudo( $product ) && ! $img_lite ) { 
                    $key = "$term_oid $product"; 
                    if ( ! $synonym_data{$key} ) { 
                        $val = "$term_oid\t$product\t$contact_oid"; 
                        $synonym_data{$key} = $val; 
                    } 
                } 
 
                $term_h{$lc_term} = $term_oid; 
 
                # add to GENE_IMG_FUNCTIONS 
                $key = "$gene_oid $term_oid"; 
                if ( ! $gene_term_data{$key} ) { 
                    # check database to see whether the association is already there
                    my %cond_h; 
                    $cond_h{"gene_oid"} = $gene_oid;
                    $cond_h{"function"} = $term_oid; 
                    if ( ! isInDatabase( $dbh, "GENE_IMG_FUNCTIONS", "gene_oid", \%cond_h) ) {
                        # add 
                        my $f_order = $f_order_h{$gene_oid}; 
                        $val = "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM"; 
                        $gene_term_data{$key} = $val; 
                        $f_order_h{$gene_oid} = $f_order++; 
                    }
                } 
            } 
            else { 
                # existing term 
                # save the new term_oid in @new_term_oids
                if ( ! WebUtil::inArray( $term_oid, @new_term_oids ) ) {
	           push @new_term_oids, ( $term_oid );
	        }

                $term_h{$lc_term} = $term_oid; 
                my %cond_h;
                $cond_h{"term_oid"} = $term_oid;
                my $s1 = $product;
                $s1 =~ s/'/''/g;
	        $cond_h{"lower(synonyms)"} = "'" . (lc $s1) . "'";
	    
                if ( ! isPseudo( $product ) && ! $img_lite &&
                     ! isInDatabase( $dbh, "IMG_TERM_SYNONYMS", "synonyms", \%cond_h) ) {
                    # add to IMG_TERM_SYNONYMS 
                    $key = "$term_oid $product"; 
                    if ( ! $synonym_data{$key} ) { 
                        $val = "$term_oid\t$product\t$contact_oid"; 
                        $synonym_data{$key} = $val; 
                    } 
                } 
 
                # add to GENE_IMG_FUNCTIONS 
                $key = "$gene_oid $term_oid"; 
                if ( ! $gene_term_data{$key} ) { 
                    # check database to see whether the association is already there
		    my %cond_h; 
		    $cond_h{"gene_oid"} = $gene_oid;
		    $cond_h{"function"} = $term_oid; 
		    if ( ! isInDatabase( $dbh, "GENE_IMG_FUNCTIONS", "gene_oid", \%cond_h) ) {
                        # add 
                        my $f_order = $f_order_h{$gene_oid}; 
                        $val = "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM"; 
                        $gene_term_data{$key} = $val; 
                        $f_order_h{$gene_oid} = $f_order++; 
		    }
                } 
            } 
	}
    }

    close (FILE);

    # prepare SQL queries
    # IMG_TERM
    for $key ( sort (keys %term_data) ) { 
        my ($t_oid, $t_term, $t_type, $t_contact, $t_valid) = 
	    split(/\t/, $term_data{$key});
	$t_term =~ s/'/''/g;
	$sql = "insert into IMG_TERM (term_oid, term, term_type, modified_by, is_valid)";
	$sql .= " values ($t_oid, '$t_term', '$t_type', $t_contact, '$t_valid')";
	push @sqlList, ( $sql );
    } 

    # IMG_TERM_SYNONYMS
    for $key ( sort (keys %synonym_data) ) { 
	my ($t_oid, $t_syn, $t_contact) = split(/\t/, $synonym_data{$key});
	$t_syn =~ s/'/''/g;
	$sql = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, modified_by)";
	$sql .= " values ($t_oid, '$t_syn', $t_contact)";
	push @sqlList, ( $sql );
    }

    # GENE_IMG_FUNCTIONS
    for $key ( sort (keys %gene_term_data) ) { 
	my ($g_oid, $t_oid, $fo, $g_contact, $flg) = split(/\t/, $gene_term_data{$key});

	my $sql2 = "select taxon, scaffold from gene where gene_oid = ?";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $g_oid );
	my ($taxon2, $scaffold2) = $cur2->fetchrow();
	$cur2->finish();

	$sql = "insert into gene_img_functions (gene_oid, taxon, scaffold, " .
	    "function, f_order, modified_by, f_flag)";
	$sql .= " values ($g_oid, $taxon2, $scaffold2, $t_oid, $fo, $g_contact, '$flg')";
	push @sqlList, ( $sql );

        if ( ! WebUtil::inArray( $g_oid, @new_gene_oids ) ) {
	    push @new_gene_oids, ( $g_oid );
	}
    } 

    # perform database update
    if ( db_sqlTrans_2( @sqlList ) ) {
	# update Gene Cart
	if ( scalar(@new_gene_oids) > 0 ) {
	    my $gc = new GeneCartStor( );
	    $gc->addGeneBatch( \@new_gene_oids );
	}

	# update Img Term Cart
	if ( scalar(@new_term_oids) > 0 ) {
	    my $itc = new ImgTermCartStor( ); 
	    $itc->addImgTermBatch( \@new_term_oids );
	}
    }

    ##$dbh->disconnect();

    return 1;
}


############################################################################
# getImgTermCount - get IMG term count per gene
############################################################################
sub getImgTermCount {
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
		select gene_oid, count(function)
		    from gene_img_functions
		    where gene_oid in ( $keyList )
		    group by gene_oid
		};

	    my $cur = execSql( $dbh, $sql, $verbose );

	    for( ;; ) {
		my( $g_oid, $t_cnt ) = $cur->fetchrow( );
		last if !$g_oid;

		$h{ $g_oid } = $t_cnt;
	    }

	    $count = 0;
	    $keyList = "";
	}  # end else
    }  #end for k loop

    # last batch
    if ( $count > 0 && length($keyList) > 0 ) {
	my $sql = qq{
	    select gene_oid, count(function)
		from gene_img_functions
		where gene_oid in ( $keyList )
		group by gene_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $g_oid, $t_cnt ) = $cur->fetchrow( );
	    last if !$g_oid;

	    $h{ $g_oid } = $t_cnt;
	}
    }

    return %h;
}

############################################################################
# getGeneImgTerms - get IMG terms for each gene
############################################################################
sub getGeneImgTerms {
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
		select g.gene_oid, t.term
		    from gene_img_functions g, img_term t
		    where g.gene_oid in ( $keyList )
                    and g.function = t.term_oid
		    order by g.gene_oid
		};

	    my $cur = execSql( $dbh, $sql, $verbose );

	    my $prev_id = -1;

	    for( ;; ) {
		my( $g_oid, $term ) = $cur->fetchrow( );
		last if !$g_oid;

		if ( $prev_id == $g_oid ) {
		    # the same gene. append
		    $h{ $g_oid } .= " $term" ;
		}
		else {
		    # a new gene
		    $h{ $g_oid } = $term;
		}

		$prev_id = $g_oid;
	    }

	    $count = 0;
	    $keyList = "";
	}  # end else
    }  #end for k loop

    # last batch
    if ( $count > 0 && length($keyList) > 0 ) {
	my $sql = qq{
	    select g.gene_oid, t.term
		from gene_img_functions g, img_term t
		where g.gene_oid in ( $keyList )
		and g.function = t.term_oid
		order by g.gene_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	my $prev_id = -1;

	for( ;; ) {
	    my( $g_oid, $term ) = $cur->fetchrow( );
	    last if !$g_oid;

	    if ( $prev_id == $g_oid ) {
		# the same gene. append
		$h{ $g_oid } .= " $term" ;
	    }
	    else {
		# a new gene
		$h{ $g_oid } = $term;
	    }

	    $prev_id = $g_oid;
	}
    }

    return %h;
}


############################################################################
# getTermOidForGene - get all associated IMG term oid for a gene
############################################################################
sub getTermOidForGene {
    my ($dbh, $gene_oid) = @_;

    my @termList = ( );

    # exec SQL
    my $sql = qq{
	select g.gene_oid, g.function
	    from gene_img_functions g
	    where g.gene_oid = $gene_oid
	};

    my $cur = execSql( $dbh, $sql, $verbose );

    for( ;; ) {
	my( $g_oid, $term_oid ) = $cur->fetchrow( );
	last if !$g_oid;

	push @termList, ( $term_oid );
    }

    return @termList;
}


############################################################################
# getImgTerm - get IMG term for a term oid
############################################################################
sub getImgTerm {
    my ($dbh, $oid) = @_;

    #exec SQL
    my $sql = qq{
	select t.term
	    from img_term t
	    where t.term_oid = $oid
	};

    my $cur = execSql( $dbh, $sql, $verbose );

    my $term = "";

    for( ;; ) {
	my ( $t_val ) = $cur->fetchrow( );
	last if !$t_val;

	$term = $t_val;
    }

    return $term;
}


############################################################################
# getCOG - get COG per gene
############################################################################
sub getCOG {
    my ($dbh, @keys) = @_;

    my %h;

    my $count = 0;
    my $key_list;

    for my $k ( @keys ) {
	if ( $key_list ) {
	    $key_list .= ", " . $k;
	}
	else {
	    $key_list = $k;
	}
	$count++;

	if ( $count >= 1000 ) {
	    #exec SQL
	    my $sql = qq{
	        select g.gene_oid, c.cog_name
		from gene_cog_groups g, cog c
		where g.gene_oid in ( $key_list )
		and g.cog = c.cog_id
                order by 1, 2
	    };

	    my $cur = execSql( $dbh, $sql, $verbose );

	    for (;;) {
		my( $g_oid, $c_name ) = $cur->fetchrow( );
		last if !$g_oid;

		if ( $h{$g_oid} ) {
		    $h{$g_oid} .= " | $c_name";
		}
		else {
		    $h{$g_oid} = $c_name;
		}
	    }
	    $cur->finish();

	    $count = 0;
	    $key_list = "";
	}
    }

    # last batch
    if ( $key_list ) {
	#exec SQL
	my $sql = qq{
	        select g.gene_oid, c.cog_name
		from gene_cog_groups g, cog c
		where g.gene_oid in ( $key_list )
		and g.cog = c.cog_id
                order by 1, 2
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for (;;) {
	    my( $g_oid, $c_name ) = $cur->fetchrow( );
	    last if !$g_oid;

	    if ( $h{$g_oid} ) {
		$h{$g_oid} .= " | $c_name";
	    }
	    else {
		$h{$g_oid} = $c_name;
	    }
	}
	$cur->finish();
    }

    return %h;
}

############################################################################
# getPfam- get Pfam per gene
############################################################################
sub getPfam {
    my ($dbh, @keys) = @_;

    my %h;

    my $count = 0;
    my $key_list;

    for my $k ( @keys ) {
	if ( $key_list ) {
	    $key_list .= ", " . $k;
	}
	else {
	    $key_list = $k;
	}
	$count++;

	if ( $count >= 1000 ) {
	    #exec SQL
	    my $sql = qq{
	        select distinct g.gene_oid, p.name, p.description
		from gene_pfam_families g, pfam_family p
		where g.gene_oid in ( $key_list )
		and g.pfam_family = p.ext_accession
                order by 1, 2
	    };

	    my $cur = execSql( $dbh, $sql, $verbose );

	    for (;;) {
		my( $g_oid, $p_name, $p_desc ) = $cur->fetchrow( );
		last if !$g_oid;

		if ( $p_desc ) {
		    $p_name = $p_desc . " (" . $p_name . ")";
		}

		if ( $h{$g_oid} ) {
		    $h{$g_oid} .= " | $p_name";
		}
		else {
		    $h{$g_oid} = $p_name;
		}
	    }
	    $cur->finish();

	    $count = 0;
	    $key_list = "";
	}
    }

    # last batch
    if ( $key_list ) {
	#exec SQL
	my $sql = qq{
	        select distinct g.gene_oid, p.name, p.description
		from gene_pfam_families g, pfam_family p
		where g.gene_oid in ( $key_list )
		and g.pfam_family = p.ext_accession
                order by 1, 2
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for (;;) {
	    my( $g_oid, $p_name, $p_desc ) = $cur->fetchrow( );
	    last if !$g_oid;

	    if ( $p_desc ) {
		$p_name = $p_desc . " (" . $p_name . ")";
	    }

	    if ( $h{$g_oid} ) {
		$h{$g_oid} .= " | $p_name";
	    }
	    else {
		$h{$g_oid} = $p_name;
	    }
	}
	$cur->finish();
    }

    return %h;
}


############################################################################
# getTIGRfam- get TIGRfam per gene
############################################################################
sub getTIGRfam {
    my ($dbh, @keys) = @_;

    my %h;

    my $count = 0;
    my $key_list;

    for my $k ( @keys ) {
	if ( $key_list ) {
	    $key_list .= ", " . $k;
	}
	else {
	    $key_list = $k;
	}
	$count++;

	if ( $count >= 1000 ) {
	    #exec SQL
	    my $sql = qq{
	        select g.gene_oid, tigr.expanded_name,
                tigr.ext_accession, tigr.isology_type
		from gene_tigrfams g, tigrfam tigr
		where g.gene_oid in ( $key_list )
		and g.ext_accession = tigr.ext_accession
	    };

	    my $cur = execSql( $dbh, $sql, $verbose );

	    for (;;) {
		my( $g_oid, $t_name, $ext_accession, $iso_type ) = $cur->fetchrow( );
		last if !$g_oid;

		if ( $iso_type ) {
		    $t_name .= " (" . $iso_type . ")";
		}

		if ( $h{$g_oid} ) {
		    $h{$g_oid} .= " | $t_name";
		}
		else {
		    $h{$g_oid} = $t_name;
		}
	    }
	    $cur->finish();

	    $count = 0;
	    $key_list = "";
	}
    }

    # last batch
    if ( $key_list ) {
	#exec SQL
	my $sql = qq{
	        select g.gene_oid, tigr.expanded_name,
                tigr.ext_accession, tigr.isology_type
		from gene_tigrfams g, tigrfam tigr
		where g.gene_oid in ( $key_list )
		and g.ext_accession = tigr.ext_accession
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for (;;) {
	    my( $g_oid, $t_name, $ext_accession, $iso_type ) = $cur->fetchrow( );
	    last if !$g_oid;

	    if ( $iso_type ) {
		$t_name .= " (" . $iso_type . ")";
	    }

	    if ( $h{$g_oid} ) {
		$h{$g_oid} .= " | $t_name";
	    }
	    else {
		$h{$g_oid} = $t_name;
	    }
	}
	$cur->finish();
    }

    return %h;
}


############################################################################
# searchIMGTermSynonym - search IMG terms and synonyms that match
#                        the searchTerm
#
# (return IMG term oid => term hash)
############################################################################
sub searchIMGTermSynonym {
    my ($dbh, $searchTermLc, $max_count) = @_;

    my %h;

    # search IMG terms first
    ## --es 09/30/2006 Use lower( ) for case insensitive search.
    my $sql = qq{
        select it.term_oid, it.term
		from img_term it
		where lower( it.term ) like ? 
    };

    my $cur = execSql( $dbh, $sql, $verbose, "%$searchTermLc%" );
    my $count = 0;
    for( ;; ) {
        my( $term_oid, $term ) = $cur->fetchrow( );
	last if !$term_oid;

	# save term_oid and term
	if ( $count < $max_count ) {
	    $term_oid = sprintf( "%05d", $term_oid ); 
	    $h{ $term_oid } = "$term_oid $term";
	    $count++;
	}
    }
    $cur->finish( );

    # search synonyms only when max_count is not reached
    if ( $count >= $max_count ) {
	return %h
    }

    # search synonyms
    my $sql2 = qq{
        select it.term_oid, it.term, its.synonyms
		from img_term it, img_term_synonyms its
		where it.term_oid = its.term_oid
		and lower( its.synonyms ) like ? 
    };

    my $cur2 = execSql( $dbh, $sql2, $verbose, "%$searchTermLc%" );

    for( ;; ) {
        my( $term_oid, $term, $synonym ) = $cur2->fetchrow( );
	last if !$term_oid;

	# save term_oid and term
	$term_oid = sprintf( "%05d", $term_oid ); 

	if ( $count < $max_count &&
	     !($h{ $term_oid }) ) {
	    $h{ $term_oid } = "$term_oid $term";
	    $count++;
	}
    }
    $cur2->finish( );

    return %h
}

############################################################################
# getSynonyms - retrieve all synonyms for a list of IMG term oids
############################################################################
sub getSynonyms {
    my ($dbh, @keys) = @_;

    my %h;

    for my $key ( @keys ) {
	my $sql = qq{
	    select term_oid, synonyms
		from img_term_synonyms
		where term_oid = ? 
                order by synonyms
	    };

	my $cur = execSql( $dbh, $sql, $verbose, $key );

	my $synonymString = "";
	my $first = 1;

	for( ;; ) {
	    my( $term_oid, $synonym ) = $cur->fetchrow( );
	    last if !$term_oid;

	    $term_oid = sprintf( "%05d", $term_oid ); 

	    my $s = $synonym;

	    if ( $first ) {
		$first = 0;
		$synonymString = $s;
	    }
	    else {
		$synonymString .= ("\n" . $s);
	    }
	}

	if ( !$first ) {
	    $h{ $key } = $synonymString;
	}

	$cur->finish( );
    }

    return %h;
}


############################################################################# 
# findIdForTermSynonym - find Img Term OID for term (or synonym) 
# 
# use case-insensitive match 
############################################################################# 
sub findIdForTermSynonym { 
    my ($dbh, $term) = @_; 
 
    my $term_oid = -1; 
    my $lc_term = lc $term; 

    my $sql = "select term_oid from IMG_TERM where lower(term) = ? "; 

    my $cur = execSql( $dbh, $sql, $verbose, $lc_term);
 
    for ( ;; ) { 
        my ( $db_val ) = $cur->fetchrow( ); 
        last if !$db_val; 
 
        if ( $term_oid < 0 ) { 
            $term_oid = $db_val; 
        } 
    } 

    # now, search for synonym 
    $sql = "select term_oid from IMG_TERM_SYNONYMS where lower(synonyms) = ? "; 
 
    my $cur = execSql( $dbh, $sql, $verbose, $lc_term );

    for ( ;; ) { 
        my ( $db_val ) = $cur->fetchrow( ); 
        last if !$db_val; 
 
        if ( $term_oid < 0 ) { 
            $term_oid = $db_val; 
        } 
    } 
 
#    if ( $term_oid >= 0 ) { 
#        print "Synonym: $term, OID: $term_oid\n"; 
#    } 
 
    return $term_oid; 
} 


############################################################################ 
# getFOrder1 - get the "next" f_order for gene oid 
#
# This subrountine only check for on gene
############################################################################ 
sub getFOrder1 { 
    my ($dbh, $gene_oid) = @_;
 
    my %h; 
    my $f_order = 0; 
 
    #exec SQL
    my $sql = qq{ 
        select max(f_order)+1
            from gene_img_functions
            where gene_oid = $gene_oid
        }; 
 
    my $cur = $dbh->prepare( $sql ) ||
        return 0;
    $cur->execute( ) || 
        return 0; 
 
    for( ;; ) {
        my ( $fo ) = $cur->fetchrow( );
        last if !$fo;

        # get the next number
        $f_order = $fo; 
    }  # end for loop 
 
    return $f_order; 
} 
 

############################################################################
# getFOrder - get the "next" f_order for each gene oid
############################################################################
sub getFOrder {
    my ($dbh, @keys) = @_;

    my %h;

    my $f_order = -1;

    for my $k ( @keys ) {
	$f_order = -1;

	#exec SQL
	my $sql = qq{
	    select gene_oid, max(f_order)
		from gene_img_functions
		where gene_oid = $k
                group by gene_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $g_oid, $fo ) = $cur->fetchrow( );
	    last if !$g_oid;

	    # next number
	    $f_order = $fo + 1;
	}  # end for loop

	if ( $f_order > 0 ) {
	    $h{ $k } = $f_order;
	}

    }  #end for k loop

    return %h;
}


############################################################################
# getGeneProteinProduct - get protein product for genes
############################################################################
sub getGeneProteinProduct {
    my ($dbh, @keys) = @_;

    my %h;

    my $prod;

    for my $k ( @keys ) {
	$prod = "";

	#exec SQL
	my $rclause   = WebUtil::urClause('g.taxon');
	my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
	my $sql = qq{
	    select g.gene_oid, g.product_name
		from gene g
		where g.gene_oid = $k
		$rclause
		$imgClause
	    };

	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $g_oid, $pr ) = $cur->fetchrow( );
	    last if !$g_oid;

	    $prod = $pr;
	}  # end for loop

	# discard blanks, hypothetical, unknown or unnamed protein
	my $s = lc $prod;
	if ( isPseudo($s) ) {
	    # skip this one
	}
	else {
	    $h{ $k } = $prod;
	}

    }  #end for k loop

    return %h;
}


############################################################################
# dbUpdateGeneTerms - update gene term associations from the database
############################################################################
sub dbUpdateGeneTerms {
    my $gc = new GeneCartStor( );
    my $recs = $gc->readCartFile(); # get records

    my @gene_oids = sort{ $a <=> $b }keys( %$recs );
        # The keys for the records are gene_oids.
	# But we want them sorted.

    my @selected_gene_oids = param( "gene_oid" );
    my %selected_gene_oids_h;
    for my $gene_oid( @selected_gene_oids ) {
       $selected_gene_oids_h{ $gene_oid } = 1;
    }

    my $term_oid = param ( "termSelection" );

    # login
    my $dbh = dbLogin();

    # get f_order
    my %f_order = getFOrder ( $dbh, @selected_gene_oids );

    # prepare SQL
    my @sqlList = ();
    my $sql = "";
    my $ins = "";
    my $vals = "";

    for my $gene_oid ( @selected_gene_oids ) {
    	my $ar = param ("ar_" . $gene_oid);
    
    	if ( $ar eq 'replace' ) {
    	    # delete
    	    $sql = "delete from gene_img_functions where gene_oid = $gene_oid";
    	    push @sqlList, ( $sql );
    
    	}
    
    	# , evidence, confidence, modified_by)";

	my $sql2 = "select taxon, scaffold from gene where gene_oid = ?";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid );
	my ($taxon2, $scaffold2) = $cur2->fetchrow();
	$cur2->finish();
    
    	# insert
    	$ins = "insert into gene_img_functions (gene_oid, taxon, scaffold, function, f_order";
    	$vals = " values ($gene_oid, $taxon2, $scaffold2, $term_oid";
    	    
    	# f_order
    	my $next_order = 0;
    	if ( $ar ne 'replace' && $f_order{ $gene_oid } ) {
    	    $next_order = $f_order{$gene_oid};
    	}
    
    	$vals .= ", $next_order";
    
    	# evidence
    	my $ev = param ("ev_" . $gene_oid);
    	if ( $ev eq 'Experimental' ||
    	     $ev eq 'High' ||
    	     $ev eq 'Inferred' ) {
    	    $ins .= ", evidence";
    	    $vals .= ", '" . $ev . "'";
    	}
    
    	# confidence
    	my $cm = param ("cm_" . $gene_oid);
    	if ( $cm && !blankStr($cm) ) {
    	    $cm =~ s/'/''/g;
    	    $ins .= ", confidence";
    	    $vals .= ", '" . $cm . "'";
    	}
    
    	# cell_loc
    	my $cl = param ("cell_" . $gene_oid);
    	if ( $cl && !blankStr($cl) ) {
    	    $cl =~ s/'/''/g;
    	    $ins .= ", cell_loc";
    	    $vals .= ", '" . $cl . "'";
    	}
    
    	# modified by
    	if ( $contact_oid ) {
    	    $ins .= ", modified_by";
    	    $vals .= ", " . $contact_oid;
    	}
    
            # f_flag
    	$ins .= ", f_flag)";
    	$vals .= ", 'M')";
    
    	$sql = $ins . $vals;
    
    	push @sqlList, ( $sql );
    
    }   # end for gene_oid

    # update IMG Term to put Gene Protein Product into synonym
    my %protProduct = getGeneProteinProduct($dbh, @selected_gene_oids );
    $sql = "select term_oid, lower(synonyms) from img_term_synonyms where term_oid = $term_oid";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %syn;
    for( ;; ) {
	my( $term_oid, $synonym ) = $cur->fetchrow( );
	last if !$term_oid;

        $syn{$synonym} = $synonym;
    }

    my %new_syn;
    if ( $img_lite ) {
	# do nothing. don't update
    }
    else {
    	for my $k (keys %protProduct) {
    	    my $prod = $protProduct{$k};
    	    my $lc_prod = lc $prod;
    	    if ( $syn{$lc_prod} ) {
        		# already an synonym
    	    }
    	    elsif ( $new_syn{$lc_prod} ) {
        		# already in the inserts
    	    }
    	    else {
        		$prod =~ s/'/''/g;   # replace ' with ''
        		my $sql2 = "insert into IMG_TERM_SYNONYMS (term_oid, synonyms, modified_by)";
        		$sql2 .= " values (" . $term_oid . ", '" . $prod . "', " . $contact_oid . ")";
        
        		push @sqlList, ( $sql2 );
        
        		# add to new_syn
        		$new_syn{$lc_prod} = $lc_prod;
    	    }
    	}
    }

    ##$dbh->disconnect();

    # perform database update
    db_sqlTrans_2( @sqlList );
}


############################################################################
# dbDeleteGeneTerms - delete gene term associations from the database
############################################################################
sub dbDeleteGeneTerms {
    my @gene_term = param( "gene_term" );

    # prepare SQL
    my @sqlList = ();
    my $sql = "";

    my $dbh = dbLogin();
    for my $ids ( @gene_term ) {
    	my ($gene_oid, $term_oid) = split (/\|/, $ids);
    
    	# delete from synonym?
    	my ($found, $prod, $new_gene_oid) = checkGeneOid ( $dbh, $gene_oid );
    	if ( ! isPseudo($prod) ) {
    	    # we are going to use case-insensitive comparison
    	    # so change the product to lower case
    	    my $product = lc $prod;
    	    $product =~ s/'/''/g;   # replace ' with ''
    
    	    if ( ! $img_lite &&
    		 deleteGeneProdFromSynonym($dbh, $gene_oid, $product, $term_oid) ) {
        		$sql = "delete from IMG_TERM_SYNONYMS where term_oid = $term_oid ";
        		$sql .= "and lower(synonyms) = '" . $product . "' ";
        		push @sqlList, ( $sql );
    	    }
    	}
    
    	# delete from GENE_IMG_FUNCTIONS
    	$sql = "delete from GENE_IMG_FUNCTIONS where gene_oid = $gene_oid and function = $term_oid";
    	push @sqlList, ( $sql );
    
    }

    #$dbh->disconnect( );

#    for $sql ( @sqlList ) {
#	print "<p>SQL: $sql</p>\n";
#    }

    # perform database update
    db_sqlTrans_2( @sqlList );
}


############################################################################ 
# db_sqlTrans_2 - perform an SQL transaction 
############################################################################ 
sub db_sqlTrans_2 () { 
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
        ##$dbh->disconnect(); 
        webError ("Incorrect SQL: $last_sql"); 
        return 0; 
    } 
 
    $dbh->commit(); 
    ##$dbh->disconnect(); 
 
    return 1; 
} 

#############################################################################
# checkGeneOid - check whether the gene_oid exists
#                also return gene product
#############################################################################
sub checkGeneOid {
    my ( $dbh, $gene_oid ) = @_;

    my $found        = 0;
    my $prod         = "";
    my $new_gene_oid = "";

    if ( isInt($gene_oid) == 0 ) {
        return ( $found, $prod );
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.gene_oid, g.product_name 
        from gene g
        where g.gene_oid = ?
            $rclause
            $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );

    for ( ; ; ) {
        my ( $db_id, $db_val ) = $cur->fetchrow();
        last if !$db_id;

        $found        = 1;
        $prod         = $db_val;
        $new_gene_oid = $gene_oid;
    }

    if ($found) {
        return ( $found, $prod, $new_gene_oid );
    }

    # check GENE_REPLACEMENTS (IMG 2.0)
    $sql = WebUtil::getGeneReplacementSql();
    $cur = execSql( $dbh, $sql, $verbose, $gene_oid );

    for ( ; ; ) {
        my ($db_id) = $cur->fetchrow();
        last if !$db_id;

        $found        = 1;
        $new_gene_oid = $db_id;
    }

    if ( $found == 0 ) {
        return ( 0, $prod, $new_gene_oid );
    }

    # get gene product for $new_gene_oid
    $found = 0;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    $sql   = qq{
        select g.gene_oid, g.product_name 
        from gene g
        where g.gene_oid = ?
            $rclause
            $imgClause
    };
    $cur = execSql( $dbh, $sql, $verbose, $new_gene_oid );

    for ( ; ; ) {
        my ( $db_id, $db_val ) = $cur->fetchrow();
        last if !$db_id;

        $found = 1;
        $prod  = $db_val;
    }

    return ( $found, $prod, $new_gene_oid );
}


############################################################################
# findMaxID - find the max ID of a table 
############################################################################
sub findMaxID { 
    my ($dbh, $table_name, $attr_name) = @_;
 
    # SQL statement 
    my $sql = qq{
        select max($attr_name)
        from $table_name
    }; 
 
    my $cur = $dbh->prepare( $sql ) ||
        return 0; 
    $cur->execute( ) ||
        return 0; 
 
    my $max_id = 0; 
    for (;;) {
        my ( $val ) = $cur->fetchrow( );
        last if !$val;
 
        # set max ID
        $max_id = $val;
    }
 
    return $max_id;
} 


############################################################################# 
# deleteGeneProdFromSynonym - should we delete the gene product from
#       synonyms of this term $term_oid?
#
#       1 - if the term is not associated with any other genes
#           with the same product
#       0 - otherwise
#############################################################################
sub deleteGeneProdFromSynonym {
    my ($dbh, $gene_oid, $product, $term_oid) = @_;

    my $found = 0;

    #exec SQL
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
	select g.gene_oid
	    from gene g, gene_img_functions f
	    where f.function = $term_oid
	    and g.gene_oid = f.gene_oid
	    and f.gene_oid <> $gene_oid
	    and lower(g.product_name) = '$product'
            $rclause
            $imgClause
	};

    my $cur = execSql( $dbh, $sql, $verbose );

    for( ;; ) {
	my( $g_oid ) = $cur->fetchrow( );
	last if !$g_oid;

	$found = 1;
    }

    if ( $found ) {
	# don't delete
	return 0;
    }
    else {
	return 1;
    }
}


############################################################################# 
# isInDatabase 
#############################################################################
sub isInDatabase { 
    my ($dbh, $table_name, $attr_name, $cond_ref) = @_; 
 
    my $found = 0; 
    my $sql = qq{
        select $attr_name 
        from $table_name
    };

    my $where_and = " where ";
    for my $k (keys %$cond_ref) {
        $sql .= $where_and . $k . " = " . $cond_ref->{$k};
        $where_and = " and "; 
    } 
 
    my $cur = $dbh->prepare( $sql ) || 
        return 0; 
    $cur->execute( ) || 
        return 0; 
 
    for ( ;; ) { 
        my ( $db_val ) = $cur->fetchrow( ); 
        last if !$db_val; 
 
        $found = 1; 
    } 
 
    return $found; 
} 
 

############################################################################
# isPseudo 
############################################################################
sub isPseudo { 
    my $val = shift;
 
    my $s = lc $val;
 
    if ( blankStr($s) || 
         $s =~ /hypothetic/ || 
         $s =~ /predicted protein/ || 
         $s =~ /unknown/ || 
         $s =~ /unnamed/ ) { 
        return 1; 
    } 
 
    return 0;
} 

1;



