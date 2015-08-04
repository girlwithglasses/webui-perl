package Bio::PSU::Utils::EstwiseParsing;

use strict;
use Data::Dumper;
use Carp;

eval "require Bio::PSU::Utils::EstwiseHit";
# use Bio::PSU::Utils::EstwiseHit;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name => value pairs (odd number supplied)";
  }

  my $self = {
	      estwiseOutput  => undef,
	      pfamMapping => undef,
	      iproMapping => undef,
	      goMapping   => undef,
	      @_,
	     };
  bless ($self, $class);
  return $self;
}

#########
# set the estwise output
# it can be a file or a directory containing a set of estwise output files
##

sub setEstwiseOutput {
  my $self = shift;
  my ($estwiseOutput) = @_;
  $self->{estwiseOutput} = $estwiseOutput;
}

sub getEstwiseOutput {
  my $self = shift;
  return $self->{estwiseOutput};
}

sub mapPfam_name_accession {
  my $self = shift;
  my ($pfam_name) = @_;
  my $pfam_acc = undef;

  print STDERR "mapping pfam name and accession...\n";

  open MAPPING, "< $self->{pfamMapping}" or die "can't open file, $!\n";

  while (<MAPPING>) {
    my $line = $_;
    if ($line =~ /.+$pfam_name\W+/) {
      # print STDERR "line: $line\n";
      $line =~ /\s*(\w+)\s+.+/;
      $pfam_acc = $1;
      last;
    }
  }

  close MAPPING;  

  return $pfam_acc;
}

sub mapPfam2Ipro {
  my $self = shift;
  my ($pfam_acc) = @_;
  my $ipro_acc  = "undefined";
  my $ipro_name = "undefined";

  print STDERR "mapping pfam 2 interpro accession numbers...\n";
  # print STDERR "pfam acc: $pfam_acc\n";

  open MAPPING, "< $self->{iproMapping}" or die "can't open file, $!\n";

  while (<MAPPING>) {
    my $line = $_;
    if ($line =~ /.+$pfam_acc.+/) {
      # print STDERR "line: $line\n";
      $line =~ /.+(IPR\d+)\s+(.+)/;
      $ipro_acc  = $1;
      $ipro_name = $2;
      chomp ($ipro_name); 
      last;
    }
  }

  close MAPPING;

  # print STDERR "ipro acc, ipro name: $ipro_acc, $ipro_name\n";

  return ($ipro_acc, $ipro_name);
}

sub mapIpro2GO {
  my $self = shift;
  my ($ipro_acc) = @_;
  my @go_list = ();
  
  print STDERR "mapping interpro 2 GO accession numbers...\n";

  open MAPPING, "< $self->{goMapping}" or die "can't open file, $!\n";

  while (<MAPPING>) {
    my $line = $_;
    if ($line =~ /.+$ipro_acc.+/) {
      print STDERR "line: $line\n";
      $line =~ /.+GO:(.+)\s\;\s(GO:\d+)/;
      my $go_term = $1;
      my $go_acc  = $2;

      print STDERR "go_term, go_acc: $go_term, $go_acc\n";

      my %go = (
		go_term => $go_term,
		go_acc  => $go_acc,
	       );
      push (@go_list, \%go);
    }
  }

  close MAPPING;

  print STDERR "go list dump: " . Dumper (@go_list) . "\n";

  return @go_list;
}


sub parse {
  my $self = shift;
  my %results;
  my @results = ();

  if (-d $self->{estwiseOutput}) {
    print STDERR "it's a directory\n";

    my @files = getFiles ($self->{estwiseOutput});
    foreach my $file (@files) {
      my @results_tmp = $self->parseOneFile ($file);
      push (@results, @results_tmp);
    }
  }
  else {
    print STDERR "it's a file\n";
    @results = $self->parseOneFile;
  }

  # print STDERR "#############\narray results object: " . Dumper (@results) . ", size: " . @results . "\n#############\n";

  # generate the %results hashtable

  print STDERR "generating estwise hashtable...\n";

  foreach my $result (@results) {
    # print STDERR "estwise hit: " . Dumper ($result) . "\n";
    if (defined $result->getESTAccession) {
      my $est = $result->getESTAccession;
      my @resultsPerEST = ();
      if (defined ($results{$est})) {
	my @resultsPerEST = @{$results{$est}};
	push (@resultsPerEST, $result);
	$results{$est} = \@resultsPerEST;
      }
      else {
	push (@resultsPerEST, $result);
	$results{$est} = \@resultsPerEST;
      }
    }
  }
  return %results;
}


