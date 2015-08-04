###########################################################################
#
#
# $Id: EggNog.pm 29739 2014-01-07 19:11:08Z klchu $
#
############################################################################
package EggNog;

use strict;
use CGI qw/:standard/;
use Data::Dumper;
use WebConfig;
use WebUtil;
use HtmlUtil;
use InnerTable;
use ChartUtil;
use OracleUtil;
$| = 1;

my $env         = getEnv();
my $base_url    = $env->{base_url};
my $base_dir    = $env->{base_dir};
my $tmp_url     = $env->{tmp_url};
my $tmp_dir     = $env->{tmp_dir};
my $main_cgi    = $env->{main_cgi};
my $cgi_url     = $env->{cgi_url};
my $verbose     = $env->{verbose};
my $YUI         = $env->{yui_dir_28};
my $yui_tables  = $env->{yui_tables};
my $section     = "EggNog";
my $section_cgi = "$main_cgi?section=$section";

sub dispatch {
    my $page = param("page");
    if ( $page eq "genelist" ) {

        #printGeneList();

        printChart();

    } elsif ( $page eq 'hierarchy' ) {
        getHierarchy();
    } elsif ( $page eq 'details' ) {
        printDetails();
    } elsif ( $page eq 'eggnogCategoryGenes' ) {

        printPieGeneList();
    } elsif ( $page eq 'list' ) {
        printPieGeneList();
    }
}

sub printPieGeneList {
    my $taxon_oid = param('taxon_oid');
    my $category  = param('category');

    print "<h1>EggNOG Genes</h1>\n";
    print "<p>\n";
    print "(Only EggNOG associated with <i><u>"
      . escHtml($category)
      . "</u></i> are shown with genes.)\n";
    print "</p>\n";


    my $rclause   = WebUtil::urClause('g1.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g1.taxon');

    my $sql = qq{
select distinct g.gene_oid
from gene g1, gene_eggnogs g left join eggnog_hierarchy e
on g.nog_id = e.nog_id 
where g.type like '%NOG'
and g.gene_oid = g1.gene_oid
and g1.taxon =  ?
and e.level_1 = ?        
$rclause
$imgClause
    };

    if ( $category eq 'unknown' ) {
        $sql = qq{
select distinct g.gene_oid
from gene g1, gene_eggnogs g left join eggnog_hierarchy e
on g.nog_id = e.nog_id 
where g.type like '%NOG'
and g.gene_oid = g1.gene_oid
and g1.taxon =  ?
and e.level_1 is null        
$rclause
$imgClause
    };

    }

    require TaxonDetailUtil;
    if ( $category eq 'unknown' ) {
        TaxonDetailUtil::printGeneListSectionSorting( $sql, '', '', $taxon_oid );
    } else {
        TaxonDetailUtil::printGeneListSectionSorting( $sql, '', '', $taxon_oid, $category );
    }
}

