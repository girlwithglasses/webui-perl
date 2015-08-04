############################################################################
# DrawTreeNode.pm - Node for DrawTree.pm
#   --es 11/27/2006
############################################################################
package DrawTreeNode;
use strict;
use Data::Dumper;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $verbose = $env->{ verbose };

my $h_bar = 10; # horizontal bar
my $y_start = 1;
my $y_offset = 1;

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
   my( $myType, $id, $desc, $branchLength, $distance ) = @_;
   my $self = { };
   bless( $self, $myType );

   ###
   # Attributes
   #
   $self->{ id } = $id;
   $self->{ desc } = $desc;
   $self->{ highlight } = 0;
   $self->{ mouseover } = ""; # title to use in mouse over
   $self->{ hyperlink } = "";  # hyperlink URL for clicking
   $self->{ branchLength } = $branchLength;
   $self->{ branchLength } = 1.0 if $branchLength eq "";
   $self->{ distance } = $distance;
   $self->{ distance } = 1.0 if $distance eq "";
   $self->{ leafOrder } = { };

   $self->{ x } = -1;
   $self->{ y } = -1;

   my @a;
   $self->{ children } = \@a;
   $self->{ parent };

   $self->{ domains };

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
# toPhyloXML - converts the tree stucture to phyloXML format for aptx
############################################################################
sub toPhyloXML {
    my( $self, $outFile ) = @_;

    # assign names to parent nodes based on lineage of leaf nodes:
    my @leafNodes; 
    getLeafNodes( $self, \@leafNodes );
    for my $leaf( @leafNodes ) {
	my $parent = $leaf->{ parent };
	if ($parent ne "") {
	    assign($parent);
	}
    }

    my $wfh = newWriteFileHandle( $outFile, "toPhyloXML" );
    print $wfh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $wfh 
	"<phyloxml xmlns:xsi=\"" .
	"http://www.w3.org/2001/XMLSchema-instance" .
	"\" xsi:schemaLocation=\"" .
	"http://www.phyloxml.org http://www.phyloxml.org/1.10/phyloxml.xsd\"" .
	" xmlns=\"" . "http://www.phyloxml.org\">\n";               
    print $wfh "<phylogeny rooted=\"false\">\n";

    writeNode( $self, $wfh ); 

    print $wfh "</phylogeny>\n";
    print $wfh "</phyloxml>\n";
    close $wfh;
}

############################################################################
# assigns names to parent nodes based on lineage of leaf nodes
############################################################################
sub assign { 
    my( $self ) = @_; 

    my $siblings = $self->{ children };   
    my $nNodes = @$siblings; 
    
    my ($d, $ph, $cls, $o, $f, $g) = 0;
    my ($domain, $phylum, $class, $order, $family, $genus);

    for( my $i = 0; $i < $nNodes; $i++ ) { 
	# check if all siblings have the desc field
	my $child = $siblings->[ $i ];
	my $desc = $child->{ desc }; 
	if ($child->{ desc } eq "") { return; }
	
	my $a = $child->{ children };
	my $n = @$a; 
	my $isLeaf = 0; 
	$isLeaf = 1 if $n == 0;
 
	my @items; 
	if ($isLeaf) {
	    my ($lineage, $rest) = split(':', $desc);
	    @items = split(',', $lineage); 
	} else { 
	    @items = split(',', $desc);
	} 

	my $nItems = scalar @items;
	if ($i == 0) {
	    $domain = $items[0] if ($nItems > 0);
	    $phylum = $items[1] if ($nItems > 1);
	    $class  = $items[2] if ($nItems > 2);
	    $order  = $items[3] if ($nItems > 3);
	    $family = $items[4] if ($nItems > 4);
	    $genus  = $items[5] if ($nItems > 5);
	    next;
	}
	if ($nItems > 0 && $domain ne "" && $items[0] eq $domain) {
	    $d = 1;
	} else {
	    $d = 0;
	}
	if ($nItems > 1 && $phylum ne "" && $items[1] eq $phylum) { 
	    $ph = 1;
	} else {
	    $ph = 0;
	}
	if ($nItems > 2 && $class ne "" && $items[2] eq $class) { 
	    $cls = 1;
	} else {
	    $cls = 0;
	}
	if ($nItems > 3 && $order ne "" && $items[3] eq $order) { 
	    $o = 1;
	} else {
	    $o = 0;
	}
	if ($nItems > 4 && $family ne "" && $items[4] eq $family) { 
	    $f = 1;
	} else {
	    $f = 0;
	}
	if ($nItems > 5 && $genus ne "" && $items[5] eq $genus) { 
	    $g = 1;
	} else {
	    $g = 0;
	}
    } 

    my $parentLineage;
    $parentLineage .= $domain if $d;
    $parentLineage .= ",".$phylum if $ph;
    $parentLineage .= ",".$class if $cls;
    $parentLineage .= ",".$order if $o;
    $parentLineage .= ",".$family if $f;
    $parentLineage .= ",".$genus if $g;
    #$parent->{ desc } = $parentLineage;
    $self->{ desc } = $parentLineage;
    
    my $parent = $self->{ parent };
    if ($parent ne "") { 
	assign( $parent ); 
    }
}

