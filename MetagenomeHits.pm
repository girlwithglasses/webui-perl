###########################################################################
# Phylogenetic Distribution of Genes from taxon detail page
# $Id: MetagenomeHits.pm 33936 2015-08-07 18:49:54Z klchu $
###########################################################################
package MetagenomeHits;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MetagJavaScript;
use MetagenomeGraph;
use PhylumTree;
use BarChartImage;
use ChartUtil;
use InnerTable;
use OracleUtil;
use HtmlUtil;
use ScaffoldCart;
use MyIMG;
use QueryUtil;
use MerFsUtil;
use PhyloUtil;

$| = 1;

my $env                      = getEnv();
my $cgi_dir                  = $env->{cgi_dir};
my $cgi_url                  = $env->{cgi_url};
my $main_cgi                 = $env->{main_cgi};
my $inner_cgi                = $env->{inner_cgi};
my $tmp_url                  = $env->{tmp_url};
my $verbose                  = $env->{verbose};
my $taxonomy_base_url        = $env->{taxonomy_base_url};
my $include_metagenomes      = $env->{include_metagenomes};
my $include_img_terms        = $env->{include_img_terms};
my $web_data_dir             = $env->{web_data_dir};
my $ncbi_entrez_base_url     = $env->{ncbi_entrez_base_url};
my $pubmed_base_url          = $env->{pubmed_base_url};
my $ncbi_project_id_base_url = $env->{ncbi_project_id_base_url};
my $img_internal             = $env->{img_internal};
my $img_lite                 = $env->{img_lite};
my $user_restricted_site     = $env->{user_restricted_site};
my $no_restricted_message    = $env->{no_restricted_message};
my $cgi_tmp_dir              = $env->{cgi_tmp_dir};
my $artemis_url              = $env->{artemis_url};
my $artemis_link             = alink( $artemis_url, "Artemis" );
my $mgtrees_dir              = $env->{mgtrees_dir};
my $show_mgdist_v2           = $env->{show_mgdist_v2};
my $myimg_job                = $env->{myimg_job};
my $contact_oid = WebUtil::getContactOid();
#my $maxOrthologGroups = 10;
#my $maxParalogGroups  = 100;

#MyIMG&page=preferences
my $preferences_url    = "$main_cgi?section=MyIMG&page=preferences";
my $max_gene_batch     = 900;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $taxon_stats_dir          = $env->{taxon_stats_dir};
my $taxon_faa_dir            = $env->{taxon_faa_dir};
my $taxon_fna_dir            = $env->{taxon_fna_dir};
my $taxon_genes_fna_dir      = $env->{taxon_genes_fna_dir};
my $taxon_intergenic_fna_dir = $env->{taxon_intergenic_fna_dir};
my $genes_dir                = $env->{genes_dir};
my $all_fna_files_dir        = $env->{all_fna_files_dir};

# also see MetaJavaSscript for this value too
# method checkSelect()
my $max_scaffold_list = 20;

# Initial list.
my $max_scaffold_list2 = 1000;

# For 2nd order list.
my $max_export_scaffold_list = 100000;

my $max_scaffold_results = 20000;

my $base_url = $env->{base_url};

my $YUI        = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

my $section = "MetagenomeHits";

my $unknown = "Unknown";

# make sure its last in sorting
my $zzzUnknown = "zzzUnknown";
my $mynull     = "mynull";

my $nvl = getNvl();

#
# dispatch - Dispatch to pages for this section.
#
# this is the hook into main.pl
# to get here, then I use section=??? to go the correct page after
#
sub dispatch {
    my $sid       = getContactOid();
    my $page      = param("page");
    my $taxon_oid = param("taxon_oid");

    if ( $page eq "showProfile"
        || paramMatch("showProfile") ne "" )
    {
        printMetagCateFunc();
        return;
    }

    if ( $page eq "metagenomeHits" ) {
        
        my $view = param("view");
        # test to see if cached file exists to turn off cgi caching
        my $file1 = param("cf1");

        if ( $view eq "cogfuncpath" ) {
            printMetagCogFuncPath();
        } else {

            if ( $file1 eq "" ) {
                HtmlUtil::cgiCacheInitialize( $section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printMetagenomeHits();
            HtmlUtil::cgiCacheStop() if ( $file1 eq "" );
        }

    } 
    elsif ( $page eq "cogfunclist" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;
        printMetagCateFunc('cogc');
        HtmlUtil::cgiCacheStop();

    } 
    elsif ( $page eq "catefuncgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagCateFuncGenes();
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "catefuncstatsgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagCateFuncGenes($page);
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "cogfunclistgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7 - fix for unknown
        printMetagCogFuncGene();
        HtmlUtil::cgiCacheStop();

    } 
    elsif ( $page eq "cogfunclistpath" ) {
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7
        printMetagCogFuncPath2();
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "cogpath" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;
        printMetagCateFunc('cogp');
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "cogpathgenes" ) {

       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7 - fix for unknown
        printMetagCogPathGene();
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "unassigned" ) {
        # test to see if cached file exists to turn off cgi caching
        my $file1 = param("cf1");
        if ( $file1 eq "" ) {
           HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;
        }
        printMetagenomeHits();
        HtmlUtil::cgiCacheStop() if ( $file1 eq "" );
    } 
    elsif ( $page eq "cogFuncStats" ) {
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeCogFuncStats();
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "cogStatsMetagenome" ) {
        BarChartImage::dispatch();
    } 
    elsif ( $page eq "cogPathStatsMetagenome" ) {
        BarChartImage::dispatch();
    } 
    elsif ( $page eq "compareCogFunc" ) {
       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeCogFuncCompare( $taxon_oid );
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "comparePathFunc" ) {
       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeCogPathCompare( $taxon_oid );
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "cogPathStats" ) {
       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeCogPathStats();
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "download" ) {
        checkAccess();
        PhyloUtil::download();
        WebUtil::webExit(0);

    } 
    elsif ( $page eq "ir_class_file"
        || $page eq "ir_order_file"
        || $page eq "family_file"
        || $page eq "genus_file"
        || $page eq "species_file" 
        ) {
        my ($taxonomy, $junk) = split( /_file/, $page );
        PhyloUtil::printFileTaxonomyPhyloDist( $section, $taxonomy );

    } 
    elsif ( $page eq "ir_class"
        || $page eq "ir_order"
        || $page eq "family"
        || $page eq "genus"
        || $page eq "species" 
        ) {
        PhyloUtil::printTaxonomyPhyloDist( $section, $page );

    } 
    elsif ( $page eq "taxonomyMetagHits" ) {
        # test to see if cached file exists to turn off cgi caching
        my $file1 = param("cf1");

        # on any family page when you click on the counts to go to
        # the cog functional break down page

        if ( $file1 eq "" ) {
           HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;
        }
        printTaxonomyMetagHits();

        HtmlUtil::cgiCacheStop() if ( $file1 eq "" );

    } 
    elsif ( $page eq "speciesForm" ) {
        # form to select metag scaffold and ref gene scaffold
        if ( ScaffoldCart::isCartEmpty() ) {

            # using caching iff scaffold cart if empty

            HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;

            PhyloUtil::printSpeciesStatsForm($section);

            HtmlUtil::cgiCacheStop();
        } else {

            # no caching if scaffold is being used
            PhyloUtil::printSpeciesStatsForm($section);
        }

    } 
    elsif ( $page eq "tree" ) {
        PhylumTree::dispatch();

    } 
    elsif ( $page eq "treebin" ) {
        require BinTree;
        BinTree::dispatch();

    } 
    elsif ( $page eq "binstats" ) {
        # all methods bin stat page
        PhyloUtil::printBinStats( $section, $taxon_oid );

    } 
    elsif ( $page eq "binmethodstats" ) {
        # bin stat page for a given method
        PhyloUtil::printBinMethodStats( $section, $taxon_oid );

    } 
    elsif ( $page eq "binfamilystats" ) {
        # family stat page for a given method and bin
        PhyloUtil::printBinFamilyStats( $section, $taxon_oid );

    } 
    elsif ( $page eq "binscatter" ) {
        PhyloUtil::printBinScatterPlotForm($section);

    } 
    elsif ( $page eq "binspecies" ) {
        PhyloUtil::printBinSpeciesPlotForm($section);

    } 
    elsif ( $page eq "metagtable" ) {
        printMetagenomeStatsResults();

    } 
    elsif ( $page eq "radialtree" ) {
        require RadialPhyloTree;
        RadialPhyloTree::runTree();

    #} 
    #elsif ( $page eq "computePhyloDistOnDemand" ) {
    #   use MyIMG;
    #   MyIMG::computePhyloDistOnDemand();

    } 
    else {
        # stats page by default
        # page = "metagenomeStats"
        my $dbh = dbLogin();


       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeStats( $dbh, $taxon_oid );

        HtmlUtil::cgiCacheStop();

        #$dbh->disconnect();
    }
}

#
# Print cog function compare page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
# param $difference difference value 2 to 10
#
sub printMetagenomeCogFuncCompare {
    my ( $taxon_oid ) = @_;

    my $percent       = param("perc");
    my $difference = param("difference");

    my $domain1   = param("domain1");
    my $phylum1   = param("phylum1");

    my $domain2   = param("domain2");
    my $phylum2   = param("phylum2");

    #
    # Get phylum grouping data
    #
    my @phylum_array;
    push( @phylum_array, "$domain1\t$phylum1" );
    push( @phylum_array, "$domain2\t$phylum2" );

    my $dbh       = dbLogin();

    my $rclause = PhyloUtil::getPercentClause( $percent );

    #
    # Get all the cog functions for given percentage
    #
    my $sql = qq{
        select dt.domain, dt.phylum,
            $nvl(cf.definition, '$zzzUnknown') as defn,
            count(dt.gene_oid)
        from dt_phylum_dist_genes dt
        left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
        left join cog_functions cfs on gcg.cog =  cfs.cog_id
        left join cog_function cf on cfs.functions = cf.function_code
        where dt.taxon_oid = ?
        and dt.domain in (?, ?)
        and dt.phylum in (?, ?)
        $rclause
        group by dt.domain, dt.phylum, $nvl(cf.definition, '$zzzUnknown')
   };

    my @binds = ( $taxon_oid, $domain1, $domain2, $phylum1, $phylum2 );

    # unassigned
    if ( $domain2 eq "unassigned" || $domain1 eq "unassigned" ) {
        my $clause = PhyloUtil::getPercentClause( $percent, 1 );

        $sql .= qq{
          union 
          SELECT 'unassigned', 'unassigned',
          $nvl(cf.definition, '$zzzUnknown') as defn,
          count(distinct a.gene_oid)
    FROM
  (SELECT g.gene_oid
   FROM gene g
   WHERE g.taxon = ?
   AND g.obsolete_flag = ? 
   AND g.locus_type = ? 
   minus
   SELECT dt.gene_oid
   FROM dt_phylum_dist_genes dt
   WHERE dt.taxon_oid = ?
   $clause
   ) a 
    LEFT JOIN gene_cog_groups gcg ON a.gene_oid = gcg.gene_oid 
    LEFT JOIN cog_functions cfs ON gcg.cog = cfs.cog_id 
    LEFT JOIN cog_function cf ON cfs.functions = cf.function_code
    group by 'unassigned', 'unassigned', $nvl(cf.definition, '$zzzUnknown')
        };

        push( @binds, $taxon_oid );
        push( @binds, 'No' );
        push( @binds, 'CDS' );
        push( @binds, $taxon_oid );
    }

    # hash of hashes
    # key is: cog function name
    # value is hash  key: "$domain\t$phylum" value: $gene_count
    my %cogFunctions;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $domain, $phylum, $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"$domain\t$phylum"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"$domain\t$phylum"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();

    # now get true gene counts without cog func duplicates
    my $bind;
    if ( $domain1 ne "unassigned" ) {
        $rclause .= " and dt.domain = ? ";
        $bind = $domain1;
    } elsif ( $domain2 ne "unassigned" ) {
        $rclause .= " and dt.domain = ? ";
        $bind = $domain2;
    }
    my $totalGeneCounts_href = getTrueGeneCounts( $dbh, $cur, $taxon_oid, $rclause, $percent, $bind );

    #$dbh->disconnect();

    my $text = "$phylum1 and $phylum2";

    print "<h1>Comparison Summary Statistics for $text COG Functional Categories" . " $percent%</h1>\n";
    PhyloUtil::printCogFuncStatTable( $section, $taxon_oid, '', \@phylum_array, \%cogFunctions, $difference, $totalGeneCounts_href );
}

#
# Print cog pathway compare page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
# param $difference difference value 2 to 10
#
sub printMetagenomeCogPathCompare {
    my ( $taxon_oid ) = @_;

    my $percent    = param("perc");
    my $difference = param("difference");

    my $domain1   = param("domain1");
    my $phylum1   = param("phylum1");

    my $domain2   = param("domain2");
    my $phylum2   = param("phylum2");

    #
    # Get phylum grouping data
    #
    my @phylum_array;
    push( @phylum_array, "$domain1\t$phylum1" );
    push( @phylum_array, "$domain2\t$phylum2" );

    my $dbh       = dbLogin();

    my $rclause = PhyloUtil::getPercentClause( $percent );

    #
    # Get all the cog functions for given percentage
    #
    my $sql = qq{
        select dt.domain, dt.phylum,
            $nvl(cp.cog_pathway_name, '$zzzUnknown'),
            count(dt.gene_oid)
        from dt_phylum_dist_genes dt
        left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
        left join cog_pathway_cog_members cpcm on gcg.cog = cpcm.cog_members
        left join cog_pathway cp on cpcm.cog_pathway_oid = cp.cog_pathway_oid
        where dt.taxon_oid = ?
        and dt.domain in (?, ?)
        and dt.phylum in (?, ?)
        $rclause 
        group by dt.domain, dt.phylum, $nvl(cp.cog_pathway_name, '$zzzUnknown')
   };

    my @binds = ( $taxon_oid, $domain1, $domain2, $phylum1, $phylum2 );

    if ( $domain2 eq "unassigned" || $domain1 eq "unassigned" ) {
        my $clause = PhyloUtil::getPercentClause( $percent, 1 );

        $sql .= qq{
          union 
          SELECT 'unassigned', 'unassigned',
          $nvl(cp.cog_pathway_name, '$zzzUnknown'),
          count(distinct a.gene_oid)
    FROM
  (SELECT g.gene_oid
   FROM gene g
   WHERE g.taxon = ?
   AND g.obsolete_flag = ? 
   AND g.locus_type = ? minus
   SELECT dt.gene_oid
   FROM dt_phylum_dist_genes dt
   WHERE dt.taxon_oid = ?
   $clause) a 
        left join gene_cog_groups gcg on a.gene_oid = gcg.gene_oid
        left join cog_pathway_cog_members cpcm on gcg.cog = cpcm.cog_members
        left join cog_pathway cp on cpcm.cog_pathway_oid = cp.cog_pathway_oid
    group by 'unassigned', 'unassigned', $nvl(cp.cog_pathway_name, '$zzzUnknown')
        };

        push( @binds, $taxon_oid );
        push( @binds, 'No' );
        push( @binds, 'CDS' );
        push( @binds, $taxon_oid );
    }

    # hash of hashes
    # key is: cog function name
    # value is hash  key: "$domain\t$phylum" value: $gene_count
    my %cogFunctions;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $domain, $phylum, $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        #my $strrec = "$domain\t$phylum\t$gene_count";
        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"$domain\t$phylum"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"$domain\t$phylum"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();
    #$dbh->disconnect();

    my $text = "$phylum1 and $phylum2";

    print "<h1>Comparison Summary Statistics for $text COG Pathway $percent%</h1>\n";
    PhyloUtil::printCogPathStatTable( $section, $taxon_oid, '', \@phylum_array, \%cogFunctions, $difference );
}

# Print cog function stats page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
#
sub printMetagenomeCogFuncStats {

    my $taxon_oid = param("taxon_oid");
    my $percent  = param("perc");
    my $plus  = param("plus");
    my $chart = param("chart");

    my $rclause = PhyloUtil::getPercentClause( $percent, $plus );

    my $dbh = dbLogin();
    #my $use_phylo_file = PhyloUtil::toUsePhyloFile( $taxon_oid );
    #todo $use_phylo_file == 1
    my @phylum_array = PhyloUtil::getPhylumArray( $dbh, $taxon_oid, $rclause );

    #
    # Get all the cog functions for given percentage
    #
    my $sql = qq{
        select dt.domain, dt.phylum,
            $nvl(cf.definition, '$zzzUnknown') as defn,
            count(dt.gene_oid)
        from dt_phylum_dist_genes dt
        left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
        left join cog_functions cfs on gcg.cog =  cfs.cog_id
        left join cog_function cf on cfs.functions = cf.function_code
        where dt.taxon_oid = ?
        $rclause 
        group by dt.domain, dt.phylum, $nvl(cf.definition, '$zzzUnknown')
   };
   #print "printMetagenomeCogFuncStats() sql=$sql<br/>\n";

    # hash of hashes
    # key is: cog function name
    # value is hash  key: "$domain\t$phylum" value: $gene_count
    my %cogFunctions;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $domain, $phylum, $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        #my $strrec = "$domain\t$phylum\t$gene_count";
        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"$domain\t$phylum"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"$domain\t$phylum"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();

    # unassigned
    my $clause = PhyloUtil::getPercentClause( $percent, 1 );

    # duplicate gene counts ?
    # get cog count to unassigned genes
    # remember the a cog can have more than one cog function assigned
    # to it, so the gene count can be higher, is this a bug ?
    # e.g. COG0834 gene 2001166110
    my $sql = qq{
SELECT $nvl(cf.definition, '$zzzUnknown') as defn,
        count(distinct a.gene_oid)
FROM
  (SELECT g.gene_oid
   FROM gene g
   WHERE g.taxon = $taxon_oid
   AND g.obsolete_flag = 'No'
   AND g.locus_type = 'CDS' minus
   SELECT dt.gene_oid
   FROM dt_phylum_dist_genes dt
   WHERE dt.taxon_oid = ?
   $clause) a 
LEFT JOIN gene_cog_groups gcg ON a.gene_oid = gcg.gene_oid 
LEFT JOIN cog_functions cfs ON gcg.cog = cfs.cog_id 
LEFT JOIN cog_function cf ON cfs.functions = cf.function_code
group by $nvl(cf.definition, '$zzzUnknown')
                };

    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"unassigned\tunassigned"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"unassigned\tunassigned"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();

    # now get true gene counts without cog func duplicates
    my $totalGeneCounts_href = getTrueGeneCounts( $dbh, $cur, $taxon_oid, $rclause, $percent );

    my $plusSign;
    if ( $plus ) {
        $plusSign = '+';
    }

    print "<h1>Summary Statistics of COG Functional Categories $percent%$plusSign</h1>\n";
    if ( $chart && ( $chart eq "yes" ) ) {
        PhyloUtil::printCogStatChart( $section, $taxon_oid, '', $percent, $plus, \%cogFunctions, "func" );
    } else {
        PhyloUtil::printCogFuncStatTable( $section, $taxon_oid, '', \@phylum_array, \%cogFunctions, 0, $totalGeneCounts_href );
    }
}

#
# some cog func groups use duplicate gene oid
sub getTrueGeneCounts {
    my ( $dbh, $cur, $taxon_oid, $rclause, $percent, $bind ) = @_;

    # now get true gene counts without cog func duplicates
    my %totalGeneCounts;
    my $sql = qq{
        select dt.domain, dt.phylum,
            count(distinct dt.gene_oid)
        from dt_phylum_dist_genes dt
        where dt.taxon_oid = ?
        $rclause 
        group by dt.domain, dt.phylum
   };

    if ( $bind ne "" ) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $bind );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    }
    for ( ; ; ) {
        my ( $domain, $phylum, $gene_count ) = $cur->fetchrow();
        last if !$domain;

        $totalGeneCounts{"$domain\t$phylum"} = $gene_count;

    }

    $cur->finish();

    my $clause = PhyloUtil::getPercentClause( $percent, 1 );

    # unassigned gene count
    my $sql = qq{
SELECT count(distinct gene_oid)
FROM
  (SELECT g.gene_oid
   FROM gene g
   WHERE g.taxon = ?
   AND g.obsolete_flag = 'No'
   AND g.locus_type = 'CDS' minus
   SELECT dt.gene_oid
   FROM dt_phylum_dist_genes dt
   WHERE dt.taxon_oid = ?
   $clause) 
                };

    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    for ( ; ; ) {
        my ($gene_count) = $cur->fetchrow();
        last if !$gene_count;

        $totalGeneCounts{"unassigned\tunassigned"} = $gene_count;

    }

    $cur->finish();
    return \%totalGeneCounts;
}

