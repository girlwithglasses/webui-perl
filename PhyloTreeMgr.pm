#############################################################################
# Phylo Tree manager.   Wrapper for root node to PhyloNode.pm to
#   implement functions such as loading the tree and printing it out.
#      --es 02/02/2005
#
# $Id: PhyloTreeMgr.pm 33904 2015-08-05 17:46:52Z aireland $
#############################################################################
package PhyloTreeMgr;
my $section = "PhyloTreeMgr";
# Phylo Tree manager.
use strict;
use CGI qw( :standard );
use Data::Dumper;
use PhyloNode;
use DBI;
use WebConfig;
use WebUtil;

my $env = getEnv();
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi = $env->{ inner_cgi };
my $base_url = $env->{ base_url };
my $verbose = $env->{ verbose };
my $img_taxon_edit = $env->{img_taxon_edit};

############################################################################
# new - New object instance of the manager.
############################################################################
sub new {
   my( $myType ) = @_;
   my $self = { };
   bless( $self, $myType );

   my %taxonOid2Node;
   $self->{ taxonOid2Node } = \%taxonOid2Node;
   my $root = new PhyloNode();
   $self->{ root } = $root;

   return $self;
}

############################################################################
# loadPhyloTree - Load the tree from the database.
############################################################################
sub loadPhyloTree {
   my( $self, $taxonSelectRestrict, $taxons_href, $dbh_ken ) = @_;
   my $root = $self->{ root };
   $root->{ node_oid } = "root";
   my $taxonOid2Node = $self->{ taxonOid2Node };

   my $dbh;
   if ($dbh_ken ne "") {
       webLog("edit tree version \n");
       $dbh = $dbh_ken;
   } else {
       $dbh = WebUtil::dbLogin();
   }

   ## Load taxon_oid => taxon_display_names map.
   my %taxonNames;
   my %taxonDomains;
   my %taxonObsolete;
   my %seqCenter;
   my %seqStatus;
   my $hideViruses = getSessionParam( "hideViruses" );
   my $hidePlasmids = getSessionParam( "hidePlasmids" );
   my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");
   my $hideGFragment = getSessionParam("hideGFragment");
   if ($dbh_ken ne "") {
       my $domain = param("domain");
       if ($domain eq "Plasmids") {
           $hidePlasmids = "No";
       } elsif ($domain eq "Viruses") {
           $hideViruses = "No";
       } elsif ($domain eq "GFragment") {
           $hideGFragment = "No";
       }
       $hideObsoleteTaxon = "Yes" if $hideObsoleteTaxon eq "";
   }

   my $rclause   = WebUtil::urClause("t");
   my $imgClause = WebUtil::imgClause("t");
   my $sql = qq{
       select t.taxon_oid, t.taxon_display_name,
	      t.domain, t.seq_status, t.seq_center
       from taxon t
       where 1=1
       $rclause
       $imgClause
   };

   if ($dbh_ken ne "") {
       $sql = qq{
       select t.taxon_oid, t.taxon_display_name,
 	      t.domain, t.seq_status, t.seq_center, t.obsolete_flag
       from taxon t
       where 1=1
       $rclause
       $imgClause
       };
   }

   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   for( ;; ) {
      my( $taxon_oid, $taxon_display_name, $domain,
          $seq_status, $seq_center, $obsolete_flag ) = $cur->fetchrow();
      last if !$taxon_oid;
      $taxonNames{ $taxon_oid } = $taxon_display_name;
      $taxonDomains{ $taxon_oid } = substr( $domain, 0, 1 );
      $seqCenter{ $taxon_oid } = $seq_center;
      $seqStatus{ $taxon_oid } = substr( $seq_status, 0, 1 );
      if ($dbh_ken ne "") {
        $taxonObsolete{$taxon_oid} = $obsolete_flag;
      }
   }
   $cur->finish();

   ## Load tree
   my %validTaxons;
   %validTaxons = %$taxons_href
       if $taxons_href ne "" && ref($taxons_href) eq 'HASH';

   if (scalar keys %validTaxons < 1) {
       %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
       if ( $taxonSelectRestrict eq "taxonSelections" ) {
	       %validTaxons = WebUtil::getSelectedTaxonsHashed( $dbh );
       }
       if ( $taxonSelectRestrict eq "pageRestrictedMicrobes" ) {
	       %validTaxons = getPageRestrictedMicrobes( $dbh );
       }
   }
   my $sql = qq{
      select node_oid, display_name, rank_name, taxon, parent
      from dt_taxon_node_lite
      where 1 = 1
      order by node_oid
   };


   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   my %nodeOid2Node;
   my %nodeOid2Parent;
   my @roots;
   for( ;; ) {
       my( $node_oid, $display_name, $rank_name, $taxon, $parent ) =
          $cur->fetchrow();
       last if !$node_oid;

       my $taxon_oid = $taxon;
       $taxon_oid = "" if $validTaxons{ $taxon } eq "";
       $taxon_oid = "" if !$validTaxons{ $taxon };
       if ( $taxon_oid ne "" ) {
          $display_name = $taxonNames{ $taxon_oid };
       }
       my $n = new PhyloNode( $taxon_oid, $display_name );
       $n->{ domain } = $taxonDomains{ $taxon_oid };
       $n->{ node_oid } = $node_oid;
       $n->{ seq_center } = $seqCenter{ $taxon_oid };
       $n->{ seq_status } = $seqStatus{ $taxon_oid };

       if ($dbh_ken ne "") {
	   $n->{ obsolete_flag } = $taxonObsolete{ $taxon_oid };
       }

       $nodeOid2Node{ $node_oid } = $n;
       $nodeOid2Parent{ $node_oid } = $parent;

       if ( blankStr( $parent ) || $parent == 0 ) {
          push( @roots, $n );
	  $root->addNode( $n );
       }
       if ( ! WebUtil::blankStr( $taxon ) ) {
          $taxonOid2Node->{ $taxon } = $n;
       }
   }
   ## Attach children
   my @node_oids = sort{ $a <=> $b }keys( %nodeOid2Node );
   for my $node_oid( @node_oids ) {
      my $n = $nodeOid2Node{ $node_oid };
      my $parent = $nodeOid2Parent{ $node_oid };
      next if WebUtil::blankStr( $parent ) || $parent == 0;
      next if !$parent;
      #if ($dbh_ken ne "") {
      #   my $domain = param("domain");
      #   next if invalidParent2( $node_oid, \%nodeOid2Parent, \%nodeOid2Node,
      #   $hideViruses, $hidePlasmids, $domain );
      #} else {
      next if invalidParent( $node_oid, \%nodeOid2Parent, \%nodeOid2Node,
			     $hideViruses, $hidePlasmids, $hideObsoleteTaxon,
			     $hideGFragment );
      #}
      my $p = $nodeOid2Node{ $parent };
      next if !$p;

      $p->addNode( $n );
   }
   $root->countTaxonOidNodes();
   $root->trimBranches();
   $root->sortLeafNodes();
   $root->loadAllDomains();
   $cur->finish();

   if ($dbh_ken ne "") {
       return;
   } else {
     #$dbh->disconnect();
   }
}


