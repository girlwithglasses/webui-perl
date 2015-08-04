############################################################################
# TreeQ.pm - Start java applet for Tree view.
#  This is just a prototype for the time being.
#    --es 02/02/2007
############################################################################
package TreeQ;
my $section = "TreeQ";
use strict;
use CGI qw( :standard );
use WebUtil;
use WebConfig;

my $env = getEnv( );
my $base_url = $env->{ base_url };
my $base_dir = $env->{ base_dir };
my $verbose = $env->{ verbose };

my $code = "gov.lbl.genome.tree.TreeApplet";
my $codebase = "http://hazelton.lbl.gov/treeq";
my $servletUrl = "http://hazelton.lbl.gov/servlet/treeq";
my $archive = "Tree.jar";
my $jsUrl = "http://hazelton.lbl.gov/treeq/treeq.js";

############################################################################
# dispatch
############################################################################
sub dispatch {
     my $page = param( "page" );
     if( paramMatch( "applet" ) ne "" ) {
        printApplet( );
     }
     else {
        webError( "Unsupported page='$page'." );
     }
}

############################################################################
# printAppletForm
############################################################################
sub printAppletForm {
    my( $taxon_oids_ref ) = @_;

    ## --es 07/17/2007 No longer needed.
    return;

    print "<form name='treeq'  method='POST'>\n";
    my $sessionId = getSessionId( );
    print hiddenVar( "sid", $sessionId );
    for my $taxon_oid( @$taxon_oids_ref ) {
        print hiddenVar( "taxon_oid", $taxon_oid );
    }
    my $name = "_section_${section}_applet";
    print submit( -name => $name,
       -value => "Dynamic Tree View", -class => "medbutton" );
    print "</form>\n";
}


############################################################################
# printJavaScript - Print javascript section.
############################################################################
sub printJavaScript {
    print "<script language='javascript' type='text/javascript'>\n";
    my $line_separator = "\\n";
    print qq{
         function read_form_values() {
         	var f = document.forms['treeq'];
         	var values = "";
         	var line_separator = "$line_separator";
         	var element_name = 'taxon_oid';
         	var taxon_oids = document.getElementsByName(element_name);	
         	for (var i = 0; i < taxon_oids.length; i++) {
         		values += taxon_oids[i].value + line_separator;
                }
         	return values;
         }
         function submitForm(name) {
         	document.TreeQ.read_html();
         }
    };
    print "</script>\n";

}

############################################################################
# printApplet - Show initial applet.
############################################################################
sub printApplet {
     print "<h1>Dynamic Tree View (Experimental)</h2>\n";
     print "<form name = 'treeq' id = 'treeq'>\n";
     printJavaScript( );
     my @taxon_oids = param( "taxon_oid" );
     for my $taxon_oid( @taxon_oids ) {
         print hiddenVar( "taxon_oid", $taxon_oid );
     }
     print qq{
        <a href="#" onclick="submitForm('treeq');return false">
           Highlight Genomes</a>
     };
     print "</form>\n";
     #print "<applet name='TreeQ' code='$code' codebase='$codebase' ";
     #print "archive='$archive' width='100%' height='80%' MAYSCRIPT ";
     print "<applet name='TreeQ' code='$code' codebase='$codebase' ";
     print "archive='$archive' width='100%' height='500px' MAYSCRIPT ";
     print "alt='Your browser understands the applet tag, but applet ";
     print "is not running'>\n";
     print "<param name='servletURL' value='$servletUrl'>\n";
     print "You browser is ignoring the applet tag.\n";
     print "</applet>\n";
}

1;

