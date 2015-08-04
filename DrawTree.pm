############################################################################
# DrawTree.pm - Draw tree given node coordinates and parent relationships.
#   Used mainly for clustering.
# 
# Usage:
#    my $dt = new DrawTree( $newickSpec, \%id2Rec );
#           # rec has tab delim fields: <description> <highlight> 
#           #       <mouseover> <hyperlinkUrl>
#           #  <description> - Description that is displayed.
#           #  <highlight> - value 1 or 0
#    my $dt->drawToFile( $outFile );
#    my $s = $dt->getMap( $image_url, 1 );
#    print "$s\n";
#
#    --es 01/22/2005
############################################################################
package DrawTree;
use strict;
use Data::Dumper;
use GD;
use CGI qw( :standard );
use WebUtil;
use DrawTreeNode;

my $verbose = 3;

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
   my( $myType, $newickSpec, $id2Rec_ref, $domainsRec_ref ) = @_;

   my $self = { };
   bless( $self, $myType );

   my $root;
   $root = parse( $newickSpec, $id2Rec_ref, $domainsRec_ref )
      if !blankStr( $newickSpec );

   $self->{ width } = 800;
   $self->{ height } = 750;
   $self->{ id } = $$;
   $self->{ recs } = { };
   $self->{ x_scale } = 1;
   $self->{ y_scale } = 10;
   $self->{ x_border } = 10;
   $self->{ y_border } = 10;
   $self->{ desc_width } = 700;
   $self->{ leaf_line_width } = 0;
   $self->{ root } = $root;
   $self->{ max_desc_length } = 100;
   $self->{ idList } = { };

   return $self;
}


############################################################################
# esimateDimensions - Estimate dimensions for whole panel with tree.
############################################################################
sub estimateDimensions {
   my( $self ) = @_;

   my $recs = $self->{ recs };
   my $max_x = 0;
   my $max_y = 0;
   my $max_desc = 0;
   my @keys = sort( keys( %$recs ) );
   for my $k( @keys ) {
      my $rec = $recs->{ $k };
      my( $id, $parent, $desc, $highlight, $x, $y ) = split( /\t/, $rec );
      my $im_x = img_x( $self, $x );
      my $im_y = img_y( $self, $y );
      $max_x = $max_x > $im_x ? $max_x : $im_x;
      $max_y = $max_y > $im_y ? $max_y : $im_y;
      my $desc_length = length($desc);
      if ($max_desc < $desc_length) {
	  $max_desc = $desc_length;
      }
   }
   $self->{ max_desc_length } = $max_desc*(gdMediumBoldFont->width);
   $max_x += $self->{ x_border };
   $max_x += $self->{ max_desc_length };
   $max_x += $self->{ x_border };
   $max_y += $self->{ y_border };
   $self->{ width } = $max_x;
   $self->{ height } = $max_y;
}

############################################################################
# img_x - Translate coordaintes for image.
############################################################################
sub img_x {
   my( $self, $x ) = @_;
   return int( $self->{ x_border } + ( $x * $self->{ x_scale } ) );
}

############################################################################
# img_y - Translate coordinates for image.
############################################################################
sub img_y {
   my( $self, $y ) = @_;
   return int( $self->{ y_border } + ( $y * $self->{ y_scale } ) );
}

############################################################################
# allcoateImage - Allocate the image buffer.
############################################################################
sub allocateImage {
    my( $self ) = @_;

    estimateDimensions( $self );
    my $width = $self->{ width };
    my $height = $self->{ height };
    webLog( "width=$width height=$height\n" ) if $verbose >= 3;
    my $im = new GD::Image( $width, $height );
    $self->{ im } = $im;
    $self->colorAllocate( );
    $self->setBrush( );
}

############################################################################
# colorAllocate - Preallocate the colors.
############################################################################
sub colorAllocate {
    my( $self ) = @_;

    my $im = $self->{ im };
    $self->{ color_white } = $im->colorAllocate( 255, 255, 255 );
    $self->{ color_black } = $im->colorAllocate( 0, 0, 0 );
    $self->{ color_red } = $im->colorAllocate( 255, 0, 0 );
    $self->{ color_green } = $im->colorAllocate( 0, 255, 0 );
    $self->{ color_blue } = $im->colorAllocate( 0, 0, 255 );
    $self->{ color_purple } = $im->colorAllocate( 155, 48, 255 );
    $self->{ color_yellow } = $im->colorAllocate( 255, 250, 205 );
    $im->transparent( $self->{ color_white } );
    $im->interlaced( 'true' );

}

