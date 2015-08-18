############################################################################
# Pangenome.pm - displays a pangenome and its composing genomes
# $Id: Pangenome.pm 31333 2014-07-03 17:32:34Z jinghuahuang $
############################################################################
package Pangenome;
my $section = "Pangenome";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use InnerTable;
use ChartUtil;
use ScaffoldGraph;
use GeneCassettePanel2;
use GeneUtil;
use WebConfig;
use WebUtil;
use GeneCassette;
use CompareGenomes;

my $env              = getEnv();
my $main_cgi         = $env->{main_cgi};
my $section_cgi      = "$main_cgi?section=$section";
my $tmp_url          = $env->{tmp_url};
my $tmp_dir          = $env->{tmp_dir};
my $verbose          = $env->{verbose};
my $show_myimg_login = $env->{show_myimg_login};
my $base_url         = $env->{base_url};

my $flank_length     = 25000;
my $max_genes        = 40;

my $nullcount = -1;
my $nvl = getNvl();
my $YUI = $env->{yui_dir_28};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    
#    my $enable_pangenome = $env->{enable_pangenome};
#    if (!$enable_pangenome) {
#	print "<p>Pangenomes are not supported in IMG at the current time.";
#	print "</p>";
#        return;
#    }

    if ( paramMatch("exportCompStats") ne "" ) {
        checkAccess();
        printTaxonBreakdownStats("export");
        WebUtil::webExit(0);
    } elsif ( paramMatch("statTableName") ne ""
	      && ( $page eq "taxonBreakdownStats"
		   || paramMatch("setTaxonBreakdownStatCols") ne "" ) ) {
        printTaxonBreakdownStats("display");
    } elsif ( $page eq "pangenes" ) {
        displayPangenesCounts();
    } elsif ( $page eq "uniquepangenes" ) {
        displayPangenesCountsUnique();
    } elsif ( $page eq "plot" ) {
        #        my @taxons    = param("comp_taxon_oid");
        #        my $taxon_oid = param("taxon_oid");        # pangenome
        #        my $gene_oid  = param("pang_gene_oid");    # pangene
        #
        #        print "list: @taxons <br/>\n";
        #        print "t: $taxon_oid<br/>\n";
        #        print "g: $gene_oid <br/>\n";

        displayPlot();
    } elsif ( $page eq "compgenelist" ) {
        printCompGeneList();
    } else {
        printDefault();
    }
}

