############################################################################
# $Id: ImgStatsOverview.pm 33935 2015-08-07 18:26:22Z klchu $
############################################################################
package ImgStatsOverview;

my $section = "ImgStatsOverview";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use GeneCassette;
use DataEntryUtil;
use HtmlUtil;
use OracleUtil;
use TabViewFrame;
use Date::Format;

my $env             = getEnv();
my $main_cgi        = $env->{main_cgi};
my $section_cgi     = "$main_cgi?section=$section";
my $tmp_url         = $env->{tmp_url};
my $tmp_dir         = $env->{tmp_dir};
my $verbose         = $env->{verbose};
my $web_data_dir    = $env->{web_data_dir};
my $preferences_url = "$main_cgi?section=MyIMG&page=preferences";
my $cgi_dir         = $env->{cgi_dir};
my $cgi_tmp_dir     = $env->{cgi_tmp_dir};

my $img_er                = $env->{img_er};
my $img_hmp               = $env->{img_hmp};
my $img_edu                = $env->{img_edu};
my $img_internal          = $env->{img_internal};
my $img_lite              = $env->{img_lite};
my $include_metagenomes   = $env->{include_metagenomes};
my $include_img_terms     = $env->{include_img_terms};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};
my $enable_cassette       = $env->{enable_cassette};
my $base_url              = $env->{base_url};
my $use_img_gold          = $env->{use_img_gold};
my $YUI                   = $env->{yui_dir_28};
my $web_data_dir          = $env->{web_data_dir};
my $user_restricted_site  = $env->{user_restricted_site};
my $domain_stats_file     = $env->{domain_stats_file};
my $enable_interpro       = $env->{enable_interpro};

my $GENE_TOTAL_COL = "Gene Total";
my $total_gene_count;
my %domain_gene_count;    # hash with gene total for each domain

my @globalDomain = ( "Bacteria", "Archaea", "Eukaryota", "Plasmids", "Viruses", "Genome Fragments" );
push( @globalDomain, "*Microbiome" ) if $include_metagenomes;

my $microbiomeLabel = "Metagenome";    # column heading for *Microbiome
#$microbiomeLabel = "Samples" if $img_hmp;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub getPageTitle {
    return 'IMG Stats Overview';
}

sub getAppHeaderData {
    my ($self) = @_;

    my @a = ();
    
    if ( param('excel') eq 'yes' ) {
        printExcelHeader("stats_export$$.xls");
    } else {
        @a = ("ImgStatsOverview");
    }    
    
    return @a;
}

sub dispatch {

    # if turn off cache
    my $oidsInCart_ref = GenomeCart::getAllGenomeOids();

    if ( $oidsInCart_ref < 0 ) {
        my $time = 3600 * 24;          # 24 hour cache
        my $sid  = getContactOid();
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
    }

    my $page = param("page");

    if ( $page eq "cassetteOccurrence" ) {
        printCassetteOccurrence();
    } elsif ( $page eq "cassetteBox" ) {
        printCassetteBox();
    } elsif ( $page eq "cassetteBoxDetail" ) {
        printCassetteBoxDetail();
    } elsif ( $page eq "bbhOccurrence" ) {
        printBbhOccurrence();
    } elsif ( $page eq "googlemap" ) {
        googleMap_new();
    } elsif ( $page eq "gomolecular" ) {
        printGoMolecular();
    } elsif ( $page eq "gocellular" ) {
        printGoCellular();
    } elsif ( $page eq "seed" ) {
        printSeed();
    } elsif ( $page eq "seedlist" ) {

        # TODO - genome and gene count table
        printSeedList();
    } elsif ( $page eq "seedgenelist" ) {
        printSeedGeneList();
    } elsif ( $page eq "seedtaxonlist" ) {
        printSeedTaxonList();
    } elsif ( $page eq "seedtaxongenelist" ) {
        printSeedTaxonGeneList();
    } elsif ( $page eq "komod" ) {
        printKoMod();
    } elsif ( $page eq "cog" ) {
        printCogList();
    } elsif ( $page eq "coggenelist" ) {
        printCogGeneList();
    } elsif ( $page eq "cogtaxonlist" ) {
        printCogTaxonList();
    } elsif ( $page eq "cogtaxongenelist" ) {
        printCogTaxonGeneList();
    } elsif ( $page eq "pfam" ) {
        printPfamList();
    } elsif ( $page eq "pfamgenelist" ) {
        printPfamGeneList();
    } elsif ( $page eq "pfamtaxonlist" ) {
        printPfamTaxonList();
    } elsif ( $page eq "pfamtaxongenelist" ) {
        printPfamTaxonGeneList();
    } elsif ( $page eq "tigrfam" ) {
        printTigrfamList();
    } elsif ( $page eq "tigrfamgenelist" ) {
        printTigrfamGeneList();
    } elsif ( $page eq "tigrfamtaxonlist" ) {
        printTigrfamTaxonList();
    } elsif ( $page eq "tigrfamtaxongenelist" ) {
        printTigrfamTaxonGeneList();
    } elsif ( $page eq "enzyme" ) {
        printEnzymeList();
    } elsif ( $page eq "enzymegenelist" ) {
        printEnzymeGeneList();
    } elsif ( $page eq "enzymetaxonlist" ) {
        printEnzymeTaxonList();
    } elsif ( $page eq "enzymetaxongenelist" ) {
        printEnzymeTaxonGeneList();
    } elsif ( $page eq "geneWithAllFunc" ) {
        my $dbh = dbLogin();
        printGeneWithAllFunc($dbh);
    } elsif ( $page eq "essential" ) {
        printEssential();
    } elsif ( $page eq 'treeStats' ) {
        printTreeStats();
    } elsif ( $page eq 'treeStatsList' ) {
        printTreeStatsList();
    } else {
        my $dbh = dbLogin();
        printAllStats($dbh);
    }

    # Optional unless you're using mod_perl for FastCGI
    #CGI::Cache::stop();
    #CGI::Cache::pause();
    HtmlUtil::cgiCacheStop() if ( $oidsInCart_ref < 0 );
}

############################################################################
# printAllStats - IMG Statistics; runs from IMG main page
############################################################################
sub printAllStats {
    my ($dbh)      = @_;
    my $indent     = nbsp(4);
    my $table_size = "style='width: 640px;'";

    printStatusLine("Loading ...");
    print "<h1>IMG Statistics</h1>";
    print qq{
	<style type="text/css">
	   div#content_other { width: 100%; }
	</style>
    };
#### start tabs ####

    TabViewFrame::printTabViewMarkup();
    my @tabNames = ( "Genome Statistics", "Gene/Cluster Statistics", "Function/Pathway Statistics" );
    if(!$img_edu) {
        push(@tabNames, "OMICS");
    }
    
    my $super_user = getSuperUser();
    if($super_user eq 'Yes') {
        push(@tabNames, 'Admin Stats');
    }
    
    my @tabIds   = TabViewFrame::printTabViewWidgetStart(@tabNames);

### Tab 1 ###
    TabViewFrame::printTabIdDivStart( $tabIds[0] );
    printGenomeStats($dbh);
    printDNAStats($dbh);
    TabViewFrame::printTabIdDivEnd();

### Tab 2 ###
    TabViewFrame::printTabIdDivStart( $tabIds[1], "class='yui-hidden'" );
    printGeneStats($dbh);
    printClusterStats();
    TabViewFrame::printTabIdDivEnd();

### Tab 3 ###
    TabViewFrame::printTabIdDivStart( $tabIds[2], "class='yui-hidden'" );
    printFunctionStats();
    printPathwayStats();
    TabViewFrame::printTabIdDivEnd();

### Tab 4 ###
    if(!$img_edu) {
    TabViewFrame::printTabIdDivStart( $tabIds[3], "class='yui-hidden'" );
    printExperiments($dbh);
    TabViewFrame::printTabIdDivEnd();
    }
    
    if($super_user eq 'Yes') {
### Tab 5 ###
        TabViewFrame::printTabIdDivStart( $tabIds[4], "class='yui-hidden'" );
        printAdminStats();
        TabViewFrame::printTabIdDivEnd();
    }


    TabViewFrame::printTabViewWidgetEnd();
### End tabs ###

    printStatusLine( "Loaded", 2 );
}

sub printAdminStats {
    print qq{
        <h2>Admin Statistics</h2>
    };
    
    print qq{
        <h2>Isolates Study Viewer</h2>

   <input class="smbutton" type="button" name="table" 
    value="Study Table Viewer" onclick="window.open('main.cgi?section=StudyViewer&page=tableviewisolate', '_self')">

    };
    
    if($include_metagenomes) {
    
    print qq{
        <h2>Samples Study Tree Viewer</h2>
        <p>

   <input class="smbutton" type="button" name="tree" 
    value="Study Tree Viewer" onclick="window.open('main.cgi?section=StudyViewer', '_self')">    
&nbsp;&nbsp;
   <input class="smbutton" type="button" name="table" 
    value="Study Table Viewer" onclick="window.open('main.cgi?section=StudyViewer&page=tableview', '_self')">
    
&nbsp;&nbsp;
   <input class="smbutton" type="button" name="table" 
    value="Sample Table Viewer" onclick="window.open('main.cgi?section=StudyViewer&page=sampletableview&onlyGoldId=1', '_self')">
    </p>
    };
    }

        # phylum breakdown counts
#        print qq{
#        <h2>Phylum Count Statistics</h2>
#        
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Bacteria" 
#    value="Bacteria" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=Bacteria', '_self')">    
#
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Archaea" 
#    value="Archaea" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=Archaea', '_self')">    
#
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Eukaryota" 
#    value="Eukaryota" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=Eukaryota', '_self')">    
#
#   <input class="smbutton" style="min-width: 90px;" type="button" name="GFragment" 
#    value="GFragment" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=GFragment', '_self')">    
#
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Plasmid" 
#    value="Plasmid" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=Plasmid', '_self')">    
#
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Viruses" 
#    value="Viruses" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=Viruses', '_self')">    
#    };
#
#        if ($include_metagenomes) {
#            print qq{
#   <input class="smbutton" style="min-width: 90px;" type="button" name="Metagenomes" 
#    value="Metagenomes" onclick="window.open('main.cgi?section=ImgStatsOverview&page=treeStats&domain=*Microbiome', '_self')">    
#        };
#        }

    
}

############################################################################
# printGenomeStats - Print the genome statistics table by domain
############################################################################
sub printGenomeStats {
    require MainPageStats;
    my %stats  = MainPageStats::mainPageStats();
    my @status = ( "Finished", "Draft", "Permanent Draft", "Total" );

    # @globalDomain defined globally
    my @domain;
    push( @domain, @globalDomain );
    push( @domain, "Total" );

    print "<h2>Genome Count</h2>";

    print <<YUI;
    <link rel="stylesheet" type="text/css"
	href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	   .img-hor-bgColor { background-color: #DBEAFF; }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
	<div class='yui-dt-liner'>
	<span>Status</span>
	</div>
	</th>
YUI
    for my $dom (@domain) {
        my $d = $dom;
        $d = $microbiomeLabel if ( $d eq "*Microbiome" );
        print <<YUI_HEAD;
        <th>
 	    <div class='yui-dt-liner'>
	    <span>$d</span>
	    </div>
	</th>
YUI_HEAD
    }

    my ( $totalCount, $unused ) = MainPageStats::getSumStr_new( \%stats, "All Genomes", "Total" );
    my $totalSum = MainPageStats::getMergedSumStr_new( \%stats, "All Genomes", "Total" );
    $totalCount =~ s/>\/</>##</gi;
    $totalCount =~ s/\/0/##0/gi;
    my @statTotal = split( '##', $totalCount );

    my $idx = 0;
    my $classStr;

    foreach my $st (@status) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        $classStr = "yui-dt-first img-hor-bgColor"
          if ( $st eq "Total" );

        print "<tr class='$classStr' >\n";
        print "<td>\n";
        print "<div class='yui-dt-liner'>";
        print $st;
        print "</div>\n";
        print "</td>\n";

        foreach my $curDom (@domain) {
            my ( $counts, $sum ) = MainPageStats::getCountStr( \%stats, $curDom, "Total" );

            # Replace slashes with ## for spliting later
            $counts =~ s/>\/</>##</gi;
            $counts =~ s/\/0/##0/gi;
            $counts =~ s/0\//0##/gi;

            my @statCounts = split( '##', $counts );
            my $genomeCnt = ( $st eq "Total" ) ? $sum : $statCounts[$idx];
            $statTotal[$idx] = $totalSum if ( $st eq "Total" );
            $genomeCnt = $statTotal[$idx] if ( $curDom eq "Total" );

            $classStr = " yui-dt-asc"
              if ( $curDom eq "Total" );

            print "<td class='$classStr' style='text-align:right' >\n";
            print "<div class='yui-dt-liner'>";
            print $genomeCnt;
            print "</div>\n";
            print "</td>\n";
        }
        $idx++;
        print "</tr>\n";
    }

    print "</table>\n";
    print "</div>\n";
}

