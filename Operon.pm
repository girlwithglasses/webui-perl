############################################################################
# Operon - Function prediction based on chromosomal clusters.
#    --km 07/30/2007
#
# $Id: Operon.pm 30400 2014-03-12 19:20:25Z klchu $
############################################################################
package Operon;
my $section = "Operon";

use strict;

use CGI qw( :standard );
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp 'warningsToBrowser';
use Bio::Perl;
use Bio::TreeIO;
use DBI;
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use OperonSQL;
use OperonFunc;
use OperonTree;
use OperonFile;

use HtmlUtil;

my $env         = getEnv();
my $cgi_dir     = $env->{cgi_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};            # application tmp directory
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $verbose     = $env->{verbose};
my $tmp_dir     = $env->{tmp_dir};                # viewable image tmp directory
my $tmp_url     = $env->{tmp_url};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_internal         = $env->{img_internal};
my $base_url             = $env->{base_url};
my $user_restricted_site = $env->{user_restricted_site};

# file version
#my $img_ken = $env->{ img_ken };
my $OPERON_DATA_DIR = $env->{operon_data_dir};

############################################################################
# dispatch - Dispatch to right page based on page
############################################################################
sub dispatch {
    my $sid  = getContactOid();
    my $page = param("page");

    ################################################################
    # show the table with the connections between protein families
    ################################################################
    if ( $page eq "geneConnections" ) {
        my $expansion = param("expansion");

        #depending if the script is called for a gene or a cluster
        my @geneCluster = ();
        my $method      = param("clusterMethod");
        if (     lc($method) ne 'cog'
             and lc($method) ne 'pfam'
             and lc($method) ne 'bbh' )
        {
            webError "This feature has not been implemented yet";
        }
        if ( param("genePageGeneOid") ) {

            my @gene_oids = param("genePageGeneOid");


           HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;

            foreach my $geneComp (@gene_oids) {
                @geneCluster =
                  ( @geneCluster, &getGeneCluster( $geneComp, $method ) );
            }
            @geneCluster = OperonFunc::unique( \@geneCluster, 2 );
        }
        if ( param("genePageClusterid") ) {
            my $cluster_id = param("genePageClusterid");
            push @geneCluster,
              [
                $cluster_id, &OperonSQL::getClusterName( $cluster_id, $method )
              ];
        }

        if ( !$expansion or $expansion == 2 ) {
            GeneConnections(@geneCluster);
        } else {
            GeneExpandedConnections(@geneCluster);
        }

        if ( param("genePageGeneOid") ) {
            HtmlUtil::cgiCacheStop();
        }

    } elsif ( $page eq "geneConnectionsGraph" ) {
        ################################################################
        # show the graph (network viewer) with the connections
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        if ( $OPERON_DATA_DIR ne "" ) {
            showConnectionsGraph2( $method, \@clusters );
        } else {
            showConnectionsGraph( $method, \@clusters );
        }
    } elsif ( $page eq "cassetteTree" ) {
        ################################################################
        # show the hierarchical clustering tree of cassettes
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        if ( param("genePageGeneOid") ) {
            my @gene_oids = param("genePageGeneOid");


           HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;

            OperonTree::CassetteTree( $method, \@clusters, \@gene_oids );

            HtmlUtil::cgiCacheStop();
        } else {
            OperonTree::CassetteTree( $method, \@clusters );
        }
    } elsif ( $page eq "genomeWithClusters" ) {
        ################################################################
        # show the list of genomes with a set of clusters
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        getGenomesWithCluster( \@clusters, $method );
    } elsif ( $page eq "genomeWithClustersCassette" ) {
        ################################################################
        # show the list of genomes with a set of clusters in cassette
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        getGenomesWithClusterCassette( \@clusters, $method );
    } elsif ( $page eq "genomeWithClustersFusion" ) {
        ################################################################
        # show the list of genomes with a set of clusters in fusions
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        getGenomesWithClusterFusion( \@clusters, $method );
    } elsif ( $page eq "cassettesWithClusters" ) {
        ################################################################
        # show the cassettes that have a set of clusters
        ################################################################

        my $method   = param("clusterMethod");
        my $taxon    = param("taxon_oid");
        my @clusters = param("geneClusters");
        print "<p> Method: $method, Taxon: $taxon, Clusters @clusters</p>\n";
        getCassettesWithCluster( \@clusters, $method, $taxon );
    } elsif ( $page eq "fusionsWithClusters" ) {
        ################################################################
        # show the fusions that have a set of clusters
        ################################################################

        my $method   = param("clusterMethod");
        my @clusters = param("geneClusters");
        my $taxon    = param("taxon_oid");
        getFusionsWithCluster( \@clusters, $method, $taxon );
    } else {
        printMainOperonPage();
    }
}

############################################################################
# printMainOperonPage - Default main page.

# prints a menu that prompts the user to select the method that the clustering
# was made (cog, pfam, bbh)
############################################################################
sub printMainOperonPage {
    my ($gene_oid) = param("genePageGeneOid");
    my $cluster_method = param("clusterMethod");
    print "<h1>Context analysis based on protein families.</h1>\n";
    print "<p>\n";
    print
"Context analysis is based on protein clusters found together (a) in multiple organisms (cooccurrence), ";
    print
      "(b) found in conserved chromosomal clusters, (c) fusion events.<br>\n";

    print "</p>\n";

    my @gene_oids = ($gene_oid);
    print
"<p>The query gene $gene_oid belongs to the following protein clusters:<br></p>\n";

    # get the clusters of each gene_oid
    my @methods = ( 'cog', 'pfam', 'bbh' );
    print qq{<table class='img' border='1'>
			<tr class='img'>};
    print
qq{<tr class='highlight'><td class='img'><b>Protein clusters</b></td></tr>};
    foreach my $method (@methods) {
        my $strCluster = &OperonFunc::clusterString($method);

        my @geneCluster = ();
        foreach my $geneComp (@gene_oids) {
            @geneCluster =
              ( @geneCluster, &getGeneCluster( $geneComp, $method ) );
        }
        @geneCluster = OperonFunc::unique( \@geneCluster, 2 );
        for ( my $i = 0 ; $i < scalar(@geneCluster) ; $i++ ) {
            print qq{<tr class='img'><td class='img'><b>$strCluster</b></td>};
            print
qq{<td class='img'>$geneCluster[$i][0] : $geneCluster[$i][1]</td></tr>};
        }

    }
    print qq{</table>};
    print "<p>Please select a clustering method to view the results.<br></p>\n";

    my $url = url();
    print start_form(
                      -method => 'post',
                      -action => $url,
                      -name   => 'selectMethod'
    );

    # print the actual javascript for the popup menu
    &scriptForSelection( $url, $section, $gene_oid );
    print end_form();
    print qq{
		<div id='status_line_z2'>
		Loaded.
		</div>
	};

    printHint(
        "Correlation of genes is based in any of the above clustering methods. "
          . "Each method provides different analysis resolution. "
          . "Select COG for a general comparison between organisms and functions, "
          . "Bidirectional best hits for a more precise, but phylogenetically limited correlation "
          . "and Pfams for protein domain based analyses." );

}

############################################################
############################################################
# cassette tree viewers
############################################################
############################################################

