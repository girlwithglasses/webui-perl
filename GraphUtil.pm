###########################################################################
#
# $Id: GraphUtil.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
#
###########################################################################
package GraphUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use CGI qw( :standard );
use POSIX qw(ceil floor);
use WebUtil;
use WebConfig;
use OracleUtil;
use QueryUtil;
use PhyloUtil;
use MetagGraphScatterPanel;
use MetagGraphPercentPanel;


$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $main_cgi             = $env->{main_cgi};
my $inner_cgi            = $env->{inner_cgi};
my $tmp_url              = $env->{tmp_url};
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};
my $web_data_dir         = $env->{web_data_dir};
my $img_internal         = $env->{img_internal};
my $img_ken              = $env->{img_ken};
my $user_restricted_site = $env->{user_restricted_site};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $base_url             = $env->{base_url};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};
my $tmp_dir              = $env->{tmp_dir};

my $unknown      = "Unknown";

# frag plot
my $NUM_GRAPHS_PER_PAGE = 2;
my $MAX_RANGE           = 40000;

# records index location
# some of querys return '' for the specific column
my $IDX_GENE_OID          = 0;
my $IDX_TAXON_OID         = 1;
my $IDX_PERCENT           = 2;
my $IDX_TAXON_NAME        = 3;
my $IDX_STRAND            = 4;
my $IDX_START             = 5;
my $IDX_END               = 6;
my $IDX_SCAFFOLD          = 7;
my $IDX_SCAFFOLD_NAME     = 8;
my $IDX_YOFFSET           = 9;
my $IDX_WRAPPED           = 10;
my $IDX_QUERY_GENE_OID    = 11;
my $IDX_COG_CODE          = 12;
my $IDX_METAG_START       = 13;
my $IDX_METAG_END         = 14;
my $IDX_METAG_STRAND      = 15;
my $IDX_REF_SCAFFOLD_NAME = 16;
my $IDX_PRODUCT_NAME      = 17;


############################################################################
# getMAXRANGE
############################################################################
sub getMAXRANGE {
    return $MAX_RANGE;
}

############################################################################
# getNUMGRAPHSPERPAGE
############################################################################
sub getNUMGRAPHSPERPAGE {
    return $NUM_GRAPHS_PER_PAGE;
}

############################################################################
# loadColorArrayFile - Load file with all the colors to be used to
#   map to COG functions.
############################################################################
sub loadColorArrayFile {
    my ($inFile) = @_;

    my $rfh = newReadFileHandle( $inFile, "loadColorArrayFile" );
    my @color_array;
    my %done;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if $s eq "";
        next if $s =~ /^#/;
        next if $s =~ /^\!/;
        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        $s =~ s/\s+/ /g;
        my ( $r, $g, $b, @junk ) = split( / /, $s );
        next if scalar(@junk) > 1;
        my $val = "$r,$g,$b";
        next if $done{$val} ne "";
        push( @color_array, $val );
    }
    close $rfh;
    return @color_array;
}

#
# gets min and max start and end coord for a list of scaffold
# list should be less than 1000 ie oracle limit - should be ok since
# the jscript limit selection to 10
#
sub getScaffoldMinMax {
    my ( $dbh, $scaffolds_aref ) = @_;

    my $scaffolds_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffolds_aref );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select min(g.start_coord), max(g.end_coord)
        from gene g
        where g.scaffold in ($scaffolds_str)
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    my ( $min, $max ) = $cur->fetchrow();
    $cur->finish();
    
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaffolds_str =~ /gtt_num_id/i );

    return ( $min, $max );
}

#
# Gets phylum gene next range on the ref genome
# Used by protein plot
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
# param $page - which page
# param $range - length of x-axis per page
# return (start, end) otherwise (-1,-1) nothing found
sub getPhylumGeneCalcRange {
    my (
         $dbh,    $taxon_oid, 
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
         $start_coord, $end_coord, $scaffold_id, $page, $range
      )
      = @_;

    my @binds = ( $taxon_oid, $scaffold_id );

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

    # this query is slow using the range
    # 1. i remove the metag taxon table - a little help in performance
    # 2. try to do start and end selection in perl not in oracle
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select  g2.start_coord
        from dt_phylum_dist_genes dt,
            gene g2, taxon t, scaffold s2
        where dt.taxon_oid = ?
            and dt.homolog = g2.gene_oid
            and dt.homolog_taxon = t.taxon_oid
            and g2.taxon = t.taxon_oid
            and g2.scaffold = s2.scaffold_oid
            and s2.scaffold_oid = ?
            $taxonomyClause
            $rclause
            $imgClause
        order by g2.start_coord
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    
    my $i   = 0;
    for ( ; ; ) {
        my ($start) = $cur->fetchrow();
        last if !$start;

        #webLog("page, range = $page, $range\n");
        #webLog(" start = $start\n");
        #webLog(" start_coord, end_coord = $start_coord, $end_coord\n");

        if ( $start >= $start_coord && $start <= $end_coord ) {

            #webLog(" $start >= $start_coord  && $start <= $end_coord \n");

            # case for 1st page
            if ( $i >= $page ) {
                $cur->finish();
                return ( $start_coord, $end_coord );
            }

        } elsif ( $start >= $end_coord ) {

            # move range
            while ( $start >= $end_coord ) {
                $start_coord = $start_coord + $range;
                $end_coord   = $end_coord + $range;
            }
            $i++;

            #webLog(" recalc $i start_coord, end_coord = $start_coord, $end_coord\n");
            if ( $i >= $page ) {
                $cur->finish();
                return ( $start_coord, $end_coord );
            }

        }
    }
    $cur->finish();

    # nothing found
    return ( -1, -1 );
}

#
# Gets phylum gene details
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
# param $recs_aref return data array of arrays
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param \%scaffolds_hash - ref gene scaffold oids
sub getPhylumGenePercentInfo {
    my (
         $dbh,    $taxon_oid, 
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,   
         $recs_aref, $start_coord, $end_coord, $scaffold_href,
         $scaffolds_query_href, $query_scaffold_aref
      )
      = @_;

    my @binds = ( $taxon_oid );

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

    my $query_scaffold_str;
    if ( $query_scaffold_aref ne "" ) {
        $query_scaffold_str = join( ",", @$query_scaffold_aref );
        $query_scaffold_str = "and g.scaffold in ($query_scaffold_str)";
    }

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select  dt.gene_oid, dt.taxon_oid, 
            dt.percent_identity, t1.taxon_display_name, 
            g2.strand, g2.start_coord, g2.end_coord,
            g.scaffold, s.scaffold_name, g2.gene_oid, 
            g.start_coord, g.end_coord, g.strand, 
            s2.scaffold_name, s2.scaffold_oid, g.product_name
        from dt_phylum_dist_genes dt, taxon t1, 
            gene g, scaffold s, gene g2, 
            taxon t, scaffold s2
        where dt.taxon_oid = t1.taxon_oid
            and dt.gene_oid = g.gene_oid
            and t1.taxon_oid = g.taxon
            and g.scaffold = s.scaffold_oid
            and dt.taxon_oid = ?
            and dt.homolog = g2.gene_oid
            and dt.homolog_taxon = t.taxon_oid
            and g2.taxon = t.taxon_oid
            and g2.scaffold = s2.scaffold_oid
            $query_scaffold_str        
            $taxonomyClause
            $rclause
            $imgClause
    };

    #  trying to make the query faster
    # order by g.start_coord, g.end_coord
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
             $gene_oid,     $taxon_oid,         $percent,
             $taxon_name,   $strand,            $start,
             $end,          $scaffold,          $scaffold_name,
             $ref_gene_oid, $metag_start,       $metag_end,
             $metag_strand, $ref_scaffold_name, $ref_scaffold_oid,
             $product_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        # trying to make the query faster
        #        if($start > $end_coord && $end > $end_coord) {
        #            last;
        #        }

        # doing this range selection here is faster than doing it in oracle
        if (    ( $start >= $start_coord && $start <= $end_coord )
             || ( $end <= $end_coord && $end >= $start_coord ) )
        {

            # do nothing
        } else {

            # skip
            next;
        }

        if ( $scaffolds_query_href ne "" ) {
            if ( exists $scaffolds_query_href->{$scaffold} ) {

                # nothing
            } else {
                next;
            }
        }

        if ( $scaffold_href ne "" ) {
            if ( exists $scaffold_href->{$ref_scaffold_oid} ) {

                # do noting
            } else {
                next;
            }
        }

        my @rec;

        # list is consistent with the array index global variables
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $ref_gene_oid );
        push( @rec,        '' );
        push( @rec,        $metag_start );
        push( @rec,        $metag_end );
        push( @rec,        $metag_strand );
        push( @rec,        $ref_scaffold_name );
        push( @rec,        $product_name );
        push( @$recs_aref, \@rec );

    }
    $cur->finish();
}


