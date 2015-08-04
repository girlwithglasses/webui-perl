package OperonSQL;
########################################################
# functions that return sql queries
# used in Operons.pm
#
# $Id: OperonSQL.pm 29739 2014-01-07 19:11:08Z klchu $
########################################################
use strict;
use warnings;
use CGI qw( :standard );
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp 'warningsToBrowser';
use DBI;
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use DrawTree;
use DrawTreeNode;

#use lib '/home/kmavromm/Perl_lib/';
#use ArrayRoutines::Array_Routines;
#use lib '/home/kmavromm/img_ui/';
#use OperonSQL;
# use OperonFormat;

my $env         = getEnv();
my $cgi_dir     = $env->{cgi_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};    # application tmp directory
my $main_cgi    = $env->{main_cgi};
my $verbose     = $env->{verbose};
my $tmp_dir     = $env->{tmp_dir};        # viewable image tmp directory
my $tmp_url     = $env->{tmp_url};

######################################################################

# need to change the sql queries for getXXXConnectionsSql in the next
# releases of IMG (> 2.4)
# Currently due to an error in the script that generated the data
# comm_cass_taxano and comm_fusion_taxano were mixed.
# the program has been corrected.
# in the next releases the queries must change the order of these two
# columns.
#######################################################################
#generate the sql for cogs
sub getCogConnectionsSql {
    my ($gene_clusterStr) = @_;
    my $sql = qq{
		select distinct gcc.gene1,c1.cog_name,gcc.gene2,c2.cog_name,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_cog gcc
		join cog c1 on gcc.gene1 = c1.cog_id
		join cog c2 on gcc.gene2 = c2.cog_id
		where 	gcc.gene1 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano >= 1
		and gcc.gene1 <> gcc.gene2
		union all
		select distinct gcc.gene1,c1.cog_name,gcc.gene2,c2.cog_name,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_cog gcc
		join cog c1 on gcc.gene1 = c1.cog_id
		join cog c2 on gcc.gene2 = c2.cog_id
		where 	gcc.gene2 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano >= 1
		and gcc.gene1 <> gcc.gene2
		};

    return $sql;
}

sub getPfamConnectionsSql {
    my ($gene_clusterStr) = @_;
    my $sql = qq{
		select distinct gcc.gene1,c1.description,gcc.gene2,c2.description,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_pfam gcc
		join pfam_family c1 on gcc.gene1 = c1.ext_accession
		join pfam_family c2 on gcc.gene2 = c2.ext_accession
		where 	gcc.gene1 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano >= 1
		and gcc.gene1 <> gcc.gene2
		union all
		select distinct gcc.gene1,c1.description,gcc.gene2,c2.description,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_pfam gcc
		join pfam_family c1 on gcc.gene1 = c1.ext_accession
		join pfam_family c2 on gcc.gene2 = c2.ext_accession
		where 	gcc.gene2 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano >= 1
		and gcc.gene1 <> gcc.gene2
		};

    return $sql;
}

sub getBBHConnectionsSql {
    my ($gene_clusterStr) = @_;
    my $sql = qq{
		select distinct gcc.gene1,c1.cluster_name,gcc.gene2,c2.cluster_name,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_bbh gcc
		join bbh_cluster c1 on gcc.gene1 = c1.cluster_id
		join bbh_cluster c2 on gcc.gene2 = c2.cluster_id
		where 	gcc.gene1 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano > 0
		and gcc.gene1 <> gcc.gene2
		union all
		select distinct gcc.gene1,c1.cluster_name,gcc.gene2,c2.cluster_name,
		gcc.taxa1,gcc.taxa2,gcc.comm_taxano,gcc.comm_cass_taxano,gcc.comm_fusion_taxano,
		gcc.coeff_gts,gcc.coeff_gns,gcc.coeff_gfs
		from gene_correlation_bbh gcc
		join bbh_cluster c1 on gcc.gene1 = c1.cluster_id
		join bbh_cluster c2 on gcc.gene2 = c2.cluster_id
		where 	gcc.gene2 in ('$gene_clusterStr')
		and gcc.comm_cass_taxano > 0
		and gcc.gene1 <> gcc.gene2
		};

    return $sql;
}

