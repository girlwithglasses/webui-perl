############################################################################
# FindGenesLucy.pm - Find genes implementation using Lucy search
#  --es 07/17/13
############################################################################
package FindGenesLucy;
my $section = "FindGenesLucy";

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use Data::Dumper;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;               # added for YUI datatable conversion +BSJ 11/17/09
use TreeViewFrame;
use GenomeListFilter;
use GeneTableConfiguration;
use MerFsUtil;
use MetaUtil;
use HashUtil;
use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Analysis::PolyAnalyzer;
use Lucy::Plan::FullTextType;
use GenomeCart;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $img_internal          = $env->{img_internal};
my $tmp_dir               = $env->{tmp_dir};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $web_data_dir          = $env->{web_data_dir};
my $taxon_faa_dir         = "$web_data_dir/taxon.faa";
my $kegg_orthology_url    = $env->{kegg_orthology_url};
my $swiss_prot_base_url   = $env->{swiss_prot_base_url};
my $user_restricted_site  = $env->{user_restricted_site};
my $no_restricted_message = $env->{no_restricted_message};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes   = $env->{include_metagenomes};
my $include_img_terms     = $env->{include_img_terms};
my $show_myimg_login      = $env->{show_myimg_login};
my $mer_data_dir          = $env->{mer_data_dir};
my $search_dir            = $env->{search_dir};
my $sandbox_lucy_dir      = $env->{sandbox_lucy_dir};
my $flank_length          = 25000;
my $max_batch             = 100;
my $max_rows              = 1000;
my $max_seq_display       = 30;
my $grep_bin              = $env->{grep_bin};
my $rdbms                 = getRdbms();
my $in_file               = $env->{in_file};
my $http_solr_url         = $env->{ http_solr_url };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes

    my $page = param( "page" );
    if ( paramMatch("fgFindGenesLucy") ne '' ) {
        my $genomeFilter = param( "genomeFilter" );
	if( !blankStr( $genomeFilter ) ) {
	    printTaxonSelections( );
	}
	else {
	    my $outFmt = param( "outFmt" );
	    if( $outFmt eq "summary" ) {
	        printFuncSummary( );
	    }
	    else {
	        printGeneList( );
	    }
	}
    } 
    elsif( $page eq "summaryGeneList" ) {
        printSummaryGeneList( );
    }
    elsif( $page eq "summaryTaxonList" ) {
        printSummaryTaxonList( );
    }
    else {
        printQueryForm();
    }
}

############################################################################
# printQueryForm - Print input search query form.
############################################################################
sub printQueryForm {

   print qq{
    <form class='alignleft' method='post' action='$main_cgi'
       enctype='application/x-www-form-urlencoded' name='findGenesLucyForm'>
    <h1>Gene Search by Keyword or Phrase (Experimental)</h1>
    <p>
    Find genes in selected genomes by keyword.
    Please enter keyword pertaining to selected gene 
    or pathway type from the checkboxes below.   <br/>
    <br/>
    (This experimental setup uses Perl's Lucy, a version
     of Lucene keyword search, which should run faster than
     Oracle database searches when the top N values allowed are small.<br/>
     Selecting specific (meta)genomes through the Genome Filter specification
     is also usually faster.<br/>
     It also demonstrates a new user interface that
     allows more flexibility in specifying a combination of search options.
     Also, genome selection does not require loading a large scroll list
     of genomes, which is now becoming unwieldy to load and select from.
     Rather the user can type in a phrase, and from the phrase, 
     select from a much smaller candidate list of genomes.)
    </p>
    <table class='img' border="0" width="400">
    <tr class='img'>
    <th class="subhead">Keyword</th>
    <td>
    <input type="text" name="searchTerm" style="min-width:281px" /></td>
    </tr>
    <tr>
    <th class='subhead'>Genome Filter<sup>1</sup></th>
    <td>
    <input type="text" name="genomeFilter" style="min-width:281px" /></td>
    </td>
    </tr>
    </table>
     <br>
     <font size='-1'>
   };
   my $url = "${main_cgi}?section=TaxonList&page=taxonList";
   print alink( $url, "Genome Browser" );
   print nbsp( 1 );
   print qq{ (Right click on the link to open a new window
     if you need a reference page.) };

   printHint( qq{ 
       1 - E.g. genome filter values:
          'proteobacteria', 'firmicutes', 'pseudomonas', '
         'O104:H4', 'wetland', 'soil', 'b2 cattail', submission_id '6541',
	 taxon_oid '3300000100'<br/> 
	 More specific filter values will result in smaller
	 candidate list.  <br/>
	 If no entry is specified,
	 all isolates and non-MER-FS genomes are assumed.<br/>
	 MER-FS metagenomes requires an explict selection.  <br/>
	 The genome search string
	 will result in a candidate list of (meta)genomes to select
	 from in the next page.
     </br>
     </font>
   } );
   print hiddenVar( "section", $section );

   print "<h2>Gene Level</h2>\n";
   print "<table class='img' border=1>\n";
   print "<th class='subhead'>Selection</th>\n";
   print "<th class='subhead'>Type</th>\n";
   print "<th class='subhead'>Comments</th>\n";
   printRowCheckBox3( "Gene", "func", "gene_product",
      "Gene object identifier, locus tag, gene symbol, ".
      "product name keyword.<br/>E.g., '2506702098', 'EschW_0005', ".
      "'rpsJ', 'shikimate'.", 1 );
   printRowCheckBox3( "COG", "func", "cog",
      "E.g., 'COG0036', 'methylase'" );
   printRowCheckBox3( "KOG", "func", "kog",
      "E.g., 'KOG0020', 'dehydrogenase'" );
   printRowCheckBox3( "Pfam", "func", "pfam",
      "E.g., 'pfam00061', 'lys', 'permease'" );
   printRowCheckBox3( "TIGRfam", "func", "tfam",
      "E.g., 'TIGR00008', 'GTP', 'gtp', 'RecB', 'ribonuclease'" );
   printRowCheckBox3( "KO", "func", "ko",
      "KEGG orthology term. E.g., 'KO:K00957', 'malate'" );
   printRowCheckBox3( "EC", "func", "ec",
      "Enzyme Commision. E.g., 'EC:1.1.1.103', 'transferase'" );
   printRowCheckBox3( "TC", "func", "tc",
      "Transporter Classificaiton. E.g., 'TC:1.A.10', 'glutaamte'" );
   printRowCheckBox3( "IPR", "func", "ipr",
      "InterPro. E.g., 'IPR007859', 'polymerase'" );
   printRowCheckBox3( "GO", "func", "go",
      "Gene Ontology. E.g., 'GO:0003887', 'magnesium'" );
   printRowCheckBox3( "MyGene", "func", "myimg",
      "MyIMG Gene. E.g., 'phosphatase' ". 
      "(if indeed this annotation belongs to you)" );
   printRowCheckBox3( "ITerm", "func", "iterm",
      "IMG Term and Synonyms. E.g., '7419', 'carboxyethyl'" );
   printRowCheckBox3( "SEED", "func", "seed",
      "SEED name or subsystem. E.g., 'transposase', 'Purine_conversions'" );
   printRowCheckBox3( "SwissProt", "func", "swissprot",
      "SwissProt names. E.g., 'adenosine', 'clp'" );

   print "</table>\n";

   print "<h2>Pathway Level</h2>\n";
   print "<table class='img' border=1>\n";
   print "<th class='subhead'>Selection</th>\n";
   print "<th class='subhead'>Type</th>\n";
   print "<th class='subhead'>Comments</th>\n";
   printRowCheckBox3( "KEGG", "func", "kegg",
      "Kyoto Encyclopedia of Genes and Genomes. E.g., 'carbohydrate', 'atp'" );
   printRowCheckBox3( "MetaCyc", "func", "metacyc",
      "E.g., 'glucosinolate', 'atp'" );
   printRowCheckBox3( "IPWAY", "func", "ipway",
      "IMG Pathway: E.g., '229', 'hydrolysis'" );
   printRowCheckBox3( "IPART", "func", "ipart",
      "IMG Parts List: E.g., '28', 'ribosome'" );

   print "</table>\n";

   print "<h2>Genome</h2>\n";

   my $metagClause;
   $metagClause = "The Metagenome option can make the search very slow."
      if $include_metagenomes;
   print qq{
      <p>(
      This part is active only when no Genome Filter is specified.
      $metagClause
      )</p>
   };
   print "<b>Sequencing Status</b>:<br/>\n";
   print "<table border=0>\n";
   printRowCheckBox2( "seq_status", "Finished", 1 );
   printRowCheckBox2( "seq_status", "Draft", 1 );
   printRowCheckBox2( "seq_status", "Permanent Draft", 1 );
   print "</table>\n";
   print "<br/>\n";

   print "<b>Domain</b>:<br/>\n";
   print "<table border=0>\n";
   printRowCheckBox2( "domain", "Bacteria", 1 );
   printRowCheckBox2( "domain", "Archaea", 1 );
   printRowCheckBox2( "domain", "Eukaryota", 1 );
   printRowCheckBox2( "domain", "Virus", 1 );
   printRowCheckBox2( "domain", "Metagenome", 0 ) if $include_metagenomes;
   print "</table>\n";

   print "<h2>Display Options</h2>\n";

   print hiddenVar( "outFmt", "list" );
   #print "<b>Display Options</b>:<br/>\n";
   # Function summary is not faster than current UI and
   # is only partial.
   #print "<table border=0>\n";
   #printRadioBox2( "outFmt", "list", "Gene List", 1 );
   #printRadioBox2( "outFmt", "summary", "Function Summary", 0 );
   #print "</table>\n";
   #print "<br/>\n";

   print "<b>Top N hits per Function Type</b>:<br/>\n";
   print qq{
      <p>
      (This is very critical to speed of operations.
      Smaller numbers result in faster searches.)
      </p>
   };
   print "<select name='top_n'>\n";
   print "<option value='100'>100</option>\n";
   print "<option value='1000'>1000</option>\n";
   print "<option value='10000'>10000</option>\n";
   print "<option value='100000'>100000</option>\n";
   print "</select>\n";

   printHint( qq{
      If the <i>Genome Filter</i> is filled in,
      the next page will take you a candidate list of
      (meta)genomes that match the substring in the genome filter.
      You can select these genomes precisely and explicitly by clicking
      on the checkboxes.
   } );
   print "<br/>\n";

   print qq{
        <input id="go" class="smdefbutton" type="submit" 
	   name="fgFindGenesLucy" value="Go" />
       <input id="reset" class="smbutton" type="reset" name=".reset" 
       value="Reset" />
       </form>
   };


}