# Print cog pathway stats page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
#
sub printMetagenomeCogPathStats {

    my $taxon_oid = param("taxon_oid");
    my $percent  = param("perc");
    my $plus  = param("plus");
    my $chart = param("chart");

    my $rclause = PhyloUtil::getPercentClause( $percent, $plus );

    my $dbh = dbLogin();
    #my $use_phylo_file = PhyloUtil::toUsePhyloFile( $taxon_oid );
    #todo $use_phylo_file == 1
    my @phylum_array = PhyloUtil::getPhylumArray( $dbh, $taxon_oid, $rclause );

    #
    # Get all the cog functions for given percentage
    #
    my $sql = qq{
        select dt.domain, dt.phylum,
            $nvl(cp.cog_pathway_name, '$zzzUnknown'),
            count(dt.gene_oid)
        from dt_phylum_dist_genes dt
        left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
        left join cog_pathway_cog_members cpcm on gcg.cog = cpcm.cog_members
        left join cog_pathway cp on cpcm.cog_pathway_oid = cp.cog_pathway_oid
        where dt.taxon_oid = ?
        $rclause 
        group by dt.domain, dt.phylum, $nvl(cp.cog_pathway_name, '$zzzUnknown')
   };
   #print "printMetagenomeCogPathStats() sql=$sql<br/>\n";

    # hash of hashes
    # key is: cog function name
    # value is hash  key: "$domain\t$phylum" value: $gene_count
    my %cogFunctions;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $domain, $phylum, $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        #my $strrec = "$domain\t$phylum\t$gene_count";
        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"$domain\t$phylum"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"$domain\t$phylum"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();

    # unassigned
    my $clause = PhyloUtil::getPercentClause( $percent, 1 );

    # duplicate gene counts ?
    # get unassigned genes
    my $sql = qq{
SELECT $nvl(cp.cog_pathway_name, '$zzzUnknown') as defn,
        count(distinct a.gene_oid)
FROM
  (SELECT g.gene_oid
   FROM gene g
   WHERE g.taxon = ?
   AND g.obsolete_flag = 'No'
   AND g.locus_type = 'CDS' minus
   SELECT dt.gene_oid
   FROM dt_phylum_dist_genes dt
   WHERE dt.taxon_oid = ?
   $clause) a 
        left join gene_cog_groups gcg on a.gene_oid = gcg.gene_oid
        left join cog_pathway_cog_members cpcm on gcg.cog = cpcm.cog_members
        left join cog_pathway cp on cpcm.cog_pathway_oid = cp.cog_pathway_oid
group by $nvl(cp.cog_pathway_name, '$zzzUnknown')
                };

    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    for ( ; ; ) {
        my ( $defn, $gene_count ) = $cur->fetchrow();
        last if !$defn;

        if ( exists( $cogFunctions{$defn} ) ) {
            my $href_tmp = $cogFunctions{$defn};
            $href_tmp->{"unassigned\tunassigned"} = $gene_count;
        } else {
            my %tmp;
            $tmp{"unassigned\tunassigned"} = $gene_count;
            $cogFunctions{$defn} = \%tmp;
        }
    }

    $cur->finish();

    #$dbh->disconnect();

    my $plusSign;
    if ( $plus ) {
        $plusSign = '+';
    }

    print "<h1>Summary Statistics of COG Pathways $percent%$plusSign</h1>\n";
    if ( $chart && ( $chart eq "yes" ) ) {
        PhyloUtil::printCogStatChart( $section, $taxon_oid, '', $percent, $plus, \%cogFunctions, "path" );
    } else {
        PhyloUtil::printCogPathStatTable( $section, $taxon_oid, '', \@phylum_array, \%cogFunctions, 0 );
    }
}