############################################################################
# setBrush - Set the brush characteristics.
############################################################################
sub setBrush {
    my( $self ) = @_;

    my $im = $self->{ im };
    my $brush = new GD::Image( 1, 1 );
    $brush->colorAllocate( 255, 255, 255 ); # white
    $brush->colorAllocate( 0, 0, 0 ); # black
    $brush->transparent( $self->{ color_white } );
    $brush->filledRectangle( 0, 0, 1, 1, $self->{ color_black } );
    $im->setBrush( $brush );
    $self->{ brush } = $brush;
}

############################################################################
# addRec - Add one record node.
############################################################################
sub addRec {
   my( $self, $id, $parent, $desc, $highlight, $x, $y, $isLeaf, 
       $mouseover, $hyperlink, $distance ) = @_;

   my $recs = $self->{ recs };
   my $rec = "$id\t";
   $rec .= "$parent\t";
   $rec .= "$desc\t";
   $rec .= "$highlight\t";
   $rec .= "$x\t";
   $rec .= "$y\t";
   $rec .= "$isLeaf\t";
   $rec .= "$mouseover\t";
   $rec .= "$hyperlink\t";
   $rec .= "$distance\t";
   $recs->{ $id } = $rec;
}

############################################################################
# drawTreeLines - Draw the edges to nodes.
############################################################################
sub drawTreeLines {
   my( $self ) = @_;
   my $recs = $self->{ recs };
   my @keys = sort( keys( %$recs ) );

   for my $k( @keys ) {
      my $rec1 = $recs->{ $k };
      my( $id1, $parent1, $desc1, $highlight, $x1, $y1 ) = split( /\t/, $rec1 );
      my $rec2 = $recs->{ $parent1 };
      if( $rec2 eq "" ) {
	  if( $parent1 ne "" ) {
	      webLog( "drawTree: parent '$parent1' not found\n" );
	  }
          next;
      }
      my( $id2, $parent2, $desc2, $highlight2, $x2, $y2 ) = 
         split( /\t/, $rec2 );
      drawBentLine( $self, $x2, $y2, $x1, $y1 );
   }
}

############################################################################
# drawBentLine - Draw bent right angle lines.
############################################################################
sub drawBentLine {
    my( $self, $x1, $y1, $x2, $y2 ) = @_;

    my $im = $self->{ im };
    my $color = $self->{ color_black };

    my $im_x1 = img_x( $self, $x1 );
    my $im_x2 = img_x( $self, $x2 );
    my $im_y1 = img_y( $self, $y1 );
    my $im_y2 = img_y( $self, $y2 );

    if( $verbose >= 5 ) {
        webLog( "drawBentLine:org: ($x1,$y1)  ($x2,$y2)\n" );
        webLog( "drawBentLine:img: ($im_x1,$im_y1)  ($im_x2,$im_y2)\n" );
    }
    $im->line( $im_x1, $im_y1, $im_x1, $im_y2, $color );
    $im->line( $im_x1, $im_y2, $im_x2, $im_y2, $color );
}

############################################################################
# drawTreeDesc - Show the text description of the tree.
############################################################################
sub drawTreeDesc {
   my( $self ) = @_;

   my $recs = $self->{ recs };
   my @keys = sort( keys( %$recs ) );
   my $im = $self->{ im };

   for my $k( @keys ) {
      my $rec1 = $recs->{ $k };
      my( $id1, $parent1, $desc1, $highlight1, $x1, $y1, $isLeaf1, undef ) = 
           split( /\t/, $rec1 );
      next if $desc1 eq "";
      next if !$isLeaf1;

      my $im_x1 = img_x( $self, $x1 );
      my $im_y1 = img_y( $self, $y1 );
      my $im_x2 = $im_x1 + $self->{ leaf_line_width };
      my $im_y2 = $im_y1;
      $im->line( $im_x1, $im_y1, $im_x2, $im_y2, $self->{ color_black } );

      my $color = $self->{ color_blue };
      $color = $self->{ color_red } if $highlight1;
      $im->string( gdMediumBoldFont, 
         $im_x2 + 10, $im_y2 - 7, $desc1, $color );
   }
}

