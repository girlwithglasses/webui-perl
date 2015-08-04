############################################################################
# CachedTable.pm - Cached table for later sorting.
#  Not be used for table with large numbers of columns.
#  This currently does not work for more than one sort column.
#  This module may be made obsolete with a more AJAX like module
#  called InnerTable.pm which uses an inner.cgi rendering for the
#  table.
#   --es 06/30/2005
#
#  Modified to work with the InnerTable.pm variant that uses YUI Datatables
#  - BSJ 11/16/09
#
# $Id: CachedTable_yui.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package CachedTable;
use strict;
use Data::Dumper;
use Storable;
use WebConfig;
use WebUtil;
use InnerTable;    #InnerTable.pm variant that uses YUI Datatables

my $env = getEnv( );
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $rowsPerPage = 100; # default rows per page

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
#
#  Modified to work with the InnerTable.pm variant that uses YUI Datatables
#  - BSJ 11/16/09
############################################################################

sub new {
   my( $myType, $id, $baseUrl, $colSpecs_ref, $colorMap_ref ) = @_;
   my $self = { };
   bless( $self, $myType );
   $self->{ id } = "$id" . "$$";

   my $stateFile = $self->getStateFile( );
   wunlink( $stateFile );

   if( -e $stateFile ) {
      $self = retrieve( $stateFile );
      $self->{ sortIdx } = 1;
   } else {
      my @colSpec;
      $self->{ baseUrl }      = $baseUrl;
      $self->{ id }           = $id;
      $self->{ startSortIdx } = 1;
      $self->{ sortType }     = "$id";
      $self->{ sortIdx }      = 1;
      $self->{ pageSize }     = $rowsPerPage; # initial page size
      $self->{ colSpec }      = \@colSpec;
      $self->{ hideExport }   = "false";  # show export buttons by default
      $self->{ hideColSel }   = "false";  # show column selector by default
      $self->{ hideFilter }   = "false";  # show filter line by default
      $self->{ hideSelect }   = "false";  # show Select/Deselect Page buttons by default
      $self->{ hidePages }    = 0;        # show pagination by default
      my @rows;
      $self->{ rows }         = \@rows;
      $self->{ colorMap }     = $colorMap_ref;

      $self->save( );
   }

   bless( $self, $myType );
   return $self;

}

# point to same functions in InnerTable
sub getStateFile; *getStateFile = \&InnerTable::getStateFile;
sub save; *save = \&InnerTable::save;

sub addColSpec; *addColSpec = \&InnerTable::addColSpec;
sub getSdDelim; *getSdDelim = \&InnerTable::getSdDelim;
sub addRow; *addRow = \&InnerTable::addRow;
sub printTable; *printTable = \&InnerTable::printTable;
sub printOuterTable; *printOuterTable = \&InnerTable::printOuterTable;

1;
