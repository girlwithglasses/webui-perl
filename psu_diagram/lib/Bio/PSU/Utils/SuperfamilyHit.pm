package Bio::PSU::Utils::SuperfamilyHit;

use strict;
use Carp;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }
  my $self = {
	      prot_accession => undef,
	      start    => undef,
	      end      => undef,
	      evalue   => undef,
	      scopid   => undef,
	      scopName => undef,
	      @_,
	     };
  bless ($self, $class);
  return $self;
}

sub setProtAccession {
  my $self = shift;
  my ($prot_acc) = @_;
  $self->{prot_accession} = $prot_acc;
}

sub getProtAccession {
  my $self = shift;
  return $self->{prot_accession};
}

sub getStart {
  my $self = shift;
  return $self->{start};
}

sub setStart {
  my $self = shift;
  my ($start) = @_;
  $self->{start} = $start;
}

sub getEnd {
  my $self = shift;
  return $self->{end};
}

sub setEnd {
  my $self = shift;
  my ($end) = @_;
  $self->{end} = $end;
}

sub setEvalue {
  my $self = shift;
  my ($evalue) = @_;
  $self->{evalue} = $evalue;
}

sub getEvalue {
  my $self = shift;
  return $self->{evalue};
}

sub getScopID {
  my $self = shift;
  return $self->{scopid};
}

sub setScopID {
  my $self = shift;
  my ($scop_id) = @_;
  $self->{scopid} = $scop_id;
}

sub getScopName {
  my $self = shift;
  return $self->{scopName};
}

sub setScopName {
  my $self = shift;
  my ($scop_name) = @_;
  $self->{scopName} = $scop_name;
}
