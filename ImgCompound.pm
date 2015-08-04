############################################################################
# ImgCompound - Process search and browsing for IMG compound.
#   imachen 12/08/2006
#
# $Id: ImgCompound.pm 32248 2014-11-05 21:33:44Z klchu $
###########################################################################
package ImgCompound;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use CuraCartStor;
use InnerTable;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };

my $verbose = $env->{ verbose };

my $section = "ImgCompound";
my $section_cgi = "$main_cgi?section=$section";

#my $pubchem_base_url = "http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid="; 
my $pubchem_base_url = "http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?"; 


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
    elsif( $page eq "imgCpdDetail" ) {
	    my $compound_oid = param( "compound_oid" );
        printImgCpdDetail( $compound_oid );
    }
    else {
        print "<h1>Invalid Page: $page</h1>\n";
    }
}

############################################################################
# printIndex - Show root page.
############################################################################
sub printIndex {
    print "<h1>Under Construction</h1>\n";
}

############################################################################
# printSearchResults 
############################################################################
sub printSearchResults {
    my( $searchTerm ) = @_;

    print "<h1>IMG Compound Search Results</h1>\n";
    printMainForm();

    print "<p>Search IMG Compound (compound names, common names, and aliases) with '" . escapeHTML($searchTerm) . "'.\n</p>";

    #  Get rid of preceding and lagging spaces.
    #  Escape SQL quotes.
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//; 
    #my $lc_term = lc ($searchTerm);
    #$lc_term =~ s/'/''/g;  # replace ' with ''

    # check whether there are IMG compounds in the database
    my $dbh = dbLogin( ); 

    my $sid = getContactOid(); 
    my $can_edit = WebUtil::isImgEditor($dbh, $sid);

    my %compounds = searchCompound($dbh, $searchTerm);
    my @keys = keys( %compounds );
    my $cnt = scalar(@keys);

    if( $cnt == 0 ) { 
	print "<div id='message'>\n"; 
	print "<p>\n"; 
	print "No IMG compounds found.\n"; 
	print "</p>\n"; 
	print "</div>\n"; 
	#$dbh->disconnect(); 
	return; 
    }

    # print cart footer
    if ( $can_edit ) {
	my $name = "_section_CuraCartStor_addCompoundToCuraCart";
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

    print "<p>\n";

    for my $compound_oid ( @keys ) {
	my $compound_name = $compounds{$compound_oid};

	$compound_oid = FuncUtil::compoundOidPadded( $compound_oid );
	if ( !$compound_name ) {
	    $compound_name = "(null)";
	}

	if ( $can_edit ) {
	    print "<input type='checkbox' name='compound_oid' value='$compound_oid' />\n";
	}

	my $url = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$compound_oid"; 
	print nbsp( 1 ); 
	print alink( $url, $compound_oid ); 
	print nbsp( 1 ); 
	print $compound_name; 
	print "<br/>\n"; 
    }
    #$dbh->disconnect();

    print "<p>\n";

    # print cart footer
    if ( $cnt > 20 && $can_edit ) {
        my $name = "_section_CuraCartStor_addCompoundToCuraCart";
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
# printBrowse 
############################################################################
sub printBrowse {
    print "<h1>IMG Compound Browser</h1>\n";
    printMainForm();

    my $dbh = dbLogin( ); 

    # get pubchem compound id
    my %pubchem_id_h;
    my $sql = qq{ 
        select compound_oid, id
        from img_compound_ext_links
        where db_name = 'PubChem Compound'
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    for (;;) {
	my ($compound_oid, $pubchem_id) = $cur->fetchrow( ); 
	last if ! $compound_oid;

	$compound_oid = FuncUtil::compoundOidPadded( $compound_oid );
	$pubchem_id_h{$compound_oid} = $pubchem_id;
    }
    $cur->finish( ); 

    $sql = qq{
             select url_template from compound_ext_db\@img_ext
             where db_name = 'PubChem Compound'
           };
    $cur = execSql( $dbh, $sql, $verbose );
    my( $pubchem_url ) = $cur->fetchrow( );
    $cur->finish();

    my $sid = getContactOid(); 
    my $can_edit = WebUtil::isImgEditor($dbh, $sid);

    # print cart footer
    if ( $can_edit ) {
	my $name = "_section_CuraCartStor_addCompoundToCuraCart";
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

    my $it = new InnerTable( 1, "imgCompound$$", "imgCompound", 1 ); 
    if ( $can_edit ) {
	$it->addColSpec("Select"); 
    }
    $it->addColSpec( "Compound OID",   "number asc", "right" ); 
    $it->addColSpec( "Compound Name",   "char asc", "left" ); 
    $it->addColSpec( "PubChem CID",   "number asc", "right" ); 
    $it->addColSpec( "DB Source", "char asc", "left" ); 
    $it->addColSpec( "Ext Accession", "char asc", "left" ); 
    $it->addColSpec( "Formula", "char asc", "left" ); 
    $it->addColSpec( "CAS Number", "char asc", "left" ); 
    my $sd = $it->getSdDelim(); 
    my $row = 0;

    # prepare SQL
    $sql = qq{
           select compound_oid, compound_name, db_source, ext_accession, 
                  formula, cas_number
           from img_compound
           };

    $cur = execSql( $dbh, $sql, $verbose ); 
    print "<p>\n";
    for (;;) {
	my ($compound_oid, $compound_name, $db_source, $ext_accession,
	    $formula, $cas_number) = $cur->fetchrow( );
	last if !$compound_oid;

	$compound_oid = FuncUtil::compoundOidPadded( $compound_oid );
	if ( !$compound_name ) {
	    $compound_name = "(null)";
	}

	my $r = "";
	if ( $can_edit ) {
	    $r = $sd .
		"<input type='checkbox' name='compound_oid' value='$compound_oid' />\t";
	}

	my $url = "$main_cgi?section=$section&page=imgCpdDetail&compound_oid=$compound_oid"; 
	$r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
	$r .= $compound_name . $sd . $compound_name . "\t";

	my $pubchem_id = $pubchem_id_h{$compound_oid};
	my $p_url = $pubchem_id;
	if ( $pubchem_url ) {
	    $p_url = alink($pubchem_url . $pubchem_id, $pubchem_id);
	}
	$r .= $pubchem_id . $sd . $p_url . "\t";

	$r .= $db_source . $sd . $db_source . "\t";

	my ($ex1, $ex2) = split(/\:/, $ext_accession);
	if ( uc($ex1) eq 'CHEBI' && isInt($ex2) ) {
	    my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" .
		$ex2;
	    $r .= $ext_accession . $sd . alink($url3, $ext_accession) . "\t";
	}
	elsif ( uc($db_source) eq 'KEGG LIGAND' ) {
	    my $url3 = "http://www.kegg.jp/entry/" . $ext_accession;
	    $r .= $ext_accession . $sd . alink($url3, $ext_accession) . "\t";
	}
	elsif ( uc($db_source) eq 'PUBCHEM:SID' ) {
	    my $url3 = $pubchem_base_url . "sid=" . $ext_accession;
	    $r .= $ext_accession . $sd . alink($url3, $ext_accession) . "\t";
	}
	elsif ( uc($db_source) =~ /PUBCHEM/ ) {
	    my $url3 = $pubchem_base_url . "cid=" . $ext_accession;
	    $r .= $ext_accession . $sd . alink($url3, $ext_accession) . "\t";
	}
	else {
	    $r .= $ext_accession . $sd . $ext_accession . "\t";
	}
	$r .= $formula . $sd . $formula . "\t";
	$r .= $cas_number . $sd . $cas_number . "\t";
	$it->addRow($r);
	$row++;
    }
    $cur->finish( ); 
    #$dbh->disconnect();

    if ( $row ) {
	$it->printOuterTable(1); 
    }
    printStatusLine( "$row rows loaded", 2 );

    print "<p>\n";

    # print cart footer
    if ( $row && $can_edit ) {
	my $name = "_section_CuraCartStor_addCompoundToCuraCart";
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
# printImgCpdDetail - Print details for one compound.
############################################################################ 
sub printImgCpdDetail { 
    my( $compound_oid ) = @_; 
 
    printMainForm( ); 
    printStatusLine( "Loading ...", 1 ); 

    print "<h1>IMG Compound Details</h1>\n"; 
    #print hiddenVar('func_id', "ICMPD:$compound_oid");
 
    my $compound_oid_orig = $compound_oid; 
    $compound_oid = sprintf( "%d", $compound_oid ); 
 
    my $dbh = dbLogin( ); 
    my $sql = qq{
        select ic.compound_oid, ic.compound_name, ic.common_name,
	   ic.ext_accession, ic.db_source, ic.class, ic.composition,
	   ic.formula, ic.cas_number, ic.status,
           to_char(ic.mod_date, 'yyyy-mm-dd'), to_char(ic.add_date, 'yyyy-mm-dd'), 
           c.name, c.email,
           ic.mol_weight, ic.num_atoms, ic.num_bonds,
           ic.np_class, ic.np_sub_class,
           ic.smiles, ic.inchi, ic.inchi_key
        from img_compound ic, contact c
        where ic.compound_oid = ?
        and ic.modified_by = c.contact_oid
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    my( $cpd_oid, $cpd_name, $common_name, $ext_acc, $db_src, $cl,
	$comp, $formula, $cas, $status,
        $mod_date, $add_date, $c_name, $email,
	$mol_weight, $num_atoms, $num_bonds,
	$np_class, $np_sub_class,
	$smiles, $inchi, $inchi_key) = $cur->fetchrow( );
    $cur->finish( );

    if( $cpd_oid eq "" ) {
        #$dbh->disconnect();
        printStatusLine( "Error.", 2 ); 
        webError( "Compound $compound_oid not found in this database." );
        return; 
    } 

    $cpd_oid = FuncUtil::compoundOidPadded( $cpd_oid );

    my @names = ();
    print "<h2>Compound Information</h2>\n";
    print "<table class='img' border='1'>\n";
    printAttrRow( "Compound Object ID", $cpd_oid );
    printAttrRow( "Compound Name", $cpd_name ); 
    if ( $cpd_name ) {
    	push @names, ( $cpd_name );
    }
    printAttrRow( "Common Name", $common_name );
    if ( $common_name ) {
    	push @names, ( $common_name );
    }

    my $chebi_id;
    my $ligand_id;
    my ($ex1, $ex2) = split(/\:/, $ext_acc);
    if ( uc($ex1) eq 'CHEBI' && isInt($ex2) ) {
    	my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" .
	    $ex2;
    	printAttrRowRaw( "Ext Accession", alink($url3, $ext_acc) );
    	$chebi_id = $ex2;
    }
    elsif ( uc($db_src) eq 'KEGG LIGAND' ) {
    	my $url3 = "http://www.kegg.jp/entry/" . $ext_acc;
    	printAttrRowRaw( "Ext Accession", alink($url3, $ext_acc) );
    	$ligand_id = $ext_acc;
    }
    else {
    	printAttrRow( "Ext Accession", $ext_acc );
    }

    printAttrRow( "DB Source", $db_src );
    printAttrRow( "Class", $cl );
    printAttrRow( "Composition", $comp );
    printAttrRow( "Formula", $formula );
    printAttrRow( "CAS Number", $cas );
    printAttrRow( "Status", $status );

    if ( $mol_weight ) {
	printAttrRow( "Mol. Weight", $mol_weight );
    }
    if ( $num_atoms ) {
	printAttrRow( "Num of Atoms", $num_atoms );
    }
    if ( $num_bonds ) {
	printAttrRow( "Num of Bonds", $num_bonds );
    }
    if ( $np_class ) {
	printAttrRow( "NP Class", $np_class );
    }
    if ( $np_sub_class ) {
	printAttrRow( "NP Subclass", $np_sub_class );
    }
    if ( $smiles ) {
	printAttrRow( "SMILES", $smiles );
    }
    if ( $inchi ) {
	printAttrRow( "InChI", $inchi );
    }
    if ( $inchi_key ) {
	printAttrRowInchiKey( "InChI Key", $inchi_key );
    }

    printAttrRow( "Add Date", $add_date ); 
    printAttrRow( "Modify Date", $mod_date ); 
    my $s = escHtml( $c_name ) . emailLinkParen( $email );
    printAttrRowRaw( "Modified By", $s );

    # aliases
    printAliases( $dbh, $compound_oid, \@names);

    # print mesh tree
    printMeshTree ($dbh, $compound_oid);

    printMeshTreeJson($compound_oid);

    # SM activity
#    printNpActivity ($dbh, $compound_oid);
    printMeshTree ($dbh, $compound_oid, 1);

    printMeshTreeJsonAct($compound_oid);

    # ext links
    printCompoundExtLinks ( $dbh, $compound_oid );

    # KEGG compound info
#    printKeggCompounds( $dbh, $compound_oid);

    # MetaCyc compounds
#    matchMetaCycCompound($dbh, $chebi_id, $ligand_id, \@names, 1);

    # reactions
    printReactions( $dbh, $compound_oid);

    # pathways
    my $p_cnt = printPathways( $dbh, $compound_oid);

    # print NP
    findNaturalProd($dbh, $compound_oid, 1);

printAttrRowInchiKeyImage($inchi_key) if ( $inchi_key );


    print "</table>\n";

    #$dbh->disconnect(); 

    if ( $p_cnt ) {
        my $name = "_section_FuncCartStor_addToFuncCart"; 
        print submit( 
              -name  => $name, 
              -value => "Add to Function Cart", 
              -class => "meddefbutton" 
        ); 
    	print nbsp(1); 
    	print "<input type='button' name='selectAll' value='Select All' " 
    	    . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n"; 
    	print nbsp(1); 
    	print "<input type='button' name='clearAll' value='Clear All' " 
    	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 
    	print "<p>\n";
    }

    my $sid = getContactOid(); 
    my $can_edit = WebUtil::isImgEditor($dbh, $sid);
    if ( $can_edit ) {
	print "<p>\n";
	$compound_oid = FuncUtil::compoundOidPadded( $compound_oid );
	print hiddenVar('compound_oid', $compound_oid );
	my $name = "_section_CuraCartStor_addCompoundToCuraCart";
	print submit( 
	   -name => $name,
       -value => 'Add Compound to Curation Cart', 
       -class => 'lgdefbutton' );
    }

    printStatusLine( "Loaded.", 2 ); 
    print end_form( ); 
} 

sub printAttrRowInchiKeyImage {
    my ( $attrVal ) = @_;
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Chemical Structure</th>\n";
    my $val = attrValue($attrVal);
    print "  <td class='img' align='left'>" ;
    
    print qq{
      <img src='http://cactus.nci.nih.gov/chemical/structure/InChIKey=$val/image' alt="Inchi key $val"  style="height:175px; vertical-align:middle;">
      <i>Image from <a href='http://cactus.nci.nih.gov/'>NCI/CADD</a>.
      Source 
      <a href='http://cactus.nci.nih.gov/chemical/structure/InChIKey=$val/image'>url</a></i>.  
    };
    
    print "  </td>\n";
    print "</tr>\n";
}



sub printAttrRowInchiKey {
    my ( $attrName, $attrVal ) = @_;
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>$attrName</th>\n";
    my $val = attrValue($attrVal);
    print "  <td class='img'   align='left'>" . "<a href='http://cactus.nci.nih.gov/chemical/structure/InChIKey=$val/image'>$val</a>" ;
    
#    print qq{
#      &nbsp;&nbsp; <img src='http://cactus.nci.nih.gov/chemical/structure/InChIKey=$val/image' alt="Inchi key $val"  height="200px" align="middle" >
#      <br>
#      <i>Image from <a href='http://cactus.nci.nih.gov/'>NCI/CADD</a>.
#      Source 
#      <a href='http://cactus.nci.nih.gov/chemical/structure/InChIKey=$val/image'>url</a></i>.  
#    };
    
    print "  </td>\n";
    print "</tr>\n";
}

# mesh tree via json ajax
sub printMeshTreeJson {
    my ($compound_oid) = @_;
    
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Mesh Classification Tree</th>\n";
    print "<td class='img'>\n";
    
    require MeshTree;
    MeshTree::printTreeOneDiv($compound_oid);

    print "</td>\n"; 
    print "</tr>\n";     
}

# mesh tree via json ajax
sub printMeshTreeJsonAct {
    my ($compound_oid) = @_;
    
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Activity Tree</th>\n";
    print "<td class='img'>\n";
    
    require MeshTree;
    MeshTree::printTreeActDiv($compound_oid);

    print "</td>\n"; 
    print "</tr>\n";     
}


############################################################################ 
# searchCompound - search IMG compound using a keyword
############################################################################
sub searchCompound {
    my( $dbh, $searchTerm ) = @_;

    my %compounds;

    #  Escape SQL quotes.
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//; 
    my $lc_term = lc ($searchTerm);
    $lc_term =~ s/'/''/g;  # replace ' with ''

    my $oid_search;
    $oid_search = "compound_oid = $lc_term or " if isInt($lc_term);

    # prepare SQL
    my $sql = qq{ 
	select compound_oid, compound_name, common_name
	    from img_compound
	    where $oid_search
	    lower(compound_name) like '%$lc_term%'
	    or lower(common_name) like '%$lc_term%'
	    or compound_oid in
	       (select ica.compound_oid
		from img_compound_aliases ica
		where lower(aliases) like '%$lc_term%')
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $cpd_oid, $cpd_name, $comm_name ) = $cur->fetchrow( );
        last if !$cpd_oid;

	my $matchText = highlightMatchHTML2( $cpd_name, $searchTerm );
	if ( !blankStr($comm_name) ) {
	    $matchText .= "<br/>" . nbsp(7) . " (Common Name: " .
		highlightMatchHTML2( $comm_name, $searchTerm ) .
		")";
	}

	$compounds{$cpd_oid} = $matchText;
    } 
    $cur->finish( );

    return %compounds;
} 


############################################################################ 
# printAliases - show compound aliases
############################################################################
sub printAliases {
    my( $dbh, $compound_oid, $name_aref ) = @_;
 
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Aliases</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
        select ica.aliases
               from img_compound_aliases ica
               where ica.compound_oid = ?
               order by ica.aliases
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $alias ) = $cur->fetchrow( );
        last if !$alias;
        print escHtml( $alias );

	if ( $name_aref ) {
	    push @$name_aref, ( $alias );
	}

        print "<br/>\n";
    } 
    $cur->finish( );
    print "</td>\n"; 
    print "</tr>\n"; 
} 


############################################################################ 
# printMeshTree
#
# type: 0 -> classification, 1 -> activity
############################################################################
sub printMeshTree{
    my( $dbh, $compound_oid, $type ) = @_;

    # SQL to get node name
    my $sql2 = "select md.name from mesh_dtree md where md.node = ?";
    my $table_name = "img_compound_meshd_tree";
    my $attr_name = "node";
    if ( $type ) {
	$table_name = "img_compound_activity";
	$attr_name = "activity";
    }

    my @nodes = ();

    my $sql = qq{
        select icmt.compound_oid, icmt.$attr_name, md.name
               from $table_name icmt,
                    mesh_dtree md
               where compound_oid = ?
               and md.node = icmt.$attr_name
               order by 1, 2
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $id2, $n, $m ) = $cur->fetchrow( );
        last if !$id2;

	push @nodes, ( $n );
    } 
    $cur->finish( );

    my $label = "MeSH Classification";
    if ( $type ) {
	$label = "Activity";
    }

    if ( scalar(@nodes) > 0 ) {
	print "<tr class='img'>\n";
	print "<th class='subhead' align='right'>$label</th>\n";
	print "<td class='img'>\n";

	print "<ul>\n";
	for my $n ( @nodes ) {
	    print "<li>\n";
	    my @levels = split(/\./, $n);
	    my $id = "";
	    for my $n2 ( @levels ) {
		if ( $id ) {
		    print " - ";
		    $id .= "." . $n2;
		}
		else {
		    $id = $n2;
		}

		my $cur2 = execSql( $dbh, $sql2, $verbose, $id );
		my ($node_name) = $cur2->fetchrow();
		$cur2->finish();

		print "$node_name ($id)";
	    }
	    print "</li>\n";
	}
	print "</ul>\n";
	print "</td>\n"; 
	print "</tr>\n"; 
    }
} 


############################################################################ 
# printNpActivity
############################################################################
sub printNpActivity {
    my( $dbh, $compound_oid ) = @_;
 
    my @activities = ();

    my $sql = qq{
        select compound_oid, activity
               from img_compound_activity
               where compound_oid = ?
               order by 1, 2
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $id2, $act ) = $cur->fetchrow( );
        last if !$id2;

	push @activities, ( $act );
    } 
    $cur->finish( );

    if ( scalar(@activities) > 0 ) {
	print "<tr class='img'>\n";
	print "<th class='subhead' align='right'>NP Activity</th>\n";
	print "<td class='img'>\n";

	for my $act ( @activities ) {
	    print $act . "<br/>\n";
	}
	print "</td>\n"; 
	print "</tr>\n"; 
    }
} 


############################################################################ 
# printCompoundExtLinks
############################################################################
sub printCompoundExtLinks {
    my( $dbh, $compound_oid ) = @_;

    my %url_h;
    my $sql = qq{
        select db_name, url_template
               from compound_ext_db\@img_ext
               where url_template is not null
           };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $db_name, $url_template ) = $cur->fetchrow( );
        last if !$db_name;

	$db_name = lc($db_name);
	$url_h{$db_name} = $url_template;
    }
    $cur->finish();
 
    my $sql = qq{
        select icel.compound_oid, icel.db_name, icel.id
               from img_compound_ext_links icel
               where icel.compound_oid = ?
               order by icel.db_name
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $c_id, $db_name, $id2 ) = $cur->fetchrow( );
        last if !$c_id;

	print "<tr class='img'>\n";
	print "<th class='subhead' align='right'>$db_name</th>\n";

	$db_name = strTrim($db_name);
	$id2 = strTrim($id2);
	print "<td class='img'>";
	my $lc_db_name = lc($db_name);
	if ( $url_h{$lc_db_name} ) {
	    my $url2 = $url_h{$lc_db_name} . $id2;
	    print alink($url2, $id2);
	}
	elsif ( uc($db_name) eq 'METACYC' ) {
	    my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$id2";
	    print alink($url2, $id2);
	}
	else {
	    print $id2;
	}
	print "</td>\n";

	print "</tr>\n"; 	
    } 
    $cur->finish( );
} 