sub parseOneFile {
  my $self = shift;
  my $file = "";
  if (@_) {
    $file = shift;
  }
  else {
    $file = $self->{estwiseOutput};
  }
  my @results = ();

  print STDERR "parsing file, $file...\n";

  open ESTWISE, "< $file" or die "can't open file, $!\n";

  # activate filter initially
  my $filter = 1;
  while (<ESTWISE>) {
    my $line = $_;
    # print STDERR "line: $line\n";
    if ($line =~ /High Score list/i) {
      # print STDERR "deactivate filtering\n";
      $filter = 0;
      $line = <ESTWISE>;
      $line = <ESTWISE>;
      $line = <ESTWISE>;
    }
    if ((not $filter) && (not $line =~ /^\w/)) {
      $filter = 1;
      # last;
    }
    
    if (not $filter) {
      # parsing line
      # print STDERR "parsing line, $line.\n";
      $line =~ /Protein\s+(\w+\-*\w*)\s+DNA\s+(\S+)\s+(\S+)\s+(\d+\.\d+)/;

      my $est_acc   = $3;
      my $strand    = $2;
      my $pfam_name = $1;
      my $pfam_acc = undef;

      # print STDERR "pfam name: $pfam_name\n";

      if (defined $pfam_name) {
	$pfam_acc  = $self->mapPfam_name_accession ($pfam_name);
      }

      my $bits       = $4;

      my $ipro_acc   = "undefined";
      my $ipro_name = "undefined";
      my @go_accs    = ();

      if (defined ($pfam_acc)) {
	($ipro_acc, $ipro_name)  = $self->mapPfam2Ipro ($pfam_acc);
	@go_accs = $self->mapIpro2GO ($ipro_acc);
      }
      else {
	$pfam_acc = "undefined";
      }

      my $estwise_hit = Bio::PSU::Utils::EstwiseHit->new (
							  est_accession => $est_acc,
							  strand => $strand,
							  pfam_name => $pfam_name,
							  pfam_accession => $pfam_acc,
							  ipro_accession => $ipro_acc,
							  ipro_name => $ipro_name,
							  go_accessions => \@go_accs,
							  bits => $bits,
							 );

      push (@results, $estwise_hit);
    }
  }

  print STDERR "parsing done.\n";

  close ESTWISE;

  # @results = $self->sort_by_EST (@results);
  # print STDERR "array size: " . @results . "\n";
  # print STDERR "#############\narray results object: " . Dumper (@results) . "\n#############\n";

  return @results;
}

sub sort_by_EST {
  my $self = shift;
  my (@results) = @_;
  my @new_results = ();
  
  while (@results) {
    my ($index, $estwise_hit) = getMinEST (@results);
    push (@new_results, $estwise_hit);
    splice (@results, $index, 1);
  }

  return @new_results;
}

sub getMinEST {
  my (@results) = @_;
  my $index = 0;
  my $estwise_hit = undef;
  my $est_acc_min = undef;

  my $i = 0;
  while ($i<@results) {
    my $estwise_hit_tmp = $results[$i];
    if (not defined $estwise_hit) {
      $estwise_hit = $estwise_hit_tmp;
      $est_acc_min = $estwise_hit_tmp->getESTAccession;
    }
    else {
      my $est_acc_tmp = $estwise_hit_tmp->getESTAccession;
      if (($est_acc_tmp cmp $est_acc_min) == -1) {
	$estwise_hit = $estwise_hit_tmp;
	$est_acc_min = $est_acc_tmp;
	$index = $i;
      }
    }
    $i++;
  }

  return ($index, $estwise_hit);
}

sub getFiles {
  my ($directory) = @_;
  my @files = ();
  
  opendir (THISDIR, $directory) or die "can not read this directory, $!\n";
  @files = map {$directory."/".$_} grep {($_ =~ /.*\.res$/)} readdir THISDIR;
  closedir THISDIR;
  
  # print STDERR "files: @files\n";

  return @files;
}
