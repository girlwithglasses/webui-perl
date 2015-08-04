############################################################################
# ImgPwayBrowser.pm - IMG Pathway Browser module.
#   Includes IMG pathway details.
#
# $Id: ImgPwayBrowser.pm 32248 2014-11-05 21:33:44Z klchu $
############################################################################
package ImgPwayBrowser;
my $section = "ImgPwayBrowser";

use strict;
use CGI qw( :standard );
use Data::Dumper;
use CachedTable;
use InnerTable;
use GeneDetail;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;
use FuncUtil;
use HtmlUtil;
use PwNwNode;
use PwNwNodeMgr;
use ImgTermNode;
use ImgTermNodeMgr;
use ImgNetworkBrowser;
use DataEntryUtil;
use TaxonList;
use WorkspaceUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
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
my $img_pheno_rule       = $env->{img_pheno_rule};
my $img_pheno_rule_saved = $env->{img_pheno_rule_saved};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "imgPwayBrowser" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #	printImgPwayBrowser( );
        # if not tabs then use list
        if ( !$tab_panel ) {
            ImgNetworkBrowser::printImgFam();
        }
        printAlphaList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "alphaList" ) {
        printAlphaList();
    } elsif ( $page eq "imgPwayDetail" ) {
        printImgPwayDetail();
    } elsif ( $page eq "pwayTaxonDetail" ) {
        printPwayTaxonDetail();
    } elsif ( $page eq "rxnTaxons" ) {
        printRxnTaxons();
    } elsif ( $page eq "imgPwayTaxonGenes" ) {
        printImgPwayTaxonGenes();
    } elsif ( paramMatch("updateAssertion") ) {
        updateAssertion();
        printPwayTaxonDetail();
    } elsif ( $page eq "imgPwayPhyloDist" ) {
        printImgPwayPhyloDist();
    } elsif ( $page eq "rxnPhyloDist" ) {
        printRxnPhyloDist();
    } elsif ( $page eq "pwayAssocGeneList" ) {
        printPwayAssocGeneList();
    } elsif ( $page eq "imgPwayHistory" ) {
        printImgPwayHistory();
    } elsif ( $page eq "partsListDetail" ) {
        printPartsListDetail();
    } elsif ( $page eq "statlist" ) {
        printStatList();
    } elsif ( $page eq "phenoRules" ) {
        printPhenoRules();
    } elsif ( $page eq "PhenotypeRuleDetail"
              || paramMatch("PhenotypeRuleDetail") ne "" )
    {
        printPhenotypeRuleDetail();
    } elsif ( $page eq "showPhenoTaxons"
              || paramMatch("showPhenoTaxons") ne "" )
    {
        printShowPhenoTaxons_tree();
    } elsif ( $page eq "showPhenoTaxonsTable"
              || paramMatch("showPhenoTaxonsTable") ne "" )
    {
        printShowPhenoTaxons_table();
    } elsif ( $page eq "findPhenoTaxons"
              || paramMatch("findPhenoTaxons") ne "" )
    {
        printFindPhenoTaxons();
    } else {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #   printImgPwayBrowser( );
        # if not tabs then use list
        if ( !$tab_panel ) {
            ImgNetworkBrowser::printImgFam();
        }

        #        printImgPwayBrowser( );
        printAlphaList();
        HtmlUtil::cgiCacheStop();
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
# printImgPwayBrowser - Show pathway list.
#   (Perhaps when we have a more of a hierarchy someday, we'll do
#    the hierarchy thing.)
############################################################################
sub printImgPwayBrowser {
    print "<h1>IMG Pathway Browser</h1>\n";
    printMainForm();
    my $dbh = dbLogin();
    my $sql = qq{
       select count(*)
       from img_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = $cur->fetchrow();
    $cur->finish();

    if ( $cnt == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "This database has no IMG pathways.\n";
        print "</p>\n";
        print "</div>\n";
        #$dbh->disconnect();
        return;
    }
    my $mgr = new PwNwNodeMgr();
    WebUtil::printFuncCartFooterForEditor();

    print "<p>\n";
    my $url = "$section_cgi&page=alphaList";
    print alink( $url, "Alphabetical List" ) . "<br/>\n";
    print "</p>\n";

    $mgr->loadTree();
    my $root = $mgr->{root};
    print "<p>\n";
    $root->printNodeHtml();
    print "</p>\n";
    print "<br/>\n";
    WebUtil::printFuncCartFooterForEditor();

    #printPartsList( $dbh );

    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printImgPwayDetail - Print details for one pathway.
############################################################################
sub printImgPwayDetail {
    my $pway_oid = param("pway_oid");
    my $pway_oid_orig = $pway_oid;

    print "<h1>IMG Pathway Details</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);

    printMainForm();
    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name,
	       to_char(ipw.add_date, 'yyyy-mm-dd'), 
           to_char(ipw.mod_date, 'yyyy-mm-dd'),
           c.name, c.email
        from img_pathway ipw, contact c
    	where ipw.pathway_oid = ?
    	and ipw.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my ( $pway_oid, $pathway_name, $add_date, $mod_date, $c_name, $email ) =
	$cur->fetchrow();
    $cur->finish();
    $pway_oid = FuncUtil::pwayOidPadded($pway_oid);

    print "<table class='img' border='1'>\n";
    printAttrRow( "Pathway OID", $pway_oid );
    printAttrRow( "Name",        $pathway_name );
    printAttrRow( "Add Date",    $add_date );
    printAttrRow( "Modify Date", $mod_date );

    my $s = escHtml($c_name);
    printAttrRowRaw( "Modified By", $s );
    print "</table>\n";

    if ($img_internal) {
        my $url = "$section_cgi&page=imgPwayHistory&pway_oid=$pway_oid";
        print "<p>\n";
        print alink( $url, "History" );
        print nbsp(1);
        print "(Internal use only.)";
        print "</p>\n";
    }
    print "<p>\n";
    print
      "<input type='checkbox' name='pway_oid' value='$pway_oid' checked />\n";
    print "Add this pathway to the function cart.<br/>\n";
    print "</p>\n";
    WebUtil::printFuncCartFooterForEditor();

    my %rxnOrderOid2SubOrder;

    my @term_oids;
    printReactionTerms( $dbh, $root, $pway_oid, \@term_oids );
    printAssocGenomes( $dbh, $root, $pway_oid, \@term_oids );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printPwayTaxonDetail - Print details for one pathway and taxon.
############################################################################
sub printPwayTaxonDetail {
    my $pway_oid  = param("pway_oid");
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");
    my $pway_oid_orig = $pway_oid;

    print "<h1>IMG Pathway Assertion Details</h1>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();

    my $contact_oid = getContactOid();
    my $imgEditor   = 0;
    if ( $contact_oid ) {
	my $sql = "select img_editor, img_editing_level "
	        . "from contact where contact_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $contact_oid ); 
	my ($e1, $e2) = $cur->fetchrow();
	$cur->finish();
	if ( $e1 eq 'Yes' || $e2 =~ /img\-pathway/ ) {
	    $imgEditor = 1;
	}
    }

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my $mgr        = new ImgTermNodeMgr();
    my $root       = $mgr->loadTree($dbh);

    print hiddenVar( "pway_oid",  $pway_oid );
    print hiddenVar( "taxon_oid", $taxon_oid );

    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
        from img_pathway ipw, contact c
	where ipw.pathway_oid = ?
	and ipw.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my ( $pway_oid, $pathway_name ) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
        select pa.status,  c.username, to_char(pa.mod_date, 'yyyy-mm-dd'), 
	pa.evidence, pa.comments
	from img_pathway_assertions pa, contact c
	where pa.pathway_oid = ?
	and pa.taxon = ?
	and pa.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $taxon_oid );
    my ( $status, $username, $mod_date, $evidence, $comments ) =
      $cur->fetchrow();
    $cur->finish();

    $pway_oid = FuncUtil::pwayOidPadded($pway_oid);
    print "<table class='img' border='1'>\n";
    printAttrRow( "Pathway OID",  $pway_oid );
    printAttrRow( "Pathway Name", $pathway_name );
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
    $url .= "&taxon_oid=$taxon_oid";
    my $taxon_link = alink( $url, $taxon_name );
    printAttrRowRaw( "Genome", $taxon_link );

    if ( $cluster_id ) {
        my $url2 = "$main_cgi?section=BiosyntheticDetail" .
            "&page=cluster_detail&taxon_oid=$taxon_oid" . 
            "&cluster_id=$cluster_id";
	printAttrRowRaw( "Cluster", alink($url2, $cluster_id) );
    }

    printAttrRow( "Modify Date", $mod_date );
    printAttrRowRaw( "Modified By", $username );

    #printAttrRowRaw( "Status", $status );
    my ( $ck1, $ck2, $ck3 );
    if (    $status eq 'asserted'
         || $status eq "Yes"
         || $status eq "MANDATORY"
         || $status =~ /FULL/ )
    {
        $ck1 = "checked";
        $ck2 = "";
	$ck3 = "";
    } elsif ( $status eq 'unknown' ) {
	$ck1 = "";
	$ck2 = "";
	$ck3 = "checked";
    } else {
        $ck1 = "";
        $ck2 = "checked";
	$ck3 = "";
    }

    printAttrRowRaw( "Assertion",
	"<input type='radio' name='asserted' value='asserted' $ck1 />Asserted "
      . "<input type='radio' name='asserted' value='not asserted' $ck2 />Not Asserted "
      . "<input type='radio' name='asserted' value='unknown' $ck3 />Unknown "
    );

    # evidence
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Evidence</th>\n";
    print "  <td class='img'   align='left'>";
    if ( $imgEditor ) {
	print "<input type='text' name='evidence' value='"
	    . escapeHTML($evidence)
	    . "' size='60' maxLength='480' />";
    }
    else {
	print escapeHTML($evidence);
    }
    print "</td></tr>\n";

    # comments
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Comments</th>\n";
    print "  <td class='img'   align='left'>";
    if ( $imgEditor ) {
	print "<input type='text' name='comments' value='"
	    . escapeHTML($comments)
	    . "' size='60' maxLength='480' />";
    }
    else {
	print escapeHTML($comments);
    }
    print "</td></tr>\n";
    print "</table>\n";

    if ($imgEditor) {
        print hiddenVar( "pway_oid",  $pway_oid );
        print hiddenVar( "taxon_oid", $taxon_oid );
        my $name = "_section_${section}_updateAssertion";
        print submit(
                      -name  => $name,
                      -value => "Update Database",
                      -class => "meddefbutton "
        );
        print nbsp(1);
        print reset( -class => "smbutton" );
        print "<br/>\n";
    }

    my @term_oids;
    printTaxonReactionTerms( $dbh, $root, $pway_oid, $taxon_oid, \@term_oids );

    print end_form();
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# updateAssertion - Update assertion data.
############################################################################
sub updateAssertion {
    my $pway_oid  = param("pway_oid");
    my $taxon_oid = param("taxon_oid");
    my $asserted  = param("asserted");
    my $evidence  = param("evidence");
    my $comments  = param("comments");

    my $dbh = dbLogin();
    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Not logged in.");
    }

    my $imgEditor   = 0;
    if ( $contact_oid ) {
	my $sql = "select img_editor, img_editing_level "
	        . "from contact where contact_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $contact_oid ); 
	my ($e1, $e2) = $cur->fetchrow();
	$cur->finish();
	if ( $e1 eq 'Yes' || $e2 =~ /img\-pathway/ ) {
	    $imgEditor = 1;
	}
    }

    if ( !$imgEditor ) {
        webError("Insufficient editing privileges.");
    }

    execSqlOnly( $dbh, "commit work", $verbose );
    execSqlOnly( $dbh, "set transaction read write", $verbose );

    my $sql = qq{
        select count(*)
	from img_pathway_assertions
	where pathway_oid = ?
	and taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $taxon_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();

    if ( $cnt > 0 ) {
        my $sql = qq{
	   delete from img_pathway_assertions
	   where pathway_oid = $pway_oid
	   and taxon = $taxon_oid
	};
        execSqlOnly( $dbh, $sql, $verbose );
    }

    if ($asserted) {
        my $db_evidence = 'null';
        if ( !blankStr($evidence) ) {
            $db_evidence = $evidence;
            $db_evidence =~ s/'/''/g;    # replace ' with ''
            $db_evidence = "'" . $db_evidence . "'";
        }

        my $db_comments = 'null';
        if ( !blankStr($comments) ) {
            $db_comments = $comments;
            $db_comments =~ s/'/''/g;    # replace ' with ''
            $db_comments = "'" . $db_comments . "'";
        }

        my $sql = qq{
            insert into img_pathway_assertions( 
              pathway_oid, taxon, status, modified_by, mod_date, 
						evidence, comments )
              values( $pway_oid, $taxon_oid, 
	         '$asserted', $contact_oid, sysdate, 
		      $db_evidence, $db_comments )
        };
        execSqlOnly( $dbh, $sql, $verbose );
    }
    execSqlOnly( $dbh, "commit work", $verbose );

    #$dbh->disconnect();

    my $url = "$section_cgi";
    $url .= "&page=pwayTaxonDetail";
    $url .= "&pway_oid=$pway_oid";
    $url .= "&taxon_oid=$taxon_oid";
}

############################################################################
# printReactionTerms - Print terms together with reaction definition.
#  All the ugly code is to handle the various formatting options
#  under various data conditions.
############################################################################
sub printReactionTerms {
    my ( $dbh, $root, $pway_oid, $termOids_ref ) = @_;

    print "<h2>Pathway Reactions</h2>\n";

    my $sql = qq{
        select ir.rxn_oid, ipr.rxn_order, 
       	    ir.rxn_name, ir.rxn_definition
    	from img_pathway_reactions ipr, img_reaction ir
            where ipr.pathway_oid = ?
    	and ipr.rxn = ir.rxn_oid
    	order by ipr.rxn_order, ipr.rxn
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my @reactions;
    my $old_rxn_order;
    my $subOrder = 0;
    my %rxnOid2SubOrder;
    for ( ; ; ) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          $cur->fetchrow();
        last if !$rxn_oid;
        my $r = "$rxn_oid\t";
        $r .= "$rxn_order\t";
        $r .= "$rxn_name\t";
        $r .= "$rxn_definition\t";
        $subOrder = 0 if ( $old_rxn_order != $rxn_order );
        $rxnOid2SubOrder{$rxn_oid} = $subOrder++;
        push( @reactions, $r );
        $old_rxn_order = $rxn_order;
    }
    $cur->finish();
    if ( scalar(@reactions) == 0 ) {
        print "<p>\n";
        print "No reactions have been " . "defined for this pathway.<br/>\n";
        print "</p>\n";
        return;
    }
    ## Massage order
    my $alphabet   = "abcdefghijklmnopqrstuvwxyz";
    my $nReactions = @reactions;
    for ( my $i = 0 ; $i < $nReactions ; $i++ ) {
        my $r_prev;
        $r_prev = $reactions[ $i - 1 ] if $i > 0;
        my (
             $rxn_oid_prev,   $rxn_order_prev, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_prev );
        my $subOrderPrev = $rxnOid2SubOrder{$rxn_oid_prev};

        my $r_curr = $reactions[$i];
        my (
             $rxn_oid_curr,   $rxn_order_curr, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_curr );
        my $subOrderCurr = $rxnOid2SubOrder{$rxn_oid_curr};

        my $r_next;
        $r_next = $reactions[ $i + 1 ] if $i < $nReactions - 1;
        my (
             $rxn_oid_next,   $rxn_order_next, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_next );
        my $subOrderNext = $rxnOid2SubOrder{$rxn_oid_next};

        if (    $rxn_order_curr eq $rxn_order_next
             || $rxn_order_curr eq $rxn_order_prev )
        {
            my $c = substr( $alphabet, $subOrderCurr, 1 );
            $rxnOid2SubOrder{$rxn_oid_curr} = $c;
        } else {
            $rxnOid2SubOrder{$rxn_oid_curr} = ".";
        }
    }
    my $sql = qq{
        select ipr.rxn rxn, irc.catalysts term_oid, 'catalyst', ''
    	from img_pathway_reactions ipr, img_reaction_catalysts irc
            where ipr.rxn = irc.rxn_oid
    	and ipr.pathway_oid = ?
    	    union
            select ipr.rxn rxn, rtc.term term_oid, 'component', rtc.c_type
    	from img_pathway_reactions ipr, img_reaction_t_components rtc
            where ipr.rxn = rtc.rxn_oid
    	and ipr.pathway_oid = ?
    	order by  rxn, term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $pway_oid );
    my %rxn2TermOids;
    my %rxnTerm2Type;
    for ( ; ; ) {
        my ( $rxn, $term_oid, $r_type, $c_type ) = $cur->fetchrow();
        last if !$rxn;
        $rxn2TermOids{$rxn} .= "$term_oid ";
        push( @$termOids_ref, $term_oid );
        my $k = "$rxn:$term_oid";
        my $type = "catalyst" if $r_type eq "catalyst";
        $type = $c_type if $r_type eq "component";
        $rxnTerm2Type{$k} = $type;
    }
    $cur->finish();

    # Use YUI css
    if ($yui_tables) {
	print qq{
        <link rel="stylesheet" type="text/css"
            href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	};

	print <<YUI;
        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>Order</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>ID</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>IMG Terms</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>Definition</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Genome<br/>Count</span>
	    </div>
	</th>
	</tr>
YUI
    } else {
    	print "<table class='img' border='1'>\n";
    	print "<th class='img'>Reaction<br/>Order</th>\n";
    
    	print "<th class='img'>Reaction<br/>ID</th>\n";
    	print "<th class='img'>IMG Terms</th>\n";
    
    	#print "<th class='img'>Catalyst</th>\n";
    	print "<th class='img'>Reaction<br/>Definition</th>\n";
    	print "<th class='img'>Genome<br/>Count</th>\n";
    }

    my $idx = 0;
    my $classStr;
    for my $r (@reactions) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          split( /\t/, $r );

    	if ($yui_tables) {
    	    $classStr = !$idx ? "yui-dt-first ":"";
    	    $classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    	} else {
    	    $classStr = "img";
    	}
        print "<tr class='$classStr'>\n";
        my $subOrder = $rxnOid2SubOrder{$rxn_oid};

        #my $taxonCount = $rxn2TaxonCount{ $rxn_oid };
        my $termOidStr = $rxn2TermOids{$rxn_oid};
        my @term_oids = sort( split( / /, $termOidStr ) );
        my @catalyst_term_oids;
        my @lhs_term_oids;
        my @rhs_term_oids;

        ## sort by LHS, catalyst, RHS
        my @sortRecs;
        for my $term_oid (@term_oids) {
            my $k    = "$rxn_oid:$term_oid";
            my $type = $rxnTerm2Type{$k};
            my $type2;
            if ( $type eq "catalyst" ) {
                $type2 = "M";    # sort in the middle between "LHS" and "RHS"
            } else {
                $type2 = $type;
            }
            my $r = "$type2\t$term_oid";
            push( @sortRecs, $r );
        }
        my @sortRecs2 = sort(@sortRecs);
        @term_oids = ();
        for my $sr (@sortRecs2) {
            my ( $type2, $term_oid ) = split( /\t/, $sr );
            push( @term_oids, $term_oid );
            if ( $type2 eq "M" || $type2 eq "" ) {
                push( @catalyst_term_oids, $term_oid );
            }
            if ( $type2 eq "LHS" ) {
                push( @lhs_term_oids, $term_oid );
            }
            if ( $type2 eq "RHS" ) {
                push( @rhs_term_oids, $term_oid );
            }
            #print "$type2, term_oid: $term_oid<br>\n";
        }

        print "<td class='$classStr' style='text-align:right'>\n";
    	print "<div class='yui-dt-liner'>\n" if $yui_tables;
    	print $rxn_order . $subOrder;
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";

        my $rec_url =
            "$main_cgi?section=ImgReaction&page=imgRxnDetail"
          . "&rxn_oid=$rxn_oid";
        $rec_url = alink( $rec_url, $rxn_oid );

        print "<td class='$classStr' style='text-align:right'>";
    	print "<div class='yui-dt-liner'>\n" if $yui_tables;
    	print $rec_url;
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";

        my $nCatalysts = @catalyst_term_oids;
        my $nLhs       = @lhs_term_oids;
        my $nRhs       = @rhs_term_oids;
        my @term_oids  = @catalyst_term_oids;
        my $rhsOnly    = 0;
        if ( $nCatalysts == 0 && $nRhs > 0 && $nLhs == 0 ) {
            $rhsOnly = 1;
        }
        if ($rhsOnly) {
            @term_oids = @rhs_term_oids;
        }

        ## IMG Terms
        print "<td class='$classStr' style='white-space:nowrap'>\n";
    	print "<div class='yui-dt-liner'>\n" if $yui_tables;
        if ( $nCatalysts == 0 && $nLhs && $nRhs > 0 ) {
            print nbsp(1);
        } else {
            my $count = 0;
            for my $term_oid (@term_oids) {
                next if $term_oid eq "";
                $count++;
                my $n = $root->findNode($term_oid);
                if ( !defined($n) ) {
                    webLog(   "printReactionTerms: cannot find "
                            . "term_oid=$term_oid\n" );
                    next;
                }
                my $k    = "$rxn_oid:$term_oid";
                my $type = $rxnTerm2Type{$k};
                my %suffixMap;
                $suffixMap{$term_oid} = " ($type)"
                  if scalar(@term_oids) > 1;

                #if( $img_internal ) {
                #    $n->printHtml( 0, 0, \%suffixMap );
                #}
                #else {
                #    $n->printHtml(  );
                #}
                print "or<br/>\n" if $count > 1;
                $n->printHtml();
            }
        }
    	print "</div>\n" if $yui_tables;
        print "</td>\n";

        ## Reaction Definition: Print LHS => RHS components
        my $c_rxn_definition = getReactionCompounds( $dbh, $rxn_oid );
        if ( !blankStr($rxn_definition) ) {
            print "<td class='$classStr'>\n";
    	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
    	    print escHtml($rxn_definition);
    	    print "</div>\n" if $yui_tables;
    	    print "</td>\n";
        } elsif ( !blankStr($c_rxn_definition) ) {
            print "<td class='$classStr'>\n";
    	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
            print escHtml($c_rxn_definition);
    	    print "</div>\n" if $yui_tables;
    	    print "</td>\n";
        } elsif ( $nLhs > 0 && $nRhs > 0 ) {
            my $url0 =
                "$main_cgi?section=ImgTermBrowser"
              . "&page=imgTermDetail&term_oid=";
            print "<td class='$classStr'>\n";
    	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
            my $s;
            for my $term_oid (@lhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
            print " => <br/> ";
            my $s;
            for my $term_oid (@rhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
    	    print "</div>\n" if $yui_tables;
            print "</td>\n";
        }
        ## Totally empty definition
        else {
            print "<td class='$classStr'>\n";
    	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
    	    print nbsp(1);
    	    print "</div>\n" if $yui_tables;
    	    print "</td>\n";
        }
        my $taxonCount = pwayRxn2TaxonCount( $dbh, $root, $pway_oid, $rxn_oid );
        my $url = "$section_cgi&page=rxnTaxons";
        $url .= "&pway_oid=$pway_oid";
        $url .= "&rxn_oid=$rxn_oid";
        my $link = 0;
        $link = alink( $url, $taxonCount ) if $taxonCount > 0;
        print "<td class='$classStr' style='text-align:right'>\n";
    	print "<div class='yui-dt-liner'>\n" if $yui_tables;
    	print $link;
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";
        print "</tr>\n";
        $idx++;
     }
    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "<p>\n";
    print "Add selected terms to function cart.<br/>\n";
    print "</p>\n";
    WebUtil::printFuncCartFooterForEditor();

    # Add ids to buttons so they don't interfere with other tables.
    # +BSJ 05/07/10
    print <<EOF;

    <script type="text/javascript">
      AddIds ('selectAll');
      AddIds ('clearAll');

      function AddIds(b) {
	  var selclr = document.getElementsByName(b);
	  for (var i in selclr) {
	      selclr[i].id = 'pway' + b + i;
	  }
      }
    </script>

EOF

}


###################################################################
# findAllChildTerms
###################################################################
sub findAllChildTerms {
    my ( $dbh, $term_oid ) = @_;

    if ( ! $term_oid ) {
	return "";
    }

    my %term_h;
    $term_h{$term_oid} = 2;

    my $cnt = 0;
    my $sql = "select term_oid, child from img_term_children where term_oid = ?";
    my $term_list = "";

    while ( $cnt < 100 ) {
	my @arr = ( );
	for my $key (keys %term_h) {
	    if ( $term_h{$key} >= 2 ) {
		push @arr, ( $key );
	    }
	}

	if ( scalar(@arr) == 0 ) {
	    last;
	}

	for my $t2 ( @arr ) {
	    my $cur = execSql( $dbh, $sql, $verbose, $t2 );
	    for ( ; ; ) {
		my ( $term_oid, $child ) = $cur->fetchrow();
		last if ! $term_oid;

		if ( $term_h{$child} ) {
		    # already added
		}
		else {
		    $term_h{$child} = 2;
		    if ( $term_list ) {
			$term_list .= "\t" . $child;
		    }
		    else {
			$term_list = $child;
		    }
		}
	    }
	    $cur->finish();
	    $term_h{$t2} = 1;
	}   # end t2

	$cnt++;
    }   # end while cnt

    return $term_list;
}


###################################################################
# findAllParentTerms  (the reverse of findAllChildTerms)
###################################################################
sub findAllParentTerms {
    my ( $dbh, $term_oid, $include_self ) = @_;

    my @all_terms = ();

    if ( ! $term_oid ) {
	return @all_terms;
    }

    if ( $include_self ) {
	@all_terms = ( $term_oid );
    }

    my $cnt = 0;
    my $sql = "select term_oid, child from img_term_children where child = ?";
    my $curr_term = $term_oid;

    while ( $cnt < 100 && $curr_term ) {
	my $cur = execSql( $dbh, $sql, $verbose, $curr_term );
	my ( $parent_oid, $child ) = $cur->fetchrow();
	$cur->finish();

	if ( $parent_oid ) {
	    push @all_terms, ( $parent_oid );
	}

	$curr_term = $parent_oid;
	$cnt++;
    }

    return @all_terms;
}

############################################################################
# printTaxonReactionTerms - Print terms together with reaction definition.
#  All the ugly code is to handle the various formatting options
#  under various data conditions.
############################################################################
sub printTaxonReactionTerms {
    my ( $dbh, $root, $pway_oid, $taxon_oid, $termOids_ref ) = @_;

    my $cluster_id = param('cluster_id');

    my %bc_gene_h;
    if ( $cluster_id ) {
	my $sql = "select feature_id from bio_cluster_features_new " . 
	    "where cluster_id = ? and feature_type = 'gene'";
	my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
	for (;;) { 
	    my ($gene_id) = $cur->fetchrow(); 
	    last if ! $gene_id; 
	    $bc_gene_h{$gene_id} = 1; 
	}
	$cur->finish();
    }

    print "<h2>Evidence</h2>\n";

    my $sql = qq{
        select ir.rxn_oid, ipr.rxn_order, 
	   ir.rxn_name, ir.rxn_definition
	from img_pathway_reactions ipr, img_reaction ir
        where ipr.pathway_oid = ?
	and ipr.rxn = ir.rxn_oid
	order by ipr.rxn_order, ipr.rxn
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my @reactions;
    my $old_rxn_order;
    my $subOrder = 0;
    my %rxnOid2SubOrder;
    for ( ; ; ) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          $cur->fetchrow();
        last if !$rxn_oid;
        my $r = "$rxn_oid\t";
        $r .= "$rxn_order\t";
        $r .= "$rxn_name\t";
        $r .= "$rxn_definition\t";
        $subOrder = 0 if ( $old_rxn_order != $rxn_order );
        $rxnOid2SubOrder{$rxn_oid} = $subOrder++;
        push( @reactions, $r );
        $old_rxn_order = $rxn_order;
    }
    $cur->finish();
    if ( scalar(@reactions) == 0 ) {
        print "<p>\n";
        print "No reactions have been " . "defined for this pathway.<br/>\n";
        print "</p>\n";
        return;
    }

    ## Massage order
    my $alphabet   = "abcdefghijklmnopqrstuvwxyz";
    my $nReactions = @reactions;
    for ( my $i = 0 ; $i < $nReactions ; $i++ ) {
        my $r_prev;
        $r_prev = $reactions[ $i - 1 ] if $i > 0;
        my (
             $rxn_oid_prev,   $rxn_order_prev, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_prev );
        my $subOrderPrev = $rxnOid2SubOrder{$rxn_oid_prev};

        my $r_curr = $reactions[$i];
        my (
             $rxn_oid_curr,   $rxn_order_curr, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_curr );
        my $subOrderCurr = $rxnOid2SubOrder{$rxn_oid_curr};

        my $r_next;
        $r_next = $reactions[ $i + 1 ] if $i < $nReactions - 1;
        my (
             $rxn_oid_next,   $rxn_order_next, $rxn_name,
             $rxn_definition, $is_mandatory
          )
          = split( /\t/, $r_next );
        my $subOrderNext = $rxnOid2SubOrder{$rxn_oid_next};

        if (    $rxn_order_curr eq $rxn_order_next
             || $rxn_order_curr eq $rxn_order_prev )
        {
            my $c = substr( $alphabet, $subOrderCurr, 1 );
            $rxnOid2SubOrder{$rxn_oid_curr} = $c;
        } else {
            $rxnOid2SubOrder{$rxn_oid_curr} = ".";
        }
    }
    my $sql = qq{
        select ipr.rxn rxn, irc.catalysts term_oid, 'catalyst', ''
	from img_pathway_reactions ipr, img_reaction_catalysts irc
        where ipr.rxn = irc.rxn_oid
	and ipr.pathway_oid = ?
	    union
        select ipr.rxn rxn, rtc.term term_oid, 'component', rtc.c_type
	from img_pathway_reactions ipr, img_reaction_t_components rtc
        where ipr.rxn = rtc.rxn_oid
	and ipr.pathway_oid = ?
	order by  rxn, term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $pway_oid );
    my %rxn2TermOids;
    my %rxnTerm2Type;
    for ( ; ; ) {
        my ( $rxn, $term_oid, $r_type, $c_type ) = $cur->fetchrow();
        last if !$rxn;

        $rxn2TermOids{$rxn} .= "$term_oid ";
        push( @$termOids_ref, $term_oid );
        my $k = "$rxn:$term_oid";
        my $type = "catalyst" if $r_type eq "catalyst";
        $type = $c_type if $r_type eq "component";
        $rxnTerm2Type{$k} = $type;
    }
    $cur->finish();

    # Use YUI css
    if ($yui_tables) {
	my $bc_fld = " ";
	if ( $cluster_id ) {
	    $bc_fld = "<th><div class='yui-dt-liner'><span>Genes in Cluster</span>" .
		"</div></th>";
	}

	print qq{
        <link rel="stylesheet" type="text/css"
            href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	};

	print <<YUI;
        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>Order</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>IMG Terms</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Reaction<br/>Definition</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Genes</span>
	    </div>
	</th>
        $bc_fld
	</tr>
YUI
    } else {

	print "<table class='img' border='1'>\n";
	print "<th class='img'>Reaction<br/>Order</th>\n";

	#print "<th class='img'>Reaction<br/>OID</th>\n";
	print "<th class='img'>IMG Terms</th>\n";

	#print "<th class='img'>Catalyst</th>\n";
	print "<th class='img'>Reaction<br/>Definition</th>\n";
	print "<th class='img'>Genes</th>\n";

	if ( $cluster_id ) {
	    print "<th class='img'>Genes in Cluster</th>\n";
	}
    }

    my $idx = 0;
    my $classStr;

    for my $r (@reactions) {
        my ( $rxn_oid, $rxn_order, $rxn_name, $rxn_definition ) =
          split( /\t/, $r );

	if ($yui_tables) {
	    $classStr = !$idx ? "yui-dt-first ":"";
	    $classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
	} else {
	    $classStr = "img";
	}

        print "<tr class='$classStr'>\n";
        my $subOrder = $rxnOid2SubOrder{$rxn_oid};

        #my $taxonCount = $rxn2TaxonCount{ $rxn_oid };
        my $termOidStr = $rxn2TermOids{$rxn_oid};
        my @term_oids = sort( split( / /, $termOidStr ) );
        my @catalyst_term_oids;
        my @lhs_term_oids;
        my @rhs_term_oids;

        ## sort by LHS, catalyst, RHS
        my @sortRecs;
        for my $term_oid (@term_oids) {
            my $k    = "$rxn_oid:$term_oid";
            my $type = $rxnTerm2Type{$k};
            my $type2;
            if ( $type eq "catalyst" ) {
                $type2 = "M";    # sort in the middle between "LHS" and "RHS"
            } else {
                $type2 = $type;
            }
            my $r = "$type2\t$term_oid";
            push( @sortRecs, $r );
        }
        my @sortRecs2 = sort(@sortRecs);
        @term_oids = ();
        for my $sr (@sortRecs2) {
            my ( $type2, $term_oid ) = split( /\t/, $sr );
            push( @term_oids, $term_oid );
            if ( $type2 eq "M" || $type2 eq "" ) {
                push( @catalyst_term_oids, $term_oid );
            }
            if ( $type2 eq "LHS" ) {
                push( @lhs_term_oids, $term_oid );
            }
            if ( $type2 eq "RHS" ) {
                push( @rhs_term_oids, $term_oid );
            }
        }

        print "<td class='$classStr' style='text-align:right'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
	print $rxn_order . $subOrder;
	print "</div>\n" if $yui_tables;
	print "</td>\n";


        #print "<td class='img' align='right'>$rxn_oid</td>\n";
        my $nCatalysts = @catalyst_term_oids;
        my $nLhs       = @lhs_term_oids;
        my $nRhs       = @rhs_term_oids;
        my @term_oids  = @catalyst_term_oids;
        my $rhsOnly    = 0;
        if ( $nCatalysts == 0 && $nRhs > 0 && $nLhs == 0 ) {
            $rhsOnly = 1;
        }
        if ($rhsOnly) {
            @term_oids = @rhs_term_oids;
        }
        my @all_term_oids;
        for my $term_oid (@catalyst_term_oids) {
            push( @all_term_oids, $term_oid );
        }
        for my $term_oid (@lhs_term_oids) {
            push( @all_term_oids, $term_oid );
        }
        for my $term_oid (@rhs_term_oids) {
            push( @all_term_oids, $term_oid );
        }

        ## IMG Terms
	print "<td class='$classStr' style='white-space:nowrap'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
        if ( $nCatalysts == 0 && $nLhs && $nRhs > 0 ) {
            print nbsp(1);
        } else {
            my $count = 0;
            for my $term_oid (@term_oids) {
                next if $term_oid eq "";
                $count++;
                my $n = $root->findNode($term_oid);
                if ( !defined($n) ) {
                    webLog(   "printReactionTerms: cannot find "
                            . "term_oid=$term_oid\n" );
                    next;
                }
                my $k    = "$rxn_oid:$term_oid";
                my $type = $rxnTerm2Type{$k};
                my %suffixMap;
                $suffixMap{$term_oid} = " ($type)"
                  if scalar(@term_oids) > 1;

                print "or<br/>\n" if $count > 1;
                $n->printHtml();
            }
        }
	print "</div>\n" if $yui_tables;
        print "</td>\n";

        ## Reaction Definition: Print LHS => RHS components
        my $c_rxn_definition = getReactionCompounds( $dbh, $rxn_oid );
	my $rxn_url = "$main_cgi?section=ImgReaction"
              . "&page=imgRxnDetail&rxn_oid=$rxn_oid";
        if ( !blankStr($rxn_definition) ) {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
	    # print escHtml($rxn_definition);
	    print alink($rxn_url, $rxn_definition);
	    print "</div>\n" if $yui_tables;
	    print "</td>\n";
        } elsif ( !blankStr($c_rxn_definition) ) {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
            # print escHtml($c_rxn_definition);
	    print alink($rxn_url, $c_rxn_definition);
	    print "</div>\n" if $yui_tables;
	    print "</td>\n";
        } elsif ( $nLhs > 0 && $nRhs > 0 ) {
            my $url0 =
                "$main_cgi?section=ImgTermBrowser"
              . "&page=imgTermDetail&term_oid=";
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
            my $s;
            for my $term_oid (@lhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
            print " => <br/> ";
            my $s;
            for my $term_oid (@rhs_term_oids) {
                my $n        = $root->findNode($term_oid);
                my $term_oid = FuncUtil::termOidPadded( $n->{term_oid} );
                my $term     = $n->{term};
                my $url      = $url0 . $n->{term_oid};
                my $link     = alink( $url, $term_oid );
                $s .= $link . " " . escHtml($term) . " +<br/>";
            }
            $s = substr( $s, 0, length($s) - 7 );
            print $s;
	    print "</div>\n" if $yui_tables;
            print "</td>\n";
        }
        ## Totally empty definition
        else {
            print "<td class='$classStr'>\n";
	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
	    print nbsp(1);
	    print "</div>\n" if $yui_tables;
	    print "</td>\n";
        }
        print "<td class='$classStr' style='text-align:right'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
        my @genes = printTermGenes( $dbh, $taxon_oid, \@all_term_oids );
	print "</div>\n" if $yui_tables;
        print "</td>\n";

	if ( $cluster_id ) {
	    print "<td class='$classStr' style='text-align:right'>\n";
	    print "<div class='yui-dt-liner'>\n" if $yui_tables;
	    for my $gene2 ( @genes ) {
		print $gene2 . " ";
	    }
	    print "</div>\n" if $yui_tables;
	    print "</td>\n";
	}

        print "</tr>\n";
        $idx++;
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "<p>\n";
    print "Add selected terms to function cart.<br/>\n";
    print "</p>\n";
    WebUtil::printFuncCartFooterForEditor();

}

############################################################################
# printTermGenes - Print list of gene_oid's for terms.
############################################################################
sub printTermGenes {
    my ( $dbh, $taxon_oid, $term_oids_aref ) = @_;

    my %term_h;
    for my $term_oid (@$term_oids_aref) {
	$term_h{$term_oid} = 1;
	my $child_term_list = findAllChildTerms($dbh, $term_oid);
	if ( $child_term_list ) {
	    my @term_arr = split(/\t/, $child_term_list);
	    for my $t2 ( @term_arr ) {
		$term_h{$t2} = 1;
	    }
	}
    }

    my %done;
#    for my $term_oid (@$term_oids_aref) {
    for my $term_oid (keys %term_h) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#        my $sql = qq{
#           select g.gene_oid
#    	   from dt_img_term_path tp, gene_img_functions g
#    	   where tp.term_oid = ?
#           and tp.map_term = g.function
#           and g.taxon = ?
#    	   $rclause
#    	   $imgClause
#        };
        my $sql = qq{
           select g.gene_oid
           from gene_img_functions g
           where g.function = ?
           and g.taxon = ?
           $rclause
           $imgClause
        };

        my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $taxon_oid );
        for ( ; ; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;
            next if $done{$gene_oid};

            my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
            $url .= "&gene_oid=$gene_oid";
            print alink( $url, $gene_oid ) . "<br/>\n";
            $done{$gene_oid} = 1;
        }
        $cur->finish();
    }
    my @keys  = keys(%done);
    my $nKeys = @keys;
    if ( $nKeys == 0 ) {
        print nbsp(1);
    }

    return @keys;
}

############################################################################
# getReactionCompounds - Get the compounds from the table
#   img_reaction_c_components.   This is the complement to
#   reaction.rxn_defition for metabolic reactions.
############################################################################
sub getReactionCompounds {
    my ( $dbh, $rxn_oid ) = @_;
    my $sql = qq{
       select ic.compound_oid, ic.compound_name, ircc.c_type
       from img_reaction_c_components ircc, img_compound ic
       where ircc.rxn_oid = ?
       and ircc.compound = ic.compound_oid
       order by ircc.c_type, ircc.stoich
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    my @lhs;
    my @rhs;
    for ( ; ; ) {
        my ( $compound_oid, $compound_name, $c_type ) = $cur->fetchrow();
        last if !$compound_oid;
        if ( $c_type eq "LHS" ) {
            push( @lhs, $compound_name );
        } elsif ( $c_type eq "RHS" ) {
            push( @rhs, $compound_name );
        } else {
            webLog("getReactionCompounds: unknown c_type='$c_type'\n");
        }
    }
    $cur->finish();

    my $nLhs = @lhs;
    my $nRhs = @rhs;

    ## Generate reaction definition string.
    my $s;
    for my $c (@lhs) {
        $s .= "$c + ";
    }
    chop $s;
    chop $s;
    $s .= " <=> " if $nLhs > 0 && $nLhs > 0;
    for my $c (@rhs) {
        $s .= "$c + ";
    }
    chop $s;
    chop $s;

    #$s .= " (IMG definition)";
    return $s;
}

############################################################################
# printRxnTaxons - Print taxon list for a given reaction in a pathway.
############################################################################
sub printRxnTaxons {
    my $pway_oid = param("pway_oid");
    my $rxn_oid  = param("rxn_oid");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    print "<h1>Genomes with IMG Pathway Reaction</h1>\n";
    my $sql = qq{
        select ir.rxn_name
    	from img_reaction ir
    	where ir.rxn_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    my $rxn_name = $cur->fetchrow();
    $cur->finish();
    
    print "<p>\n";
    print "Genomes with <i>" . escHtml($rxn_name) . ".</i>\n";
    print "</p>\n";

    my $url = "$section_cgi&page=rxnPhyloDist";
    $url .= "&pway_oid=$pway_oid";
    $url .= "&rxn_oid=$rxn_oid";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );

    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);
    my %taxon2GeneCount;
    pwayRxn2Taxons( $dbh, $root, $pway_oid, $rxn_oid, \%taxon2GeneCount );

    my @taxon_oids = keys(%taxon2GeneCount);
    my @taxonRecs;
    getTaxonOidNames( $dbh, \@taxon_oids, \@taxonRecs );
    #$dbh->disconnect();

    my $select_id_name = "taxon_filter_oid";
    
    my $baseUrl = "$section_cgi&page=rxnTaxons";
    $baseUrl .= "&pway_oid=$pway_oid";
    $baseUrl .= "&rxn_oid=$rxn_oid";
    
    my $ct = new CachedTable( "rxnTaxons$rxn_oid", $baseUrl );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome",     "char asc",    "left" );
    $ct->addColSpec( "Gene Count", "number desc", "right" );
    my $sdDelim = CachedTable::getSdDelim();

    my $count   = 0;
    for my $taxonRec (@taxonRecs) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name ) =
          split( /\t/, $taxonRec );
        last if !$taxon_oid;
        my $cnt = $taxon2GeneCount{$taxon_oid};
        $count++;
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";
        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .=
          $taxon_display_name . $sdDelim
          . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=imgPwayTaxonGenes";
        $url .= "&pway_oid=$pway_oid";
        $url .= "&rxn_oid=$rxn_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
        $ct->addRow($r);
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if ($count > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $ct->printTable();
    WebUtil::printGenomeCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }


    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgPwayTaxonGenes - Show genes for a given pathway reaction
#   and taxon.
############################################################################
sub printImgPwayTaxonGenes {
    my $pway_oid  = param("pway_oid");
    my $rxn_oid   = param("rxn_oid");
    my $taxon_oid = param("taxon_oid");

    printStatusLine( "Loading ...", 1 );

    my $dbh                = dbLogin();
    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    my %geneOids_h;
    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);
    pwayRxn2TaxonGenes( $dbh, $root, $pway_oid, $rxn_oid, $taxon_oid,
                        \%geneOids_h );

    my @gene_oids = sort( keys(%geneOids_h) );

    my $title    = "Genes in Pathway";
    my $subtitle = "Genes in <i>" . escHtml($taxon_display_name) . "</i> \n";
    HtmlUtil::printGeneListHtmlTable( $title, $subtitle, $dbh, \@gene_oids );
}

############################################################################
# printImgPwayPhyloDist - Print phylogenetic distribution for pathway.
############################################################################
sub printImgPwayPhyloDist {
    my $pway_oid = param("pway_oid");

    my $dbh = dbLogin();
    my $sql = qq{
        select ipw.pathway_name
	from img_pathway ipw
	where ipw.pathway_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my $name = $cur->fetchrow();
    $cur->finish();

    printMainForm();
    print "<h1>Phylogenetic Distribution for IMG Pathway</h1>\n";
    print "<p>\n";
    print "(Hits are shown in red.)<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections");

    my %taxon2GeneCount;
    my @terms  = getPwayTerms( $dbh, $pway_oid );
    my $tnMgr  = new ImgTermNodeMgr();
    my $tnRoot = $tnMgr->loadTree($dbh);
    imgTerms2Taxons( $dbh, $tnRoot, $pway_oid, \@terms, \%taxon2GeneCount );
    my @taxon_oids = keys(%taxon2GeneCount);
    for my $taxon_oid (@taxon_oids) {
        my $cnt = $taxon2GeneCount{$taxon_oid};
        $mgr->setCount( $taxon_oid, $cnt );
    }
    if ($show_private) {
        require TreeQ;
        TreeQ::printAppletForm( \@taxon_oids );
    }
    print "<p>\n";
    print "Distribution for <i>" . escHtml($name) . "</i>.<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printRxnPhyloDist - Print phylogenetic distribution for reaction.
############################################################################
sub printRxnPhyloDist {
    my $pway_oid = param("pway_oid");
    my $rxn_oid  = param("rxn_oid");

    my $dbh = dbLogin();
    my $sql = qq{
        select ir.rxn_name
	from img_reaction ir
	where ir.rxn_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rxn_oid );
    my $name = $cur->fetchrow();
    $cur->finish();

    printMainForm();
    print "<h1>Phylogenetic Distribution for Reaction</h1>\n";

    printStatusLine( "Loading ...", 1 );

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections");
    my $tnMgr  = new ImgTermNodeMgr();
    my $tnRoot = $tnMgr->loadTree($dbh);
    my %taxon2GeneCount;
    pwayRxn2Taxons( $dbh, $tnRoot, $pway_oid, $rxn_oid, \%taxon2GeneCount );
    my @taxon_oids = keys(%taxon2GeneCount);
    for my $taxon_oid (@taxon_oids) {
        my $cnt = $taxon2GeneCount{$taxon_oid};
        $mgr->setCount( $taxon_oid, $cnt );
    }
    #$dbh->disconnect();

    if ($show_private) {
        require TreeQ;
        TreeQ::printAppletForm( \@taxon_oids );
    }
    print "<p>\n";
    print "Distribution for <i>" . escHtml($name) . "</i>.<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printAssocGenomes - Print associtiations with genomes.
#   "Assertion" is simple one gene assocation.
############################################################################
sub printAssocGenomes {
    my ( $dbh, $root, $pway_oid, $terms_ref ) = @_;

    print "<h2>Associated Genomes</h2>\n";
    my %taxon2GeneCount;
    imgTerms2Taxons( $dbh, $root, $pway_oid, $terms_ref, \%taxon2GeneCount );
    my @taxon_oids = sort( keys(%taxon2GeneCount) );
    my $nTaxons    = @taxon_oids;
    if ( $nTaxons == 0 ) {
        print "<p>\n";
        print "No associated genomes with at least one gene ";
        print "associated with pathway terms were found.<br/>\n";
        print "</p>\n";
        return;
    }

    my %assert;
    my $sql = qq{ 
        select ipa.taxon, ipa.status, ipa.evidence 
            from img_pathway_assertions ipa
            where ipa.pathway_oid = ? 
        };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    for ( ; ; ) {
        my ( $t_oid, $status, $evid ) = $cur->fetchrow();
        last if !$t_oid;

        #       $assert{$t_oid} = $status . " (" . $evid . ")";
        $assert{$t_oid} = $status;
    }
    $cur->finish();

    my @taxonRecs;
    getTaxonOidNames( $dbh, \@taxon_oids, \@taxonRecs );
    
    print "<p>\n";
    print "The following genomes have at least one gene ";
    print "associated with the pathway.<br/>\n";
    print "</p>\n";

    my $select_id_name = "taxon_filter_oid";
        
    my $url = "$section_cgi&page=imgPwayPhyloDist&pway_oid=$pway_oid";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );
    
    my $ct = new InnerTable( 0, "pwayAssoc$$", "pwayAssoc", 0 );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome",                "char asc",    "left" );
    $ct->addColSpec( "Pathway<br/>Assertion", "char asc",    "left" );
    $ct->addColSpec( "Gene<br/>Count",        "number desc", "right" );
    my $sdDelim = InnerTable::getSdDelim();

    for my $r (@taxonRecs) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name ) =
          split( /\t/, $r );
        my $gene_count = $taxon2GeneCount{$taxon_oid};
        my $url        =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .=
          $taxon_display_name . $sdDelim
          . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=pwayAssocGeneList";
        $url .= "&pway_oid=$pway_oid";
        $url .= "&taxon_oid=$taxon_oid";

        # assertion
        if ( $assert{$taxon_oid} ) {
            my $assert_url =
                "$main_cgi?section=ImgPwayBrowser"
              . "&page=pwayTaxonDetail"
              . "&pway_oid=$pway_oid&taxon_oid=$taxon_oid";
            $r .=
              $assert{$taxon_oid} . $sdDelim
              . alink( $assert_url, $assert{$taxon_oid} ) . "\t";
        } else {
            $r .= "\t";
        }

        # gene count
        $r .= $gene_count . $sdDelim . alink( $url, $gene_count ) . "\t";

        $ct->addRow($r);
    }
    
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if (scalar(@taxonRecs) > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $ct->printOuterTable(1);
    WebUtil::printGenomeCartFooter();

    if (scalar(@taxonRecs) > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }
    
}

############################################################################
# printPwayAssocGeneList - Show genes with terms asserted in pathway
#   for a given genome.
############################################################################
sub printPwayAssocGeneList {
    my $pway_oid  = param("pway_oid");
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my %geneOids_h;
    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);
    if ( $cluster_id ) {
	imgTermCluster2Genes( $dbh, $root, $pway_oid, $taxon_oid, 
			      $cluster_id, \%geneOids_h );
    }
    else {
	imgTermTaxon2Genes( $dbh, $root, $pway_oid, $taxon_oid, 
			    \%geneOids_h );
    }
    my @gene_oids = sort( keys(%geneOids_h) );

    my $title = "Genes Connected to Pathway";
    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );
    my $subtitle = "Genes in <i>" . escHtml($taxon_display_name) . "</i> ";
    $subtitle .= "that are connected to pathway are shown below.<br/>\n";
    HtmlUtil::printGeneListHtmlTable( $title, $subtitle, $dbh, \@gene_oids );
}

############################################################################
# printAssertedGenomes - Print "asserted" genomes.
#   (Definition of "asserted" is handled externally,
#    but defined in the data.)
############################################################################
sub printAssertedGenomes_old {
    my ( $dbh, $pway_oid ) = @_;

    print "<h2>Asserted Genomes</h2>\n";

    my $taxonClause = txsClause("tx.taxon_oid", $dbh);
    my $rclause     = WebUtil::urClause('tx');
    my $imgClause   = WebUtil::imgClause('tx');
    my $sql = qq{
	select 
	   tx.domain,
	   tx.seq_status, 
	   ipa.pathway_oid, tx.taxon_oid, tx.taxon_display_name,
	   ipa.status
	from img_pathway_assertions ipa, taxon tx
	where ipa.taxon = tx.taxon_oid
	and ipa.pathway_oid = ?
	$taxonClause
	$rclause
	$imgClause
	order by tx.taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my @recs;

    for ( ; ; ) {
        my ( $domain, $seq_status, $pathway_oid, $taxon_oid,
             $taxon_display_name, $status )
          = $cur->fetchrow();
        last if !$pathway_oid;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $r;
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$pathway_oid\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$status\t";
        push( @recs, $r );
    }
    $cur->finish();
    if ( scalar(@recs) == 0 ) {
        print "<p>\n";
        print "This pathway has no asserted genomes.<br/>\n";
        print "</p>\n";
        return;
    }
    my $baseUrl = "$section_cgi&page=imgPwayDetail&pway_oid=$pway_oid";
    my $ct = new CachedTable( "pwayAssert$pway_oid", $baseUrl );
    $ct->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome", "char asc", "left" );
    $ct->addColSpec( "Status", "char asc", "left" );
    my $sdDelim = CachedTable::getSdDelim();

    for my $r0 (@recs) {
        my ( $domain, $seq_status, $pathway_oid, $taxon_oid,
             $taxon_display_name, $status )
          = split( /\t/, $r0 );
        $status = " " if $status eq "";
        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r;
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .=
          $taxon_display_name . $sdDelim
          . alink( $url, $taxon_display_name ) . "\t";
        $r .= "$status\t";
        $ct->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    $ct->printTable();
}

############################################################################
# imgTerms2Taxons - Get taxons from recursive list of IMG terms.
############################################################################
sub imgTerms2Taxons {
    my ( $dbh, $root, $pway_oid, $terms_ref, $taxon2GeneCount_ref ) = @_;

    my %term_oids_h;
    for my $term_oid0 (@$terms_ref) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("imgTerm2Pathways: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webLog(   "imgTerms2taxons: ERROR no term_oids retrieved "
                . "for pway_oid=$pway_oid\n" );
        return;
    }
    my $taxonClause = txsClause('g.taxon', $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $rxnClause;
    my $sql = qq{
        select g.taxon, count( distinct g.gene_oid )
        from gene_img_functions g
        where g.function in( $term_oid_str )
    	$rclause
    	$imgClause
    	group by g.taxon
    	order by g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon, $gene_count ) = $cur->fetchrow();
        last if !$taxon;
        $taxon2GeneCount_ref->{$taxon} = $gene_count;
    }
    $cur->finish();
}

############################################################################
# imgTermTaxon2Genes - Get genes from recursive list of IMG terms
#     and taxons.
############################################################################
sub imgTermTaxon2Genes {
    my ( $dbh, $root, $pway_oid, $taxon_oid, $geneOids_ref ) = @_;

    my @term_oids0 = getPwayTerms( $dbh, $pway_oid );
    my %term_oids_h;
    for my $term_oid0 (@term_oids0) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("imgTerm2Pathways: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webLog(   "imgTerms2taxons: ERROR no term_oids retrieved for "
                . "pway_oid=$pway_oid taxon_oid=$taxon_oid\n" );
        return;
    }
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql         = qq{
        select g.gene_oid
        from gene_img_functions g
        where g.function in( $term_oid_str )
    	and g.taxon = ?
    	$rclause
    	$imgClause
    	$taxonClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOids_ref->{$gene_oid} = $gene_oid;
    }
    $cur->finish();
}

############################################################################
# imgTermCluster2Genes - Get genes from recursive list of IMG terms
#     and clusters.
############################################################################
sub imgTermCluster2Genes {
    my ( $dbh, $root, $pway_oid, $taxon_oid, $cluster_id,
	 $geneOids_ref ) = @_;

    my @term_oids0 = getPwayTerms( $dbh, $pway_oid );
    my %term_oids_h;
    for my $term_oid0 (@term_oids0) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("imgTerm2Pathways: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webLog(   "imgTerms2taxons: ERROR no term_oids retrieved for "
                . "pway_oid=$pway_oid taxon_oid=$taxon_oid\n" );
        return;
    }
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql         = qq{
        select g.gene_oid
        from gene_img_functions g, bio_cluster_features_new bcg
        where g.function in( $term_oid_str )
    	and g.taxon = ?
        and bcg.cluster_id = ?
        and g.gene_oid = bcg.gene_oid
    	$rclause
    	$imgClause
    	$taxonClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $cluster_id );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOids_ref->{$gene_oid} = $gene_oid;
    }
    $cur->finish();
}