#################################################################################
# matchMetaCycCompound
#################################################################################
sub matchMetaCycCompound {
    my ($dbh, $chebi_id, $ligand_id, $name_aref, $print) = @_;

    my %compound_h;

    if ( $chebi_id ) {
    	## remove CHEBI: if any
    	if ( uc($chebi_id) =~ /^CHEBI/ ) {
    	    my ($tag, $val) = split(/\:/, $chebi_id);
    	    $chebi_id = strTrim($val);
    	}

    	my $sql = "select c.unique_id, c.common_name " .
    	    "from biocyc_comp c, biocyc_comp_ext_links el ";
    	$sql .= "where el.db_name = 'CHEBI' and el.id = ? ";
    	$sql .= "and el.unique_id = c.unique_id";
        #print "matchMetaCycCompound() chebi_id=$chebi_id sql: $sql<br/>\n";
        
    	my $cur = execSql( $dbh, $sql, $verbose, $chebi_id );
    	for (;;) {
    	    my ( $id3, $name3 ) = $cur->fetchrow();
    	    last if ! $id3;
    
    	    $compound_h{$id3} = $name3;
    	}
    	$cur->finish();
    }

    if ( $ligand_id ) {
    	my $sql = "select c.unique_id, c.common_name " .
    	    "from biocyc_comp c, biocyc_comp_ext_links el ";
    	$sql .= "where el.db_name = 'LIGAND-CPD' and el.id = ? ";
    	$sql .= "and el.unique_id = c.unique_id";
        #print "matchMetaCycCompound() ligand_id=$ligand_id sql: $sql<br/>\n";

    	my $cur = execSql( $dbh, $sql, $verbose, $ligand_id );
    	for (;;) {
    	    my ( $id3, $name3 ) = $cur->fetchrow();
    	    last if ! $id3;
    
    	    $compound_h{$id3} = $name3;
    	}
    	$cur->finish();
    }

    my $name_str = "";
    my $cnt = 0;
    for my $name ( @$name_aref ) {
    	$cnt++;
    	if ( $cnt > 1000 ) {
    	    last;
    	}
    
    	$name = lc($name);
    	$name =~ s/'/''/g;    # replace ' with ''
    	if ( $name_str ) {
    	    $name_str .= ", '" . $name . "'";
    	}
    	else {
    	    $name_str = "'" . $name . "'";
    	}
    }

    if ( $name_str ) {
    	my $sql = "select c.unique_id, c.common_name from biocyc_comp c ";
    	$sql .= "where lower(c.common_name) in (" . $name_str . ") ";
    	$sql .= "or lower(c.systematic_name) in (" . $name_str . ") ";
    	$sql .= "or c.unique_id in (select a.unique_id from biocyc_comp_synonyms a ";
    	$sql .= " where lower(a.synonyms) in (" . $name_str . ")) ";
        #print "matchMetaCycCompound() sql: $sql<br/>\n";
    
    	my $cur = execSql( $dbh, $sql, $verbose );
    	for (;;) {
    	    my ( $id3, $name3 ) = $cur->fetchrow();
    	    last if ! $id3;
    
    	    $compound_h{$id3} = $name3;
    	}
    	$cur->finish();
    }

    if ( $print ) {
    	my @keys = (keys %compound_h);
    	if ( scalar(@keys) > 0 ) {
    	    print "<tr class='img'>\n";
    	    print "<th class='subhead' align='right'>MetaCyc Compounds</th>\n";
    	    print "<td class='img'>\n";
    	    for my $key ( @keys ) {
        		my $compound_name = $compound_h{$key};
        
        		my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$key";
        		print alink($url2, $key);
        		print " (" . $compound_name . ")"; 
        		print "<br/>\n";
    	    } 
    	    print "</td>\n"; 
    	    print "</tr>\n"; 
    	}
    }

    return %compound_h;
}

