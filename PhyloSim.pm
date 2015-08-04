############################################################################
# PhyloSim.pl - Phylogenetic profile similarity search.
#   A phylo profile is a ordered vector of hits across genomes.
#   These vectors may be compared, with some tolerance for
#   non-exact matches.
#   Search for other genes with similar vectors in the same
#   genome as query gene.
#    --es 03/12/2005
############################################################################
package PhyloSim;
my $section = "PhyloSim";
use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use LwpHandle;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $web_data_dir = $env->{ web_data_dir };
my $ava_taxon_dir = $env->{ ava_taxon_dir };
my $phyloProfile_file = $env->{ phyloProfile_file };
my $phyloProfile_idxFile = $env->{ phyloProfile_idxFile };
my $phyloSim_bin = $env->{ phyloSim_bin };
my $phyloSimServer_base_url = $env->{ phyloSimServer_base_url };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $default_timeout_mins = $env->{ default_timeout_mins };
$default_timeout_mins = 5 if $default_timeout_mins eq "";

my $maxBatchSize = 100;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "phyloSimResults" ) {
        printPhyloSimResults( );
    }
    else {
        printPhyloSimForm( );
    }
}

############################################################################
# printPhyloSimForm - Print input form.
############################################################################
sub printPhyloSimForm {
   my $gene_oid = param( "genePageGeneOid" );

   printMainForm( );
   print "<h1>Phylogenetic Profile Similarity Search</h1>\n";

   print "<p>\n";
   print "Find genes with similar phylogenetic occurrence profile.";
   print "</p>\n";

   my $dbh = dbLogin( );

   print "<table class='img'  border='1'>\n";

   print "<tr class='img' >\n";
   print "<th class='subhead' align='left'>" .
      "Min. % Occurrence Match</th>\n";
   print "<td class='img' >\n";
   print popup_menu( -name => "minPhyloPercIdent",
      -values => [ 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 ],
      -default => 80 
   );
   print "</td>\n";
   print "</tr>\n";

   print "<tr class='img' >\n";
   print "<th class='subhead' align='left'>Top N results</th>\n";
   print "<td class='img' >\n";
   print popup_menu( -name => "top_n_phyloResults",
      -values => [ 10, 50, 100, 200, 500, 1000, 2000, 5000, 10000 ],
      -default => 500 
   );
   print "</td>\n";
   print "</tr>\n";

   print "</table>\n";

   print "<br/>\n";
   print hiddenVar( "phyloSimGeneOid", $gene_oid );
   print hiddenVar( "page", "phyloSimResults" );
   my $name = "_section_${section}_phyloSimSubmit";
   print submit( -name => $name,
      -value => "Run Search", 
      -class => "smdefbutton" );
   print nbsp( 1 );
   print reset( -class => "smbutton" );

   #$dbh->disconnect();

   print "<p>\n";
   printHint( "The minimum percent occurrence match is the minimum " .
     "percentage agreement between two  profiles " .
     "in order to constitute a match.  " .
     "An occurrence is an occurrence of the gene in another genome " .
     "through bidirectional best hit orthologs. " .
     "See <a href='help/concepts.html#phyloOccurProfile'>Concepts</a> " .
     "and <a href='about/analysis.html#phyloOccurProfile'>Data Analysis</a> " .
     "for more information.  " .
     "Profiles are constructed for currently selected genomes. " .
     "Selecting all genomes to get the widest phylogenetic context " .
     "is recommended. " );
   print "</p>\n";
   print end_form( );
   #printHint( 
   #  "Hold down control key to select more than one genome." 
   #);
}

