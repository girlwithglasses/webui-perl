############################################################################
# NaturalProd.pm
# $Id: NaturalProd.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package NaturalProd;
my $section = "NaturalProd";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use Number::Format;
use HTML::Template;
use WebConfig;
use WebUtil;
use HtmlUtil;
use TabHTML;
use InnerTable;
use ImgPwayBrowser;
use BiosyntheticDetail;
use ChartUtil;
use MeshTree;
use BcUtil;

$| = 1;

my $env           = getEnv();
my $cgi_dir       = $env->{cgi_dir};
my $cgi_url       = $env->{cgi_url};
my $tmp_url       = $env->{tmp_url};
my $tmp_dir       = $env->{tmp_dir};
my $main_cgi      = $env->{main_cgi};
my $section_cgi   = "$main_cgi?section=$section";
my $verbose       = $env->{verbose};
my $base_url      = $env->{base_url};
my $base_dir      = $env->{base_dir};
my $metacyc_url   = $env->{metacyc_url};
my $ncbi_base_url = $env->{ncbi_entrez_base_url};
my $enable_biocluster = $env->{enable_biocluster};

sub dispatch {
    my $page = param('page');

    if ( $page eq "naturalProd" ) {
        printTaxonNP();
    } elsif ( $page eq "npTaxonList" ) {
        my $compound_oid = param('compound_oid');
        printNPTaxonList($compound_oid);
    } elsif ( $page eq "npBioClusterList" ) {
        my $compound_oid = param('compound_oid');
        printNPBioClusterList($compound_oid);
    } elsif ( $page eq "npListing" ) {
        my $dbh = dbLogin();
    	listAllNaturalProds( $dbh );
    } elsif ( $page eq "subCategory" ) {
        my $dbh       = dbLogin();
        my $stat_type = param('stat_type');
        my $val       = param('stat_val');
        listAllNaturalProds( $dbh, $stat_type, $val );
    } elsif ( $page eq "npActivity" ) {
        my $dbh = dbLogin();
        printNPActivity($dbh);
    } elsif ( $page eq "byPhylum" ) {
    	print "<h1>Secondary Metabolites by Phylum</h1>";
    	printNPByPhylum();
    } elsif ( $page eq "npsByPhylo" ) {
        printNPByPhylo();
    } elsif ( $page eq "taxonNPList" ) {
        printTaxonNPList();

    } elsif ( $page eq "summaryStats" ) {
	printStats(1);
    } elsif ( $page eq "bySMType" ) {
	printNpTree(1);
    } elsif ( $page eq "byActivity" ) {
        print "<h1>Secondary Metabolites - By Activity</h1>";
	MeshTree::printTreeActDiv();
    } elsif ( $page eq "byPhylum" ) {
	printNPByPhylum();
    } elsif ( $page eq "smListing" ) {
        my $dbh = dbLogin();
	listAllNaturalProds( $dbh, 0, 0, '', 0 );
    } elsif ( $page eq "activityListing" ) {
	printActivityListing(1);

    } else {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;         
        
        my $dbh = dbLogin();
        printAllNaturalProds($dbh);
        HtmlUtil::cgiCacheStop();
    }
}

sub getPredictedBc {
    my($dbh) = @_;
    my $sql = qq{
        select count (*)
        from bio_cluster_data_new
        where evidence = 'Predicted'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $bcp_cnt ) = $cur->fetchrow();
    return $bcp_cnt;
}

sub getSmStructures {
    my($dbh) = @_;
    my $sql = qq{
        select count (distinct compound_oid)
        from np_biosynthesis_source
        where compound_oid != '73142'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $np_cnt ) = $cur->fetchrow();
    return $np_cnt;
}


sub printLandingPage {
    HtmlUtil::cgiCacheInitialize($section);
    HtmlUtil::cgiCacheStart() or return;        
    
    my $dbh = dbLogin();

    # 1,139,707 predicted BCs:
    my $bcp_cnt = getPredictedBc($dbh);

    # 1,108 SM structures:
    my $np_cnt = getSmStructures($dbh);

    $bcp_cnt = Number::Format::format_number($bcp_cnt);
    #$bce_cnt = Number::Format::format_number($bce_cnt);
    $np_cnt = Number::Format::format_number($np_cnt);

    my $template = HTML::Template->new( filename => "$base_dir/npLanding.html" );
    $template->param( base_url => $base_url );
    #$template->param( bc_published => $bce_cnt );
    $template->param( bc_predicted => $bcp_cnt );
    $template->param( np_items => $np_cnt );
    print $template->output; 
    
    HtmlUtil::cgiCacheStop();
}

sub printNpTree {
    my ($show_title) = @_;
    $show_title = 0 if $show_title eq "";
    if ($show_title) {
        print "<h1>Secondary Metabolites - By SM Type</h1>";
    } 

    #require MeshTree;
    MeshTree::printTreeAllDiv();
}

# ABC - for main page stats
sub getNpPhylum {
   my($dbh) =@_;
        my $rclause   = WebUtil::urClause('t.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
         my $sql = qq{
            select replace(replace(t.domain, 'GFragment:'), 'Plasmid:'),
                   t.phylum,
                   count(distinct nbs.compound_oid)
            from taxon t, bio_cluster_new bc,
                 np_biosynthesis_source nbs
            where nbs.cluster_id = bc.cluster_id
            and bc.taxon = t.taxon_oid
            $rclause 
            $imgClause 
            group by replace(replace(t.domain, 'GFragment:'), 'Plasmid:'), 
                     t.phylum
            };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %val_h;
    for ( ; ; ) {
        my ( $v1, $v2, $cnt1 ) = $cur->fetchrow();
        last if !$v1;

            my $domain = substr( $v1, 0, 1 );
            my $str1 = $domain . ". " . $v2;
            if ( $val_h{$str1} ) {
                $val_h{$str1} += $cnt1;
            } else {
                $val_h{$str1} = $cnt1;
            }
    }
    return \%val_h;
}

sub printNpPhylum {
    my ( $dbh, $stat_type, $print ) = @_;
    my $new_url = "$main_cgi?section=NaturalProd&page=list";

    my $sql;
    if ( $stat_type eq 'SM Activity' ) {
        $sql = qq{
            select md.name, md.name,
                   count(distinct ia.compound_oid)
            from img_compound_activity ia, 
                 np_biosynthesis_source nbs,
                 mesh_dtree md
            where nbs.compound_oid = ia.compound_oid
            and ia.activity = md.node
            group by md.name, md.name
            };
    } elsif ( $stat_type eq 'Phylum' ) {
        my $rclause   = WebUtil::urClause('t.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
        $sql = qq{
            select replace(replace(t.domain, 'GFragment:'), 'Plasmid:'),
                   t.phylum,
                   count(distinct nbs.compound_oid)
            from taxon t, bio_cluster_new bc,
                 np_biosynthesis_source nbs
            where nbs.cluster_id = bc.cluster_id
            and bc.taxon = t.taxon_oid
            $rclause 
            $imgClause 
            group by replace(replace(t.domain, 'GFragment:'), 'Plasmid:'), 
                     t.phylum
            };
    } else {
        $sql = qq{
            select md.name, md.name,
                   count(distinct icmt.compound_oid)
            from img_compound_meshd_tree icmt, 
                 np_biosynthesis_source nbs, mesh_dtree md
            where nbs.compound_oid = icmt.compound_oid
            and md.node = icmt.node
            group by md.name, md.name
            };
    }

    # if using 1-up parent, replace md.node = icmt.mode by:
    #            and md.node = substr(icmt.node, 1,
    #                 length(icmt.node) - instr(reverse(icmt.node), '.'))

    my %val_h;
    my $maxcount = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $v1, $v2, $cnt1 ) = $cur->fetchrow();
        last if !$v1;

        if($cnt1 > $maxcount) {
            $maxcount = $cnt1;
        }

        if (   $stat_type eq 'SM Activity'
            || $stat_type eq 'SM Type' )
        {
            $val_h{$v1} = $cnt1;
        } elsif ( $stat_type eq 'Phylum' ) {
            my $domain = substr( $v1, 0, 1 );
            my $str1 = $domain . ". " . $v2;
            if ( $val_h{$str1} ) {
                $val_h{$str1} += $cnt1;
            } else {
                $val_h{$str1} = $cnt1;
            }
        }
    }
    $cur->finish();

    my $tmp = $stat_type;
    $tmp =~ s/\s+/_/g;
    my $it = new InnerTable( 1, $tmp . "_NPstats$$", $tmp . "_NPstats", 0 );
    $it->addColSpec( $stat_type, "char asc", "left" );
    $it->addColSpec( "SM Count", "number asc", "right" );
    if($stat_type eq 'SM Activity') {
        $it->addColSpec("Histogram");
    }
    my $sd = $it->getSdDelim();

    my $idx = 0;
    
    my (@cat, @item);
    for my $k1 (sort keys %val_h ) {
        my $cnt1 = $val_h{$k1};
        my $r    = $k1 . $sd . $k1 . "\t";
        my $url2 = "$main_cgi?section=NaturalProd&page=subCategory" . "&stat_type=$stat_type&stat_val=$k1";
        $r .= $cnt1 . $sd . alink( $url2, $cnt1 ) . "\t";
        
        if($stat_type eq 'SM Activity') {
             my $per = $cnt1 * 100 / $maxcount;
             $r .= $sd . histogramBar($per , 1 ) . "\t";
        }
        
        $it->addRow($r);
        $idx++;
        
        push(@cat, $k1);
        push(@item, $cnt1);
    }
    $cur->finish();
    $it->hideAll();    # if $idx < 50;
    $it->printOuterTable(1) if($print);

    return  (\@cat, \@item, $it);
}

