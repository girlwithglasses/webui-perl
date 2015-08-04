#
# experimental
#
# $Id: TreeFileMgr.pm 29739 2014-01-07 19:11:08Z klchu $
package TreeFileMgr;
use strict;
use CGI qw( :standard );
use CGI::Cookie;
use DBI;
use WebUtil;
use WebConfig;
use TreeNode;
use TreeNode2;
use Data::Dumper;

my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $base_url            = $env->{base_url};
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $img_internal        = $env->{img_internal};
my $tmp_dir             = $env->{tmp_dir};
my $web_data_dir        = $env->{web_data_dir};
my $include_metagenomes = $env->{include_metagenomes};
my $rdbms               = getRdbms();
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $YUI                 = $env->{yui_dir_28};

my $dir2 = WebUtil::getSessionDir();
$dir2 .= "/TreeFileMgr";
if ( !(-e "$dir2") ) { 
    mkdir "$dir2" or webError("Can not make $dir2!"); 
}
$cgi_tmp_dir = $dir2;

#my $domain_tree         = $env->{domain_tree};
my $section     = "TreeFileMgr";
my $section_cgi = "$main_cgi?section=$section";

# new for 2.9
my $domain_all_file = "domain_all.html";

$| = 1;

# letters count mapped to level
# 1 => A => count
my %level2Letter = (
                     0 => 'r',
                     1 => 'a',
                     2 => 'b',
                     3 => 'c',
                     4 => 'd',
                     5 => 'e',
                     6 => 'f',
                     7 => 'g',
                     8 => 'h'
);

my %letter2Count = (
                     'r' => 0,
                     'a' => 0,
                     'b' => 0,
                     'c' => 0,
                     'd' => 0,
                     'e' => 0,
                     'f' => 0,
                     'g' => 0,
                     'h' => 0
);

# map level to phylum name
my %PHYLUM_NAME = (
                    1 => "Domain",
                    2 => "Phylum",
                    3 => "IR Class",
                    4 => "IR Order",
                    5 => "Family",
                    6 => "Genus",
                    7 => "Species",
                    8 => "Genome"
);

sub dispatch {
    my $page = param("page");
    if ( $page eq "update" ) {
        updateSelectedFile();
    } elsif ( $page eq "treediv" ) {
        my ( $root, $open, $domain, $openfile, $selectedfile, $domainfile ) =
          printTreeView();
        printTreeDiv( $root, $open, $domain, $openfile, $selectedfile,
                      $domainfile, "section=TreeFileMgr&page=treediv" );
    }
}

