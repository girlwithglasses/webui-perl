=head1 QualifierEditor::HitInfo

QualifierEditor::HitInfo - This object contains the information about one
search hit in the qualifier_editor application

$Header: /scratch/svn-conversion/img_dev/v2/webUI/webui.cgi/psu_diagram/lib/QualifierEditor/HitInfo.pm,v 1.1 2013-03-27 20:41:23 jinghuahuang Exp $

=cut

package QualifierEditor::HitInfo;

use Exporter;
use strict;

use vars qw(@ISA @EXPORT_OK);

@ISA = qw(Exporter);

@EXPORT_OK = qw (get_protein_databases get_dna_databases);

# change these variables to list the databases to search for the IDs
my $PROTEIN_DATABASES = "swall";

$PROTEIN_DATABASES =~ s/ /%20/g;

sub get_protein_databases
{
  return $PROTEIN_DATABASES;
}

# change these variables to list the databases to search for the IDs
my $DNA_DATABASES = "embl";

$DNA_DATABASES =~ s/ /%20/g;

sub get_dna_databases
{
  return $DNA_DATABASES;
}

my @srs_prot_libs = get_protein_databases ();
my $srs_prot_libs = "@srs_prot_libs";
my @srs_prot_libs_shortnames = qw(sw swnew tr trnew);
my $srs_prot_libs_shortnames = "@srs_prot_libs_shortnames";

my %ids_i_have_seen = ();

# a mapping from field names to SWALL line start characters
my %srs_field_info =
(id => "ID",
 organism => "OS",
 description => "DE",
 genename => "GN",
 acc => "AC",
 dbxref => "DR");

# a list of the fields that we are likely to need
my @default_srs_fields = qw(id acc dbxref organism description genename);

my %global_cache = ();

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;

  my $self = {
              %args
             };

  bless $self, $class;

  my $id = $self->{id};

  $id =~ s/(?:\w+)\|(.*)/$1/;

  $ids_i_have_seen{$id}++;

  return $self;
}

# return the given field for this id.  the DE, OS part of the line will be
# removed and the lines will be concatenated
sub get_concatenated_lines ($$)
{
  my ($self, $field_name) = @_;

  my $lines_string = $self->get_field_from_id ($field_name);

  my $line_start = $srs_field_info{$field_name};

  # remove all lines that don't befin with the right two letter code
  my @stripped_lines = $lines_string =~ m/^$line_start\s+(.*)/mg;

#    print STDERR "\nall: $lines_string\n:*****:\n";

#    for my $bit (@stripped_lines) {
#      print STDERR "bit: $bit\n";
#    }

  $lines_string = join " ", @stripped_lines;

  $lines_string =~ s/^$line_start\s+(.*)/$1 /mg;

  $lines_string =~ s/\n/ /mg;
  $lines_string =~ s/\s+/ /g;
  $lines_string =~ s/\.?\s*$//g;

#  print STDERR "returning: $lines_string:\n";

  return $lines_string;
}


  # return the organism name of the given $id using SRS