############################################################################
# printDefault - default form
############################################################################
sub printDefault() {
    my $taxon_oid = param("taxon_oid");
    my $dbh       = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    # get cog gene count
    my $sql = qq{
	select pcg.pangenome_taxon, count(distinct pcg.gene)
        from pangenome_count_genes pcg, gene_cog_groups gc
	where pcg.taxon_oid = ?
	and pcg.gene = gc.gene_oid
	group by pcg.pangenome_taxon       
    };
    my %taxon_cog_counts;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;
        $taxon_cog_counts{$id} = $count;
    }
    $cur->finish();

    # get pfam gene count
    my $sql = qq{
	select pcg.pangenome_taxon, count(distinct pcg.gene)
        from pangenome_count_genes pcg, gene_pfam_families gp
	where pcg.taxon_oid = ?
	and pcg.gene = gp.gene_oid
	group by pcg.pangenome_taxon      
    };
    my %taxon_pfam_counts;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;
        $taxon_pfam_counts{$id} = $count;
    }
    $cur->finish();

    # get tigrfam gene count
    my $sql = qq{
	select pcg.pangenome_taxon, count(distinct pcg.gene)
        from pangenome_count_genes pcg, gene_tigrfams gp
	where pcg.taxon_oid = ?
	and pcg.gene = gp.gene_oid
	group by pcg.pangenome_taxon      
    };
    my %taxon_tigrfam_counts;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;
        $taxon_tigrfam_counts{$id} = $count;
    }
    $cur->finish();

    # get ko gene count
    my $sql = qq{
	select pcg.pangenome_taxon, count(distinct pcg.gene)
        from pangenome_count_genes pcg, gene_ko_terms gp
	where pcg.taxon_oid = ?
	and pcg.gene = gp.gene_oid
	group by pcg.pangenome_taxon        
    };
    my %taxon_ko_counts;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;
        $taxon_ko_counts{$id} = $count;
    }
    $cur->finish();

    # get number genes used in each comp. genomes
    my $sql = qq{
	select pcg.pangenome_taxon, count(distinct pcg.gene)
        from pangenome_count_genes pcg
	where pcg.taxon_oid = ?
	group by pcg.pangenome_taxon        
    };
    my %taxon_counts;    # counts of genes used in each comp. genomes
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $count;
    }
    $cur->finish();

    my %comp_taxon_names;
    my $sql = qq{
	select p.pangenome_composition, t.taxon_display_name,
        ts.total_gene_count 
        from taxon_pangenome_composition p, taxon t, taxon_stats ts
        where p.taxon_oid = ? 
        and t.taxon_oid = p.pangenome_composition
        and t.taxon_oid = ts.taxon_oid
        order by t.taxon_display_name
    };

    print "<h1>Pangenome Composition Details</h1>\n";
    my $turl = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";
    my $pangenomeUrl = alink($turl.$taxon_oid, $taxon_name, "_blank");
    print "<p>$pangenomeUrl</p>";

    use TabHTML;
    TabHTML::printTabAPILinks("pangenomecompTab");
    my @tabIndex = ( "#pantab1", "#pantab2", "#pantab3",
                     "#pantab4", "#pantab5" );
    my @tabNames = ( "Genome Composition",
                     "Function Composition",
                     "Gene Counts",
                     "Pangenes in Category",
                     "Pangenes not in Category" );
    TabHTML::printTabDiv("pangenomecompTab", \@tabIndex, \@tabNames);
 
    print "<div id='pantab1'>"; 
    print "<h2>Genome Composition</h2>";

    my $it = new InnerTable( 1, "genomecomp$$", "genomecomp", 0 ); 
    my $sd = $it->getSdDelim(); 
    $it->hideAll();

    $it->addColSpec( $taxon_name, "asc", "left", "", "", "wrap" ); 
    $it->addColSpec( "Pangene COG", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Pangene Pfam", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Pangene TIGRfam", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Pangene KO", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Pangene Count", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Total Gene Count", "desc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Percent Pangenes", "desc", "right", "", "", "wrap" ); 
 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    for ( ;; ) { 
        my ( $comp, $tname, $total_gene_count ) = $cur->fetchrow(); 
        last if !$comp; 
 
	$comp_taxon_names{$comp} = $tname;
        my $row; 
        $row .= $tname.$sd.alink($turl.$comp, $tname)."\t"; 
        $row .= $taxon_cog_counts{$comp}."\t"; 
        $row .= $taxon_pfam_counts{$comp}."\t"; 
        $row .= $taxon_tigrfam_counts{$comp}."\t"; 
        $row .= $taxon_ko_counts{$comp}."\t"; 
        $row .= $taxon_counts{$comp}."\t"; 
        $row .= $total_gene_count."\t"; 
 
        my $percent = $taxon_counts{$comp} * 100 / $total_gene_count; 
        $row .= sprintf("%.2f", $percent)."\t"; 
        $it->addRow($row); 
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    print "</div>"; # end pantab1
 
    print "<div id='pantab2'>"; 
    print "<h2>Function Composition</h2>";

    print "<p>\n";
    my $url =
        "$section_cgi&page=taxonBreakdownStats"
      . "&taxon_oid=$taxon_oid"
      . "&statTableName=dt_cog_stats&initial=1";
    print alink( $url, "Breakdown by COG categories", "_blank" );

    print "<br/>\n";
    my $url =
        "$section_cgi&page=taxonBreakdownStats"
      . "&taxon_oid=$taxon_oid"
      . "&statTableName=dt_kegg_stats&initial=1";
    print alink( $url, "Breakdown by KEGG categories", "_blank" );

    print "<br/>\n";
    my $url =
        "$section_cgi&page=taxonBreakdownStats"
      . "&taxon_oid=$taxon_oid"
      . "&statTableName=dt_pfam_stats&initial=1";
    print alink( $url, "Breakdown by Pfam categories", "_blank" );

    print "<br/>\n";
    my $url =
        "$section_cgi&page=taxonBreakdownStats"
      . "&taxon_oid=$taxon_oid"
      . "&statTableName=dt_tigrfam_stats&initial=1";
    print alink( $url, "Breakdown by TIGRfam roles", "_blank" );

    print "</p>\n";
    print "</div>"; # end pantab2

    # Organism Composition
    my $curl = $section_cgi 
	     . "&page=pangenes&taxon_oid=$taxon_oid&numorgs=";
    my $uurl = $section_cgi 
	     . "&page=uniquepangenes&taxon_oid=$taxon_oid&numorgs=";

 
    print "<div id='pantab3'>"; 
    print "<h2>Gene Counts</h2>";

    print "<p>";
    print "The following displays the number of pangenes that represent"
        . " genes from different number of organisms.\n";
    print "</p>";

    # Display the summary table results

    # * prepare the bar chart
    my $chart = newBarChart(); # make vertical labels in BarChart, too
    $chart->WIDTH(600);
    $chart->HEIGHT(450);
    $chart->DOMAIN_AXIS_LABEL("Number of Organisms");
    $chart->RANGE_AXIS_LABEL("Number of Pangenes");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($curl . "&chart=y");
    $chart->COLOR_THEME("ORANGE");

    my @chartseries;
    my @chartcategories;
    my @chartdata;

    print "<table cellpadding=2 cellspacing=2 border=0 >\n";
    print "<tr><td align=left valign=top>\n";

    my $it = new InnerTable( 1, "pangenecnt$$", "pangenecnt", 0 );
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Number of<br/>Organisms", "", "right" );
    $it->addColSpec( "Number of<br/>Pangenes", "", "right" );
    $it->addColSpec( "Unique Number<br>of Pangenes", "", "right" );

    my $sql = qq{
        select genome_count, gene_count
        from pangenome_count
        where taxon_oid = ? 
        order by genome_count desc
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $countadditive = 0; 
 
    my @uniquecount;
    for ( ; ; ) {
        my ( $genome_count, $gene_count ) = $cur->fetchrow(); 
        last if !$genome_count; 
 
        my $count = $gene_count + $countadditive;
        $countadditive = $count; 
 
        push @chartcategories, $genome_count;
        push @chartdata,       $countadditive;
	push @uniquecount,     $gene_count;
 
        my $row; 
        $row .= $genome_count."\t";
	if ($count != 0) {
	    $row .= $count.$sd.alink($curl.$genome_count, $count)."\t";
	} else {
	    $row .= $count."\t";
	}
	$row .= $gene_count.$sd.alink($uurl.$genome_count, $gene_count)."\t";
        $it->addRow($row); 
    }
    $cur->finish(); 
#    $it->printOuterTable(1); 
 
    print "</td>"; # end of 1st column in outer table

    # chart colunm in outer table
    print "<td align=right valign=center>\n";

    my @rchartcategories = reverse @chartcategories;
    my @rchartdata = reverse @chartdata;

    push @chartseries, "num pangenes";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@rchartcategories );

    my $datastr = join( ",", @rchartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $nitems = scalar @chartcategories;
    my $chartW = 30 * $nitems;
    if ($nitems <= 20) {
	$chartW = 600;
    }
    $chart->WIDTH($chartW);

    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "pangeneCountSummary", 1 );
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
    print "</td></tr></table>\n";
    print "</div>"; # end pantab3
 
    print "<div id='pantab4'>"; 
    print "<h2>Pangenes in Category</h2>";
    my $it = new InnerTable( 1, "incategory$$", "incategory", 0 );
    $it->hideAll();
 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Genome" );
    foreach my $genome_count( @chartcategories ) {
        if ($genome_count == 1) { 
	    $it->addColSpec( "Pangenes in<br/>$genome_count Genome", 
			     "", "right" );
	} else {
	    $it->addColSpec( "Pangenes in<br/>$genome_count Genomes", 
			     "", "right" );
	}
    }

    my $idx = 0;
    my $row1;
    #$row1 .= "Total Pangenes\t";
    $row1 .= "Pangenes found in n or more genomes\t";
    foreach my $count ( @chartdata ) {
	my $genome_count = $chartcategories[$idx];
        if ($count != 0) { 
            $row1 .= $count.$sd
		.alink($curl.$genome_count, $count, "_blank")."\t";
        } else { 
            $row1 .= $count."\t";
        } 
	$idx++;
    }
    $it->addRow($row1);

    my $idx = 0; 
    my $row1;
    $row1 .= "Pangenes found in n genomes only\t";
    foreach my $gene_count ( @uniquecount ) { 
        my $genome_count = $chartcategories[$idx];
	$row1 .= $gene_count.$sd
	    .alink($uurl.$genome_count, $gene_count, "_blank")."\t";
        $idx++; 
    } 
    $it->addRow($row1); 

    my $sql = qq{
        select p.pangenome_taxon, p.genome_count,
               count(distinct p.gene)
        from pangenome_count_genes p
        where p.taxon_oid = ? 
        group by p.pangenome_taxon, p.genome_count
        order by p.pangenome_taxon, p.genome_count desc
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 

    my $tid0;
    my $row;
    for ( ; ; ) { 
        my ( $tid, $genome_count, $gene_count ) = $cur->fetchrow();
        last if !$tid;

	if ($tid ne $tid0) {
	    if ($tid0 ne "") {
		$it->addRow($row);
	    }
	    $tid0 = $tid;

	    $row = "";
	    my $tname = $comp_taxon_names{ $tid };
	    $row .= $tname.$sd.alink($turl.$tid, $tname, "_blank")."\t";
	}
	$row .= $gene_count."\t";
    }
    $it->addRow($row); 
    $cur->finish(); 
    $it->printOuterTable(1); 
    print "</div>"; # end pantab4
 
    print "<div id='pantab5'>"; 
    print "<h2>Pangenes <u>not</u> in Category</h2>"; 
    my $it = new InnerTable( 1, "notincategory$$", "notincategory", 0 ); 
    $it->hideAll();
 
    my $sd = $it->getSdDelim(); 
    my $idx = 0;
    $it->addColSpec( "Genome" ); 
    foreach my $genome_count( @chartcategories ) { 
	if ($genome_count == 1) {
#	    $it->addColSpec
#		( "Pangenes in <u>only</u><br/>$genome_count Genome", 
#		  "", "right" ); 
	} elsif ($idx == 0) {
	    $it->addColSpec
		( "Pangenes <u>not</u> in<br/>$genome_count Genomes", 
		  "", "right" ); 
	} else {
	    $it->addColSpec
		( "Pangenes <u>not</u> in<br/>$genome_count or more Genomes", 
		  "", "right" ); 
	}
	$idx++;
    } 

    my %profile;
    my @totalcounts;
    foreach my $genome_count( @chartcategories ) { 
	my $sql = qq{
	    select sum(gene_count)
            from pangenome_count 
	    where taxon_oid = ?
	    and genome_count < ?
	    order by genome_count desc 
	};
	$cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $genome_count ); 
	for ( ;; ) {
	    my ( $count ) = $cur->fetchrow();
	    last if !$count;
	    push @totalcounts, $count;
	}

	my $sql = qq{ 
	    select p.pangenome_taxon,
	           count(distinct p.gene) 
	    from pangenome_count_genes p 
	    where p.taxon_oid = ? 
	    and p.genome_count < ?
	    group by p.pangenome_taxon
	    order by p.pangenome_taxon
	}; 
	$cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $genome_count ); 
 
	for ( ; ; ) { 
	    my ( $tid, $gene_count ) = $cur->fetchrow(); 
	    last if !$tid; 

	    if ($profile{ $tid } ne "") {
		$profile{ $tid } .= "\t".$gene_count;
	    } else {
		$profile{ $tid } = $gene_count;
	    }
	}
    }
    $cur->finish(); 

    my $idx = 0; 
    my $row1; 
    #$row1 .= "Total Pangenes\t"; 
    $row1 .= "Pangenes not in n or more genomes\t";
    foreach my $count ( @totalcounts ) { 
        my $genome_count = $chartcategories[$idx]; 
        if ($count != 0) { 
            $row1 .= $count.$sd
		.alink($curl.$genome_count, $count, "_blank")."\t"; 
        } else { 
            $row1 .= $count."\t"; 
        } 
        $idx++; 
    } 
    $it->addRow($row1); 

    foreach my $tid (sort {$a<=>$b} keys %profile) {
	my $valueStr = $profile{ $tid };
	my @values = split("\t", $valueStr);

	my $row; 
	my $tname = $comp_taxon_names{ $tid }; 
	$row .= $tname.$sd.alink($turl.$tid, $tname, "_blank")."\t"; 

	foreach my $gene_count( @values ) {
	    $row .= $gene_count."\t";
	}
	$it->addRow($row); 
    }
    $it->printOuterTable(1); 
    print "</div>"; # end pantab5
    TabHTML::printTabDivEnd(); 

    #$dbh->disconnect();
}

