############################################################################
# PhyloOccur - Phylogenetic occurence print out.
#   This is a BLAST-like alignment of occurrences which each position
#   representing a genome in phylogenetic placement.
#    --es 03/22/2006
############################################################################
package PhyloOccur;
my $section = "PhyloOccur";
use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $tmp_dir = $env->{ tmp_dir };
my $base_url = $env->{ base_url };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "" ) {
    }
    else {
    }
}

############################################################################
# printAlignment - Phylogenetic occurrence profile results.
#  idRecs_ref - This is an array of ID hashes with the following fields:
#     {
#          id =>   <string for display>
#          name => <string for mouseover>
#          url =>  <string for link out>
#          taxonOidHash => <ref to hash of instantiated taxonOids>
#     }
############################################################################
sub printAlignment {
   my( $taxon_oids_ref, $idRecs_ref, $panelDesc ) = @_;

   my $nRecs = @$idRecs_ref;

   printMainForm( );
   print "<h1>Phylogenetic Occurrence Profile</h1>\n";
   if( $nRecs  < 1 ) {
      webError( "You must select at least one cart entry.\n" );
   }
   print "<p>\n";
   print "Phylogenetic occurrence profile for selected genomes.\n";
   print nbsp( 1 );
   print "(Metagenomes and Viruses are not included.)<br/>\n";
   print "</p>\n";
   printHint( "Mouse over domain letter to see genome name.<br/>" . 
	      "Mouse over identifiers to see more information." );
   print "<p>\n";
   print domainLetterNoteNoVNoM( ) . "<br/>\n";
   print "$panelDesc\n";
   print "</p>\n";

   my $dbh = dbLogin( );
   my @phyloRecs = phyloArrayRecs( $dbh, $taxon_oids_ref );

   my @arrays;
   for my $rh( @$idRecs_ref ) {
      my $taxonOidHash = $rh->{ taxonOidHash };
      ## Augment phyloRecs with a match field at the end.
      my @arr = addArrayMatches( \@phyloRecs, $taxonOidHash );
      push( @arrays, \@arr );
   }
   
   print "<font color='blue'>\n";
   print "<pre>\n";
   my $i = 0;
   my $incr = 70;
   for( ; $i < scalar(@phyloRecs); $i += $incr ) {
      printPhyloPanel( $idRecs_ref, \@arrays, $i, $incr );
      print "\n";
   }
   print "</pre>\n";
   print "</font>\n";

   print "<script src='$base_url/overlib.js'></script>\n";
   print end_form( );
}

############################################################################
# phyloArrayRecs - Generate phylo array based on phylogentic level.
############################################################################
sub phyloArrayRecs {
   my( $dbh, $taxon_oids_ref ) = @_;
   
   my $taxonClause;
   if ( $taxon_oids_ref ne '') {
        my $taxon_oids_str = OracleUtil::getNumberIdsInClause1( $dbh, @$taxon_oids_ref );
        $taxonClause = " and t.taxon_oid in ( $taxon_oids_str ) ";
   }
   else {
       $taxonClause = txsClause( "", $dbh );       
   }
   
   my $rclause   = WebUtil::urClause('t');
   my $imgClause = WebUtil::imgClause('t');
   
   my $sql = qq{
      select distinct t.domain, t.phylum, t.ir_class, 
          t.ir_order, t.family, t.taxon_display_name, 
          t.taxon_oid
      from taxon t
      where 1 = 1
      and domain not like 'Vir%'
      and genome_type != 'metagenome'
      and domain not like 'Plasmid%'
      and domain not like 'GFragment%'
      $taxonClause
      $rclause
      $imgClause
      order by domain, phylum, ir_class, ir_order, family, 
          taxon_display_name, taxon_oid
   };

   my @recs;
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
      my( $domain, $phylum, $ir_class, $ir_order, $family, 
          $taxon_display_name, $taxon_oid ) = $cur->fetchrow( );
      last if !$taxon_oid;
      if( $domain eq "" ) {
          $domain = "?";
	  webLog "phyloArray: null domain for taxon_oid='$taxon_oid'\n"
	     if $verbose >= 1;
      }
      my $d = substr( $domain, 0, 1 );
      my $r = "$d\t";
      $r .= "$phylum\t";
      $r .= "$taxon_oid\t";
      $r .= "$taxon_display_name";
      push( @recs, $r );
      #print "phyloArrayRecs() r: $r<br/>\n";
   }

    OracleUtil::truncTable( $dbh, "gtt_num_id1" )
      if ( $taxonClause =~ /gtt_num_id1/i );

   return @recs;
}

