############################################################################
# BcNpIDSearch.pm - Formerly geneSearch.pl
#
# $Id: BcNpIDSearch.pm 31652 2014-08-14 05:59:25Z jinghuahuang $
############################################################################
package BcNpIDSearch;
my $section = "BcNpIDSearch";

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use ScaffoldPanel;
use CachedTable;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use GeneDetail;
use InnerTable;
use MetaUtil;
use MerFsUtil;
use Data::Dumper;
use FuncUtil;
use WorkspaceUtil;
use GenomeListJSON;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $base_url              = $env->{base_url};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $img_internal          = $env->{img_internal};
my $show_private          = $env->{show_private};
my $tmp_dir               = $env->{tmp_dir};
my $web_data_dir          = $env->{web_data_dir};
my $taxon_faa_dir         = "$web_data_dir/taxon.faa";
my $user_restricted_site  = $env->{user_restricted_site};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes   = $env->{include_metagenomes};
my $search_dir            = ''; # use search_dir "$web_data_dir/search" too slow;
my $flank_length          = 25000;
my $max_gene_batch        = 100;
my $max_rows              = 1000;
my $max_seq_display       = 30;
my $grep_bin              = $env->{grep_bin};
my $rdbms                 = getRdbms();
my $max_taxon_selections  = 1000;
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $cgi_url               = $env->{cgi_url};
my $max_prod_name         = 50;
my $max_genome_selections = 50;
my $mer_data_dir          = $env->{mer_data_dir};
my $in_file               = $env->{in_file};
my $new_func_count        = $env->{new_func_count};
my $enable_biocluster     = $env->{enable_biocluster};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my %function2Name = (
      bc => "Biosynthetic Cluster (BC)",
      np => "Secondary Metabolite (SM)",
);

$| = 1;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {

    my $page = param("page");

    if ( $page eq "findFunctions" ) {
        printFunctionSearchForm();
    } elsif (    paramMatch("ffgFindFunctions") ne ""
              || paramMatch("ffgSearchTerm") ne "" )
    {
        timeout( 60 * 40 );      # timeout in 40 minutes
        printFfgFunctionList();
    } elsif ( $page eq "ffgFindFunctionsGeneList" ) {
        printFfgFindFunctionsGeneList();
    } elsif ( $page eq "ffgFindFunctionsGenomeList" ) {
        printFfgFindFunctionsGenomeList();
    } else {
        printFunctionSearchForm();
    }
}

############################################################################
# printFunctionSearchForm - Show basic gene search form.
#   Read from template file and replace some template components.
############################################################################
sub printFunctionSearchForm {

    my $session = getSession();
    $session->clear( [ "getSearchTaxonFilter", "genomeFilterSelections" ] );

    my $templateFile = "$base_dir/bcNpIDSearch.html";
    my $rfh = newReadFileHandle( $templateFile, "printBcNpIDSearchForm" );

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__searchFilterOptions__/ ) {
            printSearchFilterOptions();
        } elsif ( $img_internal && $s =~ /keggGenomes/ ) {
            print "$s\n";
        } elsif ( $s =~ /__mer_fs_note__/ ) {
            if ($include_metagenomes) {
		printHint("Search term marked by <b>*</b> indicates that it supports metagenomes");
            }
        } else {
            print "$s\n";
        }
    }
    close $rfh;
}

############################################################################
# printSearchFilterOptions - Print options for search filter.
############################################################################
sub printSearchFilterOptions {    

    if ( $enable_biocluster )  {
        my $option = param("option");
        my ( $bcSelect, $npSelect );
        if ( $option eq 'bc' ) {
            $bcSelect = 'selected';
        }
        elsif ( $option eq 'np' ) {
            $npSelect = 'selected';            
        }
        
        my $super;
        if ($include_metagenomes) {
            $super = '*';
        }
        print qq{
           <option value='bc' $bcSelect>Biosynthetic Cluster (list) $super </option>
           <option value='np' $npSelect>Secondary Metabolite (list) </option>
        };
    }    
    
}

