#
#
#
# $Id: ScaffoldSearch.pm 33963 2015-08-10 23:37:20Z jinghuahuang $

package ScaffoldSearch;
use POSIX qw(ceil floor); 
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use HTML::Template;
use MetaUtil;
use MerFsUtil;
use OracleUtil;
use WebConfig;
use WebUtil;
$| = 1;

my $section                  = "ScaffoldSearch";
my $env                      = getEnv();
my $main_cgi                 = $env->{main_cgi};
my $verbose                  = $env->{verbose};
my $show_sql_verbosity_level = $env->{show_sql_verbosity_level};
my $base_url                 = $env->{base_url};
my $top_base_url             = $env->{top_base_url};
my $domain_name              = $env->{domain_name};
my $img_submit_url           = $env->{img_submit_url};
my $base_dir                 = $env->{base_dir};
my $cgi_url                  = $env->{cgi_url};
my $cgi_dir                  = $env->{cgi_dir};
my $cgi_tmp_dir              = $env->{cgi_tmp_dir};
my $tmp_dir                  = $env->{tmp_dir};
my $include_metagenomes      = $env->{include_metagenomes};
my $scaffold_cart = $env->{scaffold_cart};

## We use the max count for both gene and scaffold display
my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults"); 
} 

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
} 
## Let's try 10 min to see how it works
$merfs_timeout_mins = 10;


sub dispatch {
    my ($numTaxon) = @_;

    my $page = param('page');
    if ( $page eq 'searchResult' ) {
        printResults();
    } else {
        printSearchForm($numTaxon);
    }
}

# if not blank and a integer
sub notBlankAndInt {
    my ( $name, $x ) = @_;
    if ( !blankStr($x) && !isInt($x) ) {
        webError("$name must be a integer.");
    }
}

sub pairCheck {
    my ( $name, $low, $high ) = @_;

    if ( blankStr($low) && blankStr($high) ) {
        return;
    } elsif ( !blankStr($low) && blankStr($high) ) {
        webError("$name high value cannot be empty.");
    } elsif ( blankStr($low) && !blankStr($high) ) {
        webError("$name low value cannot be empty.");
    } elsif ( $low > $high ) {
        webError("$name low value cannot be greater than the high value.");
    } elsif ( $low < 0 ) {
        webError("$name low value cannot be less than zero.");
    } elsif ( $high < 0 ) {
        webError("$name high value cannot be less than zero.");
    }
}

# run scaffold search
sub printResults {

    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("searchTerm");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $searchResults_ref, $trunc );

    if ( $searchFilter eq 'scaffoldId' 
    || $searchFilter eq 'scaffoldName' 
    || $searchFilter eq 'extAccession' ) {

        if ( $searchFilter eq 'scaffoldId' ) {
            WebUtil::processSearchTermCheck($searchTerm, 'Scaffold ID');
            $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
            my @scaffoldOids = WebUtil::splitTerm( $searchTerm, 0, 0 );
            # list of ids separated by a comma and or white space
            #my $scaffoldId = $searchTerm;
            #my @scaffoldOids;
            #if ( $scaffoldId ne '' ) {
            #    $scaffoldId =~ s/\s+|,/ /g;
            #    @scaffoldOids = split( / /, $scaffoldId );
            #    #print "printResults() scaffold Ids: @scaffoldOids<br>\n";
            #}
            ( $searchResults_ref, $trunc ) 
                = processIdSearchResults( $dbh, \@scaffoldOids );
        }
        elsif ( $searchFilter eq 'scaffoldName' ) {
            WebUtil::processSearchTermCheck($searchTerm, 'Scaffold Name');
            $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
            my $scaffoldName_lc = lc($searchTerm);  # only of isolates
            ( $searchResults_ref, $trunc ) 
                = processNameAccessionSearchResults( $dbh, $scaffoldName_lc );
        }
        elsif ( $searchFilter eq 'extAccession' ) {
            WebUtil::processSearchTermCheck($searchTerm, 'Scaffold External Accession');
            $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
            my $searchTerm_lc = lc($searchTerm);  # only of isolates
            my @extAccession_lc = WebUtil::splitTerm( $searchTerm_lc, 0, 0 );
            #print "printResults() extAccession_lc: @extAccession_lc<br>\n";
            ( $searchResults_ref, $trunc )
                = processNameAccessionSearchResults( $dbh, '', \@extAccession_lc );
        }

        print qq{
            <h1>Scaffold Search Results</h1>  
        };
        print "<p>\n";
        if ( $searchFilter eq 'scaffoldId' ) {
            print "Filter: Scaffold ID<br/>\n";
        }
        elsif ( $searchFilter eq 'scaffoldName' ) {
            print "Filter: Scaffold Name<br/>\n";
        }
        elsif ( $searchFilter eq 'extAccession' ) {
            print "Filter: Scaffold External Accession<br/>\n";
        }
        print "Keyword: " . $searchTerm;
        print "</p>\n";
    }
    elsif ( $searchFilter eq 'statisticsParameter' ) {
        # genome selection
        my @taxonOids     = param("selectedGenome1");
        my $data_type     = param('q_data_type');

        if ( $#taxonOids < 0 ) {
            webError("Please select at least one genome");
        }

        my $gcLow         = param('gcLow');
        my $gcHigh        = param('gcHigh');
        my $seqLengthLow  = param('seqLengthLow');
        my $seqLengthHigh = param('seqLengthHigh');
        my $geneCountLow  = param('geneCountLow');
        my $geneCountHigh = param('geneCountHigh');
    
        # applies only to metagenomes
        my $readDepthLow       = param('readDepthLow');
        my $readDepthHigh      = param('readDepthHigh');
        my $lineagePercentLow  = param('lineagePercentLow');
        my $lineagePercentHigh = param('lineagePercentHigh');
        my $domain             = param('domain');
        my $phylum             = param('phylum');
        my $class              = param('class');
        my $order              = param('order');
        my $family             = param('family');
        my $genus              = param('genus');
        my $species            = param('species');
    
        if (   blankStr($gcLow)
            && blankStr($gcHigh)
            && blankStr($seqLengthLow)
            && blankStr($seqLengthHigh)
            && blankStr($geneCountLow)
            && blankStr($geneCountHigh)
            && blankStr($readDepthLow)
            && blankStr($readDepthHigh)
            && blankStr($lineagePercentLow)
            && blankStr($lineagePercentHigh)
            && $domain  eq 'none'
            && $phylum  eq 'none'
            && $class   eq 'none'
            && $order   eq 'none'
            && $family  eq 'none'
            && $genus   eq 'none'
            && $species eq 'none' )
        {
            webError("Please set a search criteria.");
        }
    
        # param pre checks
        # 1. at least one genome
        # 2. at least one of the scaffold params excluding genome param
        # 3. low and high params low <= high the pair is required and one cannot be blank
        notBlankAndInt( 'GC', $gcLow );
        notBlankAndInt( 'GC', $gcHigh );
        pairCheck( 'GC', $gcLow, $gcHigh );
        notBlankAndInt( 'Sequence Length', $seqLengthLow );
        notBlankAndInt( 'Sequence Length', $seqLengthHigh );
        pairCheck( 'Sequence Length', $seqLengthLow, $seqLengthHigh );
        notBlankAndInt( 'Gene Count', $geneCountLow );
        notBlankAndInt( 'Gene Count', $geneCountHigh );
        pairCheck( 'Gene Count', $geneCountLow, $geneCountHigh );
    
        if ($include_metagenomes) {
            notBlankAndInt( 'Read Depth', $readDepthLow );
            notBlankAndInt( 'Read Depth', $readDepthHigh );
            pairCheck( 'Read Depth', $readDepthLow, $readDepthHigh );
            notBlankAndInt( 'Lineage Percentage', $lineagePercentLow );
            notBlankAndInt( 'Lineage Percentage', $lineagePercentHigh );
            pairCheck( 'Lineage Percentage', $lineagePercentLow, $lineagePercentHigh );
        }
    
        ( $searchResults_ref, $trunc ) = processStatPramSearchResults( $dbh, '', '', 
            $gcLow, $gcHigh, $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh, 
            $readDepthLow, $readDepthHigh, $lineagePercentLow, $lineagePercentHigh,
            $domain, $phylum, $class, $order, $family, $genus, $species,
            \@taxonOids, $data_type );


        print qq{
            <h1>Scaffold Search Results</h1>  
        };     
        print "<p>\n";
        print "Filter: Scaffold Statistics Parameter<br/>\n";
        print "GC Percentage (0-100): $gcLow - $gcHigh<br/>\n" 
            if ( ! blankStr($gcLow) || ! blankStr($gcHigh) );
        print "Sequence Length (bp): $seqLengthLow - $seqLengthHigh<br/>\n" 
            if ( ! blankStr($seqLengthLow) || ! blankStr($seqLengthHigh) );
        print "Gene Count: $geneCountLow - $geneCountHigh<br/>\n" 
            if ( ! blankStr($geneCountLow) || ! blankStr($geneCountHigh) );
        if ($include_metagenomes) {
            print "Read Depth: $readDepthLow - $readDepthHigh<br/>\n" 
                if ( ! blankStr($readDepthLow) || ! blankStr($readDepthHigh) );
            print "Lineage Percentage (0-100): $lineagePercentLow - $lineagePercentHigh<br/>\n" 
                if ( ! blankStr($lineagePercentLow) || ! blankStr($lineagePercentHigh) );
            print "Lineage Domain: $domain<br/>\n" if ( ! blankStr($domain) && $domain ne 'none' );
            print "Lineage Phylum: $phylum<br/>\n" if ( ! blankStr($phylum) && $phylum ne 'none' );
            print "Lineage Class: $class<br/>\n" if ( ! blankStr($class) && $class ne 'none' );
            print "Lineage Order: $order<br/>\n" if ( ! blankStr($order) && $order ne 'none' );
            print "Lineage Family: $family<br/>\n" if ( ! blankStr($family) && $family ne 'none' );
            print "Lineage Genus: $genus<br/>\n" if ( ! blankStr($genus) && $genus ne 'none' );
            print "Lineage Species: $species<br/>\n" if ( ! blankStr($species) && $species ne 'none' );
        }        
        print "</p>\n";
    }

    printResultPage( $searchResults_ref, $trunc );
}

