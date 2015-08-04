############################################################################
# Creates a Bar Chart as a PNG file
# $Id: BarChartImage.pm 32375 2014-12-03 20:49:53Z jinghuahuang $
############################################################################
package BarChartImage;

use strict;
use CGI qw(:standard);
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MerFsUtil;
use ChartUtil;

$| = 1;

my $env = getEnv();
my $tmp_url = $env->{tmp_url};
my $base_url = $env->{base_url};
my $verbose = $env->{verbose};

# location of yahoo's api
my $YUI = $env->{yui_dir_28};


sub dispatch {
    my $page = param("page");

    if ($page eq "cogStatsMetagenome") {
        my $taxon_oid = param("taxon_oid");
        my $code = param("function_code");
        my $perc = param("perc");
        getImage($taxon_oid, $code, $perc, "func");

    } elsif ($page eq "cogPathStatsMetagenome") {
        my $taxon_oid = param("taxon_oid");
        my $oid = param("cog_pathway_oid");
        my $perc = param("perc");
        getImage($taxon_oid, $oid, $perc, "path");

    } elsif ($page eq "compareKeggStats") {
        my $category = param("kegg");
        getImage2($category);

    } elsif ($page eq "compareCOGStats") {
        my $code = param("function_code");
        getImage3($code, "cog");
    } elsif ($page eq "compareKOGStats") {
        my $code = param("function_code");
        getImage3($code, "kog");
    } elsif ($page eq "comparePfamStats") {
        my $code = param("function_code");
        getImage3($code, "pfam");
    } elsif ($page eq "compareTIGRfamStats") {
        my $role = param("role");
        getImage3($role, "tigrfam");
    }
}

#####################################################
# Chart image png url is returned in an xml fragment
# COG metagenome stats
#####################################################
sub getImage {
    my ($taxon_oid, $id, $percent, $which) = @_;
    #webLog "ANNA oid: ".$taxon_oid."  id:".$id."\n";

    my $plus = param("plus");

    if ($id eq "") {
        my $header = "no COG assignment";
        my $body = "Genes with no COG assignment";

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq {
            <response>
                <header>$header</header>
                <url>'$body'</url>
            </response>
        }; 
        return;
    }

    # PREPARE THE BAR CHART 
    my $chart = newBarChart(); 
    $chart->WIDTH(450); 
    $chart->HEIGHT(350); 
    $chart->DOMAIN_AXIS_LABEL("Phylum");
    $chart->RANGE_AXIS_LABEL("Number of Genes");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    ##########################################

    my $dbh = dbLogin();

    my $sql;
    if ($which eq "func") {
        $sql = qq {
            select definition
            from cog_function
            where function_code = ?
        };
    } elsif ($which eq "path") {
        $sql = qq {
            select cog_pathway_name
            from cog_pathway
            where cog_pathway_oid = ?
        };
    }

    my $cur = execSql($dbh, $sql, $verbose, $id);
    my ($name) = $cur->fetchrow();
    $cur->finish();

    my $rclause = "";
    if ($percent == 30) {
        if ( $plus ) {
            $rclause = "and dt.percent_identity >= 30 ";
        }
        else {
            $rclause = " and dt.percent_identity >= 30 "
                     . " and dt.percent_identity < 60 ";
        }
    } elsif ($percent == 60) {
        if ( $plus ) {
            $rclause = "and dt.percent_identity >= 60 ";
        }
        else {
            $rclause = " and dt.percent_identity >= 60 "
                     . " and dt.percent_identity < 90 ";
        }
    } else {
        $rclause = "and dt.percent_identity >= 90 ";
    }

    my $sql;
    if ($which eq "func") {
        $sql = qq {
            select dt.domain, dt.phylum, count(dt.gene_oid)
            from dt_phylum_dist_genes dt, gene_cog_groups gcg, cog_functions cfs
            where dt.taxon_oid = ?
            and dt.gene_oid = gcg.gene_oid
            and gcg.cog = cfs.cog_id
            and cfs.functions = ?
            $rclause
            group by dt.domain, dt.phylum
            order by dt.domain, dt.phylum
        };
    } elsif ($which eq "path") {
        $sql = qq {
            select dt.domain, dt.phylum, count(dt.gene_oid)
            from dt_phylum_dist_genes dt, gene_cog_groups gcg,
                 cog_pathway_cog_members cpcm
            where dt.taxon_oid = ?
            and dt.gene_oid = gcg.gene_oid
            and gcg.cog = cpcm.cog_members
            and cpcm.cog_pathway_oid = ?
            $rclause
            group by dt.domain, dt.phylum
            order by dt.domain, dt.phylum
        };
    }

    my %cogItems;
    $cur = execSql($dbh, $sql, $verbose, $taxon_oid, $id);

    my @phyla;
    my @gene_count_data;
    for ( ;; ) {
        my ($domain, $phylum, $gene_count)
            = $cur->fetchrow(); 
        last if !$domain;
        $cogItems{$phylum} = $gene_count;

        push @phyla, $phylum;
        push @gene_count_data, $gene_count;
    }
    $cur->finish();

    my @chartseries;
    push @chartseries, "count"; 
    $chart->SERIES_NAME(\@chartseries); 
    $chart->CATEGORY_NAME(\@phyla);
    my $datastr = join(",", @gene_count_data);
    my @datas = ($datastr); 
    $chart->DATA(\@datas); 

    #$dbh->disconnect();

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = generateChart($chart); 
    }

    if ($env->{ chart_exe } ne "") {
        if ($st == 0) { 
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png"; 
            my $imagemap = "#".$chart->FILE_PREFIX;
	    my $script = "$base_url/overlib.js";
            my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq { 
                <response> 
                    <header>$name</header> 
                    <script>$script</script> 
                    <maptext><![CDATA[ 
            }; 

            my $FH = newReadFileHandle 
                ($chart->FILEPATH_PREFIX.".html", "statsMetagenome",1);
            while (my $s = $FH->getline()) { 
                print $s;
            } 
            close ($FH); 

            #webLog "ANNA url: ".$url."\n";
            print qq { 
                    ]]></maptext>
                    <url>$url</url>
                    <imagemap>$imagemap</imagemap>
                    <width>$width</width> 
                    <height>$height</height> 
                </response> 
            }; 
        }
    }
}