############################################################################
# findNaturalProd
############################################################################
sub findNaturalProd {
    my ($dbh, $compound_oid, $print) = @_;

    my %np_h;
    my %bio_h;
    my %taxon_h;
#    my $sql = qq{
#        select np.np_id, np.np_product_name, np.taxon, 
#               np.cluster_id, bio.taxon
#        from natural_product np, bio_cluster_new bio
#        where np.compound_oid = ?
#        and (np.taxon is not null or np.cluster_id is not null) 
#        and np.cluster_id = bio.cluster_id (+)
#        order by 1
#    };

    my $rclause = WebUtil::urClause('np.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('np.taxon_oid');
    my $sql = qq{
        select np.rowid, np.taxon_oid,
               np.cluster_id, bio.taxon
        from np_biosynthesis_source np, bio_cluster_new bio
        where np.compound_oid = ?
        and (np.taxon_oid is not null or np.cluster_id is not null) 
        $rclause
        $imgClause
        and np.cluster_id = bio.cluster_id (+)
        order by 1
    };

    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for (;;) {
	my ( $id3, $taxon_oid, $bio_id, $bio_taxon ) = $cur->fetchrow();
	last if ! $id3;

	$np_h{$id3} = $id3;
	if ( $taxon_oid ) {
	    $taxon_h{$id3} = $taxon_oid;
	}
	if ( $bio_id ) {
	    $bio_h{$id3} = $bio_id;
	    if ( $bio_taxon ) {
		$taxon_h{$id3} = $bio_taxon;
	    }
	}
    }
    $cur->finish();

    if ( $print ) {
	my @keys = (keys %np_h);
	if ( scalar(@keys) > 0 ) {
	    print "<tr class='img'>\n";
	    print "<th class='subhead' align='right'>Secondary Metabolite Source(s)</th>\n";
	    print "<td class='img'>\n";
	    for my $key ( @keys ) {
#		my $name = $np_h{$key};

#		my $url2 = "main.cgi?section=NaturalProd&page=naturalProd&np_id=$key";
#		print alink($url2, $key);
#		print " (" . escHtml($name) . "): "; 

		if ( $taxon_h{$key} ) {
		    my $tid = $taxon_h{$key};
		    my $taxon_name = taxonOid2Name($dbh, $tid);
		    my $url3 = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$tid";
		    print alink($url3, $taxon_name);
		}

		if ( $bio_h{$key} ) {
		    my $url3 = "main.cgi?section=BiosyntheticDetail&page=cluster_detail";
		    if ( $taxon_h{$key} ) {
			$url3 .= "&taxon_oid=" . $taxon_h{$key};
			}
		    $url3 .= "&cluster_id=" . $bio_h{$key};
		    print " (Biosynthetic Cluster " . 
			alink($url3, $bio_h{$key}) . ")";
		}
		print "<br/>\n";
	    } 
	    print "</td>\n"; 
	    print "</tr>\n"; 
	}
    }

    return %np_h;
}


############################################################################ 
# printKeggCompounds - Show associated KEGG compound
############################################################################
sub printKeggCompounds {
    my( $dbh, $compound_oid ) = @_;
 
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>KEGG Compounds</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
        select ickc.compound, c.compound_name
               from img_compound_kegg_compounds ickc, compound c
               where ickc.compound_oid = ?
	       and ickc.compound = c.ext_accession
               order by ickc.compound
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $kegg_compound, $compound_name ) = $cur->fetchrow( );
        last if !$kegg_compound;

	my $url2 = "http://www.kegg.jp/entry/" . $kegg_compound;
#	print escHtml( $kegg_compound );
	print alink($url2, $kegg_compound);
        print " (" . escHtml($compound_name) . ")"; 
        print "<br/>\n";
    } 
    $cur->finish( );
    print "</td>\n"; 
    print "</tr>\n"; 
} 