sub processIdSearchResults {
    my ( $dbh, $scaffoldOids_ref ) = @_;

    my @searchResults;
    my $trunc = 0;
    my $count = 0;

    my ( $dbOids_ref, $metaOids_ref ) 
        = MerFsUtil::splitDbAndMetaOids(@$scaffoldOids_ref);

    my @notFoundOids;
    if ( scalar(@$dbOids_ref) > 0 ) {
        my $rclause = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');

        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @$dbOids_ref );

        my $sql = qq{
            select s.scaffold_oid, s.scaffold_name, s.ext_accession, s.taxon, 
                st.seq_length, st.gc_percent, s.read_depth, st.count_total_gene, 
                t.taxon_display_name, t.genome_type, t.domain
            from scaffold s, scaffold_stats st, taxon t
            where s.scaffold_oid in ($ids_str)
              and s.scaffold_oid = st.scaffold_oid
              and s.taxon = st.taxon
              and s.taxon = t.taxon_oid
            $rclause
            $imgClause
        };
    
        my $cur = execSql( $dbh, $sql, $verbose );
        my %foundOids_h;
        for ( ; ; ) {
            my (
                $scaffold_oid,       $scaffold_name, $ext_acc,    $taxon_oid,
                $seq_length,         $gc_percent,    $read_depth, $gene_count,
                $taxon_display_name, $genome_type,   $domain
            ) = $cur->fetchrow();
            last if !$scaffold_oid;
            $foundOids_h{$scaffold_oid} = 1;
    
            my $tmp = "$scaffold_oid\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
            $tmp .= "$seq_length\t$gc_percent\t$read_depth\t$gene_count\t";
            $tmp .= "$taxon_display_name\t$genome_type\t$domain";
            push( @searchResults, $tmp );
    
            $count++;
            if ( $count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );
            
        if ( scalar(keys %foundOids_h) < scalar(@$dbOids_ref) ) {
            foreach my $oid (@$dbOids_ref) {
                if ( $oid && (! $foundOids_h{$oid}) ) {
                    push(@notFoundOids, $oid);
                }
            }
        }
    }
    
    if ( !$trunc 
        && (scalar(@notFoundOids) > 0 || scalar(@$metaOids_ref) > 0) ) {
        my @metaOids;
        push(@metaOids, @notFoundOids) if ( scalar(@notFoundOids) > 0 );
        push(@metaOids, @$metaOids_ref) if ( scalar(@$metaOids_ref) > 0 );
        #print "processIdSearchResults() metaOids: @metaOids, size=" . scalar(@metaOids) . "<br>\n";

        my ($taxonDataType2metaOids_href, $taxons_href) 
            = findMetaScaf2TaxonMap( $dbh, @metaOids );

        my @taxonOids = keys %$taxons_href;
        my ( $taxon_name_href, $genome_type_href ) 
            = QueryUtil::fetchTaxonOid2NameGenomeTypeHash( $dbh, \@taxonOids );

        timeout( 60 * $merfs_timeout_mins ); 
        my $start_time  = time();
        my $timeout_msg = ""; 
    
        printStartWorkingDiv(); 

        foreach my $taxon_oid_data_type (keys %$taxonDataType2metaOids_href) {
            #print "processIdSearchResults() taxon_oid_data_type=$taxon_oid_data_type<br>\n";
            if ( ! $trunc ) {
                my $meta_oids_ref = $taxonDataType2metaOids_href->{$taxon_oid_data_type};
                my ( $taxon_oid, $data_type ) = split( / /, $taxon_oid_data_type );
                ($trunc, $count) = processScaffoldMetagenome( $dbh, 
                    $taxon_oid, $data_type, $taxon_name_href, $genome_type_href, $meta_oids_ref,
                    \@searchResults, $maxGeneListResults, $trunc, $count, $start_time );                
            }
        } # end for loop

        printEndWorkingDiv(); 
    }
    

    return ( \@searchResults, $trunc );
}

