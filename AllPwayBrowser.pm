########################################################################### 
# AllPwayBrowser.pm - Browser module for all IMG pathways
# $Id: AllPwayBrowser.pm 33566 2015-06-11 10:47:36Z jinghuahuang $
############################################################################ 
package AllPwayBrowser; 
use strict; 

use CGI qw( :standard ); 
use GD;
use Data::Dumper; 

use InnerTable; 
use GeneDetail; 
use PhyloTreeMgr; 
use WebConfig; 
use WebUtil; 
use HtmlUtil; 
use DataEntryUtil; 
use FuncUtil;
use TaxonList; 

my $section = "AllPwayBrowser";  
my $env                  = getEnv(); 
my $main_cgi             = $env->{main_cgi}; 
my $section_cgi          = "$main_cgi?section=$section"; 
my $verbose              = $env->{verbose}; 
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir}; 
my $max_gene_batch       = 100; 
my $max_taxon_batch      = 20;
my $max_scaffold_batch   = 20; 
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $tab_panel            = $env->{tab_panel};
my $content_list         = $env->{content_list};
my $mpw_pathway          = $env->{mpw_pathway};
my $all_pathway          = $env->{all_pathway};
my $tmp_dir              = $env->{tmp_dir}; 
my $tmp_url              = $env->{tmp_url}; 
my $enzyme_base_url      = $env->{enzyme_base_url};

my $use_cache = 0;
 
############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch { 
    my $page = param("page");
    if ( $page eq "allPwayBrowser" ) {
	if ( $use_cache ) {
	    HtmlUtil::cgiCacheInitialize( $section );
	    HtmlUtil::cgiCacheStart() or return;
	}
        printAllPwayMain(); 

	if ( $use_cache ) {
	    HtmlUtil::cgiCacheStop();
        }
    } elsif ( $page eq "searchAllPathways" ||
	      paramMatch("searchAllPathways") ne "" ) {
        SearchAllPathways(); 
    } elsif ( $page eq "searchAllCompounds" ||
	      paramMatch("searchAllCompounds") ne "" ) {
        SearchAllCompounds(); 
    } else { 
        my $sid = 0; 
    	if ( $use_cache ) {
    	    HtmlUtil::cgiCacheInitialize( $section ); 
    	    HtmlUtil::cgiCacheStart() or return; 
    	}
        printAllPwayMain(); 
    	if ( $use_cache ) {
    	    HtmlUtil::cgiCacheStop();
        }
    } 
} 

sub printJavaScript { 
    print qq{ 
    <script> 
	function selectAllCheckBoxes3( x ) { 
	    var f = document.mainForm3; 
	    for( var i = 0; i < f.length; i++ ) { 
		var e = f.elements[ i ]; 
               if( e.name == "mviewFilter" ) 
                   continue; 
		if( e.type == "checkbox" ) { 
		    e.checked = ( x == 0 ? false : true );
		} 
	    } 
	} 
    </script> 
    }; 
} 

