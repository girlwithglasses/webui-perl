############################################################################
# GeneCartStor - Gene cart persistent storage.
#  Record fields (tab delimited separator):
#     0: gene_oid
#     1. locus_tag
#     2: description
#     3: description original
#     4: amino acid sequence length
#     5: taxon_oid
#     6: org name
#     7: batch_id
#     8: scaffold_oid
#     9: scaffold_name
#    10: scaffold seq length
#    11: scaffold GC percent
#    12: scaffold read depth
#    --es 03/22/2007
#
# $Id: GeneCartStor.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package GeneCartStor;
my $section = "GeneCartStor";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use InnerTable;
use OracleUtil;
use QueryUtil;
use MerFsUtil;
use MetaUtil;
use GenomeListFilter;
use GeneTableConfiguration;
use GenerateArtemisFile;
use GenomeListJSON;
use WorkspaceUtil;
use HTML::Template;
use HtmlUtil;
use CartUtil;

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{cgi_tmp_dir};

#my $log_tmp_dir          = $env->{log_tmp_dir};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_lite             = $env->{img_lite};
my $verbose              = $env->{verbose};
my $show_myimg_login     = $env->{show_myimg_login};
my $user_restricted_site = $env->{user_restricted_site};
my $img_internal         = $env->{img_internal};
my $scaffold_cart        = $env->{scaffold_cart};
my $include_bbh_lite     = $env->{include_bbh_lite};
my $bbh_files_dir        = $env->{bbh_files_dir};
my $cog_base_url         = $env->{cog_base_url};
my $pfam_base_url        = $env->{pfam_base_url};
my $tigrfam_base_url     = $env->{tigrfam_base_url};
my $enzyme_base_url      = $env->{enzyme_base_url};
my $kegg_orthology_url   = $env->{kegg_orthology_url};
my $bbh_zfiles_dir       = $env->{bbh_zfiles_dir};
my $enable_genomelistJson = $env->{enable_genomelistJson};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $http                 = $env->{ http };
my $domain_name          = $env->{ domain_name };
my $main_cgi             = $env->{ main_cgi };
my $YUI                  = $env->{yui_dir_28};
my $enable_interpro = $env->{enable_interpro};

# tab panel redirect
my $tab_panel    = $env->{tab_panel};
my $content_list = $env->{content_list};

my $max_genome_selections = 1000;
my $max_gene_batch        = 900;
my $maxGeneCartGenes      = 1000;
my $maxProfileOccurIds    = 100;
if ( $env->{max_gene_cart_genes} ne "" ) {
    $maxGeneCartGenes = $env->{max_gene_cart_genes};
}

my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $dDelim = "===";
my $fDelim = "<<>>";

#old original cols saved
#my $origColIDs = "gene_oid,locus_tag,desc,desc_orig,aa_seq_length,taxon_oid,taxon_display_name,batch_id,scaffold_oid,scf_ext_accession,scaffold_name,scf_seq_length,scf_gc_percent,scf_read_depth,";
my $fixedColIDs = "gene_oid,locus_tag,desc,desc_orig,taxon_oid,taxon_display_name,batch_id,scaffold_oid,";

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $GENE_FOLDER = "gene";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {

    timeout( 60 * $merfs_timeout_mins );

    my $page = param("page");

    if ( $page eq "geneCart" ) {
        setSessionParam( "lastCart", "geneCart" );
        my $gc = new GeneCartStor();
        $gc->printGeneCartForm();
    } elsif ( $page eq "upload" ) {

        # this was for the new menu and tab system
        my $gc = new GeneCartStor();
        $gc->printTab2();
    } elsif ( $page eq "tools" ) {

        # this was for the new menu and tab system
        my $gc = new GeneCartStor();
        $gc->printTab3();
    } elsif ( paramMatch("deleteSelectedCartGenesNeigh") ne "" ) {

        # delete from Gene Cart Neighborhood page
        my $gc = new GeneCartStor();
        $gc->webRemoveGenesNeigh();
        $gc->printGeneCartForm();
    } elsif ( paramMatch("deleteSelectedCartGenes") ne "" ) {

        # delete gene
        my $gc = new GeneCartStor();
        $gc->webRemoveGenes();
        $gc->printGeneCartForm();
    } elsif ( paramMatch("addGenePageGeneToGeneCart") ne "" ) {
        my $gc = new GeneCartStor();
        $gc->webAddGenes();
    } elsif (    $page eq "showGeneCart"
              || paramMatch("addToGeneCart")      ne ""
              || paramMatch("deleteAllCartGenes") ne "" )
    {
        setSessionParam( "lastCart", "geneCart" );
        my $gc = new GeneCartStor();
        if ( paramMatch("addToGeneCart") ne "" ) {
            $gc->printGeneCartForm("add");
        } else {
            $gc->printGeneCartForm("");
        }

    } elsif ( paramMatch("uploadGeneCart") ne "" ) {
        setSessionParam( "lastCart", "geneCart" );
        my $gc = new GeneCartStor();
        $gc->printGeneCartForm("upload");
    } elsif ( paramMatch("setGeneOutputCol") ne "" ) {
        setSessionParam( "lastCart", "geneCart" );
        my $gc = new GeneCartStor();
        $gc->printGeneCartForm("configure");
    } elsif ( paramMatch("geneOccurProfiles") ne "" ) {
        require WorkspaceGeneSet;
        WorkspaceGeneSet::printPhyloOccurProfiles_otf();

        #printPhyloOccurProfiles();
    } elsif ( paramMatch("printUploadGeneCartForm") ne "" ) {
        printUploadGeneCartForm();
    } elsif ( paramMatch("addFunctionCart") ne "" ) {
        addFunctionCart();
    } else {
        my $gc = new GeneCartStor();
        $gc->printGeneCartForm();
    }
}

sub printValidationJS {
    print qq{
        <script language='JavaScript' type='text/javascript'>
        function validateSelection(num) {
            var startElement = document.getElementById("genecarttab1");
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var e = els[i];

                if (e.type == "checkbox" &&
                    e.name == "gene_oid" &&
                    e.checked == true) {
                    count++;
                }
            }

            if (count < num) {
                if (num == 1) {
                    alert("Please select some genes");
                } else {
                    alert("Please select at least "+num+" genes");
                }
                return false;
            }

            return true;
        }
        </script>
    };
}