############################################################################
# writeNode - recursively writes out the xml for each node (phyloXML)
############################################################################
sub writeNode { 
   my( $self, $wfh ) = @_; 
   my $level = $self->getLevel(); 
   my $sp = "  " x $level; 
   print $wfh "$sp"."<clade>\n";

   my $a = $self->{ children }; 
   my $nNodes = @$a; 
   my $distance = 1 - $self->{ distance };

   my $domains = $self->{ domains };
   my $href = "img";
   $href = "imgDomains" if $domains;

   if ($nNodes == 0) {
       my ($lineage, $sname, $oid) = split(':', $self->{ desc });
       print $wfh "  $sp"."<name>";
       print $wfh $oid;
       print $wfh "[".$self->{ id }."]" if $oid ne $self->{ id };
       print $wfh "</name>\n"; 

       print $wfh "  $sp"."<branch_length>";
       print $wfh $distance; 
       print $wfh "</branch_length>\n"; 

       print $wfh "  $sp"."<taxonomy>\n";
       print $wfh "    $sp"."<id provider=\"$href\">";

       if(!isInt($oid)) { # for MER-FS metagenes -anna
	   my $url = $self->{ hyperlink };
	   $oid = substr($url, rindex($url, "=")+1) if $url ne "";
       }

       print $wfh $oid;
       print $wfh "</id>\n";

       my $code = uc(substr($sname, 0, 10)); ### get from CLASS
       #$code =~ s/\s*$//g;
       $code =~ s/[^\w]/_/g;  # only alphanumeric chars allowed
       print $wfh "    $sp"."<code>";
       print $wfh $code;
       print $wfh "</code>\n";

       if (!$domains) {
	   print $wfh "    $sp"."<scientific_name>";
	   print $wfh $sname;
	   print $wfh "</scientific_name>\n";
           print $wfh "    $sp"."<common_name>";
           print $wfh "$lineage";
           print $wfh "</common_name>\n"; 
	   print $wfh "  $sp"."</taxonomy>\n";
       }

       if ($domains) {
	   my ($lineage, $tx_code, $gene_oid, $gene_name,
	       $taxon_oid, $taxon_name, $locus_tag, 
	       $dna_seq_length, $aa_len,
	       $start, $end, $accession) = split(':', $self->{ desc });

	   print $wfh "    $sp"."<scientific_name>";
	   print $wfh "$gene_name"; 
	   print $wfh "</scientific_name>\n";
	   print $wfh "    $sp"."<common_name>";
	   print $wfh "$lineage,$taxon_name"; 
	   print $wfh "</common_name>\n";
	   print $wfh "  $sp"."</taxonomy>\n";

	   my @items = split('\t', $domains);
	   if (scalar @items > 0) {
	       print $wfh "  $sp"."<sequence type='protein'>\n";
	       print $wfh "    $sp"."<accession source=\"img\">$accession</accession>\n";
	       print $wfh "    $sp"."<name>$locus_tag</name>\n";
	       print $wfh "    $sp"."<domain_architecture length=\"$aa_len\">\n";
	       
	       foreach my $item (@items) {
		   my ($dm_id, $dm, $from, $to) = split(':', $item);
		   print $wfh "      $sp"
		       ."<domain id=\"$dm_id\" from=\"$from\" to=\"$to\" "
		       ."confidence=\"0.3\">$dm</domain>\n";
	       }
	       
	       print $wfh "    $sp"."</domain_architecture>\n";
	       print $wfh "  $sp"."</sequence>\n";
	   }
       }

   } else {
       my $lineage = $self->{ desc };
       my $name;
       if ($lineage ne "") {
	   my @lineage = split(',', $self->{ desc }); 
	   my $count = scalar @lineage;
	   $name = $lineage[$count-1];
	   print $wfh "  $sp"."<name>"; 
	   print $wfh $name; 
	   print $wfh "</name>\n"; 
       }
       print $wfh "  $sp"."<branch_length>";
       print $wfh $distance;
       print $wfh "</branch_length>\n"; 

       print $wfh "  $sp"."<taxonomy>\n";
#       if ($domains) {
	   print $wfh "    $sp"."<id provider=\"imgGenes\">"; 
	   print $wfh $name;
	   print $wfh "</id>\n"; 
#       }
       print $wfh "    $sp"."<common_name>"; 
       print $wfh "$lineage"; 
       print $wfh "</common_name>\n"; 
       print $wfh "  $sp"."</taxonomy>\n"; 
   }
   for( my $i = 0; $i < $nNodes; $i++ ) { 
      my $n2 = $self->{ children }->[ $i ]; 
      writeNode( $n2, $wfh ); 
   } 
   print $wfh "$sp"."</clade>\n";
} 