############################################################################ 
# printAllPwayMain - main page
############################################################################ 
sub printAllPwayMain { 
    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo
            ("Search Pathways", "", "", "", 1);
    } else { 
        WebUtil::printHeaderWithInfo
            ("Search Pathways", "");
    } 

    print "<h2>All Pathways in IMG</h2>\n"; 
    printStatusLine( "Loading ...", 1 ); 
    printMainForm();

    my $dbh = dbLogin(); 

    # IMG pathways
    my $sql = qq{
    	select count(*) from img_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my ( $img_cnt ) = $cur->fetchrow();
    $cur->finish();

    # KEGG pathways
    $sql = qq{
    	select count(*) from kegg_pathway
    };
    $cur = execSql( $dbh, $sql, $verbose ); 
    my ( $kegg_cnt ) = $cur->fetchrow();
    $cur->finish();

    # MetaCyc pathways
    my $metacyc_cnt = 0;
    $sql = qq{
    	select count(*) from biocyc_pathway
    };
    $cur = execSql( $dbh, $sql, $verbose ); 
    ( $metacyc_cnt ) = $cur->fetchrow();
    $cur->finish();
    
    # MPW pathways
    my $mpw_cnt = 0;
    if ( $mpw_pathway ) {
    	$sql = qq{
    	    select count(*) from mpw_pgl_pathway
    	};
    	$cur = execSql( $dbh, $sql, $verbose ); 
    	( $mpw_cnt ) = $cur->fetchrow();
    	$cur->finish();
    }

    #$dbh->disconnect();

    print "<table class='img'>\n";
    my $img_pway_url = "$main_cgi?section=ImgPwayBrowser&page=imgPwayBrowser";
    printAttrRowRaw("IMG Pathways", alink($img_pway_url, $img_cnt));
    my $kegg_pway_url = "$main_cgi?section=FindFunctions&page=ffoAllKeggPathways&view=ko";
    printAttrRowRaw("KEGG Pathways", alink($kegg_pway_url, $kegg_cnt));
    
    my $metacyc_url = "$main_cgi?section=MetaCyc";
    printAttrRowRaw("MetaCyc Pathways", alink($metacyc_url, $metacyc_cnt));
    
    if ( $mpw_pathway ) {
    	my $mpw_pway_url = "$main_cgi?section=MpwPwayBrowser&page=mpwPwayBrowser";
    	printAttrRowRaw("MPW Pathways", alink($mpw_pway_url, $mpw_cnt));
    }

    print "</table>\n";

    print "<h2>Search Pathways</h2>\n";
    print "<p>Pathway type: \n";
    print nbsp(2);
    print "<input type='checkbox' name='pway_type' value='img_pway' checked/>IMG Pathways\n";
    print nbsp(1);
    print "<input type='checkbox' name='pway_type' value='kegg_pway' checked/>KEGG Pathways\n";
    print nbsp(1);
    print "<input type='checkbox' name='pway_type' value='metacyc_pway' checked/>MetaCyc Pathways\n";
    
    if ( $mpw_pathway ) {
    	print nbsp(1);
    	print "<input type='checkbox' name='pway_type' value='mpw_pway' checked/>MPW Pathways\n";
    }

    print "<p>Enzyme: EC: \n";
    print nbsp(2);
    print "<input type='text' name='searchEc1' size='3' />\n";
    print ".";
    print "<input type='text' name='searchEc2' size='3' />\n";
    print ".";
    print "<input type='text' name='searchEc3' size='3' />\n";
    print ".";
    print "<input type='text' name='searchEc4' size='3' />\n";
    print "<br/>\n";

    print "<p>Keyword: \n";
    print "<input type='text' name='searchKey' size='80' />\n";
    print "<br/>\n";
 
    my $name = "_section_${section}_searchAllPathways";
    print submit( -name => $name, -value => "Search All Pathways",
		  -class => "meddefbutton" );
    print "</p>\n";

    print "<hr>\n";
    printAllCompounds();

    printJavaScript(); 

    printStatusLine( "Loaded.", 2 );
    print end_form();
}