############################################################################
# printDNAStats - Print DNA statistics by domain
############################################################################
sub printDNAStats() {
    my ($dbh) = @_;
    my %stats;

    my @rowTitle = ( "DNA, no. of bases", "DNA, no. of coding bases", "DNA, G+C no. of bases", "DNA, Scaffolds" );

    my @domain;
    push( @domain, @globalDomain );    # @globalDomain defined globally
    push( @domain, "Total" );

    print "<h2>DNA Statistics</h2>";

    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
      select sum (total_bases       ),
             sum (total_coding_bases),
             sum (total_gc          ),
             sum (n_scaffolds       )
      from taxon_stats dts
      where exists (select 1 from taxon tx
      where dts.taxon_oid = tx.taxon_oid
      $imgClause       
      and tx.domain = ?)
    };

    my %allStats;
    foreach my $curDom (@domain) {
        my $sqlDom = $curDom;
        if ( $curDom =~ /Plasmid/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "Plasmid%";
        }
        if ( $curDom =~ /Virus/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "Vir%";
        }
        if ( $curDom =~ /Fragment/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "GFragment%";
        }

        my $cur = execSql( $dbh, $sql, $verbose, $sqlDom );
        my @domStats = $cur->fetchrow();
        last if $curDom eq "Total";
        $allStats{$curDom} = \@domStats;
    }

    print <<YUI;
    <link rel="stylesheet" type="text/css"
	href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	   .img-hor-bgColor { background-color: #DBEAFF; }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	    <span>DNA</span>
	    </div>
	</th>
YUI
    for my $dom (@domain) {
        my $d = $dom;
        $d = $microbiomeLabel if ( $d eq "*Microbiome" );
        print <<YUI_HEAD;
        <th>
 	    <div class='yui-dt-liner'>
	    <span>$d</span>
	    </div>
	</th>
YUI_HEAD
    }

    my $idx = 0;
    my $classStr;
    my @colTotal;

    foreach my $title (@rowTitle) {
        my $domCnt   = 0;
        my $rowTotal = 0;
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        $classStr = "yui-dt-first img-hor-bgColor"
          if ( $title eq "Total" );

        print "<tr class='$classStr' >\n";
        print "<td style='white-space:nowrap'>\n";
        print "<div class='yui-dt-liner'>";
        print $title;
        print "</div>\n";
        print "</td>\n";

        foreach my $curDom (@domain) {
            my $count = $allStats{$curDom}[$idx] + 0;
            $rowTotal += $count;

            #$colTotal[$domCnt] += ( $curDom eq "Total" ) ? $rowTotal : $count;
            my $itemCnt = ( $title eq "Total" ) ? $colTotal[$domCnt] : $count;
            $itemCnt = $rowTotal
              if ( $curDom eq "Total" )
              && ( $title ne "Total" );

            #$classStr = " yui-dt-asc"
            #  if ( $curDom eq "Total" );

            # insert commas for thousandths
            $itemCnt =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;

            print "<td class='$classStr' style='text-align:right' >\n";
            print "<div class='yui-dt-liner'>";
            print $itemCnt;
            print "</div>\n";
            print "</td>\n";
            $domCnt++;
        }
        
        
        
        $idx++;
        print "</tr>\n";
    }

    print "</table>\n";
    print "</div>\n";
}

