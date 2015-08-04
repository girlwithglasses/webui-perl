############################################################################
# ImgReaction - Process search and browsing for IMG reaction data.
#   imachen 12/08/2006
###########################################################################
package ImgReaction;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };

my $verbose = $env->{ verbose };

my $section = "ImgReaction";
my $section_cgi = "$main_cgi?section=$section";

############################################################################
# dispatch - Dispatch pages for this section.
#   All page links to this same section should be in the form of
#
#   my $url = "$main_cgi?section=$section&page=..." 
#
############################################################################
sub dispatch {

    my $page = param( "page" );

    if( $page eq "index" ) {
        printIndex( ); #root page
    }
    elsif( $page eq "searchResults" ) {
        printSearchResults( );
    }
    elsif( $page eq "browse" ) {
        printBrowse( );
    }
    elsif( $page eq "imgRxnDetail" ) {
	my $rxn_oid = param( "rxn_oid" );
        printImgRxnDetail( $rxn_oid );
    }
    elsif( param( "addToRxnCart" ) ne "" ) {
        print "<h1>Add to Reaction Cart</h1>\n";
    }
    else {
        print "<h1>Invalid Page: $page</h1>\n";
    }
}

############################################################################
# printIndex - Show root page.
############################################################################
sub printIndex {
    print "<h1>IMG Reaction Cart</h1>\n";
}

############################################################################
# printSearchResults 
############################################################################
sub printSearchResults {
    my( $searchTerm ) = @_;

    print "<h1>IMG Reaction Search Results</h1>\n";

    printMainForm();

    print "<p>Search IMG reactions with '" . escapeHTML($searchTerm) . "'.\n</p>";

    #  Get rid of preceding and lagging spaces. 
    #  Escape SQL quotes. 
    $searchTerm =~ s/^\s+//; 
    $searchTerm =~ s/\s+$//; 
    my $lc_term = lc ($searchTerm);

    # check whether there are matching IMG reactions in the database
    my $dbh = dbLogin( ); 

    my $oid_search;
    $oid_search = "rxn_oid = $lc_term or " if isInt($lc_term);
    
    my $sql = qq{ 
        select count(*)
        from IMG_REACTION 
        where $oid_search
        lower(rxn_name) like ? 
        or lower(rxn_definition) like ? 
    }; 
    #print "printSearchResults() sql:$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, "%$lc_term%", "%$lc_term%" ); 
    my $cnt = $cur->fetchrow( ); 
    $cur->finish( ); 
    if( $cnt == 0 ) {
    	print "<div id='message'>\n"; 
    	print "<p>\n"; 
    	print "No IMG Reactions found.\n";
    	print "</p>\n"; 
    	print "</div>\n"; 
    	#$dbh->disconnect(); 
    	return; 
    }

    ## --es 12/11/2006 Stage the next section for 
    #  when the submit button is hit.
    my $name = "_section_CuraCartStor_addReactionToCuraCart";
    print submit( -name => $name,
                  -value => 'Add Selected to Curation Cart', -class => 'lgdefbutton' );
 
    print nbsp( 1 ); 
    print "<input type='button' name='selectAll' value='Select All' " .
       "onClick='selectAllCheckBoxes(1)' class='smbutton' /> ";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " .
       "onClick='selectAllCheckBoxes(0)' class='smbutton' /> "; 
    print "<br/>\n";

    # search
    $sql = qq{ 
        select rxn_oid, rxn_name, rxn_definition
        from IMG_REACTION 
        where $oid_search
        lower(rxn_name) like '%$lc_term%' 
        or lower(rxn_definition) like '%$lc_term%' 
    }; 
    $cur = execSql( $dbh, $sql, $verbose ); 
    print "<p>\n";
    for (;;) {
	my ($rxn_oid, $rxn_name, $rxn_def) = $cur->fetchrow( );
	last if !$rxn_oid;

	$rxn_oid = FuncUtil::rxnOidPadded( $rxn_oid );
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

	# print rxn_def
	if ( $rxn_def ne "" ) {
	    print "<br/>\n";
	    my $matchText = highlightMatchHTML2( $rxn_def, $searchTerm ); 
            print nbsp( 7 );
            print "(Definition: $matchText)";
	}


	print "<br/>\n"; 
    }
    $cur->finish( ); 
    #$dbh->disconnect();

    print "<p>\n";

    if ( $cnt > 20 ) {
	# --es 12/11/2006
	# print cart footer
	my $name = "_section_CuraCartStor_addReactionToCuraCart";
	print submit( -name => $name,
	      -value => 'Add Selected to Curation Cart', -class => 'lgdefbutton' );
	print nbsp( 1 );
	print "<input type='button' name='selectAll' value='Select All' " .
	    "onClick='selectAllCheckBoxes(1)' class='smbutton' /> ";
	print nbsp( 1 );
	print "<input type='button' name='clearAll' value='Clear All' " .
	    "onClick='selectAllCheckBoxes(0)' class='smbutton' /> "; 
	print "<br/>\n";

      }

    print end_form();
}


