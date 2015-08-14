############################################################################
# ImgTermBrowser.pm - Browse IMG terms from this module.
#   Include IMG term details.
#
# $Id: ImgTermBrowser.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package ImgTermBrowser;
my $section = "ImgTermBrowser";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use GeneDetail;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use ImgTermNode;
use ImgTermNodeMgr;
use ImgNetworkBrowser;
use WorkspaceUtil;
use FuncUtil;
use DataEntryUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $enzyme_base_url      = $env->{enzyme_base_url};
my $pubmed_base_url      = $env->{pubmed_base_url};
my $tmp_dir              = $env->{tmp_dir};
my $max_gene_batch       = 100;
my $max_taxon_batch      = 20;
my $max_scaffold_batch   = 20;
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $include_img_term_bbh = $env->{include_img_term_bbh};
my $show_private         = $env->{show_private};
my $tab_panel            = $env->{tab_panel};
my $content_list         = $env->{content_list};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) { 
    $merfs_timeout_mins = 60; 
} 

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {

    timeout( 60 * $merfs_timeout_mins );
    
    my $page = param("page");

    if ( $page eq "imgTermBrowser" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;
        # if not tabs then use list
        if ( !$tab_panel ) {
            ImgNetworkBrowser::printImgFam();
        }

        printImgTermBrowser();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "alphaList" ) {
        printAlphaList();
    } elsif ( $page eq "imgTermDetail" ) {
        printImgTermDetail();
    } elsif ( $page eq "imgTermBrowserSynonyms" ) {
        printImgTermBrowserSynonyms();
    } elsif ( $page eq "imgTermBrowserGenes" ) {
        printImgTermBrowserGenes();
    } elsif ( $page eq "imgTermTaxonGenes" ) {
        printImgTermTaxonGenes();
    } elsif ($page eq "imgTermTaxonGenes2") {
        # parent term oid
        printImgTermTaxonGenes_list();
    } elsif ( $page eq "imgTermHistory" ) {
        printImgTermHistory();
    } elsif ( $page eq "cellLocGenes" ) {
        printCellLocGenes();
    } elsif ( $page eq "imgTermPhyloDist" ) {
        printImgTermPhyloDist();
    } elsif ( $page eq "imgReactions" ) {
        printImgReactions();
    } elsif ( $page eq "bbhClusterGenes" ) {
        printBbhClusterGenes();
    } elsif ( $page eq "cogGenes" ) {
        printCogGenes();
    } elsif ( $page eq "pfamGenes" ) {
        printPfamGenes();
    } elsif ( $page eq "tigrfamGenes" ) {
        printTigrfamGenes();
    } elsif ( $page eq "imgtermlist" ) {
        printImgTermList();
    } elsif ( $page eq "confirmDeleteGeneTerm" ||
	paramMatch("confirmDeleteGeneTerm") ne "" ) {
        confirmDeleteGeneTerm();
    } elsif ( $page eq "dbDeleteGeneTerm" ||
	paramMatch("dbDeleteGeneTerm") ne "" ) {
        my $msg = dbDeleteGeneTerm();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    printImgTermBrowserGenes();
	}
    } else {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;        
        # if not tabs then use list
        if ( !$tab_panel ) {
            ImgNetworkBrowser::printImgFam();
        }        
        printImgTermBrowser();
        HtmlUtil::cgiCacheStop();
    }
}

sub printJavaScript {
    print qq{
    <script>
    function selectAllCheckBoxes2( x ) {
        var f = document.mainForm2;
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
# printImgTermBrowser - Show term list.
#   (Perhaps when we have a more of a hierarchy someday, we'll do
#    the hierarchy thing.)
############################################################################
sub printImgTermBrowser {

    print "<h1>IMG Term Browser</h1>\n";
    printStatusLine( "Loading ...", 1 );
    
    # see printJavaScript();
    WebUtil::printMainFormName("2");

    my $dbh = dbLogin();
    my $sql = qq{
        select count(*)
        from img_term
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    if ( $cnt == 0 ) {
        #$dbh->disconnect();
        print "<div id='message'>\n";
        print "<p>\n";
        print "This database has no IMG terms.\n";
        print "</p>\n";
        print "</div>\n";
        return;
    }

    # img term stats
    my $super_user = getSuperUser();

    if ( $super_user eq "Yes" ) {
        print qq{
            <p>
            <b>Warning: IMG Term Statistics are very slow to run.</b>
            </p>
            <table class='img'>
            <th class='img'> IMG Term Statistics</th>
        };
        print qq{
<tr class='img' >
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=paralog'>IMG Term Paralog</a> 
  </td>
</tr>
<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=termscombo2'>IMG Term Combinations</a> 
  </td>
</tr>
    };

        if ($include_img_term_bbh) {
            print qq{
<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=bbh'>IMG Ortholog Clusters</a> 
  </td>
</tr>
    };
        }

        print qq{
<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=ko'>IMG Term KO</a> 
  </td>
</tr>
    };
        print "</table>\n";
    }

    print "<p>\n";
    my ( $gene_product, $modified_protein, $protein_complex ) =
      getTermStats($dbh);

    my $url   = "$section_cgi&page=imgtermlist&term_type=";
    my $link1 = alink( "$url" . "GENE PRODUCT", $gene_product );
    my $link2 = alink( "$url" . "MODIFIED PROTEIN", $modified_protein );
    my $link3 = alink( "$url" . "PROTEIN COMPLEX", $protein_complex );

    my $tree_href     = getImgChildParent($dbh);
    my $pathways_href = getAllImgConnPath($dbh);
    my $parts_href    = getAllImgConnParts($dbh);

    print "<table class='img'>\n";

    print qq{
<tr class='img' >
  <th class='subhead' align='right'>Gene Product</th>
  <td class='img'   align='left'>$link1</td>
</tr>
    };

    my $indent = nbsp(4);

    # connpathway
    my $cnt = getImgConnPath( $dbh, $pathways_href, $tree_href );
    my $link = alink( "$url" . "connpathway", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'>$indent IMG Terms connected to Pathways</th>
  <td class='img'   align='left'> $link </td>
</tr>
    };

    my $cnt = getImgConnParts( $dbh, $parts_href, $tree_href );
    my $link = alink( "$url" . "connparts", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'> $indent IMG Terms connected to Parts Lists</th>
  <td class='img'   align='left'>$link</td>
</tr>
    };

    my $cnt =
      getImgNotConnPathOrParts( $dbh, $pathways_href, $parts_href, $tree_href );
    my $link = alink( "$url" . "notconnpathorparts", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'> $indent IMG Terms not connected to Pathways or Parts Lists</th>
  <td class='img'   align='left'> $link </td>
</tr>
    };

    my $cnt = getImgNotConnPath( $dbh, $pathways_href, $tree_href );
    my $link = alink( "$url" . "notconnpath", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'> $indent IMG Terms not connected to Pathways</th>
  <td class='img'   align='left'> $link </td>
</tr>
    };

    my $cnt = getImgNotConnParts( $dbh, $parts_href, $tree_href );
    my $link = alink( "$url" . "notconnparts", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'> $indent IMG Terms not connected to Parts Lists</th>
  <td class='img'   align='left'> $link </td>
</tr>
    };

    my $cnt = getImgNotConnGene($dbh);
    my $link = alink( "$url" . "notconngene", $cnt );
    $link = $cnt if ( $cnt == 0 );
    print qq{
    <tr class='img' >
  <th class='subhead' align='right'> $indent IMG Terms not connected to Genes (missing genes)</th>
  <td class='img'   align='left'>  $link </td>
</tr>
    };

    print qq{
<tr class='img' >
  <th class='subhead' align='right'>Modified Protein</th>
  <td class='img'   align='left'>$link2</td>
</tr>

    <tr class='img' >
  <th class='subhead' align='right'>Protein Complex</th>
  <td class='img'   align='left'>$link3</td>
</tr>
    };

    print "</table>\n";
    print "</p>\n";
    print "<br/>\n";

    WebUtil::printFuncCartFooterForEditor("2");

    print "<p>\n";

    my $url = "$section_cgi&page=alphaList";
    print alink( $url, "Alphabetical List" ) . "<br/>\n";
    print "</p>\n";

    print "<p>\n";
    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);
    $root->sortNodes();
    $root->printHtml();
    print "</p>\n";
    #$dbh->disconnect();

    WebUtil::printFuncCartFooterForEditor("2");

    print hiddenVar( 'save_func_id_name', 'term_oid' );
    WorkspaceUtil::printSaveFunctionToWorkspace('term_oid');

    printStatusLine( "Loaded.", 2 );
    print end_form();

    printJavaScript();
    
}

# get child to parent
# return hash child id => hash of parent ids => ""
sub getImgChildParent {
    my ($dbh) = @_;
    my $sql = qq{
    select term_oid, child
    from img_term_children
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $pid, $cid ) = $cur->fetchrow();
        last if !$pid;

        if ( exists $hash{$cid} ) {
            my $href = $hash{$cid};
            $href->{$pid} = "";
        } else {
            my %phash;
            $phash{$pid} = "";
            $hash{$cid}  = \%phash;
        }
    }
    $cur->finish();
    return \%hash;

}

# get all terms connected to a pathway
# return term oid => ""
sub getAllImgConnPath {
    my ($dbh) = @_;
    my $sql = qq{
select irc.catalysts
from img_reaction_catalysts irc, img_pathway_reactions ipr
where irc.rxn_oid = ipr.rxn
union
select irtc2.term
from img_reaction_t_components irtc2, img_pathway_reactions ipr2
where irtc2.rxn_oid = ipr2.rxn
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;
        $hash{$oid} = "";
    }
    $cur->finish();
    return \%hash;
}

# get all term connected to parts list
sub getAllImgConnParts {
    my ($dbh) = @_;
    my $sql = qq{
select t2.term from img_parts_list_img_terms t2 
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;
        $hash{$oid} = "";
    }
    $cur->finish();
    return \%hash;
}

sub getImgConnPath {
    my ( $dbh, $pathways_href, $tree_href ) = @_;
    my $sql = qq{
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
    };

    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $pathways_href, $tree_href, \%cycle );
        next if ( $res == 0 );
        $cnt++;
    }
    $cur->finish();

    return $cnt;
}