############################################################################
# printGeneStats - Print gene statistics by domain
############################################################################
sub printGeneStats() {
    my ($dbh) = @_;
    my %stats;
    my $indent       = nbsp(4);
    my $doubleIndent = nbsp(8);
    my $delim        = "###";

    my @rowTitleField = (
                          "Total Genes" . $delim . "total_gene_count",
                          "Protein-coding genes total" . $delim . "cds_genes",
                          $indent . "horizontally transferred genes" . $delim . "genes_hor_transfer",
                          $indent . "fused genes" . $delim . "fused_genes",
                          $indent . "genes as fusion components" . $delim . "fusion_components",
                          $indent . "genes with signal peptides" . $delim . "genes_signalp",
                          $indent . "genes with transmembrane segments" . $delim . "genes_transmembrane",
                          "RNA-coding genes total" . $delim . "rna_genes",
                          $indent . "rRNA genes" . $delim . "rrna_genes",
                          $doubleIndent . "5S" . $delim . "rrna5s_genes",
                          $doubleIndent . "16S" . $delim . "rrna16s_genes",
                          $doubleIndent . "18S" . $delim . "rrna18s_genes",
                          $doubleIndent . "23S" . $delim . "rrna23s_genes",
                          $indent . "tRNA genes" . $delim . "trna_genes",
                          $indent . "other RNA genes" . $delim . "other_rna_genes",
                          "Pseudogenes" . $delim . "pseudo_genes",
                          "Obsolete genes" . $delim . "genes_obsolete",
                          "Revised genes" . $delim . "genes_revised"
    );

    my @domain;
    push( @domain, @globalDomain );    # @globalDomain defined globally
    push( @domain, "Total" );

    print "<h2>Gene Statistics</h2>";

    my $sql = "select";
    my @rowTitle;

    foreach my $row (@rowTitleField) {
        my ( $title, $field ) = split( $delim, $row );
        push( @rowTitle, $title );
        if ($field) {
            $sql .= "\tsum(" . $field . "),\n";
        }
    }

    chomp $sql;    # remove the last newline
    chop $sql;     # remove the last comma

    my $imgClause = WebUtil::imgClause('tx');
    $sql .= qq{
        from taxon_stats dts
        where exists (select 1 from taxon tx 
        where dts.taxon_oid = tx.taxon_oid
        $imgClause       
        and tx.domain = ?)
              };

    my %allStats;
    foreach my $curDom (@domain) {
        my $sqlDom = $curDom;
        if ( $curDom =~ /Plasmid/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "Plasmid%";
        }
        if ( $curDom =~ /Virus/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "Vir%";
        }
        if ( $curDom =~ /Fragment/i ) {
            $sql =~ s/tx.domain =/tx.domain like/;
            $sqlDom = "GFragment%";
        }
        my $cur = execSql( $dbh, $sql, $verbose, $sqlDom );
        my @domStats = $cur->fetchrow();
        last if $curDom eq "Total";
        $allStats{$curDom} = \@domStats;

        # Get protein coding gene totals for each domain
        # Used for percentage calculation
        $domain_gene_count{$curDom} = $domStats[1];
    }

    print <<YUI;
    <link rel="stylesheet" type="text/css"
	href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	   .img-hor-bgColor { background-color: #DBEAFF; }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	    <span>Gene</span>
	    </div>
	</th>
YUI
    for my $dom (@domain) {
        my $d = $dom;
        $d = $microbiomeLabel if ( $d eq "*Microbiome" );
        print <<YUI_HEAD;
        <th>
 	    <div class='yui-dt-liner'>
	    <span>$d</span>
	    </div>
	</th>
YUI_HEAD
    }

    # the following variable is used to check whether
    # the previous was a total and hence needs both upper and
    # lower border lines. The class is set accordingly.
    # Sort of a hack, but works. +BSJ 09/21/11
    my $prevLineIsTotal;
    my @colTotal;

    my $idx = 0;
    my $classStr;

    foreach my $title (@rowTitle) {
        my $domCnt   = 0;
        my $rowTotal = 0;
        $classStr = ( !$idx || $prevLineIsTotal ) ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        $classStr = "yui-dt-first img-hor-bgColor"
          if ( $title =~ /Total/ );
        $prevLineIsTotal = ( $title =~ /Total/ ) ? 1 : 0;

        print "<tr class='$classStr' >\n";
        print "<td style='white-space:nowrap'>\n";
        print "<div class='yui-dt-liner'>";
        print $title;
        print "</div>\n";
        print "</td>\n";

        foreach my $curDom (@domain) {
            my $count = $allStats{$curDom}[$idx] + 0;
            $rowTotal += $count;

            $colTotal[$domCnt] += ( $curDom eq "Total" ) ? $rowTotal : $count;
            my $itemCnt = ( $title eq "Total" ) ? $colTotal[$domCnt] : $count;
            $itemCnt = $rowTotal
              if ( $curDom eq "Total" )
              && ( $title ne "Total" );

            $classStr = " yui-dt-asc"
              if ( $curDom eq "Total" );

            # Get Total Gene Count for calculating %total later
            # $total_gene_count defined globally
            $total_gene_count = $itemCnt
              if ( $title eq $GENE_TOTAL_COL && $curDom eq "Total" );

            # insert commas for thousandths
            $itemCnt =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;

            print "<td class='$classStr' style='text-align:right' >\n";
            print "<div class='yui-dt-liner'>";
            print $itemCnt;
            print "</div>\n";
            print "</td>\n";
            $domCnt++;
        }
        $idx++;
        print "</tr>\n";
    }

    print "</table>\n";
    print "</div>\n";
}

############################################################################
# printClusterStats - Print cluster statistics by domain
############################################################################
sub printClusterStats() {
    my $header = "Cluster";

    # Keep EggNOG stats internal +BSJ 11/30/11
    my $eggNogText = "EggNOG total" if ($img_internal);

    # Include cassette stats as per WebConfig settings
    my $cassettes = "IMG Chromosomal Cassettes total"
      if ($enable_cassette);

    my $enable_synthetic = $env->{enable_biocluster};

    my $synthetic = "IMG Biosynthetic Pathways total"
      if ($enable_synthetic);

    my $interproText = 'InterPRO total' if($enable_interpro);
    my @rowTitleField = (
                          "COG total", "KOG total", "Pfam total", "TIGRfam total",
                          $eggNogText,
                          $interproText,
                          "IMG Ortholog Clusters total",
                          "IMG Paralog Clusters total",
                          $cassettes, $synthetic,
    );

    commonStats( $header, \@rowTitleField );
}

############################################################################
# printFunctionStats - Print function statistics by domain
############################################################################
sub printFunctionStats() {
    my $header = "Function";

    my @rowTitleField = (
                          "Product Names total",
                          "No Product Names total",
                          "Enzyme total",
                          "IMG Terms total",
                          "GO-Molecular Functions total",
                          "KO Terms total",
#                          "SEED total",
                          "Swiss-Prot total"
    );



    commonStats( $header, \@rowTitleField );
}

############################################################################
# printPathwayStats - Print pathway statistics by domain
############################################################################
sub printPathwayStats() {
    my $header = "Pathway";

    my @rowTitleField = (
        "COG Pathways total",

        #        "KOG Pathways total",
        "KEGG Pathways total",
        "KO Modules total",
        "TIGRfam Roles total",
        "IMG Pathways total",
        "IMG Parts List total",
        "MetaCyc total",
        "GO-Biological Process total",
 #       "SEED Subsystems total"
    );

    commonStats( $header, \@rowTitleField );
}

############################################################################
# commonStats - sub common to cluster, function, and pathway statistics
############################################################################
sub commonStats {
    my ( $header, $rowTitle_ref ) = @_;

   
    my @rowTitleField = @$rowTitle_ref;
    my @domain;
    push( @domain, @globalDomain );    # @globalDomain defined globally

    # Get time stamp of domain stats file
    if(!-e $domain_stats_file) {
        print qq{
            <p>
            Statistics file $domain_stats_file was not found.
        };
        return;
    }
    
    my $timeStamp;
    my $touchFileTime = fileAtime($domain_stats_file);

    # Date format: ddd, mmm d yyyy hh:mm am/pm (LC_DATE locale format)
    $touchFileTime = Date::Format::time2str( "%a, %b %e %Y %l:%M %P %Z", $touchFileTime );
    $timeStamp = "<span style='font-size:12px;font-style:italic;'>";
    $timeStamp .= "(Last updated: " . $touchFileTime . ")</span>";

    print "<h2>$header Statistics $timeStamp</h2>";
    my %allStats;

=sample structure of %allStats
    %allStats = {
	'Bacteria' => {
            #        total genes, genes with, percent
	    'Pfam' => [ '7467', 7225761, '62.11%' ],
	    'COG' => [ '4524', 6727453, '57.82%' ],
	    'TIGRfam' => [ '3688', 2931661, '25.20%' ],
	    .
	    .
	    .
	},
	'Archaea' => {
	    'Pfam' => [ '3177', 178880, '1.54%' ],
	    'COG' => [ '2969', 175017, '1.50%' ],
	    'TIGRfam' => [ '1614', 63605, '0.55%' ],
	    .
	    .
	    .
	},
	.
	.
	.
    }; 
=cut

    my @arrDomStat;
    if ( -e $domain_stats_file ) {    # get stats from stats file
        @arrDomStat = tabFile2Array($domain_stats_file);
    }

    my %grandTotal;
    for my $stat (@arrDomStat) {
        my %itemStats;
        my ( $name, $domain, $total_count, $genes_with ) = @$stat;
        my $curDomTotal = $domain_gene_count{$domain};
        my $percent     = 0;

        # Get the grand totals
        if ( $domain eq "Total" ) {
            $grandTotal{$name} = $total_count;
            next;
        }

        # Calculate percent if domain total is non-zero
        if ($curDomTotal) {
            $percent = $genes_with * 100 / $curDomTotal;
            $percent = sprintf( "%.2f%%", $percent );
        }

        $allStats{$domain}{$name} = [ $total_count, $genes_with, $percent ];
    }

    # Get index of last element of the array $itemStats{$name}.
    # This is the (no. of rows) - 1 of stats for each cluster/function (COG, Pfam, etc.).
    # Used later to loop through rows.
    my $cntRow = $#{ $allStats{ @domain[0] }{ ( keys %{ $allStats{ @domain[0] } } )[0] } };

    print <<YUI;
    <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	   .img-hor-bgColor { background-color: #DBEAFF; }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>$header</span>
	    </div>
	</th>
YUI
    for my $dom (@domain) {
        my $d = $dom;
        $d = $microbiomeLabel if ( $d eq "*Microbiome" );
        print <<YUI_HEAD;
            <th>
 	    <div class='yui-dt-liner'>
	        <span>$d</span>
	    </div>
	    </th>
YUI_HEAD
    }

    my $idx = 0;
    foreach my $title (@rowTitleField) {

        # ignore blank titles
        if ($title) {
            for my $i ( 0 .. $cntRow ) {
                printDomainCounts( \%allStats, $title, $i, $idx, \@domain, \%grandTotal );
                $idx++;
            }
        }
    }

    print "</table>\n";
    print "</div>\n";
    print "<p><i><b>Note:</b> All percentages are calculated for their respective domains.</i></p>";
}

############################################################################
# tabFile2Array - return a 2-D array from a tab delimited file
############################################################################
sub tabFile2Array {
    my ($filePath) = @_;
    my @array;
    if ( -e ($filePath) ) {
        my $fh = newReadFileHandle($filePath);

        while ( my $line = $fh->getline() ) {
            chomp $line;
            push @array, [ split( /\t/, $line ) ];
        }
    }
    return @array;
}

############################################################################
# printDomainCounts - print total counts, genewith and percent
############################################################################
sub printDomainCounts() {
    my ( $allStats, $title, $rowType, $idx, $domain, $grandTotal ) = @_;
    my $indent = nbsp(4);
    my $classStr;
    my @rowTitle = ( $title, $indent . "Protein coding genes with", $indent . "% total protein coding genes" );
    my $field = $title;
    $field =~ s/ total//gi;

    $classStr = ( !$idx || $rowType == 1 ) ? "yui-dt-first " : "";
    $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    $classStr = "yui-dt-first img-hor-bgColor"
      if ( $rowType == 0 );    # print row bottom border if protein genes with

    my $curTitle = $rowTitle[$rowType];

    # Get grand total for first row of current item
    my $itemGrandTotal = $grandTotal->{$field} if $rowType == 0;

    # Insert commas for thousandths
    $itemGrandTotal =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;

    my $curGrandTotal = " ($itemGrandTotal)" if $itemGrandTotal;

    # Show totals for all systems -BSJ 10/19/12
    #$curTitle =~ s/ \(.*\)//gi if !$include_metagenomes;
    print "<tr class='$classStr' >\n";
    print "<td>\n";
    print "<div class='yui-dt-liner'>";
    print $curTitle . $curGrandTotal;
    print "</div>\n";
    print "</td>\n";

    foreach my $curDom (@$domain) {

        # Get cluster/function numbers for each domain
        my $count = $allStats->{$curDom}->{$field}[$rowType];

        # Insert commas for thousandths
        $count =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;

        print "<td class='$classStr' style='text-align:right' >\n";
        print "<div class='yui-dt-liner'>";
        print $count;
        print "</div>\n";
        print "</td>\n";
    }
    print "</tr>\n";
}

############################################################################
# getDomainHeader - Return special cases of domain labels
############################################################################
sub getDomainHeader {
    my ($sqlDomain) = @_;
    if ( $sqlDomain =~ /Plasmid/i ) {
        return "Plasmids";
    }
    if ( $sqlDomain =~ /Vir/i ) {
        return "Viruses";
    }
    if ( $sqlDomain =~ /Fragment/i ) {
        return "Genome Fragments";
    }
    return $sqlDomain;
}

############################################################################
# printExperiments - Print experiment statistics by domain
############################################################################
sub printExperiments {
    my ($dbh) = @_;

    my $methylomicscount = 0;
    my $methylomics_data = $env->{methylomics};
    if ($methylomics_data) {
        $methylomicscount = 1;
    }

    my $rnaseqcount = 0;
    my $rnaseq_data = $env->{rnaseq};
    if ($rnaseq_data) {
        $rnaseqcount = 1;
    }

    my $proteincount = 0;
    my $proteomics_data = $env->{proteomics};
    if ($proteomics_data) {
        $proteincount = 1;
    }

    my @rowTitles;
    if ( $proteincount > 0 ) {
        push @rowTitles, "Protein Experiments";
    }
    if ( $rnaseqcount > 0 ) {
        push @rowTitles, "RNASeq Studies";
    }
    if ( $methylomicscount > 0 ) {
	push @rowTitles, "Methylation Experiments";
    }

    push @rowTitles, "Essential Gene Experiments";
    push @rowTitles, "Total";

    my @domains = ( "Bacteria", "Archaea", "Eukaryota", "Plasmids", 
		    "Viruses", "Genome Fragments" );
    push( @domains, "*Microbiome" ) if $include_metagenomes;
    push( @domains, "Total" );

    print "<h2>OMICS statistics</h2>";

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
         select count(distinct g.taxon), tx.domain
         from gene_essential_genes ge, gene g, taxon tx
         where ge.gene_oid = g.gene_oid
         $rclause
         $imgClause
         and g.taxon = tx.taxon_oid
         and tx.is_public = 'Yes'
         group by tx.domain
         order by tx.domain
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %essential_exps;
    for ( ;; ) {
        my ( $cnt, $domain ) = $cur->fetchrow();
        last if !$cnt;
        $essential_exps{ getDomainHeader($domain) } = $cnt;
    }

    my %protein_exps;
    if ( $proteincount > 0 ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{                           
            select count(distinct exp_oid), tx.domain
            from ms_experiment e, ms_sample s, taxon tx
            where e.exp_oid = s.experiment
            $rclause
            $imgClause
            and s.IMG_taxon_oid = tx.taxon_oid
            and tx.is_public = 'Yes'                                         
            group by tx.domain
            order by tx.domain
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ;; ) {
            my ( $cnt, $domain ) = $cur->fetchrow();
            last if !$cnt;
            $protein_exps{ getDomainHeader($domain) } = $cnt;
        }
    }

    my %rnaseq_exps;
    if ( $rnaseqcount > 0 ) { 
        require RNAStudies;
        my $rclause    = WebUtil::urClause('tx');
        my $imgClause  = WebUtil::imgClause('tx');
	my $datasetClause = RNAStudies::datasetClause('dts');

	# metagenomes only:
	my $rnaseq_sql = qq{
            select tx.domain, count(distinct gs.study_name)
            from rnaseq_dataset dts, gold_study\@imgsg_dev gs,
                 gold_sp_study_gold_id\@imgsg_dev gssg, taxon tx
            where dts.gold_id = gssg.gold_id
            and gssg.study_gold_id = gs.gold_id
            and dts.reference_taxon_oid = tx.taxon_oid
            $rclause
            $imgClause
            $datasetClause
            group by tx.domain
            order by tx.domain
        };
        $cur = execSql( $dbh, $rnaseq_sql, $verbose );
        for ( ;; ) {
            my ( $domain, $cnt ) = $cur->fetchrow();
            last if !$cnt;
            $rnaseq_exps{ getDomainHeader($domain) } = $cnt;
        }
        $cur->finish();
    }

    my %methylomics_exps;
    if ( $methylomicscount > 0 ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
            select count(distinct exp_oid), tx.domain
            from meth_experiment e, meth_sample s, taxon tx
            where e.exp_oid = s.experiment
            $rclause
            $imgClause
            and s.IMG_taxon_oid = tx.taxon_oid
            and tx.is_public = 'Yes'
            group by tx.domain
            order by tx.domain
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ;; ) {
            my ( $cnt, $domain ) = $cur->fetchrow();
            last if !$cnt;
            $methylomics_exps{ getDomainHeader($domain) } = $cnt;
        }
    }

    print <<YUI;
    <link rel="stylesheet" type="text/css"
	href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	<style type="text/css">
	.img-hor-bgColor { background-color: #DBEAFF;
    }
    </style>

    <div class='yui-dt'>
    <table style='font-size:12px'>
    <th>
        <div class='yui-dt-liner'>
        <span>Experiment Type</span>
        </div>
    </th>
YUI
    foreach my $dom (@domains) {
        my $d = $dom;
        $d = $microbiomeLabel if ( $d eq "*Microbiome" );
        print <<YUI_HEAD;
	<th>
	    <div class='yui-dt-liner'>
	    <span>$d</span>
	    </div>
	</th>
YUI_HEAD
    }

    # rows in order are: protein, rnas, essential gene exps
    my $url1 = "$main_cgi?section=IMGProteins&page=proteomics";
    my $url2 = "$main_cgi?section=RNAStudies&page=rnastudies";
    my $url3 = "$section_cgi&page=essential";
    my $url4 = "$main_cgi?section=Methylomics&page=methylomics";
    my @urls;
    if ( $proteincount > 0 ) {
        push @urls, $url1;
    }
    if ( $rnaseqcount > 0 ) {
        push @urls, $url2;
    }
    if ($methylomicscount > 0) {
	push @urls, $url4;
    }
    push @urls, $url3;

    my $idx = 0;
    my $classStr;
    my @colTotals;
    my $prevLineIsTotal;

    foreach my $title (@rowTitles) {
        $classStr = ( !$idx || $prevLineIsTotal ) ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        $classStr = "yui-dt-first img-hor-bgColor"
          if ( $title =~ /Total/ );
        $prevLineIsTotal = ( $title =~ /Total/ ) ? 1 : 0;

        print "<tr class='$classStr' >\n";
        print "<td>\n";
        print "<div class='yui-dt-liner'>";
        print $title;
        print "</div>\n";
        print "</td>\n";

        my $col_idx  = 0;
        my $rowTotal = 0;

        foreach my $curDom (@domains) {
            my $count = 0;
            if ( $proteincount > 0 ) {
                $count = $protein_exps{$curDom}
                  if $title eq "Protein Experiments";
            }
            if ( $rnaseqcount > 0 ) {
                $count = $rnaseq_exps{$curDom}
                  if $title eq "RNASeq Studies";
            }
	    if ( $methylomicscount > 0 ) {
		$count = $methylomics_exps{$curDom}
		if $title eq "Methylation Experiments";
	    }
            $count = $essential_exps{$curDom}
              if $title eq "Essential Gene Experiments";

            $rowTotal += $count;

            if ( blankStr($count) ) {
                $count = 0;
            }
            $colTotals[$col_idx] += ( $curDom eq "Total" ) ? $rowTotal : $count;
            my $itemCnt = ( $title eq "Total" ) ? $colTotals[$col_idx] : $count;
            $itemCnt = $rowTotal
              if ( $curDom eq "Total" )
              && ( $title ne "Total" );

            my $link = $itemCnt;
            $link = alink( $urls[$idx], $itemCnt )
              if ( $itemCnt > 0 && $title ne "Total" && $curDom eq "Total" );
            $link = alink( $urls[$idx] . "&domain=$curDom", $itemCnt )
              if ( $itemCnt > 0 && $title ne "Total" && $curDom ne "Total" );

            $classStr = " yui-dt-asc"
              if ( $curDom eq "Total" );

            print "<td class='$classStr' style='text-align:right' >\n";
            print "<div class='yui-dt-liner'>";
            print $link;
            print "</div>\n";
            print "</td>\n";
            $col_idx++;
        }

        $idx++;
        print "</tr>\n";
    }
    print "</table>\n";
    print "</div>\n";
}

#
# gene count to number of cassettes
sub printCassetteOccurrence {
    print "<h1>\n";
    print "IMG Chromosomal Cassette Occurrence\n";
    print "</h1>\n";

    my $dbh = dbLogin();
    printStatusLine("Loading ...");

    my $rec_aref = getGeneCountOccurrence($dbh);

    #$dbh->disconnect();

    my $it = new InnerTable( 1, "cassetteOccur$$", "cassetteOccur", 1 );

    $it->addColSpec( "Gene Count", "number desc", "right" );
    $it->addColSpec( "Occurrence", "number asc",  "right" );

    my $sd = $it->getSdDelim();    # sort delimiter

    foreach my $line (@$rec_aref) {
        my ( $gene_count, $occurrence ) = split( /\t/, $line );
        my $r;
        $r .= $gene_count . $sd . "\t";
        $r .= $occurrence . $sd . "\t";
        $it->addRow($r);
    }
    $it->printOuterTable(1);

    my $count = $#$rec_aref + 1;
    printStatusLine( "Loaded $count", 2 );
}

sub printCassetteBox {
    my $type  = param("type");
    my $title = GeneCassette::getTypeTitle($type);

    print "<h1>\n";
    print "Conserved Cassette Occurrence <br> by " . $title;
    print "</h1>\n";

    my $dbh = dbLogin();
    printStatusLine("Loading ...");
    my $recs_aref = getCassetteBoxClusterCount( $dbh, $type );

    #$dbh->disconnect();

    my $it = new InnerTable( 1, "cassetteBox" . $type . "$$", "cassetteBox$type", 0 );

    $it->addColSpec( "Cluster Count", "number desc", "right" );
    $it->addColSpec( "Occurrence",    "number desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimiter

    my $url = "$section_cgi&page=cassetteBoxDetail&type=$type";

    foreach my $line (@$recs_aref) {
        my ( $cluster_count, $occurrence ) =
          split( /\t/, $line );

        my $tmpurl = $url . "&cluster_count=$cluster_count";
        $tmpurl = alink( $tmpurl, $cluster_count );
        my $r;
        $r .= $cluster_count . $sd . $tmpurl . "\t";
        $r .= $occurrence . $sd . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    my $cnt = $#$recs_aref + 1;
    printStatusLine( "Loaded $cnt", 2 );
}

sub printCassetteBoxDetail {
    my $cluster_count = param("cluster_count");
    my $type          = param("type");
    my $file          = param("file");            # cache file name
    my $postion       = param("postion");         # file postion
    my $total         = param("total");           # total number of lines or recs
    my $pindex        = param("pindex");          # page index

    # my $prev_postion  = param("prev_postion");   # previous file postion
    my $max = 1000;                               # max lines to show per page

    # TODO I have total number of lines - how to do page index and a better
    # previous

    my $title = GeneCassette::getTypeTitle($type);

    print "<h1>\n";
    print "Chromosomal Cassette Occurrence <br> by " . $title . " Details";
    print "</h1>\n";

    printStatusLine("Loading ...");

    my $recs_aref;

    if ( $file eq "" ) {

        # do sql
        my $dbh = dbLogin();
        $recs_aref = getCassetteBoxDetail( $dbh, $cluster_count, $type );

        #$dbh->disconnect();

        $file   = cacheData($recs_aref);
        $total  = $#$recs_aref + 1;
        $pindex = 1;
        ( $recs_aref, $postion ) = readCacheData( $file, 0 );

        #$prev_postion = 0;
    } else {

        #$prev_postion = $postion;
        # read cache file
        ( $recs_aref, $postion ) = readCacheData( $file, $postion );
    }

    my $it = new InnerTable( 1, "cassetteBoxDetail" . $type . "$$", "cassetteBoxDetail$type", 0 );

    $it->addColSpec( "Box ID",         "number asc",  "right" );
    $it->addColSpec( "Cluster Count",  "number desc", "right" );
    $it->addColSpec( "Cassette Count", "number desc", "right" );
    $it->addColSpec( "Genome Count",   "number desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimiter

    my $count = 0;
    foreach my $line (@$recs_aref) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count ) =
          split( /\t/, $line );
        my $r;
        $r .= $box_oid . $sd . "\t";
        $r .= $cluster_count . $sd . "\t";
        $r .= $cass_count . $sd . "\t";
        $r .= $taxon_count . $sd . "\t";
        $it->addRow($r);
        $count++;
    }

    my $cnt = ( $pindex - 1 ) * $max + ( $#$recs_aref + 1 );

    print "<p>\n";

    if ( $pindex > 1 ) {
        print "<a href='javascript:history.back()'> &lt;Prev </a> &nbsp;";
    }

    if ( $cnt < $total ) {
        $pindex++;
        my $url =
            "$section_cgi&page=cassetteBoxDetail&type=$type"
          . "&file=$file"
          . "&postion=$postion"
          . "&total=$total"
          . "&pindex=$pindex";
        print alink( $url, "Next>" );

    }
    print "</p>\n";

    $it->printOuterTable(1);
    print "<p>Row count: $count</p>\n";

    print "<p>\n";

    if ( ( $pindex - 1 ) > 1 ) {
        print "<a href='javascript:history.back()'> &lt;Prev </a> &nbsp;";
    }

    if ( $cnt < $total ) {
        my $url =
            "$section_cgi&page=cassetteBoxDetail&type=$type"
          . "&file=$file"
          . "&postion=$postion"
          . "&total=$total"
          . "&pindex=$pindex";
        print alink( $url, "Next>" );
    }

    print "</p>\n";
    printStatusLine( "Loaded $cnt of $total", 2 );
}

sub printBbhOccurrence {
    print "<h1>\n";
    print "IMG Ortholog Clusters Occurrence\n";
    print "</h1>\n";

    my $dbh = dbLogin();
    printStatusLine("Loading ...");

    my $sql = qq{  
    select a.cnt as gene_count, count(*) as occurrence
    from (    
        select b.cluster_id, count(b.member_genes) as cnt
        from bbh_cluster_member_genes b
        group by b.cluster_id    
            ) a
    group by a.cnt
    order by 1 desc 
    };

    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_count, $occurrence ) = $cur->fetchrow();
        last if !$gene_count;
        push( @recs, "$gene_count\t$occurrence" );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $it = new InnerTable( 1, "bbh$$", "bbhOccur", 1 );

    $it->addColSpec( "Gene Count", "number desc", "right" );
    $it->addColSpec( "Occurrence", "number asc",  "right" );

    my $sd = $it->getSdDelim();    # sort delimiter

    foreach my $line (@recs) {
        my ( $gene_count, $occurrence ) = split( /\t/, $line );
        my $r;
        $r .= $gene_count . $sd . "\t";

        $r .= $occurrence . $sd . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    my $count = $#recs + 1;
    printStatusLine( "Loaded $count", 2 );
}

#
# javascript form
#
sub printJSForm {

    print qq{
        <script language="JavaScript" type="text/javascript">
        <!--
        function mySubmit (gcnt, ocnt ) {
            document.mainForm2.occurrence.value = ocnt;
            document.mainForm2.gene_count.value = gcnt;
            document.mainForm2.submit();
        }
        -->
        </script>    
    };

    WebUtil::printMainFormName("2");

    print qq{  
        <p> Select Protein Cluster for occurrence count link &nbsp;&nbsp;
        <select name='protein' >
        <option value="cog" selected>COG &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>
        <option value="bbh" title="Bidirectional Best hits (MCL)">IMG Ortholog Cluster</option>
        <option value="pfam">Pfam</option> 
        </select>
        </p>       
    };

    print hiddenVar( "page",       "cassetteBox" );
    print hiddenVar( "section",    $section );
    print hiddenVar( "occurrence", "0" );
    print hiddenVar( "gene_count", "0" );

    print end_form();
}

#
#
# return a array of tab delimited gene coun to occurrences
sub getGeneCountOccurrence {
    my ($dbh) = @_;

    #  slow query
    my $sql = qq{
    select a.cnt as gene_count, count(*) as occurrence
    from (
        select gcg.cassette_oid, count(gcg.gene) as cnt
        from gene_cassette_genes gcg
        group by gcg.cassette_oid
        ) a
    group by a.cnt
    order by 1 desc 
    };

    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_count, $occurrence ) = $cur->fetchrow();
        last if !$gene_count;
        push( @recs, "$gene_count\t$occurrence" );
    }
    $cur->finish();

    return \@recs;
}

sub getCassetteBoxClusterCount {
    my ( $dbh, $type ) = @_;

    #  slow query
    my $sql;

    if ( $type eq "bbh" ) {
        $sql = qq{
        select nvl(cluster_count,-1), count(*)
        from cassette_box_bbh
        group by cluster_count
        order by 1 desc
        };
    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select cluster_count, count(*)
        from cassette_box_pfam
        group by cluster_count
        order by 1 desc
        };
    } else {

        # cog default
        $sql = qq{
        select cluster_count, count(*)
        from cassette_box_cog
        group by cluster_count
        order by 1 desc
        };
    }

    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cluster_count, $count ) = $cur->fetchrow();
        last if !$cluster_count;
        push( @recs, "$cluster_count\t$count" );
    }
    $cur->finish();

    return \@recs;
}

