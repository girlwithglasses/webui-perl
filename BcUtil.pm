############################################################################
# Utility subroutines for queries
# $Id: BcUtil.pm 30115 2014-02-17 06:15:54Z jinghuahuang $
############################################################################
package BcUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use OracleUtil;
use QueryUtil;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $user_restricted_site = $env->{user_restricted_site};
my $enable_biocluster    = $env->{enable_biocluster};
my $img_internal         = $env->{img_internal};

sub printTableFooter {
    my ( $myform ) = @_;
    my $buttonLabel = "View Selected Neighborhoods";
    my $buttonClass = "meddefbutton";
    my $name = "_section_BiosyntheticDetail_selectedNeighborhoods";
    print submit(
          -name  => $name,
          -value => $buttonLabel,
          -class => $buttonClass,
          -onclick => "return validateBCSelection(1, \"$myform\");"
    );
    print nbsp(1);    
    printAddToCartFooter('Scaffold', $myform);
    print nbsp(1);
    printAddToCartFooter('Gene', $myform);
    print nbsp(1);
    WebUtil::printButtonFooter($myform);
    
    if($img_internal) {
        my $workspace = 0;
       if($workspace) {
          # add to workspace - new file, an existing file or buffer / cart if no file given - ken 
       } else {
           # just a button to add to buffer
           print nbsp(1);
            print submit(
          -name  => '_section_WorkspaceBcSet_addToBcBuffer',
          -value => 'Add Selected to BC Cart',
          -class => $buttonClass,
          -onclick => "return validateBCSelection(1, \"$myform\");"
            );           
       }
    }
    
}

sub printAddToCartFooter {
    my ( $cart_type, $myform ) = @_;
    
    my $id;
    if ( $cart_type eq 'Gene' ) {
        $id = "_section_BiosyntheticDetail_addToGeneCart";        
    }
    elsif ( $cart_type eq 'Scaffold' ) {
        $id = "_section_BiosyntheticDetail_addToScaffoldCart";        
    }
    my $buttonLabel = "Add Selected to $cart_type Cart";
    my $buttonClass = "meddefbutton";
    print submit(
          -name  => $id,
          -value => $buttonLabel,
          -class => $buttonClass,
          -onclick => "return validateBCSelection(1, \"$myform\");"
    );
}

sub addSelectedToScaffoldCart {
    my @bc_ids = param("bc_id");
    if ( scalar(@bc_ids) <= 0 ) {
        webError("Please make at least one selection or no Biosynthetic Cluster.");
    }

    printStartWorkingDiv();

    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $cluster_ids_clause;
    if ( scalar(@bc_ids) > 0 ) {
        my $cluster_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @bc_ids );
        $cluster_ids_clause = " and g.cluster_id in ($cluster_ids_str) ";
    }

    print "<br/>Getting cluster scaffolds ...";
    my $sql = qq{
        select distinct g.scaffold, g.taxon, t.in_file
        from bio_cluster_features_new bcf, bio_cluster_new g, taxon t
        where bcf.feature_type = 'gene'
        and bcf.cluster_id = g.cluster_id
        and g.taxon = t.taxon_oid
        $cluster_ids_clause
        $rclause
        $imgClause
    };
    #print "addSelectedToScaffoldCart() sql=$sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    my @scaffolds;
    for ( ;; ) {
        my ($scaffold_oid, $taxon, $in_file) = $cur->fetchrow();
        last if !$scaffold_oid;
        
        if ( $in_file eq 'Yes' ) {
            push(@scaffolds, "$taxon assembled $scaffold_oid");            
        }
        else {
            push(@scaffolds, $scaffold_oid);            
        }
    }
    $cur->finish();
    #print "addSelectedToScaffoldCart() scaffolds: @scaffolds<br/>\n";

    printEndWorkingDiv();        

    require ScaffoldCart;
    ScaffoldCart::addToScaffoldCart( \@scaffolds );
    ScaffoldCart::printIndex();
}


