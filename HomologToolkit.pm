############################################################################
# HomologToolkit - Allows user much greater options for displaying
#   a large list homologs.
#     --es 03/30/2007
############################################################################
package HomologToolkit;
my $section = "HomologToolkit";

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use FuncUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi = $env->{ inner_cgi };
my $verbose = $env->{ verbose };
my $base_dir = $env->{ base_dir };
my $img_internal = $env->{ img_internal };
my $include_img_terms = $env->{ include_img_terms };
my $include_metagenomes = $env->{ include_metagenomes };
my $show_myimg_login = $env->{ show_myimg_login };
my $img_lite = $env->{ img_lite };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir }; 
my $top_n_homologs = 10000;  # make a very large number
my $max_batch = 500; 

############################################################################
# dispatch - Dispatch events.
############################################################################
sub dispatch {
    my $page = param( "page" );
    
    if( paramMatch( "homologResults" ) ne "" ) {
       printHomologResults( );
    }
    elsif( $page eq "homologPager" ) {
       printHomologPager( );
    }
    else {
       printQueryForm( );
    }
}

############################################################################
# printQueryForm - Show query form for homologs.
############################################################################
sub printQueryForm {
    my $gene_oid = param( "gene_oid" );
    if( blankStr( $gene_oid ) ) {
       webError( "Gene $gene_oid not found." );
    }
    my $dbh = dbLogin( );
    my $gene_name = geneOid2Name( $dbh, $gene_oid );
    checkGenePerm( $dbh, $gene_oid );

    print "<h1>Homolog Toolkit</h1>\n";
    print "<p>\n";
    print "The homolog toolkit allows you customize how homologs are ";
    print "displayed.<br/>\n";
    print "All available homologs are retrieved ";
    print "and displayed in multiple pages.<br/>\n";
    print "Find homologs for gene $gene_oid: <i>" . 
       escHtml( $gene_name ) . "</i>.<br/>\n";
    print "</p>\n";

    printMainForm( );
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    printOptionLabel( "Page Options" );
    print nbsp( 2 );
    print popup_menu( -name => "hitsPerPage",
       -values => [ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 ],
       -default => 500 );
    print nbsp( 1 );
    print "hits per page.\n";
    print "<br/>\n";
    print "<br/>\n";

    printOptionLabel( "Column Options" );
    #
    print nbsp( 2 );
    print "<input type='checkbox' name='enzymes' value='1' />\n";
    print nbsp( 1 );
    print "Show enzyme column.<br/>\n";
    if( $show_myimg_login ) {
        print nbsp( 2 );
        print "<input type='checkbox' name='myMyImgAnnot' value='1' />\n";
        print nbsp( 1 );
        print "Show <i>my</i> MyIMG annotations.<br/>\n";
        #
        print nbsp( 2 );
        print "<input type='checkbox' name='allMyImgAnnot' value='1' />\n";
        print nbsp( 1 );
        print "Show <i>all</i> MyIMG annotations.<br/>\n";
    }
    if( $include_img_terms ) {
        print nbsp( 2 );
        print "<input type='checkbox' name='imgTerms' value='1' />\n";
        print nbsp( 1 );
        print "Show IMG terms.<br/>\n";
    }
    print nbsp( 2 );
    my $ck;
    $ck =  "checked" if $include_metagenomes;
    print "<input type='checkbox' name='scaffoldInfo' value='1' $ck/>\n";
    print nbsp( 1 );
    print "Show Scaffold Information.<br/>\n";
    #
    if( $img_internal ) {
        print nbsp( 2 );
        print "<input type='checkbox' name='family' value='1' />\n";
        print nbsp( 1 );
        print "Show taxonomic rank above genus<sup>1</sup>" . 
	   "(Experimental).<br/>\n";
    }
    #
    print "<br/>\n";

    printOptionLabel( "Row Options" );
    #
    my $ck = "checked";
    print nbsp( 2 );
    print "<input type='radio' name='rowOption' value='allHomologs' $ck/>\n";
    print nbsp( 1 );
    print "Show all homologs.<br/>\n";
    #
    if( $include_img_terms ) {
       print nbsp( 2 );
       print "<input type='radio' name='rowOption' value='woImgTerms' />\n";
       print nbsp( 1 );
       print "Show homologs without IMG terms.<br/>\n";
    }
    print nbsp( 2 );
    print "<input type='radio' name='rowOption' value='finishedGenomes' />\n";
    print nbsp( 1 );
    print "Show homologs from finished genomes only.<br/>\n";
    #
    print "<br/>\n ";

    printOptionLabel( "Sort Options" );
    #
    print nbsp( 2 );
    print "<input type='radio' name='sortOption' value='descBitScore' $ck/>\n";
    print nbsp( 1 );
    print "Sort by descending bit score.<br/>\n";
    #
    print nbsp( 2 );
    print "<input type='radio' name='sortOption' value='ascTaxon' />\n";
    print nbsp( 1 );
    print "Sort by genomes.<br/>\n";
    #
    print nbsp( 2 );
    print "<input type='radio' name='sortOption' value='descPercIdent' />\n";
    print nbsp( 1 );
    print "Sort by descending amino acid percent identity.<br/>\n";
    #
    print nbsp( 2 );
    print "<input type='radio' name='sortOption' value='ascProductName' />\n";
    print nbsp( 1 );
    print "Sort by product name.<br/>\n";
    #
    print "<br/>\n ";

    print hiddenVar( "gene_oid", $gene_oid );

    my $name = "_section_${section}_homologResults";
    print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 );
    print reset( -class => "smbutton" );
    print "<br/>\n";

    print "</p>\n";
    printStatusLine( "Loaded.", 2 );
    if( $img_internal ) {
        print "<p>\n";
        print "<b>Notes:</b><br/>\n";
        print "1 - This may be used to infer horizontal ";
	print "transfers from outside\n";
        print "the query gene's family, or higher rank ";
	print "if <i>unclassified</i>.<br/>\n";
        print nbsp( 3 );
        print "Sort by bit score, to see if some other family shows up\n";
        print "(or higher rank) near the top ";
        print "that is not in the same species as the query gene.<br/>\n";
        print "</p>\n";
    }
    print end_form( );
    #$dbh->disconnect();
}