sub getCassetteBoxDetail {
    my ( $dbh, $count, $type ) = @_;

    #  slow query
    my $sql;

    if ( $type eq "bbh" ) {
        $sql = qq{
        select box_oid, cluster_count, cass_count, taxon_count
        from cassette_box_bbh
        where cluster_count = ?
        order by box_oid
        };
    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select box_oid, cluster_count, cass_count, taxon_count
        from cassette_box_pfam
        where cluster_count = ?
        order by box_oid
        };
    } else {
        $sql = qq{
        select box_oid, cluster_count, cass_count, taxon_count
        from cassette_box_cog
        where cluster_count = ?
        order by box_oid
        };
    }

    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose, $count );
    for ( ; ; ) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count ) = $cur->fetchrow();
        last if !$box_oid;
        push( @recs, "$box_oid\t$cluster_count\t$cass_count\t$taxon_count" );
    }
    $cur->finish();

    return \@recs;
}

sub cacheData {
    my ($recs_aref) = @_;

    my $cacheFile = "imgStatsOverview$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $res       = newWriteFileHandle( $cachePath, "imgstat" );

    foreach my $line (@$recs_aref) {
        print $res "$line\n";
    }
    close $res;

    return $cacheFile;
}

sub readCacheData {
    my ( $cacheFile, $curpos ) = @_;

    $curpos = 0 if ( $curpos eq "" );

    my $maxsize = 1000;
    my $count   = 0;

    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $res = newReadFileHandle( $cachePath, "imgStat" );
    seek( $res, $curpos, 0 );

    my @recs;
    while ( my $line = $res->getline() ) {
        chomp $line;
        push( @recs, $line );
        $count++;
        last if ( $count >= $maxsize );
    }

    my $pos = tell($res);
    close $res;
    return ( \@recs, $pos );
}

