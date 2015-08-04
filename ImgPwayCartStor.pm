############################################################################
# ImgPwayCartStor - IMG pathway cart persistent storage.
#  Record fields (tab delimited separator):
#     0: pathway_oid (padded)
#     1: pathway_name
#     2: batch_id
#    --es 04/04/2006
############################################################################
package ImgPwayCartStor;
my $section = "ImgPwayCartStor";
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

my $max_pway_batch = 250;
my $max_taxon_batch = 900;
my $maxProfileOccurIds = 300;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "imgPwayCart" || paramMatch( "addToImgPwayCart" ) ne "" ||
           paramMatch( "deleteSelectedCartImgPways" ) ne "" ||
           paramMatch( "transferFunctionCart" ) ne "" ) {
       setSessionParam( "lastCart", "imgPwayCart" );
       my $ipw = new ImgPwayCartStor( );
       if( paramMatch( "deleteSelectedCartImgPways" ) ne "" ) {
           $ipw->webRemoveImgPways( )
       }
       elsif( paramMatch( "transferFunctionCart" ) ne "" ) {
           $ipw->transferFunctionCart( );
       }
       my $load;
       $load = "add" if paramMatch( "addToImgPwayCart" ) ne  "";
       $ipw->printImgPwayCartForm( $load );
    }
    elsif( paramMatch( "showImgPwayCartProfile_s" ) ne "" ) {
       my $ipw = new ImgPwayCartStor( );
       $ipw->printImgPwayCartProfile_s( );
    }
    elsif( paramMatch( "showImgPwayCartProfile_t" ) ne "" ) {
       my $ipw = new ImgPwayCartStor( );
       $ipw->printImgPwayCartProfile_t( );
    }
    elsif( paramMatch( "imgPwayOccurProfiles" ) ne "" ) {
        ImgPwayCartStor::printPhyloOccurProfiles( );
    }
    else {
        webLog( "ImgPwayCartStor::dispatch: invalid page='$page'\n" );
        warn( "ImgPwayCartStor::dispatch: invalid page='$page'\n" );
    }
}

