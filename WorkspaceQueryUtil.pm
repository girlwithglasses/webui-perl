############################################################################
# WorkspaceQueryUtil.pm
# $Id: WorkspaceQueryUtil.pm 33910 2015-08-06 05:10:03Z jinghuahuang $
############################################################################
package WorkspaceQueryUtil;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );

use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $in_file  = $env->{in_file};
my $new_func_count  = $env->{new_func_count};


############################################################################
# getDbTaxonFuncGeneSql - return the func gene sql for db single taxon
############################################################################
sub getDbSingleTaxonFuncGeneSql {
    my ( $func_id, $taxon, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql = "";
    my @bindList = ();

    my $db_id = $func_id;
    $db_id =~ s/'/''/g; # replace ' with '' if any
    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g
            where g.cog = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g
            where g.pfam_family = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tigrfams g
            where g.ext_accession = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_kog_groups g
            where g.kog = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_ko_terms g
            where g.ko_terms = ?
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_ko_enzymes g
            where g.enzymes = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select distinct g.gene_oid
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($id2, $taxon);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tc_families g
            where g.tc_family = ? 
            and g.taxon = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id, $taxon);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon = ?
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid
                from gene_img_functions g
                where g.function = ?
                and g.taxon = ?
                $rclause
                $imgClause
            };
            @bindList = ($id2, $taxon);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #my $rclause2 = WebUtil::urClause('g2.taxon');
        #my $imgClause2 = WebUtil::imgClauseNoTaxon('g2.taxon');

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select g.gene_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #    and ipr.rxn = irc.rxn_oid
            #    and irc.catalysts = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon = ?
            #    $rclause
            #    $imgClause
            #    union
            #    select g.gene_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #    and ipr.rxn = irtc.rxn_oid
            #    and irtc.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon = ?
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.taxon = ?
                $rclause
                $imgClause
                union
                select g.gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = g.function
                and g.taxon = ?
                $rclause
                $imgClause
        	};
            @bindList = ($id2, $taxon, $id2, $taxon);
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon = ?
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.taxon = ?
                $rclause
                $imgClause
            };
            @bindList = ($id2, $taxon);
        }
    }

    return ( $sql, @bindList );
}

############################################################################
# getDbFuncTaxonSql - return the taxon sql for specified func
############################################################################
sub getDbFuncTaxonSql {
    my ( $func_id, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql = "";
    my @bindList = ();

    my $db_id = $func_id;
    $db_id =~ s/'/''/g; # replace ' with '' if any
    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.taxon 
            from gene_cog_groups g 
            where g.cog = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.taxon 
            from gene_pfam_families g 
            where g.pfam_family = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_tigrfams g
            where g.ext_accession = ? 
            $rclause
            $imgClause            
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_kog_groups g
            where g.kog = ? 
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^KO\:/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_ko_terms g
            where f.ko_terms = ?
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_ko_enzymes g
            where g.enzymes = ? 
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select distinct g.taxon
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ? 
            $rclause
            $imgClause
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ? 
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.taxon
            from gene_tc_families g
            where g.tc_family = ? 
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.taxon
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.taxon
                from gene_img_functions g
                where g.function = ?
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #my $rclause1 = WebUtil::urClause('g2.taxon');
        #my $imgClause1 = WebUtil::imgClauseNoTaxon('g2.taxon');

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select g.taxon
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #    and ipr.rxn = irc.rxn_oid
            #    and irc.catalysts = dtp.term_oid
            #    and dtp.map_term = g.function
            #    $rclause
            #    $imgClause
            #    union
            #    select g.taxon
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #    and ipr.rxn = irtc.rxn_oid
            #    and irtc.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.taxon
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                $rclause
                $imgClause
                union
                select g.taxon
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = g.function
                $rclause
                $imgClause
            };
            @bindList = ( $id2, $id2 );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.taxon
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.taxon
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }

    return ( $sql, @bindList );
}

############################################################################
# getDbTaxonSimpleFuncGeneSql - return simple gene info sql for specified db taxons and func
############################################################################
sub getDbTaxonSimpleFuncGeneSql {
    my ( $func_id, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql      = "";
    my @bindList = ();

    my $db_id = $func_id;
    $db_id =~ s/'/''/g; # replace ' with '' if any
    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog 
            from gene_cog_groups g
            where g.cog = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family
            from gene_pfam_families g
            where g.pfam_family = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };                
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g
            where g.ext_accession = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.kog 
            from gene_kog_groups g
            where g.kog = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms 
            from gene_ko_terms g
            where g.ko_terms = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.enzymes 
            from gene_ko_enzymes g
            where g.enzymes = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.id
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.tc_family
            from gene_tc_families g
            where g.tc_family = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, it.term_oid
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, g.function
                from gene_img_functions g
                where g.function = ?
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #my $rclause1 = WebUtil::urClause('g2.taxon');
        #my $imgClause1 = WebUtil::imgClauseNoTaxon('g2.taxon');

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #        and ipr.rxn = irc.rxn_oid
            #        and irc.catalysts = dtp.term_oid
            #        and dtp.map_term = g.function
            #        and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #    union
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ? 
            #        and ipr.rxn = irtc.rxn_oid
            #        and irtc.term = dtp.term_oid
            #        and dtp.map_term = g.function
            #        and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                    and ipr.rxn = irc.rxn_oid
                    and irc.catalysts = g.function
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
                union
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid = ? 
                    and ipr.rxn = irtc.rxn_oid
                    and irtc.term = g.function
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ( $id2, $id2 );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, pt.parts_list_oid
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, pt.parts_list_oid
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }

    return ( $sql, @bindList );
}


############################################################################
# getDbTaxonFuncGeneCountSql - return the gene count sql for specified db taxons and func
############################################################################
sub getDbTaxonFuncGeneCountSql {
    my ( $func_id, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql      = "";
    my @bindList = ();

    my $db_id = $func_id;
    $db_id =~ s/'/''/g; # replace ' with '' if any
    if ( $func_id =~ /COG/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_cog_groups g
        #    where g.cog = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};

    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select sum(g.gene_count)
            from mv_taxon_cog_stat g
            where g.cog = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_kog_groups g
        #    where g.kog = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select sum(g.gene_count)
            from mv_taxon_kog_stat g
            where g.kog = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_pfam_families g
        #    where g.pfam_family = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};                

    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select sum(g.gene_count)
            from mv_taxon_pfam_stat g
            where g.pfam_family = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_tigrfams g
        #    where g.ext_accession = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};

    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select sum(g.gene_count)
            from mv_taxon_tfam_stat g
            where g.ext_accession = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_ko_terms g
        #    where g.ko_terms = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};

    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select sum(g.gene_count)
            from mv_taxon_ko_stat g
            where g.ko_term = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        #$sql = qq{
        #    select count(*)
        #    from gene_ko_enzymes g
        #    where g.enzymes = ?
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #};

    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select sum(g.gene_count)
            from mv_taxon_ec_stat g
            where g.enzyme = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select count(*)
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select count(*)
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select count(*)
            from gene_tc_families g
            where g.tc_family = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select count(*)
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select count(*)
                from gene_img_functions g
                where g.function = ?
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select count(*) from (
            #        select g.gene_oid
            #        from img_pathway_reactions ipr,
            #            img_reaction_catalysts irc,
            #            dt_img_term_path dtp, gene_img_functions g
            #        where ipr.pathway_oid = ? 
            #            and ipr.rxn = irc.rxn_oid
            #            and irc.catalysts = dtp.term_oid
            #            and dtp.map_term = g.function
            #            and g.taxon in ( $taxon_str )
            #        $rclause
            #        $imgClause
            #        union
            #        select g.gene_oid
            #        from img_pathway_reactions ipr,
            #            img_reaction_t_components irtc,
            #            dt_img_term_path dtp, gene_img_functions g
            #        where ipr.pathway_oid = ? 
            #            and ipr.rxn = irtc.rxn_oid
            #            and irtc.term = dtp.term_oid
            #            and dtp.map_term = g.function
            #            and g.taxon in ( $taxon_str )
            #        $rclause
            #        $imgClause
            #    )
            #};
            $sql = qq{
                select count(*) from (
                    select g.gene_oid
                    from img_pathway_reactions ipr,
                        img_reaction_catalysts irc,
                        gene_img_functions g
                    where ipr.pathway_oid = ? 
                        and ipr.rxn = irc.rxn_oid
                        and irc.catalysts = g.function
                        and g.taxon in ( $taxon_str )
                    $rclause
                    $imgClause
                    union
                    select g.gene_oid
                    from img_pathway_reactions ipr,
                        img_reaction_t_components irtc,
                        gene_img_functions g
                    where ipr.pathway_oid = ? 
                        and ipr.rxn = irtc.rxn_oid
                        and irtc.term = g.function
                        and g.taxon in ( $taxon_str )
                    $rclause
                    $imgClause
                )
            };
            @bindList = ( $id2, $id2 );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select count(*)
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select count(*)
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }

    return ( $sql, @bindList );
}

############################################################################
# getDbTaxonFuncsGeneCountSql - return the gene count sql for specified db taxons and funcs
############################################################################
sub getDbTaxonFuncsGeneCountSql {
    my ( $dbh, $func_ids_ref, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    
    my $sql;
    my @bindList;

    my ($func_id, $func_ids_str) = getFuncIdsStr( $dbh, $func_ids_ref );

    if ( $func_id =~ /COG/i ) {
        #$sql = qq{
        #    select g.cog, count(distinct g.gene_oid)
        #    from gene_cog_groups g
        #    where g.cog in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.cog
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.cog, sum(g.gene_count)
            from mv_taxon_cog_stat g
            where g.cog in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.cog
        };
    }
    elsif ( $func_id =~ /KOG/i ) {
        #$sql = qq{
        #    select g.kog, count(distinct g.gene_oid)
        #    from gene_kog_groups g
        #    where g.kog in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.kog
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.kog, sum(g.gene_count)
            from mv_taxon_kog_stat g
            where g.kog in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.kog
        };
    }
    elsif ( $func_id =~ /pfam/i ) {
        #$sql = qq{
        #    select g.pfam_family, count(distinct g.gene_oid)
        #    from gene_pfam_families g
        #    where g.pfam_family in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.pfam_family
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.pfam_family, sum(g.gene_count)
            from mv_taxon_pfam_stat g
            where g.pfam_family in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.pfam_family
        };
    }
    elsif ( $func_id =~ /TIGR/i ) {
        #$sql = qq{
        #    select g.ext_accession, count(distinct g.gene_oid)
        #    from gene_tigrfams g
        #    where g.ext_accession in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.ext_accession
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.ext_accession, sum(g.gene_count)
            from mv_taxon_tfam_stat g
            where g.ext_accession in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.ext_accession
        };
    }
    elsif ( $func_id =~ /KO/i ) {
        #$sql = qq{
        #    select g.ko_terms, count(distinct g.gene_oid)
        #    from gene_ko_terms g
        #    where g.ko_terms in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.ko_terms
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.ko_term, sum(g.gene_count)
            from mv_taxon_ko_stat g
            where g.ko_term in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.ko_term
        };
    }
    elsif ( $func_id =~ /EC/i ) {
        #$sql = qq{
        #    select g.enzymes, count(distinct g.gene_oid)
        #    from gene_ko_enzymes g
        #    where g.enzymes in ( $func_ids_str )
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by g.enzymes
        #};

        $rclause = WebUtil::urClause('g.taxon_oid');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
        $sql = qq{
            select g.enzyme, sum(g.gene_count)
            from mv_taxon_ec_stat g
            where g.enzyme in ( $func_ids_str )
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
            group by g.enzyme
        };
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        $sql = qq{
            select brp.in_pwys, count(distinct g.gene_oid)
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where g.biocyc_rxn = brp.unique_id
            and brp.in_pwys in ( $func_ids_str )
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by brp.in_pwys
        };
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select g.id, count(distinct g.gene_oid)
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id in ( $func_ids_str )
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.id
        };
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select g.tc_family, count(distinct g.gene_oid)
            from gene_tc_families g
            where g.tc_family in ( $func_ids_str )
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.tc_family
        };
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        #$sql = qq{
        #    select it.term_oid, count(distinct g.gene_oid)
        #    from img_term it, dt_img_term_path dtp, gene_img_functions g
        #    where it.term_oid in ( $func_ids_str )
        #    and it.term_oid = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by it.term_oid
        #};
        $sql = qq{
            select g.function, count(distinct g.gene_oid)
            from gene_img_functions g
            where g.function in ( $func_ids_str )
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.function
        };
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #$sql = qq{
        #    select new.pathway_oid, count(distinct new.gene_oid) 
        #    from (
        #        select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #        from img_pathway_reactions ipr,
        #            img_reaction_catalysts irc,
        #            dt_img_term_path dtp, gene_img_functions g
        #        where ipr.pathway_oid in ( $func_ids_str )
        #            and ipr.rxn = irc.rxn_oid
        #            and irc.catalysts = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $taxon_str )
        #        $rclause
        #        $imgClause
        #        union
        #        select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #        from img_pathway_reactions ipr,
        #            img_reaction_t_components irtc,
        #            dt_img_term_path dtp, gene_img_functions g
        #        where ipr.pathway_oid in ( $func_ids_str )
        #            and ipr.rxn = irtc.rxn_oid
        #            and irtc.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $taxon_str )
        #        $rclause
        #        $imgClause
        #    ) new
        #    group by new.pathway_oid
        #};
        $sql = qq{
            select new.pathway_oid, count(distinct new.gene_oid) 
            from (
                select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_ids_str ) 
                    and ipr.rxn = irc.rxn_oid
                    and irc.catalysts = g.function
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
                union
                select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_ids_str )
                    and ipr.rxn = irtc.rxn_oid
                    and irtc.term = g.function
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            ) new
            group by new.pathway_oid
        };
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        #$sql = qq{
        #    select pt.parts_list_oid, count(distinct g.gene_oid)
        #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #    where pt.parts_list_oid in ( $func_ids_str )
        #    and pt.term = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.taxon in ( $taxon_str )
        #    $rclause
        #    $imgClause
        #    group by pt.parts_list_oid
        #};
        $sql = qq{
            select pt.parts_list_oid, count(distinct g.gene_oid)
            from img_parts_list_img_terms pt, gene_img_functions g
            where pt.parts_list_oid in ( $func_ids_str )
            and pt.term = g.function
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by pt.parts_list_oid
        };
    }

    return ( $sql, @bindList );
}


