############################################################################
# GeneProfilerStor - Variation on phylogenetic profiler, but stores
#   results in a matrix.
#        --es 3/20/2006
#
# $Id: GeneProfilerStor.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package GeneProfilerStor;
my $section = "GeneProfilerStor";

use strict;
use Storable;
use GzWrap;
use CGI qw( :standard );
use Data::Dumper;
use Time::localtime;
use WebConfig;
use WebUtil;
use InnerTable;
use OracleUtil;
use MerFsUtil;
use HtmlUtil;
use Command;

$| = 1;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $cgi_url               = $env->{cgi_url};
my $base_dir              = $env->{base_dir};
my $avagz_batch_dir       = $env->{avagz_batch_dir};
my $genomePair_zfiles_dir = $env->{genomePair_zfiles_dir};
my $taxon_stats_dir       = $env->{taxon_stats_dir};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $img_internal          = $env->{img_internal};
my $include_metagenomes   = $env->{include_metagenomes};
my $in_file               = $env->{in_file};
my $usearch_bin           = $env->{usearch_bin};
my $taxon_faa_dir         = $env->{taxon_faa_dir};
my $sandbox_blast_data_dir = $env->{sandbox_blast_data_dir};
my $enable_genomelistJson = $env->{enable_genomelistJson};
my $max_taxon_candidates = 1000;
my $max_gene_selections  = 1000;
my $max_gene_batch       = 500;

# Check whether using Yahoo! tables
my $yui_tables = $env->{yui_tables};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if (    paramMatch("showGeneCartProfile_s") ne ""
         || paramMatch("showGeneCartProfile_t") ne ""
         || $page eq "geneProfilerStor" )
    {

        my $gp = new GeneProfilerStor;
        $gp->printProfile();
    } elsif ( $page eq "geneProfilerGenes" ) {
        my $gp = new GeneProfilerStor;
        $gp->printProfileGenes();
    } else {
        my $gp = new GeneProfilerStor;
        $gp->printProfile();
    }
}

############################################################################
# new - New object instance.
############################################################################
sub new {
    my ( $myType, $baseUrl ) = @_;

    $baseUrl = "$section_cgi&page=geneProfilerStor" if $baseUrl eq "";
    my $self = {};
    bless( $self, $myType );
    my $stateFile     = $self->getStateFile();
    my $page = param('page');
    my $fromQueryForm = 0;
    $fromQueryForm = 1 if (paramMatch("showGeneCartProfile_s") ne ""  || paramMatch("showGeneCartProfile_t") ne "" 
    || $page eq 'showGeneCartProfile_s' || $page eq 'showGeneCartProfile_t');
    
    if ( -e $stateFile && !$fromQueryForm ) {

        if ( !( -e $stateFile ) ) {
            webError("Session expired. Please rerun your query again.");
        }
        $self = retrieve($stateFile);
    } else {
        #webLog("================== $fromQueryForm  $page\n"); 

        my %h1;
        my %h2;
        my %h3;
        my @a1;
        my @a2;
        $self->{geneOids}            = \@a1;
        $self->{profileTaxonBinOids} = \@a2;
        $self->{cells}               = \%h1;
        $self->{gene2Desc}           = \%h2;
        $self->{taxonBin2Desc}       = \%h3;
        $self->{baseUrl}             = $baseUrl;
        processResults($self);
        $self->save();
    }
    bless( $self, $myType );
    return $self;
}

############################################################################
# printProfile - Print the profile.
############################################################################
sub printProfile {
    my ($self) = @_;

    my $data_type = param("data_type");

    my $transpose = $self->{transpose};

    printHeader($self, $data_type);
    if ( !$transpose ) {
        printMatrix($self, $data_type);
    } else {
        printMatrixTranspose($self, $data_type);
    }

    my $url = "$main_cgi?section=GeneCartStor&page=showGeneCart";
    print buttonUrl( $url, "Start Over Again", "medbutton" );
}

############################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
    my ($self)      = @_;
    my $sessionId   = getSessionId();
    my $sessionFile = "$cgi_tmp_dir/geneProfiler.$sessionId.stor";
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
    my ($self) = @_;
    store( $self, checkTmpPath( $self->getStateFile() ) );
}

############################################################################
# printHeader - Print header
############################################################################
sub printHeader {
    my ($self, $data_type) = @_;

    print "<h1>Gene Profile</h1>\n";

    my $minPercIdent = $self->{minPercIdent};
    my $maxEvalue    = $self->{maxEvalue};
    my $transpose    = $self->{transpose};

    print "<p>\n";
    print "Show unidirectional sequence similarities ";
    print "for selected genes with BLAST cutoffs at<br/>";
    print "minimum <b>$minPercIdent\%</b> identity, and ";
    print "maximum <b>$maxEvalue</b> E-value.<br/>\n";
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
    print "</p>\n";

    my $x = "genome (bin) abbreviation";
    $x = "gene object identifier" if $transpose;
    my $s = "Mouse over $x to see the name.<br/>\n";
    $s .= "Cell coloring is based on gene counts: white = 0, ";
    $s .= "<span style='background-color:bisque'>bisque</span> = 1-4, ";
    $s .= "<span style='background-color:yellow'>yellow</span> >= 5.";
    printHint($s);
    print "<br/>";
}