############################################################################
# printNode - Print contents of the node out for debugging.
############################################################################
sub printNode {
    my( $self ) = @_;
    my $level = $self->getLevel( );
    my $mouseover = $self->{ mouseover };
    my $hyperlink = $self->{ hyperlink };
    my $sp = "&nbsp;&nbsp;" x $level; 

    my $mo;
    my $hl;
    $mo = " '$mouseover'" if $mouseover ne "";
    $hl = " '$hyperlink'" if $hyperlink ne "";

    printf "%s%02d '%s' '%s'%d (%.6f)(%d,%d)$mo $hl<br/>\n",
    $sp, $level, 
    $self->{ id }, $self->{ desc }, $self->{ highlight },
    $self->{ distance }, $self->{ x }, $self->{ y };

    my $a = $self->{ children };
    my $nNodes = @$a;
    for( my $i = 0; $i < $nNodes; $i++ ) {
	my $n2 = $self->{ children }->[ $i ];
	printNode( $n2 );
    }
}

############################################################################
# getRecs - Get records for DrawTree::addNode( ).
############################################################################
sub getRecs {
   my( $self, $recs_ref ) = @_;
   my $id = $self->{ id };
   my $desc = $self->{ desc };
   my $highlight = $self->{ highlight };
   my $x = $self->{ x };
   my $y = $self->{ y };
   my $a = $self->{ children };
   my $nNodes = @$a;
   my $isLeaf = 0;
   $isLeaf = 1 if $nNodes == 0;
   my $p = $self->{ parent };
   my $parentId;
   if( defined( $p ) ) {
      $parentId = $p->{ id };
   }
   my $mouseover = $self->{ mouseover };
   my $hyperlink = $self->{ hyperlink };
   my $distance = $self->{ distance };

   my $r;
   $r .= "$id\t";
   $r .= "$parentId\t";
   $r .= "$desc\t";
   $r .= "$highlight\t";
   $r .= "$x\t";
   $r .= "$y\t";
   $r .= "$isLeaf\t";
   $r .= "$mouseover\t";
   $r .= "$hyperlink\t";
   $r .= "$distance\t";

   push( @$recs_ref, $r );
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $self->{ children }->[ $i ];
      getRecs( $n2, $recs_ref );
   }
}