############################################################################
# printBrowse - This is the "ImgReactionBrowser" function.
############################################################################
sub printBrowse {

    print "<h1>IMG Reaction Browser</h1>\n";

    printMainForm();

    # check whether there are IMG reactions in the database
    my $dbh = dbLogin( ); 
    my $sql = qq{ 
        select count(*) 
        from img_reaction 
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my $cnt = $cur->fetchrow( ); 
    $cur->finish( ); 
    if( $cnt == 0 ) { 
	print "<div id='message'>\n"; 
	print "<p>\n"; 
	print "This database has no IMG reactions.\n"; 
	print "</p>\n"; 
	print "</div>\n"; 
	#$dbh->disconnect(); 
	return; 
    }

    # print cart footer
    # --es 12/11/2006 Set up to go the the next section
    #   on the submit( ) button for this form.
    #   I use "addToImgRxnCart" so it can be inside
    #   ImgRxnCartStor in terms of naming.
    my $name = "_section_CuraCartStor_addReactionToCuraCart";
    print submit( -name => $name,
                  -value => 'Add Selected to Curation Cart', -class => 'lgdefbutton' );
    print nbsp( 1 );
    print "<input type='button' name='selectAll' value='Select All' " .
       "onClick='selectAllCheckBoxes(1)' class='smbutton' /> ";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " .
       "onClick='selectAllCheckBoxes(0)' class='smbutton' /> "; 
    print "<br/>\n";


    # prepare SQL
    $sql = "select rxn_oid, rxn_name from img_reaction";
    # $sql .= " where rownum < 100";
    $sql .= " order by rxn_name, rxn_oid";

    $cur = execSql( $dbh, $sql, $verbose ); 
    print "<p>\n";
    for (;;) {
	my ($rxn_oid, $rxn_name) = $cur->fetchrow( );
	last if !$rxn_oid;

	$rxn_oid = FuncUtil::rxnOidPadded( $rxn_oid );
	if ( !$rxn_name ) {
	    $rxn_name = "(null)";
	}

	# --es 12/11/2006
	print "<input type='checkbox' name='rxn_oid' value='$rxn_oid' />\n";

	my $url = "$main_cgi?section=$section&page=imgRxnDetail&rxn_oid=$rxn_oid"; 
	print nbsp( 1 ); 
	print alink( $url, $rxn_oid ); 
	print nbsp( 1 ); 
	print escapeHTML( $rxn_name ); 
	print "<br/>\n"; 
    }
    $cur->finish( ); 
    #$dbh->disconnect();

    print "<p>\n";

    # print cart footer
    # --es 12/11/2006
    my $name = "_section_CuraCartStor_addReactionToCuraCart";
    print submit( -name => $name,
                  -value => 'Add Selected to Curation Cart', -class => 'lgdefbutton' );
    print nbsp( 1 );
    print "<input type='button' name='selectAll' value='Select All' " .
       "onClick='selectAllCheckBoxes(1)' class='smbutton' /> ";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' " .
       "onClick='selectAllCheckBoxes(0)' class='smbutton' /> "; 
    print "<br/>\n";


    print end_form();
}


############################################################################ 
# printImgRxnDetail - Print details for one term. 
############################################################################ 
sub printImgRxnDetail { 
    my( $rxn_oid ) = @_; 
 
    my $rxn_oid_orig = $rxn_oid; 
 
    print "<h1>IMG Reaction Details</h1>\n"; 
    printMainForm( ); 
    printStatusLine( "Loading ...", 1 ); 
 
    $rxn_oid = sprintf( "%d", $rxn_oid ); 
 
    my $dbh = dbLogin( ); 
    my $sql = qq{ 
        select ir.rxn_oid, ir.rxn_name, ir.rxn_type, ir.rxn_definition, 
	   ir.rxn_equation, ir.is_reversible,
           ir.comments, to_char(ir.mod_date, 'yyyy-mm-dd'), to_char(ir.add_date, 'yyyy-mm-dd'), c.name, c.email 
        from img_reaction ir, contact c
        where ir.rxn_oid = $rxn_oid
        and ir.modified_by = c.contact_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $r_oid, $r_name, $r_type, $r_definition, $r_equation,
	$r_is_reversible, $r_comments,
        $mod_date, $add_date, $c_name, $email ) = $cur->fetchrow( );
    $cur->finish( );

    if( $r_oid eq "" ) {
        #$dbh->disconnect();
        printStatusLine( "Error.", 2 ); 
        webError( "Reaction $rxn_oid not found in this database." );
        return; 
    } 

    $r_oid = FuncUtil::rxnOidPadded( $r_oid );

    print "<h2>Reaction Information</h2>\n";
    print "<table class='img' border='1'>\n";
    printAttrRow( "Reaction Object ID", $r_oid );
    printAttrRow( "Reaction Name", $r_name ); 
    printAttrRow( "Reaction Type", $r_type );
    printAttrRow( "Definition", $r_definition );
    printAttrRow( "Equation", $r_equation );
    printAttrRow( "Is Reversible?", $r_is_reversible );
    printAttrRow( "Comments", $r_comments );
    printAttrRow( "Add Date", $add_date ); 
    printAttrRow( "Modify Date", $mod_date ); 
    my $s = escHtml( $c_name ) . emailLinkParen( $email );
    printAttrRowRaw( "Modified By", $s );

    # pathway
    printPathways($dbh, $rxn_oid);

    # compound
    printReactionCompounds($dbh, $rxn_oid);

    # terms
    printReactionTerms($dbh, $rxn_oid);

    print "</table>\n";

    #$dbh->disconnect(); 

    printStatusLine( "Loaded.", 2 ); 
    print end_form( ); 
} 


############################################################################
# printPathways - print associated pathways
############################################################################
sub printPathways {
    my( $dbh, $rxn_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Pathways</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
	select ipr.pathway_oid, p.pathway_name, ipr.rxn_order
	       from img_pathway_reactions ipr, img_pathway p
	       where ipr.rxn = $rxn_oid
	       and ipr.pathway_oid = p.pathway_oid
	       order by ipr.pathway_oid
	   };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $p_oid, $p_name, $r_order ) = $cur->fetchrow( );
	last if !$p_oid;
	$p_oid = FuncUtil::pwayOidPadded ($p_oid);
	my $url = "$main_cgi?section=ImgPwayBrowser" . 
	    "&page=imgPwayDetail&pway_oid=$p_oid";
	print alink( $url, $p_oid );
	print " " . escHtml($p_name) . " - (Reaction Order: $r_order)";
	print "<br/>\n";
    }
    $cur->finish( );
    print "</td>\n";
    print "</tr>\n";
}