############################################################################
# new - New instance.
############################################################################
sub new {
   my( $myType, $baseUrl ) = @_;

   $baseUrl = "$section_cgi&page=imgPwayCart" if $baseUrl eq "";
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
        next if $i !~ /IPWAY/;
	my $r = $recs->{ $i };
	my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	$i =~ s/^IPWAY://;
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
   my $sessionFile = "$cgi_tmp_dir/imgPwayCart.$sessionId.stor";
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my ( $self ) = @_;
   store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# webAddImgPways - Load IMG pathway cart from selections.
############################################################################
sub webAddImgPways {
    my( $self ) = @_;
    my @pway_oids = param( "pway_oid" );
    $self->addImgPwayBatch( \@pway_oids );
}

############################################################################
# addImgPwayBatch - Add genes in a batch.
############################################################################
sub addImgPwayBatch {
    my( $self, $pway_oids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "imgPway" );

    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $pway_oid( @$pway_oids_ref ) {
       if( scalar( @batch ) > $max_pway_batch ) {
          $self->flushImgPwayBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $pway_oid );
       $selected->{ $pway_oid } = 1;
    }
    $self->flushImgPwayBatch( $dbh, \@batch, $batch_id );
    ##$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushImgPwayBatch  - Flush one batch.
############################################################################
sub flushImgPwayBatch {
    my( $self, $dbh, $pway_oids_ref, $batch_id ) = @_;

    return if( scalar( @$pway_oids_ref ) == 0 ); 
    my $pway_oid_str = join( ',', @$pway_oids_ref );

    my $recs = $self->{ recs };

    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
	from img_pathway ipw
	where ipw.pathway_oid in( $pway_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
       my( $pway_oid, $pway ) = $cur->fetchrow( );
       last  if !$pway_oid;
       $pway_oid = FuncUtil::pwayOidPadded( $pway_oid );
       $count++;
       my $r = "$pway_oid\t";
       $r .= "$pway\t";
       $r .= "$batch_id\t";
       $recs->{ $pway_oid } = $r;
    }
}

############################################################################
# webRemoveImgPways - Remove IMG pathways.
############################################################################
sub webRemoveImgPways {
   my( $self ) = @_;
   my @pway_oids = param( "pway_oid" );
   my $recs = $self->{ recs };
   my $selected = $self->{ selected };
   for my $pway_oid( @pway_oids ) {
      delete $recs->{ $pway_oid };
      delete $selected->{ $pway_oid };
   }
   $self->save( );
}

############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
   my( $self ) = @_;
   my @pway_oids = param( "pway_oid" );
   $self->{ selected } = { };
   my $selected = $self->{ selected };
   for my $pway_oid( @pway_oids ) {
      $selected->{ $pway_oid } = 1;
   }
   $self->save( );
}


############################################################################
# prinImgPwayCartForm - Print IMG pathway.
#  cart form with list of genes and operations
#  that can be done on them.  
############################################################################
sub printImgPwayCartForm {
    my( $self, $load ) = @_;

    if( $load eq "add" ) {
       printStatusLine( "Loading ...", 1 );
       $self->webAddImgPways( );
    }
    my $dbh = dbLogin( );
    my $contact_oid = getContactOid( );

    setSessionParam( "lastCart", "imgPwayCart" );
    printMainForm( );
    print "<h1>IMG Pathway Cart</h1>\n";

    my $name = "_section_${section}_transferFunctionCart";
    print submit( -name => $name, -value => "Copy from Function Cart",
       -class => "medbutton" );

    my $recs = $self->{ recs };
    my @pway_oids = sort( keys( %$recs ) );
    my $count = @pway_oids;
    if( $count == 0 ) {
       print "<p>\n";
       print "0 pathways in IMG Pathway cart.\n";
       print "</p>\n";
       printStatusLine( "0 pathways in cart", 2 );
    }

    if( isImgEditor( $dbh, $contact_oid ) ) {
	print "<h2>IMG Pathway Curation</h2>\n";
	print "<p>\n";
	print "Add, delete, and edit IMG pathways.<br/>\n";
	print "</p>\n";
        my $name = "_section_ImgPwayCartDataEntry_index";
	print submit( -name => $name,
	   -value => "IMG Pathway Curation", -class => "medbutton " );
	print "<br/>\n";

        print "<h2>Upload IMG Pathway - ";
	print "IMG Reaction Associations from a File</h2>\n";
	my $name = "_section_ImgPwayCartDataEntry_fileUploadPwayRxnForm";
	print submit( -name => $name, -value => "File Upload",
		      -class => "medbutton" );
        print "<br/>\n";
    }

    if( $count == 0 ) {
	##$dbh->disconnect();
	return;
    }

    print "<p>\n";
    print "$count pathway(s) in cart\n";
    print "</p>\n";

    my $name = "_section_${section}_deleteSelectedCartImgPways";
    print submit( -name => $name,
       -value => "Remove Selected", -class => 'smdefbutton' );
    print " ";
    print "<input type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print "<input type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Selection</th>\n";
    $self->printSortHeaderLink( "Pathway<br/>Object<br/>ID", 0 );
    $self->printSortHeaderLink( "Pathway Name", 1 );
    $self->printSortHeaderLink( "Batch<sup>1</sup>", 2 );
    my @sortedRecs;
    my $sortIdx = param( "sortIdx" );
    $sortIdx = 2 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{ selected };
    for my $r( @sortedRecs ) {
       my( $pway_oid, $pway,  $batch_id ) = split( /\t/, $r );
       $pway_oid = FuncUtil::pwayOidPadded( $pway_oid );
       print "<tr class='img'>\n";
       print "<td class='checkbox'>\n";
       my $ck;
       $ck = "checked" if $selected->{ $pway_oid } ne "";
       print "<input type='checkbox' name='pway_oid' " . 
          "value='$pway_oid' $ck />\n";
       print "</td>\n";
       my $url = "$main_cgi?section=ImgPwayBrowser" . 
          "&page=imgPwayDetail&pway_oid=$pway_oid";
       print "<td class='img'>" . alink( $url, $pway_oid ) . "</td>\n";
       print "<td class='img'>" . escHtml( $pway ) . "</td>\n";
       print "<td class='img'>$batch_id</td>\n";
       print "</tr>\n";
    }
    print "</table>\n";
    print "<p>\n";
    print "1 - Each time a set of IMG pathway is added to the cart, " .
      "a new distinguishing batch number is generated for the set.<br/>\n";
    print "</p>\n";
    printStatusLine( "$count pathway(s) in cart", 2 );

    print "<h2>IMG Pathway Profile</h2>\n";
    print "<p>\n";
    print "View selected pathways against selected genomes.<br/>\n";
    print "Please select at least one genome.<br/>\n";
    print "</p>\n";
    GenomeListFilter::appendGenomeListFilter($dbh, '', 1);

    print hiddenVar( "type", "imgPway" );
    my $name = "_section_${section}_showImgPwayCartProfile_s";
    print submit(
        -id  => "go1",
        -name => $name,
        -value => "View Pathways vs. Genomes", -class => "meddefbutton" ); 
    print nbsp( 1 );
    my $name = "_section_${section}_showImgPwayCartProfile_t";
    print submit(
        -id  => "go2",
        -name => $name,
        -value => "View Genomes vs. Pathways", -class => "medbutton" ); 
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
    print "against currently selected pathways.<br/>\n";
    print "</p>\n";
    my $name = "_section_${section}_imgPwayOccurProfiles";
    print submit( -name => $name,
       -value => "View Phylogenetic Occurrence Profiles", 
         -class => 'lgbutton' );

    ##$dbh->disconnect();
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
    my @pway_oids = keys( %$recs );
    my @a;
    my @idxVals;
    for my $pway_oid( @pway_oids ) {
       my $rec = $recs->{ $pway_oid };
       my @fields = split( /\t/, $rec );
       my $sortRec;
       my $sortFieldVal = $fields[ $sortIdx ];
       if( $sortIdx == 0 || $sortIdx == 2 ) {
          $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $pway_oid );
       }
       else {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $pway_oid );
       }
       push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort( @idxVals );
    for my $i( @idxValsSorted ) {
       my( $idxVal, $pway_oid ) = split( /\t/, $i );
       my $r = $recs->{ $pway_oid };
       push( @$outRecs_ref, $r );
    }
}

