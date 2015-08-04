############################################################################
# Utility subroutines for queries
# $Id: CartUtil.pm 33638 2015-06-24 08:38:01Z jinghuahuang $
############################################################################
package CartUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use OracleUtil;
use QueryUtil;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $in_file  = $env->{in_file};
my $user_restricted_site = $env->{user_restricted_site};
my $enable_biocluster    = $env->{enable_biocluster};

my $max_display_num = 20000;

############################################################################
# getMaxDisplayNum
############################################################################
sub getMaxDisplayNum {
    
    return $max_display_num;
}

sub printMaxNumMsg {
    my ( $type ) = @_;
        
    print "<p>\n";
    print "Only a maximum of $max_display_num $type can be in cart.\n";
    print "</p>\n";
}

############################################################################
# addFuncGenesToGeneCart - add the genes of selected functions to gene cart
#
# add user restricted genes via genomes
# add taxon saved to restrict gene list too
############################################################################
sub addFuncGenesToGeneCart {
    my ( $useGenomeFilter, $selectName ) = @_;
        
    my @func_ids = param("func_id");
    if ( scalar(@func_ids) <= 0 ) {
        webError("Please select at least one function.");
    }
    #print "\@func_ids: @func_ids<br/>\n";
    
    # t:640753014
    my @taxon_oids;
    if ($useGenomeFilter) {
        @taxon_oids = OracleUtil::processTaxonBinOids("t", $selectName);
    }
    else {
        @taxon_oids = param("taxon_oid");
    }
    if ( scalar(@taxon_oids) <= 0 ) {
        webError("Please select at least one genome.");
    }

    printStatusLine( "Loading ...", 1 );

    # from queries list of distinct genes
    my %distinct_gene_oids;

    # function types list
    my (
        $go_ids_ref,      $cog_ids_ref,     $kog_ids_ref,    $pfam_ids_ref,    
        $tigr_ids_ref,    $ec_ids_ref,      $ko_ids_ref,     $ipr_ids_ref,
        $tc_fam_nums_ref, $bc_ids_ref,      $np_ids_ref,     $metacyc_ids_ref, 
        $iterm_ids_ref,  $ipway_ids_ref,    $plist_ids_ref,  $netwk_ids_ref,   
        $icmpd_ids_ref,  $irexn_ids_ref,
        $prule_ids_ref,   $unrecognized_ids_ref
      )
      = QueryUtil::groupFuncIds(\@func_ids);
    
    my @go_ids = @$go_ids_ref;
    my @cog_ids = @$cog_ids_ref;
    my @kog_ids = @$kog_ids_ref;
    my @pfam_ids = @$pfam_ids_ref;
    my @tigr_ids = @$tigr_ids_ref;
    my @ec_ids = @$ec_ids_ref;
    my @ko_ids = @$ko_ids_ref;
    my @ipr_ids = @$ipr_ids_ref;
    my @tc_fam_nums = @$tc_fam_nums_ref;
    my @bc_ids = @$bc_ids_ref;
    my @np_ids = @$np_ids_ref;
    my @metacyc_ids = @$metacyc_ids_ref;
    my @iterm_ids = @$iterm_ids_ref;
    my @ipway_ids = @$ipway_ids_ref;
    my @plist_ids = @$plist_ids_ref;
    my @netwk_ids = @$netwk_ids_ref;
    my @icmpd_ids = @$icmpd_ids_ref;
    my @irexn_ids = @$irexn_ids_ref;
    my @prule_ids = @$prule_ids_ref;

    printStartWorkingDiv();
    
    my $dbh = dbLogin();

    my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @taxon_oids );
    my @dbTaxons   = @$dbTaxons_ref;
    my @metaTaxons = @$metaTaxons_ref;

    if (scalar(@dbTaxons) > 0) {
        # restrict taxon_oid
        # returns statement: and tx.taxon_oid in (....
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
        # user selected taxons
        # returns statement: and tx.taxon_oid in (....
        my $taxonClause = '';
        if ( scalar(@dbTaxons) > 0 ) {
            my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbTaxons );
            $taxonClause = "and g.taxon in( $oid_str ) ";
        }
    
        #my $gttstr = " select id from gtt_func_id ";
        my $funcIdsInClause = '';
    
        if ( $#go_ids > -1 ) {
            print "Getting go genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @go_ids );
            my $sql = qq{
                select distinct ggt.gene_oid
                from gene_go_terms ggt, gene g
                where ggt.go_id in ( $funcIdsInClause )
                and ggt.gene_oid = g.gene_oid
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#cog_ids > -1 ) {
            print "Getting COG genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @cog_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_cog_groups g
                where g.cog in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#kog_ids > -1 ) {
            print "Getting KOG genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @kog_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_kog_groups g
                where g.kog in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#pfam_ids > -1 ) {
            print "Getting pfam genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @pfam_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_pfam_families g
                where g.pfam_family in ( $funcIdsInClause )
                $taxonClause            
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#tigr_ids > -1 ) {
            print "Getting tigrfam genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @tigr_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_tigrfams g
                where g.ext_accession in ( $funcIdsInClause )
                $taxonClause            
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#ec_ids > -1 ) {
            print "Getting enzymes genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @ec_ids );
            my $sql = qq{
                select distinct e.gene_oid
                from gene_ko_enzymes e, gene g
                where e.enzymes in ( $funcIdsInClause )
                and e.gene_oid = g.gene_oid
                $taxonClause                        
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#ko_ids > -1 ) {
            print "Getting kegg ko genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @ko_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_ko_terms g
                where g.ko_terms in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#ipr_ids > -1 ) {
            print "Getting interpro genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @ipr_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_xref_families g
                where g.db_name = 'InterPro'
                and g.id in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#tc_fam_nums > -1 ) {
            print "Getting Transporter Classification genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @tc_fam_nums );
            my $sql = qq{
                select distinct g.gene_oid
                from gene_tc_families g
                where g.tc_family in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#bc_ids > -1 ) {
            print "Getting biosynthetic cluster genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @bc_ids );

#            my $sql = qq{
#                select distinct g.gene_oid
#                from biosynth_cluster_features bc, gene g
#                where bc.biosynthetic_oid in ( $funcIdsInClause )
#                and bc.feature_oid = g.gene_oid
#                and bc.feature_type = 'gene'
#                $taxonClause
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from bio_cluster_features_new bcg, gene g
                where bcg.cluster_id in ( $funcIdsInClause )
                and bcg.gene_oid = g.gene_oid
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }

        if ( $#np_ids > -1 ) {
            print "Getting Secondary Metabolite genes <br/>\n";
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @np_ids );

#            my $sql = qq{
#                select distinct g.gene_oid
#                from project_info_natural_prods\@imgsg_dev gnp, 
#                    biosynth_cluster_features bc, gene g
#                where gnp.gold_np_id in ( $funcIdsInClause )
#                and gnp.bio_cluster_id = bc.biosynthetic_oid
#                and bc.feature_oid = g.gene_oid
#                and bc.feature_type = 'gene'
#                $taxonClause
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from natural_product np, bio_cluster_features_new bcg, gene g
                where np.np_id in ( $funcIdsInClause )
                and np.cluster_id = bcg.cluster_id
                and bcg.gene_oid = g.gene_oid
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }

        if ( $#metacyc_ids > -1 ) {
            print "Getting metacyc genes <br/>\n";
            $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @metacyc_ids );
            my $sql = qq{
                select distinct g.gene_oid
                from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
                    biocyc_reaction br, gene_biocyc_rxns g
                where bp.unique_id = brp.in_pwys
                and brp.unique_id = br.unique_id
                and br.unique_id = g.biocyc_rxn
                and br.ec_number = g.ec_number
                and bp.unique_id in ( $funcIdsInClause )
                $taxonClause                        
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }

        if ( $#icmpd_ids > -1 ) {
            print "Getting img compound genes <br/>\n";
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @icmpd_ids );
#            my $sql = qq{
#                select distinct g.gene_oid
#                from project_info_natural_prods\@imgsg_dev gnp, cvnatural_prods\@imgsg_dev np, 
#                    biosynth_cluster_features bc, gene g
#                where gnp.np_id = np.np_id
#                and np.img_compound_id in ( $funcIdsInClause )
#                and gnp.bio_cluster_id = bc.biosynthetic_oid
#                and bc.feature_oid = g.gene_oid
#                and bc.feature_type = 'gene'
#                $taxonClause
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from natural_product np, bio_cluster_features_new bcg, gene g
                where np.compound_oid in ( $funcIdsInClause )
                and np.cluster_id = bcg.cluster_id
                and bcg.gene_oid = g.gene_oid
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }

        if ( $#iterm_ids > -1 ) {
            print "Getting img terms genes <br/>\n";
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @iterm_ids );
#            my $sql = qq{
#                select distinct g.gene_oid
#                from dt_img_term_path dtp, gene_img_functions g
#                where dtp.term_oid in ( $funcIdsInClause )
#                and dtp.map_term = g.function
#                $taxonClause
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from gene_img_functions g
                where g.function in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
        
        # it's very complicated, need to go thru the tree to find all the img terms
        if ( $#ipway_ids > -1 ) {
            print "Getting img pathways genes <br/>\n";
            require ImgTermNodeMgr;
            my $mgr  = new ImgTermNodeMgr();
            my $root = $mgr->loadTree($dbh);
            my @term_oids;
    
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @ipway_ids );
            my $sql = qq{
                select irc.catalysts term_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc
                where ipr.rxn = irc.rxn_oid
                and ipr.pathway_oid in ( $funcIdsInClause )
                union
                select rtc.term term_oid
                from img_pathway_reactions ipr, img_reaction_t_components rtc
                where ipr.rxn = rtc.rxn_oid
                and ipr.pathway_oid in ( $funcIdsInClause )
            };
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ($toid) = $cur->fetchrow();
                last if !$toid;
                push( @term_oids, $toid );
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id1" )
              if ( $funcIdsInClause =~ /gtt_num_id1/i );
    
            my %childrenTerms;
            foreach my $id (@term_oids) {
                my $n = $root->ImgTermNode::findNode($id);
                $n->getTerms( \%childrenTerms );
            }
    
            foreach my $i ( keys %childrenTerms ) {
                push( @term_oids, $i );
            }
    
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @term_oids );
#            my $sql = qq{
#                select distinct g.gene_oid
#                from dt_img_term_path dtp, gene_img_functions g
#                where dtp.term_oid in ( $funcIdsInClause )
#                and dtp.map_term = g.function
#                $taxonClause
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from gene_img_functions g
                where g.function in ( $funcIdsInClause )
                $taxonClause
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        if ( $#plist_ids > -1 ) {
            print "Getting img part list genes <br/>\n";
            $funcIdsInClause = OracleUtil::getNumberIdsInClause1( $dbh, @plist_ids );
#            my $sql = qq{
#                select distinct g.gene_oid
#                from img_parts_list_img_terms plt, dt_img_term_path dtp, gene_img_functions g
#                where plt.parts_list_oid in ( $funcIdsInClause )
#                and plt.term = dtp.term_oid
#                and dtp.map_term = g.function
#                $taxonClause                        
#                $rclause
#                $imgClause
#            };
            my $sql = qq{
                select distinct g.gene_oid
                from img_parts_list_img_terms plt, gene_img_functions g
                where plt.parts_list_oid in ( $funcIdsInClause )
                and plt.term = g.function
                $taxonClause                        
                $rclause
                $imgClause
            };
            runGetGeneQueries( $dbh, $sql, \%distinct_gene_oids );
        }
    
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        OracleUtil::truncTable( $dbh, "gtt_num_id1" )
          if ( $funcIdsInClause =~ /gtt_num_id1/i );
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxonClause =~ /gtt_num_id/i );
                  
    }
    #$dbh->disconnect();

    if (scalar(@metaTaxons) > 0) {
        my $data_type_p = param("data_type");
        my @type_list = MetaUtil::getDataTypeList( $data_type_p );

        if ( $#metacyc_ids > -1 ) {
            print "Getting metacyc genes <br/>\n";
            my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @metacyc_ids );

            # get MetaCyc enzymes
            my $sql     = qq{
                select distinct br.ec_number 
                from biocyc_reaction_in_pwys brp, biocyc_reaction br
                where brp.in_pwys in ( $funcIdsInClause )
                and brp.unique_id = br.unique_id
                and br.ec_number is not null
            };

            my $dbh = dbLogin();
            my $cur = execSql( $dbh, $sql, $verbose );
            my @enzymes = ();
            for ( ; ; ) {
                my ($ec) = $cur->fetchrow();
                last if !$ec;
                push @enzymes, ($ec);
            }
            $cur->finish();

            OracleUtil::truncTable( $dbh, "gtt_func_id" )
              if ( $funcIdsInClause =~ /gtt_func_id/i );
                    
            #$dbh->disconnect();

            if (scalar(@enzymes) > 0) {
                my %func_id_hash;
                for my $ec (@enzymes) {
                    $func_id_hash{$ec} = 1;
                }
    
                foreach my $id (@func_ids) {
                    if ( $id =~ /^MetaCyc:/ ) {
                        next;
                    }
                    $func_id_hash{$id} = 1;
                }
                @func_ids = keys(%func_id_hash);
            }            
        }
    
        for my $t_oid (@metaTaxons) {
            for my $data_type (@type_list) {
                for my $func_id (@func_ids) {
                    my %func_gene_hash = MetaUtil::getTaxonFuncGenes( $t_oid, $data_type, $func_id );
                    foreach my $func_gene (keys %func_gene_hash) {
                        my $workspace_id = $func_gene_hash{$func_gene};
                        $distinct_gene_oids{$workspace_id} = 1;
                    }
                }
            }
        }
    }

    my @genes = keys(%distinct_gene_oids);

    callGeneCartToAdd( \@genes, 1 );
}

