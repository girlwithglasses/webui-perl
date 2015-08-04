############################################################################
# $Id: MeshTree.pm 32572 2015-01-16 20:54:23Z aratner $
############################################################################
package MeshTree;

use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use OracleUtil;
use JSON;
use HTML::Template;
use Storable;
use WebConfig;
use WebUtil;

$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $main_cgi             = $env->{main_cgi};
my $verbose              = $env->{verbose};
my $base_url             = $env->{base_url};
my $YUI                  = $env->{yui_dir_28};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_ken              = $env->{img_ken};
my $xml_cgi              = $cgi_url . '/xml.cgi';
my $cacheDir             = '/webfs/scratch/img/sqlcache/';
my $user_restricted_site = $env->{user_restricted_site};

my $nvl = getNvl();

my $pubchem_baseurl = "http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=";
my $mfile           = '/global/homes/i/imachen/script/test1.txt';

sub dispatch {
    my $page = param('page');

    if ( $page eq 'compound' ) {
        printImgCompoundList();
    } elsif ( $page eq 'bcCompound' ) {
        printBcCompoundList();
    } elsif ( $page eq 'cluster' ) {
        printBCList();
    } elsif ( $page eq 'jsonAll' ) {

        # ajax call to print all img compound mesh tree
        print header( -type => "application/json" );
        printTreeAllJson();
    } elsif ( $page eq 'jsonActAll' ) {
        print header( -type => "application/json" );
        printTreeAllJsonAct();
    } elsif ( $page eq 'jsonOne' ) {

        # ajax call to print one img compound mesh tree
        print header( -type => "application/json" );
        printTreeOneCompoundJson();

    } elsif ( $page eq 'jsonBcAll' ) {
        print header( -type => "application/json" );
        printTreeAllJsonBc();
    } elsif ( $page eq 'jsonEcAll' ) {
        print header( -type => "application/json" );
        printTreeAllJsonEc();
    } elsif ( $page eq 'one' ) {

        # test
        printTreeOneDiv(72562);
    } elsif ( $page eq 'ec' ) {
        printEcList();
    } elsif ( $page eq 'ecClusterList' ) {
        printEcBcList();
    } elsif ( $page eq 'unclassifiedEcBc' ) {

        #printUnclassifiedEcBc();
    } elsif ( $page eq 'ectree' ) {
        printTreeEcDiv();
    } elsif ( $page eq 'bctree' ) {
        printTreeBcDiv();
    } elsif ( $page eq 'nptype' ) {
        print "<h1>Secondary Metabolites by Type</h1>";
        printTreeAllDiv();
    } elsif ( $page eq 'acttree' ) {
        print "<h1>Secondary Metabolites by Activity</h1>";
        my $compoundId = param('compoundId');
        printTreeActDiv($compoundId);
    } elsif ( $page eq 'jsonANIPhylo' ) {
        # ajax call to print all img ani phylum tree
        print header( -type => "application/json" );
        printTreeJsonANIPhylo();
    } elsif ( $page eq 'jsonBcPhylo' ) {
        # ajax call to print all img bc phylum tree
        print header( -type => "application/json" );
        printTreeJsonBcPhylo();
    } elsif ( $page eq 'jsonNpPhylo' ) {
        # ajax call to print all img bc phylum tree
        print header( -type => "application/json" );
        printTreeJsonNpPhylo();
    } elsif ( $page eq 'activity' ) {
        printNodeActivity();
    } else {
        printTreeAllDiv();
    }

    #printJson();
}

sub printBcCompoundList {
    my $meshId     = param('meshId');
    my $compoundId = param('compoundId');    # optional - non blank if from compound detail page
    my $name       = param('name');          # optional - non blank from tree leaf

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select node, name from mesh_dtree where node = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $meshId );
    my ( $node, $meshName ) = $cur->fetchrow();

    my $title = $meshName;

    my $clause = qq{
        and icmt.node = ?
        and c.compound_name = ?
    };
    my @bind = ( $meshId, $name );
    if ( $name eq '' ) {
        $clause = "and icmt.node like ? || '%'";
        @bind   = ($meshId);
    }
    if ( $compoundId ne '' && $compoundId > -1 ) {
        $clause .= " and c.compound_oid = ? ";
        push( @bind, $compoundId );
    }

    my $rclause   = WebUtil::urClause('npbs.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('npbs.taxon_oid');

    my %clusterIds;
    my $sql = qq{
        select distinct npbs.cluster_id, npbs.taxon_oid
        from img_compound c, img_compound_meshd_tree icmt, 
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
        $clause
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my ( $id, $taxon_oid ) = $cur->fetchrow();
        last if ( !$id );
        if ( exists $clusterIds{$id} ) {
            my $aref = $clusterIds{$id};
            push( @$aref, $taxon_oid );
        } else {
            my @a = ($taxon_oid);
            $clusterIds{$id} = \@a;
        }
    }

    require BiosyntheticDetail;
    BiosyntheticDetail::processBiosyntheticClusters( $dbh, '', '', \%clusterIds, $title, '' );
}

sub printUnclassifiedBcList {
    print qq{
        <h1>Unclassified Biosynthetic Cluster</h1>
        <p>Biosynthetic Cluster not categorized by MeSH</p>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('npbs.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('npbs.taxon_oid');

    my $sql = qq{
        select npbs.cluster_id, npbs.taxon_oid
        from np_biosynthesis_source npbs
        where 1 = 1
        $rclause
        $imgClause
        minus
        select npbs2.cluster_id, npbs2.taxon_oid
        from mesh_dtree md, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs2 
        where md.node = icmt.node
        and icmt.compound_oid = npbs2.compound_oid
    };

    my %bcId2TaxonOid;
    my @taxonOids;
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    for ( ; ; ) {
        my ( $bcid, $taxon_oid ) = $cur->fetchrow();
        last if ( !$bcid );
        $bcId2TaxonOid{$bcid} = $taxon_oid;
        push( @taxonOids, $taxon_oid );
        $cnt++;
    }

    my $inStmt = OracleUtil::getNumberIdsInClause( $dbh, @taxonOids );
    my %taxonNames;
    my $sql = qq{
        select taxon_oid, taxon_display_name
        from taxon
        where taxon_oid in ($inStmt)  
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $taxonNames{$taxon_oid} = $name;
    }

    my $it = new InnerTable( 1, "mesh$$", "mesh", 0 );
    $it->addColSpec( "Cluster ID",  "asc", "right" );
    $it->addColSpec( "Genome ID",   "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimit

    foreach my $bcid ( keys %bcId2TaxonOid ) {
        my $taxon_oid  = $bcId2TaxonOid{$bcid};
        my $taxon_name = $taxonNames{$taxon_oid};

        my $r;
        my $url = "$main_cgi?section=BiosyntheticDetail" . "&page=cluster_detail&cluster_id=$bcid";
        $r .= $bcid . $sd . alink( $url, $bcid ) . "\t";
        $r .= $taxon_oid . $sd . "$taxon_oid\t";

        my $url = 'main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=' . $taxon_oid;
        $r .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    printStatusLine( "$cnt loaded", 2 );
}


sub printEcBcList {
    my $ecId = param('ecId');
    my $type = param('type');
    my $dbh  = dbLogin();

    my $fromClause;
    my $stmtClause;
    if($type eq 'Experimental') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Experimental'";
    } elsif($type eq 'Predicted') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Predicted'";
    }

    # all ec info
    my $ec_href = getAllEc($dbh);

    my $title    = $ecId;
    my $subTitle = $ec_href->{$ecId};

    printStatusLine( "Loading ...", 1 );
    my $sql = qq{
        select distinct bf.cluster_id, ko.taxon
        from gene_ko_enzymes ko, bio_cluster_features_new bf $fromClause
        where ko.gene_oid = bf.gene_oid
        and ko.enzymes = ?
        $stmtClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ecId );
    my %clusterIds;
    for ( ; ; ) {
        my ( $id, $taxon ) = $cur->fetchrow();
        last if ( !$id );
        my $taxons_ref = $clusterIds{$id};
        if ($taxons_ref) {
            push( @$taxons_ref, $taxon );
        } else {
            my @taxons = ($taxon);
            $clusterIds{$id} = \@taxons;
        }
    }

    # replace $mfile with sql
    #desc dt_bc2ec
    #Name       Null Type
    #---------- ---- ------------
    #TAXON_OID       NUMBER(38)
    #CLUSTER_ID      VARCHAR2(50)
    #GENE_ID         VARCHAR2(50)
    #EC_NUMBER       VARCHAR2(50)
    if ($include_metagenomes) {
        my %ecCounts;    # ec num => hash of bc ids

        my $sql = qq{
            select TAXON_OID, CLUSTER_ID, GENE_ID, EC_NUMBER
            from  dt_bc2ec
            where EC_NUMBER = ?
        };

        #my $rfh = newReadFileHandle($mfile);
        #while ( my $line = $rfh->getline() ) {
        my $cur = WebUtil::execSql( $dbh, $sql, $verbose, $ecId );
        for ( ; ; ) {

            #chomp $line;
            #my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = split( /\t/, $line );
            my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = $cur->fetchrow();
            last if ( !$taxon_oid );

            $ecnum = ecValid($ecnum);

            if ( $ecnum =~ /^$ecId/ ) {

                # keep this one
            } else {
                next;
            }
            my $taxons_ref = $clusterIds{$bcid};
            if ($taxons_ref) {
                push( @$taxons_ref, $taxon_oid );
            } else {
                my @taxons = ($taxon_oid);
                $clusterIds{$bcid} = \@taxons;
            }
        }

        #close $rfh;
    }

    #print "printEcBcList() clusterIds<br/>\n";
    #print Dumper(\%clusterIds);
    #print "<br/>\n";

    require BiosyntheticDetail;
    BiosyntheticDetail::processBiosyntheticClusters( $dbh, '', '', \%clusterIds, $title, $subTitle );

}

# metagenomes
#
# what if end node no '-' at the end then show list of ec, gene, ko, cluster id
sub printEcList {
    my $ecId = param('ecId');
    my $type = param('type');

    if ( $ecId eq '-1' ) {

        #printUnclassifiedEcList();
        return;
    }

    my $dbh = dbLogin();

    # all ec info
    my $ec_href = getAllEc($dbh);
    my %ecNames = %$ec_href;

    my $name = $ec_href->{$ecId};
    print qq{
        <h1>
       $ecId 
       <br>$name
       </h1>
    };

    my $ecClause  = "and ko.enzymes = ?";
    my $ecClause2 = "and EC_NUMBER = ?";
    if ( $ecId =~ /-$/ ) {
        $ecClause  = "and ko.enzymes like ? || '%'";
        $ecClause2 = "and EC_NUMBER like ? || '%'";
    }

    my $fromClause;
    my $stmtClause;
    if($type eq 'Experimental') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Experimental'";
    } elsif($type eq 'Predicted') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Predicted'";
    }

    my $sql = qq{
        select ko.enzymes, count(distinct bf.cluster_id) 
        from gene_ko_enzymes ko, bio_cluster_features_new bf $fromClause
        where ko.gene_oid = bf.gene_oid
        $ecClause
        $stmtClause
        group by ko.enzymes
    };

    my $ecTmp = $ecId;
    $ecTmp =~ s/-$//;    # just remove the - not the '.' too
    my $cur = execSql( $dbh, $sql, $verbose, $ecTmp );

    my %dataHash;        # ec => count
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if ( !$id );
        $dataHash{$id} = $count;
    }

    # replace $mfile with sql
    #desc dt_bc2ec
    #Name       Null Type
    #---------- ---- ------------
    #TAXON_OID       NUMBER(38)
    #CLUSTER_ID      VARCHAR2(50)
    #GENE_ID         VARCHAR2(50)
    #EC_NUMBER       VARCHAR2(50)
    if ($include_metagenomes) {
        my %ecCounts;    # ec num => hash of bc ids
        my $sql = qq{
            select TAXON_OID, CLUSTER_ID, GENE_ID, EC_NUMBER
            from  dt_bc2ec
            where 1 = 1
            $ecClause2
        };
        my $cur = WebUtil::execSql( $dbh, $sql, $verbose, $ecTmp );
        for ( ; ; ) {

            #chomp $line;
            #my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = split( /\t/, $line );
            my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = $cur->fetchrow();
            last if ( !$taxon_oid );
            $ecnum = ecValid($ecnum);

            if ( $ecnum =~ /^$ecTmp/ ) {

                # keep this one
            } else {
                next;
            }

            if ( exists $ecCounts{$ecnum} ) {
                my $href = $ecCounts{$ecnum};
                $href->{$bcid} = $bcid;
            } else {
                my %h = ( $bcid => $bcid );
                $ecCounts{$ecnum} = \%h;
            }
        }

        #close $rfh;

        foreach my $ecnum ( keys %ecCounts ) {
            my $href  = $ecCounts{$ecnum};
            my $count = keys %$href;
            if ( exists $dataHash{$ecnum} ) {
                $dataHash{$ecnum} = $dataHash{$ecnum} + $count;
            } else {
                $dataHash{$ecnum} = $count;
            }
        }
    }

    my $it = new InnerTable( 1, "ecmesh$$", "ecmesh", 0 );
    $it->addColSpec( "Enzymes Id",    "char asc",   "left" );
    $it->addColSpec( "Enzymes Name",  "char asc",   "left" );
    $it->addColSpec( "Cluster Count", "number asc", "right" );
    my $sd = $it->getSdDelim();    # sort delimit

    my $cnt = 0;
    my $sum = 0;
    foreach my $id ( keys %dataHash ) {
        my $count = $dataHash{$id};
        my $name  = $ecNames{$id};
        my $r;
        $r .= $id . $sd . $id . "\t";
        $r .= $name . $sd . $name . "\t";
        my $url = 'main.cgi?section=MeshTree&page=ecClusterList&ecId=' . $id;
        $url = alink( $url, $count );
        $r .= $count . $sd . $url . "\t";

        $it->addRow($r);

        $cnt++;
        $sum += $count;
    }

    $it->printOuterTable(1);
    printStatusLine( "Rows $cnt, Sum $sum loaded", 2 );

}