#
# gets min max of start and end coord of metag on ref genome
#
# For now I did the tange filter in perl not in orcale
# because is seems faster
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
# param $scaffold_id - ref gene scaffold oid - can be ""
#
# return (min, max)
#
sub getPhylumGenePercentInfoMinMax {
    my (
         $dbh,    $taxon_oid, 
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,   
         $scaffold_id,     $query_scaffold_aref
      )
      = @_;

    my @binds = ( $taxon_oid );

    my $query_scaffold_str = "";
    my $from_str           = "";
    if ( $query_scaffold_aref ne "" && $#$query_scaffold_aref > -1 ) {
        $query_scaffold_str = join( ",", @$query_scaffold_aref );
        $query_scaffold_str =
            " and dt.gene_oid = g.gene_oid "
          . " and g.scaffold in ($query_scaffold_str) ";
        $from_str = " gene g, ";
    }

    my $scaffoldClause = "and g2.scaffold = ? ";
    if ( $scaffold_id eq "" ) {
        $scaffoldClause = "";
    } else {
        push( @binds, $scaffold_id );
    }

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );
      
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql = qq{
        select  min( g2.start_coord), max(g2.end_coord)
        from dt_phylum_dist_genes dt, $from_str
            gene g2, taxon t
        where dt.taxon_oid = ?
        and dt.homolog = g2.gene_oid
        and g2.taxon = t.taxon_oid
        $query_scaffold_str
        $scaffoldClause
        $taxonomyClause
        $rclause
        $imgClause
    };
    #print "getPhylumGenePercentInfoMinMax() sql: $sql<br/>\n";
    #print "getPhylumGenePercentInfoMinMax() binds: @binds<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my ( $min, $max ) = $cur->fetchrow();

    $cur->finish();

    return ( $min, $max );
}

#
# Gets phylum gene details for a range
#
# For now I did the tange filter in perl not in orcale
# because is seems faster
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
# param $recs_aref return data array of arrays
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
#
sub getPhylumGenePercentInfoRange {
    my (
         $dbh,    $taxon_oid,   
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
         $recs_aref, $start_coord, $end_coord, $scaffold_id
      )
      = @_;

    my @binds = ( $taxon_oid, $scaffold_id );

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );

    # this query is slow using the range
    # 1. i remove the metag taxon table - a little help in performance
    # 2. try to do start and end selection in perl not in oracle
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select dt.gene_oid, dt.taxon_oid, 
            dt.percent_identity, '', g2.strand, 
            g2.start_coord, g2.end_coord, g.scaffold, 
            s.scaffold_name, g2.gene_oid, g.start_coord, 
            g.end_coord, g.strand, s2.scaffold_name
        from dt_phylum_dist_genes dt, gene g, scaffold s, 
            gene g2, taxon t, scaffold s2
        where dt.gene_oid = g.gene_oid
            and g.scaffold = s.scaffold_oid
            and dt.taxon_oid = ?
            and dt.homolog = g2.gene_oid
            and dt.homolog_taxon = t.taxon_oid
            and g2.taxon = t.taxon_oid
            and g2.scaffold = s2.scaffold_oid
            and s2.scaffold_oid = ?
            $taxonomyClause
            $rclause
            $imgClause
        order by g2.start_coord, g2.end_coord
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
             $gene_oid,     $taxon_oid,   $percent,
             $taxon_name,   $strand,      $start,
             $end,          $scaffold,    $scaffold_name,
             $ref_gene_oid, $metag_start, $metag_end,
             $metag_strand, $ref_scaffold_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        # doing this range selection here is faster than doing it in oracle
        if (    ( $start >= $start_coord && $start <= $end_coord )
             || ( $end <= $end_coord && $end >= $start_coord ) )
        {

            # do nothing - keep the record
        } else {

            # skip - ignore the record
            next;
        }

        # I could have use not and put the skip in the if statement,
        # but I did it this way for readability.

        my @rec;

        # list is consistent with the array index global variables
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $ref_gene_oid );
        push( @rec,        '' );
        push( @rec,        $metag_start );
        push( @rec,        $metag_end );
        push( @rec,        $metag_strand );
        push( @rec,        $ref_scaffold_name );
        push( @$recs_aref, \@rec );

    }
    $cur->finish();
}


#
# Gets phylum gene's homolog gene details
#
# param("hitgene") is used to decide to show all ref genes
# or show only ref genes that have been hits
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $domain domain name
# param $phylum phylum name
# param $ir_class ir_class name
# param $ir_order ir_order name
# param $family family name
# param $genus genus
# param $species species
# param $recs_aref return data array of arrays
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
#
# return scaffold name or '' if no data
#
#
sub getPhylumGeneHomologPercentInfo {
    my (
         $dbh,    $taxon_oid, 
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
         $recs_aref, $start, $end, $scaffold_id
      )
      = @_;
    my $hitgene = param("hitgene");

    my @binds;

    if ( $hitgene eq 'false' || $hitgene eq "" ) {
        @binds = ( $start, $end, $end, $start );
    } else {
        @binds = ( $start, $end, $end, $start, $taxon_oid );
    }

    my $scaffoldClause = '';
    if ( $scaffold_id ne '' ) {
        $scaffoldClause = "and s.scaffold_oid = ? ";
        push( @binds, $scaffold_id );
    }

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );
    
    # better performance query from above but no percent info
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql;
    if ( $hitgene eq 'false' || $hitgene eq "" ) {
        # all the ref genes

        $sql = qq{
            select  g.gene_oid, t.taxon_oid, '', 
                t.taxon_display_name, g.strand, g.start_coord, 
                g.end_coord, g.scaffold, s.scaffold_name, 
                g.gene_oid, cfs.functions, g.product_name
            from taxon t, 
                gene g
                    left join gene_cog_groups gcg 
                        on g.gene_oid = gcg.gene_oid
                    left join cog_functions cfs 
                        on gcg.cog = cfs.cog_id,
                scaffold s
            where g.taxon = t.taxon_oid
                and g.scaffold = s.scaffold_oid
                and (
                    (g.start_coord >= ? and g.start_coord <= ?)  
                    or (g.end_coord <= ? and g.end_coord >= ?)
                )
                $scaffoldClause
                $taxonomyClause
                $rclause
                $imgClause
            order by g.start_coord, g.end_coord     
        };
    }
    else {

        #ref genes - just ones with the hits
        #my $sql = qq{
        #   select  dt.homolog, dt.taxon_oid, dt.percent_identity,
        #   t.taxon_display_name, g.strand, g.start_coord, g.end_coord,
        #   g.scaffold, s.scaffold_name, g.gene_oid, cfs.functions, g.product_name
        #   from dt_phylum_dist_genes dt, taxon t, gene g
        #   left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
        #   left join cog_functions cfs on gcg.cog = cfs.cog_id,
        #   scaffold s
        #   where dt.homolog = g.gene_oid
        #   and g.taxon = t.taxon_oid
        #   and g.scaffold = s.scaffold_oid
        #   and dt.taxon_oid = ?
        #    and ((g.start_coord >= ? and g.start_coord <= ?)
        #    or (g.end_coord <= ? and g.end_coord >= ?))
        #    $scaffoldClause
        #    $taxonomyClause
        #    order by g.start_coord, g.end_coord
        #};

        $sql = qq{
            select g.gene_oid, t.taxon_oid, '', 
                t.taxon_display_name, g.strand, g.start_coord, 
                g.end_coord, g.scaffold, s.scaffold_name, 
                g.gene_oid, cfs.functions, g.product_name
            from taxon t, 
                gene g
                    left join gene_cog_groups gcg 
                        on g.gene_oid = gcg.gene_oid
                    left join cog_functions cfs 
                        on gcg.cog = cfs.cog_id,
                scaffold s
            where g.taxon = t.taxon_oid
                and g.scaffold = s.scaffold_oid
                and (
                    (g.start_coord >= ? and g.start_coord <= ?)  
                    or (g.end_coord <= ? and g.end_coord >= ?)
                )
                and g.gene_oid in (
                    select  dt.homolog
                    from dt_phylum_dist_genes dt
                    where dt.taxon_oid = ?
                )
                $scaffoldClause
                $taxonomyClause
                $rclause
                $imgClause
            order by g.start_coord, g.end_coord     
        };        
    }

    my %unique_genes;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
             $gene_oid,      $taxon_oid,      $percent, $taxon_name,
             $strand,        $start,          $end,     $scaffold,
             $scaffold_name, $query_gene_oid, $cogfunc, $product_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $unique_genes{$gene_oid} = "";

        my @rec;
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $query_gene_oid );
        push( @rec,        $cogfunc );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        $product_name );
        push( @$recs_aref, \@rec );
    }
    $cur->finish();

    #webLog("scaffold $scaffold_id array size is $#$recs_aref\n");
    if ( $#$recs_aref < 0 ) {
        return '';
    }

    my $scaffold_name = $recs_aref->[0]->[$IDX_SCAFFOLD_NAME];
    my $count_genes   = keys %unique_genes;
    return ( $scaffold_name, $count_genes );
}

