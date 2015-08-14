###########################################################################
# $Id: PhyloUtil.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
###########################################################################
package PhyloUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use HtmlUtil;
use OracleUtil;
use QueryUtil;
use GraphUtil;
use MetaUtil;
use MetagJavaScript;
use ScaffoldCart;
use BarChartImage;
use ChartUtil;

$| = 1;

my $env                 = getEnv();
my $base_url            = $env->{base_url};
my $cgi_dir             = $env->{cgi_dir};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $cgi_url             = $env->{cgi_url};
my $main_cgi            = $env->{main_cgi};
my $inner_cgi           = $env->{inner_cgi};
my $tmp_url             = $env->{tmp_url};
my $verbose             = $env->{verbose};
my $include_metagenomes = $env->{include_metagenomes};
my $in_file             = $env->{in_file};
my $mer_data_dir        = $env->{mer_data_dir};
my $myimg_job           = $env->{myimg_job};
my $YUI                 = $env->{yui_dir_28};
my $yui_tables          = $env->{yui_tables};
my $show_mgdist_v2      = $env->{show_mgdist_v2};
my $img_internal        = $env->{img_internal};
my $scaffold_page_size  = $env->{scaffold_page_size};
my $contact_oid = WebUtil::getContactOid();
# also see MetaJavaSscript for this value too
# method checkSelect()
my $max_scaffold_list = 20;

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my %distMethodText = (
    "gene_count" => "Gene Count",
    "est_copy"   => "Estimated Gene Copies"
);

my $unknown      = "Unknown";
my $zzzUnknown = "zzzUnknown";
my $unclassified = 'unclassified';

my $nvl = getNvl();
my $debug = 0;


sub printTaxonNameAndPhyloDistDate {
    my ( $dbh, $taxon_oid, $phyloDist_date ) = @_;

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    $taxon_name = HtmlUtil::printTaxonName( $taxon_oid, $taxon_name, 1 );
    if ( $phyloDist_date ne "" ) {
        print qq{
            <br/>
            <b>Phylogenetic distribution was computed on <font color='red'>$phyloDist_date</font></b>
        };
    }
    HtmlUtil::printEndTag();
}

sub printPhyloDistMessage_GenesInGenome {
    my ( $rna16s ) = @_;
    
    if ( $rna16s ) {
        print "<p>The Phylogenetic Distribution of 16S rRNA Genes allows to assess "
            . "the phylogenetic composition of a genome sample <br/>based on the "
            . "distribution of best BLAST hits of 16S rRNA genes in "
            . "the dataset. </p>";
    }
    else {
        print "<p>The Phylogenetic Distribution of Genes allows to assess "
            . "the phylogenetic composition of a genome sample <br/>based on the "
            . "distribution of best BLAST hits of protein-coding genes in "
            . "the dataset. </p>";
    }

}


sub printTaxonNameAndPhyloMessage {
    my ( $dbh, $taxon_oid, $data_type ) = @_;

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $taxon_name, $data_type );
    
    print "<p style='width: 950px;'>\n";
    printPhyloDistMessage();
    print "</p>\n";

}

sub printPhyloDistMessage {
    
    if ($include_metagenomes) {
        print qq{
           The Phylogenetic Distribution of Genes allows to assess the 
           phylogenetic composition of a genome sample based on the 
           distribution of best BLAST hits of protein-coding genes in the 
           dataset. The phylogenetic disctribution can be projected onto the 
           families in a phylum (click on phylum name), 
           and then further onto species in a family. 
           For a reference genome within a species, 
           the genome genes can be viewed using the Protein Recruitment 
           Plot or the Reference Genome Context Viewer.
        };
    } else {
        print qq{
            The Phylogenetic Distribution of Genes allows to assess potential 
            horizontally transferred genes of a genome based on the distribution 
            of best BLAST hits of its protein-coding genes. The phylogenetic 
            distribution can be projected onto the families in a phylum 
            (click on phylum name), and then further onto species in a 
            family.
        };
    }

}

sub printPhyloTitle {
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $title;
    if ($domain) {
        $title .= "<u>Domain</u>: $domain";
    }
    if ($phylum) {
        $title .= "<br/>";
        $title .= "<u>Phylum</u>: $phylum";
    }
    if ($ir_class) {
        $title .= "<br/>";
        $title .= "<u>Class</u>: $ir_class";
    }
    if ($ir_order) {
        $title .= "<br/>";
        $title .= "<u>Order</u>: $ir_order";
    }
    if ($family) {
        $title .= "<br/>";
        $title .= "<u>Family</u>: $family";
    }
    if ($genus) {
        $title .= "<br/>";
        $title .= "<u>Genus</u>: $genus";
    }
    if ($species) {
        $title .= "<br/>";
        $title .= "<u>Species</u>: $species";
    }

    print "<p>";
    print $title;
    print "</p>";
}

sub printTaxonomyMetagHitTitle {
    my ( $dbh, $taxon_oid, $data_type, $percent_identity, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus ) = @_;

    my $plusSign = $plus ? "+" : "";    # to show "+" in titles when cumulative
    #my $dataTypeSign = $data_type ? "($data_type)" : "";

    print "<h1>\n";
    if ( $rna16s ) {
        print "16S rRNA Gene ";
    }
    #print "Best Hits at $percent_identity%$plusSign Identity $dataTypeSign\n";
    print "Best Hits at $percent_identity%$plusSign Identity\n";
    print "</h1>\n";
    printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( isInt($taxon_oid) ) {
        my @taxon_array = ( $taxon_oid );
    	if (scalar @taxon_array > 5) {
    	    printCollapsableHeader($dbh, \@taxon_array, $data_type, 0);
    	} else {
    	    printGenomeListSubHeader( $dbh, \@taxon_array, $data_type, 0 );
    	}
    }
}

sub printCollapsableHeader {
    my ( $dbh, $taxons_ref, $data_type, $show_abbr) = @_;
    print qq{
        <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
        </script>

        <script language='JavaScript' type='text/javascript'>
        function showSubHeader(type) {
            if (type == 'noheader') {
                document.getElementById('showheader').style.display = 'none';
                document.getElementById('hideheader').style.display = 'block';
            } else {
                document.getElementById('showheader').style.display = 'block';
                document.getElementById('hideheader').style.display = 'none';
            }
        }
        </script>
    };

    print "<div id='hideheader' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
        . " value='Show Metagenome List'"
        . " onclick='showSubHeader(\"header\")' />";
    print "</div>\n";

    print "<div id='showheader' style='display: none;'>";
    print "<input type='button' class='medbutton' name='view'"
        . " value='Hide Metagenome List'"
        . " onclick='showSubHeader(\"noheader\")' />";

    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref )
        = printGenomeListSubHeader($dbh, $taxons_ref, $data_type, $show_abbr);
    print "</div>\n";
    return ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
            $merfs_taxons_ref, $db_taxons_ref);
}

sub printGenomeListSubHeader {
    my ( $dbh, $taxons_ref, $data_type, $show_abbr) = @_;
    $show_abbr = 0 if $show_abbr eq "";

    my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash($dbh, $taxons_ref);
    my %mer_fs_taxons;
    if ($in_file) {
        %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @$taxons_ref);
    }

    my @phylo_db_taxons;
    my @phylo_fs_taxons;
    my @db_taxons;
    my @merfs_taxons;

    print "<p style='width: 950px;'>\n";
    my $cnt;
    my $total = scalar keys %taxon_name_h;
    foreach my $id ( sort keys %taxon_name_h ) {
        my $name      = $taxon_name_h{$id};
        my $taxon_url;
        my $abbr_name = WebUtil::abbrColName( $id, $name, 1 );
        if ( $mer_fs_taxons{$id} ) {
            $taxon_url = "main.cgi?section=MetaDetail"
                       . "&page=metaDetail&taxon_oid=$id";
            $name      .= " (MER-FS)";
            $abbr_name .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $name .= " ($data_type)";
                $abbr_name .= " ($data_type)";
            }
            push @phylo_fs_taxons, ($id);
            push @merfs_taxons, ($id);
        } else {
            $taxon_url = "main.cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$id";

            my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $id );
            if ( -e $phylo_dir_name ) {
                push @phylo_fs_taxons, ($id);
            }
            else {
                push @phylo_db_taxons, ($id);
            }
            push @db_taxons, ($id);
        }

        $taxon_url = alink( $taxon_url, $name );
        $abbr_name =~ s/<br\/>/ /g;
        #if ( $cnt > 0 ) {
        #    print "<br/>\n";
        #}
	print "<u>Genome</u>: " if $total < 5 && !$show_abbr;
	print "($abbr_name)<br/>" if $show_abbr;
        print "$taxon_url<br/>\n";
        $cnt++;
    }
    print "</p>\n";

    return (\%taxon_name_h, \@phylo_fs_taxons, \@phylo_db_taxons,
            \@merfs_taxons, \@db_taxons);
}

sub printCogViewTitle {
    my ( $dbh, $taxon_oid, $percent_identity, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $plusSign = $plus ? "+" : "";    # to show "+" in titles when cumulative
    
    print "<h1>\n";
    print "Best Hits at $percent_identity%$plusSign Identity\n";
    print "</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( isInt($taxon_oid) ) {
        my @taxon_array = ( $taxon_oid );
	if (scalar @taxon_array > 5) {
	    PhyloUtil::printCollapsableHeader($dbh, \@taxon_array, '', 0);
	} else {
	    printGenomeListSubHeader( $dbh, \@taxon_array, '', 0 );
	}
    }    
}

sub printCogFuncTitle {
    my ( $cogFuncOrPath, $isPath ) = @_;

    print "<p>\n";
    if ($isPath) {
        print "Cog Pathway: ";        
    }
    else {
        print "Cog Functional Category: ";
    }
    if ( $cogFuncOrPath eq $zzzUnknown ) {
        print "Unknown";
    } else {
        print "$cogFuncOrPath";
    }
    print "</p>\n";

}

sub loadBestBlastHits {
    my ( $dbh, $taxon_oid, $xcopy, $show_hits, $plus ) = @_;

    my @pcId = (30, 60, 90);
    my %stats;
    my %totalCount;
    for my $pc (@pcId) {
        $stats{$pc} = {};
        print "Loading $pc% $plus stats ...<br/>\n";
        $totalCount{$pc} = loadMetagenomeStats( $dbh, $taxon_oid, $pc, $stats{$pc}, $plus, $show_hits, $xcopy );
    }

    print "Loading genome hits ...<br/>\n";
    my %genomeHitStats;
    loadGenomeHitStats( $dbh, $taxon_oid, \%genomeHitStats );

    # how to get genome count like before???
    my %orgCount;
    loadPhylumOrgCount( $dbh, \%orgCount );

    return ( \@pcId, \%totalCount, \%stats, \%genomeHitStats, \%orgCount );
}

#
# Load blast meta stats
# database version
# param $dbh databse handler
# param $taxon_oid taxon oid
# param $percent_identity percent
# param $stats_href return data hash of "$domain\t$phylum" to
#               a string tab delimited
#
sub loadMetagenomeStats {
    my ( $dbh, $taxon_oid, $percent_identity, $stats_href, $plus, $show_hits, $xcopy ) = @_;

    my $urclause = WebUtil::urClause("dt.homolog_taxon");
    my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');

    # The following query is used only if genome hits are needed in cumulative option
    my %dp2genomeCnt;
    if ( $plus && $show_hits ) {
        my $sql = qq{
            select dt.domain, dt.phylum, count (distinct dt.homolog_taxon) 
            from dt_phylum_dist_genes dt
            where dt.taxon_oid = ?
            and dt.percent_identity >= ?
            $urclause
            $imgClause
            group by dt.domain, dt.phylum
        };
        #print "loadMetagenomeStats() dp2genomeCnt sql=$sql<br/>\n";
        #print "loadMetagenomeStats() taxon_oid=$taxon_oid, percent=$percent_identity<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $percent_identity );
        for ( ; ; ) {
            my ( $domain, $phylum, $cnt_taxon ) = $cur->fetchrow();
            last if !$domain;
            $dp2genomeCnt{"$domain\t$phylum"} = $cnt_taxon;
        }
        $cur->finish();
    }
    
    my $cur;
    if ( $xcopy eq 'est_copy' ) {
        my $rclause = getPercentClause( $percent_identity, $plus );
        my $sql = qq{
            select dt.domain, dt.phylum, sum(g.est_copy), count(distinct dt.homolog_taxon)
            from dt_phylum_dist_genes dt, gene g
            where dt.taxon_oid = ?
            and dt.domain is not null
            and dt.gene_oid = g.gene_oid
            $rclause
            $urclause
            $imgClause
            group by dt.domain, dt.phylum
        };
        #print "loadMetagenomeStats() sql=$sql<br/>\n";
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    } else {
        my $cumOp = $plus ? ">" : "";
        my $sql = qq{
           select dt.domain, dt.phylum, sum(dt.gene_count), sum(dt.taxon_count)
           from dt_phylum_dist_stats dt
           where dt.taxon_oid = ?
           and dt.domain is not null
           and dt.perc_ident_bin ${cumOp}= ?
           group by dt.domain, dt.phylum
        };
        #print "loadMetagenomeStats() sql=$sql<br/>\n";
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $percent_identity );
    }

    my $totalCount = 0;
    for ( ; ; ) {
        my ( $domain, $phylum, $cnt, $cnt_taxon ) = $cur->fetchrow();
        last if !$domain;
        $totalCount += $cnt;
        my $key = "$domain\t$phylum";
        my $r = "$taxon_oid\t";
        $r .= "$key\t";
        $r .= "$cnt\t";
        if ( $plus && $show_hits ) {
            $cnt_taxon = $dp2genomeCnt{$key};
        }
        $r .= "$cnt_taxon";
        $stats_href->{"$domain\t$phylum"} = $r;
    }
    $cur->finish();
    #print "loadMetagenomeStats() stats_ref:<br/>\n";
    #print Dumper($stats_href);
    #print "<br/>\n";    
    
    return $totalCount;
}

sub loadGenomeHitStats {
    my ( $dbh, $taxon_oid, $stats_href ) = @_;

    my $sql = qq{
       select dt.domain, dt.phylum, dt.taxon_count
       from dt_phylum_dist_stats dt
       where dt.taxon_oid = ?
       and dt.domain is not null
       and dt.perc_ident_bin is null
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $domain, $phylum, $cnt_taxon ) = $cur->fetchrow();
        last if !$domain;
        my $r = "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$phylum\t";
        $r .= "$cnt_taxon";
        $stats_href->{"$domain\t$phylum"} = $r;
    }
    $cur->finish();
}

#
# load phylum org gene count
#
# param $dbh database handler
# param $orgCount_ref return data hash of "$domain\t$phylum" to count
#
sub loadPhylumOrgCount {
    my ( $dbh, $orgCount_ref ) = @_;

    my $rcClause = WebUtil::urClause("tx");
    my $imgClause  = WebUtil::imgClause('tx');

#    my $sql = qq{
#        select domain, phylum, count( distinct tx.taxon_oid )
#        from taxon tx
#        where tx.is_public = 'Yes'
#        and genome_type = 'isolate'
#        $rcClause
#        $imgClause
#        group by domain, phylum
#    };

    my $sql = qq{
        select domain, phylum, count( distinct tx.taxon_oid )
        from taxon tx
        where genome_type = 'isolate'
        $rcClause
        $imgClause
        group by domain, phylum
    };

    # order by domain, phylum, ir_class
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $domain, $phylum, $cnt ) = $cur->fetchrow();
        last if !$domain;
        my $k = "$domain\t$phylum";
        $orgCount_ref->{$k} += $cnt;
    }
    $cur->finish();
}

#Todo: should merge with printFileBestBlastHits()
sub printBestBlastHits {
    my ( $dbh, $section, 
        $taxon_oid, $xcopy, $show_hist, $show_hits, $show_percentage, $noEstCopy, $plus,
        $gene_count_file, $homolog_count_file, $genome_count_file, $filters_ref,  
        $totalGeneCount, $totalCopyCount, $pcId_ref, $stats_href, $genomeHitStats_href, $orgCount_href ) = @_;

    my @filters = @$filters_ref;
    my @pcId = @$pcId_ref;
    my %stats = %$stats_href;
    my %genomeHitStats = %$genomeHitStats_href;
    my %orgCount = %$orgCount_href;

    my $xcopyText = getXcopyText( $xcopy );
    print "<h2>Distribution of Best Blast Hits ($xcopyText)</h2>";

    print "<p>\n";
    print domainLetterNote();
    print "</p>";

    my $str = getPhyloDistHintText( $show_hist, $show_hits, $xcopyText, $totalGeneCount, $noEstCopy );
    printHint($str);
    print "<br/>";

    # create export file
    my $sessionId  = getSessionId();
    my $exportfile = "metagenomeStats$$-" . $sessionId;
    my $exportPath = "$cgi_tmp_dir/$exportfile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # export headers
    print $res "Domain\t";
    print $res "Phylum\t";
    print $res "No. Of Genomes\t";
    print $res "No. Of Hits 30%$plus\t";
    print $res "% Hits 30%$plus\t" if $show_percentage;
    print $res "No. Of Hits 60%$plus\t";
    print $res "% Hits 60%$plus\t" if $show_percentage;
    print $res "No. Of Hits 90%$plus";
    print $res "\t% Hits 90%$plus" if $show_percentage;
    print $res "\n";

    # form parameters
    print hiddenVar( "section",            $section );
    print hiddenVar( "page",               "metagtable" );
    print hiddenVar( "taxon_oid",          $taxon_oid );
    print hiddenVar( "fromviewer",         "MetagPhyloDist" );
    print hiddenVar( "gene_count_file",    $gene_count_file );
    print hiddenVar( "homolog_count_file", $homolog_count_file );
    print hiddenVar( "genome_count_file",  $genome_count_file );
    print hiddenVar( "show_percentage",    $show_percentage );
    print hiddenVar( "show_hist",          $show_hist );
    print hiddenVar( "show_hits",          $show_hits );
    print hiddenVar( "plus",               $plus );
    print hiddenVar( "xcopy",              $xcopy );

    my $total_count = $totalGeneCount;
    if ( $xcopy eq 'est_copy' && $totalCopyCount ) {
        $total_count = $totalCopyCount;
    }
    my $pcToolTip = getPcToolTip( '', $xcopy, $total_count );

    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
        "30%+" => "30% and above",
        "60%+" => "60% and above",
        "90%+" => "90% and above"
    );

    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec("Select");
    $sit->addColSpec("D"); # Domain
    $sit->addColSpec("Phylum");
    $sit->addColSpec("No. Of Genomes", "", "right");
    for my $pc (@pcId) {
        $sit->addColSpec("No. Of Hits ${pc}%$plus", "", "right", "", $toolTip{"${pc}%$plus"});
        $sit->addColSpec("% Hits ${pc}%$plus", "", "right", "", $pcToolTip) if $show_percentage;
        $sit->addColSpec("Histogram ${pc}%$plus") if ($show_hist);
    }

    # add missing keys to 30% list if any
    # the 30 percent is the driver for displaying the table, but
    # with 30-59 % the list may be different since 60 and 90 % ones
    # are not counted in as before when the list was >30%
    #

    foreach my $k ( keys %{$stats{60}} ) {
        if ( !exists( $stats{30}{$k} ) ) {
            webLog("WARNING: 60% $k does not exist in 30% list\n");
            $stats{30}{$k} = "";
        }
    }

    foreach my $k ( keys %{$stats{90}} ) {
        if ( !exists( $stats{30}{$k} ) ) {
            webLog("WARNING: 90% $k does not exist in 30% list\n");
            $stats{30}{$k} = "";
        }
    }

    my $showUnassigned;
    my @domainPhylum;

    for my $class (@filters) {
        my $unEscClass = CGI::unescape($class);
        if ( $unEscClass ne "unassigned\tunassigned" ) {
            push( @domainPhylum, $unEscClass );
        } else {
            $showUnassigned = 1;
        }
    }

    # if no selections show all phyla/classes
    @domainPhylum = sort( keys(%{$stats{30}}) ) if ( @filters < 1 );
    $showUnassigned = 1 if ( @filters < 1 );

    my $count = 0;
    for my $dpc (@domainPhylum) {
        my $orgcnt = $orgCount{$dpc};
        # see loadMetagenomeStats() for key separator
        my ( $domain, $phylum ) = split( /\t/, $dpc );
        
        # total number if distinct genomes hits 30, 60 90
        my $lineHit = $genomeHitStats{$dpc};
        my ( $taxon_oidHit, $domainHit, $phylumHit, $genomCntHit ) = split( /\t/, $lineHit );

        my %taxon_oid;
        my %domain;
        my %phylum;
        my %noHits;
        my %genomCnt;

        # check box
        my $tmp  = CGI::escape("compare_$dpc");
        my $tmp2 = CGI::escape("$dpc");
        my $row = "<input type='checkbox' name='filter' value='$tmp2' checked='checked' />\t";

        # domain
        $row .= substr( $domain, 0, 1 ) . "\t";

        # export
        print $res "$domain\t";

        # phylum column
        my $phylum_est = $phylum;
        if ( $domain =~ /Virus/ ) {
            $phylum_est =~ s/\_no/, no/;
            $phylum_est =~ s/\_/ /g;
        }
        $phylum_est = escHtml($phylum_est);

        my $midUrl ="&taxon_oid=$taxon_oid";
        $midUrl .= "&domain=" . WebUtil::massageToUrl2($domain);
        $midUrl .= "&phylum=" . WebUtil::massageToUrl2($phylum);
        $midUrl .= "&perc=1" if $show_percentage;
        $midUrl .= "&hist=1" if $show_hist;
        $midUrl .= "&plus=1" if $plus;
        $midUrl .= "&xcopy=$xcopy" if $xcopy;

        my $phylumUrl = "$main_cgi?section=$section&page=ir_class" . $midUrl;
        $row .= "<a href='$phylumUrl' >$phylum_est</a>\t";

        # export
        print $res "$phylum_est\t";

        # no of genomes
        $row .= $orgcnt;
        $row .= " ($genomCntHit)" if $show_hits;
        $row .= "\t";
    
        # export
        print $res $orgcnt;
        print $res " ($genomCntHit)" if $show_hits;
        print $res "\t";

        my $i = 0;
        for my $pc (@pcId) { # (30, 60, 90)
            my $r = $stats{$pc}{$dpc};
            ($taxon_oid{$pc}, $domain{$pc}, $phylum{$pc}, $noHits{$pc}, $genomCnt{$pc} ) 
                = split( /\t/, $r );
        
            if ( $noHits{$pc} > 0 ) {
                my $tmpurl  = "$main_cgi?section=$section&page=metagenomeHits";
                $tmpurl .= $midUrl;
                $tmpurl .= "&percent_identity=$pc";
                
                $row .= alink( $tmpurl, $noHits{$pc} );
                $row .= " (${genomCnt{$pc}})" if $show_hits;
                $row .= "\t";
        
                # export
                print $res $noHits{$pc};
                print $res " (${genomCnt{$pc}})" if $show_hits;
                print $res "\t";
            } else {
                $row .= nbsp(1) . "\t";
        
                # export
                print $res " \t";
            }
    
            if ($show_percentage) {
                my $percentHits = 0;
                $percentHits = $noHits{$pc} * 100 / $total_count if $total_count;
                if ( $percentHits > 0 ) {
                    $row .= sprintf "%.2f", $percentHits;
                } else {
                    $row .= nbsp(1);
                }
                $row .= "\t";
        
                # export
                print $res "$percentHits";
                print $res "\t" if ($pc != 90 );
            }
    
            if ($show_hist) {
                my $histCount = 0;
                $histCount = ($noHits{$pc} / $total_count) if $total_count;
                my $maxLen = (@pcId - $i) * 100;
                # $maxLen = 300 for 30%, 200 for 60%, 100 for 90%
                $row .= histogramBar( $histCount, $maxLen );
                $row .= "\t";
            }
            $i++;
        }
        $count++;
        chop $row; # remove the last \t
        $sit->addRow($row);

        # export end of unassigned
        print $res "\n";
    }

    # Unassigned
    if ($showUnassigned) {
        my $dpc = "unassigned\tunassigned";
        my $chkVal = CGI::escape("$dpc");

        # checkbox
        my $row = "<input type='checkbox' name='filter' value='$chkVal' checked='checked' />\t";
        $row .= "-\t";
        $row .= "Unassigned\t";
        $row .= "-\t";

        # export unassigned
        print $res "-\t";
        print $res "Unassigned\t";
        # export unassigned genome hits
        print $res "-\t";

        my %remainCount;
        my $i = 0;
        for my $pc (@pcId) { # (30, 60, 90)
            $remainCount{$pc} = getUnassignedCount( $dbh, $taxon_oid, $pc, $plus );
            my $url           = "$main_cgi?section=$section&page=unassigned" . "&taxon_oid=$taxon_oid&perc=$pc";
            my $link          = alink( $url, $remainCount{$pc} );
    
            $row .= $link . "\t";
    
            # export unassigned 
            print $res "${remainCount{$pc}}\t";
    
            if ($show_percentage) {
                my $percentHits = 0;
                $percentHits = $remainCount{$pc} * 100 / $total_count if $total_count;
                if ( $percentHits > 0 ) {
                    $row .= sprintf "%.2f", $percentHits;
                } else {
                    $row .= nbsp(1);
                }
                $row .= "\t";
        
                # export percent unassigned
                print $res "$percentHits";
                print $res "\t" if ($pc != 90 );
            }
    
            if ($show_hist) {
                my $histCount = 0;
                $histCount = $remainCount{$pc} / $total_count if $total_count;
                my $maxLen = (scalar(@pcId) - $i) * 100;
                # $maxLen = 300 for 30%, 200 for 60%, 100 for 90%
                $row .= histogramBar( $histCount, $maxLen );
                $row .= "\t";
            }
            $i++;
        }
        $count++;
        chop $row; # remove the last \t
        $sit->addRow($row);

        # export end of unassigned
        print $res "\n";
    }
    close $res;
    
    my $allDomainPhylumCount = scalar( keys(%{$stats{30}}) );
    my $filterCount = scalar( @filters );
    printPhyloTableButtons( $allDomainPhylumCount, $filterCount ) if ($count > 10);
    $sit->printTable();
    printPhyloTableButtons( $allDomainPhylumCount, $filterCount );

    # export link
    print qq{
        <p>
        <a href='main.cgi?section=$section&page=download&file=$exportfile&noHeader=1' onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link $section']);\">
        Export tab-delimited file to Excel</a>
        </p>
    };

    if ($myimg_job) {
        ### add computation on demand
        print "<h2>Request Recomputation</h2>\n";
        print "<p>\n";
        print "You can request the phylogenetic distribution of genes "
        . "in this genome to be recomputed.\n";

        my $sql2        = "select is_public from taxon where taxon_oid = ?";
        my $cur2        = execSql( $dbh, $sql2, $verbose, $taxon_oid );
        my ($is_public) = $cur2->fetchrow();
        $cur2->finish();

        if ( $is_public eq 'No' ) {
            print "You can also select one or more private genomes from the list to be included in the computation.\n";
            print "<p>\n";
            print "<select name='private_taxon_oid' size='10' multiple>\n";
            my $rclause = WebUtil::urClause("t");
            my $imgClause = WebUtil::imgClause('t');

            $sql2 = qq{
                select t.taxon_oid, t.domain, t.seq_status,
                       t.taxon_display_name
                from taxon t
                where t.is_public = 'No'
                $rclause
                $imgClause
                order by t.domain, t.taxon_display_name
            };
            $cur2 = execSql( $dbh, $sql2, $verbose );
            my $cnt2 = 0;

            for ( ; ; ) {
                my ( $t2, $domain, $seq_status, $name2 ) = $cur2->fetchrow();
                last if !$t2;

                if ( $t2 == $taxon_oid ) {
                    # self
                    next;
                }

                if ( length($domain) > 0 ) {
                    $domain = substr( $domain, 0, 1 );
                }
                if ( length($seq_status) > 0 ) {
                    $seq_status = substr( $seq_status, 0, 1 );
                }

                print "<option value='$t2'>$name2 [$domain][$seq_status]</option>\n";

                $cnt2++;
                if ( $cnt2 > 1000000 ) {
                    last;
                }
            }
            $cur2->finish();
            print "</select>\n";
        }

        print "<p>User Notes: ";
        print nbsp(1);
        print "<input type='text' name='user_notes' value='' " 
        . "size='60' maxLength='800' />\n";
        print "<br/>";
        my $name = "_section_MyIMG_computePhyloDistOnDemand";
        print submit(
                      -name  => $name,
                      -value => "Request Recomputation",
                      -class => "meddefbutton"
        );
        print "</p>\n";
    }

=removed per Natalia for IMG 3.3
    # compare action buttons
    print <<EOF;
        <p>
        Percent
        <SELECT name="percentage">
        <OPTION value="30">30</OPTION>
        <OPTION value="60">60</OPTION>
        <OPTION value="90">90</OPTION>
        </SELECT>
        &nbsp;&nbsp;
        Difference Factor
        <SELECT name="difference">
        <OPTION value="2">2</OPTION>
        <OPTION value="3">3</OPTION>
        <OPTION value="4">4</OPTION>
        <OPTION value="5">5</OPTION>
        <OPTION value="6">6</OPTION>
        <OPTION value="7">7</OPTION>
        <OPTION value="8">8</OPTION>
        <OPTION value="9">9</OPTION>
        <OPTION value="10">10</OPTION>
        </SELECT>
