############################################################################
# TermNodeMgr.pm - Term node manager. 
#  Use to generate tree from nodes and manage the application.
#     --es 12/27/2005
############################################################################
package TermNodeMgr;
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use TermNode;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $inner_cgi = $env->{ inner_cgi };
my $base_url = $env->{ base_url };
my $verbose = $env->{ verbose };

my $max_batch = 500;

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
   my( $myType ) = @_;
   my $self = { };
   bless( $self, $myType );

   $self->{ root } = new TermNode( 0, "_root" );
   $self->{ max_depth } = 0;
   $self->{ termOid2Name } = { };
   $self->{ termOid2Parents } = { };
   $self->{ termOid2Children } = { };
   $self->{ termOid2Node } = { };

   return $self;
}

############################################################################
# Accessors
############################################################################
sub getRoot {
    my( $self ) = @_;
    return $self->{ root };
}
sub getMaxDepth {
    my( $self ) = @_;
    return $self->{ max_depth };
}
sub getTermOid2Name {
    my( $self ) = @_;
    return $self->{ termOid2Name };
}
sub getTermOid2Parents {
    my( $self ) = @_;
    return $self->{ termOid2Parents };
}
sub getTermOid2Children {
    my( $self ) = @_;
    return $self->{ termOid2Children };
}
sub getTermOidNode {
    my( $self ) = @_;
    return $self->{ termOid2Node };
}


############################################################################
# loadTree - Load tree from scratch.
#   type = "phenotype", "ecotype", "disease", or "relevance".
############################################################################
sub loadTree {
    my( $self, $dbh, $type ) = @_;
    
    my $root = $self->{ root };
    my $termOid2Node = $self->{ termOid2Node };

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select t.${type}s, tx.taxon_oid
        from project_info_${type}s t, taxon tx
        where tx.project = t.project_oid
        $rclause
        $imgClause
    };
    #print "loadTree \$sql1: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %type2Taxon;
    for( ;; ) {
		my( $t, $taxon_oid ) = $cur->fetchrow( );
		last if !$t;
		$type2Taxon{ $t } = $taxon_oid;
    }
    $cur->finish( );

    ## Get all terms.
    my $sql = qq{
        select cv.${type}_oid, cv.${type}_term
	    from ${type}cv cv
	    where 1 = 1
	    order by cv.${type}_term
    };
    #print "loadTree \$sql2: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %termOid2Name;
    for( ;; ) {
        my( $term_oid, $term_name ) = $cur->fetchrow( );
	   last if !$term_oid;
	   $termOid2Name{ $term_oid } = $term_name;
    }
    $cur->finish( );
    $self->{ termOid2Name } = \%termOid2Name;

    # Find parents and children.
    my $sql = qq{
        select p.${type}_oid, p.parents
	    from ${type}cv_parents p
    };
    #print "loadTree \$sql3: $sql<br/>\n";
    my %termOid2Parents;
    my %termOid2Children;
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $term_oid, $parent ) = $cur->fetchrow( );
	    last if !$term_oid;
	    my $term_name =  $termOid2Name{  $term_oid };
	    next if $term_name eq "";
	    my $term_name =  $termOid2Name{  $parent };
	    next if $term_name eq "";
	    $termOid2Parents{ $term_oid } .= "$parent ";
	    $termOid2Children{ $parent } .= "$term_oid ";
    }
    $cur->finish( );
    $self->{ termOid2Parents } = \%termOid2Parents;
    $self->{ termOid2Children } = \%termOid2Children;

    # Terms w/o parents.  Term root nodes.
    my @keys = sort( keys( %termOid2Name ) );
    my @recs;
    for my $k( @keys ) {
       my $parents = $termOid2Parents{ $k };
       next if $parents ne "";
       my $term_name = $termOid2Name{ $k };
       my $r = "$term_name\t";
       $r .= "$k\t";
       push( @recs, $r );
    }
    my @recs2 = sort( @recs );
    for my $r( @recs2 ) {
        my( $term_name, $term_oid ) = split( /\t/, $r );
	    my $n = new TermNode( $term_oid, $term_name );
	    addBranch( $self, $root, $n, $term_oid, 
	    \%termOid2Children, \%termOid2Name, \%type2Taxon );
    }

    $root->purgeNoTaxonOid( );

    ## Find maximum depth.
    my $depth = 0;
    $root->maxDepth( \$depth );
    $self->{ max_depth } = $depth;
}