############################################################################
# addNode - Add one node.  Set the dual pointers.
############################################################################
sub addNode {
   my( $self, $node ) = @_;
   my $a = $self->{ children };
   push( @$a, $node );
   $node->{ parent } = $self;
}

############################################################################
# setCoordinates - Set x,y coordinates of each node for print out.
#   This should be applied to root node only.
############################################################################
sub setCoordinates {
   my( $self ) = @_;

   ## Set coordinates verically for leaf nodes.
   my @leafNodes;
   getLeafNodes( $self, \@leafNodes );
   my $y = $y_start;
   for my $n( @leafNodes ) {
     my $x = 0;
     for( my $p = $n; $p; $p = $p->{ parent } ) {
         $x += ( $p->{ branchLength } * $h_bar );
     }
     $n->{ x } = $x;
     $n->{ y } = $y;
     $y += $y_offset;
   }
   setParentCoordinates( $self );
}

############################################################################ 
# setAlignCoordinates - Set x,y coordinates of each node for print out. 
#   Aligns the leaf names vertically. Should be applied to root node only. 
############################################################################ 
sub setAlignCoordinates { 
   my( $self ) = @_; 
 
   ## Set coordinates verically for leaf nodes. 
   my @leafNodes; 
   getLeafNodes( $self, \@leafNodes ); 

   my $y = $y_start; 
   my $longest_x = 0;

   my $leafOrder = $self->{ leafOrder };
   if ($leafOrder ne "") {
       # order the leaf nodes:
       my @orderedLeafNodes;
       for my $i( @$leafOrder) {
	   for my $j( @leafNodes ) {
	       my $desc = $j->{ desc };
	       if ($i eq $desc) {
		   push (@orderedLeafNodes, $j);
	       }
	   }
       }
       @leafNodes = @orderedLeafNodes;
   }

   for my $n( @leafNodes ) { 
       my $x = 0; 
       for( my $p = $n; $p; $p = $p->{ parent } ) { 
	   $x += ( $p->{ branchLength } * $h_bar ); 
       } 
       if ($x > $longest_x) {
	   $longest_x = $x;
       }
   }
   for my $n( @leafNodes ) { 
       $n->{ x } = $longest_x; 
       $n->{ y } = $y; 
       $y += $y_offset; 
   } 
   setParentCoordinates( $self ); 
} 

############################################################################
# setLeafNodeOrder - sets the order by which to draw the leaf nodes
############################################################################
sub setLeafNodeOrder { 
   my( $self, $order ) = @_; 
   $self->{ leafOrder } = $order;
}
 
############################################################################
# setParentCoordinates - Set parent coordinates once leaf coordinates
#   are set.  Depth first traversal.
############################################################################
sub setParentCoordinates {
   my( $self ) = @_;

   my $a = $self->{ children };
   my $nNodes = @$a;
   return if $nNodes == 0;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $self->{ children }->[ $i ];
      setParentCoordinates( $n2 );
   }
   my $y_sum = 0;
   for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $self->{ children }->[ $i ];
       my $y = $n2->{ y };
       $y_sum += $y;
   }
   my $y_avg = $y_sum / $nNodes;
   my $x = 0;
   for( my $p = $self->{ parent }; $p; $p = $p->{ parent } ) {
       $x += ( $p->{ branchLength } * $h_bar );
   }
   $self->{ x } = $x;
   $self->{ y } = $y_avg;
}

############################################################################
# getLeafNodes - Get only leaf nodes.
############################################################################
sub getLeafNodes {
   my( $self, $leafNodes_ref ) = @_;

   my $a = $self->{ children };
   my $nNodes = @$a;
   if( $nNodes == 0 ) {
      push( @$leafNodes_ref, $self );
   }
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $self->{ children }->[ $i ];
      getLeafNodes( $n2, $leafNodes_ref );
   }
}

1;