sub getRefGenomeHitCount {
    my (
         $dbh,    $taxon_oid, 
         $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
         $start,  $end, $scaffold_id
      )
      = @_;

    my @binds =
      ( $scaffold_id, $start, $end, $end, $start, $taxon_oid );

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2( 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push( @binds, @$binds_t_clause_ref ) if ( $binds_t_clause_ref );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql = qq{
        select  count( g.gene_oid)
        from taxon t, gene g
        where g.taxon = t.taxon_oid
            and g.scaffold = ?
            and (
                (g.start_coord >= ? and g.start_coord <= ?)  
                or (g.end_coord <= ? and g.end_coord >= ?)
            )   
            and g.gene_oid in (
                select  dt.homolog
                from dt_phylum_dist_genes dt
                where dt.taxon_oid = ?
            )
            $taxonomyClause     
            $rclause
            $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    
    return $count;
}


#
# draw the scatter plot
#
# param $start_coord - start coord
# param $end_coord - end coord
# param $drawn_aref - data to draw
# parma $geneoids_href - gene oids - not used
# param $xincr x coord increment value
# param $both draw only '+' '-' or '+-' strands
#
sub drawScatterPanel {
    my ( $start_coord, $end_coord, $drawn_aref, $geneoids_href, $xincr, $both, $merfs, $taxon_oid, $useOverlib ) = @_;

    my $fname = "both" if ( $both eq "+-" );
    $fname = "neg" if ( $both eq "-" );
    $fname = "pos" if ( $both eq "+" );

    my $size    = param("size");
    my $tooltip = param("tooltip");
    $tooltip = "true" if ( $tooltip eq "" );

    my $geneBaseUrl = "$main_cgi?section=GeneDetail&page=geneDetail";
    $geneBaseUrl = "main.cgi?section=MetaGeneDetail&page=metaGeneDetail&taxon_oid=$taxon_oid&data_type=assembled" if ($merfs);

    my $args = {
                 id                 => "$fname.$start_coord.$$",
                 start_coord        => $start_coord,
                 end_coord          => $end_coord,
                 coord_incr         => $xincr,
                 strand             => "+",
                 title              => "$start_coord .. $end_coord",
                 has_frame          => 1,
                 gene_page_base_url => $geneBaseUrl,
                 color_array_file   => $env->{large_color_array_file},
                 tmp_dir            => $tmp_dir,
                 tmp_url            => $tmp_url,
                 size               => $size,
                 tooltip            => $tooltip
    };

    my $sp          = new MetagGraphScatterPanel($args);
    my $color_array = $sp->{color_array};

    my $count = 0;

    foreach my $rec_aref (@$drawn_aref) {
        my $gene_oid       = $rec_aref->[$IDX_GENE_OID];
        my $percent        = $rec_aref->[$IDX_PERCENT];
        my $taxon_name     = $rec_aref->[$IDX_TAXON_NAME];
        my $strand         = $rec_aref->[$IDX_STRAND];
        my $start          = $rec_aref->[$IDX_START];
        my $end            = $rec_aref->[$IDX_END];
        my $scaffold       = $rec_aref->[$IDX_SCAFFOLD];
        my $scaffold_name  = $rec_aref->[$IDX_SCAFFOLD_NAME];
        my $yoffset        = $rec_aref->[$IDX_YOFFSET];
        my $wrapped        = $rec_aref->[$IDX_WRAPPED];
        my $query_gene_oid = $rec_aref->[$IDX_QUERY_GENE_OID];

        my $metag_start       = $rec_aref->[$IDX_METAG_START];
        my $metag_end         = $rec_aref->[$IDX_METAG_END];
        my $metag_strand      = $rec_aref->[$IDX_METAG_STRAND];
        my $ref_scaffold_name = $rec_aref->[$IDX_REF_SCAFFOLD_NAME];

        my $color = $sp->{color_red} if ( $percent >= 90 );
        $color = $sp->{color_blue} if ( $percent < 60 );
        $color = $sp->{color_green}
          if ( $percent < 90 && $percent >= 60 );

        my $label =
          "$gene_oid $scaffold_name $metag_start..$metag_end " . "$percent%  $ref_scaffold_name $start..$end $strand";

        if ( $both eq $strand ) {
            $sp->addLine( $start, $end, $percent, $color, $gene_oid, $label );
            $count++;
        } elsif ( $both eq "+-" ) {
            $sp->addLine( $start, $end, $percent, $color, $gene_oid, $label );
            $count++;
        }
    }

    my $s;
    if ( $useOverlib ) {
        $s = $sp->getMapHtml( $tooltip, "overlib" );
    }
    else {
        $s = $sp->getMapHtml($tooltip);
    }
    print "$s\n";
    if ( $useOverlib ) {
        print "<script src='$base_url/overlib.js'></script>\n";
    }
    print "<p>$count points\n";
}


#
# this draws the percentage panel.
#
# param $start_coord - start coord
# param $end_coord - end coord
# param $drawn_aref - array ref of arrays of records to draw
# param $scaffold_id - ref genome scaffold id used for cached file name
#
# see printProtein
sub drawPercentPanel {
    my ( $start_coord, $end_coord, $drawn_aref, $scaffold_id, $useOverlib ) = @_;

    my $args = {
                 id                 => "percent.$scaffold_id.$start_coord.$$",
                 start_coord        => $start_coord,
                 end_coord          => $end_coord,
                 coord_incr         => 5000,
                 strand             => "+",
                 title              => "$start_coord .. $end_coord",
                 has_frame          => 1,
                 gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
                 color_array_file   => $env->{large_color_array_file},
                 tmp_dir            => $tmp_dir,
                 tmp_url            => $tmp_url
    };

    my $sp          = new MetagGraphPercentPanel($args);
    my $color_array = $sp->{color_array};

    foreach my $rec_aref (@$drawn_aref) {
        my $gene_oid = $rec_aref->[$IDX_GENE_OID];
        my $percent  = $rec_aref->[$IDX_PERCENT];

        #my $taxon_name     = $rec_aref->[$IDX_TAXON_NAME];
        my $strand         = $rec_aref->[$IDX_STRAND];
        my $start          = $rec_aref->[$IDX_START];
        my $end            = $rec_aref->[$IDX_END];
        my $scaffold       = $rec_aref->[$IDX_SCAFFOLD];
        my $scaffold_name  = $rec_aref->[$IDX_SCAFFOLD_NAME];
        my $yoffset        = $rec_aref->[$IDX_YOFFSET];
        my $wrapped        = $rec_aref->[$IDX_WRAPPED];
        my $query_gene_oid = $rec_aref->[$IDX_QUERY_GENE_OID];

        my $metag_start       = $rec_aref->[$IDX_METAG_START];
        my $metag_end         = $rec_aref->[$IDX_METAG_END];
        my $metag_strand      = $rec_aref->[$IDX_METAG_STRAND];
        my $ref_scaffold_name = $rec_aref->[$IDX_REF_SCAFFOLD_NAME];

        last if ( $start > $end_coord );

        if ( $start < $start_coord && $end < $start_coord ) {

            #shift @$drawn_aref;
            next;
        }

        # draw line
        my $color;
        $color = $sp->{color_red}  if ( $percent >= 90 );
        $color = $sp->{color_blue} if ( $percent < 60 );
        $color = $sp->{color_green}
          if ( $percent < 90 && $percent >= 60 );

        my $label = "$gene_oid $scaffold_name $metag_start..$metag_end " . "$percent%  $ref_scaffold_name $start..$end";
        $sp->addLine( $start, $end, $percent, $color, $gene_oid, $label );
    }

    my $s;
    if ( $useOverlib ) {
        $s = $sp->getMapHtml("overlib");
    }
    else {
        $s = $sp->getMapHtml("Percent");
    }
    print "$s\n";
    if ( $useOverlib ) {
        print "<script src='$base_url/overlib.js'></script>\n";
    }
}

#
# print cog code coloring legend
# param $cogFunction_href - cog hash mapping
sub printCogColorLegend {
    my ($cogFunction_href) = @_;

    my @color_array = loadColorArrayFile( $env->{small_color_array_file} );
    my @keys        = sort( keys(%$cogFunction_href) );

    print "<h2>COG Code Coloring</h2>\n";
    print "<p>\n";
    print "Color code of function category for top COG hit ";
    print "is shown below.<br/>\n";
    print "</p>\n";

    if ($yui_tables) {
        print <<YUI;

       <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

    <style type="text/css">
        .yui-skin-sam .yui-dt th .yui-dt-liner {
        white-space:normal;
        }
    </style>

    <div class='yui-dt'>
    <table style='font-size:12px'>
    <th>
    <div class='yui-dt-liner'>
    <span>COG Code</span>
    </div>
    </th>
    <th>
    <div class='yui-dt-liner'>
    <span>COG Function Definition</span>
    </div>
    </th>
YUI
    } else {
        print <<IMG;
    <table class='img'  border=1>
    <th class='img' >COG Code</th>
    <th class='img' >COG Function Definition</th>
IMG
    }

    my $idx = 0;
    my $classStr;

    for my $k (@keys) {

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        my ( $definition, $count ) = split( /\t/, $cogFunction_href->{$k} );
        my $cogRec = $cogFunction_href->{$k};
        my ( $definition, $function_idx ) = split( /\t/, $cogRec );
        my $color = $color_array[$function_idx];
        my ( $r, $g, $b ) = split( /,/, $color );
        my $kcolor = sprintf( "#%02x%02x%02x", $r, $g, $b );

        #COG Code
        print "<tr class='$classStr'>\n";
        print "<td class='$classStr'\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print qq{ 
            <span style='border-left:1em solid $kcolor;padding-left:0.5em; margin-left:0.5em' />\n 
        };
        print "[$k]";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        #COG Function Definition
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print escHtml($definition);
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;
}

#
# Find max. yoffset
#
# param $aref array of arrays of drawn objects
# param $strand "+" or "-"
#
# return  int from 0 to max y offset
#
sub getMaxYoffset {
    my ( $aref, $strand ) = @_;

    my $offset = 0;
    foreach my $rec_aref (@$aref) {
        if ( $rec_aref->[$IDX_STRAND] eq $strand ) {
            if ( $rec_aref->[$IDX_YOFFSET] > $offset ) {
                $offset = $rec_aref->[$IDX_YOFFSET];
            }
        }
    }

    return $offset;
}


#
# Draw plot - fragmeent recur. viewer
#
# param $drawn_aref array of arrays of objects to draw
# param $start_coord plot start coord
# param $end_coord plot end coord
# param $title prefix to title - can be null or ""\
#
# $drawNohits - draw genes with no hits too
sub draw {
    my ( $drawn_aref, $start_coord, $end_coord, $title, $colorName, $useOverlib ) = @_;

    # set of genes drawn on plot so far
    my @distinct_genes;

    # calc y height
    # highest y +ve and highest y -ve offests
    my $yPosOffest = getMaxYoffset( $drawn_aref, "+" ) + 1;
    my $yNegOffest = getMaxYoffset( $drawn_aref, "-" ) + 1;

    # 20 for title space, 20 for axis and axis lables
    # 10 width of each bar
    my $yheight = 140;    #20 + 20 + ( $yPosOffest + $yNegOffest ) * 11;

    if ( $title ne "" ) {
        $title = $title . " $start_coord .. $end_coord";
    } else {
        $title = "$start_coord .. $end_coord";
    }

# gene_page_base_url => "$main_cgi?section=MetagenomeGraph&page=fragRecView2&cacheFile1=$file1&cacheFile2=$file2",
    my $args = {
           id                 => "gn.$start_coord.$$",
           start_coord        => $start_coord,
           end_coord          => $end_coord,
           coord_incr         => 5000,
           strand             => "+",
           title              => "$title",
           title_color        => "$colorName",
           has_frame          => 1,
           gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
           color_array_file   => $env->{large_color_array_file},
           tmp_dir            => $tmp_dir,
           tmp_url            => $tmp_url,
           y_height           => $yheight,
           y_neg_offset       => $yNegOffest,
           y_pos_offset       => $yPosOffest
    };

    my $sp          = new MetagGraphPanel($args);
    my $color_array = $sp->{color_array};

    foreach my $rec_aref (@$drawn_aref) {
        my $gene_oid          = $rec_aref->[$IDX_GENE_OID];
        my $percent           = $rec_aref->[$IDX_PERCENT];
        my $taxon_name        = $rec_aref->[$IDX_TAXON_NAME];
        my $strand            = $rec_aref->[$IDX_STRAND];
        my $start             = $rec_aref->[$IDX_START];
        my $end               = $rec_aref->[$IDX_END];
        my $scaffold          = $rec_aref->[$IDX_SCAFFOLD];
        my $scaffold_name     = $rec_aref->[$IDX_SCAFFOLD_NAME];
        my $yoffset           = $rec_aref->[$IDX_YOFFSET];
        my $wrapped           = $rec_aref->[$IDX_WRAPPED];
        my $query_gene_oid    = $rec_aref->[$IDX_QUERY_GENE_OID];
        my $metag_start       = $rec_aref->[$IDX_METAG_START];
        my $metag_end         = $rec_aref->[$IDX_METAG_END];
        my $metag_strand      = $rec_aref->[$IDX_METAG_STRAND];
        my $ref_scaffold_name = $rec_aref->[$IDX_REF_SCAFFOLD_NAME];
        my $product_name      = $rec_aref->[$IDX_PRODUCT_NAME];

        my $color = $sp->{color_light_red} if ( $percent >= 90 );

        #webLog("phylum gene's ortholog found $query_gene_oid\n");

        # phylum gene
        $color = $sp->{color_red}  if ( $percent >= 90 );
        $color = $sp->{color_blue} if ( $percent < 60 );
        $color = $sp->{color_green}
          if ( $percent < 90 && $percent >= 60 );

        #}

        my $label =
            "$gene_oid $product_name $scaffold_name $metag_start..$metag_end "
          . "$percent%  $ref_scaffold_name $start..$end";

        # the ones that are wrapped havea very low start coord
        if ( $wrapped == 1 && $start < $start_coord ) {
            $start = $start_coord;
        }

        my $offset = 10 * $yoffset;
        $sp->addGene( $gene_oid, $start, $end, $strand, $color, $label,
                      $offset );

        push( @distinct_genes, $gene_oid );
    }

    my $s;
    if ( $useOverlib ) {
        $s = $sp->getMapHtml("overlib");
    }
    else {
        $s = $sp->getMapHtml("Fragment Recuritment Viewer");
    }
    print "$s\n";
    if ( $useOverlib ) {
        print "<script src='$base_url/overlib.js'></script>\n";
    }
}


#
# draws scaffold plot for protein viewer or reg genome fragement view
#
# param $drawn_aref - array ref of array records to draw
# param $start_coord - start coord
# param $end_coord - end coord
# param $refTaxonName - ref taxon name
# param $cogFunction_ref - cog functions maping hash for coloring
# param $scaffold_id - ref genome selected scaffold id
#
sub draw3 {
    my (
         $drawn_aref,   $start_coord,     $end_coord,
         $refTaxonName, $cogFunction_ref, $scaffold_id, $useOverlib
      )
      = @_;

    # 20 for title space, 20 for axis and axis lables
    # 10 width of each bar
    my $yheight = 110;    #20 + 20 + ( $yPosOffest + $yNegOffest ) * 11;

    my $args = {
           id                 => "refgn$scaffold_id.$start_coord.$$",
           start_coord        => $start_coord,
           end_coord          => $end_coord,
           coord_incr         => 5000,
           strand             => "+",
           title              => "$refTaxonName",
           has_frame          => 1,
           gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
           color_array_file   => $env->{large_color_array_file},
           tmp_dir            => $tmp_dir,
           tmp_url            => $tmp_url,
           y_height           => $yheight
    };

    my $sp          = new MetagGraphPanel($args);
    my $color_array = $sp->{color_array};

    foreach my $rec_aref (@$drawn_aref) {
        my $gene_oid       = $rec_aref->[$IDX_GENE_OID];
        my $percent        = $rec_aref->[$IDX_PERCENT];
        my $taxon_name     = $rec_aref->[$IDX_TAXON_NAME];
        my $strand         = $rec_aref->[$IDX_STRAND];
        my $start          = $rec_aref->[$IDX_START];
        my $end            = $rec_aref->[$IDX_END];
        my $scaffold       = $rec_aref->[$IDX_SCAFFOLD];
        my $scaffold_name  = $rec_aref->[$IDX_SCAFFOLD_NAME];
        my $functions      = $rec_aref->[$IDX_COG_CODE];
        my $product_name   = $rec_aref->[$IDX_PRODUCT_NAME];
        my $yoffset        = $rec_aref->[$IDX_YOFFSET];
        my $wrapped        = $rec_aref->[$IDX_WRAPPED];
        my $query_gene_oid = $rec_aref->[$IDX_QUERY_GENE_OID];

        my $color  = $sp->{color_yellow};
        my $cogRec = $cogFunction_ref->{$functions};
        my ( $definition, $function_idx ) = split( /\t/, $cogRec );
        my $cogStr;

        #webLog("===== $cogRec\n");
        if ( $cogRec ne "" ) {
            $color  = @$color_array[$function_idx];
            $cogStr = " [$functions]";
        }

        my $label;
        if ( $percent ne "" ) {
            $label =
                "$gene_oid $product_name $percent%"
              . " $scaffold_name $start..$end";
        } else {
            $label = "$gene_oid $product_name $scaffold_name $start..$end";
        }

        if ( $functions ne "" ) {
            $label = $label . " COG_Code_" . "$functions";
        }

        # the ones that are wrapped havea very low start coord

        my $offset = 10 * $yoffset;
        $sp->addGene( $gene_oid, $start, $end, $strand, $color, $label,
                      $offset );
    }

    my $s;
    if ( $useOverlib ) {
        $s = $sp->getMapHtml("overlib");
    }
    else {
        $s = $sp->getMapHtml("Fragment Recuritment Viewer");
    }
    print "$s\n";
    if ( $useOverlib ) {
        print "<script src='$base_url/overlib.js'></script>\n";
    }
    
}

#
# protein viewer - only draws the select ref's genome scaffold and
# the metag gene's that hit the selected scaffold.
#
# param $dbh - database handler
# other parameters from url
#
# see drawPercentPanel
#
sub printProtein {
    my ($dbh, $section) = @_;

    my $taxon_oid = param("taxon_oid");
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $genus     = param("genus");
    my $species   = param("species");

    my $scaffolds       = param("scaffolds");
    my @scaffolds_array = split( /_/, $scaffolds );

    printStatusLine("Loading ...");
    
    print "<h1>Protein Viewer</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );    

    # get cog functions for coloring
    my %cogFunction = QueryUtil::getCogFunction($dbh);

    # param passed to next page s.t. I know what range to query for
    my $page      = param("pagecount");
    my $pagecount = 0;
    $pagecount = $page if ( $page ne "" );

    my $isMore = 0;

    foreach my $scaffold_id (@scaffolds_array) {

        # gets min max of start and end coord of metag on ref genome
        my ( $min1, $max1 ) = getPhylumGenePercentInfoMinMax(
              $dbh,    $taxon_oid, 
              $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
              $scaffold_id );

        if ( !defined($max1) || $max1 == 0 ) {
            next;
        }

        my $range = getMAXRANGE();
        if ( $max1 < $range ) {
            $range = $max1;
        }

        # plot x-coord start point
        # last seq to draw, last x-coord ceil value
        my $end   = ceil( $max1 / $range ) * $range;
        my $start = floor( $min1 / $range ) * $range + 1;

        # my tmp start and tmp end
        my $tmpstart = $start + $range + 1;

        # lets calc when the next metag is visiable on the scaffold
        my ( $tmps, $tmpe ) = getPhylumGeneCalcRange(
            $dbh,    $taxon_oid,   
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,     
            $start, $tmpstart, $scaffold_id, $pagecount, $range
        );
        $tmpstart = $tmps;
        my $tmpend = $tmpe;

        my @allrecords;
        my $scaffold_name = '';

        if ( $tmps != -1 ) {
            my $count;
            ( $scaffold_name, $count ) = getPhylumGeneHomologPercentInfo(
                 $dbh,    $taxon_oid, 
                 $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                 \@allrecords, $tmpstart, $tmpend, $scaffold_id
            );
        }

        if ( $scaffold_name ne '' ) {
            
            if ( $section eq 'MetaFileGraph' ) {
                draw3( \@allrecords, $tmpstart, $tmpend, "$scaffold_name",
                    \%cogFunction, $scaffold_id );
            }
            else {
                draw3( \@allrecords, $tmpstart, $tmpend, "$scaffold_name", 
                    \%cogFunction, $scaffold_id, 1 );
            }

            my @records;
            getPhylumGenePercentInfoRange(
                    $dbh,    $taxon_oid, 
                    $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                    \@records, $tmpstart, $tmpend, $scaffold_id
            );

            if ( $section eq 'MetaFileGraph' ) {
                drawPercentPanel( $tmpstart, $tmpend, \@records, $scaffold_id );
            }
            else {
                drawPercentPanel( $tmpstart, $tmpend, \@records, $scaffold_id, 1 );
            }
        }

        # does any of the scaffold continue?
        if ( $tmpend <= $end ) {
            $isMore = 1;
        }
    }

    if ( $section eq 'MetaFileGraph' ) {
        print toolTipCode();
    }

    if ($isMore) {
        print "<p>\n";
        $pagecount++;
        my $url = "$main_cgi?section=$section&page=fragRecView2";
        $url .= "&pagecount=$pagecount";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&domain=$domain";
        $url .= "&phylum=$phylum";
        $url .= "&ir_class=$ir_class" if ( $ir_class );
        $url .= "&ir_order=$ir_order" if ( $ir_order );
        $url .= "&family=$family"  if ( $family );
        $url .= "&genus=$genus"  if ( $genus );
        $url .= "&species=$species" if ( $species );
        $url .= "&hitgene=false";
        $url .= "&scaffolds=$scaffolds";

        print <<EOF;
    <input type='button' name='more' value='More...' 
    onClick='window.open("$url", "_self");' 
    class='smbutton' />
EOF

    }

    printCogColorLegend( \%cogFunction );

    printStatusLine( "Loaded.", 2 );
}

#
# Draw frag. rec viewer plot.
# Plots gene's seq location and % colour
#
# param $dbh database handler
# other parameters from url
#
# see printContinue1 for continue page
#
sub printFragment {
    my ($dbh, $section) = @_;

    my $taxon_oid = param("taxon_oid");    # query genome
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $genus     = param("genus");
    my $species   = param("species");
    my $scaffolds = param("scaffolds");    # from js combo box selection
    my $all_scaffolds = param("all_query_scaffold");

    # gets min max of start and end coord of metag on ref genome
    my $min            = param("min");
    my $max            = param("max");
    my $hitgene        = param("hitgene");
    my @query_scaffold = param("query_scaffold");    # query genome checkbox
    my @ref_scaffold   = param("ref_scaffold");

    # hack for 3.2 ?
    # new 3.1 or 3.2 to use scaffold cart
    my $query_scaffold_name = param("query_scaffold_name");
    if ( $query_scaffold_name eq "all" ) {
        $all_scaffolds = "all";
    } elsif ( $query_scaffold_name eq "all_cart" ) {
        
        # TODO get all cart's scaffolds
        $all_scaffolds = "";
        require ScaffoldCart;
        my $soids_aref = ScaffoldCart::getAllScaffoldOids();
        $soids_aref = PhyloUtil::validateCartSoids($dbh, $taxon_oid,  $soids_aref);
        @query_scaffold = @$soids_aref; 
    } else {

        # TODO scaffold cart name
        $all_scaffolds = "";
        require ScaffoldCart;
        my $soids_aref = ScaffoldCart::getScaffoldByCartName($query_scaffold_name);
        $soids_aref = PhyloUtil::validateCartSoids($dbh, $taxon_oid, $soids_aref);
        @query_scaffold = @$soids_aref;
    }

    # all scaffold overrides the any other query scaffold selection
    if ( $all_scaffolds eq "all" ) {
        @query_scaffold = ();
    }

    if ($img_ken) {
        print "hello you are using developer's version<br/>\n";
        print "query scaffold: @query_scaffold <br/>";
        print "ref scaffold: @ref_scaffold <br/>";
        print "js ref scaffold: $scaffolds <br/>";
        print "all query scaffold: $all_scaffolds <br/>";
        print "min: $min <br/>";
        print "max: $max <br/>";
        print "hit: $hitgene<br/>";
    }

    if ( $#query_scaffold < 0 ) {

        # default is all scaffolds
        $all_scaffolds  = "all";
        @query_scaffold = ();
    }

    if ( $#query_scaffold > 999 && $all_scaffolds ne "all" ) {
        webError(   "Please select less than 999 query scaffolds or"
                  . " check 'Select ALL query scaffolds'" );
    }

    if ( $#ref_scaffold > 19 ) {
        webError("Please only select 20 reference scaffolds!");
    }
    if ( $#ref_scaffold < 0 && $scaffolds eq "" ) {
        webError("Please select a reference scaffold!");
    }

    # if js combo override any other ref scaffold selection
    if ( $scaffolds ne "" ) {
        @ref_scaffold = ($scaffolds);
    }

    # ref scaffolds
    my %scaffolds_hash;
    foreach my $oid (@ref_scaffold) {
        $scaffolds_hash{$oid} = "";
    }

    # query scaffold
    my %scaffolds_query_hash;
    foreach my $oid (@query_scaffold) {
        $scaffolds_query_hash{$oid} = "";
    }

    printStatusLine("Loading ...");

    print "<h1>Reference Genome Context Viewer<br>for Fragments</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );    

    print "<p>\n";
    print "<font size=1>";
    print "Query genes percent identity colors:";
    print "<br><font color='red'>Red 90%</font>\n";
    print "<br><font color='green'>Green 60%</font>\n";
    print "<br><font color='blue'>Blue 30%</font>\n";
    print "</font>";
    print "</p>\n";

    # get cog functions for coloring
    my %cogFunction = QueryUtil::getCogFunction($dbh);

    if ( $min eq "" || $max eq "" ) {
        ( $min, $max ) = getPhylumGenePercentInfoMinMax(
               $dbh,    $taxon_oid, 
               $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
               "",        \@query_scaffold
        );

        # set max to ref or metag?
        my ( $scaffold_start, $scaffold_end ) = getScaffoldMinMax( $dbh, \@ref_scaffold );
        webLog("metag s,e $min, $max\n");
        webLog("ref   s,e $scaffold_start, $scaffold_end\n");

        # min should always be the metag start
        # but the end should be smallest max
        $max = $scaffold_end if ( $scaffold_end < $max );
        webLog("final metag s,e $min, $max\n");
    }

    my $range = getMAXRANGE();
    if ( $max < $range ) {
        $range = $max;
    }

    # user selected a bad combination of
    # query scaffold and ref scaffold
    if( $range eq "" || $range == 0 ) {
        #$dbh->disconnect();
        printStatusLine( "No data.", 2 );
        webError("There is no data to plot for query scaffold and reference scaffolds you've selected!");
    }

    my $end   = ceil( $max / $range ) * $range;
    my $start = floor( $min / $range ) * $range + 1;

    my $i = $start;

    my $count = 0;
    for ( ; $i <= $end && $count < getNUMGRAPHSPERPAGE() ; $i = $i + $range ) {

        my $tmpend = $i + $range;

        # now get data for metag genes
        my @records;
        webLog("getPhylumGenePercentInfo\n");

        #  add query scaffold ids here
        if ( $all_scaffolds eq "all" ) {
            getPhylumGenePercentInfo(
                  $dbh,      $taxon_oid,
                  $domain,   $phylum,
                  $ir_class, $ir_order,
                  $family,
                  $genus,    $species,
                  \@records, $i,
                  $tmpend,   \%scaffolds_hash,
                  ""
            );
        } else {
            getPhylumGenePercentInfo(
                  $dbh,
                  $taxon_oid,
                  $domain,
                  $phylum,
                  $ir_class,
                  $ir_order,
                  $family,
                  $genus,
                  $species,
                  \@records,
                  $i,
                  $tmpend,
                  \%scaffolds_hash,
                  \%scaffolds_query_hash,
                  \@query_scaffold
            );
        }

        # find next page of data
        # no records
        # go to next set of data
        if ( !(@records) || $#records < 0 ) {
            webLog("no records found between $i, $tmpend\n");
            next;
        } else {
            $count++;
        }

        # offset
        foreach my $rec_aref (@records) {
            if ( $rec_aref->[$IDX_PERCENT] >= 90 ) {

                # 90 %
                $rec_aref->[$IDX_YOFFSET] = 2;
            } elsif (    $rec_aref->[$IDX_PERCENT] < 90
                      && $rec_aref->[$IDX_PERCENT] >= 60 )
            {
                $rec_aref->[$IDX_YOFFSET] = 1;
            } else {

                # 30 %
                $rec_aref->[$IDX_YOFFSET] = 0;
            }
        }

        # draw metag gene
        my $title = "Query Genome: ";
        if ( $#records > -1 ) {
            my $rec_aref = $records[0];
            $title .= $rec_aref->[$IDX_TAXON_NAME];
        }

        if ( $section eq 'MetaFileGraph' ) {
            draw( \@records, $i, $tmpend, $title, "red" );
        }
        else {
            draw( \@records, $i, $tmpend, $title, "red", 1 );
        }

        foreach my $scaffold_id (@ref_scaffold) {

            my @allrecords;
            webLog("getPhylumGeneHomologPercentInfo\n");
            my ( $scaffold_name, $outof ) = getPhylumGeneHomologPercentInfo(
                 $dbh,    $taxon_oid, 
                 $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                 \@allrecords, $i, $tmpend, $scaffold_id
            );

            # get gene product name here ?

            if ( $scaffold_name ne '' ) {
                my $hitcount = getRefGenomeHitCount(
                    $dbh,      $taxon_oid,
                    $domain,   $phylum,
                    $ir_class, $ir_order, 
                    $family,
                    $genus,    $species,
                    $i,        $tmpend,
                    $scaffold_id
                );

                if ( $section eq 'MetaFileGraph' ) {
                    draw3( \@allrecords, $i, $tmpend,
                           "$scaffold_name - $hitcount hits of $outof genes",
                           \%cogFunction, $scaffold_id );
                }
                else {
                    draw3( \@allrecords, $i, $tmpend, 
                           "$scaffold_name - $hitcount hits of $outof genes",
                           \%cogFunction, $scaffold_id, 1 );
                }
            }
        }

    }

    if ( $section eq 'MetaFileGraph' ) {
        print toolTipCode();
    }

    printMainForm();
    print "<p>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "domain",    $domain );
    print hiddenVar( "phylum",    $phylum );
    print hiddenVar( "ir_class",  $ir_class );
    print hiddenVar( "ir_order",  $ir_order );
    print hiddenVar( "family",    $family );
    print hiddenVar( "genus",     $genus );
    print hiddenVar( "species",   $species );
    print hiddenVar( "section",   "MetagenomeGraph" );
    print hiddenVar( "page",      "fragRecView1" );
    print hiddenVar( "hitgene",   "$hitgene" );
    print hiddenVar( "min",       "" );
    print hiddenVar( "max",       "" );
    print hiddenVar( "scaffolds", $scaffolds );          # for js combo box
    print hiddenVar( "all_query_scaffold", $all_scaffolds );
    print hiddenVar( "query_scaffold_name", $query_scaffold_name );

    foreach my $id (@query_scaffold) {
        print hiddenVar( "query_scaffold", $id );
    }

    foreach my $id (@ref_scaffold) {
        print hiddenVar( "ref_scaffold", $id );
    }

    # this will have to be a form t
    # 1. query scafold
    # 2. ref scaffold
    #
    # previous button
    if ( $start > 1 ) {
        my $tmin = $start - $range * 2;
        $tmin = 1 if ( $tmin < 1 );

        print qq{
        <input type="button" 
        name="_section_MetagenomeGraph_fragRecView1" 
        value="< Previous" 
        class="meddefbutton"
        onClick="mySubmit($tmin, $max)" />        
        };
    }

    if ( $i <= $end ) {

        # next page new min is $i
        print qq{
        <input type="button" 
        name="_section_MetagenomeGraph_fragRecView1" 
        value="Next >" 
        class="meddefbutton"
        onClick="mySubmit($i, $max)" />        
        };
    }

    print "</p>\n";

    print qq{
        <script>
        function mySubmit(min, max) {  
            document.mainForm.min.value = min;
            document.mainForm.max.value = max; 
            document.mainForm.submit();
        }
        </script>
    };

    print end_form();

    if ( $count == 0 ) {

        # no plots drawn
        printStatusLine( "Loaded.", 2 );
        webError(   "There are no query genes within reference genomes range"
                  . " $min to $i!" );
    } else {
        printCogColorLegend( \%cogFunction );
    }

    printStatusLine( "Loaded.", 2 );
}


#
# Gets all metag data for plots
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $bin_oid bin oid
# param $method_oid bin method oid
# param $family family name
# param $genus genus
# param $species species
# param $recs_aref - return data array
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
# list of scaffold ids $scaffolds_aref
sub getBinGenePercentInfoRange {
    my (
         $dbh,         $taxon_oid, $bin_oid,     $method_oid,
         $family,      $genus,     $species,     $recs_aref,
         $start_coord, $end_coord, $scaffold_id, $scaffolds_href
      )
      = @_;

    my @binds = ( $method_oid, $bin_oid, $taxon_oid );

    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t2.family = ? ";
        push( @binds, $family );
    } else {
        $familyClause = "and t2.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t2.species is null";
        } else {
            $familyClause .= " and t2.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t2.genus is null";
        } else {
            $familyClause .= " and t2.genus = ? ";
            push( @binds, $genus );
        }
    }

    my $scaffoldClause = "and g2.scaffold = ? ";
    if ( $scaffold_id eq "" ) {
        $scaffoldClause = "";
    } else {
        push( @binds, $scaffold_id );
    }

    # this query is slow using the range
    # 1. i remove the metag taxon table - a little help in performance
    # 2. try to do start and end selection in perl not in oracle
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql = qq{
        select  dt.gene_oid, dt.taxon_oid, dt.percent_identity,
            '', g2.strand, g2.start_coord, g2.end_coord,
            g.scaffold, '', g2.gene_oid, g.start_coord, 
            g.end_coord, g.strand, s2.scaffold_name, s2.scaffold_oid
        from bin b, bin_scaffolds bs, gene g, 
            dt_phylum_dist_genes dt, gene g2, 
            taxon t2, scaffold s2
        where b.bin_method = ?
            and b.is_default = 'Yes'
            and b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and g.scaffold = bs.scaffold
            and g.taxon = ?
            and g.taxon = dt.taxon_oid
            and dt.gene_oid = g.gene_oid
            and dt.homolog = g2.gene_oid
            and g2.taxon = t2.taxon_oid
            and g2.scaffold = s2.scaffold_oid
            $familyClause
            $scaffoldClause              
            $rclause
            $imgClause
        order by g2.start_coord, g2.end_coord
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
             $gene_oid,     $taxon_oid,         $percent,
             $taxon_name,   $strand,            $start,
             $end,          $scaffold,          $scaffold_name,
             $ref_gene_oid, $metag_start,       $metag_end,
             $metag_strand, $ref_scaffold_name, $ref_scaffold_oid
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        # doing this range selection here is faster than doing it in oracle
        if (    ( $start >= $start_coord && $start <= $end_coord )
             || ( $end <= $end_coord && $end >= $start_coord ) )
        {

            # do nothing
        } else {

            # skip
            next;
        }

        if ( $scaffolds_href ne "" ) {
            if ( exists $scaffolds_href->{$ref_scaffold_oid} ) {

                # do noting
            } else {
                next;
            }
        }

        my @rec;

        # list is consistent with the array index global variables
        push( @rec, $gene_oid );
        push( @rec, $taxon_oid );
        push( @rec, $percent );
        push( @rec, $taxon_name );
        push( @rec, $strand );
        push( @rec, $start );
        push( @rec, $end );
        push( @rec, $scaffold );
        push( @rec, $scaffold_name );
        push( @rec, 0 );
        push( @rec, 0 );
        push( @rec, $ref_gene_oid );
        push( @rec, '' );
        push( @rec, $metag_start );
        push( @rec, $metag_end );
        push( @rec, $metag_strand );
        push( @rec, $ref_scaffold_name );

        # product name holder
        push( @rec,        "" );
        push( @$recs_aref, \@rec );

    }
    $cur->finish();
}

