############################################################################
# ImgTermNode.pm - Node for one term.  Cf. ImgTermNodeMgr.
#    --es 12/27/2005
############################################################################
package ImgTermNode;
use strict;
use Data::Dumper;
use CGI qw( :standard );
use WebConfig;
use WebUtil;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $verbose = 0;

my %termType2Name = (
   #"GENE PRODUCT" => "Gene Product",
   "MODIFIED PROTEIN" => "Modified Protein",
   "PROTEIN COMPLEX" => "Protein Complex",
   "PARTS LIST" => "Parts List",
);

############################################################################
# new - Allocate new instance
############################################################################
sub new {
    my( $myType, $term_oid, $term, $term_type ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ term_oid } = $term_oid;
    $self->{ term } = $term;
    $self->{ term_type } = $term_type;
    my @a;
    $self->{ children } = \@a;
    $self->{ parent };  
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
   printf "%s%02d '%s' (oid=%d)\n", $sp, $level,
      $self->{ term }, $self->{ term_oid };
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      printNode( $n2 );
   }
}

############################################################################
# printHtml - Print HTML tree for a node.
############################################################################
sub printHtml {
   my( $self, $notStartNode, $minusLevel, $suffixMap_ref ) = @_;

   my $term_oid = $self->{ term_oid };
   my $term = $self->{ term };
   my $term_type = $self->{ term_type };
   my $level = $self->getLevel( );
   my $a = $self->{ children };
   my $nNodes = @$a;

   print "<br/>" if $nNodes > 0;
   my $sp;
   $sp = nbsp( 2 ) x ( $level - $minusLevel ) if $notStartNode;

   my $term_type_name = $termType2Name{ $term_type };
   print $sp;
   if( $term_oid == 0 ) {
      print "<b>(Term Tree Root)</b>" . nbsp( 1 );
   }
   else {
       my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
       print "<input type='checkbox' name='term_oid' value='$term_oid2' />";
       print nbsp( 1 );
   }
   #if( $nNodes > 0 ) {
   #   print "<b>(Protein Complex)</b>" . nbsp( 1 );
   #}
   if( $term_type eq "PROTEIN COMPLEX" ||
       $term_type eq "MODIFIED PROTEIN" ||
       $term_type eq "PARTS LIST" ) {
          print "<b>($term_type_name)</b>" . nbsp( 1 );
   }
   my $url = "$main_cgi?section=ImgTermBrowser" . 
      "&page=imgTermDetail&term_oid=$term_oid";
   my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
   print alink( $url, $term_oid2 ) if $term_oid > 0;
   print nbsp( 1 );
   print "<b>" if $nNodes > 0;
   print escHtml( $term ) if $term_oid > 0;
   my $suffix;
   if( defined( $suffixMap_ref ) ) {
      $suffix = $suffixMap_ref->{ $term_oid };
   }
   print $suffix;
   print "</b>" if $nNodes > 0;
   print "<br/>\n";

   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      my $level2 = 0;
      $level2 = $minusLevel if $notStartNode;
      printHtml( $n2, 1, $level2 );
   }
   print "<br/>" if $nNodes > 0;
}

#
# for given term node find me all the children term oids
#
sub getTerms {
   my( $self,  $href ) = @_;

   my $term_oid = $self->{ term_oid };
   my $term = $self->{ term };
   my $term_type = $self->{ term_type };
   my $level = $self->getLevel( );
   my $a = $self->{ children };
   my $nNodes = @$a;

   
   $href->{$term_oid} = "";
#   my $s = keys %$href;
#   print "$s --- $term_oid <br/>\n";

   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      $n2->getTerms( $href );
   }
}

# given a term find all its parents and grand parents etc...
# term oids stored in $href
sub getTermsParents {
    my( $self,  $href ) = @_;
    my $term_oid = $self->{ term_oid };
    $href->{$term_oid} = "";
    my $parentNode = $self->{ parent };
    if(!$parentNode) {
        return;
    } else {
        $parentNode->getTermsParents($href);
    }
}

