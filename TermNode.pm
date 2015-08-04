############################################################################
# TermNode.pm - Node for one term.  Cf. TermNodeMgr.
#   The terms here are NOT IMG terms, but terms used for taxon
#   search categories, such as phenotype, ecotype, disease, and relevance.
#   These terms are organized in a tree.
#    --es 12/27/2005
############################################################################
package TermNode;
use strict;
use Data::Dumper;
use CGI qw( :standard );
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $verbose = $env->{ verbose };

############################################################################
# new - Allocate new instance
############################################################################
sub new {
    my( $myType, $term_oid, $term_name ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ term_oid } = $term_oid;
    $self->{ term_name } = $term_name;
    my @a;
    $self->{ children } = \@a;
    $self->{ parent };  # we only allow one parent here
    			# unlike the schema.
    $self->{ taxon_oid } = "";  # associated taxon_oid if any

    return $self;
}

############################################################################
# getLevel - Level (depth) of node.
############################################################################
sub getLevel {
   my( $self ) = @_;
   my $parent = $self->{ parent };
   my $count = 0;
   for( ; $parent; $parent = $parent->{ parent } ) {
      $count++;
   }
   return $count;
}

############################################################################
# printNode - Print contents of the node out for debuggiag.
############################################################################
sub printNode {
   my( $self ) = @_;
   my $level = $self->getLevel( );
   my $sp = "  " x $level;
   my $x;
   my $taxon_oid = $self->{ taxon_oid };
   $x = "(taxon_oid=$taxon_oid)" if $taxon_oid ne "";
   printf "%s%02d '%s' (oid=%d)$x\n", $sp, $level,
      $self->{ term_name }, $self->{ term_oid };
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      printNode( $n2 );
   }
}

############################################################################
# maxDepth - Get maximum depth assessemnt.
############################################################################
sub maxDepth {
   my( $self, $depth_ref ) = @_;
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      maxDepth( $n2, $depth_ref );
   }
   my $level = $self->getLevel( );
   $$depth_ref = $level if $level > $$depth_ref;
}

############################################################################
# printSelectionOptions - Print selection options.
############################################################################
sub printSelectionOptions {
   my( $self, $type ) = @_;
   my $level = $self->getLevel( );
   if( $level == 0 ) {
       print "<select name='${type}_oid' multiple size='10'>\n";
   }
   else {
       my $term_oid = $self->{ term_oid };
       my $term_name = $self->{ term_name };
       my $val = escHtml( $term_name );
       print "<option value='$term_oid'>";
       my $sp = "-" x ( ( $level - 1 ) * 2 );
       if( $level > 1 ) {
           print "$sp $val";
       }
       else {
           print "$val";
       }
       print "</option>\n";
   }
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      printSelectionOptions( $n2 );
   }
   if( $level == 0 ) {
       print "</select>\n";
   }
}

sub printTreeLists {
   my( $self, $type ) = @_;   

   my $level = $self->getLevel( );   
   if( $level == 0 ) {
       #print "<select name='${type}_oid' multiple size='10'>\n";
       print "<li name='${type}_oid'>${type}\n";
   }
   else {
       my $taxon_oid = $self->{ taxon_oid };
       my $term_oid = $self->{ term_oid };
       my $term_name = $self->{ term_name };
       my $val = escHtml( $term_name );
       #print "<option value='$term_oid'>";
       print "<li value='$term_oid'>";

       my $sp = "-" x ( ( $level - 1 ) * 2 );
       if( $level > 1 ) {
           print "$sp $val";
       }
       else {
           print "$val";
       }
       #print "</option>\n";
       print "</li>\n";
   }
   my $a = $self->{ children };
   my $nNodes = @$a;
   if ($nNodes > 0) {
       print "<ul>\n";
       for( my $i = 0; $i < $nNodes; $i++ ) {
          my $n2 = $a->[ $i ];
          #printSelectionOptions( $n2 );
          printTreeLists( $n2 );
       }
       print "</ul>\n";
   }
   if( $level == 0 ) {
       #print "</select>\n";
       print "</li>\n";
   }
}

sub processJSObject {
   my( $self, $type ) = @_;
   my $jsObject = "";
   
   my $level = $self->getLevel( );
   
   if( $level == 0 ) {
       $jsObject .= "{";
       $jsObject .= "level:$level, ";
       $jsObject .= "label:'${type}', ";
       $jsObject .= "param:'${type}_oid', ";
   }
   else {
       my $taxon_oid = $self->{ taxon_oid };
       my $term_oid = $self->{ term_oid };
       my $term_name = $self->{ term_name };
       my $val = escHtml( $term_name );
       $jsObject .= "{";
       #$jsObject .= "level:$level, ";
       $jsObject .= "term_oid:$term_oid, ";
       #$jsObject .= "taxon_oid:$taxon_oid, ";

       my $sp = "-" x ( ( $level - 1 ) * 2 );
       if( $level > 1 ) {
           $jsObject .= "label:\"$sp $val\"";
       }
       else {
           $jsObject .= "label:\"$val\"";
       }
       $jsObject .= "}";
   }
   my $a = $self->{ children };
   my $nNodes = @$a;
   if ($nNodes > 0) {
       $jsObject .= "children: [";
	   for( my $i = 0; $i < $nNodes; $i++ ) {
	      my $n2 = $a->[ $i ];
	      $jsObject .= processJSObject($n2);
	      if ($i != $nNodes-1) {
              $jsObject .= ", ";	      	
	      }
	   }
       $jsObject .= "]";
   }
   if( $level == 0 ) {
       $jsObject .= "}";
   }
   
   return $jsObject;
}


