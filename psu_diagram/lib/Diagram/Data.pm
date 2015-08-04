=head1 NAME

Diagram::Data

=head1 SYNOPSIS

Storage for one group of input data used to draw a diagram.

=head1 AUTHOR

Kim Rutherford (kmr@sanger.ac.uk)

=cut

package Diagram::Data;

use Bio::PSU::SeqFactory;
use Bio::PSU::IO::BufferFH;

use strict;
use Carp;
use POSIX;

=head2 new

 Title   : new
 Usage   : $data = Diagram::Data->new ($baseline, $data)
 Function: Create a new Data object
 Returns : A new Data object
 Args    : $baseline is an integer the specifies how far from the centre the
           baseline of the feature will be drawn.  0 is the centre of the
           diagram, 100 is the outside edge.  $data should be a
           reference to an array which contains Bio::PSU::Feature
           objects.  Each Feature should have a height qualifier,
           which gives the distance from base line / height of feature
           messured in the same units as the $baseline argument.
           negative values will cause the feature to from the baseline
           towards the centre (rather than away from the centre)
=cut

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($baseline, $features_ref) = @_;

  my $self  = {
               baseline => $baseline,
               features => $features_ref
              };

  return bless $self, $class;
}

sub baseline ($)
{
  return shift->{baseline};
}



sub features ($)
{
  return @{shift->{features}};
}


=head2 read_data_file

 Title   : read_data_file
 Usage   : $data = Diagram::Data->read_data_file ($file_name)
 Function: Reads a Data object from a file.  The format of the features is much
           simpler than an EMBL feature table:

The data files must start with a line like:
  baseline 50
the number is the distance from the centre (with 100 being the maximum)

Each line after that should be a comment (starting with #) or a data
line with either 3 or 6 columns:

column 1:    start coordinate (between 1 and the value of the -divisions
             option)
column 2:    end coordinate (between 1 and the value of the -divisions option)
column 3:    distance from base line / height of feature messured in the same
             units as the baseline position.  negative values will cause the
             feature to from the baseline towards the centre (rather than
             away from the centre)
columns 4-6: the red, green and blue values to use as the feature colour.  the
             values should be <= 1 and >= 0.  if the colour is omitted, black
             is used.


 Returns :
 Args    :

=cut

sub read_data_file
{
#   my $self = shift;

#   my ($buffer_fh, $baseline, $max_height) = @_;
my ($file_name,$baseline,$max_height)=@_;
# my $buffer_fh = Bio::PSU::IO::BufferFH->new(-file => $file_name);
  my @features = ();
# print "Filename:$file_name\tBaseline=$baseline\tMax_height=$max_height\n";
  my $line;
# print "Reading tab delimited file\n";
	open (TAB,$file_name) || die ("cannot open file $file_name\n");
#   while (defined ($line = $buffer_fh->buffered_read )) {
	while ($line=<TAB>){
	chomp $line;
    $line =~ s/#.*//;

    if ($line =~ m/^\s*$/) {
      next;
    }

    my @line_bits = split("\t",$line);
    if (scalar(@line_bits) == 3 || scalar(@line_bits) == 6) {
      my ($start, $end, $height, $red, $green, $blue) = @line_bits;

      my $feature = new Bio::PSU::Feature (-start => $start,
					   -end   => $end);

      $feature->qadd (height => $height / $max_height);

      if (defined $red) {
        if (defined $blue && defined $green) {
          my $colour = sprintf "%.4f %.4f %.4f", $red, $green, $blue;
          $feature->qadd (colour => $colour);
        } else {
          warn "not enough fields in this line: $line";
        }
      }

      push @features, $feature;
    } else {
      warn "can't understand this line: $line\n";
    }
  }
  return new Diagram::Data ($baseline, \@features);
}

# make a Data object from a file
sub read_file
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($file_name, $baseline, $max_height, $forward_only) = @_;

  my $buffer_fh = Bio::PSU::IO::BufferFH->new(-file => $file_name);
# print "Opening file $file_name\n";
  if (!defined $buffer_fh) {
    die "couldn't open $file_name for reading\n";
  }

  # these will be put back after we know what the file type is
  my @save_lines = ();

  my $line;
  while (defined ($line = $buffer_fh->buffered_read)) {
    push @save_lines, $line;
    if ($line =~ /^\#/ || $line =~ /|^baseline/ || $line=~/^\d/) {
      # probably a simple data file
      @{$buffer_fh->{buffer}} = @save_lines;
# print "probably simple data file\n";
      return read_data_file ($file_name, $baseline, $max_height);
# 	return read_data_file($file_name,$baseline,$max_height);
    } 
# 	else {
#       if ($line =~ /^\s*$/) {
#         # ignore empty lines
#       } else {
#         # probably a tab file
#         @{$buffer_fh->{buffer}} = @save_lines;
# print "probably EMBL data file\n";
#         return read_tab_file ($buffer_fh, $baseline, $max_height, 
#                               $forward_only);
#       }
#     }
  }
}