#
# Gets bin's gene next range on the ref genome
# Used by protein plot
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $bin_oid bin oid
# param $method_oid bin method oid
# param $family family name
# param $genus genus
# param $species species
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
# param $page - which page
# param $range - length of x-axis per page
# return (start, end) otherwise (-1,-1) nothing found
sub getBinGeneCalcRange {
    my (
         $dbh,       $taxon_oid,   $bin_oid, $method_oid,
         $family,    $genus,       $species, $start_coord,
         $end_coord, $scaffold_id, $page,    $range
      )
      = @_;

    my @binds = ( $method_oid, $bin_oid, $taxon_oid, $scaffold_id );

    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t2.family = ? ";
        push( @binds, $family );
    } else {
        $familyClause = "and t2.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t2.species is null";
        } else {
            $familyClause .= " and t2.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t2.genus is null";
        } else {
            $familyClause .= " and t2.genus = ? ";
            push( @binds, $genus );
        }
    }

    # this query is slow using the range
    # 1. i remove the metag taxon table - a little help in performance
    # 2. try to do start and end selection in perl not in oracle
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql = qq{
        select  g2.start_coord
        from bin b, bin_scaffolds bs, gene g, 
            dt_phylum_dist_genes dt, gene g2, taxon t2
        where b.bin_method = ?
            and b.is_default = 'Yes'
            and b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and g.scaffold = bs.scaffold
            and g.taxon = ?
            and g.taxon = dt.taxon_oid
            and dt.gene_oid = g.gene_oid
            and dt.homolog = g2.gene_oid
            and dt.homolog_taxon = t2.taxon_oid
            and g2.taxon = t2.taxon_oid
            and g2.scaffold = ?
            $familyClause              
            $rclause
            $imgClause
        order by g2.start_coord
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $i = 0;

    for ( ; ; ) {
        my ($start) = $cur->fetchrow();
        last if !$start;

        if ( $start >= $start_coord && $start <= $end_coord ) {

            #webLog(" $start >= $start_coord  && $start <= $end_coord \n");
            if ( $i >= $page ) {
                $cur->finish();
                return ( $start_coord, $end_coord );
            }

        } elsif ( $start >= $end_coord ) {

            # move range
            while ( $start >= $end_coord ) {
                $start_coord = $start_coord + $range;
                $end_coord   = $end_coord + $range;
            }
            $i++;

            if ( $i >= $page ) {
                $cur->finish();
                return ( $start_coord, $end_coord );
            }

        }
    }
    $cur->finish();

    # nothing found
    return ( -1, -1 );
}