sub printForm {
    my ( $dbh, $taxon_oid ) = @_;

    my $phyloDist_date = PhyloUtil::getPhyloDistDate( $dbh, $taxon_oid );
    #my $phyloDist_method = PhyloUtil::getPhyloDistMethod( $dbh, $taxon_oid );

    print "<h1>Phylogenetic Distribution of Genes in Genome</h1>";
    PhyloUtil::printTaxonNameAndPhyloDistDate( $dbh, $taxon_oid, $phyloDist_date );
    PhyloUtil::printPhyloDistMessage_GenesInGenome();

    printStatusLine( "Loading ...", 1 );

    use TabHTML;
    TabHTML::printTabAPILinks("metahitsTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("metahitsTab");
        </script>
    }; 
 
    my @tabIndex = ( "#metahitstab1", "#metahitstab2" );
    my @tabNames = ( "Table View", "Tree View" );
    TabHTML::printTabDiv("metahitsTab", \@tabIndex, \@tabNames);
    print "<div id='metahitstab1'>";

#    print "<p>";
#    print "View the phylogenetic distribution of genes for "
#	. "selected percent identity in a tabulated format.";
#    print "</p>";

    printMainForm();

    print "<p>\n";

    print qq{
        <b>Percent Identity</b><br />
        <input type='radio' name="percentage" value='suc' checked='checked' onClick='enableHits("suc")' />
        Successive (30% to 59%, 60% to 89%, 90%+)<br />
        <input type='radio' name="percentage" value='cum' onClick='enableHits("cum")' />
        Cumulative (30%+, 60%+, 90%+)
        <span style='padding-left:5em'><input id='hitChk' type='checkbox' name='show_hits' disabled='disabled' />
        <label for='hitChk'>Display hit genome count (slow)</label></span><br/>
    };

    print qq{
        <br/>
        <b>Distribution By</b><br/>
        <input type='radio' name='xcopy' value='gene_count' checked='checked' />
        Gene count <br/>
        <input type='radio' name='xcopy' value='est_copy' />
        Estimated gene copies <br/>
    };

    print qq{
        <br/>
        <b>Display Options</b><br/>
        <input type='checkbox' name='show_percentage' checked='checked' /> &nbsp; Show percentage column<br/>
        <input type='checkbox' name='show_hist' checked='checked' /> &nbsp; Show histogram column
    };

    print "</p>\n";

    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "metagtable" );
    print hiddenVar( "taxon_oid",  $taxon_oid );
    print hiddenVar( "fromviewer", "MetagPhyloDist" );
    print hiddenVar( "metag",      "1" );

    print submit(
          -name  => "",
          -value => "Go",
          -class => "smdefbutton"
    );

    print nbsp(3);
    print reset(
         -name  => "",
         -value => "Reset",
         -class => "smbutton"
    );
    print end_form();

    print "</div>"; # end metahitstab1
 
    print "<div id='metahitstab2'>"; 

    print start_form( -name => "treeForm", -action => $main_cgi );
    print "<p>View the phylogenetic distribution of genes in a "
	. "radial tree format.</p>";

    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "radialtree" );
    print hiddenVar( "selectedGenome1",  $taxon_oid );
    print hiddenVar( "fromviewer",       "TreeFileMgr" );

    print submit(
          -name  => "",
          -value => "Draw Tree",
          -class => "smdefbutton"
    );
    print end_form();

    print "</div>"; # end metahitstab2
    TabHTML::printTabDivEnd(); 

    printStatusLine( "Loaded.", 2 );
}

# main page
#
# print start stats page
#
# param $dbh database handler
# param $taxon_oid taxon oid
#
sub printMetagenomeStats {
    my ( $dbh, $taxon_oid ) = @_;

    MetagJavaScript::printFormJS();

    # Split subroutine to accept user input such as percent identity - Biju
    printForm( $dbh, $taxon_oid );
}

###############################################################################
# printMetagenomeStatsResults: this is the subroutine that prints out         
#     the phylo distribution result                                            
###############################################################################
sub printMetagenomeStatsResults {
    
    my $percentage         = param("percentage");  # "suc"=30-59,60-89,90+;
                                                   # "cum"=30+,60+,90+
    my $xcopy              = param("xcopy");       # gene_count, est_copy
    my $gene_count_file    = param("gene_count_file");
    my $homolog_count_file = param("homolog_count_file");
    my $genome_count_file  = param("genome_count_file");
    my $show_percentage    = param("show_percentage");
    my $show_hist          = param("show_hist");
    my $show_hits          = param("show_hits");
    my $taxon_oid          = param("taxon_oid");
    my @filters            = param("filter");      # filter on selected phyla

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ($totalGeneCount, $totalCopyCount);

    # Gene count SQL
    my $gcSql = qq{
        select ts.cds_genes
        from taxon_stats ts
        where ts.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $gcSql, $verbose, $taxon_oid );
    ($totalGeneCount) = $cur->fetchrow();
    $cur->finish();

    if ( $xcopy eq 'est_copy' ) {
        my $sql = qq{
            select sum(g.est_copy)
            from  gene g
            where g.taxon = ?
            and g.locus_type = 'CDS'
        };        
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        ($totalCopyCount) = $cur->fetchrow();
        $cur->finish();
    }
    # if est_copy unavailable, use gene count instead
    my $noEstCopy = 0;
    if (!$totalCopyCount && ($xcopy eq 'est_copy')) {
    	$totalCopyCount = $totalGeneCount;
    	$noEstCopy = 1;	
    }

    # read "$taxon_stats_dir/$taxon_oid.phylumDist.$perc_identity.tab.txt"
    # to get the stats - ken

    $show_hits = "on" if $percentage eq "suc";    # always show genome hit counts if successive
    my $plus = ( $percentage eq "cum" ) ? "+" : "";    # display "+" if cumulative

    my ( $pcId_ref, $totalCount_href, $stats_href, $genomeHitStats_href, $orgCount_href );

    my ( $found_href, $total_href,
    $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
    $depth30_href, $depth60_href, $depth90_href );

    my $use_phylo_file = PhyloUtil::toUsePhyloFile( $taxon_oid );
    if ( $use_phylo_file ) {
        printStartWorkingDiv();
        
        ( $totalCopyCount, $found_href, $total_href,
        $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
        $depth30_href, $depth60_href, $depth90_href ) 
            = PhyloUtil::loadFileBestBlastHits( $dbh, $taxon_oid, 'assembled', '', $xcopy, $totalGeneCount );        

        printEndWorkingDiv();

        if ( scalar( keys %$found_href ) == 0 ) {
            printMessage("No phylogenetic distribution has been computed here.");
            printStatusLine( "Loaded.", 2 );
            return;
        }

    }
    else {
        printStartWorkingDiv();

        ( $pcId_ref, $totalCount_href, $stats_href, $genomeHitStats_href, $orgCount_href ) 
          = PhyloUtil::loadBestBlastHits( $dbh, $taxon_oid, $xcopy, $show_hits, $plus );

        printEndWorkingDiv();

        if ( $totalCount_href->{30} + $totalCount_href->{60} + $totalCount_href->{90} == 0 ) {
            printMessage("No phylogenetic distribution has been computed here.");
            printStatusLine( "Loaded.", 2 );
            return;
        }

    }

    PhyloUtil::printMetagenomeStatsResultsCore( $dbh, $use_phylo_file, $section, 
        $taxon_oid, 'assembled', '', $xcopy, $show_hist, $show_hits, $show_percentage, 
        $gene_count_file, $homolog_count_file, $genome_count_file, \@filters,
        $plus, $totalGeneCount, $totalCopyCount, $found_href, $total_href,
        $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
        $depth30_href, $depth60_href, $depth90_href,
        $noEstCopy, $pcId_ref, $stats_href, $genomeHitStats_href, $orgCount_href );

}

