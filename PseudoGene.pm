###########################################################################
#
# $Id: PseudoGene.pm 30280 2014-03-01 03:19:34Z jinghuahuang $
#
package PseudoGene;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;

$| = 1;

my $env          = getEnv();
my $cgi_dir      = $env->{cgi_dir};
my $cgi_url      = $env->{cgi_url};
my $main_cgi     = $env->{main_cgi};
my $inner_cgi    = $env->{inner_cgi};
my $tmp_url      = $env->{tmp_url};
my $verbose      = $env->{verbose};
my $web_data_dir = $env->{web_data_dir};
my $img_internal = $env->{img_internal};
my $cgi_tmp_dir  = $env->{cgi_tmp_dir};


1;