# this is a bad name, but i got it from the tab layout
# its now the tools page to print from the menu
#
sub printTab3 {
    my ($self) = @_;

    setSessionParam( "lastCart", "geneCart" );
    my $recs = readCartFile();

    my $count = scalar( keys(%$recs) );
    if ( $count == 0 ) {
        print "<p>\n";
        print qq{
            You have 0 genes in cart. In order to compare genes
            you need to select / upload genes into the gene cart.};
        print "</p>\n";
        return;
    }

    print "<div id='genecarttab4'>";
    print "<h2>Chromosome Map</h2>";
    print "<p>You may select genes from the cart to view " . "against an the entire chromosome.</p>\n";

    my $name = "_section_GeneCartChrViewer_index";
    print submit(
                  -name    => $name,
                  -value   => "Chromosome Map",
                  -class   => "medbutton",
                  -onclick => "return validateSelection(1);"
    );
    printHint(
        qq{
        - Maps from maximum of three scaffolds can be drawn.<br/>
        - Selected genes from gene cart are projected on inner circles
          of the circular diagram.<br/>
        - Initially genes are assigned to circles based on their batch number.
      <br/>
        - User will be prompted in the next page to assign genes to
      different circles.<br/>
        }
    );
    print "</div>";    # end genecarttab4

    print "<div id='genecarttab5'>";
    print "<h2>Sequence Alignment</h2>";
    print "<p>You may select genes from the cart " . "for sequence alignment with Clustal.</p>";
    print "<p>\n";
    print "<input type='radio' name='alignment' value='amino' checked />\n";
    print "Protein<br/>\n";
    print "<input type='radio' name='alignment' value='nucleic' />\n";
    print "DNA\n";
    print nbsp(2);
    print "<input type='text' size='3' " . "name='align_up_stream' value='-0' />\n";
    print "bp upstream.\n";
    print nbsp(2);
    print "<input type='text' size='3' " . "name='align_down_stream' value='+0' />\n";
    print "bp downstream\n";
    print "<br/>\n";
    print "</p>\n";

    my $name = "_section_ClustalW_runClustalW";
    print submit(
                  -name    => $name,
                  -value   => "Do Alignment",
                  -class   => "smbutton",
                  -onclick => "return validateSelection(2);"
    );
    print "</div>";    # end genecarttab5

    print "<div id='genecarttab6'>";
    print "<h2>Gene Neighborhoods</h2>";
    print "<p>You may view the chromosomal neighborhood of each gene " . "selected in the gene cart.</p>";
    print "<p>\n";
    print "<input type='radio' name='alignGenes' value='1' checked />"
      . "5'-3' direction of each selected gene is left to right<br/>\n";
    print "<input type='radio' name='alignGenes' value='0' />"
      . "5'-3' direction of plus strand is always left to right, on top";
    print "<br/>\n";
    print "</p>\n";

    print hiddenVar( "cog_color", "yes" );
    my $name = "_section_GeneNeighborhood_selectedGeneNeighborhoods";
    print submit(
                  -name    => $name,
                  -value   => "Show Neighborhoods",
                  -class   => "smbutton",
                  -onclick => "return validateSelection(1);"
    );
    print "</div>";    # end genecarttab6

    #if ( $img_lite && !$include_bbh_lite ) {
    #    return;
    #}

    print "<div id='genecarttab7'>";
    print "<h2>Profile and Alignment Tools</h2>";

    printHint(   "- Hold down the control key (or command key in the case of Mac)"
               . " to select multiple genomes.<br/>\n"
               . "- Drag down list to select all genomes.<br/>\n"
               . "- More genome and gene selections result in slower query.\n" );
    print "<br/>";

    if ($enable_genomelistJson) {
        GenomeListJSON::printHiddenInputType();
        GenomeListJSON::printGenomeListJsonDiv('t:');
    } else {
        my $dbh = dbLogin();
        GenomeListFilter::appendGenomeListFilter( $dbh, '', 1, '', 'Yes', 'Yes' );
    }

    HtmlUtil::printMetaDataTypeChoice();

    WebUtil::printProfileBlastConstraints();

    print "<h2>Gene Profile</h2>";
    print "<p>\n";
    print "View selected protein coding genes against selected genomes ";
    print "using unidirectional sequence similarities.<br/>\n";
    print "Use the <font color='blue'><u>Genome Filter</u></font> above to "
      . "select 1 to $max_genome_selections genome(s).<br/>\n";
    print "</p>\n";

    my $name = "_section_GeneProfilerStor_showGeneCartProfile_s";

    if ($enable_genomelistJson) {
        GenomeListJSON::printMySubmitButton( "go1", $name, "View Genes vs. Genomes",
                                             '', 'GeneProfilerStor', 'showGeneCartProfile_s' );
        print nbsp(1);
        my $name = "_section_GeneProfilerStor_showGeneCartProfile_t";
        GenomeListJSON::printMySubmitButton( "go2", $name, "View Genomes vs. Genes",
                                             '', 'GeneProfilerStor', 'showGeneCartProfile_t' );
    } else {
        print submit(
                      -id    => "go1",
                      -name  => $name,
                      -value => "View Genes vs. Genomes",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        my $name = "_section_GeneProfilerStor_showGeneCartProfile_t";
        print submit(
                      -id    => "go2",
                      -name  => $name,
                      -value => "View Genomes vs. Genes",
                      -class => "medbutton"
        );
    }
    #print nbsp(1);
    #print "<input id='reset' type='button' name='clearSelections' " . "value='Reset' class='smbutton' />\n";

    print "<h2>Occurrence Profile</h2>";
    print "<p>\n";
    my $url  = "$main_cgi?section=TaxonList&page=taxonListAlpha";
    my $link = alink( $url, "Genome Browser" );

    #    print "Show phylogenetic occurrence profile for ";
    #    print "genomes selected using the $link <br/>\n";
    #    print "against currently selected genes.<br/>\n";
    print "Show phylogenetic occurrence profile for selected genes. Please select no more than $maxProfileOccurIds genes.<br/>\n";
    print "You can change the default E-value and percent identity cutoff above.<br/>";
    print "</p>\n";

    if ($enable_genomelistJson) {
        my $name = "_section_${section}_geneOccurProfiles";
        GenomeListJSON::printMySubmitButton( "", $name, "View Phylogenetic Occurrence Profiles",
                                             '', $section, 'geneOccurProfiles' );
    } else {
        my $name = "_section_${section}_geneOccurProfiles";
        print submit(
              -name    => $name,
              -value   => "View Phylogenetic Occurrence Profiles",
              -class   => "lgbutton",
              -onclick => "return validateSelection(1);"
        );
    }

    #not subject to genome filter selection
    print "<h2>Function Alignment</h2>";
    print "\n";
    print "<p>\n";
    print "List alignments of function prediction for selected genes (limit to COG, KOG and pfam).<br/>\n";
    if ( $include_metagenomes ) {
        print "Metagenome Genes are not supported.<br/>\n";
    }
    print "</p>\n";

    my $name = "_section_FunctionAlignment_showAlignmentForGene";
    print submit(
          -id      => "go",
          -name    => $name,
          -value   => "Function Alignment",
          -class   => "medbutton",
          -onclick => "return validateSelection(1);"
    );

    print "<br/>\n";
    print "</div>";    # end genecarttab7
}

sub printUploadSection {
    print "<h2>Upload Gene Cart</h2>";
    printUploadGeneCartFormContent('Yes');
}

# upload and export
#
sub printTab2 {
    my ($self) = @_;

    setSessionParam( "lastCart", "geneCart" );
    printUploadSection();

    print "<h2>Export Genes</h2>";
    GenerateArtemisFile::printDataExportHint($GENE_FOLDER);
    print "<p>\n";
    print "You may select genes from the cart to export " . "in one of the following export formats.\n";
    print "</p>\n";

    print "<p>\n";
    print "<input type='radio' name='exportType' value='amino' checked />\n";
    print "FASTA Amino Acid format<br/>\n";
    print "<input type='radio' name='exportType' value='nucleic' />\n";
    print "FASTA Nucleic Acid format\n";
    print nbsp(2);
    print "<input type='text' size='3' name='up_stream' value='-0' />\n";
    print "bp upstream\n";
    print nbsp(2);
    print "<input type='text' size='3' name='down_stream' value='+0' />\n";
    print "bp downstream\n";
    print "<br/>\n";

    my $recs  = readCartFile();
    my $count = scalar( keys(%$recs) );
    if ( $count == 0 ) {
        print "<p>You have 0 genes to export.</p>\n";
    } else {
        print "<input type='radio' name='exportType' value='excel' />\n";
        print "Gene information in tab-delimited format to Excel "
	    . "<b>(Gene Cart uploadable format)</b><br/>\n";
        print "</p>\n";

        ## enter email address
        GenerateArtemisFile::printEmailInputTable( '', $GENE_FOLDER );

        my $name = "exportGenes";
#        print submit(
#                      -name    => $name,
#                      -value   => "Show in Export Format",
#                      -class   => "medbutton",
#                      -onclick => "return validateSelection(1);"
#        );
        my $contact_oid = WebUtil::getContactOid();
        my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name", "return validateSelection(1);");
        print qq{
<input class='meddefbutton' name='$name' type="submit" value="Show in Export Format" $str>
        };


        WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
    }

}

############################################################################
# new - New instance.
############################################################################
sub new {
    my ( $myType, $baseUrl ) = @_;

    my $self = {};
    bless( $self, $myType );
    return $self;
}

############################################################################
# webConfigureGenes - Configure gene cart display.
############################################################################
sub webConfigureGenes {
    my ( $self,
         $outColClause,   $taxonJoinClause,    $scfJoinClause,      $ssJoinClause,
         $cogQueryClause, $pfamQueryClause,    $tigrfamQueryClause, $ecQueryClause,
         $koQueryClause,  $imgTermQueryClause, $projectMetadataCols_ref, $outputCol_ref
      )
      = @_;

    my $recs      = readCartFile();
    my @gene_oids = keys(%$recs);

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my $dbh           = dbLogin();
    my %goid2BatchIds = {};
    my $colIDs        = '';

    if ( scalar(@dbOids) > 0 ) {
        for my $gene_oid (@dbOids) {
            my $rec    = $recs->{$gene_oid};
            my @fields = split( /\t/, $rec );
            $goid2BatchIds{$gene_oid} = $fields[6]; #6 for batch_id
        }
        my $colIDsNew = flushGeneBatch(
            $recs, $dbh, \@dbOids, \%goid2BatchIds, '',
            $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
            $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
            $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
            $projectMetadataCols_ref, $outputCol_ref
        );
        if ($colIDsNew) {
            $colIDs = $colIDsNew;
        }
    }

    if ( scalar(@metaOids) > 0 ) {
        for my $mOid (@metaOids) {
            my $rec    = $recs->{$mOid};
            my @fields = split( /\t/, $rec );
            $goid2BatchIds{$mOid} = $fields[6];     #6 for batch_id
        }
        my $colIDsNew = flushMetaGeneBatch(
            $recs, $dbh, \@metaOids, \%goid2BatchIds, '',
            $projectMetadataCols_ref, $outputCol_ref
        );
        if ($colIDsNew) {
            $colIDs = $colIDsNew;
        }
    }

    writeCartFile($recs);
    GeneTableConfiguration::writeColIdFile($colIDs, "geneCart");
}

############################################################################
# webAddGenes - Load gene cart from selections.
############################################################################
sub webAddGenes {
    my ( $self,
         $outColClause,   $taxonJoinClause,    $scfJoinClause,      $ssJoinClause,
         $cogQueryClause, $pfamQueryClause,    $tigrfamQueryClause, $ecQueryClause,
         $koQueryClause,  $imgTermQueryClause, $projectMetadataCols_ref, $outputCol_ref
      )
      = @_;
    my @gene_oids = param("gene_oid");
    #print "webAddGenes() gene_oids: @gene_oids<br/>\n";
    $self->addGeneBatch( \@gene_oids,
         $outColClause,   $taxonJoinClause,    $scfJoinClause,      $ssJoinClause,
         $cogQueryClause, $pfamQueryClause,    $tigrfamQueryClause, $ecQueryClause,
         $koQueryClause,  $imgTermQueryClause, $projectMetadataCols_ref, $outputCol_ref
    );
}

############################################################################
# addGenes
############################################################################
sub addGenes {
    my ( $self, $geneStr ) = @_;
    my @gene_oids = split( ',', $geneStr );
    $self->addGeneBatch( \@gene_oids );
}

############################################################################
# addGeneBatch - Add genes in a batch.
# $working - lots of genes to add print working messages
############################################################################
sub addGeneBatch {
    my (
         $self,           $gene_oids_ref,
         $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
         $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
         $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
         $projectMetadataCols_ref, $outputCol_ref, $workingDivNotNeeded
      )
      = @_;

    if (    $outColClause eq ''
         && $taxonJoinClause    eq ''
         && $scfJoinClause      eq ''
         && $ssJoinClause       eq ''
         && $cogQueryClause     eq ''
         && $pfamQueryClause    eq ''
         && $tigrfamQueryClause eq ''
         && $ecQueryClause      eq ''
         && $koQueryClause      eq ''
         && $imgTermQueryClause eq '' )
    {
	    my @rest;
        (
           $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
           $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
           $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
           $projectMetadataCols_ref, $outputCol_ref,  @rest
          )
          = GeneTableConfiguration::getOutputColClauses($fixedColIDs, "geneCart");
    }

    my $colIDs = '';

    my $recs = readCartFile();
    my $recsNum = scalar(keys %$recs);
    #print "addGeneBatch() recsNum=$recsNum<br/>\n";

    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {
        my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@$gene_oids_ref);
        my @dbOids   = @$dbOids_ref;
        my @metaOids = @$metaOids_ref;

        my $dbh      = dbLogin();
        my $batch_id = getNextBatchId("gene");

        if ( scalar(@dbOids) > 0 ) {
            #not working using QueryUtil::fetchValidGeneOids
            #@dbOids = QueryUtil::fetchValidGeneOids( $dbh, @dbOids );
            my $colIDsNew = flushGeneBatch
            ( $recs, $dbh,     \@dbOids, '', $batch_id,
              $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
              $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
              $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
              $projectMetadataCols_ref, $outputCol_ref
            );

            if ($colIDsNew) {
                $colIDs = $colIDsNew;
            }
        }

        if ( scalar(@metaOids) > 0 ) {
            my @metaOidsValid = ();
            my %taxon_oid_hash = MerFsUtil::fetchValidMetaTaxonOidHash( $dbh, @metaOids );
            for my $mOid (@metaOids) {
                my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $mOid );
                if ( !exists( $taxon_oid_hash{$taxon_oid} ) ) {
                    next;
                }
                push( @metaOidsValid, $mOid );
            }
            if ( scalar(@metaOidsValid) > 0 ) {
                my $colIDsNew = flushMetaGeneBatch
            ( $recs, $dbh, \@metaOidsValid, '', $batch_id,
              $projectMetadataCols_ref, $outputCol_ref, $workingDivNotNeeded );
                if ($colIDsNew) {
                    $colIDs = $colIDsNew;
                }
            }
        }
    }

    writeCartFile($recs);
    GeneTableConfiguration::writeColIdFile($colIDs, "geneCart");
}

