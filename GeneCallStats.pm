############################################################################
# GeneCallStats.pm - Compute stats for gene calls.
#    --es 09/01/09
#
# $Id: GeneCallStats.pm 29739 2014-01-07 19:11:08Z klchu $
# OBSOLETE 2012-08-29
############################################################################
package GeneCallStats;
use strict;
use CGI qw( :standard );
use TaxonDetailUtil;
use Data::Dumper;
use WebUtil;
use WebConfig;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $tmp_url = $env->{ tmp_url };
my $tmp_dir = $env->{ tmp_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };

my $section = "GeneCallStats";
my $section_cgi = "$main_cgi?section=$section";

############################################################################
# dispatch
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "geneList" ) {
       printGeneList( );
    }
    else {
       printStats( );
    }
}

############################################################################
# hasGeneCallerInfo - Test to see if this has gene calling information.
############################################################################
#sub hasGeneCallerInfo {
#    my( $dbh, $taxon_oid ) = @_;
#
#    return 0; # if !WebUtil::tableExists( $dbh, "gene_feature_tags" );
#
#    my  $sql = qq{
#       select taxon_oid
#       from dt_gene_caller_stats
#       where taxon_oid = ?
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
#    my( $val ) = $cur->fetchrow( );
#    $cur->finish( );
#    return $val;

#    my $sql = qq{
#        select g.gene_oid
#	from gene g, gene_feature_tags gft
#	where g.taxon = ?
#	and g.gene_oid = gft.gene_oid
#	and gft.tag = 'gene_calling_method'
#    };
    
#    my $sql = qq{
#        select g.gene_oid
#        from gene g
#        where g.taxon = ?
#        and exists (select 1 
#                    from gene_feature_tags gft 
#                    where g.gene_oid = gft.gene_oid
#                    and gft.tag = ?
#                    and rownum < ? )
#    };
    
#    my $sql = qq{
#        select g.gene_oid
#        from gene g, gene_feature_tags gft 
#        where g.taxon = ?
#        and g.gene_oid = gft.gene_oid
#        and gft.tag = ?
#        and rownum < ?        
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 
#        "gene_calling_method", 2 );
#    my( $gene_oid ) = $cur->fetchrow( );
#    $cur->finish( );
#    return $gene_oid;
#}