############################################################################
# printPhyloSimResults - Show search results.
#   Input parameters (from CGI):
#     phyloSimGeneOid - query gene object identifier
#     minPhyloPercIdent - minimum percent identity
#     top_n_phyloResults - n in limit to top n results
#     phyloSimGenomeSelections - (not used anymore)
############################################################################
sub printPhyloSimResults {

   timeout( 60 * 40 );  # make long timeout

   my $gene_oid = param( "phyloSimGeneOid" );
   $gene_oid =~ /([0-9]+)/;
   $gene_oid = $1;

   my $minPhyloPercIdent = param( "minPhyloPercIdent" );
   $minPhyloPercIdent =~ /([0-9]+)/;
   $minPhyloPercIdent = $1;
   my $minPercIdent = $minPhyloPercIdent / 100;

   my $top_n_phyloResults = param( "top_n_phyloResults" );
   $top_n_phyloResults =~ /([0-9]+)/;
   $top_n_phyloResults = $1;

   my @phyloSimGenomeSelections = param( "phyloSimGenomeSelections" );

   printMainForm( );
   print "<h1>Phylogenetic Profile Similarity Results</h1>\n";

   my $dbh = dbLogin( );

   checkGenePerm( $dbh, $gene_oid );

   printStatusLine( "Loading ...", 1 );

   # --es 03/10/2006
   # (We use taxon_stats to filter out genomes in progress.)
   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $sql = qq{
       select tx.taxon_oid, tx.taxon_display_name
       from gene g, taxon tx, taxon_stats ts
       where g.taxon = tx.taxon_oid
       and g.gene_oid = $gene_oid
       and g.obsolete_flag = 'No'
       and ts.taxon_oid = tx.taxon_oid
       $rclause
       $imgClause
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   my( $taxon_oid, $taxon_display_name ) = $cur->fetchrow( );
   $cur->finish( );

   print "<p>\n";
   print "Find genes with similar profiles in " .  
     escHtml( $taxon_display_name ) . 
     " at $minPhyloPercIdent% occurrence match " .
     "using bidirectional best hit orthologs " .
     "in currently selected genomes. ";
   print "</p>\n";

   printHint( "You can add matching genes to the gene cart " .
     "and view their phylogenetic occurrence profiles." );

   ## Mask out selected taxons.
   my $mask = phyloSimMask( $dbh );
   $mask =~ /([0-1]+)/;
   $mask = $1;

   my $tmpFile = "$cgi_tmp_dir/phyloSim$$.out.txt";
   my $tmpMaskFile = "$cgi_tmp_dir/phyloSim$$.mask.txt";
   str2File( "$mask\n", $tmpMaskFile );
   my $rfh;
   if( $phyloSimServer_base_url ne "" ) {
       my $url = $phyloSimServer_base_url;
       webLog( "Calling '$url'\n" );
       my %args;
       $args{ gene_oid } = $gene_oid;
       $args{ taxon_oid } = $taxon_oid;
       $args{ minPercIdent } = $minPercIdent;
       $args{ top_n_phyloResults } = $top_n_phyloResults;
       $args{ mask } = $mask;
       $rfh = new LwpHandle( $url, \%args );
   }
   else {
       my $cmd = "$phyloSim_bin -i $phyloProfile_file -I $gene_oid " .
         "-o $tmpFile -p $minPercIdent -n $top_n_phyloResults " .
         "-v 1 -T $taxon_oid -mf $tmpMaskFile -M 200000 ";
       webLog "+ $cmd\n" if $verbose >= 1;
       printStartWorkingDiv( );
       #print "<p>\n";
       my $st = wsystem( $cmd );
       #print "</p>\n";
       printEndWorkingDiv( );
       if( $st != 0 ) {
           webLog "ERROR: Cannot '$cmd'\n";
           print "<p>\n";
           print "0 genes found.\n";
           print "</p>\n";
           printStatusLine( "0 genes found", 2 );
           wunlink( $tmpFile );
           return;
       }
       $rfh = newReadFileHandle( $tmpFile, "printPhyloSimResults" );
   }
   my $s = $rfh->getline( ); # skip header
   my @recs0;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      push( @recs0, $s );
   }
   $rfh->close( );
   if( scalar( @recs0 ) == 0 ) {
      print "<p>\n";
      print "0 genes found.\n";
      print "</p>\n";
      printStatusLine( "0 genes found", 2 );
      wunlink( $tmpFile );
      return;
   }
   printGeneCartFooter( );

   printAddQueryGeneCheckBox( $gene_oid );

   print "<table class='img'  border='1'>\n";
   print "<th class='img' >Select</th>\n";
   print "<th class='img' >Gene ID</th>\n";
   print "<th class='img' >Gene Product Name</th>\n";
   #print "<th class='img' >D</th>\n";
   #print "<th class='img' >Genome</th>\n";
   print "<th class='img' >% Occurrence Match</th>\n";
   print "<th class='img' >P-value</th>\n";
   my $count = 0;
   my @recs;
   for my $r( @recs0 ) {
      $count++;
      if( scalar( @recs ) > $maxBatchSize ) {
	 flushSimBatch( $dbh, \@recs );
         @recs = ( );
      }
      my( $gene_oid, $taxon_oid, $percIdent, $pvalue ) = split( /\t/, $r );
      my $rec = "$gene_oid\t";
      $rec .= "$percIdent\t";
      $rec .= "$pvalue";
      push( @recs, $rec );
   }
   flushSimBatch( $dbh, \@recs );
   print "</table>\n";
   #$dbh->disconnect();
   printStatusLine( "$count gene(s) retrieved", 2 );
   #wunlink( $tmpFile );
   #wunlink( $tmpMaskFile );
   if( $count > 10 ) {
      printGeneCartFooter( );
   }
   print end_form( );

   timeout( 60 * $default_timeout_mins );
}

