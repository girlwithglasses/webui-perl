############################################################################
# IprGraph.pm - InterPro alignment graph display.
#  Show InterPro alignments on query sequence.
#    --es 03/29/2006
############################################################################
package IprGraph;
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
my $graph_width = 200;
my $graph_text_space = 10;
my $text_width = 600;
#my $text_width = 500;
my $text_x_start = $x_offset + $graph_width + $graph_text_space;
my $total_width = $text_x_start + $text_width;
my $vert_spacing = 14;
my $graph_y_offset = 5;
my $font_h = 12;
my $ipr_w = 53;
 
############################################################################
# writeFile - Write image file.
#   query_len - AA sequence length of query gene.
#   recs_ref - Records with following fields 
#       (from gene_img_interpro_hits) - tab delimited fields
#     sfstarts
#     sfends
#     iprid
#     iprdesc
#     domaindb
#     domainid
#       
############################################################################
sub writeFile {
    my( $query_len, $recs_ref, $outFile ) = @_;

    my $nRecs = @$recs_ref;
    my $total_height = $vert_spacing * ( $nRecs + 3 );

    my $im = new GD::Image( $total_width, $total_height );

    my $white = $im->colorAllocate( 255, 255, 255 );
    my $black = $im->colorAllocate( 0, 0, 0 );
    my $blue = $im->colorAllocate( 0, 0, 170 );
    my $green = $im->colorAllocate( 0, 255, 0 );
    my $red = $im->colorAllocate( 255, 0, 0 );

    $im->transparent( $white );
    $im->interlaced( 'true' );

    my $y = $vert_spacing;

    ## Query gene
    my $w = 1.0 * $graph_width;
    my $y2 = $y + $graph_y_offset;
    $im->rectangle( $x_offset, $y2-1, $w + $x_offset, $y2+1, $red );
    $im->string( gdSmallFont, $text_x_start, $y, "Query Gene", $red );

    ## Hits
    my @iprid_ys;
    for my $r( @$recs_ref ) {
	$y += $vert_spacing;
        my( $sfstarts, $sfends, $iprid, $iprdesc, $domaindb, $domainid ) =
	   split( /\t/, $r );
        my @starts = split( /,/, $sfstarts );
        my @ends = split( /,/, $sfends );
	my $n = @starts;
	for( my $i = 0; $i < $n; $i++ ) {
	   my $start = $starts[ $i ];
	   my $end = $ends[ $i ];
	   my $y2 = $y + $graph_y_offset;
	   my $x1 = $x_offset + ( ( $start / $query_len ) * $graph_width );
	   my $x2 = $x_offset + ( ( $end / $query_len ) * $graph_width );
	   $im->rectangle( $x1, $y2-1, $x2, $y2+1, $blue );
	   if( $start > $query_len ) {
	      webLog( "WARNING: bad sfstart $start > $query_len\n" );
	   }
	   if( $end > $query_len ) {
	      webLog( "WARNING: bad sfend $start > $query_len\n" );
	   }
	}
	my $label = "$iprid - $iprdesc ($domaindb $domainid)";
	$im->string( gdSmallFont, $text_x_start, $y, $label, $blue );
	$im->line( $text_x_start, $y+$font_h, $text_x_start + $ipr_w,
	   $y+$font_h, $blue );
	push( @iprid_ys, "$y\t$iprid" );
    }
    my $wfh = newWriteFileHandle( $outFile, "writeFile" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    ## Highlight the IPR ID part.
    my $s;
    for my $i( @iprid_ys ) {
       my( $y, $iprid ) = split( /\t/, $i );
       my $x1 = $text_x_start;
       my $y1 = $y;
       my $x2 = $x1 + $ipr_w;
       my $y2 = $y1 + 10;
       my $url = "$ipr_base_url$iprid";
       $s .= "<area shape='rect' coords='$x1,$y1,$x2,$y2' href='$url'>\n";
    }
    return $s;

}


1;
