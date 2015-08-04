=head1 QualifierEditor::GO

QualifierEditor::App - This package contains the GO reader for the
qualifier_editor application (aka. MESS).

$Header: /scratch/svn-conversion/img_dev/v2/webUI/webui.cgi/psu_diagram/lib/QualifierEditor/GO.pm,v 1.1 2013-03-27 20:41:23 jinghuahuang Exp $

=cut

package QualifierEditor::GO;

use strict;
use Exporter;
use Carp;
use GDBM_File;
use FreezeThaw qw(freeze thaw);
use Benchmark;

use vars qw(@ISA @EXPORT_OK);

@ISA = qw(Exporter);

@EXPORT_OK = qw(get_go_ontology_name get_go_description get_go_mapping
                get_go_name make_dbm_files);

my $go_files_directory = "/nfs/disk222/yeastpub/analysis/pathogen/GO";
my $go_flattened_file = $go_files_directory . "/go.flat";
my $go_flattened_name_db_file = $go_flattened_file . ".name.db";
my $go_flattened_desc_db_file = $go_flattened_file . ".desc.db";
my $go_flattened_ontology_db_file = $go_flattened_file . ".ontology.db";
my $go_mapping_file = $go_files_directory . "/gene_association.all";
my $go_mapping_db_file = $go_mapping_file . ".db";


# indexed by GO id, contents are the term name:
#   $go_flattened{GO:012345} = "term name"
my %go_flattened_name = ();
# indexed by GO id, contents are the go term description
#   $go_flattened{GO:012345}{description}
my %go_flattened_desc = ();
# values are "F", "C" or "P"
my %go_flattened_ontology = ();

# indexed by gene id
my %mapping = ();

BEGIN {
#  tie %mapping, 'GDBM_File', $go_mapping_db_file, &GDBM_READER, 0664;
#  tie %go_flattened, 'GDBM_File', $go_flattened_db_file, &GDBM_READER, 0664;
}

# if argv is 1 the dbm file will be opened read-write
sub tie_me ($)
{
  my $flags;

  if ($_[0]) {
    $flags = (&GDBM_NEWDB | &GDBM_FAST);
  } else {
    $flags = (&GDBM_READER | &GDBM_FAST);
  }

  my $db_type = 'GDBM_File';

  tie %mapping, $db_type, $go_mapping_db_file, $flags, 0664 or
    die "can't open $go_mapping_db_file: $!\n";
  tie (%go_flattened_name,
       $db_type, $go_flattened_name_db_file, $flags, 0664) or
    die "can't open $go_flattened_name_db_file: $!\n";
  tie (%go_flattened_desc,
       $db_type, $go_flattened_desc_db_file, $flags, 0664) or
    die "can't open $go_flattened_desc_db_file: $!\n";
  tie (%go_flattened_ontology,
       $db_type, $go_flattened_ontology_db_file, $flags, 0664) or
    die "can't open $go_flattened_ontology_db_file: $!\n";
}

