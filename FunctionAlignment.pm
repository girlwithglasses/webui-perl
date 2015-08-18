############################################################################
# FunctionAlignment.pm - new tool
#
# $Id: FunctionAlignment.pm 31652 2014-08-14 05:59:25Z jinghuahuang $
############################################################################
package FunctionAlignment;
my $section = "FunctionAlignment";

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use FunctionAlignmentUtil;
use GenomeListFilter;
use TabViewFrame;
use MerFsUtil;

# Force flush
$| = 1;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $tmp_dir               = $env->{tmp_dir};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $enable_genomelistJson = $env->{enable_genomelistJson};
my $img_ken               = $env->{img_ken};
my %function2Name = (
      cog  => "COG",
      kog  => "KOG",
      pfam => "Pfam",
      all  => "All"
);

############################################################################
# dispatch - Dispatch to pages for this section.
############################################################################
sub dispatch {

    my $page = param("page");
    timeout( 60 * 180 );    # timeout in 3 hrs
    if ( paramMatch("showAlignmentForGene") ) {
        printSearchResults(2);
    } elsif ( paramMatch("showAlignmentForFunc") ) {
        printSearchResults(1);
    } elsif ( paramMatch("ffgFunctionAlignment") ne ""
              || $page eq "functionAlignmentSearchForm" )
    {
        printSearchResults(0);
    } elsif ( $page eq "tabForm" ) {
        my $id      = param("id");
        my $tabName = param("tabName");
        my $type    = param("type");

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq{
            <response>
                <div id='$id'><![CDATA[ 
        };
        printTabForm( $id, $tabName, $type );
        print qq {
            ]]></div>
            <name></name>
            </response>
        };
    } else {
        printSearchForm();
    }
}

############################################################################
# printSearchForm - Show basic function alignment search form.
#   Read from template file and replace some template components.
############################################################################
sub printSearchForm {
    my $templateFile = "$base_dir/functionAlignmentSearch.html";
    my $rfh = newReadFileHandle( $templateFile, "printFunctionAlignmentSearchForm" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__searchFilterOptions__/ ) {
            printSearchFilterOptions();
        } elsif ( $s =~ /__genomeListFilter__/ ) {
            my $dbh = dbLogin();
            GenomeListFilter::appendGenomeListFilter($dbh);
            ##$dbh->disconnect();
        } elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        } else {
            print "$s\n";
        }
    }
    close $rfh;
}

############################################################################
# printSearchFilterOptionList - Print options for search filter.
############################################################################
sub printSearchFilterOptions {
    my $s = qq{
        <select name="searchFilter" style="min-width:285px" onChange="showTip(this, 'searchTerm')">
            <option value='cog'>COG</option>
            <option value='kog'>KOG</option>
            <option value='pfam'>Pfam</option>
            <option value='all' title='COG, KOG, Pfam'>All function names*</option>
        </select>
    };
    print "$s\n";
}

############################################################################
# printPageHint - Show this page's hint.
############################################################################
sub printPageHint {

    printWideHint(
        qq{
           All searches treat the keyword as a substring (a word or part of a word). <br/>
           The search should contain some alphanumeric characters. <br/>
           it may use matching metacharacters. <br/>
           Use an underscore (_) as a single-character wildcard. <br/>
           Use % to match zero or more characters. <br/>
           All matches are case insensitive. <br/>
           Very general searches may be slow. <br/>
           Hold down control key (or command key in the case
           of the Mac) to select multiple genomes.<br/>
        }
    );
}