############################################################################
# displayPangenesCounts - display only the gene counts
############################################################################
sub displayPangenesCounts {
    my $taxon_oid = param("taxon_oid");
    my $numorgs   = param("numorgs");
    my $chart     = param("chart");
    my $dbh       = dbLogin();

    # invoked via click on chart; re-map variable(s)
    if ( $chart eq "y" ) {
        $numorgs = param("category");
    }

    printStatusLine( "Loading ...", 1 );
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>";
    print "$taxon_name :<br/>Pangenes in at least $numorgs Organisms";
    print "</h1>\n";

    # get composition taxon names
    my %comp_taxon_names;
    my $sql = qq{
	select t.taxon_oid,  t.taxon_display_name
        from taxon t, taxon_pangenome_composition p
	where t.taxon_oid = p.pangenome_composition
	and p.taxon_oid = ?        
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $tid, $tname ) = $cur->fetchrow();
        last if ( !$tid );
        $comp_taxon_names{$tid} = $tname;
    }
    $cur->finish();

    # Display the table header
    my $it = new InnerTable( 1, "panglist$$", "panglist", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Pangene Name", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Pangene ID", "asc", "right" );
    foreach my $genome ( sort keys %comp_taxon_names ) {
        my $tname = $comp_taxon_names{$genome};
        $it->addColSpec( "$tname", "desc", "right", "", "", "wrap" );
    }

    ## Now retrieve data
    my $sql = qq{
	select p.pangenome_taxon, p.pangene,
	g.gene_display_name, g.locus_tag, $nvl(g.gene_symbol, ''),
	count(distinct p.gene)
        from pangenome_count_genes p, gene g
	where p.taxon_oid = ?
	and p.genome_count >= ?
	and p.pangene = g.gene_oid
	group by p.pangenome_taxon, p.pangene, 
	g.gene_display_name, g.locus_tag, g.gene_symbol
    };
    my %uniquegenes;    # pangenes
    my %tablemap;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $numorgs );
    while ( my ( $pangenome_taxon, $pangene,
		 $gene_display_name, $locus_tag, $symbol, $gene_count ) 
	    = $cur->fetchrow() ) {
	my $name = $gene_display_name;
	$name = $symbol if blankStr($name);
        $uniquegenes{$pangene} = 
	    $name."\t".$locus_tag."\t".$pangene;
        my $tablekey = $pangene . "|" . $pangenome_taxon;
        $tablemap{$tablekey} = $gene_count;
    }
    $cur->finish();

    # display the results
    my $link =
        "$section_cgi&page=compgenelist&taxon_oid=$taxon_oid"
      . "&numorgs=$numorgs&pangene=";
    my @uniquekeys = sort keys %uniquegenes;

    foreach my $gkey (@uniquekeys) {
        my $r;
        my $url = $link . $gkey;
        my $value = $uniquegenes{$gkey}; 
	my ($name, $locus, $id) = split('\t', $value);

	if (blankStr($name)) {
	    $r .= "\t";
	} else {
	    $r .= lc($name) . $sd . alink($url, $name) . "\t";
	}
	$r .= $locus . $sd . alink($url, $locus) . "\t";
	$r .= $id . $sd . alink($url, $id) . "\t";

        foreach my $genomecomp ( sort keys %comp_taxon_names ) {
            my $tablekey = $gkey . "|" . $genomecomp;
            my $genecnt  = $tablemap{$tablekey};
            if ( $genecnt eq "" ) {
                $r .= $nullcount.$sd." &nbsp; "."\t";
            } else {
                $r .= $genecnt.$sd.$genecnt."\t";
            }
        }
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    printStatusLine( scalar(@uniquekeys) . " comparison rows displayed", 2 );
    #$dbh->disconnect();
}