sub printTreeView {

    my $domain        = param("domain");          # for all trees
    my $open          = param("open");            # a node was open nodes
    my $close         = param("close");           # a node was close
    my $openfile      = param("openfile");        # file list of open nodes
    my $selectedfile  = param("selectedfile");    # file list of selected nodes
    my $selectid      = param("selectid");        # all button pressed
    my $selectlevel   = param("selectlevel");
    my $unselectid    = param("unselectid");      # none button pressed
    my $unselectlevel = param("unselectlevel");
    my $domainfile    = param("domainfile");      # domain file name
    my $seq_status    = param("seq_status");

    $domain = "all" if ( $domain eq "" );
    $domain = lc($domain) if ( $domain ne "*Microbiome" && $domain ne 'GFragment' );

    # replace this section with createFile
    my $file;
    if ( $domain eq "bacteria" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";
    } elsif ( $domain eq "archaea" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";
    } elsif ( $domain eq "eukaryota" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";
    } elsif ( $domain eq "plasmid" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";

    } elsif ( $domain eq "GFragment" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . $domain . " Tree</h1>\n";

    } elsif ( $domain eq "viruses" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";

    } elsif ( $domain eq "*Microbiome" ) {

        $file = createFile( $domainfile, $domain, $seq_status );
        print "<h1>Genome Browser " . ucfirst($domain) . " Tree</h1>\n";
    } else {
        my $hideViruses = getSessionParam("hideViruses");
        $hideViruses = "Yes" if $hideViruses eq "";

        my $hidePlasmids = getSessionParam("hidePlasmids");
        $hidePlasmids = "Yes" if $hidePlasmids eq "";

        my $hideGFragment = getSessionParam("hideGFragment");
        $hideGFragment = "Yes" if $hideGFragment eq "";

        if ( $hideViruses eq "Yes" && $hidePlasmids eq "Yes" && $hideGFragment eq "Yes" ) {

            $file = createFile( $domainfile, "novpg", $seq_status );
        } elsif ( $hideViruses eq "Yes" && $hideGFragment eq "Yes" ) {
            
            $file = createFile( $domainfile, "novg", $seq_status );
        } elsif ( $hideViruses eq "Yes" && $hidePlasmids eq "Yes" ) {

            $file = createFile( $domainfile, "novp", $seq_status );
        
        } elsif ( $hidePlasmids eq "Yes" && $hideGFragment eq "Yes" ) {
            
            $file = createFile( $domainfile, "nopg", $seq_status );
        } elsif ( $hideViruses eq "Yes" ) {

            #$file = $domain_all_file_novir;
            $file = createFile( $domainfile, "novir", $seq_status );
        } elsif ( $hidePlasmids eq "Yes" ) {

            #$file = $domain_all_file_nopla;
            $file = createFile( $domainfile, "nopla", $seq_status );

        } elsif ( $hideGFragment eq "Yes" ) {

            #$file = $domain_all_file_nopla;
            $file = createFile( $domainfile, "nogfrag", $seq_status );

        } else {

            # all
            $file = createFile( $domainfile, "all", $seq_status );
        }
    }

    # update the access time of domain file
    WebUtil::fileTouch("$cgi_tmp_dir/$file");
    $domainfile = $file;

    # pre select from saved genomes
    my $saved_genomes_href = ();
    if ( $selectedfile eq "" ) {
        $saved_genomes_href = getTaxonFilterHash();
    }
    my @saved_genomes_ids = ();

    # gets session list of open ids and selected ids
    my $openids_href     = readSession($openfile);
    my $selectedids_href = readSession($selectedfile);

    # all list either open or close all nodes
    my @allids;

    my $root = createTreeFromFile(
                                   $file,             \@allids,
                                   $selectedfile,     $open,
                                   $close,            $openids_href,
                                   $selectedids_href, $saved_genomes_href,
                                   \@saved_genomes_ids
    );

    #    print "<p> hello \n";
    #    print Dumper $root;
    #    print "</p>\n";

    # set selected nodes when all button pressed
    if ( $selectid ne "" ) {
        my $node = findNode( $root, $selectid );
        $node->setOpen(1);
        my @list;    # list of selected nodes ids
        my @listopen = ($selectid);
        setChildrenSelect( $node, 1, \@list, \@listopen );
        $selectedfile = writeSession( $selectedfile, \@list );
        $openfile     = writeSession( $openfile,     \@listopen );
    } elsif ( $unselectid ne "" ) {

        # none button pressed
        my $node = findNode( $root, $unselectid );
        $node->setOpen(1);
        my @list;    # list of selected nodes ids
        my @listopen = ($unselectid);
        setChildrenSelect( $node, 0, \@list, \@listopen );
        $selectedfile = writeSessionRemove( $selectedfile, \@list );
        $openfile     = writeSession( $openfile,           \@listopen );
    } elsif ( $selectedfile eq "" ) {

        # init $selectedfile for js
        my @list = ();

        # genome cart
        @list = @saved_genomes_ids;
        $selectedfile = writeSession( $selectedfile, \@list );
    }

    # save close nodes
    # now close the node and its children node
    if ( $close eq "all" || $close =~ /^[2-6]/ ) {
        $openfile = writeSessionRemove( $openfile, \@allids );
    } elsif ( $close ne "" ) {
        my $closenode = findNode( $root, $close );
        $closenode->setOpen(0);
        my @list = ($close);
        closeChildren( $closenode, \@list );
        $openfile = writeSessionRemove( $openfile, \@list );
    }

    # save open node id
    if ( $open eq "all" || $open =~ /^[1-5]/ ) {
        $openfile = writeSession( $openfile, \@allids );
    } elsif ( $open ne "" ) {
        my @a = ($open);
        $openfile = writeSession( $openfile, \@a );
    }

    # if child open then make sure parent is open
    # can I do it here instead - for open all

    my $url = "$section_cgi&page=domain&domain=$domain";
    $url .= "&seq_status=$seq_status" if ( $seq_status ne "" );
    $url .= "&domainfile=$domainfile" if ( $domainfile ne "" );

    if ( $openfile ne "" ) {
        WebUtil::fileTouch("$cgi_tmp_dir/$openfile");
        $url .= "&openfile=$openfile";
    }

    if ( $selectedfile ne "" ) {
        WebUtil::fileTouch("$cgi_tmp_dir/$selectedfile");
        $url .= "&selectedfile=$selectedfile";
    }

    return ( $root, $open, $domain, $openfile, $selectedfile, $domainfile );
}