sub getCogSql {
    my ($gene_oid) = @_;
    my $sql = qq{
		select cgg.gene_oid,c1.cog_id,c1.cog_name
		from gene_cog_groups cgg
		join cog c1 on cgg.cog = c1.cog_id
		where cgg.gene_oid= ?
		
		};
    return ( $sql, $gene_oid );
}

sub getPfamSql {
    my ($gene_oid) = @_;
    my $sql = qq{
		select cgg.gene_oid,c1.ext_accession,c1.name
		from gene_pfam_families cgg
		join pfam_family c1 on cgg.pfam_family = c1.ext_accession
		where cgg.gene_oid= ?	
		};
    return ( $sql, $gene_oid );
}

sub getBBHSql {
    my ($gene_oid) = @_;
    my $sql = qq{
		select cgg.member_genes,c1.cluster_id,c1.cluster_name
		from bbh_cluster_member_genes cgg
		join bbh_cluster c1 on cgg.cluster_id = c1.cluster_id
		where cgg.member_genes= ?
		};
    return ( $sql, $gene_oid );
}

sub getClusterName {
    my ( $cluster_id, $method ) = @_;
    my $sql;

    if ( lc($method) eq 'cog' ) {
        $sql = qq{
            select cog_id,cog_name from cog where cog_id= ?
        };
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = qq{
            select ext_accession,name from pfam_family where ext_accession= ?
        };
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = qq{
            select cluster_id,cluster_name from bbh_cluster where cluster_id= ?
        };
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    my $clusterData;
    while ( my ( $cluster, $name ) = $cur->fetchrow_array() ) {
        $clusterData = $name;
    }
    $cur->finish;
    #$dbh->disconnect();
    return $clusterData;
}

sub getSqlExpandedCogGroups {

    #genes in cassette(cog groups)
    my @genes = @_;
    my @from;
    my @joins;
    my @filters;
    #######################3

    # 	print "Genes @genes<br>\n";
    my $i;
    for ( $i = 0 ; $i < scalar(@genes) ; $i++ ) {
        push @from, "cassette_box_cog_xlogs cbg$i";

        push @joins, "cbg$i.box_oid=cbg" . ( $i + 1 ) . ".box_oid";
        push @filters, "cbg$i.cog_cluster='$genes[$i]'";
    }
    my $select =
      " cbg$i.cog_cluster, jc.cog_name ,count(distinct gc1.taxon) as taxa ";
    my $from =
      join( qq{ , }, @from )
      . " , cassette_box_cog_xlogs cbg$i , cassette_box_cassettes_cog cbc1, cog jc, gene_cassette gc1";
    my $joins =
      join( qq{ AND }, @joins )
      . " AND cbg1.box_oid=cbc1.box_oid AND jc.cog_id=cbg$i.cog_cluster  					 AND gc1.cassette_oid=cbc1.cassettes";
    my $filters = join( qq{ AND }, @filters );
    my $group   = "cbg$i.cog_cluster, jc.cog_name ";
    my $order   = "taxa ";

    my $sql = qq{
	SELECT $select 
	FROM $from
	WHERE $joins
	AND $filters
	GROUP BY $group
	ORDER BY $order DESC
	};

    # print "$sql<br>\n";
    return $sql;
}

sub getSqlExpandedPfamGroups {

    #genes in cassette(cog groups)
    my @genes = @_;
    my @from;
    my @joins;
    my @filters;
    #######################3

    # 	print "Genes @genes<br>\n";
    my $i;
    for ( $i = 0 ; $i < scalar(@genes) ; $i++ ) {
        push @from, "cassette_box_pfam_xlogs cbg$i";

        push @joins, "cbg$i.box_oid=cbg" . ( $i + 1 ) . ".box_oid";
        push @filters, "cbg$i.pfam_cluster='$genes[$i]'";
    }
    my $select =
      " cbg$i.pfam_cluster, jc.name ,count(distinct gc1.taxon) as taxa ";
    my $from =
      join( qq{ , }, @from )
      . " , cassette_box_pfam_xlogs cbg$i , cassette_box_cassettes_pfam cbc1, pfam_family jc, gene_cassette gc1";
    my $joins =
      join( qq{ AND }, @joins )
      . " AND cbg1.box_oid=cbc1.box_oid AND jc.ext_accession=cbg$i.pfam_cluster  					 AND gc1.cassette_oid=cbc1.cassettes";
    my $filters = join( qq{ AND }, @filters );
    my $group   = "cbg$i.pfam_cluster, jc.name ";
    my $order   = "taxa ";

    my $sql = qq{
	SELECT $select 
	FROM $from
	WHERE $joins
	AND $filters
	GROUP BY $group
	ORDER BY $order DESC
	};

    # print "$sql<br>\n";
    return $sql;
}

sub getSqlExpandedBBHGroups {

    #genes in cassette(cog groups)
    my @genes = @_;
    my @from;
    my @joins;
    my @filters;
    #######################3

    # 	print "Genes @genes<br>\n";
    my $i;
    for ( $i = 0 ; $i < scalar(@genes) ; $i++ ) {
        push @from, "cassette_box_bbh_xlogs cbg$i";

        push @joins, "cbg$i.box_oid=cbg" . ( $i + 1 ) . ".box_oid";
        push @filters, "cbg$i.bbh_cluster='$genes[$i]'";
    }
    my $select =
      " cbg$i.bbh_cluster, jc.cluster_name ,count(distinct gc1.taxon) as taxa ";
    my $from =
      join( qq{ , }, @from )
      . " , cassette_box_bbh_xlogs cbg$i , cassette_box_cassettes_bbh cbc1, bbh_cluster jc, gene_cassette gc1";
    my $joins =
      join( qq{ AND }, @joins )
      . " AND cbg1.box_oid=cbc1.box_oid AND jc.cluster_id=cbg$i.bbh_cluster   AND gc1.cassette_oid=cbc1.cassettes";
    my $filters = join( qq{ AND }, @filters );
    my $group   = "cbg$i.bbh_cluster, jc.cluster_name ";
    my $order   = "taxa ";

    my $sql = qq{
	SELECT $select 
	FROM $from
	WHERE $joins
	AND $filters
	GROUP BY $group
	ORDER BY $order DESC
	};

    # print "$sql<br>\n";
    return $sql;
}

sub checkFusion {
    my ($gene_oid) = @_;
    my @gene_oids;
    my $sql = qq{
        select component 
        from gene_fusion_components 
        where gene_oid= ?
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    while ( my ($component) = $cur->fetchrow_array() ) {
        push @gene_oids, $component;
    }
    $cur->finish;
    #$dbh->disconnect();

    #if the array is empty return the original gene
    if ( scalar(@gene_oids) == 0 ) {
        push @gene_oids, $gene_oid;
    }
    return @gene_oids;

}
###############################################################
# finds the composite bbh for a given bbh
###############################################################
sub getCompositeBBH {
    my ($bbh) = @_;
    my @a;
    my $sql = qq{
select distinct m1.CLUSTER_ID
from GENE_FUSION_COMPONENTS gfc
join BBH_CLUSTER_MEMBER_GENES m1 on gfc.gene_oid=m1.MEMBER_GENES
join BBH_CLUSTER_MEMBER_GENES m2 on gfc.component=m2.MEMBER_GENES
where m2.CLUSTER_ID= ?
	};
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $bbh );
    while ( my ($composite) = $cur->fetchrow_array() ) {
        push @a, $composite;
    }
    $cur->finish();
    #$dbh->disconnect();
    return @a;
}

###############################################################
# get lists of genomes that
# have a specific gene cluster
###############################################################
sub getGenomesWithCOGSQL {
    my ($cluster_id) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    
    for my $cluster ( @{$cluster_id} ) {
        push @sql,
          qq{select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid
			from taxon t
			join gene g on g.taxon=t.taxon_oid
			join gene_cog_groups gc on gc.gene_oid=g.gene_oid
			where gc.cog='$cluster'
			$imgClause
          };
    }
    my $sql = join( " intersect ", @sql );

    # 	print "$sql<br>\n";
    return $sql;
}

sub getGenomesWithPfamSQL {
    my ($cluster_id) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        push @sql, qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid
			from taxon t
			join gene g on g.taxon=t.taxon_oid
			join gene_pfam_families gc on gc.gene_oid=g.gene_oid
			where gc.pfam_family='$cluster'
			$imgClause
          };
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

sub getGenomesWithBBHSQL {
    my ($cluster_id) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {

        # if the bbhcluster is a fusion component we need to find the composites

        push @sql, qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid
			from taxon t
			join gene g on g.taxon=t.taxon_oid
			join bbh_cluster_member_genes gc on gc.member_genes=g.gene_oid
			where gc.cluster_id='$cluster'
			$imgClause
          };
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}
############################################################################
sub getGenomesWithCOGCassetteSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
     my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,gcg.cassette_oid
			from gene_cassette gc
			join gene_cassette_genes gcg on gc.cassette_oid=gcg.cassette_oid
			join gene g on gcg.gene=g.gene_oid
			join gene_cog_groups cg on cg.gene_oid=g.gene_oid
			join taxon t on t.taxon_oid=g.taxon
			where cg.cog='$cluster'
			$imgClause
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }

        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

sub getGenomesWithPfamCassetteSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,gcg.cassette_oid
			from gene_cassette gc
			join gene_cassette_genes gcg on gc.cassette_oid=gcg.cassette_oid
			join gene g on gcg.gene=g.gene_oid
			join gene_pfam_families cg on cg.gene_oid=g.gene_oid
			join taxon t on t.taxon_oid=g.taxon
			where cg.pfam_family='$cluster'
			$imgClause
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }
        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

sub getGenomesWithBBHCassetteSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
     my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,gcg.cassette_oid
			from gene_cassette gc
			join gene_cassette_genes gcg on gc.cassette_oid=gcg.cassette_oid
			join gene g on gcg.gene=g.gene_oid
			join bbh_cluster_member_genes cg on cg.member_genes=g.gene_oid
			join taxon t on t.taxon_oid=g.taxon
			where cg.cluster_id='$cluster'
			$imgClause
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }
        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

##################################################################
sub getGenomesWithCOGFusionSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,g.gene_oid,g.product_name
			from gene_cog_groups gc
			join gene g on gc.gene_oid=g.gene_oid
			join taxon t on g.taxon=t.taxon_oid
			where gc.cog='$cluster'
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }
        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

sub getGenomesWithPfamFusionSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,g.gene_oid,g.product_name
			from gene_pfam_families gc
			join gene g on gc.gene_oid=g.gene_oid
			join taxon t on g.taxon=t.taxon_oid
			where gc.pfam_family='$cluster'
			$imgClause
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }
        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

