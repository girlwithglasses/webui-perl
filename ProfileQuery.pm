############################################################################
# ProfileQuery -  Query genes based on substraction and intersections
#   within function clusters.   
#  (The is the "function" version of the 
#   "gene base" "phylogenetic profiler", used mainly in IMG-lite
#   because precomputed gene/protein similarities are not available
#   in the lite version.)
#    --es 05/31/2006
############################################################################
package ProfileQuery;
my $section = "ProfileQuery";
use strict;
use CGI qw( :standard );
use DBI;
use ScaffoldPanel;
use Data::Dumper;
use Time::localtime;
use WebConfig;
use InnerTable;
use WebUtil;
use HtmlUtil;

$| = 1;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $cgi_url = $env->{ cgi_url };
my $base_dir = $env->{ base_dir };

my $taxon_stats_dir = $env->{ taxon_stats_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $img_internal = $env->{ img_internal };
my $include_metagenomes = $env->{ include_metagenomes };
my $img_lite = $env->{ img_lite };
my $gene_clusters_dir = $env->{ gene_clusters_dir };
my $max_gene_batch = 250;

my %funcType2Suffix = (
  "COG" => "cog",
  "Pfam" => "pfam",
  "Enzyme" => "enzyme",
  "TIGRfam" => "tfam",
);

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "profileQueryForm" ) {
	printProfileQueryForm( );
    }
    elsif( paramMatch( "profileQueryResults" ) ne "" ) {
	printProfileQueryResults( );
    }
    elsif( $page eq "profileQueryGenes" ) {
	printProfileQueryGenes( );
    }
    else {
        printProfileQueryForm( );
    }
}

############################################################################
# printProfileQueryForm  - Print query form for specifying the
#   profile to query on.
############################################################################
sub printProfileQueryForm {
    
    print "<h1>Profile Query (Experimental)</h1>\n";
    print "<p>\n";
    print "This tool allows you query for functions ";
    print "in a selected genome (or bin) ";
    print "based on<br/>\n";
    print "presence or absense of the same ";
    print "functions in other genomes.<br/>\n";
    print "(This tool is the <i>function</i> complement to ";
    print "the <i>gene</i> based <i>Phylogenetic Profiler</i>.)<br/>\n";
    print "<br/>\n";
    print domainLetterNote( 1 );
    print "</p>\n";

    my $dbh = dbLogin( );
    printMainForm( );

    print "<p>\n";

    print "Select <i>one</i> genome with <i>output</i> functions<br/>\n";
    printTaxonSelectionList( $dbh, "taxonOutputFuncs", 1 );
    print "<br/>\n";

    print "Select genomes where functions are <i>present</i><br/>\n";
    printTaxonSelectionList( $dbh, "taxonPresentFuncs" );
    print "<br/>\n";

    print "Select genomes where functions are <i>absent</i><br/>";
    printTaxonSelectionList( $dbh, "taxonAbsentFuncs" );

    print "</p>\n";

    print "<table class='img'  border=1>\n";
    print "<br/>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Function Type</th>\n";
    print "<td class='img' >\n";
    print popup_menu( -name => "funcType",
       -values => [ "COG", "Pfam", "Enzyme", "TIGRfam", ],
       -default => "COG" );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img' >\n";
    print popup_menu( -name => "maxEvalue",
        -values => [ "1e-2", "1e-5", "1e-10" ],
        -default => "1e-5" );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'>Min. Percent Identity</th>\n";
    print "<td class='img' >\n";
    print popup_menu( -name => "minPercIdent",
       -values => [ "10", "20", "30", "40", "50", "60", "70", "80", "90" ],
       -default => "30" );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    printJavaScriptReset( );

    print "<br/>\n";
    my $name = "_section_${section}_profileQueryResults";
    print submit( -name => $name,
       -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 );
    print "<input type='button' name='clearSelections' value='Reset' ";
    print "onClick='resetProfileQuerySelections()' class='smbutton' />\n";

    printHint( 
      "- Hold down control key (or command key in the case of the Mac) " .
      "to select multiple genomes.<br/>\n" .
      "- Drag down list to select all genomes.<br/>\n" .
      "- More genome and function selections result in slower query.<br/>\n".
      "- Percent identity and e-value cutoffs currently " .
      "apply only to COG and Pfam.<br/>" );


    #$dbh->disconnect();
    print end_form( );
}