#
# gets min max of start and end coord of metag on ref genome
#
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $bin_oid bin id
# param $method_oid bin's method id
# param $family family name
# param $genus genus
# param $species species
# param $scaffold_id - ref gene scaffold oid can be ""
#
# return (min, max)
#
sub getBinGenePercentInfoMinMax {
    my (
         $dbh,    $taxon_oid, $bin_oid, $method_oid,
         $family, $genus,     $species, $scaffold_id
      )
      = @_;

    my @binds = ( $bin_oid, $taxon_oid, $family );

    my $familyClause = "";
    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t2.species is null";
        } else {
            $familyClause .= " and t2.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t2.genus is null";
        } else {
            $familyClause .= " and t2.genus = ? ";
            push( @binds, $genus );
        }
    }

    my $scaffoldClause = " and g2.scaffold = ? ";
    if ( $scaffold_id eq "" ) {
        $scaffoldClause = "";
    } else {
        push( @binds, $scaffold_id );
    }

    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql = qq{
       select  min( g2.start_coord), max(g2.end_coord)
       from bin b, bin_scaffolds bs, gene g,
           dt_phylum_dist_genes dt, gene g2, taxon t2
       where b.bin_method = $method_oid
           and b.is_default = 'Yes'
           and b.bin_oid = ?
           and b.bin_oid = bs.bin_oid
           and g.scaffold = bs.scaffold
           and g.taxon = ?
           and g.taxon = dt.taxon_oid
           and dt.gene_oid = g.gene_oid
           and dt.homolog = g2.gene_oid
           and dt.homolog_taxon = t2.taxon_oid
           and g2.taxon = t2.taxon_oid
           and t2.family = ?
           $familyClause
           $scaffoldClause
           $rclause
           $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my ( $min, $max ) = $cur->fetchrow();

    $cur->finish();

    return ( $min, $max );
}