sub printStats {
    my ($show_title) = @_;
    $show_title = 0 if $show_title eq "";
    if ($show_title) {
        print "<h1>Secondary Metabolites - Summary Stats</h1>";
    }

    printMainForm();

    my $indent = nbsp(4);
    my $dbh = dbLogin();

    print "<table class='img'  border='0' cellspacing='3' cellpadding='0'>\n";

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'><b>Secondary Metabolite (SM) Statistics</b>$indent</th>\n");
    printf("<th class='subhead' align='right'><b>Number</b>$indent</th>\n");
    printf("</tr>\n");

    my $rclause   = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');
    my $sql       = qq{
        select count (distinct nbs.compound_oid)
        from np_biosynthesis_source nbs, bio_cluster_new bc
        where nbs.cluster_id is not null
        and nbs.cluster_id = bc.cluster_id
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $np_cnt ) = $cur->fetchrow();
    $cur->finish();

    my $nps = alink("$section_cgi&page=npListing", $np_cnt);
    printf("<tr class='img'>\n");
    printf("<td class='img'>%sTotal</td>\n", $indent);
    printf("<td class='img' align='right'>%s</td>\n", $nps);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byNPType = alink("$main_cgi?section=MeshTree&page=nptype", "by SM Type");
    printf("<td class='img'>%s$byNPType</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byNPActivity = alink("$main_cgi?section=MeshTree&page=acttree", "by SM Activity");
    printf("<td class='img'>%s$byNPActivity</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byPhylum = alink("$section_cgi&page=byPhylum", "by Phylum");
    printf("<td class='img'>%s$byPhylum</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    print "</table>\n";

    print end_form();
}

sub printAllNaturalProds {
    my ($dbh) = @_;

    print "<h1>Secondary Metabolite (SM) Statistics</h1>";
    my $search_url = "$main_cgi?section=BcSearch&page=npSearches";
    my $link = alink($search_url, "Search for Secondary Metabolites");
    print "<p>$link";
    my $portal_url = "$main_cgi?section=np";
    my $link = alink($portal_url, "ABC Portal");
    print "<br/>$link</p>";

    printMainForm();

    use TabHTML;
    TabHTML::printTabAPILinks("npDetailTab");

    my @tabIndex = ( "#npdetailtab1", "#npdetailtab2", "#npdetailtab3",
		     "#npdetailtab4", "#npdetailtab5", "#npdetailtab6" );
    my @tabNames = ( "Overview", "by SM Type", "SM Listing",
		     "by SM Activity", "SM Activity Listing", "by Phylum" );
    TabHTML::printTabDiv( "npDetailTab", \@tabIndex, \@tabNames );

    # tab 1
    print "<div id='npdetailtab1'>";
    # for overview:
    print "<br/>";
    printStats();
    print "</div>\n";    # end tab1

    # tab 2
    print "<div id='npdetailtab2'>";
    printNpTree();
    print "</div>\n";    # end tab2

    # tab 3
    print "<div id='npdetailtab3'>";
    print "<br/>";
    listAllNaturalProds( $dbh, 0, 0, '', 1 );
    print "</div>\n";

    # tab 4
    print "<div id='npdetailtab4'>";
    MeshTree::printTreeActDiv();
    print "</div>\n";

    # tab 5
    print "<div id='npdetailtab5'>";
    printActivityListing(0);

    # google chart
    # missing last data set and low counts bars are not showing
    #googleColumnChart($cat_aref, $item_aref);    

    print "</div>\n"; # end tab5

    # tab 6
    print "<div id='npdetailtab6'>";
    # $name - first column name
    # $param - url param value
    # $url - base url
    # $categories - array of item "names" - 1st col
    # $sections_aref - array same as $categories for now
    # $data_aref - array counts
    # $series_aref - not use? array = ( "Count" ) - for bar chart
    # $has_sections - section url 
    printNPByPhylum();
    print "</div>\n";

    TabHTML::printTabDivEnd();
    print end_form();
}

sub printActivityListing {
    my ($show_title) = @_;
    $show_title = 0 if $show_title eq "";
    if ($show_title) {
        print "<h1>Secondary Metabolites - Activity Listing</h1>";
    } 

    my $dbh = dbLogin();
    print qq{
        <script language='JavaScript' type='text/javascript'>
        function showView(type) {
        if (type == 'graphical') {
            document.getElementById('tableView').style.display = 'none';
            document.getElementById('graphicalView').style.display = 'block';
        } else {
            document.getElementById('tableView').style.display = 'block';
            document.getElementById('graphicalView').style.display = 'none';
        }
        }
        </script>
    };

    my ($cat_aref, $item_aref, $it) = printNpPhylum( $dbh, 'SM Activity', 0 );
    my @x = ('Count');
    my $datastr = join(",", @$item_aref);
    my @datas = ($datastr);

    print "<div id='tableView' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
	. " value='Graphical View'"
	. " onclick='showView(\"graphical\")' />";
    print "<br/>";
    print qq{
    <table border='0'> <tr> 
    <td style="vertical-align: top; width: 475px;">
    };

    $it->printOuterTable(1);
    print qq{
    </td>
    <td style="vertical-align: top; padding-left: 20px;">
    };

    print "</td></tr></table>\n";
    print "</div>"; # tableView div

    print "<div id='graphicalView' style='display: none;'>";
    print "<input type='button' class='medbutton' name='view'"
	. " value='Table View'"
	. " onclick='showView(\"table\")' />";
    print "<br/>";

    my $barurl = "$section_cgi&page=subCategory&stat_type=SM Activity";
    use ChartUtil;
    my $url = ChartUtil::printBarChart
	("Activity", "stat_val", "Count", $barurl,
	 $cat_aref, $cat_aref, \@datas, \@x, 0 );
    print "</div>"; # graphicalView div
}

sub printNPByPhylum {
    my $dbh = dbLogin();

    my @a = ("Count");
    my ($cat_aref, $item_aref, $it) = printNpPhylum( $dbh, 'Phylum', 0 );
    my $pieurl = "$section_cgi&page=subCategory&stat_type=Phylum";
    use ChartUtil;
    ChartUtil::printPieChart
        ("Phylum", "stat_val", $pieurl,
         $cat_aref, $cat_aref, $item_aref, \@a, 0, "", "np" );
}

sub googleColumnChart {
    my($xaxis_aref, $yaxis_aref) = @_;
 
    my @data;
    for(my $i=0;$i<=$#$xaxis_aref; $i++) {
        my $str = "['" . $xaxis_aref->[$i] . "'," . $yaxis_aref->[$i] . "]";
        push(@data, $str);
    }
    my $dataStr = join(',', @data);
 
    print <<EOF;

    <div id="chart_div" style="width: 2000px; height: 600px;" ></div>
    <div id='png'></div>
    
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
    google.load("visualization", "1", {packages:["corechart"]});
    google.setOnLoadCallback(drawChart);
    function drawChart() {
	var dataTable = new google.visualization.DataTable();
	dataTable.addColumn('string', 'Year');
	dataTable.addColumn('number', 'Sales');
	// A column for custom tooltip content
        //dataTable.addColumn({type: 'string', role: 'tooltip'});

	dataTable.addRows([$dataStr]);

	var options = {
	    vAxis : {title: 'Count', logScale: true},
	    legend : {position: 'none'}
	};
	var chart_div = document.getElementById('chart_div');
	var chart = new google.visualization.ColumnChart(chart_div);
	chart.draw(dataTable, options);
	
	google.visualization.events.addListener(chart, 'select', function(e) {
	    var y = dataTable.getValue(chart.getSelection()[0]['row'], 0 ); 
            var x = dataTable.getValue(chart.getSelection()[0]['row'], 1 );
            var tt = dataTable.getValue(chart.getSelection()[0]['row'], 2 );
	    alert( y + ', ' + x + '  tooltip: ' + tt );
        }); 

        document.getElementById('png').outerHTML = 
            '<a href="' + chart.getImageURI() + '">Printable version</a>';
    }
    </script>        
    
EOF
}

#######################################################################
# listAllNaturalProds
#######################################################################
sub listAllNaturalProds {
    my ( $dbh, $stat_type, $val, $compIds_ref, $notitle, $subTitle ) = @_;
    $notitle = 0 if $notitle eq "";

    print "<h1>Secondary Metabolite (SM) List</h1>" if !$notitle;

    printMainForm();
    if ( $stat_type && $val ) {
        print "<h2>$stat_type: $val</h2>\n";
    }
    if ( $subTitle ) {
        print $subTitle;
    }

    my $compoundClause;
    if ( $compIds_ref && scalar(@$compIds_ref) > 0 ) {
        my $compIds_str = OracleUtil::getNumberIdsInClause( $dbh, @$compIds_ref );        
        $compoundClause = " and nbs.compound_oid in ( $compIds_str ) ";
    }

    ## Genome Fragment
    my %gf_h;
    my $rclause   = WebUtil::urClause('nbs.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('nbs.taxon_oid');
    my $sql       = qq{
        select nbs.compound_oid, count(distinct nbs.taxon_oid)
        from np_biosynthesis_source nbs
        where nbs.cluster_id is null
        and nbs.taxon_oid is not null
        $compoundClause
        $rclause
        $imgClause
        group by nbs.compound_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $cnt1 ) = $cur->fetchrow();
        last if !$compound_oid;
        $gf_h{$compound_oid} = $cnt1;
    }
    $cur->finish();

    ## BC
    my %bc_h;
    my %bc_taxon_h;
    my $rclause   = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');
    my $sql       = qq{
        select nbs.compound_oid, count(distinct bc.taxon),
               count(distinct bc.cluster_id)
        from np_biosynthesis_source nbs,
             bio_cluster_new bc
        where nbs.cluster_id is not null
        and nbs.cluster_id = bc.cluster_id
        $compoundClause
        $rclause
        $imgClause
        group by nbs.compound_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $t_cnt, $bc_cnt ) = $cur->fetchrow();
        last if !$compound_oid;
        $bc_taxon_h{$compound_oid} = $t_cnt;
        $bc_h{$compound_oid}       = $bc_cnt;
    }
    $cur->finish();

    ## SM activity
    my %act_h;
    my $sql = qq{
        select distinct ca.compound_oid, md.name
        from np_biosynthesis_source nbs, 
             img_compound_activity ca, mesh_dtree md
        where nbs.compound_oid = ca.compound_oid
        and ca.activity = md.node
        $compoundClause
        order by 1, 2
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $act ) = $cur->fetchrow();
        last if !$compound_oid;

        if ( $act_h{$compound_oid} ) {
            $act_h{$compound_oid} .= "; " . $act;
        } else {
            $act_h{$compound_oid} = $act;
        }
    }
    $cur->finish();

    ## SM type
    my %type_h;
    my $sql = qq{
        select distinct icmt.compound_oid, md.name
        from np_biosynthesis_source nbs, 
             img_compound_meshd_tree icmt, mesh_dtree md
        where nbs.compound_oid = icmt.compound_oid
        and md.node = icmt.node
        $compoundClause
        order by 1, 2
    };

    # if using 1-up parent, replace md.node = icmt.mode by:
    #        and md.node = substr(icmt.node, 1,
    #              length(icmt.node) - instr(reverse(icmt.node), '.'))

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $name ) = $cur->fetchrow();
        last if !$compound_oid;

        if ( $type_h{$compound_oid} ) {
            $type_h{$compound_oid} .= "; " . $name;
        } else {
            $type_h{$compound_oid} = $name;
        }
    }
    $cur->finish();

    my $in_str;
    my @binds;
    if ( $stat_type eq 'SM Activity' ) {
        if ( $compoundClause ) {
            $in_str = qq{
                select nbs.compound_oid 
                from np_biosynthesis_source nbs
                where nbs.compound_oid is not null 
                $compoundClause
            };
        }
        else {
            $in_str = qq{
                select nbs.compound_oid 
                from np_biosynthesis_source nbs
                where nbs.compound_oid is not null 
                and nbs.compound_oid in (
                    select ia.compound_oid 
                    from img_compound_activity ia, mesh_dtree md
                    where ia.activity = md.node
                    and md.name = ? 
                )
            };
            push(@binds, $val);            
        }                
    } elsif ( $stat_type eq 'SM Type' && $val ) {
        if ( $compoundClause ) {
            $in_str = qq{
                select nbs.compound_oid 
                from np_biosynthesis_source nbs
                where nbs.compound_oid is not null 
                $compoundClause
            };
        }
        else {
            $in_str = qq{
                select nbs.compound_oid 
                from np_biosynthesis_source nbs
                where nbs.compound_oid is not null 
                and nbs.compound_oid in (
                    select icmt.compound_oid 
                    from img_compound_meshd_tree icmt, mesh_dtree md
                    where md.name = ? 
                    and md.node = icmt.node 
                )
            };
            push(@binds, $val);
        }                

        # if using 1-up parent, replace md.node = icmt.mode by:
        #           and md.node = substr(icmt.node, 1,
        #               length(icmt.node) - instr(reverse(icmt.node), '.')))

    } elsif ( $stat_type eq 'Phylum' ) {

        my $rclause      = WebUtil::urClause('t.taxon_oid');
        my $imgClause    = WebUtil::imgClauseNoTaxon('t.taxon_oid');

        my ( $domain, $phylum ) = split( / /, $val );
        if ( $domain eq 'A.' ) {
            $domain = 'Archaea';
        } elsif ( $domain eq 'B.' ) {
            $domain = 'Bacteria';
        } elsif ( $domain eq 'E.' ) {
            $domain = 'Eukaryota';
        }
        my $domainClause = " and t.domain like '\%" . $domain . "'";

        $in_str = qq{
            select nbs.compound_oid 
            from np_biosynthesis_source nbs, bio_cluster_new bc, taxon t
            where nbs.cluster_id = bc.cluster_id
            and bc.taxon = t.taxon_oid
            and t.phylum = ? 
            $compoundClause
            $domainClause
            $rclause 
            $imgClause 
        };
        push(@binds, $phylum);
    }
    else {
        $in_str = qq{
            select nbs.compound_oid 
            from np_biosynthesis_source nbs
            where nbs.compound_oid is not null
            $compoundClause
        };
    }
    
    $sql = qq{
        select c.compound_oid, c.compound_name, 
            c.formula, c.num_atoms, c.mol_weight
        from img_compound c
        where c.compound_oid in ( $in_str )
    };

    my $it = new InnerTable( 1, "NPlist$$", "NPlist", 1 );

    #$it->addColSpec( "Selection" );
    $it->addColSpec( "SM ID",                          "asc", "right" );
    $it->addColSpec( "Secondary Metabolite (SM) Name", "asc", "left" );
    $it->addColSpec( "SM Type",                        "asc", "left" );
    $it->addColSpec( "SM Activity",                    "asc", "left" );
    $it->addColSpec( "Formula",                        "asc", "left" );
    $it->addColSpec( "Number of Atoms", "number asc", "right" );
    $it->addColSpec( "Molecular Weight",     "number asc", "right" );
    $it->addColSpec( "Biosynthetic Cluster Count",     "asc", "right" );
    $it->addColSpec( "Genome Count",                   "asc", "right" );
    my $sd = $it->getSdDelim();

    $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $cnt = 0;
    for ( ; ; ) {
        my ( $compound_oid, $np_name, $formula, $num_atoms, $mol_weight )
	    = $cur->fetchrow();
        last if !$compound_oid;

        my $r = "";

        #$r .= $sd . "<input type='checkbox' name='func_id' value='NP:$np_id' />\t";

        my $url = "$main_cgi?section=ImgCompound" . "&page=imgCpdDetail&compound_oid=$compound_oid";
        $r .= $compound_oid . $sd . alink( $url, $compound_oid ) . "\t";
        $r .= $np_name . $sd . $np_name . "\t";

        my $np_type = $type_h{$compound_oid};
        if ( $stat_type eq 'SM Type' ) {
            $np_type = highlightMatchName( $np_type, $val );
        }
        $r .= $np_type . $sd . $np_type . "\t";

        my $np_act = $act_h{$compound_oid};
        if ( $stat_type eq 'SM Activity' ) {
            $np_act = highlightMatchName( $np_act, $val ) if (!$compIds_ref);
        }
        $r .= $np_act . $sd . $np_act . "\t";

        $r .= $formula . $sd . $formula . "\t";
        $r .= $num_atoms . $sd . "$num_atoms\t";
        $r .= $mol_weight . $sd . "$mol_weight\t";

        my $bc_cnt = 0;
        if ( $bc_h{$compound_oid} ) {
            $bc_cnt = $bc_h{$compound_oid};
        }
        my $url3 = "$main_cgi?section=NaturalProd&page=npBioClusterList" . "&compound_oid=$compound_oid";
        if ($bc_cnt) {
            $r .= $bc_cnt . $sd . alink( $url3, $bc_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        my $t_cnt = 0;
        if ( $gf_h{$compound_oid} ) {
            $t_cnt += $gf_h{$compound_oid};
        }
        if ( $bc_taxon_h{$compound_oid} ) {
            $t_cnt += $bc_taxon_h{$compound_oid};
        }
        my $url2 = "$main_cgi?section=NaturalProd&page=npTaxonList" . "&compound_oid=$compound_oid";
        if ($t_cnt) {
            $r .= $t_cnt . $sd . alink( $url2, $t_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        $it->addRow($r);
        $cnt++;
    }
    $cur->finish();

    #WebUtil::printFuncCartFooter() if $cnt > 10;
    $it->hideAll() if $cnt < 50;
    $it->printOuterTable(1);

    #WebUtil::printFuncCartFooter();

    printStatusLine( "$cnt SMs loaded.", 2 );

    print qq{
        <p> Rows: $cnt</p>
    };
    print end_form();
   
    #return $cnt;
}

#######################################################################
# printNPActivity
#######################################################################
sub printNPActivity {
    my ($dbh) = @_;

    printMainForm();
    my $activity = param('activity');
    listAllNaturalProds( $dbh, 'SM Activity', $activity );
    print end_form();
}

#######################################################################
# printNPTaxonList
#######################################################################
sub printNPTaxonList {
    my ($compound_oid) = @_;

    print "<h1>SM Genome List</h1>";

    printMainForm();
    if ( !$compound_oid ) {
        print end_form();
        return;
    }

    my $dbh = dbLogin();
    printCompoundNpInfo( $dbh, $compound_oid );

    ## genomes
    my $it = new InnerTable( 1, "NPlist$$", "NPlist", 1 );

    #$it->addColSpec( "Selection" );
    $it->addColSpec( "Genome",     "asc", "left" );
    $it->addColSpec( "Cluster ID", "asc", "left" );
    $it->addColSpec( "Gene Count", "asc", "right" );
    my $sd = $it->getSdDelim();

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');

    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, ts.cds_genes
        from np_biosynthesis_source nbs, taxon t, taxon_stats ts
        where nbs.compound_oid = ?
        and nbs.cluster_id is null
        and nbs.taxon_oid = t.taxon_oid
        and t.taxon_oid = ts.taxon_oid
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );

    my $cnt = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $gene_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        my $r = "";

        my $url2 = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_name . $sd . alink( $url2, $taxon_name ) . "\t";

        $r .= "-" . $sd . "-" . "\t";

        my $url2 = "$main_cgi?section=TaxonDetail" . "&page=proteinCodingGenes&taxon_oid=$taxon_oid";
        if ($gene_cnt) {
            $r .= $gene_cnt . $sd . alink( $url2, $gene_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        $it->addRow($r);
        $cnt++;
    }
    $cur->finish();

    my $sql = qq{
        select bc.cluster_id, bc.taxon, t.taxon_display_name,
               count(distinct bcf.feature_id)
        from np_biosynthesis_source nbs,
             bio_cluster_new bc, taxon t, bio_cluster_features_new bcf
        where nbs.compound_oid = ?
        and nbs.cluster_id = bc.cluster_id
        and bc.taxon = t.taxon_oid
        and bcf.cluster_id = bc.cluster_id
        and bcf.feature_type = 'gene'
        $rclause
        $imgClause
        group by bc.cluster_id, bc.taxon, t.taxon_display_name
        };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );

    for ( ; ; ) {
        my ( $bc_id, $taxon_oid, $taxon_name, $gene_cnt ) = $cur->fetchrow();
        last if !$bc_id;

        my $r = "";

        my $url2 = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_name . $sd . alink( $url2, $taxon_name ) . "\t";

        my $url = "$main_cgi?section=BiosyntheticDetail" . "&page=cluster_detail&taxon_oid=$taxon_oid&cluster_id=$bc_id";
        $r .= $bc_id . $sd . alink( $url, $bc_id ) . "\t";

        if ($gene_cnt) {
            $r .= $gene_cnt . $sd . alink( $url, $gene_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        $it->addRow($r);
        $cnt++;
    }
    $cur->finish();

    print "<h2>Genome List</h2>\n";
    $it->hideAll() if $cnt < 50;
    $it->printOuterTable(1);

    print end_form();
    printStatusLine( "$cnt rows loaded.", 2 );
}

#######################################################################
# printNPBioClusterList
#######################################################################
sub printNPBioClusterList {
    my ($compound_oid) = @_;

    print "<h1>SM Biosynthetic Cluster List</h1>";

    printMainForm();
    if ( !$compound_oid ) {
        print end_form();
        return;
    }

    my $dbh = dbLogin();
    printCompoundNpInfo( $dbh, $compound_oid );

    ## BC
    my $sql = qq{
        select distinct cluster_id, evidence
        from bio_cluster_data_new
    };
    my $cur = execSql($dbh, $sql, $verbose);
    my %bc2evidence;
    for ( ;; ) {
        my ($bc_id, $attr_val) = $cur->fetchrow();
        last if !$bc_id;
        $bc2evidence{ $bc_id } = $attr_val;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql       = qq{
        select bc.cluster_id, bc.taxon, t.taxon_display_name,
               count(distinct bcf.feature_id)
        from np_biosynthesis_source nbs,
             bio_cluster_new bc, taxon t, bio_cluster_features_new bcf
        where nbs.compound_oid = ?
        and nbs.cluster_id = bc.cluster_id
        and bc.taxon = t.taxon_oid
        and bcf.cluster_id = bc.cluster_id
        and bcf.feature_type = 'gene'
        $rclause
        $imgClause
        group by bc.cluster_id, bc.taxon, t.taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );

    my $it = new InnerTable( 1, "NPlist$$", "NPlist", 1 );

    #$it->addColSpec( "Selection" );
    $it->addColSpec( "Cluster ID", "asc", "left" );
    $it->addColSpec( "Genome",     "asc", "left" );
    $it->addColSpec( "Evidence",   "asc", "left" );
    $it->addColSpec( "Gene Count", "asc", "right" );
    my $sd = $it->getSdDelim();

    my $cnt = 0;
    for ( ; ; ) {
        my ( $bc_id, $taxon_oid, $taxon_name, $gene_cnt ) = $cur->fetchrow();
        last if !$bc_id;

        my $r = "";

        my $url = "$main_cgi?section=BiosyntheticDetail"
	    . "&page=cluster_detail&taxon_oid=$taxon_oid&cluster_id=$bc_id";
        $r .= $bc_id . $sd . alink( $url, $bc_id ) . "\t";

        my $url2 = "$main_cgi?section=TaxonDetail" 
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_name . $sd . alink( $url2, $taxon_name ) . "\t";

	my $attr_val = $bc2evidence{ $bc_id };
	$r .= $attr_val . $sd . $attr_val . "\t";
        if ($gene_cnt) {
            $r .= $gene_cnt . $sd . alink( $url, $gene_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        $it->addRow($r);
        $cnt++;
    }
    $cur->finish();

    print "<h2>Biosynthetic Cluster List</h2>\n";
    $it->hideAll() if $cnt < 50;
    $it->printOuterTable(1);

    print end_form();
    printStatusLine( "$cnt clusters loaded.", 2 );
}

#######################################################################
# printCompoundNpInfo
#######################################################################
sub printCompoundNpInfo {
    my ( $dbh, $compound_oid ) = @_;

    if ( !$compound_oid ) {
        return;
    }

    my $sql = qq{
        select c.compound_oid, c.compound_name, c.formula,
               c.np_class, c.np_sub_class
        from img_compound c
        where compound_oid = ?
        };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    my ( $compound_oid, $np_name, $formula, $np_class, $np_subclass )
	= $cur->fetchrow();
    $cur->finish();

    print "<h2>Secondary Metabolite (SM) Information</h2>\n";

    print "<table class='img' border='1'>\n";
    my $url = "$main_cgi?section=ImgCompound" 
	    . "&page=imgCpdDetail&compound_oid=$compound_oid";
    #printAttrRowRaw( "Compound Object ID", alink($url, $compound_oid) );
    my $indent = nbsp(4);
    my $attrName = "Compound Object ID".$indent;
    my $link = alink($url, $compound_oid);
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>".$attrName."</th>\n";
    print "  <td class='img' align='right'>" . $link . "</td>\n";
    print "</tr>\n";

    printAttrRow( "SM Name",     $np_name );
    printAttrRow( "Formula",     $formula );
    printAttrRow( "SM Class",    $np_class );
    printAttrRow( "SM Subclass", $np_subclass );

    my $compound_act = "";
    my $sql          = qq{
        select ca.compound_oid, ca.activity
        from img_compound_activity ca
        where ca.compound_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_oid );
    for ( ; ; ) {
        my ( $cid, $act ) = $cur->fetchrow();
        last if !$cid;

        if ($compound_act) {
            $compound_act .= $act;
        } else {
            $compound_act = $act;
        }
    }
    $cur->finish();

    printAttrRow( "SM Activity", $compound_act );
    print "</table>\n";
}

##########################################################################
# printTaxonNP: print SM detail for a genome fragment
##########################################################################
sub printTaxonNP {
    my $np_id = param('np_id');
    if ( !$np_id ) {
        $np_id = param('gold_np_id');
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select taxon, cluster_id, np_product_name
        from natural_product
        where np_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $np_id );
    my ( $taxon_oid, $cluster_id, $np_name ) = $cur->fetchrow();
    $cur->finish();

    # Note: taxon id in natural_product table is related to GFragm
    #       therefore, get cluster_id and look in bio_cluster_new table
    #       for correct taxon id
    if ($cluster_id) {
        my $sql = qq{
	    select bc.taxon
	    from bio_cluster_new bc
	    where bc.cluster_id = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
        ($taxon_oid) = $cur->fetchrow();
        $cur->finish();
    }
    return if !$taxon_oid;

    checkTaxonPerm( $dbh, $taxon_oid );

    $sql = qq{
        select taxon_display_name, in_file
        from taxon where taxon_oid = ?
    };
    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Secondary Metabolite (SM) Information</h1>";
    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );

    my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p style='width: 650px;'>Genome: " . alink( $taxon_url, $taxon_name );
    my $url2 = "main.cgi?section=BiosyntheticDetail&page=cluster_detail" . "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
    print "<br/>Cluster ID: " . alink( $url2, $cluster_id ) if $cluster_id;
    if ($cluster_id) {
        print hiddenVar( 'cluster_id', $cluster_id );
    }

    my $gene_tab = "Genes in Genome";
    if ($cluster_id) {
        $gene_tab = "Genes in Cluster";
    }

    use TabHTML;
    TabHTML::printTabAPILinks("npDetailTab");
    my @tabIndex = ( "#npdetailtab1", "#npdetailtab2", "#npdetailtab3", "#npdetailtab4", "#npdetailtab5" );
    my @tabNames = ( $gene_tab, "Secondary Metabolite", "IMG Pathways", "MetaCyc", "KEGG" );
    TabHTML::printTabDiv( "npDetailTab", \@tabIndex, \@tabNames );

    print "<div id='npdetailtab1'>";
    if ($cluster_id) {
        BiosyntheticDetail::printBioClusterGeneList( $taxon_oid, $cluster_id );
    } else {
        printTaxonGeneList($taxon_oid);
    }
    print "</div>";    # end npdetailtab1

    print "<div id='npdetailtab2'>";
    my %compound_h;
    my %alias_h;
    printNPDetail( $dbh, $np_id, \%compound_h, \%alias_h );
    print "</div>";    # end npdetailtab1

    print "<div id='npdetailtab3'>";
    my $test_new = 1;
    if ( $in_file eq 'Yes' ) {
        print "<h2>IMG Pathways</h2>\n";
        print "<p>No IMG Pathways.\n";
    } elsif ($cluster_id) {
        BiosyntheticDetail::printClusterPathwayList( $dbh, $taxon_oid, $cluster_id, 0, $np_name );
    } elsif ($test_new) {
        BiosyntheticDetail::printClusterPathwayList( $dbh, $taxon_oid, 0, 0, $np_name );
    } else {
        print "<h2>Predicted IMG Compounds from Pathway Assertion</h2>\n";

        # get all terms in this genome
        my %all_term_h;
        my @all_term_oids;
        $sql = qq{
          select distinct gif.function
          from gene_img_functions gif
          where gif.taxon = ?
    };
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ($term_oid) = $cur->fetchrow();
            last if !$term_oid;
            push( @all_term_oids, $term_oid );
            $all_term_h{$term_oid} = $term_oid;
        }
        $cur->finish();
        foreach my $t2 (@all_term_oids) {
            my $term_list = ImgPwayBrowser::findAllChildTerms( $dbh, $t2 );
            if ($term_list) {
                my @p_terms = split( /\t/, $term_list );
                for my $p2 (@p_terms) {
                    $all_term_h{$p2} = $p2;
                }
            }
        }    # end for t2

        @all_term_oids = ( keys %all_term_h );
        if ( scalar(@all_term_oids) == 0 ) {
            print "<p>No related IMG Pathways.\n";
            print end_form();
        } elsif ( scalar(@all_term_oids) > 1000 ) {

            # shouldn't happen
            print "<p>Too many IMG terms!\n";
            print end_form();
        } else {
            my $term_list = join( ",", @all_term_oids );

            $sql = qq{
        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name,
               ipa.status, ipr.rxn
        from img_reaction_catalysts irc, img_pathway_reactions ipr, 
             img_pathway ipw, img_pathway_assertions ipa
        where irc.catalysts in ( $term_list )
        and irc.rxn_oid = ipr.rxn
        and ipr.pathway_oid = ipw.pathway_oid
        and ipw.pathway_oid = ipa.pathway_oid
        and ipa.taxon = ?
        union
        select ipw.pathway_oid pathway_oid,
               ipw.pathway_name pathway_name, ipa.status, ipr.rxn
        from img_reaction_t_components itc, img_pathway_reactions ipr, 
             img_pathway ipw, img_pathway_assertions ipa
        where itc.term in ( $term_list )
        and itc.rxn_oid = ipr.rxn
        and ipr.pathway_oid = ipw.pathway_oid
        and ipw.pathway_oid = ipa.pathway_oid
        and ipa.taxon = ?
        };

            $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
            my $prev_pathway = 0;
            my $prev_name;
            my $prev_status;
            my $rxn_str = "";
            for ( ; ; ) {
                my ( $pathway_oid, $pathway_name, $status, $rxn ) = $cur->fetchrow();
                last if !$pathway_oid;

                if ( $pathway_oid == $prev_pathway ) {

                    # same pathway
                    if ($rxn_str) {
                        $rxn_str .= ", " . $rxn;
                    } else {
                        $rxn_str = $rxn;
                    }
                } else {

                    # different pathway
                    if ( $prev_pathway && $rxn_str ) {
                        print "<h4>Pathway $prev_pathway: $prev_name</h4>\n";
                        my $p_url =
                            "$main_cgi?section=ImgPwayBrowser"
                          . "&page=pwayTaxonDetail"
                          . "&pway_oid=$prev_pathway"
                          . "&taxon_oid=$taxon_oid";
                        print "<p>Pathway Assertion: " . alink( $p_url, $prev_status ) . "\n";
                        printPathwayCompound( $dbh, $prev_pathway, $rxn_str, \%compound_h );
                    }

                    # reset
                    $prev_pathway = $pathway_oid;
                    $rxn_str      = $rxn;
                    $prev_name    = $pathway_name;
                    $prev_status  = $status;
                }
            }
            $cur->finish();

            if ( $prev_pathway && $rxn_str ) {
                print "<h4>Pathway $prev_pathway: $prev_name</h4>\n";
                my $p_url =
                    "$main_cgi?section=ImgPwayBrowser"
                  . "&page=pwayTaxonDetail&pway_oid=$prev_pathway"
                  . "&taxon_oid=$taxon_oid";
                print "<p>Pathway Assertion: " . alink( $p_url, $prev_status ) . "\n";
                printPathwayCompound( $dbh, $prev_pathway, $rxn_str, \%compound_h );
            }
        }
    }                  # end if ($cluster_id ne "")
    print "</div>";    # end npdetailtab3

    print "<div id='npdetailtab4'>";
    if ($cluster_id) {
        if ( $in_file eq 'Yes' ) {
            BiosyntheticDetail::printClusterMetacycList_meta( $taxon_oid, $cluster_id );
        } else {
            BiosyntheticDetail::printClusterMetacycList( $taxon_oid, $cluster_id );
        }

    } else {
        print "<h2>MetaCyc Pathways</h2>\n";
        my $p_cnt = printMetaCycPathway( $dbh, $taxon_oid, $cluster_id, \%alias_h );
        if ( !$p_cnt ) {
            print "<p>No MetaCyc Pathways.\n";
        }
    }
    print "</div>";    # end npdetailtab4

    print "<div id='npdetailtab5'>";
    if ($cluster_id) {
        if ( $in_file eq 'Yes' ) {
            BiosyntheticDetail::printClusterKEGGList_meta( $taxon_oid, $cluster_id );
        } else {
            BiosyntheticDetail::printClusterKEGGList( $taxon_oid, $cluster_id );
        }
    } else {
        print "<h2>KEGG Pathways</h2>\n";
        my $p_cnt = printKeggPathway( $dbh, $taxon_oid, 0, \%alias_h, \%compound_h );
        if ( !$p_cnt ) {
            print "<p>No KEGG Pathways.\n";
        }
    }
    print "</div>";    # end npdetailtab5

    TabHTML::printTabDivEnd();
    print end_form();
}

############################################################
# printTaxonGeneList: for GF
############################################################
sub printTaxonGeneList {
    my ($taxon_oid) = @_;

    my $it = new InnerTable( 1, "geneSet$$", "geneSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Pfam Info",         "asc", "left" );
    $it->addColSpec( "Best Hit Gene",     "asc", "right" );
    $it->addColSpec( "Best Hit Genome",   "asc", "left" );
    my $sd = $it->getSdDelim();

    my $dbh = dbLogin();

    ## get gene-pfam
    my $pfam_base_url = $env->{pfam_base_url};
    my %gene_pfam_h;
    my $sql = qq{                                                             
            select distinct gpf.gene_oid,
                   gpf.pfam_family, pf.description                             
            from pfam_family pf,                     
                 gene_pfam_families gpf                                        
            where gpf.taxon = ?
            and gpf.pfam_family = pf.ext_accession                             
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $gene_oid, $pfam_id, $pfam_name ) = $cur->fetchrow();
        last if ( !$gene_oid );

        my $str = "$pfam_id\t$pfam_name";
        if ( $gene_pfam_h{$gene_oid} ) {
            $gene_pfam_h{$gene_oid} .= "\n" . $str;
        } else {
            $gene_pfam_h{$gene_oid} = $str;
        }
    }
    $cur->finish();

    my %bbh_gene;
    my %bbh_taxon;
    my %taxon_name_h;
    getTaxonBestHit_bbh( $dbh, $taxon_oid, \%bbh_gene, \%bbh_taxon, \%taxon_name_h );

    my $sql = qq{
          select g.gene_oid, g.locus_tag, g.gene_display_name
          from gene g
          where g.taxon = ?
          };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $row = 0;
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_name ) = $cur->fetchrow();
        last if !$gene_oid;

        my $r = $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' /> \t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $gene_name . $sd . $gene_name . "\t";

        my $str = "";
        my @lines = split( /\n/, $gene_pfam_h{$gene_oid} );
        foreach my $line (@lines) {
            my ( $pfam_id, $pfam_name ) =
              split( /\t/, $line, 2 );

            if ($str) {
                $str .= "; ";
            }

            if ($pfam_id) {
                my $ext_accession2 = $pfam_id;
                $ext_accession2 =~ s/pfam/PF/;
                my $url = "$pfam_base_url$ext_accession2";
                $str .= alink( $url, $pfam_id ) . " " . $pfam_name;
            } else {
                $str .= "-";
            }
        }
        $r .= $str . $sd . $str . "\t";

        if ( $bbh_gene{$gene_oid} ) {
            my $gene2 = $bbh_gene{$gene_oid};
            my $url2  = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene2";
            $r .= $gene2 . $sd . alink( $url2, $gene2 ) . "\t";
        } else {
            $r .= "-" . $sd . "-" . "\t";
        }

        if ( $bbh_taxon{$gene_oid} ) {
            my $taxon2 = $bbh_taxon{$gene_oid};
            my $url2   = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon2";
            $r .= $taxon_name_h{$taxon2} . $sd . alink( $url2, $taxon_name_h{$taxon2} ) . "\t";
        } else {
            $r .= "-" . $sd . "-" . "\t";
        }

        $it->addRow($r);
        $row++;
    }
    $cur->finish();

    WebUtil::printGeneCartFooter() if ( $row > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    ## protein domain display
    my $maxGeneProfileIds = 100;
    my $super_user_flag   = getSuperUser();
    if ( $super_user_flag eq 'Yes' ) {
        print "<div id='geneprotein'>";
        print "<h2>Display Protein Domains of Selected Genes</h2>\n";
        print "<p><font color='red'>This feature is available for super users only.</font>\n";
        print "<p>Select 1 to $maxGeneProfileIds genes to view protein domains.<br/>\n";
        my $name = "_section_WorkspaceGeneSet_viewProteinDomain";
        print submit(
            -name  => $name,
            -value => 'View Protein Domains',
            -class => 'meddefbutton'
        );
        print "</div>\n";
    }

    ## find similar BCs and GFs
    if ( $super_user_flag eq 'Yes' ) {
        print "<div id='geneprotein'>";
        print "<h2>Find Similar Biosynthetic Clusters</h2>\n";
        print "<p><font color='red'>This feature is available for super users only.</font>\n";
        print "<p>Select one or more genes to search. "
          . "The result is based on Pfams associated with the selected gene(s).<br/>\n";
        my $name = "_section_BiosyntheticDetail_findSimilarBCGF";
        print submit(
            -name  => $name,
            -value => 'Find Similar Clusters',
            -class => 'meddefbutton'
        );
        print "</div>\n";
    }
}

sub getTaxonBestHit_bbh {
    my ( $dbh, $taxon_oid, $bbh_gene_h, $bbh_taxon_h, $taxon_name_h ) = @_;

    my $bbh_dir = $env->{bbh_zfiles_dir};
    $taxon_oid = sanitizeInt($taxon_oid);
    my $bbh_file_name = $bbh_dir . "/" . $taxon_oid . ".zip";

    if ( !blankStr($bbh_file_name) && ( -e $bbh_file_name ) ) {

        # yes, we have file
    } else {
        return;
    }

    my %public_taxons;
    my $sql = qq{
        select taxon_oid, taxon_display_name
        from taxon
        where is_public = 'Yes'
        and obsolete_flag = 'No'
        and genome_type = 'isolate'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $public_taxons{$taxon_oid} = $taxon_name;
    }
    $cur->finish();

    unsetEnvPath();

    my $sql = qq{
        select g.gene_oid, g.locus_tag, g.gene_display_name
        from gene g
        where g.taxon = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_name ) = $cur->fetchrow();
        last if ( !$gene_oid );

        # open file
        my $rfh = newUnzipFileHandle( $bbh_file_name, $gene_oid, "getBBHZipFiles" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );
            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

            if ( $staxon && $public_taxons{$staxon} ) {
                $bbh_gene_h->{$gene_oid}  = $sgene_oid;
                $bbh_taxon_h->{$gene_oid} = $staxon;
                $taxon_name_h->{$staxon}  = $public_taxons{$staxon};
                last;
            }
        }    # end while
        close $rfh;

    }    # end for
    WebUtil::resetEnvPath();

    $cur->finish();
}

#########################################################################
# getNPID: return np_id based on taxon_oid
#########################################################################
sub getNPID {
    my ( $dbh, $taxon_oid ) = @_;

    #    my $sql = qq{
    #         select gnp.gold_np_id
    #         from project_info_natural_prods\@imgsg_dev gnp
    #         where gnp.img_oid = ?
    #         };
    my $sql = qq{
         select np.np_id
         from natural_product np
         where np.taxon = ?
         };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($np_id) = $cur->fetchrow();
    $cur->finish();

    return $np_id;
}

sub printExperimentalNP {
    my ( $dbh, $np_id ) = @_;

    #    my $sql = qq{
    #         select np.np_id, np.np_product_name, np.np_product_link,
    #                np.img_compound_id, c.compound_name
    #         from project_info_natural_prods\@imgsg_dev gnp,
    #              cvnatural_prods\@imgsg_dev np,
    #              img_compound c
    #         where gnp.gold_np_id = ?
    #         and gnp.np_id = np.np_id
    #         and np.img_compound_id = c.compound_oid (+)
    #         };
    my $sql = qq{
         select np.np_id, np.np_product_name, np.np_product_link, 
                np.compound_oid, c.compound_name
         from natural_product np,
              img_compound c
         where np.np_id = ? 
         and np.compound_oid = c.compound_oid (+)
         };
    my $cur = execSql( $dbh, $sql, $verbose, $np_id );
    for ( ; ; ) {
        my ( $np_id, $np_name, $np_link, $compound_id, $compound_name ) = $cur->fetchrow();
        last if !$np_id;

        if ($np_link) {
            print " " . alink( $np_link, $np_name );
        } else {
            print " " . $np_name;
        }

        if ($compound_id) {
            my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_id";
            print " ( IMG Compound: " . alink( $url, $compound_id ) . " $compound_name )";
        }
        print "<br/>\n";
    }
    $cur->finish();
}

########################################################################
# printGenbankIdNP: print SM info based on genbank_id
########################################################################
sub printGenbankIdNP {
    my ( $dbh, $genbank_id ) = @_;

    #    my $sql = qq{
    #        select gnp.gold_np_id, gnp.project_oid, p.gold_stamp_id,
    #               np.np_id, np.np_product_name, np.np_product_link,
    #               np.img_compound_id, c.compound_name
    #        from project_info_natural_prods\@imgsg_dev gnp,
    #             cvnatural_prods\@imgsg_dev np, project_info\@imgsg_dev p,
    #             img_compound c
    #        where gnp.genbank_id = ?
    #        and gnp.np_id = np.np_id
    #        and gnp.project_oid = p.project_oid
    #        and np.img_compound_id = c.compound_oid (+)
    #    };
    my $sql = qq{
        select np.np_id, np.project_oid, p.gold_stamp_id,
               np.np_product_name, np.np_product_link, 
               np.compound_oid, c.compound_name
        from natural_product np,
             project_info\@imgsg_dev p,
             img_compound c
        where np.genbank_id = ? 
        and np.project_oid = p.project_oid
        and np.compound_oid = c.compound_oid (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $genbank_id );

    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Secondary Metabolite Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    for ( ; ; ) {
        my ( $np_id, $project_oid, $gold_id, $np_name, $np_link, $compound_id, $compound_name ) = $cur->fetchrow();
        last if !$np_id;

        my $url2 = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$np_id";

        use GeneDetail;
        GeneDetail::printAttrRowRaw( "Secondary Metabolite ID", alink( $url2, $np_id ) );

        my $prj_url =
          "https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?" . "section=ProjectInfo&page=displayProject&project_oid=";
        my $prj_link = alink( $prj_url . $project_oid, $project_oid );
        GeneDetail::printAttrRowRaw( "PROJECT_OID", $prj_link );

        my $gold_link;
        if ( !blankStr($gold_id) ) {
            my $url = HtmlUtil::getGoldUrl($gold_id);
            $gold_link = alink( $url, "Project ID: $gold_id" );
        }
        GeneDetail::printAttrRowRaw( "GOLD ID", $gold_link );

        if ($np_link) {
            $np_name = alink( $np_link, $np_name );
        }
        GeneDetail::printAttrRowRaw( "Secondary Metabolite Name", $np_name );

        if ($compound_id) {
            my $url = "$main_cgi?section=ImgCompound" . "&page=imgCpdDetail&compound_oid=$compound_id";
            GeneDetail::printAttrRowRaw( "IMG Compound", alink( $url, $compound_id ) );
        }
    }
    $cur->finish();
    print "</table>";
}

########################################################################
# printBioClusterIdNP: print SM info based on genbank_id
########################################################################
sub printBioClusterIdNP {
    my ( $dbh, $cluster_id ) = @_;

    my $np_cnt = 0;

    #    my $sql = qq{
    #        select gnp.gold_np_id, gnp.project_oid, p.gold_stamp_id,
    #               np.np_id, np.np_product_name, np.np_product_link,
    #               np.np_type, np.np_activity, gnp.modified_by, gnp.mod_date,
    #               np.img_compound_id, c.compound_name
    #        from project_info_natural_prods\@imgsg_dev gnp,
    #             cvnatural_prods\@imgsg_dev np, project_info\@imgsg_dev p,
    #             img_compound c
    #        where gnp.bio_cluster_id = ?
    #        and gnp.np_id = np.np_id
    #        and gnp.project_oid = p.project_oid
    #        and np.img_compound_id = c.compound_oid (+)
    #    };
    my $sql = qq{
        select np.np_id, np.project_oid, p.gold_stamp_id,
               np.np_product_name, np.np_product_link, 
               np.np_type, np.activity, np.modified_by, np.mod_date,
               np.compound_oid, c.compound_name
        from natural_product np,
             project_info\@imgsg_dev p,
             img_compound c
        where np.cluster_id = ? 
        and np.project_oid = p.project_oid
        and np.compound_oid = c.compound_oid (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );

    for ( ; ; ) {
        my (
            $np_id,       $project_oid, $gold_id,  $np_name,     $np_link, $np_type,
            $np_activity, $modified_by, $mod_date, $compound_id, $compound_name
          )
          = $cur->fetchrow();
        last if !$np_id;

        if ($np_cnt) {
            print "<tr class='img'>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "</tr>\n";
        } else {
            print "<table class='img' border='1'>\n";
            print "<tr class='highlight'>\n";
            print "<th class='subhead' align='center'>";
            print "<font color='darkblue'>\n";
            print "Secondary Metabolite Information</th>\n";
            print "</font>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "</tr>\n";
        }

        my $url2 = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$np_id";

        use GeneDetail;
        GeneDetail::printAttrRowRaw( "Secondary Metabolite (SM) ID", alink( $url2, $np_id ) );

        my $prj_url =
          "https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?" . "section=ProjectInfo&page=displayProject&project_oid=";
        my $prj_link = alink( $prj_url . $project_oid, $project_oid );
        GeneDetail::printAttrRowRaw( "PROJECT_OID", $prj_link );

        my $gold_link;
        if ( !blankStr($gold_id) ) {
            my $url = HtmlUtil::getGoldUrl($gold_id);
            $gold_link = alink( $url, "Project ID: $gold_id" );
        }
        GeneDetail::printAttrRowRaw( "GOLD ID", $gold_link );

        if ($np_link) {
            $np_name = alink( $np_link, $np_name );
        }
        GeneDetail::printAttrRowRaw( "Secondary Metabolite Name", $np_name );

        if ($compound_id) {
            my $url = "$main_cgi?section=ImgCompound" . "&page=imgCpdDetail&compound_oid=$compound_id";
            GeneDetail::printAttrRowRaw( "IMG Compound", alink( $url, $compound_id ) );
        }

        if ($np_type) {
            GeneDetail::printAttrRowRaw( "Secondary Metabolite Type", $np_type );
        }
        if ($np_activity) {
            GeneDetail::printAttrRowRaw( "Activity", $np_activity );
        }

        if ($modified_by) {
            my $sql2   = "select name from contact where contact_oid = ?";
            my $cur2   = execSql( $dbh, $sql2, $verbose, $modified_by );
            my ($str2) = $cur2->fetchrow();
            $cur2->finish();

            if ($mod_date) {
                $str2 .= " (" . $mod_date . ")";
            }
            GeneDetail::printAttrRowRaw( "Modified_by", $str2 );
        }

        $np_cnt++;
    }
    $cur->finish();

    if ($np_cnt) {
        print "</table>";
    }

    return $np_cnt;
}

sub printNPDetail {
    my ( $dbh, $np_id, $compound_href, $alias_href ) = @_;

    #    my $sql = "select evidence, activity, genbank_id " .
    #	" from project_info_natural_prods\@imgsg_dev " .
    #	" where gold_np_id = ?";

    my $sql = qq{
         select np.np_id, np.np_product_name, np.np_product_link,
                np.compound_oid, np.np_type, np.activity,
                np.evidence, np.genbank_id,
                c.compound_name
         from natural_product np,
              img_compound c
         where np.np_id = ? 
         and np.compound_oid = c.compound_oid (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $np_id );
    my ( $np_id, $np_name, $np_link, $compound_id, $np_type, $np_activity, $evidence, $genbank_id, $compound_name ) =
      $cur->fetchrow();
    $cur->finish();

    print hiddenVar( 'func_id', "NP:$np_id" );

    #    print "<table class='img'>\n";
    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Secondary Metabolite Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    use GeneDetail;
    GeneDetail::printAttrRowRaw( "Secondary Metabolite ID", $np_id );

    if ($np_link) {
        GeneDetail::printAttrRowRaw( "Secondary Metabolite Name", alink( $np_link, $np_name ) );
    } else {
        GeneDetail::printAttrRowRaw( "Secondary Metabolite Name", $np_name );
    }

    if ($alias_href) {
        my $name2 = lc( strTrim($np_name) );
        $alias_href->{$name2} = 1;
    }

    if ($compound_id) {
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_id";
        GeneDetail::printAttrRowRaw( "IMG Compound", alink( $url, $compound_id ) . " $compound_name" );

        if ($compound_href) {
            $compound_href->{$compound_id} = 1;
        }

        if ($alias_href) {
            my $name2 = lc( strTrim($compound_name) );
            $alias_href->{$name2} = 1;

            my $sql3 = "select compound_oid, aliases from img_compound_aliases " . "where compound_oid = ? ";
            my $cur3 = execSql( $dbh, $sql3, $verbose, $compound_id );
            for ( ; ; ) {
                my ( $id3, $alias3 ) = $cur3->fetchrow();
                last if !$id3;

                if ($alias3) {
                    my $name3 = lc($alias3);
                    $alias_href->{$name3} = 1;
                }
            }
            $cur3->finish();
        }
    }

    GeneDetail::printAttrRowRaw( "Evidence", $evidence );
    if ($np_type) {
        GeneDetail::printAttrRowRaw( "SM Type", $np_type );
    }
    if ($np_activity) {
        GeneDetail::printAttrRowRaw( "Activity", $np_activity );
    }
    if ($genbank_id) {
        my $gbk_url = $ncbi_base_url . $genbank_id;
        GeneDetail::printAttrRowRaw( "Genbank ID", alink( $gbk_url, $genbank_id ) );
    }
    print "</table>\n";

    #my $name = "_section_FuncCartStor_addToFuncCart";
    #print submit(
    #      -name  => $name,
    #      -value => "Add to Function Cart",
    #      -class => "meddefbutton"
    #);

}

sub printMetaCycPathway {
    my ( $dbh, $taxon_oid, $cluster_id, $alias_href ) = @_;
    if ( !isInt($taxon_oid) ) {
        return 0;
    }

    my @keys = ();
    if ($alias_href) {
        @keys = ( keys %$alias_href );
    }
    if ( scalar(@keys) == 0 ) {
        return 0;
    }

    ## find compound
    my $name_str = "";
    my $k_cnt    = 0;
    for my $key (@keys) {
        $k_cnt++;
        if ( $k_cnt > 1000 ) {
            last;
        }

        $key = lc($key);
        $key =~ s/'/''/g;    # replace ' with ''
        if ($name_str) {
            $name_str .= ", '" . $key . "'";
        } else {
            $name_str = "'" . $key . "'";
        }
    }

    my %metacyc_pwy_h;
    my %metacyc_comp_h;
    if ($name_str) {
        my $sql2 = qq{
                 select p.unique_id, p.common_name, r.unique_id, r.ec_number
                 from biocyc_pathway p, biocyc_reaction_in_pwys rp,
                      biocyc_reaction r, biocyc_reaction_left_hand left
                 where left.substrate = ?
                 and left.unique_id = r.unique_id
                 and r.unique_id = rp.unique_id
                 and rp.in_pwys = p.unique_id
                 };
        my $sql3 = qq{
                 select p.unique_id, p.common_name, r.unique_id, r.ec_number
                 from biocyc_pathway p, biocyc_reaction_in_pwys rp,
                      biocyc_reaction r, biocyc_reaction_right_hand right
                 where right.substrate = ?
                 and right.unique_id = r.unique_id
                 and r.unique_id = rp.unique_id
                 and rp.in_pwys = p.unique_id
                 };

        my $sql = "select c.unique_id, c.common_name from biocyc_comp c ";
        $sql .= "where lower(c.common_name) in (" . $name_str . ") ";
        $sql .= "or lower(c.systematic_name) in (" . $name_str . ") ";
        $sql .= "or c.unique_id in (select a.unique_id from biocyc_comp_synonyms a ";
        $sql .= " where lower(a.synonyms) in (" . $name_str . ")) ";

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id3, $name3 ) = $cur->fetchrow();
            last if !$id3;

            $metacyc_comp_h{$id3} = $name3;
            my $url3 = "main.cgi?section=MetaCyc&page=compound&unique_id=$id3";
            if ($taxon_oid) {
                $url3 .= "&taxon_oid=$taxon_oid";
            }
            print "<p>Related MetaCyc Compound: " . alink( $url3, $id3 ) . " $name3\n";

            my $cur2 = execSql( $dbh, $sql2, $verbose, $id3 );
            for ( ; ; ) {
                my ( $p_id, $p_name, $r_id, $ec ) = $cur2->fetchrow();
                last if !$p_id;

                # print "<p>LEFT: $p_id, $p_name, $r_id, $ec\n";
                $metacyc_pwy_h{$p_id} = $p_name;
            }
            $cur2->finish();
            $cur2 = execSql( $dbh, $sql3, $verbose, $id3 );
            for ( ; ; ) {
                my ( $p_id, $p_name, $r_id, $ec ) = $cur2->fetchrow();
                last if !$p_id;

                # print "<p>RIGHT: $p_id, $p_name, $r_id, $ec\n";
                $metacyc_pwy_h{$p_id} = $p_name;
            }
            $cur2->finish();
        }
        $cur->finish();
    }

    if ( scalar( keys %metacyc_comp_h ) == 0 ) {
        print "<p>No MetaCyc Compounds.\n";
    }

    my $p_cnt = 0;

    my $rclause       = WebUtil::urClause('g.taxon');
    my $imgClause     = WebUtil::imgClauseNoTaxon('g.taxon');
    my $clusterClause = "";
    if ($cluster_id) {

        #	$clusterClause = " and g.gene_oid in (select bcg.feature_oid " .
        #	    "from biosynth_cluster_features bcg " .
        #	    "where bcg.biosynthetic_oid = $cluster_id) ";
        $clusterClause =
            " and g.gene_oid in (select bcg.gene_oid "
          . "from bio_cluster_features_new bcg "
          . "where bcg.cluster_id = ? and bcg.feature_type = 'gene') ";
    }

    my $bind_id = $taxon_oid;
    my $sql     = qq{
        select bp.unique_id, bp.common_name, count(distinct g.gene_oid)
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        biocyc_reaction br, gene_biocyc_rxns gb, gene g
        where bp.unique_id = ?
        and bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.unique_id = gb.biocyc_rxn
        and br.ec_number = gb.ec_number
        and gb.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        $clusterClause
        group by bp.unique_id, bp.common_name
    };

    $sql = qq{
        select bp.unique_id, bp.common_name, count(distinct g.gene_oid)
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
             gene_biocyc_rxns g
        where bp.unique_id = brp.in_pwys
        and brp.unique_id = g.biocyc_rxn
        and g.taxon = ? 
        $rclause
        $imgClause
        group by bp.unique_id, bp.common_name
    };

    if ($cluster_id) {
        $bind_id = $cluster_id;

        #	$sql = qq{
        #            select bp.unique_id, bp.common_name, count(distinct g.gene_oid)
        #            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        #            gene_biocyc_rxns g, biosynth_cluster_features bcg
        #            where bp.unique_id = brp.in_pwys
        #            and brp.unique_id = g.biocyc_rxn
        #            and bcg.biosynthetic_oid = ?
        #            and bcg.feature_oid = g.gene_oid
        #            $rclause
        #            $imgClause
        #            group by bp.unique_id, bp.common_name
        #        };

        $sql = qq{
            select bp.unique_id, bp.common_name, count(distinct g.gene_oid)
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
            gene_biocyc_rxns g, bio_cluster_features_new bcg
            where bp.unique_id = brp.in_pwys
            and brp.unique_id = g.biocyc_rxn
            and bcg.cluster_id = ?
            and bcg.feature_type = 'gene'
            and bcg.gene_oid = g.gene_oid
            $rclause
            $imgClause
            group by bp.unique_id, bp.common_name
        };
    }

    my $it = new InnerTable( 1, "MetaCycPathways$$", "MetaCycPathways", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "MetaCyc Pathway ID", "asc",  "left" );
    $it->addColSpec( "MetaCyc Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",         "desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $bind_id );
    for ( ; ; ) {
        my ( $pway_id, $pway_name, $gene_count ) = $cur->fetchrow();
        last if !$pway_id;

        # my $pway_url = $metacyc_url . $pway_id;
        my $pway_url = "$main_cgi?section=MetaCyc" . "&page=detail&pathway_id=$pway_id&taxon_oid=$taxon_oid";

        my $found = 0;
        for my $key (@keys) {
            my $str = highlightMatchName( $pway_name, $key );
            if ($str) {
                $p_cnt++;
                my $url = "$main_cgi?section=TaxonDetail" . "&page=metaCycGenes&unique_id=$pway_id&taxon_oid=$taxon_oid";
                my $row;
                $row .= $sd . "<input type='checkbox' name='func_id' " . "value='MetaCyc:$pway_id' /> \t";
                $row .= $pway_id . $sd . alink( $pway_url, $pway_id, "", 1 ) . "\t";
                $row .= $str . $sd . $str . "\t";
                $row .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
                $it->addRow($row);
                $found = 1;
                last;
            }
        }    # end for my key

        #	if ( ! $found && $metacyc_pwy_h{$pway_id} ) {
        if ( !$found ) {
            $p_cnt++;
            my $url = "$main_cgi?section=TaxonDetail" . "&page=metaCycGenes&unique_id=$pway_id&taxon_oid=$taxon_oid";
            my $row;
            $row .= $sd . "<input type='checkbox' name='func_id' " . "value='MetaCyc:$pway_id' /> \t";
            $row .= $pway_id . $sd . alink( $pway_url, $pway_id, "", 1 ) . "\t";
            $row .= $pway_name . $sd . $pway_name . "\t";
            $row .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
            $it->addRow($row);
        }
    }    # end for p2
    $cur->finish();

    if ($p_cnt) {
        $it->printOuterTable(1);
        my $name        = "_section_FuncCartStor_addMetaCycToFuncCart";
        my $buttonLabel = "Add Selected to Function Cart";
        my $buttonClass = "meddefbutton";
        print submit(
            -name  => $name,
            -value => $buttonLabel,
            -class => $buttonClass
        );
    }

    return $p_cnt;
}

sub printKeggPathway {
    my ( $dbh, $taxon_oid, $cluster_id, $alias_href, $compound_href ) = @_;

    my @keys = ();
    if ($alias_href) {
        @keys = ( keys %$alias_href );
    }
    my @compounds = ();
    if ($compound_href) {
        @compounds = ( keys %$compound_href );
    }

    if ( scalar(@keys) == 0 && scalar(@compounds) == 0 ) {
        return 0;
    }

    my $p_cnt = 0;

    my %pathway_h;
    if ( scalar(@compounds) > 0 ) {
        my $c_str = join( ", ", @compounds );
        my $sql   = qq{
              select unique p.pathway_oid, c.compound_oid, c.compound_name
              from kegg_pathway_modules p, kegg_module_compounds kmc,
                   img_compound_kegg_compounds ickc, img_compound c
              where p.modules = kmc.module_id
              and kmc.compounds = ickc.compound
              and ickc.compound_oid = c.compound_oid
              and c.compound_oid in ( $c_str )
              };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $pway_id, $compound_id, $compound_name ) = $cur->fetchrow();
            last if !$pway_id;

            if ( $pathway_h{$pway_id} ) {
                $pathway_h{$pway_id} .= "\t" . $compound_id . ":" . $compound_name;
            } else {
                $pathway_h{$pway_id} = $compound_id . ":" . $compound_name;
            }
        }
        $cur->finish();
    }

    my $rclause       = WebUtil::urClause('g.taxon');
    my $imgClause     = WebUtil::imgClauseNoTaxon('g.taxon');
    my $clusterClause = "";
    if ($cluster_id) {

        #	$clusterClause = " and g.gene_oid in (select bcg.feature_oid " .
        #	    "from biosynth_cluster_features bcg " .
        #	    "where bcg.biosynthetic_oid = $cluster_id) ";
        $clusterClause =
            " and g.gene_oid in (select bcg.gene_oid "
          . "from bio_cluster_features_new bcg "
          . "where bcg.cluster_id = ? and bcg.feature_type = 'gene') ";
    }
    my $sql = qq{
        select pw.pathway_oid, pw.pathway_name, pw.image_id, count( distinct g.gene_oid )
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, gene g 
        where pw.pathway_oid = roi.pathway
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = gk.ko_terms
        and gk.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause 
        $clusterClause
        group by pw.pathway_oid, pw.pathway_name, pw.image_id
    };
    my $cur;
    if ($cluster_id) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $cluster_id );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    }

    my $it = new InnerTable( 1, "KeggPathways$$", "KeggPathways", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "KEGG Pathway ID", "asc",  "left" );
    $it->addColSpec( "KEGG Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",      "desc", "right" );
    $it->addColSpec( "Compound(s)",     "asc",  "left" );
    for ( ; ; ) {
        my ( $pway_id, $pway_name, $map_id, $gene_count ) = $cur->fetchrow();
        last if !$pway_id;

        #	my $pway_url = "$main_cgi?section=KeggPathwayDetail" .
        #	    "&page=keggPathwayDetail&pathway_oid=$pway_id";
        my $pway_url = "$main_cgi?section=KeggMap" . "&page=keggMapRelated&map_id=$map_id&taxon_oid=$taxon_oid";

        if ( $pathway_h{$pway_id} ) {
            $p_cnt++;
            my $url = "$main_cgi?section=TaxonDetail" . "&page=keggPathwayGenes&pathway_oid=$pway_id&taxon_oid=$taxon_oid";

            my $r = $pway_id . $sd . alink( $pway_url, $pway_id ) . "\t";
            $r .= $pway_name . $sd . $pway_name . "\t";
            $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";

            my $str2 = "";
            my @cpds = split( /\t/, $pathway_h{$pway_id} );
            for my $c0 (@cpds) {
                my ( $c1, $c2 ) = split( /\:/, $c0, 2 );
                my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$c1";
                $str2 .= "Compound " . alink( $url, $c1 ) . " ";
                $str2 .= "<font color='red'>$c2</font><br/>\n";
            }
            if ( !$str2 ) {
                $str2 = "-";
            }
            $r .= $str2 . $sd . $str2 . "\t";
            $it->addRow($r);
            next;
        }

        my $found = 0;
        for my $key (@keys) {
            my $str = highlightMatchName( $pway_name, $key );
            if ($str) {
                $p_cnt++;
                my $url =
                  "$main_cgi?section=TaxonDetail" . "&page=keggPathwayGenes&pathway_oid=$pway_id&taxon_oid=$taxon_oid";
                my $r = $pway_id . $sd . alink( $pway_url, $pway_id ) . "\t";
                $r .= $str . $sd . $str . "\t";
                $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
                $r .= "-" . $sd . "-" . "\t";
                $it->addRow($r);
                $found = 1;
                last;
            }
        }
        if ( !$found ) {
            $p_cnt++;
            my $url = "$main_cgi?section=TaxonDetail" . "&page=keggPathwayGenes&pathway_oid=$pway_id&taxon_oid=$taxon_oid";
            my $r = $pway_id . $sd . alink( $pway_url, $pway_id ) . "\t";
            $r .= $pway_name . $sd . $pway_name . "\t";
            $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
            $r .= "-" . $sd . "-" . "\t";
            $it->addRow($r);
        }
    }
    $cur->finish();

    if ($p_cnt) {
        $it->printOuterTable(1);
    }

    return $p_cnt;
}