############################################################################ 
# SearchAllPathways
############################################################################ 
sub SearchAllPathways {
    print "<h1>Search Pathway Result</h1>\n";

    my @pway_types = param('pway_type');
    if ( scalar(@pway_types) == 0 ) {
    	print "<p>Please select at least one pathway type.</p>\n";
    	return;
    }

    my $searchEc1 = param('searchEc1');
    my $searchEc2 = param('searchEc2');
    my $searchEc3 = param('searchEc3');
    my $searchEc4 = param('searchEc4');
    my $searchKey = param('searchKey');

    my $ec1 = '-';
    my $ec2 = '-';
    my $ec3 = '-';
    my $ec4 = '-';

    if ( $searchEc1 ) {
	# EC
	if ( isInt($searchEc1) ) {
	    $ec1 = $searchEc1;

	    if ( $searchEc2 && isInt($searchEc2) ) {
		$ec2 = $searchEc2;
		if ( $searchEc3 && isInt($searchEc3) ) {
		    $ec3 = $searchEc3;
		    if ( $searchEc4 && isInt($searchEc4) ) {
			$ec4 = $searchEc4;
		    }
		}
	    }
	}
	else {
	    print "<p>Incorrect EC number.</p>\n";
	    return;
	}
    }
    elsif ( ! blankStr($searchKey) ) {
	# keyword search
    }
    else {
    	print "<p>Please enter Enzyme EC number and/or a Keyword.</p>\n";
    	return;
    }

    print "<p>Pathway Types: ";
    my $idx = 0;
    for my $t1 ( @pway_types ) {
    	if ($idx > 0) {
    	    print ", ";
    	}
    	if ( $t1 eq 'img_pway' ) {
    	    print "IMG";
    	}
    	elsif ( $t1 eq 'metacyc_pway' ) {
    	    print "MetaCyc";
    	}
    	elsif ( $t1 eq 'kegg_pway' ) {
    	    print "KEGG";
    	}
    	elsif ( $t1 eq 'mpw_pway' ) {
    	    print "MPW";
    	}
    	else {
    	    print $t1;
    	}
    	$idx++;
    }

    my $ec_num = "";
    if ( isInt($ec1) ) {
	$ec_num = $ec1 . "." . $ec2;
	if ( isInt($ec2) ) {
	    $ec_num .= "." . $ec3;

	    if ( isInt($ec3) ) {
		$ec_num .= "." . $ec4;
	    }
	}

	print "<br/>EC: " . $ec_num;
    }

    my $db_keyword = "";
    if ( ! blankStr($searchKey) ) {
	print "<br/>Keyword: " . lc($searchKey);
	$db_keyword = $searchKey;
	$db_keyword =~ s/'/''/g;    # replace ' with ''
    }
    print "</p>\n";

    my @recs; 

    printStatusLine( "Loading ...", 1 ); 

    for my $t1 ( @pway_types ) {
	if ( $t1 eq 'img_pway' ) {
	    my $dbh = dbLogin(); 
	    my $sql = qq{ 
		select p.pathway_oid, p.pathway_name
		    from img_pathway p
		};

	    if ( ! blankStr($ec_num) ) {
		my $sql2 = qq {
		    where p.pathway_oid in
		    ((select ipr.pathway_oid
		     from img_pathway_reactions ipr, 
		     img_reaction_catalysts irc,
		     img_term_enzymes ite
		     where ipr.rxn = irc.rxn_oid 
		     and irc.catalysts = ite.term_oid
		      and ite.enzymes = 'EC:$ec_num')
		     union 
		     ( select ipr2.pathway_oid
		     from img_pathway_reactions ipr2, 
		     img_reaction_t_components rtc,
		     img_term_enzymes ite2
		     where ipr2.rxn = rtc.rxn_oid 
		     and rtc.term = ite2.term_oid
		       and ite2.enzymes = 'EC:$ec_num' ))
		};
		$sql .= $sql2;

		if ( ! blankStr($searchKey) ) {
		    $sql .= " and lower(p.pathway_name) like '%" .
			$db_keyword . "%'";
		}
	    }
	    else {
		if ( ! blankStr($searchKey) ) {
		    $sql .= " where lower(p.pathway_name) like '%" .
			$db_keyword . "%'";
		}
	    }

	    $sql .= " order by 1 ";
	    # print "<p>SQL: $sql\n";

	    my $cur = execSql( $dbh, $sql, $verbose ); 
	    my $cnt0 = 0;
	    for ( ; ; ) { 
		my ( $pathway_oid, $pathway_name ) = $cur->fetchrow(); 
		last if !$pathway_oid; 

		$cnt0++;
		if ( $cnt0 > 100000 ) {
		    last;
		}

		my $r = "IMG\t$pathway_oid\t"; 
		$r .= "$pathway_name\t"; 
		push( @recs, $r ); 
	    } 
	    $cur->finish(); 
	    #$dbh->disconnect();
	}
	elsif ( $t1 eq 'metacyc_pway' ) {
	    my $dbh = dbLogin(); 
	    my $sql = qq{ 
		select p.unique_id, p.common_name
		    from biocyc_pathway p
		};

	    if ( ! blankStr($ec_num) ) {
		my $sql2 = qq{
		    where p.unique_id in
		    (select brp.in_pwys
		     from biocyc_reaction_in_pwys brp, 
		     biocyc_reaction br
		     where brp.unique_id = br.unique_id 
		     and br.ec_number = 'EC:$ec_num')
		};
		$sql .= $sql2;

		if ( ! blankStr($searchKey) ) {
		    $sql .= " and lower(p.common_name) like '%" .
			$db_keyword . "%'";
		}
	    }
	    else {
		if ( ! blankStr($searchKey) ) {
		    $sql .= " where lower(p.common_name) like '%" .
			$db_keyword . "%'";
		}
	    }

	    $sql .= " order by 1";
	    # print "<p>SQL: $sql\n";

	    my $cur = execSql( $dbh, $sql, $verbose ); 
	    my $cnt0 = 0;
	    for ( ; ; ) { 
		my ( $pathway_oid, $pathway_name ) = $cur->fetchrow(); 
		last if !$pathway_oid; 

		$cnt0++;
		if ( $cnt0 > 100000 ) {
		    last;
		}

		my $r = "MetaCyc\t$pathway_oid\t"; 
		$r .= "$pathway_name\t"; 
		push( @recs, $r ); 
	    } 
	    $cur->finish(); 
	    #$dbh->disconnect();
	}
	elsif ( $t1 eq 'mpw_pway' && $mpw_pathway ) {
	    my $dbh = dbLogin(); 
	    my $sql = qq{ 
		select p.pathway_oid, p.pathway_name
		    from mpw_pgl_pathway p
		};

	    if ( ! blankStr($ec_num) ) {
		my $sql2 = qq{
		    where p.pathway_oid in
		    (select pr.pathway_oid
		     from mpw_pgl_pathway_reaction pr, mpw_pgl_reaction r
		    where pr.reaction_oid = r.reaction_oid
		     and r.ec = 'EC:$ec_num')
		};
		$sql .= $sql2;

		if ( ! blankStr($searchKey) ) {
		    $sql .= " and lower(p.pathway_name) like '%" .
			$db_keyword . "%'";
		}
	    }
	    else {
		$sql .= " where lower(p.pathway_name) like '%" .
		    $db_keyword . "%'";
	    }

	    $sql .= " order by 1";

	    my $cur = execSql( $dbh, $sql, $verbose ); 
	    my $cnt0 = 0;
	    for ( ; ; ) { 
		my ( $pathway_oid, $pathway_name ) = $cur->fetchrow(); 
		last if !$pathway_oid; 

		$cnt0++;
		if ( $cnt0 > 100000 ) {
		    last;
		}

		my $r = "MPW\t$pathway_oid\t"; 
		$r .= "$pathway_name\t"; 
		push( @recs, $r ); 
	    } 
	    $cur->finish(); 
	    #$dbh->disconnect();
	}
	elsif ( $t1 eq 'kegg_pway' ) {
	    my $dbh = dbLogin(); 
	    my $sql = qq{
    		select p.pathway_oid, p.pathway_name
		    from kegg_pathway p
		};

	    if ( ! blankStr($ec_num) ) {
    		my $sql2 = qq {
    		    where p.pathway_oid in
    			(select roi.pathway
    			 from image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt
    			 where roi.roi_id = rk.roi_id
                 and rk.ko_terms = kt.ko_id
                 and kt.enzymes = 'EC:$ec_num')
		    };
    		$sql .= $sql2;

    		if ( ! blankStr($searchKey) ) {
    		    $sql .= " and lower(p.pathway_name) like '%" .
    			$db_keyword . "%'";
    		}
	    }
	    else {
    		if ( ! blankStr($searchKey) ) {
    		    $sql .= " where lower(p.pathway_name) like '%" .
    			$db_keyword . "%'";
    		}
	    }

	    $sql .= " order by 1";

	    # print "<p>SQL: $sql\n";

	    my $cur = execSql( $dbh, $sql, $verbose ); 
	    my $cnt0 = 0;
	    for ( ; ; ) { 
    		my ( $pathway_oid, $pathway_name ) = $cur->fetchrow(); 
    		last if !$pathway_oid; 
    
    		$cnt0++;
    		if ( $cnt0 > 100000 ) {
    		    last;
    		}

    		my $r = "KEGG\t$pathway_oid\t"; 
    		$r .= "$pathway_name\t"; 
    		push( @recs, $r ); 
	    } 
	    $cur->finish(); 
	    #$dbh->disconnect();
	}
    }

    my $nRecs = @recs; 
    if ( $nRecs == 0 ) { 
        print "<p>\n"; 
        print "No pathways are found.<br/>\n"; 
        print "</p>\n"; 
    	printStatusLine( "Loaded.", 2 );
        return; 
    } 

    print "<p>\n"; 
 
    my $it = new InnerTable( 1, "allpathwaylist$$", "allpathwaylist", 2 );
    # Select column disabled +BSJ 12/1/11
    # $it->addColSpec("Select");
    $it->addColSpec( "Type",   "char asc", "left" );
    $it->addColSpec( "Pathway OID", "number asc",   "right" );
    $it->addColSpec( "Pathway Name", "char asc",   "left" );
    my $sd = $it->getSdDelim();
 
    my $count = 0; 
    for my $r (@recs) {
	my ( $pathway_type, $pathway_oid, $pathway_name) =
	    split( /\t/, $r );
	my $pway_oid = $pathway_oid;
	if ( isInt($pathway_oid) ) {
	    $pway_oid = FuncUtil::pwayOidPadded($pathway_oid); 
	}
	$count++;
	my $r; 
	my $new_id = $pathway_type . ':' . $pway_oid;

=Select column disabled +BSJ 12/1/11
	$r .= $sd
	    . "<input type='checkbox' name='pway_oid' value='$new_id' />"
	    . "\t";
=cut	
	$r .= $pathway_type . $sd . escHtml($pathway_type) . "\t";

	if ( $pathway_type eq 'IMG' ) {
	    my $url = "main.cgi?section=ImgPwayBrowser&page=imgPwayDetail&pway_oid=$pway_oid";
	    $r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
	}
	elsif ( $pathway_type eq 'MetaCyc' ) {
	    my $url = "main.cgi?section=MetaCyc&page=detail&pathway_id=$pway_oid";
	    $r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
	}
	elsif ( $pathway_type eq 'KEGG' ) {
	    my $url = "main.cgi?section=KeggPathwayDetail&page=keggPathwayDetail&pathway_oid=$pway_oid";
	    $r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
	}
	elsif ( $pathway_type eq 'MPW' && $mpw_pathway ) {
	    my $url = "main.cgi?section=MpwPwayBrowser&page=mpwPwayDetail&pway_oid=$pway_oid";
	    $r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
	}
	else {
	    $r .= $pway_oid . $sd . escHtml($pway_oid) . "\t";
	}

	if ( ! blankStr($searchKey) ) {
            my $matchText = highlightMatchHTML2( $pathway_name,
						 $searchKey ); 
            $r .= $matchText . $sd . $matchText ."\t"; 
	}
	else {
#	    $r .= $pathway_name . $sd . escHtml($pathway_name) . "\t";
	    $r .= $pathway_name . $sd . $pathway_name . "\t";
	}
	$it->addRow($r);
    } 
    $it->printOuterTable(1); 
    
    print "</p>\n"; 
    print end_form();
 
    printJavaScript(); 
    printStatusLine( "$count Loaded.", 2 );

    print end_form(); 
} 