############################################################################ 
# printReactions - Show associated reactions
############################################################################
sub printReactions {
    my( $dbh, $compound_oid ) = @_;
 
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Reactions</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
        select ircc.rxn_oid, r.rxn_name,
               ircc.c_type, ircc.stoich, ircc.main_flag
               from img_reaction_c_components ircc, img_reaction r
               where ircc.compound = ?
               and ircc.rxn_oid = r.rxn_oid
               order by ircc.rxn_oid
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for( ;; ) {
        my( $rxn_oid, $rxn_name, $c_type, $stoich, $main_flag ) = $cur->fetchrow( );
        last if !$rxn_oid; 
	    $rxn_oid = FuncUtil::rxnOidPadded ($rxn_oid);
        my $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$rxn_oid"; 
        print alink( $url, $rxn_oid );
        print " (" . escHtml($rxn_name) . ")"; 

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
# printPathways - Show associated pathways
############################################################################
sub printPathways {
    my( $dbh, $compound_oid ) = @_;
 
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Pathways</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
        select distinct p.pathway_oid, p.pathway_name
               from img_reaction_c_components ircc, img_pathway_reactions ipr, img_pathway p
               where ircc.compound = ?
               and ircc.rxn_oid = ipr.rxn
               and ipr.pathway_oid = p.pathway_oid
               order by p.pathway_oid
           };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    my $p_cnt = 0;
    for( ;; ) {
        my( $p_oid, $p_name ) = $cur->fetchrow( );
        last if !$p_oid; 
	$p_cnt++;
        $p_oid = FuncUtil::pwayOidPadded ($p_oid);
	my $pway_oid = "IPWAY:" . $p_oid;
	print "<input type='checkbox' name='func_id' value='$pway_oid' />\n";
        my $url = "$main_cgi?section=ImgPwayBrowser" .
            "&page=imgPwayDetail&pway_oid=$p_oid";
        print alink( $url, $p_oid );
        print " " . escHtml($p_name);
        print "<br/>\n"; 
    } 
    $cur->finish( );
    print "</td>\n"; 
    print "</tr>\n"; 

    return $p_cnt;
} 


1;
