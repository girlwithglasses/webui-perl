############################################################################
# ProfileUtil.pm - Utility for Functional profile and Phylo profile.
#
# $Id: ProfileUtil.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package ProfileUtil;

use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use MerFsUtil;
use HtmlUtil;
use QueryUtil;

my $env = getEnv( );
my $img_internal = $env->{ img_internal };
my $img_lite = $env->{ img_lite };
my $img_er = $env->{ img_er };
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $yui_tables = $env->{ yui_tables }; # flag for  YUI tables +BSJ 03/04/10

my $in_file = $env->{in_file};
my $mer_data_dir = $env->{mer_data_dir};

my $verbose = $env->{ verbose };


############################################################################
# printProfileGenes - Print profile count genes.
############################################################################
sub printProfileGenes {
    my( $taxon_sql, $bin_sql ) = @_;
   
    my $id        = param("id");
    $id           = CGI::unescape($id);
    my $id_org    = $id;
    my $taxon_oid = param("taxon_oid");
    my $bin_oid   = param("bin_oid");
    my $data_type = param("data_type");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $cur;
    if ( ( $taxon_sql ne "" || $bin_sql ne "" ) 
    && $id !~ /^ITERM:/ && $id !~ /^IPWAY:/ && $id !~ /^PLIST:/ ) {
        $id =~ s/'/''/g;    # replace ' with ''
        my $sql;
        if ( $bin_oid ne "" ) {
            $bin_sql   =~ s/__id__/$id/g;
            $bin_sql   =~ s/__bin_oid__/$bin_oid/g;
            $sql       = $bin_sql;
            $taxon_oid = $bin_oid;
        }        
        if ( $taxon_oid ne "" ) {
            $taxon_sql =~ s/__id__/$id/g;
            $taxon_sql =~ s/__taxon_oid__/$taxon_oid/g;
            $sql = $taxon_sql;
        }
        #print "printProfileGenes() 0 sql: $sql<br/>\n";
        if ( $sql ) {
            $cur = execSql( $dbh, $sql, $verbose );
        }

    } else {
        require FuncCartStor;
        
        my $sql;
        if ( $bin_oid ne "" ) {
            $bin_sql   = FuncCartStor::getDtGeneFuncQuery1_bin($id);
            $sql       = $bin_sql;
            $taxon_oid = $bin_oid;
        }
        if ( $taxon_oid ne "" ) {
            $taxon_sql = FuncCartStor::getDtGeneFuncQuery1($id);
            $sql = $taxon_sql;
        }
        #print "printProfileGenes() 1 sql: $sql<br/>\n";

        if ( $sql ) {
            if ( $id =~ /^IPWAY:/ ) {
                $id =~ s/IPWAY://;
                $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $id, $taxon_oid, $id );
            } else {
                if ( $id =~ /^BC:/ ) {
                    $id =~ s/BC://;
                }
                elsif ( $id =~ /^MetaCyc:/ ) {
                    $id =~ s/MetaCyc://;
                }
                elsif ( $id =~ /^ITERM:/ ) {
                    $id =~ s/ITERM://;
                }
                elsif ( $id =~ /^PLIST:/ ) {
                    $id =~ s/PLIST://;
                }
                $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $id );
            }            
        }
        
    }

    my @gene_oids;
    my $count = 0;
    if ( $cur ne '' ) {
        for ( ; ; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;
            $count++;
            push( @gene_oids, $gene_oid );
        }
    }
    
    if ( $count == 1 ) {
        use GeneDetail;
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    my $url;
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    if ( $bin_oid ne "" ) {
        $url = "$main_cgi?section=Metagenome" .
            "&page=binDetail&bin_oid=$bin_oid";        
    }
    else {
        my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
        if ( $isTaxonInFile ) {
            $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType( $taxon_name, $data_type );
            $url = "$main_cgi?section=MetaDetail&page=metaDetail&taxon_oid=$taxon_oid";            
        }
        else {
            $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        }
    } 

    my $subTitile = qq{
        <p style='width: 650px;'>
    };
    $subTitile .= 'Genome: ' . alink( $url, $taxon_name );
    $subTitile .= qq{
        </p>
    };

    my @func_ids = ( $id_org );
    my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );
    my $funcName = $funcId2Name{$id_org};

    $subTitile .= qq{
        <p>
    };
    if ( $funcName ) {
        $subTitile .= qq{
            $id_org, <i><u>$funcName</u></i>
        };
    }
    else {
        $subTitile .= qq{
            $id_org
        };
    }
    $subTitile .= qq{
        <br/>
        </p>
    };

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    HtmlUtil::printGeneListHtmlTable( 'Profile Genes', $subTitile, $dbh, $dbOids_ref, $metaOids_ref, 1 );
}

1;
