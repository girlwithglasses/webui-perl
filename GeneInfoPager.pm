############################################################################
# GeneInfoPager - Gene information pager.  Pager indexes and reads
#  Indexed file in pages for comparative gene information file which
#  is precomputed.
#      --es 06/10/09
# $Id: GeneInfoPager.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package GeneInfoPager;
my $section = "GeneInfoPager";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use FuncUtil;

my $env              = getEnv();
my $main_cgi         = $env->{main_cgi};
my $section_cgi      = "$main_cgi?section=$section";
my $base_dir         = $env->{base_dir};
my $cgi_dir          = $env->{cgi_dir};
my $web_data_dir     = $env->{web_data_dir};
my $cgi_tmp_dir      = $env->{cgi_tmp_dir};
my $genes_dir        = $env->{genes_dir};
my $pfam_base_url    = $env->{pfam_base_url};
my $cog_base_url     = $env->{cog_base_url};
my $tigrfam_base_url = $env->{tigrfam_base_url};
my $enzyme_base_url  = $env->{enzyme_base_url};
my $show_myimg_login = $env->{show_myimg_login};
my $verbose          = $env->{verbose};

my $img_internal = $env->{img_internal};

my $forceNewFile = 1;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "viewGeneInformation" ) {
        timeout( 60 * 180 );    # timeout in 3 hrs
        printFilePager();
    } else {
        timeout( 60 * 60 );    # timeout in 1 hr (from main.pl)
        printFilterPager();
    }
}

############################################################################
# printFilePager - Show information pager.
############################################################################
sub printFilePager {
    my $taxon_oid  = param("taxon_oid");
    my $viewPageNo = param("viewPageNo");

    $taxon_oid = sanitizeInt($taxon_oid);

    if ( $viewPageNo eq "" ) {
        $viewPageNo = 1;
    }

    print "<h1>Download Gene Information</h1>\n";
    my $dbh = dbLogin();
    my $taxonName = taxonOid2Name( $dbh, $taxon_oid );
    print "<p>\n";
    print "View informations for ";
    print "<i>" . escHtml($taxonName) . "</i>.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    #if ($img_internal) {
    my $filter     = param("filter");
    my $filtername = "none";
    if ( $filter eq "noproduct" ) {
        $filtername = "No Product Name/With Evidence";
    } elsif ( $filter eq "product" ) {
        $filtername = "Product Name/No Evidence";
    }

    printMainForm();
    print qq{
        <script language='javascript' type='text/javascript'>

        function filter() {
        var e =  document.mainForm.filterSection
        if(e.value == 'label') {
            return;
        }
        var url = "main.cgi?section=GeneInfoPager&page=viewGeneInformation&taxon_oid=$taxon_oid&filter=";
        url +=  e.value;
        window.open( url, '_self' );
            }
        </script>
        };

    print qq{
        <p>
        Select filter * &nbsp;
        <select name='filterSection' onChange='filter()'>
        };

    if ( $filter eq "noproduct" ) {
        print qq{<option value="label">
                -- Select Filter --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>};
        print qq{<option value="all">None</option>};
        print qq{
            <option value="noproduct" selected>No Product Name/With Evidence &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>
        };
        print qq{<option value="product">Product Name/No Evidence</option> };
    } elsif ( $filter eq "product" ) {
        print qq{<option value="label">
                -- Select Filter --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>};
        print qq{<option value="all">None</option>};
        print qq{
            <option value="noproduct">No Product Name/With Evidence</option>};
        print qq{
            <option value="product" selected>Product Name/No Evidence &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option> };
    } elsif ( $filter eq "all" ) {
        print qq{<option value="label">
                -- Select Filter --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>};
        print qq{<option value="all" selected>None</option>};
        print qq{
            <option value="noproduct">No Product Name/With Evidence</option>};
        print qq{<option value="product">Product Name/No Evidence</option> };
    } else {
        print qq{<option value="label" selected>
                -- Select Filter --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>};
        print qq{<option value="all">None</option>};
        print qq{
            <option value="noproduct">No Product Name/With Evidence</option>
        };
        print qq{<option value="product">Product Name/No Evidence</option> };
    }

    print qq{
        </select>

        <br><br>
        &nbsp;&nbsp;* Without product name, but with some protein family information evidence.
        <br>
        &nbsp;&nbsp;* With product name, but without any protein family information evidence.

        <br><br>
        Current filter selection: $filtername.
        </p>
        };

    print end_form();

    #}

    my $sid       = getSessionId();
    my $dataFile  = "$cgi_tmp_dir/$taxon_oid.$sid.info.xls";
    my $indexFile = "$cgi_tmp_dir/index.$taxon_oid.info.$sid.txt";
    my $displayFileName = "$taxon_oid.info.xls";    # display file name
    my $count           = 0;
    if ( $forceNewFile || !-e ($dataFile) || !-e ($indexFile) ) {
        webLog("Generate information data file\n");
        $count = genInfoFile( $dbh, $taxon_oid, $dataFile );
        webLog("Index data file\n");
        indexInfoFile( $dataFile, $indexFile );
    }
    #$dbh->disconnect();
    my $dataFile;
    my $batchSize = 0;
    my @pages;
    my %page2Offset;
    my $last_page;
    my $rfh = newReadFileHandle( $indexFile, "printFilePager" );

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+/ /g;
        my ( $tag, $val, @opts ) = split( / /, $s );
        if ( $tag eq ".dataFile" ) {
            $dataFile = $val;
        } elsif ( $tag eq ".batchSize" ) {
            $batchSize = $val;
        } elsif ( $tag eq ".page" ) {
            my ( $tag, $pageNo, $offset ) = split( / /, $s );
            push( @pages, $pageNo );
            $page2Offset{$pageNo} = $offset;
            $last_page = $pageNo;
        }
    }
    close $rfh;
    webLog "pager: dataFile='$dataFile' batchSize=$batchSize "
      . "viewPageNo='$viewPageNo'\n"
      if $verbose >= 1;

    printFooter( $taxon_oid, \@pages, $viewPageNo, $displayFileName );

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Locus Tag</th>\n";
    print "<th class='img'>Source</th>\n";
    print "<th class='img'>Cluster Information</th>\n";
    print "<th class='img'>Gene Information</th>\n";
    print "<th class='img'>E-value</th>\n";
    my $rfh = newReadFileHandle( $dataFile, "printFilePager" );
    my $pos = $page2Offset{$viewPageNo};
    seek( $rfh, $pos, 0 );
    my %uniqueGenes;
    my $geneCount = 0;
    my $lineCount = 0;

