############################################################################
# $Id: MetagPhyloDist.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package MetagPhyloDist;

my $section = "MetagPhyloDist";
use strict;
use CGI qw( :standard );
use Storable;
use Data::Dumper;
use WebUtil;
use WebConfig;
use InnerTable;
use ChartUtil;
use MerFsUtil;
use MetagenomeHits;
use MetaFileHits;
use POSIX qw(ceil floor);
use MetaUtil;
use OracleUtil;
use HtmlUtil;
use HTML::Template;
use PhyloUtil;
use GenomeListJSON;

$| = 1;

my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $section_cgi         = "$main_cgi?section=$section";
my $cluster_bin         = $env->{cluster_bin};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $cgi_url             = $env->{cgi_url};
my $base_url            = $env->{base_url};
my $base_dir            = $env->{base_dir};
my $tmp_url             = $env->{tmp_url};
my $tmp_dir             = $env->{tmp_dir};
my $include_metagenomes = $env->{include_metagenomes};
my $img_internal        = $env->{img_internal};
my $img_lite            = $env->{img_lite};
my $verbose             = $env->{verbose};
my $web_data_dir        = $env->{web_data_dir};
my $maxGeneListResults  = 1000;
my $localhost           = $env->{img_ken_localhost};

my $preferences_url = "$main_cgi?section=MyIMG&page=preferences";
my $max_gene_batch  = 900;

my $in_file      = $env->{in_file};
my $mer_data_dir = $env->{mer_data_dir};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $hmp_test = $env->{hmp_test};

my $nvl          = getNvl();
my $unknown      = "unclassified";
my $DELIMITER    = "-,-";
my $mer_fs_debug = 0;
my $YUI = $env->{yui_dir_28};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my($numTaxon) = @_;
    my $page = param("page");
    my $sid  = getContactOid();

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    if ( $page eq "process" ) {
        my $cat_type = param('cat_type');
        if ( $cat_type eq 'body_site' ) {
            printBodySiteResults();
        } else {
            printResults();
        }
    } elsif ( $page eq 'allBodySiteDistro' ) {
        timeout( 60 * 20 );    # timeout in 20 minutes
                               # this is for HMP-M only !
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        printAllBodySiteResults_merfs();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'refGenomeList' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        # hmp m
        # printRefGenomeList();
        printRefGenomeList_merfs();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'refGenomeGeneList' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        # hmp m
        printRefGenomeGeneList_merfs();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'bodySiteVsBodySite' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        # hmp m
        printBodySiteVsBodySiteList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'allRefGenomes' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printAllRefGenomeList_merfs();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'refGeneList' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printRefGeneList_merfs();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "phyla" ) {

        # drill down
        printNextPhyla();
    } elsif ( $page eq "genome" ) {

        # list of genomes
        printGenomeList();
    } elsif ( $page eq "genome_bodysite" ) {

        # list of genomes (body site)
        printGenomeList_BodySite();
    } elsif ( $page eq "gene" ) {

        # gene list
        printGeneList();
    } elsif ( $page eq "gene_bodysite" ) {

        # gene list
        printGeneList_BodySite();
    } elsif ( $page eq "top" ) {
        printTop();
    } elsif ( $page eq "form" ) {
        printForm3($numTaxon);
    } else {
        printForm3($numTaxon);
    }
}

sub getDelimiter {
    return $DELIMITER;
}

sub printTop {
    print "<h1>Phylogenetic Distribution</h1>\n";
    print qq{
        <p>
        This tool displays the phylogenetic distribution 
        based on best BLAST hits of protein-coding genes 
        in the dataset.
        </p>
    };

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec("Tool");
    $it->addColSpec("Description");

    my $idx = 0;
    my $row;

    my $url = "$main_cgi?section=MetagPhyloDist&page=form";
    $url = alink( $url, "Phylogenetic Distribution of Metagenomes" );
    $row = $url . "\t";
    $row .= "View the phylogenetic distribution of genes for selected metagenomes.";
    $it->addRow($row);

    my $url = "$main_cgi?section=GenomeHits";
    $url = alink( $url, "Genome vs. Metagenomes" );
    $row = $url . "\t";
    $row .= "View the phylogenetic distribution of genes for an isolate genome run against all metagenomes.";
    $it->addRow($row);

    my $url = "$main_cgi?section=RadialPhyloTree";
    $url =
"<a href=$url target='_blank'><img src='$base_url/images/radialtree_ico.png' class='menuimg' title='Radial Tree'/>Radial Tree</a> ";
    $row = $url . "\t";
    $row .= "View the phylogenetic distribution as a Radial Tree";
    $it->addRow($row);

    $it->printOuterTable(1);
}

sub printJS {
    print qq{
        <script language="javascript" type="text/javascript">
        function mySubmit(x, page) {
            document.mainForm.taxonomy.value = x;
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }

        function mySubmitGene(x, oid) {
            document.mainForm.taxonomy.value = x;
            document.mainForm.page.value = 'gene';
            document.mainForm.metag_oid.value = oid;
            document.mainForm.submit();
        }

        function mySubmitGeneBodySite(x, oid) {
            document.mainForm.taxonomy.value = x;
            document.mainForm.page.value = 'gene_bodysite';
            document.mainForm.metag_oid.value = oid;
            document.mainForm.submit();
        }

        function mySubmit3(page) {
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }

        </script>
    };
}

sub printGeneList {
    my $percentage = param("percentage");  # 30, 60, 90
    my $xcopy      = param("xcopy");       # gene_count, est_copy
    my $taxonomy   = param("taxonomy");    # $DELIMITER delimited - phyla names
    my $taxon_oids = param("taxon_oids");  # comma delimited - taxon oids
    my $metag_oid  = param("metag_oid");
    my $data_type  = param('data_type');

    #print "<p>taxonomy: $taxonomy\n";
    #print "<p>data_type: $data_type\n";

    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }

    my $plus = ( $percentage =~ /p$/i ) ? "+" : "";
    $percentage =~ s/p$//i;

    my $isTaxonInFile;
    if ( $in_file && isInt($metag_oid) ) {
        my $dbh  = dbLogin();
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $metag_oid );
        #$dbh->disconnect();
    }

    if ( $ir_class || $ir_order || $family || $genus || $species  ) {
        #print "<p>0 $ir_class || $ir_order || $family || $genus || $species \n";
        if ( $isTaxonInFile ) {
            MetaFileHits::printTaxonomyMetagHits( $metag_oid, $data_type, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
                $percentage, $plus );
        } else {
            MetagenomeHits::printTaxonomyMetagHits( $metag_oid, 
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
                $percentage, $plus );
        }
    } else {
        #print "<p>1 $ir_class || $ir_order || $family || $genus || $species \n";
        if ( $isTaxonInFile ) {
            MetaFileHits::printMetagenomeHits( $metag_oid, $data_type, $percentage, $domain, $phylum, $plus );
        } else {
            MetagenomeHits::printMetagenomeHits( $metag_oid, $percentage, $domain, $phylum, $plus );
        }
    }
}

sub printGeneList_BodySite {
    my $percentage = param("percentage");    # 30, 60, 90
    my $xcopy      = param("xcopy");         # gene_count, est_copy
    my $body_site  = param("taxonomy");
    my $taxon_oids = param("taxon_oids");    # comma delimited - taxon oids
    my $metag_oid  = param("metag_oid");
    my $data_type  = param('data_type');

    my $plus = ( $percentage =~ /p$/i ) ? "+" : "";
    $percentage =~ s/p$//i;

    my $isTaxonInFile;
    if ( $in_file && isInt($metag_oid) ) {
        my $dbh  = dbLogin();
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $metag_oid );
        #$dbh->disconnect();
    }

    if ( $isTaxonInFile ) {

        # FIXME LATER
        # Amy: I will take care of this later.
        #	MetaFileHits::printTaxonomyMetagHits($metag_oid, $data_type,
        #		        $domain, $phylum,
        #	         	$ir_class, $ir_order, $family,
        #		      	$genus, $species, $percentage, $plus);
    } else {

        # MER-DB
        my $dbh = dbLogin();
        printBodySiteMetagHits( $dbh, $metag_oid, $body_site, $percentage );

        #$dbh->disconnect();
    }
}

sub printBodySiteMetagHits {
    my ( $dbh, $taxon_oid, $body_site, $percent ) = @_;

    # Get parameters via CGI if not passed through function
    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $body_site = param("body_site")        if !$body_site;
    $body_site = param("taxnomoly")        if !$body_site;
    $percent   = param("percent")          if !$percent;
    $percent   = param("percent_identity") if ( $percent eq "" );

    printMainForm();
    print "<h1>\n";
    print "Best Hits at $percent% Identity\n";
    print "</h1>\n";

    print "<h2>\n";
    my $s = "Body Site: $body_site";
    print escHtml($s);
    print "</h2>\n";
    printStatusLine( "Loading ...", 1 );
    PhyloUtil::printCartFooter2( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );

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
    }

    my $count              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    my $sort = param("sort");
    if ( !defined($sort) || $sort eq "" ) {

        # default is col 2, Gene Id
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

    my $percentClause = getPercentageClause( "dt", $percent );
    $dosql = 1;    #  FIXME LATER
    if ($dosql) {
        my $rclause   = WebUtil::urClause('t2');
        my $imgClause = WebUtil::imgClause('t2');
        my $sql       = qq{                                                             
            select  dt.gene_oid, dt.percent_identity
            from dt_phylum_dist_genes dt, taxon t2,
                project_info\@imgsg_dev p, 
                project_info_body_sites\@imgsg_dev b
            where dt.taxon_oid = ?
                and dt.homolog_taxon = t2.taxon_oid
                and (t2.gold_id = p.gold_stamp_id 
                    or t2.taxon_oid = p.img_oid)
                and p.project_oid = b.project_oid
                and b.sample_body_site = '$body_site'
                and $percentClause              
                $rclause
                $imgClause
        };

        my %gene_h;
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $gene_oid, $perc_avg ) = $cur->fetchrow();
            last if !$gene_oid;
            $gene_h{$gene_oid} = sprintf( "%.2f", $perc_avg );
        }
        $cur->finish();

        my @gene_oids = ();

        foreach my $key ( keys %gene_h ) {
            $count++;

            push @gene_oids, ($key);

            if ( scalar(@gene_oids) > $max_gene_batch ) {
                PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, \%gene_h, \@recs );
                PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );
                PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );
                @gene_oids = ();
            }
            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }

        PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, \%gene_h, \@recs );

        # remove duplicates from AoA by unique 1st element of each sub array
        @recs = HtmlUtil::uniqAoA( 0, @recs );

        PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );
        PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

        ( $file1, $file2, $file4 ) =
          PhyloUtil::cacheData( \@recs, \%hash_cog_func, \%hash_cog_pathway );
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
            $trunc = 1 if $count >= $maxGeneListResults;
        }
    }

    my $checked = param("coghide");
    if ( !defined($checked) || $checked eq "" || $checked ne "true" ) {
        $checked = "false";
    }

    MetagJavaScript::printMetagJS();

    my $it = new InnerTable( 1, "MetagBodySiteHits$$", "MetagBodySiteHits", 1 );
    my $sd = $it->getSdDelim();                                                    # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",      "asc",  "left" );
    $it->addColSpec( "Percent",      "desc", "right" );
    $it->addColSpec( "Name",         "asc",  "left" );
    $it->addColSpec( "COG ID",       "asc",  "left" );
    $it->addColSpec( "COG Name",     "asc",  "left" );
    $it->addColSpec( "COG Function", "asc",  "left" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    # default display - table view
    PhyloUtil::flushGeneBatch2( $it, \@recs, \%hash_cog_func );
    $it->printOuterTable(1);

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

sub printGenomeList {
    my $percentage = param("percentage"); # 30, 60, 90
    my $xcopy      = param("xcopy");      # gene_count, est_copy
    my $taxonomy   = param("taxonomy");   # $DELIMITER delimited - phyla names
    my $taxon_oids = param("taxon_oids"); # comma delimited - taxon oids
    my $data_type  = param('data_type');

    printStatusLine( "Loading ...", 1 );
    print "<h1> Metagenome Hits - Isolate Genome List</h1>\n";

    if ( $taxonomy ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
	    = split( $DELIMITER, $taxonomy );
        PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order,
				    $family, $genus, $species );
    }
    my ($text, $xcopyText) = printParamHeader( $percentage, $xcopy, $data_type);

    my $dbh = dbLogin();
    my @taxon_array = split( ",", $taxon_oids );
    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref );
    if (scalar @taxon_array > 5) {
	($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
	 $merfs_taxons_ref, $db_taxons_ref ) =
	     PhyloUtil::printCollapsableHeader
	     ($dbh, \@taxon_array, $data_type, 0);
    } else {
	($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
	 $merfs_taxons_ref, $db_taxons_ref ) =
	     PhyloUtil::printGenomeListSubHeader
	     ($dbh, \@taxon_array, $data_type, 0);
    }
    
    # taxon oid => taxon name
    my $genome_href = getGenomeList( $dbh, $taxon_oids, $percentage, $taxonomy );
    for my $id2 (@$phylo_fs_taxons_ref) {
        my $genome_href2;
        
        $id2 = sanitizeInt($id2);
        my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($id2);
        if ( -e $phylo_dir_name ) {
            $genome_href2 = getGenomeList_sdb( $dbh, $id2, $percentage, $taxonomy );
        } 

        for my $k ( keys %$genome_href2 ) {
            if ( !$genome_href->{$k} ) {
                $genome_href->{$k} = $genome_href2->{$k};
            }
        }
    }

    printMainForm();
    printJS();
    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "phyla" );
    print hiddenVar( "taxon_oids", $taxon_oids );
    print hiddenVar( "percentage", $percentage );
    print hiddenVar( "xcopy",      $xcopy );
    print hiddenVar( "taxonomy",   "" );
    print hiddenVar( "metag_oid",  "" );
    print hiddenVar( "data_type",  $data_type );

    my $it = new InnerTable( 0, "metagphylodistgenome$$", "metagphylodistgenome", 0 );
    #$it->addColSpec( "Select" );
    $it->addColSpec( "Genome ID",   "asc", "left" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    my $sd = $it->getSdDelim();

    my $taxon_url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $row_cnt = 0;
    foreach my $taxon_oid ( sort keys %$genome_href ) {
        my $taxon_name = $genome_href->{$taxon_oid};
        my $url        = $taxon_url . $taxon_oid;
        $url = alink( $url, $taxon_name );
        my $r;
        #$r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
        $r .= $taxon_oid . $sd . $taxon_oid . "\t";
        $r .= $taxon_name . $sd . $url . "\t";
        $it->addRow($r);
        $row_cnt++;
    }

    #WebUtil::printGenomeCartFooter() if ( $row_cnt > 10);
    $it->printOuterTable(1);
    #WebUtil::printGenomeCartFooter();

    print end_form();

    #$dbh->disconnect();
    my $rowcnt = keys %$genome_href;
    printStatusLine( "$rowcnt Loaded.", 2 );
}

sub printGenomeList_BodySite {
    my $percentage = param("percentage");    # 30, 60, 90
    my $xcopy      = param("xcopy");         # gene_count, est_copy
    my $taxon_oids = param("taxon_oids");    # comma delimited - taxon oids
    my $body_site  = param("taxonomy");
    my $data_type  = param('data_type');

    printStatusLine( "Loading ...", 1 );
    print "<h1>Metagenome Hits - Isolate Genome List (Body Site)</h1>\n";

    if ( $body_site ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
	    = split( $DELIMITER, $body_site );
        PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order,
				    $family, $genus, $species );
    }
    my ($text, $xcopyText) = printParamHeader( $percentage, $xcopy, $data_type);

    my $dbh = dbLogin();
    my @taxon_array = split( ",", $taxon_oids );

    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref );
    if (scalar @taxon_array > 5) {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printCollapsableHeader
	   ($dbh, \@taxon_array, $data_type, 0);
    } else {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printGenomeListSubHeader
	   ($dbh, \@taxon_array, $data_type, 0);
    }

    # taxon oid => taxon name
    my $genome_href = getGenomeList_BodySite( $dbh, $taxon_oids, $percentage, $body_site );
 
    for my $id2 (@$phylo_fs_taxons_ref) {
        my $genome_href2;

        $id2 = sanitizeInt($id2);
        my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($id2);

        if ( -e $phylo_dir_name ) {
            $genome_href2 = getGenomeList_sdb_BodySite( $dbh, $id2, $percentage, $body_site );
        }

        for my $k ( keys %$genome_href2 ) {
            if ( !$genome_href->{$k} ) {
                $genome_href->{$k} = $genome_href2->{$k};
            }
        }
    }

    printMainForm();
    printJS();
    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "phyla" );
    print hiddenVar( "taxon_oids", $taxon_oids );
    print hiddenVar( "percentage", $percentage );
    print hiddenVar( "xcopy",      $xcopy );
    print hiddenVar( "taxonomy",   $body_site );
    print hiddenVar( "metag_oid",  "" );
    print hiddenVar( "data_type",  $data_type );

    my $it = new InnerTable( 0, "metagphylodistgenome$$", "metagphylodistgenome", 0 );
    #$it->addColSpec( "Select" );
    $it->addColSpec( "Genome ID",   "number asc", "left" );
    $it->addColSpec( "Genome Name", "char asc",   "left" );
    my $sd = $it->getSdDelim();

    my $taxon_url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $row_cnt = 0;
    foreach my $taxon_oid ( sort keys %$genome_href ) {
        my $taxon_name = $genome_href->{$taxon_oid};
        my $url        = $taxon_url . $taxon_oid;
        $url = alink( $url, $taxon_name );
        my $r;
        #$r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
        $r .= $taxon_oid . $sd . $taxon_oid . "\t";
        $r .= $taxon_name . $sd . $url . "\t";
        $it->addRow($r);
        $row_cnt++;
    }

    #WebUtil::printGenomeCartFooter() if ( $row_cnt > 10);
    $it->printOuterTable(1);
    #WebUtil::printGenomeCartFooter();

    print end_form();

    #$dbh->disconnect();
    my $rowcnt = keys %$genome_href;
    printStatusLine( "$rowcnt Loaded.", 2 );
}

