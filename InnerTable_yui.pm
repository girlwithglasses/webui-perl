############################################################################
# InnerTable_yui.pm - Dynamic tables using Yahoo User Interface (YUI).
# Requires supporting template file datatable.html in HTDOCS.
# Can accomodate multiple tables per page. Performance degradation
# possibly proportional to number of tables per page.
#
# E.g. usage:
#
#    Create a new InnerTable( ) instance.
#    ------------------------------------------------
#    my $it = new InnerTable( $clobberCache, $instanceId, $typeId,
#                             $defaultSortIndex );
#             # clobberCache - Clobber old cache and start over again
#             # instanceId - Unique ID of this one instance
#             # typeId - Type name
#             # default sort column index. Index starts at 0.
#
#   To change default rows per page, set
#   --------------------------------------------------
#   $it->{pageSize} = "<number of default rows per page>"
#   default page size is 100 rows 
#   Acceptable pageSize values: 10, 25, 50, 100, 500, 1000, All
#
#   Add column specifications to the table.
#   ----------------------------------------------------
#   $it->addColSpec( $columnName, $sortSpec, $alignSpec )
#             # HTML column name
#             # sort specification "<number|char> <asc|desc>"
#          ****** Yahoo Datatable update: <number|char> now ignored;
#                 column type detected automatically  +BSJ 11/11/09
#             # display field alignment specification "<left|right>"
#   See addColSpec() for additional options
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
#   The inner table may be displayed after everything is loaded by
#       $it->printOuterTable( 1 );             # normal page render
#       $it->printOuterTable( "nopage" ); # no pagination
#
# $loadingMessage: no longer used for displaying the "Loading ..." message
#                  but a value of "nopage" displays a table without
#                  pagination and page navigation elements.
#
# ************ Updates for Yahoo Datatables +BSJ 11/10/09 *****************
# The parameters have been maintained to support legacy code. Existing
# InnerTables will be automatically converted to YUI tables.
#
# $sortSpec: <number|char> no longer needed. Sort routine in
#           json_proxy.pl automatically detects type.
#           If sortSpec is empty column won't be sortable
#
#           <asc|desc>: Since datatables toggle sort order between ascending
#           and descending, the sort direction specfied here will be sort
#           the first time that column heading is clicked to be sorted.
#
# $Id: InnerTable_yui.pm 32309 2014-11-18 22:12:40Z klchu $
############################################################################
package InnerTable;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use Time::HiRes qw (gettimeofday);
use StaticInnerTable;

my $env         = getEnv( );
my $main_cgi    = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $cgi_dir     = $env->{ cgi_dir };
my $verbose     = $env->{ verbose };
my $cgi_url     = $env->{ cgi_url };
my $YUI         = $env->{yui_dir_28};     #get local path to YUI libraries
my $xml_cgi = $cgi_url .'/xml.cgi';
my $sdDelim = "#==#";  # Hope this string doesn't appear in the data!! +BSJ 05/23/12

my $base_dir = $env->{ base_dir };	    # get base HTDOCS dir +BSJ 11/10/09
my $base_url = $env->{ base_url };	    # get base HTDOCS url +BSJ 12/07/09
my $yui_headerfile = "datatable_header.html";
my $datatable_htmlfile = "datatable.html";  # must be prepended with $base_dir
my $rowsPerPage = 100;                            # default rows per page

my $dir = WebUtil::getSessionDir();
$dir .= "/yui";
if ( !(-e "$dir") ) { 
    mkdir "$dir" or webError("Can not make $dir!"); 
}
$cgi_tmp_dir = $dir;