#
# print tree html
#
sub printTree {
    my ( $node, $open, $domain, $openfile, $selectedfile, $domainfile,
         $section_page )
      = @_;

    my $id            = $node->getId();
    my $text          = $node->getText();
    my $level         = $node->getLevel();
    my $children_aref = $node->getChildren();
    my $parent        = $node->getParent();
    my $isOpen        = $node->isOpen();
    my $parentIsOpen  = $parent->isOpen() if ( $id ne "root" );
    my $taxon_oid     = $node->getTaxonOid();
    my $end_text      = $node->getEndText();

    my $open_url = "$base_url/images/open.png";
    $open_url = "<img class='arrowimg' src='$open_url' width='10' height='10'>";
    my $close_url = "$base_url/images/close.png";
    $close_url =
      "<img class='arrowimg' src='$close_url' width='10' height='10'>";

    my $url = "main.cgi?" . "$section_page";    # section and page
    $url .= "&domain=$domain"             if ( $domain       ne "" );
    $url .= "&domainfile=$domainfile"     if ( $domainfile   ne "" );
    $url .= "&openfile=$openfile"         if ( $openfile     ne "" );
    $url .= "&selectedfile=$selectedfile" if ( $selectedfile ne "" );

    # image select = green dot
    # clear red dot
    # green-dot.png red-dot.png
    # checked-box.gif
    # unchecked-box.gif
    my $checkedbox   = "green-dot.png";
    my $uncheckedbox = "red-dot.png";
    if ( param("icon") ne "" ) {
        $checkedbox   = "checked-box.gif";
        $uncheckedbox = "unchecked-box.gif";
    }
    my $image_button = qq{ 
      <a style='text-decoration:none' id='$id' name='$level' title='Select'
      href=\"javascript:window.open('$url&selectid=$id&selectlevel=$level#$id', '_self', '' ,true)\" >
      <img class='arrowimg' src='$base_url/images/$checkedbox' width='10' height='10'>
      </a>    
       
      <a style='text-decoration:none' id='$id' name='$level' title='Clear'
    };

    my $image_button_end = qq{
      >
      <img class='arrowimg' src='$base_url/images/$uncheckedbox' width='10' height='10'>
      </a>
      &nbsp;       
    };

    # cached pages with # in url
    my $unselectid = param("unselectid");    # none button pressed
    if ( $id eq $unselectid ) {

        $image_button =
            $image_button
          . "href=\"javascript:myopen('$url&unselectid=$id&unselectlevel=$level', '$id')\" "
          . $image_button_end;

    } else {

        $image_button =
            $image_button
          . "href=\"javascript:window.open('$url&unselectid=$id&unselectlevel=$level#$id', '_self', '' ,false)\" "
          . $image_button_end;

    }

    # js call when i select check box
    # some how update session records for
    # both select and unselect
    my $url2 =
        "xml.cgi?section=TreeFileMgr&page=update"
      . "&selectedfile=$selectedfile"
      . "&id=$id";

    my $checkbox =
        "<input id='$id' "
      . "type='checkbox' "
      . "name='taxon_filter_oid' value='$taxon_oid' "
      . "onclick=\"onChecked('$id', '$url2')\"  ";

    # change to node param
    if ( $node->getSelected() ) {
        $checkbox .= " checked='true' />";
    } else {
        $checkbox .= " /> ";
    }

    if ( $id ne "root" ) {
        if ($isOpen) {
            $url .= "&close=$id" . "#$id";
            print "<a name='$id'></a>" . nbsp( $level * 2 );
            if ( $level == 8 ) {
                print lpad($level);
                my $url2 = "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
                $url2 = alink( $url2, $text );
                print " &nbsp; $checkbox &nbsp; $url2 ";
                print " &nbsp; $end_text ";
            } else {
                print
"<a style='text-decoration:none' href='$url' title='$PHYLUM_NAME{$level}' >"
                  . lpad($level)
                  . $open_url . "</a>";

                if ( $level == 1 ) {

                    # bold text for level 1
                    #print $image_button . "<b>$text</b> $button";
                    print $image_button . "<b>$text</b>";
                } else {

                    #print $image_button . $text . $button;
                    print $image_button . $text;
                }
            }
            print "<br/>\n";
        } elsif ($parentIsOpen) {
            $url .= "&open=$id" . "#$id";
            print "<a name='$id'></a>" . nbsp( $level * 2 );
            if ( $level == 8 ) {
                print lpad($level);
                my $url2 = "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
                $url2 = alink( $url2, $text );
                print " &nbsp; $checkbox &nbsp; $url2 ";
                print " &nbsp; $end_text ";
            } else {
                print
"<a style='text-decoration:none' href='$url' title='$PHYLUM_NAME{$level}'>"
                  . lpad($level)
                  . $close_url . "</a>";

                if ( $level == 1 ) {

                    # bold text for level 1
                    #print $image_button . "<b>$text</b> $button";
                    print $image_button . "<b>$text</b> ";
                } else {

                    #print $image_button . $text . $button;
                    print $image_button . $text;
                }
            }
            print "<br/>\n";
        }
    }

    my $children_aref = $node->getChildren();
    foreach my $childNode (@$children_aref) {
        printTree( $childNode, $open, $domain, $openfile, $selectedfile,
                   $domainfile, $section_page );
    }
}

