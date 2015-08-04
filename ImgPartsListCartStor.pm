############################################################################
# ImgPartsListCartStor - IMG parts list cart persistent storage.
#  Record fields (tab delimited separator):
#     0: parts_list_oid (padded)
#     1: parts_list_name
#     2: batch_id
#    --imachen 03/20/2007
############################################################################
package ImgPartsListCartStor;
my $section = "ImgPartsListCartStor";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
#my $use_func_cart = $env->{ use_func_cart };
my $use_func_cart = 1;

my $verbose = $env->{ verbose };

my $max_partsList_batch = 250;
my $max_taxon_batch = 900;
my $maxProfileOccurIds = 300;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "imgPartsListCart" || 
           paramMatch( "index" ) ne "" ||
           paramMatch( "addToImgPartsListCart" ) ne "" ||
           paramMatch( "deleteSelectedCartImgPartsLists" ) ne "" ||
           paramMatch( "transferFunctionCart" ) ne "" ) {
       setSessionParam( "lastCart", "imgPartsListCart" );
       my $itc = new ImgPartsListCartStor( );
       if( paramMatch( "transferFunctionCart" ) ne "" ) {
           $itc->transferFunctionCart( )
       }
       elsif( paramMatch( "deleteSelectedCartImgPartsLists" ) ne "" ) {
           $itc->webRemoveImgPartsLists( )
       }
       my $load;
       $load = "add" if paramMatch( "addToImgPartsListCart" ) ne  "";
       $itc->printImgPartsListCartForm( $load );
    }
    elsif( paramMatch( "ImgPartsListDataEntry" ) ne "" ) {
        require ImgPartsListDataEntry;
	ImgPartsListDataEntry::dispatch( );
    }
    else {
        webLog( "ImgPartsListCartStor::dispatch: unkonwn page='$page'\n" );
        warn( "ImgPartsListCartStor::dispatch: unkonwn page='$page'\n" );
    }
}

############################################################################
# new - New instance.
############################################################################
sub new {
   my( $myType, $baseUrl ) = @_;

   $baseUrl = "$section_cgi&page=imgPartsListCart" if $baseUrl eq "";
   my $self = { };
   bless( $self, $myType );
   my $stateFile = $self->getStateFile( );
   if( -e $stateFile ) {
      $self = retrieve( $stateFile );
   }
   else {
      my %h1;
      my %h2;
      $self->{ recs } = \%h1;
      $self->{ selected } = \%h2;
      $self->{ baseUrl } = $baseUrl;
      $self->save( );
   }


   bless( $self, $myType );
   return $self;
}

############################################################################
# transferFunctionCart - Transfer information from function cart.
#   We transfer to IMG partsList cart mainly for internal data entry tools.
#   This is not the best way to do it, but for now, for backwards
#   compatability, it will have to do.
############################################################################
sub transferFunctionCart {
    my( $self ) = @_;

    require FuncCartStor;
    my $fc = new FuncCartStor( );

    my $recs = $fc->{ recs };
    my @keys = sort( keys( %$recs ) );
    my %recs2;
    my %selected;
    for my $i( @keys ) {
        next if $i !~ /PLIST/;
	my $r = $recs->{ $i };
	my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	$i =~ s/^PLIST://;
	$recs2{ $i } = "$i\t$func_name\t$batch_id";
	$selected{ $i } = 1;
    }
    $self->{ recs } = \%recs2;
    $self->{ selected } = \%selected;
}

############################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
   my( $self ) = @_;
   my $sessionId = getSessionId( );
   my $sessionFile = "$cgi_tmp_dir/imgPartsListCart.$sessionId.stor";
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my( $self ) = @_;
   store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# webAddImgPartsLists - Load IMG partsList cart from selections.
############################################################################
sub webAddImgPartsLists {
    my( $self ) = @_;
    my @parts_list_oids = param( "parts_list_oid" );
    $self->addImgPartsListBatch( \@parts_list_oids );
}

