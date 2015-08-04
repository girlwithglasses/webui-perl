#!/usr/local/bin/perl -w

use strict;

use vars qw(@ISA @EXPORT);
use Math::Complex;
use Carp;

use Bio::PSU::Feature;
use Diagram::Data;
use Pathogens::Artemis;

use Exporter;

@ISA = qw (Exporter);

@EXPORT = qw (draw_picture);

sub get_feature_rgbcolour ($)
{
  my $feature = shift;

  my $colour = "0 0 0";

  if ($feature->qvalues ("colour")) {
    $colour = ($feature->qvalues ("colour"))[0];

    if ($colour =~ /^\s*(\d+)\s*$/) {
      # an Artemis colour number
      $colour = get_colour_from_number ($colour);
    }
  }

  return $colour;
}

sub get_feature_height ($)
{
  my $feature = shift;

  my $height = ($feature->qvalues ("height"))[0];

  if (defined $height) {
    return $height;
  } else {
    confess "feature has no height qualifier\n";
  }
}

sub get_feature_info ($$)
{
  my ($feature, $options) = @_;

  my $start_coord = $feature->start - 1.0;
  my $end_coord = $feature->end;

  my $feature_length = $end_coord - $start_coord;

  my $minimum_feature_width = $options->{minimum_feature_width};

  if ($feature_length < $minimum_feature_width) {
    my $feature_centre = ($start_coord + $end_coord) / 2;

    $start_coord = $feature_centre - $minimum_feature_width / 2;
    $end_coord   = $feature_centre + $minimum_feature_width / 2;
  }

  my $height = get_feature_height ($feature);
  my $colour = get_feature_rgbcolour ($feature);

  return ($start_coord, $end_coord, $height, $colour);
}

sub draw_rect_box ($$$$;$)
{
  my ($fh, $options, $baseline, $feature, $border_only) = @_;

  my ($start_coord, $end_coord, $height, $colour) =
    get_feature_info ($feature, $options);

  # the number of bases in the input sequence
  my $divisions = $options->{divisions};

  # the amount of gap to leave at the end of the sequence (ie. after the last
  # base)
  my $end_gap = $options->{end_gap};

  # the effective total number of bases
  my $screen_divisions = $divisions + $end_gap;


  my $half_end_gap = $end_gap / 2.0;

  my $sin_val_start = sin(($start_coord +
                           $half_end_gap)/$screen_divisions*pi*2);
  my $cos_val_start = cos(($start_coord +
                           $half_end_gap)/$screen_divisions*pi*2);

  my $sin_val_end = sin(($end_coord +
                         $half_end_gap)/$screen_divisions*pi*2);
  my $cos_val_end = cos(($end_coord +
                         $half_end_gap)/$screen_divisions*pi*2);

  if (!$options->{clockwise}) {
    $sin_val_end = -$sin_val_end;
    $sin_val_start = -$sin_val_start;
  }

  my $point_1_x = $sin_val_start * $baseline;
  my $point_1_y = $cos_val_start * $baseline;

  my $point_2_x = $sin_val_start * ($baseline + $height);
  my $point_2_y = $cos_val_start * ($baseline + $height);

  my $point_3_x = $sin_val_end * ($baseline + $height);
  my $point_3_y = $cos_val_end * ($baseline + $height);

  my $point_4_x = $sin_val_end * $baseline;
  my $point_4_y = $cos_val_end * $baseline;

#  print STDERR "$x_start - $y_start - $start_coord - $end_coord - $direction - $height\n";

  my $line_width = "";

  my $draw_string;

  if (defined $border_only && $border_only) {
    $draw_string = "stroke";
    $colour = "0 0 0";
  } else {
    $draw_string = "fill";
  }

  print $fh <<EOF;
gsave
$colour setrgbcolor
$line_width
newpath
EOF

  printf $fh "%.3f %.3f M\n", $point_1_x, $point_1_y;
  printf $fh "%.3f %.3f L\n", $point_2_x, $point_2_y;
  printf $fh "%.3f %.3f L\n", $point_3_x, $point_3_y;
  printf $fh "%.3f %.3f L\n", $point_4_x, $point_4_y;

  print $fh <<EOF;
closepath
$draw_string
grestore
EOF
}

