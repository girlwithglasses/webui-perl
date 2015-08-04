############################################################################
# EmblFile.pm - Generate EMBL format files.
#     --es 04/14/2006
############################################################################
package EmblFile;
my $section = "EmblFile";
use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use Data::Dumper;
use WebUtil;
use WebConfig;

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
# printProcessEmbl - Print processing results for EMBL file.
############################################################################
sub printProcessEmbl {
    my ( $scaffold_oid, $myImgOverride, $imgTermOverride, $gene_oid_note, $misc_features ) = @_;

    if ( $scaffold_oid eq "" ) {
        webError("Please select a scaffold.");
    }
    print "<h1>Generate EMBL File</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $tmpFile     = "$scaffold_oid.$$.embl";
    my $tmpFilePath = "$cgi_tmp_dir/$tmpFile";
    wunlink($tmpFilePath);
    writeScaffold2EmblFile( $scaffold_oid, $tmpFilePath, $myImgOverride, $imgTermOverride, $gene_oid_note );
    printStatusLine( "Loaded.", 2 );

    print hiddenVar( "scaffold_oid", $scaffold_oid );
    print hiddenVar( "pid",          $$ );
    print hiddenVar( "type",         "embl" );

    my $name = "_section_TaxonDetail_viewArtemisFile";
    print submit(
        -name  => $name,
        -value => "View Results",
        -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_TaxonDetail_downloadArtemisFile";
    print submit(
        -name  => $name,
        -value => "Download File",
        -class => "medbutton"
    );

    print "<br/>\n";
    printHint("The downloaded file is viewable by $artemis_link.");

    print end_form();
}

############################################################################
# writeScaffold2EmblFile - Given scaffold_oid write an output file.
############################################################################
sub writeScaffold2EmblFile {
    my ( $scaffold_oid, $outFile, $myImgOverride, $imgTermOverride, $gene_oid_note, $notPrint ) = @_;

    if ( $verbose >= 1 ) {
        webLog("imgTermOverride='$imgTermOverride'\n");
    }
    $myImgOverride   = 1 if $myImgOverride   eq "on";
    $imgTermOverride = 1 if $imgTermOverride eq "on";

    my $dbh = dbLogin();
    checkScaffoldPerm( $dbh, $scaffold_oid );
    my $wfh = newAppendFileHandle( $outFile, "writeScaffold2EmblFile" );

    #my $cur = execSql( $dbh, "select sysdate from dual", $verbose );
    #my $sydate = $cur->fetchrow( );
    #$cur->finish( );
    my $sysdate = getSysDate();

    my $ext_accession = scaffoldOid2ExtAccession( $dbh, $scaffold_oid );
    print "<p>\n"                                                  if ( !$notPrint );
    print "Process scaffold $ext_accession information ...<br/>\n" if ( !$notPrint );
    ## We kludge chromosome for historical reasons since this value
    #  isn't always filled in.
    #  Assume chromosome_oid is same as scaffold_oid.
    my $rclause   = WebUtil::urClause('tx');
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
	and scf.scaffold_oid = ss.scaffold_oid
	and scf.taxon = tx.taxon_oid
	$rclause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my (
        $scf_ext_accession, $scf_seq_length, $mol_type,      $mol_topology,
        $scaffold_name,     $taxon_oid,      $ncbi_taxon_id, $taxon_display_name,
        $domain,            $phylum,         $ir_class,      $ir_order,
        $family,            $genus,          $species,       $strain
      )
      = $cur->fetchrow();
    $cur->finish();
    my $lineage = "$domain; $phylum; $ir_class; $ir_order; $family; $genus.";
    my $sp      = " " x 4;
    printLine01( $wfh, "ID", "$scf_ext_accession $sp $scf_seq_length bp " . "$sp DNA $mol_topology $sp" );
    printLine01( $wfh, "XX" );
    printLine01( $wfh, "DT", $sysdate );
    printLine01( $wfh, "XX" );
    printLine01( $wfh, "DE", $scaffold_name );
    printLine01( $wfh, "XX" );
    printLine01( $wfh, "OS", $taxon_display_name );
    printLine01( $wfh, "OC", $lineage );
    printLine01( $wfh, "XX" );

    print $wfh "FH   Key             Location/Qualifiers\n";
    print $wfh "FH\n";

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
    print "Process enzymes ...<br/>\n" if ( !$notPrint );
    my %geneEnzymes;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
    	select g.gene_oid, g.enzymes
    	from gene_ko_enzymes g
    	where g.scaffold = ?
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $enzyme ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneEnzymes{$gene_oid} .= "$enzyme ";
    }
    $cur->finish();

    ## IMG term override
    print "Process IMG terms ...<br/>\n" if ( !$notPrint );
    my %geneImgTerms;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #    my $sql = qq{
    #    	select g.gene_oid, it.term, g.f_order
    #    	from gene_img_functions g, dt_img_term_path dtp, img_term it
    #    	where g.scaffold = ?
    #    	and g.function = dtp.map_term
    #        and dtp.term_oid = it.term_oid
    #        $rclause
    #        $imgClause
    #    	order by g.gene_oid, g.f_order
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
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $term, $f_order ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneImgTerms{$gene_oid} .= "$term\n";
    }
    $cur->finish();

    ## Iterate through genes
    print "Process genes ...<br/>\n" if ( !$notPrint );
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
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
            $gene_oid,  $gene_display_name, $start_coord, $end_coord,         $strand, $locus_type,
            $locus_tag, $gene_symbol,       $aa_residue,  $protein_seq_accid, $is_pseudogene
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        if ( $start_coord > $scf_seq_length || $end_coord > $scf_seq_length ) {
            webLog( "$0: bad coordinate $start_coord..$end_coord for " . "scf_seq_length=$scf_seq_length\n" );
            next;
        }
        if ($imgTermOverride) {
            my $termsStr = $geneImgTerms{$gene_oid};
            my @terms    = split( /\n/, $termsStr );
            my $termStr2 = join( ' / ', @terms );
            $gene_display_name = $termStr2;
        }
        my $img_terms = $geneImgTerms{$gene_oid};
        my $coords    = getCoords( $start_coord, $end_coord, $strand );
        my $h         = {
            _coords       => $coords,
            gene          => $gene_symbol,
            locus_tag     => $locus_tag,
            is_pseudogene => $is_pseudogene,
            img_terms     => $img_terms,
        };
        if ($gene_oid_note) {
            $h->{note} .= "IMG gene_oid=$gene_oid\n";
        }
        my $enzymes = $geneEnzymes{$gene_oid};
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

    printLine01( $wfh, "XX" );

    ## Get the sequence
    print "Process scaffold DNA sequence ...<br/>\n" if ( !$notPrint );

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

    my $sql = qq{
	select scf.taxon, scf.ext_accession
	from scaffold scf
	where scf.scaffold_oid = ?
	$rclause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ( $taxon_oid, $scf_ext_accession ) = $cur->fetchrow();
    $cur->finish();
    printScaffoldSequence( $wfh, $taxon_oid, $scf_ext_accession, $scf_seq_length );
    print $wfh "//\n";
    close $wfh;

    #$dbh->disconnect();
    print "</p>\n" if ( !$notPrint );
}