############################################################################
# printSearchResults - Print search results for different cases.
############################################################################
sub printSearchResults {
    my ($type) = @_;    #type: 0 from search form, 1 from function cart, 2 from gene cart

    my $seq_status = param("seqstatus");
    setSessionParam( "seqstatus", $seq_status );
    my $domain = param("domainfilter");
    setSessionParam( "domainfilter", $domain );
    my $taxonChoice = param("taxonChoice");
    setSessionParam( "taxonChoice", $taxonChoice );

    my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections") if ( $type == 0 );
    if ( $type == 1 ) {
        my @ts = OracleUtil::processTaxonBinOids("t");
        my @bs = OracleUtil::processTaxonBinOids("b");

        if ( $enable_genomelistJson ) {
            @ts = OracleUtil::processTaxonBinOids( "t", 'genomeFilterSelections' );
            @bs = OracleUtil::processTaxonBinOids( "b", 'genomeFilterSelections' );
        }

        if ( scalar(@bs) > 0 ) {
            push( @ts, @bs );
            my %hash_t = map { $_ => 1 } @ts;
            @genomeFilterSelections = sort keys %hash_t;
        } else {
            @genomeFilterSelections = @ts;
        }
    } elsif ( $type == 2 ) {
        my @ts = OracleUtil::processTaxonBinOids("t");
        my @bs = OracleUtil::processTaxonBinOids("b");
        if ($enable_genomelistJson) {
            @ts = OracleUtil::processTaxonBinOids( "t", 'genomeFilterSelections' );
            @bs = OracleUtil::processTaxonBinOids( "b", 'genomeFilterSelections' );
        }
        if ( scalar(@bs) > 0 ) {
            push( @ts, @bs );
            my %hash_t = map { $_ => 1 } @ts;
            @genomeFilterSelections = sort keys %hash_t;
        } else {
            @genomeFilterSelections = @ts;
        }
    }
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $searchFilter = '';
    my $searchTermLc = '';
    if ( $type == 0 ) {
        $searchFilter = param("searchFilter");

        my $searchTerm = param("searchTerm");
        WebUtil::processSearchTermCheck($searchTerm);
        $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
        $searchTermLc = $searchTerm;
        $searchTermLc =~ tr/A-Z/a-z/;
        setSessionParam( "searchTermLc", $searchTermLc );
    } elsif ( $type == 1 ) {
        my @func_ids = param("func_id");
        if ( scalar(@func_ids) <= 0 ) {
            webError("Please select at least one function.");
        }
        my @cog_func_ids  = ();
        my @kog_func_ids  = ();
        my @pfam_func_ids = ();
        for ( my $i = 0 ; $i < scalar(@func_ids) ; $i++ ) {
            push( @cog_func_ids,  $func_ids[$i] ) if ( $func_ids[$i] =~ /^cog/i );
            push( @kog_func_ids,  $func_ids[$i] ) if ( $func_ids[$i] =~ /^kog/i );
            push( @pfam_func_ids, $func_ids[$i] ) if ( $func_ids[$i] =~ /^pfam/i );
        }

        my $nCogFunc  = scalar(@cog_func_ids);
        my $nKogFunc  = scalar(@kog_func_ids);
        my $nPfamFunc = scalar(@pfam_func_ids);
        if ( $nCogFunc > 0 && $nKogFunc > 0 && $nPfamFunc > 0 ) {
            $searchFilter = 'all';
            setSessionParam( "cog_func_ids",  \@cog_func_ids );
            setSessionParam( "kog_func_ids",  \@kog_func_ids );
            setSessionParam( "pfam_func_ids", \@pfam_func_ids );
        } elsif ( $nCogFunc > 0 && $nKogFunc <= 0 && $nPfamFunc <= 0 ) {
            $searchFilter = 'cog';
            setSessionParam( "cog_func_ids", \@cog_func_ids );
        } elsif ( $nCogFunc <= 0 && $nKogFunc > 0 && $nPfamFunc <= 0 ) {
            $searchFilter = 'kog';
            setSessionParam( "kog_func_ids", \@cog_func_ids );
        } elsif ( $nCogFunc <= 0 && $nKogFunc <= 0 && $nPfamFunc > 0 ) {
            $searchFilter = 'pfam';
            setSessionParam( "pfam_func_ids", \@pfam_func_ids );
        } else {
            webError("Please select at least one cog, kog, or pfam function.");
        }
    } elsif ( $type == 2 ) {
        $searchFilter = 'all';

        my @gene_oids = param("gene_oid");
        if ( scalar(@gene_oids) <= 0 ) {
            webError("Please select at least one gene.");
        }

        setSessionParam( "gene_oids", \@gene_oids );
    }

    printMainForm();
    my $title = $function2Name{$searchFilter};
    print "<h1>$title Function Alignment Search Results</h1>\n" if ( $type == 0 );
    print "<h1>Function Alignment</h1>\n"                       if ( $type == 1 || $type == 2 );

    TabViewFrame::printTabViewMarkup();

    my @tabNames = ();
    push( @tabNames, "COG" )  if ( $searchFilter eq 'cog'  || $searchFilter eq 'all' );
    push( @tabNames, "KOG" )  if ( $searchFilter eq 'kog'  || $searchFilter eq 'all' );
    push( @tabNames, "Pfam" ) if ( $searchFilter eq 'pfam' || $searchFilter eq 'all' );

    print qq{
        <script type="text/javascript">
            setUrl("xml.cgi?section=FunctionAlignment&page=tabForm&type=$type");
        </script>
    };

    my @tabIds = TabViewFrame::printTabViewWidgetStart(@tabNames);
    if ( scalar(@tabIds) > 0 ) {
        my $dbh = dbLogin();
        TabViewFrame::printTabIdDivStart( $tabIds[0] );
        printTabForm( $tabIds[0], $tabNames[0], $type, $dbh );
        TabViewFrame::printTabIdDivEnd();
        for ( my $i = 1 ; $i < scalar(@tabIds) ; $i++ ) {
            TabViewFrame::printTabIdDivStart( $tabIds[$i] );
            printTabForm( $tabIds[$i], $tabNames[$i], $type, $dbh );
            TabViewFrame::printTabIdDivEnd();

            #callback not working for YUI table
            #TabViewFrame::printTabIdDiv_NoneActive($tabIds[$i]);
        }
        ##$dbh->disconnect();
    }
    TabViewFrame::printTabViewWidgetEnd();
    print end_form();
}

