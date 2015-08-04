###########################################################################
# $Id: MerFsUtil.pm 32574 2015-01-16 21:06:34Z klchu $
###########################################################################
package MerFsUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use QueryUtil;

$| = 1;

my $env                 = getEnv();
my $cgi_dir             = $env->{cgi_dir};
my $cgi_url             = $env->{cgi_url};
my $main_cgi            = $env->{main_cgi};
my $inner_cgi           = $env->{inner_cgi};
my $tmp_url             = $env->{tmp_url};
my $verbose             = $env->{verbose};
my $include_metagenomes = $env->{include_metagenomes};
my $in_file             = $env->{in_file};

sub isTaxonInFile {
    my ( $dbh, $taxon_oid ) = @_;
    my $sql = qq{
        select in_file
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($in_file) = $cur->fetchrow();
    $cur->finish();
    if ( $in_file eq 'Yes' ) {
        return 1;
    }
    return 0;
}

sub getGenomeType {
    my ( $dbh, $taxon_oid ) = @_;
    my $sql = qq{
        select genome_type
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($genome_type) = $cur->fetchrow();
    $cur->finish();
    return $genome_type;
}

sub getInFileClause {
    my $inFileClause;
    if ($in_file) {
        $inFileClause = "tx.in_file";
    }
    else {
        $inFileClause = "'No'";
    }
    return $inFileClause;
}

sub getSingleTaxonOidAndNameFileSql {
    my ($rclause, $imgClause) = @_;

    if (!$rclause && !$imgClause) {
        $rclause = WebUtil::urClause('t');
        $imgClause = WebUtil::imgClause('t');
    }
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
        from taxon t 
        where t.taxon_oid = ? 
        $rclause
        $imgClause
    };

    return $sql;
}

sub getFsTaxonsInfoSql {
    my $rclause2 = urClause("t");
    my $imgClause2 = WebUtil::imgClause('t');
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file 
        from taxon t 
        where t.taxon_oid = ?
        $rclause2
        $imgClause2
    };
        
    return $sql;
}

sub getTaxonsInFileSql {
    my ($taxonClause) = @_;

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select t.taxon_oid 
        from taxon t 
        where t.in_file = 'Yes'
        $taxonClause
        $rclause 
        $imgClause
    };
    #print "getTaxonsInFileSql() sql: $sql<br/>\n";

    return $sql;
}

sub getTaxonsInFile {
    my ($dbh, $taxonClause, $bindList_ref) = @_;

    my %taxon_in_file;
    if ($in_file) {
        my $sql = getTaxonsInFileSql($taxonClause);
        my $cur;
        my $size = $#$bindList_ref + 1;
        if ($bindList_ref ne '' && $size > 0) {
            $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
        }
        else {
            $cur = execSql( $dbh, $sql, $verbose );            
        }
        for ( ; ; ) {
            my ($toid) = $cur->fetchrow();
            last if !$toid;

            $taxon_in_file{$toid} = 1;
        }
        $cur->finish();
    }

    return %taxon_in_file;
}

sub getFsTaxonsSql {
    my ($oid_str) = @_;

    my $rclause = urClause("t");
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select t.taxon_oid
        from taxon t 
        where t.in_file = 'Yes'
        and t.taxon_oid in ($oid_str)
        $rclause
        $imgClause
    };
    #print "MerFsUtil::getFsTaxonsSql() $sql <br/>\n";
        
    return $sql;
}

sub fetchTaxonsInFile {
    my ($dbh, @oids) = @_;

    my %taxon_in_file;
    if ($in_file) {
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
        
        my $sql = getFsTaxonsSql($oid_str);
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($toid) = $cur->fetchrow();
            last if !$toid;

            $taxon_in_file{$toid} = 1;
            #print "MerFsUtil::findTaxonsInFile() $toid added <br/>\n";
        }
        $cur->finish();
        
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    }
        
    return (%taxon_in_file);
}