sub getEnvSample_v20 {
    my ($dbh, $type) = @_;
    $type = 'metagenome' if $type eq '';
    my $sql;
    my $totalGenome = 0;
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    if ($type eq 'metagenome') {

        # total metagenome count
        $sql = qq{
select count(*)
from taxon t
where t.genome_type = 'metagenome'
and t.obsolete_flag = 'No'
$rclause
$imgClause 
        };
     } elsif ($type eq 'genome') {
        $sql = qq{
select count(*)
from taxon t
where t.genome_type = 'isolate'
and t.obsolete_flag = 'No'
and t.domain in ('Bacteria', 'Archaea' ,'Eukaryota')
$rclause
$imgClause
        };
    } 
    
    if($type eq 'genome' || $type eq 'metagenome') {
        my $cur = execSql( $dbh, $sql, $verbose );
        ($totalGenome) = $cur->fetchrow();
    } elsif ($type eq 'cart') {
        my $oidsInCart_ref = GenomeCart::getAllGenomeOids();
        $totalGenome = $#$oidsInCart_ref + 1;
    }
    
    if ($type eq 'metagenome') {
        $sql = qq{
select distinct t.taxon_oid, t.taxon_display_name, 
p.geo_location, p.latitude, p.longitude, p.altitude
from taxon t, GOLD_SEQUENCING_PROJECT p
where p.GOLD_ID = t.SEQUENCING_GOLD_ID
and t.genome_type = 'metagenome'
and t.obsolete_flag = 'No'
and p.longitude is not null 
and p.latitude is not null
$rclause
$imgClause
order by 4, 5, 3, 2
      };

    } elsif ($type eq 'genome') {
        $sql = qq{
select distinct t.taxon_oid, t.taxon_display_name, 
p.geo_location, p.latitude, p.longitude, p.altitude
from taxon t, GOLD_SEQUENCING_PROJECT p
where p.GOLD_ID = t.SEQUENCING_GOLD_ID
        and t.genome_type = 'isolate'
        and t.domain in ('Bacteria', 'Archaea' ,'Eukaryota')
        and t.obsolete_flag = 'No'
        and p.longitude is not null 
        and p.latitude is not null
        order by 4, 5, 3, 2
      };
    } elsif($type eq 'cart') {
        $sql = qq{
select distinct t.taxon_oid, t.taxon_display_name, 
p.geo_location, p.latitude, p.longitude, p.altitude
from taxon t, GOLD_SEQUENCING_PROJECT p
where p.GOLD_ID = t.SEQUENCING_GOLD_ID
        and t.obsolete_flag = 'No'
        and p.longitude is not null 
        and p.latitude is not null
        order by 4, 5, 3, 2
      };        
    }

    my @recs;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $name, $geo_location, $latitude, $longitude, $altitude ) = $cur->fetchrow();
        last if !$taxon_oid;
        $latitude  = strTrim($latitude);
        $longitude = strTrim($longitude);
        if ( $latitude eq '' || $longitude eq '' ) {
            next;
        }
        push( @recs, "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude" );
    }
    $cur->finish();

    return ( \@recs, ( $totalGenome - ( $#recs + 1 ) ) );
}


# api v3
# gold metagenome query
#select p.project_oid, p.domain ,p.display_name, p.img_oid,
#es.sample_oid, es.gold_id, es.sample_display_name, es.longitude, es.latitude, es.altitude, es.geo_location
#from env_sample es, project_info p
#where es.project_info = p.project_oid
#and p.gold_stamp_id is not null
#and p.img_oid is not null
#and p.domain = 'MICROBIAL'
#order by p.project_oid, es.sample_oid
#
# metag genome query for img/m
#    select t.taxon_oid, t.taxon_display_name, e.geo_location,
#    e.latitude, e.longitude, e.altitude
#    from env_sample e, taxon t
#    where e.sample_oid = t.taxon_oid
#    and t.is_public = 'Yes'
#    and t.domain = '*Microbiome'
#    and e.latitude is not null
#    and e.longitude is not null
#    order by e.latitude, e.longitude, e.geo_location, t.taxon_display_name
#
sub googleMap_new {

    # flag=1 -> show only those genomes in the cart
    # flag=0 or missing -> show all genomes
    my $flag_mapCart = param('mapcart');
    my $type = param('type');
    $type = 'metagenome' if $type eq '';

    my $hmpMetagenomeCnt = 748;    # no metadata
    if ($type eq 'metagenome') {
        print "<h1>Metagenome Projects Map</h1>";
    } elsif($type eq 'genome') {
        print "<h1>Projects Map</h1>";
    } elsif($type eq 'cart') {
        print "<h1>Genome Cart Map</h1>";
    }

    # get Oids for genomes in cart
    my $oidsInCart_ref = GenomeCart::getAllGenomeOids();

    # number of oids in cart
    my $count_cart = $#$oidsInCart_ref + 1;

    if (  !$flag_mapCart   &&  $count_cart  ) {
        print qq{
            <p>
            <a href="$main_cgi?section=ImgStatsOverview&page=googlemap&mapcart=1&type=cart">Map genomes in cart</a>
            </p>
        };
    } elsif ( $flag_mapCart && $count_cart ) {
        print qq{
            <p>Showing genomes in cart&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <a href="$main_cgi?section=ImgStatsOverview&page=googlemap&type=genome">Map all genomes</a>
            &nbsp;&nbsp;
            <a href="$main_cgi?section=ImgStatsOverview&page=googlemap&type=metagenome">Map all metagenomes</a>
            </p>
        };            
    }


#    print qq{
#          <p>
#          Only public projects that have longitude/latitude coordinates in 
#          GOLD are displayed on this map.
#          </p>  
#    };

    printStatusLine("Loading ...");
    my $dbh = dbLogin();

    my $gmapkey = getGoogleMapsKey();

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude"
    # only public genomes
    my ( $recs_aref, $count_rejected_getEnvSample ) = getEnvSample_v20($dbh, $type);

    # count_rejected_getEnvSample returned by getEnvSample contains the
    # number of genomes out of the whole database with missing coords data.

    #$dbh->disconnect();

    my $tmp = $#$recs_aref + 1;
    if ($type eq 'metagenome') {
        print qq{
        <p>
        $tmp samples. <br/>
        Some samples maybe rejected via Google Maps because of bad location coordinates. 
        See rejected count above. <br/>
        Note: rejected count includes $hmpMetagenomeCnt HMP metagenomes that have no location data.
        <br/>
        Map pins represent location counts. Some pins may have multiple samples.
        };
    } elsif($type eq 'genome') {
        print qq{
        <p>
        $tmp projects. <br/>
        Some projects maybe rejected via Google Maps because of bad location coordinates. 
        See rejected count above. <br/>
        Map pins represent location counts. Some pins may have multiple genomes.
        </p>
        };
    } elsif($type eq 'cart') {
        print qq{
        <p>
        Some projects maybe rejected via Google Maps because of bad location coordinates. 
        See rejected count above. <br/>
        Map pins represent location counts. Some pins may have multiple genomes.
        </p>
        };        
    }

    ### prepare data to be mapped
    my $recsToDisplay_aref;
    my $count_display = 0;

    if ( $flag_mapCart eq 1 ) {    # put on map only those genomes in the cart
                                   # turn array into hash for easy lookup
        my %oidsInCart_hash = map { $_ => "1" } @$oidsInCart_ref;

        # create a new array (rectsToDisplay) for only those
        # genomes to be displayed on google map
        my @recsToDisplay = ();
        $recsToDisplay_aref = \@recsToDisplay;
        foreach my $line (@$recs_aref) {
            my ( $taxon_oid, $name, $geo_location, $latitude, $longitude, $altitude ) = split( /\t/, $line );

            if ( exists $oidsInCart_hash{$taxon_oid} ) {
                push( @recsToDisplay, $line );
            }
        }
    } else {    # put all genomes on the map
        $recsToDisplay_aref = $recs_aref;
    }

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    # $gmapkey - for v2 api not v3
    # <script type="text/javascript"
    #      src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&sensor=SET_TO_TRUE_OR_FALSE">
    #    </script>

    # <script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
    #<script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?key=$gmapkey&sensor=false"></script>

    print <<EOF;
<link href="https://code.google.com/apis/maps/documentation/javascript/examples/default.css" rel="stylesheet" type="text/css" />
<script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
<script type="text/javascript" src="$base_url/googlemap.js"></script>
<script type="text/javascript" src="$base_url/markerclusterer.js"></script>

    <div id="map_canvas" style="width: 1000px; height: 700px; position: relative;"></div>            
            
    <script type="text/javascript">
        var map = createMap(2, 0, 0);    
EOF

    my $last_lat  = "";
    my $last_lon  = "";
    my $last_name = "";
    my $info      = "";

    my $count_mappedSuccessfully = 0;
    my $count_rejected           = 0;

    foreach my $line (@$recsToDisplay_aref) {
        my ( $taxon_oid, $name, $geo_location, $latitude, $longitude, $altitude ) =
          split( /\t/, $line );
        $name = escapeHTML($name);
        my $tmp_geo_location = escHtml($geo_location);
        my $tmp_altitude     = escHtml($altitude);

        #webLog( "taxon oid = $taxon_oid  === $name\n");

        # add geo location check too ? maybe not
        if ( ( $last_lat ne $latitude ) || ( $last_lon ne $longitude ) ) {
            if ( $info ne "" ) {

                # clean lat and long remove " ' , etc
                my $clat  = convertLatLong($last_lat);
                my $clong = convertLatLong($last_lon);
                print qq{
                    var contentString = "$info </div>";
                    addMarker(map, $clat, $clong, '$last_name', contentString);
                };
                $count_mappedSuccessfully++;
            }

            # new point
            $info = "";

            # clean lat and long remove " ' , etc
            my $clat  = convertLatLong($latitude);
            my $clong = convertLatLong($longitude);

            # some data is a space not a null
            if ( $clat eq "" || $clong eq "" ) {

                next;
            }

            $info = "<h1>$tmp_geo_location</h1> <div><p>$latitude, $longitude<br/>$tmp_altitude";
            $info .= "<br/><a href='$url$taxon_oid'>$name</a>";

        } else {
            $info .= "<br/><a href='$url$taxon_oid'>$name</a>";
        }
        $last_lat = $latitude;
        $last_lon = $longitude;

        # $last_name = CGI::escape($name);
        $last_name = $name;
    }

    # last recrod
    if ( $#$recsToDisplay_aref > -1 && $info ne "" ) {
        my $clat  = convertLatLong($last_lat);
        my $clong = convertLatLong($last_lon);
        if ( $clat eq "" || $clong eq "" ) {

        } else {
            print qq{
                var contentString = "$info";
                addMarker(map, $clat, $clong, '$last_name', contentString);
            };
            $count_mappedSuccessfully++;
        }
    }

    # finish map
    print qq{ 
        cluster(map); 
        </script>  
    };

    if ( $flag_mapCart ne 1 ) {
        $count_rejected = $count_rejected_getEnvSample;
    } else {
        $count_rejected = $count_cart - $count_mappedSuccessfully;
    }

    # no points to point
    if ( $#$recsToDisplay_aref < 0 ) {
        printStatusLine( "0 Locations", 2 );
    } else {
        printStatusLine( "$count_mappedSuccessfully Locations, $count_rejected rejected", 2 );
    }

}

# gets all gold data
# returns 2 hashes one keyed on nbci and the another on taxon oid
#
sub getImgGoldLatLon_old {

    my $sql = qq{
    select p.ncbi_project_id,  p.img_oid,
    p.latitude, p.longitude, p.altitude, p.geo_location
    from project_info p
    where p.latitude is not null
    and p.longitude is not null
    and p.img_oid is not null   
    };

    # ncbi prj id => tab delimited
    my %ncbiLocation;

    # img oid => tab delimited
    my %imgLoction;

    my $dbhgold = WebUtil::dbGoldLogin();
    my $cur = execSql( $dbhgold, $sql, $verbose );
    for ( ; ; ) {
        my ( $ncbi, $oid, $lat, $lon, $alt, $geo ) = $cur->fetchrow();

        # lat can be 0 not ""
        last if $lat eq "";
        next if ( $ncbi eq "" && $oid eq "" );

        if ( $ncbi ne "" ) {
            $ncbiLocation{$ncbi} = "$ncbi\t$oid\t$lat\t$lon\t$alt\t$geo";
        }

        if ( $oid ne "" ) {
            $imgLoction{$oid} = "$ncbi\t$oid\t$lat\t$lon\t$alt\t$geo";
        }
    }
    $cur->finish();

    #$dbhgold->disconnect();
    return ( \%ncbiLocation, \%imgLoction );
}

# for genomes with not lat in long in current db try looking into
# gold db for data
# gold data in the 1st 2 hashes below:
#
# $ncbiLocation{$ncbi} = "$ncbi\t$oid\t$lat\t$lon\t$alt\t$geo";
# $imgLoction{$oid} = "$ncbi\t$oid\t$lat\t$lon\t$alt\t$geo";
# $recs_aref $taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude
sub getEnvSampleViaGold_old {
    my ( $dbh, $ncbiLocation_href, $imgLoction_href, $recs_aref ) = @_;

    # list of taxons I already have data for
    # taxon id => ""
    my %taxonIgnore;
    foreach my $line (@$recs_aref) {
        my ( $taxon_oid, $name, $geo_location, $latitude, $longitude, $altitude ) = split( /\t/, $line );
        $taxonIgnore{$taxon_oid} = "";
    }

    my @binds        = ('Yes');
    my $domainClause = "";
    if ($include_metagenomes) {
        $domainClause = "and t.domain = ? ";
        push( @binds, "*Microbiome" );
    }

    my @a;
    foreach my $id ( keys %$imgLoction_href ) {
        push( @a, $id );
    }

    my $str;
    if ( OracleUtil::useTempTable( scalar(@a) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@a );
        $str = " select id from gtt_num_id ";
    } else {
        $str = join( ",", @a );
    }

    # taxon oid search 1st
    # taxon id => taxon name
    my %taxonsMap;
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
	    select t.taxon_oid, t.taxon_display_name
	    from taxon t
	    where t.is_public = ? 
	    $domainClause
	    $rclause
	    $imgClause
	    and t.taxon_oid in ( $str )
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;
        next if ( exists $taxonIgnore{$oid} );
        $taxonsMap{$oid} = "$name";
    }
    $cur->finish();

    my @a;
    foreach my $id ( keys %$ncbiLocation_href ) {
        push( @a, $id );
    }
    my $str;
    if ( OracleUtil::useTempTable( scalar(@a) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@a );
        $str = " select id from gtt_num_id ";
    } else {
        $str = join( ",", @a );
    }

    # taxon oid search 2nd
    # ncbi id => taxon id \t taxon name
    my %ncbiMap;
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
	    select t.taxon_oid, t.taxon_display_name, t.gbk_project_id
	    from taxon t
	    where t.is_public = ? 
	    $rclause
	    $imgClause
	    $domainClause
	    and t.gbk_project_id in ($str)
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $oid, $name, $pid ) = $cur->fetchrow();
        last if !$oid;
        next if ( exists $taxonsMap{$oid} );
        next if ( exists $taxonIgnore{$oid} );
        $ncbiMap{$pid} = "$oid\t$name" if ( $pid ne '' );
    }
    $cur->finish();

    # now add to data into recs to be ploted
    foreach my $id ( keys %taxonsMap ) {
        my $name = $taxonsMap{$id};
        my $line = $imgLoction_href->{$id};
        my ( $ncbi, $oid, $lat, $lon, $alt, $geo ) = split( /\t/, $line );
        push( @$recs_aref, "$oid\t$name\t$geo\t$lat\t$lon\t$alt" );
    }

    foreach my $id ( keys %ncbiMap ) {
        my ( $toid, $name ) = split( /\t/, $ncbiMap{$id} );
        my $line = $ncbiLocation_href->{$id};
        my ( $ncbi, $oid, $lat, $lon, $alt, $geo ) = split( /\t/, $line );
        push( @$recs_aref, "$oid\t$name\t$geo\t$lat\t$lon\t$alt" );
    }

    # order by e.latitude, e.longitude, t.taxon_display_name
}

