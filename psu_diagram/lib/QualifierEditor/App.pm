=head1 QualifierEditor::HitInfo

QualifierEditor::App - This package contains the guts of the qualifier_editor
application.

$Header: /scratch/svn-conversion/img_dev/v2/webUI/webui.cgi/psu_diagram/lib/QualifierEditor/App.pm,v 1.1 2013-03-27 20:41:23 jinghuahuang Exp $

=cut

package QualifierEditor::App;

use strict;
use Exporter;

use Tk;
use Tk::Adjuster;
use Tk::Dialog;

use QualifierEditor::HitInfo qw(get_protein_databases get_dna_databases);
use QualifierEditor::HitInfoCollection;
use QualifierEditor::GO qw(get_go_mapping get_go_ontology_name
                           get_go_description get_go_name);

use vars qw(@ISA @EXPORT_OK);

@ISA = qw(Exporter);

@EXPORT_OK = qw (create_app make_prok_note make_euk_similarity);

my $global_font           = "fixed";
my $id_desc_width         = 110;
my $button_xpad           = 1;
my $button_ypad           = 1;
my $text_height           = 2;
my $fasta_button_t_height = 25;
my $srs_command           = "getz";
my $pointer_cursor        = "top_left_arrow";
my $button_pack_padx      = 5;

my $NETSCAPE = "/usr/bin/X11/real-netscape";

# change this to point to the wgetz script of your SRS server
my $SRS_SERVER = "srs.sanger.ac.uk/srs6bin/cgi-bin/wgetz?-e+";


# change this subroutine to change the generated qualifiers
sub get_new_qualifiers ($$$)
{
  my ($old_qualifiers_string, $info_holder, $params) = @_;

  my $new_qualifiers = "";

  my @selected_go_ids = ();

  for my $info ($info_holder->all_values) {
    for my $hit (@{$info->{_selected_go_ids}}) {
      push @selected_go_ids, { info=>$info, hit=>$hit };
    }
  }

  for my $selected_go_id_info (@selected_go_ids) {
    my $info = $selected_go_id_info->{info};
    my $hit = $selected_go_id_info->{hit};
    my $go_id = $hit->{go_id};

#      print STDERR keys %{$hit},"\n";
#      print STDERR "$go_id\n";

    my $ontology_tag = get_go_ontology_name ($go_id);
    my $ontology_name = "[unknown_ontology]";

    if (defined $ontology_tag) {
      if (lc $ontology_tag eq "p") {
        $ontology_name = "process";
      } else {
        if (lc $ontology_tag eq "c") {
          $ontology_name = "component";
        } else {
          if (lc $ontology_tag eq "f") {
            $ontology_name = "function";
          }
        }
      }
    }


    my $go_name = get_go_name ($go_id);

    if (defined $go_name) {
      $new_qualifiers .= qq|/GO_$ontology_name="$go_id ($go_name);|;
    } else {
      $new_qualifiers .= qq|/GO_$ontology_name="$go_id;|;
    }

    my $go_desc = get_go_description ($go_id);

    $new_qualifiers .=  " ISS;";

    my $protein_id = $info->{id};

    my $hit_db_name = $hit->{database_name};
    my $hit_db_id = $hit->{database_id};
    my $hit_evidence_code = $hit->{evidence_code};
    my $hit_internal_db_info = $hit->{internal_db_info};

    $new_qualifiers .= qq| SWALL:$protein_id ($hit_db_name:$hit_db_id);|;
    $new_qualifiers .= qq| source ($hit_evidence_code; $hit_internal_db_info);|;

#      if (defined $go_desc) {
#        $new_qualifiers .= " $go_desc";
#      }

    $new_qualifiers .= qq|"\n|;
  }

  $new_qualifiers .= qualifier_maker_sub ($info_holder, $params);

#    if (@selected_info_refs) {
#      my $note_value =
#        "Similar to " . ($qualifier_maker_sub->(shift @selected_info_refs));

#      for my $info_ref (@selected_info_refs) {
#        $note_value .= ", and to " . $qualifier_maker_sub->($info_ref);
#      }

#      $new_qualifiers .= qq|/note="$note_value"\n|;

#      if (defined $orth_ref) {
#        my $orth_id = $orth_ref->{id};

#        my $orth_product = $orth_ref->get_product ();
#        my $orth_ecnumber = $orth_ref->get_ecnumber ();
#        my $orth_gene_name = $orth_ref->get_gene_name ();

#        if (defined $orth_product) {
#          $new_qualifiers .= qq|/product="$orth_product"\n|;
#        }
#        if (defined $orth_ecnumber) {
#          $new_qualifiers .= qq|/EC_number="$orth_ecnumber"\n|;
#        }
#        if (defined $orth_gene_name) {
#          $new_qualifiers .= qq|/gene="$orth_gene_name"\n|;
#        }
#      }
#    }

  return $new_qualifiers . $old_qualifiers_string;
}

######################################################################

sub is_go
{
  my $params = shift;

  my $results_type = $params->{results_type};

  if ($results_type =~ /\+go$/) {
    1;
  } else {
    0;
  }
}


# return a string containing the name, description and ontology of the given
# GO id
sub get_go_text
{
  my $go_id = shift;

  my $return_string = "";

  my $go_ontology_name = get_go_ontology_name ($go_id);

  if (defined $go_ontology_name) {
    $return_string = $go_ontology_name;
  } else {
    $return_string = "[unknown ontology]";
  }

  my $go_name = get_go_name ($go_id);

  $return_string .= "  -  ";

  if (defined $go_name) {
    $return_string .= $go_name;
  } else {
    $return_string .= "[unknown id]";
  }

  my $go_desc = get_go_description ($go_id);

  if (defined $go_desc) {
    $return_string .= "  -  $go_desc";
  }

  return $return_string;
}


