############################################################################
# GeneAnnotPager - Gene annotation pager.  Pager indexes and read's
#  Indexed file in pages for comparative gene annotation file which
#  is precomputed.
#      --es 09/27/2005
#
# $Id: GeneAnnotPager.pm 30841 2014-05-08 04:32:57Z klchu $
############################################################################
package GeneAnnotPager;
my $section = "GeneAnnotPager";
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

    if ( $page eq "viewGeneAnnotations" ) {
        printFilePager();
    } else {
        printFilterPager();
    }
}

############################################################################
# printFilePager - Show annotation pager.
############################################################################
sub printFilePager {
    my $taxon_oid  = param("taxon_oid");
    my $viewPageNo = param("viewPageNo");

    $taxon_oid = sanitizeInt($taxon_oid);

    if ( $viewPageNo eq "" ) {
        $viewPageNo = 1;
    }

    print "<h1>Compare Gene Annotations</h1>\n";
    my $dbh = dbLogin();
    my $taxonName = taxonOid2Name( $dbh, $taxon_oid );
    print "<p>\n";
    print "View annotations for ";
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
        var url = "main.cgi?section=GeneAnnotPager&page=viewGeneAnnotations&taxon_oid=$taxon_oid&filter=";
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
        &nbsp;&nbsp;* Without product name, but with some protein family annotation evidence.
        <br> 
        &nbsp;&nbsp;* With product name, but without any protein family annotation evidence.     
         
        <br><br>
        Current filter selection: $filtername.
        </p>             
        };

    print end_form();

    #}

    my $sid       = getSessionId();
    my $dataFile  = "$cgi_tmp_dir/$taxon_oid.$sid.annot.xls";
    my $indexFile = "$cgi_tmp_dir/index.$taxon_oid.annot.$sid.txt";
    my $displayFileName = "$taxon_oid.annot.xls";    # display file name
    my $count           = 0;
    if ( $forceNewFile || !-e ($dataFile) || !-e ($indexFile) ) {
        webLog("Generate annotation data file\n");
        $count = genAnnotFile( $dbh, $taxon_oid, $dataFile );
        webLog("Index data file\n");
        indexAnnotFile( $dataFile, $indexFile );
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
    print "<th class='img'>Cluster Annotation</th>\n";
    print "<th class='img'>Gene Annotation</th>\n";
    print "<th class='img'>E-value</th>\n";
    my $rfh = newReadFileHandle( $dataFile, "printFilePager" );
    my $pos = $page2Offset{$viewPageNo};
    seek( $rfh, $pos, 0 );
    my %uniqueGenes;
    my $geneCount = 0;
    my $lineCount = 0;

# TODO test bug code
# http://localhost/~ken/cgi-bin/web25.htd/main.cgi?section=GeneAnnotPager&page=viewGeneAnnotations&taxon_oid=640427101&filter=noproduct

    while ( my $s = $rfh->getline() ) {
        my ( $gene_oid, $locus, $source, $cluster_annotation, $gene_annotation,
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
        } elsif ( $source =~ /^COG/ ) {
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
        print "<td class='img'>" . escHtml($cluster_annotation) . "</td>\n";
        print "<td class='img'>" . escHtml($gene_annotation) . "</td>\n";
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
    my $contact_oid = WebUtil::getContactOid();
    my $url =
        "$main_cgi?section=TaxonDetail"
      . "&downloadTaxonAnnotFile=1&taxon_oid=$taxon_oid&noHeader=1";
    my $fileName_link = alink( $url, $fileName, '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link downloadTaxonAnnotFile']);" );
    print "Pages for download file $fileName_link: ";
    my $nPages     = @$pages_ref;
    my $lastPageNo = $pages_ref->[ $nPages - 1 ];
    for my $pageNo (@$pages_ref) {
        my $url = "$section_cgi&page=viewGeneAnnotations";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&viewPageNo=$pageNo" . $filterStr;
        print nbsp(1);
        print "[" if $pageNo eq $viewPageNo;
        print alink( $url, $pageNo );
        print "]" if $pageNo eq $viewPageNo;
    }
    if ( $viewPageNo < $lastPageNo ) {
        my $pageNo2 = $viewPageNo + 1;
        my $url     = "$section_cgi&page=viewGeneAnnotations";
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
# indexAnnotFile - Index annotation file.
############################################################################
sub indexAnnotFile {
    my ( $inFile, $outFile ) = @_;

    my $batchSize = 500;

    my $rfh = newReadFileHandle( $inFile,   "indexAnnotFile" );
    my $wfh = newWriteFileHandle( $outFile, "indexAnnotFile" );
    print $wfh "# Index file for compare annotations pager\n";
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
        my ( $gene_oid, $locus, $source, $annotation ) = split( /\t/, $s );
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
# genAnnotFile - Generate annotation file.
############################################################################
sub genAnnotFile {
    my ( $dbh, $inTaxonOid, $outFile ) = @_;

    my $wfh = newWriteFileHandle( $outFile, "genAnnotFile" );
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

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, g.locus_type, g.locus_tag
      from gene g
      where g.taxon = ?
      and g.locus_type = ?
      $sqlClause
      $rclause
      $imgClause
      order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'CDS' );
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
    my @binds = ( $taxon_oid );
    populateHash( $dbh, $sql, \%geneOid2Name, @binds );

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
    my @binds = ( $taxon_oid );
    populateHash( $dbh, $sql, \%geneOid2NtLen, @binds );

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
    my @binds = ( $taxon_oid );
    populateHash( $dbh, $sql, \%geneOid2AaLen, @binds );

    my %geneOid2Cog;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, c.cog_id, c.cog_name, gcg.evalue
      from gene g, gene_cog_groups gcg, cog c
      where g.taxon = ?
      and g.gene_oid = gcg.gene_oid
      and gcg.cog = c.cog_id
      and g.obsolete_flag = ?
      and g.locus_type = ?
      $rclause
      $imgClause
      order by g.gene_oid, c.cog_id
   };
    my @binds = ( $taxon_oid, 'No', 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Cog, @binds );

    my %geneOid2Pfam;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, pf.ext_accession, pf.name, gpf.evalue
      from gene g, gene_pfam_families gpf, pfam_family pf
      where g.taxon = ?
      and g.gene_oid = gpf.gene_oid
      and gpf.pfam_family = pf.ext_accession
      and g.obsolete_flag = ?
      and g.locus_type = ?
      $rclause
      $imgClause
      order by g.gene_oid, pf.ext_accession
   };
    my @binds = ( $taxon_oid, 'No', 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Pfam, @binds );

    my %geneOid2Enzyme;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, ez.ec_number, ez.enzyme_name
      from gene g, gene_ko_enzymes ge, enzyme ez
      where g.taxon = ?
      and g.gene_oid = ge.gene_oid
      and ge.enzymes = ez.ec_number
      and g.obsolete_flag = ?
      and g.locus_type = ?
      $rclause
      $imgClause
      order by g.gene_oid, ez.ec_number
   };
    my @binds = ( $taxon_oid, 'No', 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Enzyme, @binds );

    my %geneOid2Annot;
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
      and g.obsolete_flag = ?
      and g.locus_type = ?
      $rclause
      $imgClause
      $sclause
   };
    my @binds = ( $taxon_oid, 'No', 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Annot, @binds )
      if $show_myimg_login && $contact_oid > 0;

    my %geneOid2TigrFam;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $sql = qq{
      select distinct gtf.gene_oid, gtf.ext_accession, tf.expanded_name,
        gtf.evalue
      from gene g, gene_tigrfams gtf, tigrfam tf
      where g.obsolete_flag = ?
      and g.gene_oid = gtf.gene_oid
      and g.taxon = ?
      and g.locus_type = ?
      and gtf.ext_accession = tf.ext_accession
      $rclause
      $imgClause
   };
    my @binds = ( 'No', $taxon_oid, 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2TigrFam, @binds );

    my %geneOid2ImgTerm;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