# TODO test bug code
# http://localhost/~ken/cgi-bin/web25.htd/main.cgi?section=GeneInfoPager&page=viewGeneInformation&taxon_oid=640427101&filter=noproduct

    while ( my $s = $rfh->getline() ) {
        my ( $gene_oid, $locus, $source, $cluster_information, $gene_information,
            $evalue )
          = split( /\t/, $s );

        next if $gene_oid =~ /^gene_oid/;
        $lineCount++;
        if ( $geneCount % 2 == 0 ) {
            print "<tr class='img'>\n";
        } else {
            print "<tr class='highlight'>\n"
              if $gene_oid ne "";
        }
        next if $gene_oid eq "" && $lineCount == 1;

        # create a blank row with 6 columns
        if ( $gene_oid eq "" ) {
            for ( my $i = 0 ; $i < 6 ; $i++ ) {
                print "<td class='img'>" . nbsp(1) . "</td>\n"
                  if $lineCount > 0;
            }
            $geneCount++;
            print "</tr>\n";
            next;
        }

        $uniqueGenes{$gene_oid} = $gene_oid;
        my @keys = keys(%uniqueGenes);
        last if scalar(@keys) > $batchSize && $viewPageNo ne $last_page;
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img'>" . escHtml($locus) . "</td>\n";
        if ( $source =~ /^pfam/ ) {
            my $id = $source;
            $id =~ s/pfam/PF/;
            my $url = "$pfam_base_url$id";
            print "<td class='img'>" . alink( $url, $source ) . "</td>\n";
        } elsif ( $source =~ /^COG$/ ) {
            my $id  = $source;
            my $url = "$cog_base_url$id";
            print "<td class='img'>" . alink( $url, $source ) . "</td>\n";
        } elsif ( $source =~ /^TIGR/ ) {
            my $id  = $source;
            my $url = "$tigrfam_base_url$id";
            print "<td class='img'>" . alink( $url, $source ) . "</td>\n";
        } elsif ( $source =~ /^EC:/ ) {
            my $id = $source;
            $id =~ tr/A-Z/a-z/;
            my $url = "$enzyme_base_url$id";
            print "<td class='img'>" . alink( $url, $source ) . "</td>\n";
        } elsif ( $source =~ /^ITERM:/ ) {
            my $id = $source;
            $id =~ tr/A-Z/a-z/;
            my $term_oid = $source;
            $term_oid =~ s/^ITERM://;
            $term_oid = FuncUtil::termOidPadded($term_oid);
            my $url =
                "$main_cgi?section=ImgTermBrowser"
              . "&page=imgTermDetail&term_oid=$term_oid";
            print "<td class='img'>ITERM:"
              . alink( $url, $term_oid )
              . "</td>\n";
        } else {
            print "<td class='img'>" . escHtml($source) . "</td>\n";
        }
        print "<td class='img'>" . escHtml($cluster_information) . "</td>\n";
        print "<td class='img'>" . escHtml($gene_information) . "</td>\n";
        print "<td class='img'>" . escHtml($evalue) . "</td>\n";
        print "</tr>\n";
    }
    close $rfh;
    print "</table>\n";

    if ( scalar(@pages) > 1 ) {
        printFooter( $taxon_oid, \@pages, $viewPageNo, $displayFileName );
    }
    printStatusLine( "$count Loaded.", 2 );
}