############################################################################
# printLine01 - Print first level type lines in EMBL format.
############################################################################
sub printLine01 {
    my ( $wfh, $tag, $val ) = @_;

    my $sp = " " x 3;
    my $x  = "$tag$sp";
    print $wfh $x;
    if ( blankStr($val) ) {
        print $wfh "\n";
        return;
    }
    my @toks = split( / /, $val );
    my $cumLen = length($x);
    for my $t (@toks) {
        my $len = length($t);
        if ( $cumLen + $len + 1 > $maxPageWidth ) {
            print $wfh "\n";
            print $wfh "$x";
            $cumLen = length($x);
        }
        print $wfh "$t ";
        $cumLen += $len + 1;
    }
    print $wfh "\n";
}

############################################################################
# printFeature - Print tag value with appropriate indentation
#   Use hash for multiple values in EMBL format.
############################################################################
sub printFeature {
    my ( $wfh, $tag, $tagVals_ref ) = @_;

    my $sp     = " " x 19;
    my $spFeat = "FT" . $sp;
    printf $wfh "%-21s", "FT   $tag";

    ## These tags dictate order
    my @tags = (
        "_coords",    "organism", "mol_type",    "strain",  "locus_tag", "gene",
        "note",       "enzymes",  "EC_number",   "product", "img_terms", "function",
        "protein_id", "db_xref",  "translation", "is_pseudogene"
    );
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
    }
}

############################################################################
# printScaffoldSequence  - Print the scaffold sequence.
############################################################################
sub printScaffoldSequence {
    my ( $wfh, $taxon_oid, $scf_ext_accession, $scf_seq_length ) = @_;

    my $inFile = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq    = WebUtil::readLinearFasta( $inFile, $scf_ext_accession );
    my $len    = length($seq);
    my ( $a_count, $c_count, $g_count, $t_count ) = getAcgtCounts($seq);

    if ( $len != $scf_seq_length ) {
        webLog( "$0: printScaffoldSeqeuence: " . "bad scf_seq_length=$scf_seq_length len=$len\n" );
    }
    my $gatcCount   = $a_count + $c_count + $g_count + $t_count;
    my $other_count = $len - $gatcCount;

    print $wfh "SQ   ";
    print $wfh "Sequence $len BP; ";
    print $wfh "$a_count A; ";
    print $wfh "$c_count C; ";
    print $wfh "$g_count G; ";
    print $wfh "$t_count T; ";
    print $wfh "$other_count other;";
    print $wfh "\n";

    for ( my $i = 0 ; $i < $len ; $i += 60 ) {
        print $wfh " " x 4;
        my $i2 = $i;
        for ( my $j = 0 ; $j < 60 ; $j += 10 ) {
            $i2 = $i + $j;
            if ( $i2 >= $len ) {
                printf $wfh " %-10s", "";
            } else {
                my $seq2 = substr( $seq, $i2, 10 );
                printf $wfh " %-10s", $seq2;
            }
        }
        printf $wfh "%10d", $i + 1;
        print $wfh "\n";
    }
}

############################################################################
# printCharWrapped - Print with characters wrapped.
############################################################################
sub printCharWrapped {
    my ( $wfh, $tag, $val ) = @_;

    my $indent = 19;
    my $sp     = " " x $indent;
    my $x      = "FT$sp/$tag=\"";
    print $wfh "$x";
    my $len    = length($val);
    my $cumLen = length($x);
    for ( my $i = 0 ; $i < $len ; $i++ ) {
        if ( $cumLen + 1 > $maxPageWidth ) {
            print $wfh "\n";
            print $wfh "FT$sp";
            $cumLen = $indent + 2;
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

    my $indent = 19;
    my $sp     = " " x $indent;
    my $x      = "FT$sp/$tag=\"";
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
            $s .= "FT$sp";
            $cumLen = $indent + 2;
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

