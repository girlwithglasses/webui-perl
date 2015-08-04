#
# generate a UPGMA tree from the cassettes that have one or more clusters
# $Id: OperonTree.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
#
package OperonTree;

my $section = "Operon";

use strict;
use CGI qw( :standard );
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp 'warningsToBrowser';
use DBI;
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;

#use lib '/home/kmavromm/img_ui';
use DrawTree;
use DrawTreeNode;

#use lib '/home/kmavromm/img_ui/';
use OperonSQL;
use OperonFunc;

my $env         = getEnv();
my $cgi_dir     = $env->{cgi_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};            # application tmp directory
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $verbose     = $env->{verbose};
my $tmp_dir     = $env->{tmp_dir};                # viewable image tmp directory
my $tmp_url     = $env->{tmp_url};
my $cluster_bin = $env->{cluster_bin};

###################################################################################
# main function for the generation of a tree
# showing the simililariteies between cassettes
# the similarity is simply the number of common gene clusters
# divided by the number of the smallest cassette.
####################################################################################
sub CassetteTree {
    my ( $method, $clusters, $gene_oids ) = @_;

    # retrieve the cassettes that have the first cluster
    # store the contents of each cassette in an hash
    # store the taxon name for each cassette in a separate hash
    printStatusLine( "Loading ...", 1 );
    print "<p>Retrieving cassettes...<br></p>\n";

    my $sql = CassetteSQL( $method, ${$clusters}[0] );

    # 	print "<p> $sql </p>\n";
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, ${$clusters}[0] );
    my %cassetteContent;
    my %cassetteTaxon;
    my $cassetteIDX = 0;
    my %Hcassette;
    my %RHcassette;

    while ( my ( $cassette, $gene, $cluster_name, $taxon_name ) =
            $cur->fetchrow_array() )
    {

        #print "$cassette<br>\n";
        if ( !$Hcassette{$cassette} ) {
            $cassetteIDX++;
            $Hcassette{$cassette}     = $cassetteIDX;
            $RHcassette{$cassetteIDX} = $cassette;
        }
        my $cass = $Hcassette{$cassette};
        $cassetteTaxon{$cass} = $taxon_name;
        if ($cluster_name) {
            $cassetteContent{$cass} .= $cluster_name . ":";
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    # keep only the cassettes that have the specified clusters
    %cassetteContent = KeepCassette( \%cassetteContent, $clusters );

    #clustering can be performed only if we have three or more cassettes
    if ( scalar( keys(%cassetteContent) ) < 3 ) {
        printStatusLine( "Loaded.", 2 );
        webError("Clustering can be performed with at least 3 cassettes");
    }
    my %idRef;
    my %isHighLighted;

    # find the cassettes that harbor the genes we started from
    if ($gene_oids) {

        my @gene_oids = @{$gene_oids};
        print "<p> Original genes @gene_oids<br></p>\n";
        my $gstr = join( qq{','}, @gene_oids );
        my $sql = qq{
            select cassette_oid,gene 
            from gene_cassette_genes 
            where gene in '$gstr'
        };
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose );
        while ( my ( $cass, $gene ) = $cur->fetchrow_array() ) {
            $isHighLighted{$cass} = 1;
            print "<p>Cassette $cass contains the $gene</p>\n";
        }
        $cur->finish();
        #$dbh->disconnect();

    }

    foreach my $k ( keys(%cassetteContent) ) {
        my $url =
          url()
          . "?section=GeneCassette&page=cassetteBox&cassette_oid=$RHcassette{$k}&type=$method";

        if ( $isHighLighted{ $RHcassette{$k} } ) {
            print "<p> Cassette $RHcassette{$k} has been identified</p>\n";
            $idRef{$k} = "$cassetteTaxon{$k} ($RHcassette{$k}) *\t";
            $idRef{$k} .= "1\t";
        } else {
            $idRef{$k} = "$cassetteTaxon{$k} ($RHcassette{$k})\t";
            $idRef{$k} .= "0\t";
        }
        $idRef{$k} .= "$cassetteContent{$k}\t";
        $idRef{$k} .= "$url\t";

    }

    cassetteCluster( \%cassetteContent, \%idRef );
    print
"<p>Hierarchical clustering of chromosomal cassettes containing gene clusters @{$clusters}.<br></p>\n";
    printStatusLine( scalar( keys(%cassetteContent) ) . " cassettes loaded.",
                     2 );

}
###########################################################
#create a "distance matrix" based on the occurences of
#the clusters and
#do hierarchical clustering
#
##########################################################
# create vectors for each cassette
# first create a list of all the available clusters
# and then populate this list for each cassette
# returns
# a ref to an array of the values of the vertical axis
# a ref to an array of the values of the horizontal axis
# a ref to a hash with the values of the table
sub getCassettesVectors {
    my ($cassetteContent) = @_;
    my %cassetteContent = %{$cassetteContent};

    # create a list of all the available gene clusters
    my @clusterList  = ();
    my @cassetteList = keys(%cassetteContent);
    my %cassetteVector;
    foreach my $cassettes (@cassetteList) {

        # 		print "<p> Creating vector for cassette $cassettes</p>\n";
        my @clusters = split( ":", $cassetteContent{$cassettes} );
        @clusterList = ( @clusterList, @clusters );
        @clusterList = OperonFunc::unique( \@clusterList, 1 );
        my %profile;
        foreach my $cluster (@clusters) {
            $profile{$cluster}++;
        }
        $cassetteVector{$cassettes} = \%profile;
    }
    @clusterList  = sort { $a cmp $b } @clusterList;
    @cassetteList = sort { $a <=> $b } @cassetteList;
    return ( \@cassetteList, \@clusterList, \%cassetteVector );
}