############################################################################
# loadPhenotypeTree - Load the tree from the database for IMG phenotypes
############################################################################
sub loadPhenotypeTree {
   my( $self, $dbh, $rule_id, $show_all ) = @_;
   my $root = $self->{ root };
   $root->{ node_oid } = "root";
   my $taxonOid2Node = $self->{ taxonOid2Node };

   ## Load taxon_oid => taxon_display_names map.
   my %taxonNames;
   my %taxonDomains;
   my %taxonObsolete;
   my %seqCenter;
   my %seqStatus;
   my $hideViruses = 1;
   my $hidePlasmids = 1;
   my $hideGFragment = 1;
   my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");

   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $sql = qq{
       select tx.taxon_oid, tx.taxon_display_name,
	      tx.domain, tx.seq_status, tx.seq_center
       from taxon tx
       where tx.domain in ('Archaea','Bacteria', 'Eukaryota')
       $rclause
       $imgClause
   };

   if ( ! $show_all ) {
       $sql = qq{
           select tx.taxon_oid, tx.taxon_display_name,
	          tx.domain, tx.seq_status, tx.seq_center
	   from taxon tx, phenotype_rule_taxons prt
	   where tx.taxon_oid = prt.taxon
	   and prt.rule_id = $rule_id
	   $rclause
	   $imgClause
       };
   }

   my %validTaxons;

   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   for( ;; ) {
      my( $taxon_oid, $taxon_display_name, $domain,
          $seq_status, $seq_center ) = $cur->fetchrow();
      last if !$taxon_oid;

      $validTaxons{$taxon_oid} = $taxon_oid;

      $taxonNames{ $taxon_oid } = $taxon_display_name;
      $taxonDomains{ $taxon_oid } = substr( $domain, 0, 1 );
      $seqCenter{ $taxon_oid } = $seq_center;
      $seqStatus{ $taxon_oid } = substr( $seq_status, 0, 1 );
   }
   $cur->finish();

   ## Load tree
   my $sql = qq{
      select node_oid, display_name, rank_name, taxon, parent
      from dt_taxon_node_lite
      where 1 = 1
      order by node_oid
   };

   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   my %nodeOid2Node;
   my %nodeOid2Parent;
   my @roots;
   for( ;; ) {
       my( $node_oid, $display_name, $rank_name, $taxon, $parent ) =
          $cur->fetchrow();
       last if !$node_oid;
       my $taxon_oid = $taxon;
       $taxon_oid = "" if $validTaxons{ $taxon } eq "";
       if ( $taxon_oid ne "" ) {
          $display_name = $taxonNames{ $taxon_oid };
       }

       my $n = new PhyloNode( $taxon_oid, $display_name );
       $n->{ domain } = $taxonDomains{ $taxon_oid };
       $n->{ node_oid } = $node_oid;
       $n->{ seq_center } = $seqCenter{ $taxon_oid };
       $n->{ seq_status } = $seqStatus{ $taxon_oid };

       $nodeOid2Node{ $node_oid } = $n;
       $nodeOid2Parent{ $node_oid } = $parent;
       if ( blankStr( $parent ) || $parent == 0 ) {
          push( @roots, $n );
	  $root->addNode( $n );
       }
       if ( !WebUtil::blankStr( $taxon ) ) {
          $taxonOid2Node->{ $taxon } = $n;
       }
   }
   ## Attach children
   my @node_oids = sort{ $a <=> $b }keys( %nodeOid2Node );
   for my $node_oid( @node_oids ) {
      my $n = $nodeOid2Node{ $node_oid };
      my $parent = $nodeOid2Parent{ $node_oid };
      next if WebUtil::blankStr( $parent ) || $parent == 0;

      next if invalidParent( $node_oid, \%nodeOid2Parent, \%nodeOid2Node,
			     $hideViruses, $hidePlasmids, $hideObsoleteTaxon,
			     $hideGFragment );

      my $p = $nodeOid2Node{ $parent };
      $p->addNode( $n );
   }
   $root->countTaxonOidNodes();
   $root->trimBranches();
   $root->sortLeafNodes();
   $root->loadAllDomains();
   $cur->finish();

}


