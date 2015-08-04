############################################################################
# GenomeProperty - Handle methods for genome property.
#   --es 10/17/2007
############################################################################
package GenomeProperty;
my $section = "GenomeProperty";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };

############################################################################
# dispatch
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "genomePropertyDetails" ) {
       printGenomePropertyDetails( );
    }
    else {
       webError( "No genome property found." );
    }
}

############################################################################
# printGenomePropertyDetails - Show details for a genome property.
############################################################################
sub printGenomePropertyDetails {
    my $prop_accession  = param( "prop_accession" );
    my $gene_oid = param( "gene_oid" );

    print "<h1>Genome Property Details</h1>\n";
    print "<p>\n";
    if( $gene_oid ne "" ) {
       print "Evidence for step from gene <i>$gene_oid</i> ";
       print "is shown in red.<br/>\n";
       print "Evidence from other genes in the same genome\n";
       print "is shown in green.<br/>\n";
    }
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    printMainForm( );

    my $sql = qq{
        select name, description, threshold, type
	from genome_property gp
	where prop_accession = '$prop_accession'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $name, $description, $threshold, $type ) = $cur->fetchrow( );
    $cur->finish( );
    print "<table class='img' border='1'>\n";
    printAttrRow( "Accession", $prop_accession );
    printAttrRow( "Name", $name );
    printAttrRow( "Description", $description );
    printAttrRow( "Threshold", $threshold );
    printAttrRow( "Type", $type );
    printParents( $dbh, $prop_accession );
    printChildren( $dbh, $prop_accession );
    printSteps( $dbh, $prop_accession, $gene_oid );
    print "</table>\n";

    #$dbh->disconnect( );
    print end_form( );
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printParents - Print parent properties
############################################################################
sub printParents {
    my( $dbh, $prop_accession ) = @_;

    my $sql = qq{
       select gp.prop_accession, gp.name
       from genome_property_parents gpp, genome_property gp
       where gpp.prop_accession = '$prop_accession'
       and gpp.parents = gp.prop_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<tr class='img'>\n";
    print "<th class='subhead'>Parents</th>\n";
    print "<td class='img'>\n";
    my $s;
    for( ;; ) {
        my( $accession, $name ) = $cur->fetchrow( );
	last if !$accession;
	my $url = "$section_cgi&page=genomePropertyDetails";
	$url .= "&prop_accession=$accession";
	$s .= alink( $url, $prop_accession );
	$s .= " - ";
	$s .= escHtml( $name );
	$s .= "<br/>\n";
    }
    $s = nbsp( 1 ) if $s eq "";
    print $s;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish( );
}

############################################################################
# printChildren - Print children properties
############################################################################
sub printChildren {
    my( $dbh, $prop_accession ) = @_;

    my $sql = qq{
       select gp.prop_accession, gp.name
       from genome_property_parents gpp, genome_property gp
       where gpp.parents = '$prop_accession'
       and gpp.prop_accession = gp.prop_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<tr class='img'>\n";
    print "<tr class='img'>\n";
    print "<th class='subhead'>Children</th>\n";
    print "<td class='img'>\n";
    my $s;
    for( ;; ) {
        my( $accession, $name ) = $cur->fetchrow( );
	last if !$accession;
	my $url = "$section_cgi&page=genomePropertyDetails";
	$url .= "&prop_accession=$accession";
	$s .= alink( $url, $prop_accession );
	$s .= " - ";
	$s .= escHtml( $name );
	$s .= "<br/>\n";
    }
    $s = nbsp( 1 ) if $s eq "";
    print $s;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish( );
}

############################################################################
# printSteps - Show steps for property.
############################################################################
sub printSteps {
    my( $dbh, $prop_accession, $gene_oid ) = @_;

    my $sql1 = qq{
        select ps.step_accession, gxf.gene_oid
	from property_step ps, property_step_evidences pse,
	  gene_xref_families gxf
	where ps.genome_property = '$prop_accession'
	and ps.step_accession = pse.step_accession
	and pse.query = gxf.id
	and gxf.gene_oid = $gene_oid
	order by ps.step_accession
    };
    my $sql2 = qq{
        select ps.step_accession, gpf.gene_oid
	from property_step ps, property_step_evidences pse,
	  gene_pfam_families gpf
	where ps.genome_property = '$prop_accession'
	and ps.step_accession = pse.step_accession
	and pse.query = gpf.pfam_family
	and gpf.gene_oid = $gene_oid
	order by ps.step_accession
    };
    my $taxon;
    $taxon = geneOid2TaxonOid( $dbh, $gene_oid )
       if $gene_oid ne "";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql3 = qq{
        select ps.step_accession, g.gene_oid
	from property_step ps, property_step_evidences pse,
	  gene_xref_families gxf, gene g
	where ps.genome_property = '$prop_accession'
	and ps.step_accession = pse.step_accession
	and pse.query = gxf.id
	and gxf.gene_oid = g.gene_oid
	and g.taxon = $taxon
	$rclause
	$imgClause
	order by ps.step_accession
    };
    my $sql4 = qq{
        select ps.step_accession, g.gene_oid
	from property_step ps, property_step_evidences pse,
	  gene_pfam_families gpf, gene g
	where ps.genome_property = '$prop_accession'
	and ps.step_accession = pse.step_accession
	and pse.query = gpf.pfam_family
	and gpf.gene_oid = g.gene_oid
	and g.taxon = $taxon
        $rclause
        $imgClause
	order by ps.step_accession
    };
    my %stepRed;
    my %stepGreen;
    if( $gene_oid ne "" ) {
       my $cur = execSql( $dbh, $sql1, $verbose );
       for( ;; ) {
          my( $step_accession, $gene_oid ) = $cur->fetchrow( );
	  last if !$step_accession;
	  $stepRed{ $step_accession } .= "$gene_oid ";
       }
       $cur->finish( );
       my $cur = execSql( $dbh, $sql2, $verbose );
       for( ;; ) {
          my( $step_accession, $gene_oid ) = $cur->fetchrow( );
	  last if !$step_accession;
	  $stepRed{ $step_accession } .= "$gene_oid ";
       }
       $cur->finish( );
       my $cur = execSql( $dbh, $sql3, $verbose );
       for( ;; ) {
          my( $step_accession, $gene_oid ) = $cur->fetchrow( );
	  last if !$step_accession;
	  $stepGreen{ $step_accession } .= "$gene_oid ";
       }
       $cur->finish( );
       my $cur = execSql( $dbh, $sql4, $verbose );
       for( ;; ) {
          my( $step_accession, $gene_oid ) = $cur->fetchrow( );
	  last if !$step_accession;
	  $stepGreen{ $step_accession } .= "$gene_oid ";
       }
       $cur->finish( );
    }

    my $sql = qq{
        select ps.step_accession, ps.name, ps.is_required
	from property_step ps
	where ps.genome_property = '$prop_accession'
	order by ps.step_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<tr class='img'>\n";
    print "<tr class='img'>\n";
    print "<th class='subhead'>Steps</th>\n";
    print "<td class='img'>\n";
    my $s;
    for( ;; ) {
       my( $step_accession, $name, $is_required ) = $cur->fetchrow( );
       last if !$step_accession;
       my $x = "optional";
       $x = "required" if $is_required;
       my $hiliteRed = $stepRed{ $step_accession } ne "";
       my $hiliteGreen = $stepGreen{ $step_accession } ne "";
       if( $hiliteRed ) {
           $s .= "<font color='red'>";
       }
       elsif( $hiliteGreen ) {
           $s .= "<font color='green'>";
       }
       my $link = $step_accession;
       my $oidStr;
       if( $hiliteRed || $hiliteGreen ) {
	   my $redOid = $stepRed{ $step_accession };
	   my $greenOids = $stepGreen{ $step_accession };
	   $oidStr = " gene[";
	   my $url0 = "$main_cgi?page=geneDetail&gene_oid=";
	   if( $redOid ne "" ) {
	      chop $redOid;
	      my $url = "$url0$redOid";
	      $oidStr .= alink( $url, $redOid ) . ", ";
	   }
	   else {
	      my @oids = split( / /, $greenOids );
	      for my $oid( @oids ) {
	          my $url = "$url0$oid";
	          $oidStr .= alink( $url, $oid ) . ", ";
	      }
	   }
	   chop $oidStr;
	   chop $oidStr;
	   $oidStr .= "]";
       }
       $s .= escHtml( "- $step_accession - $name ($x)" );
       $s .= $oidStr;
       $s .= "</font>" if $hiliteRed || $hiliteGreen;
       $s .= "<br/>\n";
    }
    $s = nbsp( 1 ) if $s eq "";
    print $s;
    print "</td>\n";
    print "</tr>\n";
    $cur->finish( );
}
############################################################################
# getGenomeType - isolate or metagenome
############################################################################
sub getGenomeType {
    my( $taxon_oid ) = @_;

    my $sql = "select genome_type from taxon where taxon_oid = ? ";
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $genome_type = "";
    for ( ; ; ) {
        my $genome_type_temp = $cur->fetchrow();
        last if !$genome_type_temp;
        $genome_type = $genome_type_temp;
    }

    if ( $genome_type eq "") {
        webError("Taxon_oid $taxon_oid is invalid.");
    }
    $cur->finish();
    #$dbh->disconnect();

    return $genome_type;
}

1;