# when the user clicks the phyla name to drill down
# we stop the link on genus and species level
# see printTable
sub printNextPhyla {
    my $percentage = param("percentage");    # 30, 60, 90
    my $xcopy      = param("xcopy");         # gene_count, est_copy
    my $taxonomy   = param("taxonomy");      # comma delimited - phyla names
    my $taxon_oids = param("taxon_oids");    # comma delimited - taxon oids
    my $data_type  = param('data_type');          #

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Phylogenetic Distribution of Metagenomes</h1>\n";
    if ( $taxonomy ) {
        my ($domain, $phylum, $ir_class, $ir_order, $family, $genus, $species)
	    = split( $DELIMITER, $taxonomy );
        PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order,
				    $family, $genus, $species );
    }
    my ($text, $xcopyText) = printParamHeader($percentage, $xcopy, $data_type);

    my $dbh = dbLogin();
    my @taxon_array = split( ",", $taxon_oids );

    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref );
    if (scalar @taxon_array > 5) {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printCollapsableHeader
	   ($dbh, \@taxon_array, $data_type, 1);
    } else {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printGenomeListSubHeader
	   ($dbh, \@taxon_array, $data_type, 1);
    }

    if ( !$mer_fs_debug ) {
        printStartWorkingDiv();
    }

    print "<p>computing genome gene count ...<br/>\n";
    my $total_gene_count_href = getGenomeGeneCount
	( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type );

    my $total_est_copy_count_href;
    if ( $xcopy eq 'est_copy' ) {
        print "<p>Computing genome est copy count ...\n";
        $total_est_copy_count_href = getGenomeEstCopyCount
	    ( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type, $total_gene_count_href );        
    }

    my $genome_count_href;
    my $taxon_list_href;

    if ( scalar(@$phylo_db_taxons_ref) > 0 ) {
        print "computing gene counts for @$phylo_db_taxons_ref ...<br/>\n";
    }

    my ( $gene_count_href, $homolog_count_href ) = getGeneCounts( $dbh, $phylo_db_taxons_ref, $percentage, $taxonomy, 1 );

    for my $t_id (@$phylo_fs_taxons_ref) {
        print "computing gene counts for $t_id ...<br/>\n";

        my ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 );

        $t_id = sanitizeInt($t_id);
        my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($t_id);
        if ( -e $phylo_dir_name ) {
            ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 ) =
              getGeneCounts_sdb( $dbh, $t_id, $data_type, $percentage, $taxonomy );
        }

        for my $k ( keys %$gene_count_href2 ) {
            my $new_k = $k;
            if ( $new_k =~ /Viruses/ ) {
                $new_k =~ s/\_no/\, no/;
            }
            $new_k =~ s/\_/ /g;

            if ( $gene_count_href2->{$k}->{$t_id} ) {
                $gene_count_href->{$new_k}->{$t_id} = $gene_count_href2->{$k}->{$t_id};
            }
        }

        for my $k ( keys %$homolog_count_href2 ) {
            my $new_k = $k;
            if ( $new_k =~ /Viruses/ ) {
                $new_k =~ s/\_no/\, no/;
            }
            $new_k =~ s/\_/ /g;

            if ( $homolog_count_href2->{$k}->{$t_id} ) {
                $homolog_count_href->{$new_k}->{$t_id} = $homolog_count_href2->{$k}->{$t_id};
            }
        }

        for my $k ( keys %$taxon_list_href2 ) {
            my $new_k = $k;
            if ( $new_k =~ /Viruses/ ) {
                $new_k =~ s/\_no/\, no/;
            }
            $new_k =~ s/\_/ /g;

            if ( $taxon_list_href->{$k} ) {
                $taxon_list_href->{$new_k} .= "," . $taxon_list_href2->{$k};
            } else {
                $taxon_list_href->{$new_k} = $taxon_list_href2->{$k};
            }
        }
    }    # for t_id

    # get distinct genome count
    if ( scalar(@$phylo_fs_taxons_ref) == 0 ) {
        $genome_count_href = getGenomeCount( $dbh, $taxon_oids, $percentage, $taxonomy );
    } else {
        if ( scalar(@$phylo_db_taxons_ref) > 0 ) {
            my $taxon_list_href3 = getGenomeNameList( $dbh, $phylo_db_taxons_ref, $percentage );

            for my $k ( keys %$taxon_list_href3 ) {
                if ( $taxon_list_href->{$k} ) {
                    $taxon_list_href->{$k} .= "," . $taxon_list_href3->{$k};
                } else {
                    $taxon_list_href->{$k} = $taxon_list_href3->{$k};
                }
            }
        }

        # count distinct taxons
        for my $k ( keys %$taxon_list_href ) {
            my @taxons = split( /\,/, $taxon_list_href->{$k} );
            my %count_hash;
            undef %count_hash;
            for my $t2 (@taxons) {
                $count_hash{$t2} = 1;
            }
            $genome_count_href->{$k} = scalar( keys %count_hash );
        }
    }

    if ( !$mer_fs_debug ) {
        printEndWorkingDiv();
    }

    printJS();
    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "phyla" );
    print hiddenVar( "taxon_oids", $taxon_oids );
    print hiddenVar( "percentage", $percentage );
    print hiddenVar( "xcopy",      $xcopy );
    print hiddenVar( "taxonomy",   "" );
    print hiddenVar( "metag_oid",  "" );
    print hiddenVar( "data_type",  $data_type );

    my $rowcnt =
      printTable( \@taxon_array, $taxon_name_href, 
                  $gene_count_href, $genome_count_href, 
		  $homolog_count_href, 0, "",
                  $total_gene_count_href, $total_est_copy_count_href );

    print end_form();
    printStatusLine( "$rowcnt Loaded.", 2 );
}

sub printParamHeader {
    my ( $percentage, $xcopy, $data_type) = @_;
    my $text = getPercentageText($percentage);
    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    print qq{
        <p>
        <u>Percent Identity</u>: $text<br/>
        <u>Display</u>: $xcopyText<br/>
        <u>MER-FS Metagenome</u>: $data_type<br/>
        </p>
    };

    return ($text, $xcopyText);
}

#
# filter
#
# initial form result page
sub printResults {
    my $percentage         = param("percentage");    # 30, 60, 90
    my $xcopy              = param("xcopy");         # gene_count, est_copy
    my $gene_count_file    = param("gene_count_file");
    my $homolog_count_file = param("homolog_count_file");
    my $genome_count_file  = param("genome_count_file");
    my $show_percentage    = param("show_percentage");
    my $show_hist          = param("show_hist");
    my $data_type          = param("data_type");     # assembled or unassembled or both

    my @filters = param("filter");                   # filter on selected phyla
    my %filters_hash;                                # list of phyla to show
    foreach my $x (@filters) {
        $filters_hash{$x} = $x;
    }

    my @genomeFilterSelections = param('genomeFilterSelections');
    my $find_toi_ref =  \@genomeFilterSelections; 
    if ( $#$find_toi_ref < 0 ) {
        # filter does not have taxon oids
        my @taxon_oids = param("taxon_oid");
        $find_toi_ref = \@taxon_oids;
    }
    my $taxon_oids_str = join( ",", @$find_toi_ref );
    if ( $#$find_toi_ref < 0 ) {
        webError("Please select at least 1 genome.<br/>\n");
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    
    print "<h1>Phylogenetic Distribution of Metagenomes</h1>\n";
    my ($text, $xcopyText) = printParamHeader($percentage, $xcopy, $data_type);

    timeout( $merfs_timeout_mins * 60 );

    my $sid        = getContactOid();
    my $start_time = time();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $dbh = dbLogin();

    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref );
    if (scalar @$find_toi_ref > 5) {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printCollapsableHeader
	   ($dbh, $find_toi_ref, $data_type, 1);
    } else {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
	   PhyloUtil::printGenomeListSubHeader
	   ($dbh, $find_toi_ref, $data_type, 1);
    }

    if ( !$mer_fs_debug ) {
        printStartWorkingDiv();
    }

    print "<p>Computing genome gene count ...\n";
    my $total_gene_count_href = getGenomeGeneCount( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type );

    my $total_est_copy_count_href;
    if ( $xcopy eq 'est_copy' ) {
        print "<p>Computing genome est copy count ...\n";
        $total_est_copy_count_href = getGenomeEstCopyCount( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type, $total_gene_count_href );        
    }

    my $gene_count_href;
    my $homolog_count_href;
    my $genome_count_href;
    my $taxon_list_href;

    if ( $gene_count_file eq "" ) {
        if ( scalar(@$phylo_db_taxons_ref) > 0 ) {
            print "<p>Computing gene counts for @$phylo_db_taxons_ref ...\n";
        }
        ( $gene_count_href, $homolog_count_href ) = getGeneCounts( $dbh, $phylo_db_taxons_ref, $percentage, '', 1 );

        if ( scalar(@$phylo_fs_taxons_ref) > 0 ) {
            print "<p>This computation takes longer because metagenomes with phylogentic files are selected.\n";

            for my $t_id (@$phylo_fs_taxons_ref) {
                print "<p>computing gene counts for $t_id ...\n";
    
                my ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 );
                
                $t_id = sanitizeInt($t_id);
                my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($t_id);
                if ( -e $phylo_dir_name ) {
                    ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 ) =
                      getGeneCounts_sdb( $dbh, $t_id, $data_type, $percentage );
                }
    
                for my $k ( keys %$gene_count_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $gene_count_href2->{$k}->{$t_id} ) {
                        $gene_count_href->{$new_k}->{$t_id} = $gene_count_href2->{$k}->{$t_id};
                    }
                }
    
                for my $k ( keys %$homolog_count_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $homolog_count_href2->{$k}->{$t_id} ) {
                        $homolog_count_href->{$new_k}->{$t_id} = $homolog_count_href2->{$k}->{$t_id};
                    }
                }
    
                for my $k ( keys %$taxon_list_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $taxon_list_href->{$k} ) {
                        $taxon_list_href->{$new_k} .= "," . $taxon_list_href2->{$k};
                    } else {
                        $taxon_list_href->{$new_k} = $taxon_list_href2->{$k};
                    }
                }
            }
        }

        # get distinct genome counts for all homologs
        if ( scalar(@$phylo_fs_taxons_ref) == 0 ) {

            # only db taxons
            $genome_count_href = getGenomeCount( $dbh, $taxon_oids_str, $percentage );
        } else {
            if ( scalar(@$phylo_db_taxons_ref) > 0 ) {
                my $taxon_list_href3 = getGenomeNameList( $dbh, $phylo_db_taxons_ref, $percentage );

                for my $k ( keys %$taxon_list_href3 ) {
                    if ( $taxon_list_href->{$k} ) {
                        $taxon_list_href->{$k} .= "," . $taxon_list_href3->{$k};
                    } else {
                        $taxon_list_href->{$k} = $taxon_list_href3->{$k};
                    }
                }
            }

            # count distinct taxons
            for my $k ( keys %$taxon_list_href ) {
                my @taxons = split( /\,/, $taxon_list_href->{$k} );
                my %count_hash;
                undef %count_hash;
                for my $t2 (@taxons) {
                    $count_hash{$t2} = 1;
                }
                $genome_count_href->{$k} = scalar( keys %count_hash );
            }
        }

        $gene_count_file    = cacheHashHash( $gene_count_href,    "gene" );
        $homolog_count_file = cacheHashHash( $homolog_count_href, "homolog" );
        $genome_count_file  = cacheHash( $genome_count_href,      "genome" );

    } else {

        # read cache file
        $gene_count_href    = readHashHash($gene_count_file);
        $homolog_count_href = readHashHash($homolog_count_file);
        $genome_count_href  = readHash($genome_count_file);
    }

    if ( !$mer_fs_debug ) {
        printEndWorkingDiv();
    }

    webError(   "Phylogenetic distribution data is not available for "
              . "<b>$text percent identity</b> based on <b>$xcopyText</b> for "
              . "the selected metagenome(s) (<b>$data_type</b>)." )
      if !%$gene_count_href;

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    printJS();
    print hiddenVar( "section",            $section );
    print hiddenVar( "page",               "phyla" );
    print hiddenVar( "taxon_oids",         $taxon_oids_str );
    print hiddenVar( "percentage",         $percentage );
    print hiddenVar( "xcopy",              $xcopy );
    print hiddenVar( "taxonomy",           "" );
    print hiddenVar( "metag_oid",          "" );
    print hiddenVar( "data_type",          $data_type );
    print hiddenVar( "gene_count_file",    $gene_count_file );
    print hiddenVar( "homolog_count_file", $homolog_count_file );
    print hiddenVar( "genome_count_file",  $genome_count_file );
    print hiddenVar( "show_percentage",    $show_percentage );
    print hiddenVar( "show_hist",          $show_hist );

    foreach my $x (@$find_toi_ref) {
        # for filter
        print hiddenVar( "taxon_oid", $x );
    }

    printHint("Hit gene count is shown in brackets ( ).");
    print "<br/>";

    print qq{
        <input class='smdefbutton' type='button' value='View Selected'
        onClick="javascript:mySubmit3('process')" />
        &nbsp;
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
        <br/>
    };

    # x-axis labels
    my @chartcategories;

    # data poits, array of arrays
    # array 1 = 1st genome list of percentages
    my @chartdata;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my @tmp = ();
        push( @chartdata, \@tmp );
    }

    my $rowcnt = printTable(
         $find_toi_ref, $taxon_name_href, $gene_count_href, $genome_count_href,
         $homolog_count_href, 1, \%filters_hash,   
         $total_gene_count_href, $total_est_copy_count_href,
         \@chartcategories,   \@chartdata
    );

    print qq{
        <input class='smdefbutton' type='button' value='View Selected'
        onClick="javascript:mySubmit3('process')" />
        &nbsp;
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
    };

    print end_form();

    #$dbh->disconnect();

    # PREPARE THE BAR CHART
    # width should depend on the number of catergories and number of genomes
    my $min_width   = 300;
    my $num_genomes = $#$find_toi_ref + 1;

    # number of genomes - grouping of bars for each category
    my @chartseries;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my $oid = $find_toi_ref->[$i];
        #push( @chartseries, "$oid" );
        my $name = $taxon_name_href->{$oid};
        push( @chartseries, "$oid - $name" );
    }

    my $url = "";
    $min_width = ( scalar @chartcategories ) * 25 * ( scalar @chartseries );
    my $window_w = $min_width + 100;
    $window_w = 800 if ( $window_w > 800 );

    my $chart = newBarChart();
    $chart->WIDTH($min_width);  # 4096 for 75 catergories and 2 genomes
    $chart->HEIGHT(600);
    $chart->DOMAIN_AXIS_LABEL("Phylum");       # x-axis
    $chart->RANGE_AXIS_LABEL("Percentage");    # y-axis
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->ITEM_URL( $url . "&chart=y" );
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_LEGEND("yes");
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );

    # now set data as array for strings delimited by commas
    # array 1 = .01,12,...
    # array 2 = .2,.23,...
    my @datas;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my $aref = $chartdata[$i];
        my $datastr = join( ",", @$aref );
        push( @datas, $datastr );
    }
    $chart->DATA( \@datas );

    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        my $htmlpage;    # html page
        if ( $st == 0 ) {
            $htmlpage = "<script src='$base_url/overlib.js'></script>\n";
            webLog( $chart->FILEPATH_PREFIX . ".html\n" );

            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "metachart", 1 );
            while ( my $s = $FH->getline() ) {
                $htmlpage .= $s;
            }
            close($FH);
            $htmlpage .= "<img src='$tmp_url/"
		       . $chart->FILE_PREFIX . ".png' BORDER=0 ";
            $htmlpage .= " width=" . $chart->WIDTH . " HEIGHT=" 
		       . $chart->HEIGHT;
            $htmlpage .= " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
        my $sid  = getSessionId();
        my $file = "chart$$" . "_" . $sid . ".html";
        my $path = "$tmp_dir/$file";
        my $FH   = newWriteFileHandle($path);
        print $FH $htmlpage;
        close $FH;

        print qq{
            <p>
            You may view this phylogenetic distribution in a Bar Chart<br/>
            <input class='smbutton' type='button' value='Bar Chart'
             onClick="javascript:window.open('$tmp_url/$file','popup',
             'width=$window_w,height=650,scrollbars=yes,status=no,resizable=yes,toolbar=no'); 
             window.focus();" 
            />&nbsp; will be in a new new pop-up window or tab.
            </p>
        };
    }
    printStatusLine( "$rowcnt Loaded.", 2 );
}

sub cacheHash {
    my ( $href, $text ) = @_;
    my $id        = getSessionId();
    my $cacheFile = "metagphylodist" . $text . $id . $$;
    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    my $res = newWriteFileHandle( $cachePath, "runJob" );
    foreach my $key ( keys %$href ) {
        print $res $key . "=====" . $href->{$key} . "\n";
    }
    close $res;
    return $cacheFile;
}

sub readHash {
    my ($file) = @_;
    my $cachePath = "$cgi_tmp_dir/$file";
    my %hash;
    my $res = newReadFileHandle( $cachePath, "runJob" );
    while ( my $line = $res->getline() ) {
        chomp $line;
        my ( $key, $value ) = split( /=====/, $line );
        $hash{$key} = $value;
    }

    close $res;
    return \%hash;
}

sub cacheHashHash {
    my ( $href, $text ) = @_;
    my $id        = getSessionId();
    my $cacheFile = "metagphylodist" . $text . $id . $$;
    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    my $res = newWriteFileHandle( $cachePath, "runJob" );
    foreach my $key ( keys %$href ) {
        my $href2 = $href->{$key};
        foreach my $key2 ( keys %$href2 ) {
            my $tmp = $href2->{$key2};
            print $res $key . "=====" . $key2 . "=====" . $tmp . "\n";
        }
    }
    close $res;
    return $cacheFile;
}