############################################################################
# printFfgFunctionList - Show list of functions.  The gene count is
#   show in parenteheses.
#      searchTerm - Search term / expression
#      searcFilter - Search filter or field
############################################################################
sub printFfgFunctionList {
    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("ffgSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    # get the genomes in the selected box:
    #my @genomeFilterSelections = param("selectedGenome1");

    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";

    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %ids_h;
    my @recs;
    my $count = 0;

    my $dbh = dbLogin();
    
    my ( $rclause, @bindList_ur );
    my $imgClause;
    if ( $searchFilter eq "bc" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    elsif ( $searchFilter eq "np" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("np.taxon_oid");
        $imgClause = WebUtil::imgClauseNoTaxon('np.taxon_oid');
    }
    #print "printFfgFunctionList() rclause: $rclause<br/>";
    #print "printFfgFunctionList() imgClause: $imgClause<br/>";

    my ( $merfs_genecnt_href, $merfs_genomecnt_href, $func_id2Name_href );
    if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
        if ( $enable_biocluster ) {
            my $sql;
            my @bindList = ();

            ( $sql, @bindList ) =
              getBcSql_merfs( $searchTermLc, $rclause, $imgClause, \@bindList_ur )
              if $searchFilter eq "bc";
    
            #( $sql, @bindList ) =
            #  getNpSql_merfs( $searchTermLc, $rclause, $imgClause, \@bindList_ur )
            #  if $searchFilter eq "np";                    

            #print "printFfgFunctionList() merfs sql: $sql<br/>";
            #print "printFfgFunctionList() merfs bindList: @bindList<br/>";
            if ( blankStr($sql) && $searchFilter ne "bc" ) {
                webDie( "printFunctionsList: Unknown search filter '$searchFilter'\n" );
            }

            if ( $sql ) {
                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                for ( ; ; ) {
                    my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
                    last if ( !$id );
                    $ids_h{$id} = 1;

                    $func_id2Name_href->{$id}    = $name;
                    $merfs_genecnt_href->{$id}   = $gcnt;
                    $merfs_genomecnt_href->{$id} = $tcnt;
                    #print "printFfgFunctionList() merfs added id: $id<br/>";
                }
                $cur->finish();
            }
        }
    }

    my $sql;
    my @bindList = ();
    if ( $enable_biocluster )  {
        ( $sql, @bindList ) =
          getBcSql( $searchTermLc, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "bc";
        ( $sql, @bindList ) =
          getNpSql( $searchTermLc, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "np";
    }
    #print "printFfgFunctionList() sql: $sql<br/>";
    #print "printFfgFunctionList() bindList: @bindList<br/>";
    if ( blankStr($sql) ) {
        webDie( "printFunctionsList: Unknown search filter '$searchFilter'\n" );
    }

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
        last if ( !$id );
        $ids_h{$id} = 1;

        my $rec = "$id\t";
        $rec .= "$name\t";
        #print "printFfgFunctionList rec: $rec $gcnt $tcnt <br/>\n";

        if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
            if ( exists $merfs_genecnt_href->{$id} ) {
                my $gcnt2 = $merfs_genecnt_href->{$id};
                my $tcnt2 = $merfs_genomecnt_href->{$id};
                $gcnt += $gcnt2;
                $tcnt += $tcnt2;
                delete $merfs_genecnt_href->{$id};
                delete $merfs_genomecnt_href->{$id};
            }
        }
        $rec .= "$gcnt\t";
        $rec .= "$tcnt\t";

        push( @recs, $rec );
        $count++;
    }
    $cur->finish();

    foreach my $key ( keys %$merfs_genecnt_href ) {
        my $name  = $func_id2Name_href->{$key};
        my $gcnt2 = $merfs_genecnt_href->{$key};
        my $tcnt2 = $merfs_genomecnt_href->{$key};
        my $rec   = "$key\t";
        $rec .= "$name\t";
        $rec .= "$gcnt2\t";
        $rec .= "$tcnt2\t";
        push( @recs, $rec );
        $count++;
    }

    #print "printFfgFunctionList recs: @recs<br/>\n";
    #webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    if ( $count == 0 ) {
        printMainForm();
        WebUtil::printNoHitMessage();
        print end_form();
        printStatusLine( "0 retrieved.", 2 );
        return;
    }

    #TabHTML::printTabAPILinks("bcresultTab");
    #my @tabIndex = ( "#bcresulttab1", "#bcresulttab2" );
    #my @tabNames = ( "Overview", "Details" );
    #TabHTML::printTabDiv( "bcresultTab", \@tabIndex, \@tabNames );

    my $cnt;
    #print "<div id='bcresulttab1'>";
    #$cnt = printHtmlTable( $searchTerm, $searchFilter, \@recs );
    #print "</div>\n";

    #print "<div id='bcresulttab2'>";
    my @ids = keys %ids_h;
    my $subTitle = "ID: $searchTerm";
    if ( $searchFilter eq "bc" ) {
        require BiosyntheticDetail;
        BiosyntheticDetail::processBiosyntheticClusters
	    ( $dbh, '', \@ids, '', '', $subTitle );        
    }
    else {
	print "<p>\n";
	print "ID: " . $searchTerm;
	print "</p>\n";
        printMainForm();
        require NaturalProd;
        $cnt = NaturalProd::printNaturalProducts( $dbh, '', \@ids );
        print end_form();
    }
    #print "</div>\n";

    printStatusLine( "$cnt retrieved.", 2 );
    #print "<br/>printFfgFunctionList: $count results retrieved from data, $cnt produced from table<br/>\n" if ($count != $cnt);

}