#
# Gets bin gene's homolog gene details
#
# param("hitgene") is used to decide to show all ref genes
# or show only ref genes that have been hits
#
# param $dbh database handler
# param $taxon_oid taxon oid
# param $bin_oid bin id
# param $method_oid bin method id
# param $family family name
# param $genus genus
# param $species species
# param $recs_aref return data array of arrays
# param $start_coord - ref gene start coord
# param $end_coord - ref gene end coord
# param $scaffold_id - ref gene scaffold oid
#
# return scaffold name or '' if no data
#
#
sub getBinGeneHomologPercentInfo {
    my (
         $dbh,     $bin_oid,   $method_oid, $family, $genus,
         $species, $recs_aref, $start,      $end,    $scaffold_id
      )
      = @_;

    my @binds = ( $start, $end, $end, $start );

    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t.family = ? ";
        push( @binds, $family );
    } else {
        $familyClause = "and t.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t.species is null";
        } else {
            $familyClause .= " and t.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t.genus is null";
        } else {
            $familyClause .= " and t.genus = ? ";
            push( @binds, $genus );
        }
    }

    my $scaffoldClause = '';
    if ( $scaffold_id ne '' ) {
        $scaffoldClause = "and s.scaffold_oid = ? ";
        push( @binds, $scaffold_id );
    }

    # ref genes - just ones with the hits
    # better performance query but no percent info
    my $sql;

    # all the ref genes
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    $sql = qq{
        select  g.gene_oid, t.taxon_oid, '', 
            t.taxon_display_name, g.strand, g.start_coord, 
            g.end_coord, g.scaffold, s.scaffold_name, 
            g.gene_oid, cfs.functions
        from taxon t, 
            gene g
                left join gene_cog_groups gcg 
                    on g.gene_oid = gcg.gene_oid
                left join cog_functions cfs 
                    on gcg.cog = cfs.cog_id, 
            scaffold s
        where g.taxon = t.taxon_oid
            and g.scaffold = s.scaffold_oid
            and (
                (g.start_coord >= ? and g.start_coord <= ?)  
                or (g.end_coord <= ? and g.end_coord >= ?)
            )
            $rclause
            $imgClause
            $familyClause
            $scaffoldClause
        order by g.start_coord, g.end_coord     
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my (
             $gene_oid,      $taxon_oid,      $percent, $taxon_name,
             $strand,        $start,          $end,     $scaffold,
             $scaffold_name, $query_gene_oid, $cogfunc
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my @rec;
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $query_gene_oid );
        push( @rec,        $cogfunc );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        '' );
        push( @rec,        '' );                # product name
        push( @$recs_aref, \@rec );
    }
    $cur->finish();

    #webLog("scaffold $scaffold_id array size is $#$recs_aref\n");
    if ( $#$recs_aref < 0 ) {
        return '';
    }

    my $scaffold_name = $recs_aref->[0]->[$IDX_SCAFFOLD_NAME];
    return $scaffold_name;
}