#
# JS div update
#
sub printTreeDiv {
    my ( $node, $open, $domain, $openfile, $selectedfile, $domainfile,
         $section_page )
      = @_;

    my $id            = $node->getId();
    my $text          = $node->getText();
    my $level         = $node->getLevel();
    my $children_aref = $node->getChildren();
    my $parent        = $node->getParent();
    my $isOpen        = $node->isOpen();
    my $parentIsOpen  = $parent->isOpen() if ( $id ne "root" );
    my $taxon_oid     = $node->getTaxonOid();
    my $end_text      = $node->getEndText();

    my $open_url = "$base_url/images/open.png";
    $open_url = "<img class='arrowimg' src='$open_url' width='10' height='10'>";
    my $close_url = "$base_url/images/close.png";
    $close_url =
      "<img class='arrowimg' src='$close_url' width='10' height='10'>";

    my $url = "xml.cgi?" . "$section_page";    # section and page
    $url .= "&domain=$domain"             if ( $domain       ne "" );
    $url .= "&domainfile=$domainfile"     if ( $domainfile   ne "" );
    $url .= "&openfile=$openfile"         if ( $openfile     ne "" );
    $url .= "&selectedfile=$selectedfile" if ( $selectedfile ne "" );

    # image select = green dot
    # clear red dot
    # green-dot.png red-dot.png
    # checked-box.gif
    # unchecked-box.gif
    my $checkedbox   = "green-dot.png";
    my $uncheckedbox = "red-dot.png";
    if ( param("icon") ne "" ) {
        $checkedbox   = "checked-box.gif";
        $uncheckedbox = "unchecked-box.gif";
    }
    my $image_button = qq{ 
      <a style='text-decoration:none' id='$id' name='$level' title='Select'
      href=\"javascript:updateTreeDiv('$url&selectid=$id&selectlevel=$level#$id')\" >
      <img class='arrowimg' src='$base_url/images/$checkedbox' width='10' height='10'>
      </a>    
       
      <a style='text-decoration:none' id='$id' name='$level' title='Clear'
    };

    my $image_button_end = qq{
      >
      <img class='arrowimg' src='$base_url/images/$uncheckedbox' width='10' height='10'>
      </a>
      &nbsp;       
    };

    # cached pages with # in url
    my $unselectid = param("unselectid");    # none button pressed
    if ( $id eq $unselectid ) {

        $image_button =
            $image_button
          . "href=\"javascript:myopen4('$url&unselectid=$id&unselectlevel=$level', '$id')\" "
          . $image_button_end;

    } else {

        $image_button =
            $image_button
          . "href=\"javascript:updateTreeDiv('$url&unselectid=$id&unselectlevel=$level#$id')\" "
          . $image_button_end;

    }

    # js call when i select check box
    # some how update session records for
    # both select and unselect
    my $url2 =
        "xml.cgi?section=TreeFileMgr&page=update"
      . "&selectedfile=$selectedfile"
      . "&id=$id";

    my $checkbox =
        "<input id='$id' "
      . "type='checkbox' "
      . "name='taxon_filter_oid' value='$taxon_oid' "
      . "onclick=\"onChecked('$id', '$url2')\"  ";

    # change to node param
    if ( $node->getSelected() ) {
        $checkbox .= " checked='true' />";
    } else {
        $checkbox .= " /> ";
    }

    if ( $id ne "root" ) {
        if ($isOpen) {
            $url .= "&close=$id" . "#$id";
            print "<a name='$id'></a>" . nbsp( $level * 2 );
            if ( $level == 8 ) {
                print lpad($level);
                my $url2 = "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
                $url2 = alink( $url2, $text );
                print " &nbsp; $checkbox &nbsp; $url2 ";
                print " &nbsp; $end_text ";
            } else {
                print
"<a style='text-decoration:none' href='javascript:updateTreeDiv(\"$url\")' title='$PHYLUM_NAME{$level}' >"
                  . lpad($level)
                  . $open_url . "</a>";

                if ( $level == 1 ) {

                    # bold text for level 1
                    #print $image_button . "<b>$text</b> $button";
                    print $image_button . "<b>$text</b>";
                } else {

                    #print $image_button . $text . $button;
                    print $image_button . $text;
                }
            }
            print "<br/>\n";
        } elsif ($parentIsOpen) {
            $url .= "&open=$id" . "#$id";
            print "<a name='$id'></a>" . nbsp( $level * 2 );
            if ( $level == 8 ) {
                print lpad($level);
                my $url2 = "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
                $url2 = alink( $url2, $text );
                print " &nbsp; $checkbox &nbsp; $url2 ";
                print " &nbsp; $end_text ";
            } else {
                print
"<a style='text-decoration:none' href='javascript:updateTreeDiv(\"$url\")' title='$PHYLUM_NAME{$level}'>"
                  . lpad($level)
                  . $close_url . "</a>";

                if ( $level == 1 ) {

                    # bold text for level 1
                    #print $image_button . "<b>$text</b> $button";
                    print $image_button . "<b>$text</b> ";
                } else {

                    #print $image_button . $text . $button;
                    print $image_button . $text;
                }
            }
            print "<br/>\n";
        }
    }

    my $children_aref = $node->getChildren();
    foreach my $childNode (@$children_aref) {
        printTreeDiv( $childNode, $open, $domain, $openfile, $selectedfile,
                      $domainfile, $section_page );
    }
}