############################################################################
# printStats
############################################################################
sub printStats {
    my $taxon_oid = param( "taxon_oid" );

    my $dbh = dbLogin( );

    print "<h1>Gene Caller Statistics</h1>\n";
    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv( );

    print "Computing overall gene caller stats (please wait) ...<br/>\n";
    my $sql = qq{
        select gcs.gene_caller, gcs.gene_cnt
	   min_bp, med_bp, max_bp,
	   min_aa, med_aa, max_aa,
	   min_sf, med_sf, max_sf
        from dt_gene_caller_stats gcs
        where gcs.taxon_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %overallStats;
    for( ;; ) {
        my( $value, $cnt, 
	    $min_bp, $med_bp, $max_bp, 
	    $min_aa, $med_aa, $max_aa,  
	    $min_sf, $med_sf, $max_sf ) = $cur->fetchrow( );
	last if $value eq "";
	$overallStats{ $value } = "$cnt\t" . 
	   "$min_bp\t" . "$med_bp\t" . "$max_bp\t" .
	   "$min_aa\t" . "$med_aa\t" . "$max_aa\t" .
	   "$min_sf\t" . "$med_sf\t" . "$max_sf\t" ;
    }
    $cur->finish( );

    print "Computing start/end stats ...<br/>\n";
#    my $sql = qq{
#        select ise.gene_caller, ise.note, ise.gene_cnt
#	from dt_invalid_start_end ise
#	where ise.taxon_oid = ?
#    };

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select gft1.value, gn2.notes, count( distinct g.gene_oid )
        from gene g, gene_feature_tags gft1, gene_notes gn2
        where g.gene_oid = gft1.gene_oid
	and g.gene_oid = gn2.gene_oid
        and gft1.tag = 'gene_calling_method'
	and gn2.notes like 'unable to find valid%'
        and g.taxon = ?
        $rclause
        $imgClause
	group by gft1.value, gn2.notes
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %startEndStats;
    my %notes2;
    for( ;; ) {
        my( $value1, $note2, $cnt ) = $cur->fetchrow( );
	last if $value1 eq "";
	my $k = "$value1\t$note2";
	$notes2{ $note2 } = 1;
	$startEndStats{ $k } = $cnt;
    }
    $cur->finish( );

    printEndWorkingDiv( );

    my @gene_callers = sort( keys( %overallStats ) );
    for my $gene_caller( @gene_callers ) {
       my $stats_rec = $overallStats{ $gene_caller };
       my $ks = "$gene_caller\t" . "unable to find valid start";
       my $ke = "$gene_caller\t" . "unable to find valid end";
       my $invalidStarts = $startEndStats{ $ks };
       my $invalidEnds = $startEndStats{ $ke };
       $stats_rec .= "$invalidStarts\t" . "$invalidEnds\t";
       printGeneCaller( $taxon_oid, $gene_caller, $stats_rec );
    }
    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printGeneCaller - Print Record for one gene caller
############################################################################
sub printGeneCaller {
    my( $taxon_oid, $gene_caller, $rec ) = @_;

    my $gene_caller2 = sprintf( "%20s", $gene_caller ); # padded for same length
    my( $gene_cnt, $min_bp, $med_bp, $max_bp, $min_aa, $med_aa, $max_aa,
        $min_sf, $med_sf, $max_sf, $invalidStarts, $invalidEnds ) =
	split( /\t/, $rec );

    my $invalidStartPerc = sprintf( "%2d%%", 
       $invalidStarts * 100  / $gene_cnt );
    my $invalidEndPerc = sprintf( "%2d%%", 
       $invalidEnds * 100  / $gene_cnt );

    my $sp = nbsp( 2 );

    print "<br/>\n";
    print "<table border='1' class='img'>\n";
    print "<th class='img'>Gene Caller: <i>$gene_caller2</i></th>\n";
    print "<th class='img'>Number</th>\n";
    print "<th class='img'>Percentage</th>\n";

    my $url = "$section_cgi&taxon_oid=$taxon_oid";
    $url .= "&gene_caller=$gene_caller";
    $url .= "&page=geneList";
    my $link = alink( $url, $gene_cnt );
    my $link = $gene_cnt; # no link, too slow
    printRow3( "<b>Gene Count</b>", $link, "100%" );
    #printRow3( $sp, $sp );

    printRow3( "<b>DNA Sequence</b>", "" );
    printRow3( $sp . "Min (bp)", $min_bp );
    printRow3( $sp . "Median (bp)", $med_bp );
    printRow3( $sp . "Max (bp)", $max_bp );
    #printRow3( $sp, $sp );

    printRow3( "<b>Protein Sequence</b>", "" );
    printRow3( $sp . "Min (aa)", $min_aa );
    printRow3( $sp . "Median (aa)", $med_aa );
    printRow3( $sp . "Max (aa)", $max_aa );
    #printRow3( $sp, $sp );

    printRow3( "<b>Scaffold Sequence</b>", "" );
    printRow3( nbsp( 2 ) . "Min (bp)", $min_sf );
    printRow3( nbsp( 2 ) . "Median (bp)", $med_sf );
    printRow3( nbsp( 2 ) . "Max (bp)", $max_sf );
    #printRow3( $sp, $sp );

    printRow3( "<b>Invalid Coordinates</b>", "" );
    my $url = "$section_cgi&taxon_oid=$taxon_oid";
    $url .= "&gene_caller=$gene_caller";
    $url .= "&page=geneList";
    $url .= "&invalidStartEnds=invalidStarts";
    my $link = alink( $url, $invalidStarts );
    $link = $invalidStarts; # no link, too slow
    $link = "0" if $invalidStarts == 0;
    printRow3( $sp . "Invalid starts", $link, $invalidStartPerc );
    #
    my $url = "$section_cgi&taxon_oid=$taxon_oid";
    $url .= "&gene_caller=$gene_caller";
    $url .= "&page=geneList";
    $url .= "&invalidStartEnds=invalidEnds";
    my $link = alink( $url, $invalidEnds );
    $link = $invalidEnds; # no link, too slow
    $link = "0" if $invalidEnds == 0;
    printRow3( $sp . "Invalid ends", $link, $invalidEndPerc );

    print "</table>\n";
}

############################################################################
# printRow3 - Print 3 column row.
############################################################################
sub printRow3 {
    my( $tag, $val, $val_perc ) = @_;

    $val = nbsp( 1 ) if $val eq "";
    $val_perc = nbsp( 1 ) if $val_perc eq "";

    print "<tr class='img'>\n";

    print "<td class='img'>";
    print $tag;
    print "</td>\n";

    print "<td class='img' align='right'>";
    print "$val";
    print "</td>\n";

    print "<td class='img' align='right'>";
    print "$val_perc";
    print "</td>\n";

    print "</tr>\n";
}

############################################################################
# printGeneList - Show gene list for a gene caller
############################################################################
sub printGeneList {
    my $taxon_oid = param( "taxon_oid" );
    my $gene_caller = param( "gene_caller" );
    my $invalidStartEnds = param( "invalidStartEnds" );

    my $title = "Genes from $gene_caller";
    if( $invalidStartEnds eq "invalidStarts" ) {
       $title .= " (invalid starts)";
    }
    elsif( $invalidStartEnds eq "invalidEnds" ) {
       $title .= " (invalid ends)";
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql_overall = qq{
        select distinct g.gene_oid
        from gene g, gene_feature_tags gft
        where g.gene_oid = gft.gene_oid
	and g.taxon = $taxon_oid
        and gft.tag = 'gene_calling_method'
	and gft.value ='$gene_caller'
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $sql_invalidStarts = qq{
        select distinct g.gene_oid
        from gene g, gene_feature_tags gft1, gene_notes gn2
        where g.gene_oid = gft1.gene_oid
	and g.gene_oid = gn2.gene_oid
	and g.taxon = $taxon_oid
        and gft1.tag = 'gene_calling_method'
	and gft1.value = '$gene_caller'
	and gn2.notes = 'unable to find valid start'
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $sql_invalidEnds = qq{
        select distinct g.gene_oid
        from gene g, gene_feature_tags gft1, gene_notes gn2
        where g.gene_oid = gft1.gene_oid
	and g.gene_oid = gn2.gene_oid
	and g.taxon = $taxon_oid
        and gft1.tag = 'gene_calling_method'
	and gft1.value = '$gene_caller'
	and gn2.notes = 'unable to find valid end'
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $sql;
    if( $invalidStartEnds eq "invalidStarts" ) {
       $sql = $sql_invalidStarts;
    }
    elsif( $invalidStartEnds eq "invalidEnds" ) {
       $sql = $sql_invalidEnds;
    }
    else {
       $sql = $sql_overall;
    }
    TaxonDetailUtil::printGeneListSectionSorting( $sql, $title );
}

1;


