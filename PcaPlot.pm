############################################################################
# PcaPlot.pm - Plot PCA output.  Do only two dimensions.
#    --es 12/22/2006
############################################################################
package PcaPlot;
use strict;
use Data::Dumper;
use GD;
use WebUtil;
use WebConfig;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $tmp_url = $env->{ tmp_url };
my $tmp_dir = $env->{ tmp_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $ipr_base_url = $env->{ ipr_base_url };
my $verbose = $env->{ verbose };

my $x_offset = 10;
my $y_offset = 10;
my $graph_dim = 500;
my $total_width  = 2*$x_offset + $graph_dim;
my $total_height = 2*$y_offset + $graph_dim;

############################################################################
# writeFile - Write PCA file.
#   Input tab delimited records has.
#      1. id
#      2. descritpion
#      3. url
#      4. PC1
#      5. PC2
#  Write file and return information for clickable maps.
############################################################################
sub writeFile {
    my( $recs_ref, $outFile ) = @_;

    my $im = new GD::Image( $total_width, $total_height );

    my $white = $im->colorAllocate( 255, 255, 255 );
    my $black = $im->colorAllocate( 0, 0, 0 );
    my $blue = $im->colorAllocate( 0, 0, 255 );
    my $green = $im->colorAllocate( 0, 255, 0 );
    my $red = $im->colorAllocate( 255, 0, 0 );
    my $background = $im->colorAllocate( 240, 240, 255 );

    $im->transparent( $white );
    $im->interlaced( 'true' );
    $im->filledRectangle( 0, 0, $total_width, $total_height, $background );

    my $min_val = 1000000000;
    my $max_val = -1000000000;
    for my $r( @$recs_ref ) {
        my( $id, $desc, $url, $pc1, $pc2, undef ) = split( /\t/, $r );
	$min_val = $min_val < $pc1 ? $min_val : $pc1;
	$min_val = $min_val < $pc2 ? $min_val : $pc2;
	$max_val = $max_val > $pc1 ? $max_val : $pc1;
	$max_val = $max_val > $pc2 ? $max_val : $pc2;
    }
    my $max_abs_val = abs( $max_val );
    $max_abs_val = $max_abs_val > abs( $min_val ) ?
       $max_abs_val : abs( $min_val );
    webLog( "min_val=$min_val max_val=$max_val max_abs_val=$max_abs_val\n" );
    my $graph_dim2 = $graph_dim / 2;
    my $scale = $max_abs_val / $graph_dim2;

    my $x1 = $x_offset;
    my $y1 = $y_offset + $graph_dim2;
    my $x2 = $x1 + $graph_dim;
    my $y2 = $y1;
    #$im->line( $x1, $y1, $x2, $y2, $black );

    my $x1 = $x_offset + $graph_dim2;
    my $y1 = $y_offset;
    my $x2 = $x1;
    my $y2 = $y1 + $graph_dim;
    #$im->line( $x1, $y1, $x2, $y2, $black );

    my $s; # clickable map information
    for my $r( @$recs_ref ) {
        my( $id, $desc, $url, $pc1, $pc2, undef ) = split( /\t/, $r );
	my $x = int( $graph_dim2 + $x_offset + ( $pc1 / $scale ) );
	my $y = int( $graph_dim2 + $y_offset + ( $pc2 / $scale ) );
	#$im->string( gdMediumBoldFont, $x, $y, $id, $blue );
	drawPoint( $im, $x, $y, $red );
	$s .= getArea( $x, $y, $id, $desc, $url );
    }
    my $wfh = newWriteFileHandle( $outFile, "writeFile" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;
    return $s;
}

############################################################################
# drawPoint - Draw the point.
############################################################################
sub drawPoint {
    my( $im, $x, $y, $color ) = @_;

    ## Offset
    my $offset = 10;

    ## Vertical bar
    my $v_x1 = $x;
    my $v_y1 = $y - $offset;
    my $v_x2 = $x;
    my $v_y2 = $y + $offset;
    $im->line( $v_x1, $v_y1, $v_x2, $v_y2, $color );

    ## Horizontal bar
    my $h_x1 = $x - $offset;
    my $h_y1 = $y;
    my $h_x2 = $x + $offset;
    my $h_y2 = $y;
    $im->line( $h_x1, $h_y1, $h_x2, $h_y2, $color );
}

############################################################################
# getArea - Get mouse over area.
############################################################################
sub getArea {
    my( $x, $y, $id, $desc, $url ) = @_;

    my $offset = 2;

    my $x1 = $x - $offset;
    my $y1 = $y - $offset;
    my $x2 = $x + $offset;
    my $y2 = $y + $offset;
    my $s = "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
    $s .= "href='$url' title='$id $desc' />\n";
    return $s;
}

1;