sub callGeneCartToAdd {
    my ( $genes_ref, $endWorkingDivNeeded ) = @_;
    
    my $size = scalar(@$genes_ref);
    printStatusLine( "Adding $size genes", 2 );

    require GeneCartStor;
    my $gc = new GeneCartStor();
    if ($endWorkingDivNeeded) {
        $gc->addGeneBatch( $genes_ref, '', '', '', '', '', '', '', '', '', '', '', '', 1 );
        printEndWorkingDiv();        
    }
    else {
        $gc->addGeneBatch( $genes_ref );
    }

    if ( scalar(@$genes_ref) <= 0 ) {
        print "<font color='red'>There are no genes added into Gene Cart."
          . "</font><br/><br/>\n";
    }

    $gc->printGeneCartForm( '', 1 );
}

############################################################################
# runGetGeneQueries - helper function for addGeneCart()
# $sql - query to run
# $genelist_href - where to store the found data
############################################################################
sub runGetGeneQueries {
    my ( $dbh, $sql, $genelist_href ) = @_;

    #print "CartUtil::runGetGeneQueries() sql: $sql<br/>\n";

    my $count = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $genelist_href->{$gene_oid} = 1;
        $count++;
    }
    $cur->finish();
    print "Found $count genes <br/>\n";
}