############################################################################
# printOptionLabel
############################################################################
sub printOptionLabel {
   my( $s ) = @_;
   print "<b>";
   print "<font color='blue'>";
   print escHtml( $s );
   print "</font>";
   print "</b>";
   print ":<br/>\n";
}

############################################################################
# printHomologResults - Show results from query form.
############################################################################
sub printHomologResults {
   my $gene_oid = param( "gene_oid" );

   print "<h1>Homolog Toolkit</h1>\n";
   printMainForm( );
   printStatusLine( "Loading ...", 1 );

   printStartWorkingDiv( );
   my @homologRecs;
   require OtfBlast;
   print "Retrieve BLAST hits ...<br/>\n";
   my $dbh = dbLogin( );
   my $filterType = OtfBlast::genePageTopHits( 
       $dbh, $gene_oid, \@homologRecs, $top_n_homologs );
   my $nRecs = @homologRecs;
   webLog( "$nRecs blast records found\n" );
   my %attrs;
   retrieveAttributes( $dbh, $gene_oid, \@homologRecs, \%attrs );
   filterRows( $dbh, \@homologRecs, \%attrs );
   sortRows( $dbh, \@homologRecs, \%attrs );
   my $pagerFileRoot = getPagerFileRoot( $gene_oid );
   webLog( "pagerFileRoot $pagerFileRoot'\n" );
   outputRows( $dbh, $gene_oid, \@homologRecs, \%attrs );
   printEndWorkingDiv( );

   #$dbh->disconnect();

   printOnePage( $gene_oid, 1 );
   printStatusLine( "Loaded.", 2 );
   print end_form( );
}

############################################################################
# retreiveAttributes - Get attributes for homolog records.
############################################################################
sub retrieveAttributes {
    my( $dbh, $gene_oid, $recs_ref, $attrs_ref ) = @_;

    my $myMyImgAnnot = param( "myMyImgAnnot" );
    my $allMyImgAnnot = param( "allMyImgAnnot" );
    my $imgTerms = param( "imgTerms" );
    my $enzymes = param( "enzymes" );
    my $scaffoldInfo = param( "scaffoldInfo" );
    my $rowOption = param( "rowOption" );
    my $family = param( "family" );

    my %homolog_oids_h;
    for my $r( @$recs_ref ) {
       my( $gene_oid, $homolog, undef ) = split( /\t/, $r );
       $homolog_oids_h{ $homolog } = $homolog;
    }
    my @homolog_oids = sort( keys( %homolog_oids_h ) );
    getGeneTaxonInfo( $dbh, \@homolog_oids, $attrs_ref );
    if( !$img_lite ) {
       getParaOrtho( $dbh, $gene_oid, $attrs_ref );
    }
    if( $myMyImgAnnot && !$allMyImgAnnot ) {
       getMyImgAnnot( $dbh, \@homolog_oids, $attrs_ref, "my" );
    }
    if( $allMyImgAnnot ) {
       getMyImgAnnot( $dbh, \@homolog_oids, $attrs_ref, "all" );
    }
    if( $enzymes ) {
       getEnzymes( $dbh, \@homolog_oids, $attrs_ref );
    }
    if( $imgTerms || $rowOption eq "woImgTerms" ) {
       getImgTerms( $dbh, \@homolog_oids, $attrs_ref );
    }
    if( $scaffoldInfo ) {
       getScaffoldInfo( $dbh, \@homolog_oids, $attrs_ref );
    }
    if( $family ) {
       getFamily( $dbh, \@homolog_oids, $attrs_ref );
    }
}