sub getBcSql {
    my ( $searchTermLc, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( 'BC:', '', $searchTermLc, '', '', 1 );

    my $sql = qq{
        select bcg.cluster_id, NULL, 
            count( distinct bcg.gene_oid ), count( distinct g.taxon )
        from bio_cluster_features_new bcg, bio_cluster_new g
        where bcg.cluster_id in ( $idWhereClause )
        and bcg.cluster_id = g.cluster_id
        $rclause
        $imgClause
        group by bcg.cluster_id
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getBcSql_merfs {
    my ( $searchTermLc, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( 'BC:', '', $searchTermLc, '', '', 1 );

    my $sql = qq{
        select bcg.cluster_id, NULL, 
            count( distinct bcg.feature_id ), count( distinct g.taxon )
        from bio_cluster_features_new bcg, bio_cluster_new g
        where bcg.cluster_id in ( $idWhereClause )
        and bcg.cluster_id = g.cluster_id
        and g.taxon in (
            select t.taxon_oid from taxon t where t.in_file = 'Yes'
        )
        $rclause
        $imgClause
        group by bcg.cluster_id
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getNpSql {
    my ( $searchTermLc, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( '', '', $searchTermLc, 1, 1 );
    my $idClause;
    if ( !WebUtil::blankStr($idWhereClause) ) {
        $idClause = " c.compound_oid in ( $idWhereClause ) or "; 
    }
    $idClause .= " lower(c.compound_name) like ? ";

    #null return if no associated gene
    #my $sql = qq{
    #    select c.compound_oid, c.compound_name,
    #        count( distinct g.gene_oid ), count( distinct g.taxon )
    #    from img_compound c, np_biosynthesis_source np, 
    #        bio_cluster_features bcg, gene g
    #    where ( $idClause )
    #    and c.compound_oid = np.compound_oid
    #    and np.cluster_id = bcg.cluster_id
    #    and bcg.gene_oid = g.gene_oid
    #    $rclause
    #    $imgClause
    #    group by c.compound_oid, c.compound_name
    #};
    my $sql = qq{
        select c.compound_oid, c.compound_name,
            count( distinct bcg.gene_oid ), count( distinct np.taxon_oid )
        from img_compound c, np_biosynthesis_source np, 
            bio_cluster_features_new bcg
        where ( $idClause )
        and c.compound_oid = np.compound_oid
        and np.cluster_id = bcg.cluster_id
        $rclause
        $imgClause
        group by c.compound_oid, c.compound_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getNpSql_merfs {
    my ( $searchTermLc, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( '', '', $searchTermLc, 1, 1 );
    my $idClause;
    if ( !WebUtil::blankStr($idWhereClause) ) {
        $idClause = " c.compound_oid in ( $idWhereClause ) or "; 
    }
    $idClause .= " lower(c.compound_name) like ? ";

    #my $sql = qq{
    #    select c.compound_oid, c.compound_name,
    #        count( distinct bcg.feature_id ), count( distinct g.taxon )
    #    from img_compound c, np_biosynthesis_source np, 
    #        bio_cluster_features bcg, bio_cluster g
    #    where ( $idClause )
    #    and c.compound_oid = np.compound_oid
    #    and np.cluster_id = bcg.cluster_id
    #    and bcg.cluster_id = g.cluster_id
    #    $rclause
    #    $imgClause
    #    group by c.compound_oid, c.compound_name
    #};
    my $sql = qq{
        select c.compound_oid, c.compound_name,
            count( distinct bcg.feature_id ), count( distinct np.taxon_oid )
        from img_compound c, np_biosynthesis_source np, 
            bio_cluster_features_new bcg
        where ( $idClause )
        and c.compound_oid = np.compound_oid
        and np.cluster_id = bcg.cluster_id
        $rclause
        $imgClause
        group by c.compound_oid, c.compound_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub printHtmlTable {
    my ( $searchTerm, $searchFilter, $recs_aref ) = @_;

    my $it = new InnerTable( 1, "function$$", "function", 1 );
    if ( $searchFilter eq 'bc' ) {
        $it->addColSpec( "Cluster ID", "asc", "left" );
    } elsif ( $searchFilter eq 'np' ) {
        $it->addColSpec( "Secondary Metabolite ID", "asc", "left" );
        $it->addColSpec( "Secondary Metabolite Name", "asc", "left" );
    }
    $it->addColSpec( "Gene Count",   "desc", "right" );
    $it->addColSpec( "Genome Count", "desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimit

    my %done;
    my $count = 0;
    for my $rec (@$recs_aref) {
        my ( $id, $name, $gcnt, $tcnt, $metagGcnt, $metagTcnt ) 
            = split( /\t/, $rec );
        next if ( $done{$id} );
        $count++;

        my $r;

        # select column
        #my $tmp;
        #$tmp = "<input type='checkbox' name='func_id' value='BC:$id' />\n"
        #  if $searchFilter eq "bc";
        #$tmp = "<input type='checkbox' name='func_id' value='NP:$id' />\n"
        #  if $searchFilter eq "np";
        #$r .= $sd . $tmp . "\t";

        my $id2 = highlightMatchHTML2( $id, $searchTerm );
        $r .= $id2 . $sd . $id2 . "\t";

        # function name
        if ( $searchFilter ne "bc") {
            my $s = $name;
            my $matchText = highlightMatchHTML2( $s, $searchTerm );
            $r .= $s . $sd . $matchText . "\t";
        }

        # gene count
        my $g_url = "$section_cgi&page=ffgFindFunctionsGeneList";
        $g_url .= "&searchFilter=$searchFilter";
        $g_url .= "&id=$id";
        $g_url .= "&cnt=$gcnt";

        if ( $gcnt > 0 ) {
            $r .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
        } else {
            $r .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=ffgFindFunctionsGenomeList";
        $t_url .= "&searchFilter=$searchFilter";
        $t_url .= "&id=$id";
        $t_url .= "&cnt=$tcnt";

        if ( $tcnt > 0 ) {
            $r .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
        } else {
            $r .= $tcnt . $sd . "0" . "\t";
        }

        $done{$id} = $id;
        $it->addRow($r);
    }

    $it->printOuterTable(1);
    return $count;
}

############################################################################
# printFfgFindFunctionsGeneList - Show gene list of individual counts.
############################################################################
sub printFfgFindFunctionsGeneList {
    my $searchFilter = param("searchFilter");
    my $id           = param("id");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $rclause, @bindList_ur );
    my $imgClause;
    if ( $searchFilter eq "bc" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    elsif ( $searchFilter eq "np" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("np.taxon_oid");
        $imgClause = WebUtil::imgClauseNoTaxon('np.taxon_oid');
    }
    #print "printFfgFindFunctionsGeneList() rclause: $rclause<br/>";
    #print "printFfgFindFunctionsGeneList() imgClause: $imgClause<br/>";

    my $sql;
    my @bindList = ();
    if ( $enable_biocluster )  {
        ( $sql, @bindList ) = getBcGeneListSql( $id, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "bc";
        ( $sql, @bindList ) = getNpGeneListSql( $id, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "np";
    }
    #print "printFfgFindFunctionsGeneList() sql: $sql<br/>";
    #print "printFfgFindFunctionsGeneList() bindList: @bindList<br/>";
    if ( blankStr($sql) ) {
        webDie( "printFfgFunctionsGeneList: Unknown search filter '$searchFilter'\n" );
    }

    my @gene_oids;
    my @meta_genes;
    if ($searchFilter eq "bc") {
        my $cur = execSql( $dbh, $sql, $verbose, @bindList );
        for ( ; ; ) {
            my ( $g_oid, $taxon, $in_file ) = $cur->fetchrow();
            last if !$g_oid;
            if ( $in_file = 'Yes' ) {
                my $workspaceId = "$taxon assembled $g_oid";
                push( @meta_genes, $workspaceId );
            }
            else {
                push( @gene_oids, $g_oid );            
            }
        }
        $cur->finish();        
    }
    elsif ($searchFilter eq "np") {
        @gene_oids = HtmlUtil::fetchGeneList($dbh, $sql, $verbose, @bindList);
    }

    #my $gene_cnt = scalar(@gene_oids);
    #my $trunc    = 0;
    #if ( $gene_cnt >= $maxGeneListResults ) {
    #    $trunc = 1;
    #}
    #if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
    #    if ( $searchFilter eq "bc" ) {            
    #        if ( $enable_biocluster )  {
    #            my @func_ids = ( $id );
    #            my %workspaceIds_href = MetaUtil::getMetaTaxonsBcFuncGenes( $dbh, '', '', \@func_ids );
    #            my @workspaceIds = keys %workspaceIds_href;
    #            if ( scalar(@workspaceIds) > 0 ) {
    #                push( @meta_genes, @workspaceIds );                    
    #
    #                $gene_cnt += scalar(@workspaceIds);
    #                if ( $gene_cnt >= $maxGeneListResults ) {
    #                    $trunc = 1;
    #                    last;
    #                }
    #            }
    #        }
    #    }
    #}

    if ( scalar(@gene_oids) == 1 && scalar(@meta_genes) == 0 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }
    #print "printFfgFindFunctionsGeneList() gene_oids: @gene_oids<br/>\n";

    my $name = $function2Name{$searchFilter};
    my $title    = "Genes In $name";
    my $subtitle = "$name ID: " . $id;

    if ( $searchFilter eq "np" ) {
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id";
        $subtitle = "SM ID: " . alink( $url, $id );
    } 

    HtmlUtil::printGeneListHtmlTable
    ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes );
}

sub getBcGeneListSql {
    my ( $id, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct bcg.feature_id, g.taxon, t.in_file
        from bio_cluster_features_new bcg, bio_cluster_new g, taxon t
        where bcg.cluster_id = ?
        and bcg.cluster_id = g.cluster_id
        and g.taxon = t.taxon_oid
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getNpGeneListSql {
    my ( $id, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    #my $sql = qq{
    #    select distinct g.gene_oid
    #    from np_biosynthesis_source np, bio_cluster_features bcg, gene g
    #    where np.compound_oid = ?
    #    and np.cluster_id = bcg.cluster_id
    #    and bcg.gene_oid = g.gene_oid
    #    $rclause
    #    $imgClause
    #};
    my $sql = qq{
        select distinct bcg.gene_oid
        from np_biosynthesis_source np, bio_cluster_features_new bcg
        where np.compound_oid = ?
        and np.cluster_id = bcg.cluster_id
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# printFfgFindFunctionsGenomeList - Show genome list of individual counts.
############################################################################
sub printFfgFindFunctionsGenomeList {
    my $searchFilter = param("searchFilter");
    my $data_type    = param("data_type");
    my $id           = param("id");
    my $subs         = param("sub");
    my $cnt          = param("cnt");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $rclause, @bindList_ur );
    my $imgClause;
    if ( $searchFilter eq "bc" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    elsif ( $searchFilter eq "np" ) {
        ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("np.taxon_oid");
        $imgClause = WebUtil::imgClauseNoTaxon('np.taxon_oid');
    }
    #print "printFfgFindFunctionsGenomeList() rclause: $rclause<br/>";
    #print "printFfgFindFunctionsGenomeList() imgClause: $imgClause<br/>";

    my $sql;
    my @bindList = ();
    if ( $enable_biocluster )  {
        ( $sql, @bindList ) =
          getBcGenomeListSql( $id, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "bc";
        ( $sql, @bindList ) =
          getNpGenomeListSql( $id, $rclause, $imgClause, \@bindList_ur )
          if $searchFilter eq "np";
    }
    #print "printFfgFindFunctionsGenomeList sql: $sql<br/>";
    #print "printFfgFindFunctionsGenomeList bindList: @bindList<br/>";
    if ( blankStr($sql) ) {
        webDie( "printFfgFunctionsGenomeList: Unknown search filter '$searchFilter'\n" );
    }

    my @taxon_oids = HtmlUtil::fetchGenomeList( $dbh, $sql, $verbose, @bindList );
    #print "printFfgFindFunctionsGenomeList taxon_oids size: " . @taxon_oids . "<br/>";

    #if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
    #    my $sql;
    #    my @bindList = ();
    #    if ( $enable_biocluster )  {
    #        ( $sql, @bindList ) =
    #          getBcGenomeListSql_merfs( $id, $rclause, $imgClause, \@bindList_ur )
    #          if $searchFilter eq "bc";
    #        ( $sql, @bindList ) =
    #          getNpGenomeListSql_merfs( $id, $rclause, $imgClause, \@bindList_ur )
    #          if $searchFilter eq "np";
    #    }
    #    #print "printFfgFunctionGenomeList() merfs sql: $sql<br/>";
    #    #print "printFfgFunctionGenomeList() merfs bindList: @bindList<br/>";
    #    if ( blankStr($sql) ) {
    #        webDie( "printFfgFindFunctionsGenomeList: Unknown search filter '$searchFilter'\n" );
    #    }
    #    my @meta_taxons = HtmlUtil::fetchGenomeList( $dbh, $sql, $verbose, @bindList );
    #    push( @taxon_oids, @meta_taxons );
    #}
    #print "printFfgFindFunctionsGenomeList() taxon_oids size: " . @taxon_oids . "<br/>\n";
    #print "printFfgFindFunctionsGenomeList() taxon_oids: @taxon_oids<br/>\n";

    my $name = $function2Name{$searchFilter};
    $name = "IMG Term" if ( $searchFilter eq "img_term_iex" );
    my $title    = "Genomes In $name";
    my $subtitle = "$name ID: " . $id;

    if ( $searchFilter eq "np" ) {
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id";
        $subtitle = "SM ID: " . alink( $url, $id );
    } 

    HtmlUtil::printGenomeListHtmlTable( $title, $subtitle, $dbh, \@taxon_oids );
}

sub getBcGenomeListSql {
    my ( $id, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    #cover both isolate & metagenome
    my $sql = qq{
        select distinct g.taxon
        from bio_cluster_new g
        where g.cluster_id = ?
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getBcGenomeListSql_merfs {
    my ( $id, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from bio_cluster_new g
        where g.cluster_id = ?
        and g.taxon in (
            select t.taxon_oid from taxon t where t.in_file = 'Yes'
        )
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getNpGenomeListSql {
    my ( $id, $rclause, $imgClause, $bindList_ur_ref ) = @_;

    #my $sql = qq{
    #    select distinct g.taxon
    #    from np_biosynthesis_source np, gene g
    #    where np.compound_oid = ?
    #    and np.taxon_oid = g.taxon
    #    $rclause
    #    $imgClause
    #};
    my $sql = qq{
        select distinct np.taxon_oid
        from np_biosynthesis_source np
        where np.compound_oid = ?
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, '', $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub isMetaSupported {
    my ($searchFilter) = @_;

    if ( $searchFilter eq "bc" )
    {
        return 1;
    }

    return 0;
}

sub getCacheFile {
    my ($file) = @_;

    $file = WebUtil::checkFileName($file);
    return "$cgi_tmp_dir/$file";
}



1;
