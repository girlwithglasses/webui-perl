############################################################################
# GenBankFile.pm - Generate GenBank files.
#     --es 04/13/2006
#
# $Id: GenBankFile.pm 30360 2014-03-08 00:12:52Z jinghuahuang $
############################################################################
package GenBankFile;
my $section = "GenBankFile";
use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use Data::Dumper;
use WebUtil;
use WebConfig;
use QueryUtil;

$| = 1;

my $maxPageWidth  = 80;
my $featureIndent = 21;

my $env               = getEnv();
my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};
my $tmp_url           = $env->{tmp_url};
my $tmp_dir           = $env->{tmp_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};
my $artemis_url       = $env->{artemis_url};
my $artemis_link      = alink( $artemis_url, "Artemis" );
my $verbose           = $env->{verbose};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "" ) {
    } else {
    }
}

############################################################################
# printProcessGenBank - print processing results for GenBank file.
############################################################################
sub printProcessGenBank {
    my ( $scaffold_oid, $myImgOverride, $imgTermOverride, $gene_oid_note,
         $offset, $mygeneOverride, $misc_features ) = @_;

    if ( $scaffold_oid eq "" ) {
        webError("Please select a scaffold.");
    }
    print "<h1>Generate Genbank File</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $tmpFile     = "$scaffold_oid.$$.gbk";
    my $tmpFilePath = "$cgi_tmp_dir/$tmpFile";
    wunlink($tmpFilePath);
    writeScaffold2GenBankFile(
                               $scaffold_oid,   $tmpFilePath,
                               $myImgOverride,  $imgTermOverride,
                               $gene_oid_note,  $offset,
			                   $mygeneOverride, $misc_features
    );
    printStatusLine( "Loaded.", 2 );

    print hiddenVar( "scaffold_oid", $scaffold_oid );
    print hiddenVar( "pid",          $$ );
    print hiddenVar( "type",         "gbk" );

    my $name = "_section_TaxonDetail_viewArtemisFile";
    print submit(
                  -name  => $name,
                  -value => "View Results",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_TaxonDetail_downloadArtemisFile";
    my $contact_oid = WebUtil::getContactOid();
    print submit(
                  -name  => $name,
                  -value => "Download File",
                  -class => "medbutton",
                  -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']);"
    );

    print "<br/>\n";
    printHint("The downloaded file is viewable by $artemis_link.");

    print end_form();
}

############################################################################
# writeScaffold2GenBankFile - Given scaffold_oid write an output file.
############################################################################
sub writeScaffold2GenBankFile {
    my ( $scaffold_oid, $outFile, $myImgOverride, $imgTermOverride,
         $gene_oid_note, $offset, $mygeneOverride, $misc_features, $notPrint )
      = @_;

    $offset = 0 if ( $offset eq "" );

    if ( $verbose >= 1 ) {
        webLog "myImgOverride='$myImgOverride'\n";
        webLog "imgTermOverride='$imgTermOverride'\n";
    }
    $myImgOverride   = 1 if $myImgOverride   eq "on";
    $imgTermOverride = 1 if $imgTermOverride eq "on";

    my $dbh = dbLogin();
    checkScaffoldPerm( $dbh, $scaffold_oid );

    my $wfh = newAppendFileHandle( $outFile, "writeScaffold2GenBankFile" );

    #my $cur = execSql( $dbh, "select sysdate from dual", $verbose );
    #my $sydate = $cur->fetchrow( );
    #$cur->finish( );
    my $sysdate = getSysDate();

    my $ext_accession = scaffoldOid2ExtAccession( $dbh, $scaffold_oid );
    print "<p>\n" if (!$notPrint);
    print "Retrieve scaffold $ext_accession information ...<br/>\n" if (!$notPrint);
    ## We kludge chromosome for historical reasons since this value
    #  isn't always filled in.
    #  Assume chromosome_oid is same as scaffold_oid.
    my $sql = getScaffoldStatTaxonInfoSql();
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my (
         $scf_ext_accession, $scf_seq_length,     $mol_type,
         $mol_topology,      $scaffold_name,      $taxon_oid,
         $ncbi_taxon_id,     $taxon_display_name, $domain,
         $phylum,            $ir_class,           $ir_order,
         $family,            $genus,              $species,
         $strain
      )
      = $cur->fetchrow();
    $cur->finish();

    my $lineage = "$domain; $phylum; $ir_class; $ir_order; $family; $genus.";
    my $sp      = " " x 4;
    printLine01(
                 $wfh,
                 "LOCUS",
                 "$scf_ext_accession $sp $scf_seq_length bp "
                   . "$sp DNA $mol_topology $sp $sysdate"
    );
    printLine01( $wfh, "DEFINITION", $scaffold_name );
    printLine01( $wfh, "COMMENT",    getComments( $dbh, $scaffold_oid ) );
    printLine01( $wfh, "SOURCE",     $taxon_display_name );
    printLine01( $wfh, "  ORGANISM", $taxon_display_name );
    printLine01( $wfh, "",           $lineage );

    printTagVal( $wfh, 0, "FEATURES", $featureIndent, "Location/Qualifiers" );

    ## Source
    my $h = {
              _coords  => "1..$scf_seq_length",
              organism => $taxon_display_name,
              mol_type => $mol_type,
              strain   => $strain,
              db_xref  => "taxon:$ncbi_taxon_id",
    };
    printFeature( $wfh, "source", $h );

    ## Enzymes
    print "Process enzymes ...<br/>\n" if (!$notPrint);
    my %geneEnzymes;
    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = getGeneKoEnzymesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $enzyme ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneEnzymes{$gene_oid} .= "$enzyme ";
    }
    $cur->finish();

    ## IMG term override
    print "Process IMG terms ...<br/>\n" if (!$notPrint);
    my %geneImgTerms;
    my $sql = getGeneImgFunctionsSql($rclause, $imgClause);    
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $term, $f_order ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneImgTerms{$gene_oid} .= "$term\n";
    }
    $cur->finish();

    my %geneFeatures;
    if( $misc_features ) {
	    print "Process gene features ...<br/>\n" if (!$notPrint);
        my $sql = qq{
            select gft.gene_oid, gft.tag, gft.value
    	    from gene g, gene_feature_tags gft
    	    where g.gene_oid = gft.gene_oid
    	    and g.taxon = ?
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for( ;; ) {
            my( $gene_oid, $tag, $value ) = $cur->fetchrow( );
    	    last if !$gene_oid;
    	    next if (blankStr($value));
    
    	    $value =~ s/"/'/g;
    	    $geneFeatures{ $gene_oid } .= "$tag\t$value\n";
        }
        $cur->finish( );
    }

    my $contact_oid = getContactOid();

    ## Iterate through genes
    my $mygene_sql = ""; 
    if ( $mygeneOverride ) { 
        print "Process genes and my missing genes ...<br/>\n" if (!$notPrint); 
 
        $mygene_sql = qq{ 
            select g.mygene_oid, g.gene_display_name, 
                g.start_coord, g.end_coord, 
                g.strand, g.locus_type, g.locus_tag, 
                g.gene_symbol, 
                g.protein_seq_accid, g.is_pseudogene, 1, g.description 
            from mygene g 
            where g.modified_by = $contact_oid 
            and g.scaffold = $scaffold_oid 
            and (g.obsolete_flag is null 
                 or g.obsolete_flag != 'Yes')
            $rclause
            $imgClause
        }; 
    } 
    else { 
        print "Process genes ...<br/>\n" if (!$notPrint); 
    } 
    
    my $sql = qq{ 
        select g.gene_oid, g.gene_display_name, g.start_coord, g.end_coord, 
           g.strand, g.locus_type, g.locus_tag, g.gene_symbol,
           g.protein_seq_accid, g.is_pseudogene, 0, g.description
        from gene g 
        where g.scaffold = $scaffold_oid 
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    }; 

    if ( ! blankStr($mygene_sql) ) {
        $sql .= " union $mygene_sql";
    }
    $sql .= " order by 3"; 
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
             $gene_oid,          $gene_display_name, $start_coord,
             $end_coord,         $strand,            $locus_type,
             $locus_tag,         $gene_symbol,       
#	    $aa_residue,
             $protein_seq_accid, $is_pseudogene, $is_mygene, $gene_desc
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $aa_residue = ''; 
        if( $start_coord > $scf_seq_length || $end_coord > $scf_seq_length ) { 
            webLog( "$0: bad coordinate $start_coord..$end_coord for " .
		    "scf_seq_length=$scf_seq_length\n" ); 
            next; 
        } 

        if ( $start_coord > $scf_seq_length || $end_coord > $scf_seq_length ) {
            webLog(   "$0: bad coordinate $start_coord..$end_coord for "
                    . "scf_seq_length=$scf_seq_length\n" );
            next;
        }

        my $has_myimg_annot     = 0;
        my $myimg_product_name  = "";
        my $myimg_prot_desc     = "";
        my $myimg_ec_number     = "";
        my $myimg_pubmed_id     = "";
        my $myimg_inference     = "";
        my $myimg_is_pseudogene = "";
        my $myimg_notes         = "";
        my $myimg_obsolete_flag = ""; 

        if ($myImgOverride && !$is_mygene) {

            # IMG 2.3
            if ($contact_oid) {
                my $sql2 = getGeneMyimgFunctionsSql($rclause, $imgClause);
                my $cur2 =
                  execSql( $dbh, $sql2, $verbose, $gene_oid, $contact_oid );
                my $g_oid;
                (  $g_oid,               $myimg_product_name,
                   $myimg_prot_desc,     $myimg_ec_number,
                   $myimg_pubmed_id,     $myimg_inference,
                   $myimg_is_pseudogene, $myimg_notes,
                   $myimg_obsolete_flag) = $cur2->fetchrow();
                $cur2->finish();

                if ( $myimg_obsolete_flag eq 'Yes' ) {
                    # skip this gene
                    next; 
                } 

                if ( $g_oid && !blankStr($myimg_product_name) ) {
                    $has_myimg_annot = 1;

                    $gene_display_name = $myimg_product_name;

                    if ( !blankStr($myimg_is_pseudogene) ) {
                        $is_pseudogene = $myimg_is_pseudogene;
                    }
                }
            }
        }

        if ( $imgTermOverride && $has_myimg_annot == 0 && !$is_mygene) {
            my $termsStr = $geneImgTerms{$gene_oid};
            my @terms    = split( /\n/, $termsStr );
            my $termStr2 = join( ' / ', @terms );
            $gene_display_name = $termStr2
	       if !blankStr( $termStr2 );
        }
        my $img_terms = $geneImgTerms{$gene_oid};

        my $coords;

        # v2.9 for ACT - ken
        if ( $offset > 0 ) {
            my $ts = $start_coord + $offset;
            my $te = $end_coord + $offset;
            $coords = getCoords( $ts, $te, $strand );
        } else {
            $coords = getCoords( $start_coord, $end_coord, $strand );
        }

        my $h = {
                  _coords       => $coords,
                  gene          => $gene_symbol,
                  locus_tag     => $locus_tag,
                  is_pseudogene => $is_pseudogene,
                  img_terms     => $img_terms,
        };
        if( $gene_oid_note ) { 
            if ( $is_mygene ) { 
                if ( $gene_desc ) { 
                    $h->{ note } .= "My missing gene gene_oid=$gene_oid (description: $gene_desc)\n"; 
                } 
                else {
                    $h->{ note } .= "My missing gene gene_oid=$gene_oid\n";
                } 
            } 
            else {
                $h->{ note } .= "IMG gene_oid=$gene_oid\n";
            } 
        } 
        elsif ( $is_mygene ) { 
            if ( $gene_desc ) { 
                $h->{ note } .= "My missing gene (description: $gene_desc)\n";
            }
            else { 
                $h->{ note } .= "My missing gene\n"; 
            } 
        } 

        if ( $myImgOverride && $has_myimg_annot && !$is_mygene) {

            # add IMG annotations
            if ( !blankStr($myimg_prot_desc) ) {
                $h->{prot_desc} = $myimg_prot_desc;
            }
            if ( !blankStr($myimg_pubmed_id) ) {
                $myimg_pubmed_id =~ s/;/ /g;
                my @pubmed_arr = split( / /, $myimg_pubmed_id );
                for my $s2 (@pubmed_arr) {
                    if ( !blankStr($s2) ) {
                        $h->{db_xref} .= "$s2\n";
                    }
                }
            }
            if ( !blankStr($myimg_inference) ) {
                $h->{inference} = $myimg_inference;
            }

            #	    if ( !blankStr($myimg_is_pseudogene) ) {
            #		$h->{ pseudo } .= "$myimg_is_pseudogene\n";
            #	    }
            if ( !blankStr($myimg_notes) ) {
                $h->{note} .= "$myimg_notes\n";
            }
        }

        my $enzymes = "";
        if (    $myImgOverride
             && $has_myimg_annot
             && !blankStr($myimg_ec_number) )
        {

            # use annotated EC numbers instead
            $myimg_ec_number =~ s/;/ /g;
            $enzymes = $myimg_ec_number;
        } else {

            # get from gene_ko_enzymes table
            $enzymes = $geneEnzymes{$gene_oid};
        }
	    my $geneFeaturesStr = $geneFeatures{ $gene_oid };

        printFeature( $wfh, "gene", $h, $geneFeaturesStr );
        next if $is_pseudogene eq "Yes";
        if ( $locus_type eq "tRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "tRNA", $h );
        } elsif ( $locus_type eq "rRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "rRNA", $h );
        } elsif ( $locus_type eq "ncRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "ncRNA", $h );
        } elsif ( $locus_type eq "snoRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "snoRNA", $h );
        } elsif ( $locus_type eq "snRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "snRNA", $h );
        } elsif ( $locus_type eq "scRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "scRNA", $h );
        } elsif ( $locus_type =~ /RNA/ ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "misc_RNA", $h );
        } elsif ( $locus_type eq "CDS" ) {
            my $aa_sql = "select aa_residue from gene where gene_oid = $gene_oid";
            if ( $is_mygene ) { 
                $aa_sql = "select aa_residue from mygene where mygene_oid = $gene_oid";
            } 
            my $aa_cur = execSql( $dbh, $aa_sql, $verbose ); 
            ($aa_residue) = $aa_cur->fetchrow( );
            $aa_cur->finish();

            $h->{product}     = $gene_display_name;
            $h->{protein_id}  = $protein_seq_accid;
            $h->{translation} = $aa_residue;
            $h->{enzymes}     = $enzymes;
            printFeature( $wfh, "CDS", $h );
        }
    }
    $cur->finish();

    ## Repeats
    my $sql = getScaffoldRepeatsSql();
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $start_coord, $end_coord, $type ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        my $coords = "$start_coord..$end_coord";
        my $h = {
                  _coords    => $coords,
                  rpt_family => "$type",
        };
        printFeature( $wfh, "repeat_region", $h );
    }
    $cur->finish();

    ## scaffold_misc_features
    my $sql = qq{
        select s.scaffold_oid, s.frag_coord, s.note, s.locus_tag, s.inference
    	from scaffold_misc_features s
    	where s.scaffold_oid = ?
    	order by s.frag_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $frag_coord, $note, $locus_tag, $inference ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        my $coords = $frag_coord;
        my $h = {
                  _coords    => $coords,
                  note => $note,
		  locus_tag => $locus_tag,
		  inference => $inference,
        };
        printFeature( $wfh, "misc_feature", $h );
    }
    $cur->finish();

    ## scaffold_misc_bindings
    my $sql = qq{
        select s.scaffold_oid, s.frag_coord, s.note, s.bound_moiety
    	from scaffold_misc_bindings s
    	where s.scaffold_oid = ?
    	order by s.frag_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $frag_coord, $note, $bound_moiety ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        my $coords = $frag_coord;
        my $h = {
                  _coords    => $coords,
                  note => $note,
		  bound_moiety => $bound_moiety,
        };
        printFeature( $wfh, "misc_bindings", $h );
    }
    $cur->finish();

    ## scaffolds_sig_peptides
    my $sql = qq{
        select s.scaffold_oid, s.frag_coord, s.note, s.locus_tag, s.inference
    	from scaffold_sig_peptides s
    	where s.scaffold_oid = ?
    	order by s.frag_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $frag_coord, $note, $locus_tag, $inference ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        my $coords = $frag_coord;
        my $h = {
                  _coords    => $coords,
                  note => $note,
		  locus_tag => $locus_tag,
		  inference => $inference,
        };
        printFeature( $wfh, "sig_peptide", $h );
    }
    $cur->finish();

    ## Get the sequence
    print "Process scaffold DNA sequence ...<br/>\n" if (!$notPrint);
    my $sql = QueryUtil::getSingleScaffoldTaxonSql();
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ( $taxon_oid, $scf_ext_accession ) = $cur->fetchrow();
    $cur->finish();
    printScaffoldSequence( $wfh, $taxon_oid, $scf_ext_accession,
                           $scf_seq_length );
    print $wfh "//\n";
    close $wfh;
    #$dbh->disconnect();
    print "</p>\n" if (!$notPrint);
}