############################################################################
# getPwayTerms - Get terms from pathway.
############################################################################
sub getPwayTerms {
    my ( $dbh, $pway_oid ) = @_;
    my $sql = qq{
        select irc.catalysts
	from img_pathway_reactions ipr, img_reaction_catalysts irc
        where ipr.rxn = irc.rxn_oid
	and ipr.pathway_oid = ?
	    union
        select rtc.term
	from img_pathway_reactions ipr, img_reaction_t_components rtc
        where ipr.rxn = rtc.rxn_oid
	and ipr.pathway_oid = ?
    };
    my %term_oids_h;
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $pway_oid );
    for ( ; ; ) {
        my ($term_oid) = $cur->fetchrow();
        last if !$term_oid;
        $term_oids_h{$term_oid} = $term_oid;
    }
    $cur->finish();
    return sort( keys(%term_oids_h) );

}

############################################################################
# getPwayAllTerms - Get all terms (includign child terms) from pathway.
############################################################################
sub getPwayAllTerms {
    my ( $dbh, $pway_oid ) = @_;
    
    my @terms = getPwayTerms($dbh, $pway_oid);
    my %term_h;
    my $term_oid = pop (@terms);
    my $cnt = 0;
    while ( $term_oid && $cnt < 200 ) {
	if ( $term_h{$term_oid} ) {
	    # already checked
	    next;
	}
	$term_h{$term_oid} = 1;

	my $term_str = findAllChildTerms($dbh, $term_oid);
	if ( $term_str ) {
	    my @c_terms = split(/\t/, $term_str);
	    for my $term2 ( @c_terms ) {
		if ( $term_h{$term2} ) {
		    # already checked
		    next;
		}
		push @terms, ( $term2 );
	    }
	}

	$term_oid = pop(@terms);
	$cnt++;
    }  # end while term_oid

    return (keys %term_h);
}


