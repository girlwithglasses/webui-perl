############################################################################
# CogCategoryDetail.pm - Show category deteail for a COG.
#  "Ccd" = COG category detail, relic from days before this code
#     was put into perl modules.
#    --es 07/17/2005
############################################################################
package CogCategoryDetail;

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use Time::localtime;
use CachedTable;
use WebConfig;
use WebUtil;
use HtmlUtil;
use PhyloTreeMgr;
use GeneDetail;
use MetaUtil;
use MetaGeneTable;
use MerFsUtil;
use WorkspaceUtil;

my $section              = "CogCategoryDetail";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $max_gene_batch       = 100;
my $max_taxon_batch      = 20;
my $max_scaffold_batch   = 20;
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $cog_base_url         = $env->{cog_base_url};
my $kog_base_url         = $env->{kog_base_url};
my $show_private         = $env->{show_private};
my $new_func_count       = $env->{new_func_count};

my $min_scaffold_length = 50000;
my $scaffold_page_size  = $min_scaffold_length * 3;

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    timeout( 60 * $merfs_timeout_mins );

    my $page = param("page");
    HtmlUtil::cgiCacheInitialize( $section );
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "cogCategoryDetail" ) {
        printCogCategoryDetail();
    }
    elsif ( $page eq "cogCategoryDetailForSamples" ) {
	printCogCategoryDetailForSamples();
    }
    elsif ( $page eq "kogCategoryDetail" ) {
        printCogCategoryDetail("kog");
    }
    elsif ( $page eq "kogGroupList" ) {
        printKogGroupList();
    }
    elsif ( $page eq "nullCOGCategoryDetail" ) {
        printNullCogCategoryDetail();
    }
    elsif ( $page eq "nullKOGCategoryDetail" ) {
        printNullCogCategoryDetail("kog");
    }
    elsif ( $page eq "cogPathwayDetail" ) {
        printCogPathwayDetail();
    }
    elsif ( $page eq "kogPathwayDetail" ) {
        printCogPathwayDetail("kog");
    }
    elsif ( $page eq "nullCOGPathwayDetail" ) {
        printNullCogPathwayDetail();
    }
    elsif ( $page eq "nullKOGPathwayDetail" ) {
        printNullCogPathwayDetail("kog");
    }
    elsif ( $page eq "ccdCOGGenomeList" ) {
        printCcdCogGenomeList();
    }
    elsif ( $page eq "ccdKOGGenomeList" ) {
        printCcdCogGenomeList("kog");
    }
    elsif ( $page eq "ccdCOGPhyloDist" ) {
        printCcdPhyloDist();
    }
    elsif ( $page eq "ccdKOGPhyloDist" ) {
        printCcdPhyloDist("kog");
    }
    elsif ( $page eq "ccdCOGGenomeGeneList" ) {
        printCcdCogGenomeGeneList();
    }
    elsif ( $page eq "ccdKOGGenomeGeneList" ) {
        printCcdCogGenomeGeneList("kog");
    }
    elsif ( $page eq "ccdCOGTaxonGenes" ) {
        printCcdCogTaxonGenes();
    }
    elsif ( $page eq "ccdKOGTaxonGenes" ) {
        printCcdCogTaxonGenes("kog");
    }
    elsif ( $page eq "ccdCOGSelectScaffolds" ) {
        printCcdSelectScaffolds();
    }
    elsif ( $page eq "ccdKOGSelectScaffolds" ) {
        printCcdSelectScaffolds("kog");
    }
    elsif ( $page eq "cpdCOGSelectScaffolds" ) {
        printCpdSelectScaffolds();
    }
    elsif ( $page eq "cpdKOGSelectScaffolds" ) {
        printCpdSelectScaffolds("kog");
    }
    elsif ( paramMatch("ccdCOGViewScaffoldProfile") ne "" ) {
        printCcdScaffoldProfile();
    }
    elsif ( paramMatch("ccdKOGViewScaffoldProfile") ne "" ) {
        printCcdScaffoldProfile("kog");
    }
    elsif ( paramMatch("cpdCOGViewScaffoldProfile") ne "" ) {
        printCpdScaffoldProfile();
    }
    elsif ( paramMatch("cpdKOGViewScaffoldProfile") ne "" ) {
        printCpdScaffoldProfile("kog");
    }
    elsif ( $page eq "ccdCOGScaffoldGenes" ) {
        printCcdCogScaffoldGenes();
    }
    elsif ( $page eq "ccdKOGScaffoldGenes" ) {
        printCcdCogScaffoldGenes("kog");
    }
    elsif ( $page eq "cpdCOGScaffoldGenes" ) {
        printCpdCogScaffoldGenes();
    }
    elsif ( $page eq "cpdKOGScaffoldGenes" ) {
        printCpdCogScaffoldGenes("kog");
    }
    else {
        printCogCategoryDetail();
    }

    HtmlUtil::cgiCacheStop();
}

############################################################################
# hasOneValue - Has one value in that is non-zero in hash.
############################################################################
sub hasOneValue {
    my ($h_ref) = @_;
    my @keys = keys(%$h_ref);
    for my $k (@keys) {
        my $v = $h_ref->{$k};
        return 1 if $v;
    }
    return 0;
}

############################################################################
# printCogCategoryDetailForSamples - Show detail page for COG category 
#                                    for selected samples and study
############################################################################
sub printCogCategoryDetailForSamples {
    my $fn_code = param("function_code");
    my $taxon_oid = param("taxon_oid");
    my $study = param("study");
    my $sample_oid_str = param("samples");
    my @sample_oids = split(',', $sample_oid_str);
    my $nSamples = @sample_oids;

    if ($nSamples < 1) {
        webError( "Please select at least 1 sample." );
    }

    printMainForm();
    print "<h1>COG Category Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();
    print "<p>Getting cogs ...\n";

    # get cog ids and names for the selected function & taxon
    my %cog_name_h;
    my $sql = qq{
        select c.cog_id, c.cog_name
        from cog_function cf, cog_functions cfs,
             cog c, mv_taxon_cog_stat t
        where cf.function_code = ?
        and cf.function_code = cfs.functions
        and cfs.cog_id = c.cog_id
        and c.cog_id = t.cog
        and t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $fn_code, $taxon_oid );
    for ( ;; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_name_h{$cog_id} = $cog_name;
    }
    $cur->finish();

    # for metagenomes ?
    $sql = qq{
        select c.cog_id, c.cog_name
        from cog_function cf, cog_functions cfs,
             cog c, taxon_cog_count t
        where cf.function_code = ?
        and cf.function_code = cfs.functions
        and cfs.cog_id = c.cog_id
        and c.cog_id = t.func_id
        and t.taxon_oid = ?
        and t.gene_count > 0
    };
    $cur = execSql( $dbh, $sql, $verbose, $fn_code, $taxon_oid );
    for ( ; ; ) {
	my ( $cog_id, $cog_name ) = $cur->fetchrow();
	last if !$cog_id;
        $cog_name_h{$cog_id} = $cog_name;
    }
    $cur->finish();

    my @cogs4fn = sort keys %cog_name_h;

    my ($taxon_oid, $in_file, $genome_type);
    my %sampleNames;
    if ($study eq "rnaseq") {
        my $names_ref = RNAStudies::getNamesForSamples($dbh, $sample_oid_str);
        %sampleNames = %$names_ref;

        my $txsql = qq{
            select distinct dts.reference_taxon_oid, tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $txsql, $verbose );
        ($taxon_oid, $in_file, $genome_type) = $cur->fetchrow();
        $cur->finish();
    }

    my %sample2geneInfo;
    my %cog2genes;
    my @allcogs;
    if ($study eq "rnaseq") {
	foreach my $cog_id (@cogs4fn) {
	    my %cog_genes;
	    print "<br/>Getting cog genes for $cog_id ...\n";
	    if ($genome_type eq "metagenome") {
		%cog_genes = MetaUtil::getTaxonFuncGenes
		    ($taxon_oid, "assembled", $cog_id);
	    } else {
		my $sql = qq{
                    select gcg.gene_oid
                    from gene_cog_groups gcg, cog c,
                         cog_functions cfs, cog_function cf
                    where gcg.cog = c.cog_id
                    and c.cog_id = ?
                    and c.cog_id = cfs.cog_id
                    and cfs.functions = cf.function_code
                    and cf.function_code = ?
                    and gcg.taxon = ?
                };

		my $cur = execSql( $dbh, $sql, $verbose, 
				   $cog_id, $fn_code, $taxon_oid );
		for ( ;; ) {
		    my ( $gene_oid ) = $cur->fetchrow();
		    last if !$gene_oid;
		    $cog_genes{ $gene_oid } = 1;
		}
		$cur->finish();
	    }

            my @gene_group = keys %cog_genes;
            next if (scalar @gene_group == 0);
	    print "<br/>$cog_id: ".scalar @gene_group." genes";

	    my $found = 0;
            foreach my $s( @sample_oids ) {
		$s =~ tr/'//d;
		my $insample = 0;
		print "<br/>checking SAMPLE:$s ...";

                # check if a gene is among genes for this sample:
                GENE: foreach my $gene( @gene_group ) {
		    my ($geneid, $locus_type, $locus_tag, $strand,
			$scaffold_oid, $dna_seq_length, $reads_cnt, @rest) =
			MetaUtil::getGeneInRNASeqSample($gene,$s,$taxon_oid);
		    next if !$geneid;
		    next if (! $reads_cnt > 0.0000000);

		    $found = 1;
		    $insample = 1;
                    $cog2genes{ $s.$cog_id } .= $gene."\t";
                }
		if (!$insample && $genome_type ne "metagenome") {
		    # still need to check db:
		    my $genestr = join(",", @gene_group);
		    my $sql = qq{
                        select distinct es.IMG_gene_oid
                        from rnaseq_expression es
                        where es.dataset_oid = ?
                        and es.reads_cnt > 0.0000000
                        and es.IMG_gene_oid in ($genestr)
                    };
		    my $cur = execSql( $dbh, $sql, $verbose, $s );
		    for ( ;; ) {
			my ( $gene ) = $cur->fetchrow();
			last if !$gene;
			$cog2genes{ $s.$cog_id } .= $gene."\t";
			$found = 1;
		    }
		}
            }
	    push (@allcogs, $cog_id) if $found;
	}
    }

    printEndWorkingDiv();

    my $cit = new InnerTable( 1, "cogsforsamples$$", "cogsforsamples", 1 );
    my $sd = $cit->getSdDelim();
    $cit->addColSpec( "Select" );
    $cit->addColSpec( "COG ID",   "asc", "left" );
    $cit->addColSpec( "COG Name", "asc", "left" );
    foreach my $s( @sample_oids ) {
        $cit->addColSpec( "Gene Count<br/>".$sampleNames{$s}." [$s]",
			  "asc", "right", "", "", "wrap" );
    }

    my $count = 0;
    foreach my $cog_id ( @allcogs ) {
        my $cog_name = $cog_name_h{$cog_id};
        $count++;

        my $r = $sd
	    . "<input type='checkbox' name='func_id' value='$cog_id' />\t";
        my $url = "$cog_base_url$cog_id";
        $r .= "$cog_id" . $sd . alink( $url, $cog_id ) . "\t";
        $r .= "$cog_name\t";

	foreach my $s( @sample_oids ) {
	    $s =~ tr/'//d;
	    my $geneStr = $cog2genes{ $s.$cog_id };
	    chop $geneStr;

            my $group_url = "$main_cgi?section=RNAStudies&page=geneGroup"
                . "&sample=$s&taxon_oid=$taxon_oid"
                . "&fn_id=$fn_code&fn=cog&id=$cog_id";
            my @gene_group = split("\t", $geneStr);
            my $group_count = scalar(@gene_group);
	    if ($group_count == 0) {
		$r .= $group_count."\t";
	    } else {
		$r .= $group_count.$sd
		    .alink($group_url, $group_count, "_blank", 0, 1)."\t";
	    }
	}

        $cit->addRow($r);
	$count++;
    }

    my $cogCatName = cogCategoryName( $dbh, $fn_code, "cog" );
    print "<p>Details for COG Category: ";
    print "<i>".escHtml($cogCatName)."</i></p>";

    WebUtil::printFuncCartFooter() if $count > 10;
    $cit->printTable();
    WebUtil::printFuncCartFooter();

    $cur->finish();
    print end_form();
}