############################################################################
# flushGeneBatch  - Flush one batch.
############################################################################
sub flushGeneBatch {
    my (
         $recs, $dbh, $batch_gene_oids_ref, $goid2BatchIds_ref, $batch_id_new,
         $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
         $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
         $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
         $projectMetadataCols_ref, $outputCol_ref
      )
      = @_;

    my $recsNum = scalar(keys %$recs);
    #print "flushGeneBatch() 0 recsNum=$recsNum<br/>\n";
    if ( $recsNum && $recsNum >= CartUtil::getMaxDisplayNum() ) {
        return '';
    }

    if ( ! $batch_gene_oids_ref || scalar(@$batch_gene_oids_ref) == 0 ) {
        return '';
    }

    webLog "flushGeneBatch() " . currDateTime() . "\n" if $verbose >= 1;

    my $gidInClause = OracleUtil::getIdClause( $dbh, 'gtt_num_id', '', $batch_gene_oids_ref );

    my $gene2cogs_href = GeneTableConfiguration::getGene2Cog
    	($dbh, $batch_gene_oids_ref, $cogQueryClause, $gidInClause);

    my $gene2pfams_href = GeneTableConfiguration::getGene2Pfam
    	($dbh, $batch_gene_oids_ref, $pfamQueryClause, $gidInClause);

    my $gene2tigrfams_href = GeneTableConfiguration::getGene2Tigrfam
    	($dbh, $batch_gene_oids_ref, $tigrfamQueryClause, $gidInClause);

    my $gene2ecs_href = GeneTableConfiguration::getGene2Ec
    	($dbh, $batch_gene_oids_ref, $ecQueryClause, $gidInClause);

    my $gene2kos_href = GeneTableConfiguration::getGene2Ko
    	($dbh, $batch_gene_oids_ref, $koQueryClause, $gidInClause);

    my $gene2imgTerms_href = GeneTableConfiguration::getGene2Term
    	($dbh, $batch_gene_oids_ref, $imgTermQueryClause, $gidInClause);

    my ($gene2taxonInfo_href, $taxon2metaInfo_href)
        = GeneTableConfiguration::getGene2TaxonInfo($dbh, $batch_gene_oids_ref, $gidInClause);

    my $taxon_metadata_href;
    if ( $projectMetadataCols_ref && scalar(@$projectMetadataCols_ref) > 0 ) {
        $taxon_metadata_href = GeneTableConfiguration::getTaxon2projectMetadataInfo($taxon2metaInfo_href);
        $gidInClause = OracleUtil::getIdClause( $dbh, 'gtt_num_id', '', $batch_gene_oids_ref );
    }

    webLog "gene query " . currDateTime() . "\n" if $verbose >= 1;

    my $scf_ext_accession_idx = -1;
    my @outCols               = ();
    if ( $outputCol_ref ne '' ) {
        @outCols = @$outputCol_ref;
        for ( my $i = 0 ; $i < scalar(@outCols) ; $i++ ) {
            if ( $outCols[$i] eq 'ext_accession' ) {
                $scf_ext_accession_idx = $i;
                last;
            }
        }
    }

    my %scaffold2Bin;
    if ( $scf_ext_accession_idx >= 0 ) {
        my $sql = qq{
            select distinct bs.scaffold, b.bin_oid, b.display_name
            from gene g, bin_scaffolds bs, bin b
            where g.gene_oid $gidInClause
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            order by bs.scaffold, b.display_name
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $scaffold, $bin_oid, $bin_display_name ) = $cur->fetchrow();
            last if !$scaffold;
            $scaffold2Bin{$scaffold} .= " $bin_display_name;";
        }
        $cur->finish();
    }

    my $sql = qq{
        select distinct g.gene_oid, g.locus_type, g.locus_tag,
            g.gene_symbol, g.gene_display_name, g.scaffold
            $outColClause
        from gene g
        $taxonJoinClause
        $scfJoinClause
        $ssJoinClause
        where g.gene_oid $gidInClause
        order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my (
             $gene_oid, $locus_type, $locus_tag, $gene_symbol, $gene_display_name,
             $scaffold, @outColVals
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $batch_id = $batch_id_new;
        if ( $batch_id eq '' && $goid2BatchIds_ref ne '' ) {
            $batch_id = $goid2BatchIds_ref->{$gene_oid};
        }

        my $desc = $gene_display_name;
        $desc = "($locus_type $gene_symbol)" if $locus_type =~ /RNA/;
        my $desc_orig = $desc;

        my $r = "$gene_oid\t";
        $r .= "$locus_tag\t";
        $r .= "$desc\t";
        $r .= "$desc_orig\t";

        my $taxon_info = $gene2taxonInfo_href->{$gene_oid};
        my ($taxon_oid, $taxon_display_name) = split(/\t/, $taxon_info);
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";

        $r .= "$batch_id\t";
        $r .= "$scaffold\t";

        for ( my $j = 0 ; $j < scalar(@outColVals) ; $j++ ) {
            if ( $scf_ext_accession_idx >= 0 && $scf_ext_accession_idx == $j ) {
                my $scf_ext_accession = $outColVals[$j];
                my $bin_display_names = $scaffold2Bin{$scaffold};
                chop $bin_display_names;
                $scf_ext_accession .= " (bin(s):$bin_display_names)"
                  if $bin_display_names ne "";
                $r .= "$scf_ext_accession\t";
            } else {
                $r .= "$outColVals[$j]\t";
            }
        }

        if ($cogQueryClause) {
            my $val = $gene2cogs_href->{$gene_oid};
            $r .= "$val\t\t";
        }

        if ($pfamQueryClause) {
            my $val = $gene2pfams_href->{$gene_oid};
            $r .= "$val\t\t";
        }

        if ($tigrfamQueryClause) {
            my $val = $gene2tigrfams_href->{$gene_oid};
            $r .= "$val\t\t";
        }

        if ($ecQueryClause) {
            my $val = $gene2ecs_href->{$gene_oid};
            $r .= "$val\t\t";
        }

        if ($koQueryClause) {
            my $val = $gene2kos_href->{$gene_oid};
            $r .= "$val\t\t\t";
        }

        if ($imgTermQueryClause) {
            my $val = $gene2imgTerms_href->{$gene_oid};
            $r .= "$val\t";
        }

        #project metadata
        if ( $projectMetadataCols_ref && scalar(@$projectMetadataCols_ref) > 0 ) {
            my $sub_href = $taxon_metadata_href->{$taxon_oid};
            foreach my $col (@$projectMetadataCols_ref) {
                my $val = $sub_href->{$col};
                $val = GenomeList::cellValueEscape($val);
                $r .= "$val\t";
            }
        }

        $recs->{$gene_oid} = $r;
        $recsNum = scalar(keys %$recs);
        if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
            last;
        }
    }

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gidInClause =~ /gtt_num_id/i );
    webLog "gene query done " . currDateTime() . "\n" if $verbose >= 1;
    #print "flushGeneBatch() 1 recsNum=$recsNum<br/>\n";

    my $colIDs = $fixedColIDs;
    foreach my $col (@outCols) {
        $colIDs .= "$col,";
    }

    return $colIDs;
}