sub addSelectedToGeneCart {
    my @bc_ids = param("bc_id");
    if ( scalar(@bc_ids) <= 0 ) {
        webError("Please make at least one selection or no Biosynthetic Cluster.");
    }

    printStartWorkingDiv();

    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $cluster_ids_clause;
    if ( scalar(@bc_ids) > 0 ) {
        my $cluster_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @bc_ids );
        $cluster_ids_clause = " and g.cluster_id in ($cluster_ids_str) ";
    }

    print "<br/>Getting cluster genes ...";
    my $sql = qq{
        select distinct bcf.feature_id, g.taxon, t.in_file
        from bio_cluster_features_new bcf, bio_cluster_new g, taxon t
        where bcf.feature_type = 'gene'
        and bcf.cluster_id = g.cluster_id
        and g.taxon = t.taxon_oid
        $cluster_ids_clause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @genes;
    for ( ;; ) {
        my ($gene_id, $taxon, $in_file) = $cur->fetchrow();
        last if !$gene_id;
        if ( $in_file eq 'Yes' ) {
            push(@genes, "$taxon assembled $gene_id"); 
        }
        else {
            push(@genes, $gene_id);
        }
    }
    $cur->finish();
    #print "addSelectedToScaffoldCart() genes: @genes<br/>\n";

    require CartUtil;
    CartUtil::callGeneCartToAdd( \@genes, 1 );
}

sub getBcId2taxonInfo {
    my ( $dbh, $bcIds_ref, $bcIds_str ) = @_;

    my %bc2taxonInfo;    # bc_id => $line of <tab> data

    # get BC
    #print "Getting BC cluster taxon info<br>\n";
    if ( scalar(@$bcIds_ref) > 0 ) {
        if ( ! $bcIds_str ) {
            $bcIds_str = OracleUtil::getFuncIdsInClause( $dbh, @$bcIds_ref );                
        }
        my $sql = qq{
            select distinct g.cluster_id,
              t.domain, t.taxon_oid, t.taxon_display_name
            from bio_cluster_new g, taxon t
            where g.taxon = t.taxon_oid
            and g.cluster_id in ($bcIds_str)
        };
        #print "getBcId2taxonInfo() sql=$sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );    
        for ( ; ; ) {
            my ( $clusterId, $domain, $taxon_oid, $taxonName ) = $cur->fetchrow();
            last if ( !$clusterId );
            my $line = "$domain\t$taxon_oid\t$taxonName";
            $bc2taxonInfo{$clusterId} = $line;
        }
        $cur->finish();
    }
    #print "getBcId2taxonInfo() bc2taxonInfo:<br/>\n";
    #print Dumper(\%bc2taxonInfo) . "<br/>\n";
    
    return ( \%bc2taxonInfo );
}

sub getBcId2evidProb {
    my ( $dbh, $bcIds_ref, $bcIds_str ) = @_;

    my %bc2evid;
    my %bc2prob;

    #print "Getting BC 'EVIDENCE', 'PROBABILITY'<br>\n";
    if ( scalar(@$bcIds_ref) > 0 ) {
        if ( ! $bcIds_str ) {
            $bcIds_str = OracleUtil::getFuncIdsInClause( $dbh, @$bcIds_ref );                
        }
        my $sql      = qq{
            select distinct bcd.cluster_id, bcd.evidence, bcd.probability
            from bio_cluster_data_new bcd, bio_cluster_new g
            where bcd.cluster_id = g.cluster_id
            and  bcd.cluster_id in ($bcIds_str)
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $cluster_id, $evidence, $probability ) = $cur->fetchrow();
            last if ( !$cluster_id );
            $bc2evid{$cluster_id} = $evidence;
            $bc2prob{$cluster_id} = $probability;
        }
    }
    
    return ( \%bc2evid, \%bc2prob );
}


1;