sub printTabForm {
    my ( $tabId, $tabName, $type, $dbh ) = @_;
    my $discNow = 0;

    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $hasGeneCol = 1;

    if ( $dbh eq '' ) {
        $dbh     = dbLogin();
        $discNow = 1;
    }
    my ( $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = getClauses($dbh, $type);    

    my $idsInClause;
    my ( $sql, @bindList );
    if ( $type == 0 ) {
        my $searchTermLc = getSessionParam("searchTermLc");
        $idsInClause = getFuncIdsInClauseForSearch( $dbh, $searchTermLc, $tabName );
        ( $sql, @bindList ) =
          getSqlForFunc( $idsInClause, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref,
                         $tabName )
          if ( !blankStr($idsInClause) );
    } elsif ( $type == 1 ) {
        $idsInClause = getFuncIdsInClauseForFunc( $dbh, $tabName );
        ( $sql, @bindList ) =
          getSqlForFunc( $idsInClause, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref,
                         $tabName )
          if ( !blankStr($idsInClause) );
    } elsif ( $type == 2 ) {
        $idsInClause = getGeneOidsInClause($dbh);
        ( $sql, @bindList ) =
          getSqlForGene( $idsInClause, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref,
                         $tabName, $hasGeneCol )
          if ( !blankStr($idsInClause) );
    }

    my $count = 0;
    if ( !blankStr($sql) ) {
        if ( $tabName eq "COG" ) {
            my $og = "cog";
            my ( $cnt, $recs_ref, $func_ids_ref ) = FunctionAlignmentUtil::execCogSearch( $dbh, $sql, \@bindList );
            if ( $cnt > 0 ) {
                my ( $funcI2desc_href, $funcId2def_href ) = FunctionAlignmentUtil::fetchCogId2Desc( $dbh, $idsInClause );
                $count = FunctionAlignmentUtil::printCogResults( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, $hasGeneCol, $og );
            }
        } elsif ( $tabName eq "KOG" ) {
            my $og = "kog";
            my ( $cnt, $recs_ref, $func_ids_ref ) = FunctionAlignmentUtil::execCogSearch( $dbh, $sql, \@bindList );
            if ( $cnt > 0 ) {
                my ( $funcI2desc_href, $funcId2def_href ) = FunctionAlignmentUtil::fetchKogId2Desc( $dbh, $idsInClause );
                $count = FunctionAlignmentUtil::printCogResults( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, $hasGeneCol, $og );
            }
        } elsif ( $tabName eq "Pfam" ) {
            my ( $cnt, $recs_ref, $func_ids_ref ) = FunctionAlignmentUtil::execPfamSearch( $dbh, $sql, \@bindList );
            if ( $cnt > 0 ) {
                my ( $funcI2desc_href, $doHmm ) = FunctionAlignmentUtil::fetchPfamId2Desc( $dbh, $idsInClause );
                $count = FunctionAlignmentUtil::printPfamResults( $dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm, $hasGeneCol );
            }
        }
    }

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
    }
    printStatusLine( "$count loaded.", 2 );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
}