sub readHashHash {
    my ($file) = @_;
    my $cachePath = "$cgi_tmp_dir/$file";
    my %hash;
    my $res = newReadFileHandle( $cachePath, "runJob" );
    while ( my $line = $res->getline() ) {
        chomp $line;
        my ( $key, $key2, $value ) = split( /=====/, $line );
        if ( exists $hash{$key} ) {
            my $href2 = $hash{$key};
            $href2->{$key2} = $value;
        } else {
            my %hash2;
            $hash2{$key2} = $value;
            $hash{$key}   = \%hash2;
        }
    }
    close $res;
    return \%hash;
}

# $selectCol - string boolean flag to print a select column
sub printTable {
    my (
         $find_toi_ref, $taxon_name_href, $gene_count_href, $genome_count_href,
         $homolog_count_href, $selectCol, $filters_href,    
         $total_gene_count_href,$total_est_copy_count_href,
         $chartcategories_aref, $chartdata_aref
      )
      = @_;

    my $xcopy    = param("xcopy");       # gene_count, est_copy
    my $taxonomy = param("taxonomy");    # comma delimited - phyla names
    my $data_type = param("data_type");  # assembled or unassembled or both

    my $show_percentage = param("show_percentage");
    my $show_hist       = param("show_hist");

    my $phylumColLabel = "Phylum";
    if ( $taxonomy ne "" ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family,
	     $genus, $species ) = split( $DELIMITER, $taxonomy );
        $phylumColLabel = "Class"         if ( $phylum );
        $phylumColLabel = "Order"         if ( $ir_class );
        $phylumColLabel = "Family"        if ( $ir_order );
        $phylumColLabel = "Genus"         if ( $family );
        $phylumColLabel = "Species"       if ( $genus );
    }

    my $sortCol = 0;
    if ($selectCol) {
        $sortCol = 1;
    }

    ## get MER-FS taxons
    my %mer_fs_taxons;
    if ($in_file) {
        my $dbh = dbLogin();
        %mer_fs_taxons = MerFsUtil::getTaxonsInFile($dbh);
    }

    # get total counts for percentage
    my %total_counts;
    if ( $xcopy eq 'est_copy' ) {
        %total_counts = %$total_est_copy_count_href;
    }
    else {
        %total_counts = %$total_gene_count_href;
    }

    # export file
    my $id         = getSessionId();
    my $exportFile = "export" . $id . ".txt";
    my $exportPath = "$tmp_dir/$exportFile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # table header
    my $it = new InnerTable(0, "metagphylodist$$", "metagphylodist", $sortCol);
    my $sd = $it->getSdDelim();
    if ($selectCol) {
        $it->addColSpec( "Select" );
        $it->addColSpec( "Domain", "asc", "left" );    # domain col
        print $res "Domain\t";
    }
    $it->addColSpec( "$phylumColLabel", "asc", "left" );
    print $res "Phylum\t";
    $it->addColSpec( "Genome Count", "desc", "right", "", "Isoate genome count", "wrap" );
    print $res "Genome Count\t";

    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    foreach my $id ( sort @$find_toi_ref ) {
        my $name = $taxon_name_href->{$id};
        my $abbr_name = WebUtil::abbrColName( $id, $name, 1 );
        if ( $mer_fs_taxons{$id} ) {
            $abbr_name .= "<br/>(MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $abbr_name .= "<br/>($data_type)";
            }
        }
        $it->addColSpec("$abbr_name<br/>$xcopyText",
                        "desc", "right", "", 
			"$name - Metagenome $xcopyText (homolog gene count)");

        print $res "$name - Metagenome $xcopyText (homolog gene count)\t";

        # percentage col
        # column name must be unique for yui tables
        if ( $show_percentage ) {
            my $pcToolTip = PhyloUtil::getPcToolTip( $name, $xcopy, $total_counts{$id} );
            $it->addColSpec( "$abbr_name <br/> &#37; ",
                             "desc", "right", "", $pcToolTip );
            print $res "Percentage\t";
        }

        # histogram
        if ( $show_hist ne "" ) {
            $it->addColSpec("$abbr_name <br/> Histogram");
        }

    }
    print $res "\n";

    # end of column headers

    # start of data rows
    my $rowcnt = 0;
    foreach my $name ( sort keys %$gene_count_href ) {
        my $r;

        # ($domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
        my (@tmp) = split( /\t/, $name );

        # common separator / delimiter
        my $tmp_str = join( $DELIMITER, @tmp );    # for javascript label
        $tmp_str = CGI::escape($tmp_str);

        my $name2 = $name;
        $name2 =~ s/\t/ /g;

        # filter
        if ( $filters_href ne "" ) {
            my $cnt = keys %$filters_href;
            if ( $cnt > 0 && !exists $filters_href->{$name2} ) {
                next;
            }
        }

        if ($selectCol) {
            $r .= $sd . "<input type='checkbox' name='filter' " . "value='$name2' checked />" . "\t";

            # domain
            $r .= $tmp[0] . $sd . $tmp[0] . "\t";
        }

        # $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species
        my $display_name = $tmp[$#tmp];
        if ( $#tmp < 6 ) {
            my $url = qq{ <a href="javascript:mySubmit('$tmp_str', 'phyla')"> $display_name </a>};
            $r .= $display_name . $sd . $url . "\t";

        } else {
            # species
            # no link for species level
            $r .= $display_name . $sd . $display_name . "\t";
        }

        print $res $name2 . "\t";

        # bar chart x-axis labels
        if ( $chartcategories_aref ne "" ) {
            push( @$chartcategories_aref, $name2 );
        }

        my $genome_cnt = $genome_count_href->{$name};
        my $url        = qq{ <a href="javascript:mySubmit('$tmp_str', 'genome')"> $genome_cnt </a>};
        $r .= $genome_cnt . $sd . $url . "\t";

        print $res $genome_cnt . "\t";

        my $thref   = $gene_count_href->{$name};
        my $hl_href = $homolog_count_href->{$name};
        my $index   = 0;
        foreach my $toid ( sort @$find_toi_ref ) {
            my $count = $thref->{$toid};
            $count = 0 if ( $count eq "" );

            # homolog gene count
            my $hl_count = $hl_href->{$toid};
            $hl_count = 0 if ( $hl_count eq "" );

            if ( $count == 0 ) {
                $r .= $count . $sd . "$count ($hl_count)" . "\t";
            } else {
                my $url = qq{ <a href="javascript:mySubmitGene('$tmp_str', '$toid')"> $count </a>};
                $r .= $count . $sd . "$url ($hl_count)" . "\t";
            }
            print $res "$count ($hl_count)" . "\t";

            # percentage
            my $per = 0;
            $per = $count * 100 / $total_counts{$toid} 
                if ($total_counts{$toid});
            if ( $show_percentage ne "" ) {
                my $per2 = sprintf( "%.2f", $per );
                $r .= $per2 . $sd . "$per2" . "\t";
                print $res "$per\t";
            }

            # histogram
            if ( $show_hist ne "" ) {
                $r .= $sd . histogramBar( $per, 1 ) . "\t";
            }

            # bar chart data - array of array
            if ( $chartdata_aref ne "" ) {
                my $aref = $chartdata_aref->[$index];
                push( @$aref, $per );
                $index++;
            }

        }
        print $res "\n";
        $it->addRow($r);
        $rowcnt++;
    }

    $it->printOuterTable("nopage");
    close $res;

    return $rowcnt;

}

# get list of genomes
sub getGenomeList {
    my ( $dbh, $genome_str, $percentage, $taxonomy ) = @_;
    my $percentClause = getPercentageClause( "dt", $percentage );

    # taxon_oid -> taxon_name
    my %hash;

    my $phylaClause;
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }
    $phylaClause .= " and t2.domain = ? "   if ( $domain   ne "" );
    $phylaClause .= " and t2.phylum = ? "   if ( $phylum   ne "" );
    $phylaClause .= " and t2.ir_class = ? " if ( $ir_class ne "" );
    $phylaClause .= " and t2.ir_order = ? " if ( $ir_order ne "" );
    $phylaClause .= " and t2.family = ? "   if ( $family   ne "" );
    $phylaClause .= " and t2.genus = ? "    if ( $genus    ne "" );
    $phylaClause .= " and t2.species = ? "  if ( $species  ne "" );

    # check permission
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select distinct t2.taxon_oid, t2.taxon_display_name
        from dt_phylum_dist_genes dt, taxon t2
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            $phylaClause   
            $rclause 
            $imgClause
    };
    my $cur;
    if ( $taxonomy ne "" ) {
        my @binds = ();
        for my $k2 ( split( $DELIMITER, $taxonomy ) ) {
            if ($k2) {
                push @binds, ($k2);
            }
        }
        $cur = execSql( $dbh, $sql, $verbose, @binds );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $hash{$taxon_oid} = $taxon_name;

    }
    $cur->finish();

    return \%hash;
}

# get list of genomes (body site)
sub getGenomeList_BodySite {
    my ( $dbh, $genome_str, $percentage, $body_site ) = @_;
    my $percentClause = getPercentageClause( "dt", $percentage );

    # taxon_oid -> taxon_name
    my %hash;

    # check permission
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');

    $body_site =~ s/'/''/g;    # replace ' with ''

    my $sql = qq{
        select distinct t2.taxon_oid, t2.taxon_display_name
        from dt_phylum_dist_genes dt, taxon t2,
            project_info\@imgsg_dev p, 
            project_info_body_sites\@imgsg_dev b
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            and (t2.gold_id = p.gold_stamp_id 
                or t2.taxon_oid = p.img_oid)                    
            and p.project_oid = b.project_oid
            and b.sample_body_site = '$body_site'
            $rclause 
            $imgClause
    };

    if ( !$body_site || $body_site eq 'Unknown' ) {
        $sql = qq{
            select distinct t2.taxon_oid, t2.taxon_display_name
            from dt_phylum_dist_genes dt, taxon t2,
                 project_info\@imgsg_dev p
            where $percentClause 
                and dt.taxon_oid in ($genome_str)   
                and dt.homolog_taxon = t2.taxon_oid
                and (t2.gold_id = p.gold_stamp_id 
                    or t2.taxon_oid = p.img_oid)
                and p.project_oid in (
                    select p2.project_oid 
                    from project_info\@imgsg_dev p2
                    minus 
                    select b.project_oid 
                    from project_info_body_sites\@imgsg_dev b
                )
                $rclause
                $imgClause
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $hash{$taxon_oid} = $taxon_name;

    }
    $cur->finish();
    return \%hash;
}

sub getGenomeList_sdb {
    my ( $dbh, $taxon_oid, $percentage, $taxonomy ) = @_;

    my $data_type = param('data_type');

    my @perc_list = ();
    if ( isInt($percentage) ) {
        @perc_list = ($percentage);
    } elsif ( $percentage eq '30p' ) {
        @perc_list = ( 30, 60, 90 );
    } elsif ( $percentage eq '60p' ) {
        @perc_list = ( 60, 90 );
    }

    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }

    if ($mer_fs_debug) {
        print "<p>domain: $domain, phylum: $phylum, class: $ir_class, order: $ir_order, family: $family\n";
    }

    my $display_level = "phylum";

    if ($family) {
        $display_level = "genus";
    } elsif ($ir_order) {
        $display_level = "family";
    } elsif ($ir_class) {
        $display_level = "order";
    } elsif ($phylum) {
        $display_level = "class";
    }

    if ($mer_fs_debug) {
        print "<p>display level: $display_level\n";
    }

    my %taxon_h;
    my %taxon_name_h;
    my $nvl       = getNvl();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
          select t.taxon_oid, t.taxon_display_name,
                 t.domain, t.phylum,
                 $nvl(t.ir_class, '$unknown'),
                 $nvl(t.ir_order, '$unknown'),
                 $nvl(t.family, '$unknown'),
                 $nvl(t.genus, '$unknown'),
                 $nvl(t.species, '$unknown')
          from taxon t
          where 1 = 1
          $rclause
          $imgClause
          };

    if ($domain) {
        if ( $domain =~ /$unknown/ ) {
            $sql .= " and (domain is null or phylum = '$domain')";
        } else {
            $sql .= " and domain = '$domain'";
        }
    }
    if ($phylum) {
        if ( $phylum =~ /$unknown/ ) {
            $sql .= " and (phylum is null or phylum = '$phylum')";
        } else {
            $sql .= " and phylum = '$phylum'";
        }
    }
    if ($ir_class) {
        if ( $ir_class eq $unknown ) {
            $sql .= " and (ir_class is null or ir_class = '$ir_class')";
        } else {
            $sql .= " and ir_class = '$ir_class'";
        }
    }
    if ($ir_order) {
        if ( $ir_order eq $unknown ) {
            $sql .= " and (ir_order is null or ir_order = '$ir_order')";
        } else {
            $sql .= " and ir_order = '$ir_order'";
        }
    }
    if ($family) {
        if ( $family eq $unknown ) {
            $sql .= " and (family is null or family = '$family')";
        } else {
            $sql .= " and family = '$family'";
        }
    }
    if ($genus) {
        if ( $genus eq $unknown ) {
            $sql .= " and (genus is null or genus = '$family')";
        } else {
            $sql .= " and genus = '$genus'";
        }
    }
    if ($species) {
        if ( $species eq $unknown ) {
            $sql .= " and (species is null or species = '$species')";
        } else {
            $sql .= " and species = '$species'";
        }
    }

    if ($mer_fs_debug) {
        print "<p>SQL: $sql<br/>\n";
    }

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $t2, $name2, $d2, $p2, $c2, $o2, $f2, $g2, $s2 ) = $cur->fetchrow();
        last if ( !$t2 );

        if ( !$c2 ) {
            $c2 = 'unclassified';
        }
        if ( !$o2 ) {
            $o2 = 'unclassified';
        }
        if ( !$f2 ) {
            $f2 = 'unclassified';
        }

        $taxon_h{$t2}      = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2 . "\t" . $f2 . "\t" . $g2 . "\t" . $s2;
        $taxon_name_h{$t2} = $name2;
    }

    $cur->finish();

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = MetaUtil::getDataTypeList( $data_type );

    # (unique) homolog taxon list
    my %taxon_hash;
    for my $t2 (@type_list) {
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/$t2" . ".profile.txt";
        if ( -e $full_dir_name ) {
            my $res = newReadFileHandle( $full_dir_name, "phyloDist" );
            while ( my $line = $res->getline() ) {
                chomp $line;
                my ( $t2_oid, $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 ) = split( /\t/, $line );
                if ( !isInt($t2_oid) ) {
                    next;
                }
                if ( $taxon_h{$t2_oid} ) {

                    # included
                    $taxon_hash{$t2_oid} = $taxon_name_h{$t2_oid};
                }
            }    # end while line
            close $res;
        }
    }    # end t2

    return ( \%taxon_hash );
}

sub getGenomeList_sdb_BodySite {
    my ( $dbh, $taxon_oid, $percentage, $body_site ) = @_;

    my $data_type = param('data_type');

    my @perc_list = ();
    if ( isInt($percentage) ) {
        @perc_list = ($percentage);
    } elsif ( $percentage eq '30p' ) {
        @perc_list = ( 30, 60, 90 );
    } elsif ( $percentage eq '60p' ) {
        @perc_list = ( 60, 90 );
    }

    if ($mer_fs_debug) {
        print "<p>display level: Body Site\n";
    }

    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select t2.taxon_oid, b.sample_body_site
        from taxon t2, project_info\@imgsg_dev p, 
             project_info_body_sites\@imgsg_dev b
        where (t2.gold_id = p.gold_stamp_id or t2.taxon_oid = p.img_oid)
        and p.project_oid = b.project_oid
        and b.sample_body_site is not null
        $rclause
        $imgClause
        order by 1, 2
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %taxon_bodysite;
    my %bodysite_h;
    for ( ; ; ) {
        my ( $taxon_oid, $body_site ) = $cur->fetchrow();
        last if ( !$taxon_oid );

        if ( $taxon_bodysite{$taxon_oid} ) {
            my $href = $taxon_bodysite{$taxon_oid};
            $href->{$body_site} = 1;
        } else {
            my %htmp;
            $htmp{$body_site}           = 1;
            $taxon_bodysite{$taxon_oid} = \%htmp;
        }

        $bodysite_h{$body_site} = 1;
    }
    $cur->finish();

    # (unique) homolog taxon list
    my %taxon_hash;

    $taxon_oid = sanitizeInt($taxon_oid);
    
    my @type_list = MetaUtil::getDataTypeList( $data_type );

    my %taxon_hash;
    for my $t2 (@type_list) {
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/$t2" . ".profile.txt";
        if ( -e $full_dir_name ) {
            my $res = newReadFileHandle( $full_dir_name, "phyloDist" );
            while ( my $line = $res->getline() ) {
                chomp $line;
                my ( $t2_oid, $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 ) = split( /\t/, $line );
                if ( !isInt($t2_oid) ) {
                    next;
                }
                
                if ( $taxon_bodysite{$t2_oid} ) {
                    # with body site
                    my $href2 = $taxon_bodysite{$t2_oid};
                    if ( $href2->{$body_site} ) {
                        $taxon_hash{$t2_oid} = $t2_oid;
                    }
                }
            }    # end while line
            close $res;
        }
    }    # end t2

    return ( \%taxon_hash );
}