############################################################################
# printFooter - Print footer with page numbers.
############################################################################
sub printFooter {
    my ( $taxon_oid, $pages_ref, $viewPageNo, $fileName ) = @_;

    my $filter    = param("filter");
    my $filterStr = "";
    if ( $filter eq "noproduct" ) {
        $filterStr = "&filter=noproduct";
    } elsif ( $filter eq "product" ) {
        $filterStr = "&filter=product";
    }

    print "<p>\n";
    my $url =
        "$main_cgi?section=TaxonDetail"
      . "&downloadTaxonInfoFile=1&taxon_oid=$taxon_oid&noHeader=1";
      my $contact_oid = WebUtil::getContactOid();
    my $fileName_link = alink( $url, $fileName, '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link downloadTaxonInfoFile']);" );
    print "Pages for download file $fileName_link: ";
    my $nPages     = @$pages_ref;
    my $lastPageNo = $pages_ref->[ $nPages - 1 ];
    for my $pageNo (@$pages_ref) {
        my $url = "$section_cgi&page=viewGeneInformation";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&viewPageNo=$pageNo" . $filterStr;
        print nbsp(1);
        print "[" if $pageNo eq $viewPageNo;
        print alink( $url, $pageNo );
        print "]" if $pageNo eq $viewPageNo;
    }
    if ( $viewPageNo < $lastPageNo ) {
        my $pageNo2 = $viewPageNo + 1;
        my $url     = "$section_cgi&page=viewGeneInformation";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&viewPageNo=$pageNo2" . $filterStr;
        print nbsp(1);
        print "[";
        print alink( $url, "Next" );
        print "]";
    }
    print "</p>\n";
}