############################################################################
# getParaOrtho - Get paralog and ortholog information.
############################################################################
sub getParaOrtho {
    my( $dbh, $gene_oid, $attrs_ref ) = @_;

    print "Retrieving paralog and ortholog information ...<br/>\n";

    ## Paralogs
    my $sql = qq{
       select gp.paralog
       from gene_paralogs gp
       where gp.gene_oid = $gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %paralogs;
    $attrs_ref->{ paralogs } = \%paralogs;
    for( ;; ) {
       my( $paralog ) = $cur->fetchrow( );
       last if !$paralog;
       $paralogs{ $paralog } = "$paralog";
    }
    $cur->finish( );

    ## Orthologs
    my $sql = qq{
       select go.ortholog
       from gene_orthologs go
       where go.gene_oid = $gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %orthologs;
    $attrs_ref->{ orthologs } = \%orthologs;
    for( ;; ) {
       my( $ortholog ) = $cur->fetchrow( );
       last if !$ortholog;
       $orthologs{ $ortholog } = "$ortholog";
    }
    $cur->finish( );

}

############################################################################
# getMyImgAnnot - Get MyIMG annotation.
############################################################################
sub getMyImgAnnot {
    my( $dbh, $homolog_oids_ref, $attrs_ref, $type ) = @_;

    print "Retrieving MyIMG annotations ...<br/>\n";

    my @batch;
    my %attrs2;
    $attrs_ref->{ myImgAnnotations } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushMyImgAnnot( $dbh, \@batch, \%attrs2, $type );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushMyImgAnnot( $dbh, \@batch, \%attrs2, $type );
    trimHashValues( \%attrs2, 2 );
}

sub flushMyImgAnnot {
   my( $dbh, $oids_ref, $attrs2_ref, $type ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

   my $contact_oid = getContactOid( );
   my $authorClause;
   $authorClause = "and ct.contact_oid = $contact_oid"
       if $contact_oid > 0 && $type eq "my";

   my $rclause   = WebUtil::urClause('g.taxon');
   my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
   my $sql_old = qq{
       select g.gene_oid, ann.annotation_text,
          ann.author, ct.username, to_char(ann.add_date, 'yyyy-mm-dd')
       from gene g, annotation ann, annotation_genes ag,
         contact ct
       where g.gene_oid = ag.genes
       and g.gene_oid in( $oid_str )
       and ag.annot_oid = ann.annot_oid
       and ct.contact_oid = ann.author
       $rclause
       $imgClause
       $authorClause
   };
   my $sql = qq{
       select g.gene_oid, gmf.product_name,
          gmf.modified_by, ct.username, to_char(gmf.mod_date, 'yyyy-mm-dd')
       from gene g, gene_myimg_functions gmf, contact ct
       where g.gene_oid = gmf.gene_oid
       and g.gene_oid in( $oid_str )
       and ct.contact_oid = gmf.modified_by
       $rclause
       $imgClause
       $authorClause
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $annotation_text, $author, $username, $add_date ) = 
          $cur->fetchrow( );
       last if !$gene_oid;
       my $s = "$username: $annotation_text ($add_date); ";
       $attrs2_ref->{ $gene_oid } .= $s;
   }
   $cur->finish( );
}

############################################################################
# getGeneTaxonInfo - Get taxon information.
############################################################################
sub getGeneTaxonInfo {
    my( $dbh, $homolog_oids_ref, $attrs_ref ) = @_;

    print "Retrieving gene and taxon information ...<br/>\n";
    my @batch;
    my %attrs2;
    $attrs_ref->{ geneTaxonInfo } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushGeneTaxonInfo( $dbh, \@batch, \%attrs2 );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushGeneTaxonInfo( $dbh, \@batch, \%attrs2 );
}

sub flushGeneTaxonInfo {
   my( $dbh, $oids_ref, $attrs2_ref ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $sql = qq{
      select g.gene_oid, g.gene_display_name, g.aa_seq_length,
         tx.taxon_oid, tx.taxon_display_name,
	 tx.domain, tx.seq_status
      from gene g, taxon tx
      where g.gene_oid in( $oid_str )
      and g.taxon = tx.taxon_oid
      $rclause
      $imgClause
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $gene_display_name, $aa_seq_length,
           $taxon_oid, $taxon_display_name,
	   $domain, $seq_status ) = $cur->fetchrow( );
       last if !$gene_oid;
       my $r = "$gene_display_name\t";
       $r .= "$aa_seq_length\t";
       $r .= "$taxon_oid\t";
       $r .= "$taxon_display_name\t";
       $r .= "$domain\t";
       $r .= "$seq_status";
       $attrs2_ref->{ $gene_oid } .= $r;
   }
   $cur->finish( );
}

############################################################################
# getImgTerms - Get IMG terms.
############################################################################
sub getImgTerms {
    my( $dbh, $homolog_oids_ref, $attrs_ref ) = @_;

    print "Retrieving IMG terms ...<br/>\n";

    my @batch;
    my %attrs2;
    $attrs_ref->{ imgTerms } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushImgTerms( $dbh, \@batch, \%attrs2 );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushImgTerms( $dbh, \@batch, \%attrs2 );
    #trimHashValues( \%attrs2, 0 );
}

sub flushImgTerms {
   my( $dbh, $oids_ref, $attrs2_ref ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

#   my $sql = qq{
#       select gif.gene_oid, it.term_oid, it.term
#       from gene_img_functions gif, dt_img_term_path dtp, img_term it
#       where gif.gene_oid in( $oid_str )
#       and gif.function = dtp.map_term
#       and it.term_oid = dtp.term_oid
#       order by it.term_oid
#   };
   my $sql = qq{
       select gif.gene_oid, it.term_oid, it.term
       from gene_img_functions gif, img_term it
       where gif.gene_oid in( $oid_str )
       and gif.function = it.term_oid
       order by it.term_oid
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $term_oid, $term ) = $cur->fetchrow( );
       last if !$gene_oid;
       my $s = "$term_oid\t$term\n";
       $attrs2_ref->{ $gene_oid } .= $s;
   }
   $cur->finish( );
}

############################################################################
# getEnzymes - Get enzymes.
############################################################################
sub getEnzymes {
    my( $dbh, $homolog_oids_ref, $attrs_ref ) = @_;

    print "Retrieving EC numbers ...<br/>\n";

    my @batch;
    my %attrs2;
    $attrs_ref->{ enzymes } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushEnzymes( $dbh, \@batch, \%attrs2 );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushEnzymes( $dbh, \@batch, \%attrs2 );
    trimHashValues( \%attrs2, 2 );
}

sub flushEnzymes {
   my( $dbh, $oids_ref, $attrs2_ref ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

   my $sql = qq{
       select ge.gene_oid, ge.enzymes
       from gene_ko_enzymes ge
       where ge.gene_oid  in( $oid_str )
       order by ge.enzymes
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $enzymes ) = $cur->fetchrow( );
       last if !$gene_oid;
       $attrs2_ref->{ $gene_oid } .= "$enzymes, ";
   }
   $cur->finish( );
}

############################################################################
# getFamily - Get family, taxonomic rank.
############################################################################
sub getFamily {
    my( $dbh, $homolog_oids_ref, $attrs_ref ) = @_;

    print "Retrieving phylogenetic ranks above genus ...<br/>\n";

    my @batch;
    my %attrs2;
    $attrs_ref->{ family } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushFamily( $dbh, \@batch, \%attrs2 );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushFamily( $dbh, \@batch, \%attrs2 );
}

sub flushFamily {
   my( $dbh, $oids_ref, $attrs2_ref ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

   my $rclause   = WebUtil::urClause('tx');
   my $imgClause = WebUtil::imgClause('tx');
   my $sql = qq{
       select g.gene_oid, tx.family, tx.ir_order, tx.ir_class, tx.phylum
       from gene g, taxon tx 
       where g.gene_oid  in( $oid_str )
       and g.taxon = tx.taxon_oid
       $rclause
       $imgClause
       order by g.gene_oid
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $family, $ir_order, $ir_class, $phylum ) = 
           $cur->fetchrow( );
       last if !$gene_oid;
       my $rank = $family;
       $rank = $ir_order if $rank eq "unclassified";
       $rank = $ir_class if $rank eq "unclassified";
       $rank = $phylum if $rank eq "unclassified";
       $attrs2_ref->{ $gene_oid } = $rank;
   }
   $cur->finish( );
}

############################################################################
# getScaffoldInfo - Get scaffold information.
############################################################################
sub getScaffoldInfo {
    my( $dbh, $homolog_oids_ref, $attrs_ref ) = @_;

    print "Retrieving scaffold information ...<br/>\n";

    my @batch;
    my %attrs2;
    $attrs_ref->{ scaffoldInfo } = \%attrs2;
    for my $oid( @$homolog_oids_ref ) {
       if( scalar( @batch ) > $max_batch ) {
          flushScaffoldInfo( $dbh, \@batch, \%attrs2 );
	  @batch = ( );
       }
       push( @batch, $oid );
    }
    flushScaffoldInfo( $dbh, \@batch, \%attrs2 );
}

sub flushScaffoldInfo {
   my( $dbh, $oids_ref, $attrs2_ref ) = @_;

   my $oid_str = join( ',', @$oids_ref );
   return if blankStr( $oid_str );

   my $rclause   = WebUtil::urClause('g.taxon');
   my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
   my $sql = qq{
      select g.gene_oid, scf.ext_accession, ss.seq_length, ss.gc_percent
      from gene g, scaffold scf, scaffold_stats ss
      where g.gene_oid in( $oid_str )
      and g.scaffold = scf.scaffold_oid
      and scf.scaffold_oid = ss.scaffold_oid
      $rclause
      $imgClause
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $gene_oid, $ext_accession, $seq_length, $gc_percent ) = 
          $cur->fetchrow( );
       last if !$gene_oid;
       my $r = "$ext_accession\t";
       $r .= "$seq_length\t";
       $r .= "$gc_percent";
       $attrs2_ref->{ $gene_oid } = $r;
   }
   $cur->finish( );
}

############################################################################
# trimHashValues - Trim hash values by specified characters.
############################################################################
sub trimHashValues {
   my( $h_ref, $nChars ) = @_;
   my @keys = keys( %$h_ref );
   for my $k( @keys ) {
      my $v = $h_ref->{ $k };
      for( my $i = 0; $i < $nChars; $i++ ) {
         chop $v;
      }
      $h_ref->{ $k } = $v;
   }
}

############################################################################
# filterRows - Filter rows.
############################################################################
sub filterRows {
    my( $dbh, $recs_ref, $attrs_ref ) = @_;

    my $rowOption = param( "rowOption" );

    if( $rowOption eq "woImgTerms" ) {
       my $attrs2_ref = $attrs_ref->{ imgTerms };
       print "Filtering rows without IMG terms ...<br/>\n";
       my @recs2;
       for my $r( @$recs_ref ) {
          my( $gene_oid, $homolog, undef ) = split( /\t/, $r );
          my $imgTermsRec = $attrs2_ref->{ $homolog };
          next if !blankStr( $imgTermsRec );
          push( @recs2, $r );
       }
       my $nRecs = @recs2;
       webLog( "sortRows: $nRecs filtered\n" );
       @$recs_ref = @recs2;
    }
    if( $rowOption eq "finishedGenomes" ) {
       my $attrs2_ref = $attrs_ref->{ geneTaxonInfo };
       print "Filtering rows for finished genomes ...<br/>\n";
       my @recs2;
       for my $r( @$recs_ref ) {
          my( $gene_oid, $homolog, undef ) = split( /\t/, $r );
          my $geneTaxonInfoRec = getDictVals( $attrs_ref, "geneTaxonInfo",
	    $homolog );
	  my( $gene_display_name, $aa_seq_length, $taxon_oid,
	      $taxon_display_name, $domain, $seq_status ) = 
	         split( /\t/, $geneTaxonInfoRec );
	  next if $seq_status ne "Finished";
          push( @recs2, $r );
       }
       my $nRecs = @recs2;
       webLog( "sortRows: $nRecs filtered\n" );
       @$recs_ref = @recs2;
    }
}

############################################################################
# sortRows - Sort rows.
############################################################################
sub sortRows {
    my( $dbh, $recs_ref, $attrs_ref ) = @_;

    my $sortOption = param( "sortOption" );
    my %h;
    my $auxSortRecs_ref = \%h;
    my $attrName = "bit score";
    if( $sortOption eq "ascTaxon" ) {
       $auxSortRecs_ref = $attrs_ref->{ geneTaxonInfo };
       $attrName = "genome name";
    }
    elsif( $sortOption eq "descPercIdent" ) {
       $attrName = "percent identity";
    }
    elsif( $sortOption eq "ascProductName" ) {
       $auxSortRecs_ref = $attrs_ref->{ geneTaxonInfo };
       $attrName = "gene product name";
    }
    print "Sorting by $attrName ...<br/>\n";

    my @sortRecs;
    my $rowIdx = 0;
    for my $r( @$recs_ref ) {
       my( $gene_oid, $homolog, $taxon, $percent_identity, $query_start,
          $query_end, $subj_start, $subj_end, $evalue, $bit_score,
          $align_length ) = split( /\t/, $r );
       my $sortVal = $bit_score;
       if( $sortOption eq "ascTaxon" || $sortOption eq "ascProductName" ) {
          my $val = $auxSortRecs_ref->{ $homolog };
	  my( $gene_display_name, $aa_seq_length,
	      $taxon_oid, $taxon_display_name,
	      $domain, $seq_status ) = split( /\t/, $val );
          $sortVal = $taxon_display_name if $sortOption eq "ascTaxon";
          $sortVal = $gene_display_name if $sortOption eq "ascProductName";
       }
       elsif( $sortOption eq "descPercIdent" ) {
          $sortVal = $percent_identity;
       }
       my $sortRec = "$sortVal\t";
       $sortRec .= "$rowIdx\t";
       push( @sortRecs, $sortRec );
       $rowIdx++;
    }
    ## Alpha
    my @sortRecs2;
    if( $sortOption eq "ascTaxon" || $sortOption eq "ascProductName" ) {
       @sortRecs2 = sort( @sortRecs );
    }
    ## Numeric
    else {
       @sortRecs2 = reverse( sort{ $a <=> $b }( @sortRecs ) );
    }
    my @recs3;
    for my $r2( @sortRecs2 ) {
       my( $val, $rowIdx ) = split( /\t/, $r2 );
       my $r = $recs_ref->[ $rowIdx ];
       push( @recs3, $r );
    }
    my $nRecs = @recs3;
    webLog( "sortRows: $nRecs sorted\n" );
    @$recs_ref = @recs3;
}

############################################################################
# outputRows - Output rows for pager in HTML. Do some column
#   ordering and formatting of sub values.
############################################################################
sub outputRows {
    my( $dbh, $gene_oid, $recs_ref, $attrs_ref ) = @_;

    #print "Output rows ...<br/>\n";

    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );
    my $query_gene_display_name = geneOid2Name( $dbh, $gene_oid );

    my $myMyImgAnnot = param( "myMyImgAnnot" );
    my $allMyImgAnnot = param( "allMyImgAnnot" );
    my $imgTerms = param( "imgTerms" );
    my $enzymes = param( "enzymes" );
    my $scaffoldInfo = param( "scaffoldInfo" );
    my $family = param( "family" );

    my $nRecs = @$recs_ref;
    my $hitsPerPage = param( "hitsPerPage" );
    my $nPages = int( $nRecs / $hitsPerPage ) + 1;
    my $sortOption = param( "sortOption" );
    my $attrName = "bit score";
    if( $sortOption eq "ascTaxon" ) {
       $attrName = "genome name";
    }
    elsif( $sortOption eq "descPercIdent" ) {
       $attrName = "genome name";
    }
    elsif( $sortOption eq "ascProductName" ) {
       $attrName = "gene product name";
    }
    my $sortOptionDesc = "Sort by $attrName";

    my $pagerFileRoot = getPagerFileRoot( $gene_oid );
    my $pagerFileIdx = "$pagerFileRoot.idx";
    my $pagerFileRows = "$pagerFileRoot.rows";
    my $pagerFileMeta = "$pagerFileRoot.meta";

    my $Frows = newWriteFileHandle( $pagerFileRows, "outputRows" );
    my $Fmeta = newWriteFileHandle( $pagerFileMeta, "outputRows" );

    print $Fmeta ".hitsPerPage $hitsPerPage\n";
    print $Fmeta ".sortOptionDesc $sortOptionDesc\n";
    print $Fmeta ".nPages $nPages\n";
    print $Fmeta ".query_gene_oid $gene_oid\n";
    print $Fmeta ".query_gene_display_name $query_gene_display_name\n";
    my( $qgFamily, $taxon_display_name ) = 
       getFamily4GeneOid( $dbh, $gene_oid );
    print $Fmeta ".query_gene_family $qgFamily\n" if $family;
    print $Fmeta ".query_taxon_display_name $taxon_display_name\n" if $family;

    ## Attribute Names
    my $colIdx = 0;
    print $Fmeta ".attrNameStart\n";
    print $Fmeta "$colIdx : Select\n"; $colIdx++;
    print $Fmeta "$colIdx : Row No. : AN : right\n"; $colIdx++;
    print $Fmeta "$colIdx : Homolog : AN :\n"; $colIdx++; 
    print $Fmeta "$colIdx : Product Name : AS :\n"; $colIdx++;
    if( $enzymes ) {
       print $Fmeta "$colIdx : Enzymes : DS :\n"; $colIdx++;
    }
    if( $myMyImgAnnot || $allMyImgAnnot ) {
       print $Fmeta "$colIdx : MyIMG Annotation : AS :\n"; $colIdx++;
    }
    if( $imgTerms ) {
       print $Fmeta "$colIdx : IMG Terms : AS :\n"; $colIdx++;
    }
    if( !$img_lite ) {
       print $Fmeta "$colIdx : T : AS\n"; $colIdx++;
    }
    # Fields: column index : name : sort type : field alignment.
    #   sortType: A = ascending, D = descending, N = number, S = string.
    print $Fmeta "$colIdx : Percent<br/>Identity : DN: right\n"; $colIdx++;
    print $Fmeta "$colIdx : Alignment<br/>On<br/>Query<br/>Gene\n"; $colIdx++;
    print $Fmeta "$colIdx : Alignment<br/>On<br/>Subject<br/>Gene\n"; 
       $colIdx++;
    print $Fmeta "$colIdx : Length : DN: right\n"; $colIdx++;
    print $Fmeta "$colIdx : E-value : AN: right\n"; $colIdx++;
    print $Fmeta "$colIdx : Bit<br/>Score : DN: right\n"; $colIdx++;
    print $Fmeta "$colIdx : D : AS\n"; $colIdx++;
    print $Fmeta "$colIdx : C : AS\n"; $colIdx++;
    if( $family ) {
       print $Fmeta "$colIdx : Above<br/>Genus<br/>Rank : AS\n"; $colIdx++;
    }
    print $Fmeta "$colIdx : Genome : AS\n"; $colIdx++;
    if( $scaffoldInfo ) {
       print $Fmeta "$colIdx : Scaffold ID : AS\n"; $colIdx++;
       print $Fmeta "$colIdx : Scaffold<br/>Length : DN: rigth\n"; $colIdx++;
       print $Fmeta "$colIdx : Scaffold<br/>GC : DN: right\n"; $colIdx++;
    }
    print $Fmeta ".attrNameEnd\n";

    ## Rows
    #  Output values in parirs:
    #  1. HTML display value
    #  2. Sort value
    my $count = 0;
    for my $r( @$recs_ref ) {
       my( $gene_oid, $homolog, $taxon, $percent_identity, $query_start,
          $query_end, $subj_start, $subj_end, $evalue, $bit_score,
          $align_length ) = split( /\t/, $r );
       next if $gene_oid eq $homolog;
       $percent_identity = sprintf( "%.2f%%", $percent_identity );
       $evalue = sprintf( "%.1e", $evalue );
       $bit_score = sprintf( "%d", $bit_score );
       $count++;

       my $myImgAnnotationsDat = getDictVals( 
          $attrs_ref, "myImgAnnotations", $homolog );
       my $imgTermsDat = getDictVals( $attrs_ref, "imgTerms", $homolog );
       my $enzymesDat = getDictVals( $attrs_ref, "enzymes", $homolog );
       my $orthologsDat = getDictVals( $attrs_ref, "orthologs", $homolog );
       my $paralogsDat = getDictVals( $attrs_ref, "paralogs", $homolog );
       my $familyDat = getDictVals( $attrs_ref, "family", $homolog );

       my $geneTaxonInfoDat = getDictVals( 
           $attrs_ref, "geneTaxonInfo", $homolog );
       my( $gene_display_name, $aa_seq_length, 
           $taxon_oid, $taxon_display_name,
	   $domain, $seq_status ) = split( /\t/, $geneTaxonInfoDat );
       $domain = substr( $domain, 0, 1 );
       $seq_status = substr( $seq_status, 0, 1 );

       my $scaffoldInfoDat = getDictVals( 
           $attrs_ref, "scaffoldInfo", $homolog );
       my( $scf_ext_accession, $scf_seq_length, $scf_gc_percent ) =
          split( /\t/, $scaffoldInfoDat );
       $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
       
       my $r2;
       $r2 .= "<input type='checkbox' name='gene_oid' value='$homolog' />\t";
       $r2 .= "\t";

       $r2 .= "$count\t";
       $r2 .= "$count\t";

       my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
       $url .= "&gene_oid=$homolog";
       $r2 .= alink( $url, $homolog ) . "\t";
       $r2 .= "$homolog\t";

       $r2 .= escHtml( $gene_display_name ) . "\t";
       $r2 .= "$gene_display_name\t";

       if( $enzymes ) {
          my( @lines ) = split( /,/, $enzymesDat );
	  my $s;
	  for my $line( @lines ) {
	     $line =~ s/\s+//g;
	     $s .= escHtml( $line ) . "<br/>";
	  };
	  $s = nbsp( 1 ) if $s eq "";
	  $r2 .= "$s\t";
	  $r2 .= "$enzymesDat\t";
       }
       if( $myMyImgAnnot || $allMyImgAnnot ) {
          my( @lines ) = split( /;/, $myImgAnnotationsDat );
	  my $s;
	  for my $line( @lines ) {
	     $line =~ s/^\s+//;
	     $line =~ s/\s+$//;
	     $s .= escHtml( $line ) . "<br/>";
	  };
	  $s = nbsp( 1 ) if $s eq "";
	  $r2 .= "$s\t";
	  $r2 .= "$myImgAnnotationsDat\t";
       }
       if( $imgTerms ) {
          my( @lines ) = split( /\n/, $imgTermsDat );
	  my $s;
	  my $terms2;
	  for my $line( @lines ) {
	     $line =~ s/^\s+//;
	     $line =~ s/\s+$//;
	     my( $term_oid, $term  ) = split( /\t/, $line );
	     $term_oid = FuncUtil::termOidPadded( $term_oid );
	     my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
	     $url .= "&term_oid=$term_oid";
	     $s .= alink( $url, $term_oid );
	     $s .= ":" . escHtml( $term ) . "<br/>";
	     #$s .= alink( $url, $term ) . "<br/>";
	     $terms2 .= "$term / ";
	  };
	  chop $s;
	  chop $s;
	  chop $s;
	  chop $s;
	  chop $s;
	  $s = nbsp( 1 ) if $s eq "";
	  $r2 .= "$s\t";
	  $r2 .= "$terms2\t";
       }
       if( !$img_lite ) {
          my $s = "-";
	  $s = "O" if $orthologsDat ne "";
	  $s = "P" if $paralogsDat ne "";
	  $r2 .= "$s\t";
	  $r2 .= "$s\t";
       }
       $r2 .= "$percent_identity\t";
       $r2 .= "$percent_identity\t";

       $r2 .=  alignImage( $query_start, $query_end, 
          $query_aa_seq_length ) . "\t";
       $r2 .=  "\t";

       $r2 .= alignImage( $subj_start, $subj_end, $aa_seq_length ) . "\t";
       $r2 .= "\t";

       my $aa_seq_length2 = nbsp( 1 );
       $aa_seq_length2 = "${aa_seq_length}aa" if $aa_seq_length > 0;
       $r2 .= "$aa_seq_length2\t";
       $r2 .= "$aa_seq_length\t";

       $r2 .= "$evalue\t";
       $r2 .= "$evalue\t";

       $r2 .= "$bit_score\t";
       $r2 .= "$bit_score\t";

       $r2 .= "$domain\t";
       $r2 .= "$domain\t";

       $r2 .= "$seq_status\t";
       $r2 .= "$seq_status\t";

       if( $family ) {
          $r2 .= "$familyDat\t";
          $r2 .= "$familyDat\t";
       }

       my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
       $url .= "&taxon_oid=$taxon_oid";
       $r2 .= alink( $url, $taxon_display_name ) . "\t";
       $r2 .= "$taxon_display_name\t";

       if( $scaffoldInfo ) {
          $r2 .= "$scf_ext_accession\t";
          $r2 .= "$scf_ext_accession\t";
	  my $scf_seq_length2 = nbsp( 1 );
	  $scf_seq_length2 = "${scf_seq_length}bp" if $scf_seq_length > 0;
	  $r2 .= "$scf_seq_length2\t";
	  $r2 .= "$scf_seq_length\t";
	  $r2 .= "$scf_gc_percent\t";
	  $r2 .= "$scf_gc_percent\t";
       }
       $r2 =~ s/\n/ /g;
       print $Frows "$r2\n";
    }
    print $Fmeta ".total_hits $count\n";

    close $Frows;
    close $Fmeta;

    indexRows( $pagerFileRows, $pagerFileIdx, $hitsPerPage );
}