sub getImgConnParts {
    my ( $dbh, $parts_href, $tree_href ) = @_;
    my $sql = qq{
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT' 
    };

    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $parts_href, $tree_href, \%cycle );
        next if ( $res == 0 );
        $cnt++;
    }
    $cur->finish();

    return $cnt;
}

sub getImgNotConnPath {
    my ( $dbh, $pathways_href, $tree_href ) = @_;
    my $sql = qq{
    select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
minus
(select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
and t.term_oid in
(select irc.catalysts
from img_reaction_catalysts irc, img_pathway_reactions ipr
where irc.rxn_oid = ipr.rxn
union
select irtc2.term
from img_reaction_t_components irtc2, img_pathway_reactions ipr2
where irtc2.rxn_oid = ipr2.rxn)
)
    };

    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $pathways_href, $tree_href, \%cycle );
        next if ( $res == 1 );
        $cnt++;
    }
    $cur->finish();

    return $cnt;
}

#
# check terms parents if its connected to a pathway - ken
#
# $oid - term id to check
# $pathways_href - all terms oid => "" connected to a pathways
# $tree_href - tree child id => hash of parent ids => ""
# $cycle_href - hash set of term oids already checked,
#               because there are cycles
#             - usually initialized with $oid on first recursive call.
sub isConnPathway {
    my ( $oid, $pathways_href, $tree_href, $cycle_href ) = @_;

    if ( exists $pathways_href->{$oid} ) {
        return 1;
    } else {
        my $parent_href = $tree_href->{$oid};
        foreach my $pid ( keys %$parent_href ) {
            next if ( exists $cycle_href->{$pid} );
            $cycle_href->{$pid} = "";

            #webLog("parent $pid \n");
            my $res =
              isConnPathway( $pid, $pathways_href, $tree_href, $cycle_href );
            if ( $res == 1 ) {
                return 1;
            }
        }
    }
    return 0;
}

sub getImgNotConnParts {
    my ( $dbh, $parts_href, $tree_href ) = @_;
    my $sql = qq{
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
minus
(select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
and t.term_oid in
(select t2.term from img_parts_list_img_terms t2))  
    };

    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $parts_href, $tree_href, \%cycle );
        next if ( $res == 1 );
        $cnt++;
    }
    $cur->finish();

    return $cnt;
}

sub getImgNotConnPathOrParts {
    my ( $dbh, $pathways_href, $parts_href, $tree_href ) = @_;
    my $sql = qq{      
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
minus
(
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
and t.term_oid in
(select irc.catalysts
from img_reaction_catalysts irc, img_pathway_reactions ipr
where irc.rxn_oid = ipr.rxn
union
select irtc2.term
from img_reaction_t_components irtc2, img_pathway_reactions ipr2
where irtc2.rxn_oid = ipr2.rxn)
union
select t.term_oid
from img_term t
where t.term_type = 'GENE PRODUCT'
and t.term_oid in
(select t2.term from img_parts_list_img_terms t2)
)        
    };

    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($oid) = $cur->fetchrow();
        last if !$oid;

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $pathways_href, $tree_href, \%cycle );
        next if ( $res == 1 );

        my %cycle;
        $cycle{$oid} = "";
        my $res = isConnPathway( $oid, $parts_href, $tree_href, \%cycle );
        next if ( $res == 1 );

        $cnt++;
    }
    $cur->finish();

    return $cnt;

}