############################################################################
# printCogCategoryDetail - Show detail page for COG category.
############################################################################
sub printCogCategoryDetail {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $function_code = param("function_code");

    printMainForm();
    print "<h1>${OG} Category Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select cf.${og}_id
        from ${og}_functions cf
        where cf.functions = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ;; ) {
        my ($cog_id) = $cur->fetchrow();
        last if !$cog_id;
        $allCogs{$cog_id} = 1;
    }
    $cur->finish();

    my %cog_name_h;
    $sql = qq{
        select c.${og}_id, c.${og}_name
        from ${og}_function cf, ${og}_functions cfs, ${og} c
        where cfs.functions = ?
        and cfs.${og}_id = c.${og}_id
    };
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_name_h{$cog_id} = $cog_name;
    }
    $cur->finish();

    my %cog_cnts;
    my %m_cog_cnts;

    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );
    $sql = qq{
        select g.${og}, count( distinct g.taxon_oid )
        from ${og}_function cf, ${og}_functions cfs, ${og} c,
        mv_taxon_${og}_stat g
        where cf.function_code = ?
        and cf.function_code = cfs.functions
        and cfs.${og}_id = c.${og}_id
        and c.${og}_id = g.${og}
        $taxonClause
        $rclause
        $imgClause
        group by g.${og}
    };
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $cog_id, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_cnts{$cog_id} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
            select g.${og}, count( distinct g.taxon_oid )
            from ${og}_function cf, ${og}_functions cfs, ${og} c,
            mv_taxon_${og}_stat g
            where cf.function_code = ?
            and cf.function_code = cfs.functions
            and cfs.${og}_id = c.${og}_id
            and c.${og}_id = g.${og}
            $taxonClause
            $rclause
            $imgClause
            group by g.${og}
        };
        $cur = execSql( $dbh, $sql, $verbose, $function_code );
        for ( ; ; ) {
            my ( $cog_id, $cnt ) = $cur->fetchrow();
            last if !$cog_id;
            $m_cog_cnts{$cog_id} = $cnt;
        }
        $cur->finish();

        if ( $og eq 'cog' ) {
            print "<p>Counting metagenome genes ...\n";
	    if ( $new_func_count ) {
		my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
		my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
		my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
		for my $cog_id ( sort ( keys %allCogs ) ) { 
		    print "Retrieving gene count for $cog_id ...<br/>\n"; 
 
		    $sql = qq{
                        select count(distinct f.taxon_oid)
                        from taxon_cog_count f
                        where f.gene_count > 0
                        and f.func_id = ?
                        $rclause2
                        $imgClause2
                        $taxonClause2
                    }; 
 
		    $cur = execSql( $dbh, $sql, $verbose, $cog_id ); 
		    my ( $t_cnt ) = $cur->fetchrow();
 
		    if ( $m_cog_cnts{$cog_id} ) {
			$m_cog_cnts{$cog_id} += $t_cnt; 
		    } 
		    else { 
			$m_cog_cnts{$cog_id} = $t_cnt;
		    } 
		}
		$cur->finish(); 
		print "<br/>\n"; 
		
	    } else {
		my $tClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
		$sql = MerFsUtil::getTaxonsInFileSql($tClause);
		$sql .= " and t.genome_type = 'metagenome' "; 
		$cur = execSql( $dbh, $sql, $verbose );
		for ( ; ; ) {
		    my ($t_oid) = $cur->fetchrow();
		    last if !$t_oid;

		    print ". ";
		    my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'cog' );
		    for my $cog_id ( keys %funcs ) {
			if ( $m_cog_cnts{$cog_id} ) {
			    $m_cog_cnts{$cog_id} += 1;
			}
			else {
			    $m_cog_cnts{$cog_id} = 1;
			}
		    }
		}
		$cur->finish();
		print "<br/>\n";
	    }
	}
    }

    printEndWorkingDiv();

    my $baseUrl = "$section_cgi&page=cogCategoryDetail";
    $baseUrl .= "&function_code=$function_code";

    my $hasIsolates = scalar (keys %cog_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_cog_cnts) > 0 ? 1 : 0;

    my $cachedTable =
	new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 1 );
    my $sdDelim = $cachedTable->getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "${OG} ID",   "asc", "left" );
    $cachedTable->addColSpec( "${OG} Name", "asc", "left" );
    if ($include_metagenomes) {
        $cachedTable->addColSpec("Isolate<br/>Genome Count", "desc", "right")
	    if $hasIsolates;
        $cachedTable->addColSpec("Metagenome<br/>Count", "asc",  "right")
	    if $hasMetagenomes;
    } else {
        $cachedTable->addColSpec("Genome<br/>Count", "desc", "right")
	    if $hasIsolates;
    }

    my $select_id_name = "func_id";
    my $count = 0;
    foreach my $cog_id ( keys %cog_name_h ) {
        my $cog_name = $cog_name_h{$cog_id};
        $count++;

        my $r = $sdDelim
	. "<input type='checkbox' name='$select_id_name' value='$cog_id' />\t";
        my $og_url = ( $og eq "cog" ) ? $cog_base_url : $kog_base_url;
        my $url = "$og_url$cog_id";
        $r .= "$cog_id" . $sdDelim . alink( $url, $cog_id ) . "\t";
        $r .= "$cog_name\t";

        my $cnt = $cog_cnts{$cog_id};
	if ($hasIsolates) {
	    if ($cnt) {
		my $url = "$section_cgi&page=ccd${OG}GenomeList";
		$url .= "&${og}_id=$cog_id&gtype=isolate";
		$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
	    }
	}

        if ($include_metagenomes) {
            my $m_cnt = $m_cog_cnts{$cog_id};
	    if ($hasMetagenomes) {
		if ($m_cnt) {
		    my $m_url = "$section_cgi&page=ccd${OG}GenomeList";
		    $m_url .= "&${og}_id=$cog_id&gtype=metagenome";
		    $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
		} else {
		    $r .= "0" . $sdDelim . "0" . "\t";
		}
	    }
        }

        $cachedTable->addRow($r);
    }
    $cur->finish();
    
    if ( $count == 0 ) {
        #$dbh->disconnect();
        print "<div id='message'>\n";
        print "<p>\n";
        print "No ${OG}s found for current genome selections.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $cogCatName = cogCategoryName( $dbh, $function_code, $og );
    #$dbh->disconnect();

    print "<p>";
    print "Details for ${OG} Category: ";
    print "<i>".escHtml($cogCatName)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>";

    WebUtil::printFuncCartFooter() if $count > 10;
    $cachedTable->printTable();
    WebUtil::printFuncCartFooter();

    printHint("The function cart allows for phylogenetic profile comparisons.");

    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    if ( hasOneValue( \%allCogs ) ) {
        my $url = "$section_cgi&page=null${OG}CategoryDetail";
        $url .= "&function_code=$function_code";
        print "<p>\n";
        print alink( $url, "${OG}s with no hits" );
        print "</p>\n";
    }

    if ( $include_metagenomes && $img_internal ) {
        print "<h2>Experimental</h2>\n";
        my $url = "$section_cgi&page=ccd${OG}SelectScaffolds";
        $url .= "&function_code=$function_code";
        print buttonUrl( $url, "Scaffold Profiler", "smbutton" );
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

############################################################################
# printKogGroupList - list all kog by a given function group.
############################################################################
sub printKogGroupList {
    my $function_group = param("function_group");
    print "<h1>KOG Function Group</h1>\n";
    print "<h3> $function_group </h3>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh   = dbLogin();
    my $rclause   = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql       = qq{
        select k.kog_id, k.kog_name, kf.function_code,
        kf.definition, count( distinct g.taxon )
        from kog k, kog_functions kfs,
        kog_function kf, gene_kog_groups g
        where k.kog_id = kfs.kog_id
        and k.kog_id = g.kog
        and kfs.functions = kf.function_code
        and kf.function_group = ?
        $rclause
        $imgClause
        group by k.kog_id, k.kog_name, kf.function_code, kf.definition
    };

    my $cur = execSql( $dbh, $sql, $verbose, $function_group );
    
    my $it = new InnerTable( 1, "koglist$$", "koglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "KOG ID",              "asc",  "left" );
    $it->addColSpec( "Name",                "asc",  "left" );
    $it->addColSpec( "Function Code",       "asc",  "left" );
    $it->addColSpec( "Function Definition", "asc",  "left" );
    $it->addColSpec( "Genome<br/>Count",    "desc", "right" );

    my $select_id_name = "func_id";
    
    my $count = 0;
    for ( ; ; ) {
        my ( $kog_id, $kog_name, $function_code, $definition, $cnt ) =
          $cur->fetchrow();
        last if !$kog_id;
        $count++;

        my $r;
        $r .= $sd
          . "<input type='checkbox' name='$select_id_name' "
          . "value='$kog_id' />" . "\t";

        my $url = "$kog_base_url$kog_id";
        $r .= $kog_id . $sd;
        if ($kog_base_url) {    # create a link only if url is available
            $r .= alink( $url, $kog_id );
        }
        else {
            $r .= $kog_id;
        }
        $r .= "\t";

        $r .= $kog_name . $sd . $kog_name . "\t";
        $r .= $function_code . $sd . $function_code . "\t";
        $r .= $definition . $sd . $definition . "\t";
        my $url = "$section_cgi&page=ccdKOGGenomeList";
        $url .= "&kog_id=$kog_id";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    if ( $count == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "No KOGs found for current genome selections.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    printHint("The function cart allows for phylogenetic profile comparisons.");
    print "<br/>";
    
    WebUtil::printFuncCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count loaded.", 2 );
    print end_form();
}

############################################################################
# printNullCogCategoryDetail - Show COG's that are not hit for
#   a given COG category.
############################################################################
sub printNullCogCategoryDetail {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $function_code = param("function_code");

    printMainForm();
    print "<h1>${OG}s With No Hits</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # find all COGs of this pathway
    my %cog_h;
    my $sql = qq{
      select c.${og}_id, c.${og}_name
      from ${og}_function cf, ${og}_functions cfs, ${og} c
      where cf.function_code = cfs.functions
      and cf.function_code = ?
      and cfs.${og}_id = c.${og}_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_h{$cog_id} = $cog_name;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause("dt.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("dt.taxon");
    $sql = qq{
        select c.${og}_id
        from ${og}_function cf, ${og}_functions cfs, ${og} c,
             gene_${og}_groups dt
        where cf.function_code = cfs.functions
        and cf.function_code = ?
        and cfs.${og}_id = c.${og}_id
        and c.${og}_id = dt.${og}
        $rclause
        $imgClause
    };

    my %cogsHit;
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ($cog_id) = $cur->fetchrow();
        last if !$cog_id;
        $cogsHit{$cog_id} = 1;
    }
    $cur->finish();

    # check MER-FS?
    my $check_mer = 0;
    if ( $include_metagenomes && $og eq 'cog' ) {
        for my $cog_id ( keys %cog_h ) {
            if ( $cogsHit{$cog_id} ) {
                next;
            }

            # found one
            $check_mer = 1;
            last;
        }
    }
    if ($check_mer) {
        my $rclause2   = WebUtil::urClause("t");
        my $imgClause2 = WebUtil::imgClause("t");
        $sql =
            "select t.taxon_oid from taxon t where t.in_file = 'Yes' "
          . "$rclause2 $imgClause2";
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($t_oid) = $cur->fetchrow();
            last if !$t_oid;

            my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'cog' );
            for my $cog_id ( keys %funcs ) {
                $cogsHit{$cog_id} = 1;
            }
        }
        $cur->finish();
    }

    my $baseUrl = "$section_cgi&page=null${OG}CategoryDetail";
    $baseUrl .= "&function_code=$function_code";
    my $cachedTable = new CachedTable( "null${OG}Cat$function_code", $baseUrl );
    $cachedTable->addColSpec("Select");
    $cachedTable->addColSpec( "${OG} ID",   "asc", "left" );
    $cachedTable->addColSpec( "${OG} Name", "asc", "left" );
    my $sdDelim = CachedTable::getSdDelim();

    my $select_id_name = "func_id";

    my $count = 0;
    for my $cog_id ( keys %cog_h ) {
        next if $cogsHit{$cog_id};
        my $cog_name = $cog_h{$cog_id};
        $count++;

        my $r = $sdDelim
          . "<input type='checkbox' name='$select_id_name' value='$cog_id' />\t";
        my $og_url = ( $og eq "cog" ) ? $cog_base_url : $kog_base_url;
        my $url = "$og_url$cog_id";
        $r .= "$cog_id" . $sdDelim . alink( $url, $cog_id ) . "\t";
        $r .= "$cog_name\t";
        $cachedTable->addRow($r);
    }
    $cur->finish();
    
    my $cogCatName = cogCategoryName( $dbh, $function_code, $og );
    print "<p>\n";
    print "${OG}s not hit for ${OG} Category\n";
    print "<i>\n";
    print escHtml($cogCatName);
    print "</i>.\n";
    print "</p>\n";

    if ($count) {
        WebUtil::printFuncCartFooter() if $count > 10;
        $cachedTable->printTable();
        WebUtil::printFuncCartFooter();

        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);        
    }
    else {
        print "<h5>No COGs found.</h5>\n";
    }

    print "</form>\n";

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printCogPathwayDetail - Show detail page for COG category.
############################################################################
sub printCogPathwayDetail {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $cog_pathway_oid = param("${og}_pathway_oid");

    printMainForm();
    print "<h1>${OG} Pathway Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    print "<p>Retrieving $OG Pathway information ...\n";

    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select c.${og}_id, c.${og}_name
        from ${og}_pathway_${og}_members cm, ${og} c
        where cm.${og}_pathway_oid = ?
        and cm.${og}_members = c.${og}_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        $allCogs{$cog_id} = $cog_name;
    }
    $cur->finish();

    my %cog_cnts;
    my %m_cog_cnts;

    my $taxonClause = WebUtil::txsClause( "dt.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause("dt.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon( "dt.taxon_oid", 1 );

    print "<p>Counting isolate genomes ... <br/>\n";

    my $sql = qq{
        select /*+ result_cache */ dt.${og}, count( distinct dt.taxon_oid )
        from ${og}_pathway_${og}_members cm, mv_taxon_${og}_stat dt
        where cm.${og}_pathway_oid = ?
        and cm.${og}_members = dt.${og}
        $rclause
        $imgClause
        $taxonClause
        group by dt.${og}
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    my $rowcnt = 0;
    for ( ; ; ) {
        my ( $cog_id, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_cnts{$cog_id} = $cnt;
        $rowcnt++;
    }
    $cur->finish();

    print "Done counting isolate genomes $rowcnt ...<br/>\n";

    if ($include_metagenomes) {
        print "Counting metagenomes ...<br/>\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "dt.taxon_oid", 2 );
        $sql = qq{
            select /*+ result_cache */ dt.${og}, count( distinct dt.taxon_oid )
            from ${og}_pathway_${og}_members cm,
                 mv_taxon_${og}_stat  dt
            where cm.${og}_pathway_oid = ?
            and cm.${og}_members = dt.${og} 
            $rclause
            $imgClause
            $taxonClause
            group by dt.${og}
        };

        $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
        my $rowcnt = 0;
        for ( ; ; ) {
            my ( $cog_id, $cnt ) = $cur->fetchrow();
            last if !$cog_id;
            $m_cog_cnts{$cog_id} = $cnt;
            $rowcnt++;
        }
        $cur->finish();

        print "Done counting metagenomes genomes $rowcnt ...<br/>\n";

        if ( $og eq 'cog' ) {
            print "Counting MER-FS metagenomes ...<br/>\n";

	    if ( $new_func_count ) {
		my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
		my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
		my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

		foreach my $cog_id ( sort ( keys %allCogs ) ) {
		    print "Retrieving gene count for $cog_id ...<br/>\n"; 
 
		    $sql = qq{
                       select count(distinct f.taxon_oid)
                       from taxon_cog_count f
                       where f.gene_count > 0
                       and f.func_id = ?
                       $rclause2
                       $imgClause2
                       $taxonClause2
                    }; 
 
		    $cur  = execSql( $dbh, $sql, $verbose, $cog_id ); 
		    my ( $t_cnt ) = $cur->fetchrow(); 
		    next if !$t_cnt;
 
		    if ( $m_cog_cnts{$cog_id} ) {
			$m_cog_cnts{$cog_id} += $t_cnt;
		    } else {
			$m_cog_cnts{$cog_id} = $t_cnt;
		    }
		} 
		$cur->finish();
	    
	    } else {
		my $tClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
		$sql = MerFsUtil::getTaxonsInFileSql($tClause);
		$sql .= " and t.genome_type = 'metagenome' ";
		$cur = execSql( $dbh, $sql, $verbose );
		for ( ; ; ) {
		    my ($t_oid) = $cur->fetchrow();
		    last if !$t_oid;

		    print ". ";
		    my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'cog' );
		    foreach my $cog_id ( keys %funcs ) {
			if ( $allCogs{$cog_id} ) {
			    if ( $m_cog_cnts{$cog_id} ) {
				$m_cog_cnts{$cog_id} += 1;
			    }
			    else {
				$m_cog_cnts{$cog_id} = 1;
			    }
			}
		    }
		}
		$cur->finish();
	    }
	}

        print "<br/>\n";
    }

    my $baseUrl = "$section_cgi&page=${og}PathwayDetail";
    $baseUrl .= "&${og}_pathway_oid=$cog_pathway_oid";

    my $hasIsolates = scalar (keys %cog_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_cog_cnts) > 0 ? 1 : 0;

    my $it =
	new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 1 );
    my $sdDelim = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "${OG} ID",   "asc", "left" );
    $it->addColSpec( "${OG} Name", "asc", "left" );
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "desc", "right" )
	    if $hasIsolates;
        $it->addColSpec( "Metagenome<br/>Count", "desc", "right" )
	    if $hasMetagenomes;
    } else {
        $it->addColSpec( "Genome<br/>Count", "desc", "right" )
	    if $hasIsolates;
    }

    my $select_id_name = "func_id";
    my $count = 0;
    for my $cog_id ( keys %allCogs ) {
        my $cog_name = $allCogs{$cog_id};
        $count++;

        my $r = $sdDelim
          . "<input type='checkbox' name='$select_id_name' value='$cog_id' />\t";
        my $og_url = ( $og eq "cog" ) ? $cog_base_url : $kog_base_url;
        my $url = "$og_url$cog_id";
        $r .= "$cog_id" . $sdDelim . alink( $url, $cog_id ) . "\t";
        $r .= "$cog_name\t";

        my $cnt = $cog_cnts{$cog_id};
	if ($hasIsolates) {
	    if ($cnt) {
		my $url = "$section_cgi&page=ccd${OG}GenomeList";
		$url .= "&${og}_id=$cog_id&gtype=isolate";
		$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
	    }
	}

        if ($include_metagenomes) {
            my $m_cnt = $m_cog_cnts{$cog_id};
	    if ($hasMetagenomes) {
		if ($m_cnt) {
		    my $m_url = "$section_cgi&page=ccd${OG}GenomeList";
		    $m_url .= "&${og}_id=$cog_id&gtype=metagenome";
		    $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
		} else {
		    $r .= "0" . $sdDelim . "0" . "\t";
		}
	    }
        }

        $it->addRow($r);
    }
    $cur->finish();

    printEndWorkingDiv();

    if ( $count == 0 ) {
        #$dbh->disconnect();
        print "<p>\n";
        print "No ${OG}s found for current genome selections.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $cogPathwayName = cogPathwayName( $dbh, $cog_pathway_oid, $og );
    #$dbh->disconnect();

    print "<p>\n";
    print "Details for ${OG} Pathway: ";
    print "<i>".escHtml($cogPathwayName)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    WebUtil::printFuncCartFooter() if $count > 10;
    $it->printTable();
    WebUtil::printFuncCartFooter();

    printHint("The function cart allows for phylogenetic profile comparisons.");

    ## save to workspace
    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    if ( hasOneValue( \%allCogs ) ) {
        my $url = "$section_cgi&page=null${OG}PathwayDetail";
        $url .= "&${og}_pathway_oid=$cog_pathway_oid";
        print "<p>\n";
        print alink( $url, "${OG}s with no hits" );
        print "</p>\n";
    }

    if ( $include_metagenomes && $img_internal ) {
        print "<h2>Experimental</h2>\n";
        my $url = "$section_cgi&page=cpd${OG}SelectScaffolds";
        $url .= "&${og}_pathway_oid=$cog_pathway_oid";
        print buttonUrl( $url, "Scaffold Profiler", "smbutton" );
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

############################################################################
# printNullCogPathwayDetail - Show COG pathways that are not hit
#   for a given pathwya.
############################################################################
sub printNullCogPathwayDetail {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $cog_pathway_oid = param("${og}_pathway_oid");

    printMainForm();
    print "<h1>${OG}s With No Hits</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # find all COGs of this pathway
    my %cog_h;
    my $sql = qq{
      select c.${og}_id, c.${og}_name
      from ${og}_pathway cp, ${og}_pathway_${og}_members cm, ${og} c
      where cp.${og}_pathway_oid = ?
      and cp.${og}_pathway_oid = cm.${og}_pathway_oid
      and cm.${og}_members = c.${og}_id
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        $cog_h{$cog_id} = $cog_name;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause("dt.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("dt.taxon");
    $sql = qq{
        select dt.${og}
        from ${og}_pathway cp, ${og}_pathway_${og}_members cm,
             gene_${og}_groups  dt
        where cp.${og}_pathway_oid = ?
        and cp.${og}_pathway_oid = cm.${og}_pathway_oid
        and cm.${og}_members = dt.${og}
        $rclause
        $imgClause
    };
    my %cogsHit;
    $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    for ( ; ; ) {
        my ($cog_id) = $cur->fetchrow();
        last if !$cog_id;
        $cogsHit{$cog_id} = 1;
    }
    $cur->finish();

    # check MER-FS?
    my $check_mer = 0;
    if ( $include_metagenomes && $og eq 'cog' ) {
        for my $cog_id ( keys %cog_h ) {
            if ( $cogsHit{$cog_id} ) {
                next;
            }

            # found one
            $check_mer = 1;
            last;
        }
    }
    if ($check_mer) {
        my $rclause2   = WebUtil::urClause("t");
        my $imgClause2 = WebUtil::imgClause("t");
        $sql = 
            "select t.taxon_oid from taxon t where t.in_file = 'Yes' "
          . "$rclause2 $imgClause2";
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($t_oid) = $cur->fetchrow();
            last if !$t_oid;

            my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'cog' );
            for my $cog_id ( keys %funcs ) {
                $cogsHit{$cog_id} = 1;
            }
        }
        $cur->finish();
    }

    my $baseUrl = "$section_cgi&page=null${OG}PathwayDetail";
    $baseUrl .= "&${og}_pathway_oid=$cog_pathway_oid";

    my $cachedTable =
      new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 1 );
    my $sdDelim = $cachedTable->getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "${OG} ID",   "asc", "left" );
    $cachedTable->addColSpec( "${OG} Name", "asc", "left" );

    my $count = 0;
    for my $cog_id ( keys %cog_h ) {
        my $cog_name = $cog_h{$cog_id};
        next if $cogsHit{$cog_id};
        $count++;

        my $r = $sdDelim
          . "<input type='checkbox' name='${og}_id' value='$cog_id' />\t";
        $r .= "$cog_id\t";
        $r .= "$cog_name\t";
        $cachedTable->addRow($r);
    }

    my $cogPathwayName = cogPathwayName( $dbh, $cog_pathway_oid, $og );
    print "<p>\n";
    print "${OG}'s with no hits for ${OG} Pathway\n";
    print "<i>\n";
    print escHtml($cogPathwayName);
    print "</i>.\n";
    print "</p>\n";

    if ($count) {
        WebUtil::printFuncCartFooter() if $count > 10;
        $cachedTable->printTable();
        WebUtil::printFuncCartFooter();
    }
    else {
        print "<h5>No COGs found.</h5>\n";
    }

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printCcdCogTaxonGenes - Show cog category genes.
############################################################################
sub printCcdCogTaxonGenes {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $function_code = param("function_code");
    my $cog_id        = param("${og}_id");
    my $taxon_oid     = param("taxon_oid");

    my $dbh = dbLogin();
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from ${og}_function cf, ${og}_functions cfs, ${og} c,
          gene_${og}_groups gcg, gene g
       where cf.function_code = cfs.functions
       and cf.function_code = ?
       and c.${og}_id = ?
       and cfs.${og}_id = c.${og}_id
       and c.${og}_id = gcg.${og}
       and gcg.gene_oid = g.gene_oid
       and g.taxon = ?
       and g.locus_type = ?
       and g.obsolete_flag = ?
       order by g.gene_display_name
   };
    my $cur =
      execSql( $dbh, $sql, $verbose, $function_code, $cog_id, $taxon_oid, 'CDS',
        'No' );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    
    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $cog_id</h1>\n";
    printGeneCartFooter() if ( $count > 10 );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printCcdCogOrganistList - Show COG genome listing for COG table
#   selection.
############################################################################
sub printCcdCogGenomeList {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id = param("${og}_id");
    my $gtype  = param('gtype');
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    my $dbh = dbLogin();
    $dbh->{FetchHashKeyName} = 'NAME_lc';
    my $name = cogName( $dbh, $cog_id, $og );

    printMainForm();

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    if ( $gtype eq 'metagenome' ) {
        print "<h1>Metagenomes with $cog_id</h1>\n";
    } else {
        print "<h1>Isolate Genomes with $cog_id</h1>\n";
    }
    print "<p>\n";
    print "Genomes with <i>" . escHtml($name) . "</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $url = "$section_cgi&page=ccd${OG}PhyloDist";
    $url .= "&${og}_id=$cog_id";
    $url .= "&gtype=$gtype";

    WebUtil::buttonMySubmit("Phylogenetic Distribution", "medbutton",
			    'setTaxonFilter', 'setTaxonFilter',
			    $section, "ccd${OG}PhyloDist" );
    print hiddenVar( "${og}_id", $cog_id );
    print hiddenVar( "gtype",   $gtype );    

    printStartWorkingDiv();

    my $domain_clause = "";
    my $andClause = "";
    if ( $gtype eq 'metagenome' ) {
        $domain_clause = " and tx.genome_type = 'metagenome'";
        $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $andClause = " where tx.genome_type = 'metagenome'";
    } else {
        $domain_clause = " and tx.genome_type = 'isolate'";
        $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );
        $andClause = " where tx.genome_type = 'isolate'";
    }

    print "Retrieving genome information from database ... <br/>\n";

    my $sql = qq{
        select tx.domain, tx.seq_status, tx.taxon_oid,
            tx.taxon_display_name, g.gene_count
        from mv_taxon_${og}_stat g, taxon tx
        where g.${og} = ?
        and g.taxon_oid = tx.taxon_oid
        and obsolete_flag = 'No'
        $domain_clause
        $rclause
        $imgClause
        $taxonClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );

    my $baseUrl = "$section_cgi&page=ccd${OG}GenomeList";
    $baseUrl .= "&${og}_id=$cog_id";

    my $cachedTable = new CachedTable( "ccd${OG}Genomes$cog_id", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec("Select");
    $cachedTable->addColSpec( "Domain", "asc", "center", "",
"*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses"
    );
    $cachedTable->addColSpec( "Status", "asc", "center", "",
        "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $cachedTable->addColSpec( "Genome",     "asc",  "left" );
    $cachedTable->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "taxon_filter_oid";
    my $count = 0;
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $gene_cnt )
            = $cur->fetchrow();
        last if !$taxon_oid;

        $count++;

        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";

        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sdDelim
	    . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=ccd${OG}GenomeGeneList";
        $url .= "&${og}_id=$cog_id";
        $url .= "&taxon_oid=$taxon_oid";

        $r .= $gene_cnt . $sdDelim . alink( $url, $gene_cnt ) . "\t";
        $cachedTable->addRow($r);
    }
    $cur->finish();

    if ( $gtype eq 'metagenome' && $og eq 'cog' ) {
        # count MER-FS
        print "<p>Retriving metagenome gene counts ...<br/>\n";

    	my %gene_func_count; 
        if ( $new_func_count ) { 
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
            my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

            my $sql3 = qq{
                select f.taxon_oid, f.gene_count
                from taxon_cog_count f, taxon tx
                where f.func_id = ?
                and f.taxon_oid = tx.taxon_oid
                $rclause2 $imgClause2 $taxonClause2 $domain_clause
            };

            my $cur3 = execSql( $dbh, $sql3, $verbose, $cog_id ); 
            for ( ;; ) { 
                my ( $tid3, $cnt3 ) = $cur3->fetchrow(); 
                last if ! $tid3; 
 
                if ( $gene_func_count{$tid3} ) {
                    $gene_func_count{$tid3} += $cnt3; 
                } 
                else {
                    $gene_func_count{$tid3} = $cnt3;
                } 
            } 
            $cur3->finish();
        } 

        my $rclause2   = WebUtil::urClause("t");
        my $imgClause2 = WebUtil::imgClause("t");
        my $taxonClause2 = WebUtil::txsClause( "t", $dbh );
        my $sql2       = qq{
            select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
            from taxon t
            where t.in_file = 'Yes'
    	    and t.genome_type = 'metagenome'
            $rclause2
            $imgClause2
            $taxonClause2
        };

        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ;; ) {
            my ( $t_oid, $domain, $seq_status, $taxon_display_name ) =
              $cur2->fetchrow();
            last if !$t_oid;

    	    my $cnt = 0;
    	    if ( $new_func_count ) {
		$cnt = $gene_func_count{$t_oid};
    	    } else {
		$cnt = MetaUtil::getTaxonOneFuncCnt( $t_oid, "", $cog_id );
    	    }

            if ($cnt) {
                $domain     = substr( $domain,     0, 1 );
                $seq_status = substr( $seq_status, 0, 1 );
                my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
                $url .= "&taxon_oid=$t_oid";
                my $r;
                $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$t_oid' /> \t";
                $r .= "$domain\t";
                $r .= "$seq_status\t";
                $r .= $taxon_display_name . $sdDelim
		    . alink( $url, $taxon_display_name ) . "\t";

                $url = "$section_cgi&page=ccd${OG}GenomeGeneList";
                $url .= "&${og}_id=$cog_id";
                $url .= "&taxon_oid=$t_oid";
                $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

                $cachedTable->addRow($r);
                $count++;
            }
        }
        $cur2->finish();
    }
    #$dbh->disconnect();

    printEndWorkingDiv();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    
    if ($count > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $cachedTable->printTable();
    WebUtil::printGenomeCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printCcdPhyloDist - Print phylo distribution for COGs/KOGs.
############################################################################
sub printCcdPhyloDist {
    my ($isKOG) = @_;

    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG
    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id = param("${og}_id");
    my $gtype   = param("gtype");
    if ( !$gtype || $gtype eq "") {
        $gtype = 'isolate';
    }

    my $dbh  = dbLogin();
    my $name = cogName( $dbh, $cog_id, $og );

    setLinkTarget("_blank");
    printMainForm();
    print "<h1>Phylogenetic Distribution for $cog_id</h1>\n";

    my $domain_clause = "";
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    print "<p>$OG: ";
    print "<i>".escHtml($name)."</i>";
    if ( $gtype eq 'metagenome' ) {
        $domain_clause = " and tx.genome_type = 'metagenome'";
        print "<br/>*Showing counts for metagenomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all metagenomes"
            if $taxonClause eq "";
    } else {
        print "<br/>*Showing counts for genomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all genomes"
            if $taxonClause eq "";
        $domain_clause = " and tx.genome_type = 'isolate'";
    }
    if ($taxonClause ne "") {
        print "<br/>(User selected genomes with hits are shown in "
            . "<font color=red>red</font>)<br/>\n";
    } else {
        print "<br/>(Hits are shown in <font color=red>red</font>)<br/>\n";
    }
    print "</p>";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my @taxon_oids;
    my %tx2cnt_href;

    print "<p>Retrieving information from database ...<br/>\n";

    my $rclause   = WebUtil::urClause( "tx.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "tx.taxon_oid" );
    my $taxonClause = WebUtil::txsClause( "tx.taxon_oid", $dbh );
    my $sql = qq{
        select tx.taxon_oid, g.gene_count
        from ${og}_function cf, ${og}_functions cfs, ${og} c,
             mv_taxon_${og}_stat g, taxon tx
        where cf.function_code = cfs.functions
        and c.${og}_id = ?
        and cfs.${og}_id = c.${og}_id
        and c.${og}_id = g.${og}
        and g.taxon_oid = tx.taxon_oid
        and tx.obsolete_flag = 'No'
        $rclause
        $imgClause
        $taxonClause
        $domain_clause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        $tx2cnt_href{ $taxon_oid } = $cnt;
        push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();

    if ($gtype eq "metagenome") {
	my $check_merfs = 1;
	if ( !$include_metagenomes ) {
	    $check_merfs = 0;
	}
	if ( $og eq 'kog' ) {
	    $check_merfs = 0;
	}

	if ($check_merfs) {
	    print "<p>Checking metagenomes ...<br/>\n";

	    my %gene_func_count; 
	    if ( $new_func_count ) { 
                my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
                my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
                my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

                my $sql3 = qq{
                    select f.taxon_oid, f.gene_count
                    from taxon_cog_count f, taxon tx
                    where f.func_id = ?
                    and f.taxon_oid = tx.taxon_oid
                    $rclause2 $imgClause2 $taxonClause2 $domain_clause
                };

		my $cur3 = execSql( $dbh, $sql3, $verbose, $cog_id ); 
		for ( ;; ) { 
		    my ( $tid3, $cnt3 ) = $cur3->fetchrow(); 
		    last if ! $tid3; 
		    
		    if ( $gene_func_count{$tid3} ) { 
			$gene_func_count{$tid3} += $cnt3; 
		    } else { 
			$gene_func_count{$tid3} = $cnt3; 
		    } 
		} 
		$cur3->finish(); 
	    } 
	    
            my $tclause = WebUtil::txsClause("t.taxon_oid", $dbh);
            my $sql = MerFsUtil::getTaxonsInFileSql($tclause);
            $sql .= " and t.genome_type = 'metagenome' ";
	    $cur = execSql( $dbh, $sql, $verbose );

	    for ( ;; ) {
		my ($t_oid) = $cur->fetchrow();
		last if !$t_oid;
		
		print ". ";
		
		my $cnt = 0;
		if ( $new_func_count ) { 
		    $cnt = $gene_func_count{$t_oid};
		} else { 
		    $cnt = MetaUtil::getTaxonOneFuncCnt( $t_oid, "", $cog_id );
		}
		
		if ($cnt) {
		    $tx2cnt_href{ $t_oid } = $cnt;
		    push( @taxon_oids, $t_oid );
		}
            }
	    $cur->finish();
	    print "<br/>\n";
        }
    }

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections", \%tx2cnt_href);
    foreach my $tx (@taxon_oids) {
        my $cnt = $tx2cnt_href{ $tx };
        $mgr->setCount($tx, $cnt);
    }

    printEndWorkingDiv();
    #$dbh->disconnect();

    if ($show_private) {
        require TreeQ;
        TreeQ::printAppletForm( \@taxon_oids );
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printCcdCogGenomeGeneList - Show COG genome gene listing for genome
#   selection.
############################################################################
sub printCcdCogGenomeGeneList {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id    = param("${og}_id");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $cog_id );

    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause("t");

    my $sql = 
        "select t.taxon_oid, t.taxon_display_name, t.in_file "
      . "from taxon t where taxon_oid = ? $rclause $imgClause";

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $id2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();
    if ( !$id2 ) {
        #$dbh->disconnect();
        return;
    }

    print "<h1>Genes with $cog_id</h1>\n";
    my $url =
        "$main_cgi?section=TaxonDetail&page=taxonDetail"
      . "&taxon_oid=$taxon_oid";
    print "<p>" . alink( $url, $taxon_name ) . "</p>";

    my $it = new InnerTable( 1, "cogGenes$$", "cogGenes", 1 );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;

    if ( $in_file eq 'Yes' ) {
        # MER-FS
        printStartWorkingDiv();
        print "<p>Retrieving gene information ...<br/>\n";

        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $cog_id );
        my @gene_oids = ( keys %genes );
#        if ( scalar(@gene_oids) > 100 ) {
#            $show_gene_name = 0;
#        }

        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID", "asc", "left" );
        if ($show_gene_name) {
            $it->addColSpec( "Gene Product Name", "asc", "left" );
        }
        $it->addColSpec( "Genome Name", "asc", "left" );

        foreach my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a>\t";

            if ($show_gene_name) {
                my ( $value, $source ) =
                  MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
                $row .= $value . $sd . $value . "\t";
            }

            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a>\t";

            $it->addRow($row);
            $gene_count++;
            print ". ";
            if ( ( $gene_count % 180 ) == 0 ) {
                print "<br/>\n";
            }

            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }

        printEndWorkingDiv();
    }

    else {
        # Oracle DB
        my $rclause   = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my $sql       = qq{
             select distinct g.gene_oid, g.gene_display_name, g.locus_tag
             from ${og}_function cf, ${og}_functions cfs, ${og} c,
                  gene_${og}_groups gcg, gene g
             where cf.function_code = cfs.functions
             and c.${og}_id = '$cog_id'
             and cfs.${og}_id = c.${og}_id
             and c.${og}_id = gcg.${og}
             and gcg.gene_oid = g.gene_oid
             and g.taxon = ?
             and g.locus_type = 'CDS'
             and g.obsolete_flag = 'No'
             $rclause
             $imgClause
        };

        if ( $og eq 'cog' ) {
            $sql = qq{
                 select distinct g.gene_oid, g.gene_display_name, g.locus_tag
                 from gene_cog_groups gcg, gene g
                 where gcg.cog = '$cog_id'
                 and gcg.gene_oid = g.gene_oid
                 and g.taxon = ?
                 and g.locus_type = 'CDS'
                 and g.obsolete_flag = 'No'
                 $rclause
                 $imgClause
            };
        }

        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",           "asc", "left" );
        $it->addColSpec( "Locus Tag",         "asc", "left" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome Name",       "asc", "left" );

        for ( ; ; ) {
            my ( $gene_oid, $gene_name, $locus_tag ) = $cur->fetchrow();
            last if !$gene_oid;
            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
            $row .=
                $gene_oid . $sd
              . "<a href='main.cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid'>"
              . "$gene_oid</a>\t";
            $row .= $locus_tag . $sd . $locus_tag . "\t";
            $row .= $gene_name . $sd . $gene_name . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid'>$taxon_name</a>\t";

            $it->addRow($row);
            $gene_count++;

            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();
    }
    #$dbh->disconnect();

    my $msg = '';
    if ( !$show_gene_name ) {
        $msg .= " Gene names are not displayed. Use 'Expand Gene "
              . "Table Display' option to view detailed gene information.";
        printHint($msg);
    }

    if ($gene_count > 10) {
        printGeneCartFooter();
    }
    $it->printOuterTable(1);
    printGeneCartFooter();
    
    if ( !$show_gene_name ) {
        printHint($msg);
    }

    if ($gene_count > 0) {
        MetaGeneTable::printMetaGeneTableSelect();
	if ( $og eq 'cog' ) {
            print hiddenVar ( 'data_type', 'both' );
            WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
        }
        else {
            WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
        }
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# printCcdSelectScaffolds - Select scaffolds for scaffold Profiler.
############################################################################
sub printCcdSelectScaffolds {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $function_code = param("function_code");

    my $dbh = dbLogin();
    printMainForm();

    print "<h1>Select ${OG} Category Scaffolds</h1>\n";
    print "<p>\n";
    print "Select scaffolds for scaffold profiler.<br/>\n";
    print "Scaffolds > ${min_scaffold_length}bp are candidates.<br/>\n";
    my $catName = cogCategoryName( $dbh, $function_code, $og );
    print "Scaffolds with genes in <i>"
      . escHtml($catName)
      . "</i> are shown.<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $rclause     = WebUtil::urClause("sc.taxon_oid");
    my $taxonClause = WebUtil::txsClause( "sc.taxon_oid", $dbh );
    my $imgClause   = WebUtil::imgClauseNoTaxon("sc.taxon_oid");
    my $sql         = qq{ 
       select sc.scaffold_oid, sc.scaffold_name, sc.taxon_oid,
         sc.taxon_display_name, ss.seq_length
       from dt_scaffold_${og}cat sc, scaffold_stats ss
       where ss.seq_length > ?
       and ss.scaffold_oid = sc.scaffold_oid
       and sc.${og}_function = ?
       $rclause
       $taxonClause
       $imgClause
       order by sc.taxon_display_name, ss.seq_length desc
    };
    my $cur =
      execSql( $dbh, $sql, $verbose, $min_scaffold_length, $function_code );
    my $old_taxon_oid;
    my $count = 0;
    my @recs;

    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name,
            $seq_length )
          = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$seq_length\t";
        push( @recs, $r );
    }
    if ( $count == 0 ) {
        print "<p>\n";
        print "No scaffolds found for the current context.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $count = 0;
    print "<p>\n";
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Select</th>\n";
    print "<th class='img' >Scaffold Name</th>\n";
    print "<th class='img' >Sequence<br/>Length (bp)</th>\n";
    for my $r (@recs) {
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name,
            $seq_length )
          = split( /\t/, $r );
        $count++;
        if ( $old_taxon_oid ne "" && $old_taxon_oid ne $taxon_oid ) {
            print "<tr class='img' >\n";
            print "<td class='img' ></td>\n";
            print "<td class='img' >&nbsp;</td>\n";
            print "<td class='img' >&nbsp;</td>\n";
            print "</tr>\n";
        }
        print "<tr class='img' >\n";
        print "<td class='checkbox'>\n";
        print
"<input type='checkbox' name='scaffold_oid' value='$scaffold_oid' />\n";
        print "</td>\n";
        my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
        $url .= "&scaffold_oid=$scaffold_oid";
        $url .= "&start_coord=1";
        my $end_coord = $scaffold_page_size;
        $end_coord = $seq_length if $seq_length < $scaffold_page_size;
        $url .= "&end_coord=$end_coord";
        $url .= "&seq_length=$seq_length";
        print "<td class='img' >" . alink( $url, $scaffold_name ) . "</td>\n";
        print "<td class='img'  align='right'>$seq_length</td>\n";
        print "</tr>\n";
        $old_taxon_oid = $taxon_oid;
    }
    $cur->finish();
    print "</table>\n";
    print "</p>\n";

    print hiddenVar( "function_code", $function_code );

    print "<br/>\n";
    my $name = "_section_${section}_ccd${OG}ViewScaffoldProfile";
    print submit(
        -name  => $name,
        -value => "Continue",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    printStatusLine( "$count scaffold(s) retrieved.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printCpdSelectScaffolds - Select scaffolds for scaffold Profiler.
#   "Cpd" = COG pathway detail
############################################################################
sub printCpdSelectScaffolds {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_pathway_oid = param("${og}_pathway_oid");

    my $dbh = dbLogin();
    printMainForm();

    print "<h1>Select ${OG} Pathway Scaffolds</h1>\n";
    print "<p>\n";
    print "Select scaffolds for scaffold profiler.<br/>\n";
    print "Scaffolds > ${min_scaffold_length}bp are candidates.<br/>\n";
    my $catName = cogPathwayName( $dbh, $cog_pathway_oid, $og );
    print "Scaffolds with genes in <i>"
      . escHtml($catName)
      . "</i> are shown.<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $rclause     = WebUtil::urClause("sc.taxon_oid");
    my $taxonClause = WebUtil::txsClause( "sc.taxon_oid", $dbh );
    my $imgClause   = WebUtil::imgClauseNoTaxon("sc.taxon_oid");
    my $sql         = qq{  
        select sc.scaffold_oid, sc.scaffold_name, sc.taxon_oid,
               sc.taxon_display_name, ss.seq_length
        from dt_scaffold_${og}path sc, scaffold_stats ss
        where ss.seq_length > ?
        and ss.scaffold_oid = sc.scaffold_oid
        and sc.${og}_pathway_oid = ?
        $rclause
        $taxonClause
        $imgClause
        order by sc.taxon_display_name, ss.seq_length desc
    };
    my $cur =
      execSql( $dbh, $sql, $verbose, $min_scaffold_length, $cog_pathway_oid );
    my $old_taxon_oid;
    my $count = 0;
    my @recs;

    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name,
            $seq_length )
          = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;

        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$seq_length\t";
        push( @recs, $r );
    }
    if ( $count == 0 ) {
        print "<p>\n";
        print "No scaffolds found for the current context.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $count = 0;
    print "<p>\n";
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Select</th>\n";
    print "<th class='img' >Scaffold Name</th>\n";
    print "<th class='img' >Sequence<br/>Length (bp)</th>\n";
    for my $r (@recs) {
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name,
            $seq_length )
          = split( /\t/, $r );
        $count++;
        if ( $old_taxon_oid ne "" && $old_taxon_oid ne $taxon_oid ) {
            print "<tr class='img' >\n";
            print "<td class='img' ></td>\n";
            print "<td class='img' >&nbsp;</td>\n";
            print "<td class='img' >&nbsp;</td>\n";
            print "</tr>\n";
        }
        print "<tr class='img' >\n";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' name='scaffold_oid' value='$scaffold_oid' />\n";
        print "</td>\n";
        my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
        $url .= "&scaffold_oid=$scaffold_oid";
        $url .= "&start_coord=1";
        my $end_coord = $scaffold_page_size;
        $end_coord = $seq_length if $seq_length < $scaffold_page_size;
        $url .= "&end_coord=$end_coord";
        $url .= "&seq_length=$seq_length";
        print "<td class='img' >" . alink( $url, $scaffold_name ) . "</td>\n";
        print "<td class='img'  align='right'>$seq_length</td>\n";
        print "</tr>\n";
        $old_taxon_oid = $taxon_oid;
    }
    $cur->finish();
    print "</table>\n";
    print "</p>\n";

    print hiddenVar( "${og}_pathway_oid", $cog_pathway_oid );

    print "<br/>\n";
    my $name = "_section_${section}_cpd${OG}ViewScaffoldProfile";
    print submit(
        -name  => $name,
        -value => "Continue",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    printStatusLine( "$count scaffold(s) retrieved.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printCcdScaffoldProfile - Show COG category profile.
############################################################################
sub printCcdScaffoldProfile {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $function_code = param("function_code");

    my @scaffold_oids = param("scaffold_oid");
    my $scaffold_selection_str = join( ',', @scaffold_oids );
    if ( blankStr($scaffold_selection_str) ) {
        webError("Please select scaffolds for profiling.");
    }
    my $nScaffolds = @scaffold_oids;
    if ( $nScaffolds < 1 ) {
        webError("Please select at least one scaffold.");
    }
    if ( $nScaffolds > $max_scaffold_batch ) {
        webError( "Please select from one to a maximum of "
              . "$max_scaffold_batch scaffolds." );
    }
    my $dbh        = dbLogin();
    my $cogCatName = cogCategoryName( $dbh, $function_code, $og );

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<h1>${OG} Category Scaffold Profile</h1>\n";

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $sql       = qq{
        select scf.scaffold_oid, scf.scaffold_name
        from scaffold scf, taxon tx
        where scf.scaffold_oid in( $scaffold_selection_str )
        and scf.taxon = tx.taxon_oid
        $rclause
        $imgClause
        order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
        tx.family, tx.genus, tx.taxon_display_name
    };

    my @scaffoldRecs;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        push( @scaffoldRecs, $r );
    }
    $cur->finish();

    my $rclause     = WebUtil::urClause("g.taxon");
    my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh );
    my $imgClause   = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql         = qq{
        select c.${og}_id, c.${og}_name, g.scaffold, 
               count( distinct g.gene_oid )
        from ${og}_function cf, ${og}_functions cfs, ${og} c,
             gene_${og}_groups gcg, gene g
        where cf.function_code = cfs.functions
        and cf.function_code = ?
        and cfs.${og}_id = c.${og}_id
        and c.${og}_id = gcg.${og}
        and gcg.gene_oid = g.gene_oid
        and g.scaffold in( $scaffold_selection_str )
        and g.locus_type = ?
        and g.obsolete_flag = ?
        $rclause
        $taxonClause
        $imgClause
        group by c.${og}_id, c.${og}_name, g.scaffold
        order by c.${og}_id, c.${og}_name, g.scaffold
    };
    my %cogScaffold2GeneCount;
    my $cur = execSql( $dbh, $sql, $verbose, $function_code, 'CDS', 'No' );
    for ( ; ; ) {
        my ( $cog_id, $cog_name, $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        my $k = "$cog_id\t$scaffold_oid";
        $cogScaffold2GeneCount{$k} = $cnt;
    }
    $cur->finish();

    my @colSpec;
    push(
        @colSpec,
        {
            displayColName => "${OG} ID",
            sortSpec       => "char asc",
            align          => "left",
        }
    );
    push(
        @colSpec,
        {
            displayColName => "${OG} Name",
            sortSpec       => "char asc",
            align          => "left",
        }
    );
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $r );
        my $colName = abbrScaffoldName( $scaffold_oid, $scaffold_name, 1 );
        push(
            @colSpec,
            {
                displayColName => $colName,
                sortSpec       => "number desc",
                align          => "right",
                title          => $scaffold_name,
                useColorMap    => 1,
            }
        );
    }
    my $baseUrl = "$section_cgi&ccd${OG}ViewScaffoldProfile=1";
    $baseUrl .= "&function_code=$function_code";
    for my $scaffold_oid (@scaffold_oids) {
        $baseUrl .= "&scaffold_oid=$scaffold_oid";
    }
    my @colorMap = ( "1:5:bisque", "5:1000000:yellow", );
    my $cachedTable =
      new CachedTable( "ccdScaffold$function_code", $baseUrl, \@colSpec,
        \@colorMap );
    my $sdDelim = CachedTable::getSdDelim();
    my $sql     = qq{
        select c.${og}_id, c.${og}_name, count( distinct g.gene_oid )
        from ${og}_function cf, ${og}_functions cfs, ${og} c,
             gene_${og}_groups gcg, gene g
        where cf.function_code = cfs.functions
        and cf.function_code = ?
        and cfs.${og}_id = c.${og}_id
        and c.${og}_id = gcg.${og}
        and gcg.gene_oid = g.gene_oid
        and g.scaffold in( $scaffold_selection_str )
        and g.obsolete_flag = ?
        $rclause
        $taxonClause
        $imgClause
        group by c.${og}_id, c.${og}_name
        order by c.${og}_id, c.${og}_name
    };
    my $cur   = execSql( $dbh, $sql, $verbose, $function_code, 'No' );
    my $count = 0;

    for ( ; ; ) {
        my ( $cog_id, $cog_name, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        $count++;

        my $r = "$cog_id\t";
        $r .= "$cog_name\t";
        for my $scaffoldRec (@scaffoldRecs) {
            my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $scaffoldRec );
            my $k   = "$cog_id\t$scaffold_oid";
            my $cnt = $cogScaffold2GeneCount{$k};
            $cnt = 0 if $cnt eq "";
            my $color = "white";
            $color = "bisque" if $cnt >= 1 && $cnt < 5;
            $color = "yellow" if $cnt >= 5;

            if ( $cnt > 0 ) {
                my $url = "$section_cgi&page=ccd${OG}ScaffoldGenes";
                $url .= "&function_code=$function_code";
                $url .= "&${og}_id=$cog_id";
                $url .= "&scaffold_oid=$scaffold_oid";
                $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
            }
            else {
                $r .= "0\t";
            }
        }
        $cachedTable->addRow($r);
    }
    $cur->finish();

    if ( $count == 0 ) {
        print "<p>\n";
        print "No ${OG}s match the profile.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
    print "<p>\n";
    print "${OG} category profile for <i>"
      . escHtml($cogCatName)
      . "</i> with $nScaffolds scaffolds.\n";
    print "<br/>\n";
    print "The count of genes is shown under the genome abbreviation.\n";
    print "<br/>\n";
    print "(Larger numbers have brighter cell coloring.)<br/>\n";
    print "</p>\n";

    printHint("Mouse over scaffold abbreviation to see scaffold name.");
    $cachedTable->printTable();
    #$dbh->disconnect();

    print "<br/>\n";
    my $url = "$section_cgi&page=cogCategoryDetail";
    $url .= "&function_code=$function_code";
    print buttonUrl( $url, "Start ${OG} Category Detail Again", "lgbutton" );
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printCpdScaffoldProfile - Show COG category profile.
############################################################################
sub printCpdScaffoldProfile {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_pathway_oid = param("${og}_pathway_oid");

    my @scaffold_oids = param("scaffold_oid");
    my $scaffold_selection_str = join( ',', @scaffold_oids );
    if ( blankStr($scaffold_selection_str) ) {
        webError("Please select scaffolds for profiling.");
    }
    my $nScaffolds = @scaffold_oids;
    if ( $nScaffolds < 1 ) {
        webError("Please select at least one scaffold.");
    }
    if ( $nScaffolds > $max_scaffold_batch ) {
        webError( "Please select from one to a maximum of "
              . "$max_scaffold_batch scaffolds." );
    }
    my $dbh        = dbLogin();
    my $cogCatName = cogPathwayName( $dbh, $cog_pathway_oid, $og );

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<h1>${OG} Pathway Scaffold Profile</h1>\n";

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $sql       = qq{
        select scf.scaffold_oid, scf.scaffold_name
        from scaffold scf, taxon tx
        where scf.scaffold_oid in( $scaffold_selection_str )
        and scf.taxon = tx.taxon_oid
        $rclause
        $imgClause
        order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
        tx.family, tx.genus, tx.taxon_display_name
    };

    my @scaffoldRecs;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        push( @scaffoldRecs, $r );
    }
    $cur->finish();

    my $rclause     = WebUtil::urClause("g.taxon");
    my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh );
    my $imgClause   = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql         = qq{
        select c.${og}_id, c.${og}_name, g.scaffold,
               count( distinct g.gene_oid )
        from ${og}_pathway_${og}_members cm, ${og} c,
             gene_${og}_groups gcg, gene g
        where cm.${og}_pathway_oid = ?
        and cm.${og}_members = c.${og}_id
        and c.${og}_id = gcg.${og}
        and gcg.gene_oid = g.gene_oid
        and g.scaffold in( $scaffold_selection_str )
        and g.locus_type = ?
        and g.obsolete_flag = ?
        $rclause
        $taxonClause
        $imgClause
        group by c.${og}_id, c.${og}_name, g.scaffold
        order by c.${og}_id, c.${og}_name, g.scaffold
    };
    my %cogScaffold2GeneCount;
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid, 'CDS', 'No' );
    for ( ; ; ) {
        my ( $cog_id, $cog_name, $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        my $k = "$cog_id\t$scaffold_oid";
        $cogScaffold2GeneCount{$k} = $cnt;
    }
    $cur->finish();

    my @colSpec;
    push(
        @colSpec,
        {
            displayColName => "${OG} ID",
            sortSpec       => "char asc",
            align          => "left",
        }
    );
    push(
        @colSpec,
        {
            displayColName => "${OG} Name",
            sortSpec       => "char asc",
            align          => "left",
        }
    );
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $r );
        my $colName = abbrScaffoldName( $scaffold_oid, $scaffold_name, 1 );
        push(
            @colSpec,
            {
                displayColName => $colName,
                sortSpec       => "number desc",
                align          => "right",
                title          => $scaffold_name,
                useColorMap    => 1,
            }
        );
    }
    my $baseUrl = "$section_cgi&cpd${OG}ViewScaffoldProfile=1";
    $baseUrl .= "&${og}_pathway_oid=$cog_pathway_oid";
    for my $scaffold_oid (@scaffold_oids) {
        $baseUrl .= "&scaffold_oid=$scaffold_oid";
    }
    my @colorMap = ( "1:5:bisque", "5:1000000:yellow", );
    my $cachedTable =
      new CachedTable( "cpdScaffold$cog_pathway_oid", $baseUrl, \@colSpec,
        \@colorMap );
    my $sdDelim = CachedTable::getSdDelim();
    my $sql     = qq{
        select c.${og}_id, c.${og}_name, count( distinct g.gene_oid )
        from ${og}_pathway_${og}_members cm, ${og} c,
             gene_${og}_groups gcg, gene g
        where cm.${og}_pathway_oid = ?
        and cm.${og}_members = c.${og}_id
        and c.${og}_id = gcg.${og}
        and gcg.gene_oid = g.gene_oid
        and g.scaffold in( $scaffold_selection_str )
        and g.obsolete_flag = ?
        $rclause
        $taxonClause
        $imgClause
        group by c.${og}_id, c.${og}_name
        order by c.${og}_id, c.${og}_name
    };
    my $cur   = execSql( $dbh, $sql, $verbose, $cog_pathway_oid, 'No' );
    my $count = 0;

    for ( ; ; ) {
        my ( $cog_id, $cog_name, $cnt ) = $cur->fetchrow();
        last if !$cog_id;
        $count++;

        my $r = "$cog_id\t";
        $r .= "$cog_name\t";
        for my $scaffoldRec (@scaffoldRecs) {
            my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $scaffoldRec );
            my $k   = "$cog_id\t$scaffold_oid";
            my $cnt = $cogScaffold2GeneCount{$k};
            $cnt = 0 if $cnt eq "";
            my $color = "white";
            $color = "bisque" if $cnt >= 1 && $cnt < 5;
            $color = "yellow" if $cnt >= 5;

            if ( $cnt > 0 ) {
                my $url = "$section_cgi&page=cpd${OG}ScaffoldGenes";
                $url .= "&${og}_pathway_oid=$cog_pathway_oid";
                $url .= "&${og}_id=$cog_id";
                $url .= "&scaffold_oid=$scaffold_oid";
                $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
            }
            else {
                $r .= "0\t";
            }
        }
        $cachedTable->addRow($r);
    }
    $cur->finish();

    if ( $count == 0 ) {
        print "<p>\n";
        print "No ${OG}s match the profile.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
    print "<p>\n";
    print "${OG} category profile for <i>"
      . escHtml($cogCatName)
      . "</i> with $nScaffolds scaffolds.\n";
    print "<br/>\n";
    print "The count of genes is shown under the genome abbreviation.\n";
    print "<br/>\n";
    print "(Larger numbers have brighter cell coloring.)<br/>\n";
    print "</p>\n";

    printHint("Mouse over scaffold abbreviation to see scaffold name.");
    $cachedTable->printTable();
    #$dbh->disconnect();

    print "<br/>\n";
    my $url = "$section_cgi&page=${og}PathwayDetail";
    $url .= "&${og}_pathway_oid=$cog_pathway_oid";
    print buttonUrl( $url, "Start ${OG} Pathway Detail Again", "lgbutton" );
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printCcdCogScaffoldGenes - Show cog category genes.
############################################################################
sub printCcdCogScaffoldGenes {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $function_code = param("function_code");
    my $cog_id        = param("${og}_id");
    my $scaffold_oid  = param("scaffold_oid");

    my $dbh = dbLogin();
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from ${og}_function cf, ${og}_functions cfs, ${og} c,
          gene_${og}_groups gcg, gene g
       where cf.function_code = cfs.functions
       and cf.function_code = ?
       and c.${og}_id = ?
       and cfs.${og}_id = c.${og}_id
       and c.${og}_id = gcg.${og}
       and gcg.gene_oid = g.gene_oid
       and g.scaffold = ?
       and g.locus_type = ?
       and g.obsolete_flag = ?
       order by g.gene_display_name
   };
    my $cur =
      execSql( $dbh, $sql, $verbose, $function_code, $cog_id, $scaffold_oid,
        'CDS', 'No' );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $cog_id</h1>\n";
    printGeneCartFooter() if ( $count > 10 );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printCpdCogScaffoldGenes - Show cog category genes.
############################################################################
sub printCpdCogScaffoldGenes {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_pathway_oid = param("${og}_pathway_oid");
    my $cog_id          = param("${og}_id");
    my $scaffold_oid    = param("scaffold_oid");

    my $dbh = dbLogin();
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from ${og}_pathway_${og}_members cm, ${og} c,
          gene_${og}_groups gcg, gene g
       where cm.${og}_pathway_oid = ?
       and c.${og}_id = ?
       and cm.${og}_members = c.${og}_id
       and c.${og}_id = gcg.${og}
       and gcg.gene_oid = g.gene_oid
       and g.scaffold = ?
       and g.locus_type = ?
       and g.obsolete_flag = ?
       order by g.gene_display_name
   };
    my $cur =
      execSql( $dbh, $sql, $verbose, $cog_pathway_oid, $cog_id, $scaffold_oid,
        'CDS', 'No' );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $cog_id</h1>\n";
    printGeneCartFooter() if ($count > 10);
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

1;