sub getGenomesWithBBHFusionSQL {
    my ( $cluster_id, $taxon ) = @_;
    my @sql;
    my $imgClause = WebUtil::imgClause('t');
    for my $cluster ( @{$cluster_id} ) {
        my $s = qq{
            select distinct t.domain, t.seq_status, t.taxon_name,t.taxon_oid,g.gene_oid,g.product_name
			from bbh_cluster_member_genes gc
			join gene g on gc.gene_oid=g.gene_oid
			join taxon t on g.taxon=t.taxon_oid
			where gc.cluster_id='$cluster'
			$imgClause
        };
        if ($taxon) {
            $s .= " and t.taxon_oid=$taxon";
        }
        push @sql, $s;
    }
    my $sql = join( " intersect ", @sql );
    return $sql;
}

################################################################
# get all the gene pairs from the table
# between a query gene and genes that belong to the same family
#################################################################
sub getFamilyConnectionSQL {
    my ( $cluster_id, $cluster_method ) = @_;
    my $sql;

    # get the family
    my @families = getFamily( $cluster_id, $cluster_method );

    # 	print "<p> Families: @families. </p>\n";
    if ( lc($cluster_method) eq 'cog' ) {
        $sql = getCOGFamilyConnections( \@families );
    } elsif ( lc($cluster_method) eq 'pfam' ) {
        $sql = getPFAMFamilyConnections( \@families );
    } elsif ( lc($cluster_method) eq 'bbh' ) {
        $sql = getBBHFamilyConnections( \@families );
    } else {
        webError("Unknown clustering method");
    }

    # 	print "<p>$sql</p>\n";
    return $sql;
}