###############################################################################
# sub printMetagCateFuncGenes
###############################################################################
sub printMetagCateFuncGenes {
    my ( $page ) = @_;
    
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');
    my $plus             = param("plus");

    my $domain  = param("domain");
    my $phylum  = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    my $cogfunc = param("cogfunc");

    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    if ( $page ne "catefuncstatsgenes" ) {
        PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent_identity, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );        
    }
    else {
        my @taxon_array = ( $taxon_oid );
        PhyloUtil::printGenomeListSubHeader( $dbh, \@taxon_array );        
    }

    my $profileType = param('profileType');
    my $category_display_type = PhyloUtil::getFuncTextVal($profileType);
    if ( !$category_display_type ) {
        webError("Unknown function type: $profileType\n"); 
    }
    print "<h3>\n";
    print "$category_display_type Gene List";
    print "</h3>\n";

    my $cate_id = param('cate_id');
    if ( !$cate_id ) {
        webError("No function is selected.\n");
    }
    
    my ($category_name) = PhyloUtil::getCategoryName( $dbh, $profileType, $cate_id );
    print "<p>\n";
    print "$category_name";
    print "</p>\n";

    # print table of function and gene count
    my $it = new InnerTable( 1, "catefuncgene$$", "catefuncgene", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "char asc",    "left" );
    $it->addColSpec( "Percent Identity",  "number desc", "right" );
    $it->addColSpec( "Function ID",       "char asc",    "left" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );

    my $select_id_name = "gene_oid";

    #get hit genes
    my ($gene_oids_ref, $percentHits_href, $count, $trunc) = processMetagenomeHitGenes($dbh,
        $taxon_oid, $data_type, $percent_identity, $plus, $rna16s, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species);
    #print "printMetagCateFuncGenes() percentHits_href:<br/>\n";
    #print Dumper($percentHits_href);
    #print "<br/>\n";

    my @funcs;
    if ( $cate_id && $cate_id ne $zzzUnknown ) {
        @funcs = PhyloUtil::getFuncsFromCategoryId( $dbh, $profileType, $cate_id );    
    }
    my %gene2func_h = getGene2Funcs( $dbh, $profileType, $gene_oids_ref, \@funcs );
    #print "printMetagCateFuncGenes() gene2func_h:<br/>\n";
    #print Dumper \%gene2func_h;
    #print "<br/>\n";

    my @validGenes;
    my %oid2name_h;
    if ( $cate_id && $cate_id ne $zzzUnknown ) {
        @validGenes = keys %gene2func_h;
    }
    else {
        foreach my $gene_oid (@$gene_oids_ref) {
            next if ( $gene2func_h{$gene_oid} );
            push(@validGenes, $gene_oid);            
        }
    }
    my %oid2name_h = QueryUtil::fetchGeneNames( $dbh, @validGenes );

    my $gene_cnt = 0;
    my $trunc    = 0;
    for my $gene_oid (@validGenes) {
        my $row = $sd
          . "<input type='checkbox' name='$select_id_name' value='$gene_oid' checked />\t";
        my $url = "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        
        my $perc_identity;
        if ( $percentHits_href ) {
            $perc_identity = $percentHits_href->{ $gene_oid };
        }
        $row .= $perc_identity . $sd . $perc_identity . "\t";

        my $funcs_str;
        if ( $cate_id && $cate_id ne $zzzUnknown ) {
            my $funcs_href = $gene2func_h{$gene_oid};
            my @func_ids = keys %$funcs_href;
            $funcs_str = join(',', @func_ids);
        }        
        $row .= $funcs_str . $sd . $funcs_str . "\t";

        my $gene_name = $oid2name_h{$gene_oid};
        $row .= $gene_name . $sd . $gene_name . "\t";

        $it->addRow($row);
        $gene_cnt++;
        if ( $gene_cnt >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }    # end for gene_info

    if ($gene_cnt) {
        WebUtil::printGeneCartFooter() if ( $gene_cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_cnt gene(s) retrieved", 2 );
    }
}


sub printMetagCogPathGene {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $plus             = param('plus');
    my $rna16s           = param('rna16s');    

    my $domain           = param("domain");
    my $phylum           = param("phylum");
    my $ir_class         = param("ir_class");
    my $ir_order         = param("ir_order");
    my $family           = param("family");
    my $genus            = param("genus");
    my $species          = param("species");

    my $cogpath          = param("cogpath");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();    

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        
    print "<h3>COG Pathway Gene List</h3>";
    PhyloUtil::printCogFuncTitle( $cogpath, 1 );

    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }

    my $cclause = "";
    my @binds_c_clause;
    if ( $cogpath eq $zzzUnknown ) {
        $cclause .= " and cp.cog_pathway_name is null ";
    } else {
        $cclause .= " and cp.cog_pathway_name = ? ";
        push( @binds_c_clause, $cogpath );
    }

    my ($rclause, $taxonomyClause, $binds_t_clause_ref, 
        $gene_oid_str, $percentHits_href, $cogcount_href)
        = getMetagCogCount( $dbh, $use_phylo_file, $cclause, \@binds_c_clause, 2,
        $taxon_oid, $percent_identity, $data_type, $rna16s, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species);
    my @binds_t_clause = @$binds_t_clause_ref if ( $binds_t_clause_ref );

    # new query and new binds
    my $sql;
    my @binds;

    if ( $use_phylo_file ) {

        my $urclause = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        $sql = qq{
           select distinct g.gene_oid, g.gene_display_name, '', cfs.cog_id
           from gene g
           left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
           left join cog_functions cfs on gcg.cog = cfs.cog_id
           left join cog_pathway cp on cfs.functions = cp.function
           where g.gene_oid in ( $gene_oid_str )
           $cclause
           $urclause
           $imgClause
        };
        @binds = ();
        push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );        

    }
    else {

        if ( $domain eq "" ) {
            # unassigned
            my $clause = PhyloUtil::getPercentClause( $percent_identity, 1 );
            
            if ( $cogpath eq $zzzUnknown ) {
        
                # unassigned
                #
                # genes with no cog paths
                #
                $sql = qq{
                    select distinct abc.gene_oid, g.gene_display_name, '', c.cog_id
                    from gene g 
                    left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
                    left join cog c on gcg.cog = c.cog_id, 
                    (
                        select distinct gene_oid 
                        from (
                            select gene_oid
                            from ( 
                                select distinct g.gene_oid
                                from gene g
                                where g.taxon       =  ?
                                and g.obsolete_flag = 'No'
                                and g.locus_type    = 'CDS' 
                                minus
                                select dt.gene_oid
                                from dt_phylum_dist_genes dt
                                where dt.taxon_oid      = ?
                                $clause
                            ) 
                            minus
                            select gcg.gene_oid
                            from gene_cog_groups gcg, cog c, cog_functions cf, cog_pathway cp
                            where gcg.cog = c.cog_id
                            and c.cog_id = cf.cog_id
                            and cf.functions = cp.function
                            and gcg.gene_oid in (
                                select g.gene_oid
                                from gene g
                                where g.taxon       = ?
                                and g.obsolete_flag = 'No'
                                and g.locus_type    = 'CDS' 
                                minus
                                select dt.gene_oid
                                from dt_phylum_dist_genes dt
                                where dt.taxon_oid      = ?
                                $clause
                            )
                        )
                    ) abc
                    where g.gene_oid = abc.gene_oid
                };
        
                @binds = ( $taxon_oid, $taxon_oid, $taxon_oid, $taxon_oid );
        
            } else {    
                # fix
                # unassigned - but with cog pathways
                $sql = qq{
                    select distinct g.gene_oid, g.gene_display_name, '', c.cog_id
                    from gene g, gene_cog_groups gcg, cog c, cog_functions cf, cog_pathway cp
                    where g.gene_oid = gcg.gene_oid
                    and gcg.cog = c.cog_id
                    and c.cog_id = cf.cog_id
                    and cf.functions = cp.function
                    and cp.cog_pathway_name = ?
                    and gcg.gene_oid in (
                        select g.gene_oid
                        from gene g
                        where g.taxon       = ?
                        and g.obsolete_flag = 'No'
                        and g.locus_type    = 'CDS' 
                        minus
                        select dt.gene_oid
                        from dt_phylum_dist_genes dt
                        where dt.taxon_oid      = ?
                        $clause
                    )
                };
                @binds = ( $cogpath, $taxon_oid, $taxon_oid );
            }        
        
        }
        else {
            if ( $cogpath eq $zzzUnknown ) {
        
                #  unknown for cog path view table
                $sql = qq{
                    select distinct abc2.gene_oid, g2.gene_display_name, '', c2.cog_id
                    from gene g2 
                    left join gene_cog_groups gcg2 on g2.gene_oid = gcg2.gene_oid
                    left join cog c2 on gcg2.cog = c2.cog_id, 
                    (
                        select dt.gene_oid
                        from gene g, taxon t, dt_phylum_dist_genes dt 
                        where dt.taxon_oid = ?
                        and g.taxon = t.taxon_oid
                        and g.gene_oid = dt.homolog 
                        and dt.homolog_taxon = t.taxon_oid
                        $rclause
                        $taxonomyClause
                        minus
                        select gcg.gene_oid
                        from gene_cog_groups gcg, cog c, cog_functions cf, cog_pathway cp
                        where gcg.cog = c.cog_id 
                        and c.cog_id = cf.cog_id
                        and cf.functions = cp.function
                        and gcg.gene_oid in (
                            select dt.gene_oid
                            from gene g, taxon t, dt_phylum_dist_genes dt 
                            where dt.taxon_oid = ?
                            and g.taxon = t.taxon_oid
                            and g.gene_oid = dt.homolog 
                            and dt.homolog_taxon = t.taxon_oid
                            $rclause
                            $taxonomyClause
                        )
                    ) abc2
                    where g2.gene_oid = abc2.gene_oid       
                };
                @binds = ($taxon_oid);
                push( @binds, @binds_t_clause ) if ( $#binds_t_clause > -1 );        
                push( @binds, $taxon_oid );        
                push( @binds, @binds_t_clause ) if ( $#binds_t_clause > -1 ); 
            }
            else {
                $sql = qq{
                    select distinct abc.gene_oid, g.gene_display_name, abc.percent_identity, c.cog_id
                    from gene g, gene_cog_groups gcg, cog c, cog_functions cf, cog_pathway cp,
                    (
                        select dt.gene_oid, dt.percent_identity
                        from gene g2, taxon t, dt_phylum_dist_genes dt 
                        where dt.taxon_oid = ?
                        and g2.taxon = t.taxon_oid
                        and g2.gene_oid = dt.homolog
                        and dt.homolog_taxon = t.taxon_oid
                        $rclause
                        $taxonomyClause
                    ) abc
                    where gcg.cog = c.cog_id 
                    and c.cog_id = cf.cog_id
                    and cf.functions = cp.function
                    and cp.cog_pathway_name = ?
                    and gcg.gene_oid = abc.gene_oid
                    and g.gene_oid = gcg.gene_oid
                };
                @binds = ($taxon_oid);
                push( @binds, @binds_t_clause ) if ( $#binds_t_clause > -1 );        
                push( @binds, $cogpath );
                
            } 
        }

    }  
    #print "printMetagCogPathGene() sql: $sql<br/>\n";
    #print "printMetagCogPathGene() binds: @binds<br/>\n";
      
    my ( $distinctcount, $count ) = printGeneListTable( $dbh, $sql, \@binds, $cogcount_href, $percentHits_href );

    printStatusLine( "$distinctcount ($count) loaded.", 2 );
}


#
#
#
sub printMetagCogFuncGene {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $plus             = param('plus');

    my $rna16s           = param('rna16s');
    my $domain           = param("domain");
    my $phylum           = param("phylum");
    my $ir_class         = param("ir_class");
    my $ir_order         = param("ir_order");
    my $family           = param("family");
    my $genus            = param("genus");
    my $species          = param("species");

    my $cogfunc          = param("cogfunc");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    print "<h3>Cog Functional Category Gene List</h3>";
    PhyloUtil::printCogFuncTitle( $cogfunc );
        
    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }

    my $cclause = "";
    my @binds_c_clause;
    if ( $cogfunc eq $zzzUnknown ) {
        $cclause .= " and cf.definition is null ";
    } else {
        $cclause .= " and cf.definition = ? ";
        push( @binds_c_clause, $cogfunc );
    }

    my ($rclause, $taxonomyClause, $binds_t_clause_ref, 
        $gene_oid_str, $percentHits_href, $cogcount_href)
        = getMetagCogCount( $dbh, $use_phylo_file, $cclause, \@binds_c_clause, 1,
        $taxon_oid, $percent_identity, $data_type, $rna16s, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species);
    my @binds_t_clause = @$binds_t_clause_ref if ( $binds_t_clause_ref );

    my $sql;
    my @binds;

    if ( $use_phylo_file ) {

        my $urclause = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        $sql = qq{
           select distinct g.gene_oid, g.gene_display_name, '', cfs.cog_id
           from gene g
           left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
           left join cog_functions cfs on gcg.cog = cfs.cog_id
           left join cog_function cf on cf.function_code = cfs.functions
           where g.gene_oid in ( $gene_oid_str )
           $cclause
           $urclause
           $imgClause
        };
        @binds = ();
        push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );        

    }
    else {
        if ( $domain eq "" ) {
        
            # Unassigned
            my $rclause = PhyloUtil::getPercentClause( $percent_identity, 1 );    
            $sql = qq{
               select distinct g.gene_oid, g.gene_display_name, ' ', cfs.cog_id
               from gene g 
               left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
               left join cog_functions cfs on gcg.cog = cfs.cog_id
               left join cog_function cf on cf.function_code = cfs.functions
               where g.taxon = ?
               and g.gene_oid in (
                 select distinct g2.gene_oid
                 from gene g2
                 where g2.taxon = ?
                 and g2.obsolete_flag = 'No'
                 and g2.locus_type = 'CDS'
                 minus 
                 select dt.gene_oid
                 from dt_phylum_dist_genes dt
                 where dt.taxon_oid = ?
                 $rclause
               )        
               $cclause
            };
            @binds = ( $taxon_oid, $taxon_oid, $taxon_oid );
            push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );

        }
        else {

            my $urclause = WebUtil::urClause("dt.homolog_taxon");
            my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
    
            # new binds
            $sql = qq{
               select distinct dt.gene_oid, g.gene_display_name, dt.percent_identity, cfs.cog_id
               from gene g, taxon t, dt_phylum_dist_genes dt 
               left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
               left join cog_functions cfs on gcg.cog = cfs.cog_id
               left join cog_function cf on cf.function_code = cfs.functions
               where dt.taxon_oid = ?
               and dt.homolog_taxon = t.taxon_oid
               and dt.homolog = g.gene_oid
               and g.taxon = t.taxon_oid
               $rclause
               $taxonomyClause
               $cclause
               $urclause
               $imgClause
            };
            @binds = ( $taxon_oid );
            push( @binds, @binds_t_clause ) if ( $#binds_t_clause > -1 );
            push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );
            
        }        
    }
    #print "printMetagCogFuncGene() sql: $sql<br/>\n";
    #print "printMetagCogFuncGene() binds: @binds<br/>\n";

    my ( $distinctcount, $count ) = printGeneListTable( $dbh, $sql, \@binds, $cogcount_href, $percentHits_href );

    if ( $use_phylo_file ) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $gene_oid_str =~ /gtt_num_id/i );
    }

    printStatusLine( "$distinctcount ($count) loaded.", 2 );
    #$dbh->disconnect();
}

sub getMetagCogCount {
    my ( $dbh, $use_phylo_file, $cclause, $binds_c_clause_ref, $cogFuncOrPath,
        $taxon_oid, $percent_identity, $data_type, $rna16s, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species
     ) = @_;
    #$cogFuncOrPath 1: cogFunc, 2: cogPath

    my @binds_c_clause = @$binds_c_clause_ref;
    
    # query
    my $rclause = "";
    my $taxonomyClause;
    my $binds_t_clause_ref;

    my $gene_oid_str;
    my %percentHits;
        
    my $sql;
    my @binds;    
    if ( $use_phylo_file ) {

        my @workspace_ids_data;
        PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $data_type, $percent_identity, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $rna16s, 0, '', \@workspace_ids_data );

        my @gene_oids;
        for my $r (@workspace_ids_data) {        
            my (
                $workspace_id, $per_cent, $homolog_gene,
                $homo_taxon, $copies, @rest
              )
              = split( /\t/, $r );

            my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
            push( @gene_oids, $gene_oid2 );
            $percentHits{$gene_oid2} = $per_cent;
        }
        $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );

        my $urclause = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        if ( $cogFuncOrPath == 1 ) {
            $sql = qq{
                select cog, count(*)
                from gene_cog_groups 
                where cog in(        
                   select cfs.cog_id
                   from gene_cog_groups g 
                   left join cog_functions cfs on g.cog = cfs.cog_id
                   left join cog_function cf on cf.function_code = cfs.functions
                   where g.gene_oid in ( $gene_oid_str )
                   $cclause
                   $urclause
                   $imgClause
                )
                group by cog
            };            
        }
        elsif ( $cogFuncOrPath == 2 ) {

            $sql = qq{
                select cog, count(*)
                from gene_cog_groups 
                where cog in(        
                   select cfs.cog_id
                   from gene_cog_groups g 
                   left join cog_functions cfs on g.cog = cfs.cog_id
                   left join cog_pathway cp on cfs.functions = cp.function
                   where g.gene_oid in ( $gene_oid_str )
                   $cclause
                   $urclause
                   $imgClause
                )
                group by cog
            };            
        }
        @binds = ( );
        push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );        

    }
    else {

        if ( $domain eq "" ) {

            # Unassigned
            my $urclause = WebUtil::urClause("g.taxon");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
            if ( $cogFuncOrPath == 1 ) {
                $sql = qq{
                    select cog, count(*)
                    from gene_cog_groups 
                    where cog in (
                        select cfs.cog_id
                        from gene_cog_groups g 
                        left join cog_functions cfs on g.cog = cfs.cog_id
                        left join cog_function cf on cf.function_code = cfs.functions
                        where g.taxon = ?
                        $cclause
                        $urclause
                        $imgClause
                    )
                    group by cog
                };
            }
            elsif ( $cogFuncOrPath == 2 ) {
                $sql = qq{
                    select cog, count(*)
                    from gene_cog_groups 
                    where cog in (
                        select cfs.cog_id
                        from gene_cog_groups g 
                        left join cog_functions cfs on g.cog = cfs.cog_id
                        left join cog_pathway cp on cfs.functions = cp.function
                        where g.taxon = ?
                        $cclause
                        $urclause
                        $imgClause
                    )
                    group by cog
                };
            }
            @binds = ($taxon_oid);
            push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );
        }
        else {

            # query
            $rclause = PhyloUtil::getPercentClause( $percent_identity, $plus );

            ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        
            my $urclause = WebUtil::urClause("dt.homolog_taxon");
            my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');

            if ( $cogFuncOrPath == 1 ) {
                $sql = qq{
                    select cog, count(*)
                    from gene_cog_groups 
                    where cog in(        
                       select cfs.cog_id
                       from taxon t, dt_phylum_dist_genes dt 
                       left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
                       left join cog_functions cfs on gcg.cog = cfs.cog_id
                       left join cog_function cf on cf.function_code = cfs.functions
                       where dt.taxon_oid = ?
                       and dt.homolog_taxon = t.taxon_oid
                       $rclause
                       $taxonomyClause
                       $cclause
                       $urclause
                       $imgClause
                    )
                    group by cog
                };
            }
            elsif ( $cogFuncOrPath == 2 ) {
                $sql = qq{
                    select cog, count(*)
                    from gene_cog_groups 
                    where cog in(        
                       select cfs.cog_id
                       from taxon t, dt_phylum_dist_genes dt 
                       left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
                       left join cog_functions cfs on gcg.cog = cfs.cog_id
                       left join cog_pathway cp on cfs.functions = cp.function
                       where dt.taxon_oid = ?
                       and dt.homolog_taxon = t.taxon_oid
                       $rclause
                       $taxonomyClause
                       $cclause
                       $urclause
                       $imgClause
                    )
                    group by cog
                };
            }

            @binds = ( $taxon_oid );
            push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref && scalar(@$binds_t_clause_ref) > 0 );        
            push( @binds, @binds_c_clause ) if ( $#binds_c_clause > -1 );        
        }

    }
    #print "getMetagCogCount() sql: $sql<br/>\n";
    #print "getMetagCogCount() binds: @binds<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my %cogcount_hash;
    for ( ; ; ) {
        my ( $cog_oid, $count ) = $cur->fetchrow();
        last if !$cog_oid;
        $cogcount_hash{$cog_oid} = $count;
    }
    $cur->finish();
    #print Dumper \%cogcount_hash;
    #print "<br/>\n";
    
    return ($rclause, $taxonomyClause, $binds_t_clause_ref, 
        $gene_oid_str, \%percentHits, \%cogcount_hash);
}


