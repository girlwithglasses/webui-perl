############################################################################
# hmp taxon list data
# $Id: HmpTaxonList.pm 33841 2015-07-29 20:48:56Z klchu $
############################################################################
package HmpTaxonList;
my $section = "HmpTaxonList";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use TaxonDetail;
use TaxonList;
use HtmlUtil;
use HTML::Template;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $cgi_url              = $env->{cgi_url};
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $tmp_url              = $env->{tmp_url};
my $img_hmp              = $env->{img_hmp};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $content_list         = $env->{content_list};
my $web_data_dir         = $env->{web_data_dir};
my $nvl                  = getNvl();

my $nullhmpid = "999999";    # to be last

## Map column name to friendlier label
my %colName2Label = (
                      toid             => "Genome ID",
                      ncbi_tid         => "NCBI Taxon ID",
                      phylum           => "Phylum",
                      ir_class         => "Class",
                      ir_order         => "Order",
                      family           => "Family",
                      genus            => "Genus",
                      seq_center       => "Sequencing Center",
                      total_gene_count => "Gene Count",
                      total_bases      => "Genome Size",
                      n_scaffolds      => "Scaffold Count",
                      img_version      => "IMG Release",
                      is_public        => "Is Public",
                      add_date         => "Add Date",
                      mrn              => "Medical Record Number",
                      date_collected   => 'Sample Collection Date',
                      host_gender      => 'Host Gender',
                      visit_num        => 'Visits',
                      replicate_num    => 'Replicate',
                      body_subsite     => 'Body Subsite',
);

# if not here then left
my %colName2Align = (
                      total_gene_count => "right",
                      total_bases      => "right",
                      n_scaffolds      => "right",
                      img_version      => "right",
                      mrn              => "right",
                      visit_num        => "right",
                      replicate_num    => "right",
);

# what names I found in gold to be human
#my $HUMAN_STR = "and p.host_name in ('Homo sapiend', 'Home sapiens', 'Homo sapiens', 'Human')";
my $HUMAN_STR = "and p.host_name = 'Homo sapiens'";
my $HOST_NAME = "Homo sapiens";
my $OTHER     = "zzzOther";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $sid  = getContactOid();

    if ( paramMatch("exportGenomes") ne "" ) {
        checkAccess();
        printExport();
        WebUtil::webExit(0);
    }

    if ( $page eq "list" ) {
        printTaxonList();
    } elsif ( $page eq "metadatahit" ) {

        HtmlUtil::cgiCacheInitialize( $section );
        HtmlUtil::cgiCacheStart() or return;

        printMetadataHitCharts_new();

        HtmlUtil::cgiCacheStop();

    } elsif ( $page eq "bodysites" ) {
        HtmlUtil::cgiCacheInitialize( $section );
        HtmlUtil::cgiCacheStart() or return;
        printBodySites();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "subjectsamples" ) {
        printSubjectSamples();
    } elsif ( $page eq "phylotreeview" ) {
        printPhyloTreeView();
    } elsif ( $page eq "familyPlot" ) {
        printLargerImage();
    } else {
        printTaxonList();
    }
}

sub printPhyloTreeView {
    print "<h1>Significant Family Plot</h1>";

    my $cdtFile = $tmp_dir . "/significant$$.cdt";
    my $atrFile = $tmp_dir . "/significant$$.atr";
    my $gtrFile = $tmp_dir . "/significant$$.gtr";

    my $kostas_dir = $env->{ webfs_data_dir } . "hmp/";
    my $kostasCDT  = $kostas_dir . "hmp.1.cdt";
    my $kostasATR  = $kostas_dir . "hmp.1.atr";
    my $kostasGTR  = $kostas_dir . "hmp.1.gtr";

    runCmd("/bin/cp $kostasCDT $cdtFile");
    runCmd("/bin/cp $kostasATR $atrFile");
    runCmd("/bin/cp $kostasGTR $gtrFile");

    my $gurl = "$cgi_url/$main_cgi?section=TaxonDetail"
	     . "&amp;page=taxonDetail&amp;taxon_oid=HEADER";
    my $s = "<DocumentConfig>\n"
	  . "<UrlExtractor urlTemplate='$gurl' index='1' isEnabled='1'/>\n"
	  . "</DocumentConfig>";

    my $jtvFile = "$tmp_dir/significant$$.jtv";
    my $wfh = newWriteFileHandle( $jtvFile, "printPhyloTreeView" );
    print $wfh "$s\n";
    close $wfh;

    # call the Java TreeView applet:
    my $archive = "$base_url/TreeViewApplet.jar,"
	        . "$base_url/nanoxml-2.2.2.jar," 
		. "$base_url/Dendrogram.jar";
    print qq{                                                              
        <APPLET code="edu/stanford/genetics/treeview/applet/ButtonApplet.class"
                archive="$archive" 
                alt="Java TreeView applet - check your java installation" 
                width='250' height='50'>                                       
            <PARAM name="cdtFile" value="$tmp_url/significant$$.cdt">
            <PARAM name="cdtName" value="with Java TreeView">                  
            <PARAM name="jtvFile" value="$tmp_url/significant$$.jtv">
            <PARAM name="styleName" value="linked">                            
            <PARAM name="plugins" value="edu.stanford.genetics.treeview.plugin.dendroview.DendrogramFactory">                                                
        </APPLET>                                                          
    };

    my $imageUrl = "$base_url/images/hmp.significantfamily.counts.png";
    $imageUrl = "$section_cgi&page=familyPlot";
    print qq{
        <p><a href="$imageUrl" alt='Tree View Image' 
            width=1500 height=9400 border=0 target="_blank">
            <img src="$base_url/images/hmp.signif.counts.thmb.jpg" 
             width=346 height=260 border=0 
             style="border:2px #99CCFF solid;" 
             alt="Thumbnail PNG" title="View larger image"/>
           </a>
           <br/><a href=$imageUrl target="_blank">View larger image
           </a>
        </p>
    };
}