############################################################################
# indexInfoFile - Index information file.
############################################################################
sub indexInfoFile {
    my ( $inFile, $outFile ) = @_;

    my $batchSize = 200;

    my $rfh = newReadFileHandle( $inFile,   "indexInfoFile" );
    my $wfh = newWriteFileHandle( $outFile, "indexInfoFile" );
    print $wfh "# Index file for compare informations pager\n";
    print $wfh ".dataFile $inFile\n";
    print $wfh ".batchSize $batchSize\n";

    ## Skip header
    my $s = $rfh->getline();

    #my $s = $rfh->getline();
    # I commented out the 2nd getline - there is only one header line - ken

    my $geneCount     = 0;
    my $pageCount     = 0;
    my $pos           = tell $rfh;
    my $last_page_pos = $pos;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $gene_oid, $locus, $source, $information ) = split( /\t/, $s );
        if ( $gene_oid eq "" ) {
            $geneCount++;
        }
        if ( $geneCount >= $batchSize ) {
            $pageCount++;
            print $wfh ".page $pageCount $last_page_pos\n";
            $geneCount     = 0;
            $last_page_pos = $pos;
        }
        $pos = tell $rfh;
    }
    if ( $geneCount > 0 ) {
        $pageCount++;
        print $wfh ".page $pageCount $last_page_pos\n";
    }
    close $rfh;
    close $wfh;
}

############################################################################
# genInfoFile - Generate information file.
############################################################################
sub genInfoFile {
    my ( $dbh, $inTaxonOid, $outFile ) = @_;

    my $wfh = newWriteFileHandle( $outFile, "genInfoFile" );
    my $count = flushGenesToExcel( $wfh, $dbh, $inTaxonOid );
    close $wfh;

    return $count;
}