# returns the contents of the file given by the /fasta_file or
# /blast_file in the given qualifiers
sub get_results_file ($$$$)
{
  my ($top_level_window,
      $base_directory, $qualifier_string, $qualifier_name) = @_;

  my $results_file_name;

  if ($qualifier_string =~ m!/\Q$qualifier_name\E="([^\"]+)"!) {
    $results_file_name = $1;
  } else {
    my $message = "Error: can't find /$qualifier_name qualifier";
    my $dialog = $top_level_window->Dialog (-title          =>
                                            "Error - file not found",
                                            -text           => $message,
                                            -default_button => 'Ok',
                                            -buttons        => ['Ok']);
    $dialog->Show();
    $dialog->destroy();

    die "$message\n";
  }

  my @return_lines = ();

  if (open IN_FILE, "$base_directory/$results_file_name" or
      -e "$base_directory/$results_file_name.gz" and
      open IN_FILE, "gzip -d < $base_directory/$results_file_name.gz |") {
    my $line;

    while (defined ($line = <IN_FILE>)) {
      push @return_lines, $line;
    }

    close IN_FILE;

    return @return_lines;

  } else {
    my $message = "Error: can't find $base_directory/$results_file_name";
    my $dialog = $top_level_window->Dialog (-title          =>
                                            "Error - file not found",
                                            -text           => $message,
                                            -default_button => 'Ok',
                                            -buttons        => ['Ok']);
    $dialog->Show();
    $dialog->destroy();

    die "$message\n";
  }
}

# Create a new Scrolled Text widget, parse the given fasta results
# and put the results in the new widget.  The sequence ID at the start
# of each alignment will be tagged with the id of the hit.

# Returns ($new_text_widget, $info_holder)
sub make_fasta_text ($\@)
{
  my ($parent, $fasta_file_text_ref) = @_;

  my @fasta_file_text = @{$fasta_file_text_ref};

  my $fasta_text_widget = $parent->Scrolled ("Text",
                                             -font => $global_font,
                                             -scrollbars => 'ose',
                                             -background => 'white',
                                             -height => $text_height,
                                             -width => 90);

  $fasta_text_widget->pack (-side => "right",
                            -expand => "y", -fill => "both");

  my $info_holder = new QualifierEditor::HitInfoCollection ();

  my %seen_ids = ();

  my $seen_top_of_summary = 0;
  my $seen_bottom_of_summary = 0;

  # the the id on the top of the last alignment line
  my $last_id;

  for my $line (@fasta_file_text) {
    if (!$seen_top_of_summary && $line =~ m/^The best scores are/) {
      $seen_top_of_summary = 1;
    } else {
      if ($seen_top_of_summary && !$seen_bottom_of_summary) {
        if ($line =~ m/^$/) {
          $seen_bottom_of_summary = 1;
        } else {
          # handle one line of the summary
          my ($id, $desc, $opt, $z_score, $e_value) =
            ($line =~ m{ ^(\S+)\s+    # id
                          (.*?)\s+     # description
                          ([\.\d]+)\s+ # opt
                          ([\.\d]+)\s+ # z-score
                          ([\.\de\-\+]+)\s* # evalue
                          $
                      }xg);

          my $orth_flag = 0;
          my $para_flag = 0;
          my $selected_flag = 0;

          if (defined $id) {

            $desc =~ s/^symbol://;

            if (!$seen_ids{$id}) {
              my %args = (id                => $id,
                          desc              => $desc,
                          opt               => $opt,
                          z_score           => $z_score,
                          e_value           => $e_value,
                          orth_flag_ref     => \$orth_flag,
                          para_flag_ref     => \$para_flag,
                          selected_flag_ref => \$selected_flag,
                         );

              my $new_info = new QualifierEditor::HitInfo (%args);

              $info_holder->add ($new_info);

              $seen_ids{$id} = $new_info;
            }
          } else {
            my $message = "The fasta input file is corrupted" .
              " or truncated at this line:\n" . $line;
            $parent->messageBox (-text => $message);
            die "$message\n";
          }
        }
      }
    }

    if ($seen_bottom_of_summary && $line =~
        m/^(?:>>)?(\S+)(\s+.*\s\((\d+)\s+aa\))/) {
      # this is the start of an alignment section

      $last_id = $1;

      my $rest_of_line = $2;

      exists $seen_ids{$last_id} ||
         die "error while reading the alignments: id $last_id doesn't exist\n";

      my $last_hit_info = $seen_ids{$last_id};

      $last_hit_info->{hit_length} = $3;

      if (!exists $last_hit_info->{_seen_alignment}) {
        # only do this if we haven't seen the alignment for this id
        # before (to handle duplicates)

        $fasta_text_widget->tagConfigure ($last_id, -background => "white");

        $fasta_text_widget->insert ('end', $last_id, $last_id);

        $fasta_text_widget->insert ('end', $rest_of_line . "\n");
      } else {
        $fasta_text_widget->insert ('end', $last_id . $rest_of_line . "\n");
      }
    } else {

      if ($line =~ m{ Smith-Waterman\s+score:\s+
                      (\d+);\s+   # sw_score
                      ([\d\.]+)\%\s+  # percent_id
                      identity\s+\(([\d\.]+)%\s+ungapped\)\s+
                      in\s+(\d+)\s+aa\s+overlap\s+\((\d+)-(\d+):(\d+)-(\d+)\)
                    }x) {

        exists $seen_ids{$last_id} || die "id $last_id doesn't exist\n";

        if (!exists $seen_ids{$last_id}{_seen_alignment}) {
          # only do this if we haven't seen the alignment for this id
          # before (to handle duplicates)
          my $info_ref = $seen_ids{$last_id};

          $info_ref->{sw_score} = $1;
          $info_ref->{percent_id} = int($2*100)/100.0;
          $info_ref->{ungapped_percent_id} = int($3*100)/100.0;
          $info_ref->{overlap} = $4;
          $info_ref->{query_start_pos} = $5;
          $info_ref->{query_end_pos} = $6;
          $info_ref->{subject_start_pos} = $7;
          $info_ref->{subject_end_pos} = $8;
        }

        $seen_ids{$last_id}{_seen_alignment} = 1;
      }

      $fasta_text_widget->insert ('end', $line);
    }
  }

  $fasta_text_widget->configure (-state => 'disabled');

  return ($fasta_text_widget, $info_holder);
}

# Create a new Scrolled Text widget, parse the given blastp results
# and put the results in the new widget.  The sequence ID at the start
# of each alignment will be tagged with the id of the hit.

