# $Id: TreeNode.pm 29739 2014-01-07 19:11:08Z klchu $
package TreeNode;
use strict;

#
#
sub new {
    my ( $class, $id, $level, $text, $pnode, $open ) = @_;
    my $self = {};
    bless( $self, $class );

    $self->{id}         = $id;
    $self->{text}       = $text;
    $self->{level}      = $level;
    $self->{parentnode} = $pnode;
    $self->{taxon_oid}  = "";       # genome id
    $self->{end_text}   = "";       # genome status text
    $self->{selected}   = 0;        # for check box
    $self->{isopen}     = 0;
    $self->{isopen} = $open if ( $open ne "" );

    # an array of children Node objects
    my @chlidren = ();
    $self->{childrenNodes} = \@chlidren;

    return $self;
}

sub getSelected {
    my ($self) = @_;
    return $self->{selected};
}

sub setSelected {
    my ( $self, $x ) = @_;
    $self->{selected} = $x;
}

sub setTaxonOid {
    my ( $self, $x ) = @_;
    $self->{taxon_oid} = $x;
}

sub setEndText {
    my ( $self, $x ) = @_;
    $self->{end_text} = $x;
}

sub getTaxonOid {
    my ($self) = @_;
    return $self->{taxon_oid};
}

sub getEndText {
    my ($self) = @_;
    return $self->{end_text};
}

sub isOpen {
    my ($self) = @_;
    return $self->{isopen};
}

sub setOpen {
    my ( $self, $x ) = @_;
    $self->{isopen} = $x;
}

sub addChild {
    my ( $self, $nodeRef ) = @_;
    my $aref = $self->{childrenNodes};
    push( @$aref, $nodeRef );
}

sub getChildren {
    my ($self) = @_;
    return $self->{childrenNodes};
}

sub getId {
    my ($self) = @_;
    return $self->{id};
}

sub getParent {
    my ($self) = @_;
    return $self->{parentnode};
}

sub getText {
    my ($self) = @_;
    return $self->{text};
}

sub getLevel {
    my ($self) = @_;
    return $self->{level};
}

sub hasChildren {
    my ($self) = @_;
    my $aref = $self->{childrenNodes};
    if ( defined($aref) && $#$aref >= 0 ) {
        return $#$aref + 1;    #1;
    } else {
        return 0;
    }
}

1;