############################################################################
# new - new instance.
#  Arguments:
#    id - ID with [a-zA-Z][a-zA-Z0-9_]* identifier. Does not have to
#       include sessionId.
#    sortType - Sort type (so param("sortIdx") is not confused).
#    startSortIdx - Index to start sort.
#    baseUrl - Base URL "inner.cgi?iframe=innerTable"   <<<- deprecated
#    loader( $innerTable, @args )  - Loader subroutine. <<<- deprecated
#    loaderArgs - Arguments for loader subroutine.      <<<- deprecated
#
#    ******* Yahoo Datatables update: last 3 args deprecated +BSJ 11/11/09
#    Added $self->{ hideExport } +BSJ 04/29/11
#    Added $self->{ hideFilter } +BSJ 04/29/11
#    Added $self->{ hidePages  } +BSJ 04/29/11
#    Added $self->{ hideSelect } +BSJ 05/02/11
############################################################################
sub new {
   my( $myType, $clobberCache, $id, $sortType, $startSortIdx, $baseUrl,
       $loader, @loaderArgs ) = @_;

   my $self = { };
   bless( $self, $myType );
   $self->{ id } = $id;

   my $stateFile = $self->getStateFile( );
   wunlink( $stateFile ) if $clobberCache;

   if( -e $stateFile ) {
      $self = retrieve( $stateFile );
      $self->{ sortIdx } = $startSortIdx if $startSortIdx ne "";
      $self->{ sortIdx } = $self->{ startSortIdx } if $startSortIdx eq "";
   } else {
      my @colSpec;
      $self->{ baseUrl }      = $baseUrl;
      $self->{ id }           = $id;
      $self->{ startSortIdx } = $startSortIdx;
      $self->{ sortType }     = $sortType;
      $self->{ sortIdx }      = $startSortIdx;
      $self->{ pageSize }     = $rowsPerPage; # initial page size
      $self->{ colSpec }      = \@colSpec;
      $self->{ hideExport }   = "false";  # show export buttons by default
      $self->{ hideColSel }   = "false";  # show column selector by default
      $self->{ hideFilter }   = "false";  # show filter line by default
      $self->{ hideSelect }   = "false";  # show Select/Deselect Page buttons by default
      $self->{ hidePages }    = 0;        # show pagination by default
      my @rows;
      $self->{ rows }         = \@rows;

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
# hideExportButtons - Suppress showing the Export buttons in YUI tables 
############################################################################
sub hideExportButtons {
   my( $self ) = @_;
   $self->{ hideExport } = "true";
}

############################################################################
# hideColumnSelector - Suppress the column selector button in YUI tables 
############################################################################
sub hideColumnSelector {
   my( $self ) = @_;
   $self->{ hideColSel } = "true";
}

############################################################################
# hideFilterLine - Suppress showing filter feature in YUI tables 
############################################################################
sub hideFilterLine {
   my( $self ) = @_;
   $self->{ hideFilter } = "true";
}

############################################################################
# hidePagination - Suppress showing pages and navigation bar in YUI tables 
############################################################################
sub hidePagination {
   my( $self ) = @_;
   $self->{ hidePages } = 1;
}

############################################################################
# disableSelectButtons - Disable Select/Deselect Page buttons in YUI tables 
############################################################################
sub disableSelectButtons {
   my( $self ) = @_;
   $self->{ hideSelect } = "true";
}

############################################################################
# hideAll - Suppress all of the above in YUI tables 
############################################################################
sub hideAll {
   my( $self ) = @_;
   $self->{ hideColSel } = "true";
   $self->{ hideExport } = "true";
   $self->{ hideSelect } = "true";
   $self->{ hideFilter } = "true";
   $self->{ hidePages  } = 1;
}

############################################################################
# nonFilterColumn
#      - Don't list column(s) in "Filter Column" dropdown for YUI tables.
#        Such columns are, therefore, non-filterable.
#      - arg. $colId: zero based index of column(s) separated by commas.
#                   If $colId is blank the last defined column is used.
# examples: $it->nonFilterColumn(2) suppresses column 3 from appearing in
#                the "Filter Column" dropdown.
#           $it->nonFilterColumn(2,3,6) suppresses columns 3,4, and 7 from 
#                appearing in the "Filter Column" dropdown.
#           $it->nonFilterColumn() suppresses the last defined column from
#                appearing in the "Filter Column" dropdown.
# HINT: To hide filtering entirely, call $it->hideFilterLine;
############################################################################
sub nonFilterColumn {
   my( $self, @colId ) = @_;
   my $colSpec = $self->{ colSpec };
   @colId[0] = $#$colSpec if !(@colId);
   for my $id (@colId) {
       if ($id < @$colSpec) { # check that arg. is with array bounds
	   $colSpec->[$id]->{ filter } = 0;
       }
   }
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
#
#  >>> Updated usage:
# addColSpec("Mycolumn","asc|desc", "left|center|right", 
#            "<HTML Color>", "mytitle",
#            "<blank>|nowrap|wrap", "<width in px>", "<maxAutoWidth in px>");
#
#    Former usage has been grandfathered in so old code won't break
#  >>> Added colName as a key to store field names with spaces
#      and special characters removed
#  - for internal use +BSJ 11/11/09
#
#  >>> Added wrapSpec and widthSpec. See below for explanation +BSJ 09/29/10
#
############################################################################
sub addColSpec  {
    my( $self, $displayColName, $sortSpec, $align, $bgcolor, $title,
	$wrapSpec, @widthSpec ) = @_;

    # $wrapSpec - Acceptable values: "" (default), "wrap", or "nowrap"
    # When $wrapSpec = "", that column's <th> is nowrap, but <td> wraps.
    # This is the YUI default.
    # Use $wrapSpec = "nowrap" to force a nowrap for the entire column.

    # @widthSpec = (<width>, <maxAutoWidth>) numbers in px.
    # Do not specify units.
    # See http://developer.yahoo.com/yui/docs/YAHOO.widget.Column.html
    # or http://img.jgi.doe.gov/yui/docs/YAHOO.widget.Column.html

    my $colName = $displayColName;
    my $a = $self->{ colSpec };

    # By default, list this column within "Filter Column" dropdown in YUI tables
    my $filter = 1;

    $colName =~ s/(<br>|<br\/>)//ig;
    $colName =~ s/<[^>]*>//gs;  #remove HTML tags
    $colName =~ s/(\s|\W)//g;   #remove white space, and special chars

    # Convert quotes to HTML entities, but allow HTML in tooltips
    $title   =~ s/"/&quot;/g if ($title);
    $title   =~ s/'/&apos;/g if ($title);

    # check for duplicate column
    for my $c ( @$a ) {
	if ( $c->{ colName } eq $colName ) {
	    $colName .= $#$a; # append array size to make column key unique
	}
    }

    my $h = {
       colName        => $colName,
       displayColName => $displayColName,
       sortSpec       => $sortSpec,
       align          => $align,
       bgcolor        => $bgcolor,
       title          => $title,
       filter         => $filter,
       wrap           => $wrapSpec,
       widthSpec      => \@widthSpec
    };

    webLog "addColSpec '$displayColName' '$sortSpec' '$align'\n"
       if $verbose >= 3;
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
# printOuterTable - Print outer table stub.
#
# >>>Modified for YUI Datatable - BSJ 11/10/09
############################################################################
sub printOuterTable {
   my( $self, $loadingMessage, $headerLineToRemove, $jsOrigLineToRemove,
       $jsNewLineToAdd ) = @_;

   my $blockDatatableCss = $self->{ blockDatatableCss };
   my $colSpec           = $self->{ colSpec };
   my $sortType          = $self->{ sortType };
   my $sortIdx           = $self->{ sortIdx };
   my $rows              = $self->{ rows };
   my $id                = $self->{ id };
   my $pageSize          = $self->{ pageSize };
   my $hideExport        = $self->{ hideExport }; # hide export buttons if "true"
   my $hideColSel        = $self->{ hideColSel }; # hide column selector if "true"
   my $hideFilter        = $self->{ hideFilter }; # hide filter line if "true"
   my $hideSelect        = $self->{ hideSelect }; # disable Select/Deselect Page buttons if "true"
   my $hidePages         = $self->{ hidePages  }; # hide pagination if 1
   my $JS_Null           = "null";
   my $rowID_Label       = "_img_yuirow_id";
   my $filtCol           = param("filtCol");
   my $filtTerm          = param("filtTerm");
   my $filtType          = param("filtType");
   my $contact_oid = WebUtil::getContactOid();

   # populate $sortType if blank; used as HTML table id
   # $sortType will be blank when called via CachedTable
   $sortType = ($sortType eq "") ? $id : $sortType;

   webLog "sortType.self='$sortType'\n";
   webLog "sortIdx.self='$sortIdx'\n";
   webLog "printInnerTable sortIdx='$sortIdx'\n"
    if $verbose >= 1;

   my $nCols = @$colSpec;
   if( $nCols == 0 ) {
       webError( "Table unavailable. Please refresh the whole page." );
       webLog "printOuterTable: Missing Colspec\n" if $verbose >= 1;
       return;
   }
   my $colDefs; # holds __col_defs__ for HTML template (datatable.html)
   my $rowDefs = "            " . qq({ key:"$rowID_Label" },\n) ;   #holds __row_defs__
   my $sortedBy = "${JS_Null}";     #holds __sorted_By__ for HTML template (datatable.html)
   my $initSortField = "";    #holds __init_sort_field__ for HTML template (datatable.html)
   my $initSortDir = "";       #holds __init_sort_dir__ for HTML template (datatable.html)
   my $colStyles;
   my $idx = 0;

   for my $c( @$colSpec ) {
      my $displayColName = $c->{ displayColName };
      my $colName = $c->{ colName };
      my $sortSpec = $c->{ sortSpec };
      my $title = $c->{ title };
      # display in Filter Column dropdown if "true"
      my $filter = $c->{ filter } ? "true" : "false"; 
      $title =~ s/title\s*=\s*//g;    # remove "title=" to support legacy code
      $title =~ s/(^'|'$)//g;         # remove leading and trailing ' to support legacy code

      my $wrap = $c->{ wrap };
      my $width = $c->{ widthSpec }[0];
      my $maxAutoWidth = $c->{ widthSpec }[1];

      my $key = "";
      my $label = qq(, label:"$displayColName");
      my $field = "";
      my $sortString = "";

      my $colSkin = "\n.yui-skin-sam td.yui-dt-col-$colName {\n";
      my $align = $c->{ align };
      my $alignSpec = "    text-align:$align;\n" if ($align ne "");
      my $bgcolor = $c->{ bgcolor };
      $bgcolor =~ s/(bgcolor|=)//g; # remove "bgcolor=" to support legacy code
      my $bgColorSpec = "    background-color:$bgcolor;\n" .
	                "    border:1px outset white;\n" if ($bgcolor ne "");

      $rowDefs .= "            " . qq({ key:"$colName");
      $key = qq({ key:"$colName", resizeable:true);

      # check sort order of field
      if( $sortSpec =~ /(asc|desc)/i) {
	  $sortString = qq(, sortable:true, sortOptions:{defaultDir:YAHOO.widget.DataTable.CLASS_) . uc($1). qq(});
	  if ($sortIdx == $idx) { # get sortIdx and set up initial sort
	      $initSortField = $colName;
	      $initSortDir = "\L$1";
	      $sortedBy = $key . qq(, dir:YAHOO.widget.DataTable.CLASS_) . uc($1) . qq(});
	  } else {
	      $initSortField = $colName if ($initSortField  eq "");
	      $initSortDir = "\L$1" if ($initSortDir  eq "");
	      $sortedBy = $key . qq(, dir:YAHOO.widget.DataTable.CLASS_) . uc($1) . qq(})
		  if ($sortedBy eq "${JS_Null}");
	  }
      } else {
	  $sortString = qq(, sortable:false);
      }
      my $toolTip = qq(, toolTip: "$title");
      my $filterStr = qq(, filter: $filter);
      my $colWidthStr;
      $colWidthStr = qq (, width:$width) if $width;
      $colWidthStr .= qq (, maxAutoWidth:$maxAutoWidth) if $maxAutoWidth;

      my $className;
      $className = qq (, className:"img-col-) . $wrap . qq (")
	  if ($wrap =~ /(wrap|nowrap)/i);

      # check through the entire column for at least one non-blank display value
      my $hasDispVal = colHasDispVal($idx, $rows);
      if ($hasDispVal) {
	  $field = qq(, field:"$colName) . qq(Disp");
	  $rowDefs .= qq( },\n            { key:"$colName) . qq(Disp");
      }

      $colDefs .= "        " . $key . $field . $label . $sortString
	  . $toolTip . $filterStr . $colWidthStr . $className . " },\n";
      $rowDefs .= " },\n";

      $colStyles .= (($alignSpec || $bgColorSpec) ne "")
	  ? $colSkin . $alignSpec . $bgColorSpec . "}\n" : "";
      $idx++;
   }

   # remove trailing new line and the last comma in the array definitions
   chomp $colDefs;chop $colDefs;
   chomp $rowDefs;chop $rowDefs;

   my $count = 0;
   my $arLine = "";

   for my $r( @$rows ) {
      $count++;
      my @fields = split( /\t/, $r );
      my $idx = 0;

      $arLine .= qq({\n   '$rowID_Label'=>'$count',\n); # generate a unique row ID

      for my $f( @fields ) {
         my ( $val, $displayVal ) = split( $sdDelim, $f );
	 my $c = $colSpec->[ $idx ];

	 # Used by selection.js::disableCheckbox() to identify checkboxes in this table
	 # class atttribute is used to store "<table name>-chk"
	 if ($c->{ colName } =~ /(^Select$|^Selection$)/i) {
	     if ($displayVal =~ /class\s*=\s*['|"]*/i) { # check if class statement exists
	        $displayVal =~ s/$&/$&$sortType-chk /i;  # add a custom class
	     } else { # just add a new class statement for this checkbox
		 $displayVal =~ s/name/class='$sortType-chk' name/i;
	     }
	 }

	 my $hasNoVal = ($val eq "") ? 1 : 0;
	 my $colNameSuffix = ($hasNoVal) ? "" : "Disp"; # don't append suffix if raw (non-HTML) value absent
	 $displayVal = escHtml($val) if ($displayVal eq "");
	 if( $val ne "" ) {
	     $displayVal =~ s/\\/\\\\/g;   #escape \ since this is generated perl code
	     $displayVal =~ s/'/\\'/g;     #escape ' since this is generated perl code
	     $arLine .= "   '" . scalar($c->{ colName }) . $colNameSuffix . "'=>'" . $displayVal . "',\n";
	 } else {
	     $val = $displayVal;
	 }
	 $val =~ s/\\/\\\\/g;   #escape \ since this is generated perl code
	 $val =~ s/'/\\'/g;     #escape ' since this is generated perl code
	 $arLine .= "   '" . scalar($c->{ colName }) . "'=>'" . $val . "',\n"
	     if (($colNameSuffix ne "") || $hasNoVal);

	 $idx++;
      }
      $arLine .= "},\n";
   }

   my $arrayFile = str2TempFile( $arLine);
   my @path=split(/\//,$arrayFile);
   my $fileName = $path[$#path];
   my $formId = $sortType . "_frm";

   # check if YUI headers are already on this HTML page
   my $sessionId = getSessionId( );
   my $yuiStatFile = "$cgi_tmp_dir/" . $$ . $sessionId; #uniquely identifies an HTML page instance

   # block loading of datatable.css because it has been loaded earlier on the same page.
   if ( $blockDatatableCss eq 1 ) {
       $headerLineToRemove = "datatable.css";
   }

   if ( -e $yuiStatFile ) {
       $formId = file2Str ($yuiStatFile) . "_frm" ;
   } else {
       str2File ("$sortType", $yuiStatFile);
       my $yuiTemplate = "$base_dir/$yui_headerfile";
       my $yuiStr;
       if ($headerLineToRemove ne '') {
           $yuiStr = conditionalFile2Str( $yuiTemplate, $headerLineToRemove, '' );
       } else {
           $yuiStr = file2Str( $yuiTemplate );
       }
       $yuiStr =~ s/__yui_url__/$YUI/g;
       $yuiStr =~ s/__base_url__/$base_url/g;
######## uncomment line below for debug version of YUI JS headers #######
#       $yuiStr =~ s/-min.js/-debug.js/g;
######## uncomment line above for debug version of YUI JS headers #######

       print $yuiStr;        # print YUI header prior to first datatable
   }

   my $htmlTemplate = "$base_dir/$datatable_htmlfile";
   my $htmlStr;
   if ($jsOrigLineToRemove ne '') {
       $htmlStr = conditionalFile2Str( $htmlTemplate, $jsOrigLineToRemove, $jsNewLineToAdd );
   } else {
       $htmlStr = file2Str( $htmlTemplate );
   }

   # replace markers in datatable template

   # Use an iframe if IE; see http://developer.yahoo.com/yui/history/#req_markup
   if ($ENV{ HTTP_USER_AGENT } =~ /MSIE/) {
       $htmlStr =~ s/__bhm_container__/<iframe id="__table_id__-bhm" src="__base_url__\/blank.html"><\/iframe>/g;
   } else {
       $htmlStr =~ s/__bhm_container__/<div id="__table_id__-bhm"><\/div>/g;
   }

   $htmlStr =~ s/__form_id__/$formId/g;
   $htmlStr =~ s/__table_id__/$sortType/g;
   $htmlStr =~ s/__contact_oid__/$contact_oid/g;
   $htmlStr =~ s/__xml_pl_url__/$xml_cgi/g;
   $htmlStr =~ s/__unique_id__/$id/g;
   $htmlStr =~ s/__filtCol__/$filtCol/g;
   $htmlStr =~ s/__filtTerm__/$filtTerm/g;
   $htmlStr =~ s/__filtType__/$filtType/g;
   $htmlStr =~ s/__array_file__/$fileName/g;
   $htmlStr =~ s/__cached_session__/$sessionId/g;
   $htmlStr =~ s/__col_defs__/$colDefs/g;
   $htmlStr =~ s/__row_defs__/$rowDefs/g;
   $htmlStr =~ s/__sorted_By__/$sortedBy/g;
   $htmlStr =~ s/__init_sort_field__/$initSortField/g;
   $htmlStr =~ s/__init_sort_dir__/$initSortDir/g;
   $htmlStr =~ s/__col_styles__/$colStyles/g;
   $htmlStr =~ s/__base_url__/$base_url/g;
   $htmlStr =~ s/__main_cgi__/$main_cgi/g;
   $htmlStr =~ s/__yui_url__/$YUI/g;
   $htmlStr =~ s/__hide_export_buttons__/$hideExport/g;
   $htmlStr =~ s/__hide_column_selector__/$hideColSel/g;
   $htmlStr =~ s/__hide_filter_line__/$hideFilter/g;
   $htmlStr =~ s/__hide_selectpage__/$hideSelect/g;

   # Set max row pull down to "All" if < 10000, otherwise "Top 10,000"
   if ( $count > 10000 ) {
       $htmlStr =~ s/__max_rows_num__/10000/g;
       $htmlStr =~ s/__max_rows_txt__/Top 10,000/g;
   } else {
       $htmlStr =~ s/__max_rows_num__/"All"/g;
       $htmlStr =~ s/__max_rows_txt__/All/g;
   }

   # $loadingMessage comandeered for specifying "no pagination" tables
   # if $loadingMessage = "nopage" the table created won't have pagination
   $hidePages = 1 if ($loadingMessage eq "nopage");
   if ($hidePages) {
       $pageSize = @$rows; # Change the initial page size to total rows
       $htmlStr =~ s/__paginator__/$JS_Null \/\/No pagination for this table/g;
   } else {
       $htmlStr =~ s/__paginator__/myPaginator/g;
   }

   $htmlStr =~ s/__rows_per_page__/$pageSize/g;

   print $htmlStr;
   webLog "Generated HTML and Javascript for YUI Datatable $id ["
	   . currDateTime( ) . "]\n" if $verbose >= 1;
}

############################################################################
# printTable - Do not use inner.cgi server.  Clean up old files.
############################################################################
sub printTable {
   my( $self, $purgeStateFile ) = @_;
   $self->printOuterTable( );
   wunlink( $self->getStateFile( ) ) if $purgeStateFile;
}

############################################################################
# str2TempFile - Create a temp file in the CGI temp directory
#                and the return the file name with path
# BSJ 11/10/09
############################################################################
sub str2TempFile {
    my ($str) = @_;

    my $sid = getSessionId();

    # Create some randomness
    my ($sec,$min,$hr,$mday,$mon,$yr,$wday,$yday,$isdst) = localtime(time);
    my ($s, $msec) = gettimeofday;
    my $file = "yui_dt_" . $hr.$min.$sec.$msec . "_" . $$ . "_" . substr($sid,0,10);

    $file = WebUtil::checkFileName($file);
    my $path = "$cgi_tmp_dir/$file";

    str2File ($str, $path);
    webLog "Created YUI Datatable temp file: '$path'" . currDateTime( ) . "\n" if $verbose >= 1;
    return $path;
}

############################################################################
# colHasDispval - Check whether a specified column has at least one
#                 non-blank value. If yes, return 1.
#                 Called by printOutertable()
############################################################################
sub colHasDispVal {
    my ($colIdx, $rows) = @_;

    for my $r (@$rows) {
	my @curRow  = split(/\t/, $r);
	my ($val, $displayVal) = split( $sdDelim, @curRow[$colIdx]);
	return 1 if $val;
    }
    return 0;
}

############################################################################
# sub loadDatatableCss - load datatable.css
#
# Normally this is done within printOuterTable. But in some cases when
# there are more than one datatable on one HTML page, datatable.css should
# be loaded only once. Otherwise later loadings of this css file
# will overwrite any settings made earlier such as column alignment.
# - yjlin 04192013
############################################################################
sub loadDatatableCss {

   print qq {
   <link rel="stylesheet" type="text/css"
       href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
   };

}



1;