sub getClauses {
    my ($dbh, $type) = @_;

    my ( $taxonClause, @bindList_txs );

    if ( $type == 0 || $type == 1 ) {        
        my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");
        if ( scalar(@genomeFilterSelections) <= 0 ) {
            my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
            if ( $genomeFilterSelections_ref ne "" && scalar(@$genomeFilterSelections_ref) > 0 ) {
                @genomeFilterSelections = @$genomeFilterSelections_ref;
            }
        } elsif ( $#genomeFilterSelections > -1 ) {
            @genomeFilterSelections = GenomeListJSON::cleanTaxonOid(@genomeFilterSelections);
        }
    
        ( $taxonClause, @bindList_txs ) 
            = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    }    

    my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    return ( $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );
}

sub getFuncIdsInClauseForSearch {
    my ( $dbh, $searchTermLc, $tabName ) = @_;

    my ( $sql, @bindList );
    ( $sql, @bindList ) = getCogSql($searchTermLc)  if ( $tabName eq 'COG' );
    ( $sql, @bindList ) = getKogSql($searchTermLc)  if ( $tabName eq 'KOG' );
    ( $sql, @bindList ) = getPfamSql($searchTermLc) if ( $tabName eq 'Pfam' );
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @func_ids = ();
    for ( ; ; ) {
        my ($func_id) = $cur->fetchrow();
        last if !$func_id;
        push( @func_ids, $func_id );
    }

    my $funcIdsInClause = '';
    if ( scalar(@func_ids) > 0 ) {
        $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @func_ids );
    }

    return ($funcIdsInClause);
}

sub getCogSql {
    my ($searchTermLc) = @_;

    my $lattr1 = lowerAttr("cog.cog_id");
    my $lattr2 = lowerAttr("cog.cog_name");
    my ( $moreWhereClause, @bindList_sql ) =
      OracleUtil::addMoreWhereClause( 'cog', 1, $searchTermLc, $lattr1, $lattr2, '', 0 );

    my $sql = qq{
        select distinct cog.cog_id
        from cog cog
        where ( $moreWhereClause )
    };

    return ( $sql, @bindList_sql );
}

sub getKogSql {
    my ($searchTermLc) = @_;

    my $lattr1 = lowerAttr("kog.kog_id");
    my $lattr2 = lowerAttr("kog.kog_name");
    my ( $moreWhereClause, @bindList_sql ) =
      OracleUtil::addMoreWhereClause( 'kog', 1, $searchTermLc, $lattr1, $lattr2, '', 0 );

    my $sql = qq{
        select distinct kog.kog_id
        from kog kog
        where ( $moreWhereClause )
    };

    return ( $sql, @bindList_sql );
}

sub getPfamSql {
    my ($searchTermLc) = @_;

    my $lattr1 = "lower(pf.ext_accession)";
    my $lattr2 = "lower(pf.name)";
    my $lattr3 = "lower(pf.description)";
    my ( $moreWhereClause, @bindList_sql ) =
      OracleUtil::addMoreWhereClause( 'pfam', 1, $searchTermLc, $lattr1, $lattr2, $lattr3, 1 );

    my $sql = qq{
        select distinct pf.ext_accession
        from pfam_family pf
        where ( $moreWhereClause )
    };

    return ( $sql, @bindList_sql );
}

sub getFuncIdsInClauseForFunc {
    my ( $dbh, $tabName ) = @_;

    my @func_ids = ();
    my $func_ids_ref;
    $func_ids_ref = getSessionParam("cog_func_ids")  if ( $tabName eq 'COG' );
    $func_ids_ref = getSessionParam("kog_func_ids")  if ( $tabName eq 'KOG' );
    $func_ids_ref = getSessionParam("pfam_func_ids") if ( $tabName eq 'Pfam' );
    if ( $func_ids_ref ne "" && scalar(@$func_ids_ref) > 0 ) {
        @func_ids = @$func_ids_ref;
    }

    my $funcIdsInClause = '';
    if ( scalar(@func_ids) > 0 ) {
        $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @func_ids );
    }

    return ($funcIdsInClause);
}

