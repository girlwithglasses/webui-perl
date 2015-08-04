############################################################################
# ImgNetworkBrowser.pm - Network Browser module.
# $Id: ImgNetworkBrowser.pm 29998 2014-01-29 23:05:26Z jinghuahuang $
############################################################################
package ImgNetworkBrowser;
my $section = "ImgNetworkBrowser";

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use PwNwNode;
use PwNwNodeMgr;
use DataEntryUtil;
use FuncUtil;
use HtmlUtil;
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

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "imgNetworkBrowser" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section );        
        HtmlUtil::cgiCacheStart() or return;
        
        # if not tabs then use list
        if ( !$tab_panel ) {
            printImgFam();
        }

        printImgNetworkBrowser();
        HtmlUtil::cgiCacheStop();

    } elsif ( $page eq "pathwayNetworkDetail" ) {
        printPathwayNetworkDetail();
    } elsif ( $page eq "" ) {
        # do nothing
    } else {
        print "<h1>Incorrect Page: $page</h1>\n";
    }
}

#
# list of other IMG Network pages
#
sub printImgFam {
    my $url = "$base_url/doc/imgterms.html";
    my $link = "<a href=$url target=_blank>IMG Networks</a>";
    my $text = "IMG Pathways are linked together through the common metabolites or macromolecular complexes to form $link. IMG Networks correspond to the fragments of a metabolic map that are known to perform a certain physiological role. IMG Networks can be linked to higher level IMG Networks based, again, on a common physiological role. ";
 
    if ($include_metagenomes) { 
        WebUtil::printHeaderWithInfo 
            ("IMG Network", $text, 
             "show description for this tool", "IMG Network Info", 1);
    } else { 
        WebUtil::printHeaderWithInfo 
            ("IMG Network", $text,
             "show description for this tool", "IMG Network Info");
    } 

    my $link = alink( $url, "IMG Terms and Pathways" );
    print "<p>\n";
    print "IMG controlled terminology is shown below.<br/>\n";
    print "For documentation, see $link.";
    print "</p>\n";

    print "<p>\n";
    my $url = "main.cgi?section=ImgNetworkBrowser&page=imgNetworkBrowser";
    my $link = alink( $url, "IMG Network Browser" );
    print "$link<br>\n";

    my $url = "main.cgi?section=ImgPartsListBrowser&page=browse";
    my $link = alink( $url, "IMG Parts List" );
    print "$link<br>\n";

    my $url = "main.cgi?section=ImgPwayBrowser&page=imgPwayBrowser";
    my $link = alink( $url, "IMG Pathways" );
    print "$link<br>\n";

    my $url = "main.cgi?section=ImgTermBrowser&page=imgTermBrowser";
    my $link = alink( $url, "IMG Terms" );
    print "$link<br>\n";

    my $url = "main.cgi?section=ImgCompound&page=browse";
    my $link = alink( $url, "IMG Compounds" );
    print "$link<br>\n";
    print "</p>";
}