############################################################################
# drawTree - Wrapper function.
############################################################################
sub drawTree {
   my( $self, $outFile ) = @_;

   allocateImage( $self );
   drawTreeLines( $self );
   drawTreeDesc( $self );
   my $wfh = newWriteFileHandle( $outFile, "drawTree" );
   binmode $wfh;
   my $im = $self->{ im };
   print $wfh $im->png;
   close $wfh;
}

sub toPhyloXML {
    my( $self, $outFile ) = @_;
    my $root = $self->{ root };
    $root->setCoordinates();
    $root->toPhyloXML( $outFile );
}

############################################################################
# parse - Parse the newick string and return the node tree structure.
############################################################################
sub parse {
   my( $spec, $id2Rec_ref, $domainsRec_ref ) = @_;

   $spec =~ s/\s+/ /g;
   $spec =~ s/\(/ ( /g;
   $spec =~ s/\)/ ) /g;
   $spec =~ s/:/ : /g;
   $spec =~ s/,/ , /g;
   my @toks = split( / /, $spec );
   my $root = new DrawTreeNode( 0, "" );
   my $nodeCount = 1;
   my @toks2;
   for my $t( @toks ) {
       next if $t eq "";
       next if $t eq ",";
       push( @toks2, $t );
   }
   my $nToks2 = @toks2;
   my @stack;
   push( @stack, $root );
   my $lastTop;
   for( my $i = 0; $i < $nToks2; $i++ ) {
       my $t = $toks2[ $i ];
       last if $t eq ";";
       print "tok[$i] '$t'\n" if $verbose >= 5;
       my $stackSize = @stack;
       my $top = $stack[ $stackSize - 1 ];
       if( $t eq "(" ) {
	   my $id = "_n$nodeCount";
	   my $n = new DrawTreeNode( $id, "" );
	   push( @stack, $n );
	   $top->addNode( $n );
	   $nodeCount++;
       }
       elsif( $t eq ")" && $stackSize >= 1 ) {
	   $lastTop = pop( @stack );
	   my $t2 = $toks2[ $i + 1 ];
	   if( $t2 eq ":" ) {
	       my $t3 = $toks2[ $i + 2 ];
	       $lastTop->{ branchLength } = $t3
		   if defined( $lastTop );
	       $lastTop->{ distance } = $t3
		   if defined( $lastTop );
	       $i += 2;
	   }
       }
       elsif( $t =~ /^[0-9_a-zA-Z]+$/ ) {
	   my $id = $t;
	   my $desc = $id;
	   my $n = new DrawTreeNode( $id );
	   if( defined( $id2Rec_ref ) && keys( %$id2Rec_ref ) ) {
	       my( $desc, $highlight, $mouseover, $hyperlink ) = 
		   split( /\t/, $id2Rec_ref->{ $id } );
	       $n->{ desc } = $desc;
	       $n->{ mouseover } = $mouseover;
	       $n->{ hyperlink } = $hyperlink;
	       $n->{ highlight } = $highlight;
	   }
	   elsif( defined( $domainsRec_ref ) ) {
	       my( $gene_desc, $hyperlink, $sp, $tmh, $cog, $pfam, $tfam ) =
		   split( /\t/, $domainsRec_ref->{ $id } );
	       #my( $gene_desc, $hyperlink, $domains ) =
	       #split( /\t/, $domainsRec_ref->{ $id } );
	       webLog ("\nANNA2:$gene_desc\n  $hyperlink\n  $cog");
	       $n->{ desc } = $gene_desc;
	       $n->{ hyperlink } = $hyperlink;
	       $n->{ domains } = $sp."\t".$tmh."\t".$cog."\t".$pfam."\t".$tfam;
	   }
	   
	   $n->{ desc } = $n->{ id } if $n->{ desc } eq "";
	   $top->addNode( $n );
	   my $t2 = $toks2[ $i + 1 ];
	   if( $t2 eq ":" ) {
	       my $t3 = $toks2[ $i + 2 ];
	       $n->{ branchLength } = $t3;
	       $n->{ distance } = $t3;
	       $i += 2;
	   }
       }
   }
   return $root;
}

