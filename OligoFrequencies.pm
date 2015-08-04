###########################################################################
# OligoFrequencies.pm - class used by Kmer.pm
#           -- originally developed by Konstantinos Mavrommatis, Dec 2011
#
# $Id: OligoFrequencies.pm 29739 2014-01-07 19:11:08Z klchu $
###########################################################################
package OligoFrequencies;

sub new{
	my $self={};
	my ($class,$inputFile,$outputFile)=@_;
	bless($self,$class);
	$self->sequenceType('dna');
	$self->kmerSize(4);
	$self->{oligomers}={};
	return $self;
}

sub getOligos{
	my($self)=@_;
	return $self->{oligomers};
}
sub kmerSize{
	my($self,$value)=@_;
	if($value){$self->{kmerSize}=$value;}
	return $self->{kmerSize};
}
sub sequenceType{
	my($self,$value)=@_;
	if($value){
		$self->{sequenceType}=$value;
		$self->setAlphabet();	
	}
	
	return $self->{sequenceType};
}

# build the initial set of oligomers
sub buildOligos{
	my ($self)=@_;
	$self->fillOligomers( );
        # After fill Oligomers we have scalar(keys(%{$self->{oligomers}})) oligomers in the array
	$self->lightOligomers() if $self->sequenceType() eq 'dna';
        #After light Oligomers we have scalar(keys(%{$self->{oligomers}})) oligomers in the array;
}


sub getKmers{
	my ($self,$seq)=@_;
	$self->resetHash();
	for( my $i=0 ; $i<=length($seq)-$self->kmerSize() ; $i++ ){
		my $oligomer=substr( $seq, $i, $self->kmerSize() );
		my $revcomp =$self->rc($oligomer);
		if( defined( $self->{ oligomers }->{ $oligomer } ) ){
			$self->{ oligomers }->{ $oligomer } ++  ;
		}elsif( defined( $self->{ oligomers }->{ $revcomp } ) ){
			$self->{ oligomers }->{ $revcomp } ++  ;
		}
	}
	return $self->{ oligomers };
}

sub resetHash{
	my ($self)=@_;
        # Resetting hash
	my @temp=keys( %{$self->{oligomers}} );
	foreach my $d(@temp){
		$self->{oligomers}->{$d}=0;
	}
}

sub debugOligos{
    my ($self)=@_;
    
    my %hash;
    my @temp=keys( %{$self->{oligomers}} );
    foreach my $i(@temp){
	$hash{  $self->{oligomers}->{$i} }=1;	
	print "Oligo: $i: ", $self->{oligomers}->{$i}, "\n" if(defined( $self->{oligomers}->{$i}));
    }
}

sub fillOligomers{
    my($self)=@_;
    # if the alphabet is for DNA we can take advandage of the rc sequences. Thanks Alex Sczyrba
    # we fill in the array for the first iteration

    foreach my $aa(@{$self->{alphabet}}){
	# filling up array with $aa
	$self->{oligomers}->{$aa}=0;
    };
    for(my $i=1; $i<$self->kmerSize(); $i++){
	my @temp=keys( %{$self->{oligomers}} );
	foreach my $oligo( @temp ) {
	    # fillOligomers: oligo is $oligo
	    foreach my $aa(@{$self->{alphabet}}){
		my $newid=$oligo.$aa;
		$self->{oligomers}->{ $newid }=0;
		# The new id is now $newid
	    }
	    delete $self->{oligomers}->{$oligo} ;
	}
    }
}

sub lightOligomers{
    my ($self)=@_;
    my %usedHash;
    my @temp=sort{$a cmp $b}keys( %{$self->{oligomers}}  );
    foreach my $i(@temp){
	my $kmer=$i;
	my $rc = $self->rc($kmer);
	# lightOligomers: $kmer
	if( defined($usedHash{ $rc } ) and $rc ne $kmer ){
            # removing $kmer
	    delete $self->{oligomers}->{$kmer};
	}
	$usedHash{ $kmer }=1;
    }
}

sub rc{
    my($self,$s)=@_;
    my $rc=reverse($s);
    $rc=~tr/[A,T,C,G,N]/[T,A,G,C,N]/;
    # Sequence $s is now $rc
    return $rc;
}

sub setAlphabet{
    my($self)=@_;
    if($self->{sequenceType} eq 'dna'){
	$self->{alphabet}=['A','C','G','T'];
    }elsif($self->{sequenceType} eq 'protein'){
	$self->{alphabet}=['A','C','D','E','F','G','H','I','K','L','M','N','P','Q','R','S','T','V','W','Y'];
    }else{
	die"getAlphabet: unknown alphabet type\n";
    }
}

1;
