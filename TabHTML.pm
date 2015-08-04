############################################################################
# $Id: TabHTML.pm 31086 2014-06-03 19:14:00Z klchu $
############################################################################
package TabHTML;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;

$| = 1;

my $section = "TabHTML";
my $env = getEnv( );
my $base_url  = $env->{base_url};
my $YUI = $env->{yui_dir_28};

############################################################################
# print yui links and dependencies - .js and .css files
# param $tabName used for yahoo api
############################################################################
sub printTabAPILinks {
    my ($tabName, $init_flag) =@_;
    
#    print qq{
#	<!-- Dependencies -->
#	    
#	<link rel="stylesheet" type="text/css" 
#	 href="$YUI/build/container/assets/skins/sam/container.css" />
#	<link rel="stylesheet" type="text/css" 
#	 href="$YUI/build/tabview/assets/skins/sam/tabview.css" />
#
#	<script type="text/javascript" 
#	 src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
#	<script src="$YUI/build/element/element-min.js"></script>
#	<script src="$YUI/build/tabview/tabview-min.js"></script>
	print qq{   
        <style type='text/css'> 
	    .yui-skin-sam .yui-navset .yui-nav .selected a em { 
	        background-color:#6699CC;
	    } 

	    .yui-skin-sam .yui-navset .yui-content { 
	        border-style:hidden; 
	        background:none repeat scroll 0 0 #FFFFFF;
	    } 

	    .yui-skin-sam .yui-navset .yui-nav .selected a, 
	    .yui-skin-sam .yui-navset .yui-nav .selected a em { 
	        border-color:#6699CC;
	    } 

	    .yui-skin-sam .yui-navset .yui-nav, 
	    .yui-skin-sam .yui-navset .yui-navset-top .yui-nav { 
	        border:solid #a3a3a3; 
	        border-width:0 0 1px;
	        Xposition:relative; 
	        zoom:1;
	    }
	</style> 
    };

    if (!$init_flag || ($init_flag eq "")) {
    print qq{
	<script type="text/javascript">
        var myTabs = new YAHOO.widget.TabView("$tabName");
	</script> 
    };  
    } else {
	# will be initialized in calling code
    }
}

############################################################################
# create the html div for the tabs
# DOES NOT print the </div> yet, its up to you to print your code here
# 
# param $tabName used for yahoo api
# param $tabIndex_aref array list of tab index names
# param $tabNames_aref array list of tab names
############################################################################
sub printTabDiv {
    my ($tabName, $tabIndex_aref, $tabNames_aref, $width) = @_;
    
    print "<div id=\"$tabName\" class=\"yui-navset\">\n";
    print "<ul class=\"yui-nav\">\n";

    for (my $i=0; $i<=$#$tabIndex_aref; $i++) {
        if ($i == 0 ) {
            # select the first tab
            print qq{
		<li class="selected">
		    <a href="$tabIndex_aref->[$i]">
		    <em>$tabNames_aref->[$i]</em>
		    </a>
		</li>\n};
        } else {
            print qq{
		<li><a href="$tabIndex_aref->[$i]">
		    <em>$tabNames_aref->[$i]</em></a>
		</li>};
        }
    }
    
    print "</ul> \n";
    print "<div class='yui-content'>\n";
    # now print your code!
}

############################################################################
# end of tab div
############################################################################
sub printTabDivEnd {
    # yui-content div
    print "</div>\n";
    # tabName div
    print "</div>\n";
}



1;