sub printGeneListTable {
    my ( $dbh, $sql, $binds_ref, $cogcount_href, $percentHits_href ) = @_;

    my @binds = @$binds_ref;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $count = 0;
    my %distinctgenes;

    my $it = new InnerTable( 1, "metacyc$$", "metacyc", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "char asc",    "left" );
    $it->addColSpec( "Percent",           "number desc", "right" );
    $it->addColSpec( "COG ID",            "char desc",   "left" );
    $it->addColSpec( "COG Gene Count",    "number desc", "right" );
    $it->addColSpec( "Gene Product Name", "char desc",   "left" );

    for ( ; ; ) {
        my ( $gene_oid, $name, $percent, $cog_oid ) = $cur->fetchrow();
        last if !$gene_oid;

        $distinctgenes{$gene_oid} = 1;

        # checkbox
        my $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' />" . "\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $url = alink( $url, $gene_oid );

        $r .= $gene_oid . $sd . $url . "\t";

        if ( $percent eq '' && $percentHits_href ne '' && defined($percentHits_href) ) {
            $percent = $percentHits_href -> { $gene_oid };
        }
        $r .= $percent . $sd . $percent . "\t";            

        $r .= $cog_oid . $sd . $cog_oid . "\t";

        my $cogcount = $cogcount_href->{$cog_oid};
        if ( $cogcount eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {

            $r .= $cogcount . $sd . $cogcount . "\t";
        }
        $r .= $name . $sd . $name . "\t";

        $it->addRow($r);

        $count++;
    }
    $cur->finish();

    my $distinctcount = keys %distinctgenes;

    printMainForm();
    printGeneCartFooter() if ( $distinctcount > 10 );
    $it->printOuterTable(1) ;
    printGeneCartFooter();
    print end_form();

    return ( $distinctcount, $count );
}

sub printMetagCogFuncPath2 {
    my $taxon_oid        = param("taxon_oid");
    my $percent_identity = param("percent_identity");
    my $plus             = param("plus");

    my $domain  = param("domain");
    my $phylum  = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    my $cogfunc = param("cogfunc");
    my $name = $cogfunc;
    if ( $cogfunc eq $zzzUnknown ) {
        $name = "Unknown";
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    print "<h3>COG Functional Category Pathways</h3>\n";
    PhyloUtil::printCogFuncTitle( $cogfunc );

    # query
    my $clause = "";
    my $rclause = "";
    my @binds_r_clause;

    if ( $domain eq "" ) {  # unassigned
        if ( $percent_identity == 30 ) {
            $clause = "and dt5.percent_identity >= 30 ";
        } elsif ( $percent_identity == 60 ) {
            $clause = " and dt5.percent_identity >= 60 ";
        } else {
            $clause = "and dt5.percent_identity >= 90 ";
        }
    }
    else {
        $rclause = PhyloUtil::getPercentClause( $percent_identity, $plus );

        # about ir_class - its blank sometimes
        if ( !defined($ir_class) || $ir_class eq "" ) {
            $rclause .= " and dt.ir_class is null";
        } else {
            $rclause .= " and dt.ir_class = ? ";
            push( @binds_r_clause, $ir_class );
        }        

    }

    if ( $cogfunc eq $zzzUnknown ) {
        $rclause .= " and cf.definition is null ";
    } else {
        $rclause .= " and cf.definition = ? ";
        push( @binds_r_clause, $cogfunc );
    }

    my $familyClause;
    my @binds_f_clause;
    if ( $family ne "" ) {
        $familyClause = "and t.family = ? ";
        push( @binds_f_clause, $family );
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t.species is null";
        } else {
            $familyClause .= " and t.species = ? ";
            push( @binds_f_clause, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t.genus is null";
        } else {
            $familyClause .= " and t.genus = ? ";
            push( @binds_f_clause, $genus );
        }
    }

    my $sql;
    my @binds;
    if ( $domain eq "" ) { # unassigned
        #$sql = qq{
        #    select cp2.cog_pathway_name, g2.gene_oid, g2.gene_display_name, ' ', cfs.cog_id
        #    from gene g2, gene_cog_groups gcg2, cog_function cf, cog_functions cfs, cog_pathway cp2,
        #    cog_pathway_cog_members cpcm2
        #    where g2.gene_oid in (
        #      select g5.gene_oid
        #      from gene g5
        #      where g5.taxon = ?
        #      and g5.obsolete_flag = 'No'
        #      and g5.locus_type = 'CDS'
        #      minus 
        #      select dt5.gene_oid
        #      from dt_phylum_dist_genes dt5
        #      where dt5.taxon_oid = ?
        #      $clause         
        #    )        
        #    and g2.gene_oid = gcg2.gene_oid 
        #    and gcg2.cog = cfs.cog_id
        #    and cfs.functions = cp2.function
        #    and cp2.cog_pathway_oid = cpcm2.cog_pathway_oid
        #    and cf.function_code = cfs.functions
        #    $rclause    
        #    order by cp2.cog_pathway_name, g2.gene_oid
        #};
        $sql = qq{
            select cp2.cog_pathway_name, g2.gene_oid, g2.gene_display_name, ' ', cfs.cog_id
            from gene g2, gene_cog_groups gcg2, cog_function cf, cog_functions cfs, cog_pathway cp2
            where g2.gene_oid in (
              select g5.gene_oid
              from gene g5
              where g5.taxon = ?
              and g5.obsolete_flag = 'No'
              and g5.locus_type = 'CDS'
              minus 
              select dt5.gene_oid
              from dt_phylum_dist_genes dt5
              where dt5.taxon_oid = ?
              $clause         
            )        
            and g2.gene_oid = gcg2.gene_oid 
            and gcg2.cog = cfs.cog_id
            and cfs.functions = cp2.function
            and cfs.functions = cf.function_code
            $rclause
            order by cp2.cog_pathway_name, g2.gene_oid
        };
        @binds = ( $taxon_oid, $taxon_oid );
        push( @binds, @binds_r_clause ) if ( $#binds_r_clause > -1 );
    }
    else {
        # new binds
        my $urclause = WebUtil::urClause("dt.homolog_taxon");
        my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
    
        #$sql = qq{
        #    select distinct cp2.cog_pathway_name, abc.gene_oid, abc.gene_display_name,
        #        abc.percent_identity, abc.cog_id
        #    from
        #    (
        #        select dt.gene_oid, g.gene_display_name, dt.percent_identity, cfs.cog_id
        #        from gene g, taxon t, dt_phylum_dist_genes dt
        #        left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
        #        left join cog_functions cfs on gcg.cog = cfs.cog_id
        #        left join cog_function cf on cf.function_code = cfs.functions
        #        where dt.taxon_oid = ?
        #        and dt.domain = ?
        #        and dt.phylum = ?
        #        and dt.homolog_taxon = t.taxon_oid
        #        and dt.homolog = g.gene_oid
        #        and g.taxon = t.taxon_oid
        #        $rclause
        #        $familyClause
        #        $urclause
        #        $imgClause
        #    ) abc, cog_pathway_cog_members cpcm2, cog_pathway cp2
        #    where abc.cog_id = cpcm2.cog_members
        #    and cpcm2.cog_pathway_oid = cp2.cog_pathway_oid
        #    order by cp2.cog_pathway_name, abc.gene_oid
        #};

        $sql = qq{
            select distinct cp2.cog_pathway_name, abc.gene_oid, abc.gene_display_name,
                abc.percent_identity, abc.cog_id
            from
            (
                select dt.gene_oid, g.gene_display_name, dt.percent_identity, cfs.functions, cfs.cog_id
                from gene g, taxon t, dt_phylum_dist_genes dt
                left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
                left join cog_functions cfs on gcg.cog = cfs.cog_id
                left join cog_function cf on cf.function_code = cfs.functions
                where dt.taxon_oid = ?
                and dt.domain = ?
                and dt.phylum = ?
                and dt.homolog_taxon = t.taxon_oid
                and dt.homolog = g.gene_oid
                and g.taxon = t.taxon_oid
                $rclause
                $familyClause
                $urclause
                $imgClause
            ) abc, cog_pathway cp2
            where abc.functions = cp2.function
            order by cp2.cog_pathway_name, abc.gene_oid
        };
        @binds = ( $taxon_oid, $domain, $phylum );
        push( @binds, @binds_r_clause ) if ( $#binds_r_clause > -1 );
        push( @binds, @binds_f_clause ) if ( $#binds_f_clause > -1 );
    }
    #print "printMetagCogFuncPath2() 1 sql=$sql<br/>\n";
    #print "printMetagCogFuncPath2() 1 binds=@binds<br/>\n";

    # pathway name => array of genes info tab delimited
    my %recs;
    my %cog_h;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $pathway, $gene_oid, $gene_display_name, $percent_identity, $cog_oid ) = $cur->fetchrow();
        last if !$gene_oid;

        if ( exists $recs{$pathway} ) {
            my $aref = $recs{$pathway};
            push( @$aref, "$gene_oid\t$gene_display_name\t$percent_identity\t$cog_oid" );
        } else {
            my @a;
            push( @a, "$gene_oid\t$gene_display_name\t$percent_identity\t$cog_oid" );
            $recs{$pathway} = \@a;
        }
        $cog_h{$cog_oid} = 1;
    }
    $cur->finish();

    my %cogcount_hash;
    my @keys = keys %cog_h;
    if ( scalar(@keys)  > 0) {        
        my $cogids_str = OracleUtil::getFuncIdsInClause( $dbh, @keys );
        my $sql = qq{
            select cog, count(*)
            from gene_cog_groups 
            where cog in ( $cogids_str )
            group by cog
        };
        #print "printMetagCogFuncPath2() 2 sql=$sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $cog_oid, $count ) = $cur->fetchrow();
            last if !$cog_oid;
            $cogcount_hash{$cog_oid} = $count;
        }
        $cur->finish();        
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $cogids_str =~ /gtt_func_id/i );
    }

    MetagJavaScript::printMetagJS();
    printMainForm();

    if (scalar(keys %recs) > 0 ) {
        printGeneCartFooter();        
    }

    foreach my $pathway ( sort keys %recs ) {
        my $aref = $recs{$pathway};

        # fix distinct count
        my $distinct_gene_count = $#$aref + 1;
        my $geneCount           = $#$aref + 1;

        print "<font color='navy' size='+1'>";
        if ( $pathway eq $zzzUnknown ) {
            print $unknown . "</font>\n";
        } else {

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

        foreach my $line (@$aref) {
            my ( $gene_oid, $gene_name, $percent, $cog_oid ) =
              split( /\t/, $line );

            print "<tr>\n";
            print "<td nowrap>";
            print nbsp(4);
            print "</td><td>";
            print "\n<input type='checkbox' name='gene_oid' value='$gene_oid'/>";
            print "</td>";
            
            print "<td>";
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            print alink( $url, $gene_oid );
            print "</td>";
            
            print "<td>";
            if ( $percent ne "" ) {
                print "$percent%";
            } else {
                print "";
            }
            print "</td>";

            print "<td>";
            print "$cog_oid";
            print "</td>";

            print "<td>";
            my $cogGeneCount = $cogcount_hash{$cog_oid};
            print "$cogGeneCount";
            print "</td>";

            print "<td nowrap>";
            print $gene_name;
            print "</td>";
            print "</tr>\n";
        }
        print "</table>\n";
    }

    print end_form();
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

#########################################################################
# printMetagCateFunc
#########################################################################
sub printMetagCateFunc {
    my ( $profileType ) = @_;

    $profileType = param('profileType') if ( ! $profileType );
    
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');
    my $plus             = param("plus");
	
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, '', $percent_identity, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );

    my $category_display_type = PhyloUtil::getFuncTextVal($profileType);
    if ( !$category_display_type ) {
        webError("Unknown function type: $profileType\n"); 
    }
    print "<h3>$category_display_type View</h3>\n";

    # get category
    my ( $cateId2cateName_href, $cateName2cateId_href, $cateId2funcs_href, $func2cateId_href )
        = PhyloUtil::getAllCategoryInfo( $dbh, $profileType );

    #get hit genes
    my ($gene_oids_ref, $percentHits_href, $count, $trunc) = processMetagenomeHitGenes($dbh,
        $taxon_oid, $data_type, $percent_identity, $plus, $rna16s, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species);

    my %gene2func_h = getGene2Funcs( $dbh, $profileType, $gene_oids_ref );

    my %category2gcnt;
    my $unknownCount = 0;

    foreach my $gene_oid (@$gene_oids_ref) {
        # get funcs for this gene
        my $funcs_href = $gene2func_h{$gene_oid};
        my @funcs = keys %$funcs_href;
        my %gene_category;
        for my $func_id (@funcs) {
            if ( $func2cateId_href->{$func_id} ) {
                my @p_list = split( /\t/, $func2cateId_href->{$func_id} );
                for my $p (@p_list) {
                    $gene_category{$p} = 1;
                }
            }
        }    # end for func_id

        for my $p2 ( keys %gene_category ) {
            if ( $category2gcnt{$p2} ) {
                $category2gcnt{$p2} += 1;
            }
            else {
                $category2gcnt{$p2} = 1;
            }
        }    # end for p2
        
        if ( scalar( keys %gene_category ) == 0 ) {
            $unknownCount++;
        }
        undef %gene_category;
    }    # end for gene_oid

    my $gene_count_total = PhyloUtil::printCateChart( $section,
        $taxon_oid, $data_type, $percent_identity, $plus,
        $domain,    $phylum,    $ir_class,         $ir_order, 
        $family,    $genus,     $species,          $rna16s,
        $profileType, $category_display_type,
        $cateId2cateName_href, $cateName2cateId_href, \%category2gcnt, 
        $unknownCount, 1
    );
      
    printStatusLine( "$gene_count_total (duplicates*) Loaded.", 2 );
}

sub getGene2Funcs {
    my ( $dbh, $profileType, $gene_oids_ref, $funcs_ref ) = @_;

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );
    my $funcs_str = OracleUtil::getFuncIdsInClause( $dbh, @$funcs_ref ) 
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 );
    my $funcClause;

    my $sql;
    if ( $profileType eq 'cogc' || $profileType eq 'cogp' ) {
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 ) {
            $funcClause = " and g.cog in ( $funcs_str ) "; 
        }
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g
            where g.gene_oid in ( $gene_oid_str )
            $funcClause
        }
    }
    elsif ($profileType eq 'keggp_ec'
        || $profileType eq 'keggc_ec' )
    {
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 ) {
            $funcClause = " and g.enzymes in ( $funcs_str ) "; 
        }
        $sql = qq{
            select distinct g.gene_oid, g.enzymes
            from gene_ko_enzymes g
            where g.gene_oid in ( $gene_oid_str )
            $funcClause
        };
    }
    elsif ($profileType eq 'keggp_ko'
        || $profileType eq 'keggc_ko' )
    {
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 ) {
            $funcClause = " and g.ko_terms in ( $funcs_str ) "; 
        }
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms
            from gene_ko_terms g
            where g.gene_oid in ( $gene_oid_str )
            $funcClause
        }; 
    }
    elsif ( $profileType eq 'pfamc' ) {
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 ) {
            $funcClause = " and g.pfam_family in ( $funcs_str ) "; 
        }
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family
            from gene_pfam_families g
            where g.gene_oid in ( $gene_oid_str )
            $funcClause
        };
    }
    elsif ( $profileType eq 'tigrr' ) {
        if ( $funcs_ref && scalar(@$funcs_ref) > 0 ) {
            $funcClause = " and g.ext_accession in ( $funcs_str ) "; 
        }
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession
            from gene_tigrfams g 
            where g.gene_oid in ( $gene_oid_str )
            $funcClause
        };    
    }
    else {
        webError("Pending: $profileType\n");         
    }
    #print "getGene2Funcs() sql=$sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    my %gene2func_h;
    for ( ; ; ) {
        my ($gene_oid, $func_id) = $cur->fetchrow();
        last if !$gene_oid;

        my $funcs_href = $gene2func_h{$gene_oid};
        if ( $funcs_href ) {
            $funcs_href->{$func_id} = 1;
        }
        else {
            my %funcs_h;
            $funcs_h{$func_id} = 1;
            $gene2func_h{$gene_oid} = \%funcs_h;
        }
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $gene_oid_str =~ /gtt_num_id/i );
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $funcs_str =~ /gtt_func_id/i );

    return ( %gene2func_h );
}



