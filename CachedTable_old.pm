############################################################################
# CachedTable.pm - Cached table for later sorting.
#  Not be used for table with large numbers of columns.
#  This currently does not work for more than one sort column.
#  This module may be made obsolete with a more AJAX like module
#  called InnerTable.pm which uses an inner.cgi rendering for the
#  table.
#   --es 06/30/2005
############################################################################
package CachedTable;
use strict;
use Data::Dumper;
use Storable;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $verbose = $env->{ verbose };

my $sdDelim = "##";
	# SortValue##DisplayValue delimiter.

############################################################################
# new - Allocate new instance.
#  colSpecs is an array of colSpec hash references.
#    displayColName - HTML column name.
#    sortSpec -  "sortType1 asc|desc, sortType2, asc|desc"
#       zero index based. sortType = "char" or "number".
#       If no sort spec, then this field
#       is not hyperlinked for sorting.
#    align - Align 'left' or 'right' in <td class='img' > field.
#
#  Initial sort is as rows are entered.
############################################################################
sub new {
    my( $myType, $id, $baseUrl, $colSpecs_ref, $colorMap_ref ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ id } = $id;
    my $stateFile = $self->getStateFile( );
    if( -e $stateFile ) {
       $self = retrieve( $stateFile );
    }
    else {
        my @a;
        $self->{ id } = $id;
        $self->{ baseUrl } = $baseUrl;
        $self->{ colSpecs } = $colSpecs_ref;
        if( $self->{ colSpecs } eq "" ) {
            my @b;
	    $self->{ colSpecs } = \@b;
        }
        $self->{ rows } = \@a;
        $self->{ colorMap } = $colorMap_ref;
	$self->save( );
    }
    return $self;
}

############################################################################
# getStateFile - Uniform wrapper for getting the state file for this
#   object.
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
############################################################################
sub addColSpec  {
    my( $self, $displayColName, $sortSpec, $align, $bgcolor, $title ) = @_;
    my $h = {
       displayColName => $displayColName,
       sortSpec => $sortSpec,
       align => $align,
       bgcolor => $bgcolor,
       title => $title,
    };
    my $a = $self->{ colSpecs };
    push( @$a, $h );
}

############################################################################
# getSdDelim - Get sort value and display value delimiter.
#    Values used for sorting, may potentially be different from
#    display values, esp. if the latter has HTML formatting or
#    is part of a URL link.
############################################################################
sub getSdDelim {
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
   push( @$rows, $row );
}

############################################################################
# printColHeader - Print column header.
############################################################################
sub printColHeader {
   my( $self ) = @_;
   my $colSpecs = $self->{ colSpecs };
   my $baseUrl = $self->{ baseUrl };
   my $idx = 0;
   for my $colSpec( @$colSpecs ) {
      my $displayColName = $colSpec->{ displayColName };
      my $sortSpec = $colSpec->{ sortSpec };
      my $title = $colSpec->{ title };
      my $bgcolor = $colSpec->{ bgcolor };
      my $url = $baseUrl;
      $url .= "&sortColIdx=$idx";
      print "<th class='img' >\n";
      if( $sortSpec ne "" ) {
	 my $tt;
	 $tt = " title='$title' " if $title ne "";
	 my $bg = " bgcolor='$bgcolor' " if $bgcolor ne "";
         print "<a href='$url' $tt $bg>$displayColName</a>\n";
      }
      else {
         print "$displayColName";
      }
      print "</th>\n";
      $idx++;
   }
}