############################################################################
# getRxnTerms - Get terms from pathway and reaction.
############################################################################
sub getRxnTerms {
    my ( $dbh, $pway_oid, $rxn_oid ) = @_;
    my $sql = qq{
        select irc.catalysts
	from img_pathway_reactions ipr, img_reaction_catalysts irc
        where ipr.rxn = irc.rxn_oid
	and ipr.pathway_oid = ?
	and ipr.rxn = ?
	    union
        select rtc.term
	from img_pathway_reactions ipr, img_reaction_t_components rtc
        where ipr.rxn = rtc.rxn_oid
	and ipr.pathway_oid = ?
	and ipr.rxn = ?
    };
    my %term_oids_h;
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid, $rxn_oid, $pway_oid, $rxn_oid );
    for ( ; ; ) {
        my ($term_oid) = $cur->fetchrow();
        last if !$term_oid;
        $term_oids_h{$term_oid} = $term_oid;
    }
    $cur->finish();
    return sort( keys(%term_oids_h) );

}

############################################################################
# pwayRxn2TaxonCount - Get taxon count from pathway reaction.
############################################################################
sub pwayRxn2TaxonCount {
    my ( $dbh, $root, $pway_oid, $rxn_oid ) = @_;

    my @terms = getRxnTerms( $dbh, $pway_oid, $rxn_oid );
    my %term_oids_h;
    for my $term_oid0 (@terms) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("pwayRxn2TaxonCount: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webLog(   "pwayRxn2TaxonCount: ERROR no term_oids retrieved "
                . "for pway_oid=$pway_oid rxn_oid=$rxn_oid\n" );
        return;
    }
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $rxnClause;
    my $sql = qq{
        select count( distinct g.taxon )
        from gene_img_functions g
        where g.function in( $term_oid_str )
        $taxonClause
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $taxon_count = $cur->fetchrow();
    $cur->finish();
    return $taxon_count;
}

