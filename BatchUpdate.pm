############################################################################
# BatchUpdate.pm - Utilties for batch update of derived data.
#     --es 10/04/2006
############################################################################
package BatchUpdate;
use strict;
use Data::Dumper;
use ImgTermNode;
use ImgTermNodeMgr;
use WebUtil;
use WebConfig;

my $verbose = 1;

############################################################################
# imgTermBatchUpdate - Batch update for dervied data dues to
#    changes in IMG terms.
############################################################################
sub imgTermBatchUpdate {

    my $dbh = dbLogin( );

    imgTermPathUpdate( $dbh );

    ## --es 10/04/2006 This is still kind of slow.
    #imgTermStatsUpdate( $dbh );

    #$dbh->disconnect( );
}

############################################################################
# imgTermPathUpdate - Update img_term_path for direct mapping of
#   parent to leaf terms.
############################################################################
sub imgTermPathUpdate {
    my( $dbh ) = @_;

    my $mgr = new ImgTermNodeMgr( );
    $mgr->insertMapNodes( $dbh );
}

############################################################################
# imgTermStatsUpdate - Update stats when terms have changed.
#   We break this up for individual taxons to avoid deadlocks
#   rather than one large transaction over a large database.
#   (The values may be updated again by external scripts before
#    the whole database is actually published.  For now, this
#    will have to do.)
#   This stuff may also easier for showing progress bars, in
#   the future.
# NO LONGER IN USE - 20120824
############################################################################
sub imgTermStatsUpdate_old {
    my( $dbh ) = @_;

    my $sql = qq{
        select taxon_oid
	from taxon
	order by taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @taxon_oids;
    for( ;; ) {
       my( $taxon_oid ) = $cur->fetchrow( );
       last if !$taxon_oid;
       push( @taxon_oids, $taxon_oid );
    }
    for my $taxon_oid( @taxon_oids ) {
	updateImgTermStats( $dbh, $taxon_oid );
	#updateImgPwayStats( $dbh, $taxon_oid );
    }

}

############################################################################
# updateImgTermStats - Update taxon_stats for genes_in_img_terms
# NO LONGER IN USE - 20120824
############################################################################
sub updateImgTermStats_old {
    my( $dbh, $taxon_oid ) = @_;

    my $rClause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
       select count( g.gene_oid )
       from gene_img_functions g
       where g.taxon = ? 
       $rClause
       $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my( $cnt ) = $cur->fetchrow( );
    $cur->finish( );

    my $sql = qq{
       update taxon_stats
       set genes_in_img_terms = $cnt
       where taxon_oid = $taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

    my $sql = qq{
       update taxon_stats
       set genes_in_img_terms_pc =
          genes_in_img_terms / total_gene_count
       where taxon_oid = $taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );
}

############################################################################
# updateImgPwayStats - Update taxon_stats for genes_in_img_pways
# NO LONGER IN USE - 20120824
############################################################################
sub updateImgPwayStats_old {
    my( $dbh, $taxon_oid ) = @_;

    ### Uggghh.  I hate this.
    my $sql = qq{
       select count( distinct g.gene_oid ) g_count
       from gene_img_functions g,
           img_reaction_catalysts irc, img_pathway_reactions ipr,
           img_pathway ipw
       where g.taxon = $taxon_oid
       and g.function = irc.catalysts
       and irc.rxn_oid = ipr.rxn
       and ipr.pathway_oid = ipw.pathway_oid
          union
       select count( distinct g.gene_oid ) g_count
       from gene_img_functions g,
           img_reaction_t_components itc, img_pathway_reactions ipr,
           img_pathway ipw
       where g.taxon = $taxon_oid
       and g.function = itc.term
       and itc.rxn_oid = ipr.rxn
       and ipr.pathway_oid = ipw.pathway_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $cnt ) = $cur->fetchrow( );
    $cur->finish( );

    my $sql = qq{
       update taxon_stats
       set genes_in_img_pways = $cnt
       where taxon_oid = $taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

    my $sql = qq{
       update taxon_stats
       set genes_in_img_pways_pc =
          genes_in_img_pways / total_gene_count
       where taxon_oid = $taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );
}


1;
