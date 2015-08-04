###########################################################################
# MetaGeneDetail.pm - file version
# $Id: MetaGeneDetail.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package MetaGeneDetail;
my $section = "MetaGeneDetail";

use strict;
use CGI qw( :standard );
use Data::Dumper;
use ScaffoldPanel;
use ScaffoldGraph;
use Time::localtime;
use InnerTable;
use IprGraph;
use WebConfig;
use WebUtil;
use ImgTermNode;
use ImgTermNodeMgr;
use InnerFrameUtil;
use GeneCassette;
use GeneUtil;
use Sequence;
use SequenceExportUtil;
use HtmlUtil;
use MetaUtil;
use MetaFuncAlignmentUtil;
use HashUtil;
use MetaGeneTable;
use WorkspaceUtil;

my $env          = getEnv();
my $main_cgi     = $env->{main_cgi};
my $section_cgi  = "$main_cgi?section=$section";
my $inner_cgi    = $env->{inner_cgi};
my $verbose      = $env->{verbose};
my $base_dir     = $env->{base_dir};
my $img_internal = $env->{img_internal};
my $snp_enabled  = $env->{snp_enabled};

#my $use_gene_priam = $env->{ use_gene_priam };
my $tmp_dir               = $env->{tmp_dir};
my $tmp_url               = $env->{tmp_url};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $mer_data_dir          = $env->{mer_data_dir};
my $taxon_reads_fna_dir   = $env->{taxon_reads_fna_dir};
my $swiss_prot_base_url   = $env->{swiss_prot_base_url};
my $ncbi_entrez_base_url  = $env->{ncbi_entrez_base_url};
my $ncbi_mapview_base_url = $env->{ncbi_mapview_base_url};
my $img_hmms_serGiDb      = $env->{img_hmms_serGiDb};
my $img_hmms_singletonsDb = $env->{img_hmms_singletonsDb};

#my $puma_redirect_base_url = $env->{ puma_redirect_base_url };
my $vimss_redirect_base_url = $env->{vimss_redirect_base_url};
my $geneid_base_url         = $env->{geneid_base_url};
my $nice_prot_base_url      = $env->{nice_prot_base_url};
my $enzyme_base_url         = $env->{enzyme_base_url};
my $pfam_base_url           = $env->{pfam_base_url};

my $ipr_base_url            = $env->{ipr_base_url};
my $ipr_base_url2            = $env->{ipr_base_url2};
my $ipr_base_url3            = $env->{ipr_base_url3};
my $ipr_base_url4           = $env->{ipr_base_url4};

my $pirsf_base_url          = $env->{pirsf_base_url};
my $tigrfam_base_url        = $env->{tigrfam_base_url};
my $unigene_base_url        = $env->{unigene_base_url};
my $tair_base_url           = $env->{tair_base_url};
my $wormbase_base_url       = $env->{wormbase_base_url};
my $zfin_base_url           = $env->{zfin_base_url};
my $flybase_base_url        = $env->{flybase_base_url};
my $hgnc_base_url           = $env->{hgnc_base_url};
my $mgi_base_url            = $env->{mgi_base_url};
my $rgd_base_url            = $env->{rgd_base_url};
my $pdb_base_url            = $env->{pdb_base_url};
my $cog_base_url            = $env->{cog_base_url};
my $go_base_url             = $env->{go_base_url};
my $go_evidence_url         = $env->{go_evidence_url};
my $greengenes_blast_url    = $env->{greengenes_blast_url};
my $include_metagenomes     = $env->{include_metagenomes};
my $include_bbh_lite        = $env->{include_bbh_lite};
my $show_myimg_login        = $env->{show_myimg_login};
my $metacyc_url             = $env->{metacyc_url};
my $img_lite                = $env->{img_lite};
my $img_er                  = $env->{img_er};
my $img_edu                 = $env->{img_edu};
my $preferences_url         = "$main_cgi?section=MyIMG&page=myIMG&page=preferences";
my $flank_length            = 25000;
my $enable_interpro = $env->{enable_interpro};
#my $flank_length = 40000;
#my $large_flank_length = 100000;
my $large_flank_length    = 200000;
my $max_gene_batch        = 100;
my $max_homologs          = 1000;
my $max_hilite_taxons     = 10;
my $user_restricted_site  = $env->{user_restricted_site};
my $no_restricted_message = $env->{no_restricted_message};
my $nrhits_dir            = $env->{nrhits_dir};
my $truncHomologs         = 0;
my $seqWrapLen            = 70;   # max. length before wrapping sequence
my $rdbms                 = getRdbms();
my $ncbi_blast_server_url = $env->{ncbi_blast_server_url};
my $show_private          = $env->{show_private};
my $base_url              = $env->{base_url};
my $crispr_png            = "$base_url/images/crispr.png";
my $mysql_config          = $env->{mysql_config};
my $lite_homologs_url     = $env->{lite_homologs_url};
my $use_app_lite_homologs = $env->{use_app_lite_homologs};
my $img_geba              = $env->{img_geba};
my $kegg_orthology_url    = $env->{kegg_orthology_url};
my $kegg_module_url       = $env->{kegg_module_url};
my $swissprot_source_url  = $env->{swissprot_source_url};
my $include_ht_homologs   = $env->{include_ht_homologs};
my $rna_server_url        = $env->{rna_server_url};
my $img_rna_blastdb       = $env->{img_rna_blastdb};
my $img_meta_rna_blastdb  = $env->{img_meta_rna_blastdb};
my $img_iso_blastdb       = $env->{img_iso_blastdb};
my $blastall_bin          = $env->{blastall_bin};
my $blast_server_url  = $env->{blast_server_url};
my $img_lid_blastdb   = $env->{img_lid_blastdb};
my $lite_homologs_url = $env->{lite_homologs_url};

my $sandbox_blast_data_dir  = $env->{sandbox_blast_data_dir};
my $mer_data_dir = $env->{mer_data_dir};

my $rfam_base_url = $env->{rfam_base_url};
$rfam_base_url = "http://rfam.sanger.ac.uk/family/"
  if ( $rfam_base_url eq "" );

my $regtransbase_check_base_url = $env->{regtransbase_check_base_url};
my $regtransbase_base_url       = $env->{regtransbase_base_url};

my $tc_base_url = "http://www.tcdb.org/search/result.php?tc=";

# tab panel redirect
my $tab_panel             = $env->{tab_panel};
my $content_list          = $env->{content_list};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};

## --es 05/05/2005 Set limits on no. of annotations to show.
my $top_annotations_to_show = $env->{top_annotations_to_show};
$top_annotations_to_show = 100 if $top_annotations_to_show == 0;

my $nvl = getNvl();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $sid = getContactOid();

    my $page = param("page");

    if ( $page eq "metaGeneDetail" || paramMatch("refreshGenePage") ne "" ) {
        my $gene_oid = param("gene_oid");
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;           
        printGeneDetail();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "geneDetailByGiNo" ) {
        printGeneDetailByGiNo();
    } elsif ( $page eq "genePageOrthologCluster" ) {
        printGenePageOrthologCluster();
    } elsif ( $page eq "orthologCategoryHits" ) {
        printOrthologCategoryHits();
    } elsif ( $page eq "genePageOrthologHits" ) {
        printGenePageOrthologHits();
    } elsif ( $page eq "pepstats" ) {
        require PepStats;
        my $gene_oid = param("gene_oid");
        PepStats::printPepStats($gene_oid);
    } elsif ( $page eq "fusionComponents" ) {
        printFusionComponents();
    } elsif ( $page eq "taxonFusionComponents" ) {
        printTaxonFusionComponents();
    } elsif ( $page eq "fusionProteins" ) {
        printFusionProteins();
    } elsif ( $page eq "sigCleavage" ) {
        printSigCleavage();
    } elsif ( $page eq "tmTopo" ) {
        printTmTopo();
    } elsif ( $page eq "myImgNote" ) {
        printMyImgNote();
    } elsif ( $page eq "consRegionScoreNote" ) {
        printConsRegionScoreNote();
    } elsif ( $page eq "domainLetterNote" ) {
        printDomainLetterNote();
    } elsif ( $page eq "genePageFaa" ) {
        printGenePageFaa();
    } elsif ( $page eq "genePageMainFaa" ) {
        printGenePageMainFaa();
    } elsif ( $page eq "genePageAltFaa" ) {
        printGenePageAltFaa();
    }
    ## --es 07/18/2007
    elsif ( $page eq "componentOrthologs" ) {
        printComponentOrthologs();
    } elsif ( $page eq "phyloDist" ) {
        phyloCdsHomologs();
    } elsif ( $page eq "estCopyNote" ) {
        printEstCopyNote();
    } elsif ( $page eq "homolog" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        timeout( 60 * 20 );      # timeout in 20 minutes
        printHomologPage();

        HtmlUtil::cgiCacheStop();

    } elsif ( $page eq "rnaHomolog" ) { 
#        if ($user_restricted_site && HtmlUtil::isCgiCacheEnable()) { 
#            my $dbh = dbLogin(); 
#            my $taxon_oid = param("taxon_oid"); 
#            my $x = WebUtil::isTaxonPublic($dbh, $taxon_oid); 
#            #$dbh->disconnect(); 
###            $sid = 0 if($x); # public cache                                                  #                
#        } 
#        HtmlUtil::cgiCacheInitialize("$section" . "_" . $sid); 
#        HtmlUtil::cgiCacheStart() or return; 
 
        timeout( 60 * 20 );      # timeout in 20 minutes
        printRnaHomologPage(); 
 
#        HtmlUtil::cgiCacheStop(); 
 
    } elsif ( $page eq "mygeneNeighborhood" ) {
        printNeighborhoodMyGene();
    } elsif ( $page eq "neighborhoodAlignment" ) {
        printNeighborhoodAlignment();
    } elsif ( $page eq "geneSnp" ) {
        use Snps;
        Snps::printGeneSnps();
    } elsif ( $page eq "exportMetaGenes" ) {
        my $gene_oid = param("gene_oid");
        printExportGenes($gene_oid);
    } else {
        my $gene_oid = param("gene_oid");
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;        
        printGeneDetail();
        HtmlUtil::cgiCacheStop();
    }
}

sub printHomologPage {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $gene_oid  = param("gene_oid");
    my $dbh       = dbLogin();

    #    checkGenePerm( $dbh, $gene_oid );
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>Gene Homolog</h1>\n";

    print "<table class='img'>\n";
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    print "<tr class='img'><td class='img'>Genome Name</td>\n";
    print "<td class='img'>$taxon_name</td></tr>\n";
    print "<tr class='img'><td class='img'>Gene</td>\n";
    my $gene_name = 
    MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $data_type );
    if ($gene_name) {
        $gene_name = $gene_oid . ": " . $gene_name;
    } else {
        $gene_name = $gene_oid;
    }
    print "<td class='img'>$gene_name</td></tr>\n";
    print "</table>\n";

    printStatusLine( "Loading ...", 1 );

    printHomologToolKit($gene_oid);
    printCdsHomologs( $dbh, $taxon_oid, $data_type, $gene_oid );

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

sub printRnaHomologPage { 
 
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $gene_oid = param("gene_oid"); 
    my $dbh      = dbLogin(); 
    checkTaxonPerm( $dbh, $taxon_oid );
 
    printStatusLine( "Loading ...", 1 ); 

    my $workspace_id = "$taxon_oid $data_type $gene_oid";
 
    my ($dna_seq, $strand, $scaf_oid) = MetaUtil::getGeneFna($gene_oid, $taxon_oid, $data_type);
    my $dna_seq_length = length($dna_seq);

    if( $rna_server_url ) {
        printMetaRnaHomologsBlast( $dbh, $workspace_id, $dna_seq_length, $dna_seq );
    } 
 
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect(); 
} 

############################################################################
# printGeneDetailBySymbol - Show gene detail from one gene symbol.
#  (This is not correct since a gene symbol may map to more than one gene.)
############################################################################
sub printGeneDetailBySymbol {
    my ($geneSymbol) = @_;
    if ( $geneSymbol eq "" ) {
        webError("Enter gene symbol.");
        return;
    }
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select g.gene_oid
       from gene g
       where lower( g.gene_symbol ) = ?
       $rclause
       $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, lc($geneSymbol) );
    my ($gene_oid) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$gene_oid ) {
        webError("Gene symbol '$geneSymbol' not found.\n");
        return;
    }
    printGeneDetail($gene_oid);
}

############################################################################
# printGeneDetailByLocusTag - Show one gene detail by locus tag ID.
############################################################################
sub printGeneDetailByLocusTag {
    my ($locus_tag) = @_;
    if ( $locus_tag eq "" ) {
        webError("Enter locus tag.");
        return;
    }
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select g.gene_oid
       from gene g
       where lower( g.locus_tag ) = ?
       $rclause
       $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, lc($locus_tag) );
    my ($gene_oid) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$gene_oid ) {
        webError("Locus tag '$locus_tag' not found.\n");
        return;
    }
    printGeneDetail($gene_oid);
}

############################################################################
# printGeneDetailByGiNo - Print by GI number.
############################################################################
sub printGeneDetailByGiNo {
    my $giNo = param("giNo");

    if ( $giNo eq "" ) {
        webError("Enter GI number.");
        return;
    }
    my $dbh = dbLogin();
    my $sql = qq{
       select gel.gene_oid
       from gene_ext_links gel
       where gel.id = ?
       and gel.db_name = 'GI'
   };
    my $cur = execSql( $dbh, $sql, $verbose, $giNo );
    my ($gene_oid) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$gene_oid ) {
        webError("GI number '$giNo' not found.\n");
        return;
    }
    printGeneDetail($gene_oid);
}

############################################################################
# printGeneDetailByExtAccession - Show one gene detail by external
#   accession.
############################################################################
sub printGeneDetailByExtAccession {
    my ($accId) = @_;
    if ( $accId eq "" ) {
        webError("Enter external accession.");
        return;
    }
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select g.gene_oid
       from gene g
       where lower( g.protein_seq_accid ) =  ?
       $rclause
       $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, lc($accId) );
    my ($gene_oid) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$gene_oid ) {
        webError("External Accession '$accId' not found.\n");
        return;
    }
    printGeneDetail($gene_oid);
}

############################################################################
# printGeneDetail - Show gene detail again.
############################################################################
sub printGeneDetail {
    my ($gene_oid) = @_;
    my $cassette_oid = "";    # new - ken

    $gene_oid = param("gene_oid") if $gene_oid eq "";
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if (!WebUtil::isInt($gene_oid)) {
        my ($txid, $dt, $gid) = split(/ /, $gene_oid);
        if ($gid && $gid ne "") {
            $taxon_oid = $txid;
            $gene_oid = $gid;
            $data_type = $dt;
        } else {
            # in ClustalW, spaces are not allowed, so the metagene
            # is specified as txid-dt-gid
            ($txid, $dt, $gid) = split("-", $gene_oid);
            if ($gid && $gid ne "") {
                $taxon_oid = $txid;
                $gene_oid = $gid;
                $data_type = $dt;
            }
        }
    }

    if ( blankStr($gene_oid) ) {
        webError("No meta-Gene ID specified.");
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $sql2 = "select genome_type from taxon where taxon_oid = ?";
    my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
    my ($g_type) = $cur2->fetchrow();
    $cur2->finish();
    if ( $g_type ne 'metagenome' ) {
        ## We have isolate bins in files
        print "<h1>Gene Detail</h1>\n";
    }
    else {
        print "<h1>Metagenome Gene Detail</h1>\n";
    }
    printStatusLine( "Loading ...", 1 );

    my $faa = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
    my $locus_type = param("locus_type");

    my @vals = ();
    if ( !$locus_type ) {
        # get locus type
        @vals = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
        if ( scalar(@vals) > 0 && scalar(@vals) <= 7 ) {
            $locus_type = $vals[0];
        } elsif ( scalar(@vals) > 2 ) {
            $locus_type = $vals[1];
        }
    }

    my $aa_seq_length = length($faa);
    my $gene_display_name;

    my $start_coord;
    my $end_coord;
    my $strand;

    if ($content_list) {
        # show a table of content list
        # html bookmark    -ken

        my $nbsps1 = "&nbsp;" x 4;
        my $nbsps2 = "&nbsp;" x 8;

        if ( $locus_type =~ /RNA/ ) {
            # I have to switch tools from rna to Evidence ...
            print qq{
              <p>
              $nbsps1<a href="#information">RNA Information</a>
              <br>
              $nbsps1<a href="#evidence">RNA Neighborhood</a>
              <br>
              $nbsps1<a href="#tools">External Sequence Search</a>
              <br>
              $nbsps1<a href="#homolog">RNA Homologs</a>
              <br>
              </p>
            };
        } elsif ( $aa_seq_length > 0 ) {
            print "<p>\n";
            print "$nbsps1<a href='#information'>Gene Information</a><br>\n";
            #print "$nbsps1<a href='#candidate'>"
            #    . "Find Candidate Product Name</a><br>\n";
            print "$nbsps1<a href='#evidence'>"
                . "Evidence For Function Predictions</a><br>\n";
            print "$nbsps1<a href='#tools'>Sequence Search</a><br>\n";
            print "$nbsps2<a href='#tools1.1'>"
                . "External Sequence Search</a><br>\n";
            print "$nbsps2<a href='#tools1.2'>IMG Sequence Search</a><br>\n";
            print "$nbsps1<a href='#homolog'>Homolog Display</a><br>\n";
            print "</p>\n";
        }
    }    # end if - content list

    # html bookmark 1
    if ( $locus_type =~ /RNA/ ) {
        print WebUtil::getHtmlBookmark
        ( "information", "<h2>RNA Information</h2>" );
    } else {
        print WebUtil::getHtmlBookmark
        ( "information", "<h2>Gene Information</h2>" );
    }

    my $dbh = dbLogin();

    my $is_pseudogene;
    my $scaffold_oid;

    my @cogs;
    my @pfams;
    my $gene_display_name = "";
    print "<table class='img' border='1'>\n";

    if ( $locus_type =~ /RNA/ ) {
        # RNA
        print "<tr class='highlight'>\n";
        print "<th class='subhead' align='center'>";
        print "<font color='darkblue'>\n";
        print "RNA Information</th>\n";
        print "</font>\n";
        print "<td class='img'>" . nbsp(1) . "</td>\n";
        print "</tr>\n";
        ( $scaffold_oid, $taxon_oid, $start_coord, $end_coord, $strand, $gene_display_name ) =
          printMetaRnaInfo( $dbh, $gene_oid, $taxon_oid, $data_type );
    } else {
        # Gene
        my ($cogs_ref, $sdbFileExist) = MetaUtil::getGeneCogInfo( $gene_oid, $taxon_oid, $data_type );
        @cogs = @$cogs_ref;
        my ($pfams_ref, $sdbFileExist) = MetaUtil::getGenePfamInfo( $gene_oid, $taxon_oid, $data_type );
        @pfams = @$pfams_ref;
        my ($tigrfams_ref, $sdbFileExist) = MetaUtil::getGeneTIGRfamInfo( $gene_oid, $taxon_oid, $data_type );

        print "<tr class='highlight'>\n";
        print "<th class='subhead' align='center'>";
        print "<font color='darkblue'>\n";
        print "Gene Information</th>\n";
        print "</font>\n";
        print "<td class='img'>" . nbsp(1) . "</td>\n";
        print "</tr>\n";

        ( $is_pseudogene, $scaffold_oid, $taxon_oid, $start_coord, $end_coord, $strand ) =
          printMetaGeneInfo( $gene_oid, $taxon_oid, $data_type, $cogs_ref, $pfams_ref, $tigrfams_ref );

        print "<tr class='img'>";
        print "<td class='img'>&nbsp;</td><td class='img'>&nbsp;</td>";
        print "</tr>\n";

        if ( $aa_seq_length > 0 ) {
            print "<tr class='highlight'>\n";
            print "<th class='subhead' align='center'>";
            print "<font color='darkblue'>\n";
            print "Protein Information</th>\n";
            print "</font>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "</tr>\n";
            printProteinInfo( $dbh, $gene_oid, $taxon_oid, $data_type, 
			      $gene_display_name, $aa_seq_length, 
			      $cogs_ref, $pfams_ref, $tigrfams_ref );
            print "<tr class='img'>";
            print "<td class='img'>&nbsp;</td><td class='img'>&nbsp;</td>";
            print "</tr>\n";

            print "<tr class='highlight'>\n";
            print "<th class='subhead' align='center'>";
            print "<font color='darkblue'>\n";
            print "Pathway Information</th>\n";
            print "</font>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "</tr>\n";

            printPathwayInfo( $dbh, $gene_oid, $taxon_oid, $data_type );
        } else {
            print "<p>No amino acid data\n";
        }

        # Add gene cassette info here - ken
        my $to_display = 0;
        if (    $to_display
             && !$include_metagenomes
             && lc($is_pseudogene) ne 'yes' )
        {
            print "<tr class='img'>";
            print "<td class='img'>&nbsp;</td><td class='img'>&nbsp;</td>";
            print "</tr>\n";
            print "<tr class='highlight'>\n";
            print "<th class='subhead' align='center'>";
            print "<font color='darkblue'>\n";
            print "IMG Clusters</th>\n";
            print "</font>\n";
            print "<td class='img'>" . nbsp(1) . "</td>\n";
            print "</tr>\n";

            # Operons section
            # printAnalysis( $dbh, $gene_oid );
            #} my $include_bbh     = $env->{include_bbh};
        }
    }

    my $contact_oid = getContactOid();
    print "</table>\n";

    #printAddQueryGene($gene_oid, $aa_seq_length); # if $aa_seq_length > 0;
    # add to gene cart button
    print start_form( -name   => "addQueryGeneForm",
                      -action => $main_cgi );
    print hiddenVar( "gene_oid", "$taxon_oid $data_type $gene_oid" );
    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => "medbutton"
    );
    print end_form();



    if ( $locus_type =~ /RNA/ ) {
        # html bookmark 2
        printMetaRnaNeighborhood( $dbh, $gene_oid, $taxon_oid, $data_type,
                  $start_coord, $end_coord, $strand,
                  $scaffold_oid );

        # html bookmark 3
        my ( $gene_symbol, @rest ) = split( /(\s+)/, $gene_display_name );
        printMetaRnaTools( $taxon_oid, $data_type, $gene_oid, $locus_type, $gene_symbol, $scaffold_oid, $start_coord, $end_coord, $strand );

        # html bookmark 4
        print WebUtil::getHtmlBookmark( "homolog", "<h2>RNA Homolog</h2>" ); 
        print "\n"; 
        my $rnaHomologs = param( "rnaHomologs" ); 
        printMetaRnaHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $rnaHomologs, $locus_type );

    } elsif ( $aa_seq_length > 0 ) {
        # html bookmark 2
        printMetaFuncEvidence( $dbh, $gene_oid, $taxon_oid, $data_type,
                   $start_coord, $end_coord, $strand, 
                   $scaffold_oid, $aa_seq_length,
                   \@cogs, \@pfams );

        # --es 10/17/2007
        #printGenomeProperties( $dbh, $gene_oid ) if $img_internal;

        # html bookmark 3
        printCdsTools( $dbh, $gene_oid, $scaffold_oid, $taxon_oid,
               $start_coord, $end_coord, $strand );

        #if($img_internal ) {
        #    phyloDistSelect($gene_oid);
        #}
        print WebUtil::getHtmlBookmark ("homolog", "<h2>Homolog Display</h2>");

        #printHomologToolKit($gene_oid) if $locus_type eq "CDS";

        # html bookmark 4
        printCdsHomologs( $dbh, $taxon_oid, $data_type, $gene_oid );

        MetaGeneTable::printMostSimilarPatternSection
        ( $taxon_oid, $data_type, $gene_oid );
    }

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# getGeneProductName
############################################################################
sub getGeneProductName {
    my ( $dbh, $gene_oid, $gene_name, $cog_ref, $pfam_ref, $tigrfam_ref ) = @_;

    if (    blankStr($gene_name)
         || $gene_name =~ /unknown/
         || $gene_name =~ /hypothetic/ )
    {
        my $ids      = "";
        my $new_name = "";
        my $source   = "";

        # check TIGRfam
        if ( $tigrfam_ref && scalar(@$tigrfam_ref) > 0 ) {
            for my $t (@$tigrfam_ref) {
                my ( $gid, $tid, @rest ) = split( /\t/, $t );
                if ( !blankStr($ids) ) {
                    $ids .= ", ";
                }
                $ids .= "'" . $tid . "'";
            }

            my $sql = qq{
        select tr.ext_accession, tr.expanded_name
            from tigrfam tr
            where tr.ext_accession in ($ids)
        };
            my $cur = execSql( $dbh, $sql, $verbose );
            my @recs;
            for ( ; ; ) {
                my ( $id, $description ) = $cur->fetchrow();
                last if !$id;

                if ($source) {
                    $source .= ", " . $id;
                } else {
                    $source = $id;
                }
                if ($new_name) {
                    $new_name .= "; " . $description;
                } else {
                    $new_name = $description;
                }
            }
            $cur->finish();

            if ($new_name) {
                return ( $new_name, $source );
            }
        }    # end if tigrfam

        # check cog
        if ( $cog_ref && scalar(@$cog_ref) > 0 ) {
            my $t = $cog_ref->[0];
            if ($t) {
                my ( $gid, $cid, @rest ) = split( /\t/, $t );

                if ($cid) {
                    $ids    = $cid;
                    $source = $cid;

                    my $sql = qq{
            select c.cog_id, c.cog_name
                from cog c
                where c.cog_id = ?
            };
                    my $cur = execSql( $dbh, $sql, $verbose, $cid );
                    my ( $id, $description ) = $cur->fetchrow();
                    $new_name = $description;
                    $cur->finish();

                    if ($new_name) {
                        return ( $new_name, $source );
                    }
                }
            }
        }    # end if cog

        # check Pfam
        if ( $pfam_ref && scalar(@$pfam_ref) > 0 ) {
            for my $t (@$pfam_ref) {
                my ( $gid, $pid, @rest ) = split( /\t/, $t );
                if ( !blankStr($ids) ) {
                    $ids .= ", ";
                }
                $ids .= "'" . $pid . "'";
            }

            my $sql = qq{
        select p.ext_accession, p.description
            from pfam_family p
            where p.ext_accession in ($ids)
        };
            my $cur = execSql( $dbh, $sql, $verbose );
            my @recs;
            for ( ; ; ) {
                my ( $id, $description ) = $cur->fetchrow();
                last if !$id;

                if ($source) {
                    $source .= ", " . $id;
                } else {
                    $source = $id;
                }
                if ($new_name) {
                    $new_name .= "; " . $description;
                } else {
                    $new_name = $description;
                }
            }
            $cur->finish();

            if ($new_name) {
                return ( $new_name, $source );
            }
        }    # end if tigrfam
    }

    return ( $gene_name, '' );
}

############################################################################
# printMetaGeneInfo - Print metagenome gene information.
############################################################################
sub printMetaGeneInfo {
    my ( $gene_oid, $taxon_oid, $data_type, $cog_ref, $pfam_ref, $tigrfam_ref ) = @_;
    my $gene_oid_orig = $gene_oid;

    my $hash_file = $mer_data_dir . "/$taxon_oid/$data_type/taxon_hash.txt";
    my $fno = HashUtil::get_hash_code( $hash_file, "gene", $gene_oid );

    my (
         $gene_symbol,        $locus_type,        $locus_tag,      $gene_display_name, $img_product_source,
         $description,        $protein_seq_accid, $start_coord,    $end_coord,         $strand,
         $dna_seq_length,     $obsolete_flag,     $is_pseudogene,
         $img_orf_type,       $scaffold_oid,      $scaffold_name,  $chromosome,        $scf_seq_length,
         $taxon_display_name, $is_pangenome,      $gc_percent,     $est_copy,          $cds_frag_coord,
         $is_big_euk
    );

    if ( blankStr($gene_oid) ) {
        webError("Gene ID 2 $gene_oid_orig not found.");
    }

    # read gene info
    my @vals = MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
    my $line = join("\t", @vals);
    if ( scalar(@vals) == 0 ) {
        webError("Cannot find gene $gene_oid");
        return;
    }
    elsif ( scalar(@vals) <= 7 ) {
        ( $locus_type, $locus_tag, $gene_display_name, 
      $start_coord, $end_coord, $strand, $scaffold_oid )
        = split( /\t/, $line );
    } else {
        my $id2;
        ( $id2, $locus_type, $locus_tag, $gene_display_name,
      $start_coord, $end_coord, $strand, $scaffold_oid )
        = split( /\t/, $line );
    }

    my $seq = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
    my $gene_seq = "";
    if ( $strand eq '-' ) {
        $gene_seq = WebUtil::getSequence( $seq, $end_coord, $start_coord );
    } else {
        $gene_seq = WebUtil::getSequence( $seq, $start_coord, $end_coord );
    }
    my ( $a, $b, $c ) = gcContent($gene_seq);
    $gc_percent = sprintf( "%.2f", $c );

    my $dbh = dbLogin();

    printAttrRowRaw( "Gene ID", $gene_oid );
    printAttrRowRaw( "Gene Symbol",    nbspWrap($gene_symbol) );
    printAttrRowRaw( "Locus Tag",      $locus_tag );

    #    my ($new_name, $source) = getGeneProductName($dbh, $gene_oid,
    #                        $gene_display_name,
    #                        $cog_ref,
    #                        $pfam_ref,
    #                        $tigrfam_ref);

    my ($new_name, $source) = 
       MetaUtil::getGeneProdNameSource($gene_oid, $taxon_oid, $data_type);

    printAttrRowRaw( "Product Name", escHtml($new_name) );

    if ($source) {
        $img_product_source = $source;
    }
    printAttrRowRaw( "IMG Product Source", escHtml($img_product_source) )
      if $img_product_source ne "";
    printAttrRowRaw( "Description", nbspWrap($description) )
      if $description ne "";

    printAttrRowRaw( "Assembled/Unassembled", escHtml($data_type) );

    # get taxon name
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_display_name, t.is_pangenome 
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    ( $taxon_display_name, $is_pangenome ) = $cur->fetchrow();
    $cur->finish();
    #print "printMetaGeneInfo() sql=$sql; taxon_oid=$taxon_oid; taxon_display_name=$taxon_display_name<br/>\n";

    my $url = "$main_cgi?section=MetaDetail" 
        . "&page=metaDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    printAttrRowRaw( "Genome", $link );

    my $coords = "$start_coord..$end_coord";
    $coords .= GeneUtil::getMultFragCoordsLine( $dbh, $gene_oid, $cds_frag_coord );
    $coords .= " ($strand)";

    $dna_seq_length = $end_coord - $start_coord + 1;

    my $contact_oid = getContactOid();

    my $url = "$section_cgi&page=exportMetaGenes&exportType=nucleic";
    $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";
    $url .= "&gene_oid=$gene_oid&scaffold_oid=$scaffold_oid";
    $url .= "&strand=$strand&start_coord=$start_coord&end_coord=$end_coord";
    my $link = alink( $url, "${dna_seq_length}bp", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link exportMetaGenes']);" );

    my $scf_start  = 0;
    my $scf_end    = 0;
    my $scf_strand = "";
    my @genes_on_s = ();

    if ( $data_type eq 'assembled' && $scaffold_oid ) {
        ( $scf_start, $scf_end, $scf_strand ) = 
      MetaUtil::getScaffoldCoord($taxon_oid, $data_type, $scaffold_oid);
        $scf_seq_length = $scf_end - $scf_start + 1;
        @genes_on_s = MetaUtil::getScaffoldGenes($taxon_oid, $data_type, $scaffold_oid);
    }

    $scf_seq_length = length($seq);

    #if ($data_type eq 'assembled' && $end_coord > 0 && $scf_seq_length > 0) {
    printAttrRowRaw( "DNA Coordinates", $coords . "(" . $link . ")" );

    #}
    #else {
    #printAttrRowRaw("DNA Coordinates", $coords." (".$dna_seq_length."bp)");
    #}

    if ( $data_type eq 'assembled' && $scaffold_oid && $scf_seq_length > 0 ) {
        if ( !$scaffold_name ) {
            $scaffold_name = $scaffold_oid;
        }

        my $start_coord = $scf_start;
        if ($start_coord == 0) {
            $start_coord = 1;
        }
        my $url =
            "$main_cgi?section=MetaScaffoldGraph"
          . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
          . "&taxon_oid=$taxon_oid";
        $url .= "&start_coord=$start_coord&end_coord=$scf_end";
        $url .= "&marker_gene=$gene_oid&seq_length=$scf_seq_length";

        #        my $x = getBinInformation( $dbh, $gene_oid );
        my $x = "";
        my $link = alink( $url, "$scaffold_name (${scf_seq_length}bp) $x" );
        printAttrRowRaw( "Scaffold Source", $link );
    }

    printAttrRow( "Chromosome", $chromosome )
      if $chromosome ne "";

    printAttrRowRaw( "Pseudo Gene", "Yes" )
      if $is_pseudogene eq "Yes" || $img_orf_type eq "pseudo";
    printAttrRowRaw( "Obsolete", "Yes" ) if $obsolete_flag eq "Yes";

    printAttrRowRaw( "IMG ORF Type", nbspWrap($img_orf_type) );

    #    printPrevVersions( $dbh, $gene_oid );
    #    printNextVersions( $dbh, $gene_oid );
    # In case not precomputed.
    #    $gc_percent = getGcContent( $dbh, $gene_oid ) if $gc_percent == 0.0;
    printAttrRowRaw( "GC Content", $gc_percent )
      if $end_coord > 0 && $scf_seq_length > 0;
    my $link = alink( "$section_cgi&page=estCopyNote", '1' );

    # get est copy
    if ( $data_type eq 'assembled' ) {
        $est_copy = MetaUtil::getGeneEstCopy( $taxon_oid, $data_type, $gene_oid );
    }
    if ( !$est_copy ) {
        $est_copy = 1;
    }
    printAttrRowRaw( "Estimated Copy<sup>($link)</sup>", $est_copy )
      if $include_metagenomes;

    my $url = "$ncbi_entrez_base_url$protein_seq_accid";
    if ( $protein_seq_accid ne "" ) {
        if ( $protein_seq_accid =~ /:/ ) {
            printAttrRowRaw( "Accession", $protein_seq_accid );
        } else {
            my $checkurl = $regtransbase_check_base_url . $protein_seq_accid;
            my $ans      = urlGet($checkurl);
            my $str      = alink( $url, $protein_seq_accid );

            if ( $ans eq "1" ) {
                my $u = $regtransbase_base_url . $protein_seq_accid;
                $str = $str . " &nbsp; " . alink( $u, "RegTransBase" );
            }

            printAttrRowRaw( "Accession", $str );
        }
    }

    #    printGeneExtLinks( $dbh, $gene_oid,  $is_big_euk );

    #    printGoTerms( $dbh, $gene_oid );
    #    printNotes( $dbh, $gene_oid );

    # Amy: comment this out for my developer's site
    #    printGeneFeatures( $dbh, $gene_oid );

    if ( $data_type eq 'assembled' ) {
        printGeneBioCluster($dbh, $gene_oid, $taxon_oid);
    }

    return ( $is_pseudogene, $scaffold_oid, $taxon_oid, $start_coord, $end_coord, $strand );
}

############################################################################
# printExportGenes
############################################################################
sub printExportGenes {
    my ($gene_oid) = @_;

    if ( blankStr($gene_oid) ) {
        webError("Gene ID $gene_oid not found.");
    }

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    my $exportType = param("exportType");

    my $fna_faa = "faa";
    if ( $exportType eq 'nucleic' ) {
        $fna_faa = "fna";
    }

    my $scaffold_oid = param("scaffold_oid");
    my $line = "";
    if ( $fna_faa eq 'fna' ) {
        $line = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );

        my $strand      = param('strand');
        my $start_coord = param('start_coord');
        my $end_coord   = param('end_coord');
        my $gene_seq    = "";
        if ( $strand eq '-' ) {
            $gene_seq = WebUtil::getSequence($line, $end_coord, $start_coord);
        } else {
            $gene_seq = WebUtil::getSequence($line, $start_coord, $end_coord);
        }
        $line = $gene_seq;
    }
    else {
    $line = MetaUtil::getGeneFaa($gene_oid, $taxon_oid, $data_type);
    }

    my $seq = wrapSeq($line);

    print "<pre>\n";
    print "<font color='blue'>";
    print ">$gene_oid";
    print "</font>\n";
    print "$seq\n";
    print "</pre>\n";
}

