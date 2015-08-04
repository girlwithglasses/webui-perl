package MetaCycNode;
use strict;
use Data::Dumper;

#
# $name is common name - but should only be used for leaf nodes?
#
sub new {
	my ( $class, $unique_id, $name, $type ) = @_;
	my $self = {};
	bless( $self, $class );

    $self->{unique_id} = $unique_id;
	$self->{name} = $name;
    $self->{type} = $type;
	
	# list of parents Node object
	my @parents;
	$self->{parentNodes} = \@parents;
	
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

sub addChildUnique {
    my($self, $nodeRef) = @_;
    my $aref = $self->{childrenNodes};
    my $found = 0;
    foreach my $node (@$aref) {
        if($node->getUniqueId() eq $nodeRef->getUniqueId()) {
            $found = 1;
            last;
        }
    }
    
    if($found == 0) {
        push (@$aref, $nodeRef);
    }
}

sub addParent {
    my($self, $nodeRef) = @_;
    my $aref = $self->{parentNodes};
    push (@$aref, $nodeRef);
}

sub getChildren {
	my($self) = @_;
	return $self->{childrenNodes};
}

sub getUniqueId {
	my($self) = @_;
	return $self->{unique_id};
}

sub getName {
    my($self) = @_;
    return $self->{name};
}

sub getType {
    my($self) = @_;
    return $self->{type};
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

sub hasParents {
    my($self) = @_;
    my $aref = $self->{parentNodes};
    if (defined ($aref) && $#$aref >= 0) {
        return  $#$aref + 1; #1;
    } else {
        return 0;
    }
}
1;