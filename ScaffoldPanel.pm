############################################################################
# ScaffoldPanel - Scaffold panel.  This the main "graphic" component
#  for all the chromosome and gene neighborhood viewers, resued in
#  tandem in different ways.
#     --es 09/07/2004
#
# $Id: ScaffoldPanel.pm 33886 2015-08-04 00:24:01Z aireland $
############################################################################
package ScaffoldPanel;
use strict;
use warnings;

use Data::Dumper;
use GD;
use CGI qw( :standard );
use WebUtil;
use WebConfig;

my $section = "ScaffoldPanel";

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $tmp_url     = $env->{tmp_url};
my $tmp_dir     = $env->{tmp_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $verbose     = $env->{verbose};
my $img_edu     = $env->{img_edu};


############################################################################
# new - Allocate a new instance.  See below for arguments stored in hash.
############################################################################
sub new {
    my ( $myType, $args ) = @_;
    my $self = {};
    bless( $self, $myType );

    $self->{scale}      = 0.25;
    $self->{has_frame}  = 0;
    $self->{x_width}    = 750;
    $self->{y_height}   = 70;
    $self->{coord_incr} = 100;
    $self->{tmp_dir}    = $tmp_dir;
    $self->{tmp_url}    = $tmp_url;
    $self->{id}         = $$;
    $self->{offset}     = 0;

    ## ANNA: used when the scaffold is circular and the region
    #  contains the end-to-start boundry
    $self->{scf_seq_length} = 0;
    $self->{topology} = "linear";
    $self->{in_boundry} = 0;

    $self->{scf_seq_length} = $args->{scf_seq_length};
    $self->{topology} = $args->{topology};
    $self->{in_boundry} = $args->{in_boundry};

    $self->{tx_url} = $args->{tx_url};

    ##
    # Arguments
    #
    $self->{id} = $args->{id};

    # ID of panel. Used for tmp file.
    $self->{start_coord} = $args->{start_coord};

    # Start coordinate marking.
    $self->{end_coord} = $args->{end_coord};

    # End coordinate marking.
    $self->{strand} = $args->{strand};

    # '+' or '-' strand.
    $self->{coord_incr} = $args->{coord_incr};

    # Increment for coordinate axis display.
    $self->{title} = $args->{title};

    # Title for panel.
    $self->{gene_page_base_url} = $args->{gene_page_base_url};
    $self->{meta_gene_page_base_url} = $args->{meta_gene_page_base_url};
    $self->{mygene_page_base_url} = $args->{mygene_page_base_url};

    # Outlinks base url for gene.
    $self->{color_array_file} = $args->{color_array_file};

    # Color array file to color genes with index.
    $self->{tmp_dir} = $args->{tmp_dir} if $args->{tmp_dir} ne "";

    # tmp directory for output PNG images.
    $self->{tmp_url} = $args->{tmp_url} if $args->{tmp_url} ne "";

    # tmp URL corresponding to above tmp directory.
    $self->{x_width} = $args->{x_width} if $args->{x_width} ne "";

    # Width of panel.
    $self->{img} = $args->{img} if $args->{img} ne "";

    my $coord_length = $self->{end_coord} - $self->{start_coord};
    $self->{scale}    = $self->{x_width} / $coord_length;
    $self->{y_height} = 45 if $self->{title} eq "";

    my $im = new GD::Image( $self->{x_width} + 2, $self->{y_height} + 2 );
    $self->{im} = $im;
    $self->colorAllocates();
    $self->setBrush();

    my @a;
    $self->{gene_map} = \@a;
    my @a_mygene;
    $self->{mygene_map} = \@a_mygene;
    my @b;
    $self->{intergenic_map} = \@b;

    $im->string( gdSmallFont, 1, 0, $self->{title}, $self->{color_blue} );

    my $mid_yheight = $self->{y_height} * 0.5;
    $self->{mid_yheight} = $mid_yheight;
    $im->line( 0, $mid_yheight, $self->{x_width}, $mid_yheight,
               $self->{color_black} );
    my $text_y = 13;
    $text_y = 0 if $self->{title} eq "";

    if ( $self->{strand} eq "-" ) {
        for ( my $i = $self->{end_coord} - $self->{coord_incr} ;
              $i >= $self->{start_coord} ;
              $i -= $self->{coord_incr} )
        {
            my $x = $self->coord2x($i);
            $x -= 10 if $i > 1000;
            if (    $self->{in_boundry}
		    && $self->{topology} eq "circular" ) {
		my $ix = $i;
		if ($i > $self->{scf_seq_length} ) {
		    $ix = $i - $self->{scf_seq_length};
		} elsif ($i < 1) {
		    $ix = $i + $self->{scf_seq_length};
		}
		$im->string( gdTinyFont, $x, $text_y, "$ix",
			     $self->{color_black} );
            } else {
		$im->string( gdTinyFont, $x, $text_y, "$i",
			     $self->{color_black} );
	    }
        }
    } else {
        for ( my $i = $self->{start_coord} ;
              $i <= $self->{end_coord} - $self->{coord_incr} ;
              $i += $self->{coord_incr} )
        {
            my $x = $self->coord2x($i);
	    if (    $self->{in_boundry}
		 && $self->{topology} eq "circular" ) {
		my $ix = $i;
		if ($i > $self->{scf_seq_length} ) {
		    $ix = $i - $self->{scf_seq_length};
		} elsif ($i < 1) {
		    $ix = $i + $self->{scf_seq_length};
		}
		$im->string( gdTinyFont, $x, $text_y, "$ix",
			     $self->{color_black} );
	    } else {
		$im->string( gdTinyFont, $x, $text_y, "$i",
			     $self->{color_black} );
	    }
        }
    }

    return $self;
}

############################################################################
# colorAllocates - Allocate basic colors and other array colors.
############################################################################
sub colorAllocates {
    my ($self) = @_;

    my $maxColors = 100;

    my $im = $self->{im};
    $self->{color_white} = $im->colorAllocate( 255, 255, 255 );
    $self->{color_black} = $im->colorAllocate( 0,   0,   0 );
    $self->{color_red}   = $im->colorAllocate( 255, 0,   0 );

    $self->{color_turquoise} = $im->colorAllocate( 20, 170, 170 );
    $self->{color_green}  = $im->colorAllocate( 99,  204, 99 );
    $self->{color_blue}   = $im->colorAllocate( 0,   0,   255 );
    $self->{color_purple} = $im->colorAllocate( 155, 48,  255 );
    $self->{color_yellow} = $im->colorAllocate( 255, 250, 205 );
    $self->{color_cyan}   = $im->colorAllocate( 200, 255, 255 );

    $self->{color_pink} = $im->colorAllocate( 255, 225, 255 );

    $self->{color_light_purple} = $im->colorAllocate( 208, 161,  254 );

    ## Allocate a battery of colors.
    my @a;
    $self->{color_array} = \@a;
    $self->loadColorArray();
    $im->transparent( $self->{color_white} );
    $im->interlaced('true');
}

sub getIm {
    my ($self) = @_;
    my $im = $self->{im};
    return $im;
}

############################################################################
# loadColorArray - Allocate colors from RGB file specification.
############################################################################
sub loadColorArray {
    my ($self)           = @_;
    my $color_array_file = $self->{color_array_file};
    my $im               = $self->{im};
    my $color_array      = $self->{color_array};
    my $rfh = newReadFileHandle( $color_array_file, "loadColorArray", 1 );
    if ( !$rfh ) {
        webLog("loadColorArray: cannot read '$color_array_file'\n");
        return;
    }
    my $count = 0;

    # Scramble with hash.
    my %done;
    my @color_array;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if $s eq "";
        next if $s =~ /^#/;
        next if $s =~ /^\!/;
        $count++;
        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        $s =~ s/\s+/ /g;
        my ( $r, $g, $b, @junk ) = split( / /, $s );
        next if scalar(@junk) > 1;
        my $val = "$r,$g,$b";
        next if $done{$val} ne "";
        push( @color_array, $val );
        $done{$val} = 1;
    }
    close $rfh;

    #for my $k( keys( %colors ) ) {
    my $matchCount    = 0;
    my $misMatchCount = 0;
    for my $k (@color_array) {
        my ( $r, $g, $b ) = split( /,/, $k );
        my $color = $im->colorAllocate( $r, $g, $b );
        my ( $rx, $gx, $bx ) = $im->rgb($color);
        if ( $rx == 0 && $gx == 0 && $bx == 0 ) {
            webLog("loadColorArray:[$count] cannot allocated ($r,$g,$b)\n");
            next;
        }
        if ( $rx == $r || $gx == $g || $bx == $b ) {
            webLog "[$count] match for ($r,$g,$b)\n"
              if $verbose >= 5;
            $matchCount++;
        }
        if ( $rx != $r || $gx != $g || $bx != $b ) {
            webLog("[$count] mismatch($r,$g,$b)($rx,$gx,$bx)\n")
              if $verbose >= 5;
            $misMatchCount++;
            next;
        }
        push( @$color_array, $color );
    }
    webLog "color matchCount=$matchCount misMatchCount=$misMatchCount\n"
      if $misMatchCount > 0;
}