sub printLargerImage {
    print "<h1>Significant Family Plot</h1>";
    print "<p>Below is a larger PNG image of the Significant Family Plot.</p>";

    print "<img src='$base_url/images/hmp.significantfamily.counts.png' "
      . "style='border:2px #99CCFF solid; ' "
      . "alt='Tree View Image' width=1200 height=7520 border=0 />";
}

sub printMetadataHitCharts {
    print qq{
        <h1>
        Body Site Metagenome Hit Distribution
        </h1>
        <p>
        The following shows the distribution of best blast hits of metagenome
        samples from each major body site <br/>run against reference isolate
        genomes from each major body site. <br/>
        Counts - Sample gene counts with best hit to reference genomes. <br/>
        Pie Chart - The counts from second column to seventh column (Airway ref., Gastro ref., Oral ref., Skin ref.,
        Urogenital ref., Other Body Sites)
        </p>
    };

    printStatusLine( "Loading ...", 1 );

    # unknown counts

    #     my $dbh = dbLogin();
    #     my %bodySiteUnknownCnt = (
    #        'Airways' => 0,
    #        'Gastrointestinal tract' => 0,
    #        'Oral' => 0,
    #        'Skin' => 0,
    #        'Urogenital tract' => 0
    #        );
    #
    #     my $sql = qq{
    #      select count(distinct dt.gene_oid)
    #      from dt_phylum_dist_genes dt, taxon t
    #      where dt.homolog_taxon = t.taxon_oid
    #      and dt.taxon_oid in (
    #        select t.taxon_oid
    #        from project_info_gold p, env_sample_gold esg, taxon t
    #        where p.project_oid = esg.project_info
    #        and t.sample_gold_id = esg.gold_id
    #        and esg.host_name = 'Homo sapiens'
    #        and esg.body_site = ?
    #        and p.project_oid = 18646
    #      )
    #      and t.gold_id not in (
    #select p.gold_stamp_id
    #from  project_info\@imgsg_dev p, project_info_body_sites\@imgsg_dev b
    #where p.project_oid = b.project_oid
    #and p.host_name = 'Homo sapiens'
    #and b.sample_body_site is not null
    #and p.gold_stamp_id is not null
    #      )
    #     };
    #     printStartWorkingDiv();
    #     foreach my $site (keys %bodySiteUnknownCnt) {
    #        print "Getting unknown for $site<br/>\n";
    #        my $cur = execSql( $dbh, $sql, $verbose, $site );
    #        my ( $cnt ) = $cur->fetchrow();
    #        $bodySiteUnknownCnt{$site} = $cnt;
    #     }
    #     printEndWorkingDiv();
    #
    #    #$dbh->disconnect();

    my $file = $env->{all_hits_file};
    my $all_hits_file = $env->{webfs_data_dir} . "hmp/$file";
    my %all_hits = (
                     'Airways'                => 'air',
                     'Gastrointestinal tract' => 'gat',
                     'Oral'                   => 'ora',
                     'Skin'                   => 'ski',
                     'Urogenital tract'       => 'urt',
                     'Other'                  => 'oth'
    );

    my $template = HTML::Template->new( filename => "$base_dir/metadata-hits-charts.html" );

    my $rfh = newReadFileHandle($all_hits_file);
    while ( my $line = $rfh->getline() ) {
        next if $line =~ /^#/;
        my @a = split( /\t/, $line );

# array index
# 0 - body site
# 1 - metag total gene count
# 2 - metag total hits gene count
# 3, 4, 5, 6, 7, 8, 9 - ref genome total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )
# 10, 11, 12, 13, 14, 15, 16 - ref genome hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )
# 17, 18, 19, 20, 21, 22, 23 - metag ref body site hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )

        # I need 17 - 22 as a row in the table and pie chart

        my $bs_name = $a[0];
        my $bs      = $all_hits{ $a[0] };

        $template->param( "$bs" . "_1" => $a[17] );
        $template->param( "$bs" . "_2" => $a[18] );
        $template->param( "$bs" . "_3" => $a[19] );
        $template->param( "$bs" . "_4" => $a[20] );
        $template->param( "$bs" . "_5" => $a[21] );
        $template->param( "$bs" . "_6" => $a[22] );

        $template->param( "$bs"
                  . "2_1" =>
                  "<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Airways'>"
                  . $a[17]
                  . " </a>" );
        $template->param( "$bs"
            . "2_2" =>
"<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Gastrointestinal tract'>"
            . $a[18]
            . " </a>" );
        $template->param( "$bs"
                     . "2_3" =>
                     "<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Oral'>"
                     . $a[19]
                     . " </a>" );
        $template->param( "$bs"
                     . "2_4" =>
                     "<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Skin'>"
                     . $a[20]
                     . " </a>" );
        $template->param( "$bs"
            . "2_5" =>
"<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Urogenital tract'>"
            . $a[21]
            . " </a>" );
        $template->param( "$bs"
                    . "2_6" =>
                    "<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Other'>"
                    . $a[22]
                    . " </a>" );
        $template->param( "$bs"
                  . "2_7" =>
                  "<a href='main.cgi?section=MetagPhyloDist&page=bodySiteVsBodySite&qbody_site=$bs_name&sbody_site=Unknown'>"
                  . $a[23]
                  . " </a>" );

    }
    close $rfh;

    #    my $file = $base_dir . "/metadata-hits-charts.html";
    #    my $s = file2Str($file);
    #    print $s;

    print $template->output;
    printStatusLine( "Loaded.", 2 );
}