sub getGenomeNameList {
    my ( $dbh, $db_genomes_ref, $percentage, $taxonomy ) = @_;

    my %taxon_hash;

    if ( scalar(@$db_genomes_ref) <= 0 ) {
        return \%taxon_hash;
    }

    my $genome_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_genomes_ref );
    
    my $percentClause = getPercentageClause( "dt", $percentage );

    my $phylaClause;
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }
    $phylaClause .= " and t2.domain = ? "   if ( $domain   ne "" );
    $phylaClause .= " and t2.phylum = ? "   if ( $phylum   ne "" );
    $phylaClause .= " and t2.ir_class = ? " if ( $ir_class ne "" );
    $phylaClause .= " and t2.ir_order = ? " if ( $ir_order ne "" );
    $phylaClause .= " and t2.family = ? "   if ( $family   ne "" );
    $phylaClause .= " and t2.genus = ? "    if ( $genus    ne "" );
    $phylaClause .= " and t2.species = ? "  if ( $species  ne "" );

    # select and group by clause
    my $selectClause;
    $selectClause .= " ,$nvl(t2.ir_class, '$unknown') " if ( $phylum ne "" );
    $selectClause .= " ,$nvl(t2.ir_order, '$unknown') "
      if ( $phylum ne "" && $ir_class ne "" );
    $selectClause .= " ,t2.family " if ( $phylum ne "" && $ir_order ne "" );
    $selectClause .= " ,$nvl(t2.genus, '$unknown') "
      if ( $phylum ne "" && $family ne "" );
    $selectClause .= " ,$nvl(t2.species, '$unknown') "
      if ( $phylum ne "" && $family ne "" );

    # check permission
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select distinct t2.taxon_oid,
            t2.domain, t2.phylum $selectClause
        from dt_phylum_dist_genes dt, taxon t2
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            $phylaClause
            $rclause
            $imgClause
        order by t2.domain, t2.phylum $selectClause    
    };

    my $cur;
    if ( $taxonomy ne "" ) {
        my @binds = split( $DELIMITER, $taxonomy );
        $cur = execSql( $dbh, $sql, $verbose, @binds );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    for ( ; ; ) {
        my ( $taxon_oid, @temp ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $name = join( "\t", @temp );

        if ( $taxon_hash{$name} ) {
            $taxon_hash{$name} .= "," . $taxon_oid;
        } else {
            $taxon_hash{$name} = $taxon_oid;
        }
    }

    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $genome_str =~ /gtt_num_id/i );
        

    return \%taxon_hash;
}

sub getGenomeCount {
    my ( $dbh, $genome_str, $percentage, $taxonomy ) = @_;
    
    my $percentClause = getPercentageClause( "dt", $percentage );

    my $phylaClause;
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }
    $phylaClause .= " and t2.domain = ? "   if ( $domain   ne "" );
    $phylaClause .= " and t2.phylum = ? "   if ( $phylum   ne "" );
    $phylaClause .= " and t2.ir_class = ? " if ( $ir_class ne "" );
    $phylaClause .= " and t2.ir_order = ? " if ( $ir_order ne "" );
    $phylaClause .= " and t2.family = ? "   if ( $family   ne "" );
    $phylaClause .= " and t2.genus = ? "    if ( $genus    ne "" );
    $phylaClause .= " and t2.species = ? "  if ( $species  ne "" );

    # select and group by clause
    my $selectClause;
    $selectClause .= " ,$nvl(t2.ir_class, '$unknown') " if ( $phylum ne "" );
    $selectClause .= " ,$nvl(t2.ir_order, '$unknown') "
      if ( $phylum ne "" && $ir_class ne "" );
    $selectClause .= " ,t2.family " if ( $phylum ne "" && $ir_order ne "" );
    $selectClause .= " ,$nvl(t2.genus, '$unknown') "
      if ( $phylum ne "" && $family ne "" );
    $selectClause .= " ,$nvl(t2.species, '$unknown') "
      if ( $phylum ne "" && $family ne "" );

    # check permission
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select count(distinct t2.taxon_oid),  
            t2.domain, t2.phylum $selectClause
        from dt_phylum_dist_genes dt, taxon t2
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            $phylaClause
            $rclause
            $imgClause
        group by t2.domain, t2.phylum $selectClause    
    };

    # print "<p>getGenomeCount: $sql\n";

    # phylum name tab delimited => genome count
    my %hash;

    my $cur;
    if ( $taxonomy ne "" ) {
        my @binds = split( $DELIMITER, $taxonomy );
        $cur = execSql( $dbh, $sql, $verbose, @binds );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    for ( ; ; ) {
        my ( $genome_count, @temp ) = $cur->fetchrow();
        last if ( $genome_count eq "" );
        my $name = join( "\t", @temp );

        $hash{$name} = $genome_count;

    }

    $cur->finish();
    return \%hash;
}

sub getGenomeCount_BodySite {
    my ( $dbh, $genome_str, $percentage ) = @_;
    my $percentClause = getPercentageClause( "dt", $percentage );

    # check permission
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select count(distinct t2.taxon_oid),  
            b.sample_body_site
        from dt_phylum_dist_genes dt, taxon t2, 
            project_info\@imgsg_dev p, 
            project_info_body_sites\@imgsg_dev b
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            and (t2.gold_id = p.gold_stamp_id 
                or t2.taxon_oid = p.img_oid) 
            and p.project_oid = b.project_oid
            $rclause
            $imgClause
        group by b.sample_body_site
    };

    # print "<p>getGenomeCount: $sql\n";

    # phylum name tab delimited => genome count
    my %hash;

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $genome_count, $body_site ) = $cur->fetchrow();
        last if ( $genome_count eq "" );
        my $name = $body_site;

        $hash{$name} = $genome_count;
    }

    $cur->finish();

    # get count of genomes w/o body_site
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    $sql = qq{
        select count(distinct t2.taxon_oid)
        from dt_phylum_dist_genes dt, taxon t2, 
            project_info\@imgsg_dev p
        where $percentClause 
            and dt.taxon_oid in ($genome_str)   
            and dt.homolog_taxon = t2.taxon_oid
            and (t2.gold_id = p.gold_stamp_id or 
                t2.taxon_oid = p.img_oid) 
            and p.project_oid in (
                select p2.project_oid 
                from project_info\@imgsg_dev p2 
                minus 
                select b.project_oid 
                from project_info_body_sites\@imgsg_dev b
            )
            $rclause
            $imgClause
    };
    $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt0) = $cur->fetchrow();
    $cur->finish();

    $hash{"Unknown"} = $cnt0;
    return \%hash;
}

sub getPercentageClause {
    my ( $alias, $percentage ) = @_;
    my $percentClause;
    if ( $percentage eq "30" ) {
        $percentClause = $alias . ".percent_identity >= 30 and " . $alias . ".percent_identity < 60 ";
    } elsif ( $percentage eq "60" ) {
        $percentClause = $alias . ".percent_identity >= 60 and " . $alias . ".percent_identity < 90 ";
    } elsif ( $percentage eq "30p" ) {
        $percentClause = $alias . ".percent_identity >= 30 ";
    } elsif ( $percentage eq "60p" ) {
        $percentClause = $alias . ".percent_identity >= 60 ";
    } else {

        # 90+
        $percentClause = $alias . ".percent_identity >= 90 ";
    }
    return $percentClause;
}

sub getPercentageText {
    my ($percentage) = @_;
    if ( $percentage eq "30" ) {
        return "30%";
    } elsif ( $percentage eq "60" ) {
        return "60%";
    } elsif ( $percentage eq "30p" ) {
        return "30% +";
    } elsif ( $percentage eq "60p" ) {
        return "60% +";
    } else {
        return "90%";
    }
}

# get hit gene counts for each metag
sub getGeneCounts {
    my ( $dbh, $db_genomes_ref, $percentage, $taxonomy, $hideSingleCell ) = @_;

    # phylum name tab delimited => taxon oid => gene count
    my %hash;

    # phylum name tab delimited => taxon oid => homolog gene count
    my %hash_homolog_count;

    if ( scalar(@$db_genomes_ref) <= 0 ) {
        return ( \%hash, \%hash_homolog_count );
    }

    my $genome_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_genomes_ref );

    my $xcopy = param("xcopy");    # gene_count, est_copy
    my $percentClause = getPercentageClause( "dt", $percentage );

    my $phylaClause;
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }
    $phylaClause .= " and t2.domain = ? "   if ( $domain );
    $phylaClause .= " and t2.phylum = ? "   if ( $phylum );
    $phylaClause .= " and t2.ir_class = ? " if ( $ir_class );
    $phylaClause .= " and t2.ir_order = ? " if ( $ir_order );
    $phylaClause .= " and t2.family = ? "   if ( $family );
    $phylaClause .= " and t2.genus = ? "    if ( $genus );
    $phylaClause .= " and t2.species = ? "  if ( $species );

    # select and group by clause
    my $selectClause;
    $selectClause .= " ,$nvl(t2.ir_class, '$unknown') " if ( $phylum );
    $selectClause .= " ,$nvl(t2.ir_order, '$unknown') "
      if ( $phylum && $ir_class );
    $selectClause .= " ,t2.family " if ( $phylum && $ir_order );
    $selectClause .= " ,$nvl(t2.genus, '$unknown') "
      if ( $phylum && $family );
    $selectClause .= " ,$nvl(t2.species, '$unknown') "
      if ( $phylum ne "" && $genus );

    # check permission
    my $rclause          = WebUtil::urClause('t2');
    my $imgClause        = WebUtil::imgClause('t2');
    my $singleCellClause = WebUtil::singleCellClause( 't2', $hideSingleCell );

    my $sql;
    if ( $xcopy eq 'est_copy' ) {
        $sql = qq{
            select dt.taxon_oid, sum(g.est_copy), 
                count(distinct dt.homolog),  
                t2.domain, t2.phylum  $selectClause
            from dt_phylum_dist_genes dt, taxon t2, gene g
            where $percentClause 
                and dt.taxon_oid in ($genome_str)   
                and dt.gene_oid = g.gene_oid
                and dt.homolog_taxon = t2.taxon_oid
                $phylaClause
                $rclause
                $imgClause
                $singleCellClause
            group by t2.domain, t2.phylum $selectClause, dt.taxon_oid   
        };
    } else {
        $sql = qq{
            select dt.taxon_oid, count(dt.gene_oid), 
                count(distinct dt.homolog),  
                t2.domain, t2.phylum  $selectClause
            from dt_phylum_dist_genes dt, taxon t2
            where $percentClause 
                and dt.taxon_oid in ($genome_str)   
                and dt.homolog_taxon = t2.taxon_oid
                $phylaClause
                $rclause
                $imgClause
                $singleCellClause
            group by t2.domain, t2.phylum $selectClause, dt.taxon_oid   
        };
    }

    #print "getGeneCounts() sql: $sql<br/>\n";

    my $cur;
    if ( $taxonomy ne "" ) {
        my @binds = split( $DELIMITER, $taxonomy );
        $cur = execSql( $dbh, $sql, $verbose, @binds );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    for ( ; ; ) {
        my ( $taxon_oid, $gene_count, $homolog_count, @temp ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        my $name = join( "\t", @temp );

        # gene counts
        if ( exists $hash{$name} ) {

            # metag gene count
            my $href = $hash{$name};
            $href->{$taxon_oid} = $gene_count;

            # homolog counts
            my $href = $hash_homolog_count{$name};
            $href->{$taxon_oid} = $homolog_count;

        } else {

            # metag gene count
            my %htmp;
            $htmp{$taxon_oid} = $gene_count;
            $hash{$name}      = \%htmp;

            # homolog counts
            my %htmp;
            $htmp{$taxon_oid}          = $homolog_count;
            $hash_homolog_count{$name} = \%htmp;
        }
    }

    $cur->finish();
    
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $genome_str =~ /gtt_num_id/i );
        
    return ( \%hash, \%hash_homolog_count );
}

###############################################################################
# getGeneCounts_sdb: get MER-FS gene counts (SQLite version)
###############################################################################
sub getGeneCounts_sdb {
    my ( $dbh, $taxon_oid, $data_type, $percentage, $taxonomy ) = @_;
    
    my $xcopy = param("xcopy");    # gene_count, est_copy

    my @perc_list = ();
    if ( isInt($percentage) ) {
        @perc_list = ($percentage);
    } elsif ( $percentage eq '30p' ) {
        @perc_list = ( 30, 60, 90 );
    } elsif ( $percentage eq '60p' ) {
        @perc_list = ( 60, 90 );
    }

    # parse taxonomy
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    if ( $taxonomy ne "" ) {
        ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
          split( $DELIMITER, $taxonomy );
    }

    if ($mer_fs_debug) {
        print "<p>domain: $domain, phylum: $phylum, class: $ir_class, " 
        . "order: $ir_order, family: $family, genus: $genus, species: $species\n";
    }

    # parse display level
    my $display_level = "phylum";
    if ($genus) {
        $display_level = "species";
    } elsif ($family) {
        $display_level = "genus";
    } elsif ($ir_order) {
        $display_level = "family";
    } elsif ($ir_class) {
        $display_level = "order";
    } elsif ($phylum) {
        $display_level = "class";
    }
    if ($mer_fs_debug) {
        print "<p>display level: $display_level\n";
    }

    # prepare sql query using the given taxonomy
    # (usually) it is expected that only one row is returned
    my $nvl       = getNvl();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_oid, t.domain, t.phylum,
               $nvl(t.ir_class, '$unknown'),
               $nvl(t.ir_order, '$unknown'),
               $nvl(t.family, '$unknown'),
               $nvl(t.genus, '$unknown'),
               $nvl(t.species, '$unknown')
        from taxon t
        where t.genome_type = 'isolate'
        $rclause
        $imgClause
    };

    if ($domain) {
        $sql .= " and domain = '$domain'";
    }
    if ($phylum) {
        if ( $phylum =~ /$unknown/ ) {
            $sql .= " and (phylum is null or phylum = '$phylum')";
        } else {
            $sql .= " and phylum = '$phylum'";
        }
    }
    if ($ir_class) {
        if ( $ir_class eq $unknown ) {
            $sql .= " and (ir_class is null or ir_class = '$ir_class')";
        } else {
            $sql .= " and ir_class = '$ir_class'";
        }
    }
    if ($ir_order) {
        if ( $ir_order eq $unknown ) {
            $sql .= " and (ir_order is null or ir_order = '$ir_order')";
        } else {
            $sql .= " and ir_order = '$ir_order'";
        }
    }
    if ($family) {
        if ( $family eq $unknown ) {
            $sql .= " and (family is null or family = '$family')";
        } else {
            $sql .= " and family = '$family'";
        }
    }
    if ($genus) {
        if ( $genus eq $unknown ) {
            $sql .= " and (genus is null or genus = '$genus')";
        } else {
            $sql .= " and genus = '$genus'";
        }
    }

    if ($mer_fs_debug) {
        print "<p>SQL: $sql<br/>\n";
    }

    my $cur = execSql( $dbh, $sql, $verbose );

    # parse returned row
    my %taxon_h;
    for ( ; ; ) {
        my ( $t2, $d2, $p2, $c2, $o2, $f2, $g2, $s2 ) = $cur->fetchrow();
        last if ( !$t2 );

        if ( !$c2 ) {
            $c2 = 'unclassified';
        }
        if ( !$o2 ) {
            $o2 = 'unclassified';
        }
        if ( !$f2 ) {
            $f2 = 'unclassified';
        }
        if ( !$g2 ) {
            $g2 = 'unclassified';
        }
        if ( !$s2 ) {
            $s2 = 'sp.';
        }

        # key is taxon_oid for this specific species,
        # value is phylogeny as a tab delimited string
        $taxon_h{$t2} = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2 . "\t" . $f2 . "\t" . $g2 . "\t" . $s2;
    }

    $cur->finish();

    # check existence of merfs file, assembled and/or unassembled
    $taxon_oid = sanitizeInt($taxon_oid);
    my @type_list = MetaUtil::getDataTypeList( $data_type );

    # (unique) homolog taxon list
    my %taxon_hash;

    # phylum name tab delimited => taxon oid => gene count
    my %hash;

    # phylum name tab delimited => taxon oid => homolog gene count
    my %hash_homolog_count;

    for my $t2 (@type_list) {
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/" . $t2 . ".profile.txt";
        print "<p>processing $taxon_oid $t2 data ...<br/>\n";
        if ( -e $full_dir_name ) {
            my $res = newReadFileHandle( $full_dir_name, "phyloDist" );

            while ( my $line = $res->getline() ) {
                chomp $line;
                my ( $t2_oid, $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 ) = split( /\t/, $line );
                if ( !isInt($t2_oid) ) {    # skip the first line
                    next;
                }
                if ( $taxon_h{$t2_oid} ) {

                    # included
                    my ( $d2, $p2, $c2, $o2, $f2, $g2, $s2 ) =
                      split( /\t/, $taxon_h{$t2_oid} );
                    my $name = $d2 . "\t" . $p2;

                    if ( $display_level eq 'class' ) {
                        if ($c2) {
                            $name = $d2 . "\t" . $p2 . "\t" . $c2;
                        } else {
                            $name = "";
                        }
                    } elsif ( $display_level eq 'order' ) {
                        if ($o2) {
                            if ( $ir_class && $c2 ne $ir_class ) {
                                $name = "";
                            } else {
                                $name = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2;
                            }
                        } else {
                            $name = "";
                        }
                    } elsif ( $display_level eq 'family' ) {
                        if ( $ir_class && $c2 ne $ir_class ) {
                            if ($mer_fs_debug) {
                                print "<p>class: $ir_class, $c2\n";
                            }
                            $name = "";
                        } elsif ( $ir_order && $o2 ne $ir_order ) {
                            if ($mer_fs_debug) {
                                print "<p>order: $ir_order, $o2\n";
                            }
                            $name = "";
                        } else {
                            $name = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2 . "\t" . $f2;
                        }
                    } elsif ( $display_level eq 'genus' ) {
                        if ( $ir_class && $c2 ne $ir_class ) {
                            if ($mer_fs_debug) {
                                print "<p>class: $ir_class, $c2\n";
                            }
                            $name = "";
                        } elsif ( $ir_order && $o2 ne $ir_order ) {
                            if ($mer_fs_debug) {
                                print "<p>order: $ir_order, $o2\n";
                            }
                            $name = "";
                        } elsif ( $family && $f2 ne $family ) {
                            if ($mer_fs_debug) {
                                print "<p>family: $family, $f2\n";
                            }
                            $name = "";
                        } else {
                            $name = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2 . "\t" . $f2 . "\t" . $g2;
                        }
                    } elsif ( $display_level eq 'species' ) {
                        if ( $ir_class && $c2 ne $ir_class ) {
                            if ($mer_fs_debug) {
                                print "<p>class: $ir_class, $c2\n";
                            }
                            $name = "";
                        } elsif ( $ir_order && $o2 ne $ir_order ) {
                            if ($mer_fs_debug) {
                                print "<p>order: $ir_order, $o2\n";
                            }
                            $name = "";
                        } elsif ( $family && $f2 ne $family ) {
                            if ($mer_fs_debug) {
                                print "<p>family: $family, $f2\n";
                            }
                            $name = "";
                        } elsif ( $genus && $g2 ne $genus ) {
                            if ($mer_fs_debug) {
                                print "<p>genus: $genus, $g2\n";
                            }
                            $name = "";
                        } else {
                            $name = $d2 . "\t" . $p2 . "\t" . $c2 . "\t" . $o2 . "\t" . $f2 . "\t" . $g2 . "\t" . $s2;
                        }
                    }

                    if ( !$name ) {
                        next;
                    }

                    my $count = 0;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $percentage eq '30p' ) {
                            $count = $copy30 + $copy60 + $copy90;
                        } elsif ( $percentage eq '60p' ) {
                            $count = $copy60 + $copy90;
                        } elsif ( $percentage eq '30' ) {
                            $count = $copy30;
                        } elsif ( $percentage eq '60' ) {
                            $count = $copy60;
                        } else {
                            $count = $copy90;
                        }
                    } else {
                        if ( $percentage eq '30p' ) {
                            $count = $cnt30 + $cnt60 + $cnt90;
                        } elsif ( $percentage eq '60p' ) {
                            $count = $cnt60 + $cnt90;
                        } elsif ( $percentage eq '30' ) {
                            $count = $cnt30;
                        } elsif ( $percentage eq '60' ) {
                            $count = $cnt60;
                        } else {
                            $count = $cnt90;
                        }
                    }

                    if ( $taxon_hash{$name} ) {
                        $taxon_hash{$name} .= "," . $t2_oid;
                    } else {
                        $taxon_hash{$name} = $t2_oid;
                    }

                    # metag gene count
                    if ( defined $hash{$name} ) {
                        my $href = $hash{$name};
                        $href->{$taxon_oid} += $count;
                    } else {
                        my %htmp;
                        $htmp{$taxon_oid} = $count;
                        $hash{$name}      = \%htmp;
                    }
                }
            }    # end while line
            close $res;
        }

        # get homolog gene counts
        print "<p>computing homolog gene counts ...<br/>\n";
        my %homolog_gene_h;
        for my $p2 (@perc_list) {
            my $sdb_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/" . $t2 . "." . sanitizeInt($p2) . ".sdb";

            if ( !( -e $sdb_name ) ) {
                next;
            }

            my $dbh2 = WebUtil::sdbLogin($sdb_name)
              or next;

            for my $key ( keys %taxon_hash ) {
                print "checking $key ...\n";

                my @taxon_list = split( /\,/, $taxon_hash{$key} );
                my $sql2 = getPhyloDistHomologSql( @taxon_list );
                my $sth  = $dbh2->prepare($sql2);
                $sth->execute();
                for ( ; ; ) {
                    my ($gene2) = $sth->fetchrow_array();
                    last if !$gene2;

                    if ( defined $homolog_gene_h{$key} ) {
                        my $href2 = $homolog_gene_h{$key};
                        $href2->{$gene2} = 1;
                    } else {
                        my %htmp2;
                        $htmp2{$gene2}        = 1;
                        $homolog_gene_h{$key} = \%htmp2;
                    }
                }
                $sth->finish();
                
                print "<br/>\n";
            }

            $dbh2->disconnect();
        }

        for my $key ( keys %homolog_gene_h ) {

            # homolog counts
            my $href3 = $homolog_gene_h{$key};
            my $cnt3  = scalar( keys %$href3 );

            if ( defined $hash_homolog_count{$key} ) {
                my $href2 = $hash_homolog_count{$key};
                $href2->{$taxon_oid} += $cnt3;
            } else {
                my %htmp2;
                $htmp2{$taxon_oid}        = $cnt3;
                $hash_homolog_count{$key} = \%htmp2;
            }
        }
    }

    print "<p>\n";
    return ( \%hash, \%hash_homolog_count, \%taxon_hash );
}