############################################################################
# addBranch - Add an entire branch recursively.
############################################################################
sub addBranch {
    my( $self, $parent, $child, $child_oid, 
        $termOid2Children_ref, $termOid2Name_ref,
	$type2Taxon_ref ) = @_;

    my $taxon_oid = $type2Taxon_ref->{ $child_oid };
    $child->{ taxon_oid } = $taxon_oid;
    my $termOid2Node = $self->{ termOid2Node };
    $termOid2Node->{ $child_oid } = $child;
    $parent->addNode( $child );
    my $children_str = $termOid2Children_ref->{ $child_oid };
    my @children2 = split( / /, $children_str );
    for my $c2_oid( @children2 ) {
        next if $c2_oid eq "";
	    my $term_name2 = $termOid2Name_ref->{ $c2_oid };
	    next if $term_name2 eq "";
	    my $n2 = new TermNode( $c2_oid, $term_name2 );
        #my $taxon_oid = $type2Taxon_ref->{ $c2_oid };
        #$n2->{ taxon_oid } = $taxon_oid;
	    addBranch( $self, $child, $n2, $c2_oid, 
	    $termOid2Children_ref, $termOid2Name_ref, $type2Taxon_ref );
    }
}

############################################################################
# findTaxons - Find taxons for a list of term_oid's.
############################################################################
sub findTaxons {
    my( $self, $dbh, $type, $termOids_ref, $taxonRecs_ref ) = @_;

    my $max_depth = $self->{ max_depth };
    for( my $i = 0; $i < $max_depth; $i++ ) {
       $self->findTaxonAtLevel( $dbh, $type, $i, 
          $termOids_ref, $taxonRecs_ref );
    }
}

############################################################################
# findTaxonAtLevel - Find taxon a given level.
############################################################################
sub findTaxonAtLevel {
    my( $self, $dbh, $type, $level, $termOids_ref, $taxonRecs_ref ) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $termOid_str = join( ',', @$termOids_ref );
    my $selectClause = "select distinct tx.taxon_oid, t0.${type}s";
    my $fromClause = "from project_info_${type}s t0, taxon tx, ";
    my $whereClause = "where t0.${type}s in( $termOid_str )\n";
    $whereClause .= "and t0.project_oid = tx.project";
    if( $level > 0 ) {
       $selectClause = "select distinct t0.taxon_oid, t$level.parents";
       $whereClause = "where t$level.parents in( $termOid_str )\n";
       for( my $i = $level; $i > 0; $i--  ) {
    	  my $i0 = $i - 1;
              $fromClause .= "${type}cv_parents t$i, ";
    	  if( $i0 > 0 ) {
    	      $whereClause .= "and t$i.${type}_oid = t$i0.parents\n";
              }
    	  else {
    	      $whereClause .= "and t$i.${type}_oid = t0.${type}s\n";
    	  }
       }
    }
    chop $fromClause;
    chop $fromClause;
    my $sql = qq{
        $selectClause
        $fromClause
        $whereClause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $taxon_oid, $taxon_display_name, $term_oid ) = $cur->fetchrow( );
    	last if !$taxon_oid;
    	my $r = "$taxon_oid\t";
    	$r .= "$term_oid";
    	push( @$taxonRecs_ref, $r );
    }
    $cur->finish( );
}

############################################################################
# getTermAttrs4Taxon - Get term attributes for one taxon.
############################################################################
sub getTermAttrs4Taxon {
    my( $self, $dbh, $type, $taxon_oid ) = @_;
    my @taxonOids;
    push( @taxonOids, $taxon_oid );
    my @termOids;
    my %outRecs;
    highlightTermAttrs( $self, $dbh, $type, 
       \@taxonOids, \@termOids, \%outRecs );
    my $r = $outRecs{ $taxon_oid };
    my( $taxon_oid, $taxon_display_name, $htmlTerms ) = split( /\t/, $r );
    return $htmlTerms;
}

############################################################################
# highlightTermAttrs - Highlight term attributes.
############################################################################
sub highlightTermAttrs {
   my( $self, $dbh, $type, $taxonOids_ref, $termOids_ref, $outRecs_ref ) = @_;

   my @batch;
   for my $taxon_oid( @$taxonOids_ref ) {
      if( scalar( @batch ) > $max_batch ) {
         $self->flushTermBatch( $dbh, $type, \@batch, 
	     $termOids_ref, $outRecs_ref );
	 @batch = ( );
      }
      push( @batch, $taxon_oid );
   }
   $self->flushTermBatch( $dbh, $type, \@batch, 
      $termOids_ref, $outRecs_ref );
}

