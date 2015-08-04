############################################################################
# ImgTermCartStor - IMG term cart persistent storage.
#  Record fields (tab delimited separator):
#     0: term_oid (padded)
#     1: term
#     2: batch_id
#    --es 04/04/2006
############################################################################
package ImgTermCartStor;
my $section = "ImgTermCartStor";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use OracleUtil;
use GenomeListFilter;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
#my $use_func_cart = $env->{ use_func_cart };
my $use_func_cart = 1;

my $verbose = $env->{ verbose };

my $max_term_batch = 250;
my $max_taxon_batch = 900;
my $maxProfileOccurIds = 300;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "imgTermCart" || paramMatch( "addToImgTermCart" ) ne "" ||
           paramMatch( "deleteSelectedCartImgTerms" ) ne "" ||
           paramMatch( "transferFunctionCart" ) ne "" ) {
       setSessionParam( "lastCart", "imgTermCart" );
       my $itc = new ImgTermCartStor( );
       if( paramMatch( "transferFunctionCart" ) ne "" ) {
           $itc->transferFunctionCart( )
       }
       elsif( paramMatch( "deleteSelectedCartImgTerms" ) ne "" ) {
           $itc->webRemoveImgTerms( )
       }
       my $load;
       $load = "add" if paramMatch( "addToImgTermCart" ) ne  "";
       $itc->printImgTermCartForm( $load );
    }
    elsif( paramMatch( "showImgTermCartProfile_s" ) ne "" ) {
       my $itc = new ImgTermCartStor( );
       $itc->printImgTermCartProfile_s( );
    }
    elsif( paramMatch( "showImgTermCartProfile_t" ) ne "" ) {
       my $itc = new ImgTermCartStor( );
       $itc->printImgTermCartProfile_t( );
    }
    elsif( paramMatch( "imgTermOccurProfiles" ) ne "" ) {
        printPhyloOccurProfiles( );
    }
    else {
        webLog( "ImgTermCartStor::dispatch: unkonwn page='$page'\n" );
        warn( "ImgTermCartStor::dispatch: unkonwn page='$page'\n" );
    }
}