##### Amy: I need this function in WorkspaceRuleSet.pm.
############################################################################
# getDbTaxonFuncGroupByCountSql
############################################################################
sub getDbTaxonFuncGroupByCountSql {
    my ( $func_id, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql      = "";
    my @bindList = ();

    my $db_id = $func_id;
    # no need to replace if we use bind
    # $db_id =~ s/'/''/g; # replace ' with '' if any

    if ( $func_id =~ /COG/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_cog_stat g
            where g.cog = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_pfam_stat g
            where g.pfam_family = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_tfam_stat g
            where g.ext_accession = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_kog_stat g
            where g.kog = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        

	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_ko_stat g
            where g.ko_term = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

	@bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
    	$rclause = WebUtil::urClause('g.taxon_oid');
    	$imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');        
    
    	$sql = qq{
            select g.taxon_oid, g.gene_count
            from mv_taxon_ec_stat g
            where g.enzyme = ?
            and g.taxon_oid in ( $taxon_str )
            $rclause
            $imgClause
        };

        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        # $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select g.taxon, count(*)
            from gene_biocyc_rxns g, biocyc_reaction_in_pwys brp
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.taxon
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select g.taxon, count(*)
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.taxon
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select g.taxon, count(*)
            from gene_tc_families g
            where g.tc_family = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.taxon
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
	    $sql = qq{
            select g.taxon, count(*)
            from gene_img_functions g
            where g.function = ?
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            group by g.taxon
        };
	    @bindList = ($id2);
	}
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #my $rclause1 = WebUtil::urClause('g2.taxon');
        #my $imgClause1 = WebUtil::imgClauseNoTaxon('g2.taxon');

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            $sql = qq{
                select g.taxon, g.status
                from img_pathway_assertions g
                where g.pathway_oid = ? 
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ( $id2 );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            $sql = qq{
                select g.taxon, count(*)
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
                group by g.taxon
            };
            @bindList = ($id2);
        }
    }

    return ( $sql, @bindList );
}