# this version for artemis ACT
sub writeScaffold2GenBankFile_act_header {
    my ( $dbh, $wfh, $scaffold_oid, $outFile, $myImgOverride, $imgTermOverride,
         $gene_oid_note, $total_basepair )
      = @_;

    $myImgOverride   = 1 if $myImgOverride   eq "on";
    $imgTermOverride = 1 if $imgTermOverride eq "on";

    checkScaffoldPerm( $dbh, $scaffold_oid );

    my $sysdate = getSysDate();

    my $ext_accession = scaffoldOid2ExtAccession( $dbh, $scaffold_oid );

    print "Retrieve scaffold $ext_accession information ...<br/>\n";

    ## We kludge chromosome for historical reasons since this value
    #  isn't always filled in.
    #  Assume chromosome_oid is same as scaffold_oid.
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select scf.ext_accession, ss.seq_length, 
           scf.mol_type, scf.mol_topology,
           scf.scaffold_name, tx.taxon_oid, tx.ncbi_taxon_id,
           tx.taxon_display_name, tx.domain, tx.phylum,
           tx.ir_class, tx.ir_order, tx.family, tx.genus, tx.species,
           tx.strain
        from scaffold scf, taxon tx, scaffold_stats ss
        where scf.scaffold_oid = ?
        and scf.taxon = tx.taxon_oid
        and scf.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my (
         $scf_ext_accession, $scf_seq_length,     $mol_type,
         $mol_topology,      $scaffold_name,      $taxon_oid,
         $ncbi_taxon_id,     $taxon_display_name, $domain,
         $phylum,            $ir_class,           $ir_order,
         $family,            $genus,              $species,
         $strain
      )
      = $cur->fetchrow();
    $cur->finish();
    my $lineage = "$domain; $phylum; $ir_class; $ir_order; $family; $genus.";
    my $sp      = " " x 4;
    printLine01(
                 $wfh,
                 "LOCUS",
                 "$scf_ext_accession $sp $total_basepair bp "
                   . "$sp DNA $mol_topology $sp $sysdate"
    );
    printLine01( $wfh, "DEFINITION", $scaffold_name );
    printLine01( $wfh, "COMMENT",    getComments( $dbh, $scaffold_oid ) );
    printLine01( $wfh, "SOURCE",     $taxon_display_name );
    printLine01( $wfh, "  ORGANISM", $taxon_display_name );
    printLine01( $wfh, "",           $lineage );

    printTagVal( $wfh, 0, "FEATURES", $featureIndent, "Location/Qualifiers" );

    ## Source
    my $h = {
              _coords  => "1..$total_basepair",
              organism => $taxon_display_name,
              mol_type => $mol_type,
              strain   => $strain,
              db_xref  => "taxon:$ncbi_taxon_id",
    };
    printFeature( $wfh, "source", $h );

    ## Iterate through genes
}