sub draw_arc_box ($$$$;$)
{
  my ($fh, $options, $baseline, $feature, $border_only) = @_;

  my ($start_coord, $end_coord, $height, $colour) =
    get_feature_info ($feature, $options);

  # the number of bases in the input sequence
  my $divisions = $options->{divisions};

  # the amount of gap to leave at the end of the sequence (ie. after the last
  # base)
  my $end_gap = $options->{end_gap};

  # the effective total number of bases
  my $screen_divisions = $divisions + $end_gap;

  my $half_end_gap = $end_gap / 2.0;

  my $start_angle;
  my $end_angle;

  if ($options->{clockwise}) {
    $start_angle = 90 - (($start_coord +
                          $half_end_gap) / $screen_divisions * 360);
    $end_angle = 90 - (($end_coord +
                        $half_end_gap)/ $screen_divisions * 360);
  } else {
    $start_angle = (($end_coord +
                     $half_end_gap) / $screen_divisions * 360) + 90;
    $end_angle = (($start_coord +
                  $half_end_gap)/ $screen_divisions * 360) + 90;
  }

  my $radius = $baseline;
  my $outer_radius = $baseline + $height;

  my $line_width = "";

  my $draw_string;

  if (defined $border_only && $border_only) {
    $draw_string = "stroke";
    $colour = "0 0 0";
    $line_width = "0.20 setlinewidth"
  } else {
    $draw_string = "fill";
  }

  print $fh <<EOF;
gsave
$colour setrgbcolor
$line_width
newpath
EOF

  printf $fh "0 0 %.3f %.3f %.3f arc\n",
     $radius, $end_angle, $start_angle;
  printf $fh "0 0 %.3f %.3f %.3f arcn\n",
     $outer_radius, $start_angle, $end_angle;

  print $fh <<EOF;
closepath
$draw_string
grestore
EOF
}