EOF
    print "<p>\n";
    print "<input type='button' name='compareFunc' "
      . "title='Compare 2 selected Phylum with COG Functions' "
      . "value='Compare COG Functions' class='lgbutton' "
      . "onClick='myCompareCogFunc(\"$main_cgi\", \"$taxon_oid\")' />";
    print "&nbsp;\n";
    print "<input type='button' name='comparePath' "
      . "title='Compare 2 selected Phylum with COG Pathways' "
      . "value='Compare COG Pathways' class='lgbutton' "
      . "onClick='myCompareCogPath(\"$main_cgi\", \"$taxon_oid\")' />";
=cut

}

sub getPcToolTip {
    my ( $name, $xcopy, $total_count ) = @_;
        
    my $xcopyText = getXcopyText( $xcopy );
    my $pcToolTip;
    if ( $name ) {
        $pcToolTip .= "$name - ";
    }
    $pcToolTip .= "Hit Count / Total $xcopyText $total_count";

    return $pcToolTip;
}

sub getPhyloDistHintText {
    my ( $show_hist, $show_hits, $xcopyText, $totalGeneCount, $noEstCopy ) = @_;
        
    my $str = "";
    if ($show_hits) {
        $str .= "Hit genome count is in brackets ( ).<br/>";
    }
    if ($show_hist) {
        $str .= "<u>Histogram</u> is a count of best hits within the phylum ";
        $str .= "/ class <br/>at 30%, 60%, and 90% BLAST identities.<br/>";
    }
    $str .= "<i>Unassigned</i> are the remainder of genes less than ";
    $str .= "the percent identity cutoff, or ";
    $str .= "that are not best hits at the cutoff, or have no hits.";
    $str .= "<br><span style='color:red'>Total gene count ($xcopyText) is unavailable; " .
    "percentages & histograms not computed.</span>" if !$totalGeneCount;
    $str .= "<br><span style='color:red'>${distMethodText{'est_copy'}} unavailable; " .
    "${distMethodText{'gene_count'}} used instead.</span>" if $noEstCopy;

    return $str;
}


#
# Gets unassigned gene count.
# I used minus instead of not in becuz its faster in this case
#
sub getUnassignedCount {
    my ( $dbh, $taxon_oid, $perc ) = @_;

    my $sql = qq{
        select sum(dt.gene_count)
        from dt_phylum_dist_stats dt
        where dt.taxon_oid = ?
        and domain is null
        and perc_ident_bin = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $perc );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;
}

sub getFileTotalGeneCount {
    my ( $taxon_oid, $data_type, $rna16s ) = @_;

    ## only count CDS genes
    my $stats_keyword = "Protein coding genes";
    if ( $rna16s ) {
       $stats_keyword = "16S rRNA";
    }
    my $totalGeneCount = 
       MetaUtil::getGenomeStats( $taxon_oid, $data_type, $stats_keyword );

    if ( !$totalGeneCount ) {
        my $total_assembled   = 0;
        my $total_unassembled = 0;
        if ( $data_type eq 'assembled' || $data_type eq 'both' ) {
            $total_assembled =
                MetaUtil::getGenomeStats( $taxon_oid, 'assembled', $stats_keyword );
        }
        if ( $data_type eq 'unassembled' || $data_type eq 'both' ) {
            $total_unassembled =
                MetaUtil::getGenomeStats( $taxon_oid, 'unassembled', $stats_keyword );
        }
        $totalGeneCount = $total_assembled + $total_unassembled;
    }

    return $totalGeneCount;
}


sub loadFileBestBlastHits {
    my ( $dbh, $taxon_oid, $data_type, $rna16s, $xcopy, $totalGeneCount ) = @_;

    my $phylo_prefix = "";
    if ( $rna16s ) {
       $phylo_prefix = "16s_";
    }
    
    my $totalCopyCount;
    if ( $xcopy eq 'est_copy' ) {
        print "<p>Retrieving est. copy stats ...\n";
        $totalCopyCount = MetaUtil::getPhyloDistEstCopyCount( $phylo_prefix, $taxon_oid, $data_type );        
        #print "loadFileBestBlastHits() taxon_oid=$taxon_oid, $data_type, phylo_prefix=$phylo_prefix, totalCopyCount=$totalCopyCount <br/>\n";
    }
    if ( $totalCopyCount < $totalGeneCount ) {
        $totalCopyCount = $totalGeneCount;
    }

    #print "<p>Checking taxon stats ...\n";
    
    my %h = MetaUtil::getPhyloDistProfileTxt( $phylo_prefix, $taxon_oid, $data_type );

    my %total_h;
    my %found_h;
    my %cnt30;
    my %cnt60;
    my %cnt90;
    my %genome30;
    my %genome60;
    my %genome90;
    my %depth30;
    my %depth60;
    my %depth90;

    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.domain, tx.phylum, tx.taxon_oid
        from taxon tx 
        where tx.genome_type = 'isolate'
        $rclause
        $imgClause
        order by tx.domain, tx.phylum, tx.taxon_oid
    };
    #print "sql: $sql\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $domain, $phylum, $taxon_oid ) = $cur->fetchrow();
        last if !$domain;
        last if !$taxon_oid;

        my $key = "$domain\t$phylum";
        if ( $total_h{$key} ) {
            $total_h{$key} += 1;
        }
        else {
            $total_h{$key} = 1;
        }

        if ( $h{$taxon_oid} ) {
            if ( $found_h{$key} ) {
                $found_h{$key} += 1;
            }
            else {
                $found_h{$key} = 1;
            }

            my @lines = split( /\n/, $h{$taxon_oid} );
            for my $line (@lines) {
                my ( $tid2, $c30, $c60, $c90, $d30, $d60, $d90 ) =
                  split( /\t/, $line );

                if ($c30) {
                    if ( $cnt30{$key} ) {
                        $cnt30{$key} += $c30;
                    }
                    else {
                        $cnt30{$key} = $c30;
                    }

                    ## TODO problematic: cumulative genome counts wrong, 
                    ## because 30% hits and 60% hits could come 
                    ## from the same genome  - yjlin 06172013
                    if ( $genome30{$key} ) {
                        $genome30{$key} += 1;
                    }
                    else {
                        $genome30{$key} = 1;
                    }

                    # est copy
                    if ( !$d30 || $d30 < $c30 ) {
                        $d30 = $c30;
                    }
                    if ( $depth30{$key} ) {
                        $depth30{$key} += $d30;
                    }
                    else {
                        $depth30{$key} = $d30;
                    }
                }

                if ($c60) {
                    if ( $cnt60{$key} ) {
                        $cnt60{$key} += $c60;
                    }
                    else {
                        $cnt60{$key} = $c60;
                    }
                    if ( $genome60{$key} ) {
                        $genome60{$key} += 1;
                    }
                    else {
                        $genome60{$key} = 1;
                    }

                    # est copy
                    if ( !$d60  || $d60 < $c60 ) {
                        $d60 = $c60;
                    }
                    if ( $depth60{$key} ) {
                        $depth60{$key} += $d60;
                    }
                    else {
                        $depth60{$key} = $d60;
                    }
                }

                if ($c90) {
                    if ( $cnt90{$key} ) {
                        $cnt90{$key} += $c90;
                    }
                    else {
                        $cnt90{$key} = $c90;
                    }
                    if ( $genome90{$key} ) {
                        $genome90{$key} += 1;
                    }
                    else {
                        $genome90{$key} = 1;
                    }

                    # est copy
                    if ( !$d90  || $d90 < $c90 ) {
                        $d90 = $c90;
                    }
                    if ( $depth90{$key} ) {
                        $depth90{$key} += $d90;
                    }
                    else {
                        $depth90{$key} = $d90;
                    }
                }
            }
        }
    }
    $cur->finish();

    return ( $totalCopyCount, \%found_h, \%total_h,
        \%cnt30, \%cnt60, \%cnt90, \%genome30, \%genome60, \%genome90,
        \%depth30, \%depth60, \%depth90 );
    
}

#Todo: should merge with printBestBlastHits()
sub printFileBestBlastHits {
    my ( $section, 
        $taxon_oid, $data_type, $rna16s, $xcopy, $show_hist, $show_hits, $show_percentage, 
        $gene_count_file, $homolog_count_file, $genome_count_file, $filters_ref,
        $plus, $totalGeneCount, $totalCopyCount, $found_href, $total_href,
        $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
        $depth30_href, $depth60_href, $depth90_href, $isIsolate ) = @_;
    
    my @filters = @$filters_ref;
    my %found_h = %$found_href;
    my %total_h = %$total_href;
    my %cnt30 = %$cnt30_href;
    my %cnt60 = %$cnt60_href;
    my %cnt90 = %$cnt90_href;
    my %genome30 = %$genome30_href;
    my %genome60 = %$genome60_href;
    my %genome90 = %$genome90_href;
    my %depth30 = %$depth30_href;
    my %depth60 = %$depth60_href;
    my %depth90 = %$depth90_href;

    my $remain30 = 0;
    my $remain60 = 0;
    my $remain90 = 0;

    my $totalCount30 = 0;
    my $totalCount60 = 0;
    my $totalCount90 = 0;

    #print "printFileBestBlastHits()<br/>\n";

    my $xcopyText = getXcopyText( $xcopy );
    print "<h2>Distribution of Best Blast Hits ($xcopyText)</h2>";

    print "<p>\n";
    print domainLetterNote();
    print "</p>\n";

    my $str = getPhyloDistHintText( $show_hist, $show_hits, $xcopyText, $totalGeneCount );
    printHint($str);
    print "<br/>";

    # create export file
    my $sessionId  = getSessionId();
    my $exportfile = "metagenomeStats$$-" . $sessionId;
    my $exportPath = "$cgi_tmp_dir/$exportfile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # export headers
    print $res "Domain\t";
    print $res "Phylum\t";
    print $res "No. Of Genomes\t";
    print $res "No. Of Hits 30%$plus\t";
    print $res "% Hits 30%$plus\t" if $show_percentage;
    print $res "No. Of Hits 60%$plus\t";
    print $res "% Hits 60%$plus\t" if $show_percentage;
    print $res "No. Of Hits 90%$plus";
    print $res "\t% Hits 90%$plus" if $show_percentage;
    print $res "\n";

    # form parameters
    my $percentage = ( $plus eq "+" || $plus eq "1") ? "cum" : "suc";
    print hiddenVar( "section",            $section );
    print hiddenVar( "page",               "metagtable" );
    print hiddenVar( "taxon_oid",          $taxon_oid );
    print hiddenVar( "data_type",          $data_type );
    print hiddenVar( "fromviewer",         "MetagPhyloDist" );
    print hiddenVar( "percentage",         $percentage );
    print hiddenVar( "xcopy",              $xcopy );
    print hiddenVar( "gene_count_file",    $gene_count_file );
    print hiddenVar( "homolog_count_file", $homolog_count_file );
    print hiddenVar( "genome_count_file",  $genome_count_file );
    print hiddenVar( "show_percentage",    $show_percentage );
    print hiddenVar( "show_hist",          $show_hist );
    print hiddenVar( "show_hits",          $show_hits );
    print hiddenVar("rna16s",              $rna16s) if ( $rna16s );

    my $total_count = $totalGeneCount;
    if ( $xcopy eq 'est_copy' ) {
        $total_count = $totalCopyCount;
    }
    my $pcToolTip = getPcToolTip( '', $xcopy, $total_count );

    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
        "30%+" => "30% and above",
        "60%+" => "60% and above",
        "90%+" => "90% and above"
    );

    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec("Select");
    $sit->addColSpec("D"); # Domain
    $sit->addColSpec("Phylum");
    $sit->addColSpec("No. Of Genomes", "", "right");
    for my $pc ( 30, 60, 90 ) {
        $sit->addColSpec("No. Of Hits ${pc}%$plus", "", "right", "", $toolTip{"${pc}%$plus"});
        $sit->addColSpec("% Hits ${pc}%$plus", "", "right", "", $pcToolTip) if $show_percentage;
        $sit->addColSpec("Histogram ${pc}%$plus") if ($show_hist);
    }

    my $showUnassigned;
    my @domainPhylum;

    for my $class (@filters) {
        my $unEscClass = CGI::unescape($class);
        if ( $unEscClass ne "unassigned\tunassigned" ) {
            push( @domainPhylum, $unEscClass );
        }
        else {
            $showUnassigned = 1;
        }
    }

    # This is the show result data part
    # if no selections show all phyla/classes
    if ( scalar(@filters) < 1 ) {
        @domainPhylum = sort( keys(%found_h) );
        $showUnassigned = 1;
    }

    my $count = 0;
    for my $dpc (@domainPhylum) {
        my $key    = $dpc;
        my $orgcnt = $total_h{$dpc};

        my ( $domain, $phylum ) = split( /\t/, $key );

        my $row;
        
        ## select
        my $tmp  = CGI::escape("compare_$dpc");
        my $tmp2 = CGI::escape("$dpc");
        $row .= "<input type='checkbox' name='filter' value='$tmp2' checked='checked' />\t";

        ## domain
        $row .= substr( $domain, 0, 1 ) . "\t";

        # export 
        print $res "$domain\t";

        # phylum column
        my $phylum_est = $phylum;
        if ( $domain =~ /Virus/ ) {
            $phylum_est =~ s/\_no/, no/;
            $phylum_est =~ s/\_/ /g;
        }
        $phylum_est = escHtml($phylum_est);

        my $midUrl ="&taxon_oid=$taxon_oid&data_type=$data_type";
        $midUrl .= "&domain=" . WebUtil::massageToUrl2($domain);
        $midUrl .= "&phylum=" . WebUtil::massageToUrl2($phylum);
        $midUrl .= "&perc=1" if $show_percentage;
        $midUrl .= "&hist=1" if $show_hist;
        $midUrl .= "&plus=1" if $plus;
        $midUrl .= "&rna16s=1" if $rna16s;
        $midUrl .= "&xcopy=$xcopy" if $xcopy;

        my $phylumUrl = "$main_cgi?section=$section&page=ir_class_file" . $midUrl;
        $row .= "<a href='$phylumUrl' >$phylum_est</a>\t";

        # export
        print $res "$phylum_est\t";

        ## no of genomes
        $row .= $total_h{$key};
        $row .= " (" . $found_h{$key} . ")" if $show_hits;
        $row .= "\t";

        # export
        print $res $total_h{$key};
        print $res " (" . $found_h{$key} . ")" if $show_hits;
        print $res "\t";

        ## 30
        my $genome_val30 = $genome30{$key};
        if ($plus) {
            $genome_val30 += $genome60{$key} + $genome90{$key};
        }

        #cause negative value if est used
        if ( $xcopy eq 'est_copy' ) {
            $totalCount30 += $depth30{$key};
            #if ($plus) {
                $totalCount30 += $depth60{$key} + $depth90{$key};
            #}
        }
        elsif ( $cnt30{$key} ) {
            $totalCount30 += $cnt30{$key};
            #if ($plus) {
                $totalCount30 += $cnt60{$key} + $cnt90{$key};
            #}
        }

        my $val30;
        if ( $xcopy eq 'est_copy' ) {
            $val30 = $depth30{$key};
            if ($plus) {
                $val30 += $depth60{$key} + $depth90{$key};
            }
        }
        else {
            $val30 = $cnt30{$key};
            if ($plus) {
                $val30 += $cnt60{$key} + $cnt90{$key};
            }
        }
        if ($val30) {
            my $c30Url = "$main_cgi?section=$section&page=metagenomeHits" 
                . $midUrl . "&percent_identity=30";
            $row .= alink( $c30Url, $val30 );
            $row .= " (" . $genome_val30 . ")" if $show_hits;
            $row .= "\t";

            # export
            print $res $val30;
            print $res " (" . $genome_val30 . ")" if $show_hits;
            print $res "\t";
        }
        else {
            $row .= nbsp(1) . "\t";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            if ($total_count) {
                $percentHits = $val30 * 100 / $total_count;
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            } else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            if ($total_count) {
                $row .= histogramBar( $val30 / $total_count, 300 );
            }
            else {
                $row .= "-";
            }
            $row .= "\t";
        }

        ## 60
        my $genome_val60 = $genome60{$key};
        if ($plus) {
            $genome_val60 += $genome90{$key};
        }

        #cause negative value if est used
        if ( $xcopy eq 'est_copy' ) {
            $totalCount60 += $depth60{$key};
            #if ($plus) {
                $totalCount60 += $depth90{$key};
            #}
        }
        elsif ( $cnt60{$key} ) {
            $totalCount60 += $cnt60{$key};
            #if ($plus) {
                $totalCount60 += $cnt90{$key};
            #}
        }

        my $val60;
        if ( $xcopy eq 'est_copy' ) {
            $val60 = $depth60{$key};
            if ($plus) {
                $val60 += $depth90{$key};
            }
        }
        else {
            $val60 = $cnt60{$key};
            if ($plus) {
                $val60 += $cnt90{$key};
            }            
        }
        if ($val60) {
            my $c60Url = "$main_cgi?section=$section&page=metagenomeHits"
                . $midUrl . "&percent_identity=60";
            $row .= alink( $c60Url, $val60 );
            $row .= " (" . $genome_val60 . ")" if $show_hits;
            $row .= "\t";

            # export
            print $res $val60;
            print $res " (" . $genome_val60 . ")" if $show_hits;
            print $res "\t";
        }
        else {
            $row .= nbsp(1) . "\t";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            if ( $total_count ) {
                $percentHits = $val60 * 100 / $total_count;                
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            } else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            if ($total_count) {
                $row .= histogramBar( $val60 / $total_count, 200 );
            }
            else {
                $row .= "-";
            }
            $row .= "\t";
        }

        ## 90
        #cause negative value if est used
        if ( $xcopy eq 'est_copy' ) {
            $totalCount90 += $depth90{$key};
        }
        elsif ( $cnt90{$key} ) {
            $totalCount90 += $cnt90{$key};
        }

        my $val90;
        if ( $xcopy eq 'est_copy' ) {
            $val90 = $depth90{$key};
        }
        else {
            $val90 = $cnt90{$key};            
        }
        if ($val90) {
            my $c90Url = "$main_cgi?section=$section&page=metagenomeHits"
                . $midUrl . "&percent_identity=90";
            $row .= alink( $c90Url, $val90 );
            $row .= " (" . $genome90{$key} . ")" if $show_hits;
            $row .= "\t";

            # export
            print $res $val90;
            print $res " (" . $genome90{$key} . ")" if $show_hits;
            print $res "\t";
        }
        else {
            $row .= nbsp(1) . "\t";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            if ($total_count) {
                $percentHits = $val90 * 100 / $total_count;
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            } else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            if ($total_count) {
                $row .= histogramBar( $val90 / $total_count, 100 );
            }
            else {
                $row .= "-";
            }
            $row .= "\t";
        }
        $count++;
        $sit->addRow($row);

       # export end of unassigned
       print $res "\n";
    }
    #print "printFileBestBlastHits() totalCount30=$totalCount30<br/>\n";
    #print "printFileBestBlastHits() totalCount60=$totalCount60<br/>\n";
    #print "printFileBestBlastHits() totalCount90=$totalCount90<br/>\n";

    # unassigned data
    if ( $showUnassigned ) {
        
        #get the right number of totalCount30, totalCount60, totalCount90 when filter exists
        if ( scalar(@filters) > 0 ) {
            $totalCount30 = 0;
            $totalCount60 = 0;
            $totalCount90 = 0;
            for my $key ( keys(%found_h) ) {
                # 30
                if ( $xcopy eq 'est_copy' ) {
                    $totalCount30 += $depth30{$key};
                    #if ($plus) {
                        $totalCount30 += $depth60{$key} + $depth90{$key};
                    #}
                }
                elsif ( $cnt30{$key} ) {
                    $totalCount30 += $cnt30{$key};
                    #if ($plus) {
                        $totalCount30 += $cnt60{$key} + $cnt90{$key};
                    #}
                }
                # 60
                if ( $xcopy eq 'est_copy' ) {
                    $totalCount60 += $depth60{$key};
                    #if ($plus) {
                        $totalCount60 += $depth90{$key};
                    #}
                }
                elsif ( $cnt60{$key} ) {
                    $totalCount60 += $cnt60{$key};
                    #if ($plus) {
                        $totalCount60 += $cnt90{$key};
                    #}
                }
                # 90
                if ( $xcopy eq 'est_copy' && $depth90{$key} ) {
                    $totalCount90 += $depth90{$key};
                }
                elsif ( $cnt90{$key} ) {
                    $totalCount90 += $cnt90{$key};
                }
            }
        }

        my $dpc = "unassigned\tunassigned";
        my $chkVal = CGI::escape("$dpc");

        # checkbox
        my $row = "<input type='checkbox' name='filter' value='$chkVal' checked='checked' />\t";
        $row .= "-\t";
        $row .= "Unassigned\t";
        $row .= "-\t";

        # export
        print $res "-\t";
        print $res "Unassigned\t";
        print $res "-\t";

        # 30 unassigned
        $remain30 = $total_count - $totalCount30;
        $row .= "$remain30\t";

        # export
        print $res "$remain30\t";

        if ($show_percentage) {
            my $percentHits;
            if ( $total_count ) {
                $percentHits = $remain30 * 100 / $total_count;
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            }
            else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }
        if ($show_hist) {
            if ( $total_count ) {
                $row .= histogramBar( $remain30 / $total_count, 300 );
            }
            $row .= "\t";
        }

        # 60 unassigned
        $remain60 = $total_count - $totalCount60;
        $row .= "$remain60\t";

        # export
        print $res "$remain60\t";

        if ($show_percentage) {
            my $percentHits;
            if ( $total_count ) {
                $percentHits = $remain60 * 100 / $total_count;
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            }
            else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            if ( $total_count ) {
                $row .= histogramBar( $remain60 / $total_count, 200 );
            }
            $row .= "\t";
        }
        
        # 90 unassigned
        $remain90 = $total_count - $totalCount90;
        $row .= "$remain90\t";

        # export
        print $res "$remain90\t";

        if ($show_percentage) {
            my $percentHits;
            if ( $total_count ) {
                $percentHits = $remain90 * 100 / $total_count;
            }
            if ( $percentHits > 0 ) {
                $row .= sprintf "%.2f", $percentHits;
            }
            else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            # export
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            if ( $total_count ) {
                $row .= histogramBar( $remain90 / $total_count, 100 );
            }
            $row .= "\t";
        }

        $count++;
        $sit->addRow($row);

        # export end of unassigned
        print $res "\n";
    }
    close $res;

    my $allDomainPhylumCount = scalar( keys(%found_h) ); 
    my $filterCount = scalar( @filters );
    printPhyloTableButtons( $allDomainPhylumCount, $filterCount ) if ( $count > 10 );
    $sit->printTable();
    printPhyloTableButtons( $allDomainPhylumCount, $filterCount );

    # export link
    print qq{
        <p>
        <a href='main.cgi?section=$section&page=download&file=$exportfile&noHeader=1' onClick="_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link $section download']);" >
        Export tab delimited Excel file.</a>
        </p>
    };

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>total gene count: totalGeneCount=$totalGeneCount, total copy count: totalCopyCount=$totalCopyCount\n";
        print "<p>(plus=$plus) use total_count=$total_count\n";
        print "<p>filters=@filters\n";
        print "<p>total: totalCount30=$totalCount30, totalCount60=$totalCount60, totalCount90=$totalCount90\n";
        print "<p>remain: remain30=$remain30, remain60=$remain60, remain90=$remain90\n";
    }

    if ($myimg_job) {
        ### add computation on demand
        print "<h2>Request Recomputation</h2>\n";
        print "<p>\n";
        print "You can request the phylogenetic distribution of genes "
          . "in this genome to be recomputed.\n";

        print "<p>User Notes: ";
        print nbsp(1);
        print "<input type='text' name='user_notes' value='' "
          . "size='60' maxLength='800' />\n";
        print "<br/>";
        my $name = "_section_MyIMG_computePhyloDistOnDemand";
        print submit(
            -name  => $name,
            -value => "Request Recomputation",
            -class => "meddefbutton"
        );
        print "</p>\n";
    }

}

sub printPhyloTableButtons {
    my ( $allDomainPhylumCount, $filterCount ) = @_;

    #print "printPhyloTableButtons() allDomainPhylumCount: $allDomainPhylumCount; filter count: $filterCount<br/>\n";

    print qq{
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
        &nbsp;
    };

    if ( $filterCount == 0 || $filterCount > 1 ) {
        print qq{
            <input class='smdefbutton' type='submit' value='Filter' />
            &nbsp;
        };
    }

    if ( $filterCount > 0 && $filterCount < $allDomainPhylumCount + 1 ) { #1 for unassigned
        print qq{
            <input class='smbutton' type='button' value='Show All Phyla'
            onClick="javascript:selectAllCheckBoxes(0); document.mainForm.submit();" />
        };        
    }

    print qq{
        <br/>
    };

}