# run cluster
sub cassetteCluster {
    my ( $cassRef, $idRef ) = @_;
    my %cassContent    = %{$cassRef};
    my $tmpProfileFile = "$cgi_tmp_dir/cassProfile$$.tab.txt";
    my $tmpClusterRoot = "$cgi_tmp_dir/cluster$$";
    my $tmpClusterCdt  = "$cgi_tmp_dir/cluster$$.cdt";
    my $tmpClusterGtr  = "$cgi_tmp_dir/cluster$$.gtr";
    my $wfh = newWriteFileHandle( $tmpProfileFile, "cassetteCluster" );
    my $s   = "id\t";

    my ( $cass_oids, $cluster_oids, $profile_ref ) =
      getCassettesVectors($cassRef);
    my %profile = %{$profile_ref};
    for my $i ( @{$cluster_oids} ) {
        $s .= "$i\t";
    }
    chop $s;
    print $wfh "$s\n";

    for my $cass_oid ( @{$cass_oids} ) {
        print $wfh "$cass_oid\t";
        my $lprofile_ref = $profile{$cass_oid};
        my $line;
        for my $k ( @{$cluster_oids} ) {
            my $cnt = 0;
            if ( $lprofile_ref->{$k} ) {
                $cnt = $lprofile_ref->{$k};
            }
            $line .= "$cnt\t";
        }
        chop $line;
        print $wfh "$line\n";

    }
    close $wfh;

    # run the program cluster
    WebUtil::unsetEnvPath();
    print "<p>Clustering cassettes<br>\n";
    my $cmd = "$cluster_bin -g 1 -m s -f $tmpProfileFile -u $tmpClusterRoot";
    runCmd($cmd);

    # 	print "$cmd<br>\n";
    WebUtil::resetEnvPath();
    print "<\p>\n";

    # draw the Tree
    my $dt = new DrawTree();
    $dt->loadGtrCdtFiles( $tmpClusterGtr, $tmpClusterCdt, $idRef );
    my $tmpFile = "drawTree$$.png";
    my $outFile = "$tmp_dir/$tmpFile";
    my $outURL  = "$tmp_url/$tmpFile";
    $dt->drawToFile($outFile);
    my $s = $dt->getMap( $outURL, 0 );
    print "$s\n";

    wunlink($tmpProfileFile);
    wunlink($tmpClusterCdt);
    wunlink($tmpClusterGtr);

}

# filter the cassettes and keep only those that have all the clusters
sub KeepCassette {
    my ( $cassette, $clusters ) = @_;
    my %cassette  = %{$cassette};
    my @cassettes = keys(%cassette);
    my %returnHash;
    foreach my $cas (@cassettes) {

        #		print "$cas: $cassette{$cas}<br>";
        my @a = split( ":", $cassette{$cas} );
        @a = sort { clusterCMP( $a, $b ) } @a;
        if (
             scalar( OperonFunc::intersect( $clusters, \@a ) ) !=
             scalar( @{$clusters} ) )
        {
            next;
        }

        #		print "$cas: accepted<br>\n";
        $returnHash{$cas} = join( ":", @a );
    }
    return %returnHash;
}

# remove the 'pfam' 'COG' string from a protein family description
sub clusterCMP {
    my ( $a, $b ) = @_;
    $a =~ s/COG//;
    $a =~ s/pfam//;
    $b =~ s/COG//;
    $b =~ s/pfam//;
    if ( $a < $b )  { return -1; }
    if ( $a >= $b ) { return 1; }
}

# return an sql query that retrieves the cassettes that contain a specific gene cluster
sub CassetteSQL {
    my ( $method, $cluster_id ) = @_;
    my $sql;
    my $imgClause = WebUtil::imgClause('t');
    $sql = qq{
		select gcg2.cassette_oid,gcg2.gene,pf2.pfam_family,t.taxon_name
		from gene_pfam_families pf1 
		join gene_cassette_genes gcg1 on pf1.gene_oid=gcg1.gene
		join gene_cassette_genes gcg2 on gcg1.cassette_oid=gcg2.cassette_oid
		join gene g on gcg2.gene=g.gene_oid
		join taxon t on t.taxon_oid=g.taxon
		left join gene_pfam_families pf2 on gcg2.gene=pf2.gene_oid
		where pf1.pfam_family= ?
		$imgClause
	} if lc($method) eq 'pfam';
    $sql = qq{
		select gcg2.cassette_oid,gcg2.gene,cg2.cog,t.taxon_name
		from gene_cog_groups cg1 
		join gene_cassette_genes gcg1 on cg1.gene_oid=gcg1.gene
		join gene_cassette_genes gcg2 on gcg1.cassette_oid=gcg2.cassette_oid
		join gene g on gcg2.gene=g.gene_oid
		join taxon t on t.taxon_oid=g.taxon
		left join gene_cog_groups cg2 on gcg2.gene=cg2.gene_oid
		where cg1.cog= ?
		$imgClause
	} if lc($method) eq 'cog';
    $sql = qq{
		select gcg2.cassette_oid,gcg2.gene,cg2.cluster_id,t.taxon_name
		from bbh_cluster_member_genes cg1 
		join gene_cassette_genes gcg1 on cg1.member_genes=gcg1.gene
		join gene_cassette_genes gcg2 on gcg1.cassette_oid=gcg2.cassette_oid
		join gene g on gcg2.gene=g.gene_oid
		join taxon t on t.taxon_oid=g.taxon
		left join bbh_cluster_member_genes cg2 on gcg2.gene=cg2.member_genes
		where cg1.cluster_id= ?
		$imgClause
	} if lc($method) eq 'bbh';
    return $sql;
}

1;