############################################################################
# pwayRxn2Taxons - Get taxons for reaction.
############################################################################
sub pwayRxn2Taxons {
    my ( $dbh, $root, $pway_oid, $rxn_oid, $taxon2GeneCount_ref ) = @_;

    my @terms = getRxnTerms( $dbh, $pway_oid, $rxn_oid );
    my %term_oids_h;
    for my $term_oid0 (@terms) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("pwayRxn2Taxons: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webDie(   "pwayRxn2Taxons: ERROR no term_oids retrieved for "
                . "pway_oid=$pway_oid rxn_oid=$rxn_oid\n" );
    }
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $rxnClause;
    my $sql = qq{
        select g.taxon, count( distinct g.gene_oid )
        from gene_img_functions g
        where g.function in( $term_oid_str )
        $taxonClause
    	$rclause
    	$imgClause
    	group by g.taxon
    	order by g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon, $cnt ) = $cur->fetchrow();
        last if !$taxon;
        $taxon2GeneCount_ref->{$taxon} = $cnt;
    }
    $cur->finish();
}

############################################################################
# pwayRxn2TaxonGenes - Get genes for a taxon in reaction and pathway.
############################################################################
sub pwayRxn2TaxonGenes {
    my ( $dbh, $root, $pway_oid, $rxn_oid, $taxon_oid, $geneOids_ref ) = @_;

    my @terms = getRxnTerms( $dbh, $pway_oid, $rxn_oid );
    my %term_oids_h;
    for my $term_oid0 (@terms) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("pwayRxn2TaxonGenes: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webDie( "pwayRxn2TaxonGenes: ERROR no term_oids retrieved "
              . "for pway_oid=$pway_oid rxn_oid=$rxn_oid taxon_oid=$taxon_oid\n"
        );
    }
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql         = qq{
        select distinct g.gene_oid
        from gene_img_functions g
        where g.function in( $term_oid_str )
    	and g.taxon = ?
        $taxonClause
    	$rclause
    	$imgClause
    	order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOids_ref->{$gene_oid} = $gene_oid;
    }
    $cur->finish();
}