##########################################################
# Prints a button that triggers the creation of a tree
# of all the cassettes with a set of gene clusters
##########################################################
sub showButtonCassTreeForm {
    my ($geneCluster)  = @_;
    my $section        = param("section");
    my $cluster_method = param("clusterMethod");
    my $url            = url();
    print start_form(
                      -method => 'post',
                      -action => $url,
                      -name   => 'showCassTreeForm'
    );
    print hiddenVar( "section",       $section );
    print hiddenVar( "clusterMethod", $cluster_method );
    for ( my $c = 0 ; $c < scalar( @{$geneCluster} ) ; $c++ ) {
        print hiddenVar( "geneClusters", ${$geneCluster}[$c][0] );
    }
    print hiddenVar( "page", "cassetteTree" );
    if ( param("genePageGeneOid") ) {
        my @g = param("genePageGeneOid");
        foreach my $g (@g) {
            print hiddenVar( "genePageGeneOid", $g );
        }
    }
    print submit(
                  -name  => "showCassTree",
                  -value => "Cassette tree of current cluster",
                  -class => "medbutton"
    );
    print end_form();

}

#####################################################################
# show the tree of the connections between the clusters that belong
# to this specific family of genes.
# for this take the contents of each cassette and
# do hierarchical clustering using 'cluster'
# The tree is projected using Ernest's tree viewing tool
#####################################################################
sub showConnectionsTree {
    my ( $method, $cluster_id ) = @_;

    #  replace path with env in webconfig - old code
    my $dir     = "/home/kmavromm/img_ui/clusters/$method/";
    my $members = $dir . "/0.subdm";
    open( IN, $members ) or webError("cannot read file $members");
    my %id2Rec;
    while ( my $line = <IN> ) {
        chomp $line;
        my ( $el1, $el2, $t ) = split( "\t", $line );
        $id2Rec{$el1} = "$el1\t0\t$el1\t\t";
        $id2Rec{$el2} = "$el2\t0\t$el2\t\t";
    }
    close IN;
    my $tree    = $dir . "1.nwk";
    my $newick  = file2Str($tree);
    my $dt      = new DrawTree( $newick, \%id2Rec );
    my $tmpFile = "drawTree$$.png";
    my $outPath = "$tmp_dir/$tmpFile";
    my $outUrl  = "$tmp_url/$tmpFile";
    $dt->drawToFile($outPath);
    my $s = $dt->getMap( $outUrl, 0 );
    print "$s\n";

}

##################################################################
##################################################################
# network viewers
##################################################################
##################################################################

############################################################################
# show a button on top of a page that dispatches to the graph page
#############################################################################

sub showButtonNetworkForm {
    my $section        = param("section");
    my @geneClusters   = @_;
    my $cluster_method = param("clusterMethod");
    my $url            = url();

    #show a button to go to the graph
    print start_form(
                      -method => 'post',
                      -action => $url,
                      -name   => 'showGeneGraphForm'
    );
    print hiddenVar( "section", $section );
    for ( my $i = 0 ; $i < scalar(@geneClusters) ; $i++ ) {
        print hiddenVar( "geneClusters", $geneClusters[$i][0] );
    }
    print hiddenVar( "clusterMethod", $cluster_method );
    print hiddenVar( "page",          "geneConnectionsGraph" );
    print submit(
                  -name  => "showGeneGraph",
                  -value => "Show connections graph",
                  -class => "medbutton"
    );
    print end_form();
}

################################################################
# get the distances between the nodes
# use only members of the same family
# and only the top hits that include the query protein family
###############################################################
sub showConnectionsGraph {
    my ( $cluster_method, $geneClusters ) = @_;

    if (    lc($cluster_method) eq "cog"
         or lc($cluster_method) eq "bbh"
         or lc($cluster_method) eq "pfam" )
    {
        printStatusLine( "Loading distances...", 1 );
        printHint(
"Please be patient. Some large families might take several seconds to load." );

  # load from a table the connections of the query with genes of the same family
        my $sql =
          OperonSQL::getFamilyConnectionSQL( $geneClusters, $cluster_method );

        my @geneOrderConnections;
        my %neighbors;
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose );
        foreach my $c ( @{$geneClusters} ) {
            $neighbors{$c} = 1;
        }
        while ( my ( $el1, $el2, $d1, $d2, $d3, $an1, $an2 ) =
                $cur->fetchrow_array() )
        {

       #store the genes that neighbor our initial cluster in the %neighbors hash
            my ( $a, $b ) = (
                              OperonFunc::in( $geneClusters, $el1 ),
                              OperonFunc::in( $geneClusters, $el2 )
            );

            if ( $a >= 0 ) { $neighbors{$el2} = 1; }
            if ( $b >= 0 ) { $neighbors{$el1} = 1; }
            push @geneOrderConnections,
              [ $el1, $el2, $d1, $d2, $d3, $an1, $an2 ];

        }
        $cur->finish;
        #$dbh->disconnect();

# in order to be able to show something we need to keep the edges that have our gene
# and the edges between them
        my @graph;
        my $cutoff = 0;

        for ( my $i = 0 ; $i < scalar(@geneOrderConnections) ; $i++ ) {
            next if $geneOrderConnections[$i][2] <= $cutoff;

            # keep only the genes that are neighbors to our query gene
            if (     $neighbors{ $geneOrderConnections[$i][0] } == 1
                 and $neighbors{ $geneOrderConnections[$i][1] } == 1 )
            {
                push @graph,
                  [
                    $geneOrderConnections[$i][0],
                    $geneOrderConnections[$i][1],
                    $geneOrderConnections[$i][2],
                    $geneOrderConnections[$i][3],
                    $geneOrderConnections[$i][4],
                    $geneOrderConnections[$i][5],
                    $geneOrderConnections[$i][6]
                  ];
            }
        }

        # sort the edges because we need to keep only the top 500 of those
        @graph = sort { $$b[3] <=> $$a[3] } @graph;

        if ( scalar(@graph) == 0 ) {
            webError("There are no valid connections for @{$geneClusters}");
        } else {

            # Deploying the applet
            &DeployGraph( \@graph, $geneClusters );
        }
        printStatusLine( "Loading distances...", 1 );
    } else {
        webError("This feature has not been implemented yet.");
    }
}