############################################################################
# printSearchHtml - Print HTML tree for a node.
############################################################################
sub printSearchHtml {
   my( $self, $searchTerm, $termOid2Html_ref, 
       $notStartNode, $minusLevel ) = @_;

   my $term_oid = $self->{ term_oid };
   my $term = $self->{ term };
   my $level = $self->getLevel( );
   my $a = $self->{ children };
   my $nNodes = @$a;
   my $sp;
   $sp = nbsp( 2 ) x ( $level - $minusLevel ) if $notStartNode;

   print $sp;
   my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
   print "<input type='checkbox' name='term_oid' value='$term_oid2' />";
   print nbsp( 1 );
   if( $nNodes > 0 ) {
      print "(Protein Complex)" . nbsp( 1 );
   }
   my $url = "$main_cgi?section=ImgTermBrowser" . 
      "&page=imgTermDetail&term_oid=$term_oid";
   my $term_oid2 = FuncUtil::termOidPadded( $term_oid );
   print alink( $url, $term_oid2 );
   print nbsp( 1 );
   #print escHtml( $term );
   my $matchText = highlightMatchHTML2( $term, $searchTerm );
   print $matchText;
   my $xtra = $termOid2Html_ref->{ $term_oid };
   print $xtra;
   print "<br/>\n";

   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $a->[ $i ];
      my $level2 = 0;
      $level2 = $minusLevel if $notStartNode;
      printSearchHtml( $n2, $searchTerm, $termOid2Html_ref, 1, $level2 );
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
# addNode - Add one node.
############################################################################
sub addNode {
   my( $self, $n ) = @_;

   my $n2 = new ImgTermNode( 
      $n->{ term_oid }, $n->{ term }, $n->{ term_type } );

   my $a = $self->{ children };
   push( @$a, $n2 );
   $n2->{ parent } = $self;
   return $n2;
}

############################################################################
# loadLeafTermOids - Load all leaf term_oid's.
############################################################################
sub loadLeafTermOids {
    my( $self, $a_ref ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    push( @$a_ref, $term_oid ) if $nNodes == 0;
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->loadLeafTermOids( $a_ref );
    }
}
############################################################################
# loadAllChildTermOids - Load all leaf term_oid's.
############################################################################
sub loadAllChildTermOids {
    my( $self, $a_ref ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    push( @$a_ref, $term_oid );
    my $p = $self->{ parent };
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->loadAllChildTermOids( $a_ref );
    }
}

############################################################################
# loadAllTermOidsHashed - Load all leaf term_oid's.
############################################################################
sub loadAllTermOidsHashed {
    my( $self, $h_ref ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    $h_ref->{ $term_oid } = $term_oid;
    my $p = $self->{ parent };
    for( ; $p && $p->{ term_oid } > 0; $p = $p->{ parent } ) {
	my $p_term_oid = $p->{ term_oid };
	$h_ref->{ $p_term_oid } = $p_term_oid;
    }
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->loadAllTermOidsHashed( $h_ref );
    }
}
############################################################################
# loadAllParentTermOidsHashed - Load all leaf term_oid's.
############################################################################
sub loadAllParentTermOidsHashed {
    my( $self, $h_ref ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    $h_ref->{ $term_oid } = $term_oid;
    my $p = $self->{ parent };
    for( ; $p && $p->{ term_oid } > 0; $p = $p->{ parent } ) {
	my $p_term_oid = $p->{ term_oid };
	$h_ref->{ $p_term_oid } = $p_term_oid;
    }
}
############################################################################
# loadAllChildTermOidsHashed - Load all leaf term_oid's.
############################################################################
sub loadAllChildTermOidsHashed {
    my( $self, $h_ref ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    $h_ref->{ $term_oid } = $term_oid;
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->loadAllChildTermOidsHashed( $h_ref );
    }
}

############################################################################
# findNode - Find a specific node.
############################################################################
sub findNode {
    my( $self, $q_term_oid ) = @_;
    $q_term_oid = sprintf( "%d", $q_term_oid );
    my $term_oid = $self->{ term_oid };
    return $self if( $term_oid eq $q_term_oid );
    my $children = $self->{ children };
    for my $c( @$children ) {
       my $x = $c->findNode( $q_term_oid );
       return $x if defined( $x );
    }
    return undef;
}

############################################################################
# printPathHtml - Print path from parents with links in HTML format.
############################################################################
sub printPathHtml {
    my( $self ) = @_;
    my @a;
    my $n = $self;
    for( ; $n->{ parent }; $n = $n->{ parent } ) {
       push( @a, $n );
    }
    my @b = reverse( @a );
    my $s;
    for my $n( @b ) {
	my $term_oid = $n->{ term_oid };
	my $term = $n->{ term };
	my $url = "$main_cgi?section=ImgTermBrowser" . 
	   "&page=imgTermDetail&term_oid=$term_oid";
	$s .= alink( $url, $term ) . "; ";
    }
    chop $s;
    chop $s;
    print "$s<br/>\n";
}

############################################################################
# sortNodes - Sort children alphabetically.
############################################################################
sub sortNodes {
    my( $self ) = @_;

    my $n = $self;
    my $a = $n->{ children };
    my $nNodes = @$a;

    my @recsIdx;
    my @recsNodes;
    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       my $term = $n2->{ term };
       my $r = "$term\t";
       $r .= "$i\t";
       push( @recsIdx, $r );
       push( @recsNodes, $n2 );
    }
    my @recsIdx2 = sort( @recsIdx );
    my @recsNodes2;
    for my $r( @recsIdx2 ) {
       my( $term, $idx ) = split( /\t/, $r );
       my $n2 = $recsNodes[ $idx ];
       push( @recsNodes2, $n2 );
    }
    $n->{ children } = \@recsNodes2;

    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       sortNodes( $n2 );
    }
}

############################################################################
# insertMapNodes - Print mapping (child) nodes associated with node.
############################################################################
sub insertMapNodes {
    my( $self, $dbh ) = @_;

    my $a = $self->{ children };
    my $nNodes = @$a;
    my $term_oid = $self->{ term_oid };
    if( $nNodes > 0 && $term_oid > 0 ) {
       my @leafs;
       #$self->loadLeafTermOids( \@leafs );
       $self->loadAllChildTermOids( \@leafs );
       for my $leaf( @leafs ) {
	  next if $leaf eq $term_oid;
	  my $sql = qq{
	     insert into dt_img_term_path( term_oid, map_term )
	     values( $term_oid, $leaf )
	  };
	  my $cur = execSql( $dbh, $sql, $verbose );
	  $cur->finish( );
       }
    }
    for( my $i = 0; $i < $nNodes; $i++ ) {
        my $n2 = $a->[ $i ];
	$n2->insertMapNodes( $dbh );
    }
}

1;