sub getSqlForFunc {
    my ( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $tabName ) = @_;

    my ( $sql, @bindList );
    ( $sql, @bindList ) =
      getCogSqlForFunc( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref )
      if ( $tabName eq "COG" );
    ( $sql, @bindList ) =
      getKogSqlForFunc( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref )
      if ( $tabName eq "KOG" );
    ( $sql, @bindList ) =
      getPfamSqlForFunc( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref )
      if ( $tabName eq "Pfam" );

    return ( $sql, @bindList );
}

sub getCogSqlForFunc {
    my ( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct gcg.gene_oid, gcg.cog, gcg.percent_identity,
            gcg.query_start, gcg.query_end, g.aa_seq_length,
            gcg.evalue, gcg.bit_score,
            tx.taxon_oid, tx.taxon_display_name
        from gene_cog_groups gcg, gene g, taxon tx
        where gcg.cog in ($func_ids_str)
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
        order by gcg.cog, gcg.query_start, gcg.bit_score desc
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getKogSqlForFunc {
    my ( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct gcg.gene_oid, gcg.kog, gcg.percent_identity,
            gcg.query_start, gcg.query_end, g.aa_seq_length,
            gcg.evalue, gcg.bit_score,
            tx.taxon_oid, tx.taxon_display_name
        from gene_kog_groups gcg, gene g, taxon tx
        where gcg.kog in ($func_ids_str)
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
        order by gcg.kog, gcg.query_start, gcg.bit_score desc
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getPfamSqlForFunc {
    my ( $func_ids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct gpf.gene_oid, gpf.pfam_family, gpf.percent_identity,
            gpf.query_start, gpf.query_end, g.aa_seq_length,
            gpf.evalue, gpf.bit_score, 
            tx.taxon_oid, tx.taxon_display_name
        from pfam_family pf, gene_pfam_families gpf, gene g, taxon tx
        where gpf.pfam_family in ( $func_ids_str )
            and gpf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
        order by gpf.pfam_family, gpf.query_start, gpf.bit_score desc
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGeneOidsInClause {
    my ($dbh) = @_;

    my @gene_oids = param("gene_oid");
    if ( scalar(@gene_oids) <= 0 ) {
        my $gene_oids_ref = getSessionParam("gene_oids");
        if ( $gene_oids_ref ne "" && scalar(@$gene_oids_ref) > 0 ) {
            @gene_oids = @$gene_oids_ref;
        }
    }

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    #temp block none-database genes
    if ( scalar(@dbOids) > 0 ) {
        @gene_oids = @dbOids;
    } else {
        webError("You have selected file-based genes.  Please select at least one database gene.");
    }

    my $geneOidsInClause = '';
    if ( scalar(@gene_oids) > 0 ) {
        $geneOidsInClause = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );
    }

    return ($geneOidsInClause);
}

sub getSqlForGene {
    my ( $gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $tabName, $hasGeneCol ) =
      @_;
    my $og = ( $tabName eq "COG" ) ? "cog" : "kog";

    my ( $sql, @bindList );
    ( $sql, @bindList ) =
      FunctionAlignmentUtil::getCogSqlForGene( $gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
                                               $bindList_ur_ref, $hasGeneCol, $og )
      if ( $tabName eq "COG" );
      
    ( $sql, @bindList ) =
      FunctionAlignmentUtil::getCogSqlForGene( $gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
                                               $bindList_ur_ref, $hasGeneCol, $og )
      if ( $tabName eq "KOG" );
      
    ( $sql, @bindList ) =
      FunctionAlignmentUtil::getPfamSqlForGene( $gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
                                                $bindList_ur_ref, $hasGeneCol )
      if ( $tabName eq "Pfam" );

    #print "getSqlForGene() sql: $sql, bindList: @bindList<br/>\n";
    return ( $sql, @bindList );
}

1;