############################################################################
# printTaxonSelectionList - Show phylogenetically ordered
#   taxon/bin selection list.
############################################################################
sub printTaxonSelectionList {
   my( $dbh, $id, $single ) = @_;

   my $hideViruses = getSessionParam( "hideViruses" );
   $hideViruses = "Yes" if $hideViruses eq "";
   my $virusClause;
   $virusClause = "and tx.domain not like 'Vir%'" if $hideViruses eq "Yes";

   my $hidePlasmids = getSessionParam( "hidePlasmids" );
   $hidePlasmids = "Yes" if $hidePlasmids eq "";
   my $plasmidClause;
   $plasmidClause = "and tx.domain not like 'Plasmid%' " 
      if $hidePlasmids eq "Yes";

   my $hideGFragment = getSessionParam("hideGFragment");
   $hideGFragment = "Yes" if $hideGFragment eq "";
   my $gFragmentClause;
   $gFragmentClause = "and tx.domain not like 'GFragment%' " 
      if $hideGFragment eq "Yes";


   my %defaultBins;
   getDefaultBins( $dbh, \%defaultBins );
   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $taxonClause = txsClause( "tx", $dbh );
   my $sql = qq{  
      select tx.domain, tx.taxon_oid, tx.taxon_display_name,
         b.bin_oid, b.display_name
      from taxon_stats ts, taxon tx
      left join env_sample_gold es
         on tx.env_sample = es.sample_oid     
      left join bin b
         on es.sample_oid = b.env_sample
      where tx.taxon_oid = ts.taxon_oid
      $rclause
      $imgClause
      $taxonClause
      $virusClause     
      $plasmidClause
      $gFragmentClause
      order by tx.domain, tx.taxon_display_name, tx.taxon_oid, 
         b.display_name
   };       
   my $cur = execSql( $dbh, $sql, $verbose );
   my $multiple = "multiple";
   $multiple = "" if $single;
   print "<select name='$id' size='10' $multiple>\n";
   my $old_domain;
   my $old_phylum;
   my $old_genus;
   my $old_taxon_oid;
   for( ;; ) {
      my( $domain, $taxon_oid, 
          $taxon_display_name, $bin_oid, $bin_display_name ) = 
	     $cur->fetchrow( );
      last if !$taxon_oid;
      if( $old_taxon_oid ne $taxon_oid ) {
          print "<option value='t:$taxon_oid'>\n";
          print escHtml( $taxon_display_name );
          my $d = substr( $domain, 0 , 1 );
          print " ($d)";
          print "</option>\n";
      }
      if( $bin_oid ne "" && $defaultBins{ $bin_oid } ) {
          print "<option value='b:$bin_oid'>\n";
          print "-- ";
          print escHtml( $bin_display_name );
          print " (b)";
          print "</option>\n";
      }
      $old_taxon_oid = $taxon_oid;
   }
   print "</select>\n";
   print "<script language='JavaScript' type='text/javascript'>\n";
   print qq{
      function clear_${id}_selections( ) {
         var selector = document.mainForm.$id;
         for( var i = 0; i < selector.length; i++ ) {
            var e = selector[ i ];
            e.selected = false;
         }
      }
   };
   print "</script>\n";
   print "<br/>\n";
}

############################################################################
# printJavaScriptReset - Print reset code in javascript.
############################################################################
sub printJavaScriptReset {
   print "<script language='JavaScript' type='text/javascript'>\n";
   print qq{
      function resetProfileQuerySelections( ) {
          clear_taxonOutputFuncs_selections( );
          clear_taxonPresentFuncs_selections( );
          clear_taxonAbsentFuncs_selections( );
          document.mainForm.funcType.selectedIndex = 0;
          document.mainForm.minPercIdent.selectedIndex = 2;
          document.mainForm.maxEvalue.selectedIndex = 1;
      }
   };
   print "</script>\n";
}