############################################################################
# setBrush - Set brush parameters.
############################################################################
sub setBrush {
    my ($self) = @_;

    my $im = $self->{im};
    my $brush = new GD::Image( 1, 1 );
    $brush->colorAllocate( 255, 255, 255 );    # white
    $brush->colorAllocate( 0,   0,   0 );      # black
    $brush->transparent( $self->{color_white} );
    $brush->filledRectangle( 0, 0, 1, 1, $self->{color_black} );
    $im->setBrush($brush);
    $self->{brush} = $brush;
}

sub addHorLine {
    my ( $self, $start_coord, $end_coord, $y_off_mid, $color ) = @_;

    my $im = $self->{im};
    my $mid_yheight = $self->{mid_yheight};
    my $x1          = $self->coord2x($start_coord);
    my $x2          = $self->coord2x($end_coord);

    my $y = $mid_yheight + $y_off_mid;

    $im->line( $x1 + 3, $y, $x2 - 3, $y, $color );
}

sub addVertLine {
    my ( $self, $xcoord, $y_off_mid, $color ) = @_;

    my $im = $self->{im};
    my $y = $self->{mid_yheight};
    my $x = $self->coord2x($xcoord);

    $im->dashedLine( $x + 3, $y, $x + 3, $y + $y_off_mid, $color );
}