############################################################################
# invalidParent - Check for invaliid parent.
############################################################################
sub invalidParent {
   my( $node_oid, $nodeOid2Parent_ref, $nodeOid2Node_ref,
       $hideViruses, $hidePlasmids, $hideObsoleteTaxon, $hideGFragment ) = @_;
   for( my $parent_oid = $node_oid; $parent_oid ne ""; ) {
      my $p = $nodeOid2Node_ref->{ $parent_oid };
      return 1 if $p->{ domain } eq "V" && $hideViruses ne "No";
      return 1 if $p->{ domain } eq "P" && $hidePlasmids ne "No";
      return 1 if $p->{ domain } eq "G" && $hideGFragment ne "No";

      if ($img_taxon_edit) {
          return 1 if $p->{ obsolete_flag } eq "Yes"
	      && $hideObsoleteTaxon eq "Yes";
      }

      $parent_oid = $nodeOid2Parent_ref->{ $parent_oid };
   }
   return 0;
}


############################################################################
# getPageRestrictedMicrobes - Get restricted microbes qualification
#   from hidden variables, taken from main front page, or lineage
#   selection.
############################################################################
sub getPageRestrictedMicrobes {
    my( $dbh ) = @_;

    my $genome_type = param( "genome_type" );
    my $domain = param( "domain" );
    my $phylum = param( "phylum" );
    my $ir_class = param( "ir_class" );
    my $ir_order = param( "ir_order" );
    my $family = param( "family" );
    my $genus = param( "genus" );
    my $seq_center = param( "seq_center" );
    my $seq_status = param( "seq_status" );
    my $mainPageStats = param( "mainPageStats" );

    my ($rclause, @bindList_ur) = urClauseBind();
    my $andClause;
    my @bindList_sql;
    if ( $domain ne "" ) {
        if ( $domain =~ /Plasmid/ ) {
            $andClause .= "and domain like ? \n";
            push(@bindList_sql, "Plasmid%");
        } elsif ($domain =~ /GFragment/) {
            $andClause .= "and domain like ? \n";
            push(@bindList_sql, "GFragment%");
        } elsif ($domain =~ /Vir/) {
            $andClause .= "and domain like ? \n";
            push(@bindList_sql, "Vir%");
        }
        else {
            $andClause .= "and domain = ? \n";
            push(@bindList_sql, "$domain");
        }
    }
    elsif ( $mainPageStats eq "" ) {
       my $hideViruses = getSessionParam( "hideViruses" );
       $hideViruses = "Yes" if $hideViruses eq "";
       if ($hideViruses eq "Yes") {
           $andClause .= "and domain not like ? \n";
           push(@bindList_sql, "Vir%");
       }
       my $hidePlasmids = getSessionParam( "hidePlasmids" );
       $hidePlasmids = "Yes" if $hidePlasmids eq "";
       if ($hidePlasmids eq "Yes") {
           $andClause .= "and domain not like ? \n";
           push(@bindList_sql, "Plasmid%");
       }

       my $hideGFragment = getSessionParam("hideGFragment");
       $hideGFragment = "Yes" if $hideGFragment eq "";
       if ($hideGFragment eq "Yes") {
           $andClause .= "and domain not like ? \n";
           push(@bindList_sql, 'GFragment%');
       }

    }
    if ($phylum ne "") {
        $andClause .= "and phylum = ? \n";
        push(@bindList_sql, "$phylum");
    }
    if ($ir_class ne "") {
        $andClause .= "and ir_class = ? \n";
        push(@bindList_sql, "$ir_class");
    }
    if ($ir_order ne "") {
        $andClause .= "and ir_order = ? \n";
        push(@bindList_sql, "$ir_order");
    }
    if ($family ne "") {
        $andClause .= "and family = ? \n";
        push(@bindList_sql, "$family");
    }
    if ($genus ne "") {
        $andClause .= "and genus = ? \n";
        push(@bindList_sql, "$genus");
    }
    if ($seq_center ne "") {
        $andClause .= "and seq_center = ? \n";
        push(@bindList_sql, "$seq_center");
    }
    if ($seq_status ne "") {
        $andClause .= "and seq_status = ? \n";
        push(@bindList_sql, "$seq_status");
    }

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select t.taxon_oid
        from taxon t
        where 1 = 1
	$andClause
        $rclause
        $imgClause
    };
    #print "getPageRestrictedMicrobes \$sql: $sql<br/>";
    my @bindList = ();
    processBindList(\@bindList, \@bindList_sql, undef, \@bindList_ur);
    #print "\@bindList: @bindList<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my %h;
    for( ;; ) {
        my( $taxon_oid ) = $cur->fetchrow();
	last if !$taxon_oid;
	$h{ $taxon_oid } = $taxon_oid;
    }
    $cur->finish();
    return %h;
}