############################################################################
# displayPangenesCountsUnique - display only the gene counts
############################################################################
sub displayPangenesCountsUnique {
    my $taxon_oid = param("taxon_oid");
    my $numorgs   = param("numorgs");
    my $chart     = param("chart");
    my $dbh       = dbLogin();

    # invoked via click on chart; re-map variable(s)
    if ( $chart eq "y" ) {
        $numorgs = param("category");
    }

    printStatusLine( "Loading ...", 1 );
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>";
    print "$taxon_name :<br/>Pangenes in $numorgs Organisms";
    print "</h1>\n";

    # get composition taxon names
    my %comp_taxon_names;
    my $sql = qq{
	select t.taxon_oid,  t.taxon_display_name
	from taxon t, taxon_pangenome_composition p
	where t.taxon_oid = p.pangenome_composition
	and p.taxon_oid = ?        
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $tid, $tname ) = $cur->fetchrow();
        last if ( !$tid );
        $comp_taxon_names{$tid} = $tname;
    }
    $cur->finish();

    # Display the table header
    my $it = new InnerTable( 1, "pangunqlist$$", "pangunqlist", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Pangene Name", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Pangene ID", "asc", "right" );
    foreach my $genome ( sort keys %comp_taxon_names ) {
        my $tname = $comp_taxon_names{$genome};
        $it->addColSpec( "$tname", "desc", "right", "", "", "wrap" );
    }

    ## Now retrieve data
    my $sql = qq{
	select p.pangenome_taxon, p.pangene,
	       g.gene_display_name, g.locus_tag, $nvl(g.gene_symbol, ''),
	       count(distinct p.gene)
        from pangenome_count_genes p, gene g
	where p.taxon_oid = ?
	and p.genome_count = ?
	and p.pangene = g.gene_oid
	group by p.pangenome_taxon, p.pangene, 
	g.gene_display_name, g.locus_tag, g.gene_symbol 
    };
    
    my %uniquegenes;    # pangenes
    my %tablemap;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $numorgs );
    while ( my ( $pangenome_taxon, $pangene,
		 $gene_display_name, $locus_tag, $symbol, $gene_count )
	    = $cur->fetchrow() ) {
	my $name = $gene_display_name;
	$name = $symbol if blankStr($name);
        $uniquegenes{$pangene} = 
            $name."\t".$locus_tag."\t".$pangene;
        my $tablekey = $pangene . "|" . $pangenome_taxon;
        $tablemap{$tablekey} = $gene_count;
    }
    $cur->finish();

    # display the results
    my $link =
        "$section_cgi&page=compgenelist&taxon_oid=$taxon_oid"
      . "&numorgs=$numorgs&pangene=";
    my @uniquekeys = sort keys %uniquegenes;

    foreach my $gkey (@uniquekeys) {
        my $r;
        my $url = $link . $gkey;
        my $value = $uniquegenes{$gkey};
        my ($name, $locus, $id) = split('\t', $value); 

        if (blankStr($name)) {
            $r .= "\t"; 
        } else { 
	    $r .= lc($name) . $sd . alink($url, $name) . "\t"; 
	}
        $r .= $locus . $sd . alink($url, $locus) . "\t"; 
        $r .= $id . $sd . alink($url, $id) . "\t"; 

        foreach my $genomecomp ( sort keys %comp_taxon_names ) {
            # lookup
            my $tablekey = $gkey . "|" . $genomecomp;
            my $genecnt  = $tablemap{$tablekey};
            if ( $genecnt eq "" ) {
                $r .= $nullcount.$sd." &nbsp; "."\t";
            } else {
                $r .= $genecnt.$sd.$genecnt."\t";
            }
        }
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    printStatusLine( scalar(@uniquekeys) . " comparison rows displayed", 2 );
    #$dbh->disconnect();
}

############################################################################
# printJS - javascript for mysubmit
############################################################################
sub printJS {
    print <<EOF;
    <script language="javascript" type="text/javascript">
	
    function mysubmit() {
	document.mainForm.section.value = 'Pangenome';
	document.mainForm.page.value = 'plot';
	document.mainForm.submit();
    }
    </script>       

EOF

}

