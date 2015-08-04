############################################################################
# Utility subroutines for queries
# $Id: QueryUtil.pm 33879 2015-08-03 18:21:55Z jinghuahuang $
############################################################################
package QueryUtil;

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
use OracleUtil;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_dir = $env->{base_dir};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $in_file  = $env->{in_file};

my $nvl       = getNvl();

############################################################################
# getTaxonOidNameSql
############################################################################
sub getTaxonOidNameSql {
    my ($taxon_oid_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql    = qq{
        select t.taxon_oid, t.taxon_display_name
        from taxon t
        where t.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getTaxonOidNameDomainSql {
    my ($taxon_oid_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql    = qq{
        select t.taxon_oid, t.taxon_display_name, t.domain
        from taxon t
        where t.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getTaxonOidNameGenomeTypeSql {
    my ($taxon_oid_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql    = qq{
        select t.taxon_oid, t.taxon_display_name, t.genome_type
        from taxon t
        where t.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getTaxonOidGenomeTypeSql {
    my ($taxon_oid_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql    = qq{
        select t.taxon_oid, t.genome_type
        from taxon t
        where t.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getTaxonOidPublicSql {
    my ($taxon_oid_str, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql    = qq{
        select t.taxon_oid, t.is_public
        from taxon t
        where t.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getAllTaxonOidAndNameBindSql {
    my ($rclause, @bindList) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql     = qq{ 
        select tx.taxon_oid, tx.taxon_display_name 
        from taxon tx 
        where 1 = 1
        $rclause
        $imgClause
    }; 
        
    return ($sql, @bindList);
}

sub getAllTaxonOidBindSql {
    my ($rclause, @bindList) = urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
	   select tx.taxon_oid
	   from taxon tx
	   where 1 = 1
	   $rclause
	   $imgClause
    };
        
    return ($sql, @bindList);
}

############################################################################
# getTotalTaxonCount
############################################################################
sub getTotalTaxonCount {
    my ( $dbh2 ) = @_;

    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select count(*)
       from taxon tx
       where 1 = 1
       $rclause
       $imgClause
    };
    #tx.domain in ('Archaea','Bacteria', 'Eukaryota', '*Microbiome')
    my $cur = execSqlBind( $dbh2, $sql, \@bindList_ur, $verbose );
    my ($total_count) = $cur->fetchrow();
    $cur->finish();

    return $total_count;
}

############################################################################
# fetchTaxonOid2NameHash
############################################################################
sub fetchTaxonOid2NameHash {
    my ( $dbh, $taxon_oids_ref, $rclause, $imgClause) = @_;

    my %name_h;

    my @oids = getIntOid(@$taxon_oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchTaxonOid2NameHash oids size:".@oids."<br/>\n";
        
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidNameSql($oid_str, $rclause, $imgClause);
         
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;
            $name_h{$taxon_oid} = $taxon_display_name;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
        
        #print "QueryUtil fetchTaxonOid2NameHash name_h size:".(keys(%name_h))."<br/>\n";
    }

    return %name_h;
}

############################################################################
# fetchTaxonOid2NameHash2
############################################################################
sub fetchTaxonOid2NameHash2 {
    my ( $dbh, $taxon_oid_str, $rclause, $imgClause) = @_;

    my $sql = getTaxonOidNameSql($taxon_oid_str, $rclause, $imgClause);

    my %name_h;
    my $cur = execSql( $dbh, $sql, $verbose);
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $name_h{$taxon_oid} = $taxon_display_name;
    }
    $cur->finish();

    return %name_h;
}

############################################################################
# fetchTaxonOid2NameGenomeTypeHash
############################################################################
sub fetchTaxonOid2NameGenomeTypeHash {
    my ($dbh, $oids_ref, $rclause, $imgClause) = @_;

    my @oids = getIntOid(@$oids_ref);

    my %name_h;
    my %gtype_h;
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchTaxonOid2NameGenomeTypeHash oids size:".@oids."<br/>\n";
        
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidNameGenomeTypeSql($oids_str, $rclause, $imgClause);
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name, $genomeType ) = $cur->fetchrow();
            last if !$taxon_oid;
            $name_h{$taxon_oid} = $taxon_display_name;
            $gtype_h{$taxon_oid} = $genomeType;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oids_str =~ /gtt_num_id/i );        
    }

    return (\%name_h, \%gtype_h);
}


############################################################################
# fetchTaxonOid2GenomeTypeHash
############################################################################
sub fetchTaxonOid2GenomeTypeHash {
    my ($dbh, $oids_ref, $rclause, $imgClause) = @_;

    my %gtype_h;
    my @oids = getIntOid(@$oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchTaxonOid2GenomeTypeHash oids size:".@oids."<br/>\n";
        
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidGenomeTypeSql($oids_str, $rclause, $imgClause);
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $genomeType ) = $cur->fetchrow();
            last if !$taxon_oid;        
            $gtype_h{$taxon_oid} = $genomeType;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oids_str =~ /gtt_num_id/i );        
    }

    return (\%gtype_h);
}

############################################################################
# getAllTaxonGidInfo
############################################################################
sub getAllTaxonGidInfo {
    my ($dbh, $domain) = @_;

    my %taxon2gidInfo;

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my $domainClause;
    my @bindList;
    if ( !blankStr($domain) ) {
        $domainClause = " and t.domain = ? ";
        push(@bindList, '$domain');
    }
    else {
        $domainClause = " and t.domain in ('Archaea','Bacteria', 'Eukaryota', '*Microbiome') ";
    }

    my $sql = qq{
        select distinct t.taxon_oid, t.sequencing_gold_id, t.sample_gold_id
        from taxon t
        where 1 = 1
        $domainClause
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose, @bindList);
    for ( ;; ) {
        my ($taxon_oid, @colVals) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( ! $taxon2gidInfo{$taxon_oid} ) {
            my $r;
            for (my $j = 0; $j < scalar(@colVals); $j++) {
                if ($j != 0) {
                    $r .= "\t";
                }
                $r .= "$colVals[$j]";
            }
            $taxon2gidInfo{$taxon_oid} = $r;            
        }
    }
    $cur->finish();
    #print "getTaxonGidInfo() taxon2gidInfo: <br/>\n";
    #print Dumper(\%taxon2gidInfo);
    #print "<br/>\n";

    return (\%taxon2gidInfo);
}

############################################################################
# getTaxonForGids
############################################################################
sub getTaxonForGids {
    my ($dbh, $gids_ref, $domain) = @_;

    my %taxon2gidInfo;

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $oids_str = OracleUtil::getFuncIdsInClause( $dbh, @$gids_ref );
    
    my $domainClause;
    my @bindList;
    if ( !blankStr($domain) ) {
        $domainClause = " and t.domain = ? ";
        push(@bindList, '$domain');
    }
    #else {
    #    $domainClause = " and t.domain in ('Archaea','Bacteria', 'Eukaryota', '*Microbiome') ";
    #}

    my $sql = qq{
        select distinct t.taxon_oid, t.sequencing_gold_id
        from taxon t
        where t.sequencing_gold_id in ($oids_str)
        $domainClause
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose, @bindList);
    for ( ;; ) {
        my ($taxon_oid, $gold_id) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxon2gidInfo{$taxon_oid} = $gold_id;            
    }
    $cur->finish();
    #print "getTaxonForGid() taxon2gidInfo: <br/>\n";
    #print Dumper(\%taxon2gidInfo);
    #print "<br/>\n";

    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
        if ( $oids_str =~ /gtt_func_id/i );        

    return (\%taxon2gidInfo);
}


############################################################################
# fetchTaxonMetaInfo
############################################################################
sub fetchTaxonMetaInfo {
    my ($dbh, $oids_aref) = @_;

    my %taxon_name_h;
    my %taxon_gtype_h;
    my %taxon2metaInfo;

    my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$oids_aref );
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql       = qq{
        select distinct t.taxon_oid, t.taxon_display_name, t.genome_type,
            t.sequencing_gold_id, t.sample_gold_id, t.submission_id, t.is_public, t.analysis_project_id
        from taxon t
        where t.taxon_oid in ($oids_str)
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($taxon_oid, $taxon_display_name, $genome_type, @colVals) = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon_name_h{$taxon_oid} = $taxon_display_name;
        $taxon_gtype_h{$taxon_oid} = $genome_type;

        if ( ! $taxon2metaInfo{$taxon_oid} ) {
            my $r;
            for (my $j = 0; $j < scalar(@colVals); $j++) {
                if ($j != 0) {
                    $r .= "\t";
                }
                $r .= "$colVals[$j]";
            }
            $taxon2metaInfo{$taxon_oid} = $r;            
        }
    }
    $cur->finish();
    #print "getTaxonMetaInfo() taxon_name_h: <br/>\n";
    #print Dumper(\%taxon_name_h);
    #print "<br/>\n";
    #print "getTaxonMetaInfo() taxon_gtype_h: <br/>\n";
    #print Dumper(\%taxon_gtype_h);
    #print "<br/>\n";
    #print "getTaxonMetaInfo() taxon2metaInfo: <br/>\n";
    #print Dumper(\%taxon2metaInfo);
    #print "<br/>\n";

    return (\%taxon_name_h, \%taxon_gtype_h, \%taxon2metaInfo);
}

############################################################################
# fetchTaxonsOfDomainABE
############################################################################
sub fetchTaxonsOfDomainABE {
    my ($dbh, $oids_ref, $rclause, $imgClause) = @_;

    my @new_oids;
    
    my @oids = getIntOid(@$oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil::fetchTaxonsOfDomainABE() oids size:".@oids."<br/>\n";
        
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidNameDomainSql($oids_str, $rclause, $imgClause);
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $t_name, $domain ) = $cur->fetchrow();
            last if !$taxon_oid;
            next if ( $domain ne 'Archaea' && $domain ne 'Bacteria' && $domain ne 'Eukarya' );
            push(@new_oids, $taxon_oid);  
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oids_str =~ /gtt_num_id/i );        
    }

    return (@new_oids);
}


############################################################################
# fetchTaxonOid2PublicHash
############################################################################
sub fetchTaxonOid2PublicHash {
    my ( $dbh, $taxon_oids_ref, $rclause, $imgClause) = @_;

    my %public_h;

    my @oids = getIntOid(@$taxon_oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchTaxonOid2PublicHash oids size:".@oids."<br/>\n";
        
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidPublicSql($oid_str, $rclause, $imgClause);
         
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $isPublic ) = $cur->fetchrow();
            last if !$taxon_oid;
            $public_h{$taxon_oid} = $isPublic;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
        
        #print "QueryUtil fetchTaxonOid2PublicHash name_h size:".(keys(%name_h))."<br/>\n";
    }

    return %public_h;
}

############################################################################
# fetchTaxonsDomains
############################################################################
sub fetchTaxonsDomains {
    my ($dbh, $oids_ref, $rclause, $imgClause) = @_;

    my @domains;
    
    my @oids = getIntOid(@$oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil::fetchTaxonsDomain() oids size:".@oids."<br/>\n";
        
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        if (!$rclause && !$imgClause) {
            $rclause = WebUtil::urClause('t');
            $imgClause = WebUtil::imgClause('t');
        }
        my $sql = qq{
            select distinct t.domain
            from taxon t
            where t.taxon_oid in ($oids_str)
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $domain ) = $cur->fetchrow();
            last if !$domain;
            push(@domains, $domain);  
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oids_str =~ /gtt_num_id/i );        
    }

    return (@domains);
}

############################################################################
# fetchAllTaxonsOidAndNameFile
############################################################################
sub fetchAllTaxonsOidAndNameFile {
    my ($dbh, $rclause, $imgClause) = @_;

    my %taxon2name_h;
    my %taxon_in_file;

    my $sql = getAllTaxonsOidAndNameFileSql( $rclause, $imgClause );
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $in_file ) = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon2name_h{$taxon_oid} = $taxon_display_name;
        if ($in_file eq 'Yes') {
            $taxon_in_file{$taxon_oid} = 1;
        }
    }
    $cur->finish();

    return (\%taxon2name_h, \%taxon_in_file);
}

sub getAllTaxonsOidAndNameFileSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
        from taxon t 
        where 1 = 1
        $rclause
        $imgClause
    };
    #print "fetchAllTaxonsOidAndNameFile() sql=$sql<br/>\n";

    return $sql;
}

############################################################################
# fetchTaxonsOidAndNameFile
############################################################################
sub fetchTaxonsOidAndNameFile {
    my ($dbh, $taxon_oids_ref, $rclause, $imgClause) = @_;

    my %taxon2name_h;
    my %taxon_in_file;
    my %taxon_db;

    my ( $sql, $taxon_oid_str ) = getTaxonsOidAndNameFileSql( $dbh, $taxon_oids_ref, $rclause, $imgClause );
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $in_file ) = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon2name_h{$taxon_oid} = $taxon_display_name;
        if ($in_file eq 'Yes') {
            $taxon_in_file{$taxon_oid} = 1;
        }
        else {
            $taxon_db{$taxon_oid} = 1;            
        }
    }
    $cur->finish();

    return (\%taxon2name_h, \%taxon_in_file, \%taxon_db, $taxon_oid_str);
}

sub getTaxonsOidAndNameFileSql {
    my ($dbh, $taxon_oids_ref, $rclause, $imgClause) = @_;

    my $sql;
    my $oid_str;

    my @oids = QueryUtil::getIntOid(@$taxon_oids_ref);
    if (scalar(@oids) > 0) {
        $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        
        if (!$rclause && !$imgClause) {
            $rclause = WebUtil::urClause('t');
            $imgClause = WebUtil::imgClause('t');
        }
        $sql = qq{
            select t.taxon_oid, t.taxon_display_name, t.in_file
            from taxon t 
            where t.taxon_oid in ($oid_str)
            $rclause
            $imgClause
        };
    }

    return ($sql, $oid_str);
}

############################################################################
# fetchTaxonName
############################################################################
sub fetchTaxonName {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select $nvl(taxon_display_name, taxon_name)
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($name) = $cur->fetchrow();
    $cur->finish();

    return $name;
}

############################################################################
# fetchSingleTaxonName
############################################################################
sub fetchSingleTaxonName {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNameSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $taxon_display_name = $cur->fetchrow();
    $cur->finish();
    
    return $taxon_display_name;
}

############################################################################
# fetchSingleTaxonNameGenomeType
############################################################################
sub fetchSingleTaxonNameGenomeType {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNameGenomeTypeSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_display_name, $inFile, $genome_type) = $cur->fetchrow();
    $cur->finish();
    
    return ($taxon_display_name, $inFile, $genome_type);
}

############################################################################
# fetchSingleTaxonRank
############################################################################
sub fetchSingleTaxonRank {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{ 
        select t.seq_status, 
            t.domain, t.phylum, t.ir_class, t.ir_order,
	        t.family, t.genus, t.species 
	    from taxon t 
	    where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species) = $cur->fetchrow();
    $cur->finish();
    
    return ($seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
}


sub getSimpleTaxonSql {
    my ( $rclause, $imgClause ) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name 
        from taxon t 
        where 1 = 1 
        $rclause 
        $imgClause
    };
        
    return $sql;
}

sub fetchSimpleTaxonOidNameHash {
    my ( $dbh, $taxon_name_h_ref, $rclause, $imgClause) = @_;
    
    my $sql = getSimpleTaxonSql($rclause, $imgClause);
    #print "sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid, $taxon_name) = $cur->fetchrow();
        last if ( !$taxon_oid );

        $taxon_name_h_ref->{$taxon_oid} = "$taxon_name";
        #print "taxon_name_h added with $taxon_oid<br/>\n";
    }
    $cur->finish();
}