############################################################################
# printProfileQueryResults - Print results of profile query search.
############################################################################
sub printProfileQueryResults {

   print "<h1>Profile Query Results</h1>\n";

   my $funcType = param( "funcType" );
   my @taxonOutputFuncs = param( "taxonOutputFuncs" );
   my @taxonPresentFuncs = param( "taxonPresentFuncs" );
   my @taxonAbsentFuncs = param( "taxonAbsentFuncs" );

   if( scalar( @taxonOutputFuncs ) == 0 ) {
      webError( "Please select one output genome or bin." );
   }
   printStatusLine( "Loading ...",  1 );
   printMainForm( );
   my $dbh = dbLogin( );

   print "<p>\n";
   my %func2Genes;
   initOutputFuncs( $dbh, $funcType, \@taxonOutputFuncs, \%func2Genes );
   intersectFuncs( $dbh, $funcType, \@taxonPresentFuncs, \%func2Genes );
   subtractFuncs( $dbh, $funcType, \@taxonAbsentFuncs, \%func2Genes );
   print "</p>\n";

   my @funcIds = sort( keys( %func2Genes ) );
   my $nFuncs = @funcIds;
   if( $nFuncs == 0 ) {
       print "<p>\n";
       print "No functions remain after operations.<br/>\n";
       print "</p>\n";
       print end_form( );
       #$dbh->disconnect();
       printStatusLine( "0 function(s) retrieved", 2 );
       return;
   }
   my %id2Name;
   loadId2Name( $dbh, $funcType, \%id2Name );

   printTableResults( $dbh, $funcType, \%func2Genes, \%id2Name );

   printStatusLine( "$nFuncs function(s) retrieved.", 2 );
   print end_form( );
   #$dbh->disconnect();
}

############################################################################
# initOutputFuncs - Load output functions.
############################################################################
sub initOutputFuncs {
   my( $dbh, $funcType, $taxonOutputFuncs_ref, $func2Genes_ref ) = @_;

   for my $x( @$taxonOutputFuncs_ref ) {
      if( $x =~ /^t:/ ) {
	 $x =~ s/t://;
	 my $name = taxonOid2Name( $dbh, $x );
         my $nFuncs = 
	    loadOutputFuncs( $dbh, $funcType, $x, 0, $func2Genes_ref );
	 print "$nFuncs functions loaded for <i>" . 
	    escHtml( $name ) . "</i> ...<br/>\n";
      }
      elsif( $x =~ /^b:/ ) {
	 $x =~ s/b://;
	 my $taxon_oid = binOid2TaxonOid( $dbh, $x );
	 my $name = binOid2Name( $dbh, $x );
         my $nFuncs = loadOutputFuncs( $dbh, $funcType, $taxon_oid, $x,
            $func2Genes_ref );
	 print "$nFuncs functions loaded for <i>" . escHtml( $name ) . 
	    "</i> (bin) ...<br/>\n";
      }
   }
}


############################################################################
# loadOutputFuncs - Load output gene functions.
#  If the genes do not exist in output file, do not load it.
############################################################################
sub loadOutputFuncs {
    my( $dbh, $funcType, $taxon_oid, $bin_oid, $func2Genes_ref ) = @_;

    my %genes;
    loadValidGenes( $dbh, $taxon_oid, $bin_oid, \%genes );

    my $minPercIdent = param( "minPercIdent" );
    my $maxEvalue = param( "maxEvalue" );

    $taxon_oid = sanitizeInt( $taxon_oid );
    my $suffix = $funcType2Suffix{ $funcType };
    my $inFile = "$gene_clusters_dir/$taxon_oid.$suffix.tab.txt";
    if( !-e( $inFile ) ) {
       webLog( "loadOutputFuncs: cannot find '$inFile'\n" );
       return;
    }
    my $rfh = newReadFileHandle( $inFile, "loadOuputGeneFuncs" );
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $gene_oid, $id, $percIdent, $evalue ) = split( /\t/, $s );
       next if $genes{ $gene_oid } eq "";
       next if $percIdent < $minPercIdent;
       next if $evalue > $maxEvalue;
       $func2Genes_ref->{ $id } .= "$gene_oid ";
    }
    close $rfh;
    return funcCount( $func2Genes_ref );
}