############################################################################
# flushMetaGeneBatch  - Flush one batch.
############################################################################
sub flushMetaGeneBatch {
    my ( $recs, $dbh, $meta_gene_oids_ref, $goid2BatchIds_ref, $batch_id_new,
        $projectMetadataCols_ref, $outputCol_ref, $workingDivNotNeeded ) = @_;

    my $recsNum = scalar(keys %$recs);
    #print "flushMetaGeneBatch() 0 recsNum=$recsNum<br/>\n";
    if ( $recsNum && $recsNum >= CartUtil::getMaxDisplayNum() ) {
        return '';
    }

    if ( scalar(@$meta_gene_oids_ref) == 0 ) {
        return '';
    }

    #test use
    #print "GeneCartStor::flushMetaGeneBatch() meta_gene_oids_ref: @$meta_gene_oids_ref<br/>\n";
    #print "GeneCartStor::flushMetaGeneBatch() outputCol_ref: @$outputCol_ref<br/>\n";

    #print "GeneCartStor::flushMetaGeneBatch() workingDivNotNeeded: $workingDivNotNeeded<br/>\n";
    if ( !$workingDivNotNeeded ) {
        printStartWorkingDiv();
    }

    #webLog "GeneCartStor::flushMetaGeneBatch() start " . currDateTime() . "\n" if $verbose >= 1;
    #print "GeneCartStor::flushMetaGeneBatch() 0 " . currDateTime() . "<br/>\n";

    my %genes_h;
    my %taxon_oid_h;

    #my $k = 0;
    for my $workspace_id (@$meta_gene_oids_ref) {
        $genes_h{$workspace_id} = 1;

        my @vals = split( / /, $workspace_id );
        if ( scalar(@vals) >= 3 ) {
            $taxon_oid_h{ $vals[0] } = 1;

            #$k++;
            #if ( $k > $maxGeneListResults ) {
            #   last;
            #}
        }
    }
    my @taxonOids = keys(%taxon_oid_h);

    my $taxon_name_href;
    my $taxon_genome_type_href;
    my $taxon_metaInfo_href;
    if ( scalar(@taxonOids) > 0 ) {
        ( $taxon_name_href, $taxon_genome_type_href, $taxon_metaInfo_href ) =
          QueryUtil::fetchTaxonMetaInfo( $dbh, \@taxonOids );
    }
    #print "flushMetaGeneBatch() taxon2metaInfo: <br/>\n";
    #print Dumper($taxon_metaInfo_href);
    #print "<br/>\n";

    my $get_taxon_public = 0;
    my $get_taxon_oid = 0;
    my $get_gene_info    = 0;
    my $get_gene_faa     = 0;
    my $get_scaf_info    = 0;
    my $get_gene_cog     = 0;
    my $get_gene_pfam    = 0;
    my $get_gene_tigrfam = 0;
    my $get_gene_ec      = 0;
    my $get_gene_ko      = 0;

    my @outCols;
    if ( $outputCol_ref ) {
        @outCols = @$outputCol_ref;
        foreach my $outCol ( @outCols ) {
            if ( $outCol eq 'is_public' ) {
                $get_taxon_public = 1;
            } elsif ( $outCol eq 'taxon_oid' ) {
                $get_taxon_oid = 1;
            } elsif (    $outCol eq 'locus_type'
                      || $outCol eq '$start_coord'
                      || $outCol eq '$end_coord'
                      || $outCol eq '$strand'
                      || $outCol eq 'dna_seq_length'
                      || $outCol eq 'scaffold_oid' )
            {
                $get_gene_info = 1;
            } elsif ( $outCol eq 'aa_seq_length' ) {
                $get_gene_faa = 1;
            } elsif (    $outCol eq 'seq_length'
                      || $outCol eq 'gc_percent'
                      || $outCol eq 'read_depth' )
            {
                $get_gene_info = 1;
                $get_scaf_info = 1;
            } elsif ( $outCol =~ /cog_id/i ) {
                $get_gene_cog = 1;
            } elsif ( $outCol =~ /pfam_id/i ) {
                $get_gene_pfam = 1;
            } elsif ( $outCol =~ /tigrfam_id/i ) {
                $get_gene_tigrfam = 1;
            } elsif ( $outCol =~ /ec_number/i ) {
                $get_gene_ec = 1;
            } elsif ( $outCol =~ /ko_id/i ) {
                $get_gene_ko = 1;
            }
        }
    }
    #print "GeneCartStor::flushMetaGeneBatch() outCols=@outCols<br/>\n";
    #print "GeneCartStor::flushMetaGeneBatch() outCols size=" . @outCols . "<br/>\n";

    my %taxon_public_h;
    if ( $get_taxon_public && scalar(@taxonOids) > 0 ) {
        %taxon_public_h = QueryUtil::fetchTaxonOid2PublicHash( $dbh, \@taxonOids );
    }

    my %taxon_genes = MetaUtil::getOrganizedTaxonGenes(@$meta_gene_oids_ref);

    my %gene_name_h;
    MetaUtil::getAllMetaGeneNames( \%genes_h, $meta_gene_oids_ref, \%gene_name_h, \%taxon_genes, 1 );

    #print "GeneCartStor::flushMetaGeneBatch() 0b " . currDateTime() . "<br/>\n";

    my %gene_info_h;
    my %scaf_id_h;
    if ( $get_gene_info && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneInfo( \%genes_h, $meta_gene_oids_ref, \%gene_info_h, \%scaf_id_h, \%taxon_genes, 1, 0, 1 );
        #print "GeneCartStor::flushMetaGeneBatch() getAllMetaGeneInfo() called " . currDateTime() . "<br/>\n";
        #print Dumper(\%scaf_id_h);
    }

    # gene-faa
    my %gene_faa_h;
    if ( $get_gene_faa && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFaa( \%genes_h, $meta_gene_oids_ref, \%gene_faa_h, \%taxon_genes, 1 );
    }

    my %scaffold_h;
    if ( $get_scaf_info && scalar( keys %scaf_id_h ) > 0 ) {
        MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h );
        #print Dumper(\%scaffold_h);
        #print "GeneCartStor::flushMetaGeneBatch() getAllScaffoldInfo() called " . currDateTime() . "<br/>\n";
    }

    # gene-cog
    my %gene_cog_h;
    my %cog_name_h;
    if ( $get_gene_cog && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'cog', $meta_gene_oids_ref, \%genes_h, \%gene_cog_h );
        #Todo: should use gene_cog_h results
        QueryUtil::fetchAllCogIdNameHash( $dbh, \%cog_name_h );
        #print Dumper(\%gene_cog_h);
        #print "<br/>\n";
        #print "GeneCartStor::flushMetaGeneBatch() getAllMetaGeneFuncs() called " . currDateTime() . "<br/>\n";
    }

    # gene-pfam
    my %gene_pfam_h;
    my %pfam_name_h;
    if ( $get_gene_pfam && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'pfam', $meta_gene_oids_ref, \%genes_h, \%gene_pfam_h );
        #Todo: should use gene_pfam_h results
        QueryUtil::fetchAllPfamIdNameHash( $dbh, \%pfam_name_h );
    }

    # gene-tigrfam
    my %gene_tigrfam_h;
    my %tigrfam_name_h;
    if ( $get_gene_tigrfam && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'tigr', $meta_gene_oids_ref, \%genes_h, \%gene_tigrfam_h );
        #print "flushMetaGeneBatch() gene_tigrfam_h:<br/>\n";
        #print Dumper(\%gene_tigrfam_h);
        #print "<br/>\n";
        #Todo: should use gene_tigrfam_h results
        QueryUtil::fetchAllTigrfamIdNameHash( $dbh, \%tigrfam_name_h );
    }

    # gene-ec
    my %gene_ec_h;
    my %ec_name_h;
    if ( $get_gene_ec && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'ec', $meta_gene_oids_ref, \%genes_h, \%gene_ec_h );
        #print "flushMetaGeneBatch() gene_ec_h:<br/>\n";
        #print Dumper(\%gene_ec_h);
        #print "<br/>\n";
        #Todo: should use gene_ec_h results
        QueryUtil::fetchAllEnzymeNumberNameHash( $dbh, \%ec_name_h );
    }

    # gene-ko
    my %gene_ko_h;
    my %ko_name_h;
    my %ko_def_h;
    if ( $get_gene_ko && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'ko', $meta_gene_oids_ref, \%genes_h, \%gene_ko_h );
        #Todo: should use gene_ko_h results
        QueryUtil::fetchAllKoIdNameDefHash( $dbh, \%ko_name_h, \%ko_def_h );
    }

    my $taxon_metadata_href;
    if ( $projectMetadataCols_ref && scalar(@$projectMetadataCols_ref) > 0 ) {
        $taxon_metadata_href = GeneTableConfiguration::getTaxon2projectMetadataInfo($taxon_metaInfo_href);
    }
    #print "flushMetaGeneBatch() taxon_metadata_href: <br/>\n";
    #print Dumper($taxon_metadata_href);
    #print "<br/>\n";

    #print "GeneCartStor::flushMetaGeneBatch 2 " . currDateTime() . "<br/>\n";

    my $trunc      = 0;
    my $gene_count = 0;
    for my $workspace_id (@$meta_gene_oids_ref) {
        my $batch_id = $batch_id_new;
        if ( $batch_id eq '' && $goid2BatchIds_ref ne '' ) {
            $batch_id = $goid2BatchIds_ref->{$workspace_id};
        }

        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );
        if ( !exists( $taxon_name_href->{$taxon_oid} ) ) {

            #$taxon_oid not in hash, probably due to permission
            webLog("GeneCartStor flushMetaGeneBatch:: $taxon_oid not retrieved from database, probably due to permission.");
            next;
        }

        my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 );
        if ( exists( $gene_info_h{$workspace_id} ) ) {
            ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 )
              = split( /\t/, $gene_info_h{$workspace_id} );
        } else {
            $locus_tag = $gene_oid;
        }

        if ( !$taxon_oid && $tid2 ) {
            $taxon_oid = $tid2;
            if ( !exists( $taxon_name_href->{$taxon_oid} ) ) {
                my $taxon_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );

                # save taxon display name to prevent repeat retrieving
                $taxon_name_href->{$taxon_oid} = $taxon_name;
            }
        }

        # taxon
        my $taxon_display_name = $taxon_name_href->{$taxon_oid};
        my $genome_type = $taxon_genome_type_href->{$taxon_oid};
        $taxon_display_name .= " (*)"
          if ( $genome_type eq "metagenome" );

        if ( $gene_name_h{$workspace_id} ) {
            $gene_display_name = $gene_name_h{$workspace_id};
        }
        if ( !$gene_display_name ) {
            $gene_display_name = 'hypothetical protein';
        }
        my $desc      = $gene_display_name;
        my $desc_orig = $desc;

        # scaffold
        my $scaf_len;
        my $scaf_gc;
        my $scaf_gene_cnt;
        my $scaf_depth;
        if ( $data_type eq 'assembled' && $scaffold_oid && scalar( keys %scaffold_h ) > 0 ) {
            my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
            ( $scaf_len, $scaf_gc, $scaf_gene_cnt, $scaf_depth ) = split( /\t/, $scaffold_h{$ws_scaf_id} );
            if ( !$scaf_depth ) {
                $scaf_depth = 1;
            }
            $scaf_gc = sprintf( "%.2f", $scaf_gc );
        }

        my $r = "$workspace_id\t";
        $r .= "$locus_tag\t";
        $r .= "$desc\t";
        $r .= "$desc_orig\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$batch_id\t";
        $r .= "$scaffold_oid\t";

        foreach my $outCol ( @outCols ) {
            #print "flushMetaGeneBatch() outCol=$outCol<br/>\n";
            if ( $outCol eq 'dna_seq_length' ) {
                my $dna_seq_length = $end_coord - $start_coord + 1;
                $r .= "$dna_seq_length\t";
            } elsif ( $outCol eq 'aa_seq_length' ) {
                #takes too long for getGeneFaa(), get Kosta's permission for the division in metagenome
                #my $aa_seq_length = $dna_seq_length / 3;
                my $faa           = $gene_faa_h{$workspace_id};
                my $aa_seq_length = length($faa);
                $r .= "$aa_seq_length\t";
            } elsif ( $outCol eq 'start_coord' ) {
                $r .= "$start_coord\t";
            } elsif ( $outCol eq 'end_coord' ) {
                $r .= "$end_coord\t";
            } elsif ( $outCol eq 'strand' ) {
                $r .= "$strand\t";
            } elsif ( $outCol eq 'locus_type' ) {
                $r .= "$locus_type\t";
            } elsif ( $outCol eq 'is_public' ) {
                my $is_public = $taxon_public_h{$taxon_oid};
                $r .= "$is_public\t";
            } elsif ( $outCol eq 'taxon_oid' ) {
                $r .= "$taxon_oid\t";
            } elsif ( $outCol eq 'scaffold_oid' ) {
                $r .= "$scaffold_oid\t";
            } elsif ( $outCol eq 'scaffold_name' ) {
                $r .= "$scaffold_oid\t";
            } elsif ( $outCol eq 'seq_length' ) {
                $r .= "$scaf_len\t";
            } elsif ( $outCol eq 'gc_percent' ) {
                $r .= "$scaf_gc\t";
            } elsif ( $outCol eq 'read_depth' ) {
                $r .= "$scaf_depth\t";
            } elsif ( $outCol =~ /cog_id/i ) {
                my @cog_recs;
                my $cogs = $gene_cog_h{$workspace_id};
                if ($cogs) {
                    @cog_recs = split( /\t/, $cogs );
                }

                my $cog_all;
                for my $cog_id (@cog_recs) {
                    my $cog_name = $cog_name_h{$cog_id};
                    if ($cog_all) {
                        $cog_all .= "$fDelim$r";
                    }
                    $cog_all = $cog_id . $dDelim . $cog_name;
                }
                $r .= "$cog_all\t\t";

            } elsif ( $outCol =~ /pfam_id/i ) {
                my @pfam_recs;
                my $pfams = $gene_pfam_h{$workspace_id};
                if ($pfams) {
                    @pfam_recs = split( /\t/, $pfams );
                }

                my $pfam_all;
                for my $pfam_id (@pfam_recs) {
                    my $pfam_name = $pfam_name_h{$pfam_id};
                    if ($pfam_all) {
                        $pfam_all .= "$fDelim$r";
                    }
                    $pfam_all = $pfam_id . $dDelim . $pfam_name;
                }
                $r .= "$pfam_all\t\t";

            } elsif ( $outCol =~ /tigrfam_id/i ) {
                my @tigrfam_recs;
                my $tigrfams = $gene_tigrfam_h{$workspace_id};
                if ($tigrfams) {
                    @tigrfam_recs = split( /\t/, $tigrfams );
                }

                my $tigrfam_all;
                for my $tigrfam_id (@tigrfam_recs) {
                    my $tigrfam_name = $tigrfam_name_h{$tigrfam_id};
                    if ($tigrfam_all) {
                        $tigrfam_all .= "$fDelim$r";
                    }
                    $tigrfam_all = $tigrfam_id . $dDelim . $tigrfam_name;
                }
                $r .= "$tigrfam_all\t\t";

            } elsif ( $outCol =~ /ec_number/i ) {
                my @ec_recs;
                my $ecs = $gene_ec_h{$workspace_id};
                if ($ecs) {
                    @ec_recs = split( /\t/, $ecs );
                }

                my $ec_all;
                for my $ec_id (@ec_recs) {
                    my $ec_name = $ec_name_h{$ec_id};
                    if ($ec_all) {
                        $ec_all .= "$fDelim$r";
                    }
                    $ec_all = $ec_id . $dDelim . $ec_name;
                }
                $r .= "$ec_all\t\t";

            } elsif ( $outCol =~ /ko_id/i ) {
                my @ko_recs;
                my $kos = $gene_ko_h{$workspace_id};
                if ($kos) {
                    @ko_recs = split( /\t/, $kos );
                }

                my $ko_all;
                for my $ko_id (@ko_recs) {
                    my $ko_name = $ko_name_h{$ko_id};
                    my $ko_def  = $ko_def_h{$ko_id};
                    if ($ko_all) {
                        $ko_all .= "$fDelim$r";
                    }
                    $ko_all = $ko_id . $dDelim . $ko_name . $dDelim . $ko_def;
                }
                $r .= "$ko_all\t\t\t";
            } elsif ( $projectMetadataCols_ref
                && scalar(@$projectMetadataCols_ref) > 0
                && GenomeList::isProjectMetadataAttr($outCol) ) {
                #to be applied later, ProjectMetadataAttr must be listed as last group
                last;
            } else {
                $r .= "\t";
            }
        }

        #project metadata
        if ( $projectMetadataCols_ref && scalar(@$projectMetadataCols_ref) > 0 ) {
            my $sub_href = $taxon_metadata_href->{$taxon_oid};
            foreach my $col (@$projectMetadataCols_ref) {
                my $val = $sub_href->{$col};
                $val = GenomeList::cellValueEscape($val);
                $r .= "$val\t";
            }
        }

        $recs->{$workspace_id} = $r;
        #print "flushMetaGeneBatch() r: $r<br/>\n";
        #my @splitColVals  = split( /\t/, $r );
        #print "flushMetaGeneBatch() splitColVals size: " . scalar(@splitColVals) . "<br/>\n";
        #print "flushMetaGeneBatch() splitColVals: @splitColVals<br/>\n";
        $recsNum = scalar(keys %$recs);
        if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
            last;
        }
    }

    #test use
    #foreach my $key (keys %{$recs}) {
    #    my $rec = $recs -> {$key};
    #    print "flushMetaGeneBatch 1 record for $key:<br/>\n$rec<br/>\n";
    #}

    if ( !$workingDivNotNeeded ) {
        printEndWorkingDiv();
    }

    #webLog "GeneCartStor::flushMetaGeneBatch done " . currDateTime() . "\n" if $verbose >= 1;
    #print "GeneCartStor::flushMetaGeneBatch 3 " . currDateTime() . "<br/>\n";
    #print "flushMetaGeneBatch() 1 recsNum=$recsNum<br/>\n";

    my $colIDs = $fixedColIDs;
    foreach my $col (@outCols) {
        $colIDs .= "$col,";
    }

    return $colIDs;
}

############################################################################
# webRemoveGenes - Remove genes from web selections.
############################################################################
sub webRemoveGenes {
    my ($self) = @_;

    my @gene_oids = param("gene_oid");
    if ( scalar(@gene_oids) == 0 ) {
        webError("No genes have been selected.");
        return;
    }

    removeGenes(@gene_oids);
}