sub make_gc_data
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($seq, $deviation_flag,
      $baseline, $max_height, $window_size, $window_step) = @_;

  my %all_composition = ('a' => 0, 'c' => 0, 'g' => 0, 't' => 0);

  my $seq_string = lc $seq->str ();

  $seq_string = lc $seq_string;

  my @chunk_composition = ();

  my $base_count = 0;

  while ($seq_string =~ /(.)/g) {
    $all_composition{$1}++;
    $chunk_composition[$base_count / $window_step]{$1}++;
#    print STDERR "$base_count / $window_step  $1 ", $base_count / $window_step, "  ", $chunk_composition[int ($base_count / $window_step)]{$1}, "\n";
    $base_count++;
  }

#  print STDERR $chunk_composition[0]{'a'}, "\n";

  my $seq_gc_content = ($all_composition{'g'} +
                        $all_composition{'c'}) / $seq->length;

#  print STDERR "$all_composition{'g'} $all_composition{'c'} $all_composition{'a'} $all_composition{'t'}\n";

  my @new_features = ();

  my $max_abs_value = -1;

  my $chunks_per_window = int (ceil ($window_size / $window_step));

  my $chunk_count = scalar (@chunk_composition);

  # make it circular
  push @chunk_composition, @chunk_composition[0..($chunks_per_window - 2)];

  # print STDERR "$seq_gc_content ", $chunk_count, " ", scalar (@chunk_composition), " $chunks_per_window \n";

  for (my $i = 0 ; $i < $chunk_count ; ++$i) {
    my $c_count = 0;
    my $g_count = 0;

    for (my $chunk_index = 0; $chunk_index < $chunks_per_window;
         ++$chunk_index) {
#      print STDERR "$i \$chunk_index: $chunk_index   ";

      if (exists $chunk_composition[$i + $chunk_index]->{c}) {
        $c_count += $chunk_composition[$i + $chunk_index]->{c};
#        print STDERR "\$c_count   $c_count ";
      }
      if (exists $chunk_composition[$i + $chunk_index]->{g}) {
        $g_count += $chunk_composition[$i + $chunk_index]->{g};
#        print STDERR "\$g_count   $g_count ";
      }
#      print STDERR "\n";
    }

    my $gc_content = ($g_count + $c_count) / $window_size;

    my $start_pos = $i * $window_step + 1;
    my $end_pos = $i * $window_step + $window_step;

#    print STDERR "$start_pos $end_pos\n";

#    if ($i % 100 == 0 || $i % 100 == 1) {
#      print STDERR "$i $c_count $g_count $start_pos $end_pos\n";
#    }

    my $feature = new Bio::PSU::Feature (-start => $start_pos,
					 -end   => $end_pos);

    my $new_value;

    if ($deviation_flag) {
      if ($c_count + $g_count > 0) {
        $new_value = ($g_count - $c_count) / ($g_count + $c_count);

        my $colour;

        if ($new_value < 0) {
          $colour = "0.7 0.1 0.7";
        } else {
          $colour = "0.7 0.7 0.1";
        }

        $feature->qadd (colour => $colour);
      } else {
        $new_value = 0;
      }
    } else {
      $new_value = $gc_content - $seq_gc_content;
    }

    if (abs $new_value > $max_abs_value) {
      $max_abs_value = abs $new_value;
    }

#    print STDERR "\$gc_content = ($g_count + $c_count) / $window_size;\t$new_value $gc_content $seq_gc_content\n";

    $feature->qadd (height => $new_value);

    push @new_features, $feature;
  }

  # scale the heights
  for my $feature (@new_features) {
    my ($current_height) = $feature->height ();
    $feature->qremove ("height");

    my $new_value = $current_height / $max_abs_value * $max_height;

    $feature->qadd (height => $new_value);

#    print STDERR "$current_height $max_abs_value $new_value\n";
  }

  return Diagram::Data->new ($baseline, \@new_features);
}


1;