############################################################################
# printGeneInfo - Print gene information.
############################################################################
sub printGeneInfo {
    my ( $dbh, $gene_oid ) = @_;
    my $gene_oid_orig = $gene_oid;
    my $rclause       = WebUtil::urClause('tx');
    my $imgClause     = WebUtil::imgClause('tx');
    my $sql           = qq{
        select g.gene_oid, g.gene_symbol, g.locus_type, 
           g.locus_tag, g.gene_display_name, g.img_product_source,
           g.description, g.protein_seq_accid,
           g.start_coord, g.end_coord, g.strand,
           g.dna_seq_length,
           g.obsolete_flag, g.is_pseudogene, g.img_orf_type,
           scf.scaffold_oid, scf.scaffold_name, g.chromosome, 
           ss.seq_length, tx.taxon_oid, tx.taxon_display_name, 
           tx.is_pangenome, g.gc_percent, g.est_copy, 
           g.cds_frag_coord,  tx.is_big_euk
        from scaffold scf, scaffold_stats ss, gene g,
           taxon tx
        where g.gene_oid = ?
           and g.scaffold = scf.scaffold_oid
           and scf.scaffold_oid = ss.scaffold_oid
           and g.scaffold = ss.scaffold_oid
           and g.gene_oid = $gene_oid
           and g.taxon = tx.taxon_oid
           $rclause
           $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my (
         $gene_oid,           $gene_symbol,    $locus_type,         $locus_tag,      $gene_display_name,
         $img_product_source, $description,    $protein_seq_accid,  $start_coord,    $end_coord,
         $strand,             $dna_seq_length, $obsolete_flag,
         $is_pseudogene,      $img_orf_type,   $scaffold_oid,       $scaffold_name,  $chromosome,
         $scf_seq_length,     $taxon_oid,      $taxon_display_name, $is_pangenome,   $gc_percent,
         $est_copy,           $cds_frag_coord, $is_big_euk
      )
      = $cur->fetchrow();
    $cur->finish();
    $gc_percent = sprintf( "%.2f", $gc_percent );

    if ( blankStr($gene_oid) ) {
        webError("Gene ID 3 $gene_oid_orig not found.");
    }

    printAttrRowRaw( "Gene ID", $gene_oid );
    printAttrRowRaw( "Gene Symbol",    nbspWrap($gene_symbol) );
    printAttrRowRaw( "Locus Tag",      $locus_tag );
    printAttrRowRaw( "Product Name",   escHtml($gene_display_name) );

    printSwissProt( $dbh, $gene_oid );
    printSeed( $dbh, $gene_oid );
    printImgTerms( $dbh, $gene_oid );

    printAttrRowRaw( "IMG Product Source", escHtml($img_product_source) )
      if $img_product_source ne "";
    printAttrRowRaw( "Description", nbspWrap($description) )
      if $description ne "";

    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    printAttrRowRaw( "Genome", $link );

    my $coords = "$start_coord..$end_coord";
    $coords .= GeneUtil::getMultFragCoordsLine( $dbh, $gene_oid, $cds_frag_coord );
    $coords .= " ($strand)";

    my $contact_oid = getContactOid();
    my $url = "$main_cgi?exportGenes=1&exportType=nucleic";
    $url .= "&gene_oid=$gene_oid&up_stream=0&down_stream=0";
    my $link = alink( $url, "${dna_seq_length}bp", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link exportGenes']);" );
    printAttrRowRaw( "DNA Coordinates", $coords . "(" . $link . ")" )
      if $end_coord > 0 && $scf_seq_length > 0;

    if ( $scf_seq_length > 0 ) {
        my $url = getScaffoldUrl( $gene_oid, $start_coord, $end_coord, $scaffold_oid, $scf_seq_length );
        my $x    = getBinInformation( $dbh, $gene_oid );
        my $link = alink( $url,             "$scaffold_name (${scf_seq_length}bp) $x" );
        printAttrRowRaw( "Scaffold Source", $link );
    }

    if ( lc($is_pangenome) eq "yes" ) {
        my $sql2 = qq{
          select gp.pangene_composition, g.gene_display_name 
          from gene_pangene_composition gp, gene g
          where gp.gene_oid = ?
            and g.gene_oid = gp.gene_oid  
        };
        my $cur = execSql( $dbh, $sql2, $verbose, $gene_oid );
        my $str;
        my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";
        while ( my ( $sourcegene, $name ) = $cur->fetchrow() ) {
            $str .= "<a href='$gurl$sourcegene'>$sourcegene</a> \n";
        }
        $cur->finish();
        printAttrRowRaw( "Gene Source", $str );
    }

    printAttrRow( "Chromosome", $chromosome )
      if $chromosome ne "";

    printAttrRowRaw( "Pseudo Gene", "Yes" )
      if $is_pseudogene eq "Yes" || $img_orf_type eq "pseudo";
    printAttrRowRaw( "Obsolete", "Yes" ) if $obsolete_flag eq "Yes";

    printAttrRowRaw( "IMG ORF Type", nbspWrap($img_orf_type) );
    printPrevVersions( $dbh, $gene_oid );
    printNextVersions( $dbh, $gene_oid );

    # In case not precomputed.
    $gc_percent = getGcContent( $dbh, $gene_oid ) if $gc_percent == 0.0;
    printAttrRowRaw( "GC Content", $gc_percent )
      if $end_coord > 0 && $scf_seq_length > 0;
    my $link = alink( "$section_cgi&page=estCopyNote", '1' );
    printAttrRowRaw( "Estimated Copy<sup>($link)</sup>", $est_copy )
      if $include_metagenomes;

    my $url = "$ncbi_entrez_base_url$protein_seq_accid";
    if ( $protein_seq_accid ne "" ) {
        if ( $protein_seq_accid =~ /:/ ) {
            printAttrRowRaw( "Accession", $protein_seq_accid );
        } else {
            my $checkurl = $regtransbase_check_base_url . $protein_seq_accid;
            my $ans      = urlGet($checkurl);
            my $str      = alink( $url, $protein_seq_accid );

            if ( $ans eq "1" ) {
                my $u = $regtransbase_base_url . $protein_seq_accid;
                $str = $str . " &nbsp; " . alink( $u, "RegTransBase" );
            }

            printAttrRowRaw( "Accession", $str );
        }
    }
    printGeneExtLinks( $dbh, $gene_oid, $is_big_euk );

    my $bf   = hasFusionComponent( $dbh, $gene_oid );
    my $link = "No";
    my $url  = "$section_cgi&page=fusionComponents&gene_oid=$gene_oid";
    $link = alink( $url, "Yes" ) if $bf;
    printAttrRowRaw( "Fused Gene", $link );

    if ( !$img_lite ) {
        my $bf   = isFusionComponent( $dbh, $gene_oid );
        my $link = "No";
        my $url  = "$section_cgi&page=fusionProteins&gene_oid=$gene_oid";
        $link = alink( $url, "Yes" ) if $bf;
        printAttrRowRaw( "Fusion Component", $link );
    }

    if ($snp_enabled) {
        my $sql3 = qq{
        select s.gene_oid, exp.exp_oid, exp.exp_name, count(*)
        from gene_snp s, snp_experiment exp
        where s.gene_oid = ?
        and s.experiment = exp.exp_oid
        };

        my $contact_oid = getContactOid();
        my $super_user  = 'No';
        if ($contact_oid) {
            $super_user = getSuperUser();
        }

        if ( !$contact_oid ) {
            $sql3 .= " and exp.is_public = 'Yes' ";
        } elsif ( $super_user ne 'Yes' ) {
            $sql3 .=
              " and (exp.is_public = 'Yes' or exp.exp_oid in "
            . " (select snp_exp_permissions from contact_snp_exp_permissions "
            . " where contact_oid = $contact_oid))";
        }

        $sql3 .= " group by s.gene_oid, exp.exp_oid, exp.exp_name ";

        my $cur3 = execSql( $dbh, $sql3, $verbose, $gene_oid );
        my ( $gid3, $exp_oid, $exp_name, $snp_cnt ) = $cur3->fetchrow();
        $cur3->finish();

        if ($gid3) {
            my $str3  = "$exp_name (SNP count: $snp_cnt) ";
            my $url3  = "$section_cgi&page=geneSnp"
              . "&gene_oid=$gene_oid&exp_oid=$exp_oid";
            my $link3 = alink( $url3, $str3 );
            printAttrRowRaw( "SNP", $link3 );
        }
    }

    printGoTerms( $dbh, $gene_oid );
    printNotes( $dbh, $gene_oid );

    # Amy: comment this out for my developer's site
    printGeneFeatures( $dbh, $gene_oid );

    return ( $is_pseudogene, $scaffold_oid, $taxon_oid );
}

############################################################################
# getGcContent - Get GC content on the fly.
############################################################################
sub getGcContent {
    my ( $dbh, $gene_oid, $is_rna ) = @_;

    my ($seq, @junk) = SequenceExportUtil::getGeneDnaSequence( $dbh, $gene_oid, '', '', $is_rna );
    if ( $is_rna ne "" && $seq eq "na" ) {
        return 0;
    }
    my $gc = sprintf( "%.2f", gcContent($seq) );
    return $gc;
}

############################################################################
# printMetaRnaInfo - Print RNA gene information.
############################################################################
sub printMetaRnaInfo {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    my ( $id2, $locus_type, $locus_tag, $gene_display_name,
     $start_coord, $end_coord, $strand, $scaffold_oid, $rna_source ) =
      MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );

    my $seq = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
    my $gene_seq = "";
    if ( $strand eq '-' ) {
        $gene_seq = WebUtil::getSequence( $seq, $end_coord, $start_coord );
    } else {
        $gene_seq = WebUtil::getSequence( $seq, $start_coord, $end_coord );
    }
    my ( $a, $b, $c ) = gcContent($gene_seq);
    my $gc_percent = sprintf( "%.2f", $c );

    # get taxon name
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_display_name, t.is_pangenome 
        from taxon t
        where t.taxon_oid = ?
            $rclause
            $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_display_name, $is_pangenome ) = $cur->fetchrow();
    $cur->finish();

    my ( $gene_symbol, @rest ) = split( /(\s+)/, $gene_display_name );
    printAttrRowRaw( "Gene ID", $gene_oid );
    printAttrRowRaw( "Gene Symbol",    nbspWrap($gene_symbol) );
    printAttrRowRaw( "Locus Tag",      $locus_tag );

    if ( $gene_display_name =~ /^RF/ ) {
        my $url = $rfam_base_url . $gene_display_name;
        $url = alink( $url, $gene_display_name );
        printAttrRowRaw( "Display Name", $url );
    } else {
        printAttrRowRaw( "Display Name", escHtml($gene_display_name) );
    }

    my $description = "";
    printAttrRowRaw( "Description", nbspWrap($description) );

    printAttrRowRaw( "Assembled/Unassembled", nbspWrap($data_type) );

    my $url = "$main_cgi?section=MetaDetail" 
        . "&page=metaDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_display_name );
    printAttrRowRaw( "Genome", $link );

    my $coords        = "$start_coord..$end_coord ";
    $coords .= "($strand)";

    my $contact_oid = getContactOid();
    my $url = "$section_cgi&page=exportMetaGenes&exportType=nucleic";
    $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";
    $url .= "&gene_oid=$gene_oid&scaffold_oid=$scaffold_oid";
    $url .= "&strand=$strand&start_coord=$start_coord&end_coord=$end_coord";
    my $dna_seq_length = $end_coord - $start_coord + 1;
    my $link = alink( $url, "${dna_seq_length}bp", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link exportMetaGenes']);" );
    printAttrRowRaw( "DNA Coordinates", $coords . "(" . $link . ")" )
      if $end_coord > 0;

    my $scf_start      = 0;
    my $scf_end        = 0;
    my $scf_strand     = "";
    my @genes_on_s     = ();
    my $scf_seq_length = 0;

    if ( $data_type eq 'assembled' && $scaffold_oid ) {
        ( $scf_start, $scf_end, $scf_strand ) = 
      MetaUtil::getScaffoldCoord( $taxon_oid, $data_type, $scaffold_oid );
        $scf_seq_length = $scf_end - $scf_start + 1;
        @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );
    }

    my $scaffold_name = $scaffold_oid;

    if ( $data_type eq 'assembled' && $scaffold_oid && $scf_seq_length > 0 ) {

        my $url =
            "$main_cgi?section=MetaScaffoldGraph"
          . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
          . "&taxon_oid=$taxon_oid";
        $url .= "&start_coord=$scf_start&end_coord=$scf_end";
        $url .= "&marker_gene=$gene_oid&seq_length=$scf_seq_length";

        #        my $x = getBinInformation( $dbh, $gene_oid );
        my $x = "";
        my $link = alink( $url, "$scaffold_name (${scf_seq_length}bp) $x" );
        printAttrRowRaw( "Scaffold Source", $link );
    }

    printAttrRowRaw( "GC Content", $gc_percent );

    #    printGeneExtLinks( $dbh, $gene_oid, $is_big_euk );
    #    printGoTerms( $dbh, $gene_oid );
    #    printNotes( $dbh, $gene_oid );
    #    printGeneFeatures( $dbh, $gene_oid );

    #$dbh->disconnect();


    # get est copy
    my $est_copy;
    if ( $data_type eq 'assembled' ) {
        $est_copy = MetaUtil::getGeneEstCopy( $taxon_oid, $data_type, $gene_oid );
    }
    if ( !$est_copy ) {
        $est_copy = 1;
    }
    my $link = alink( "$section_cgi&page=estCopyNote", '1' );
    printAttrRowRaw( "Estimated Copy<sup>($link)</sup>", $est_copy );


    return ( $scaffold_oid, $taxon_oid, $start_coord, $end_coord, $strand, $gene_display_name );

}

############################################################################
# printProteinInfo - Print gene information.
############################################################################
sub printProteinInfo {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $gene_display_name,
     $aa_seq_length, $cog_ref, $pfam_ref, $tigrfam_xref ) = @_;

    return if $aa_seq_length == 0;

    my $url = "$section_cgi&page=genePageMainFaa"
        . "&taxon_oid=$taxon_oid&data_type=$data_type"
        . "&gene_oid=$gene_oid";

    my $link = alink( $url, "${aa_seq_length}aa" );
    $link = "0aa" if $aa_seq_length == 0;
    printAttrRowRaw( "Amino Acid Sequence Length", $link );

    # printAttrRowRaw( "Amino Acid Sequence Length", $aa_seq_length . "aa" );
    # printAltTranscripts( $dbh, $gene_oid );
    printCogName( $dbh, $gene_oid, $taxon_oid, $data_type, $cog_ref );

    if ($img_internal) {
        # printCogFuncDefn( $dbh, $gene_oid );
    }

    printGeneXrefFamilies( $dbh, $gene_oid, $tigrfam_xref );

    #    printStructureXref( $dbh, $gene_oid );
    #    printTmHmm( $dbh, $gene_oid );
    #    printSignalp( $dbh, $gene_oid );

    my $statisticsstr = "";
    my $url = "$section_cgi&page=pepstats&gene_oid=$gene_oid";
    $statisticsstr .= alink( $url, "peptide" );

    #    printAttrRowRaw( "Statistics", $statisticsstr );

    printProteinPfam( $dbh, $gene_oid, $taxon_oid, $data_type, $pfam_ref );

    #    if ($img_internal) {
    #        printTigrfamsMainRole( $dbh, $gene_oid, $taxon_oid, $data_type );
    #    }

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name, tx.in_file, tx.genome_type
        from taxon tx
        where tx.taxon_oid = ?
        $rclause
        $imgClause
    };
    #print "printProteinInfo() sql=$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $t_oid, $taxon_name, $in_file, $genome_type ) = $cur->fetchrow();
    $cur->finish();
    if ( !$t_oid ) {
        return;
    }

    my $expression_studies = "";

    # see if there is any proteomic data:
    my $proteincount = 1;
    if ( $proteincount > 0 ) {
        if ( $in_file eq "Yes" ) {
            $proteincount = 0;
            #$proteincount = MetaUtill::hasProteinData($gene_oid, $taxon_oid);
        } else {
            #print "printProteinInfo() taxon_oid=$taxon_oid in_file=$in_file gene_oid=$gene_oid<br/>\n";
            my $sql = qq{
                select count (distinct pig.protein_oid)
                from ms_protein_img_genes pig
                where pig.gene = ?
            };
            my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            $proteincount = $cur->fetchrow();
            $cur->finish();
        }

        if ( $proteincount > 0 ) {
            my $url = "$main_cgi?section=IMGProteins" 
            . "&page=geneproteins&gene_oid=$gene_oid";
            $expression_studies .= alink( $url, "protein" );
        }
    }

    # see if there is any rnaseq data:
    my $rnaseqcount = 1;
    my $rnaseq_data = $env->{rnaseq};
    if ( !$rnaseq_data ) {
        $rnaseqcount = 0;
    }
    if ( $rnaseqcount > 0 ) {
    $rnaseqcount = MetaUtil::hasRNASeq( $gene_oid, $taxon_oid );

    if ($rnaseqcount < 1 && $genome_type ne "metagenome" &&
        isInt($gene_oid) ) {
            my $sql = qq{
                select es.reads_cnt
                from rnaseq_expression es
                where es.IMG_gene_oid = ?
            };
            my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            $rnaseqcount = $cur->fetchrow();
            $cur->finish();
        }
        if ( $rnaseqcount > 0 ) {
            my $url = "$main_cgi?section=RNAStudies&page=genereads" 
            . "&gene_oid=$gene_oid&taxon_oid=$taxon_oid";
            if ( $expression_studies ne "" ) {
                $expression_studies .= ", ";
            }
            $expression_studies .= alink( $url, "rnaseq" );
        }
    }
    if ( $proteincount > 0 || $rnaseqcount > 0 ) {
        printAttrRowRaw( "Expression", $expression_studies );
    }
}

sub printSwissProt {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
    select $nvl(product_name, 'n/a'), source
        from gene_swissprot_names
        where gene_oid = ?
        order by product_name, source
    };

    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>SwissProt Protein Product</th>\n";
    print "<td class='img'>\n";

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $name, $source ) = $cur->fetchrow();
        last if !$name;
        $count++;
        $source =~ s/\s+//g;
        my @list = split( /;/, $source );

        print "$name &nbsp;";
        my $cnt = 0;
        foreach my $src (@list) {
            my $url = $swissprot_source_url . $src;
            $url = alink( $url, $src );
            if ( $cnt > 5 ) {
                $cnt = 0;
                print "<br/>";
            }
            print "$url &nbsp;";
            $cnt++;
        }
        print "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

sub printSeed {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
    select $nvl(product_name, 'n/a'), source, subsystem
        from gene_seed_names
        where gene_oid = ?
        order by product_name, source
    };

    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>SEED</th>\n";
    print "<td class='img'>\n";

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $name, $source, $subsystem ) = $cur->fetchrow();
        last if !$name;
        $count++;
        print "[$name] &nbsp; $source &nbsp; $subsystem <br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printGenePageFaa - Print gene page amino acid display.
#   Include alternate s.
############################################################################
sub printGenePageFaa {
    my $gene_oid = param("gene_oid");

    my $dbh = dbLogin();

    print "<pre>\n";

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag,
            g.gene_symbol, g.protein_seq_accid, g.aa_residue, 
            scf.scaffold_name
        from  gene g, taxon tx, scaffold scf
        where g.gene_oid = ?
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.aa_residue is not null
            and g.aa_seq_length > 0
    };
    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $protein_seq_accid, $aa_residue, $scaffold_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        my $seq = wrapSeq($aa_residue);
        print "<font color='blue'>";
        my $ids;
        $ids .= "$protein_seq_accid " if !blankStr($protein_seq_accid);

        print ">$gene_oid $ids$gene_display_name [$scaffold_name]";
        print "</font>\n";
        print "$seq\n";
    }
    $cur->finish();

    my $sql = qq{
        select g.gene_oid, at.name, g.locus_tag, g.gene_symbol, 
            at.ext_accession, at.alt_transcript_oid, 
            at.aa_residue, scf.scaffold_name
        from alt_transcript at, gene g, taxon tx, scaffold scf
        where g.gene_oid = ?
            and g.gene_oid = at.gene
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and at.aa_residue is not null
            and at.aa_seq_length > 0
        order by at.alt_transcript_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $ext_accession, $alt_transcript_oid, $aa_residue,
             $scaffold_name )
          = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( blankStr($aa_residue) ) {
            webLog("printGenePageFaa() aa_residue not found for gene_oid=$gene_oid\n");
            next;
        }
        my $seq = wrapSeq($aa_residue);
        print "<font color='blue'>";
        my $ids;
        $ids .= "$ext_accession " if !blankStr($ext_accession);

        #$ids .= "$locus_tag "  if !blankStr( $locus_tag );
        #$ids .= "$gene_symbol "  if !blankStr( $gene_symbol );
        print ">${gene_oid}_${alt_transcript_oid} (alt. $count) ";
        print "$ids$gene_display_name [$scaffold_name]";
        print "</font>\n";
        print "$seq\n";
    }
    $cur->finish();

    print "</pre>\n";
    #$dbh->disconnect();
}

############################################################################
# printGenePageMainFaa - Print gene page main amino acid display.
############################################################################
sub printGenePageMainFaa {
    my $gene_oid = param("gene_oid");
    if ( blankStr($gene_oid) ) {
        webError("Gene ID $gene_oid not found.");
    }

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    my $faa = MetaUtil::getGeneFaa($gene_oid, $taxon_oid, $data_type);
    my $seq = wrapSeq($faa);

    print "<pre>\n";
    print "<font color='blue'>";
    print ">$gene_oid";
    print "</font>\n";
    print "$seq\n";
    print "</pre>\n";
}

############################################################################
# printGenePageAltFaa - Print gene page alternative amino acid display.
############################################################################
sub printGenePageAltFaa {
    my $gene_oid           = param("gene_oid");
    my $alt_transcript_oid = param("alt_transcript_oid");

    my $dbh = dbLogin();

    print "<pre>\n";

    my $sql = qq{
        select g.gene_oid, at.name, g.locus_tag, g.gene_symbol, 
           at.ext_accession, at.alt_transcript_oid, at.aa_residue, 
           scf.scaffold_name
        from alt_transcript at, gene g, taxon tx, scaffold scf
        where at.alt_transcript_oid = $alt_transcript_oid
        and at.gene = ?
        and g.gene_oid = at.gene
        and g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and at.aa_residue is not null
        and at.aa_seq_length > 0
        order by at.alt_transcript_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $ext_accession, $alt_transcript_oid, $aa_residue,
             $scaffold_name )
          = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( blankStr($aa_residue) ) {
            webLog("printGenePageAltFaa() aa_residue not found for gene_oid=$gene_oid\n");
            next;
        }
        my $seq = wrapSeq($aa_residue);
        print "<font color='blue'>";
        my $ids;
        $ids .= "$ext_accession " if !blankStr($ext_accession);

        #$ids .= "$locus_tag "  if !blankStr( $locus_tag );
        #$ids .= "$gene_symbol "  if !blankStr( $gene_symbol );
        print ">${gene_oid}_${alt_transcript_oid} (alt. $count) ";
        print "$ids$gene_display_name [$scaffold_name]";
        print "</font>\n";
        print "$seq\n";
    }
    $cur->finish();

    print "</pre>\n";
    #$dbh->disconnect();
}

############################################################################
# printAddQueryGene - Print code for adding query gene to gene cart.
############################################################################
sub printAddQueryGene {
    my ( $gene_oid, $aa_seq_length ) = @_;

    print start_form( -name   => "addQueryGeneForm",
                      -action => $main_cgi );
    print hiddenVar( "gene_oid", $gene_oid );
    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit(
                  -name  => $name,
                  -value => "Add To Gene Cart",
                  -class => "medbutton"
    );

    return if ( $aa_seq_length < 1 );

    my $contact_oid     = getContactOid();
    my $super_user_flag = "";
    if ( $contact_oid > 0 ) {
        $super_user_flag = getSuperUser();
    }

    # find missing enzymes
    print nbsp(1);
    my $name = "_section_MissingGenes_geneKOEnzymeList";
    print submit(
                  -name  => $name,
                  -value => "Find Candidate Enzymes",
                  -class => "medbutton"
    );

    if ( $show_myimg_login && $contact_oid > 0 ) {
        if ( $super_user_flag eq 'Yes' ) {
            print nbsp(1);
            my $name = "_section_MyIMG_showGeneAnnotation";
            print submit(
                          -name  => $name,
                          -value => "Show All User Annotations",
                          -class => "medbutton"
            );
        }
    }

    # Victor wants 'find product name' function
    # to be available to public IMG as well
    print WebUtil::getHtmlBookmark
    ( "candidate", "<h2>Find Candidate Product Name</h2>" );

    print "<p>\n";
    print "Display Option: ";
    print nbsp(1);
    print "<select name='findProdNameOption'>\n";
    print "<option value='showAll' selected>Show All</option>\n";
    print "<option value='hideHypothetical'>Hide Hypothetical Protein</option>\n";
    print "</select>\n";

    print nbsp(2);
    my $name = "_section_MissingGenes_findProdName";
    print submit(
                  -name  => $name,
                  -value => "Find Candidate Product Name",
                  -class => "medbutton"
    );

    print "</p>\n";
    print end_form();
    print "\n <!-- end addQueryGeneForm form  -->\n";

}

############################################################################
# printPathwayInfo - Print gene information.
############################################################################
sub printPathwayInfo {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    printEnzymes( $dbh, $gene_oid, $taxon_oid, $data_type );

    my $ko_list = printKoTerm( $dbh, $gene_oid, $taxon_oid, $data_type );
    if ($ko_list) {
        printKeggPathways( $dbh, $gene_oid, $taxon_oid, $data_type, $ko_list );
    }

    printKeggModules( $dbh, $gene_oid, $taxon_oid, $data_type, $ko_list );
    printMetaCycPathways( $dbh, $gene_oid, $taxon_oid, $data_type );
}