############################################################################
# printImgPwayHistory - Show history for this particular pathway.
#   For internal use only.
############################################################################
sub printImgPwayHistory {
    my $pway_oid = param("pway_oid");

    my $dbh = dbLogin();
    print "<h1>IMG Pathway History</h1>\n";

    my $sql = qq{
	select iph.pathway, 
	   iph.author, c.email, iph.pathway_name_new, 
	   iph.pathway_name_old, iph.action, to_char(iph.add_date, 'yyyy-mm-dd')
	from img_pathway_history iph, contact c
	where iph.pathway = ?
	and iph.contact = c.contact_oid
	order by iph.add_date desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );

    # Use YUI css
    if ($yui_tables) {

	print <<YUI;
        <link rel="stylesheet" type="text/css"
            href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	.yui-nowrap {
	    white-space: nowrap;
	}
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Date</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Author</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>New Pathway</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Old Pathway</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Action</span>
	    </div>
	</th>
	</tr>
YUI
    } else {
	print "<table class='img' border='1'>\n";
	print "<th class='img'>Date</th>\n";
	print "<th class='img'>Author</th>\n";

	#print "<th class='img'>Email</th>\n";
	print "<th class='img'>New Pathway</th>\n";
	print "<th class='img'>Old Pathway</th>\n";
	print "<th class='img'>Action</th>\n";
    }

    my $idx = 0;
    my $classStr;
    for ( ; ; ) {
        my ( $pathway, $author, $email, $pathway_name_new, $pathway_name_old,
             $action, $add_date )
          = $cur->fetchrow();
        last if !$pathway;
        $pathway_name_new = "-" if $pathway_name_new eq "";
        $pathway_name_old = "-" if $pathway_name_old eq "";

	if ($yui_tables) {
	    $classStr = !$idx ? "yui-dt-first ":"";
	    $classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
	    $classStr .= " yui-nowrap";
	} else {
	    $classStr = "img";
	}

        print "<tr class='$classStr'>\n";
        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
	print escHtml($add_date);
	print "</div>\n" if $yui_tables;
	print "</td>\n";

        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
	print escHtml($author);
	print "</div>\n" if $yui_tables;
	print "</td>\n";

        #print "<td class='img'>" . emailLink( $email ) . "</td>\n";

        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>\n"
	    if $yui_tables;
	print escHtml($pathway_name_new);
	print "</div>\n" if $yui_tables;
	print "</td>\n";

        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>\n"
	    if $yui_tables;
	print escHtml($pathway_name_old);
	print "</div>\n" if $yui_tables;
	print "</td>\n";

        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>\n" if $yui_tables;
	print escHtml($action);
	print "</div>\n" if $yui_tables;
	print "</td>\n";

        print "</tr>\n";
	$idx++;
    }
    $cur->finish();
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    #$dbh->disconnect();
}

############################################################################
# printPartList - Print parts list.
############################################################################
sub printPartsList {
    my ($dbh) = @_;

    my $sql = qq{
       select pl.parts_list_oid, pl.parts_list_name
       from img_parts_list pl
       order by pl.parts_list_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $parts_list_oid, $parts_list_name ) = $cur->fetchrow();
        last if !$parts_list_oid;
        my $r = "$parts_list_oid\t";
        $r .= "$parts_list_name";
        push( @recs, $r );
    }
    $cur->finish();
    my $nRecs = @recs;
    return if $nRecs == 0;
    print "<h2>Parts List</h2>\n";
    print "<p>\n";
    print "Parts list organizes components involved ";
    print "in various cellular processes.<br/>\n";
    print "<p>\n";
    print "<p>\n";

    for my $r (@recs) {
        my ( $parts_list_oid, $parts_list_name ) = split( /\t/, $r );
        my $url = "$section_cgi&page=partsListDetail";
        $url .= "&parts_list_oid=$parts_list_oid";
        print alink( $url, $parts_list_name ) . "<br/>\n";
    }
    print "</p>\n";
}