############################################################################
# flushTermBatch - Flush one batch of taxon_oids.
############################################################################
sub flushTermBatch {
   my( $self, $dbh, $type, $taxonOids_ref, 
       $highLightTermOids_ref, $outRecs_ref ) = @_;
   return if scalar( @$taxonOids_ref ) == 0;

   my %hilightTermOids;
   for my $i( @$highLightTermOids_ref ) {
      $hilightTermOids{ $i } = $i;
   }

   my $termOid2Name_ref = $self->{ termOid2Name };
   my $termOid2Parents_ref = $self->{ termOid2Parents };
   my $taxon_oid_str = join( ',', @$taxonOids_ref );

   ## Get leaf terms  and highlight them.
   my $rclause = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   #my $sql_old = qq{
   #    select distinct tx.taxon_oid, tx.taxon_display_name, 
   #       cv.${type}_oid, cv.${type}_term
   #    from taxon_${type}s tcv, taxon tx, ${type}cv cv
   #    where tx.taxon_oid in( $taxon_oid_str )
   #    and tcv.taxon_oid = tx.taxon_oid
   #    and tcv.${type}s = cv.${type}_oid
   #    $rclause
   #    order by tx.taxon_display_name, cv.${type}_term
   #};
   my $sql = qq{
        select distinct tx.taxon_oid, tx.taxon_display_name, 
          cv.${type}_oid, cv.${type}_term
        from project_info_${type}s picv, taxon tx, ${type}cv cv
        where tx.taxon_oid in( $taxon_oid_str )
        and picv.project_oid = tx.project
        and picv.${type}s = cv.${type}_oid
        $rclause
        $imgClause
        order by tx.taxon_display_name, cv.${type}_term
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   my @taxonOidsOrdered;
   my %taxonOidsDone;
   my %taxonOid2Name;
   my %taxonOid2Terms;
   my %taxonOid2TermOids;
   for( ;; ) {
      my( $taxon_oid, $taxon_display_name, $term_oid, $term_name ) = 
          $cur->fetchrow( );
      last if !$taxon_oid;
      $taxonOid2Terms{ $taxon_oid } .= "$term_name\t$term_oid\n";
      $taxonOid2TermOids{ $taxon_oid } . "$term_oid ";
      push( @taxonOidsOrdered, $taxon_oid ) 
         if $taxonOidsDone{ $taxon_oid } eq "";
      $taxonOid2Name{ $taxon_oid } = $taxon_display_name
         if $taxonOidsDone{ $taxon_oid } eq "";
      $taxonOidsDone{ $taxon_oid } = 1;
   }
   $cur->finish( );

   ## Get (unique) parents and highlight them.
   my %taxonOid2ParentHtmlStr;
   for my $taxon_oid( @taxonOidsOrdered ) {
      my @term_oids = split( / /, $taxonOid2TermOids{ $taxon_oid } );
      my %parentOids;
      for my $term_oid( @term_oids ) {
          next if $term_oid eq "";
	  getAllParents( $self, $term_oid, \%parentOids );
      }
      my @keys = keys( %parentOids );
      for my $k( @keys ) {
         my $term_name = $termOid2Name_ref->{ $k };
	 $taxonOid2Terms{ $taxon_oid } .= "$term_name\t$k\n";
      }
   }

   ## Output unique taxon_oid/taxon name rows with leaf and parent terms.
   for my $taxon_oid( @taxonOidsOrdered ) {
      my $r = "$taxon_oid\t";
      my $taxon_display_name = $taxonOid2Name{ $taxon_oid };
      $r .= escHtml( $taxon_display_name ) . "\t";
      my $termRecs_str = $taxonOid2Terms{ $taxon_oid };
      my @termRecs = split( /\n/, $termRecs_str );
      my @termRecs2 = sort( @termRecs );
      my %done;
      my $htmlTerms;
      my $nTermRecs = @termRecs2;
      for my $r2( @termRecs2 ) {
         my( $term_name, $term_oid ) = split( /\t/, $r2 );
	 next if $done{ $term_name } ne "";
	 my $htmlTerm = escHtml( $term_name ) . ", ";
	 $htmlTerm = "<font color='green'><b>" .
	    escHtml( $term_name ) . "</b></font>, " 
	       if $hilightTermOids{ $term_oid } ne "";
	 $htmlTerms .= $htmlTerm;
	 $done{ $term_name } =  1;
      }
      chop $htmlTerms;
      chop $htmlTerms;
      $r .= $htmlTerms;
      $outRecs_ref->{  $taxon_oid } = $r;
   }
}

############################################################################
# getAllParent - Get all (unique) parents.
#   We assume one parent per node here.
############################################################################
sub getAllParents {
   my( $self, $term_oid, $parentOids_ref ) = @_;

   my $termOid2Parents = $self->{ termOid2Parents };
   my $parents_str = $termOid2Parents->{  $term_oid };
   my @a = split( / /, $parents_str );
   for my $i( @a ) {
      $parentOids_ref->{ $i } = $i;
      getAllParents( $self, $i, $parentOids_ref );
   }
}


############################################################################
# expandTermOids - Expand list of term_oids to include children.
############################################################################
sub expandTermOids {
    my( $self, $termOids_ref ) = @_;
    my $termOid2Node = $self->{ termOid2Node };
    my %termOids2;
    for my $term_oid0( @$termOids_ref ) {
       my $n = $termOid2Node->{ $term_oid0 };
       $n->loadChildrenTermOids( \%termOids2 );
    }
    ## Add original list to make unique.
    for my $i( @$termOids_ref ) {
       $termOids2{ $i } = $i;
    }
    my @keys = sort( keys( %termOids2 ) );
    @$termOids_ref = ( );
    for my $k( @keys ) {
       push( @$termOids_ref, $k );
    }
}

1;