sub findMetaScaf2TaxonMap {
    my ( $dbh, @metaOids ) = @_;

    my %metaOid2idPrefix;
    my %idPrefix2metaOids;
    my %idPrefixes_h;
    foreach my $oid (@metaOids) {
        my $id_prefix;
        if ( $oid =~ /\_/ ) {
            my @tokens = split( /\_/, $oid );
            $id_prefix = $tokens[0];
        }
        else {
            $id_prefix = substr($oid, 0, 6);
            
        }
        $idPrefixes_h{$id_prefix} = 1;
        $metaOid2idPrefix{$oid} = $id_prefix;

        if ( $idPrefix2metaOids{$id_prefix} ) {
            my $mOids_ref = $idPrefix2metaOids{$id_prefix};
            push(@$mOids_ref, $oid);
        }
        else {
            my @mOids = ( $oid );
            $idPrefix2metaOids{$id_prefix} = \@mOids;
        }
    }
    #print "findMetaScaf2TaxonMap() idPrefixes_h:<br/>\n";
    #print Dumper(\%idPrefixes_h)."<br/>\n";

    my %taxonDataType2metaOids;    
    my %taxons_h;
    
    my @idPrefixes = keys %idPrefixes_h;
    if ( scalar(@idPrefixes) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @idPrefixes );
        #print "findMetaScaf2TaxonMap() ids_str=$ids_str<br>\n";
        
        my $sql = qq{
            select taxon_oid, id_prefix, data_type
            from taxon_scaf_prefix
            where id_prefix in ($ids_str)
        };
        #print "findMetaScaf2TaxonMap() sql=$sql<br>\n";
    
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my (
                $taxon_oid, $id_prefix, $data_type
            ) = $cur->fetchrow();
            last if !$taxon_oid;
            $taxons_h{$taxon_oid} = 1;
            
            my $taxon_oid_data_type = "$taxon_oid $data_type";
            my $mOids_ref = $idPrefix2metaOids{$id_prefix};

            if ( $taxonDataType2metaOids{$taxon_oid_data_type} ) {
                my $meta_oids_ref = $taxonDataType2metaOids{$taxon_oid_data_type};
                push(@$meta_oids_ref, @$mOids_ref);
            }
            else {
                my @meta_oids = @$mOids_ref;
                $taxonDataType2metaOids{$taxon_oid_data_type} = \@meta_oids;
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
    #print "findMetaScaf2TaxonMap() taxonDataType2metaOids:<br/>\n";
    #print Dumper(\%taxonDataType2metaOids)."<br/>\n";

    return (\%taxonDataType2metaOids, \%taxons_h);
}


sub processScaffoldMetagenome {
    my ( $dbh, $taxon_oid, $data_type, $taxon_name_href, $genome_type_href, $oids_ref,
        $results_aref, $max_rows, $trunc, $count, $start_time,
        $readDepthLow, $readDepthHigh, 
        $lineagePercentLow, $lineagePercentHigh, $lineagePerClause, $has_lineage_cond, 
        $domain, $phylum, $class, $order, $family, $genus, $species, 
        $lenClause, $gcClause, $geneClause ) = @_;

    if ( $trunc ) {
        last;
    }

    my $large_block_size = MetaUtil::getLargeBlockSize();
    my $cnt0 = 0;
    if ( $oids_ref ) {
        $cnt0 = scalar(@$oids_ref);
    }

    if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) )  < 200 ) { 
        $trunc = $taxon_oid;
        last; 
    } 

    my $taxon_display_name = $taxon_name_href->{$taxon_oid};
    print "<p>searching ($taxon_oid) $taxon_display_name ...<br/>\n";

    my $singleScaffoldStatsFile = MetaUtil::getSingleSdbScaffoldStatsFile( $taxon_oid, $data_type );
    if ( ! $singleScaffoldStatsFile ) {
        print "<p>Metagenome $taxon_oid has no assembled data.<br/>\n";
        next;
    }

    ## reads depth
    my %scaf_depth_h;
    my $has_depth_sdb = 0;

    my $singleScaffoldDepthFile = MetaUtil::getSingleSdbScaffoldDepthFile( $taxon_oid, $data_type );
    if ( $singleScaffoldDepthFile ne '' && -e $singleScaffoldDepthFile ) {
        ## Amy: cannot filter read depth because: 
        ## (1) we don't store depth = 1,
        ## (2) we need to round depth

        print "checking reads depth ...<br/>\n";
        my $sql3 = "select scaffold_oid, depth from scaffold_depth ";

        if ( $oids_ref && scalar(@$oids_ref) > 0 ) {
            my $cnt1     = 0;
            my $oids_str = '';
            for my $oid (@$oids_ref) {
                if ($oids_str) {
                    $oids_str .= ", '" . $oid . "'";
                } else {
                    $oids_str = "'" . $oid . "'";
                }
                $cnt1++;
                if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    my $sql = $sql3 . " where scaffold_oid in ($oids_str)";
                    my (%scaffoldDepths) = MetaUtil::fetchScaffoldDepthForTaxonFromSqlite( 
                        $taxon_oid, $data_type, $singleScaffoldDepthFile, $sql );
                    if ( scalar( keys %scaffoldDepths ) > 0 ) {
                        foreach my $id3 ( keys %scaffoldDepths ) {
                            my $depth3 = $scaffoldDepths{$id3};
                            if ( ! $depth3 ) {
                                $depth3 = 1;
                            }
                            $scaf_depth_h{$id3} = $depth3;
                        }
                    }
                    $oids_str = '';
                }
            }    #end of for scaffoldDepthFile
        }
        else {
            my (%scaffoldDepths) = MetaUtil::fetchScaffoldDepthForTaxonFromSqlite( 
                $taxon_oid, $data_type, $singleScaffoldDepthFile, $sql3 );
            if ( scalar( keys %scaffoldDepths ) > 0 ) {
                foreach my $id3 ( keys %scaffoldDepths ) {
                    my $depth3 = $scaffoldDepths{$id3};
                    if ( ! $depth3 ) {
                        $depth3 = 1;
                    }
                    $scaf_depth_h{$id3} = $depth3;
                }
            }
        }
        
        $has_depth_sdb = 1;
    }
    elsif ( $readDepthLow || $readDepthHigh ) {
        # cannot eval this condition
        next;
    }

    if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 ) { 
        $trunc = $taxon_oid;
        last; 
    } 

    ## lineage
    my %scaf_lineage_h;
    my $singleScaffoldLineageFile = MetaUtil::getSingleSdbScaffoldLineageFile( $taxon_oid, $data_type );
    if ( $singleScaffoldLineageFile && -e $singleScaffoldLineageFile ) {
        print "checking scaffold lineage ...<br/>\n";
        my $sql3 = qq{
            select scaffold_oid, lineage, percentage, rank 
            from contig_lin
            where scaffold_oid is not null
            $lineagePerClause
        };

        if ( $oids_ref && scalar(@$oids_ref) > 0 ) {
            my $cnt1     = 0;
            my $oids_str = '';
            for my $oid (@$oids_ref) {
                if ($oids_str) {
                    $oids_str .= ", '" . $oid . "'";
                } else {
                    $oids_str = "'" . $oid . "'";
                }
                $cnt1++;
                if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    my $sql = $sql3 . " and scaffold_oid in ($oids_str) ";
                    my (%scaffoldLineages) = MetaUtil::fetchScaffoldLineageForTaxonFromSqlite( 
                        $taxon_oid, $data_type, $singleScaffoldLineageFile, $sql );
                    if ( scalar( keys %scaffoldLineages ) > 0 ) {
                        foreach my $id3 ( keys %scaffoldLineages ) {
                            my ( $lin3, $perc3, $rank ) = split( /\t/, $scaffoldLineages{$id3} );
                            ## need to process lineage
                            if ( $perc3 ) {
                                $perc3 *= 100;
                            }
                            $scaf_lineage_h{$id3} = $lin3 . "\t" . $perc3;
                        }
                    }
                    $oids_str = '';
                }
            }            
        }
        else {
            my (%scaffoldLineages) = MetaUtil::fetchScaffoldLineageForTaxonFromSqlite( 
                $taxon_oid, $data_type, $singleScaffoldLineageFile, $sql3 );
            if ( scalar( keys %scaffoldLineages ) > 0 ) {
                foreach my $id3 ( keys %scaffoldLineages ) {
                    my ( $lin3, $perc3, $rank ) = split( /\t/, $scaffoldLineages{$id3} );
                    ## need to process lineage
                    if ( $perc3 ) {
                        $perc3 *= 100;
                    }
                    $scaf_lineage_h{$id3} = $lin3 . "\t" . $perc3;
                }
            }
        }
    }
    elsif ( $has_lineage_cond || $lineagePercentLow || $lineagePercentHigh ) {
        ## cannot eval this condition
        next;
    }

    print "checking scaffold stats information ...<br/>\n";
    if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) )  < 200 ) { 
        $trunc = $taxon_oid;
        last; 
    } 

    if ( -e $singleScaffoldStatsFile ) {
        my $sql3 = qq{
            select scaffold_oid, length, gc, n_genes
            from scaffold_stats
            where scaffold_oid is not null
            $lenClause 
            $gcClause
            $geneClause 
        };
        #print "processScaffoldMetagenome() sql3=$sql3<br/>\n";

        if ( $oids_ref && scalar(@$oids_ref) > 0 ) {
            my $cnt1         = 0;
            my $oid_str = '';
            for my $oid (@$oids_ref) {
                if ($oid_str) {
                    $oid_str .= ", '" . $oid . "'";
                } else {
                    $oid_str = "'" . $oid . "'";
                }
                $cnt1++;
                if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    my $sql = $sql3 . " and scaffold_oid in ($oid_str)";
                    my (%scaffoldStats) = MetaUtil::fetchScaffoldStatsForTaxonFromSqlite( 
                        $taxon_oid, $data_type, $singleScaffoldStatsFile, $sql );
                    #print Dumper(\%scaffoldStats);
                    if ( scalar( keys %scaffoldStats ) > 0 ) {
                        foreach my $scaffold_oid ( keys %scaffoldStats ) {
                            my ( $length, $gc, $n_genes ) = split( /\t/, $scaffoldStats{$scaffold_oid} );

                            ## depth cond?
                            my $read_depth = 1;
                            if ( $has_depth_sdb ) {
                                if ( $scaf_depth_h{$scaffold_oid} ) {
                                    $read_depth = $scaf_depth_h{$scaffold_oid};
                                }
                            }
                            if ( isInt($readDepthLow) && $read_depth < $readDepthLow ) {
                                next;
                            }
                            if ( isInt($readDepthHigh) && $read_depth > $readDepthHigh ) {
                                next;
                            }
                        
                            ## lineage cond?
                            if ( $lineagePerClause ) {
                                if ( ! $scaf_lineage_h{$scaffold_oid} ) {
                                    ## filter out
                                    next;
                                }
                            }
                            if ( $has_lineage_cond ) {
                                my $lin_res = 1;
                                my @lin = split(/\;/, $scaf_lineage_h{$scaffold_oid});
                                my $j = 0;
                                for my $x ($domain, $phylum, $class, $order, 
                                       $family, $genus, $species) {
                                    if ( $x && $x ne 'none' ) {
                                        my $y = "";
                                        if ( $j < scalar(@lin) ) {
                                            $y = $lin[$j];
                                        }
                                        if ( lc($y) ne lc($x) ) {
                                            $lin_res = 0;
                                            last;
                                        }
                                    }
                                    $j++;
                                }
                    
                                if ( ! $lin_res ) {
                                    next;
                                }
                            }
                        
                            my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
                            my $scaffold_name = $scaffold_oid;
                            my $ext_acc;
                            my $genome_type = $genome_type_href->{$taxon_oid};
                        
                            my $tmp = "$workspace_id\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
                            $tmp .= "$length\t$gc\t$read_depth\t$n_genes\t";
                            $tmp .= "$taxon_display_name\t$genome_type\t$domain";
                            if ( $scaf_lineage_h{$scaffold_oid} ) {
                                $tmp .= "\t" . $scaf_lineage_h{$scaffold_oid};
                            }
                            else {
                                $tmp .= "\t\t";
                            }
                        
                            if ( $count >= $max_rows ) {
                                $trunc = 1;
                                last;
                            }
                        
                            # good record
                            push( @$results_aref, $tmp );
                            $count++;
                        }
                    }
                    $oid_str = '';
                }
            }
        }
        else {
            my (%scaffoldStats) = MetaUtil::fetchScaffoldStatsForTaxonFromSqlite( 
                $taxon_oid, $data_type, $singleScaffoldStatsFile, $sql3 );
            #print Dumper(\%scaffoldStats);
            if ( scalar( keys %scaffoldStats ) > 0 ) {
                foreach my $scaffold_oid ( keys %scaffoldStats ) {
                    my ( $length, $gc, $n_genes ) = split( /\t/, $scaffoldStats{$scaffold_oid} );

                    ## depth cond?
                    my $read_depth = 1;
                    if ( $has_depth_sdb ) {
                        if ( $scaf_depth_h{$scaffold_oid} ) {
                            $read_depth = $scaf_depth_h{$scaffold_oid};
                        }
                    }
                    if ( isInt($readDepthLow) && $read_depth < $readDepthLow ) {
                        next;
                    }
                    if ( isInt($readDepthHigh) && $read_depth > $readDepthHigh ) {
                        next;
                    }
                        
                    ## lineage cond?
                    if ( $lineagePerClause ) {
                        if ( ! $scaf_lineage_h{$scaffold_oid} ) {
                            ## filter out
                            next;
                        }
                    }
                    if ( $has_lineage_cond ) {
                        my $lin_res = 1;
                        my @lin = split(/\;/, $scaf_lineage_h{$scaffold_oid});
                        my $j = 0;
                        for my $x ($domain, $phylum, $class, $order, 
                               $family, $genus, $species) {
                            if ( $x && $x ne 'none' ) {
                                my $y = "";
                                if ( $j < scalar(@lin) ) {
                                    $y = $lin[$j];
                                }
                                if ( lc($y) ne lc($x) ) {
                                    $lin_res = 0;
                                    last;
                                }
                            }
                            $j++;
                        }
                    
                        if ( ! $lin_res ) {
                            next;
                        }
                    }
                        
                    my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
                    my $scaffold_name = $scaffold_oid;
                    my $ext_acc;
                    my $genome_type = $genome_type_href->{$taxon_oid};
                        
                    my $tmp = "$workspace_id\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
                    $tmp .= "$length\t$gc\t$read_depth\t$n_genes\t";
                    $tmp .= "$taxon_display_name\t$genome_type\t$domain";
                    if ( $scaf_lineage_h{$scaffold_oid} ) {
                        $tmp .= "\t" . $scaf_lineage_h{$scaffold_oid};
                    }
                    else {
                        $tmp .= "\t\t";
                    }
                        
                    if ( $count >= $max_rows ) {
                        $trunc = 1;
                        last;
                    }
                        
                    # good record
                    push( @$results_aref, $tmp );
                    $count++;
                }
            }
        }

    }

    return ($trunc, $count);
}