############################################################################
# printMyIMGInfo
############################################################################
sub printMyIMGInfo {
    my ( $dbh, $gene_oid, $contact_oid ) = @_;

    my $sql = qq{
        select g.gene_oid, ann.product_name, ann.prot_desc,
        ann.ec_number, ann.pubmed_id, ann.inference,
        ann.is_pseudogene, ann.notes, ann.gene_symbol,
        c.username, to_char(ann.mod_date, 'yyyy-mm-dd')
        from gene g, gene_myimg_functions ann, Contact c
        where g.gene_oid = ?
        and g.gene_oid = ann.gene_oid
        and ann.modified_by = c.contact_oid
        and c.contact_oid = $contact_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my (
         $gene_oid,      $product_name, $prot_desc,   $ec_number,    $pubmed_id, $inference,
         $is_pseudogene, $notes,        $gene_symbol, $contact_name, $mod_date
      )
      = $cur->fetchrow();
    $cur->finish();

    printAttrRowRaw( "Product Name", $product_name );
    printAttrRowRaw( "Prot Desc",    $prot_desc );
    printAttrRowRaw( "EC Number",    $ec_number );

    #printMyIMGKeggPathways( $dbh, $gene_oid, $contact_oid );
    printAttrRowRaw( "PUBMED ID",       $pubmed_id );
    printAttrRowRaw( "Inference",       $inference );
    printAttrRowRaw( "Is Pseudo Gene?", $is_pseudogene );
    printAttrRowRaw( "Notes",           $notes );
    printAttrRowRaw( "Gene Symbol",     $gene_symbol );
    printAttrRowRaw( "Last Modified",   $contact_name . " (" . $mod_date . ")" );
}

############################################################################
# getScaffoldUrl - Get URL for scaffold link.
############################################################################
sub getScaffoldUrl {
    my ( $gene_oid0, $start_coord0, $end_coord0, $scaffold_oid, $scf_seq_length ) = @_;

    return "" if $scaffold_oid == 0;

    my $scf_start_coord = $start_coord0 - $large_flank_length;
    my $scf_end_coord   = $end_coord0 + $large_flank_length;
    $scf_start_coord = $scf_start_coord > 1             ? $scf_start_coord : 1;
    $scf_end_coord   = $scf_end_coord > $scf_seq_length ? $scf_seq_length  : $scf_end_coord;

    my $url = "$main_cgi?section=ScaffoldGraph" . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid";
    $url .= "&start_coord=$scf_start_coord&end_coord=$scf_end_coord";
    $url .= "&marker_gene=$gene_oid0&seq_length=$scf_seq_length";
    return $url;
}

############################################################################
# printPrevVersions - Print alternate versions of the gene.
############################################################################
sub printPrevVersions {
    my ( $dbh, $gene_oid ) = @_;
    my $rclause   = WebUtil::urClause('g2.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql       = qq{
       select pv.prev_version, g2.start_coord, g2.end_coord, g2.strand,
           g2.dna_seq_length, g2.aa_seq_length
       from gene_prev_versions pv, gene g2
       where pv.gene_oid = ?
           and pv.prev_version = g2.gene_oid
           $rclause
           $imgClause
       order by pv.prev_version
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $start_coord, $end_coord, $strand, $dna_seq_length, $aa_seq_length ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$start_coord\t";
        $r .= "$end_coord\t";
        $r .= "$strand\t";
        $r .= "$dna_seq_length\t";
        $r .= "$aa_seq_length\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $nRecs = @recs;
    if ( $nRecs > 0 ) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>Previous Version(s)</th>\n";
        print "<td class='img'>\n";
        for my $r (@recs) {
            my ( $gene_oid, $start_coord, $end_coord, $strand, $dna_seq_length, $aa_seq_length ) = split( /\t/, $r );
            my $url = "$section_cgi&page=geneDetail&gene_oid=$gene_oid";
            print alink( $url, $gene_oid );
            print nbsp(1);
            my $len = "${aa_seq_length}aa";
            $len = "${dna_seq_length}bp" if $aa_seq_length == 0;
            print "$start_coord..$end_coord($strand) ($len)<br/>\n";
        }
        print "</td>\n";
        print "</tr>\n";
    }
}

############################################################################
# printNextVersions - Print alternate versions of the gene.
############################################################################
sub printNextVersions {
    my ( $dbh, $gene_oid ) = @_;
    my $rclause   = WebUtil::urClause('g2.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql       = qq{
       select pv.gene_oid, g2.start_coord, g2.end_coord, 
           g2.strand, g2.dna_seq_length, g2.aa_seq_length
       from gene_prev_versions pv, gene g2
       where pv.prev_version = ?
           and pv.gene_oid = g2.gene_oid
           $rclause
           $imgClause
       order by pv.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $start_coord, $end_coord, $strand, $dna_seq_length, $aa_seq_length ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$start_coord\t";
        $r .= "$end_coord\t";
        $r .= "$strand\t";
        $r .= "$dna_seq_length\t";
        $r .= "$aa_seq_length\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $nRecs = @recs;
    if ( $nRecs > 0 ) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>Next Version(s)</th>\n";
        print "<td class='img'>\n";
        for my $r (@recs) {
            my ( $gene_oid, $start_coord, $end_coord, $strand, $dna_seq_length, $aa_seq_length ) = split( /\t/, $r );
            my $url = "$section_cgi&page=geneDetail&gene_oid=$gene_oid";
            print alink( $url, $gene_oid );
            print nbsp(1);
            my $len = "${aa_seq_length}aa";
            $len = "${dna_seq_length}bp" if $aa_seq_length == 0;
            print "$start_coord..$end_coord($strand) ($len)<br/>\n";
        }
        print "</td>\n";
        print "</tr>\n";
    }
}

############################################################################
# printGeneExtLinks - Print external links information.
############################################################################
sub printGeneExtLinks {
    my ( $dbh, $gene_oid, $is_big_euk ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead'>External Links</th>\n";

    my $sql = qq{
        select distinct db_name, id, custom_url
        from gene_ext_links
        where gene_oid = ?
        order by db_name, id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    print "<td class='img'>\n";
    my $count = 0;
    my $s;

    for ( ; ; ) {
        my ( $db_name, $id, $custom_url ) = $cur->fetchrow();
        last if !$id;
        my $dbId = "$db_name:$id";
        if ( $db_name eq "GI" && $ncbi_entrez_base_url ne "" ) {
            my $url = "$ncbi_entrez_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";

        } elsif ( $db_name eq "GenBank" && $ncbi_entrez_base_url ne "" ) {
            my $url = "$ncbi_entrez_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "GeneID" && $geneid_base_url ne "" ) {
            my $url = "$geneid_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
            if ( $is_big_euk eq "Yes" ) {
                my $url = "$ncbi_mapview_base_url$id";
                $s .= alink( $url, "MapView/$dbId" );
                $s .= "; ";
            }
        } elsif ( $db_name =~ /UniProt/ && $nice_prot_base_url ne "" ) {
            my $url = "$nice_prot_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ($enable_interpro && $db_name =~ /InterPro/ && $ipr_base_url ne "" ) {
            my $url = "$ipr_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";

        } elsif ($enable_interpro && $db_name =~ /SUPERFAMILY/ ) {
            my $url = "$ipr_base_url2$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";

        } elsif ($enable_interpro && $db_name =~ /ProSiteProfiles/  ) {
            my $url = "$ipr_base_url3$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";

        } elsif ($enable_interpro && $db_name =~ /SMART/  ) {
            my $url = "$ipr_base_url4$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";

            
        } elsif ( $db_name eq "UniGene" ) {
            my ( $org, $id2 ) = split( /\./, $id );
            my $url = "$unigene_base_url?ORG=$org&CID=$id2";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "TAIR" ) {
            my $url = "$tair_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "WormBase" ) {
            my $url = "$wormbase_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "ZFIN" ) {
            my $url = "$zfin_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "FLYBASE" ) {
            my $url = "$flybase_base_url$id.html";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "HGNC" ) {
            my $url = "$hgnc_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "MGI" ) {
            my $url = "$mgi_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "RGD" ) {
            my $url = "$rgd_base_url$id";
            $s .= alink( $url, "$dbId" );
            $s .= "; ";
        } elsif ( $db_name eq "gene_oid" ) {
            my $sql2 = qq{
               select tx2.taxon_display_name
               from gene g2, taxon tx2
               where g2.gene_oid = ?
               and g2.taxon = tx2.taxon_oid
            };
            my $cur2 = execSql( $dbh, $sql2, $verbose, $id );
            my ($pr_taxon_display_name) = $cur2->fetchrow();
            my $x = " [[proxy from $pr_taxon_display_name]]";

            #$cur2->finish();
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
            $url .= "&gene_oid=$id";
            $s .= alink( $url, $id ) . "$x; ";
        } elsif ( $db_name eq "read_id" ) {
            $s .= "$id; ";
        } elsif ( $custom_url =~ /^http/ ) {
            $s .= alink( $custom_url, $id ) . "; ";
        }
    }
    chop $s;
    chop $s;
    print "$s\n";
    $cur->finish();
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# hasFusionComponent - Has fusion components.
############################################################################
sub hasFusionComponent {
    my ( $dbh, $gene_oid ) = @_;

    my $rclause = urClause("gfc.taxon");
    my $sql     = qq{
       select count(*)
       from gene_fusion_components gfc
       where gfc.gene_oid = ?
       $rclause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($x) = $cur->fetchrow();
    $cur->finish();
    return $x;
}

############################################################################
# isFusionComponent - Is a fusion component.
############################################################################
sub isFusionComponent {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
       select count(*)
       from gene_all_fusion_components gfc
       where gfc.component = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($x) = $cur->fetchrow();
    $cur->finish();
    return $x;
}

############################################################################
# printCogName - Print COG name.
############################################################################
sub printCogName {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $cog_ref ) = @_;

    if ( !$cog_ref || scalar(@$cog_ref) == 0 ) {
        return;
    }
    my $line = $cog_ref->[0];

    my ( $gid2, $cog_id, $perc_identity, $align_length, $q_start, $q_end, $s_start, $s_end, $evalue, $bit_score, $rank ) =
      split( /\t/, $line );

    if ( !$cog_id ) {
        return;
    }

    my $sql = qq{
       select c.cog_id, c.cog_name
       from cog c
       where c.cog_id = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ( $c2_id, $cog_name ) = $cur->fetchrow();

    print "<tr class='img'>\n";
    print "<th class='subhead'>COG</th>\n";
    print "<td class='img'>\n";

    my $url = "$cog_base_url$cog_id";
    print alink( $url, $cog_id );
    print escHtml(" - $cog_name");
    print "<br/>\n";

    print nbsp(1) if !$cog_name;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printKoTerm - Print KO term.
############################################################################
sub printKoTerm {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;
    my @kos = MetaUtil::getGeneKoId( $gene_oid, $taxon_oid, $data_type );
    my $ko_list = "";

    for my $ko_id (@kos) {
        if ($ko_list) {
            $ko_list .= ", '" . $ko_id . "'";
        } else {
            $ko_list = "'" . $ko_id . "'";
        }
    }

    if ( !$ko_list ) {
        return "";
    }

    my $sql = qq{
       select kt.ko_id, kt.ko_name, kt.definition
       from ko_term kt
       where kt.ko_id in ( $ko_list )
       order by kt.definition
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my %done;
    my $count = 0;
    print "<tr class='img'>\n";

    #print "<th class='subhead'>KEGG Ontology Term</th>\n";
    print "<th class='subhead'>KEGG Orthology (KO) Term</th>\n";
    print "<td class='img'>\n";
    for ( ; ; ) {
        my ( $ko_id, $ko_name, $definition ) = $cur->fetchrow();
        last if !$ko_id;
        $count++;

        #my $tmp = $ko_id;
        #$tmp =~ s/KO://;
        # my $url = $kegg_orthology_url . $tmp;
        #        my $url =
        #            "main.cgi?section=KeggPathwayDetail&page=koterm2&ko_id=$ko_id"
        #          . "&gene_oid=$gene_oid";

        my ( $ko1, $ko2 ) = split( /\:/, $ko_id );
        my $url = "$enzyme_base_url" . "ko+" . $ko2;
        $url = alink( $url, "$ko_id" ) . " $ko_name $definition";

        #print escHtml( "$ko_id - $definition" );
        print "$url <br/>";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();

    return $ko_list;
}

############################################################################
# printGoTerms - Show GO terms if they exist.
############################################################################
sub printGoTerms {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select ggt.gene_oid, gt.go_id, gt.go_term, gt.go_type, ggt.go_evidence
       from gene_go_terms ggt, go_term gt
       where ggt.gene_oid = ?
       and ggt.go_id = gt.go_id
       and gt.go_type = 'molecular_function'
       order by gt.go_type, gt.go_term
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $go_id, $go_term, $go_type, $go_evidence ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$go_id\t";
        $r .= "$go_term\t";
        $r .= "$go_type\t";
        $r .= "$go_evidence\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    print "<th class='subhead'>GO Terms</th>\n";
    print "<td class='img'>\n";
    for my $r (@recs) {
        my ( $go_id, $go_term, $go_type, $go_evidence ) = split( /\t/, $r );
        my $url = "$go_base_url$go_id";
        print alink( $url, $go_id );
        print " - ";
        my $x;
        $x = " [evidence=$go_evidence]" if $go_evidence ne "";
        my $link = alink( $go_evidence_url, $go_evidence );
        $x = " [evidence=$link]"
          if $go_evidence ne "" && $go_evidence_url ne "";
        print escHtml($go_term) . "$x<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printGeneXrefFamilies - Print external protein families.
############################################################################
sub printGeneXrefFamilies {
    my ( $dbh, $gene_oid, $tigrfam_ref ) = @_;

    my $tigrfam_list = "";
    my %tigrfam_score;

    for my $t (@$tigrfam_ref) {
        my ( $gid2, $tigrfam_id, $bit_score, @rest ) = split( /\t/, $t );
        if ($tigrfam_list) {
            $tigrfam_list .= ", '" . $tigrfam_id . "'";
        } else {
            $tigrfam_list = "'" . $tigrfam_id . "'";
        }

        $tigrfam_score{$tigrfam_id} = $bit_score;
    }

    if ( blankStr($tigrfam_list) ) {
        return;
    }

    my $sql = qq{
    select tr.ext_accession, tr.expanded_name
        from tigrfam tr
        where tr.ext_accession in ($tigrfam_list)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $id, $description ) = $cur->fetchrow();
        last if !$id;
        my $r = "$id\t";
        $r .= "$description\t";
        push( @recs, $r );
    }
    $cur->finish();

    my $count = @recs;
    return if $count == 0;

    my $contact_oid = getContactOid();

    print "<tr class='img'>\n";
    print "<th class='subhead'>Families</th>\n";
    print "<td class='img'>\n";
    my $db_name = "TIGRFam";
    for my $r (@recs) {
        my ( $id, $description ) = split( /\t/, $r );
        print "- " . nbsp(1);
        my $link = "$db_name:$id";
        if ($enable_interpro && $db_name eq "InterPro" ) {
            my $url = "$ipr_base_url$id";
            $link = alink( $url, $id );

        } elsif ($enable_interpro && $db_name eq 'SUPERFAMILY' ) {
            my $url = "$ipr_base_url2$id";
            $link = alink( $url, $id );
        } elsif ($enable_interpro && $db_name eq 'ProSiteProfiles'  ) {
            my $url = "$ipr_base_url3$id";
            $link = alink( $url, $id );

        } elsif ($enable_interpro && $db_name eq 'SMART'  ) {
            my $url = "$ipr_base_url4$id";
            $link = alink( $url, $id );
            
        } elsif ( $db_name eq "TIGRFam" ) {
            my $url = "$tigrfam_base_url$id";
            $link = alink( $url, $id );
        } elsif ( $db_name eq "PIRSF" ) {
            my $url = "$pirsf_base_url$id";
            $link = alink( $url, $id );
        }
        my $x;
        if ( $db_name eq "TIGRFam" && $contact_oid > 0 ) {
            my $bit_score = $tigrfam_score{$id};
            my $tc        = "";
            if ( $bit_score ne "" && $tc ne "" && $bit_score < $tc ) {
                $x = " <font color='red'>(WARNING: ";
                $x .= "bit_score=$bit_score < trusted_cutoff=$tc)";
                $x .= "</font>";
            } elsif ($bit_score) {
                $x .= " (bit_score=$bit_score)";
            }
        }
        print $link;
        print nbsp(1);
        print escHtml($description) . "$x<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# getTfamScores - Get tigrfam bit score and trusted cutoff.
############################################################################
sub getTfamScores {
    my ( $dbh, $gene_oid, $tfam_id ) = @_;

    my $sql = qq{
        select gtf.bit_score, tf.ls_tc_model
        from gene_tigrfams gtf, tigrfam tf
        where gtf.ext_accession = tf.ext_accession
        and gtf.gene_oid = ?
        and tf.ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $tfam_id );
    my ( $bit_score, $tc ) = $cur->fetchrow();
    $cur->finish();
    return ( $bit_score, $tc );
}

############################################################################
# printStructureXref - Print external protein families.
############################################################################
sub printStructureXref {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select gpx.gene_oid, gpx.db_name, gpx.id
      from gene_pdb_xrefs gpx
      where gpx.gene_oid = ?
      order by gpx.db_name, gpx.id
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $db_name, $id ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$db_name\t";
        $r .= "$id\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    print "<th class='subhead'>Structure Links</th>\n";
    print "<td class='img'>\n";
    my $s;
    for my $r (@recs) {
        my ( $gene_oid, $db_name, $id ) = split( /\t/, $r );
        my $link = "$db_name:$id";
        if ( $db_name eq "PDB" ) {
            my ( $id2, $chain2 ) = split( /:/, $id );
            my $url = "$pdb_base_url$id2&chainId=$chain2";
            $link = alink( $url, $id );
        }
        $s .= "$link; ";
    }
    chop $s;
    chop $s;
    print "$s\n";
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printNotes - Print out notes.
#    Some of the '/tag="value"' stuff is absorbed by gene_feature_tags.
############################################################################
sub printNotes {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select gn.gene_oid, gn.notes
       from gene_notes gn
       where gn.gene_oid = ?
       and gn.notes not like '/%=%'
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $notes ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$notes\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    print "<th class='subhead'>Notes</th>\n";
    print "<td class='img'>\n";
    for my $r (@recs) {
        my ( $gene_oid, $notes ) = split( /\t/, $r );
        print "-" . nbsp(1);
        print escHtml($notes) . "<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}
############################################################################
# printGeneFeatures - Show tag features.
############################################################################
sub printGeneFeatures {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select gft.gene_oid, gft.tag, gft.value, gft.notes
       from gene_feature_tags gft
       where gft.gene_oid = ?
       order by gft.tag, gft.value
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $tag, $value, $notes ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$tag\t";
        $r .= "$value\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    print "<th class='subhead'>Features</th>\n";
    print "<td class='img'>\n";
    for my $r (@recs) {
        my ( $gene_oid, $tag, $value, $notes ) = split( /\t/, $r );
        print "/$tag =" . nbsp(1);
        my $val2 = "\"$value\"";
        $val2 .= " ($notes)" if $notes ne "";
        print escHtml($val2) . "<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printGeneBioCluster
############################################################################
sub printGeneBioCluster {
    my ( $dbh, $gene_oid, $taxon_oid ) = @_;

#    my $sql = qq{
#       select bcg.biosynthetic_oid
#       from biosynth_cluster_features bcg
#       where bcg.feature_type = 'gene'
#       and bcg.feature_oid = ?
#    };
    my $sql = qq{
       select distinct bcg.cluster_id
       from bio_cluster_features_new bcg
       where bcg.feature_type = 'gene'
       and bcg.feature_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $cluster_id ) = $cur->fetchrow();
        last if !$cluster_id;
        push( @recs, $cluster_id );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    if ( $count > 1 ) {
        print "<th class='subhead'>In Biosynthetic Clusters</th>\n";
    }
    else {
        print "<th class='subhead'>In Biosynthetic Cluster</th>\n";
    }
    print "<td class='img'>\n";
    for my $r (@recs) {
    my $cluster_id = $r;
    my $url2 = "$main_cgi?section=BiosyntheticDetail&page=cluster_detail"
        . "&taxon_oid=$taxon_oid" 
        . "&cluster_id=$cluster_id"; 

    my $val2 = alink($url2, $cluster_id);
        print $val2 . "<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printAltTranscripts - Print alternative transcripts.
############################################################################
sub printAltTranscripts {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
      select at.alt_transcript_oid, at.ext_accession, at.aa_seq_length
      from alt_transcript at
      where at.gene = ?
      and at.aa_seq_length > 0
      and at.ext_accession is not null
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ( $alt_transcript_oid, $ext_accession, $aa_seq_length ) = $cur->fetchrow();
        last if !$alt_transcript_oid;
        my $r = "$alt_transcript_oid\t";
        $r .= "$ext_accession\t";
        $r .= "$aa_seq_length\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $count = @recs;
    return if $count == 0;

    print "<tr class='img'>\n";
    print "<th class='subhead'>Alternative Transcripts</th>\n";
    print "<td class='img'>\n";
    for my $r (@recs) {
        my ( $alt_transcript_oid, $ext_accession, $aa_seq_length ) =
          split( /\t/, $r );
        my $url = "$ncbi_entrez_base_url$ext_accession";
        print alink( $url, $ext_accession );
        my $url = "$section_cgi&page=genePageAltFaa";
        $url .= "&gene_oid=$gene_oid";
        $url .= "&alt_transcript_oid=$alt_transcript_oid";
        print "(" . alink( $url, "${aa_seq_length}aa" ) . "); ";
        print nbsp(2);
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printEnzymes - Show associated enzymes with gene detial page.
############################################################################
sub printEnzymes {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;
    
    my @enzymes = MetaUtil::getGeneEc( $gene_oid, $taxon_oid, $data_type );
    if ( scalar(@enzymes) == 0 ) {
        return;
    }

    my $enzyme_list = "";
    for my $ec (@enzymes) {
        if ($enzyme_list) {
            $enzyme_list .= ", '" . $ec . "'";
        } else {
            $enzyme_list = "'" . $ec . "'";
        }
    }

    my $sql = qq{
       select ez.ec_number, ez.enzyme_name
       from enzyme ez
       where ez.ec_number in ( $enzyme_list )
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my %done;
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>Enzymes</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $ec_number, $enzyme_name ) = $cur->fetchrow();
        last if !$ec_number;
        $count++;
        my $ec_number2 = $ec_number;
        $ec_number2 =~ tr/A-Z/a-z/;
        next if $done{$ec_number2} ne "";
        my $url = "$enzyme_base_url$ec_number2";
        print alink( $url, $ec_number );
        print " - ";
        ## Remove trailing period
        $enzyme_name =~ s/\.$/ /;
        print attrValue($enzyme_name);

        #      if( $img_ec_flag eq "Yes" ) {
        #         print "(PRIAM)";
        #      }
        print "<br/>\n";
        $done{$ec_number2} = 1;
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printTc - Show transport classification with gene detial page.
############################################################################
sub printTc {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
       select distinct gtf.gene_oid, tf.tc_family_num, tf.tc_family_name
       from gene_tc_families gtf, tc_family tf
       where gtf.gene_oid = ?
       and gtf.tc_family = tf.tc_family_num
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );

    my @recs;
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $tc_family_num, $tc_family_name ) = $cur->fetchrow();
        last if ( !$gene_oid );
        $count++;

        my $rec = "$gene_oid\t";
        $rec .= "$tc_family_num\t";
        $rec .= "$tc_family_name\t";
        push( @recs, $rec );
    }
    $cur->finish();

    #print "\$count: $count<br/>\n";

    if ( $count > 0 ) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>Transport Classification</th>\n";
        print "<td class='img'>\n";

        my $url = "$main_cgi?section=FindFunctions&page=tcList";
        for my $rec (@recs) {
            my ( $gene_oid, $tc_family_num, $tc_family_name ) = split( /\t/, $rec );
            next if !$gene_oid;

            my $url_num  = $tc_base_url . $tc_family_num;
            my $url_name = "$url&id=" . massageToUrl($tc_family_num);
            print alink( $url_num, $tc_family_num ) . " - " . alink( $url_name, $tc_family_name, '', 1 ) . "<br/>\n";
        }

        print "</td>\n";
        print "</tr>\n";
    }

}

############################################################################
# printImgTerms - Print IMG terms.
############################################################################
sub printImgTerms {
    my ( $dbh, $gene_oid ) = @_;
    my @termRecs = getImgTermRecs( $dbh, $gene_oid );
    print "<tr class='img' >\n";
    print "<th class='subhead'>IMG Term</th>\n";
    print "<td class='img' >\n";
    for my $t (@termRecs) {
        my ( $term_oid, $term, $f_flag, $confidence, $evidence, $mod_date, $name, $email ) = split( /\t/, $t );
        $confidence = "; " . $confidence     if $confidence ne "";
        $evidence   = "; " . $evidence . " " if $evidence   ne "";
        my $url = "$main_cgi?section=ImgTermBrowser" . "&page=imgTermDetail&term_oid=$term_oid";
        my $x1;
        if ( $f_flag eq "M" ) {
            $x1 = " (manual assigment)";
        }
        if ( $f_flag eq "A" ) {
            $x1 = " (automatic assignment)";
        }
        if ( $f_flag eq "C" ) {
            $x1 = " (automatic complete match$evidence$confidence)<br/>";
        }
        if ( $f_flag eq "P" ) {
            $x1 = " (automatic partial match$evidence$confidence)<br/>";
        }
        ## Do not show for public
        if ( !$img_internal ) {
            $x1 = "";
        }
        my $x2;
        my $elink = emailLink($email);
        if ( $mod_date ne "" && $name ne "" ) {
            $x2 = " ($name $mod_date)";
        }
        my $br;
        $br = "<br/>" if $x1 ne "" || $x2 ne "";
        print alink( $url, $term ) . "$br$x1$x2<br/>\n";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# getImgTermRecs - Get IMG term records in a string for print out.
############################################################################
sub getImgTermRecs {
    my ( $dbh, $gene_oid ) = @_;
#    my $sql = qq{
#       select it.term_oid, it.term, g.f_flag, g.confidence,
#          g.evidence, to_char(g.mod_date, 'yyyy-mm-dd'), c.name, c.email
#       from gene_img_functions g, dt_img_term_path dtp, img_term it, contact c
#       where g.function = dtp.map_term
#       and it.term_oid = dtp.term_oid
#       and g.gene_oid = ?
#       and g.modified_by = c.contact_oid
#       order by it.term
#    };
    my $sql = qq{
       select it.term_oid, it.term, g.f_flag, g.confidence,
          g.evidence, to_char(g.mod_date, 'yyyy-mm-dd'), c.name, c.email
       from gene_img_functions g, img_term it, contact c
       where g.function = it.term_oid
       and g.gene_oid = ?
       and g.modified_by = c.contact_oid
       order by it.term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $s;
    my @termRecs;
    for ( ; ; ) {
        my ( $term_oid, $term, $f_flag, $confidence, $evidence, $mod_date, $name, $email ) = $cur->fetchrow();
        last if !$term_oid;
        my $r = "$term_oid\t";
        $r .= "$term\t";
        $r .= "$f_flag\t";
        $r .= "$confidence\t";
        $r .= "$evidence\t";
        $r .= "$mod_date\t";
        $r .= "$name\t";
        $r .= "$email\t";
        push( @termRecs, $r );
    }
    $cur->finish();
    return @termRecs;
}

############################################################################
# printTmHmm - Print transmembrane HMM hits.
############################################################################
sub printTmHmm {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select count(*)
      from gene_tmhmm_hits
      where gene_oid = ?
      and feature_type = 'TMhelix'
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    my $link = "No";
    my $url  = "$section_cgi&page=tmTopo&gene_oid=$gene_oid";
    $link = alink( $url, "Yes" ) if $cnt > 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>Transmembrane Helices</th>\n";
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";
}

############################################################################
# printSignalp - Show signal peptides.
############################################################################
sub printSignalp {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select count(*)
      from gene_sig_peptides
      where gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    my $link = "No";
    my $url  = "$section_cgi&page=sigCleavage&gene_oid=$gene_oid";
    $link = alink( $url, "Yes" ) if $cnt > 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>Signal Peptide</th>\n";
    print "<td class='img'>$link</td>\n";
    print "</tr>\n";
}

############################################################################
# printMyImg - Print MyIMG annnotations.
############################################################################
sub printMyImg {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select g.gene_oid, ann.annotation_text,
          ann.author, ct.username, to_char(ann.add_date, 'yyyy-mm-dd')
       from gene g, annotation ann, annotation_genes ag,
         contact ct
       where g.gene_oid = ag.genes
       and g.gene_oid = ?
       and ag.annot_oid = ann.annot_oid
       and ct.contact_oid = ann.author
       order by ann.add_date desc, ct.username asc
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    my %done;
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>MyIMG Annotations</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $gene_oid, $annotation_text, $contact_oid, $username, $add_date ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        print "<b>$username</b>: ";
        print escHtml($annotation_text);
        print nbsp(1);
        print "($add_date)";
        print "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# getBinInformation - Get information about bins.
############################################################################
sub getBinInformation {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select g.gene_oid, b.display_name, bm.method_name
      from gene g, bin_scaffolds bs, bin b, bin_method bm
      where g.gene_oid = ?
      and g.scaffold = bs.scaffold
      and bs.bin_oid = b.bin_oid
      and b.bin_method = bm.bin_method_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $s;
    for ( ; ; ) {
        my ( $gene_oid, $bin_display_name, $method_name ) = $cur->fetchrow();
        last if !$gene_oid;
        $s .= "$bin_display_name ($method_name), ";
    }
    chop $s;
    chop $s;
    $cur->finish();
    return "" if blankStr($s);
    my $s2 = "(bins: $s)";
    return $s2;
}

############################################################################
# printMetaFuncEvidence - Print evidence for functional prediction.
#                     (file version)
############################################################################
sub printMetaFuncEvidence {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, 
     $start_coord, $end_coord, $strand, $scf_ext_accession,
     $aa_seq_length, $cog_ref, $pfam_ref ) = @_;

    # html bookmark 2
    print WebUtil::getHtmlBookmark
    ( "evidence", "<h2>Evidence For Function Prediction</h2>" );

    print "<table class='img' cellspacing='1' border='1'>\n";

    if ( $end_coord > 0 && $scf_ext_accession ne "" ) {
        print "<tr class='highlight'>\n";
        print "  <th class='subhead' colspan='7'>Neighborhood</th>\n";
        print "</tr>\n";

        print "<tr class='img' >\n";
        print "   <td colspan='7' class='subhead'>\n";

        if ( $data_type eq 'unassembled' ) {
            print "<p>No gene neighborhood information for unassembled data.\n";
        } else {
            printMetaNeighborhood( $dbh, $gene_oid, $taxon_oid, $data_type,
                   0, $start_coord, $end_coord,
                   $scf_ext_accession );
        }

        #print "<br>";
        print "  </td>\n";
        print "</tr>\n";
    }

    print "<tr class='highlight'>\n";
    print "  <th class='subhead' colspan='7'>Conserved Neighborhood</th>\n";
    print "</tr>\n";
    print "<tr class='img' >\n";
    print "   <td colspan='7' class='subhead'>\n";

    # cassette viewer
    my $cassette_oid = "";
    printViewers( $dbh, $gene_oid, $taxon_oid, $data_type, $cassette_oid );
    print "  </td>\n";
    print "</tr>\n";

    my $gene_oid_str;
    $gene_oid_str = $gene_oid;

    print "<tr class='highlight'>\n";
    print "  <th class='subhead' colspan='7'>COG</th>\n";
    print "</tr>\n";
    print "<tr class='img' >\n";
    print "   <td colspan='7' class='subhead'>\n";
    MetaFuncAlignmentUtil::printMetaCog( $dbh, $gene_oid, $taxon_oid, $data_type, $aa_seq_length, $cog_ref )
      if ( $gene_oid_str ne '' );
    print "  </td>\n";
    print "</tr>\n";

    print "<tr class='highlight'>\n";
    print "  <th class='subhead' colspan='7'>Pfam</th>\n";
    print "</tr>\n";
    print "<tr class='img' >\n";
    print "  <td class='img'  colspan='7'>\n";
    MetaFuncAlignmentUtil::printMetaPfam( $dbh, $gene_oid, $taxon_oid, $data_type, $aa_seq_length, $pfam_ref );
    print "  </td>\n";
    print "</tr>\n";
    print "</table>\n";

    print "<script src='$base_url/overlib.js'></script>\n";
    print toolTipCode();
}

############################################################################
# printMetaRnaNeighborhood - Show neighborhood for RNA genes.
# (file version)
############################################################################
sub printMetaRnaNeighborhood {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $start_coord, 
     $end_coord, $strand, $scf_ext_accession ) = @_;

    # html bookmark 2
    print WebUtil::getHtmlBookmark( "evidence", "<h2>RNA Neighborhood</h2>" );
    print "\n";

    if ( $data_type eq 'unassembled' ) {
        print "<p>No gene neighborhood information for unassembled data.\n";
        return;
    }

    print "<table class='img' cellspacing='1' border='1'>\n";
    if ( $end_coord > 0 ) {
        print "<tr class='highlight'>\n";
        print "  <th class='subhead' colspan='7'>Neighborhood</th>\n";
        print "</tr>\n";
        print "<tr class='img' >\n";
        print "   <td colspan='7' class='subhead'>\n";
        printMetaNeighborhood( $dbh, $gene_oid, $taxon_oid, $data_type,
                   1, $start_coord, $end_coord,
                   $scf_ext_accession );
        print "  </td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    print "<script src='$base_url/overlib.js'></script>\n";
    print toolTipCode();
}

############################################################################
# printIprFamily - Show Interpro hits.
############################################################################
sub printIprFamily {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select aa_seq_length
       from gene
       where gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($aa_seq_length) = $cur->fetchrow();
    $cur->finish();
    my $sql = qq{
       select distinct giih.gene_oid, giih.iprid, giih.iprdesc,
          giih.domaindb, giih.domainid, giih.domaindesc,
          sfstarts, sfends
       from gene_img_interpro_hits giih
       where giih.gene_oid = ?
       and giih.iprid  like 'IPR%'
       order by giih.iprid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;

    for ( ; ; ) {
        my ( $gene_oid, $iprid, $iprdesc, $domaindb, $domainid, $domaindesc, $sfstarts, $sfends ) = $cur->fetchrow();
        last if !$gene_oid;
        my $url = "$ipr_base_url$iprid";
        my $r   = "$sfstarts\t";
        $r .= "$sfends\t";
        $r .= "$iprid\t";
        $r .= "$iprdesc\t";
        $r .= "$domaindb\t";
        $r .= "$domainid\t";
        push( @recs, $r );
    }
    $cur->finish();
    my $nRecs = @recs;
    return if $nRecs == 0;

    my $fileName = "ipr.$gene_oid.png";
    webLog "Write file '$fileName'\n" if $verbose >= 1;
    my $tmpFile    = "$tmp_dir/$fileName";
    my $tmpFileUrl = "$tmp_url/$fileName";
    my $map        = IprGraph::writeFile( $aa_seq_length, \@recs, $tmpFile );
    print "<image src='$tmpFileUrl' usemap='#iprmap' border='1' />\n";
    print "<map name='iprmap'>\n";
    print $map;
    print "</map>\n";
}

############################################################################
# printMetaNeighborhood - Show graphics for gene gene neighborhood for
#   this gene and link outs to other chromosome viewers.
#   (file version)
############################################################################
sub printMetaNeighborhood {
    my ( $dbh, $gene_oid0, $taxon_oid, $data_type, $isRna, 
     $start_coord0, $end_coord0, $scaffold_oid ) = @_;

    #my %pos_cluster_genes = positionalClusterGenes( $dbh, $gene_oid0 );
    #    my %pos_cluster_genes = positionalClusterKeggGenes( $dbh, $gene_oid0 );
    my %pos_cluster_genes;
    my $mid_coord = int(($end_coord0 - $start_coord0)/2) + $start_coord0 + 1;

    ## Rescale for large organisms
    my $taxon_rescale = 1;
    $flank_length *= $taxon_rescale;

    my $left_flank  = $mid_coord - $flank_length + 1;
    my $left_flank  = $left_flank > 0 ? $left_flank : 0;
    my $right_flank = $mid_coord + $flank_length + 1;

    #my %gene2Enzymes;
    #WebUtil::gene2EnzymesMap( $dbh, $scaffold_oid, $left_flank, $right_flank,
    #                 \%gene2Enzymes );
    #my %gene2MyEnzymes;
    #WebUtil::gene2MyEnzymesMap( $dbh, $scaffold_oid, $left_flank, $right_flank,
    #                 \%gene2MyEnzymes );

    # read scaffold info from file
    my $t2        = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my ( $scaffold_start, $scaffold_end, $scaffold_strand ) = 
    MetaUtil::getScaffoldCoord( $taxon_oid, $data_type, $scaffold_oid );
    my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

    # ken is_pseudogene new 2.7
    #my $rclause   = WebUtil::urClause('g.taxon');
    #my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    #my $sql       = qq{
    #   select distinct g.gene_oid, g.gene_symbol, g.gene_display_name, 
    #          g.locus_type, g.locus_tag, g.start_coord, 
    #          g.end_coord, g.strand, g.aa_seq_length, ss.seq_length, 
    #          g.is_pseudogene, g.img_orf_type, g.cds_frag_coord
    #   from scaffold scf, scaffold_stats ss, gene g
    #   where g.scaffold = ?
    #   and g.scaffold = scf.scaffold_oid
    #   and scf.scaffold_oid = ss.scaffold_oid
    #   and g.start_coord > 0
    #   and g.end_coord > 0
    #   and g.obsolete_flag = 'No'
    #   and ( ( g.start_coord >= ? and g.end_coord <= ? )
    #        or ( ( g.end_coord + g.start_coord ) / 2 >= ? and
    #             ( g.end_coord + g.start_coord ) / 2 <= ? ) )
    #   $rclause
    #   $imgClause
    #};

    #    my @binds = ($scaffold_oid, $left_flank,
    #        $right_flank, $left_flank, $right_flank);
    #    my $cur        = execSql( $dbh, $sql, $verbose, @binds );

    my $id         = "gd.$scaffold_oid.$start_coord0..$end_coord0";
    my $coord_incr = 5000;
    $coord_incr *= $taxon_rescale;
    my $args = {
                 id                      => $id,
                 start_coord             => $left_flank,
                 end_coord               => $right_flank,
                 coord_incr              => $coord_incr,
                 strand                  => "+",
                 has_frame               => 1,
                 x_width                 => 800,
                 gene_page_base_url      => "$section_cgi&page=metaGeneDetail&taxon_oid=$taxon_oid&data_type=$data_type",
                 meta_gene_page_base_url => "$section_cgi&page=metaGeneDetail&taxon_oid=$taxon_oid&data_type=$data_type",
                 mygene_page_base_url    => "$main_cgi?section=MyGeneDetail&page=geneDetail",
                 color_array_file        => $env->{small_color_array_file},
                 tmp_dir                 => $env->{tmp_dir},
                 tmp_url                 => $env->{tmp_url},
    };
    my $sp             = new ScaffoldPanel($args);
    my $scf_seq_length = $scaffold_end - $scaffold_start + 1;

    # number of pseudogene count
    my $pseudogene_cnt = 0;

    # save marker gene data to add last to plot
    my ( $mymaker_gene_oid, $mymaker_start_coord, $mymaker_end_coord, $mymaker_strand, $mymaker_color, $mymaker_label );

    for my $s2 (@genes_on_s) {
        my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
          split( /\t/, $s2 );

        if ( !$gene_oid || ( !$start_coord && !$end_coord ) ) {
            next;
        }

        if ( $start_coord >= $left_flank && $end_coord <= $right_flank ) {

            # in the range
        } elsif (    ( $end_coord + $start_coord ) / 2 >= $left_flank
                  && ( $end_coord + $start_coord ) / 2 <= $right_flank )
        {

            # in the range
        } else {
            next;
        }

        # get gene product name
        my ( $prod_name, $prod_source ) = 
           MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
        if ($prod_name) {
            $gene_display_name = $prod_name;
        }

        #my $label = $gene_symbol;
        my $label = $locus_tag;
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";

        $label .= " $start_coord..$end_coord";

        #if ( $locus_type eq "CDS" ) {
        #    $label .= "(${aa_seq_length}aa)";
        #} else {
        #    my $len = $end_coord - $start_coord + 1;
        #    $label .= "(${len}bp)";
        #}

        my $color = $sp->{color_yellow};

        #$color = $sp->{color_green} if $pos_cluster_genes{$gene_oid} ne "";
        $color = $sp->{color_red} if $gene_oid eq $gene_oid0;

        #$color = $sp->{color_cyan}
        #  if $ez2      ne ""
        #  && $gene_oid ne $gene_oid0
        #  && $show_myimg_login;

        #All pseudo gene should be white - 2008-04-09 ken
        #if (    ( $gene_oid ne $gene_oid0 )
        #     && ( uc($is_pseudogene) eq "YES" || $img_orf_type eq "pseudo" ) )
        #{
        #    $color = $sp->{color_white};
        #    $pseudogene_cnt++;
        #}

        my $is_pseudogene  = "NO";
        my $cds_frag_coord = "";

        my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
        if ( scalar(@coordLines) > 1 ) {
            foreach my $line (@coordLines) {
                my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                my $tmplabel = $label . " $frag_start..$frag_end";
                $sp->addGene( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmplabel );
            }
        } else {
            if ( $gene_oid eq $gene_oid0 ) {
                # if marker gene - save it to add last
                (
                   $mymaker_gene_oid, $mymaker_start_coord, $mymaker_end_coord,
                   $mymaker_strand,   $mymaker_color,       $mymaker_label
                  )
                  = ( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
            }
            $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
        }
    }

    # marker gene
    $sp->addGene( $mymaker_gene_oid, $mymaker_start_coord, $mymaker_end_coord,
                  $mymaker_strand,   $mymaker_color,       $mymaker_label );

    if ( $left_flank <= 1 ) {
        $sp->addBracket( 1, "left" );
    }
    if ( $left_flank <= $scf_seq_length && $scf_seq_length <= $right_flank ) {
        $sp->addBracket( $scf_seq_length, "right" );
    }

    #    addNxFeatures( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );
    require MetaScaffoldGraph;
    MetaScaffoldGraph::addMetaRepeats( $taxon_oid, $scaffold_oid, $sp, "+", $left_flank, $right_flank );

    #    addIntergenic( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );

    my $s = $sp->getMapHtml("overlib");
    print "$s\n";

    #    $cur->finish();

    print "<br/>\n";
    print "<font color='red'>red = Current Gene</font><br/>\n";

    #    if ( $img_er || $img_internal ) {
    #        print "cyan or dashes = My Gene<br/>\n";
    #    }

    #    if ( $pseudogene_cnt > 0 ) {
    #        print "white = Pseudo Gene<br/>\n";
    #    }

    my $url = "$section_cgi&page=regionScoreNote";

    #    if ( !$isRna ) {
    #        print "<font color='green'>green = "
    #          . "Positional Cluster Gene in the same KEGG Pathway "
    #          . "as the Current Gene"
    #          . "</font><br/>\n";
    #        if ($show_myimg_login) {
    #            print "<font color='#229999'>cyan = "
    #              . "Neigboring genes with MyIMG EC number assignment</font><br/>\n";
    #        }
    #    }
    print "<image src='$crispr_png' width='25' height='10' alt='Crispr' >\n";
    print "CRISPR array<br/>\n";

    # Sequence Viewer
    if ($mymaker_end_coord > 0 && $scf_seq_length > 0) {
        my $url = "$main_cgi?section=Sequence&page=queryForm";
        $url .= "&genePageGeneOid=$gene_oid0&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
        print alink( $url, "Sequence Viewer For Alternate ORF Search" );
        print "<br/>\n";
    }

    return;

    WebUtil::printMainFormName("coloredBy");
    print qq{
        <script language='javascript' type='text/javascript'>

        function chromoColor() {
            var e =  document.mainFormcoloredBy.chromoColorBy;
            if(e.value == 'label') {
                return;
            }
            var url = e.value;
            window.open( url, '_self' );
        }
        </script>
        };

    # Chromosome Viewer colored by section
    print qq{
        Chromosome Viewer colored by &nbsp;
        <select onchange="chromoColor()" name="chromoColorBy">
        <option selected="true" value="label"> --- Select Function --- </option>
    };

    my $scf_start_coord = $start_coord0 - $large_flank_length - 2 * $flank_length;
    my $scf_end_coord   = $end_coord0 + $large_flank_length;
    $scf_start_coord = $scf_start_coord > 1             ? $scf_start_coord : 1;
    $scf_end_coord   = $scf_end_coord > $scf_seq_length ? $scf_seq_length  : $scf_end_coord;
    my $url = "$main_cgi?section=ScaffoldGraph" . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid";
    $url .= "&start_coord=$scf_start_coord&end_coord=$scf_end_coord";
    $url .= "&marker_gene=$gene_oid0&seq_length=$scf_seq_length";

    print qq{
        <option value="$url"> COG </option>
    };

    # chro viewer by gc percent color
    my $urltmp = $url . "&color=gc";
    print qq{
        <option value="$urltmp"> GC </option>
    };

    # chro viewer by kegg
    my $urltmp = $url . "&color=kegg";
    print qq{
        <option value="$urltmp"> KEGG </option>
    };

    # chro viewer by pfam
    my $urltmp = $url . "&color=pfam";
    print qq{
        <option value="$urltmp"> Pfam </option>
    };

    # chro viewer by tigrfam
    my $urltmp = $url . "&color=tigrfam";
    print qq{
        <option value="$urltmp"> TIGRfam </option>
    };

    print "</select>\n";
    print "</form>\n";
}

#
# print neighborhood for my gene / missing gene
# This is for a stand alone html page
# used by the my gene page to do dynamic viewer
#
sub printNeighborhoodMyGene {
    my $mygene_oid   = param("gene_oid");
    my $start_coord0 = param("start_coord");
    my $end_coord0   = param("end_coord");
    my $scaffold_oid = param("scaffold");
    my $strand0      = param("strand");

    print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    print qq { 
        <response> 
            <div id='nbhood'><![CDATA[ 
    };

    print qq{
        <p>
            My Gene Id: $mygene_oid <br/>
            Start Coord. $start_coord0 <br/>
            End Coord.  $end_coord0 <br/>
        </p>
    };

    my $sp = getScaffoldPanel( $mygene_oid, $start_coord0, $end_coord0, $scaffold_oid, $strand0 );
    my $s = $sp->getMapHtml("overlib");
    print "$s\n";
    print "<br/>\n";
    print "<p>\n";
    print "<font color='red'>red = Current Gene</font><br/>\n";
    print "cyan or dashes = My Gene<br/>\n";
    print "white = Pseudo Gene<br/>\n";

    my $url = "$section_cgi&page=regionScoreNote";
    print "<image src='$crispr_png' width='25' height='10' alt='Crispr' >\n";
    print "CRISPR array<br/>\n";
    print "</p>\n";

    print qq{ 
           ]]></div>
       </response> 
    };
}

############################################################################
# printNeighborhoodAlignment - xml to show the neighborhood alignment
#   of two gene segments. This is called from DotPlot.
############################################################################
sub printNeighborhoodAlignment {
    my $start_coord1  = param("start_coord1");
    my $end_coord1    = param("end_coord1");
    my $scaffold_oid1 = param("scaffold1");
    my $accession1    = param("accession1");

    my $start_coord2  = param("start_coord2");
    my $end_coord2    = param("end_coord2");
    my $scaffold_oid2 = param("scaffold2");
    my $accession2    = param("accession2");

    print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    print qq { 
        <response> 
            <div id='nbhood'><![CDATA[ 
    };

    my $style1 = " style='font-size: 12px; " . "font-family: Arial,Helvetica,sans-serif; " . "line-height: 1.0em;' ";
    my $style2 = " style='font-size: 11px; " . "font-family: Arial,Helvetica,sans-serif; " . "line-height: 1.0em;' ";
    print qq{ 
        <p $style1>Referrence ($start_coord1..$end_coord1) [$accession1]
    <br/></p> 
    };
    my $sp = getScaffoldPanel( "", $start_coord1, $end_coord1, $scaffold_oid1 );
    my $s = $sp->getMapHtml("overlib");
    print "$s\n";
    print "<br/>\n";

    print qq{ 
        <p $style1>Query ($start_coord2..$end_coord2) [$accession2]<br/></p> 
    };
    my $sp = getScaffoldPanel( "", $start_coord2, $end_coord2, $scaffold_oid2 );
    my $s = $sp->getMapHtml("overlib");
    print "$s\n";

    print "<p $style2>\n";
    print "dashed frame = Aligned Region<br/>\n";

    #print "<font color='red'>red = Current Gene</font><br/>\n";
    print "cyan or dashes = My Gene<br/>\n";
    print "white = Pseudo Gene<br/>\n";

    my $url = "$section_cgi&page=regionScoreNote";
    print "<image src='$crispr_png' width='25' height='10' alt='Crispr' >\n";
    print "CRISPR array<br/>\n";
    print "</p>\n";

    print qq { 
           ]]></div> 
       </response> 
    };
}

sub getScaffoldPanel {
    my ( $mygene_oid, $start_coord0, $end_coord0, $scaffold_oid, $strand0 ) = @_;
    my $dbh       = dbLogin();
    my $mid_coord = int( ( $end_coord0 - $start_coord0 ) / 2 ) + $start_coord0 + 1;

    ## Rescale for large organisms
    my $taxon_oid     = scaffoldOid2TaxonOid( $dbh, $scaffold_oid );
    my $taxon_rescale = getTaxonRescale( $dbh,      $taxon_oid );
    $flank_length *= $taxon_rescale;

    my $left_flank  = $mid_coord - $flank_length + 1;
    my $left_flank  = $left_flank > 0 ? $left_flank : 0;
    my $right_flank = $mid_coord + $flank_length + 1;
    
    #my %gene2Enzymes;
    #WebUtil::gene2EnzymesMap( $dbh, $scaffold_oid, $left_flank, $right_flank, \%gene2Enzymes );
    my %gene2MyEnzymes;
    WebUtil::gene2MyEnzymesMap( $dbh, $scaffold_oid, $left_flank, $right_flank, \%gene2MyEnzymes );

    # ken is_pseudogene new 2.7
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid, g.gene_symbol, 
            g.gene_display_name, g.locus_type,
            g.locus_tag, g.start_coord, g.end_coord, g.strand,
            g.aa_seq_length, ss.seq_length, g.is_pseudogene, 
            g.img_orf_type, g.cds_frag_coord
        from scaffold scf, scaffold_stats ss, gene g
        where g.scaffold = ?
            and g.scaffold = scf.scaffold_oid
            and scf.scaffold_oid = ss.scaffold_oid
            and g.start_coord > 0
            and g.end_coord > 0
            and g.obsolete_flag = 'No'
            and (
              ( g.start_coord >= ? and g.end_coord <= ? ) 
              or
              (( g.end_coord + g.start_coord ) / 2 >= ? and
               ( g.end_coord + g.start_coord ) / 2 <= ? )
            )
            $rclause
            $imgClause
    };
    my @binds = ( $scaffold_oid, $left_flank, $right_flank, $left_flank, $right_flank );

    my $cur        = execSql( $dbh, $sql, $verbose, @binds );
    my @all_genes;
    for ( ; ; ) {
        my (
             $gene_oid,        $gene_symbol,   $gene_display_name, $locus_type,
             $locus_tag,       $start_coord,   $end_coord,         $strand, $aa_seq_length,
             $scf_seq_length0, $is_pseudogene, $img_orf_type,      $cds_frag_coord
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        push( @all_genes,
                "$gene_oid\t$gene_symbol\t$gene_display_name\t"
              . "$locus_type\t$locus_tag\t$start_coord\t"
              . "$end_coord\t$strand\t$aa_seq_length\t$scf_seq_length0\t"
              . "$is_pseudogene\t$img_orf_type\t$cds_frag_coord" );    
    }
    $cur->finish();
    
    my $id         = "gd.$scaffold_oid.$start_coord0..$end_coord0";
    my $coord_incr = 5000;
    $coord_incr *= $taxon_rescale;
    my $args = {
                 id                   => $id,
                 start_coord          => $left_flank,
                 end_coord            => $right_flank,
                 coord_incr           => $coord_incr,
                 strand               => "+",
                 has_frame            => 1,
                 x_width              => 800,
                 gene_page_base_url   => "$section_cgi&page=geneDetail",
                 mygene_page_base_url => "$main_cgi?section=MyGeneDetail&page=geneDetail",
                 color_array_file     => $env->{small_color_array_file},
                 tmp_dir              => $env->{tmp_dir},
                 tmp_url              => $env->{tmp_url},
    };
    my $sp = new ScaffoldPanel($args);
    my $scf_seq_length;

    # number of pseudogene count
    my $pseudogene_cnt = 0;

    if ( $mygene_oid eq "" ) {
        $sp->highlightRegion( $start_coord0, $end_coord0 );
    }

    foreach my $geneline (@all_genes) {
        my (
             $gene_oid,        $gene_symbol,   $gene_display_name, $locus_type,
             $locus_tag,       $start_coord,   $end_coord,         $strand, $aa_seq_length,
             $scf_seq_length0, $is_pseudogene, $img_orf_type,      $cds_frag_coord
          )
          = split( /\t/, $geneline );

        $scf_seq_length = $scf_seq_length0;

        my $ez2 = $gene2MyEnzymes{$gene_oid};

        my $label = $gene_symbol;
        $label = $locus_tag       if $label eq "";
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }
        my $color = $sp->{color_yellow};
        $color = $sp->{color_red} if $gene_oid eq $mygene_oid;
        $color = $sp->{color_cyan}
          if $ez2      ne ""
          && $gene_oid ne $mygene_oid
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
                $sp->addGene( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmplabel );
            }

        } else {
            $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
        }
    }    # end for loop

    # find missing gene / my gene data?
    if ( ( $img_er || $img_internal ) && ( $mygene_oid ne "" ) ) {
        ScaffoldGraph::addMyGene( $dbh, $sp, $scaffold_oid, $left_flank, $right_flank, $taxon_oid, $mygene_oid );
        my $color  = $sp->{color_red};
        my $label  = "$mygene_oid, $start_coord0, $end_coord0";
        my $strand = "+";
        $strand = "-" if ( $strand0 eq "-" );
        $sp->addMyGene( $mygene_oid, $start_coord0, $end_coord0, $strand, $color, $label );
    }

    if ( $left_flank <= 1 ) {
        $sp->addBracket( 1, "left" );
    }
    if ( $left_flank <= $scf_seq_length && $scf_seq_length <= $right_flank ) {
        $sp->addBracket( $scf_seq_length, "right" );
    }
    WebUtil::addNxFeatures( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );
    WebUtil::addRepeats( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );
    WebUtil::addIntergenic( $dbh, $scaffold_oid, $sp, "+", $left_flank, $right_flank );

    return $sp;
}

############################################################################
# scaffoldGraphCoords - Get coordinates for ScaffoldGraph.
#   Return( $scaffold_oid, $start_coord, $end_coord, $seq_length )
#   for scaffold.
############################################################################
sub scaffoldGraphCoords {
    my ( $dbh, $gene_oid0 ) = @_;

    my $sql = qq{
       select g.scaffold, g.start_coord, g.end_coord, ss.seq_length
       from gene g, scaffold_stats ss
       where g.gene_oid = ?
       and g.scaffold = ss.scaffold_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid0 );
    my ( $scaffold_oid, $start_coord0, $end_coord0, $scf_seq_length ) = $cur->fetchrow();
    $cur->finish();

    my $mid_coord = int( ( $end_coord0 - $start_coord0 ) / 2 ) + $start_coord0 + 1;

    ## Rescale for large organisms
    my $taxon_oid     = scaffoldOid2TaxonOid( $dbh, $scaffold_oid );
    my $taxon_rescale = getTaxonRescale( $dbh,      $taxon_oid );
    $flank_length *= $taxon_rescale;

    my $left_flank  = $mid_coord - $flank_length + 1;
    my $left_flank  = $left_flank > 0 ? $left_flank : 0;
    my $right_flank = $mid_coord + $flank_length + 1;

    my $scf_start_coord = $start_coord0 - $large_flank_length + 2 * $flank_length;
    my $scf_end_coord   = $end_coord0 + $large_flank_length;
    $scf_start_coord = $scf_start_coord > 1             ? $scf_start_coord : 1;
    $scf_end_coord   = $scf_end_coord > $scf_seq_length ? $scf_seq_length  : $scf_end_coord;

    return ( $scaffold_oid, $scf_start_coord, $scf_end_coord, $scf_seq_length );
}

############################################################################
# positionClusterKeggGenes - Positional cluster genes in the same
#   KEGG pathway with current gene.
############################################################################
sub positionalClusterKeggGenes {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select distinct pcg2.genes, pw.image_id
        from 
          gene_ko_enzymes ge1, ko_term_enzymes kt1, image_roi_ko_terms rk1, image_roi iroi1, 
          gene_ko_enzymes ge2, ko_term_enzymes kt2, image_roi_ko_terms rk2, image_roi iroi2, 
          kegg_pathway pw,
          positional_cluster_genes pcg1, positional_cluster_genes pcg2,
          gene g 
        where g.gene_oid = ?
        and g.gene_oid = ge1.gene_oid
        and ge1.enzymes = kt1.enzymes
        and kt1.ko_id = rk1.ko_terms
        and rk1.roi_id = iroi1.roi_id
        and pcg1.genes = ge1.gene_oid
        and iroi1.pathway = pw.pathway_oid
        and pcg1.genes = g.gene_oid
        and pcg1.group_oid = pcg2.group_oid
        and pcg2.genes != ?
        and pcg2.genes = ge2.gene_oid
        and ge2.enzymes = kt2.enzymes
        and kt2.ko_id = rk2.ko_terms
        and rk2.roi_id = iroi2.roi_id
        and iroi2.pathway = pw.pathway_oid
   };
    my %genes;
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $gene_oid );
    for ( ; ; ) {
        my ( $gene_oid, $image_id ) = $cur->fetchrow();
        last if !$gene_oid;
        $genes{$gene_oid} = $gene_oid;
        webLog "posClusterGene=$gene_oid image_id=$image_id\n"
          if $verbose >= 2;
    }
    $cur->finish();
    return %genes;
}

############################################################################
# hasConsRegionOrhthologs - Has conserved region orthologs.
#  Test if there is conserved region worth showing.
#  Now mainly used as filter from taxon selection.
############################################################################
sub hasConsRegionOrthologs {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    # check whether gene has BBH
    my $bbh = MetaUtil::getGeneBBH( $taxon_oid, $data_type, $gene_oid );
    if ($bbh) {
        return 1;
    }
    return 0;
}

############################################################################
# hasCommonCluster - Find common cluster data.
############################################################################
sub hasCommonCluster {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    # check whether gene has COG
    my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
    my $cnt  = scalar(@cogs);

    return 1 if $cnt > 0;

    return 0;
}

############################################################################
# printReaction - Show associated reactions in gene detail page.
############################################################################
sub printReaction {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select g.gene_oid, ez.ec_number, r.rxn_name, r.rxn_definition
       from gene g, gene_ko_enzymes ge, enzyme ez, reaction_enzymes re,
         reaction r
       where g.gene_oid = ge.gene_oid
       and ge.enzymes = ez.ec_number
       and g.gene_oid = ?
       and re.enzymes = ez.ec_number
       and re.ext_accession = r.ext_accession
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>KEGG LIGAND Reaction</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $gene_oid, $ec_number, $rxn_name, $rxn_definition ) = $cur->fetchrow();
        last if !$gene_oid;
        print attrValue($rxn_definition) . "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printKeggPathways - Show list of KEGG pathways on page.
############################################################################
sub printKeggPathways {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $ko_list ) = @_;

    if ( !$ko_list ) {
        return;
    }

    my $contact_oid = getContactOid();

    my $sql_ko = qq{
       select distinct pw.pathway_name, pw.image_id
       from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk
       where pw.pathway_oid = roi.pathway
       and roi.roi_id = irk.roi_id
       and irk.ko_terms in ( $ko_list )
   };
    my $sql   = $sql_ko;
    my $cur   = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>KEGG Pathway</th>\n";
    print "<td class='img'>\n";
    my %done;

    # BAD image maps - overview maps
    # see KeggMap
    $done{'map01100'} = 1;

    for ( ; ; ) {
        my ( $pathway_name, $image_id ) = $cur->fetchrow();
        last if !$pathway_name;
        next if $done{$image_id};
        my $url =
            "$main_cgi?section=KeggMap"
          . "&page=keggMap&map_id=$image_id&gene_oid=$gene_oid"
          . "&taxon_oid=$taxon_oid&data_type=$data_type";
        if ( $count > 0 ) {
            print "<br/>\n";
        }
        print alink( $url, $pathway_name );
        $done{$image_id} = 1;
        $count++;
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

sub printMetaCycPathways {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    my @ecs = MetaUtil::getGeneEc( $gene_oid, $taxon_oid, $data_type );
    if ( scalar(@ecs) == 0 || scalar(@ecs) > 1000 ) {
        return;
    }

    my $ec_str = "";
    for my $ec (@ecs) {
        if ($ec_str) {
            $ec_str .= ", '" . $ec . "'";
        } else {
            $ec_str = "'" . $ec . "'";
        }
    }
    if ( !$ec_str ) {
        return;
    }

    my $sql = qq{
        select distinct bp.unique_id, bp.common_name
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        biocyc_reaction br
        where bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.ec_number in ( $ec_str )
   };

    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>MetaCyc Pathway</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        my $url = $metacyc_url . $id;
        print alink( $url, $name, "", 1 ) . "<br/>\n";

    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

sub printKeggModules {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $ko_list ) = @_;

    my $sql = "";
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        # MER-FS
        if ($ko_list) {
            $sql = qq{
                 select distinct km.module_id, km.module_name
                 from kegg_module_ko_terms kmkt, kegg_module km
                 where kmkt.module_id = km.module_id
                 and kmkt.ko_terms in ( $ko_list )
                 };
        }
    } elsif ( WebUtil::isInt($gene_oid) ) {
        # DB
        $sql = qq{
           select distinct km.module_id, km.module_name
           from gene_ko_terms gkt, kegg_module_ko_terms kmkt, kegg_module km
           where gkt.gene_oid = $gene_oid
           and gkt.ko_terms = kmkt.ko_terms
           and kmkt.module_id = km.module_id      
           };
    }

    if ( !$sql ) {
        return;
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>KEGG Orthology (KO) Modules</th>\n";
    print "<td class='img'>\n";

    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        my $url = $kegg_module_url . $id;
        print alink( $url, $name ) . "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printMyIMGKeggPathways - Show list of KEGG pathways on page.
############################################################################
sub printMyIMGKeggPathways {
    my ( $dbh, $gene_oid, $contact_oid ) = @_;

    return if !$contact_oid || !$show_myimg_login;

    my $sql = qq{
        select distinct pw.pathway_name, pw.image_id
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt,
         gene_myimg_enzymes gme, gene g
        where pw.pathway_oid = roi.pathway
        and ir.roi_id = rk.roi_id
        and rk.ko_terms = kt.ko_id
        and kt.enzymes = gme.ec_number
        and gme.modified_by = ?
        and gme.gene_oid = g.gene_oid
        and g.gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $gene_oid );
    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>My KEGG Pathway</th>\n";
    print "<td class='img'>\n";
    for ( ; ; ) {
        my ( $pathway_name, $image_id ) = $cur->fetchrow();
        last if !$pathway_name;
        my $url = "$main_cgi?section=KeggMap" . "&page=keggMap&map_id=$image_id&gene_oid=$gene_oid&myimg=1";
        print alink( $url, $pathway_name ) . "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printImgPathways - Print IMG pathways and reactions in formatted form.
############################################################################
sub printImgPathways {
    my ( $dbh, $gene_oid ) = @_;

    my $mgr  = new ImgTermNodeMgr();
    my $root = $mgr->loadTree($dbh);

    my $sql = qq{
        select ipa.pathway_oid, ipa.status
        from gene g, img_pathway_assertions ipa
        where g.taxon = ipa.taxon
        and g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %asserted;
    for ( ; ; ) {
        my ( $pathway_oid, $status ) = $cur->fetchrow();
        last if !$pathway_oid;
        my $r = "1\t";
        $r .= "$status\t";
        $asserted{$pathway_oid} = $r;
    }
    $cur->finish();

    my @term_oids;
    my $sql = qq{
        select distinct gif.function
        from gene_img_functions gif
        where gif.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ($term_oid) = $cur->fetchrow();
        last if !$term_oid;
        push( @term_oids, $term_oid );
    }
    $cur->finish();
    my %outPathwayOids;
    imgTerm2Pathways( $dbh, $root, \@term_oids, \%outPathwayOids );
    my @pathway_oids = sort( keys(%outPathwayOids) );
    my $pathway_oid_str = join( ',', @pathway_oids );
    if ( blankStr($pathway_oid_str) ) {
        print "<tr class='img' >\n";
        print "<th class='subhead'>IMG Pathways</th>\n";
        print "<td class='img' >\n";
        print nbsp(1);
        print "</td>\n";
        print "</tr>\n";
        return;
    }
    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
        from img_pathway ipw
        where ipw.pathway_oid in( $pathway_oid_str )
        order by ipw.pathway_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $s;
    print "<tr class='img' >\n";
    print "<th class='subhead'>IMG Pathways</th>\n";
    print "<td class='img' >\n";
    my $count = 0;

    for ( ; ; ) {
        my ( $pathway_oid, $pathway_name ) = $cur->fetchrow();
        last if !$pathway_oid;
        $count++;
        my $url = "$main_cgi?section=ImgPwayBrowser" . "&page=imgPwayDetail&pway_oid=$pathway_oid";
        my $x;
        my $ra = $asserted{$pathway_oid};
        my ( $flag, $status ) = split( /\t/, $ra );

        #       $x = " (asserted $status)" if $flag;
        $x = " ($status)" if $flag;

        $x =~ s/ \)$/\)/g;
        print alink( $url, $pathway_name ) . "$x<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printImgPartsList - Print IMG parts list.
############################################################################
sub printImgPartsList {
    my ( $dbh, $gene_oid ) = @_;

#    my $sql = qq{
#       select ipl.parts_list_oid, ipl.parts_list_name
#       from img_parts_list ipl, img_parts_list_img_terms plt,
#           gene_img_functions g, dt_img_term_path tp
#       where ipl.parts_list_oid = plt.parts_list_oid
#       and plt.term = tp.term_oid
#       and tp.map_term = g.function
#       and g.gene_oid = ?
#       order by ipl.parts_list_name
#    };
    my $sql = qq{
       select ipl.parts_list_oid, ipl.parts_list_name
       from img_parts_list ipl, img_parts_list_img_terms plt,
           gene_img_functions g
       where ipl.parts_list_oid = plt.parts_list_oid
       and plt.term = g.function
       and g.gene_oid = ?
       order by ipl.parts_list_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    print "<tr class='img' >\n";
    print "<th class='subhead'>IMG Parts List</th>\n";
    print "<td class='img' >\n";
    my $count = 0;
    for ( ; ; ) {
        my ( $parts_list_oid, $parts_list_name ) = $cur->fetchrow();
        last if !$parts_list_oid;
        $count++;
        my $url = "$main_cgi?section=ImgPartsListBrowser" . "&page=partsListDetail&parts_list_oid=$parts_list_oid";
        print alink( $url, $parts_list_name ) . "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# printLocalization - Print localization information.
############################################################################
sub printLocalization {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select distinct gif.cell_loc
        from gene_img_functions gif
        where gif.gene_oid = ?
        and gif.cell_loc is not null
        order by gif.cell_loc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @recs;
    for ( ; ; ) {
        my ($cell_loc) = $cur->fetchrow();
        last if !$cell_loc;
        push( @recs, $cell_loc );
    }
    $cur->finish();
    return if scalar(@recs) == 0;
    print "<tr class='img' >\n";
    print "<th class='subhead'>Localization</th>\n";
    print "<td class='img' >\n";
    my $count = @recs;
    for my $cell_loc (@recs) {
        print escHtml($cell_loc) . "<br/>\n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printQueryGeneCB - checkbox to add query gene to gene cart
############################################################################
sub printQueryGeneCB {
    my ($gene_oid, $taxon_oid, $data_type) = @_;

    my $workspace_id = $gene_oid;
    my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
    $workspace_id = "$taxon_oid $data_type $gene_oid";
    $url = "$main_cgi?section=MetaGeneDetail" . "&page=metaGeneDetail" .
        "&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid";
    }
    print "<input type='checkbox' " . "name='gene_oid' value='$workspace_id' checked />\n";
    my $link = alink( $url, $gene_oid );
    print "Add query gene $link to gene cart";
    print "</p>\n";
}

############################################################################
# printTopHomologs - Read homologs directly from On the Fly BLAST.
############################################################################
sub printTopHomologs {
    my ( $dbh, $taxon_oid, $data_type, $gene_oid, $isLite, $opType ) = @_;

    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";
    my $clobberCache         = param("clobberCache");
    my $oldMaxHomologResults = param("oldMaxHomologResults");
    if ( $oldMaxHomologResults ne $maxHomologResults ) {
        $clobberCache = 1;
        webLog("maxHomologResults changed clobberCache=$clobberCache\n");
    }
    my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name,
     $start_coord, $end_coord, $strand, $scaffold ) =
      MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
    print "<h2>Top IMG Homolog Hits</h2>\n";

    my $fasta = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
    my $query_aa_seq_length = length($fasta);

    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }

    blastProcCheck();
    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    timeout( 60 * 40 );    # 40 minutes timeout

    webLog ">>> printTopHomologs gene_oid='$gene_oid'\n"
      if $verbose >= 1;

    my $seq;
    my @lines = split( /\n/, $fasta );
    my $seq_id = "query";
    for my $line (@lines) {
        if ( $line =~ /^>/ ) {
            $line =~ s/>//g;
            if ( length($line) > 240 ) {
                $seq_id = substr( $line, 0, 240 );
            } else {
                $seq_id = $line;
            }
            $seq_id =~ s/^\s+//;
            $seq_id =~ s/\s+$//;
            $seq_id =~ s/\r//g;
            if ( $seq_id eq '' ) {
                $seq_id = "query";
            }
        } else {
            $seq .= "$line\n";
        }
    }

    #    $fasta =~ s/^\s+//;
    #    $fasta =~ s/\s+$//;
    #    my $fasta2 = $fasta;
    #    if ( $fasta !~ /^>/ ) {
    #        $fasta2 = ">query$$\n";
    #        $fasta2 .= "$fasta\n";
    #    }

    my $blast_data_dir = $env->{blast_data_dir};

    my $a_flag = "-a 32";         # Number of processors
    my $e_flag = "-e 1e-2";       # E-value cutoff.
    my $b_flag = "-b 1000";       # Maximum number of hits.

    my $db = $img_lid_blastdb;
    $db = $img_iso_blastdb
    if $img_iso_blastdb ne ""
    && param("homologs") eq "topIsolates";
    $db =~ /([a-zA-Z0-9_\-]+)/;
    my $dbFile = "$blast_data_dir/$db";

    webLog( ">>> loadHomologOtfBlast get sequence gene_oid='$gene_oid' "
      . currDateTime() . "\n" );

    #    my $aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );
    my $aa_seq_length = length($seq);

    my $it = new InnerTable($clobberCache, "topHomologs$$", "topHomologs", 9);

    webLog( ">>> loadHomologOtfBlast get top hits " . currDateTime() . "\n" );
    my @homologRecs;

    print "Calculating top hits<br>\n";

    # Run BLAST
    # Write input FASTA file
#    my $gid2    = MetaUtil::sanitizeGeneId3($gene_oid);
#    my $tmpFile = "$cgi_tmp_dir/gene.$gid2.$$.faa";
#    my $wfh     = newWriteFileHandle( $tmpFile, "blastServer" );
#    print $wfh ">$gene_oid\n";
#    print $wfh "$seq\n";
#    close $wfh;
#    print "<p>Run blast ...\n";
#    # please update this cmd to use new BLAST if you want 
#    # to bring it back -- yjlin 03/12/2013
#    my $cmd = "$blastall_bin -p blastp $e_flag -F 'm S' -m 8 $b_flag ";
#    $cmd .= "-i $tmpFile -d $dbFile $a_flag ";
#
#    if ( $verbose >= 1 ) {
#        webLog(
#            ">>> BLAST start " .
#              currDateTime() . " for gene_oid=$gene_oid\n" );
#        webLog("+ $cmd\n");
#    }
#    WebUtil::unsetEnvPath();
#    my $cfh = newCmdFileHandle( $cmd, "blastServer" );
#    my $count = 0;
#    while ( my $s = $cfh->getline() ) {
#        chomp $s;
#
#        my ( $s1, $s2, @s_rest ) = split( /\t/, $s );
#        print "found homolog $s2 ...<br/>\n";
#        $count++;
#        push @homologRecs, ($s);
#    }
#    close $cfh;
#    WebUtil::resetEnvPath();
#    webLog( "BLAST for gene_oid=$gene_oid done with $count rows " . currDateTime() . "\n" ) if $verbose >= 1;
#    unlink($tmpFile);

    ### FIX ME
    require OtfBlast;
    my $workspace_id = "$taxon_oid $data_type $gene_oid";
    my $filterType =
        OtfBlast::genePageTopHits
        ( $dbh, $workspace_id, \@homologRecs, "", $isLite, 1, $opType, '', $seq );
        webLog(   ">>> loadHomologOtfBlast got and retrieved top hits "
                . currDateTime()
                . "\n" );

    print "Done calculating top hits<br>\n";

    #my $filterType = "topHits";
    $it->{filterType} = $filterType;
    my $nHomologRecs = @homologRecs;

    print "<p>nHomologs: $nHomologRecs\n";

    my $trunc = 0;
    my @recs;
    my $count = 0;
    for my $s (@homologRecs) {
#        my (
#             $gene_oid,     $homolog,    $percent_identity, $align_length, $nMisMtach, $nGap,
#             $query_start0, $query_end0, $subj_start0,      $subj_end0,    $evalue,    $bit_score
#          )
#          = split( /\t/, $s );

        my (
             $gene_oid,         $homolog,      $taxon,
             $percent_identity, $query_start0, $query_end0,
             $subj_start0,      $subj_end0,    $evalue,
             $bit_score,        $align_length, $opType
          )
          = split( /\t/, $s );


        my ( $homo_gene, $homo_taxon, $perc ) = split( /\_/, $homolog );

        next if $gene_oid eq $homo_gene;

        if ( $count > $maxHomologResults ) {
            $trunc = 1;
            webLog( "loadHomologOtfBlast: truncate at " . "$maxHomologResults rows\n" );
            last;
        }
        $count++;
        my $query_start = $query_start0;
        my $query_end   = $query_end0;
        if ( $query_start0 > $query_end0 ) {
            $query_start = $query_end0;
            $query_end   = $query_start0;
        }

        my $r = "$homo_gene\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start0\t";
        $r .= "$subj_end0\t";
        $r .= "$align_length\t";
        $r .= "$opType\t";
        push( @recs, $r );
    }

    # --es 07/16/08 runs too slowly
    #if( $img_lite ) {
    #    # Get "on the fly" orthologs and paralogs from running BLAST.
    #   getOtfOrthlogs( $dbh, $gene_oid,
    #       \@homologRecs, \%orthologs, \%paralogs );
    #}
    #    $nHomologRecs = $count;
    #    if ($trunc) {
    #        $it->{maxHomologResults} = $maxHomologResults;
    #        $it->{truncHomologs}     = 1;
    #    }
    my @recs2 = getGeneTaxonAttributes( $dbh, \@recs );

    #    my $taxonFilterHash_ref = getTaxonFilterHash();
    #    my $nFilterTaxons       = scalar( keys(%$taxonFilterHash_ref) );

    #    my @htRecs = getHorizontalTransfers( $dbh, \@recs2, $gene_oid );
    my @htRecs  = ();
    my $nHtRecs = @htRecs;
    my %htPhyla_h;
    my @htPhylaRecs;
    my %htHomologs;

    #    for my $htRec (@htRecs) {
    #        my ( $homolog, $phyloLevel, $phyloVal ) = split( /\t/, $htRec );
    #        my $k = "$phyloLevel\t";
    #        $k .= "$phyloVal\t";
    #        $htPhyla_h{$k}        = 1;
    #        $htHomologs{$homolog} = 1;
    #    }
    #    my @htPhylaRecs = sort( keys(%htPhyla_h) );

    printEndWorkingDiv();

    $it->addColSpec("Select");
    $it->addColSpec( "Homolog",              "asc",  "left" );
    $it->addColSpec( "T",                    "desc", "left" );
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",        "desc", "right" );
    $it->addColSpec( "E-value",       "asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "desc", "right" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",         "asc",  "left" );
        $it->addColSpec( "Scaffold<br/>Length", "desc", "right" );
        $it->addColSpec( "Scaffold<br/>GC",     "desc", "right" );

        #$it->addColSpec( "Scaffold<br/>Depth", "desc", "right" );
    }
    my $sd = $it->getSdDelim();
    my %taxonsHit;
    my $percIdentRejects   = 0;
    my $alignPerc1Rejects  = 0;
    my $alignPerc2Rejects  = 0;
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    #    my $query_taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    my $query_taxon_oid = $taxon_oid;
    $taxonsHit{$query_taxon_oid} = $query_taxon_oid;
    my $count = 0;
    for my $r (@recs2) {
        my (
             $homolog,            $gene_display_name,  $percent_identity, $evalue,         $bit_score,
             $query_start,        $query_end,          $subj_start,       $subj_end,       $align_length,
             $opType,             $subj_aa_seq_length, $taxon_oid,        $domain,         $seq_status,
             $taxon_display_name, $scf_ext_accession,  $scf_seq_length,   $scf_gc_percent, $scf_read_depth
          )
          = split( /\t/, $r );
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        my $alignPercent = $align_length / $aa_seq_length * 100;
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $count++;

        my $gene_url  = "$section_cgi&page=geneDetail&gene_oid=$homolog";
        my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $evalue2   = sprintf( "%.1e", $evalue );
        my $op;

        #        $op = "O" if $orthologs{"$gene_oid-$homolog"} ne "";
        #        $op = "P" if $paralogs{"$gene_oid-$homolog"}  ne "";
        #$op .= "H" if $htHomologs{$homolog};
        $op = $opType; #if $include_bbh_lite;
        $op = "-" if $op eq "";
        my $r;
        my $ck;
        $ck = "checked" if $selectedGeneOids{$homolog} ne "";
        $r .= "$sd<input type='checkbox' name='gene_oid' " . "value='$homolog' $ck />\t";
        $r .= $homolog . $sd . alink( $gene_url, $homolog ) . "\t";
        $r .= "$op\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "${subj_aa_seq_length}${sd}${subj_aa_seq_length}aa\t";
        $r .= "$evalue2\t";
        my $bit_score2 = sprintf( "%.1f", $bit_score );
        $r .= "$bit_score2\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sd . alink( $taxon_url, $taxon_display_name ) . "\t";

        if ($include_metagenomes) {
            $r .= "$scf_ext_accession\t";
            $r .= "$scf_seq_length\t";
            $r .= "$scf_gc_percent\t";

            #$r .= "$scf_read_depth\t";
        }
        $it->addRow($r);
        $taxonsHit{$taxon_oid} = $taxon_oid;
    }
    webLog("loadHomologOtfBlast: $count rows loaded\n");

    if ( $count == 0 ) {
        print "<p>\n";
        print "No hits found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    print hiddenVar( "genePageGeneOid", $gene_oid );

    if ($isLite) {
        printHint( "
          <i><u>Lite Homologs</u></i> uses precomputed hits 
          against <i>standard reference genomes</i><br/>
          and possibly other preselected groups. 
          It is fast and usually sufficient.
          <br/> 
          If you don't see any results, or want hits 
          against other metagenomes, use 
          <i><u>Top IMG Homolog Hits</u></i>.
        " );
    }

    printHomologFooter();
    $it->printOuterTable(1);
    printHomologFooter() if $count > 0;

    return;

    #my $name = "_section_PhyloDist_phyloDist";
    my $name = "_section_DistanceTree_phyloTree";
    print submit(
                  -name  => $name,
                  -value => "Phylogenetic Distribution",
                  -class => 'medbutton'
    );

    print "<p>\n";
    my $x;
    $x = "H - Putative origin of Horizontal Transfer, "
      if $include_ht_homologs;
    print "Types (T): O = Ortholog, P = Paralog, $x" . "- = other unidirectional hit.<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    printAddQueryGeneCheckBox($gene_oid);

    if ( $nHtRecs > 0 ) {
        print "<p>\n";
        print "<font color='red'>\n";
        for my $r (@htPhylaRecs) {
            my ( $phyloLevel, $phyloVal ) = split( /\t/, $r );
            print "Horizontal transfer from <i>" . escHtml($phyloLevel) . " '" . escHtml($phyloVal) . "</i>'.<br/>\n";
        }
        print "</font>\n";
        print "</p>\n";
    }

    printHomologFooter();
    $it->printOuterTable(1);
    printHomologFooter() if $count > 0;

    my $url = "$main_cgi?section=OtfBlast&genePageGenomeBlast=1";
    $url .= "&genePageGeneOid=$gene_oid";
    my $link = alink( $url, "IMG Genome BLAST" );
    print "<p>\n";
    print "Try $link for a more specific selection of genomes ";
    print "when running BLAST.\n";
    print "</p>\n";

    print hiddenVar( "xlogSource", "otfBlast" );
    my $outFile = "$cgi_tmp_dir/otfTaxonsHit.$gene_oid.txt";
    my @keys    = sort( keys(%taxonsHit) );
    my $wfh     = newWriteFileHandle( $outFile, "loadHomologOtfBlast" );
    for my $k (@keys) {
        print $wfh "$k\n";
    }
    close $wfh;
}

############################################################################
# printTopAssembleHomologs - Top hits from the assembled part
#                            of the same MER-FS metagenome
############################################################################
sub printTopAssembleHomologs {
    my ( $dbh, $taxon_oid, $data_type, $gene_oid, $isLite, $opType ) = @_;

    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";
    my $clobberCache         = param("clobberCache");
    my $oldMaxHomologResults = param("oldMaxHomologResults");
    if ( $oldMaxHomologResults ne $maxHomologResults ) {
        $clobberCache = 1;
        webLog("maxHomologResults changed clobberCache=$clobberCache\n");
    }
    my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold ) =
      MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );

    print "<h2>Top IMG Homolog Hits (Assembled Part of the Same Metagenome)</h2>\n";

    my $fasta = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );

    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }

    blastProcCheck();
    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    timeout( 60 * 40 );    # 40 minutes timeout

    webLog ">>> printTopAssembleHomologs gene_oid='$gene_oid'\n"
      if $verbose >= 1;

    my $seq;
    my @lines = split( /\n/, $fasta );
    my $seq_id = "query";
    for my $line (@lines) {
        if ( $line =~ /^>/ ) {
            $line =~ s/>//g;
            if ( length($line) > 240 ) {
                $seq_id = substr( $line, 0, 240 );
            } else {
                $seq_id = $line;
            }
            $seq_id =~ s/^\s+//;
            $seq_id =~ s/\s+$//;
            $seq_id =~ s/\r//g;
            if ( $seq_id eq '' ) {
                $seq_id = "query";
            }
        } else {
            $seq .= "$line\n";
        }
    }

    # OBSOLETE location
    my $blast_data_dir = $mer_data_dir . "/" . sanitizeInt($taxon_oid) . "/assembled/blast.data";
    $blast_data_dir = $sandbox_blast_data_dir . "/" . sanitizeInt($taxon_oid) if($sandbox_blast_data_dir ne '');

    my $a_flag = "-a 32";         # Number of processors
    my $e_flag = "-e 1e-2";       # E-value cutoff.
    my $b_flag = "-b 1000";       # Maximum number of hits.

    my $db = sanitizeInt($taxon_oid) . ".a.faa";
    $db =~ /([a-zA-Z0-9_\-\.]+)/;
    my $dbFile = "$blast_data_dir/$db";

    webLog( ">>> loadHomologOtfBlast get sequence gene_oid='$gene_oid' "
      . currDateTime() . "\n" );

    #    my $aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );
    my $aa_seq_length       = length($fasta);
    my $query_aa_seq_length = $aa_seq_length;

    my $it = new InnerTable( $clobberCache, "topHomologs$$", "topHomologs", 9 );

    webLog( ">>> loadHomologOtfBlast get top hits " . currDateTime() . "\n" );
    my @homologRecs;

    print "Calculating top hits<br>\n";

    # Write input FASTA file
    my $gid2    = MetaUtil::sanitizeGeneId3($gene_oid);
    my $tmpFile = "$cgi_tmp_dir/gene.$gid2.$$.faa";
    my $wfh     = newWriteFileHandle( $tmpFile, "blastServer" );
    print $wfh ">$gene_oid\n";
    print $wfh "$seq\n";
    close $wfh;

    # Run BLAST
    print "<p>Run blast ...\n";

    ## New BLAST
    my $cmd = "$blastall_bin/legacy_blast.pl blastall "
            . " -p blastp $e_flag -F 'm S' -m 8 $b_flag "
            . " -i $tmpFile -d $dbFile $a_flag "
            . " --path $blastall_bin ";
            # --path is needed although fullpath of legacy_blast.pl is
            # specified in the beginning of command! ---yjlin 03/12/2013


    if ( $verbose >= 1 ) {
        webLog( ">>> BLAST start " . currDateTime() . " for gene_oid=$gene_oid\n" );
        webLog("+ $cmd\n");
    }

    my $contact_oid = getContactOid();
    if ( $contact_oid == 312 ) {
        print "*** cmd: $cmd<br/>\n";
    }

    WebUtil::unsetEnvPath();
    my $cfh = newCmdFileHandle( $cmd, "blastServer" );
    my $count = 0;
    while ( my $s = $cfh->getline() ) {
        chomp $s;

        my ( $s1, $s2, @s_rest ) = split( /\t/, $s );
        print "found homolog $s2 ...<br/>\n";
        $count++;
        push @homologRecs, ($s);
    }
    close $cfh;
    WebUtil::resetEnvPath();
    webLog( "BLAST for gene_oid=$gene_oid done with $count rows " . currDateTime() . "\n" ) if $verbose >= 1;

    unlink($tmpFile);

    print "Done calculating top hits<br>\n";

    my $filterType = "topHits";
    $it->{filterType} = $filterType;
    my $nHomologRecs = @homologRecs;

    print "<p>nHomologs: $nHomologRecs\n";

    my $trunc = 0;
    my @recs;
    my $count = 0;
    for my $s (@homologRecs) {
        my (
             $gene_oid,     $homolog,    $percent_identity, $align_length, $nMisMatch, $nGap,
             $query_start0, $query_end0, $subj_start0,      $subj_end0,    $evalue,    $bit_score
          )
          = split( /\t/, $s );
        next if $gene_oid eq $homolog;

        if ( $count > $maxHomologResults ) {
            $trunc = 1;
            webLog( "loadHomologOtfBlast: truncate at " . "$maxHomologResults rows\n" );
            last;
        }
        $count++;
        my $query_start = $query_start0;
        my $query_end   = $query_end0;
        if ( $query_start0 > $query_end0 ) {
            $query_start = $query_end0;
            $query_end   = $query_start0;
        }
        my $opType = "";

        #   my ($homo_gene, $homo_taxon, $perc) = split(/\_/, $homolog);
        #        my $r = "$homo_gene\t";
        my ( undef, $homolog_gene_oid ) = split('\:', $homolog);
        $homolog = $homolog_gene_oid;
        my $r = "$homolog\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start0\t";
        $r .= "$subj_end0\t";
        $r .= "$align_length\t";
        $r .= "$opType\t";
        push( @recs, $r );
    }

    my @recs2   = getMetaGeneTaxonAttributes( $dbh, $taxon_oid, 'assembled', \@recs );
    my @htRecs  = ();
    my $nHtRecs = @htRecs;
    my %htPhyla_h;
    my @htPhylaRecs;
    my %htHomologs;

    printEndWorkingDiv();

    $it->addColSpec("Select");
    $it->addColSpec( "Homolog",              "asc",  "left" );
    $it->addColSpec( "T",                    "desc", "left" );
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",        "desc", "right" );
    $it->addColSpec( "E-value",       "asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "desc", "right" );

    #    $it->addColSpec( "Domain",        "asc",  "center", "",
    #            "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    #    $it->addColSpec( "Status",        "asc",  "center", "",
    #            "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    #    $it->addColSpec( "Genome Name",   "asc",  "left" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",         "asc",  "left" );
        $it->addColSpec( "Scaffold<br/>Length", "desc", "right" );
        $it->addColSpec( "Scaffold<br/>GC",     "desc", "right" );
        $it->addColSpec( "Scaffold<br/>Depth",  "desc", "right" );
    }
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";
    
    my %taxonsHit;
    my $percIdentRejects   = 0;
    my $alignPerc1Rejects  = 0;
    my $alignPerc2Rejects  = 0;
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    #    my $query_taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    my $query_taxon_oid = $taxon_oid;
    $taxonsHit{$query_taxon_oid} = $query_taxon_oid;
    my $count = 0;
    for my $r (@recs2) {
        my (
             $homolog,            $gene_display_name,  $percent_identity, $evalue,         $bit_score,
             $query_start,        $query_end,          $subj_start,       $subj_end,       $align_length,
             $opType,             $subj_aa_seq_length, $taxon_oid,        $domain,         $seq_status,
             $taxon_display_name, $scf_ext_accession,  $scf_seq_length,   $scf_gc_percent, $scf_read_depth
          )
          = split( /\t/, $r );
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        my $alignPercent = $align_length / $aa_seq_length * 100;
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $count++;

        my $gene_url  = "$section_cgi&page=metaGeneDetail&gene_oid=$homolog" 
                      . "&taxon_oid=$taxon_oid&data_type=assembled";
        my $taxon_url = "$main_cgi?section=TaxonDetail" 
                      . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $evalue2   = sprintf( "%.1e", $evalue );
        my $op;

        #        $op = "O" if $orthologs{"$gene_oid-$homolog"} ne "";
        #        $op = "P" if $paralogs{"$gene_oid-$homolog"}  ne "";
        $op .= "H" if $htHomologs{$homolog};
        $op = $opType; # if $include_bbh_lite;
        $op = "-" if $op eq "";
        my $r;
        my $ck;
        $ck = "checked" if $selectedGeneOids{$homolog} ne "";
        my $workspace_id = "$taxon_oid assembled $homolog";
        $r .= "$sd<input type='checkbox' name='$select_id_name' " 
            . "value='$workspace_id' $ck />\t";
        $r .= $workspace_id . $sd . alink( $gene_url, $homolog ) . "\t";
        $r .= "$op\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length )
            . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length )
            . "\t";
        $r .= "${subj_aa_seq_length}${sd}${subj_aa_seq_length}aa\t";
        $r .= "$evalue2\t";
        my $bit_score2 = sprintf( "%.1f", $bit_score );
        $r .= "$bit_score2\t";

        #        $r .= "$domain\t";
        #        $r .= "$seq_status\t";
        #        $r .= $taxon_display_name . $sd
        #          . alink( $taxon_url, $taxon_display_name ) . "\t";

        if ($include_metagenomes) {
            # scaffold ID
            my $scaf_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaScaffoldDetail&scaffold_oid=$scf_ext_accession"
              . "&taxon_oid=$taxon_oid&data_type=$data_type";
            my $scaf_link = alink( $scaf_url, $scf_ext_accession );
            $r .= $scf_ext_accession . $sd . $scaf_link . "\t";

            # scaffold length
            my $scaf_len_url =
                "$main_cgi?section=MetaScaffoldGraph"
              . "&page=metaScaffoldGraph&scaffold_oid=$scf_ext_accession"
              . "&taxon_oid=$taxon_oid"
              . "&start_coord=1&end_coord=$scf_seq_length"
              . "&marker_gene=$homolog&seq_length=$scf_seq_length";
            my $scaf_len_link = alink( $scaf_len_url, $scf_seq_length );
            $r .= $scf_seq_length . $sd . $scaf_len_link . "\t";

            # scaffold GC
            $r .= "$scf_gc_percent\t";

            # scaffold depth
            $r .= "$scf_read_depth\t";
        }
        $it->addRow($r);
        $taxonsHit{$taxon_oid} = $taxon_oid;
    }
    webLog("loadHomologOtfBlast: $count rows loaded\n");

    if ( $count == 0 ) {
        print "<p>\n";
        print "No hits found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    print hiddenVar( "genePageGeneOid", $gene_oid );

    if ($isLite) {
        printHint( "
          <i><u>Lite Homologs</u></i> uses precomputed hits 
          against <i>standard reference genomes</i><br/>
          and possibly other preselected groups. 
          It is fast and usually sufficient.
          <br/> 
          If you don't see any results, or want hits 
          against other metagenomes, use 
          <i><u>Top IMG Homolog Hits</u></i>.
        " );
    }

    if ( $count <= 0 ) {
        return;
    }

    print "<p>\n";
    if ( $select_id_name eq "gene_oid" ) {
        WebUtil::printGeneCartFooter() if ( $count > 10 );
    } else {
        WebUtil::printButtonFooter() if ( $count > 10 );
    }

    $it->printOuterTable(1);

    if ( $select_id_name eq "gene_oid" ) {
        WebUtil::printGeneCartFooter();
    } else {
        WebUtil::printButtonFooter();
    }

    if ( $count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }
    
}

############################################################################
# printClusterHomologs - Read homologs directly from cluster homologs
#   with on the fly blast.
############################################################################
sub printClusterHomologs {
    my ( $dbh, $gene_oid, $isLite, $opType ) = @_;

    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";
    my $clobberCache         = param("clobberCache");
    my $oldMaxHomologResults = param("oldMaxHomologResults");
    if ( $oldMaxHomologResults ne $maxHomologResults ) {
        $clobberCache = 1;
        webLog("maxHomologResults changed clobberCache=$clobberCache\n");
    }
    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    print "<h2>Top IMG Cluster Homolog Hits</h2>\n";
    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my $it = new InnerTable( $clobberCache, "topHomologs$$", "topHomologs", 9 );

    my %orthologs;
    my %paralogs;

    print "Finding gene $gene_oid orthologs<br>\n";

    getOrthologs( $dbh, $gene_oid, \%orthologs );

    print "Finding gene $gene_oid paralogs<br>\n";
    getParalogs( $dbh, $gene_oid, \%paralogs );

    my $aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    my @homologRecs;

    print "Calculating top hits<br>\n";

    require OtfBlast;
    my $filterType = OtfBlast::genePageTopHits( $dbh, $gene_oid, \@homologRecs, "", $isLite, 1, $opType, "clusterHomologs" );

    print "Done calculating top hits<br>\n";

    $it->{filterType} = $filterType;
    my $nHomologRecs = @homologRecs;

    my $trunc = 0;
    my @recs;
    my $count = 0;
    for my $s (@homologRecs) {
        my (
             $gene_oid,    $homolog,   $taxon,  $percent_identity, $query_start0, $query_end0,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length, $opType
          )
          = split( /\t/, $s );
        next if $gene_oid == $homolog;

        if ( $count > $maxHomologResults ) {
            $trunc = 1;
            webLog( "loadHomologOtfBlast: truncate at " . "$maxHomologResults rows\n" );
            last;
        }
        $count++;
        my $query_start = $query_start0;
        my $query_end   = $query_end0;
        if ( $query_start0 > $query_end0 ) {
            $query_start = $query_end0;
            $query_end   = $query_start0;
        }

        my $r = "$homolog\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start0\t";
        $r .= "$subj_end0\t";
        $r .= "$align_length\t";
        $r .= "$opType\t";
        push( @recs, $r );
    }

    # --es 07/16/08 runs too slowly
    #if( $img_lite ) {
    #    # Get "on the fly" orthologs and paralogs from running BLAST.
    #   getOtfOrthlogs( $dbh, $gene_oid,
    #       \@homologRecs, \%orthologs, \%paralogs );
    #}
    $nHomologRecs = $count;
    if ($trunc) {
        $it->{maxHomologResults} = $maxHomologResults;
        $it->{truncHomologs}     = 1;
    }
    my @recs2 = getGeneTaxonAttributes( $dbh, \@recs );

    my $taxonFilterHash_ref = getTaxonFilterHash();
    my $nFilterTaxons       = scalar( keys(%$taxonFilterHash_ref) );

    my @htRecs = getHorizontalTransfers( $dbh, \@recs2, $gene_oid );
    my $nHtRecs = @htRecs;
    my %htPhyla_h;
    my @htPhylaRecs;
    my %htHomologs;
    for my $htRec (@htRecs) {
        my ( $homolog, $phyloLevel, $phyloVal ) = split( /\t/, $htRec );
        my $k = "$phyloLevel\t";
        $k .= "$phyloVal\t";
        $htPhyla_h{$k}        = 1;
        $htHomologs{$homolog} = 1;
    }
    my @htPhylaRecs = sort( keys(%htPhyla_h) );
    printEndWorkingDiv();

    $it->addColSpec("Select");
    $it->addColSpec( "Homolog",              "asc",  "left" );
    $it->addColSpec( "T",                    "desc", "left" );
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",        "desc", "right" );
    $it->addColSpec( "E-value",       "asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "desc", "right" );
    $it->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",         "asc",  "left" );
        $it->addColSpec( "Scaffold<br/>Length", "desc", "right" );
        $it->addColSpec( "Scaffold<br/>GC",     "desc", "right" );

        #$it->addColSpec( "Scaffold<br/>Depth", "desc", "right" );
    }
    my $sd = $it->getSdDelim();
    my %taxonsHit;
    my $percIdentRejects   = 0;
    my $alignPerc1Rejects  = 0;
    my $alignPerc2Rejects  = 0;
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    my $query_taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    $taxonsHit{$query_taxon_oid} = $query_taxon_oid;
    my $count = 0;
    for my $r (@recs2) {
        my (
             $homolog,            $gene_display_name,  $percent_identity, $evalue,         $bit_score,
             $query_start,        $query_end,          $subj_start,       $subj_end,       $align_length,
             $opType,             $subj_aa_seq_length, $taxon_oid,        $domain,         $seq_status,
             $taxon_display_name, $scf_ext_accession,  $scf_seq_length,   $scf_gc_percent, $scf_read_depth
          )
          = split( /\t/, $r );
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        my $alignPercent = $align_length / $aa_seq_length * 100;
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $count++;
        my $gene_url  = "$section_cgi&page=geneDetail&gene_oid=$homolog";
        my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $evalue2   = sprintf( "%.1e", $evalue );
        my $op;
        $op = "O" if $orthologs{"$gene_oid-$homolog"} ne "";
        $op = "P" if $paralogs{"$gene_oid-$homolog"}  ne "";
        $op .= "H" if $htHomologs{$homolog};
        $op = $opType if $include_bbh_lite;
        $op = "-" if $op eq "";
        my $r;
        my $ck;
        $ck = "checked" if $selectedGeneOids{$homolog} ne "";
        $r .= "$sd<input type='checkbox' name='gene_oid' " . "value='$homolog' $ck />\t";
        $r .= $homolog . $sd . alink( $gene_url, $homolog ) . "\t";
        $r .= "$op\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "${subj_aa_seq_length}${sd}${subj_aa_seq_length}aa\t";
        $r .= "$evalue2\t";
        my $bit_score2 = sprintf( "%.1f", $bit_score );
        $r .= "$bit_score2\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sd . alink( $taxon_url, $taxon_display_name ) . "\t";

        if ($include_metagenomes) {
            $r .= "$scf_ext_accession\t";
            $r .= "$scf_seq_length\t";
            $r .= "$scf_gc_percent\t";

            #$r .= "$scf_read_depth\t";
        }
        $it->addRow($r);
        $taxonsHit{$taxon_oid} = $taxon_oid;
    }
    webLog("loadHomologOtfBlast: $count rows loaded\n");

    if ( $count == 0 ) {
        print "<p>\n";
        print "No hits found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return 0;
    }

    print hiddenVar( "genePageGeneOid", $gene_oid );

    if ($isLite) {
        printHint( "
          <i><u>Lite Homologs</u></i> uses precomputed hits 
          against <i>standard reference genomes</i><br/>
          and possibly other preselected groups. 
          It is fast and usually sufficient.
          <br/> 
          If you don't see any results, or want hits 
          against other metagenomes, use 
          <i><u>Top IMG Homolog Hits</u></i>.
        " );
    }

    my $name = "_section_DistanceTree_phyloTree";
    print submit(
                  -name  => $name,
                  -value => "Phylogenetic Distribution",
                  -class => 'medbutton'
    );

    print "<p>\n";
    my $x;
    $x = "H - Putative origin of Horizontal Transfer, "
      if $include_ht_homologs;
    print "Types (T): O = Ortholog, P = Paralog, $x" . "- = other unidirectional hit.<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    printAddQueryGeneCheckBox($gene_oid);

    if ( $nHtRecs > 0 ) {
        print "<p>\n";
        print "<font color='red'>\n";
        for my $r (@htPhylaRecs) {
            my ( $phyloLevel, $phyloVal ) = split( /\t/, $r );
            print "Horizontal transfer from <i>" . escHtml($phyloLevel) . " '" . escHtml($phyloVal) . "</i>'.<br/>\n";
        }
        print "</font>\n";
        print "</p>\n";
    }

    printHomologFooter();
    $it->printOuterTable(1);
    printHomologFooter() if $count > 0;

    my $url = "$main_cgi?section=OtfBlast&genePageGenomeBlast=1";
    $url .= "&genePageGeneOid=$gene_oid";
    my $link = alink( $url, "IMG Genome BLAST" );
    print "<p>\n";
    print "Try $link for a more specific selection of genomes ";
    print "when running BLAST.\n";
    print "</p>\n";

    print hiddenVar( "xlogSource", "otfBlast" );
    my $outFile = "$cgi_tmp_dir/otfTaxonsHit.$gene_oid.txt";
    my @keys    = sort( keys(%taxonsHit) );
    my $wfh     = newWriteFileHandle( $outFile, "loadHomologOtfBlast" );
    for my $k (@keys) {
        print $wfh "$k\n";
    }
    close $wfh;
}

############################################################################
# getOtfOrthologs - Get "on the fly" orthologs from BLAST.
#   @param $dbh - database handle
#   @param $query_gene_oid - input query gene_oid
#   @param $homologsRecs_ref - input homolog records
#   @param $orthologs_ref - Output orthologs gene_oid-ortholog
#   @param $paralogs_ref - Output paralogs gene_oid-paralog
############################################################################
sub getOtfOrthlogs_old { # Marked as NOT IN USE -- yjlin 03/13/2013
    my ( $dbh, $query_gene_oid, $homologRecs_ref, $orthologs_ref, $paralogs_ref ) = @_;

    my $query_gene_taxon = geneOid2TaxonOid( $dbh, $query_gene_oid );
    my %homologTaxon2Gene;
    for my $s (@$homologRecs_ref) {
        my (
             $gene_oid,   $homolog,  $taxon,  $percent_identity, $query_start, $query_end,
             $subj_start, $subj_end, $evalue, $bit_score,        $align_length
          )
          = split( /\t/, $s );
        split( /\t/, $s );
        next if $gene_oid == $homolog;
        if ( $taxon eq $query_gene_taxon ) {
            $paralogs_ref->{"$query_gene_oid-$homolog"} = 1;
        }
        my $r = "$homolog\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        $r .= "$align_length";

        # Take first hit for a taxon which is the best hit.
        if ( $homologTaxon2Gene{$taxon} eq "" && $taxon ne $query_gene_taxon ) {
            $homologTaxon2Gene{$taxon} = $homolog;
        }
    }
    my $maxEvalue    = "1e-2";
    my $minPercIdent = 25;
    my %orthologs;
    OtfBlast::computeBBH( $dbh, $query_gene_oid, \%homologTaxon2Gene, \%orthologs, $maxEvalue, $minPercIdent );
    my @keys = keys(%orthologs);
    for my $k (@keys) {
        $orthologs_ref->{"$query_gene_oid-$k"} = 1;
    }
}

############################################################################
# printNrHits - Print NR hits data.
############################################################################
sub printNrHits {
    my ( $dbh, $gene_oid ) = @_;

    print "<h2>NR Hits</h2>\n";
    printStatusLine( "Loading ...", 1 );

    my $clobberCache      = param("clobberCache");
    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";
    my $oldMaxHomologResults = getSessionParam("oldMaxHomologResults");
    if ( $oldMaxHomologResults ne $maxHomologResults ) {
        $clobberCache = 1;
        webLog("maxHomologResults changed clobberCache=$clobberCache\n");
    }
    setSessionParam( "oldMaxHomologResults", $maxHomologResults );

    my $aa_seq_length = getAASeqLength( $dbh, $gene_oid );
    my @recs;
    require NrHits;
    my $trunc;
    if ( $ncbi_blast_server_url ne "" ) {
        $trunc = NrHits::loadNcbiServerHits( $dbh, $gene_oid, \@recs, $maxHomologResults );
    } else {
        $trunc = NrHits::loadNrHits( $dbh, $gene_oid, \@recs, $maxHomologResults );
    }
    my $nRecs = @recs;

    my $it = new InnerTable( $clobberCache, "nrHits$$", "nrHits", 8 );
    $it->addColSpec( "GI No.",                 "number asc",  "left" );
    $it->addColSpec( "DB",                     "char asc",    "left" );
    $it->addColSpec( "External<br/>Accession", "char asc",    "left" );
    $it->addColSpec( "Description",            "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity",   "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec( "Length",        "number desc", "right" );
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    $it->addColSpec( "Genome",        "char asc",    "left" );
    my $sd = $it->getSdDelim();

    my $count = 0;
    for my $r (@recs) {
        my (
             $gene_oid,  $giNo,   $db,       $ext_accession,      $desc,
             $percIdent, $alen,   $qstart,   $qend,               $sstart,
             $send,      $evalue, $bitScore, $subj_aa_seq_length, $genome
          )
          = split( /\t/, $r );
        $count++;
        my $r;

        my $url = "$ncbi_entrez_base_url$giNo";
        $r .= $giNo . $sd . alink( $url, $giNo ) . "\t";
        $r .= "$db\t";
        $r .= "$ext_accession\t";
        $r .= "$desc\t";

        $percIdent = sprintf( "%.2f", $percIdent );
        $r .= "$percIdent\t";

        $r .= $sd . alignImage( $qstart, $qend, $aa_seq_length ) . "\t";
        $r .= "$subj_aa_seq_length\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";

        $genome = "-" if $genome eq "";
        $r .= "$genome\t";

        $it->addRow($r);
    }
    if ( $count == 0 ) {
        print "<p>\n";
        print "No hits found.<br/>";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
    }
    $it->printOuterTable(1);
}

############################################################################
# printCategorySummary - Print summary for each categorical value
#  or orthologous genome hit.
############################################################################
sub printCategorySummary {
    my ( $dbh, $gene_oid, $attrName ) = @_;

    my $attrNameCap = substr( $attrName, 0, 1 );
    $attrNameCap =~ tr/a-z/A-Z/;
    $attrNameCap .= substr( $attrName, 1 );

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select distinct cv.${attrName}_term
       from gene_orthologs go, taxon tx, project_info_${attrName}s picv,  
           ${attrName}cv cv
       where go.taxon = tx.taxon_oid
           and tx.project = picv.project_oid
           and picv.${attrName}s = cv.${attrName}_oid
           and go.gene_oid = ?
           $rclause
           $imgClause
       order by cv.${attrName}_term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $thisOrgVal;
    for ( ; ; ) {
        my ($attrVal) = $cur->fetchrow();
        last if !$attrVal;
        next if $attrVal =~ /None/;
        $thisOrgVal .= "$attrVal, ";
    }
    chop $thisOrgVal;
    chop $thisOrgVal;
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select cv.${attrName}_term, count( distinct go.ortholog )
       from gene_orthologs go, taxon tx, project_info_${attrName}s picv,  
           ${attrName}cv cv
       where go.taxon = tx.taxon_oid
           and tx.project = picv.project_oid
           and picv.${attrName}s = cv.${attrName}_oid
           and go.gene_oid = ?
           $rclause
           $imgClause
       group by cv.${attrName}_term
       order by cv.${attrName}_term
    };
    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );

    for ( ; ; ) {
        my ( $attrVal, $cnt ) = $cur->fetchrow();
        last if !$attrVal;
        my $r = "$attrVal\t";
        $r .= "$cnt\t";
        push( @recs, $r );
    }
    $cur->finish();
    return if scalar(@recs) == 0;

    if ( lc($attrName) eq "ecotype" ) {
        print "<h2>Summaries for Habitat</h2>\n";
        print "<p>\n";
        print "Summaries are formed with bidirectional best hits in ";
        print "genomes with specified <i>habitat</i>.<br/>\n";
    } else {
        print "<h2>Summaries for $attrNameCap</h2>\n";
        print "<p>\n";
        print "Summaries are formed with bidirectional best hits in ";
        print "genomes with specified <i>$attrName</i>.<br/>\n";
    }
    print "</p>\n";

    my $baseUrl = "$section_cgi&page=geneDetail";
    $baseUrl .= "&gene_oid=$gene_oid";
    $baseUrl .= "&homologs=$attrName";
    my $clobberCache = param("clobberCache");
    my $ct           = new InnerTable( $clobberCache, "catSummary$$", "catSummary", 1 );

    if ( lc($attrName) eq "ecotype" ) {
        $ct->addColSpec( "Habitat", "char asc", "left" );
    } else {
        $ct->addColSpec( $attrNameCap, "char asc", "left" );
    }

    $ct->addColSpec( "Ortholog<br/>Count", "number desc", "right" );
    my $sd = $ct->getSdDelim();
    for my $r (@recs) {
        my ( $attrVal, $cnt ) = split( /\t/, $r );

        my $r;
        $r .= "$attrVal\t";

        my $url = "$section_cgi&page=orthologCategoryHits";
        $url .= "&gene_oid=$gene_oid";
        $url .= "&categoryName=$attrName";
        $url .= "&categoryVal=" . massageToUrl($attrVal);

        alink( $url, $cnt ) . "</td>\n";
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        $ct->addRow($r);
    }
    $ct->printOuterTable();
}

############################################################################
# printOrthologCategoryHits - Print gene list with ortholog category.
############################################################################
sub printOrthologCategoryHits {
    my $gene_oid     = param("gene_oid");
    my $categoryName = param("categoryName");
    my $categoryVal  = param("categoryVal");

    my $categoryValEsc = $categoryVal;

    #$categoryValEsc =~ s/'/''/g;    #'

    my $dbh                 = dbLogin();
    my $gene_display_name   = geneOid2Name( $dbh, $gene_oid );
    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    my $categoryLabel = $categoryName;
    if ( $categoryName eq "ecotype" ) {
        $categoryLabel = "habitat";
    }
    print "<h1>Orthologs with genomes in $categoryLabel</h1>\n";
    print "<p>\n";
    print "Orthologs to gene $gene_oid ";
    print "<i>" . escHtml($gene_display_name) . "</i>.<br/>\n";
    print "(Orthologs are bidirectional best hits from BLASTP ";
    print "against genomes with the following ";
    print "$categoryLabel: <i>" . escHtml($categoryVal) . "</i>.)<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my %regionScores;

    #loadRegionScore( $dbh, $gene_oid, \%regionScores );

    my $rclause1   = WebUtil::urClause('tx');
    my $imgClause1 = WebUtil::imgClause('tx');
    my $rclause2   = WebUtil::urClause('g.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql        = qq{
       select go.ortholog, g.gene_display_name, go.percent_identity,
           go.evalue, go.bit_score, go.query_start, go.query_end, 
           go.subj_start, go.subj_end, go.align_length, g.aa_seq_length,
           tx.taxon_oid, tx.domain, tx.seq_status,
           tx.taxon_display_name
       from gene g, taxon tx,
           project_info_${categoryName}s picv,  
           ${categoryName}cv cv, gene_orthologs go
       where go.gene_oid = ?
           and go.ortholog = g.gene_oid
           and go.taxon = tx.taxon_oid
           and tx.project = picv.project_oid
           and picv.${categoryName}s = cv.${categoryName}_oid
           and cv.${categoryName}_term = ?
           $rclause1
           $imgClause1
           $rclause2
           $imgClause2
       order by go.bit_score desc
    };
    my @binds = ( $gene_oid, $categoryValEsc );
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $baseUrl = "$section_cgi&page=orthologCategoryHits";
    $baseUrl .= "&gene_oid=$gene_oid";
    $baseUrl .= "&categoryName=$categoryName";
    $baseUrl .= "&categoryVal=" . massageToUrl($categoryVal);
    my $clobberCache = param("clobberCache");
    my $ct           = new InnerTable( $clobberCache, "orthologCatHits$$", "ortholog", 7, $baseUrl );

    #my $ct = new CachedTable( "orthologCat$gene_oid", $baseUrl );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Ortholog",             "number asc",  "left" );
    $ct->addColSpec( "Product Name",         "char asc",    "left" );
    $ct->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $ct->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $ct->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $ct->addColSpec( "Length",    "number desc", "right" );
    $ct->addColSpec( "E-value",   "number asc",  "left" );
    $ct->addColSpec( "Bit Score", "number desc", "right" );

    #$ct->addColSpec( "Cons. Score<sup>1</sup>", "number desc", "right" )
    #   if $mysql_config eq "";
    $ct->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );

    $ct->addColSpec( "Genome Name", "char asc", "left" );
    my $sd    = $ct->getSdDelim();
    my $count = 0;
    for ( ; ; ) {
        my (
             $ortholog,           $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$ortholog;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $count++;
        my $cons_region_score = $regionScores{$ortholog};
        $cons_region_score = 0 if $cons_region_score eq "";
        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$ortholog' />\t";
        my $url = "$section_cgi&page=geneDetail&gene_oid=$ortholog";
        $r .= $ortholog . $sd . alink( $url, $ortholog ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "$subj_aa_seq_length${sd}${subj_aa_seq_length}aa\t";
        my $evalue_f = sprintf( "%.1e", $evalue );
        $r .= "$evalue_f\t";
        my $bit_score2 = sprintf( "%d", $bit_score );
        $r .= "$bit_score2\t";

        #$r .= "$cons_region_score\t" if $mysql_config eq "";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $ct->addRow($r);
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    printGeneCartFooter() if $count > 10;
    $ct->printTable(1);
    printGeneCartFooter();

    #print "<p>\n";
    #my $url = "$section_cgi&page=consRegionScoreNote";
    #print "1 - ". alink( $url, "Conserved Region Score Note" ) . "<br/>\n";
    #print "</p>\n";

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$count ortholog(s) retrieved.", 2 );
    print end_form;
}

############################################################################
# getOrthologs - Get orthologs given gene_oid.   Used in homologs page
#   to mark the orthologs as 'O'.
############################################################################
sub getOrthologs {
    my ( $dbh, $gene_oid, $h_ref ) = @_;
    my $sql = qq{
        select x.ortholog 
        from gene_orthologs x
        where x.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ($x) = $cur->fetchrow();
        last if !$x;
        $h_ref->{"$gene_oid-$x"} = 1;
    }
    $cur->finish();
}

############################################################################
# getParalogs - Get paralogs given gene_oid. Used in homologs page to
#   mark homolog as 'P'.
############################################################################
sub getParalogs {
    my ( $dbh, $gene_oid, $h_ref ) = @_;
    my $sql = qq{
        select x.paralog
        from gene_paralogs x
        where x.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ($x) = $cur->fetchrow();
        last if !$x;
        $h_ref->{"$gene_oid-$x"} = 1;
    }
    $cur->finish();
}

############################################################################
# getAASeqLength - Get amino acid sequence length.
############################################################################
sub getAASeqLength {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select g.aa_seq_length
        from gene g 
        where g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($aa_seq_length) = $cur->fetchrow();
    $cur->finish();
    return $aa_seq_length;
}

############################################################################
# printMetaRnaHomologsBlast - Print RNA based homologs through Blast
############################################################################
sub printMetaRnaHomologsBlast {
    my ( $dbh, $workspace_id, $query_dna_seq_length, $seq ) = @_; 
 
    my $rnaHomologs = param("rnaHomologs");
    my $max;
    if ( $rnaHomologs eq 'topMetaRnas' ) {
        print "<h1>Top IMG Metagenome RNA Hits</h1>\n";
        $max = 200;
    }
    else {
        print "<h1>Top IMG Isolate RNA Hits</h1>\n";
        $max = 1000;
    }
    printHint( "Only display a maximum of $max hits." );

    my ($taxon_oid, $data_type, $gene_oid0) = split(/ /, $workspace_id);
    #print "printMetaRnaHomologsBlast() gene_oid=$gene_oid0<br/>\n";
    webLog ">>> printMetaRnaHomologsBlast() gene_oid='$gene_oid0'\n"
        if $verbose >= 1;
    my $gene_lid = "${gene_oid0}";
    #my $gene_lid = "${gene_oid0}_${taxon_oid}_${query_dna_seq_length}"; #not working for some taxons
    #print( "printMetaRnaHomologsBlast() gene_lid: $gene_lid<br/>\n" );
 
    printStartWorkingDiv( );

    print "Retrieving BLAST hits ...<br/>\n"; 
    my %validTaxons;
    if ( $rnaHomologs eq 'topMetaRnas' ) {
        %validTaxons = WebUtil::getAllTaxonsHashed( $dbh, 2 );  # metagenome only
    }
    else {
        %validTaxons = WebUtil::getAllTaxonsHashed( $dbh, 1 );  # isolate only
    }
 
    #WebUtil::unsetEnvPath( );                                                
    my $rfh;
    if ( $rna_server_url ne "" ) {  
        my $db = $img_rna_blastdb;
        if ( $rnaHomologs eq 'topMetaRnas' ) {
            $db = $img_meta_rna_blastdb;
        }
        webLog("printMetaRnaHomologsBlast() rnaHomologs=$rnaHomologs db=$db\n");
        #print("printMetaRnaHomologsBlast() rnaHomologs=$rnaHomologs db=$db\n");

        my %args = ( 
           gene_lid => $gene_lid,
           db       => $db, 
           seq      => $seq,
           top_n    => 10000, 
        ); 
        #print( "args: <br/>\n" );
        #print Dumper(\%args);
        #print( "<br/>\n" );
        #print( ">>> Call $rna_server_url<br/>\n" );
        webLog( ">>> Call $rna_server_url\n" ); 
        $rfh = new LwpHandle( $rna_server_url, \%args ); 
    } 

    if( !$rfh ) { 
        webDie( "rna_server_url not set\n" ); 
    } 

    my $count = 0; 
    my @recs; 
    my %homologOids; 
    while( my $s = $rfh->getline( ) ) { 
        chomp $s; 
        my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
            $qstart, $qend, $sstart, $send, $evalue, $bitScore ) 
            = split( /\t/, $s ); 
        next if $percIdent < 30;

        my( $qgene_oid, $qtaxon, $qlen, $qsymbol ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen, $ssymbol );
        if ( $rnaHomologs eq 'topMetaRnas' ) {
           my ($a_type, $sg_oid);
           ( $staxon, $a_type, $sg_oid ) = split( /[.:]/, $sid );
           $sgene_oid = "$staxon assembled $sg_oid";
        }
        else {
           ( $sgene_oid, $staxon, $slen, $ssymbol ) = split( /_/, $sid );            
        }
        next if !$validTaxons{ $staxon };
        next if $qgene_oid eq $sgene_oid; 
        my $qalign = abs( $qend - $qstart ) + 1;
        next if $qalign < 0.7 * $qlen;
        next if ( $homologOids{$sgene_oid} );

        $homologOids{ $sgene_oid } = 1; 
        push( @recs, $s );
        $count++;
        if ( $count >= $max ) {
            last;
        }
    } 
    $rfh->close(); 
    #print( "homologOids: <br/>\n" );
    #print Dumper(\%homologOids);
    #print( "<br/>\n" );
 
    print "Retrieve gene information ...<br/>\n";
    my @homologs = sort( keys( %homologOids ) );
    my %homologRecs; 
    if ( $rnaHomologs eq 'topMetaRnas' ) {
        GeneUtil::flushRnaMetaHomologRecs( $dbh, \@homologs, \%homologRecs );
    }
    else {
        GeneUtil::flushRnaHomologRecs( $dbh, \@homologs, \%homologRecs );
    }
 
    print "Merge hits with gene information ...<br/>\n";
    my $count = 0; 
    my @recs2;
    for my $r( @recs ) {
        my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
            $qstart, $qend, $sstart, $send, $evalue, $bitScore ) 
            = split( /\t/, $r );
        next if $percIdent < 30;

        my( $qgene_oid, $qtaxon, $qlen, $qsymbol ) = split( /_/, $qid ); 
        my ( $sgene_oid, $staxon, $slen, $ssymbol );
        if ( $rnaHomologs eq 'topMetaRnas' ) {
           my ($a_type, $sg_oid);
           ( $staxon, $a_type, $sg_oid ) = split( /[.:]/, $sid );
           $sgene_oid = "$staxon assembled $sg_oid";
        }
        else {
           ( $sgene_oid, $staxon, $slen, $ssymbol ) = split( /_/, $sid );            
        }
        $count++; 
 
        my $infoStr = $homologRecs{ $sgene_oid }; 
        my @a = split( /\t/, $infoStr ); 
        my( $gene_oid1, $locus_type, $dna_seq_length, 
            $taxon_oid, $domain, $seq_status, $taxon_display_name, 
            $scf_scaffold_oid, $scf_ext_accession, 
            $scf_scaffold_name, $scf_seq_length, 
            $scf_gc_percent, $scf_read_depth ) = @a; 
        next if !$gene_oid1; 
 
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $evalue2        = sprintf( "%.1e", $evalue );
        my $query_start    = $qstart;
        my $query_end      = $qend;
 
        # Handle reverse DNA coordinates
        if ( $qstart > $qend ) { 
            $query_start = $qend; 
            $query_end   = $qstart;
        } 
        my $rec = "$sgene_oid\t"; 
        $rec .= "$locus_type\t"; 
        $rec .= "$percIdent\t";
        $rec .= "$evalue2\t"; 
        $rec .= "$bitScore\t"; 
        $rec .= "$query_start\t";
        $rec .= "$query_end\t"; 
        $rec .= "$alen\t";
        $rec .= "$dna_seq_length\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$domain\t"; 
        $rec .= "$seq_status\t"; 
        $rec .= "$taxon_display_name\t";
        $rec .= "$scf_scaffold_oid\t"; 
        $rec .= "$scf_ext_accession\t"; 
        $rec .= "$scf_scaffold_name\t";
        $rec .= "$scf_seq_length\t";
        $rec .= "$scf_gc_percent\t"; 
        $rec .= "$scf_read_depth\t"; 
        push( @recs2, $rec ); 
    } 
    #WebUtil::resetEnvPath( );
 
    printEndWorkingDiv( ); 
 
    if ( $count == 0 ) {
        print "<p>\n"; 
        print "No RNA homologs found.<br/>\n"; 
        print "</p>\n"; 
        printStatusLine( "Loaded.", 2 );
        return;
    } 
 
    my $clobberCache = param("clobberCache");
    my $it = new InnerTable( $clobberCache, "rnaHomologs$$", "homologs", 7 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Homolog",              "number asc",  "left" );
    $it->addColSpec( "Product Name",         "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec( "Alignment<br/>On<br/>Query<br/>Gene" );
    $it->addColSpec( "Length",        "number desc", "right" );
    $it->addColSpec( "E-value",       "number asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    $it->addColSpec( "Domain",        "char asc",    "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",        "char asc",    "center", "",
                     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name",   "char asc",    "left" );
    if ($include_metagenomes) { 
        $it->addColSpec( "Scaffold ID",               "char asc",    "left" );
        $it->addColSpec( "Contig<br/>Length",         "number desc", "right" );
        $it->addColSpec( "Contig<br/>GC",             "number desc", "right" );
        $it->addColSpec( "Contig<br/>Read<br/>Depth", "number desc", "right" );
    } 
    my $sd                  = $it->getSdDelim();
    my $count               = 0;
    my $taxonFilterHash_ref = getTaxonFilterHash();
    my $nFilterTaxons       = scalar( keys(%$taxonFilterHash_ref) ); 
    my %taxonsHit; 
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);
 
    for my $r (@recs2) {
        #print "printMetaRnaHomologsBlast() recs2 r=$r<br/>\n";
        my ( 
             $homolog,            $locus_type,     $percent_identity,
             $evalue,             $bit_score,      $query_start,
             $query_end,          $align_length,   $dna_seq_length,
             $taxon_oid,          $domain,         $seq_status,
             $taxon_display_name, $scaffold_oid,   $scf_ext_accession,
             $scaffold_name,      $scf_seq_length, $scf_gc_percent,
             $scf_read_depth
          ) 
        = split( /\t/, $r ); 
        next if $percent_identity < 30; 
        $count++; 

        my $data_type;
        my $gene_oid;
        if ( $homolog && WebUtil::isInt($homolog) ) {
            $data_type = 'database';
            $gene_oid  = $homolog;
        } else {
            my @vals = split( / /, $homolog );
            $data_type = $vals[1];
            $gene_oid  = $vals[2];
        }

        my $gene_url;
        if ( $data_type eq 'database' ) {
            $gene_url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        } else {
            $gene_url =
                "$section_cgi"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        }

        my $taxon_url = 
            "$main_cgi?section=TaxonDetail" 
        . "&page=taxonDetail&taxon_oid=$taxon_oid"; 
        my $evalue2 = sprintf( "%.1e", $evalue ); 
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent ); 
        $scf_read_depth = sprintf( "%.2f", $scf_read_depth ); 
        $scf_read_depth = "-" if $scf_read_depth == 0; 
 
        my $r; 
        my $ck; 
        $ck = "checked" if $selectedGeneOids{$homolog} ne "";
        $r .= $sd 
          . "<input type='checkbox' name='gene_oid' "
          . "value='$homolog' $ck />\t";           
        $r .= $homolog . $sd . alink( $gene_url, $gene_oid ) . "\t"; 
        $r .= "$locus_type\t";
        my $percent_identity2 = sprintf( "%.2f", $percent_identity );
        $r .= $percent_identity2 . $sd . "$percent_identity2%\t";
        $r .= $sd
          . alignImage( $query_start, $query_end, $query_dna_seq_length )
          . "\t"; 
        $r .= $dna_seq_length . $sd . "${dna_seq_length}bp\t"; 
        $r .= "$evalue2\t"; 
        my $bit_score2 = sprintf( "%d", $bit_score ); 
        $r .= "$bit_score2\t"; 
        $r .= "$domain\t"; 
        $r .= "$seq_status\t";
        $r .= 
          $taxon_display_name . $sd 
          . alink( $taxon_url, $taxon_display_name ) . "\t";
 
        if ($include_metagenomes) {
            my $scaffold_url;
            if ($data_type eq 'database' && WebUtil::isInt($scaffold_oid)) {
                $scaffold_url = 
                    "$main_cgi?section=ScaffoldGraph"
                  . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
            } else {
                $scaffold_url =
                    "$main_cgi?section=MetaDetail"
                  . "&page=metaScaffoldDetail&scaffold_oid=$scaffold_oid"
                  . "&taxon_oid=$taxon_oid&data_type=$data_type";
            }
            $scaffold_url = alink($scaffold_url, $scaffold_oid);
            $r .= $scaffold_oid . $sd . $scaffold_url . "\t";

            $r .= "$scf_seq_length\t"; 
            $r .= "$scf_gc_percent\t"; 
            $r .= "$scf_read_depth\t"; 
        } 
        $it->addRow($r); 
        $taxonsHit{$taxon_oid} = $taxon_oid; 
    } 
    print "<p>\n"; 
    print domainLetterNote() . "<br/>\n"; 
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
 
    printMainForm();
    printAddQueryGeneCheckBox($gene_oid0, $taxon_oid, $data_type); 
 
    printHomologFooter(); 
    $it->printOuterTable(1); 
    printHomologFooter() if $count > 0; 
 
    print end_form(); 
} 

############################################################################
# getGeneTaxonAttributes - Get attributes from gene and taxon table
#   for homolog file BLAST hits.
#   Inputs:
#     dbh - database handle
#     r_ref - records reference.
# If r_ref points to an array of both isolate genes and metagenes, 
# separate genes from metagenes, 
# use getMetaGeneTaxonAttributes() for metagenes,
# use getGeneTaxonAttributes for isolate genes.
############################################################################
sub getGeneTaxonAttributes {
    my ( $dbh, $r_ref ) = @_;
    my %geneRec;
    my @gene_oids;
    my $count = 0;
    for my $r (@$r_ref) {
        $count++;

        # Cannot abort here; need to match blast results.
        if ( scalar(@gene_oids) > $max_gene_batch ) {
            getGeneTaxonBatch( $dbh, \@gene_oids, \%geneRec );
            @gene_oids = ();
        }
        my ( $gene_oid, @junk ) = split( /\t/, $r );
        push( @gene_oids, $gene_oid ) if $gene_oid ne "";
    }
    getGeneTaxonBatch( $dbh, \@gene_oids, \%geneRec );
    my @recs;
    for my $r (@$r_ref) {
        my ( $sid, $percIdent, $evalue, $bitScore, $query_start, $query_end, $subj_start, $subj_end, $alen, $opType ) =
          split( /\t/, $r );
        my (
             $homolog_oid,    $gene_display_name, $aa_seq_length,      $taxon_oid,
             $domain,         $seq_status,        $taxon_display_name, $scf_ext_accession,
             $scf_seq_length, $scf_gc_percent,    $scf_read_depth
          )
          = split( /\t/, $geneRec{$sid} );
        next if $homolog_oid eq "";
        if ( $homolog_oid ne $sid ) {
            webDie("getGeneTaxonAttributes: '$homolog_oid' != '$sid'\n");
        }
        my $r2 = "$sid\t";
        $r2 .= "$gene_display_name\t";
        $r2 .= "$percIdent\t";
        $r2 .= "$evalue\t";
        $r2 .= "$bitScore\t";
        $r2 .= "$query_start\t";
        $r2 .= "$query_end\t";
        $r2 .= "$subj_start\t";
        $r2 .= "$subj_end\t";
        $r2 .= "$alen\t";
        $r2 .= "$opType\t";
        $r2 .= "$aa_seq_length\t";
        $r2 .= "$taxon_oid\t";
        $r2 .= "$domain\t";
        $r2 .= "$seq_status\t";
        $r2 .= "$taxon_display_name\t";
        $r2 .= "$scf_ext_accession\t";
        $r2 .= "$scf_seq_length\t";
        $r2 .= "$scf_gc_percent\t";
        $r2 .= "$scf_read_depth\t";
        push( @recs, $r2 );
    }
    return @recs;
}

############################################################################
# getMetaGeneTaxonAttributes - Get attributes from gene and taxon table
#   for homolog file BLAST hits.
#   Inputs:
#     dbh - database handle
#     r_ref - records reference.
# (for MER-FS)
# If r_ref points to an array of both genes and metagenes, there are two options:
# first option is to use MetaGeneDetail::getGeneTaxonAttributes, 
# which handles both types. The 2nd option is to separate genes from metagenes, 
# and use MetaGeneDetail::getMetaGeneTaxonAttributes() for metagenes,
# and use GeneDetail::getGeneTaxonAttributes for isolate genes.
############################################################################
sub getMetaGeneTaxonAttributes {
    my ( $dbh, $taxon_oid, $data_type, $r_ref ) = @_;

    print "<p>Retrieving homolog gene information ...<br/>\n";
    my $sql = qq{
          select domain, seq_status, taxon_display_name 
          from taxon where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $domain, $seq_status, $taxon_display_name ) = $cur->fetchrow();
    $cur->finish();

    my @recs;
    my $count = 0;
    for my $r (@$r_ref) {
        my ( $gene_oid, $percIdent, $evalue, $bitScore, $query_start, $query_end, 
             $subj_start, $subj_end, $alen, $opType ) = split( /\t/, $r );
        $count++;
        print ".";
        print "<br/>\n" if ( ( $count % 120 ) == 0 );

        my $r2 = "$gene_oid\t";
        if ( $gene_oid =~ /\./ and $gene_oid =~ /:/ ) {
            (undef, $gene_oid) = split( /:/, $gene_oid, 2 );
        }

        my ( $gene_oid2, $locus_type, $locus_tag, $gene_orig_name,
         $start_coord, $end_coord, $strand, $scaffold_oid ) =
            MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
        my ( $gene_display_name, $name_src ) = 
        MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
        my ( $scf_seq_length, $scf_gc_percent, $scaf_gene_cnt ) =
        MetaUtil::getScaffoldStats( $taxon_oid, $data_type, $scaffold_oid );
        my $scf_read_depth = MetaUtil::getScaffoldDepth( $taxon_oid, $data_type, 
                                                         $scaffold_oid );
        my $scf_ext_accession = $scaffold_oid;
        my $aa_seq = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
        my $aa_seq_length = length($aa_seq);

        require TaxonDetail;
        $domain = TaxonDetail::getShortDomain( $domain );
        $seq_status = TaxonDetail::getShortDomain( $seq_status );

        $r2 .= "$gene_display_name\t";
        $r2 .= "$percIdent\t";
        $r2 .= "$evalue\t";
        $r2 .= "$bitScore\t";
        $r2 .= "$query_start\t";
        $r2 .= "$query_end\t";
        $r2 .= "$subj_start\t";
        $r2 .= "$subj_end\t";
        $r2 .= "$alen\t";
        $r2 .= "$opType\t";
        $r2 .= "$aa_seq_length\t";
        $r2 .= "$taxon_oid\t";
        $r2 .= "$domain\t";
        $r2 .= "$seq_status\t";
        $r2 .= "$taxon_display_name\t";
        $r2 .= "$scf_ext_accession\t";
        $r2 .= "$scf_seq_length\t";
        $r2 .= "$scf_gc_percent\t";
        $r2 .= "$scf_read_depth\t";
        push( @recs, $r2 );
    }
    return @recs;
}
############################################################################
# getGeneTaxonBatch - Get gene tand taxon information from database.
#   Inputs:
#     dbh - database handle.
#     gene_oids_ref - gene object identifers reference to array.
#     geneRec_ref - gene records reference to gene lookup information.
############################################################################
sub getGeneTaxonBatch {
    my ( $dbh, $gene_oids_ref, $geneRec_ref ) = @_;
    my $gene_oid_str = join( ',', @$gene_oids_ref );
    return if ( blankStr($gene_oid_str) );
    my %scaffold2Bin;
    my $rclause = urClause("g.taxon");
    my $sql     = qq{
        select distinct bs.scaffold, b.bin_oid, b.display_name
        from gene g, bin_scaffolds bs, bin b
        where g.scaffold = bs.scaffold
        and bs.bin_oid = b.bin_oid
        and g.gene_oid in( $gene_oid_str )
        and b.is_default = 'Yes'
        $rclause
        order by bs.scaffold, b.display_name
   };
    if ($include_metagenomes) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
            last if !$scaffold_oid;
            $scaffold2Bin{$scaffold_oid} .= " $bin_display_name;";
        }
        $cur->finish();
    }
    my $rclause = urClause("g.taxon");
    my $sql     = qq{
       select g.gene_oid, g.gene_display_name, g.aa_seq_length, 
          tx.taxon_oid, 
          tx.domain, 
          tx.seq_status, 
          tx.taxon_display_name,
          scf.scaffold_oid, scf.ext_accession, ss.seq_length, ss.gc_percent,
          scf.read_depth
       from taxon tx, scaffold scf, gene g, scaffold_stats ss
       where g.taxon = tx.taxon_oid
       and g.gene_oid in( $gene_oid_str ) 
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       $rclause
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
             $gene_oid,          $gene_display_name, $aa_seq_length,      $taxon_oid,
             $domain,            $seq_status,        $taxon_display_name, $scaffold_oid,
             $scf_ext_accession, $scf_seq_length,    $scf_gc_percent,     $scf_read_depth
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $bin_display_names = $scaffold2Bin{$scaffold_oid};
        chop $bin_display_names;
        $scf_ext_accession .= " (bin(s):$bin_display_names)"
          if $bin_display_names ne "";

        my $r = "$gene_oid\t";
        $r .= "$gene_display_name\t";
        $r .= "$aa_seq_length\t";
        $r .= "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_display_name\t";
        $r .= "$scf_ext_accession\t";
        $r .= "$scf_seq_length\t";
        $r .= "$scf_gc_percent\t";
        $r .= "$scf_read_depth\t";
        $geneRec_ref->{$gene_oid} = $r;
    }
    $cur->finish();
}

############################################################################
# printTruncatedHomologStatus - Print status line with truncated note.
#   This is the "Max. Gene List Results" version.
############################################################################
sub printTruncatedHomologStatus {
    my ($maxResults) = @_;
    print "<br/>\n";
    my $s = "Results limited to $maxResults homologs.\n";
    $s .= "( Go to ";
    $s .= alink( $preferences_url, "Preferences" );
    $s .= " to change \"Max. Homolog Results\" limit. )\n";
    printStatusLine( $s, 2 );
}

############################################################################
# printHomologFooter - Print homolog footer with standard button
#   to add to gene cart, select all, clear all, phylo distribution, etc.
############################################################################
sub printHomologFooter {
    my ($buttonId) = @_;

    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit(
                  -name  => $name,
                  -value => "Add Selections To Gene Cart",
                  -class => "meddefbutton"
    );
    print nbsp(1);

    # Added id for buttons. Required for HTML pages with multiple tables
    # Format of id field: id ='<table_id><0|1>' (1-Select All, 0-Clear All)
    # +BSJ 02/02/10

    my $selAll = "";
    my $clrAll = "";

    if ( defined $buttonId ) {
        $selAll = "${buttonId}1";
        $clrAll = "${buttonId}0";
    }

    print "<input id='$selAll' type='button' "
      . "name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input id='$clrAll' type='button' "
      . "name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
}

############################################################################
# printParalogs - Show paralogs in gene object detail table.
#   Inputs:
#      dbh - database handle.
#      gene_oid - gene object identifier.
#      is_metagenome - handle adaptation to metagenome terminology.
############################################################################
sub printParalogs {
    my ( $dbh, $gene_oid, $is_metagenome ) = @_;

    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );
    my $rclause             = WebUtil::urClause('g2.taxon');
    my $imgClause           = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql                 = qq{
       select distinct bs.scaffold, b.bin_oid, b.display_name
       from gene_paralogs gp, gene g2, bin_scaffolds bs, bin b
       where gp.gene_oid = ?
           and gp.paralog = g2.gene_oid
           and g2.scaffold = bs.scaffold
           and bs.bin_oid = b.bin_oid
           and b.is_default = 'Yes'
           $rclause
           $imgClause
       order by bs.scaffold, b.display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %scaffold2Bin;
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} .= " $bin_display_name;";
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select gp.paralog, g.gene_display_name, gp.percent_identity,
           gp.evalue, gp.bit_score, gp.query_start, gp.query_end,
           gp.subj_start, gp.subj_end, g.aa_seq_length, 
           scf.scaffold_oid, scf.ext_accession, scf.scaffold_name,
           ss.seq_length, ss.gc_percent, scf.read_depth
       from gene g, scaffold scf, gene_paralogs gp, scaffold_stats ss
       where gp.gene_oid = ?
           and gp.paralog = g.gene_oid
           and g.scaffold = scf.scaffold_oid
           and scf.scaffold_oid = ss.scaffold_oid
           $rclause
           $imgClause
       order by gp.evalue, gp.percent_identity desc
    };
    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $count = 0;
    my @recs;

    for ( ; ; ) {
        my (
             $paralog,       $gene_display_name, $percent_identity, $evalue,
             $bit_score,     $query_start,       $query_end,        $subj_start,
             $subj_end,      $aa_seq_length,     $scaffold_oid,     $scf_ext_accession,
             $scaffold_name, $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = $cur->fetchrow();
        last if !$paralog;

        my $evalue2 = sprintf( "%.1e", $evalue );
        $count++;

        my $rec = "$paralog\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$percent_identity\t";
        $rec .= "$evalue2\t";
        $rec .= "$bit_score\t";
        $rec .= "$query_start\t";
        $rec .= "$query_end\t";
        $rec .= "$subj_start\t";
        $rec .= "$subj_end\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$scaffold_oid\t";
        $rec .= "$scf_ext_accession\t";
        $rec .= "$scaffold_name\t";
        $rec .= "$scf_seq_length\t";
        $rec .= "$scf_gc_percent\t";
        $rec .= "$scf_read_depth\t";
        push( @recs, $rec );
    }
    $cur->finish();
    return if ( $count == 0 );

    if ($is_metagenome) {
        print "<h2>Reciprocal hits within the metagenome.</h2>\n";
    } else {
        print "<h2>Paralogs</h2>\n";
        print "<p>\n";
        print "Paralogs are reciprocal hits within the same genome.\n";
        print "</p>\n";
    }

    my $homologs = param("homologs");
    my $baseUrl  = "$section_cgi&page=homolog";
    $baseUrl .= "&gene_oid=$gene_oid";
    $baseUrl .= "&homologs=$homologs";
    my $clobberCache = param("clobberCache");

    my $it = new InnerTable( $clobberCache, "paralogs$$", "paralogs", 7, $baseUrl );
    $it->addColSpec("Select");
    if ($is_metagenome) {
        $it->addColSpec( "Internal Homolog", "char asc", "left" );
    } else {
        $it->addColSpec( "Paralog", "char asc", "left" );
    }
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",    "desc", "right" );
    $it->addColSpec( "E-value",   "asc",  "left" );
    $it->addColSpec( "Bit Score", "desc", "right" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",               "asc",  "left" );
        $it->addColSpec( "Contig<br/>Length",         "desc", "right" );
        $it->addColSpec( "Contig<br/>GC",             "desc", "right" );
        $it->addColSpec( "Contig<br/>Read<br/>Depth", "desc", "right" );
    }
    my $sd                 = $it->getSdDelim();
    my $count              = 0;
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    for my $r (@recs) {
        $count++;
        my (
             $paralog,       $gene_display_name,  $percent_identity, $evalue,
             $bit_score,     $query_start,        $query_end,        $subj_start,
             $subj_end,      $subj_aa_seq_length, $scaffold_oid,     $scf_ext_accession,
             $scaffold_name, $scf_seq_length,     $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );

        $percent_identity = sprintf( "%.2f", $percent_identity );
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        $scf_read_depth = sprintf( "%.2f", $scf_read_depth );
        $scf_read_depth = "-" if $scf_read_depth == 0;
        my $row_color = $count % 2 == 0 ? "#ffffff" : "#f0f0f0";
        my $gene_url  = "$section_cgi&page=geneDetail&gene_oid=$paralog";
        my $trClass   = "";

        my $r;
        my $ck;
        $ck = "checked" if $selectedGeneOids{$paralog} ne "";
        $r .= "$sd<input type='checkbox' name='gene_oid' " . "value='$paralog' $ck />\t";
        $r .= $paralog . $sd . alink( $gene_url, $paralog ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start, $subj_end, $subj_aa_seq_length ) . "\t";
        $r .= $subj_aa_seq_length . $sd . "${subj_aa_seq_length}aa\t";
        $r .= "$evalue\t";
        my $bit_score2 = sprintf( "%d", $bit_score );
        $r .= "$bit_score2\t";

        if ($include_metagenomes) {
            my $bin_display_names = $scaffold2Bin{$scaffold_oid};
            chop $bin_display_names;
            $scf_ext_accession .= " (bin(s):$bin_display_names)"
              if $bin_display_names ne "";
            $r .= "$scf_ext_accession\t";
            $r .= "$scf_seq_length\t";
            $r .= "$scf_gc_percent\t";
            $r .= "$scf_read_depth\t";
        }
        $it->addRow($r);
    }
    printHomologFooter();
    $it->printTable(1);
    printHomologFooter() if $count > 0;
}

############################################################################
# loadOrthologs - Load orthologs hits for InnerTable.
############################################################################
sub loadOrthologs {
    my ( $it, $dbh, $gene_oid ) = @_;

    my $gene_display_name   = geneOid2Name( $dbh,        $gene_oid );
    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    my %regionScores;

    #loadRegionScore( $dbh, $gene_oid, \%regionScores );

    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    my $rclause = urClause("go.taxon");
    my $sql     = qq{
       select count(*)
       from gene_orthologs go
       where go.gene_oid = ?
       $rclause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select go.ortholog, g.gene_display_name, go.percent_identity,
           go.evalue, go.bit_score, go.query_start, go.query_end, 
           go.subj_start, go.subj_end, go.align_length, g.aa_seq_length,
           tx.taxon_oid, tx.domain, tx.seq_status, tx.taxon_display_name
       from taxon tx, gene g, gene_orthologs go
       where go.gene_oid = ?
           and go.ortholog = g.gene_oid
           and go.taxon = tx.taxon_oid
           $rclause
           $imgClause
       order by go.bit_score desc
    };
    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    $it->addColSpec("Select");
    $it->addColSpec( "Ortholog",             "number asc",  "left" );
    $it->addColSpec( "Product Name",         "char asc",    "left" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",    "number desc", "right" );
    $it->addColSpec( "E-value",   "number asc",  "left" );
    $it->addColSpec( "Bit Score", "number desc", "right" );

    #$it->addColSpec(
    #  "Cons. Region Score<sup>1</sup>", "number desc", "right" )
    #     if $mysql_config eq "";
    $it->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd    = $it->getSdDelim();
    my $count = 0;
    for ( ; ; ) {
        my (
             $ortholog,           $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $subj_aa_seq_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$ortholog;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        $count++;
        my $cons_region_score = $regionScores{$ortholog};
        $cons_region_score = 0 if $cons_region_score eq "";
        $percent_identity = sprintf( "%.2f", $percent_identity );

        my $ck;
        $ck = "checked" if $selectedGeneOids{$ortholog} ne "";
        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$ortholog' $ck />\t";
        my $url = "$section_cgi&page=geneDetail&gene_oid=$ortholog";
        $r .= $ortholog . $sd . alink( $url, $ortholog ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "$subj_aa_seq_length${sd}${subj_aa_seq_length}aa\t";
        my $evalue_f = sprintf( "%.1e", $evalue );
        $r .= "$evalue_f\t";
        my $bit_score2 = sprintf( "%d", $bit_score );
        $r .= "$bit_score2\t";

        #$r .= "$cons_region_score\t" if $mysql_config eq "";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $it->addRow($r);
    }
    $cur->finish();
}

############################################################################
# printOrthologs - Print ortholog hits.
############################################################################
sub printOrthologs {
    my ( $dbh, $gene_oid ) = @_;

    print hiddenVar( "xlogSource", "orthologs" );

    print "<h2>Orthologs</h2>\n";
    print "<p>\n";
    print "Orthologs are bidirectional best hits from BLASTP comparisons.";
    print "</p>\n";

    my $baseUrl = "$section_cgi&page=homolog";
    $baseUrl .= "&gene_oid=$gene_oid";
    $baseUrl .= "&homologs=orthologs";
    my $clobberCache = 1;    #param( "clobberCache" );

    my $it =
      new InnerTable( $clobberCache, "orthologs_gid$gene_oid", "ortholog", 7, $baseUrl, \&loadOrthologs, $dbh, $gene_oid );

    my $rows  = $it->{rows};
    my $count = @$rows;

    if ( $count == 0 ) {
        print "<p>\n";
        print "No hits found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    printHomologFooter("ortholog");
    $it->printTable(0);
    printHomologFooter("ortholog") if $count > 0;
}

############################################################################
# printOrthologSummary - Print summary of orthologs.
############################################################################
sub printOrthologSummary {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
       select distinct bbhg.cluster_id
       from bbh_cluster_member_genes bbhg
       where bbhg.member_genes = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %query_cluster_id;
    for ( ; ; ) {
        my $cluster_id = $cur->fetchrow();
        last if !$cluster_id;
        $query_cluster_id{$cluster_id} = $cluster_id;
    }
    $cur->finish();

    my $sql = qq{
       select bbhc.cluster_id, bbhc.cluster_name, 
          count( distinct go.ortholog ), 
          count( distinct bbhg2.member_genes )
       from gene g, gene_orthologs go, 
         bbh_cluster_member_genes bbhg, bbh_cluster bbhc,
         bbh_cluster_member_genes bbhg2
       where g.gene_oid = go.gene_oid
       and g.gene_oid = ?
       and go.ortholog = bbhg.member_genes
       and bbhg.cluster_id = bbhc.cluster_id
       and bbhc.cluster_id = bbhg2.cluster_id
       group by bbhc.cluster_id, bbhc.cluster_name
       order by bbhc.cluster_id, bbhc.cluster_name
   };
    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %clusterId2Rank;
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $ortho_count, $cluster_size ) = $cur->fetchrow();
        last if !$cluster_id;
        my $r = sprintf( "%09d\t", $ortho_count );
        $r .= "$cluster_id\t";
        $r .= "$cluster_name\t";
        $r .= "$cluster_size\t";
        push( @recs, $r );
        $clusterId2Rank{$cluster_id} = "";
    }
    my $clusterCount = @recs;
    return 0 if $clusterCount == 0;

    my @rrecs = reverse( sort(@recs) );
    print "<h2>Ortholog Clusters</h2>\n";
    print "<p>\n";
    print "Ortholog clusters are clustered ";
    print "bidirectional best hits.\n";
    print "</p>\n";

    my $baseUrl = "$section_cgi&page=geneDetail";
    $baseUrl .= "&gene_oid=$gene_oid";
    my $clobberCache = param("clobberCache");
    my $ct = new InnerTable( $clobberCache, "cluster$$", "cluster", 3 );
    $ct->addColSpec( "Cluster<br/>ID<sup>1</sup>", "number asc",  "left" );
    $ct->addColSpec( "Cluster<br/>Size",           "number desc", "right" );
    $ct->addColSpec( "Cluster Name<sup>2</sup>",   "char asc",    "left" );
    $ct->addColSpec( "Ortholog<br/>Count",         "number desc", "right" );

    #$ct->addColSpec( "Highest<br/>Rank", "char asc", "left" );
    my $sd = $ct->getSdDelim();
    for my $r (@rrecs) {
        my ( $ortho_count_str, $cluster_id, $cluster_name, $cluster_size ) =
          split( /\t/, $r );
        my $ortho_count = sprintf( "%d", $ortho_count_str );
        my $url = "$section_cgi&page=genePageOrthologCluster";
        $url .= "&cluster_id=$cluster_id";
        $url .= "&gene_oid=$gene_oid";
        my $link = alink( $url, $cluster_id );
        $link = "<b>" . alink( $url, $cluster_id ) . "</b>"
          if $query_cluster_id{$cluster_id} ne "";
        my $r = $cluster_id . $sd . "$link\t";
        $r .= "$cluster_size\t";
        $r .= "$cluster_name\t";
        my $url = "$section_cgi&page=genePageOrthologHits";
        $url .= "&cluster_id=$cluster_id";
        $url .= "&gene_oid=$gene_oid";
        $r   .= $ortho_count . $sd . alink( $url, $ortho_count ) . "\t";

        #my $rank = $clusterId2Rank{ $cluster_id };
        #my( $order, $rank_name, $display_name ) = split( /\t/, $rank );
        #my $rank_str = "<i>$rank_name</i>: $display_name";
        #$r .= "$rank_name $display_name" . $sd . "$rank_str\t";
        $ct->addRow($r);
    }

    $ct->printOuterTable();
    $cur->finish();
    print hiddenVar( "xlogSource", "orthologs" );
    print "<p>\n";
    print "1 - Cluster with query gene is shown in bold.<br/>\n";
    print "2 - Cluster name is most frequently occurring gene name.<br/>\n";
    print "</p>\n";
    return $clusterCount;
}

############################################################################
# printGenePageOrthologCluster - Show genes under one cluster.
############################################################################
sub printGenePageOrthologCluster {
    my $cluster_id     = param("cluster_id");
    my $query_gene_oid = param("gene_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause = urClause("go.taxon");
    my $sql     = qq{
       select go.ortholog
       from gene_orthologs go
       where go.gene_oid = ?
           $rclause
   };
    my %orthologGenes;
    my $cur = execSql( $dbh, $sql, $verbose, $query_gene_oid );
    for ( ; ; ) {
        my ($ortholog) = $cur->fetchrow();
        last if !$ortholog;
        $orthologGenes{$ortholog} = $ortholog;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select distinct g.gene_oid
       from bbh_cluster_member_genes bbhg, gene g
       where bbhg.cluster_id = ?
           and bbhg.member_genes = g.gene_oid
           $rclause
           $imgClause
       order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    my $count = 0;
    my @gene_oids;
    printMainForm();
    print "<h1>\n";
    print "Ortholog Cluster Genes\n";
    print "</h1>\n";
    print "<p>\n";
    my $gene_display_name = geneOid2Name( $dbh, $query_gene_oid );
    print "Bidirectional best hit orthologs to gene $query_gene_oid ";
    print "<i>" . escHtml($gene_display_name) . "</i> are shown in blue.<br/>\n";
    print "If present, query gene $query_gene_oid " . "is shown in dark green.<br/>\n";
    print "</p>\n";
    printGeneCartFooter();
    print "<p>\n";
    my $count = 0;

    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( scalar(@gene_oids) > $max_gene_batch ) {
            flushOrthologGeneBatch( $dbh, $query_gene_oid, \@gene_oids, \%orthologGenes );
            @gene_oids = ();
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    flushOrthologGeneBatch( $dbh, $query_gene_oid, \@gene_oids, \%orthologGenes );
    print "<br/>\n";
    print "</p>\n";
    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );

    #printGeneCartFooter( );
    if ( $user_restricted_site && !$no_restricted_message ) {
        print "<p>\n";
        print "<font color='red'>\n";
        print "Orthologs cluster genes listed here are restricted by\n";
        print "genomes access.<br/>\n";
        print "</font>\n";
        print "</p>\n";
    }
    print end_form();
}

############################################################################
# flushOrthologGeneBatch - Flush (print) a batch of gene_oid's.
############################################################################
sub flushOrthologGeneBatch {
    my ( $dbh, $query_gene_oid, $gene_oids_ref, $orthologGenes_ref ) = @_;

    my @gene_oids    = param("gene_oid");
    my %geneOids     = WebUtil::array2Hash(@gene_oids);
    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);

    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type, 
         tx.taxon_oid, tx.ncbi_taxon_id, 
         tx.taxon_display_name, tx.genus, tx.species,
         g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       order by tx.taxon_display_name, g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,      $gene_display_name,  $gene_symbol,       $locus_type, $taxon_oid,
             $ncbi_taxon_id, $taxon_display_name, $genus,             $species, 
             $aa_seq_length, $seq_status,         $scf_ext_accession, $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$scf_ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    my %done;
    for my $r (@recs) {
        my (
             $gene_oid,      $gene_display_name,  $gene_symbol,       $locus_type, $taxon_oid,
             $ncbi_taxon_id, $taxon_display_name, $genus,             $species, 
             $aa_seq_length, $seq_status,         $scf_ext_accession, $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";

        my $ck = "checked" if $geneOids{$gene_oid} ne "";
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\n";
        my $url = "$section_cgi&page=geneDetail&gene_oid=$gene_oid";

        if ( $gene_oid eq $query_gene_oid ) {
            print "<font color='green'><b>\n";
        } elsif ( $orthologGenes_ref->{$gene_oid} ne "" ) {
            print "<font color='blue'>\n";
        }

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "";
        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2              = escHtml($genus);
        my $species2            = escHtml($species);
        my $taxon_display_name2 = escHtml($taxon_display_name);
        my $orthStr;
        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($scf_ext_accession: ${seq_length}bp)";
        }
        print alink( $url, $gene_oid ) . " "
          . escHtml($gene_display_name)
          . " ${seqLen} [$taxon_display_name2]$scfInfo";
        if ( $gene_oid eq $query_gene_oid ) {
            print "</b></font>\n";
        } elsif ( $orthologGenes_ref->{$gene_oid} ne "" ) {
            print "</font>\n";
        }
        print "<br/>\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();
}

############################################################################
# printGenePageOrthologHits - Print ortholog hits
############################################################################
sub printGenePageOrthologHits {
    my $cluster_id = param("cluster_id");
    my $gene_oid   = param("gene_oid");

    my $dbh                 = dbLogin();
    my $gene_display_name   = geneOid2Name( $dbh, $gene_oid );
    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    printMainForm();
    print "<h1>Orthologs in Cluster</h1>\n";
    print "<p>\n";
    print "Orthologs to gene $gene_oid ";
    print "<i>" . escHtml($gene_display_name) . "</i>.<br/>\n";
    print "(Orthologs are bidirectional best hits from BLASTP comparisons.)";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my %regionScores;

    #loadRegionScore( $dbh, $gene_oid, \%regionScores );

    my $rclause   = WebUtil::urClause('g2.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql       = qq{
       select go.ortholog, g2.gene_display_name, go.percent_identity,
           go.evalue, go.bit_score,
           go.query_start, go.query_end, 
           go.subj_start, go.subj_end,
           go.align_length, g2.aa_seq_length,
           tx2.taxon_oid, 
           tx2.domain,
           tx2.seq_status,
           tx2.taxon_display_name
       from taxon tx2, bbh_cluster_member_genes bbhg, 
           gene g2, gene_orthologs go
       where go.gene_oid = ?
           and go.taxon = tx2.taxon_oid
           and go.ortholog = g2.gene_oid
           and go.ortholog = bbhg.member_genes
           and bbhg.cluster_id = ?
           $rclause
           $imgClause
       order by go.bit_score desc
    };
    my @binds = ( $gene_oid, $cluster_id );
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $baseUrl = "$section_cgi&page=genePageOrthologHits";
    $baseUrl .= "&cluster_id=$cluster_id";
    $baseUrl .= "&gene_oid=$gene_oid";
    my $clobberCache = param("clobberCache");
    my $ct           = new InnerTable( $clobberCache, "orthologHits$$", "ortholog", 7, $baseUrl );

    #my $ct = new CachedTable( "orthologHits$gene_oid", $baseUrl );
    $ct->addColSpec("Select");
    $ct->addColSpec( "Ortholog",             "number asc",  "left" );
    $ct->addColSpec( "Product Name",         "char asc",    "left" );
    $ct->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $ct->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $ct->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $ct->addColSpec( "Length",    "number desc", "right" );
    $ct->addColSpec( "E-value",   "number asc",  "left" );
    $ct->addColSpec( "Bit Score", "number desc", "right" );

    #$ct->addColSpec(
    #   "Cons. Region Score<sup>1</sup>", "number desc", "right" )
    #      if $mysql_config eq "";
    $ct->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $ct->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome Name", "char asc", "left" );
    my $sd    = $ct->getSdDelim();
    my $count = 0;
    for ( ; ; ) {
        my (
             $ortholog,           $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$ortholog;

        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        $count++;
        my $cons_region_score = $regionScores{$ortholog};
        $cons_region_score = 0 if $cons_region_score eq "";
        $percent_identity = sprintf( "%.2f", $percent_identity );

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$ortholog' />\t";
        my $url = "$section_cgi&page=geneDetail&gene_oid=$ortholog";
        $r .= $ortholog . $sd . alink( $url, $ortholog ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "$subj_aa_seq_length${sd}${subj_aa_seq_length}aa\t";
        my $evalue_f = sprintf( "%.1e", $evalue );
        $r .= "$evalue_f\t";
        my $bit_score2 = sprintf( "%d", $bit_score );
        $r .= "$bit_score2\t";

        #$r .= "$cons_region_score\t" if $mysql_config eq "";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $ct->addRow($r);
    }
    printGeneCartFooter();
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    $ct->printTable(1);
    printGeneCartFooter() if $count > 10;

    #print "<p>\n";
    #my $url = "$section_cgi&page=consRegionScoreNote";
    #print "1 - ". alink( $url, "Conserved Region Score Note" ) . "<br/>\n"
    #   if $mysql_config eq "";
    #print "</p>\n";

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$count ortholog(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# loadRegionScores - Load conserved regions scores
############################################################################
sub loadRegionScore {
    my ( $dbh, $gene_oid, $ortholog2Scores_ref ) = @_;

    ##
    # MySQL is too slow to support the query below.
    #    --es 09/14/2007
    #return if $mysql_config ne "";
    return;

    ## Cache file
    my $regionScoreFile = "$cgi_tmp_dir/$gene_oid.regionScores.tab.txt";
    if ( -e $regionScoreFile ) {
        webLog "loadConsRegionScore: using file '$regionScoreFile'\n"
          if $verbose >= 1;
        my $rfh = newReadFileHandle( $regionScoreFile, "loadConsRegionScore" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            my ( $ortholog, $score ) = split( /\t/, $s );
            $ortholog2Scores_ref->{$ortholog} = $score;
        }
        close $rfh;
        return;
    }

    my $wfh = newWriteFileHandle( $regionScoreFile, "loadRegionScore" );
    my $sql = qq{
       select go1.ortholog, count( distinct go2.ortholog )
       from positional_cluster_genes pg1, gene_orthologs go1,
         gene_orthologs go2, positional_cluster_genes pg2,
         positional_cluster_genes pg3, positional_cluster_genes pg4
       where go1.gene_oid = ?
       and go1.gene_oid = pg1.genes
       and go1.ortholog = pg2.genes
       and pg2.group_oid = pg3.group_oid
       and pg3.genes = go2.gene_oid
       and go2.ortholog = pg4.genes
       and pg4.group_oid = pg1.group_oid
       group by go1.ortholog
       having count( distinct go2.ortholog ) > 1
       order by go1.ortholog
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $ortholog, $score ) = $cur->fetchrow();
        last if !$ortholog;
        my $regionScore = $score - 1;
        $ortholog2Scores_ref->{$ortholog} = $regionScore;
        print $wfh "$ortholog\t";
        print $wfh "$regionScore\n";
    }
    $cur->finish();
    close $wfh;
}

############################################################################
# printConsRegionScoreNote - Link out to note explaining conserved
#   region score.
############################################################################
sub printConsRegionScoreNote {
    my $s = qq{
      <h1>Conserved Region Score</h1>
      <p>
      <strong>Positional Clusters</strong> are runs of genes within
      300 base pairs of each other.  (By itself, this does not
      imply conservation with other positional clusters.)
      <br/>
      <br/>
      The <strong>Conserved Region Score</strong>
      measures the strength of 
      chromosomal neighborhood region conservation between two
      orthologs.  It does this by counting <i>additional</i> 
      orthologs between two positional clusters to which the original
      pairs of orthologs belong.
      <br/>
      <br/>
      Besides measuring the strength of neighborhood 
      conservation in terms of count of neigbhoring orthologs, 
      the conserved region score is used to rank the most
      similar to less similar neighborhoods in the
      ortholog neighborhood chromosomal viewer.
      </p>
   };
    print "$s\n";
}

############################################################################
# printProteinFaa - Print gene page amino acid display.
#   Include alternate s.
############################################################################
sub printProteinFaa {
    my ($gene_oid) = @_;

    my $dbh = dbLogin();

    print "<pre>\n";

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag, g.gene_symbol, 
           tx.genus, tx.species, g.aa_residue, scf.scaffold_name
        from  gene g, taxon tx, scaffold scf
        where g.gene_oid = ?
        and g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and g.aa_residue is not null
        and g.aa_seq_length > 0
    };
    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $genus, $species, $aa_residue, $scaffold_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        my $seq = wrapSeq($aa_residue);
        print "<font color='blue'>";
        my $ids;
        $ids = "$locus_tag "   if !blankStr($locus_tag);
        $ids = "$gene_symbol " if !blankStr($gene_symbol);
        print ">$gene_oid $ids$gene_display_name [$scaffold_name]";
        print "</font>\n";
        print "$seq\n";
    }
    $cur->finish();

    my $sql = qq{
        select g.gene_oid, at.name, g.locus_tag, g.gene_symbol, 
           tx.genus, tx.species, at.aa_residue, scf.scaffold_name
        from alt_transcript at, gene g, taxon tx, scaffold scf
        where g.gene_oid = ?
        and g.gene_oid = at.gene
        and g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and at.aa_residue is not null
        and at.aa_seq_length > 0
        order by at.alt_transcript_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $genus, $species, $aa_residue, $scaffold_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( blankStr($aa_residue) ) {
            webLog("printProteinFaa() aa_residue not found for gene_oid=$gene_oid\n");
            next;
        }
        my $seq = wrapSeq($aa_residue);
        print "<font color='blue'>";
        my $ids;
        $ids = "$locus_tag "   if !blankStr($locus_tag);
        $ids = "$gene_symbol " if !blankStr($gene_symbol);
        print ">$gene_oid (alt. $count) ";
        print "$ids$gene_display_name [$scaffold_name]";
        print "</font>\n";
        print "$seq\n";
    }
    $cur->finish();

    print "</pre>\n";
    #$dbh->disconnect();
}

############################################################################
# printRegionScoreNote - Link out to note explaining conserved
#   region score.
############################################################################
sub printRegionScoreNote {
    my $s = qq{
      <h1>Conserved Region Score</h1>
      <p>
      <strong>Positional Clusters</strong> are runs of genes within
      300 base pairs of each other.  (By itself, this does not
      imply conservation with other positional clusters.)
      <br/>
      <br/>
      The <strong>Conserved Region Score</strong>
      measures the strength of 
      chromosomal neighborhood region conservation between two
      orthologs.  It does this by counting <i>additional</i> 
      orthologs between two positional clusters to which the original
      pairs of orthologs belong.
      <br/>
      <br/>
      Besides measuring the strength of neighborhood 
      conservation in terms of count of neigbhoring orthologs, 
      the conserved region score is used to rank the most
      similar to less similar neighborhoods in the
      ortholog neighborhood chromosomal viewer.
      </p>
   };
    print "$s\n";
}

############################################################################
# printFusionComponents - Print components to this query gene
#   which is a fusion gene.
#      --es 07/06/2007
############################################################################
sub printFusionComponents {
    my $gene_oid = param("gene_oid");

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Fusion Components</h1>\n";
    print "<p>\n";

    print "<p>\n";
    print "Fusion components are taken from exemplar homologs.<br/>\n";
    print "</p>\n";

    my $contact_oid = getContactOid();

    my $sql = qq{
        select gfc.component, c.cog_id, c.cog_name
        from gene_fusion_components gfc, gene_cog_groups gcg, cog c
        where gfc.gene_oid = $gene_oid
        and gfc.component = gcg.gene_oid
        and gcg.cog = c.cog_id
        order by gfc.component, c.cog_id
    };
    my %comp2Cogs;
    loadFuncMap( $dbh, $sql, \%comp2Cogs );

    my $sql = qq{
        select gfc.component, pf.ext_accession, pf.name
        from gene_fusion_components gfc, gene_pfam_families gpf, pfam_family pf
        where gfc.gene_oid = $gene_oid
        and gfc.component = gpf.gene_oid
        and gpf.pfam_family = pf.ext_accession
        order by gfc.component, pf.ext_accession
    };
    my %comp2Pfams;
    loadFuncMap( $dbh, $sql, \%comp2Pfams );

    my $sql = qq{
        select gfc.component, ez.ec_number, ez.enzyme_name
        from gene_fusion_components gfc, gene_ko_enzymes ge, enzyme ez
        where gfc.gene_oid = $gene_oid
        and gfc.component = ge.gene_oid
        and ge.enzymes = ez.ec_number
        order by gfc.component, ez.ec_number
    };
    my %comp2Enzymes;
    loadFuncMap( $dbh, $sql, \%comp2Enzymes );

    my $sql = qq{
        select gfc.component, gmf.product_name, gmf.ec_number
        from gene_fusion_components gfc, gene_myimg_functions gmf
        where gfc.gene_oid = $gene_oid
        and gfc.component = gmf.gene_oid
        and gmf.modified_by = $contact_oid
        order by gfc.component
    };
    my %comp2MyImg;

    ## --es 07/18/2007
    my %comp2Count;
    if ( !$img_lite ) {
        my $sql = qq{
            select gfc.component, count( distinct go.ortholog )
            from gene_fusion_components gfc, gene_orthologs go
            where gfc.component = go.gene_oid
            and gfc.gene_oid = ?
            group by gfc.component
            order by gfc.component
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ( $component, $cnt ) = $cur->fetchrow();
            last if !$component;
            $comp2Count{$component} = $cnt;
        }
        $cur->finish();
    }

    my $query_gene_len = geneOid2AASeqLength( $dbh, $gene_oid );

    ## --es 07/18/2007

#### BEGIN updated table +BSJ 04/13/10

    my $it = new InnerTable( 1, "FusionComponents$$", "FusionComponents", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Exemplar", "char asc", "left" );
    $it->addColSpec( "COG",      "char asc", "left" );
    $it->addColSpec( "Pfam",     "char asc", "left" );
    $it->addColSpec( "Enzyme",   "char asc", "left" );
    $it->addColSpec( "MyIMG",    "char asc", "left" )
      if $contact_oid > 0 && $show_myimg_login;
    $it->addColSpec( "Percent<br/>Identity",  "number desc", "right" );
    $it->addColSpec( "Alignment Coordinates", "number desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query Gene");
    $it->addColSpec( "Exemplar<br/>Length",        "number desc", "right" );
    $it->addColSpec( "Components<br/>Represented", "number desc", "right" );

    if ( !$img_lite ) {
        $it->addColSpec( "Ortholog<br/>Count", "number desc", "right" );
    }

    my $rclause   = WebUtil::urClause('g2.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql       = qq{
        select gfc.gene_oid, gfc.component, gfc.taxon,
            gfc.query_start, gfc.query_end,
            gfc.percent_identity, gfc.evalue, gfc.bit_score,
            g2.gene_display_name, gfc.comp_length,
            gfc.n_components
        from gene_fusion_components gfc, gene g2
        where gfc.component = g2.gene_oid
            and gfc.gene_oid = ?
            $rclause
            $imgClause
        order by gfc.query_start, gfc.component
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;
    for ( ; ; ) {
        my (
             $gene_oid,          $component,        $taxon,  $query_start,
             $query_end,         $percent_identity, $evalue, $bit_score,
             $gene_display_name, $aa_seq_length,    $n_components
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        my $percent_identity = sprintf( "%.2f", $percent_identity );
        my $cogs             = $comp2Cogs{$component};
        my $pfams            = $comp2Pfams{$component};
        my $enzymes          = $comp2Enzymes{$component};
        my $myImg            = $comp2MyImg{$component};

        my $url = "$section_cgi&page=geneDetail&gene_oid=$component";
        my $tblRow = $component . $sd . alink( $url, $component ) . ": ";
        $tblRow .= escHtml($gene_display_name) . "\t";

        $tblRow .= fusionString( $cogs,    $sd );
        $tblRow .= fusionString( $pfams,   $sd );
        $tblRow .= fusionString( $enzymes, $sd );

        if ( $contact_oid > 0 && $show_myimg_login ) {
            my @rows = split( /\n/, $pfams );
            my $itCell;
            for my $r (@rows) {
                my ( $name, $ec ) = split( /\t/, $r );
                $itCell .= escHtml($name);
                if ( $ec ne "" ) {
                    $itCell .= "($ec)";
                }
                $itCell .= "<br/>";
            }
            if ( $myImg eq "" ) {
                $tblRow .= " " . $sd . nbsp(1) . "\t";
            } else {
                $tblRow .= $itCell . $sd . $itCell . "\t";
            }
        }

        $tblRow .= $percent_identity . $sd . $percent_identity . "\t";
        $tblRow .= $query_start . $sd;
        $tblRow .= "<span style='white-space:nowrap;'>";
        $tblRow .= "$query_start..$query_end / $query_gene_len</span>\t";
        $tblRow .= "--" . $sd;
        $tblRow .= alignImage( $query_start, $query_end, $query_gene_len ) . "\t";
        $tblRow .= $aa_seq_length . $sd . "${aa_seq_length}aa\t";
        $tblRow .= $n_components . $sd . $n_components . "\t";

        ## --es 07/18/2007
        if ( !$img_lite ) {
            my $url = "$section_cgi&page=componentOrthologs";
            $url .= "&gene_oid=$gene_oid&component=$component";
            my $cnt  = $comp2Count{$component};
            my $link = 0;
            if ( $cnt > 0 ) {
                $link = alink( $url, $cnt );
            }
            $tblRow .= $cnt . $sd . $link . "\t";
        }
        $it->addRow($tblRow);
    }
    $cur->finish();
    $it->printOuterTable(1);

#### END updated table +BSJ 04/13/10

    if ( !$img_lite ) {
        printFusionComponentTaxons( $dbh, $gene_oid );
    }
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# fusionString - Convenience function to create InnerTable cell string for
#                printFusionComponents() above +BSJ 04/13/10
############################################################################
sub fusionString {
    my ( $fns, $sd ) = @_;
    my @rows = split( /\n/, $fns );
    my $cell;
    my $itCell;
    my $sortKey;
    for my $r (@rows) {
        my ( $id, $name ) = split( /\t/, $r );
        $cell    .= "<font color='blue'>$id</font>: " . escHtml($name) . "<br/>";
        $sortKey .= $id . ":" . $name . " ";
    }
    if ( $fns eq "" ) {
        $itCell .= " " . $sd . nbsp(1) . "\t";
    } else {
        $itCell .= $sortKey . $sd . $cell . "\t";
    }
    return $itCell;
}

############################################################################
# printFusionComponentTaxons - Show taxons with fusion components.
############################################################################
sub printFusionComponentTaxons {
    my ( $dbh, $gene_oid ) = @_;

    print "<h2>Genomes with Components</h2>\n";
    my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name
        from gene_all_fusion_components gfc, taxon tx
        where gfc.gene_oid = ?
        and gfc.taxon = tx.taxon_oid
        order by tx.taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    print "<p>\n";
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $url = "$section_cgi&page=taxonFusionComponents";
        $url .= "&gene_oid=$gene_oid&taxon_oid=$taxon_oid";
        print alink( $url, $taxon_display_name );
        print "<br/>\n";
    }
    $cur->finish();

    print "<br/>\n";
    my $url = "$main_cgi?section=PhyloDist&phyloDist=1";
    $url .= "&xlogSource=fusionComponents&genePageGeneOid=$gene_oid";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );
    print "</p>\n";
}

############################################################################
# printTaxonFusionComponents - Show components for one taxon.
############################################################################
sub printTaxonFusionComponents {
    my $gene_oid  = param("gene_oid");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>Genome Fusion Components</h1>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh                 = dbLogin();
    my $query_aa_seq_length = getAASeqLength( $dbh, $gene_oid );
    my $rclause             = WebUtil::urClause('g2.taxon');
    my $imgClause           = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql                 = qq{
        select g2.gene_oid, g2.gene_display_name, gfc.percent_identity,
            gfc.evalue, gfc.bit_score, gfc.query_start, gfc.query_end,
            gfc.subj_start, gfc.subj_end, g2.aa_seq_length,
            tx.taxon_oid, tx.domain, tx.seq_status,
            tx.taxon_display_name
        from gene_all_fusion_components gfc, taxon tx, gene g2
        where gfc.gene_oid = ?
            and gfc.taxon = ?
            and gfc.taxon = tx.taxon_oid
            and gfc.component = g2.gene_oid
            $rclause
            $imgClause
        order by gfc.query_start, gfc.bit_score desc
    };
    printGeneCartFooter();

#### BEGIN updated table +BSJ 04/13/10

    my $it = new InnerTable( 1, "GenomeFusion$$", "GenomeFusion", 5 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene<br/>Object<br/>Identifier", "asc",  "left" );
    $it->addColSpec( "Product",                        "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity",           "desc", "right" );
    $it->addColSpec( "E-value",                        "desc", "right" );
    $it->addColSpec( "Bit<br/>Score",                  "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query");
    $it->addColSpec("Alignment<br/>On<br/>Subject");
    $it->addColSpec( "Genome", "asc", "left" );

    my $cur   = execSql( $dbh, $sql, $verbose, $gene_oid, $taxon_oid );
    my $count = 0;

    for ( ; ; ) {
        my (
             $gene_oid,    $gene_display_name, $percent_identity, $evalue,   $bit_score,
             $query_start, $query_end,         $subj_start,       $subj_end, $subj_aa_seq_length,
             $taxon_oid,   $domain,            $seq_status,       $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        $count++;
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $evalue           = sprintf( "%.1e", $evalue );
        $bit_score        = sprintf( "%d",   $bit_score );

        my $row .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
        $url .= "&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $gene_display_name . $sd . escHtml($gene_display_name) . "\t";
        $row .= $percent_identity . $sd . $percent_identity . "\t";
        $row .= $evalue . $sd . $evalue . "\t";
        $row .= $bit_score . $sd . $bit_score . "\t";
        $row .= "--" . $sd . alignImage( $query_start, $query_end, $query_aa_seq_length ) . "\t";
        $row .= "--" . $sd . alignImage( $subj_start, $subj_end, $subj_aa_seq_length ) . "\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $it->addRow($row);
    }
    $cur->finish();
    $it->printOuterTable(1);

#### END updated table +BSJ 04/13/10

    printGeneCartFooter() if $count > 10;

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printComponentOrthologs - Print component orthologs given
#     fusion component.
#   --es 07/18/2007
############################################################################
sub printComponentOrthologs {
    my $gene_oid  = param("gene_oid");
    my $component = param("component");

    my $sql = qq{
        select distinct go.ortholog
        from gene_fusion_components gfc, gene_orthologs go
        where gfc.component = go.gene_oid
        and gfc.gene_oid = ?
        and gfc.component = ?
    };
    my @binds = ( $gene_oid, $component );
    my $it = new InnerTable( 1, "CompOrth$$", "CompOrth", 1 );
    HtmlUtil::printGeneListSectionSort( $it, $sql, "Component Orthologs", 1, @binds );
}

############################################################################
# printFusionProteins - Print fusion proteins this components
#  is involved in.
#     --es 10/21/2007
############################################################################
sub printFusionProteins {
    my $gene_oid = param("gene_oid");

    my $dbh = dbLogin();

    print "<h1>Related Fused Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $query_aa_seq_length = getAASeqLength( $dbh, $gene_oid );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct gfc.gene_oid, 
            g.gene_display_name, gfc.percent_identity,
            gfc.evalue, gfc.bit_score, 
            gfc.query_start, gfc.query_end,
            gfc.subj_start, gfc.subj_end, g.aa_seq_length, 
            tx.taxon_oid, tx.domain, tx.seq_status, tx.taxon_display_name
        from gene_all_fusion_components gfc, gene g, taxon tx
        where gfc.component = ?
            and gfc.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        order by gfc.component
    };
    my @binds = ($gene_oid);
    my $it = new InnerTable( 1, "relatedFusionProteins$$", "relatedFusionProteins", 8 );
    $it->addColSpec("Select");
    $it->addColSpec( "Fused<br/>Gene",       "asc",  "left" );
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Component");
    $it->addColSpec("Alignment<br/>On<br/>Fused<br/>Gene");
    $it->addColSpec( "Length",    "desc", "right" );
    $it->addColSpec( "E-value",   "asc",  "left" );
    $it->addColSpec( "Bit Score", "desc", "right" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );

    $it->addColSpec( "Genome Name", "asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $count = 0;
    for ( ; ; ) {
        my (
             $fused_gene,  $gene_display_name, $percent_identity, $evalue,   $bit_score,
             $query_start, $query_end,         $subj_start,       $subj_end, $subj_aa_seq_length,
             $taxon_oid,   $domain,            $seq_status,       $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$fused_gene;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$fused_gene' />\t";
        my $url = "$section_cgi&page=geneDetail&gene_oid=$fused_gene";
        $r .= $fused_gene . $sd . alink( $url, $fused_gene ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $query_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $query_start, $query_end, $subj_aa_seq_length ) . "\t";
        $r .= "$subj_aa_seq_length${sd}${subj_aa_seq_length}aa\t";
        my $evalue_f = sprintf( "%.1e", $evalue );
        $r .= "$evalue_f\t";
        my $bit_score2 = sprintf( "%d", $bit_score );
        $r .= "$bit_score2\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $it->addRow($r);
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter() if $count > 10;

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

#sub printFusionProteins_old {
#    my $gene_oid = param("gene_oid");
#
#    my $rclause = urClause("g.taxon");
#    my $sql     = qq{
#        select distinct gfc.gene_oid
#        from gene_all_fusion_components gfc, gene g
#        where gfc.component = $gene_oid
#        and gfc.gene_oid = g.gene_oid
#        $rclause
#        order by gfc.component
#    };
#    HtmlUtil::printGeneListSection( $sql, "Related Fused Genes" );
#}

############################################################################
# printSigCleavage - Print signal cleavage display.
############################################################################
sub printSigCleavage {
    my $gene_oid = param("gene_oid");

    print "<h1>Signal Cleavage</h1>\n";
    print "<p>\n";
    print "Two parts of the cleavage are indicated ";
    print "by different colors.\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh      = dbLogin();
    my $geneName = geneOid2Name( $dbh, $gene_oid );
    my $sql      = qq{
       select gsp.start_coord, gsp.end_coord
       from gene_sig_peptides gsp
       where gsp.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $start_coord, $end_coord ) = $cur->fetchrow();
    $cur->finish();
    my $seq = getAASequence( $dbh, $gene_oid );
    #$dbh->disconnect();

    my @bases     = split( //, $seq );
    my $nBases    = @bases;
    my $charCount = 0;
    print "<pre>\n";
    print ">$gene_oid $geneName<br/>\n";
    print "<font color='blue'>";
    for ( my $i = 0 ; $i < $nBases ; $i++ ) {
        my $i1 = $i + 1;
        my $b  = $bases[$i];
        if ( $charCount >= $seqWrapLen ) {
            print "\n";
            $charCount = 0;
        }
        print "$b";
        $charCount++;
        if ( $i1 == $start_coord ) {
            print "</font>";
            print "<font color='red'>";
        }
    }
    print "</font>";
    print "\n";
    print "</pre>\n";
    printStatusLine( "Loaded.", 2 );

}

############################################################################
# printTmTopo - Print transmembrane topology.
############################################################################
sub printTmTopo {
    my $gene_oid = param("gene_oid");

    print "<h1>Transmembrane Topology</h1>\n";
    print "<p>\n";
    print "<font color='blue'>Blue - Outside</font><br/>\n";
    print "<font color='green'>Green - Transmembrane Helix</font><br/>\n";
    print "<font color='red'>Red - Inside</font><br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh      = dbLogin();
    my $geneName = geneOid2Name( $dbh, $gene_oid );
    my $sql      = qq{
       select gtm.gene_oid, gtm.feature_type, gtm.start_coord, gtm.end_coord
       from gene_tmhmm_hits gtm
       where gtm.gene_oid = ?
       order by gtm.start_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my @ranges;
    for ( ; ; ) {
        my ( $gene_oid, $feature_type, $start_coord, $end_coord ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$start_coord\t";
        $r .= "$end_coord\t";
        $r .= "$feature_type\t";
        webLog "$r\n" if $verbose >= 3;
        push( @ranges, $r );
    }
    $cur->finish();
    my $nRanges = @ranges;
    my $seq = getAASequence( $dbh, $gene_oid );
    #$dbh->disconnect();

    my @bases     = split( //, $seq );
    my $nBases    = @bases;
    my $charCount = 0;
    print "<pre>\n";
    print ">$gene_oid $geneName<br/>\n";
    print "<font color='blue'>";
    my $last_r_idx = 0;
    for ( my $i = 0 ; $i < $nBases ; $i++ ) {
        my $i1 = $i + 1;
        my $b  = $bases[$i];
        if ( $charCount >= $seqWrapLen ) {
            print "\n";
            $charCount = 0;
        }
        for ( my $j = $last_r_idx ; $j < $nRanges ; $j++ ) {
            my $r = $ranges[$j];
            my ( $start_coord, $end_coord, $type ) = split( /\t/, $r );
            if ( $i1 == $start_coord ) {
                if ( $type eq "outside" ) {
                    print "<font color='blue'>";
                } elsif ( $type eq "inside" ) {
                    print "<font color='red'>";
                } elsif ( $type eq "TMhelix" ) {
                    print "<font color='green'>";
                }
            }
            if ( $i1 >= $start_coord && $i1 < $end_coord ) {
                $last_r_idx = $j;
                last;
            }
        }
        print "$b";
        for ( my $j = $last_r_idx ; $j < $nRanges ; $j++ ) {
            my $r = $ranges[$j];
            my ( $start_coord, $end_coord, $type ) = split( /\t/, $r );
            if ( $i1 == $end_coord ) {
                print "</font>";
            }
            if ( $i1 > $start_coord && $i1 <= $end_coord ) {
                $last_r_idx = $j;
                last;
            }
        }
        $charCount++;
    }
    print "</font>";
    print "\n";
    print "</pre>\n";
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printCdsTools - Print tools for CDS gene.
############################################################################
sub printCdsTools {
    my ( $dbh, $gene_oid, $scaffold_oid, $taxon_oid,
     $start_coord, $end_coord, $strand ) = @_;

    print WebUtil::getHtmlBookmark( "tools", "" );

    # html bookmark 3
    print WebUtil::getHtmlBookmark
    ( "tools1.1", "<h2>External Sequence Search</h2>" );
    print "\n";

    print "<p>\n";
    my $data_type = param("data_type");
    my $url = "$main_cgi?section=NcbiBlast&ncbiBlast=1";
    $url .= "&genePageGeneOid=$gene_oid";
    $url .= "&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
    $url .= "&genome_type=metagenome";
    $url .= "&scaffold_oid=$scaffold_oid";
    $url .= "&strand=$strand";
    $url .= "&start_coord=$start_coord";
    $url .= "&end_coord=$end_coord";
    print alink( $url, "NCBI BLAST" ) . "<br/>\n";

    my $url = "$main_cgi?section=EbiIprScan&page=index";
    $url .= "&genePageGeneOid=$gene_oid";
    $url .= "&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
    $url .= "&genome_type=metagenome";
    print alink( $url, "EBI InterPro Scan" ) . "<br/>\n";

    my $url = "$main_cgi?section=PdbBlast&page=index";
    $url .= "&genePageGeneOid=$gene_oid";
    $url .= "&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
    $url .= "&genome_type=metagenome";
    print alink( $url, "Protein Data Bank BLAST" ) . "<br/>\n";

    print "</p>\n";
    print WebUtil::getHtmlBookmark
    ( "tools1.2", "<h2>IMG Sequence Search</h2>" );
    print "\n";
    print "<p>\n";

    my $url = "$main_cgi?section=OtfBlast&genePageGenomeBlast=1";
    $url .= "&genePageGeneOid=$gene_oid";
    $url .= "&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
    $url .= "&genome_type=metagenome";
    print alink( $url, "IMG Genome BLAST" ) . "<br/>\n";

    if ($data_type eq "assembled" 
    && MetaUtil::hasUnassembled($taxon_oid) 
    && hasSnpBlastDb($taxon_oid)) {
    my $url = "$main_cgi?section=GenePageEnvBlast"
            . "&page=snpBlastMERFS"
        . "&gene_oid=$gene_oid"
        . "&scaffold_oid=$scaffold_oid"
        . "&start_coord=$start_coord"
        . "&end_coord=$end_coord"
        . "&strand=$strand"
        . "&taxon_oid=$taxon_oid"
        . "&data_type=$data_type";
    print alink( $url, "SNP BLAST" ) . "<br/>\n";
    }

    # TODO yjlin
    #if ( !$img_lite ) {
    #    my $url = "$main_cgi?section=PhyloSim&genePagePhyloSim=1";
    #    $url .= "&genePageGeneOid=$gene_oid";
    #    print alink($url, "Phylogenetic Profile Similarity Search")."<br/>\n";
    #}

    if ($img_internal) {
        # TODO web artemis -ken does not work yet
        require Artemis;
        my $url = "$main_cgi?section=Artemis"
            . "&page=processArtemisFile&processArtemisFile=1"
        . "&scaffold_oid=$scaffold_oid&format=embl"
        . "&taxon_oid=$taxon_oid";
        print alink( $url, "Web Artemis" ) . "<br/>\n";
    }

    print "</p>\n";
}

sub printHomologToolKit {
    my ($gene_oid) = @_;
    my $url = "$main_cgi?section=HomologToolkit&page=queryForm";
    $url .= "&gene_oid=$gene_oid";
    print "<p>";
    print alink( $url, "Customized Homolog Display" ) . "<br/>\n";
    print "</p>";
}

############################################################################
# printMetaRnaTools - Print tools for RNA gene in MER-FS metagenomes
############################################################################
sub printMetaRnaTools {
    my ( $taxon_oid, $data_type, $gene_oid, $locus_type, $gene_symbol, $scaffold_oid,$start_coord, $end_coord, $strand ) = @_;

    # html bookmark 3
    print WebUtil::getHtmlBookmark( "tools", "<h2>External Sequence Search</h2>" );
    print "\n";


    print "<p>\n";
    my $data_type = param("data_type");
    my $url = "$main_cgi?section=NcbiBlast&ncbiBlast=1";
    $url .= "&genePageGeneOid=$gene_oid";
    $url .= "&taxon_oid=$taxon_oid";
    $url .= "&data_type=$data_type";
    $url .= "&genome_type=metagenome";
    $url .= "&scaffold_oid=$scaffold_oid";
    $url .= "&strand=$strand";
    $url .= "&start_coord=$start_coord";
    $url .= "&end_coord=$end_coord";
    print alink( $url, "NCBI BLAST" ) . "<br/>\n";


    # we need a message since the table of contents is always printed - ken
    if ( $gene_symbol ne "16S" || $greengenes_blast_url eq "" ) {
        #print "<p>Search available only for 16S. ($gene_symbol)</p>";
        #return;
    } else {

    #print "<p>\n";
    my $url = "$main_cgi?section=GreenGenesBlast";
    $url .= "&genePageGeneOid=$gene_oid&genePageTaxonOid=$taxon_oid" 
      . "&genePageDataType=$data_type";
    print alink( $url, "Green Genes BLAST" ) . "<br/>\n";
    }
    
    print "</p>\n";
}

#
# Phylogenetic Distribution select list
#
sub phyloDistSelect {
    my ($gene_oid) = @_;

    phyloDistSelectJavaScript($gene_oid);

    print WebUtil::getHtmlBookmark
    ( "phylodist", "<h2>Phylogenetic Distribution</h2>" );
    WebUtil::printMainFormName("1");
    print qq{      
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Phylogenetic Distribution
      &nbsp;
      </th>
      <td class='img'>
      
      <select name='phyloSelection' onChange='selectPhyloDist()'>
      <option value='label' select>
         -- Select Homolog Type -- &nbsp;&nbsp;&nbsp;&nbsp;
      </option>
      <option value='orthologs' >Paralogs / Orthologs &nbsp;&nbsp;&nbsp;&nbsp;</option>
      <option value='otfBlast' >Top IMG Homolog Hits</option>
      </select>
      </td>
      </tr>
      </table>         
    
   };

    print end_form();
}

# TODO testing
sub phyloDistSelectJavaScript {
    my ($gene_oid) = @_;

    print "<script language='javascript' type='text/javascript'>\n";
    print qq{
      function selectPhyloDist( ) {;
        var e = document.mainForm1.phyloSelection;
        var url = "$main_cgi?section=GeneDetail&page=phyloDist&gene_oid=$gene_oid";
        url += "&homologs=" + e.value;
        //alert(url);
        if(e.value != "label") {
            window.open( url, '_self' );
        }
        
      }
   };
    print "</script>\n";
}

sub phyloCdsHomologs {
    my $dbh = dbLogin();

    my $gene_oid                = param("gene_oid");
    my $homologs                = param("homologs");
    my $genePageDefaultHomologs = getSessionParam("genePageDefaultHomologs");
    if ( !blankStr($genePageDefaultHomologs) && $homologs eq "" ) {
        $homologs = $genePageDefaultHomologs;
    }

    param( "genePageGeneOid", $gene_oid );

    if ( $homologs eq "cluster" || $homologs eq "orthologs" ) {
        printStatusLine( "Loading ...", 1 );
        print hiddenVar( "xlogSource", "orthologs" );
        param( "xlogSource", "orthologs" );

        require PhyloDist;
        PhyloDist::printPhyloDistCounted();

        printStatusLine( "Loaded.", 2 );

    } elsif ( $homologs eq "otfBlast" ) {
        my $count = phyloTopHomologs( $dbh, $gene_oid );
        param( "page", "phyloDist" );

        require PhyloDist;
        PhyloDist::printPhyloDistCounted();

        printStatusLine( "Loaded.", 2 );
    }

    #$dbh->disconnect();
}

#
# javascript to clear working div
#
sub clearWorkingDiv {
    print qq{
    <script>
        var e0 = document.getElementById( "working" );
        e0.innerHTML = "";
    </script>
    }
}

#
sub phyloTopHomologs {
    my ( $dbh, $gene_oid ) = @_;

    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";
    my $clobberCache         = param("clobberCache");
    my $oldMaxHomologResults = param("oldMaxHomologResults");
    if ( $oldMaxHomologResults ne $maxHomologResults ) {
        $clobberCache = 1;
        webLog("maxHomologResults changed clobberCache=$clobberCache\n");
    }
    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    printStatusLine( "Loading ...", 1 );

    webLog ">>> printTopHomologs gene_oid='$gene_oid'\n"
      if $verbose >= 1;

    #   my $it = new InnerTable( $clobberCache, "topHomologs$$",
    #      "topHomologs", 8 );

    my %orthologs;
    my %paralogs;
    webLog( ">>> loadHomologOtfBlast get orthologs gene_oid='$gene_oid' " . currDateTime() . "\n" );

    print "<div id='working'>\n";
    print "<p><font size=1>\n";
    print "Getting orthologs...<br>\n";
    getOrthologs( $dbh, $gene_oid, \%orthologs );
    webLog( ">>> loadHomologOtfBlast get paralogs gene_oid='$gene_oid' " . currDateTime() . "\n" );

    print "Getting paralogs...<br>\n";
    getParalogs( $dbh, $gene_oid, \%paralogs );
    webLog( ">>> loadHomologOtfBlast get sequence gene_oid='$gene_oid' " . currDateTime() . "\n" );
    my $aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    webLog( ">>> loadHomologOtfBlast get top hits " . currDateTime() . "\n" );
    my @homologRecs;
    require OtfBlast;

    print "Getting top hits... " . currDateTime() . "<br>\n";
    my $filterType = OtfBlast::genePageTopHits( $dbh, $gene_oid, \@homologRecs );
    webLog( ">>> loadHomologOtfBlast got and retrieved top hits " . currDateTime() . "\n" );

    print "Loaded top hits... " . currDateTime() . "<br>\n";

    # end of working div
    print "</font></p></div>\n";
    clearWorkingDiv();

    #   $it->{ filterType } = $filterType;
    my $nHomologRecs = @homologRecs;
    my $trunc        = 0;
    my @recs;
    my $count = 0;
    for my $s (@homologRecs) {
        my (
             $gene_oid,    $homolog,   $taxon,  $percent_identity, $query_start0, $query_end0,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length
          )
          = split( /\t/, $s );
        next if $gene_oid == $homolog;
        if ( $count > $maxHomologResults ) {
            $trunc = 1;
            webLog( "loadHomologOtfBlast: truncate at " . "$maxHomologResults rows\n" );
            last;
        }
        $count++;
        my $query_start = $query_start0;
        my $query_end   = $query_end0;
        if ( $query_start0 > $query_end0 ) {
            $query_start = $query_end0;
            $query_end   = $query_start0;
        }
        my $r = "$homolog\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start0\t";
        $r .= "$subj_end0\t";
        $r .= "$align_length";
        push( @recs, $r );
    }
    $nHomologRecs = $count;
    my @recs2 = getGeneTaxonAttributes( $dbh, \@recs );

    my $taxonFilterHash_ref = getTaxonFilterHash();
    my $nFilterTaxons       = scalar( keys(%$taxonFilterHash_ref) );

    my %taxonsHit;
    my $percIdentRejects   = 0;
    my $alignPerc1Rejects  = 0;
    my $alignPerc2Rejects  = 0;
    my @selected_gene_oids = param("selected_gene_oid");
    my %selectedGeneOids   = WebUtil::array2Hash(@selected_gene_oids);

    my $query_taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    $taxonsHit{$query_taxon_oid} = $query_taxon_oid;
    my $count = 0;
    for my $r (@recs2) {
        my (
             $homolog,            $gene_display_name,  $percent_identity, $evalue,         $bit_score,
             $query_start,        $query_end,          $subj_start,       $subj_end,       $align_length,
             $opType,             $subj_aa_seq_length, $taxon_oid,        $domain,         $seq_status,
             $taxon_display_name, $scf_ext_accession,  $scf_seq_length,   $scf_gc_percent, $scf_read_depth
          )
          = split( /\t/, $r );
        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        my $alignPercent = $align_length / $aa_seq_length * 100;
        $percent_identity = sprintf( "%.2f", $percent_identity );
        $count++;
        my $gene_url  = "$section_cgi&page=geneDetail&gene_oid=$homolog";
        my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $evalue2   = sprintf( "%.1e", $evalue );
        my $op        = "-";
        $op = "O" if $orthologs{"$gene_oid-$homolog"} ne "";
        $op = "P" if $paralogs{"$gene_oid-$homolog"}  ne "";
        my $r;
        my $ck;
        $ck = "checked" if $selectedGeneOids{$homolog} ne "";

        my $bit_score2 = sprintf( "%d", $bit_score );
        $taxonsHit{$taxon_oid} = $taxon_oid;
    }
    webLog("loadHomologOtfBlast: $count rows loaded\n");

    # hidden var
    print hiddenVar( "genePageGeneOid", $gene_oid );
    print hiddenVar( "xlogSource",      "otfBlast" );
    param( "genePageGeneOid", $gene_oid );
    param( "xlogSource",      "otfBlast" );

    my $outFile = "$cgi_tmp_dir/otfTaxonsHit.$gene_oid.txt";
    my @keys    = sort( keys(%taxonsHit) );
    my $wfh     = newWriteFileHandle( $outFile, "loadHomologOtfBlast" );
    for my $k (@keys) {
        print $wfh "$k\n";
    }
    close $wfh;
    return $count;
}

############################################################################
# printHomologSelect - Print homolog selector.
############################################################################
sub printHomologSelect {
    my ( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs ) = @_;

    if (    $img_lite
         && $homologs ne "otfBlast"
         && $homologs ne "otfBlastTypeO"
         && $homologs ne "otfBlastTypeP"
         && $homologs ne "nrhits" )
    {
        $homologs = "label";
    }
    my $contact_oid = getContactOid();
    my $genome_type;
    if ($include_bbh_lite) {
        $genome_type = geneOid2GenomeType( $dbh, $gene_oid );
    }
    print "<script language='javascript' type='text/javascript'>\n";
    print qq{
      function selectHomolog( ) {
         ct = ctime( );
         var e = document.mainForm.homologSelection;
         if(e.value == 'label') {
             return;
         }
         var url = "$section_cgi&page=homolog&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid";
         url += "&homologs=" + e.value;
         window.open( url, '_self' );
      }
    };
    print "</script>\n";
    my ( $ocSelected, $oSelected, $hSelected, $otfSelected );
    my ( $nrhitsSelected, $fusComSelected, $fusRelSelected );
    my ( $pheSelected, $ecoSelected, $disSelected, $relSelected );
    my ($labelSelected);
    my ($liteSelected);
    my ( $otfTypeOSelected, $otfTypePSelected, $clusterHomologsSelected );
    my ($topIsolatesSelected);
    my ($topAssembleSelected);

    if ( $homologs eq "otfBlast" ) {
        $otfSelected = "selected";
    } elsif ( $homologs eq "otfBlastTypeO" ) {
        $otfTypeOSelected = "selected";
    } elsif ( $homologs eq "otfBlastTypeP" ) {
        $otfTypePSelected = "selected";
    } elsif ( $homologs eq "liteSelected" ) {
        $liteSelected = "selected";
    } elsif ( $homologs eq "cluster" ) {
        $ocSelected = "selected";
    } elsif ( $homologs eq "nrhits" ) {
        $nrhitsSelected = "selected";
    } elsif ( $homologs eq "orthologs" ) {
        $oSelected = "selected";
    } elsif ( $homologs eq "phenotype" ) {
        $pheSelected = "selected";
    } elsif ( $homologs eq "ecotype" ) {
        $ecoSelected = "selected";
    } elsif ( $homologs eq "disease" ) {
        $disSelected = "selected";
    } elsif ( $homologs eq "relevance" ) {
        $relSelected = "selected";
    } elsif ( $homologs eq "clusterHomologs" ) {
        $clusterHomologsSelected = "selected";
    } elsif ( $homologs eq "topIsolates" ) {
        $topIsolatesSelected = "selected";
    } elsif ( $homologs eq "topAssemble" ) {
        $topAssembleSelected = "selected";
    } elsif ( $homologs eq "label" ) {
        $labelSelected = "selected";
    } else {
        $labelSelected = "selected";
    }

    my $s = qq{
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Homolog Selection
      &nbsp;
      </th>
      <td class='img'>
      <select name='homologSelection' onChange='selectHomolog()'>
      <option value='label' $labelSelected>
         -- Select Homolog Type --
         &nbsp;
         &nbsp;
         &nbsp;
         &nbsp;
       </option>
#     <option value='orthologs' $oSelected>Paralogs / Orthologs</option>
#      <option value='otfBlast' $otfSelected>
#         Top IMG Homolog Hits</option>

     };

    #    $s .= qq{
    #      <option value='phenotype' $pheSelected>Phenotype</option>
    #      <option value='ecotype' $ecoSelected>Habitat</option>
    #      <option value='disease' $disSelected>Disease</option>
    #      <option value='relevance' $relSelected>Relevance</option>
    #    };

    # rename ecotype to habitat - ken
    $s .= qq{
      </select>
      </td>
      </tr>
      </table>
    };

    ## IMG-lite version
    my $nrOpt;

    # --es 07/15/08
    #$nrOpt = "<option value='nrhits' $nrhitsSelected>NR hits</option>\n"
    #   if $ncbi_blast_server_url ne "";
    my $liteOpt;
    $liteOpt =
        "<option value='liteHomologs' $liteSelected>"
      . "Lite Homologs "
      . "(fast, precomputed UBLAST against reference isolates)</option>\n"
      if $lite_homologs_url ne "" || $use_app_lite_homologs;
    my $orthologFilterOpt;
    $orthologFilterOpt = "<option value='otfBlastTypeO' $otfTypeOSelected >" . "Orthologs only</option>\n"
      if $genome_type eq "isolate" && $include_bbh_lite;
    my $paralogFilterOpt;
    $paralogFilterOpt = "<option value='otfBlastTypeP' $otfTypePSelected >" . "Paralogs only</option>\n"
      if $genome_type eq "isolate" && $include_bbh_lite;
    my $clusterHomologsOpt;
    $clusterHomologsOpt =
      "<option value='clusterHomologs' $clusterHomologsSelected >" . "Cluster Homologs (experimental)</option>\n"
      if $img_internal
      && $img_hmms_serGiDb      ne ""
      && $img_hmms_singletonsDb ne "";
    my $topIsolatesOpt;
    $topIsolatesOpt = "<option value='topIsolates' $topIsolatesSelected >" . "Top Isolate Hits</option>\n"
      if $img_iso_blastdb ne "";

    # OBSOLETE location
    my $assemble_blast_data = $mer_data_dir . "/$taxon_oid/assembled/blast.data";
    $assemble_blast_data = $sandbox_blast_data_dir . "/" . sanitizeInt($taxon_oid) if($sandbox_blast_data_dir ne '');

    my $topAssembleOpt;
    $topAssembleOpt =
      "<option value='topAssemble' $topAssembleSelected >" . "Top Hits in Assembled Part of the Same Metagenome</option>\n"
      if ( -e $assemble_blast_data );

    #    my $s_lite = qq{
    #      <table class='img' border='1'>
    #      <tr class='img'>
    #      <th class='subhead'>Homolog Selection
    #      &nbsp;
    #      </th>
    #      <td class='img'>
    #      <select name='homologSelection' onChange='selectHomolog()'>
    #      <option value='label' $labelSelected>
    #         -- Select Homolog Type --
    #        &nbsp;
    #        &nbsp;
    #        &nbsp;
    #        &nbsp;
    #        &nbsp;
    #      </option>
    #      $liteOpt
    #      <option value='otfBlast' $otfSelected>
    #         Top IMG Homolog Hits</option>
    #      $orthologFilterOpt
    #      $paralogFilterOpt
    #      $topIsolatesOpt;
    #      $clusterHomologsOpt
    #      $nrOpt
    #      </select>
    #      </td>
    #      </tr>
    #      </table>
    #    };

    my $s_lite = qq{
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Homolog Selection
      &nbsp;
      </th>
      <td class='img'>
      <select name='homologSelection' onChange='selectHomolog()'>
      <option value='label' $labelSelected>
         -- Select Homolog Type --
        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;
      </option>
      $liteOpt
      $orthologFilterOpt
      $paralogFilterOpt
      $topIsolatesOpt
      $topAssembleOpt
      $clusterHomologsOpt
      $nrOpt
      </select>
      </td>
      </tr>
      </table>
    };

    # now the default for all --es 06/03/11
    #$s = $s_lite if $img_lite;
    $s = $s_lite;
    print "$s\n";
}

sub printHomologSelect_old {
    my ( $dbh, $gene_oid, $homologs ) = @_;

    if (    $img_lite
         && $homologs ne "otfBlast"
         && $homologs ne "otfBlastTypeO"
         && $homologs ne "otfBlastTypeP"
         && $homologs ne "nrhits" )
    {
        $homologs = "label";
    }
    my $contact_oid = getContactOid();
    my $genome_type;
    if ($include_bbh_lite) {
        $genome_type = geneOid2GenomeType( $dbh, $gene_oid );
    }
    print "<script language='javascript' type='text/javascript'>\n";
    print qq{
      function selectHomolog( ) {
         ct = ctime( );
         var e = document.mainForm.homologSelection;
         var url = "$section_cgi&page=homolog&gene_oid=$gene_oid";
         url += "&homologs=" + e.value;
         window.open( url, '_self' );
      }
    };
    print "</script>\n";
    my ( $ocSelected, $oSelected, $hSelected, $otfSelected );
    my ( $nrhitsSelected, $fusComSelected, $fusRelSelected );
    my ( $pheSelected, $ecoSelected, $disSelected, $relSelected );
    my ($labelSelected);
    my ($liteSelected);
    my ( $otfTypeOSelected, $otfTypePSelected, $clusterHomologsSelected );

    if ( $homologs eq "otfBlast" ) {
        $otfSelected = "selected";
    } elsif ( $homologs eq "otfBlastTypeO" ) {
        $otfTypeOSelected = "selected";
    } elsif ( $homologs eq "otfBlastTypeP" ) {
        $otfTypePSelected = "selected";
    } elsif ( $homologs eq "liteSelected" ) {
        $liteSelected = "selected";
    } elsif ( $homologs eq "cluster" ) {
        $ocSelected = "selected";
    } elsif ( $homologs eq "nrhits" ) {
        $nrhitsSelected = "selected";
    } elsif ( $homologs eq "orthologs" ) {
        $oSelected = "selected";
    } elsif ( $homologs eq "phenotype" ) {
        $pheSelected = "selected";
    } elsif ( $homologs eq "ecotype" ) {
        $ecoSelected = "selected";
    } elsif ( $homologs eq "disease" ) {
        $disSelected = "selected";
    } elsif ( $homologs eq "relevance" ) {
        $relSelected = "selected";
    } elsif ( $homologs eq "clusterHomologs" ) {
        $clusterHomologsSelected = "selected";
    } elsif ( $homologs eq "label" ) {
        $labelSelected = "selected";
    } else {
        $labelSelected = "selected";
    }

    my $s = qq{
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Homolog Selection
      &nbsp;
      </th>
      <td class='img'>
      <select name='homologSelection' onChange='selectHomolog()'>
      <option value='label' $labelSelected>
         -- Select Homolog Type --
         &nbsp;
         &nbsp;
         &nbsp;
         &nbsp;
       </option>
      <option value='orthologs' $oSelected>Paralogs / Orthologs</option>
      <option value='otfBlast' $otfSelected>
         Top IMG Homolog Hits</option>

     };

    #    $s .= qq{
    #      <option value='phenotype' $pheSelected>Phenotype</option>
    #      <option value='ecotype' $ecoSelected>Habitat</option>
    #      <option value='disease' $disSelected>Disease</option>
    #      <option value='relevance' $relSelected>Relevance</option>
    #    };

    # rename ecotype to habitat - ken
    $s .= qq{
      </select>
      </td>
      </tr>
      </table>
    };

    ## IMG-lite version
    my $nrOpt;

    # --es 07/15/08
    #$nrOpt = "<option value='nrhits' $nrhitsSelected>NR hits</option>\n"
    #   if $ncbi_blast_server_url ne "";
    my $liteOpt;
    $liteOpt =
        "<option value='liteHomologs' $liteSelected>"
      . "Lite Homologs "
      . "(fast, precomputed UBLAST against reference isolates)</option>\n"
      if $lite_homologs_url ne "" || $use_app_lite_homologs;
    my $orthologFilterOpt;
    $orthologFilterOpt = "<option value='otfBlastTypeO' $otfTypeOSelected >" . "Orthologs only</option>\n"
      if $genome_type eq "isolate" && $include_bbh_lite;
    my $paralogFilterOpt;
    $paralogFilterOpt = "<option value='otfBlastTypeP' $otfTypePSelected >" . "Paralogs only</option>\n"
      if $genome_type eq "isolate" && $include_bbh_lite;
    my $clusterHomologsOpt;
    $clusterHomologsOpt =
      "<option value='clusterHomologs' $clusterHomologsSelected >" . "Cluster Homologs (experimental)</option>\n"
      if $img_internal
      && $img_hmms_serGiDb      ne ""
      && $img_hmms_singletonsDb ne "";
    my $s_lite = qq{
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Homolog Selection
      &nbsp;
      </th>
      <td class='img'>
      <select name='homologSelection' onChange='selectHomolog()'>
      <option value='label' $labelSelected>
         -- Select Homolog Type --
        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;
        &nbsp;
      </option>
      $liteOpt
      <option value='otfBlast' $otfSelected>
         Top IMG Homolog Hits</option>
      $orthologFilterOpt
      $paralogFilterOpt
      $clusterHomologsOpt
      $nrOpt
      </select>
      </td>
      </tr>
      </table>
    };
    $s = $s_lite if $img_lite;
    print "$s\n";
}
############################################################################
# printMetaRnaHomologSelect - Print homolog selector.
############################################################################
sub printMetaRnaHomologSelect {
    my ( $dbh, $taxon_oid, $data_type, $gene_oid, $rnaHomologs, $locus_type ) = @_;

    WebUtil::printMainFormName( "RNA" );
    if ( $rnaHomologs eq "" ) {
        $rnaHomologs = "label";
    }
    print "<script language='javascript' type='text/javascript'>\n";
    print qq{
      function selectRnaHomolog( ) {
         ct = ctime( );
         var e = document.mainFormRNA.rnaHomologSelection;
         var url = "$section_cgi&page=rnaHomolog&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid";
         url += "&rnaHomologs=" + e.value;
         window.open( url, '_self' );
      }
    };
    print "</script>\n";

    my ($labelSelected);
    my ($isolateRnasSelected);
    my ($metaRnasSelected);

    if ( $rnaHomologs eq "topIsolateRnas" ) {
        $isolateRnasSelected = "selected";
    } elsif ( $rnaHomologs eq "topMetaRnas" ) {
        $metaRnasSelected = "selected";
    } else {
        $labelSelected = "selected";
    }

    my $s = qq{
      <table class='img' border='1'>
      <tr class='img'>
      <th class='subhead'>Homolog Selection
      &nbsp;
      </th>
      <td class='img'>
      <select name='rnaHomologSelection' onChange='selectRnaHomolog()'>
      <option value='label' selected>
         -- Select Homolog Type --
         &nbsp;
         &nbsp;
         &nbsp;
         &nbsp;
       </option>
      <option value='topIsolateRnas' $isolateRnasSelected>Top IMG Isolate RNA Hits</option>
    };
    
    if ( $include_metagenomes && $locus_type ne 'tRNA' ) {
        $s .= qq{
          <option value='topMetaRnas' $metaRnasSelected>Top IMG Metagenome RNA Hits</option>
        };        
    }
    $s .= qq{
      </select>
      </td>
      </tr>
      </table>
    };
    print "$s\n";
    print end_form( );
}

############################################################################
# printCdsHomologs - Handle homologs below
############################################################################
sub printCdsHomologs {
    my ( $dbh, $taxon_oid, $data_type, $gene_oid ) = @_;

    my $homologs                = param("homologs");
    my $genePageDefaultHomologs = getSessionParam("genePageDefaultHomologs");
    if ( !blankStr($genePageDefaultHomologs) && $homologs eq "" ) {
        $homologs = $genePageDefaultHomologs;
    }

    printMainForm();

    print hiddenVar( "genePageGeneOid", $gene_oid );

    if ( $homologs eq "label" || $homologs eq "" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
    } elsif ( $homologs eq "cluster" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printQueryGeneCB($gene_oid, $taxon_oid, $data_type);    # for both tables
        my $name = "_section_DistanceTree_phyloTree";
        print submit(
                      -name  => $name,
                      -value => "Phylogenetic Distribution",
                      -class => 'medbutton'
        );
        printParalogs( $dbh, $gene_oid );
        printOrthologSummary( $dbh, $gene_oid );
    } elsif ( $homologs eq "orthologs" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printQueryGeneCB($gene_oid, $taxon_oid, $data_type);    # for both tables
        my $name = "_section_DistanceTree_phyloTree";
        print submit(
                      -name  => $name,
                      -value => "Phylogenetic Distribution",
                      -class => 'medbutton'
        );
        printParalogs( $dbh, $gene_oid );
        printOrthologs( $dbh, $gene_oid );
    } elsif (    $homologs eq "phenotype"
              || $homologs eq "ecotype"
              || $homologs eq "disease"
              || $homologs eq "relevance" )
    {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printCategorySummary( $dbh, $gene_oid, $homologs );
    } elsif ( $homologs eq "otfBlast" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 0 );
    } elsif ( $homologs eq "topIsolates" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 0 );
    } elsif ( $homologs eq "topAssemble" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopAssembleHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 0 );
    } elsif ( $homologs eq "otfBlastTypeO" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 0, "O" );
    } elsif ( $homologs eq "otfBlastTypeP" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 0, "P" );
    } elsif ( $homologs eq "liteHomologs" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printTopHomologs( $dbh, $taxon_oid, $data_type, $gene_oid, 1 );
    } elsif ( $homologs eq "clusterHomologs" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printClusterHomologs( $dbh, $gene_oid, 1 );
    } elsif ( $homologs eq "nrhits" ) {
        printHomologSelect( $dbh, $taxon_oid, $data_type, $gene_oid, $homologs );
        printNrHits( $dbh, $gene_oid );
    }
    print end_form();
}

############################################################################
# printDeletedGenePage - Print the page for deleted gene.
############################################################################
sub printDeletedGenePage {
    my ( $dbh, $gene_oid ) = @_;

    printMainForm();
    print "<h1>Unmapped Gene</h1>\n";
    print "<p>\n";
    print "The following gene is unmappable from a previous version of IMG.<br/>\n";
    print "</p>\n";

    my $sql = qq{
        select old_gene_oid, locus_tag, gene_display_name, taxon_name,
           aa_seq_length, aa_residue, img_version
        from unmapped_genes_archive
        where old_gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $gene_oid, $locus_tag, $gene_display_name, $taxon_name, 
     $aa_seq_length, $aa_residue, $img_version ) = $cur->fetchrow();
    $cur->finish();

    print "<table class='img'  border='1'>\n";
    printAttrRow( "Gene ID", $gene_oid );
    printAttrRow( "Locus Tag",    $locus_tag );
    printAttrRow( "Product Name", $gene_display_name );
    printAttrRow( "Genome Name",  $taxon_name );
    my $seq = wrapSeq( $aa_residue, 10 );
    printAttrRow( "Protein Sequence (${aa_seq_length}aa)", $seq );
    printAttrRow( "IMG Version",  $img_version );
    print "</table>\n";

    print end_form();
}

############################################################################
# hasSnpBlastDb - Has SNP Blast database
############################################################################
sub hasSnpBlastDb {
    my ( $taxon_oid ) = @_;
    #my $snp_blast_data_dir = $env->{snp_blast_data_dir_merfs};
    my $snp_blast_data_dir = $mer_data_dir;
    my $dbFile = "$snp_blast_data_dir/$taxon_oid/unassembled/"
           . "blast.data/$taxon_oid" . ".u.fna";
    return 1 if -e $dbFile;

    return 0;
}

############################################################################
# hasGenomeProperties - Has at least one genome property.
#   --es 10/17/2007
############################################################################
sub hasGenomeProperties {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
      select sum( cnt ) from (
          select count( distinct gp.prop_accession ) cnt
          from gene_xref_families gxf, genome_property gp,
             property_step ps, property_step_evidences pse
          where gxf.gene_oid = ?
          and gxf.id = pse.query
          and pse.step_accession = ps.step_accession
          and ps.genome_property = gp.prop_accession
               union
          select count( distinct gp.prop_accession ) cnt
          from gene_pfam_families gpf, genome_property gp,
             property_step ps, property_step_evidences pse
          where gpf.gene_oid = ?
          and gpf.pfam_family = pse.query
          and pse.step_accession = ps.step_accession
          and ps.genome_property = gp.prop_accession
      )
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $gene_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# Gene cassette viewer link
# prints viewer selection - cassette, neighborhoods
############################################################################
sub printViewers {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $cassette_oid ) = @_;

    # new cog coloring for 2.9
    my $url =
        "$main_cgi?section=GeneNeighborhood"
      . "&page=geneOrthologNeighborhood"
      . "&taxon_oid=$taxon_oid&data_type=$data_type"
      . "&gene_oid=$gene_oid&show_checkbox=1&cog_color=yes";

    
        print alink( $url, "Show neighborhood regions with the same top isolate hit" );
        print "<br/>\n";
    

    # print form tag and name
    WebUtil::printMainFormName("cassette");

    # cassette stuff
    if ( ( !$include_metagenomes || $img_er ) && $cassette_oid ne "" ) {
        print qq{
        <script language='javascript' type='text/javascript'>

        function selectCassette() {
        ct = ctime( );
        var e =  document.mainFormcassette.cassetteSelection;
        if(e.value == 'label') {
            return;
        }
        var url = "main.cgi?section=GeneCassette&page=geneCassette&gene_oid=$gene_oid&type=";
        url += e.value;
        window.open( url, '_self' );
            }
        </script>
        };

        printProteinSelection( "Chromosomal Cassette Viewer By", "cassetteSelection", "selectCassette()" );
        print "<br>\n";
    }

    print end_form();
}

############################################################################
# prints analysis / operon selection
############################################################################
sub printAnalysis {
    my ( $dbh, $gene_oid ) = @_;

    WebUtil::printMainFormName("analysis");

    print qq{
        <script language='javascript' type='text/javascript'>

        function selectClusterMethod() {
        ct = ctime( );
        var e =  document.mainFormanalysis.ClusterMethodSelection;
        if(e.value == 'label') {
            return;
        }
        var url = "$main_cgi?section=Operon&page=geneConnections&genePageGeneOid=$gene_oid&expansion=2";
        url += "&clusterMethod=" + e.value;
        window.open( url, '_self' );
            }
        </script>

    };

    # print the option list
    print qq{
        <tr class='img'>
        <th class='subhead'>Protein Cluster Context</th>
        <td class='img'>
    };
    printProteinSelection( "<b>Analysis</b> By", "ClusterMethodSelection", "selectClusterMethod()" );
    print "</td> </tr>\n";

    print end_form();
}

############################################################################
# prints cassette details selection
############################################################################
sub printCassetteInfo {
    my ( $dbh, $gene_oid, $cassette_oid ) = @_;

    WebUtil::printMainFormName("cassette2");

    print qq{
        <script language='javascript' type='text/javascript'>

        function selectCassetteDetail() {
        ct = ctime( );
        var e =  document.mainFormcassette2.cassetteDetail
        if(e.value == 'label') {
            return;
        }
        var url = "main.cgi?section=GeneCassette&page=cassetteBox&gene_oid=$gene_oid&type=";
        url +=  e.value;
        window.open( url, '_self' );
            }
        </script>

    };

    print qq{
        <tr class='img'>
        <th class='subhead'>Chromosomal Cassette</th>
        <td class='img'>
    };
    if ( $cassette_oid ne "" ) {
        printProteinSelection( "<b>Details</b> By", "cassetteDetail", "selectCassetteDetail()" );
    } else {
        print "&nbsp;";
    }
    print "</td> </tr>\n";

    print end_form();
}

############################################################################
# prints cassette's or operon's selection box
#
# $label - text before selection bos - can be null
# $name - html selection name
# $jsFunction - onchange javascript to call
# see GeneCassette
############################################################################
sub printProteinSelection {
    my ( $label, $name, $jsFunction ) = @_;
    GeneCassette::printProteinSelection( $label, $name, $jsFunction );
}

#
# prints gene's pfams
#
sub printProteinPfam {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, $pfam_ref ) = @_;

    if ( !$pfam_ref || scalar(@$pfam_ref) == 0 ) {
        return;
    }

    my @a = ($gene_oid);

    my $pfam_str = "";
    for my $line (@$pfam_ref) {
        chomp($line);
        my ( $gid2, $pfam_id, @rest ) = split( /\t/, $line );
        if ($pfam_str) {
            $pfam_str .= ", '" . $pfam_id . "'";
        } else {
            $pfam_str = "'" . $pfam_id . "'";
        }
    }

    if ( blankStr($pfam_str) ) {
        return;
    }

    print "<tr class='img'>\n";
    print "<th class='subhead'>Pfam</th>\n";
    print "<td class='img'>\n";

    my $sql = qq{
       select p.ext_accession, p.name
       from pfam_family p
       where p.ext_accession in ( $pfam_str )
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    for ( ; ; ) {
        my ( $p2_id, $pfam_name ) = $cur->fetchrow();
        last if !$p2_id;

        $cnt++;
        last if ( $cnt > 100 );

        my $func_id2 = $p2_id;
        $func_id2 =~ s/pfam/PF/;
        print "<a href='" . $pfam_base_url . $func_id2 . "'>  $p2_id </a> - $pfam_name ";
        print " <br/>\n";
    }
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";
}

#
# prints gene's bbh
#
sub printProteinBBH {
    my ( $dbh, $gene_oid ) = @_;

    my @gene_list = ($gene_oid);

    # list of fusing genes found
    my @fusion_genes;

    # look for cycle connections
    my %cycle;
    $cycle{$gene_oid} = "";

    # check query when bbh redone and fusion added to bbh_memebers table - ken
    GeneCassette::getFusionGenes( $dbh, $gene_oid, \@fusion_genes, \%cycle );
    push( @gene_list, @fusion_genes );
    my $aref = GeneCassette::getBBHClusterInfo( $dbh, \@gene_list );

    # now used to count fused genes found
    my $cnt = 0;

    my $url = "$main_cgi?section=TaxonDetail&page=orthologClusterGeneList" . "&cluster_id=";

    print "<tr class='img'>\n";
    print "<th class='subhead' title='Bidirectional Best Hits (MCL)'>" . "IMG Ortholog Cluster</th>\n";
    print "<td class='img'>\n";

    # bbh
    foreach my $line (@$aref) {
        my ( $gid, $cid, $func ) = split( /\t/, $line );

        # fused genes
        my $tmp = $url . $cid;
        print alink( $tmp, "$cid" );
        print " - $func";
        print "<br/>\n";
        $cnt++;
    }

    # if $cnt == 1 then its just the gene itself and do nothing
    if ( $cnt > 1 ) {

        # fusion bbh footnote
        #print "<font size=-1>* - fused gene&#39;s cluster id.</font>\n";
    } elsif ( $cnt == 0 ) {

        # no bbh found
        print "&nbsp;";
    }

    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printGenomeProperties - Print list of genome properties for gene.
#   --es 10/17/2007
############################################################################
sub printGenomeProperties {
    my ( $dbh, $gene_oid ) = @_;

    return if !WebUtil::tableExists( $dbh, "genome_property" );
    return if hasGenomeProperties( $dbh, $gene_oid ) == 0;

    print "<h2>Genome Properties</h2>\n";

    my $sql = qq{
       select gxf.gene_oid gene_oid, 
          gxf.id funcId, gp.prop_accession prop_accession, gp.name prop_name,
          ps.step_accession, ps.name
       from gene_xref_families gxf, genome_property gp,
          property_step ps, property_step_evidences pse
       where gxf.gene_oid = ?
       and gxf.id = pse.query
       and pse.step_accession = ps.step_accession
       and ps.genome_property = gp.prop_accession
           union
       select gpf.gene_oid gene_oid, 
          gpf.pfam_family funcId, gp.prop_accession prop_accession, 
          gp.name prop_name, ps.step_accession, ps.name
       from gene_pfam_families gpf, genome_property gp,
         property_step ps, property_step_evidences pse
       where gpf.gene_oid = ?
       and gpf.pfam_family = pse.query
       and pse.step_accession = ps.step_accession
       and ps.genome_property = gp.prop_accession
       order by prop_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $gene_oid );
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Evidence</th>\n";
    print "<th class='img'>Accession</th>\n";
    print "<th class='img'>Property Name</th>\n";
    print "<th class='img'>Step</th>\n";
    print "<th class='img'>Step Name</th>\n";

    for ( ; ; ) {
        my ( $gene_oid, $funcId, $prop_accession, $prop_name, $step_accession, $step_name ) = $cur->fetchrow();
        last if !$gene_oid;
        print "<tr class='img'>\n";
        print "<td class='img'>$funcId</td>\n";
        my $url = "$main_cgi?section=GenomeProperty";
        $url .= "&page=genomePropertyDetails";
        $url .= "&gene_oid=$gene_oid";
        $url .= "&prop_accession=$prop_accession";
        print "<td class='img'>" . alink( $url, $prop_accession ) . "</td>\n";
        print "<td class='img'>" . escHtml($prop_name) . "</td>\n";
        print "<td class='img'>" . escHtml($step_accession) . "</td>\n";
        print "<td class='img'>" . escHtml($step_name) . "</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();
}

############################################################################
# printEstCopyNote - Print estimate copy note.
############################################################################
sub printEstCopyNote {
    print "<h1>Estimated Copy</h1>\n";

    print qq{
        <p style='width: 900px;'>
        Estimated copy is an abundance multiplier when used with
        abundance profile tools.  It is estimated from the read
        depth where the gene resides.  For well assembled isolate
        genomes, this value is 1, the abundance measure reflecting
        the gene count in the actual genome.  Additional reads in
        well assembled genomes do not confer additional abundance,
        but additional coverage to give confidence in the quality
        of assembly.

        <br/><br/>
        In the case of metagenomes, assembly of complex communities
        is usually not possible.  The reads reflect a random
        sampling of biological material, not the assembly of
        a single genomic entity.  For the few pieces
        that one manages to assemble,  the abundance measurement
        of multiple reads for one contig is collapsed into one
        gene.  The same problem occurs for proxy gene clustering
        of 454 short reads.  The estimated gene copy measure
        compensates for this collapse when using the abundance
        profile and comparison tools.  The "estimated copy"
        option should be selected when using such tools
        on metagenomes.
        </p>
     };
}

#
# get cog function
# returns tab delimited array
#
sub printCogFuncDefn {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
    select distinct gcg.cog, cf.function_code, cf.definition
    from gene_cog_groups gcg, cog_functions cfs, cog_function cf
    where cfs.functions = cf.function_code
    and gcg.cog = cfs.cog_id
    and gcg.gene_oid = ?
    order by cf.definition
    };

    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>COG Function</th>\n";
    print "<td class='img'>\n";

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $coid, $funcId, $func_name ) = $cur->fetchrow();
        last if !$coid;
        $count++;
        print "$func_name \n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

#
# gets gene main role
#
sub printTigrfamsMainRole {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type ) = @_;

    my $tigrfam_list = "";
    my @tigr_ids = MetaUtil::getGeneTIGRfamId($gene_oid, $taxon_oid, $data_type);
    for my $tigrfam_id ( @tigr_ids ) {
        if ($tigrfam_list) {
            $tigrfam_list .= ", '" . $tigrfam_id . "'";
        } else {
            $tigrfam_list = "'" . $tigrfam_id . "'";
        }
    }

    if ( blankStr($tigrfam_list) ) {
        return;
    }

    my $sql = qq{
    select distinct tr.main_role
    from tigrfam_roles trs, tigr_role tr
    where trs.roles = tr.role_id
    and trs.ext_accession in ( $tigrfam_list )
    order by tr.main_role
    };

    my $count = 0;
    print "<tr class='img'>\n";
    print "<th class='subhead'>TIGRfam Role</th>\n";
    print "<td class='img'>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($func_name) = $cur->fetchrow();
        last if !$func_name;

        $count++;
        print "$func_name \n";
    }
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish();
}

############################################################################
# getHorizontalTransfers - Get horizontal transfers from records.
# Input
#   $dbh - database handle
#   $homologRecs_aref - homolog records array
#   $gene_oid - Current gene object identifier
# Output
#   @htRecs - Horizontal transfer records with
#     -- gene_oid (homolog)
#     -- phyloLevel
#     -- phyloVal (phyla)
############################################################################
sub getHorizontalTransfers {
    my ( $dbh, $homologs_aref, $gene_oid ) = @_;

    my @a;
    return @a if !$include_ht_homologs;

    my $sql = qq{
       select tx.domain, tx.phylum, tx.ir_class, 
          tx.ir_order, tx.family, tx.genus 
       from taxon tx, gene g
       where g.gene_oid = ?
       and tx.taxon_oid = g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $domain0, $phylum0, $ir_class0, $ir_order0, $family0, $genus0 ) = $cur->fetchrow();
    my @lineage0;
    push( @lineage0, $domain0 );
    push( @lineage0, $phylum0 );
    push( @lineage0, $ir_class0 );
    push( @lineage0, $ir_order0 );
    push( @lineage0, $family0 );
    push( @lineage0, $genus0 );
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select tx.taxon_oid, tx.domain, tx.phylum, tx.ir_class, 
           tx.ir_order, tx.family, tx.genus 
       from taxon tx
       where (tx.domain like '%Bacteria%'
              or tx.domain like '%Archaea%'
              or tx.domain like '%Eukaryota%'
              or tx.domain like '%Viruses%'
           )
           $rclause
           $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %taxonOid2Phyla;
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
        last if !$taxon_oid;
        $domain = "Bacteria"  if $domain =~ /Bacteria/;
        $domain = "Archaea"   if $domain =~ /Archaea/;
        $domain = "Eukaryota" if $domain =~ /Eukaryota/;
        my $r = "$domain\t";
        $r .= "$phylum\t";
        $r .= "$ir_class\t";
        $r .= "$ir_order\t";
        $r .= "$family\t";
        $r .= "$genus\t";
        $taxonOid2Phyla{$taxon_oid} = $r;
    }
    $cur->finish();

    my %invalidPhyla;
    getInvalidPhyloLevelVals( $dbh, \%invalidPhyla );
    my $max_bit_score = 0;
    my @recs;
    for my $r (@$homologs_aref) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus ) =
          split( /\t/, $taxonOid2Phyla{$taxon_oid} );
        next if $domain eq "";
        $max_bit_score = $bit_score > $max_bit_score ? $bit_score : $max_bit_score;
        push( @recs, $r );
    }
    my $threshold = 0.95 * $max_bit_score;
    webLog("max_bit_score=$max_bit_score threshold=$threshold\n");

    my @lineages;
    my @homologs;
    for my $r (@recs) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        next if $gene_oid eq $homolog;
        next if $bit_score < $threshold;
        my @lineage = split( /\t/, $taxonOid2Phyla{$taxon_oid} );
        push( @lineages, \@lineage );
        push( @homologs, $homolog );
    }
    my @htRecs;
    my @phyloLevels;
    push( @phyloLevels, "domain" );
    push( @phyloLevels, "phylum" );
    push( @phyloLevels, "class" );
    push( @phyloLevels, "order" );
    push( @phyloLevels, "family" );
    push( @phyloLevels, "genus" );
    my $nPhyloLevels = @phyloLevels;

    for ( my $colIdx = 0 ; $colIdx < $nPhyloLevels ; $colIdx++ ) {
        my $phyloVal0   = $lineage0[$colIdx];
        my $phyloLevel  = $phyloLevels[$colIdx];
        my $phyloLevel2 = $phyloLevel;
        $phyloLevel2 = "ir_class" if $phyloLevel eq "class";
        $phyloLevel2 = "ir_order" if $phyloLevel eq "order";
        my $k = "$phyloLevel2:$phyloVal0";
        if ( $invalidPhyla{$k} ) {
            webLog("Invalid phyla '$k'\n");
            next;
        }
        my %outRec;
        if ( checkPhyloLevel( \@lineages, $colIdx, $phyloVal0, \%outRec ) ) {
            my $outRowIdx = $outRec{outRowIdx};
            my $homolog   = $homologs[$outRowIdx];
            my $phyloVal  = $outRec{phyloVal};
            webLog(   "HT: gene_oid=$gene_oid ht_homolog=$homolog "
                    . "[outRowIdx=$outRowIdx,colIdx=$colIdx] "
                    . "phyloLevel='$phyloLevel' phyloVal='$phyloVal'\n" );
            my $r = "$homolog\t";
            $r .= "$phyloLevel\t";
            $r .= "$phyloVal\t";
            push( @htRecs, $r );
            last;
        }
    }
    return @htRecs;
}

sub getHorizontalTransfers_indv {
    my ( $dbh, $homologs_aref, $gene_oid ) = @_;

    my @a;
    return @a if !$img_internal;

    my $sql = qq{
       select tx.domain, tx.phylum, tx.ir_class, 
          tx.ir_order, tx.family, tx.genus 
       from taxon tx, gene g
       where g.gene_oid = ?
       and tx.taxon_oid = g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $domain0, $phylum0, $ir_class0, $ir_order0, $family0, $genus0 ) = $cur->fetchrow();
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select tx.taxon_oid, tx.domain, tx.phylum, tx.ir_class, 
           tx.ir_order, tx.family, tx.genus 
       from taxon tx
       where (tx.domain like '%Bacteria%'
              or tx.domain like '%Archaea%'
              or tx.domain like '%Eukaryota%'
              or tx.domain like '%Viruses%'
           )
           $rclause
           $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %taxonOid2Phyla;
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
        last if !$taxon_oid;
        $domain = "Bacteria"  if $domain =~ /Bacteria/;
        $domain = "Archaea"   if $domain =~ /Archaea/;
        $domain = "Eukaryota" if $domain =~ /Eukaryota/;
        my $r = "$domain\t";
        $r .= "$phylum\t";
        $r .= "$ir_class\t";
        $r .= "$ir_order\t";
        $r .= "$family\t";
        $r .= "$genus\t";
        $taxonOid2Phyla{$taxon_oid} = $r;
    }
    $cur->finish();

    my %invalidPhyla;
    getInvalidPhyloLevelVals( $dbh, \%invalidPhyla );
    my $max_bit_score = 0;
    my @recs;
    for my $r (@$homologs_aref) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus ) =
          split( /\t/, $taxonOid2Phyla{$taxon_oid} );
        next if $domain eq "";
        $max_bit_score = $bit_score > $max_bit_score ? $bit_score : $max_bit_score;
        push( @recs, $r );
    }
    my $threshold = 0.95 * $max_bit_score;
    webLog("max_bit_score=$max_bit_score threshold=$threshold\n");

    my @htRecs;
    for my $r (@recs) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        next if $gene_oid eq $homolog;
        next if $bit_score < $threshold;
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus ) =
          split( /\t/, $taxonOid2Phyla{$taxon_oid} );
        next if $domain eq "";    # skip viruses and plasmids
        my ( $phyloLevel, $phyloVal, $phyloVal0 );
        if ( $domain ne $domain0 ) {
            $phyloLevel = "domain";
            $phyloVal   = $domain;
            $phyloVal0  = $domain0;
        } elsif (    $phylum ne $phylum0
                  && !nullPhyla($phylum)
                  && !nullPhyla($phylum0) )
        {
            $phyloLevel = "phylum";
            $phyloVal   = $phylum;
            $phyloVal0  = $phylum0;
        } elsif (    $ir_class ne $ir_class0
                  && !nullPhyla($ir_class)
                  && !nullPhyla($ir_class0) )
        {
            $phyloLevel = "class";
            $phyloVal   = $ir_class;
            $phyloVal0  = $ir_class0;
        } elsif (    $ir_order ne $ir_order0
                  && !nullPhyla($ir_order)
                  && !nullPhyla($ir_order0) )
        {
            $phyloLevel = "order";
            $phyloVal   = $ir_order;
            $phyloVal0  = $ir_order0;
        } elsif (    $family ne $family0
                  && !nullPhyla($family)
                  && !nullPhyla($family0) )
        {
            $phyloLevel = "family";
            $phyloVal   = $family;
            $phyloVal0  = $family0;
        } elsif (    $genus ne $genus0
                  && !nullPhyla($genus)
                  && !nullPhyla($genus0) )
        {
            $phyloLevel = "genus";
            $phyloVal   = $genus;
            $phyloVal0  = $genus0;
        } else {    # not an HT for the block
            @htRecs = ();
            last;
        }
        next if $phyloVal eq "";
        my $phyloLevel2 = $phyloLevel;
        $phyloLevel2 = "ir_class" if $phyloLevel eq "class";
        $phyloLevel2 = "ir_order" if $phyloLevel eq "order";
        my $k = "$phyloLevel2:$phyloVal0";
        if ( $invalidPhyla{$k} ) {
            webLog("$gene_oid invalid '$k'\n");
            next;
        }
        my $r = "$homolog\t";
        $r .= "$phyloLevel\t";
        $r .= "$phyloVal\t";
        push( @htRecs, $r );
    }

    return @htRecs;
}

sub getHorizontalTransfers_consistent {
    my ( $dbh, $homologs_aref, $gene_oid ) = @_;

    my $sql = qq{
       select tx.domain, tx.phylum, tx.ir_class, 
          tx.ir_order, tx.family, tx.genus 
       from taxon tx, gene g
       where g.gene_oid = ?
       and tx.taxon_oid = g.taxon
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $domain0, $phylum0, $ir_class0, $ir_order0, $family0, $genus0 ) = $cur->fetchrow();
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select tx.taxon_oid, tx.domain, tx.phylum, tx.ir_class, 
           tx.ir_order, tx.family, tx.genus 
       from taxon tx
       where (tx.domain like '%Bacteria%'
              or tx.domain like '%Archaea%'
              or tx.domain like '%Eukaryota%'
              or tx.domain like '%Viruses%'
           )
           $rclause
           $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %taxonOid2Phyla;
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
        last if !$taxon_oid;
        $domain = "Bacteria"  if $domain =~ /Bacteria/;
        $domain = "Archaea"   if $domain =~ /Archaea/;
        $domain = "Eukaryota" if $domain =~ /Eukaryota/;
        my $r = "$domain\t";
        $r .= "$phylum\t";
        $r .= "$ir_class\t";
        $r .= "$ir_order\t";
        $r .= "$family\t";
        $r .= "$genus\t";
        $taxonOid2Phyla{$taxon_oid} = $r;
    }
    $cur->finish();

    my %invalidPhyla;
    getInvalidPhyloLevelVals( $dbh, \%invalidPhyla );
    my $max_bit_score = 0;
    my @recs;
    for my $r (@$homologs_aref) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus ) =
          split( /\t/, $taxonOid2Phyla{$taxon_oid} );
        next if $domain eq "";
        $max_bit_score = $bit_score > $max_bit_score ? $bit_score : $max_bit_score;
        push( @recs, $r );
    }
    my $threshold = 0.95 * $max_bit_score;
    webLog("max_bit_score=$max_bit_score threshold=$threshold\n");

    my ( $domainVal, @domain_homologs ) = getConsistentPhyla( "domain", \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );
    my ( $phylumVal, @phylum_homologs ) = getConsistentPhyla( "phylum", \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );
    my ( $ir_classVal, @ir_class_homologs ) =
      getConsistentPhyla( "ir_class", \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );
    my ( $ir_orderVal, @ir_order_homologs ) =
      getConsistentPhyla( "ir_order", \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );
    my ( $familyVal, @family_homologs ) = getConsistentPhyla( "family", \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );
    my ( $genusVal,  @genus_homologs )  = getConsistentPhyla( "genus",  \@recs, $gene_oid, $threshold, \%taxonOid2Phyla );

    my @htRecs;
    if (    $domainVal ne ""
         && !nullPhyla($domain0)
         && !$invalidPhyla{"domain:$domain0"}
         && $domainVal ne $domain0 )
    {
        for my $homolog (@domain_homologs) {
            my $r = "$homolog\t";
            $r .= "domain\t";
            $r .= "$domainVal\t";
            push( @htRecs, $r );
        }
    } elsif (    $phylumVal ne ""
              && !nullPhyla($phylum0)
              && !$invalidPhyla{"phylum:$phylum0"}
              && $phylumVal ne $phylum0 )
    {
        for my $homolog (@phylum_homologs) {
            my $r = "$homolog\t";
            $r .= "phylum\t";
            $r .= "$phylumVal\t";
            push( @htRecs, $r );
        }
    } elsif (    $ir_classVal ne ""
              && !nullPhyla($ir_class0)
              && !$invalidPhyla{"ir_class:$ir_class0"}
              && $ir_classVal ne $ir_class0 )
    {
        for my $homolog (@ir_class_homologs) {
            my $r = "$homolog\t";
            $r .= "class\t";
            $r .= "$ir_classVal\t";
            push( @htRecs, $r );
        }
    } elsif (    $ir_orderVal ne ""
              && !nullPhyla($ir_order0)
              && !$invalidPhyla{"ir_order:$ir_order0"}
              && $ir_orderVal ne $ir_order0 )
    {
        for my $homolog (@ir_order_homologs) {
            my $r = "$homolog\t";
            $r .= "order\t";
            $r .= "$ir_orderVal\t";
            push( @htRecs, $r );
        }
    } elsif (    $familyVal ne ""
              && !nullPhyla($family0)
              && !$invalidPhyla{"family:$family0"}
              && $familyVal ne $family0 )
    {
        for my $homolog (@family_homologs) {
            my $r = "$homolog\t";
            $r .= "family\t";
            $r .= "$familyVal\t";
            push( @htRecs, $r );
        }
    } elsif (    $genusVal ne ""
              && !nullPhyla($genus0)
              && !$invalidPhyla{"genus:$genus0"}
              && $genusVal ne $genus0 )
    {
        for my $homolog (@genus_homologs) {
            my $r = "$homolog\t";
            $r .= "genus\t";
            $r .= "$genusVal\t";
            push( @htRecs, $r );
        }
    }
    return @htRecs;
}

############################################################################
# getConsistentPhyla - Get consistent phyla.
############################################################################
sub getConsistentPhyla {
    my ( $phyloLevel, $recs_aref, $gene_oid, $threshold, $taxonOid2Phyla_href ) = @_;

    my @htRecs;
    my $phyloVal;
    my @homologs;
    for my $r (@$recs_aref) {
        my (
             $homolog,            $gene_display_name, $percent_identity, $evalue,     $bit_score,
             $query_start,        $query_end,         $subj_start,       $subj_end,   $align_length,
             $subj_aa_seq_length, $taxon_oid,         $domain,           $seq_status, $taxon_display_name,
             $scf_ext_accession,  $scf_seq_length,    $scf_gc_percent,   $scf_read_depth
          )
          = split( /\t/, $r );
        next if $gene_oid eq $homolog;
        next if $bit_score < $threshold;
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus ) =
          split( /\t/, $taxonOid2Phyla_href->{$taxon_oid} );
        next if $domain eq "";    # skip viruses and plasmids
        if ( $phyloLevel eq "domain" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $domain;
            $phyloVal = $domain;
            push( @homologs, $homolog );
        } elsif ( $phyloLevel eq "phylum" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $phylum;
            $phyloVal = $phylum;
            push( @homologs, $homolog );
        } elsif ( $phyloLevel eq "ir_class" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $ir_class;
            $phyloVal = $ir_class;
            push( @homologs, $homolog );
        } elsif ( $phyloLevel eq "ir_order" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $ir_order;
            $phyloVal = $ir_order;
            push( @homologs, $homolog );
        } elsif ( $phyloLevel eq "family" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $family;
            $phyloVal = $family;
            push( @homologs, $homolog );
        } elsif ( $phyloLevel eq "genus" ) {
            return "" if $phyloVal ne "" && $phyloVal ne $genus;
            $phyloVal = $genus;
            push( @homologs, $homolog );
        }
    }
    return "" if nullPhyla($phyloVal);
    return ( $phyloVal, @homologs );
}

############################################################################
# nullPhyla
############################################################################
sub nullPhyla {
    my ($s) = @_;
    if ( $s eq "" || $s eq "unclassified" ) {
        return 1;
    } else {
        return 0;
    }
}

############################################################################
# getInvalidPhyloLevelVals - Get invalid phylo level values because
#   they only have one count.
############################################################################
sub getInvalidPhyloLevelVals {
    my ( $dbh, $invalidVals_href ) = @_;

    my %invalidVals;
    getInvalidPhyloVals( $dbh, "domain",   $invalidVals_href );
    getInvalidPhyloVals( $dbh, "phylum",   $invalidVals_href );
    getInvalidPhyloVals( $dbh, "ir_class", $invalidVals_href );
    getInvalidPhyloVals( $dbh, "ir_order", $invalidVals_href );
    getInvalidPhyloVals( $dbh, "family",   $invalidVals_href );
    getInvalidPhyloVals( $dbh, "genus",    $invalidVals_href );
}

sub getInvalidPhyloVals {
    my ( $dbh, $level, $invalidVals_href ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select tx.$level, count( tx.taxon_oid )
        from taxon
        where tx.domain not like 'Vir%' 
            and tx.domain not like 'Plasmid%'
            and tx.domain not like 'GFragment%'
            $rclause
            $imgClause
        group by tx.$level
        having count( tx.taxon_oid ) = 1
        order by tx.$level
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $levelVal, $cnt ) = $cur->fetchrow();
        last if !$levelVal;
        my $k = "$level:$levelVal";
        $invalidVals_href->{$k} = $cnt;
    }
    $cur->finish();
}

############################################################################
# checkPhyloLevel - Check one phylo level through all the hit's lineages.
#  If one has same query phyla, return false.  Else return true, with
#  the first/highest differing phyla.
############################################################################
sub checkPhyloLevel {
    my ( $lineages_aref, $colIdx, $query_phyloVal0, $outRec_href ) = @_;

    ## See that there are no hits that have the same as query lineage.
    my $count = 0;
    my $outPhyloVal;
    my $outRowIdx;
    for my $lineage_aref (@$lineages_aref) {
        $count++;
        my $rowIdx   = $count - 1;
        my $phyloVal = $lineage_aref->[$colIdx];
        webLog("[$rowIdx,$colIdx] phyloVal='$phyloVal' ($query_phyloVal0)\n");
        if (    $phyloVal eq $query_phyloVal0
             && !nullPhyla($phyloVal)
             && !nullPhyla($query_phyloVal0) )
        {
            webLog("   abort: match query='$query_phyloVal0'\n");
            return 0;
        }
        if (    $phyloVal ne $query_phyloVal0
             && !nullPhyla($phyloVal)
             && !nullPhyla($query_phyloVal0) )
        {
            if ( $outPhyloVal eq "" ) {
                webLog("   capture: not match query='$query_phyloVal0'\n");
                $outRowIdx   = $rowIdx;
                $outPhyloVal = $phyloVal;
            }
        }
    }
    return 0 if $outRowIdx eq "";
    $outRec_href->{outRowIdx} = $outRowIdx;
    $outRec_href->{phyloVal}  = $outPhyloVal;
    return 1;
}

############################################################################
# printAddQueryGeneCheckBox - Add checkbox for query gene.
############################################################################
sub printAddQueryGeneCheckBox { 
    my ($gene_oid, $taxon_oid, $data_type) = @_; 
    my $workspace_id = $gene_oid;
    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid"; 

    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
    $workspace_id = "$taxon_oid $data_type $gene_oid";
    $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail" .
        "&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid"; 
    }
    print "<p>\n"; 
    print "<input type='checkbox'  " 
    . "name='gene_oid' value='$workspace_id' checked />\n"; 
    my $link = alink( $url, $gene_oid ); 
    print "Add query gene $link<br/>\n"; 
    print "</p>\n"; 
} 




1;