############################################################################
# incrCount - Increment count for one taxon_oid.
############################################################################
sub incrCount {
   my( $self, $taxon_oid ) = @_;
   my $taxonOid2Node = $self->{ taxonOid2Node };
   my $n = $taxonOid2Node->{ $taxon_oid };
   if ( $n eq "" ) {
      webLog( "incrCount: cannot find taxon_oid='$taxon_oid'\n" );
      return;
   }
   $n->{ count }++;
}

############################################################################
# setCount - Set count for one taxon_oid.
############################################################################
sub setCount {
   my( $self, $taxon_oid, $cnt ) = @_;
   my $taxonOid2Node = $self->{ taxonOid2Node };
   my $n = $taxonOid2Node->{ $taxon_oid };
   if ( $n eq "" ) {
      webLog( "setCount: cannot find taxon_oid='$taxon_oid'\n" );
      return;
   }
   $n->{ count } = $cnt;
}

############################################################################
# aggCount - Aggregate count from leave to parent nodes.
############################################################################
sub aggCount {
   my( $self ) = @_;
   my $root = $self->{ root };
   $root->aggCount();
}

############################################################################
# printHtmlCounted - Print the tree out with counts of hits at various
#   levels.
############################################################################
sub printHtmlCounted {
   my( $self ) = @_;
   my $root = $self->{ root };
   $root->printHtmlCounted();
}