############################################################################
# flushSimBatch - Flush one set of batch results.
############################################################################
sub flushSimBatch {
    my( $dbh, $recs_ref ) = @_;
    my @gene_oids;
    for my $r( @$recs_ref ) {
       my( $gene_oid, $percIdent ) = split( /\t/, $r );
       push( @gene_oids, $gene_oid );
    }
    return if( scalar( @gene_oids ) == 0 );
    my $gene_oid_str = join( ',', @gene_oids );
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select g.gene_oid, g.gene_display_name, tx.taxon_oid, 
          tx.domain, tx.taxon_display_name
       from gene g, taxon tx, taxon_stats ts
       where g.taxon = tx.taxon_oid
       and g.gene_oid in( $gene_oid_str )
       and g.obsolete_flag = 'No'
       and tx.taxon_oid = ts.taxon_oid
       $rclause
       $imgClause 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %geneRecs;
    for( ;; ) {
       my( $gene_oid, $gene_display_name, 
           $taxon_oid, $domain, $taxon_display_name ) = $cur->fetchrow( );
       last if !$gene_oid;

       my $domainLetter = substr( $domain, 0, 1 );
       my $rec = "$gene_oid\t";
       $rec .= "$gene_display_name\t";
       $rec .= "$taxon_oid\t";
       $rec .= "$domainLetter\t";
       $rec .= "$taxon_display_name";
       $geneRecs{ $gene_oid } = $rec;
    }
    $cur->finish( );
    for my $r( @$recs_ref ) {
       my( $gene_oid, $percIdent, $pvalue ) = split( /\t/, $r );
       my $geneRec = $geneRecs{ $gene_oid };
       my( $gene_oid2, $gene_display_name, $taxon_oid, 
          $domainLetter, $taxon_display_name ) = split( /\t/, $geneRec );
       print "<tr class='img' >\n";
       print "<td class='img' >\n";
       print "<input type='checkbox' name='gene_oid' value='$gene_oid'/>\n";
       print "</td>\n";
       my $url = "$main_cgi?section=GeneDetail" . 
          "&page=geneDetail&gene_oid=$gene_oid";
       print "<td class='img' >" . alink( $url, $gene_oid ) . "</td>\n";
       print "<td class='img' >" . escHtml( $gene_display_name ) . "</td>\n"; 
       my $url = "$main_cgi?section=TaxonDetail" . 
          "&page=taxonDetail&taxon_oid=$taxon_oid";
       my $percIdent2 = sprintf( "%3.1f%%", $percIdent * 100 );
       print "<td class='img'  align='right'>$percIdent2</td>\n";
       print "<td class='img'  align='right' nowrap>$pvalue</td>\n";
       print "</tr>\n";
    }
}

1;