#
# Download a tab delimited file to local pc
# file name is part of the url
#
# param none
#
# url example
# main.cgi?section=MetagenomeHits&page=download&file=$exportfile&noHeader=1
#
# we assume file is located at $cgi_tmp_dir
sub download {
    my $file = param("file");

    my $path = "$cgi_tmp_dir/$file";

    if ( !-e $path ) {
        webErrorHeader("Export file no longer exist. Please go back and refresh page.");
    }

    my $sz = fileSize($path);

    print "Content-type: application/vnd.ms-excel\n";

    # apps like open office is extension sensitive, csv for comma and tabs
    # Changed the extension from .csv to .xls since the file is tab separated
    # Using .csv opens the file wrongly in Excel +BSJ 11/20/10
    print "Content-Disposition: inline; filename=$file.xls\n";
    print "Content-length: $sz\n";
    print "\n";

    my $rfh = newReadFileHandle( $path, "download" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

############################################################################
# getFilePhyloGeneList
############################################################################
sub getFilePhyloGeneList {
    my (
        $taxon_oid, $data_type, $percent_identity, $plus,
        $domain,    $phylum,    $ir_class,         $ir_order, 
        $family,    $genus,     $species,          $rna16s,
        $gene_oid_only,         $max_count,
        $genes_ref, $limiting_genes_href
      )
      = @_;

    my $phylo_prefix = "";
    if ( $rna16s ) {
        $phylo_prefix = "16s_";
    }

    my $dbh = dbLogin();
    WebUtil::checkTaxonPerm( $dbh, $taxon_oid );

    my $start_time = time();
    timeout( 60 * $merfs_timeout_mins );

    my $taxon_href = getTaxonTaxonomy( $dbh, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        
    # array of arrays rec data
    $percent_identity = sanitizeInt($percent_identity);
    $taxon_oid = sanitizeInt($taxon_oid);

    my $count = 0;
    my $trunc = 0;

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my $use_zip       = 0;
        my $use_sdb       = 0;
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
            . "/" . $phylo_prefix . $t2 . "." . $percent_identity . ".sdb";
        #print "getPhyloGeneList() full_dir_name: $full_dir_name<br/>\n";
        if ( -e $full_dir_name ) {
            $use_sdb = 1;
        }
        else {
            $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
                . "/" . $t2 . ".list.zip";

            if ( -e $full_dir_name ) {
                $use_zip = 1;
            }
            else {
                $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
                    . "/" . $t2 . ".list.txt";
                if ( !( -e $full_dir_name ) ) {
                    next;
                }
            }
        }
        #print "getPhyloGeneList() use_sdb: $use_sdb<br/>\n";

        if ($use_sdb) {
            # use SQLite
            my @perc_list = ($percent_identity);
            if ($plus) {
                for my $p3 ( 60, 90 ) {
                    if ( $p3 > $percent_identity ) {
                        push @perc_list, ($p3);
                    }
                }
            }

            for my $p3 (@perc_list) {
                if ($trunc) {
                    last;
                }

                my $sdb_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
                    . "/" . $phylo_prefix . $t2 . "." . $p3 . ".sdb";
                if ( !( -e $sdb_name ) ) {
                    next;
                }
                my $dbh2 = WebUtil::sdbLogin($sdb_name)
                  or next;

                my @toid_list = keys %$taxon_href;
                my $sql = MetaUtil::getPhyloDistHomoTaxonsSql( @toid_list );
                if ($max_count) {
                    $sql .= " LIMIT $max_count ";
                }
                webLog("$sql\n");
                #print "getPhyloGeneList() sdb_name: $sdb_name, sql: $sql<br/>\n";
                    
                my $sth = $dbh2->prepare($sql);
                $sth->execute();

                for ( ; ; ) {
                    my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $copies ) 
                        = $sth->fetchrow_array();
                    last if !$gene_oid;
                    next if ( $limiting_genes_href && ! $limiting_genes_href->{$gene_oid} );

                    $count++;
                    if ( $max_count && $count > $max_count ) {
                        $trunc = 1;
                        last;
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ($gene_oid_only) {
                        push @$genes_ref, ($workspace_id);
                    }
                    else {
                        if ( !$taxon_href->{$homo_taxon} ) {
                            # no access to genome
                            next;
                        }
                        my $res =
                            $workspace_id . "\t"
                          . $gene_perc . "\t"
                          . $homolog_gene . "\t"
                          . $homo_taxon . "\t"
                          . $copies. "\t"
                          . $taxon_href->{$homo_taxon};
                        push @$genes_ref, ($res);
                        #print "getPhyloGeneList() added: $res<br/>\n";
                    }

                    # check timeout
                    if (
                        (
                            ( $merfs_timeout_mins * 60 ) -
                            ( time() - $start_time )
                        ) < 200
                      )
                    {
                        $trunc = 2;
                        last;
                    }
                }
                $sth->finish();
                $dbh2->disconnect();
            }    # end for my $p3
        }
        elsif ($use_zip) {
            my %zip_h;
            WebUtil::unsetEnvPath();
            for my $t_oid ( keys %$taxon_href ) {
                if ($trunc) {
                    last;
                }

                my $j         = $t_oid % 1000;
                my $comp_name = $j . ".txt";
                if ( $zip_h{$comp_name} ) {
                    next;
                }
                else {
                    $zip_h{$comp_name} = 1;
                }

                my $fh =
                  newCmdFileHandle(
                    "/usr/bin/unzip -p $full_dir_name $comp_name",
                    'phyloGeneList' );

                while ( my $line = $fh->getline() ) {
                    chomp $line;
                    my (
                        $workspace_id, $gene_perc, $homolog_gene,
                        $homo_taxon,   $copies
                      )
                      = split( /\t/, $line );
                    next if ( $limiting_genes_href && ! $limiting_genes_href->{$workspace_id} );

                    # check percent identity
                    if ( $gene_perc < $percent_identity ) {
                        next;
                    }
                    if ( ( $gene_perc >= ( $percent_identity + 30 ) )
                        && !$plus )
                    {
                        next;
                    }

                    if ($gene_oid_only) {
                        push @$genes_ref, ($workspace_id);
                    }
                    else {
                        if ( !$taxon_href->{$homo_taxon} ) {
                            # no access to genome
                            next;
                        }
                        my $res =
                            $workspace_id . "\t"
                          . $gene_perc . "\t"
                          . $homolog_gene . "\t"
                          . $homo_taxon . "\t"
                          . $copies. "\t"
                          . $taxon_href->{$homo_taxon};
                        push @$genes_ref, ($res);
                    }

                    $count++;
                    if ( $max_count && $count > $max_count ) {
                        $trunc = 1;
                        last;
                    }

                    # check timeout
                    if (
                        (
                            ( $merfs_timeout_mins * 60 ) -
                            ( time() - $start_time )
                        ) < 200
                      )
                    {
                        $trunc = 2;
                        last;
                    }
                }    # end while line
                close $fh;
            }    # end for t_oid

            WebUtil::resetEnvPath();
        }
        else {
            my $fh = newReadFileHandle($full_dir_name);
            while ( my $line = $fh->getline() ) {
                chomp $line;

                my (
                    $workspace_id, $gene_perc, $homolog_gene,
                    $homo_taxon,   $copies
                  )
                  = split( /\t/, $line );
                next if ( $limiting_genes_href && ! $limiting_genes_href->{$workspace_id} );

                if ( $gene_perc < $percent_identity ) {
                    next;
                }
                if ( ( $gene_perc >= ( $percent_identity + 30 ) ) && !$plus ) {
                    next;
                }

                if ($gene_oid_only) {
                    push @$genes_ref, ($workspace_id);
                }
                else {
                    if ( !$taxon_href->{$homo_taxon} ) {
                        # no access to genome
                        next;
                    }
                    my $res =
                        $workspace_id . "\t"
                      . $gene_perc . "\t"
                      . $homolog_gene . "\t"
                      . $homo_taxon . "\t"
                      . $copies. "\t"
                      . $taxon_href->{$homo_taxon};
                    push @$genes_ref, ($res);
                }

                $count++;
                if ( $max_count && $count > $max_count ) {
                    $trunc = 1;
                    last;
                }

                # check timeout
                if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) )
                    < 200 )
                {
                    $trunc = 2;
                    last;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    return $trunc;
}


############################################################################
# printTaxonomyPhyloDist - print taxonomy stats using gene homologs
# other param are from the url
#
# Todo: merge with printFileTaxonomyPhyloDist
############################################################################
sub printTaxonomyPhyloDist {
    my ( $section, $taxonomy ) = @_;

    my $taxonomy_uc = ucfirst($taxonomy);
    if ( $taxonomy eq 'ir_class' ) {
        $taxonomy_uc = 'Class';
    }
    elsif ( $taxonomy eq 'ir_order' ) {
        $taxonomy_uc = 'Order';
    }

    my $taxon_oid = param("taxon_oid");
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $genus     = param("genus");

    my $show_percentage = param("perc");
    my $show_hist       = param("hist");
    my $xcopy           = param("xcopy");

    # param ("plus)" is 1 if cumulative option selected in printForm()
    my $plus = "+" if param("plus");

    printStatusLine( "Loading ...", 1 );

    my $xcopyText = getXcopyText( $xcopy );
    print "<h1>$taxonomy_uc Statistics ($xcopyText)</h1>\n";
    if ( $domain =~ /Virus/ ) {
        my $phylum2 = $phylum;
        $phylum2 =~ s/\_no/\, no/;
        $phylum2 =~ s/\_/ /g;
        printPhyloTitle( $domain, $phylum2, $ir_class, $ir_order, $family, $genus );
    } else {
        printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    }

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid ); 
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    if ( $taxonomy eq 'species' && ($include_metagenomes || $img_internal) ) {
        print "<b>Protein Recruitment Plot</b>\n";
        printRecruitmentSelection( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    }
    print "<p>\n";

    my ($distinctTaxonomy_href, $stats30_href, $stats60_href, $stats90_href, $count30, $count60, $count90)
        = processTaxonomyPhyloDist( $dbh, $taxon_oid, $xcopy, $plus, 
            $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    #print "printTaxonomyPhyloDist()<br/>\n";
    #print Dumper($distinctTaxonomy_href);
    #print "<br/>\n";
            
    my @pcId = ( 30, 60, 90 );
    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
        "30%+" => "30% and above",
        "60%+" => "60% and above",
        "90%+" => "90% and above"
    );

    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec($taxonomy_uc);
    for my $pc (@pcId) {
        my $count_pc;
        if ( $pc == 30  ) {
            $count_pc = $count30;
        }
        elsif ( $pc == 60  ) {
            $count_pc = $count60;                
        }
        elsif ( $pc == 90  ) {
            $count_pc = $count90;
        }
        my $pcToolTip = getPcToolTip( '', $xcopy, $count_pc );

        $sit->addColSpec("No. Of Hits ${pc}%$plus", "", "right", "", $toolTip{"${pc}%$plus"});
        $sit->addColSpec("% Hits ${pc}%$plus", "", "right", "", $pcToolTip) if $show_percentage;
        $sit->addColSpec("Histogram ${pc}%$plus") if ($show_hist);
    }

    my $sublevel_page;
    if ( $taxonomy eq 'ir_class' ) {
        $sublevel_page = 'ir_order';
    }
    elsif ( $taxonomy eq 'ir_order' ) {
        $sublevel_page = 'family';
    }
    elsif ( $taxonomy eq 'family' ) {
        $sublevel_page = 'genus';
    }
    elsif ( $taxonomy eq 'genus' ) {
        $sublevel_page = 'species';
    }

    foreach my $key ( sort keys %$distinctTaxonomy_href ) {
        my $row;

        if ( $taxonomy eq 'species' ) {   
            if ( $include_metagenomes ) {
                my $speciesUrl = "$main_cgi?section=$section";
                $speciesUrl .= "&page=speciesForm";
                $speciesUrl .= "&taxon_oid=$taxon_oid";
                $speciesUrl .= "&domain=" . WebUtil::massageToUrl2($domain);
                $speciesUrl .= "&phylum=" . WebUtil::massageToUrl2($phylum);
                $speciesUrl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $speciesUrl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                $speciesUrl .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                $speciesUrl .= "&genus=" . WebUtil::massageToUrl2($genus) if ( $genus );
                $speciesUrl .= "&species=" . WebUtil::massageToUrl2($key) if ( $key );        
                $speciesUrl .= "&perc=1" if $show_percentage;
                $speciesUrl .= "&hist=1" if $show_hist;
                $speciesUrl .= "&plus=1" if $plus;
                $speciesUrl .= "&xcopy=$xcopy" if $xcopy;
                $row .= qq{
                    <a href="$speciesUrl">$key</a>
                };
            } else {
                $row .= "$key";
            }
        }
        else {
            my $taxonomy_url = "$main_cgi?section=$section";
            $taxonomy_url .= "&page=$sublevel_page";
            $taxonomy_url .= "&taxon_oid=$taxon_oid";
            $taxonomy_url .= "&domain=" . WebUtil::massageToUrl2($domain);
            $taxonomy_url .= "&phylum=" . WebUtil::massageToUrl2($phylum);
            if ( $taxonomy eq 'ir_class' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'ir_order' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'family' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                $taxonomy_url .= "&family=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'genus' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                $taxonomy_url .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                $taxonomy_url .= "&genus=" . WebUtil::massageToUrl2($key);
            }        
            $taxonomy_url .= "&perc=1" if $show_percentage;
            $taxonomy_url .= "&hist=1" if $show_hist;
            $taxonomy_url .= "&plus=1" if $plus;
            $taxonomy_url .= "&xcopy=$xcopy" if $xcopy;
            
            $row .= qq{
                <a href="$taxonomy_url">$key</a>
            };
        }
        $row .= "\t";

        # hits columns
        my $i = 0;
        for my $pc ( @pcId ) {
            my $aref_pc;
            my $count_pc;
            if ( $pc == 30  ) {
                $aref_pc = $stats30_href->{$key};
                $count_pc = $count30;
            }
            elsif ( $pc == 60  ) {
                $aref_pc = $stats60_href->{$key};
                $count_pc = $count60;                
            }
            elsif ( $pc == 90  ) {
                $aref_pc = $stats90_href->{$key};                
                $count_pc = $count90;
            }

            if ( defined($aref_pc) ) {
                my $cnt = 0;
                if ( $xcopy eq 'est_copy' ) {
                    $cnt = 0;
                    for my $a1 (@$aref_pc) {
                        my @v = split( /\t/, $a1 );
                        $cnt += $v[-1];
                        #print "printTaxonomyPhyloDist() a1=$a1, cnt=$cnt<br/>\n";
                    }
                }
                else {
                    $cnt = $#$aref_pc + 1;                    
                }

                if ($cnt) {
                    # count here should be link to page taxonomyMetagHits
                    my $tmpurl = "$main_cgi?section=$section&page=taxonomyMetagHits";
                    $tmpurl .= "&taxon_oid=$taxon_oid";
                    $tmpurl .= "&domain=" . WebUtil::massageToUrl2($domain);
                    $tmpurl .= "&phylum=" . WebUtil::massageToUrl2($phylum);
                    if ( $taxonomy eq 'ir_class' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'ir_order' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'family' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'genus' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                        $tmpurl .= "&genus=" . WebUtil::massageToUrl2($key);
                    }        
                    elsif ( $taxonomy eq 'species' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                        $tmpurl .= "&genus=" . WebUtil::massageToUrl2($genus) if ( $genus );
                        $tmpurl .= "&species=" . WebUtil::massageToUrl2($key);
                    }
                    $tmpurl .= "&perc=1"           if $show_percentage;
                    $tmpurl .= "&hist=1"           if $show_hist;
                    $tmpurl .= "&plus=1"           if $plus;
                    $tmpurl .= "&xcopy=$xcopy"     if $xcopy;
                    $tmpurl .= "&percent=$pc";

                    $row .= qq{
                        <a href="$tmpurl">$cnt</a>
                    };                }
                else {
                    $row .= nbsp(1);
                }
                $row .= "\t";

                if ($show_percentage) {
                    my $percentHits;
                    $percentHits = $cnt * 100 / $count_pc;
                    if ( $percentHits > 0 ) {
                        $row .= sprintf "%.2f", $percentHits;
                    } else {
                        $row .= nbsp(1);
                    }
                    $row .= "\t";
                }

                if ($show_hist) {
                    if ($count_pc) {
                        my $maxLen = (scalar(@pcId) - $i) * 100;
                        $row .= histogramBar( $cnt / $count_pc, $maxLen );
                    } else {
                        $row .= "-";
                    }
                    $row .= "\t";
                }
    
            } else {
                $row .= "-\t";
            
                if ($show_percentage) {
                    $row .= nbsp(1) . "\t";
                }
    
                if ($show_hist) {
                    $row .= nbsp(1) . "\t";
                }
            }
            $i++;
        }
        
        $sit->addRow($row);
    }
    $sit->printTable();

    printStatusLine( "Loaded.", 2 );
}

sub processTaxonomyPhyloDist {
    my ( $dbh, $taxon_oid, $xcopy, $plus, 
        $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = @_;

    my %distinctTaxonomy;
    my %stats30;
    my %stats60;
    my %stats90;
    my $count30 = 0;
    my $count60 = 0;
    my $count90 = 0;

    my $taxonomyClause;
    my @binds = ( $taxon_oid );
        
    if ( $domain ) {
        $taxonomyClause .= " and t.domain = ? ";            
        push( @binds, $domain );
    }
        
    if ( $phylum ) {
        $taxonomyClause .= " and t.phylum = ? ";            
        push( @binds, $phylum );
    }
        
    if ( $ir_class ) {
        $taxonomyClause .= " and t.ir_class = ? ";
        push( @binds, $ir_class );
    }
    elsif ( !defined($ir_class) || $ir_class eq "" ) {
        if ( $taxonomy eq 'ir_order' 
            || $taxonomy eq 'family' 
            || $taxonomy eq 'genus' 
            || $taxonomy eq 'species' ) {
            $taxonomyClause .= " and t.ir_class is null ";                
        }
    }
    if ( $ir_order ) {
        $taxonomyClause .= " and t.ir_order = ? ";
        push( @binds, $ir_order );
    }
    elsif ( !defined($ir_order) || $ir_order eq "" ) {
        if ( $taxonomy eq 'family' 
            || $taxonomy eq 'genus' 
            || $taxonomy eq 'species' ) {
            $taxonomyClause .= " and t.ir_order is null ";                
        }
    }
    if ( $family ) {
        $taxonomyClause .= " and t.family = ? ";
        push( @binds, $family );
    }
    elsif ( !defined($family) || $family eq "" ) {
        if ( $taxonomy eq 'genus' 
            || $taxonomy eq 'species' ) {
            $taxonomyClause .= " and t.family is null ";                
        }
    }
    if ( $genus ) {
        $taxonomyClause .= " and t.genus = ? ";
        push( @binds, $genus );
    }
    elsif ( !defined($genus) || $genus eq "" ) {
        if ( $taxonomy eq 'species') {
            $taxonomyClause .= " and t.genus is null ";                
        }
    } 

    my $rclause   = WebUtil::urClause('dt.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

    my $sql;
    if ( $xcopy eq 'est_copy' ) {
        $sql = qq{
            select dt.gene_oid, g.est_copy, dt.taxon_oid, dt.percent_identity,
                   $nvl(t.$taxonomy, '$unknown') 
            from dt_phylum_dist_genes dt, gene g, taxon t
            where dt.gene_oid = g.gene_oid
            and dt.taxon_oid = ?
            and dt.homolog_taxon = t.taxon_oid
            $taxonomyClause 
            $rclause
            $imgClause
        };
    } else {
        $sql = qq{
            select dt.gene_oid, 1, dt.taxon_oid, dt.percent_identity,
                   $nvl(t.$taxonomy, '$unknown')
            from dt_phylum_dist_genes dt, taxon t
            where dt.taxon_oid = ?
            and dt.homolog_taxon = t.taxon_oid
            $taxonomyClause 
            $rclause
            $imgClause
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my ( $gene_oid, $cnt, $taxon, $percent, $sublevel ) = $cur->fetchrow();
        last if !$gene_oid;

        my $key   = "$sublevel";
        my $value = "$taxon\t$gene_oid\t$percent\t$cnt";

        if ( !exists( $distinctTaxonomy{$key} ) ) {
            $distinctTaxonomy{$key} = "";
        }

        if (    ( $plus && $percent >= 30 )
             || ( !$plus && $percent < 60 ) )
        {
            $count30 += $cnt;
            if ( exists( $stats30{$key} ) ) {
                my $aref = $stats30{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats30{$key} = \@a;
            }
        }

        if (    ( $plus && $percent >= 60 )
             || ( !$plus && ( $percent >= 60 && $percent < 90 ) ) )
        {
            $count60 += $cnt;
            if ( exists( $stats60{$key} ) ) {
                my $aref = $stats60{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats60{$key} = \@a;
            }

        }
        if ( $percent >= 90 ) {
            $count90 += $cnt;
            if ( exists( $stats90{$key} ) ) {
                my $aref = $stats90{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats90{$key} = \@a;
            }
        }
    }
    $cur->finish();

    return (\%distinctTaxonomy, \%stats30, \%stats60, \%stats90, $count30, $count60, $count90);
}

############################################################################
# printFileTaxonomyPhyloDist - print taxonomy stats using gene homologs
# other param are from the url
#
# Todo: merge with printTaxonomyPhyloDist
############################################################################
sub printFileTaxonomyPhyloDist {
    my ( $section, $taxonomy ) = @_;

    my $taxonomy_uc = ucfirst($taxonomy);
    if ( $taxonomy eq 'ir_class' ) {
        $taxonomy_uc = 'Class';
    }
    elsif ( $taxonomy eq 'ir_order' ) {
        $taxonomy_uc = 'Order';
    }

    my $taxon_oid       = param("taxon_oid");
    my $data_type       = param("data_type");
    my $rna16s          = param("rna16s");

    my $domain          = param("domain");
    my $phylum          = param("phylum");
    my $ir_class        = param("ir_class");
    my $ir_order        = param("ir_order");
    my $family          = param("family");
    my $genus           = param("genus");

    my $show_percentage = param("perc");
    my $show_hist       = param("hist");
    my $xcopy           = param("xcopy");

    my $phylo_prefix = "";
    if ( $rna16s ) {
        $phylo_prefix = "16s_";
    }
    
    # param ("plus)" is 1 if cumulative option selected in printForm()
    my $plus = "+" if param("plus");

    printStatusLine( "Loading ...", 1 );

    my $stats_keyword = "Protein coding genes";
    if ( $rna16s ) {
       $stats_keyword = "16S rRNA";
    }
    my $totalGeneCount =
       MetaUtil::getGenomeStats( $taxon_oid, $data_type, $stats_keyword );

    print "<h1>";
    if ( $rna16s ) {
        print "16S rRNA Gene ";
    }
    my $xcopyText = getXcopyText( $xcopy );
    print "$taxonomy_uc Statistics ($xcopyText)";
    print "</h1>\n";
    if ( $domain =~ /Virus/ ) {
        my $phylum2 = $phylum;
        $phylum2 =~ s/\_no/\, no/;
        $phylum2 =~ s/\_/ /g;
        printPhyloTitle( $domain, $phylum2, $ir_class, $ir_order, $family, $genus );
    } else {
        printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    }

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $taxon_name, $data_type );

    if ( $taxonomy eq 'species' ) {
        # rec. plot - ken
        my $plotUrl = "main.cgi?section=MetagenomeGraph&page=fragRecView3&strand=all&taxon_oid=$taxon_oid";
        $plotUrl .= "&data_type=$data_type"  if ( $data_type );
        if ( $section eq 'MetagenomeHits' ) {
            # skip
        } else {
            $plotUrl .= "&merfs=1";
        }
        $plotUrl .= "&domain=$domain";
        $plotUrl .= "&phylum=$phylum";
        $plotUrl .= "&ir_class=$ir_class" if ( $ir_class );
        $plotUrl .= "&ir_class=$ir_order" if ( $ir_order );
        $plotUrl .= "&family=$family" if ( $family );
        $plotUrl .= "&genus=$genus" if ( $genus );
    
        print qq{
            <p>
            <input class="smdefbutton" type="button" 
            name="ProteinRecruitmentPlot" value="Protein Recruitment Plot" 
            onclick="window.open('$plotUrl', '_self')">
        };        
    }

    my ($distinctTaxonomy_href, $stats30_href, $stats60_href, $stats90_href, $count30, $count60, $count90)
        = processFileTaxonomyPhyloDist( $dbh, $taxon_oid, $data_type, $xcopy, $plus, $phylo_prefix, 
            $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    #print "printFileTaxonomyPhyloDist()<br/>\n";
    #print Dumper($distinctTaxonomy_href);
    #print "<br/>\n";

    my $total_count = $totalGeneCount;
    #if ( $xcopy eq 'est_copy' && $totalCopyCount ) {
    #    $total_count = $totalCopyCount;
    #}
    my $pcToolTip = getPcToolTip( '', $xcopy, $total_count );

    my @pcId = ( 30, 60, 90 );
    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
        "30%+" => "30% and above",
        "60%+" => "60% and above",
        "90%+" => "90% and above"
    );

    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec($taxonomy_uc);
    for my $pc (@pcId) {
        $sit->addColSpec("No. Of Hits ${pc}%$plus", "", "right", "", $toolTip{"${pc}%$plus"});
        $sit->addColSpec("% Hits ${pc}%$plus", "", "right", "", $pcToolTip) if $show_percentage;
        $sit->addColSpec("Histogram ${pc}%$plus") if ($show_hist);
    }

    my $sublevel_page;
    if ( $taxonomy eq 'ir_class' ) {
        $sublevel_page = 'ir_order_file';
    }
    elsif ( $taxonomy eq 'ir_order' ) {
        $sublevel_page = 'family_file';
    }
    elsif ( $taxonomy eq 'family' ) {
        $sublevel_page = 'genus_file';
    }
    elsif ( $taxonomy eq 'genus' ) {
        $sublevel_page = 'species_file';
    }

    foreach my $key ( sort keys %$distinctTaxonomy_href ) {

        my $row;
        if ( $taxonomy eq 'species' ) {     
            $row .= "$key";
        }
        else {
            my $taxonomy_url = "$main_cgi?section=$section";
            $taxonomy_url .= "&page=$sublevel_page";
            $taxonomy_url .= "&taxon_oid=$taxon_oid&data_type=$data_type";
            $taxonomy_url .= "&domain=" . WebUtil::massageToUrl2($domain);
            $taxonomy_url .= "&phylum=" . WebUtil::massageToUrl2($phylum);
            if ( $taxonomy eq 'ir_class' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'ir_order' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'family' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                $taxonomy_url .= "&family=" . WebUtil::massageToUrl2($key);
            }
            elsif ( $taxonomy eq 'genus' ) {
                $taxonomy_url .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                $taxonomy_url .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                $taxonomy_url .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                $taxonomy_url .= "&genus=" . WebUtil::massageToUrl2($key);
            }        
            $taxonomy_url .= "&perc=1" if $show_percentage;
            $taxonomy_url .= "&hist=1" if $show_hist;
            $taxonomy_url .= "&plus=1" if $plus;
            $taxonomy_url .= "&rna16s=1" if $rna16s;
            $taxonomy_url .= "&xcopy=$xcopy" if $xcopy;
            
            $row .= qq{
                <a href="$taxonomy_url">$key</a>
            };
        }
        $row .= "\t";

        # hits columns
        my $i = 0;
        for my $pc ( @pcId ) {
            my $aref_pc;
            my $count_pc;
            if ( $pc == 30  ) {
                $aref_pc = $stats30_href->{$key};
                $count_pc = $count30;
            }
            elsif ( $pc == 60  ) {
                $aref_pc = $stats60_href->{$key};
                $count_pc = $count60;                
            }
            elsif ( $pc == 90  ) {
                $aref_pc = $stats90_href->{$key};                
                $count_pc = $count90;
            }

            if ( defined($aref_pc) ) {
                my $cnt = $aref_pc;    
                if ($cnt) {
                    # count here should be link to page taxonomyMetagHits
                    my $tmpurl = "$main_cgi?section=$section&page=taxonomyMetagHits";
                    $tmpurl .= "&taxon_oid=$taxon_oid&data_type=$data_type";
                    $tmpurl .= "&domain=" . WebUtil::massageToUrl2($domain);
                    $tmpurl .= "&phylum=" . WebUtil::massageToUrl2($phylum);
                    if ( $taxonomy eq 'ir_class' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'ir_order' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'family' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($key);
                    }
                    elsif ( $taxonomy eq 'genus' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                        $tmpurl .= "&genus=" . WebUtil::massageToUrl2($key);
                    }        
                    elsif ( $taxonomy eq 'species' ) {
                        $tmpurl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
                        $tmpurl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
                        $tmpurl .= "&family=" . WebUtil::massageToUrl2($family) if ( $family );
                        $tmpurl .= "&genus=" . WebUtil::massageToUrl2($genus) if ( $genus );
                        $tmpurl .= "&species=" . WebUtil::massageToUrl2($key);
                    }
                    $tmpurl .= "&perc=1"           if $show_percentage;
                    $tmpurl .= "&hist=1"           if $show_hist;
                    $tmpurl .= "&plus=1"           if $plus;
                    $tmpurl .= "&rna16s=1"         if $rna16s;
                    $tmpurl .= "&xcopy=$xcopy"     if $xcopy;
                    $tmpurl .= "&percent=$pc";

                    $row .= qq{
                        <a href="$tmpurl">$cnt</a>
                    };
                }
                else {
                    $row .= nbsp(1);
                }
                $row .= "\t";
        
                if ($show_percentage) {
                    my $percentHits;
                    $percentHits = $cnt * 100 / $count_pc;
                    if ( $percentHits > 0 ) {
                        $row .= sprintf "%.2f", $percentHits;
                    } else {
                        $row .= nbsp(1);
                    }
                    $row .= "\t";
                }

                if ($show_hist) {
                    if ($count_pc) {
                        my $maxLen = (scalar(@pcId) - $i) * 100;
                        $row .= histogramBar( $cnt / $count_pc, $maxLen );
                    } else {
                        $row .= "-";
                    }
                    $row .= "\t";
                }
    
            } else {
                $row .= "-\t";
            
                if ($show_percentage) {
                    $row .= nbsp(1) . "\t";
                }
    
                if ($show_hist) {
                    $row .= nbsp(1) . "\t";
                }
            }
            $i++;
        }        
        $sit->addRow($row);
    }
    $sit->printTable();

    printStatusLine( "Loaded.", 2 );
}

sub processFileTaxonomyPhyloDist {
    my ( $dbh, $taxon_oid, $data_type, $xcopy, $plus, $phylo_prefix,
        $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = @_;

    my %distinctTaxonomy;
    my %stats30;
    my %stats60;
    my %stats90;
    my $count30 = 0;
    my $count60 = 0;
    my $count90 = 0;

    printStartWorkingDiv();

    print "Rerieving taxon phylogeny ...<br/>\n";
    my $taxon_href = getTaxonTaxonomy( $dbh, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus );

    $taxon_oid = sanitizeInt($taxon_oid);
    my @type_list = MetaUtil::getDataTypeList( $data_type );

    for my $t2 (@type_list) {
        print "<p>Retrieving $t2 data ...\n";
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
            . "/" . $phylo_prefix . $t2 . ".profile.txt";
        if ( !( -e $full_dir_name ) ) {
            next;
        }

        my $res = newReadFileHandle($full_dir_name);
        while ( my $line = $res->getline() ) {
            chomp $line;
            my ( $tid2, $c30, $c60, $c90, $d30, $d60, $d90 ) =
              split( /\t/, $line );

            if ( !$taxon_href->{$tid2} ) {
                # no access to genome
                next;
            }
            
            my ( $domain2, $phylum2, $ir_class2, $ir_order2, $family2, $genus2, $species2, $tname ) =
              split( /\t/, $taxon_href->{$tid2} );

            my $key;
            if ( $taxonomy eq 'ir_class' ) {
                if ( $domain2 ne $domain 
                    || $phylum2 ne $phylum ) {
                    next;
                }
                $key = "$ir_class2";
            }
            elsif ( $taxonomy eq 'ir_order' ) {
                if ( $domain2 ne $domain 
                    || $phylum2 ne $phylum 
                    || $ir_class2 ne $ir_class ) {
                    next;
                }
                $key = "$ir_order2";
            }
            elsif ( $taxonomy eq 'family' ) {
                if ( $domain2 ne $domain 
                    || $phylum2 ne $phylum 
                    || $ir_class2 ne $ir_class 
                    || $ir_order2 ne $ir_order ) {
                    next;
                }
                $key = "$family2";
            }
            elsif ( $taxonomy eq 'genus' ) {
                if ( $domain2 ne $domain 
                    || $phylum2 ne $phylum 
                    || $ir_class2 ne $ir_class 
                    || $ir_order2 ne $ir_order
                    || $family2 ne $family ) {
                    next;
                }
                $key = "$genus2";
            }
            elsif ( $taxonomy eq 'species' ) {
                if ( $domain2 ne $domain 
                    || $phylum2 ne $phylum 
                    || $ir_class2 ne $ir_class 
                    || $ir_order2 ne $ir_order
                    || $family2 ne $family
                    || $genus2 ne $genus ) {
                    next;
                }
                $key = "$species2";
            }
            print "key: $key<br/>\n";

            my $ct30 = $c30;
            my $ct60 = $c60;
            my $ct90 = $c90;
            if ( $xcopy eq 'est_copy' ) {
                if ( $d30 && $d30 > $c30 ) {
                    $ct30 = $d30;
                }
                if ( $d60 && $d60 > $c60 ) {
                    $ct60 = $d60;
                }
                if ( $d90 && $d90 > $c90) {
                    $ct90 = $d90;
                }
            }

            if ($ct30) {
                $distinctTaxonomy{$key} = 1;
                $stats30{$key}     += $ct30;
                $count30           += $ct30;
            }

            if ($ct60) {
                $distinctTaxonomy{$key} = 1;
                $stats60{$key}     += $ct60;
                $count60           += $ct60;

                if ($plus) {
                    $stats30{$key} += $ct60;
                    $count30       += $ct60;
                }
            }

            if ($ct90) {
                $distinctTaxonomy{$key} = 1;
                $stats90{$key}     += $ct90;
                $count90           += $ct90;

                if ($plus) {
                    $stats30{$key} += $ct90;
                    $count30       += $ct90;
                    $stats60{$key} += $ct90;
                    $count60       += $ct90;
                }
            }
        }
        close $res;
    }    # end t2

    printEndWorkingDiv();

    return (\%distinctTaxonomy, \%stats30, \%stats60, \%stats90, $count30, $count60, $count90);
}


############################################################################
# prints buttons for printSpeciesStatsForm
#
# see printSpeciesStatsForm
############################################################################
sub printSpeciesFormButtons {
    print <<EOF;
        <input type='button' name='plot1' value='Run Viewer' 
        onClick='plot(\"$main_cgi\")' 
        class='smbutton' />
        &nbsp;
EOF
    if ($img_internal) {
        print <<EOF;
        <input type='button' name='plot2' value='Future'  
        onClick='plotProtein(\"$main_cgi\")' 
        class='smbutton' />
        &nbsp;
EOF
    }
}

############################################################################
# bin section
############################################################################

#
# load bin stats for a given percent identity
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param $percent_identity - percent 30, 60 or 90
# param $stats_href - return hash table of data method \t method oid => count
# param $distinct_list_href - return distinct list of method \t method oid
#
sub loadBinStats {
    my ( $dbh, $taxon_oid, $percent_identity, $stats_href, $distinct_list_href ) = @_;

    my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = getPercentClause( $percent_identity );
    my $sql = qq{
        select bm.bin_method_oid, bm.method_name,  count(*)
        from dt_phylum_dist_genes dt, bin b, bin_scaffolds bs, 
             bin_method bm, gene g
        where dt.taxon_oid = ?
        and b.env_sample = ?
        and b.bin_oid = bs.bin_oid
        and b.is_default = 'Yes'
        and b.bin_method = bm.bin_method_oid
        and g.scaffold = bs.scaffold
        and g.gene_oid = dt.gene_oid
        and g.taxon = ?
        and g.taxon = dt.taxon_oid
        $rclause
        group by bm.bin_method_oid, bm.method_name
   };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $env_sample, $taxon_oid );

    my $totalCount = 0;
    for ( ; ; ) {
        my ( $method_oid, $method_name, $cnt ) = $cur->fetchrow();
        last if !$method_name;
        $totalCount += $cnt;
        my $key = "$method_name\t$method_oid";
        $distinct_list_href->{$key} = "";
        $stats_href->{$key}         = $cnt;
    }
    $cur->finish();

    return $totalCount;
}

# prints taxon's bin method stats page
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
sub printBinStats {
    my ( $section, $taxon_oid ) = @_;

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    # a distinct list of method\tbin_name
    my %distinctList;

    #
    my %stats30;
    my $count30 =
      loadBinStats( $dbh, $taxon_oid, 30, \%stats30, \%distinctList );
    my %stats60;
    my $count60 =
      loadBinStats( $dbh, $taxon_oid, 60, \%stats60, \%distinctList );
    my %stats90;
    my $count90 =
      loadBinStats( $dbh, $taxon_oid, 90, \%stats90, \%distinctList );

    print "<h2>$taxon_name<br>Bin Methods</h2>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Method</th>\n";
    print "<th class='img' title='30% to 59%' align='right'>"
      . "No. Of Hits 30%</th>\n";
    print "<th class='img' >Histogram 30%</th>\n";
    print "<th class='img' title='60% to 89%' align='right'>"
      . "No. Of Hits 60%</th>\n";
    print "<th class='img' >Histogram 60%</th>\n";
    print "<th class='img'  align='right'>No. Of Hits 90%</th>\n";
    print "<th class='img' >Histogram 90%</th>\n";

    my @methodbins = sort( keys(%distinctList) );
    for my $key (@methodbins) {
        my ( $method, $method_oid ) = split( /\t/, $key );

        print "<tr class='img' >\n";

        # url
        my $url = "$main_cgi?section=$section&page=binmethodstats";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&method_oid=$method_oid";

        print "<td class='img' >\n";
        print "<a href='$url' > $method </a>";
        print "</td>\n";

        if ( exists( $stats30{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats30{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats30{$key} / $count30, 300 );
            print "</td>\n";

        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats60{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats60{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats60{$key} / $count60, 200 );
            print "</td>\n";

        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats90{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats90{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats90{$key} / $count90, 100 );
            print "</td>\n";

        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        print "</tr>\n";
    }

    print "</table>\n";
    printStatusLine( "Loaded.", 2 );
}

#
# load a bin method's bins stats for a given percent identity
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param $method_oid - bin method oid
# param $percent_identity - percent 30, 60 or 90
# param $stats_href - return hash table of data "bin name\t bin id" => count
# param $distinct_list_href - return distinct list of "bin name\t bin id"
#
sub loadBinMethodStats {
    my ( $dbh, $taxon_oid, $method_oid, $percent_identity, $stats_href,
        $distinct_list_href )
      = @_;

    my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = getPercentClause( $percent_identity );
    my $sql = qq{
        select b.bin_oid, b.display_name, count(*)
        from dt_phylum_dist_genes dt, bin b, bin_scaffolds bs, 
             bin_method bm, gene g
        where dt.taxon_oid = ?
        and b.env_sample = ?
        and b.bin_oid = bs.bin_oid
        and b.is_default = 'Yes'
        and b.bin_method = bm.bin_method_oid
        and bm.bin_method_oid = ? 
        and g.scaffold = bs.scaffold
        and g.taxon = ?
        and g.taxon = dt.taxon_oid
        and g.gene_oid = dt.gene_oid
        $rclause
        group by b.bin_oid, b.display_name
   };

    my $cur =
      execSql( $dbh, $sql, $verbose, $taxon_oid, $env_sample, $method_oid,
        $taxon_oid );
    my $totalCount = 0;
    for ( ; ; ) {
        my ( $oid, $name, $cnt ) = $cur->fetchrow();
        last if !$oid;
        $totalCount += $cnt;
        my $key = "$name\t$oid";
        $distinct_list_href->{$key} = "";
        $stats_href->{$key}         = $cnt;
    }
    $cur->finish();
    return $totalCount;
}

# prints bin method's stats page
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param others by url
sub printBinMethodStats {
    my ( $section, $taxon_oid ) = @_;

    my $method_oid = param("method_oid");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    my $method_name = QueryUtil::getMethodName( $dbh, $method_oid );

    # a distinct list of method\tbin_name
    my %distinctList;

    my %stats30;
    my $count30 =
      loadBinMethodStats( $dbh, $taxon_oid, $method_oid, 30, \%stats30,
        \%distinctList );
    my %stats60;
    my $count60 =
      loadBinMethodStats( $dbh, $taxon_oid, $method_oid, 60, \%stats60,
        \%distinctList );
    my %stats90;
    my $count90 =
      loadBinMethodStats( $dbh, $taxon_oid, $method_oid, 90, \%stats90,
        \%distinctList );

    print "<h2>$taxon_name<br>$method_name Bins</h2>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Bin Name</th>\n";
    print "<th class='img' title='30% to 59%' align='right'>"
      . "No. Of Hits 30%</th>\n";
    print "<th class='img' >Histogram 30%</th>\n";
    print "<th class='img' title='60% to 89%' align='right'>"
      . "No. Of Hits 60%</th>\n";
    print "<th class='img' >Histogram 60%</th>\n";
    print "<th class='img'  align='right'>No. Of Hits 90%</th>\n";
    print "<th class='img' >Histogram 90%</th>\n";
    my @methodbins = sort( keys(%distinctList) );

    for my $key (@methodbins) {
        my ( $name, $bin_oid ) = split( /\t/, $key );

        print "<tr class='img' >\n";

        # url
        my $url = "$main_cgi?section=$section&page=binfamilystats";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&method_oid=$method_oid";
        $url .= "&bin_oid=$bin_oid";

        print "<td class='img' >\n";
        print "<a href='$url' > $name </a>";
        print "</td>\n";

        if ( exists( $stats30{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats30{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats30{$key} / $count30, 300 );
            print "</td>\n";

        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats60{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats60{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats60{$key} / $count60, 200 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats90{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats90{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats90{$key} / $count90, 100 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        print "</tr>\n";
    }

    print "</table>\n";
    printStatusLine( "Loaded.", 2 );
}

#
# load a bin's family stats for a given percent identity
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param $method_oid - bin method oid
# param $bin_oid - bin oid
# param $percent_identity - percent 30, 60 or 90
# param $stats_href - return hash table of data "bin name\t bin id" => count
# param $distinct_list_href - return distinct list of "bin name\t bin id"
#
sub loadBinFamilyStats {
    my ( $dbh, $taxon_oid, $method_oid, $bin_oid, $percent_identity,
        $stats_href, $distinct_list_href )
      = @_;

    my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = getPercentClause( $percent_identity );
    my $sql = qq{
       select t2.family, count(*)
       from bin b, bin_method bm, bin_scaffolds bs, gene g,
            dt_phylum_dist_genes dt, gene g2, taxon t2
       where b.env_sample = ?
       and b.bin_method = bm.bin_method_oid
       and b.is_default = 'Yes'
       and bm.bin_method_oid = ?
       and b.bin_oid = ?
       and b.bin_oid = bs.bin_oid
       and g.scaffold = bs.scaffold
       and g.taxon = ?
       and g.taxon = dt.taxon_oid
       and dt.gene_oid = g.gene_oid
       and dt.homolog = g2.gene_oid
       and g2.taxon = t2.taxon_oid
       $rclause
       group by t2.family
   };

    my $cur =
      execSql( $dbh, $sql, $verbose, $env_sample, $method_oid, $bin_oid,
        $taxon_oid );
    my $totalCount = 0;
    for ( ; ; ) {
        my ( $name, $cnt ) = $cur->fetchrow();
        last if !$name;
        $totalCount += $cnt;
        my $key = "$name";
        $distinct_list_href->{$key} = "";
        $stats_href->{$key}         = $cnt;
    }
    $cur->finish();
    return $totalCount;
}

# prints bin's family stats page
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param others by url
sub printBinFamilyStats {
    my ( $section, $taxon_oid ) = @_;

    my $method_oid = param("method_oid");
    my $bin_oid    = param("bin_oid");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    my $method_name = QueryUtil::getMethodName( $dbh, $method_oid );
    my $bin_name = QueryUtil::getBinName( $dbh, $bin_oid );

    # a distinct list of method\tbin_name
    my %distinctList;

    my %stats30;
    my $count30 =
      loadBinFamilyStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 30,
        \%stats30, \%distinctList );
    my %stats60;
    my $count60 =
      loadBinFamilyStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 60,
        \%stats60, \%distinctList );
    my %stats90;
    my $count90 =
      loadBinFamilyStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 90,
        \%stats90, \%distinctList );

    print "<h2>$taxon_name<br>$method_name $bin_name Family</h2>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Family Name</th>\n";
    print "<th class='img' title='30% to 59%' align='right'>"
      . "No. Of Hits 30%</th>\n";
    print "<th class='img' >Histogram 30%</th>\n";
    print "<th class='img' title='60% to 89%' align='right'>"
      . "No. Of Hits 60%</th>\n";
    print "<th class='img' >Histogram 60%</th>\n";
    print "<th class='img'  align='right'>No. Of Hits 90%</th>\n";
    print "<th class='img' >Histogram 90%</th>\n";

    my @methodbins = sort( keys(%distinctList) );
    for my $key (@methodbins) {
        my $family = $key;

        print "<tr class='img' >\n";

        # url
        my $url = "$main_cgi?section=$section&page=binscatter";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&method_oid=$method_oid";
        $url .= "&bin_oid=$bin_oid";
        $url .= "&family=$family";

        print "<td class='img' >\n";
        print "<a href='$url' > $family </a>";
        print "</td>\n";

        if ( exists( $stats30{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats30{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats30{$key} / $count30, 300 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats60{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats60{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats60{$key} / $count60, 300 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats90{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats90{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats90{$key} / $count90, 100 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        print "</tr>\n";
    }

    print "</table>\n";
    printStatusLine( "Loaded.", 2 );
}

#
# load a bin's species stats for a given percent identity
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# param $method_oid - bin method oid
# param $bin_oid - bin oid
# param $percent_identity - percent 30, 60 or 90
# param $family - homolog family name
# param $stats_href - return hash table of data "bin name\t bin id" => count
# param $distinct_list_href - return distinct list of "bin name\t bin id"
#
sub loadBinSpeciesStats {
    my ( $dbh, $taxon_oid, $method_oid, $bin_oid, $percent_identity, $family,
        $stats_href, $distinct_list_href )
      = @_;

    my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = getPercentClause( $percent_identity );
    my $sql = qq{
       select t2.genus, t2.species, count(*)
       from bin b, bin_method bm, bin_scaffolds bs, gene g,
            dt_phylum_dist_genes dt, gene g2, taxon t2
       where b.env_sample = ?
       and b.bin_method = bm.bin_method_oid
       and b.is_default = 'Yes'
       and bm.bin_method_oid = ? 
       and b.bin_oid = ? 
       and b.bin_oid = bs.bin_oid
       and g.scaffold = bs.scaffold
       and g.taxon = ?
       and g.taxon = dt.taxon_oid
       and dt.gene_oid = g.gene_oid
       and dt.homolog = g2.gene_oid
       and g2.taxon = t2.taxon_oid
       $rclause
       and t2.family = ?
       group by t2.genus, t2.species
   };

    my $cur =
      execSql( $dbh, $sql, $verbose, $env_sample, $method_oid, $bin_oid,
        $taxon_oid, $family );

    my $totalCount = 0;
    for ( ; ; ) {
        my ( $genus, $species, $cnt ) = $cur->fetchrow();
        last if !$genus;
        $totalCount += $cnt;
        my $key = "$genus\t$species";
        $distinct_list_href->{$key} = "";
        $stats_href->{$key}         = $cnt;
    }
    $cur->finish();
    return $totalCount;
}

#
# prints scatter plot form for a given family
#
# param $dbh - database handler
# param others by url
sub printBinScatterPlotForm {
    my ($section) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $method_oid = param("method_oid");
    my $bin_oid    = param("bin_oid");
    my $family     = param("family");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name  = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    my $method_name = QueryUtil::getMethodName( $dbh, $method_oid );
    my $bin_name    = QueryUtil::getBinName( $dbh, $bin_oid );

    print "<h2>$taxon_name<br>$method_name $bin_name"
      . "<br>Family $family</h2>\n";

    my $link;
    if ( $section eq 'MetagenomeHits' ) {
        $link = "<a href='main.cgi?section=MetagenomeGraph&page=binscatter";        
    }
    else {
        $link = "<a href='main.cgi?section=MetaFileGraph&page=binscatter";        
    }

    my $gUrl .= "&taxon_oid=$taxon_oid";
    $gUrl    .= "&family=$family";
    $gUrl    .= "&method_oid=$method_oid";
    $gUrl    .= "&bin_oid=$bin_oid";

    print $link . "&strand=all" . "$gUrl'>Protein Recruitment Plot</a> <br>";
    print $link
      . "&strand=pos"
      . "$gUrl'>Protein Recruitment Plot positive strands</a> <br>";
    print $link
      . "&strand=neg"
      . "$gUrl'>Protein Recruitment Plot negative strands</a> <p>";

    # ref taxon scaffold form
    # a distinct list of method\tbin_name
    my %distinctList;

    my %stats30;
    my $count30 =
      loadBinSpeciesStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 30, $family,
        \%stats30, \%distinctList );
    my %stats60;
    my $count60 =
      loadBinSpeciesStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 60, $family,
        \%stats60, \%distinctList );
    my %stats90;
    my $count90 =
      loadBinSpeciesStats( $dbh, $taxon_oid, $method_oid, $bin_oid, 90, $family,
        \%stats90, \%distinctList );

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Genus Species</th>\n";
    print "<th class='img' title='30% to 59%' align='right'>"
      . "No. Of Hits 30%</th>\n";
    print "<th class='img' >Histogram 30%</th>\n";
    print "<th class='img' title='60% to 89%' align='right'>"
      . "No. Of Hits 60%</th>\n";
    print "<th class='img' >Histogram 60%</th>\n";
    print "<th class='img'  align='right'>No. Of Hits 90%</th>\n";
    print "<th class='img' >Histogram 90%</th>\n";

    my @methodbins = sort( keys(%distinctList) );
    for my $key (@methodbins) {
        my ( $genus, $species ) = split( /\t/, $key );

        print "<tr class='img' >\n";

        #  url
        my $url = "$main_cgi?section=$section&page=binspecies";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&method_oid=$method_oid";
        $url .= "&bin_oid=$bin_oid";
        $url .= "&family=$family";
        $url .= "&genus=$genus";
        $url .= "&species=$species" if ( $species ne "" );

        print "<td class='img' >\n";
        print "<a href='$url'> $genus $species </a>";
        print "</td>\n";

        if ( exists( $stats30{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats30{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats30{$key} / $count30, 300 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats60{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats60{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats60{$key} / $count60, 200 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        if ( exists( $stats90{$key} ) ) {
            print "<td class='img' >\n";
            print "$stats90{$key}\n";
            print "</td>\n";

            print "<td class='img' align='left'>\n";
            print histogramBar( $stats90{$key} / $count90, 100 );
            print "</td>\n";
        }
        else {
            print "<td class='img' > - </td>\n";

            print "<td class='img' align='left'>\n";
            print "</td>\n";
        }

        print "</tr>\n";
    }

    print "</table>\n";
    printStatusLine( "Loaded.", 2 );

}

# gets bin ref genome taxon oid
#
# param $dbh - database handler
# param others by url
# #return (taxon oid, taxon display name)
# return hash of  $id => $name ) - ref genome taxon id and taxon name
sub getBinRefGenomeTaxonId {
    my ($dbh) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $method_oid = param("method_oid");
    my $bin_oid    = param("bin_oid");
    my $family     = param("family");
    my $genus      = param("genus");
    my $species    = param("species");

    my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my @binds = ( $env_sample, $method_oid, $bin_oid, $taxon_oid );

    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t2.family = ? ";
        push( @binds, $family );
    }
    else {
        $familyClause = "and t2.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t2.species is null";
        }
        else {
            $familyClause .= " and t2.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t2.genus is null";
        }
        else {
            $familyClause .= " and t2.genus = ? ";
            push( @binds, $genus );
        }
    }

    my $sql = qq{
       select t2.taxon_oid, t2.taxon_display_name
       from bin b, bin_method bm, bin_scaffolds bs, gene g,
       dt_phylum_dist_genes dt, gene g2, taxon t2
       where b.env_sample = ?
       and b.bin_method = bm.bin_method_oid
       and b.is_default = 'Yes'
       and bm.bin_method_oid = ?
       and b.bin_oid = ?
       and b.bin_oid = bs.bin_oid
       and g.scaffold = bs.scaffold
       and g.taxon = ?
       and g.taxon = dt.taxon_oid
       and dt.gene_oid = g.gene_oid
       and dt.homolog = g2.gene_oid
       and g2.taxon = t2.taxon_oid
       $familyClause
   };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %taxons;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();

        last if !$taxon_oid;
        $taxons{$taxon_oid} = $taxon_name;
    }

    $cur->finish();

    return \%taxons;
}

#
# prints bin species plot form
#
# param $dbh - database handler
# param others by url
sub printBinSpeciesPlotForm {
    my ($section) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $method_oid = param("method_oid");
    my $bin_oid    = param("bin_oid");
    my $family     = param("family");
    my $genus      = param("genus");
    my $species    = param("species");

    #printMainForm();
    print "<form method=\"post\" action=\"javascript:noop()\" "
      . "onSubmit=\"return false;\" target=\"_self\" name=\"mainForm\"> ";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name  = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    my $method_name = QueryUtil::getMethodName( $dbh, $method_oid );
    my $bin_name    = QueryUtil::getBinName( $dbh, $bin_oid );

    # get ref genome info fixme for
    # duplicate genomes  search for $ref_taxon_id
    my $ref_taxon_href = getBinRefGenomeTaxonId($dbh);

    print "<h2>$taxon_name<br>$method_name $bin_name<br>$family\n";
    print "<br>$genus $species</h2>\n";
    print "<p>\n";

    my $link;
    if ( $section eq 'MetagenomeHits' ) {
        $link = "<a href='main.cgi?section=MetagenomeGraph&page=binscatter";
    }
    else {
        $link = "<a href='main.cgi?section=MetaFileGraph&page=binscatter";
    }

    my $gUrl .= "&taxon_oid=$taxon_oid";
    $gUrl    .= "&family=$family";
    $gUrl    .= "&method_oid=$method_oid";
    $gUrl    .= "&bin_oid=$bin_oid";
    $gUrl .= "&genus=$genus"     if ( $genus   ne "" );
    $gUrl .= "&species=$species" if ( $species ne "" );

    print $link . "&strand=all" . "$gUrl'>Protein Recruitment Plot</a> <br>";
    print $link
      . "&strand=pos"
      . "$gUrl'>Protein Recruitment Plot positive strands</a> <br>";
    print $link
      . "&strand=neg"
      . "$gUrl'>Protein Recruitment Plot negative strands</a> <p>";

    print "Please select reference scaffold(s) to plot against "
      . "(max. $max_scaffold_list selections)<br>";

    # testing code for post window.open()
    print <<EOF;
        <input type='button' name='plot1' value='Run Viewer' 
        onClick='plotBin(\"$main_cgi\")' 
        class='smbutton' />
        &nbsp;
EOF
    if ( $show_mgdist_v2 && $img_internal ) {
        print <<EOF;
        <input type='button' name='plot2' value='Future'  
        onClick='plotBinProtein(\"$main_cgi\")' 
        class='smbutton' />
        &nbsp;

EOF
    }

    # should i only get hit scaffolds too?

    foreach my $key ( keys %$ref_taxon_href ) {
        my $ref_taxon_id = $key;

        print "<p>\n";

        print "<b> " . "$ref_taxon_href->{$key}" . " </b><br>\n";

        printScaffolds( $dbh, $section, $ref_taxon_id );
    }
    MetagJavaScript::printMetagSpeciesPlotJS();

    print hiddenVar( "method_oid", $method_oid );
    print hiddenVar( "bin_oid",    $bin_oid );
    print hiddenVar( "family",     $family );
    print hiddenVar( "taxon_oid",  $taxon_oid );
    print hiddenVar( "genus",      $genus );
    print hiddenVar( "species",    $species );

    #print hiddenVar( "ref_taxon_id", $ref_taxon_id );

    printStatusLine( "Loaded.", 2 );

    #print end_form();
    print "</form>\n";
}

#
# print scaffold info for printSpeciesStatsForm
# this table is similar to es' chrom. viewer table
#
# param $dbh - database handler
# param $taxon_oid - reference genome's taxon oid
#
# see printSpeciesStatsForm
sub printScaffolds {

    my ( $dbh, $section, $taxon_oid, $scaffold_aref, 
        $metag_start_coord, $metag_end_coord, $hitCount_href )
      = @_;

    #webLog("print here iam to save the day =========== \n");
    
    my $taxon_display_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );    
    print "Scaffolds and contigs for ";
    print escHtml($taxon_display_name);
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    ## Est. orfs
    my $sql = qq{
      select ss.scaffold_oid, ss.count_total_gene
      from scaffold_stats ss, gene g
      where g.scaffold = ss.scaffold_oid
      and g.taxon = ?
      and g.obsolete_flag = 'No'
      and ss.taxon = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my %scaffold2NoGenes;
    my %scaffold2Bin;
    my $count = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        $scaffold2NoGenes{$scaffold_oid} = $cnt;
        $scaffold2Bin{$scaffold_oid}     = "";
    }
    $cur->finish();
    if ( $count == 0 ) {
        print "<p>\n";
        print "This scaffold has no genes to view.\n";
        print "</p>\n";
        #$dbh->disconnect();
        return;
    }

    my $sql = qq{
      select scf.scaffold_oid, b.bin_oid, b.display_name
      from scaffold scf, bin_scaffolds bs, bin b
      where bs.scaffold = scf.scaffold_oid
      and b.bin_oid = bs.bin_oid
      and scf.taxon = ?
      and b.is_default = 'Yes'
      and scf.ext_accession is not null
      order by scf.scaffold_oid, b.display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();
    my $scaffoldCount1 = keys(%scaffold2NoGenes);

    #webLog "scaffoldCount0=$scaffoldCount0\n" if $verbose >= 1;
    webLog "scaffoldCount1=$scaffoldCount1\n" if $verbose >= 1;

    my $scaffold_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_aref );

    my @binds = ($taxon_oid);
    my $sql   = qq{
      select distinct s.scaffold_name, ss.seq_length, ss.count_total_gene,
        ss.gc_percent, s.read_depth, s.scaffold_oid, tx.taxon_display_name
      from scaffold s, scaffold_stats ss, taxon tx
      where s.taxon = ?
      and s.taxon = ss.taxon
      and s.scaffold_oid = ss.scaffold_oid
      and s.scaffold_oid in ( $scaffold_str )
      and s.taxon = tx.taxon_oid
      and s.ext_accession is not null
      order by ss.seq_length desc
    };
    my @binds = ($taxon_oid);

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    print "<table class='img'   border='1'>\n";
    print "<th class='subhead'>Select</th>\n";
    print "<th class='subhead'>Scaffold</th>\n";
    print "<th class='subhead'>Length (bp)</th>\n";
    print "<th class='subhead'>GC</th>\n";
    print "<th class='subhead'>Read Depth</th>\n" if $include_metagenomes;
    print "<th class='subhead'>No. Genes</th>\n";
    print "<th class='subhead'>No. Hit Genes</th>\n";

    if ( $metag_start_coord eq "" || $metag_end_coord eq "" ) {
        print "<th class='subhead'>Coordinate Range</th>\n";
    }
    else {
        print "<th class='subhead'>Coordinate Range<sup>4</sup></th>\n";
    }
    my @scaffoldRecs;

    for ( ; ; ) {
        my ( $scaffold_name, $seq_length, $total_gene_count, $gc_percent,
            $read_depth, $scaffold_oid, $taxon_display_name, undef )
          = $cur->fetchrow();
        last if !$scaffold_oid;
        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;
        print "<tr class='img' >\n";

        webLog("sequence length $seq_length\n");

        # check box
        print "<td class='img'>";
        print "<input type='checkbox' name='scaffold$scaffold_oid' "
          . "value='$scaffold_oid' onClick=\"checkSelect2('scaffold$scaffold_oid')\"/>";
        print "</td>\n";

        #$scaffold_name =
        substr( $scaffold_name, length($taxon_display_name) );
        my $scaffold_name2    = WebUtil::getChromosomeName($scaffold_name);
        my $bin_display_names = $scaffold2Bin{$scaffold_oid};
        chop $bin_display_names;
        $scaffold_name2 .= " (bin(s):$bin_display_names)"
          if $bin_display_names ne "";
        my $rec = "$scaffold_oid\t";
        $rec .= "$scaffold_name2\t";
        $rec .= "$seq_length";
        push( @scaffoldRecs, $rec ) if $seq_length > 0;
        print "<td class='img'   valign='top'>"
          . attrLabel($scaffold_name2)
          . "</td>\n";
        print "<td class='img' valign='top' align='right'>${seq_length}</td>\n";
        print "<td class='img' valign='top' align='right'>${gc_percent}</td>\n";
        print "<td class='img' valign='top' align='right'>${read_depth}</td>\n"
          if $include_metagenomes;
        print "<td class='img'  valign='top' align='right'>"
          . $scaffold2NoGenes{$scaffold_oid}
          . "</td>\n";

        # hit genes count
        print "<td class='img'  valign='top' align='right'>"
          . $hitCount_href->{$scaffold_oid}
          . "</td>\n";

        print "<td class='img' >\n";

        # range selection - points to chrom viewers
        if ( $metag_start_coord eq "" || $metag_end_coord eq "" ) {

            # original selection
            if ( $seq_length < $scaffold_page_size ) {
                my $range = "1\.\.$seq_length";
                my $url   =
                  "$main_cgi?section=ScaffoldGraph" . "&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=1&end_coord=$seq_length";
                if ( $seq_length > 0 ) {
                    print alink( $url, $range ) . "<br/>\n";
                }
                else {
                    print nbsp(1);
                }
            }
            else {
                my $last = 1;
                for ( my $i = $scaffold_page_size ; $i < $seq_length ; $i += $scaffold_page_size ) {
                    my $curr  = $i;
                    my $range = "$last\.\.$curr";
                    my $url   =
                      "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                    $url .= "&scaffold_oid=$scaffold_oid";
                    $url .= "&start_coord=$last&end_coord=$curr";
                    $url .= "&seq_length=$seq_length";
                    if ( $seq_length > 0 ) {
                        print alink( $url, $range ) . "<br/>\n";
                    }
                    else {
                        print nbsp(1);
                    }
                    $last = $curr + 1;
                }
                if ( $last < $seq_length ) {
                    my $range = "$last\.\.$seq_length";
                    my $url   =
                      "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                    $url .= "&scaffold_oid=$scaffold_oid";
                    $url .= "&start_coord=$last&end_coord=$seq_length";
                    if ( $seq_length > 0 ) {
                        print alink( $url, $range ) . "<br/>\n";
                    }
                    else {
                        print nbsp(1);
                    }
                }
            }
        }
        else {

            # new a selection box of co-ord to use
            my @scaffolds_array = ($scaffold_oid);
            my ( $scaffold_start, $scaffold_end ) = GraphUtil::getScaffoldMinMax( $dbh, \@scaffolds_array );
            $metag_end_coord = $scaffold_end
              if ( $scaffold_end < $metag_end_coord );
            webLog("final metag s,e $metag_start_coord, $metag_end_coord\n");

            print "<SELECT name='range_select"
              . $scaffold_oid . "' "
              . "onChange='plotRange(\"$main_cgi\", \"$scaffold_oid\")'>\n";

            print "<OPTION value='-' selected='true'>-</option>";

            my $incr = GraphUtil::getMAXRANGE() * GraphUtil::getNUMGRAPHSPERPAGE();
            
            my $i = 1;
            for ( ; ; $i = $i + $incr ) {
                my $tmp = $i + $incr - 1;
                last if ( $tmp > $metag_end_coord );
                print "<OPTION value='$i,$metag_end_coord'>$i .. $tmp</option>";
            }

            # some of the end seletion has no metag genes to show
            # within the given end range, but there are genes
            # further up the coord but not matching on
            # the current scaffold slection
            print "<OPTION value='$i,$metag_end_coord'>"
              . "$i .. $metag_end_coord</option>";
            print "</SELECT>";

        }
        print "</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    printStatusLine( "Loaded.", 2 );
    $cur->finish();
    
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaffold_str =~ /gtt_num_id/i );

}

# scaffold name is not unique - used for form submit
# 2.8
sub printScaffolds2 {
    my ( $dbh, $section, $taxon_oid, $scaffold_aref, 
        $metag_start_coord, $metag_end_coord, $hitCount_href )
      = @_;

    #webLog("print here iam to save the day =========== \n");

    my $taxon_display_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );    
    print "Scaffolds and contigs for ";
    print escHtml($taxon_display_name);
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    ## Est. orfs
    my $sql = qq{
      select ss.scaffold_oid, ss.count_total_gene
      from scaffold_stats ss, gene g
      where g.scaffold = ss.scaffold_oid
      and g.taxon = ?
      and g.obsolete_flag = 'No'
      and ss.taxon = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my %scaffold2NoGenes;
    my %scaffold2Bin;
    my $count = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        $scaffold2NoGenes{$scaffold_oid} = $cnt;
        $scaffold2Bin{$scaffold_oid}     = "";
    }
    $cur->finish();
    if ( $count == 0 ) {
        print "<p>\n";
        print "This scaffold has no genes to view.\n";
        print "</p>\n";
        #$dbh->disconnect();
        return;
    }

    my $sql = qq{
      select scf.scaffold_oid, b.bin_oid, b.display_name
      from scaffold scf, bin_scaffolds bs, bin b
      where bs.scaffold = scf.scaffold_oid
      and b.bin_oid = bs.bin_oid
      and scf.taxon = ?
      and b.is_default = 'Yes'
      and scf.ext_accession is not null
      order by scf.scaffold_oid, b.display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();
    my $scaffoldCount1 = keys(%scaffold2NoGenes);

    #webLog "scaffoldCount0=$scaffoldCount0\n" if $verbose >= 1;
    webLog "scaffoldCount1=$scaffoldCount1\n" if $verbose >= 1;

    my $scaffold_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_aref );

    my $sql   = qq{
      select distinct s.scaffold_name, ss.seq_length, ss.count_total_gene,
        ss.gc_percent, s.read_depth, s.scaffold_oid, tx.taxon_display_name
      from scaffold s, scaffold_stats ss, taxon tx
      where s.taxon = ?
      and s.taxon = ss.taxon
      and s.scaffold_oid = ss.scaffold_oid
      and s.scaffold_oid in ( $scaffold_str )
      and s.taxon = tx.taxon_oid
      and s.ext_accession is not null
      order by ss.seq_length desc
    };
    my @binds = ($taxon_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
    .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
    }
    </style>

        <div class='yui-dt'>
YUI

        $tableAttr = "style='font-size:12px'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='subhead'";
    }
    
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Select";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Scaffold";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Length (bp)";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "GC";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Read Depth";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Genes";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Hit Genes";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    if ( $metag_start_coord eq "" || $metag_end_coord eq "" ) {
        print "Coordinate Range";
    }
    else {
        print "Coordinate Range<sup>4</sup>";
    }
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    my @scaffoldRecs;

    my $idx = 0;
    my $classStr;

    my $rowcnt = 0;
    for ( ; ; ) {
        my ( $scaffold_name, $seq_length, $total_gene_count, $gc_percent,
            $read_depth, $scaffold_oid, $taxon_display_name, undef )
          = $cur->fetchrow();
        last if !$scaffold_oid;

        $rowcnt++;
        if($rowcnt > 20) {
            # TODO limit scaffolds for a genome to top 20 
            last;
        }

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;

        print "<tr class='$classStr' >\n";
        webLog("sequence length $seq_length\n");

        # check box
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "<input type='checkbox' name='ref_scaffold' "
          . "value='$scaffold_oid' />";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # Scaffold Name
        substr( $scaffold_name, length($taxon_display_name) );
        my $scaffold_name2    = WebUtil::getChromosomeName($scaffold_name);
        my $bin_display_names = $scaffold2Bin{$scaffold_oid};
        chop $bin_display_names;
        $scaffold_name2 .= " (bin(s):$bin_display_names)"
          if $bin_display_names ne "";
        my $rec = "$scaffold_oid\t";
        $rec .= "$scaffold_name2\t";
        $rec .= "$seq_length";
        push( @scaffoldRecs, $rec ) if $seq_length > 0;

        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print attrLabel($scaffold_name2);
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # Length (bp)
        print "<td class='$classStr' style='text-align:right'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print ${seq_length};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        #GC Percent
        print "<td class='$classStr' style='text-align:right'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print ${gc_percent};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        if ($include_metagenomes) {
            #Read Depth
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print ${read_depth};
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        # Gene Count
        print "<td class='$classStr' style='text-align:right'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $scaffold2NoGenes{$scaffold_oid};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # Hit Genes Count
        print "<td class='$classStr' style='text-align:right'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $hitCount_href->{$scaffold_oid};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;

        # range selection - points to chrom viewers
        if ( $metag_start_coord eq "" || $metag_end_coord eq "" ) {

            # original selection
            if ( $seq_length < $scaffold_page_size ) {
                my $range = "1\.\.$seq_length";
                my $url   =
                  "$main_cgi?section=ScaffoldGraph" . "&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=1&end_coord=$seq_length";
                if ( $seq_length > 0 ) {
                    print alink( $url, $range ) . "<br/>\n";
                }
                else {
                    print nbsp(1);
                }
            }
            else {
                my $last = 1;
                for ( my $i = $scaffold_page_size ; $i < $seq_length ; $i += $scaffold_page_size ) {
                    my $curr  = $i;
                    my $range = "$last\.\.$curr";
                    my $url   =
                      "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                    $url .= "&scaffold_oid=$scaffold_oid";
                    $url .= "&start_coord=$last&end_coord=$curr";
                    $url .= "&seq_length=$seq_length";
                    if ( $seq_length > 0 ) {
                        print alink( $url, $range ) . "<br/>\n";
                    }
                    else {
                        print nbsp(1);
                    }
                    $last = $curr + 1;
                }
                if ( $last < $seq_length ) {
                    my $range = "$last\.\.$seq_length";
                    my $url   =
                      "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                    $url .= "&scaffold_oid=$scaffold_oid";
                    $url .= "&start_coord=$last&end_coord=$seq_length";
                    if ( $seq_length > 0 ) {
                        print alink( $url, $range ) . "<br/>\n";
                    }
                    else {
                        print nbsp(1);
                    }
                }
            }
        }
        else {

            # new a selection box of co-ord to use
            my @scaffolds_array = ($scaffold_oid);
            my ( $scaffold_start, $scaffold_end ) = GraphUtil::getScaffoldMinMax( $dbh, \@scaffolds_array );
            $metag_end_coord = $scaffold_end
              if ( $scaffold_end < $metag_end_coord );
            webLog("final metag s,e $metag_start_coord, $metag_end_coord\n");

            print "<SELECT name='range_select"
              . $scaffold_oid . "' "
              . "onChange='plotRange2(\"$main_cgi\", \"$scaffold_oid\")'>\n";

            print "<OPTION value='-' selected='true'>-</option>";

            my $incr = GraphUtil::getMAXRANGE() * GraphUtil::getNUMGRAPHSPERPAGE();
            my $i = 1;
            for ( ; ; $i = $i + $incr ) {
                my $tmp = $i + $incr - 1;
                last if ( $tmp > $metag_end_coord );
                print "<OPTION value='$i,$metag_end_coord'>$i .. $tmp</option>";
            }

            # some of the end seletion has no metag genes to show
            # within the given end range, but there are genes
            # further up the coord but not matching on
            # the current scaffold slection
            print "<OPTION value='$i,$metag_end_coord'>"
              . "$i .. $metag_end_coord</option>";
            print "</SELECT>";

        }
        print "</td>\n";
        print "</div>\n" if $yui_tables;
        print "</tr>\n";
        $idx++;
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    # TODO size issues
    if ($rowcnt > 20) {
        print qq{
            <br/>
            <font color='red' size=-1>
            There were too many scaffolds to display above, limited to top 20 largest scaffolds.
            </font>
            <br/>
        };
    }
        
    printStatusLine( "Loaded.", 2 );
    $cur->finish();
    
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaffold_str =~ /gtt_num_id/i );
}

# prints query scaffold, but use the sacffold cart names
# cart names - only show the ones that have the query scaffold oids
#
# links to select sacffolds main.cgi?section=TaxonDetail&page=scaffolds&taxon_oid=2001200000
# scaffold cart main.cgi?section=ScaffoldCart&page=index
sub printQueryScaffolds {
    my ( $dbh, $taxon_oid, $domain, $phylum, $ir_class, $family, $genus,
        $species )
      = @_;

    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    my $scnt = QueryUtil::getScaffoldCount( $dbh, $taxon_oid );

    print qq{
      <p>
      <dl>
      <dt>
      <b>Query Genome Scaffold Selection</b>
      </dt>
      </dl>
      <font size=-1>
      Advanced option.<br/> 
      Use the <a href='main.cgi?section=ScaffoldCart&page=index'> Scaffold Cart </a>
      to select query genomes scaffolds. Query genome has 
      <a href='main.cgi?section=TaxonDetail&page=scaffolds&taxon_oid=$taxon_oid'> $scnt scaffolds </a>
      </font>
      </p> 
    };

    # cart names => scaffold oids
    my $cartnames_href = ScaffoldCart::getCartNamesWithSoids();
    $cartnames_href = validateCartSoidsInCart( $dbh, $taxon_oid, $isTaxonInFile, $cartnames_href );
    my $all_soid_cart_aref = ScaffoldCart::getAllScaffoldOids();

    #
    # need to get query scaffold oids
    #
    # display only cart names with query genome's scaffolds

    print qq{
        <p>
        <select name='query_scaffold_name' >
        <option value='all' selected='selected'> All Query Genome Scaffolds (recommended ) </option>    
    };

    my $size  = $#$all_soid_cart_aref + 1;
    my $size2 = keys %$cartnames_href;
    if ( $size > 0 && $size2 < 1 ) {
        # lets assume user has not name any scaffold in scaffold cart
        $all_soid_cart_aref = validateCartSoids( $dbh, $taxon_oid, $isTaxonInFile, $all_soid_cart_aref );

        $size = $#$all_soid_cart_aref + 1;
    }

    if ( $size > 0 || $size2 > 0 ) {
        print qq{
            <option value='all_cart'> All Scaffold Cart's Applicable Scaffolds </option>
        };
    }

    #foreach my $key ( keys %$cartnames_href ) {
    #    print qq{
    #        <option value='$key'> $key </option>
    #    };
    #}
    print qq{
        </select>
        </p>
    };
}

#
# prints form to select which ref genome's scaffold to plot against
#
# param $dbh - database handler
# other params from url
#
# see getRefGenomeTaxonId
# see MetagJavaScript::printMetagSpeciesPlotJS()
# see printScaffolds
#
sub printSpeciesStatsForm {
    my ($section) = @_;

    my $taxon_oid = param("taxon_oid");
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $genus     = param("genus");
    my $species   = param("species");

    printMainForm();

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>Plots</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    if ($include_metagenomes) {
        print "<p>\n";
        print "<dl>\n";
        print "<b>Protein Recruitment Plot</b>\n";
        print "</dl>\n";
        if ( $section eq 'MetagenomeHits' ) {
            printRecruitmentSelection( $taxon_oid, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        } else {
            printFileRecruitmentSelection( $taxon_oid, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        }        
    }

    # print query genome scaffolds selection
    printQueryScaffolds( $dbh, $taxon_oid, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    # ref genomes selection
    print "<p>\n";
    print "<dl>\n";
    print "<dt><b>Reference Genome Context View</b></dt>\n";
    print "</dl>\n";

    print "<font size=-1>\n";
    print "Please select reference scaffold(s) to plot against "
      . "(max. $max_scaffold_list selections)<br>";
    print "</font></p>\n";

    my $scaffolds_aref = getHitRefScaffolds( $dbh, $taxon_oid, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    my ( $min, $max ) = GraphUtil::getPhylumGenePercentInfoMinMax( $dbh, 
         $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, "" );    
    webLog("metag genes min, max = $min, $max\n");

    my $hitCount_href = getRefGenomeHitCount( $dbh, $taxon_oid, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    my $ref_taxon_href = getRefGenomeTaxonId( $dbh, $taxon_oid, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

   my $count = 0;
   foreach my $key ( keys %$ref_taxon_href ) {
        my $ref_taxon_id = $key;

        print "<p>\n";

        print "<b> " . "$ref_taxon_href->{$key}" . " </b><br>\n";

        printScaffolds2( $dbh, $section, $ref_taxon_id, $scaffolds_aref, $min, $max,
            $hitCount_href );

        $count++;        
        # TODO limit size
        if ( $count > 20 ) {
            print qq{ 
                <font color='red' size=-1>
                Too many ref. genomes to display max. limit of 20 <br/>
                </font>
            };
            last;
        }

    }

    print qq{
        <p>
        <font size=1>
        4 - View query genome against a reference genome within selected range
        </font>        
        </p>
    };

    MetagJavaScript::printMetagSpeciesPlotJS();

    # print buttons
    # printSpeciesFormButtons();

    # test button
    #    print submit(
    #        -name  => "_section_MetaFileGraph_fragRecView1",
    #        -value => "Run Viewer 2 test",
    #        -class => "meddefbutton"
    #    );

    if ( $section eq 'MetagenomeHits' ) {
        print qq{
            <input type="button" 
            name="_section_MetagenomeGraph_fragRecView1" 
            value="Run Viewer" 
            class="meddefbutton"
            onClick='mySubmit()' />
        };
    }
    else {
        print qq{
            <input type="button" 
            name="_section_MetaFileGraph_fragRecView1" 
            value="Run Viewer" 
            class="meddefbutton"
            onClick='mySubmit()' />
        };
    }        

    print "<input type='checkbox' name='hitgene' value='true'/> "
      . "<font size=-1>Show only hit reference genes on viewer</font>";

    printStatusLine( "Loaded.", 2 );

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "domain",    $domain );
    print hiddenVar( "phylum",    $phylum );
    print hiddenVar( "ir_class",  $ir_class );
    print hiddenVar( "ir_order",  $ir_order );
    print hiddenVar( "family",    $family );
    print hiddenVar( "genus",     $genus );
    print hiddenVar( "species",   $species );
    if ( $section eq 'MetagenomeHits' ) {
        print hiddenVar( "section",   "MetagenomeGraph" );
    }
    else {
        print hiddenVar( "section",   "MetaFileGraph" );
    }        
    print hiddenVar( "page",      "fragRecView1" );
    print hiddenVar( "min",       "" );
    print hiddenVar( "max",       "" );
    print hiddenVar( "scaffolds", "" );                # for js combo box

    # run button I need to clear the js scaffolds value
    print qq{
        <script>
        function mySubmit() {
            document.mainForm.min.value = "";
            document.mainForm.max.value = ""; 
            document.mainForm.scaffolds.value = "";              
            document.mainForm.submit();
        }
        </script>
    };

    print end_form();
}

#
# Gets list ref scaffold oids that hit the metag
#
sub getHitRefScaffolds {
    my ( $dbh, $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my @binds = ( $taxon_oid );

    my ($taxonomyClause, $binds_t_clause_ref) = getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );

    my $sql = qq{
        select distinct g2.scaffold 
        from dt_phylum_dist_genes dt, gene g2, taxon t
        where dt.taxon_oid = ?
        and dt.homolog = g2.gene_oid
        and dt.homolog_taxon = t.taxon_oid
        and g2.taxon = t.taxon_oid
        $taxonomyClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @list;
    for ( ; ; ) {
        my ($ref_scaffold_oid) = $cur->fetchrow();
        last if !$ref_scaffold_oid;
        push( @list, $ref_scaffold_oid );
    }
    $cur->finish();
    return \@list;
}

sub getRefGenomeHitCount {
    my ( $dbh, $taxon_oid, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
      = @_;

    my @binds = ( $taxon_oid );

    my ($taxonomyClause, $binds_t_clause_ref) = getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );

    my $sql = qq{
        select g.scaffold, count( g.gene_oid)
        from taxon t, gene g
        where g.taxon = t.taxon_oid
        and g.gene_oid in ( 
            select  dt.homolog
            from dt_phylum_dist_genes dt
            where dt.taxon_oid = ?
        )
        $taxonomyClause
        group by g.scaffold  
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my %hash;    # scaffold oid => hit count - genes matching on ref genome
    for ( ; ; ) {
        my ( $sid, $count ) = $cur->fetchrow();
        last if !$sid;
        $hash{$sid} = $count;
    }

    $cur->finish();
    return \%hash;
}

#
# gets ref genome given the metag's taxon oid
#
# param $dbh database handler
# param $metag_taxon metag taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
#
# return hash of  $id => $name ) - ref genome taxon id and taxon name
#
sub getRefGenomeTaxonId {
    my ( $dbh, $metag_taxon, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
      = @_;

    my @binds = ( $metag_taxon );

    my ($taxonomyClause, $binds_t_clause_ref) = getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );

    # ref genome is the taxon oid from the homolog
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select distinct t.taxon_oid, t.taxon_display_name
        from dt_phylum_dist_genes dt, gene g, taxon t
        where dt.homolog = g.gene_oid
        and g.taxon = t.taxon_oid
        and dt.taxon_oid = ?
        $taxonomyClause
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my %taxons;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();

        last if !$taxon_oid;
        $taxons{$taxon_oid} = $taxon_name;
    }

    $cur->finish();

    return \%taxons;
}


############################################################################
# printRecruitmentSelection
# Todo: merge with printFileRecruitmentSelection
############################################################################
sub printRecruitmentSelection {
    my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $plot_base_url = 'main.cgi?section=MetagenomeGraph&page=fragRecView3&';

    # no species and genome info
    my $gUrl .= "&taxon_oid=$taxon_oid";
    $gUrl    .= "&domain=" . WebUtil::massageToUrl2($domain);
    $gUrl    .= "&phylum=" . WebUtil::massageToUrl2($phylum);
    $gUrl .= "&ir_class=" . WebUtil::massageToUrl2($ir_class) if ( $ir_class );
    $gUrl .= "&ir_order=" . WebUtil::massageToUrl2($ir_order) if ( $ir_order );
    $gUrl .= "&family=" . WebUtil::massageToUrl2($family)     if ( $family );
    $gUrl .= "&genus=" . WebUtil::massageToUrl2($genus)       if ( $genus );
    $gUrl .= "&species=" . WebUtil::massageToUrl2($species)   if ( $species );

    #$gUrl = WebUtil::massageToUrl2($gUrl);

    # TODO build the url
    my $recplot_url = $env->{recplot_url};
    my $recplot_url = "http://img-edge1.jgi-psf.org:8080/imgrecplot/imgrecplot/StartView.html?strand=all" . $gUrl;
    my $geneUrl     = WebUtil::massageToUrl2("$cgi_url/main.cgi?section=GeneDetail&page=geneDetail&gene_oid=");
    $recplot_url .= "&geneUrl=$geneUrl";

    #&taxon_oid=2001200000&domain=Archaea&phylum=Euryarchaeota&family=Ferroplasmaceae";
    # http://networking.mydesigntool.com/viewtopic.php?tid=312&id=31
    if ($img_internal) {
        print qq{
       <p> 
        <input class='smbutton' type='button' value='View Plot (Beta)'
        onClick="javascript:window.open('$recplot_url','popup',
        'width=800,height=800,scrollbars=yes,status=yes,resizable=yes, toolbar=yes'); 
        window.focus();" 
        /> &nbsp; NEW Beta Viewer. (It will open in pop-up window)
        </p>
        };
    }

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
    .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
    }
    </style>

        <div class='yui-dt'>
YUI
        $tableAttr = "style='font-size:12px;'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    print "<table $tableAttr>\n";
    print "<th $thAttr id='anchor'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Percent Identity Plot For";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Plots with Tooltips<sup>1</sup>";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    print "<th $thAttr>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Plots without Tooltips<sup>1</sup>";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    my @idPlot = (
                   { 'type' => 'all', 'desc' => 'All Scaffolds' },
                   { 'type' => 'pos', 'desc' => 'All Positive Strands' },
                   { 'type' => 'neg', 'desc' => 'All Negative Strands' },
    );

    my $idx = 0;
    my $classStr;

    for my $line (@idPlot) {

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        # Percent Identity Plot For
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $line->{'desc'};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # Plots with Tooltips
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print qq{ <a href='${plot_base_url}strand=$line->{'type'}$gUrl'>
          Normal</a> &nbsp;&nbsp;
          <a href='${plot_base_url}strand=$line->{'type'}&size=large$gUrl'>
              Larger<sup>2</sup></a>
    };
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # Plots without Tooltips
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print qq{ <a href='${plot_base_url}strand=$line->{'type'}&tooltip=false$gUrl'>
          Normal </a> &nbsp;&nbsp;
          <a href='${plot_base_url}strand=$line->{'type'}&size=large&tooltip=false$gUrl'>
          Larger<sup>2</sup> </a>
    };
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";

        $idx++;
    }

    print "</table>\n";
    print "</div>\n" if $yui_tables;

    print "<p>\n";
    print "<font size=1>\n";
    print " 1 - Plots with tool tips require min. 128 MBytes of free RAM";
    print "<br>\n";
    print " 2 - Larger plots (4096x2048) require min. of 256 MBytes of free RAM";
    print "<br>\n";
    print " 3 - Plots excluding tooltips require less memory";
    print "</font>\n";
}

############################################################################
# printFileRecruitmentSelection
# Todo: merge with printRecruitmentSelection
############################################################################
sub printFileRecruitmentSelection {
    my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
      @_;

    # no species and genome info
    my $gUrl .= "&taxon_oid=$taxon_oid";
    $gUrl    .= "&domain=$domain";
    $gUrl    .= "&phylum=$phylum";
    $gUrl .= "&ir_class=$ir_class" if ( $ir_class );
    $gUrl .= "&ir_order=$ir_order" if ( $ir_order );
    $gUrl .= "&family=$family"     if ( $family );
    $gUrl .= "&genus=$genus"       if ( $genus );
    $gUrl .= "&species=$species"   if ( $species );

    $gUrl = escapeHTML($gUrl);

    # Use YUI css
    my $tableAttr;
    my $thAttr;

        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
    .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
    }
    </style>

        <div class='yui-dt'>
YUI
        $tableAttr = "style='font-size:12px;'";
        $thAttr    = "";

    print "<table $tableAttr>\n";
    print "<th $thAttr id='anchor'>\n";
    print "<div class='yui-dt-liner'><span>";
    print "Percent Identity Plot For";
    print "</span></div>\n";
    print "</th>\n";

    print "<th $thAttr>\n";
    print "<div class='yui-dt-liner'><span>";
    print "Plots with Tooltips<sup>1</sup>";
    print "</span></div>\n";
    print "</th>\n";

    print "<th $thAttr>\n";
    print "<div class='yui-dt-liner'><span>";
    print "Plots without Tooltips<sup>1</sup>";
    print "</span></div>\n";
    print "</th>\n";

    my @idPlot = (
        { 'type' => 'all', 'desc' => 'All Scaffolds' },
        { 'type' => 'pos', 'desc' => 'All Positive Strands' },
        { 'type' => 'neg', 'desc' => 'All Negative Strands' },
    );

    my $idx = 0;
    my $classStr;

    for my $line (@idPlot) {
    $classStr = !$idx ? "yui-dt-first " : "";
    $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";

        # Percent Identity Plot For
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>";
        print $line->{'desc'};
        print "</div>\n";
        print "</td>\n";

        # Plots with Tooltips
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>";
        print
qq{ <a href='main.cgi?section=MetaFileGraph&page=fragRecView3&strand=$line->{'type'}$gUrl'>
          Normal</a> &nbsp;&nbsp;
          <a href='main.cgi?section=MetaFileGraph&page=fragRecView3&strand=$line->{'type'}&size=large$gUrl'>
              Larger<sup>2</sup></a>
    };
        print "</div>\n";
        print "</td>\n";

        # Plots without Tooltips
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>";
        print
qq{ <a href='main.cgi?section=MetaFileGraph&page=fragRecView3&strand=$line->{'type'}&tooltip=false$gUrl'>
          Normal </a> &nbsp;&nbsp;
          <a href='main.cgi?section=MetaFileGraph&page=fragRecView3&strand=$line->{'type'}&size=large&tooltip=false$gUrl'>
          Larger<sup>2</sup> </a>
    };
        print "</div>\n";
        print "</td>\n";
        print "</tr>\n";

        $idx++;
    }

    print "</table>\n";
    print "</div>\n";

    print "<p>\n";
    print "<font size=1>\n";
    print " 1 - Plots with tool tips require min. 128 MBytes of free RAM";
    print "<br>\n";
    print
      " 2 - Larger plots (4096x2048) require min. of 256 MBytes of free RAM";
    print "<br>\n";
    print " 3 - Plots excluding tooltips require less memory";
    print "</font>\n";
}

#
#
# Gets a hash list cog id to function(s) - a cog can have more than one
# function
#
# param $dbh database handler
# param $gene_oids_ref array list of gene oids
# param $hash_ref return data hash cog id => to array of func names, last item
#               is the cog's gene count
#
sub getCogGeneFunction {
    my ( $dbh, $gene_oids_ref, $hash_ref ) = @_;

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }

    my $str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
        select distinct cfs.cog_id, cf.definition
        from cog_function cf, cog_functions cfs, gene_cog_groups gcg
        where cf.function_code = cfs.functions
        and cfs.cog_id = gcg.cog
        and gcg.gene_oid in ($str)
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $cog_id, $defn ) = $cur->fetchrow();
        last if !$cog_id;

        if ( exists( $hash_ref->{$cog_id} ) ) {
            my $aref = $hash_ref->{$cog_id};

            # check for duplicates
            my $found = 0;
            foreach my $x (@$aref) {
                if ( $x eq $defn ) {
                    $found = 1;
                    last;
                }
            }
            if ( $found == 0 ) {
                unshift( @$aref, $defn );
            }
        } else {
            my @tmp;
            unshift( @tmp, $defn );
            $hash_ref->{$cog_id} = \@tmp;
        }
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );

    # now get the cog to gene count information
    getCogGeneCount( $dbh, $hash_ref );
}


#
# Gets cog gene counts
#
# param $dbh database handler
# param $hash_ref return data hash cog id => array list of cog funcs with count
#               at the end of the list
#
sub getCogGeneCount {
    my ( $dbh, $hash_ref ) = @_;

    my @idlist;
    foreach my $key ( keys %$hash_ref ) {
        push( @idlist, $key );
    }

    if ( $#idlist < 0 ) {
        return;
    }

    my $str = OracleUtil::getFuncIdsInClause( $dbh, @idlist );

    my $sql = qq{
        select gcg.cog, count(*)
        from gene_cog_groups gcg
        where gcg.cog in ( $str )
        group by gcg.cog 
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $cogid, $cnt ) = $cur->fetchrow();
        last if !$cogid;
        my $tmp = $hash_ref->{$cogid};
        next if !defined($tmp);

        # do not add gene count if it exists
        if ( $cnt ne $tmp->[$#$tmp] ) {
            push( @$tmp, $cnt );
        }

    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $str =~ /gtt_func_id/i );
}

#
# Gets list of gene oids => array list of cog pathway name(s)
#
# param $dbh database handler
# param $gene_oids_ref array list of gene oids
# param $hash_ref return data hash gene oid => array list cog pathway name(s)
#
sub getCogGenePathway {
    my ( $dbh, $gene_oids_ref, $hash_ref ) = @_;

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }

    my $str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
        select cp.cog_pathway_name, gcg.gene_oid
        from gene_cog_groups gcg, cog c, cog_functions cf, cog_pathway cp
        where gcg.gene_oid in ($str)
        and gcg.cog = c.cog_id 
        and c.cog_id = cf.cog_id
        and cf.functions = cp.function
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $name, $gid ) = $cur->fetchrow();
        last if !$gid;
        if ( exists( $hash_ref->{$gid} ) ) {
            my $aref = $hash_ref->{$gid};
            push( @$aref, $name );
        } else {
            my @tmp;
            push( @tmp, $name );
            $hash_ref->{$gid} = \@tmp;
        }
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );
}

#
# Use to sort data by cog name
#
# param $cogid cog id
# param $globalhashref hash cog id => to array of records
#
# return lc cog name or "zzz\t$cogid" if not found
#
sub cogname {
    my ( $cogid, $globalhashref ) = @_;

    my $array_ref = $globalhashref->{$cogid};
    if ( defined($array_ref) ) {
        return lc( $array_ref->[0] );
    } else {
        return "zzz\t$cogid";
    }
}

#
# Use to sort data by cog gene count
#
# param $cogid cog id
# param $globalhashref hash cog id => to array of records, count is last item
#
# return cog  gene count or 0 if not found
#
sub cogGeneCountSort {
    my ( $cogid, $globalhashref ) = @_;

    my $array_ref = $globalhashref->{$cogid};
    if ( defined($array_ref) ) {
        return $array_ref->[$#$array_ref];
    } else {
        return 0;
    }
}

#
# Use by sort data by cog func, or cog func's separated by comma
# "" if not found
#
# param $cogid cog id
# param $globalhashref hash cog id => to array of records
#
# return cog function name or "" if not found
#
sub cogfunc {
    my ( $cogid, $globalhashref ) = @_;

    my $array_ref = $globalhashref->{$cogid};
    if ( defined($array_ref) ) {

        # copy the real array
        my @tmp = @$array_ref;

        # remove the gene count
        pop(@tmp);
        @tmp = sort { lc($a) cmp lc($b) } @tmp;
        my $str = join( ", ", @tmp );
        return $str;
    }
    else {
        return "";
    }
}

#
# Gets the cog gene count
#
# param $cogid cog id
# param $globalhashref hash cog id => to array of records
#
# returns 0 if not there
#
sub coggenecount {
    my ( $cogid, $globalhashref ) = @_;

    my $array_ref = $globalhashref->{$cogid};
    if ( defined($array_ref) ) {
        return $array_ref->[$#$array_ref];
    } else {
        return 0;
    }
}

#
# used to sort list by cog patways percentage
#
# param $gid gene oid
# param $recs_ref main data records
#
# return percent
#
# see flushGeneBatch4 and flushGeneBatch3
#
sub cogPathSort {
    my ( $gid, $recs_ref ) = @_;

    my $rec_ref = getRecInfo( $recs_ref, $gid );

    my (
         $gene_oid,   $percent,       $gene_name,  $gene_symbol, $locus_type, $taxon_oid,
         $taxon_id,   $abbr_name,     $genus,      $species,     $aa_seq_length,
         $seq_status, $ext_accession, $seq_length, $cog_id
      )
      = @$rec_ref;

    return $percent;
}

#
# given a sort list by cog func
# count how many there are in each group
#
# param $recs_ref array of arrays
# param $hash_cog_func_ref hash of recs, cog id => array of funcs + gene count
#
# return ref hash of cog func name to array list of gene oids
#
sub cogFuncCheckBoxCount {
    my ( $recs_ref, $hash_cog_func_ref ) = @_;

    # hash of cog name => count
    my %cog_counts;

    foreach my $r (@$recs_ref) {
        my (
            $gene_oid,   $percent,       $gene_name,  $gene_symbol,
            $locus_type, $taxon_oid,     $taxon_id,   $abbr_name,
            $genus,      $species,       $aa_seq_length,
            $seq_status, $ext_accession, $seq_length, $cog_id
          )
          = @$r;

        my $aref = $hash_cog_func_ref->{$cog_id};

        # cog function
        if ( defined($aref) && $aref ne "" ) {
            my @atmp = @$aref;
            pop @atmp;    # remove gene count
            foreach my $name (@atmp) {
                if ( exists $cog_counts{$name} ) {
                    my $tmp = $cog_counts{$name};
                    push( @$tmp, $gene_oid );
                }
                else {
                    my @tmp;
                    push( @tmp, $gene_oid );
                    $cog_counts{$name} = \@tmp;
                }
            }
        }
        else {

            # unknown
            if ( exists $cog_counts{$zzzUnknown} ) {
                my $tmp = $cog_counts{$zzzUnknown};
                push( @$tmp, $gene_oid );
            }
            else {
                my @tmp;
                push( @tmp, $gene_oid );
                $cog_counts{$zzzUnknown} = \@tmp;
            }
        }

    }

    return \%cog_counts;
}

#
# find list of gene oids for each pathway name
#
#
# param $recs_ref array of arrays
# param $hash_cog_func_ref hash of recs, gene id to array list cog pathway names
#
# return ref hash of cog pathway name to array list of gene oids
#
sub cogPathCheckBoxCount {
    my ( $recs_ref, $hash_cog_path_ref ) = @_;

    # hash of cog pathway name => count
    my %cog_counts;

    foreach my $r (@$recs_ref) {
        my (
            $gene_oid,   $percent,       $gene_name,  $gene_symbol,
            $locus_type, $taxon_oid,     $taxon_id,   $abbr_name,
            $genus,      $species,       $aa_seq_length,
            $seq_status, $ext_accession, $seq_length, $cog_id
          )
          = @$r;

        # path names for this gene oid
        my $aref = $hash_cog_path_ref->{$gene_oid};

        # cog pathways
        if ( defined($aref) && $aref ne "" ) {
            foreach my $name (@$aref) {
                if ( exists $cog_counts{$name} ) {
                    my $tmp = $cog_counts{$name};
                    push( @$tmp, $gene_oid );
                }
                else {
                    my @tmp;
                    push( @tmp, $gene_oid );
                    $cog_counts{$name} = \@tmp;
                }
            }
        }
        else {

            # unknown
            if ( exists $cog_counts{$zzzUnknown} ) {
                my $tmp = $cog_counts{$zzzUnknown};
                push( @$tmp, $gene_oid );
            }
            else {
                my @tmp;
                push( @tmp, $gene_oid );
                $cog_counts{$zzzUnknown} = \@tmp;
            }
        }
    }

    return \%cog_counts;
}

#
# get a distinct list of cog pathway names
#
# param $hash_cog_path_ref hash ref of gene oid to array list of pathways name
#
# return array list ref
#
sub getPathwayList {
    my ($hash_cog_path_ref) = @_;

    my %pnames;

    foreach my $key ( keys %$hash_cog_path_ref ) {
        my $aref = $hash_cog_path_ref->{$key};
        foreach my $name (@$aref) {
            $pnames{$name} = '';
        }
    }

    my @list;

    foreach my $key ( keys %pnames ) {
        push( @list, $key );
    }

    return \@list;
}

#
# given a list of gene oids, find all the pathway names using cached data
#
# param $gene_list_aref list of gene oids
# param $hash_cog_path_ref hash ref of gene oid to array list of pathways name
#
# return ref to array list of pathway names
#
sub getGenePathwayList {
    my ( $gene_list_aref, $hash_cog_path_ref ) = @_;

    my %pnames;

    foreach my $gid (@$gene_list_aref) {
        my $aref = $hash_cog_path_ref->{$gid};
        $pnames{$gid} = $aref;
    }

    return \%pnames;
}

# get a distinct list of cog function names
#
# param $hash_cog_func_ref hash ref of cog oid to arrray list of fnames
#               and gene count
#
# return array list ref of cog function names
#
sub getCogFunctionList {
    my ($hash_cog_func_ref) = @_;

    my %fnames;

    foreach my $key ( keys %$hash_cog_func_ref ) {
        my $aref = $hash_cog_func_ref->{$key};
        my @tmp  = @$aref;

        # remove the gene count
        pop(@tmp);
        foreach my $name (@tmp) {
            $fnames{$name} = '';
        }
    }

    my @list;

    foreach my $key ( keys %fnames ) {
        push( @list, $key );
    }

    return \@list;
}

#
# Gets gene rec info
#
# param $recs_ref array or array of record
# param $goid gene oid
#
# return array ref to record info or "" if not found
#
sub getRecInfo {
    my ( $recs_ref, $goid ) = @_;

    foreach my $r (@$recs_ref) {
        my (
            $gene_oid,   $percent,       $gene_name,  $gene_symbol,
            $locus_type, $taxon_oid,     $taxon_id,   $abbr_name,
            $genus,      $species,       $aa_seq_length,
            $seq_status, $ext_accession, $seq_length, $cog_id
          )
          = @$r;
        if ( $goid eq $gene_oid ) {
            return $r;
        }
    }
    return "";
}

# validate scaffold oids in cart - make sure those ids belong to
# the query genome
# return new hash cart name with valid names with correct scaffolds.
sub validateCartSoidsInCart {
    my ( $dbh, $taxon_oid, $isTaxonInFile, $cartnames_href ) = @_;

    my %good_hash;
    foreach my $key ( keys %$cartnames_href ) {
        my $soids_aref = $cartnames_href->{$key};
        #my $size      = $#$soids_aref + 1;
        my @a = validateCartSoids( $dbh, $taxon_oid, $isTaxonInFile, $soids_aref );
        # this cart name has some query genome scaffolds
        if ( $#a > -1 ) {
            $good_hash{$key} = \@a;
        }

    }

    return \%good_hash;
}

# validate list of scaffold oids
# return the an aref list of good soids
sub validateCartSoids {
    my ( $dbh, $taxon_oid, $isTaxonInFile, $soids_aref ) = @_;

    my @good;

    my ( $dbOids_ref, $metaOids_ref ) =
      MerFsUtil::splitDbAndMetaOids(@$soids_aref);

    if ( !$isTaxonInFile && scalar(@$dbOids_ref) > 0 ) {
        my $rclause   = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $str = OracleUtil::getNumberIdsInClause( $dbh, @$dbOids_ref );        
        my $sql = qq{
            select s.scaffold_oid
            from scaffold s
            where s.taxon = ?
            and s.scaffold_oid in ($str)
            $rclause
            $imgClause
        };
            
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ($id) = $cur->fetchrow();
            last if !$id;
            push( @good, $id );
        }
    
        # clean up temp tables
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $str =~ /gtt_num_id/i );
    }

    if ( $isTaxonInFile && scalar(@$metaOids_ref) > 0 ) {
        for my $mOid (@$metaOids_ref) {
            my ( $t_oid, $data_type, $scaffold_oid ) = split( / /, $mOid );
            if ( $taxon_oid == $t_oid ) {
                push( @good, $mOid );                    
            }
        }
    }

    return \@good;
}

#
# Given a data file cache the results
# return tmp file name
#
# param $recs_ref array of arrays
# param $hash_cog_func_ref hash of arrays
# param $hash_cog_pathway_ref hash of gene oid to cog pathway names
# return cache file names ( $cacheFile1, $cacheFile2, $cacheFile3, $cacheFile4 )
# 1 - main recs
# 2 - cog func
# 3 - enyzme
# 4 - gene to cog pathways
# see readCacheData
#
sub cacheData {
    my ( $recs_ref, $hash_cog_func_ref, $hash_cog_pathway_ref ) = @_;

    my @recs = @$recs_ref;

    #
    # CACHE data to tmp file with name abundanceResults<process id>
    #
    my $cacheFile1 = "metagenomhits1$$";
    my $cacheFile2 = "metagenomhits2$$";
    my $cacheFile4 = "metagenomhits4$$";

    # file 1
    my $cachePath = "$cgi_tmp_dir/$cacheFile1";

    #webLog("==== $cachePath\n");
    my $res = newWriteFileHandle( $cachePath, "runJob" );

    foreach my $r (@recs) {
        my (
            $gene_oid,   $percent,       $gene_name,  $gene_symbol,
            $locus_type, $taxon_oid,     $taxon_id,   $abbr_name,
            $genus,      $species,       $aa_seq_length,
            $seq_status, $ext_accession, $seq_length, $cog_id,
            $copies
          )
          = @$r;
        print $res $gene_oid;
        print $res "\t";
        print $res $percent;
        print $res "\t";
        print $res $gene_name;
        print $res "\t";
        print $res $gene_symbol;
        print $res "\t";
        print $res $locus_type;
        print $res "\t";
        print $res $taxon_oid;
        print $res "\t";
        print $res $taxon_id;
        print $res "\t";
        print $res $abbr_name;
        print $res "\t";
        print $res $genus;
        print $res "\t";
        print $res $species;
        print $res "\t";
        print $res $aa_seq_length;
        print $res "\t";
        print $res $seq_status;
        print $res "\t";
        print $res $ext_accession;
        print $res "\t";
        print $res $seq_length;
        print $res "\t";
        print $res $cog_id;
        print $res "\t";
        print $res $copies;
        print $res "\n";
    }
    close $res;

    # file 2 - cog func
    $cachePath = "$cgi_tmp_dir/$cacheFile2";

    #webLog("==== $cachePath\n");
    $res = newWriteFileHandle( $cachePath, "runJob" );
    foreach my $key ( keys %$hash_cog_func_ref ) {
        my $aref = $hash_cog_func_ref->{$key};

        print $res $key;
        print $res "\t";

        foreach my $x (@$aref) {
            print $res $x;
            print $res "\t";
        }

        # the read cache chomp will remove \t\n chars at the end

        print $res "\n";
    }
    close $res;

    # file 4 - cog pathway
    $cachePath = "$cgi_tmp_dir/$cacheFile4";

    #webLog("==== $cachePath\n");
    $res = newWriteFileHandle( $cachePath, "runJob" );
    foreach my $key ( keys %$hash_cog_pathway_ref ) {
        print $res $key;
        print $res "\t";
        my $aref = $hash_cog_pathway_ref->{$key};
        foreach my $pname (@$aref) {
            print $res "$pname\t";
        }
        print $res "\n";
    }
    close $res;

    return ( $cacheFile1, $cacheFile2, $cacheFile4 );
}

#
# given cached data files, read them and restore the data models
#
# param $cacheFile1 main data recs
# param $cacheFile2 cog func
# param $cacheFile3 enzyme
# param $cacheFile4 gene oid to cog pathways
# return data models ( \@recs, \%hash_cog_func, \%hash_cog_path)
# see cacheData
#
sub readCacheData {
    my ( $cacheFile1, $cacheFile2, $cacheFile4 ) = @_;
    my @recs;
    my %hash_cog_func;
    my %hash_cog_path;

    $cacheFile1 = WebUtil::checkFileName($cacheFile1);
    $cacheFile2 = WebUtil::checkFileName($cacheFile2);
    $cacheFile4 = WebUtil::checkFileName($cacheFile4);

    # file 1
    my $cachePath = "$cgi_tmp_dir/$cacheFile1";
    my $res       = newReadFileHandle( $cachePath, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        my @tmp = split( /\t/, $line );
        push( @recs, \@tmp );
    }
    close $res;

    # file 2 - cog functions
    $cachePath = "$cgi_tmp_dir/$cacheFile2";
    $res = newReadFileHandle( $cachePath, "runJob" );
    while ( my $line = $res->getline() ) {
        chomp $line;
        my @tmp   = split( /\t/, $line );
        my $cogid = $tmp[0];

        # remove 1st element which is the key
        shift(@tmp);
        $hash_cog_func{$cogid} = \@tmp;
    }

    close $res;

    # file 4 - pathway
    $cachePath = "$cgi_tmp_dir/$cacheFile4";
    $res = newReadFileHandle( $cachePath, "runJob" );
    while ( my $line = $res->getline() ) {
        chomp $line;
        my @tmp = split( /\t/, $line );
        my $key = $tmp[0];

        # remove 1st element which is the key
        shift(@tmp);
        $hash_cog_path{$key} = \@tmp;
    }
    close $res;

    return ( \@recs, \%hash_cog_func, \%hash_cog_path );
}

#
# html table view of the data - default view
#
# param $sort column number, starts at 2
# param $recs_ref array of arrays of queried data
# param $hash_cog_func_ref hash of arrays cog id => array of cog data
#
sub flushGeneBatch2 {
    my ( $it, $recs_ref, $hash_cog_func_ref ) = @_;
    my @recs = @$recs_ref;

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    my $count = 0;
    my $sd    = $it->getSdDelim();    # sort delimiter

    my $last_gene_oid = "";
    foreach my $r (@recs) {
        my (
             $gene_oid,   $percent,       $gene_name,  $gene_symbol, $locus_type, $taxon_oid,
             $taxon_id,   $abbr_name,     $genus,      $species,     $aa_seq_length,
             $seq_status, $ext_accession, $seq_length, $cog_id,      $copies
          )
          = @$r;
        next if ( $checked eq "true" && $cog_id eq "" );

        my $ck = "";

        # col 1
        my $row = $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2     = escHtml($genus);
        my $species2   = escHtml($species);
        my $abbr_name2 = escHtml($abbr_name);
        my $orthStr;
        my $scfInfo = "";
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        # col 2
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        # col 3 - percent hits
        $row .= $percent . $sd . $percent . "\t";

        # col 4 - name
        $row .= $gene_name . " [$abbr_name2]$scfInfo" . $sd . $gene_name . " [$abbr_name2]$scfInfo\t";

        # col 5 - cog id
        $row .= $cog_id . $sd . $cog_id . "\t";

        my $arr_ref = $hash_cog_func_ref->{$cog_id};

        # col 6 cog name
        if ( defined($arr_ref) ) {
            $row .= $arr_ref->[0] . $sd . $arr_ref->[0] . "\t";
        } else {
            $row .= " " . $sd . nbsp(1) . "\t";
        }

        # col 7 cog function
        if ( defined($arr_ref) ) {
            my $cogfunc = cogfunc( $cog_id, $hash_cog_func_ref );
            $row .= $cogfunc . $sd . $cogfunc . "\t";
        } else {
            $row .= " " . $sd . nbsp(1) . "\t";
        }

        # col 8 cog to gene count
        # COG Gene Count removed

=removed as requested by Natalia (GBP) for IMG 3.3 +BSJ 10/13/10
        if ( defined($arr_ref) ) {
        $row .= $arr_ref->[$#$arr_ref] . $sd . $arr_ref->[$#$arr_ref] . "\t";
        } else {
        $row .= " " . $sd . nbsp(1) . "\t";
        }
=cut

        if ( !$copies ) {
            $copies = 1;
        }
        $row .= $copies . $sd . $copies . "\t";

        $it->addRow($row);
        $count++;
    }
}

#
# creates html page displaying data group by cog func
#
# param $recs_ref array of arrays of main display data
# param $hash_cog_func_ref hash of arrays cog id => array of cog data
#
sub flushGeneBatch3 {
    my ( $recs_ref, $hash_cog_func_ref, $hash_cog_path_ref, $section ) = @_;
    my @recs = @$recs_ref;

    my $file1 = param("cf1");
    my $file2 = param("cf2");
    my $file4 = param("cf4");

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    my $funcNames_aref = getCogFunctionList($hash_cog_func_ref);
    my @funcNames      = sort @$funcNames_aref;

    # add unknown to the end
    push( @funcNames, $zzzUnknown );

    # ref hash of cog func name = > array list of gene oids
    my $cog_count_ref = cogFuncCheckBoxCount( \@recs, $hash_cog_func_ref );

    foreach my $function (@funcNames) {
        if ( $function eq $zzzUnknown && $checked eq "true" ) {
            next;
        }

        # array list of gen oids from function names
        # sub sort list by percentage?
        my $genelist = $cog_count_ref->{$function};

        # bug fix - this can be undefined
        next if ( !defined($genelist) );

        # I can user cogPathSort() here too! see flushGeneBatch4
        my @sorted_genelist =
          sort { cogPathSort( $b, $recs_ref ) <=> cogPathSort( $a, $recs_ref ) } @$genelist;

        # array size or last element index
        my $geneCount = $#$genelist + 1;

        # get distinct gne oid count - because there are duplicate hits
        my %distinct_genes;
        foreach my $geneoid (@sorted_genelist) {
            $distinct_genes{$geneoid} = "";
        }
        my $distinct_gene_count = keys %distinct_genes;

        my $escFunc = escHtml($function);

        print "<font color='navy' size='+1'>";

        my $tmpname = $function;
        $tmpname = $unknown if ( $function eq $zzzUnknown );

        print "<a href='main.cgi?section=$section&page=metagenomeHits"
          . "&view=cogfuncpath&cf1=$file1&cf2=$file2&cf4=$file4"
          . "&function=$escFunc'>$tmpname</a> ($distinct_gene_count)";
        print "</font>\n";

        my $tmp = $function . "_selectall";
        print "\n<input type='button' name='$tmp' value='Select' ";
        print "onClick=\"selectTaxon($geneCount, '$tmp')\" ";
        print "class='tinybutton' />\n";
        $tmp = $function . "_clearall";
        print "&nbsp;";
        print "\n<input type='button' name='$tmp' value='Clear' ";
        print "onClick=\"unSelectTaxon($geneCount, '$tmp')\" ";
        print "class='tinybutton' />\n";
        print "&nbsp;\n";

        print "<table>\n";

        foreach my $geneoid (@sorted_genelist) {

            # a single row of data
            my $rec_ref = getRecInfo( $recs_ref, $geneoid );

            my (
                 $gene_oid,   $percent,       $gene_name,  $gene_symbol, $locus_type, $taxon_oid,
                 $taxon_id,   $abbr_name,     $genus,      $species,     $aa_seq_length,
                 $seq_status, $ext_accession, $seq_length, $cog_id,      $copies
              )
              = @$rec_ref;

            next if ( $checked eq "true" && $cog_id eq "" );

            my $arr_ref = $hash_cog_func_ref->{$cog_id};

            my $cogGeneCount = "";
            if ( defined($arr_ref) ) {
                $cogGeneCount = $arr_ref->[$#$arr_ref];
            } else {
                $cogGeneCount = "";
            }

            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            print "<tr>\n";
            print "<td nowrap>";
            print nbsp(4);
            print "</td><td>\n";
            print "<input type='checkbox' name='gene_oid' value='$gene_oid'/>";
            print "</td>";
            print "<td>";
            print alink( $url, $gene_oid );
            print "</td><td>";

            if ( $percent ne "" ) {
                print "$percent%";
            } else {
                print "";
            }
            print "</td><td>$cogGeneCount</td><td nowrap>";
            print $gene_name;
            print "</td>";
            print "</tr>\n";
        }
        print "</table>\n";
    }
}

#
# creates html page displaying data group by cog pathways
#
# param $recs_ref array of arrays of main display data
# param $hash_cog_func_ref hash of arrays cog id => array of cog data
# param $hash_cog_path_ref hash of arrays gene oid to cog pathways
# param $functionname function name
#
sub flushGeneBatch3path {
    my (
        $recs_ref,          $hash_cog_func_ref,
        $hash_cog_path_ref, $functionname
      )
      = @_;
    my @recs = @$recs_ref;

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    print <<EOF;
        <table>
        <tr><td>
        &nbsp;
        <input type="hidden" name='tableview' value='Table View'  />
        &nbsp;
        <input type="hidden" name='cogfuncview' value='COG Functional Categories' /> 
        &nbsp;
        <input type="hidden" name='cogpathview' value='COG Pathways'  />
        </td><td>
        <input type="hidden" 
        </td></tr> 
        </table>
EOF

    my $funcNames_aref = getCogFunctionList($hash_cog_func_ref);
    my @funcNames      = sort @$funcNames_aref;

    # add unknown to the end
    push( @funcNames, $zzzUnknown );

    # ref hash of cog func name = > array list of gene oids
    my $cog_count_ref = cogFuncCheckBoxCount( \@recs, $hash_cog_func_ref );

    foreach my $function (@funcNames) {
        if ( $function eq $zzzUnknown ) {
            next;
        }

        my $escfunctionname = escHtml($function);
        if ( $escfunctionname ne $functionname ) {
            next;
        }

        # array list of gen oids from function names
        # sub sort list by percentage?
        my $genelist = $cog_count_ref->{$function};

        my $hash_sub_cog_path_ref =
          getGenePathwayList( $genelist, $hash_cog_path_ref );

        print "<font color='navy' size='+1'>";
        print "COG Functional Category: <i>$function</i> <br>"
          . "COG Pathways </font><p>\n";

        flushGeneBatch4( $recs_ref, $hash_cog_func_ref,
            $hash_sub_cog_path_ref, 'true' );
    }
}

#
# creates html page displaying data group by cog pathways
#
# param $recs_ref array of arrays of main display data
# param $hash_cog_func_ref hash of arrays cog id => array of cog data
# param $hash_cog_path_ref hash of gene id => array list of cog pathway names
#
sub flushGeneBatch4 {
    my ( $recs_ref, $hash_cog_func_ref, $hash_cog_path_ref,
        $hide )
      = @_;
    my @recs = @$recs_ref;

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    if ( defined($hide) ) {
        $checked = $hide;
    }

    # array list of pathways names
    my $pathNames_aref = getPathwayList($hash_cog_path_ref);
    my @pathNames      = sort @$pathNames_aref;

    # add unknown to the end
    push( @pathNames, $zzzUnknown );

    # ref hash of cog pathway name = > array list of gene oids
    my $cog_count_ref = cogPathCheckBoxCount( \@recs, $hash_cog_path_ref );

    foreach my $pathway (@pathNames) {
        if ( $pathway eq $zzzUnknown && $checked eq "true" ) {
            next;
        }

        # array list of gen oids from pathway names
        # sub sort list by percentage?
        my $genelist = $cog_count_ref->{$pathway};

        # bug fix
        next if ( !defined($genelist) );

        my @sorted_genelist =
          sort { cogPathSort( $b, $recs_ref ) <=> cogPathSort( $a, $recs_ref ) }
          @$genelist;

        # array size or last element index
        my $geneCount = $#$genelist + 1;

        # get distinct gne oid count - because there are duplicate hits
        my %distinct_genes;
        foreach my $geneoid (@sorted_genelist) {
            $distinct_genes{$geneoid} = "";
        }
        my $distinct_gene_count = keys %distinct_genes;

        print "<font color='navy' size='+1'>";
        if ( $pathway eq $zzzUnknown ) {
            print $unknown . "</font>\n";
        }
        else {

            print $pathway . " ($distinct_gene_count) </font>\n";
        }

        my $tmp = $pathway . "_selectall";
        print "\n<input type='button' name='$tmp' value='Select' ";
        print "onClick=\"selectTaxon($geneCount, '$tmp')\" ";
        print "class='tinybutton' />\n";
        $tmp = $pathway . "_clearall";
        print "&nbsp;";
        print "\n<input type='button' name='$tmp' value='Clear' ";
        print "onClick=\"unSelectTaxon($geneCount, '$tmp')\" ";
        print "class='tinybutton' />\n";
        print "&nbsp;\n";

        print "<table>\n";

        foreach my $geneoid (@sorted_genelist) {

            # a single row of data
            my $rec_ref = getRecInfo( $recs_ref, $geneoid );

            my (
                $gene_oid,   $percent,       $gene_name,  $gene_symbol,
                $locus_type, $taxon_oid,     $taxon_id,   $abbr_name,
                $genus,      $species,       $aa_seq_length,
                $seq_status, $ext_accession, $seq_length, $cog_id,
                $copies
              )
              = @$rec_ref;

            next if ( $checked eq "true" && $cog_id eq "" );

            my $arr_ref = $hash_cog_func_ref->{$cog_id};

            my $cogGeneCount = "";
            if ( defined($arr_ref) ) {
                $cogGeneCount = $arr_ref->[$#$arr_ref];
            }
            else {
                $cogGeneCount = "";
            }

            my $url =
              "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";

            print "<tr>\n";
            print "<td nowrap>";
            print nbsp(4);
            print "</td><td>";
            print
              "\n<input type='checkbox' name='gene_oid' value='$gene_oid'/>";
            print "</td>";
            print "<td>";
            print alink( $url, $gene_oid );
            print "</td><td>";

            if ( $percent ne "" ) {
                print "$percent%";
            }
            else {
                print "";
            }
            print "</td><td>$cogGeneCount</td><td nowrap>";
            print $gene_name;
            print "</td>";
            print "</tr>\n";
        }
        print "</table>\n";
    }
}


#
# Gets gene information, placed in $recs_ref
#
# param $dbh database handle
# param $gene_oids_ref array list of gene oids
# param $percentHits_ref hash of gene oid => to percent
# param $recs_ref return data array of arrays
#
sub getFlushGeneBatch2 {
    my ( $dbh, $gene_oids_ref, $percentHits_ref, $recs_ref ) = @_;

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    #print "getFlushGeneBatch2()  gene_oids_ref=@$gene_oids_ref<br/>\n";

    my $str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type, 
       tx.taxon_oid, tx.ncbi_taxon_id, tx.taxon_display_name, tx.genus, 
       tx.species, g.aa_seq_length, 
       tx.seq_status, scf.ext_accession, ss.seq_length, gcg.cog, g.est_copy
       from taxon tx, scaffold scf, scaffold_stats ss, 
       gene g 
       left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid 
    };
    #print "getFlushGeneBatch2() sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my (
             $gene_oid,      $gene_name,  $gene_symbol,   $locus_type, $taxon_oid,
             $taxon_id,      $abbr_name,  $genus,         $species, 
             $aa_seq_length, $seq_status, $ext_accession, $seq_length, $cog_id, 
             $copies
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my @rec;
        push( @rec, "$gene_oid" );
        push( @rec, $percentHits_ref->{$gene_oid} );
        push( @rec, "$gene_name" );
        push( @rec, "$gene_symbol" );
        push( @rec, "$locus_type" );
        push( @rec, "$taxon_oid" );
        push( @rec, "$taxon_id" );
        push( @rec, "$abbr_name" );
        push( @rec, "$genus" );
        push( @rec, "$species" );
        push( @rec, "$aa_seq_length" );
        push( @rec, "$seq_status" );
        push( @rec, "$ext_accession" );
        push( @rec, "$seq_length" );
        push( @rec, "$cog_id" );
        push( @rec, "$copies" );
        
        push( @$recs_ref, \@rec );
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );
}

#
# copy of WebUtil.pm printCartFooter
# I used it because some of my pages have checkboxes that should not be
# selected
#
# param $id
# param $buttonLabel
# param $bclass
#
# see WebUtil.pm printCartFooter
#
sub printCartFooter2 {
    my ( $id, $buttonLabel, $bclass ) = @_;
    my $buttonClass = "meddefbutton";
    $buttonClass = $bclass if $bclass ne "";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes2(1, 7)' class='smbutton' /> ";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes2(0, 7)' class='smbutton' /> ";
    print "<br/>\n";
}

#
# calc median
# array should be sorted!
#
# param $aref array ref of numbers
# return median
#
sub median {
    my ($aref) = @_;

    my @array = sort(@$aref);

    my $size = $#$aref + 1;

    my $median;

    if ( $size == 1 ) {
        $median = $array[$#array];
    }
    elsif ( $size % 2 != 0 ) {
        $median = $array[ ( $#array / 2 ) ];
    }
    else {
        $median = $array[ ( $#array / 2 ) ] +
          ( ( $array[ ( $#array / 2 ) + 1 ] - $array[ ( $#array / 2 ) ] ) / 2 );
    }

    return $median;
}

#
# calc math mode
#
# param $aref array ref list of numbers
# return array ref of numbers with max number occurance
sub mode {
    my ($aref) = @_;

    # list of number that have max occurance
    my @maxNumbers;

    # max count found so far
    my $maxCount = 0;

    # hash of number => count
    my %counts;
    foreach my $x (@$aref) {
        if ( exists( $counts{$x} ) ) {
            $counts{$x} = $counts{$x} + 1;
        }
        else {
            $counts{$x} = 1;
        }

        if ( $counts{$x} == $maxCount ) {
            push( @maxNumbers, $x );
        }
        elsif ( $counts{$x} > $maxCount ) {

            # new set of max's
            $maxCount   = $counts{$x};
            @maxNumbers = ();
            push( @maxNumbers, $x );
        }
    }

    # When no number occurs more than once in a data set, there is no mode.
    # http://mathforum.org/library/drmath/view/61375.html
    if ( $maxCount == 1 ) {
        @maxNumbers = ();
    }

    return \@maxNumbers;
}

#
# is the number math "mode"
#
# param $mode_aref array ref list of mode numbers
# param $number number
#
sub isModeNumber {
    my ( $mode_aref, $number ) = @_;

    foreach my $x (@$mode_aref) {
        if ( $x == $number ) {
            return 1;
        }
    }

    return 0;
}

#
# Get phylo distribution date.
#
sub getPhyloDistDate {
    my( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
      select t.phylodist_date
      from taxon t
      where t.taxon_oid = ?
      $rclause
      $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $dt = $cur->fetchrow( );
    $cur->finish( );
    
    return $dt;
}

#
# Get phylo distribution method.
#
sub getPhyloDistMethod {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
       select phylodist_method
       from taxon
       where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $m = $cur->fetchrow();
    $cur->finish();
    
    return $m;
}

sub printPhylogeneticDistributionSection {
    my ( $isSet, $isSingleScafDetail ) = @_;

    print "<h2>Phylogenetic Distribution</h2>";

    my $inScaffoldMsg = lc( getInScaffoldMsg( $isSet, $isSingleScafDetail ) );
    print "<p>You may view the phylogenetic distrubution "
    . "of best blast hits of protein-coding genes in $inScaffoldMsg.</p>\n";

    ## something we might need in the future
    #    print "<p>\n";
    #    print "<b>Display Type</b>\n";
    #    print nbsp(1);
    #    print "<input type='radio' name='display_type' value='all_scaffolds' checked='checked' />" .
    #   "Include all scaffolds in selected scaffold set(s)\n";
    #    print "<br/>\n";
    #    print nbsp(12);
    #    print "<input type='radio' name='display_type' value='individual_set' />" .
    #   "Show distribution of each selected scaffold set\n";
    #    print " with Percent Identity\n";
    #    print "     <select name='percent_identity' class='img' size='1'>\n";
    #    print "        <option value='30'>30 - 59\%</option>\n";
    #    print "        <option value='60'>60 - 89\%</option>\n";
    #    print "        <option value='30plus'>30\%\+</option>\n";
    #    print "        <option value='60plus'>60\%\+</option>\n";
    #    print "        <option value='90plus'>90\%\+</option>\n";
    #    print "     </select>\n";
    #    print "</p>\n";
    
    if ( $isSingleScafDetail ) {
        my $name = "_section_ScaffoldCart_showPhyloDist";
        print hiddenVar( "isSingleScafDetail", $isSingleScafDetail );
        print submit(
            -name    => $name,
            -value   => 'Distribution by BLAST percent identities',
            -class   => 'lgdefbutton',
        );
    }
    else {
        if ($isSet) {
            print "<p>\n";
            HtmlUtil::printMetaDataTypeChoice('_p', '', 1, 1);
            print "</p>\n";
            my $name = "_section_WorkspaceScafSet_scaffoldSetPhyloDist";
            print submit(
                -name    => $name,
                -value   => 'Distribution by BLAST percent identities',
                -class   => 'lgdefbutton',
                -onClick => "return checkSetsIncludingShare('scaffold');"
            );
        } else {
            my $name = "_section_ScaffoldCart_showPhyloDist";
            print submit(
                -name    => $name,
                -value   => 'Distribution by BLAST percent identities',
                -class   => 'lgdefbutton',
                -onClick => 'return validateSelection(1);'
            );
        }
    }

}

sub getInScaffoldMsg {
    my ( $isSet, $isSingleScafDetail ) = @_;

    my $scaffoldMsg;
    if ($isSingleScafDetail) {
        $scaffoldMsg = 'Scaffold';
    } else {
        if ($isSet) {
            $scaffoldMsg = 'Selected Scaffold Sets';
        } else {
            $scaffoldMsg = 'Selected Scaffolds';
        }
    }
    
    return $scaffoldMsg;
}


sub getXcopyText {
    my ( $xcopy ) = @_;

    my $xcopyText = $distMethodText{$xcopy};
    if ( !$xcopyText ) {
        $xcopyText = $distMethodText{'gene_count'};
    }
    return $xcopyText;
}

sub getPercentClause {
    my ( $percent, $plus, $alias ) = @_;

    #todo
    if ( ! $alias ) {
        $alias = 'dt';
    }
    
    my $percentClause;
    if ( $percent == 30 ) {
        if ( $plus ) {
            $percentClause = "and dt.percent_identity >= 30 ";
        }
        else {
            $percentClause = "and dt.percent_identity >= 30 and dt.percent_identity < 60 ";
        }
    } elsif ( $percent == 60 ) {
        if ( $plus ) {
            $percentClause = "and dt.percent_identity >= 60 ";
        }
        else {
            $percentClause = "and dt.percent_identity >= 60 and dt.percent_identity < 90 ";
        }
    } else {
        $percentClause = "and dt.percent_identity >= 90 ";
    }

    return $percentClause;
}


sub getTaxonomyClause2 {
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $taxonomyClause;
    my @binds;
        
    if ( $domain ) {
        $taxonomyClause .= " and t.domain = ? ";            
        push( @binds, $domain );
    }
        
    if ( $phylum ) {
        $taxonomyClause .= " and t.phylum = ? ";            
        push( @binds, $phylum );
    }
        
    if ( $ir_class ) {
        if ( $ir_class eq $unknown ) {
            $taxonomyClause .= " and t.ir_class is null ";
        } elsif ( $family eq "*" ) {
            $taxonomyClause .= "";
        } else {
            $taxonomyClause .= " and t.ir_class = ? ";
            push( @binds, $ir_class );
        }
    }
    
    if ( $ir_order ) {
        if ( $ir_order eq $unknown ) {
            $taxonomyClause .= " and t.ir_order is null ";
        } elsif ( $family eq "*" ) {
            $taxonomyClause .= "";
        } else {
            $taxonomyClause .= " and t.ir_order = ? ";
            push( @binds, $ir_order );
        }
    }

    if ( $family ) {
        if ( $family eq $unknown ) {
            $taxonomyClause .= " and t.family is null ";
        } elsif ( $family eq "*" ) {
            $taxonomyClause .= "";
        } else {
            $taxonomyClause .= " and t.family = ? ";
            push( @binds, $family );
        }
    }
    
    if ( $genus ) {
        if ( $genus eq $unknown ) {
            $taxonomyClause .= " and t.genus is null ";
        } elsif ( $genus eq "*" ) {
            $taxonomyClause .= "";
        } else {
            $taxonomyClause .= " and t.genus = ? ";
            push( @binds, $genus );
        }
    }
    
    if ( $species ) {
        if ( $species eq $unknown ) {
            $taxonomyClause .= " and t.species is null ";
        } elsif ( $species eq "*" ) {
            $taxonomyClause .= "";
        } else {
            $taxonomyClause .= " and t.species = ? ";
            push( @binds, $species );
        }
    }

    return ( $taxonomyClause, \@binds );
}


sub getTaxonomyClause {
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $taxonomyClause;
    my @bindList;
    
    if ( $domain ) {
        $taxonomyClause .= " and domain = ? "; 
        push(@bindList, $domain);
    }
    if ( $phylum ) {
        $taxonomyClause .= " and phylum = ? "; 
        push(@bindList, $phylum);
    }
    if ( $ir_class ) {
        $taxonomyClause .= " and ir_class = ? "; 
        push(@bindList, $ir_class);
    }
    if ( $ir_order ) {
        $taxonomyClause .= " and ir_order = ? "; 
        push(@bindList, $ir_order);
    }
    if ( $family ) {
        $taxonomyClause .= " and family = ? "; 
        push(@bindList, $family);
    }
    if ( $genus ) {
        $taxonomyClause .= " and genus = ? "; 
        push(@bindList, $genus);
    }
    if ( $species ) {
        $taxonomyClause .= " and species = ? "; 
        push(@bindList, $species);
    }

    return ( $taxonomyClause, \@bindList );
}

sub getTaxonTaxonomy {
    my ( $dbh, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $taxonomyClause;
    my @bindList;
    if ( $domain ) {
        $taxonomyClause .= " and domain = ? "; 
        push(@bindList, $domain);
    }
    if ( $phylum ) {
        $taxonomyClause .= " and phylum = ? "; 
        push(@bindList, $phylum);
    }
    if ( $ir_class ) {
        $taxonomyClause .= " and ir_class = ? "; 
        push(@bindList, $ir_class);
    }
    if ( $ir_order ) {
        $taxonomyClause .= " and ir_order = ? "; 
        push(@bindList, $ir_order);
    }
    if ( $family ) {
        $taxonomyClause .= " and family = ? "; 
        push(@bindList, $family);
    }
    if ( $genus ) {
        $taxonomyClause .= " and genus = ? "; 
        push(@bindList, $genus);
    }
    if ( $species ) {
        $taxonomyClause .= " and species = ? "; 
        push(@bindList, $species);
    }

    my ($taxonomyClause, $bindList_ref) = getTaxonomyClause( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, 
            t.domain, t.phylum, t.ir_class, t.ir_order, t.family, t.genus, t.species
        from taxon t 
        where 1 = 1
        $taxonomyClause
        $rclause
        $imgClause
    };
    #not applicable with where t.in_file = 'Yes'
    #where t.genome_type = 'metagenome'
    
    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );

    my %taxon_h;
    for ( ; ; ) {
        my ( $tid2, $tname, $domain2, $phylum2, $ir_class2, $ir_order2, $family2, $genus2, $species2 ) = $cur->fetchrow();
        last if !$tid2;
        $taxon_h{$tid2} = "$domain2\t$phylum2\t$ir_class2\t$ir_order2\t$family2\t$genus2\t$species2\t$tname";
    }
    $cur->finish();
    #print "getTaxonTaxonomy() taxon_h:<br/>\n";
    #print Dumper(\%taxon_h);
    #print "<br/>\n";

    return (\%taxon_h);
}

my %func_text = (
    'cogc'     => 'COG Categories',
    'cogp'     => 'COG Pathways',
    'keggc_ec' => 'KEGG Categories via EC',
    'keggc_ko' => 'KEGG Categories via KO',
    'keggp_ec' => 'KEGG Pathways via EC',
    'keggp_ko' => 'KEGG Pathways via KO',
    'pfamc'    => 'Pfam Categories',
    'tigrr'    => 'TIGRfam Roles',
);

sub getFuncTextVal {
    my ( $key ) = @_;

    return $func_text{$key};
}

sub printProfileSelection {
    my ( $section ) = @_;

    print "<p>";
    print "Profile Type: ";
    print nbsp(1);
    print "<select name='profileType'>\n";
    my @sorted_keys = sort( keys %func_text );
    for my $key ( @sorted_keys ) {
        my $val = $func_text{$key};
        print "<option value='$key'>$val</option>\n";        
    }
    print "</select>\n";
    print nbsp(3);
    my $name = "_section_" . $section . "_showProfile";
    print submit(
        -name  => $name,
        -value => "Show Profile",
        -class => "meddefbutton"
    );
    print "</p>\n";

}

sub getAllCategoryInfo {
    my ( $dbh, $profileType ) = @_;

    # get category
    my $sql = "";
    if ( $profileType eq 'cogc' ) {
        $sql = qq{
           select distinct cf.function_code, cf.definition, cfs.cog_id
           from cog_function cf, cog_functions cfs
           where cf.function_code = cfs.functions
           order by 1, 2, 3
       };
    }
    elsif ( $profileType eq 'cogp' ) {
        $sql = qq{
           select distinct cp.cog_pathway_oid, cp.cog_pathway_name,
                  cpcm.cog_members
           from cog_pathway cp, cog_pathway_cog_members cpcm
           where cp.cog_pathway_oid = cpcm.cog_pathway_oid
           order by 1, 2, 3
       };
    }
    elsif ( $profileType eq 'keggc_ec' ) {
        $sql = qq{                                                                                      
            select distinct kp3.min_pid, kp.category, kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp, 
            (select kp2.category category, min(kp2.pathway_oid) min_pid
            from kegg_pathway kp2
            where kp2.category is not null 
            group by kp2.category) kp3
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            and kp.category is not null
            and kp.category = kp3.category
            order by 1, 2, 3
        };
    }
    elsif ( $profileType eq 'keggc_ko' ) {
        $sql = qq{                                                                                      
            select distinct kp3.min_pid, kp.category, rk.ko_terms
            from kegg_pathway kp, image_roi_ko_terms rk, image_roi ir,
            (select kp2.category category, min(kp2.pathway_oid) min_pid
            from kegg_pathway kp2
            where kp2.category is not null
            group by kp2.category) kp3
            where rk.roi_id = ir.roi_id and kp.pathway_oid = ir.pathway
            and kp.category is not null
            and kp.category = kp3.category
            order by 1, 2, 3
        };
    }
    elsif ( $profileType eq 'keggp_ec' ) {
        $sql = qq{
            select distinct kp.pathway_oid, kp.pathway_name, kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            order by 1, 2, 3
        };
    }
    elsif ( $profileType eq 'keggp_ko' ) {
        $sql = qq{
            select distinct kp.pathway_oid, kp.pathway_name, rk.ko_terms
            from kegg_pathway kp, image_roi ir, image_roi_ko_terms rk
            where ir.roi_id = rk.roi_id
            and ir.pathway = kp.pathway_oid
            order by 1, 2, 3
        };
    }
    elsif ( $profileType eq 'pfamc' ) {
        $sql = qq{
            select distinct cf.function_code, cf.definition, pfc.ext_accession
            from cog_function cf, pfam_family_cogs pfc
            where cf.function_code = pfc.functions
            order by 1, 2, 3
        };
    }
    elsif ( $profileType eq 'tigrr' ) {
        $sql = qq{
            select distinct t.role_id, t.sub_role, tr.ext_accession
            from tigr_role t, tigrfam_roles tr
            where t.role_id = tr.roles
            and t.sub_role != 'Other'
            order by 1, 2, 3
        };
    }
    else {
        return;
    }

    # category => array of genes
    my %cateId2cateName_h;
    my %cateName2cateId_h;
    my %func2cateId_h;
    my %cateId2funcs_h;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cate_code, $cate_name, $func_id ) = $cur->fetchrow();
        last if !$cate_code;

        if ( !$cateId2cateName_h{$cate_code} ) {
            $cateId2cateName_h{$cate_code} = $cate_name;
        }

        if ( !$cateName2cateId_h{$cate_name} ) {
            $cateName2cateId_h{$cate_name} = $cate_code;
        }

        if ( $cateId2funcs_h{$cate_code} ) {
            $cateId2funcs_h{$cate_code} .= "\t" . $func_id;
        }
        else {
            $cateId2funcs_h{$cate_code} = $func_id;
        }

        if ( $func2cateId_h{$func_id} ) {
            $func2cateId_h{$func_id} .= "\t" . $cate_code;
        }
        else {
            $func2cateId_h{$func_id} = $cate_code;
        }

    }
    $cur->finish();

    return ( \%cateId2cateName_h, \%cateName2cateId_h, \%cateId2funcs_h, \%func2cateId_h );
}

sub getCategoryName {
    my ( $dbh, $profileType, $cate_id ) = @_;

    my ($category_name);
    if ( $cate_id eq $zzzUnknown ) {
        $category_name = $unknown;
    } else {
        # get category
        my $sql;
        if ( $profileType eq 'cogc' || $profileType eq 'pfamc' ) {
            $sql = qq{
                select definition 
                from cog_function 
                where function_code = ?
            };
        }
        elsif ( $profileType eq 'cogp' ) {
            $sql = qq{
                select cog_pathway_name 
                from cog_pathway 
                where cog_pathway_oid = ?
            };
        }
        elsif ( $profileType eq 'keggc_ec' || $profileType eq 'keggc_ko' ) {
            $sql = qq{
                select category 
                from kegg_pathway 
                where pathway_oid = ?
            };
        }
        elsif ( $profileType eq 'keggp_ec' || $profileType eq 'keggp_ko' ) {
            $sql = qq{
                select pathway_name 
                from kegg_pathway 
                where pathway_oid = ?
            };
        }
        elsif ( $profileType eq 'tigrr' ) {
            $sql = qq{
                select sub_role 
                from tigr_role 
                where role_id = ?
            };
        }
        else {
            return;
        }
        #print "getCategoryName() sql: $sql<br/>\n";
    
        my $cur = execSql( $dbh, $sql, $verbose, $cate_id );
        ($category_name) = $cur->fetchrow();
        $cur->finish();
        #print "getCategoryName() category_name: $category_name<br/>\n";
    }


    return ( $category_name );
}

sub getFuncsFromCategoryId {
    my ( $dbh, $profileType, $cate_id ) = @_;

    # get functions
    my $cclause;
    my $sql = "";
    my @binds;
    if ( $profileType eq 'cogc' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and functions is null ";
        } else {
            $cclause = " and functions = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct cog_id
            from cog_functions
            where 1 = 1
            $cclause
        };
    }
    elsif ( $profileType eq 'cogp' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and cpcm.cog_pathway_oid is null ";
        } else {
            $cclause = " and cpcm.cog_pathway_oid = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct cpcm.cog_members
            from cog_pathway_cog_members cpcm
            where 1 = 1
            $cclause
        };
    }
    elsif ( $profileType eq 'keggc_ec' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and kp3.pathway_oid is null ";
        } else {
            $cclause = " and kp3.pathway_oid = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct kt.enzymes
            from image_roi ir, image_roi_ko_terms rk, ko_term_enzymes kt
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway in
               (select kp2.pathway_oid from kegg_pathway kp2
                where kp2.category =
                   (select kp3.category from kegg_pathway kp3
                    where 1 = 1
                    $cclause) )
        };
    }
    elsif ( $profileType eq 'keggc_ko' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and kp3.pathway_oid is null ";
        } else {
            $cclause = " and kp3.pathway_oid = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct rk.ko_terms
            from image_roi ir, image_roi_ko_terms rk
            where ir.roi_id = rk.roi_id
            and ir.pathway in
               (select kp2.pathway_oid from kegg_pathway kp2
                where kp2.category =
                   (select kp3.category from kegg_pathway kp3
                    where 1 = 1
                    $cclause) )
        };
    }
    elsif ( $profileType eq 'keggp_ec' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and ir.pathway is null ";
        } else {
            $cclause = " and ir.pathway = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct kt.enzymes
            from image_roi ir, ko_term_enzymes kt, image_roi_ko_terms rk
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            $cclause
        };
    }
    elsif ( $profileType eq 'keggp_ko' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and ir.pathway is null ";
        } else {
            $cclause = " and ir.pathway = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct rk.ko_terms
            from image_roi ir, image_roi_ko_terms rk
            where ir.roi_id = rk.roi_id
            $cclause
        };
    }
    elsif ( $profileType eq 'pfamc' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and pfc.functions is null ";
        } else {
            $cclause = " and pfc.functions = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct pfc.ext_accession
            from pfam_family_cogs pfc
            where 1 = 1
            $cclause
        };
    }
    elsif ( $profileType eq 'tigrr' ) {
        if ( $cate_id eq $zzzUnknown ) {
            $cclause = " and tr.roles is null ";
        } else {
            $cclause = " and tr.roles = ? ";
            push( @binds, $cate_id );
        }
        $sql = qq{
            select distinct tr.ext_accession
            from tigrfam_roles tr
            where 1 = 1
            $cclause
        };
    }
    #print "getFuncsFromCategoryId() sql: $sql<br/>\n";
    
    # category => array of genes
    my @funcs;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ($func_id) = $cur->fetchrow();
        last if !$func_id;
        push @funcs, ($func_id);
    }
    $cur->finish();
    #print "getFuncsFromCategoryId() funcs: @funcs<br/>\n";

    return ( @funcs );
}

sub getFuncTypeFromProfileType {
    my ( $profileType ) = @_;

    my $func_type;
    if ( $profileType eq 'cogc' || $profileType eq 'cogp' ) {
        $func_type = "COG";
    }
    elsif ( $profileType eq 'keggc_ec' || $profileType eq 'keggp_ec' ) {
        $func_type = "EC";
    }
    elsif ( $profileType eq 'keggc_ko' || $profileType eq 'keggp_ko' ) {
        $func_type = "KO";
    }
    elsif ( $profileType eq 'pfamc' ) {
        $func_type = "PFAM";
    }
    elsif ( $profileType eq 'tigrr' ) {
        $func_type = "TIGR";
    }
    
    return $func_type;
}


sub printMetagenomeStatsResultsCore {
    my ( $dbh, $use_phylo_file, $section, 
        $taxon_oid, $data_type, $rna16s, $xcopy, $show_hist, $show_hits, $show_percentage, 
        $gene_count_file, $homolog_count_file, $genome_count_file, $filters_ref,
        $plus, $totalGeneCount, $totalCopyCount, $found_href, $total_href,
        $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
        $depth30_href, $depth60_href, $depth90_href,
        $noEstCopy, $pcId_ref, $stats_href, $genomeHitStats_href, $orgCount_href ) = @_;
    
    printMainForm();

    my $genomeWord;
    if ( $section eq 'MetagenomeHits' ) {
        $genomeWord = 'Genome';
    }
    else {
        $genomeWord = 'Metagenome';            
    }
    if ( $rna16s ) {
        print "<h1>Phylogenetic Distribution of 16S rRNA Genes in Metagenome</h1>\n";
    }
    else {
        print "<h1>Phylogenetic Distribution of Genes in $genomeWord</h1>\n";
    }
    
    printTaxonNameAndPhyloMessage( $dbh, $taxon_oid, $data_type );
    
    use TabHTML;
    TabHTML::printTabAPILinks("phylodistTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("phylodistTab");
        </script>
    }; 
 
    my @tabIndex = ( "#phylodisttab1" );
    my @tabNames = ( "Distribution of Best Blast Hists" );
    if ($include_metagenomes) {
        push @tabIndex, "#phylodisttab2";
        push @tabIndex, "#phylodisttab3";
        push @tabNames, "COG Functional Category Statistics";
        push @tabNames, "COG Pathway Statistics";
    }
    if ( $show_mgdist_v2 && $img_internal ) {
        push @tabIndex, "#phylodisttab4";
        push @tabNames, "Tree Views (Experimental)";
    }
    TabHTML::printTabDiv("phylodistTab", \@tabIndex, \@tabNames);
    print "<div id='phylodisttab1'>";

    if ( $use_phylo_file ) {
        printFileBestBlastHits( $section, 
            $taxon_oid, $data_type, $rna16s, $xcopy, $show_hist, $show_hits, $show_percentage, 
            $gene_count_file, $homolog_count_file, $genome_count_file, $filters_ref,
            $plus, $totalGeneCount, $totalCopyCount, $found_href, $total_href,
            $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
            $depth30_href, $depth60_href, $depth90_href );        
    }
    else {
        printBestBlastHits( $dbh, $section,
            $taxon_oid, $xcopy, $show_hist, $show_hits, $show_percentage, $noEstCopy, $plus,  
            $gene_count_file, $homolog_count_file, $genome_count_file, $filters_ref,
            $totalGeneCount, $totalCopyCount, $pcId_ref, $stats_href, $genomeHitStats_href, $orgCount_href );        
    }

    print "</div>"; # end of phylodisttab1

    if ($include_metagenomes) {
        print "<div id='phylodisttab2'>";
        print "<h2>View COG Functional Category Statistics</h2>";
        print "<p>\n";

        my $url_base = "$main_cgi?section=$section&taxon_oid=$taxon_oid";
        $url_base .= "&data_type=$data_type" if ($data_type);
        $url_base .= "&plus=1" if ($plus);
        $url_base .= "&rna16s=$rna16s" if ($rna16s);

        print "View all COG Functional Category 30% Statistics &nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=30'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=30&chart=yes'>Chart</a>\n";
        print "<br>\n";

        print "View all COG Functional Category 60% Statistics &nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=60'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=60&chart=yes'>Chart</a>\n";
        print "<br>\n";

        print "View all COG Functional Category 90% Statistics &nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=90'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogFuncStats&perc=90&chart=yes'>Chart</a>\n";
        print "</p>\n";
        print "</div>"; # end phylodisttab2
    
        print "<div id='phylodisttab3'>";
        print "<h2>View COG Pathway Statistics</h2>";

        print "<p>\n";
        print "View all COG Pathways 30% Statistics &nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=30'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=30&chart=yes'>Chart</a>\n";
        print "<br>\n";

        print "View all COG Pathways 60% Statistics &nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=60'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=60&chart=yes'>Chart</a>\n";
        print "<br>\n";

        print "View all COG Pathways 90% Statistics &nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=90'>Table</a>";
        print "&nbsp;&nbsp;&nbsp;";
        print "<a href='$url_base&page=cogPathStats&perc=90&chart=yes'>Chart</a>\n";
        print "</p>\n";
        print "</div>"; # end phylodisttab3
    }

    #  links to new tree viewers
    if ( $show_mgdist_v2 && $img_internal ) {
        print "<div id='phylodisttab4'>";
        print "<h4>Tree Views (Experimental)</h4>\n";
        
        my $url_base = "$main_cgi?section=MetagenomeHits&taxon_oid=$taxon_oid";
        if ( $plus ) {
            $url_base .= "&plus=1";
        }

        print "<a href='$url_base&page=tree'>Phylum Tree Viewer</a>\n";
        print "<br>\n";
        print "<a href='$url_base&page=treebin'>Bin Tree Viewer</a>\n";
        print "<br>\n";
        print "<a href='$url_base&page=binstats'>Bin Non-Tree Viewer</a>\n";
        print "</div>"; # end phylodisttab4
    }

    TabHTML::printTabDivEnd();

    printStatusLine( "Loaded.", 2 );
    print end_form();

    MetagJavaScript::printMetagJS();
}


sub getPhylumArray {
    my ( $dbh, $taxon_oid, $rclause ) = @_;

    #
    # Get phylum grouping data
    #
    my $sql = qq{
       select distinct dt.domain, dt.phylum
       from dt_phylum_dist_genes dt
       where dt.taxon_oid = ?
       $rclause
   };

    my @phylum_array;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $domain, $phylum ) = $cur->fetchrow();
        last if !$domain;
        push( @phylum_array, "$domain\t$phylum" );
    }
    $cur->finish();

    # add the unassigned
    push( @phylum_array, "unassigned\tunassigned" );

    return (@phylum_array);
}

sub getFilePhylumArray {
    my ( $dbh, $taxon_oid, $data_type, $percent, $plus, $rna16s, $xcopy ) = @_;

    my $totalGeneCount = getFileTotalGeneCount( $taxon_oid, $data_type, $rna16s );

    my ( $totalCopyCount, $found_href, $total_href,
    $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
    $depth30_href, $depth60_href, $depth90_href ) 
        = loadFileBestBlastHits( $dbh, $taxon_oid, $data_type, $rna16s, $xcopy, $totalGeneCount );

    my %cnt30 = %$cnt30_href;
    my %cnt60 = %$cnt60_href;
    my %cnt90 = %$cnt90_href;
    my %depth30 = %$depth30_href;
    my %depth60 = %$depth60_href;
    my %depth90 = %$depth90_href;

    my $totalCount30 = 0;
    my $totalCount60 = 0;
    my $totalCount90 = 0;

    my $total_count = $totalGeneCount;
    if ( $xcopy eq 'est_copy' ) {
        $total_count = $totalCopyCount;
    }

    #
    # Get phylum grouping data
    #
    my %phylum2geneVal;
    for my $key (keys %$found_href) {
        if ( $percent == 30 ) {
            my $val30;
            if ( $xcopy eq 'est_copy' ) {
                $val30 = $depth30{$key};
                if ($plus) {
                    $val30 += $depth60{$key} + $depth90{$key};
                }

                $totalCount30 += $depth30{$key};
                #if ($plus) {
                    $totalCount30 += $depth60{$key} + $depth90{$key};
                #}
            }
            else {
                $val30 = $cnt30{$key};
                if ($plus) {
                    $val30 += $cnt60{$key} + $cnt90{$key};
                }

                $totalCount30 += $cnt30{$key};
                #if ($plus) {
                    $totalCount30 += $cnt60{$key} + $cnt90{$key};
                #}
            }
            if ($val30) {
                $phylum2geneVal{$key} = $val30;
            }

        } 
        elsif ( $percent == 60 ) {
            my $val60;
            if ( $xcopy eq 'est_copy' ) {
                $val60 = $depth60{$key};
                if ($plus) {
                    $val60 += $depth90{$key};
                }
                
                $totalCount60 += $depth60{$key};
                #if ($plus) {
                    $totalCount60 += $depth90{$key};
                #}
            }
            else {
                $val60 = $cnt60{$key};
                if ($plus) {
                    $val60 += $cnt90{$key};
                }            

                $totalCount60 += $cnt60{$key};
                #if ($plus) {
                    $totalCount60 += $cnt90{$key};
                #}
            }
            if ($val60) {
                $phylum2geneVal{$key} = $val60;
            }

        } 
        else {
            my $val90;
            if ( $xcopy eq 'est_copy' ) {
                $val90 = $depth90{$key};
                $totalCount90 += $depth90{$key};
            }
            else {
                $val90 = $cnt90{$key};            
                $totalCount90 += $cnt90{$key};
            }
            if ($val90) {
                $phylum2geneVal{$key} = $val90;
            }
        }
    }


    # add the unassigned
    my $dpc = "unassigned\tunassigned";
    if ( $percent == 30 ) {
        # 30 unassigned
        my $remain30 = $total_count - $totalCount30;
        if ($remain30) {
            $phylum2geneVal{$dpc} = $remain30;
        }
    } 
    elsif ( $percent == 60 ) {
        # 60 unassigned
        my $remain60 = $total_count - $totalCount60;
        if ($remain60) {
            $phylum2geneVal{$dpc} = $remain60;
        }
    } 
    else {
        # 90 unassigned
        my $remain90 = $total_count - $totalCount90;
        if ($remain90) {
            $phylum2geneVal{$dpc} = $remain90;
        }
    }

    return ( %phylum2geneVal );
}

sub toUsePhyloFile {
    my ( $taxon_oid ) = @_;

    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }
    #print "toUsePhyloFile() use_phylo_file: $use_phylo_file<br/>\n";
    
    return $use_phylo_file;
}

#
# Print cog function stat table
#
# param $phylum_array_aref array ref list of phylum separate by ':'
# param $cogFunctions_href hash ref of hash of hashes, func names to hash
#       of phylum to gene count
# param $difference value int
# param $totalGeneCounts_href hash ref of phylum to gene count - can be undefined
#      this over rides the %totalUnknownCounts hash
sub printCogFuncStatTable {
    my ( $section, $taxon_oid, $data_type, $phylum_array_aref, $cogFunctions_href, $difference, $totalGeneCounts_href ) = @_;

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $taxon_name, $data_type );

    # this is for the export file
    my $file       = "cogFunctionStats$$";
    my $exportPath = "$cgi_tmp_dir/$file";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
    .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
    }
    </style>

        <div class='yui-dt'>
YUI
        $tableAttr = "style='font-size:12px;border-collapse:collapse;'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    # column headers
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "COG Functional Category\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # export file
    print $res "COG Functional Category\t";

    my @domainPhylum = sort(@$phylum_array_aref);
    foreach my $dpc (@domainPhylum) {
        my ( $domain, $phylum ) = split( /\t/, $dpc );
        print "<th $thAttr>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print escHtml($phylum);
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";

        # export file
        print $res "$phylum\t";
    }

    # export file
    print $res "\n";

    # total genes with cog
    # key is "$domain\t$phylum"
    # value is total count
    my %totalCogCounts;

    # total count with unknown genes
    # key is "$domain\t$phylum"
    # value is count
    # now its total genes - ken
    my %totalUnknownCounts;

    # cog func names sorted
    my @cogfuncNames = sort( keys(%$cogFunctions_href) );

    # pre-calc totals first such i can calc percentage
    foreach my $cfn (@cogfuncNames) {
        my $href = $cogFunctions_href->{$cfn};
        foreach my $dpc (@domainPhylum) {
            if ( !exists( $totalCogCounts{$dpc} ) ) {
                $totalCogCounts{$dpc} = 0;
            }
            if ( !exists( $totalUnknownCounts{$dpc} ) ) {
                $totalUnknownCounts{$dpc} = 0;
            }

            if ( exists $href->{$dpc} ) {

                if ( $cfn ne $zzzUnknown ) {
                    $totalCogCounts{$dpc} += $href->{$dpc};
                }
                $totalUnknownCounts{$dpc} += $href->{$dpc};
            }
        }
    }

    # total count with unknown genes
    # key is "$domain\t$phylum:'cog function name'"
    # value is percentage
    my %percentage;

    # hash of array list of non-zero percentages
    # key: $dpc - domain
    # valus: array
    my %percentHashList;

    foreach my $cfn (@cogfuncNames) {
        my $href = $cogFunctions_href->{$cfn};
        foreach my $dpc (@domainPhylum) {
            if ( exists $href->{$dpc} && $totalCogCounts{$dpc} != 0 ) {
                $percentage{"$dpc\t$cfn"} = $href->{$dpc} * 100 / $totalCogCounts{$dpc};

                # lets store the rounded percentage
                $percentage{"$dpc\t$cfn"} = sprintf( "%.1f", $percentage{"$dpc\t$cfn"} );

                if ( exists( $percentHashList{$dpc} ) ) {
                    my $tmp = $percentHashList{$dpc};
                    push( @$tmp, $percentage{"$dpc\t$cfn"} );
                } else {
                    my @tmp;
                    push( @tmp, $percentage{"$dpc\t$cfn"} );
                    $percentHashList{$dpc} = \@tmp;
                }

            } else {
                $percentage{"$dpc\t$cfn"} = 0;
            }
        }
    }

    my $idx = 0;
    my $classStr;

    foreach my $cfn (@cogfuncNames) {
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr' >\n";
        my $borderStyle;
        $borderStyle = "border:thin solid #CBCBCB;" . "border-left-color:#7F7F7F'" if $yui_tables;
        if ( $cfn eq $zzzUnknown ) {
            print "<td class='$classStr' style='$borderStyle'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print "<b>Genes with no COG assignment</b>\n";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "Genes with no COG assignment\t";

        } else {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $cfn;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$cfn\t";

        }
        my $href = $cogFunctions_href->{$cfn};

        foreach my $dpc (@domainPhylum) {
            my $percentModeList_aref = PhyloUtil::mode( $percentHashList{$dpc} );

            if ( $difference == 0 ) {

                # all stats
                if ( $cfn eq $zzzUnknown ) {
                    print "<td class='$classStr' style='$borderStyle'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print $href->{$dpc};
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc}\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 ) {

                    my $percent = $percentage{"$dpc\t$cfn"};

                    # set font color via style
                    my $redFontStyle = ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 ) ? "style='color:red'" : "";
                    print "<td class='$classStr' $redFontStyle>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";
                } else {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "0";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "0\t";
                }
            } else {

                # difference >= 3
                # I know @domainPhylum has size of 2
                my $pcent1    = $percentage{"$domainPhylum[0]\t$cfn"};
                my $pcent2    = $percentage{"$domainPhylum[1]\t$cfn"};
                my $highlight = 0;

                if ( $pcent1 > ( $pcent2 * $difference )
                     || ( $pcent1 * $difference ) < $pcent2 )
                {
                    $highlight = 1;
                }

                if ( $cfn eq $zzzUnknown ) {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print $href->{$dpc};
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc}\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 && $highlight == 0 ) {
                    my $percent = $percentage{"$dpc\t$cfn"};

                    # set font color via style
                    my $redFontStyle = ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 ) ? "style='color:red'" : "";
                    print "<td class='$classStr' $redFontStyle>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 ) {

                    # high light yellow
                    my $percent = $percentage{"$dpc\t$cfn"};

                    # display a thin border if highlighted for YUI tables
                    my $borderStyle;
                    $borderStyle = "border:thin solid #CBCBCB;" if $yui_tables;
                    my $redOnYellowBg =
                      ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 )
                      ? "style='background-color:yellow;color:red;$borderStyle'"
                      : "style='background-color:yellow;$borderStyle'";
                    print "<td class='$classStr' $redOnYellowBg>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";

                } else {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "0";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "0\t";
                }

            }
        }
        print "</tr>\n";

        # export file
        print $res "\n";
        $idx++;
    }

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;border-left-color:#7F7F7F'>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Total genes with COG assignment</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Total with genes with COG assignment\t";

    foreach my $dpc (@domainPhylum) {
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $totalCogCounts{$dpc};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export file
        print $res "$totalCogCounts{$dpc}\t";

    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;border-left-color:#7F7F7F'>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Total genes</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Total genes\t";

    foreach my $dpc (@domainPhylum) {
        if ( $totalGeneCounts_href ne "" ) {

            #webLog("$dpc\n");
            # true gene count without cog duplicates
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $totalGeneCounts_href->{$dpc};
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$totalGeneCounts_href->{$dpc}\t";
        } else {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $totalUnknownCounts{$dpc};
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$totalUnknownCounts{$dpc}\t";
        }
    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;"
      . "border-left-color:#7F7F7F;border-bottom-color:#7F7F7F; '>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Percentage Median</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Percentage Median\t";

    # %percentHashList
    foreach my $dpc (@domainPhylum) {
        my $aref = $percentHashList{$dpc};

        #webLog("$dpc\n");

        if ( defined($aref) && $aref ne "" ) {
            my $ans = PhyloUtil::median($aref);
            $ans = sprintf( "%.1f", $ans );
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $ans;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$ans\t";

        } else {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "-\t";

        }
    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "</table> \n";
    print "</div>\n" if $yui_tables;

    print "<p>";
    if ( $difference != 0 ) {
        print "Yellow highlighted cells - percentage difference factor by" . " $difference X\n";
        print "<br>";
    }
    print "Red text - percentage math mode, the value(s) that occurs most often<br>\n";
    print "Numbers are COG counts<br>\n";
    print "Numbers in ( ) are COG counts percentage\n";

    print "<p>\n";
    print "<a href='$main_cgi?section=$section&page=download&file=$file"
      . "&noHeader=1' onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link $section']);\">Tab delimited file for Excel</a>\n";

    close $res;
}

#
# Print cog pathway stat table
#
# param $phylum_array_aref array ref list of phylum separate by ':'
# param $cogFunctions_href hash ref of hash of hashes, func names to hash
#       of phylum to gene count
# param $difference value int
#
sub printCogPathStatTable {
    my ( $section, $taxon_oid, $data_type, $phylum_array_aref, $cogFunctions_href, $difference ) = @_;

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $taxon_name, $data_type );

    # this is for the export file
    my $file       = "cogPathwaysStats$$";
    my $exportPath = "$cgi_tmp_dir/$file";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
    .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
    }
    </style>

        <div class='yui-dt'>
YUI
        $tableAttr = "style='font-size:12px;border-collapse:collapse;'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    # column headers
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "COG Pathway\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # export file
    print $res "COG Pathway\t";

    my @domainPhylum = sort(@$phylum_array_aref);
    foreach my $dpc (@domainPhylum) {
        my ( $domain, $phylum ) = split( /\t/, $dpc );
        print "<th $thAttr>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print escHtml($phylum);
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";

        # export file
        print $res "$phylum\t";
    }

    # export file
    print $res "\n";

    # total genes with cog
    # key is "$domain\t$phylum"
    # value is total count
    my %totalCogCounts;

    # total count with unknown genes
    # key is "$domain\t$phylum"
    # value is count
    my %totalUnknownCounts;

    # cog func names sorted
    my @cogfuncNames = sort( keys(%$cogFunctions_href) );

    # pre-calc totals first such i can calc percentage
    foreach my $cfn (@cogfuncNames) {
        my $href = $cogFunctions_href->{$cfn};
        foreach my $dpc (@domainPhylum) {
            if ( !exists( $totalCogCounts{$dpc} ) ) {
                $totalCogCounts{$dpc} = 0;
            }
            if ( !exists( $totalUnknownCounts{$dpc} ) ) {
                $totalUnknownCounts{$dpc} = 0;
            }

            if ( exists $href->{$dpc} ) {
                if ( $cfn ne $zzzUnknown ) {
                    $totalCogCounts{$dpc} += $href->{$dpc};
                }
                $totalUnknownCounts{$dpc} += $href->{$dpc};
            }
        }
    }

    # total count with unknown genes
    # key is "$domain\t$phylum:'cog function name'"
    # value is percentage
    my %percentage;

    # hash of array list of non-zero percentages
    # key: $dpc - domain
    # valus: array
    my %percentHashList;

    foreach my $cfn (@cogfuncNames) {
        my $href = $cogFunctions_href->{$cfn};
        foreach my $dpc (@domainPhylum) {
            if ( exists $href->{$dpc} && $totalCogCounts{$dpc} != 0 ) {
                $percentage{"$dpc\t$cfn"} = $href->{$dpc} * 100 / $totalCogCounts{$dpc};

                # lets store the rounded percentage
                $percentage{"$dpc\t$cfn"} = sprintf( "%.1f", $percentage{"$dpc\t$cfn"} );

                if ( exists( $percentHashList{$dpc} ) ) {
                    my $tmp = $percentHashList{$dpc};
                    push( @$tmp, $percentage{"$dpc\t$cfn"} );
                } else {
                    my @tmp;
                    push( @tmp, $percentage{"$dpc\t$cfn"} );
                    $percentHashList{$dpc} = \@tmp;
                }

            } else {
                $percentage{"$dpc\t$cfn"} = 0;
            }
        }
    }

    my $idx = 0;
    my $classStr;

    foreach my $cfn (@cogfuncNames) {
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr'>\n";

        # cog pathway names
        my $borderStyle;
        $borderStyle = "border:thin solid #CBCBCB;" . "border-left-color:#7F7F7F'" if $yui_tables;

        if ( $cfn eq $zzzUnknown ) {
            print "<td class='$classStr' style='$borderStyle'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print "<b>Genes with no COG assignment</b>\n";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "Genes with no COG assignment\t";

        } else {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $cfn;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$cfn\t";

        }
        my $href = $cogFunctions_href->{$cfn};

        foreach my $dpc (@domainPhylum) {
            my $percentModeList_aref = PhyloUtil::mode( $percentHashList{$dpc} );

            if ( $difference == 0 ) {

                # all stats

                if ( $cfn eq $zzzUnknown ) {
                    print "<td class='$classStr' style='$borderStyle'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print $href->{$dpc};
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc}\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 ) {

                    my $percent = $percentage{"$dpc\t$cfn"};

                    # set font color via style
                    my $redFontStyle = ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 ) ? "style='color:red'" : "";
                    print "<td class='$classStr' $redFontStyle>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";

                } else {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "0";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "0\t";

                }
            } else {

                # difference >= 3
                # I know @domainPhylum has size of 2
                my $pcent1    = $percentage{"$domainPhylum[0]\t$cfn"};
                my $pcent2    = $percentage{"$domainPhylum[1]\t$cfn"};
                my $highlight = 0;

                if ( $pcent1 > ( $pcent2 * $difference )
                     || ( $pcent1 * $difference ) < $pcent2 )
                {
                    $highlight = 1;
                }

                if ( $cfn eq $zzzUnknown ) {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print $href->{$dpc};
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc}\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 && $highlight == 0 ) {
                    my $percent = $percentage{"$dpc\t$cfn"};

                    # set font color via style
                    my $redFontStyle = ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 ) ? "style='color:red'" : "";
                    print "<td class='$classStr' $redFontStyle>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";

                } elsif ( $percentage{"$dpc\t$cfn"} != 0 ) {

                    # high light yellow
                    my $percent = $percentage{"$dpc\t$cfn"};

                    # display a thin border if highlighted for YUI tables
                    my $borderStyle;
                    $borderStyle = "border:thin solid #CBCBCB;" if $yui_tables;
                    my $redOnYellowBg =
                      ( PhyloUtil::isModeNumber( $percentModeList_aref, $percent ) == 1 )
                      ? "style='background-color:yellow;color:red;$borderStyle'"
                      : "style='background-color:yellow;$borderStyle'";
                    print "<td class='$classStr' $redOnYellowBg>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "$href->{$dpc} ($percent)";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "$href->{$dpc} ($percent)\t";

                } else {
                    print "<td class='$classStr'>\n";
                    print "<div class='yui-dt-liner'>" if $yui_tables;
                    print "0";
                    print "</div>\n" if $yui_tables;
                    print "</td>\n";

                    # export file
                    print $res "0\t";
                }

            }
        }
        print "</tr>\n";

        # export file
        print $res "\n";
        $idx++;
    }

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;border-left-color:#7F7F7F'>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Total genes with COG assignment</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Total with genes with COG assignment\t";

    foreach my $dpc (@domainPhylum) {
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $totalCogCounts{$dpc};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export file
        print $res "$totalCogCounts{$dpc}\t";
    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;border-left-color:#7F7F7F'>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Total genes</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Total genes\t";

    foreach my $dpc (@domainPhylum) {
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $totalUnknownCounts{$dpc};
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export file
        print $res "$totalUnknownCounts{$dpc}\t";
    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "<tr class='$classStr' style='border:thin solid #CBCBCB;"
      . "border-left-color:#7F7F7F;border-bottom-color:#7F7F7F; '>\n";
    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Percentage Median</b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # export file
    print $res "Percentage Median\t";

    # %percentHashList
    foreach my $dpc (@domainPhylum) {
        my $aref = $percentHashList{$dpc};

        if ( defined($aref) && $aref ne "" ) {
            my $ans = PhyloUtil::median($aref);
            $ans = sprintf( "%.1f", $ans );

            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $ans;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "$ans\t";
        } else {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export file
            print $res "-\t";
        }
    }
    print "</tr>\n";

    # export file
    print $res "\n";

    print "</table> \n";
    print "</div>\n" if $yui_tables;

    print "<p>";
    if ( $difference != 0 ) {
        print "Yellow highlighted Cells -" . " percentage difference factor by $difference X\n";
        print "<br>";
    }
    print "Red text - percentage math mode, the value(s) that occurs most often<br>\n";
    print "Numbers are COG pathways counts<br>\n";
    print "Numbers in ( ) are COG pathways counts percentage\n";

    print "<p>\n";
    print "<a href='$main_cgi?section=$section&page=download&file=$file"
      . "&noHeader=1' onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link $section']);\">Tab delimited file for Excel</a>\n";

    close $res;
}

#
# Print cog function stat chart
#
# param $cogFunctions_href hash ref of hash of hashes, func names to hash
#       of phylum to gene count
#
sub printCogStatChart {
    my ( $section, $taxon_oid, $data_type, $percent, $plus, $cogs_href, $which ) = @_;

    my $page = "catefuncstatsgenes";
    my $profileType;
    if ( $which eq "func" ) {
        $profileType = "cogc";
    } elsif ( $which eq "path" ) {
        $profileType = "cogp";
    }
    
    #my $url_mid = "&taxon_oid=$taxon_oid&perc=$percent";
    my $url_mid = "&taxon_oid=$taxon_oid&percent_identity=$percent";
    $url_mid .= "&data_type=$data_type"  if ( $data_type );
    $url_mid .= "&plus=1"  if ( $plus );

    my $url2_base = "$main_cgi?section=$section&page=$page";
    $url2_base .= $url_mid;
    $url2_base .= "&profileType=$profileType&cate_id=";

    printStatusLine( "Loading ...", 1 );
    print "<h2>Genes with COGs</h2>";

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $taxon_name, $data_type );    

    #### PREPARE THE PIECHART ######
    my @chartcategories;
    my @cateids;
    my @chartdata;
    #################################

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql;
    if ( $which eq "func" ) {
        $sql = qq{
            select definition, function_code
            from cog_function
        };
    } 
    elsif ( $which eq "path" ) {
        $sql = qq{
            select cog_pathway_name, cog_pathway_oid
            from cog_pathway
        };
    }
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count = 0;
    my %cogHash;
    for ( ; ; ) {
        my ( $name, $id ) = $cur->fetchrow();
        last if !$name;
        last if !$id;
        $count++;
        $cogHash{$name} = $id;
    }
    $cur->finish();
    #print "printCogStatChart() cogHash:<br/>\n";
    #print Dumper(\%cogHash);
    #print "<br/>\n";

    #print "printCogStatChart() cogs_href:<br/>\n";
    #print Dumper($cogs_href);
    #print "<br/>\n";

    # cog names sorted
    my @cogNames = sort( keys %$cogs_href );

    # calculate totals for each COG
    my $gene_count_total = 0;
    foreach my $cfn (@cogNames) {
        if ( $cfn eq $zzzUnknown ) {
            next;
        }
        my $cogid = $cogHash{$cfn};
        #print "printCogStatChart() cfn=$cfn cogid=$cogid<br/>\n";

        my $gene_count;
        my $href = $cogs_href->{$cfn};
        while ( my ( $k, $v ) = each %$href ) {
            #webLog("printCogStatChart() key: $k, value: $v.<br/>\n");
            #print "printCogStatChart() key: $k, value: $v.<br/>\n";
            $gene_count += $v;
        }
        $gene_count_total += $gene_count;

        if ( $cfn eq $zzzUnknown ) {
            push @chartcategories, "Genes with no COG assignment";
        } else {
            push @chartcategories, $cfn;
        }
        push @cateids,   $cogid;
        push @chartdata, $gene_count;
    }

    printD3Chart( \@chartcategories, \@cateids, \@chartdata, $url2_base, $gene_count_total);

    printStatusLine( "Done.", 2 );
}


#########################################################################
# printCateChart
#########################################################################
sub printCateChart {
    my ($section,
        $taxon_oid, $data_type, $percent_identity, $plus,
        $domain,    $phylum,    $ir_class,         $ir_order, 
        $family,    $genus,     $species,          $rna16s,
        $profileType, $category_display_type,
        $cateId2cateName_href, $cateName2cateId_href, $category2gcnt_href, 
        $unknownCount, $yesUnknownCountLink
      )
      = @_;

    #### PREPARE THE PIECHART ######
    my @chartcategories;
    my @cateids;
    my @chartdata;
    #################################

    my $url_mid = "&taxon_oid=$taxon_oid&percent_identity=$percent_identity";
    $url_mid .= "&data_type=$data_type" if ( $data_type );
    $url_mid .= "&rna16s=$rna16s"     if ( $rna16s );
    $url_mid .= "&domain=$domain"     if ( $domain );
    $url_mid .= "&phylum=$phylum"     if ( $phylum );
    $url_mid .= "&ir_class=$ir_class" if ( $ir_class );
    $url_mid .= "&family=$family"     if ( $family );
    $url_mid .= "&genus=$genus"       if ( $genus );
    $url_mid .= "&species=$species"   if ( $species );
    $url_mid .= "&plus=1"             if ( $plus );

    my $url2_base = "$main_cgi?section=$section&page=catefuncgenes";
    $url2_base .= $url_mid;
    $url2_base .= "&profileType=$profileType&cate_id=";

    # use below for purpose of sorting name
    my @cateNames;
    foreach my $cate_oid ( keys %$category2gcnt_href ) {
        my $cate_name  = $cateId2cateName_href->{$cate_oid};
        push(@cateNames, $cate_name);
    }

    my $gene_count_total = 0;
    foreach my $cate_name ( sort( @cateNames ) ) {
        my $cate_oid = $cateName2cateId_href->{$cate_name};
        my $gcount = $category2gcnt_href->{$cate_oid};
        $gene_count_total += $gcount;
    
        push @chartcategories, $cate_name;
        push @cateids,   $cate_oid;
        push @chartdata,       $gcount;
    }

    printD3Chart( \@chartcategories, \@cateids, \@chartdata, $url2_base, $gene_count_total, 
        $category_display_type, $unknownCount, $yesUnknownCountLink);
        
=pod
    # pie chart:
    my $idx = 0;
    my $d3data = "";
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $percent = 100 * $chartdata[$idx] / $gene_count_total;
        $percent = sprintf( "%.2f", $percent );

        if ($d3data) {
            $d3data .= ",";
        } else {
            $d3data = "[";
        }
        $d3data .= "{" . 
            "\"id\": \"" . escHtml($category1) . "\", 
            \"count\": " . $chartdata[$idx] . ", 
            \"name\": \"" . escHtml($category1) . "\", 
            \"urlfragm\": \"" . $cateids[$idx] .  "\", 
            \"percent\": " . $percent . 
        "}";
    
        $idx++;
    }

    if ( $d3data ) {
        if ($unknownCount > 0) {
            $d3data .= ",";
            if ( $yesUnknownCountLink ) {
                $d3data .= "{" .
                    "\"id\": \"" . "Not in $category_display_type" . "\", 
                    \"count\": " . $unknownCount . ", 
                    \"name\": \"" . "Not in $category_display_type" . "\", 
                    \"urlfragm\": \"" . $zzzUnknown . "\", 
                    \"draw\": \"" . "no" . "\"" . 
                    "}";
            }
            else {
                $d3data .= "{" .
                    "\"id\": \"" . "Not in $category_display_type" . "\", 
                    \"count\": " . $unknownCount . ", 
                    \"name\": \"" . "Not in $category_display_type" . "\", 
                    \"urlfragm\": \"" . "" . "\"" . 
                    "}";                
            }
        }

        $d3data .= "]";
        require D3ChartUtil;
        D3ChartUtil::printPieChart
            ($d3data, $url2_base, $url2_base, "", 0, 1,
             "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    }

#    if ( $d3data ) {
#        $d3data .= ",";
#        $d3data .= "{" .
#            "\"id\": \"" . "Not in $category_display_type" . "\", 
#            \"count\": " . $unknownCount . ", 
#            \"name\": \"" . "Not in $category_display_type" . "\", 
#            \"urlfragm\": \"" . "" . "\"" . 
#            "}";
#        
#        $d3data .= "]";
#        require D3ChartUtil;
#        D3ChartUtil::printPieChart($d3data, $url2_base, $url2_base, '', 0, 1, 
#            "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
#        #D3ChartUtil::printPieChart($d3data, '', $url2_base, '', 0, 0, '', 500, 400);
#    }
=cut

    return ( $gene_count_total );
}

sub printD3Chart {
    my ( $chartcategories_ref, $cateids_ref, $chartdata_ref, $url2_base, $gene_count_total, 
        $category_display_type, $unknownCount, $yesUnknownCountLink
      )
      = @_;

    #print "printD3Chart() chartcategories_ref: @$chartcategories_ref<br/>\n";
    #print "printD3Chart() cateids_ref: @$cateids_ref<br/>\n";
    #print "printD3Chart() chartdata_ref: @$chartdata_ref<br/>\n";

    my @chartcategories = @$chartcategories_ref;
    my @cateids = @$cateids_ref;
    my @chartdata = @$chartdata_ref;

    # pie chart:
    my $idx = 0;
    my $d3data = "";
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $percent = 100 * $chartdata[$idx] / $gene_count_total;
        $percent = sprintf( "%.2f", $percent );

        if ($d3data) {
            $d3data .= ",";
        } else {
            $d3data = "[";
        }
        $d3data .= "{" . 
            "\"id\": \"" . escHtml($category1) . "\", 
            \"count\": " . $chartdata[$idx] . ", 
            \"name\": \"" . escHtml($category1) . "\", 
            \"urlfragm\": \"" . $cateids[$idx] .  "\", 
            \"percent\": " . $percent . 
        "}";
    
        $idx++;
    }

    if ( $d3data ) {
        if ($unknownCount > 0) {
            $d3data .= ",";
            if ( $yesUnknownCountLink ) {
                $d3data .= "{" .
                    "\"id\": \"" . "Not in $category_display_type" . "\", 
                    \"count\": " . $unknownCount . ", 
                    \"name\": \"" . "Not in $category_display_type" . "\", 
                    \"urlfragm\": \"" . $zzzUnknown . "\", 
                    \"draw\": \"" . "no" . "\"" . 
                    "}";
            }
            else {
                $d3data .= "{" .
                    "\"id\": \"" . "Not in $category_display_type" . "\", 
                    \"count\": " . $unknownCount . ", 
                    \"name\": \"" . "Not in $category_display_type" . "\", 
                    \"urlfragm\": \"" . "" . "\"" . 
                    "}";                
            }
        }

        $d3data .= "]";
        require D3ChartUtil;
        D3ChartUtil::printPieChart
            ($d3data, $url2_base, $url2_base, "", 0, 1,
             "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    }

    #if ( $d3data ) {
    #    $d3data .= ",";
    #    $d3data .= "{" .
    #        "\"id\": \"" . "Not in $category_display_type" . "\", 
    #        \"count\": " . $unknownCount . ", 
    #        \"name\": \"" . "Not in $category_display_type" . "\", 
    #        \"urlfragm\": \"" . "" . "\"" . 
    #        "}";
    #    
    #    $d3data .= "]";
    #    require D3ChartUtil;
    #    D3ChartUtil::printPieChart($d3data, $url2_base, $url2_base, '', 0, 1, 
    #        "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    #    #D3ChartUtil::printPieChart($d3data, '', $url2_base, '', 0, 0, '', 500, 400);
    #}

}


1;