sub printGoMolecular {
    print "<h1> GO-Molecular Functions List </h1>";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my @recs;
    my $sql = qq{
    select go_id, go_term, definition
    from go_term
    where go_type = 'molecular_function'        
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $term, $defn ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$term\t$defn" );
    }
    $cur->finish();

    #$dbh->disconnect();

    printMainForm();

    # 0 sort col
    my $it = new InnerTable( 1, "gomod$$", "gomod", 0 );
    my $sd = $it->getSdDelim();                            # sort delimiter

    $it->addColSpec( "GO ID",      "char asc", "left" );
    $it->addColSpec( "GO Term",    "char asc", "left" );
    $it->addColSpec( "Definition", "char asc", "left" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $term, $defn ) = split( /\t/, $line );

        my $r;

        $r .= $id . $sd . $id . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printGoCellular {
    print "<h1> GO-Cellular Component List </h1>";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my @recs;
    my $sql = qq{
    select go_id, go_term, definition
    from go_term
    where go_type = 'cellular_component'     
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $term, $defn ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$term\t$defn" );
    }
    $cur->finish();

    #$dbh->disconnect();

    printMainForm();

    # 0 sort col
    my $it = new InnerTable( 1, "gocell$$", "gocell", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "GO ID",      "char asc", "left" );
    $it->addColSpec( "GO Term",    "char asc", "left" );
    $it->addColSpec( "Definition", "char asc", "left" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $term, $defn ) = split( /\t/, $line );

        my $r;
        $r .= $id . $sd . $id . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

# seed term list
sub printSeed {
    print "<h1> SEED Term List </h1>";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my @recs;
    my $sql = qq{
    select distinct product_name 
    from gene_seed_names
    };

    # where subsystem_flag = 1
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($term) = $cur->fetchrow();
        last if !$term;
        push( @recs, "$term" );
    }
    $cur->finish();

    #$dbh->disconnect();

    # 0 sort col
    require InnerTable_yui;    #force Yahoo! tables
    my $it = new InnerTable( 1, "seed$$", "seed", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "SEED Term", "char asc", "left" );

    my $row_cnt = 0;

    foreach my $term (@recs) {
        my $r;
        $r .= $term . $sd . $term . "\t";
        $it->addRow($r);
        $row_cnt++;

        # some where between 6453 to 6454 its crashes
        # its display but lots of erros
        # last if($row_cnt > 6453);
    }

    $it->printOuterTable(1);

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

# print seed list with genome and gene counts
sub printSeedList {
    print qq{
      <h1> SEED List </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    print "Getting SEED gene counts <br/>\n";
    my $dbh = dbLogin();
    my %cognames;
    my $sql = qq{
        select distinct product_name 
        from gene_seed_names
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        $cognames{$id} = $id;
    }
    $cur->finish();

    my @recs;
    my $sql = qq{
    select product_name, count(distinct gene_oid) 
    from gene_seed_names
    group by product_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$cnt" );
    }
    $cur->finish();

    # cog => taxon counts
    my %taxon_counts;
    print "Getting SEED genome counts <br/>\n";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    select gp.product_name,  count(distinct g.taxon)
    from gene_seed_names gp, gene g
    where gp.gene_oid = g.gene_oid
    $rclause
    $imgClause
    group by gp.product_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();

    # 0 sort col
    require InnerTable_yui;    #force Yahoo! tables
    my $it = new InnerTable( 1, "seed$$", "seed", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "SEED Name",    "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    $it->addColSpec( "Genome Count", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $cnt ) = split( /\t/, $line );

        my $r;

        my $name = $cognames{$id};
        $r .= $name . $sd . $name . "\t";

        my $url = "$section_cgi&page=seedgenelist&product_name=$id";
        $url = alink( $url, $cnt );
        $r .= $cnt . $sd . $url . "\t";

        my $url = "$section_cgi&page=seedtaxonlist&product_name=$id";
        $url = alink( $url, $taxon_counts{$id} );
        $r .= $taxon_counts{$id} . $sd . $url . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );

}

# seed gene list
sub printSeedGeneList {
    my $product_name = param("product_name");

    my $sql = qq{
        select distinct gene_oid
        from gene_seed_names
        where product_name = ?
    };

    print qq{
        <h1>
        $product_name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "", $product_name );
}

# seed taxon list
sub printSeedTaxonList {
    my $product_name = param("product_name");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    #    my $sql = qq{
    #    select ec_number, enzyme_name
    #    from enzyme
    #    where ec_number = ?
    #    };
    #    my $cur = execSql( $dbh, $sql, $verbose, $enzyme_id );
    #    my ( $id, $name ) = $cur->fetchrow();
    #    $cur->finish();

    print qq{
        <h1>
        $product_name <br/>
        Genome List
        </h1> 
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
    select t.taxon_oid, t.taxon_display_name, count(distinct g.gene_oid)
    from taxon t, gene g, gene_seed_names gc
    where gc.product_name = ?
    $rclause
    $imgClause
    and t.taxon_oid = g.taxon
    and g.gene_oid = gc.gene_oid
    group by t.taxon_oid, t.taxon_display_name
    };

    my $it = new InnerTable( 1, "product_nametaxon$$", "product_nametaxon", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $product_name );
    my $row_cnt = 0;
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        my $r;

        my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        my $url = "$section_cgi&page=seedtaxongenelist&product_name=$product_name&taxon_oid=$id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
        $row_cnt++;
    }
    $it->printOuterTable(1);
    $cur->finish();

    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

# seed taxon gene list
sub printSeedTaxonGeneList {
    my $product_name = param("product_name");
    my $taxon_oid    = param("taxon_oid");

    my $dbh        = dbLogin();
    my $genomename = genomeName( $dbh, $taxon_oid );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g, gene_seed_names gc
        where gc.product_name = ?
        $rclause
        $imgClause
        and g.taxon = ?
        and g.gene_oid = gc.gene_oid     
    };

    print qq{
        <h1>
        $genomename <br/>
        $product_name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "", $product_name, $taxon_oid );
}

sub printKoMod {
    print "<h1> KO Module List </h1>";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my @recs;
    my $sql = qq{
    select module_id, module_name
    from kegg_module 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $term ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$term" );
    }
    $cur->finish();

    #$dbh->disconnect();

    # 0 sort col
    my $it = new InnerTable( 1, "komod$$", "komod", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "KO Module ID",   "char asc", "left" );
    $it->addColSpec( "KO Module Name", "char asc", "left" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $term ) = split( /\t/, $line );
        my $r;
        $r .= $id . $sd . $id . "\t";
        $r .= $term . $sd . $term . "\t";
        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printCogList {
    print qq{
      <h1> COG List </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    print "Getting COG gene counts <br/>\n";
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %cognames;
    my $sql = qq{
        select cog_id, cog_name
        from cog
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cognames{$id} = $name;
    }
    $cur->finish();

    my @recs;
    my $sql = qq{
        select g.cog, count(g.gene_oid)
        from gene_cog_groups g
        $rclause
        $imgClause
        group by g.cog
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$cnt" );
    }
    $cur->finish();

    # cog => taxon counts
    my %taxon_counts;
    print "Getting COG genome counts <br/>\n";
    my $sql = qq{
        select g.cog, count(g.taxon)
        from gene_cog_groups g
        $rclause
        $imgClause
        group by g.cog
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "cog$$", "cog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "COG ID",       "char asc",    "left" );
    $it->addColSpec( "COG Name",     "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    $it->addColSpec( "Genome Count", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $cnt ) = split( /\t/, $line );

        my $r;

        $r .= $sd . "<input type='checkbox' name='cog_id' " . "value='$id' />" . "\t";
        $r .= $id . $sd . $id . "\t";

        my $name = $cognames{$id};
        $r .= $name . $sd . $name . "\t";

        my $url = "$section_cgi&page=coggenelist&cog_id=$id";
        $url = alink( $url, $cnt );
        $r .= $cnt . $sd . $url . "\t";

        my $url = "$section_cgi&page=cogtaxonlist&cog_id=$id";
        $url = alink( $url, $taxon_counts{$id} );
        $r .= $taxon_counts{$id} . $sd . $url . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printCogGeneList {
    my $cog_id = param("cog_id");

    my $dbh = dbLogin();

    my $sql = qq{
        select cog_id, cog_name
        from cog
        where cog_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $sql = qq{
        select gene_oid
        from gene_cog_groups
        where cog = ? 
    };

    my $title = qq{
        <h1>
        $id <br/> $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $cog_id );
}

sub printCogTaxonList {
    my $cog_id = param("cog_id");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
    select cog_id, cog_name
    from cog
    where cog_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    print qq{
        <h1>
        $id $name <br/>
        Genome List
        </h1> 
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
    select t.taxon_oid, t.taxon_display_name, count(distinct g.gene_oid)
    from taxon t, gene g, gene_cog_groups gc
    where gc.cog = ?
    $rclause
    $imgClause
    and t.taxon_oid = g.taxon
    and g.gene_oid = gc.gene_oid
    group by t.taxon_oid, t.taxon_display_name
    };

    my $it = new InnerTable( 1, "cogtaxon$$", "cogtaxon", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my $row_cnt = 0;
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        my $r;

        my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        my $url = "$section_cgi&page=cogtaxongenelist&cog_id=$cog_id&taxon_oid=$id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
        $row_cnt++;
    }
    $it->printOuterTable(1);
    $cur->finish();

    #$dbh->disconnect();
    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printCogTaxonGeneList {
    my $cog_id    = param("cog_id");
    my $taxon_oid = param("taxon_oid");

    my $dbh        = dbLogin();
    my $genomename = genomeName( $dbh, $taxon_oid );

    #my %cognames;
    my $sql = qq{
    select cog_id, cog_name
    from cog
    where cog_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g, gene_cog_groups gc
        where g.taxon = ? 
        $rclause
        $imgClause
        and gc.cog = ? 
        and g.gene_oid = gc.gene_oid
    };

    my $title = qq{
        <h1>
        $genomename <br/>
        $id <br/> $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $taxon_oid, $cog_id );
}

sub printGeneWithAllFunc {
    my ($dbh) = @_;

    print "<h1>Genes with All Functions</h1>"
      . "<p> (protein product, COG, Pfam, TIGRfam, Enzyme, KO term, KEGG, MetaCyc, SEED, IMG term, SwissProt)" . "</p>";

    my $rclause   = WebUtil::urClause('g1.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g1.taxon');
    my $sql       = qq{
      select g1.gene_oid from gene g1
      where g1.gene_display_name is not null
        $rclause
        $imgClause
        and g1.obsolete_flag = 'No'
        and exists (select 1 from gene_cog_groups where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_pfam_families where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_tigrfams where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_ko_enzymes where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_ko_terms where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_seed_names where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_img_functions where gene_oid = g1.gene_oid)
        and EXISTS (select 1 from gene_swissprot_names where gene_oid = g1.gene_oid)
        and EXISTS (select 1 
                    from gene_ko_terms gk, kegg_module_ko_terms km, 
                      kegg_pathway_modules kp, kegg_pathway k
                    where gk.gene_oid = g1.gene_oid 
                      and gk.ko_terms = km.ko_terms 
                      and km.module_id = kp.modules 
                      and kp.pathway_oid = k.pathway_oid
                   )
        and EXISTS (select 1 from gene_biocyc_rxns where gene_oid = g1.gene_oid) 
    };
    printGeneListAllFunc( $dbh, $sql );
}

#
# prints gene list with all functions
#

sub printGeneListAllFunc {
    my ( $dbh, $sql ) = @_;
    my $max_gene_batch     = 900;
    my $maxGeneListResults = 1000;

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    printGeneCartFooter();
    print "<p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my @gene_oids;
    my $count = 0;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome ID",           "number asc", "right" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );

    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    $cur->finish();
    $it->printOuterTable(1);

    my $s = "";
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
    } else {
        $s = "$count gene(s) retrieved.";
    }
    printStatusLine( $s, 2 );
    print "</p>\n";
    printGeneCartFooter();
    print end_form();

    return ( $count, $s );
}

# ===============================================================
#
#               pfam
#
# ===============================================================

sub printPfamList {
    print qq{
      <h1> Pfam List </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    print "Getting Pfam gene counts <br/>\n";
    my $dbh = dbLogin();
    my %cognames;
    my $sql = qq{
    select ext_accession, name
    from pfam_family
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cognames{$id} = $name;
    }
    $cur->finish();

    my @recs;
    my $sql = qq{
    select pfam_family, count(gene_oid)
    from gene_pfam_families
    group by pfam_family
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$cnt" );
    }
    $cur->finish();

    # cog => taxon counts
    my %taxon_counts;
    print "Getting Pfam genome counts <br/>\n";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    select pfam_family,  count(distinct taxon)
    from gene_pfam_families gp, gene g
    where gp.gene_oid = g.gene_oid
    $rclause
    $imgClause
    group by pfam_family       
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "cog$$", "cog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Pfam ID",      "char asc",    "left" );
    $it->addColSpec( "Pfam Name",    "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    $it->addColSpec( "Genome Count", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $cnt ) = split( /\t/, $line );

        my $r;

        $r .= $sd . "<input type='checkbox' name='pfam_id' " . "value='$id' />" . "\t";
        $r .= $id . $sd . $id . "\t";

        my $name = $cognames{$id};
        $r .= $name . $sd . $name . "\t";

        my $url = "$section_cgi&page=pfamgenelist&pfam_id=$id";
        $url = alink( $url, $cnt );
        $r .= $cnt . $sd . $url . "\t";

        my $url = "$section_cgi&page=pfamtaxonlist&pfam_id=$id";
        $url = alink( $url, $taxon_counts{$id} );
        $r .= $taxon_counts{$id} . $sd . $url . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printPfamGeneList {
    my $pfam_id = param("pfam_id");

    my $dbh = dbLogin();

    my $sql = qq{
    select ext_accession, name
    from pfam_family
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $sql = qq{
        select gene_oid
        from gene_pfam_families
        where pfam_family = ? 
    };

    my $title = qq{
        <h1>
        $id  $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $pfam_id );
}

sub printPfamTaxonList {
    my $pfam_id = param("pfam_id");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
    select ext_accession, name
    from pfam_family
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    print qq{
        <h1>
        $id $name <br/>
        Genome List
        </h1> 
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
    select t.taxon_oid, t.taxon_display_name, count(distinct g.gene_oid)
    from taxon t, gene g, gene_pfam_families gc
    where gc.pfam_family = ?
    $rclause
    $imgClause
    and t.taxon_oid = g.taxon
    and g.gene_oid = gc.gene_oid
    group by t.taxon_oid, t.taxon_display_name
    };

    my $it = new InnerTable( 1, "pfamtaxon$$", "pfamtaxon", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
    my $row_cnt = 0;
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        my $r;

        my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        my $url = "$section_cgi&page=pfamtaxongenelist&pfam_id=$pfam_id&taxon_oid=$id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
        $row_cnt++;
    }
    $it->printOuterTable(1);
    $cur->finish();

    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printPfamTaxonGeneList {
    my $pfam_id   = param("pfam_id");
    my $taxon_oid = param("taxon_oid");

    my $dbh        = dbLogin();
    my $genomename = genomeName( $dbh, $taxon_oid );

    #my %cognames;
    my $sql = qq{
    select ext_accession, name
    from pfam_family
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g, gene_pfam_families gc
        where gc.pfam_family = ?
        $rclause
        $imgClause
        and g.taxon = ?
        and g.gene_oid = gc.gene_oid        
    };

    my $title = qq{
        <h1>
        $genomename <br/>
        $id <br/> $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $pfam_id, $taxon_oid );
}

# ===============================================================
#
#               tigrfam
#
# ===============================================================

sub printTigrfamList {
    print qq{
      <h1> TIGRfam List </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    print "Getting Tigrfam gene counts <br/>\n";
    my $dbh = dbLogin();
    my %cognames;
    my $sql = qq{
    select ext_accession, expanded_name
    from tigrfam
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cognames{$id} = $name;
    }
    $cur->finish();

    my @recs;
    my $sql = qq{
    select ext_accession, count(gene_oid)
    from gene_tigrfams
    group by ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$cnt" );
    }
    $cur->finish();

    # cog => taxon counts
    my %taxon_counts;
    print "Getting Tigrfam genome counts <br/>\n";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    select ext_accession,  count(distinct taxon)
    from gene_tigrfams gp, gene g
    where gp.gene_oid = g.gene_oid
    $rclause
    $imgClause
    group by ext_accession       
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "tigr$$", "tigr", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "TIGRfam ID",   "char asc",    "left" );
    $it->addColSpec( "TIGRfam Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    $it->addColSpec( "Genome Count", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $cnt ) = split( /\t/, $line );

        my $r;

        $r .= $sd . "<input type='checkbox' name='tigrfam_id' " . "value='$id' />" . "\t";
        $r .= $id . $sd . $id . "\t";

        my $name = $cognames{$id};
        $r .= $name . $sd . $name . "\t";

        my $url = "$section_cgi&page=tigrfamgenelist&tigrfam_id=$id";
        $url = alink( $url, $cnt );
        $r .= $cnt . $sd . $url . "\t";

        my $url = "$section_cgi&page=tigrfamtaxonlist&tigrfam_id=$id";
        $url = alink( $url, $taxon_counts{$id} );
        $r .= $taxon_counts{$id} . $sd . $url . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printTigrfamGeneList {
    my $tigrfam_id = param("tigrfam_id");

    my $dbh = dbLogin();

    my $sql = qq{
    select ext_accession, expanded_name
    from tigrfam
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $sql = qq{
        select gene_oid
        from gene_tigrfams
        where ext_accession = ? 
    };

    my $title = qq{
        <h1>
        $id  $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $tigrfam_id );
}

sub printTigrfamTaxonList {
    my $tigrfam_id = param("tigrfam_id");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
    select ext_accession, expanded_name
    from tigrfam
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    print qq{
        <h1>
        $id $name <br/>
        Genome List
        </h1> 
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
    select t.taxon_oid, t.taxon_display_name, count(distinct g.gene_oid)
    from taxon t, gene g, gene_tigrfams gc
    where gc.ext_accession = ?
    $rclause
    $imgClause
    and t.taxon_oid = g.taxon
    and g.gene_oid = gc.gene_oid
    group by t.taxon_oid, t.taxon_display_name
    };

    my $it = new InnerTable( 1, "tigrfamtaxon$$", "tigrfamtaxon", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my $row_cnt = 0;
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        my $r;

        my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        my $url = "$section_cgi&page=tigrfamtaxongenelist&tigrfam_id=$tigrfam_id&taxon_oid=$id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
        $row_cnt++;
    }
    $it->printOuterTable(1);
    $cur->finish();

    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printTigrfamTaxonGeneList {
    my $tigrfam_id = param("tigrfam_id");
    my $taxon_oid  = param("taxon_oid");

    my $dbh        = dbLogin();
    my $genomename = genomeName( $dbh, $taxon_oid );

    #my %cognames;
    my $sql = qq{
    select ext_accession, expanded_name
    from tigrfam
    where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g, gene_tigrfams gc
        where gc.ext_accession = ?
        $rclause
        $imgClause
        and g.taxon = ?
        and g.gene_oid = gc.gene_oid        
    };

    my $title = qq{
        <h1>
        $genomename <br/>
        $id <br/> $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $tigrfam_id, $taxon_oid );
}

# ===============================================================
#
#               enzymes
#
# ===============================================================

sub printEnzymeList {
    print qq{
      <h1> Enzyme List </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    print "Getting Enzyme gene counts <br/>\n";
    my $dbh = dbLogin();
    my %cognames;
    my $sql = qq{
    select ec_number, enzyme_name
    from enzyme
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cognames{$id} = $name;
    }
    $cur->finish();

    my @recs;
    my $sql = qq{
    select enzymes, count(gene_oid)
    from gene_ko_enzymes
    group by enzymes
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        push( @recs, "$id\t$cnt" );
    }
    $cur->finish();

    # cog => taxon counts
    my %taxon_counts;
    print "Getting Enzyme genome counts <br/>\n";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    select enzymes,  count(distinct g.taxon)
    from gene_ko_enzymes gp, gene g
    where gp.gene_oid = g.gene_oid
    $rclause
    $imgClause
    group by enzymes       
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $taxon_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "tigr$$", "tigr", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "EC Number",    "char asc",    "left" );
    $it->addColSpec( "EC Name",      "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    $it->addColSpec( "Genome Count", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $line (@recs) {
        my ( $id, $cnt ) = split( /\t/, $line );

        my $r;

        $r .= $sd . "<input type='checkbox' name='ec_number' " . "value='$id' />" . "\t";
        $r .= $id . $sd . $id . "\t";

        my $name = $cognames{$id};
        $r .= $name . $sd . $name . "\t";

        my $url = "$section_cgi&page=enzymegenelist&enzyme_id=$id";
        $url = alink( $url, $cnt );
        $r .= $cnt . $sd . $url . "\t";

        my $url = "$section_cgi&page=enzymetaxonlist&enzyme_id=$id";
        $url = alink( $url, $taxon_counts{$id} );
        $r .= $taxon_counts{$id} . $sd . $url . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printEnzymeGeneList {
    my $enzyme_id = param("enzyme_id");

    my $dbh = dbLogin();

    my $sql = qq{
    select ec_number, enzyme_name
    from enzyme
    where ec_number = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $enzyme_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $sql = qq{
        select gene_oid
        from gene_ko_enzymes
        where enzymes = ?
    };

    my $title = qq{
        <h1>
        $id  $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $enzyme_id );
}

sub printEnzymeTaxonList {
    my $enzyme_id = param("enzyme_id");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
    select ec_number, enzyme_name
    from enzyme
    where ec_number = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $enzyme_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    print qq{
        <h1>
        $id $name <br/>
        Genome List
        </h1> 
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
    select t.taxon_oid, t.taxon_display_name, count(distinct g.gene_oid)
    from taxon t, gene g, gene_ko_enzymes gc
    where gc.enzymes = ?
    $rclause
    $imgClause
    and t.taxon_oid = g.taxon
    and g.gene_oid = gc.gene_oid
    group by t.taxon_oid, t.taxon_display_name
    };

    my $it = new InnerTable( 1, "enzymestaxon$$", "enzymestaxon", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $cur = execSql( $dbh, $sql, $verbose, $enzyme_id );
    my $row_cnt = 0;
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        my $r;

        my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        my $url = "$section_cgi&page=enzymetaxongenelist&enzyme_id=$enzyme_id&taxon_oid=$id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
        $row_cnt++;
    }
    $it->printOuterTable(1);
    $cur->finish();

    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printEnzymeTaxonGeneList {
    my $enzyme_id = param("enzyme_id");
    my $taxon_oid = param("taxon_oid");

    my $dbh        = dbLogin();
    my $genomename = genomeName( $dbh, $taxon_oid );

    #my %cognames;
    my $sql = qq{
    select ec_number, enzyme_name
    from enzyme
    where ec_number = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $enzyme_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g, gene_ko_enzymes gc
        where gc.enzymes = ?
        $rclause
        $imgClause
        and g.taxon = ?
        and g.gene_oid = gc.gene_oid        
    };

    my $title = qq{
        <h1>
        $genomename <br/>
        $id <br/> $name <br/>
        Gene List
        </h1> 
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title, 1, $enzyme_id, $taxon_oid );
}

sub printEssential {
    print "<h1> Essential Gene List </h1>";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select distinct t.taxon_oid, t.taxon_display_name
        from gene g, gene_essential_genes ge, taxon t
        where g.gene_oid = ge.gene_oid
        $rclause
        $imgClause
        and g.taxon = t.taxon_oid  
        and rownum < 2      
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, $taxon_name );
    print "<p>$url</p>";

    print qq{
        <p>
        Essential genes identified using the methods described in: Gerdes, S.Y. et al. (2003), J. Bacteriology 185, 5673-84, 
        <br/><a href='http://www.ncbi.nlm.nih.gov/pubmed/13129938?dopt=AbstractPlus'>
        Experimental Determination and System-Level Analysis of Essential Genes in E. coli MG1655.
        </a>
        </p>
    };

    # value yes, no, unknown, all or blank
    my $essentiality = param("essentiality");

    my $clause;
    if ( $essentiality eq "yes" ) {
        $clause = "and lower(ge.essentiality) = 'yes' ";
    } elsif ( $essentiality eq "no" ) {
        $clause = "and lower(ge.essentiality) = 'no' ";
    } elsif ( $essentiality eq "unknown" ) {
        $clause = "and lower(ge.essentiality) not in ('yes', 'no') ";
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    select g.gene_oid, g.gene_display_name, ge.ext_id, ge.essentiality, 
    g.gene_symbol
    from gene g, gene_essential_genes ge
    where g.gene_oid = ge.gene_oid
    $rclause
    $imgClause
    $clause
    };

    my $row_cnt = 0;

    # 0 sort col
    my $it = new InnerTable( 1, "essential$$", "essential", 1 );
    my $sd = $it->getSdDelim();                                    # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Ext ID",            "char asc",   "left" );
    $it->addColSpec( "Essentiality",      "char asc",   "left" );
    $it->addColSpec( "Gene Symbol",       "char asc",   "left" );

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $ext_id, $essentiality, $gene_symbol ) = $cur->fetchrow();
        last if !$gene_oid;

        my $r;

        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' />" . "\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $url = alink( $url, $gene_oid );
        $r .= $gene_oid . $sd . $url . "\t";
        $r .= $gene_display_name . $sd . $gene_display_name . "\t";
        $r .= $ext_id . $sd . $ext_id . "\t";
        $r .= $essentiality . $sd . $essentiality . "\t";
        $r .= $gene_symbol . $sd . $gene_symbol . "\t";

        $it->addRow($r);

        $row_cnt++;

    }
    $cur->finish();

    #$dbh->disconnect();

    printMainForm();

    print qq{
        <script language='javascript' type='text/javascript'>
            function myFilter() {
               var e =  document.mainForm.filter;
               var ess = e.value;
               var url = "main.cgi?section=ImgStatsOverview&page=essential&essentiality=" + ess;
               if(ess != "na") {
                   window.open( url, '_self' );
               }
            }
        </script>
        
        <p>
        <select name="filter" onChange='myFilter()'>
        <option value="na" selected="selected" > -- Essentiality Filter -- </option>
        <option value="all" > All </option>
        <option value="yes"> Yes </option>
        <option value="no"> No </option>
        <option value="unknown"> Unknown </option>
        </select>
        </p>
    };

    printGeneCartFooter();
    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );

}

sub printTreeStats {
    my $domain = param('domain');
    my $excel  = param('excel');

    my $contact_oid = WebUtil::getContactOid();
    if ( $excel ne 'yes' ) {
        print qq{
        <h1>$domain Phylum Count Statistics</h1>
    
    
    <input class="smdefbutton" type="button" name="Export" 
    value="Export" onclick="_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link ImgStatsOverview treeStats']); window.open('main.cgi?section=ImgStatsOverview&page=treeStats&excel=yes&domain=$domain', '_self')">    
    
    };
    }

    printStatusLine( "Loading...", 1 ) if $excel ne 'yes';

    my $dbh       = dbLogin();
    my $imgClause = WebUtil::imgClause('t');

    my $domainClause = "where domain = ?";
    if ( $domain eq 'GFragment' ) {
        $domainClause = "where domain like ?";
        $domain       = $domain . '%';
    } elsif ( $domain eq 'Plasmid' ) {
        $domainClause = "where domain like ?";
        $domain       = $domain . '%';
    } elsif ( $domain eq 'Viruses' ) {
        $domainClause = "where domain like ?";
        $domain       = 'Vir%';
    }

    my $sql = qq{
select t.domain, 
nvl(t.phylum, 'unknown'), 
nvl(t.ir_class, 'unknown'), 
nvl(t.ir_order, 'unknown'), 
nvl(t.family, 'unknown'), 
nvl(t.genus, 'unknown'), 
nvl(t.species, 'unknown')
from taxon t
$domainClause
$imgClause
order by t.domain, t.phylum, t.ir_class, t.ir_order,  t.family, t.genus, t.species
    };

    #
    # key $domain => cnt
    #     $domain\tphylum => cnt
    #     etc ....
    my %counts;
    my $cur = execSql( $dbh, $sql, $verbose, $domain );
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = $cur->fetchrow();
        last if ( !$domain );
        my $key1 = "01 $domain";
        my $key2 = "02 $domain\t$phylum";
        my $key3 = "03 $domain\t$phylum\t$ir_class";
        my $key4 = "04 $domain\t$phylum\t$ir_class\t$ir_order";
        my $key5 = "05 $domain\t$phylum\t$ir_class\t$ir_order\t$family";
        my $key6 = "06 $domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus";
        my $key7 = "07 $domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species";

        my @a = ( $key1, $key2, $key3, $key4, $key5, $key6, $key7 );
        foreach my $key (@a) {
            if ( exists $counts{$key} ) {
                $counts{$key} = $counts{$key} + 1;
            } else {
                $counts{$key} = 1;
            }
        }
    }

    if ( $excel eq 'yes' ) {
        foreach my $key ( sort keys %counts ) {
            my $cnt = $counts{$key};
            print "$key\t$cnt\n";
        }
        WebUtil::webExit();
    } else {

        my ( @a01, @a02, @a03, @a04, @a05, @a06, @a07 );
        foreach my $key ( sort keys %counts ) {
            my $cnt = $counts{$key};
            my @p = split( /\t/, $key );
            my ( $level, $domain ) = split( / /, $p[0] );
            my $name = $domain;
            $name = $p[$#p] if ( $#p != 0 );

            if ( $level eq '01' ) {
                push( @a01, "$key\t$cnt" );
            } elsif ( $level eq '02' ) {
                push( @a02, "$key\t$cnt" );
            } elsif ( $level eq '03' ) {
                push( @a03, "$key\t$cnt" );
            } elsif ( $level eq '04' ) {
                push( @a04, "$key\t$cnt" );
            } elsif ( $level eq '05' ) {
                push( @a05, "$key\t$cnt" );
            } elsif ( $level eq '06' ) {
                push( @a06, "$key\t$cnt" );
            } elsif ( $level eq '07' ) {
                push( @a07, "$key\t$cnt" );
            }
        }

        my $sit = new InnerTable( 0, "treestats$$", "treestats", 0 );
        my $sd = $sit->getSdDelim();
        $sit->hideColumnSelector();
        $sit->hideFilterLine();
        $sit->hidePagination();
        $sit->addColSpec( "Domain",  'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Phylum",  'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Class",   'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Order",   'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Family",  'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Genus",   'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );
        $sit->addColSpec( "Species", 'asc', 'left' );
        $sit->addColSpec( "Count",   'asc', 'right' );

        for ( my $i = 0 ; $i <= $#a07 ; $i++ ) {
            my $col1_name = "";
            my $col1_cnt  = "";
            my $col2_name = "";
            my $col2_cnt  = "";
            my $col3_name = "";
            my $col3_cnt  = "";
            my $col4_name = "";
            my $col4_cnt  = "";
            my $col5_name = "";
            my $col5_cnt  = "";
            my $col6_name = "";
            my $col6_cnt  = "";
            my $col7_name = "";
            my $col7_cnt  = "";

            if ( $i <= $#a01 ) {
                my @a = split( /\t/, $a01[$i] );
                my ( $level, $domain ) = split( / /, $a[0] );
                $col1_name = $domain . $sd . $domain;
                $col1_cnt  = $a[$#a] . $sd . $a[$#a];
            } else {
                $col1_name = 'zzz' . $sd . '_';
                $col1_cnt  = 'zzz' . $sd . '_';
            }
            if ( $i <= $#a02 ) {
                my @a = split( /\t/, $a02[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a02[$i] );
                $col2_name = $a[1] . $sd . alink( $url, $a[1] );
                $col2_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col2_name = 'zzz' . $sd . '_';
                $col2_cnt  = 'zzz' . $sd . '_';
            }
            if ( $i <= $#a03 ) {
                my @a = split( /\t/, $a03[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a03[$i] );
                $col3_name = $a[2] . $sd . alink( $url, $a[2] );
                $col3_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col3_name = 'zzz' . $sd . '_';
                $col3_cnt  = 'zzz' . $sd . '_';
            }
            if ( $i <= $#a04 ) {
                my @a = split( /\t/, $a04[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a04[$i] );
                $col4_name = $a[3] . $sd . alink( $url, $a[3] );
                $col4_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col4_name = 'zzz' . $sd . '_';
                $col4_cnt  = 'zzz' . $sd . '_';                
            }
            if ( $i <= $#a05 ) {
                my @a = split( /\t/, $a05[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a05[$i] );
                $col5_name = $a[4] . $sd . alink( $url, $a[4] );
                $col5_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col5_name = 'zzz' . $sd . '_';
                $col5_cnt  = 'zzz' . $sd . '_';                
            }
            if ( $i <= $#a06 ) {
                my @a = split( /\t/, $a06[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a06[$i] );
                $col6_name = $a[5] . $sd . alink( $url, $a[5] );
                $col6_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col6_name = 'zzz' . $sd . '_';
                $col6_cnt  = 'zzz' . $sd . '_';                
            }
            if ( $i <= $#a07 ) {
                my @a = split( /\t/, $a07[$i] );
                my $url = "main.cgi?section=ImgStatsOverview&page=treeStatsList&key=" . WebUtil::massageToUrl2( $a07[$i] );
                $col7_name = $a[6] . $sd . alink( $url, $a[6] );
                $col7_cnt = $a[$#a] . $sd . $a[$#a]
            } else {
                $col7_name = 'zzz' . $sd . '_';
                $col7_cnt  = 'zzz' . $sd . '_';                
            }

            my $row = "$col1_name\t$col1_cnt\t";
            $row .= "$col2_name\t$col2_cnt\t";
            $row .= "$col3_name\t$col3_cnt\t";
            $row .= "$col4_name\t$col4_cnt\t";
            $row .= "$col5_name\t$col5_cnt\t";
            $row .= "$col6_name\t$col6_cnt\t";
            $row .= "$col7_name\t$col7_cnt";
            $sit->addRow($row);
        }

        $sit->printTable() if ($sit);
    }
    printStatusLine( "Loaded", 2 ) if $excel ne 'yes';
}

sub printTreeStatsList {
    my $key = param('key');
    my @a   = split( /\t/, $key );

    #    foreach my $x (@a) {
    #        print "$x<br/>\n";
    #    }

    my $imgClause = WebUtil::imgClause('t');
    my $domainClause;
    my $phylumClause;
    my $classClause;
    my $orderClause;
    my $familyClause;
    my $genusClause;
    my $speciesClause;

    my @bind;

    # the last $a[] is the count ignore it
    for ( my $i = 0 ; $i < $#a ; $i++ ) {
        if ( $i == 0 ) {
            my $domain = $a[$i];
            $domain =~ s/^0\d //;
            $domainClause = "where t.domain = ?";
            push( @bind, $domain );
        } elsif ( $i == 1 ) {
            $phylumClause = "and t.phylum = ?";
            if($a[$i] eq 'unknown') {
                $phylumClause = "and t.phylum is null";
            } else {
                push( @bind, $a[$i] );
            }
        } elsif ( $i == 2 ) {
            $classClause = "and t.ir_class = ?";
            if($a[$i] eq 'unknown') {
                $classClause = "and t.ir_class is null";
            } else {
                push( @bind, $a[$i] );
            }
        } elsif ( $i == 3 ) {
            $orderClause = "and t.ir_order = ?";
            if($a[$i] eq 'unknown') {
                $orderClause = "and t.ir_order is null";
            } else {
                push( @bind, $a[$i] );
            }
        } elsif ( $i == 4 ) {
            $familyClause = "and t.family = ?";
            if($a[$i] eq 'unknown') {
                $familyClause = "and t.family is null";
            } else {
                push( @bind, $a[$i] );
            }
        } elsif ( $i == 5 ) {
            $genusClause = "and t.genus = ?";
            if($a[$i] eq 'unknown') {
                $genusClause = "and t.genus is null";
            } else {
                push( @bind, $a[$i] );
            }
        } elsif ( $i == 6 ) {
            $speciesClause = "and t.species = ?";
            if($a[$i] eq 'unknown') {
                $speciesClause = "and t.species is null";
            } else {
                push( @bind, $a[$i] );
            }
        }
    }

    my $sql = qq{
select t.taxon_oid
from taxon t
$domainClause
$phylumClause
$classClause
$orderClause
$familyClause
$genusClause
$speciesClause
    };

    my $title = "Genome List";
    my $note  = '<p> ' . join( ', ', @a ) . ' </p>';

    require GenomeList;
    GenomeList::printGenomesViaSql( '', $sql, $title, \@bind, '', $note );
}

1;