sub printJavaScript {
    print qq{
    <script>
    function selectAllCheckBoxes1( x ) {
        var f = document.mainForm1;
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
# printImgNetworkBrowser - Show network hierarchy
############################################################################
sub printImgNetworkBrowser {
    my $dbh = dbLogin();

    my $is_editor   = 0;
    my $contact_oid = getContactOid();
    $is_editor = isImgEditor( $dbh, $contact_oid )
      if $contact_oid > 0;

    print "<h1>IMG Network Browser</h1>\n";
    printStatusLine( "Loading ...", 1 );

    # also see printJavaScript() var f = document.mainForm1;
    WebUtil::printMainFormName("1");
    print "<p>\n";
    print "IMG networks organize IMG pathways and parts lists.<br/>";
    if ($is_editor) {
        print "<b>Note:</b> Currently, only IMG pathways and parts lists ";
        print "can be added to the function cart.<br/>\n";
    }
    print "</p>\n";

    my $sql = qq{
	select count(*)
	from pathway_network
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    if ( $cnt == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "This database has no function networks.\n";
        print "</p>\n";
        print "</div>\n";
        #$dbh->disconnect();
        return;
    }
    my $mgr = new PwNwNodeMgr();
    printNetworkFooter($dbh);

    $mgr->loadTree();
    my $root = $mgr->{root};
    print "<p>\n";

print <<EOF;
    <script language="javascript" type="text/javascript">
    function selectMetaCyc(parentId, level) {
        var f = document.mainForm1;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
              
            if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                e.checked = true;
            }
            
            if( e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }
    }

    function clearMetaCyc(parentId, level) {
        var f = document.mainForm1;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
              
            if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                e.checked = false;
            }
            
            if(e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }        
    }

    </script>
EOF
        
    printCompleteNetworkHtml( $root, $is_editor );
    print "</p>\n";
    printNetworkFooter($dbh);
    #$dbh->disconnect();

    WorkspaceUtil::printSaveFunctionToWorkspace('pway_oid');

    printStatusLine( "Loaded.", 2 );
    print end_form();

    printJavaScript();

}

############################################################################
# printCompleteNetworkHtml - print complete network, with pathways and
#                            parts lists
############################################################################
sub printCompleteNetworkHtml {
    my ( $root, $is_editor ) = @_;

    my $type = $root->{type};
    my $oid  = $root->{oid};
    my $name = $root->{name};

    my $a      = $root->{children};
    my $nNodes = @$a;

    my $level = $root->getLevel();
    print "<br/>\n" if $level == 1;
    print nbsp( ( $level - 1 ) * 4 );

    if ($oid) {
        print sprintf( "%02d", $level );
        print nbsp(1);
        print "<b>" if $level == 1;
        my $func_id    = $oid;
        my $class_name = "";
        if ( $type eq 'network' ) {
            $class_name = 'PATHWAY_NETWORK';
        } elsif ( $type eq 'pathway' ) {
            $class_name = 'IMG_PATHWAY';
        } elsif ( $type eq 'parts_list' ) {
            $class_name = 'IMG_PARTS_LIST';
        }
        $func_id = FuncUtil::getFuncId( $class_name, $oid );
        my $func_id_nopadding = FuncUtil::getFuncId( $class_name, $oid, 1 );
        
        print "<input id='$level' type='checkbox' name='func_id' "
        ." value='$func_id_nopadding' />\n"
          if $is_editor && $type eq "network" || $type ne "network";
        print nbsp(1);
        my $url = FuncUtil::getUrl( $main_cgi, $class_name, $oid );
        print alink( $url, $func_id );
        print nbsp(1);
        print escHtml($name);
        
        if($is_editor && $type eq "network" || $type ne "network" ) {
            # do nothing
        } else {
            # not a check box
        print qq{
            <input id='$level' name='$func_id' type='button' value='All' Class='tinybutton' 
            onClick='selectMetaCyc("$func_id", $level)' />
            <input type='button' value='None' Class='tinybutton' 
            onClick='clearMetaCyc("$func_id", $level)' />
        };            
        }
        
        print "</b>" if $level == 1;
    }
    elsif ($name) {
        print "(" . escHtml($name) . ")";
    }

    print "<br/>\n" if $level >= 1;

    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $root->{children}->[$i];
        printCompleteNetworkHtml( $n2, $is_editor );
    }
}

###########################################################################
# printNetworkFooter
###########################################################################
sub printNetworkFooter {
    my ($dbh) = @_;

    my $contact_oid = getContactOid();
    my $is_editor   = 0;
    $is_editor = isImgEditor( $dbh, $contact_oid )
      if $contact_oid > 0;

    my $id          = "_section_CuraCartStor_addFuncIdToCuraCart";
    my $idFc        = "_section_FuncCartStor_addToFuncCart";
    my $buttonLabel = "Add Selected to Function Cart";
    print submit(
        -name  => $idFc,
        -value => $buttonLabel,
        -class => "meddefbutton"
    );
    print nbsp(1);

    if ($is_editor) {
        my $buttonLabel = "Add Selected to Curation Cart";
        print submit(
            -name  => $id,
            -value => $buttonLabel,
            -class => "medbutton"
        );
        print nbsp(1);
    }

    # also see printJavaScript();
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes1(1)' class='smbutton' /> ";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes1(0)' class='smbutton' /> ";
    print "<br/>\n";
}

############################################################################
# printNetworkPathwayDetail
############################################################################
sub printPathwayNetworkDetail {
    print "<h1>IMG Network Detail</h1>\n";
    printMainForm();

    my $network_oid = param('network_oid');
    if ( blankStr($network_oid) ) {
        return;
    }

    my $class_name = 'PATHWAY_NETWORK';

    my $dbh = dbLogin();

    # print pathway network attribute
    my $sql = qq{
        select pn.network_oid, pn.network_name, 
	pn.eqn_grammer, pn.description, pn.comments, pn.image_id,
	to_char(pn.add_date, 'yyyy-mm-dd'), 
        to_char(pn.mod_date, 'yyyy-mm-dd'), c.name, c.email
        from pathway_network pn, contact c
	where pn.network_oid = ?
	and pn.modified_by = c.contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $network_oid );
    my (
        $network_oid, $network_name, $eqn,      $desc,
        $comm,        $image_id,     $add_date, $mod_date,
        $c_name,      $email
      )
      = $cur->fetchrow();
    $cur->finish();
    $network_oid = FuncUtil::oidPadded( $class_name, $network_oid );

    print "<table class='img' border='1'>\n";
    printAttrRow( "Network OID", $network_oid );
    printAttrRow( "Name",        $network_name );
    printAttrRow( "EQN Grammar", $eqn );
    printAttrRow( "Description", $desc );
    printAttrRow( "Comments",    $comm );
    printAttrRow( "Image ID",    $image_id );
    printAttrRow( "Add Date",    $add_date );
    printAttrRow( "Modify Date", $mod_date );
    my $s = escHtml($c_name) . emailLinkParen($email);
    printAttrRowRaw( "Modified By", $s );
    print "</table>\n";

    # print network tree
    my $mgr = new PwNwNodeMgr();
    $mgr->loadTree();
    my $root = $mgr->{root};

    print "<h2>IMG Network Subtree Structure</h2>\n";

    # find the subtree to print
    my $found = 0;
    my @nodes = ($root);
    while ( $found == 0 && scalar(@nodes) > 0 ) {
        my $node = pop @nodes;

        if ( $node->{type} ne 'pathway' && $node->{type} ne 'parts_list' ) {
            if ( $node->{oid} == $network_oid ) {
                $found = 1;
                print "<p>\n";
                printNodeDisplayHtml($node);
                last;
            } else {
                my $a = $node->{children};
                for my $c (@$a) {
                    if ( $c->{type} eq 'network' ) {
                        push @nodes, ($c);
                    }
                }
            }
        }
    }

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printNodeDisplayHtml - Print contents of the node out web display.
#                        (display only. no checkbox)
############################################################################
sub printNodeDisplayHtml {
    my ($node) = @_;

    my $type = $node->{type};
    my $oid  = $node->{oid};
    my $name = $node->{name};

    my $a      = $node->{children};
    my $nNodes = @$a;

    #return if $nNodes == 0 && $type eq "network";

    my $level = $node->getLevel();
    print "<br/>\n" if $level == 1;
    print nbsp( ( $level - 1 ) * 4 );

    if ( $type eq "network" ) {
        print sprintf( "%02d", $level );
        print nbsp(1);
        print "<b>" if $level == 1;
        print escHtml($name);
        print "</b>" if $level == 1;
    } elsif ( $type eq 'pathway' || $type eq 'parts_list' ) {
        my $class_name = 'IMG_PATHWAY';
        if ( $type eq 'parts_list' ) {
            $class_name = 'IMG_PARTS_LIST';
        }

        my $func_id = FuncUtil::getFuncId( $class_name, $oid );
        my $url = FuncUtil::getUrl( $main_cgi, $class_name, $oid );
        if ( $class_name eq 'IMG_PATHWAY' ) {
            print "<font color='blue'>\n";
        } else {
            print "<font color='purple'>\n";
        }
        print alink( $url, $func_id );
        print nbsp(1);
        print escHtml($name);
        print "</font>\n";
        print "</b>" if $level == 1;
    }
    print "<br/>\n" if $level >= 1;

    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $node->{children}->[$i];
        printNodeDisplayHtml($n2);
    }
}

1;

