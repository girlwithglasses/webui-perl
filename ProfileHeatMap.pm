############################################################################
# ProfileHeatMap.pm - Generate heat map drawing module for profiles.
#    --es 10/02/2005
# $Id: ProfileHeatMap.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package ProfileHeatMap;
my $section = "ProfileHeatMap";
use strict;
use Data::Dumper;
use WebUtil;
use WebConfig;
use GD;
use CGI qw( :standard );

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $verbose     = $env->{verbose};
my $tmp_url     = $env->{tmp_url};
my $tmp_dir     = $env->{tmp_dir};

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my ( $myType, $args ) = @_;
    my $self = {};
    bless( $self, $myType );

    $self->{scale}       = 0.25;
    $self->{n_rows}      = 10;
    $self->{n_cols}      = 500;
    $self->{cell_width}  = 10;
    $self->{cell_height} = $self->{cell_width};
    $self->{text_width}  = 70;
    $self->{tmp_dir}     = "$tmp_dir";
    $self->{max_desc_length} = 60;

    ###
    # Arguments
    #
    $self->{id} = $args->{id};

    # ID of panel. Used for tmp file and area map name.
    $self->{n_rows}       = $args->{n_rows};
    $self->{n_cols}       = $args->{n_cols};
    $self->{image_file}   = $args->{image_file};
    $self->{data}         = $args->{data};
    $self->{x_width}      = $self->{cell_width} * $self->{n_cols};
    $self->{x_width_ext}  = $self->{x_width} + $self->{text_width};
    $self->{y_height}     = $self->{cell_height} * $self->{n_rows} 
                          + $self->{max_desc_length};
    $self->{y_height_ext} = $self->{y_height} + $self->{cell_height};
    $self->{taxon_aref}   = $args->{taxon_aref};
    $self->{use_colors}   = $args->{use_colors};

    $self->{y_labels}      = $args->{y_labels}; # up,down,both
    $self->{y_label_chars} = $args->{y_label_chars};

    my %allColors; 
    $self->{colors} = \%allColors;

    my $im = new GD::Image( $self->{x_width_ext}, $self->{y_height_ext} );
    $self->{im} = $im;
    $self->colorAllocates();
    $self->setBrush();
    return $self;
}

