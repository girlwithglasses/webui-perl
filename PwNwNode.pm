############################################################################
# PwNwNode -  Pathway Network node for forming tree.
#  We allow only one parent, unlike the database here, and
#  replicate the children if necessary.  We also combine
#  pathway_network with img_pathway into one structure.
#      --es 04/04/2006
############################################################################
package PwNwNode;
use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebUtil;
use WebConfig;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $verbose = $env->{ verbose };
 
############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my( $myType, $type, $oid, $name ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ myType } = $myType;
    $self->{ type } = $type;
    $self->{ oid } = $oid;
    $self->{ name } = $name;
    my @a;
    $self->{ children } = \@a;
    $self->{ parent } = 0;

    return $self;
}

############################################################################
# cloneNode - Clone bare node, but children.
#    Used to establish deep copy.
############################################################################
sub cloneNode {
   my( $self ) = @_;

   my $myType = $self->{ myType };
   my $n = { };
   bless( $n, $myType );
   $n->{ myType } = $myType;
   $n->{ type } = $self->{ type };
   $n->{ oid } = $self->{ oid };
   $n->{ name } = $self->{ name };
   my @a;
   $n->{ children } = \@a;
   $n->{ parent } = 0;
   return $n;
}

############################################################################
# getLevel - Level (depth) of node.
############################################################################
sub getLevel {
   my( $self ) = @_;
   my $parent = $self->{ parent };
   my $count = 0;
   for( ; $parent; $parent = $parent->{ parent } ) {
      $count++;
   }
   return $count;
}

############################################################################
# printNode - Print contents of the node out for debugging.
############################################################################
sub printNode {
   my( $self ) = @_;
   my $level = $self->getLevel( );
   my $sp = "  " x $level;
   my $type = $self->{ type };
   my $oid = $self->{ oid };
   my $name = $self->{ name };
   printf "%s%02d oid=%d '%s' (%s)\n", $sp, $level, $oid, $name, $type;
   my $a = $self->{ children };
   my $nNodes = @$a;
   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $self->{ children }->[ $i ];
      printNode( $n2 );
   }
}

############################################################################
# printNodeHtml - Print contents of the node out web display.
############################################################################
sub printNodeHtml {
   my( $self ) = @_;

   my $type = $self->{ type };
   my $oid = $self->{ oid };
   my $name = $self->{ name };

   my $a = $self->{ children };
   my $nNodes = @$a;
   #return if $nNodes == 0 && $type eq "network";

   my $level = $self->getLevel( );
   print "<br/>\n" if $level == 1;
   print nbsp( ( $level - 1 ) * 4 );

   if( $type eq "network" ) {
       print sprintf( "%02d", $level );
       print nbsp( 1 );
       print "<b>" if $level == 1;
       #print escHtml( "$name (network $oid)" );
       print escHtml( $name );
       print "</b>" if $level == 1;
   }
   elsif( $type eq "pathway" ) {
       $oid = FuncUtil::pwayOidPadded( $oid );
       print "<input type='checkbox' name='pway_oid' value='$oid' />\n";
       print nbsp( 1 );
       my $url = "$main_cgi?section=ImgPwayBrowser" . 
          "&page=imgPwayDetail&pway_oid=$oid";
       print "<font color='blue'>\n";
       print alink( $url, $oid ) . nbsp( 1 ) . escHtml( $name );
       print "</font>\n";
   }
   print "<br/>\n" if $level >= 1;

   for( my $i = 0; $i < $nNodes; $i++ ) {
      my $n2 = $self->{ children }->[ $i ];
      printNodeHtml( $n2 );
   }
}

############################################################################
# addNode - Add node and set pointers.
############################################################################
sub addNode {
    my( $self, $n0 ) = @_;


    my $n = $n0->cloneNode( );
    #my $n = $n0;
    my $children = $self->{ children };
    $n->{ parent } = $self;
    push( @$children, $n );

    return $n;
}

1;