############################################################################
# processResults - Process results from selection.
############################################################################
sub processResults {
    my ($self) = @_;
    
    printStatusLine( "Loading ...", 1 );
    my @geneOids = param("gene_oid");

    my @profileTaxonBinOids =  OracleUtil::processTaxonSelectionParam( "profileTaxonBinOid" );
    
    if($enable_genomelistJson) {
        @profileTaxonBinOids = param('genomeFilterSelections');
    }
    
    my $minPercIdent        = param("minPercIdent");
    my $maxEvalue           = param("maxEvalue");
    my $transpose           = 0;
    $transpose = 1 if paramMatch("showGeneCartProfile_t") ne "";
    $self->{transpose}           = $transpose;
    $self->{minPercIdent}        = $minPercIdent;
    $self->{maxEvalue}           = $maxEvalue;
    $self->{geneOids}            = \@geneOids;
    $self->{profileTaxonBinOids} = \@profileTaxonBinOids;

    my $nGeneOids            = @geneOids;
    my $nProfileTaxonBinOids = @profileTaxonBinOids;
    if ( $nGeneOids == 0 ) {
        webError("You must select at least one gene.");
    }
    if ( $nProfileTaxonBinOids == 0 ) {
        webError("You must select at least one genome or bin.");
    }
    if ( $nGeneOids == 0 ) {
        webError("You must select at least one gene.");
    }

    if ( $nProfileTaxonBinOids > $max_taxon_candidates ) {
        webError( "Too many genomes/bins selected. " 
            . "Please select a maximum of $max_taxon_candidates" );
    }
    
    my $dbh = dbLogin();
    my $bad_oid_str = checkBigEuks( $dbh, \@geneOids );
    if ( !blankStr($bad_oid_str) ) {
        webError( "Large model organisms are not supported here for " 
            . "gene object identifier(s) $bad_oid_str." );
    }

    my $data_type = param("data_type");
    
    printStartWorkingDiv();

    my %taxon2Genes;
    my %gene2Desc;
    my %obsoleteGenes;
    my %rnaGenes;
    loadTaxon2Genes( $dbh, \@geneOids, \%taxon2Genes, \%gene2Desc, \%obsoleteGenes, \%rnaGenes );
    my @rnaGenes_a = keys(%rnaGenes);
    if ( scalar(@rnaGenes_a) > 0 ) {
        my @rnaGenes_sort = sort( @rnaGenes_a );
        my $s = join( ",", @rnaGenes_sort );
        printStatusLine( "Error.", 2 );
        webError( "Select only protein coding genes. " 
            . "The following RNA genes were found: '$s'\n" );
    }
    $self->{gene2Desc} = \%gene2Desc;

    my @gene_taxon_oids = sort( keys(%taxon2Genes) );
    my %gene_taxons_in_file = MerFsUtil::fetchTaxonsInFile($dbh, @gene_taxon_oids);

    my %taxonOid2TaxonBin;
    my %taxonBin2Desc;
    my %taxons_in_file = loadTaxonOid2TaxonBin( $dbh, \@profileTaxonBinOids, \%taxonOid2TaxonBin, \%taxonBin2Desc, $data_type );
    $self->{taxonBin2Desc} = \%taxonBin2Desc;
    my @taxon_oids = sort( keys(%taxonOid2TaxonBin) );

    my %gene2BinOids;
    loadGene2BinOids( $dbh, \@profileTaxonBinOids, \%gene2BinOids, \%obsoleteGenes );

    my %cells;
    for my $gene_taxon_oid (@gene_taxon_oids) {
        my $workspace_id_str = $taxon2Genes{$gene_taxon_oid};
        for my $taxon_oid (@taxon_oids) {
            my $taxon_bin_str     = $taxonOid2TaxonBin{$taxon_oid};
            my $includeWholeTaxon = 0;
            if ( $taxon_bin_str =~ /t:$taxon_oid/ ) {
                $includeWholeTaxon = 1;
            }
            WebUtil::unsetEnvPath();

            print "Comparing taxons $gene_taxon_oid vs. $taxon_oid ...<br/>\n";
            my $taxon1Faa;
            if ( $gene_taxons_in_file{$gene_taxon_oid} ) {
                next if ( $data_type eq 'unassembled' );
                $taxon1Faa = $sandbox_blast_data_dir . "/" . $gene_taxon_oid . "/" . $gene_taxon_oid . ".a.faa";                
            }
            else {
                $taxon1Faa = "$taxon_faa_dir/$gene_taxon_oid.faa";
            }
            if ( !-e $taxon1Faa ) {
                #print("WARNING: '$taxon1Faa' not found<br/>\n");
                #webLog("WARNING: '$taxon1Faa' not found\n");
                next;
            }

            my $taxon2Faa;
            if ( $taxons_in_file{$taxon_oid} ) {
                next if ( $data_type eq 'unassembled' );
                $taxon2Faa = $sandbox_blast_data_dir . "/" . $taxon_oid . "/" . $taxon_oid . ".a.faa";                
            }
            else {
                $taxon2Faa = "$taxon_faa_dir/$taxon_oid.faa";
            }
            if ( !-e $taxon2Faa ) {
                #print("WARNING: '$taxon2Faa' not found<br/>\n");
                #webLog("WARNING: '$taxon2Faa' not found\n");
                next;
            }

            #my $tmpFile = "$cgi_tmp_dir/$gene_taxon_oid-$taxon_oid.$$.m8.txt";
            my $tmpFile = Command::createSessionDir();
            $tmpFile = "$tmpFile/$gene_taxon_oid-$taxon_oid.$$.m8.txt";

            my $cmd =
                "$usearch_bin --query $taxon1Faa --db $taxon2Faa "
              . "--accel 0.8 --quiet --trunclabels --iddef 4 "
              . "--evalue 1e-1 --blast6out $tmpFile";
            #my $cmd =
            #    "$usearch_bin --query $taxon1Faa --db $taxon2Faa "
            #  . "--accel 0.8 --quiet --trunclabels --iddef 4 --maxaccepts 20 --maxrejects 20 "
            #  . "--evalue 1e-1 --blast6out $tmpFile";
            #print "$cmd<br/>\n";
            #webLog("+ $cmd\n");
            my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
            my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
            if ( $stdOutFile == -1 ) {
                next;
            }

            my $rfh = newReadFileHandle( $tmpFile, "processResults" );
            loadCells( $dbh,           $rfh,            $workspace_id_str, $taxon_oid,    $includeWholeTaxon,
                       \%gene2BinOids, \%obsoleteGenes, $maxEvalue,    $minPercIdent, \%cells );
            $rfh->close();
            WebUtil::resetEnvPath();
        }
    }
    $self->{cells} = \%cells;
    save($self);
    #print Dumper(\%cells);
    
    printEndWorkingDiv();    
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# loadTaxon2Genes - Group genes into taxons for later efficient access
#   of taxon oriented files.
############################################################################
## Batch version
sub loadTaxon2Genes {
    my ( $dbh, $geneOids_ref, $taxon2Genes_ref, $gene2Desc_ref, $obsoleteGenes_ref, $rnaGenes_ref ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@$geneOids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@dbOids) > 0 ) {
        loadTaxon2GenesFlush( $dbh, \@dbOids, $taxon2Genes_ref, $gene2Desc_ref, $obsoleteGenes_ref, $rnaGenes_ref );
    }

    if ( scalar(@metaOids) > 0 ) {
        loadTaxon2GenesMetaFlush( $dbh, \@metaOids, $taxon2Genes_ref, $gene2Desc_ref, $obsoleteGenes_ref, $rnaGenes_ref );
    }

}

