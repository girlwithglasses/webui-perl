package Bio::PSU::Utils::GenericPSU_to_GO;

use strict;
use Data::Dumper;
use Carp;

my $debug = 0;

sub new {
  my $invocant = shift;
  my $class    = ref ($invocant) || $invocant;
  if(@_ % 2) {
    croak "Default options must be name => value pairs (odd number supplied)";
  }

  my $self = {
	      @_,
	     };
  
  bless ($self, $class);
  return $self;
}

sub embl_parsing {
  my $self = shift;
  my ($seq, $tigr_format, $db_name, $taxon_id) = @_;
  
  my $time;
  
  {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    
    $year += 1900;
    
    $time = sprintf "%s%2.2d%2.2d", $year, $mon, $mday;
  }
  
  if (defined $seq) {
    my @features = ();
    
  FEATURE:
    for my $feature ($seq->features) {
      next unless $feature->key () eq "CDS";
      
      if ((not $tigr_format) && $feature->qexists ('pseudo')) {
	print STDERR "pseudogene!\n";
	next;
      }
      
      my @feat_name = $feature->qvalues ("FEAT_NAME");
      
      if ($tigr_format && (!@feat_name || @feat_name > 1)) {
	die "no /FEAT_NAME at: " . get_range_string ($feature) . "\n";
      }
      
      my $feat_name = $feat_name[0];
      
      my @genes = ($feature->gene (), $feature->label());
      
      if (!@genes && !@feat_name && !$tigr_format) {
	warn "no /gene and no /FEAT_NAME at: ", get_range_string($feature), "\n";
	next FEATURE;
      }
      
      my $pfc_gene_name;
      my $mal_gene_name;
      
      for my $gene (map {split /\s*,\s*/, $_} @genes) {
	if ($gene =~ /^(PF\w\d\d\d+\S+|Tb927\.\d+\.\d+)$/) {
	  $pfc_gene_name = $1;
	} else {
	  if ($gene =~ /^(MAL\S+\.\d+[a-z]?)$/) {
	    $mal_gene_name = $1;
	  } else {
	    warn "can't fathom this /gene name: $gene\n";
	  }
	}
      }
      
      # added by axk
      $pfc_gene_name = $genes[0];
      
      #if (defined $pfc_gene_name && !defined $mal_gene_name &&
      #    $pfc_gene_name =~ /^Tb927\.\d+\.\d+$/) {
      #  $mal_gene_name = $pfc_gene_name;
      #}
      
      # disabled by axk
      $mal_gene_name = $pfc_gene_name;
      
      if (!defined $mal_gene_name) {
	my @feat_name = $feature->qvalues ("FEAT_NAME");
	
	if (@feat_name) {
	  $mal_gene_name = $feat_name[0];
	} else {
	  die "no MAL /gene name and no /FEAT_NAME at: " .
	    get_range_string ($feature);
	}
      }
      
      if (!$tigr_format && (!defined $pfc_gene_name or
			    !defined $mal_gene_name)) {
	warn "missing a MAL... gene name or a FPC... gene name at: ",
        get_range_string ($feature), "\n";
	
	if (!defined $pfc_gene_name) {
	  $pfc_gene_name = "";
	}
	
	if (!defined $mal_gene_name) {
	  $mal_gene_name = "";
	}
      }
      
      my @products = $feature->product ();
      
      my $product = "";
      
      if (!@products && !$tigr_format) {
	warn "no /product at: " . get_range_string ($feature);
      } else {
	$product = join "|", @products;
      }
      
      my @GO_component = ();
      
      if ($feature->qexists ("GO_component")) {
	@GO_component = $feature->qvalues ("GO_component");
      }
      
      my @GO_function = ();
      
      if ($feature->qexists ("GO_function")) {
	@GO_function = $feature->qvalues ("GO_function")
      }
      
      my @GO_process = ();
      
      if ($feature->qexists ("GO_process")) {
	@GO_process = $feature->qvalues ("GO_process");
      }
      
      my @all_go_qualifiers = ();
      
      push @all_go_qualifiers, map { "component; $_" } @GO_component;
      push @all_go_qualifiers, map { "function; $_" } @GO_function;
      push @all_go_qualifiers, map { "process; $_" } @GO_process;
      
      for my $go_qualifier (@all_go_qualifiers) {
	$go_qualifier =~ s/^\s*(.*)\s*$/$1/;
	
	my ($ontology, $go_id, $evidence_code, $ev_code_db_ids, $the_rest) =
	  split /\s*;\s*/, $go_qualifier, 5;
	
	if (!defined $go_id) {
	  warn "no go id in /GO_$ontology qualifier for $mal_gene_name\n";
	  next FEATURE;
	}
	
	if (!defined $evidence_code) {
	  warn "no evidence_code in /GO_$ontology qualifier for $mal_gene_name\n";
	  next FEATURE;
	}
	
	if ($feature->pseudo) {
	  warn "skipping pseudogene at: " . get_range_string ($feature);
	  next FEATURE;
	}
	
	my $ontology_id;
	
	if ($ontology =~ /^([pcf])/i) {
	  $ontology_id = uc $1;
	} else {
	  die "internal error";
	}
	
	my $source_ev_code;
	my $source_db_id;
	
	if (defined $the_rest && $the_rest =~ /source \((\S+)\s*;\s*(\S+)\)/) {
	  $source_ev_code = $1;
	  $source_db_id = $2;
	}
	
	my $not_flag = 0;
	
	if ($go_id =~ s/^NOT //) {
	  $not_flag = 1;
	}
	
	my $go_id_description;
	
	$go_id =~ s/(\S*)\s*\((.*)\)/$1/;
	
	$go_id_description = $2;
	
	my $pubmed_id = "PMID:unpublished";
	
	if (defined $ev_code_db_ids) {
	  if ($ev_code_db_ids =~ /^SWALL/) {
	    $ev_code_db_ids =~ s/\s*\(/|/;
	    $ev_code_db_ids =~ s/\)//;
	    
	    $ev_code_db_ids =~ s/SWALL:/SP:/g;
	  } else {
	    if ($ev_code_db_ids =~ /(PMID:\S+)/) {
	      $pubmed_id = $1;
	    }
	    
	    $ev_code_db_ids = "";
	  }
	} else {
	  $ev_code_db_ids = "";
	}
	
	my $db_object_id;
	my $db_object_symbol;
	
	my $synonym = "";
	
	if ($tigr_format) {
	  if (defined $mal_gene_name) {
	    $synonym = $mal_gene_name;
	  }
	  $db_object_id = $feat_name;
	  
	  my $locus = ($feature->qvalues ("LOCUS"))[0];
	  
	  if (defined $locus) {
	    $db_object_symbol = $locus;
	  } else {
	    warn "couldn't find /LOCUS at: ", get_range_string($feature), "\n";
	    $db_object_symbol = "LOCUS_UNKNOWN";
	  }
	} else {
	  $db_object_id = $mal_gene_name;
	  $db_object_symbol = $pfc_gene_name;
	}
	
	print "$db_name\t$db_object_id\t$db_object_symbol\t\t$go_id\t$pubmed_id\t$evidence_code\t$ev_code_db_ids\t$ontology_id\t$product\t$synonym\tgene\ttaxon:$taxon_id\t$time\n";
      }
    }
  } else {
    die "End of file while reading tab file\n";
  }
}

sub get_range_string
{
  my ($feature) = shift;
  my @ranges = map {
    $_->{start} . ".." . $_->{end}
  } $feature->ranges ();

  return join ",", @ranges;
}

#########
# END
##