sub getFunctionTypes {
    my ($functions_aref) = @_;

    my %function_types = (
        go      => 0,
        cog     => 0,
        kog     => 0,
        pfam    => 0,
        tigrfam => 0,
        ipr     => 0,
        ec      => 0,
        tc      => 0,
        ko      => 0,
        kog     => 0,
        metacyc => 0,
        ipways  => 0,
        plist   => 0,
        iterm   => 0,
        eggnog  => 0,
    );

    foreach my $id (@$functions_aref) {
        if ( $id =~ /^GO/ ) {
            $function_types{go} = 1;
        }
        elsif ( $id =~ /^COG/ ) {
            $function_types{cog} = 1;
        }
        elsif ( $id =~ /^KOG/ ) {
            $function_types{kog} = 1;
        }
        elsif ( $id =~ /^pfam/ ) {
            $function_types{pfam} = 1;
        }
        elsif ( $id =~ /^TIGR/ ) {
            $function_types{tigrfam} = 1;
        }
        elsif ( $id =~ /^IPR/ ) {
            $function_types{ipr} = 1;
        }
        elsif ( $id =~ /^EC:/ ) {
            $function_types{ec} = 1;
        }
        elsif ( $id =~ /^TC:/ ) {
            $function_types{tc} = 1;
        }
        elsif ( $id =~ /^KO:/ ) {
            $function_types{ko} = 1;
        }
        elsif ( $id =~ /^MetaCyc:/ ) {
            $function_types{metacyc} = 1;
        }
        elsif ( $id =~ /^IPWAY:/ ) {
            $function_types{ipways} = 1;
        }
        elsif ( $id =~ /^PLIST:/ ) {
            $function_types{plist} = 1;
        }
        elsif ( $id =~ /^ITERM:/ ) {
            $function_types{iterm} = 1;
        }
        elsif ( $id =~ /^EGGNOG/ ) {
            $function_types{eggnog} = 1;
        }
    }

    return \%function_types;

}