#
# creates bin scatter plot page
#
# param $dbh datbase handler
# param others see url
#
# $strand - all, pos or neg
#
sub printBinScatterPlot {
    my ($dbh, $section) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $method_oid = param("method_oid");
    my $bin_oid    = param("bin_oid");
    my $family     = param("family");
    my $strand     = param("strand");
    my $species    = param("species");
    my $genus      = param("genus");

    printStatusLine("Loading ...");
    my $taxon_name  = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    my $method_name = QueryUtil::getMethodName( $dbh, $method_oid );
    my $bin_name    = QueryUtil::getBinName( $dbh, $bin_oid );
    my $env_sample  = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    print "<h2>Protein Recruitment Plot<br>$taxon_name<br>$method_name $bin_name" . "<br>Family $family</h2>\n";

    print "<font size=1>";
    print "<br>Red 90%\n";
    print "<br>Green 60%\n";
    print "<br>Blue 30%\n";
    print "</font>";
    print "<p>\n";

    my @records;
    my $geneoids_href;    # not used

    my $min = -1;
    my $max = -1;

    my @binds = ( $env_sample, $method_oid, $bin_oid, $taxon_oid );

    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t2.family = ? ";
        push( @binds, $family );
    } else {
        $familyClause = "and t2.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t2.species is null";
        } else {
            $familyClause .= " and t2.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t2.genus is null";
        } else {
            $familyClause .= " and t2.genus = ? ";
            push( @binds, $genus );
        }
    }

   my $rclause   = WebUtil::urClause('t2');
   my $imgClause = WebUtil::imgClause('t2');
   my $sql = qq{
       select  dt.gene_oid, dt.taxon_oid, dt.percent_identity, 
       '$taxon_name', g2.strand, g2.start_coord, 
           g2.end_coord, g.scaffold, s.scaffold_name, 
           g2.gene_oid, g.start_coord, g.end_coord, 
           g.strand, s2.scaffold_name
       from bin b, bin_method bm, bin_scaffolds bs, 
           gene g, scaffold s, dt_phylum_dist_genes dt, 
           gene g2, taxon t2, scaffold s2
       where b.env_sample = ?
           and b.bin_method = bm.bin_method_oid
           and b.is_default = 'Yes'
           and bm.bin_method_oid = ?
           and b.bin_oid = ?
           and b.bin_oid = bs.bin_oid
           and g.scaffold = bs.scaffold
           and g.scaffold = s.scaffold_oid
           and g.taxon = ?
           and g.taxon = dt.taxon_oid
           and dt.gene_oid = g.gene_oid
           and dt.homolog = g2.gene_oid
           and dt.homolog_taxon = t2.taxon_oid
           and g2.taxon = t2.taxon_oid
           and g2.scaffold = s2.scaffold_oid
           $familyClause
           $rclause
           $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my (
             $gene_oid,    $taxon_oid, $percent,      $taxon_name,    $strand,
             $start,       $end,       $scaffold,     $scaffold_name, $ref_gene_oid,
             $metag_start, $metag_end, $metag_strand, $ref_scaffold_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $max = $end   if ( $max == -1 );
        $min = $start if ( $min == -1 );

        $max = $end   if ( $end > $max );
        $min = $start if ( $start < $min );

        my @rec;

        # list is consistent with the array index global variables
        push( @rec,     $gene_oid );
        push( @rec,     $taxon_oid );
        push( @rec,     $percent );
        push( @rec,     $taxon_name );
        push( @rec,     $strand );
        push( @rec,     $start );
        push( @rec,     $end );
        push( @rec,     $scaffold );
        push( @rec,     $scaffold_name );
        push( @rec,     0 );
        push( @rec,     0 );
        push( @rec,     $ref_gene_oid );
        push( @rec,     '' );
        push( @rec,     $metag_start );
        push( @rec,     $metag_end );
        push( @rec,     $metag_strand );
        push( @rec,     $ref_scaffold_name );
        push( @records, \@rec );

    }
    $cur->finish();

    my $seq_length = $max;
    my $xincr      = ceil( $seq_length / 10 );

    webLog("max is $max\n");
    webLog("seq_length is $seq_length\n");
    webLog("xincr is $xincr\n");

    # lets make sure the last point is visible on my plot
    $seq_length = $seq_length + ceil( $xincr / 2 );

    if ( $strand eq "pos" ) {
        print "<p>Positive Strands Plot<p>\n";
        if ( $section eq 'MetaFileGraph' ) {
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "+" );
        }
        else {        
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "+", '', '', 1 );
        }
    } elsif ( $strand eq "neg" ) {
        print "<p>Negative Strands Plot<p>\n";
        if ( $section eq 'MetaFileGraph' ) {
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "-" );
        }
        else {        
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "-", '', '', 1 );
        }
    } else {
        print "<p>All Strands Plot<p>\n";
        if ( $section eq 'MetaFileGraph' ) {
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "+-" );
        }
        else {        
            drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr, "+-", '', '', 1 );
        }
    }

    if ( $section eq 'MetaFileGraph' ) {
        print toolTipCode();
    }

    printStatusLine( "Loaded.", 2 );
}