#####################################################
# Chart image png url is returned in an xml fragment
# Stats for genomes by specific KEGG category
#####################################################
sub getImage2 {
    my ($category) = @_;

    my $dbh = dbLogin();
    my $taxonClause = txsClause("tx", $dbh);
    my $nTaxons = getSelectedTaxonCount();
    my $max = 40;

    my $pangenome_oid = param("pangenome_oid");
    if ($pangenome_oid ne "") {
        $max = 9999999;
        use Pangenome;
        my $aref = Pangenome::getCompGenomes( $dbh, $pangenome_oid );
        push( @$aref, $pangenome_oid );
        $nTaxons = scalar @$aref;
        my $taxon_str = join( ',', @$aref );
        $taxonClause = qq{
            and tx.taxon_oid in ($taxon_str)
        };
    }

    if ($nTaxons > $max) {
        my $body = "Number of genomes selected ($nTaxons) is "
	         . "greater than $max, \nso no chart is displayed.";
        my $header = "Too many genomes";

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq{
            <response>
                <header>$header</header>
                <url>$body</url>
            </response>
        };
        return;
    }

    my %taxon2name = getTaxonName( $dbh, $taxonClause );
    my @goodTaxons = keys %taxon2name;
    my ( $dbTaxons_ref, $metaTaxons_ref ) 
	= MerFsUtil::findTaxonsInFile( $dbh, @goodTaxons );

    my @taxon_oids;
    my @gene_count_data;
    if ( scalar(@$dbTaxons_ref) > 0 ) {
        my $taxon_str = join( ',', @$dbTaxons_ref );
        $taxonClause = qq{
            and g.taxon in ($taxon_str)
        };      

        my $sql = qq{
           select g.taxon, count( distinct g.gene_oid )
           from kegg_pathway pw, image_roi roi, 
                image_roi_ko_terms irkt, ko_term_enzymes kte,
                gene_ko_enzymes ge, gene g
           where pw.pathway_oid = roi.pathway
           and roi.roi_id = irkt.roi_id
           and irkt.ko_terms = kte.ko_id
           and kte.enzymes = ge.enzymes
           and ge.gene_oid = g.gene_oid
           and g.locus_type = ?
           and g.obsolete_flag = ?
           and pw.category = ?
           $taxonClause
           group by g.taxon
           having count( distinct g.gene_oid ) > 0
           order by g.taxon
        };
    
        my $cur = execSql($dbh, $sql, $verbose, 'CDS', 'No', $category );
	for ( ;; ) {
            my ($taxon_oid, $gene_count) = $cur->fetchrow();
            last if !$taxon_oid;
            push @taxon_oids, $taxon_oid;
            push @gene_count_data, $gene_count;
        }
        $cur->finish();
    }

    if ( scalar(@$metaTaxons_ref) > 0 ) {        
        my $sql = qq{
            select distinct pw.pathway_oid
            from kegg_pathway pw
            where pw.category = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $category );
        my @ids;
        for ( ;; ) {
            my ($id) = $cur->fetchrow();
            last if !$id;
            push(@ids, $id);
        }
        $cur->finish();
        
        foreach my $t_oid (@$metaTaxons_ref) {
            my %funcs = MetaUtil::getTaxonFuncCount($t_oid, '', 'kegg_pathway');
            my $gene_count;
            for my $id (@ids) {
                #Todo: in-accurate with addition of gene_count
                $gene_count += $funcs{$id};
            }
            if ($gene_count > 0) {
                push @taxon_oids, $t_oid;
                push @gene_count_data, $gene_count;                
            }
        }
    }
    
    my $nTaxons = @taxon_oids;

    # percentage is of total genes in genome
    my $sql = qq{
        select genes_in_kegg
        from taxon_stats
        where taxon_oid = ?
    };
    my $cur = prepSql($dbh, $sql, $verbose );

    my @taxons;
    my @taxon_gene_count_data;
    foreach my $oid (@taxon_oids) {
        last if !$oid;
        push @taxons, $taxon2name{$oid};

        execStmt( $cur, $oid );
        my $taxon_gene_count = $cur->fetchrow();
        push @taxon_gene_count_data, $taxon_gene_count;
    }
    $cur->finish();

    my $chartW = 750;
    if ($nTaxons < 20) {
        $chartW = 450;
    } elsif ($nTaxons < 30) {
        $chartW = 600;
    } elsif ($nTaxons <= 40) {
        $chartW = 750;
    }

    # PREPARE THE BAR CHART
    my $chart = newBarChart(); 
    $chart->WIDTH($chartW); 
    $chart->HEIGHT(350); 
    $chart->DOMAIN_AXIS_LABEL("Genome Name"); 
    $chart->RANGE_AXIS_LABEL("% of Genes in Genome"); 
    $chart->INCLUDE_TOOLTIPS("yes"); 
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes"); 
    ########################################## 

    my @chartseries;
    push @chartseries, "count"; 
    $chart->SERIES_NAME(\@chartseries); 
    $chart->CATEGORY_NAME(\@taxons);
    my $datastr = join(",", @gene_count_data);
    my @datas = ($datastr); 
    $chart->DATA(\@datas); 

    my $totalstr = join(",", @taxon_gene_count_data);
    my @totaldatas = ($totalstr);
    $chart->DATA_TOTALS(\@totaldatas);

    my $st = -1;
    if (($env->{ chart_exe } ne "") &&
        ($nTaxons <= $max)) { 
        $st = generateChart($chart); 
    }

    if ($env->{ chart_exe } ne "") {
        if ($st == 0) { 
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png"; 
            my $imagemap = "#".$chart->FILE_PREFIX; 
            my $script = "$base_url/overlib.js";
            my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq{ 
                <response> 
                    <header>$category</header>
                    <script>$script</script>
                    <maptext><![CDATA[
            }; 

            my $FH = newReadFileHandle
		($chart->FILEPATH_PREFIX.".html", "keggStats",1);
            while (my $s = $FH->getline()) {
                print $s;
            }
            close ($FH);

            #webLog "ANNA url: ".$url."\n";
            print qq{
                    ]]></maptext>
                    <url>$url</url>
                    <imagemap>$imagemap</imagemap>
                    <width>$width</width>
                    <height>$height</height>
                </response>
            };
        }
    }
}

