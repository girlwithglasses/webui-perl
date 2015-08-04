############################################################################
# Curation cart.  This is a generalization of all the curation
#  ... carts.
#  Record fields (tab delimited separator):
#     0: func_id
#     1: func_name
#     2: batch_id
#    --imachen 03/20/2007
############################################################################
package CuraCartStor;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use InnerTable;
use DataEntryUtil;
use CuraCartDataEntry;
use FuncUtil;
use QueryUtil;

my $section = "CuraCartStor";
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $img_internal = $env->{ img_internal };
my $include_metagenomes = $env->{ include_metagenomes };
my $show_private = $env->{ show_private };
my $img_pheno_rule = $env->{ img_pheno_rule };

my $verbose = $env->{ verbose };

my $max_func_batch = 250;
my $max_taxon_batch = 900;
my $maxProfileOccurIds = 300;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "curaCart" || paramMatch( "addToCuraCart" ) ne "" ||
	paramMatch( "deleteSelectedCartFuncs" ) ne "" ||
	paramMatch( "clearCartFuncs" ) ne "" ||
	paramMatch( "transferFunctionCart" ) ne "" ) {
	setSessionParam( "lastCart", "curaCart" );
	my $cc = new CuraCartStor( );
	if( paramMatch( "transferFunctionCart" ) ne "" ) {
	    $cc->transferFunctionCart( );
	}
	elsif( paramMatch( "deleteSelectedCartFuncs" ) ne "" ) {
	    $cc->webRemoveFuncs( ) ;
	}
	elsif( paramMatch( "clearCartFuncs" ) ne "" ) {
	    $cc->webClearFuncs( ) ;
	}
	my $load;
	$load = "add" if paramMatch( "addToCuraCart" ) ne  "";
	$cc->printCuraCartForm( $load );
    }
    elsif( paramMatch( "addCompoundToCuraCart" ) ne "" ) {
       my $cc = new CuraCartStor( );
       $cc->addItemToCart( 'IMG_COMPOUND' );
       $cc->printCuraCartForm( );
    }
    elsif( paramMatch( "addReactionToCuraCart" ) ne "" ) {
       my $cc = new CuraCartStor( );
       $cc->addItemToCart( 'IMG_REACTION' );
       $cc->printCuraCartForm( );
    }
    elsif( paramMatch( "searchToAddForm" ) ne "" ||
	   paramMatch( "addForm" ) ne "" ||
	   paramMatch( "updateForm" ) ne "" ||
	   paramMatch( "updateNpActivityForm" ) ne "" ||
	   paramMatch( "mergeForm" ) ne "" ||
	   paramMatch( "confirmDeleteForm" ) ne "" ||
	   paramMatch( "addFuncIdToCuraCart" ) ne "" ||
	   paramMatch( "updateChildTermForm" ) ne "" ||
	   paramMatch( "updateAssocForm" ) ne "" ||
	   paramMatch( "connectAssocForm" ) ne "" ||
	   paramMatch( "searchAssocResultForm" ) ne "" ||
	   paramMatch( "fileUploadForm" ) ne "" ) {
	setSessionParam( "lastCart", "curaCart" );
	require CuraCartDataEntry;
	CuraCartDataEntry::dispatch( );
    } 
    else {
       my $cc = new CuraCartStor( );
       $cc->printCuraCartForm( );
    }
}

############################################################################
# new - New instance.
############################################################################
sub new {
   my( $myType, $baseUrl ) = @_;

   $baseUrl = "$section_cgi&page=curaCart" if $baseUrl eq "";
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
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
   my( $self ) = @_;
   my ($cartDir, $sessionId) = WebUtil::getCartDir();
   my $sessionFile = "$cartDir/curaCart.$sessionId.stor";
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my( $self ) = @_;
   store( $self, checkTmpPath( $self->getStateFile( ) ) );
}

