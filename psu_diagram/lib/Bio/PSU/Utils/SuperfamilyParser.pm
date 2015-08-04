package Bio::PSU::Utils::SuperfamilyParser;

use strict;
use Data::Dumper;
use Carp;

eval "require Bio::PSU::Utils::SuperfamilyHit";
# use Bio::PSU::Utils::SuperfamilyHit;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name=>value pairs (odd number supplied)";
  }

  my $self     = {
		  superfamilyOutput  => undef,
		  verbose            => 0,
		  @_,
		 };
  bless ($self, $class);
  return $self;
}

sub setSuperfamilyOutput {
  my $self = shift;
  my ($superfamilyOutput) = @_;
  $self->{superfamilyOutput} = $superfamilyOutput;
}

sub getSuperfamilyOutput {
  my $self = shift;
  return $self->{superfamilyOutput};
}

sub parse {
  my $self = shift;
  my ($mapping_file) = @_;
  my @results = ();
  my $verbose = $self->{verbose};

  open SUPERFAMILY, "< $self->{superfamilyOutput}" or die "can't open file, $!\n";

  while (<SUPERFAMILY>) {
    my $line = $_;
    if ($verbose) {
      print STDERR "parsing line, $line...\n";
    }
    if ($line =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
	
	my $prot_acc   = $1;
	my $scop_id    = $2;
	my $start      = $4;
	my $end        = $5;
	my $evalue     = $6;
	my $scop_name  = $8;
	
	my $superfamily_hit = Bio::PSU::Utils::SuperfamilyHit->new (
								    prot_accession => $prot_acc,
								    start  => $start,
								    end    => $end,
								    evalue => $evalue,
								    scopid => $scop_id,
								    scopName => $scop_name,
								   );

	if ($verbose) {
	  print STDERR "SP Hit created: " . Dumper ($superfamily_hit) . "\n";
	}

	push (@results, $superfamily_hit);
	
      }
  }

  close SUPERFAMILY;

  return @results;
}