# from taxon detail page
# print chart instead of gene list
sub printChart {
    my $taxon_oid = param("taxon_oid");

    my $url2 = "$section_cgi&page=list&taxon_oid=$taxon_oid";

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("no");
    $chart->URL_SECTION_NAME("category");
    my @chartseries;
    my @chartcategories;
    my @chartdata;
    #################################

    print "<h1>EggNOG Categories</h1>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # get the total
    my $sql = qq{ 
select genes_in_eggnog
from taxon_stats
where taxon_oid = ?
    };
    my $cur              = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $total_gene_count = $cur->fetchrow();


    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select t.taxon_display_name, t.is_pangenome
from taxon t
where t.taxon_oid = ?
$rclause
$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $is_pangenome ) = $cur->fetchrow();

    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>\n" . alink( $url, $taxon_name ) . "</p>\n";

    my $rclause   = WebUtil::urClause('g1.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g1.taxon');

    my $sql = qq{
select nvl(e.level_1, 'unknown'),  count(distinct g.gene_oid)
from gene g1, gene_eggnogs g left join eggnog_hierarchy e
on g.nog_id = e.nog_id 
where g.type like '%NOG'
and g.gene_oid = g1.gene_oid
and g1.taxon =  ?
$rclause
$imgClause
group by e.level_1        
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # Use YUI css
    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
        <div class='yui-dt-liner'>
            <span>EggNOG Categories</span>
        </div>
    </th>
        <th>
        <div class='yui-dt-liner'>
            <span>Gene Count</span>
        </div>
    </th>
YUI
    } else {
        print "<table class='img' border='1'>\n";
        print "<th class='img' >EggNOG Categories</th>\n";
        print "<th class='img' >Gene Count</th>\n";
    }

    my %categoryHash;
    for ( ; ; ) {
        my ( $category, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;

        push @chartcategories, "$category";
        push @chartdata,       $gene_count;
        $categoryHash{$category} = $gene_count;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    my $classStr;

    for my $category1 (@chartcategories) {
        last if !$category1;

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        my $catUrl = massageToUrl($category1);
        my $url    = "$section_cgi&page=eggnogCategoryGenes";
        $url .= "&category=$catUrl";
        $url .= "&taxon_oid=$taxon_oid";

        # Categories
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;

        if ( $st == 0 ) {
            print "<a href='$url'>";
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "</a>";
            print "&nbsp;&nbsp;";
        }
        print escHtml($category1);
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        #Gene Count
        print "<td class='$classStr' style='text-align:right;'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print alink( $url, $chartdata[$idx] );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    print "</td>\n";
    print "<td valign=top align=left>\n";

    ## print the chart:
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH =
              newReadFileHandle( $chart->FILEPATH_PREFIX . ".html", "printEggNogCategories", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/" . $chart->FILE_PREFIX . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }

    print "<p>\n";
    print "</td></tr>\n";
    print "</table>\n";

    #$dbh->disconnect();
    printStatusLine( "$count EggNOG category.", 2 );
}

sub printDetails {
    print "<h1>EggNOG Details</h1>";
    my $level2 = param('level2');

    printStatusLine("Loading ...");

    print qq{
        $level2
        <br/>
    };

    my $sql = qq{
select h.eggnog_oid, h.function_group, h.level_1, h.level_2, h.nog_id
from eggnog_hierarchy h
where h.type like '%NOG'
and h.level_2 = ?        
    };
    my $dbh = dbLogin();

    print qq{
      <p>
      <table class='img'>
      <th class='img'> ID</th>
      <th class='img'> NOG ID</th>
      <th class='img'> Function Group</th>
      <th class='img'> Level 1</th>
      <th class='img'> Level 2</th>
    };

    my $nogCount = 0;
    my $cur = execSql( $dbh, $sql, $verbose, $level2 );
    for ( ; ; ) {
        my ( $eggnog_oid, $function_group, $level_1, $level_2, $nog_id ) = $cur->fetchrow();
        last if !$eggnog_oid;
        $nogCount++;
        print "<tr class='img'> <td class='img' nowrap> \n";
        print $eggnog_oid;
        print "</td> <td class='img' nowrap> \n";
        print $nog_id;
        print "</td> <td class='img' nowrap> \n";
        print $function_group;
        print "</td> <td class='img' nowrap> \n";
        print $level_1;
        print "</td> <td class='img' nowrap> \n";
        print $level_2;
        print "</td></tr>\n";
    }

    print qq{
        </table>    
    };

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $sql = qq{
select g.gene_oid, ge.nog_id, g.gene_display_name
from gene g, gene_eggnogs ge
where g.gene_oid = ge.gene_oid
and ge.level_2 = ?
and ge.type like '%NOG'        
$rclause
$imgClause
    };

    my $it = new InnerTable( 1, "eggnog$$", "eggnog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "asc", "left" );
    $it->addColSpec( "NOG ID",    "asc", "left" );
    $it->addColSpec( "Gene Name", "asc", "left" );
    my $count = 0;
    my %distinctGenes;
    my $cur = execSql( $dbh, $sql, $verbose, $level2 );
    for ( ; ; ) {
        my ( $gene_oid, $nog_id, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        $distinctGenes{$gene_oid} = 1;
        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' />" . "\t";
        my $url = alink( "main.cgi?section=GeneDetail&gene_oid=" . $gene_oid, $gene_oid );
        $r .= $gene_oid . $sd . $url . "\t";
        $r .= $nog_id . $sd . $nog_id . "\t";
        $r .= $gene_display_name . $sd . $gene_display_name . "\t";
        $it->addRow($r);
        $count++;
    }

    print "<br/><br/>";

    printMainForm();
    WebUtil::printGeneCartFooter();

    $it->printOuterTable(1);

    WebUtil::printGeneCartFooter() if $count > 10;
    print end_form();
    #$dbh->disconnect();
    my $c = keys %distinctGenes;
    printStatusLine( "$nogCount NOGs $c Genes Loaded", 2 );
}

sub getHierarchy {
    print "<h1>EggNOG Browser</h1>";

    printStatusLine("Loading ...");

    my $sql = qq{
select distinct h.function_group, h.level_1, h.level_2
from eggnog_hierarchy h
where h.type like '%NOG'
order by 1, 2, 3        
    };

    my $dbh = dbLogin();

    # function_group => level_1 => level_2
    my %tree;
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $function_group, $level_1, $level_2 ) = $cur->fetchrow();
        last if !$function_group;
        if ( exists $tree{$function_group} ) {
            my $subhash1_href = $tree{$function_group};
            if ( exists $subhash1_href->{$level_1} ) {
                my $subhash2_href = $subhash1_href->{$level_1};
                $subhash2_href->{$level_2} = 1;
            } else {
                my %tmp = ( $level_2 => 1 );
                $subhash1_href->{$level_1} = \%tmp;
            }
        } else {
            my %tmp  = ( $level_2 => 1 );
            my %tmp1 = ( $level_1 => \%tmp );
            $tree{$function_group} = \%tmp1;
        }
    }

    #$dbh->disconnect();

    #print Dumper \%tree;
    print "<p>\n";
    print qq{
      <table border=0>
      <tr>
      <td nowrap>      
    };

    foreach my $function_group ( sort keys %tree ) {
        print "<b>01 - $function_group</b><br/>\n";
        my $href1 = $tree{$function_group};
        foreach my $level_1 ( sort keys %$href1 ) {
            print nbsp(4);
            print "<b>02 - " . $level_1 . "</b><br/>\n";
            my $href2 = $href1->{$level_1};
            foreach my $level_2 ( sort keys %$href2 ) {
                print nbsp(8);
                my $x   = CGI::escape($level_2);
                my $url = $section_cgi . "&page=details&level2=" . $x;
                $url = alink( $url, $level_2 );
                print "03 - " . $url . "<br/>\n";
            }
        }
    }
    print qq{
        </td>
        </tr>
        </table>    
    };
    printStatusLine( "Loaded", 2 );
}

#
# print gene list from taxon detail page count
#
sub printGeneList {
    my $taxon_oid = param("taxon_oid");
    my $dbh       = dbLogin();
    my $name      = genomeName( $dbh, $taxon_oid );
    #$dbh->disconnect();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
select distinct g.gene_oid
from gene_eggnogs ge, gene g
where ge.gene_oid = g.gene_oid
and ge.type like '%NOG'
and g.taxon = ?    
$rclause
$imgClause
    };

    require TaxonDetail;
    TaxonDetail::printGeneListSectionSorting( $sql, "$name <br/> EggNOG Genes", 1, $taxon_oid );
}

1;
