############################################################################
# PwNwNodeMgr - Tree manager for PwNwNode's.
#  Build tree from nodes.
#     --es 04/04/2006
############################################################################
package PwNwNodeMgr;
use strict;
use CGI qw( :standard );
use Data::Dumper;
use PwNwNode;
use DBI;
use WebConfig;
use WebUtil;
 
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $inner_cgi = $env->{ inner_cgi };
my $base_url = $env->{ base_url };
my $verbose = $env->{ verbose };
  
############################################################################
# new - New instance.
############################################################################
sub new {
    my( $myType ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ root } = new PwNwNode( );

    return $self;
}

############################################################################
# loadTree - Load the tree.
#
# Amy: add parts lists to the tree display for IMG 2.3
############################################################################
sub loadTree {
    my( $self ) = @_;

    my $dbh = dbLogin( );

    my $root = $self->{ root };

    ## Get network nodes
    my %networkNodes;
    my $sql = qq{
        select network_oid, network_name
	from pathway_network
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $network_oid, $network_name ) = $cur->fetchrow( );
       last if !$network_oid;
       my $n = new PwNwNode( "network", $network_oid, $network_name );
       $networkNodes{ $network_oid } = $n;
    }
    $cur->finish( );

    ## Get pathway nodes
    my %pathwayNodes;
    my $sql = qq{
        select pathway_oid, pathway_name
	from img_pathway
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $pathway_oid, $pathway_name ) = $cur->fetchrow( );
       last if !$pathway_oid;
       my $n = new PwNwNode( "pathway", $pathway_oid, $pathway_name );
       $pathwayNodes{ $pathway_oid } = $n;
    }
    $cur->finish( );

    ## Get parts list nodes
    my %partsListNodes;
    my $sql = qq{
        select parts_list_oid, parts_list_name
	from img_parts_list
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $parts_list_oid, $parts_list_name ) = $cur->fetchrow( );
       last if !$parts_list_oid;
       my $n = new PwNwNode( "parts_list", $parts_list_oid, $parts_list_name );
       $partsListNodes{ $parts_list_oid } = $n;
    }
    $cur->finish( );

    my %networkChildren;
    my %networkParents;
    my $sql = qq{
        select network_oid, parent
	from pathway_network_parents
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $network_oid, $parent ) = $cur->fetchrow( );
       last if !$network_oid;
       $networkChildren{ $parent } .= "$network_oid ";
       $networkParents{ $network_oid } .= "$parent ";
    }
    $cur->finish( );

    ## network - pathway relationship
    my %network2Pathways;
    my %pathway2Networks;
    my $sql = qq{
        select network_oid, pathway
	from pathway_network_img_pathways
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $network_oid, $pathway ) = $cur->fetchrow( );
       last if !$network_oid;
       $network2Pathways{ $network_oid } .= "$pathway ";
       $pathway2Networks{ $pathway } .= "$network_oid ";
    }
    $cur->finish( );

    ## network - parts list relationship
    my %network2PartsLists;
    my %partsList2Networks;
    my $sql = qq{
        select network_oid, parts_list
	from pathway_network_parts_lists
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $network_oid, $parts_list ) = $cur->fetchrow( );
       last if !$network_oid;
       $network2PartsLists{ $network_oid } .= "$parts_list ";
       $partsList2Networks{ $parts_list } .= "$network_oid ";
    }
    $cur->finish( );

    ## Find networks with no parents.
    my @keys = keys( %networkNodes );
    for my $k( @keys ) {
       next if $networkParents{ $k } ne "";
       my $n = $networkNodes{ $k };
       $root->addNode( $n );
    }

    ## Find pathways with no networks.
    my $unc = new PwNwNode( "network", 0, "unclassified" );
    $unc = $root->addNode( $unc );
    my @keys = keys( %pathwayNodes );
    for my $k( @keys ) {
       next if $pathway2Networks{ $k } ne "";
       my $n = $pathwayNodes{ $k };
       $unc->addNode( $n );
    }

    ## Find parts lists with no networks.
    my @keys = keys( %partsListNodes );
    for my $k( @keys ) {
       next if $partsList2Networks{ $k } ne "";
       my $n = $partsListNodes{ $k };
       $unc->addNode( $n );
    }

    ## Recursion adding of network nodes.
    my $level = 0;
    addNetworkChildren( $root, \%networkChildren, \%networkNodes, \$level );
    addNetworkPathways( $root, \%network2Pathways, \%pathwayNodes );
    addNetworkPartsLists( $root, \%network2PartsLists, \%partsListNodes );
    sortNodes( $root );

    #$dbh->disconnect();
}

