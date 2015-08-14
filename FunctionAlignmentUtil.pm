############################################################################
#   Misc. utility functions to support HTML.
# $Id: FunctionAlignmentUtil.pm 30147 2014-02-19 21:08:29Z imachen $
############################################################################
package FunctionAlignmentUtil;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;

# Force flush
$| = 1;

my $env = getEnv();
my $main_cgi = $env->{main_cgi};
my $cog_base_url = $env->{cog_base_url};
my $kog_base_url = $env->{kog_base_url};
my $pfam_base_url = $env->{pfam_base_url};
my $verbose = $env->{verbose};
my $image_len = 150;

my $og = "cog"; # can be set to "kog"
my $OG = "COG"; # can be set to "KOG"

############################################################################
# printCog - Show COG hits.
############################################################################
sub printCog {
    my ( $dbh, $gene_oids_str, $rclause, $imgClause) = @_;
    $og = "cog"; # global variable
    my ($sql, @bindList) = getCogSqlForGene($gene_oids_str, undef, $rclause, $imgClause,
			   undef, undef, undef, $og );
    my ($cnt, $recs_ref, $func_ids_ref) = execCogSearch( $dbh, $sql, \@bindList );

    my $count;
    if ( scalar(@$func_ids_ref) > 0 ) {
        my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
        my ( $funcI2desc_href, $funcId2def_href ) = fetchCogId2Desc( $dbh, $func_ids_str );
        $count = printCogResults( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, undef, $og);
    }
    
    return $count;    
}

############################################################################
# printKog - Show KOG hits.
############################################################################
sub printKog {
    my ( $dbh, $gene_oids_str, $rclause, $imgClause) = @_;
    $og = "kog"; # global variable
    my ($sql, @bindList) = getCogSqlForGene($gene_oids_str, undef, $rclause, $imgClause,
			   undef, undef, undef, $og);
    my ($cnt, $recs_ref, $func_ids_ref) = execCogSearch( $dbh, $sql, \@bindList );

    my $count;
    if ( scalar(@$func_ids_ref) > 0 ) {
        my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
        my ( $funcI2desc_href, $funcId2def_href ) = fetchKogId2Desc( $dbh, $func_ids_str );
        $count = printCogResults( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, undef, $og);        
    }

    return $count;
}

sub fetchCogId2Desc {
    my ( $dbh, $func_ids_str ) = @_;

    my $sql = qq{
        select distinct c.cog_id, c.seq_length, c.cog_name
        from cog c
        where c.cog_id in ($func_ids_str)
    };
    #print "fetchCogId2Desc() 1 sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %i2desc_h;
    for ( ; ; ) {
        my ( $cog_id, $seq_length, $cog_name )
          = $cur->fetchrow();
        last if !$cog_id;

        my $rec = "$seq_length\t";
        $rec .= "$cog_name";
        $i2desc_h{$cog_id} = $rec;
    }
    $cur->finish();    
    #print Dumper \%i2desc_h;
    #print "fetchCogId2Desc() dump i2desc_h done<br/>\n";

    my $sql = qq{
        select distinct cfs.cog_id, cf.function_code, cf.definition
        from cog_function cf, cog_functions cfs
        where cf.function_code = cfs.functions
        and cfs.cog_id in ($func_ids_str)
    };
    #print "fetchCogId2Desc() 2 sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %id2def_h;
    for ( ; ; ) {
        my ( $cog_id, $function_code, $definition )
          = $cur->fetchrow();
        last if !$cog_id;

        $id2def_h{$cog_id} .= "$function_code\t$definition\n";
    }
    $cur->finish();
    #print Dumper \%id2def_h;
    #print "fetchCogId2Desc() dump i2def_h done<br/>\n";

    return ( \%i2desc_h, \%id2def_h );
}