############################################################################
# webAddFuncs - Load func cart from selections.
############################################################################
sub webAddFuncs {
    my( $self ) = @_;

    my @cog_ids = param( "cog_id" );
    my @pfam_ids = param( "pfam_id" );
    my @ec_numbers = param( "ec_number" );
    my @tigrfam_ids = param( "tigrfam_id" );
    #my @term_oids = param( "term_oid" );
    #my @pway_oids = param( "pway_oid" );
    my @func_ids; 
    for my $i( @cog_ids ) {
       push( @func_ids, $i );
    }
    for my $i( @pfam_ids ) {
       push( @func_ids, $i );
    }
    for my $i( @ec_numbers ) {
       push( @func_ids, $i );
    }
    for my $i( @tigrfam_ids ) {
       push( @func_ids, $i );
    }
    # These are more dynamic. Handle from raw sources.
    # --es 01/07/2007
    #for my $i( @term_oids ) {
    #   push( @func_ids, "ITERM:" . FuncUtil::termOidPadded( $i ) );
    #}
    #for my $i( @pway_oids ) {
    #   push( @func_ids, "IPWAY:" . FuncUtil::pwayOidPadded( $i ) );
    #}
    $self->addFuncBatch( \@func_ids );

    my @term_oids = param( "term_oid" );
    $self->addImgTermBatch( \@term_oids );

    my @pway_oids = param( "pway_oid" );
    $self->addImgPwayBatch( \@pway_oids );

    my @parts_list_oids = param( "parts_list_oid" );
    $self->addImgPartsListBatch( \@parts_list_oids );
}

############################################################################
# addItemToCart - add selected compound, reaction etc to curation cart
############################################################################
sub addItemToCart {
    my( $self, $c_name ) = @_;

    my @item_oids = param( FuncUtil::getOidAttr($c_name) );
    $self->addItemBatch( $c_name, \@item_oids );
}