#
# creates bin protein plot
#
# param $dbh datbase handler
# param others see url
#
#
sub printBinProtein {
    my ($dbh, $section) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $bin_oid    = param("bin_oid");
    my $method_oid = param("method_oid");

    #my $ref_taxon_id  = param("ref_taxon_id");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    my $scaffolds       = param("scaffolds");
    my @scaffolds_array = split( /_/, $scaffolds );

    print "<h1>Protein Viewer</h1>\n";
    print "<h3>$family $genus $species</h3>\n";
    print "<p>\n";
    printStatusLine("Loading ...");

    # get cog functions for coloring
    my %cogFunction = QueryUtil::getCogFunction($dbh);

    # param passed to next page s.t. I know what range to query for
    my $page      = param("pagecount");
    my $pagecount = 0;
    $pagecount = $page if ( $page ne "" );

    my $isMore = 0;

    foreach my $scaffold_id (@scaffolds_array) {

        # gets min max of start and end coord of metag on ref genome
        my ( $min1, $max1 ) =
          getBinGenePercentInfoMinMax( $dbh, $taxon_oid, $bin_oid, $method_oid, $family, $genus, $species, $scaffold_id );

        if ( !defined($max1) || $max1 == 0 ) {
            next;
        }

        my $range = getMAXRANGE();
        if ( $max1 < $range ) {
            $range = $max1;
        }

        # plot x-coord start point
        # last seq to draw, last x-coord ceil value
        my $end   = ceil( $max1 / $range ) * $range;
        my $start = floor( $min1 / $range ) * $range + 1;

        # my tmp start and tmp end
        my $tmpstart = $start + $range + 1;

        # lets calc when the next metag is visiable on the scaffold
        my ( $tmps, $tmpe ) = getBinGeneCalcRange( $dbh,     $taxon_oid, $bin_oid,  $method_oid,  $family,    $genus,
                                                   $species, $start,     $tmpstart, $scaffold_id, $pagecount, $range );
        $tmpstart = $tmps;
        my $tmpend = $tmpe;

        my @allrecords;
        my $scaffold_name = '';

        if ( $tmps != -1 ) {
            $scaffold_name = getBinGeneHomologPercentInfo( $dbh,     $bin_oid,     $method_oid, $family, $genus,
                                                           $species, \@allrecords, $tmpstart,   $tmpend, $scaffold_id );
        }

        if ( $scaffold_name ne '' ) {

            if ( $section eq 'MetaFileGraph' ) {
                draw3( \@allrecords, $tmpstart, $tmpend, "$scaffold_name", \%cogFunction, $scaffold_id );
            }
            else {        
                draw3( \@allrecords, $tmpstart, $tmpend, "$scaffold_name", \%cogFunction, $scaffold_id, 1 );
            }

            my @records;
            getBinGenePercentInfoRange( $dbh,     $taxon_oid, $bin_oid,  $method_oid, $family, $genus,
                                        $species, \@records,  $tmpstart, $tmpend,     $scaffold_id );

            if ( $section eq 'MetaFileGraph' ) {
                drawPercentPanel( $tmpstart, $tmpend, \@records, $scaffold_id );
            }
            else {        
                drawPercentPanel( $tmpstart, $tmpend, \@records, $scaffold_id, 1 );
            }
        }

        # does any of the scaffold continue?
        if ( $tmpend <= $end ) {
            $isMore = 1;
        }
    }

    if ( $section eq 'MetaFileGraph' ) {
        print toolTipCode();
    }

    if ($isMore) {
        print "<p>\n";
        $pagecount++;
        my $url = "$main_cgi?section=$section&page=binfragRecView2";
        $url .= "&pagecount=$pagecount";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&bin_oid=$bin_oid";
        $url .= "&method_oid=$method_oid";
        $url .= "&family=$family";
        $url .= "&genus=$genus";
        $url .= "&species=$species" if ( $species ne "" );
        $url .= "&scaffolds=$scaffolds";

        print <<EOF;
    <input type='button' name='more' value='More...' 
    onClick='window.open("$url", "_self");' 
    class='smbutton' />
EOF

    }

    printCogColorLegend( \%cogFunction );

    printStatusLine( "Loaded.", 2 );
}

#
# creates bin fragment plot page
#
# param $dbh datbase handler
# param others see url
#
sub printBinFragment {
    my ($dbh, $section) = @_;

    my $taxon_oid  = param("taxon_oid");
    my $bin_oid    = param("bin_oid");
    my $method_oid = param("method_oid");

    #my $ref_taxon_id  = param("ref_taxon_id");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    my $scaffolds = param("scaffolds");
    my @scaffolds_array = split( /_/, $scaffolds );
    my %scaffolds_hash;
    foreach my $oid (@scaffolds_array) {
        $scaffolds_hash{$oid} = "";
    }

    print "<h1>Reference Genome Context Viewer<br>for Fragments</h1>\n";
    print "<h3>$family $genus $species</h3>\n";

    printStatusLine("Loading ...");

    print "<p>\n";
    print "Blue - 30%<br>\n";
    print "Green - 60%<br>\n";
    print "Red - 90%<br>\n";

    # get cog functions for coloring
    my %cogFunction = QueryUtil::getCogFunction($dbh);

    # gets min max of start and end coord of metag on ref genome
    my $min = param("min");
    my $max = param("max");
    if ( $min eq "" || $max eq "" ) {
        ( $min, $max ) =
          getBinGenePercentInfoMinMax( $dbh, $taxon_oid, $bin_oid, $method_oid, $family, $genus, $species, "" );
    }

    my $range = getMAXRANGE();
    if ( $max < $range ) {
        $range = $max;
    }

    my $end   = ceil( $max / $range ) * $range;
    my $start = floor( $min / $range ) * $range + 1;

    my $i = $start;

    my $count = 0;
    for ( ; $i <= $end && $count < getNUMGRAPHSPERPAGE() ; $i = $i + $range ) {

        my $tmpend = $i + $range;

        #webLog("tmpend: $tmpend\n");
        #webLog("i: $i\n");
        #webLog("range: $range\n");

        # now get data for metag genes
        my @records;
        getBinGenePercentInfoRange( $dbh,     $taxon_oid, $bin_oid, $method_oid, $family, $genus,
                                    $species, \@records,  $i,       $tmpend,     "",      \%scaffolds_hash );

        # find next page of data
        if ( !(@records) || $#records < 0 ) {
            next;
        } else {
            $count++;
        }

        # offset
        foreach my $rec_aref (@records) {
            if ( $rec_aref->[$IDX_PERCENT] >= 90 ) {
                # 90 %
                $rec_aref->[$IDX_YOFFSET] = 2;
            } elsif (    $rec_aref->[$IDX_PERCENT] < 90
                      && $rec_aref->[$IDX_PERCENT] >= 60 )
            {
                $rec_aref->[$IDX_YOFFSET] = 1;
            } else {
                # 30 %
                $rec_aref->[$IDX_YOFFSET] = 0;
            }
        }

        # draw metag gene
        if ( $section eq 'MetaFileGraph' ) {
            draw( \@records, $i, $tmpend );
        }
        else {
            draw( \@records, $i, $tmpend, '', '', 1 );            
        }

        foreach my $scaffold_id (@scaffolds_array) {

            my @allrecords;
            my $scaffold_name = getBinGeneHomologPercentInfo( $dbh,     $bin_oid,     $method_oid, $family, $genus,
                                                              $species, \@allrecords, $i,          $tmpend, $scaffold_id );

            if ( $scaffold_name ne '' ) {
                if ( $section eq 'MetaFileGraph' ) {
                    draw3( \@allrecords, $i, $tmpend, "$scaffold_name", \%cogFunction, $scaffold_id );
                }
                else {
                    draw3( \@allrecords, $i, $tmpend, "$scaffold_name", \%cogFunction, $scaffold_id, 1 );
                }
            }
        }
    }

    if ( $section eq 'MetaFileGraph' ) {
        print toolTipCode();
    }

    if ( $i <= $end ) {

        # next page new min is $i

        print "<p>\n";
        my $url = "$main_cgi?section=$section&page=binfragRecView1";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&bin_oid=$bin_oid";
        $url .= "&method_oid=$method_oid";
        $url .= "&family=$family";
        $url .= "&genus=$genus";
        $url .= "&species=$species" if ( $species ne "" );
        $url .= "&scaffolds=$scaffolds";
        $url .= "&min=$i&max=$max";

        print <<EOF;
    <input type='button' name='more' value='More...' 
    onClick='window.open("$url", "_self");' 
    class='smbutton' />
EOF

    }

    printCogColorLegend( \%cogFunction );

    printStatusLine( "Loaded.", 2 );

}


1;