sub processNameAccessionSearchResults {
    my ( $dbh, $scaffoldName, $extAccessions_lc_ref ) = @_;

    my $trunc = 0;
    my @searchResults;
    
    $trunc = findScaffoldByAccession( $dbh, 
        \@searchResults, $maxGeneListResults, $scaffoldName, $extAccessions_lc_ref);

    return ( \@searchResults, $trunc );
    
}

#####################################################################
# findScaffoldByAccession: for database genomes
#####################################################################
sub findScaffoldByAccession {
    my ( $dbh, $results_aref, $max_rows, $scaffoldName_lc, $extAccessions_lc_ref ) = @_;
    
    my $count = scalar(@$results_aref);
    my $trunc = 0;
    my @binds;

    my $nameClause;
    if ( $scaffoldName_lc ) {
        $nameClause = " and lower(s.scaffold_name) like ? ";
        push(@binds, "%$scaffoldName_lc%");
    }

    my $extAccessionClause;
    if ( $extAccessions_lc_ref && scalar(@$extAccessions_lc_ref) > 0 ) {
        my $str = OracleUtil::getFuncIdsInClause( $dbh, @$extAccessions_lc_ref );
        $extAccessionClause = " and lower(s.ext_accession) in ($str) ";
    }

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select s.scaffold_oid, s.scaffold_name, s.ext_accession, s.taxon, st.seq_length,
            st.gc_percent, s.read_depth, st.count_total_gene, 
            t.taxon_display_name, t.genome_type, t.domain
        from scaffold s, scaffold_stats st, taxon t
        where s.scaffold_oid = st.scaffold_oid
          and s.taxon = st.taxon
          and s.taxon = t.taxon_oid
          and st.taxon =  t.taxon_oid
        $nameClause
        $extAccessionClause
        $rclause
        $imgClause
    };
    #print "findScaffoldByAccession() sql=$sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
            $scaffold_oid,       $scaffold_name, $ext_acc,    $taxon_oid,
            $seq_length,         $gc_percent,    $read_depth, $gene_count,
            $taxon_display_name, $genome_type,   $domain, $ext_accession

        ) = $cur->fetchrow();
        last if !$scaffold_oid;

        my $tmp = "$scaffold_oid\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
        $tmp .= "$seq_length\t$gc_percent\t$read_depth\t$gene_count\t";
        $tmp .= "$taxon_display_name\t$genome_type\t";
        $tmp .= "$domain";

        if ( $count >= $max_rows ) {
            $trunc = 1;
            last;
        }

        # good record
        push( @$results_aref, $tmp );
        $count++;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
        if ( $extAccessionClause =~ /gtt_func_id/i );        
    
    return $trunc;
}