sub getCOGFamilyConnections {
    my ($families) = @_;
    my $fstr = join( qq{','}, @{$families} );
    my $sql  = qq{
		select gene1,gene2,coeff_gts,coeff_gns,coeff_gfs,c1.cog_name,c2.cog_name
		from gene_correlation_cog gc
		join COG_families f1 on gc.gene1=f1.COG_id
		join COG_families f2 on gc.gene2=f2.COG_id
		join COG c1 on c1.cog_id=gc.gene1
		join COG c2 on c2.cog_id=gc.gene2
		and f1.families in ('$fstr')
		and f2.families =f1.families
		where coeff_gns>0
	};
    return $sql;
}

sub getPFAMFamilyConnections {
    my ($families) = @_;
    my $fstr = join( qq{','}, @{$families} );
    my $sql  = qq{
		select gene1,gene2,coeff_gts,coeff_gns,coeff_gfs,p1.name,p2.name
		from gene_correlation_pfam gc
		join Pfam_family_families f1 on gc.gene1=f1.ext_accession
		join Pfam_family_families f2 on gc.gene1=f2.ext_accession
		join pfam_family p1 on p1.ext_accession=gc.gene1	
		join pfam_family p2 on p2.ext_accession=gc.gene2
		and f1.families in ('$fstr')
		and f1.families=f2.families
		where coeff_gns>0

	};
    return $sql;
}

sub getBBHFamilyConnections {
    my ($families) = @_;
    my $fstr = join( qq{','}, @{$families} );
    my $sql  = qq{
		select gene1,gene2,coeff_gts,coeff_gns,coeff_gfs,b1.cluster_name,b2.cluster_name
		from gene_correlation_bbh gc
		join BBH_cluster_families f1 on gc.gene1=f1.cluster_id
		join BBH_cluster_families f2 on gc.gene2=f2.cluster_id
		join BBH_cluster b1 on b1.cluster_id=gc.gene1
		join BBH_cluster b2 on b2.cluster_id=gc.gene2
		and f1.families in ('$fstr')
		and f2.families =f2.families
		where coeff_gns>0
	};
    return $sql;
}

#################################################################
# find the family(ies) of a given cluster
#################################################################
sub getFamily {
    my ( $clusters, $cluster_method ) = @_;
    my $sql;
    my @families;
    
    
    if ( lc($cluster_method) eq 'cog' ) {
        $sql = qq{
        select families
        from COG_families
        where COG_id = ?
        };
    } elsif ( lc($cluster_method) eq 'pfam' ) {
        $sql = qq{
        select families
        from Pfam_family_families
        where ext_accession = ?
        };
    } elsif ( lc($cluster_method) eq 'bbh' ) {
        $sql = qq{
        select families
        from BBH_cluster_families
        where cluster_id = ?
        };
    } else {
        webError("Unknown clustering method");
    }

    my $dbh = dbLogin();
    my $cur = prepSql($dbh, $sql, $verbose);
    foreach my $cluster_id ( @{$clusters} ) {
        execStmt( $cur, $cluster_id );
        while ( my ($family) = $cur->fetchrow_array() ) {
            push @families, $family;
        }
    }

    #$cur->finish;
    #$dbh->disconnect();

    return @families;
}


1;