sub showConnectionsGraph2 {
    my ( $cluster_method, $geneClusters ) = @_;

    print $cluster_method . " " . $geneClusters->[0] . "<br/>\n";

    if (    lc($cluster_method) eq "cog"
         or lc($cluster_method) eq "bbh"
         or lc($cluster_method) eq "pfam" )
    {
        printStatusLine( "Loading distances...", 1 );
        printHint(
"Please be patient. Some large families might take several seconds to load." );

  # load from a table the connections of the query with genes of the same family

        # fix for files - ken
        my $dbh          = dbLogin();
        my $results_aref =
          OperonFile::getFamilyConnections( $dbh, $geneClusters,
                                            $cluster_method );

        #$dbh->disconnect();

        my @geneOrderConnections;
        my %neighbors;

        foreach my $c ( @{$geneClusters} ) {
            $neighbors{$c} = 1;
        }

        foreach my $line (@$results_aref) {
            my ( $el1, $el2, $d1, $d2, $d3, $an1, $an2 ) = split( /\t/, $line );

       #store the genes that neighbor our initial cluster in the %neighbors hash
            my ( $a, $b ) = (
                              OperonFunc::in( $geneClusters, $el1 ),
                              OperonFunc::in( $geneClusters, $el2 )
            );

            if ( $a >= 0 ) { $neighbors{$el2} = 1; }
            if ( $b >= 0 ) { $neighbors{$el1} = 1; }
            push @geneOrderConnections,
              [ $el1, $el2, $d1, $d2, $d3, $an1, $an2 ];

        }

# in order to be able to show something we need to keep the edges that have our gene
# and the edges between them
        my @graph;
        my $cutoff = 0;

        for ( my $i = 0 ; $i < scalar(@geneOrderConnections) ; $i++ ) {
            next if $geneOrderConnections[$i][2] <= $cutoff;

            # keep only the genes that are neighbors to our query gene
            if (     $neighbors{ $geneOrderConnections[$i][0] } == 1
                 and $neighbors{ $geneOrderConnections[$i][1] } == 1 )
            {
                push @graph,
                  [
                    $geneOrderConnections[$i][0],
                    $geneOrderConnections[$i][1],
                    $geneOrderConnections[$i][2],
                    $geneOrderConnections[$i][3],
                    $geneOrderConnections[$i][4],
                    $geneOrderConnections[$i][5],
                    $geneOrderConnections[$i][6]
                  ];
            }
        }

        # sort the edges because we need to keep only the top 500 of those
        @graph = sort { $$b[3] <=> $$a[3] } @graph;

        if ( scalar(@graph) == 0 ) {
            webError("There are no valid connections for @{$geneClusters}");
        } else {

            # Deploying the applet
            &DeployGraph( \@graph, $geneClusters );
        }
        printStatusLine( "Loading distances...", 1 );
    } else {
        webError("This feature has not been implemented yet.");
    }
}