sub make_dbm_files
{
  tie_me (1);

  open FILE, $go_flattened_file or die "can't open $go_flattened_file\n";

  while (my $line = <FILE>) {
    if ($line =~ /^(GO:\d+)\t([^\t]*)\t(.*)/) {
      # only save the ids that are annotated in the mappings file
      if (length $2) {
        $go_flattened_name{$1} = $2;
      }
      if (length $3) {
        $go_flattened_desc{$1} = $3;
      }
    }
  }

  if (keys %go_flattened_name == 0) {
    die "failed to read anything from $go_flattened_file\n";
  }

  close FILE;

  # Read the mapping file into %mapping.  The key of the %mapping hash
  # is the database id of the protein.  The value of the hash is an
  # array of hashes of this form {go_id=>"GO:0005743",
  # evidence_code=>"ISS"}.  Ontology codes (F, P, C) are added to the
  # %go_flattened hash: {GO:0005743}{ontology=>"F"}

  open FILE, $go_mapping_file or die "can't open $go_mapping_file\n";

  # create in memory first
  my %temp_mapping = ();

  while (my $line = <FILE>) {
    if ($line =~ /^([^\t]+)\t  # database name
                   ([^\t]+)\t  # ID
                   ([^\t]*)\t  # gene name
                   ([^\t]*)\t  # dunno
                   ([^\t]+)\t  # GO ID
                   ([^\t]*)\t  # internal database information
                   ([^\t]*)\t  # evidence code
                   ([^\t]*)\t  # might be NO meaning the not this GO id
                   ([^\t]*)\t  # ontology tag (F,C or P)
                   ([^\t]*)\t  # dunno
                   ([^\t]*)\t  # dunno
                   (?:([^\t]*)\t)?  # dunno
                   taxon(?:ID)?:(\d+)    # taxon
                  /x) {
      my $database_name = $1;
      my $database_id = $2;
      my $gene_name = $3;
      my $go_id = $5;
      my $internal_db_info = $6;
      my $evidence_code = $7;
      my $no_flag = $8;
      my $ontology_tag = $9;
      my $taxon_id = $13;

      if ($no_flag !~ /no/i
          #  && $evidence_code ne "IEA"
         ) {

#        print "pushing $database_id -> {go_id => $go_id, evidence_code => $evidence_code, database_name => $database_name,};\n";

        push @{$temp_mapping{$database_id}},
        {
         database_name    => $database_name,
         database_id      => $database_id,
         evidence_code    => $evidence_code,
         internal_db_info => $internal_db_info,
         go_id            => $go_id,
         taxon_id         => $taxon_id,
         taxon_species    => get_species_from_taxonid ($taxon_id),
        };

        $go_flattened_ontology{$go_id} = $ontology_tag;
      }
    } else {
      if ($line !~ /^\s*!|^\s*$/) {
        warn "can't fathom line $. from $go_mapping_file:\n$line";
      }
    }
  }

  if (keys %temp_mapping == 0) {
    die "failed to read anything from $go_mapping_file";
  }

  close FILE;

  tie %mapping, 'GDBM_File', $go_mapping_db_file, &GDBM_NEWDB | &GDBM_FAST, 0664;

  for my $key (keys %temp_mapping) {
#    print $key, " ", $temp_mapping{$key},"\n";

    $mapping{$key} = freeze ($temp_mapping{$key})
  }

  untie %mapping;
  untie %go_flattened_name;
  untie %go_flattened_desc;
  untie %go_flattened_ontology;
}

# return the description of the given GO id.  returns undef if the id
# doesn't (yet) have a description
sub get_go_description
{
  my $go_id = shift;

  if (!defined tied %mapping) {
    tie_me 0;
  }

  return $go_flattened_desc{$go_id};
}

# return the name of the given GO id.  returns undef if the id
# doesn't have a name.
sub get_go_name
{
  my $go_id = shift;

  if (!defined tied %mapping) {
    tie_me 0;
  }

  return $go_flattened_name{$go_id};
}

# return the ontology tag of the ontology that contains the given GO id.
# returns C, F or P or undef if we don't know.
sub get_go_ontology_name
{
  my $go_id = shift;

  if (!defined tied %mapping) {
    tie_me 0;
  }

  my $return_value = $go_flattened_ontology{$go_id};

  return $return_value;
}

my %mapping_cache = ();

my $count = 0;

# Return an array containing all the go ids associated with the given
# gene_id.
# Each element of the array is a hash contains a go id and
# a description: {go_id => "GO:0005743", evidence_code => "ISS"}
sub get_go_mapping
{
  my $gene_id = shift;

  $gene_id =~ s/(?:\w+)\|(.*)/$1/;

  if (!exists $mapping_cache{$gene_id}) {
    if (!defined tied %mapping) {
      tie_me 0;
    }

    my $value = $mapping{$gene_id};

    if (defined $value) {
      my ($thawed) = thaw ($value);

      $mapping_cache{$gene_id} = $thawed;
    } else {
      print STDERR "\ncan't find: $gene_id in the association file\n";

      return ();
    }
  }

  my @return_value = @{$mapping_cache{$gene_id}};

  return @return_value;
}


my %taxon_cache = ();

# return a data field for this ID from SRS
sub get_species_from_taxonid
{
  my $taxonid = shift;

  my $field_name = "species";

  if (!exists $taxon_cache{$taxonid}{$field_name}) {

    my $getz_command =
      "getz -f $field_name \"[taxonomy-id: $taxonid]\" |";

    open (GETZ, $getz_command) or die "can't open pipe to getz\n";
    local $/ = undef;
    my $field = <GETZ>;
    close GETZ or die "can't close pipe to getz\n";

    chomp $field;

    if ($field =~ /SCIENTIFIC NAME\s*:\s*(.*)/) {
      $taxon_cache{$taxonid}{$field_name} = $1;
    } else {
      die "can't understand this taxon species: $field from $taxonid\n";
    }
  }

  return $taxon_cache{$taxonid}{$field_name};
}

1;