############################################################################
# printRowCheckBox3
############################################################################
sub printRowCheckBox3 {
   my( $tag, $name, $val, $comment, $checked ) = @_;

   print "<tr>\n";
   my $x;
   $x = "checked" if $checked;
   print "<td><input type='checkbox' name='$name' value='$val' $x/></td>\n";
   print "<td><b>$tag</b></td>\n";
   print "<td><i>$comment</i></td>\n";
   print "</tr>\n";
}
############################################################################
# printRowCheckBox2
############################################################################
sub printRowCheckBox2 {
   my( $name, $val, $checked ) = @_;

   print "<tr>\n";
   my $x;
   $x = "checked" if $checked;
   print "<td><input type='checkbox' name='$name' value='$val' $x/></td>\n";
   print "<td>$val</td>\n";
   print "</tr>\n";
}

############################################################################
# printRadioBox2
############################################################################
sub printRadioBox2 {
   my( $name, $val, $label, $checked ) = @_;

   print "<tr>\n";
   my $x;
   $x = "checked" if $checked;
   print "<td><input type='radio' name='$name' value='$val' $x/></td>\n";
   print "<td>$label</td>\n";
   print "</tr>\n";
}

############################################################################
# newSearcher
############################################################################
sub newSearcher {
   my( $inDir ) = @_;

   my $searcher = Lucy::Search::IndexSearcher->new(
      index => $inDir,
   );
   return $searcher;
}

############################################################################
# newHits
############################################################################
sub newHits {
   my( $inDir, $term, $top_n, $offset ) = @_;

   my $srch = newSearcher( $inDir );
   my $hits = $srch->hits(
       query => $term,
       offset => $offset,
       num_wanted => $top_n
   );
   return $hits;
}