############################################################################
# printImgPwayCartProfile_s - Show profile for IMG pathways in cart.
############################################################################
sub printImgPwayCartProfile_s {
    my( $self, $type, $procId, $sortIdx ) = @_;

    $type = param( "type" ) if $type eq "";
    $procId = param( "procId" ) if $procId eq "";
    $sortIdx = param( "sortIdx" ) if $sortIdx eq "";

    my $baseUrl = $self->{ baseUrl };

    print "<h1>IMG Pathway Profile</h1>\n";

    require PhyloProfile;

    if( $procId ne "" ) {
       my $pp = new PhyloProfile( $type, $procId );
       $pp->printProfile( );
       print "<br/>\n";
       print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
       return;
    }

    my @pway_oids = param( "pway_oid" );
    if( scalar( @pway_oids ) == 0 || 
        scalar( @pway_oids ) > $max_pway_batch  ) {
       webError( "Please select 1 to $max_pway_batch pathways." );
    }
    my @taxon_oids = OracleUtil::processTaxonBinOids( "t" );
    my @bin_oids = OracleUtil::processTaxonBinOids( "b" );
    my $nSelections = scalar( @taxon_oids ) + scalar( @bin_oids );
    if( $nSelections == 0 || $nSelections > $max_taxon_batch ) {
       webError( "Please select at least one genome." );
    }
    $self->{ selected } = { };
    my $selected  = $self->{ selected };
    for my $pway_oid( @pway_oids ) {
       $selected->{ $pway_oid } = 1;
    }
    $self->save( );


    my $pway_oid_str = join( ',', @pway_oids );
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
	from img_pathway ipw
	where ipw.pathway_oid in( $pway_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %pwayOid2Name;
    for( ;; ) {
        my( $pway_oid, $pway ) = $cur->fetchrow( );
	last if !$pway_oid;
	$pway_oid = FuncUtil::pwayOidPadded( $pway_oid );
	$pwayOid2Name{ $pway_oid } = $pway;
    }
    $cur->finish( );

    my @recs;

    ## Taxon selection
    my $taxon_oid_str = join( ',', @taxon_oids );
    if( !blankStr( $taxon_oid_str ) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#        my $sql = qq{
#            select ipw.pathway_oid pathway_oid, 
#                ipw.pathway_name pathway_name, 
#                g.taxon taxon, count( distinct g.gene_oid )
#            from gene_img_functions g,
#              img_reaction_catalysts irc, img_pathway_reactions ipr, 
#              img_pathway ipw, dt_img_term_path ditp
#            where g.taxon in( $taxon_oid_str )
#            and g.function = ditp.map_term
#            and irc.catalysts = ditp.term_oid
#            and irc.rxn_oid = ipr.rxn
#            and ipr.pathway_oid = ipw.pathway_oid
#            and ipw.pathway_oid in( $pway_oid_str )
#            $rclause
#            $imgClause
#            group by ipw.pathway_oid, ipw.pathway_name, g.taxon
#                union
#            select ipw.pathway_oid pathway_oid, 
#                ipw.pathway_name pathway_name, 
#                g.taxon taxon, count( distinct g.gene_oid )
#            from gene_img_functions g,
#              img_reaction_t_components itc, img_pathway_reactions ipr, 
#              img_pathway ipw, dt_img_term_path ditp
#            where g.taxon in( $taxon_oid_str )
#            and g.function = ditp.map_term
#            and itc.term = ditp.term_oid
#            and itc.rxn_oid = ipr.rxn
#            and ipr.pathway_oid = ipw.pathway_oid
#            and ipw.pathway_oid in( $pway_oid_str )
#            $rclause
#            $imgClause
#            group by ipw.pathway_oid, ipw.pathway_name, g.taxon
#            order by pathway_oid, pathway_name, taxon
#       };
        my $sql = qq{
            select ipw.pathway_oid pathway_oid, 
        		ipw.pathway_name pathway_name, 
    	        g.taxon taxon, count( distinct g.gene_oid )
    	    from gene_img_functions g,
    	      img_reaction_catalysts irc, img_pathway_reactions ipr, 
    	      img_pathway ipw
    	    where g.taxon in( $taxon_oid_str )
    	    and g.function = irc.catalysts
    	    and irc.rxn_oid = ipr.rxn
    	    and ipr.pathway_oid = ipw.pathway_oid
    	    and ipw.pathway_oid in( $pway_oid_str )
            $rclause
            $imgClause
    	    group by ipw.pathway_oid, ipw.pathway_name, g.taxon
        		union
            select ipw.pathway_oid pathway_oid, 
        		ipw.pathway_name pathway_name, 
    	        g.taxon taxon, count( distinct g.gene_oid )
    	    from gene_img_functions g,
    	      img_reaction_t_components itc, img_pathway_reactions ipr, 
    	      img_pathway ipw
    	    where g.taxon in( $taxon_oid_str )
    	    and g.function = itc.term
    	    and itc.rxn_oid = ipr.rxn
    	    and ipr.pathway_oid = ipw.pathway_oid
    	    and ipw.pathway_oid in( $pway_oid_str )
            $rclause
            $imgClause
    	    group by ipw.pathway_oid, ipw.pathway_name, g.taxon
    	    order by pathway_oid, pathway_name, taxon
       };
       my $cur = execSql( $dbh, $sql, $verbose );
       for( ;; ) {
           my( $id, $name, $taxon_oid, $gene_count ) = $cur->fetchrow( );
           last if !$id;
	       $id = FuncUtil::pwayOidPadded( $id );
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
#            select ipw.pathway_oid pathway_oid, 
#                ipw.pathway_name pathway_name, 
#                bs.bin_oid bin_oid, count( distinct g.gene_oid )
#            from gene_img_functions g,
#              img_reaction_catalysts irc, img_pathway_reactions ipr, 
#              img_pathway ipw, bin_scaffolds bs, dt_img_term_path ditp
#            where g.scaffold = bs.scaffold
#            and bs.bin_oid in( $bin_oid_str )
#            and g.function = ditp.map_term
#            and irc.catalysts = ditp.term_oid
#            and irc.rxn_oid = ipr.rxn
#            and ipr.pathway_oid = ipw.pathway_oid
#            and ipw.pathway_oid in( $pway_oid_str )
#            $rclause
#            $imgClause
#            group by ipw.pathway_oid, ipw.pathway_name, bs.bin_oid
#            union
#            select ipw.pathway_oid pathway_oid, 
#                ipw.pathway_name pathway_name, 
#                bs.bin_oid bin_oid, count( distinct g.gene_oid )
#            from gene_img_functions g,
#              img_reaction_t_components itc, img_pathway_reactions ipr, 
#              img_pathway ipw, bin_scaffolds bs, dt_img_term_path ditp
#            where g.scaffold = bs.scaffold
#            and bs.bin_oid in( $bin_oid_str )
#            and g.function =  ditp.map_term
#            and itc.term = ditp.term_oid
#            and itc.rxn_oid = ipr.rxn
#            and ipr.pathway_oid = ipw.pathway_oid
#            and ipw.pathway_oid in( $pway_oid_str )
#            $rclause
#            $imgClause
#            group by ipw.pathway_oid, ipw.pathway_name, bs.bin_oid
#            order by pathway_oid, pathway_name, bin_oid
#        };
        my $sql = qq{
            select ipw.pathway_oid pathway_oid, 
                ipw.pathway_name pathway_name, 
                bs.bin_oid bin_oid, count( distinct g.gene_oid )
            from gene_img_functions g,
              img_reaction_catalysts irc, img_pathway_reactions ipr, 
              img_pathway ipw, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid in( $bin_oid_str )
            and g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and ipw.pathway_oid in( $pway_oid_str )
            $rclause
            $imgClause
            group by ipw.pathway_oid, ipw.pathway_name, bs.bin_oid
            union
            select ipw.pathway_oid pathway_oid, 
                ipw.pathway_name pathway_name, 
                bs.bin_oid bin_oid, count( distinct g.gene_oid )
            from gene_img_functions g,
              img_reaction_t_components itc, img_pathway_reactions ipr, 
              img_pathway ipw, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid in( $bin_oid_str )
            and g.function =  itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and ipw.pathway_oid in( $pway_oid_str )
            $rclause
            $imgClause
            group by ipw.pathway_oid, ipw.pathway_name, bs.bin_oid
            order by pathway_oid, pathway_name, bin_oid
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
#        select distinct g.gene_oid gene_oid
#        from gene_img_functions g, 
#           img_reaction_catalysts irc, img_pathway_reactions ipr,
#           dt_img_term_path ditp
#        where g.taxon = __taxon_oid__
#        and g.function = ditp.map_term
#        and irc.catalysts = ditp.term_oid
#        and irc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#        union
#        select distinct g.gene_oid 
#        from gene_img_functions g, 
#           img_reaction_t_components itc, img_pathway_reactions ipr,
#           dt_img_term_path ditp
#        where g.taxon = __taxon_oid__
#        and g.function = ditp.map_term
#        and itc.term = ditp.term_oid
#        and itc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#        order by gene_oid
#    };
    my $taxon_cell_sql_template = qq{
        select distinct g.gene_oid gene_oid
    	from gene_img_functions g, 
    	   img_reaction_catalysts irc, img_pathway_reactions ipr
    	where g.taxon = __taxon_oid__
    	and g.function = irc.catalysts
    	and irc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
	    union
        select distinct g.gene_oid 
    	from gene_img_functions g, 
    	   img_reaction_t_components itc, img_pathway_reactions ipr
    	where g.taxon = __taxon_oid__
    	and g.function = itc.term
    	and itc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
    	order by gene_oid
    };
#    my $bin_cell_sql_template = qq{
#        select distinct g.gene_oid gene_oid
#        from gene_img_functions g, 
#           img_reaction_catalysts irc, img_pathway_reactions ipr,
#           bin_scaffolds bs, dt_img_term_path ditp
#        where g.scaffold = bs.scaffold
#        and bs.bin_oid = __bin_oid__
#        and g.function = ditp.map_term
#        and irc.catalysts = ditp.term_oid
#        and irc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#            union
#        select distinct g.gene_oid
#        from gene_img_functions g, 
#           img_reaction_t_components itc, img_pathway_reactions ipr,
#           bin_scaffolds bs, dt_img_term_path ditp
#        where g.scaffold = bs.scaffold
#        and bs.bin_oid = __bin_oid__
#        and g.function = ditp.map_term
#        and itc.term = ditp.term_oid
#        and itc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#        order by gene_oid
#    };
    my $bin_cell_sql_template = qq{
        select distinct g.gene_oid gene_oid
    	from gene_img_functions g, 
    	   img_reaction_catalysts irc, img_pathway_reactions ipr,
    	   bin_scaffolds bs
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
    	and g.function = irc.catalysts
    	and irc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
    	    union
        select distinct g.gene_oid
    	from gene_img_functions g, 
    	   img_reaction_t_components itc, img_pathway_reactions ipr,
    	   bin_scaffolds bs
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
    	and g.function = itc.term
    	and itc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
    	order by gene_oid
    };
    my $url = "$main_cgi?section=PhyloProfile&page=phyloProfile";
    my @colorMap = (
       "1:5:bisque",
       "5:100000:yellow",
    );
    my $sortUrl = "$section_cgi&showImgPwayCartProfile_s";
    my $pp = new PhyloProfile( "imgPway", $$, "Pway<br/>Object<br/>ID", "Name",
                               $url, $sortUrl, \@pway_oids, \%pwayOid2Name, 
                               \@taxon_oids, \@bin_oids, '', \@recs, \@colorMap, 
	                           $taxon_cell_sql_template, $bin_cell_sql_template );
    $pp->printProfile( );

    ##$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save( );
}

############################################################################
# printImgPwayCartProfile_t - 
#    Show profile for IMG pathways in cart, transposed.
############################################################################
sub printImgPwayCartProfile_t {
    my( $self, $type, $procId, $sortIdx ) = @_;

    $type = param( "type" ) if $type eq "";
    $procId = param( "procId" ) if $procId eq "";
    $sortIdx = param( "sortIdx" ) if $sortIdx eq "";
    my $baseUrl = $self->{ baseUrl };

    print "<h1>IMG Pathway Profile</h1>\n";

    require FuncProfile;

    if( $procId ne "" ) {
       my $fp = new FuncProfile( $type, $procId );
       $fp->printProfile( );
       print "<br/>\n";
       print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
       return;
    }

    my @pway_oids = param( "pway_oid" );
    if( scalar( @pway_oids ) == 0 || 
        scalar( @pway_oids ) > $max_pway_batch  ) {
       webError( "Please select 1 to $max_pway_batch pathways." );
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
    for my $pway_oid( @pway_oids ) {
       $selected->{ $pway_oid } = 1;
    }
    $self->save( );

    my $pway_oid_str = join( ',', @pway_oids );
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
	from img_pathway ipw
	where ipw.pathway_oid in( $pway_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %pwayOid2Name;
    for( ;; ) {
        my( $pway_oid, $pway ) = $cur->fetchrow( );
	last if !$pway_oid;
	$pway_oid = FuncUtil::pwayOidPadded( $pway_oid );
	$pwayOid2Name{ $pway_oid } = $pway;
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
	    $rclause
	    $imgClause
	    where tx.taxon_oid in( $taxon_oid_str )
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
#            select tx.taxon_oid taxon_oid, 
#             tx.taxon_display_name taxon_display_name,
#             ipr.pathway_oid pathway_oid, count( distinct g.gene_oid )
#            from gene_img_functions g, taxon tx,
#              img_reaction_catalysts irc, img_pathway_reactions ipr,
#              dt_img_term_path ditp
#            where g.taxon in( $taxon_oid_str )
#            and g.taxon = tx.taxon_oid
#            and g.function = ditp.map_term
#            and irc.catalysts = ditp.term_oid
#            and irc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#            group by tx.taxon_display_name, tx.taxon_oid, ipr.pathway_oid
#            union
#            select tx.taxon_oid taxon_oid, 
#               tx.taxon_display_name taxon_display_name, 
#               ipr.pathway_oid pathway_oid, count( distinct g.gene_oid )
#            from gene_img_functions g, taxon tx,
#              img_reaction_t_components itc, img_pathway_reactions ipr,
#              dt_img_term_path ditp
#            where g.taxon in( $taxon_oid_str )
#            and g.taxon = tx.taxon_oid
#            and g.function = ditp.map_term
#            and itc.term = ditp.term_oid
#            and itc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#            group by tx.taxon_display_name, tx.taxon_oid, ipr.pathway_oid
#            order by taxon_display_name, taxon_oid, pathway_oid
#        };
        my $sql = qq{
            select tx.taxon_oid taxon_oid, 
	         tx.taxon_display_name taxon_display_name,
	         ipr.pathway_oid pathway_oid, count( distinct g.gene_oid )
    	    from gene_img_functions g, taxon tx,
    	      img_reaction_catalysts irc, img_pathway_reactions ipr
    	    where g.taxon in( $taxon_oid_str )
    	    and g.taxon = tx.taxon_oid
    	    and g.function = irc.catalysts
    	    and irc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
    	    group by tx.taxon_display_name, tx.taxon_oid, ipr.pathway_oid
    		union
            select tx.taxon_oid taxon_oid, 
    	       tx.taxon_display_name taxon_display_name, 
    	       ipr.pathway_oid pathway_oid, count( distinct g.gene_oid )
    	    from gene_img_functions g, taxon tx,
    	      img_reaction_t_components itc, img_pathway_reactions ipr
    	    where g.taxon in( $taxon_oid_str )
    	    and g.taxon = tx.taxon_oid
    	    and g.function = itc.term
    	    and itc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
    	    group by tx.taxon_display_name, tx.taxon_oid, ipr.pathway_oid
    	    order by taxon_display_name, taxon_oid, pathway_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
           my( $taxon_oid, $taxon_display_name, $id, $gene_count ) = 
               $cur->fetchrow( );
           last if !$taxon_oid;
	       $id = FuncUtil::pwayOidPadded( $id );
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
#            select b.bin_oid bin_oid, b.display_name display_name,
#               g.function function, count( distinct g.gene_oid )
#            from gene_img_functions g, bin_scaffolds bs, bin b,
#               img_reaction_catalysts irc, img_pathway_reactions ipr,
#               dt_img_term_path ditp
#            where g.scaffold = bs.scaffold
#            and bs.bin_oid = b.bin_oid
#            and b.bin_oid in( $bin_oid_str )
#            and g.function = ditp.map_term
#            and irc.catalysts = ditp.term_oid
#            and irc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#            group by b.display_name, b.bin_oid, g.function
#            union
#            select b.bin_oid bin_oid, b.display_name display_name,
#               g.function function, count( distinct g.gene_oid )
#            from gene_img_functions g, bin_scaffolds bs, bin b,
#               img_reaction_t_components itc, img_pathway_reactions ipr,
#               dt_img_term_path ditp
#            where g.scaffold = bs.scaffold
#            and bs.bin_oid = b.bin_oid
#            and b.bin_oid in( $bin_oid_str )
#            and g.function = ditp.map_term
#            and itc.term = ditp.term_oid
#            and itc.rxn_oid = ipr.rxn
#            $rclause
#            $imgClause
#            group by b.display_name, b.bin_oid, g.function
#            order by display_name, bin_oid, function
#        };
        my $sql = qq{
            select b.bin_oid bin_oid, b.display_name display_name,
    	       g.function function, count( distinct g.gene_oid )
    	    from gene_img_functions g, bin_scaffolds bs, bin b,
    	       img_reaction_catalysts irc, img_pathway_reactions ipr
    	    where g.scaffold = bs.scaffold
    	    and bs.bin_oid = b.bin_oid
    	    and b.bin_oid in( $bin_oid_str )
    	    and g.function = irc.catalysts
    	    and irc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
    	    group by b.display_name, b.bin_oid, g.function
    		union
            select b.bin_oid bin_oid, b.display_name display_name,
    	       g.function function, count( distinct g.gene_oid )
    	    from gene_img_functions g, bin_scaffolds bs, bin b,
    	       img_reaction_t_components itc, img_pathway_reactions ipr
    	    where g.scaffold = bs.scaffold
    	    and bs.bin_oid = b.bin_oid
    	    and b.bin_oid in( $bin_oid_str )
    	    and g.function = itc.term
    	    and itc.rxn_oid = ipr.rxn
            $rclause
            $imgClause
    	    group by b.display_name, b.bin_oid, g.function
    	    order by display_name, bin_oid, function
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

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
#    my $taxon_cell_sql_template = qq{
#        select distinct g.gene_oid gene_oid
#    	from taxon tx, gene_img_functions g,
#    	  img_reaction_catalysts irc, img_pathway_reactions ipr,
#    	  dt_img_term_path ditp
#    	where g.taxon = __taxon_oid__
#    	and g.function = ditp.map_term
#    	and irc.catalysts = ditp.term_oid
#    	and irc.rxn_oid = ipr.rxn
#    	and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#    	    union
#        select distinct g.gene_oid gene_oid
#    	from taxon tx, gene_img_functions g,
#    	  img_reaction_t_components itc, img_pathway_reactions ipr,
#    	  dt_img_term_path ditp
#    	where g.taxon = __taxon_oid__
#    	and g.function = ditp.map_term
#    	and itc.term = ditp.term_oid
#    	and itc.rxn_oid = ipr.rxn
#    	and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#    	order by gene_oid
#    };
    my $taxon_cell_sql_template = qq{
        select distinct g.gene_oid gene_oid
        from taxon tx, gene_img_functions g,
          img_reaction_catalysts irc, img_pathway_reactions ipr,
        where g.taxon = __taxon_oid__
        and g.function = irc.catalysts
        and irc.rxn_oid = ipr.rxn
        and ipr.pathway_oid = __id__
        $rclause
        $imgClause
            union
        select distinct g.gene_oid gene_oid
        from taxon tx, gene_img_functions g,
          img_reaction_t_components itc, img_pathway_reactions ipr
        where g.taxon = __taxon_oid__
        and g.function = itc.term
        and itc.rxn_oid = ipr.rxn
        and ipr.pathway_oid = __id__
        $rclause
        $imgClause
        order by gene_oid
    };

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
#    my $bin_cell_sql_template = qq{
#        select distinct g.gene_oid gene_oid
#        from bin_scaffolds bs, gene_img_functions g,
#          img_reaction_catalysts irc, img_pathway_reactions ipr,
#          dt_img_term_path ditp
#        where g.scaffold = bs.scaffold
#        and bs.bin_oid = __bin_oid__
#        and g.function = ditp.map_term
#        and irc.catalysts = ditp.term_oid
#        and irc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#            union
#        select distinct g.gene_oid gene_oid
#        from bin_scaffolds bs, gene_img_functions g,
#          img_reaction_t_components itc, img_pathway_reactions ipr,
#          dt_img_term_path ditp
#        where g.scaffold = bs.scaffold
#        and bs.bin_oid = __bin_oid__
#        and g.function = ditp.map_term
#        and itc.term = ditp.term_oid
#        and itc.rxn_oid = ipr.rxn
#        and ipr.pathway_oid = __id__
#        $rclause
#        $imgClause
#        order by gene_oid
#    };
    my $bin_cell_sql_template = qq{
        select distinct g.gene_oid gene_oid
    	from bin_scaffolds bs, gene_img_functions g,
    	  img_reaction_catalysts irc, img_pathway_reactions ipr
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
    	and g.function = irc.catalysts
    	and irc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
    	    union
        select distinct g.gene_oid gene_oid
    	from bin_scaffolds bs, gene_img_functions g,
    	  img_reaction_t_components itc, img_pathway_reactions ipr
    	where g.scaffold = bs.scaffold
    	and bs.bin_oid = __bin_oid__
    	and g.function = itc.term
    	and itc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = __id__
        $rclause
        $imgClause
    	order by gene_oid
    };
    my $url = "$main_cgi?section=FuncProfile&page=funcProfile";
    my @colorMap = (
       "1:5:bisque",
       "5:100000:yellow",
    );
    my $sortUrl = "$section_cgi&showImgPwayCartProfile_t";
    my $fp = new FuncProfile( 
        "imgPway", $$, $url, $sortUrl, 
        \@taxon_bin_oids, \%taxonBinOid2Name, \%taxonBinOid2Domain, '', 
        \@pway_oids, \%pwayOid2Name, \@recs, \@colorMap, 
	    $taxon_cell_sql_template, $bin_cell_sql_template );
    $fp->printProfile( );

    ##$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save( );
}

############################################################################
# printPhyloOccurProfiles - Print phylogenetic occurrence profiles.
############################################################################
sub printPhyloOccurProfiles {

     my @pway_oids = param( "pway_oid" );
     my $nPways = @pway_oids;
     if( $nPways == 0 ) {
         webError( "Please select at least one pathway." );
     }
     if( $nPways > $maxProfileOccurIds ) {
         webError( "Please select no more than $maxProfileOccurIds " . 
	    "pathways." );
     }
     my $pway_oid_str = join( ',', @pway_oids );

     printStatusLine( "Loading ...", 1 );
     my $dbh = dbLogin( );

     ### Load ID information
     my $sql = qq{
         select ipw.pathway_oid, ipw.pathway_name
	 from img_pathway ipw
	 where ipw.pathway_oid in( $pway_oid_str )
     };
     my $cur = execSql( $dbh, $sql, $verbose );
     my @idRecs;
     my %idRecsHash;
     for( ;; ) {
         my( $id, $name ) = $cur->fetchrow( );
	 last if !$id;
	 $id = FuncUtil::pwayOidPadded( $id );
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
#         select distinct ipr.pathway_oid, g.taxon
#    	 from gene_img_functions g,
#    	    img_reaction_catalysts irc, img_pathway_reactions ipr,
#    	    dt_img_term_path ditp
#    	 where g.function = ditp.map_term
#    	 and irc.catalysts = ditp.term_oid
#    	 and irc.rxn_oid = ipr.rxn
#    	 and ipr.pathway_oid in( $pway_oid_str )
#         $rclause
#         $imgClause
#    	     union
#         select distinct ipr.pathway_oid, g.taxon
#    	 from gene_img_functions g,
#    	    img_reaction_t_components itc, img_pathway_reactions ipr,
#    	    dt_img_term_path ditp
#    	 where g.function = ditp.map_term
#    	 and itc.term = ditp.term_oid
#    	 and itc.rxn_oid = ipr.rxn
#    	 and ipr.pathway_oid in( $pway_oid_str )
#         $rclause
#         $imgClause
#     };
     my $sql = qq{
         select distinct ipr.pathway_oid, g.taxon
         from gene_img_functions g,
            img_reaction_catalysts irc, img_pathway_reactions ipr
         where g.function = irc.catalysts
         and irc.rxn_oid = ipr.rxn
         and ipr.pathway_oid in( $pway_oid_str )
         $rclause
         $imgClause
             union
         select distinct ipr.pathway_oid, g.taxon
         from gene_img_functions g,
            img_reaction_t_components itc, img_pathway_reactions ipr
         where g.function = itc.term
         and itc.rxn_oid = ipr.rxn
         and ipr.pathway_oid in( $pway_oid_str )
         $rclause
         $imgClause
     };
     my $cur = execSql( $dbh, $sql, $verbose );
     for( ;; ) {
         my( $id, $taxon ) = $cur->fetchrow( );
    	 last if !$id;
    	 $id = FuncUtil::pwayOidPadded( $id );
    	 my $rh = $idRecsHash{ $id };
    	 if( !defined( $rh ) ) {
    	    webDie( "printPhyloOccurProfiles: cannot find '$id'\n" );
    	 }
    	 my $taxonOidHash = $rh->{ taxonOidHash };
    	 $taxonOidHash->{ $taxon } = 1;
     }
     $cur->finish( );
     ##$dbh->disconnect();

     ## Print it out as an alignment.
     require PhyloOccur;
     my $s = "(Profiles are based on instantiation ";
     $s .= "of a pathway in a genome.\n";
     $s .= "A dot '.' means there are no instantiation.)\n";
     PhyloOccur::printAlignment( '', \@idRecs, $s );

     printStatusLine( "Loaded.", 2 );
}
1;