############################################################################ 
# printAllCompounds
############################################################################ 
sub printAllCompounds { 

    print "<h2>All Compounds in IMG</h2>\n"; 

    my $dbh = dbLogin(); 

    # IMG compounds
    my $sql = qq{
	select count(*) from img_compound
    };
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my ( $img_cnt ) = $cur->fetchrow();
    $cur->finish();

    # KEGG compounds
    $sql = qq{
	select count(*) from compound
    };
    $cur = execSql( $dbh, $sql, $verbose ); 
    my ( $kegg_cnt ) = $cur->fetchrow();
    $cur->finish();

    # MetaCyc compounds
    my $metacyc_cnt = 0;
    $sql = qq{
	select count(*) from biocyc_comp
    };
    $cur = execSql( $dbh, $sql, $verbose ); 
    ( $metacyc_cnt ) = $cur->fetchrow();
    $cur->finish();

    # MPW compounds
    my $mpw_cnt = 0;
    $sql = qq{
	select count(*) from mpw_pgl_compound
    };
    $cur = execSql( $dbh, $sql, $verbose ); 
    ( $mpw_cnt ) = $cur->fetchrow();
    $cur->finish();
    
    print "<table class='img'>\n";
    my $img_pway_url = "$main_cgi?section=ImgCompound&page=browse";
    printAttrRowRaw("IMG Compounds", alink($img_pway_url, $img_cnt));
    my $kegg_pway_url = "$main_cgi?section=KeggPathwayDetail&page=cpdList";
    printAttrRowRaw("KEGG Compounds", alink($kegg_pway_url, $kegg_cnt));
    
    my $metacyc_url = "$main_cgi?section=MetaCyc&page=cpdList";
    printAttrRowRaw("MetaCyc Compounds", alink($metacyc_url, $metacyc_cnt));
    my $mpw_url = "$main_cgi?section=MpwPwayBrowser&page=cpdList";
    printAttrRowRaw("MPW Compounds", alink($mpw_url, $mpw_cnt));
    
    print "</table>\n";

    print "<h2>Search All Compounds</h2>\n";
    print "<p>Compound type: \n";
    print nbsp(2);
    print "<input type='checkbox' name='cmpd_type' value='img_pway' checked/>IMG\n";
    print nbsp(1);
    print "<input type='checkbox' name='cmpd_type' value='kegg_pway' checked/>KEGG\n";
    
    print nbsp(1);
    print "<input type='checkbox' name='cmpd_type' value='metacyc_pway' checked/>MetaCyc\n";
    
    if ( $mpw_pathway ) {
	print nbsp(1);
	print "<input type='checkbox' name='cmpd_type' value='mpw_pway' checked/>MPW\n";
    }

    print "<p>\n";
    print "<select name='compound_filter' class='img' size='1'>\n";
    print "<option value='keyword'>Keyword</option>\n";
    print "<option value='cas'>CAS Number</option>\n";
    print "<option value='chebi'>CHEBI ID</option>\n";
    print "<option value='ligand'>KEGG LIGAND ID</option>\n";
    print "</select> contains : \n";
    print "<input type='text' name='searchCmpdKey' size='80' />\n";
    print "<br/>\n";
 
    my $name = "_section_${section}_searchAllCompounds";
    print submit( -name => $name, -value => "Search All Compounds",
		  -class => "meddefbutton" );
    print "</p>\n";

}


