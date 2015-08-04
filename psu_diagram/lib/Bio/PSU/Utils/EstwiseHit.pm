package Bio::PSU::Utils::EstwiseHit;

use strict;
use Carp;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my $self     = {
		  est_accession => undef,
		  strand => undef,
		  pfam_name => undef,
		  pfam_accession => undef,
		  ipro_accession => undef,
		  ipro_name => undef,
		  go_accessions => undef,
		  bits => undef,
		  @_,
		 };
  bless ($self, $class);
  return $self;
}

sub setESTAccession {
  my $self = shift;
  my ($est_acc) = @_;
  $self->{est_accession} = $est_acc;
}

sub getESTAccession {
  my $self = shift;
  return $self->{est_accession};
}

sub getStrand {
  my $self = shift;
  return $self->{strand};
}

sub setStrand {
  my $self = shift;
  my ($strand) = @_;
  $self->{strand} = $strand;
}

sub getPfamName {
  my $self = shift;
  return $self->{pfam_name};
}

sub setPfamName {
  my $self = shift;
  my ($pfam_name) = @_;
  $self->{pfam_name} = $pfam_name;
}

sub setPfamAccession {
  my $self = shift;
  my ($pfam_acc) = @_;
  $self->{pfam_accession} = $pfam_acc;
}

sub getPfamAccession {
  my $self = shift;
  return $self->{pfam_accession};
}

sub setInterproAccession {
  my $self = shift;
  my ($ipro_acc) = @_;
  $self->{ipro_accession} = $ipro_acc;
}

sub getInterproAccession {
  my $self = shift;
  return $self->{ipro_accession};
}

sub setInterproName {
  my $self = shift;
  my ($ipro_name) = @_;
  $self->{ipro_name} = $ipro_name;
}

sub getInterproName {
  my $self = shift;
  return $self->{ipro_name};
}

sub setGOAccessions {
  my $self = shift;
  my ($go_acc_ref) = @_;
  $self->{go_accessions} = $go_acc_ref;
}

sub getGOAccessions {
  my $self = shift;
  return @{$self->{go_accessions}};
}

sub getBits {
  my $self = shift;
  return $self->{bits};
}

sub setBits {
  my $self = shift;
  my ($bits) = @_;
  $self->{bits} = $bits;
}

