package Bio::PSU::Utils::BlastHit;

use strict;
use Carp;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my $self     = {
		  query_accession => undef,
		  q_strand => undef,
		  s_strand => undef,
		  subject_accession => undef,
		  subject_description => undef,
		  score => undef,
		  percent => undef,
		  evalue => undef,
		  @_,
		 };
  bless ($self, $class);
  return $self;
}

sub getQueryAccession {
  my $self = shift;
  return $self->{query_accession};
}

sub getStrand {
  my $self = shift;
  return $self->{strand};
}

sub getSubjectAccession {
  my $self = shift;
  return $self->{subject_accession};
}

sub getSubjectDescription {
  my $self = shift;
  return $self->{subject_description};
}

sub getScore {
  my $self = shift;
  return $self->{score};
}

sub getPercent {
  my $self = shift;
  return $self->{percent};
}

sub getEValue {
  my $self = shift;
  return $self->{evalue};
}

