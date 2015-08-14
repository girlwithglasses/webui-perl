############################################################################
# WebGD.pm - wrapper for the Graphics Draw (GD) library  
#                 (obtained from MG-RAST - anl.gov).
#                 Used by RadialTree.pm
# $Id: WebGD.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package WebGD;

use strict;
use warnings;

use GD;
use GD::Polyline;
use base qw( GD::Image );

use MIME::Base64;
use File::Temp qw( tempfile );

$| = 1;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  bless($self, $class);

  return $self;
}

sub newFromPng {
  my $class = shift;

  # for now this only works on filepath
  return undef unless(-f $_[0]);

  my $self = $class->SUPER::newFromPng(@_);
  
  bless($self, $class);

  return $self;
}


# Return the MIME encoded link for small pie charts
sub image_src {
  my ($self) = @_;
  my $mime = MIME::Base64::encode($self->png(), "");
  my $image_link = "data:image/png;base64,$mime";

  return $image_link;
}

# Return the MIME encoded link for radial tree
sub main_image_src {
  my ($self) = @_;
  my $image_link;

  # IE does not work with large (>32K) inline MIME encoded images.
  # So output a temp file and provide a URL to it -BSJ 04/19/11
  if ($ENV{ HTTP_USER_AGENT } =~ /MSIE/) {
      use WebConfig;
      use WebUtil;
      my $env          = getEnv();
      my $tmp_url      = $env->{ tmp_url };
      my $tmp_dir      = $env->{ tmp_dir };
      my $file = "/RadialTree$$.png";
      my $image_file = $tmp_dir . $file;
      $image_link = $tmp_url . $file;
      my $outHandle = newWriteFileHandle($image_file, "RadialTree");
      binmode $outHandle;  # Force the output file to be binary
      print $outHandle $self->png();
      close $outHandle;
  } else {
      my $mime = MIME::Base64::encode($self->png(), "");
      $image_link = "data:image/png;base64,$mime";
  }
  return $image_link;
}

1;