############################################################################
# printCompGeneList - prints the pangene comp gene details
############################################################################
sub printCompGeneList {
    my $taxon_oid = param("taxon_oid");
    my $numorgs   = param("numorgs");
    my $pangene   = param("pangene");
    my $dbh       = dbLogin();

    printStatusLine( "Loading ...", 1 );

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>";
    print formatHtmlTitle( "$taxon_name with $numorgs Organisms", 50 );
    print "</h1>\n";

    print "<p>Pangene: \n";
    printGeneInfo($pangene);
    print "</p>\n";

    printMainForm();
    printJS();
    print hiddenVar( "section",       "GeneCartStor" );
    print hiddenVar( "page",          "addToGeneCart" );
    print hiddenVar( "taxon_oid",     "$taxon_oid" );
    print hiddenVar( "pang_gene_oid", "$pangene" );

    # get composition taxon names
    my %comp_taxon_names;
    my $sql = qq{
	select t.taxon_oid,  t.taxon_display_name
        from taxon t, taxon_pangenome_composition p
	where t.taxon_oid = p.pangenome_composition
	and p.taxon_oid = ?        
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $tid, $tname ) = $cur->fetchrow();
        last if ( !$tid );
        $comp_taxon_names{$tid} = $tname;
    }
    $cur->finish();

    # Display the table header
    my $it = new InnerTable( 1, "panglist2$$", "panglist2", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Composition Genome", "number asc", "left" );
    $it->addColSpec( "Composition Genes" );
    $it->addColSpec( "Gene Count", "number desc", "right" );

    ## Now retrieve data
    my $sql = qq{
	select pangenome_taxon, gene
        from pangenome_count_genes
	where taxon_oid = ?
	and genome_count >= ?
	and pangene = ?
	order by pangenome_taxon, gene       
    };

    my %tablemap;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $numorgs, $pangene );
    while ( my ( $pangenome_taxon, $gene ) = $cur->fetchrow() ) {
        if ( exists $tablemap{$pangenome_taxon} ) {
            my $aref = $tablemap{$pangenome_taxon};
            push( @$aref, $gene );
        } else {
            my @a = ($gene);
            $tablemap{$pangenome_taxon} = \@a;
        }
    }
    $cur->finish();

    my $geneurl = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";
    my $plot = "$section_cgi&page=plot"
	     . "&taxon_oid=$taxon_oid&gene_oid=$pangene";
    my $turl = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    # TODO fix the graph mysubmit()
    # onClick='javascript:window.open("$plot", "_self");' />
    print qq{
        <p>
        Please select a Composition Genome to plot against. If nothing 
	is selected,<br/> the pangenome will be plotted against all genomes.
	</p>
        <input type='button' 
               class='medbutton' 
               value='Neighborhood Viewer' 
               onClick='javascript:mysubmit();' /><br/>
    };
    printGeneCartFooter();

    foreach my $genomecomp ( sort keys %comp_taxon_names ) {
        my $r;
        $r .= $sd
          . "<input type='checkbox' name='comp_taxon_oid' "
	  . "value='$genomecomp'>"
          . "\t";

        my $tname = $comp_taxon_names{$genomecomp};
        $r .= $tname . $sd . alink( "$turl" . "$genomecomp", $tname ) . "\t";

        my $aref = $tablemap{$genomecomp};
        if ( $aref eq "" ) {
            $r .= $sd . "&nbsp;" . "\t";
            $r .= 0 . $sd . 0 . "\t";
        } else {
            my $str;
            my $cnt = 0;
            foreach my $gid (@$aref) {
                my $x =
                    "<input type='checkbox' name='gene_oid' value='$gid'>"
                  . "<a href='$geneurl$gid'>$gid</a>\n";
                $str .= $x;
                $cnt++;
                if ( $cnt % 4 == 0 ) {
                    $str .= " <br/> ";
                } else {
                    $str .= " &nbsp; ";
                }
            }
            $r .= $sd . $str . "\t";
            if ( $cnt eq "" || $cnt < 1 ) {
                $r .= $nullcount . $sd . " &nbsp; " . "\t";
            } else {
                $r .= $cnt . $sd . $cnt . "\t";
            }
        }
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    my $size = keys %comp_taxon_names;
    printStatusLine( "$size loaded", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# center the round the pangene and limit the range to about 50kb
############################################################################
sub displayPlot {
    my $plot_per_page = 10;
    my $taxon_oid     = param("taxon_oid");        # pangenome
    my $gene_oid      = param("pang_gene_oid");    # pangene
    my @taxons        = param("comp_taxon_oid");
    my $pageno        = param("pageno");
    my $totalplots    =
      param("totalplots");    # total num of plots -comp neighborhoods

    my $taxon_oid_str = join( ',', @taxons );
    $pageno     = 1  if ( $pageno     eq "" );
    $totalplots = -1 if ( $totalplots eq "" ); # total plots was not calc yet.

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>";
    print formatHtmlTitle( "Panfold Viewer", 50 );
    print "</h1>\n";

    # print gene information
    print "<p>Marker Gene: \n";
    printGeneInfo($gene_oid);
    print "</p>\n";
    printHint( "Mouse over a gene to to see details. "
             . "The marker gene is displayed in "
	     . "<font color=red>red</font>." );
    print "<br/>";

    # print plot -
    # first determine the pangene's scaffold start and end rage
    # and strand for the marker gene
    my $sql = qq{
        select g.start_coord, g.end_coord, g.strand, g.scaffold
        from gene g
        where g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $pgene_start_coord, $pgene_end_coord,
	 $pgene_strand, $pgene_scaffold )
      = $cur->fetchrow();
    $cur->finish();

    printNeighborhood( $dbh, $gene_oid, $pgene_start_coord, $pgene_end_coord,
                       $pgene_scaffold, $pgene_strand );

    # now get the comp taxons and their comp genes for this pangene
    # add user genome selection here
    my $txClause = "";
    if ( $taxon_oid_str ne "" ) {
        $txClause = "and p.pangenome_taxon in ($taxon_oid_str)";
    }
    my $sql = qq{
	select p.pangenome_taxon, p.gene, 
	g.start_coord, g.end_coord, g.strand, g.scaffold
	from pangenome_count_genes p, gene g
	where p.taxon_oid = ?
	and p.pangene = ?
	and p.gene = g.gene_oid
	$txClause
	order by p.pangenome_taxon, g.scaffold, g.start_coord
    };

    my $show_next  = 1;
    my $count      = 0;
    my $end_page   = $pageno * $plot_per_page;
    my $start_page = $end_page - $plot_per_page + 1;
    my %ctaxon_hash;    # toid => list of gene details
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $gene_oid );
    for ( ; ; ) {
        my ( $ctaxon, $cgene, $cstart_coord, $cend_coord,
	     $cstrand, $cscaffold )
	    = $cur->fetchrow();
        if ( !$ctaxon ) {
            $show_next = 0;
            last;
        }

        $count++;
        next if ( $count < $start_page );
        printNeighborhood( $dbh, $cgene, $cstart_coord, $cend_coord,
			   $cscaffold, $cstrand );

        last if ( $count >= $end_page );
    }
    $cur->finish();

    printStatusLine( "$count loaded", 2 );
    #$dbh->disconnect();

    # TODO next prev buttons
    printMainForm();
    print hiddenVar( "section",       "Pangenome" );
    print hiddenVar( "page",          "plot" );
    print hiddenVar( "taxon_oid",     "$taxon_oid" );
    print hiddenVar( "pang_gene_oid", "$gene_oid" );
    print hiddenVar( "pageno",        "$pageno" );

    foreach my $tid (@taxons) {
        print hiddenVar( "comp_taxon_oid", "$tid" );
    }

    print qq{
	<script language="javascript" type="text/javascript">
        function mysubmit(x) {
	    document.mainForm.pageno.value = $pageno + x; 
	    //alert("page " + document.mainForm.pageno.value);
	    document.mainForm.submit();
	}
	</script>       
    };

    if ( $pageno > 1 ) {
        print qq{
        <input type="button" 
        name="prev" 
        value="< Previous" 
        class="meddefbutton"
        onClick="mysubmit(-1)" />
        };
    }

    if ($show_next) {
        print qq{
        <input type="button" 
        name="next" 
        value="Next >" 
        class="meddefbutton"
        onClick="mysubmit(1)" />        
        };
    }
    print end_form();
}

############################################################################
# printNeighborhood - 
############################################################################
sub printNeighborhood {
    my (
         $dbh,        $mygene_oid,   $start_coord0,
         $end_coord0, $scaffold_oid, $pgene_strand
      )
      = @_;

    my $scaffold_name = getScaffoldName( $dbh, $scaffold_oid );
    my $mid_coord =
      int( ( $end_coord0 - $start_coord0 ) / 2 ) + $start_coord0 + 1;

    my $taxon_oid = scaffoldOid2TaxonOid( $dbh, $scaffold_oid );
    my $left_flank = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    my $sql = qq{
    	select distinct g.gene_oid, g.gene_symbol, g.gene_display_name, 
        	g.locus_type, g.locus_tag, 
        	g.start_coord, g.end_coord, g.strand, g.aa_seq_length,
        	ss.seq_length, g.is_pseudogene, g.img_orf_type, g.cds_frag_coord,
        	gcg.cog
        from scaffold scf, scaffold_stats ss, gene g
    	left join gene_cog_groups gcg 
            on g.gene_oid = gcg.gene_oid       
    	where g.scaffold = ?
    	and g.scaffold = scf.scaffold_oid
    	and scf.scaffold_oid = ss.scaffold_oid
    	and g.start_coord > 0
    	and g.end_coord > 0
    	and g.obsolete_flag = 'No'
    	and ( 
    	      ( g.start_coord >= ? and g.end_coord <= ? ) or
    	      ( ( g.end_coord + g.start_coord ) / 2 >= ? and
    		( g.end_coord + g.start_coord ) / 2 <= ? ) 
	    )
    };
    
    my $cur        = execSql( $dbh, $sql, $verbose, $scaffold_oid, 
			      $left_flank, $right_flank, 
			      $left_flank, $right_flank );
    my @all_genes;
    for ( ; ; ) {
        my (
             $gene_oid,      $gene_symbol,     $gene_display_name,
             $locus_type,    $locus_tag,
             $start_coord,   $end_coord,       $strand,
             $aa_seq_length, $scf_seq_length0, $is_pseudogene,
             $img_orf_type,  $cds_frag_coord,  $cog
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        push( @all_genes,
                "$gene_oid\t$gene_symbol\t$gene_display_name\t"
              . "$locus_type\t$locus_tag\t$start_coord\t"
              . "$end_coord\t$strand\t$aa_seq_length\t$scf_seq_length0\t"
              . "$is_pseudogene\t$img_orf_type\t$cds_frag_coord\t$cog" );    
    }
    $cur->finish();
			      
			      
    my $id         = "gd.$scaffold_oid.$start_coord0..$end_coord0";
    my $coord_incr = 5000;

    my $args = {
           id                 => $id,
           start_coord        => $left_flank,
           end_coord          => $right_flank,
           coord_incr         => $coord_incr,
           strand             => $pgene_strand,
           has_frame          => 1,
           x_width            => 800,
           gene_page_base_url => 
	       "$main_cgi?section=GeneDetail&page=geneDetail",
	   mygene_page_base_url =>
	       "$main_cgi?section=MyGeneDetail&page=geneDetail",
	   
           color_array_file => $env->{large_color_array_file},
           tmp_dir          => $env->{tmp_dir},
           tmp_url          => $env->{tmp_url},
           title            => $scaffold_name,
    };
    my $sp = new ScaffoldPanel($args);
    my $scf_seq_length;

    # number of pseudogene count
    my $pseudogene_cnt = 0;

    foreach my $geneline (@all_genes) {
        my (
             $gene_oid,      $gene_symbol,     $gene_display_name,
             $locus_type,    $locus_tag,
             $start_coord,   $end_coord,       $strand,
             $aa_seq_length, $scf_seq_length0, $is_pseudogene,
             $img_orf_type,  $cds_frag_coord,  $cog
          )
          = split( /\t/, $geneline );

        $scf_seq_length    = $scf_seq_length0;

        my $label = $gene_symbol;
    	if ($label eq "" || $label eq "null") {
    	    $label = $locus_tag;
    	} else { 
    	    $label .= " $locus_tag"; 
    	} 
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }
        $label .= " $cog";
        my $color = $sp->{color_yellow};
        $color = GeneCassette::getCogColor( $sp, $cog );
        $color = $sp->{color_red} if $gene_oid eq $mygene_oid;
        $color = $sp->{color_cyan}
          if $gene_oid ne $mygene_oid
          && $show_myimg_login;

        # All pseudo gene should be white - 2008-04-09 ken
        if (    ( $gene_oid ne $mygene_oid )
             && ( uc($is_pseudogene) eq "YES" || $img_orf_type eq "pseudo" ) )
        {
            $color = $sp->{color_white};
            $pseudogene_cnt++;
        }

        my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
        if ( scalar(@coordLines) > 1 ) {
            foreach my $line (@coordLines) {
                my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                my $tmplabel = $label . " $frag_start..$frag_end";
                $sp->addGene( $gene_oid, $frag_start, $frag_end,
                              $strand,   $color,      $tmplabel );

            }

        } else {
            $sp->addGene( $gene_oid, $start_coord, $end_coord, 
			  $strand, $color, $label );
        }
    }   # end for loop

    WebUtil::addIntergenic( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );
    my $s = $sp->getMapHtml("overlib");
    print "$s\n";

    # print tooltip code for the scaffold
    print "<script src='$base_url/overlib.js'></script>\n";
}

############################################################################
# printScaffold - code adapted from ScaffoldGraph::printScaffoldGraph
############################################################################
sub printScaffold {
    my (
         $scaffold_oid,        $start_coord, $end_coord,
         $pangenecolormap_ref, $genemap_ref, $scaffoldstrand_ref
      )
      = @_;

    $start_coord =~ s/\s+//g;
    $end_coord   =~ s/\s+//g;
    if ( !isInt($start_coord) ) {
        webError("Expected integer for start coordinate.");
    }
    if ( !isInt($end_coord) ) {
        webError("Expected integer for end coordinate.");
    }
    if ( $start_coord < 1 ) {
        webError("Start coordinate should be greater or equal to 1.");
    }
    if ( $start_coord > $end_coord ) {
        webError(   "Start coordinate should be "
                  . "less than or equal to the end coordinate." );
    }
    if ( $scaffold_oid eq "" ) {
        webDie("printScaffold: scaffold_oid not defined\n");
    }
    webLog "Start Graph " . currDateTime() . "\n" if $verbose >= 1;

    my $dbh = dbLogin();

    # get scaffold information
    checkScaffoldPerm( $dbh, $scaffold_oid );
    my $scaffold_name = getScaffoldName( $dbh, $scaffold_oid );

    # determine flanking coordinates for the panel
    my $flank_length = 5000;
    my $mid_coord = int(($end_coord - $start_coord) / 2) + $start_coord + 1;
    my $left_flank  = $start_coord - $flank_length;
    my $right_flank = $end_coord + $flank_length;

    my $strand = "+";
    if ( $scaffoldstrand_ref->{$scaffold_oid} eq "-" ) {
        $strand = "-";
    }

    # build the panel
    my $args = {
           id          => "panscf.$scaffold_oid.$left_flank.$right_flank",
           start_coord => $left_flank,
           end_coord   => $right_flank,
           coord_incr  => 2500,
           strand      => $strand,
           title       => $scaffold_name,
           has_frame   => 1,
           gene_page_base_url =>
	       "$main_cgi?section=GeneDetail&page=geneDetail",
           color_array_file   => $env->{large_color_array_file},
           tmp_dir            => $tmp_dir,
           tmp_url            => $tmp_url,
    };
    my $sp = new ScaffoldPanel($args);

    # get all the genes within the flanking region
    my $sql = qq{
	select distinct g.gene_oid, g.gene_symbol, 
	g.gene_display_name, g.locus_type, g.locus_tag,
	g.start_coord, g.end_coord, g.strand,
	g.aa_seq_length, g.scaffold
        from gene g
	where g.scaffold = ?
	and g.start_coord >=  ?
	and g.end_coord <= ?
	order by g.start_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid,
		       $left_flank, $right_flank );

    my $color_array = $sp->{color_array};
    my $coloridx    = 0;

    for ( ; ; ) {
        my (
             $gene_oid,   $gene_symbol, $gene_display_name,
             $locus_type, $locus_tag,   $start_coord,
             $end_coord,  $strand,      $aa_seq_length,
             $scaffold
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $coloridx++;

        my $label = $gene_symbol;
	if ($label eq "" || $label eq "null") {
	    $label = $locus_tag;
	} else { 
	    $label .= " $locus_tag"; 
	} 
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }

        my $pangene_oid = $genemap_ref->{$gene_oid};
        my $color;
        if ( !defined $pangene_oid || $pangene_oid eq "" ) {
            $color = $sp->{color_yellow};
        } else {
            $color = $pangenecolormap_ref->{$pangene_oid};
        }
        $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color,
                      $label );
    }
    $cur->finish();

    if ( $scaffoldstrand_ref->{$scaffold_oid} eq "-" ) {
        $sp->addBracket( $start_coord, "right" );
        $sp->addBracket( $end_coord,   "left" );
    } else {
        $sp->addBracket( $start_coord, "left" );
        $sp->addBracket( $end_coord,   "right" );
    }

    my $s = $sp->getMapHtml("overlib");
    print "<br>\n";
    print "$s\n";

    $cur->finish();
    #$dbh->disconnect();
}