# this version for artemis ACT
sub writeScaffold2GenBankFile_act {
    my ( $dbh, $wfh, $scaffold_oid, $outFile, $myImgOverride, $imgTermOverride,
         $gene_oid_note, $offset )
      = @_;

    $offset = 0 if ( $offset eq "" );

    if ( $verbose >= 1 ) {
        webLog "myImgOverride='$myImgOverride'\n";
        webLog "imgTermOverride='$imgTermOverride'\n";
    }
    $myImgOverride   = 1 if $myImgOverride   eq "on";
    $imgTermOverride = 1 if $imgTermOverride eq "on";

    checkScaffoldPerm( $dbh, $scaffold_oid );

    #my $cur = execSql( $dbh, "select sysdate from dual", $verbose );
    #my $sydate = $cur->fetchrow( );
    #$cur->finish( );
    my $sysdate = getSysDate();

    my $ext_accession = scaffoldOid2ExtAccession( $dbh, $scaffold_oid );
    print "<p>\n";
    print "Retrieve scaffold $ext_accession information ...<br/>\n";
    ## We kludge chromosome for historical reasons since this value
    #  isn't always filled in.
    #  Assume chromosome_oid is same as scaffold_oid.
    my $sql = getScaffoldStatTaxonInfoSql();
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my (
         $scf_ext_accession, $scf_seq_length,     $mol_type,
         $mol_topology,      $scaffold_name,      $taxon_oid,
         $ncbi_taxon_id,     $taxon_display_name, $domain,
         $phylum,            $ir_class,           $ir_order,
         $family,            $genus,              $species,
         $strain
      )
      = $cur->fetchrow();
    $cur->finish();

    ## Enzymes
    print "Process enzymes ...<br/>\n";
    my %geneEnzymes;
    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = getGeneKoEnzymesSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $enzyme ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneEnzymes{$gene_oid} .= "$enzyme ";
    }
    $cur->finish();

    ## IMG term override
    print "Process IMG terms ...<br/>\n";
    my %geneImgTerms;
    my $sql = getGeneImgFunctionsSql($rclause, $imgClause);
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $term, $f_order ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneImgTerms{$gene_oid} .= "$term\n";
    }
    $cur->finish();

    ## Iterate through genes
    print "Process genes ...<br/>\n";
    my $contact_oid = getContactOid();
    my $sql         = qq{
        select g.gene_oid, g.gene_display_name, g.start_coord, g.end_coord,
           g.strand, g.locus_type, g.locus_tag, g.gene_symbol, g.aa_residue,
           g.protein_seq_accid, g.is_pseudogene
        from gene g
        where g.scaffold = $scaffold_oid
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        order by g.start_coord
    };
    
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
             $gene_oid,          $gene_display_name, $start_coord,
             $end_coord,         $strand,            $locus_type,
             $locus_tag,         $gene_symbol,       $aa_residue,
             $protein_seq_accid, $is_pseudogene
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        if ( $start_coord > $scf_seq_length || $end_coord > $scf_seq_length ) {
            webLog(   "$0: bad coordinate $start_coord..$end_coord for "
                    . "scf_seq_length=$scf_seq_length\n" );
            next;
        }

        my $has_myimg_annot     = 0;
        my $myimg_product_name  = "";
        my $myimg_prot_desc     = "";
        my $myimg_ec_number     = "";
        my $myimg_pubmed_id     = "";
        my $myimg_inference     = "";
        my $myimg_is_pseudogene = "";
        my $myimg_notes         = "";
        my $myimg_obsolete_flag = ""; 

        if ($myImgOverride) {

            # IMG 2.3
            if ($contact_oid) {
                my $sql2 = getGeneMyimgFunctionsSql($rclause, $imgClause);
                my $cur2 =
                  execSql( $dbh, $sql2, $verbose, $gene_oid, $contact_oid );
                my $g_oid;
                (  $g_oid,               $myimg_product_name,
                   $myimg_prot_desc,     $myimg_ec_number,
                   $myimg_pubmed_id,     $myimg_inference,
                   $myimg_is_pseudogene, $myimg_notes,
                   $myimg_obsolete_flag
                  ) = $cur2->fetchrow();
                $cur2->finish();

                if ( $g_oid && !blankStr($myimg_product_name) ) {
                    $has_myimg_annot = 1;

                    $gene_display_name = $myimg_product_name;

                    if ( !blankStr($myimg_is_pseudogene) ) {
                        $is_pseudogene = $myimg_is_pseudogene;
                    }
                }
            }
        }

        if ( $imgTermOverride && $has_myimg_annot == 0 ) {
            my $termsStr = $geneImgTerms{$gene_oid};
            my @terms    = split( /\n/, $termsStr );
            my $termStr2 = join( ' / ', @terms );
            $gene_display_name = $termStr2;
        }
        my $img_terms = $geneImgTerms{$gene_oid};

        my $coords;

        # v2.9 for ACT - ken
        if ( $offset > 0 ) {
            my $ts = $start_coord + $offset;
            my $te = $end_coord + $offset;
            $coords = getCoords( $ts, $te, $strand );
        } else {
            $coords = getCoords( $start_coord, $end_coord, $strand );
        }

        my $h = {
                  _coords       => $coords,
                  gene          => $gene_symbol,
                  locus_tag     => $locus_tag,
                  is_pseudogene => $is_pseudogene,
                  img_terms     => $img_terms,
        };
        if ($gene_oid_note) {
            $h->{note} .= "IMG gene_oid=$gene_oid\n";
        }

        if ( $myImgOverride && $has_myimg_annot ) {

            # add IMG annotations
            if ( !blankStr($myimg_prot_desc) ) {
                $h->{prot_desc} = $myimg_prot_desc;
            }
            if ( !blankStr($myimg_pubmed_id) ) {
                $myimg_pubmed_id =~ s/;/ /g;
                my @pubmed_arr = split( / /, $myimg_pubmed_id );
                for my $s2 (@pubmed_arr) {
                    if ( !blankStr($s2) ) {
                        $h->{db_xref} .= "$s2\n";
                    }
                }
            }
            if ( !blankStr($myimg_inference) ) {
                $h->{inference} = $myimg_inference;
            }

            #       if ( !blankStr($myimg_is_pseudogene) ) {
            #       $h->{ pseudo } .= "$myimg_is_pseudogene\n";
            #       }
            if ( !blankStr($myimg_notes) ) {
                $h->{note} .= "$myimg_notes\n";
            }
        }

        my $enzymes = "";
        if (    $myImgOverride
             && $has_myimg_annot
             && !blankStr($myimg_ec_number) )
        {

            # use annotated EC numbers instead
            $myimg_ec_number =~ s/;/ /g;
            $enzymes = $myimg_ec_number;
        } else {

            # get from gene_ko_enzymes table
            $enzymes = $geneEnzymes{$gene_oid};
        }

        printFeature( $wfh, "gene", $h );
        next if $is_pseudogene eq "Yes";
        if ( $locus_type eq "tRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "tRNA", $h );
        } elsif ( $locus_type eq "rRNA" ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "rRNA", $h );
        } elsif ( $locus_type =~ /RNA/ ) {
            $h->{product} = $gene_display_name;
            printFeature( $wfh, "misc_RNA", $h );
        } elsif ( $locus_type eq "CDS" ) {
            $h->{product}     = $gene_display_name;
            $h->{protein_id}  = $protein_seq_accid;
            $h->{translation} = $aa_residue;
            $h->{enzymes}     = $enzymes;
            printFeature( $wfh, "CDS", $h );
        }
    }
    $cur->finish();

    ## Repeats
    my $sql = getScaffoldRepeatsSql();
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $start_coord, $end_coord, $type ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        my $coords = "$start_coord..$end_coord";
        my $h = {
                  _coords    => $coords,
                  rpt_family => "$type",
        };
        printFeature( $wfh, "repeat_region", $h );
    }
    $cur->finish();
}