sub removeGenes {
    my (@oids) = @_;

    my $cnt_left = 0;
    $cnt_left = removeFromFile( getSelectedFile(), @oids );
    $cnt_left = removeFromFile( getStateFile(),    @oids );

    if ( $cnt_left == 0 ) {
        wunlink( getColIdFile() );
    }
}

sub webRemoveGenesNeigh {
    my ($self) = @_;

    my @gene_oids          = param("gene_oid_neigh");
    my $gene_oid_neigh_str = param("gene_oid_neigh_str");
    my @atmp               = split( /,/, $gene_oid_neigh_str );
    push( @gene_oids, @atmp );

    removeGenes(@gene_oids);
}

############################################################################
# restoreOrigDesc - Restore backup descriptions for gene_oid's.
############################################################################
sub restoreOrigDesc {
    my ( $self, $geneOids_ref ) = @_;

    my %h    = WebUtil::array2Hash(@$geneOids_ref);
    my $recs = readCartFile();
    my @keys = sort( keys(%$recs) );
    for my $k (@keys) {
        my $r0 = $recs->{$k};
        my ( $gene_oid, $locus_tag, $desc, $desc_orig, $taxon_oid, $taxon_display_name, $scaffold, @colVals ) =
          split( /\t/, $r0 );
        next if $h{$gene_oid} eq "";
        $desc = $desc_orig;
        my $r = "$gene_oid\t";
        $r .= "$locus_tag\t";
        $r .= "$desc\t";
        $r .= "$desc_orig\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$scaffold\t";

        for ( my $j = 0 ; $j < scalar(@colVals) ; $j++ ) {
            $r .= "$colVals[$j]\t";
        }
        $recs->{$gene_oid} = $r;
    }
    writeCartFile($recs);
}

############################################################################
# setNewDesc - Set new description from MyIMG update.
############################################################################
sub setNewDesc {
    my ( $self, $geneOids_ref, $newDesc ) = @_;

    my %h    = WebUtil::array2Hash(@$geneOids_ref);
    my $recs = readCartFile();
    my @keys = sort( keys(%$recs) );
    for my $k (@keys) {
        my $r0 = $recs->{$k};
        my ( $gene_oid, $locus_tag, $desc, $desc_orig, $taxon_oid, $taxon_display_name, $scaffold, @colVals ) =
          split( /\t/, $r0 );
        next if $h{$gene_oid} eq "";
        $desc = $newDesc;
        my $r = "$gene_oid\t";
        $r .= "$locus_tag\t";
        $r .= "$desc\t";
        $r .= "$desc_orig\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$scaffold\t";

        for ( my $j = 0 ; $j < scalar(@colVals) ; $j++ ) {
            $r .= "$colVals[$j]\t";
        }
        $recs->{$gene_oid} = $r;
    }
    writeCartFile($recs);
}

#
# get hash of gene oids => data line
#
sub getGeneOids {
    my ($self) = @_;
    my $recs = readCartFile();

    #my @gene_oids = keys(%$recs);
    return $recs;    #\@gene_oids;
}

sub getDbGeneOids {
    my ($self) = @_;

    my $recs      = readCartFile();
    my @gene_oids = keys(%$recs);
    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);

    return @$dbOids_ref;
}

############################################################################
# prinGeneCartForm - Print gene cart form with list of genes and operations
#  that can be done on them.
############################################################################
sub printGeneCartForm {
    my ( $self, $load, $needGenomeJson ) = @_;

    # link is from the gene tools page - ken 2008-06-12
    # param value is: geneTool
    my $from = param("from");

    my $geneStr = param("genes");
    if ( $geneStr ne "" ) {
        $self->addGenes($geneStr);
    }

    if (    $load eq "upload"
         || $load eq "add"
         || $load eq "configure" )
    {
        my (
             $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
             $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
             $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
             $projectMetadataCols_ref, $outputCol_ref,  @rest
          )
          = GeneTableConfiguration::getOutputColClauses($fixedColIDs, "geneCart");

        printStatusLine( "Loading ...", 1 );

        if ( $load eq "upload" ) {
            $self->uploadGeneCart(
                $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
                $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
                $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
                $projectMetadataCols_ref, $outputCol_ref
            );
        } elsif ( $load eq "add" ) {
            $self->webAddGenes(
                $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
                $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
                $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
                $projectMetadataCols_ref, $outputCol_ref
            );
        } elsif ( $load eq "configure" ) {
            $self->webConfigureGenes(
                $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
                $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
                $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
                $projectMetadataCols_ref, $outputCol_ref
            );
        }
    }

    setSessionParam( "lastCart", "geneCart" );

    #print "printGeneCartForm() needGenomeJson: $needGenomeJson<br/>\n";
    if ( $needGenomeJson ) {
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        print qq{
            $js
        };
    }

    printMainForm();
    print "<h1>Gene Cart</h1>\n";
    CartUtil::printMaxNumMsg('genes');

    my $recs  = readCartFile();
    my $count = scalar( keys(%$recs) );
    if ( $count == 0 ) {
        print "<p>\n";
        print "0 genes in gene cart.\n";
        print qq{
            In order to compare genes you need to
            select / upload genes into gene cart.
        };
        print "</p>\n";
        printStatusLine( "0 genes in cart", 2 );

        # upload gene cart from file
        print "<h2>Upload Gene Cart</h2>\n";
        printUploadGeneCartFormContent();
        print end_form();
        return;
    }

    my $colIDs = GeneTableConfiguration::readColIdFile("geneCart");

    print "<p>\n$count gene(s) in cart\n</p>\n";
    printValidationJS();

    use TabHTML;
    TabHTML::printTabAPILinks("genecartTab");
    my @tabIndex = (
                     "#genecarttab1", "#genecarttab2", "#genecarttab3", "#genecarttab4",
                     "#genecarttab5", "#genecarttab6", "#genecarttab7"
    );
    my @tabNames = ( "Genes in Cart", "Functions" );

    if ($user_restricted_site) {
        push @tabNames, "Upload & Export & Save";
    } else {
        push @tabNames, "Upload & Export";
    }

    push @tabNames, ( "Chromosome Map", "Sequence Alignment", "Gene Neighborhoods", "Profile & Alignment" );

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    my $imgEditor   = isImgEditor( $dbh, $contact_oid );
    my $canEditTerm = canEditGeneTerm( $dbh, $contact_oid );

    my $doEdit   = 0;
    my $username = getUserName();
    if (
         $canEditTerm
         || (    $show_myimg_login
              && $user_restricted_site
              && $username ne "public" )
      )
    {
        $doEdit = 1;
    }

    if ($doEdit) {
        push @tabIndex, "#genecarttab8";
        push @tabNames, "Edit";
    }

    TabHTML::printTabDiv( "genecartTab", \@tabIndex, \@tabNames );
    print "<div id='genecarttab1'>";

    my $it = new InnerTable( 1, "GeneCart$$", "GeneCart", 3 );
    my $sd = $it->getSdDelim();                                  # sort delimiter

    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "center" );
    $it->addColSpec( "Locus Tag",         "asc", "center" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome",            "asc", "left" );
    $it->addColSpec( "Batch<sup>1</sup>", "asc", "right" );

    $colIDs =~ s/$fixedColIDs//i;
    my @outCols = WebUtil::processParamValue($colIDs);
    GeneTableConfiguration::addColIDs($it, \@outCols);

    #my @sortedRecs;
    #my $sortIdx  = param("sortIdx");
    #my $sortType = param("sortType");
    #$sortIdx = 1 if $sortIdx eq "";
    #sortedRecsArray( $recs, $sortIdx, \@sortedRecs, $sortType );
    #for my $r (@sortedRecs) {
    for my $r ( values %$recs ) {

        #print "printGeneCartForm() r: $r<br/>\n";
        #my @splitColVals  = split( /\t/, $r );
        #print "printGeneCartForm() splitColVals size: " . scalar(@splitColVals) . "<br/>\n";
        #print "printGeneCartForm() splitColVals: @splitColVals<br/>\n";

        my ( $workspace_id, $locus_tag, $desc, $desc_orig, $taxon_oid,
	     $orgName, $batch_id, $scaffold_oid, @outColVals ) =
          split( /\t/, $r );

        #print "printGeneCartForm() outColVals size: " . scalar(@outColVals) . "<br/>\n";
        #print "printGeneCartForm() outColVals: @outColVals<br/>\n";

        my $row;
        $row .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$workspace_id' checked />\t";

        my $data_type = '';
        my $gene_oid;
        if ( $workspace_id && WebUtil::isInt($workspace_id) ) {
            $data_type = 'database';
            $gene_oid  = $workspace_id;
        } else {
            my @vals = split( / /, $workspace_id );
            $data_type = $vals[1];
            $gene_oid  = $vals[2];
        }

        my $gene_url;
        if ( $data_type eq 'database' ) {
            $gene_url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        } else {
            $gene_url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        }
        $row .= $workspace_id . $sd . alink( $gene_url, $gene_oid ) . "\t";
        $row .= $locus_tag . $sd . escHtml($locus_tag) . "\t";
        $row .= $desc . $sd . escHtml($desc) . "\t";

        my $taxon_url;
        if ( $data_type eq 'database' ) {
            $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        } else {
            $taxon_url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$taxon_oid";
            $orgName = HtmlUtil::appendMetaTaxonNameWithDataType( $orgName, $data_type );
        }

        $row .= $orgName . $sd . alink( $taxon_url, $orgName ) . "\t";
        $row .= $batch_id . $sd . $batch_id . "\t";

    	$row = GeneTableConfiguration::addCols2Row
    	    ($gene_oid, $data_type, $taxon_oid, $scaffold_oid,
    	     $row, $sd, \@outCols, \@outColVals);
        #print "printGeneCartForm() row: $row<br/>\n";

        $it->addRow($row);
    }

    printGeneCartButtons() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartButtons();

    print qq{
        <p>\n
          1 - Each time a set of genes is added to the cart,
          a new batch number is generated for the set.<br/>\n
        </p>\n
    };
    printStatusLine( "$count gene(s) in cart", 2 );

    my $bad_oid_str = param("bad_oid_str");
    if ( !blankStr($bad_oid_str) ) {
        print "<p>\n";
        print "<font color='red'>\n";
        print "Unmapped gene_oid's $bad_oid_str<br/>.\n";
        print "</font>\n";
        print "</p>\n";
    }

    ## Table Configuration
    my %outputColHash = WebUtil::array2Hash(@outCols);
    my $name          = "_section_${section}_setGeneOutputCol";
    #GeneTableConfiguration::appendGeneTableConfiguration_old( \%outputColHash, $name );
    GeneTableConfiguration::appendGeneTableConfiguration( \%outputColHash, $name, 1 );
    print "</div>";    # end genecarttab1

    print "<div id='genecarttab2'>";
    print "<h2>Function Cart</h2>";
    print "<p>You may select genes from the cart and add functions "
      . "(of the specified type) <br/>in which these genes participate "
      . "to the function cart.</p>";
    print submit(
          -name    => "_section_GeneCartStor_addFunctionCart",
          -value   => "Add to Function Cart",
          -class   => "medbutton",
          -onclick => "return validateSelection(1);"
    );

    my $interproText = " <option value='ipr' > InterPro </option>" if($enable_interpro);

    print qq{
    &nbsp;
    <select name='functype' style="width:150px;" >
        <option value='go'  selected='selected'> GO </option>
        <option value='cog'  selected='selected'> COG </option>
        <option value='pfam' > Pfam </option>
        <option value='tigrfam' > TIGRfam </option>
        <option value='ec' > EC Numbers </option>
        <option value='ipr' > InterPro </option>
        <option value='tc' > Transporter Classification </option>
        <option value='ko' > KEGG KO </option>
        <option value='metacyc' > MetaCyc </option>
        $interproText
        <option value='iterm' > IMG Terms </option>
        <option value='ipways' > IMG Pathways </option>
        <option value='plist' > IMG Parts List </option>
    </select>
    };

    print "<h2>KEGG Pathways</h2>";
    print "<p>You may view pathways for selected genes if these genes " . "map to functions associated with a KEGG map.</p>";
    my $name = "_section_PathwayMaps_selectedGeneFns";
    print submit(
          -id      => "keggPathways",
          -name    => $name,
          -value   => "KEGG Pathways",
          -class   => "medbutton",
          -onclick => "return validateSelection(1);"
    );
    print "</div>";    # end genecarttab2

    print "<div id='genecarttab3'>";

    # upload and export
    $self->printTab2();
    print "</div>";    # end genecarttab3

    $self->printTab3();

    if ($doEdit) {
        print "<div id='genecarttab8'>";

        if ($canEditTerm) {
            print "<h2>Gene Term Associations</h2>\n";
            print "<p>\n";
            print "You may associate genes with IMG terms. ";

            if ($imgEditor) {
                print "You may also search for IMG terms, ";
                print "<br/>enter new IMG terms, ";
                print "or upload a file with gene / term associations.";
            }

            print "</p>\n";
            my $name = "_section_GeneCartDataEntry_index";
            print submit(
                  -name  => $name,
                  -value => "Gene Term Associations",
                  -class => "meddefbutton"
            );

            if ($imgEditor) {
                print nbsp(1);
                my $name = "_section_GeneCartDataEntry_fileUpload";
                print submit(
                      -name  => $name,
                      -value => "File Upload",
                      -class => "medbutton"
                );
            }
        }

        if (    $show_myimg_login
             && $user_restricted_site
             && $username ne "public" )
        {
            printMyImgAnnotation( $dbh, $contact_oid );
        }

        print "</div>";    # end genecarttab8
    }

    TabHTML::printTabDivEnd();
    print end_form();
    printStatusLine( "$count gene(s) in cart", 2 );

}