############################################################################
# intersectFuncs - Intersect function lists.
############################################################################
sub intersectFuncs {
   my( $dbh, $funcType, $taxonPresentFuncs_ref, $func2Genes_ref ) = @_;

   for my $x( @$taxonPresentFuncs_ref ) {
      if( $x =~ /^t:/ ) {
	 $x =~ s/t://;
	 my $name = taxonOid2Name( $dbh, $x );
	 my $nFuncs = 
	     loadIntersectFuncs( $dbh, $funcType, $x, 0, $func2Genes_ref );
	 print "$nFuncs functions left intersecting with <i>" . 
	    escHtml( $name ) . "</i> ...<br/>\n";
      }
      elsif( $x =~ /^b:/ ) {
	 $x =~ s/b://;
	 my $taxon_oid = binOid2TaxonOid( $dbh, $x );
	 my $name = binOid2Name( $dbh, $x );
	 my $nFuncs = loadIntersectFuncs( $dbh, $funcType, 
	     $taxon_oid, $x, $func2Genes_ref );
	 print "$nFuncs functions left intersecting with <i>" . 
	     escHtml( $name ) . "</i> (bin) ...<br/>\n";
      }
   }
}

############################################################################
# loadIntersectFuncs - Load intersection functions.
############################################################################
sub loadIntersectFuncs {
    my( $dbh, $funcType, $taxon_oid, $bin_oid, $func2Genes_ref ) = @_;

    my $minPercIdent = param( "minPercIdent" );
    my $maxEvalue = param( "maxEvalue" );

    my %genes;
    loadValidGenes( $dbh, $taxon_oid, $bin_oid, \%genes );

    $taxon_oid = sanitizeInt( $taxon_oid );
    my $suffix = $funcType2Suffix{ $funcType };
    my $inFile = "$gene_clusters_dir/$taxon_oid.$suffix.tab.txt";
    if( !-e( $inFile ) ) {
       webLog( "loadIntersectFuncs: cannot find '$inFile'\n" );
       return;
    }
    my $rfh = newReadFileHandle( $inFile, "loadOuputGeneFuncs" );
    my %intersections;
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $gene_oid, $id, $percIdent, $evalue ) = split( /\t/, $s );
       next if $genes{ $gene_oid } eq "";
       next if $percIdent < $minPercIdent;
       next if $evalue > $maxEvalue;
       my $x = $func2Genes_ref->{ $id };
       if( $x ne "" ) {
	  $intersections{ $id } = $x;
       }
    }
    close $rfh;
    %$func2Genes_ref = %intersections;
    return funcCount( $func2Genes_ref );
}

############################################################################
# subtractFuncs - Subtract from genes list.
############################################################################
sub subtractFuncs {
   my( $dbh, $funcType, $taxonAbsentFuncs_ref, $func2Genes_ref ) = @_;

   for my $x( @$taxonAbsentFuncs_ref ) {
      if( $x =~ /^t:/ ) {
	 $x =~ s/t://;
	 my $name = taxonOid2Name( $dbh, $x );
	 my $nFuncs = 
	     loadSubtractionFuncs( $dbh, $funcType, $x, 0, $func2Genes_ref );
	 print "$nFuncs functions left subtracting from <i>" . 
	    escHtml( $name ) . "</i> ...<br/>\n";
      }
      elsif( $x =~ /^b:/ ) {
	 $x =~ s/b://;
	 my $taxon_oid = binOid2TaxonOid( $dbh, $x );
	 my $name = binOid2Name( $dbh, $x );
	 my $nFuncs = loadSubtractionFuncs( $dbh, $funcType, $taxon_oid, $x,
	    $func2Genes_ref );
	 print "$nFuncs functions left subtracting from <i>" . 
	     escHtml( $name ) . "</i> (bin) ...<br/>\n";
      }
   }
}