sub writeScaffold2GenBankFile_act_footer {
    my ( $dbh, $wfh, $taxon_oid, $scaffold_order_aref, $total_basepair ) = @_;

    ## Get the sequence
    print "Process scaffold DNA sequence ...<br/>\n";

    my $inFile = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq    = readLinearFasta_act( $inFile, $scaffold_order_aref );
    my $len    = length($seq);
    my ( $a_count, $c_count, $g_count, $t_count ) = getAcgtCounts($seq);

    if ( $len != $total_basepair ) {
        webLog(   "$0: printScaffoldSeqeuence: "
                . "bad scf_seq_length=$total_basepair len=$len\n" );
    }

    my $sp = " " x 4;
    print $wfh "BASE COUNT";
    print $wfh "$sp$a_count a";
    print $wfh "$sp$c_count c";
    print $wfh "$sp$g_count g";
    print $wfh "$sp$t_count t";
    print $wfh "\n";
    print $wfh "ORIGIN\n";

    for ( my $i = 0 ; $i < $len ; $i += 60 ) {
        printf $wfh "%10d", $i + 1;
        my $i2 = $i;
        for ( my $j = 0 ; $j < 60 && $i2 < $len ; $j += 10 ) {
            $i2 = $i + $j;
            my $seq2 = substr( $seq, $i2, 10 );
            print $wfh " $seq2";
        }
        print $wfh "\n";
    }

    print $wfh "//\n";
}