sub getImgNotConnGene {
    my ($dbh) = @_;
    my $sql = qq{
        select count(*)
        from (
            select t.term_oid
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            minus
            select t.term_oid
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select t2.function from gene_img_functions t2)
        )     
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printImgTermDetail - Print details for one term.
############################################################################
sub printImgTermDetail {
    my ($term_oid) = @_;
    $term_oid = param("term_oid") if $term_oid eq "";

    my $term_oid_orig = $term_oid;
    $term_oid = sprintf( "%d", $term_oid );

    printMainForm();
    print "<h1>IMG Term Details</h1>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $contact_oid = getContactOid();
    my $imgEditor   = isImgEditor( $dbh, $contact_oid );

    my $sql = qq{
        select it.term_oid, it.term, it.term_type, it.definition, it.pubmed_id,
        	   it.comments, to_char(it.mod_date, 'yyyy-mm-dd'), to_char(it.add_date, 'yyyy-mm-dd'), c.name, c.email
        from img_term it, contact c
    	where it.term_oid = ?
    	and it.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid);
    my (
        $term_oid, $term,     $term_type, $definition, $pubmed_id,
        $comments, $mod_date, $add_date,  $c_name,     $email
      )
      = $cur->fetchrow();
    $cur->finish();

    if ( $term_oid eq "" ) {
        #$dbh->disconnect();
        printStatusLine( "Error.", 2 );
        webError("Term not found in this database.");
        return;
    }

    # get enzyme EC's
    my @ecs = ();
    $sql = "select term_oid, enzymes from img_term_enzymes where term_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid);
    for ( ; ; ) {
        my ( $tid, $ec ) = $cur->fetchrow();
        last if !$tid;

        push @ecs, ($ec);
    }
    $cur->finish();

    $term_oid = FuncUtil::termOidPadded($term_oid);

    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);

    print "<h2>Term Information</h2>\n";
    print "<table class='img' border='1'>\n";
    printAttrRow( "Term Object ID", $term_oid );
    printAttrRow( "Term",           $term );
    printAttrRow( "Type",           $term_type );
    printAttrRow( "Definition",     $definition );

    #printAttrRow( "Pubmed ID", $pubmed_id );
    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>Pubmed ID</th>\n";
    my $url = "$pubmed_base_url$pubmed_id";
    my $link = alink( $url, $pubmed_id );
    $link = nbsp(1) if $pubmed_id eq "";
    print "<td class='img'>$link</td>\n";
    printAttrRow( "Comments", $comments );

    # add EC
    printTermEnzymes( $dbh, \@ecs );

    printAttrRow( "Add Date",    $add_date );
    printAttrRow( "Modify Date", $mod_date );
    my $s = escHtml($c_name);
    printAttrRowRaw( "Modified By", $s );

    #printAttrRowRaw( "Email", emailLink( $email ) );
    #printSynonyms( $dbh, $term_oid );

    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>Number of<br/>Synonyms</th>\n";
    my $url  = "$section_cgi&page=imgTermBrowserSynonyms&term_oid=$term_oid";
    my $cnt  = synonymCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>Number of<br/>Genes</th>\n";
    my $url  = "$section_cgi&page=imgTermBrowserGenes&term_oid=$term_oid";
    my $cnt  = geneCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    # include for 2.7
    #if ($img_internal) {
    ## BBH cluster count
    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>";
    print "Number of<br/>BBH Clusters</th>\n";
    my $url  = "$section_cgi&page=bbhClusterGenes&term_oid=$term_oid";
    my $cnt  = bbhClusterCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    ##
    ## COG count
    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>";
    print "Number of<br/>COG's</th>\n";
    my $url  = "$section_cgi&page=cogGenes&term_oid=$term_oid";
    my $cnt  = cogCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    ##
    ## Pfam count
    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>";
    print "Number of<br/>Pfam Families</th>\n";
    my $url  = "$section_cgi&page=pfamGenes&term_oid=$term_oid";
    my $cnt  = pfamCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    ##
    ## TIGRfam count
    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>";
    print "Number of<br/>TIGRfam's</th>\n";
    my $url  = "$section_cgi&page=tigrfamGenes&term_oid=$term_oid";
    my $cnt  = tigrfamCount( $dbh, $term_oid );
    my $link = alink( $url, $cnt );
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead' align='left'>";
    print "Number of<br/>IMG Reactions</th>\n";
    my $url  = "$section_cgi&page=imgReactions&term_oid=$term_oid";
    my $cnt  = imgReactionCount( $dbh, $term_oid );
    my $link = $cnt;
    $link = alink( $url, $cnt ) if $imgEditor;
    $link = 0 if $cnt == 0;
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";

    printPathways( $dbh, $root, $term_oid );
    printPartsList( $dbh, $root, $term_oid );
    printLocalization( $dbh, $term_oid );
    print "</table>\n";
    if ($img_internal) {
        my $url = "$section_cgi&page=imgTermHistory&term_oid=$term_oid";
        print "<p>\n";
        print alink( $url, "History" );
        print nbsp(1);
        print "(Internal use only.)";
        print "</p>\n";
    }

    ## Parents
    my $sql = qq{
        select distinct it.term_oid, it.term
    	from img_term_children itc, img_term it
    	where itc.child = ?
    	and itc.term_oid = it.term_oid
    	order by it.term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid);
    my @recs;
    for ( ; ; ) {
        my ( $p_term_oid, $term ) = $cur->fetchrow();
        last if !$p_term_oid;
        $p_term_oid = FuncUtil::termOidPadded($p_term_oid);
        my $url = "$section_cgi&page=imgTermDetail&term_oid=$p_term_oid";
        print "<h2>Larger Protein Complex</h2>\n";
        print "<p>\n";
        print alink( $url, $p_term_oid );
        print nbsp(1);
        print escHtml($term);
        print "<br/>\n";
        print "</p>\n";
    }
    $cur->finish();

    print "<h2>Term Hierarchy</h2>\n";
    print "<p>\n";
    print "Only terms with no sub-components are selectable.<br/>\n";
    print "</p>\n";
    my $mgr       = new ImgTermNodeMgr();
    my $root      = $mgr->loadTree($dbh);
    my $n         = $root->ImgTermNode::findNode($term_oid);
    
    # get all the img term oids for this node 
    my @children;
    $n->ImgTermNode::loadAllChildTermOids(\@children);
    
    #print Dumper \@children;
    
    my $nChildren = 0;
    if ( !defined($n) ) {
        webLog("printImgTermDetail: cannot find '$term_oid'\n");
    } else {
        print "<p>\n";
        $n->printHtml();
        print "</p>\n";
    }
    WebUtil::printFuncCartFooterForEditor();

    my $suc = printTermGenomes( $dbh, $term_oid_orig );

    if(!$suc) {
        printTermGenomes_list($dbh, \@children, $term_oid_orig);
    }
    #$dbh->disconnect();
    
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printTermEnzymes - print associated enzymes for this term
############################################################################
sub printTermEnzymes {
    my ( $dbh, $ecs_ref ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Enzymes</th>\n";
    print "<td class='img'>\n";

    for my $ec (@$ecs_ref) {
        #$ec =~ s/'/''/g;    # replace ' with '' -- just in case
        my $sql = "select ec_number, enzyme_name from enzyme where ec_number = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $ec );
        my $enzyme_name = "";
        for ( ; ; ) {
            my ( $ec_no, $ec_name ) = $cur->fetchrow();
            last if !$ec_no;

            $enzyme_name = $ec_name;
        }
        #$cur->finish();

        if ( blankStr($enzyme_name) ) {

            # unknown EC number. text display only.
            print escHtml($ec);
        } else {

            # show url
            my $url = "$enzyme_base_url$ec";
            print alink( $url, $ec );
            print nbsp(1);
            print escHtml($enzyme_name);
        }
        print "<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printImgTermBrowserSynonyms - Show synonyms for the term.
############################################################################
sub printImgTermBrowserSynonyms {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();

    print "<h1>Synonyms</h1>\n";
    my $sql = qq{
	select term
	from img_term
	where term_oid = $term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    print "<p>\n";
    print "Synonyms for <i>" . escHtml($term) . "</i>:<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $sql = qq{
	select its.term_oid, its.synonyms
	from img_term_synonyms its
	where its.term_oid = $term_oid
	order by its.synonyms
    };
    print "<p>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    for ( ; ; ) {
        my ( $term_oid, $synonyms ) = $cur->fetchrow();
        last if !$term_oid;
        $count++;
        print nbsp(4) . escHtml($synonyms) . "<br/>\n";
    }
    $cur->finish();
    print "</p>\n";
    printStatusLine( "$count synonym(s) retrieved.", 2 );

    #$dbh->disconnect();
}

############################################################################
# printImgTermBrowserGenes - Show genes for the term.
############################################################################
sub printImgTermBrowserGenes {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    print "<h1>Genes assigned to Term</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print hiddenVar( 'term_oid', $term_oid );

    my $sql = qq{
       select term
       from img_term
       where term_oid = $term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    print "<p>\n";
    print "Genes assigned to <i>" . escHtml($term) . "</i>.<br/>\n";
    print "</p>\n";

    #my $sql = qq{
    #	select g.gene_oid, ge.enzymes
    #	from gene_img_functions g, gene_ko_enzymes ge
    #	where g.function = ?
    #	and g.gene_oid = ge.gene_oid
    #};
    #my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    #my %gene2Enzymes;
    #for ( ; ; ) {
    #    my ( $gene_oid, $enzyme ) = $cur->fetchrow();
    #    last if !$gene_oid;
    #    $gene2Enzymes{$gene_oid} .= "$enzyme,";
    #}
    #$cur->finish();

    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('tx');
    my $imgClause   = WebUtil::imgClause('tx');

    my $sql = qq{
    	select distinct g.gene_oid, g.gene_display_name, 
    	   tx.taxon_oid, tx.taxon_display_name, 
           to_char(gif.mod_date, 'yyyy-mm-dd'), c.name, 
           tx.domain, tx.phylum, tx.ir_class
    	from gene_img_functions gif, gene g, taxon tx, contact c
    	where gif.function = ?
        and gif.gene_oid = g.gene_oid
    	and g.taxon = tx.taxon_oid
        and g.obsolete_flag = 'No'
    	and gif.modified_by = c.contact_oid
        $taxonClause
    	$rclause
    	$imgClause
    	$taxonClause
    	order by tx.taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );

    my $it = new InnerTable( 0, "imgTermGenes$$", "imgTermGenes", 0 );
    my $sd = InnerTable::getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Gene<br/>ID", "number asc", "left" );
    $it->addColSpec( "Product Name",           "char asc",   "left" );
    $it->addColSpec( "Domain",                 "char asc",   "left" );
    $it->addColSpec( "Phylum",                 "char asc",   "left" );
    $it->addColSpec( "Class",                 "char asc",   "left" );
    $it->addColSpec( "Genome",                 "char asc",   "left" );
    if ($img_internal) {
        $it->addColSpec( "Modification<br/>Date", "char desc", "left" );
        $it->addColSpec( "Modified By",           "char asc",  "left" );
    }

    my $select_id_name = "gene_oid";

    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $taxon_oid, 
	     $taxon_display_name,
	     $mod_date, $name, $domain, $phylum, $ir_class )
          = $cur->fetchrow();
        last if !$gene_oid;
        $count++;

        my $r;
        $r .= $sd
          . "<input type='checkbox' "
          . "name='$select_id_name' value='$gene_oid' />\t";
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";
        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
	my $domain = substr($domain, 0, 1);
	$r .= $domain . $sd . $domain . "\t";
	$r .= $phylum . $sd . $phylum . "\t";
	$r .= $ir_class . $sd . $ir_class . "\t";
        $r .=
          $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ($img_internal) {
            my $sortVal = $mod_date; #dateSortVal($mod_date);
            $r .= $sortVal . $sd . "$mod_date\t";
            $r .= "$name\t";
        }
        $it->addRow($r);
    }

    #print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();

    my $contact_oid = getContactOid();
    my $imgEditor   = isImgEditor( $dbh, $contact_oid );
    if ($count > 10) {
	if ( $imgEditor ) {
	    my $name = "_section_ImgTermBrowser_confirmDeleteGeneTerm";
	    print submit(
		-name  => $name, 
		-value => "Delete Term Association", 
		-class => 'medbutton' 
		); 
	    print nbsp(1);
	}
	WebUtil::printGeneCartFooter() if $count > 10;
    }
    $it->printOuterTable(1);
    if ( $imgEditor ) {
        my $name = "_section_ImgTermBrowser_confirmDeleteGeneTerm";
        print submit(
	    -name  => $name, 
	    -value => "Delete Term Association", 
	    -class => 'medbutton' 
	    ); 
        print nbsp(1);
    }
    WebUtil::printGeneCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();

}

############################################################################
# confirmDeleteGeneTerm
############################################################################
sub confirmDeleteGeneTerm {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    print "<h1>Confirm Term Deletion</h1>\n";

    printStatusLine( "Loading ...", 1 );

    printMainForm();

    my $contact_oid = getContactOid();
    my $imgEditor   = isImgEditor( $dbh, $contact_oid );
    if ( ! $imgEditor ) {
        printStatusLine( "Error.", 2 );
        webError("You do not have the privilege to delete term association.");
        return;
    }

    print hiddenVar( 'term_oid', $term_oid );
    if ( ! $term_oid ) {
        printStatusLine( "Error.", 2 );
        webError("No term has been selected.");
        return;
    }

    my @selected_genes = param('gene_oid');
    if ( scalar(@selected_genes) == 0 ) {
        printStatusLine( "Error.", 2 );
        webError("No genes have been selected.");
        return;
    }
    my %selected_gene_h;
    for my $g1 ( @selected_genes ) {
	$selected_gene_h{$g1} = $g1;
	print hiddenVar('gene_oid', $g1);
    }

    my $sql = qq{
       select term
       from img_term
       where term_oid = $term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    print "<p>\n";
    print "Selected genes assigned to <i>" . escHtml($term) . "</i>.<br/>\n";
    print "</p>\n";

    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('tx');
    my $imgClause   = WebUtil::imgClause('tx');

    my $sql = qq{
    	select distinct g.gene_oid, g.gene_display_name, 
    	   tx.taxon_oid, tx.taxon_display_name, 
           to_char(gif.mod_date, 'yyyy-mm-dd'), c.name, 
           tx.domain, tx.phylum, tx.ir_class
    	from gene_img_functions gif, gene g, taxon tx, contact c
    	where gif.function = ?
        and gif.gene_oid = g.gene_oid
    	and g.taxon = tx.taxon_oid
        and g.obsolete_flag = 'No'
    	and gif.modified_by = c.contact_oid
        $taxonClause
    	$rclause
    	$imgClause
    	$taxonClause
    	order by tx.taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );

    my $it = new InnerTable( 0, "imgTermGenes$$", "imgTermGenes", 0 );
    my $sd = InnerTable::getSdDelim();
#    $it->addColSpec("Select");
    $it->addColSpec( "Gene<br/>ID", "number asc", "left" );
    $it->addColSpec( "Product Name",           "char asc",   "left" );
    $it->addColSpec( "Domain",                 "char asc",   "left" );
    $it->addColSpec( "Phylum",                 "char asc",   "left" );
    $it->addColSpec( "Class",                 "char asc",   "left" );
    $it->addColSpec( "Genome",                 "char asc",   "left" );
    if ($img_internal) {
        $it->addColSpec( "Modification<br/>Date", "char desc", "left" );
        $it->addColSpec( "Modified By",           "char asc",  "left" );
    }

    my $select_id_name = "gene_oid";

    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $taxon_oid, 
	     $taxon_display_name,
	     $mod_date, $name, $domain, $phylum, $ir_class )
          = $cur->fetchrow();
        last if !$gene_oid;

	if ( ! $selected_gene_h{$gene_oid} ) {
	    next;
	}

        $count++;

        my $r;
#        $r .= $sd
#          . "<input type='checkbox' "
#          . "name='$select_id_name' value='$gene_oid' />\t";
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";
        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
	my $domain = substr($domain, 0, 1);
	$r .= $domain . $sd . $domain . "\t";
	$r .= $phylum . $sd . $phylum . "\t";
	$r .= $ir_class . $sd . $ir_class . "\t";
        $r .=
          $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ($img_internal) {
            my $sortVal = $mod_date; #dateSortVal($mod_date);
            $r .= $sortVal . $sd . "$mod_date\t";
            $r .= "$name\t";
        }
        $it->addRow($r);
    }

    #print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();

    if ($count > 10) {
	my $name = "_section_ImgTermBrowser_dbDeleteGeneTerm";
	print submit(
	    -name  => $name, 
	    -value => "Delete Term Association from Database", 
	    -class => 'lgbutton' 
	    ); 
    }
    print "<br/>\n";

    $it->printOuterTable(1);

    my $name = "_section_ImgTermBrowser_dbDeleteGeneTerm";
    print submit(
	-name  => $name, 
	-value => "Delete Term Association from Database", 
	-class => 'lgbutton' 
	); 
    print "<br/>\n";

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();

}


############################################################################
# dbDeleteGeneTerm
############################################################################
sub dbDeleteGeneTerm {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    my $contact_oid = getContactOid();
    my $imgEditor   = isImgEditor( $dbh, $contact_oid );
    if ( ! $imgEditor ) {
        return "You do not have the privilege to delete term association.";
    }

    if ( ! $term_oid ) {
        print "No term has been selected.";
    }

    my @selected_genes = param('gene_oid');
    if ( scalar(@selected_genes) == 0 ) {
        return "No genes have been selected.";
    }

    my @sqlList = ();
    for my $g1 ( @selected_genes ) {

	if ( ! $g1 || ! isInt($g1) ) {
	    return "Incorrect Gene ID: '" . $g1 . "'";
	}

	my $sql = "delete from gene_img_functions " .
	    "where gene_oid = $g1 and function = $term_oid";

	push @sqlList, ( $sql );
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        my $sql = $sqlList[ $err - 1 ];
	return "SQL Error: $sql";
    } 

    return;
}


############################################################################
# synonymCount - Get count of synonyms.
############################################################################
sub synonymCount {
    my ( $dbh, $term_oid ) = @_;

    my $sql = qq{
      select count( its.synonyms )
      from img_term_synonyms its
      where its.term_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# geneCount - Get count of genes for term.
############################################################################
sub geneCount {
    my ( $dbh, $term_oid ) = @_;

    my $taxonClause = txsClause("g.taxon", $dbh);
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql         = qq{
      select count( distinct g.gene_oid )
      from gene_img_functions g
      where g.function = ?
      $taxonClause
      $rclause
      $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printFusionComponents - Show fusion components invovled in the term.
############################################################################
sub printFusionComponents {
    my ( $dbh, $term_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>Fusion Component Terms</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
    	select distinct it2.term_oid, it2.term
    	from img_term it1, gene_img_functions gif1,
    	   gene_fusion_components gfc, gene_img_functions gif2, img_term it2
    	where it1.term_oid = ?
    	and it1.term_oid = gif1.function
    	and gif1.gene_oid = gfc.gene_oid
    	and gfc.component = gif2.gene_oid
    	and gif2.function = it2.term_oid
    	and it2.term_oid != ?
    	order by it2.term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $term_oid );
    for ( ; ; ) {
        my ( $term_oid2, $term2 ) = $cur->fetchrow();
        last if !$term_oid2;
        $term_oid2 = FuncUtil::termOidPadded($term_oid2);
        my $url = "$section_cgi&page=imgTermDetail&term_oid=$term_oid2";
        print alink( $url, $term_oid2 );
        print " - ";
        print escHtml($term2);
        print "<br/>\n";
    }
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printFusionRelated - Show related fusion protein.
############################################################################
sub printFusionRelated {
    my ( $dbh, $term_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>";
    print "Related Fusion Protein Terms</th>\n";
    print "<td class='img'>\n";
    my $sql = qq{
    	select distinct it2.term_oid, it2.term
    	from img_term it1, gene_img_functions gif1,
    	   gene_fusion_components gfc, gene_img_functions gif2, img_term it2
    	where it1.term_oid = ?
    	and it1.term_oid = gif1.function
    	and gif1.gene_oid = gfc.component
    	and gfc.gene_oid = gif2.gene_oid
    	and gif2.function = it2.term_oid
    	and it2.term_oid != ?
    	order by it2.term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $term_oid );
    for ( ; ; ) {
        my ( $term_oid2, $term2 ) = $cur->fetchrow();
        last if !$term_oid2;
        $term_oid2 = FuncUtil::termOidPadded($term_oid2);
        my $url = "$section_cgi&page=imgTermDetail&term_oid=$term_oid2";
        print alink( $url, $term_oid2 );
        print " - ";
        print escHtml($term2);
        print "<br/>\n";
    }
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printPathways  - Print related pathway information.
############################################################################
sub printPathways {
    my ( $dbh, $root, $term_oid ) = @_;

    my @term_oids;
    push( @term_oids, $term_oid );
    my %outPathwayOids;
    imgTerm2Pathways( $dbh, $root, \@term_oids, \%outPathwayOids );
    my @pathway_oids = sort( keys(%outPathwayOids) );
    my $pathway_oid_str = join( ',', @pathway_oids );
    if ( blankStr($pathway_oid_str) ) {
        print "<tr class='img' >\n";
        print "<th class='subhead'>IMG Pathways</th>\n";
        print "<td class='img' >\n";
        print nbsp(1);
        print "</td>\n";
        print "</tr>\n";
        return;
    }
    my $sql = qq{
    	select ipw.pathway_oid, ipw.pathway_name
    	from img_pathway ipw
    	where ipw.pathway_oid in( $pathway_oid_str )
    	order by ipw.pathway_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $s;
    print "<tr class='img'>\n";
    print "<th class='subhead'>";
    print "IMG Pathways</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $pathway_oid, $pathway_name ) = $cur->fetchrow();
        last if !$pathway_oid;
        my $pway_oid = FuncUtil::pwayOidPadded($pathway_oid);
        my $url      =
            "$main_cgi?section=ImgPwayBrowser"
          . "&page=imgPwayDetail&pway_oid=$pathway_oid";
        print alink( $url, $pway_oid );
        print " - ";
        print escHtml($pathway_name);
        print "<br/>\n";
    }
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";
}


############################################################################
# printPartsList - Print associated parts list.
############################################################################
sub printPartsList {
    my ( $dbh, $root, $term_oid ) = @_;

    my @term_oids;
    push( @term_oids, $term_oid );
    my %outPartsListOids;
    imgTerm2PartsList( $dbh, $root, \@term_oids, \%outPartsListOids );
    my @parts_list_oids = sort( keys(%outPartsListOids) );
    my $parts_list_oid_str = join( ',', @parts_list_oids );
    if ( blankStr($parts_list_oid_str) ) {
        print "<tr class='img' >\n";
        print "<th class='subhead'>IMG Parts List</th>\n";
        print "<td class='img' >\n";
        print nbsp(1);
        print "</td>\n";
        print "</tr>\n";
        return;
    }
    my $sql = qq{
    	select ipl.parts_list_oid, ipl.parts_list_name
    	from img_parts_list ipl
    	where ipl.parts_list_oid in( $parts_list_oid_str )
    	order by ipl.parts_list_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $s;
    print "<tr class='img'>\n";
    print "<th class='subhead'>";
    print "IMG Parts List</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $parts_list_oid, $parts_list_name ) = $cur->fetchrow();
        last if !$parts_list_oid;
        my $parts_list_oid = FuncUtil::partsListOidPadded($parts_list_oid);
        my $url            =
            "$main_cgi?section=ImgPartsListBrowser"
          . "&page=partsListDetail&parts_list_oid=$parts_list_oid";
        print alink( $url, $parts_list_oid );
        print " - ";
        print escHtml($parts_list_name);
        print "<br/>\n";
    }
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printLocalization  - Print localization information.
############################################################################
sub printLocalization {
    my ( $dbh, $term_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql     = qq{
    	select distinct g.cell_loc
    	from gene_img_functions g
    	where g.function = ?
    	and g.cell_loc is not null
    	$rclause
    	$imgClause
    	order by g.cell_loc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my @recs;
    for ( ; ; ) {
        my ($cell_loc) = $cur->fetchrow();
        last if !$cell_loc;
        push( @recs, $cell_loc );
    }
    $cur->finish();
    return if scalar(@recs) == 0;
    print "<tr class='img'>\n";
    print "<th class='subhead' align='right'>";
    print "Localization</th>\n";
    print "<td class='img'>\n";
    for my $cell_loc (@recs) {
        my $url = "$section_cgi&page=cellLocGenes&term_oid=$term_oid";
        print alink( $url, $cell_loc ) . "<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printCellLocGenes - Print localization genes.
############################################################################
sub printCellLocGenes {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql     = qq{
    	select distinct g.gene_oid, g.cell_loc
    	from gene_img_functions g
    	where g.function = ?
    	and g.cell_loc is not null
    	$rclause
    	$imgClause
    	order by g.gene_oid
    };
    my @gene_oids;
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );

    my $g_cell_loc;
    for ( ; ; ) {
        my ( $gene_oid, $cell_loc ) = $cur->fetchrow();
        last if !$gene_oid;
        $g_cell_loc = $cell_loc;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    
    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    print "<h1>Genes with Cell Localization</h1>\n";
    print "<p>\n";
    print "Genes in <i>" . escHtml($g_cell_loc) . "</i>.<br/>\n";
    print "</p>\n";

    printGeneCartFooter() if ( $count > 10 );
    my $dbh = dbLogin( );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    print "</p>\n";
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printTermGenomes - Print genomes with this term.
############################################################################
sub printTermGenomes {
    my ( $dbh, $term_oid ) = @_;

    my $rclause     = WebUtil::urClause('tx');
    my $imgClause   = WebUtil::imgClause('tx');
    my $taxonClause = txsClause("g.taxon", $dbh);
#    my $sql = qq{
#        select tx.domain, tx.seq_status, 
#           tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
#        from dt_img_term_path dtp, gene_img_functions g, taxon tx
#        where dtp.term_oid = ?
#        and dtp.map_term = g.function       
#        and g.taxon = tx.taxon_oid
#        $taxonClause
#        $rclause
#        $imgClause
#        group by 
#           tx.domain, tx.seq_status, 
#           tx.taxon_display_name, tx.taxon_oid
#        order by 
#           tx.domain, tx.seq_status, 
#           tx.taxon_display_name, tx.taxon_oid
#    };
    my $sql = qq{
        select tx.domain, tx.seq_status, 
	       tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
    	from gene_img_functions g, taxon tx
    	where g.function = ?
    	and g.taxon = tx.taxon_oid
        $taxonClause
    	$rclause
    	$imgClause
    	group by tx.domain, tx.seq_status, 
    	   tx.taxon_display_name, tx.taxon_oid
    	order by tx.domain, tx.seq_status, 
    	   tx.taxon_display_name, tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my @recs;
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $gene_cnt )
          = $cur->fetchrow();
        last if !$taxon_oid;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $r;
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$gene_cnt\t";
        push( @recs, $r );
    }
    $cur->finish();
    if (scalar(@recs) == 0) {
        return 0;
    }

    print "<h2>Genomes with Term</h2>\n";

    my $url = "$section_cgi&page=imgTermPhyloDist&term_oid=$term_oid";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );

    my $baseUrl = "$section_cgi&page=imgTermDetail&term_oid=$term_oid";

    my $ct = new InnerTable( 0, "imgTerm$$", "imgTerm", 0 );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome",         "char asc",    "left" );
    $ct->addColSpec( "Gene<br/>Count", "number desc", "right" );
    my $sdDelim = InnerTable::getSdDelim();

    my $select_id_name = "taxon_filter_oid";

    for my $r (@recs) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $gene_cnt )
          = split( /\t/, $r );
        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .=
          $taxon_display_name . $sdDelim
          . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=imgTermTaxonGenes";
        $url .= "&term_oid=$term_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_cnt . $sdDelim . alink( $url, $gene_cnt ) . "\t";
        $ct->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if (scalar(@recs) > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $ct->printTable();
    WebUtil::printGenomeCartFooter();

    if (scalar(@recs) > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }
    
    return 1;
}

# $term_oid_aref - list of term oids
# $ref_term_oid - main ref term oid
sub printTermGenomes_list {
    my ( $dbh, $term_oid_aref, $ref_term_oid ) = @_;

    my $str = join(",", @$term_oid_aref);
    
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $taxonClause = txsClause("g.taxon", $dbh);
#    my $sql = qq{
#        select tx.domain, tx.seq_status, 
#        tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
#        from dt_img_term_path dtp, gene_img_functions g, taxon tx
#        where dtp.term_oid in ($str)
#        and dtp.map_term = g.function
#        and g.taxon = tx.taxon_oid
#        $taxonClause
#        $rclause
#        $imgClause
#        group by tx.domain, tx.seq_status, 
#           tx.taxon_display_name, tx.taxon_oid
#        order by tx.domain, tx.seq_status, 
#           tx.taxon_display_name, tx.taxon_oid
#    };
    my $sql = qq{
        select tx.domain, tx.seq_status, 
        tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
        from gene_img_functions g, taxon tx
        where g.function in ($str)
        and g.taxon = tx.taxon_oid
        $taxonClause
        $rclause
        $imgClause
        group by tx.domain, tx.seq_status, 
           tx.taxon_display_name, tx.taxon_oid
        order by tx.domain, tx.seq_status, 
           tx.taxon_display_name, tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $gene_cnt )
          = $cur->fetchrow();
        last if !$taxon_oid;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $r;
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$gene_cnt\t";
        push( @recs, $r );
    }
    $cur->finish();
    return if scalar(@recs) == 0;

    print "<h2>Genomes with Terms</h2>\n";

    #my $url = "$section_cgi&page=imgTermPhyloDist&term_oid=$term_oid";
    #print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );

    #my $baseUrl = "$section_cgi&page=imgTermDetail&term_oid=$term_oid";
    my $ct = new InnerTable( 0, "imgTerm$$", "imgTerm", 0 );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome",         "char asc",    "left" );
    $ct->addColSpec( "Gene<br/>Count", "number desc", "right" );
    my $sdDelim = InnerTable::getSdDelim();

    my $select_id_name = "taxon_filter_oid";

    for my $r (@recs) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $gene_cnt )
          = split( /\t/, $r );
        my $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .=
          $taxon_display_name . $sdDelim
          . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=imgTermTaxonGenes2";
        $url .= "&ref_term_oid=$ref_term_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $url = alink($url, $gene_cnt);
        $r   .= $gene_cnt . $sdDelim .  $url  . "\t";
        
        $ct->addRow($r);
    }
    
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if (scalar(@recs) > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $ct->printOuterTable();
    WebUtil::printGenomeCartFooter();

    if (scalar(@recs) > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

}

############################################################################
# printImgTermTaxonGenes - Show genes for a give term and taxon.
############################################################################
sub printImgTermTaxonGenes {
    my $term_oid  = param("term_oid");
    my $taxon_oid = param("taxon_oid");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
#    my $sql         = qq{
#        select distinct g.gene_oid
#        from dt_img_term_path dtp, gene_img_functions g
#        where dtp.term_oid = $term_oid
#        and dtp.map_term = g.function
#        and g.taxon = $taxon_oid
#        $rclause
#        $imgClause
#        $taxonClause
#        order by g.gene_oid
#    };
    my $sql         = qq{
        select distinct g.gene_oid
    	from gene_img_functions g
    	where g.function = $term_oid
    	and g.taxon = $taxon_oid
    	$rclause
    	$imgClause
        $taxonClause
    	order by g.gene_oid
    };
    
    my @gene_oids = HtmlUtil::fetchGeneList($dbh, $sql);

    my $title = "Genes in Genome with Term";
    my $subtitle = "Genes in <i>" . escHtml($taxon_display_name) . "</i> ";
    HtmlUtil::printGeneListHtmlTable($title, $subtitle, $dbh, \@gene_oids);

}

sub printImgTermTaxonGenes_list {
    my $ref_term_oid  = param("ref_term_oid");
    my $taxon_oid = param("taxon_oid");
    
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $mgr       = new ImgTermNodeMgr();
    my $root      = $mgr->loadTree($dbh);
    my $n         = $root->ImgTermNode::findNode($ref_term_oid);
    
    # get all the img term oids for this node 
    my @children;
    $n->ImgTermNode::loadAllChildTermOids(\@children);

    my $str = join(",",@children);

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
#    my $sql = qq{
#        select distinct g.gene_oid
#        from dt_img_term_path dtp, gene_img_functions g
#        where dtp.term_oid in ($str)
#        and dtp.map_term = g.function
#        and g.taxon = ?
#        $taxonClause
#        $rclause
#        $imgClause
#        order by g.gene_oid
#    };
    my $sql = qq{
        select distinct g.gene_oid
	    from gene_img_functions g
	    where g.function in ($str)
	    and g.taxon = ?
        $taxonClause
	    $rclause
	    $imgClause
	    order by g.gene_oid
    };

    my @gene_oids = HtmlUtil::fetchGeneList($dbh, $sql, $verbose, $taxon_oid);
    my $title = "Genes in Genome with Terms";
    my $subtitle = "Genes in <i>" . escHtml($taxon_display_name) . "</i>.<br/>\n";
    HtmlUtil::printGeneListHtmlTable($title, $subtitle, $dbh, \@gene_oids);

}

############################################################################
# printImgTermPhyloDist - Print phylogenetic distribution for term.
############################################################################
sub printImgTermPhyloDist {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    my $sql = qq{
        select it.term
	from img_term it
	where it.term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my $name = $cur->fetchrow();
    $cur->finish();

    printMainForm();
    print "<h1>Phylogenetic Distribution for IMG Term</h1>\n";
    print "<p>\n";
    print "(Hits are shown in red.)<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections");

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $sql         = qq{
       select g.taxon, count( distinct g.gene_oid ) 
       from gene_img_functions g
       where g.function = ?
       $taxonClause
       $rclause
       $imgClause
       group by g.taxon
       order by g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my @taxon_oids;
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        $mgr->setCount( $taxon_oid, $cnt );
        push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();

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
# printImgTermHistory - Show history for this particular term.
#   For internal use only.
############################################################################
sub printImgTermHistory {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    print "<h1>IMG Term History</h1>\n";

    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
	select ith.term, 
	   ith.author, c.email, 
	   ith.term_new, ith.term_old, ith.action, to_char(ith.add_date, 'yyyy-mm-dd')
	from img_term_history ith, contact c
	where ith.term = $term_oid
	and ith.contact = c.contact_oid
	order by ith.add_date desc
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<h2>Term</h2>\n";
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Date</th>\n";
    print "<th class='img'>Author</th>\n";

    #print "<th class='img'>Email</th>\n";
    print "<th class='img'>New Term</th>\n";
    print "<th class='img'>Old Term</th>\n";
    print "<th class='img'>Action</th>\n";
    for ( ; ; ) {
        my ( $term, $author, $email, $term_new, $term_old, $action, $add_date )
          = $cur->fetchrow();
        last if !$term;
        $term_new = "-" if $term_new eq "";
        $term_old = "-" if $term_old eq "";
        print "<tr class='img'>\n";
        print "<td class='img'>" . escHtml($add_date) . "</td>\n";
        print "<td class='img'>" . escHtml($author) . "</td>\n";

        #print "<td class='img'>" . emailLink( $email ) . "</td>\n";
        print "<td class='img'>" . escHtml($term_new) . "</td>\n";
        print "<td class='img'>" . escHtml($term_old) . "</td>\n";
        print "<td class='img'>" . escHtml($action) . "</td>\n";
        print "</tr>\n";
    }
    $cur->finish();
    print "</table>\n";

    print "<h2>Gene Association</h2>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#    my $sql = qq{
#       select it.term_oid, gif.f_flag, g.gene_oid, g.gene_display_name, 
#          gif.confidence, gif.evidence, to_char(gif.mod_date, 'yyyy-mm-dd'), c.name, c.email
#       from gene g, gene_img_functions gif, dt_img_term_path dtp, contact c
#       where g.gene_oid = gif.gene_oid
#       and gif.modified_by = c.contact_oid
#       and g.function = dtp.map_term
#       and dtp.term_oid = $term_oid
#       $rclause
#       $imgClause
#       order by gif.mod_date desc, c.name
#    };
    my $sql = qq{
       select it.term_oid, gif.f_flag, g.gene_oid, g.gene_display_name, 
          gif.confidence, gif.evidence, to_char(gif.mod_date, 'yyyy-mm-dd'), c.name, c.email
       from gene g, gene_img_functions gif, contact c
       where g.gene_oid = gif.gene_oid
       and gif.modified_by = c.contact_oid
       and g.function = ?
       $rclause
       $imgClause
       order by gif.mod_date desc, c.name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Mod Date</th>\n";
    print "<th class='img'>Author</th>\n";

    #print "<th class='img'>Email</th>\n";
    print "<th class='img'>Gene<br/>Object<br/>Identifier</th>\n";
    print "<th class='img'>Gene<br/>Product<br/>Name</th>\n";
    print "<th class='img'>F_flag</th>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Confidence</th>\n";
    for ( ; ; ) {
        my (
            $term_oid,          $f_flag,     $gene_oid,
            $gene_display_name, $confidence, $evidence,
            $mod_date,          $name,       $email
          )
          = $cur->fetchrow();
        last if !$term_oid;
        print "<tr class='img'>\n";
        print "<td class='img'>" . escHtml($mod_date) . "</td>\n";
        print "<td class='img'>" . escHtml($name) . "</td>\n";

        #print "<td class='img'>" . emailLink( $email ) . "</td>\n";
        my $url = "$main_cgi?section=GeneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img'>" . escHtml($gene_display_name) . "</td>\n";
        print "<td class='img'>" . escHtml($f_flag) . "</td>\n";
        print "<td class='img'>" . escHtml($evidence) . "</td>\n";
        print "<td class='img'>" . escHtml($confidence) . "</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();
    print "<p>\n";
    print "Note: F_flag notes: M=manul. Automatic annotation flags: ";
    print "C=complete, P=partial match.<br/>\n";
    print "</p>\n";

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# imgReactionCount - Get count of IMG reactions given term_oid.
############################################################################
sub imgReactionCount {
    my ( $dbh, $term_oid ) = @_;

    my $sql = qq{
        select distinct count( distinct irc.rxn_oid )
        from img_reaction_catalysts irc
    	where irc.catalysts = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($count1) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
        select distinct count( distinct itc.rxn_oid )
        from img_reaction_t_components itc
    	where itc.term = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($count2) = $cur->fetchrow();
    $cur->finish();

    return $count1 + $count2;
}

############################################################################
# printImgReactions - Get count of IMG reactions given term_oid.
############################################################################
sub printImgReactions {
    my $term_oid = param("term_oid");

    print "<h1>IMG Reactions</h1>\n";
    my $dbh = dbLogin();
    my $sql = qq{
        select term
	from img_term
	where term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    print "<p>\n";
    print "IMG reactions for <i>" . escHtml($term) . "</i>.<br/>\n";
    print "</p>\n";

    my $sql = qq{
        select distinct ir.rxn_oid rxn_oid, ir.rxn_name rxn_name
        from img_reaction_catalysts irc, img_reaction ir
	where irc.catalysts = ?
	and irc.rxn_oid = ir.rxn_oid
	    union
        select distinct ir.rxn_oid rxn_oid, ir.rxn_name rxn_name
        from img_reaction_t_components itc, img_reaction ir
	where itc.term = ?
	and itc.rxn_oid = ir.rxn_oid
	order by rxn_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid, $term_oid );
    print "<p>\n";
    for ( ; ; ) {
        my ( $rxn_oid, $rxn_name ) = $cur->fetchrow();
        last if !$rxn_oid;
        my $url = "$main_cgi?section=ImgReaction";
        $url .= "&page=imgRxnDetail&rxn_oid=$rxn_oid";
        $rxn_oid = sprintf( "%05d", $rxn_oid );
        print alink( $url, $rxn_oid );
        print nbsp(1);
        print escHtml($rxn_name);
        print "<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
}

############################################################################
# getTermStats - Get term statistics.
############################################################################
sub getTermStats {
    my ($dbh) = @_;

    my ( $gene_product, $modified_protein, $protein_complex );
    my $sql = qq{
        select term_type, count( distinct term_oid )
	from img_term
	group by term_type
	order by term_type
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_type, $cnt ) = $cur->fetchrow();
        last if !$term_type;
        if ( $term_type eq "PROTEIN COMPLEX" ) {
            $protein_complex = $cnt;
        } elsif ( $term_type eq "MODIFIED PROTEIN" ) {
            $modified_protein = $cnt;
        } else {
            $gene_product = $cnt;
        }
    }
    $cur->finish();

    return ( $gene_product, $modified_protein, $protein_complex );
}

############################################################################
# bbhClusterCount - Get BBH cluster count for term.
############################################################################
sub bbhClusterCount {
    my ( $dbh, $term_oid ) = @_;

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $sql         = qq{
       select count( distinct bbhg.cluster_id )
       from gene_img_functions g, bbh_cluster_member_genes bbhg
       where g.function = ?
       and g.gene_oid = bbhg.member_genes
       $rclause
       $imgClause
       $taxonClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# cogCount - Get COG count for term.
############################################################################
sub cogCount {
    my ( $dbh, $term_oid ) = @_;

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $sql         = qq{
       select count( distinct gcg.cog )
       from gene_img_functions g, gene_cog_groups gcg
       where g.function = ?
       and g.gene_oid = gcg.gene_oid
       $taxonClause
       $rclause
       $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# pfamCount - Get Pfam count for term.
############################################################################
sub pfamCount {
    my ( $dbh, $term_oid ) = @_;

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $sql         = qq{
       select count( distinct gpf.pfam_family )
       from gene_img_functions g, gene_pfam_families gpf
       where g.function = ?
       and g.gene_oid = gpf.gene_oid
       $taxonClause
       $rclause
       $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# tigrfamCount - Get  TIGRfam count for term.
############################################################################
sub tigrfamCount {
    my ( $dbh, $term_oid ) = @_;

    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = txsClause("g.taxon", $dbh);
    my $sql         = qq{
       select count( distinct tf.ext_accession )
       from gene_img_functions g, gene_tigrfams tf
       where g.function = ?
       and g.gene_oid = tf.gene_oid
       $taxonClause
       $rclause
       $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printGeneTerms
############################################################################
sub printGeneTerms {
    my ($dbh, $gene_ids_ref, $recs_ref, $isBbhCluster ) = @_;    
    my @gene_ids = @$gene_ids_ref;   
    my @recs = @$recs_ref;

    my ($geneOid2Terms_href, $termOid2Term_href) = getGeneTerms( $dbh, @gene_ids );

    printGeneCartFooter();
    print "<p>\n";
    my $select_id_name = "gene_oid";

    my $old_cluster_id;
    my $count = 0;
    for my $r (@recs) {
        my ( $cluster_id, $cluster_name, $gene_oid, $gene_display_name )
          = split( /\t/, $r );
        last if !$gene_oid;
        $count++;
        my $term_oid_str = $geneOid2Terms_href->{$gene_oid};
        $term_oid_str =~ s/^\s+//;
        $term_oid_str =~ s/\s+$//;
        my @term_oids   = split( / /, $term_oid_str );
        my %term_oids_h = WebUtil::array2Hash(@term_oids);
        my $nTerms      = @term_oids;

        if ( $old_cluster_id ne $cluster_id ) {
            print "<br/>\n";
            if ( $isBbhCluster ) {
                print "<b>BBH Cluster $cluster_id</b>\n";
            }
            else {
                print "<b>$cluster_id</b>";
                if ($cluster_name ne '') {
                    print " - " . escHtml($cluster_name);                
                }                
            }
            print "<br/>\n";
        }

        print nbsp(2);
        print "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\n";
        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid";
        print alink( $url, $gene_oid );
        print nbsp(1);
        if ( $nTerms > 0 ) {
            my $color = "green";
            print "<font color='$color'>\n";
        }
        print escHtml($gene_display_name);
        if ( $nTerms > 0 ) {
            print "</font>\n";
        }
        print nbsp(1);
        if ( $nTerms > 0 ) {
            print "(terms: ";
            my $s;
            for my $term_oid (@term_oids) {
                my $term = $termOid2Term_href->{$term_oid};
                $term_oid = FuncUtil::termOidPadded($term_oid);
                my $url = "$main_cgi?section=ImgTermBrowser";
                $url .= "&page=imgTermDetail&term_oid=$term_oid";
                $s   .= "<a href='$url' title='$term'>$term_oid</a> ";
            }
            print "$s";
            print ")";
        }
        print "<br/>\n";
        $old_cluster_id = $cluster_id;
    }
    print "</p>\n";

    printGeneCartFooter() if $count > 10;
    if ($count > 0) {
        print "<br/>\n";
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);     
    }

    return $count;
}

sub getGeneTerms {
    my ( $dbh, @gene_ids ) = @_;    
    #print "getGeneTerms() gene_ids: @gene_ids<br/>";

    my %geneOid2Terms;
    my %termOid2Term;    
    if (scalar(@gene_ids) > 0) {
        my $gene_id_str = OracleUtil::getNumberIdsInClause( $dbh, @gene_ids );

        my $taxonClause = txsClause("g.taxon", $dbh);
        my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
        my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
           select distinct g.gene_oid, it.term_oid, it.term
           from gene_img_functions g, img_term it
           where g.gene_oid in ( $gene_id_str )
           and g.function = it.term_oid
           $taxonClause
           $rclause
           $imgClause
           order by g.gene_oid, it.term_oid
        };
        #print "getGeneTerms() sql: $sql<br/>\n";
        my @bindList = ();
        if (scalar(@bindList_ur) > 0) {
            push (@bindList, @bindList_ur);             
        }
        #print "bindList: @bindList<br/>";
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose);
        for ( ; ; ) {
            my ( $gene_oid, $term_oid, $term ) = $cur->fetchrow();
            last if !$gene_oid;
            $term_oid = FuncUtil::termOidPadded($term_oid);
            $geneOid2Terms{$gene_oid} .= "$term_oid ";
            $termOid2Term{$term_oid} = $term;
        }
        $cur->finish();        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $gene_id_str =~ /gtt_num_id/i );
    }

    return (\%geneOid2Terms, \%termOid2Term);
}

############################################################################
# printBbhClusterGenes - Show clusters with IMG term
############################################################################
sub printBbhClusterGenes {
    my $term_oid  = param("term_oid");
    my $term_oid0 = FuncUtil::termOidPadded($term_oid);

    my $dbh = dbLogin();
    my $sql = qq{
       select term
       from img_term
       where term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid0 );
    my ($term) = $cur->fetchrow();
    $cur->finish();

    print "<h1>BBH Cluster Genes</h1>\n";
    print "<p>\n";
    print "Genes with current IMG term<br/>";
    my $url = "$section_cgi&page=imgTermDetails&term_oid=$term_oid0";
    print "<a href='$url' title='$term'>$term_oid</a> ";
    print nbsp(1);
    print "<i>" . escHtml($term) . "</i><br/>";
    print "are shown in green.<br/>\n";
    print "</p>\n";
    printHint(
        qq{
       - Mouse over term object identifier to see term name.<br/>
    }
    );
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $taxonClause = txsClause("g.taxon", $dbh);    
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
       select distinct bbhg.cluster_id, g.gene_oid, g.gene_display_name
       from gene_img_functions gif, gene g, bbh_cluster_member_genes bbhg
       where gif.function = ?
       and gif.gene_oid = bbhg.member_genes
       and bbhg.member_genes = g.gene_oid
       $taxonClause
       $rclause
       $imgClause
       order by bbhg.cluster_id, g.gene_display_name
    };
    #print "printBbhClusterGenes \$sql: $sql<br/>\n";
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);             
    }
    #print "\@bindList: @bindList<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose);
    
    my @gene_ids;    
    my @recs = ();
    for ( ; ; ) {
        my ( $cluster_id, $gene_oid, $gene_display_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_ids, $gene_oid );
        
        my $r = "$cluster_id\t";
        $r .= "\t";
        $r .= "$gene_oid\t";
        $r .= "$gene_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();

    my $count = printGeneTerms($dbh, \@gene_ids, \@recs, 1 );

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printCogGenes - Show COG with IMG term
############################################################################
sub printCogGenes {
    my $term_oid  = param("term_oid");
    my $term_oid0 = FuncUtil::termOidPadded($term_oid);

    my $dbh = dbLogin();
    my $sql = qq{
       select term
       from img_term
       where term_oid = ? 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid0 );
    my ($term) = $cur->fetchrow();
    $cur->finish();

    print "<h1>COG Genes</h1>\n";
    print "<p>\n";
    print "Genes with current IMG term<br/>";
    my $url = "$section_cgi&page=imgTermDetails&term_oid=$term_oid0";
    print "<a href='$url' title='$term'>$term_oid</a> ";
    print nbsp(1);
    print "<i>" . escHtml($term) . "</i><br/>";
    print "are shown in green.<br/>\n";
    print "</p>\n";
    printHint(
        qq{
       - Mouse over term object identifier to see term name.<br/>
    }
    );

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $taxonClause = txsClause("g.taxon", $dbh);
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
       select distinct c.cog_id, c.cog_name,
          g.gene_oid, g.gene_display_name
       from gene_img_functions gif, gene g, gene_cog_groups gcg, cog c
       where gif.function = ?
       and gif.gene_oid = gcg.gene_oid
       and gcg.cog = c.cog_id
       and gcg.gene_oid = g.gene_oid
       $taxonClause
       $rclause
       $imgClause
       order by c.cog_id, c.cog_name, g.gene_display_name
    };
    #print "printCogGenes \$sql: $sql<br/>\n";
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);             
    }
    #print "bindList: @bindList<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose);

    my @gene_ids;
    my @recs = ();
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_oid, $gene_display_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_ids, $gene_oid );
        
        my $r = "$cluster_id\t";
        $r .= "$cluster_name\t";
        $r .= "$gene_oid\t";
        $r .= "$gene_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();
    #print "gene_ids: @gene_ids<br/>";

    my $count = printGeneTerms($dbh, \@gene_ids, \@recs );

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printPfamGenes - Show Pfams with IMG term
############################################################################
sub printPfamGenes {
    my $term_oid  = param("term_oid");
    my $term_oid0 = FuncUtil::termOidPadded($term_oid);

    my $dbh = dbLogin();
    my $sql = qq{
       select term
       from img_term
       where term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid0 );
    my ($term) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Pfam Family Genes</h1>\n";
    print "<p>\n";
    print "Genes with current IMG term<br/>";
    my $url = "$section_cgi&page=imgTermDetails&term_oid=$term_oid0";
    print "<a href='$url' title='$term'>$term_oid</a> ";
    print nbsp(1);
    print "<i>" . escHtml($term) . "</i><br/>";
    print "are shown in green.<br/>\n";
    print "</p>\n";
    printHint(
        qq{
       - Mouse over term object identifier to see term name.<br/>
    }
    );
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $taxonClause = txsClause("g.taxon", $dbh);    
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
       select distinct pf.ext_accession, pf.name,
          g.gene_oid, g.gene_display_name
       from gene_img_functions gif, gene g, gene_pfam_families gpf, 
          pfam_family pf
       where gif.function = ? 
       and gif.gene_oid = gpf.gene_oid
       and gpf.pfam_family = pf.ext_accession
       and gpf.gene_oid = g.gene_oid
       $taxonClause
       $rclause
       $imgClause
       order by pf.ext_accession, pf.name, g.gene_display_name
    };
    #print "printPfamGenes \$sql: $sql<br/>\n";
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);             
    }
    #print "bindList: @bindList<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose);

    my @gene_ids;    
    my @recs = ();
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_oid, $gene_display_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_ids, $gene_oid );
        
        my $r = "$cluster_id\t";
        $r .= "$cluster_name\t";
        $r .= "$gene_oid\t";
        $r .= "$gene_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();

    my $count = printGeneTerms($dbh, \@gene_ids, \@recs );
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printTigrfamGenes - Show Pfams with IMG term
############################################################################
sub printTigrfamGenes {
    my $term_oid  = param("term_oid");
    my $term_oid0 = FuncUtil::termOidPadded($term_oid);

    my $dbh = dbLogin();
    my $sql = qq{
       select term
       from img_term
       where term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid0 );
    my ($term) = $cur->fetchrow();
    $cur->finish();

    print "<h1>TIGRfam Genes</h1>\n";
    print "<p>\n";
    print "Genes with current IMG term<br/>";
    my $url = "$section_cgi&page=imgTermDetails&term_oid=$term_oid0";
    print "<a href='$url' title='$term'>$term_oid</a> ";
    print nbsp(1);
    print "<i>" . escHtml($term) . "</i><br/>";
    print "are shown in green.<br/>\n";
    print "</p>\n";
    printHint(
        qq{
       - Mouse over term object identifier to see term name.<br/>
    }
    );
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $taxonClause = txsClause("g.taxon", $dbh);    
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $sql = qq{
       select distinct tf.ext_accession, tf.expanded_name,
          g.gene_oid, g.gene_display_name
       from gene_img_functions gif, gene g, gene_tigrfams gtf,
          tigrfam tf
       where gif.function = ?
       and gif.gene_oid = gtf.gene_oid
       and gtf.ext_accession = tf.ext_accession
       and gtf.gene_oid = g.gene_oid
       $taxonClause
       $rclause
       $imgClause
       order by tf.ext_accession, tf.expanded_name, g.gene_display_name
    };
    #print "printTigrfamGenes \$sql: $sql<br/>\n";
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);             
    }
    #print "\@bindList: @bindList<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose);
    
    my @gene_ids;    
    my @recs = ();
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_oid, $gene_display_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_ids, $gene_oid );
        
        my $r = "$cluster_id\t";
        $r .= "$cluster_name\t";
        $r .= "$gene_oid\t";
        $r .= "$gene_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();

    my $count = printGeneTerms($dbh, \@gene_ids, \@recs );
    
    print end_form();
    printStatusLine( "$count gene(s) retrieved.", 2 );
}

############################################################################
# printAlphaList - Print alphabetical listing of pathways.
############################################################################
sub printAlphaList {
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $sql = qq{
       select it.term_oid, it.term
       from img_term it
       order by lower( it.term )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;
        my $r = "$term_oid\t";
        $r .= "$term";
        push( @recs, $r );
    }
    $cur->finish();
    #$dbh->disconnect();

    my $nRecs = @recs;
    if ( $nRecs == 0 ) {
        print "<p>\n";
        print "No IMG terms are found in this database.<br/>\n";
        print "</p>\n";
        return;
    }

    printMainForm();
    print "<h1>IMG Terms (Alphabetical)</h1>\n";
    
    my $it = new InnerTable( 1, "tigrlist$$", "tigrlist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Term ID",   "char asc", "left" );
    $it->addColSpec( "Term Name", "char asc", "left" );  

    my $select_id_name = "term_oid";
        
    my $count = 0;
    for my $r (@recs) {
        my ( $term_oid, $term ) = split( /\t/, $r );
        my $term_oid = FuncUtil::termOidPadded($term_oid);
        $count++;
    
        my $r;
        $r .= $sd
          . "<input type='checkbox' name='$select_id_name' "
          . "value='$term_oid' />" . "\t";

        my $url = "$section_cgi&page=imgTermDetail";
        $url .= "&term_oid=$term_oid";
    
        $r .= $term_oid . $sd . alink( $url, $term_oid ) . "\t";
        $r .= $term . $sd . $term . "\t";

        $it->addRow($r);
    }

    WebUtil::printFuncCartFooterForEditor() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooterForEditor();

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'term_oid' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }
    
    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

sub printImgTermList {
    my $term_type = param("term_type");

    printMainForm();

    if ( $term_type eq "connpathway" ) {
        print "<h1>IMG Terms connected to Pathways</h1>";
    } elsif ( $term_type eq "connparts" ) {
        print "<h1>IMG Terms connected to Parts Lists</h1>";
    } elsif ( $term_type eq "notconnpathorparts" ) {
        print "<h1>IMG Terms not connected to Pathways or Parts Lists</h1>";
    } elsif ( $term_type eq "notconnpath" ) {
        print "<h1>IMG Terms not connected to Pathways</h1>";
    } elsif ( $term_type eq "notconnparts" ) {
        print "<h1>IMG Terms not connected to Parts Lists</h1>";
    } elsif ( $term_type eq "notconngene" ) {
        print "<h1>IMG Terms not connected to Genes (missing genes)</h1>";
    } elsif ( $term_type eq "GENE PRODUCT" ) {
        print "<h1>Gene Product</h1>";
    } elsif ( $term_type eq "MODIFIED PROTEIN" ) {
        print "<h1>Modified Protein</h1>";
    } elsif ( $term_type eq "PROTEIN COMPLEX" ) {
        print "<h1>Protein Complex</h1>";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $tree_href;
    my $pathways_href;
    my $parts_href;
    if (   $term_type eq "notconnpath"
        || $term_type eq "notconnpathorparts"
        || $term_type eq "connpathway" )
    {
        $tree_href     = getImgChildParent($dbh);
        $pathways_href = getAllImgConnPath($dbh);
    }
    if (   $term_type eq "notconnparts"
        || $term_type eq "notconnpathorparts"
        || $term_type eq "connparts" )
    {
        if ( $tree_href eq "" ) {
            $tree_href = getImgChildParent($dbh);
        }
        $parts_href = getAllImgConnParts($dbh);
    }

    my $sql = qq{
        select term_oid, term
        from img_term
        where term_type = ?
    };

    my $cur;
    if ( $term_type eq "connpathway" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'        
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $term_type eq "connparts" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'      
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $term_type eq "notconnpathorparts" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            minus
            (
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select irc.catalysts
            from img_reaction_catalysts irc, img_pathway_reactions ipr
            where irc.rxn_oid = ipr.rxn
            union
            select irtc2.term
            from img_reaction_t_components irtc2, img_pathway_reactions ipr2
            where irtc2.rxn_oid = ipr2.rxn)
            union
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select t2.term from img_parts_list_img_terms t2)
            )       
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $term_type eq "notconnpath" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            minus 
            (
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select irc.catalysts
            from img_reaction_catalysts irc, img_pathway_reactions ipr
            where irc.rxn_oid = ipr.rxn
            union
            select irtc2.term
            from img_reaction_t_components irtc2, img_pathway_reactions ipr2
            where irtc2.rxn_oid = ipr2.rxn)
            )       
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $term_type eq "notconnparts" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            minus
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select t2.term from img_parts_list_img_terms t2)    
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $term_type eq "notconngene" ) {
        $sql = qq{
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            minus
            select t.term_oid, t.term
            from img_term t
            where t.term_type = 'GENE PRODUCT'
            and t.term_oid in
            (select t2.function from gene_img_functions t2)    
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } else {
        my @a = ($term_type);
        $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    }
    
    my $it    = new InnerTable( 1, "imgterm$$", "imgterm", 1 );
    my $sd    = $it->getSdDelim();                              # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "IMG Term ID", "number asc", "right" );
    $it->addColSpec( "Name",        "char asc",   "left" );

    my $select_id_name = "term_oid";

    my $count = 0;
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;

        if ( $term_type eq "notconnpath" || $term_type eq "notconnpathorparts" )
        {
            my %cycle;
            $cycle{$term_oid} = "";
            my $res =
              isConnPathway( $term_oid, $pathways_href, $tree_href, \%cycle );
            next if ( $res == 1 );
        } elsif ( $term_type eq "connpathway" ) {
            my %cycle;
            $cycle{$term_oid} = "";
            my $res =
              isConnPathway( $term_oid, $pathways_href, $tree_href, \%cycle );
            next if ( $res == 0 );
        }

        if (   $term_type eq "notconnparts"
            || $term_type eq "notconnpathorparts" )
        {
            my %cycle;
            $cycle{$term_oid} = "";
            my $res =
              isConnPathway( $term_oid, $parts_href, $tree_href, \%cycle );
            next if ( $res == 1 );
        } elsif ( $term_type eq "connparts" ) {
            my %cycle;
            $cycle{$term_oid} = "";
            my $res =
              isConnPathway( $term_oid, $parts_href, $tree_href, \%cycle );
            next if ( $res == 0 );
        }

        $count++;
        my $r;

        my $term_oid = FuncUtil::termOidPadded($term_oid);
        $r .= $sd
          . "<input type='checkbox' name='$select_id_name' "
          . "value='$term_oid' />" . "\t";

        my $url = "$section_cgi&page=imgTermDetail";
        $url .= "&term_oid=$term_oid";
        $r   .= $term_oid . $sd . alink( $url, $term_oid ) . "\t";
        $r   .= $term . $sd . $term . "\t";

        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    WebUtil::printFuncCartFooterForEditor() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooterForEditor();

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'term_oid' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
    
}

1;