############################################################################ 
# SearchAllCompounds
############################################################################ 
sub SearchAllCompounds {
    printMainForm();
    print "<h1>Search Compound Result</h1>\n";

    my @cmpd_types = param('cmpd_type');
    if ( scalar(@cmpd_types) == 0 ) {
    	print "<p>Please select at least one compound type.</p>\n";
    	return;
    }

    my $ec_num = "";

    my $filter = param('compound_filter');
    my $searchKey = param('searchCmpdKey');
    $searchKey = strTrim($searchKey);

    if ( ! blankStr($searchKey) ) {
    	# keyword search
    }
    else {
    	print "<p>Please enter a Keyword.</p>\n";
    	return;
    }

    print "<p>Compound Types: ";
    my $idx = 0;
    for my $t1 ( @cmpd_types ) {
    	if ($idx > 0) {
    	    print ", ";
    	}
    	if ( $t1 eq 'img_pway' ) {
    	    print "IMG";
    	}
    	elsif ( $t1 eq 'metacyc_pway' ) {
    	    print "MetaCyc";
    	}
    	elsif ( $t1 eq 'kegg_pway' ) {
    	    print "KEGG";
    	}
    	elsif ( $t1 eq 'mpw_pway' ) {
    	    print "MPW";
    	}
    	else {
    	    print $t1;
    	}
    	$idx++;
    }

    my $db_keyword = "";
    if ( ! blankStr($searchKey) ) {
    	print "<br/>Keyword: " . lc($searchKey);
    	$db_keyword = lc($searchKey);
    	$db_keyword =~ s/'/''/g;    # replace ' with ''
    }
    print "</p>\n";

    my @recs; 
    my $dbh = dbLogin(); 

    printStatusLine( "Loading ...", 1 ); 

    for my $t1 ( @cmpd_types ) {
    	if ( $t1 eq 'img_pway' ) {
    	    my $sql = "select c.compound_oid, c.compound_name from img_compound c ";
    	    if ( $filter eq 'cas' ) {
        		$sql .= "where lower(c.cas_number) like '%" . $db_keyword . "%'";
    	    }
    	    elsif ( $filter eq 'chebi' ) {
        		$sql .= "where c.db_source = 'CHEBI' ";
        		$sql .= "and lower(c.ext_accession) like '%" . $db_keyword . "%'";
    	    }
    	    elsif ( $filter eq 'ligand' ) {
        		$sql .= "where (c.db_source = 'KEGG LIGAND' ";
        		$sql .= "and lower(c.ext_accession) like '%" . $db_keyword . "%') ";
        		$sql .= "or c.compound_oid in ";
        		$sql .= " (select a.compound_oid from img_compound_kegg_compounds a ";
        		$sql .= " where lower(a.compound) like '%" . $db_keyword . "%') ";
    	    }
    	    else {
        		$sql .= "where lower(c.compound_name) like '%" . $db_keyword . "%'";
        		$sql .= "or lower(c.common_name) like '%" . $db_keyword . "%'";
        		$sql .= "or c.compound_oid in (select a.compound_oid from img_compound_aliases a ";
        		$sql .= " where lower(a.aliases) like '%" . $db_keyword . "%') ";
    	    }
    
    	    #print "<p>SQL: $sql\n";
    
    	    my $cur = execSql( $dbh, $sql, $verbose ); 
    	    my $cnt0 = 0;
    	    for ( ; ; ) { 
        		my ( $compound_oid, $compound_name ) = $cur->fetchrow(); 
        		last if !$compound_oid; 
        
        		$cnt0++;
        		if ( $cnt0 > 1000000 ) {
        		    last;
        		}
        
        		my $r = "IMG\t$compound_oid\t"; 
        		$r .= "$compound_name\t"; 
        		push( @recs, $r ); 
    	    } 
    	    $cur->finish(); 
    	}
    	elsif ( $t1 eq 'metacyc_pway' ) {
    	    my $sql = "select c.unique_id, c.common_name from biocyc_comp c ";
    
    	    if ( $filter eq 'cas' ) {
        		$sql .= "where c.unique_id in ";
        		$sql .= " (select a.unique_id from biocyc_comp_ext_links a ";
        		$sql .= " where a.db_name = 'CAS' ";
        		$sql .= " and lower(a.id) like '%" . $db_keyword . "%') ";
    	    }
    	    elsif ( $filter eq 'chebi' ) {
        		$sql .= "where c.unique_id in ";
        		$sql .= " (select a.unique_id from biocyc_comp_ext_links a ";
        		$sql .= " where a.db_name = 'CHEBI' ";
        		$sql .= " and lower(a.id) like '%" . $db_keyword . "%') ";
    	    }
    	    elsif ( $filter eq 'ligand' ) {
        		$sql .= "where c.unique_id in ";
        		$sql .= " (select a.unique_id from biocyc_comp_ext_links a ";
        		$sql .= " where a.db_name in ('LIGAND', 'LIGAND-CPD' ) ";
        		$sql .= " and lower(a.id) like '%" . $db_keyword . "%') ";
    	    }
    	    else {
        		$sql .= "where lower(c.common_name) like '%" . $db_keyword . "%'";
        		$sql .= "or lower(c.systematic_name) like '%" . $db_keyword . "%'";
        		$sql .= "or c.unique_id in (select a.unique_id from biocyc_comp_synonyms a ";
        		$sql .= " where lower(a.synonyms) like '%" . $db_keyword . "%') ";
    	    }    
    	    #print "<p>SQL: $sql\n";
    
    	    my $cur = execSql( $dbh, $sql, $verbose ); 
    	    my $cnt0 = 0;
    	    for ( ; ; ) { 
        		my ( $compound_oid, $compound_name ) = $cur->fetchrow(); 
        		last if !$compound_oid; 
        
        		$cnt0++;
        		if ( $cnt0 > 1000000 ) {
        		    last;
        		}
        
        		my $r = "MetaCyc\t$compound_oid\t"; 
        		$r .= "$compound_name\t"; 
        		push( @recs, $r ); 
    	    } 
    	    $cur->finish(); 
    	}
    	elsif ( $t1 eq 'mpw_pway' && $mpw_pathway ) {
    	    if ( $filter ne 'keyword' ) {
        		next;
    	    }
    
    	    my $sql = "select c.compound_oid, c.compound_name from mpw_pgl_compound c ";
    	    $sql .= "where lower(c.compound_name) like '%" . $db_keyword . "%'";
    
    	    #print "<p>SQL: $sql\n";
    
    	    my $cur = execSql( $dbh, $sql, $verbose ); 
    	    my $cnt0 = 0;
    	    for ( ; ; ) { 
        		my ( $compound_oid, $compound_name ) = $cur->fetchrow(); 
        		last if !$compound_oid; 
        
        		$cnt0++;
        		if ( $cnt0 > 1000000 ) {
        		    last;
        		}
        
        		my $r = "MPW\t$compound_oid\t"; 
        		$r .= "$compound_name\t"; 
        		push( @recs, $r ); 
    	    } 
    	    $cur->finish(); 
    	}
    	elsif ( $t1 eq 'kegg_pway' ) {
    	    my $sql = "select c.ext_accession, c.compound_name from img_compound c ";
    
    	    if ( $filter eq 'cas' ) {
        		$sql .= "where lower(c.cas_number) like '%" . $db_keyword . "%'";
        		$sql .= " or c.ext_accession in ";
        		$sql .= " (select a.ext_accession from compound_ext_links a ";
        		$sql .= " where a.db_name = 'CAS' ";
        		$sql .= " and lower(a.id) like '%" . $db_keyword . "%') ";
    	    }
    	    elsif ( $filter eq 'chebi' ) {
        		$sql .= "where c.ext_accession in ";
        		$sql .= " (select a.ext_accession from compound_ext_links a ";
        		$sql .= " where a.db_name = 'ChEBI' ";
        		$sql .= " and lower(a.id) like '%" . $db_keyword . "%') ";
    	    }
    	    elsif ( $filter eq 'ligand' ) {
        		$sql .= "where lower(c.ext_accession) like '%" . $db_keyword . "%') ";
    	    }
    	    else {
        		$sql .= "where lower(c.compound_name) like '%" . $db_keyword . "%'";
        		$sql .= "or c.ext_accession in (select a.ext_accession from compound_aliases a ";
        		$sql .= " where lower(a.aliases) like '%" . $db_keyword . "%') ";
    	    }
    
    	    #print "<p>SQL: $sql\n";
    
    	    my $cur = execSql( $dbh, $sql, $verbose ); 
    	    my $cnt0 = 0;
    	    for ( ; ; ) { 
        		my ( $compound_oid, $compound_name ) = $cur->fetchrow(); 
        		last if !$compound_oid; 
        
        		$cnt0++;
        		if ( $cnt0 > 1000000 ) {
        		    last;
        		}
        
        		my $r = "Kegg\t$compound_oid\t"; 
        		$r .= "$compound_name\t"; 
        		push( @recs, $r ); 
    	    } 
    	    $cur->finish(); 
    	}
    }

    my $nRecs = @recs; 
    if ( $nRecs == 0 ) { 
        print "<p>\n"; 
        print "No compounds are found.<br/>\n"; 
        print "</p>\n"; 
    	printStatusLine( "Loaded.", 2 );
        return; 
    } 

    print "<p>\n"; 

    my $sid = getContactOid();
    my $can_edit = WebUtil::isImgEditor($dbh, $sid);

    my $it = new InnerTable( 1, "allcmpdlist$$", "allcmpdlist", 2 );
    # Select column disabled +BSJ 12/1/11
    if ( $can_edit ) {
    	$it->addColSpec("Select");
    }
    $it->addColSpec( "Type",   "char asc", "left" );
    $it->addColSpec( "Compound OID", "char asc",   "left" );
    $it->addColSpec( "Compound Name", "char asc",   "left" );
    my $sd = $it->getSdDelim();
 
    my $count = 0; 
    my $edit_cnt = 0;
    for my $r (@recs) {
    	my ( $compound_type, $compound_oid, $compound_name) =
    	    split( /\t/, $r );
    
    	$count++;
    	my $r; 
    	if ( $can_edit ) {
    	    if ( $compound_type eq 'IMG' ) {
        		my $comp_oid = FuncUtil::compoundOidPadded( $compound_oid );
        		$r .= $sd .
        		    "<input type='checkbox' name='compound_oid' value='$comp_oid' />\t"; 
        		$edit_cnt++;
    	    }
    	    else {
        		$r .= "" . $sd . "\t";
    	    }
    	}
    
    	$r .= $compound_type . $sd . $compound_type . "\t";
    
    	if ( $compound_type eq 'IMG' ) {
    	    my $url = "main.cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
    	    $r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
    	}
    	elsif ( $compound_type eq 'MetaCyc' ) {
    	    my $url = "main.cgi?section=MetaCyc&page=compound&unique_id=$compound_oid";
    	    $r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
    	}
    	elsif ( $compound_type eq 'Kegg' ) {
    	    my $url = "main.cgi?section=KeggPathwayDetail&page=compound&ext_accession=$compound_oid";
    	    $r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
    	}
    	elsif ( $compound_type eq 'MPW' && $mpw_pathway ) {
    	    my $url = "main.cgi?section=MpwPwayBrowser&page=compound&compound_oid=$compound_oid";
    	    $r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
    	}
    	else {
    	    $r .= $compound_oid . $sd . $compound_oid . "\t";
    	}
    
    	if ( ! blankStr($searchKey) ) {
            my $matchText = highlightMatchHTML2( $compound_name,
    					 $searchKey, 1 ); 
            $r .= $matchText . $sd . $matchText ."\t"; 
    	}
    	else {
    	    $r .= $compound_name . $sd . $compound_name . "\t";
    	}
    	$it->addRow($r);
    } 
    $it->printOuterTable(1); 
    
    if ( $can_edit && $edit_cnt ) { 
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

    print "</p>\n"; 
    print end_form();
 
    printJavaScript(); 
    printStatusLine( "$count Loaded.", 2 );

    print end_form(); 
} 



1;