############################################################################
# getDictVals - Get dictionary values from attribute.
############################################################################
sub getDictVals {
    my( $attrs_ref, $attrName, $gene_oid ) = @_;
    my $attrs2_ref = $attrs_ref->{ $attrName };
    if( !defined( $attrs2_ref ) ) {
       return "";
    }
    my $val = $attrs2_ref->{ $gene_oid };
    $val =~ s/\n/ /g;
    return $val;
}

############################################################################
# indexRows - Index rows in file.
############################################################################
sub indexRows {
    my( $inFile, $outFile, $hitsPerPage, $nPages ) = @_;

    my $rfh = newReadFileHandle( $inFile, "indexRows" );
    my $wfh = newWriteFileHandle( $outFile, "indexRows" );
    my $count = 0;
    my $fpos = tell( $rfh );
    my $pageNo = 1;
    print $wfh "$pageNo $fpos\n";
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	$count++;
	if( $count > $hitsPerPage ) {
	   $pageNo++;
	   print $wfh "$pageNo $fpos\n";
	   $count = 1;
	}
	$fpos = tell( $rfh );
    }
    close $rfh;
    close $wfh;
}

############################################################################
# printHomologPager - Show pages in pager.
############################################################################
sub printHomologPager {
   my $gene_oid = param( "gene_oid" );
   my $pageNo = param( "pageNo" );
   my $sortType = param( "sortType" );
   my $colIdx = param( "colIdx" );
   my $hitsPerPage = param( "hitsPerPage" );

   print "<h1>Homolog Toolkit</h1>\n";
   printMainForm( );
   printStatusLine( "Loading ...", 1 );
   if( $sortType ne "" ) {
      sortHomologFile( $gene_oid, $sortType, $colIdx, $hitsPerPage );
      $pageNo = 1;
   }
   printOnePage( $gene_oid, $pageNo );
   printStatusLine( "Loaded.", 2 );
   print end_form( );
}