#
# since metagenomes in oracle do not have contigLin.assembled.sdb data,
# there's no need to split taxons based on genome_type
# split taxons based on in_file is enough
#
sub processStatPramSearchResults {
    my ( $dbh, $scaffoldName, $extAccession, $gcLow, $gcHigh, 
        $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh, 
        $readDepthLow, $readDepthHigh, $lineagePercentLow, $lineagePercentHigh,
        $domain, $phylum, $class, $order, $family, $genus, $species,
        $taxonOids_aref, $data_type ) = @_;

    my $trunc = 0;
    my @searchResults;

    my @dbTaxonOids;      # list of database taxon oids
    my @metaTaxonOids;    # list of MERFS metagenome taxon oids
    if ($include_metagenomes) {
        my ( $dbTaxons_ref, $metaTaxons_ref ) 
            = MerFsUtil::findTaxonsInFile( $dbh, @$taxonOids_aref );
        @dbTaxonOids = @$dbTaxons_ref;
        @metaTaxonOids = @$metaTaxons_ref;
    } else {
        @dbTaxonOids = @$taxonOids_aref;
    }

    if ( scalar(@dbTaxonOids) <= 0 && $#metaTaxonOids > -1 && $include_metagenomes ) {
        if (    blankStr($gcLow)
             && blankStr($gcHigh)
             && blankStr($seqLengthLow)
             && blankStr($seqLengthHigh)
             && blankStr($geneCountLow)
             && blankStr($geneCountHigh)
             && blankStr($readDepthLow)
             && blankStr($readDepthHigh)
             && blankStr($lineagePercentLow)
             && blankStr($lineagePercentHigh)
             && $domain  eq 'none'
             && $phylum  eq 'none'
             && $class   eq 'none'
             && $order   eq 'none'
             && $family  eq 'none'
             && $genus   eq 'none'
             && $species eq 'none' )
        {
            webError("Please set a search criteria for MER-FS metagenome(s).");
        }
    }
    
    if ( $#dbTaxonOids > -1 && scalar(@metaTaxonOids) <= 0 ) {
        if (    blankStr($gcLow)
             && blankStr($gcHigh)
             && blankStr($seqLengthLow)
             && blankStr($seqLengthHigh)
             && blankStr($geneCountLow)
             && blankStr($geneCountHigh)
             && blankStr($readDepthLow)
             && blankStr($readDepthHigh) )
        {
            webError("Please set a search criteria for genomes.");
        }
    }

    # debug section
    #my $debug_msg = 0;
    #if ( $debug_msg ) {
    #    print qq{
    #        gc: $gcLow $gcHigh <br>
    #        seq leng: $seqLengthLow $seqLengthHigh <br>
    #        gene cnt: $geneCountLow $geneCountHigh <br>
    #        read: $readDepthLow $readDepthHigh <br>
    #        lineage perc: $lineagePercentLow $lineagePercentHigh <br>
    #        d: $domain<br>
    #        p: $phylum<br>
    #        c: $class<br>
    #        o: $order<br>
    #        f: $family<br>
    #        g: $genus<br>
    #        s: $species<br>
    #        taxon database: @dbTaxonOids<br>
    #        taxon merfs: @metaTaxonOids<br>
    #        dt: $data_type<br>
    #    };
    #}
    # end of debug section

    if ( $#dbTaxonOids > -1 ) {
        #lineage search not applicable to database genomes
        if (    blankStr($lineagePercentLow)
             && blankStr($lineagePercentHigh)
             && $domain  eq 'none'
             && $phylum  eq 'none'
             && $class   eq 'none'
             && $order   eq 'none'
             && $family  eq 'none'
             && $genus   eq 'none'
             && $species eq 'none' )
        {
            $trunc = findScaffoldDatabase( $dbh, \@dbTaxonOids, 
                \@searchResults, $maxGeneListResults, '', '', 
                $gcLow, $gcHigh, $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh, 
                $readDepthLow, $readDepthHigh);
        }
    }

    if ( $include_metagenomes && $#metaTaxonOids > -1 && ! $trunc ) {
        $trunc = findScaffoldMerfs( $dbh, \@metaTaxonOids, 
            \@searchResults, $maxGeneListResults, 
            $gcLow, $gcHigh, $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh,
            $readDepthLow, $readDepthHigh, $lineagePercentLow, $lineagePercentHigh,
            $domain, $phylum, $class, $order, $family, $genus, $species, $data_type);
    }

    return ( \@searchResults, $trunc );
    
}

