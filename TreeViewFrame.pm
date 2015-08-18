############################################################################
#  Tree view utility
############################################################################
package TreeViewFrame;
#my $section = "TreeViewFrame";

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  printTreeMarkup
);

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use WebConfig;
use WebUtil;

my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $base_url            = $env->{base_url};
my $YUI28               = $env->{yui_dir_28};

sub printTreeMarkup {
    print qq{
        <link rel="stylesheet" type="text/css" href="$YUI28/build/treeview/assets/skins/sam/treeview.css" />
        <script type="text/javascript" src="$YUI28/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript" src="$YUI28/build/treeview/treeview-min.js"></script>
        <script type="text/javascript" src="$YUI28/build/json/json-min.js"></script>
        <script type="text/javascript" src="$YUI28/build/calendar/calendar-min.js"></script>

        <style type='text/css'>
            .ygtv-checkbox .ygtv-highlight0 .ygtvcontent {
                background:url("$base_url/images/check0.gif") no-repeat scroll 0 0 transparent;
                padding-left:1.25em;
            }
            .ygtv-checkbox .ygtv-highlight1 .ygtvcontent {
                background:url("$base_url/images/check1.gif") no-repeat scroll 0 0 transparent;
                padding-left:1.25em;
            }
            .ygtv-checkbox .ygtv-highlight2 .ygtvcontent {
                background:url("$base_url/images/check2.gif") no-repeat scroll 0 0 transparent;
                padding-left:1.25em;
            }
            .ygtvfocus, 
            .ygtvfocus .ygtvlabel, 
            .ygtvfocus .ygtvlabel:link, 
            .ygtvfocus .ygtvlabel:visited,
            .ygtvfocus .ygtvlabel:hover,
            .ygtv-checkbox .ygtv-highlight0 .ygtvfocus.ygtvcontent, 
            .ygtv-checkbox .ygtv-highlight1 .ygtvfocus.ygtvcontent, 
            .ygtv-checkbox .ygtv-highlight2 .ygtvfocus.ygtvcontent  {
                background-color:white;
            }
        </style>

        <script language='JavaScript' type='text/javascript' src='$base_url/treeviewFrame.js'>
        </script>
    };
}

1;
