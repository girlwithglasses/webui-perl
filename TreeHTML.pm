############################################################################
#
# Template html code to build a frameless page with a javascript tree
# on thr left and inner html pages on the left.
# This template prints the start and end of the page. Its up to you
# to build the tree.
# see BinTree.pm
# see PhylumTree.pm
#
# $Id: TreeHTML.pm 29739 2014-01-07 19:11:08Z klchu $
#
package TreeHTML;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  printYuiTreePageStart
);

use strict;
use CGI qw( :standard );
use Data::Dumper;

use WebUtil;
use WebConfig;

$| = 1;

my $env     = getEnv();

#
# configuration - location of yahoo's api
#
my $YUI = $env->{yui_dir_28};

#
# Start of the frameless HTML tree page, its copied from treeview.net
# but I'm using yahoo's api.
# You need to print this first. After this section you need to
# add your code (javascript) to  build the tree
#
sub printYuiTreePageStart {

    print <<EOF;

<!--
    If you want, edit the styles for the remainder if the
    document.
-->
  
	<!-- Yahoo API - updated for 2.8 -->
	<link rel="stylesheet" type="text/css" href="$YUI/examples/treeview/assets/css/local/tree.css" />
	<link rel="stylesheet" type="text/css" href="$YUI/examples/treeview/assets/css/check/tree.css" />
	<link rel="stylesheet" type="text/css" href="$YUI/build/treeview/assets/skins/sam/treeview.css">
	<link rel="stylesheet" type="text/css" href="$YUI/build/resize/assets/skins/sam/resize.css" />

	<script type="text/javascript" src = "$YUI/build/yahoo-dom-event/yahoo-dom-event.js" ></script>
	<script type="text/javascript" src = "$YUI/build/treeview/treeview-min.js" ></script> 
	<script type="text/javascript" src = "$YUI/build/connection/connection-min.js"></script> 
	<script type="text/javascript" src = "$YUI/examples/treeview/assets/js/TaskNode.js"></script>
	<script type="text/javascript" src = "$YUI/build/utilities/utilities.js"></script>
	<script type="text/javascript" src = "$YUI/build/resize/resize.js"></script>

<style>

/* Styles */
body { 
    background-color: white; 
}

.ygtvfocus {
    background-color: white; 
}

</style>

EOF

	# TODO custom build tree
}

#
# End of frameless HTML tree page.
#
# param $treeDivId - name you want html's div id to be, default value is "tree".
#		this is where the tree will be drawn. The div id is required
#		by the yahoo's api to initialize the tree.
# param $innerDivId - HTML's div id where the the inner pages (right-side) will
# 		be loaded. default value is "innerSection"
# param $initTreeMethod - Your javascript method to initialize the tree.
#		Default value is "initializeDocument"
#
# param $tooltip turn on tool tip div, top of the root node
#		1 on, anything else is off
#		remember you'll have to source the correct js lib files
# param $treeName - name used in tree label div in tool tip area, default is
#		"Tree"
#
# param $buttonDiv html code for a buttons div under the tree.
#		It can be a blank value 
#	e.g. 
#	 <div='treeButtons'>
#	 	<input type='button' name='save' value='Save Selection'
#	  		onClick='javascript:treeSaveSelected()' class='smbutton' />	 
#	 </div>
#
# see PhylumTree::yuiPrintTreeFolderDynamic for example
#
# Main Table -----------------------------------------------------------
# - TR - TD								- TD
# -		Table ------------------------	-	Table ----------------
# -			- TR - TD				 -	-		- TR - TD
# -			-	Table ----------------	-		-	inner html
# -			-		- TR - TD       --	-		-
# -			-		-	tree div	--	-		-
# -			-		------------------	-		-
# -			-----------------------------		------------------
# ----------------------------------------------------------------------
#
#
sub printYuiTreePageEnd {
	my ( $treeDivId, $innerDivId, $initTreeMethod, $tooltip, $treeName, $buttonDiv ) = @_;

	$treeDivId      = "tree"               if ( $treeDivId      eq "" );
	$innerDivId     = "innerSection"       if ( $innerDivId     eq "" );
	$initTreeMethod = "initializeDocument" if ( $initTreeMethod eq "" );
	$treeName       = "Tree"               if ( $treeName       eq "" );

	print <<EOF;    
	
<style>
    #resize {
        border: 1px solid blue;
        border-top: 0px;
        border-left: 0px;
        border-bottom: 1px solid blue;
        border-right: 1px solid blue;        
        height: 400px;
        width: 300px;
        background-color: #fff;
        overflow-y:auto;
    }
    #resize div.$treeDivId {
        overflow: hidden;
        height: 100%;
        width: 100%;
    }
</style>	
	
	<!-- 
		The main body of the page, including the table         
		structure that contains the tree and the contents.
	-->

 <!-- main table -->	
 <TABLE cellpadding="0" cellspacing="0" border="0" width="772">
  <TR>
   <TD width="178" valign="top">
   
   <!-- border line around tree -->
    <TABLE cellpadding="4" cellspacing="0" border="0" >
     <TR>
      <TD bgcolor="#ECECD9">
      
        <!-- tree area -->
        <TABLE cellspacing="0" cellpadding="2" border="0" width="100%">
         <TR>
          <TD bgcolor="white">

EOF

	if ( $tooltip == 1 ) {
		print "<div id='tooltipid' "
		  . "style='font-size:8pt;text-decoration:none;color:silver'>";
		print "$treeName</div>";
	}

	print <<EOF;
	<!--
		Build the tree.
	-->
	   
     <div id="resize" ><p>
  	<div id='parentTreeDiv' >
  	
  	<!-- 
  		no text label wrap tip from 
  		http://yuiblog.com/sandbox/yui/v0121/examples/treeview/scrolling.php
  		
  		580 = 600 - 20, 20 for the horz. scroll bar
  		
  		the area must be a static size, it does not work dynamically 
  	-->
  	
  	<div id='$treeDivId'>
  	<!-- div id='$treeDivId' style='width: 600px; height: 580px;'> --> 	
  	</div>
	
	<!-- init tree -->
  	<SPAN>
  	<SCRIPT>
  		$initTreeMethod();
	</SCRIPT>
	<NOSCRIPT>
		A tree for site navigation will open here if you enable JavaScript in your browser.
	</NOSCRIPT>
	</SPAN>

	</div>
</p>
</div>
          </TD>
         </TR>
        </TABLE>
        <!-- end of tree area -->

       </TD>
      </TR>
     </TABLE>
	 <!-- end of border line around tree -->
	 
	 $buttonDiv

    </TD>

	<!-- main table 1st row 2nd colum -->
    <TD bgcolor="white" valign="top">
     <TABLE cellpadding="10" cellspacing="0" border="0" width="100%">
      <TR>
       <TD>

		<!-- 
			And now we have the continuation of the body of the  
 			page, after the tree.  Replace this entire section with 
 			your site's HTML.
 		-->

		<div id='$innerDivId'>
		
			<!-- CUSTOM section inner.cgi pages -->
			
		</div>

       </TD>
      </TR>
     </TABLE>
     <!-- end of inner table -->

    </TD>
   </TR>
  </TABLE>



<script>

(function() {
    var Dom = YAHOO.util.Dom,
        Event = YAHOO.util.Event;
    
    var resize = new YAHOO.util.Resize('resize', {
        proxy: true,   
        animate: true,   
        animateDuration: .75,   
        animateEasing: YAHOO.util.Easing.backBoth   
    });
})();
</script>

EOF
}