sub printGeneCartButtons {
    my $name = "_section_GenomeCart_addGeneGenome";
    print submit(
                  -name  => $name,
                  -value => "Add Genomes of Selected Genes to Cart",
                  -class => 'lgbutton'
    );
    print nbsp(1);
    print "\n";

    if ($scaffold_cart) {
        $name = "_section_ScaffoldCart_addGeneScaffold";
        print submit(
                      -name  => $name,
                      -value => "Add Scaffolds of Selected Genes to Cart",
                      -class => 'lgbutton'
        );
        print nbsp(1);
        print "<br>\n";
    }

    WebUtil::printButtonFooterInLineWithToggle();

    $name = "_section_${section}_deleteSelectedCartGenes";
    print submit(
          -name  => $name,
          -value => "Remove Selected",
          -class => 'smdefbutton'
    );
}

############################################################################
# printUploadGeneCartForm
############################################################################
sub printUploadGeneCartForm {
    print "<h1>Upload Gene Cart</h1>\n";

    # need a different ENCTYPE for file upload
    print start_form(
                      -name    => "mainForm",
                      -enctype => "multipart/form-data",
                      -action  => "$section_cgi"
    );
    printUploadGeneCartFormContent();
    print end_form();
}

sub printUploadGeneCartFormContent {
    my ($fromUploadSection) = @_;

    my $submission_site_url = $http . $domain_name . "/cgi-bin/submit/" . $main_cgi;
    my $submission_site_url_link = alink( $submission_site_url, 'submission site' );

    my $text = "";
    $text = " or IMG genes saved as a gene set to the workspace," if $user_restricted_site;

    print "<p style='width: 650px;'>";
    print "<font color=red>";
    print "The Gene Cart is used for genes already in IMG. Only previously exported IMG genes$text can be uploaded. <u>To upload private data</u>, you must submit it to IMG through the $submission_site_url_link.";
    print "</font><br/><br/>\n";

    print "You may upload a Gene Cart from a tab-delimited file.<br/>\n";
    print "The file should have a column header 'gene_oid' " . "(or 'Gene ID', or 'Gene Object ID').<br/>\n";
    if ( $fromUploadSection eq 'Yes' ) {
        print qq{
       	    (This file can be created using the
       	    <font color="blue"><u>Export Genes</u></font> section below with
       	    the format <i>"Gene information in tab delimited format to Excel"</i>)<br/>\n
        };
    } else {
        print "(This file may initially be obtained by exporting genes in a gene cart to Excel)<br/>\n";
    }
    print "<br/>\n";

    my $textFieldId = "cartUploadFile";
    print "File to upload:<br/>\n";
    print "<input id='$textFieldId' type='file' name='uploadFile' size='45'/>\n";

    print "<br/>\n";
    my $name = "_section_GeneCartStor_uploadGeneCart";
    print submit(
          -name    => $name,
          -value   => "Upload from File",
          -class   => "medbutton",
          -onClick => "return uploadFileName('$textFieldId');",
    );

    if ($user_restricted_site) {
	print nbsp(1);
	my $url = "$main_cgi?section=WorkspaceGeneSet&page=home";
	print buttonUrl( $url, "Upload from Workspace", "medbutton" );
    }

    print "</p>\n";
}

############################################################################
# uploadGeneCart - Upload data for gene cart.
#   Make this so it's more responsive to the user.
############################################################################
sub uploadGeneCart {
    my ( $self,
         $outColClause,   $taxonJoinClause,    $scfJoinClause,      $ssJoinClause,
         $cogQueryClause, $pfamQueryClause,    $tigrfamQueryClause, $ecQueryClause,
         $koQueryClause,  $imgTermQueryClause, $projectMetadataCols_ref, $outputCol_ref
      )
      = @_;

    require MyIMG;
    my @gene_oids;
    my $errmsg;
    if ( !MyIMG::uploadIdsFromFile( "gene_oid,Gene ID,Gene OID,Gene Object ID", \@gene_oids, \$errmsg ) ) {
        printStatusLine( "Error.", 2 );
        webError($errmsg);
    }

    if ( scalar(@gene_oids) > $maxGeneCartGenes ) {
        printStatusLine( "Error.", 2 );
        webError( "Import to gene cart exceeded $maxGeneCartGenes genes. " . "Please import a smaller set." );
    }

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my @finalOids;
    my @badOids;
    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        geneOidsMap( $dbh, \@dbOids, \@finalOids, \@badOids );
        my @badOids2;
        if ( !validateGenePerms( $dbh, \@finalOids, \@badOids2 ) ) {
            my %bad;
            for my $oid (@badOids) {
                $bad{$oid} = $oid;
            }
            for my $oid (@badOids2) {
                $bad{$oid} = $oid;
            }
            @badOids = sort( keys(%bad) );
            my @finalOids2;
            for my $oid (@finalOids) {
                next if $bad{$oid} ne "";
                push( @finalOids2, $oid );
            }
            @finalOids = @finalOids2;
        }
    }

    if ( scalar(@badOids) > 0 ) {
        my $bad_oid_str = join( ', ', @badOids );
        param( -name => "bad_oid_str", -value => $bad_oid_str );
    }

    if ( scalar(@metaOids) > 0 ) {
        push( @finalOids, @metaOids );
    }

    $self->addGeneBatch( \@finalOids,
         $outColClause,   $taxonJoinClause, $scfJoinClause, $ssJoinClause,
         $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause,
         $ecQueryClause,  $koQueryClause,   $imgTermQueryClause,
         $projectMetadataCols_ref, $outputCol_ref
    );
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my ( $recs, $sortIdx, $outRecs_ref, $sortType ) = @_;
    my @gene_oids = keys(%$recs);
    my @a;
    my @idxVals;
    for my $gene_oid (@gene_oids) {
        my $rec = $recs->{$gene_oid};

        #print "sortedRecsArray $gene_oid rec: ". $rec."<br/>\n";
        my @fields = split( /\t/, $rec );
        my $sortRec;
        my $sortFieldVal = $fields[$sortIdx];
        $sortRec = sprintf( "%s\t%s", $sortFieldVal, $gene_oid );
        push( @idxVals, $sortRec );
    }
    my @idxValsSorted;
    ## Numeric
    if ( $sortType =~ /N/ ) {
        ## Descending
        if ( $sortType =~ /D/ ) {
            webLog "sort ND\n";
            @idxValsSorted = reverse( sort { $a <=> $b } (@idxVals) );
        }
        ## (Ascending)
        else {
            webLog "sort NA\n";
            @idxValsSorted = sort { $a <=> $b } (@idxVals);
        }
    }
    ## (Non-numeric)
    else {
        if ( $sortType =~ /D/ ) {
            webLog "sort SD\n";
            @idxValsSorted = reverse( sort(@idxVals) );
        } else {
            webLog "sort SA\n";
            @idxValsSorted = sort(@idxVals);
        }
    }
    for my $i (@idxValsSorted) {
        my ( $idxVal, $gene_oid ) = split( /\t/, $i );
        my $r = $recs->{$gene_oid};

        #print "sortedRecsArray $gene_oid r: ". $r."<br/>\n";
        push( @$outRecs_ref, $r );
    }
}

############################################################################
# printPhyloOccurProfiles - Print phylogenetic occurrence profiles.
# obsolete now
############################################################################
sub printPhyloOccurProfiles {
    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        webError("Please select at least one gene.");
    }
    if ( $nGenes > $maxProfileOccurIds ) {
        webError("Please select no more than $maxProfileOccurIds genes.");
    }

    my $gene_oid_str = join( ',', @gene_oids );
    my $bindTokens = '?,' x @gene_oids;
    chop $bindTokens;

    printStatusLine( "Loading ...", 1 );
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    ### Load ID information
    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.taxon, g.locus_type
        from gene g
        where g.gene_oid in( $bindTokens )
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, @gene_oids );

    my @badGenes;
    my @idRecs;
    my %idRecsHash;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $taxon, $locus_type ) = $cur->fetchrow();
        last if !$gene_oid;

        if ( $locus_type ne "CDS" ) {
            push( @badGenes, $gene_oid );
            next;
        }
        my %taxons;
        $taxons{$taxon} = 1;
        my $rh = {
           id           => $gene_oid,
           name         => $gene_display_name,
           url          => "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid",
           taxonOidHash => \%taxons,
        };
        push( @idRecs, $rh );
        $idRecsHash{$gene_oid} = $rh;
    }
    $cur->finish();
    if ( scalar(@badGenes) > 0 ) {

        #$dbh->disconnect();
        my $s = join( ',', @badGenes );
        webError( "Select only protein coding genes. " . "The following RNA genes were found: $s." );
        return;
    }

    ### Load taxonomic hits information
    if ( $include_bbh_lite && $bbh_zfiles_dir ne "" ) {
        WebUtil::unsetEnvPath();
        for my $gene_oid (@gene_oids) {
            my @recs = getBBHLiteRows($gene_oid);
            for my $r (@recs) {
                my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore )
                  = split( /\t/, $r );
                my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
                my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
                my $rh = $idRecsHash{$gene_oid};
                if ( !defined($rh) ) {
                    webDie( "printPhyloOccurProfiles: " . "cannot find '$gene_oid'\n" );
                }
                my $taxonOidHash = $rh->{taxonOidHash};
                $taxonOidHash->{$staxon} = 1;
            }
        }
        WebUtil::resetEnvPath();
    } else {
        my $sql = qq{
            select distinct g.gene_oid, g.taxon
            from gene_orthologs g
            where g.gene_oid in( $bindTokens )
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, @gene_oids );
        for ( ; ; ) {
            my ( $gene_oid, $taxon ) = $cur->fetchrow();
            last if !$gene_oid;
            my $rh = $idRecsHash{$gene_oid};
            if ( !defined($rh) ) {
                webDie("printPhyloOccurProfiles: cannot find '$gene_oid'\n");
            }
            my $taxonOidHash = $rh->{taxonOidHash};
            $taxonOidHash->{$taxon} = 1;
        }
    }
    $cur->finish();

    #$dbh->disconnect();

    ## Print it out as an alignment.
    require PhyloOccur;
    my $s = "Profiles are based on bidirectional best hit orthologs.<br/>\n";
    $s .= "A dot '.' means there are no bidirectional best hit orthologs \n";
    $s .= "for the genome.<br/>\n";
    PhyloOccur::printAlignment( '', \@idRecs, $s );

    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printMyImgAnnotation - Show section for entering MyIMG annotation.