sub printResultPage {
    my ( $searchResults_aref, $trunc ) = @_;

    printMainForm();

    my $it = new InnerTable( 0, "scaffoldSearch$$", 'scaffoldSearch', 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Scaffold ID",              "asc", "left" );
    $it->addColSpec( "Scaffold Name",            "asc", "left" );
    $it->addColSpec( "External Accession",       "asc", "left" );
    $it->addColSpec( "Genome",                   "asc", "left" );
    $it->addColSpec( "Gene Count",               "asc", "right" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "asc", "right" );
    $it->addColSpec( "GC Content",               "asc", "right" );
    if ($include_metagenomes) {
        $it->addColSpec( "Read Depth",         "asc", "right" );
        $it->addColSpec( "Lineage Domain",    "asc", "left" );
        $it->addColSpec( "Lineage Phylum",    "asc", "left" );
        $it->addColSpec( "Lineage Class",     "asc", "left" );
        $it->addColSpec( "Lineage Order",     "asc", "left" );
        $it->addColSpec( "Lineage Family",    "asc", "left" );
        $it->addColSpec( "Lineage Genus",     "asc", "left" );
        $it->addColSpec( "Lineage Species",   "asc", "left" );
        $it->addColSpec( "Lineage Percentage", "asc", "right" );
    }

    foreach my $line (@$searchResults_aref) {
        my (
            $workspace_id,       $scaffold_name, $ext_acc,    $taxon_oid,
            $seq_length,         $gc_percent,    $read_depth, $gene_count,
            $taxon_display_name, $genome_type,   $domain,
            $lineage,            $lineage_perc
        ) = split( /\t/, $line );

        my $scaffold_oid;
        my $url2;
        my $url3;
        my $scaf_len_url;
        if ( ! WebUtil::isInt($workspace_id) ) {
            my ($t2, $d2, $g2) = split(/ /, $workspace_id);
            $scaffold_oid = $g2;
            $url2 = "$main_cgi?section=MetaDetail" 
                . "&page=metaScaffoldDetail" 
                . "&scaffold_oid=$scaffold_oid" 
                . "&taxon_oid=$t2&data_type=$d2";
            $url3 = "$main_cgi?section=MetaDetail" 
                . "&page=metaScaffoldGenes" 
                . "&scaffold_oid=$scaffold_oid" 
                . "&taxon_oid=$t2&data_type=$d2";
            $scaf_len_url = "$main_cgi?section=MetaScaffoldGraph" 
                . "&page=metaScaffoldGraph" 
                . "&scaffold_oid=$scaffold_oid" 
                . "&taxon_oid=$t2&data_type=$d2";
        }
        else {
            $scaffold_oid = $workspace_id;
            $url2 = "$main_cgi?section=ScaffoldCart" 
                . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
            $url3 = "$main_cgi?section=ScaffoldCart" 
                . "&page=scaffoldGenes&scaffold_oid=$scaffold_oid";
            $scaf_len_url = "$main_cgi?section=ScaffoldGraph"
                . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid"
                . "&taxon_oid=$taxon_oid"
                . "&start_coord=1&end_coord=$seq_length"
                . "&seq_length=$seq_length";            
        }

        my $r;
        $r .= "$sd<input type='checkbox' name='scaffold_oid' value='$workspace_id' />\t";
        $r .= $scaffold_oid . $sd . alink( $url2, $scaffold_oid ) . "\t";
        $r .= $scaffold_name . $sd . "$scaffold_name\t";
        $r .= $ext_acc . $sd . "$ext_acc\t";
    
        my $url = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
    
        if ( $gene_count eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $gene_count . $sd . alink( $url3, $gene_count ) . "\t";
        }
    
        $r .= $seq_length . $sd . alink( $scaf_len_url, $seq_length ) . "\t";
    
        $gc_percent = sprintf( " %.2f", $gc_percent );
        $r .= $gc_percent . $sd . "$gc_percent\t";
    
        if ($include_metagenomes) {
            $r .= $read_depth . $sd . "$read_depth\t";
            my @lin = split(/\;/, $lineage);
            for (my $j = 0; $j < 7; $j++) {
                if ( $j < scalar(@lin) ) {
                    $r .= $sd . $lin[$j] . "\t";
                }
                else {
                    $r .= $sd . "" . "\t";
                }
            }
            $r .= $sd . $lineage_perc . "\t";   #lineage percentage
        }
    
        $it->addRow($r);
    }

    my $size = scalar(@$searchResults_aref);
    if ( $size <= 0 ) {
        print "<h4>No scaffolds satisfy the search criteria.</h4>\n";
        printStatusLine( "$size Loaded.", 2 );
        print end_form();
        return;
    }
    my $select_id_name = "scaffold_oid"; 

    WebUtil::printScaffoldCartFooter() if ( $size > 10 && $scaffold_cart );
    $it->printOuterTable(1);

    if ($scaffold_cart) {
        my $name   = "_section_ScaffoldCart_addToScaffoldCart";
        my $errMsg = "Please make one or more selections.";
        print submit(
            -name    => $name, 
            -value   => "Add Selected to Scaffold Cart", 
            -class   => "meddefbutton",
            -onClick => "return isChecked ('scaffold_oid', '$errMsg');"
        ); 
    } 
    print nbsp(1);
    print "\n";
    WebUtil::printButtonFooterInLine(); 
    print "<br>\n";
    if ( $size > 0 && $scaffold_cart ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    if ( $trunc > 1 ) {
        my $s =
            "Process takes too long to run " 
            . "-- stopped at $trunc. " 
            . "Only partial result is displayed. "
            . "$size Loaded.";
            printStatusLine( $s, 2 );
        } elsif ($trunc) { 
            my $s = "Results limited to $maxGeneListResults scaffolds.\n";
            $s .= "( Go to "
                . alink( $preferences_url, "Preferences" )
                . " to change \"Max. Scaffold List Results\". )\n";
            printStatusLine( $s, 2 );
        } else {
        printStatusLine( "$size Loaded.", 2 );
    }
    print end_form();
}


##################################################################
# findScaffoldMerfs: for MERFS metagenomes
##################################################################
sub findScaffoldMerfs {
    my ( $dbh, $taxonOids_aref, $results_aref, $max_rows, 
        $gcLow, $gcHigh, $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh,
        $readDepthLow, $readDepthHigh, $lineagePercentLow, $lineagePercentHigh,
        $domain, $phylum, $class, $order, $family, $genus, $species, $data_type ) = @_;

    my $count = scalar(@$results_aref);
    my $trunc = 0;

    my $gcClause;
    if ( $gcLow ne '' ) {
        $gcLow  = $gcLow / 100  if ( $gcLow > 0 );
        $gcHigh = $gcHigh / 100 if ( $gcHigh > 0 );
        $gcClause = "and gc between $gcLow and $gcHigh";
    }

    my $lenClause;
    if ( $seqLengthLow ne '' ) {
        $lenClause = "and length between $seqLengthLow and $seqLengthHigh";
    }

    my $geneClause;
    if ( $geneCountLow ne '' ) {
        $geneClause = "and n_genes between $geneCountLow and $geneCountHigh";
    }

    my $readClause;
    if ( $readDepthLow ne '' ) {
        $readClause = "and depth between $readDepthLow and $readDepthHigh";
    }

    my $lineagePerClause;
    if ( $lineagePercentLow ne '' ) {
        $lineagePercentLow  = $lineagePercentLow / 100  if ( $lineagePercentLow > 0 );
        $lineagePercentHigh = $lineagePercentHigh / 100 if ( $lineagePercentHigh > 0 );
        $lineagePerClause = " and percentage between $lineagePercentLow and $lineagePercentHigh";
    }

    ## is there a condition on lineage?
    my $has_lineage_cond = 0;
    for my $x ($domain, $phylum, $class, $order, $family, $genus, $species) {
    	if ( $x && $x ne 'none' ) {
    	    $has_lineage_cond = 1;
    	    last;
    	}
    }

    my ( $taxon_name_href, $genome_type_href ) 
        = QueryUtil::fetchTaxonOid2NameGenomeTypeHash( $dbh, $taxonOids_aref );


    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time  = time();
    my $timeout_msg = ""; 

    printStartWorkingDiv(); 

    my @dataTypes = MetaUtil::getDataTypeList($data_type);
    foreach my $dataType (@dataTypes) {
        foreach my $taxon_oid (@$taxonOids_aref) {
            if ( ! $trunc ) {
                ($trunc, $count) = processScaffoldMetagenome( $dbh, 
                    $taxon_oid, $data_type, $taxon_name_href, $genome_type_href, '',
                    $results_aref, $max_rows, $trunc, $count, $start_time,
                    $readDepthLow, $readDepthHigh, 
                    $lineagePercentLow, $lineagePercentHigh, $lineagePerClause, $has_lineage_cond, 
                    $domain, $phylum, $class, $order, $family, $genus, $species, 
                    $lenClause, $gcClause, $geneClause );
            }            
        } # end for loop my $taxon_oid (@$taxonOids_aref)
    }

    printEndWorkingDiv(); 

    return $trunc;
}

#####################################################################
# findScaffoldOracleMeta: for Oracle metagenome
#
# since metagenomes in oracle do not have contigLin.assembled.sdb data,
# there's no need to split taxons based on genome_type
# below method is obsolete
#####################################################################
sub findScaffoldOracleMeta {
    my ( $dbh, $taxonOids_aref, $results_aref, $max_rows, 
        $scaffoldName, $extAccession, $gcLow, $gcHigh, 
        $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh,
        $readDepthLow, $readDepthHigh, $lineagePercentLow, $lineagePercentHigh,
        $domain, $phylum, $class, $order, $family, $genus, $species, $data_type ) = @_;

    my $count = scalar(@$results_aref);
    my $trunc = 0;

    ## we only have assembled
    if ( $data_type eq 'unassembled' ) {
    	return $trunc;
    }
    $data_type = 'assembled';

    my @bind;
    my $gcClause;
    if ( $gcLow ne '' ) {
        $gcLow  = $gcLow / 100  if ( $gcLow > 0 );
        $gcHigh = $gcHigh / 100 if ( $gcHigh > 0 );
        $gcClause = "and st.gc_percent between ? and ?";
        push( @bind, $gcLow );
        push( @bind, $gcHigh );
    }

    my $lenClause;
    if ( $seqLengthLow ne '' ) {
        $lenClause = "and st.seq_length between ? and ?";
        push( @bind, $seqLengthLow );
        push( @bind, $seqLengthHigh );
    }

    my $geneClause;
    if ( $geneCountLow ne '' ) {
        $geneClause = "and st.count_total_gene between ? and ?";
        push( @bind, $geneCountLow );
        push( @bind, $geneCountHigh );
    }

    my $readClause;
    if ( $readDepthLow ne '' ) {
        $readClause = "and read_depth between $readDepthLow and $readDepthHigh";
    } 
 
    my $lineagePerClause;
    if ( $lineagePercentLow ne '' ) {
        $lineagePercentLow  = $lineagePercentLow / 100  
	    if ( $lineagePercentLow > 0 ); 
        $lineagePercentHigh = $lineagePercentHigh / 100 
	    if ( $lineagePercentHigh > 0 );
        $lineagePerClause = " and percentage between $lineagePercentLow and $lineagePercentHigh"; 
    } 

    ## is there a condition on lineage?
    my $has_lineage_cond = 0;
    for my $x ($domain, $phylum, $class, $order, $family,
               $genus, $species) {
        if ( $x && $x ne 'none' ) {
            $has_lineage_cond = 1; 
            last;
        }
    } 

    ## lineage                                                         
    my %scaf_lineage_h;
    if ( $taxonOids_aref && scalar(@$taxonOids_aref) > 0 ) {
        foreach my $taxon_oid (@$taxonOids_aref) {
            my $singleScaffoldLineageFile = MetaUtil::getSingleSdbScaffoldLineageFile( $taxon_oid, $data_type ); 
            if ( $singleScaffoldLineageFile ne '' &&
                 -e $singleScaffoldLineageFile ) { 
                my $dbh3 = WebUtil::sdbLogin($singleScaffoldLineageFile)
                or next; 
                my $sql3 = "select scaffold_oid, lineage, percentage from contig_lin where scaffold_oid is not null ";
                if ( $lineagePerClause ) {
                    $sql3 .= $lineagePerClause;
                } 
        
                my $sth  = $dbh3->prepare($sql3); 
                $sth->execute();
                for (;;) {
                    my ( $id3, $lin3, $perc3 ) = $sth->fetchrow_array();
                    last if ! $id3; 
        
                    ## need to process lineage
                    if ( $perc3 ) { 
                        $perc3 *= 100; 
                    } 
                    $scaf_lineage_h{$id3} = $lin3 . "\t" . $perc3; 
                } 
                $sth->finish(); 
                $dbh3->disconnect(); 
            } 
        }        
    }

    my $taxonOidClause;
    if ( scalar(@$taxonOids_aref) > 0 ) {
        my $str = OracleUtil::getTaxonIdsInClause( $dbh, @$taxonOids_aref );
        $taxonOidClause = " and t.taxon_oid in ($str) ";
    }

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select s.scaffold_oid, s.scaffold_name, s.ext_accession, s.taxon, st.seq_length,
            st.gc_percent, s.read_depth, st.count_total_gene, 
            t.taxon_display_name, t.genome_type, t.domain
        from scaffold s, scaffold_stats st, taxon t
        where s.scaffold_oid = st.scaffold_oid
          and s.taxon = st.taxon
          and s.taxon = t.taxon_oid
          and st.taxon =  t.taxon_oid
        $taxonOidClause
        $gcClause
        $lenClause
        $geneClause
        $readClause
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my (
            $scaffold_oid,       $scaffold_name, $ext_acc,    $taxon_oid,
            $seq_length,         $gc_percent,    $read_depth, $gene_count,
            $taxon_display_name, $genome_type,   $domain

        ) = $cur->fetchrow();
        last if !$scaffold_oid;

    	$genome_type = "meta_oracle";
        my $tmp = "$scaffold_oid\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
        $tmp .= "$seq_length\t$gc_percent\t$read_depth\t$gene_count\t";
        $tmp .= "$taxon_display_name\t$genome_type\t$domain";

        if ( $scaffoldName ) {
            if ( $scaffold_name =~ /$scaffoldName/i ) {
                # good record
                # do nothing here
            } else {
                next;
            }
        }
        
        if ( $extAccession ) {
            if ( $ext_acc =~ /$extAccession/i ) {
                # good record
                # do nothing here
            } else {
                next;
            }
        }

    	## lineage cond?
    	if ( $lineagePerClause ) { 
    	    if ( ! $scaf_lineage_h{$scaffold_oid} ) {
        		## filter out
        		next; 
    	    } 
    	} 
    	if ( $has_lineage_cond ) {
    	    my $lin_res = 1;
    	    my @lin = split(/\;/, $scaf_lineage_h{$scaffold_oid});
    	    my $j = 0;
    	    for my $x ($domain, $phylum, $class, $order, $family, $genus, $species) {
        		if ( $x && $x ne 'none' ) {
        		    my $y = "";
        		    if ( $j < scalar(@lin) ) {
            			$y = $lin[$j];
        		    }
        		    if ( lc($y) ne lc($x) ) { 
            			$lin_res = 0; 
            			last; 
        		    } 
        		} 
        		$j++;
    	    }
     
    	    if ( ! $lin_res ) {
        		next; 
    	    } 
    	} 
    
    	if ( $count >= $max_rows ) {
    	    $trunc = 1;
    	    last;
    	}

        # good record
        push( @$results_aref, $tmp );
    	$count++;
    }
    $cur->finish();
    
    return $trunc;
}

#####################################################################
# findScaffoldDatabase: for database genomes
#####################################################################
sub findScaffoldDatabase {
    my ( $dbh, $taxonOids_aref, $results_aref, $max_rows, 
        $scaffoldName, $extAccession, $gcLow, $gcHigh, 
        $seqLengthLow, $seqLengthHigh, $geneCountLow, $geneCountHigh, 
        $readDepthLow, $readDepthHigh ) = @_;
    
    my $count = scalar(@$results_aref);
    my $trunc = 0;

    my @bind;
    my $gcClause;
    if ( $gcLow ne '' ) {
        $gcLow  = $gcLow / 100  if ( $gcLow > 0 );
        $gcHigh = $gcHigh / 100 if ( $gcHigh > 0 );
        $gcClause = "and st.gc_percent between ? and ?";
        push( @bind, $gcLow );
        push( @bind, $gcHigh );
    }

    my $lenClause;
    if ( $seqLengthLow ne '' ) {
        $lenClause = "and st.seq_length between ? and ?";
        push( @bind, $seqLengthLow );
        push( @bind, $seqLengthHigh );
    }

    my $geneClause;
    if ( $geneCountLow ne '' ) {
        $geneClause = "and st.count_total_gene between ? and ?";
        push( @bind, $geneCountLow );
        push( @bind, $geneCountHigh );
    }

    #applicable for metagenome in database
    my $readClause;
    if ( $readDepthLow ne '' ) {
        $readClause = "and s.read_depth between $readDepthLow and $readDepthHigh";
    } 

    my $taxonOidClause;
    if ( $taxonOids_aref && scalar(@$taxonOids_aref) > 0 ) {
        my $str = OracleUtil::getTaxonIdsInClause( $dbh, @$taxonOids_aref );
        $taxonOidClause = " and t.taxon_oid in ($str) ";
    }

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select s.scaffold_oid, s.scaffold_name, s.ext_accession, s.taxon, st.seq_length,
            st.gc_percent, s.read_depth, st.count_total_gene, 
            t.taxon_display_name, t.genome_type, t.domain
        from scaffold s, scaffold_stats st, taxon t
        where s.scaffold_oid = st.scaffold_oid
          and s.taxon = st.taxon
          and s.taxon = t.taxon_oid
          and st.taxon =  t.taxon_oid
          $taxonOidClause
          $gcClause
          $lenClause
          $geneClause
          $readClause
          $rclause
          $imgClause
    };
    #print "findScaffoldDatabase() sql=$sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my (
            $scaffold_oid,       $scaffold_name, $ext_acc,    $taxon_oid,
            $seq_length,         $gc_percent,    $read_depth, $gene_count,
            $taxon_display_name, $genome_type,   $domain, $ext_accession

        ) = $cur->fetchrow();
        last if !$scaffold_oid;

        my $tmp = "$scaffold_oid\t$scaffold_name\t$ext_acc\t$taxon_oid\t";
        $tmp .= "$seq_length\t$gc_percent\t$read_depth\t$gene_count\t";
        $tmp .= "$taxon_display_name\t$genome_type\t$domain";

        if ( $scaffoldName ) {
            if ( $scaffold_name =~ /$scaffoldName/i ) {
                # good record
                # do nothing here
            } else {
                next;
            }
        }
        
        if ( $extAccession ) {
            if ( $ext_acc =~ /$extAccession/i ) {
                # good record
                # do nothing here
            } else {
                next;
            }
        }

    	if ( $count >= $max_rows ) {
    	    $trunc = 1;
    	    last;
    	}

        # good record
        push( @$results_aref, $tmp );
    	$count++;
    }
    $cur->finish();
    
    return $trunc;
}