#####################################################
# Chart image png url is returned in an xml fragment
# Stats for genomes by specific COG, Pfam, TIGRfam
#####################################################
sub getImage3 {
    my ($code, $which) = @_;

    my $dbh = dbLogin();
    my $taxonClause = txsClause("tx", $dbh);
    my $nTaxons = getSelectedTaxonCount();
    my $max = 40; 

    my $pangenome_oid = param("pangenome_oid");
    if ($pangenome_oid ne "") {
        $max = 9999999;
        use Pangenome;
        my $aref = Pangenome::getCompGenomes( $dbh, $pangenome_oid );
        push( @$aref, $pangenome_oid );
        $nTaxons = scalar @$aref;
        my $taxon_str = join( ',', @$aref );
        $taxonClause = qq{
            and tx.taxon_oid in ($taxon_str)
        };
    }  

    if ($nTaxons > $max) { 
        my $body = "Number of genomes selected ($nTaxons) is "
             . "greater than $max, \nso no chart is displayed.";
        my $header = "Too many genomes"; 
 
        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq{
            <response> 
                <header>$header</header>
                <url>$body</url>
            </response> 
        }; 
        return; 
    } 

    my %taxon2name = getTaxonName( $dbh, $taxonClause );
    my @goodTaxons = keys %taxon2name;
    my ( $dbTaxons_ref, $metaTaxons_ref ) 
	= MerFsUtil::findTaxonsInFile( $dbh, @goodTaxons );

    my $definition;
    if ($which eq "cog") { 
        my $sql = qq{ 
            select definition 
            from cog_function 
            where function_code = ?
        }; 
        my $cur = execSql($dbh, $sql, $verbose, $code );
        $definition = $cur->fetchrow(); 
        $cur->finish(); 
        
    } elsif ($which eq "kog") { 
        my $sql = qq{ 
            select definition 
            from kog_function 
            where function_code = ?
        }; 
        my $cur = execSql($dbh, $sql, $verbose, $code );
        $definition = $cur->fetchrow(); 
        $cur->finish(); 
        
    } elsif ($which eq "pfam") { 
        if ($code ne "_" && $code ne "Unclassified") {
            my $sql = qq{ 
                select definition 
                from cog_function 
                where function_code = ?
            }; 
            my $cur = execSql($dbh, $sql, $verbose, $code);
            $definition = $cur->fetchrow(); 
            $cur->finish();
        } else {
            $definition = "Unclassified";
        }
        
    } elsif ($which eq "tigrfam") {
        $definition = $code;    
    }

    my @taxon_oids;
    my @gene_count_data;
    if ( scalar(@$dbTaxons_ref) > 0 ) {
        my $taxon_str = join( ',', @$dbTaxons_ref );
        $taxonClause = qq{
            and g.taxon in ($taxon_str)
        };

        my $sql; 
        my @binds;
    
        if ( $which eq "cog" ) { 
            $sql = qq{
                select g.taxon, count( distinct gcg.gene_oid )
                from gene_cog_groups gcg, cog c, gene g, cog_function cf,
                     cog_functions cfs
                where gcg.cog = c.cog_id
                and gcg.gene_oid = g.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                and cfs.functions = ?
                and cfs.cog_id = c.cog_id
                $taxonClause
                group by g.taxon
                having count(distinct gcg.gene_oid) > 0
                order by g.taxon
            };
            push (@binds, 'CDS', 'No', $code);
            
        } elsif ( $which eq "kog" ) { 
            $sql = qq{
                select g.taxon, count( distinct gcg.gene_oid )
                from gene_kog_groups gcg, kog c, gene g, kog_function cf,
                     kog_functions cfs
                where gcg.kog = c.kog_id
                and gcg.gene_oid = g.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                and cfs.functions = ?
                and cfs.kog_id = c.kog_id
                $taxonClause
                group by g.taxon
                having count(distinct gcg.gene_oid) > 0
                order by g.taxon
            };
            push (@binds, 'CDS', 'No', $code);
            
        } elsif ( $which eq "pfam" ) { 
            my $clause = "and pfc.functions is null";
            if ($code ne "_" && $code ne "Unclassified") {
                $clause = "and pfc.functions = '$code'";
            } 
    
            $sql = qq{
                select g.taxon, count( distinct g.gene_oid ) 
                from gene g, pfam_family_cogs pfc, gene_pfam_families gpf
                where pfc.ext_accession = gpf.pfam_family
                and gpf.gene_oid = g.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                $clause
                $taxonClause 
                group by g.taxon 
                having count(distinct g.gene_oid) > 0 
                order by g.taxon 
            };
            push (@binds, 'CDS', 'No');
            
        } elsif ( $which eq "tigrfam" ) {
            $sql = qq{
                select g.taxon, count( distinct g.gene_oid )
                from gene g, gene_tigrfams gtf, tigrfam_roles trs, tigr_role tr
                where gtf.ext_accession = trs.ext_accession
                and trs.roles = tr.role_id
                and tr.main_role = ?
                and g.gene_oid = gtf.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                $taxonClause 
                group by g.taxon 
                having count(distinct g.gene_oid) > 0 
                order by g.taxon
            };
            push (@binds, $code, 'CDS', 'No');
        }
    
        my $cur = execSql( $dbh, $sql, $verbose, @binds );        
        for ( ;; ) {
            my ($taxon_oid, $gene_count) = $cur->fetchrow();
            last if !$taxon_oid;
            push @taxon_oids, $taxon_oid;
            push @gene_count_data, $gene_count;
        }
        $cur->finish();
    }

    if ( scalar(@$metaTaxons_ref) > 0 && $which ne "kog") {
        my $taxon_str = OracleUtil::getNumberIdsInClause
	                ( $dbh, @$metaTaxons_ref );
        my $taxonClause = qq{ 
            and g.taxon_oid in ($taxon_str)
        };
    
        my $sql;
        if ( $which eq "cog" ) { 
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_COG_COUNT g, cog_functions cfs
                where g.gene_count > 0
                and g.func_id = cfs.cog_id
                and cfs.functions = ?
                $taxonClause
            };
        }
        elsif ( $which eq "pfam" ) {
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_PFAM_COUNT g, pfam_family_cogs pfc, cog_function cf
                where g.gene_count > 0
                and g.func_id = pfc.ext_accession
                and pfc.functions = cf.function_code
                and cf.function_code = ?
                $taxonClause
            };
        }
        elsif ( $which eq "tigrfam" ) {
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_TIGR_COUNT g, tigrfam_roles trs, tigr_role tr
                where g.gene_count > 0
                and g.func_id = trs.ext_accession
                and trs.roles = tr.role_id
                and tr.main_role = ?
                $taxonClause
            };
        }
             
        my $cur = execSql( $dbh, $sql, $verbose, $code );
        my %taxon2func;
        for ( ;; ) {
            my ( $taxon_oid, $func_id, $function_code, $definition ) 
		= $cur->fetchrow();
            last if !$taxon_oid;
        
            my $func_ids_href = $taxon2func{$taxon_oid};
            if ( $func_ids_href eq '' ) {
                my %func_ids;
                $func_ids{$func_id} = 1;
                $taxon2func{$taxon_oid} = \%func_ids;
            } else {
                $func_ids_href->{$func_id} = 1;
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
	    if ( $taxon_str =~ /gtt_num_id/i );
    
        # get the genes for each func id, and put them into each category
        foreach my $t_oid (@$metaTaxons_ref) {
            my %genes_h;

            my $func_ids_href = $taxon2func{$t_oid};
            for my $func_id (keys %$func_ids_href) {
                my %func_genes = MetaUtil::getTaxonFuncGenes( $t_oid, '', $func_id );
                for my $f_gene (keys %func_genes) {
                    $genes_h{$f_gene} = 1;
                }
            }

            my $gene_count = scalar(keys %genes_h);
            if ($gene_count > 0) {
                push @taxon_oids, $t_oid;
                push @gene_count_data, $gene_count;                
            }
        }        
    }
    
    my $nTaxons = @taxon_oids;

    my $sql;
    if ( $which eq "cog" ) {
        $sql = qq{
            select genes_in_cog
            from taxon_stats
            where taxon_oid = ?
        };
    } elsif ($which eq "kog") {
        $sql = qq{
            select genes_in_kog
            from taxon_stats
            where taxon_oid = ?
        };
    } elsif ($which eq "pfam") {
        $sql = qq{
            select genes_in_pfam
            from taxon_stats
            where taxon_oid = ?
        };
    } elsif ($which eq "tigrfam") {
        $sql = qq{
            select genes_in_tigrfam
            from taxon_stats
            where taxon_oid = ?
        };
    }
    my $cur = prepSql($dbh, $sql, $verbose );

    # percentage is of total genes in genome
    my @taxons;
    my @taxon_gene_count_data;
    foreach my $oid (@taxon_oids) {
        last if !$oid;
        push @taxons, $taxon2name{$oid};

        execStmt( $cur, $oid );
        my $taxon_gene_count = $cur->fetchrow();
        push @taxon_gene_count_data, $taxon_gene_count;
    }
    $cur->finish();

    my $chartW = 750; 
    if ($nTaxons < 20) { 
        $chartW = 450; 
    } elsif ($nTaxons < 30) { 
        $chartW = 600; 
    } elsif ($nTaxons <= 40 ) { 
        $chartW = 750;
    } 
 
    # PREPARE THE BAR CHART
    my $chart = newBarChart();
    $chart->WIDTH($chartW); 
    $chart->HEIGHT(350);
    $chart->DOMAIN_AXIS_LABEL("Genome Name");
    $chart->RANGE_AXIS_LABEL("% of Genes in Genome");
    $chart->INCLUDE_TOOLTIPS("yes"); 
    $chart->INCLUDE_URLS("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes"); 
 
    my @chartseries;
    push @chartseries, "count"; 
    $chart->SERIES_NAME(\@chartseries); 
    $chart->CATEGORY_NAME(\@taxons);
    my $datastr = join(",", @gene_count_data);
    my @datas = ($datastr); 
    $chart->DATA(\@datas); 
 
    my $totalstr = join(",", @taxon_gene_count_data);
    my @totaldatas = ($totalstr); 
    $chart->DATA_TOTALS(\@totaldatas); 

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        if (($env->{ chart_exe } ne "") &&
	    ($nTaxons <= $max)) { 
            $st = generateChart($chart); 
        }
    }

    if ($env->{ chart_exe } ne "") {
        if ($st == 0) {
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png"; 
            my $imagemap = "#".$chart->FILE_PREFIX;
            my $script = "$base_url/overlib.js";
            my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq { 
                <response> 
                    <header>$definition</header> 
                    <script>$script</script> 
                    <maptext><![CDATA[ 
            }; 

            my $refname;
            if ($which eq "cog") {
                $refname = "cogStats";
            } elsif ($which eq "kog") {
                $refname = "kogStats";
            } elsif ($which eq "pfam") {
                $refname = "pfamStats";
            } elsif ($which eq "tigrfam") {
                $refname = "tigrfamStats";
            }

            my $FH = newReadFileHandle 
                ($chart->FILEPATH_PREFIX.".html", "$refname", 1);
            while (my $s = $FH->getline()) { 
                print $s;
            } 
            close ($FH); 

            #webLog "ANNA url: ".$url."\n";
            print qq { 
                    ]]></maptext>
                    <url>$url</url>
                    <imagemap>$imagemap</imagemap>
                    <width>$width</width> 
                    <height>$height</height> 
                </response> 
            }; 
        }
    }
}

sub getTaxonName {
    my ( $dbh, $taxonClause ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my %taxon2name;
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name
        from taxon tx
        where 1 = 1
        $taxonClause
        $rclause
        $imgClause
        order by tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );  
    for ( ;; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxon2name{$taxon_oid} = $taxon_display_name;
    }
    $cur->finish();    

    return ( %taxon2name );
}


1;
