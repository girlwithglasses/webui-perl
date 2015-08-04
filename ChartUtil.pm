############################################################################
#   Charting utility functions
#       --ac 3/24/2008
# $Id: ChartUtil.pm 31823 2014-08-30 05:00:25Z aratner $
############################################################################
package ChartUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    newBarChart
    newBarChart3D
    newPieChart
    newLineChart
    newHistogramChart
    newDotChart
    newScatterChart
    newStackedChart
    generateChart
);

use strict;
use Class::Struct;
use Time::HiRes qw (gettimeofday);

use WebConfig;
use WebUtil;

# Force flush
$| = 1;

my $env = getEnv( );
my $tmp_url = $env->{ tmp_url };
my $tmp_dir = $env->{ tmp_dir };
my $base_url = $env->{ base_url };

# 
# Chart structure
#
struct Chart => {
  TYPE                      => '$',
  TITLE                     => '$',
  SUBTITLE                  => '$',
  FILE_PREFIX               => '$',
  FILEPATH_PREFIX           => '$',
  WIDTH                     => '$',
  HEIGHT                    => '$',
  DOMAIN_AXIS_LABEL         => '$',
  RANGE_AXIS_LABEL          => '$',
  PLOT_ORIENTATION          => '$',
  INCLUDE_LEGEND            => '$',
  INCLUDE_TOOLTIPS          => '$',
  INCLUDE_URLS              => '$',
  INCLUDE_SECTION_URLS      => '$', 
  URL_SECTION_NAME          => '$', 
  URL_SECTION               => '$', 
  SERIES_NAME               => '$',
  CATEGORY_NAME             => '$',
  DATA                      => '$',
  DATA_TOTALS               => '$',
  ITEM_URL                  => '$',
  CHART_BG_COLOR            => '$',
  COLOR_THEME               => '$',
  ROTATE_DOMAIN_AXIS_LABELS => '$',
  IMAGEMAP_ONCLICK          => '$',
  IMAGEMAP_HREF_ONCLICK     => '$',
  XAXIS                     => '$', 
  YAXIS                     => '$', 
  SLOPE                     => '$', 
  SHOW_REGRESSION           => '$',
  SHOW_XLABELS              => '$',
  SHOW_YLABELS              => '$',
  LOG_SCALE                 => '$',
};