############################################################################
# printTaxonSelections - Print candidate taxon selections.
############################################################################
sub printTaxonSelections {
    
    my $searchTerm = param( "searchTerm" );
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my $genomeFilter = param( "genomeFilter" );
    my $genomeFilterLc = lc( $genomeFilter );
    my @seq_status = param( "seq_status" );
    my $nSeqStatus = @seq_status;
    my @domain = param( "domain" );
    my $nDomains = @domain;
    my @funcs = param( "func" );
    my $nFuncs = @funcs;
    my $top_n = param( "top_n" );

    print "<h1>Genome Selections (cont.)</h1>\n";
    print qq{
    <form class='alignleft' method='post' action='$main_cgi'
       enctype='application/x-www-form-urlencoded' name='taxonForm'>
    };
    print hiddenVar( "section", $section );
    #print hiddenVar( "searchTerm", $searchTerm );


    if( blankStr( $searchTerm ) ) {
        printStatusLine( "Error.", 2 );
	webError( "No search term specified." );
	return;
    }
    if( blankStr( $genomeFilter ) ) {
        printStatusLine( "Error.", 2 );
	webError( "No genome filter specified." );
	return;
    }
    if( $nFuncs ==  0 ) {
        printStatusLine( "Error.", 2 );
	webError( "No functions specified." );
	return;
    }
    for my $func( @funcs ) {
       print hiddenVar( "func", $func );
    }
    print hiddenVar( "top_n", $top_n );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin( );
    my $domainClause;
    if( $nDomains > 0 ) {
       $domainClause = "and (";
       for my $d( @domain ) {
	  $d = "Microbiome" if $d eq "Metagenome";
          $domainClause .= "tx.domain like '%$d' or ";
       }
       chop $domainClause;
       chop $domainClause;
       chop $domainClause;
       chop $domainClause;
       $domainClause .= ")";
    }
    my $seqStatusClause;
    if( $nSeqStatus > 0 ) {
       $seqStatusClause = "and tx.seq_status in(";
       for my $ss( @seq_status ) {
          $seqStatusClause .=  "'$ss',";
       }
       chop $seqStatusClause;
       $seqStatusClause .= ")";
    }
    # Inactivate this part
    $domainClause = "";
    $seqStatusClause = "";

    my $idClause;
    $idClause = "or tx.taxon_oid = $genomeFilter or ".
       "tx.submission_id = $genomeFilter" if isInt( $genomeFilter );

    my $rclause = urClause( "tx" );
    my $sql = qq{
        select tx.taxon_oid, tx.submission_id,
	    tx.domain, tx.phylum, tx.ir_class, 
	    tx.taxon_display_name, tx.seq_status
	from taxon tx
	where ( lower( tx.phylum ) like ? or
	        lower( tx.ir_class ) like ? or
		lower( tx.taxon_display_name ) like ? )
	$idClause
        $domainClause
	$seqStatusClause
	$rclause
	and tx.obsolete_flag = 'No'
	order by tx.taxon_oid
    };
    my $lc = "%$genomeFilterLc%";
    my $cur = execSql( $dbh, $sql, $verbose, $lc, $lc, $lc );
    my @rows;
    for( ;; ) {
       my( $taxon_oid, $submission_id, $domain, $phylum, $ir_class, 
           $taxon_display_name, $seq_status ) = $cur->fetchrow( );
       last if !$taxon_oid;
       my $r = "$taxon_oid\t";
       $r .= "$submission_id\t";
       $r .= "$domain\t";
       $r .= "$phylum\t";
       $r .= "$ir_class\t";
       $r .= "$taxon_display_name\t";
       $r .= "$seq_status\t";
       push( @rows, $r );
    }
    my $nRows = @rows;
    if( $nRows == 0 ) {
       printStatusLine( "Loaded.". 2 );
       webError( "No rows found for genome filter string ".
          "<i>'$genomeFilter'</i> and other genome selections." );
       $dbh->disconnect( );
       return;
    }
    print qq{
       <p>
       <b>Search Term:</b>:
       <input type="text" name="searchTerm" value='$searchTerm' 
          style="min-width:281px" />
       <p>
    };
    print qq{
       <p>
       Select one or more genomes from the filtered list.
       </p>
    };
    my $it = new InnerTable( 1, "taxonList$$", "taxonList", 1 );
    my $sd = $it->getSdDelim( );

    $it->addColSpec( "Selection", "", "center" );
    $it->addColSpec( "Domain", "asc" );
    $it->addColSpec( "Status", "asc" );
    $it->addColSpec( "Taxon<br/>Object<br/>Identifier", "asc" );
    $it->addColSpec( "Submission<br/>ID", "asc" );
    $it->addColSpec( "Taxon Name", "asc" );
    $it->addColSpec( "Lineage / Metadata", "asc" );

    my $count = 0;
    for my $row( @rows ) {
       my( $taxon_oid, $submission_id, $domain, $phylum, $ir_class, 
           $taxon_display_name, $seq_status ) = split( /\t/, $row );
       my $d = substr( $domain, 0, 1 );
       my $ss = substr( $seq_status, 0, 1 );
       my $r;

       $r .= $sd . "<input type='checkbox' name='taxon_oid' ".
          "value='$taxon_oid' />\t";

       $r .= "$d\t";
       $r .= "$ss\t";

       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
          "&taxon_oid=$taxon_oid";
       my $matchText = highlightMatchHTML2( $taxon_oid, $genomeFilter );
       my $link = alink( $url, $matchText, $$, 1 );
       $r .= $taxon_oid . $sd . "$link\t";

       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
          "&taxon_oid=$taxon_oid";
       my $matchText = highlightMatchHTML2( $submission_id, $genomeFilter );
       my $link = alink( $url, $matchText, $$, 1 );
       $r .= $submission_id . $sd . "$link\t";


       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
          "&taxon_oid=$taxon_oid";
       my $matchText = highlightMatchHTML2( $taxon_display_name, 
          $genomeFilter );
       my $link = alink( $url, $matchText, $$, 1 );
       $r .= $taxon_display_name . $sd . "$link\t";

       my $lineage = "$domain; $phylum; $ir_class";
       my $matchText = highlightMatchHTML2( $lineage, $genomeFilter );
       $r .= $lineage . $sd . "$matchText\t";

       $it->addRow( $r );
    }
    $it->printOuterTable( 1 );

    print "<br/>\n";
    print qq{
        <input id="go" class="smdefbutton" type="submit" 
	   name="fgFindGenesLucy" value="Go" />
       <input id="reset" class="smbutton" type="reset" name=".reset" 
       value="Reset" />
    };
    printStatusLine( "$nRows genome(s) loaded.". 2 );
    $dbh->disconnect( );

}