############################################################################
# printPartsListDetail - Print details for a given parts list.
############################################################################
sub printPartsListDetail {
    my $parts_list_oid = param("parts_list_oid");

    print "<h1>Parts List Details</h1>\n";
    my $dbh = dbLogin();
    my $sql = qq{
        select pl.parts_list_oid, pl.parts_list_name,
	   pl.definition, to_char(pl.add_date, 'yyyy-mm-dd'), to_char(pl.mod_date, 'yyyy-mm-dd'),
	   c.name, c.email
	from img_parts_list pl, contact c
	where pl.modified_by = c.contact_oid
	and pl.parts_list_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $parts_list_oid );
    my ( $parts_list_oid, $parts_list_name, $definition, $add_date, $mod_date,
         $name, $email )
      = $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n";
    printAttrRow( "Parts List OID", $parts_list_oid );
    printAttrRow( "Name",           $parts_list_name );
    printAttrRow( "Definition",     $definition );
    printAttrRow( "Add Date",       $add_date );
    printAttrRow( "Modify Date",    $mod_date );
    my $s = escHtml($name);

    #$s .= emailLinkParen( $email );
    printAttrRowRaw( "Modified By", $s );
    print "</table>\n";

    print "<h3>IMG Terms</h3>\n";
    print "<p>\n";
    print "IMG terms specify components involved in the parts list.<br/>\n";
    print "</p>\n";
    printMainForm();

    WebUtil::printFuncCartFooterForEditor();
    my $sql = qq{
       select it.term_oid, it.term
       from img_term it, img_parts_list_img_terms plt
       where plt.term = it.term_oid
       and plt.parts_list_oid = ?
       order by plt.list_order
    };
    my $cur = execSql( $dbh, $sql, $verbose, $parts_list_oid );
    my $count = 0;
    print "<p>\n";
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;
        $term_oid = FuncUtil::termOidPadded($term_oid);
        $count++;
        print "<input type='checkbox' name='term_oid' value='$term_oid' />\n";
        my $url =
            "$main_cgi?section=ImgTermBrowser"
          . "&page=imgTermDetail&term_oid=$term_oid";
        print alink( $url, $term_oid );
        print nbsp(1);
        print escHtml($term);
        print "<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    WebUtil::printFuncCartFooterForEditor() if $count > 10;
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printAlphaList - Print alphabetical listing of pathways.
############################################################################
sub printAlphaList {
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $sql = qq{
       select ipw.pathway_oid, ipw.pathway_name
       from img_pathway ipw
       order by lower( ipw.pathway_name )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $pathway_oid, $pathway_name ) = $cur->fetchrow();
        last if !$pathway_oid;
        my $r = "$pathway_oid\t";
        $r .= "$pathway_name";
        push( @recs, $r );
    }
    $cur->finish();
    
    my $nRecs = @recs;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        print "No IMG pathways are found in this database.<br/>\n";
        print "</p>\n";
        return;
    }
    print "<h1>IMG Pathways (Alphabetical)</h1>\n";

    # stats
    #1. IMG Paths
    #2. IMG parts lists
    #3. IMG Paths connected to IMG Networks
    #4. IMG Paths not connected to IMG Networks
    #5. IMG Parts Lists connected to IMG Networks
    #6. IMG parts lists non connected to IMG Networks
    print "<table class='img'>\n";

    my $url = $section_cgi . "&page=statlist&type=";
    my $cnt = getStats1($dbh);
    my $tmp = alink( $url . "stat1", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Paths</th>
        <td class='img'   align='left'>  $cnt </td>
        </tr>
    };

    my $cnt = getStats2($dbh);
    my $tmp = alink( "main.cgi?section=ImgPartsListBrowser&page=browse", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Parts Lists</th>
        <td class='img'   align='left'> $tmp</td>
        </tr>
    };

    my $cnt = getStats3($dbh);
    my $tmp = alink( $url . "stat3", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Paths Connected to IMG Networks</th>
        <td class='img'   align='left'> $tmp</td>
        </tr>
    };

    my $cnt = getStats4($dbh);
    my $tmp = alink( $url . "stat4", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Paths Not Connected to IMG Networks</th>
        <td class='img'   align='left'> $tmp</td>
        </tr>
    };

    my $cnt = getStats5($dbh);
    my $tmp = alink( $url . "stat5", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Parts Lists Connected to IMG Networks</th>
        <td class='img'   align='left'> $tmp</td>
        </tr>
    };

    my $cnt = getStats6($dbh);
    my $tmp = alink( $url . "stat6", $cnt );
    $tmp = $cnt if ( $cnt == 0 );
    print qq{
        <tr class='img' >
        <th class='subhead' align='right'>IMG Parts Lists not Connected to IMG Networks</th>
        <td class='img'   align='left'> $tmp</td>
        </tr>
    };

    print "</table><br/>\n";

    #$dbh->disconnect();

    WebUtil::printMainFormName("3");

    my $select_id_name = "pway_oid";

    my $it = new InnerTable( 1, "imgpathwaylist$$", "imgpathwaylist", 2 );
    $it->addColSpec("Select");
    $it->addColSpec( "Pathway ID",   "number asc", "right" );
    $it->addColSpec( "Pathway Name", "char asc",   "left" );
    my $sd = $it->getSdDelim();

    my $count = 0;
    for my $r (@recs) {
        my ( $pathway_oid, $pathway_name ) = split( /\t/, $r );
        my $pway_oid = FuncUtil::pwayOidPadded($pathway_oid);
        $count++;
        my $r;
        $r .= $sd
          . "<input type='checkbox' name='$select_id_name' value='$pway_oid' />"
          . "\t";
        my $url = "$section_cgi&page=imgPwayDetail&pway_oid=$pway_oid";
        $r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
        $r .= $pathway_name . $sd . escHtml($pathway_name) . "\t";
        $it->addRow($r);
    }


    WebUtil::printFuncCartFooterForEditor("3") if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooterForEditor("3");

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'pway_oid' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();

    printJavaScript();
}