sub fetchKogId2Desc {
    my ( $dbh, $func_ids_str ) = @_;

    my $sql = qq{
        select distinct c.kog_id, c.seq_length, c.kog_name
        from kog c
        where c.kog_id in ($func_ids_str)
    };
    #print "fetchKogId2Desc() 1 sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %i2desc_h;
    for ( ; ; ) {
        my ( $kog_id, $seq_length, $kog_name )
          = $cur->fetchrow();
        last if !$kog_id;

        my $rec = "$seq_length\t";
        $rec .= "$kog_name\t";
        $i2desc_h{$kog_id} = $rec;
    }
    $cur->finish();

    my $sql = qq{
        select distinct cfs.kog_id, cf.function_code, cf.definition
        from kog_function cf, kog_functions cfs
        where cf.function_code = cfs.functions
        and cfs.kog_id in ($func_ids_str)
    };
    #print "fetchKogId2Desc() 2 sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %id2def_h;
    for ( ; ; ) {
        my ( $kog_id, $function_code, $definition )
          = $cur->fetchrow();
        last if !$kog_id;
        $id2def_h{$kog_id} .= "$function_code\t$definition\n";
    }
    $cur->finish();

    return ( \%i2desc_h, \%id2def_h );
}

sub getCogSqlForGene {
    my ($gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $hasGeneCol, $og) = @_;

    my $sql = qq{
        select distinct gcg.gene_oid, gcg.${og}, gcg.percent_identity,
            gcg.query_start, gcg.query_end, g.aa_seq_length,
            gcg.evalue, gcg.bit_score,
            tx.taxon_oid, tx.taxon_display_name
        from gene_${og}_groups gcg, gene g, taxon tx
        where gcg.gene_oid in ( $gene_oids_str )
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
    };
    if ($hasGeneCol) {
	    $sql .= qq{
	        order by gcg.${og}, gcg.query_start, gcg.bit_score desc
	    };
    }
    else {
        $sql .= qq{
            order by gcg.query_start, gcg.bit_score desc
        };
    }
    
    my @bindList = ();
    processBindList(\@bindList, undef, $bindList_txs_ref, $bindList_ur_ref);
    return ($sql, @bindList);
}

sub execCogSearch {
    my ( $dbh, $sql, $bindList_ref ) = @_;

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    
    my $count = 0;
    my @recs;
    my %func_ids_h;
    for ( ; ; ) {
        my (
             $gene_oid,      $cog_id,      $percent_identity,
             $query_start,   $query_end,   $aa_seq_length,
             $evalue,        $bit_score,   $taxon_oid,     $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        $func_ids_h{$cog_id} = 1;

        my $rec = "$gene_oid\t";
        $rec .= "$cog_id\t";
        $rec .= "$percent_identity\t";
        $rec .= "$query_start\t";
        $rec .= "$query_end\t";
        $rec .= "$aa_seq_length\t";
        my $evalue2 = sprintf( "%.1e", $evalue );
        $rec .= "$evalue2\t";
        $rec .= "$bit_score\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$taxon_display_name";
        if (!(grep $_ eq $rec, @recs)) {
            push( @recs, $rec );
            $count++;
        }
    }
    $cur->finish();

    my @func_ids = keys %func_ids_h;
    return ($count, \@recs, \@func_ids);
}

sub printCogResults {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, $hasGeneCol, $og ) = @_;

    my $count = 0;
    if ($hasGeneCol) {
        $count = printCogResults_YUI( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, undef, $og);
    }
    else {
        $count = printCogResults_classic( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, undef, $og);
    }
    return $count;    
}

