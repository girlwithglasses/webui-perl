############################################################################
# $Id: MetagGraphScatterPanel.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package MetagGraphScatterPanel;

use strict;
use Data::Dumper;
use GD;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use POSIX qw(ceil floor);

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};

#my $section_cgi = "$main_cgi?section=$section";
my $tmp_url     = $env->{tmp_url};
my $tmp_dir     = $env->{tmp_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $verbose     = $env->{verbose};

############################################################################
# new - Allocate a new instance.  See below for arguments stored in hash.
############################################################################
sub new {
    my ( $myType, $args ) = @_;
    my $self = {};
    bless( $self, $myType );

    $self->{scale}           = 0.25;
    $self->{has_frame}       = 0;
    $self->{x_width}         = 900;    # original 750
    $self->{y_height}        = 540;    # orig 440
    $self->{y_top_offset}    = 20;
    $self->{y_bottom_offset} = 20;
    $self->{x_left_offset}   = 20;

    $self->{coord_incr} = 100;
    $self->{tmp_dir}    = $tmp_dir;
    $self->{tmp_url}    = $tmp_url;
    $self->{size}       = "";
    $self->{id}         = $$;

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

    # Outlinks base url for gene.
    $self->{color_array_file} = $args->{color_array_file};

    # Color array file to color genes with index.
    $self->{tmp_dir} = $args->{tmp_dir} if $args->{tmp_dir} ne "";

    # tmp directory for output PNG images.
    $self->{tmp_url} = $args->{tmp_url} if $args->{tmp_url} ne "";

    $self->{x_width} = $args->{x_width} if $args->{x_width} ne "";

    $self->{y_height} = $args->{y_height} if $args->{y_height} ne "";

    # these are predefined x and y sizes, overrides x and y
    # large
    $self->{size} = $args->{size} if $args->{size} ne "";
    if ( $self->{size} eq "large" ) {
        $self->{x_width}  = 4096;
        $self->{y_height} = 2048;

        #$self->{end_coord} = $self->{end_coord} + $self->{coord_incr};
    }
    $self->{end_coord} = $self->{end_coord} + $self->{coord_incr};

    # Width of panel.
    my $coord_length = $self->{end_coord} - $self->{start_coord};
    if ( $coord_length == 0 ) {
        webError("There is no data to plot!");
    }

#webLog("TEST ========== $self->{end_coord} - $self->{start_coord} = $coord_length \n");
    $self->{scale} = $self->{x_width} / $coord_length if ( $coord_length != 0 );

    my $im = new GD::Image( $self->{x_width} + 2, $self->{y_height} + 2 );
    $self->{im} = $im;
    $self->colorAllocates();
    $self->setBrush();
    my @a;
    $self->{gene_map} = \@a;

    $im->string( gdSmallFont, 1, 0, $self->{title}, $self->{color_blue} );

    my $mid_yheight = $self->{y_height} - $self->{y_bottom_offset};
    $self->{mid_yheight} = $mid_yheight;

    # x-axis coord line
    $im->line( $self->{x_left_offset}, $mid_yheight, $self->{x_width},
               $mid_yheight,           $self->{color_black} );

    my $text_y = $mid_yheight + 2;

    # y axis size is 400 / 100 = % percentage value for each y point
    my $yloc =
      ( $self->{y_height} - $self->{y_top_offset} - $self->{y_bottom_offset} ) /
      100;

    # draw y coords lables
    for ( my $i = 0 ; $i < 100 ; $i += 10 ) {
        my $yloc2 = $mid_yheight - ( $i * $yloc );    # + $self->{y_top_offset};
        $im->string( gdTinyFont, 0, $yloc2, "$i", $self->{color_black} );
    }

   # 100% label
   #  $mid_yheight - ( 100 * $yloc ) + $self->{y_top_offset}
   # == $self->{y_height} - $self->{y_bottom_offset} - ($self->{y_height}
   # - $self->{y_top_offset} - $self->{y_bottom_offset}) + $self->{y_top_offset}
   # == $self->{y_top_offset}  + $self->{y_top_offset}
    my $yloc2 = $self->{y_top_offset};                #+ $self->{y_top_offset};
    $im->string( gdTinyFont, 0, $yloc2, "100", $self->{color_black} );

    # y-axis line
    $im->line( $self->{x_left_offset},
               $yloc2,
               $self->{x_left_offset},
               $self->{y_height} - $self->{y_bottom_offset},
               $self->{color_black} );

    # draw x coords
    for ( my $i = $self->{start_coord} ;
          $i <= $self->{end_coord} ;
          $i += $self->{coord_incr} )
    {
        my $x = $self->coord2x($i);
        $im->string( gdTinyFont, $x, $text_y, "$i", $self->{color_black} );
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
    $self->{color_red}   = $im->colorAllocate( 200, 0,   0 );

    #$self->{ color_green } = $im->colorAllocate( 0, 255, 0 );
    $self->{color_green}  = $im->colorAllocate( 0,   175, 0 );
    $self->{color_blue}   = $im->colorAllocate( 0,   0,   200 );
    $self->{color_purple} = $im->colorAllocate( 155, 48,  255 );
    $self->{color_yellow} = $im->colorAllocate( 255, 250, 205 );

    ## Allocate a battery of colors.
    my @a;
    $self->{color_array} = \@a;
    $self->loadColorArray();
    $im->transparent( $self->{color_white} );
    $im->interlaced('true');
}

sub getColorArray {
    my ($self) = @_;
    return $self->{color_array};
}

sub getGDImage {
    my ($self) = @_;
    return $self->{im};
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

sub addLine {
    my ( $self, $start, $end, $percent, $color, $gene_oid, $label ) = @_;

    my $im = $self->{im};

    my $mid_yheight = $self->{mid_yheight};

    my $yloc = $percent * (
         (
           $self->{y_height} - $self->{y_top_offset} - $self->{y_bottom_offset}
         ) / 100
    );

    my $y = ceil( $mid_yheight - $yloc );

    #webLog("y line location $y\n");

    my $x1       = $self->coord2x($start);
    my $x2       = $self->coord2x($end);
    my $gene_map = $self->{gene_map};

    if ( $self->{size} eq "large" ) {

        # ceil value on graph
        #$im->line( $x1, $y, $x2, $y, $color );
        #$im->line( $x1, $y + 5, $x2, $y + 5, $color );
        #$im->rectangle( $x1, $y, $x2, $y + 5, $color );
        $im->filledRectangle( $x1, $y, $x2, $y + 5, $color );

        # tool tip region
        my $y1 = $y - 5;
        my $y2 = $y + 10;
        $x1 = $x1 - 5;
        $x2 = $x2 + 5;
        push( @$gene_map,
                  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
                . "$label" );
    } else {

        # ceil value on graph
        $im->line( $x1, $y, $x2, $y, $color );

        # floor value on graph remember y drawing goes down the screen,
        # opposite of what the graph is showing y+ve goes up
        $im->line( $x1, $y + 1, $x2, $y + 1, $color );

        # tool tip region
        my $y1 = $y - 5;
        my $y2 = $y + 5;
        $x1 = $x1 - 5;
        $x2 = $x2 + 5;
        push( @$gene_map,
                  "$gene_oid\t" . "$x1\t" . "$y1\t" . "$x2\t" . "$y2\t"
                . "$label" );
    }
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

    # TODO add enough for x's 0 label to be off the y axis label
    my $offset = $self->{x_left_offset};
    if ( $strand eq "-" ) {
        return $x_width - $rel_x + $offset;
    } else {
        return $rel_x + $offset;
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
    my $gene_map           = $self->{gene_map};
    my $gene_page_base_url = $self->{gene_page_base_url};
    my $s                  = "<map name='$mapName'>\n";
    for my $r (@$gene_map) {
        my ( $gene_oid, $x1, $y1, $x2, $y2, $label ) =
          split( /\t/, $r );
        $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
        $s .= "href='$gene_page_base_url&gene_oid=$gene_oid' ";

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
    my ( $self, $tooltip, $uselib ) = @_;
    my $id = $self->{id};
    $self->printToFile( "$tmp_dir/ScaffoldPanel.$id.png",
                        "$tmp_dir/ScaffoldPanel.$id.map", );
    my $mapName = "ScaffoldPanel_$id";
    my $s       = "<img src='$tmp_url/ScaffoldPanel.$id.png' ";
    if ( $tooltip eq "true" ) {
        # enable mouseover cursor
        $s .= " usemap='#" . "$mapName'";
    }
    $s .= " border='0' />\n";
    if ( $tooltip eq "true" ) {
        $s .= $self->makeMapString($mapName, $uselib);
    }
    return $s;
}

1;