############################################################################
# printExpandableTree  - Print expandable tree.
############################################################################
sub printExpandableTree {
   my( $self, $master_taxon_oid, $return_page ) = @_;
   my $collapse = param( "collapse" );
   my $expand = param( "expand" );
   my $expand_nodes = getSessionParam( "expand_nodes" );
   my $select_taxon_oid = param( "select_taxon_oid" );
   my $deselect_taxon_oid = param( "deselect_taxon_oid" );
   my $selected_taxon_oid_str = getSessionParam( "selected_taxon_oid" );
   my %expandNodes;
   print "<p>\n";;
   print WebUtil::domainLetterNote();
   print "<br/>\n";
   print "Operations: [<b>O</b>]pen, [<b>C</b>]lose.&nbsp;&nbsp;\n";
   print "[<b>Add</b>] [<b>Rem</b>]ove selection.<br/>\n";
   print "The number of genomes is shown in parentheses.\n";
   print "</p>\n";;
   if ( $expand_nodes eq "" ) {
       my $dbh = WebUtil::dbLogin();
       my $sql = qq{
           select node_oid
	   from dt_taxon_node_lite
	   where rank_name = 'Domain'
       };
       my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
       for( ;; ) {
          my( $node_oid ) = $cur->fetchrow();
	  last if !$node_oid;
	  #$expandNodes{ $node_oid } = $node_oid;
       }
       $cur->finish( );
       #$dbh->disconnect();
   }
   else {
      my @a = split( ',', $expand_nodes );
      @expandNodes{@a} = @a;
#      my %h = WebUtil::array2Hash( @a );
#      %expandNodes = %h;
   }
   if ( $collapse ne "" ) {
      delete $expandNodes{ $collapse };
   }
   if ( $expand ne "" ) {
      $expandNodes{ $expand } = $expand;
   }
   my @taxon_oids = split( /,/, $selected_taxon_oid_str );
   my %selectedTaxonOidsHash;
#   = WebUtil::array2Hash( @taxon_oids );
	@selectedTaxonOidsHash{ @taxon_oids } = @taxon_oids;
   if ( $select_taxon_oid ne "" ) {
      webLog( "select taxon_oid=$select_taxon_oid\n" ) if $verbose >= 1;
      $selectedTaxonOidsHash{ $select_taxon_oid } = $select_taxon_oid;
   };
   if ( $deselect_taxon_oid ne "" ) {
      webLog( "deselect taxon_oid=$deselect_taxon_oid\n" ) if $verbose >= 1;
      delete $selectedTaxonOidsHash{ $deselect_taxon_oid };
   };
   my @keys = sort( keys( %selectedTaxonOidsHash ) );
   my $nSelected = @keys;
   my $selected_taxon_oid_str = join( ',', @keys );
   webLog( "selected_taxon_oid_str='$selected_taxon_oid_str'\n" )
      if $verbose >= 1;
   setSessionParam( "selected_taxon_oid", $selected_taxon_oid_str );
   my $last_changed_node = $collapse if $collapse ne "";
   $last_changed_node = $expand if $expand ne "";
   $last_changed_node = param( "last_changed_node" )
      if param( "last_changed_node" ) ne "";
   my $root = $self->{ root };
   my $root_node_oid = $root->{ node_oid };
   webLog( "root_node_oid='$root_node_oid'\n" );
   $expandNodes{ $root_node_oid } = $root_node_oid;
   my $expand_nodes = join( ',', keys( %expandNodes ) );
   setSessionParam( "expand_nodes", $expand_nodes );
   webLog( "expand_node='$expand_nodes'\n" ) if $verbose >= 1;
   print "<pre>\n";
   $root->printExpandableTree( \%expandNodes, $master_taxon_oid,
      $return_page, $last_changed_node, \%selectedTaxonOidsHash );
   print "</pre>\n";
   print "<p>\n";
   print "<font color='green'>\n";
   print "$nSelected selected genome(s) in tree.\n";
   print "</font>\n";
   WebUtil::printStatusLine( "$nSelected selected genome(s) in tree.", 2 );
   print "</p>\n";
}

