############################################################################
# ImgPartsListBrowser - Show parts list and detetails.
#   --imachen 03/17/2007
#
# $Id: ImgPartsListBrowser.pm 30115 2014-02-17 06:15:54Z jinghuahuang $
############################################################################
package ImgPartsListBrowser;
my $section = "ImgPartsListBrowser";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use GeneDetail;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;
use ImgTermNode;
use ImgTermNodeMgr;
use ImgNetworkBrowser;
use HtmlUtil;
use WorkspaceUtil;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $tab_panel = $env->{ tab_panel };
my $content_list = $env->{ content_list };

############################################################################
# dispatch
############################################################################
sub dispatch {
    my $page =  param( "page" );

    if( $page eq "partsListDetail" ) {
       printPartsListDetail( );
    }
    else {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section );        
        HtmlUtil::cgiCacheStart() or return; 
        
        # if not tabs then use list
        if(!$tab_panel) {
            ImgNetworkBrowser::printImgFam();
        }        
       
       printPartsList( );
       HtmlUtil::cgiCacheStop();
    }
}


sub printJavaScript {
    print qq{
    <script>
    function selectAllCheckBoxes4( x ) {
        var f = document.mainForm4;
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
# printPartList - Print parts list.
############################################################################
sub printPartsList {
    printStatusLine( "Loading ...", 1 ); 
    my $dbh = dbLogin( );
    my $sql = qq{
       select pl.parts_list_oid, pl.parts_list_name
       from img_parts_list pl
       order by pl.parts_list_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for( ;; ) {
        my( $parts_list_oid, $parts_list_name ) = $cur->fetchrow( );
    	last if !$parts_list_oid;
    	my $r = "$parts_list_oid\t";
    	$r .= "$parts_list_name";
    	push( @recs, $r );
    }
    $cur->finish( );
    #$dbh->disconnect();
    
    my $nRecs = @recs;
    return if $nRecs == 0;

    print "<h1>IMG Parts List</h1>\n";
    print "<p>\n";
    print "Parts list organizes components involved ";
    print "in various cellular processes.<br/>\n";
    
    # ajax pages need its own form name - ken
    WebUtil::printMainFormName("4");

    my $it = new InnerTable( 1, "partslist$$", "partslist", 2 );
    $it->addColSpec("Select");
    $it->addColSpec( "Parts List ID",     "number asc", "right" );
    $it->addColSpec( "Parts List Name",    "char asc",   "left" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "parts_list_oid";
    
    my $count = 0;
    for my $r( @recs ) {
       my( $parts_list_oid, $parts_list_name ) = split( /\t/, $r );
       $parts_list_oid = FuncUtil::partsListOidPadded( $parts_list_oid );
       $count++;       
       my $url = "$section_cgi&page=partsListDetail"
                . "&parts_list_oid=$parts_list_oid";
       my $r;
       $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$parts_list_oid' />" ."\t";
       $r .= $parts_list_oid . $sd . alink( $url, $parts_list_oid ) ."\t";
       $r .= $parts_list_name . $sd . escHtml( $parts_list_name ) ."\t";
       $it->addRow($r);
    }
    
    WebUtil::printFuncCartFooterForEditor("4" ) if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooterForEditor("4" );

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'parts_list_oid' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form( );
    
    printJavaScript();
}

############################################################################
# printPartsListDetail - Print details for a given parts list.
############################################################################
sub printPartsListDetail {
    my $parts_list_oid = param( "parts_list_oid" );

    printMainForm( );

    print "<h1>IMG Parts List Details</h1>\n";
    my $dbh = dbLogin( );
    my $sql = qq{
        select pl.parts_list_oid, pl.parts_list_name,
    	   pl.definition, to_char(pl.add_date, 'yyyy-mm-dd'), to_char(pl.mod_date, 'yyyy-mm-dd'),
    	   c.name, c.email
    	from img_parts_list pl, contact c
    	where pl.modified_by = c.contact_oid
    	and pl.parts_list_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $parts_list_oid );
    my( $parts_list_oid, $parts_list_name, $definition,
        $add_date, $mod_date, $name, $email ) = $cur->fetchrow( );
    $cur->finish( );
    $parts_list_oid = FuncUtil::partsListOidPadded( $parts_list_oid );

    print "<table class='img' border='1'>\n";
    printAttrRow( "Parts List OID", $parts_list_oid );
    printAttrRow( "Name", $parts_list_name );
    printAttrRow( "Definition", $definition );
    printAttrRow( "Add Date", $add_date );
    printAttrRow( "Modify Date", $mod_date );
    my $s = escHtml( $name ); 
    #$s .= emailLinkParen( $email );
    printAttrRowRaw( "Modified By", $s );
    print "</table>\n";

    print "<h3>IMG Terms</h3>\n";
    print "<p>\n";
    print "IMG terms specify components involved in the parts list.<br/>\n";
    print "</p>\n";

    my $sql = qq{
       select it.term_oid, it.term
       from img_term it, img_parts_list_img_terms plt
       where plt.term = it.term_oid
       and plt.parts_list_oid = ?
       order by plt.list_order
    };
    my $cur = execSql( $dbh, $sql, $verbose, $parts_list_oid );

    my $it = new InnerTable( 1, "termlist$$", "termlist", 2 );
    $it->addColSpec("Select");
    $it->addColSpec( "Term ID",     "number asc", "right" );
    $it->addColSpec( "Term Name",    "char asc",   "left" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "term_oid";
    
    my $count = 0;
    for( ;; ) {
       my( $term_oid, $term ) = $cur->fetchrow( );
       last if !$term_oid;
       $term_oid = FuncUtil::termOidPadded( $term_oid );
       $count++;
       my $url = "$main_cgi?section=ImgTermBrowser" 
               . "&page=imgTermDetail&term_oid=$term_oid";
       my $r;
       $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$term_oid' />" ."\t";
       $r .= $term_oid . $sd . alink( $url, $term_oid ) ."\t";
       $r .= $term . $sd . escHtml( $term ) ."\t";
       $it->addRow($r);
    }
    $cur->finish( );
    #$dbh->disconnect();

    WebUtil::printFuncCartFooterForEditor( ) if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooterForEditor( );

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'term_oid' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    print end_form( );
}