sub printCogResults_classic {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, $hasGeneCol, $og ) = @_;
    my @recs = @$recs_ref;
    my %cogId2desc = %$funcId2def_href;
    
    return $cnt if ( $cnt == 0 );

    $OG = uc($og);
    print "<table class='img' cellspacing='1' border='1'>\n" if ($hasGeneCol);
    print "<tr class='img'>\n";
    print "<th class='img'>Gene ID</th>\n" if ($hasGeneCol);
    print "<th class='img'>$OG ID</th>\n";
    print "<th class='img'>Consensus<br/>Sequence<br/>Length</th>\n";
    print "<th class='img'>Description</th>\n";
    print "<th class='img'>Percent<br/>Identity</th>\n";
    if ($hasGeneCol) {
	    print "<th class='img'>Query<br/>Start</th>\n";
	    print "<th class='img'>Query<br/>End</th>\n";
        print "<th class='img'>Alignment<br/>On Query Gene</th>\n";
    } else {
        print "<th class='img'>Alignment<br/>On<br/>Query<br/>Gene</th>\n";
        print "<th class='img'>E-value</th>\n";
    }
    print "<th class='img'>Bit<br/>Score</th>\n";
    print "<th class='img'>Genome</th>\n" if ($hasGeneCol);
    print "</tr>\n";

    my $count = 0;
    my %doneCat;
    my $old_cog_id;
    for my $r (@recs) {
        my (
             $gene_oid,         $cog_id,      
             $percent_identity, $query_start, $query_end,   $aa_seq_length,
             $evalue,           $bit_score,   $taxon_oid,   $taxon_display_name
          )
          = split( /\t/, $r );
        $count++;

        my $func_rec = $funcI2desc_href->{$cog_id};
        my ($seq_length, $cog_name) = split( /\t/, $func_rec );

        print "<tr class='img'>\n";
        if ($hasGeneCol) {
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            my $geneLink .= alink( $url, $gene_oid );
            print "<td class='img'>$geneLink</td>\n";
        }
    	my $og_url = ($og eq "cog") ? $cog_base_url : $kog_base_url;
        my $url = "$og_url$cog_id";
        print "<td class='img'>" .
	    alink( $url, $cog_id ) . "</td>\n";
        print "<td class='img'>$seq_length</td>\n";
        print "<td class='img' >\n";
        my @cogCats = split( /\n/, $cogId2desc{$cog_id} );
        if ( $old_cog_id ne $cog_id ) {
            for my $cc (@cogCats) {
                my ( $function_code, $definition ) = split( /\t/, $cc );
                next if $doneCat{$function_code} ne "";
                print "[$function_code] ";
                my $url =
                    "$main_cgi?section=CogCategoryDetail"
                  . "&page=${og}CategoryDetail";
                $url .= "&function_code=$function_code";
                print alink( $url, $definition ) . "<br/>\n";
                $doneCat{$function_code} = 1;
            }
            %doneCat = ();
        }
        print nbsp(2) . escHtml($cog_name);
        print "</td>\n";
        print "<td class='img' align='right'>$percent_identity</td>\n";
        if ($hasGeneCol) {
	        print "<td class='img' align='right'>$query_start</td>\n";
	        print "<td class='img' align='right'>$query_end</td>\n";        	
	        print "<td class='img' align='middle' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length, $image_len )
	          . "</td>\n";
        }
        else {
	        print "<td class='img' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length )
	          . "</td>\n";        	
            print "<td class='img' align='left'>$evalue</td>\n";
        }
        $bit_score = sprintf( "%d", $bit_score );
        print "<td class='img' align='right'>$bit_score</td>\n";
        if ($hasGeneCol) {
	        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            my $genomeLink .= alink( $taxon_url, $taxon_display_name );
            print "<td class='img'>$genomeLink</td>\n";
        }
        print "</tr>\n";
        $old_cog_id = $cog_id;
    }
    print "</table>\n" if ($hasGeneCol); 
    
    return $count;
}

