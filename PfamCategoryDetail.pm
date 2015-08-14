############################################################################
# PfamCategoryDetail.pm - category detail for a Pfam using Pfam categories.
#  "Pcd" = Pfam category detail, relic from days before this code
#     was put into perl modules.
#    --es 10/06/2007
#
# $Id: PfamCategoryDetail.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package PfamCategoryDetail;
my $section = "PfamCategoryDetail";

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
my $pfam_base_url        = $env->{pfam_base_url};
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
    my $sid  = getContactOid();
    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "pfamCategoryDetail" ) {
        printPfamCategoryDetail();
    } elsif ( $page eq "pfamPathwayDetail" ) {
        printPfamPathwayDetail();
    } elsif ( $page eq "pcdPfamGenomeList" ) {
        printPcdPfamGenomeList();
    } elsif ( $page eq "pcdPhyloDist" ) {
        printPcdPhyloDist();
    } elsif ( $page eq "pcdPfamGenomeGeneList" ) {
        printPcdPfamGenomeGeneList();
    } elsif ( $page eq "pcdPfamTaxonGenes" ) {
        printPcdPfamTaxonGenes();
    } else {
        printPfamCategoryDetail();
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
# printPfamCategoryDetail - Show detail page for Pfam category.
############################################################################
sub printPfamCategoryDetail {
    my $function_code = param("function_code");

    timeout( 60 * $merfs_timeout_mins );

    printMainForm();
    print "<h1>Pfam Category Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();

    print "<p>Retrieving Pfam Category information ...\n";
    my %allPfams;
    my $sql = qq{
        select pf.ext_accession, pf.description, pf.name
        from pfam_family_cogs pfc, pfam_family pf
        where pfc.functions = ?
        and pfc.ext_accession = pf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $pfam_id, $pfam_name, $name2 ) = $cur->fetchrow();
        last if !$pfam_id;
        if ( !$pfam_name ) {
            $pfam_name = $name2;
        }
        $allPfams{$pfam_id} = $pfam_name;
    }
    $cur->finish();

    my %pfam_cnts;
    my %m_pfam_cnts;

    print "<p>Counting isolate genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );
    my $rclause     = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause   = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );
    $sql = qq{
       select g.pfam_family, count( distinct g.taxon_oid )
       from mv_taxon_pfam_stat g, pfam_family_cogs pfc 
       where pfc.functions = ?
       and pfc.ext_accession = g.pfam_family
       $taxonClause
       $rclause
       $imgClause
       group by g.pfam_family
   };
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $ext_accession, $cnt ) = $cur->fetchrow();
        last if !$ext_accession;
        $pfam_cnts{$ext_accession} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
           select g.pfam_family, count( distinct g.taxon_oid )
           from mv_taxon_pfam_stat g, pfam_family_cogs pfc 
           where pfc.functions = ?
           and pfc.ext_accession = g.pfam_family
           $taxonClause
           $rclause
           $imgClause
           group by g.pfam_family
       };
        $cur = execSql( $dbh, $sql, $verbose, $function_code );
        for ( ; ; ) {
            my ( $ext_accession, $cnt ) = $cur->fetchrow();
            last if !$ext_accession;
            $m_pfam_cnts{$ext_accession} = $cnt;
        }
        $cur->finish();

        if ($new_func_count) {
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
    	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

            print "<br/>\n";
            foreach my $pfam_id ( sort ( keys %allPfams ) ) {
                print "Retrieving counts for $pfam_id ...<br/>\n";

                $sql = qq{
                     select count(distinct f.taxon_oid)
                     from taxon_pfam_count f
                     where f.gene_count > 0
                     and f.func_id = ? 
                     $rclause2 
                     $imgClause2 
                     $taxonClause2
                };

                $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
                my ($t_cnt) = $cur->fetchrow();
        		next if !$t_cnt;

                if ( $m_pfam_cnts{$pfam_id} ) {
                    $m_pfam_cnts{$pfam_id} += $t_cnt;
                } else {
                    $m_pfam_cnts{$pfam_id} = $t_cnt;
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
                my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'pfam' );
                for my $pfam_id ( keys %funcs ) {
                    if ( $m_pfam_cnts{$pfam_id} ) {
                        $m_pfam_cnts{$pfam_id} += 1;
                    } else {
                        $m_pfam_cnts{$pfam_id} += 1;
                    }
                }
            }
            $cur->finish();
            print "<br/>\n";
        }
    }

    printEndWorkingDiv();

    my $baseUrl = "$section_cgi&page=pfamCategoryDetail";
    $baseUrl .= "&function_code=$function_code";

    my $hasIsolates = scalar (keys %pfam_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_pfam_cnts) > 0 ? 1 : 0;

    my $cachedTable = new CachedTable( "pfamCat$function_code", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "Pfam ID",   "asc", "left" );
    $cachedTable->addColSpec( "Pfam Name", "asc", "left" );
    if ($include_metagenomes) {
        $cachedTable->addColSpec( "Isolate<br/>Genome Count", "asc", "right" )
	    if $hasIsolates;
        $cachedTable->addColSpec( "Metagenome<br/>Count", "asc", "right" )
	    if $hasMetagenomes;
    } else {
        $cachedTable->addColSpec( "Genome<br/>Count", "asc", "right" )
	    if $hasIsolates;
    }

    my $select_id_name = "func_id";
    my $count = 0;
    foreach my $pfam_id ( keys %allPfams ) {
        my $name = $allPfams{$pfam_id};
        $count++;
        my $r = $sdDelim . "<input type='checkbox' "
	                 . "name='$select_id_name' value='$pfam_id' />\t";
        my $pfam_id2 = $pfam_id;
        $pfam_id2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$pfam_id2";
        $r .= "$pfam_id" . $sdDelim . alink( $url, $pfam_id ) . "\t";
        $r .= "$name\t";

        my $cnt = $pfam_cnts{$pfam_id};
        if ($hasIsolates) {
    	    if ($cnt) {
        		my $url = "$section_cgi&page=pcdPfamGenomeList";
        		$url .= "&pfam_id=$pfam_id&gtype=isolate";
        		$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
    	    } else {
        		$r .= "0" . $sdDelim . "0" . "\t";
    	    }
    	}

        if ($include_metagenomes) {
            my $m_cnt = $m_pfam_cnts{$pfam_id};
            if ($hasMetagenomes) {
        		if ($m_cnt) {
        		    my $m_url = "$section_cgi&page=pcdPfamGenomeList";
        		    $m_url .= "&pfam_id=$pfam_id&gtype=metagenome";
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
        print "No Pfams found for current genome selections.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $pfamCatName = cogCategoryName( $dbh, $function_code );
    #$dbh->disconnect();

    print "<p>";
    print "Details for Pfam Category: ";
    print "<i>".escHtml($pfamCatName)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only" 
	if $taxonClause ne "";
    print "</p>";

    WebUtil::printFuncCartFooter() if $count > 10;
    $cachedTable->printTable();
    WebUtil::printFuncCartFooter();

    printHint("The function cart allows for phylogenetic profile comparisons.");

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    #   if( hasOneValue( \%allPfams ) ) {
    #       my $url = "$section_cgi&page=nullPfamCategoryDetail";
    #       $url .= "&function_code=$function_code";
    #       print "<p>\n";
    #       print alink( $url, "Pfam's with no hits" );
    #       print "</p>\n";
    #   }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printPfamPathwayDetail - Show detail page for Pfam category.
############################################################################
sub printPfamPathwayDetail {
    my $cog_pathway_oid = param("cog_pathway_oid");

    printMainForm();
    print "<h1>Pfam Pathway Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    #print "<p>start time: " . currDateTime() . "\n";
    print "<p>Retrieving Pfam Pathway information ...\n";

    my $dbh = dbLogin();

    my %allPfams;
    my $sql = qq{
        select distinct pfc.ext_accession, pf.description
        from cog_pathway_cog_members cm, 
             pfam_family_cogs pfc, pfam_family pf
        where cm.cog_pathway_oid = ?
        and cm.cog_members = pfc.cog
        and pfc.ext_accession = pf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    for ( ;; ) {
        my ( $pfam_id, $pfam_name ) = $cur->fetchrow();
        last if !$pfam_id;
        $allPfams{$pfam_id} = $pfam_name;
    }
    $cur->finish();
    
    my @allPfamIds = sort ( keys %allPfams );
    
    my %pfam_cnts;
    my %m_pfam_cnts;

    print "<p>Counting isolate genomes ...\n";

    my $pfamIds_str = OracleUtil::getFuncIdsInClause( $dbh, @allPfamIds );
        
    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );
    my $rclause     = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause   = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );

    $sql = qq{
       select g.pfam_family, count( distinct g.taxon_oid )
       from mv_taxon_pfam_stat g
       where g.pfam_family in ( $pfamIds_str )
       $taxonClause
       $rclause
       $imgClause
       group by g.pfam_family
    };
    $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $pfam_id, $cnt ) = $cur->fetchrow();
        last if !$pfam_id;
        $pfam_cnts{$pfam_id} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes in database ...\n";

        $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
           select g.pfam_family, count( distinct g.taxon_oid )
           from mv_taxon_pfam_stat g
           where g.pfam_family in ( $pfamIds_str )
           $taxonClause
           $rclause
           $imgClause
           $taxonClause
           group by g.pfam_family
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $pfam_id, $cnt ) = $cur->fetchrow();
            last if !$pfam_id;
            $m_pfam_cnts{$pfam_id} = $cnt;
        }
        $cur->finish();
    }

    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
	if ( $pfamIds_str =~ /gtt_func_id/i );        
    
    if ($include_metagenomes) {
        print "<p>Counting metagenome genes in file system ...<br/>\n";

        if ($new_func_count) {
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

            foreach my $pfam_id ( @allPfamIds ) {
                print "Retrieving gene count for $pfam_id ...<br/>\n";

                $sql = qq{
                     select count(distinct f.taxon_oid)
                     from taxon_pfam_count f
                     where f.gene_count > 0  
                     and f.func_id = ?
                     $rclause2
                     $imgClause2
                     $taxonClause2
                };

                $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
                my ($t_cnt) = $cur->fetchrow();
		next if !$t_cnt;

                if ( $m_pfam_cnts{$pfam_id} ) {
                    $m_pfam_cnts{$pfam_id} += $t_cnt;
                } else {
                    $m_pfam_cnts{$pfam_id} = $t_cnt;
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
                my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'pfam' );
                for my $pfam_id ( keys %funcs ) {
                    if ( $allPfams{$pfam_id} ) {
                        if ( $m_pfam_cnts{$pfam_id} ) {
                            $m_pfam_cnts{$pfam_id} += 1;
                        } else {
                            $m_pfam_cnts{$pfam_id} = 1;
                        }
                    }
                }
            }
            $cur->finish();
            print "<br/>\n";
        }
    }

    #print "<p>end time: " . currDateTime() . "\n";

    my $baseUrl = "$section_cgi&page=pfamPathwayDetail";
    $baseUrl .= "&cog_pathway_oid=$cog_pathway_oid";

    my $hasIsolates = scalar (keys %pfam_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_pfam_cnts) > 0 ? 1 : 0;

    my $cachedTable = new CachedTable( "pfamPway$cog_pathway_oid", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec("Select");
    $cachedTable->addColSpec( "Pfam ID",   "asc", "left" );
    $cachedTable->addColSpec( "Pfam Name", "asc", "left" );
    if ($include_metagenomes) {
        $cachedTable->addColSpec( "Isolate<br/>Genome Count", "desc", "right" )
	    if $hasIsolates;
        $cachedTable->addColSpec( "Metagenome<br/>Count", "desc", "right" )
	    if $hasMetagenomes;
    } else {
        $cachedTable->addColSpec( "Genome<br/>Count", "desc", "right" )
	    if $hasIsolates;
    }

    my $select_id_name = "func_id";
    my $count = 0;
    for my $pfam_id ( @allPfamIds ) {
        my $pfam_name = $allPfams{$pfam_id};
        $count++;
        my $r  = $sdDelim . "<input type='checkbox' "
	                  . "name='$select_id_name' value='$pfam_id' />\t";
        my $pfam_id2 = $pfam_id;
        $pfam_id2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$pfam_id2";
        $r .= "$pfam_id" . $sdDelim . alink( $url, $pfam_id ) . "\t";
        $r .= "$pfam_name\t";
        my $cnt = $pfam_cnts{$pfam_id};

        if ($hasIsolates) {
	    if ($cnt) {
		my $url = "$section_cgi&page=pcdPfamGenomeList";
		$url .= "&pfam_id=$pfam_id&gtype=isolate";
		$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
	    }
	}

        if ($include_metagenomes) {
            my $m_cnt = $m_pfam_cnts{$pfam_id};
            if ($hasMetagenomes) {
		if ($m_cnt) {
		    my $m_url = "$section_cgi&page=pcdPfamGenomeList";
		    $m_url .= "&pfam_id=$pfam_id&gtype=metagenome";
		    $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
		}
	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
	    }
	}

        $cachedTable->addRow($r);
    }
    $cur->finish();

    printEndWorkingDiv();

    if ( $count == 0 ) {
        #$dbh->disconnect();
        print "<p>\n";
        print "No Pfams found for current genome selections.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $cogPathwayName = cogPathwayName( $dbh, $cog_pathway_oid );
    #$dbh->disconnect();

    print "<p>";
    print "Details for Pfam Pathway: ";
    print "<i>".escHtml($cogPathwayName)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only." 
	if $taxonClause ne "";
    print "</p>";

    WebUtil::printFuncCartFooter() if $count > 10;
    $cachedTable->printTable();
    WebUtil::printFuncCartFooter();

    printHint("The function cart allows for phylogenetic profile comparisons.");

    ## save to workspace
    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    #   if( hasOneValue( \%allPfams ) ) {
    #       my $url = "$section_cgi&page=nullPfamPathwayDetail";
    #       $url .= "&cog_pathway_oid=$cog_pathway_oid";
    #       print "<p>\n";
    #       print alink( $url, "Pfam's with no hits" );
    #       print "</p>\n";
    #   }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printPcdPfamTaxonGenes - Show pfam category genes.
############################################################################
sub printPcdPfamTaxonGenes {
    my $function_code = param("function_code");
    my $pfam_id       = param("pfam_id");
    my $taxon_oid     = param("taxon_oid");

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select distinct g.gene_oid, g.gene_display_name
       from pfam_family_cogs pfc, 
           gene_pfam_families gpf, gene g
       where pfc.functions = ?
           and pfc.ext_accession = ?
           and pfc.ext_accession = gcg.pfam_family
           and gpf.gene_oid = g.gene_oid
           and g.taxon = ?
           and g.locus_type = 'CDS'
           and g.obsolete_flag = 'No'
           $rclause
           $imgClause
       order by g.gene_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code, $pfam_id, $taxon_oid );
    my @gene_oids;
    for ( ;; ) {
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

    print "<h1>Genes for $pfam_id</h1>\n";
    printGeneCartFooter() if $count > 10;
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printPcdPfamOrganistList - Show Pfam genome listing for Pfam table
#   selection.
############################################################################
sub printPcdPfamGenomeList {
    my $pfam_id = param("pfam_id");
    my $noCat   = param("nocat");     # no cat.
    my $gtype   = param("gtype");
    if ( !$gtype ) {
        $gtype = 'isolate';
    }
    my $dbh  = dbLogin();
    my $name = pfamName( $dbh, $pfam_id );

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    if ( $gtype eq 'metagenome' ) {
        print "<h1>Metagenomes with $pfam_id</h1>\n";
    } else {
        print "<h1>Isolate Genomes with $pfam_id</h1>\n";
    }
    print "<p>\n";
    print "Genomes with <i>" . escHtml($name) . "</i>";
    print "<br/>*Showing counts for genomes in genome cart only" 
	if $taxonClause ne "";
    print "</p>\n";

    my $url = "$section_cgi&page=pcdPhyloDist";
    $url .= "&pfam_id=$pfam_id";
    $url .= "&nocat=$noCat" if ( $noCat eq 'yes' );
    $url .= "&gtype=$gtype";

    WebUtil::buttonMySubmit("Phylogenetic Distribution", "medbutton",
			    'setTaxonFilter', 'setTaxonFilter',
			    'PfamCategoryDetail', 'pcdPhyloDist' );
    print hiddenVar( "pfam_id", $pfam_id );
    print hiddenVar( "nocat",   $noCat );
    print hiddenVar( "gtype",   $gtype );

    printStartWorkingDiv();

    my $domain_clause = "";
    if ( $gtype eq 'metagenome' ) {
        $domain_clause = " and tx.genome_type = 'metagenome'";
    } else {
        $domain_clause = " and tx.genome_type = 'isolate'";
    }

    print "<p>Retriving gene counts from database ...<br/>\n";

    my $sql = qq{
        select tx.domain, tx.seq_status, tx.taxon_oid, 
            tx.taxon_display_name, g.gene_count
        from mv_taxon_pfam_stat g, taxon tx
        where g.pfam_family = ?
        and g.taxon_oid = tx.taxon_oid
        $domain_clause
        $rclause
        $imgClause
        $taxonClause
    };
    #print "printPcdPfamGenomeList() sql=$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );

    my $baseUrl = "$section_cgi&page=pcdPfamGenomeList";
    $baseUrl .= "&pfam_id=$pfam_id";

    my $cachedTable = new CachedTable( "pcdPfamGenomes$pfam_id", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "Domain", "asc", "center", "",
                              "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids,  G=GFragment, V=Viruses" );
    $cachedTable->addColSpec( "Status", "asc", "center", "",
                              "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $cachedTable->addColSpec( "Genome",     "asc",  "left" );
    $cachedTable->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "taxon_filter_oid";
    my $count = 0;
    my $total_gene_count = 0;
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $cnt )
	    = $cur->fetchrow();
        last if !$taxon_oid;

        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        $count++;
        print ". ";
        if ( ( $count % 180 ) == 0 ) {
            print "<br/>\n";
        }

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";

        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sdDelim
	    . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=pcdPfamGenomeGeneList";
        $url .= "&pfam_id=$pfam_id";
        $url .= "&taxon_oid=$taxon_oid";

        $r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
        $cachedTable->addRow($r);
        $total_gene_count = $total_gene_count + $cnt;
    }
    $cur->finish();

    my $m_count = 0;
    if ( $gtype eq 'metagenome' ) {
        # count MER-FS
        print "<p>Retriving metagenome gene counts ...<br/>\n";

        my %gene_func_count;
        if ($new_func_count) {
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
    	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

            my $sql3 = qq{
        		select f.taxon_oid, f.gene_count 
        		from taxon_pfam_count f, taxon tx 
        		where f.func_id = ? 
        		and f.taxon_oid = tx.taxon_oid 
        		$rclause2 $imgClause2 $taxonClause2 $domain_clause
    	    };
            #print "printPcdPfamGenomeList() 0 sql3=$sql3<br/>\n";
            my $cur3 = execSql( $dbh, $sql3, $verbose, $pfam_id );
            for ( ; ; ) {
                my ( $tid3, $cnt3 ) = $cur3->fetchrow();
                last if !$tid3;

                if ( $gene_func_count{$tid3} ) {
                    $gene_func_count{$tid3} += $cnt3;
                } else {
                    $gene_func_count{$tid3} = $cnt3;
                }
            }
            $cur3->finish();
        }

        my $rclause2     = WebUtil::urClause("t");
        my $imgClause2   = WebUtil::imgClause("t");
    	my $taxonClause2 = WebUtil::txsClause( "t", $dbh );
        my $sql2 = qq{
            select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
            from taxon t
            where t.in_file = 'Yes'
            and t.genome_type = 'metagenome'
            $rclause2
            $imgClause2
            $taxonClause2
        };
        #print "printPcdPfamGenomeList() sql2=$sql2<br/>\n";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $t_oid, $domain, $seq_status, $taxon_display_name )
		= $cur2->fetchrow();
            last if !$t_oid;

            $m_count++;

            my $cnt = 0;
            if ($new_func_count) {
                $cnt = $gene_func_count{$t_oid};
            } else {
                $cnt = MetaUtil::getTaxonOneFuncCnt( $t_oid, "", $pfam_id );
            }

            if ($cnt) {
                $domain     = substr( $domain,     0, 1 );
                $seq_status = substr( $seq_status, 0, 1 );
                my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
                $url .= "&taxon_oid=$t_oid";
                my $r;
                $r .= $sdDelim . "<input type='checkbox' name='taxon_filter_oid' value='$t_oid' /> \t";
                $r .= "$domain\t";
                $r .= "$seq_status\t";
                $r .= $taxon_display_name . $sdDelim 
		    . alink( $url, $taxon_display_name ) . "\t";

                $url = "$section_cgi&page=pcdPfamGenomeGeneList";
                $url .= "&pfam_id=$pfam_id";
                $url .= "&taxon_oid=$t_oid";
                $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
                $cachedTable->addRow($r);
                $total_gene_count = $total_gene_count + $cnt;
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

    if ( $count > 10 ) {
        WebUtil::printGenomeCartFooter();
    }
    $cachedTable->printTable();
    WebUtil::printGenomeCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine("$count genome(s) $total_gene_count genes retrieved.", 2);
    print end_form();

}

############################################################################
# printPcdPhyloDist - Print phylo distribution for Pfam's.
############################################################################
sub printPcdPhyloDist {
    my $pfam_id = param("pfam_id");
    my $noCat   = param("nocat");     # no cat.
    my $gtype   = param("gtype");
    if ( !$gtype || $gtype eq "") {
        $gtype = 'isolate';
    }

    my $dbh  = dbLogin();
    my $name = pfamName( $dbh, $pfam_id );

    setLinkTarget("_blank");
    printMainForm();
    print "<h1>Phylogenetic Distribution for $pfam_id</h1>\n";

    my $domain_clause = "";
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    print "<p>Pfam: ";
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
    print "</p>";

    if ( $noCat ne 'yes' ) {
        my $sql = qq{
          select cm.cog_pathway_oid
          from cog_pathway_cog_members cm, pfam_family_cogs pfc
          where pfc.ext_accession = ?
          and cm.cog_members = pfc.cog
        };
        my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
        my @cog_pways = ();
        for ( ; ; ) {
            my ($pid) = $cur->fetchrow();
            last if !$pid;
            push @cog_pways, ($pid);
        }
        $cur->finish();

        if ( scalar(@cog_pways) == 0 ) {
            print "<p>This Pfam does not belong to any pathways.\n";
            print end_form();
            #$dbh->disconnect();
            return;
        }
    }

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my @taxon_oids;
    my %tx2cnt_href;

    # isolate genomes and metagenomes in db:
    print "<p>Retrieving information from database ...<br/>\n";

    my $rclause   = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid" );
    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );
    my $sql = qq{
        select g.taxon_oid, g.gene_count
        from mv_taxon_pfam_stat g, taxon tx
        where g.pfam_family = ?
        and g.taxon_oid = tx.taxon_oid
        $rclause
        $imgClause
        $taxonClause
        $domain_clause
    };
    
    my $cur = execSql( $dbh, $sql, $verbose, $pfam_id );
    for ( ;; ) {
	my ( $taxon_oid, $cnt ) = $cur->fetchrow();
	last if !$taxon_oid;
	
	$tx2cnt_href{ $taxon_oid } = $cnt;
	push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();
    
    if ($gtype eq "metagenome") {
	my $check_merfs = 1;
	if ( $noCat eq 'yes' ) {
	    $check_merfs = 1;
	}
	if ( !$include_metagenomes ) {
	    $check_merfs = 0;
	}

	if ($check_merfs) {
	    print "<p>Checking metagenomes ...<br/>\n";

	    my %gene_func_count;
	    if ($new_func_count) {
		my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
		my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
		my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

		my $sql3 = qq{
		    select f.taxon_oid, f.gene_count 
		    from taxon_pfam_count f, taxon tx 
		    where f.func_id = ? 
		    and f.taxon_oid = tx.taxon_oid 
		    $rclause2 $imgClause2 $taxonClause2 $domain_clause
	        };

		my $cur3 = execSql( $dbh, $sql3, $verbose, $pfam_id );
		for ( ; ; ) {
		    my ( $tid3, $cnt3 ) = $cur3->fetchrow();
		    last if !$tid3;

		    if ( $gene_func_count{$tid3} ) {
			$gene_func_count{$tid3} += $cnt3;
		    } else {
			$gene_func_count{$tid3} = $cnt3;
		    }
		}
		$cur3->finish();
	    }

	    my $tclause = WebUtil::txsClause( "t.taxon_oid", $dbh );
	    my $sql = MerFsUtil::getTaxonsInFileSql($tclause);
	    $sql .= " and t.genome_type = 'metagenome' ";
	    my $cur = execSql( $dbh, $sql, $verbose );
	    my $cnt1 = 0;
	    for ( ;; ) {
		my ($t_oid) = $cur->fetchrow();
		last if !$t_oid;

		$cnt1++;
		if ( ( $cnt1 % 10 ) == 0 ) {
		    print ". ";
		}
		if ( ( $cnt1 % 1800 ) == 0 ) {
		    print "<br/>\n";
		}

		my $cnt = 0;
		if ($new_func_count) {
		    $cnt = $gene_func_count{$t_oid};
		} else {
		    $cnt = MetaUtil::getTaxonOneFuncCnt($t_oid, "", $pfam_id);
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
    #$dbh->disconnect();

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections", \%tx2cnt_href);
    foreach my $tx (@taxon_oids) {
	my $cnt = $tx2cnt_href{ $tx };
	$mgr->setCount($tx, $cnt);
    }

    printEndWorkingDiv();

    use TabHTML;
    TabHTML::printTabAPILinks("phyloTab");
    my @tabIndex = ( "#phylotab1", "#phylotab2" );
    my @tabNames = ( "Distribution", "Distance Tree" );
    TabHTML::printTabDiv("phyloTab", \@tabIndex, \@tabNames);

    print "<div id='phylotab1'><p>";
    print "<p>\n";
    print "Distribution for <i>" . escHtml($name) . "</i><br/>\n";
    if ($taxonClause ne "") {
        print "(User selected genomes with hits are shown in "
	    . "<font color=red>red</font>)<br/>\n";
    } else {
        print "(Hits are shown in <font color=red>red</font>)<br/>\n";
    }
    print "<br/>";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";
    print "</div>"; # end phylotab1

    print "<div id='phylotab2'><p>";
    require DistanceTree;
    if ($gtype eq "isolate") {
	DistanceTree::runTree(\%tx2cnt_href, "selected", "counts", 0, 1);

    } elsif ($gtype eq "metagenome") {
	print "<p>\n";
	print "BLAST Percent Identity: &nbsp;";
	print "<input type='radio' name='perc_identity' "
	    . "value='30' checked='checked' />30+ &nbsp;";
	print "<input type='radio' name='perc_identity' "
	    . "value='60' />60+ &nbsp;";
	print "<input type='radio' name='perc_identity' "
	    . "value='90' />90+ &nbsp;";
	print "</p>\n";
	
	# set the params to pass:
	my $txstr;
	foreach my $t (keys %tx2cnt_href) {
	    $txstr .= $t."\t".$tx2cnt_href{ $t }.",";
	}
	chop $txstr;

	print hiddenVar("taxon2cnt", $txstr);
	print hiddenVar("taxon_selection", "selected");
	print hiddenVar("type", "counts");
	print hiddenVar("metag", 2);

	my $name = "_section_DistanceTree_runTree";
	print submit(
	    -name  => $name,
	    -value => "Distance Tree",
	    -class => "meddefbutton"
        );
	#DistanceTree::runTree(\%tx2cnt_href, "selected", "counts", 0, 2);
    }
    print "</div>"; # end phylotab2
    TabHTML::printTabDivEnd();

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printPcdPfamGenomeGeneList - Show Pfam genome gene listing for genome
#   selection.
############################################################################
sub printPcdPfamGenomeGeneList {
    my $pfam_id   = param("pfam_id");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $pfam_id );

    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
    	from taxon t 
        where taxon_oid = ? 
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $id2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();

    if ( !$id2 ) {
        #$dbh->disconnect();
        return;
    }

    my $name = pfamName( $dbh, $pfam_id );
    print "<h1>Genome Gene List - $pfam_id</h1>";
    my $pfam_id2 = $pfam_id;
    $pfam_id2 =~ s/pfam/PF/;
    my $url = "$pfam_base_url$pfam_id2";
    print "<p>$pfam_id - ".alink( $url, $name )."</p>";

    require InnerTable;
    my $it = new InnerTable( 1, "pfamGenes$$", "pfamGenes", 1 );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;
    if ( $in_file eq 'Yes' ) {
        # MER-FS
        printStartWorkingDiv();
        print "<p>Retrieving gene information ...<br/>\n";

        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $pfam_id );
        my @gene_oids = ( keys %genes );

        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID", "asc", "left" );
        if ($show_gene_name) {
            $it->addColSpec( "Gene Product Name", "asc", "left" );
        }
        $it->addColSpec( "Genome ID",   "asc", "left" );
        $it->addColSpec( "Genome Name", "asc", "left" );

        for my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";

            if ($show_gene_name) {
                my ( $value, $source ) = 
		    MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
                $row .= $value . $sd . $value . "\t";
            }
            
            $row .= $tid . $sd . $tid . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a></td>\t";

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

    } else {
        my $rclause     = WebUtil::urClause("tx");
        my $imgClause   = WebUtil::imgClause("tx");
        my $taxonClause = WebUtil::txsClause("tx", $dbh);
        my $sql         = qq{
            select distinct g.gene_oid, g.gene_display_name, g.locus_tag
            from gene_pfam_families gpf, gene g, taxon tx
            where gpf.pfam_family = ?
            and gpf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            $rclause
            $imgClause
            $taxonClause
            order by g.gene_display_name
         };

        $cur = execSql( $dbh, $sql, $verbose, $pfam_id, $taxon_oid );
        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID",           "asc", "left" );
        $it->addColSpec( "Locus Tag",         "asc", "left" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome ID",         "asc", "left" );
        $it->addColSpec( "Genome Name",       "asc", "left" );

        for ( ; ; ) {
            my ( $gene_oid, $gene_name, $locus_tag ) = $cur->fetchrow();
            last if !$gene_oid;
            my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
            $row .=
                $gene_oid . $sd
              . "<a href='main.cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid'>"
              . "$gene_oid</a>\t";
            $row .= $locus_tag . $sd . $locus_tag . "\t";
            $row .= $gene_name . $sd . $gene_name . "\t";
            $row .= $taxon_oid . $sd . $taxon_oid . "\t";
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
        $msg = "Gene names are not displayed. Use 'Exapnd Gene Table Display' option to view detailed gene information.";
        printHint($msg);
    }

    printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( !$show_gene_name ) {
        printHint($msg);
    }

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        print hiddenVar( 'data_type', 'both' );
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) 
	    . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# pfamName - Get Pfam name.
############################################################################
sub pfamName {
    my ( $dbh, $ext_accession ) = @_;

    my $sql = qq{
       select ext_accession, name, description, db_source
       from pfam_family
       where ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ext_accession );
    my ( $ext_accession, $name, $description, $db_source ) = $cur->fetchrow();
    $cur->finish();

    my $pfam_name = $name;
    if ( $db_source =~ /HMM/ ) {
        $pfam_name .= " - $description";
    }

    return $pfam_name;
}

1;