############################################################################
# new - New instance.
############################################################################
sub new {
   my( $myType, $baseUrl ) = @_;

   $baseUrl = "$section_cgi&page=imgTermCart" if $baseUrl eq "";
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
#   We transfer to IMG term cart mainly for internal data entry tools.
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
        next if $i !~ /ITERM/;
	my $r = $recs->{ $i };
	my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	$i =~ s/^ITERM://;
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
   my $sessionFile = "$cgi_tmp_dir/imgTermCart.$sessionId.stor";
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my( $self ) = @_;
   store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# webAddImgTerms - Load IMG term cart from selections.
############################################################################
sub webAddImgTerms {
    my( $self ) = @_;
    my @term_oids = param( "term_oid" );
    $self->addImgTermBatch( \@term_oids );
}

############################################################################
# addImgTermBatch - Add genes in a batch.
############################################################################
sub addImgTermBatch {
    my( $self, $term_oids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "imgTerm" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $term_oid( @$term_oids_ref ) {
       if( scalar( @batch ) > $max_term_batch ) {
          $self->flushImgTermBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $term_oid );
       $selected->{ $term_oid } = 1;
    }
    $self->flushImgTermBatch( $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushImgTermBatch  - Flush one batch.
############################################################################
sub flushImgTermBatch {
    my( $self, $dbh, $term_oids_ref, $batch_id ) = @_;

    return if( scalar( @$term_oids_ref ) == 0 ); 
    my $term_oid_str = join( ',', @$term_oids_ref );

    my $recs = $self->{ recs };

    my $sql = qq{
        select it.term_oid, it.term
	from img_term it
	where it.term_oid in( $term_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
       my( $term_oid, $term ) = $cur->fetchrow( );
       last  if !$term_oid;
       $term_oid = FuncUtil::termOidPadded( $term_oid );
       $count++;
       my $r = "$term_oid\t";
       $r .= "$term\t";
       $r .= "$batch_id\t";
       $recs->{ $term_oid } = $r;
    }
}

############################################################################
# webRemoveImgTerms - Remove IMG terms.
############################################################################
sub webRemoveImgTerms {
   my( $self ) = @_;
   my @term_oids = param( "term_oid" );
   my $recs = $self->{ recs };
   my $selected = $self->{ selected };
   for my $term_oid( @term_oids ) {
      delete $recs->{ $term_oid };
      delete $selected->{ $term_oid };
   }
   $self->save( );
}

############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
   my( $self ) = @_;
   my @term_oids = param( "term_oid" );
   $self->{ selected } = { };
   my $selected = $self->{ selected };
   for my $term_oid( @term_oids ) {
      $selected->{ $term_oid } = 1;
   }
   $self->save( );
}


############################################################################
# prinImgTermCartForm - Print IMG Term
#  cart form with list of genes and operations
#  that can be done on them.  
############################################################################
sub printImgTermCartForm {
    my( $self, $load ) = @_;

    if( $load eq "add" ) {
       printStatusLine( "Loading ...", 1 );
       $self->webAddImgTerms( );
    }
    my $dbh = dbLogin( );
    my $contact_oid = getContactOid( );

    setSessionParam( "lastCart", "imgTermCart" );
    printMainForm( );
    print "<h1>IMG Term Cart</h1>\n";

    my $name = "_section_${section}_transferFunctionCart";
    print submit( -name => $name, -value => "Copy from Function Cart",
       -class => "medbutton" );

    my $recs = $self->{ recs };
    my @term_oids = sort( keys( %$recs ) );
    my $count = @term_oids;
    if( $count == 0 ) {
       print "<p>\n";
       print "0 terms in IMG Term cart.\n";
       print "</p>\n";
       printStatusLine( "0 terms in cart", 2 );
    }

    my $imgEditor = isImgEditor( $dbh, $contact_oid );
    
    if( $imgEditor ) {
	print "<h2>IMG Term Curation</h2>\n";
	print "<p>\n";
	print "Add, delete, and edit IMG terms.<br/>\n";
	print "</p>\n";
        my $name = "_section_ImgTermCartDataEntry_index";
	print submit( -name => $name,
	   -value => "IMG Term Curation", -class => "medbutton " );
	print "<br/>\n";
    }

    print "<p>\n";
    print "$count term(s) in cart\n";
    print "</p>\n";


    if( $count > 0 ) {
        my $name = "_section_${section}_deleteSelectedCartImgTerms";
        print submit( -name => $name,
           -value => "Remove Selected", -class => 'smdefbutton' );
        print " ";
        print "<input type='button' name='selectAll' value='Select All' " .
            "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
        print "<input type='button' name='clearAll' value='Clear All' " .
            "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    
        print "<table class='img' border='1'>\n";
        print "<th class='img'>Selection</th>\n";
        $self->printSortHeaderLink( "Term<br/>Object<br/>ID", 0 );
        $self->printSortHeaderLink( "Term", 1 );
        $self->printSortHeaderLink( "Batch<sup>1</sup>", 2 );
        my @sortedRecs;
        my $sortIdx = param( "sortIdx" );
        $sortIdx = 2 if $sortIdx eq "";
        $self->sortedRecsArray( $sortIdx, \@sortedRecs );
        my $selected = $self->{ selected };
        for my $r( @sortedRecs ) {
           my( $term_oid, $term,  $batch_id ) = split( /\t/, $r );
           $term_oid = FuncUtil::termOidPadded( $term_oid );
           print "<tr class='img'>\n";
           print "<td class='checkbox'>\n";
           my $ck;
           $ck = "checked" if $selected->{ $term_oid } ne "";
           print "<input type='checkbox' name='term_oid' " . 
              "value='$term_oid' $ck />\n";
           print "</td>\n";
           my $url = "$main_cgi?section=ImgTermBrowser" . 
              "&page=imgTermDetail&term_oid=$term_oid";
           print "<td class='img'>" . alink( $url, $term_oid ) . "</td>\n";
           print "<td class='img'>" . escHtml( $term ) . "</td>\n";
           print "<td class='img'>$batch_id</td>\n";
           print "</tr>\n";
        }
        print "</table>\n";
        print "<p>\n";
        print "1 - Each time a set of terms is added to the cart, " .
          "a new distinguishing batch number is generated for the set.<br/>\n";
        print "</p>\n";
    }
    printStatusLine( "$count term(s) in cart", 2 );

    if( $imgEditor ) {
        print "<h2>Curate IMG Reaction for the Selected Term(s)</h2>\n";
	my $name = "_section_ImgTermCartDataEntry_addTermRxnForm";
	print submit( -name => $name, -value => "Add IMG Reaction",
	   -class => "meddefbutton" );
	print nbsp( 1 );
	my $name = "_section_ImgTermCartDataEntry_deleteTermRxnForm";
	print submit( -name => $name, -value => "Delete IMG Reaction",
	   -class => "medbutton" );
        print "<br/>\n";

        print "<h2>Upload IMG Term - ";
	print "IMG Reaction Associations from a File</h2>\n";
	my $name = "_section_ImgTermCartDataEntry_fileUploadTermRxnForm";
	print submit( -name => $name, -value => "File Upload",
	   -class => "medbutton" );
        print "<br/>\n";
    }
    if( $count == 0 ) {
	#$dbh->disconnect();
	return;
    }

    print "<h2>IMG Term Profile</h2>\n";
    print "<p>\n";
    print "View selected terms against selected genomes.<br/>\n";
    print "Please select at least one genome.<br/>\n";
    print "</p>\n";
    GenomeListFilter::appendGenomeListFilter($dbh, '', 1);

    print hiddenVar( "type", "imgTerm" );
    my $name = "_section_${section}_showImgTermCartProfile_s";
    print submit( 
        -id  => "go1",
        -name => $name,
        -value => "View Terms vs. Genomes", -class => "meddefbutton" ); 
    print nbsp( 1 );
    my $name = "_section_${section}_showImgTermCartProfile_t";
    print submit( 
        -id  => "go2",
        -name => $name,
        -value => "View Genomes vs. Terms", -class => "medbutton" ); 
    print nbsp( 1 );
    print "<input id='reset' type='button' name='clearSelections' value='Reset' class='smbutton' />\n";
    printHint( 
      "- Hold down control key (or command key in the case of the Mac) " .
      "to select multiple genomes.<br/>\n" .
      "- Drag down list to select all genomes.<br/>\n" .
      "- More genome and function selections result in slower query.\n" );

    print "<h2>Occurrence Profiles</h2>\n";
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonList&page=taxonListAlpha";
    my $link = alink( $url, "Genome Browser" );
    print "Show phylogenetic occurrence profile for ";
    print "genomes selected from the $link,<br/>\n";
    print "against currently selected terms.<br/>\n";
    print "</p>\n";
    my $name = "_section_${section}_imgTermOccurProfiles";
    print submit( -name => $name,
       -value => "View Phylogenetic Occurrence Profiles", 
         -class => 'lgbutton' );

    #$dbh->disconnect();
    print end_form( );
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
    my @term_oids = keys( %$recs );
    my @a;
    my @idxVals;
    for my $term_oid( @term_oids ) {
       my $rec = $recs->{ $term_oid };
       my @fields = split( /\t/, $rec );
       my $sortRec;
       my $sortFieldVal = $fields[ $sortIdx ];
       if( $sortIdx == 0 || $sortIdx == 2 ) {
          $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $term_oid );
       }
       else {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $term_oid );
       }
       push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort( @idxVals );
    for my $i( @idxValsSorted ) {
       my( $idxVal, $term_oid ) = split( /\t/, $i );
       my $r = $recs->{ $term_oid };
       push( @$outRecs_ref, $r );
    }
}

############################################################################
# printImgTermCartProfile_s - Show profile for IMG terms in cart.
############################################################################
sub printImgTermCartProfile_s {
    my( $self, $type, $procId, $sortIdx ) = @_;

    $type = param( "type" ) if $type eq "";
    $procId = param( "procId" ) if $procId eq "";
    $sortIdx = param( "sortIdx" ) if $sortIdx eq "";
    my $baseUrl = $self->{ baseUrl };

    print "<h1>IMG Term Profile</h1>\n";

    require PhyloProfile;

    if( $procId ne "" ) {
       my $pp = new PhyloProfile( $type, $procId );
       $pp->printProfile( );
       print "<br/>\n";
       print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
       return;
    }

    my @term_oids = param( "term_oid" );
    if( scalar( @term_oids ) == 0 || 
        scalar( @term_oids ) > $max_term_batch  ) {
       webError( "Please select 1 to $max_term_batch terms." );
    }
    my @taxon_oids = OracleUtil::processTaxonBinOids( "t" );
    my @bin_oids = OracleUtil::processTaxonBinOids( "b" );
    my $nSelections = scalar( @taxon_oids ) + scalar( @bin_oids );
    if( $nSelections == 0 || $nSelections > $max_taxon_batch ) {
       webError( "Please select at least one genome." );
    }
    $self->{ selected } = { };
    my $selected  = $self->{ selected };
    for my $term_oid( @term_oids ) {
       $selected->{ $term_oid } = 1;
    }
    $self->save( );


    my $term_oid_str = join( ',', @term_oids );
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    my $sql = qq{
        select it.term_oid, it.term
	from img_term it
	where it.term_oid in( $term_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %termOid2Name;
    for( ;; ) {
        my( $term_oid, $term ) = $cur->fetchrow( );
	last if !$term_oid;
	$term_oid = FuncUtil::termOidPadded( $term_oid );
	$termOid2Name{ $term_oid } = $term;
    }
    $cur->finish( );

    my @recs;

    ## Taxon selection
    my $taxon_oid_str = join( ',', @taxon_oids );
    if( !blankStr( $taxon_oid_str ) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#        my $sql = qq{
#            select it.term_oid, it.term, g.taxon, count( distinct g.gene_oid )
#            from img_term it, dt_img_term_path tp, gene_img_functions g
#            where g.taxon in( $taxon_oid_str )
#            and g.function = tp.map_term
#            and tp.term_oid = it.term_oid
#            and it.term_oid in( $term_oid_str )
#            $rclause
#            $imgClause
#            group by it.term_oid, it.term, g.taxon
#            order by it.term_oid, it.term, g.taxon
#       };
        my $sql = qq{
            select it.term_oid, it.term, g.taxon, count( distinct g.gene_oid )
    	    from img_term it, gene_img_functions g
    	    where g.taxon in( $taxon_oid_str )
            and g.function = it.term_oid
    	    and it.term_oid in( $term_oid_str )
            $rclause
            $imgClause
    	    group by it.term_oid, it.term, g.taxon
    	    order by it.term_oid, it.term, g.taxon
       };
       my $cur = execSql( $dbh, $sql, $verbose );
       for( ;; ) {
           my( $id, $name, $taxon_oid, $gene_count ) = $cur->fetchrow( );
           last if !$id;
	   $id = FuncUtil::termOidPadded( $id );
           my $r = "$id\t";
           $r .= "$name\t";
           $r .= "$taxon_oid\t";
           $r .= "\t"; # null bin_oid
           $r .= "$gene_count\t";
           push( @recs, $r );
        }
        $cur->finish( );
    }

    ## Bin selection
    my $bin_oid_str = join( ',', @bin_oids );
    if( !blankStr( $bin_oid_str ) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#        my $sql = qq{
#            select it.term_oid, it.term, bs.bin_oid, 
#               count( distinct g.gene_oid )
#    	    from img_term it, dt_img_term_path tp, 
#    	       gene_img_functions g, bin_scaffolds bs
#            where it.term_oid in( $term_oid_str )
#    	    and it.term_oid = tp.term_oid
#    	    and tp.map_term = g.function
#    	    and g.scaffold = bs.scaffold
#    	    and bs.bin_oid in( $bin_oid_str )
#            $rclause
#            $imgClause
#    	    group by it.term_oid, it.term, bs.bin_oid
#    	    order by it.term_oid, it.term, bs.bin_oid
#        };
        my $sql = qq{
            select it.term_oid, it.term, bs.bin_oid, 
               count( distinct g.gene_oid )
            from img_term it,
               gene_img_functions g, bin_scaffolds bs
            where it.term_oid in( $term_oid_str )
            and it.term_oid = g.function
            and g.scaffold = bs.scaffold
            and bs.bin_oid in( $bin_oid_str )
            $rclause
            $imgClause
            group by it.term_oid, it.term, bs.bin_oid
            order by it.term_oid, it.term, bs.bin_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my( $id, $name, $bin_oid, $gene_count ) = $cur->fetchrow( );
            last if !$id;
            my $r = "$id\t";
            $r .= "$name\t";
            $r .= "\t"; # null taxon_oid
            $r .= "$bin_oid\t"; 
            $r .= "$gene_count\t";
            push( @recs, $r );
        }
        $cur->finish( );
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#    my $taxon_cell_sql_template = qq{
#        select distinct g.gene_oid
#    	from dt_img_term_path tp, gene_img_functions g
#    	where g.taxon = __taxon_oid__
#    	and g.function = tp.map_term
#    	and tp.term_oid = __id__
#        $rclause
#        $imgClause
#    };
    my $taxon_cell_sql_template = qq{
        select distinct g.gene_oid
        from gene_img_functions g
        where g.taxon = __taxon_oid__
        and g.function = = __id__
        $rclause
        $imgClause
    };
#    my $bin_cell_sql_template = qq{
#        select distinct g.gene_oid
#        from dt_img_term_path tp, gene_img_functions g, bin_scaffolds bs
#        where g.scaffold = bs.scaffold
#        and bs.bin_oid = __bin_oid__
#        and g.function = tp.map_term
#        and tp.map_term = tp.function
#        and tp.term_oid = __id__
#        $rclause
#        $imgClause
#    };
    my $bin_cell_sql_template = qq{
        select distinct g.gene_oid
    	from gene_img_functions g, bin_scaffolds bs
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
        and g.function = __id__
        $rclause
        $imgClause
    };
    my $url = "$main_cgi?section=PhyloProfile&page=phyloProfile";
    my @colorMap = (
       "1:5:bisque",
       "5:100000:yellow",
    );
    my $sortUrl = "$section_cgi&showImgTermCartProfile_s";
    my $pp = new PhyloProfile( "imgTerm", $$, "Term<br/>Object<br/>ID", "Name",
                               $url, $sortUrl, \@term_oids, \%termOid2Name, 
                               \@taxon_oids, \@bin_oids, '', \@recs, \@colorMap, 
	                           $taxon_cell_sql_template, $bin_cell_sql_template );
    $pp->printProfile( );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save( );
}

############################################################################
# printImgTermCartProfile_t - 
#    Show profile for IMG terms in cart, transposed.
############################################################################
sub printImgTermCartProfile_t {
    my( $self, $type, $procId, $sortIdx ) = @_;

    $type = param( "type" ) if $type eq "";
    $procId = param( "procId" ) if $procId eq "";
    $sortIdx = param( "sortIdx" ) if $sortIdx eq "";

    my $baseUrl = $self->{ baseUrl };

    print "<h1>IMG Term Profile</h1>\n";

    require FuncProfile;

    if( $procId ne "" ) {
       my $fp = new FuncProfile( $type, $procId );
       $fp->printProfile( );
       print "<br/>\n";
       print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
       return;
    }

    my @term_oids = param( "term_oid" );
    if( scalar( @term_oids ) == 0 || 
        scalar( @term_oids ) > $max_term_batch  ) {
       webError( "Please select 1 to $max_term_batch terms." );
    }
    my @taxon_oids = OracleUtil::processTaxonBinOids( "t" );
    my @bin_oids = OracleUtil::processTaxonBinOids( "b" );
    my $nSelections = scalar( @taxon_oids ) + scalar( @bin_oids );
    if( $nSelections == 0 || $nSelections > $max_taxon_batch ) {
       webError( "Please select at least one genome." );
    }
    my @taxon_bin_oids;
    for my $taxon_oid( @taxon_oids ) {
       push( @taxon_bin_oids, "t:$taxon_oid" );
    }
    for my $bin_oid( @bin_oids ) {
       push( @taxon_bin_oids, "b:$bin_oid" );
    }
    $self->{ selected } = { };
    my $selected  = $self->{ selected };
    for my $term_oid( @term_oids ) {
       $selected->{ $term_oid } = 1;
    }
    $self->save( );

    my $term_oid_str = join( ',', @term_oids );
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    my $sql = qq{
        select it.term_oid, it.term
	from img_term it
	where it.term_oid in( $term_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %termOid2Name;
    for( ;; ) {
        my( $term_oid, $term ) = $cur->fetchrow( );
	last if !$term_oid;
	$term_oid = FuncUtil::termOidPadded( $term_oid );
	$termOid2Name{ $term_oid } = $term;
    }
    $cur->finish( );

    my @recs;
    my %taxonBinOid2Name;
    my %taxonBinOid2Domain;

    ## Taxon rows
    my $taxon_oid_str = join( ',', @taxon_oids );
    if( !blankStr( $taxon_oid_str ) ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql = qq{
            select tx.taxon_oid, tx.taxon_display_name, tx.domain
	    from taxon tx
	    where tx.taxon_oid in( $taxon_oid_str )
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my( $taxon_oid, $taxon_display_name, $domain ) = $cur->fetchrow( );
	    last if !$taxon_oid;
	    $taxonBinOid2Name{ "t:$taxon_oid" } = $taxon_display_name;
	    $taxonBinOid2Domain{ "t:$taxon_oid" } = substr( $domain, 0, 1 );
        }
        $cur->finish( );
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
#        my $sql = qq{
#            select tx.taxon_oid, tx.taxon_display_name, 
#                tp.term_oid, count( distinct g.gene_oid )
#            from dt_img_term_path tp,
#               gene_img_functions g, taxon tx
#            where g.taxon in( $taxon_oid_str )
#            and g.taxon = tx.taxon_oid
#            and g.function = tp.map_term
#            $rclause
#            $imgClause
#            group by tx.taxon_display_name, tx.taxon_oid, tp.term_oid
#            order by tx.taxon_display_name, tx.taxon_oid, tp.term_oid
#        };
        my $sql = qq{
            select tx.taxon_oid, tx.taxon_display_name, 
	            g.function, count( distinct g.gene_oid )
    	    from gene_img_functions g, taxon tx
    	    where g.taxon in( $taxon_oid_str )
    	    and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
    	    group by tx.taxon_display_name, tx.taxon_oid, g.function
    	    order by tx.taxon_display_name, tx.taxon_oid, g.function
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
           my( $taxon_oid, $taxon_display_name, $id, $gene_count ) = 
               $cur->fetchrow( );
           last if !$taxon_oid;
	   $id = FuncUtil::termOidPadded( $id );
           my $r = "t:$taxon_oid\t";
           $r .= "$taxon_display_name\t";
           $r .= "$id\t";
           $r .= "$gene_count\t";
           push( @recs, $r );
        }
        $cur->finish( );
    }

    ## Bin rows
    my $bin_oid_str = join( ',', @bin_oids );
    if( !blankStr( $bin_oid_str ) ) {
        my $sql = qq{
            select b.bin_oid, b.display_name, es.display_name
            from bin b, env_sample_gold es
            where bin_oid in( $bin_oid_str )
            and b.env_sample = es.sample_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my( $bin_oid, $bin_display_name, $es_display_name ) = 
	        $cur->fetchrow( );
	    last if !$bin_oid;
	    $taxonBinOid2Name{ "b:$bin_oid" } = 
	       "$bin_display_name ($es_display_name)";
	    $taxonBinOid2Domain{ "b:$bin_oid" } = "b";
        }
        $cur->finish( );

        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#        my $sql = qq{
#            select b.bin_oid, b.display_name,
#               tp.term_oid, count( distinct g.gene_oid )
#            from dt_img_term_path tp, 
#               gene_img_functions g, bin_scaffolds bs, bin b
#            where g.scaffold = bs.scaffold
#            and bs.bin_oid = b.bin_oid
#            and b.bin_oid in( $bin_oid_str )
#            and g.function = tp.map_term
#            $rclause
#            $imgClause
#            group by b.display_name, b.bin_oid, tp.term_oid
#            order by b.display_name, b.bin_oid, tp.term_oid
#        };
        my $sql = qq{
            select b.bin_oid, b.display_name,
	           g.function, count( distinct g.gene_oid )
    	    from gene_img_functions g, bin_scaffolds bs, bin b
    	    where g.scaffold = bs.scaffold
    	    and bs.bin_oid = b.bin_oid
    	    and b.bin_oid in( $bin_oid_str )
            $rclause
            $imgClause
    	    group by b.display_name, b.bin_oid, g.function
    	    order by b.display_name, b.bin_oid, g.function
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
           my( $bin_oid, $bin_display_name, $id, $gene_count ) = 
               $cur->fetchrow( );
           last if !$bin_oid;
           my $r = "b:$bin_oid\t";
           $r .= "$bin_display_name\t";
           $r .= "$id\t";
           $r .= "$gene_count\t";
           push( @recs, $r );
        }
        $cur->finish( );
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

#    my $taxon_cell_sql_template = qq{
#        select distinct g.gene_oid
#    	from gene_img_functions g, dt_img_term_path tp
#    	where g.taxon = __taxon_oid__
#    	and tp.term_oid = __id__
#    	and tp.map_term = g.function
#        $rclause
#        $imgClause
#    };
    my $taxon_cell_sql_template = qq{
        select distinct g.gene_oid
        from gene_img_functions g
        where g.taxon = __taxon_oid__
        and g.function = __id__
        $rclause
        $imgClause
    };

    my $bin_cell_sql_template = qq{
        select distinct g.gene_oid
    	from bin_scaffolds bs, gene_img_functions g
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
    	and g.function = __id__
        $rclause
        $imgClause
    };
    my $url = "$main_cgi?section=FuncProfile&page=funcProfile";
    my @colorMap = (
       "1:5:bisque",
       "5:100000:yellow",
    );
    my $sortUrl = "$section_cgi&showImgTermCartProfile_t";
    my $fp = new FuncProfile( 
        "imgTerm", $$, $url, $sortUrl,
        \@taxon_bin_oids, \%taxonBinOid2Name, \%taxonBinOid2Domain, '',
        \@term_oids, \%termOid2Name, \@recs, \@colorMap, 
	    $taxon_cell_sql_template, $bin_cell_sql_template );
    $fp->printProfile( );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save( );
}

############################################################################
# printPhyloOccurProfiles - Print phylogenetic occurrence profiles.
############################################################################
sub printPhyloOccurProfiles {

     my @term_oids = param( "term_oid" );
     my $nTerms = @term_oids;
     if( $nTerms == 0 ) {
         webError( "Please select at least one term." );
     }
     if( $nTerms > $maxProfileOccurIds ) {
         webError( "Please select no more than $maxProfileOccurIds terms." );
     }
     my $term_oid_str = join( ',', @term_oids );

     printStatusLine( "Loading ...", 1 );
     my $dbh = dbLogin( );

     ### Load ID information
     my $sql = qq{
         select it.term_oid, it.term
         from img_term it
         where tp.term_oid in( $term_oid_str )
     };
     my $sql = qq{
         select it.term_oid, it.term
	 from img_term it
	 where it.term_oid in( $term_oid_str )
     };
     my $cur = execSql( $dbh, $sql, $verbose );
     my @idRecs;
     my %idRecsHash;
     for( ;; ) {
         my( $id, $name ) = $cur->fetchrow( );
	 last if !$id;
	 $id = FuncUtil::termOidPadded( $id );
	 my %taxons;
	 my $rh = {
	    id => $id,
	    name => $name,
	    url => "#",
	    taxonOidHash => \%taxons,
	 };
	 push( @idRecs, $rh );
	 $idRecsHash{ $id } = $rh;
     }
     $cur->finish( );

     ### Load taxonomic hits information
     my $rclause   = WebUtil::urClause('g.taxon');
     my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#     my $sql = qq{
#         select distinct tp.term_oid, g.taxon
#    	 from dt_img_term_path tp, gene_img_functions g
#    	 where tp.term_oid in( $term_oid_str )
#    	 and g.function = tp.map_term
#         $rclause
#         $imgClause
#     };
     my $sql = qq{
         select distinct g.function, g.taxon
         from gene_img_functions g
         where g.function in( $term_oid_str )
         $rclause
         $imgClause
     };
     my $cur = execSql( $dbh, $sql, $verbose );
     for( ;; ) {
         my( $id, $taxon ) = $cur->fetchrow( );
	 last if !$id;
	 $id = FuncUtil::termOidPadded( $id );
	 my $rh = $idRecsHash{ $id };
	 if( !defined( $rh ) ) {
	    webDie( "printPhyloOccurProfiles: cannot find '$id'\n" );
	    #next;
	 }
	 my $taxonOidHash = $rh->{ taxonOidHash };
	 $taxonOidHash->{ $taxon } = 1;
     }
     $cur->finish( );
     #$dbh->disconnect();

     ## Print it out as an alignment.
     require PhyloOccur;
     my $s = "(Profiles are based on instantiation ";
     $s .= "of a term in a genome.\n";
     $s .= "A dot '.' means there are no instantiation.)\n";
     PhyloOccur::printAlignment( '', \@idRecs, $s );

     printStatusLine( "Loaded.", 2 );
}

1;