sub printJS {
    print qq{
        <script type="text/javascript" src="$base_url/treeFile.js" ></script>
<script type="text/javascript" src="$YUI/build/yahoo/yahoo-min.js"></script>
<script type="text/javascript" src="$YUI/build/event/event-min.js"></script>
<script type="text/javascript" src="$YUI/build/connection/connection-min.js"></script>
    };

}

# ==========================================================================
#
#  private functions
#
#
# ==========================================================================

#
# create the tree in memory by reading the domain file
# return TreeNode root
#
# $file - domain info file
# @allids - init empty array for listing either open or close all nodes
# $selectedfile  - file list of selected nodes
# $open - node id to open - user clicked
# $close - node id to close - user clicked
# $openids_href - hash of open node ids
# $selectedids_href - hash of selected node ids
# $saved_genomes_href - pre selected genome ids from saved genomes
# @saved_genomes_ids - init. empty array of saved genome node ids
sub createTreeFromFile {
    my (
         $file,             $allids_aref,
         $selectedfile,     $open,
         $close,            $openids_href,
         $selectedids_href, $saved_genomes_href,
         $saved_genomes_ids_aref
      )
      = @_;

    # $id, $level, $text, $pnode
    my $root       = new TreeNode( "root", 0, "root", "", 1 );
    my $parentNode = $root;
    my $fh         = newReadFileHandle("$cgi_tmp_dir/$file");

    # all list either open or close all nodes
    #my @allids;

    while ( my $line = $fh->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        my ( $id, $level, $text, $taxon_oid, $end_text ) = split( /\t/, $line );

        my $node;
        if ( ( $level - 1 ) == $parentNode->getLevel() ) {

            # child of current node
            $node = new TreeNode( $id, $level, $text, $parentNode );
            $parentNode->addChild($node);
            $parentNode = $node;

        } elsif ( ( $level - 2 ) == $parentNode->getLevel() ) {

            # same genus print another genome name
            $node = new TreeNode( $id, $level, $text, $parentNode );
            $parentNode->addChild($node);
        } elsif ( ( $level - 2 ) > $parentNode->getLevel() ) {

            # this node is grand child of current node
            my $aref = $parentNode->getChildren();
            $parentNode = $aref->[$#$aref];
            $node = new TreeNode( $id, $level, $text, $parentNode );
            $parentNode->addChild($node);

        } elsif ( $level == $parentNode->getLevel() ) {

            # this node is another parent node
            $parentNode = $parentNode->getParent();
            $node = new TreeNode( $id, $level, $text, $parentNode );
            $parentNode->addChild($node);
        } else {

            # this node is grand parent of current node
            for ( ; ; ) {
                my $plevel = $parentNode->getLevel();
                last if ( $plevel < $level );
                $parentNode = $parentNode->getParent();
            }
            $node = new TreeNode( $id, $level, $text, $parentNode );
            $parentNode->addChild($node);
            $parentNode = $node;
        }
        $node->setOpen(1) if ( $open =~ $id || exists $openids_href->{$id} );
        $node->setTaxonOid($taxon_oid);
        $node->setEndText($end_text);
        $node->setSelected(1) if ( exists $selectedids_href->{$id} );

        # genome cart selection only on initial tree drawing
        if ( $selectedfile eq "" && exists $saved_genomes_href->{$taxon_oid} ) {
            $node->setSelected(1);

            #webLog("$id === $taxon_oid \n");
            push( @$saved_genomes_ids_aref, $id );
        }

        if ( $open eq "all" || ( $open =~ /^[1-5]/ && $level <= $open ) ) {
            $node->setOpen(1);
            $close = "";
            push( @$allids_aref, $id );
        } elsif ( $close eq "all"
                  || ( $close =~ /^[2-6]/ && $level >= $close ) )
        {
            $open = "";
            $node->setOpen(0);
            push( @$allids_aref, $id );
        }
    }
    close $fh;
    return $root;
}

#
# ajax call to update the session selected list file
#
sub updateSelectedFile {
    my $id           = param("id");
    my $selectedfile = param("selectedfile");
    my $remove       = param("remove");
    my @list         = ($id);

    if ( $remove eq "true" ) {
        $selectedfile = writeSessionRemove( $selectedfile, \@list );
        print "unchecked";
    } else {
        $selectedfile = writeSession( $selectedfile, \@list );
        print "checked";
    }
}

#
# file format:
# open list  of  ids \n
# or
# selected list od ids \n
#
sub readSession {
    my ($file) = @_;
    $file = WebUtil::checkFileName($file);
    my %hash = ();

    my $path = "$cgi_tmp_dir/$file";
    if ( !-e $path ) {

        #webLog("Tree state file does not exists or session time out\n");
        return \%hash;
    }

    my $res = newReadFileHandle( $path, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        $hash{$line} = "";
    }

    close $res;
    return \%hash;
}

# write session file on what the user has done so far
sub writeSession {
    my ( $file, $ids_aref ) = @_;

    if ( $file eq "" ) {
        my $sid = getSessionId();
        $file = "treestate$$" . "_" . $sid;
    } elsif ( $file ne "" ) {
        $file = WebUtil::checkFileName($file);
        if ( !-e "$cgi_tmp_dir/$file" ) {
            webError("Your session timed out, please restart!");
        }
    }

    $file = WebUtil::checkFileName($file);

    my $prev_data_href = readSession($file);
    my $path           = "$cgi_tmp_dir/$file";
    my $res            = newWriteFileHandle( $path, "runJob" );

    # save new ids
    foreach my $id (@$ids_aref) {
        if ( exists $prev_data_href->{$id} ) {

            # skip
            next;
        } else {
            print $res "$id\n";
        }
    }

    foreach my $id ( keys %$prev_data_href ) {
        print $res "$id\n";
    }

    close $res;
    return $file;
}

# write session files but remove ids
sub writeSessionRemove {
    my ( $file, $ids_aref ) = @_;

    if ( $file eq "" ) {
        my $sid = getSessionId();
        $file = "treestate$$" . "_" . $sid;
    } elsif ( $file ne "" ) {
        $file = WebUtil::checkFileName($file);
        if ( !-e "$cgi_tmp_dir/$file" ) {

            #my $url = "$section_cgi";
            #$url = alink( $url, "Restart" );
            #            print qq{
            #              <p>
            #
            #              </p>
            #            };
            webError("Your session timed out, please restart!");
        }
    }

    $file = WebUtil::checkFileName($file);

    my $prev_data_href = readSession($file);
    my $path           = "$cgi_tmp_dir/$file";
    my $res            = newWriteFileHandle( $path, "runJob" );

    # save new ids
    foreach my $id (@$ids_aref) {
        if ( exists $prev_data_href->{$id} ) {

            #webLog("=== delete ids $id \n");
            delete $prev_data_href->{$id};
        }
    }

    foreach my $id ( keys %$prev_data_href ) {
        print $res "$id\n";
    }

    close $res;
    return $file;
}

#
# return node with the  given id
# otherwise return ""
# $node -start   node
# $id - id to find
sub findNode {
    my ( $node, $id ) = @_;

    if ( $node->getId() eq $id ) {
        return $node;
    } else {
        my $children_aref = $node->getChildren();
        foreach my $childnode (@$children_aref) {

            #webLog("looking at node " . $node->getId()  . "\n");
            my $suc = findNode( $childnode, $id );
            if ( $suc ne "" ) {
                return $suc;
            }
        }
    }

    return "";
}

#
# given a parent node close all its children
# $parentnode - parent node
# $list_aref - list of closed ids
#
sub closeChildren {
    my ( $parentnode, $list_aref ) = @_;

    my $children_aref = $parentnode->getChildren();
    foreach my $childnode (@$children_aref) {
        $childnode->setOpen(0);
        my $id = $childnode->getId();
        push( @$list_aref, $id );
        closeChildren( $childnode, $list_aref );
    }
}

#
# select ids to select - from all or none button
#
# $node - node
# $value - selected value
# $list_aref - list of selected  node
# $listopen_aref - list id to be open
#
sub setChildrenSelect {
    my ( $node, $value, $list_aref, $listopen_aref ) = @_;
    my $children_aref = $node->getChildren();
    foreach my $childnode (@$children_aref) {
        $childnode->setOpen(1);    # open all the node for all and node button
        if ( $childnode->getLevel() == 8 ) {
            $childnode->setSelected($value);
            push( @$list_aref, $childnode->getId() );
        }
        push( @$listopen_aref, $childnode->getId() );
        setChildrenSelect( $childnode, $value, $list_aref, $listopen_aref );
    }
}

#
# id padding
#
sub lpad {
    my ($id) = @_;
    return sprintf( "%02d", $id );
}

# create the domain file
# return file name
sub createFile {
    my ( $file, $domain, $seq_status ) = @_;

    if ( $file eq "" ) {
        my $sid = getSessionId();
        my $tmp = $domain;
        $tmp =~ s/\*//;
        $file = "tree" . "$tmp" . "$$" . "_" . $sid;
    } elsif ( $file ne "" ) {
        $file = WebUtil::checkFileName($file);
        if ( -e "$cgi_tmp_dir/$file" ) {

            # file still exists
            #webLog("domain file already exists $file\n");
            return $file;
        } else {

            # session file was deleted so create a new one
            my $sid = getSessionId();
            my $tmp = $domain;
            $tmp =~ s/\*//;
            $file = "tree" . "$tmp" . "$$" . "_" . $sid;
        }
    }

    #webLog("creating domain file $file\n");

    $file = WebUtil::checkFileName($file);
    my $path = "$cgi_tmp_dir/$file";
    my $fh   = newWriteFileHandle($path);

    # taxon oid => text to display after the taxon name
    my %taxon_hash   = ();
    my $results_aref = getDomainFile( $domain, \%taxon_hash, $seq_status );

    my $root = new TreeNode2( "", "root", 0 );

    foreach my $line (@$results_aref) {
        my (
             $taxon_oid, $taxon_display_name, $domain,
             $phylum,    $ir_class,           $ir_order,
             $family,    $genus,              $species
          )
          = split( /\t/, $line );

        my @phyla = ( $domain, $phylum, $ir_class, $ir_order, $family, $genus );

        my $curr_domain = substr( lc($domain), 0, 3 );

        # build tree into meemory
        buildTreeFile( $root, \@phyla, $taxon_oid, $taxon_display_name, 0,
                       $curr_domain );
    }

    # write tree to session file
    printTreeFile( $fh, $root, \%taxon_hash, 0 );

    close $fh;

    return $file;
}

# get leaf counts
sub getLeafCount {
    my ($node)        = @_;
    my $name          = $node->getName();
    my $nlevel        = $node->getLevel();
    my $children_aref = $node->getChildren();
    my $domain        = $node->getDomain();
    if ( $nlevel == 7 ) {

        #webLog("1 ===== $name \n");
        return 1;
    } else {
        my $count = 0;
        foreach my $childNode (@$children_aref) {
            $count = $count + getLeafCount($childNode);

            #webLog("$count \n");
        }
        return $count;
    }

}

#
# write tree to a session file
#
sub printTreeFile {
    my ( $fh, $node, $taxon_href, $level ) = @_;

    my $name          = $node->getName();
    my $nlevel        = $node->getLevel();
    my $children_aref = $node->getChildren();
    my $domain        = $node->getDomain();

    if ( $name ne "root" && $nlevel != 7 ) {
        my $cnt = getLeafCount($node);
        $name = $name . " ($cnt)";
    }

    my $letter = $level2Letter{$level};
    my $count  = $letter2Count{$letter} + 1;
    my $prefix = $letter . $count . "-";
    $letter2Count{$letter} = $count;

    if ( $name eq "root" ) {

        # skip
    } elsif ( $nlevel < 3 ) {

        print $fh "$prefix\t$nlevel\t$name\n";
    } elsif ( $nlevel == 7 ) {

        # genome node
        my $id   = $node->getOid();
        my $text = $taxon_href->{$id};
        $nlevel = $nlevel + 1;

        print $fh "$prefix\t$nlevel\t$name\t$id\t$text\n";
    } else {
        print $fh "$prefix\t$nlevel\t$name\n";
    }

    my $children_aref = $node->getChildren();
    foreach my $childNode (@$children_aref) {
        printTreeFile( $fh, $childNode, $taxon_href, $level + 1 );
    }
}

# read db to get domain tree info
sub getDomainFile {
    my ( $domain, $taxon_href, $seq_status ) = @_;
    my $dbh = dbLogin();

    my $clause = "";
    if ( lc($domain) eq "bacteria" ) {
        $clause = "where domain = 'Bacteria' ";
    } elsif ( lc($domain) eq "archaea" ) {
        $clause = "where domain = 'Archaea' ";
    } elsif ( lc($domain) eq "eukaryota" ) {
        $clause = "where domain = 'Eukaryota' ";

    } elsif ( lc($domain) eq "*microbiome" ) {

        # *Microbiome
        $clause = "where domain = '*Microbiome' ";

    } elsif ( lc($domain) eq "plasmid" ) {
        $clause = "where domain like 'Plasmid%' ";
    } elsif ( $domain eq "GFragment" ) {
        $clause = "where domain like 'GFragment%' ";
    } elsif ( lc($domain) eq "viruses" ) {
        $clause = "where domain like 'Vir%' ";
    } elsif ( $domain eq "novir" ) {
        $clause = "where domain not like 'Vir%' ";
    } elsif ( $domain eq "nopla" ) {
        $clause = "where domain not like 'Plasmid%' ";
        
    } elsif ( $domain eq "nogfrag" ) {
        $clause = "where domain not like 'GFragment%' ";
    } elsif ( $domain eq "novp" ) {
        $clause =
          "where domain not like 'Plasmid%' and domain not like 'Vir%' ";
    } elsif ( $domain eq "novg" ) {
        $clause =
          "where domain not like 'GFragment%' and domain not like 'Vir%' ";
    } elsif ( $domain eq "nopg" ) {
        $clause =
          "where domain not like 'GFragment%' and domain not like 'Plasmid%' ";
    } elsif ( $domain eq "novpg" ) {
        $clause =
          "where domain not like 'Plasmid%' and domain not like 'Vir%' and domain not like 'GFragment%' ";
    }

    my $seq_clause = "";
    if ( $seq_status ne "" ) {
        $seq_clause = " and seq_status = '$seq_status' ";
    }

    my $rclause = urClause();

    # for saved genomes
    my $txclause = txsClause("", $dbh);

    my $imgclause = WebUtil::imgClause('t');

    my $sql = qq{
select taxon_oid, taxon_display_name,
  domain, phylum,  ir_class,  ir_order,
  family, genus, species, seq_status ,seq_center
from taxon t
$clause
$rclause
$txclause
$seq_clause
$imgclause
order by domain, phylum, ir_class, ir_order, family,
  genus, species, is_pangenome desc, taxon_display_name    
    };

    my @results;
    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my (
             $taxon_oid, $taxon_display_name, $domain, $phylum,
             $ir_class,  $ir_order,           $family, $genus,
             $species,   $status,             $center
          )
          = $cur->fetchrow();
        last if !$taxon_oid;
        if ( $domain =~ /^Plasmid/ ) {
            $domain = "Plasmid";
        } elsif ( $domain =~ /^GFragment/ ) {
            $domain = "GFragment";
        } elsif ( $domain =~ /^Vir/ ) {
            $domain = "Viruses";
        }
        push( @results,
                  "$taxon_oid\t$taxon_display_name\t$domain\t$phylum\t"
                . "$ir_class\t$ir_order\t$family\t$genus\t$species" );

        if ( $status =~ /^F/ ) {
            $status = "[F]";
        } elsif ( $status =~ /^P/ ) {

            # Permanent Draft
            $status = "[P]";
        } else {
            $status = "[D]";
        }

        if ( $center eq "JGI" ) {
            $center = "<font color='red'> (JGI) </font>";
        } else {
            $center = "";
        }
        $taxon_href->{$taxon_oid} = "$status $center";

    }
    $cur->finish();

    #$dbh->disconnect();
    return \@results;
}