############################################################################
# printTaxonCategoryNode - Show node and children.
############################################################################
sub printTaxonCategoryNode {
   my( $self, $type ) = @_;
   my $level = $self->getLevel( );
   my $taxon_oid = $self->{ taxon_oid };
   if( $level == 0 ) {
      ; # root
   }
   else {
       my $term_oid = $self->{ term_oid };
       my $term_name = $self->{ term_name };
       my $val = escHtml( $term_name );
       if( $taxon_oid ne "" ) {
          my $url = "$main_cgi?section=TaxonList&page=categoryTaxons";
	  $url .= "&category=$type";
	  $url .= "&categoryValue=" . massageToUrl( $term_name );
	  $val = alink( $url, $term_name );
       }
       my $sp = nbsp( 2 ) x $level;
       if( $level >= 1 ) {
           print "$sp $val";
       }
       else {
           print "$val";
       }
       print "<br/>\n";
   }
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      printTaxonCategoryNode( $n2, $type );
   }
   if( $level == 0 ) {
       print "<br/>\n";
   }
}

############################################################################
# printCategoryNodeTaxons - Show node and children.
############################################################################
sub printCategoryNodeTaxons {
   my( $self, $dbh, $type ) = @_;
   my $level = $self->getLevel( );
   my $taxon_oid = $self->{ taxon_oid };
   if( $level == 0 ) {
      ; # root
   }
   else {
       my $term_oid = $self->{ term_oid };
       my $term_name = $self->{ term_name };
       my $val = escHtml( $term_name );
       my $sp = nbsp( 2 ) x $level;
       if( $level >= 1 ) {
           print "$sp $val";
       }
       else {
           print "$val";
       }
       print "<br/>\n";
       if( $taxon_oid ne "" ) {
          printTaxons( $dbh, $level, $term_name, $type );
       }
   }
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      printCategoryNodeTaxons( $n2, $dbh, $type );
   }
   if( $level == 0 ) {
       print "<br/>\n";
   }
}


############################################################################
# printTaxons - Show taxons from give category node.
############################################################################
sub printTaxons {
    my( $dbh, $level, $term_name, $category ) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $valClause = "and cv.${category}_term = ? ";
    
    my $sql = qq{
        select cv.${category}_term, tx.taxon_oid, tx.taxon_display_name,
          tx.domain, tx.seq_status
        from taxon tx, taxon_${category}s ta, ${category}cv cv
        where ta.${category}s = cv.${category}_oid
        and ta.taxon_oid = tx.taxon_oid
        $rclause
        $imgClause
        order by cv.${category}_term, tx.taxon_display_name
   };
   my $cur = execSql( $dbh, $sql, $verbose, $term_name );
   my $count = 0;
   for( ;; ) {
       my( $category, $taxon_oid, $taxon_display_name,
           $domain, $seq_status ) = $cur->fetchrow( );
       last if !$taxon_oid;
       $count++;
       $domain = substr( $domain, 0, 1 );
       $seq_status = substr( $seq_status, 0, 1 );
       print nbsp( 2 ) x ( $level + 1 );
       print "<input type='checkbox' " . 
          "name='taxon_filter_oid' value='$taxon_oid' />\n";
       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
       $url .= "&taxon_oid=$taxon_oid";
       print alink( $url, $taxon_display_name );
       print nbsp( 1 );
       print "($domain)[$seq_status]";
       print "<br/>\n";
   }
   $cur->finish( );
}

############################################################################
# addNode - Add one node.
############################################################################
sub addNode {
   my( $self, $node ) = @_;
   my $a = $self->{ children };
   push( @$a, $node );
   $node->{ parent } = $self;
}

############################################################################
# loadChildrenTermOids - Load all children term_oids' recursively.
############################################################################
sub loadChildrenTermOids {
    my( $self, $h_ref ) = @_;

    my $term_oid = $self->{ term_oid };

    $h_ref->{ $term_oid } = $term_oid;
    my $a = $self->{ children };
    my $nNodes = @$a;
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->loadChildrenTermOids( $h_ref );
    }
}

############################################################################
# hasTaxonOid - See if this or any child node has taxon_oid
############################################################################
sub hasTaxonOid {
    my( $self ) = @_;

    my $taxon_oid = $self->{ taxon_oid };
    if( $taxon_oid ne "" ) {
       return 1;
    }
    my $children = $self->{ children };
    for my $c( @$children ) {
       return 1 if( $c->hasTaxonOid( ) ); 
    }
    return 0;
}

############################################################################
# purgeNoTaxonOid - Purge nodes w/o taxon_oid's in itself or children.
############################################################################
sub purgeNoTaxonOid {
    my( $self ) = @_;

    my $children = $self->{ children };
    my @a2;
    for my $c( @$children ) {
       if( $c->hasTaxonOid( ) ) {
	  push( @a2, $c );
       }
    }
    $self->{ children } = \@a2;
    my $children = $self->{ children };
    for my $c( @$children ) {
       $c->purgeNoTaxonOid( );
    }
}

1;