############################################################################
sub printMyImgAnnotation {
    print "<h2>Enter MyIMG Annotation</h2>\n";
    print "<p>\n";
    print "You may enter, update, or delete your <i>product name</i>, ";
    print "<i>function</i>, <i>EC number</i>, <i>PUBMED ID</i>, etc. ";
    print "for the selected genes.\n";
    print "</p>\n";
    my $name = "_section_MyIMG_geneCartAnnotations";
    print submit(
                  -name    => $name,
                  -value   => "Annotate Selected Genes",
                  -class   => "medbutton",
                  -onclick => "return validateSelection(1);"
    );
}

############################################################################
# printGenesToExcelLarge - Print gene table for exporting to excel,
#   large table version.
############################################################################
sub printGenesToExcelLarge {
    my ($gene_oids_ref) = @_;

    if ( 0 == scalar @$gene_oids_ref ) {
        webError("You must select at least one gene to export.");
		return;
	}

#    return if ( scalar(@$gene_oids_ref) == 0 );

    print "gene_oid\t";
    print "Locus Tag\t";
    print "Gene Symbol\t";
    print "Product Name\t";
    print "DNA Seq Length\t";
    print "AA Seq Length\t";
    print "Genome\t";
    print "Enzymes\t";
    print "COGs\t";
    print "COG Categories\t";
    print "Pfams\t";
    print "TIGRfams\t";
    print "Signal Peptide\t";
    print "Transmembrane Helices\t";
    print "Genome ID\n";

    my $dbh = dbLogin();

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@$gene_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@dbOids) > 0 ) {
        my @batch;
        my @genes_oids = sort(@dbOids);
        for my $gene_oid (@genes_oids) {
            if ( scalar(@batch) > 500 ) {
                flushGenesToExcelLarge( $dbh, \@batch );
                @batch = ();
            }
            push( @batch, $gene_oid );
        }
        flushGenesToExcelLarge( $dbh, \@batch );
    }

    if ( scalar(@metaOids) > 0 ) {
        flushMetaGenesToExcelLarge( $dbh, \@metaOids );
    }

    #$dbh->disconnect();
}

############################################################################
# flushGenesToExcelLarge - Print values from the database to the browser
#   to be opened by Excel.
############################################################################
sub flushGenesToExcelLarge {
    my ( $dbh, $batch_gene_oids_ref ) = @_;

    return if ( scalar(@$batch_gene_oids_ref) == 0 );

    #my $bindTokens = '?,' x @$batch_gene_oids_ref;
    #chop $bindTokens;

    # use gtt instead
    OracleUtil::truncTable( $dbh, "gtt_num_id" );
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", $batch_gene_oids_ref );

    my $sql = qq{
       select ge.gene_oid, ge.enzymes
       from gene_ko_enzymes ge
       where ge.gene_oid in( select id from gtt_num_id )
       order by ge.gene_oid, ge.enzymes
    };
    my %geneOid2Enzymes;
    loadFuncIds( $dbh, $sql, \%geneOid2Enzymes );

    my $sql = qq{
       select gcg.gene_oid, gcg.cog
       from gene_cog_groups gcg
       where gcg.gene_oid in( select id from gtt_num_id )
       order by gcg.gene_oid, gcg.cog
    };
    my %geneOid2Cogs;
    loadFuncIds( $dbh, $sql, \%geneOid2Cogs );

    my $sql = qq{
       select gcg.gene_oid, cf.functions
       from gene_cog_groups gcg, cog_functions cf
       where gcg.gene_oid in( select id from gtt_num_id )
       and gcg.cog = cf.cog_id
       order by gcg.gene_oid, gcg.cog
    };
    my %geneOid2CogFunctions;
    loadFuncIds( $dbh, $sql, \%geneOid2CogFunctions );

    my $sql = qq{
       select distinct gpf.gene_oid, gpf.pfam_family
       from gene_pfam_families gpf
       where gpf.gene_oid in( select id from gtt_num_id )
       order by gpf.gene_oid, gpf.pfam_family
    };
    my %geneOid2Pfams;
    loadFuncIds( $dbh, $sql, \%geneOid2Pfams );

    my $sql = qq{
       select gt.gene_oid, gt.ext_accession
       from gene_tigrfams gt
       where gt.gene_oid in( select id from gtt_num_id )
    };
    my %geneOid2Tigrfams;
    loadFuncIds( $dbh, $sql, \%geneOid2Tigrfams );

    my $sql = qq{
       select gsp.gene_oid, count( distinct gsp.feature_type )
       from gene_sig_peptides gsp
       where gsp.gene_oid in( select id from gtt_num_id )
       and gsp.feature_type = ?
       group by gsp.gene_oid
       order by gsp.gene_oid
    };
    my @binds;
    push( @binds, 'cleavage' );

    my %geneOid2SpCount;
    loadGeneOid2Count( $dbh, $sql, \%geneOid2SpCount, @binds );

    my $sql = qq{
       select gtm.gene_oid, count( gtm.feature_type )
       from gene_tmhmm_hits gtm
       where gtm.gene_oid in( select id from gtt_num_id )
       and gtm.feature_type = ?
       group by gtm.gene_oid
       order by gtm.gene_oid
    };
    my @binds;
    push( @binds, 'TMhelix' );

    my %geneOid2TmCount;
    loadGeneOid2Count( $dbh, $sql, \%geneOid2TmCount, @binds );

    my ($rclause) = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select g.gene_oid, g.gene_display_name,
          g.locus_type, g.locus_tag, g.gene_symbol, g.dna_seq_length, g.aa_seq_length,
          tx.taxon_oid, tx.ncbi_taxon_id, tx.taxon_display_name
        from taxon tx, gene g
        where g.taxon = tx.taxon_oid
        and g.gene_oid in ( select id from gtt_num_id )
        $rclause
        $imgClause
        order by tx.taxon_display_name, g.gene_oid
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
             $gene_oid,       $gene_display_name, $locus_type, $locus_tag,     $gene_symbol,
             $dna_seq_length, $aa_seq_length,     $taxon_oid,  $ncbi_taxon_id, $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $gene_display_name = " ( $locus_type ) " if $locus_type ne "CDS";
        my $enzymes = $geneOid2Enzymes{$gene_oid};
        chop $enzymes;
        my $cogs = $geneOid2Cogs{$gene_oid};
        chop $cogs;
        my $cogFunctions = $geneOid2CogFunctions{$gene_oid};
        chop $cogFunctions;
        my $pfams = $geneOid2Pfams{$gene_oid};
        chop $pfams;
        my $tigrfams = $geneOid2Tigrfams{$gene_oid};
        chop $tigrfams;
        my $spCount = $geneOid2SpCount{$gene_oid};
        my $tmCount = $geneOid2TmCount{$gene_oid};
        my $sp      = "No";
        $sp = "Yes" if $spCount > 0;
        my $tm = "No";
        $tm = "Yes" if $tmCount > 0;
        print "$gene_oid\t";
        print "$locus_tag\t";
        print "$gene_symbol\t";
        print "$gene_display_name\t";
        print "$dna_seq_length\t";
        print "$aa_seq_length\t";
        print "$taxon_display_name\t";
        print "$enzymes\t";
        print "$cogs\t";
        print "$cogFunctions\t";
        print "$pfams\t";
        print "$tigrfams\t";
        print "$sp\t";
        print "$tm\t";
        print "$taxon_oid\n";
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" );
}

############################################################################
# flushMetaGenesToExcelLarge - Print values from the file to the browser
#   to be opened by Excel.
############################################################################
sub flushMetaGenesToExcelLarge {
    my ( $dbh, $meta_gene_oids_ref ) = @_;

    return if ( scalar(@$meta_gene_oids_ref) == 0 );

    my %genes_h;
    my %taxon_oid_h;

    #my $k = 0;
    for my $workspace_id (@$meta_gene_oids_ref) {
        $genes_h{$workspace_id} = 1;
        my @vals = split( / /, $workspace_id );
        if ( scalar(@vals) >= 3 ) {
            $taxon_oid_h{ $vals[0] } = 1;

            #$k++;
            #if ( $k > $maxGeneListResults ) {
            #   last;
            #}
        }
    }
    my @taxonOids = keys(%taxon_oid_h);

    my $taxon_name_href;
    my $taxon_genome_type_href;
    my $taxon_metaInfo_href;
    if ( scalar(@taxonOids) > 0 ) {
        ( $taxon_name_href, $taxon_genome_type_href, $taxon_metaInfo_href ) =
          QueryUtil::fetchTaxonMetaInfo( $dbh, \@taxonOids );
    }

    my %gene_name_h;
    my %gene_info_h;
    MetaUtil::getAllGeneNames( \%genes_h, \%gene_name_h, 0 );
    MetaUtil::getAllGeneInfo( \%genes_h, \%gene_info_h );

    my $get_gene_cog  = 1;
    my $get_gene_pfam = 1;

    # gene-cog
    my %gene_cog_h;
    my %cog_name_h;
    if ( $get_gene_cog && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'cog', $meta_gene_oids_ref, \%genes_h, \%gene_cog_h );
    }

    # gene-pfam
    my %gene_pfam_h;
    my %pfam_name_h;
    if ( $get_gene_pfam && scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneFuncs( 'pfam', $meta_gene_oids_ref, \%genes_h, \%gene_pfam_h );
    }

    my $gene_count = 0;
    for my $workspace_id (@$meta_gene_oids_ref) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );
        if ( !exists( $taxon_name_href->{$taxon_oid} ) ) {

            #$taxon_oid not in hash, probably due to permission
            webLog(
"GeneCartStor flushMetaGenesToExcelLarge:: $taxon_oid not retrieved from database, probably due to permission." );
        }

        my ( $locus_type, $locus_tag, $gene_display_name, $start_coord,
	     $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 )
	    = split( /\t/, $gene_info_h{$workspace_id} );
        if ( !$taxon_oid && $tid2 ) {
            $taxon_oid = $tid2;
            if ( !exists( $taxon_name_href->{$taxon_oid} ) ) {
                my $taxon_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );

                # save taxon display name to prevent repeat retrieving
                $taxon_name_href->{$taxon_oid} = $taxon_name;
            }
        }

        # taxon
        my $taxon_display_name = $taxon_name_href->{$taxon_oid};

        if ( $gene_name_h{$workspace_id} ) {
            $gene_display_name = $gene_name_h{$workspace_id};
        }
        if ( !$gene_display_name ) {
            $gene_display_name = 'hypothetical protein';
        }

        my $dna_seq_length = $end_coord - $start_coord + 1;

        my $faa           = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
        my $aa_seq_length = length($faa);

        my @cog_recs;
        my $cogs = $gene_cog_h{$workspace_id};
        if ($cogs) {
            @cog_recs = split( /\t/, $cogs );
        }

        my $cog_ids;
        for my $cog_id (@cog_recs) {
            if ($cog_ids) {
                $cog_ids .= "; " . $cog_id;
            } else {
                $cog_ids = $cog_id;
            }
        }

        my @pfam_recs;
        my $pfams = $gene_pfam_h{$workspace_id};
        if ($pfams) {
            @pfam_recs = split( /\t/, $pfams );
        }

        my $pfam_ids;
        for my $pfam_id (@pfam_recs) {
            if ($pfam_ids) {
                $pfam_ids .= "; " . $pfam_id;
            } else {
                $pfam_ids = $pfam_id;
            }
        }

        print "$workspace_id\t";
        print "$locus_tag\t";
        print "\t";    #gene symbol
        print "$gene_display_name\t";
        print "$dna_seq_length\t";
        print "$aa_seq_length\t";
        print "$taxon_display_name\t";
        print "\t";    #enzymes
        print "$cog_ids\t";
        print "\t";    #COG Categories
        print "$pfam_ids\t";
        print "\t";    #tigrfams
        print "\t";    #Signal Peptide
        print "\t";    #Transmembrane Helices
        print "$taxon_oid\n";
    }
}