## Code for each batch to flush.
sub loadTaxon2GenesFlush {
    my ( $dbh, $geneOids_ref, $taxon2Genes_ref, $gene2Desc_ref, $obsoleteGenes_ref, $rnaGenes_ref ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$geneOids_ref );
    my $sql       = qq{
        select g.taxon, g.gene_oid, g.locus_type, 
	       g.gene_display_name, g.obsolete_flag
    	from gene g
    	where g.gene_oid in( $gene_oid_str )
    	$rclause
    	$imgClause
    	order by g.taxon
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon, $gene_oid, $locus_type, $gene_display_name, $obsolete_flag ) = $cur->fetchrow();
        last if !$taxon;

        $taxon2Genes_ref->{$taxon} .= "$gene_oid\t";
        $gene2Desc_ref->{$gene_oid}     = $gene_display_name;
        $obsoleteGenes_ref->{$gene_oid} = 1 if $obsolete_flag eq "Yes";
        $rnaGenes_ref->{$gene_oid}      = 1 if $locus_type ne "CDS";
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $gene_oid_str =~ /gtt_num_id/i );

}

sub loadTaxon2GenesMetaFlush {
    my ( $dbh, $geneOids_ref, $taxon2Genes_ref, $gene2Desc_ref, $obsoleteGenes_ref, $rnaGenes_ref ) = @_;

    my $gene_oid_str = join( ",", @$geneOids_ref );
    return if blankStr($gene_oid_str);

    my %genes_h;
    for my $workspace_id (@$geneOids_ref) {
        $genes_h{$workspace_id} = 1;
    }

    my %gene_name_h;
    my %gene_info_h;
    require MetaUtil;
    MetaUtil::getAllGeneNames( \%genes_h, \%gene_name_h );
    MetaUtil::getAllGeneInfo( \%genes_h, \%gene_info_h );

    for my $workspace_id (@$geneOids_ref) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );

        my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 )
          = split( /\t/, $gene_info_h{$workspace_id} );

        if ( $gene_name_h{$workspace_id} ) {
            $gene_display_name = $gene_name_h{$workspace_id};
        }
        if ( !$gene_display_name ) {
            $gene_display_name = 'hypothetical protein';
        }

        #$taxon2Genes_ref->{$taxon_oid} .= "$gene_oid\t";
        #$gene2Desc_ref->{$gene_oid} = $gene_display_name;
        #$rnaGenes_ref->{$gene_oid} = 1 if $locus_type ne "CDS";

        $taxon2Genes_ref->{$taxon_oid} .= "$workspace_id\t";
        $gene2Desc_ref->{$workspace_id} = $gene_display_name;
        $rnaGenes_ref->{$workspace_id} = 1 if $locus_type ne "CDS";

    }

}