# Returns ($new_text_widget, $info_holder)
sub make_blastp_text ($\@)
{
  my ($parent, $blastp_file_text_ref) = @_;

  my @blastp_file_text = @{$blastp_file_text_ref};

  my $blastp_text_widget = $parent->Scrolled ("Text",
                                              -font => $global_font,
                                              -scrollbars => 'ose',
                                              -background => 'white',
                                              -height => $text_height,
                                              -width => 80);

  $blastp_text_widget->pack (-side => "right",
                             -expand => "y", -fill => "both");

  my $info_holder = new QualifierEditor::HitInfoCollection ();

  my %seen_ids = ();

  my $seen_top_of_summary = 0;
  my $seen_bottom_of_summary = 0;

  # the the id on the top of the last alignment header section
  my $last_id;

  for my $line (@blastp_file_text) {
    if (!$seen_top_of_summary && $line =~ m/^Sequences producing /) {
      $seen_top_of_summary = 1;
    } else {
      if ($seen_top_of_summary == 1) {
        # 2 is a flag that indicates that we have seen the blank
        $seen_top_of_summary = 2;

        if ($line =~ m/^$/) {
          $blastp_text_widget->insert ('end', $line);
          next;
        } else {
          warn "warning: expected a blank line but got: $line\n";
        }
      }

      if ($seen_top_of_summary  && !$seen_bottom_of_summary) {
        if ($line =~ m/^$/) {
          $seen_bottom_of_summary = 1;
        } else {
          # handle one line of the summary
          #   TGL1_YEAST P34163 TRIGLYCERIDE LIPASE-CHOLESTEROL  345  2e-94
          # or
          #   UFD1_HUMAN Q92890 UBIQUITIN FUSION DEGRADATION   316  1.2e-49   2

          my ($id, $acc, $desc, $score, $prob, $n_value) =
            ($line =~ m{ ^(?:SGD:)?(\S+)\s+       # id
                          (\S+)\s+       # acc
                          (.*?)\s+       # description
                          (\d+)\s+   # score
                          ([\.\de\-\+]+) # prob
                          (?:\s+
                          ([\.\d]+)?\s*) # n_value (only blast 1)
                          $
                      }xg);

          my ($p_value, $e_value);

          my $orth_flag = 0;
          my $para_flag = 0;
          my $selected_flag = 0;

          if (defined $id) {
            $acc =~ s/^symbol://;

            if (defined $n_value) {
              $p_value = $prob;
              $e_value = undef;
            } else {
              $n_value = undef;
              $p_value = undef;
              $e_value = $prob;
            }

            if (!$seen_ids{$id}) {
              my %args = (id                => $id,
                          acc               => $acc,
                          desc              => $desc,
                          score             => $score,
                          e_value           => $e_value,
                          p_value           => $p_value,
                          n_value           => $n_value,
                          orth_flag_ref     => \$orth_flag,
                          para_flag_ref     => \$para_flag,
                          selected_flag_ref => \$selected_flag,
                         );

              my $new_info = new QualifierEditor::HitInfo (%args);

              $info_holder->add ($new_info);

              $seen_ids{$id} = $new_info;
            }
          } else {
            my $message = "The blast input file is corrupted" .
              " or truncated at this line:\n" . $line;

            $parent->messageBox (-text => $message);
            die "$message\n";
          }
        }
      }
    }

    if ($seen_bottom_of_summary) {

      if ($line =~ m/^>(?:SGD:)?(\S+)(.*)/) {
        # this is the start of an alignment section

        my $this_id = $1;
        $last_id = $this_id;
        my $rest_of_line = $2;

        if (!exists $seen_ids{$this_id}) {
          warn "error while reading the alignments: " .
               "id $this_id doesn't exist in the summary\n";
        }

        my $last_hit_info = $seen_ids{$this_id};

        $last_hit_info->{hit_length} = $3;

        if (!exists $last_hit_info->{_seen_alignment}) {
          # only do this if we haven't seen the alignment for this id
          # before (to handle duplicates)

          $blastp_text_widget->tagConfigure ($this_id, -background => "white");

          $blastp_text_widget->insert ('end', ">$this_id", $this_id);

          $blastp_text_widget->insert ('end', $rest_of_line . "\n");
        } else {
          $blastp_text_widget->insert ('end', $this_id . $rest_of_line . "\n");
        }
        next;
      } else {
        # Score = 1922 (676.6 bits), Expect = 1.3e-198, P = 1.3e-198
        if ($line =~ m{                # blast 1
                       ^\s*Score\s+=\s+(\d+)\s+    # score
                       \((\d+)\s+bits\),\s+         # bits
                       Expect\s+=\s+([\.\de\-\+]+),\s+   # expect
                       P\s+=\s+([\.\de\-\+]+)\s*   # p_value
                       $
                      }x) {
          # second line of the alignment section

          my $info_ref = $seen_ids{$last_id};

          $info_ref->{score} = $1;
          $info_ref->{bits}  = $2;
          $info_ref->{e_value} = $3;
          $info_ref->{p_value} = $1;
        } else {
          if ($line =~ m{                # blast 2
                         ^\s*Score\s+=\s+(\d+)\s+bits\s+\((\d+)\),\s+  # score
                         Expect\s+=\s+([\.\de\-\+]+)   # expect
                         $
                        }x) {

            my $last_hit_info = $seen_ids{$last_id};

            if (exists $last_hit_info->{_seen_alignment}) {
              # only do this if we haven't seen the alignment for this id
              # before (to handle multiple HSPs)

              next;
            }

            # second line of the alignment section

            my $info_ref = $seen_ids{$last_id};

            $info_ref->{bits}  = $1;
            $info_ref->{score} = $2;
          } else {
            # last line of the alignment header
            if ($line =~ /Identities\s+=\s+\d+\/\d+\s+\(([\d\.]+)\%\)/) {
              my $last_hit_info = $seen_ids{$last_id};

              if (exists $last_hit_info->{_seen_alignment}) {
                # only do this if we haven't seen the alignment for this id
                # before (to handle multiple HSPs)

                next;
              }

              my $info_ref = $seen_ids{$last_id};

              $info_ref->{percent_id} = $1;

              $seen_ids{$last_id}{_seen_alignment} = 1;
            }
          }
        }
      }
    }

    $blastp_text_widget->insert ('end', $line);
  }

  $blastp_text_widget->configure (-state => 'disabled');

  return ($blastp_text_widget, $info_holder);
}