############################################################################
# flushGenesToExcel - Flush buffer genes to Excel.
############################################################################
sub flushGenesToExcel {
    my ( $fh, $dbh, $taxon_oid ) = @_;

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();

    my $filter    = param("filter");
    my $sqlClause = "";

    # other filter criteria at the print stage since its faster
    # there than in oracle
    my $prod_name = "g.gene_display_name";
    if ( $filter eq "noproduct" ) {
        $sqlClause = qq{
            and ( $prod_name is null
                 or lower($prod_name) like '%hypothetic%'
                 or lower($prod_name) like '%unknown%'
                 or lower($prod_name) like '%unnamed%' )
        };
    } elsif ( $filter eq "product" ) {
        $sqlClause = qq{
            and $prod_name is not null
            and lower($prod_name) not like '%hypothetic%'
            and lower($prod_name) not like '%unknown%'
            and lower($prod_name) not like '%unnamed%'
        };
    }

    printStartWorkingDiv( );

    print "Retrieving genes ...<br/>\n";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, g.locus_type, g.locus_tag
      from gene g
      where g.taxon = ?
      $sqlClause
      $rclause
      $imgClause
      order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @geneRecs;
    for ( ; ; ) {
        my ( $gene_oid, $locus_type, $locus_tag ) = $cur->fetchrow();
        last if !$gene_oid;
        my $r = "$gene_oid\t";
        $r .= "$locus_type\t";
        $r .= "$locus_tag\t";
        push( @geneRecs, $r );
    }
    $cur->finish();

    print "Retrieving locus type ...<br/>\n";
    my %geneOid2LocusType;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Locus_type', g.locus_type
      from gene g
      where g.taxon = ?
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2LocusType, $taxon_oid );

    print "Retrieving gene symbol ...<br/>\n";
    my %geneOid2Symbol;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Gene_symbol', g.gene_symbol
      from gene g
      where g.taxon = ?
      and g.gene_symbol is not null
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Symbol, $taxon_oid );

    print "Retrieving NCBI sequence accession ...<br/>\n";
    my %geneOid2Acc;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'NCBI_accession', g.protein_seq_accid
      from gene g
      where g.taxon = ?
      and g.protein_seq_accid is not null
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Acc, $taxon_oid );

    print "Retrieving product name ...<br/>\n";
    my %geneOid2Name;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Product_name', g.gene_display_name
      from gene g
      where g.taxon = ?
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2Name, $taxon_oid );

    print "Retrieving scaffold accession ...<br/>\n";
    my %geneOid2Scaffold;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Scaffold', scf.ext_accession
      from scaffold scf, gene g
      where g.taxon = ?
      and g.scaffold = scf.scaffold_oid
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Scaffold, $taxon_oid );

    print "Retrieving coordinates ...<br/>\n";
    my %geneOid2Coords;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Coordinates',
         g.start_coord || '..' || g.end_coord || '(' || g.strand || ')'
      from scaffold scf, gene g
      where g.taxon = ?
      and g.scaffold = scf.scaffold_oid
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Coords, $taxon_oid );

    print "Retrieving gene lengths ...<br/>\n";
    my %geneOid2NtLen;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'DNA_length', g.dna_seq_length
      from gene g
      where g.taxon = ?
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2NtLen, $taxon_oid );

    my %geneOid2AaLen;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Protein_length', g.aa_seq_length
      from gene g
      where g.taxon = ?
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2AaLen, $taxon_oid );

    print "Retrieving GC ...<br/>\n";
    my %geneOid2Gc;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'GC', g.gc_percent
      from gene g
      where g.taxon = ?
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Gc, $taxon_oid );

    print "Retrieving signal peptides ...<br/>\n";
    my %geneOid2Sp;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Signal_peptide', count(*)
      from gene g, gene_sig_peptides gsp
      where g.taxon = ?
      and g.gene_oid = gsp.gene_oid
      $rclause
      $imgClause
      group by g.gene_oid, 'Signal_peptide'
    };
    populateHashYesNo( $dbh, $sql, \%geneOid2Sp, $taxon_oid );

    print "Retrieving transmembrane proteins ...<br/>\n";
    my %geneOid2Tm;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Transmembrane', count(*)
      from gene g, gene_tmhmm_hits gth
      where g.taxon = ?
      and g.gene_oid = gth.gene_oid
      and gth.feature_type = 'TMhelix'
      $rclause
      $imgClause
      group by g.gene_oid, 'Transmembranec'
    };
    populateHashYesNo( $dbh, $sql, \%geneOid2Tm, $taxon_oid );

    print "Retrieving fused genes ...<br/>\n";
    my %geneOid2Fused;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, 'Fused_gene', count(*)
      from gene g, gene_fusion_components gfc
      where g.taxon = ?
      and g.gene_oid = gfc.gene_oid
      $rclause
      $imgClause
      group by g.gene_oid, 'Fused_gene'
    };
    populateHashYesNo( $dbh, $sql, \%geneOid2Fused, $taxon_oid );

    print "Retrieving COG category ...<br/>\n";
    my %geneOid2CogCat;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, 'COG_category',
         '[' || cf.function_code || '] ' || cf.definition
      from gene g, gene_cog_groups gcg, cog_functions cfs, cog_function cf
      where g.taxon = ?
      and g.gene_oid = gcg.gene_oid
      and gcg.cog = cfs.cog_id
      and cfs.functions = cf.function_code
      and g.obsolete_flag = 'No'
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2CogCat, $taxon_oid );

    print "Retrieving KEGG modules ...<br/>\n";
    my %geneOid2KoModule;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
       select distinct g.gene_oid, 'KEGG_module',
          km.module_id||': '||km.module_name val
       from kegg_module km,
          gene_ko_terms gk, gene g, ko_term kt, kegg_module_ko_terms kmk
       where km.module_id = kmk.module_id
       and kmk.ko_terms = gk.ko_terms
       and gk.gene_oid = g.gene_oid
       and kt.ko_id = gk.ko_terms
       and g.taxon = ?
       $rclause
       $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2KoModule, $taxon_oid );

    print "Retrieving IMG pathways ...<br/>\n";
    my %geneOid2ImgPway;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct g.gene_oid, 'IMG_pathway',
           pw.pathway_oid||': '||pw.pathway_name
        from gene_img_functions g,
           img_reaction_catalysts irc, img_pathway_reactions ipr,
	       img_pathway pw
        where g.function = irc.catalysts
        and irc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = pw.pathway_oid
    	and g.taxon = ?
        $rclause
        $imgClause
            union
        select distinct g.gene_oid, 'IMG_pathway',
           pw.pathway_oid||': '||pw.pathway_name
        from gene_img_functions g,
           img_reaction_t_components itc, img_pathway_reactions ipr,
    	   img_pathway pw
        where g.function = itc.term
        and itc.rxn_oid = ipr.rxn
    	and ipr.pathway_oid = pw.pathway_oid
    	and g.taxon = ?
        $rclause
        $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2ImgPway, $taxon_oid, $taxon_oid );

    print "Retrieving Metacyc pathways ...<br/>\n";
    my %geneOid2Metacyc;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct g.gene_oid, 'Metacyc',
	   bp.unique_id||': '||bp.common_name val
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        biocyc_reaction br, gene_biocyc_rxns gb, gene g
        where bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.unique_id = gb.biocyc_rxn
        and br.ec_number = gb.ec_number
        and gb.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Metacyc, $taxon_oid );

    print "Retrieving COG annotations ...<br/>\n";
    my %geneOid2Cog;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, c.cog_id, c.cog_name, gcg.evalue
      from gene g, gene_cog_groups gcg, cog c
      where g.taxon = ?
      and g.gene_oid = gcg.gene_oid
      and gcg.cog = c.cog_id
      and g.obsolete_flag = 'No'
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
    };
    populateHash( $dbh, $sql, \%geneOid2Cog, $taxon_oid );

    print "Retrieving Pfam annotations ...<br/>\n";
    my %geneOid2Pfam;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, pf.ext_accession, pf.name, gpf.evalue
      from gene g, gene_pfam_families gpf, pfam_family pf
      where g.taxon = ?
      and g.gene_oid = gpf.gene_oid
      and gpf.pfam_family = pf.ext_accession
      and g.obsolete_flag = 'No'
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2Pfam, $taxon_oid );

    print "Retrieving EC annotations ...<br/>\n";
    my %geneOid2Enzyme;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, ez.ec_number, ez.enzyme_name
      from gene g, gene_ko_enzymes ge, enzyme ez
      where g.taxon = ?
      and g.gene_oid = ge.gene_oid
      and ge.enzymes = ez.ec_number
      and g.obsolete_flag = 'No'
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2Enzyme, $taxon_oid );

    print "Retrieving Contact information ...<br/>\n";
    my %geneOid2Info;
    my $sclause = "and gmf.modified_by = $contact_oid";
    $sclause = "" if $super_user eq "Yes";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.gene_oid, ct.username, gmf.product_name
      from gene g, gene_myimg_functions gmf, contact ct
      where g.gene_oid = gmf.gene_oid
      and gmf.modified_by = ct.contact_oid
      and g.taxon = ?
      and g.obsolete_flag = 'No'
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
      $sclause
   };
    populateHash( $dbh, $sql, \%geneOid2Info, $taxon_oid )
      if $show_myimg_login && $contact_oid > 0;

    print "Retrieving TIGRfam annotations ...<br/>\n";
    my %geneOid2TigrFam;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct gtf.gene_oid, gtf.ext_accession, tf.expanded_name,
        gtf.evalue
      from gene g, gene_tigrfams gtf, tigrfam tf
      where g.obsolete_flag = 'No'
      and g.gene_oid = gtf.gene_oid
      and g.taxon = ?
      and g.locus_type = 'CDS'
      and gtf.ext_accession = tf.ext_accession
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2TigrFam, $taxon_oid );

    print "Retrieving IMG term annotations ...<br/>\n";
    my %geneOid2ImgTerm;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, it.term_oid, it.term
      from gene_img_functions g, img_term it
      where g.taxon = ?
      and g.function = it.term_oid
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2ImgTerm, $taxon_oid );

    print "Retrieving Swissprot annotations ...<br/>\n";
    my %geneOid2Swissprot;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, '', gs.product_name, ''
      from gene g, gene_swissprot_names gs
      where g.gene_oid = gs.gene_oid
      and g.obsolete_flag = 'No'
      and g.taxon = ?
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2Swissprot, $taxon_oid );

    print "Retrieving KO term annotations ...<br/>\n";
    my %geneOid2Ko;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select distinct g.gene_oid, kt.ko_id, kt.definition, gk.evalue
      from gene g, gene_ko_terms gk, ko_term kt
      where g.gene_oid = gk.gene_oid
      and gk.ko_terms = kt.ko_id
      and g.obsolete_flag = 'No'
      and g.taxon = ?
      and g.locus_type = 'CDS'
      $rclause
      $imgClause
   };
    populateHash( $dbh, $sql, \%geneOid2Ko, $taxon_oid );

    printEndWorkingDiv( );

    print $fh "gene_oid\t";
    print $fh "Locus Tag\t";
    print $fh "Source\t";
    print $fh "Cluster Information\t";
    print $fh "Gene Information\t";
    print $fh "E-value\n";

    my $count = 0;
    for my $r (@geneRecs) {
        my ( $gene_oid, $locus_type, $locus_tag ) = split( /\t/, $r );

        my $a_refCog  = $geneOid2Cog{$gene_oid};
        my $a_refTigr = $geneOid2TigrFam{$gene_oid};
        my $a_refPfam = $geneOid2Pfam{$gene_oid};

        # faster to filter here than in oracle
        #
        if ( $filter eq "noproduct" ) {
            if ( $a_refCog eq "" && $a_refTigr eq "" && $a_refPfam eq "" ) {
                next;
            }

        } elsif ( $filter eq "product" ) {
            if ( $a_refCog eq "" && $a_refTigr eq "" && $a_refPfam eq "" ) {

                # do nothing
            } else {
                next;
            }
        }

        $count++;

        my $a_ref = $geneOid2KoModule{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Metacyc{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2ImgPway{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2CogCat{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }
        for my $r2 (@$a_refCog) {
            my ( $id, $val, $evalue ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "$evalue\n";
        }

        for my $r2 (@$a_refPfam) {
            my ( $id, $val, $evalue ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "$evalue\n";
        }

        my $a_ref = $geneOid2Enzyme{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }

        for my $r2 (@$a_refTigr) {
            my ( $id, $val, $evalue ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "$evalue\n";
        }
        my $a_ref = $geneOid2Ko{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, $evalue ) = split( /\t/, $r2 );
            next if $val eq "";
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "$evalue\n";
        }
        my $a_ref = $geneOid2ImgTerm{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            my $term_oid = sprintf( "%05d", $id );
            print $fh "ITERM:$term_oid\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2LocusType{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Symbol{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Acc{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Name{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Info{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "MyIMG:$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Scaffold{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Coords{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2NtLen{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "${val}bp\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2AaLen{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            next if $val eq "";
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "${val}aa\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Gc{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Sp{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Tm{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }
        my $a_ref = $geneOid2Fused{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "$id\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Swissprot{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            next if $val eq "";
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "SwissProt\t";
            print $fh "$val\t";
            print $fh "\t";
            print $fh "\n";
        }

        print $fh "\t";
        print $fh "\t";
        print $fh "\t";
        print $fh "\t";
        print $fh "\t";
        print $fh "\n";
    }
    return $count;
}

############################################################################
# populateHash - Populate hash expecting these 3 fields from sql.
#   1. gene_oid
#   2. id
#   3. value
############################################################################
sub populateHash {
    my ( $dbh, $sql, $h_ref, @binds ) = @_;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $id, $name, $evalue ) = $cur->fetchrow();
        $evalue = sprintf( "%.1e", $evalue );
        last if !$gene_oid;
        my $a_ref = $h_ref->{$gene_oid};
        if ( !defined($a_ref) ) {
            my @a;
            $a_ref = \@a;
            $h_ref->{$gene_oid} = $a_ref;
        }
        push( @$a_ref, "$id\t$name\t$evalue" );
    }
    $cur->finish();

}

############################################################################
# populateHashYesNo - Populate hash expecting these 3 fields from sql.
#   1. gene_oid
#   2. id
#   3. value 0 (No) > 0 (Yes)
############################################################################
sub populateHashYesNo {
    my ( $dbh, $sql, $h_ref, @binds ) = @_;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $id, $cnt, $evalue ) = $cur->fetchrow();
        $evalue = sprintf( "%.1e", $evalue );
        last if !$gene_oid;
        my $a_ref = $h_ref->{$gene_oid};
        if ( !defined($a_ref) ) {
            my @a;
            $a_ref = \@a;
            $h_ref->{$gene_oid} = $a_ref;
        }
	my $yn = "No";
	$yn = "Yes" if $cnt > 0;
        push( @$a_ref, "$id\t$yn\t$evalue" );
    }
    $cur->finish();

}

1;