############################################################################
# loadTaxonOid2TaxonBin - Map "t:taxon_oid, b:bin_oid"  to
#   taxon_oid keys and descriptions.
############################################################################
sub loadTaxonOid2TaxonBin {
    my ( $dbh, $profileTaxonBinOids_ref, $taxonOid2TaxonBin_ref, $taxonBin2Desc_ref, $data_type ) = @_;
    
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    
    my %taxons_in_file;
    my @taxon_oids = extractTaxonOids( $profileTaxonBinOids_ref );
    #webLog("==================== @taxon_oids\n");    
    if ( scalar(@taxon_oids) > 0 ) {
        %taxons_in_file = MerFsUtil::fetchTaxonsInFile($dbh, @taxon_oids);

        my $taxon_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @taxon_oids );
        my $sql = qq{
    	    select tx.taxon_oid, tx.taxon_display_name
    	    from taxon tx
    	    where tx.taxon_oid in( $taxon_oid_str )
    	    $rclause
    	    $imgClause
    	    order by tx.taxon_oid
    	};
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;
            $taxonOid2TaxonBin_ref->{$taxon_oid} .= "t:$taxon_oid ";
            if ( $taxons_in_file{$taxon_oid} ) {
                $taxon_display_name .= " (MER-FS)";
                if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                    $taxon_display_name .= " ($data_type)";
                }
            }            
            $taxonBin2Desc_ref->{"t:$taxon_oid"} = $taxon_display_name;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_oid_str =~ /gtt_num_id/i );
    }
    
    my @bin_oids = extractBinOids($profileTaxonBinOids_ref);
    #webLog("==================== @bin_oids\n");    
    if ( scalar(@bin_oids) > 0 ) {
        my $bin_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @bin_oids );
        my $sql = qq{
    	    select distinct tx.taxon_oid, b.bin_oid, b.display_name
    	    from bin b, env_sample_gold es, taxon tx
    	    where b.env_sample = es.sample_oid
    	    and tx.env_sample = es.sample_oid
    	    and b.bin_oid in( $bin_oid_str )
    	    $rclause
    	    $imgClause
    	    order by tx.taxon_oid
    	};
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;
            $taxonOid2TaxonBin_ref->{$taxon_oid} .= "b:$bin_oid ";
            $taxonBin2Desc_ref->{"b:$bin_oid"} = $bin_display_name;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $bin_oid_str =~ /gtt_num_id/i );
    }
    
    return %taxons_in_file;
}

############################################################################
# extractBinOids - Extract bin_oid's from taxonBinOids of <t>:<oid>.
############################################################################
sub extractBinOids {
    my ($profileTaxonBinOids_ref) = @_;
    my @bin_oids;
    for my $taxonBin (@$profileTaxonBinOids_ref) {
        next if $taxonBin !~ /^b:/;
        my $bin_oid = $taxonBin;
        $bin_oid =~ s/^b://;
        push( @bin_oids, $bin_oid );
    }
    return @bin_oids;
}

############################################################################
# extractTaxonOids - Extract taxon_oid's from taxonBinOids of <t>:<oid>.
############################################################################
sub extractTaxonOids {
    my ( $profileTaxonBinOids_ref ) = @_;

    my @taxon_oids;
    for my $taxonBin (@$profileTaxonBinOids_ref) {
        next if $taxonBin !~ /^t:/;
        my $taxon_oid = $taxonBin;
        $taxon_oid =~ s/^t://;
        push( @taxon_oids, $taxon_oid );
    }
    return @taxon_oids;
}