############################################################################
# drawToFile - Wrapper for DrawTree.
############################################################################
sub drawToFile {
    my( $self, $outFile ) = @_;

    my $root = $self->{ root };
    $root->setCoordinates( );

    my @recs;
    $root->getRecs( \@recs );
    for my $r( @recs ) {
	my( $id, $parentId, $desc, $highlight, $x, $y, 
	    $isLeaf, $mouseover, $hyperlink, $distance )
	    = split( /\t/, $r );
	$self->addRec( $id, $parentId, $desc, $highlight, $x, $y, $isLeaf, 
		       $mouseover, $hyperlink, $distance );
    }
    $self->drawTree( $outFile );
}

############################################################################
# drawAlignedToFile - Wrapper for DrawTree.
############################################################################
sub drawAlignedToFile { 
    my( $self, $outFile ) = @_;
 
    my $root = $self->{ root };
    my $idList = $self->{ idList };
    $root->setLeafNodeOrder( $idList );
    $root->setAlignCoordinates( );

    my @recs;
    $root->getRecs( \@recs );
    for my $r( @recs ) {
	my( $id, $parentId, $desc, $highlight, $x, $y,
	    $isLeaf, $mouseover, $hyperlink, $distance ) 
	    = split( /\t/, $r );
	$self->addRec( $id, $parentId, $desc, $highlight, $x, $y, $isLeaf, 
		       $mouseover, $hyperlink, $distance ); 
    } 
    $self->drawTree( $outFile ); 
} 

############################################################################
# getMap - Show map as string.
############################################################################
sub getMap {
    my( $self, $image_url, $border, $map_id ) = @_;

    my $recs = $self->{ recs };
    my $s;
    my $id = $map_id;
    $id = "drawTree$$" if $map_id eq "";
    $s .= "<image src='$image_url' usemap='#$id' border='$border' />\n";
    $s .= "<map name='$id'>\n";
    my @keys = sort( keys( %$recs ) );
 
    for my $k( @keys ) {
       my $r = $recs->{ $k };
       my( $id, $parentId, $desc, $highlight, $x, $y,
	   $isLeaf, $mouseover, $hyperlink, $distance )
	   = split( /\t/, $r );
       if (!$isLeaf) {
	   my $x1 = $self->img_x( $x ) - 5;
	   my $y1 = $self->img_y( $y ) - 5; 
	   my $x2 = $x1 + 10;
	   my $y2 = $y1 + 10; 
	   $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
	   $s .= "title='DISTANCE: $distance' "; 
	   $s .= " >\n"; 
       }

       next if !$isLeaf;
       my $descLen = length( $desc );
       my $x1 = $self->img_x( $x );
       my $y1 = $self->img_y( $y ) - 5;
       my $x2 = $self->img_x( $x + $self->{ max_desc_length } + 20 ); 
       #my $x2 = $self->img_x( $x + $descLen + 1000 );
       my $y2 = $y1 + 10;
       $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
       $s .= "href='$hyperlink' " if $hyperlink ne "";
       $s .= "title='$mouseover' " if $mouseover ne "";
       $s .= " >\n";
    }
    $s .= "</map>\n";
    return $s;
}

############################################################################
# getIds - returns the ordered list of ids
############################################################################
sub getIds {
    my( $self ) = @_;
    return $self->{ idList };
}

############################################################################
# loadGtrCdtFiles - Load .gtr and .cdt  files
#    generated by the "cluster" tool.
############################################################################
sub loadGtrCdtFiles {
   my( $self, $inGtrFile, $inCdtFile, $id2Rec_ref ) = @_;

   my $rfh = newReadFileHandle( $inCdtFile, "loadGtrCdtFile" );
   my $count = 0;
   my %gid2Name;
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       $count++;
       next if $count < 3;
       my( $geneIdx, $id, $name, undef ) = split( /\t/, $s );
       $gid2Name{ $geneIdx } = $name;
   }
   close $rfh;

   loadClusterFile($self, $inGtrFile, \%gid2Name, $id2Rec_ref);
}