############################################################################
# getValidTaxons
############################################################################
sub getValidTaxons {
    my( $dbh ) = @_;

    my @seq_status = param( "seq_status" );
    my $nSeqStatus = @seq_status;
    my @domain = param( "domain" );
    my $nDomains = @domain;

    my @taxon_oid = param( "taxon_oid" );
    my $nSelected = @taxon_oid;
    if( $nSelected > 0 ) {
       my %h;
       for my $toid( @taxon_oid ) {
          $h{ $toid } = $toid;
       }
       return %h;
    }
    else {
        my $domainClause;
        if( $nDomains > 0 ) {
           $domainClause = "and (";
           for my $d( @domain ) {
	      $d = "Microbiome" if $d eq "Metagenome";
              $domainClause .= "tx.domain like '%$d' or ";
           }
           chop $domainClause;
           chop $domainClause;
           chop $domainClause;
           chop $domainClause;
           $domainClause .= ")";
        }
        my $seqStatusClause;
        if( $nSeqStatus > 0 ) {
           $seqStatusClause = "and tx.seq_status in(";
           for my $ss( @seq_status ) {
              $seqStatusClause .=  "'$ss',";
           }
           chop $seqStatusClause;
           $seqStatusClause .= ")";
        }
	my $rclause = urClause( "tx" );
        my $sql = qq{
            select tx.taxon_oid
	    from taxon tx
	    where tx.obsolete_flag = 'No'
            $domainClause
	    $seqStatusClause
	    $rclause
	    order by tx.taxon_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	my %h;
	for( ;; ) {
	    my( $taxon_oid ) = $cur->fetchrow( );
	    last if !$taxon_oid;
	    $h{ $taxon_oid } = 1;
	}
	return %h;
    }
}

############################################################################
# splitOraFsTaxons - Splits into 2 sets of Oralce and MER-FS taxons
############################################################################
sub splitOraFsTaxons {
   my( $dbh, $inTaxonOids_aref, $outOraTaxons_aref, $outFsTaxons_aref ) = @_;

   my @selectedTaxons = param( "taxon_oid" );
   my $nSelected = @selectedTaxons;
   my %selectedTaxons_h;
   for my $taxon_oid( @selectedTaxons ) {
      $selectedTaxons_h{ $taxon_oid } = 1;
   }
   my $sql = qq{
       select taxon_oid from taxon
       where in_file = 'Yes' and obsolete_flag = 'No'
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   my %merFsTaxons;
   for( ;; ) {
       my( $taxon_oid ) = $cur->fetchrow( );
       last if !$taxon_oid;
       $merFsTaxons{ $taxon_oid } = 1;
   }
   $cur->finish( );
   my( $nOra, $nFs );
   for my $taxon_oid( @$inTaxonOids_aref ) {
      if( $merFsTaxons{ $taxon_oid } ) {
	 next if !$selectedTaxons_h{ $taxon_oid };
         push( @$outFsTaxons_aref, $taxon_oid );
	 webLog( "MER-FS taxon='$taxon_oid\n" );
	 $nFs++;
      }
      else {
	 next if $nSelected > 0 && !$selectedTaxons_h{ $taxon_oid };
         push( @$outOraTaxons_aref, $taxon_oid );
	 #webLog( "Oracle taxon='$taxon_oid\n" );
	 $nOra++;
      }
   }
   return( $nOra, $nFs );
}

############################################################################
# printFuncSummary
############################################################################
sub printFuncSummary {
    my $searchTerm = param( "searchTerm" );
    my @funcs = param( "func" );

    print "<h1>Function Summary  Results</h1>\n";
    print qq{
       <form class='alignleft' method='post' action='$main_cgi'
         enctype='application/x-www-form-urlencoded' name='funcSummaryForm'>
    };
    if( blankStr( $searchTerm ) ) {
        printStatusLine( "Error.", 2 );
	webError( "No search term specified." );
	return;
    }
    my $nFuncs = @funcs;
    if( $nFuncs == 0 ) {
        printStatusLine( "Error.", 2 );
	webError( "No functions specified." );
	return;
    }
    print hiddenVar( "searchTerm", $searchTerm );
   
    my $dbh = dbLogin( );

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv( );

    my @outRows;
    getListResults( $dbh, \@outRows );
    print "Get taxon information ...<br/>\n";
    my %taxonInfo;
    taxonInfoMap( $dbh, \%taxonInfo );


    my $nRows = @outRows;
    if( $nRows == 0 ) {
        printEndWorkingDiv( );
    	WebUtil::printNoHitMessage( );
    	printStatusLine( "0 genes retrieved", 2 );
        print end_form( );
    	$dbh->disconnect( );
        return;
    }
    my $sid = getSessionId( );
    #my $sdbId = "$sid.$$";
    my $sdbId = "$$";
    print hiddenVar( "sdbId", $sdbId );
    my $sdbFile = "$cgi_tmp_dir/lucy.$sdbId.sdb";
    print "Create summary database file ...<br/>\n";
    my $sdbh = WebUtil::sdbLogin( $sdbFile, "w" );
    my $sql = qq{
       create table gene(
          taxau varchar(20),
	  gene_oid varchar(80),
	  locus_tag varchar(80),
	  locus_type varchar(10),
          gene_symbol varchar(30),
          func_type varchar(30),
          func_id varchar(60),
          func_symbol varchar(60),
          func_name varchar(255),
	  enzymes varhcar(255)
       )
    };
    execSqlOnly( $sdbh, $sql, $verbose );
    my $sql = qq{
       insert into gene( taxau, gene_oid, locus_tag, locus_type, gene_symbol,
                         func_type, func_id, func_symbol, func_name, enzymes )
                   values( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
    };
    my $cur = prepSql( $sdbh, $sql, $verbose );
    my $count = 0;
    print "Load data ...<br/>\n";
    for my $row( @outRows ) {
        my( $taxau, $gene_oid, $locus_tag, $locus_type, $gene_symbol,
	    $func_type, $func_id, $func_symbol, $func_name,
	    $enzymes ) = split( /\t/, $row );
        execStmt( $cur, $taxau, $gene_oid, $locus_tag, $locus_type,
	   $gene_symbol, $func_type, $func_id, $func_symbol, $func_name,
	   $enzymes );
        $count++;
    }
    webLog( "$count rows loaded into '$sdbFile'\n" );
    print "Create Indices ...<br/>\n";
    execSqlOnly( $sdbh, 
       "create index func_type_idx on gene(func_type)", $verbose );
    execSqlOnly( $sdbh, 
       "create index taxau_idx on gene(taxau)", $verbose );
    execSqlOnly( $sdbh, 
       "create index gene_oid_idx on gene(gene_oid)", $verbose );
    print "Create summary statistics ...<br/>\n";
    my $sql = qq{
        select func_type, count(distinct gene_oid), count(distinct taxau)
	from gene
	group by func_type
	order by func_type
    };
    my $cur = execSql( $sdbh, $sql, $verbose );
    my %funcTypeMap = ( 
       gene_product => "Gene Product",
       EC => "Enzymes",
    );
    printEndWorkingDiv( );

    print "<table class='img' border='1'>\n";
    print "<th class='subhead'>Function Type</th>\n";
    print "<th class='subhead'>Gene<br/>Count</th>\n";
    print "<th class='subhead'>Genome<br/>Count</th>\n";
    for( ;; ) {
       my( $func_type, $gene_cnt, $taxon_cnt ) = $cur->fetchrow( );
       last if !$func_type;
       my $func_type2 = $funcTypeMap{ $func_type };
       $func_type2 = $func_type if $func_type2 eq "";
       print "<tr class='img'>\n";
       print "<td class='img'>$func_type2</td>\n";

       my $sterm = massageToUrl( $searchTerm );
       my  $url = "$main_cgi?section=FindGenesLucy&page=summaryGeneList".
         "&sdbId=$sdbId&func_type=$func_type&searchTerm=$sterm";
       my $link = alink( $url, $gene_cnt );
       print "<td class='img' align='right'>$link</td>\n";

       my  $url = "$main_cgi?section=FindGenesLucy&page=summaryTaxonList".
         "&sdbId=$sdbId&func_type=$func_type&$searchTerm=$sterm";
       my $link = alink( $url, $taxon_cnt );
       print "<td class='img' align='right'>$link</td>\n";

       print "</tr>\n";
    }
    print "</table>\n";
    $sdbh->disconnect( );


    $dbh->disconnect( );
    printStatusLine( "Loaded.", 2 );
    print end_form( );
}

############################################################################
# printSummaryGeneList
############################################################################
sub printSummaryGeneList {
    my $searchTerm = param( "searchTerm" );
    my $sdbId = param( "sdbId" );
    my $func_type = param( "func_type" );
    my $sdbFile = "$cgi_tmp_dir/lucy.$sdbId.sdb";
    my $sdbh = WebUtil::sdbLogin( $sdbFile );

    print "<h1>Function Summary Gene List</h1>\n";
    print qq{
       <form class='alignleft' method='post' action='$main_cgi'
         enctype='application/x-www-form-urlencoded' 
	 name='funcSummaryGeneListForm'>
    };
    printStatusLine( "Loading ...", 1 );
    my $sql = qq{
        select taxau, gene_oid, locus_tag, locus_type, gene_symbol,
	      func_type, func_id, func_symbol, func_name, enzymes
        from gene
	where func_type = ?
	order by gene_oid
    };
    my $cur = execSql( $sdbh, $sql, $verbose, $func_type );
    my $it = new InnerTable( 1, "geneList$$", "geneList", 1 );
    my $sd = $it->getSdDelim( );

    $it->addColSpec( "Selection", "", "center" );
    $it->addColSpec( "Gene<br/>Object<br/>Identifier", "asc"  );
    $it->addColSpec( "Locus<br/>Tag", "asc" );
    $it->addColSpec( "Locus<br/>Type", "asc" );
    $it->addColSpec( "Gene<br/>Symbol", "asc" );
    $it->addColSpec( "Function<br/>Type", "asc" );
    $it->addColSpec( "Function<br/>ID", "asc" );
    $it->addColSpec( "Function<br/>Name", "asc" );
    $it->addColSpec( "Domain", "asc" );
    $it->addColSpec( "Status", "asc" );
    $it->addColSpec( "Genome / Sample Name", "asc" );

    my $dbh = dbLogin( );
    my %taxonInfo;
    taxonInfoMap( $dbh, \%taxonInfo );

    my %done;
    my $count = 0;
    for( ;; ) {
        my( $taxau, $gene_oid, $locus_tag, $locus_type, $gene_symbol,
	    $func_type, $func_id, $func_symbol, $func_name, $enzymes ) =
            $cur->fetchrow( );
        last if !$gene_oid;
	next if $done{ $gene_oid };
	my( $taxon_oid, $au ) = split( /\./, $taxau );
	$count++;

        my $r;

	my $workspace_id = $gene_oid;
	if( $au ne "" ) {
	   my $fs_type = "assembled";
	   $fs_type = "unassembled" if $au eq "u";
	   $workspace_id = "$taxon_oid $fs_type $gene_oid";
	}
	my $workspace_id2 = massageToUrl( $workspace_id );
	$r .= $sd . "<input type='checkbox' name='gene_oid' ".
	   "value='$workspace_id' />\t";

	my $url = "$main_cgi?section=GeneDetial&page=geneDetail".
	   "&gene_oid=$workspace_id2";
	my $matchText = highlightMatchHTML2( $gene_oid, $searchTerm );
	my $link = alink( $url, $matchText, $$, 1 );
        $r .= $gene_oid . $sd . "$link\t";

	my $matchText = highlightMatchHTML2( $locus_tag, $searchTerm );
        $r .= $locus_tag . $sd . "$matchText\t";

        $r .= "$locus_type\t";

	my $matchText = highlightMatchHTML2( $gene_symbol, $searchTerm );
	$matchText = "-" if $matchText eq "";
	$r .= $gene_symbol . $sd . "$matchText\t";

	$r .= "$func_type\t";

	$func_id = "-" if $func_id eq $gene_oid && 
	   $func_type eq "gene_product";
	my $matchText = highlightMatchHTML2( $func_id, $searchTerm );
	$r .= $func_id . $sd . "$matchText\t";

        my $desc = $func_name;
	$desc = "$func_symbol - $func_name" if $func_symbol ne "";
	$desc .= " ($enzymes)" if $enzymes ne "";
	my $matchText = highlightMatchHTML2( $desc, $searchTerm );
	$r .= $desc . $sd . "$matchText\t";

	my( $domain, $seq_status, $taxon_display_name ) = 
	    $taxonInfo{ $taxon_oid };
        $r .= "$domain\t";
        $r .= "$seq_status\t";

	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
	   "&taxon_oid=$taxon_oid";
	$r .= "$taxon_display_name" . $sd . 
	    alink( $url, $taxon_display_name ) . "\t";

	$it->addRow( $r );
	$done{ $gene_oid } = 1;
    }
    printGeneCartFooter( );
    $it->printOuterTable( 1 );

    print "<br/>\n";
    printGeneCartFooter( ) if $count > 10;
    printStatusLine( "$count genes retrieved", 2 );
    print end_form( );
    $cur->finish( );

    $sdbh->disconnect( );
    $dbh->disconnect( );
    printStatusLine( "$count genes loaded.", 2 );
    print end_form( );
}

############################################################################
# printSummaryTaxonList
############################################################################
sub printSummaryTaxonList {
    my $searchTerm = param( "searchTerm" );
    my $sdbId = param( "sdbId" );
    my $func_type = param( "func_type" );
    my $sdbFile = "$cgi_tmp_dir/lucy.$sdbId.sdb";
    my $sdbh = WebUtil::sdbLogin( $sdbFile );

    print "<h1>Function Summary Genome List</h1>\n";
    print qq{
       <form class='alignleft' method='post' action='$main_cgi'
         enctype='application/x-www-form-urlencoded' 
	 name='funcSummaryTaxonListForm'>
    };
    printStatusLine( "Loading ...", 1 );
    my $sql = qq{
        select distinct taxau
        from gene
	where func_type = ?
	order by taxau
    };

    my $cur = execSql( $sdbh, $sql, $verbose, $func_type );
    my $it = new InnerTable( 1, "geneList$$", "geneList", 1 );
    my $sd = $it->getSdDelim( );


    my $dbh = dbLogin( );
    my %taxonInfo;
    taxonInfoMap( $dbh, \%taxonInfo );

    $it->addColSpec( "Selection", "", "center" );
    $it->addColSpec( "Domain", "asc" );
    $it->addColSpec( "Status", "asc" );
    $it->addColSpec( "Taxon Name", "asc" );

    my $count = 0;
    for( ;; ) {
       my( $taxau ) = $cur->fetchrow( );
       last if !$taxau;
       my( $taxon_oid, $au ) = split( /\./, $taxau );
       $count++;

       my $r;

       $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' ".
          "value='$taxon_oid' />\t";

       my( $d, $ss, $taxon_display_name ) = 
          split( /\t/, $taxonInfo{ $taxon_oid } );
       $r .= "$d\t";
       $r .= "$ss\t";

       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
          "&taxon_oid=$taxon_oid";
       my $link = alink( $url, $taxon_display_name );
       $r .= $taxon_display_name . $sd . "$link\t";

       $it->addRow( $r );
    }
    printTaxonButtons( );
    $it->printOuterTable( 1 );
    printTaxonButtons( ) if $count > 10;

    print "<br/>\n";
    printStatusLine( "$count genome(s) loaded.". 2 );

    $sdbh->disconnect( );
    $dbh->disconnect( );
    print end_form( );
}

############################################################################
# printGeneList
############################################################################
sub printGeneList {
    my $searchTerm = param( "searchTerm" );
    my @funcs = param( "func" );

    print "<h1>Gene List Results</h1>\n";
    print qq{
       <form class='alignleft' method='post' action='$main_cgi'
         enctype='application/x-www-form-urlencoded' name='geneListForm'>
    };
    if( blankStr( $searchTerm ) ) {
        printStatusLine( "Error.", 2 );
	webError( "No search term specified." );
	return;
    }
    my $nFuncs = @funcs;
    if( $nFuncs == 0 ) {
        printStatusLine( "Error.", 2 );
	webError( "No functions specified." );
	return;
    }
   
    my $dbh = dbLogin( );

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv( );

    my @outRows;
    getListResults( $dbh, \@outRows );
    print "Get taxon information ...<br/>\n";
    my %taxonInfo;
    taxonInfoMap( $dbh, \%taxonInfo );

    printEndWorkingDiv( );

    my $nRows = @outRows;
    if( $nRows == 0 ) {
    	WebUtil::printNoHitMessage( );
    	printStatusLine( "0 genes retrieved", 2 );
        print end_form( );
    	$dbh->disconnect( );
        return;
    }

    printGeneCartFooter( );

    my $it = new InnerTable( 1, "geneList$$", "geneList", 1 );
    my $sd = $it->getSdDelim( );

    $it->addColSpec( "Selection", "", "center" );
    $it->addColSpec( "Gene<br/>Object<br/>Identifier", "asc"  );
    $it->addColSpec( "Locus<br/>Tag", "asc" );
    $it->addColSpec( "Locus<br/>Type", "asc" );
    $it->addColSpec( "Gene<br/>Symbol", "asc" );
    $it->addColSpec( "Function<br/>Type", "asc" );
    $it->addColSpec( "Function<br/>ID", "asc" );
    $it->addColSpec( "Function<br/>Name", "asc" );
    $it->addColSpec( "Domain", "asc" );
    $it->addColSpec( "Status", "asc" );
    $it->addColSpec( "Genome / Sample Name", "asc" );

    my %done;
    my $count = 0;
    for my $row( @outRows ) {
        my( $taxau, $gene_oid, $locus_tag, $locus_type, $gene_symbol, 
	    $func_type, $func_id, $func_symbol, $func_name, $enzymes ) =
	    split( /\t/, $row );
        my( $taxon_oid, $au ) = split( /\./, $taxau );
	my $taxonRec = $taxonInfo{ $taxon_oid };
	my( $domain, $seq_status, $taxon_display_name ) =
	    split( /\t/, $taxonRec );

	next if $done{ $gene_oid };
	$count++;

        my $r;

	my $workspace_id = $gene_oid;
	if( $au ne "" ) {
	   my $fs_type = "assembled";
	   $fs_type = "unassembled" if $au eq "u";
	   $workspace_id = "$taxon_oid $fs_type $gene_oid";
	}
	my $workspace_id2 = massageToUrl( $workspace_id );
	$r .= $sd . "<input type='checkbox' name='gene_oid' ".
	   "value='$workspace_id' />\t";

	my $url = "$main_cgi?section=GeneDetial&page=geneDetail".
	   "&gene_oid=$workspace_id2";
	my $matchText = highlightMatchHTML2( $gene_oid, $searchTerm );
	my $link = alink( $url, $matchText, $$, 1 );
        $r .= $gene_oid . $sd . "$link\t";

	my $matchText = highlightMatchHTML2( $locus_tag, $searchTerm );
        $r .= $locus_tag . $sd . "$matchText\t";

        $r .= "$locus_type\t";

	my $matchText = highlightMatchHTML2( $gene_symbol, $searchTerm );
	$matchText = "-" if $matchText eq "";
	$r .= $gene_symbol . $sd . "$matchText\t";

	$r .= "$func_type\t";

	$func_id = "-" if $func_id eq $gene_oid && 
	   $func_type eq "gene_product";
	my $matchText = highlightMatchHTML2( $func_id, $searchTerm );
	$r .= $func_id . $sd . "$matchText\t";

        my $desc = $func_name;
	$desc = "$func_symbol - $func_name" if $func_symbol ne "";
	$desc .= " ($enzymes)" if $enzymes ne "";
	my $matchText = highlightMatchHTML2( $desc, $searchTerm );
	$r .= $desc . $sd . "$matchText\t";

        $r .= "$domain\t";
        $r .= "$seq_status\t";

	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail".
	   "&taxon_oid=$taxon_oid";
	$r .= "$taxon_display_name" . $sd . 
	    alink( $url, $taxon_display_name ) . "\t";

	$it->addRow( $r );
	$done{ $gene_oid } = 1;
    }
    $it->printOuterTable( 1 );

    print "<br/>\n";
    printGeneCartFooter( ) if $count > 10;
    printStatusLine( "$count genes retrieved", 2 );
    print end_form( );

    $dbh->disconnect( );
}

############################################################################
# getListResults
############################################################################
sub getListResults {
    my( $dbh, $outRows_aref ) = @_;
    my $searchTerm = param( "searchTerm" );
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my @funcs = param( "func" );

    my %validTaxons = getValidTaxons( $dbh );
    my @taxon_oids = sort( keys( %validTaxons ) );
    my @selected_taxons = param( "taxon_oid" );
    my $nSelectedTaxons = @selected_taxons;
    if( $nSelectedTaxons > 0 ) {
       @taxon_oids = @selected_taxons;
    }

    my @oraTaxons;
    my @fsTaxons;
    my( $nOra, $nFs ) = 
       splitOraFsTaxons( $dbh, \@taxon_oids, \@oraTaxons, \@fsTaxons );
    webLog( "nOra=$nOra nFs=$nFs\n" );
    if( $nOra > 0 &&  $nSelectedTaxons == 0) {
       for my $func( @funcs ) {
	  my $func_type;
	  if( $func eq "gene_product" ) {
	     $func_type = $func;
	  }
	  else {
	     $func_type = "${func}_genes";
	  }
	  print "Retrieving from function type '<i>$func_type</i>' ...<br>\n";
          getOraHits( $searchTerm, $func_type, \%validTaxons, $outRows_aref );
       }
    }
    if( $nOra > 0 && $nSelectedTaxons > 0 ) {
       for my $taxon_oid( @oraTaxons ) {
           for my $func( @funcs ) {
	      my $func_type;
	      if( $func eq "gene_product" ) {
	         $func_type = $func;
	      }
	      else {
	          $func_type = "${func}_genes";
	      }
	      my $dir = "$sandbox_lucy_dir/Oracle/$taxon_oid/$func_type";
	      if( -e $dir ) {
		 print "Retrieving from Oracle $taxon_oid ". 
		       " function type '<i>$func_type</i>' ...<br>\n";
                 getOraTaxonHits( 
		     $searchTerm, $taxon_oid, $func_type, $outRows_aref );
	      }
	   }
       }
    }
    if( $nFs > 0 && $nSelectedTaxons > 0 ) {
       for my $taxon_oid( @fsTaxons ) {
           for my $func( @funcs ) {
	      my $func_type;
	      if( $func eq "gene_product" ) {
	         $func_type = $func;
	      }
	      else {
	          $func_type = "${func}_genes";
	      }
	      next if $func_type ne "gene_product" &&
	              $func_type ne "cog_genes" &&
		      $func_type ne "pfam_genes" &&
		      $func_type ne "kegg_enes" &&
		      $func_type ne "metacyc_genes";
	      my $taxau = "$taxon_oid.a";
	      my $dir = "$sandbox_lucy_dir/MER-FS/$taxau/$func_type";
	      if( -e $dir ) {
		 print "Retrieving from $taxau ". 
		       " function type '<i>$func_type</i>' ...<br>\n";
                 getFsHits( $searchTerm, $taxau, $func_type, $outRows_aref )
	      }
	      my $taxau = "$taxon_oid.u";
	      my $dir = "$sandbox_lucy_dir/MER-FS/$taxau/$func_type";
	      if( -e $dir ) {
		 print "Retrieving from $taxau ". 
		       " function type '<i>$func_type</i>' ...<br>\n";
		 getFsHits( $searchTerm, $taxau, $func_type, $outRows_aref )
	      }
	   }
       }
    }
}

############################################################################
# getOraHits - Get oracle search directory hits.
############################################################################
sub getOraHits {
    my( $searchTerm, $func_type0, $validTaxons_href, $outRows_aref ) = @_;
    my $searchTermLc = lc( $searchTerm );
    my $top_n = param( "top_n" );
    my $inDir = "$sandbox_lucy_dir/Oracle/$func_type0";

    my $hits = newHits( $inDir, $searchTerm, 100000 );
    my $count = 0;
    while( my $hit = $hits->next( ) ) {
        my $taxau = $hit->{ taxau };
        my $gene_oid = $hit->{ gene_oid };
        my $locus_tag = $hit->{ locus_tag };
        my $locus_type = $hit->{ locus_type };
        my $gene_symbol = $hit->{ gene_symbol };
        my $func_type = $hit->{ func_type };
        my $func_id = $hit->{ func_id };
        my $func_symbol = $hit->{ func_symbol };
        my $func_name = $hit->{ func_name };
        my $enzymes = $hit->{ enzymes };
	next if !$validTaxons_href->{ $taxau };
	next if $func_type0 ne "gene_product" &&
	   lc( $func_id ) !~ /$searchTermLc/ &&
	   lc( $func_symbol ) !~ /$searchTermLc/ &&
	   lc( $func_name ) !~ /$searchTermLc/;
	$count++;
	my $r = "$taxau\t";
	$r .= "$gene_oid\t";
	$r .= "$locus_tag\t";
	$r .= "$locus_type\t";
	$r .= "$gene_symbol\t";
	$r .= "$func_type\t";
	$r .= "$func_id\t";
	$r .= "$func_symbol\t";
	$r .= "$func_name\t";
	$r .= "$enzymes";
	push( @$outRows_aref, $r );
	last if $count >= $top_n;
    }
    webLog( "phase 1a: $count $func_type0 Oracle hits\n" );
    if( $count == 0 && $func_type0 eq "gene_product" ) {
        my $inDir = "$sandbox_lucy_dir/Oracle/no_gene_product";
	if( !-e $inDir ) {
	   webLog( "getOraHits: '$inDir' not found\n" );
	   print STDERR "getOraHits: '$inDir' not found\n";
	}
	else {
            my $hits = newHits( $inDir, $searchTerm, 100000 );
            while( my $hit = $hits->next( ) ) {
                my $taxau = $hit->{ taxau };
                my $gene_oid = $hit->{ gene_oid };
                my $locus_tag = $hit->{ locus_tag };
                my $locus_type = $hit->{ locus_type };
                my $gene_symbol = $hit->{ gene_symbol };
	        next if !$validTaxons_href->{ $taxau };
	        $count++;
		my( $func_type, $func_id, $func_symbol, 
		    $func_name, $enzymes ); # blank
		$func_name = "hypothetical protein" if $locus_type eq "CDS";
	        my $r = "$taxau\t";
	        $r .= "$gene_oid\t";
	        $r .= "$locus_tag\t";
	        $r .= "$locus_type\t";
	        $r .= "$gene_symbol\t";
	        $r .= "$func_type\t";
	        $r .= "$func_id\t";
	        $r .= "$func_symbol\t";
	        $r .= "$func_name\t";
	        $r .= "$enzymes";
	        push( @$outRows_aref, $r );
	        last if $count >= $top_n;
            }
	}
        webLog( "phase 1b: $count $func_type0 " .
	        "Oracle hits for no_gene_product\n" );
    }

    print nbsp( 3 ) . "$count $func_type0 hits found.<br/>\n";
    webLog( "phase 2: $count $func_type0 Oracle hits\n" );
}
############################################################################
# getOraTaxonHits - Get oracle search directory hits for one taxon.
############################################################################
sub getOraTaxonHits {
    my( $searchTerm, $taxon_oid, $func_type0, $outRows_aref ) = @_;
    my $searchTermLc = lc( $searchTerm );
    my $top_n = param( "top_n" );
    my $inDir = "$sandbox_lucy_dir/Oracle/$taxon_oid/$func_type0";

    my $hits = newHits( $inDir, $searchTerm, 100000 );
    my $count = 0;
    while( my $hit = $hits->next( ) ) {
        my $taxau = $hit->{ taxau };
        my $gene_oid = $hit->{ gene_oid };
        my $locus_tag = $hit->{ locus_tag };
        my $locus_type = $hit->{ locus_type };
        my $gene_symbol = $hit->{ gene_symbol };
        my $func_type = $hit->{ func_type };
        my $func_id = $hit->{ func_id };
        my $func_symbol = $hit->{ func_symbol };
        my $func_name = $hit->{ func_name };
        my $enzymes = $hit->{ enzymes };
	next if $func_type0 ne "gene_product" &&
	   lc( $func_id ) !~ /$searchTermLc/ &&
	   lc( $func_symbol ) !~ /$searchTermLc/ &&
	   lc( $func_name ) !~ /$searchTermLc/;
	$count++;
	my $r = "$taxau\t";
	$r .= "$gene_oid\t";
	$r .= "$locus_tag\t";
	$r .= "$locus_type\t";
	$r .= "$gene_symbol\t";
	$r .= "$func_type\t";
	$r .= "$func_id\t";
	$r .= "$func_symbol\t";
	$r .= "$func_name\t";
	$r .= "$enzymes";
	push( @$outRows_aref, $r );
	last if $count >= $top_n;
    }
    webLog( "phase 1a: $count $taxon_oid $func_type0 Oracle hits\n" );
    if( $count == 0 && $func_type0 eq "gene_product" ) {
        my $inDir = "$sandbox_lucy_dir/Oracle/$taxon_oid/no_gene_product";
	if( !-e $inDir ) {
	   webLog( "getOraTaxonHits: '$inDir' not found\n" );
	   print STDERR "getOraTaxonHits: '$inDir' not found\n";
	}
	else {
            my $hits = newHits( $inDir, $searchTerm, 100000 );
            while( my $hit = $hits->next( ) ) {
                my $taxau = $hit->{ taxau };
                my $gene_oid = $hit->{ gene_oid };
                my $locus_tag = $hit->{ locus_tag };
                my $locus_type = $hit->{ locus_type };
                my $gene_symbol = $hit->{ gene_symbol };
	        $count++;
		my( $func_type, $func_id, $func_symbol, 
		    $func_name, $enzymes ); # blank
		$func_name = "hypothetical protein" if $locus_type eq "CDS";
	        my $r = "$taxau\t";
	        $r .= "$gene_oid\t";
	        $r .= "$locus_tag\t";
	        $r .= "$locus_type\t";
	        $r .= "$gene_symbol\t";
	        $r .= "$func_type\t";
	        $r .= "$func_id\t";
	        $r .= "$func_symbol\t";
	        $r .= "$func_name\t";
	        $r .= "$enzymes";
	        push( @$outRows_aref, $r );
	        last if $count >= $top_n;
            }
	}
        webLog( "phase 1b: $count $taxon_oid $func_type0 " .
	        "Oracle hits for no_gene_product\n" );
    }
    print nbsp( 3 ) . "$count $taxon_oid $func_type0 hits found.<br/>\n";
    webLog( "phase 2: $count $taxon_oid $func_type0 Oracle hits\n" );
}

############################################################################
# getFsHits - Get hits from file system.  Handle inverted indices.
#   Make it look like the output of getOraHits.
############################################################################
sub getFsHits {
    my( $searchTerm, $taxau, $func_type0, $outRows_aref ) = @_;
    my $searchTermLc = lc( $searchTerm );
    my $inDir = "$sandbox_lucy_dir/MER-FS/$taxau/$func_type0";
    my $top_n = param( "top_n" );
    my( $taxon_oid, $au ) = split( /\./, $taxau );

    my %funcNameMap = (
       gene_product => "gene_product",
       cog_genes => "COG",
       pfam_genes => "Pfam",
       ko_genes => "KO",
       kegg_genes => "KEGG",
       metacyc_genes => "MetaCyc",
    );
    my $hits = newHits( $inDir, $searchTerm, 1000000 );
    my $count = 0;
    my $exitLoop = 0;
    while( my $hit = $hits->next( ) ) {
	last if $exitLoop;
        my $func_type = $hit->{ func_type };
        my $func_id = $hit->{ func_id };
        my $func_symbol = $hit->{ func_symbol };
        my $func_name = $hit->{ func_name };
        my $genes = $hit->{ genes };
	my @genes_a = split( /\s+/, $genes );
	for my $gene_oid( @genes_a ) {
	    last if $exitLoop;
	    $count++;
	    my $locus_tag = $gene_oid;
	    my( $gene_symbol, $func_symbol, $enzymes ); #blank
	    my $func_type = $funcNameMap{ $func_type0 };
	    my $locus_type = "CDS";
	    $locus_type = "rRNA" if 
	       $func_name =~ /16S/ ||
	       $func_name =~ /23S/ ||
	       $func_name =~ /5S/ ||
	       $func_name =~ /18S/ ||
	       $func_name =~ /28S/ ||
	       $func_name =~ /SSU/ ||
	       $func_name =~ /TSU/ ||
	       $func_name =~ /LSU/;
	    $locus_type = "tRNA" if $func_name =~ /tRNA/;
	    my $r = "$taxau\t";
	    $r .= "$gene_oid\t";
	    $r .= "$locus_tag\t";
	    $r .= "$locus_type\t";
	    $r .= "$gene_symbol\t";
	    $r .= "$func_type\t";
	    $r .= "$func_id\t";
	    $r .= "$func_symbol\t";
	    $r .= "$func_name\t";
	    $r .= "$enzymes";
	    if( lc( $func_id ) =~ /$searchTermLc/ ||
	        lc( $func_symbol ) =~ /$searchTermLc/ ||
		lc( $func_name ) =~ /$searchTermLc/ ||
                lc( $gene_oid ) eq $searchTermLc ) {
	           push( @$outRows_aref, $r );
	           if( $count >= $top_n ) {
		      $exitLoop = 1;
		      last;
		   }
	    }
        }
    }
    webLog( "$count $taxau $func_type0 MER-FS hits\n" );
    # Maybe it's a gene_oid lookup not in the product file.
    if( $count == 0 && $func_type0 eq "gene_product" ) {
	my $type = "assembled";
	$type = "unassembled" if $au eq "u";
        my $txd = "$mer_data_dir/$taxon_oid/$type";
	my $nBins = taxonHashNoBins( $taxau, "gene" );
	my $fileNo = HashUtil::hash_mod( $searchTerm, $nBins );
	my $sdbFile = "$txd/gene/gene_${fileNo}.sdb";
	if( !-e $sdbFile ) {
	    webLog( "getFsHits: '$sdbFile' not found\n" );
	}
	else {
	    my $dbh = WebUtil::sdbLogin( $sdbFile );
	    my $sql = "select gene_oid, locus_type, locus_tag ".
	       "from gene where gene_oid = ?";
	    my $cur = execSql( $dbh, $sql, $verbose, $searchTerm );
	    my( $gene_oid, $locus_type, $locus_tag ) = $cur->fetchrow( );
	    if( $gene_oid ne "" ) {
	        $count++;
	        my( $gene_symbol, $func_symbol, $func_name, $enzymes ); #blank
		$func_name = "hypothetical protein" if
		   $func_name eq "" && $locus_type eq "CDS" &&
		   $func_type0 eq "gene_product";
	        my $r = "$taxau\t";
	        $r .= "$gene_oid\t";
	        $r .= "$locus_tag\t";
	        $r .= "$locus_type\t";
	        $r .= "$gene_symbol\t";
	        $r .= "$func_type0\t";
	        $r .= "$func_symbol\t";
	        $r .= "$func_name\t";
	        $r .= "$enzymes";
	        push( @$outRows_aref, $r );
	    }
	    $dbh->disconnect( );
        }
    }
    print nbsp( 3 ) . "$count $func_type0 MER-FS hits found.<br/>\n";
}


############################################################################
# taxonInfoMap - Get taxon information map.
############################################################################
sub taxonInfoMap {
    my( $dbh, $map_href ) = @_;

    my $sql = qq{
        select taxon_oid, domain, seq_status, taxon_display_name
	from taxon
	where obsolete_flag = 'No'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $taxon_oid, $domain, $seq_status, $taxon_display_name ) = 
	   $cur->fetchrow( );
        last if !$taxon_oid;
	my $d = substr( $domain, 0, 1 );
	my $ss = substr( $seq_status, 0, 1 );
	$map_href->{ $taxon_oid } = "$d\t$ss\t$taxon_display_name";
    }
    $cur->finish( );
}

1;