sub make_entry_text ($$$$)
{
  my ($info_holder, $this_editor_info, $get_org_flag, $results_type) = @_;

  my $id = $this_editor_info->{id};
  my $desc = $this_editor_info->{desc};
  my $organism_field = "";

  # fasta score
  my $z_score = $this_editor_info->{z_score};

  # blast scores
  my $e_value = $this_editor_info->{e_value};
  my $n_value = $this_editor_info->{n_value};
  my $p_value = $this_editor_info->{p_value};
  my $score = $this_editor_info->{score};

  my $percent_id = $this_editor_info->{percent_id};
  my $overlap = $this_editor_info->{overlap};

  my $max_id_length = $info_holder->max_length ("id");
  my $max_desc_length = $info_holder->max_length ("desc");

  my $max_org_length = 30;

  if ($get_org_flag && $results_type !~ /\+go$/) {
    $organism_field = $this_editor_info->get_organism;

    if (!defined $organism_field) {
      $organism_field = "unknown";
    }
  }

  my $return_value;

  if ($results_type eq "fasta") {
    $return_value = (sprintf ("%-${max_id_length}s " .
                              "%-${max_desc_length}s " .
                              "%-${max_org_length}.${max_org_length}s" .
                              "  %8.8s  %5d  " .
                              "%5.1f", $id, $desc, $organism_field,
                              $e_value, $z_score,
                              $percent_id) .
                     '% id in ' .
            sprintf ("%-8.8s" , sprintf ("%d", $overlap) . 'aa'));
  } else {
    $return_value = sprintf ("%-${max_id_length}s " .
                             "%-${max_desc_length}s " .
                             "%-${max_org_length}.${max_org_length}s " .
                             (defined $e_value ? "%6.6s  " : "") .
                             (defined $n_value ? "%6.6s  " : "") .
                             (defined $p_value ? "%6.6s  " : "") .
                             (defined $score ? "%5d  " : "") .
                             (defined $percent_id ? "%5.1f%% id " : ""),
                             $id, $desc, $organism_field,
                             (defined $e_value ? $e_value : ()),
                             (defined $n_value ? $n_value : ()),
                             (defined $p_value ? $p_value : ()),
                             (defined $score ? $score : ()),
                             (defined $percent_id ? $percent_id : ()));
  }

#  print STDERR "make_entry_text(): $return_value\n";

  return $return_value;
}

