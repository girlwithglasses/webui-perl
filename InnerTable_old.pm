############################################################################
# InnerTable.pm - Inner sortable cached table using AJAX.
#  WARNING: Currently only allow one of these per page.
#  Also, web browser back button does not work correctly, which
#  is a typical problem with AJAX.
#  The inner table is generated from and a secondary CGI process
#  from inner.cgi.  The outer table is the primary CGI process.
#
# E.g. usage:
#
#    Create a new InnerTable( ) instance.
#
#    my $it = new InnerTable( $clobberCache, $instanceId, $typeId,
#                             $defaultSortIndex );
#             # clobberCache - Clobber old cache and start over again
#             # instanceId - Unique ID of this one instance
#             # typeId - Type name
#             # default sort column index. Index starts at 0.
#
#   Add column specifications to the table.
#
#   $it->addColSpec( $columnName, $sortSpec, $alignSpec )
#             # HTML column name
#             # sort specification "<number|char> <asc|desc>"
#             # display field alignment specification "<left|right>"
#   ...
#
#   my $sd = $it->getSdDelim( ); # get sort delimiter character
#
#   The fields in a row string is delimited by "\t".
#       E.g.  $row .= "$val\t";
#   A field may optionally be split between the raw sortable data value
#   and the HTML display value.
#       E.g.  $row .= $val . $sd . $displayVal . "\t";
#   A row string is added to the table by
#       $it->addRow( $row );
#
#   The inner table may be displayed in an outer table frame,
#   after everything is loaded by
#       $it->printOuterTable( 1 );
#   (The 1 says to show the "Loading ..." message.)
#
#    --es 09/09/2005
#
# $Id: InnerTable_old.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package InnerTable;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $inner_cgi =  $env->{ inner_cgi };

my $verbose = $env->{ verbose };

my $sdDelim = "##";

############################################################################
# new - new instance.
#  Arguments:
#    id - ID with [a-zA-Z][a-zA-Z0-9_]* identifier. Does not have to
#       include sessionId.
#    sortType - Sort type (so param("sortIdx") is not confused).
#    startSortIdx - Index to start sort.
#    baseUrl - Base URL "inner.cgi?iframe=innerTable"
#    loader( $innerTable, @args )  - Loader subroutine.
#    loaderArgs - Arguments for loader subroutine.
############################################################################
sub new {
   my( $myType, $clobberCache, $id, $sortType, $startSortIdx, $baseUrl,
       $loader, @loaderArgs ) = @_;

   $baseUrl = "$inner_cgi?iframe=innerTable" if $baseUrl eq "";
   my $self = { };
   bless( $self, $myType );
   $self->{ id } = $id;
   my $stateFile = $self->getStateFile( );
   wunlink( $stateFile ) if $clobberCache;
   if( -e $stateFile ) {
      $self = retrieve( $stateFile );
      $self->{ sortIdx } = $startSortIdx if $startSortIdx ne "";
      $self->{ sortIdx } = $self->{ startSortIdx } if $startSortIdx eq "";
   }
   else {
      my @colSpec;
      $self->{ baseUrl } = $baseUrl;
      $self->{ id } = $id;
      #$self->{ loadingMessage } = $loadingMessage;
      $self->{ startSortIdx } = $startSortIdx;
      $self->{ sortType } = $sortType;
      $self->{ sortIdx } = $startSortIdx;
      $self->{ colSpec } = \@colSpec;
      my @rows;
      $self->{ rows } = \@rows;
      if( defined( $loader ) ) {
         $loader->( $self, @loaderArgs );
      }
      $self->save( );
   }

   bless( $self, $myType );
   return $self;
}