sub getScaffoldStatTaxonInfoSql {
    
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select scf.ext_accession, ss.seq_length, 
           scf.mol_type, scf.mol_topology,
           scf.scaffold_name, tx.taxon_oid, tx.ncbi_taxon_id,
           tx.taxon_display_name, tx.domain, tx.phylum,
           tx.ir_class, tx.ir_order, tx.family, tx.genus, tx.species,
           tx.strain
        from scaffold scf, taxon tx, scaffold_stats ss
        where scf.scaffold_oid = ?
        and scf.taxon = tx.taxon_oid
        and scf.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getGeneKoEnzymesSql {
    my ($rclause, $imgClause) = @_;
    
    my $sql = qq{
        select g.gene_oid, g.enzymes
        from gene_ko_enzymes g
        where g.scaffold = ?
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub getGeneImgFunctionsSql {
    my ($rclause, $imgClause) = @_;
    
#    my $sql = qq{
#        select g.gene_oid, it.term, g.f_order
#        from gene_img_functions g, dt_img_term_path dtp, img_term it
#        where g.scaffold = ?
#        and g.function = dtp.map_term
#        and dtp.term_oid = it.term_oid
#        $rclause
#        $imgClause
#        order by g.gene_oid, g.f_order
#    };
    my $sql = qq{
        select g.gene_oid, it.term, g.f_order
        from gene_img_functions g, img_term it
        where g.scaffold = ?
        and g.function = it.term_oid
        $rclause
        $imgClause
        order by g.gene_oid, g.f_order
    };
    
    return $sql;
}

sub getGeneMyimgFunctionsSql {
    my ($rclause, $imgClause) = @_;
    
    my $sql2 = qq{
        select gm.gene_oid, gm.product_name, gm.prot_desc, 
        gm.ec_number, gm.pubmed_id, gm.inference, gm.is_pseudogene, gm.notes, gm.obsolete_flag 
        from gene_myimg_functions gm, gene g
        where gm.gene_oid = g.gene_oid
        and gm.gene_oid = ?
        and gm.modified_by = ?
        $rclause
        $imgClause
    };
    
    return $sql2;
}


sub getScaffoldRepeatsSql {
    
    my $sql = qq{
        select sr.scaffold_oid, sr.start_coord, sr.end_coord, sr.type
    	from scaffold_repeats sr
    	where sr.scaffold_oid = ?
    	order by sr.start_coord
    };
    
    return $sql;
}


sub readLinearFasta_act {
    my ($inFile, $scaffold_order_aref) = @_;

    my $rfh = newReadFileHandle( $inFile, "readLinearFasta", 1 );
    if ( !$rfh ) {
        webLog("WARNING: readLinearFasta: cannot read '$inFile'\n");
        return "";
    }
    
    my %ext_hash;
    foreach my $ext (@$scaffold_order_aref) {
        $ext_hash{$ext} = 1;
    }

    my $seq;
    my $found = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if blankStr($s);
        if ( $s =~ /^>(.*)/ ) {
            if(exists $ext_hash{$1}) {
                $found = 1;
            } else {
                $found = 0;
            }
            next;
        }
        
        if($found) {
            $seq .= $s;
        }
    }

    close $rfh;
    return $seq;
}

############################################################################
# getComments - Attach whatever comments is necessary here.
############################################################################
sub getComments {
    my ( $dbh, $scaffold_oid ) = @_;

    # Check for bins
    my $rclause = WebUtil::urClause("bs.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('bs.taxon');
    my $sql = qq{
        select bm.method_name, b.display_name, b.confidence
    	from bin_scaffolds bs, bin b, bin_method bm
    	where bs.scaffold = ?
    	and bs.bin_oid = b.bin_oid
    	and b.bin_method = bm.bin_method_oid
        $rclause
        $imgClause
    	order by bm.method_name, b.display_name
    };
    my $s;
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $method_name, $bin_display_name, $confidence ) = $cur->fetchrow();
        last if !$method_name;
        $confidence = "undef" if $confidence eq "";
        $s .=
            "(bin=\"$bin_display_name\", "
          . "method=\"$method_name\", confidence=$confidence); ";
    }
    chop $s;
    chop $s;

    $s = "-" if $s eq "";
    return $s;
}

############################################################################
# printLine01 - Print first level type lines in Genbank format.
############################################################################
sub printLine01 {
    my ( $wfh, $tag, $val ) = @_;
    printTagVal( $wfh, 0, $tag, 12, $val );
}

############################################################################
# printTagVal - Print tag value with appropriate indentation
#   in Genbank format.
############################################################################
sub printTagVal {
    my ( $wfh, $tagIndent, $tag, $valIndent, $val ) = @_;
    my $sp = " " x $tagIndent;
    printf $wfh "%-*s", $valIndent, $sp . $tag;
    my @toks = split( / /, $val );
    my $cumLen = $valIndent;
    for my $t (@toks) {
        my $len = length($t);
        if ( $tag ne "LOCUS" &&
	     $cumLen + $len + 1 > $maxPageWidth ) {
            printf $wfh "\n";
            printf $wfh "%-*s", $valIndent, " ";
            $cumLen = $valIndent;
        }
        print $wfh "$t ";
        $cumLen += $len + 1;
    }
    print $wfh "\n";
}

############################################################################
# printFeature - Print tag value with appropriate indentation
#   for Genbank format.
#   Use hash for multiple values.
############################################################################
sub printFeature {
    my ( $wfh, $tag, $tagVals_ref, $geneFeatureStr ) = @_;
    my $sp     = " " x 5;
    my $spFeat = " " x $featureIndent;
    printf $wfh "%-21s", $sp . $tag;

    ## These tags dictate order
    # Amy: add 'prot_desc', 'inference' for IMG 2.3
    my @tags = (
                 "_coords",     "organism",
                 "mol_type",    "strain",
                 "locus_tag",   "gene",
                 "note",        "enzymes",
                 "EC_number",   "product",
                 "img_terms",   "function",
                 "prot_desc",   "inference",
                 "protein_id",  "db_xref",
                 "translation", "is_pseudogene",
                 "rpt_family",  "bound_moiety",
    );
    my %done;
    for my $tag2 (@tags) {
        my $val = $tagVals_ref->{$tag2};
        next if blankStr($val);
        next if $tag2 eq "db_xref" && $val eq "taxon:";
        if ( $tag2 eq "_coords" ) {
            print $wfh "$val\n";
        } elsif ( $tag2 eq "translation" ) {
            printCharWrapped( $wfh, $tag2, $val );
        } elsif ( $tag2 eq "enzymes" ) {
            my @ec_numbers = split( / /, $val );
            for my $ec_number (@ec_numbers) {
                next if $ec_number eq "";
                $ec_number =~ s/EC://;
                print $wfh $spFeat . "/EC_number=\"$ec_number\"\n";
            }
        } elsif ( $tag2 eq "img_terms" ) {
            my @terms = split( /\n/, $val );
            for my $term (@terms) {
                next if $term eq "";
                printWordWrapped( $wfh, "function", $term );
            }
        } elsif ( $tag2 eq "is_pseudogene" ) {
            print $wfh $spFeat . "/pseudo\n" if $val eq "Yes";
        } elsif ( $tag2 eq "note" ) {
            my @notes = split( /\n/, $val );
            for my $note (@notes) {
                next if $note eq "";
                printWordWrapped( $wfh, "note", $note );
            }
        } else {
            printWordWrapped( $wfh, $tag2, $val );
        }
	    $done{ $tag2 } = 1;
    }
    my @featureRecs = split( /\n/, $geneFeatureStr );
    for my $r( @featureRecs ) {
        my( $tag, $val ) = split( /\t/, $r );
	    printWordWrapped( $wfh, $tag, $val );
    }
}

############################################################################
# printScaffoldSequence  - Print the scaffold sequence at the bottom
#   of Genbank output.
############################################################################
sub printScaffoldSequence {
    my ( $wfh, $taxon_oid, $scf_ext_accession, $scf_seq_length ) = @_;

    my $inFile = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq    = WebUtil::readLinearFasta( $inFile, $scf_ext_accession );
    my $len    = length($seq);
    my ( $a_count, $c_count, $g_count, $t_count ) = getAcgtCounts($seq);

    if ( $len != $scf_seq_length ) {
        webLog(   "$0: printScaffoldSeqeuence: "
                . "bad scf_seq_length=$scf_seq_length len=$len\n" );
    }

    my $sp = " " x 4;
    print $wfh "BASE COUNT";
    print $wfh "$sp$a_count a";
    print $wfh "$sp$c_count c";
    print $wfh "$sp$g_count g";
    print $wfh "$sp$t_count t";
    print $wfh "\n";
    print $wfh "ORIGIN\n";

    for ( my $i = 0 ; $i < $len ; $i += 60 ) {
        printf $wfh "%10d", $i + 1;
        my $i2 = $i;
        for ( my $j = 0 ; $j < 60 && $i2 < $len ; $j += 10 ) {
            $i2 = $i + $j;
            my $seq2 = substr( $seq, $i2, 10 );
            print $wfh " $seq2";
        }
        print $wfh "\n";
    }
}

############################################################################
# printCharWrapped - Print with characters wrapped.
############################################################################
sub printCharWrapped {
    my ( $wfh, $tag, $val ) = @_;

    my $indent = 21;
    my $sp     = " " x $indent;
    my $x      = "$sp/$tag=\"";
    print $wfh "$x";
    my $len    = length($val);
    my $cumLen = length($x);
    for ( my $i = 0 ; $i < $len ; $i++ ) {
        if ( $cumLen + 1 > $maxPageWidth ) {
            print $wfh "\n";
            print $wfh $sp;
            $cumLen = $indent;
        }
        my $c = substr( $val, $i, 1 );
        print $wfh $c;
        $cumLen++;
    }
    print $wfh "\"\n";
}

############################################################################
# printWordWrapped - Print with word tokens wrapped.
############################################################################
sub printWordWrapped {
    my ( $wfh, $tag, $val ) = @_;

    my $indent = 21;
    my $sp     = " " x $indent;
    my $x      = "$sp/$tag=\"";
    print $wfh "$x";
    my $len    = length($val);
    my $cumLen = length($x);
    $val =~ s/"/'/g;
    $val =~ s/^\s+//;
    $val =~ s/\s+$//;
    $val =~ s/\s+/ /g;
    my @toks = split( / /, $val );
    my $s;

    for my $tok (@toks) {
        my $len = length($tok);
        if ( $cumLen + $len + 1 > $maxPageWidth ) {
            $s .= "\n";
            $s .= $sp;
            $cumLen = $indent;
        }
        $s .= "$tok ";
        $cumLen += $len + 1;
    }
    chop $s;
    print $wfh "$s\"\n" if !blankStr($s);
}

############################################################################
# getCoords - Get coordinate in proper form.
############################################################################
sub getCoords {
    my ( $start_coord, $end_coord, $strand ) = @_;
    if ( $strand eq "-" ) {
        return "complement($start_coord..$end_coord)";
    } else {
        return "$start_coord..$end_coord";
    }
}

############################################################################
# massageAltName - Strip out (MyIMG:<username>) from string.
############################################################################
sub massageAltName {
    my ($s) = @_;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/\s+/ /g;
    my @toks = split( / /, $s );
    my $s2;
    for my $t (@toks) {
        next if $t =~ /^\(MyIMG:/;
        $s2 .= "$t ";
    }
    chop $s2;
    return $s2;
}

1;