sub printMetagCateFunc_old {
    my ( $profileType ) = @_;

    $profileType = param('profileType') if ( ! $profileType );
    
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');
    my $plus             = param("plus");
    
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, '', $percent_identity, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );

    my $category_display_type = PhyloUtil::getFuncTextVal($profileType);
    if ( !$category_display_type ) {
        webError("Unknown function type: $profileType\n"); 
    }
    print "<h3>$category_display_type View</h3>\n";

    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }

    my %category2gcnt;
    if ( $profileType eq 'cogc' ) {
        %category2gcnt = processMetagCogCategories( $dbh, $use_phylo_file, 
            $taxon_oid, $data_type, $percent_identity, $plus, $rna16s,
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );        
    }
    elsif ( $profileType eq 'cogp' ) {
        %category2gcnt = processMetagCogPathways( $dbh, $use_phylo_file, 
            $taxon_oid, $data_type, $percent_identity, $plus, $rna16s, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );        
    }
    else {
        webError("Pending: $profileType\n");         
    }        

    #### PREPARE THE PIECHART ######
    my @chartcategories;
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

    my $url2_base = "$main_cgi?section=$section";
    $url2_base .= $url_mid;
    if ( $profileType eq 'cogc' ) {
        $url2_base .= "&page=cogfunclistgenes";
        $url2_base .= "&cogfunc=";
    }
    elsif ( $profileType eq 'cogp' ) {
        $url2_base .= "&page=cogpathgenes";
        $url2_base .= "&cogpath=";
    }

    my $gene_count_total = 0;
    foreach my $catepath_name ( sort keys %category2gcnt ) {
        next if ( $catepath_name eq $zzzUnknown );

        my $gcount = $category2gcnt{$catepath_name};
        $gene_count_total += $gcount;

        push @chartcategories, $catepath_name;
        push @chartdata,       $gcount;
    }

    # pie chart:
    my $idx = 0;
    my $d3data = "";
    foreach my $category1 (sort @chartcategories) {
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
            \"urlfragm\": \"" . escHtml($category1) .  "\", 
            \"percent\": " . $percent . 
        "}";
    
        $idx++;
    }

    if ( $d3data ) {
        my $unknownCnt = $category2gcnt{$zzzUnknown};
        if ($unknownCnt > 0) {
            $d3data .= ",";
            $d3data .= "{" .
                "\"id\": \"" . "Not in $category_display_type" . "\", 
                \"count\": " . $unknownCnt . ", 
                \"name\": \"" . "Not in $category_display_type" . "\", 
                \"urlfragm\": \"" . $zzzUnknown . "\", 
                \"draw\": \"" . "no" . "\"" . 
                "}";
        }

        $d3data .= "]";
        require D3ChartUtil;
        D3ChartUtil::printPieChart
            ($d3data, $url2_base, $url2_base, "", 0, 1,
             "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    }

    printStatusLine( "$gene_count_total (duplicates*) Loaded.", 2 );
}


sub processMetagCogPathways {
    my ( $dbh, $use_phylo_file, $taxon_oid, $data_type, $percent_identity, $plus, $rna16s, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    # gene list
    my %genelist = getMetagCogGenelist( $dbh, $use_phylo_file,
        $taxon_oid, $percent_identity, $data_type, $rna16s, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species
     );
    my @gene_oids = keys( %genelist );
    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );

    # genes with pathways
    my $sql = qq{
        select cp.cog_pathway_name, gcg.gene_oid
        from gene_cog_groups gcg, cog c, cog_functions cfs, cog_pathway cp
        where gcg.cog = c.cog_id 
        and c.cog_id = cfs.cog_id
        and cfs.functions = cp.function
        and gcg.gene_oid in ( $gene_oid_str )
        order by cp.cog_pathway_name
    };
    #print "printMetagCogPath() sql: $sql<br/>\n";

    # pathway => array of genes
    my %pathways2gcnt;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_pathway_name, $gene_oid ) = $cur->fetchrow();
        last if !$gene_oid;

        # what is left is unknown pathway to genes
        delete $genelist{$gene_oid};

        if ( exists $pathways2gcnt{$cog_pathway_name} ) {
            $pathways2gcnt{$cog_pathway_name} += 1;
            #my $aref = $pathways2gcnt{$cog_pathway_name};
            #push( @$aref, $gene_oid );
        } else {
            $pathways2gcnt{$cog_pathway_name} = 1;
            #my @a;
            #push( @a, $gene_oid );
            #$pathways2gcnt{$cog_pathway_name} = \@a;
        }
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $gene_oid_str =~ /gtt_num_id/i );

    #now unknown
    my @unknownGenes = keys %genelist;
    if ( scalar(@unknownGenes) > 0 ) {
        $pathways2gcnt{$zzzUnknown} = scalar(@unknownGenes);
    }

    return %pathways2gcnt;
}

sub getMetagCogGenelist {
    my ( $dbh, $use_phylo_file,
        $taxon_oid, $percent_identity, $data_type, $rna16s, $plus,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species
     ) = @_;
    
    # gene list
    my %genelist;

    if ( $use_phylo_file ) {
        my @workspace_ids;
        PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $data_type, $percent_identity, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $rna16s, 1, '', \@workspace_ids );

        for my $workspace_id (@workspace_ids) {
            my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
            $genelist{$gene_oid2} = 1;
        }

    }
    else {

        my $sql;
        my @binds;

        if ( $domain eq "" ) {
    
            # unassigned
            my $clause = "";
            if ( $domain eq "" ) {
                $clause = PhyloUtil::getPercentClause( $percent_identity, 1 );
            }
            
            # Unassigned
            $sql = qq{
                select distinct g.gene_oid
                from gene g
                where g.taxon = ?
                and g.obsolete_flag = 'No'
                and g.locus_type = 'CDS'
                minus 
                select dt.gene_oid
                from dt_phylum_dist_genes dt
                where dt.taxon_oid = ?
                $clause
            };
            @binds = ( $taxon_oid, $taxon_oid );
            
        }
        else {

            # assigned
            my $rclause = PhyloUtil::getPercentClause( $percent_identity, $plus );

            @binds = ( $taxon_oid );
        
            my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
            push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

            my $urclause = WebUtil::urClause("dt.homolog_taxon");
            my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
            
            $sql = qq{
               select dt.gene_oid
               from dt_phylum_dist_genes dt, taxon t
               where dt.taxon_oid = ?
               and dt.homolog_taxon = t.taxon_oid
               $rclause
               $taxonomyClause
               $urclause
               $imgClause
            };
        }    
        #print "getMetagCogGenelist() sql: $sql<br/>\n";
        #print "getMetagCogGenelist() binds: @binds<br/>\n";
    
        my $cur = execSql( $dbh, $sql, $verbose, @binds );
        for ( ; ; ) {
            my ($gid) = $cur->fetchrow();
            last if !$gid;
            $genelist{$gid} = 1;
        }
        $cur->finish();

    }
    #print Dumper \%genelist;
    #print "<br/>\n";

    return %genelist;
}

sub processMetagCogCategories {
    my ( $dbh, $use_phylo_file, $taxon_oid, $data_type, $percent_identity, $plus, $rna16s, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) = @_;

    my $sql;
    my @binds;
    my $gene_oid_str;
    
    if ( $use_phylo_file ) {
        my @workspace_ids_data;
        PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $data_type, $percent_identity, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $rna16s, 1, '', \@workspace_ids_data );

        my @gene_oids;
        for my $workspace_id (@workspace_ids_data) {
            my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
            push( @gene_oids, $gene_oid2 );
        }

        $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );

        my $urclause = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        $sql = qq{
           select $nvl(cf.definition, '$zzzUnknown'), count(distinct g.gene_oid)
           from gene_cog_groups g, cog_functions cfs, cog_function cf
           where g.gene_oid in ( $gene_oid_str )
           and g.cog = cfs.cog_id
           and cf.function_code = cfs.functions
           $urclause
           $imgClause
           group by $nvl(cf.definition, '$zzzUnknown')
           order by $nvl(cf.definition, '$zzzUnknown')
        };        
    }
    else {
        if ( $domain eq "" ) {
    
            # Unassigned
            my $clause = PhyloUtil::getPercentClause( $percent_identity, 1 );
            $sql = qq{
              select $nvl(cf2.definition, '$zzzUnknown'), count(distinct g2.gene_oid)
              from gene_cog_groups g2
              left join cog_functions cfs2 on g2.cog = cfs2.cog_id
              left join cog_function cf2 on cf2.function_code = cfs2.functions
              where g2.taxon = ?
              and g2.gene_oid in(
                  select distinct g.gene_oid
                  from gene g
                  where g.taxon = ?
                  and g.obsolete_flag = 'No'
                  and g.locus_type = 'CDS'
                  minus 
                  select dt.gene_oid
                  from dt_phylum_dist_genes dt
                  where dt.taxon_oid = ?
                  $clause
              )
              group by $nvl(cf2.definition, '$zzzUnknown')
              order by $nvl(cf2.definition, '$zzzUnknown')
            };
            
            @binds = ( $taxon_oid, $taxon_oid, $taxon_oid );
    
        }
        else {
            
            # query
            my $rclause = PhyloUtil::getPercentClause( $percent_identity, $plus );        

            @binds = ( $taxon_oid );
        
            my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
            push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

            my $urclause = WebUtil::urClause("dt.homolog_taxon");
            my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
            
            $sql = qq{
               select $nvl(cf.definition, '$zzzUnknown'), count(distinct dt.gene_oid)
               from taxon t, dt_phylum_dist_genes dt
               left join gene_cog_groups gcg on dt.gene_oid = gcg.gene_oid
               left join cog_functions cfs on gcg.cog = cfs.cog_id
               left join cog_function cf on cf.function_code = cfs.functions
               where dt.taxon_oid = ?
               and dt.homolog_taxon = t.taxon_oid
               $rclause
               $taxonomyClause
               $urclause
               $imgClause
               group by $nvl(cf.definition, '$zzzUnknown')
               order by $nvl(cf.definition, '$zzzUnknown')
            };
        }        
    }
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %category2gcnt;
    for ( ; ; ) {
        my ( $cate_name, $gcnt ) = $cur->fetchrow();
        last if !$cate_name;
        
        $category2gcnt{$cate_name} = $gcnt;
    }
    $cur->finish();

    if ( $use_phylo_file ) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $gene_oid_str =~ /gtt_num_id/i );
    }

    return (%category2gcnt);
}



