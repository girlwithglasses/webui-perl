############################################################################
#  Add tab view
############################################################################
package TabViewFrame;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
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
my $img_internal        = $env->{img_internal};
my $tmp_dir             = $env->{tmp_dir};
my $web_data_dir        = $env->{web_data_dir};
my $YUI28               = $env->{yui_dir_28};
my $include_metagenomes = $env->{include_metagenomes};

sub printTabViewMarkup {
    if ( $ENV{HTTP_USER_AGENT} =~ /MSIE/ ) {
        print qq{
            <iframe id='tabviewFrame-history-iframe' 
		    src="$base_dir\/blank.html"><\/iframe>
            <style type='text/css'>
                #tabviewFrame-history-iframe {
                  position: absolute;
                  top: 0;
                  left: 0;
                  width: 1px;
                  height: 1px;
                  visibility: hidden;
                }
            </style>
        };
    }
    else {
        print qq{
            <div id='tabviewFrame-history-iframe'><\/div>
        };
    }
    print qq{
        <input id="tabviewFrame-history-field" type="hidden">
    };

    print qq{
        <link rel="stylesheet" type="text/css" 
	 href="$YUI28/build/container/assets/skins/sam/container.css" />
        <link rel="stylesheet" type="text/css" 
	 href="$YUI28/build/tabview/assets/skins/sam/tabview.css" />

        <script type="text/javascript" 
	 src="$YUI28/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
        <script type="text/javascript" 
	 src="$YUI28/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/container/container-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/yahoo/yahoo-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/event/event-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/connection/connection-min.js"></script>        
        <script type="text/javascript" 
	 src="$YUI28/build/element/element-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/tabview/tabview-min.js"></script>
        <script type="text/javascript" 
	 src="$YUI28/build/history/history-min.js"></script>
     };

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

        <script src='$base_url/chart.js'></script>
        <script language='JavaScript' type='text/javascript' 
	        src='$base_url/tabviewFrame.js'>
        </script>
    };

}

sub printTabViewWidgetStart {
    my (@tabNames) = @_;

    my $count = 0;
    my $tabLis = "";
    my @tabIds;
    my $namesStr = "";
    my $idsStr = "";
    foreach my $name (@tabNames) {
    	chomp $name;
    	$name = strTrim($name);
    	next if ( $name eq "" );
	
        my $tabId = "tab" . $count;
        $tabLis .= "<li><a href=" . $tabId . "><em>$name</em></a></li>";
        $tabIds[$count] = $tabId;
	
        $namesStr .= $name;
        $idsStr .= $tabId;
        if ($count != $#tabNames) {
    	    $namesStr .= ',';
    	    $idsStr .= ',';        	
        }
        
    	$count++;
    }

    print qq{
        <script type="text/javascript">
           setTabNames('$namesStr', '$idsStr');
        </script>
    };

    print qq{
        <div id="tabviewFrame" class="yui-navset yui-navset-top">
	    <ul class="yui-nav">
	    $tabLis
	    </ul>
        <div class="yui-content">
    };

    return @tabIds;
}

# $style - some addition style if needed
# - for example in Find Genomes Genome Search page the default div size
#   is too small and the example text goes into the footer    - ken
sub printTabIdDivStart {
    my ($tabId, $style) = @_;
    print qq{
       <div id="$tabId" $style>
    };
}

sub printTabIdDivEnd {
    print qq{
       </div>
    };
}

sub printTabIdDiv_NoneActive {
    my ($tabId) = @_;
    print qq{
       <div id="$tabId"></div>
    };
}

sub printTabViewWidgetEnd {
    print qq{
          </div>
        </div>
    };	
}

1;