############################################################################
# addArrayMatches - Add matches to end of records of PhyloArrayRec.
############################################################################
sub addArrayMatches {
   my( $phyloRecs_ref, $taxonOidsHash_ref ) = @_;
   
   my @recs;
   for my $pr( @$phyloRecs_ref ) {
      my( $domainLetter, $phylum, $taxon_oid, $taxon_display_name ) = 
         split( /\t/, $pr );
      if( $taxonOidsHash_ref->{ $taxon_oid } ne "" ) {
         push( @recs, "$pr\t1" );
      }
      else {
         push( @recs, "$pr\t0" );
      }
   }
   
   return @recs;
}

############################################################################
# printPhyloPanel - Print one panel subsection of occurrence profile.
#   Inputs:
#      idRecs_ref - ID records.
#      arrays_ref - array of phylogenetic positions (1|0) for each ID
#      startIdx - start index for panel
#      incr - increment for panel
############################################################################
sub printPhyloPanel {
    my( $idRecs_ref, $arrays_ref, $startIdx, $incr ) = @_;
    my $nRecs = @$idRecs_ref;
    my $nRows = @$arrays_ref;
    if( $nRecs != $nRows ) {
       webDie( "printPhyloPanel: nRecs=$nRecs != nRows=$nRows\n" );
    }

    print "<div>";
    print "<table id='phyloTable' cellspacing=0>";

    my $x1 = "<font color='blue'><b>";
    my $x2 = "</b></font>";
    my $x3 = "<font color='darkGreen'><b>";
    my $x4 = "</b></font>";

    for( my $i = 0; $i < $nRecs; $i++ ) {
       my $rh = $idRecs_ref->[ $i ];
       my $id = $rh->{ id };
       my $name = $rh->{ name };
       my $name2 = escHtml( $name );
       my $url = $rh->{ url };
       my $arr_ref = $arrays_ref->[ $i ];
       my $nPad = 20 - length( $id );
       my $pad = " " x $nPad;

       my $tooltip = "onmouseover=\"return overlib('$name2')\" onmouseout='return nd()'";
       if ( blankStr($name2) || blankStr($name) ) {
	   $tooltip = "";
       }
       print "<tr style='font-size: 10pt;'>";
       print "<td style=\"cursor:pointer;\" $tooltip>$x1$id$x2$pad</td>";

       my $nCols = @$arr_ref;
       $nCols = $startIdx + $incr if $nCols > $startIdx + $incr;
       for( my $j = $startIdx; $j < $nCols; $j++ ) {
          my $rec = $arr_ref->[ $j ];
	  my( $domain, $phylum, $taxon_oid, $taxon_display_name, $match ) = 
	     split( /\t/, $rec );

	  $taxon_display_name =~ s/'/ /g;
	  my $label = escHtml( "[$phylum] $taxon_display_name" );

          my $tooltip2 = "onmouseover=\"return overlib('$label')\" onmouseout='return nd()'";
          print "<td width=10 border=0 align='center' style=\"cursor:pointer;\" $tooltip2>$x3";
	  if( $match ) {
	     print "$domain$x4</td>";
          }
	  else {
	     print ".$x2</td>";
	  }
       }
       print "\n";
    }
    print "</table>";
    print "</div>\n";
}


1;