############################################################################
# printGeneInfo - prints the gene detail
############################################################################
sub printGeneInfo {
    my ($pangene) = @_;
    my $gene_oid = param("gene_oid");

    if ( $gene_oid eq "" ) {
        $gene_oid = $pangene;
    }

    my $dbh = dbLogin();

    # get the gene info
    my $sql = qq{
	select g.gene_oid, g.gene_symbol, 
               g.gene_display_name, 
               g.locus_type, g.locus_tag, 
	       g.start_coord, g.end_coord, 
	       g.strand, g.aa_seq_length, 
	       g.scaffold
        from gene g
	where g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my (
         $gene_oid,      $gene_symbol, $gene_display_name, $locus_type,
         $locus_tag,     $start_coord, $end_coord,         $strand,
         $aa_seq_length, $scaffold
      )
      = $cur->fetchrow();
    $cur->finish();
    return if ( !$gene_oid );

    my $label = $gene_symbol;
    if ($label eq "" || $label eq "null") {
	$label = $locus_tag;
    } else {
	$label .= " $locus_tag";
    }

    $label = "gene $gene_oid" if $label eq "";
    $label .= " : $gene_display_name";
    $label .= " $start_coord..$end_coord";
    if ( $locus_type eq "CDS" ) {
        $label .= "(${aa_seq_length}aa)";
    } else {
        my $len = $end_coord - $start_coord + 1;
        $label .= "(${len}bp)";
    }

    print "<font color='blue'>"; 
    print "<a href='main.cgi?section=GeneDetail"
	. "&page=geneDetail&gene_oid=$gene_oid'>$gene_oid</a> $label\n";
    print "</font>\n";

    #$dbh->disconnect();
}

############################################################################
# formatHtmlTitle
############################################################################
sub formatHtmlTitle {
    my ( $title, $width ) = @_;

    my $newtitle = "";
    my @toks     = split( "\\s+", $title );
    my $idx      = 1;
    foreach my $tok (@toks) {
        if ( $idx + length($tok) < $width ) {
            $newtitle .= $tok . " ";
            $idx += length($tok) + 1;
        } else {
            $newtitle .= "<br>" . $tok . " ";
            $idx = length($tok) + 1;
        }
    }
    return $newtitle;
}

############################################################################
# printTaxonBreakdownStats - for stats e.g. KEGG, COG, Pfam, TIGRfam
############################################################################
sub printTaxonBreakdownStats {
    my ($mode) = @_;

    my $statTableName = param("statTableName");
    my $pangenome_oid = param("taxon_oid");

    if ( $statTableName eq "dt_kegg_stats" ) {
	    CompareGenomes::printTaxonBreakdownKeggStats($mode, $pangenome_oid);
    } elsif ( $statTableName eq "dt_cog_stats" ) {
        CompareGenomes::printTaxonBreakdownCogStats($mode, 0, $pangenome_oid);
    } elsif ( $statTableName eq "dt_pfam_stats" ) {
        CompareGenomes::printTaxonBreakdownPfamStats($mode, $pangenome_oid);
    } elsif ( $statTableName eq "dt_tigrfam_stats" ) {
        CompareGenomes::printTaxonBreakdownTIGRfamStats($mode, $pangenome_oid);
    } else {
        webLog( "printTaxonBreakdownStats: "
              . "unsupported statTableName='$statTableName'\n" );
        WebUtil::webExit(-1);
    }
}

############################################################################
# printInCategoryCogStats - cog stats for each unique genome group
############################################################################
sub printInCategoryCogStats {
    my ($dbh, $mode, $pangenome_oid, $outputColNames) = @_;
    my @outputCols = @$outputColNames;

    my $sql = qq{ 
        select pcg.genome_count, count(distinct pcg.gene)
        from gene_cog_groups gcg, pangenome_count_genes pcg
        where pcg.gene = gcg.gene_oid
        and pcg.taxon_oid = ?
        group by pcg.genome_count 
        order by pcg.genome_count desc
    }; 
#    my $sql = qq{ 
#        select pcg.genome_count, count(distinct pcg.gene)
# 	 from pangenome_count_genes pcg 
#        where pcg.taxon_oid = ? 
#        group by pcg.genome_count 
#        order by pcg.genome_count desc
#    }; 
#    my $sql = qq{ 
#        select genome_count, gene_count 
#        from pangenome_count 
#        where taxon_oid = ?
#        order by genome_count desc 
#    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $pangenome_oid );

    my %group_count; 
    my @allcategories;
 
    for( ;; ) { 
        my( $genome_count, $cnt ) = $cur->fetchrow( );
        last if !$genome_count; 
	$group_count{ $genome_count } = $cnt; 
	push @allcategories, $genome_count;
    }

    my $sql = qq{
	select cf.definition, pcg.genome_count, count(distinct pcg.gene)
        from gene_cog_groups gcg, cog c, cog_function cf,
             cog_functions cfs, pangenome_count_genes pcg
        where gcg.cog = c.cog_id
	and cfs.cog_id = c.cog_id 
	and cfs.functions = cf.function_code 
	and pcg.gene = gcg.gene_oid
	and pcg.taxon_oid = ?
	group by cf.definition, pcg.genome_count
	order by cf.definition, pcg.genome_count desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pangenome_oid );

    my %name2category;
    my %name2group;

    use CogCategories;
    for( ;; ) {
	my( $category, $genome_count, $cnt ) = $cur->fetchrow( );
	last if !$genome_count; 
	
	my $name = CogCategories::getNameForCategory($category);
	$name2category{ $name } = $category;
	$name2group{ $name } .= $genome_count."-".$cnt."\t";
    }
    $cur->finish(); 
    
    my $it = new InnerTable( 1, "incategorycog$$", "incategorycog", 0 ); 
    my $sd = $it->getSdDelim(); 
    $it->hideAll();
    $it->addColSpec( "Genome Category", "", "left", "", "", "wrap" ); 

    my $colHeader = "Genome Category\t";
    foreach my $col(@outputCols) {
	if ( $col eq "total_cog_gene_count" ) { 
	    $it->addColSpec( "Total COG Gene Count",
			     "", "right", "", "", "wrap" ); 
	    $colHeader .= "Total COG Gene Count\t";
	} elsif ( $col =~ m/_pc$/ ) {
	    my $col2 = $col;
	    chop $col2; chop $col2; chop $col2;
	    next if (!exists $name2group{ $col2 });

	    my $header = $name2category{$col2}."%";
	    $it->addColSpec( $header, "", "right", "", "", "wrap" ); 
	    $colHeader .= $header."\t";
	} else {
	    next if (!exists $name2group{ $col });

	    my $header = $name2category{$col};
	    $it->addColSpec( $header, "", "right", "", "", "wrap" ); 
	    $colHeader .= $header."\t";
	}
    }
    if ($mode eq "export") {
	chop $colHeader;
	print "$colHeader\n";
    }

    foreach my $group (@allcategories) {
	my $row; 
	my $rowVals;
	if ($group == 1) {
	    $row .= "Pangenes in $group Genome only"; 
	} else {
	    $row .= "Pangenes in $group Genomes only";
	} 
	$row .= "\t"; 
	$rowVals = $row;

	foreach my $col0(@outputCols) {
	    my $val;
	    my $pc = 0;
	    my $total_count = $group_count{ $group };
	    my $col = $col0;

	    if ( $col eq "total_cog_gene_count" ) { 
		$val = $total_count;
	    } else {
		if ( $col0 =~ m/_pc$/ ) {
		    $pc = 1;
		    chop $col; chop $col; chop $col;
		}
		next if (!exists $name2group{ $col });

		my @allvalues = split("\t", $name2group{ $col });
		for my $item( @allvalues ) {
		    my ($g, $count) = split("-", $item);
		    if ($g eq $group) {
			if ($pc) {
			    $val = $count / $total_count * 100;
			} else {
			    $val = $count;
			}
			last;
		    }
		}
	    }
	    if ( $pc ) {
		$row .= $val.$sd.sprintf("%.2f%%", $val)."\t"; 
		$rowVals .= sprintf("%.2f%%", $val)."\t";
	    } else {
		$row .= $val.$sd.$val;
		$row .= "\t";
		$rowVals .= $val."\t";
	    }
	}
	$it->addRow($row);
	if ($mode eq "export") {
	    chop $rowVals;
	    print "$rowVals\n";
	}
    }
    if ($mode eq "display") {
	$it->printOuterTable("nopage");
    }
}

############################################################################
# getCompGenomes - returns the list of genomes making up the pangenome
############################################################################
sub getCompGenomes {
    my ( $dbh, $pangenome ) = @_;
    my $sql = qq{
	select pangenome_composition 
        from taxon_pangenome_composition
	where taxon_oid = ?        
    };
    my @a;
    my $cur = execSql( $dbh, $sql, $verbose, $pangenome );
    for ( ; ; ) {
        my ($toid) = $cur->fetchrow();
        last if ( !$toid );
        push( @a, $toid );
    }
    $cur->finish();
    return \@a;
}

1;