sub printMetadataHitCharts_new {
    print qq{
        <h1>
        Body Site Metagenome Hit Distribution
        </h1>
        <p>
        The following shows the distribution of best blast hits of metagenome
        samples from each major body site <br/>run against reference isolate
        genomes from each major body site. <br/>
        Counts - Sample gene counts with best hit to reference genomes. <br/>
        Pie Chart - The counts from second column to seventh column (Airway ref., Gastro ref., Oral ref., Skin ref.,
        Urogenital ref., Other Body Sites)
        </p>
    };

    printStatusLine( "Loading ...", 1 );

    # rowNames, i.e. body site names, or bs_names
    my @rowNames = ( "Airways", "Gastrointestinal tract", "Oral", "Skin", "Urogenital tract" );

    # columnNames
    my @columnNames = (
                        "HMP Samples",
                        "Airway ref.",
                        "Gastro ref.",
                        "Oral ref.",
                        "Skin ref.",
                        "Urogenital ref.",
                        "Other Body Sites",
                        "Pie Chart",
                        "Other Isolation Sources",
    );

    # column alignment specifications. If not specified, align to the right
    my %columnNames_alignLeft = ( "HMP Samples" => "left", );

    my %linkKeywords = (
                         "Airway ref."             => "Airways",
                         "Gastro ref."             => "Gastrointestinal tract",
                         "Oral ref."               => "Oral",
                         "Skin ref."               => "Skin",
                         "Urogenital ref."         => "Urogenital tract",
                         "Other Body Sites"        => "Other",
                         "Other Isolation Sources" => "Unknown",
    );

    # source data from txt file
    my $file = $env->{all_hits_file};
    my $all_hits_file      = $env->{webfs_data_dir} . "hmp/$file";
    my @all_hits_shortname = ( "Airways", "G.T.", "Oral", "Skin", "U.T.", "Other" );

    my $rfh        = newReadFileHandle($all_hits_file);
    my @table_data = ();
    while ( my $line = $rfh->getline() ) {
        next if $line =~ /^#/;
        my @a = split( /\t/, $line );
        my @row_data = @a[ 17 .. 22 ];
        push( @row_data, -1, @a[23] );
        push( @table_data, \@row_data );
    }

    # create a new instance of StaticInnerTable
    my $it = new StaticInnerTable();
    $it->getSdDelim("\t");

    # set column specifications
    my $align;
    my $width;
    foreach my $columnName (@columnNames) {
        my $align = $columnNames_alignLeft{$columnName};
        if ( $align eq "" ) {
            $align = "right";
        } else {
            $align = "left";
        }
        $it->addColSpec( $columnName, "asc", $align );
    }

    my $url_part        = "main.cgi?section=MetagPhyloDist";
    my $ncol            = scalar(@columnNames);
    my $nrow            = scalar(@rowNames);
    my $firstRow_aref   = @table_data[0];
    my $nItemInFirstRow = scalar(@$firstRow_aref);

    # add rows one by one, each row correspond to one body site
    foreach my $i ( 0 .. ( $nrow - 1 ) ) {
        my $row_data = @table_data[$i];
        my $bs_name  = @rowNames[$i];
        my $url      = $url_part 
	             . "&page=allBodySiteDistro"
		     . "&body_site=$bs_name";
        my $row      = "<a href='$url'>$bs_name</a>";
        foreach my $j ( 0 .. ( $nItemInFirstRow - 1 ) ) {
            my $cell_data = @$row_data[$j];
            my $drawChartFlag;
            if ( $cell_data eq "-1" ) {
                $drawChartFlag = "1";
            } else {
                $drawChartFlag = "0";
            }

            if ( $drawChartFlag ne "1" ) {
                my $columnName  = @columnNames[ $j + 1 ];
                my $linkKeyword = $linkKeywords{$columnName};
                $linkKeyword =~ s/ /%20/g;
                my $url = $url_part 
		        . "&page=bodySiteVsBodySite"
			. "&qbody_site=$bs_name"
			. "&sbody_site=$linkKeyword";
                $row .= "\t<a href='$url'>$cell_data</a>";
            } else {
                $row .= "\t<div id='chart_div$i'></div>";
            }
        }
        $it->addRow($row);
    }

    $it->printTable();
    printStatusLine( "Loaded.", 2 );

    ### Last part of HTML body: print Javascript functions
    ### which underlie the pie charts (include three parts)

    # Javascript for Pie Chart: PART 1
    print <<EOF;
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
EOF

    # Javascript for Pie Chart: PART 2
    foreach my $i ( 0 .. ( $nrow - 1 ) ) {
        my $row_data      = @table_data[$i];
        my $addRow_string = "";
        my $nSlices       = scalar(@all_hits_shortname);

        # make sure chart bakcground color alternates the same way the row color of the table does
        my $bgcolor;
        if ( ( $i % 2 ne 0 ) ) {
            $bgcolor = "#EDF5FF";
        } else {
            $bgcolor = "FFFFFF";
        }
        foreach my $j ( 0 .. ( $nSlices - 1 ) ) {
            my $sliceName = @all_hits_shortname[$j];
            my $cell_data = @$row_data[$j];
            $addRow_string .= "['$sliceName', $cell_data],";
        }
        print <<EOF;
	google.setOnLoadCallback(drawChart$i);
	function drawChart$i() {
	    var data = new google.visualization.DataTable();
	    data.addColumn('string', 'Body Site');
	    data.addColumn('number', 'Counts');
	    data.addRows([$addRow_string]);
	    var chart = createChart('chart_div$i', 'Urogenital tract Samples', data, '$bgcolor');
	}
EOF
    }

    # Javascript for Pie Chart: PART 3
    print <<EOF;
    function createChart(divName, myTitle, data, chartBgColor) {
	var chart = new google.visualization.PieChart(document.getElementById(divName));
	chart.draw(data, {colors: ['#ff99aa', '#ffcc00', '#99cc66', '#99ccff', '#ffdd99', '#bbbbbb'],
              pieSliceText: 'label',
              pieSliceTextStyle: {color: 'black'},
              backgroundColor: chartBgColor,
              width: 250,
              height: 120,              chartArea: { width:240, height:110},
              is3D: true,
              tooltip: {showColorCode: true},
              legend: {position: 'right'}             });
          return chart;
      }
    </script>
EOF

    ### End of javascripts for Pie Chart

}