sub getSingleTaxonNameSql {
    my ( $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{ 
        select t.taxon_display_name 
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    #print "getSingleTaxonNameSql sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleTaxonNameGenomeTypeSql {
    my ( $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{ 
        select t.taxon_display_name, t.in_file, t.genome_type 
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    #print "getSingleTaxonNameGenomeTypeSql sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleTaxonNvlNameSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{ 
        select $nvl(t.taxon_name, t.taxon_display_name) 
        from taxon t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    #print "getSingleTaxonNvlNameSql sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonNvlName {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNvlNameSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name) = $cur->fetchrow();
    $cur->finish();
    
    return $taxon_name;
}

sub fetchSingleTaxonNameAndPangenome {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{
        select t.taxon_display_name, t.is_pangenome
        from taxon t
	    where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name, $is_pangenome) = $cur->fetchrow();
    $cur->finish();
    
    return ($taxon_name, $is_pangenome);
}

sub getSingleTaxonGenesSql {
    my ( $rclause, $imgClause) = @_;
    

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid, g.locus_type
        from gene g
        where g.taxon = ?
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonGenesSql() sql: $sql\n");
    #print "getSingleTaxonGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleTaxonCDSGenesSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonCDSGenesSql() sql: $sql\n");
    #print "getSingleTaxonCDSGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonCDSGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonCDSGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonRnaGenesSql {
    my ( $locus_type, $gene_symbol, $rclause, $imgClause) = @_;

    my $optWhereClause;
    if ( $locus_type eq "xRNA" ) {
        $optWhereClause = "and g.locus_type not in( 'rRNA', 'tRNA' )";
        $optWhereClause .= "and g.locus_type like '%RNA' ";
    } elsif ( $locus_type ne "" ) {
        $optWhereClause = " and g.locus_type = '$locus_type' "
          if $locus_type ne "";
        my $x = lc($gene_symbol);
        $optWhereClause .= " and lower(g.gene_symbol) = '$x' "
          if $gene_symbol ne "";
    } else {
        $optWhereClause = "and g.locus_type like '%RNA' ";
    }
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.obsolete_flag = 'No'
        $optWhereClause
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonRnaGenesSql() sql: $sql\n");
    #print "getSingleTaxonRnaGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonRnaGenes {
    my ( $dbh, $taxon_oid, $locus_type, $gene_symbol, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonRnaGenesSql($locus_type, $gene_symbol, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonGenesWithFuncSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and not ( lower( g.gene_display_name ) like '%hypothetical%' or
          lower( g.gene_display_name ) like '%unknown%' or
          lower( g.gene_display_name ) like '%unnamed%' or
          lower( g.gene_display_name ) like '%predicted protein%' or
          g.gene_display_name is null 
        )
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonGenesWithFuncSql() sql: $sql\n");
    #print "getSingleTaxonGenesWithFuncSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonGenesWithFunc {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonGenesWithFuncSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonGenesWithoutFuncSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and ( lower( g.gene_display_name ) like '%hypothetical%' or
          lower( g.gene_display_name ) like '%unknown%' or
          lower( g.gene_display_name ) like '%unnamed%' or
          lower( g.gene_display_name ) like '%predicted protein%' or
          g.gene_display_name is null 
        )
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonGenesWithFuncSql() sql: $sql\n");
    #print "getSingleTaxonGenesWithFuncSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonGenesWithoutFunc {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonGenesWithoutFuncSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonNoEnzymeWithKOGenesSql {

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.aa_seq_length,
        gckt.ko_terms, ko.definition,
        gckt.bit_score, gckt.percent_identity, gckt.evalue, 
        gckt.query_start, gckt.query_end, 
        gckt.subj_start, gckt.subj_end
        from (select g2.gene_oid gene_oid
          from gene g2
          where g2.taxon = ?
          and g2.obsolete_flag = 'No'
          minus 
          select gkt.gene_oid
          from gene_ko_terms gkt, ko_term_enzymes kte
          where gkt.ko_terms = kte.ko_id) g3,
          gene g, gene_candidate_ko_terms gckt,
          ko_term_enzymes kte2, ko_term ko
        where g.gene_oid = g3.gene_oid
        and g.gene_oid = gckt.gene_oid
        and gckt.ko_terms = kte2.ko_id
        and gckt.ko_terms = ko.ko_id (+)
        order by 1 asc, 6 desc
    };
    #webLog("getSingleTaxonNoEnzymeWithKOGenesSql() sql: $sql\n");
    #print "getSingleTaxonNoEnzymeWithKOGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonNoEnzymeWithKOGenes {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = getSingleTaxonNoEnzymeWithKOGenesSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonKeggCategoryGenesSql {
    my ( $taxon_oid, $category, $cluster_id, $rclause, $imgClause) = @_;
    
    my @binds = ($taxon_oid);
    push( @binds, $cluster_id ) if ( $cluster_id );
    my $catClause;
    if ( $category eq "" || $category eq "Unknown" ) {
        $catClause = "and pw.category is null ";
    } else {
        $catClause = "and pw.category = ? ";
        push( @binds, $category );
    }

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    
    my $sql;
    if ( $cluster_id ne "" ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, 
                pw.image_id, pw.pathway_name
            from gene g, bio_cluster_features_new bcf, gene_ko_terms gk, 
                image_roi_ko_terms rk, image_roi roi, kegg_pathway pw
            where g.taxon = ?
            and g.gene_oid = bcf.gene_oid
            and bcf.cluster_id = ?
            and bcf.feature_type = 'gene'
            and bcf.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = roi.roi_id
            and roi.pathway = pw.pathway_oid
            $catClause
            $rclause
            $imgClause
            order by pw.pathway_name, bcf.gene_oid
        };
    }
    else {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, 
                pw.image_id, pw.pathway_name
            from gene g, gene_ko_terms gk, 
                image_roi_ko_terms rk, image_roi roi, kegg_pathway pw
            where g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            and g.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = roi.roi_id
            and roi.pathway = pw.pathway_oid
            $catClause
            $rclause
            $imgClause
            order by pw.pathway_name, g.gene_display_name
        };        
    }
    #webLog("getSingleTaxonKeggCategoryGenesSql() sql: $sql\n");
    #print "getSingleTaxonKeggCategoryGenesSql() sql: $sql<br/>\n";
    
    return ($sql, @binds);
}

sub fetchSingleTaxonKeggCategoryGenes {
    my ( $dbh, $taxon_oid, $category, $cluster_id, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonKeggCategoryGenesSql($taxon_oid, $category, $cluster_id, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonKeggPathwayGenesSql {
    my ( $rclause, $imgClause) = @_;
    
    my $sql = qq{
        select distinct g.gene_oid, pw.pathway_oid, pw.pathway_name
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.gene_oid = gk.gene_oid
        and gk.ko_terms = rk.ko_terms
        and rk.roi_id = roi.roi_id
        and roi.pathway = pw.pathway_oid
        and pw.pathway_oid = ?
        and pw.pathway_name is not null
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonKeggPathwayGenesSql() sql: $sql\n");
    #print "getSingleTaxonKeggPathwayGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonKeggPathwayGenes {
    my ( $dbh, $taxon_oid, $pathway_oid, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonKeggPathwayGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $pathway_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonNonKeggGenesSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.gene_oid not in( 
          select distinct g1.gene_oid
          from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt,
            gene_ko_enzymes ge, gene g1
          where pw.pathway_oid = roi.pathway
          and roi.roi_id = rk.roi_id
          and rk.ko_terms = kt.ko_id
          and kt.enzymes = ge.enzymes
          and ge.gene_oid = g1.gene_oid
          and g1.taxon = ?
        )
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonNonKeggGenesSql() sql: $sql\n");
    #print "getSingleTaxonNonKeggGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonNonKeggGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNonKeggGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonNonKoGenesSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.gene_oid not in( 
            select g1.gene_oid
            from gene g1, gene_ko_terms gkt
            where g1.taxon = ?
            and g1.gene_oid = gkt.gene_oid
        )
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonNonKoGenesSql() sql: $sql\n");
    #print "getSingleTaxonNonKoGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonNonKoGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNonKeggGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonNonMetacycGenesSql {
    my ( $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            $rclause
            $imgClause
        minus 
        select distinct g0.gene_oid
        from gene_biocyc_rxns g0
        where g0.taxon =  ?
    };
    #webLog("getSingleTaxonNonMetacycGenesSql() sql: $sql\n");
    #print "getSingleTaxonNonMetacycGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonNonMetacycGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonNonMetacycGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonCKogCatGenesSql {
    my ( $taxon_oid, $function_code, $og, $rclause, $imgClause) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, c.${og}_id, c.${og}_name
        from gene g, gene_${og}_groups gcg, $og c,
           ${og}_functions cfs, ${og}_function cf
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.gene_oid = gcg.gene_oid
        and g.taxon = gcg.taxon
        and gcg.$og = c.${og}_id
        and c.${og}_name is not null
        and c.${og}_id = cfs.${og}_id
        and cfs.functions = cf.function_code
        and cf.function_code = ?
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonCKogCatGenesSql() sql: $sql\n");
    #print "getSingleTaxonCKogCatGenesSql() sql: $sql<br/>\n";
    
    my @binds = ($taxon_oid, $function_code);
    
    return ($sql, @binds);
}

sub fetchSingleTaxonCKogCatGenes {
    my ( $dbh, $taxon_oid, $function_code, $og, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonCKogCatGenesSql($taxon_oid, $function_code, $og, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonPfamCatGenesSql {
    my ( $taxon_oid, $func_code, $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    
    my @binds = ($taxon_oid);
    my $clause;
    if ( $func_code && $func_code ne "_" ) {
        $clause = "and cf.function_code = ? ";
        push(@binds, $func_code);
    }
    else {
        $clause = "and cf.function_code is null";
    }

    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, gpf.pfam_family
        from gene g, gene_pfam_families gpf 
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession 
        left join cog_function cf on pfc.functions = cf.function_code
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.gene_oid = gpf.gene_oid
        and g.taxon = gpf.taxon
        $clause
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonPfamCatGenesSql() sql: $sql\n");
    #print "getSingleTaxonPfamCatGenesSql() sql: $sql<br/>\n";
    
    return ($sql, @binds);
}

sub fetchSingleTaxonPfamCatGenes {
    my ( $dbh, $taxon_oid, $function_code, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonPfamCatGenesSql($taxon_oid, $function_code, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonTIGRfamCatGenesSql {
    my ( $taxon_oid, $role, $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    my @binds = ($taxon_oid);
    my $clause;
    if ( $role && $role ne "_" ) {
        $clause = "and tr.main_role = ?";
        push( @binds, $role );
    }
    else {
        $clause = "and tr.main_role is null";
    }

    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, gtf.ext_accession
        from gene g, gene_tigrfams gtf 
        left join tigrfam_roles trs on gtf.ext_accession = trs.ext_accession
        left join tigr_role tr on trs.roles = tr.role_id
        where g.taxon = ?
        and g.taxon = gtf.taxon
        and g.gene_oid = gtf.gene_oid
        $clause
        $rclause
        $imgClause
    };    
    #webLog("getSingleTaxonTIGRfamCatGenesSql() sql: $sql\n");
    #print "getSingleTaxonTIGRfamCatGenesSql() sql: $sql<br/>\n";
    
    return ($sql, @binds);
}

sub fetchSingleTaxonTIGRfamCatGenes {
    my ( $dbh, $taxon_oid, $role, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonTIGRfamCatGenesSql($taxon_oid, $role, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonImgTermCatGenesSql {
    my ( $taxon_oid, $term_oid, $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    my @binds = ($taxon_oid);
    my $clause;
    if ( $term_oid && $term_oid ne "-1" ) {
        $clause = "and itc.term_oid = ?";
        push( @binds, $term_oid );
    }
    else {
        $clause = "and itc.term_oid is null";        
    }

    #my $sql = qq{
    #    select distinct g.gene_oid, g.locus_tag, g.gene_display_name, itc.term_oid
    #    from gene g, gene_img_functions gif,
    #        dt_img_term_path dtp, img_term it
    #    left join img_term_children itc on itc.child = it.term_oid
    #    left join img_term it2 on  itc.term_oid = it2.term_oid
    #    where g.taxon = ?
    #    and g.locus_type = 'CDS'
    #    and g.gene_oid = gif.gene_oid
    #    and gif.function = dtp.map_term
    #    and it.term_oid = dtp.term_oid
    #    $clause
    #    $rclause
    #    $imgClause
    #    order by g.gene_display_name
    #};
    my $sql = qq{   
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, itc.term_oid
        from gene g, gene_img_functions gif, img_term it 
        left join img_term_children itc on itc.child = it.term_oid
        left join img_term it2 on itc.term_oid = it2.term_oid
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
        $clause
        $rclause
        $imgClause
        order by g.gene_display_name
    };
    #webLog("getSingleTaxonImgTermCatGenesSql() sql: $sql\n");
    #print "getSingleTaxonImgTermCatGenesSql() sql: $sql<br/>\n";
    
    return ($sql, @binds);
}

sub fetchSingleTaxonImgTermCatGenes {
    my ( $dbh, $taxon_oid, $term_oid, $rclause, $imgClause) = @_;

    my ($sql, @binds) = getSingleTaxonImgTermCatGenesSql($taxon_oid, $term_oid, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getClusterGenesSql {
    my ( $funcIdsInClause, $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    my $sql = qq{
        select distinct g.gene_oid
        from paralog_group_genes pgg, gene g
        where pgg.group_oid in ($funcIdsInClause)
        and g.gene_oid = pgg.genes
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    #webLog("getClusterGenesSql() sql: $sql\n");
    #print "getClusterGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchClusterGenes {
    my ( $dbh, $ids_ref, $rclause, $imgClause) = @_;

    my $funcIdsInClause = OracleUtil::getNumberIdsInClause( $dbh, @$ids_ref );
    
    my $sql = getClusterGenesSql($funcIdsInClause, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $funcIdsInClause =~ /gtt_num_id/i );
    
    return (@gene_oids);
}

sub getSingleTaxonCassetteGenesSql {
    my ( $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    my $sql = qq{
        select distinct g.gene_oid
        from gene_cassette_genes gcg2, gene g
        where g.gene_oid = gcg2.gene
        and g.taxon = ?
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonCassetteGenesSql() sql: $sql\n");
    #print "getSingleTaxonCassetteGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonCassetteGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonCassetteGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonCassetteOccurrenceGenesSql {
    my ( $taxon_oid, $gene_count ) = @_;
    
    my $sql = qq{
        select distinct g.gene_oid
        from gene_cassette_genes gcg, gene g
        where g.taxon = ?
        and g.gene_oid = gcg.gene
        and gcg.cassette_oid in (       
            select gcg2.cassette_oid
            from gene_cassette_genes gcg2, gene g2
            where g2.taxon = ?
            and g2.gene_oid = gcg2.gene
            group by gcg2.cassette_oid
            having count(gcg2.gene) = ?
        )
    };
    my @binds = ( $taxon_oid, $taxon_oid, $gene_count );

    #webLog("getSingleTaxonCassetteOccurrenceGenesSql() sql: $sql\n");
    #print "getSingleTaxonCassetteOccurrenceGenesSql() sql: $sql<br/>\n";
    
    return ($sql, @binds);
}

sub fetchSingleTaxonCassetteOccurrenceGenes {
    my ( $dbh, $taxon_oid, $gene_count ) = @_;

    my ($sql, @binds) = getSingleTaxonCassetteOccurrenceGenesSql($taxon_oid, $gene_count);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonFusedGenesSql {
    my ( $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    #my $sql = qq{
    #    select g.gene_oid,  ge.enzymes
    #    from gene g, gene_fusion_components gfc, gene_ko_enzymes ge
    #    where g.gene_oid = gfc.gene_oid
    #    and g.obsolete_flag = 'No'
    #    and g.taxon = ?
    #    and g.gene_oid = ge.gene_oid
    #    $rclause
    #    $imgClause
    #    order by g.gene_oid
    #};
    #my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    #my %geneOid2Enzymes;
    #my %doneGeneOidEc;
    #for ( ; ; ) {
    #    my ( $gene_oid, $enzymes ) = $cur->fetchrow();
    #    last if !$gene_oid;
    #    next if $doneGeneOidEc{"$gene_oid-$enzymes"};
    #    $geneOid2Enzymes{$gene_oid} .= "$enzymes, ";
    #    $doneGeneOidEc{"$gene_oid-$enzymes"} = 1;
    #}
    #$cur->finish();

    my $sql = qq{
        select g.gene_oid, g.gene_display_name,
           count( gfc.component )
        from gene g, gene_fusion_components gfc
        where g.gene_oid = gfc.gene_oid
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        $rclause
        $imgClause
        group by g.gene_oid, g.gene_display_name
        order by g.gene_oid, g.gene_display_name
    };
    #webLog("getSingleTaxonFusedGenesSql() sql: $sql\n");
    #print "getSingleTaxonFusedGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonFusedGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonFusedGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonSignalGenesSql {
    my ( $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }

    my $sql = qq{
        select distinct g.gene_oid
        from gene g, gene_sig_peptides gsp
        where g.gene_oid = gsp.gene_oid
        and g.obsolete_flag = 'No'
        and g.locus_type = 'CDS'
        and g.taxon = ?
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonSignalGenesSql() sql: $sql\n");
    #print "getSingleTaxonSignalGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonSignalGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonSignalGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonTransmembraneGenesSql {
    my ( $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, gene_tmhmm_hits gth
        where g.taxon = ?
        and g.obsolete_flag = 'No'
        and g.locus_type = 'CDS'
        and g.gene_oid = gth.gene_oid
        and gth.feature_type = 'TMhelix'
        $rclause
        $imgClause
        order by g.gene_oid
    };
    #webLog("getSingleTaxonTransmembraneGenesSql() sql: $sql\n");
    #print "getSingleTaxonTransmembraneGenesSql() sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchSingleTaxonTransmembraneGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleTaxonTransmembraneGenesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

sub getSingleTaxonBiosyntheticGenesSqls {
    my ( $taxon_oid, $rclause, $imgClause ) = @_;
    
    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    }
    my $sql = qq{
        select distinct bcf.feature_id
        from bio_cluster_features_new bcf, bio_cluster_new g
        where bcf.feature_type = 'gene'
        and bcf.cluster_id = g.cluster_id
        and g.taxon = $taxon_oid
        $rclause
        $imgClause
    };
    my $extrasql = qq{
        select distinct bcf.feature_id, bcf.cluster_id
        from bio_cluster_features_new bcf, bio_cluster_new g
        where bcf.feature_type = 'gene'
        and bcf.cluster_id = g.cluster_id
        and g.taxon = $taxon_oid
        $rclause
        $imgClause
    };
    #webLog("getSingleTaxonBiosyntheticGenesSql() sql: $sql\n");
    #print "getSingleTaxonBiosyntheticGenesSql() sql: $sql<br/>\n";
    
    return ($sql, $extrasql);
}

sub fetchSingleTaxonBiosyntheticGenes {
    my ( $dbh, $taxon_oid, $rclause, $imgClause) = @_;

    my ($sql, $extrasql) = getSingleTaxonBiosyntheticGenesSqls($taxon_oid, $rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid, @junk) = $cur->fetchrow();
        last if ( !$gene_oid );
        push(@gene_oids, $gene_oid);
    }
    $cur->finish();
    
    return (@gene_oids);
}

# gets genome's scaffold count
sub getScaffoldCount {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select n_scaffolds
        from taxon_stats
        where taxon_oid = ?     
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    
    return $cnt;
}

sub getAllTaxonDataSql {
    my ( $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
	my $sql = qq{
	    select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name 
	    from taxon t 
	    where 1 = 1 
        $rclause
        $imgClause
    };	
    
    return $sql;
}

sub getAllTaxonDataAndFileTypeSql {
    my ( $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name, t.in_file, t.genome_type 
        from taxon t 
        where 1 = 1 
        $rclause
        $imgClause
    };  
    
    return $sql;
}

sub getTaxonDataSql {
    my ( $oid_list_str, $rclause, $imgClause ) = @_;

    $rclause = WebUtil::urClause('t') if ( ! $rclause );
    $imgClause = WebUtil::imgClause('t') if ( ! $imgClause );

    my $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name 
	    from taxon t 
	    where t.taxon_oid in ( $oid_list_str )
        $rclause 
        $imgClause
    };
        
    return $sql;
}


sub getGeneTaxonDataSql {
    my ( $oid_list_str, $rclause, $imgClause ) = @_;
	
    my $sql = qq{
       select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name 
	   from taxon t, gene g 
	   where t.taxon_oid = g.taxon
	   and g.gene_oid in ( $oid_list_str )
       $rclause 
       $imgClause
    };
    
    return $sql;
}

sub getScaffoldTaxonDataSql {
    my ( $oid_list_str, $rclause, $imgClause ) = @_;

    my $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name 
	    from taxon t, scaffold s 
	    where t.taxon_oid = s.taxon
	    and s.scaffold_oid in ( $oid_list_str )
        $rclause 
        $imgClause
    };
    
    return $sql;
}

sub executeTaxonDataSql {
    my ( $dbh, $sql, $taxon_name_h_ref) = @_;
    
    #print "sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid, $domain, $seq_status, $taxon_name) = $cur->fetchrow();
        last if ( !$taxon_oid );

        $domain = substr($domain, 0, 1);
        $seq_status = substr($seq_status, 0, 1);
        $taxon_name_h_ref->{$taxon_oid} = "$domain\t$seq_status\t$taxon_name";
        #print "taxon_name_h added with $taxon_oid<br/>\n";
    }
    $cur->finish();
}



############################################################################
# getSingleGeneNameAndTaxonSql
############################################################################
sub getSingleGeneNameAndTaxonSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    my $sql = qq{
        select g.gene_display_name, g.taxon 
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    };
    
    return ($sql);
}

sub fetchSingleGeneNameAndTaxon {
    my ( $dbh, $gene_oid, $hypotheticalName, $rclause, $imgClause) = @_;

    my $sql = getSingleGeneNameAndTaxonSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($gene_display_name, $taxon) = $cur->fetchrow();
    if ( !$gene_display_name && $hypotheticalName) {
	    $gene_display_name = $hypotheticalName;
    }
    $cur->finish();
    
    return ($gene_display_name, $taxon);
}

sub getSingleGeneNameAndLocusTagSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    my $sql = qq{
        select g.locus_tag, g.gene_display_name
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    };
    
    return ($sql);
}

sub fetchSingleGeneNameAndLocusTag {
    my ( $dbh, $gene_oid, $hypotheticalName, $rclause, $imgClause) = @_;

    my $sql = getSingleGeneNameAndLocusTagSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($locus_tag, $gene_display_name) = $cur->fetchrow();
    if ( !$gene_display_name && $hypotheticalName) {
	    $gene_display_name = $hypotheticalName;
    }
    $cur->finish();
    
    return ($locus_tag, $gene_display_name);
}

sub getSingleGeneNameLocusTypeAAseqSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    my $sql = qq{
        select g.locus_type, g.gene_display_name, g.aa_residue
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    };
    
    return ($sql);
}

sub fetchSingleGeneNameLocusTypeAAseq {
    my ( $dbh, $gene_oid, $rclause, $imgClause) = @_;

    my $sql = getSingleGeneNameLocusTypeAAseqSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($locus_type, $gene_display_name, $aa_residue) = $cur->fetchrow();
    $cur->finish();
    
    return ($locus_type, $gene_display_name, $aa_residue);
}


sub fetchSingleGeneTaxon {
    my ( $dbh, $gene_oid, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    my $sql = qq{ 
        select g.taxon 
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($taxon) = $cur->fetchrow();
    $cur->finish();
    
    return ($taxon );
}

sub fetchSingleGeneInfo {
    my ( $dbh, $gene_oid, $rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('g.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');        
    }
    my $sql = qq{
        select g.gene_oid, g.locus_type, g.locus_tag, g.gene_display_name,
             g.start_coord, g.end_coord, g.strand, g.scaffold, g.taxon
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($gene_oid2, $locus_type, $locus_tag, $gene_name, 
        $start_coord, $end_coord, $strand, $scaffold, $taxon)
        = $cur->fetchrow();
    $cur->finish();
    
    return ($gene_oid2, $locus_type, $locus_tag, $gene_name, $start_coord, $end_coord, $strand, $scaffold, $taxon);
}

############################################################################
# fetchGeneNames
############################################################################
sub fetchGeneNames {
    my ( $dbh, @oids ) = @_;

    my %oid2name_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil::fetchGeneNames() oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
            select distinct g.gene_oid, g.gene_display_name
            from gene g
            where g.obsolete_flag = 'No'
            and g.gene_oid in ($oid_str)
            $rclause
            $imgClause
        };
    
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id, $name) = $cur->fetchrow();
            last if ( !$id );
            $oid2name_h{$id} = $name;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil::fetchGeneNames() oid2name_h size:".(keys(%oid2name_h))."<br/>\n";
    }

    return %oid2name_h;
}

############################################################################
# fetchTaxonOid2GeneCntHash
############################################################################
sub fetchTaxonOid2GeneCntHash {
    my ( $dbh, $taxon_oids_ref) = @_;

    my %gene_cnt_h;

    my @oids = getIntOid(@$taxon_oids_ref);
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchTaxonOid2GeneCntHash oids size:".@oids."<br/>\n";
        
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        my $sql = getTaxonOidGeneCntSql($oid_str);
         
        my $cur = execSql( $dbh, $sql, $verbose);
        for ( ; ; ) {
            my ( $taxon_oid, $gene_cnt ) = $cur->fetchrow();
            last if !$taxon_oid;
            $gene_cnt_h{$taxon_oid} = $gene_cnt;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
        
        #print "QueryUtil fetchTaxonOid2GeneCntHash gene_cnt_h size:".(keys(%gene_cnt_h))."<br/>\n";
    }

    return %gene_cnt_h;
}

sub getTaxonOidGeneCntSql {
    my ($taxon_oid_str) = @_;

    my $sql    = qq{
        select t.taxon_oid, t.total_gene_count
        from taxon_stats t
        where t.taxon_oid in ($taxon_oid_str)
    };
    
    return $sql;
}

#############################################################################
## fetchSingleTaxonScaffolds
#############################################################################
sub fetchSingleTaxonScaffolds {
    my ( $dbh, $taxon_oid ) = @_;

    my %hash;
    my $sql = QueryUtil::getSingleTaxonScaffoldSql(); 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $ext_accession ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $hash{$scaffold_oid} = $ext_accession;
        #print "scaffold_oid: $scaffold_oid, ext_accession: $ext_accession<br/>\n"
    }
    $cur->finish();
    
    return \%hash;
}

#############################################################################
## getSingleTaxonScaffoldSql
#############################################################################
sub getSingleTaxonScaffoldSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('s.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    }
    my $sql = qq{
        select s.scaffold_oid, s.ext_accession
        from scaffold s
        where s.taxon = ?
        $rclause
        $imgClause
    };
    #print "getSingleTaxonScaffoldSql sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleScaffoldTaxonSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('s.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    }
    my $sql = qq{
    	select s.taxon, s.ext_accession
    	from scaffold s
    	where s.scaffold_oid = ?
        $rclause
        $imgClause
    };
    #print "getSingleScaffoldTaxonSql sql: $sql<br/>\n";
    
    return $sql;
}

#############################################################################
## fetchScaffoldNameHash
#############################################################################
sub fetchScaffoldNameHash {
    my ( $dbh, @oids ) = @_;

    my %oid2name_h;
    
    if (scalar(@oids) > 0) {
        #print "fetchScaffoldNameHash() oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $sql = qq{
            select s.scaffold_oid, s.scaffold_name 
            from scaffold s
            where s.scaffold_oid in ( $oid_str )
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id, $name) = $cur->fetchrow();
            last if ( !$id );
            $oid2name_h{$id} = $name;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "fetchScaffoldNameHash() oid2name_h size:".(keys %oid2name_h)."<br/>\n";
    }

    return %oid2name_h;
}

sub getSingleScaffoldNameOnlySql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('s.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    }
    my $sql = qq{
    	select s.scaffold_name 
    	from scaffold s
    	where s.scaffold_oid = ?
        $rclause
        $imgClause
	};
    #print "getSingleScaffoldNameOnlySql sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleScaffoldNameSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('s.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    }
    my $sql = qq{
    	select s.scaffold_oid, s.scaffold_name, s.ext_accession
    	from scaffold s
    	where s.scaffold_oid = ?
        $rclause
        $imgClause
	};
    #print "getSingleScaffoldNameSql sql: $sql<br/>\n";
    
    return $sql;
}

sub getSingleScaffoldExtSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('s.taxon');
        $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    }
    my $sql = qq{
    	select s.scaffold_oid, s.ext_accession
    	from scaffold s
    	where s.scaffold_oid = ?
        $rclause
        $imgClause
	};
    #print "getSingleScaffoldExtSql sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchValidTaxonOidHash {
    my ( $dbh, @oids) = @_;

    my %oid_h;
    
    @oids = getIntOid(@oids);
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchValidTaxonOidHash oids size:".@oids."<br/>\n";

        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
 
        my $rclause = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
        my $sql = qq{
            select distinct t.taxon_oid
            from taxon t
            where t.taxon_oid in ($oid_str)
            $rclause
            $imgClause
        };
            
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if ( !$oid );
            $oid_h{$oid} = 1;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil fetchValidTaxonOidHash oid_h size:".(keys(%oid_h))."<br/>\n";        
    }

    return %oid_h;
}

sub fetchGeneGenomeOidsHash {
    my ( $dbh, @oids ) = @_;

    my %oid_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchGeneGenomeOidsHash oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
            select distinct g.taxon
            from gene g
            where g.obsolete_flag = 'No'
            and g.gene_oid in ($oid_str)
            $rclause
            $imgClause
        };
    
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id) = $cur->fetchrow();
            last if ( !$id );
            $oid_h{$id} = 1;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil fetchGeneGenomeOidsHash oid_h size:".(keys(%oid_h))."<br/>\n";
    }

    return %oid_h;
}

sub fetchScaffoldGenomeOidsHash {
    my ( $dbh, @oids ) = @_;

    my %oid_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchScaffoldGenomeOidsHash oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $sql = qq{
            select distinct s.taxon
            from scaffold s 
            where s.scaffold_oid in ( $oid_str )
            $rclause 
            $imgClause
        };
    
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id) = $cur->fetchrow();
            last if ( !$id );
            $oid_h{$id} = 1;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil fetchScaffoldGenomeOidsHash oid_h size:".(keys(%oid_h))."<br/>\n";
    }

    return %oid_h;
}


sub fetchGeneScaffoldOidsHash {
    my ( $dbh, @oids ) = @_;

    my %oid_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchGeneScaffoldOidsHash oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
            select distinct g.scaffold
            from gene g
            where g.obsolete_flag = 'No'
            and g.gene_oid in ($oid_str)
            $rclause
            $imgClause
        };
    
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id) = $cur->fetchrow();
            last if ( !$id );
            $oid_h{$id} = 1;
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil fetchGeneScaffoldOidsHash oid_h size:".(keys(%oid_h))."<br/>\n";        
    }

    return %oid_h;
}

sub fetchGenomeScaffoldOidsHash {
    my ( $dbh, @oids ) = @_;

    my %oid_h;
    my %oid2name_h;
    my %taxon_oid_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchGenomeScaffoldOidsHash oids size:".@oids."<br/>\n";
    
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );

        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $sql = qq{
            select distinct s.taxon, s.scaffold_oid, s.scaffold_name
            from scaffold s 
            where s.taxon in ( $oid_str )
            $rclause 
            $imgClause
        };
        
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($taxon, $id, $name) = $cur->fetchrow();
            last if ( !$taxon );
            $oid_h{$id} = 1;
            $oid2name_h{$id} = $name;
            
            my $oids_ref = $taxon_oid_h{$taxon};
            if ( $oids_ref && scalar(@$oids_ref) > 0 ) {
                push( @$oids_ref, $id );
            }
            else {
                my @ids = ( $id );
                $taxon_oid_h{$taxon} = \@ids;
            }
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    
        #print "QueryUtil fetchGenomeScaffoldOidsHash oid_h size:".(keys(%oid_h))."<br/>\n";        
        #print "QueryUtil fetchGenomeScaffoldOidsHash taxon_oid_h size:".(keys(%taxon_oid_h))."<br/>\n";        
    }

    return (\%oid_h, \%oid2name_h, \%taxon_oid_h);
}

sub fetchScaffoldGeneOidsHash {
    my ( $dbh, @oids ) = @_;

    my %oid_h;
    
    if (scalar(@oids) > 0) {
        #print "QueryUtil fetchScaffoldGeneOidsHash oids size:".@oids."<br/>\n";
        
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');    
        my $sql       = qq{
    	    select distinct g.gene_oid
    	    from gene g
    	    where g.obsolete_flag = 'No'
    	    and g.scaffold in ($oid_str)
            $rclause
            $imgClause
    	};
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ($id) = $cur->fetchrow();
            last if ( !$id );
            $oid_h{$id} = 1;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
        
        #print "QueryUtil fetchScaffoldGeneOidsHash oid_h size:".(keys(%oid_h))."<br/>\n";
    }

    return %oid_h;
}

sub fetchValidGeneOids {
    my ( $dbh, @oids) = @_;

    my @good_oids;

    if ( scalar(@oids) > 0 ) {
        #print "QueryUtil fetchValidGeneOids oids size:".@oids."<br/>\n";

        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
         
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql     = qq{
            select distinct g.gene_oid
            from gene g
            where g.gene_oid in ($oid_str)
            $rclause
            $imgClause
        };
    
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @good_oids, $oid );
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
        
        #print "QueryUtil fetchValidGeneOids good_oids size:".@good_oids."<br/>\n";
    }

    return @good_oids;
}

sub fetchValidScaffoldOids {
    my ( $dbh, @oids) = @_;

    my @good_oids;

    if ( scalar(@oids) > 0 ) {
        #print "QueryUtil fetchValidScaffoldOids oids size:".@oids."<br/>\n";

        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
             
        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $sql     = qq{
            select distinct s.scaffold_oid
            from scaffold s
            where s.scaffold_oid in ($oid_str)
            $rclause
            $imgClause           
        };
    
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @good_oids, $oid );
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
                    
        #print "QueryUtil fetchValidScaffoldOids size:".@good_oids."<br/>\n";
    }

    return @good_oids;
}

sub getContactTaxonPermissionSql {

    my $sql = qq{
        select distinct ctp.taxon_permissions
		from contact_taxon_permissions ctp
		where ctp.contact_oid = ? 
		order by ctp.taxon_permissions
    };
    #print "getContactTaxonPermissionSql sql: $sql<br/>\n";
    
    return $sql;
}

sub fetchGoIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct go_id, go_term 
            from go_term 
            where go_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchGoIdNameHash() go added $id<br/>\n";
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidGoIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct go_id
            from go_term 
            where go_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidGoIds() go added $id<br/>\n";
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchAllCogIdNameHash {
    my ( $dbh, $id_name_href) = @_;
    
    my $sql = qq{
        select distinct cog_id, cog_name 
        from cog
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
		my ( $id, $name ) = $cur->fetchrow(); 
		last if !$id; 
		$id_name_href->{$id} = $name; 
        #print "fetchAllCogIdNameHash() cog added $id $name<br/>\n";
    }
    $cur->finish();
}

sub fetchCogIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct cog_id, cog_name 
            from cog 
            where cog_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchCogIdNameHash() cog added $id<br/>\n";
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidCogIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct cog_id
            from cog 
            where cog_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidCogIds() cog added $id<br/>\n";
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchKogIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct kog_id, kog_name 
            from kog 
            where kog_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchKogIdNameHash() kog added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidKogIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct kog_id
            from kog 
            where kog_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidKogIds() kog added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchAllPfamIdNameHash {
    my ( $dbh, $id_name_href) = @_;

    my $sql = qq{
        select distinct ext_accession, description 
        from pfam_family
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
		my ( $id, $name ) = $cur->fetchrow(); 
		last if !$id; 
		$id_name_href->{$id} = $name; 
        #print "fetchAllPfamIdNameHash() pfam added $id<br/>\n";
    }
    $cur->finish();
}

sub fetchPfamIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession, description 
            from pfam_family 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchPfamIdNameHash() pfam added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidPfamIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession
            from pfam_family 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidPfamIds() pfam added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchAllTigrfamIdNameHash {
    my ( $dbh, $id_name_href) = @_;

    my $sql = qq{
        select distinct ext_accession, expanded_name 
        from tigrfam
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
		my ( $id, $name ) = $cur->fetchrow(); 
		last if !$id; 
		$id_name_href->{$id} = $name; 
        #print "fetchAllTigrfamIdNameHash() tigrfam added $id<br/>\n";
    }
    $cur->finish();
}

sub fetchTigrfamIdNameHash {
    my ( $dbh, $id_name_h_ref, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession, expanded_name 
            from tigrfam 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_h_ref->{$id} = $name; 
            #print "fetchTigrfamIdNameHash() tigrfam added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidTigrfamIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession
            from tigrfam 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidTigrfamIds() tigrfam added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchAllEnzymeNumberNameHash {
    my ( $dbh, $id_name_href) = @_;

    my $sql = qq{
        select distinct ec_number, enzyme_name 
        from enzyme
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
		my ( $id, $name ) = $cur->fetchrow(); 
		last if !$id; 
		$id_name_href->{$id} = $name; 
        #print "fetchAllEnzymeNumberNameHash() ec added $id<br/>\n";
    }
    $cur->finish();

}

sub fetchEnzymeNumberNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ec_number, enzyme_name 
            from enzyme 
            where ec_number in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchEnzymeNumberNameHash() ec added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidEnzymeNumbers {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ec_number
            from enzyme 
            where ec_number in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidEnzymeNumber() ec added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchAllKoIdNameDefHash {
    my ( $dbh, $id_name_href, $id_def_href) = @_;

    my $sql = qq{
        select distinct ko_id, ko_name, definition 
        from ko_term
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
		my ( $id, $name, $def ) = $cur->fetchrow(); 
		last if !$id; 

        if ( $id_def_href eq '') {
            if ( ! $name ) {
                $id_name_href->{$id} = $def; 
            }
            elsif ( $def ) {
                $id_name_href->{$id} = $def . " ($name)";
            }
            else {
                $id_name_href->{$id} = $name; 
            }            
        }
        else {
            $id_name_href->{$id} = $name; 
            $id_def_href->{$id} = $def;             
        }
    }
    $cur->finish();

}

sub fetchKoIdNameDefHash {
    my ( $dbh, $id_name_href, $id_def_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ko_id, ko_name, definition 
            from ko_term 
            where ko_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name, $def ) = $cur->fetchrow(); 
            last if !$id; 
    
            if ( $id_def_href eq '') {
                if ( ! $name ) {
                    $id_name_href->{$id} = $def; 
                }
                elsif ( $def ) {
                    $id_name_href->{$id} = $def . " ($name)";
                }
                else {
                    $id_name_href->{$id} = $name; 
                }            
            }
            else {
                $id_name_href->{$id} = $name; 
                $id_def_href->{$id} = $def;             
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }

}

sub fetchAllKoIdDefHash {
    my ( $dbh, $id_def_href) = @_;

    my $sql = qq{
        select distinct ko_id, definition 
        from ko_term
    };
    my $cur = execSql( $dbh, $sql, $verbose); 
    for ( ; ; ) { 
        my ( $id, $def ) = $cur->fetchrow(); 
        last if !$id; 
        $id_def_href->{$id} = $def;             
    }
    $cur->finish();

}

sub fetchKoIdDefHash {
    my ( $dbh, $id_def_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ko_id, definition 
            from ko_term 
            where ko_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $def ) = $cur->fetchrow(); 
            last if !$id;
            $id_def_href->{$id} = $def;             
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }

}

sub fetchValidKoIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ko_id
            from ko_term 
            where ko_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }

}

sub fetchInterproIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession, name 
            from interpro 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchInterproIdNameHash() ipr added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidInterproIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct ext_accession
            from interpro 
            where ext_accession in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidInterproIds() ipr added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchTcIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct tc_family_num, tc_family_name 
            from tc_family 
            where tc_family_num in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchTcIdNameHash() tc added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchValidTcIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct tc_family_num
            from tc_family 
            where tc_family_num in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidTcIds() tc added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchBioClusterIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchBioClusterIdNameHash() bc ids = @ids<br/>\n";
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );

        my $sql = qq{
            select distinct cluster_id, NULL
            from bio_cluster_new
            where cluster_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = ''; 
            #print "fetchBioClusterIdNameHash() bc added with $id =<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
    
}

sub fetchValidBioClusterIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchValidBioClusterIds() bc ids = @ids<br/>\n";
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );

        my $sql = qq{
            select distinct cluster_id
            from bio_cluster_features_new
            where cluster_id in ( $ids_str )
            and cluster_id = 'gene'
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidBioClusterIds() BC added with $id = 1<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
    
}

sub fetchNaturalProductIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchNaturalProductIdNameHash() SM ids = @ids<br/>\n";
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );

        my $sql = qq{
            select distinct np.np_id, np.np_product_name 
            from natural_product np
            where np.np_id in ( $ids_str )
        }; 
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchNaturalProductIdNameHash() SM added with $id = $name<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidNaturalProductIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchValidNaturalProductIds() SM ids = @ids<br/>\n";
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );

        my $sql = qq{
            select distinct np.np_id
            from natural_product np
            where np.np_id in ( $ids_str )
        }; 
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidNaturalProductIds() SM added with $id = 1<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchMetacycIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct unique_id, common_name 
            from biocyc_pathway 
            where unique_id in ( $ids_str )
            union
            select distinct unique_id, common_name 
            from biocyc_comp 
            where unique_id in ( $ids_str )
        };
        #print "fetchMetacycIdNameHash() sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchMetacycIdNameHash() metacyc added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchMetaCyc2Ec {
    my ( $dbh, $metacyc_id ) = @_;

    my @ec_ids;
    
    # get MetaCyc enzymes
    my $sql2 = qq{
        select distinct br.ec_number
        from biocyc_reaction_in_pwys brp, biocyc_reaction br
        where brp.unique_id = br.unique_id
        and brp.in_pwys = ?
        and br.ec_number is not null
    }; 
    my $cur2 = execSql( $dbh, $sql2, $verbose, $metacyc_id );
    for ( ; ; ) {
        my ($ec_id) = $cur2->fetchrow();
        last if !$ec_id;
        push(@ec_ids, $ec_id);
    } 
    $cur2->finish();
    
    return @ec_ids;
}