#######################################################
#use medusa applet to create a network view
#######################################################
sub DeployGraph {
    my ( $geneOrderP, $geneClusters ) = @_;
    my @geneOrder = @$geneOrderP;
    my $cnt       = 0;

    #initialize applet

    # TODO when this feature is not internal the applet should be rewritten to
    # located in a common/shared place
    # - 2008-03-11 ken
    printHint(   "<b>Edge colors</b>: <font color=green> Green</font>: "
               . "Phylogenetic correlation score, <font color=red> Red</font>: "
               . "Conserved neighborhood score, <font color=blue> Blue</font>: "
               . "Fusion correlation score" );

 #my $medusa_dir="http://bugmaster.jgi-psf.org/people/kmavromm/cgi-bin/medusa/";
    my $medusa_dir = $base_url;

    #	print qq{<applet
    #		code="medusa.applet.MedusaLite.class"
    #		codebase="$medusa_dir"
    #		archive="Medusa.jar" height="750" width="750">
    #
    #	};

    print qq{<applet
        code="medusa.applet.MedusaLite.class"
        codebase="$medusa_dir"
        archive="Medusa.jar" height="750" width="750">
        <PARAM name="java_arguments" value="-Xmx512m">  
        <param name="settings" value="0,0,0;100,255,100">
    };

    # plot edges
    print qq{<param name="edges" value="\n};
    my $last = scalar(@geneOrder);
    $last = 500 if $last > 500;

    #print "<p> $last edges out of ".scalar(@geneOrder)." are shown<\p>\n";
    for ( my $i = 0 ; $i < $last ; $i++ ) {

        print $geneOrder[$i][0] . ":"
          . $geneOrder[$i][1] . ":1:"
          . $geneOrder[$i][2] . ":0;\n"
          if ( $geneOrder[$i][2] > 0 );
        print $geneOrder[$i][0] . ":"
          . $geneOrder[$i][1] . ":2:"
          . $geneOrder[$i][3] . ":1;\n"
          if ( $geneOrder[$i][3] > 0 );
        print $geneOrder[$i][0] . ":"
          . $geneOrder[$i][1] . ":3:"
          . $geneOrder[$i][4]
          . ":-1;\n"
          if ( $geneOrder[$i][4] > 0 );
        $cnt++;
    }
    print qq{">\n};

    # define nodes
    print qq{<param name="nodes" value="\n};
    my %node;
    for ( my $i = 0 ; $i < $last ; $i++ ) {
        $geneOrder[$i][5] =~ s/\s/_/g;
        $geneOrder[$i][6] =~ s/\s/_/g;
        if ( !$node{ $geneOrder[$i][0] } ) {
            $node{ $geneOrder[$i][0] } = 1;
            my $shape = 4;
            my $color = "35,35,35";
            if ( OperonFunc::in( $geneClusters, $geneOrder[$i][0] ) >= 0 ) {
                $shape = 2;
                $color = "250,12,12";
            }

            print $geneOrder[$i][0]
              . ":350:350:$color:$shape:'$geneOrder[$i][5]';\n";
        }
        if ( !$node{ $geneOrder[$i][1] } ) {
            $node{ $geneOrder[$i][1] } = 1;
            my $shape = 4;
            my $color = "35,35,35";
            if ( OperonFunc::in( $geneClusters, $geneOrder[$i][1] ) >= 0 ) {
                $shape = 2;
                $color = "250,12,12";
            }
            print $geneOrder[$i][1]
              . ":350:350:$color:$shape:'$geneOrder[$i][6]';\n";
        }
    }
    print qq{">\n};

# 	example data to verify that the applet works
# 	print qq{
#  	<param name="edges"
# 	value="nodeA:node2:2:1:1.0;node1:node3:2:1:0.0;node1:node2:1:1:-1.0;node1:node2:3:1:1.0;">
# 	};
# 	print qq{<param
# 	name="nodes"
# 	value="nodeA:0.5:0.5:34,34,34:1;node2:0.8:0.4:234,234,34:2;"> };
    print qq{
	    <param name="X" value="730">
	    <param name="Y" value="710">
	    <param name="layout" value="true">
        <param name="cache_option" value="No">  
	    </applet>
	};
    printStatusLine( "$cnt edges loaded.", 2 );
}

########################################################
########################################################
# table view of the connections
########################################################
########################################################

############################################################################
# Get the data of the connections between protein families
############################################################################
sub GeneConnections {

    # 	my( $gene_oid ) = param( "genePageGeneOid" );
    my ($cluster_method) = param("clusterMethod");
    my ($expansion)      = param("expansion");
    my @geneCluster      = @_;

    #print the title of the page
    # add a more specific title that includes COGs or pfams or bbh
    my $strCluster = &OperonFunc::clusterString($cluster_method);
    print "<h1>Context analysis based on ${strCluster}s.</h1>\n";
    printStatusLine( "Loading ...", 1 );

    # TODO 3.0 not internal
    if ($img_internal) {

        # show the button that launches the network
        showButtonNetworkForm(@geneCluster);
    }
    if ($img_internal) {

        # tree is too big to show - png file cannot be display - ken 12-01-2009
        # show the button for the tree of a cassette
        showButtonCassTreeForm( \@geneCluster );
    }

    # query the database and retrieve all the genes that are connected
    # to the query gene
    my @geneOrderConnections = ();

    if ( $OPERON_DATA_DIR ne "" ) {
        webLog("=========== file version \n");
        @geneOrderConnections = (
                                  @geneOrderConnections,
                                  &getGeneCorrelation2(
                                              \@geneCluster, lc($cluster_method)
                                  )
        );

    } elsif (    lc($cluster_method) eq 'bbh'
              || lc($cluster_method) eq 'pfam'
              || lc($cluster_method) eq 'cog' )
    {

        @geneOrderConnections = (
                                  @geneOrderConnections,
                                  &getGeneCorrelation(
                                              \@geneCluster, lc($cluster_method)
                                  )
        );

    } else {
        webError("This feature has not been implemented yet.");
    }

    #sort the table on the score
    @geneOrderConnections = OperonFunc::unique( \@geneOrderConnections, 12 );

    #print a table with statistics
    #print the table with the connections
    my $tmp = printConnections( \@geneCluster, \@geneOrderConnections,
                                $expansion,    $cluster_method );
    printStatusLine( "$tmp Loaded.", 2 );
}

#

#
##############################################################
# Show the table with the gene connections
################################################################
sub printConnections {
    my ( $geneClusterP, $geneOrderP, $expansion, $cluster_method ) = @_;
    my @geneOrder   = @$geneOrderP;
    my @geneCluster = @$geneClusterP;
    my $strCluster  = &OperonFunc::clusterString($cluster_method);
    my %clusterTaxa;     #number of taxa that each cluster exists
    my %taxaCooccurence; #number of clusters that cooccur with the query cluster
    my %taxaNeighborhood
      ;                  #number of clusters that cooccur with the query cluster
    my %taxaFusions;     #number of clusters that cooccur with the query cluster

    my $it =
      new InnerTable( 1, "CorrelatedProteinClusters$$",
                      "CorrelatedProteinClusters", 11 );
    $it->addColSpec("Query $strCluster");
    $it->addColSpec( "Correlated $strCluster", "char asc", "left" );
    $it->addColSpec( "Genomes with<br>query $strCluster",
                     "", "", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Genomes with<br>correlated $strCluster",
                     "number desc", "left", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Genomes with<br>both $strCluster", "number desc",
                     "left",                             "bgcolor=#D2E6FF" );
    $it->addColSpec( "Genomes with<br>both $strCluster<br>in cassette",
                     "number desc", "left", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Genomes with<br>both $strCluster<br>in fusion ",
                     "number desc", "left", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Genome cooccurence ratio of<br>${strCluster}s ",
                     "number desc", "left" );
    $it->addColSpec( "Conserved neighborhood ratio of<br>${strCluster}s ",
                     "number desc", "left" );
    $it->addColSpec( "Fusion ratio of <br> ${strCluster}s",
                     "number desc", "left" );
    $it->addColSpec( "Genome cooccurence<br/> correlation score",
                     "number desc", "left", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Conserved neighborhood<br>correlation score",
                     "number desc", "left", "bgcolor=#D2E6FF" );
    $it->addColSpec( "Fusion<br>correlation score", "number desc",
                     "left",                        "bgcolor=#D2E6FF" );

    #if($img_internal) {
    $it->addColSpec(
               "Hierachical clustering<br>of cassettes<br>with ${strCluster}s");
    $it->addColSpec("Expansion");

    #}

    my $sd = $it->getSdDelim();    # sort delimiter

    for ( my $i = 0 ; $i < scalar(@geneOrder) ; $i++ ) {
        my $link =
            url()
          . "?section="
          . param("section")
          . "&page="
          . param("page")
          . "&expansion="
          . param("expansion")
          . "&clusterMethod="
          . param("clusterMethod");
        $link .= "&genePageClusterid=$geneOrder[$i][2]";
        my @geneClusters = ( $geneOrder[$i][0], $geneOrder[$i][2] );
        my $expansionURL =
          &expandedURL( $expansion + 1, $cluster_method, \@geneClusters );
        my $expansionName = &OperonFunc::expansionName( $expansion + 1 );

        my $cassetteTreeURL =
            url()
          . "?section="
          . param("section")
          . "&page=cassetteTree"
          . "&expansion="
          . param("expansion")
          . "&clusterMethod="
          . param("clusterMethod");
        $cassetteTreeURL .= "&geneClusters=$geneOrder[$i][0]";
        $cassetteTreeURL .= "&geneClusters=$geneOrder[$i][2]";
        $cassetteTreeURL .= provideGenes();
        my $r;
        $r .= $geneOrder[$i][0] . "\t";    # Query COG

        my $display = $geneOrder[$i][2] . " (" . $geneOrder[$i][3] . ")";
        $r .=
            $display . $sd
          . alink( $link, $geneOrder[$i][2] )
          . " $geneOrder[$i][3]"
          . "\t";                          # Correlated COG
        my $urlQuery = "";
        $urlQuery .=
            url()
          . "?section=CogCategoryDetail&page=ccdCogGenomeList&cog_id="
          . $geneOrder[$i][0]
          if lc($cluster_method) eq 'cog';
        $urlQuery .=
            url()
          . "?section=PfamCategoryDetail&page=pcdPfamGenomeList&pfam_id="
          . $geneOrder[$i][0]
          if lc($cluster_method) eq 'pfam';

# 		$urlQuery.=url()."?section=BBHCategoryDetail&page=bcdBBHGenomeList&bbh=".$geneOrder[$i][0] if lc($cluster_method) eq 'bbh';
        $r .= $geneOrder[$i][4];
        if ( $urlQuery ne "" ) {
            $r .= $sd . alink( $urlQuery, $geneOrder[$i][4] );
        }
        $r .= "\t";    # Genomes with query COG

        my $urlCorrelated = "";
        $urlCorrelated .=
            url()
          . "?section=CogCategoryDetail&page=ccdCogGenomeList&cog_id="
          . $geneOrder[$i][2]
          if lc($cluster_method) eq 'cog';
        $urlCorrelated .=
            url()
          . "?section=PfamCategoryDetail&page=pcdPfamGenomeList&pfam_id="
          . $geneOrder[$i][2]
          if lc($cluster_method) eq 'pfam';

# 		$urlCorrelated.=url()."?section=BBHCategoryDetail&page=bcdBBHGenomeList&bbh=".$geneOrder[$i][2] if lc($cluster_method) eq 'bbh';
        $r .= $geneOrder[$i][5];    # Genomes with correlated COG
        if ( $urlCorrelated ne "" ) {
            $r .= $sd . alink( $urlCorrelated, $geneOrder[$i][5] );
        }
        $r .= "\t";                 # Genomes with query COG

        my $urlGenomesWithClusters = "";
        $urlGenomesWithClusters =
            url()
          . "?section="
          . param("section")
          . "&page=genomeWithClusters&clusterMethod="
          . param("clusterMethod")
          . "&geneClusters=$geneOrder[$i][0]&geneClusters=$geneOrder[$i][2]";
        $r .=
            $geneOrder[$i][6] . $sd
          . alink( $urlGenomesWithClusters, $geneOrder[$i][6] )
          . "\t";    #Genomes with both COGs

        my $urlGenomesWithClustersCassette = "";
        $urlGenomesWithClustersCassette =
            url()
          . "?section="
          . param("section")
          . "&page=genomeWithClustersCassette&clusterMethod="
          . param("clusterMethod")
          . "&geneClusters=$geneOrder[$i][0]&geneClusters=$geneOrder[$i][2]";
        $r .=
            $geneOrder[$i][7] . $sd
          . alink( $urlGenomesWithClustersCassette, $geneOrder[$i][7] )
          . "\t";    #Genomes with both COGs in cassette

        my $urlGenomesWithClustersFusion = "";
        $urlGenomesWithClustersFusion =
            url()
          . "?section="
          . param("section")
          . "&page=genomeWithClustersFusion&clusterMethod="
          . param("clusterMethod")
          . "&geneClusters=$geneOrder[$i][0]&geneClusters=$geneOrder[$i][2]";
        $r .= $geneOrder[$i][8];

        if ( $geneOrder[$i][8] >= 1 and $cluster_method ne 'bbh' ) {
            $r .=
              $sd . alink( $urlGenomesWithClustersFusion, $geneOrder[$i][8] );
        }
        $r .= "\t";    #Genomes with both COGs in fusions
        my $minGenomes = min( $geneOrder[$i][4], $geneOrder[$i][5] );
        $r .= int( $geneOrder[$i][6] / $minGenomes * 100 ) . "\t";
        $r .= int( $geneOrder[$i][7] / $minGenomes * 100 ) . "\t";
        $r .= int( $geneOrder[$i][8] / $minGenomes * 100 ) . "\t";

        $r .= $geneOrder[$i][9] . "\t";
        $r .= $geneOrder[$i][10] . "\t";
        $r .= $geneOrder[$i][11] . "\t";

        #if($img_internal) {
        $r .= "T" . $sd . alink( $cassetteTreeURL, "T" ) . "\t";
        $r .=
          $expansionName . $sd . alink( $expansionURL, $expansionName ) . "\t";

        #}
        $it->addRow($r);

        $clusterTaxa{ $geneOrder[$i][0] } = $geneOrder[$i][4];

        # count the number of COGs that have score > 0
        #$taxaCooccurence{$geneOrder[$i][0]} ++ if $geneOrder[$i][9] >0;
        #$taxaNeighborhood{$geneOrder[$i][0]} ++ if $geneOrder[$i][10] >0;
        #$taxaFusions{$geneOrder[$i][0]} ++ if $geneOrder[$i][11] >0;
        $taxaCooccurence{ $geneOrder[$i][0] }++  if $geneOrder[$i][6] > 0;
        $taxaNeighborhood{ $geneOrder[$i][0] }++ if $geneOrder[$i][7] > 0;
        $taxaFusions{ $geneOrder[$i][0] }++      if $geneOrder[$i][8] > 0;

        #
    }

    #show the table with the statistics
    #show the hint that explains what the table shows
    print "<h2>Summary</h2>\n";
    print qq{<table class='img' border='1'>
			<tr class='img'>};
    foreach my $cluster ( keys(%clusterTaxa) ) {
        $taxaCooccurence{$cluster}  = 0 if !$taxaCooccurence{$cluster};
        $taxaNeighborhood{$cluster} = 0 if !$taxaNeighborhood{$cluster};
        $taxaFusions{$cluster}      = 0 if !$taxaFusions{$cluster};
        my $clusterName =
          OperonSQL::getClusterName( $cluster, $cluster_method );
        print qq{
			<tr class='highlight'><td class='img'><b>Query gene cluster</b></td>
				<td class='img'>$cluster : $clusterName</td></tr>
			<tr class='img'><td class='img'>Genomes with query $strCluster</td>
				<td class='img'>$clusterTaxa{$cluster}</td></tr>
			<tr class='img'><td class='img'>${strCluster}s in the same genomes and chromosomal cassettes with query $strCluster</td>
				<td class='img'>$taxaCooccurence{$cluster}</td></tr>
			<tr class='img'><td class='img'>${strCluster}s in the same conserved chromosomal cassette with query $strCluster</td>
				<td class='img'>$taxaNeighborhood{$cluster}</td></tr>
			<tr class='img'><td class='img'>${strCluster}s fused with query $strCluster</td>
				<td class='img'>$taxaFusions{$cluster}</td></tr>
			
		};
    }

    print qq{</table>};

    #show the hint that explains what the table shows
    print "<h2>List of correlated ${strCluster}s</h2>\n";

    printHint(
"<b>Phylogenetic correlation score</b> is based on the coocurrence of protein clusters in at least two genomes. "
          . "<b>Conserved neighborhood score</b> is based on the coocurrence of protein clusters in chromosomal cassettes "
          . "in at least two genomes. "
          . "<b>Fusion correlation score</b> is based on the participation of protein clusters in at least two fusion events.<br>"
          . "The higher the correlation score value, the more important this correlation is. "
          . "Values > 500 are highly significant for conserved chromosomal neighborhoods. "
          . "Values > 200 are highly significant for fusion events." );
    printHint(
"<b>Phylogenetic ratio</b> shows the dependence of the least abundant protein cluster to the most abundant based on their coocurrence in the same genome. The higher the value the more significant the dependence is. "
          . "<b>Conserved neighborhood ratio</b> shows the dependence of the two protein clusters based on their coocurrence in the same chromosomal cassette. "
          . "<b>Fusion ratio</b> shows the dependence of the two protein clusters based on their participation in fusion events.<br>"
    );

    #if($img_internal) {
    printHint(
"<b>Hierarchical clustering of cassettes</b> is performed on cassettes that contain the query and correlated ${strCluster}s.<br>"
          . "<b>Expansion</b> retrieves ${strCluster}s which are frequently occur in cassettes with the query and correlated ${strCluster}s.<br>"
    );

    #}
    $it->printOuterTable(1);

    # 	print qq{</table>};
    return scalar(@geneOrder);

}
###########################
# simple function to find
# the smallest value
###########################
sub min {
    my ( $a, $b ) = @_;
    my $min = $a;
    if ( $b < $a ) { $min = $b; }
    return $min;
}

#
#
########################################################################
# get the array with the correlated protein families
########################################################################
sub getGeneCorrelation {
    my ( $gene_clusterP, $method ) = @_;

    #closedFlag decides if the connections will be closed i.e. create a circle

    my @gene_cluster = @$gene_clusterP;
    my @gene_clusterStr;
    for ( my $i = 0 ; $i < scalar(@gene_cluster) ; $i++ ) {
        push @gene_clusterStr, $gene_cluster[$i][0];
    }
    my $gene_clusterStr = join( qq{','}, @gene_clusterStr );

    # 	print "<br>string: $gene_clusterStr<br>";
    my @connections;
    my $sql;

    #if($closedFlag eq 'n'){
    if ( lc($method) eq 'cog' ) {
        $sql = &OperonSQL::getCogConnectionsSql($gene_clusterStr);
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = &OperonSQL::getPfamConnectionsSql($gene_clusterStr);
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = &OperonSQL::getBBHConnectionsSql($gene_clusterStr);

        # 			print "$sql<br>\n";
    }

    #}

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    while (
            my (
                 $gene1,      $name1,          $gene2,
                 $name2,      $taxa1,          $taxa2,
                 $commTaxaNo, $commCassTaxaNo, $commFusionTaxaNo,
                 $coeff_gts,  $coeff_gns,      $coeff_gfs
            )
            = $cur->fetchrow_array()
      )
    {

        if ( !$coeff_gns ) { $coeff_gns = 0; }
        if ( OperonFunc::in( \@gene_clusterStr, $gene1 ) >= 0 ) {
            push @connections,
              [
                $gene1,                   $name1,
                $gene2,                   $name2,
                $taxa1,                   $taxa2,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        } elsif ( OperonFunc::in( \@gene_clusterStr, $gene2 ) >= 0 ) {
            push @connections,
              [
                $gene2,                   $name2,
                $gene1,                   $name1,
                $taxa2,                   $taxa1,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        } else {
            push @connections,
              [
                $gene1,                   "",
                $gene2,                   "",
                $taxa1,                   $taxa2,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        }
    }
    $cur->finish();
    ##$dbh->disconnect();

    return @connections;
}

#
# flat file version
#
sub getGeneCorrelation2 {
    my ( $gene_clusterP, $method ) = @_;

    my @gene_cluster = @$gene_clusterP;
    my @gene_clusterStr;
    for ( my $i = 0 ; $i < scalar(@gene_cluster) ; $i++ ) {
        push @gene_clusterStr, $gene_cluster[$i][0];
    }
    my $gene_clusterStr = join( qq{','}, @gene_clusterStr );

    my @connections;

    my $dbh = dbLogin();
    my $aref = OperonFile::getCoeff( $dbh, \@gene_clusterStr, lc($method) );
    ##$dbh->disconnect();

    foreach my $line (@$aref) {

        my (
             $gene1,      $name1,          $gene2,
             $name2,      $taxa1,          $taxa2,
             $commTaxaNo, $commCassTaxaNo, $commFusionTaxaNo,
             $coeff_gts,  $coeff_gns,      $coeff_gfs
          )
          = split( /\t/, $line );

        if ( !$coeff_gns ) { $coeff_gns = 0; }
        if ( OperonFunc::in( \@gene_clusterStr, $gene1 ) >= 0 ) {
            push @connections,
              [
                $gene1,                   $name1,
                $gene2,                   $name2,
                $taxa1,                   $taxa2,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        } elsif ( OperonFunc::in( \@gene_clusterStr, $gene2 ) >= 0 ) {
            push @connections,
              [
                $gene2,                   $name2,
                $gene1,                   $name1,
                $taxa2,                   $taxa1,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        } else {
            push @connections,
              [
                $gene1,                   "",
                $gene2,                   "",
                $taxa1,                   $taxa2,
                $commTaxaNo,              $commCassTaxaNo,
                $commFusionTaxaNo,        int( $coeff_gts * 1000 ),
                int( $coeff_gns * 1000 ), int( $coeff_gfs * 1000 )
              ];
        }
    }

    return @connections;
}

#
######################################################################
# print a JavaScript that
# asks the user to select the method of calculation
######################################################################
sub scriptForSelection {
    my ( $url, $section, $gene_oid ) = @_;

    # small Javascript that reads the selection of Clustering method
    # and loads the appropriate page
    print qq|
		<script language='javascript' type='text/javascript'>

		function selectClusterMethod() {
		ct = ctime( );
		var e = document.selectMethod.ClusterMethodSelection;
		var url = "$url?section=$section&page=geneConnections&genePageGeneOid=$gene_oid&expansion=2";
		url += "&clusterMethod=" + e.value;
		window.open( url, '_self' );
      		}
   		</script>

	|;

    # print the option list
    print qq{
		<table class='img' border='1'>
		<tr class='img'>
		<th class='subhead'>Method Selection
		&nbsp;
		</th>
		<td class='img'>
		<select name='ClusterMethodSelection' onChange='selectClusterMethod()'>
		<option value="label" selected>-- Select clustering method --&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</option>
		<option value="cog">COG</option>
		<option value="bbh">Bidirectional Best hits (MCL)</option>
		<option value="pfam">Pfam</option>
		</select>
		</td>
		</tr>
		</table>
	};
    print "\n";

}
################################################
#  get the gene cluster of gene_oid
################################################
sub getGeneCluster {
    my ( $gene_oid, $method ) = @_;
    my @clusterData;
    my $sql;
    my @binds;
    if ( lc($method) eq 'cog' ) { 
        ($sql, @binds) = &OperonSQL::getCogSql($gene_oid); 
    } elsif ( lc($method) eq 'pfam' ) {
        ($sql, @binds) = &OperonSQL::getPfamSql($gene_oid);
    } elsif ( lc($method) eq 'bbh' ) {
        ($sql, @binds) = &OperonSQL::getBBHSql($gene_oid);
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    while ( my ( $gene, $cluster, $name ) = $cur->fetchrow_array() ) {
        push @clusterData, [ $cluster, $name ];
    }
    $cur->finish;
    #$dbh->disconnect();
    return @clusterData;
}

#############################################################################
# find cassettes with multiple protein families (used for expansion)
#create sql that queries for cassettes that have more than two genes
#############################################################################
sub GeneExpandedConnections {
    my @genes            = param('geneCluster');
    my $expansion        = param('expansion');
    my ($gene_oid)       = param("genePageGeneOid");
    my ($cluster_method) = param("clusterMethod");
    my $clusterStr       = &OperonFunc::clusterString($cluster_method);

    #print a list of the genes
    print p( &OperonFunc::expansionName($expansion) . " with ${clusterStr}s" );
    printStatusLine( "Loading ...", 1 );

    # 	printHint ( "Genes that share cassettes with the query groups of genes");
    # get the data from the database
    my @connections = ();

    if (    lc($cluster_method) eq 'cog'
         or lc($cluster_method) eq 'bbh'
         or lc($cluster_method) eq 'pfam' )
    {

        # 		print "Genes:: @genes<br>\n";
        foreach my $currentGene (@genes) {
            print p(
                     $currentGene,
                     &OperonSQL::getClusterName(
                                                 $currentGene, $cluster_method
                     )
            );
        }
        @connections = getGeneExpandedConnections( \@genes, $cluster_method );

    } else {
        webError("This feature has not been implemented yet.");
    }
    @connections = sort { $$b[2] <=> $$a[2] } @connections;
    &printExpandedConnections( \@connections, $expansion, $gene_oid,
                               $cluster_method, \@genes );
    printStatusLine( "Loaded.", 2 );
}

#########################################################
# print the table with the expanded connections
#########################################################
sub printExpandedConnections {
    my ( $geneOrderP, $expansion, $gene_oid, $cluster_method, $genesP ) = @_;
    my @geneOrder     = @$geneOrderP;
    my @previousGenes = @$genesP;
    my $clusterStr    = &OperonFunc::clusterString($cluster_method);

    # 	print "There are ".scalar(@geneOrder)." new elements to show<br>\n";
    print qq{<table class='img' border='1'>
		<tr class='img'>
		<th class='subhead'>Correlated gene cluster</th>
		<th class='subhead'>Genomes with<br>correlated ${clusterStr}s<br>in the same cassette<br>with query $clusterStr</th>
		<th class='subhead'>Expansion</th>
		<th class='subhead'>Similarity <br>of cassettes<br>with these ${clusterStr}s</th>
		</tr>
	};

    for ( my $i = 0 ; $i < scalar(@geneOrder) ; $i++ ) {
        my @geneClusters = ( @previousGenes, $geneOrder[$i][0] );
        my $expansionURL =
          &expandedURL( $expansion + 1, $cluster_method, \@geneClusters );
        my $expansionName = &OperonFunc::expansionName( $expansion + 1 );

        my $cassetteTreeURL =
            url()
          . "?section="
          . param("section")
          . "&page=cassetteTree"
          . "&expansion="
          . param("expansion")
          . "&clusterMethod="
          . param("clusterMethod");
        for ( my $c = 0 ; $c < scalar(@previousGenes) ; $c++ ) {
            $cassetteTreeURL .= "&geneClusters=$previousGenes[$c]";
        }
        $cassetteTreeURL .= "&geneClusters=$geneOrder[$i][0]";
        print qq{<tr class='img'>
			<td class='img'>$geneOrder[$i][0] : $geneOrder[$i][1]</td>
			<td class='img'>$geneOrder[$i][2]</td>
			<td class='img'><a href="$expansionURL">$expansionName</a></td>
			<td class='img'><a href="$cassetteTreeURL">T</a></td>
			</tr>
			};
    }

    print qq{</table>};

}

############################################################
# generate the url for the expansion of cassettes
############################################################
sub expandedURL {
    my ( $expansion, $cluster_method, $geneClusterP ) = @_;
    my @geneClusters = @$geneClusterP;
    my $url          = url();
    $url = $url
      . "?section=Operon&page=geneConnections"
      . "&expansion=$expansion"
      . "&clusterMethod=$cluster_method";
    foreach my $geneCluster (@geneClusters) {
        $url .= "&geneCluster=$geneCluster";
    }

    return $url;

}
###########################################################
# generate the array with the expanded connections
###########################################################
sub getGeneExpandedConnections {
    my ( $genesP, $method ) = @_;
    my @genes = @$genesP;

    # 	print "Genes : @genes<br>\n";
    my @connections;
    my $sql;
    if ( lc($method) eq "cog" ) {
        $sql = &OperonSQL::getSqlExpandedCogGroups(@$genesP);
    } elsif ( lc($method) eq "pfam" ) {
        $sql = &OperonSQL::getSqlExpandedPfamGroups(@$genesP);

        # 		print "$sql<BR>";
    } elsif ( lc($method) eq "bbh" ) {
        $sql = &OperonSQL::getSqlExpandedBBHGroups(@$genesP);

        # 		print "$sql<BR>";
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    while ( my ( $geneCluster, $clusterName, $taxa ) = $cur->fetchrow_array ) {
        if ( OperonFunc::in( \@genes, $geneCluster ) >= 0 ) { next; }
        push @connections, [ $geneCluster, $clusterName, $taxa ];
    }
    $cur->finish();
    ##$dbh->disconnect();
    return @connections;
}

#
#

#
#
##################################################################################
##################################################################################
# pages that provide lists of genomes that have the gene clusters
##################################################################################
##################################################################################

##################################################################################
# retrieve a list of genomes that have the specific gene cluster
##################################################################################
sub getGenomesWithCluster {
    my ( $cluster_id, $method ) = @_;

    print "<h2>Genomes with @{$cluster_id}</h2>\n";

    print
"<p>Domains(D): B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses.<br>\n";
    print
      "Genome Completion(C): F=Finished, P=Permanent Draft, D=Draft.<br><\p>\n";

    my $it =
      new InnerTable( 1, "GenomesWithClusters$$", "GenomesWithClusters", 3 );
    $it->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome", "char asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $sql;
    if ( lc($method) eq 'cog' ) {
        $sql = OperonSQL::getGenomesWithCOGSQL($cluster_id);
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = OperonSQL::getGenomesWithPfamSQL($cluster_id);
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = OperonSQL::getGenomesWithBBHSQL($cluster_id);
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    printStatusLine( "Loading ...", 1 );
    while ( my ( $domain, $status, $name, $taxon_oid ) =
            $cur->fetchrow_array() )
    {
        $domain = uc( substr( $domain, 0, 1 ) );
        $status = uc( substr( $status, 0, 1 ) );
        my $r;
        $r .= $domain . "\t";
        $r .= $status . "\t";
        my $url =
          url() . "?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $name . $sd . alink( $url, $name ) . "\t";
        $it->addRow($r);
        $cnt++;
    }
    $cur->finish();
    #$dbh->disconnect();
    $it->printOuterTable(1);
    printStatusLine( "$cnt genomes loaded ...", 2 );
}
##################################################################################
# retrieve a list of genomes that have specific gene clusters in the same cassette
##################################################################################
sub getGenomesWithClusterCassette {
    my ( $cluster_id, $method ) = @_;

    print "<h2>Genomes with @{$cluster_id} in the same cassette</h2>\n";

    print
"<p>Domains(D): B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses.<br>\n";
    print
      "Genome Completion(C): F=Finished, P=Permanent Draft, D=Draft.<br><\p>\n";

    my $it = new InnerTable( 1, "GenomesWithClustersCassette$$",
                             "GenomesWithClustersCassette", 3 );
    $it->addColSpec( "Domain",    "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",    "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",    "char asc", "left" );
    $it->addColSpec( "Cassettes", "char asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $sql;
    my %taxonCheck
      ; # some taxa might have multiple cassettes. This way I can check and have each taxon only once
    if ( lc($method) eq 'cog' ) {
        $sql = OperonSQL::getGenomesWithCOGCassetteSQL($cluster_id);
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = OperonSQL::getGenomesWithPfamCassetteSQL($cluster_id);
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = OperonSQL::getGenomesWithBBHCassetteSQL($cluster_id);
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    printStatusLine( "Loading ...", 1 );
    my @t;
    while ( my ( $domain, $status, $name, $taxon_oid, $cassettes ) =
            $cur->fetchrow_array() )
    {

# checking a web tree application
# 	while(my ($domain,$p,$cl,$or,$fam,$gen,$sp,$status,$name,$taxon_oid,$cassettes)=$cur->fetchrow_array()){
# 		if ($taxonCheck{$taxon_oid}) {next;}
        $taxonCheck{$taxon_oid}++;
        $domain = uc( substr( $domain, 0, 1 ) );
        $status = uc( substr( $status, 0, 1 ) );

        #push @t,[$domain,$p,$cl,$or,$fam,$gen,$sp,$status,$name,$taxon_oid];
        push @t, [ $domain, $status, $name, $taxon_oid ];
    }
    for ( my $i = 0 ; $i < scalar(@t) ; $i++ ) {
        if ( $taxonCheck{ $t[$i][3] } == 0 ) { next }
        my $r;
        $r .= $t[$i][0] . "\t";
        $r .= $t[$i][1] . "\t";
        my $url =
          url() . "?section=TaxonDetail&page=taxonDetail&taxon_oid=$t[$i][3]";
        $r .= $t[$i][2] . $sd . alink( $url, $t[$i][2] ) . "\t";

        $url =
            url()
          . "?section="
          . param("section")
          . "&page=cassettesWithClusters&clusterMethod=$method&taxon_oid=$t[$i][3]";
        foreach my $c ( @{$cluster_id} ) {
            $url .= "&geneClusters=$c";
        }
        $r .=
          $taxonCheck{ $t[$i][3] } . $sd
          . alink( $url, $taxonCheck{ $t[$i][3] } ) . "\t";
        $taxonCheck{ $t[$i][3] } = 0;
        $it->addRow($r);
        $cnt++;
    }
    $it->printOuterTable(1);

#checking a web tree application
# 	my $treename="tree1";
# 	my @dataArray;
# 	my @values;
# 	my $rootName="Life";
# 	my $showColumns=7;
# 	for(my $i=0;$i<scalar(@t);$i++){
# 		if($taxonCheck{ $t[$i][9] }==0){next};
# 		my $url1=url()."?section=TaxonDetail&page=taxonDetail&taxon_oid=$t[$i][9]";
# 		my $url2=url()."?section=".param("section")."&page=cassettesWithClusters&clusterMethod=$method&taxon_oid=$t[$i][3]";
# 		foreach my $c( @{$cluster_id}){
# 			$url2.="&geneClusters=$c";
# 		}
# 		push @dataArray,[$t[$i][0],$t[$i][1],$t[$i][2],$t[$i][3],$t[$i][4],$t[$i][5],alink($url1,$t[$i][8])." ".alink($url2,$taxonCheck{$t[$i][9]})];
# 		push @values,$taxonCheck{$t[$i][9]};
# 		$cnt++;
# 	}
# 	my $tree=WebTree->new($treename,\@dataArray,$rootName,$showColumns,\@values);
# # 	$tree->submit("Add genomes to cart");
# 	$tree->SelectNodes("on");
# 	$tree->printTree();

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$cnt genomes loaded ...", 2 );
}
##################################################################################
# retrieve a list of genomes that have specific gene clusters in the same gene
##################################################################################
sub getGenomesWithClusterFusion {
    my ( $cluster_id, $method ) = @_;

    print "<h2>Genomes with @{$cluster_id} in the same gene</h2>\n";

    print
"<p>Domains(D): B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses.<br>\n";
    print
      "Genome Completion(C): F=Finished, P=Permanent Draft, D=Draft.<br><\p>\n";

    my $it = new InnerTable( 1, "GenomesWithClustersCassette$$",
                             "GenomesWithClustersCassette", 3 );
    $it->addColSpec( "Domain",      "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",      "char asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome",      "char asc", "left" );
    $it->addColSpec( "Fused genes", "char asc", "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $sql;
    my %taxonCheck
      ; # some taxa might have multiple cassettes. This way I can check and have each taxon only once
    if ( lc($method) eq 'cog' ) {
        $sql = OperonSQL::getGenomesWithCOGFusionSQL($cluster_id);
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = OperonSQL::getGenomesWithPfamFusionSQL($cluster_id);
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = OperonSQL::getGenomesWithBBHFusionSQL($cluster_id);
    }
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    printStatusLine( "Loading ...", 1 );
    my @t;

    while ( my ( $domain, $status, $name, $taxon_oid, $gene_oid ) =
            $cur->fetchrow_array() )
    {

        # 		if ($taxonCheck{$taxon_oid}) {next;}
        $taxonCheck{$taxon_oid}++;
        $domain = uc( substr( $domain, 0, 1 ) );
        $status = uc( substr( $status, 0, 1 ) );
        push @t, [ $domain, $status, $name, $taxon_oid ];
    }
    for ( my $i = 0 ; $i < scalar(@t) ; $i++ ) {
        if ( $taxonCheck{ $t[$i][3] } == 0 ) { next; }
        my $r;
        $r .= $t[$i][0] . "\t";
        $r .= $t[$i][1] . "\t";
        my $url =
          url() . "?section=TaxonDetail&page=taxonDetail&taxon_oid=$t[$i][3]";
        $r .= $t[$i][2] . $sd . alink( $url, $t[$i][2] ) . "\t";

        $url =
            url()
          . "?section="
          . param("section")
          . "&page=fusionsWithClusters&clusterMethod=$method&taxon_oid=$t[$i][3]";
        foreach my $c ( @{$cluster_id} ) {
            $url .= "&geneClusters=$c";
        }
        $r .=
          $taxonCheck{ $t[$i][3] } . $sd
          . alink( $url, $taxonCheck{ $t[$i][3] } ) . "\t";

        $it->addRow($r);
        $taxonCheck{ $t[$i][3] } = 0;
        $cnt++;
    }
    $cur->finish();
    #$dbh->disconnect();
    $it->printOuterTable(1);
    printStatusLine( "$cnt genomes loaded ...", 2 );
}

##################################################################################
# pages that show a list of cassettes or fused genes
##################################################################################
sub getCassettesWithCluster {
    my ( $cluster_id, $method, $taxon ) = @_;

    print "<h2> List of cassettes </h2>\n";
    my $sql;
    if ( lc($method) eq 'cog' ) {
        $sql = OperonSQL::getGenomesWithCOGCassetteSQL( $cluster_id, $taxon );
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = OperonSQL::getGenomesWithPfamCassetteSQL( $cluster_id, $taxon );
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = OperonSQL::getGenomesWithBBHCassetteSQL( $cluster_id, $taxon );
    }

    # 	print "<p>SQL: $sql</p>";
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    while ( my ( $domain, $status, $name, $taxon_oid, $cassette ) =
            $cur->fetchrow_array() )
    {

        my $url =
          url()
          . "?section=GeneCassette&page=cassetteBox&cassette_oid=$cassette&type=$method";
        print "<p>$name " . alink( $url, $cassette ) . "</p>\n";
    }
    $cur->finish();
    ##$dbh->disconnect();

}
##################################################################################

##################################################################################
sub getFusionsWithCluster {
    my ( $cluster_id, $method, $taxon ) = @_;

    print "<h2> List of fused genes </h2>\n";
    my $sql;
    if ( lc($method) eq 'cog' ) {
        $sql = OperonSQL::getGenomesWithCOGFusionSQL( $cluster_id, $taxon );
    } elsif ( lc($method) eq 'pfam' ) {
        $sql = OperonSQL::getGenomesWithPfamFusionSQL( $cluster_id, $taxon );
    } elsif ( lc($method) eq 'bbh' ) {
        $sql = OperonSQL::getGenomesWithBBHFusionSQL( $cluster_id, $taxon );
    }

    # 	print "<p>SQL: $sql</p>";
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    while ( my ( $domain, $status, $name, $taxon_oid, $gene, $product ) =
            $cur->fetchrow_array() )
    {

        my $url = url() . "?section=GeneDetail&page=geneDetail&gene_oid=$gene";
        print "<p>" . alink( $url, $gene ) . " $product</p>\n";
    }
    $cur->finish();
    ##$dbh->disconnect();

}

##################################################################################
# return a string with the list of genes.
# use it to append the string at the end of a url
##################################################################################
sub provideGenes {
    my $r = "";
    if ( param("genePageGeneOid") ) {

        # 		print"<p> Genes are available</p>\n";
        my @gene_oids = param("genePageGeneOid");
        for my $gene_oid (@gene_oids) {
            $r .= "&genePageGeneOid=$gene_oid";
        }
    }
    return $r;
}

1;
