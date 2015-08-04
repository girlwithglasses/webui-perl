############################################################################
# ImgTermNodeMgr.pm - IMG term node manager
#    --es 05/01/2006
############################################################################
package ImgTermNodeMgr;
use strict;
use Data::Dumper;
use ImgTermNode;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $inner_cgi = $env->{ inner_cgi };
my $base_url = $env->{ base_url };
my $verbose = $env->{ verbose };

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my( $myType ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ root } = new ImgTermNode( 0, "_root" );
    return $self;
}

############################################################################
# loadTree - Populate tree structure
############################################################################
sub loadTree {
    my( $self, $dbh ) = @_;

    my $root = $self->{ root };

    my %termOid2Node;
    my $sql = qq{
    	select term_oid, term, term_type
    	from img_term
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
    	my( $term_oid, $term, $term_type ) = $cur->fetchrow( );
    	last if !$term_oid;
    	$termOid2Node{ $term_oid } = 
    	   new ImgTermNode( $term_oid, $term, $term_type );
    }
    $cur->finish( );

    my $sql = qq{
    	select itc.term_oid, itc.child, itc.c_order, it2.term
    	from img_term_children itc, img_term it2
    	where itc.child = it2.term_oid
    	order by itc.term_oid, itc.c_order, it2.term
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %child2Parent;
    my %parent2Children;
    for( ;; ) {
    	my( $term_oid, $child, $c_order, $term2 ) = $cur->fetchrow( );
    	last if !$term_oid;
    	$child2Parent{ $child } = $term_oid;
    	$parent2Children{ $term_oid } .= "$child ";
    }
    $cur->finish( );

    ## Find nodes w/o parents first
    my @keys = sort{ $a <=> $b } keys( %termOid2Node );
    my $nKeys = @keys;
    my $count = 0;
    for my $term_oid( @keys ) {
    	$count++;
    	my $parent = $child2Parent{ $term_oid };
    	next if $parent ne "";
    	my $n = $termOid2Node{ $term_oid };
    	my $n = $root->addNode( $n );
    	addBranch( $n, \%termOid2Node, \%parent2Children );
    }
    return $root;
}

############################################################################
# addBranch - Add whole branch.
############################################################################
sub addBranch {
    my( $n, $termOid2Node_ref, $parent2Children_ref ) = @_;

    my $term_oid = $n->{ term_oid };
    my $children_s = $parent2Children_ref->{ $term_oid };
    my @a = split( / /, $children_s );
    for my $i( @a ) {
	next if $i eq "";
	my $n2 = $termOid2Node_ref->{ $i };
	my $n2 = $n->addNode( $n2 );
        addBranch( $n2, $termOid2Node_ref, $parent2Children_ref );
    }
}


############################################################################
# insertMapNodes - Insert all map nodes.
############################################################################
sub insertMapNodes {
    my( $self, $dbh ) = @_;

    my $sql = "set transaction read write";
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

    my $sql = qq{
       delete from dt_img_term_path
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

    my $sql = qq{
       insert into dt_img_term_path( term_oid, map_term )
       select term_oid, term_oid
       from img_term
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

    $self->loadTree( $dbh );
    my $root = $self->{ root };
    $root->printNode( ) if $verbose >= 2;
    $root->insertMapNodes( $dbh );

    my $sql = "commit work";
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish( );

}

1;