sub separateFuncIds {
    my ( @func_ids ) = @_;

    # function types list
    my (
        $go_ids_ref,      $cog_ids_ref,     $kog_ids_ref,    $pfam_ids_ref,    
        $tigr_ids_ref,    $ec_ids_ref,      $ko_ids_ref,     $ipr_ids_ref,
        $tc_fam_nums_ref, $bc_ids_ref,      $np_ids_ref,     $metacyc_ids_ref, 
        $iterm_ids_ref,   $ipway_ids_ref,   $plist_ids_ref,  $netwk_ids_ref,   
        $icmpd_ids_ref,   $irexn_ids_ref,
        $prule_ids_ref,   $unrecognized_ids_ref
      )
      = QueryUtil::groupFuncIds(\@func_ids);
    
    my @unsurported_func_ids = ();
    if (scalar(@$go_ids_ref) > 0) {
        push(@unsurported_func_ids, @$go_ids_ref);
    }
    if (scalar(@$ipr_ids_ref) > 0) {
        push(@unsurported_func_ids, @$ipr_ids_ref);
    }
    if (scalar(@$bc_ids_ref) > 0 && !$enable_biocluster) {
        for my $id (@$bc_ids_ref) {
            push(@unsurported_func_ids, "BC:$id");
        }
    }
    if (scalar(@$np_ids_ref) > 0) {
        for my $id (@$np_ids_ref) {
            push(@unsurported_func_ids, "NP:$id");
        }
    }
    if (scalar(@$netwk_ids_ref) > 0) {
        for my $id (@$netwk_ids_ref) {
            push(@unsurported_func_ids, "NETWK:$id");            
        }
    }
    if (scalar(@$icmpd_ids_ref) > 0) {
        for my $id (@$icmpd_ids_ref) {
            push(@unsurported_func_ids, "ICMPD:$id");            
        }
    }
    if (scalar(@$irexn_ids_ref) > 0) {
        for my $id (@$irexn_ids_ref) {
            push(@unsurported_func_ids, "IREXN:$id");            
        }
    }
    if (scalar(@$prule_ids_ref) > 0) {
        for my $id (@$prule_ids_ref) {
            push(@unsurported_func_ids, "PRULE:$id");            
        }
    }
    
    return ($cog_ids_ref, $kog_ids_ref, $pfam_ids_ref, $tigr_ids_ref, 
            $ec_ids_ref, $ko_ids_ref, $tc_fam_nums_ref, $bc_ids_ref, $metacyc_ids_ref, 
            $iterm_ids_ref,  $ipway_ids_ref, $plist_ids_ref, 
            $unrecognized_ids_ref, \@unsurported_func_ids);
}


1;
