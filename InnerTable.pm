############################################################################
# InnerTable.pm - Wrapper that selectively loads Yahoo! tables
#
# In WebConfig.pm, set
#              $e->{ yui_tables } = 1;  #for Yahoo! tables
#    OR
#              $e->{ yui_tables } = 0;  #for HTML tables
#    OR
#              $e->{ ext_tables } = 1;  #for ext tables
#
# $Id: InnerTable.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
use WebUtil;
use WebConfig;

my $env        = getEnv( );
my $yui_tables = $env->{ yui_tables };
my $ext_tables = $env->{ ext_tables };

if ($ext_tables) {
    require InnerTable_ext;
} elsif ($yui_tables) {
    require InnerTable_yui;
} else {
    require InnerTable_old;
}

1;