############################################################################ 
# loadAtrCdtFiles - Load .atr and .cdt  files 
#    generated by the "cluster" tool. 
############################################################################ 
sub loadAtrCdtFiles { 
    my( $self, $inAtrFile, $inCdtFile, $id2Rec_ref ) = @_; 

    my $rfh = newReadFileHandle( $inCdtFile, "loadAtrCdtFile" ); 
    my $count = 0; 
    my @snames;
    my @sids;
    while( my $s = $rfh->getline() ) { 
	chomp $s; 
	$count++; 
	last if $count > 2; 

	if ($count == 1) {
	    @snames = split( /\t/, $s ); 
	}
	if ($count == 2) {
	    @sids = split( /\t/, $s ); 
	}
    } 
    my %id2Name; 
    my $size = scalar @snames;
    for (my $i = 4; $i < $size; $i++) {
	my $idx = $sids[$i];
	my $name = $snames[$i];
	$id2Name{ $idx } = $name; 
    }
    close $rfh; 

    # ordered list of sample ids:
    splice(@snames, 0, 4); # starts with the 4th element
    $self->{ idList } = \@snames;

    loadClusterFile($self, $inAtrFile, \%id2Name, $id2Rec_ref);
}

############################################################################
# loadClusterFile - Loads either the .gtr or .atr file
#    generated by the "cluster" tool.
############################################################################
sub loadClusterFile { 
    my( $self, $inFile, $id2Name_ref, $id2Rec_ref ) = @_;
 
    my $rfh = newReadFileHandle( $inFile, "loadClusterFile" ); 
    my $count = 0; 
    my %nodes; 
    my $lastParent; 
    while( my $s = $rfh->getline() ) { 
	chomp $s; 
	$count++; 
	my( $parent, $child1, $child2, $distance ) = split( /\t/, $s ); 

	## Parent 
	my $n = $nodes{ $parent }; 
	if( !defined( $n ) ) { 
	    my $n = new DrawTreeNode( $parent ); 
	    $nodes{ $parent } = $n; 
	    my $id = $id2Name_ref->{ $parent }; 
	    my $r = $id2Rec_ref->{ $id }; 
	    setNodeRec( $n, $r, $distance ); 
	    $lastParent = $n; 
	} 

	## Child1 
	my $n = $nodes{ $child1 }; 
	if( !defined( $n ) ) { 
	    my $n = new DrawTreeNode( $child1 ); 
	    $nodes{ $child1 } = $n; 
	    my $id = $id2Name_ref->{ $child1 }; 
	    my $r = $id2Rec_ref->{ $id }; 
	    setNodeRec( $n, $r, $distance ); 
	} 


	## Child2 
	my $n = $nodes{ $child2 }; 
	if( !defined( $n ) ) { 
	    my $n = new DrawTreeNode( $child2 ); 
	    $nodes{ $child2 } = $n; 
	    my $id = $id2Name_ref->{ $child2 }; 
	    my $r = $id2Rec_ref->{ $id }; 
	    setNodeRec( $n, $r, $distance ); 
	} 

	## Set tree relationship. 
	my $pn = $nodes{ $parent }; 
	my $c1 = $nodes{ $child1 }; 
	my $c2 = $nodes{ $child2 }; 
	$pn->addNode( $c1 ); 
	$pn->addNode( $c2 ); 
    } 
    close $rfh; 
    $self->{ root } = $lastParent; 
} 

############################################################################
# setNodeRec - Set node record. Utility routine.
############################################################################
sub setNodeRec {
    my( $n, $r, $distance ) = @_;

    my( $desc, $highlight, $mouseover, $hyperlink )
	= split( /\t/, $r );
    $n->{ desc } = $desc;
    $n->{ highlight } = $highlight;
    $n->{ mouseover } = $mouseover;
    $n->{ hyperlink } = $hyperlink;
    $n->{ distance }  = $distance if $distance ne "";
}


1;