############################################################################
# sortHomologFile - Resort homolog file.
############################################################################
sub sortHomologFile {
   my( $gene_oid, $sortType, $colIdx, $hitsPerPage ) = @_;

   #print "<p>\n";
   #print "Resorting ...<br/>\n";
   #print "</p>\n";
   webLog( "resorting sortType='$sortType' colIdx='$colIdx'\n" );
   my $pagerFileRoot = getPagerFileRoot( $gene_oid );
   my $pagerFileRows = "$pagerFileRoot.rows";
   my $pagerFileIdx = "$pagerFileRoot.idx";
   my $rfh = newReadFileHandle( $pagerFileRows, "sortHomologFile" );
   my @recs;
   my $rowIdx = 0;
   my @sortRecs;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      push( @recs, $s );
      my( @vals ) = split( /\t/, $s );
      my $idx = ( $colIdx * 2  ) + 1;
      my $sortVal = $vals[ $idx ];
      my $sortRec = "$sortVal\t";
      $sortRec .= "$rowIdx";
      push( @sortRecs, $sortRec );
      $rowIdx++;
   }
   close $rfh;
   my @sortRecs2;
   if( $sortType =~ /N/ ) {
      if( $sortType =~ /D/ ) {
         @sortRecs2 = reverse( sort{ $a <=> $b  }( @sortRecs ) );
      }
      else {
         @sortRecs2 = sort{ $a <=> $b  }( @sortRecs );
      }
   }
   else {
      if( $sortType =~ /D/ ) {
         @sortRecs2 = reverse( sort( @sortRecs ) );
      }
      else {
         @sortRecs2 = sort( @sortRecs );
      }
   }
   my $wfh = newWriteFileHandle( $pagerFileRows, "sortHomologFile" );
   for my $r2( @sortRecs2 ) {
      my( $sortVal, $rowIdx ) = split( /\t/, $r2 );
      my $r = $recs[ $rowIdx ];
      print $wfh "$r\n";
   }
   close $wfh;
   indexRows( $pagerFileRows, $pagerFileIdx, $hitsPerPage );
}