sub findTaxonsInFile {
    my ($dbh, @oids) = @_;

    my %taxon_in_file = fetchTaxonsInFile($dbh, @oids);
    
    my @dbTaxons;
    my @metaTaxons = keys(%taxon_in_file);
    if (scalar(@metaTaxons) > 0) {
        for my $oid(@oids) {
            if ($taxon_in_file{$oid}) {
                next;  #merfs taxon
            }
            push(@dbTaxons, $oid);
        }
    }
    else {
        @dbTaxons = @oids;
    }
    
    return (\@dbTaxons, \@metaTaxons);
}

sub getShortTaxonDisplayName {
    my ($taxon_display_name) = @_;

    if ( length($taxon_display_name) > 110 ) {
        my $len = length($taxon_display_name);
        $taxon_display_name =
            substr( $taxon_display_name, 0, 50 ) . " ... "
          . substr( $taxon_display_name, $len - 60 );
    }
    $taxon_display_name .= " (MER-FS)";

    return $taxon_display_name;
}

sub splitDbAndMetaOids {
    my (@oids) = @_;

    my @dbOids;
    my @metaOids;
    for my $oid (@oids) {
        $oid = WebUtil::strTrim($oid);
        if ( WebUtil::isInt($oid) ) {
            push( @dbOids, $oid );
        }
        else {
            push( @metaOids, $oid );                    
        }
    }

    return (\@dbOids, \@metaOids);    
}

sub fetchValidMetaTaxonOidHash {
    my ( $dbh, @metaOids ) = @_;

    my %taxon_oid_h;
    for my $mOid (@metaOids) {
        my ( $taxon_oid, $data_type, $oid ) = split( / /, $mOid );
        $taxon_oid_h{$taxon_oid} = 1;
    }
    my @taxonOids = keys(%taxon_oid_h);

    return QueryUtil::fetchValidTaxonOidHash( $dbh, @taxonOids );
}

sub getExtractedMetaOidsJoinString {
    my (@metaOids) = @_;

    my @extractedOids = ();
    for my $mOid (@metaOids) {
        my ( $taxon_oid, $data_type, $oid ) = split( / /, $mOid );
        push( @extractedOids, $oid );
    }
    my $extracted_oids_join_str = join( ',', @extractedOids );

    return $extracted_oids_join_str;
}

sub getTermNotFound {
    my ($term_list_ref, $termFoundHash_ref) = @_;
    
    my @termNotFoundArray = ();
    if (scalar(keys(%$termFoundHash_ref)) == 0) {
        @termNotFoundArray = @$term_list_ref;
    }
    else {
        foreach my $t (@$term_list_ref) {
            #print "MerFsUtil::getTermNotFound() t: $t<br/>\n";
            if ( !$termFoundHash_ref->{$t} && !$termFoundHash_ref->{lc($t)}) {
                push(@termNotFoundArray, $t);
                #print "MerFsUtil::getTermNotFound() added with $t<br/>\n";
            }
        }        
    }
        
    return (\@termNotFoundArray);
}

#
# ui http://genome.jgi.doe.gov/viz/plot?jgiProjectId=1032430
# taxon_oid=3300002909
sub hasElviz {
    my($jgiProjectId) = @_;
 
    # get portal id
    my $url1 = 'http://genome.jgi-psf.org/ext-api/genome-admin/getPortalIdByParameter?parameterName=jgiProjectId&parameterValue=' . $jgiProjectId;
    webLog("calling url $url1\n");
    my $portalId = WebUtil::urlGet($url1);
    chomp $portalId;
    if($portalId eq '') {
        return 0;
    }
    
    # my $url2 = 'http://genome.jgi-psf.org/ext-api/genome-admin/GraSoi013_2_20cm/parameters?parameters=hasElviz';
    my $url2 = 'http://genome.jgi-psf.org/ext-api/genome-admin/' . $portalId . '/parameters?parameters=hasElviz';
    webLog("calling url $url2\n");
    my $text = WebUtil::urlGet($url2);
    chomp $text;
    if($text =~ /^hasElviz=1/) {
        return 1;
    }
    
    # get parameter
    # curl --request GET --url genome.jgi-psf.org/ext-api/genome-admin/GraSoi013_2_20cm/parameters?parameters=hasElviz
    # hasElviz=1
    return 0;
}


1;
