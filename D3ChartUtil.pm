package D3ChartUtil; 
require Exporter; 
@ISA = qw( Exporter ); 
@EXPORT = qw(
    printHBarChart
    printPieChart
    printDonutChart
); 

use strict; 
use DBI;
use WebConfig; 
use WebUtil; 
use JSON;

 
# Force flush
$| = 1; 
 
my $env = getEnv( ); 
my $verbose = $env->{verbose};
my $tmp_url = $env->{ tmp_url }; 
my $tmp_dir = $env->{ tmp_dir }; 
my $base_url = $env->{ base_url }; 

sub printHBarChart {
    my ($data, $url2, $additional_text, $chart_div_name) = @_; 
    return if !$data;

    # Each bar has the following fields:
    # count
    # label
    # title
    # subtitle

    print "<h3>$chart_div_name</h3>" if $chart_div_name;
    my $svg_id = "chart";
    $svg_id = $chart_div_name if $chart_div_name && $chart_div_name ne "";

    print qq{
      <link rel="stylesheet" type="text/css"
            href="$base_url/d3barchart.css" />

      <script src="$base_url/d3.min.js"></script>
      <span id="ruler"></span>
      <svg id="$svg_id"></svg>
      <script src="$base_url/d3barchart.js"></script>
      <script>
          window.onload = drawHorizontalBars("$svg_id", "$url2", $data);
      </script>
    };
}

sub printPieChart {
    my ($data, $url1, $url2, $chart_div_name, $dolegend, $dotable,
	$columns, $pie_width, $table_width) = @_;
    return if !$data;

    # Each bar has the following fields:
    # count
    # label
    # title
    # subtitle
    # colunms: ["color", "id", "name", "count", "percent"]

    print "<h3>$chart_div_name</h3>" if $chart_div_name;
    my $div_id = "chart";
    $div_id = $chart_div_name if $chart_div_name && $chart_div_name ne "";

    $dolegend = 1 if $dolegend eq "";
    $dotable = 1 if $dotable eq "";
    $columns = "[\"color\", \"id\", \"name\", \"count\", \"percent\"]"
	if !$columns || $columns eq "";
    $pie_width = 0 if !$pie_width || $pie_width eq "";
    $table_width = 0 if !$table_width || $table_width eq "";

    print qq{
      <link rel="stylesheet" type="text/css"
            href="$base_url/d3piechart.css" />
      <script src="$base_url/d3.min.js"></script>
      <span id="ruler"></span>
      <div id="$div_id"></div>
      <script src="$base_url/d3piechart.js"></script>
      <script>
          window.onload = drawPieChart
              ("$div_id", "$url1", "$url2", $data, $dolegend, $dotable, $columns, 
                $pie_width, $table_width);
      </script>
    };
}

############################################################################
# printDonutChart: print pie chart with data in JSON format
#
# data: [{"id": "A", "name": "Name for A", "urlid": "url ID for A",
#                    "count": 10, "pecent": 5.12},
#        {"id": "B", "name": "Name for B", "urlid": "url ID for B",
#                    "count": 20, "pecent": 10.24} ... ]
# url2: URL (+ urlid) for url redirection
# additional_text: optional additional HTML text to display
#
# (no data table display)
############################################################################
sub printDonutChart {
    my ($data, $url2, $additional_text) = @_;

    if ( ! $data ) {
	return;
    }

    print qq{
<div id='chart_div'>
<style>
.arc path {
  stroke: #fff;
}

td, th {
    vertical-align: middle;
    padding: 1px 2px;
}

#rectangle{
 width:16px;
 height:16px;
 background:blue;
}
</style>
};
    print "<script src='$base_url/d3.min.js'></script>\n";
    print "<script>\n";

    print "var width = 500, height = 500, radius = Math.min(width, height) / 2;\n";
    print "var h2 = 280;\n";
    print "var data = " . $data . ";\n";

    if ( $additional_text ) {
        print "var data2 = " . $additional_text . ";\n";
    }
    else {
        print "var data2 = [];\n";
    }

    print qq{
    var color = d3.scale.category20();
    var color2 = d3.scale.category20b();
    var color3 = d3.scale.category20c();

var svg = d3.select("#chart_div").append("svg")
    .attr("width", width)
    .attr("height", height)
    .append("g")
    .attr("transform", "translate(" + width / 2 + "," + height / 2 + ")");

var tooltip = d3.select("#chart_div")
    .append("div")
    .style("position", "absolute")
    .style("z-index", "10")
    .style("visibility", "hidden")
    .style("border", "solid 1px #aaa")
    .style("background", "lightgray")
    .html(function(d) {
	return "<b>a simple tooltip</b>";});

var arc = d3.svg.arc()
    .outerRadius(radius - 10)
    .innerRadius(radius - 80);

var pie = d3.layout.pie()
    .sort(null)
    .value(function(d) { return d.count; });

var g = svg.selectAll(".arc")
    .data(pie(data))
    .enter().append("g")
    .append("a")
    .attr("class", "arc")
    .on("click", function(d) { 
	var url = "$url2";
	url += d.data.urlid;
        window.open( url ); })
    .on("mouseover", function(d){return tooltip.style("visibility", "visible").html("[" + d.data.id + "] " + d.data.name + ": " + d.data.count + " (" + d.data.percent + "%)");})
    .on("mousemove", function(){return tooltip.style("top",
						     (d3.event.pageY-h2)+"px").style("left",(d3.event.pageX+10)+"px");})
    .on("mouseout", function(){return tooltip.style("visibility", "hidden");});

g.append("path")
    .attr("d", arc)
    .style("fill", function(d, i) {
	var c_temp = i % 60;
	if ( c_temp >= 40 ) {
	    return color3(i % 20);
	}
	if ( c_temp >= 20 ) {
	    return color2(i % 20);
	}
	else {
	    return color(i % 20);
	} });

g.append("text")
    .attr("transform", function(d) { return "translate(" + arc.centroid(d) + ")"; })
    .attr("dy", ".35em")
    .style("text-anchor", "middle")
    .text(function(d) { return d.data.id; });

g.append("svg:text")
    .attr("dy", ".35em")
    .attr("text-anchor", "middle")
    .style("font","bold 14px Georgia")
    .data(data2)
    .text(function(d) { return d; } );
</script>
</div>
    };
}


1;