sub highlightMatchName {
    my ( $str, $matchStr ) = @_;
    my $str_u      = $str;
    my $matchStr_u = $matchStr;
    $str_u      =~ tr/a-z/A-Z/;
    $matchStr_u =~ tr/a-z/A-Z/;

    my $idx = index( $str_u, $matchStr_u );
    my $targetMatchStr = substr( $str, $idx, length($matchStr) );

    #    return escHtml($str) if $idx < 0;
    #    return $str if $idx < 0;
    return "" if $idx < 0;
    my $part1 = escHtml( substr( $str, 0, $idx ) );
    if ( $idx <= 0 ) {
        $part1 = "";
    }
    my $part2 = escHtml($targetMatchStr);
    my $part3 = escHtml( substr( $str, $idx + length($matchStr) ) );
    return $part1 . "<font color='red'><b>" . $part2 . "</b></font>" . $part3;
}

sub printPathwayCompound {
    my ( $dbh, $pathway_oid, $rxn_str, $compound_href ) = @_;

    my $sql = qq{
         select ipr.rxn_order, ipr.rxn, r.is_reversible, ircc.c_type,
                c.compound_oid, c.compound_name
         from img_pathway_reactions ipr, img_reaction r,
              img_reaction_c_components ircc, img_compound c
         where ipr.pathway_oid = ?
         and ipr.rxn = ircc.rxn_oid
         and ircc.rxn_oid = r.rxn_oid
         and ircc.compound = c.compound_oid
         and ircc.main_flag = 'Yes'
         and ipr.rxn in ( $rxn_str )
         order by ipr.rxn_order
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for ( ; ; ) {
        my ( $rxn_order, $rxn_oid, $is_reversible, $c_type, $compound_oid, $compound_name ) = $cur->fetchrow();
        last if !$rxn_oid;

        if ( $is_reversible eq 'Yes' || $c_type eq 'RHS' ) {
            my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$compound_oid";
            print "<p>Reaction $rxn_order $rxn_oid: ($c_type) " . alink( $url, $compound_oid );
            if ( $compound_href && $compound_href->{$compound_oid} ) {
                print " <font color='red'>$compound_name</font>\n";
            } else {
                print " $compound_name\n";
            }
        }
    }
    $cur->finish();

    my $sql = qq{
         select ipr.rxn_order, ipr.rxn, r.is_reversible, itc.c_type,
                t.term_oid, t.term
         from img_pathway_reactions ipr, img_reaction r,
              img_reaction_t_components itc, img_term t
         where ipr.pathway_oid = ?
         and ipr.rxn = itc.rxn_oid
         and itc.rxn_oid = r.rxn_oid
         and itc.term = t.term_oid
         and ipr.rxn in ( $rxn_str )
         order by ipr.rxn_order
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for ( ; ; ) {
        my ( $rxn_order, $rxn_oid, $is_reversible, $c_type, $term_oid, $term_name ) = $cur->fetchrow();
        last if !$rxn_oid;

        if ( $is_reversible eq 'Yes' || $c_type eq 'RHS' ) {
            my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail&term_oid=$term_oid";
            print "<p>Reaction $rxn_order $rxn_oid: ($c_type) " . alink( $url, $term_oid ) . " $term_name\n";
        }
    }
    $cur->finish();
}

##########################################################################
# printTaxonNPList: print SM detail for taxon-related NPs
##########################################################################
sub printTaxonNPList {
    
    if ( !$enable_biocluster ) {
        webError("Natutal Product not supported!");
    }

    my $dbh = dbLogin();

    my $taxon_oid = param("taxon_oid");

    my $subTitle;
    if ( $taxon_oid ) {
        my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $taxon_url = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $subTitle = "<p style='width: 650px;'>Genome: " 
            . alink( $taxon_url, $taxon_name )
            . "</p>";
    }
        
    my $taxon_clause;
    my @binds;    
    if ( $taxon_oid ) {
        $taxon_clause = " and np.taxon_oid = ? ";
        push(@binds, $taxon_oid);
    }

    my $rclause   = WebUtil::urClause("np.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon("np.taxon_oid");

    my $sql = qq{
        select distinct c.compound_oid
        from img_compound c, np_biosynthesis_source np
        where c.compound_oid = np.compound_oid
        $taxon_clause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @np_ids;
    for ( ;; ) {
        my ( $np_id ) = $cur->fetchrow();
        last if !$np_id;
        push(@np_ids, $np_id);
    }
    $cur->finish();

    NaturalProd::listAllNaturalProds( $dbh, '', '', \@np_ids, '', $subTitle );
    
}


######################################################################
# printNPByPhylo - shows a list of SMs that have
#                         the given phylo
######################################################################
sub printNPByPhylo {
    my $Unassigned = 'Unassigned';
    
    my $domain = param("domain");
    my $phylum = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family = param("family");
    my $genus = param("genus");
    my $species = param("species");

    print "<h1>Secondary Metabolites (SM) for Phylogentic Rank</h1>";
    require PhyloUtil;
    PhyloUtil::printPhyloTitle
    ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");

    my $phyloClause;
    my @binds;
    if ($domain && $domain ne $Unassigned) {
        $phyloClause .= "and tx.domain = ? ";
        push(@binds, $domain);
    }
    if ($phylum && $phylum ne $Unassigned) {
        $phyloClause .= "and tx.phylum = ? ";
        push(@binds, $phylum);
    }
    if ($ir_class && $ir_class ne $Unassigned) {
        $phyloClause .= "and tx.ir_class = ? ";
        push(@binds, $ir_class);
    }
    if ($ir_order && $ir_order ne $Unassigned) {
        $phyloClause .= "and tx.ir_order = ? ";
        push(@binds, $ir_order);
    }
    if ($family && $family ne $Unassigned) {
        $phyloClause .= "and tx.family = ? ";
        push(@binds, $family);
    }
    if ($genus && $genus ne $Unassigned) {
        $phyloClause .= "and tx.genus = ? ";
        push(@binds, $genus);
    }
    if ($species && $species ne $Unassigned) {
        $phyloClause .= "and tx.species = ? ";
        push(@binds, $species);
    }

    my $sql = qq{
        select distinct np.compound_oid,
               tx.taxon_oid, tx.taxon_display_name
        from np_biosynthesis_source np, taxon tx
        where np.taxon_oid = tx.taxon_oid
        $phyloClause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $it = new InnerTable( 1, "byphylo$$", "byphylo", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "SM ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "asc",  "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$id;

        my $url = "$main_cgi?section=ImgCompound"
          . "&page=imgCpdDetail&compound_oid=$id";
        my $txurl = "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $id . $sd . alink($url, $id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $it->addRow($row);
        $cnt++;
    }

    $it->printOuterTable(1);

    printStatusLine("$cnt Secondary Metabolites for Phylogentic Rank. ", 2);
}


##########################################################################
# printNaturalProducts: print NP
##########################################################################
sub printNaturalProducts {
    my ( $dbh, $compId2taxons_ref, $compoundIds_ref, $compId2pubId_href, $compId2score_href ) = @_;

    my @compoundIds;
    my $taxons_str;
    if ( $compoundIds_ref && scalar($compoundIds_ref) > 0 ) {
        @compoundIds = @$compoundIds_ref;
    }
    elsif ( $compId2taxons_ref  ) {
        @compoundIds = keys %$compId2taxons_ref;
        my @validTaxons;
        for my $compoundId (@compoundIds) {
            my $taxons_ref = $compId2taxons_ref->{$compoundId};
            push(@validTaxons, @$taxons_ref);
        }
        $taxons_str = OracleUtil::getNumberIdsInClause1( $dbh, @validTaxons );
    }
    #print "printNaturalProducts() compoundIds=@compoundIds<br/>\n";

    my $compIds_str = OracleUtil::getNumberIdsInClause( $dbh, @compoundIds );
    my $compId2info_href = getCompId2info( $dbh, \@compoundIds, $compIds_str );
    my $compId2NPType_href = getCompId2NPType( $dbh, \@compoundIds, $compIds_str );
    my $compId2NPActivity_href = getCompId2NPActivity( $dbh, \@compoundIds, $compIds_str );
    my ( $compId2bcIds_href, $bcIds_ref ) = getCompId2BcIds( $dbh, \@compoundIds, $compIds_str, $taxons_str );
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $compIds_str =~ /gtt_num_id/i ); 
    
    my $bcIds_str = OracleUtil::getFuncIdsInClause( $dbh, @$bcIds_ref );                
    my $bc2taxonInfo_href = BcUtil::getBcId2taxonInfo( $dbh, $bcIds_ref, $bcIds_str );
    #my ( $bc2evid_href, $bc2prob_href ) = BcUtil::getBcId2evidProb( $dbh, $bcIds_ref, $bcIds_str );
    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
        if ( $bcIds_str =~ /gtt_func_id/i ); 

    my $it = new InnerTable( 1, "bcsearch$$", "bcsearch", 0 );
    $it->addColSpec( "Select" );
    if ( $compId2score_href ) {
        $it->addColSpec( "Similarity Score", "number desc", "right" );        
    }
    $it->addColSpec( "SM ID",                "number asc", "right" );
    $it->addColSpec( "Secondary Metabolite (SM) Name", "asc", "left" );
    $it->addColSpec( "SM Type",         "char asc",   "left" );
    $it->addColSpec( "SM Activity",     "char asc",   "left" );
    $it->addColSpec( "Formula",         "char asc",   "left" );
    #$it->addColSpec( "SMILES", "number asc", "right" );
    $it->addColSpec( "Number of Atoms", "number asc", "right" );
    $it->addColSpec( "Molecular Weight",     "number asc", "right" );
    #$it->addColSpec( "PubChem Comp ID", "number asc", "right" );
    #$it->addColSpec( "Evidence Type",   "char asc",   "left" );
    #$it->addColSpec( "Probability",     "number asc", "right" );
    $it->addColSpec( "Cluster ID",           "number asc", "right" );
    $it->addColSpec( "Genome Name",     "char asc",   "left" );
    $it->addColSpec( "Domain",          "char asc",   "left" );

    my $sd = $it->getSdDelim();    # sort delimit

    my $cnt   = 0;
    my $url   = 'main.cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=';
    my $bcurl = 'main.cgi?section=BiosyntheticDetail&page=cluster_detail&cluster_id=';
    my $turl  = 'main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=';
    #my $pub_url = 'https://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=';
    foreach my $compoundId (@compoundIds) {
        my $infoLine = $compId2info_href->{$compoundId};
        my ( $compoundName, $formula, $smiles, $num_atoms, $mol_weight ) 
            = split( /\t/, $infoLine );
        my $npType = $compId2NPType_href->{$compoundId};
        my $npAct = $compId2NPActivity_href->{$compoundId};
        my $score;
        if ( $compId2score_href ) {
            $score = $compId2score_href->{$compoundId};
        }
        #my $pubId;
        #if ( $compId2pubId_href ) {
        #    $pubId = $compId2pubId_href->{$compoundId};
        #}

        my $bc_ids_ref = $compId2bcIds_href->{$compoundId};
        for my $clusterId ( @$bc_ids_ref ) {                
            my $taxonInfo = $bc2taxonInfo_href->{$clusterId};
            my ( $domain, $taxon_oid, $taxonName ) = split( /\t/, $taxonInfo );
            if ( $compId2taxons_ref ) {
                #print "printNaturalProducts() cluster_id=$cluster_id<br/>\n";
                my $taxons_ref = $compId2taxons_ref->{$compoundId};
                next if ( !WebUtil::inArray($taxon_oid, @$taxons_ref) );
            }
    
            my $r;
            # select column
            my $tmp = "<input type='checkbox' name='bc_id' value='$clusterId' />\n";
            $r .= $sd . $tmp . "\t";
    
            if ( $compId2score_href ) {
                $r .= $score . $sd . "$score\t";
            }
    
            $r .= $compoundId . $sd . alink( $url . $compoundId, $compoundId ) . "\t";
            $r .= $compoundName . $sd . "$compoundName\t";
    
            if ( $npType eq '' ) {
                $r .= '_' . $sd . " \t";
            } else {
                $r .= $npType . $sd . "$npType\t";
            }

            if ( $npAct eq '' ) {
                $r .= '_' . $sd . " \t";
            } else {
                $r .= $npAct . $sd . "$npAct\t";
            }
    
            $r .= $formula . $sd . "$formula\t";
            #$r .= $smiles . $sd . "$smiles\t";
            $r .= $num_atoms . $sd . "$num_atoms\t";
            $r .= $mol_weight . $sd . "$mol_weight\t";
    
            #my $evidence    = $bc2evid_href->{$clusterId};
            #if ( $evidence eq '' ) {
            #    $r .= '_' . $sd . " \t";
            #} else {
            #    $r .= $evidence . $sd . "$evidence\t";
            #}
            #my $probability = $bc2prob_href->{$clusterId};
            #$r .= $probability . $sd . "$probability\t";
    
            #$r .= $pubId . $sd . alink( $pub_url.$pubId, $pubId ) . "\t";

            if ( $clusterId ne '' ) {
                $r .= $clusterId . $sd . alink( $bcurl . $clusterId, $clusterId ) . "\t";
            } else {
                $r .= '_' . $sd . " \t";
            }
    
            if ( $taxonName ne '' ) {
                $r .= $taxonName . $sd . alink( $turl . $taxon_oid, $taxonName ) . "\t";
            } else {
                $r .= '_' . $sd . " \t";
            }
            $r .= $domain . $sd . "$domain\t";
        
            $it->addRow($r);
            $cnt++;
        }
    }

    BcUtil::printTableFooter() if ( $cnt > 10 );
    $it->printOuterTable(1);
    BcUtil::printTableFooter();

    return $cnt;    
}

sub getCompId2info {
    my ( $dbh, $compoundIds_ref, $compIds_str ) = @_;

    my %compId2info;

    # get img compounds
    #print "Getting compound info<br>\n";
    if ( scalar(@$compoundIds_ref) > 0 ) {
        if ( ! $compIds_str ) {
            $compIds_str = OracleUtil::getNumberIdsInClause1( $dbh, @$compoundIds_ref );        
        }
        my $sql = qq{
            select distinct i.compound_oid, i.compound_name, 
                i.formula, i.smiles, i.num_atoms, i.mol_weight
            from img_compound i
            where i.compound_oid in ($compIds_str)
        };
        my $cur = execSql( $dbh, $sql, $verbose );
    
        for ( ; ; ) {
            my ( $compoundId, $compoundName, $formula, $smiles, $num_atoms, $mol_weight ) = $cur->fetchrow();
            last if ( !$compoundId );
            my $line  = "$compoundName\t$formula\t$smiles\t$num_atoms\t$mol_weight";
            $compId2info{$compoundId} = $line;
        }
        $cur->finish();
    }

    return ( \%compId2info );
}

sub getCompId2NPType {
    my ( $dbh, $compoundIds_ref, $compIds_str ) = @_;

    my %compId2NPType;    # compound id => SM type

    # get npType
    #print "Getting compound types<br>\n";
    if ( scalar(@$compoundIds_ref) > 0 ) {
        if ( ! $compIds_str ) {
            $compIds_str = OracleUtil::getNumberIdsInClause1( $dbh, @$compoundIds_ref );        
        }
        my $sql = qq{
            select distinct icmt.compound_oid, md.name
            from np_biosynthesis_source nbs, 
                 img_compound_meshd_tree icmt, mesh_dtree md
            where nbs.compound_oid = icmt.compound_oid
            and md.node = icmt.node
            and icmt.compound_oid in ($compIds_str) 
        };
    
        my $cur = execSql( $dbh, $sql, $verbose );
        
        for ( ; ; ) {
            my ( $compoundId, $type ) = $cur->fetchrow();
            last if ( !$compoundId );
            $compId2NPType{$compoundId} = $type;
        }
        $cur->finish();
    }
    
    return ( \%compId2NPType );
}

sub getCompId2NPActivity {
    my ( $dbh, $compoundIds_ref, $compIds_str ) = @_;

    my %compId2NPActivity;    # compound id => SM type

    # get npType
    #print "Getting compound activities<br>\n";
    if ( scalar(@$compoundIds_ref) > 0 ) {
        if ( ! $compIds_str ) {
            $compIds_str = OracleUtil::getNumberIdsInClause1( $dbh, @$compoundIds_ref );        
        }
        my $sql = qq{
            select distinct ca.compound_oid, md.name
            from np_biosynthesis_source nbs, 
                 img_compound_activity ca, mesh_dtree md
            where nbs.compound_oid = ca.compound_oid
            and ca.activity = md.node
            and ca.compound_oid in ($compIds_str) 
            order by 1, 2
        };
    
        my $cur = execSql( $dbh, $sql, $verbose );
        
        for ( ; ; ) {
            my ( $compoundId, $act ) = $cur->fetchrow();
            last if ( !$compoundId );
            if ( $compId2NPActivity{$compoundId} ) {
                $compId2NPActivity{$compoundId} .= "; " . $act;
            } else {
                $compId2NPActivity{$compoundId} = $act;
            }
        }
        $cur->finish();
    }
    
    return ( \%compId2NPActivity );
}

sub getCompId2BcIds {
    my ( $dbh, $compoundIds_ref, $compIds_str, $taxons_str ) = @_;

    my %compId2bcIds;    # compound id => array of bc_id
    my @bcIds;

    # get BC
    #print "Getting compound BC clusters<br>\n";
    if ( scalar(@$compoundIds_ref) > 0 ) {
        if ( ! $compIds_str ) {
            $compIds_str = OracleUtil::getNumberIdsInClause1( $dbh, @$compoundIds_ref );        
        }
        my $taxonsClause;
        if ( $taxons_str ) {
            $taxonsClause = "and n.taxon_oid in ( $taxons_str )";
        }
        my $sql = qq{
            select distinct n.compound_oid, n.cluster_id
            from np_biosynthesis_source n
            where n.compound_oid in ($compIds_str)
            $taxonsClause
            order by n.compound_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
    
        for ( ; ; ) {
            my ( $compoundId, $clusterId ) = $cur->fetchrow();
            last if ( !$compoundId );
    
            my $bcids_ref = $compId2bcIds{$compoundId};
            if ( $bcids_ref ) {
                push(@$bcids_ref, $clusterId);
            }
            else {
                my @bcids = ($clusterId);
                $compId2bcIds{$compoundId} = \@bcids;
            }
            push( @bcIds, $clusterId );
        }
        $cur->finish();
    }
    
    return ( \%compId2bcIds, \@bcIds );
}



1;