sub printBCList {
    my $meshId = param('meshId');
    my $bcId   = param('bcid');

    if ( $meshId eq '-1' ) {
        printUnclassifiedBcList();
        return;
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select node, name from mesh_dtree where node = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $meshId );
    my ( $node, $meshName ) = $cur->fetchrow();

    print qq{
        <h1>$meshName</h1>
        <h2>Biosynthetic Cluster List</h2>
    };

    my @bind = ($meshId);
    my $clause;
    if ( $bcId ne '' ) {
        push( @bind, $bcId );
        $clause = 'and npbs.cluster_id = ?';
    }

    my $sql = qq{
        select distinct md.node, md.name, npbs.cluster_id
        from mesh_dtree md, img_compound_meshd_tree icmt,
        np_biosynthesis_source npbs 
        where md.node = icmt.node
        and icmt.compound_oid = npbs.compound_oid
        and md.node like ? || '%'
        $clause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    my @recs;
    my @cluster_ids;
    for ( ; ; ) {
        my ( $node, $meshName, $bcid ) = $cur->fetchrow();
        last if ( !$node );
        push @recs,        "$bcid\t$node\t$meshName";
        push @cluster_ids, $bcid;
    }

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $clusterClause;
    if ( scalar(@cluster_ids) > 0 ) {
        my $cluster_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @cluster_ids );
        $clusterClause = " and bc.cluster_id in ($cluster_ids_str) ";
    }
    my $sql = qq{
        select distinct bcd.cluster_id, bcd.evidence,
               tx.taxon_oid, $nvl(tx.taxon_name, tx.taxon_display_name)
        from bio_cluster_data_new bcd, bio_cluster_new bc, taxon tx
        where bc.cluster_id = bcd.cluster_id
        and bc.taxon = tx.taxon_oid
        $rclause
        $imgClause
        $clusterClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %bc2evidence;
    my %bc2tx;
    for ( ; ; ) {
        my ( $bc_id, $attr_val, $txid, $txname ) = $cur->fetchrow();
        last if !$bc_id;
        $bc2evidence{$bc_id} = $attr_val;
        $bc2tx{$bc_id}       = $txid . "\t" . $txname;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "mesh$$", "mesh", 1 );
    $it->addColSpec( "Cluster ID", "asc", "right" );
    $it->addColSpec( "Genome",     "asc", "left" );
    $it->addColSpec( "Evidence",   "asc", "left" );
    $it->addColSpec( "MeSH Id",    "asc", "left" );
    $it->addColSpec( "Name",       "asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $cnt = 0;
    my %bcCount;
    foreach my $rec (@recs) {
        my ( $bcid, $node, $meshName ) = split( "\t", $rec );

        my $url = "$main_cgi?section=BiosyntheticDetail" . "&page=cluster_detail&cluster_id=$bcid";

        my $r;
        $r .= $bcid . $sd . alink( $url, $bcid ) . "\t";

        my $tx = $bc2tx{$bcid};
        if ( $tx eq "" ) {
            #$r .= ' obsolete' . $sd . 'obsolete genome' . "\t";
            next;
        } else {

            my ( $txid, $txname ) = split( "\t", $tx );
            my $url2 = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$txid";
            $r .= $txname . $sd . alink( $url2, $txname ) . "\t";
        }

        my $attr_val = $bc2evidence{$bcid};
        $r .= $attr_val . $sd . $attr_val . "\t";
        $r .= $node . $sd . "$node\t";
        $r .= $meshName . $sd . "$meshName\t";

        $it->addRow($r);
        $cnt++;
        $bcCount{$bcid} = 1;
    }

    $it->printOuterTable(1);
    my $size = keys %bcCount;
    printStatusLine( "Rows: $cnt BC $size loaded", 2 );
}

sub printUnclassifiedCompoundList {
    print qq{
        <h1>Unclassified Compounds</h1>
        <p>Compounds not categorized by MeSH.</p>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select c1.compound_oid, c1.compound_name
        from img_compound c1
        minus
        select c2.compound_oid, c2.compound_name
        from img_compound c2, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs
        where c2.compound_oid = npbs.compound_oid
        and c2.compound_oid = icmt.compound_oid
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my @compoundIds;
    my %compoundId2Name;
    my $cnt = 0;
    for ( ; ; ) {
        my ( $compound_oid, $name ) = $cur->fetchrow();
        last if ( !$compound_oid );
        push( @compoundIds, $compound_oid );
        $compoundId2Name{$compound_oid} = $name;
        $cnt++;
    }

    my $inStmt = OracleUtil::getNumberIdsInClause( $dbh, @compoundIds );

    my $sql = qq{
        select compound_oid, id
        from img_compound_ext_links
        where db_name = 'PubChem Compound'
        and compound_oid in ($inStmt)
    };

    my $coid2PubchemId_href = getPubchemId( $dbh, $sql );

    my $it = new InnerTable( 1, "unclassmesh$$", "unclassmesh", 0 );
    $it->addColSpec( "Compound ID", "number asc", "right" );
    $it->addColSpec( "Name",        "char asc",   "left" );
    $it->addColSpec( "PubChem CID", "number asc", "right" );
    my $sd = $it->getSdDelim();    # sort delimit

    my $url = 'main.cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=';
    foreach my $compound_oid ( keys %compoundId2Name ) {
        my $compound_name = $compoundId2Name{$compound_oid};
        my $r;

        $r .= $compound_oid . $sd . "<a href='" . $url . $compound_oid . "'> $compound_oid</a>" . "\t";
        $r .= $compound_name . $sd . "$compound_name\t";

        if ( exists $coid2PubchemId_href->{$compound_oid} ) {
            my $poid = $coid2PubchemId_href->{$compound_oid};
            $r .= $poid . $sd . "<a href='" . $pubchem_baseurl . $poid . "'> $poid</a>" . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    printStatusLine( "$cnt loaded", 2 );
}

sub printImgCompoundList {
    my $meshId     = param('meshId');
    my $name       = param('name');
    my $compoundId = param('compoundId');

    if ( $meshId eq '-1' ) {
        printUnclassifiedCompoundList();
        return;
    }

    #print "TODO mesh id = $meshId<br>";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select node, name from mesh_dtree where node = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $meshId );
    my ( $node, $meshName ) = $cur->fetchrow();

    print qq{
        <h1>$meshName</h1>
        <h2>IMG Compound List</h2>
    };

    my $it = new InnerTable( 1, "mesh$$", "mesh", 1 );
    $it->addColSpec( "Compound ID",   "number asc", "right" );
    $it->addColSpec( "Name",          "char asc",   "left" );
    $it->addColSpec( "Formula",       "char asc",   "left" );
    $it->addColSpec( "NP Type",       "char asc",   "left" );
    $it->addColSpec( "NP Activity",   "char asc",   "left" );
    $it->addColSpec( "MeSH Id",       "char asc",   "left" );
    $it->addColSpec( "PubChem CID",   "number asc", "right" );
    $it->addColSpec( "Genome Count",  "number asc", "right" );
    $it->addColSpec( "Cluster Count", "number asc", "right" );
    my $sd = $it->getSdDelim();    # sort delimit

    my $clause = qq{
        and icmt.node = ?
        and c.compound_name = ?
    };
    my @bind = ( $meshId, $name );
    if ( $name eq '' ) {
        $clause = "and icmt.node like ? || '%'";
        @bind   = ($meshId);
    }
    if ( $compoundId ne '' && $compoundId > -1 ) {
        $clause .= " and c.compound_oid = ? ";
        push( @bind, $compoundId );
    }

    my $sql = qq{
        select distinct c.compound_oid, c.compound_name, icmt.node, c.formula
        from img_compound c, img_compound_meshd_tree icmt, 
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
        $clause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @bind );

    my @dataRow;
    my @coids;
    for ( ; ; ) {
        my ( $compound_oid, $compound_name, $node, $formula ) = $cur->fetchrow();
        last if ( !$compound_oid );
        my $str = "$compound_oid\t$node\t$compound_name\t$formula";
        push( @dataRow, $str );
        push( @coids,   $compound_oid );
    }

    my $inclause = OracleUtil::getNumberIdsInClause( $dbh, @coids );
    my $sql      = qq{
        select compound_oid, id
        from img_compound_ext_links
        where db_name = 'PubChem Compound'
        and compound_oid in ($inclause)
    };

    my $coid2PubchemId_href = getPubchemId( $dbh, $sql );

    # genome and bc counts
    my $rclause   = WebUtil::urClause('bc.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('bc.taxon');
    my $sql       = qq{
        select nbs.compound_oid, count(distinct bc.taxon), 
               count(distinct bc.cluster_id)
        from np_biosynthesis_source nbs, bio_cluster_new bc
        where nbs.cluster_id is not null
        and nbs.cluster_id = bc.cluster_id
        and nbs.compound_oid in ($inclause)
        $rclause
        $imgClause
        group by nbs.compound_oid
    };
    my ( $genomeCount_href, $bcCount_href ) = getGenomeAndBcCount( $dbh, $sql );

    ## SM activity
    my %act_h;
    my $sql = qq{
        select distinct ca.compound_oid, md.name
        from np_biosynthesis_source nbs, 
             img_compound_activity ca, mesh_dtree md
        where nbs.compound_oid = ca.compound_oid
        and ca.activity = md.node
        and ca.compound_oid in ($inclause)
        order by 1, 2
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $act ) = $cur->fetchrow();
        last if !$compound_oid;

        if ( $act_h{$compound_oid} ) {
            $act_h{$compound_oid} .= "; " . $act;
        } else {
            $act_h{$compound_oid} = $act;
        }
    }

    ## SM type
    my %type_h;
    my $sql = qq{
        select distinct icmt.compound_oid, md.name
        from np_biosynthesis_source nbs, 
             img_compound_meshd_tree icmt, mesh_dtree md
        where nbs.compound_oid = icmt.compound_oid
        and md.node = icmt.node
        and icmt.compound_oid in ($inclause)
        order by 1, 2
        };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compound_oid, $name ) = $cur->fetchrow();
        last if !$compound_oid;

        if ( $type_h{$compound_oid} ) {
            $type_h{$compound_oid} .= "; " . $name;
        } else {
            $type_h{$compound_oid} = $name;
        }
    }

    my $cnt   = 0;
    my $url   = 'main.cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=';
    my $gurl  = 'main.cgi?section=NaturalProd&page=npTaxonList&compound_oid=';
    my $bcurl = 'main.cgi?section=NaturalProd&page=npBioClusterList&compound_oid=';
    foreach my $line (@dataRow) {
        my ( $compound_oid, $node, $compound_name, $formula ) = split( /\t/, $line );
        my $r;

        $r .= $compound_oid . $sd . "<a href='" . $url . $compound_oid . "'> $compound_oid</a>" . "\t";
        $r .= $compound_name . $sd . "$compound_name\t";
        $r .= $formula . $sd . "$formula\t";

        if ( exists $type_h{$compound_oid} ) {
            my $nptype = $type_h{$compound_oid};
            $r .= $nptype . $sd . $nptype . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        if ( exists $act_h{$compound_oid} ) {
            my $act = $act_h{$compound_oid};
            $r .= $act . $sd . $act . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        $r .= $node . $sd . "$node\t";

        if ( exists $coid2PubchemId_href->{$compound_oid} ) {
            my $poid = $coid2PubchemId_href->{$compound_oid};
            $r .= $poid . $sd . "<a href='" . $pubchem_baseurl . $poid . "'> $poid</a>" . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        if ( exists $genomeCount_href->{$compound_oid} ) {
            my $cnt = $genomeCount_href->{$compound_oid};
            my $u = alink( $gurl . $compound_oid, $cnt );
            $r .= $cnt . $sd . $u . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        if ( exists $bcCount_href->{$compound_oid} ) {
            my $cnt = $bcCount_href->{$compound_oid};
            my $u = alink( $bcurl . $compound_oid, $cnt );
            $r .= $cnt . $sd . $u . "\t";
        } else {
            $r .= '_' . $sd . "_\t";
        }

        $it->addRow($r);
        $cnt++;
    }

    $it->printOuterTable(1);
    printStatusLine( "$cnt loaded", 2 );
}

sub getGenomeAndBcCount {
    my ( $dbh, $sql ) = @_;
    my %genomeCnt;
    my %bcCnt;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $coid, $gcnt, $bccnt ) = $cur->fetchrow();
        last if ( !$coid );
        $genomeCnt{$coid} = $gcnt;
        $bcCnt{$coid}     = $bccnt;
    }
    return ( \%genomeCnt, \%bcCnt );

}

sub getPubchemId {
    my ( $dbh, $sql ) = @_;
    my %coid2PubchemId;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $coid, $pid ) = $cur->fetchrow();
        last if ( !$coid );
        $coid2PubchemId{$coid} = $pid;
    }
    return \%coid2PubchemId;
}

# =============================================================================
#
# mesh tree for one img compound
#
sub printTreeOneDiv {
    my ($imgCompoundId) = @_;
    print qq{
<div id="meshtreediv" >
<p> Loading Tree...
<img src="$base_url/images/yui_progressbar.gif" alt="loading tree" title="Please wait tree is loding">
</div>
<div id="treeDiv1" ></div>
<script type="text/javascript">
initTreeOne('$xml_cgi', $imgCompoundId);
</script>
    };
}

sub printTreeOneCompoundJson {
    my $imgCompoundId = param('compoundId');
    my $dbh           = dbLogin();

    # $startNodes_aref - list of D02, D23 - the part only Dxx
    my ( $leafNodes_href, $startNodes_aref, $bcCount_href, $smCount_href ) = getLeafNodes( $dbh, $imgCompoundId );

    if ( $#$startNodes_aref < 0 ) {
        print "[]";
        exit;
    }

    #my $nodes_href = getNodeNames( $dbh, $startNodes_aref );
    my $nodes_href = getAllNodeNames($dbh);
    printJson( $nodes_href, $leafNodes_href, '', $bcCount_href, $smCount_href );

}

sub getLeafNodes {
    my ( $dbh, $imgCompoundId ) = @_;

    my $sql = qq{
        select icmt.node, c.compound_name, count(*)
        from img_compound c, img_compound_meshd_tree icmt
        where c.compound_oid = icmt.compound_oid
        and c.compound_oid = ?
        group by c.compound_name, icmt.node
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getLeafNodes' . $imgCompoundId, 0, $imgCompoundId );

    # and c.compound_oid = 64623 - testing
    #my $cur = execSql( $dbh, $sql, $verbose, $imgCompoundId );
    my %data;
    my %distinctDxx;
    foreach my $inner_aref (@$aref) {
        my $node  = $inner_aref->[0];
        my $name  = $inner_aref->[1];
        my $count = $inner_aref->[2];
        $distinctDxx{$node} = $node;

        if ( exists $data{$node} ) {
            my $aref = $data{$node};

            #push( @$aref, "$compound_oid\t$name" );
            push( @$aref, "$count\t$name" );
        } else {

            #my @a = ("$compound_oid\t$name");
            my @a = ("$count\t$name");
            $data{$node} = \@a;
        }
    }

    my @dxx;
    foreach my $dxx ( keys %distinctDxx ) {
        my @a = split( /\./, $dxx );
        my $str;
        foreach my $x (@a) {
            if ( $str eq '' ) {
                $str = $x;
            } else {
                $str = $str . '.' . $x;
            }
            push( @dxx, $str );
        }
    }

    # now get SM count too
    # get distinct SM counts
    my %node2Sm;
    my $sql = qq{
        select distinct icmt.node,   c.compound_oid
        from img_compound c, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
        and c.compound_oid = ?
    };
    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getLeafNodes_SmCount2' . $imgCompoundId, 0, $imgCompoundId );

    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Sm{$node} ) {
            my $href = $node2Sm{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Sm{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Sm{$str} ) {
                my $href = $node2Sm{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Sm{$str} = \%h;
            }
        }
    }

    # now get BC count too

    my $sql = qq{
        select distinct icmt.node, npbs.cluster_id
        from img_compound c, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
        and c.compound_oid = ?
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getLeafNodes_bcCount2' . $imgCompoundId, 0, $imgCompoundId );
    my %node2Bc;    # node id to set of bc
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Bc{$node} ) {
            my $href = $node2Bc{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Bc{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Bc{$str} ) {
                my $href = $node2Bc{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Bc{$str} = \%h;
            }
        }
    }

    return ( \%data, \@dxx, \%node2Bc, \%node2Sm );
}

sub getNodeNames {
    my ( $dbh, $startNodes_aref ) = @_;

    my $clause = OracleUtil::getFuncIdsInClause( $dbh, @$startNodes_aref );

    my $sql = qq{
        select node, name 
        from mesh_dtree
        where node in ($clause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %data;
    for ( ; ; ) {
        my ( $node, $name ) = $cur->fetchrow();
        last if ( !$node );
        $data{$node} = $name;
    }

    return \%data;

}

# =============================================================================
#
# All BC mesh tree
#
sub printTreeEcDiv {
    my $hint = qq{
        () - indicates EC Tree Id <br>
        [] - indicates Biosynthetic Cluster Count<br>
    };
    printHint($hint);

    #Parent node counts may show because some BC are within the parent node.
    #<br>e.g. D10 node count shows more than the sum of its children, because there are BCs at the D10 level.

    # TOD print a selector for both, experimental and predicated
    # default is both
    #if ($img_ken) {
        print qq{
            <br>
 <select id='ecMeshTreeSelect' onchange="ecMeshTreeSelector('$xml_cgi', '$base_url/images/yui_progressbar.gif')">
  <option value="both" selected>Both</option>
  <option value="Experimental">Experimental</option>
  <option value="Predicted">Predicated</option>
</select>             
        };
    #}

    print qq{
        <div id="meshtreedivEC" >
        <p> Loading Tree...
        <img src="$base_url/images/yui_progressbar.gif" alt="loading tree" title="Please wait, tree is loding">
        </div>
        <div id="treeDiv1Ec" ></div>
        <script type="text/javascript">
        initTreeEc('$xml_cgi', 'both');
        </script>
    };
}

sub printTreeBcDiv {
    my $hint =
        "() - indicates MeSH Tree Id <br>"
      . "[] - indicates Biosynthetic Cluster Count<br/>"
      . "<u>Note</u>: Not all Biosynthetic Clusters have been categorized into a MeSH Tree";
    printHint($hint);

    #Parent node counts may show because some BC are within the parent node.
    #<br>e.g. D10 node count shows more than the sum of its children, because there are BCs at the D10 level.

    print qq{
        <div id="meshtreediv" >
        <p> Loading Tree...
        <img src="$base_url/images/yui_progressbar.gif" alt="loading tree" title="Please wait, tree is loding">
        </div>
        <div id="treeDiv1" ></div>
        <script type="text/javascript">
        initTreeBc('$xml_cgi');
        </script>
    };
}

sub printBCTypeTreeDiv {
    my $mytree = getBCTypeTree(); 
    # style='border:1px solid #99ccff;'
    print qq{
        <div id="meshtree_static"></div>
        <div id="treeDiv1BCType" class="whitebg ygtv-checkbox"></div>
        <script type="text/javascript">
            YAHOO.util.Event.onDOMReady(function () {
                loadBCTypeTree('$mytree');
            });
        </script>
    };
 }

sub getBCTypeTree {
    my $dbh = dbLogin();
    my $sql = qq{
        select bc_code, bc_desc
        from bc_type
    };

    my $aref = OracleUtil::execSqlCached
	($dbh, $sql, 'getBcTypes', 0);

    my %bc_types;
    foreach my $inner_aref (@$aref) {
	my ( $bc_type, $desc ) = @$inner_aref;
	$bc_types{$bc_type} = $desc;
    }

    # built the array:
    my @array;
    foreach my $bc_type (sort keys %bc_types) {
	my $desc =  $bc_types{$bc_type};
	my @suba;	    
	my %subhash;

	my $key = $bc_type;
	$subhash{'key'} = $key;
	$subhash{'name'}   = $desc;
	$subhash{'isLeaf'} = 'true';
	push( @array, \%subhash );
    }

    return encode_json(\@array);
}

# to remove zeros $var += 0; which will turn 00005.67 into 5.67 in $var.
#
sub ecPadded {
    my ($ec) = @_;
    my @a = split( /\./, $ec );
    my @b = @a;
    for ( my $i = 0 ; $i <= $#a ; $i++ ) {
        if ( $a[$i] =~ /^\d+/ ) {
            $b[$i] = sprintf( "%03d", $a[$i] );
        } else {
            $b[$i] = $a[$i];
        }
    }
    my $ecPadded = join( '.', @b );    # zero padded ec number
    return $ecPadded;
}

# some ec numbers in metagenomes have extra .-
# EC:1.- is correct
# but in metagenomes its EC:1.-.-.- which is wrong
# this method will strip the extra two .- or any extra .-
#
sub ecValid {
    my ($ecnum) = @_;
    if ( $ecnum =~ /-$/ ) {
        my @a = split( /\./, $ecnum );
        my @b;
        foreach my $x (@a) {
            if ( $x eq '-' ) {
                push( @b, $x );
                last;
            } else {
                push( @b, $x );
            }
        }
        $ecnum = join( '.', @b );
    }
    return $ecnum;
}

sub getAllEc {
    my ($dbh) = @_;

    # all ec info
    my $sql = qq{
select ec_number, enzyme_name
from enzyme
    };

    my $ecNames_aref = OracleUtil::execSqlCached( $dbh, $sql, 'allJsonEcNames' );
    my %ecNames;
    foreach my $inner_aref (@$ecNames_aref) {
        my $ec   = $inner_aref->[0];
        my $name = $inner_aref->[1];

        $ecNames{$ec} = $name;

        #my $ecPadded = ecPadded($ec);
        #$ecNames{$ecPadded} = $name;
    }

    return \%ecNames;
}

sub printTreeAllJsonEc {
    my $dbh     = dbLogin();
    my $ec_href = getAllEc($dbh);
    my $type    = param('type');    # both, experimental or predicated default is both

    my %ecNames = %$ec_href;


    my $fromClause;
    my $stmtClause;
    if($type eq 'Experimental') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Experimental'";
    } elsif($type eq 'Predicted') {
       $fromClause = ', bio_cluster_data_new bcd';
       $stmtClause = "and bf.cluster_id = bcd.cluster_id and bcd.evidence = 'Predicted'";
    }
    # node query ? not just leaf
    #my $rclause   = WebUtil::urClause('t.taxon_oid');
    #my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql = qq{
        select ko.enzymes, count(distinct bf.cluster_id)
        from gene_ko_enzymes ko, bio_cluster_features_new bf $fromClause
        where ko.gene_oid = bf.gene_oid
        $stmtClause
        group by ko.enzymes
    };

    my $sid;
    if ($user_restricted_site) {

        #$sid = WebUtil::getSessionId();
    }
    
   
    my $nodes_aref = OracleUtil::execSqlCached( $dbh, $sql, 'nodesJsonEc' . $sid . $type );
    my %nodes;
    foreach my $inner_aref (@$nodes_aref) {
        my $ec    = $inner_aref->[0];
        my $count = $inner_aref->[1];

        $nodes{$ec} = $count;

        #my $ecPadded = ecPadded($ec);
        #$nodes{$ecPadded} = $count;
    }

    my %metagenomeBcIds;    # bc id => bc id
    my %geneWithEc;         # metagenomes gene id => ecnum
    if ($include_metagenomes) {

        # get user valid taxons

        # SOME EC numbers for metagenomes are EC:1.-.-.- more than one .-

        # data file
        #  replace $mfile with sql
        #desc dt_bc2ec
        #Name       Null Type
        #---------- ---- ------------
        #TAXON_OID       NUMBER(38)
        #CLUSTER_ID      VARCHAR2(50)
        #GENE_ID         VARCHAR2(50)
        #EC_NUMBER       VARCHAR2(50)
        #if ( -e $mfile ) {
        webLog("getting ec metagenomes\n");
        my $sql = qq{
            select TAXON_OID, CLUSTER_ID, GENE_ID, EC_NUMBER
            from dt_bc2ec
        };
        my %ecCounts;    # ec num => hash of bc ids

        my $cacheFile  = $cacheDir . 'ecmetagenomeBcCounts_' . $sid;
        my $cacheFile2 = $cacheDir . 'ecmetagenomeBcCounts2_' . $sid;
        my $cacheFile3 = $cacheDir . 'ecmetagenomeBcCounts3_' . $sid;
        if ( -e $cacheFile && -e $cacheFile2 && -e $cacheFile3 ) {
            my $href = retrieve($cacheFile);
            %ecCounts = %$href;
            my $href = retrieve($cacheFile2);
            %metagenomeBcIds = %$href;
            my $href = retrieve($cacheFile3);
            %geneWithEc = %$href;
        } else {

            #my $validateMetagenomes_href = getValidateMetagenomes($dbh);

            #my $rfh = newReadFileHandle($mfile);
            #while ( my $line = $rfh->getline() ) {
            my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {

                #chomp $line;
                #my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = split( /\t/, $line );
                my ( $taxon_oid, $bcid, $gene_oid, $ecnum ) = $cur->fetchrow();
                last if ( !$taxon_oid );

                #next if(! exists $validateMetagenomes_href->{$taxon_oid});

                $ecnum = ecValid($ecnum);

                $metagenomeBcIds{$bcid} = $bcid;
                $geneWithEc{$gene_oid}  = $ecnum;
                if ( exists $ecCounts{$ecnum} ) {
                    my $href = $ecCounts{$ecnum};
                    $href->{$bcid} = $bcid;
                } else {
                    my %h = ( $bcid => $bcid );
                    $ecCounts{$ecnum} = \%h;
                }

            }

            #close $rfh;
            store \%ecCounts,        "$cacheFile";
            store \%metagenomeBcIds, "$cacheFile2";
            store \%geneWithEc,      "$cacheFile3";
        }

        # now add counts to %nodes;
        foreach my $ecnum ( keys %ecCounts ) {
            my $href  = $ecCounts{$ecnum};
            my $count = keys %$href;
            if ( exists $nodes{$ecnum} ) {
                $nodes{$ecnum} = $nodes{$ecnum} + $count;
            } else {
                $nodes{$ecnum} = $count;
            }
        }

        #} # end if ( -e $mfile )
    }

    my $unclassifiedCount = 0;


    # I need to add taxon obsol. public etcS

    printJsonEc( \%ecNames, \%nodes, $unclassifiedCount );

    #print "[]";
}

# hash of user viewable genomes
sub getValidateMetagenomes {
    my ($dbh) = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select t.taxon_oid 
        from taxon t 
        where t.genome_type = 'metagenome'
        $rclause
        $imgClause
    };

    my %data;
    my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $data{$taxon_oid} = $taxon_oid;
    }
    return \%data;
}

sub printTreeAllJsonBc {
    my $dbh           = dbLogin();
    my $allNodes_href = getAllNodeNames($dbh);
    my ( $allLeafNodes_href, $node2Bc_href ) = getAllLeafNodesBc2($dbh);
    my $unclassifiedCount = getUnclassifiedBcCount($dbh);

    # exception bc count here is the sm hash
    printJson( $allNodes_href, $allLeafNodes_href, $unclassifiedCount, '', $node2Bc_href );
}

sub getUnclassifiedBcCount {
    my ($dbh)     = @_;
    my $rclause   = WebUtil::urClause('npbs.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('npbs.taxon_oid');

    my $sql = qq{
        select count(*)
        from (
            select npbs.cluster_id
            from np_biosynthesis_source npbs
            where 1 = 1
            $rclause
            $imgClause
            minus
            select npbs.cluster_id
            from mesh_dtree md, img_compound_meshd_tree icmt,
                 np_biosynthesis_source npbs 
            where md.node = icmt.node
            and icmt.compound_oid = npbs.compound_oid )
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getUnclassifiedBcCount' );
    my $inner_aref = $aref->[0];
    my $count      = $inner_aref->[0];

    #my $cur = execSql( $dbh, $sql, $verbose );
    #my ($count) = $cur->fetchrow();

    return $count;
}

sub getAllLeafNodesBc2 {
    my ($dbh) = @_;

    my $sql = qq{
        select md.node, npbs.cluster_id, count(distinct npbs.cluster_id)
        from mesh_dtree md, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs 
        where md.node = icmt.node
        and icmt.compound_oid = npbs.compound_oid
        group by npbs.cluster_id, md.node
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesBc2' );

    # and c.compound_oid = 64623 - testing
    #my $cur = execSql( $dbh, $sql, $verbose );
    my %data;
    foreach my $inner_aref (@$aref) {
        my $node  = $inner_aref->[0];
        my $name  = $inner_aref->[1];
        my $count = $inner_aref->[2];
        if ( exists $data{$node} ) {
            my $aref = $data{$node};

            #push( @$aref, "$compound_oid\t$name" );
            push( @$aref, "$count\t$name" );
        } else {

            #my @a = ("$compound_oid\t$name");
            my @a = ("$count\t$name");
            $data{$node} = \@a;
        }
    }

    #    # now get BC count too
    # a bc can span over nodes and parents - I must do a manual count
    my %node2Bc;    # node id => set of bc - hash of hashes
    my $sql = qq{
        select distinct md.node, npbs.cluster_id
        from mesh_dtree md, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs, taxon t
        where md.node = icmt.node
        and icmt.compound_oid = npbs.compound_oid
        and npbs.taxon_oid = t.taxon_oid
        and t.obsolete_flag = 'No' 
    };
    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesBc2_' . 'node2Bc' );
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Bc{$node} ) {
            my $href = $node2Bc{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Bc{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Bc{$str} ) {
                my $href = $node2Bc{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Bc{$str} = \%h;
            }
        }

    }

    return ( \%data, \%node2Bc );
}

#sub getAllLeafNodesBc {
#    my ($dbh) = @_;
#
#    my $sql = qq{
#select md.node, md.name, count(distinct npbs.cluster_id)
#from mesh_dtree md, img_compound_meshd_tree icmt,
#     np_biosynthesis_source npbs
#where md.node = icmt.node
#and icmt.compound_oid = npbs.compound_oid
#group by md.node, md.name
#    };
#
#    # and c.compound_oid = 64623 - testing
#    my $cur = execSql( $dbh, $sql, $verbose );
#    my %data;
#    for ( ; ; ) {
#        my ( $node, $name, $count ) = $cur->fetchrow();
#        last if ( !$node );
#
#        if ( exists $data{$node} ) {
#            my $aref = $data{$node};
#
#            #push( @$aref, "$compound_oid\t$name" );
#            push( @$aref, "$count\t$name" );
#        } else {
#
#            #my @a = ("$compound_oid\t$name");
#            my @a = ("$count\t$name");
#            $data{$node} = \@a;
#        }
#    }
#    return \%data;
#}

# =============================================================================
#
# All img compounds mesh tree
#
sub printTreeActDiv {
    my ($imgCompoundId) = @_;

    my $hint =
        "() - indicates MeSH Tree Id <br>"
      . "[] - indicates Compound Count<br/>"
      . "<u>Note</u>: Not all IMG compounds have been categorized into a SM Activity MeSH Tree";

    if ( $imgCompoundId eq '' ) {
        $imgCompoundId = -1;
        printHint($hint);
    }

    print qq{
        <div id="meshtreedivAct" >
        <p> Loading Tree...
        <img src="$base_url/images/yui_progressbar.gif" alt="loading tree" title="Please wait tree is loding">
        </div>
        <div id="treeDiv1Act"></div>
        <script type="text/javascript">
        initTreeAct('$xml_cgi', $imgCompoundId);
        </script>
    };
}

sub printTreeAllJsonAct {
    my $dbh           = dbLogin();
    my $allNodes_href = getAllNodeNames($dbh);
    my ( $allLeafNodes_href, $node2Sm_href ) = getAllLeafNodesAct($dbh);

    my $unclassifiedCount = 0;
    printJson( $allNodes_href, $allLeafNodes_href, $unclassifiedCount, '', $node2Sm_href );
}

sub getAllLeafNodesAct {
    my ($dbh) = @_;

    my $compoundId = param('compoundId');

    my $clause;
    my @binds;
    if ( $compoundId > 0 ) {
        $clause = 'and ia.compound_oid = ?';
        push( @binds, $compoundId );
    }

    my $sql = qq{
        select md.node, md.name,
               count(distinct ia.compound_oid)
        from img_compound_activity ia,
             np_biosynthesis_source nbs,
             mesh_dtree md
        where nbs.compound_oid = ia.compound_oid
        and ia.activity = md.node
        $clause
        group by md.node, md.name
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesAct' . $compoundId, 0, @binds );

    my %data;
    foreach my $inner_aref (@$aref) {
        my $node  = $inner_aref->[0];
        my $name  = $inner_aref->[1];
        my $count = $inner_aref->[2];
        if ( exists $data{$node} ) {
            my $aref = $data{$node};
            push( @$aref, "$count\t$name" );
        } else {
            my @a = ("$count\t$name");
            $data{$node} = \@a;
        }
    }

    # get distinct SM counts
    my %node2Sm;
    my $sql = qq{
        select distinct md.node, ia.compound_oid
        from img_compound_activity ia,
             np_biosynthesis_source nbs,
             mesh_dtree md
        where nbs.compound_oid = ia.compound_oid
        and ia.activity = md.node
        $clause
    };
    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesAct_node2Sm_' . $compoundId, 0, @binds );
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Sm{$node} ) {
            my $href = $node2Sm{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Sm{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Sm{$str} ) {
                my $href = $node2Sm{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Sm{$str} = \%h;
            }
        }
    }

    return ( \%data, \%node2Sm );
}

sub printTreeAllDiv {
    my ($checkboxSelectionMode) = @_;
    $checkboxSelectionMode = 0 if ( $checkboxSelectionMode eq '' );

    if ( !$checkboxSelectionMode ) {
        my $hint =
            "() - indicates MeSH Tree Id <br>"
          . "[] - indicates Compound count (SM) and associated BC count <br/>"
          . "<u>Note</u>: Not all IMG compounds have been categorized into a MeSH Tree";
        printHint($hint);
    }

    my $checkboxSelectionYUIClass;
    if ($checkboxSelectionMode) {
        $checkboxSelectionYUIClass = "class='ygtv-checkbox'";
    }

    print qq{
        <div id="meshtreediv" >
        <p> Loading Tree...
        <img src="$base_url/images/yui_progressbar.gif" alt="loading tree" title="Please wait tree is loading">
        </div>
        <div id="treeDiv1" $checkboxSelectionYUIClass></div>
        <script type="text/javascript">
        initTree('$xml_cgi', $checkboxSelectionMode);
        </script>
    };

}

sub printTreeAllJson {
    my $dbh           = dbLogin();
    my $allNodes_href = getAllNodeNames($dbh);
    my ( $allLeafNodes_href, $node2Bc_href, $node2Sm_href ) = getAllLeafNodes($dbh);

    my $checkboxSelectionMode = param('selectionMode');
    $checkboxSelectionMode = 0 if ( $checkboxSelectionMode eq '' );
    my $unclassifiedCount;
    if ( !$checkboxSelectionMode ) {
        $unclassifiedCount = getUnclassifiedCompoundCount($dbh);
    }
    printJson( $allNodes_href, $allLeafNodes_href, $unclassifiedCount, $node2Bc_href, $node2Sm_href );
}

sub getUnclassifiedCompoundCount {
    my ($dbh) = @_;
    my $sql = qq{
        select count(*)
        from (
        select c1.compound_oid
        from img_compound c1
        minus
        select c2.compound_oid
        from img_compound c2, img_compound_meshd_tree icmt, np_biosynthesis_source npbs
        where c2.compound_oid = npbs.compound_oid
        and c2.compound_oid = icmt.compound_oid)
    };

    my $aref       = OracleUtil::execSqlCached( $dbh, $sql, 'getUnclassifiedCompoundCount' );
    my $inner_aref = $aref->[0];
    my $count      = $inner_aref->[0];

    #my $cur = execSql( $dbh, $sql, $verbose );
    #my ($count) = $cur->fetchrow();
    return $count;
}

#64623   Dimethyl sulfide    D01.248.497.158.874
#64623   Dimethyl sulfide    D01.875.350.850
#
# gets all leaf nodes with img compound
# return hash of arrays
#    Dxx => list of "$count\t$name"
#
sub getAllLeafNodes {
    my ($dbh) = @_;

    my $sql = qq{
        select icmt.node,  c.compound_name, count(distinct c.compound_oid)
        from img_compound c, img_compound_meshd_tree icmt, 
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
        group by c.compound_name, icmt.node
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodes' );

    # and c.compound_oid = 64623 - testing
    my %data;
    foreach my $inner_aref (@$aref) {
        my $node  = $inner_aref->[0];
        my $name  = $inner_aref->[1];
        my $count = $inner_aref->[2];
        if ( exists $data{$node} ) {
            my $aref = $data{$node};

            #push( @$aref, "$compound_oid\t$name" );
            push( @$aref, "$count\t$name" );
        } else {

            #my @a = ("$compound_oid\t$name");
            my @a = ("$count\t$name");
            $data{$node} = \@a;
        }
    }

    # get distinct SM counts
    my %node2Sm;
    my $sql = qq{
        select distinct icmt.node,   c.compound_oid
        from img_compound c, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid
    };
    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesCount_node2Sm' );
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Sm{$node} ) {
            my $href = $node2Sm{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Sm{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Sm{$str} ) {
                my $href = $node2Sm{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Sm{$str} = \%h;
            }
        }
    }

    #    # now get BC count too
    # a bc can span over nodes and parents - I must do a manual count
    my %node2Bc;    # node id => set of bc - hash of hashes
    my $sql = qq{
        select distinct icmt.node,  npbs.cluster_id
        from img_compound c, img_compound_meshd_tree icmt,
             np_biosynthesis_source npbs
        where c.compound_oid = npbs.compound_oid
        and c.compound_oid = icmt.compound_oid        
    };
    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'getAllLeafNodesNPBCcount_' . 'node2Bc' );
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $bc   = $inner_aref->[1];

        if ( exists $node2Bc{$node} ) {
            my $href = $node2Bc{$node};
            $href->{$bc} = $bc;
        } else {
            my %h = ( $bc => $bc );
            $node2Bc{$node} = \%h;
        }

        my @a = split( /\./, $node );
        my @key;
        foreach my $n (@a) {
            push( @key, $n );
            my $str = join( '.', @key );
            if ( exists $node2Bc{$str} ) {
                my $href = $node2Bc{$str};
                $href->{$bc} = $bc;
            } else {
                my %h = ( $bc => $bc );
                $node2Bc{$str} = \%h;
            }
        }

    }

    #webLog Dumper( \%node2Bc);
    #my $h = $node2Bc {'D01'};
    #webLog "\n\n";
    #webLog Dumper( $h);
    #webLog "\n\n";

    return ( \%data, \%node2Bc, \%node2Sm );
}

#
# Gets all node names
# return hash ref Dxx => name
#
#D01.029.260.700 Phosphorus Acids
#D01.029.260.700.600 Phosphinic Acids
#D01.029.260.700.675 Phosphoric Acids
#D01.029.260.700.675.374 Phosphates
#D01.029.260.700.675.374.025 Acidulated Phosphate Fluoride
sub getAllNodeNames {
    my ($dbh) = @_;

    my $sql = qq{
        select node, name from mesh_dtree
    };

    my $aref = OracleUtil::execSqlCached( $dbh, $sql, 'meshTreeAll' );

    #webLog "getAllNodeNames() aref<br/>\n";
    #webLog Dumper($aref);
    #webLog "<br/>\n";

    my %data;
    foreach my $inner_aref (@$aref) {
        my $node = $inner_aref->[0];
        my $name = $inner_aref->[1];
        $data{$node} = $name;
    }

    #webLog "getAllNodeNames()<br/>\n";
    #webLog Dumper(\%data);
    #webLog "<br/>\n";

    return \%data;
}

# =============================================================================
#
#
# json data to build tree called via ajax
# $allLeafNodesBcCount_href - optional
sub printJson {
    my ( $allNodes_href, $allLeafNodes_href, $unclassifiedCount, $node2Bc_href, $node2Sm_href ) = @_;

    # find the largest Dxx.xx.xx.xx size
    # max size or level
    my $maxLevel = -1;
    foreach my $node ( keys %$allLeafNodes_href ) {
        my @a = split( /\./, $node );
        my $size = $#a;
        $maxLevel = $size if ( $size > $maxLevel );
    }

    my %distinctDxxCounts;    # Dxx.... => count of img compound in children
                              #my %distinctDxxBcCounts;    # Dxx.... => count of img compound in children
    my $key;                  # Dxx.xx.xx
    my @array;                # array of array to be converted to json
    foreach my $node ( sort keys %$allLeafNodes_href ) {
        my $leafs_aref = $allLeafNodes_href->{$node};

        foreach my $leaf ( sort @$leafs_aref ) {

            # split Dxx.xx.xx into a list
            my @dxx  = split( /\./, $node );
            my $size = $#dxx;

            # inner array for @array above
            # each obj is a hash or '-'
            my @suba;

            for ( my $i = 0 ; $i <= $maxLevel ; $i++ ) {
                my %subhash;
                if ( $i == $size ) {
                    if ( $key ne '' ) {
                        $key = $key . '.' . $dxx[$i];
                    } else {

                        # root node as a leaf
                        $key = $dxx[$i];
                    }
                    $distinctDxxCounts{$key} = 0;    # initialize
                                                     #$distinctDxxBcCounts{$key} = 0;

                    # make parent node for leaf
                    my $tmp = $allNodes_href->{$key};
                    $tmp = 'n/a' if ( $tmp eq '' );
                    $subhash{'key'}    = $key;
                    $subhash{'name'}   = $tmp;
                    $subhash{'isLeaf'} = 'false';

    #                    if ( $allLeafNodesBcCount_href ne '' && exists $allLeafNodesBcCount_href->{ $key . "\t" . $tmp } ) {
    #                        my $bccnt = $allLeafNodesBcCount_href->{ $key . "\t" . $tmp };
    #                        $subhash{'bcCount'} = $bccnt;
    #                    }

                    push( @suba, \%subhash );

                    my %subhash = ();

                    # leaf node
                    my ( $count, $name ) = split( /\t/, $leaf );

                    $subhash{'key'}    = $key;
                    $subhash{'name'}   = $name;
                    $subhash{'count'}  = $count;
                    $subhash{'isLeaf'} = 'true';

   #webLog( $key . "\t" . $tmp . "\n" );
   #                    if ( $allLeafNodesBcCount_href ne '' && exists $allLeafNodesBcCount_href->{ $key . "\t" . $name } ) {
   #                        my $bccnt = $allLeafNodesBcCount_href->{ $key . "\t" . $name };
   #                        $subhash{'bcCount'} = $bccnt;
   #                    }
                    push( @suba, \%subhash );

                    $i++;
                } elsif ( $i < $size ) {
                    if ( $i == 0 ) {

                        # root node with children
                        $key = $dxx[$i];
                    } else {
                        $key = $key . '.' . $dxx[$i];
                    }
                    $distinctDxxCounts{$key} = 0;    # initialize
                                                     #$distinctDxxBcCounts{$key} = 0;

                    my $tmp = $allNodes_href->{$key};
                    $tmp = 'n/a' if ( $tmp eq '' );
                    if ( $i == 0 ) {

                        # root
                        $subhash{'key'}    = $key;
                        $subhash{'name'}   = $tmp;
                        $subhash{'isLeaf'} = 'false';

#                        if ( $allLeafNodesBcCount_href ne '' && exists $allLeafNodesBcCount_href->{ $key . "\t" . $tmp } ) {
#                            my $bccnt = $allLeafNodesBcCount_href->{ $key . "\t" . $tmp };
#                            $subhash{'bcCount'} = $bccnt;
#                        }

                        @suba = ();
                        push( @suba, \%subhash );
                    } else {

                        # sub child but not a leaf node
                        $subhash{'key'}    = $key;
                        $subhash{'name'}   = $tmp;
                        $subhash{'isLeaf'} = 'false';

#                        if ( $allLeafNodesBcCount_href ne '' && exists $allLeafNodesBcCount_href->{ $key . "\t" . $tmp } ) {
#                            my $bccnt = $allLeafNodesBcCount_href->{ $key . "\t" . $tmp };
#                            $subhash{'bcCount'} = $bccnt;
#                        }

                        push( @suba, \%subhash );

                    }
                } else {
                    push( @suba, "-" );
                }
            }

            $key = '';
            push( @array, \@suba );
        }
    }

    if ( $node2Bc_href eq '' && $node2Sm_href eq '' ) {

        # calc counts for parent nodes
        # intially only leaf nodes have counts
        foreach my $sub_aref (@array) {
            my $count = 0;

            #my $bcCount = 0;
            foreach my $href (@$sub_aref) {
                last if ( $href eq '-' );

                # find leaf node with count
                if ( exists $href->{'count'} ) {
                    $count = $href->{'count'};

                    #$bcCount = $href->{'bcCount'};
                    last;    # this should be the leaf node
                }
            }

            # update parent(s) Dxx node with counts
            foreach my $href (@$sub_aref) {
                last if ( $href eq '-' );
                last if ( ( exists $href->{'count'} ) || ( $href->{'isLeaf'} eq 'true' ) );    # do not count the leaf node
                my $dxx = $href->{'key'};
                $distinctDxxCounts{$dxx} = $distinctDxxCounts{$dxx} + $count;

                #$distinctDxxBcCounts{$dxx} = $distinctDxxBcCounts{$dxx} + $bcCount;
            }
        }
        foreach my $sub_aref (@array) {

            # update parent node with counts
            foreach my $href (@$sub_aref) {
                last if ( $href eq '-' );
                if ( $href->{'isLeaf'} eq 'false' ) {
                    my $dxx = $href->{'key'};
                    $href->{'count'} = $distinctDxxCounts{$dxx};

                    #$href->{'bcCount'} = $distinctDxxBcCounts{$dxx};
                }

            }
        }
    }

    # true SM counts for parent node - not just count the leaves which can be duplicates
    if ( $node2Sm_href ne '' ) {

        #webLog("============= here \n");

        foreach my $sub_aref (@array) {
            foreach my $href (@$sub_aref) {
                last if ( $href eq '-' );
                my $key    = $href->{'key'};
                my $isLeaf = $href->{'isLeaf'};
                next if ( $isLeaf eq 'true' );

                #webLog("key : $key\n");
                if ( exists $node2Sm_href->{$key} ) {
                    my $h    = $node2Sm_href->{$key};
                    my $size = keys %$h;
                    $href->{'count'} = $size;
                } else {
                    webLog("no sm count for node: $key\n");

                    # $href->{'bcCount'} = 0;
                }
            }
        }
    }

    # true bc counts
    if ( $node2Bc_href ne '' ) {

        #webLog("============= here \n");

        foreach my $sub_aref (@array) {
            foreach my $href (@$sub_aref) {
                last if ( $href eq '-' );
                my $key = $href->{'key'};

                #webLog("key : $key\n");
                if ( exists $node2Bc_href->{$key} ) {
                    my $h    = $node2Bc_href->{$key};
                    my $size = keys %$h;
                    $href->{'bcCount'} = $size;
                } else {
                    webLog("no bc count for node: $key\n");

                    # $href->{'bcCount'} = 0;
                }
            }
        }
    }

    if ( $unclassifiedCount ne '' && $unclassifiedCount > 0 ) {

        # add a $unclassified parent / leaf node with count
        my @suba;
        for ( my $i = 0 ; $i <= $maxLevel ; $i++ ) {
            my %subhash;
            if ( $i == 0 ) {
                $subhash{'key'}    = '-1';
                $subhash{'name'}   = 'Unclassified';
                $subhash{'isLeaf'} = 'true';
                $subhash{'count'}  = $unclassifiedCount;
                push( @suba, \%subhash );
            } else {
                push( @suba, "-" );
            }
        }
        push( @array, \@suba );
    }

    #webLog "printJson() array=\n";
    #webLog Dumper(\@array) . "\n";
    #webLog Dumper($allLeafNodesBcCount_href) . "\n";

    print encode_json( \@array );
}

sub mySort {

    # got hash keys $a and $b automatically
    return ecPadded($a) cmp ecPadded($b);
}

# $allNodes_href - ec to name
# $allLeafNodes_href - ec to count
# $unclassifiedCount - count
# $ecSorted_aref - sorted ec's of keys $allLeafNodes_href
sub printJsonEc {
    my ( $allNodes_href, $allLeafNodes_href, $unclassifiedCount ) = @_;

    # find the largest EC:1.1.1.1, EC:1.1.1.-, EC:1.1.-
    # max size or level
    my $maxLevel = 3;    # 0 to 3 = 4

    my %distinctDxxCounts;    # ECxx.... => count of EC in children
    my $key;                  # ECxx.xx.xx
    my @array;                # array of array to be converted to json
                              #foreach my $ec ( sort keys %$allLeafNodes_href ) {
                              #foreach my $ec ( sort { ecPadded($a) cmp ecPadded($b) } keys %$allLeafNodes_href ) {
    foreach my $ec ( sort mySort keys %$allLeafNodes_href ) {

        my $count = $allLeafNodes_href->{$ec};

        #webLog("$ec == $count ---- $unclassifiedCount\n");
        my $ecTmp = $ec;
        $ecTmp =~ s/\.-$//;    # remove the .- at the end of the EC
        my @ecxx = split( /\./, $ecTmp );
        my $size = $#ecxx;

        # inner array for @array above
        # each obj is a hash or '-'
        my @suba;

        for ( my $i = 0 ; $i <= $maxLevel ; $i++ ) {
            my %subhash;
            if ( $i == $size ) {
                if ( $key ne '' ) {
                    $key = $key . '.' . $ecxx[$i];
                } else {

                    # root node as a leaf
                    $key = $ecxx[$i];
                }

                # make parent node for leaf
                my $tmp = $allNodes_href->{$key};
                if ( $tmp eq '' ) {
                    $tmp = $allNodes_href->{ $key . '.-' };
                    $key .= '.-';
                    $distinctDxxCounts{ $key . '.-' } = 0;    # initialize
                } else {
                    $distinctDxxCounts{$key} = 0;             # initialize
                }
                $tmp = 'n/a' if ( $tmp eq '' );
                $subhash{'key'}    = $key;
                $subhash{'name'}   = $tmp;
                $subhash{'count'}  = $count if ( $count ne '' && $count > 0 );
                $subhash{'isLeaf'} = 'false';

                if ( $key !~ /-$/ ) {

                    # leaf node
                    $subhash{'isLeaf'} = 'true';
                }

                push( @suba, \%subhash );

            } elsif ( $i < $size ) {
                if ( $i == 0 ) {

                    # root node with children
                    $key = $ecxx[$i];
                } else {
                    $key = $key . '.' . $ecxx[$i];
                }

                my $tmp = $allNodes_href->{$key};
                if ( $tmp eq '' ) {
                    $tmp = $allNodes_href->{ $key . '.-' };
                    $distinctDxxCounts{ $key . '.-' } = 0;    # initialize
                } else {
                    $distinctDxxCounts{$key} = 0;    # initialize
                }
                $tmp = 'n/a' if ( $tmp eq '' );
                if ( $i == 0 ) {

                    # root
                    $subhash{'key'}    = $key . '.-';
                    $subhash{'name'}   = $tmp;
                    $subhash{'isLeaf'} = 'false';
                    $subhash{'count'}  = $count if ( $count ne '' && $count > 0 );
                    @suba              = ();
                    push( @suba, \%subhash );
                } else {

                    # sub child but not a leaf node
                    $subhash{'key'}    = $key . '.-';
                    $subhash{'name'}   = $tmp;
                    $subhash{'count'}  = $count if ( $count ne '' && $count > 0 );
                    $subhash{'isLeaf'} = 'false';

                    #$subhash{'count'}  = $count;
                    push( @suba, \%subhash );

                }
            } else {
                push( @suba, "-" );
            }
        }

        $key = '';
        push( @array, \@suba );
    }

    #[
    #
    #    [
    #        {
    #            "count": "5519",
    #            "name": "Oxidoreductases.",
    #            "isLeaf": "false",
    #            "key": "EC:1.-"
    #        },
    #        "-",
    #        "-",
    #        "-"
    #    ],
    #    [
    #        {
    #            "count": "4983",
    #            "name": "Oxidoreductases.",
    #            "isLeaf": "false",
    #            "key": "EC:1.-"
    #        },
    #        {
    #            "count": "4983",
    #            "name": "Oxidoreductases. Acting on the CH-OH group of donors.",
    #            "isLeaf": "false",
    #            "key": "EC:1.1.-"
    #        },
    #        "-",
    #        "-"
    #    ],
    #    [
    #        {
    #            "count": "6922",
    #            "name": "Oxidoreductases.",
    #            "isLeaf": "false",
    #            "key": "EC:1.-"
    #        },
    #        {
    #            "count": "6922",
    #            "name": "Oxidoreductases. Acting on the CH-OH group of donors.",
    #            "isLeaf": "false",
    #            "key": "EC:1.1.-"
    #        },
    #        {
    #            "count": "6922",
    #            "name": "Oxidoreductases. Acting on the CH-OH group of donors. With NAD(+) or NADP(+) as acceptor.",
    #            "isLeaf": "false",
    #            "key": "EC:1.1.1.-"
    #        },
    #        "-"
    #    ],
    #    [
    #print encode_json( \@array );
    #exit 0;

    # calc counts for parent nodes
    foreach my $sub_aref (@array) {
        my $count = 0;
        foreach my $href (@$sub_aref) {
            last if ( $href eq '-' );

            # find leaf node with count
            if ( exists $href->{'count'} ) {
                $count = $href->{'count'};

                #last;    # this should be the leaf node
            }
        }

        # update parent(s) ECxx node with counts
        foreach my $href (@$sub_aref) {
            last if ( $href eq '-' );

            my $dxx = $href->{'key'};
            $distinctDxxCounts{$dxx} = $distinctDxxCounts{$dxx} + $count;
        }
    }
    foreach my $sub_aref (@array) {

        # update parent node with counts
        foreach my $href (@$sub_aref) {
            last if ( $href eq '-' );

            #if ( $href->{'isLeaf'} eq 'false' ) {
            my $dxx = $href->{'key'};
            $href->{'count'} = $distinctDxxCounts{$dxx};

            #}

        }
    }

    if ( $unclassifiedCount ne '' && $unclassifiedCount > 0 ) {

        # add a $unclassified parent / leaf node with count
        my @suba;
        for ( my $i = 0 ; $i <= $maxLevel ; $i++ ) {
            my %subhash;
            if ( $i == 0 ) {
                $subhash{'key'}    = '-1';
                $subhash{'name'}   = 'Unclassified';
                $subhash{'isLeaf'} = 'true';
                $subhash{'count'}  = $unclassifiedCount;
                push( @suba, \%subhash );
            } else {
                push( @suba, "-" );
            }
        }
        push( @array, \@suba );
    }

    print encode_json( \@array );
}

############################################################################
# img ANI phylo tree
############################################################################
sub printTreeJsonANIPhylo {
    my $domainfilter = param('domainfilter');
    my $seqstatus = param('seqstatus');
    my $array_ref = getTreePhylo( $domainfilter, 'ani', $seqstatus );
    print encode_json($array_ref);
}

############################################################################
# img BC phylo tree
############################################################################
sub printTreeJsonBcPhylo {
    my $domainfilter = param('domainfilter');
    my $seqstatus = param('seqstatus');
    my $array_ref = getTreePhylo( $domainfilter, 'bc', $seqstatus );
    print encode_json($array_ref);
}

############################################################################
# img SM phylo tree
############################################################################
sub printTreeJsonNpPhylo {
    my $domainfilter = param('domainfilter');
    my $seqstatus = param('seqstatus');
    my $array_ref = getTreePhylo( $domainfilter, 'np', $seqstatus );
    print encode_json($array_ref);
}

############################################################################
# get BC/NP tree phylo
############################################################################
sub getTreePhylo {
    my ( $domainfilter, $treeType, $seqstatus ) = @_;

    my $Unassigned = 'Unassigned';
    my $delim      = '||';

    my $contact_oid = WebUtil::getContactOid();
    my $cacheFilename;
    my ( $sql, @binds );
    if ( $treeType eq 'np' ) {
        ( $sql, @binds ) = getTreeNpPhyloSql($domainfilter, $seqstatus);
        $cacheFilename = 'getTreeNpPhyloSql_' . $domainfilter . '_' . $seqstatus . '_' . $contact_oid;
    } elsif ( $treeType eq 'ani' ) {
        ( $sql, @binds ) = getTreeANIPhyloSql($domainfilter, $seqstatus);
        $cacheFilename = 'getTreeANIPhyloSql_' . $domainfilter . '_' . $seqstatus . '_' . $contact_oid;
    } else {
        ( $sql, @binds ) = getTreeBcPhyloSql($domainfilter, $seqstatus);
        $cacheFilename = 'getTreeBcPhyloSql_' . $domainfilter . '_' . $seqstatus . '_' . $contact_oid;
    }

    my $dbh = dbLogin();
    my $aref = OracleUtil::execSqlCached
	($dbh, $sql, $cacheFilename, 0, @binds);

    my %key2count;
    my @array;

    foreach my $inner_aref (@$aref) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family,
	     $genus, $species, $seq_status, $taxon_oid, $cnt ) = @$inner_aref;
        my @suba;

        my $key = $domain;
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $domain = $Unassigned if ( !$domain );
        $subhash{'name'}   = $domain;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

        my $key = "$domain$delim$phylum";
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $phylum = $Unassigned if ( !$phylum );
        $subhash{'name'}   = $phylum;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

        my $key = "$domain$delim$phylum$delim$ir_class";
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $ir_class = $Unassigned if ( !$ir_class );
        $subhash{'name'}   = $ir_class;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

        my $key = "$domain$delim$phylum$delim$ir_class$delim$ir_order";
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $ir_order = $Unassigned if ( !$ir_order );
        $subhash{'name'}   = $ir_order;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

        my $key = "$domain$delim$phylum$delim$ir_class$delim$ir_order$delim$family";
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $family = $Unassigned if ( !$family );
        $subhash{'name'}   = $family;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

        my $key = "$domain$delim$phylum$delim$ir_class$delim$ir_order$delim$family$delim$genus";
        $key2count{$key} += $cnt;
        my %subhash;
        $subhash{'key'} = $key;
        $genus = $Unassigned if ( !$genus );
        $subhash{'name'}   = $genus;
        $subhash{'isLeaf'} = 'false';
        push( @suba, \%subhash );

	my $anikey;
	if ($treeType eq "ani") {
	    $species = $Unassigned if ( !$species );
	    my @a = split( /\s+/, $species );
	    if ( $#a >= 1 ) {
		$species = $a[1];
	    }
	    $anikey = "$genus $species";
	}

        my %subhash;
	if ($treeType eq "ani") {
            $subhash{'count'} = $cnt; 
            $subhash{'key'} = $anikey;
            $subhash{'name'} = $anikey;
            $subhash{'isLeaf'} = 'true';
            $subhash{'tooltip'} = $cnt.' total clique(s) for species: '.$anikey;

	} else {
	    $subhash{'key'} = $taxon_oid;
	    $species = $Unassigned if ( !$species );
	    $subhash{'name'} = $species;
	    $subhash{'isLeaf'} = 'true';
	    my $d = substr( $domain, 0, 1 );
	    $seq_status = substr( $seq_status, 0, 1 );
	    $subhash{'status'} = "($d)[$seq_status]";
	    $subhash{'count'} = $cnt;
	}
        push( @suba, \%subhash );

        push( @array, \@suba );
    }

    #webLog "getTreePhylo() key2count=\n";
    #webLog Dumper(\%key2count) . "\n";

    foreach my $suba_ref (@array) {
        if ($suba_ref) {
            foreach my $subhash_href (@$suba_ref) {
                if ( $subhash_href && $subhash_href->{'isLeaf'} eq 'false' ) {
                    my $key = $subhash_href->{'key'};
                    $subhash_href->{'count'} = $key2count{$key};
                }
            }
        }
    }

    #webLog "getTreePhylo() array=\n";
    #webLog Dumper(\@array) . "\n";

    return ( \@array );
}

sub getTreeANIPhyloSql {
    my ($domainfilter, $seqstatus) = @_;

    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause("t");

    my $domainClause;
    my @binds;
    if ($domainfilter && $domainfilter ne 'all') {
        $domainClause = 'and t.domain = ? ';
        push( @binds, $domainfilter );
    }
    my $statusClause;
    if ($seqstatus && $seqstatus ne "both") {
	$statusClause = 'and t.seq_status = ? ';
	push( @binds, $seqstatus );
    }

    #TODO Anna -what exactly do we need here?
    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, 
               t.family, t.genus, t.species,
               t.seq_status, '', count(distinct acm.clique_id)
        from ani_clique_members acm, taxon t
        where acm.members = t.taxon_oid
        $domainClause
        $statusClause
        $rclause
        $imgClause
        group by t.domain, t.phylum, t.ir_class, t.ir_order,
                 t.family, t.genus, t.species, t.seq_status
        order by t.domain, t.phylum, t.ir_class, t.ir_order, 
                 t.family, t.genus, t.species, t.seq_status
    };

    return ( $sql, @binds );
}

sub getTreeBcPhyloSql {
    my ($domainfilter, $seqstatus) = @_;

    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause("t");

    my $domainClause;
    my @binds;
    if ( $domainfilter && $domainfilter ne 'all' ) {
        $domainClause = 'and t.domain = ? ';
        push( @binds, $domainfilter );
    }
    my $statusClause;
    if ($seqstatus && $seqstatus ne "both") {
	$statusClause = 'and t.seq_status = ? ';
	push( @binds, $seqstatus );
    }

    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, 
               t.family, t.genus, t.species, 
               t.seq_status, t.taxon_oid, count(distinct g.cluster_id)
        from bio_cluster_new g, taxon t
        where g.taxon = t.taxon_oid
        $domainClause
        $statusClause
        $rclause
        $imgClause
        group by t.domain, t.phylum, t.ir_class, t.ir_order, 
                 t.family, t.genus, t.species, t.seq_status, t.taxon_oid
        order by t.domain, t.phylum, t.ir_class, t.ir_order,
                 t.family, t.genus, t.species, t.seq_status, t.taxon_oid
    };

    return ( $sql, @binds );
}

sub getTreeNpPhyloSql {
    my ($domainfilter, $seqstatus) = @_;

    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause("t");

    my $domainClause;
    my @binds;
    if ( $domainfilter && $domainfilter ne 'all' ) {
        $domainClause = 'and t.domain = ? ';
        push( @binds, $domainfilter );
    }
    my $statusClause;
    if ($seqstatus && $seqstatus ne "both") {
	$statusClause = 'and t.seq_status = ? ';
	push( @binds, $seqstatus );
    }

    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, 
               t.family, t.genus, t.species, 
               t.seq_status, t.taxon_oid, count(distinct np.compound_oid)
        from np_biosynthesis_source np, taxon t
        where np.taxon_oid = t.taxon_oid
        $domainClause
        $statusClause
        $rclause
        $imgClause
        group by t.domain, t.phylum, t.ir_class, t.ir_order,
                 t.family, t.genus, t.species, t.seq_status, t.taxon_oid
        order by t.domain, t.phylum, t.ir_class, t.ir_order, 
                 t.family, t.genus, t.species, t.seq_status, t.taxon_oid
    };

    return ( $sql, @binds );
}

############################################################################
# printNodeActivity
############################################################################
sub printNodeActivity {
    my $meshId     = param('meshId');
    my $compoundId = param('compoundId');
    my $name       = param('name');

    #print qq{
    #    mesh id: $meshId <br>
    #    compoundId: $compoundId <br>
    #};
    if ( !$meshId ) {
        WebUtil::webError("No mesh ID.");
    }

    my $dbh = dbLogin();

    my $sql = qq{
        select distinct md.node, md.name 
        from img_compound_activity ia, mesh_dtree md
        where md.node like ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $meshId );
    my $nodeName;
    for ( ; ; ) {
        my ( $node, $name ) = $cur->fetchrow();
        last if !$node;
        $nodeName = $name;
    }
    $cur->finish();

    my @binds = ("$meshId%");
    my $compoundClause;
    if ($compoundId) {
        $compoundClause = "and ia.compound_oid = ? ";
        push( @binds, $compoundId );
    }

    my $nameClause;
    if ( $name ne '' ) {
        $nameClause = "and md.name = ?";
        push( @binds, $name );
    }

    my $sql = qq{
        select distinct ia.compound_oid, md.node, md.name
        from np_biosynthesis_source nbs, img_compound_activity ia, mesh_dtree md
        where nbs.compound_oid = ia.compound_oid
        and ia.activity = md.node
        and md.node like ?
        $compoundClause
        $nameClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    #my %node2name;
    my %compId2leafNodeName;
    for ( ; ; ) {
        my ( $comp_id, $node, $name ) = $cur->fetchrow();
        last if !$comp_id;

        #$node2name{$node} = $name;
        $compId2leafNodeName{$comp_id} = $name;
    }
    $cur->finish();

    my @leafCompoundIds = keys %compId2leafNodeName;
    require NaturalProd;
    NaturalProd::listAllNaturalProds( $dbh, 'NP Activity', $nodeName, \@leafCompoundIds );

}

1;
