############################################################################
#
# $Id: ProjectId.pm 30479 2014-03-25 21:17:04Z jinghuahuang $
############################################################################
package ProjectId;

use strict;
use CGI qw( :standard );
use WebConfig;
use WebUtil;
use Data::Dumper;

my $section                   = 'GenomeList';
my $env                       = getEnv();
my $main_cgi                  = $env->{main_cgi};
my $section_cgi               = "$main_cgi?section=$section";
my $base_dir                  = $env->{base_dir};
my $base_url                  = $env->{base_url};
my $verbose                   = $env->{verbose};
my $user_restricted_site      = $env->{user_restricted_site};
my $img_internal              = $env->{img_internal};
my $img_lite                  = $env->{img_lite};
my $img_hmp                   = $env->{img_hmp};
my $img_er                    = $env->{img_er};
my $include_metagenomes       = $env->{include_metagenomes};
my $cgi_tmp_dir               = $env->{cgi_tmp_dir};


sub dispatch {
    my $page = param('page');
    if($page eq 'list') {
        printProjectList();
    } else {
        printProjectList();
    }
}

sub printProjectList {
    my $projectId = param('projectId');
    
    my $sql = qq{
        select t.taxon_oid
        from taxon t
        where t.jgi_project_id = ?
    };
    
    my $title = "Project ID $projectId Genome List";
    my @bind = ($projectId);
    require GenomeList;
    GenomeList::printGenomesViaSql( '', $sql, $title, \@bind );    
    
};

1;