############################################################################
# loadGene2BinOids - Map gene_oid's to bin_oid's.
############################################################################
sub loadGene2BinOids {
    my ( $dbh, $profileTaxonBinOids_ref, $gene2BinOids_ref, $obsoleteGenes_ref ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my @bin_oids = extractBinOids($profileTaxonBinOids_ref);
    #webLog("==================== @bin_oids\n");    
    if ( scalar(@bin_oids) > 0 ) {
        my $bin_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @bin_oids );
        my $sql       = qq{
            select distinct g.gene_oid, b.bin_oid, g.obsolete_flag
    	    from bin b, bin_scaffolds bs, gene g
    	    where b.bin_oid = bs.bin_oid
    	    and bs.scaffold = g.scaffold
    	    and b.bin_oid in( $bin_oid_str )
    	    $rclause
    	    $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $bin_oid, $obsolete_flag ) = $cur->fetchrow();
            last if !$gene_oid;
            $gene2BinOids_ref->{$gene_oid} .= "$bin_oid ";
            $obsoleteGenes_ref->{$gene_oid} = 1 if $obsolete_flag eq "Yes";
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $bin_oid_str =~ /gtt_num_id/i );
    }
    
    my @taxon_oids = extractTaxonOids( $profileTaxonBinOids_ref );
    webLog("==================== @taxon_oids\n");
    if ( scalar(@taxon_oids) > 0 ) {
        my $taxon_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @taxon_oids );
        my $sql = qq{
            select distinct g.gene_oid,  g.obsolete_flag
    	    from gene g
    	    where g.taxon in( $taxon_oid_str )
    	    $rclause
    	    $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $obsolete_flag ) = $cur->fetchrow();
            last if !$gene_oid;
            $obsoleteGenes_ref->{$gene_oid} = 1 if $obsolete_flag eq "Yes";
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_oid_str =~ /gtt_num_id/i );
    }
}

############################################################################
# loadCells - Load cells.
#   Cell specification:
#  type2 = "b"in | "t"axon
#  cell
#      key: "<gene_oid1>-<t|b>:<taxon_oid2|bin_oid2>"
#      value: list of homolog gene_oid's in taxon_oid2 or bin_oid2
#
############################################################################
sub loadCells {
    my (
         $dbh,                 $rfh,               $workspace_id_str, $taxon_oid,    $includeWholeTaxon,
         $geneOid2BinOids_ref, $obsoleteGenes_ref, $maxEvalue,    $minPercIdent, $cells_ref
      )
      = @_;
    my @workspace_id_arr = split( /\t/, $workspace_id_str );
    my %workspace_ids_hsh = array2Hash(@workspace_id_arr);

    webLog "loadCells: includeWholeTaxon=$includeWholeTaxon\n"
      if $verbose >= 1;
    
    my %cells_tmp;  
    ## Get genes for specific bins
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        #print "loadCells() s=$s<br/>\n";
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        #$qid = WebUtil::firstDashTok($qid);
        $qid = tokToWorkspaceId($qid);
        #if ( $qid =~ /BsetDRAFT3_000001472/ ) {
        #    print "loadCells() s=$s<br/>\n";
        #}
        next if $workspace_ids_hsh{$qid} eq "";
        next if $obsoleteGenes_ref->{$qid} ne "";
        #print "loadCells() $qid in<br/>\n";

        #$sid = WebUtil::firstDashTok($sid);
        $sid = tokToWorkspaceId($sid);
        next if $obsoleteGenes_ref->{$sid} ne "";

        next if $evalue > $maxEvalue;
        next if $percIdent < $minPercIdent;
        #print "loadCells() qid=$qid, sid=$sid, evalue=$evalue <= $maxEvalue, percIdent=$percIdent >= $minPercIdent<br/>\n";
        
        my $bin_oid_str = $geneOid2BinOids_ref->{$sid};
        my @bin_oids    = split( / /, $bin_oid_str );
        for my $bin_oid (@bin_oids) {
            my $k = "$qid-b:$bin_oid";
            $cells_tmp{$k} .= "$sid\t";
        }
        if ($includeWholeTaxon) {
            my $k = "$qid-t:$taxon_oid";
            $cells_tmp{$k} .= "$sid\t";
        }
    }

    ## Purge duplicate homolog gene_oid's
    my @keys = keys(%cells_tmp);
    for my $k (@keys) {
        my $v = $cells_tmp{$k};
        my @a = split( /\t/, $v );
        my %h;
        for my $i (@a) {
            $h{$i} = 1;
        }
        my @keys2 = sort( keys(%h) );
        my $v2 = join( "\t", @keys2 );
        $cells_ref->{$k} = $v2;
        print "loadCells() k=$k, v=$v, v2=$v2<br/>\n";
    }
}

sub tokToWorkspaceId {    
    my ( $gene_id ) = @_;

    if ( WebUtil::isInt($gene_id) ) {
        return $gene_id;
    }
    else {
        my ( $t_oid, $t_g_oid ) = split( /\./, $gene_id );
        my ( $d_type, $g_oid ) = split( /\:/, $t_g_oid );
        if ( $d_type eq 'a' ) {
            $d_type = 'assembled';
        }
        elsif ( $d_type eq 'u' ) {
            $d_type = 'unassembled';        
        }
        return "$t_oid $d_type $g_oid";        
    }
    
    return $gene_id;
}