#    my $sql = qq{
#      select distinct g.gene_oid, it.term_oid, it.term
#      from gene g, gene_img_functions gif, dt_img_term_path dtp, img_term it
#      where g.taxon = ?
#      and g.locus_type = ?
#      and g.gene_oid = gif.gene_oid
#      and gif.function = dtp.map_term
#      and it.term_oid = dtp.term_oid
#      $rclause
#      $imgClause
#   };
    my $sql = qq{
      select distinct g.gene_oid, it.term_oid, it.term
      from gene g, gene_img_functions gif, img_term it
      where g.taxon = ?
      and g.locus_type = ?
      and g.gene_oid = gif.gene_oid
      and gif.function = it.term_oid
      $rclause
      $imgClause
   };
    my @binds = ( $taxon_oid, 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2ImgTerm, @binds );

    # TODO swissprot
    my %geneOid2Swissprot;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, '', gs.product_name, ''
      from gene g, gene_swissprot_names gs
      where g.gene_oid = gs.gene_oid
      and g.obsolete_flag = ?
      and g.taxon = ?
      and g.locus_type = ?
      $rclause
      $imgClause
   };
    my @binds = ( 'No', $taxon_oid, 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Swissprot, @binds );

    # TODO ko terms
    my %geneOid2Ko;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select distinct g.gene_oid, kt.ko_id, kt.definition, gk.evalue
      from gene g, gene_ko_terms gk, ko_term kt
      where g.gene_oid = gk.gene_oid
      and gk.ko_terms = kt.ko_id
      and g.obsolete_flag = ?
      and g.taxon = ?
      and g.locus_type = ?
      $rclause
      $imgClause
   };
    my @binds = ( 'No', $taxon_oid, 'CDS' );
    populateHash( $dbh, $sql, \%geneOid2Ko, @binds );

    print $fh "gene_oid\t";
    print $fh "Locus Tag\t";
    print $fh "Source\t";
    print $fh "Cluster Annotation\t";
    print $fh "Gene Annotation\t";
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

        my $a_ref = $geneOid2ImgTerm{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            my $term_oid = sprintf( "%05d", $id );
            print $fh "ITERM:$term_oid\t";
            print $fh "\t";
            print $fh "$val\t";
            print $fh "\n";
        }

        my $a_ref = $geneOid2Annot{$gene_oid};
        for my $r2 (@$a_ref) {
            my ( $id, $val, undef ) = split( /\t/, $r2 );
            print $fh "$gene_oid\t";
            print $fh "$locus_tag\t";
            print $fh "MyIMG:$id\t";
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

1;