############################################################################
# printReactionCompounds - Show compounds involved in the reaction
############################################################################
sub printReactionCompounds {
    my( $dbh, $rxn_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Compounds</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
	select ircc.compound, c.compound_name,
	       ircc.c_type, ircc.stoich, ircc.main_flag
	       from img_reaction_c_components ircc, img_compound c
	       where ircc.rxn_oid = ?
	       and ircc.compound = c.compound_oid
	       order by ircc.compound
	   };
    my $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    for( ;; ) {
	my( $compound, $c_name, $c_type, $stoich, $main_flag ) = $cur->fetchrow( );
	last if !$compound;
	$compound = sprintf("%06d", $compound);
	my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound";
	print alink( $url, $compound );
	print " " . escHtml($c_name);

	# main?
	if ( lc($main_flag) eq 'yes' ) {
	    print " - (Main)";
	}
	if ( !blankStr($stoich) ) {
	    print " - (Stoichiometry Value: $stoich)";
	}

	# LHS or RHS
	if ( !blankStr($c_type) ) {
	    print " - (" . escHtml( $c_type ) . ")";
	}

	print "<br/>\n";
    }
    $cur->finish( );
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printReactionTerms - Show terms associated the reaction
############################################################################
sub printReactionTerms {
    my( $dbh, $rxn_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Terms</th>\n";
    print "<td class='img'>\n";

    # IMG_REACTION_CATALYSTS
    my $sql = qq{
	select irc.catalysts, t.term
	       from img_reaction_catalysts irc, img_term t
	       where irc.rxn_oid = ?
	       and irc.catalysts = t.term_oid
	       order by irc.catalysts
	   };
    my $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    for( ;; ) {
	my( $term_oid, $term ) = $cur->fetchrow( );
	last if !$term_oid;

	$term_oid = FuncUtil::termOidPadded($term_oid);
        my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail&term_oid=$term_oid";
	print alink( $url, $term_oid );
	print " " . escapeHTML( $term ); 
	print " - (Catalyst)";
	print "<br/>\n";
    }
    $cur->finish( );

    # IMG_REACTION_T_COMPONENTS
    $sql = qq{
	select irtc.term, t.term, irtc.c_type
	       from img_reaction_t_components irtc, img_term t
	       where irtc.rxn_oid = ?
	       and irtc.term = t.term_oid
	       order by irtc.term
	   };
    $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    for( ;; ) {
	my( $term_oid, $term, $c_type ) = $cur->fetchrow( );
	last if !$term_oid;

	$term_oid = FuncUtil::termOidPadded($term_oid);
        my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail&term_oid=$term_oid";
	print alink( $url, $term_oid );
	print " " . escapeHTML( $term ); 
	if ( uc($c_type) eq "LHS" ) {
	    print " - (Substrate)";
	}
	elsif ( uc($c_type) eq "RHS" ) {
	    print " - (Product)";
	}
	print "<br/>\n";
    }
    $cur->finish( );

    print "</td>\n";
    print "</tr>\n";
}


1;