#
# scaffold search form
#
sub printSearchForm {
    my ($numTaxon) = @_;

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printJavaScript();

    my $template = HTML::Template->new( filename => "$base_dir/ScaffoldSearch.html" );
    my $searchNote = qq{
        <p>
        Find scaffolds in selected genomes.  It's required to add selections into "<b>Selected Genomes</b>" unless blocked.
    };
    if ($include_metagenomes) {
        $searchNote .= qq{
            Only assembled metagenomes will be displayed.
            <br/>
            <b>*</b>MER-FS Metagenome supported search filters.
        };
    }
    $searchNote .= qq{
        </p>
    };
    $template->param( searchNote => $searchNote );

    my $super;
    my $caseNote;
    my $noMerFsNote;
    my $noMerFsNote0;
    if ($include_metagenomes) {
        $super    = ' *';
        $caseNote = ', case-sensitive for MER-FS Metagenome';
        $noMerFsNote = ', no MER-FS Metagenome';
        $noMerFsNote0 = '(no MER-FS Metagenome)';
    }
    my $searchFilterOptions = qq{
        <option value='scaffoldId'>Scaffold ID (List$caseNote)$super</option>
        <option value='scaffoldName'>Scaffold Name $noMerFsNote0</option>
        <option value='extAccession'>Scaffold External Accession (List$noMerFsNote)</option>
        <option value='statisticsParameter'>Scaffold Statistics Parameters$super</option>
    };
    $template->param( searchFilterOptions => $searchFilterOptions );

    if ($include_metagenomes) {
        $template->param( include_metagenomes => 1 );
    }

    my $aref1 = getDomainCv($dbh);
    my $aref2 = getPhylumCv($dbh);
    my $aref3 = getClassCv($dbh);
    my $aref4 = getOrderCv($dbh);
    my $aref5 = getFamilyCv($dbh);
    my $aref6 = getGenusCv($dbh);
    my $aref7 = getSpeciesCv($dbh);

    my $str1 = printSelectBox( 'domain',  $aref1 );
    my $str2 = printSelectBox( 'phylum',  $aref2 );
    my $str3 = printSelectBox( 'class',   $aref3 );
    my $str4 = printSelectBox( 'order',   $aref4 );
    my $str5 = printSelectBox( 'family',  $aref5 );
    my $str6 = printSelectBox( 'genus',   $aref6 );
    my $str7 = printSelectBox( 'species', $aref7 );

    $template->param( selectDomain  => $str1 );
    $template->param( selectPhylum  => $str2 );
    $template->param( selectClass   => $str3 );
    $template->param( selectOrder   => $str4 );
    $template->param( selectFamily  => $str5 );
    $template->param( selectGenus   => $str6 );
    $template->param( selectSpecies => $str7 );

    print $template->output;
    print "<br>\n";

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ( $hideViruses eq "" || $hideViruses eq "Yes" ) ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ( $hidePlasmids eq "" || $hidePlasmids eq "Yes" ) ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ( $hideGFragment eq "" || $hideGFragment eq "Yes" ) ? 0 : 1;

    my $xml_cgi  = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( isolate      => 1 );
    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => 100 );
    $template->param( from       => 'ScaffoldSearch' );
    $template->param(selectedGenome1Title => 'max. 100 genomes' );

    if ($include_metagenomes) {
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 0 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    my $button = GenomeListJSON::printMySubmitButtonXDiv(
          'go',     'Search',       'Go',      '',
          $section, 'searchResult', 'smdefbutton', 'selectedGenome1',
                                                          1
    );
    print $button;

    #print nbsp( 1 );
    #print reset( -class => "smbutton" );

    GenomeListJSON::showGenomeCart($numTaxon);

    printStatusLine( "Loaded.", 2 );
    print end_form();

}

