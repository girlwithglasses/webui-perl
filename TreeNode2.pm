package TreeNode2;
use strict;
use Data::Dumper;

#
# 
#
sub new {
    my ( $class, $oid, $name, $level, $domain ) = @_;
    my $self = {};
    bless( $self, $class );

    $self->{oid} = $oid;
    $self->{name} = $name;
    $self->{level} = $level;
    $self->{domain} = $domain;
    
    # an array of children Node objects
    my @chlidren;
    $self->{childrenNodes} = \@chlidren;
    
    return $self;
}

sub addChild {
    my($self, $nodeRef) = @_;
    my $aref = $self->{childrenNodes};
    push (@$aref, $nodeRef);
}


sub getDomain {
     my($self) = @_;
     return $self->{domain};
}

sub getChildren {
    my($self) = @_;
    return $self->{childrenNodes};
}

# if id is null then its not the taxon name nore or node with a link
sub getOid {
    my($self) = @_;
    return $self->{oid};
}

sub getName {
    my($self) = @_;
    return $self->{name};
}

sub getLevel {
    my($self) = @_;
    return $self->{level};
}

sub hasChildren {
    my($self) = @_;
    my $aref = $self->{childrenNodes};
    if (defined ($aref) && $#$aref >= 0) {
        return  $#$aref + 1; #1;
    } else {
        return 0;
    }
}

1;