sub printCogResults_YUI {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $funcId2def_href, $dummy, $og) = @_;
    my @recs = @$recs_ref;
    my %cogId2desc = %$funcId2def_href;
    
    return $cnt if ( $cnt == 0 );
    my $it = new InnerTable( 1, "${og}Alignment$$", "${og}Alignment", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $OG = uc($og);
    $it->addColSpec( "Gene ID", "number asc", "center" );
    $it->addColSpec( "$OG ID", "asc", "center" );
    $it->addColSpec( "$OG Name", "asc" );
    $it->addColSpec( "Consensus<br/>Sequence<br/>Length", "number asc", "right" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec( "Query<br/>Start", "number asc", "right" );
    $it->addColSpec( "Query<br/>End", "number desc", "right" );
    $it->addColSpec( "Alignment On Query Gene", "desc" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    $it->addColSpec( "Genome", "asc" );

    my $count = 0;
    my %doneCat;
    my $old_cog_id;
    for my $r (@recs) {
        my (
             $gene_oid,         $cog_id,
             $percent_identity, $query_start, $query_end,   $aa_seq_length,
             $evalue,           $bit_score,   $taxon_oid,   $taxon_display_name
          )
          = split( /\t/, $r );
        $count++;

        my $func_rec = $funcI2desc_href->{$cog_id};
        my ($seq_length, $cog_name) = split( /\t/, $func_rec );

        my $row;
        my $gene_url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ). "\t";
    	# check whether cog or kog and use relevant URL
    	my $og_url = ($og eq "cog") ? $cog_base_url : $kog_base_url;
        my $url = "$og_url$cog_id";
        $row .= $cog_id . $sd . alink( $url, $cog_id ) . "\t";

        my $cog_desc = '';
        my $cog_desc_nolink = '';
        my @cogCats = split( /\n/, $cogId2desc{$cog_id} );
        if ( $old_cog_id ne $cog_id ) {
            for my $cc (@cogCats) {
                my ( $function_code, $definition ) = split( /\t/, $cc );
                next if $doneCat{$function_code} ne "";
                my $url = "$main_cgi?section=CogCategoryDetail&page=${og}CategoryDetail";
                $url .= "&function_code=$function_code";
                $cog_desc .= "[$function_code] ". alink( $url, $definition ) . "<br/>\n";
                $cog_desc_nolink .= "[$function_code] ". $definition;
                $doneCat{$function_code} = 1;
            }
            %doneCat = ();
        }
        $cog_desc .= escHtml($cog_name);
        $cog_desc_nolink .= escHtml($cog_name);
        $row .= $cog_desc_nolink . $sd . $cog_desc . "\t";
 
        $row .= $seq_length . $sd . $seq_length . "\t";
        $row .= $percent_identity . $sd . $percent_identity . "\t";
        $row .= $query_start . $sd . $query_start . "\t";
        $row .= $query_end . $sd . $query_end . "\t";
        $row .= 'image' . $sd . alignImage( $query_start, $query_end, $aa_seq_length, $image_len ) . "\t";

        $bit_score = sprintf( "%d", $bit_score );
        $row .= $bit_score . $sd . $bit_score . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $taxon_url, escHtml($taxon_display_name) ) . "\t";

        $it->addRow($row);
        $old_cog_id = $cog_id;
    }
    #$it->printOuterTable(1);
    $it->printOuterTable(1, "history-min.js"); #"history-min.js" from yui-table affects the tabview
    
    return $count;
}


############################################################################
# printPfam - Show Protein Family hits.
############################################################################
sub printPfam {
    my ( $dbh, $gene_oids_str, $rclause, $imgClause) = @_;

    my ($sql, @bindList) = getPfamSqlForGene($gene_oids_str, undef, $rclause, $imgClause);
    my ($cnt, $recs_ref, $func_ids_ref) = execPfamSearch( $dbh, $sql, \@bindList );

    my $count;
    if ( scalar(@$func_ids_ref) > 0 ) {
        my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
        my ( $pfamId2rec_ref, $doHmm ) = fetchPfamId2Desc( $dbh, $func_ids_str );
        $count = printPfamResults( $dbh, $cnt, $recs_ref, $pfamId2rec_ref, $doHmm);
    }

    return $count;
}