sub getPhyloDistHomologSql {
    my ( @taxon_list ) = @_;

    my $taxons_str = join( ",", @taxon_list );
    my $sql2 = qq{
        select homolog
        from phylo_dist
        where homo_taxon in ( $taxons_str )
    };
    return $sql2;
}


#### body site
# get hit gene counts for each metag
sub getGeneCounts_BodySite {
    my ( $dbh, $db_genomes_ref, $percentage, $hideSingleCell ) = @_;

    # body_site tab delimited => taxon oid => gene count
    my %hash;

    # body_site tab delimited => taxon oid => homolog gene count
    my %hash_homolog_count;

    if ( scalar($db_genomes_ref) <= 0 ) {
        return ( \%hash, \%hash_homolog_count );
    }

    my $genome_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_genomes_ref );

    my $percentClause = getPercentageClause( "dt", $percentage );

    my $phylaClause;
    my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    # check permission
    my $rclause          = WebUtil::urClause('t2');
    my $imgClause        = WebUtil::imgClause('t2');
    my $singleCellClause = WebUtil::singleCellClause( 't2', $hideSingleCell );
    my $sql              = qq{
        select dt.taxon_oid, count(dt.gene_oid), 
               count(distinct dt.homolog), b.sample_body_site
        from dt_phylum_dist_genes dt, taxon t2, 
             project_info\@imgsg_dev p, 
             project_info_body_sites\@imgsg_dev b
        where $percentClause 
        and dt.taxon_oid in ($genome_str)   
        and dt.homolog_taxon = t2.taxon_oid
        and (t2.gold_id = p.gold_stamp_id or t2.taxon_oid = p.img_oid) 
        and p.project_oid = b.project_oid
        $rclause
        $imgClause
        $singleCellClause
        group by b.sample_body_site,dt.taxon_oid   
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $gene_count, $homolog_count, $body_site ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        my $name = $body_site;

        # gene counts
        if ( exists $hash{$name} ) {

            # metag gene count
            my $href = $hash{$name};
            $href->{$taxon_oid} = $gene_count;

            # homolog counts
            my $href = $hash_homolog_count{$name};
            $href->{$taxon_oid} = $homolog_count;

        } else {

            # metag gene count
            my %htmp;
            $htmp{$taxon_oid} = $gene_count;
            $hash{$name}      = \%htmp;

            # homolog counts
            my %htmp;
            $htmp{$taxon_oid}          = $homolog_count;
            $hash_homolog_count{$name} = \%htmp;
        }
    }

    $cur->finish();

    # get count for taxons w/o body site
    $sql = qq{
        select dt.taxon_oid, count(dt.gene_oid), count(distinct dt.homolog)
        from dt_phylum_dist_genes dt, taxon t2, 
             project_info\@imgsg_dev p
        where $percentClause 
        and dt.taxon_oid in ($genome_str)   
        and dt.homolog_taxon = t2.taxon_oid
        and (t2.gold_id = p.gold_stamp_id or t2.taxon_oid = p.img_oid) 
        and p.project_oid in (
            select p2.project_oid 
            from project_info\@imgsg_dev p2 
            minus 
            select b.project_oid 
            from project_info_body_sites\@imgsg_dev b
        )
        $rclause
        $imgClause
        $singleCellClause
        group by dt.taxon_oid   
    };
    $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $gene_count, $homolog_count ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        my $name = "Unknown";

        # gene counts
        if ( exists $hash{$name} ) {

            # metag gene count
            my $href = $hash{$name};
            $href->{$taxon_oid} = $gene_count;

            # homolog counts
            my $href = $hash_homolog_count{$name};
            $href->{$taxon_oid} = $homolog_count;

        } else {

            # metag gene count
            my %htmp;
            $htmp{$taxon_oid} = $gene_count;
            $hash{$name}      = \%htmp;

            # homolog counts
            my %htmp;
            $htmp{$taxon_oid}          = $homolog_count;
            $hash_homolog_count{$name} = \%htmp;
        }
    }

    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $genome_str =~ /gtt_num_id/i );
        
    return ( \%hash, \%hash_homolog_count );
}

#ToDo: need more work
sub getGeneCounts_sdb_BodySite {
    my ( $dbh, $taxon_oid, $data_type, $percentage ) = @_;

    my @perc_list = ();
    if ( isInt($percentage) ) {
        @perc_list = ($percentage);
    } elsif ( $percentage eq '30p' ) {
        @perc_list = ( 30, 60, 90 );
    } elsif ( $percentage eq '60p' ) {
        @perc_list = ( 60, 90 );
    }

    if ($mer_fs_debug) {
        print "<p>display level: Body Site\n";
    }

    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql       = qq{
        select t2.taxon_oid, b.sample_body_site
        from taxon t2, project_info\@imgsg_dev p, 
             project_info_body_sites\@imgsg_dev b
        where (t2.gold_id = p.gold_stamp_id or t2.taxon_oid = p.img_oid)
        and p.project_oid = b.project_oid
        and b.sample_body_site is not null
        $rclause
        $imgClause
        order by 1, 2
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %taxon_bodysite;
    my %bodysite_h;
    for ( ; ; ) {
        my ( $taxon_oid, $body_site ) = $cur->fetchrow();
        last if ( !$taxon_oid );

        if ( $taxon_bodysite{$taxon_oid} ) {
            my $href = $taxon_bodysite{$taxon_oid};
            $href->{$body_site} = 1;
        } else {
            my %htmp;
            $htmp{$body_site}           = 1;
            $taxon_bodysite{$taxon_oid} = \%htmp;
        }

        $bodysite_h{$body_site} = 1;
    }
    $cur->finish();

    # (unique) homolog taxon list
    my %taxon_hash;

    # body site tab delimited => taxon oid => gene count
    my %hash;

    # body site name tab delimited => taxon oid => homolog gene count
    my %hash_homolog_count;

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = MetaUtil::getDataTypeList( $data_type );

    for my $t2 (@type_list) {
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/" . $t2 . ".profile.txt";
        print "<p>processing $taxon_oid $t2 data ...<br/>\n";
        if ( -e $full_dir_name ) {
            my $res = newReadFileHandle( $full_dir_name, "phyloDist" );

            while ( my $line = $res->getline() ) {
                chomp $line;
                my ( $t2_oid, $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 ) = split( /\t/, $line );
                if ( !isInt($t2_oid) ) {    # skip the first line
                    next;
                }


                my @body_sites = ();
                if ( $taxon_bodysite{$t2_oid} ) {

                    my $count = 0;
                    if ( $percentage eq '30p' ) {
                        $count = $cnt30 + $cnt60 + $cnt90;
                    } elsif ( $percentage eq '60p' ) {
                        $count = $cnt60 + $cnt90;
                    } elsif ( $percentage eq '30' ) {
                        $count = $cnt30;
                    } elsif ( $percentage eq '60' ) {
                        $count = $cnt60;
                    } else {
                        $count = $cnt90;
                    }

                    # with body site
                    my $href2 = $taxon_bodysite{$t2_oid};
                    for my $name ( keys %bodysite_h ) {
                        if ( $href2->{$name} ) {
                            push @body_sites, ($name);
                        }
                    }

                } else {
                    @body_sites = ('Unknown');
                }

                my $h_cnt = 1;
                for my $name (@body_sites) {
                    if ( exists $hash{$name} ) {

                        # metag gene count
                        my $href = $hash{$name};
                        $href->{$taxon_oid} += 1;

                        # homolog counts
                        my $href = $hash_homolog_count{$name};
                        $href->{$taxon_oid} += $h_cnt;
                    } else {

                        # metag gene count
                        my %htmp;
                        $htmp{$taxon_oid} = 1;
                        $hash{$name}      = \%htmp;

                        # homolog counts
                        if ($h_cnt) {
                            my %htmp;
                            $htmp{$taxon_oid}          = $h_cnt;
                            $hash_homolog_count{$name} = \%htmp;
                        }
                    }

                    if ( $taxon_hash{$name} ) {
                        $taxon_hash{$name} .= "," . $t2_oid;
                    } else {
                        $taxon_hash{$name} = $t2_oid;
                    }
                }    # end for my name
                                    
            }    
            close $res;
        }

        # get homolog gene counts
        print "<p>computing homolog gene counts ...<br/>\n";
        my %homolog_gene_h;
        for my $p2 (@perc_list) {
            my $sdb_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/" . $t2 . "." . sanitizeInt($p2) . ".sdb";

            if ( !( -e $sdb_name ) ) {
                next;
            }

            my $dbh2 = WebUtil::sdbLogin($sdb_name)
              or next;

            for my $key ( keys %taxon_hash ) {
                print "checking $key ...\n";

                my @taxon_list = split( /\,/, $taxon_hash{$key} );
                my $sql2 = getPhyloDistHomologSql( @taxon_list );
                my $sth  = $dbh2->prepare($sql2);
                $sth->execute();
                for ( ; ; ) {
                    my ($gene2) = $sth->fetchrow_array();
                    last if !$gene2;

                    if ( defined $homolog_gene_h{$key} ) {
                        my $href2 = $homolog_gene_h{$key};
                        $href2->{$gene2} = 1;
                    } else {
                        my %htmp2;
                        $htmp2{$gene2}        = 1;
                        $homolog_gene_h{$key} = \%htmp2;
                    }
                }
                $sth->finish();

                print "<br/>\n";
            }

            $dbh2->disconnect();
        }

        for my $key ( keys %homolog_gene_h ) {

            # homolog counts
            my $href3 = $homolog_gene_h{$key};
            my $cnt3  = scalar( keys %$href3 );

            if ( defined $hash_homolog_count{$key} ) {
                my $href2 = $hash_homolog_count{$key};
                $href2->{$taxon_oid} += $cnt3;
            } else {
                my %htmp2;
                $htmp2{$taxon_oid}        = $cnt3;
                $hash_homolog_count{$key} = \%htmp2;
            }
        }
    }

    return ( \%hash, \%hash_homolog_count, \%taxon_hash );
}


############################################################################
# printMainJS - Prints required JavaScript for the form
############################################################################
sub printMainJS {
    print <<EOF;
    <script type="text/javascript">
    function countSelections(maxFind) {
        var els = document.getElementsByTagName('input');

        var count = 0;
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            var name = e.name;

            if (e.type == "radio" && e.checked == true
                && e.value == "find" && name.indexOf("profile") > -1) {
                count++;
                if (count > maxFind) {
                   alert("Please select no more than " + maxFind + " genomes");
                   return false;
                }
            }
        }
        if (count < 1) {
           alert("Please select at least one genome");
           return false;
        }

        return true;
    }
    </script>
EOF
}


sub getGenomeGeneCount {
    my ( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type ) = @_;

    # taxon oid => gene count
    my %hash;

    if ( $merfs_taxons_ref && scalar(@$merfs_taxons_ref) > 0 ) {
        ## only count CDS genes
        my $stats_keyword = "Protein coding genes";
        foreach my $taxon_oid ( @$merfs_taxons_ref ) {
            my $totalGeneCount = 
               MetaUtil::getGenomeStats( $taxon_oid, $data_type, $stats_keyword );        
            $hash{$taxon_oid} = $totalGeneCount;
        }        
    }
    
    if ( $db_taxons_ref && scalar(@$db_taxons_ref) > 0 ) {
        my $genome_str = join( ",", @$db_taxons_ref ); 
        #TODO:
        #should we apply cds_genes in taxon_stats and g.locus_type = 'CDS'?
        my $sql = qq{
            select taxon_oid, total_gene_count
            from taxon_stats
            where taxon_oid in ($genome_str)
        };    
        my $cur = execSql( $dbh, $sql, $verbose );    
        for ( ; ; ) {
            my ( $taxon_oid, $totalGeneCount ) = $cur->fetchrow();
            last if ( !$taxon_oid );
            $hash{$taxon_oid} = $totalGeneCount;
        }    
        $cur->finish();        
    }

    return \%hash;
}

sub getGenomeEstCopyCount {
    my ( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type, $total_gene_count_href ) = @_;

    # taxon oid => est copy count
    my %hash;

    if ( $merfs_taxons_ref && scalar(@$merfs_taxons_ref) > 0 ) {
        foreach my $taxon_oid ( @$merfs_taxons_ref ) {
            my $totalCopyCount = MetaUtil::getPhyloDistEstCopyCount( '', $taxon_oid, $data_type );
            my $totalGeneCount = $total_gene_count_href->{$taxon_oid};
            if ( $totalCopyCount < $totalGeneCount ) {
                $totalCopyCount = $totalGeneCount;
            }
            $hash{$taxon_oid} = $totalCopyCount;
        }        
    }
    
    if ( $db_taxons_ref && scalar(@$db_taxons_ref) > 0 ) {
        my $genome_str = join( ",", @$db_taxons_ref );    
        my $sql = qq{
            select g.taxon, sum(g.est_copy)
            from gene g
            where g.taxon in ($genome_str)
            group by g.taxon
        };    
        my $cur = execSql( $dbh, $sql, $verbose );    
        for ( ; ; ) {
            my ( $taxon_oid, $totalCopyCount ) = $cur->fetchrow();
            last if ( !$taxon_oid );
            my $totalGeneCount = $total_gene_count_href->{$taxon_oid};
            if ( $totalCopyCount < $totalGeneCount ) {
                $totalCopyCount = $totalGeneCount;
            }
            $hash{$taxon_oid} = $totalCopyCount;
        }    
        $cur->finish();        
    }

    return \%hash;
}