############################################################################
# colorAllocates - Allocate basic colors and other array colors.
############################################################################
sub colorAllocates {
    my ($self) = @_;

    my $im = $self->{im};

    $self->{color_white} = $im->colorAllocate( 255, 255, 255 );
    $self->{color_black} = $im->colorAllocate( 0,   0,   0 );
    $self->{color_gray} = $im->colorAllocate( 150, 150, 150 );

    my $allColors = $self->{ colors };
    my $use_colors = $self->{use_colors};
    if ($use_colors eq "all") {
	for ( my $i = 3; $i <= 255; $i++ ) {
	    my $key1 = "0-".$i."-0";
	    $allColors->{ $key1 } = $im->colorAllocate(0, $i, 0); 
	    my $key2 = $i."-0-0"; 
	    $allColors->{ $key2 } = $im->colorAllocate($i, 0, 0); 
	    $i++;
	} 
        $allColors->{ "0-1-0" } = $allColors->{ "0-3-0" };
        $allColors->{ "1-0-0" } = $allColors->{ "3-0-0" };
	$allColors->{ "0-255-0" } = $allColors->{ "0-253-0" };
	$allColors->{ "255-0-0" } = $allColors->{ "253-0-0" }; 
    }

    $self->{color_red}   = $im->colorAllocate( 255, 0,   0 );

    my @a;
    push( @a, $im->colorAllocate( 0, 0, 100 ) );    # 0 - 5%
    push( @a, $im->colorAllocate( 0, 0, 150 ) );    # 5 - 10%

    push( @a, $im->colorAllocate( 0, 0, 200 ) );    # 11 - 15%
    push( @a, $im->colorAllocate( 0, 0, 230 ) );    # 16 - 20%

    push( @a, $im->colorAllocate( 0, 0, 240 ) );    # 21 - 25%
    push( @a, $im->colorAllocate( 0, 0, 255 ) );    # 26 - 30%

    push( @a, $im->colorAllocate( 60, 160, 144 ) ); # 31 - 35%
    push( @a, $im->colorAllocate( 80, 200, 144 ) ); # 36 - 40%

    push( @a, $im->colorAllocate( 124, 218, 144 ) );    # 41 - 45%
    push( @a, $im->colorAllocate( 144, 238, 144 ) );    # 46 - 50%

    push( @a, $im->colorAllocate( 144, 255, 144 ) );    # 51 - 55%
    push( @a, $im->colorAllocate( 200, 255, 50 ) );     # 56 - 60%

    push( @a, $im->colorAllocate( 220, 200, 0 ) );      # 61 - 65%
    push( @a, $im->colorAllocate( 238, 158, 0 ) );      # 66 - 70%

    push( @a, $im->colorAllocate( 238, 158, 158 ) );    # 71 - 75%
    push( @a, $im->colorAllocate( 240, 100, 100 ) );    # 76 - 80%

    push( @a, $im->colorAllocate( 255, 70, 70 ) );      # 81 - 85%
    push( @a, $im->colorAllocate( 255, 50, 50 ) );      # 86 - 90%

    push( @a, $im->colorAllocate( 255, 30, 30 ) );      # 91 - 95%
    push( @a, $im->colorAllocate( 255, 20, 20 ) );      # 95 - 100%

    push( @a, $im->colorAllocate( 255, 10, 10 ) );      # > 100% ?
    push( @a, $im->colorAllocate( 255, 0,  0 ) );       # > 100% ?

    $self->{color_array} = \@a;

    $im->transparent( $self->{color_white} );
    $im->interlaced('true');
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

############################################################################
# printToFile - Wrapper for print to file using file name.
############################################################################
sub printToFile {
    my ($self)     = @_;
    my $im         = $self->{im};
    my $image_file = $self->{image_file};
    my $wfh = newWriteFileHandle( $image_file, "printToFile" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;
}

############################################################################ 
# drawSpecial - draw the Heat Map
############################################################################ 
sub drawSpecial { 
    my ( $self,          $origTable_ref, $rowLabels_ref, 
         $colOids_ref,   $rowDict_ref,   $colDict_ref, 
         $normTable_ref, $stateFile,     $show_names ) = @_; 
 
    my $im          = $self->{im}; 
    my $id          = $self->{id}; 
    my $n_rows      = $self->{n_rows}; 
    my $n_cols      = $self->{n_cols}; 
    my $cell_width  = $self->{cell_width}; 
    my $cell_height = $self->{cell_height}; 
    my $color_array = $self->{color_array}; 
    my $image_file  = $self->{image_file}; 
    my $fname       = lastPathTok($image_file); 
    my $image_url   = "$tmp_url/$fname"; 
    my $colors      = $self->{ colors };

    my $y_label_chars = $self->{ y_label_chars };
    my $fontwidth = gdTinyFont->width;
    my $upmargin = ($y_label_chars) * ($fontwidth);
    $upmargin = 0 if $upmargin eq "";

    my $md0; 
    $md0 .= "<image src='$image_url' usemap='#$id' border='0' />\n"; 
    $md0 .= "<map name='$id'>\n";
    my $md2; 
    my @md2Lines; 

    for ( my $i = 0; $i < $n_rows; $i++ ) {
        my $id      = $rowLabels_ref->[$i];
        my $row     = $normTable_ref->{ $id };
        my @rowVals = split( /\t/, $row );

	my $origRow = $origTable_ref->{ $id };
	my @origRowVals = split( /\t/, $origRow );

	$n_cols = scalar @rowVals;
	$self->{n_cols} = $n_cols;
        for ( my $j = 0; $j < $n_cols; $j++ ) { 
	    # Note: $origTable_ref contains the original values
	    #       $normTable_ref contains normalized values

            my $col_oid = $colOids_ref->[$j];
            my $perc    = $rowVals[$j];

            #if ( $perc < -1.0000000 || $perc > 1.0000000 ) { 
            #    webDie("draw: invalid perc=$perc\n");
            #} 

            my $cidx  = int( $perc * 20 );
            my $color = $color_array->[$cidx];

	    my $use_colors = $self->{use_colors};
	    if ($use_colors eq "all") {
		my $ff0;
		if ( $perc < 0.00 ) {
		    $ff0 = -1 * $perc;
		} else {
		    $ff0 = $perc;
		}
		if ($ff0 > 1.0000000) { # should not really happen ...
		    $ff0 = 1.0;
		}
		my $ff1 = 1.0 - $ff0;
		my ($r, $g, $b);
		if ($perc < 0.00) {
		    $r = 0;
		    $g = int(255*$ff0 + 1*$ff1);
		    $b = 0;
		} else {
		    $r = int(255*$ff0 + 1*$ff1);
		    $g = 0;
		    $b = 0;
		}

		my $key = $r."-".$g."-".$b;
		$color = $colors->{ $key };
		if (!defined($colors->{$key}) ||
		    $color eq "" || $color == -1) {

		    if ($perc < 0.00) {
			$g = $g + 1;
		    } else {
			$r = $r + 1;
		    }
		    $key = $r."-".$g."-".$b;
		    $color = $colors->{ $key };
		}
		if ($perc eq "" || $perc eq "undef") {
		    $color = $self->{color_gray};
		}
	    }
            my $x1 = $j * $cell_width;
            my $y1 = ( $i * $cell_height ) + $cell_height + 5 + $upmargin;
            my $x2 = $x1 + $cell_width; 
            my $y2 = $y1 + $cell_height; 
            $im->filledRectangle( $x1, $y1, $x2, $y2, $color ); 
            my $cnt = $rowVals[$j];
            $cnt = "undef" if $cnt eq ""; 
            my $cnt2 = $origRowVals[$j];
            $cnt2 = "undef" if $cnt2 eq ""; 
 
            $md2 = "<area shape='rect' coords='$x1,$y1,$x2,$y2' "; 
            push( @md2Lines, $md2 ); 
            $md2 = "title='$cnt ($cnt2) [$id:$col_oid]' />\n"; 
	    push( @md2Lines, $md2 );
        } 
    } 

    $md2 = join( "\n", @md2Lines ); 
    my $mapData = drawLabelsSpecial( $self,        $rowLabels_ref,
				     $colOids_ref, $rowDict_ref,
				     $colDict_ref, $stateFile, 
				     $show_names ); 
    return $md0 . $mapData . "$md2</map>\n";
} 

############################################################################
# drawLabelsSpecial - Draw labels on the right
############################################################################
sub drawLabelsSpecial { 
    my ( $self, $rowLabels_ref, $colOids_ref, 
	 $rowDict_ref, $colDict_ref, $stateFile, $show_names ) = @_; 
 
    my $im          = $self->{im};
    my $id          = $self->{id};
    my $x_width     = $self->{x_width};
    my $cell_width  = $self->{cell_width};
    my $cell_height = $self->{cell_height};
    my $n_rows      = $self->{n_rows};
    my $n_cols      = $self->{n_cols};
    my $image_file  = $self->{image_file};
    my $text_width  = $self->{text_width};

    my $y_label_chars = $self->{ y_label_chars };
    my $y_labels  = $self->{ y_labels };
    $y_labels     = "down" if $y_labels eq "";

    my $fontwidth = gdTinyFont->width;
    my $upmargin  = ($y_label_chars) * ($fontwidth);
    $upmargin     = 0 if $upmargin eq "";

    my $md;    # mapData 
 
    ## column labels 
    my $y = $n_rows * $cell_height; 

    my $lb_length = 0;
    for ( my $i = 0; $i < $n_cols; $i++ ) {
        my $col_oid = $colOids_ref->[$i];
	my $lbl = length($col_oid);
	$lb_length = $lbl if $lbl > $lb_length;
    }

    for ( my $i = 0; $i < $n_cols; $i++ ) {
        my $x = ( $i * $cell_width ) + 2;
        my $col_oid = $colOids_ref->[$i];
        my @items = split( /\t/, $colDict_ref->{$col_oid} );
        my $title = $items[0];
	my $url1  = $items[1];
        $title =~ s/'/ /g; 

        my $x1 = $x - 2; 
        my $x2 = $x1 + $cell_width;

	# labels on bottom of image:
	if ($y_labels eq "both" || $y_labels eq "down") {
	    my $label_length = $upmargin;
	    $label_length = ($lb_length) * ($fontwidth) if $upmargin == 0;
	    
	    my $y2 = $y + $cell_height + 5 + $upmargin;
	    my $y1 = $y2 + $label_length;
	    $im->stringUp(gdTinyFont, $x, $y1, $col_oid, $self->{color_black});
	    $md .= "<area shape='rect' coords='$x1,$y2,$x2,$y1' ";
	    $md .= "href='$url1' target='_blank' title='$col_oid - $title' />";
	}

	# label on top of image:
	if ($y_labels eq "both" || $y_labels eq "up") {
	    my $y3 = 0;
	    my $y4 = $upmargin + $cell_height;
	    $im->stringUp(gdTinyFont, $x, $y4, $col_oid, $self->{color_black});
	    $md .= "<area shape='rect' coords='$x1,$y3,$x2,$y4' ";
	    $md .= "href='$url1' target='_blank' title='$col_oid - $title' />";
	}
    } 

    ## row labels
    for ( my $i = 0 ; $i < $n_rows ; $i++ ) {
        my $x1 = $n_cols*$cell_width+2;
        my $y1 = ( $i * $cell_height ) + $cell_height + 5 + $upmargin;
        my $label = $rowLabels_ref->[$i]; 
        my $color = $self->{color_black};

        my $x2 = $x1 + $text_width; 
        my $y2 = $y1 + $cell_height; 

        my @items = split( /\t/, $rowDict_ref->{$label} );
        my $desc = $items[0];
        my $url2 = $items[1];
        my $str_length = length($desc);

        if ($show_names eq "1" && $str_length < 25) {
            $im->string( gdTinyFont, $x1, $y1, $desc, $color );
        } else {
            $im->string( gdTinyFont, $x1, $y1, $label, $color );
        }

        my $title = "$label - $desc"; 
        $title =~ s/'/ /g; 
        $md .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
        $md .= "href='$url2' target='_blank' title='$title' />\n"; 
    } 
 
    return $md; 
} 

############################################################################
# draw - Draw items.
############################################################################
sub draw {
    my (
         $self,          $data_ref,         $rowLabels_ref,
         $taxonOids_ref, $rowDict_ref,      $colDict_ref,
         $table_ref,     $clusterMatchText, $stateFile, 
         $func_type,     $data_type
      )
      = @_;

    my $im          = $self->{im};
    my $id          = $self->{id};
    my $n_rows      = $self->{n_rows};
    my $n_cols      = $self->{n_cols};
    my $cell_width  = $self->{cell_width};
    my $cell_height = $self->{cell_height};
    my $color_array = $self->{color_array};
    my $image_file  = $self->{image_file};
    my $fname       = lastPathTok($image_file);
    my $image_url   = "$tmp_url/$fname";
    my $md0;
    $md0 .= "<image src='$image_url' usemap='#$id' border='0' />\n";
    $md0 .= "<map name='$id'>\n";

    my $nVals = @$data_ref;
    my $idx   = 0;
    my $md2;
    my @md2Lines;
    for ( my $i = 0; $i < $n_rows; $i++ ) {
        my $id      = $rowLabels_ref->[$i];
        my $row     = $table_ref->{$id};
        my @rowVals = split( /\t/, $row );
        for ( my $j = 0; $j < $n_cols; $j++ ) {
            my $idx = ( $i * $n_cols ) + $j;
            if ( $idx >= $nVals ) {
                webDie("draw: invalid idx='$idx' [$i,$j] nVals=$nVals\n");
            }
            my $taxon_oid = $taxonOids_ref->[$j];
            my $perc      = $data_ref->[$idx];
            if ( $perc < 0 || $perc > 1.00 ) {
                webDie("draw: invalid idx='$idx' [$i,$j] invalid perc=$perc\n");
            }
            my $cidx  = int( $perc * 20 );
            my $color = $color_array->[$cidx];
            my $x1    = $j * $cell_width;
            my $y1    = ( $i * $cell_height ) + $cell_height;
            my $x2    = $x1 + $cell_width;
            my $y2    = $y1 + $cell_height;
            $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
            my $cnt = $rowVals[$j];
            $cnt = 0 if $cnt eq "";
            my $url =
                "$main_cgi?section=AbundanceProfiles"
              . "&page=abGl&id=$id&function=$func_type"
              . "&tid=$taxon_oid&data_type=$data_type";
            my $href;
            $href = "href='$url'" if $cnt > 0;

            if ( $cnt == 0 && param("cluster") eq "enzyme" ) {
                # TODO - missing enzyme v2.9 - ken
                my $taxon_aref = $self->{taxon_aref};
                my @othertoids;
                for my $t (@$taxon_aref) {
                    next if ( $t eq $taxon_oid );
                    push( @othertoids, $t );
                }
                my $otherTaxonOids = join( ",", @othertoids );

                my $url =
                    "main.cgi?section=MissingGenes&page=candidatesForm"
                  . "&taxon_oid=$taxon_oid"
                  . "&funcId=$id"
                  . "&otherTaxonOids=$otherTaxonOids";

                $href = "href='$url'";
            }
            $md2 = "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
            push( @md2Lines, $md2 );
            $md2 = "$href title='$cnt' />\n";
            push( @md2Lines, $md2 );
        }
    }
    $md2 = join( "\n", @md2Lines );
    my $mapData = drawLabels(
          $self,          $rowLabels_ref,
          $taxonOids_ref, $rowDict_ref,
          $colDict_ref,   $clusterMatchText,
          $stateFile
    );
    return $md0 . $mapData . "$md2</map>\n";
}

############################################################################
# drawLabels - Draw labels on right.
############################################################################
sub drawLabels {
    my ( $self, $rowLabels_ref, $taxonOids_ref, $rowDict_ref, $colDict_ref,
         $clusterMatchText, $stateFile )
      = @_;

    my $im          = $self->{im};
    my $id          = $self->{id};
    my $x_width     = $self->{x_width};
    my $cell_width  = $self->{cell_width};
    my $cell_height = $self->{cell_height};
    my $n_rows      = $self->{n_rows};
    my $n_cols      = $self->{n_cols};
    my $image_file  = $self->{image_file};
    my $text_width  = $self->{text_width};

    my $md;    # mapData

    ## column labels
    for ( my $i = 0; $i < $n_cols; $i++ ) {
        my $x     = ( $i * $cell_width ) + 2;
        my $y     = 0;
        my $label = $i + 1;
        $im->string( gdTinyFont, $x, $y, $label, $self->{color_black} );
        my $taxon_oid = $taxonOids_ref->[$i];
        my $x1        = $x - 2;
        my $y1        = $y;
        my $x2        = $x1 + $cell_width;
        my $y2        = $y1 + $cell_height;
        my $title     = $colDict_ref->{$taxon_oid};
        $title =~ s/'/ /g;
        my $url =
          "$main_cgi?section=AbundanceProfiles" 
        . "&page=abundanceProfileSort";
        $url .= "&stateFile=$stateFile";
        $url .= "&sortIdx=$i";
        $md  .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
        $md  .= "href='$url' title='Sort column $label' />\n";
    }

    ## row labels
    for ( my $i = 0 ; $i < $n_rows ; $i++ ) {
        my $x      = $x_width + 2;
        my $y      = ( $i * $cell_width ) + $cell_height;
        my $label  = $rowLabels_ref->[$i];
        my $label2 = $label;
        my $desc   = $rowDict_ref->{$label2};
        my $color  = $self->{color_black};
        $color = $self->{color_red}
          if matchText( $clusterMatchText, $label )
          || matchText( $clusterMatchText, $desc );
        $im->string( gdTinyFont, $x, $y, $label, $color );
        my $x1    = $x;
        my $y1    = $y;
        my $x2    = $x1 + $text_width;
        my $y2    = $y1 + $cell_height;
        my $title = "$label - $desc";
        $title =~ s/'/ /g;
        my $url;

        if ( $label =~ /^COG/ ) {
            $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
            $url .= "&cog_id=$label";
        }
        if ( $label =~ /^pfam/ ) {
            $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
            $url .= "&pfam_id=$label";
        }
        if ( $label =~ /^EC:/ ) {
            $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
            $url .= "&ec_number=$label";
        }
        if ( $label =~ /^TIGR/ ) {
            $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
            $url .= "&tigrfam_id=$label";
        }
        if ( $label =~ /^oclust/ ) {
            my $id = $label;
            $id =~ s/oclust//;
            $url = "$section_cgi&page=orthologClusterGeneList";
            $url .= "&cluster_id=$id";
        }
        if ( $label =~ /^hclust/ ) {
            my $id = $label;
            $id =~ s/hclust//;
            $url = "$section_cgi&page=homologClusterGeneList";
            $url .= "&cluster_id=$id";
        }
        if ( $label =~ /^sclust/ ) {
            my $id = $label;
            $id =~ s/sclust//;
            $url = "$section_cgi&page=superClusterGeneList";
            $url .= "&cluster_id=$id";
        }
        my $href;
        $href = "href='$url'" if $url ne "";
        $md .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
        $md .= "$href title='$title' />\n";
    }

    #$md .= "</map>\n";
    return $md;
}

############################################################################
# matchText - See if a text matches.  Ignore case.
############################################################################
sub matchText {
    my ( $subStr, $text ) = @_;
    $subStr =~ s/\s+//g;
    return 0 if $subStr eq "";
    $subStr =~ tr/A-Z/a-z/;
    $text   =~ tr/A-Z/a-z/;
    my $idx = index( $text, $subStr );
    return 1 if $idx >= 0;
    return 0;
}

1;
