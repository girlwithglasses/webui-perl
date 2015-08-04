############################################################################
#
# $Id: ProteinCluster.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package ProteinCluster;
my $section = "ProteinCluster";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use TaxonDetail;
use POSIX qw(ceil floor);
use FindFunctions;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $img_internal          = $env->{img_internal};
my $tmp_dir               = $env->{tmp_dir};
my $user_restricted_site  = $env->{user_restricted_site};
my $include_metagenomes   = $env->{include_metagenomes};
my $show_private          = $env->{show_private};
my $content_list          = $env->{content_list};
my $pfam_base_url         = $env->{pfam_base_url};
my $cog_base_url          = $env->{cog_base_url};
my $tigrfam_base_url      = $env->{tigrfam_base_url};
my $include_img_term_bbh  = $env->{include_img_term_bbh};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $ko_stats_paralog_file = $env->{ko_stats_paralog_file};
my $ko_stats_combo_file   = $env->{ko_stats_combo_file};

my $max_gene_batch     = 500;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    
    if($page eq "exptForm") {
        printExptForm();
    } else {
        
    FindFunctions::printKoStatsLinks();
    }
}

sub printExptForm {
    my $taxon_oid = param("taxon_oid");
    
    
    
}

1;