############################################################################
# getStateFile - Get the name for the state file.  Uniform wrapper.
############################################################################
sub getStateFile {
    my( $self ) = @_;
    my $id = $self->{ id };
    my $sessionId = getSessionId( );
    my $stateFile = "$cgi_tmp_dir/$id.$sessionId.stor";
    return $stateFile;
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my( $self ) = @_;
   store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# addColSpec - Add column specification.
#
# I added a new feature bgcolor, so it should a value of:
#  "bgcolor=#D2E6FF" w/o quotes - ken 2008-07-23
#  title or column header tooltip - should be title='abc'
############################################################################
sub addColSpec  {
    my( $self, $displayColName, $sortSpec, $align, $bgcolor, $title ) = @_;
    my $h = {
       displayColName => $displayColName,
       sortSpec => $sortSpec,
       align => $align,
       bgcolor => $bgcolor,
       title => $title
    };
    webLog "addColSpec '$displayColName' '$sortSpec' '$align'\n"
       if $verbose >= 3;
    my $a = $self->{ colSpec };
    push( @$a, $h );
}

############################################################################
# getSdDelim - Get sort value and display value delimiter.
############################################################################
sub getSdDelim {
   my( $self ) = @_;
   return $sdDelim;
}

############################################################################
# addRow - Add one row. Row data column values are tab delimited.
#  If display value (which may be hyperlinked HTML)
#   is different from sort value, follow the sort value with a $sdDelim.
############################################################################
sub addRow {
   my( $self, $row ) = @_;
   my $rows = $self->{ rows };
   webLog "addRow row='$row'\n" if $verbose >= 3;
   push( @$rows, $row );
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my( $self, $sortIdx, $outRecs_ref ) = @_;
    my $rows = $self->{ rows };
    my @a;
    my @idxVals;
    my $colSpec = $self->{ colSpec };
    my $nCols = @$colSpec;
    if( $sortIdx >= $nCols || $sortIdx < 0 ) {
      webLog( "sortedRecArray: invalid sortIdx='$sortIdx' nCols=$nCols\n" );
    }
    my $h = $colSpec->[ $sortIdx ];
    my $displayColName = $h->{ displayColName };
    my $sortSpec = $h->{ sortSpec };
    my $align = $h->{ align };
    my $rowIdx = 0;
    for my $r( @$rows ) {
       my @fields = split( /\t/, $r );
       my $sortRec;
       my $sortField = $fields[ $sortIdx ];
       my( $sortVal, $sortDisplay ) = split( $sdDelim, $sortField );
       my $idxVal = "$sortVal\t$rowIdx";
       push( @idxVals, $idxVal );
       $rowIdx++;
    }
    my @idxValsSorted;
    if( $sortSpec =~ /desc/ ) {
       if( $sortSpec =~ /^number/ || $sortSpec =~ /^exponential/ ) {
          @idxValsSorted = reverse( sort{ $a <=> $b }( @idxVals ) );
       }
       else {
          @idxValsSorted = reverse( sort( @idxVals ) );
       }
    }
    else {
       if( $sortSpec =~ /^number/ || $sortSpec =~ /^exponential/ ) {
           @idxValsSorted = sort{ $a <=> $b }( @idxVals );
       }
       else {
           @idxValsSorted = sort( @idxVals );
       }
    }
    for my $i( @idxValsSorted ) {
       my( $idxVal, $rowIdx ) = split( /\t/, $i );
       my $r = $rows->[ $rowIdx ];
       push( @$outRecs_ref, $r );
    }
}

############################################################################
# printOuterTable - Print outer table stub.
############################################################################
sub printOuterTable {
   my( $self, $loadingMessage ) = @_;

   $self->save( );

   my $id = $self->{ id };
   my $baseUrl = $self->{ baseUrl };
   my $sortType = $self->{ sortType };
   my $sortIdx = $self->{ sortIdx };

   print "<script language='javascript' type='text/javascript'>\n";
   my $loadingCode;
   $loadingCode = qq{
      var e = document.getElementById( '$id' );
      e.innerHTML =
         "<p><font color='red'><blink>Loading section ...</blink></font></p>" +
	 "<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>" +
	 "<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>" +
	 "<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>" +
	 "<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>" +
	 "<br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>";
      //printLoadingMessage( );
   } if $loadingMessage;

   # Fix for displaying 2 HTML tables on the same page;
   # may not work if there are 3 tables. +BSJ 02/01/10

   my $sessionId = getSessionId( );
   my $statFile = "$cgi_tmp_dir/" . $$ . $sessionId; #uniquely identifies an HTML page instance
   my $sendUrl; my $http;

   unless ( -e $statFile ) { #if this is the first table on this HTML page,
       str2File ("$sessionId$$", $statFile); # create a session file,
       $sendUrl = "sendUrl";                 # and use first XHR object
       $http = "http";                       # in the JS code below
   }
   else {                      # otherwise,
       $sendUrl = "sendUrl2";  # use the second XHR object that is
       $http = "http2";        # exists in header.js
   }

   print qq{
      var target = ctime( );

      function ${id}Send( sortIdx ) {
         var url = '$baseUrl' +
	    "&id=$id" +
	    "&sortType=$sortType" +
            "&sortIdx=" + sortIdx +
            "&linkTarget=" + target;
	 $loadingCode
         $sendUrl( url, ${id}Recv );
      }
      function ${id}Recv( ) {
         if( $http.readyState == 4 ) {
            var e = document.getElementById( '$id' );
            e.innerHTML = $http.responseText;
	    //printLoadedMessage( );
         }
      }
   };

   print "</script>\n";
   print "<div id='$id'>\n";
   print "</div>\n";
   print "<script>${id}Send($sortIdx)</script>\n";
}

############################################################################
# printInnerTable - Print the inner HTML table out.
############################################################################
sub printInnerTable {
   my( $self ) = @_;

   $self->save( );

   my $id = $self->{ id };
   my $baseUrl = $self->{ baseUrl };
   my $colSpec = $self->{ colSpec };
   my $sortIdx = $self->{ sortIdx };
   my $sortType = $self->{ sortType };
   my $stateFile = $self->getStateFile( );

   webLog "param(sortType)='" .
      param( "sortType" ) . "'  sortType.self='$sortType'\n";
   webLog "param(sortIdx)='" . param( "sortIdx" ) . "'\n";
   webLog "param(id)='" . param( "id" ) . "' id.self='$id'\n";
   $sortIdx = param( "sortIdx" ) if param( "sortIdx" ) ne "" &&
     param( "sortType" ) eq $sortType;

   webLog "printInnerTable id='$id' sortIdx='$sortIdx'\n"
      if $verbose >= 1;
   my $nCols = @$colSpec;
   if( $nCols == 0 ||
     ( param( "sortIdx" ) ne "" && !-e( $stateFile ) ) ) {
       webError( "Inner session expired. Please refresh the whole page." );
       webLog( "printInnerTable: iframe id='$id' expired\n" );
       return;
   }
   my @rows;
   $self->sortedRecsArray( $sortIdx, \@rows );
   print "<table class='img' border='1'>\n";
   my $idx = 0;
   for my $c( @$colSpec ) {
      my $displayColName = $c->{ displayColName };
      my $sortSpec = $c->{ sortSpec };
      my $align = $c->{ align };
      my $bgcolor = $c->{bgcolor};
      my $title = $c->{title};
      # add bgcolor=#D2E6FF
      $title = "title='$title'" if $title ne "";
      $bgcolor = "style='background-color: $bgcolor'" if $bgcolor ne "";

      print "<th class='img' $bgcolor $title>\n";
      if( $sortSpec eq "" ) {
          print "$displayColName";
      }
      else {
	  if( $baseUrl =~ /inner.cgi/ ) {
              print "<a href='javascript:${id}Send($idx)'>";
	  }
	  else {
              print "<a href='$baseUrl";
	      print "&sortType=$sortType";
	      print "&sortIdx=$idx";
	      print "&id=$id'>";
	  }
          print "$displayColName";
          print "</a>\n";
      }
      print "</th>\n";
      $idx++;
   }
   my $count = 0;
   for my $r( @rows ) {
      $count++;
      my $rowClass = "img";
      #$rowClass = "highlight" if $count % 2 == 0;
      print "<tr class='$rowClass'>\n";
      my @fields = split( /\t/, $r );
      my $idx = 0;
      for my $f( @fields ) {
         my( $val, $displayVal ) = split( $sdDelim, $f );
	 my $c = $colSpec->[ $idx ];
	 my $align = $c->{ align };
	 my $bgcolor = $c->{bgcolor};
	 $bgcolor = "style='background-color: $bgcolor'" if $bgcolor ne "";
	 my $alignSpec;
	 $alignSpec = "align='$align'" if $align ne "";
	 print "<td class='img' $alignSpec $bgcolor>\n";
	 if( $displayVal ne "" ) {
	    print $displayVal;
	 }
	 else {
	    print escHtml( $val );
	 }
	 print "</td>\n";
	 $idx++;
      }
      print "</tr>\n";
   }
   print "</table>\n";
}

############################################################################
# printTable - Do not use inner.cgi server.  Clean up old files.
############################################################################
sub printTable {
   my( $self, $purgeStateFile ) = @_;
   $self->printInnerTable( );
   wunlink( $self->getStateFile( ) ) if $purgeStateFile;
}

############################################################################
# sub loadDatatableCss
############################################################################
sub loadDatatableCss {
    # do nothing, just a placeholder
}


1;