sub fetchMetaCyc2EcHash {
    my ( $dbh, $metacyc_ids_ref ) = @_;

    my %metacyc2ec_h;
    my %ec2metacyc_h;
    if (scalar(@$metacyc_ids_ref) > 0) {

        #needed
        my @mcyc_ids;
        for my $func_id (@$metacyc_ids_ref) {
            if ( $func_id =~ /MetaCyc/i ) {
                my ( $id1, $id2 ) = split( /\:/, $func_id );
                push( @mcyc_ids, $id2 );
                #print "fetchMetaCyc2EcHash() func_id=$func_id, id1=$id1, id2=$id2<br/>\n";                
            }
            else {
                push( @mcyc_ids, $func_id );                
            }
        }

        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @mcyc_ids );

        my $sql= qq{
            select distinct brp.in_pwys, br.ec_number
            from biocyc_reaction br, biocyc_reaction_in_pwys brp
            where brp.unique_id = br.unique_id
            and brp.in_pwys in ($ids_str)
            and br.ec_number is not null
        };
        #print "fetchMetaCyc2EcHash() sql: $sql<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($mcyc_id, $ec_id) = $cur->fetchrow();
            last if !$mcyc_id;
            next if !$ec_id;

            my $metacyc_id = "MetaCyc:$mcyc_id";

            my $ec_ref = $metacyc2ec_h{$metacyc_id};
            if ( $ec_ref ) {
                if ( ! WebUtil::inArray($ec_id, @$ec_ref) ) {
                    push(@$ec_ref, $ec_id);                    
                }
            }
            else {
                my @ec_ids;
                push(@ec_ids, $ec_id);
                $metacyc2ec_h{$metacyc_id} = \@ec_ids;
            }
            
            my $metacyc_ref = $ec2metacyc_h{$ec_id};
            if ( $metacyc_ref ) {
                if ( ! WebUtil::inArray($metacyc_id, @$metacyc_ref) ) {
                    push(@$metacyc_ref, $metacyc_id);
                }
            }
            else {
                my @metacyc_ids;
                push(@metacyc_ids, $metacyc_id);
                $ec2metacyc_h{$ec_id} = \@metacyc_ids;
            }
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }    

    return (\%metacyc2ec_h, \%ec2metacyc_h);
}