############################################################################
# getPagerFileRoot - Convention for getting the pager file.
############################################################################
sub getPagerFileRoot {
   my( $gene_oid ) = @_;
   my $sessionId = getSessionId( );
   my $tmpPagerFile = "$cgi_tmp_dir/homologToolkit.$gene_oid.$sessionId";
}

############################################################################
# printOnePage - Print one page for pager.
############################################################################
sub printOnePage {
   my( $gene_oid, $pageNo ) = @_;
   $gene_oid = param( "gene_oid" ) if $gene_oid eq "";
   $pageNo = param( "pageNo" )  if $pageNo eq "";
   $pageNo = 1 if $pageNo eq "";

   my $pagerFileRoot = getPagerFileRoot( $gene_oid );
   my $pagerFileIdx = "$pagerFileRoot.idx";
   my $pagerFileRows = "$pagerFileRoot.rows";
   my $pagerFileMeta = "$pagerFileRoot.meta";
   if( !-e( $pagerFileIdx ) ) {
       warn( "$pagerFileIdx not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }
   if( !-e( $pagerFileRows ) ) {
       warn( "$pagerFileRows not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }
   if( !-e( $pagerFileMeta ) ) {
       warn( "$pagerFileMeta not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }

   my %metaData = loadMetaData( $pagerFileMeta );
   my $sortOptionDesc = $metaData{ sortOptionDesc };
   my $hitsPerPage = $metaData{ hitsPerPage };
   my $query_gene_oid = $metaData{ query_gene_oid };
   my $query_gene_display_name = $metaData{ query_gene_display_name };
   my $query_gene_family = $metaData{ query_gene_family };
   my $query_taxon_display_name = $metaData{ query_taxon_display_name };
   my $attrSpecs_ref = $metaData{ attrSpecs };
   my $nAttrSpecs = @$attrSpecs_ref;
   my $nAttrSpecs2 = $nAttrSpecs * 2;
   my $total_hits = $metaData{ total_hits };

   printMainForm( );
   print "<p>\n";
   my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
   $url .= "&gene_oid=$query_gene_oid";
   my $link = alink( $url, $gene_oid );
   print "Homologs for query gene $link <i>" . 
      escHtml( $query_gene_display_name ) . "</i>.<br/>\n";
   if( $query_gene_family ne "" ) {
      print "Query Gene Above Genus Rank: <i>" . 
         escHtml( $query_gene_family ) .  "</i><br/>\n";
      print "for <i>" . escHtml( $query_taxon_display_name ) . "</i>.<br/>\n";
   }
   print escHtml( $sortOptionDesc ) . "<br/>\n";
   print "$total_hits total hits.<br/>\n";
   print "</p>\n";
   printPageHeader( $pagerFileIdx, $gene_oid, $pageNo );

   printGeneCartFooter( );
   print "<p>\n";
   print "Types (T): O = Ortholog, P = Paralog, " .
       "- = other unidirectional hit.<br/>\n" if !$img_lite;
   print domainLetterNote( ) . "<br/>\n";
   print completionLetterNote( ) . "<br/>\n";
   print "Click on column name to sort.<br/>\n";
   print "</p>\n";
   printAddQueryGeneCheckBox( $gene_oid );
   print "<table class='img'>\n";
   my %rightAlign;
   my $idx = 0;
   for my $attrSpec( @$attrSpecs_ref ) {
      my( $colIdx, $attrName, $sortType, $align ) = split( /:/, $attrSpec );
      $colIdx =~ s/\s//g;
      $attrName =~ s/^\s+//;
      $attrName =~ s/\s+$//;
      $sortType =~ s/\s+//g;
      if( $sortType eq "" ) {
         print "<th class='img'>$attrName</th>\n";
      }
      else {
	 my $url = "$section_cgi&page=homologPager";
	 $url .= "&sortType=$sortType";
	 $url .= "&gene_oid=$gene_oid";
	 $url .= "&colIdx=$colIdx";
	 $url .= "&pageNo=1";
	 $url .= "&hitsPerPage=$hitsPerPage";
	 my $link = alink( $url, $attrName, "", 1 );
         print "<th class='img'>$link</th>\n";
      }
      if( $align =~ /right/ ) {
         $rightAlign{ $idx } = 1;
      }
      $idx++;
   }
   my $fpos = getFilePosition( $pagerFileIdx, $pageNo );
   my $rfh = newReadFileHandle( $pagerFileRows, "printOnePage" );
   seek( $rfh, $fpos, 0 );
   my $count = 0;
   while( my $s = $rfh->getline( ) ) {
      my( @vals ) = split( /\t/, $s );
      my $nVals = @vals;
      $count++;
      if( $count > $hitsPerPage ) {
         last;
      }
      print "<tr class='img'>\n";
      for( my $i = 0; $i < $nAttrSpecs; $i++ ) {
         my $right = $rightAlign{ $i };
	 my $alignSpec;
	 $alignSpec = "align='right'" if $right;
	 my $val = $vals[ $i*2 ];
	 print "<td class='img' $alignSpec>$val</td>\n";
      }
      print "</tr>\n";
   }
   close $rfh;
   print "</table>\n";
   printGeneCartFooter( ) if $count > 10;
   printPageHeader( $pagerFileIdx, $gene_oid, $pageNo );
   my $url = "$section_cgi&page=queryForm&gene_oid=$gene_oid";
   print buttonUrl( $url, "Start Over", "medbutton" );
   print end_form( );

}

############################################################################
# loadMetaData - Load metadata about the pager.
############################################################################
sub loadMetaData {
   my( $inFile ) = @_;

   my %meta;
   my $rfh = newReadFileHandle( $inFile, "loadMetaData" );
   my $inAttrs = 0;
   my @attrSpecs;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      if( $s =~ /^\.attrNameStart/ ) {
         $inAttrs = 1;
      }
      elsif( $s =~ /^\.attrNameEnd/ ) {
	 $meta{ attrSpecs } = \@attrSpecs;
         $inAttrs = 0;
      }
      elsif( $inAttrs ) {
         push( @attrSpecs, $s );
      }
      elsif( $s =~ /^\./ ) {
         my( $tag, @toks ) = split( / /, $s );
	 $tag =~ s/^\.//;
	 my $val = join( ' ', @toks );
	 $meta{ $tag } =  $val;
      }
   }
   close $rfh;
   return %meta;
}


############################################################################
# printPageHeader - Print header with all the pages.
############################################################################
sub printPageHeader {
   my( $idxFile, $gene_oid, $currPageNo ) = @_;

   my $rfh = newReadFileHandle( $idxFile, "printPageHeader" );
   print "<p>\n";
   print "Pages:";
   my $lastPageNo = 1;
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $pageNo, $fpos ) = split( / /, $s );
       print nbsp( 1 );
       if( $pageNo eq $currPageNo ) {
           print "[";
       }
       my $url = "$section_cgi&page=homologPager";
       $url .= "&gene_oid=$gene_oid&pageNo=$pageNo";
       print alink( $url, $pageNo );
       if( $pageNo eq $currPageNo ) {
           print "]";
       }
       $lastPageNo = $pageNo;
   }
   if( $currPageNo < $lastPageNo ) {
       print nbsp( 1 );
       my $nextPageNo = $currPageNo + 1;
       my $url = "$section_cgi&page=homologPager";
       $url .= "&gene_oid=$gene_oid&pageNo=$nextPageNo";
       print "[" . alink( $url, "Next Page" ) . "]";
   }
   close $rfh;
   print "</p>\n";
}

############################################################################
# getFilePosition - Get file positino given page no.
############################################################################
sub getFilePosition {
   my( $idxFile, $currPageNo ) = @_;

   my $rfh = newReadFileHandle( $idxFile, "getFilePosition" );
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $pageNo, $fpos ) = split( / /, $s );
       if( $pageNo eq $currPageNo ) {
	  close $rfh;
          return $fpos;
       }
   }
   close $rfh;
   return 0;
}

############################################################################
# getFamily4GeneOid - Get the family for current gene_oid, or higher
#   rank if "unclassified".
############################################################################
sub getFamily4GeneOid {
    my( $dbh, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.family, tx.ir_order, tx.ir_class, tx.phylum, 
	  tx.taxon_display_name
	from gene g, taxon tx
	where g.taxon = tx.taxon_oid
	and g.gene_oid = $gene_oid
	$rclause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $family, $ir_order, $ir_class, $phylum, 
        $taxon_display_name ) = $cur->fetchrow( );
    my $rank = $family;
    $rank = $ir_order if $rank eq "unclassified";
    $rank = $ir_class if $rank eq "unclassified";
    $rank = $phylum if $rank eq "unclassified";
    $cur->finish( );
    return( $rank, $taxon_display_name );
}

1;