############################################################################
# addNetworkChildren - Recursively add network nodes.
############################################################################
sub addNetworkChildren {
    my( $n, $networkChildren_ref, $networkNodes_ref, $level_ref ) = @_;

    ($$level_ref)++;
    if( $$level_ref > 10 ) {
       my $oid = $n->{ oid };
       webDie( "addNetworkParents: level=$$level_ref oid=$oid loop in data\n" );
    }
    my $level = $$level_ref;
    my $oid = $n->{ oid };
    my $type = $n->{ type };

    my $a = $n->{ children };
    my $nNodes = @$a;
    if( $nNodes == 0 && $oid ne "" &&  $type eq "network" ) {
        my $s = $networkChildren_ref->{ $oid };
	my @nodes = split( /\s+/, $s );
	for my $i( @nodes ) {
	    next if $i eq "";
	    my $n2 = $networkNodes_ref->{ $i };
            my $n2Oid = $n2->{ oid };
	    $n->addNode( $n2 );
        }
    }
    my $a = $n->{ children };
    my $nNodes = @$a;
    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       my $n2Oid = $n2->{ oid };
       addNetworkChildren( $n2, $networkChildren_ref, $networkNodes_ref, 
          $level_ref );
    }
    ($$level_ref)--;
}

############################################################################
# addNetworkPathways - Recursively add pathway nodes.
############################################################################
sub addNetworkPathways {
    my( $n, $network2Pathways_ref, $pathwayNodes_ref ) = @_;

    my $oid = $n->{ oid };
    my $type = $n->{ type };
    my $s = $network2Pathways_ref->{ $oid };
    if( $oid ne "" && $s ne "" && $type eq "network" ) {
        my @nodes = split( /\s+/, $s );
	for my $i( @nodes ) {
	    next if $i eq "";
	    my $n2 = $pathwayNodes_ref->{ $i };
	    $n->addNode( $n2 );
	}
    }
    my $a = $n->{ children };
    my $nNodes = @$a;
    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       addNetworkPathways( $n2, $network2Pathways_ref, $pathwayNodes_ref );
    }
}

############################################################################
# addNetworkPartsLists - Recursively add parts list nodes.
############################################################################
sub addNetworkPartsLists {
    my( $n, $network2PartsLists_ref, $partsListNodes_ref ) = @_;

    my $oid = $n->{ oid };
    my $type = $n->{ type };
    my $s = $network2PartsLists_ref->{ $oid };
    if( $oid ne "" && $s ne "" && $type eq "network" ) {
        my @nodes = split( /\s+/, $s );
	for my $i( @nodes ) {
	    next if $i eq "";
	    my $n2 = $partsListNodes_ref->{ $i };
	    $n->addNode( $n2 );
	}
    }
    my $a = $n->{ children };
    my $nNodes = @$a;
    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       addNetworkPartsLists( $n2, $network2PartsLists_ref, $partsListNodes_ref );
    }
}


############################################################################
# sortNodes - Sort nodes alphabetically by network or pathway name
#  at each sibling level.
############################################################################
sub sortNodes {
   my( $n ) = @_;

    my $a = $n->{ children };
    my $nNodes = @$a;

    my @recsIdx;
    my @recsNodes;
    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       my $name = $n2->{ name };
       my $r = "$name\t";
       $r .= "$i\t";
       push( @recsIdx, $r );
       push( @recsNodes, $n2 );
    }
    my @recsIdx2 = sort( @recsIdx );
    my @recsNodes2;
    for my $r( @recsIdx2 ) {
       my( $name, $idx ) = split( /\t/, $r );
       my $n2 = $recsNodes[ $idx ];
       push( @recsNodes2, $n2 );
    }
    $n->{ children } = \@recsNodes2;

    for( my $i = 0; $i < $nNodes; $i++ ) {
       my $n2 = $n->{ children }->[ $i ];
       sortNodes( $n2 );
    }
}

1;