# new form
sub printForm3 {
    my($numTaxon) = @_;
    print qq{
        <h1>Phylogenetic Distribution of Metagenomes</h1>
        <p>
        View the phylogenetic distribution of genes for selected metagenomes.
        </p>
    };


    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printMainForm();
    print "<p>\n";
    print qq{
        <b>Display Options </b><br/><br/>
        Percent Identity: &nbsp; <select name="percentage" >
        <option selected="selected" value="30" title="Hits between 30% to 59%"> 30% to 59% </option>
        <option value="60"  title="Hits between 60% to 89%"> 60% to 89% </option>
        <option value="90"  title="Any hits above 90%"> 90+ </option>
        <option value="30p"  title="Any hits above 30%"> 30+ </option>
        <option value="60p"  title="Any hits above 60%"> 60+ </option>
        </select>
        <br/>
    };

    print qq{
        <br/>
        <input type='radio' name='xcopy' value='gene_count' checked='checked' />
        Gene count
        <br/>
        <input type='radio' name='xcopy' value='est_copy' /> 
        Estimated gene copies
        <br/>
    };

    print qq{
        <br/>
        <input type='checkbox' name='show_percentage' checked='checked' />
        &nbsp; Show percentage column
        <br/>
        <input type='checkbox' name='show_hist' />
        &nbsp; Show histogram column
        <br/>
    };

    HtmlUtil::printMetaDataTypeChoice();
    print "</p>\n";

    GenomeListJSON::printHiddenInputType($section, 'process');
    my $xml_cgi = $cgi_url . '/xml.cgi';
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $template = HTML::Template->new
	( filename => "$base_dir/genomeJson.html" );
    $template->param( isolate             => 0 );
    $template->param( include_metagenomes => $include_metagenomes );
    $template->param( gfr                 => 0 );
    $template->param( pla                 => 0 );
    $template->param( vir                 => 0 );
    $template->param( all                 => 0 );
    $template->param( cart                => 1 );
    $template->param( xml_cgi             => $xml_cgi );

    # TODO - for some forms show only metagenome or show only islates
    $template->param( from => $section );

    # prefix
    $template->param( prefix => '' );
    print $template->output;

    ### for hmp_test
    if ($hmp_test) {
        print "<p><font color='red'>(Note: 'Body Site' is a prototyping feature.)</font>\n";
        print "<p>Category Type: ";
        print nbsp(2);
        print "<input type='radio' name='cat_type', value='phylo' checked>Phylogeny\n";
        print nbsp(1);
        print "<input type='radio' name='cat_type', value='body_site'>Body Site\n";
        print "<p>\n";
    }    
    
    GenomeListJSON::printMySubmitButton
	( "", '', "Go", '', $section, 'process', 'meddefbutton' );    

    GenomeListJSON::showGenomeCart($numTaxon);
    print end_form();
    printStatusLine( "Loaded.", 2 );
}


###############################################################################
# printBodySiteResults
###############################################################################
sub printBodySiteResults {
    my $percentage         = param("percentage");    # 30, 60, 90
    my $xcopy              = param("xcopy");         # gene_count, est_copy
    my $gene_count_file    = param("gene_count_file");
    my $homolog_count_file = param("homolog_count_file");
    my $genome_count_file  = param("genome_count_file");
    my $show_percentage    = param("show_percentage");
    my $show_hist          = param("show_hist");
    my $data_type          = param("data_type");     # assembled or unassembled or both

    my @filters = param("filter");                   # filter on selected phyla
    my %filters_hash;                                # list of phyla to show
    foreach my $x (@filters) {
        $filters_hash{$x} = $x;
    }

    my @genomeFilterSelections = param('genomeFilterSelections');
    my $find_toi_ref = \@genomeFilterSelections;
    if ( $#$find_toi_ref < 0 ) {
        # filter does not have taxon oids
        my @taxon_oids = param("taxon_oid");
        $find_toi_ref = \@taxon_oids;
    }
    my $taxon_oids_str = join( ",", @$find_toi_ref );
    if ( $#$find_toi_ref < 0 ) {
        webError("Please select at least 1 genome.<br/>\n");
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1> Metagenome Distribution (Body Site)</h1>\n";
    my ($text, $xcopyText) = printParamHeader( $percentage, $xcopy, $data_type);

    my $dbh = dbLogin();

    my ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
        $merfs_taxons_ref, $db_taxons_ref );
    if (scalar @$find_toi_ref > 5) {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
           PhyloUtil::printCollapsableHeader
           ($dbh, $find_toi_ref, $data_type, 1);
    } else {
        ($taxon_name_href, $phylo_fs_taxons_ref, $phylo_db_taxons_ref,
         $merfs_taxons_ref, $db_taxons_ref ) =
           PhyloUtil::printGenomeListSubHeader
           ($dbh, $find_toi_ref, $data_type, 1);
    }

    if ( !$mer_fs_debug ) {
        printStartWorkingDiv();
    }

    print "<p>computing genome gene count ...\n";
    my $total_gene_count_href = getGenomeGeneCount( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type );

    my $total_est_copy_count_href;
    if ( $xcopy eq 'est_copy' ) {
        print "<p>Computing genome est copy count ...\n";
        $total_est_copy_count_href = getGenomeEstCopyCount( $dbh, $merfs_taxons_ref, $db_taxons_ref, $data_type, $total_gene_count_href );        
    }

    my $gene_count_href;
    my $homolog_count_href;
    my $genome_count_href;

    my $taxon_list_href;

    if ( $gene_count_file eq "" ) {
        if ( scalar(@$phylo_db_taxons_ref) ) {
            print "<p>computing gene counts for @$phylo_db_taxons_ref ...\n";
        }

        ( $gene_count_href, $homolog_count_href ) = getGeneCounts_BodySite( $dbh, $phylo_db_taxons_ref, $percentage, 1 );

        if ( scalar(@$phylo_fs_taxons_ref) > 0 ) {
            print "<p>This computation takes longer because metagenomes with phylogenetic files are selected.\n";
            for my $t_id (@$phylo_fs_taxons_ref) {
                print "<p>computing gene counts for $t_id ...\n";
    
                my ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 );
                
                $t_id = sanitizeInt($t_id);
                my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($t_id);
                if ( -e $phylo_dir_name ) {
                    ( $gene_count_href2, $homolog_count_href2, $taxon_list_href2 ) =
                      getGeneCounts_sdb_BodySite( $dbh, $t_id, $data_type, $percentage );
                }
    
                for my $k ( keys %$gene_count_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $gene_count_href2->{$k}->{$t_id} ) {
                        $gene_count_href->{$new_k}->{$t_id} = $gene_count_href2->{$k}->{$t_id};
                    }
                }
    
                for my $k ( keys %$homolog_count_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $homolog_count_href2->{$k}->{$t_id} ) {
                        $homolog_count_href->{$new_k}->{$t_id} = $homolog_count_href2->{$k}->{$t_id};
                    }
                }
    
                for my $k ( keys %$taxon_list_href2 ) {
                    my $new_k = $k;
                    if ( $new_k =~ /Viruses/ ) {
                        $new_k =~ s/\_no/\, no/;
                    }
                    $new_k =~ s/\_/ /g;
    
                    if ( $taxon_list_href->{$k} ) {
                        $taxon_list_href->{$new_k} .= "," . $taxon_list_href2->{$k};
                    } else {
                        $taxon_list_href->{$new_k} = $taxon_list_href2->{$k};
                    }
                }
            }
        }

        # get distinct genome counts for all homologs
        if ( scalar(@$phylo_fs_taxons_ref) == 0 ) {

            # only db taxons
            $genome_count_href = getGenomeCount_BodySite( $dbh, $taxon_oids_str, $percentage );
        } else {
            if ( scalar(@$phylo_db_taxons_ref) ) {
                my $taxon_list_href3 = getGenomeNameList( $dbh, $phylo_db_taxons_ref, $percentage );

                for my $k ( keys %$taxon_list_href3 ) {
                    if ( $taxon_list_href->{$k} ) {
                        $taxon_list_href->{$k} .= "," . $taxon_list_href3->{$k};
                    } else {
                        $taxon_list_href->{$k} = $taxon_list_href3->{$k};
                    }
                }
            }

            # count distinct taxons
            for my $k ( keys %$taxon_list_href ) {
                my @taxons = split( /\,/, $taxon_list_href->{$k} );
                my %count_hash;
                undef %count_hash;
                for my $t2 (@taxons) {
                    $count_hash{$t2} = 1;
                }
                $genome_count_href->{$k} = scalar( keys %count_hash );
            }
        }

        $gene_count_file    = cacheHashHash( $gene_count_href,    "gene" );
        $homolog_count_file = cacheHashHash( $homolog_count_href, "homolog" );
        $genome_count_file  = cacheHash( $genome_count_href,      "genome" );

    } else {

        # read cache file
        $gene_count_href    = readHashHash($gene_count_file);
        $homolog_count_href = readHashHash($homolog_count_file);
        $genome_count_href  = readHash($genome_count_file);
    }

    if ( !$mer_fs_debug ) {
        printEndWorkingDiv();
    }

    printJS();
    print hiddenVar( "section",            $section );
    print hiddenVar( "page",               "phyla" );
    print hiddenVar( "taxon_oids",         $taxon_oids_str );
    print hiddenVar( "percentage",         $percentage );
    print hiddenVar( "xcopy",              $xcopy );
    print hiddenVar( "taxonomy",           "" );
    print hiddenVar( "metag_oid",          "" );
    print hiddenVar( "data_type",          $data_type );
    print hiddenVar( "gene_count_file",    $gene_count_file );
    print hiddenVar( "homolog_count_file", $homolog_count_file );
    print hiddenVar( "genome_count_file",  $genome_count_file );
    print hiddenVar( "show_percentage",    $show_percentage );
    print hiddenVar( "show_hist",          $show_hist );

    foreach my $x (@$find_toi_ref) {

        # for filter
        print hiddenVar( "taxon_oid", $x );
    }

    print qq{
        <br/>
        <input class='smdefbutton' type='button' value='View Selected'
        onClick="javascript:mySubmit3('process')" />
        &nbsp;
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
        <br/>
    };

    # x-axis labels
    my @chartcategories;

    # data poits, array of arrays
    # array 1 = 1st genome list of percentages
    my @chartdata;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my @tmp = ();
        push( @chartdata, \@tmp );
    }

    my $rowcnt = printTable_BodySite(
	$find_toi_ref, $taxon_name_href, $gene_count_href, $genome_count_href,
	$homolog_count_href, 1, \%filters_hash,   
	$total_gene_count_href, $total_est_copy_count_href,
	\@chartcategories,   \@chartdata
    );

    #    print qq{
    #        <br/>
    #        <input class='smdefbutton' type='button' value='View Selected'
    #        onClick="javascript:mySubmit3('process')" />
    #        &nbsp;
    #        <input class='smbutton' type='button' value='Select All'
    #        onClick="javascript:selectAllCheckBoxes(1)" />
    #        &nbsp;
    #        <input class='smbutton' type='button' value='Clear All'
    #        onClick="javascript:selectAllCheckBoxes(0)" />
    #        <br/>
    #    };

    print end_form();

    #$dbh->disconnect();

    return;

    # PREPARE THE BAR CHART
    # width should depend on the number of catergories and number of genomes
    my $min_width   = 300;
    my $num_genomes = $#$find_toi_ref + 1;
    my $size        = $#chartcategories + 1;
    $size      = ceil( $size / 10 );
    $min_width = $min_width * $size * $num_genomes;
    my $url   = "";
    my $chart = newBarChart();
    $chart->WIDTH($min_width); # 4096 for 75 catergories and 2 genomes
    $chart->HEIGHT(800);
    $chart->DOMAIN_AXIS_LABEL("Phylum");       # x-axis
    $chart->RANGE_AXIS_LABEL("Percentage");    # y-axis
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->ITEM_URL( $url . "&chart=y" );
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");

    # number of genomes - grouping of bars for each category
    my @chartseries;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my $oid = $find_toi_ref->[$i];
        push( @chartseries, "$oid" );
    }

    # display the bar chart
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );

    # now set data as array for strings delimited by commas
    # array 1 = .01,12,...
    # array 2 = .2,.23,...
    my @datas;
    for ( my $i = 0 ; $i <= $#$find_toi_ref ; $i++ ) {
        my $aref = $chartdata[$i];
        my $datastr = join( ",", @$aref );
        push( @datas, $datastr );
    }
    $chart->DATA( \@datas );

    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        my $htmlpage;    # html page
        if ( $st == 0 ) {
            $htmlpage = "<script src='$base_url/overlib.js'></script>\n";

            webLog( $chart->FILEPATH_PREFIX . ".html\n" );

            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "metachart", 1 );
            while ( my $s = $FH->getline() ) {
                $htmlpage .= $s;
            }
            close($FH);
            $htmlpage .= "<img src='$tmp_url/"
		       . $chart->FILE_PREFIX . ".png' BORDER=0 ";
            $htmlpage .= " width=" . $chart->WIDTH 
		       . " HEIGHT=" . $chart->HEIGHT;
            $htmlpage .= " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
        my $sid  = getSessionId();
        my $file = "chart$$" . "_" . $sid . ".html";
        my $path = "$tmp_dir/$file";
        my $FH   = newWriteFileHandle($path);
        print $FH $htmlpage;
        close $FH;

        print qq{
        <p>
        <input class='smbutton' type='button' value='Bar Chart'
               onClick="javascript:window.open('$tmp_url/$file','popup',
               'width=800,height=800,scrollbars=yes,status=no,resizable=yes, toolbar=no'); 
        window.focus();" 
        /> &nbsp; will be in a new new pop-up window or tab.
        </p>
        };
    }
    printStatusLine( "$rowcnt Loaded.", 2 );
}

##############################################################################
# printTable_BodySite
##############################################################################
sub printTable_BodySite {
    my (
         $find_toi_ref, $taxon_name_href, $gene_count_href, $genome_count_href,
         $homolog_count_href, $selectCol, $filters_href,    
         $total_gene_count_href,$total_est_copy_count_href,
         $chartcategories_aref, $chartdata_aref
      )
      = @_;

    my $data_type = param("data_type");  # assembled or unassembled or both
    my $xcopy    = param("xcopy");       # gene_count, est_copy

    my $show_percentage = param("show_percentage");
    my $show_hist       = param("show_hist");
    $selectCol = 0;

    my $sortCol = 0;
    if ($selectCol) {
        $sortCol = 1;
    }

    ## get MER-FS taxons
    my %mer_fs_taxons;
    if ($in_file) {
        my $dbh = dbLogin();
        %mer_fs_taxons = MerFsUtil::getTaxonsInFile($dbh);

        #$dbh->disconnect();
    }

    #    foreach my $name ( sort keys %$gene_count_href ) {
    #        my $r;

    # ($domain, $phylum, $ir_class, $ir_order, $family, $genus, $species )
    #        my (@tmp) = split( /\t/, $name );
    #	print "<p>$name (" . scalar(@tmp) . ")\n";
    #    }

    # get total counts for percentage
    my %total_counts;
    if ( $xcopy eq 'est_copy' ) {
        %total_counts = %$total_est_copy_count_href;
    }
    else {
        %total_counts = %$total_gene_count_href;
    }

    printHint("Hit gene count is in brackets ( ).");
    print "<br/>";

    # export file
    my $id         = getSessionId();
    my $exportFile = "export" . $id . ".txt";
    my $exportPath = "$tmp_dir/$exportFile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # table header
    my $it = new InnerTable( 0, "metagphylodist$$", "metagphylodist", $sortCol );
    my $sd = $it->getSdDelim();
    if ($selectCol) {
        $it->addColSpec("Select");
    }
    $it->addColSpec( "Body Site", "asc", "left" );
    print $res "Body Site\t";
    $it->addColSpec( "Genome Count", "desc", "right", "", "Isolate genome count", "wrap" );
    print $res "Genome Count\t";

    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    foreach my $id ( sort @$find_toi_ref ) {
        my $name = $taxon_name_href->{$id};

        my $abbr_name = WebUtil::abbrColName( $id, $name, 1 );
        if ( $mer_fs_taxons{$id} ) {
            $abbr_name .= "<br/>(MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $abbr_name .= "<br/>($data_type)";
            }
        }
        $it->addColSpec( "$abbr_name<br/>$xcopyText",
                         "desc", "right", "", "$name - Metagenome $xcopyText (homolog gene count)" );
        print $res "$name - Metagenome $xcopyText (homolog gene count)\t";

        # percentage col
        # column name must be unique for yui tables
        if ( $show_percentage ne "" ) {
            my $pcToolTip = PhyloUtil::getPcToolTip( $name, $xcopy, $total_counts{$id} );
            $it->addColSpec( "$abbr_name <br/> &#37; ",
                             "desc", "right", "", $pcToolTip );

            print $res "Percentage\t";
        }

        # histogram
        if ( $show_hist ne "" ) {
            $it->addColSpec("$abbr_name <br/> Histogram");
        }

    }
    print $res "\n";

    # end of column headers

    # start of data rows
    my $rowcnt = 0;
    foreach my $name ( sort keys %$gene_count_href ) {
        if ( !$name ) {
            next;
        }

        my $r;

        my (@tmp) = split( /\t/, $name );

        # common separator / delimiter
        my $tmp_str = join( $DELIMITER, @tmp );    # for javascript label
        $tmp_str = CGI::escape($tmp_str);

        my $name2 = $name;
        $name2 =~ s/\t/ /g;

        # filter
        if ( $filters_href ne "" ) {
            my $cnt = keys %$filters_href;
            if ( $cnt > 0 && !exists $filters_href->{$name2} ) {
                next;
            }
        }

        if ($selectCol) {
            $r .= $sd . "<input type='checkbox' name='filter' " . "value='$name2' checked />" . "\t";
        }

        # body site
        $r .= $name2 . $sd . $name2 . "\t";
        print $res $name2 . "\t";

        # bar chart x-axis labels
        if ( $chartcategories_aref ne "" ) {
            push( @$chartcategories_aref, $name2 );
        }

        my $genome_cnt = $genome_count_href->{$name};
        my $url        = qq{ <a href="javascript:mySubmit('$tmp_str', 'genome_bodysite')"> $genome_cnt </a>};
        $r .= $genome_cnt . $sd . $url . "\t";

        print $res $genome_cnt . "\t";

        my $thref   = $gene_count_href->{$name};
        my $hl_href = $homolog_count_href->{$name};
        my $index   = 0;
        foreach my $toid ( sort @$find_toi_ref ) {
            my $count = $thref->{$toid};
            $count = 0 if ( $count eq "" );

            # homolog gene count
            my $hl_count = $hl_href->{$toid};
            $hl_count = 0 if ( $hl_count eq "" );

            if ( $count == 0 ) {
                $r .= $count . $sd . "$count ($hl_count)" . "\t";
            } else {
                my $url = qq{ <a href="javascript:mySubmitGeneBodySite('$tmp_str', '$toid')"> $count </a>};
                $r .= $count . $sd . "$url ($hl_count)" . "\t";
            }
            print $res "$count ($hl_count)" . "\t";

            # percentage
            my $per = 0;
            $per = $count * 100 / $total_counts{$toid} 
                if ($total_counts{$toid});
            if ( $show_percentage ne "" ) {
                my $per2 = sprintf( "%.2f", $per );
                $r .= $per2 . $sd . "$per2" . "\t";
                print $res "$per\t";
            }

            # histogram
            if ( $show_hist ne "" ) {
                $r .= $sd . histogramBar( $per, 1 ) . "\t";
            }

            # bar chart data - array of array
            if ( $chartdata_aref ne "" ) {
                my $aref = $chartdata_aref->[$index];
                push( @$aref, $per );
                $index++;
            }

        }
        print $res "\n";
        $it->addRow($r);
        $rowcnt++;
    }

    $it->printOuterTable("nopage");
    close $res;

    return $rowcnt;
}