############################################################################
# loadFuncIds - Load function ids for a batch of genes.
############################################################################
sub loadFuncIds {
    my ( $dbh, $sql, $geneOid2FuncIds_href, @binds ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $func_id ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        $geneOid2FuncIds_href->{$gene_oid} .= "$func_id ";
    }
    $cur->finish();
    webLog("$count rows retrieved\n");
}

############################################################################
# loadGeneOid2Count - Load counts for gene_oid.
############################################################################
sub loadGeneOid2Count {
    my ( $dbh, $sql, $geneOid2Count_href, @binds ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        $geneOid2Count_href->{$gene_oid} = $cnt;
    }
    $cur->finish();
    webLog("$count rows retrieved\n");
}

############################################################################
# addFunctionCart - Add genes to function cart.
############################################################################
sub addFunctionCart() {
    my $func_type = param("functype");
    my @gene_oids = param("gene_oid");

    if ( @gene_oids == 0 ) {
        webError("Please select at least one gene.");
    }

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my $dbh = dbLogin();
    my @funcs;

    if ( scalar(@dbOids) > 0 ) {
        my $geneOidsInClause = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        #print "\$geneOidsInClause: $geneOidsInClause<br/>\n";

        my $sql;
        my $prefix = '';
        if ( $func_type eq "go" ) {
            $sql = qq{
                select distinct go_id
                from gene_go_terms
                where gene_oid in ( $geneOidsInClause )
            }
        } elsif ( $func_type eq "cog" ) {
            $sql = qq{
                select distinct cog
                from gene_cog_groups
                where gene_oid in ( $geneOidsInClause )
            }
        } elsif ( $func_type eq "pfam" ) {
            $sql = qq{
                select distinct pfam_family
                from gene_pfam_families
                where gene_oid in ( $geneOidsInClause )
            }
        } elsif ( $func_type eq "tigrfam" ) {
            $sql = qq{
                select distinct ext_accession
                from gene_tigrfams
                where gene_oid in ( $geneOidsInClause )
            }
        } elsif ( $func_type eq "ipr" ) {
            $sql = qq{
                select distinct id
                from gene_xref_families
                where db_name = 'InterPro'
                and gene_oid in ( $geneOidsInClause )
            }
        } elsif ( $func_type eq "ec" ) {
            $sql = qq{
                select distinct enzymes
                from gene_ko_enzymes
                where gene_oid in ( $geneOidsInClause )
            };
        } elsif ( $func_type eq "tc" ) {
            $sql = qq{
                select distinct tc_family
                from gene_tc_families
                where gene_oid in ( $geneOidsInClause )
            };
        } elsif ( $func_type eq "ko" ) {
            $sql = qq{
                select distinct ko_terms
                from gene_ko_terms
                where gene_oid in ( $geneOidsInClause )
            };
        } elsif ( $func_type eq "metacyc" ) {
            $prefix = "MetaCyc:";
            $sql    = qq{
                select distinct bp.unique_id
                from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
                biocyc_reaction br, gene_biocyc_rxns gb
                where bp.unique_id = brp.in_pwys
                and brp.unique_id = br.unique_id
                and br.unique_id = gb.biocyc_rxn
                and br.ec_number = gb.ec_number
                and gb.gene_oid in ( $geneOidsInClause )
            };
        } elsif ( $func_type eq "ipways" ) {

            #$prefix = "IPWAY:";
            # 1st get all genes terms
            my @terms;
            $sql = qq{
                select distinct function
                from gene_img_functions
                where gene_oid in ( $geneOidsInClause )
            };
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ($t) = $cur->fetchrow();
                last if !$t;
                push( @terms, $t );
            }
            $cur->finish();

            require ImgTermNodeMgr;
            my $mgr  = new ImgTermNodeMgr();
            my $root = $mgr->loadTree($dbh);

            # list of all the terms for img pathways
            my %terms_hash;
            foreach my $id (@terms) {
                my $n = $root->ImgTermNode::findNode($id);
                next if ( !$n );
                $n->getTermsParents( \%terms_hash );
            }

            OracleUtil::insertDataHash( $dbh, "gtt_func_id", \%terms_hash );

            #            $sql = qq{
            #                select ipr.pathway_oid
            #                from img_pathway_reactions ipr, img_reaction_catalysts irc, dt_img_term_path dtp
            #                where ipr.rxn = irc.rxn_oid
            #                and irc.catalysts = dtp.term_oid
            #                and dtp.map_term in (select id from gtt_func_id)
            #                union
            #                select ipr.pathway_oid
            #                from img_pathway_reactions ipr, img_reaction_t_components rtc, dt_img_term_path dtp
            #                where ipr.rxn = rtc.rxn_oid
            #                and rtc.term = dtp.term_oid
            #                and dtp.map_term in (select id from gtt_func_id)
            #            };
            $sql = qq{
                select ipr.pathway_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc
                where ipr.rxn = irc.rxn_oid
                and irc.catalysts in (select id from gtt_func_id)
                union
                select ipr.pathway_oid
                from img_pathway_reactions ipr, img_reaction_t_components rtc
                where ipr.rxn = rtc.rxn_oid
                and rtc.term in (select id from gtt_func_id)
            };
        } elsif ( $func_type eq "plist" ) {

            #$prefix = "PLIST:";
            #            $sql = qq{
            #                select distinct plt.parts_list_oid
            #                from img_parts_list_img_terms plt, dt_img_term_path dtp
            #                where plt.term = dtp.term_oid
            #                and dtp.term_oid in (
            #                    select function
            #                    from gene_img_functions
            #                    where gene_oid in ( $geneOidsInClause )
            #                )
            #            };
            $sql = qq{
                select distinct plt.parts_list_oid
                from img_parts_list_img_terms plt
                where plt.term in (
                    select function
                    from gene_img_functions
                    where gene_oid in ( $geneOidsInClause )
                )
            };
        } elsif ( $func_type eq "iterm" ) {

            #$prefix = "ITERM:";
            #            $sql = qq{
            #                select distinct it.term_oid
            #                from img_term it, dt_img_term_path dtp, gene_img_functions g
            #                where g.gene_oid in ( $geneOidsInClause )
            #                and it.term_oid = dtp.term_oid
            #                and dtp.map_term = g.function
            #            };
            $sql = qq{
                select distinct g.function
                from gene_img_functions g
                where g.gene_oid in ( $geneOidsInClause )
            };
        }

        #print "GeneCartStor::addFunctionCart() func_type: $func_type, sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($func) = $cur->fetchrow();
            last if !$func;
            $func = $prefix . $func;
            push( @funcs, $func );
        }
        $cur->finish();

        #print "GeneCartStor::addFunctionCart() func_type: funcs: @funcs<br/>\n";

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $geneOidsInClause =~ /gtt_num_id/i );
    }

    if ( scalar(@metaOids) > 0 ) {
        for my $mOid (@metaOids) {
            my ( $taxon_oid, $data_type, $g2 ) = split( / /, $mOid );
            if ( $data_type eq 'database' && WebUtil::isInt($g2) ) {

                #Todo: do we need to handle this situation
                next;
            }

            # MER-FS genes
            #Todo: For KNPFADRAFT_00000011 etc, using below functions, the results
            #are different from using MetaUtil::getAllMetaGeneFuncs
            #print "GeneCartStor::addFunctionCart func_type: $func_type<br/>\n";

            my @g_func = ();
            if ( $func_type =~ /COG/i ) {
                @g_func = MetaUtil::getGeneCogId( $g2, $taxon_oid, $data_type );
                #print "GeneCartStor::addFunctionCart using getGeneCogId, COG $g2: " . join(',', @g_func) . "<br/>\n";
            } elsif ( $func_type =~ /Pfam/i ) {
                @g_func = MetaUtil::getGenePfamId( $g2, $taxon_oid, $data_type );
            } elsif ( $func_type =~ /TIGR/i ) {
                @g_func = MetaUtil::getGeneTIGRfamId( $g2, $taxon_oid, $data_type );
            } elsif ( $func_type =~ /KO/i ) {
                @g_func = MetaUtil::getGeneKoId( $g2, $taxon_oid, $data_type );
            } elsif ( $func_type =~ /EC/i || $func_type =~ /Enzyme/ ) {
                @g_func = MetaUtil::getGeneEc( $g2, $taxon_oid, $data_type );
            }

            push( @funcs, @g_func );
        }
    }

    #my $bindTokens = '?,' x @gene_oids;
    #chop $bindTokens;

    #$dbh->disconnect();

    require FuncCartStor;
    my $fc = new FuncCartStor();
    if ( $func_type eq "iterm" ) {
        $fc->addImgTermBatch( \@funcs );
    } elsif ( $func_type eq "plist" ) {
        $fc->addImgPartsListBatch( \@funcs );
    } elsif ( $func_type eq "ipways" ) {
        $fc->addImgPwayBatch( \@funcs );
    } else {
        $fc->addFuncBatch( \@funcs );
    }
    $fc->printFuncCartForm( '', 1 );
}

sub getColIdFile {
    return getFile("colid");
}

#
# gene cart file
#
sub getStateFile {
    return getFile("stor");
}

sub readCartFile {
    return readFromFile( getStateFile() );
}

sub writeCartFile {
    my ($recs) = @_;
    my $res = newWriteFileHandle( getStateFile(), "runJob" );
    foreach my $key ( keys %{$recs} ) {
        my $rec = $recs->{$key};
        if ($rec) {
            print $res $rec . "\n";
        }
    }
    close $res;
}

sub getSelectedFile {
    return getFile("selected");
}

sub readSelectedFile {
    return readFromFile( getSelectedFile() );
}

sub writeSelectedFile {
    my (@selects) = @_;
    my $res = newWriteFileHandle( getSelectedFile, "runJob" );
    foreach my $selected (@selects) {
        if ($selected) {
            print $res $selected . "\n";
        }
    }
    close $res;
}

sub getFile {
    my ($fileNameEnd) = @_;
    my ( $cartDir, $sessionId ) = WebUtil::getCartDir();
    my $sessionFile = "$cartDir/geneCart.$sessionId." . $fileNameEnd;
    return $sessionFile;
}

sub readFromFile {
    my ($file) = @_;
    my %records;
    my $res = newReadFileHandle( $file, "runJob", 1 );
    if ( !$res ) {
        return \%records;
    }
    while ( my $line = $res->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        my ( $oid, @junk ) = split( /\t/, $line );
        $oid = WebUtil::strTrim($oid);
        if ( $oid && WebUtil::hasAlphanumericChar($oid) ) {
            $records{$oid} = $line;
        }
    }
    close $res;

    #print "readFromFile 2 oids: " . keys(%records) . "<br/><br/>\n\n";
    return \%records;
}

sub removeFromFile {
    my ( $file, @oids ) = @_;

    my %oid_h;    #to be removed
    foreach my $oid (@oids) {
        #print "removeFromFile oid: ".$oid."<br/>\n";
        $oid_h{$oid} = 1;
    }

    my $recs_old_ref = readFromFile($file);
    my $res = newWriteFileHandle( $file, "runJob" );
    my $cnt = 0;

    foreach my $key ( keys(%$recs_old_ref) ) {
        #print "removeFromFile key: ".$key."<br/>\n";
        if ( exists $oid_h{$key} ) {
            # delete
            # do nothing
            # next
        } else {
            print $res $recs_old_ref->{$key} . "\n";
            $cnt++;
        }
    }
    close $res;

    if ( $cnt == 0 ) {
        wunlink($file);
    }

    return $cnt;
}

1;