sub printJavaScript {
    print qq{
        <script type="text/javascript" >
            for (var i=0; i <showOrHideArray.length; i++) {
                showOrHideArray[i]=new Array(2);
            }
            //select options that permit hiding
            showOrHideArray[0][0] = "scaffoldId";
            showOrHideArray[0][1] = "scaffoldName";
            showOrHideArray[0][2] = "extAccession"; 

            var hideAreaArray = ["statPramTableRow", "genomeFilterArea"];
            var showAreaArray = ["keywordTableRow"];

            YAHOO.util.Event.on("toHide", "change", function(e) {
                for (var i=0; i <hideAreaArray.length; i++) {
                    var hideArea = hideAreaArray[i];
                    if ( hideArea != undefined && hideArea != null && hideArea != '' ) {
                        determineHideDisplayType('toHide', hideArea);
                    }
                }
                for (var i=0; i <showAreaArray.length; i++) {
                    var showArea = showAreaArray[i];
                    if ( showArea != undefined && showArea != null && showArea != '' ) {
                        determineShowDisplayType('toHide', showArea);
                    }
                }
            });

            window.onload = function() {
                //window.alert("window.onload");
                for (var i=0; i <hideAreaArray.length; i++) {
                    var hideArea = hideAreaArray[i];
                    if ( hideArea != undefined && hideArea != null && hideArea != '' ) {
                        determineHideDisplayType('toHide', hideArea);
                    }
                }
                for (var i=0; i <showAreaArray.length; i++) {
                    var showArea = showAreaArray[i];
                    if ( showArea != undefined && showArea != null && showArea != '' ) {
                        determineShowDisplayType('toHide', showArea);
                    }
                }
            }

            for (var i=0; i <termLengthArray.length; i++) {
                termLengthArray[i]=new Array(2);
            }
            //select options that need to length validation
            termLengthArray[0][0] = "scaffoldId"; 
            termLengthArray[0][1] = "scaffoldName";
            termLengthArray[0][1] = "extAccession";
            
        </script>
    };
}

sub getDomainCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct domain 
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getDomainCv' );

    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getPhylumCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct phylum
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getPhylumCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getClassCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct ir_class
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getClassCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getOrderCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct ir_order
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getOrderCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getFamilyCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct family
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getFamilyCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getGenusCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct genus
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getGenusCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub getSpeciesCv {
    my ($dbh) = @_;

    my $sql = qq{
select distinct species
from taxon
where genome_type = 'isolate'
order by 1
    };

    my $data_aref = OracleUtil::execSqlCached( $dbh, $sql, $section . '_getSpeciesCv' );
    my @data;
    foreach my $inner_aref (@$data_aref) {
        my $name = $inner_aref->[0];
        push( @data, $name );
    }
    return \@data;
}

sub printSelectBox {
    my ( $name, $aref ) = @_;

    my $str = "<select name='$name'>\n";
    $str .= "<option value='none'>Select ---</option>";

    foreach my $val (@$aref) {
        $str .= "<option value='$val'>$val</option>\n";
    }

    $str .= "</select>\n";

    return $str;
}

1;