############################################################################
# printMatrix - Print matrix
#   Generated record with
#     gene_oid | gene_display_name | taxonCount1 | taxonCount2 ...
############################################################################
sub printMatrix {
    my ($self, $data_type) = @_;

    my $geneOids            = $self->{geneOids};
    my $profileTaxonBinOids = $self->{profileTaxonBinOids};
    my $cells               = $self->{cells};
    my $gene2Desc           = $self->{gene2Desc};
    my $taxonBin2Desc       = $self->{taxonBin2Desc};

    my @recs;
    #$verbose = 3;
    print "<pre>\n" if $verbose >= 3;
    for my $workspace_id (@$geneOids) {
        print ">>> <b>$workspace_id</b>:\n" if $verbose >= 3;
        my $gene_display_name = $gene2Desc->{$workspace_id};
        my $r = "$workspace_id\t";
        $r .= "$gene_display_name\t";
        for my $taxonBin (@$profileTaxonBinOids) {
            my $k = "$workspace_id-$taxonBin";
            my $v = $cells->{$k};
            chop $v;
            print "$taxonBin=($v)\n" if $verbose >= 3;
            my @a = split( /\t/, $v );
            my $cnt = @a;
            $r .= "$cnt\t";
        }
        push( @recs, $r );
        print "<br/>\n" if $verbose >= 3;
    }
    print "</pre>\n" if $verbose >= 3;

    my @recsSorted;
    sortMatrixRecs( $self, \@recs, \@recsSorted );

#### BEGIN updated table using InnerTable +BSJ 03/17/10

    my $it = new InnerTable( 1, "GeneProfile$$", "GeneProfile", 0 );
    my $sd = $it->getSdDelim();                                        # sort delimiter

    ## Header
    $it->addColSpec( "Gene ID",      "asc" );
    $it->addColSpec( "Product Name", "asc" );

    my $n = @$profileTaxonBinOids;
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $taxonBin = $profileTaxonBinOids->[$i];
        my $tbDesc   = $taxonBin2Desc->{$taxonBin};
        my $abbrName;
        if ( $taxonBin =~ /^t:/ ) {
            my $taxon_oid = $taxonBin;
            $taxon_oid =~ s/^t://;
            $abbrName = WebUtil::abbrColName( $taxon_oid, $tbDesc, 1 );
            #no working
            #print "tbDesc=$tbDesc<br/>\n";
            #if ( $tbDesc =~ /(MER-FS)/ ) {
            #    print "0 abbrName=$abbrName<br/>\n";
            #    if ( $tbDesc =~ /(assembled)/ ) {
            #        $abbrName .= "<br/>(MER-FS)";
            #        $abbrName .= "<br/>(assembled)";
            #    }
            #    elsif ( $tbDesc =~ /(unassembled)/ ) {
            #        $abbrName .= "<br/>(MER-FS)";
            #        $abbrName .= "<br/>(unassembled)";
            #        print "2 abbrName=$abbrName<br/>\n";
            #    }
            #}
        } elsif ( $taxonBin =~ /^b:/ ) {
            my $bin_oid = $taxonBin;
            $bin_oid =~ s/^b://;
            $abbrName = WebUtil::abbrBinColName( $bin_oid, $tbDesc, 1 );
        }
        $it->addColSpec( $abbrName, "desc", "right", "", $tbDesc );
    }
    ## Rows
    # YUI tables look better with more vertical padding:
    my $vPadding = ($yui_tables) ? 4 : 0;
    for my $r (@recsSorted) {
        my $row;
        my @fields = split( /\t/, $r );
        my $nFields = @fields;
        my $workspace_id;

        for ( my $j = 0 ; $j < $nFields ; $j++ ) {
            my $val = $fields[$j];
            if ( $j == 0 ) {
                my $url = "$main_cgi?section=GeneDetail" 
                    . "&page=geneDetail&gene_oid=$val";
                $workspace_id = $val;
                my $gene_oid;
                if ( WebUtil::isInt($workspace_id) ) {
                    $gene_oid = $workspace_id;
                }
                else {
                    my ($t_oid, $d_type, $g_oid) = split( / /, $workspace_id );
                    $gene_oid = $g_oid;                    
                }
                $row .= $val . $sd . alink( $url, $gene_oid ) . "\t";
            } elsif ( $j == 1 ) {
                $row .= $val . $sd . escHtml($val) . "\t";
            } else {
                my $taxonBin = $profileTaxonBinOids->[ $j - 2 ];
                $taxonBin =~ s/://;
                my $color = val2Color($val);
                $row .= $val . $sd;
                if ( $val == 0 ) {
                    $row .= "<span style='padding:${vPadding}px 10px;'>";
                    $row .= "0</span>\t";
                } else {
                    my $url = "$section_cgi&page=geneProfilerGenes";
                    $url .= "&gene_oid=$workspace_id";
                    $url .= "&taxonBin=$taxonBin";
                    $url .= "&data_type=$data_type" if ($data_type);
                    $row .= "<span style='background-color:$color;padding:${vPadding}px 10px;'>";
                    $row .= alink( $url, $val );
                    $row .= "</span>\t";
                }
            }
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table using InnerTable +BSJ 03/17/10

}

############################################################################
# printMatrixTranspose - Print matrix in transposed format.
############################################################################
sub printMatrixTranspose {
    my ($self, $data_type) = @_;

    my $geneOids            = $self->{geneOids};
    my $profileTaxonBinOids = $self->{profileTaxonBinOids};
    my $cells               = $self->{cells};
    my $gene2Desc           = $self->{gene2Desc};
    my $taxonBin2Desc       = $self->{taxonBin2Desc};

    my @recs;
    #$verbose = 3;
    print "<pre>\n" if $verbose >= 3;
    for my $taxonBin (@$profileTaxonBinOids) {
        print ">>> <b>$taxonBin</b>:\n" if $verbose >= 3;
        my $taxonBinName = $taxonBin2Desc->{$taxonBin};
        my $r            = "$taxonBin\t";
        $r .= "$taxonBinName\t";
        for my $workspace_id (@$geneOids) {
            my $gene_display_name = $gene2Desc->{$workspace_id};
            my $k                 = "$workspace_id-$taxonBin";
            my $v                 = $cells->{$k};
            chop $v;
            print "$workspace_id=($v)\n" if $verbose >= 3;
            my @a = split( /\t/, $v );
            my $cnt = @a;
            $r .= "$cnt\t";
        }
        push( @recs, $r );
        print "<br/>\n" if $verbose >= 3;
    }
    print "</pre>\n" if $verbose >= 3;

    my @recsSorted;
    sortMatrixRecs( $self, \@recs, \@recsSorted );

#### BEGIN updated table using InnerTable +BSJ 03/17/10

    my $it = new InnerTable( 1, "GeneProfile$$", "GeneProfile", 0 );
    my $sd = $it->getSdDelim();                                        # sort delimiter

    ## Header
    $it->addColSpec( "Genome (bin)<br/>Name", "asc" );
    for my $workspace_id ( @$geneOids ) {
        my $gene_display_name = $gene2Desc->{$workspace_id};
        my $gene_oid;
        if ( WebUtil::isInt($workspace_id) ) {
            $gene_oid = $workspace_id;
        }
        else {
            my ($t_oid, $d_type, $g_oid) = split( / /, $workspace_id );
            $gene_oid = $g_oid;                    
        }
        $it->addColSpec( $gene_oid, "number desc", "right", "", $gene_display_name );
    }
    ## Rows
    my $vPadding = ($yui_tables) ? 4 : 0;                              # YUI tables look better with more vertical padding
    for my $r (@recsSorted) {
        my $row;
        my @fields = split( /\t/, $r );
        my $nFields = @fields;
        my $taxonBin;
        for ( my $j = 1 ; $j < $nFields ; $j++ ) {
            my $val = $fields[$j];
            if ( $j == 1 ) {
                my $val0 = $fields[ $j - 1 ];
                my $url;
                if ( $val0 =~ /^t:/ ) {
                    my $taxon_oid = $val0;
                    $taxon_oid =~ s/^t://;
                    $url = "$main_cgi?section=TaxonDetail" 
                        . "&page=taxonDetail&taxon_oid=$taxon_oid";
                } elsif ( $val0 =~ /^b:/ ) {
                    my $bin_oid = $val0;
                    $bin_oid =~ s/^b://;
                    $url = "$main_cgi?section=Metagenome" 
                        . "&page=binDetail&bin_oid=$bin_oid";
                }

                $row .= $val . $sd . alink( $url, $val ) . "\t";
                $taxonBin = $val0;
                $taxonBin =~ s/://;
            } else {
                my $color    = val2Color($val);
                $row .= $val . $sd;
                if ( $val == 0 ) {
                    $row .= "<span style='padding:${vPadding}px 10px;'>";
                    $row .= "0</span>\t";
                } else {
                    my $workspace_id = $geneOids->[ $j - 2 ];
                    my $url = "$section_cgi&page=geneProfilerGenes";
                    $url .= "&gene_oid=$workspace_id";
                    $url .= "&taxonBin=$taxonBin";
                    $url .= "&data_type=$data_type" if ($data_type);
                    $row .= "<span style='background-color:$color;padding:${vPadding}px 10px;'>";
                    $row .= alink( $url, $val );
                    $row .= "</span>\t";
                }
            }
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table using InnerTable +BSJ 03/17/10
}

############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
    my ( $self, $name, $sortIdx, $mouseOverName ) = @_;

    my $linkTarget = $WebUtil::linkTarget;
    my $baseUrl    = $self->{baseUrl};
    my $transpose  = $self->{transpose};
    my $procId     = $$;
    my $url        = $baseUrl;
    $url .= "&procId=$procId";
    $url .= "&sortIdx=$sortIdx";
    print "<th class='img'>";
    my $target;
    $target = "target='$linkTarget'" if $linkTarget ne "";
    my $title;
    $mouseOverName =~ s/'//g;
    $title = "title='$mouseOverName'" if $mouseOverName ne "";
    print "<a href='$url' $target $title>$name</a>";
    print "</a>\n";
    print "</th>\n";
}

############################################################################
# sortMatrixRecs - Sort matrix records.
############################################################################
sub sortMatrixRecs {
    my ( $self, $recs_ref, $outRecs_ref ) = @_;

    my $transpose = $self->{transpose};

    my $sortIdx = param("sortIdx");
    $sortIdx = 0 if $sortIdx eq "";

    my @sortVals;
    my $nRecs = @$recs_ref;
    for ( my $i = 0 ; $i < $nRecs ; $i++ ) {
        my $r       = $recs_ref->[$i];
        my @f       = split( /\t/, $r );
        my $sortVal = $f[$sortIdx] . "\t" . $i;
        push( @sortVals, $sortVal );
    }

    ## Field names
    my @sortVals2;
    my $colFence = 2;
    if ( $sortIdx < $colFence ) {
        @sortVals2 = sort(@sortVals);
    }
    ## Counts in taxons
    else {
        @sortVals2 = reverse( sort { $a <=> $b } (@sortVals) );
    }

    ## Copy records by sorted indices
    for my $i (@sortVals2) {
        my ( $sortVal, $idx ) = split( /\t/, $i );
        my $r = $recs_ref->[$idx];
        push( @$outRecs_ref, $r );
    }
}

############################################################################
# val2Color - Map value to color.
############################################################################
sub val2Color {
    my ($val) = @_;
    my $color = "white";
    if ( $val >= 1 && $val <= 4 ) {
        $color = "bisque";
    }
    if ( $val >= 5 ) {
        $color = "yellow";
    }
    return $color;
}

############################################################################
# printProfileGenes - Print gene list for cell or go directly to
#   gene page.
############################################################################
sub printProfileGenes {
    my ($self)   = @_;
    
    my $gene_workspace_id = param("gene_oid");
    my $taxonBin = param("taxonBin");
    my $data_type = param("data_type");

    my $tbDesc;
    if ( $taxonBin !~ /:/ ) {
        my $type = substr( $taxonBin, 0, 1 );
        my $oid = substr( $taxonBin, 1 );
        $taxonBin = "$type:$oid";
        
        my $taxonBin2Desc = $self->{taxonBin2Desc};
        $tbDesc   = $taxonBin2Desc->{$taxonBin};
    }
    my $cells        = $self->{cells};
    my $k            = "$gene_workspace_id-$taxonBin";
    my $workspace_id_str = $cells->{$k};
    my @gene_oids    = split( /\t/, $workspace_id_str );

    if ( scalar(@gene_oids) == 1 ) {
        my $workspace_id = $gene_oids[0];
        if ( WebUtil::isInt($workspace_id) ) {
            use GeneDetail;
            GeneDetail::printGeneDetail( $workspace_id );
            return;            
        }
        else {
            use MetaGeneDetail;
            MetaGeneDetail::printGeneDetail( $workspace_id );
            return;            
        }
    }

    my $gene_oid;
    if ( WebUtil::isInt($gene_workspace_id) ) {
        $gene_oid = $gene_workspace_id;
    }
    else {
        my ($t_oid, $d_type, $g_oid) = split( / /, $gene_workspace_id );
        $gene_oid = $g_oid;                    
    }
    my $subTitile = qq{
        Gene ID: $gene_oid
        <br/>
        Genome: $tbDesc
    };

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    
    my $dbh = dbLogin();
    HtmlUtil::printGeneListHtmlTable( 'Profile Genes', $subTitile, $dbh, $dbOids_ref, $metaOids_ref );
}

############################################################################
# checkBigEuks - Check for large model organisms.
############################################################################
sub checkBigEuks {
    my ( $dbh, $geneOids_ref ) = @_;

    my $gene_oid_str = join( ',', @$geneOids_ref );
    return "" if blankStr($gene_oid_str);

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@$geneOids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my $bad_str;
    if ( scalar(@dbOids) > 0 ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@dbOids );
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
          select g.gene_oid
          from gene g, taxon tx
          where g.taxon = tx.taxon_oid
          and tx.is_big_euk = 'Yes'
          and g.gene_oid in( select id from gtt_num_id )
          $rclause
          $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;
            $bad_str .= "$gene_oid,";
        }
        $cur->finish();
        chop $bad_str;
    }

    return $bad_str;
}

1;