sub draw_feature ($$$$)
{
  my ($fh, $options, $baseline, $feature) = @_;

  my $start_coord = $feature->start;
  my $end_coord = $feature->end;

  # the number of bases in the input sequence
  my $divisions = $options->{divisions};

  # the amount of gap to leave at the end of the sequence (ie. after the last
  # base)
  my $end_gap = $options->{end_gap};

  # the effective total number of bases
  my $screen_divisions = $divisions + $end_gap;

  my $angular_width = ($end_coord - $start_coord) / $screen_divisions * 360;

  if ($angular_width > 1) {
    draw_arc_box $fh, $options, $baseline, $feature;
  } else {
    draw_rect_box $fh, $options, $baseline, $feature;
  }

  my $colour = get_feature_rgbcolour ($feature);

  if ($colour =~ /([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)/) {
    if ($1 > 0.99 && $2 > 0.99 && $3 > 0.99) {
      # now draw a border
      if ($angular_width > 1) {
        draw_arc_box $fh, $options, $baseline, $feature, 1;
      } else {
        draw_rect_box $fh, $options, $baseline, $feature, 1;
      }
    }
  }
}

sub draw_data ($$$)
{
  my ($fh, $options, $data) = @_;

  for my $feature ($data->features) {
    draw_feature $fh, $options, $data->baseline, $feature;
  }
}

sub draw_scale ($$)
{
  my ($fh, $options) = @_;


  my $scale_mark_separation = $options->{scale_mark_separation};
  my $scale_label_separation = $options->{scale_label_separation};
  my $scale_mark_height = $options->{scale_mark_height};
  my $scale_mark_width = $options->{scale_mark_width};
  my $scale_font_size = $options->{scale_font_size};

  # the number of bases in the input sequence
  my $divisions = $options->{divisions};

  # the amount of gap to leave at the end of the sequence (ie. after the last
  # base)
  my $end_gap = $options->{end_gap};

  my $half_end_gap = $end_gap / 2.0;

  # the effective total number of bases
  my $screen_divisions = $divisions + $end_gap;

  if ($scale_mark_separation > 0) {
    for (my $i = 1 ; $i <= $divisions ; $i += $scale_mark_separation) {
      my $start = $i;
      my $end = $i + $scale_mark_width;

      my $feature = new Bio::PSU::Feature (-start => $start, -end => $end);
      $feature->qadd (height => $scale_mark_height);
      $feature->qadd (colour => "0 0 0");

      draw_feature $fh, $options, 100, $feature;
    }
  }

  if ($scale_label_separation > 0) {
    for (my $i = 1 ; $i <= $divisions ; $i += $scale_label_separation) {
      my $coord = $i;

      my $sin_value;
      my $cos_value;

      if ($options->{clockwise}) {
        $sin_value = sin(($coord - 1 + $half_end_gap)/$screen_divisions*pi*2);
        $cos_value = cos(($coord - 1 + $half_end_gap)/$screen_divisions*pi*2);
      } else {
        $sin_value = cos(($coord - 1 + $half_end_gap)/$screen_divisions*pi*2 +
                     pi / 2);
        $cos_value = sin(($coord - 1 + $half_end_gap)/$screen_divisions*pi*2 +
                     pi / 2);
      }

      my $label_distance = $options->{label_distance};

      my $label_x_val;
      my $label_y_val;

      $label_x_val = sprintf "%.3f", $sin_value * (100 + $label_distance);
      $label_y_val = sprintf "%.3f", $cos_value * (100 + $label_distance);

      print $fh <<EOF;
gsave
/Helvetica findfont $scale_font_size scalefont setfont

$label_x_val $label_y_val translate

gsave
newpath
0 0 moveto
($coord) false charpath % flattenpath
pathbbox
grestore

neg 2 div exch neg 2 div exch

moveto
pop pop
($coord)
show
grestore
EOF
    }
  }

  my $start_angle = 360.0 * $half_end_gap/$screen_divisions + 90;
  my $end_angle = 360.0 * ($divisions + $half_end_gap)/$screen_divisions + 90;

  print $fh <<EOF;
newpath 0 0 100 $start_angle $end_angle arc stroke
EOF
}

sub draw_picture
{
  my ($fh, $options, @data) = @_;

  my $page_width = $options->{page_width};
  my $page_height = $options->{page_height};
  my $max_width = $page_width - $options->{border_width} * 2;
  my $page_centre_x = $page_width / 2;
  my $page_centre_y = $page_height / 2;
  my $half_height = $page_height / 2;

  my $real_options =
  {
   %$options,
   max_width     => $max_width,
   page_centre_x => $page_centre_x,
   page_centre_y => $page_centre_y,
   half_height   => $half_height,
  };

  my $half_width = $real_options->{max_width} / 2;

  $real_options->{half_width} = $half_width;

  my $x_scale = $real_options->{half_width} / 100;
  my $y_scale = $real_options->{half_width} / 100;

  $real_options->{x_scale} = $x_scale;
  $real_options->{y_scale} = $y_scale;

  print $fh <<EOHEADER;
\%!PS-Adobe-2.0
\%\%Creator: circular_diagram.pl
\%\%Author: Sanger Centre Pathogen Sequencing Unit
\%\%PageBoundingBox: 0 0 $page_width $page_height
\%\%Pages: 1
\%\%EndComments

\%\%BeginProlog
/M {moveto} def /L {lineto} def
\%\%EndProlog

initgraphics
0.50 setlinewidth

\%\%Page: 1 1

$page_centre_x $page_centre_y translate
$x_scale $y_scale scale
EOHEADER

  for my $data (@data) {
    draw_data $fh, $options, $data;
  }

  draw_scale $fh, $options;

  print $fh <<EOF;
showpage
\%\%EOF
EOF
}
