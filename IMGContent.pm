############################################################################
# IMGContent.pm- shows the history of IMG content - i.e. how many genes and 
#     genomes were in IMG at different version releases
# $Id: IMGContent.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package IMGContent;
my $section = "CompareGenomes";

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use ChartUtil;
use HtmlUtil;

$| = 1;

my $env         = getEnv();
my $tmp_url     = $env->{tmp_url};
my $base_url    = $env->{base_url};
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $verbose     = $env->{verbose};
my $user_restricted_site = $env->{user_restricted_site};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $sid  = getContactOid();
    my $page = param("page");

    HtmlUtil::cgiCacheInitialize( "IMGContent" );
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "contentHistory" ) {
        printIMGContentHistory();
    }

    HtmlUtil::cgiCacheStop();
}

############################################################################
# printIMGContentHistory - get content by IMG version
############################################################################
sub printIMGContentHistory {
    print "<h1>IMG Content History</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $sql = qq{
	select img_version, archaea, bacteria,
               eukaryota, viruses, plasmids, gfragment,
               total_genomes, total_genes,
               to_char(release_date, 'yyyy-mm-dd')
          from img_content_history
      order by img_version
    };

    # Exit gracefully on DB error, such as missing columns +BSJ 11/17/11
    webError("Insufficient information in database. "
	   . "Unable to display content history.")
	if (!$dbh->prepare($sql));

    print "<p style='width: 600px;'>";
    print "The graph below displays how many genomes and genes "
	. "were in IMG at each IMG version release.";
    print "</p>";

    my $cur = execSql( $dbh, $sql, $verbose );
    my @versions;
    my @archaea_data;
    my @bacteria_data;
    my @eukaryota_data;
    my @viruses_data;
    my @plasmids_data;
    my @gfragment_data;
    my @total_genomes_data;
    my @total_genes_data;
    my @series = ( "Archaea", "Bacteria", "Eukaryota", 
		   "Viruses", "Plasmids", "Genome Fragments" );
    my @grouped_series = (
                           "Archaea,1",   "Bacteria,1",
                           "Eukaryota,1", "Viruses,1",
                           "Plasmids,1",  "Genome Fragments,1",
	                   "Total Genes / 1000,2"
    );

    for ( ; ; ) {
        my (
             $version,       $archaea,     $bacteria,
             $eukaryota,     $viruses,     $plasmids, $gfragment,
             $total_genomes, $total_genes, $release_date
          )
          = $cur->fetchrow();
        last if !$version;
        push @versions,           "$version ($release_date)";
        push @archaea_data,       $archaea;
        push @bacteria_data,      $bacteria;
        push @eukaryota_data,     $eukaryota;
        push @viruses_data,       $viruses;
        push @plasmids_data,      $plasmids;
        push @gfragment_data,     $gfragment;
        push @total_genomes_data, $total_genomes;
        push @total_genes_data,   $total_genes;
    }
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    my $nrows = @versions;

    my $datastr1 = join( ",", @archaea_data );
    my $datastr2 = join( ",", @bacteria_data );
    my $datastr3 = join( ",", @eukaryota_data );
    my $datastr4 = join( ",", @viruses_data );
    my $datastr5 = join( ",", @plasmids_data );
    my $datastr6 = join( ",", @gfragment_data );
    my $datastr7 = join( ",", @total_genomes_data );
    my $datastr8 = join( ",", @total_genes_data );

    my @datas;
    push @datas, $datastr1;
    push @datas, $datastr2;
    push @datas, $datastr3;
    push @datas, $datastr4;
    push @datas, $datastr5;
    push @datas, $datastr6;

    my @datalabels;
    push @datalabels, "Total Genomes:".$datastr7;
    push @datalabels, "Total Genes:".$datastr8;

    my $width = 800;
    $width = (scalar @versions) * 12 * (scalar @series);
    my $table_width = $width + 100;

    # PREPARE THE BAR CHART
    #my $chart = newStackedChart();
    my $chart = newBarChart3D();
    $chart->WIDTH($width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL("Version");
    $chart->RANGE_AXIS_LABEL("Count");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("no");
    $chart->SERIES_NAME( \@series );
    $chart->CATEGORY_NAME( \@versions );
    $chart->DATA( \@datas );
    $chart->DATA_TOTALS( \@datalabels );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td padding=0 valign=top align=left>\n";
    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printIMGContentHistory", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################
    print "</td>\n";
    print "<td>\n";
    print "<table border='0'>\n";

    my $idx = 0;
    for my $series1 (@series) {
        last if !$series1;

        print "<tr>\n";
        print
          "<td align=left style='font-family: Calibri, Arial, Helvetica; "
	. "white-space: nowrap;'>\n";
        if ( $st == 0 ) {
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "&nbsp;&nbsp;";
        }

        print $series1;
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    print "</table>\n";
    print "</td></tr>\n";
    print "</table>\n";

    printStatusLine( "Loaded.", 2 );
}

1;