#
# print metag cog func pathways detail
#
sub printMetagCogFuncPath {
    printMainForm();
    printStatusLine( "Loading ...", 1 );
    PhyloUtil::printCartFooter2( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );

    # cache files
    my ( $file1, $file2, $file4 );
    $file1 = param("cf1");
    $file2 = param("cf2");
    $file4 = param("cf4");

    my ( $r_ref, $h_ref, $p_ref ) = PhyloUtil::readCacheData( $file1, $file2, $file4 );

    MetagJavaScript::printMetagJS();

    # this is a html esc function name
    my $functionname = param("function");

    PhyloUtil::flushGeneBatch3path( $r_ref, $h_ref, $p_ref, $functionname );

    printStatusLine( "gene(s) retrieved", 2 );
    print end_form();
}

############################################################################
# printMetagenomeHits - Show the gene list from the counts in
#   the histogram for metagenome hits.
#
# database version
#
# param $taxon_oid taxon oid
# param $percent percent
# param $phylum
# param $ir_class can be null or blank
#
############################################################################
sub printMetagenomeHits {
    my ( $taxon_oid, $percent, $domain, $phylum, $plus ) = @_;

    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $percent = param("percent_identity")   if ( $percent eq "" );
    $percent = param("percent")            if ( $percent eq "" );
    $percent = param("perc")               if ( $percent eq "" );
    $plus      = param("plus")             if !$plus;

    $domain    = param("domain")           if !$domain;
    $phylum    = param("phylum")           if !$phylum;

    my $data_type = param("data_type");
    my $rna16s = param('rna16s');

    printMainForm();
    printStatusLine( "Loading ...", 1 );
        
    my $dbh = dbLogin();    
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent, 
        $domain, $phylum, '', '', '', '', '', $rna16s, $plus );

    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "data_type",        $data_type );
    print hiddenVar( "domain",           $domain );
    print hiddenVar( "phylum",           $phylum );
    print hiddenVar( "percent_identity", $percent );
    print hiddenVar( "percent",          $percent );
    print hiddenVar( "plus",             1 ) if $plus;
    print hiddenVar( "rna16s", $rna16s ) if ($rna16s);
    
    #
    # cache results
    # based on view type display it differently
    # default is table
    #

    # cache files
    my ( $file1, $file2, $file4 );

    # if cached data, the data set are stored here
    # recs, hash of cog func , cog pathway
    my ( $r_ref, $h_ref, $p_ref );

    my $cf1   = param("cf1");
    my $dosql = 0;
    if ( !defined($cf1) || $cf1 eq "" ) {
        $dosql = 1;
    } else {
        $file1 = param("cf1");
        $file2 = param("cf2");
        $file4 = param("cf4");
        #print "printMetagenomeHits() file1: $file1, file2: $file2, file4: $file4<br/>\n";
    }
    #print "printMetagenomeHits() dosql: $dosql<br/>\n";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";

    my $count = 0;
    my $trunc = 0;

    # array of arrays rec data
    my @recs;

    # hash of arrays cog_id => rec data
    my %hash_cog_func;

    # hash of gene oid => cog path ways
    my %hash_cog_pathway;

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    if ($dosql) {
        my ($gene_oids_ref, $percentHits_href);
        ($gene_oids_ref, $percentHits_href, $count, $trunc) = processMetagenomeHitGenes($dbh,
            $taxon_oid, $data_type, $percent, $plus, $rna16s, 
            $domain, $phylum, '', '', '', '', '', 
            '', $count, $trunc );

        PhyloUtil::getFlushGeneBatch2( $dbh, $gene_oids_ref, $percentHits_href, \@recs );

        # remove duplicates from the AoA by unique 1st element of each sub array
        @recs = HtmlUtil::uniqAoA( 0, @recs );

        PhyloUtil::getCogGeneFunction( $dbh, $gene_oids_ref, \%hash_cog_func );
        PhyloUtil::getCogGenePathway( $dbh, $gene_oids_ref, \%hash_cog_pathway );

        ( $file1, $file2, $file4 ) = PhyloUtil::cacheData( \@recs, \%hash_cog_func, \%hash_cog_pathway );


    } else {

        # read data from cache files
        ( $r_ref, $h_ref, $p_ref ) = PhyloUtil::readCacheData( $file1, $file2, $file4 );

        if ( $checked eq "true" ) {     # count non-blank cogs
            $count = 0;
            foreach my $r (@$r_ref) {
                next if !$r->[15];      # cog_id
                $count++;
            }
        } else {
            $count = @$r_ref;
            $trunc = 1 if $count >= $maxGeneListResults;    # table truncation check for statusline
        }
    }

    MetagJavaScript::printMetagJS();

    PhyloUtil::printProfileSelection( $section );
    PhyloUtil::printCartFooter2( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );
#    printViewButtons( $file1, $file2, $file4, 
#        $taxon_oid, $percent, $data_type, $rna16s,
#        $domain, $phylum, $plus, $checked );

    my $it = new InnerTable( 1, "MetagHits$$", "MetagHits", 1 );
    my $sd = $it->getSdDelim();                                    # sort delimiter

    my $view = param("view");
    if ( $view ne "cogfunc" && $view ne "cogpath" ) {
        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",     "char asc",    "left" );
        $it->addColSpec( "Percent",      "number desc", "right" );
        $it->addColSpec( "Name",         "char asc",    "left" );
        $it->addColSpec( "COG ID",       "char asc",    "left" );
        $it->addColSpec( "COG Name",     "char asc",    "left" );
        $it->addColSpec( "COG Function", "char asc",    "left" );
        $it->addColSpec( "Estimated Copies", "number desc", "right" );

        # COG Gene Count removal
        # requested by Natalia (GBP) for IMG 3.3 +BSJ 10/13/10
        # $it->addColSpec( "COG<br>Gene<br>Count", "number desc", "right" );
    }

    if ($dosql) {
        print "<br>";

        # default display - table view
        PhyloUtil::flushGeneBatch2( $it, \@recs, \%hash_cog_func );
        $it->printOuterTable(1);
    } else {

        # if the user presses the cog view button
        if ( $view eq "cogfunc" ) {
            #print "h_ref:<br/>\n";
            #print Dumper $h_ref;
            #print "<br/>\n";

            #print "p_ref:<br/>\n";
            #print Dumper $p_ref;
            #print "<br/>\n";

            print "<h3>COG Function View</h3>\n";
            PhyloUtil::flushGeneBatch3( $r_ref, $h_ref, $p_ref, $section );
            #PhyloUtil::flushGeneBatch3path( $r_ref, $h_ref, $p_ref);
        } elsif ( $view eq "cogpath" ) {
            print "<h3>COG Pathway View</h3>\n";
            PhyloUtil::flushGeneBatch4( $r_ref, $h_ref, $p_ref );
        } else {
            #print "dosql = 0, use file<br/>\n";
            print "<br>";
            PhyloUtil::flushGeneBatch2( $it, $r_ref, $h_ref );
            $it->printOuterTable(1);
        }
    }

    print "</p>\n";
    print "<br/>\n";

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }
    print end_form();

}

