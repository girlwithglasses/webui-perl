############################################################################
# MyImg.pm - Functions supporting MyIMG utilty.
#    --es 04/16/2005
############################################################################
package About;
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;

$| = 1;
my $section = "About";
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param('page');
    
    if($page eq "using") {
        print "New using img  page here\n";
    } elsif ($page eq "news"){
        print "New news page here\n";
    } else {
        print "New About page here\n";
    }
}

1;