############################################################################
# loadSubtractionFuncs - Load intersection functions.
############################################################################
sub loadSubtractionFuncs {
    my( $dbh, $funcType, $taxon_oid, $bin_oid, $func2Genes_ref ) = @_;

    my $minPercIdent = param( "minPercIdent" );
    my $maxEvalue = param( "maxEvalue" );

    my %genes;
    loadValidGenes( $dbh, $taxon_oid, $bin_oid, \%genes );

    $taxon_oid = sanitizeInt( $taxon_oid );
    my $suffix = $funcType2Suffix{ $funcType };
    my $inFile = "$gene_clusters_dir/$taxon_oid.$suffix.tab.txt";
    if( !-e( $inFile ) ) {
       webLog( "loadIntersectFuncs: cannot find '$inFile'\n" );
       return;
    }
    my $rfh = newReadFileHandle( $inFile, "loadOuputGeneFuncs" );
    my %intersections;
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $gene_oid, $id, $percIdent, $evalue ) = split( /\t/, $s );
       next if $genes{ $gene_oid } eq "";
       next if $percIdent < $minPercIdent;
       next if $evalue > $maxEvalue;
       my $x = $func2Genes_ref->{ $id };
       next if $x eq "";
       delete $func2Genes_ref->{ $id };
    }
    close $rfh;
    return funcCount( $func2Genes_ref );
}

############################################################################
# loadValidGenes - Load genes that are valid for operations.
############################################################################
sub loadValidGenes {
    my( $dbh, $taxon_oid, $bin_oid, $genes_ref ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_bin = qq{
	select distinct g.gene_oid
	from gene g, bin_scaffolds bs
	where g.scaffold = bs.scaffold
	$rclause
	$imgClause
	and bs.bin_oid = $bin_oid
	and g.taxon = $taxon_oid
	and g.obsolete_flag = 'No'
    };
    my $sql_taxon = qq{
	select distinct g.gene_oid
	from gene g
	where g.taxon = $taxon_oid
        $rclause
        $imgClause
	and g.obsolete_flag = 'No'
    };
    my $sql = $sql_taxon;
    $sql = $sql_bin if $bin_oid > 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $gene_oid ) = $cur->fetchrow( );
	last if !$gene_oid;
	$genes_ref->{ $gene_oid } = 1;
    }
    $cur->finish( );
}

############################################################################
# loadId2Name - Map ID to name.
############################################################################
sub loadId2Name {
    my( $dbh, $funcType, $id2Name_ref ) = @_;

    my $sql_cog = qq{
	select cog_id, cog_name
	from cog
    };
    my $sql_pfam = qq{
	select ext_accession, name
	from pfam_family
    };
    my $sql_enzyme = qq{
	select ec_number, enzyme_name
	from enzyme
    };
    my $sql_tigrfam = qq{
	select ext_accession, expanded_name
	from tigrfam
    };
    my $sql = $sql_cog;
    $sql = $sql_pfam if $funcType eq "Pfam";
    $sql = $sql_enzyme if $funcType eq "Enzyme";
    $sql = $sql_tigrfam if $funcType eq "TIGRfam";
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $id, $name ) = $cur->fetchrow( );
       last if !$id;
       $id2Name_ref->{ $id } = $name;
    }
    $cur->finish( );
}

