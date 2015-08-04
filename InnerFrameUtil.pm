############################################################################
# InnerFrameUtil.pm - This is a little bit of AJAX, except
#   instead of sending data, we invoke remote requests to
#   generate inner frame HTML content.  This keeps most
#   of UI on the server side instead of on the browser
#   using javascript.  
#   (The approach is easier for development, as well
#    as better resources for handling data at the server end,
#    at the expense of shipping more data.)
#   (It uses mainly the GET method, since I can't seem
#    to get the POST method as well as forms to work.)
#
#  Usage:
#     printIfrPreamble( );
#     my $html_proto = ... 
#         # fill in the HTML prototype string.
#         # Cf. printHtml( ) below on .remoteCall template.
#     printIfrHtml( $html_proto );
#
#   --es 10/05/2006
############################################################################
package InnerFrameUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( printIfrPreamble printIfrHtml );
use strict;

############################################################################
# printJsStart and End - Print javascript start and end.
############################################################################
sub printJsStart {
   print "<script language='javascript' type='text/javascript'>\n";
}
sub printJsEnd {
   print "</script>\n";
}

############################################################################
# printPreamble - Print preamble functions for this javascript system.
############################################################################
sub printIfrPreamble {
   printJsStart( );
   print qq{
       function createRequestObject() {
           var ro;
           try { ro = new ActiveXObject( "Msxml2.XMLHTTP" ); }
           catch( e ) {
               try { ro = new ActiveXObject( "Microsoft.XMLHTTP" ); }
               catch( oc ) { ro = null; }
           }
           if( !ro && typeof XMLHttpRequest != "undefined" ) {
             ro = new XMLHttpRequest( );
           }
        return ro;
       }
       var http = createRequestObject( );
   };
   printJsEnd( );
}

############################################################################
# printRequestHandlers - Template handlers by target <div> ID's.
############################################################################
sub printRequestHandlers {
   my( $divId ) = @_;
   
   printJsStart( );
   print qq{
        function sendReq_${divId}( url ) {
	    var e = document.getElementById( '$divId' );
	    e.innerHTML = "<font color='red' size='-1'><blink>" +
	       "Loading ...</blink></font>";
	    http.open( 'get', url );
	    http.setRequestHeader( "If-Modified-Since",
	       "Sat, 1 Jan 2000 00:00:00 GMT" );
	    http.onreadystatechange = recvReq_${divId};
	    http.send( null );
	}
	function recvReq_${divId}( ) {
	    if( http.readyState == 4 ) {
	       var e = document.getElementById( '$divId' );
	       e.innerHTML = http.responseText;
	    }
	}
   };
   printJsEnd( );
}

############################################################################
# translate2Call - Translate arguments to javascript calls.
############################################################################
sub translate2Call {
    my( $url, $divId, $unquoted ) = @_;
    my $s;
    if( $unquoted ) {
        $s = "<script language='JavaScript' type='text/javascript'>\n";
        $s .= "sendReq_${divId}('$url');";
	$s .= "</script>\n";
    }
    else {
        $s = "\"javascript:sendReq_${divId}('$url');\"";
    }
    return $s;
}


############################################################################
# extractDivIds - Extract <div> ID's from HTML prototype. 
#   We expect a very simple format for function
#   invocation ease of parsing.
#   Inputs:
#     html_proto - HTML prototype string.
#     divIds_ref - Div ID's hash, with maps to function calls.
############################################################################
sub extractDivIds {
    my( $html_proto, $divIds_ref ) = @_;

    my @lines = split( /\n/, $html_proto );
    for my $s( @lines ) {
       $s =~ s/^\s+//;
       $s =~ s/\s+$//;
       $s =~ s/\s+/ /g;
       next if $s !~ /^\.remoteCall/;
       my( $remoteCall, $url, $divId ) = split( / /, $s );
       $divIds_ref->{ $divId } = 1;
    }
}

############################################################################
# printHtml - Print HTML from HTML prototype string.  Convert all
#   remote calls to proper javascript function invocation.
#   Generate the proper javascript functions declarations.
#
#  Remote call has the following format, on it's own line
#   (for ease of parsing).
#      .remoteCall <url> <targetDivId>
#  There should be a corresponding output 
#       <div id=targDivID></div>
#  somewhere below in the HTML.  This can be associated
#  with <a href=
#        .remoteCall <remoteUrl> <outputDiv>
#       > ... </a>
#  or with some event, such as
#       <...  onClick=
#         .remoteCall <remoteUrl> <outputDiv>
#       ...>
#
#  For immediate use of remote call, do the following
#  (on it's own line):
#      .doRemoteCall <url> <targetDivId>
#
############################################################################
sub printIfrHtml {
   my( $html_proto ) = @_;

   ## Javascript function declarations.
   my %divIds;
   extractDivIds( $html_proto, \%divIds );
   my @keys = sort( keys( %divIds ) );
   for my $divId( @keys ) {
      printRequestHandlers( $divId );
   }

   ## Replace prototype with actual HTML code.
   my @lines = split( /\n/, $html_proto );
   for my $s( @lines ) {
      $s =~ s/^\s+//;
      $s =~ s/\s+$//;
      $s =~ s/\s+/ /g;
      if( $s =~ /^\.remoteCall / ) {
          my( $remoteCall, $url, $divId ) = split( / /, $s );
          my $jsCall = translate2Call( $url, $divId );
          print "$jsCall\n";
      }
      elsif( $s =~ /^\.doRemoteCall / ) {
          my( $remoteCall, $url, $divId ) = split( / /, $s );
          my $jsCall = translate2Call( $url, $divId, 1 );
          print "$jsCall\n";
      }
      else {
          print "$s\n";
      }
   }
}


1;