############################################################################
# printSelectableTree - Print tree for genome browser selections.
# $editor - for taxon editor flag
############################################################################
sub printSelectableTree {
   my( $self, $taxon_filter_ref, $taxon_filter_cnt, $editor ) = @_;
   my $root = $self->{ root };
   my %taxonOid2Idx;
   my $count = 0;
   $taxonOid2Idx{ count } = 0;
   $root->getTaxonOid2IdxMap( \%taxonOid2Idx, \$count );
   print "<p>\n";
   if ( $verbose >= 5 ) {
       my @keys = sort( keys( %taxonOid2Idx ) );
       for my $k( @keys ) {
          my $idx = $taxonOid2Idx{ $k };
          webLog( "debug k='$k' idx='$idx'\n" );
       }
   }
   print "<div id=nowrap>\n";
   $root->printSelectableTree( $taxon_filter_ref,
      $taxon_filter_cnt, \%taxonOid2Idx, $editor );
   print "</div>\n";
   print "</p>\n";
}

############################################################################
# printTreeviewNodes - Print javascript nodes for Treeview.
############################################################################
#sub printTreeviewNodes {
#   my( $self, $target ) = @_;
#   print "<script language='javascript' type='text/javascript'>\n";
#   print qq{
#
#	var target = ctime();
#
#        function remoteTaxonSend( args ) {
#           var url0 = "$inner_cgi?iframe=taxonBrowserSelections&" + args +
#	     "&linkTarget=" + target;
#	   sendUrl2( url0, remoteTaxonSelectionsRecv );
#           var e0 = document.getElementById( "taxonSelections" );
#	   e0.innerHTML = "<font color='red'><blink>Loading ...</blink><font>";
#	   //
#	   /* --es 03/22/2007 Not needed
#           var url1 = "$inner_cgi?iframe=taxonBrowserDetails&" + args +
#	     "&linkTarget=" + target;
#	   sendUrl( url1, remoteTaxonDetailsRecv );
#           var e1 = document.getElementById( "taxonDetails" );
#	   e1.innerHTML = "<font color='red'>Loading section 1 ...<font>";
#	   */
#        }
#	function remoteTaxonSelectionSend( url ) {
#	   sendUrl2( url, remoteTaxonSelectionsRecv );
#           var e0 = document.getElementById( "taxonSelections" );
#	   e0.innerHTML = "<font color='red'>Loading section 2 ...<font>";
#	}
#        function remoteTaxonDetailsRecv() {
#           if ( http.readyState == 4 ) {
#              var e = document.getElementById( 'taxonDetails' );
#              e.innerHTML = http.responseText;
#           }
#        }
#        function remoteTaxonSelectionsRecv() {
#           if ( http2.readyState == 4 ) {
#              var e = document.getElementById( 'taxonSelections' );
#              e.innerHTML = http2.responseText;
#           }
#        }
#        USETEXTLINKS  = 1;
#        STARTALLOPEN = 0;
#        USEFRAMES = 0
#        USEICONS = 0;
#        PRESERVESATE = 1;
#        WRAPTEXT = 1;
#        HIGHLIGHT = 1;
#	ICONPATH = "$base_url/images/";
#        foldersTree = gFld( "<b>All Genomes</b>",
#          "$main_cgi?section=TaxonList&page=taxonListAlpha" );
#        var nroot = foldersTree;
#   };
#   my $root = $self->{ root };
#   $root->printTreeviewNodes();
#   print "</script>\n";
#}