############################################################################
# addItemBatch - Add compounds in a batch.
############################################################################
sub addItemBatch {
    my( $self, $name, $ids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $id( @$ids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushItemBatch( $name, $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $id );
       $selected->{ $id } = 1;
    }
    $self->flushItemBatch( $name, $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushItemBatch  - Flush one batch.
############################################################################
sub flushItemBatch {
    my( $self, $name, $dbh, $ids_ref, $batch_id ) = @_;

    return if( scalar( @$ids_ref ) == 0 ); 
    my $id_str = WebUtil::joinSqlQuoted( ',', @$ids_ref );

    my $recs = $self->{ recs };

    my $id_attr = FuncUtil::getOidAttr($name);
    my $name_attr = FuncUtil::getNameAttr($name);

    my $sql = qq{
       select t.$id_attr, t.$name_attr
       from $name t
       where t.$id_attr in( $id_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
       my( $item_id, $item_name ) = $cur->fetchrow( );
       last  if !$item_id;
       $count++;

       $item_id = FuncUtil::getFuncId ($name, $item_id);

#       if ( $name eq 'IMG_COMPOUND' ) {
#	   $item_id = "ICMPD:" . FuncUtil::oidPadded( 'IMG_COMPOUND', $item_id );
#       }
#       elsif ( $name eq 'IMG_REACTION' ) {
#	   $item_id = "IREXN:" . FuncUtil::oidPadded( 'IMG_REACTION', $item_id );
#       }

       my $r = "$item_id\t";
       $r .= "$item_name\t";
       $r .= "$batch_id\t";
       $recs->{ $item_id } = $r;
    }
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

    my $cc_recs = $self->{ recs };
    for my $i( @keys ) {
        next if $i !~ /ITERM/ && $i !~ /IPWAY/ && $i !~ /PLIST/;
	my $r = $recs->{ $i };
	my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	if ( ! $cc_recs->{ $i } ) {
	    $cc_recs->{ $i } = "$i\t$func_name\t$batch_id";
	}

#	$recs2{ $i } = "$i\t$func_name\t$batch_id";
#	$selected{ $i } = 1;
    }
#    $self->{ recs } = \%recs2;
#    $self->{ selected } = \%selected;
}

############################################################################
# addFuncBatch - Add genes in a batch.
############################################################################
sub addFuncBatch {
    my( $self, $func_ids_ref ) = @_;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $func_id( @$func_ids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushFuncBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $func_id );
       $selected->{ $func_id } = 1;
    }
    $self->flushFuncBatch( $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushFuncBatch  - Flush one batch.
############################################################################
sub flushFuncBatch {
    my( $self, $dbh, $func_ids_ref, $batch_id ) = @_;

    return if( scalar( @$func_ids_ref ) == 0 ); 

    my $recs = $self->{ recs };
    #my $selected = $self->{ selected };
    my %funcId2Name = QueryUtil::fetchFuncIdAndName($dbh, $func_ids_ref);
    for my $func_id (keys %funcId2Name) {
        my $func_name = $funcId2Name{$func_id};

        my $r = "$func_id\t";
        $r .= "$func_name\t";
        $r .= "$batch_id\t";
        $recs->{ $func_id } = $r;
    }

}

############################################################################
# addImgTermBatch - Add genes in a batch.
############################################################################
sub addImgTermBatch {
    my( $self, $term_oids_ref ) = @_;
    return if scalar( @$term_oids_ref ) == 0;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $term_oid( @$term_oids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushImgTermBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $term_oid );
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
       my $id = "ITERM:$term_oid";
       my $r = "$id\t";
       $r .= "$term\t";
       $r .= "$batch_id\t";
       $recs->{ $id } = $r;
       $selected->{ $id } = 1;
    }
}

############################################################################
# addImgPwayBatch - Add genes in a batch.
############################################################################
sub addImgPwayBatch {
    my( $self, $pway_oids_ref ) = @_;
    return if scalar( @$pway_oids_ref ) == 0;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $pway_oid( @$pway_oids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushImgPwayBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $pway_oid );
    }
    $self->flushImgPwayBatch( $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
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
       my $id = "IPWAY:$pway_oid";
       my $r = "$id\t";
       $r .= "$pway\t";
       $r .= "$batch_id\t";
       $recs->{ $id } = $r;
       $selected->{ $id } = 1;
    }
}


############################################################################
# addImgPartsListBatch - Add genes in a batch.
############################################################################
sub addImgPartsListBatch {
    my( $self, $parts_list_oids_ref ) = @_;
    return if scalar( @$parts_list_oids_ref ) == 0;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $parts_list_oid( @$parts_list_oids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushImgPartsListBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $parts_list_oid );
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
       my $id = "PLIST:$parts_list_oid";
       my $r = "$id\t";
       $r .= "$parts_list_name\t";
       $r .= "$batch_id\t";
       $recs->{ $id } = $r;
       $selected->{ $id } = 1;
    }
}

############################################################################
# addPhenoRuleBatch - Add phenotype rule in a batch.
############################################################################
sub addPhenoRuleBatch {
    my( $self, $rule_ids_ref ) = @_;
    return if scalar( @$rule_ids_ref ) == 0;
    my $dbh = dbLogin( );
    my @batch;
    my $batch_id = getNextBatchId( "func" );
    $self->{ selected } = { };
    my $selected = $self->{ selected };
    for my $rule_id ( @$rule_ids_ref ) {
       if( scalar( @batch ) > $max_func_batch ) {
          $self->flushPhenoRuleBatch( $dbh, \@batch, $batch_id );
	  @batch = ( );
       }
       push( @batch, $rule_id );
    }
    $self->flushPhenoRuleBatch( $dbh, \@batch, $batch_id );
    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# flushPhenoRuleBatch  - Flush one batch.
############################################################################
sub flushPhenoRuleBatch {
    my( $self, $dbh, $rule_oids_ref, $batch_id ) = @_;

    return if( scalar( @$rule_oids_ref ) == 0 ); 
    my $rule_oid_str = join( ',', @$rule_oids_ref );

    my $recs = $self->{ recs };

    my $sql = qq{
        select pr.rule_id, pr.description
	from phenotype_rule pr
	where pr.rule_id in( $rule_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my $selected = $self->{ selected };
    for( ;; ) {
       my( $rule_id, $descr ) = $cur->fetchrow( );
       last  if !$rule_id;
       $rule_id = FuncUtil::pwayOidPadded( $rule_id );
       $count++;
       my $id = "PRULE:$rule_id";
       my $r = "$id\t";
       $r .= "$descr\t";
       $r .= "$batch_id\t";
       $recs->{ $id } = $r;
       $selected->{ $id } = 1;
    }
}


############################################################################
# webRemoveFuncs - Remove functions from cart.
############################################################################
sub webRemoveFuncs {
   my( $self ) = @_;
   my @func_ids = param( "func_id" );
   my $recs = $self->{ recs };
   my $selected = $self->{ selected };
   for my $func_id( @func_ids ) {
      delete $recs->{ $func_id };
      delete $selected->{ $func_id };
   }
   $self->save( );
}

############################################################################
# webClearFuncs - clear cart
############################################################################
sub webClearFuncs {
   my( $self ) = @_;

   my $recs = $self->{ recs };
   my @func_ids = sort( keys( %$recs ) );
   my $selected = $self->{ selected };
   for my $func_id( @func_ids ) {
      delete $recs->{ $func_id };
      delete $selected->{ $func_id };
   }
   $self->save( );
}

############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
   my( $self ) = @_;
   my @func_ids = param( "func_id" );
   $self->{ selected } = { };
   my $selected = $self->{ selected };
   for my $func_id( @func_ids ) {
      $selected->{ $func_id } = 1;
   }
   $self->save( );
}


############################################################################
# printCuraCartForm - Print function cart 
#  form with list of genes and operations
#  that can be done on them.  
############################################################################
sub printCuraCartForm {
    my( $self, $load ) = @_;

    if( $load eq "add" ) {
       printStatusLine( "Loading ...", 1 );
       $self->webAddFuncs( );
    }
    if( $load eq "upload" ) {
       printStatusLine( "Loading ...", 1 );
       $self->uploadCuraCart( );
    }

    setSessionParam( "lastCart", "curaCart" );
    printMainForm( );
    print "<h1>Curation Cart</h1>\n";

    my $name = "_section_${section}_searchToAddForm";
    print submit( -name => $name, -value => "Search to Add to Curation Cart",
       -class => "meddefbutton" );
    print nbsp( 1 );
    my $name = "_section_${section}_transferFunctionCart";
    print submit( -name => $name, -value => "Copy from Function Cart",
       -class => "medbutton" );

    my $recs = $self->{ recs };
    my @func_ids = sort( keys( %$recs ) );
    my $count = @func_ids;
#    if( $count == 0 ) {
#       print "<p>\n";
#       print "0 functions in function cart.\n";
#       print "</p>\n";
#       printStatusLine( "0 functions in cart", 2 );
#    }
#    return if $count == 0;

    print "<p>\n";
    print "$count function(s) in cart\n";
    print "</p>\n";

    if ( $count > 0 ) {
	$self->printCuraCartContents($count);
    }

    my $contact_oid = getContactOid( );

    print "<h3>Add New Objects</h3>\n";
    print "<p>Select an object class in the listbox and click 'New' to enter a new object.</p>\n";
    my $name = "_section_${section}_addForm";
    print submit( -name => $name,
		  -value => 'New', -class => 'smbutton' );
    print nbsp( 3 );
    print "In Object Class: ";
    print nbsp( 1 );
    print "<select name='class_name' class='img' size='3'>\n";
    print "    <option value='PATHWAY_NETWORK' selected>FUNCTION_NETWORK</option>\n";
    print "    <option value='IMG_COMPOUND'>IMG_COMPOUND</option>\n";
    print "    <option value='IMG_PARTS_LIST'>IMG_PARTS_LIST</option>\n";
    print "    <option value='IMG_PATHWAY'>IMG_PATHWAY</option>\n";
    print "    <option value='IMG_REACTION'>IMG_REACTION</option>\n";
    print "    <option value='IMG_TERM'>IMG_TERM</option>\n";

    if ( $img_pheno_rule ) {
	print "    <option value='PHENOTYPE_RULE AND'>PHENOTYPE_RULE (And)</option>\n";
	print "    <option value='PHENOTYPE_RULE OR'>PHENOTYPE_RULE (Or)</option>\n";
    }

    print "</select>\n";

    if ( $count > 0 ) {
	print "<h3>Association Curation</h3>\n";
	print "<p>Select an object in the above table for object association curation. ";
	print "'Update Associations' updates existing association information. ";
	print "'Link Associations' adds additional associations from Curation Cart. ";
	print "</p>\n";
	print "<ul>\n";
	print "<li>For IMG_COMPOUND: Compound - Reaction</li>\n";
	print "<li>For IMG_PARTS_LIST: Parts List - Term</li>\n";
	print "<li>For IMG_PATHWAY: Pathway - Reaction</li>\n";
	print "<li>For IMG_REACTION: Reaction - Compound</li>\n";
	print "<li>For IMG_TERM: Term - Reaction</li>\n";
	print "</ul>\n";

	my $name = "_section_${section}_updateAssocForm"; 
	print submit( -name => $name, 
		      -value => 'Update Associations', -class => 'medbutton' ); 
	print nbsp( 1 );
	my $name = "_section_${section}_connectAssocForm"; 
	print submit( -name => $name, 
		      -value => 'Connect Associations', -class => 'medbutton' ); 

	print "<h4>Search Associations to Add</h4>\n";
	print "<p>Enter a keyword to search. Use % for wildcard.</p>\n";
	print "<input type='text' name='searchKey' size='80' />\n";
	print "<br/>\n";

	my $name = "_section_${section}_searchAssocResultForm";
	print submit( -name => $name,
		      -value => 'Search Associations', -class => 'medbutton' );
    }

    print "<h3>Upload Associations from a File</h3>\n";
    print "<p>Upload the following association data from a file. (Please select a file type.)</p>\n";

    print nbsp( 2 );
    print "<input type='radio' name='file_type' value='cr'/>Compound - Reaction\n";
    print "<br/>\n";
    print nbsp( 2 );
    print "<input type='radio' name='file_type' value='pt' />Parts List - Term\n";
    print "<br/>\n";
    print nbsp( 2 );
    print "<input type='radio' name='file_type' value='pr' />Pathway - Reaction\n";
    print "<br/>\n";
    print nbsp( 2 );
    print "<input type='radio' name='file_type' value='tr' />Term - Reaction\n";
    print "<br/>\n";

    my $name = "_section_${section}_fileUploadForm";
    print submit( -name => $name, -value => "File Upload",
		  -class => "medbutton" );

    print end_form( );
    $self->save( );
}

############################################################################
# printCuraCartContents - print curation cart (if not empty)
############################################################################
sub printCuraCartContents {
    my( $self, $count ) = @_;
    print "<h5>Note: This page only allows single item selection. 'Update SM Activity' is for IMG Compound only.</h5>\n";

    my $name = "_section_${section}_deleteSelectedCartFuncs";
    print submit( -name => $name,
       -value => "Remove Selected from Cart", -class => 'medbutton' );
    print nbsp( 1 );

    # add update and delete buttons
    my $name = "_section_${section}_updateForm";
    print submit( -name => $name,
		  -value => 'Update', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_updateNpActivityForm";
    print submit( -name => $name,
		  -value => 'Update SM Activity', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteForm";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smbutton' );
    print nbsp( 1 );

    my $name = "_section_${section}_clearCartFuncs";
    print submit( -name => $name,
       -value => "Clear Cart", -class => 'smbutton' );

    print "<br/>\n";

    # get selected func_id, if any
    my $selected_func_id = param( 'func_id' );

    my $it = new InnerTable( 3, "curaSet$$", "curaSet", 3 );
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Name", "char asc", "left" );
    $it->addColSpec( "Batch<sup>1</sup>", "number asc", "left" );
    my $sd = $it->getSdDelim();

    my @sortedRecs;
    my $sortIdx = param( "sortIdx" );
    $sortIdx = 2 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{ selected };
    for my $r( @sortedRecs ) {
       my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
       print "<tr class='img'>\n";

       my $r = $sd . "<input type='radio' name='func_id' value='$func_id' ";
       if ( $func_id eq $selected_func_id ) {
	   $r .= "checked /> \t"; 
       }
       else {
	   $r .= "/> \t";
       }
       my $link = $func_id;
       if( $func_id =~ /ITERM/ ||
	   $func_id =~ /IPWAY/ ||
	   $func_id =~ /PLIST/ ||
	   $func_id =~ /ICMPD/ ||
	   $func_id =~ /IREXN/ ||
	   $func_id =~ /NETWK/ ||
	   $func_id =~ /PRULE/ ) {
	   my ($tag, $item_oid) = split (/\:/, $func_id);
	   my $c_name = FuncUtil::funcIdToClassName($func_id);
	   my $url = FuncUtil::getUrl($main_cgi, $c_name, $item_oid);
	   $link = alink( $url, $func_id );
       }

       $r .= $func_id . $sd . $link . "\t";
       $r .= $func_name . $sd . $func_name . "\t"; 
       $r .= $batch_id . $sd . $batch_id . "\t"; 
 
       $it->addRow($r);
    }
    $it->printOuterTable(1);

    print "<p>\n";
    print "1 - Each time a set of functions is added to the cart, " .
      "a new distinguishing batch number is generated for the set.<br/>\n";
    print "</p>\n";
    printStatusLine( "$count function(s) in cart", 2 );

    # add remove selected button
    my $name = "_section_${section}_deleteSelectedCartFuncs";
    print submit( -name => $name,
       -value => "Remove Selected from Cart", -class => 'medbutton' );
    print nbsp( 1 );

    # add update and delete buttons
    my $name = "_section_${section}_updateForm";
    print submit( -name => $name,
		  -value => 'Update', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_updateNpActivityForm";
    print submit( -name => $name,
		  -value => 'Update SM Activity', -class => 'smbutton' );
    print nbsp( 1 );
    my $name = "_section_${section}_confirmDeleteForm";
    print submit( -name => $name,
		  -value => 'Delete', -class => 'smbutton' );
    print nbsp( 1 );

    my $name = "_section_${section}_clearCartFuncs";
    print submit( -name => $name,
       -value => "Clear Cart", -class => 'smbutton' );

    # update IMG term child (for IMG terms only)
    # update child terms
    print "<h3>Update Child Terms for IMG Term</h3>\n";
    print "<p><font color='red'>Note that this function only works for IMG terms.</font> Enter a search keyword and click 'Update Child Terms' to add new child terms, or simply click 'Update Child Terms' to remove child terms.</p>\n";

    print "Please enter a search keyword.<br/>\n";

    print "Filter: <input type='text' id='childTermFilter' name='childTermFilter' size='50' maxLength='1000' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_updateChildTermForm";
    print submit( -name => $name,
		  -value => 'Update Child Terms', -class => 'smbutton' );
    print "</p>\n";

    # merge IMG terms (for IMG terms only)
    print "<h3>Merge Other Terms into Selected IMG Term</h3>\n";
    print "<p><font color='red'>Note that this function only works for IMG terms.</font> Select an IMG term, enter a search keyword, and click 'Merge Terms' to start.</p>\n";

    print "Please enter a search keyword.<br/>\n";

    print "Filter: <input type='text' id='mergeTermFilter' name='mergeTermFilter' size='50' maxLength='1000' />\n";
    print nbsp( 1 );
    my $name = "_section_${section}_mergeForm";
    print submit( -name => $name,
		  -value => 'Merge Terms', -class => 'medbutton' );
    print "</p>\n";
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
    my @func_ids = keys( %$recs );
    my @a;
    my @idxVals;
    for my $func_id( @func_ids ) {
       my $rec = $recs->{ $func_id };
       my @fields = split( /\t/, $rec );
       my $sortRec;
       my $sortFieldVal = $fields[ $sortIdx ];
       if( $sortIdx == 0 || $sortIdx == 2 ) {
          $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $func_id );
       }
       else {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $func_id );
       }
       push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort( @idxVals );
    for my $i( @idxValsSorted ) {
       my( $idxVal, $func_id ) = split( /\t/, $i );
       my $r = $recs->{ $func_id };
       push( @$outRecs_ref, $r );
    }
}

1;