sub processMetagenomeHitGenes {
    my ( $dbh, $taxon_oid, $data_type, $percent, $plus, $rna16s, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
        $limiting_genes_href, $count, $trunc ) = @_;

    my @gene_oids;    
    # hash of gene oid => to percent
    my %percentHits;

    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }    
    #print "processMetagenomeHitGenes() use_phylo_file: $use_phylo_file<br/>\n";

    if ( $use_phylo_file ) {

        my @workspace_ids_data;
        $trunc = PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $data_type, $percent, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $rna16s, 0, $maxGeneListResults, \@workspace_ids_data, $limiting_genes_href );

        for my $r (@workspace_ids_data) {        
            my (
                $workspace_id, $per_cent, $homolog_gene,
                $homo_taxon, $copies, @rest
              )
              = split( /\t/, $r );

            my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
            push( @gene_oids, $gene_oid2 );
            $percentHits{$gene_oid2} = $per_cent;

            $count++;
        }
    }
    else {
            
        my $sql;
        my @binds;
            
        my $page = param("page");
        if ( $page eq "unassigned" ) {
            #  unassigned
            # I'm using minus instead of not in because
            # the minus query seems to run faster.
        
            my $clause = PhyloUtil::getPercentClause( $percent, 1 );    
            $sql   = qq{
                select distinct g.taxon, g.gene_oid
                from gene g
                where g.taxon = ?
                and g.obsolete_flag = 'No'
                and g.locus_type = 'CDS'
                minus 
                select dt.taxon_oid, dt.gene_oid
                from dt_phylum_dist_genes dt
                where dt.taxon_oid = ?
                $clause
            };
            @binds = ( $taxon_oid, $taxon_oid );
        }
        else {
    
            # query
            my $rclause = PhyloUtil::getPercentClause( $percent, $plus );
                                
            my $urclause = WebUtil::urClause("dt.homolog_taxon");
            my $imgClause = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');

            if ( $domain && $phylum ) {                
                #if ( $xcopy eq 'est_copy' ) {
                #    $sql = qq{
                #       select dt.taxon_oid, dt.gene_oid, dt.percent_identity, g.est_copy
                #       from dt_phylum_dist_genes dt, gene g
                #       where dt.taxon_oid = ?
                #       and dt.domain = ?
                #       and dt.phylum = ?
                #       $rclause
                #       $urclause
                #       $imgClause
                #       order by dt.gene_oid
                #    };
                #} else {
                    $sql = qq{
                       select dt.taxon_oid, dt.gene_oid, dt.percent_identity, 1
                       from dt_phylum_dist_genes dt
                       where dt.taxon_oid = ?
                       and dt.domain = ?
                       and dt.phylum = ?
                       $rclause
                       $urclause
                       $imgClause
                       order by dt.gene_oid
                    };
                #}                
                @binds = ( $taxon_oid, $domain, $phylum );
            }
            else {
                #if ( $xcopy eq 'est_copy' ) {
                #    $sql = qq{
                #       select dt.taxon_oid, dt.gene_oid, dt.percent_identity, g.est_copy
                #       from dt_phylum_dist_genes dt, gene g
                #       where dt.taxon_oid = ?
                #       $rclause
                #       $urclause
                #       $imgClause
                #       order by dt.gene_oid
                #    };
                #} else {
                    $sql = qq{
                       select dt.taxon_oid, dt.gene_oid, dt.percent_identity, 1
                       from dt_phylum_dist_genes dt
                       where dt.taxon_oid = ?
                       $rclause
                       $urclause
                       $imgClause
                       order by dt.gene_oid
                    };
                #}                
                @binds = ( $taxon_oid );                
            }
        }
        #print "printMetagenomeHitGenes() sql: $sql<br/>\n";
        #print "printMetagenomeHitGenes() binds: @binds<br/>\n";
    
        my $cur = execSql( $dbh, $sql, $verbose, @binds );
    
        my $last_gene_oid = "";
        for ( ; ; ) { 
            my ( $taxon_oid2, $gene_oid2, $per_cent, $cnt ) = $cur->fetchrow();
            last if !$taxon_oid2;
    
            if ( $last_gene_oid ne '' && $last_gene_oid eq $gene_oid2 ) {
                next;
            }
            $last_gene_oid = $gene_oid2;
    
            push( @gene_oids, $gene_oid2 );
            $percentHits{$gene_oid2} = $per_cent;
    
            $count++;
            if ( $count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();            
    }

    return (\@gene_oids, \%percentHits, $count, $trunc);
}


sub printViewButtons {
    my ( $file1, $file2, $file4, 
        $taxon_oid, $percent_identity, $data_type, $rna16s,
        $domain, $phylum, $plus, $checked ) = @_;

    my $url_mid = "&taxon_oid=$taxon_oid&percent_identity=$percent_identity";
    $url_mid .= "&data_type=$data_type" if ( $data_type );
    $url_mid .= "&rna16s=$rna16s"     if ( $rna16s );
    $url_mid .= "&domain=$domain"     if ( $domain );
    $url_mid .= "&phylum=$phylum"     if ( $phylum );
    $url_mid .= "&plus=1" if ( $plus );

    my $url = "main.cgi?section=MetagenomeHits&page=cogfunclist";
    $url .= $url_mid;
    $url = escHtml($url);

    #  url for pathways
    my $url2 = "main.cgi?section=MetagenomeHits&page=cogpath"; 
    $url2 .= $url_mid;
    $url2 = escHtml($url2);

    print <<EOF;
        <p>
        <input type='button' name='cogfuncview' value='COG Functional Categories' title='Group by COG Functional Categories' 
        onClick="window.location.href='$url'" 
        class='smbutton' /> 
        &nbsp;
        <input type='button' name='cogpathview' value='COG Pathways'  title='Group by COG Pathways'
        onClick="window.location.href='$url2'"
        class='smbutton' />
        </p>        
EOF

=pod
    print <<EOF;
        <p>
        <input type='button' name='tableview' value='Refresh Table View' title='used to refresh page not from cache pages'
        onClick='myView(\"$main_cgi\", \"table\", \"$file1\", \"$file2\", \"$file4\", \"$taxon_oid\", \"$percent_identity\", \"$domain\", \"$phylum\")' 
        class='smbutton' />
        &nbsp;
EOF

    my $checkedMarkup = ( $checked eq 'true' ) ? "checked='checked'" : "";
    print <<EOF;
        <input type='checkbox' title='Hide genes with no COG Function association' name='coghide' $checkedMarkup />
        Hide genes unassociated with COG Functions
        </p>
EOF
=cut
    
}

#
# for taxonomy stats get list of gene oids
#
# other params from url
#
# param $dbh database handler
#
# return hash ref geneoid to avg percentage
sub getTaxonomyGeneOidPercentHits {
    my ( $dbh, $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
        $percent, $plus, $maxGeneListResults ) = @_;

    # Get parameters via CGI if not passed through function
    # When called by MetagPhyloDist::printGeneList,
    # arguments are passed through @_ +BSJ 12/08/10
    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $domain    = param("domain")           if !$domain;
    $phylum    = param("phylum")           if !$phylum;
    $ir_class  = param("ir_class")         if !$ir_class;
    $family    = param("family")           if !$family;
    $genus     = param("genus")            if !$genus;
    $species   = param("species")          if !$species;
    $percent   = param("percent")          if !$percent;
    $percent   = param("percent_identity") if !$percent;
    $plus      = param("plus")             if !$plus;

    my $percClause = PhyloUtil::getPercentClause( $percent, $plus );

    my ($taxonomyClause, $binds_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    # get list of gene oid and avg percentage
    # query updated using homolog column
    my $sql = qq{
        select  dt.gene_oid, dt.percent_identity
        from dt_phylum_dist_genes dt, taxon t
        where dt.homolog_taxon = t.taxon_oid
        and dt.taxon_oid = ?
        $percClause
        $taxonomyClause
    };

    # hash
    # key gene_oid
    # value avg percent
    my %gene_oids_list;
    my $count = 0;
    my $trunc = 0;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, @$binds_ref );
    for ( ; ; ) {
        my ( $gene_oid, $perc_avg ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_oids_list{$gene_oid} = sprintf( "%.2f", $perc_avg );
        
        $count++;
        if ( $count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        
    } 
    $cur->finish();

    return ($count, $trunc, %gene_oids_list);
}

#
# print cog func summary table like printMetagenomeHits()
# this is similar to printMetagenomeHits()
#
# other params from url
#
# param $dbh
sub printTaxonomyMetagHits {
    my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $percent, $plus ) = @_;

    # Get parameters via CGI if not passed through function
    # When called by MetagPhyloDist::printGeneList,
    # arguments are passed through @_ +BSJ 12/08/10
    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $percent   = param("percent")          if !$percent;
    $percent   = param("percent_identity") if !$percent;
    
    $domain    = param("domain")           if !$domain;
    $phylum    = param("phylum")           if !$phylum;
    $ir_class  = param("ir_class")         if !$ir_class;
    $ir_order  = param("ir_order")         if !$ir_order;
    $family    = param("family")           if !$family;
    $genus     = param("genus")            if !$genus;
    $species   = param("species")          if !$species;

    my $data_type = param("data_type");
    my $rna16s    = param('rna16s');
    my $plus      = param("plus");

    # subject genome - taxon oid
    #my $genome = param("genome");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();    
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );    

    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "data_type",        $data_type );
    print hiddenVar( "domain",           $domain );
    print hiddenVar( "phylum",           $phylum );
    print hiddenVar( "ir_class",         $ir_class );
    print hiddenVar( "ir_order",         $ir_order );
    print hiddenVar( "family",           $family );
    print hiddenVar( "genus",            $genus );
    print hiddenVar( "species",          $species );
    print hiddenVar( "percent_identity", $percent );
    print hiddenVar( "percent",          $percent );
    print hiddenVar( "plus",             1 ) if $plus;
    print hiddenVar( "rna16s", $rna16s ) if ($rna16s);

    #
    # cache results
    # based on view type display it differently
    # default is table
    #

    # cache files
    my ( $file1, $file2, $file4 );

    # if cached data, the data set are stored here
    # recs, hash of cog func, cog pathway
    my ( $r_ref, $h_ref, $p_ref );

    my $cf1   = param("cf1");
    my $dosql = 0;
    if ( !defined($cf1) || $cf1 eq "" ) {
        $dosql = 1;
    } else {
        $file1 = param("cf1");
        $file2 = param("cf2");
        $file4 = param("cf4");
    }
    #print "printMetagenomeMetagHits() dosql: $dosql<br/>\n";

    my $count              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    my $sort = param("sort");
    if ( !defined($sort) || $sort eq "" ) {

        # default is col 2, Gene ID
        $sort = 2;
    }

    # array of arrays rec data
    my @recs;

    # hash of arrays cog_id => rec data
    my %hash_cog_func;

    # hash of gene oid => cog path ways
    my %hash_cog_pathway;

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    my $use_phylo_file = 0;
    my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
    if ( -e $phylo_dir_name ) {
        $use_phylo_file = 1;
    }    

    if ($dosql) {

        my @gene_oids;    
        # hash of gene oid => to percent
        my %percentHits;

        if ( $use_phylo_file ) {

            my @workspace_ids_data;
            $trunc = PhyloUtil::getFilePhyloGeneList( 
                $taxon_oid, $data_type, $percent, $plus, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
                $rna16s, 0, $maxGeneListResults, \@workspace_ids_data );

            for my $r (@workspace_ids_data) {        
                my (
                    $workspace_id, $per_cent, $homolog_gene,
                    $homo_taxon, $copies, @rest
                  )
                  = split( /\t/, $r );

                my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
                push( @gene_oids, $gene_oid2 );
                $percentHits{$gene_oid2} = $per_cent;
    
                $count++;
            }
        }
        else {

            ($count, $trunc, %percentHits) =
              getTaxonomyGeneOidPercentHits( $dbh, $taxon_oid, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
                $percent, $plus, $maxGeneListResults );
             @gene_oids = keys (%percentHits);

        }

        PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, \%percentHits, \@recs );

        # remove duplicates from the AoA by unique 1st element of each sub array
        @recs = HtmlUtil::uniqAoA( 0, @recs );

        PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );
        PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

        ( $file1, $file2, $file4 ) = PhyloUtil::cacheData( \@recs, \%hash_cog_func, \%hash_cog_pathway );
    } else {

        # read data from cache files
        ( $r_ref, $h_ref, $p_ref ) = PhyloUtil::readCacheData( $file1, $file2, $file4 );

        if ( $checked eq "true" ) {    # count non-blank cogs
            $count = 0;
            foreach my $r (@$r_ref) {
                next if !$r->[15];     # cog_id
                $count++;
            }
        } else {
            $count = @$r_ref;
            $trunc = 1 if $count >= $maxGeneListResults;    # table truncation check for statusline
        }
    }

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    MetagJavaScript::printMetagJS();

    PhyloUtil::printProfileSelection( $section );
    PhyloUtil::printCartFooter2( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );
#    printTaxonomyViewButtons( $file1, $file2, $file4, 
#        $taxon_oid, $percent, '', '',
#        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
#        $plus, $checked );

    my $it = new InnerTable( 1, "MetagFamilyHits$$", "MetagFamilyHits", 1 );
    my $sd = $it->getSdDelim();                                                # sort delimiter

    my $view = param("view");
    if ( $view ne "cogfunc" && $view ne "cogpath" ) {

        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",     "char asc",    "left" );
        $it->addColSpec( "Percent",      "number desc", "right" );
        $it->addColSpec( "Name",         "char asc",    "left" );
        $it->addColSpec( "COG ID",       "char asc",    "left" );
        $it->addColSpec( "COG Name",     "char asc",    "left" );
        $it->addColSpec( "COG Function", "char asc",    "left" );
        $it->addColSpec( "Estimated Copies", "number desc", "right" );

        # COG Gene Count removal
        # requested by Natalia (GBP) for IMG 3.3 +BSJ 10/13/10
        #$it->addColSpec( "COG<br>Gene<br>Count", "number desc", "right" );
    }
    if ($dosql) {
        print "<br>";

        # default display - table view
        PhyloUtil::flushGeneBatch2( $it, \@recs, \%hash_cog_func );
        $it->printOuterTable(1);
    } else {

        # if the user presses the cog view button
        if ( $view eq "cogfunc" ) {
            print "<h3>Cog Function View</h3>\n";
            PhyloUtil::flushGeneBatch3( $r_ref, $h_ref, $p_ref, $section );

        } elsif ( $view eq "cogpath" ) {
            print "<h3>COG Pathway View</h3>\n";
            PhyloUtil::flushGeneBatch4( $r_ref, $h_ref, $p_ref );
        } else {
            print "<br>";
            PhyloUtil::flushGeneBatch2( $it, $r_ref, $h_ref );
            $it->printOuterTable(1);
        }
    }

    print "</p>\n";
    print "<br/>\n";

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }

    print end_form();

}

sub printTaxonomyViewButtons {
    my ( $file1, $file2, $file4, 
        $taxon_oid, $percent, $data_type, $rna16s,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
        $plus, $checked ) = @_;

    # Return values to blanks for use with urls
    $family  = "" if ( $family  eq "*" );
    $genus   = "" if ( $genus   eq "*" );
    $species = "" if ( $species eq "*" );

    my $url_mid = "&taxon_oid=$taxon_oid";
    $url_mid .= "&data_type=$data_type" if ( $data_type );
    $url_mid .= "&rna16s=$rna16s"     if ( $rna16s );
    $url_mid .= "&domain=$domain"     if ( $domain );
    $url_mid .= "&phylum=$phylum"     if ( $phylum );
    $url_mid .= "&ir_class=$ir_class" if ( $ir_class );
    $url_mid .= "&ir_order=$ir_order" if ( $ir_order );
    $url_mid .= "&family=$family"     if ( $family );
    $url_mid .= "&genus=$genus"       if ( $genus );
    $url_mid .= "&species=$species"   if ( $species );
    $url_mid .= "&plus=1"             if ( $plus );
    $url_mid .= "&percent_identity=$percent";

    my $url =
        "main.cgi?section=MetagenomeHits&page=cogfunclist"
      . $url_mid;
    $url = escHtml($url);

    #  url for pathways
    my $url2 =
        "main.cgi?section=MetagenomeHits&page=cogpath"
      . $url_mid;
    $url2 = escHtml($url2);

    print <<EOF;
        <p>
        <input type='button' name='cogfuncview' value='COG Functional Categories' title='Group by COG Functional Categories' 
        onClick="window.location.href='$url'" 
        class='smbutton' /> 
        &nbsp;
        <input type='button' name='cogpathview' value='COG Pathways'  title='Group by COG Pathways'
        onClick="window.location.href='$url2'"
        class='smbutton' />
        </p>        
EOF

=pod
    print <<EOF;
        <p>
        <input type='button' name='tableview' value='Refresh Table View' title='used to refresh page not from cache pages'
        onClick='myView2(\"$main_cgi\", \"table\", \"$file1\", \"$file2\", \"$file4\", \"$taxon_oid\", \"$percent\", \"$plus\", \"$domain\", \"$phylum\", \"$ir_class\", \"$ir_order\", \"$family\", \"$genus\", \"$species\")' 
        class='smbutton' />
        &nbsp;
EOF

    my $checkedMarkup = ( $checked eq 'true' ) ? "checked='checked'" : "";
    print <<EOF;
        <input type='checkbox' title='Hide genes with no COG Function association' name='coghide' $checkedMarkup />
        Hide genes unassociated with COG Functions
        </p>
EOF
=cut
  
}


1;