sub fetchPfamId2Desc {
    my ( $dbh, $func_ids_str ) = @_;

    my $sql = qq{
        select distinct pf.ext_accession, pf.name, pf.description, pf.db_source
        from pfam_family pf
        where pf.ext_accession in ( $func_ids_str )
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %i2desc_h;
    my $doHmm = 1;
    for ( ; ; ) {
        my ( $ext_accession, $name, $description, $db_source )
          = $cur->fetchrow();
        last if !$ext_accession;

        my $rec = "$name\t";
        $rec .= "$description\t";
        $i2desc_h{$ext_accession} = $rec;

        if ( $db_source !~ /HMM/ ) {
            $doHmm = 0;
            webLog(">>> The db_source of $ext_accession is $db_source, none-HMM.\n");
        }
    }
    $cur->finish();

    return ( \%i2desc_h, $doHmm );
}

sub getPfamSqlForGene {
    my ($gene_oids_str, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $hasGeneCol) = @_;

    my $sql = qq{
        select distinct gpf.gene_oid, gpf.pfam_family, 
            gpf.percent_identity,
            gpf.query_start, gpf.query_end, g.aa_seq_length,
            gpf.evalue, gpf.bit_score, 
            tx.taxon_oid, tx.taxon_display_name
        from gene_pfam_families gpf, gene g, taxon tx
        where gpf.gene_oid in ( $gene_oids_str )
            and gpf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
    };
    if ($hasGeneCol) {
        $sql .= qq{
            order by gpf.pfam_family, gpf.query_start, gpf.bit_score desc
        };
    }
    else {
        $sql .= qq{
            order by gpf.query_start, gpf.bit_score desc
        };
    }

    my @bindList = ();
    processBindList(\@bindList, undef, $bindList_txs_ref, $bindList_ur_ref);
    
    return ($sql, @bindList);
}

sub execPfamSearch {
    my ( $dbh, $sql, $bindList_ref) = @_;

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    
    my $count = 0;
    my @recs;
    my %func_ids_h;
    for ( ; ; ) {
        my (
             $gene_oid,    $ext_accession, $percent_identity, 
             $query_start, $query_end,     $aa_seq_length,
             $evalue,      $bit_score,     
             $taxon_oid,   $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        $func_ids_h{$ext_accession} = 1;

        my $rec = "$gene_oid\t";
        $rec .= "$ext_accession\t";
        $rec .= "$percent_identity\t";
        $rec .= "$query_start\t";
        $rec .= "$query_end\t";
        $rec .= "$aa_seq_length\t";
        my $evalue2 = sprintf( "%.1e", $evalue );
        $rec .= "$evalue2\t";
        $rec .= "$bit_score\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$taxon_display_name";
        if (!(grep $_ eq $rec, @recs)) {
            push( @recs, $rec );
            $count++;
        }
    }
    $cur->finish();

    my @func_ids = keys %func_ids_h;
    return ($count, \@recs, \@func_ids);
}

sub printPfamResults {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm, $hasGeneCol ) = @_;

    my $count = 0;
    if ($hasGeneCol) {
        $count = printPfamResults_YUI( $dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm);
    }
    else {
        $count = printPfamResults_classic($dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm);
    }
    return $count;    
}

sub printPfamResults_classic {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm, $hasGeneCol ) = @_;
    my @recs = @$recs_ref;
    
    return $cnt if ( $cnt == 0 );

    print "<table class='img' cellspacing='1' border='1'>\n" if ($hasGeneCol);
    print "<tr class='img'>\n";
    print "<th class='img'>Gene ID</th>\n" if ($hasGeneCol);
    print "<th class='img'>Pfam Domain</th>\n";
    if ($doHmm) {
        print "<th class='img'>HMM Pfam Hit</th>\n";
    } else {
        print "<th class='img'>CDD Pfam Hit</th>\n";
    }
    print "<th class='img'>Description</th>\n";
    if ($doHmm) {
        print "<th class='img'>Percent<br/>Alignment<br/>"
          . "On<br/>Query Gene</th>\n";
    } else {
        print "<th class='img'>Percent<br/>Identity</th>\n";
    }
    if ($hasGeneCol) {
	    print "<th class='img'>Query<br/>Start</th>\n";
	    print "<th class='img'>Query<br/>End</th>\n";
        print "<th class='img'>Alignment<br/>On Query Gene</th>\n";
    } else {
        print "<th class='img'>Alignment<br/>On<br/>Query<br/>Gene</th>\n";
        print "<th class='img'>E-value</th>\n";
    }
    if ($doHmm) {
        print "<th class='img'>HMM<br/>Score</th>\n";
    } else {
        print "<th class='img'>Bit Score</th>\n";
    }
    print "<th class='img'>Genome</th>\n" if ($hasGeneCol);
    print "</tr>\n";

    my $count = 0;
    for my $r (@recs) {
        my (
             $gene_oid,    $ext_accession, $percent_identity, 
             $query_start, $query_end,     $aa_seq_length,
             $evalue,      $bit_score,
             $taxon_oid,   $taxon_display_name
          )
          = split( /\t/, $r );
        # --es 04/14/08 Allow for multiple same Pfam hits, along diff. coordinates
        #next if $done{ $ext_accession } ne "";
        $count++;

        my $func_rec = $funcI2desc_href->{$ext_accession};
        my ($name, $description) = split( /\t/, $func_rec );

        print "<tr class='img'>\n";
        if ($hasGeneCol) {
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            my $geneLink .= alink( $url, $gene_oid );
            print "<td class='img' >$geneLink</td>\n";
        }

        print "<td class='img' >" . escHtml($name) . "</td>\n";

        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        print "<td class='img' >" . alink( $url, $ext_accession ) . "</td>\n";

        my @sentences = split( /\. /, $description );
        my $description2 = $sentences[0];
        print "<td class='img' >" . escHtml($description2) . "</td>\n";

        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $perc_alignment =
          ( ( $query_end - $query_start + 1 ) / $aa_seq_length ) * 100;
        $perc_alignment = sprintf( "%.2f", $perc_alignment );
        $percent_identity = $perc_alignment if $doHmm;
        print "<td class='img' align='right'>"
          . escHtml($percent_identity)
          . "</td>\n";

        if ($hasGeneCol) {
            print "<td class='img' align='right'>$query_start</td>\n";
            print "<td class='img' align='right'>$query_end</td>\n";           
	        print "<td class='img' align='middle' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length, $image_len )
	          . "</td>\n";
        }
        else {
	        print "<td class='img' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length )
	          . "</td>\n";        	
            print "<td class='img'>" . escHtml($evalue) . "</td>\n";
        }

        $bit_score = sprintf( "%d", $bit_score );
        print "<td class='img' align='right'>"
          . escHtml($bit_score)
          . "</td>\n";

        if ($hasGeneCol) {
            my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            my $genomeLink .= alink( $taxon_url, $taxon_display_name );
            print "<td class='img'>$genomeLink</td>\n";
        }
        print "</tr>\n";
    }
    print "</table>\n" if ($hasGeneCol); 

    return $count;
}