sub get_organism ($)
{
  my ($self) = @_;

  my $organism = $self->get_concatenated_lines ("organism");

  if (!defined $organism || $organism =~ /^\s*$/) {

    if ($self->{id} =~ /^Y[A-P][LR]\d\d\d[WC]$/) {
      # it looks like a Yeast Y-code
      return "Saccharomyces cerevisiae";
    }

    warn "can't find organism for ", $self->{id}, "\n";
    return undef;
  }

  $organism =~ s/^([^\(]+)\s*\(.*$/$1/;

  $organism =~ s/\s*$//;

#  print "organism: $organism\n";

  return $organism;
}

# return the product of the protein with the given $id using SRS
sub get_product
{
  my ($self) = @_;

  my $des = lc $self->get_concatenated_lines ("description");

  my $return_value;

  my @things_to_uc =
    qw(n- o- d- l- dna dnaj atp gtp abc rna 60s 28s 18s 5s cgi cg atp gtp ctp
       ttp nadph nadp nadh nad);

  my %things_to_uc = (
                      atpase => "ATPase",
                      rrna => "rRNA",
                      cdna => "cDNA",
                     );

  if ($des =~ m/^(.*?)\s*\(/) {
    my $product = $1;

    $return_value = $product;
  } else {
    $return_value = $des;
  }

  my $gene_name = $self->get_gene_name;

  if (defined $gene_name) {
    my $capitalized_gene_name = $gene_name;

    if ($capitalized_gene_name =~ s/^(.)(.*)(.)$/\u$1\E\L$2\E\u$3\E/) {
      $return_value =~ s/$gene_name/$capitalized_gene_name/i;
    }
  }

  for my $word (@things_to_uc) {
    $return_value =~ s/\b$word\b/\U$word\E/;
  }

  for my $word (keys %things_to_uc) {
    my $new_word = $things_to_uc{$word};

    $return_value =~ s/\b$word\b/$new_word/i;
  }

  $return_value =~ s/\bkd\b/kD/;
  $return_value =~ s/\bkda\b/kDa/;

  return $return_value;
}

# return the EC number of the protein with the given $id using SRS
sub get_ecnumber
{
  my ($self) = @_;

  my $des = $self->get_concatenated_lines ("description");

  if ($des =~ /\(EC\s*([^\)]+)\)/) {
    return $1;
  } else {
    return undef;
  }
}

# return the accession number of the protein with the given $id using SRS
sub get_acc_number
{
  my ($self) = @_;

  my $acc_line = $self->get_field_from_id ("acc");

  if (defined $acc_line && $acc_line =~ /^AC\s+([^ ;]+)/) {
    return $1;
  } else {
    return undef;
  }
}

# return the accession number of the EMBL entry that this protein came from
sub get_embl_acc_number
{
  my ($self) = @_;

  my $id = $self->{id};

  my $dbxref_line = $self->get_field_from_id ("dbxref");

  if ($dbxref_line =~ /^DR   EMBL; ([^;]+)/) {
    my $acc = $1;

    return $acc;
  }

  warn "can't find EMBL entry for $id\n";

  return "UNKNOWN ACCESSION";
}

# return the gene name of the protein with the given $id using SRS
sub get_gene_name ($)
{
  my ($self) = @_;

  my $gn_line = $self->get_field_from_id ("genename");

  if (defined $gn_line && $gn_line =~ /^gn\s+(.*?)\.?\s*$/i) {
    my $gene_name = $1;

    $gene_name =~ s/(.*)(.)/\L$1\E\U$2/;

    return $gene_name;
  } else {
    return undef;
  }
}

sub add_to_cache
{
  my %fields = %{$_[0]};

  my $acc_line = $fields{acc};
  my $id_line = $fields{id};

  my $id = "dummy";
  my $acc = "dummy";

  if ($acc_line =~  /^AC   ([^\s;]+)/) {
    $acc = $1;
  }

  if ($id_line =~ /^ID   (\S+)/) {
    $id = $1;
  }

  my $dr_lines = $fields{dbxref};

#  print STDERR "id: $id\n";

  my @embl_prot_ids = ();

  if ($dr_lines =~ /DR   EMBL;/) {
    @embl_prot_ids = ($dr_lines =~ /([\w\d]+)\.\d+/g);

#    print STDERR "@embl_prot_ids\n";
  }

  my @new_cache_keys = ($acc, $id, @embl_prot_ids);

  my %cache_keys = ();

  @cache_keys{@new_cache_keys} = @new_cache_keys;

#  print STDERR "new cache keys: @new_cache_keys\n";


  for my $id_acc (keys %cache_keys) {
    for my $field_name (keys %fields) {
      if (exists $global_cache{$id_acc}{$field_name}) {
        warn "$id_acc $field_name -> $global_cache{$id_acc}{$field_name}\n";
      } else {
#        print STDERR "adding $id_acc $field_name " . $fields{$field_name}, "\n";

        $global_cache{$id_acc}{$field_name} = $fields{$field_name};
      }
    }
  }
}

# return a data field for this ID from SRS
sub get_field_from_id
{
  my ($self, $field_name) = @_;

  my $id = $self->{id};

  $id =~ s/(?:\w+)\|(.*)/$1/;

#  print STDERR $id, " -> $field_name\n";

  # special case for tremblnew entries - check tremblnew and if the entry
  # isn't there, get the entry from TREMBL via the dbxref
  if (0 && $id =~ /[a-z][a-z][a-z]\d\d\d\d\d/i) {
    if (!exists $global_cache{$id}{$field_name}) {

      warn "here be dragons\n";

      my $getz_command =
        "getz -f $field_name \"[\{$srs_prot_libs\}-dbxref:$id*]\" |";

#      print STDERR "$getz_command\n";

      open (GETZ, $getz_command) or die "can't open pipe to getz\n";

      local $/ = undef;

      my $field = <GETZ>;

      close GETZ or die "can't close pipe to getz\n";

      $global_cache{$id}{$field_name} = $field;

#      print STDERR "found for $field_name via dbxref: ", $global_cache{$id}{$field_name};
    } else {
#      print STDERR "found in cache for $field_name via dbxref: ", $global_cache{$id}{$field_name};

    }

    return $global_cache{$id}{$field_name};
  }


  if (keys %global_cache) {
    if (exists $global_cache{$id}{$field_name}) {
#      print STDERR "returning for $field_name: ", $global_cache{$id}{$field_name};
      return $global_cache{$id}{$field_name}
    } else {
      warn "not found in cache: $field_name for ", $id;
      return undef;
    }
  }

  if (!exists $ids_i_have_seen{$id}) {
    warn "internal error: haven't seen $id before";
    $ids_i_have_seen{$id}++;
  }

  my $id_string = join "|", keys %ids_i_have_seen;

  my $field_string = join " ", @default_srs_fields;

  my $getz_command =
    "getz -f '$field_string' \"[libs={$srs_prot_libs}-acc: $id_string] | [libs={$srs_prot_libs}-id: $id_string] | [libs-ProteinID: $id_string] | [libs-dbxref: $id_string*] \" |";

#  print STDERR "$getz_command\n";

  open (GETZ, $getz_command) or die "can't open pipe to getz\n";

  my %temp_cache = ();

  while (my $current_line = <GETZ>) {
#    print STDERR "read: $current_line\n";

    for my $field_long_name (@default_srs_fields) {
#          print STDERR "$field_long_name\n";

      my $field_short_name = $srs_field_info{$field_long_name};

      if ($current_line =~ /^$field_short_name   /) {
#        print STDERR "adding $current_line->$field_long_name\n";

        if (keys %temp_cache && $current_line =~ /^ID   /) {
          add_to_cache \%temp_cache;
          %temp_cache = ();
        }

        if (exists $temp_cache{$field_long_name}) {
          $temp_cache{$field_long_name} .= $current_line;
        } else {
          $temp_cache{$field_long_name} = $current_line;
        }
      }
    }
  }

  add_to_cache \%temp_cache;

#  print STDERR "found for $field_name: ", $global_cache{$id}{$field_name};

  close GETZ or die "can't close pipe to getz\n";

  return $global_cache{$id}{$field_name};
}

1;