############################################################################
# getDbTaxonFuncGeneSql - return the func gene sql for db taxons
############################################################################
sub getDbTaxonFuncGeneSql {
    my ( $func_id, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql;
    my @bindList;

    my $db_id = $func_id;
    $db_id =~ s/'/''/g; # replace ' with '' if any
    if ( $func_id =~ /COG\_Category/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, cfs.functions, g.taxon, 
                g.gene_display_name
            from gene_cog_groups f, gene g, cog_functions cfs
            where cfs.functions = ? 
            and f.cog = cfs.cog_id
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG\_Pathway/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, cpcm.cog_pathway_oid, g.taxon, 
                g.gene_display_name
            from gene_cog_groups f, gene g, cog_pathway_cog_members cpcm
            where cpcm.cog_pathway_oid = ? 
            and f.cog = cpcm.cog_members
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.cog, g.taxon, 
                g.gene_display_name
            from gene_cog_groups f, gene g
            where f.cog = ? 
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, kp2.pathway_oid, g.taxon, 
                g.gene_display_name
            from kegg_pathway kp, kegg_pathway kp2, 
                image_roi ir, image_roi_ko_terms rk, ko_term_enzymes kt,
                gene_ko_enzymes f, gene g
            where kp2.pathway_oid = ?
            and kp2.category = kp.category
            and kp.pathway_oid = ir.pathway
            and ir.roi_id = rk.roi_id
            and rk.ko_terms = kt.ko_id
            and kt.enzymes = f.enzymes
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, kp2.pathway_oid, g.taxon, 
                g.gene_display_name
            from gene_ko_terms f, gene g, image_roi ir, image_roi_ko_terms rk,
                 kegg_pathway kp, kegg_pathway kp2
            where kp2.pathway_oid = ?
            and kp2.category = kp.category
            and kp.pathway_oid = ir.pathway
            and ir.roi_id = rk.roi_id
            and rk.ko_terms = f.ko_terms
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, ir.pathway, g.taxon, 
                g.gene_display_name
            from image_roi ir, image_roi_ko_terms rk, ko_term_enzymes kt, 
                gene_ko_enzymes f, gene g
            where ir.pathway = ? 
            and ir.roi_id = rk.roi_id
            and rk.ko_terms = kt.ko_id
            and kt.enzymes = f.enzymes
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, ir.pathway, g.taxon, 
                g.gene_display_name
            from gene_ko_terms f, gene g, image_roi ir, image_roi_ko_terms rk
            where ir.pathway = ? 
            and ir.roi_id = rk.roi_id
            and rk.ko_terms = f.ko_terms
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /Pfam\_Category/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, pfc.functions, g.taxon, 
                g.gene_display_name
            from gene_pfam_families f, gene g, pfam_family_cogs pfc
            where pfc.functions = ? 
            and f.pfam_family = pfc.ext_accession
            and g.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.pfam_family, g.taxon, 
                g.gene_display_name
            from gene_pfam_families f, gene g
            where f.pfam_family = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGRfam\_Role/i ) {
    	my ($id1, $id2) = split(/\:/, $func_id);
    	if ( $id2 ) {
    	    $db_id = $id2;
    	}
        $sql = qq{
            select distinct g.gene_oid, trs.roles, g.taxon, 
                g.gene_display_name
            from gene_tigrfams f, gene g, tigrfam_roles trs
            where trs.roles = ? 
            and f.ext_accession = trs.ext_accession
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ext_accession, g.taxon, 
                g.gene_display_name
            from gene_tigrfams f, gene g
            where f.ext_accession = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.kog, g.taxon, 
                g.gene_display_name
            from gene_kog_groups f, gene g
            where f.kog = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ko_terms, g.taxon, 
                g.gene_display_name
            from gene_ko_terms f, gene g
            where f.ko_terms = ?
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.enzymes, g.taxon, 
                g.gene_display_name
            from gene_ko_enzymes f, gene g
            where f.enzymes = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys, g.taxon, 
                g.gene_display_name
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns f, gene g
            where brp.in_pwys = ? 
            and brp.unique_id = f.biocyc_rxn
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.id, g.taxon,
                g.gene_display_name
            from gene_xref_families f, gene g
            where f.db_name = 'InterPro'
            and f.id = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.tc_family, g.taxon,
                g.gene_display_name
            from gene_tc_families f, gene g
            where f.tc_family = ? 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, it.term_oid, g.taxon,
            #        g.gene_display_name
            #    from img_term it, dt_img_term_path dtp, gene_img_functions f, gene g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = f.function
            #    and f.gene_oid = g.gene_oid
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, f.function, g.taxon,
                    g.gene_display_name
                from gene_img_functions f, gene g
                where f.function = ?
                and f.gene_oid = g.gene_oid
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {

        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select g.gene_oid, gif.function, 
            #        g.taxon, g.gene_display_name
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions gif, gene g
            #    where ipr.pathway_oid = ? 
            #        and ipr.rxn = irc.rxn_oid
            #        and irc.catalysts = dtp.term_oid
            #        and dtp.map_term = gif.function
            #        and gif.gene_oid = g.gene_oid
            #        and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #    union
            #    select g.gene_oid, gif.function, 
            #        g.taxon, g.gene_display_name
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions gif, gene g
            #    where ipr.pathway_oid = ? 
            #        and ipr.rxn = irtc.rxn_oid
            #        and irtc.term = dtp.term_oid
            #        and dtp.map_term = gif.function
            #        and gif.gene_oid = g.gene_oid
            #        and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.gene_oid, gif.function, 
                    g.taxon, g.gene_display_name
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions gif, gene g
                where ipr.pathway_oid = ? 
                    and ipr.rxn = irc.rxn_oid
                    and irc.catalysts = gif.function
                    and gif.gene_oid = g.gene_oid
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
                union
                select g.gene_oid, gif.function, 
                    g.taxon, g.gene_display_name
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions gif, gene g
                where ipr.pathway_oid = ? 
                    and ipr.rxn = irtc.rxn_oid
                    and irtc.term = gif.function
                    and gif.gene_oid = g.gene_oid
                    and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ( $id2, $id2 );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, pt.parts_list_oid, 
            #        g.taxon, g.gene_display_name
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions f, gene g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = f.function
            #    and f.gene_oid = g.gene_oid
            #    and g.taxon in ( $taxon_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, pt.parts_list_oid, 
                    g.taxon, g.gene_display_name
                from img_parts_list_img_terms pt, gene_img_functions f, gene g
                where pt.parts_list_oid = ?
                and pt.term = f.function
                and f.gene_oid = g.gene_oid
                and g.taxon in ( $taxon_str )
                $rclause
                $imgClause
            };
            @bindList = ($id2);
        }
    }

    #print "WorkspaceQueryUtil::getDbTaxonFuncGeneSql sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbTaxonFuncGeneSql bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}

############################################################################
# getDbTaxonFuncsGenesSql - return the funcs genes sql for db taxons
############################################################################
sub getDbTaxonFuncsGenesSql {
    my ( $dbh, $func_ids_ref, $taxon_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    
    my $sql;
    my @bindList;

    my ($func_id, $func_ids_str) = getFuncIdsStr( $dbh, $func_ids_ref );

    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.cog, 
                g.taxon, g.gene_display_name
            from gene_cog_groups f, gene g
            where f.cog in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.kog, 
                g.taxon, g.gene_display_name
            from gene_kog_groups f, gene g
            where f.kog in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.pfam_family, 
                g.taxon, g.gene_display_name
            from gene_pfam_families f, gene g
            where f.pfam_family in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ext_accession, 
                g.taxon, g.gene_display_name
            from gene_tigrfams f, gene g
            where f.ext_accession in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ko_terms, 
                g.taxon, g.gene_display_name
            from gene_ko_terms f, gene g
            where f.ko_terms in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.enzymes, 
                g.taxon, g.gene_display_name
            from gene_ko_enzymes f, gene g
            where f.enzymes in ( $func_ids_str ) 
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys, 
                g.taxon, g.gene_display_name
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns f, gene g
            where brp.in_pwys in ( $func_ids_str )
            and brp.unique_id = f.biocyc_rxn
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.id, 
                g.taxon, g.gene_display_name
            from gene_xref_families f, gene g
            where f.db_name = 'InterPro'
            and f.id in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.tc_family, 
                g.taxon, g.gene_display_name
            from gene_tc_families f, gene g
            where f.tc_family in ( $func_ids_str )
            and f.taxon in ( $taxon_str )
            and f.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.function, 
                g.taxon, g.gene_display_name
            from gene_img_functions f, gene g
            where f.function in ( $func_ids_str )
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        $sql = qq{
            select g.gene_oid, gif.function, 
                g.taxon, g.gene_display_name
            from img_pathway_reactions ipr,
                img_reaction_catalysts irc,
                gene_img_functions gif, gene g
            where ipr.pathway_oid in ( $func_ids_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = gif.function
                and gif.gene_oid = g.gene_oid
                and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
            union
            select g.gene_oid, gif.function, 
                g.taxon, g.gene_display_name
            from img_pathway_reactions ipr,
                img_reaction_t_components irtc,
                gene_img_functions gif, gene g
            where ipr.pathway_oid in ( $func_ids_str )
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = gif.function
                and gif.gene_oid = g.gene_oid
                and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        $sql = qq{
            select distinct g.gene_oid, pt.parts_list_oid, g.taxon,
                g.gene_display_name
            from img_parts_list_img_terms pt, gene_img_functions f, gene g
            where pt.parts_list_oid in ( $func_ids_str )
            and pt.term = f.function
            and f.gene_oid = g.gene_oid
            and g.taxon in ( $taxon_str )
            $rclause
            $imgClause
        };
    }

    #print "WorkspaceQueryUtil::getDbTaxonFuncsGenesSql() sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbTaxonFuncsGenesSql() bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}


############################################################################
# getDbScaffoldFuncGeneSql - return the func gene sql for db scaffolds
############################################################################
sub getDbScaffoldFuncGeneSql {
    my ( $func_id, $scaf_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql;
    my @bindList;

    my $db_id = $func_id;
    $db_id =~ s/'/''/g;    # replace ' with '' if any
    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.cog 
            from gene g, gene_cog_groups f
            where g.gene_oid = f.gene_oid
                and f.cog = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
         };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.kog 
            from gene g, gene_kog_groups f
            where g.gene_oid = f.gene_oid
                and f.kog = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.pfam_family
            from gene g, gene_pfam_families f
            where g.gene_oid = f.gene_oid
                and f.pfam_family = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ext_accession 
            from gene g, gene_tigrfams f
            where g.gene_oid = f.gene_oid
                and f.ext_accession = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.ko_terms 
            from gene g, gene_ko_terms f
            where g.gene_oid = f.gene_oid
                and f.ko_terms = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, f.enzymes 
            from gene g, gene_ko_enzymes f
            where g.gene_oid = f.gene_oid
                and f.enzymes = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $id2 =~ s/'/'''/g;    # replace ' by ''
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys, g.taxon, g.gene_display_name
            from gene_biocyc_rxns gb, biocyc_reaction_in_pwys brp, gene g
            where brp.unique_id = gb.biocyc_rxn
                and brp.in_pwys = ?
                and gb.gene_oid = g.gene_oid 
                and g.scaffold in ( $scaf_str ) 
            $rclause
            $imgClause
        };
        @bindList = ($id2);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $db_id = $func_id;
        $sql   = qq{
            select distinct g.gene_oid, f.id, g.taxon, g.gene_display_name
            from gene g, gene_xref_families f
            where f.db_name = 'InterPro'
            and g.gene_oid = f.gene_oid
            and f.id = ?
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $db_id = $func_id;
        $sql   = qq{
            select distinct g.gene_oid, f.tc_family, g.taxon, g.gene_display_name
            from gene g, gene_tc_families f
            where g.gene_oid = f.gene_oid
                and f.tc_family = ?
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($db_id) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, it.term_oid, g.taxon, g.gene_display_name
            #    from img_term it, dt_img_term_path dtp, gene_img_functions f, gene g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = f.function
            #    and f.gene_oid = g.gene_oid
            #    and g.scaffold in ( $scaf_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, f.function, g.taxon, g.gene_display_name
                from gene_img_functions f, gene g
                where f.function = ?
                and f.gene_oid = g.gene_oid
                and g.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($db_id) ) {
            #$sql = qq{
            #    select g.gene_oid, ipr.pathway_oid, g.taxon, g.gene_display_name
            #    from img_pathway_reactions ipr, img_reaction_catalysts irc, 
            #        dt_img_term_path dtp, gene_img_functions gif, gene g
            #    where ipr.pathway_oid = ?
            #    and ipr.rxn = irc.rxn_oid
            #    and irc.catalysts = dtp.term_oid
            #    and dtp.map_term = gif.function
            #    and gif.gene_oid = g.gene_oid
            #    and g.scaffold in ( $scaf_str )
            #    $rclause
            #    $imgClause
            #     union
            #     select g.gene_oid, ipr.pathway_oid, g.taxon, g.gene_display_name
            #     from img_pathway_reactions ipr, img_reaction_t_components irtc, 
            #        dt_img_term_path dtp, gene_img_functions gif, gene g
            #     where ipr.pathway_oid = ?
            #    and ipr.rxn = irtc.rxn_oid
            #    and irtc.term = dtp.term_oid
            #    and dtp.map_term = gif.function
            #    and gif.gene_oid = g.gene_oid
            #    and g.scaffold in ( $scaf_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.gene_oid, ipr.pathway_oid, g.taxon, g.gene_display_name
                from img_pathway_reactions ipr, img_reaction_catalysts irc, 
                    gene_img_functions gif, gene g
                where ipr.pathway_oid = ?
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = gif.function
                and gif.gene_oid = g.gene_oid
                and g.scaffold in ( $scaf_str )
                $rclause
                $imgClause
                 union
                 select g.gene_oid, ipr.pathway_oid, g.taxon, g.gene_display_name
                 from img_pathway_reactions ipr, img_reaction_t_components irtc, 
                    gene_img_functions gif, gene g
                 where ipr.pathway_oid = ?
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = gif.function
                and gif.gene_oid = g.gene_oid
                and g.scaffold in ( $scaf_str )
                $rclause
                $imgClause
			};
            @bindList = ( $db_id, $db_id );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($db_id) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, pt.parts_list_oid, g.taxon,
            #        g.gene_display_name
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions f, gene g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = f.function
            #    and f.gene_oid = g.gene_oid
            #    and g.scaffold in ( $scaf_str )
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, pt.parts_list_oid, g.taxon,
                    g.gene_display_name
                from img_parts_list_img_terms pt, gene_img_functions f, gene g
                where pt.parts_list_oid = ?
                and pt.term = f.function
                and f.gene_oid = g.gene_oid
                and g.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }

    #print "WorkspaceQueryUtil::getDbScaffoldFuncGeneSql \$sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbScaffoldFuncGeneSql \@bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}

############################################################################
# getDbScaffoldFuncsGenesSql - return the func gene sql for each scaffold in db scaffolds
############################################################################
sub getDbScaffoldFuncsGenesSql {
    my ( $dbh, $func_ids_ref, $scaf_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }

    my $sql;
    my @bindList;

    my ($func_id, $func_ids_str) = getFuncIdsStr( $dbh, $func_ids_ref );

    if ( $func_id =~ /^COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.cog 
            from gene g, gene_cog_groups f
            where g.gene_oid = f.gene_oid
                and f.cog in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.kog 
            from gene g, gene_kog_groups f
            where g.gene_oid = f.gene_oid
                and f.kog in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.pfam_family
            from gene g, gene_pfam_families f
            where g.gene_oid = f.gene_oid
                and f.pfam_family in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.ext_accession 
            from gene g, gene_tigrfams f
            where g.gene_oid = f.gene_oid
                and f.ext_accession in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.ko_terms 
            from gene g, gene_ko_terms f
            where g.gene_oid = f.gene_oid
                and f.ko_terms in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.enzymes 
            from gene g, gene_ko_enzymes f
            where g.gene_oid = f.gene_oid
                and f.enzymes in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^MetaCyc/i ) { 
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, brp.in_pwys, g.taxon, g.gene_display_name
            from gene_biocyc_rxns gb, biocyc_reaction_in_pwys brp, gene g
            where brp.unique_id = gb.biocyc_rxn
                and brp.in_pwys in ( $func_ids_str )
                and gb.gene_oid = g.gene_oid 
                and g.scaffold in ( $scaf_str ) 
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPR/i ) { 
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.id, g.taxon, g.gene_display_name
            from gene g, gene_xref_families f
            where f.db_name = 'InterPro'
            and g.gene_oid = f.gene_oid
            and f.id in ( $func_ids_str )
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^TC/i ) { 
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.tc_family, g.taxon, g.gene_display_name
            from gene g, gene_tc_families f
            where g.gene_oid = f.gene_oid
                and f.tc_family in ( $func_ids_str )
                and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^ITERM/i ) { 
        #$sql = qq{
        #    select distinct g.gene_oid, g.scaffold, it.term_oid, g.taxon, g.gene_display_name
        #    from img_term it, dt_img_term_path dtp, gene_img_functions f, gene g
        #    where it.term_oid in ( $func_ids_str )
        #    and it.term_oid = dtp.term_oid
        #    and dtp.map_term = f.function
        #    and f.gene_oid = g.gene_oid
        #    and g.scaffold in ( $scaf_str )
        #    $rclause
        #    $imgClause
        #};
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, f.function, g.taxon, g.gene_display_name
            from gene_img_functions f, gene g
            where f.function in ( $func_ids_str )
            and f.gene_oid = g.gene_oid
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPWAY/i ) { 
        #$sql = qq{
        #    select g.gene_oid, g.scaffold, ipr.pathway_oid, g.taxon, g.gene_display_name
        #    from img_pathway_reactions ipr, img_reaction_catalysts irc, 
        #        dt_img_term_path dtp, gene_img_functions gif, gene g
        #    where ipr.pathway_oid in ( $func_ids_str )
        #    and ipr.rxn = irc.rxn_oid
        #    and irc.catalysts = dtp.term_oid
        #    and dtp.map_term = gif.function
        #    and gif.gene_oid = g.gene_oid
        #    and g.scaffold in ( $scaf_str )
        #    $rclause
        #    $imgClause
        #     union
        #     select g.gene_oid, g.scaffold, ipr.pathway_oid, g.taxon, g.gene_display_name
        #     from img_pathway_reactions ipr, img_reaction_t_components irtc, 
        #        dt_img_term_path dtp, gene_img_functions gif, gene g
        #     where ipr.pathway_oid in ( $func_ids_str )
        #    and ipr.rxn = irtc.rxn_oid
        #    and irtc.term = dtp.term_oid
        #    and dtp.map_term = gif.function
        #    and gif.gene_oid = g.gene_oid
        #    and g.scaffold in ( $scaf_str )
        #    $rclause
        #    $imgClause
        #};
        $sql = qq{
            select g.gene_oid, g.scaffold, ipr.pathway_oid, g.taxon, g.gene_display_name
            from img_pathway_reactions ipr, img_reaction_catalysts irc, 
                gene_img_functions gif, gene g
            where ipr.pathway_oid in ( $func_ids_str )
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = gif.function
            and gif.gene_oid = g.gene_oid
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
             union
             select g.gene_oid, g.scaffold, ipr.pathway_oid, g.taxon, g.gene_display_name
             from img_pathway_reactions ipr, img_reaction_t_components irtc, 
                gene_img_functions gif, gene g
             where ipr.pathway_oid in ( $func_ids_str )
            and ipr.rxn = irtc.rxn_oid
            and irtc.term = gif.function
            and gif.gene_oid = g.gene_oid
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        #$sql = qq{
        #    select distinct g.gene_oid, g.scaffold, pt.parts_list_oid, g.taxon,
        #        g.gene_display_name
        #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions f, gene g
        #    where pt.parts_list_oid in ( $func_ids_str )
        #    and pt.term = dtp.term_oid
        #    and dtp.map_term = f.function
        #    and f.gene_oid = g.gene_oid
        #    and g.scaffold in ( $scaf_str )
        #    $rclause
        #    $imgClause
        #};
        $sql = qq{
            select distinct g.gene_oid, g.scaffold, pt.parts_list_oid, g.taxon,
                g.gene_display_name
            from img_parts_list_img_terms pt, gene_img_functions f, gene g
            where pt.parts_list_oid in ( $func_ids_str )
            and pt.term = f.function
            and f.gene_oid = g.gene_oid
            and g.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }

    #print "WorkspaceQueryUtil::getDbScaffoldFuncsGenesSql \$sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbScaffoldFuncsGenesSql \@bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}

############################################################################
# getDbScaffoldFuncCategoryGeneSql - return the func gene sql for db scaffolds
# need to be merged with getDbScaffoldFuncGeneSql
############################################################################
sub getDbScaffoldFuncCategoryGeneSql {
    my ( $functype, $scaf_str, $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('f.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('f.taxon');        
    }

    my $sql;
    if ( $functype eq 'COG_Category' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, cf.functions
            from gene_cog_groups f, cog_functions cf
            where f.cog = cf.cog_id
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'COG_Pathway' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, cpcm.cog_pathway_oid
            from gene_cog_groups f, cog_pathway_cog_members cpcm
            where f.cog = cpcm.cog_members
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'COG' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, f.cog 
            from gene_cog_groups f
            where f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'KEGG_Category_EC' ) {
        $sql = qq{ 
            select distinct f.gene_oid, f.scaffold, kp3.min_pid
            from gene_ko_enzymes f, ko_term_enzymes kt, image_roi_ko_terms rk, 
            image_roi ir, kegg_pathway kp,
                (select kp2.category category, min(kp2.pathway_oid) min_pid
                 from kegg_pathway kp2
                 where kp2.category is not null
                 group by kp2.category) kp3
            where f.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            and kp.category is not null 
            and kp.category = kp3.category
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'KEGG_Category_KO' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, kp3.min_pid
            from gene_ko_terms f, image_roi_ko_terms rk,
            image_roi ir, kegg_pathway kp,
             (select kp2.category category, min(kp2.pathway_oid) min_pid
              from kegg_pathway kp2
              where kp2.category is not null
              group by kp2.category) kp3
            where f.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            and kp.category is not null 
            and kp.category = kp3.category
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'KEGG_Pathway_EC' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, ir.pathway
            from gene_ko_enzymes f, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
            where f.scaffold in ( $scaf_str )
            and f.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id                        
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'KEGG_Pathway_KO' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, ir.pathway
            from gene_ko_terms f, image_roi_ko_terms rk, image_roi ir
            where f.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'Pfam_Category' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, pfc.functions
            from gene_pfam_families f, pfam_family_cogs pfc
            where f.pfam_family = pfc.ext_accession
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'Pfam' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, f.pfam_family
            from gene_pfam_families f
            where f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'TIGRfam_Role' ) {
        $sql = qq{ 
            select distinct f.gene_oid, f.scaffold, tr.roles
            from gene_tigrfams f, tigrfam_roles tr, tigr_role t
            where f.ext_accession = tr.ext_accession
            and tr.roles = t.role_id
            and t.sub_role != 'Other'
            and f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'TIGRfam' ) {
        $sql = qq{ 
            select distinct f.gene_oid, f.scaffold, f.ext_accession
            from gene_tigrfams f
            where f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'KO' ) {
        $sql = qq{ 
            select distinct f.gene_oid, f.scaffold, f.ko_terms
            from gene_ko_terms f
            where f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    } elsif ( $functype eq 'Enzymes' ) {
        $sql = qq{
            select distinct f.gene_oid, f.scaffold, f.enzymes 
            from gene_ko_enzymes f
            where f.scaffold in ( $scaf_str )
            $rclause
            $imgClause
        };
    }

    return $sql;
}

############################################################################
# getDbFuncsGenesSql - return the func gene sql for db func
############################################################################
sub getDbFuncsGenesSql {
    my ($dbh, $func_ids_ref, $gene_str, $rclause, $imgClause) = @_;

    my $sql;
    my @bindList;

    my ($func_id, $func_ids_str) = getFuncIdsStr( $dbh, $func_ids_ref );

    if ( $func_id =~ /COG\_Category/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_functions cf 
            where g.cog = cf.cog_id 
            and cf.functions in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /COG\_Pathway/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_pathway_cog_members cpcm 
            where g.cog = cpcm.cog_members 
            and cpcm.cog_pathway_oid in ( $func_ids_str )           
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog 
            from gene_cog_groups g 
            where g.cog in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /Pfam\_Category/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g, pfam_family_cogs pfc 
            where g.pfam_family = pfc.ext_accession 
            and pfc.functions in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g 
            where g.pfam_family in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g, tigrfam_roles tr 
            where g.ext_accession = tr.ext_accession 
            and tr.roles in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g 
            where g.ext_accession in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, kp.category 
            from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp 
            where g.ko_terms = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            and ir.pathway = kp.pathway_oid 
            and kp.category = (
                select kp3.category 
                from kegg_pathway kp3 
                where kp3.pathway_oid in ( $func_ids_str )
            )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
        $sql = qq{
            select g.gene_oid, ir.pathway 
            from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir 
            where g.ko_terms = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            and ir.pathway in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.kog 
            from gene_kog_groups g 
            where g.kog in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms 
            from gene_ko_terms g 
            where g.ko_terms in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, kp.category 
            from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, 
                image_roi ir, kegg_pathway kp 
            where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid 
            and kp.category = (
                select kp3.category 
                from kegg_pathway kp3 
                where kp3.pathway_oid in ( $func_ids_str )
            ) 
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, ir.pathway 
            from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir 
            where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.enzymes 
            from gene_ko_enzymes g 
            where g.enzymes in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.id
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.tc_family 
            from gene_tc_families g 
            where g.tc_family in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        #$sql = qq{
        #    select distinct g.gene_oid, it.term_oid 
        #    from img_term it, dt_img_term_path dtp, gene_img_functions g
        #    where it.term_oid in ( $func_ids_str )
        #    and it.term_oid = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.gene_oid in ( $gene_str )
        #    $rclause
        #    $imgClause
        #};
        $sql = qq{
            select distinct g.gene_oid, g.function 
            from gene_img_functions g
            where g.function in ( $func_ids_str )
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        #$sql = qq{
        #    select g.gene_oid, ipr.pathway_oid
        #    from img_pathway_reactions ipr,
        #        img_reaction_catalysts irc,
        #        dt_img_term_path dtp, gene_img_functions g
        #    where ipr.pathway_oid in ( $func_ids_str )
        #    and ipr.rxn = irc.rxn_oid
        #    and irc.catalysts = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.gene_oid in ( $gene_str )
        #    $rclause
        #    $imgClause
        #    union
        #    select g.gene_oid, ipr.pathway_oid
        #    from img_pathway_reactions ipr,
        #        img_reaction_t_components irtc,
        #        dt_img_term_path dtp, gene_img_functions g
        #    where ipr.pathway_oid in ( $func_ids_str )
        #    and ipr.rxn = irtc.rxn_oid
        #    and irtc.term = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.gene_oid in ( $gene_str )
        #    $rclause
        #    $imgClause
        # };
        $sql = qq{
            select g.gene_oid, ipr.pathway_oid
            from img_pathway_reactions ipr,
                img_reaction_catalysts irc,
                gene_img_functions g
            where ipr.pathway_oid in ( $func_ids_str )
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = g.function
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
            union
            select g.gene_oid, ipr.pathway_oid
            from img_pathway_reactions ipr,
                img_reaction_t_components irtc,
                gene_img_functions g
            where ipr.pathway_oid in ( $func_ids_str )
            and ipr.rxn = irtc.rxn_oid
            and irtc.term = g.function
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
         };
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        #$sql = qq{
        #    select distinct g.gene_oid, pt.parts_list_oid 
        #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #    where pt.parts_list_oid in ( $func_ids_str )
        #    and pt.term = dtp.term_oid
        #    and dtp.map_term = g.function
        #    and g.gene_oid in ( $gene_str )
        #    $rclause
        #    $imgClause
        #};
        $sql = qq{
            select distinct g.gene_oid, pt.parts_list_oid 
            from img_parts_list_img_terms pt, gene_img_functions g
            where pt.parts_list_oid in ( $func_ids_str )
            and pt.term = g.function
            and g.gene_oid in ( $gene_str )
            $rclause
            $imgClause
        };
    }

    #print "WorkspaceQueryUtil::getDbFuncsGenesSql() sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbFuncsGenesSql() bindList: @bindList<br/>\n";
    
    return ( $sql, @bindList );
}


############################################################################
# getDbFuncGeneSql - return the func gene sql for db func
############################################################################
sub getDbFuncGeneSql {
    my ($func_id, $min_gene_oid, $max_gene_oid, $rclause, $imgClause) = @_;

    my $sql      = "";
    my @bindList = ();

    my $db_id = $func_id;
    if ( $func_id =~ /COG\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_functions cf 
            where g.cog = cf.cog_id 
            and cf.functions = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG\_Pathway/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_pathway_cog_members cpcm 
            where g.cog = cpcm.cog_members 
            and cpcm.cog_pathway_oid = ?            
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog 
            from gene_cog_groups g 
            where g.cog = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /Pfam\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g, pfam_family_cogs pfc 
            where g.pfam_family = pfc.ext_accession 
            and pfc.functions = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g 
            where g.pfam_family = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g, tigrfam_roles tr 
            where g.ext_accession = tr.ext_accession 
            and tr.roles = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g 
            where g.ext_accession = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, kp.category 
            from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp 
            where g.ko_terms = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            and ir.pathway = kp.pathway_oid 
            and kp.category = (
                select kp3.category 
                from kegg_pathway kp3 
                where kp3.pathway_oid = ?
            )
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select g.gene_oid, ir.pathway 
            from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir 
            where g.ko_terms = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            and ir.pathway = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.kog 
            from gene_kog_groups g 
            where g.kog = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms 
            from gene_ko_terms g 
            where g.ko_terms = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, kp.category 
            from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, 
                image_roi ir, kegg_pathway kp 
            where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid 
            and kp.category = (
                select kp3.category 
                from kegg_pathway kp3 
                where kp3.pathway_oid = ?
            ) 
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, ir.pathway 
            from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir 
            where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.enzymes 
            from gene_ko_enzymes g 
            where g.enzymes = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.id
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.tc_family 
            from gene_tc_families g 
            where g.tc_family = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, it.term_oid 
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, g.function 
                from gene_img_functions g
                where g.function = ?
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ?
            #    and ipr.rxn = irc.rxn_oid
            #    and irc.catalysts = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #    union
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ?
            #    and ipr.rxn = irtc.rxn_oid
            #    and irtc.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            # };
            $sql = qq{
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid = ?
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
                union
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid = ?
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
             };
             @bindList = ( $db_id, $db_id );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, pt.parts_list_oid 
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, pt.parts_list_oid 
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }

    #print "WorkspaceQueryUtil::getDbFuncGeneSql() sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbFuncGeneSql() bindList: @bindList<br/>\n";
    
    return ( $sql, @bindList );
}

############################################################################
# getDbFuncGeneSql2 - return the func gene sql for db func
# should be merged with getDbFuncGeneSql
############################################################################
sub getDbFuncGeneSql2 {
    my ($func_id, $selected_func_name, $min_gene_oid, $max_gene_oid, $rclause, $imgClause) = @_;

    my $sql      = "";
    my @bindList = ();

    my $db_id = $func_id;
    if ( $func_id =~ /COG\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_functions cf 
            where g.cog = cf.cog_id 
            and cf.functions = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG\_Pathway/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.cog
            from gene_cog_groups g, cog_pathway_cog_members cpcm 
            where g.cog = cpcm.cog_members 
            and cpcm.cog_pathway_oid = ?            
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /COG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog 
            from gene_cog_groups g 
            where g.cog = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /Pfam\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g, pfam_family_cogs pfc 
            where g.pfam_family = pfc.ext_accession 
            and pfc.functions = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g 
            where g.pfam_family = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
        #$sql = qq{
        #    select distinct g.gene_oid, g.ext_accession 
        #    from gene_tigrfams g, tigrfam_roles tr 
        #    where g.ext_accession = tr.ext_accession 
        #    and tr.roles = ?
        #	and g.gene_oid between $min_gene_oid and $max_gene_oid
        #    $rclause
        #    $imgClause
        #};
	    $sql = qq{
	        select distinct g.gene_oid, g.ext_accession 
	        from gene_tigrfams g, tigr_role t, tigrfam_roles tr 
	        where g.ext_accession = tr.ext_accession 
	        and tr.roles = t.role_id 
	        and t.sub_role != 'Other' 
	        and t.role_id = ?
	        and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g 
            where g.ext_accession = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
        #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
        #my ( $id1, $id2 ) = split( /\:/, $func_id );
        #$db_id = $id2;
        #$sql = qq{
        #    select distinct g.gene_oid, kp.category 
        #    from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp 
        #    where g.ko_terms = rk.ko_terms 
        #    and rk.roi_id = ir.roi_id 
        #    and ir.pathway = kp.pathway_oid 
        #    and kp.category = (
        #        select kp3.category 
        #        from kegg_pathway kp3 
        #        where kp3.pathway_oid = ?
        #    )
        #	and g.gene_oid between $min_gene_oid and $max_gene_oid
        #    $rclause
        #    $imgClause
        #};
        
        $db_id = $selected_func_name;
	    $sql = qq{
	        select distinct g.gene_oid, rk.ko_terms 
	        from gene_ko_terms g, image_roi ir, image_roi_ko_terms rk, kegg_pathway kp 
	        where g.ko_terms = rk.ko_terms 
	        and rk.roi_id = ir.roi_id 
	        and ir.pathway = kp.pathway_oid 
	        and kp.category = ?
	        and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
        #$sql = qq{
        #    select g.gene_oid, ir.pathway 
        #    from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir 
        #    where g.ko_terms = rk.ko_terms 
        #    and rk.roi_id = ir.roi_id 
        #    and ir.pathway = ?
        #	and g.gene_oid between $min_gene_oid and $max_gene_oid
        #    $rclause
        #    $imgClause
        #};
	    $sql = qq{
	        select distinct g.gene_oid, rk.ko_terms 
	        from gene_ko_terms g, image_roi ir, image_roi_ko_terms rk 
	        where g.ko_terms = rk.ko_terms 
	        and rk.roi_id = ir.roi_id 
	        and ir.pathway = ?
	        and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.kog 
            from gene_kog_groups g 
            where g.kog = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms 
            from gene_ko_terms g 
            where g.ko_terms = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
        #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
        #my ( $id1, $id2 ) = split( /\:/, $func_id );
        #$db_id = $id2;
        #$sql = qq{
        #    select distinct g.gene_oid, kp.category 
        #    from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, 
        #        image_roi ir, kegg_pathway kp 
        #    where g.enzymes = kt.enzymes
        #    and kt.ko_id = rk.ko_terms
        #    and rk.roi_id = ir.roi_id 
        #    and ir.pathway = kp.pathway_oid 
        #    and kp.category = (
        #        select kp3.category 
        #        from kegg_pathway kp3 
        #        where kp3.pathway_oid = ?
        #    ) 
        #	and g.gene_oid between $min_gene_oid and $max_gene_oid
        #    $rclause
        #    $imgClause
        #};
		$db_id = $selected_func_name;
	    $sql = qq{
	        select distinct g.gene_oid, g.enzymes 
	        from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, 
	            image_roi ir, kegg_pathway kp 
	        where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
	        and ir.pathway = kp.pathway_oid 
	        and kp.category = ?
	        and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
        #$sql = qq{
        #    select g.gene_oid, ir.pathway 
        #    from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir 
        #    where g.enzymes = kt.enzymes
        #    and kt.ko_id = rk.ko_terms
        #    and rk.roi_id = ir.roi_id
        #    and ir.pathway = ?
        #	 and g.gene_oid between $min_gene_oid and $max_gene_oid
        #    $rclause
        #    $imgClause
        #};
	    $sql = qq{
	        select distinct g.gene_oid, g.enzymes 
	        from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
	        where g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
	        and ir.pathway = ?
	        and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.enzymes 
            from gene_ko_enzymes g 
            where g.enzymes = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g
            where brp.unique_id = g.biocyc_rxn
            and brp.in_pwys = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.id
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.id = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select distinct g.gene_oid, g.tc_family 
            from gene_tc_families g 
            where g.tc_family = ?
    		and g.gene_oid between $min_gene_oid and $max_gene_oid
            $rclause
            $imgClause
        };
        @bindList = ($db_id);
    }
    elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, it.term_oid 
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g
            #    where it.term_oid = ?
            #    and it.term_oid = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
		        select distinct g.gene_oid, g.function 
		        from gene_img_functions g
		        where g.function = ?
		        and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }
    elsif ( $func_id =~ /^IPWAY/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #ToDo: below blocked from getDbFuncGeneSql, need to resolve the difference
            #$sql = qq{
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_catalysts irc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ?
            #    and ipr.rxn = irc.rxn_oid
            #    and irc.catalysts = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #    union
            #    select g.gene_oid, ipr.pathway_oid
            #    from img_pathway_reactions ipr,
            #        img_reaction_t_components irtc,
            #        dt_img_term_path dtp, gene_img_functions g
            #    where ipr.pathway_oid = ?
            #    and ipr.rxn = irtc.rxn_oid
            #    and irtc.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid = ?
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
                union
                select g.gene_oid, ipr.pathway_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where ipr.pathway_oid = ?
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
            };
            @bindList = ( $db_id, $db_id );
        }
    }
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select distinct g.gene_oid, pt.parts_list_oid 
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    and g.gene_oid between $min_gene_oid and $max_gene_oid
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select distinct g.gene_oid, pt.parts_list_oid 
                from img_parts_list_img_terms pt, gene_img_functions g
                where pt.parts_list_oid = ?
                and pt.term = g.function
                and g.gene_oid between $min_gene_oid and $max_gene_oid
                $rclause
                $imgClause
            };
            @bindList = ($db_id);
        }
    }

    #print "WorkspaceQueryUtil::getDbFuncGeneSql2 \$sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbFuncGeneSql2 \@bindList: @bindList<br/>\n";
    
    return ( $sql, @bindList );
}

############################################################################
# getFuncIdSql - return the func id for some func sql
############################################################################
sub getFuncIdForSomeFuncSql {
    my ($func_id, $selected_func_name) = @_;

    my $sql = "";

	my ($id1, $id2) = split(/\:/, $func_id);
	if ( $func_id =~ /COG\_Category/i ) {
	    $sql = qq{
	        select distinct cf.cog_id 
	        from cog_functions cf 
	        where cf.functions = ?
	    };
	}
	elsif ( $func_id =~ /COG\_Pathway/i ) {
	    $sql = qq{
            select distinct cpcm.cog_members 
            from cog_pathway_cog_members cpcm 
            where cpcm.cog_pathway_oid = ?	
	    };
	}
	elsif ( $func_id =~ /Pfam\_Category/i ) {
	    $sql = qq{
            select distinct pfc.ext_accession 
            from pfam_family_cogs pfc 
            where pfc.functions = ?
	    };
	}
	elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
	    $id2 = $selected_func_name;
	    $sql = qq{
	        select distinct kt.enzymes
	        from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp 
	        where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
	        and ir.pathway = kp.pathway_oid 
	        and kp.category = ?
	    };
	}
	elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
	    $sql = qq{
	        select distinct kt.enzymes 
	        from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
	        where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
	        and ir.pathway = ?
	    };
	}
	elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
	    $id2 = $selected_func_name;
	    $sql = qq{
	        select distinct rk.ko_terms 
	        from image_roi ir, image_roi_ko_terms rk, kegg_pathway kp 
	        where ir.roi_id = rk.roi_id 
	        and ir.pathway = kp.pathway_oid 
	        and kp.category = ?
	    };
	}
	elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
	    $sql = qq{
	        select distinct rk.ko_terms 
	        from image_roi ir, image_roi_ko_terms rk 
	        where ir.roi_id = rk.roi_id 
	        and ir.pathway = ?
	    };
	}
	elsif ( $func_id =~ /TIGRfam\_Role/i ) {
	    $sql = qq{
	        select distinct tr.ext_accession 
	        from tigr_role t, tigrfam_roles tr 
	        where t.role_id = tr.roles 
	        and t.sub_role != 'Other' 
	        and t.role_id = ?
	    };
	}
	elsif ( $func_id =~ /MetaCyc/i ) {
	    $sql = qq{
            select distinct br.ec_number
            from biocyc_reaction_in_pwys brp, biocyc_reaction br
            where brp.unique_id = br.unique_id
            and brp.in_pwys = ?
            and br.ec_number is not null
	    };
    }
    
    return ( $sql, $id2 );
}

############################################################################
# getDbGeneFuncSql - return the func gene sql for db gene
############################################################################
sub getDbGeneFuncSql {
    my ($functype, $gene_oids_str, $rclause, $imgClause) = @_;

    my $sql = "";
    if ( $functype eq 'COG' ) {
        $sql = qq{
            select distinct g.gene_oid, g.cog 
            from gene_cog_groups g
            where g.gene_oid in ($gene_oids_str)
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'COG_Category' ) {
        $sql = qq{
            select distinct g.gene_oid, cf.functions 
            from gene_cog_groups g, cog_functions cf 
            where g.gene_oid in ($gene_oids_str)
            and g.cog = cf.cog_id
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'COG_Pathway' ) {
        $sql = qq{
            select distinct g.gene_oid, cpcm.cog_pathway_oid 
            from gene_cog_groups g, cog_pathway_cog_members cpcm 
            where g.gene_oid in ($gene_oids_str)
            and g.cog = cpcm.cog_members 
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'Pfam_Category' ) {
        $sql = qq{
            select distinct g.gene_oid, pfc.functions 
            from gene_pfam_families g, pfam_family_cogs pfc 
            where g.gene_oid in ($gene_oids_str)
            and g.pfam_family = pfc.ext_accession 
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'Pfam' ) {
        $sql = qq{
            select distinct g.gene_oid, g.pfam_family 
            from gene_pfam_families g
            where g.gene_oid in ($gene_oids_str)
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'TIGRfam_Role' ) {
        $sql = qq{
            select distinct g.gene_oid, t.role_id 
            from gene_tigrfams g, tigr_role t, tigrfam_roles tr 
            where g.gene_oid in ($gene_oids_str)
            and g.ext_accession = tr.ext_accession 
            and tr.roles = t.role_id 
            and t.sub_role is not null 
            and t.sub_role != 'Other' 
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'TIGRfam' ) {
        $sql = qq{
            select distinct g.gene_oid, g.ext_accession 
            from gene_tigrfams g
            where g.gene_oid in ($gene_oids_str)
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'KEGG_Category_KO' ) {
        $sql = qq{
            select distinct g.gene_oid, kp3.min_pid
			from gene_ko_terms g, image_roi_ko_terms rk,
			image_roi ir, kegg_pathway kp,
               (select kp2.category category, min(kp2.pathway_oid) min_pid
                from kegg_pathway kp2
                where kp2.category is not null
                group by kp2.category) kp3
			where g.gene_oid in ($gene_oids_str)
			and g.ko_terms = rk.ko_terms
			and rk.roi_id = ir.roi_id
  			and ir.pathway = kp.pathway_oid
            and kp.category is not null
            and kp.category = kp3.category
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'KEGG_Pathway_KO' ) {
        $sql = qq{
            select distinct g.gene_oid, ir.pathway 
            from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir 
            where g.gene_oid in ($gene_oids_str)
            and g.ko_terms = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            $rclause
            $imgClause
        };
	}
    elsif ( $functype eq 'KO' ) {
        $sql = qq{
            select distinct g.gene_oid, g.ko_terms 
            from gene_ko_terms g
            where g.gene_oid in ($gene_oids_str)
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'KEGG_Category_EC' ) {
        $sql = qq{
            select distinct g.gene_oid, kp3.min_pid
    	    from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, 
    	        image_roi ir, kegg_pathway kp,
                (select kp2.category category, min(kp2.pathway_oid) min_pid
                 from kegg_pathway kp2
                 where kp2.category is not null
                 group by kp2.category) kp3
    	    where g.gene_oid in ($gene_oids_str)
    	    and g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
    	    and ir.pathway = kp.pathway_oid
            and kp.category is not null
            and kp.category = kp3.category
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'KEGG_Pathway_EC' ) {
        $sql = qq{
            select distinct g.gene_oid, ir.pathway 
            from gene_ko_enzymes g, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir 
            where g.gene_oid in ($gene_oids_str)
            and g.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id 
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'Enzymes' ) {
        $sql = qq{
            select distinct g.gene_oid, g.enzymes 
            from gene_ko_enzymes g
            where g.gene_oid in ($gene_oids_str)
            $rclause
            $imgClause
        };
    }
    elsif ( $functype eq 'MetaCyc' ) {
        $sql = qq{
            select distinct g.gene_oid, brp.in_pwys
            from gene_ko_enzymes g, biocyc_reaction_in_pwys brp, biocyc_reaction br
            where g.gene_oid in ($gene_oids_str)
            and g.enzymes = br.ec_number
            and br.unique_id = brp.unique_id
            $rclause
            $imgClause
        };
    }

    #print "getDbGeneFuncsql \$sql: $sql<br/>\n";

    return ( $sql );
}

############################################################################
# getDbGeneFuncSql - return the func gene sql for single db gene
############################################################################
sub getDbSingleGeneFuncSql {
    my ($func_id, $gene_oid, $rclause, $imgClause) = @_;

    my $sql = "";
    my @bindList = ();
    
    if ( $func_id =~ /^COG/i ) {
        $sql = qq{
            select g.cog 
            from gene_cog_groups g
            where g.gene_oid = ? 
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }
    elsif ( $func_id =~ /^pfam/i ) {
        $sql = qq{
            select g.pfam_family 
            from gene_pfam_families g
            where g.gene_oid = ? 
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }
    elsif ( $func_id =~ /^TIGR/i ) {
        $sql = qq{
            select g.ext_accession 
            from gene_tigrfams g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }
	elsif ( $func_id =~ /^KOG/i ) {
        $sql = qq{
            select g.kog 
            from gene_kog_groups g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
	}
    elsif ( $func_id =~ /^KO/i ) {
        $sql = qq{
            select g.ko_terms 
            from gene_ko_terms g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }
    elsif ( $func_id =~ /^EC/i ) {
        $sql = qq{
            select g.enzymes 
            from gene_ko_enzymes g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }
	elsif ( $func_id =~ /^MetaCyc/i ) {
        $sql = qq{
            select brp.in_pwys 
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g 
            where g.gene_oid = ? 
            and brp.unique_id = g.biocyc_rxn
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
	}
	elsif ( $func_id =~ /^IPR/i ) {
        $sql = qq{
            select g.id 
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.gene_oid = ? 
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
	}
	elsif ( $func_id =~ /^TC/i ) {
        $sql = qq{
            select g.tc_family 
            from gene_tc_families g
            where g.gene_oid = ? 
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
	}
	elsif ( $func_id =~ /^ITERM/i ) {
#        $sql = qq{
#	        select it.term_oid 
#	        from img_term it, dt_img_term_path dtp, gene_img_functions g
#	        where g.gene_oid = ?
#            and g.function = dtp.map_term
#            and dtp.term_oid = it.term_oid
#            $rclause
#            $imgClause
#        };
        $sql = qq{
            select g.function 
            from gene_img_functions g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
	}
	elsif ( $func_id =~ /^IPWAY/i ) {
#        $sql = qq{
#            select ipr.pathway_oid
#            from img_pathway_reactions ipr,
#                img_reaction_catalysts irc,
#                dt_img_term_path dtp, gene_img_functions g
#            where g.gene_oid = ?
#            and g.function = dtp.map_term
#            and dtp.term_oid = irc.catalysts
#            and irc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#            union
#            select ipr.pathway_oid
#            from img_pathway_reactions ipr,
#                img_reaction_t_components irtc,
#                dt_img_term_path dtp, gene_img_functions g
#            where g.gene_oid = ?
#            and g.function = dtp.map_term
#            and dtp.term_oid = irtc.term
#            and irtc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#        };
        $sql = qq{
            select ipr.pathway_oid
            from img_pathway_reactions ipr,
                img_reaction_catalysts irc,
                gene_img_functions g
            where g.gene_oid = ?
            and g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
            union
            select ipr.pathway_oid
            from img_pathway_reactions ipr,
                img_reaction_t_components irtc,
                gene_img_functions g
            where g.gene_oid = ?
            and g.function = irtc.term
            and irtc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $gene_oid);
	}
    elsif ( $func_id =~ /^PLIST/i ) {
#        $sql = qq{
#            select pt.parts_list_oid 
#            from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
#            where g.gene_oid = ?
#            and g.function = dtp.map_term
#            and dtp.term_oid = pt.term
#            $rclause
#            $imgClause
#        };
        $sql = qq{
            select pt.parts_list_oid 
            from img_parts_list_img_terms pt, gene_img_functions g
            where g.gene_oid = ?
            and g.function = pt.term
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid);
    }

    #print "getDbSingleGeneFuncsql() sql: $sql<br/>\n";

    return ( $sql, @bindList );
}

############################################################################
# getDbGeneFuncCountSql - return the count sql for specified gene and func
############################################################################
sub getDbGeneFuncCountSql {
    my ($func_id, $gene_oid, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    
    my $sql = "";
    my @bindList = ();
    
    my $db_id = $func_id;
    if ( $func_id =~ /^COG/i ) {
		$sql = qq{
		    select count(*) 
		    from gene_cog_groups g
		    where g.gene_oid = ? 
		    and g.cog = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^KOG/i ) {
        $sql = qq{
            select count(*) 
            from gene_kog_groups g
            where g.gene_oid = ? 
            and g.kog = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^pfam/i ) {
		$sql = qq{
		    select count(*) 
		    from gene_pfam_families g
		    where g.gene_oid = ? 
		    and g.pfam_family = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^TIGR/i ) {
		$sql = qq{
		    select count(*) 
		    from gene_tigrfams g 
		    where g.gene_oid = ? 
		    and g.ext_accession = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^KO/i ) {
		$sql = qq{
		    select count(*) 
		    from gene_ko_terms g
		    where g.gene_oid = ? 
		    and g.ko_terms = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^EC/i ) {
		$sql = qq{
		    select count(*) 
		    from gene_ko_enzymes g
		    where g.gene_oid = ? 
		    and g.enzymes = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^MetaCyc/i ) { 
		my ($id1, $id2) = split(/\:/, $func_id);
		$db_id = $id2;
		$sql = qq{
            select count(*)
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g
            where brp.unique_id = g.biocyc_rxn
            and g.gene_oid = ? 
            and brp.in_pwys = ?
            $rclause
            $imgClause
        };
        @bindList = ($gene_oid, $db_id);
    }
    elsif ( $func_id =~ /^IPR/i ) { 
		$sql = qq{
            select count(*)
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.gene_oid = ?
            and g.id = ?
            $rclause
            $imgClause
	    }; 
        @bindList = ($gene_oid, $db_id);
    } 
    elsif ( $func_id =~ /^TC/i ) { 
		$sql = qq{
            select count(*)
            from gene_tc_families g
            where g.gene_oid = ?
            and g.tc_family = ?
            $rclause
            $imgClause
	    }; 
        @bindList = ($gene_oid, $db_id);
    } 
    elsif ( $func_id =~ /^ITERM/i ) { 
		my ($id1, $id2) = split(/\:/, $func_id); 
		$db_id = $id2; 
		if ( isInt($id2) ) { 
            #$sql = qq{
            #    select count(*)
            #    from img_term it, dt_img_term_path dtp, gene_img_functions g 
            #    where g.gene_oid = ?
            #    and g.function = dtp.map_term
            #    and dtp.term_oid = it.term_oid
            #    and it.term_oid = ?
            #    $rclause
            #    $imgClause
            #}; 
            $sql = qq{
                select count(*)
                from gene_img_functions g 
                where g.gene_oid = ?
                and g.function = ?
                $rclause
                $imgClause
            }; 
            @bindList = ($gene_oid, $db_id);
		} 
    } 
    elsif ( $func_id =~ /^IPWAY/i ) { 
		my ($id1, $id2) = split(/\:/, $func_id); 
		$db_id = $id2; 
		if ( isInt($id2) ) { 
            #$sql = qq{
            #    select count(*) from (
            #        select g.gene_oid
            #        from img_pathway_reactions ipr,
            #            img_reaction_catalysts irc,
            #            dt_img_term_path dtp, gene_img_functions g
            #        where g.gene_oid = ?
            #        and ipr.pathway_oid = ?
            #        and ipr.rxn = irc.rxn_oid
            #        and irc.catalysts = dtp.term_oid
            #        and dtp.map_term = g.function
            #        $rclause
            #        $imgClause
            #        union
            #        select g.gene_oid
            #        from img_pathway_reactions ipr,
            #            img_reaction_t_components irtc,
            #            dt_img_term_path dtp, gene_img_functions g
            #        where g.gene_oid = ?
            #        and ipr.pathway_oid = ?
            #        and ipr.rxn = irtc.rxn_oid
            #        and irtc.term = dtp.term_oid
            #        and dtp.map_term = g.function
            #        $rclause
            #        $imgClause
            #    )
            #};
            $sql = qq{
                select count(*) from (
                    select g.gene_oid
                    from img_pathway_reactions ipr,
                        img_reaction_catalysts irc,
                        gene_img_functions g
                    where g.gene_oid = ?
                    and ipr.pathway_oid = ?
                    and ipr.rxn = irc.rxn_oid
                    and irc.catalysts = g.function
                    $rclause
                    $imgClause
                    union
                    select g.gene_oid
                    from img_pathway_reactions ipr,
                        img_reaction_t_components irtc,
                        gene_img_functions g
                    where g.gene_oid = ?
                    and ipr.pathway_oid = ?
                    and ipr.rxn = irtc.rxn_oid
                    and irtc.term = g.function
                    $rclause
                    $imgClause
                )
            };
            @bindList = ($gene_oid, $db_id, $gene_oid, $db_id);
		} 
    } 
    elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        if ( isInt($id2) ) {
            #$sql = qq{
            #    select count(*)
            #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
            #    where g.gene_oid = ?
            #    and pt.parts_list_oid = ?
            #    and pt.term = dtp.term_oid
            #    and dtp.map_term = g.function
            #    $rclause
            #    $imgClause
            #};
            $sql = qq{
                select count(*)
                from img_parts_list_img_terms pt, gene_img_functions g
                where g.gene_oid = ?
                and pt.parts_list_oid = ?
                and pt.term = g.function
                $rclause
                $imgClause
            };
            @bindList = ($gene_oid, $db_id);
        }
    }
    
    #print "WorkspaceQueryUtil::getDbGeneFuncCountSql \$sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbGeneFuncCountSql \@bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}


############################################################################
# getDbGeneFuncsCountSql - return the count sql for specified gene and func
############################################################################
sub getDbGeneFuncsCountSql {
    my ($dbh, $func_ids_ref, $gene_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    
    my $sql;
    my @bindList;

    my ($func_id, $func_ids_str) = getFuncIdsStr( $dbh, $func_ids_ref );

    if ( $func_id =~ /COG/i ) {
        $sql = qq{
            select g.cog, count(distinct g.gene_oid)
            from gene_cog_groups g
            where g.gene_oid in ( $gene_str ) 
            and g.cog in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.cog
        };
    }
    elsif ( $func_id =~ /KOG/i ) {
        $sql = qq{
            select g.kog, count(distinct g.gene_oid)
            from gene_kog_groups g
            where g.gene_oid in ( $gene_str )
            and g.kog in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.kog
        };
    }
    elsif ( $func_id =~ /pfam/i ) {
        $sql = qq{
            select g.pfam_family, count(distinct g.gene_oid)
            from gene_pfam_families g
            where g.gene_oid in ( $gene_str ) 
            and g.pfam_family in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.pfam_family
        };
    }
    elsif ( $func_id =~ /TIGR/i ) {
        $sql = qq{
            select g.ext_accession, count(distinct g.gene_oid) 
            from gene_tigrfams g 
            where g.gene_oid in ( $gene_str )
            and g.ext_accession in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.ext_accession
        };
    }
    elsif ( $func_id =~ /KO/i ) {
        $sql = qq{
            select g.ko_terms, count(distinct g.gene_oid)
            from gene_ko_terms g
            where g.gene_oid in ( $gene_str )
            and g.ko_terms in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.ko_terms
        };
    }
    elsif ( $func_id =~ /EC/i ) {
        $sql = qq{
            select g.enzymes, count(distinct g.gene_oid) 
            from gene_ko_enzymes g
            where g.gene_oid in ( $gene_str )
            and g.enzymes in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.enzymes
        };
    }
    elsif ( $func_id =~ /MetaCyc/i ) { 
        $sql = qq{
            select brp.in_pwys, count(distinct g.gene_oid)
            from biocyc_reaction_in_pwys brp, gene_biocyc_rxns g
            where brp.unique_id = g.biocyc_rxn
            and g.gene_oid in ( $gene_str )
            and brp.in_pwys in ( $func_ids_str )
            $rclause
            $imgClause
            group by brp.in_pwys
        };
    }
    elsif ( $func_id =~ /IPR/i ) { 
        $sql = qq{
            select g.id, count(distinct g.gene_oid)
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.gene_oid in ( $gene_str )
            and g.id in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.id
        }; 
    } 
    elsif ( $func_id =~ /TC/i ) { 
        $sql = qq{
            select g.tc_family, count(distinct g.gene_oid)
            from gene_tc_families g
            where g.gene_oid in ( $gene_str )
            and g.tc_family in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.tc_family
        }; 
    } 
    elsif ( $func_id =~ /ITERM/i ) { 
        #$sql = qq{
        #    select it.term_oid, count(distinct g.gene_oid)
        #    from img_term it, dt_img_term_path dtp, gene_img_functions g 
        #    where g.gene_oid in ( $gene_str )
        #    and g.function = dtp.map_term
        #    and dtp.term_oid = it.term_oid
        #    and it.term_oid in ( $func_ids_str )
        #    $rclause
        #    $imgClause
        #    group by it.term_oid
        #}; 
        $sql = qq{
            select g.function, count(distinct g.gene_oid)
            from gene_img_functions g 
            where g.gene_oid in ( $gene_str )
            and g.function in ( $func_ids_str )
            $rclause
            $imgClause
            group by g.function
        }; 
    } 
    elsif ( $func_id =~ /IPWAY/i ) { 
        #$sql = qq{
        #    select new.pathway_oid, count(distinct new.gene_oid)
        #    from (
        #        select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #        from img_pathway_reactions ipr,
        #            img_reaction_catalysts irc,
        #            dt_img_term_path dtp, gene_img_functions g
        #        where g.gene_oid in ( $gene_str )
        #        and ipr.pathway_oid in ( $func_ids_str )
        #        and ipr.rxn = irc.rxn_oid
        #        and irc.catalysts = dtp.term_oid
        #        and dtp.map_term = g.function
        #        $rclause
        #        $imgClause
        #        union
        #        select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #        from img_pathway_reactions ipr,
        #            img_reaction_t_components irtc,
        #            dt_img_term_path dtp, gene_img_functions g
        #        where g.gene_oid in ( $gene_str )
        #        and ipr.pathway_oid in ( $func_ids_str )
        #        and ipr.rxn = irtc.rxn_oid
        #        and irtc.term = dtp.term_oid
        #        and dtp.map_term = g.function
        #        $rclause
        #        $imgClause
        #    ) new
        #    group by new.pathway_oid
        #};
        $sql = qq{
            select new.pathway_oid, count(distinct new.gene_oid) 
            from (
                select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_catalysts irc,
                    gene_img_functions g
                where g.gene_oid in ( $gene_str )
                and ipr.pathway_oid in ( $func_ids_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                $rclause
                $imgClause
                union
                select ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr,
                    img_reaction_t_components irtc,
                    gene_img_functions g
                where g.gene_oid in ( $gene_str )
                and ipr.pathway_oid in ( $func_ids_str )
                and ipr.rxn = irtc.rxn_oid
                and irtc.term = g.function
                $rclause
                $imgClause
            ) new
            group by new.pathway_oid
        } 
    } 
    elsif ( $func_id =~ /PLIST/i ) {
        #$sql = qq{
        #    select pt.parts_list_oid, count(distinct g.gene_oid)
        #    from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #    where g.gene_oid in ( $gene_str )
        #    and pt.parts_list_oid in ( $func_ids_str )
        #    and pt.term = dtp.term_oid
        #    and dtp.map_term = g.function
        #    $rclause
        #    $imgClause
        #    group by pt.parts_list_oid
        #};
        $sql = qq{
            select pt.parts_list_oid, count(distinct g.gene_oid)
            from img_parts_list_img_terms pt, gene_img_functions g
            where g.gene_oid in ( $gene_str )
            and pt.parts_list_oid in ( $func_ids_str )
            and pt.term = g.function
            $rclause
            $imgClause
            group by pt.parts_list_oid
        };
    }
    
    #print "WorkspaceQueryUtil::getDbGeneFuncsCountSql \$sql: $sql<br/>\n";
    #print "WorkspaceQueryUtil::getDbGeneFuncsCountSql \@bindList: @bindList<br/>\n";

    return ( $sql, @bindList );
}


sub getFuncIdsStr {
    my ( $dbh, $func_ids_ref ) = @_;

    my $func_ids_str;

    my $func_id = @$func_ids_ref[0];
    if ( $func_id =~ /^BC/i || $func_id =~ /^NP/i 
        || $func_id =~ /^ITERM/i || $func_id =~ /^IPWAY/i || $func_id =~ /^PLIST/i 
        || $func_id =~ /^NETWK/i || $func_id =~ /^ICMPD/i || $func_id =~ /^IREXN/i || $func_id =~ /^PRULE/i ) {
        my @db_ids;
        for my $f_id ( @$func_ids_ref ) {
            my ( $id1, $id2 );
            if ($func_id =~ /\:/) {
                ( $id1, $id2 ) = split( /\:/, $f_id );
            }
            else {
                $id2 = $f_id;
            }
            $id2 = WebUtil::trimIntLeadingZero($id2);
            if ( isInt($id2) ) {
                push( @db_ids, $id2 );
            }
        }
        $func_ids_str = OracleUtil::getNumberIdsInClause1( $dbh, @db_ids );            
    }
    elsif ( $func_id =~ /^MetaCyc/i ) {
        my @db_ids;
        for my $f_id ( @$func_ids_ref ) {
            my ( $id1, $id2 );
            if ($func_id =~ /\:/) {
                ( $id1, $id2 ) = split( /\:/, $f_id );
            }
            else {
                $id2 = $f_id;
            }
            push( @db_ids, $id2 );
        }
        $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @db_ids );            
    }
    else {
        $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );        
    }

    return ($func_id, $func_ids_str);
}

sub addBackFuncIdPrefix {
    my ( $func_id, $func ) = @_;

    #print "addBackFuncIdPrefix() func_id=$func_id, func=$func<br/>\n";
    if ( $func_id =~ /\:/ && $func !~ /\:/ ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $func = "$id1:$func";
        #print "addBackFuncIdPrefix() after func=$func<br/>\n";
    }
    
    return ( $func );
}


1;