############################################################################
# sortRows - Sort row based on sortColIdx for sort specification.
#  Currently only works for one sort direction.
#  Inputs:
#     sortColIdx - Sort column index.
#  Output
#     rowIndexes_ref - Sort with row indexes returned.
############################################################################
sub sortRows {
    my( $self, $sortColIdx, $rowIndexes_ref ) = @_;
    my $colSpecs = $self->{ colSpecs };
    my $colSpec = $colSpecs->[  $sortColIdx ];
    my $sortSpec = $colSpec->{ sortSpec };
    my $rows = $self->{ rows };

    my @colSpecs2 = split( /,/, $sortSpec );
    my @colSpecs3;
    my $sortDir;
    my $sortType;
    for my $cs( @colSpecs2 ) {
       $cs =~ s/\^\s+//;
       $cs =~ s/\s+$//;
       $cs =~ s/\s+/ /g;
       my( $type, $dir ) = split( / /, $cs );
       my(  $type2, $len ) = split( /\(/, $type );
       $len =~ s/[\(\)]//g;
       my $h = {
	  type => $type,
	  len => $len,
	  dir => $dir,
       };
       push( @colSpecs3, $h );
       $sortDir = $dir if $sortDir eq "";
       $sortType = $type if $sortType eq "";
    }
    my @a;
    my $rowIdx = 0;
    for my $row( @$rows ) {
       my( @vals ) = split( /\t/, $row );
       my $val = $vals[ $sortColIdx ];
       my( $sortVal, $displayVal ) = split( $sdDelim, $val );
       my $s = "$sortVal\t";
       $s .= "$rowIdx";
       push( @a, $s );
       $rowIdx++;
    }
    my @res;
    if( $sortDir eq "desc" ) {
       if( $sortType =~ /^number/ || $sortType =~ /^exponential/ ) {
          @res = reverse( sort{ $a <=> $b }( @a ) );
       }
       else {
          @res = reverse( sort( @a ) );
       }
    }
    else {
       if( $sortType =~ /^number/ || $sortType =~ /^exponential/ ) {
           @res = sort{ $a <=> $b }( @a );
       }
       else {
           @res = sort( @a );
       }
    }
    for my $i( @res ) {
       my( @fields ) = split( /\t/, $i );
       my $nFields = @fields;
       my $rowIdx = $fields[ $nFields - 1 ];
       push( @$rowIndexes_ref, $rowIdx );
    }
}

############################################################################
# printTable - Print table out.
############################################################################
sub printTable {
    my( $self ) = @_;

    my $sortColIdx = WebUtil::param( "sortColIdx" );
    my $colorMap_ref = $self->{ colorMap };
    my @rowIndexes;

    if( $sortColIdx ne "" ) {
       sortRows( $self, $sortColIdx, \@rowIndexes );
    }
    else {
       my $rows = $self->{ rows };
       my $nRows = @$rows;
       for( my $i = 0; $i < $nRows; $i++ ) {
          push( @rowIndexes, $i );
       }
    }
    my $colSpecs = $self->{ colSpecs };
    my $rows = $self->{ rows };
    my $nColSpecs = @$colSpecs;
    if( $nColSpecs == 0 ) {
       printStatusLine( "Error.", 2 );
       webError( "Your session has expired. Please start over again." );
    }

    print "<table class='img'  border='1'>\n";
    printColHeader( $self );
    my $count = 0;
    for my $i( @rowIndexes ) {
	$count++;
	my $rowClass = "img";
	#$rowClass = "highlight" if $count % 2 == 0;
        my $row = $rows->[ $i ];
        print "<tr class='$rowClass' >\n";
	my @vals = split( /\t/, $row );
	my $nVals = @vals;
	for( my $i = 0; $i < $nVals; $i++ ) {
	   my $colSpec = $colSpecs->[ $i ];
	   my $align = $colSpec->{ align };
	   my $useColorMap = $colSpec->{ useColorMap };
	   my $val = $vals[ $i ];
	   my( $sortVal, $displayVal ) = split( $sdDelim, $val );
	   $displayVal = WebUtil::escHtml( $sortVal ) if $displayVal eq "";
	   my $bgcolor;
	   if( $useColorMap && defined( $colorMap_ref ) ) {
	      for my $colorSpec( @$colorMap_ref ) {
	         my( $ge, $lt, $color ) = split( /:/, $colorSpec );
		 if( $sortVal >= $ge && $sortVal < $lt && $color ne "" ) {
		    $bgcolor = " bgcolor='$color' ";
		    last;
		 }
	      }
	   }
	   print "<td class='img' align='$align' $bgcolor>$displayVal</td>\n";
	}
        print "</tr>\n";
    }
    print "</table>\n";
}

1;