##############################################################################
# return reference to new Bar Chart object
##############################################################################
sub newBarChart {
    my $chart = Chart->new();
    $chart->TYPE( "BAR" );
    my $fileprefix = getUniqueFilePrefix( "barchart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart;
}

##############################################################################
# return reference to new Bar Chart 3D object   
##############################################################################
sub newBarChart3D { 
    my $chart = Chart->new();
    $chart->TYPE( "BAR3D" ); 
    my $fileprefix = getUniqueFilePrefix( "barchart3d" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
} 
 
##############################################################################
# return reference to new Stacked Bar Chart object
##############################################################################
sub newStackedChart { 
    my $chart = Chart->new();
    $chart->TYPE( "STACKED" ); 
    my $fileprefix = getUniqueFilePrefix( "stacked" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
} 

##############################################################################
# return reference to new Pie Chart object
##############################################################################
sub newPieChart {
    my $chart = Chart->new();
    $chart->TYPE( "PIE" );
    my $fileprefix = getUniqueFilePrefix( "piechart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart;
}

##############################################################################
# return reference to new Line Chart object
##############################################################################
sub newLineChart { 
    my $chart = Chart->new();
    $chart->TYPE( "LINE" );
    my $fileprefix = getUniqueFilePrefix( "linechart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
} 

##############################################################################
# return reference to new Distribution Chart object
##############################################################################
sub newDistributionChart {
    my $chart = Chart->new();
    $chart->TYPE( "DISTRIBUTION" );
    my $fileprefix = getUniqueFilePrefix( "distributionchart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
} 

##############################################################################
# return reference to new Histogram Chart object
##############################################################################
sub newHistogramChart {
    my $chart = Chart->new();
    $chart->TYPE( "HISTOGRAM" );
    my $fileprefix = getUniqueFilePrefix( "histogramchart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
} 

############################################################################## 
# return reference to new Dot Chart object 
############################################################################## 
sub newDotChart { 
    my $chart = Chart->new(); 
    $chart->TYPE( "DOT" ); 
    my $fileprefix = getUniqueFilePrefix( "dotchart" ); 
    $chart->FILE_PREFIX( $fileprefix ); 
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix ); 
    return $chart; 
} 
 
##############################################################################
# return reference to new Scatter Chart object
##############################################################################
sub newScatterChart {
    my $chart = Chart->new();
    $chart->TYPE( "SCATTER" );
    my $fileprefix = getUniqueFilePrefix( "scatterchart" );
    $chart->FILE_PREFIX( $fileprefix );
    $chart->FILEPATH_PREFIX( $tmp_dir."/".$fileprefix );
    return $chart; 
}

##############################################################################
# generate the chart -- you should be able to pass in any Chart class struct,
# as long as the "TYPE" param is defined
##############################################################################
sub generateChart {
    my ($chart) = @_;
 
    # write out input file 
    my $filepath = $chart->FILEPATH_PREFIX.".in"; 
    my $FH = newWriteFileHandle($filepath); 
    print $FH "TYPE="                  .$chart->TYPE."\n"; 
    print $FH "TITLE="                 .$chart->TITLE."\n"; 
    print $FH "SUBTITLE="              .$chart->SUBTITLE."\n"; 
    print $FH "FILEPATH_PREFIX="       .$chart->FILEPATH_PREFIX."\n"; 
    print $FH "WIDTH="                 .$chart->WIDTH."\n"; 
    print $FH "HEIGHT="                .$chart->HEIGHT."\n"; 
    print $FH "DOMAIN_AXIS_LABEL="     .$chart->DOMAIN_AXIS_LABEL."\n"; 
    print $FH "RANGE_AXIS_LABEL="      .$chart->RANGE_AXIS_LABEL."\n"; 
    print $FH "PLOT_ORIENTATION="      .$chart->PLOT_ORIENTATION."\n"; 
    print $FH "LOG_SCALE="             .$chart->LOG_SCALE."\n"; 
    print $FH "INCLUDE_LEGEND="        .$chart->INCLUDE_LEGEND."\n"; 
    print $FH "INCLUDE_TOOLTIPS="      .$chart->INCLUDE_TOOLTIPS."\n"; 
    print $FH "INCLUDE_URLS="          .$chart->INCLUDE_URLS."\n"; 
    print $FH "URL_SECTION_NAME="      .$chart->URL_SECTION_NAME."\n"; 
    print $FH "INCLUDE_SECTION_URLS="  .$chart->INCLUDE_SECTION_URLS."\n"; 
    print $FH "IMAGEMAP_ONCLICK="      .$chart->IMAGEMAP_ONCLICK."\n"; 
    print $FH "IMAGEMAP_HREF_ONCLICK=" .$chart->IMAGEMAP_HREF_ONCLICK."\n"; 
    print $FH "ITEM_URL="              .$chart->ITEM_URL."\n"; 
    print $FH "CHART_BG_COLOR="        .$chart->CHART_BG_COLOR."\n"; 
    print $FH "COLOR_THEME="           .$chart->COLOR_THEME."\n"; 
    print $FH "SHOW_REGRESSION="       .$chart->SHOW_REGRESSION."\n"; 
    print $FH "SHOW_XLABELS="          .$chart->SHOW_XLABELS."\n"; 
    print $FH "SHOW_YLABELS="          .$chart->SHOW_YLABELS."\n"; 
    print $FH "ROTATE_DOMAIN_AXIS_LABELS=".$chart->ROTATE_DOMAIN_AXIS_LABELS."\n"; 
 
    my $series_names = $chart->SERIES_NAME;
    foreach my $series_name (@$series_names) { 
        print $FH "SERIES_NAME=".$series_name."\n";
    } 
    my $category_names = $chart->CATEGORY_NAME; 
    foreach my $category_name (@$category_names) { 
        print $FH "CATEGORY_NAME=".$category_name."\n"; 
    } 
    my $url_sections = $chart->URL_SECTION; 
    foreach my $url_section (@$url_sections) { 
        print $FH "URL_SECTION=".$url_section."\n"; 
    } 
    my $totals = $chart->DATA_TOTALS; 
    foreach my $total (@$totals) { 
        print $FH "DATA_TOTALS=".$total."\n"; 
    } 
    my $xdata = $chart->XAXIS; 
    foreach my $x (@$xdata) { 
        print $FH "XAXIS=".$x."\n"; 
    } 
    my $ydata = $chart->YAXIS;
    foreach my $y (@$ydata) {
        print $FH "YAXIS=".$y."\n";
    } 
    my $dir = $chart->SLOPE; 
    foreach my $item (@$dir) { 
        print $FH "SLOPE=".$item."\n";
    }
    my $alldata = $chart->DATA;
    foreach my $item (@$alldata) {
        print $FH "DATA=".$item."\n";
    } 
    close ($FH); 
 
    # run the charting tool 
    my $cmd = $env->{ chart_exe }." ".$filepath; 
    my $st = runCmdNoExit($cmd); 
    return $st; 
} 
 
##############################################################################
# return unique file prefix
##############################################################################
sub getUniqueFilePrefix {
    my ($id) = @_;

    my ($a,$b,$c,$d,$e,$f,$g,$h,$i) = localtime(time);
    my $rand = $h.$g.$f.$e.$d.$c.$b.$a;
    my ($now, $micro) = gettimeofday;

    my $fileprefix = $id."-".$rand."-".$micro;
    return $fileprefix;
}

##############################################################################
# printPieChart - configures a pie chart
#
# name - e.g. KEGG
# param - url item name e.g. "func_code" for pfam
# url - base url e.g. "$section_cgi&page=clustersByPfam"
# categories - array of categories e.g. gene count "25 to 50"
#              array of "cf.definition" for pfam
# sections - e.g. array of "cf.function_code" for pfam
#            or same as categories in the "gene count" example
# data - array of data for the categories e.g. counts
# series - array of one item here e.g. my @series = ( "count" );
# has_sections - whether data array contains sections e.g. ids
#      that is, whether the param "sections" is different
#      from param "categories" requiring separate arrays like
#      for pfams (func_code for url link vs. definition for display)
# limit - upper count of items for which to allow link
# tool - optional e.g. bc
# show_hyperlinks - whether to show hyperlinks on pie sections - 0 or 1
###############################################################################
sub printPieChart {
    my ($name, $param, $url, $categories_aref, $sections_aref, $data_aref,
        $series_aref, $has_sections, $limit, $tool, $show_hyperlinks) = @_;

    $limit = 5000 if $limit eq "";
    $show_hyperlinks = 1 if $show_hyperlinks eq "";

    my @items = @$categories_aref;
    my @sections = @$sections_aref;
    my @data  = @$data_aref;
    my @series = @$series_aref;

    my $datastr = join(",", @data);
    my @datas;
    push @datas, $datastr;

    my $include_urls = "no";
    $include_urls = "yes" if $show_hyperlinks;

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS($include_urls);
    $chart->ITEM_URL($url);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME($param);
    $chart->SERIES_NAME(\@series);
    $chart->CATEGORY_NAME(\@items);
    $chart->URL_SECTION(\@sections);
    $chart->DATA(\@datas);

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>";
    print "<tr>";
    print "<td valign=top>";

    my $it = new InnerTable( 1, $name.$tool."$$", $name.$tool, 0 );
    my $sd = $it->getSdDelim();
    my $col2name = @series[0];
    $it->addColSpec( $name, "asc", "left" );
    $it->addColSpec( $col2name, "desc", "right" );

    my $idx = 0;
    foreach my $item (@items) {
        last if !$item;

        my $catUrl = massageToUrl($item);
        my $url2 = $url;
        $url2 .= "&$param=$catUrl" if !$has_sections;
        $url2 .= "&$param=$sections[$idx]" if $has_sections;

        my $row;
        if ($st == 0) {
            my $imageref = "<img src='$tmp_url/"
                . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
            if (lc($item) eq "unknown") {
                $row = "xunknown";
            } else {
                $row = escHtml($item);
            }
            $row .= $sd . alink($url2, $imageref, "", 1);
            $row .= "&nbsp;&nbsp;";
        }
        $row .= escHtml($item) . "\t";

        my $count = $data[$idx];
        my $link = $count;
        if ($count && $count < $limit) {
            $link = alink($url2, $count, "_blank");
        }
        $row .= $count . $sd . $link . "\t";
        $it->addRow($row);
        $idx++;    }

    $it->hideAll() if $idx < 50;
    $it->printOuterTable(1);

    print "<td valign=top align=left>";
    printChart($chart) if $st == 0;
    print "</td></tr>";
    print "</table>";
}

######################################################################
# printBarChart - configures a bar chart
#
# name - e.g. "Gene Count"
# param - url item name 
#         e.g. "gene_count" (will be "&gene_count=25 to 50")
#         e.g. "func_code" for pfam  
# xlabel - label for the x-axis e.g. "Number of BCs"
# url - base url e.g. "$section_cgi&page=clustersByGeneCount"
# categories - array of categories e.g. gene count "25 to 50"
#              array of "cf.definition" for pfam
# sections - e.g. array of "cf.function_code" for pfam
#            or same as categories in the "gene count" example
# datas - array of data for each series i.e. 
#         e.g. counts for each series joined in comma-separated
#         string, which is added as an element into a data array
#         - the size of series array
#
#         my $datastr = join(",", @data);
#         my @datas;
#         push @datas, $datastr;
#
# series - array of one item here e.g. my @series = ( "count" );
# use_log - whether to use log2 for counts
# orientation - VERTICAL or HORIZONTAL for the plot
# log_scale - whether to display log scale for the counts axis
######################################################################
sub printBarChart {
    my ($name, $param, $ylabel, $url, $categories_aref, $sections_aref, 
	$datas_aref, $series_aref, $use_log, $orientation, $log_scale) = @_;
    $use_log = 0 if $use_log eq "";
    $log_scale = 0 if $log_scale eq "";
    $orientation = "VERTICAL" if $orientation eq "";

    my @items = @$categories_aref;
    my @sections = @$sections_aref;
    my @datas  = @$datas_aref;
    my @series = @$series_aref;

    my $chart_width = 700;
    $chart_width = (scalar @items) * 30 * (scalar @series);
    $chart_width = 400 if $chart_width < 400;

    $ylabel = "Log2(".$ylabel.")" if $use_log;

    use ChartUtil;
    # PREPARE THE BAR CHART
    my $chart = newBarChart();
    $chart->WIDTH($chart_width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL($name);
    $chart->RANGE_AXIS_LABEL($ylabel);
    $chart->LOG_SCALE("yes") if $log_scale;
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME($param);
    $chart->ITEM_URL($url);
    $chart->SERIES_NAME(\@series);
    $chart->CATEGORY_NAME(\@items);
    $chart->URL_SECTION(\@sections);
    $chart->DATA(\@datas);
    $chart->PLOT_ORIENTATION($orientation);

    if ($orientation eq "HORIZONTAL") {
	$chart->WIDTH(700);
	$chart->HEIGHT($chart_width);
	$chart->ROTATE_DOMAIN_AXIS_LABELS("no");
    }

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = generateChart($chart);
    }
    printChart($chart) if $st == 0;
}

######################################################################
# printChart - print the specified chart
######################################################################
sub printChart {
    my ($chart) = @_;

    if ($env->{ chart_exe } ne "") {
	my $url = "$tmp_url/".$chart->FILE_PREFIX.".png";
	my $imagemap = "#".$chart->FILE_PREFIX;
	my $width = $chart->WIDTH;
	my $height = $chart->HEIGHT;

	print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
                ($chart->FILEPATH_PREFIX.".html", "breakdownBy",1);
	while (my $s = $FH->getline()) {
	    print $s;
	}
	close ($FH);
	print "<img src='$url' BORDER=0 ";
	print " width=$width HEIGHT=$height";
	print " USEMAP='$imagemap'>\n";
    }
}



1;