############################################################################
# printTableResults - Print table results.
############################################################################
sub printTableResults {
    my( $dbh, $funcType, $func2Genes_ref, $id2Name_ref ) = @_;

    my $taxonOutputFuncs = param( "taxonOutputFuncs" );
    my $minPercIdent = param( "minPercIdent" );
    my $maxEvalue =  param( "maxEvalue" );
    my @keys = sort( keys( %$func2Genes_ref ) );
    my @rows;
    for my $k( @keys ) {
       my $genes = $func2Genes_ref->{ $k };
       my $geneCount = countGenes( $genes );
       my $name = $id2Name_ref->{ $k };
       my $r = "$k\t";
       $r .= "$name\t";
       $r .= "$geneCount\t";
       push( @rows, $r );
    }
    my @rows2 = sort( @rows );
    my $nRows = @rows2;
    printCartFooter( $funcType );
    my $ct = new InnerTable( 0, "profileQuery$$", "profileQuery", 1 );
    $ct->addColSpec( "Selection" );
    $ct->addColSpec( "ID", "char asc", "left" );
    $ct->addColSpec( "Function Name", "char asc", "left" );
    $ct->addColSpec( "Gene<br/>Count", "number desc", "right" );
    my $sd = $ct->getSdDelim( );
    for my $r0( @rows2 ) {
       my( $id, $name, $geneCount ) = split( /\t/, $r0 );

       my $r;

       my $function;
       $function = "cog_id" if $funcType eq "COG";
       $function = "pfam_id" if $funcType eq "Pfam";
       $function = "ec_number" if $funcType eq "Enzyme";
       $function = "tigrfam_id" if $funcType eq "TIGRfam";
       $r .= $sd . "<input type='checkbox' name='$function' value='$id' />\t";

       $r .= "$id\t";
       $r .= "$name\t";

       my $url = "$section_cgi&page=profileQueryGenes";
       $url .= "&funcType=$funcType";
       $url .= "&id=$id";
       $url .= "&taxonOutputFuncs=$taxonOutputFuncs";
       $url .= "&minPercIdent=$minPercIdent";
       $url .= "&maxEvalue=$maxEvalue";
       $r .= $geneCount . $sd . alink( $url, $geneCount ) . "\t";

       $ct->addRow( $r );
    }
    $ct->printOuterTable( 1 );
    printCartFooter( $funcType ) if $nRows > 10;
}

############################################################################
# countGenes - Count genes in gene list.
############################################################################
sub countGenes {
    my( $s ) = @_;
    my $count = 0;
    my @a = split( / /, $s );
    for my $i ( @a ) {
       next if $i eq "";
       $count++;
    }
    return $count;
}

############################################################################
# funcCount - Count functions.
############################################################################
sub funcCount {
   my( $func2Genes_ref ) = @_;
   my @keys = keys( %$func2Genes_ref );
   my $nFuncs = @keys;
   return $nFuncs;
}

############################################################################
# printCartFooter - Type specific cart footer handler.
############################################################################
sub printCartFooter {
    my( $funcType ) = @_;
    
    if (  $funcType eq "COG" || $funcType eq "Pfam" || $funcType eq "TIGRfam" || $funcType eq "Enzyme" ) {
        WebUtil::printFuncCartFooter();
    }
}