############################################################################
# printPhenotypeTree - Print tree for IMG phenotypes
#
# $phenotype: phenotype
# $rule_id: rule ID
# $show_all: 1 - show all, 0 - show selected only
############################################################################
sub printPhenotypeTree {
   my( $self, $taxon_filter_ref, $taxon_filter_cnt, $phenotype, $rule_id, $show_all ) = @_;
   my $root = $self->{ root };
   my %taxonOid2Idx;
   my $count = 0;
   $taxonOid2Idx{ count } = 0;
   $root->getTaxonOid2IdxMap( \%taxonOid2Idx, \$count );
   print "<p>\n";
   if ( $verbose >= 5 ) {
       my @keys = sort( keys( %taxonOid2Idx ) );
       for my $k( @keys ) {
          my $idx = $taxonOid2Idx{ $k };
          webLog( "debug k='$k' idx='$idx'\n" );
       }
   }
   print "<div id=nowrap>\n";
   print "<p>\n";
   $root->printPhenotypeTree( $taxon_filter_ref,
      $taxon_filter_cnt, \%taxonOid2Idx, $phenotype, $rule_id, $show_all );
   print "</div>\n";
   print "</p>\n";
}


############################################################################
# loadFuncTree - Load the tree from the database for IMG functions
############################################################################
sub loadFuncTree {
   my( $self, $dbh, $taxon_href, $show_all ) = @_;
   my $root = $self->{ root };
   $root->{ node_oid } = "root";
   my $taxonOid2Node = $self->{ taxonOid2Node };

   ## Load taxon_oid => taxon_display_names map.
   my %taxonNames;
   my %taxonDomains;
   my %taxonObsolete;
   my %seqCenter;
   my %seqStatus;
   my $hideViruses = 1;
   my $hidePlasmids = 1;
   my $hideGFragment = 1;
   my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");

   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $sql = qq{
      select tx.taxon_oid, tx.taxon_display_name,
          tx.domain, tx.seq_status, tx.seq_center
          from taxon tx
      where tx.domain in ('Archaea','Bacteria', 'Eukaryota', '*Microbiome' )
          $rclause
          $imgClause
   };

   my %validTaxons;

   my %show_only_taxon_h;
   for my $k1 (keys %$taxon_href) {
       $show_only_taxon_h{$k1} = 1;
   }

   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   for( ;; ) {
      my( $taxon_oid, $taxon_display_name, $domain,
          $seq_status, $seq_center ) = $cur->fetchrow();
      last if !$taxon_oid;

      if ( ! $show_all && ! $show_only_taxon_h{$taxon_oid} ) {
	  next;
      }

      $validTaxons{$taxon_oid} = $taxon_oid;

      $taxonNames{ $taxon_oid } = $taxon_display_name;
      $taxonDomains{ $taxon_oid } = substr( $domain, 0, 1 );
      $seqCenter{ $taxon_oid } = $seq_center;
      $seqStatus{ $taxon_oid } = substr( $seq_status, 0, 1 );
   }
   $cur->finish();

   ## Load tree
   my $sql = qq{
      select node_oid, display_name, rank_name, taxon, parent
      from dt_taxon_node_lite
      where 1 = 1
      order by node_oid
   };

   my $cur = WebUtil::execSql( $dbh, $sql, 1 );
   my %nodeOid2Node;
   my %nodeOid2Parent;
   my @roots;
   for( ;; ) {
       my( $node_oid, $display_name, $rank_name, $taxon, $parent ) =
          $cur->fetchrow();
       last if !$node_oid;
       my $taxon_oid = $taxon;
       $taxon_oid = "" if $validTaxons{ $taxon } eq "";
       if ( $taxon_oid ne "" ) {
          $display_name = $taxonNames{ $taxon_oid };
       }

       my $n = new PhyloNode( $taxon_oid, $display_name );
       $n->{ domain } = $taxonDomains{ $taxon_oid };
       $n->{ node_oid } = $node_oid;
       $n->{ seq_center } = $seqCenter{ $taxon_oid };
       $n->{ seq_status } = $seqStatus{ $taxon_oid };

       $nodeOid2Node{ $node_oid } = $n;
       $nodeOid2Parent{ $node_oid } = $parent;
       if ( blankStr( $parent ) || $parent == 0 ) {
          push( @roots, $n );
	  $root->addNode( $n );
       }
       if ( !WebUtil::blankStr( $taxon ) ) {
          $taxonOid2Node->{ $taxon } = $n;
       }
   }

   ## Attach children
   my @node_oids = sort{ $a <=> $b }keys( %nodeOid2Node );
   for my $node_oid( @node_oids ) {
      my $n = $nodeOid2Node{ $node_oid };
      my $parent = $nodeOid2Parent{ $node_oid };

      next if WebUtil::blankStr( $parent ) || $parent == 0;

      next if invalidParent( $node_oid, \%nodeOid2Parent, \%nodeOid2Node,
			     $hideViruses, $hidePlasmids, $hideObsoleteTaxon,
			     $hideGFragment );

      my $p = $nodeOid2Node{ $parent };
      $p->addNode( $n );
   }
   $root->countTaxonOidNodes();
   $root->trimBranches();
   $root->sortLeafNodes();
   $root->loadAllDomains();
   $cur->finish();
}

############################################################################
# printFuncTree - Print tree for IMG functions
#
# $show_all: 1 - show all, 0 - show selected only
############################################################################
sub printFuncTree {
   my( $self, $taxon_filter_ref, $taxon_filter_cnt, $show_all ) = @_;
   my $root = $self->{ root };
   my %taxonOid2Idx;
   my $count = 0;
   $taxonOid2Idx{ count } = 0;
   $root->getTaxonOid2IdxMap( \%taxonOid2Idx, \$count );
   print "<p>\n";
   if ( $verbose >= 5 ) {
       my @keys = sort( keys( %taxonOid2Idx ) );
       for my $k( @keys ) {
          my $idx = $taxonOid2Idx{ $k };
          webLog( "debug k='$k' idx='$idx'\n" );
       }
   }
   print "<div id=nowrap>\n";
   print "<p>\n";
   $root->printFuncTree( $taxon_filter_ref,
      $taxon_filter_cnt, \%taxonOid2Idx, $show_all );
   print "</div>\n";
   print "</p>\n";
}


1;