# ----------------------------------------------------------------------------
#
#  HMP - M functions
#
# ----------------------------------------------------------------------------
#
############################################################################
# getPhyloDistHitsMerfs - gets the total count for each homolog for
#                         each of the metagenomes for a given body site
############################################################################
sub getPhyloDistHitsMerfs {
    my ($bodysiteTaxons_href) = @_;
    my @metagenomes = sort keys %$bodysiteTaxons_href;
    my %allCounts;

    my $dbh = dbLogin();
    foreach my $taxon_oid (@metagenomes) {
        my $sql = qq{
            select dt.taxon_oid, dt.homolog_taxon,
                   dt.gene_count_30, dt.gene_count_60, dt.gene_count_90
            from dt_phylo_taxon_stats dt
            where dt.taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $txid, $homo_taxon, $cnt30, $cnt60, $cnt90 ) = $cur->fetchrow();
            last if ( !$txid );
            my $key = $taxon_oid . "\t" . $homo_taxon;
            $allCounts{$key} = $cnt30 + $cnt60 + $cnt90;
        }
    }

    #$dbh->disconnect();
    return \%allCounts;
}

sub getPhyloDistHitsMerfs_unknown {
    my ( $bodysiteTaxons_href, $ignoreHomologTaxons_href ) = @_;
    my @metagenomes = sort keys %$bodysiteTaxons_href;
    my %allCounts;

    my $dbh = dbLogin();
    foreach my $taxon_oid (@metagenomes) {
        my $sql = qq{
            select dt.taxon_oid, dt.homolog_taxon,
                   dt.gene_count_30, dt.gene_count_60, dt.gene_count_90
            from dt_phylo_taxon_stats dt
            where dt.taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $txid, $homo_taxon, $cnt30, $cnt60, $cnt90 ) = $cur->fetchrow();
            last if ( !$txid );
            next if ( exists $ignoreHomologTaxons_href->{$homo_taxon} );
            $allCounts{$taxon_oid} = $allCounts{$taxon_oid} + $cnt30 + $cnt60 + $cnt90;
        }
    }

    #$dbh->disconnect();
    return \%allCounts;
}

sub printAllBodySiteResults_merfs {

    # the 5 body sites
    # Airways, Gastrointestinal tract, Oral, Skin, Urogenital tract
    my $body_site = param('body_site');

    print qq{
        <h1> All $body_site Samples</h1>
        <p>
        Counts - Sample gene counts with best hit to reference genomes.
        </p>        
    };

    printMainForm();

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();
    my $dbh = dbLogin();

    # get ref genome - human
    my $sql = qq{
        select p.gold_stamp_id, b.sample_body_site
        from project_info\@imgsg_dev p, project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null  
    };

    # hash of hash
    # $taxon_oid => hash of body sites
    print "Getting ref genome body site info...<br/>\n";
    my %ref_all_body_sites;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gold_id, $body ) = $cur->fetchrow();
        last if ( !$gold_id );

        my $key = $gold_id;
        if ( exists $ref_all_body_sites{$key} ) {
            my $href = $ref_all_body_sites{$key};
            $href->{$body} = $body;
        } else {
            my %hash = ( $body => $body );
            $ref_all_body_sites{$key} = \%hash;
        }
    }

    # get all subject body site genomes
    #
    # taxon oid => name
    my $subjectTaxons_href = getHmpGenomesViaBodySite( $dbh, $body_site );

    # get all taxon gold ids
    # taxon => gold id
    print "Getting all genome gold ids<br/>\n";
    my %all_gold_ids;
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_oid, t.gold_id
        from taxon t
        where 1=1
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $gold_id ) = $cur->fetchrow();
        last if !$taxon_oid;
        $all_gold_ids{$taxon_oid} = $gold_id;
    }

    print "Getting $body_site distribution... " . "Please wait - this may take some time.<br/>\n";

    my $allCounts_href = getPhyloDistHitsMerfs($subjectTaxons_href);

    # hash of sub genomes => hash ref body site gene count
    my %genomeHits;
    foreach my $key ( keys %$allCounts_href ) {
        my $gene_cnt = $allCounts_href->{$key};
        my ( $taxon_oid, $homolog_taxon ) = split( /\t/, $key );
        my $gold_id = $all_gold_ids{$homolog_taxon};

        if ( exists $genomeHits{$taxon_oid} ) {
            my $hit_gene_count_href = $genomeHits{$taxon_oid};
            my $refBodySite_href    = $ref_all_body_sites{$gold_id};
            if ( $refBodySite_href eq '' ) {
                next;
            } else {
                foreach my $bs ( keys %$refBodySite_href ) {
                    if ( exists $hit_gene_count_href->{$bs} ) {
                        $hit_gene_count_href->{$bs} = $hit_gene_count_href->{$bs} + $gene_cnt;
                    } else {
                        $hit_gene_count_href->{'Other'} = $hit_gene_count_href->{'Other'} + $gene_cnt;
                    }
                }
            }

        } else {
            my %hit_gene_count = (
                                   'Airways'                => 0,
                                   'Gastrointestinal tract' => 0,
                                   'Oral'                   => 0,
                                   'Skin'                   => 0,
                                   'Urogenital tract'       => 0,
                                   'Other'                  => 0,
                                   'Unknown'                => 0
            );
            my $refBodySite_href = $ref_all_body_sites{$gold_id};
            if ( $refBodySite_href eq '' ) {
                next;
            } else {
                foreach my $bs ( keys %$refBodySite_href ) {
                    if ( exists $hit_gene_count{$bs} ) {
                        $hit_gene_count{$bs} = $hit_gene_count{$bs} + $gene_cnt;
                    } else {
                        $hit_gene_count{'Other'} = $hit_gene_count{'Other'} + $gene_cnt;
                    }
                }
            }
            $genomeHits{$taxon_oid} = \%hit_gene_count;
        }
    }

    # get unknown counts - hits to non human
    print "<br/>Getting $body_site distribution to unknown " . "- non human genomes <br/>\n";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_oid, p.gold_stamp_id
        from  taxon t, project_info\@imgsg_dev p, 
              project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null 
        and t.gold_id = p.gold_stamp_id 
    };

    my %notInTaxons;    # homolog taxon that do not have these gold ids
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $goldid ) = $cur->fetchrow();
        last if !$taxon_oid;
        $notInTaxons{$taxon_oid} = $taxon_oid;
    }

    my $unknownCounts_href = getPhyloDistHitsMerfs_unknown( $subjectTaxons_href, \%notInTaxons );

    foreach my $key ( keys %$unknownCounts_href ) {
        my $taxon_oid = $key;
        next if ( !exists $genomeHits{$taxon_oid} );
        my $gene_cnt            = $unknownCounts_href->{$key};
        my $hit_gene_count_href = $genomeHits{$taxon_oid};
        $hit_gene_count_href->{'Unknown'} = $gene_cnt;
    }

    printEndWorkingDiv();

    my $it = new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",               "asc", "Left" );
    $it->addColSpec( "Genome Name",             "asc", "left" );
    $it->addColSpec( "Airway ref.",             "asc", "right" );
    $it->addColSpec( "Gastro ref.",             "asc", "right" );
    $it->addColSpec( "Oral ref.",               "asc", "right" );
    $it->addColSpec( "Skin ref.",               "asc", "right" );
    $it->addColSpec( "Urogenital ref.",         "asc", "right" );
    $it->addColSpec( "Other Body Sites",        "asc", "right" );
    $it->addColSpec( "Other Isolation Sources", "asc", "right" );

    my $rowcnt = 0;
    foreach my $taxon_oid ( keys %genomeHits ) {
        my $genome_name    = $subjectTaxons_href->{$taxon_oid};
        my $bsGeneCnt_href = $genomeHits{$taxon_oid};
        my $aircnt         = $bsGeneCnt_href->{'Airways'};
        my $gascnt         = $bsGeneCnt_href->{'Gastrointestinal tract'};
        my $oracnt         = $bsGeneCnt_href->{'Oral'};
        my $skicnt         = $bsGeneCnt_href->{'Skin'};
        my $urocnt         = $bsGeneCnt_href->{'Urogenital tract'};
        my $othcnt         = $bsGeneCnt_href->{'Other'};
        my $unkcnt         = $bsGeneCnt_href->{'Unknown'};

        my $r;
        $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid'/>\t";

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_oid . $sd . alink( $url, $taxon_oid ) . "\t";
        $r .= $genome_name . $sd . $genome_name . "\t";

        my $url = $section_cgi . '&page=refGenomeList&sTaxonOid=' . $taxon_oid . '&subBodySite=';
        if ( $aircnt > 0 ) {
            $r .= $aircnt . $sd . alink( "$url" . 'Airways', $aircnt ) . "\t";
        } else {
            $r .= $aircnt . $sd . $aircnt . "\t";
        }

        if ( $gascnt > 0 ) {
            $r .= $gascnt . $sd . alink( "$url" . 'Gastrointestinal tract', $gascnt ) . "\t";
        } else {
            $r .= $gascnt . $sd . $gascnt . "\t";
        }

        if ( $oracnt > 0 ) {
            $r .= $oracnt . $sd . alink( "$url" . 'Oral', $oracnt ) . "\t";
        } else {
            $r .= $oracnt . $sd . $oracnt . "\t";
        }

        if ( $skicnt > 0 ) {
            $r .= $skicnt . $sd . alink( "$url" . 'Skin', $skicnt ) . "\t";
        } else {
            $r .= $skicnt . $sd . $skicnt . "\t";
        }

        if ( $urocnt > 0 ) {
            $r .= $urocnt . $sd . alink( "$url" . 'Urogenital tract', $urocnt ) . "\t";
        } else {
            $r .= $urocnt . $sd . $urocnt . "\t";
        }

        if ( $othcnt > 0 ) {
            $r .= $othcnt . $sd . alink( "$url" . 'Other', $othcnt ) . "\t";
        } else {
            $r .= $othcnt . $sd . $othcnt . "\t";
        }

        if ( $unkcnt > 0 ) {
            $r .= $unkcnt . $sd . alink( "$url" . 'Unknown', $unkcnt ) . "\t";
        } else {
            $r .= $unkcnt . $sd . $unkcnt . "\t";
        }
        $it->addRow($r);
        $rowcnt++;
    }

    if ( $rowcnt > 10 ) {
        print submit(
                      -name    => 'setTaxonFilter',
                      -value   => 'Add Selected to Genome Cart',
                      -class   => 'meddefbutton',
                      -onClick => "return isGenomeSelected('allmetagphylodist');"
        );
        print nbsp(1);
        WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('allmetagphylodist');"
    );
    print nbsp(1);
    WebUtil::printButtonFooter();

    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$rowcnt Loaded.", 2 );
}

# For HMP M only
sub printRefGenomeList_merfs {
    my $taxon_oid = param('sTaxonOid');      # body site metagenome
    my $body_site = param('subBodySite');    # ref genomes body site

    my $dbh         = dbLogin();
    my $genome_name = genomeName( $dbh, $taxon_oid );
    my $url         = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, $genome_name );

    my $display_site = $body_site;
    if ( $body_site eq 'Other' ) {
        $display_site = 'Other Body Sites';
    } elsif ( $body_site eq 'Unknown' ) {
        $display_site = 'Other Isolation Sources';
    }

    print qq{
        <h1>Genome List</h1>
        <p style='width: 650px;'>
        $url <br/>
        hits to $display_site Ref. Genomes</h1>
        <br/><br/>[Gene Count = Sample best hit gene count]
        </p>
    };

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    print "Getting body info<br/>\n";

    # TODO what about others and unknown
    # get ref genome - human
    my $sql = qq{
        select t.taxon_oid, p.gold_stamp_id, t.taxon_display_name
        from taxon t, project_info\@imgsg_dev p, 
             project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null  
        and b.sample_body_site = ?
        and t.gold_id = p.gold_stamp_id
    };

    if ( $body_site eq 'Other' ) {
        $sql = qq{
        select t.taxon_oid, p.gold_stamp_id, t.taxon_display_name
        from taxon t, project_info\@imgsg_dev p,
             project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null  
        and b.sample_body_site not in ('Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract')
        and t.gold_id = p.gold_stamp_id
    };
    } elsif ( $body_site eq 'Unknown' ) {
        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');

        $sql = qq{
            select t.taxon_oid,  t.gold_id, t.taxon_display_name
            from taxon t
            where t.genome_type = 'isolate'
            $rclause
            $imgClause
            and t.gold_id not in
              ( select  p.gold_stamp_id
                from taxon t, project_info\@imgsg_dev p, 
                     project_info_body_sites\@imgsg_dev b
                where p.project_oid = b.project_oid
                and p.host_name = 'Homo sapiens'
                and b.sample_body_site is not null  
                and p.gold_stamp_id is not null  
                and b.sample_body_site is not null )
        };
    }

    my %refTaxonOids;
    my $cur;
    if ( $body_site eq 'Other' || $body_site eq 'Unknown' ) {
        $cur = execSql( $dbh, $sql, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $body_site );
    }
    for ( ; ; ) {
        my ( $taxon_oid, $gold_id, $taxon_display_name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $refTaxonOids{$taxon_oid} = $taxon_display_name;
    }

    my $it = new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "asc", "left" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Gene Count",  "asc", "right" );

    my %allCounts;
    my $dbh = dbLogin();
    my $sql = qq{
        select dt.taxon_oid, dt.homolog_taxon,
               dt.gene_count_30, dt.gene_count_60, dt.gene_count_90
        from dt_phylo_taxon_stats dt
        where dt.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $txid, $homo_taxon, $cnt30, $cnt60, $cnt90 ) = $cur->fetchrow();
        last if ( !$txid );
        $allCounts{$homo_taxon} = $allCounts{$homo_taxon} + $cnt30 + $cnt60 + $cnt90;
    }

    #$dbh->disconnect();

    printEndWorkingDiv();

    my $rowcnt = 0;
    foreach my $qtaxon_oid ( keys %allCounts ) {
        my $qname    = $refTaxonOids{$qtaxon_oid};
        my $gene_cnt = $allCounts{$qtaxon_oid};

        my $r;
        $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$qtaxon_oid'/>\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$qtaxon_oid";
        $r .= $qtaxon_oid . $sd . alink( $url, $qtaxon_oid ) . "\t";
        $r .= $qname . $sd . $qname . "\t";

        my $url =
          $section_cgi . '&page=refGenomeGeneList&sTaxonOid=' . $taxon_oid . '&body_site' . $body_site . '&qTaxonOid=';
        $r .= $gene_cnt . $sd . alink( "$url" . $qtaxon_oid, $gene_cnt ) . "\t";

        $it->addRow($r);
        $rowcnt++;
    }

    if ( $rowcnt > 10 ) {
        print submit(
                      -name    => 'setTaxonFilter',
                      -value   => 'Add Selected to Genome Cart',
                      -class   => 'meddefbutton',
                      -onClick => "return isGenomeSelected('allmetagphylodist');"
        );
        print nbsp(1);
        WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('allmetagphylodist');"
    );
    print nbsp(1);
    WebUtil::printButtonFooter();

    print end_form();

    #$dbh->disconnect();
    my $rowcnt = keys %allCounts;
    printStatusLine( "$rowcnt Loaded.", 2 );
}