############################################################################
# printProfileQueryGenes  - Print profile query gene list if a 
#   user select a "function" output result.
############################################################################
sub printProfileQueryGenes {
     my $funcType = param( "funcType" );
     my $id = param( "id" );
     my $taxonOutputFuncs = param( "taxonOutputFuncs" );
     my $minPercIdent = param( "minPercIdent" );
     my $maxEvalue = param( "maxEvalue" );

     my $taxBin = $taxonOutputFuncs;
     my $taxon_oid;
     my $bin_oid;
     if( $taxBin =~ /^t:/ ) {
	$taxon_oid = $taxBin;
	$taxon_oid =~ s/^t://;
     }
     if( $taxBin =~ /^b:/ ) {
	$bin_oid = $taxBin;
	$bin_oid =~ s/^b://;
     }
     printStatusLine( "Loading ...",  1 );

     my $dbh = dbLogin( );

     my $rclause   = WebUtil::urClause('g.taxon');
     my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
     my $sql_cog_taxon = qq{
	select distinct g.gene_oid
	from gene g, gene_cog_groups gcg
	where g.gene_oid = gcg.gene_oid
	$rclause
	$imgClause
	and g.taxon = $taxon_oid
	and gcg.cog = '$id'
	and gcg.rank_order = 1
	and gcg.percent_identity >= $minPercIdent
	and gcg.evalue <= $maxEvalue
     };
     my $sql_cog_bin = qq{
	select distinct g.gene_oid
	from gene g, bin_scaffolds bs, gene_cog_groups gcg
	where g.scaffold = bs.scaffold
        $rclause
        $imgClause
	and g.gene_oid = gcg.gene_oid
	and gcg.cog = '$id'
	and gcg.rank_order = 1
	and gcg.percent_identity >= $minPercIdent
	and gcg.evalue <= $maxEvalue
	and bs.bin_oid = $bin_oid
     };
     my $sql_pfam_taxon = qq{
	select distinct g.gene_oid
	from gene g, gene_pfam_families gpf
	where g.gene_oid = gpf.gene_oid
        $rclause
        $imgClause
	and gpf.pfam_family = '$id'
	and gpf.percent_identity >= $minPercIdent
	and gpf.evalue <= $maxEvalue
	and g.taxon = $taxon_oid
     };
     my $sql_pfam_bin = qq{
	select distinct g.gene_oid
	from gene g, gene_pfam_families gpf, bin_scaffolds bs
	where g.gene_oid = gpf.gene_oid
        $rclause
        $imgClause
	and gpf.pfam_family = '$id'
	and gpf.percent_identity >= $minPercIdent
	and gpf.evalue <= $maxEvalue
	and g.scaffold = bs.scaffold
	and bs.bin_oid = $bin_oid
     };
     my $sql_enzyme_taxon = qq{
	select distinct g.gene_oid
	from gene g, gene_ko_enzymes ge
	where g.gene_oid = ge.gene_oid
        $rclause
        $imgClause
	and g.taxon = $taxon_oid
	and ge.enzymes = '$id'
     };
     my $sql_enzyme_bin = qq{
	select distinct g.gene_oid
	from gene g, gene_ko_enzymes ge, bin_scaffolds bs
	where g.gene_oid = ge.gene_oid
        $rclause
        $imgClause
	and ge.enzymes = '$id'
	and g.scaffold = bs.scaffold
	and bs.bin_oid = $bin_oid
     };
     my $sql_tigrfam_taxon = qq{
	select distinct g.gene_oid 
	from gene g, gene_tigrfams
	where g.gene_oid = gtf.gene_oid
        $rclause
        $imgClause
	and g.taxon = $taxon_oid
	and gtf.ext_accession = '$id'
     };
     my $sql_tigrfam_bin = qq{
	select distinct g.gene_oid 
	from gene g, gene_tigrfams gtf, bin_scaffolds bs
	where g.gene_oid = gtf.gene_oid
        $rclause
        $imgClause
	and gtf.ext_accession = '$id'
	and g.scaffold = bs.scaffold
	and bs.bin_oid = $bin_oid
     };
     my $sql;
     $sql = $sql_cog_taxon if $funcType eq "COG" && $taxon_oid ne "";
     $sql = $sql_cog_bin if $funcType eq "COG" && $bin_oid ne "";
     $sql = $sql_pfam_taxon if $funcType eq "Pfam" && $taxon_oid ne "";
     $sql = $sql_pfam_bin if $funcType eq "Pfam" && $bin_oid ne "";
     $sql = $sql_enzyme_taxon if $funcType eq "Enzyme" && $taxon_oid ne "";
     $sql = $sql_enzyme_bin if $funcType eq "Enzyme" && $bin_oid ne "";
     $sql = $sql_tigrfam_taxon if $funcType eq "TIGRfam" && $taxon_oid ne "";
     $sql = $sql_tigrfam_bin if $funcType eq "TIGRfam" && $bin_oid ne "";
     my @gene_oids;
     my $cur = execSql( $dbh, $sql, $verbose );
     for( ;; ) {
    	my( $gene_oid ) = $cur->fetchrow( );
    	last if !$gene_oid;
    	push( @gene_oids, $gene_oid );
     }
     $cur->finish();
    
     my $count = scalar(@gene_oids);
     if( $count == 1 ) {
    	 require GeneDetail;
    	 GeneDetail::printGeneDetail( $gene_oids[ 0 ] );
    	 return;
     }

     printMainForm( );
     print "<h1>Profile Query Genes for "  . escHtml( $id ) . "</h1>\n";
     printGeneCartFooter() if $count > 10;
     HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
     printGeneCartFooter();

     printStatusLine( "$count gene(s) retrieved.", 2 );
     print end_form( );
}

1;