############################################################################
# addImgPartsListBatch - Add genes in a batch.
############################################################################
sub addImgPartsListBatch {
    my( $self, $parts_list_oids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "imgPartsList" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $parts_list_oid( @$parts_list_oids_ref ) {
       if( scalar( @batch ) > $max_partsList_batch ) {
          $self->flushImgPartsListBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $parts_list_oid );
       $selected->{ $parts_list_oid } = 1;
    }
    $self->flushImgPartsListBatch( $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushImgPartsListBatch  - Flush one batch.
############################################################################
sub flushImgPartsListBatch {
    my( $self, $dbh, $parts_list_oids_ref, $batch_id ) = @_;

    return if( scalar( @$parts_list_oids_ref ) == 0 ); 
    my $parts_list_oid_str = join( ',', @$parts_list_oids_ref );

    my $recs = $self->{ recs };

    my $sql = qq{
        select ipl.parts_list_oid, ipl.parts_list_name
	from img_parts_list ipl
	where ipl.parts_list_oid in( $parts_list_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
       my( $parts_list_oid, $parts_list_name ) = $cur->fetchrow( );
       last  if !$parts_list_oid;
       $parts_list_oid = FuncUtil::partsListOidPadded( $parts_list_oid );
       $count++;
       my $r = "$parts_list_oid\t";
       $r .= "$parts_list_name\t";
       $r .= "$batch_id\t";
       $recs->{ $parts_list_oid } = $r;
    }
}

############################################################################
# webRemoveImgPartsLists - Remove IMG partsLists.
############################################################################
sub webRemoveImgPartsLists {
   my( $self ) = @_;
   my @parts_list_oids = param( "parts_list_oid" );
   my $recs = $self->{ recs };
   my $selected = $self->{ selected };
   for my $parts_list_oid( @parts_list_oids ) {
      delete $recs->{ $parts_list_oid };
      delete $selected->{ $parts_list_oid };
   }
   $self->save( );
}

############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
   my( $self ) = @_;
   my @parts_list_oids = param( "parts_list_oid" );
   $self->{ selected } = { };
   my $selected = $self->{ selected };
   for my $parts_list_oid( @parts_list_oids ) {
      $selected->{ $parts_list_oid } = 1;
   }
   $self->save( );
}


############################################################################
# prinImgPartsListCartForm - Print IMG PartsList
#  cart form with list of genes and operations
#  that can be done on them.  
############################################################################
sub printImgPartsListCartForm {
    my( $self, $load ) = @_;

    if( $load eq "add" ) {
       printStatusLine( "Loading ...", 1 );
       $self->webAddImgPartsLists( );
    }
    my $dbh = dbLogin( );
    my $contact_oid = getContactOid( );

    setSessionParam( "lastCart", "imgPartsListCart" );
    printMainForm( );
    print "<h1>IMG Parts List Cart</h1>\n";

    my $name = "_section_${section}_transferFunctionCart";
    print submit( -name => $name, -value => "Copy from Function Cart",
       -class => "medbutton" );

    my $recs = $self->{ recs };
    my @parts_list_oids = sort( keys( %$recs ) );
    my $count = @parts_list_oids;
    if( $count == 0 ) {
       print "<p>\n";
       print "0 partsLists in IMG PartsList cart.\n";
       print "</p>\n";
       printStatusLine( "0 partsLists in cart", 2 );
    }

    my $imgEditor = isImgEditor( $dbh, $contact_oid );

    if( $imgEditor ) {
	print "<h2>IMG Parts List Curation</h2>\n";
	print "<p>\n";
	print "Add, delete, and edit IMG parts list.<br/>\n";
	print "</p>\n";
        my $name = "_section_ImgPartsListDataEntry_index";
	print submit( -name => $name,
	   -value => "IMG Parts List Curation", -class => "medbutton " );
	print "<br/>\n";

        print "<h2>Upload IMG Parts List - ";
	print "IMG Term Associations from a File</h2>\n";
	my $name = "_section_ImgPartsListDataEntry_fileUploadPListTermForm";
	print submit( -name => $name, -value => "File Upload",
		      -class => "medbutton" );
        print "<br/>\n";
    }

    print "<p>\n";
    print "$count partsList(s) in cart\n";
    print "</p>\n";


    if( $count > 0 ) {
        my $name = "_section_${section}_deleteSelectedCartImgPartsLists";
        print submit( -name => $name,
           -value => "Remove Selected", -class => 'smdefbutton' );
        print " ";
        print "<input type='button' name='selectAll' value='Select All' " .
            "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
        print "<input type='button' name='clearAll' value='Clear All' " .
            "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    
        print "<table class='img' border='1'>\n";
        print "<th class='img'>Selection</th>\n";
        $self->printSortHeaderLink( "Parts List<br/>Object<br/>ID", 0 );
        $self->printSortHeaderLink( "Parts List Name", 1 );
        $self->printSortHeaderLink( "Batch<sup>1</sup>", 2 );
        my @sortedRecs;
        my $sortIdx = param( "sortIdx" );
        $sortIdx = 2 if $sortIdx eq "";
        $self->sortedRecsArray( $sortIdx, \@sortedRecs );
        my $selected = $self->{ selected };
        for my $r( @sortedRecs ) {
           my( $parts_list_oid, $partsList,  $batch_id ) = split( /\t/, $r );
           $parts_list_oid = FuncUtil::partsListOidPadded( $parts_list_oid );
           print "<tr class='img'>\n";
           print "<td class='checkbox'>\n";
           my $ck;
           $ck = "checked" if $selected->{ $parts_list_oid } ne "";
           print "<input type='checkbox' name='parts_list_oid' " . 
              "value='$parts_list_oid' $ck />\n";
           print "</td>\n";
           my $url = "$main_cgi?section=ImgPartsListBrowser" . 
              "&page=partsListDetail&parts_list_oid=$parts_list_oid";
           print "<td class='img'>" . 
	      alink( $url, $parts_list_oid ) . "</td>\n";
           print "<td class='img'>" . escHtml( $partsList ) . "</td>\n";
           print "<td class='img'>$batch_id</td>\n";
           print "</tr>\n";
        }
        print "</table>\n";
        print "<p>\n";
        print "1 - Each time a set of parts list is added to the cart, " .
          "a new distinguishing batch number is generated for the set.<br/>\n";
        print "</p>\n";
    }
    printStatusLine( "$count parts list(s) in cart", 2 );

    print end_form( );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
   my( $self, $name, $sortIdx ) = @_;

   my $baseUrl = $self->{ baseUrl };
   my $url = $baseUrl;
   $url .= "&sortIdx=$sortIdx";
   print "<th class='img'>";
   print alink( $url, $name, "", 1 );
   print "</th>\n";
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my( $self, $sortIdx, $outRecs_ref ) = @_;
    my $recs = $self->{ recs };
    my @parts_list_oids = keys( %$recs );
    my @a;
    my @idxVals;
    for my $parts_list_oid( @parts_list_oids ) {
       my $rec = $recs->{ $parts_list_oid };
       my @fields = split( /\t/, $rec );
       my $sortRec;
       my $sortFieldVal = $fields[ $sortIdx ];
       if( $sortIdx == 0 || $sortIdx == 2 ) {
          $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $parts_list_oid );
       }
       else {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $parts_list_oid );
       }
       push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort( @idxVals );
    for my $i( @idxValsSorted ) {
       my( $idxVal, $parts_list_oid ) = split( /\t/, $i );
       my $r = $recs->{ $parts_list_oid };
       push( @$outRecs_ref, $r );
    }
}

1;