############################################################################
# addGene - Add one gene to panel.
#  Inputs:
#     gene_oid - Gene object identifier
#     start_cood - Start coordinate
#     end_coord = End coordinate
#     strand - Strand ("+" or "-")
#     color - Color index to be used to show gene.
#     label - Text label for gene.
############################################################################
sub addGene {
    my ( $self, $gene_oid, $start_coord, $end_coord,
	 $strand, $color, $label ) = @_;

    my $gene_map = $self->{gene_map};

    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};
    my $arrow       = new GD::Polygon;
    my $ptrOffset   = 5;
    my $arrowHeight = 10;

    #my $arrowWidth = $self->coord2x( $end_coord - $start_coord );
    my $arrowWidth =
      abs( $self->coord2x($end_coord) - $self->coord2x($start_coord) );
    $arrowWidth = $ptrOffset if $arrowWidth < $ptrOffset;
    my $x_start_coord = $self->coord2x($start_coord);
    my $gap           = 3;

    my $gene_strand   = $strand;
    if ( $self->{strand} eq "-" ) {
        $gene_strand = $strand eq "+" ? "-" : "+";
    }
    ## Positive panel strand
    if ( $self->{strand} eq "+" ) {
        if ( $gene_strand eq "+" ) {
            $arrow->addPt( 0,                        0 );
            $arrow->addPt( $arrowWidth - $ptrOffset, 0 );
            $arrow->addPt( $arrowWidth,              $arrowHeight * 0.5 );
            $arrow->addPt( $arrowWidth - $ptrOffset, $arrowHeight );
            $arrow->addPt( 0,                        $arrowHeight );
            $arrow->offset( $x_start_coord,
                            $mid_yheight - $arrowHeight - $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight - $arrowHeight - $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        } else {
            $arrow->addPt( $ptrOffset,  0 );
            $arrow->addPt( $arrowWidth, 0 );
            $arrow->addPt( $arrowWidth, $arrowHeight );
            $arrow->addPt( $ptrOffset,  $arrowHeight );
            $arrow->addPt( 0,           $arrowHeight * 0.5 );
            $arrow->offset( $x_start_coord, $mid_yheight + $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight + $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        }
    }
    ## Negative panel strand
    else {
        $x_start_coord -= $arrowWidth;
        if ( $gene_strand eq "+" ) {
            $arrow->addPt( 0,                        0 );
            $arrow->addPt( $arrowWidth - $ptrOffset, 0 );
            $arrow->addPt( $arrowWidth,              $arrowHeight * 0.5 );
            $arrow->addPt( $arrowWidth - $ptrOffset, $arrowHeight );
            $arrow->addPt( 0,                        $arrowHeight );
            $arrow->offset( $x_start_coord,
                            $mid_yheight - $arrowHeight - $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight - $arrowHeight - $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        } else {
            $arrow->addPt( $ptrOffset,  0 );
            $arrow->addPt( $arrowWidth, 0 );
            $arrow->addPt( $arrowWidth, $arrowHeight );
            $arrow->addPt( $ptrOffset,  $arrowHeight );
            $arrow->addPt( 0,           $arrowHeight * 0.5 );
            $arrow->offset( $x_start_coord, $mid_yheight + $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight + $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        }
    }
    my $im = $self->{im};
    $im->filledPolygon( $arrow, $color );
    $im->polygon( $arrow, gdBrushed );

}

# same as addGene but its used to added my gene and its uses a different
# gene map array
# ken 2009-01-05
sub addMyGene {
    my ( $self, $gene_oid, $start_coord, $end_coord,
	 $strand, $color, $label ) = @_;

    my $mygene_map = $self->{mygene_map};

    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};
    my $arrow       = new GD::Polygon;
    my $ptrOffset   = 5;
    my $arrowHeight = 10;

    #my $arrowWidth = $self->coord2x( $end_coord - $start_coord );
    my $arrowWidth =
      abs( $self->coord2x($end_coord) - $self->coord2x($start_coord) );
    $arrowWidth = $ptrOffset if $arrowWidth < $ptrOffset;
    my $x_start_coord = $self->coord2x($start_coord);
    my $gap           = 3;
    my $gene_strand   = $strand;
    if ( $self->{strand} eq "-" ) {
        $gene_strand = $strand eq "+" ? "-" : "+";
    }
    ## Positive panel strand
    if ( $self->{strand} eq "+" ) {
        if ( $gene_strand eq "+" ) {
            $arrow->addPt( 0,                        0 );
            $arrow->addPt( $arrowWidth - $ptrOffset, 0 );
            $arrow->addPt( $arrowWidth,              $arrowHeight * 0.5 );
            $arrow->addPt( $arrowWidth - $ptrOffset, $arrowHeight );
            $arrow->addPt( 0,                        $arrowHeight );
            $arrow->offset( $x_start_coord,
                            $mid_yheight - $arrowHeight - $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight - $arrowHeight - $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$mygene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        } else {
            $arrow->addPt( $ptrOffset,  0 );
            $arrow->addPt( $arrowWidth, 0 );
            $arrow->addPt( $arrowWidth, $arrowHeight );
            $arrow->addPt( $ptrOffset,  $arrowHeight );
            $arrow->addPt( 0,           $arrowHeight * 0.5 );
            $arrow->offset( $x_start_coord, $mid_yheight + $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight + $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$mygene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        }
    }
    ## Negative panel strand
    else {
        $x_start_coord -= $arrowWidth;
        if ( $gene_strand eq "+" ) {
            $arrow->addPt( 0,                        0 );
            $arrow->addPt( $arrowWidth - $ptrOffset, 0 );
            $arrow->addPt( $arrowWidth,              $arrowHeight * 0.5 );
            $arrow->addPt( $arrowWidth - $ptrOffset, $arrowHeight );
            $arrow->addPt( 0,                        $arrowHeight );
            $arrow->offset( $x_start_coord,
                            $mid_yheight - $arrowHeight - $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight - $arrowHeight - $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$mygene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        } else {
            $arrow->addPt( $ptrOffset,  0 );
            $arrow->addPt( $arrowWidth, 0 );
            $arrow->addPt( $arrowWidth, $arrowHeight );
            $arrow->addPt( $ptrOffset,  $arrowHeight );
            $arrow->addPt( 0,           $arrowHeight * 0.5 );
            $arrow->offset( $x_start_coord, $mid_yheight + $gap );
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight + $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$mygene_map,
		  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
		. "$label" );
        }
    }
    my $im = $self->{im};
    $im->filledPolygon( $arrow, $color );

    my $b = $self->{color_black};

    # dashed outline for polygon
    $im->setStyle( $b, $b, $b, gdTransparent, gdTransparent );

    #$im->polygon( $arrow, gdBrushed );
    $im->polygon( $arrow, gdStyled );

}

############################################################################
# addPhantomGene - Add one phantom gene to panel.
#  (A different display so as not to clobber existing genes.)
#  Inputs:
#     gene_oid - Gene object identifier
#     start_cood - Start coordinate
#     end_coord = End coordinate
#     strand - Strand ("+" or "-")
############################################################################
sub addPhantomGene {
    my ( $self, $gene_oid, $start_coord, $end_coord, $strand ) = @_;

    my $gene_map  = $self->{gene_map};
    my $im        = $self->{im};
    my $color_red = $self->{color_red};
    my $label     = "Alignment $start_coord..$end_coord($strand)";

    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};
    my $arrow       = new GD::Polygon;
    my $ptrOffset   = 5;
    my $arrowHeight = 1;
    my $arrowWidth  =
      abs( $self->coord2x($end_coord) - $self->coord2x($start_coord) );
    $arrowWidth = $ptrOffset if $arrowWidth < $ptrOffset;
    my $x_start_coord = $self->coord2x($start_coord);
    my $gap           = 0;
    my $gene_strand   = $strand;

    if ( $self->{strand} eq "-" ) {
        $gene_strand = $strand eq "+" ? "-" : "+";
    }
    ## Positive panel strand
    if ( $self->{strand} eq "+" ) {
        if ( $gene_strand eq "+" ) {
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight - $arrowHeight - $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
                      "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
                    . "$label" );
            $im->line( $x1, $y1, $x2, $y1, $color_red );
        } else {
            my $x1 = $x_start_coord;
            my $y1 = $mid_yheight + $gap;
            my $x2 = $x1 + $arrowWidth;
            my $y2 = $y1 + $arrowHeight;
            push( @$gene_map,
                      "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
                    . "$label" );
            $im->line( $x1, $y2, $x2, $y2, $color_red );
        }
    }
}

sub addBox {
    my ( $self, $xstart, $xend, $color, $strand, $label, $gene_oid ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    my $x1;
    my $x2;
    my $h;

    my $y1;
    my $y2;

    if ( $self->{strand} eq "+" ) {
        # lets make the length of the box marking multiple func ids
        # and little smaller
        $x1 = $self->coord2x($xstart) + 2;
        $x2 = $self->coord2x($xend) - 2;
        $h  = 3;

        $y1 = $mid_yheight;
        $y2 = $mid_yheight;

        # draw the box such that is does not overlap with the gene
        # draw it on the otherside of the x-axis
        if ( $strand eq "+" ) {
            $y2 = $mid_yheight + $h;
        } else {
            $y1 = $mid_yheight - $h;
        }

    } else {
        # -ve panel so its reverse of the +ve panel
        $x1 = $self->coord2x($xstart) - 2;
        $x2 = $self->coord2x($xend) + 2;
        $h  = 3;

        $y1 = $mid_yheight;
        $y2 = $mid_yheight;

        if ( $strand eq "+" ) {
            $y2 = $mid_yheight - $h;
        } else {
            $y1 = $mid_yheight + $h;
        }

    }

    #    my $box = new GD::Polygon();
    #    $box->addPt( $x1, $y1 );
    #    $box->addPt( $x1, $y2 );
    #    $box->addPt( $x2, $y2 );
    #    $box->addPt( $x2, $y1 );

    #    $im->filledPolygon( $box, $color );
    #    $im->polygon( $box, gdBrushed );

    $im->filledRectangle( $x1, $y1, $x2, $y2, $color );

    my $gene_map = $self->{gene_map};
    push( @$gene_map,
          "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t" . "$label" );
}

sub addMyGeneBox {
    my ( $self, $xstart, $xend, $color, $strand, $label, $gene_oid ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    my $x1;
    my $x2;
    my $h;

    my $y1;
    my $y2;

    if ( $self->{strand} eq "+" ) {
        # lets make the length of the box marking multiple func ids
        # and little smaller
        $x1 = $self->coord2x($xstart) + 2;
        $x2 = $self->coord2x($xend) - 2;
        $h  = 3;

        $y1 = $mid_yheight;
        $y2 = $mid_yheight;

        # draw the box such that is does not overlap with the gene
        # draw it on the otherside of the x-axis
        if ( $strand eq "+" ) {
            $y2 = $mid_yheight + $h;
        } else {
            $y1 = $mid_yheight - $h;
        }

    } else {
        # -ve panel so its reverse of the +ve panel
        $x1 = $self->coord2x($xstart) - 2;
        $x2 = $self->coord2x($xend) + 2;
        $h  = 3;

        $y1 = $mid_yheight;
        $y2 = $mid_yheight;

        if ( $strand eq "+" ) {
            $y2 = $mid_yheight - $h;
        } else {
            $y1 = $mid_yheight + $h;
        }

    }

    #    my $box = new GD::Polygon();
    #    $box->addPt( $x1, $y1 );
    #    $box->addPt( $x1, $y2 );
    #    $box->addPt( $x2, $y2 );
    #    $box->addPt( $x2, $y1 );

    #    $im->filledPolygon( $box, $color );
    #    $im->polygon( $box, gdBrushed );

    $im->filledRectangle( $x1, $y1, $x2, $y2, $color );

    my $gene_map = $self->{mygene_map};
    push( @$gene_map,
          "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t" . "$label" );
}


############################################################################
# addBracket - Add brackets, mainly to show end of sequence or
#   masked out regions with N's and X's.
############################################################################
sub addBracket {
    my ( $self, $coord, $type ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};
    my $x           = $self->coord2x($coord);
    my $h           = 4;
    my $w           = 2;

    ## cosmetic offset to avoid clash with genes.
    my $offset = $w + 2;
    if ( $type eq "left" ) {
        $x -= $offset;
    }
    if ( $type eq "right" ) {
        $x += $offset;
    }
    my $y1 = $mid_yheight - $h;
    my $y2 = $mid_yheight + $h;
    $im->line( $x, $y1, $x, $y2, $self->{color_black} );
    if ( $type eq "left" ) {
        $im->line( $x + $w, $y1, $x, $y1, $self->{color_black} );
        $im->line( $x + $w, $y2, $x, $y2, $self->{color_black} );
    } elsif ( $type eq "right" ) {
        $im->line( $x - $w, $y1, $x, $y1, $self->{color_black} );
        $im->line( $x - $w, $y2, $x, $y2, $self->{color_black} );
    } else {
	# boundry
    }
}

############################################################################
# highlightRegion - used for highlighting alignments
############################################################################
sub highlightRegion {
    my ( $self, $start_coord, $end_coord, $color ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    my $h = 3;
    my $y1 = $mid_yheight - 22;
    my $y2 = $mid_yheight + 20;

    if ($color eq "") {
        $color = $self->{color_pink};
    }

    my $x1 = $self->coord2x($start_coord);
    my $x2 = $self->coord2x($end_coord);

    #$im->filledRectangle( $x1, $y1, $x2, $y2, $color );

    my $b = $self->{color_black};
    $im->setStyle( $b, $b, $b, gdTransparent, gdTransparent );
    $im->rectangle( $x1, $y1, $x2, $y2, gdStyled );
}

############################################################################
# addMethylations - Add dots in area where bases are methylated
############################################################################
sub addMethylations {
    my ( $self, $meth_coord, $strand ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    my $color = $self->{color_turquoise};
    my $x = $self->coord2x($meth_coord);
    my $y = $mid_yheight + 5;
    if ($strand eq "-") {
	$y = $mid_yheight - 5;
    }
    my $width = 2;
    my $height = 2;

    $im->arc($x, $y, $width, $height, 0, 360, $color);
    $im->fill($x, $y, $color);
}

############################################################################
# addNxBrackets - Add brackets for N and X regions. More specific
#  version to handle a pair of N's and X's.
############################################################################
sub addNxBrackets {
    my ( $self, $start_coord, $end_coord, $panelStrand ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    my $gap = 7;
    $gap *= -1 if $panelStrand eq "-";
    my $x1 = $self->coord2x($start_coord) + $gap;
    my $x2 = $self->coord2x($end_coord) - $gap;
    my $y  = $mid_yheight - 2;
    $im->line( $x1, $y, $x2, $y, $self->{color_blue} );
    my $bracket1 = "right";
    my $bracket2 = "left";
    if ( $panelStrand eq "-" ) {
        $bracket1 = "left";
        $bracket2 = "right";
    }
    $self->addBracket( $start_coord, $bracket1 );
    $self->addBracket( $end_coord,   $bracket2 );
}

############################################################################
# addCrispr - Add CRISPR annotation to genomic region.
#   CRISPR = Cluster of regularly interspaced palidromic repeats.
############################################################################
sub addCrispr {
    my ( $self, $start_coord, $end_coord, $panelStrand, $n_copies ) = @_;

    my $im          = $self->{im};
    my $scale       = $self->{scale};
    my $mid_yheight = $self->{mid_yheight};

    #my $y1 = $mid_yheight - 5;
    #my $y2 = $mid_yheight - 10;
    my $y1 = $mid_yheight - 5;
    my $y2 = $mid_yheight - 12;

    my $gap = 0;
    my $x1  = $self->coord2x($start_coord) + $gap;
    my $x2  = $self->coord2x($end_coord) - $gap;
    my $len = $x2 - $x1;

    #my $n = $n_copies / 5;
    #my $n = $n_copies / 2;

    #$incr = $len / $n if $n > 0;

    #my $x = $x1;
    #for( my $i = 0; $i < $n && $x <= $x2; $i++, $x += $incr ) {
    #   $im->line( $x, $y1, $x, $y2, $self->{ color_red } );
    #}
    my $incr = 3;
    for ( my $x = $x1 ; $x <= $x2 ; $x += $incr ) {
        $im->line( $x, $y1, $x, $y2, $self->{color_red} );
    }
}

############################################################################
# addIntergenic - Add intergenic region.
############################################################################
sub addIntergenic {
    my ( $self, $scaffold_oid, $start_coord, $end_coord, $panelStrand ) = @_;

    my $intergenic_map = $self->{intergenic_map};
    my $im             = $self->{im};
    my $scale          = $self->{scale};
    my $mid_yheight    = $self->{mid_yheight};
    my $y1             = $mid_yheight + 4;
    my $y2             = $mid_yheight - 4;

    my $gap = 0;
    my $x1  = $self->coord2x($start_coord) + $gap;
    my $x2  = $self->coord2x($end_coord) - $gap;
#    my $len = $x2 - $x1;

    #my $n = $n_copies / 5;
    #my $n = $n_copies / 2;
    my $incr = 5;

    #$incr = $len / $n if $n > 0;

    #my $incr = 3;
    #for( my $x = $x1; $x <= $x2; $x += $incr ) {
    #   $im->line( $x, $y1, $x, $y2, $self->{ color_green } );
    #}
    my $len = $end_coord - $start_coord + 1;
    push( @$intergenic_map,
              "$scaffold_oid\t"
            . "$start_coord\t"
            . "$end_coord\t" . "$x1\t" . "$x2\t" . "$y1\t" . "$y2\t"
            . "intergenic-region $start_coord..$end_coord (${len}bp)" );
}

############################################################################
# coord2x - Convert DNA coord to x value.
############################################################################
sub coord2x {
    my ( $self, $coord ) = @_;
    my $scale       = $self->{scale};
    my $strand      = $self->{strand};
    my $x_width     = $self->{x_width};
    my $start_coord = $self->{start_coord};
    my $end_coord   = $self->{end_coord};

    if (    $self->{in_boundry}
         && $self->{topology} eq "circular" ) {
	my $scf_seq_length = $self->{scf_seq_length};
	my $start_coord2 = $start_coord;
	#my $end_coord2 = $end_coord;

	my $rel_x = ( $coord - $start_coord ) * $scale;
	if ($start_coord < 1) {
	    $start_coord2 = $start_coord + $scf_seq_length;
	    $rel_x = ( $coord - $start_coord2 ) * $scale;
	    if ($coord < $start_coord2) {
		$rel_x = ( $coord - $start_coord ) * $scale;
	    }
	}
	if ($end_coord > $scf_seq_length
	    && $coord < $start_coord ) {
	    #$end_coord2 = $end_coord - $scf_seq_length;
	    $rel_x = ( $coord + $scf_seq_length - $start_coord ) * $scale;
	}

	my $offset = $self->{offset};
	if ( $strand eq "-" ) {
	    return $x_width - $rel_x + $offset;
	} else {
	    return $rel_x + $offset;
	}

    } else {
	if ( $coord < $start_coord ) {
	    webLog("coord2x: setting coord=$coord to start=$start_coord\n")
		if $verbose >= 2;
	    $coord = $start_coord;
	}
	if ( $coord > $end_coord ) {
	    webLog("coord2x: setting coord=$coord to end=$end_coord\n")
		if $verbose >= 2;
	    $coord = $end_coord;
	}
	my $rel_x = ( $coord - $start_coord ) * $scale;
	webLog("coord2x: coord=$coord < start_coord=$start_coord\n")
	    if $start_coord > $coord;

	my $offset = $self->{offset};
	if ( $strand eq "-" ) {
	    return $x_width - $rel_x + $offset;
	} else {
	    return $rel_x + $offset;
	}
    }
}

############################################################################
# print - Print out image to file for file handle.
############################################################################
sub print {
    my ( $self, $fh ) = @_;
    my $im = $self->{im};
    binmode $fh;
    print $fh $im->png;
}

############################################################################
# printToFile - Wrapper for print to file using file name.
############################################################################
sub printToFile {
    my ( $self, $imageFile ) = @_;
    wunlink($imageFile);
    my $im = $self->{im};
    my $wfh = newWriteFileHandle( $imageFile, "printToFile" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;
}

############################################################################
# makeMapString - Make map string for clickable regions on file.
############################################################################
sub makeMapString {
    my ( $self, $mapName, $uselib ) = @_;
    my $gene_map             = $self->{gene_map};
    my $mygene_map           = $self->{mygene_map};
    my $intergenic_map       = $self->{intergenic_map};
    my $gene_page_base_url   = $self->{gene_page_base_url};
    my $meta_gene_page_base_url   = $self->{meta_gene_page_base_url};
    my $mygene_page_base_url = $self->{mygene_page_base_url};
    my $s                    = "<map name='$mapName'>\n";

    my $show_checkbox = param("show_checkbox");
    if ($show_checkbox eq "") {
        $show_checkbox = 0;
    }

    # link out to genome page from scaffold header:
    my $txurl = $self->{tx_url};
    my $title = $self->{title};
    my $len = length($title) * 6;
    if ($txurl ne "") {
	$s .= "<area shape='rect' style='cursor:pointer; cursor:hand;' "
	    . " coords='1,0,$len,15' href='$txurl' />";
    }

    for my $r (@$gene_map) {
        my ( $gene_oid, $x1, $y1, $x2, $y2, $label ) =
          split( /\t/, $r );
        $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' "
	    . "style='cursor:pointer; cursor:hand;' ";

        if ( $self->{img} eq "ACT" && $img_edu ) {
            # do nothing for now
        } else {
            if ($show_checkbox) {
	      if ( isInt($gene_oid) ) {
		  # cannot have a link to gene details in href here
		  # this depends on whether user wants to link to gene page
		  # or is using click to slect genes into cart
		  #$s .= "href='$gene_page_base_url&gene_oid=$gene_oid' ";
	      }
	      else {
		  my @vals = split(/ /, $gene_oid);
		  $gene_oid = $vals[-1];
		  $s .= "href='$meta_gene_page_base_url&gene_oid=$gene_oid' ";
	      }

            } else {
              if ( isInt($gene_oid) ) {
		  $s .= "href='$gene_page_base_url&gene_oid=$gene_oid' ";
	      } elsif ( $meta_gene_page_base_url ) {
		  my @vals = split(/ /, $gene_oid);
		  $gene_oid = $vals[-1];
		  $s .= "href='$meta_gene_page_base_url&gene_oid=$gene_oid' ";
	      } else {
		  $s .= "href='#' ";
	      }
            }
        }

        my $twidth = length($label) * .05;
        my $x      = "WIDTH=$twidth; FONTSIZE='8px'";
        $label =~ s/'/ /g;
        my $label_esc = escHtml($label);

        if ( $uselib eq "overlib" ) {
            $s .= "onMouseOver=\"return overlib('$label_esc')\" ";
            $s .= "onMouseOut=\"return nd()\" ";
        } else {
            $s .= "onMouseOver=\"$x; Tip('$label_esc');\" ";
            $s .= "onMouseOut=\"UnTip();\" ";
        }
        if ($show_checkbox) {
            $s .= "onclick='addMyGeneCart(\"$gene_oid\")' ";
        }
        $s .= " />\n";
    }

    for my $r (@$mygene_map) {
        my ( $gene_oid, $x1, $y1, $x2, $y2, $label ) =
          split( /\t/, $r );

        $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
        if ( isInt($gene_oid) ) {
            $s .= "href='$mygene_page_base_url&gene_oid=$gene_oid' ";
        } else {
            $s .= "href='#' ";
        }
        my $twidth = length($label) * .05;
        my $x      = "WIDTH=$twidth; FONTSIZE='8px'";
        $label =~ s/'/ /g;
        my $label_esc = escHtml($label);
        if ( $uselib eq "overlib" ) {
            $s .= "onMouseOver=\"return overlib('$label_esc')\" ";
            $s .= "onMouseOut=\"return nd()\" ";
        } else {
            $s .= "onMouseOver=\"$x; Tip('$label_esc');\" ";
            $s .= "onMouseOut=\"UnTip();\" ";
        }
        $s .= " />\n";
    }

    for my $r (@$intergenic_map) {
        my ( $scaffold_oid, $start_coord, $end_coord, $x1, $x2, $y1, $y2,
             $label )
          = split( /\t/, $r );
        $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";

        if ( $self->{img} eq "ACT" && $img_edu ) {
        } else {
            if ( isInt($scaffold_oid) ) {
                my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldDna";
                $url .= "&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=$start_coord";
                $url .= "&end_coord=$end_coord";
                $s   .= "href='$url' ";
            } else {
                #$s .= "nohref='nohref' ";
                $s .= "href='#' ";
            }
        }
        my $twidth = length($label) * .05;
        my $x      = "WIDTH=$twidth; FONTSIZE='8px'";
        $label =~ s/'/ /g;
        my $label_esc = escHtml($label);
        if ( $uselib eq "overlib" ) {
            $s .= "onMouseOver=\"return overlib('$label_esc')\" ";
            $s .= "onMouseOut=\"return nd()\" ";
        } else {
            $s .= "onMouseOver=\"$x; Tip('$label_esc');\" ";
            $s .= "onMouseOut=\"UnTip();\" ";
        }
        $s .= " />\n";
    }

    $s .= "</map>\n";
    return $s;
}

############################################################################
# getMapHtml - Return html to output for mapping.
############################################################################
sub getMapHtml {
    my ( $self, $uselib ) = @_;
    my $id = $self->{id};
    $self->printToFile( "$tmp_dir/ScaffoldPanel.$id.png",
                        "$tmp_dir/ScaffoldPanel.$id.map", );
    my $mapName = "ScaffoldPanel_$id";
    my $s       = "<img src='$tmp_url/ScaffoldPanel.$id.png' ";
    $s .= " usemap='#" . "$mapName'";
    $s .= " border='0' />\n";
    $s .= $self->makeMapString( $mapName, $uselib );
    return $s;
}

1;

