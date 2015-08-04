############################################################################
# StaticInnerTable.pm - Static tables using YUI styles.
# Backwards compatible with InnerTable syntax.
#
# E.g. usage:
#
#    Create a new StaticInnerTable( ) instance.
#    ------------------------------------------------
#    my $it = new StaticInnerTable();
#
#   Add column specifications to the table.
#   ----------------------------------------------------
#   See addColSpec()
#   
#   my $sd = $it->getSdDelim( ); # get sort delimiter character
#
#   The fields in a row string is delimited by "\t".
#       E.g.  $row .= "$val\t";
#   A field may optionally be split between the raw data value
#   and the HTML display value.
#   ******* THIS IS LEFT FOR COMPATIBILITY WITH InnerTable
#       E.g.  $row .= $val . $sd . $displayVal . "\t";
#   A row string is added to the table by
#       $it->addRow( $row );
#
#   The static inner table may be displayed after everything is loaded by
#       $it->printOuterTable();
# $Id: StaticInnerTable.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package StaticInnerTable;
use strict;
use WebUtil;
use WebConfig;

my $env         = getEnv( );
my $verbose     = $env->{ verbose };
my $YUI         = $env->{yui_dir_28}; #get local path to YUI libraries
my $sdDelim     = "#==#";  # Hope this string doesn't appear in data!! +BSJ 05/23/12

############################################################################
# new - new instance.
#  Arguments: none
############################################################################
sub new {
   my( $myType) = @_;

   my $self = { };
   my @colSpec;
   my @rows;

   $self->{ colSpec }      = \@colSpec;
   $self->{ rows }         = \@rows;

   bless( $self, $myType );
   return $self;
}

##################################################################################
# addColSpec - Add column specification.
#
# I added a new feature bgcolor, so it should a value of:
#  "bgcolor=#D2E6FF" w/o quotes - ken 2008-07-23
#  title or column header tooltip - should be title='abc'
#
#  >>> Updated usage:
# addColSpec("Mycolumn","asc|desc", "left|center|right", "<HTML Color>", "mytitle",
#            "<blank>|nowrap|wrap", "<width in px>");
#
# >>>>>> Argument order maintained for compatibility with InnerTable +BSJ 06/01/12
##################################################################################
sub addColSpec  {
    my( $self, $displayColName, $sortSpec, $align, $bgcolor, $title,
	$wrapSpec, @widthSpec ) = @_;

    # $wrapSpec - Acceptable values: "" (default), "wrap", or "nowrap"
    # @widthSpec = (<width>) arbitrary column width in px. Do not specify units.

    my $a = $self->{ colSpec };

    my $h = {
       displayColName => $displayColName,
       align          => $align,
       bgcolor        => $bgcolor,
       title          => $title,
       wrap           => $wrapSpec,
       widthSpec      => \@widthSpec
    };

    webLog "addColSpec '$displayColName' '$align'\n"
       if $verbose >= 3;
    push( @$a, $h );
}

############################################################################
# getSdDelim - Get sort value and display value delimiter.
#            >>>> No longer used. For InnerTable compatibility +BSJ 06/01/12
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
# printOuterTable - Print the static table using YUI styles.
#                   Same as printTable()
# Arguments: None
############################################################################
sub printOuterTable {
   my( $self ) = @_;

   my $blockDatatableCss    = $self->{ blockDatatableCss };
   my $colSpec     = $self->{ colSpec };
   my $rows        = $self->{ rows };
   my $nCols       = @$colSpec;

   if( $nCols == 0 ) {
       webError( "Table unavailable. Please refresh the whole page." );
       webLog "printOuterTable: Missing Colspec\n" if $verbose >= 1;
       return;
   }

   # do not load datatable.css again if this is not the first datatable
   # on this page, otherwise any previous setting will be reset (such as
   # column alignment, sorting...) - yjlin 04/19/2013
   print qq {
   <link rel="stylesheet" type="text/css"
       href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
   } if ( $blockDatatableCss ne '1' );

   print qq {
       <style>
       .yui-skin-sam .yui-dt th .yui-dt-liner {
           white-space: inherit;
       }
       </style>
       <div class='yui-dt' style='padding:5px 0'>
       <table style='font-size:12px'>
   };

   for my $c( @$colSpec ) {
      my $displayColName = $c->{ displayColName };

      my $title = $c->{ title };
      $title =~ s/title\s*=\s*//g;    # remove "title=" to support legacy code
      $title =~ s/(^'|'$)//g;         # remove leading and trailing ' to support legacy code
      $title = "title='$title'" if $title;

      my $wrap = $c->{ wrap };
      my $width = $c->{ widthSpec }[0];
      my $wrapStyle = "white-space:nowrap;" if $wrap eq "nowrap";
      my $widthStyle = "width:${width}px;" if $width;
      my $style = $wrapStyle . $widthStyle;
      $style = "style='$style'" if $style;
      print qq{
        <th $style>
 	    <div class='yui-dt-liner'>
	    <span $title>$displayColName</span>
	    </div>
	</th>
      };
   }

   my $count = 0;
   my $classStr;

   for my $r( @$rows ) {
      $classStr = !$count ? "yui-dt-first ":"";
      $classStr .= ($count % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
      $count++;

      my @fields = split( /\t/, $r );
      my $idx = 0;

      print "<tr class='$classStr' >\n";

      for my $f( @fields ) {
         my ( $val, $displayVal ) = split( $sdDelim, $f );
	 my $c = $colSpec->[ $idx ];
	 $displayVal = $val if ($displayVal eq "");
	 my $align = $c->{ align };
	 my $alignSpec = "text-align:$align;" if ($align ne "");

	 my $bgcolor = $c->{ bgcolor };
	 $bgcolor =~ s/(bgcolor|=)//g; # remove "bgcolor=" to support legacy code
	 my $bgColorSpec = "background-color:$bgcolor;" .
	     "border:1px outset white;" if ($bgcolor ne "");

	 print "<td class='$classStr' style='$alignSpec'>\n";
         print "<div class='yui-dt-liner' style='$bgColorSpec'>";
	 print  $displayVal;
	 print "</div>\n";
	 print "</td>\n";
	 $idx++;
      }
      print "</tr>\n";
   }

   print "</table>\n";
   print "</div>\n";
   webLog "Created StaticInnerTable ["
	   . currDateTime( ) . "]\n" if $verbose >= 1;
}

############################################################################
# printTable - Synonym for printOuterTable - for InnerTable compatibility
############################################################################
sub printTable {
   my( $self ) = @_;
   $self->printOuterTable( );
}

1;