sub printPfamResults_YUI {
    my ( $dbh, $cnt, $recs_ref, $funcI2desc_href, $doHmm ) = @_;
    my @recs = @$recs_ref;
    
    return $cnt if ( $cnt == 0 );

    my $it = new InnerTable( 1, "pfamAlignment$$", "pfamAlignment", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Gene ID", "number asc", "center" );
    $it->addColSpec( "Pfam ID", "asc", "center" );
    $it->addColSpec( "Pfam Name", "asc" );
    if ($doHmm) {
        $it->addColSpec( "Percent<br/>Alignment<br/>On<br/>Query Gene", "number desc", "right" );
    } else {
        $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    }
    $it->addColSpec( "Query<br/>Start", "number asc", "right" );
    $it->addColSpec( "Query<br/>End", "number desc", "right" );
    $it->addColSpec( "Alignment On Query Gene", "desc" );
    if ($doHmm) {
        $it->addColSpec( "HMM<br/>Score", "number desc", "right" );
    } else {
        $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    }
    $it->addColSpec( "Genome", "asc" );

    my $count = 0;
    for my $r (@recs) {
        my (
             $gene_oid,    $ext_accession, $percent_identity, 
             $query_start, $query_end,     $aa_seq_length,
             $evalue,      $bit_score,
             $taxon_oid,   $taxon_display_name
          )
          = split( /\t/, $r );
        # --es 04/14/08 Allow for multiple same Pfam hits, along diff. coordinates
        #next if $done{ $ext_accession } ne "";
        $count++;

        my $func_rec = $funcI2desc_href->{$ext_accession};
        my ($name, $description) = split( /\t/, $func_rec );

        my $row;
        my $gene_url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ). "\t";

        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        $row .= $ext_accession . $sd . alink( $url, $ext_accession ) . "\t";

        my $x;
        $x = " - $description" if $doHmm;
        $row .= "$name$x" . $sd . "$name$x" . "\t";

        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $perc_alignment =
          ( ( $query_end - $query_start + 1 ) / $aa_seq_length ) * 100;
        $perc_alignment = sprintf( "%.2f", $perc_alignment );
        $percent_identity = $perc_alignment if $doHmm;
        $row .= $percent_identity . $sd . escHtml($percent_identity) . "\t";

        $row .= $query_start . $sd . $query_start . "\t";
        $row .= $query_end . $sd . $query_end . "\t";
        $row .= '' . $sd . alignImage( $query_start, $query_end, $aa_seq_length, $image_len ) . "\t";

        $bit_score = sprintf( "%d", $bit_score );
        $row .= $bit_score . $sd . escHtml($bit_score) . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $taxon_url, escHtml($taxon_display_name) ) . "\t";

        $it->addRow($row);
    }
    #$it->printOuterTable(1);
    #$it->printOuterTable(1, "history-min.js", '<script type="text/javascript">', '<script type="text/javascript" id="evalMe">'); #callback not working
    $it->printOuterTable(1, "history-min.js"); #"history-min.js" from yui-table affects the tabview

    return $count;
}

1;