#
# build tree
#
# node - initially root node
# phyla - tab delimitied string of phyla names
#
#
# level - initially 0 of root node - depth of tree
# domain - domain name for the bac, euk, arc, vir, pla
sub buildTreeFile {
    my ( $node, $phyla_aref, $taxon_oid, $taxon_display_name, $level, $domain )
      = @_;

    # level of node - 0 for root node
    my $nlevel = $node->getLevel();

    # does current node have any children
    if ( $node->hasChildren() ) {

        # node has children, let check there phyla names
        # and compare it to the one in phyla_aref
        # note: the name and the level must be equal
        #       level is used because
        #       1 - unclassified and
        #       2 - sometimes phylum and ir_class are the same
        my $children_aref = $node->getChildren();
        foreach my $childNode (@$children_aref) {
            if (    $childNode->getName() eq $phyla_aref->[0]
                 && $childNode->getLevel() == ( $level + 1 ) )
            {

                # name is equal - so check the next level down the tree
                my $a = shift(@$phyla_aref);
                buildTreeFile( $childNode, $phyla_aref, $taxon_oid,
                               $taxon_display_name, $level + 1, $domain );

                # we do not need to continue the search of children
                # in this loop
                return;
            }
        }

        # the node had children but it does match the phyla name
        # so it must be a new node
    }

    # create new node
    if ( $#$phyla_aref > -1 ) {

        # we still have data in the phyla list

        # new node
        my $name = shift(@$phyla_aref);
        my $childNode = new TreeNode2( "", $name, $level + 1, $domain );
        $node->addChild($childNode);

        if ( $#$phyla_aref < 0 ) {

            # species node
            # taxon node
            my $taxonNode =
              new TreeNode2( $taxon_oid, $taxon_display_name, $level + 2,,
                             $domain );
            $childNode->addChild($taxonNode);
        } else {

            # keep building new nodes
            buildTreeFile( $childNode, $phyla_aref, $taxon_oid,
                           $taxon_display_name, $level + 1, $domain );
        }
    } else {

        # new node and node in tree have the
        # same species
        my $taxonNode =
          new TreeNode2( $taxon_oid, $taxon_display_name, $level + 1,,
                         $domain );
        $node->addChild($taxonNode);
    }
}

1;