# For HMP M only
sub printRefGenomeGeneList_merfs {
    my $subject_taxon = param('sTaxonOid');
    my $query_taxon   = param('qTaxonOid');
    my $body_site     = param('body_site');

    WebUtil::unsetEnvPath();
    $subject_taxon = sanitizeInt($subject_taxon);

    my $dbh           = dbLogin();
    my $s_genome_name = genomeName( $dbh, $subject_taxon );
    my $q_genome_name = genomeName( $dbh, $query_taxon );
    my $s_url         = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$subject_taxon";
    my $q_url         = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$query_taxon";
    $s_url = alink( $s_url, $s_genome_name );
    $q_url = alink( $q_url, $q_genome_name );

    print qq{
        <h1>Gene List</h1>
        <p style='width: 650px;'>
        $s_url <br/>
        $body_site hits to $q_url
        </p>
    };

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my %geneList1;
    my %geneList2;
    my %percentIdent;

    foreach my $p2 ( 30, 60, 90 ) {
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $subject_taxon ) . "/assembled." . $p2 . ".sdb";
        if ( -e $full_dir_name ) {
            my $dbh3 = WebUtil::sdbLogin($full_dir_name) or next;
            
            my $sql = MetaUtil::getPhyloDistSingleHomoTaxonSql();
            my $sth  = $dbh3->prepare($sql);
            $sth->execute($query_taxon);
            for ( ; ; ) {
                my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $est_copy ) = $sth->fetchrow_array();
                last if ( !$gene_oid );
                next if ( $homo_taxon ne $query_taxon );
                next if ( $gene_perc eq "" );

                $geneList1{$gene_oid}                     = '';
                $geneList2{$homolog_gene}                 = '';
                $percentIdent{"$gene_oid\t$homolog_gene"} = $gene_perc;
            }

            $sth->finish();
            $dbh3->disconnect();
        }
    }

    # now get gene info
    OracleUtil::insertDataHash( $dbh, "gtt_num_id", \%geneList2 );
    my $sql = qq{
        select gene_oid, gene_display_name, locus_tag
        from gene
        where gene_oid in (select id from gtt_num_id)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $name, $locus_tag ) = $cur->fetchrow();
        last if ( !$gene_oid );
        $geneList2{$gene_oid} = " $name\t$locus_tag";
    }

    #$dbh->disconnect();

    my (%names) = MetaUtil::getGeneProdNamesForTaxon( $subject_taxon, 'assembled' );
    for my $id ( keys %names ) {
        my $name = $names{$id};
        $geneList1{$id} = "$name\t$id";
    }

    printEndWorkingDiv();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->disableSelectButtons();
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );

    $it->addColSpec("Select");
    $it->addColSpec( "Ref. Gene ID",           "asc", "left" );
    $it->addColSpec( "Ref. Locus Tag",         "asc", "left" );
    $it->addColSpec( "Ref. Gene Product Name", "asc", "left" );
    $it->addColSpec( "Percent Identity",       "asc", "right" );

    my $rowcnt = 0;
    foreach my $key ( keys %percentIdent ) {
        my $percent = $percentIdent{$key};
        my ( $qgene_oid, $sgene_oid )  = split( /\t/, $key );
        my ( $qname,     $qlocus_tag ) = split( /\t/, $geneList1{$qgene_oid} );
        my ( $sname,     $slocus_tag ) = split( /\t/, $geneList2{$sgene_oid} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$qgene_oid'  />\t";

        my $url =
            "$main_cgi?section=MetaGeneDetail"
          . "&page=geneDetail&gene_oid=$qgene_oid&taxon_oid=$subject_taxon&data_type=assembled";
        $r .= $qgene_oid . $sd . alink( $url, $qgene_oid ) . "\t";
        $r .= $qlocus_tag . $sd . $qlocus_tag . "\t";
        $r .= $qname . $sd . $qname . "\t";

        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$sgene_oid'  />\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$sgene_oid";
        $r .= $sgene_oid . $sd . alink( $url, $sgene_oid ) . "\t";
        $r .= $slocus_tag . $sd . $slocus_tag . "\t";
        $r .= $sname . $sd . $sname . "\t";
        $r .= $percent . $sd . $percent . "\t";
        $it->addRow($r);
        $rowcnt++;
    }

    printMainForm();
    printGeneCartFooter() if $rowcnt > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    printStatusLine( "$rowcnt rows", 2 );
    print end_form();
}

# For HMP M only
sub printBodySiteVsBodySiteList {
    my $queryBodySite   = param('qbody_site');
    my $subjectBodySite = param('sbody_site');

    my $display_site = $subjectBodySite;
    if ( $subjectBodySite eq 'Other' ) {
        $display_site = 'Other Body Sites';
    } elsif ( $subjectBodySite eq 'Unknown' ) {
        $display_site = 'Other Isolation Sources';
    }

    print qq{
        <h1>
        $queryBodySite Metagenomes vs. $display_site Ref. Genomes
        </h1>
    };

    my $file          = $env->{all_hits_file};
    my $all_hits_file = $env->{webfs_data_dir} . "hmp/$file";
    my $rfh           = newReadFileHandle($all_hits_file);
    my @a_line;
    while ( my $line = $rfh->getline() ) {
        next if $line =~ /^#/;
        @a_line = split( /\t/, $line );

# array index
# 0 - body site
# 1 - metag total gene count
# 2 - metag total hits gene count
# 3,   4,  5,  6,  7,  8 - ref genome total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other' )
# 9,  10, 11, 12, 13, 14 - ref genome hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other' )
# 15, 16, 17, 18, 19, 20 - metag ref body site hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other' )

# array index
# 0 - body site
# 1 - metag total gene count
# 2 - metag total hits gene count
# 3, 4, 5, 6, 7, 8, 9 - ref genome total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )
# 10, 11, 12, 13, 14, 15, 16 - ref genome hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )
# 17, 18, 19, 20, 21, 22, 23 - metag ref body site hit total gene count ( 'Airways', 'Gastrointestinal tract', 'Oral', 'Skin', 'Urogenital tract', 'Other', 'Unknown' )

        last if ( $queryBodySite eq $a_line[0] );
    }
    close $rfh;
    my $offset_index = 7;
    my %body_site_index = (
                            'Airways'                => 3,
                            'Gastrointestinal tract' => 4,
                            'Oral'                   => 5,
                            'Skin'                   => 6,
                            'Urogenital tract'       => 7,
                            'Other'                  => 8,
                            'Unknown'                => 9
    );

    #    print "$a_line[1]<br/>\n";
    #    print "$a_line[2]<br/>\n";
    my $i = $body_site_index{$subjectBodySite};

    #    print "$a_line[$i]<br/>\n";
    #    print $a_line[$i + $offset_index] . "<br/>\n";
    #    print $a_line[$i + 2 * $offset_index] . "<br/>\n";

    my $a1 = $a_line[1];
    my $a2 = $a_line[2];
    my $a3 = $a_line[$i];
    my $a4 = $a_line[ $i + $offset_index ];
    my $a5 = $a_line[ $i + 2 * $offset_index ];

    #print Dumper \@a_line;
    print <<EOF;
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Gene Counts');
        data.addColumn('number', 'Metag');
        data.addColumn('number', 'Metag Hits');
        data.addColumn('number', 'Hits to Ref Genomes');
        
        data.addRows([
          ['Gene Counts', $a1, $a2, $a5]
        ]);

        var options = {
          width: 600, height: 400,
          title: '$queryBodySite Metagenome vs. $display_site Ref. Genomes'
        };

        var chart = new google.visualization.ColumnChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      }
    </script>
    <div id="chart_div"></div>
    
EOF

    print qq{
        <p>
        <input class="smdefbutton" type="button" 
        name="metadata" 
        value="View $queryBodySite Samples" onclick="window.open('main.cgi?section=MetagPhyloDist&page=allBodySiteDistro&body_site=$queryBodySite', '_self')">

        &nbsp;&nbsp;
        <input class="smdefbutton" type="button" 
        name="isolates" 
        value="View $display_site Genomes" onclick="window.open('main.cgi?section=MetagPhyloDist&page=allRefGenomes&qbody_site=$queryBodySite&sbody_site=$subjectBodySite', '_self')">

    };

    print qq{
        <p>
        <table class='img'>
        <th class='img' colspan="3" style="text-align: left;"> Legend </th>
        <tr>
        <td class='img'>Metag</td>
        <td class='img'>$queryBodySite metagenomes total gene count</td>
        <td  class='img' align="right">$a1</td>
        </tr>

        <tr>
        <td class='img'>Metag Hits</td>
        <td class='img'>$queryBodySite metagenomes total gene count with best hit to any reference genomes</td>
        <td class='img' align="right">$a2</td>
        </tr>
    };

    print qq{
        <tr>
        <td class='img'>Hits to Ref Genomes</td>
        <td class='img'>$queryBodySite metagenomes total gene count best hit to $display_site reference genomes</td>
        <td class='img' align="right">$a5</td>
        </tr>
        </table>
    };

    printStatusLine( "Loaded", 2 );
}

sub getHmpGenomesViaBodySite {
    my ( $dbh, $body_site ) = @_;
    my %subjectTaxons;

    # get all subject body site genomes
    #
    # taxon oid => name
    print "Getting all $body_site metagenomes <br/>\n";
    my %subjectTaxons;
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select distinct t.taxon_oid, t.taxon_display_name
        from project_info_gold p, env_sample_gold esg, taxon t
        where p.project_oid = esg.project_info
        and t.sample_gold_id = esg.gold_id
        and esg.host_name = 'Homo sapiens'
        and esg.body_site = ?
        and p.project_oid = 18646        
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $body_site );

    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $subjectTaxons{$taxon_oid} = $name;
    }
    return \%subjectTaxons;
}

sub printAllRefGenomeList_merfs {
    my $queryBodySite   = param('qbody_site');
    my $subjectBodySite = param('sbody_site');

    my $display_site = $subjectBodySite;
    if ( $subjectBodySite eq 'Other' ) {
        $display_site = 'Other Body Sites';
    } elsif ( $subjectBodySite eq 'Unknown' ) {
        $display_site = 'Other Isolation Sources';
    }

    print qq{
        <h1>
       $queryBodySite Samples $display_site Ref. Genomes List
       </h1>
       <p>
       Gene Count - Ref. Genomes gene count
       </p>
    };

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();

    my $subjectTaxons_href = getHmpGenomesViaBodySite( $dbh, $queryBodySite );

    print "Getting $subjectBodySite data <br/>\n";

    # get ref genome - human
    my $sql = qq{
        select t.taxon_oid, p.gold_stamp_id, t.taxon_display_name
        from taxon t, project_info\@imgsg_dev p,
             project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null  
        and b.sample_body_site = ?
        and t.gold_id = p.gold_stamp_id
    };

    if ( $subjectBodySite eq 'Other' ) {
        $sql = qq{
        select t.taxon_oid, p.gold_stamp_id, t.taxon_display_name
        from taxon t, project_info\@imgsg_dev p,
             project_info_body_sites\@imgsg_dev b
        where p.project_oid = b.project_oid
        and p.host_name = 'Homo sapiens'
        and b.sample_body_site is not null  
        and p.gold_stamp_id is not null  
        and b.sample_body_site not in 
          ( 'Airways', 'Gastrointestinal tract', 'Oral', 
            'Skin', 'Urogenital tract' )
        and t.gold_id = p.gold_stamp_id
    };
    } elsif ( $subjectBodySite eq 'Unknown' ) {
        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
        $sql = qq{
            select t.taxon_oid,  t.gold_id, t.taxon_display_name
            from taxon t
            where t.genome_type = 'isolate'
            $rclause
            $imgClause
            and t.gold_id not in
              ( select p.gold_stamp_id
                from taxon t, project_info\@imgsg_dev p,
                     project_info_body_sites\@imgsg_dev b
                where p.project_oid = b.project_oid
                and p.host_name = 'Homo sapiens'
                and b.sample_body_site is not null  
                and p.gold_stamp_id is not null  
                and b.sample_body_site is not null )
        };
    }

    my %refTaxons;
    my $cur;
    if ( $subjectBodySite eq 'Other' || $subjectBodySite eq 'Unknown' ) {
        $cur = execSql( $dbh, $sql, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $subjectBodySite );
    }
    for ( ; ; ) {
        my ( $taxon_oid, $gold_id, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $refTaxons{$taxon_oid} = $name;
    }

    my %allCounts;
    foreach my $taxon_oid ( sort keys %$subjectTaxons_href ) {
        my $sql = qq{
            select dt.taxon_oid, dt.homolog_taxon,
                   dt.gene_count_30, dt.gene_count_60, dt.gene_count_90
            from dt_phylo_taxon_stats dt
            where dt.taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $txid, $homo_taxon, $cnt30, $cnt60, $cnt90 ) = $cur->fetchrow();
            last if ( !$txid );
            next if ( !exists $refTaxons{$homo_taxon} );
            $allCounts{$homo_taxon} = $cnt30 + $cnt60 + $cnt90;
        }
    }

    my $it = new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "asc", "left" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Gene Count",  "asc", "right" );

    my $rowcnt = 0;

    printEndWorkingDiv();

    foreach my $qtaxon_oid ( keys %allCounts ) {
        my $gene_cnt = $allCounts{$qtaxon_oid};
        my $qname    = $refTaxons{$qtaxon_oid};

        my $r;
        $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$qtaxon_oid'/>\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$qtaxon_oid";
        $r .= $qtaxon_oid . $sd . alink( $url, $qtaxon_oid ) . "\t";
        $r .= $qname . $sd . $qname . "\t";

        # refGeneList
        my $url =
            "$main_cgi?section=MetagPhyloDist"
          . "&page=refGeneList&qbody_site=$queryBodySite"
          . "&sbody_site=$subjectBodySite"
          . "&taxon_oid=$qtaxon_oid";
        $r .= $gene_cnt . $sd . alink( $url, $gene_cnt ) . "\t";

        $it->addRow($r);
        $rowcnt++;
    }

    if ( $rowcnt > 10 ) {
        print submit(
                      -name    => 'setTaxonFilter',
                      -value   => 'Add Selected to Genome Cart',
                      -class   => 'meddefbutton',
                      -onClick => "return isGenomeSelected('allmetagphylodist');"
        );
        print nbsp(1);
        WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('allmetagphylodist');"
    );
    print nbsp(1);
    WebUtil::printButtonFooter();

    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$rowcnt Loaded", 2 );
}

sub printRefGeneList_merfs {
    my $queryBodySite   = param('qbody_site');
    my $subjectBodySite = param('sbody_site');
    my $taxon_oid2      = param('taxon_oid');

    my $display_site = $subjectBodySite;
    if ( $subjectBodySite eq 'Other' ) {
        $display_site = 'Other Body Sites';
    } elsif ( $subjectBodySite eq 'Unknown' ) {
        $display_site = 'Other Isolation Sources';
    }

    my $dbh         = dbLogin();
    my $genome_name = genomeName( $dbh, $taxon_oid2 );
    my $url         = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid2";
    $url = alink( $url, $genome_name );

    print qq{
        <h1>Ref. Gene List</h1>
        <p style='width: 650px;'>
        For $url <br/>
        For $queryBodySite Sample
        and Ref. $display_site genomes
        </p>
    };

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my $subjectTaxons_href = getHmpGenomesViaBodySite( $dbh, $queryBodySite );

    my %geneList1;
    my %geneList2;
    my %percentIdent;

    # ANNA: FIXHERE
    foreach my $taxon_oid ( sort keys %$subjectTaxons_href ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        foreach my $p2 ( 30, 60, 90 ) {
            my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) . "/assembled." . $p2 . ".sdb";
            if ( -e $full_dir_name ) {
                my $dbh3 = WebUtil::sdbLogin($full_dir_name) or next;

                my $sql = MetaUtil::getPhyloDistSingleHomoTaxonSql();
                my $sth  = $dbh3->prepare($sql);
                $sth->execute($taxon_oid2);
                for ( ; ; ) {
                    my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $est_copy ) = $sth->fetchrow_array();
                    last if ( !$gene_oid );
                    next if ( $homo_taxon ne $taxon_oid2 );
                    next if ( $gene_perc eq "" );

                    $geneList1{$gene_oid}                     = $taxon_oid;
                    $geneList2{$homolog_gene}                 = '';
                    $percentIdent{"$gene_oid\t$homolog_gene"} = $gene_perc;
                }

                $sth->finish();
                $dbh3->disconnect();
            }
        }
    }

    # now get gene info

    OracleUtil::insertDataHash( $dbh, "gtt_num_id", \%geneList2 );
    my $sql = qq{
        select gene_oid, gene_display_name, locus_tag
        from gene
        where gene_oid in (select id from gtt_num_id)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $name, $locus_tag ) = $cur->fetchrow();
        last if ( !$gene_oid );
        $geneList2{$gene_oid} = " $name\t$locus_tag";
    }

    #$dbh->disconnect();
    foreach my $taxon_oid ( sort keys %$subjectTaxons_href ) {
        my (%names) = MetaUtil::getGeneProdNamesForTaxon( $taxon_oid, 'assembled' );
        for my $id ( keys %names ) {
            my $name = $names{$id};
            $geneList1{$id} = "$taxon_oid\t$name\t$id";
        }
    }

    printEndWorkingDiv();
    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->disableSelectButtons();
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Ref. Gene ID",           "asc", "left" );
    $it->addColSpec( "Ref. Locus Tag",         "asc", "left" );
    $it->addColSpec( "Ref. Gene Product Name", "asc", "left" );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Percent Identity",  "asc", "right" );

    my $rowcnt = 0;
    foreach my $key ( keys %percentIdent ) {
        my $percent = $percentIdent{$key};
        my ( $qgene_oid, $sgene_oid ) = split( /\t/, $key );
        my ( $qtaxon_oid, $qname, $qlocus_tag ) = split( /\t/, $geneList1{$qgene_oid} );
        my ( $sname, $slocus_tag ) = split( /\t/, $geneList2{$sgene_oid} );

        my $r;

        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$sgene_oid'  />\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$sgene_oid";
        $r .= $sgene_oid . $sd . alink( $url, $sgene_oid ) . "\t";
        $r .= $slocus_tag . $sd . $slocus_tag . "\t";
        $r .= $sname . $sd . $sname . "\t";

        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$qgene_oid'  />\t";

        my $url =
            "$main_cgi?section=MetaGeneDetail"
          . "&page=geneDetail&gene_oid=$qgene_oid"
          . "&taxon_oid=$qtaxon_oid&data_type=assembled";
        $r .= $qgene_oid . $sd . alink( $url, $qgene_oid ) . "\t";
        $r .= $qlocus_tag . $sd . $qlocus_tag . "\t";
        $r .= $qname . $sd . $qname . "\t";
        $r .= $percent . $sd . $percent . "\t";

        $it->addRow($r);
        $rowcnt++;
    }

    printGeneCartFooter() if $rowcnt > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$rowcnt Loaded", 2 );
}

# ----------------------------------------------------------------------------
#
#  END of HMP - M functions
#
# ----------------------------------------------------------------------------

1;