sub find_protein_in_netscape
{
  my ($protein_id_or_acc) = shift;

  my $PROTEIN_DATABASES = get_protein_databases ();

  my $url = "http://$SRS_SERVER\[\{$PROTEIN_DATABASES\}-ID:$protein_id_or_acc*]|[\{$PROTEIN_DATABASES\}-AccNumber:$protein_id_or_acc*]";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub find_embl_entry_in_netscape
{
  my ($embl_id_or_acc) = shift;

  my $DNA_DATABASES = get_dna_databases ();

  my $url = "http://$SRS_SERVER\[\{$DNA_DATABASES\}-ID:$embl_id_or_acc*]|[\{$DNA_DATABASES\}-AccNumber:$embl_id_or_acc*]";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub find_interpro_entry_in_netscape
{
  my ($interpro_id) = shift;

  my $url = "http://www.ebi.ac.uk/interpro/IEntry?ac=$interpro_id";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub find_pfam_entry_in_netscape
{
  my ($id) = shift;

  my $url = "http://www.sanger.ac.uk/cgi-bin/Pfam/getacc?$id";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub find_prosite_entry_in_netscape
{
  my ($id) = shift;

  my $url = "http://www.expasy.ch/cgi-bin/prosite-search-ac?$id";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub find_pubmed_entry_in_netscape
{
  my ($id) = shift;

  $id =~ s/^PMID://;

  my $url = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&list_uids=$id&dopt=Abstract";

  system "$NETSCAPE", "-remote", "openURL($url)";
}

sub make_button_row ($$$$$$$)
{
  my ($parent, $fasta_t, $this_editor_info, $info_holder,
      $callback, $get_org_at_creation, $params) = @_;

  my ($callback_sub, @callback_args) = (@{$callback}, $params);

  my $results_type = $params->{results_type};

  my $row_f = $parent->Frame ();
  my $row_top_f = $row_f->Frame (-relief => "groove", -border => 2);

  $row_top_f->pack (-side => "top",
                    -expand => "y",
                    -fill => "x");

  my $row_bottom_f = undef;

  if (is_go ($params)) {
    $row_bottom_f = $row_f->Frame ();
    $row_bottom_f->pack (-side => "top",
                         -expand => "y",
                         -fill => "x",
                         -padx => 20);
  }

  # true when the orth button is pressed
  my $orth_flag_ref = $this_editor_info->{orth_flag_ref};
  # true when the para button is pressed
  my $para_flag_ref = $this_editor_info->{para_flag_ref};


  my $orth_b = $row_top_f->Checkbutton (-text => "ORTH",
                                        -variable => $orth_flag_ref,
                                        -font => $global_font,
                                        -border => 1,
                                        -relief => "raised",
                                        -padx => $button_xpad,
                                        -pady => $button_ypad);

  $orth_b->pack (-side => "left",
                 -padx => $button_pack_padx);
  $orth_b->configure (-cursor => $pointer_cursor);


  my $para_b = $row_top_f->Checkbutton (-text => "PARA",
                                        -variable => $para_flag_ref,
                                        -font => $global_font,
                                        -border => 1,
                                        -relief => "raised",
                                        -padx => $button_xpad,
                                        -pady => $button_ypad);

  $para_b->pack (-side => "left",
                 -padx => $button_pack_padx);
  $para_b->configure (-cursor => $pointer_cursor);


  my $para_command = sub {
    if (${$para_flag_ref} && ${$orth_flag_ref}) {
      ${$orth_flag_ref} = 0;
    }

    $callback_sub->($info_holder, @callback_args);
  };

  my $orth_command = sub {
    if (${$para_flag_ref} && ${$orth_flag_ref}) {
      ${$para_flag_ref} = 0;
    }

    # if any other orth_flag is set, disable it
    for my $other_info_ref ($info_holder->all_values ()) {
      if (${$other_info_ref->{orth_flag_ref}} &&
          $other_info_ref->{orth_flag_ref} != $orth_flag_ref) {
        ${$other_info_ref->{orth_flag_ref}} = 0;
      }
    }

    $callback_sub->($info_holder, @callback_args);
  };

  $para_b->configure (-command => $para_command);
  $orth_b->configure (-command => $orth_command);


  my $id = $this_editor_info->{id};

  my $text = make_entry_text $info_holder, $this_editor_info,
                             $get_org_at_creation, $results_type;

  my $id_desc_l = $row_top_f->Label (-textvariable => \$text,
                                     -font => $global_font,
                                     -relief => "flat",
                                     -width => length $text);

  my $delay = 10 + rand 100;

  my $id_desc_l_callback;

  if (!$get_org_at_creation) {
    $id_desc_l_callback =
      sub {
        if (!$parent->ismapped) {
          $parent->after ($delay, $id_desc_l_callback);
        } else {
          $text = make_entry_text ($info_holder, $this_editor_info, 1,
                                   $results_type);
          $id_desc_l->update ("idletasks");
        }
      };

    #  $id_desc_l->after ($delay, $id_desc_l_callback);

    $id_desc_l->bind ('<Button>' => $id_desc_l_callback);
  }

  $id_desc_l->pack (-side => "left",
                    -padx => $button_pack_padx);



  my $align_command = sub {
    my $start = ($fasta_t->tagRanges ($id))[0];

    $fasta_t->yview ($start);
  };

  my $align_b = $row_top_f->Button (-text => "ALIGN",
                                    -font => $global_font,
                                    -padx => $button_xpad,
                                    -pady => $button_ypad,
                                    -borderwidth => 1,
                                    -anchor => 'w',
                                    -command => $align_command);

  $align_b->pack (-side => "left",
                  -padx => $button_pack_padx);

  $align_b->configure (-cursor => $pointer_cursor);

  my $PROTEIN_DATABASES = get_protein_databases ();

  my $srs_command = sub {

    # special case for tremblnew entries - check tremblnew and if the entry
    # isn't there, get the entry from TREMBL via the dbxref
    if ($id =~ /[a-z][a-z][a-z]\d\d\d\d\d/i) {

      system "efetch trnew:$id > /dev/null 2> /dev/null";

      if ($?) {
        # it failed so try using dbxref
        my $url = "http://$SRS_SERVER\[\{$PROTEIN_DATABASES\}-dbxref:$id*]";

        system "$NETSCAPE", "-remote", "openURL($url)";

        return;
      }
    }

    find_protein_in_netscape ($id);
  };

  my $srs_b = $row_top_f->Button (-text => "->SRS",
                                  -font => $global_font,
                                  -padx => $button_xpad,
                                  -pady => $button_ypad,
                                  -borderwidth => 1,
                                  -anchor => 'w',
                                  -command => $srs_command);

  $srs_b->pack (-side => "left",
                -padx => $button_pack_padx);

  $srs_b->configure (-cursor => $pointer_cursor);


  # true when the select button is pressed
  my $selected_flag_ref = $this_editor_info->{selected_flag_ref};

  my $select_b = $row_top_f->Checkbutton (-text => "SELECT",
                                          -variable => $selected_flag_ref,
                                          -font => $global_font,
                                          -border => 1,
                                          -relief => "raised",
                                          -padx => $button_xpad,
                                          -pady => $button_ypad);

  # make a row of go buttons
  if (defined $row_bottom_f && is_go ($params)) {
    if ($id =~ /(\S+)/) {
      my $dbid = $1;

      my @go_ids = get_go_mapping ($dbid);

      # need to sort by ontology then by ID

      @go_ids =
        sort {
          my $a_go_id = $a->{go_id};
          my $b_go_id = $b->{go_id};

          my $a_ontology = get_go_ontology_name ($a_go_id);
          my $b_ontology = get_go_ontology_name ($b_go_id);

          $a_ontology cmp $b_ontology
            ||
          $a_go_id cmp $b_go_id;
        } @go_ids;

      for (my $i = 0 ; $i < @go_ids ; ++$i) {
        my $go_id_and_evidence_ref = $go_ids[$i];

        my $go_id = $go_id_and_evidence_ref->{go_id};
        my $evidence_code = $go_id_and_evidence_ref->{evidence_code};
        my $taxon_species = $go_id_and_evidence_ref->{taxon_species};

        my $wrapper_frame = $row_bottom_f->Frame ();

        $wrapper_frame->pack (-side => "top",
                              -expand => "y",
                              -fill => "x");

        my $go_netscape_command = sub {
          my $location =
            "www.godatabase.org/cgi-bin/go.cgi?query=$go_id";
          $location =~ s/:/\%3A/g;

          system "$NETSCAPE", "-remote", "openURL(http://$location)";
        };

        my $go_netscape_b =
          $wrapper_frame->Button (-text => "->GO",
                                  -font => $global_font,
                                  -border => 1,
                                  -relief => "raised",
                                  -padx => $button_xpad,
                                  -pady => $button_ypad,
                                  -anchor => "w",
                                  -cursor => $pointer_cursor,
                                  -command => $go_netscape_command);

        $go_netscape_b->pack (-side => "left",
                              -padx => $button_pack_padx);

        my $go_flag = 0;

        my $button = $wrapper_frame->Checkbutton (-text => $go_id,
                                                  -variable => \$go_flag,
                                                  -font => $global_font,
                                                  -border => 1,
                                                  -relief => "raised",
                                                  -padx => $button_xpad,
                                                  -pady => $button_ypad,
                                                  -anchor => "w");
        $button->configure (-cursor => $pointer_cursor);


        my $current_index = $i;

        my $go_callback_sub = sub {
          if ($go_flag) {
            if (! grep {
              $_ == $go_id_and_evidence_ref
            } @{$this_editor_info->{_selected_go_ids}}) {
              push @{$this_editor_info->{_selected_go_ids}},
                   $go_id_and_evidence_ref;

#                print STDERR $this_editor_info->{_selected_go_ids},"\n";
            }
          } else {
            @{$this_editor_info->{_selected_go_ids}} =
              grep {
                $_ != $go_id_and_evidence_ref
              } @{$this_editor_info->{_selected_go_ids}};

#            print STDERR $this_editor_info->{_selected_go_ids},"\n";
          }

          $callback_sub->($info_holder, @callback_args);
        };

        $button->configure (-command => $go_callback_sub);

        $button->pack (-side => "left");

        my $go_text = get_go_text ($go_id);

        my $label_text = " " . $evidence_code . " - " . $taxon_species .
           "  -  $go_text";

        my $label = $wrapper_frame->Label (-text => $label_text,
                                           -font => $global_font);

        $label->pack (-side => "left");
      }
    } else {
      warn "can't parse id from this line: $id\n";
    }
  }


  $select_b->pack (-side => "left",
                   -padx => $button_pack_padx);


  $select_b->configure (-cursor => $pointer_cursor);


#    my $more_l = $row_top_f->Label (-text => "");

#    my $more_command = sub { $more_l->configure (-text => "foo") };

#    my $more_b = $row_top_f->Button (-text => "MORE ...",
#                                 -font => $global_font,
#                                 -padx => $button_xpad,
#                                 -pady => $button_ypad,
#                                 -borderwidth => 1,
#                                 -anchor => 'w',
#                                 -command => $more_command);

#    $more_b->pack (-side => "left");


#    $more_l->pack (-side => "left");


  return $row_f;
}

sub insert_qualifiers
{
  my ($qualifier_t, $qualifier_string) = @_;

  $qualifier_t->configure (-state => "normal");
  $qualifier_t->configure (-cursor => "top_left_arrow");

  $qualifier_t->delete ('1.0', 'end');

  my $go_re = 'GO:\d+';
  my $swall_re = q{(?:\b(?:SW|TR|SWALL):\S+\b)};
  my $embl_re = q{(?:\bEMBL:\s?\S+\b)};
  my $interpro_re = q{(?:\bIPR\d\d\d\d\d\d\b)};
  my $pfam_re = q{(?:\bPF\d\d\d\d\d\b)};
  my $prosite_re = q{(?:\bPS\d\d\d\d\d\b)};
  my $pubmed_re = q{(?:\bPMID:\d\d\d\d\d+\b)};

  # split the string and then hyperlink
  my @qualifier_bits =
    split (/($go_re|$swall_re|$embl_re|$interpro_re|$pfam_re|$prosite_re|$pubmed_re)/,
           $qualifier_string);

  for my $bit (@qualifier_bits) {
    my $callback;
    my $tag_name;

    if ($bit =~ /^$go_re/) {
      $tag_name = "go_link_$bit";

      $callback = sub {
        my ($start_pos, $end_pos) =
        $qualifier_t->tagNextrange ($tag_name, '1.0');
        my $go_id = $qualifier_t->get ($start_pos, $end_pos);

        my $location = "www.godatabase.org/cgi-bin/go.cgi?query=$go_id";
        $location =~ s/:/\%3A/g;

        system "$NETSCAPE", "-remote", "openURL(http://$location)";
      }
    } else {
      if ($bit =~ /^$swall_re/) {
        $tag_name = "sw_link_$bit";

        $callback = sub {
          my ($start_pos, $end_pos) =
          $qualifier_t->tagNextrange ($tag_name, '1.0');
          my $protein_id_or_acc = $qualifier_t->get ($start_pos, $end_pos);

          $protein_id_or_acc =~ s/(SW|TR|SWALL)://;

          find_protein_in_netscape ($protein_id_or_acc);
        }
      } else {
        if ($bit =~ /^$embl_re/) {
          $tag_name = "embl_link_$bit";

          $callback = sub {
            my ($start_pos, $end_pos) =
            $qualifier_t->tagNextrange ($tag_name, '1.0');
            my $dna_id_or_acc = $qualifier_t->get ($start_pos, $end_pos);

            $dna_id_or_acc =~ s/EMBL:\s*//;

            find_embl_entry_in_netscape ($dna_id_or_acc);
          }
        } else {
          if ($bit =~ /^$interpro_re/) {
            $tag_name = "interpro_link_$bit";

            $callback = sub {
              my ($start_pos, $end_pos) =
              $qualifier_t->tagNextrange ($tag_name, '1.0');
              my $id = $qualifier_t->get ($start_pos, $end_pos);

              find_interpro_entry_in_netscape ($id);
            }
          } else {
            if ($bit =~ /^$pfam_re/) {
              $tag_name = "pfam_link_$bit";

              $callback = sub {
                my ($start_pos, $end_pos) =
                $qualifier_t->tagNextrange ($tag_name, '1.0');
                my $id = $qualifier_t->get ($start_pos, $end_pos);

                find_pfam_entry_in_netscape ($id);
              }
            } else {
              if ($bit =~ /^$prosite_re/) {
                $tag_name = "prosite_link_$bit";

                $callback = sub {
                  my ($start_pos, $end_pos) =
                  $qualifier_t->tagNextrange ($tag_name, '1.0');
                  my $id = $qualifier_t->get ($start_pos, $end_pos);

                  find_prosite_entry_in_netscape ($id);
                }
              } else {
                if ($bit =~ /^$pubmed_re/) {
                  $tag_name = "pubmed_link_$bit";

                  $callback = sub {
                    my ($start_pos, $end_pos) =
                    $qualifier_t->tagNextrange ($tag_name, '1.0');
                    my $id = $qualifier_t->get ($start_pos, $end_pos);

                    find_pubmed_entry_in_netscape ($id);
                  }
                } else {
                  $qualifier_t->insert ('end', $bit);
                  next;
                }
              }
            }
          }
        }
      }
    }

    my $i = 0;

    my $cursor_enter = sub {
      $qualifier_t->configure (-cursor => "hand2");
    };

    my $cursor_leave = sub {
      $qualifier_t->configure (-cursor => "top_left_arrow");
    };

    $qualifier_t->tagConfigure ($tag_name, -underline => 1,
                                -foreground => 'blue');
    $qualifier_t->tagBind ($tag_name, "<Button-1>", $callback);
    $qualifier_t->tagBind ($tag_name, "<Enter>", $cursor_enter);
    $qualifier_t->tagBind ($tag_name, "<Leave>", $cursor_leave);

    $qualifier_t->insert ('end', $bit, $tag_name);
  }

  if (1 || (!($ENV{DISPLAY} eq "darth:0.0" || $ENV{DISPLAY} eq "maul:0.0"))) {
    $qualifier_t->configure (-state => "disabled");
  }
}

sub update_qualifier_t ($$$$)
{
  my ($info_holder, $qualifier_t, $orig_qualifier_string, $params) = @_;

  my $new_qualifiers_string =
    get_new_qualifiers ($orig_qualifier_string, $info_holder, $params);

  insert_qualifiers ($qualifier_t, $new_qualifiers_string);
};

sub get_id_and_acc ($)
{
  my ($info_ref) = @_;

  my $id = $info_ref->{id};

  if ($id =~ /_/) {
    # swissprot id
    return "SWALL:$id (SWALL:" . $info_ref->get_acc_number () . ")";
  } else {
    # trembl id
    return "SWALL:$id (EMBL:" . $info_ref->get_embl_acc_number () . ")";
  }
}

sub get_orth_ref (@)
{
  my ($info_holder) = @_;

  for my $info_ref ($info_holder->all_values) {
    if (${$info_ref->{orth_flag_ref}}) {
      return $info_ref;
    }
  }

  return undef;
}

sub get_para_refs (@)
{
  my ($info_holder) = @_;

  grep {
    if (${$_->{para_flag_ref}}) {
      1;
    } else {
      0;
    }
  } ($info_holder->all_values);
}

sub qualifier_maker_sub ($$)
{
  my ($info_holder, $params) = @_;

  my $results_type = $params->{results_type};

  my $orth_ref = get_orth_ref ($info_holder);

  my $new_qualifiers = "";

  my @selected_info_refs;

  if (defined $orth_ref) {
    push @selected_info_refs, $orth_ref;
  }

  push @selected_info_refs, get_para_refs ($info_holder);

  if (@selected_info_refs) {
    if (!$params->{eukaryotic_mode}) {
      my @selected_info_refs_copy = @selected_info_refs;

      my $note_value =
        "Similar to " . make_prok_note (shift @selected_info_refs_copy,
                                        $params);

      for my $info_ref (@selected_info_refs_copy) {
        $note_value .= ", and to " . make_prok_note ($info_ref, $params);
      }

      $new_qualifiers .= qq|/note="$note_value"\n|;
    }

    for my $info_ref (@selected_info_refs) {
      my $similarity_value = make_euk_similarity ($info_ref, $params);

      if (defined $similarity_value) {
        $new_qualifiers .= qq|/similarity="$similarity_value"\n|;
      }
    }

    if (defined $orth_ref) {
      my $orth_id = $orth_ref->{id};

      my $orth_product = $orth_ref->get_product ();
      my $orth_ecnumber = $orth_ref->get_ecnumber ();
      my $orth_gene_name = $orth_ref->get_gene_name ();

      if (defined $orth_product) {
        $new_qualifiers .= qq|/product="$orth_product"\n|;
      }
      if (defined $orth_ecnumber) {
        $new_qualifiers .= qq|/EC_number="$orth_ecnumber"\n|;
      }
      if (defined $orth_gene_name) {
        $new_qualifiers .= qq|/gene="$orth_gene_name"\n|;
      }
    }
  }
  return $new_qualifiers;
}

sub get_blastp_go_note ($$$)
{
  my ($info_ref, $id, $id_and_acc) = @_;

  my $gene_string = $info_ref->get_gene_name ();

  if (defined $gene_string) {
    $gene_string .= " ";
  } else {
    $gene_string = "";
  }

  return $info_ref->get_organism () . " " . $info_ref->get_product () .
    " $gene_string" .
    $id . " blast scores: E(): " . $info_ref->{e_value} .
    ", score: " . $info_ref->{score} . "  " .
    $info_ref->{percent_id} . "% id";
}

sub make_euk_similarity ($$)
{
  my ($info_ref, $params) = @_;

  my $results_type = $params->{results_type};

  my $id = $info_ref->{id};

  my $id_and_acc = get_id_and_acc ($info_ref);

#  print STDERR "$id_and_acc\n";

  my $gene_string = $info_ref->get_gene_name ();

  if (defined $gene_string) {
    $gene_string .= "";
  } else {
    $gene_string = "";
  }

  if (is_go ($params)) {
    return get_blastp_go_note ($info_ref, $id, $id_and_acc);
  }

  return ("$results_type; " .
          $id_and_acc . "; " .
          (defined $info_ref->get_organism () ?
           $info_ref->get_organism () :
           "") . "; " .
          (defined $info_ref->get_product () ?
           $info_ref->get_product () :
           "") . "; " .
          (defined $gene_string ?
           $gene_string :
           "") . "; " .
          (defined $info_ref->{hit_length} ?
           "length " . $info_ref->{hit_length} . " aa" :
           "" ) . "; " .
          (defined $info_ref->{percent_id} ?
           "id=" . $info_ref->{percent_id} . "%" :
           "") . "; " .
          (defined $info_ref->{ungapped_percent_id} ?
           "ungapped id=" . $info_ref->{ungapped_percent_id} . "%" :
           "") . "; " .
          (defined $info_ref->{e_value} ?
           "E()=" . $info_ref->{e_value} :
           "" ) . "; " .
          (defined $info_ref->{score} ?
           "score=" . $info_ref->{score} :
           "") . "; " .
          (defined $info_ref->{overlap} ?
           $info_ref->{overlap} . " aa overlap" :
           "") . "; " .
          (defined $info_ref->{query_start_pos} &&
           defined $info_ref->{query_end_pos} ?
           "query " . $info_ref->{query_start_pos} . "-" .
           $info_ref->{query_end_pos} . " aa" :
           "") . "; " .
          (defined $info_ref->{subject_start_pos} &&
           defined $info_ref->{subject_end_pos} ?
           "subject " . $info_ref->{subject_start_pos} . "-" .
           $info_ref->{subject_end_pos} . " aa" :
           ""));
}

sub make_prok_note ($$)
{
  my ($info_ref, $params) = @_;

  my $results_type = $params->{results_type};

  my $id = $info_ref->{id};

  my $id_and_acc = get_id_and_acc ($info_ref);

  my $gene_string = $info_ref->get_gene_name ();

  if (defined $gene_string) {
    $gene_string .= " ";
  } else {
    $gene_string = "";
  }

  if (is_go ($params)) {
    return get_blastp_go_note ($info_ref, $id, $id_and_acc);
  }

  if ($0 =~ /leish_qualifier_editor/) {
    return ($info_ref->get_organism () . " " . $info_ref->get_product () .
            " $gene_string" .
            $id_and_acc . " (" . $info_ref->{hit_length} .
            " aa) fasta scores: E(): " . $info_ref->{e_value} . ", " .
            $info_ref->{percent_id} . "% id in " .
            $info_ref->{overlap} . " aa");
  } else {
    if ($results_type eq "fasta") {
      return ($info_ref->get_organism () . " " . $info_ref->get_product () .
              " $gene_string" .
              $id_and_acc . " (" . $info_ref->{hit_length} .
              " aa) fasta scores: E(): " . $info_ref->{e_value} . ", " .
              $info_ref->{percent_id} . "% id in " .
              $info_ref->{overlap} . " aa");
    } else {
      return ($info_ref->get_organism () . " " . $info_ref->get_product () .
              " $gene_string" .
              $id_and_acc . " blast scores: E(): " . $info_ref->{e_value} .
              ", score: " . $info_ref->{score} . "  " .
              $info_ref->{percent_id} . "% id");
    }
  }
}

# Create and return a new top level window for the QualifierEditor application.
#
# $base_directory - The directory where the fasta/blast result are to be found
# $orig_qualifier_string - A string containing all the qualifiers and values
# $ok_callback - The subroutine to call when the user hits OK
# $cancel_callback - The subroutine to call when the user hits Cancel
# $param->{results_type} - The type of the results to display, eg. "fasta"
#                 This value is used to choose which qualifier to get the
#                 results file from (ie. /fasta_file, /blastp_file etc.) and
#                 to decide how to parse the file.  make_fasta_text() is called
#                 for "fasta", make_blast_text() is called for "blast" and
#                 "blastp".
sub create_app ($$$$$$)
{
  my ($base_directory, $orig_qualifier_string,
      $ok_callback, $cancel_callback, $jalview_callback,
      $params) = @_;

  my $results_type = $params->{results_type};
  my $max_hits = $params->{max_hits};

  my $top;

  if (0 && ($ENV{DISPLAY} eq "alsdec:0.0" || $ENV{DISPLAY} eq "maul:0.0")) {
    $top = MainWindow->new (-colormap => 'new');

    print STDERR "$ENV{DISPLAY}\n";
  } else {
    $top = MainWindow->new ();
  }

  $top->geometry ("1150x800");
  $top->wm ("minsize", 600, 300);
  $top->title ("MESS - $results_type");

  my $top_frame = $top->Frame ();

  my $qualifier_t = $top_frame->Scrolled ("Text",
                                          -font => $global_font,
                                          -scrollbars => 'ose',
                                          -background => 'white',
                                          -height => $text_height,
                                          -width => 90);

  $qualifier_t->pack (-side => "left", -expand => "y", -fill => "both");

  insert_qualifiers ($qualifier_t, $orig_qualifier_string);

  my @results_file_text =
    get_results_file ($top,
                      $base_directory, $orig_qualifier_string,
                      $results_type . "_file");

  my $scrolled_button_text = $top->Scrolled ("Text",
                                             -height => $fasta_button_t_height,
                                             -scrollbars => 'ose');

  $scrolled_button_text->packAdjust (-side => "top",
                                     -expand => 0,
                                     -fill => "both");

  $top_frame->pack (-side => "top", -expand => "y", -fill => "both");

  my $results_text_widget;
  my $info_holder;


  if ($results_type eq "fasta") {
    ($results_text_widget, $info_holder) =
      make_fasta_text ($top_frame, @results_file_text);
  } else {
    ($results_text_widget, $info_holder) =
      make_blastp_text ($top_frame, @results_file_text);
  }

  $results_text_widget->configure (-cursor => "top_left_arrow");

  my @editor_info_refs = $info_holder->all_values ();

  # make a row of buttons and label that describe each hit

  my $useful_hit_count = 0;

  for (my $i = 0;
       $i < @editor_info_refs && $useful_hit_count < $max_hits;
       ++$i) {
    my $this_editor_info = $editor_info_refs[$i];

    if (is_go ($params)) {
      my $id = $this_editor_info->{"id"};

      if ($id =~ /(\S+)/) {
        my $dbid = $1;

        my @go_ids = get_go_mapping ($dbid);

        my $found_non_iea = 0;

        for my $go_info (@go_ids) {
          my $evidence_code = $go_info->{evidence_code};

          if ($evidence_code ne "IEA") {
            $found_non_iea++;
          }
        }

        if ($found_non_iea) {
          $useful_hit_count++;
        }
      } else {
        warn "no description for hit\n";
      }
    } else {
      $useful_hit_count++;
    }

    my $new_row = make_button_row ($scrolled_button_text,
                                   $results_text_widget,
                                   $this_editor_info,
                                   $info_holder,
                                   [\&update_qualifier_t,
                                    $qualifier_t,
                                    $orig_qualifier_string],
                                   1,
                                   $params);

    $scrolled_button_text->windowCreate ('end', -window => $new_row);
    $scrolled_button_text->insert ('end', "\n");

    $top->update ("idletasks");
  }

  $scrolled_button_text->configure (-state => "disabled");

  my $first_alignment_tag = $editor_info_refs[0]->{id};

  my $start = $results_text_widget->tagRanges ($first_alignment_tag);

  if (defined $start) {
    $results_text_widget->see ($start);
  } else {
    # fasta file contained no hits
  }

  my $button_f = $top->Frame (-border => 2);

  my $real_ok_callback = sub {
    my ($info_holder) = @_;

    my $new_qualifiers_string =
      get_new_qualifiers ($orig_qualifier_string, $info_holder, $params);

    $ok_callback->($new_qualifiers_string);
  };

  my $ok_b = $button_f->Button (-text => "OK",
                                -font => $global_font,
                                -command => [$real_ok_callback,
                                             $info_holder]);

  my $cancel_b = $button_f->Button (-text => "Cancel",
                                    -font => $global_font,
                                    -command => $cancel_callback);

  my $jalview_b = $button_f->Button (-text => "Jalview",
                                     -font => $global_font,
                                     -command => [$jalview_callback,
                                                  $info_holder]);

  $jalview_b->pack (-side => "left", -padx => 10, -pady => 3);
  $ok_b->pack (-side => "left", -padx => 10, -pady => 3);
  $cancel_b->pack (-side => "left", -padx => 10, -pady => 3);

  $button_f->pack (-side => "top");

  $top->deiconify ();
  $top->raise ();

  return $top;
}