sub getStats1 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(*) from img_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getStats2 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(*) from img_parts_list
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getStats3 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(distinct p1.pathway_oid) 
        from img_pathway p1, pathway_network_img_pathways p2
        where p1.pathway_oid = p2.pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getStats4 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(distinct p1.pathway_oid) 
        from img_pathway p1
        where not exists (select 1 from pathway_network_img_pathways p2
        where p1.pathway_oid = p2.pathway)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getStats5 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(distinct p1.parts_list_oid) 
        from img_parts_list p1, pathway_network_parts_lists p2
        where p1.parts_list_oid = p2.parts_list
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getStats6 {
    my ($dbh) = @_;
    my $sql = qq{
        select count(distinct p1.parts_list_oid) 
        from img_parts_list p1
        where not exists (select 1 from pathway_network_parts_lists p2
        where p1.parts_list_oid = p2.parts_list)        
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub printStatList {
    my $type = param("type");

    printMainForm();

    if ( $type eq "stat3" ) {
        print "<h1>IMG Paths connected to IMG Networks</h1>";
    } elsif ( $type eq "stat4" ) {
        print "<h1>IMG Paths not connected to IMG Networks</h1>";
    } elsif ( $type eq "stat5" ) {
        print "<h1>IMG Parts Lists connected to IMG Networks</h1>";
    } elsif ( $type eq "stat6" ) {
        print "<h1>IMG parts lists non connected to IMG Networks</h1>";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql;
    my $cur;
    if ( $type eq "stat3" ) {
        $sql = qq{
        select distinct p1.pathway_oid, p1.pathway_name 
        from img_pathway p1, pathway_network_img_pathways p2
        where p1.pathway_oid = p2.pathway    
        };
    } elsif ( $type eq "stat4" ) {
        $sql = qq{
        select distinct p1.pathway_oid, p1.pathway_name
        from img_pathway p1
        where not exists (select 1 from pathway_network_img_pathways p2
            where p1.pathway_oid = p2.pathway)    
        };
    } elsif ( $type eq "stat5" ) {
        $sql = qq{
        select distinct p1.parts_list_oid, p1.parts_list_name 
        from img_parts_list p1, pathway_network_parts_lists p2
        where p1.parts_list_oid = p2.parts_list            
        };
    } elsif ( $type eq "stat6" ) {
        $sql = qq{
        select distinct p1.parts_list_oid, p1.parts_list_name 
        from img_parts_list p1
        where not exists (select 1 from pathway_network_parts_lists p2
        where p1.parts_list_oid = p2.parts_list)
        };
    }

    my $it    = new InnerTable( 1, "imgpath$$", "imgpath", 1 );
    my $sd    = $it->getSdDelim();                              # sort delimiter
    $it->addColSpec("Select");
    if ( $type eq "stat5" || $type eq "stat6" ) {
        $it->addColSpec( "IMG Part ID", "numberr asc", "right" );
    } else {
        $it->addColSpec( "IMG Pathway ID", "numberr asc", "right" );
    }
    $it->addColSpec( "Name", "char asc", "left" );

    $cur = execSql( $dbh, $sql, $verbose );
        
    my $count = 0;
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;
        $count++;
        my $r;

        my $toid = FuncUtil::termOidPadded($oid);

        if ( $type eq "stat5" || $type eq "stat6" ) {
            $r .= $sd
              . "<input type='checkbox' name='parts_list_oid' "
              . "value='$toid' />" . "\t";
            my $url =
              "main.cgi?section=ImgPartsListBrowser&page=partsListDetail";
            $url .= "&parts_list_oid=$toid";
            $r   .= $oid . $sd . alink( $url, $toid ) . "\t";

        } else {

            $r .= $sd
              . "<input type='checkbox' name='pway_oid' "
              . "value='$toid' />" . "\t";
            my $url = "$section_cgi&page=imgPwayDetail";
            $url .= "&pway_oid=$toid";
            $r .= $oid . $sd . alink( $url, $toid ) . "\t";
        }

        $r .= $name . $sd . $name . "\t";

        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    if ($count > 10) {
        if ( $type eq "stat5" || $type eq "stat6" ) {
            WebUtil::printFuncCartFooterForEditor();
        } else {
            WebUtil::printFuncCartFooterForEditor();
        }
    }
    $it->printOuterTable(1);
    if ( $type eq "stat5" || $type eq "stat6" ) {
        WebUtil::printFuncCartFooterForEditor();
    } else {
        WebUtil::printFuncCartFooterForEditor();
    }

    if ($count > 0) {
        if ( $type eq "stat5" || $type eq "stat6" ) {
            print hiddenVar( 'save_func_id_name', 'parts_list_oid' );
            WorkspaceUtil::printSaveFunctionToWorkspace('parts_list_oid');
        } else {
            print hiddenVar( 'save_func_id_name', 'pway_oid' );
            WorkspaceUtil::printSaveFunctionToWorkspace('pway_oid');
        }
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();

}

############################################################################
# printPhenoRules
############################################################################
sub printPhenoRules {
    my $text = "A phenotype is broadly defined as an observable characteristic of an organism. Current phenotypes in IMG are predicted using a set of rules based on IMG`s collection of pathways and parts. Follow the link provided by <b>Rule ID</b> to view the information for the selected rule.";

    my $link = "<img src=$base_url/images/application-table.png width=11 height=11 border=0 alt=table</img>";
 
    my $text2 = "";
    if ($img_pheno_rule_saved) {
	$text2 = "Follow the link provided by <b>No. of Genomes w/ Phenotype</b> to the list of genomes associated with a specific phenotype. Click on the number to view the results in tree display, or click on $link to view the results in table display.";
    }

    my $description = "$text $text2";
    if ($include_metagenomes) { 
        WebUtil::printHeaderWithInfo 
            ("Predicted Phenotypes", $description, 
             "show description for this tool", "Phenotype Info", 1);
    } else { 
        WebUtil::printHeaderWithInfo 
            ("Predicted Phenotypes", $description,
             "show description for this tool", "Phenotype Info");
    } 
    print "<p>$description</p>";

    print "<p>For more information on phenotype rules and prediction, please refer to: " .
	alink("http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0054859", "PLoS ONE 8(2): e54859. doi:10.1371/journal.pone.0054859");

    if ( !$img_pheno_rule ) {
        print "<p>No predicated phenotypes have been defined.</p>\n";
        return;
    }

#### BEGIN updated table +BSJ 04/15/10

    printMainForm();
    my $it = new InnerTable( 1, "PhenoRules$$", "PhenoRules", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Rule ID",        "asc", "right" );
    $it->addColSpec( "Name",           "asc", "left" );
    $it->addColSpec( "Category",       "asc", "left" );
    $it->addColSpec( "Category Value", "asc", "left" );
    $it->addColSpec( "Description",    "asc", "left" );

    my $print_rule = 0;
    if ($print_rule) {
	$it->addColSpec( "Rule" );
    }

    if ($img_pheno_rule_saved) {
	$it->addColSpec( "No. of Genomes w/ Phenotype", 
			 "desc", "right", "", "", "wrap" );
    }

    my $dbh = dbLogin();
    if ( !WebUtil::tableExists( $dbh, 'phenotype_rule' ) ) {
        #$dbh->disconnect();
        print "<p>No predicated phenotypes have been defined.</p>\n";
        print end_form();
        return;
    }

    my %genomes;
    if ( $img_pheno_rule && $img_pheno_rule_saved ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql3    = qq{
	    select prt.rule_id, count(*)
		from taxon tx, phenotype_rule_taxons prt
		where tx.taxon_oid = prt.taxon
		$rclause
		$imgClause
		group by prt.rule_id
        };

        my $cur3 = execSql( $dbh, $sql3, $verbose );
        for ( ; ; ) {
            my ( $r_id, $cnt3 ) = $cur3->fetchrow();
            last if !$r_id;

            $r_id = FuncUtil::oidPadded( 'PHENOTYPE_RULE', $r_id );
            $genomes{$r_id} = $cnt3;
        }

        $cur3->finish();
    }

    my $sql = qq{
        select pr.rule_id, pr.name, pr.cv_type, pr.cv_value,
        pr.description, pr.rule,
        to_char(pr.add_date, 'yyyy-mm-dd'), 
        to_char(pr.mod_date, 'yyyy-mm-dd'), c.name
        from phenotype_rule pr, contact c
	where pr.modified_by = c.contact_oid
	order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
             $rule_id, $name,     $cv_type,  $cv_value, $descr,
             $rule,    $add_date, $mod_date, $modified_by
          )
          = $cur->fetchrow();
        last if !$rule_id;

        $rule_id = FuncUtil::oidPadded( 'PHENOTYPE_RULE', $rule_id );

        # rule ID
        my $rule_url =
            "$main_cgi?section=$section"
          . "&page=PhenotypeRuleDetail"
          . "&rule_id=$rule_id";

	my $row .= $rule_id . $sd . alink( $rule_url, $rule_id ) . "\t";
	$row .= $name . $sd . escapeHTML($name) . "\t";
	my $category = DataEntryUtil::getGoldAttrDisplayName($cv_type);
	$row .= $category . $sd . $category . "\t";
	$row .= $cv_value . $sd . $cv_value . "\t";
	$row .= $descr . $sd . escapeHTML($descr) . "\t";

        # rule
        if ($print_rule) {
	    $row .= $sd;
            my @and_rules = split( /\,/, $rule );
            my $i         = 0;
            my $j         = 0;
           for my $r1 (@and_rules) {
                if ( $i > 0 ) {
		    $row .= " AND ";
                }

                if ( length($r1) >= 2 ) {
                    $r1 = substr( $r1, 1, length($r1) - 2 );
                }
                my @or_rules = split( /\|/, $r1 );
                $j = 0;

                for my $r2 (@or_rules) {
                    my $pathway_oid = 0;
                    my $not_flag    = 0;
                    if ( $r2 =~ /\!(\d+)/ ) {
                        $pathway_oid = $1;
                        $not_flag    = 1;
                    } elsif ( $r2 =~ /(\d+)/ ) {
                        $pathway_oid = $1;
                    }

                    if ( $j == 0 ) {
			$row .= " ( ";
                    } else {
			$row .= " OR ";
                    }

                    if ($pathway_oid) {
                        my $func_id = "IPWAY:" . FuncUtil::pwayOidPadded($pathway_oid);
                        my $url     =
                          FuncUtil::getUrl( $main_cgi, "IMG_PATHWAY", $pathway_oid );
                        my $link = alink( $url, $func_id );

                        my $pathway_name =
                          db_findVal( $dbh, 'img_pathway', 'pathway_oid',
                                      $pathway_oid, 'pathway_name', '' );

                        if ($not_flag) {
			    $row .= "<b>NOT</b>" . nbsp(1);
                        }
                        $row .= $link . ": " . escapeHTML($pathway_name);
                    }

                    $j++;
                }    # for r2

		$row .= nbsp(1) . " ) ";

                $i++;
            }    # for r1
	    $row .= "\t";
        }

        if ($img_pheno_rule_saved) {
            if ( $genomes{$rule_id} ) {
                my $url3 =
                    "$main_cgi?section=ImgPwayBrowser"
                  . "&page=showPhenoTaxons"
                  . "&rule_id=$rule_id";
                $url3 = alink( $url3, $genomes{$rule_id} );
		$row .= $genomes{$rule_id} . $sd . $url3;

		# image for table view
		my $tbl_link .= "<a href='" . url() .
		    "?section=ImgPwayBrowser&page=showPhenoTaxonsTable" .
		    "&rule_id=$rule_id" . "' >"; 
		$tbl_link .= "<img src='$base_url/images/application-table.png' width='11' height='11' border='0' alt='table' /> ";
		$tbl_link .= "</a>";
		$row .= " " . $tbl_link;
		$row .= "\t";
            } else {
		$row .= " " . $sd .nbsp(1) . "\t";
            }
        }
	$it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table +BSJ 04/15/10

    $cur->finish();
    #$dbh->disconnect();

    print end_form();
}

############################################################################
# printPhenotypeRuleDetail - show phenotype rule
############################################################################
sub printPhenotypeRuleDetail {
    my $rule_id = param('rule_id');

    printMainForm();

    print "<h1>Phenotype Rule</h1>\n";

    print hiddenVar( 'rule_id', $rule_id );

    my $dbh = dbLogin();
    my $sql = qq{ 
        select pr.rule_id, pr.name, pr.cv_type, pr.cv_value, 
        pr.description, pr.rule, pr.rule_type, 
        to_char(pr.add_date, 'yyyy-mm-dd'),
        to_char(pr.mod_date, 'yyyy-mm-dd'), c.name, c.email 
        from phenotype_rule pr, contact c 
        where pr.rule_id = ? 
        and pr.modified_by = c.contact_oid 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my (
         $r_id,     $rule_name,   $cv_type,   $cv_value,
         $descr,    $rule,        $rule_type, $add_date,
         $mod_date, $modified_by, $email
      )
      = $cur->fetchrow();
    $cur->finish();

    print "<h2>$rule_name</h2>\n";

    print "<table class='img' border='1'>\n";
    printAttrRow( "Rule ID", $rule_id );
    printAttrRow( "Name",    $rule_name );
    my $disp_type = DataEntryUtil::getGoldAttrDisplayName($cv_type);
    printAttrRow( "Category",       $disp_type );
    printAttrRow( "Category Value", $cv_value );
    printAttrRow( "Description",    $descr );
    printAttrRow( "Add Date",       $add_date );
    printAttrRow( "Last Mod Date",  $mod_date );

    my $c_name = $modified_by;
    if ( !blankStr($email) ) {
        $c_name .= " (" . $email . ")";
    }
    printAttrRow( "Modified By", $c_name );
    print "</table>\n";

    print "<h2>Rule</h2>\n";

    my @and_rules = split( /\,/, $rule );
    my $conn1     = 'AND';
    my $conn2     = 'or';

    if ( $rule_type =~ /OR/ ) {
        @and_rules = split( /\|/, $rule );
        $conn1     = 'OR';
        $conn2     = 'and';
    }

    my $i = 0;
    my $j = 0;
    for my $r1 (@and_rules) {
        if ( length($r1) >= 2 ) {
            $r1 = substr( $r1, 1, length($r1) - 2 );
        }
        my @or_rules = split( '\|', $r1 );
        if ( $rule_type =~ /OR/ ) {
            @or_rules = split( '\,', $r1 );
        }

        $j = 0;

        for my $r2 (@or_rules) {
            my $pathway_oid = 0;
            my $not_flag    = 0;
            if ( $r2 =~ /\!(\d+)/ ) {
                $pathway_oid = $1;
                $not_flag    = 1;
            } elsif ( $r2 =~ /(\d+)/ ) {
                $pathway_oid = $1;
            }

            print "<p>";
            if ( $j == 0 ) {
                if ( $i > 0 ) {
                    print nbsp(3) . " $conn1 ( ";
                } else {
                    print nbsp(3) . " ( ";
                }
            } else {
                print nbsp(4) . " $conn2 ";
            }

            if ($pathway_oid) {
                my $func_id = "IPWAY:" . FuncUtil::pwayOidPadded($pathway_oid);
                print
                  "<input type='checkbox' name='func_id' value='$func_id' />\n";
                my $url = FuncUtil::getUrl( $main_cgi, "IMG_PATHWAY", $pathway_oid );
                my $link = alink( $url, $func_id );

                my $pathway_name =
                  db_findVal( $dbh, 'img_pathway', 'pathway_oid', $pathway_oid,
                              'pathway_name', '' );

                if ($not_flag) {
                    print "<b>NOT</b>" . nbsp(1);
                }
                print $link . ": " . escapeHTML($pathway_name) . "\n";
            }

            $j++;
        }    # for r2

        print nbsp(1) . " ) ";

        $i++;
    }    # for r1

    #$dbh->disconnect();

    print "</p>\n";

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
    print nbsp(1);
    my $name = "_section_${section}_index";
    print submit(
                  -name  => $name,
                  -value => 'Cancel',
                  -class => 'smbutton'
    );

    my $contact_oid = getContactOid();

    if ( !$img_pheno_rule_saved && !$user_restricted_site ) {
        print end_form();
        return;
    }

    print "<h2>Find Genomes with this Phenotype</h2>\n";
    print "<p>* Only Archaea, Bacteria and Eukarya genomes are used.</p>\n";

    if ($img_pheno_rule_saved) {
        if ( $user_restricted_site && $contact_oid ) {
            print "<b>Use Pre-computed Results</b>";
            print "<p>This option uses pre-computed results. "
		. "It is fast, but does not reflect recent database changes.</p>";
        }

        $name = "_section_ImgPwayBrowser_showPhenoTaxons";
        print submit(
                      -name  => $name,
                      -value => "Show Genomes",
                      -class => "meddefbutton"
        );
    }

    if ( !$user_restricted_site ) {
        print end_form();
        return;
    }

    if ( !$contact_oid ) {
        return;
    }

    print "<br/><br/>";
    print "<b>Dynamic Search</b>\n";
    print "<p>Select domain: ";
    print nbsp(2);
    print "<select name='search_domain' class='img' size='1'>\n";
    print "    <option value='All'>All</option>\n";
    print "    <option value='Archaea'>Archaea</option>\n";
    print "    <option value='Bacteria'>Bacteria</option>\n";
    print "    <option value='Eukaryota'>Eukaryota</option>\n";
    print "</select>\n";

    print "<br/>";
    print "Select max number of returned genomes to limit your search: ";
    print nbsp(2);
    print "<select name='max_count' class='img' size='1'>\n";
    my $default_n = 1000;
    for my $cnt0 ( 1, 2, 3, 5, 10, 20, 30, 50, 100, 200, 500, 800, 1000, 2000, 3000, 5000, 8000, 10000, 15000, 20000 )
    {
        print "    <option value='$cnt0'";
	if ( $cnt0 == $default_n ) {
	    print " selected";
	}
	print ">$cnt0</option>\n";
    }
    print "</select>\n";
    print "<br/>\n";
    print "</p>\n";

    $name = "_section_ImgPwayBrowser_findPhenoTaxons";
    print submit(
                  -name  => $name,
                  -value => "Find Genomes",
                  -class => "meddefbutton"
    );

    print end_form();
}

#######################################################################
# printShowPhenoTaxons_tree()
#######################################################################
sub printShowPhenoTaxons_tree {
    my $rule_id = param('rule_id');
    my $show_all = param('show_all');

    printMainForm();

    my $dbh = dbLogin();
    my %taxon_filter; 

    my $sql = qq{
        select pr.rule_id, pr.name, pr.cv_type, pr.cv_value,
        pr.description, pr.rule,
        to_char(pr.add_date, 'yyyy-mm-dd'), 
        to_char(pr.mod_date, 'yyyy-mm-dd'), c.username
        from phenotype_rule pr, contact c
        where pr.rule_id = ?
        and pr.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my ( $r_id, $rule_name, $cv_type,  $cv_value, $descr,
         $rule, $add_date,  $mod_date, $modified_by
      ) = $cur->fetchrow();
    $cur->finish();

    my $url = 
	  "$main_cgi?section=$section" 
	. "&page=PhenotypeRuleDetail" 
	. "&rule_id=$rule_id"; 
    print "<h1>Genomes with Selected Phenotype</h1>\n";

    print "<p>\n";
    print "Phenotype Rule: ";
    print alink($url, escapeHTML($rule_name) . " ($rule_id)");
    print "</p>";

    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    $sql = qq{
        select tx.taxon_oid, tx.domain, tx.taxon_display_name,
               to_char(prt.mod_date, 'yyyy-mm-dd')
        from taxon tx, phenotype_rule_taxons prt
        where tx.taxon_oid = prt.taxon
        and prt.rule_id = ? 
        $rclause 
        $imgClause
        order by 2, 3
    };
    $cur = execSql( $dbh, $sql, $verbose, $rule_id );

    my $cnt = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $taxon_name, $date2 ) = $cur->fetchrow();
        last if !$taxon_oid;
    	$taxon_filter{$taxon_oid} = $taxon_oid;
        $cnt++;
        if ( $cnt > 2000000 ) {
            last;
        }
    }
    $cur->finish();

    printStatusLine( "$cnt genome(s) with selected phenotypes.", 2 );

    my $link = "";
    if ( $cnt > 0 ) {
    	print "<p>";
    	my $url2 = "main.cgi?section=ImgPwayBrowser&page=showPhenoTaxons"
                     . "&rule_id=$rule_id";
    
    	if ( $show_all ) {
    	    $url2 .= "&show_all=0";
                $link = alink( $url2, "Only show genomes with selected phenotype." );
    	}
    	else {
    	    $url2 .= "&show_all=1";
                $link = alink( $url2, "Display genomes with selected phenotype in complete tree.");
    	}
    	print "</p>\n";
    }
    else {
        print "<p><font color='red'>"
	    . "No genomes have the selected phenotype.</font></p>\n";
    	#$dbh->disconnect();
    
    	print end_form();
    	return;
    }

    printHint("Click on (v) or (x) to see rule prediction detail; " .
	      "(v) indicates that the genome is predicted to have the phenotype, " .
	      "and (x) indicates that the genome does not have the phenotype. <br/>"
	    . "$link");

    print "<p>\n";
    print domainLetterNoteNoVNoM() . "<br/>";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>";

    ### tree display
    my $mgr = new PhyloTreeMgr(); 
    $mgr->loadPhenotypeTree( $dbh, $rule_id, $show_all ); 
    $cur->finish();
    #$dbh->disconnect();

    my @keys             = keys(%taxon_filter); 
    my $taxon_filter_cnt = @keys; 

    printTaxonButtons ('');
    $mgr->printPhenotypeTree( \%taxon_filter, $taxon_filter_cnt,
			      $rule_name, $rule_id, $show_all ); 
    printTaxonButtons ('');

    if ($cnt > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace('taxon_filter_oid');
    }

    printStatusLine( "$cnt genome(s) loaded.", 2 );
    print end_form();
}

#######################################################################
# printShowPhenoTaxons_table()
#######################################################################
sub printShowPhenoTaxons_table {
    my $rule_id = param('rule_id');
    my $show_all = param('show_all');

    printMainForm();

    my $dbh = dbLogin();
    my %taxon_filter; 

    my $sql = qq{
        select pr.rule_id, pr.name, pr.cv_type, pr.cv_value,
        pr.description, pr.rule,
        to_char(pr.add_date, 'yyyy-mm-dd'),
        to_char(pr.mod_date, 'yyyy-mm-dd'), c.username
        from phenotype_rule pr, contact c
        where pr.rule_id = ?
        and pr.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my (
         $r_id, $rule_name, $cv_type,  $cv_value, $descr,
         $rule, $add_date,  $mod_date, $modified_by
      )
      = $cur->fetchrow();
    $cur->finish();

    my $url =
	  "$main_cgi?section=$section" 
        . "&page=PhenotypeRuleDetail" 
        . "&rule_id=$rule_id";
    print "<h1>Genomes with Selected Phenotype</h1>\n";

    print "<p>";
    print "Phenotype Rule: "; 
    print alink($url, escapeHTML($rule_name) . " ($rule_id)");
    print "</p>"; 

    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    $sql = qq{
        select tx.taxon_oid, tx.domain, tx.taxon_display_name,
               to_char(prt.mod_date, 'yyyy-mm-dd')
        from taxon tx, phenotype_rule_taxons prt
        where tx.taxon_oid = prt.taxon
        and prt.rule_id = ? 
        $rclause 
        $imgClause
        order by 2, 3
    };
    $cur = execSql( $dbh, $sql, $verbose, $rule_id );

    my $select_id_name = "taxon_filter_oid";

#### BEGIN updated table +BSJ 04/15/10
    my $txTableName = "PhenoTaxons";  # name of current instance of taxon table
    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Genome ID",        "char asc", "right");
    $it->addColSpec( "Genome Name",      "char asc", "left" );
    $it->addColSpec( "Last Modified On", "char asc", "left" );
    $it->addColSpec( "Phenotype", "char asc", "left" );

    my $cnt = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $taxon_name, $date2 ) = $cur->fetchrow();
        last if !$taxon_oid;

    	$taxon_filter{$taxon_oid} = $taxon_oid;

        $cnt++;
        if ( $cnt > 2000000 ) {
            last;
        }

        my $row = $sd . "<input type='checkbox' name='$select_id_name' " .
	    "value='$taxon_oid' checked='checked'/>\t";

        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
    	$row .= $domain . $sd .substr( $domain, 0, 1 ) . "\t";
    	$row .= $taxon_oid . $sd . alink( $url, $taxon_oid ) . "\t";
    	$row .= $taxon_name . $sd . escapeHTML($taxon_name) . "\t";
    	$row .= $date2 . $sd . $date2 . "\t";
    
    	# add link to show detail
    	my $url2 = "$main_cgi?section=TaxonDetail" . 
    	    "&page=taxonPhenoRuleDetail&taxon_oid=$taxon_oid&rule_id=$rule_id";
    	$row .= $rule_name . $sd . alink( $url2, $rule_name ) . "\t";
    
    	$it->addRow($row);
    }
    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$cnt genome(s) with selected phenotypes.", 2 );

    my $link = "";
    if ( $cnt > 0 ) {
    	my $url2 =
    	    "main.cgi?section=ImgPwayBrowser&page=showPhenoTaxons" .
                "&rule_id=$rule_id";
    
    	if ( $show_all ) {
    	    $url2 .= "&show_all=0";
                $link = alink( $url2, "Only show genomes with selected phenotype." );
    	}
    	else {
    	    $url2 .= "&show_all=1";
                $link = alink( $url2, "Display genomes with selected phenotype in complete tree.");
    	}
    	my $s = "Follow the link provided by <b>Phenotype</b> "
    	    . "to see rule prediction details.<br/>$link";

    	TaxonList::printHint($s);
    	print "<p>\n";
    	print domainLetterNoteNoVNoM();
    	print "</p>\n";
    	
    	printTaxonButtons ($txTableName)  if ( $cnt > 10 );
    	$it->printOuterTable(1);
    	printTaxonButtons ($txTableName);

        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);

    }
    else {
        print "<p><font color='red'>"
	    . "No genomes have the selected phenotype.</font></p>\n";
    }

    printStatusLine( "$cnt genome(s) loaded.", 2 );
    print end_form();
}


#######################################################################
# printFindPhenoTaxons()
#######################################################################
sub printFindPhenoTaxons {
    my $rule_id       = param('rule_id');
    my $max_count     = param('max_count');
    my $search_domain = param('search_domain');

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    
    my $sql = qq{
        select pr.rule_id, pr.name, pr.cv_type, pr.cv_value,
        pr.description, pr.rule, pr.rule_type,
        to_char(pr.add_date, 'yyyy-mm-dd'),
        to_char(pr.mod_date, 'yyyy-mm-dd'), c.username 
        from phenotype_rule pr, contact c
        where pr.rule_id = ? 
        and pr.modified_by = c.contact_oid 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my (
         $r_id, $rule_name, $cv_type,  $cv_value, $descr,
         $rule, $rule_type, $add_date,  $mod_date, $modified_by
      )
      = $cur->fetchrow();
    $cur->finish();

    my $url = 
          "$main_cgi?section=$section" 
        . "&page=PhenotypeRuleDetail"
        . "&rule_id=$rule_id";
    print "<h1>$search_domain Genomes with Selected Phenotype</h1>\n";

    print "<p>"; 
    print "Phenotype Rule: "; 
    print alink($url, escapeHTML($rule_name) . " ($rule_id)");
    print "</p>"; 
 
    my $domain_cond = " tx.domain in ( 'Archaea', 'Bacteria', 'Eukaryota' )";
    if ( $search_domain && $search_domain ne 'All' ) {
        $domain_cond = " tx.domain = '" . $search_domain . "' ";
    }

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    $sql = qq{
        select tx.taxon_oid, tx.domain, tx.taxon_display_name
            from taxon tx
            where $domain_cond 
            $rclause 
            $imgClause
            order by 2, 3 
        };

    my $eval_table = getRuleEvalTable2($rule_type, $rule);

    if ( ! blankStr($eval_table) ) {
	    my $rclause   = WebUtil::urClause('tx');
	    my $imgClause = WebUtil::imgClause('tx');
	    $sql = qq{
    	    select tx.taxon_oid, tx.domain, tx.taxon_display_name
    		from taxon tx, $eval_table t2
    		where $domain_cond 
    		$rclause
    		$imgClause
    		and tx.taxon_oid = t2.taxon
    		order by 1
	    };
    }
    # print "<p>SQL: $sql\n";
    $cur = execSql( $dbh, $sql, $verbose );

    my $cnt  = 0;
    my $cnt2 = 0;
    print "<p>\n";

    for ( ; ; ) {
        my ( $taxon_oid, $domain, $taxon_name ) = $cur->fetchrow();
        last if !$taxon_oid;

        $cnt++;
        if ( $cnt > 20000 ) {
            last;
        }

    	my $selected = 0;
    	if ( ! blankStr($eval_table) ) {
    	    # already filtered
    	    $selected = 1;
    	}
        elsif ( evalPhenotypeRule( $taxon_oid, $rule_id ) ) {
    	    $selected = 1;
    	}

    	if ( $selected ) {
            $cnt2++;
            my $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";

            print alink( $url, $taxon_oid ) . " "
              . escapeHTML($taxon_name) . "<br/>";

            if ( $cnt2 >= $max_count ) {
                last;
            }
        }
    }

    if ( $cnt2 > 0 ) {
        # has output
        if ( $cnt2 >= $max_count ) {
            if ( $cnt2 == 1 ) {
                print
"<p><font color='blue'>Only 1 genome is shown. There may be more.</font>\n";
            } else {
                print
"<p><font color='blue'>Only $max_count genomes are shown. There may be more.</font>\n";
            }
        }
    } else {
        print "<p><font color='red'>"
	    . "No genomes have the selected phenotype.</font></p>\n";
    }

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$cnt2 genome(s) loaded.", 2 );

    print end_form();
}


#######################################################################
# getRuleEvalTable: easy rules
#######################################################################
sub getRuleEvalTable {
    my ($rule_type, $rule) = @_;

    my $res = "";

    if ( $rule_type eq 'IPWAY AND' ) {
	my @rules = split( /\,/, $rule );
	my $rule_id_str = "";
	my $c_cnt = 0;

	for my $r1 ( @rules ) {
	    my @components = split( /\|/, $r1 );
	    if ( scalar(@components) > 1 ) {
		return "";
	    }

	    for my $c2 ( @components ) {
		my $pathway_oid = 0;
		my $not_flag = 0;

		if ( $c2 =~ /\!(\d+)/ ) { 
		    $pathway_oid = $1;
		    $not_flag = 1; 
		} elsif ( $c2 =~ /(\d+)/ ) {
		    $pathway_oid = $1; 
		} 

		if ( $not_flag ) {
		    return "";
		}

		if ( blankStr($rule_id_str) ) {
		    $rule_id_str = $pathway_oid;
		    $c_cnt = 1;
		}
		else {
		    $rule_id_str .= ", " . $pathway_oid;
		    $c_cnt++;
		}
	    }  # end for c2
	}  #end for r1

	if ( blankStr($rule_id_str) ) {
	    return "";
	}

	$res = qq{
	    (select ipa.taxon taxon, count(*) cnt
	     from img_pathway_assertions ipa
	     where ipa.status = 'asserted' 
	     and ipa.pathway_oid in ( $rule_id_str )
	     group by ipa.taxon
	     having count(*) >= $c_cnt)
	    };
    }
    elsif ( $rule_type eq 'IPWAY OR' ) {
	my @rules = split( /\|/, $rule );
	my $rule_id_str = "";
	my $c_cnt = 0;

	for my $r1 ( @rules ) {
	    my @components = split( /\,/, $r1 );
	    if ( scalar(@components) > 1 ) {
		return "";
	    }

	    for my $c2 ( @components ) {

		my $pathway_oid = 0;
		my $not_flag = 0;

		if ( $c2 =~ /\!(\d+)/ ) { 
		    $pathway_oid = $1;
		    $not_flag = 1; 
		} elsif ( $c2 =~ /(\d+)/ ) {
		    $pathway_oid = $1; 
		} 

		if ( $not_flag ) {
		    return "";
		}

		if ( blankStr($rule_id_str) ) {
		    $rule_id_str = $pathway_oid;
		    $c_cnt = 1;
		}
		else {
		    $rule_id_str .= ", " . $pathway_oid;
		    $c_cnt++;
		}
	    }  # end for c2
	}  #end for r1

	if ( blankStr($rule_id_str) ) {
	    return "";
	}

	$res = qq{
	    (select ipa.taxon taxon
	     from img_pathway_assertions ipa
	     where ipa.status = 'asserted' 
	     and ipa.pathway_oid in ( $rule_id_str ))
	    };
    }

    return $res;
}


#######################################################################
# getRuleEvalTable2: complete rule
#######################################################################
sub getRuleEvalTable2 {
    my ($rule_type, $rule) = @_;

    my $res = "";
    my $distinct_res = "";

    if ( $rule_type eq 'IPWAY AND' ) {
	my @rules = split( /\,/, $rule );
	my $rule_id_str = "";
	my $c_cnt = 0;

	for my $r1 ( @rules ) {
	    $c_cnt++;
	    my $not_flag = 0;
	    my $last_flag = 0;
	    my $same_flag = 1;
	    my @components = split( /\|/, $r1 );
	    my $pathway_oid_list = "";
	    my $cond_list = "";
	    my $rname = "r" . $c_cnt;

	    for my $c2 ( @components ) {
		my $pathway_oid = 0;

		if ( $c2 =~ /\!(\d+)/ ) { 
		    $pathway_oid = $1;
		    $not_flag = 1; 
		} elsif ( $c2 =~ /(\d+)/ ) {
		    $pathway_oid = $1; 
		} 

		if ( $c_cnt > 1 && $not_flag != $last_flag ) {
		    $same_flag = 0;
		}
		$last_flag = $not_flag;

		if ( $pathway_oid ) {
		    if ( blankStr($pathway_oid_list) ) {
			$pathway_oid_list = $pathway_oid;
		    }
		    else {
			$pathway_oid_list .= ", " . $pathway_oid;
		    }

		    my $cond3 = "($rname.pathway_oid = $pathway_oid and $rname.status = 'asserted')";
		    if ( $not_flag ) {
			$cond3 = "($rname.pathway_oid = $pathway_oid and $rname.status = 'not asserted')";
		    }
		    if ( blankStr($cond_list) ) {
			$cond_list = $cond3;
		    }
		    else {
			$cond_list .= " or " . $cond3;
		    }
		}
	    }  # end if c2

	    if ( blankStr($pathway_oid_list) ) {
		next;
	    }

	    my $sql2;
	    if ( $same_flag ) {
		if ( $not_flag ) {
		    $sql2 = "(select $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid in ($pathway_oid_list) and $rname.status = 'not asserted' )";
		    $distinct_res = "(select distinct $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid in ($pathway_oid_list) and $rname.status = 'not asserted' )";
		}
		else {
		    $sql2 = "(select $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid in ($pathway_oid_list) and $rname.status = 'asserted' )";
		    $distinct_res = "(select distinct $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid in ($pathway_oid_list) and $rname.status = 'asserted' )";
		}
	    }
	    else {
		$sql2 = "(select $rname.taxon from img_pathway_assertions $rname where " . $cond_list . ")";
		$distinct_res = $sql2;
	    }

	    if ( blankStr($res) ) {
		$res = $sql2;
	    }
	    else {
		$res .= " intersect " . $sql2;
	    }
	}   # end for r1

	if ( $c_cnt > 1 && ! blankStr($res) ) {
	    $res = "(" . $res . ")";
	}
	elsif ( $c_cnt == 1 && ! blankStr($distinct_res) ) {
	    $res = $distinct_res;
	}
    }
    elsif ( $rule_type eq 'IPWAY OR' ) {
	my @rules = split( /\|/, $rule );
	my $rule_id_str = "";
	my $r_cnt = 0;

	for my $r1 ( @rules ) {
	    my $not_flag = 0;
	    my @components = split( /\,/, $r1 );
	    my $res2 = "";
	    my $c_cnt = 0;

	    for my $c2 ( @components ) {
		my $pathway_oid = 0;
		my $sql2 = "";
		$c_cnt++;

		if ( $c2 =~ /\!(\d+)/ ) { 
		    $pathway_oid = $1;
		    $not_flag = 1; 
		} elsif ( $c2 =~ /(\d+)/ ) {
		    $pathway_oid = $1; 
		} 

		if ( $pathway_oid ) {
		    my $rname = "r" . $c_cnt;
		    if ( $not_flag ) {
			$sql2 = "(select $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid = $pathway_oid and $rname.status = 'not asserted' )";
			$distinct_res = "(select distinct $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid = $pathway_oid and $rname.status = 'not asserted' )";
		    }
		    else {
			$sql2 = "(select $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid = $pathway_oid and $rname.status = 'asserted' )";
			$distinct_res = "(select distinct $rname.taxon from img_pathway_assertions $rname where $rname.pathway_oid = $pathway_oid and $rname.status = 'asserted' )";
		    }
		}

		if ( blankStr($res2) ) {
		    $res2 = $sql2;
		}
		else {
		    $res2 .= " intersect " . $sql2;
		}
	    }  # end if c2

	    if ( $c_cnt == 1 && ! blankStr($distinct_res) ) {
		$res2 = $distinct_res;
	    }
	    if ( blankStr($res2) ) {
		next;
	    }

	    if ( blankStr($res) ) {
		$res = $res2;
		$r_cnt = 1;
	    }
	    else {
		$res .= " union " . $res2;
		$r_cnt++;
	    }
	}   # end for r1

	if ( $r_cnt > 1 && ! blankStr($res) ) {
	    $res = "(" . $res . ")";
	}
    }

    return $res;
}




1;