sub printSubjectSamples {
    print qq{
        <h1>
        Number of Subjects Sampled
        </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    my $sql       = qq{
        select en.mrn, count(*),  max(en.visit_num), max(en.replicate_num),
        count(distinct nvl(en.body_site, 'Other')), 
        count(distinct nvl(en.body_subsite,'Other'))
        from env_sample_gold en, taxon tx, project_info_gold p
        where en.gold_id =  tx.sample_gold_id
        and en.mrn is not null 
        and tx.is_public = 'Yes'
        and tx.obsolete_flag = 'No'
        and p.hmp_id is not null
        and p.project_oid = en.project_info
        group by en.mrn
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    my $txTableName = "hmplist";   # name of current instance of taxon table
    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    $it->hideFilterLine();

    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Subject ID",                  "asc", "right" );
    $it->addColSpec( "Number of Samples",           "asc", "right" );
    $it->addColSpec( "Number of Visits (max.)",     "asc", "right" );
    $it->addColSpec( "Number of Replicates (max.)", "asc", "right" );
    $it->addColSpec( "Number of Body Sites",        "asc", "right" );
    $it->addColSpec( "Number of Body Subsites",     "asc", "right" );

    my $count = 0;
    my $url   = "main.cgi?section=HmpTaxonList" 
	      . "&page=list&funded=hmp&genome_type=metag";
    for ( ; ; ) {
        my ( $mrn, $samples, $vists, $replicates, $body, $subsite ) = $cur->fetchrow();
        last if ( !$mrn );

        my $r;
        my $tmp = alink( $url . "&mrn=$mrn", $mrn );
        $r .= $mrn . $sd . $tmp . "\t";
        $r .= $samples . $sd . $samples . "\t";
        $r .= $vists . $sd . $vists . "\t";
        $r .= $replicates . $sd . $replicates . "\t";
        $r .= $body . $sd . $body . "\t";
        $r .= $subsite . $sd . $subsite . "\t";

        $it->addRow($r);
        $count++;
    }
    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

sub printBodySites {
    print qq{
        <h1>
        Primary Body Sites
        </h1>  
        <p>
        All Human - All strains with host as Human as defined in <a href='http://www.genomesonline.org'>GOLD</a>.
        Including HMP Genomes and HMP Samples.
        </p>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh     = dbLogin();
    my $dbhgold = WebUtil::dbGoldLogin();

    # all total counts
    require MainPageStats;
    my $data_href = MainPageStats::getHmpStats_new( $dbh, $dbhgold );
    #$dbhgold->disconnect();

    my %major_body_site = (
                            'Airways'                => 0,
                            'Gastrointestinal tract' => 0,
                            'Oral'                   => 0,
                            'Skin'                   => 0,
                            'Urogenital tract'       => 0,
                            $OTHER                   => 0,
    );
    my %body_site_total_cnt = %major_body_site;    # cat. => total count
    foreach my $key ( keys %$data_href ) {
        my $tmp_href = $data_href->{$key};

        my $body_site = $tmp_href->{body_site};

        next if ( $body_site eq "" );

        if ( exists $body_site_total_cnt{$body_site} ) {
            $body_site_total_cnt{$body_site} = $body_site_total_cnt{$body_site} + 1;
        } else {
            $body_site_total_cnt{$OTHER} = $body_site_total_cnt{$OTHER} + 1;
        }
    }
    my $total_all_cnt = 0;
    foreach my $name ( sort keys %body_site_total_cnt ) {

        my $totalCnt = $body_site_total_cnt{$name};

        $total_all_cnt = $total_all_cnt + $totalCnt;
    }

    # hmp isolates
    my $sql = qq{
        select ps.sample_body_site, count(distinct p.project_oid)
        from project_info_gold p, project_info_project_relevance pr,
             taxon t, project_info_body_sites ps
        where p.project_oid = pr.project_oid
        and p.ncbi_project_id = t.gbk_project_id
        and t.genome_type = 'isolate'
        and t.is_public = 'Yes'
        and t.obsolete_flag = 'No'
        and p.hmp_id is not null
        and p.project_oid = ps.project_oid
        and ps.sample_body_site in ('Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract') 
        group by ps.sample_body_site       
    };

    # body site => count
    my %hmp_isolates;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $body_site, $count ) = $cur->fetchrow();
        last if ( !$body_site );
        $hmp_isolates{$body_site} = $count;
    }

    my $sql       = qq{
        select nvl(body_site, '$OTHER'), count(*), count(distinct e.mrn)
        from env_sample_gold e, taxon t
        where e.gold_id = t.sample_gold_id 
        and project_info = 18646 
        and t.is_public = 'Yes'
        and t.obsolete_flag = 'No'
        group by body_site
        order by 1        
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $txTableName = "hmplist";      # name of current instance of taxon table
    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    $it->hideFilterLine();
    $it->hidePagination();
    my $sd = $it->getSdDelim();       # sort delimiter

    $it->addColSpec( "Body Site",            "", "left" );
    $it->addColSpec( "HMP Clincial Samples", "", "right" );
    $it->addColSpec( "Number of Subjects",   "", "right" );
    $it->addColSpec( "HMP Isolate Genomes",  "", "right" );
    $it->addColSpec( "All Human",            "", "right" );

    for ( ; ; ) {
        my ( $body_site, $samples, $subjects ) = $cur->fetchrow();
        last if ( !$body_site );

        my $r;
        my $url = "main.cgi?section=HmpTaxonList&page=list&funded=all&genome_type=all&body_site=";
        my $tmp = alink( $url . $body_site, $body_site );
        $r .= $sd . $tmp . "\t";

        my $url = "main.cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=metag&body_site=";
        my $tmp = alink( $url . $body_site, $samples );
        $r .= $samples . $sd . $tmp . "\t";
        $r .= $subjects . $sd . $subjects . "\t";

        my $cnt = $hmp_isolates{$body_site};
        my $url = "main.cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=isolate&body_site=";
        my $tmp = alink( $url . $body_site, $cnt );
        $r .= $cnt . $sd . $tmp . "\t";

        my $cnt = $body_site_total_cnt{$body_site};

        #print "$cnt<br/>\n";
        my $url1 = "$main_cgi?section=HmpTaxonList&page=list&funded=all&genome_type=all&body_site=$body_site";
        my $tmp = alink( $url1, $cnt );
        $r .= $cnt . $sd . $tmp . "\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

sub printTaxonList {
    printStatusLine( "Loading ...", 1 );

    my $mrn         = param("mrn");
    my $funded      = param("funded");
    my $body_site   = param("body_site");
    my $genome_type = param("genome_type");
    my @outputCol   = param("outputCol");

    my $title;

    if ( $mrn ne "" ) {
        $title = qq{
        <h1>
        HMP Genome List for Subject $mrn
        </h1>  
        };

    } elsif ( $funded eq "hmp" && $body_site eq "" ) {
        $title = qq{
        <h1>
        HMP Genome List for All Project Categories
        </h1>  
        };
    } elsif ( $funded eq "all" ) {
        $title = qq{
        <h1>
        Genomes related to the Human Microbiome
        </h1>  
        };
    } else {
        my $tmp_body_site = $body_site;
        $tmp_body_site = "Other" if ( $body_site eq $OTHER );

        # hmp
        $title = qq{
        <h1>
        HMP Genome List for Project Category
        </h1>  
        <h2>$tmp_body_site</h2>
        };
    }
    #print $title if ( !$img_internal );

    #printMainForm();

    #my $dbh = dbLogin();

    # additional default columns
    if ( $#outputCol < 0 ) {
        push( @outputCol, "total_gene_count" );
        push( @outputCol, "total_bases" );
        param( -name => "outputCol", -value => \@outputCol );
    }
    my %outputColHash = WebUtil::array2Hash(@outputCol);

    my $genomeTypeClause;
    if ( $genome_type eq "metag" ) {

        # make first query to return 0 rows
        $genomeTypeClause = "where genome_type = 'metagenome' ";
    } elsif ( $genome_type eq "isolate" ) {
        $genomeTypeClause = "where genome_type = 'isolate' ";
    } else {
        $genomeTypeClause = "where t.domain in ('Bacteria', 'Archaea' ,'Eukaryota')";
    }

    #
    # SEE MainPageStats::replaceStatTableRows for major body site list - ken
    #
    my $bodySiteClause;
    my $bodySiteMetagClause;
    my @binds;
    if ( $body_site ne "" ) {
        if($funded eq "hmp") {
            $bodySiteClause = "and p.hmp_isolation_bodysite = ?";
            $bodySiteClause = "and nvl(p.hmp_isolation_bodysite, 'Other') not in ('Airways', 'Oral', 'Gastrointestinal tract', 'Skin', 'Urogenital tract')" if ( $body_site eq $OTHER );
        } else {
            $bodySiteClause = "and b.sample_body_site = ?";
            # nvl(hmp_isolation_bodysite, 'Other') not in ('Airways', 'Oral', 'Gastrointestinal tract', 'Skin', 'Urogenital tract')
            # $bodySiteClause = "and p.hmp_isolation_bodysite is null" if ($body_site eq $OTHER);
            $bodySiteClause = "and nvl(b.sample_body_site, 'Other') not in ('Airways', 'Oral', 'Gastrointestinal tract', 'Skin', 'Urogenital tract')" if ( $body_site eq $OTHER );
        }

        

        $bodySiteMetagClause = "and esg.body_site = ? ";

        #$bodySiteMetagClause = "and esg.body_site is null " if ($body_site eq $OTHER);
        $bodySiteMetagClause =
          "and nvl(esg.body_site, 'Other') not in ('Airways', 'Oral', 'Gastrointestinal tract', 'Skin', 'Urogenital tract') "
          if ( $body_site eq $OTHER );

        push( @binds, $body_site ) if ( $body_site ne $OTHER );
    }

    my $fundedClause;
    my $fundedMetagClause = "";
    if ( $funded eq "hmp" ) {
        $fundedClause = "and p.show_in_dacc = 'Yes' and p.hmp_id is not null";
        $fundedMetagClause = "and p.project_oid = 18646";
    }


    # for new genome list
    my $sqlNew    = qq{
        select distinct t.taxon_oid
        from project_info_gold p, taxon t, project_info_body_sites\@imgsg_dev b
        $genomeTypeClause
        and p.project_oid = b.project_oid (+)
        and t.is_public = 'Yes'
        and t.obsolete_flag = 'No'
        and p.gold_stamp_id = t.gold_id
        and p.host_name = '$HOST_NAME'
        and p.gold_stamp_id is not null
        $bodySiteClause
        $fundedClause
    };

    if ( $include_metagenomes
         && ( $genome_type eq "metag" || $genome_type eq "all" ) )
    {
        push( @binds, $body_site )
          if ( $body_site ne "" && $body_site ne $OTHER );

        my $mrnClause;
        if ( $mrn ne "" ) {
            $mrnClause = "and mrn = ?";
            push( @binds, $mrn );
        }

        # for new genome list
        $sqlNew = $sqlNew . qq{
            union all
            select distinct t.taxon_oid 
            from project_info_gold p, env_sample_gold esg, taxon t
            where p.project_oid = esg.project_info
            and t.sample_gold_id = esg.gold_id
            and esg.gold_id is not null
            and t.genome_type = 'metagenome'
            and t.is_public = 'Yes'
            and esg.host_name = '$HOST_NAME' 
            $bodySiteMetagClause
            $fundedMetagClause
            $mrnClause
        };
    }

    ##$dbh->disconnect();
    require GenomeList;
    GenomeList::printGenomesViaSql( '', $sqlNew, $title, \@binds );
    return;

}

# for excel export
#sub printExport_old {
#    my $category          = param("category");
#    my $body_site         = param("body_site");
#    my @outputCol         = param("outputCol");
#    my @taxon_filter_oids = param("taxon_filter_oid");
#
#    my $taxon_filter_oid_str = join( ',', @taxon_filter_oids );
#    if ( blankStr($taxon_filter_oid_str) ) {
#        print header( -type => "text/html" );
#        webError("You must select at least one genome to export.");
#    }
#    my @taxon_oids   = split( /,/, $taxon_filter_oid_str );
#    my %taxon_filter = WebUtil::array2Hash(@taxon_oids);
#
#    my $dbh = dbLogin();
#
#    my $proj_rel_clause = " and pr.project_relevance = 'Human Microbiome Project (HMP)' and p.show_in_dacc = 'Yes' ";
#    my $rel_table       = " , project_info_project_relevance pr ";
#    my $rel_clause      = " and p.project_oid = pr.project_oid ";
#
#    if ( $category eq "human" ) {
#        $proj_rel_clause = "$HUMAN_STR";
#    }
#
#    my $bodyclause = "and ps.sample_body_site = ?";
#    if ( $category eq "Unclassified" ) {
#        $bodyclause = "and ps.sample_body_site is null";
#    } elsif ( $category eq "all" ) {
#        $bodyclause = "";
#    } elsif ( $category eq "human" ) {
#        $bodyclause = "" if ( $body_site eq "" );
#        $bodyclause = "and ps.sample_body_site is null"
#          if ( $body_site eq "Unclassified" || $body_site eq $OTHER );
#        $rel_table  = "";
#        $rel_clause = "";
#    }
#
#    # additional defualt columns
#    if ( $#outputCol < 0 ) {
#        push( @outputCol, "total_gene_count" );
#        push( @outputCol, "total_bases" );
#        param( -name => "outputCol", -value => \@outputCol );
#    }
#    my %outputColHash = WebUtil::array2Hash(@outputCol);
#
#    my $sql = qq{
#        select distinct t.domain, t.seq_status, t.taxon_display_name, 
#        p.hmp_id, p.project_oid, p.ncbi_project_id,
#        $nvl(ps.sample_body_site, 'Unclassified'),
#	t.total_gene_count, t.total_bases, 
#	t.taxon_oid, 
#	t.phylum, t.ir_class, t.ir_order, t.family, t.genus, t.seq_center, 
#	t.ncbi_taxon_id, t.n_scaffolds,
#	t.img_version, to_char(t.add_date, 'yyyy-mm-dd'), t.is_public
#        from project_info_gold p 
#	left join project_info_body_sites ps on p.project_oid = ps.project_oid  
#	$rel_table
#	, vw_taxon t
#	where 1 = 1 
#	$rel_clause
#        $proj_rel_clause
#        and p.ncbi_project_id = t.gbk_project_id
#	and t.is_public = 'Yes'
#	$bodyclause 
#    };
#
#    print "Domain\tGenome Completion\tGenome Name\tHMP ID\tGenBank Project ID\t";
#    print "Body Site\t";
#
#    foreach my $col (@outputCol) {
#        my $label = $colName2Label{$col};
#        print "$label\t";
#    }
#    print "\n";
#
#    my @a = ($category);
#    my $cur;
#    if ( $category eq "all" || $category eq "human" ) {
#        if (    $body_site ne ""
#             && $body_site ne "Unclassified"
#             && $category eq "human" )
#        {
#            $cur = execSql( $dbh, $sql, $verbose, $body_site );
#        } else {
#            $cur = execSql( $dbh, $sql, $verbose );
#        }
#    } elsif ( $category ne "Unclassified" ) {
#        $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
#    } else {
#        $cur = execSql( $dbh, $sql, $verbose );
#    }
#    for ( ; ; ) {
#        my (
#             $domain,     $seq_status,       $tname,            $hmp_id,      $poid,
#             $ncbi,       $body_sample_site, $total_gene_count, $total_bases, $toid,
#             $phylum,     $ir_class,         $ir_order,         $family,      $genus,
#             $seq_center, $ncbi_tid,         $n_scaffolds,      $img_version, $add_date,
#             $is_public
#          )
#          = $cur->fetchrow();
#        last if ( !$toid );
#        next if ( !exists $taxon_filter{$toid} );
#
#        my %hash = (
#                     toid             => $toid,
#                     ncbi_tid         => $ncbi_tid,
#                     phylum           => $phylum,
#                     ir_class         => $ir_class,
#                     ir_order         => $ir_order,
#                     family           => $family,
#                     genus            => $genus,
#                     seq_center       => $seq_center,
#                     total_gene_count => $total_gene_count,
#                     total_bases      => $total_bases,
#                     n_scaffolds      => $n_scaffolds,
#                     img_version      => $img_version,
#                     is_public        => $is_public,
#                     add_date         => $add_date
#        );
#
#        print $domain . "\t";
#        print $seq_status . "\t";
#        print $tname . "\t";
#
#        # hmp id, but link should have hmp id in it
#        if ( $hmp_id ne "" ) {
#            $hmp_id = lpad($hmp_id);
#            print $hmp_id . "\t";
#        } else {
#            print $hmp_id . "\t";
#        }
#
#        print $ncbi . "\t";
#        print $body_sample_site . "\t";
#
#        foreach my $col (@outputCol) {
#            my $x = $hash{$col};
#            print $x . "\t";
#        }
#        print "\n";
#    }
#
#    $cur->finish();
#    #$dbh->disconnect();
#}

#sub printTaxonAttribute {
#    my ( $colName, $outputColHash_ref ) = @_;
#    my $label = $colName2Label{$colName};
#    my $outChecked;
#    my @outputCol = param("outputCol");
#
#    $outChecked = "checked" if $outputColHash_ref->{$colName} ne "";
#    print "<tr class='img' >\n";
#    print "<td class='img' >\n";
#    print "<input type='checkbox' name='outputCol' value='$colName' " . "$outChecked />\n";
#    print "</td>\n";
#    print "<td class='img' >\n";
#    print $label;
#    print "</td>\n";
#    print "</tr>\n";
#}

#sub printTableConfiguration {
#    my ($outputColHash_ref) = @_;
#
#    print "<h2>Configuration</h2>\n";
#    print "<p>\n";
#    print "Configure additional output columns.\n";
#    print "</p>\n";
#    print "<table class='img'  border='1'>\n";
#    print "<th class='img' >Output</th>\n";
#    print "<th class='img' >Column Name</th>\n";
#
#    printTaxonAttribute( "toid",             $outputColHash_ref );
#    printTaxonAttribute( "ncbi_tid",         $outputColHash_ref );
#    printTaxonAttribute( "phylum",           $outputColHash_ref );
#    printTaxonAttribute( "ir_class",         $outputColHash_ref );
#    printTaxonAttribute( "ir_order",         $outputColHash_ref );
#    printTaxonAttribute( "family",           $outputColHash_ref );
#    printTaxonAttribute( "genus",            $outputColHash_ref );
#    printTaxonAttribute( "seq_center",       $outputColHash_ref );
#    printTaxonAttribute( "total_gene_count", $outputColHash_ref );
#    printTaxonAttribute( "total_bases",      $outputColHash_ref );
#    printTaxonAttribute( "n_scaffolds",      $outputColHash_ref );
#    printTaxonAttribute( "img_version",      $outputColHash_ref );
#    printTaxonAttribute( "add_date",         $outputColHash_ref );
#    printTaxonAttribute( "is_public",        $outputColHash_ref );
#
#    printTaxonAttribute( "mrn",            $outputColHash_ref );
#    printTaxonAttribute( "date_collected", $outputColHash_ref );
#    printTaxonAttribute( "host_gender",    $outputColHash_ref );
#    printTaxonAttribute( "visit_num",      $outputColHash_ref );
#    printTaxonAttribute( "replicate_num",  $outputColHash_ref );
#    printTaxonAttribute( "body_subsite",   $outputColHash_ref );
#
#    print "</table>\n";
#    print "<br/>\n";
#    my $name = "_section_${section}_setTaxonOutputCol";
#
#    print submit(
#                  -name  => $name,
#                  value  => "Display Genomes Again",
#                  -class => "meddefbutton"
#    );
#    print nbsp(1);
#    #Can not be replaced by WebUtil::printButtonFooter();
#    print "<input type=button name=SelectAll value='Select All' " . "onClick='selectAllOutputCol(1)' class='smbutton' />\n";
#    print nbsp(1);
#    print "<input type=button name=ClearAll value='Clear All' " . "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
#}

#sub lpad {
#    my ($id) = @_;
#    return sprintf( "%04d", $id );
#}

1;