sub fetchValidMetacycIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct unique_id
            from biocyc_pathway 
            where unique_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidMetacycIds() metacyc added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
            if ( $ids_str =~ /gtt_func_id/i );        
    }
}

sub fetchImgTermIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct term_oid, term 
            from img_term 
            where term_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchImgTermIdNameHash() iterm added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidImgTermIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct term_oid
            from img_term 
            where term_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidImgTermIds() iterm added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchImgPathwayIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct pathway_oid, pathway_name 
            from img_pathway 
            where pathway_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchImgPathwayIdNameHash() ipway added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidImgPathwayIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct pathway_oid
            from img_pathway 
            where pathway_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidImgPathwayIds() ipway added $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchImgPartsListIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct parts_list_oid, parts_list_name 
            from img_parts_list 
            where parts_list_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchImgPartsListIdNameHash() plist added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidImgPartsListIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct parts_list_oid
            from img_parts_list 
            where parts_list_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidImgPartsListIds() plist added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchPathwayNetworkIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct network_oid, network_name 
            from pathway_network 
            where network_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchPathwayNetworkIdNameHash() netwk added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidPathwayNetworkIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct network_oid
            from pathway_network 
            where network_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidPathwayNetworkIds() netwk added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchImgCompoundIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchImgCompoundIdNameHash() icmpd ids=@ids<br/>\n";
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct COMPOUND_oid, COMPOUND_name 
            from IMG_COMPOUND 
            where COMPOUND_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchImgCompoundIdNameHash() icmpd added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidImgCompoundIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        #print "fetchValidImgCompoundId() icmpd ids=@ids<br/>\n";
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct COMPOUND_oid
            from IMG_COMPOUND 
            where COMPOUND_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidImgCompoundIds() icmpd added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchImgReactionIdNameDefHash {
    my ( $dbh, $id_name_href, $id_def_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct rxn_oid, rxn_name, rxn_definition 
            from IMG_REACTION 
            where rxn_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id, $name, $def ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name;    
            if ( $id_def_href ne '' ) {
                $id_def_href->{$id} = $def;             
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidImgReactionIds {
    my ( $dbh, $ids_href, $id_def_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct rxn_oid
            from IMG_REACTION 
            where rxn_oid in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1;    
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchPhenotypeRuleIdNameHash {
    my ( $dbh, $id_name_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct rule_id, name 
            from PHENOTYPE_RULE 
            where rule_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id, $name ) = $cur->fetchrow(); 
            last if !$id; 
            $id_name_href->{$id} = $name; 
            #print "fetchPhenotypeRuleIdNameHash() prule added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}

sub fetchValidPhenotypeRuleIds {
    my ( $dbh, $ids_href, @ids) = @_;

    if (scalar(@ids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @ids );
        
        my $sql = qq{
            select distinct rule_id
            from PHENOTYPE_RULE 
            where rule_id in ( $ids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) {
            my ( $id ) = $cur->fetchrow(); 
            last if !$id; 
            $ids_href->{$id} = 1; 
            #print "fetchValidPhenotypeRuleIds() prule added with $id<br/>\n";
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
}


sub fetchFuncIdAndName {
    my ($dbh, $func_ids_ref) = @_;

    #print "fetchFuncIdAndName() func_ids: @$func_ids_ref<br/>\n";
    
    my (
        $go_ids_ref,      $cog_ids_ref,     $kog_ids_ref,    $pfam_ids_ref,    
        $tigr_ids_ref,    $ec_ids_ref,      $ko_ids_ref,     $ipr_ids_ref,
        $tc_fam_nums_ref, $bc_ids_ref,      $np_ids_ref,     $metacyc_ids_ref, 
        $iterm_ids_ref,   $ipway_ids_ref,   $plist_ids_ref,  $netwk_ids_ref,   
        $icmpd_ids_ref,   $irexn_ids_ref,
        $prule_ids_ref,   $unrecognized_ids_ref
      )
      = groupFuncIds($func_ids_ref);

    #print "fetchFuncIdAndName() iterm_ids: @$iterm_ids_ref<br/>\n";
    #print "fetchFuncIdAndName() icmpd_ids: @$icmpd_ids_ref<br/>\n";
    
    my %funcId2Name;
    if (scalar(@$go_ids_ref) > 0) {
        fetchGoIdNameHash( $dbh, \%funcId2Name, @$go_ids_ref );
    }
    if (scalar(@$cog_ids_ref) > 0) {
        fetchCogIdNameHash( $dbh, \%funcId2Name, @$cog_ids_ref );
    }
    if (scalar(@$kog_ids_ref) > 0) {
        fetchKogIdNameHash( $dbh, \%funcId2Name, @$kog_ids_ref );
    }
    if (scalar(@$pfam_ids_ref) > 0) {
        fetchPfamIdNameHash( $dbh, \%funcId2Name, @$pfam_ids_ref );
    }
    if (scalar(@$tigr_ids_ref) > 0) {
        fetchTigrfamIdNameHash( $dbh, \%funcId2Name, @$tigr_ids_ref );
    }
    if (scalar(@$ec_ids_ref) > 0) {
        fetchEnzymeNumberNameHash( $dbh, \%funcId2Name, @$ec_ids_ref );
    }
    if (scalar(@$ko_ids_ref) > 0) {
        fetchKoIdNameDefHash( $dbh, \%funcId2Name, '', @$ko_ids_ref );
    }
    if (scalar(@$ipr_ids_ref) > 0) {
        fetchInterproIdNameHash( $dbh, \%funcId2Name, @$ipr_ids_ref );
    }
    if (scalar(@$tc_fam_nums_ref) > 0) {
        fetchTcIdNameHash( $dbh, \%funcId2Name, @$tc_fam_nums_ref );
    }
    if (scalar(@$bc_ids_ref) > 0) {
        my %id_name_h;
        fetchBioClusterIdNameHash( $dbh, \%id_name_h, @$bc_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"BC:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$np_ids_ref) > 0) {
        my %id_name_h;
        fetchNaturalProductIdNameHash( $dbh, \%id_name_h, @$np_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"NP:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$metacyc_ids_ref) > 0) {
        my %id_name_h;
        fetchMetacycIdNameHash( $dbh, \%id_name_h, @$metacyc_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"MetaCyc:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$iterm_ids_ref) > 0) {
        my %id_name_h;
        fetchImgTermIdNameHash( $dbh, \%id_name_h, @$iterm_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"ITERM:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$ipway_ids_ref) > 0) {
        my %id_name_h;
        fetchImgPathwayIdNameHash( $dbh, \%id_name_h, @$ipway_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"IPWAY:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$plist_ids_ref) > 0) {
        my %id_name_h;
        fetchImgPartsListIdNameHash( $dbh, \%id_name_h, @$plist_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"PLIST:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$netwk_ids_ref) > 0) {
        my %id_name_h;
        fetchPathwayNetworkIdNameHash( $dbh, \%id_name_h, @$netwk_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"NETWK:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$icmpd_ids_ref) > 0) {
        my %id_name_h;
        fetchImgCompoundIdNameHash( $dbh, \%id_name_h, @$icmpd_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"ICMPD:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$irexn_ids_ref) > 0) {
        my %id_name_h;
        fetchImgReactionIdNameDefHash( $dbh, \%id_name_h, '', @$irexn_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"IREXN:$key"} = $id_name_h{$key}; 
        }
    }
    if (scalar(@$prule_ids_ref) > 0) {
        my %id_name_h;
        fetchPhenotypeRuleIdNameHash( $dbh, \%id_name_h, @$prule_ids_ref );
        for my $key (keys %id_name_h) {
            $funcId2Name{"PRULE:$key"} = $id_name_h{$key}; 
        }
    }
    #print "fetchFuncIdAndName() funcId2Name:<br/>\n";
    #print Dumper(\%funcId2Name)."<br/>\n";
        
    return (%funcId2Name);
}

sub fetchValidFuncIds {
    my ($dbh, @func_ids) = @_;

    #print "fetchValidFuncIds() func_ids: @func_ids<br/>\n";
    
    my (
        $go_ids_ref,      $cog_ids_ref,     $kog_ids_ref,    $pfam_ids_ref,    
        $tigr_ids_ref,    $ec_ids_ref,      $ko_ids_ref,     $ipr_ids_ref,
        $tc_fam_nums_ref, $bc_ids_ref,      $np_ids_ref,     $metacyc_ids_ref, 
        $iterm_ids_ref,   $ipway_ids_ref,   $plist_ids_ref,  $netwk_ids_ref,   
        $icmpd_ids_ref,   $irexn_ids_ref,
        $prule_ids_ref,   $unrecognized_ids_ref
      )
      = groupFuncIds(\@func_ids);

    #print "fetchValidFuncIds() icmpd_ids: @$icmpd_ids_ref<br/>\n";
    
    my %validFuncIds;
    if (scalar(@$go_ids_ref) > 0) {
        fetchValidGoIds( $dbh, \%validFuncIds, @$go_ids_ref );
    }
    if (scalar(@$cog_ids_ref) > 0) {
        fetchValidCogIds( $dbh, \%validFuncIds, @$cog_ids_ref );
    }
    if (scalar(@$kog_ids_ref) > 0) {
        fetchValidKogIds( $dbh, \%validFuncIds, @$kog_ids_ref );
    }
    if (scalar(@$pfam_ids_ref) > 0) {
        fetchValidPfamIds( $dbh, \%validFuncIds, @$pfam_ids_ref );
    }
    if (scalar(@$tigr_ids_ref) > 0) {
        fetchValidTigrfamIds( $dbh, \%validFuncIds, @$tigr_ids_ref );
    }
    if (scalar(@$ec_ids_ref) > 0) {
        fetchValidEnzymeNumbers( $dbh, \%validFuncIds, @$ec_ids_ref );
    }
    if (scalar(@$ko_ids_ref) > 0) {
        fetchValidKoIds( $dbh, \%validFuncIds, @$ko_ids_ref );
    }
    if (scalar(@$ipr_ids_ref) > 0) {
        fetchValidInterproIds( $dbh, \%validFuncIds, @$ipr_ids_ref );
    }
    if (scalar(@$tc_fam_nums_ref) > 0) {
        fetchValidTcIds( $dbh, \%validFuncIds, @$tc_fam_nums_ref );
    }
    if (scalar(@$bc_ids_ref) > 0) {
        my %ids_h;
        fetchValidBioClusterIds( $dbh, \%ids_h, @$bc_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"BC:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$np_ids_ref) > 0) {
        my %ids_h;
        fetchValidGoldNaturalProductIds( $dbh, \%ids_h, @$np_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"NP:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$metacyc_ids_ref) > 0) {
        my %ids_h;
        fetchValidMetacycIds( $dbh, \%ids_h, @$metacyc_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"MetaCyc:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$iterm_ids_ref) > 0) {
        my %ids_h;
        fetchValidImgTermIds( $dbh, \%ids_h, @$iterm_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"ITERM:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$ipway_ids_ref) > 0) {
        my %ids_h;
        fetchValidImgPathwayIds( $dbh, \%ids_h, @$ipway_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"IPWAY:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$plist_ids_ref) > 0) {
        my %ids_h;
        fetchValidImgPartsListIds( $dbh, \%ids_h, @$plist_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"PLIST:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$netwk_ids_ref) > 0) {
        my %ids_h;
        fetchValidPathwayNetworkIds( $dbh, \%ids_h, @$netwk_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"NETWK:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$icmpd_ids_ref) > 0) {
        my %ids_h;
        fetchValidImgCompoundIds( $dbh, \%ids_h, @$icmpd_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"ICMPD:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$irexn_ids_ref) > 0) {
        my %ids_h;
        fetchValidImgReactionIds( $dbh, \%ids_h, '', @$irexn_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"IREXN:$key"} = $ids_h{$key}; 
        }
    }
    if (scalar(@$prule_ids_ref) > 0) {
        my %ids_h;
        fetchValidPhenotypeRuleIds( $dbh, \%ids_h, @$prule_ids_ref );
        for my $key (keys %ids_h) {
            $validFuncIds{"PRULE:$key"} = $ids_h{$key}; 
        }
    }
        
    return (%validFuncIds);
}

sub getIntOid {
    my ( @oids) = @_;

    my @intOids;
    for my $oid (@oids) {
        next if ( $oid eq "" || !isInt($oid) );
        push(@intOids, $oid);
    }
    
    return @intOids;
}


##############################################################################
# getFuncTypeNames
##############################################################################
sub getFuncTypeNames {
    my ($dbh, $functype) = @_;

    my %func_names;

    my $sql;
    if ( $functype eq 'COG' ) {
        $sql = qq{
            select cog_id, cog_name 
            from cog 
        };
    } 
    elsif ( $functype eq 'COG_Category' ) {
        $sql = qq{
            select function_code, definition 
            from cog_function 
        };
    } 
    elsif ( $functype eq 'COG_Pathway' ) {
        $sql = qq{
            select cog_pathway_oid, cog_pathway_name 
            from cog_pathway 
        };
    } 
    elsif ( $functype eq 'KEGG_Category_EC'
        || $functype eq 'KEGG_Category_KO' )
    {
        $sql = qq{
            select min(pathway_oid), category 
            from kegg_pathway where category is not null 
            group by category 
        };
    } 
    elsif ( $functype eq 'KEGG_Pathway_EC'
        || $functype eq 'KEGG_Pathway_KO' )
    {
        $sql = qq{
            select pathway_oid, pathway_name 
            from kegg_pathway 
        };
    } 
    elsif ( lc($functype) eq 'metacyc' ) {
        $sql = qq{
            select unique_id, common_name 
            from biocyc_pathway 
        };
    } 
    elsif ( $functype eq 'Pfam' ) {
        $sql = qq{
            select ext_accession, description 
            from pfam_family 
        };
    } 
    elsif ( $functype eq 'Pfam_Category' ) {
        $sql = qq{
            select distinct cf.function_code, cf.definition 
            from cog_function cf, pfam_family_cogs pfc 
            where cf.function_code = pfc.functions 
        };
    } 
    elsif ( $functype eq 'TIGRfam' ) {
        $sql = qq{
            select ext_accession, expanded_name 
            from tigrfam 
        };
    } 
    elsif ( $functype eq 'TIGRfam_Role' ) {
        $sql = qq{
            select distinct t.role_id, t.main_role || ': ' || t.sub_role 
            from tigr_role t 
            where t.main_role is not null and t.sub_role != 'Other' 
        };
    } 
    elsif ( $functype eq 'KO' ) {
        $sql = qq{
            select ko_id, ko_name, definition 
            from ko_term 
        };
    } 
    elsif ( $functype eq 'Enzymes' ) {
        $sql = qq{
            select ec_number, enzyme_name 
            from enzyme
        };
    }
    if ($sql) {
        my $cur2 = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $func_id, $name1, $name2 ) = $cur2->fetchrow();
            last if ( !$func_id );
            my $func_name = $name1;
            if ( $functype eq 'KO' ) {
                if ( !$name1 ) {
                    $func_name = $name2;
                } elsif ($name2) {
                    $func_name = "$name2 ($name1)";
                }
            }
            $func_names{$func_id} = $func_name;
        }
        $cur2->finish();
    }

    return %func_names;
}

############################################################################
# getFunc2Category
# get func_id to category mapping
############################################################################
sub getFunc2Category {
    my ( $dbh, $functype ) = @_;

    my %funcId_category_h;

    my $sql;
    if ( $functype eq 'COG_Category' ) {
        $sql = qq{
            select cog_id, functions 
            from cog_functions
        };
    } 
    elsif ( $functype eq 'COG_Pathway' ) {
        $sql = qq{
            select cog_members, cog_pathway_oid 
            from cog_pathway_cog_members 
        };
    } 
    elsif ( $functype eq 'KEGG_Category_EC' ) {
        $sql = qq{
            select distinct kt.enzymes, kp3.min_pid
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp, 
                (select kp2.category category, min(kp2.pathway_oid) min_pid
                from kegg_pathway kp2
                where kp2.category is not null
                group by kp2.category) kp3
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            and kp.category = kp3.category
            and kp.category is not null
        };
    } 
    elsif ( $functype eq 'KEGG_Category_KO' ) {
        $sql = qq{
            select distinct rk.ko_terms, kp3.min_pid
            from kegg_pathway kp, image_roi_ko_terms rk, image_roi ir,
                (select kp2.category category, min(kp2.pathway_oid) min_pid
                from kegg_pathway kp2
                where kp2.category is not null 
                group by kp2.category) kp3
            where rk.roi_id = ir.roi_id and kp.pathway_oid = ir.pathway
            and kp.category is not null
            and kp.category = kp3.category
        };
    } 
    elsif ( $functype eq 'KEGG_Pathway_EC' ) {
        $sql = qq{
            select distinct kt.enzymes, ir.pathway
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
        };
    } 
    elsif ( $functype eq 'KEGG_Pathway_KO' ) {
        $sql = qq{
            select distinct rk.ko_terms, ir.pathway
            from image_roi_ko_terms rk, image_roi ir
            where rk.roi_id = ir.roi_id
        };
    } 
    elsif ( $functype eq 'Pfam_Category' ) {
        $sql = qq{
            select ext_accession, functions 
            from pfam_family_cogs
        };
    } 
    elsif ( $functype eq 'TIGRfam_Role' ) {
        $sql = qq{
            select ext_accession, roles 
            from tigrfam_roles
        };
    }
    print "getFunc2Category() sql = $sql<br/>\n";
    
    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $func_id, $func_cate ) = $cur->fetchrow();
            last if !$func_id;
            if ( $funcId_category_h{$func_id} ) {
                my $cateIds_href = $funcId_category_h{$func_id};
                $cateIds_href->{$func_cate} .= 1;
            } else {
                my %cateIds_h;
                $cateIds_h{$func_cate} = 1;
                $funcId_category_h{$func_id} = \%cateIds_h;
            }
        }
        $cur->finish();
    }

    return %funcId_category_h;
}

#################################################################################
# isSingleCell - to detect whether a genome is a single cell
#################################################################################
sub isSingleCell {
    my ($dbh, $taxon_oid) = @_;
    
    my $sql = "select taxon_oid, taxon_display_name from vw_taxon_sc where taxon_oid = ?"; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_oid, $taxon_display_name) = $cur->fetchrow();
    $cur->finish();

    return 1 if ( $taxon_oid );

    return 0;
}


############################################################################
# fetchTaxonOidsFromBinOids
############################################################################
sub fetchTaxonOidsFromBinOids {
    my ( $dbh, @bin_oids ) = @_;

    my @taxon_oids = ();
    if (scalar(@bin_oids) > 0) {
        my $ids_str = OracleUtil::getNumberIdsInClause( $dbh, @bin_oids );

        my $sql = qq{
            select distinct tx.taxon_oid
            from taxon tx, env_sample_gold es, bin b
            where b.bin_oid in ($ids_str)
            and b.is_default = 'Yes'
            and b.env_sample = es.sample_oid
            and es.sample_oid = tx.env_sample
        };        
        my $cur = execSql( $dbh, $sql, $verbose); 
        for ( ; ; ) { 
            my ( $id ) = $cur->fetchrow(); 
            last if !$id;
            push(@taxon_oids, $id);
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $ids_str =~ /gtt_num_id/i );        
    }
    #print "fetchTaxonOidsFromBinOids() taxon_oids: @taxon_oids<br/>\n";

    return @taxon_oids;
}

############################################################################
# groupFuncIds - split func ids into group
############################################################################
sub groupFuncIds {
    my ( $func_ids_ref, $withTag ) = @_;

    # function types list
    my @go_ids;
    my @cog_ids;
    my @kog_ids;
    my @pfam_ids;
    my @tigr_ids;
    my @ec_ids;
    my @ko_ids;
    my @ipr_ids;
    my @tc_fam_nums;
    my @bc_ids;
    my @np_ids;
    my @metacyc_ids;
    my @iterm_ids;
    my @ipway_ids;
    my @plist_ids;
    my @netwk_ids;
    my @icmpd_ids;
    my @irexn_ids;
    my @prule_ids;
    my @unrecognized_ids;

    foreach my $id (@$func_ids_ref) {
        $id = WebUtil::strTrim($id);
        if ( $id =~ /^GO/i ) {
            push( @go_ids, $id );
        }
        elsif ( $id =~ /^COG/i ) {
            push( @cog_ids, $id );
        }
        elsif ( $id =~ /^KOG/i ) {
            push( @kog_ids, $id );
        }
        elsif ( $id =~ /^pfam/i ) {
            push( @pfam_ids, $id );
        }
        elsif ( $id =~ /^TIGR/i ) {
            push( @tigr_ids, $id );
        }
        elsif ( $id =~ /^EC:/i ) {
            push( @ec_ids, $id );
        }
        elsif ( $id =~ /^KO:/i ) {
            push( @ko_ids, $id );
        }
        elsif ( $id =~ /^IPR/i ) {
            push( @ipr_ids, $id );
        }
        elsif ( $id =~ /^TC:/i ) {
            push( @tc_fam_nums, $id );
        }
        elsif ( $id =~ /^BC:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/BC://i;                
            }
            push( @bc_ids, $idCopy );
        }
        elsif ( $id =~ /^NP:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/NP://i;
            }
            push( @np_ids, $idCopy );
        }
        elsif ( $id =~ /^MetaCyc:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/MetaCyc://i;
            }
            push( @metacyc_ids, $idCopy );
        }
        elsif ( $id =~ /^ITERM:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/ITERM://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @iterm_ids, $idCopy );
        }
        elsif ( $id =~ /^IPWAY:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/IPWAY://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @ipway_ids, $idCopy );
        }
        elsif ( $id =~ /^PLIST:/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/PLIST://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @plist_ids, $idCopy );
        }
        elsif ( $id =~ /^NETWK/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/NETWK://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @netwk_ids, $idCopy );
        }
        elsif ( $id =~ /^ICMPD/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/ICMPD://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @icmpd_ids, $idCopy );
        }
        elsif ( $id =~ /^IREXN/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/IREXN://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @irexn_ids, $idCopy );
        }
        elsif ( $id =~ /^PRULE/i ) {
            my $idCopy = $id;
            if ( ! $withTag ) {
                $idCopy =~ s/PRULE://i;
                $idCopy = WebUtil::trimIntLeadingZero($idCopy);
            }
            push( @prule_ids, $idCopy );
        }
        else {
            push( @unrecognized_ids, $id );
        }
    }

    return (\@go_ids, \@cog_ids, \@kog_ids, \@pfam_ids, 
            \@tigr_ids, \@ec_ids, \@ko_ids, \@ipr_ids, 
            \@tc_fam_nums, \@bc_ids, \@np_ids, \@metacyc_ids, 
            \@iterm_ids, \@ipway_ids, \@plist_ids, \@netwk_ids, 
            \@icmpd_ids, \@irexn_ids, \@prule_ids, \@unrecognized_ids);
}

############################################################################
# groupFuncIdsIntoOneArray
############################################################################
sub groupFuncIdsIntoOneArray {
    my ( $func_ids_ref ) = @_;

    # function types list
    my (
        $go_ids_ref,    $cog_ids_ref,     $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
        $ec_ids_ref,    $ko_ids_ref,      $ipr_ids_ref,   $tc_fam_nums_ref, $bc_ids_ref,
        $np_ids_ref,    $metacyc_ids_ref, $iterm_ids_ref, $ipway_ids_ref,   $plist_ids_ref,
        $netwk_ids_ref, $icmpd_ids_ref,   $irexn_ids_ref, $prule_ids_ref,   $unrecognized_ids_ref
      )
      = groupFuncIds($func_ids_ref, 1);

    my @func_groups;
    push(@func_groups, $go_ids_ref) if ( $go_ids_ref && scalar(@$go_ids_ref) > 0 );
    push(@func_groups, $cog_ids_ref) if ( $cog_ids_ref && scalar(@$cog_ids_ref) > 0 );
    push(@func_groups, $kog_ids_ref) if ( $kog_ids_ref && scalar(@$kog_ids_ref) > 0 );
    push(@func_groups, $pfam_ids_ref) if ( $pfam_ids_ref && scalar(@$pfam_ids_ref) > 0 );
    push(@func_groups, $tigr_ids_ref) if ( $tigr_ids_ref && scalar(@$tigr_ids_ref) > 0 );
    push(@func_groups, $ec_ids_ref) if ( $ec_ids_ref && scalar(@$ec_ids_ref) > 0 );
    push(@func_groups, $ko_ids_ref) if ( $ko_ids_ref && scalar(@$ko_ids_ref) > 0 );
    push(@func_groups, $ipr_ids_ref) if ( $ipr_ids_ref && scalar(@$ipr_ids_ref) > 0 );
    push(@func_groups, $tc_fam_nums_ref) if ( $tc_fam_nums_ref && scalar(@$tc_fam_nums_ref) > 0 );
    push(@func_groups, $bc_ids_ref) if ( $bc_ids_ref && scalar(@$bc_ids_ref) > 0 );
    push(@func_groups, $np_ids_ref) if ( $np_ids_ref && scalar(@$np_ids_ref) > 0 );
    push(@func_groups, $metacyc_ids_ref) if ( $metacyc_ids_ref && scalar(@$metacyc_ids_ref) > 0 );
    push(@func_groups, $iterm_ids_ref) if ( $iterm_ids_ref && scalar(@$iterm_ids_ref) > 0 );
    push(@func_groups, $ipway_ids_ref) if ( $ipway_ids_ref && scalar(@$ipway_ids_ref) > 0 );
    push(@func_groups, $plist_ids_ref) if ( $plist_ids_ref && scalar(@$plist_ids_ref) > 0 );
    push(@func_groups, $netwk_ids_ref) if ( $netwk_ids_ref && scalar(@$netwk_ids_ref) > 0 );
    push(@func_groups, $icmpd_ids_ref) if ( $icmpd_ids_ref && scalar(@$icmpd_ids_ref) > 0 );
    push(@func_groups, $irexn_ids_ref) if ( $irexn_ids_ref && scalar(@$irexn_ids_ref) > 0 );
    push(@func_groups, $prule_ids_ref) if ( $prule_ids_ref && scalar(@$prule_ids_ref) > 0 );
    push(@func_groups, $unrecognized_ids_ref) if ( $unrecognized_ids_ref && scalar(@$unrecognized_ids_ref) > 0 );

    return (@func_groups);
}

############################################################################
# gets all cog names for database
# param $dbh database handler
# return hash ref: id => name
############################################################################
sub getAllCogNames {
    my ($dbh) = @_;
    
    my %results;
    fetchAllCogIdNameHash( $dbh, \%results );

    return \%results;
}

sub getCogNames {
    my ( $dbh, $id_href ) = @_;

    my @a = ();
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }

    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchCogIdNameHash( $dbh, \%hash, @a);
    }

    return \%hash;
}

############################################################################
# getCogId2Definition - gets all cog id to definition
############################################################################
sub getCogId2Definition {
    my ($dbh) = @_;
    
    my $sql = qq{
        select distinct cfs.cog_id, cf.definition
        from cog_functions cfs, cog_function cf
        where cfs.functions = cf.function_code
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %cogId2definition;
    for ( ; ; ) {
        my ( $cog_id, $definition ) = $cur->fetchrow();
        last if !$cog_id;

        my $defs_ref = $cogId2definition{$cog_id};
        if ( $defs_ref ) {
            push(@$defs_ref, $definition);
        }
        else {
            my @defs = ( $definition );
            $cogId2definition{$cog_id} = \@defs;
        }
    }
    $cur->finish();

    return ( \%cogId2definition );
}

sub getCogId2DefinitionMapping {

    my %cogId2definition;
    
    #print "printCogStatChart() base_dir=$base_dir<br/>\n";
    my $rfh = newReadFileHandle( "$base_dir/cogid_and_cat.html" );
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        next if ( $line =~ /^COG_ID/i );
        my ($cog_id, $code, $definition, @junk) = split(/\t/, $line);
        
        my $defs_ref = $cogId2definition{$cog_id};
        if ( $defs_ref ) {
            push(@$defs_ref, $definition);
        }
        else {
            my @defs = ($definition);
            $cogId2definition{$cog_id} = \@defs;
        }
    }    
    close $rfh;

    return ( \%cogId2definition );
}

############################################################################
# getCogFunction - gets all cog functions
############################################################################
sub getCogFunction {
    my ($dbh) = @_;
    
    my $sql = qq{
      select function_code, definition
      from cog_function
      order by function_code
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %cogFunction;
    my $count = 0;
    for ( ; ; ) {
        my ( $function_code, $definition ) = $cur->fetchrow();
        last if !$function_code;
        $cogFunction{$function_code} = "$definition\t$count";
        $count++;
    }
    $cur->finish();
    return %cogFunction;
}


##############################################################################
# getCKogCateDefinition
##############################################################################
sub getCKogCateDefinition {
    my ($dbh, $function_code, $og) = @_;

    my $sql = qq{
        select definition
        from ${og}_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    return $definition;
}

############################################################################
# getCogId2Pathway - gets all cog id to definition
############################################################################
sub getCogId2Pathway {
    my ($dbh) = @_;
    
    my $sql = qq{
        select cpcm.cog_members, cp.cog_pathway_name
        from cog_pathway_cog_members cpcm, cog_pathway cp
        where cpcm.cog_pathway_oid = cp.cog_pathway_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my %cogId2pathway;
    for ( ; ; ) {
        my ( $cog_id, $pathway ) = $cur->fetchrow();
        last if !$cog_id;

        my $defs_ref = $cogId2pathway{$cog_id};
        if ( $defs_ref ) {
            push(@$defs_ref, $pathway);
        }
        else {
            my @defs = ( $pathway );
            $cogId2pathway{$cog_id} = \@defs;
        }
    }
    $cur->finish();

    return ( \%cogId2pathway );
}

############################################################################
# gets all enzyme names for database
# param $dbh database handler
# return hash ref: id => name
############################################################################
sub getAllEnzymeNames {
    my ($dbh) = @_;
    
    my %results;
    fetchAllEnzymeNumberNameHash( $dbh, \%results );

    return \%results;
}

sub getEnzymeNames {
    my ( $dbh, $id_href ) = @_;

    my @a = ();
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }

    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchEnzymeNumberNameHash( $dbh, \%hash, @a);
    }

    return \%hash;
}


############################################################################
# gets all ko names for database
# param $dbh database handler
# return hash ref: id => name
############################################################################
sub getAllKoNames {
    my ($dbh) = @_;
    
    my %results;
    fetchAllKoIdDefHash( $dbh, \%results );

    return \%results;
}

sub getKoNames {
    my ( $dbh, $id_href ) = @_;

    my @a = ();
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }

    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchKoIdDefHash( $dbh, \%hash, @a);
    }

    return \%hash;
}

############################################################################
# gets all pfam names
# param $dbh database handler
# return hash ref: id => name
############################################################################
sub getAllPfamNames {
    my ($dbh) = @_;

    my %results;
    fetchAllPfamIdNameHash( $dbh, \%results);

    return \%results;
}

sub getPfamNames {
    my ( $dbh, $id_href ) = @_;
    
    my @a;
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }
    
    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchPfamIdNameHash( $dbh, \%hash, @a);
    }

    return \%hash;
}

############################################################################
# gets all tigrfam names
# param $dbh database handler
# return hash ref: id => name
############################################################################
sub getAllTigrfamNames {
    my ($dbh) = @_;

    my %results;
    fetchAllTigrfamIdNameHash( $dbh, \%results);

    return \%results;
}


sub getTigrfamNames {
    my ( $dbh, $id_href ) = @_;
    
    my @a;
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }
    
    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchTigrfamIdNameHash( $dbh, \%hash, @a);
    }
    
    return \%hash;
}

sub getKoDefinitions {
    my ( $dbh, $id_href ) = @_;
    
    my @a;
    foreach my $id ( keys %$id_href ) {
        push( @a, $id );
    }
    
    my %hash;
    if ( scalar(@a) >= 0 ) {
        fetchKoIdDefHash( $dbh, \%hash, @a);
    }

    return \%hash;
}

############################################################################
# get list of all func
# param $dbh database handler
# return array
############################################################################
sub getAllFuncList {
    my ($dbh, $func) = @_;

    my $sql;
    if ( $func eq "cog" ) {
        $sql = "select cog_id from cog order by 1";
    }
    elsif ( $func eq "enzyme" || $func eq "ec" ) {
        $sql = "select ec_number from enzyme order by 1";
    }
    elsif ( $func eq "ko" ) {
        $sql = "select ko_id from ko_term order by 1";
    }
    elsif ( $func eq "pfam" ) {
        $sql =
          "select ext_accession from pfam_family order by 1";
    }
    elsif ( $func eq "tigrfam" || $func eq "tigr" ) {
        $sql =
          "select ext_accession from tigrfam order by 1";
    }

    my @ids;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        push(@ids, $id);
    }
    $cur->finish();

    return @ids;
}

############################################################################
# gets env sample id for a taxon
#
# param $dbh - database handler
# param $taxon_oid - metag taxon id
# return env smaple id
############################################################################
sub getTaxonEnvSample {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select env_sample
        from taxon 
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($id) = $cur->fetchrow();
    $cur->finish();

    return $id;
}

############################################################################
# gets method name for a method oid
#
# param $dbh - database handler
# param $method_oid  - method oid
# return method name
############################################################################
sub getMethodName {
    my ( $dbh, $method_oid ) = @_;

    my $sql = qq{
        select method_name
        from bin_method 
        where bin_method_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $method_oid );
    my ($id) = $cur->fetchrow();
    $cur->finish();

    return $id;
}

############################################################################
# gets bin name
#
# param $dbh - database handler
# param $bin_oid - metag bin id
# return bin name
############################################################################
sub getBinName {
    my ( $dbh, $bin_oid ) = @_;

    my $sql = qq{
        select display_name
        from bin
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($id) = $cur->fetchrow();
    $cur->finish();

    return $id;
}


############################################################################
#  getTaxonCrispr - Crispr list
############################################################################
sub getTaxonCrisprList {
    my ( $dbh, $taxon_oid, $scaffolds_ref ) = @_;
    
    my @recs;
    if ( ! OracleUtil::isTableExist( $dbh, "taxon_crispr_summary" ) ) {
        return (@recs);        
    }

    my $scaffoldClause;
    if ( $scaffolds_ref && scalar(@$scaffolds_ref) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$scaffolds_ref );
        $scaffoldClause = "and tc.contig_id in ( $ids_str ) ";
    }
    
    my $rclause   = WebUtil::urClause('tc.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('tc.taxon_oid');
    my $sql       = qq{
        select tc.contig_id, tc.start_coord, tc.end_coord, tc.crispr_no
        from taxon_crispr_summary tc
        where tc.taxon_oid = ? 
        $scaffoldClause
        $rclause
        $imgClause
    };
    #print "getTaxonCrisprList() sql=$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    for ( ; ; ) {
        my ( $contig_id, $start, $end, $crispr_no ) = $cur->fetchrow();
        last if !$contig_id;
        
        my $rec;
        $rec .= "$contig_id\t";
        $rec .= "$start\t";
        $rec .= "$end\t";
        $rec .= "$crispr_no";
        push( @recs, $rec );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_func_id" ) 
        if ( $scaffoldClause =~ /gtt_func_id/i );        

    return (@recs);
}

#######################################################################
# fetchDbGenomeGenes
#######################################################################
sub fetchDbGenomeGenes {
    my ( $dbh, $db_taxons_ref ) = @_;

    # read all gene oids
    my %gene_h;

    if ( scalar(@$db_taxons_ref) > 0 ) {
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $sql2    = qq{
            select gene_oid 
            from gene 
            where taxon in ($oid_str)
        };
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ($gene_oid) = $cur2->fetchrow();
            last if ( !$gene_oid );
            $gene_h{$gene_oid} = 1;
        }
        $cur2->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );                    
    } # end if db_taxons

    return (\%gene_h);
}

1;
