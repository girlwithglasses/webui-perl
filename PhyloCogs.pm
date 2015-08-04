############################################################################
# PhyloCogs - Handle Phylo COG's, single copy COG's used as
#   phlogenetic markers.  Used mainly for metagenomes to view
#   metagenomes against the major domains Bacteria, Archaea, Eukaryota.
#   The tree results are precomputed.
#    --es 12/04/2006
#
# $Id: PhyloCogs.pm 32375 2014-12-03 20:49:53Z jinghuahuang $
############################################################################
package PhyloCogs;
my $section = "PhyloCogs";
require Exporter;

use strict;
use CGI qw( :standard );
use DBI;
use InnerTable;
use WebConfig;
use WebUtil;
use DrawTree;
use DrawTreeNode;
use MetaDetail;
use MetaUtil;
use HtmlUtil;
use Data::Dumper;

my $env          = getEnv();
my $cgi_dir      = $env->{cgi_dir};
my $cgi_tmp_dir  = $env->{cgi_tmp_dir};
my $main_cgi     = $env->{main_cgi};
my $section_cgi  = "$main_cgi?section=$section";
my $verbose      = $env->{verbose};
my $tmp_dir      = $env->{tmp_dir};
my $tmp_url      = $env->{tmp_url};
my $mgtrees_dir  = $env->{mgtrees_dir};
my $ma_bin       = $env->{ma_bin};                 # multalin
my $seqret_bin   = $env->{seqret_bin};
my $raxml_bin    = $env->{raxml_bin};
my $in_file      = $env->{in_file};
my $mer_data_dir = $env->{mer_data_dir};

my $max_no_cog_genes = 1000;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;	# number of saved genomes
    $numTaxon = 0 if ( $numTaxon eq "" );
    my $ans = 1;		# do not use cache pages if $ans

    my $page = param("page");
    my $sid  = getContactOid();

    if ( $page eq "phyloCogs" ) {
        printPhyloCogs();
    } elsif ( $page eq "phyloCogTree" ) {
        printPhyloCogTree();
    } elsif ( $page eq "phyloCogTaxonsForm" ) {
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
        		HtmlUtil::cgiCacheInitialize( $section);
        		HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloCogsTaxonForm();
        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    } elsif ( paramMatch("phyloCogsForm") ne "" ) {
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
    	    if ( !$ans ) {
        		# start cached page - all genomes
        		HtmlUtil::cgiCacheInitialize( $section);
        		HtmlUtil::cgiCacheStart() or return;
    	    }
    	}
        printPhyloCogsForm();
        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    } elsif ( $page eq "metagCogGenes" ) {
        printMetagCogGenes();
    } elsif ( paramMatch("phyloCogGenesForm") ne "" ) {
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
        		HtmlUtil::cgiCacheInitialize( $section);
        		HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloCogGenesForm();
        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    } elsif ( paramMatch("phyloCogsJalview") ne "" ) {
        printPhyloCogsJalview();
    } elsif ( paramMatch("phyloCogsMultalin") ne "" ) {
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
        		HtmlUtil::cgiCacheInitialize( $section);
        		HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloCogsMultalin();
    	HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    } else {
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
        		HtmlUtil::cgiCacheInitialize( $section);
        		HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloCogsTaxonForm();
    	HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    }
}

############################################################################
# printPhyloCogs - Print list of COG's valid for this metagenome
#   used as phylo markers.
############################################################################
sub printPhyloCogs {
    my $taxon_oid = param("taxon_oid");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct dt.cog_id, dt.cog_name
	from dt_scogs dt, gene_cog_groups gcg, gene g
	where dt.cog_id = gcg.cog
	and gcg.gene_oid = g.gene_oid
        and g.taxon = ?
        $rclause
	$imgClause
	order by dt.cog_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @recs;
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        my $treeFile = "$mgtrees_dir/$taxon_oid/$cog_id.tree.txt";
        next if !( -e $treeFile );
        my $r = "$cog_id\t";
        $r .= "$cog_name";
        push( @recs, $r );
    }
    $cur->finish();
    my $nRecs = @recs;
    printStatusLine( "Loaded.", 2 );
    if ( $nRecs == 0 ) {
        print "<p>\n";
        print "No phylogenetic marker COG's found for this metagenome.<br/>\n";
        print "</p>\n";
        #$dbh->disconnect();
        return;
    }
    print "<h1>Phylo COGs</h1>\n";
    print "<p>\n";
    print "The precomputed processing is as follows:<br/>\n";
    print "<br/>\n";
    print "Use single copy COG's occurring in Bacteria and Archaea ";
    print "domains as phylogenetic markers.<br/>\n";
    print "These COG's must occur in at least 50 genomes.<br/>\n";
    print "Member genes must be aligned on 60%  ";
    print "of COG consensus sequence.<br/>\n";
    print "Member genes must be within 70% to 130% of the ";
    print "COG consensus sequence ";
    print "in total length.<br/>\n";
    print "Member genes must be at least 30% amino acid identity over ";
    print "the alignment length.<br/>\n";
    print "Add metagenome genes to these COG genes.<br/>\n";

    my $url = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi";
    $url .= "?cmd=Retrieve&db=PubMed&dopt=Books&list_uids=16343337";
    my $kalign_link = alink( $url, "kalign" );
    print "Perform multiple sequence alignment with $kalign_link ";
    print "on COG genes.<br/>\n";
    print "Generate a distance matrix, and use neighbor joining\n";
    print "to form the tree.<br/>\n";
    print "</p>\n";
    print "<p>\n";
    print "Click on COG ID to see the tree.<br/>\n";
    print "(This is currently the <b>el cheapo</b> text version ";
    print "pending a better viewer.<br/>\n";
    print "But at least the text allows ";
    print "for easy integration with HTML, so it's easy to have ";
    print "buttons and links.)<br/>\n";
    print "</p>\n";

    printMainForm();
    
    WebUtil::printFuncCartFooter() if $nRecs > 10;
    print "<p>\n";
    for my $r (@recs) {
        my ( $cog_id, $cog_name ) = split( /\t/, $r );
        print "<input type='checkbox' name='cog_id' value='$cog_id' />\n";
        print nbsp(1);
        my $url = "$section_cgi&page=phyloCogTree";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&cog_id=$cog_id";
        print alink( $url, $cog_id ).nbsp(1).escHtml($cog_name)."<br/>\n";
    }
    print "</p>\n";
    WebUtil::printFuncCartFooter();

    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printPhyloCogTree - Show tree from phylo COG hit.
############################################################################
sub printPhyloCogTree {
    my $taxon_oid = param("taxon_oid");
    my $cog_id    = param("cog_id");

    print "<h1>Phylogenetic Marker $cog_id Tree</h1>\n";
    print "<p>\n";
    print "The output was pregenerated by a <i>Phylip</i> tool\n";
    my $url = "http://bioweb.pasteur.fr/docs/man/doc/neighbor.1";
    my $neighbor_link = alink( $url, "Neighbor" );
    print "called $neighbor_link.<br/>\n";
    print "The taxon name associated with each COG member gene ";
    print "is shown.<br/>\n";
    print "</p>\n";
    printHint(   "- Mouse over hyperlink to see gene product name.<br/>\n"
               . "- Click on Gene ID to see details.<br/>\n"
               . "- Metagenome paralogs are shown in red.<br/>\n" );

    my $treeFile = "$mgtrees_dir/$taxon_oid/$cog_id.tree.txt";
    my $geneFile = "$mgtrees_dir/$taxon_oid/$cog_id.genes.tab.txt";

    my @lines;
    my %geneOid2TaxonName;
    my %geneOid2GeneName;
    my %geneOid2Highlight;
    loadGeneInfo( $geneFile, \%geneOid2TaxonName, \%geneOid2GeneName, \%geneOid2Highlight );
    loadMassagedLines( $treeFile, \%geneOid2TaxonName, \@lines );

    printMainForm();

    print "<p>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen();
    print "</p>\n";

    printGeneCartFooter();
    print "<font color='blue'>\n";
    print "<pre>\n";
    for my $s (@lines) {
        if ( $s =~ /\^/ ) {
            my ( $prefix, $gene_oid ) = split( /\^/, $s );
            print $prefix;
            my $taxonName = $geneOid2TaxonName{$gene_oid};
            my $geneName  = $geneOid2GeneName{$gene_oid};
            my $highlight = $geneOid2Highlight{$gene_oid};

            my $url = "$main_cgi?section=GeneDetail"
		    . "&page=geneDetail&gene_oid=$gene_oid";
            print "<input type='checkbox' name='gene_oid' value='$gene_oid' /> ";
            print "<a href='$url' title='$geneName'>$gene_oid</a> ";
            print "<font color='red'>" if $highlight;
            print "$taxonName";
            print " (*)"    if $highlight;
            print "</font>" if $highlight;
            print "\n";
        } else {
            print "$s\n";
        }
    }
    print "</pre>\n";
    print "</font>\n";
    printGeneCartFooter();
    print end_form();
}

############################################################################
# loadMassagedLines - Identify the gene_oid's  in the massaged output.
#   Mark with "^" at beginning of token.
############################################################################
sub loadMassagedLines_plain {
    my ( $inFile, $lines_ref ) = @_;
    my $rfh = newReadFileHandle( $inFile, "loadMassagedLines" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @$lines_ref, $s );
    }
    close $rfh;
}

sub loadMassagedLines {
    my ( $inFile, $geneOid2Name_ref, $lines_ref ) = @_;

    my $rfh = newReadFileHandle( $inFile, "loadMassagedLines" );
    my $inTree = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+$//;
        if ( $s =~ /Negative branch/ ) {
            $inTree = 1;
            push( @$lines_ref, $s );
        } elsif ( $s =~ /remember/ ) {
            $inTree = 0;
            push( @$lines_ref, $s );
        }
        ## Work backwards till not find integer, see if gene_oid.
        #  If so mark beginning with "^".
        elsif ( $inTree && $s =~ /[0-9]$/ ) {
            push( @$lines_ref, markGeneOid( $geneOid2Name_ref, $s ) );
        } else {
            push( @$lines_ref, $s );
        }
    }
    close $rfh;
}

############################################################################
# markGeneOid - Mark gene_oid with "^" at beginning of line.
############################################################################
sub markGeneOid {
    my ( $geneOid2Name_ref, $s ) = @_;

    my $len = length($s);
    my @chars;
    my $inInt    = 1;
    my $intCount = 0;
    for ( my $i = $len - 1 ; $i >= 0 ; $i-- ) {
        my $c = substr( $s, $i, 1 );
        if ( $c !~ /^[0-9]$/ && $inInt ) {
            $inInt = 0;

            # Valid IMG gene_oid
            #if( $intCount >= 6 ) {
            #    push( @chars, "^" );
            #}
            my @chars3 = reverse(@chars);
            my $gene_oid = join( '', @chars3 );
            if ( $geneOid2Name_ref->{$gene_oid} ne "" ) {
                push( @chars, "^" );
            }
        }
        if ($inInt) {
            $intCount++;
        }
        push( @chars, $c );
    }
    my @chars2 = reverse(@chars);
    my $s2 = join( '', @chars2 );
    return $s2;
}

############################################################################
# loadGeneInfo - Load gene information.
############################################################################
sub loadGeneInfo {
    my ( $inFile, $geneOid2TaxonName_ref, $geneOid2GeneName_ref, 
	 $geneOid2Highlight_ref ) = @_;

    my $rfh = newReadFileHandle( $inFile, "loadMassagedLines" );
    my $s = $rfh->getline();    # skip header
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $gene_oid, $gene_display_name, $taxon_oid, $domain, 
	     $taxon_display_name, $seq_status, $highlight )
	    = split( /\t/, $s );

        my $d = substr( $domain,     0, 1 );
        my $c = substr( $seq_status, 0, 1 );
        my $taxonName = "$taxon_display_name ($d)[$c]";
        $geneOid2TaxonName_ref->{$gene_oid} = $taxonName;
        $geneOid2GeneName_ref->{$gene_oid}  = $gene_display_name;
        $geneOid2Highlight_ref->{$gene_oid} = $highlight;
    }
    close $rfh;
}

############################################################################
# printPhyloCogsTaxonForm - Show taxons for phylo COG selection.
############################################################################
sub printPhyloCogsTaxonForm {
    print "<h1>Phylogenetic Marker COGs</h1>\n";
    my $dbh = dbLogin();

    my $txclause = "";
    require GenomeCart;
    my $oids = GenomeCart::getAllGenomeOids();
    my @taxon_oids = @$oids;
    my $nTaxons = scalar(@taxon_oids);

    if ( $nTaxons > 0 ) {
        my $taxonStr;
        if ( OracleUtil::useTempTable($nTaxons) ) {
            OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@taxon_oids );
            $taxonStr = "select id from gtt_num_id";
        } else {
            $taxonStr = join( ",", @taxon_oids );
        }
        $txclause = " and tx.taxon_oid in ($taxonStr) ";
    }

    my %taxon_in_file;
    if ($in_file) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql2 = qq{
            select tx.taxon_oid 
            from taxon tx 
            where tx.in_file = 'Yes'
            $txclause
            $rclause
            $imgClause
        };
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;
            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }
    my @file_taxons = keys %taxon_in_file;
    my $nFileTxs    = scalar @file_taxons;

    print "<p>\n";
    print "Please select metagenomes to be included in alignment\n";
    print "against phylogenetic marker COGs.";
    print "<br/>*Showing only genomes from genome cart." if ( $nTaxons > 0 );
    print "<br/>*Showing only genomes with assembled genes."
	if ( $nFileTxs > 0 );
    print "</p>\n";

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name
        from taxon tx
        where tx.genome_type = 'metagenome'
        $rclause
        $imgClause
        $txclause
        order by tx.taxon_display_name
    };

    printMainForm();
    my $cur = execSql( $dbh, $sql, $verbose );
    my $it = new InnerTable( 1, "Metagenomes$$", "Metagenomes", 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Genome ID",  "asc", "right" );
    $it->addColSpec( "Metagenome", "asc", "left", "", "", "wrap" );

    my $count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$taxon_oid;

        my $row = $sd . "<input type='checkbox' name='taxon_oid' value='$taxon_oid' />\t";
        $row .= $taxon_oid . $sd . $taxon_oid . "\t";

        my $url = "$main_cgi?section=TaxonDetail"
	        . "&page=taxonDetail&taxon_oid=$taxon_oid";
        if ( $taxon_in_file{$taxon_oid} ) {
            next if ( !MetaUtil::hasAssembled($taxon_oid) );
            $taxon_name .= " (MER-FS)";
            $taxon_name .= " (assembled)";
            $url = "$main_cgi?section=MetaDetail"
		 . "&page=metaDetail&taxon_oid=$taxon_oid";
        }
        $row .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";
        $it->addRow($row);
        $count++;
    }
    $cur->finish();
    #$dbh->disconnect();

    if ( $count > 10 ) {
        my $name = "_section_${section}_phyloCogsForm";
        print submit(
                      -name  => $name,
                      -value => "Go",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print "\n";
        WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);

    my $user_params = 0;    # comment out for time being
    if ($user_params) {
        print "<p>\n";
        print "<table class='img' border='1'>\n";

        print "<tr class='img'>\n";
        print "<th class='subhead'>Min. Percent Identity</th>\n";
        print "<td class='img'>\n";
        print popup_menu(
                          -name    => "minPercIdent",
                          -values  => [ 30, 40, 50, 60, 70, 80, 90 ],
                          -default => 30
        );
        print "</td>\n";
        print "</tr>\n";

        print "<tr class='img'>\n";
        print "<th class='subhead'>Max. E-value</th>\n";
        print "<td class='img'>\n";
        print popup_menu(
                          -name    => "maxEvalue",
                          -values  => [ "1e-2", "1e-5", "1e-10", "1e-50", "1e-100" ],
                          -default => "1e-2"
        );
        print "</td>\n";
        print "</tr>\n";

        print "<tr class='img'>\n";
        print "<th class='subhead'>Min. Percentage Alignment</th>\n";
        print "<td class='img'>\n";
        print popup_menu(
                          -name    => "minPercAlign",
                          -values  => [ 30, 40, 50, 60, 70, 80, 90, 100 ],
                          -default => 60
        );
        print "</td>\n";
        print "</tr>\n";

        print "<tr class='img'>\n";
        print "<th class='subhead'>";
        print "Max. Percent Sequence Length Difference</th>\n";
        print "<td class='img'>\n";
        print popup_menu(
                          -name    => "maxPercLenDiff",
                          -values  => [ 30, 40, 50, 60, 70, 80, 90, 100 ],
                          -default => 30
        );
        print "</td>\n";
        print "</tr>\n";

        print "</table>\n";
        print "</p>\n";
    }

    my $name = "_section_${section}_phyloCogsForm";
    print submit(
                  -name  => $name,
                  -value => "Go",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    print "\n";
    WebUtil::printButtonFooter();
    print end_form();
}

############################################################################
# printPhyloCogsForm - Show form for selecting phylo cogs.
############################################################################
sub printPhyloCogsForm {
    my @taxon_oids    = param("taxon_oid");
    my $nTaxons       = @taxon_oids;
    my $taxon_oid_str = join( ',', @taxon_oids );
    if ( blankStr($taxon_oid_str) ) {
        webError("Please select at least one metagenome.<br/>\n");
    }
    my $minPercIdent   = param("minPercIdent");
    my $minPercAlign   = param("minPercAlign");
    my $maxEvalue      = param("maxEvalue");
    my $maxPercLenDiff = param("maxPercLenDiff");
    my $bound1         = sprintf( "%.2f", 1 - ( $maxPercLenDiff / 100 ) );
    my $bound2         = sprintf( "%.2f", 1 + ( $maxPercLenDiff / 100 ) );

    print "<h1>Phylogenetic Marker COGs</h1>\n";
    print "<p>\n";
    print "Please select a phylogenetic marker COG relevant to $nTaxons ";
    print "selected metagenome(s).<br/>\n";
    print "Member protein coding genes from metagenomes and isolates ";
    print "for the selected COG will be used for multiple alignment.";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # get the single-copy cogs for metagenome in database:
    my %validCogs;
    my %foundCogs; # to eliminate empty rows
    my %cogProfiles;
    my %cog_seqlength;
    my $sql = qq{
        select dt.cog_id, dt.cog_name, dt.single_copy, c.seq_length
	from dt_scogs dt, cog c
        where dt.cog_id = c.cog_id
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_id, $cog_name, $single_copy, $seq_length )
	    = $cur->fetchrow();
        last if !$cog_id;
        $validCogs{$cog_id}     = 1;
        $cogProfiles{$cog_id}   = "$cog_name\t$single_copy";
        $cog_seqlength{$cog_id} = $seq_length;
    }
    $cur->finish();

    my %taxon2cog;
    my %taxon_in_file;
    my %taxonProfile;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql2 = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.in_file
        from taxon tx
        where tx.taxon_oid in ($taxon_oid_str) 
        $rclause
        $imgClause
    };
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ( $tx2, $txname2, $infile2 ) = $cur2->fetchrow();
        last if !$tx2;
        $taxonProfile{$tx2} = $txname2;
        if ( $in_file && $infile2 eq "Yes" ) {
            $taxon_in_file{$tx2} = 1;
        }
    }
    $cur2->finish();

    my $minNoGenes   = 1500;       # minimu no. of genes in genome
    my $minBasePairs = 1500000;    # minimum DNA size

    my @file_taxons = keys %taxon_in_file;
    if ( ( scalar @file_taxons ) > 0 ) {
        printHint( "For MER-FS genomes, the count displayed is the <u>total "
		 . "cog gene count</u> for the genome rather than the single "
		 . "copy cog gene count. Clicking on the count will search "
		 . "for the genes that pass the single-copy criteria. " 
		 . "This count will be <font color='blue'><=</font> "
		 . "the total count displayed.<br/>" 
                 . "Right-click on a table column to go to the genome " 
                 . "details page." );
        print "<p/>";

        timeout( 60 * 20 );        # timeout in 20 minutes
        printStartWorkingDiv("mer-fs");

        foreach my $txid (@file_taxons) {
            $txid = sanitizeInt($txid);

            # check "genome" criteria for "single copy cog":
            my $total_genes = MetaUtil::getGenomeStats
		( $txid, "", "Protein coding genes" );
            my $num_bases   = MetaUtil::getGenomeStats
		( $txid, "", "Number of bases" );
            if (    $num_bases < $minBasePairs
                 || $total_genes < $minNoGenes ) {
                $taxon2cog{$txid} = "";
                next;
            }

            my %cog2cnt;
            my %cog2genes;

            if (0) {    ### this is very slow and may timeout:
                my @type_list = ('assembled');
                for my $t2 (@type_list) {
                    my %h = MetaUtil::getTaxonFuncsGenes($txid, $t2, "cog");
                    if (scalar(keys %h) > 0) {
                        for my $cog (keys %h) {
                            next if ( !exists $cogProfiles{$cog} );

                            my @gene_list = split( /\t/, $h{$cog} );
                            for my $gene (@gene_list) {
                                next if ( !MetaDetail::passesSingleCopyCriteria
                                  ( $txid, $gene, $t2, $cog, 
                                    $cog_seqlength{$cog} ) );        
                                
                                if ( exists $cog2genes{$cog} ) {
                                    $cog2genes{$cog} .= "\t" . $gene;
                                } else {
                                    $cog2genes{$cog} = $gene;
                                }                            
                            }

                        }
                    }
                }

                print "<p>getting counts for cog: ";
                foreach my $cg ( keys %cog2genes ) {
                    my $genesstr = $cog2genes{$cg};
                    print "$cg, ";
                    my @genes = split( "\t", $genesstr );
                    $cog2cnt{$cg} = scalar @genes;
                }
                $taxon2cog{$txid} = \%cog2cnt;
            }    # end of "true" count

            # quick way to get all cogs for the genome (assembled):
            my $file = "$mer_data_dir/$txid/assembled/cog_count.txt";
            if ( !( -e $file ) ) {
                next;
            }
            print "<p>getting cog counts from file: $file ";
            my $fh = newReadFileHandle($file);
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $cog2, $cnt ) = split( /\t/, $line );
		next if !$validCogs{$cog2};
		$foundCogs{$cog2} = 1;
                $cog2cnt{$cog2} = $cnt;
            }
            $taxon2cog{$txid} = \%cog2cnt;
            close $fh;
        }

        printEndWorkingDiv("mer-fs");
    }

    foreach my $taxon (@taxon_oids) {
        my %cog2cnt;
        my $sql = qq{
            select sc.cog_id, count( distinct sg.gene_oid )
            from dt_scogs sc, dt_scog_genes sg
            where sc.cog_id = sg.cog_id
            and sg.taxon_oid = ?
            group by sc.cog_id
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon );
        for ( ; ; ) {
            my ( $cog_id, $geneCount ) = $cur->fetchrow();
            last if !$cog_id;
            next if !$validCogs{$cog_id};
	    $foundCogs{$cog_id} = 1;
            $cog2cnt{$cog_id} = $geneCount;
        }
        if ( !$taxon_in_file{$taxon} ) {    # do not overwrite
            $taxon2cog{$taxon} = \%cog2cnt;
        }
    }
    #$dbh->disconnect();

    printMainForm();
    my $it = new InnerTable( 1, "phyloCogs2$$", "phyloCogs2", 2 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "COG",             "asc", "left" );
    $it->addColSpec( "Name",            "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Single<br/>Copy", "asc", "left" );
    for my $taxon (@taxon_oids) {
        my $taxon_name = $taxonProfile{$taxon};
        my $link;
        if ( $taxon_in_file{$taxon} ) {
            #no longer we can play link in col header
            #my $url = "$main_cgi?section=MetaDetail" 
            #    . "&page=metaDetail&taxon_oid=$taxon";
            #my $abbr_name = WebUtil::abbrColName2( $taxon, $taxon_name, $url );
            my $abbr_name = WebUtil::abbrColName2( $taxon, $taxon_name );
            $abbr_name .= "<br/>(MER-FS)";
            $abbr_name .= "<br/>(assembled)";
            $link = $abbr_name;
        }
        else {
            #no longer we can play link in col header
            #my $url = "$main_cgi?section=TaxonDetail"
            #    . "&page=taxonDetail&taxon_oid=$taxon";
            #$link = alink( $url, $taxon_name, "_blank" );
            $link = $taxon_name;
        }
        $it->addColSpec( $link, "desc", "right", "", $taxon_name, "wrap" );
    }

    my $count = 0;
    my @cogs = sort( keys %foundCogs );
    foreach my $cog_id (@cogs) {
        my ( $cog_name, $single_copy ) = split( "\t", $cogProfiles{$cog_id} );
        my $r;
        $r .= $sd . "<input type='radio' name='cog_id' value='$cog_id' />\t";
        $r .= "$cog_id\t";
        $r .= "$cog_name\t";
        $r .= "$single_copy\t";

        my $totalCnt = 0;
        for my $taxon_oid (@taxon_oids) {
            $taxon_oid = sanitizeInt($taxon_oid);
            my $cog2cnt = $taxon2cog{$taxon_oid};
            my $cnt = 0;
            if ( $cog2cnt ne "" ) {
                $cnt = $cog2cnt->{$cog_id};
            }

            my $url = "$section_cgi&page=metagCogGenes"
		    . "&cog_id=$cog_id&taxon_oid=$taxon_oid";
	    my $approx = "";
            if ( $taxon_in_file{$taxon_oid} ) {
                # need criteria to get single copy cogs only :
                $url =
                    "$main_cgi?section=MetaDetail"
                  . "&page=cogGeneList"
                  . "&single_copy=yes"
                  . "&taxon_oid=$taxon_oid"
                  . "&cog_id=$cog_id&data_type=assembled";
		$approx = "<= ";
            }
            if ( $cnt eq "" || $cnt == 0 ) {
                $r .= $cnt . "\t";
            } else {
                $r .= $cnt . $sd . $approx.alink($url, $cnt, "_blank") . "\t";
            }
            $totalCnt += $cnt;
        }

        $it->addRow($r);
        $count++;
    }

    if ( $count > 10 ) {
        my $name = "_section_${section}_phyloCogGenesForm";
        print submit(
                      -name  => $name,
                      -value => "Go",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print reset(
                     -name  => "Reset",
                     -value => "Reset",
                     -class => "medbutton"
        );
    }
    $it->printOuterTable(1);

    print hiddenVar( "minPercIdent",   $minPercIdent );
    print hiddenVar( "minPercAlign",   $minPercAlign );
    print hiddenVar( "maxEvalue",      $maxEvalue );
    print hiddenVar( "maxPercLenDiff", $maxPercLenDiff );
    for my $taxon_oid (@taxon_oids) {
        print hiddenVar( "taxon_oid", $taxon_oid );
    }

    my $name = "_section_${section}_phyloCogGenesForm";
    print submit(
                  -name  => $name,
                  -value => "Go",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "medbutton" );
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printMetagCogGenes - Show COG genes for metagenomes.
############################################################################
sub printMetagCogGenes {
    my $cog_id        = param("cog_id");
    my @taxon_oids    = param("taxon_oid");
    my $taxon_oid_str = join( ',', @taxon_oids );

    webError ("Missing COG ID.") if (!$cog_id);
    webError ("Missing Taxon ID.") if (!scalar @taxon_oids);

    my $sql = qq{
        select distinct sg.gene_oid
    	from dt_scog_genes sg, dt_scogs sc
    	where sg.cog_id = ?
    	and sg.cog_id = sc.cog_id
    	and sg.taxon_oid in( $taxon_oid_str )
    	order by sg.gene_oid
    };

    my $taxonlink = 0;
    if (scalar @taxon_oids == 1) {
    	$taxonlink = 1;
    }
    HtmlUtil::printMetagGeneListSection
	( $sql, "Metagenome Genes for $cog_id", $taxonlink, $cog_id );
}

############################################################################
# printPhyloCogGenesForm - Show form for selecting phylo cogs.
############################################################################
sub printPhyloCogGenesForm {
    my @taxon_oids    = param("taxon_oid");
    my $nTaxons       = @taxon_oids;
    my $taxon_oid_str = join( ',', @taxon_oids );
    if ( blankStr($taxon_oid_str) ) {
        webError("Please select at least one metagenome.<br/>\n");
    }
    my $cog_id         = param("cog_id");
    my $minPercIdent   = param("minPercIdent");
    my $minPercAlign   = param("minPercAlign");
    my $maxEvalue      = param("maxEvalue");
    my $maxPercLenDiff = param("maxPercLenDiff");
    my $bound1         = sprintf( "%.2f", 1 - ( $maxPercLenDiff / 100 ) );
    my $bound2         = sprintf( "%.2f", 1 + ( $maxPercLenDiff / 100 ) );

    if ( $cog_id eq "" ) {
        webError("Please select one COG.");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh          = dbLogin();
    my $cog_base_url = $env->{cog_base_url};
    my $url          = $cog_base_url . $cog_id;

    my $sql = qq{
        select dt.cog_name, c.seq_length
        from dt_scogs dt, cog c
        where dt.cog_id = c.cog_id
        and c.cog_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ( $cog_name, $cog_seq_length ) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Phylogenetic Marker COG Genes - $cog_id</h1>\n";
    print "<p>";
    print alink( $url, $cog_id . ": " . escHtml($cog_name), "_blank" );
    print "</p>";

    #    my $murl = "http://www.ncbi.nlm.nih.gov/pubmed/2849754";
    #    my $mlink = alink($murl, "Multalin", "_blank");
    #    print "<p>\n";
    #    print "Member genes are shown by descending bit score.<br/>\n";
    #    print "$mlink is a multiple sequence alignment tool.<br/>\n";
    #    print "</p>\n";

    my @recs1;    # priority for metagenomes
    my @recs2;    # remainder

    ### get MER-FS genes for the cog:
    my %taxon_in_file;
    my %taxonProfile;
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql2 = qq{
        select tx.taxon_oid, tx.taxon_display_name,
               tx.domain, tx.seq_status, tx.in_file
        from taxon tx
        where tx.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ( $tx2, $txname2, $txdomain2, $txseq_status2, $infile2 )
	    = $cur2->fetchrow();
        last if !$tx2;
        $taxonProfile{$tx2} = 
	    $txname2 . "\t" . $txdomain2 . "\t" . $txseq_status2;
        if ( $in_file && $infile2 eq "Yes" ) {
            $taxon_in_file{$tx2} = 1;
        }
    }
    $cur2->finish();

    printStartWorkingDiv("genesforcogid");
    my @file_taxons = keys %taxon_in_file;
    if ( ( scalar @file_taxons ) > 0 ) {
        timeout( 60 * 20 );    # timeout in 20 minutes

        print "<p>this may take time - please be patient.";

        my $minNoGenes   = 1500;       # minimu no. of genes in genome
        my $minBasePairs = 1500000;    # minimum DNA size

        foreach my $txid (@file_taxons) {
            $txid = sanitizeInt($txid);

            # check "genome" criteria for "single copy cog":
            my $total_genes = MetaUtil::getGenomeStats
		( $txid, "", "Protein coding genes" );
            my $num_bases   = MetaUtil::getGenomeStats
		( $txid, "", "Number of bases" );
            if (    $num_bases < $minBasePairs
                 || $total_genes < $minNoGenes ) {
                next;
            }

            my @type_list = ('assembled');
            for my $t2 (@type_list) {
                my %h = MetaUtil::getTaxonFuncsGenes($txid, $t2, "cog");
                if (scalar(keys %h) > 0) {
                    for my $cog (keys %h) {
                        my @gene_list = split( /\t/, $h{$cog} );
                        for my $gene (@gene_list) {
                                                        
                            next if ( $cog ne $cog_id );
        
                            my $valuesStr = MetaDetail::passesSingleCopyCriteria
                             ( $txid, $gene, $t2, $cog, $cog_seq_length );
                            next if !$valuesStr;
        
                            # retrieve all cog_id info for gene:
                            my ( $gene_name, $aa_seq_length, $gid2, $cog2,
                                 $perc_identity, $align_length, $q_start, $q_end, 
                                 $s_start, $s_end, $evalue, $bit_score, $rank )
                                = split( /\t/, $valuesStr );
                            next if ( $cog2 ne $cog_id );
        
                            if ( $gene_name eq "" ) {
                                my $source;
                                ( $gene_name, $source ) = 
                                    MetaUtil::getGeneProdNameSource
                                    ( $gid2, $txid, "assembled" );
                            }

                            my ( $txname2, $txdomain2, $txseq_status2 )
                                = split( "\t", $taxonProfile{$txid} );

                            my $r;
                            $r .= "$gid2\t";
                            $r .= "$gene_name\t";
                            $r .= "$aa_seq_length\t";
                            $r .= "$txid\t";
                            $r .= "$txname2\t";
                            $r .= "$txdomain2\t";
                            $r .= "$txseq_status2\t";
                            $r .= "$perc_identity\t";
                            $r .= "$q_start\t";
                            $r .= "$q_end\t";
                            $r .= "$s_start\t";
                            $r .= "$s_end\t";
                            $r .= "$evalue\t";
                            $r .= "$bit_score\t";
                            $r .= "$cog2\t";
                            $r .= "$cog_seq_length\t";
        
                            push( @recs1, $r );
                            
                        }
                    }        
                }
                
            }
        }
    }
    ########## end MER-FS

    my @arrayOfArray1;
    my @arrayOfArray2;
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql1 = qq{
        select g.gene_oid, g.gene_display_name, g.aa_seq_length,
            tx.taxon_oid, tx.taxon_display_name, 
            tx.genome_type, tx.domain, tx.seq_status, 
            gcg.percent_identity, 
            gcg.query_start, gcg.query_end, 
            gcg.subj_start, gcg.subj_end, 
            gcg.evalue, gcg.bit_score, c.cog_id, c.seq_length
        from dt_scog_genes dt, gene_cog_groups gcg, gene g, cog c, taxon tx
        where dt.cog_id = gcg.cog
            $rclause
            $imgClause
            and gcg.cog = ?
            and gcg.cog = c.cog_id
            and dt.gene_oid = gcg.gene_oid
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.taxon = dt.taxon_oid
            and tx.domain = 'Archaea'
            and rownum < $max_no_cog_genes
        order by gcg.bit_score desc
    };
    print "<br/> Looking for hits to Archaea <br/>\n";
    getData( $dbh, $sql1, $cog_id, \@arrayOfArray1, \@arrayOfArray2 );

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql2 = qq{
        select g.gene_oid, g.gene_display_name, g.aa_seq_length,
            tx.taxon_oid, tx.taxon_display_name, 
            tx.genome_type, tx.domain, tx.seq_status, 
            gcg.percent_identity, 
            gcg.query_start, gcg.query_end, 
            gcg.subj_start, gcg.subj_end, 
            gcg.evalue, gcg.bit_score, c.cog_id, c.seq_length
        from dt_scog_genes dt, gene_cog_groups gcg, gene g, cog c, taxon tx
        where dt.cog_id = gcg.cog
            $rclause
            $imgClause
            and gcg.cog = ?
            and gcg.cog = c.cog_id
            and dt.gene_oid = gcg.gene_oid
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.taxon = dt.taxon_oid
            and tx.domain = 'Bacteria'
            and rownum < $max_no_cog_genes
        order by gcg.bit_score desc
    };
    print "Looking for hits to Bacteria <br/>\n";
    getData( $dbh, $sql2, $cog_id, \@arrayOfArray1, \@arrayOfArray2 );

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql3 = qq{
        select g.gene_oid, g.gene_display_name, g.aa_seq_length,
	    tx.taxon_oid, tx.taxon_display_name, 
	    tx.genome_type, tx.domain, tx.seq_status, 
            gcg.percent_identity, 
	    gcg.query_start, gcg.query_end, 
	    gcg.subj_start, gcg.subj_end, 
	    gcg.evalue, gcg.bit_score, c.cog_id, c.seq_length
        from dt_scog_genes dt, gene_cog_groups gcg, gene g, cog c, taxon tx
	where dt.cog_id = gcg.cog
            $rclause
            $imgClause
   	    and gcg.cog = ?
 	    and gcg.cog = c.cog_id
	    and dt.gene_oid = gcg.gene_oid
	    and gcg.gene_oid = g.gene_oid
	    and g.taxon = tx.taxon_oid
	    and g.taxon = dt.taxon_oid
            and g.taxon in( $taxon_oid_str )
            and rownum < $max_no_cog_genes
        order by gcg.bit_score desc
    };
    print "Looking for Query genomes <br/>\n";
    getData( $dbh, $sql3, $cog_id, \@arrayOfArray1, \@arrayOfArray2 );
    #$dbh->disconnect();
    
    #sort array of arrays
    my @sorted1 = sort { $a->[13] <=> $b->[13] } @arrayOfArray1;
    my @sorted2 = sort { $a->[13] <=> $b->[13] } @arrayOfArray2;

    foreach my $row (@sorted1) {
        my $r = join("\t", @{$row});
    	push( @recs1, $r );
    }
    foreach my $row (@sorted2) {
        my $r = join("\t", @{$row});
    	push( @recs2, $r );
    }

    printEndWorkingDiv("genesforcogid");

    printMainForm();
    my $sid = WebUtil::getSessionId();
    my $it  = new InnerTable( 1, "phyloCogGenes$$" . "_$sid", "phyloCogGenes", 9 );
    my $sd  = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "asc",  "left" );
    $it->addColSpec( "Product Name",         "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec( "Genome",               "asc",  "left" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, " . "P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec("Algnment<br/>On Gene");
    $it->addColSpec("Algnment<br/>On COG");
    $it->addColSpec( "Bit Score", "desc", "right" );
    $it->addColSpec( "E-value",   "asc",  "left" );

    my $count = 0;
    my $trunc = 0;
    ## Metagenome rows get priority.
    for my $r (@recs1) {
        my (
             $gene_oid,           $gene_display_name, $g_aa_seq_length, $taxon_oid,
             $taxon_display_name, $domain,            $seq_status,      $percent_identity,
             $query_start,        $query_end,         $subj_start,      $subj_end,
             $evalue,             $bit_score,         $cog_id,          $cog_seq_length
          )
          = split( /\t/, $r );
        $count++;
        if ( $count > $max_no_cog_genes ) {
            $trunc = 1;
            last;
        }
        $evalue           = sprintf( "%.2e",   $evalue );
        $percent_identity = sprintf( "%.2f%%", $percent_identity );
        $bit_score        = sprintf( "%d",     $bit_score );
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        my $r;

        my $fsid;
        my $gnurl = "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene_oid";
        my $txurl = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        if ( $taxon_in_file{$taxon_oid} ) {
            $gnurl =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$taxon_oid"
              . "&data_type=assembled&gene_oid=$gene_oid";
            $txurl = "$main_cgi?section=MetaDetail" 
                . "&page=metaDetail&taxon_oid=$taxon_oid";
            $fsid = $taxon_oid . " assembled " . $gene_oid;    # important!!!
            $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$fsid' checked />\t";
        } else {
            $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' checked />\t";
            $fsid = $gene_oid;
        }
        $r .= $fsid . $sd . alink( $gnurl, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        $r .= $taxon_display_name . $sd . alink( $txurl, $taxon_display_name ) . "\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $sd . alignImage( $query_start, $query_end, $g_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $cog_seq_length ) . "\t";
        $r .= "$bit_score\t";
        $r .= "$evalue\t";
        $it->addRow($r);
    }

    ## Bacteria and Archaea remainder.
    for my $r (@recs2) {
        my (
             $gene_oid,           $gene_display_name, $g_aa_seq_length, $taxon_oid,
             $taxon_display_name, $domain,            $seq_status,      $percent_identity,
             $query_start,        $query_end,         $subj_start,      $subj_end,
             $evalue,             $bit_score,         $cog_id,          $cog_seq_length
          )
          = split( /\t/, $r );
        last if $trunc;
        $count++;
        if ( $count > $max_no_cog_genes ) {
            $trunc = 1;
            last;
        }
        $evalue           = sprintf( "%.2e",   $evalue );
        $percent_identity = sprintf( "%.2f%%", $percent_identity );
        $bit_score        = sprintf( "%d",     $bit_score );
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' checked />\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $sd . alignImage( $query_start, $query_end, $g_aa_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $cog_seq_length ) . "\t";
        $r .= "$bit_score\t";
        $r .= "$evalue\t";
        $it->addRow($r);
    }

    print "<p>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen();
    print "</p>\n";

    my $name = "_section_${section}_phyloCogsJalview";
    print submit(
                  -name  => $name,
                  -value => "Run Jalview",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_${section}_phyloCogsMultalin";
    print submit(
                  -name  => $name,
                  -value => "Run Multalin",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    WebUtil::printGeneCartFooter();
    $it->printOuterTable(1);

    #print "<b>Output Format:</b>\n";
    #my $sp = " " x 30;
    #print popup_menu( -name => "outputView",
    #  -values => [ "Text Tree$sp", "Image Tree$sp" ]
    #);
    #print "<br/>\n";
    print hiddenVar( "minPercIdent",  $minPercIdent );
    print hiddenVar( "minPercAlign",  $minPercAlign );
    print hiddenVar( "maxEvalue",     $maxEvalue );
    print hiddenVar( "maxPerLenDiff", $maxPercLenDiff );
    print hiddenVar( "cog_id",        $cog_id );
    for my $taxon_oid (@taxon_oids) {
        print hiddenVar( "taxon_oid", $taxon_oid );
    }

    my $name = "_section_${section}_phyloCogsJalview";
    print submit(
                  -name  => $name,
                  -value => "Run Jalview",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_${section}_phyloCogsMultalin";
    print submit(
                  -name  => $name,
                  -value => "Run Multalin",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    WebUtil::printGeneCartFooter();
    print end_form();

    if ($trunc) {
        printStatusLine( "Results truncated to $max_no_cog_genes genes.", 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
}

sub getData {
    my ( $dbh, $sql, $cog_id, $aref1, $aref2 ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my $count = 0;
    for ( ; ; ) {
        my (
             $gene_oid,    $gene_display_name, $g_aa_seq_length, $taxon_oid,        $taxon_display_name,
             $genome_type, $domain,            $seq_status,      $percent_identity, $query_start,
             $query_end,   $subj_start,        $subj_end,        $evalue,           $bit_score,
             $cog_id,      $cog_seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $count++;

        #last if ( $count > $max_no_cog_genes );

        my $r;
        $r .= "$gene_oid\t"; # 0
        $r .= "$gene_display_name\t";
        $r .= "$g_aa_seq_length\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$percent_identity\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t"; # 13
        $r .= "$cog_id\t";
        $r .= "$cog_seq_length";

        if ( $genome_type eq "metagenome" ) {
            push @$aref1, [split(/\t/, $r)];
        } else {
            push @$aref2, [split(/\t/, $r)];
        }
    }
    $cur->finish();

}

############################################################################
# printPhyloCogJalview - Print clustalw alignment in Jalview
############################################################################
sub printPhyloCogsJalview {
    my $cog_id    = param("cog_id");
    my @gene_oids = param("gene_oid");

    print "<h1>Multiple Alignment for $cog_id</h1>\n";
    use ClustalW;
    ClustalW::runClustalw( \@gene_oids, "amino" );
}

############################################################################
# printPhyloCogsMultalin - Print multalin results.
############################################################################
sub printPhyloCogsMultalin {
    my @taxon_oids    = param("taxon_oid");
    my %taxon_oids_h  = WebUtil::array2Hash(@taxon_oids);
    my $taxon_oid_str = join( ',', @taxon_oids );
    my $cog_id        = param("cog_id");
    my @gene_oids     = param("gene_oid");
    my $total_genes   = scalar(@gene_oids);

    my $imageTree = 1;
    if ( param("outputView") =~ /Image/ ) {
        $imageTree = 1;
    }
    if ( $total_genes < 2 ) {
        webError("Please select two or more genes.<br/>\n");
    }
    if ( $total_genes > $max_no_cog_genes ) {
        webError("Please select a maximum of $max_no_cog_genes genes.");
    }
    if ( $cog_id eq "" ) {
        webError("Please select a COG.<br/>\n");
    }

    print "<h1>Multiple Alignment for $cog_id</h1>\n";

    my $murl  = "http://www.ncbi.nlm.nih.gov/pubmed/2849754";
    my $mlink = alink( $murl, "Multalin", "_blank" );

    print "<p>\n";
    print "$mlink hierarchical clustering output is shown below. ";
    print "MSF output follows.<br/>\n";
    print "(Please be patient when aligning a large number of genes.)<br/>\n";
    print "</p>\n";
    printHint
	( "- Mouse over hyperlink to see gene product name.<br/>\n"
	. "- Click on gene identifier hyperlink to see gene details.<br/>"
	. "- Metagenome paralogs are highlighed in "
	. "<font color='red'>red</font> and marked with (*)." );
    printStatusLine( "Loading ...", 1 );

    # find which genes are MER-FS:
    my @gene_oids2;
    my @fs_txgene_oids;
    foreach my $gene (@gene_oids) {
        my @items = split( " ", $gene );
        if ( scalar @items == 1 ) {
            push( @gene_oids2, $gene );
        } else {
            push( @fs_txgene_oids, $gene );
        }
    }
    my $nfs_txgenes  = scalar @fs_txgene_oids;
    my $gene_oid_str = join( ',', @gene_oids2 );

    my $tmpBlosumFile = "$cgi_tmp_dir/blosum62.$$.txt";
    my $froot         = "multalin$$";
    my $tmpFaa        = "$cgi_tmp_dir/$froot.faa";
    my $tmpMsf        = "$cgi_tmp_dir/$froot.msf";
    my $tmpClu        = "$cgi_tmp_dir/$froot.clu";
    my $tmpCl2        = "$cgi_tmp_dir/$froot.cl2";
    my $tmpCfg        = "$cgi_tmp_dir/ma.cfg";

    my %geneOid2TaxonName;
    my %geneOid2TaxonOid;
    my %geneOid2GeneName;
    my %idx2GeneOid;

    my $wfh = newWriteFileHandle( $tmpFaa, "printPhyloCogsMultalin" );
    my $idx = 0;
    my %done;

    my $dbh = dbLogin();

    my %taxon_in_file;
    my %taxonProfile;
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql2 = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.in_file
        from taxon tx
        where tx.taxon_oid in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ( $tx2, $txname2, $infile2 ) = $cur2->fetchrow();
        last if !$tx2;
        $taxonProfile{$tx2} = $txname2;
        if ( $in_file && $infile2 eq "Yes" ) {
            $taxon_in_file{$tx2} = 1;
        }
    }
    $cur2->finish();

    printStartWorkingDiv();

    # add faa for MER-FS
    if ( $nfs_txgenes > 0 ) {
	print "<p>getting MER-FS gene info <br/>";
        foreach my $id (@fs_txgene_oids) {
            my ( $taxon_oid, $dt, $gene_oid ) = split( " ", $id );
            next if $done{$gene_oid};

	    print "getting info for $id <br/>";
            my ( $gene_display_name, $source ) = 
		MetaUtil::getGeneProdNameSource
		($gene_oid, $taxon_oid, "assembled");
            my $aa_residue = 
		MetaUtil::getGeneFaa($gene_oid, $taxon_oid, "assembled");

            $idx++;
            $geneOid2GeneName{$gene_oid}  = $gene_display_name;
            $geneOid2TaxonName{$gene_oid} = $taxonProfile{$taxon_oid};
            $geneOid2TaxonOid{$gene_oid}  = $taxon_oid;
            $idx2GeneOid{$idx}            = $gene_oid;
            $aa_residue =~ s/\s+//g;
            $aa_residue =~ s/\*//g;
            $aa_residue =~ s/\-//g;
            print $wfh ">$idx\n";
            print $wfh "$aa_residue\n";
            $done{$gene_oid} = 1;
        }
    }

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select g.gene_oid, tx.taxon_oid, tx.taxon_display_name,
 	       g.gene_display_name, g.aa_residue
	from gene g, taxon tx
	where g.taxon = tx.taxon_oid
        and g.gene_oid in( $gene_oid_str )
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    print "getting DB gene info <br/>";
    for ( ;; ) {
        my ( $gene_oid, $taxon_oid, $taxon_display_name,
	     $gene_display_name, $aa_residue ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid};

        $idx++;
        $geneOid2GeneName{$gene_oid}  = $gene_display_name;
        $geneOid2TaxonName{$gene_oid} = $taxon_display_name;
        $geneOid2TaxonOid{$gene_oid}  = $taxon_oid;
        $idx2GeneOid{$idx}            = $gene_oid;
        $aa_residue =~ s/\s+//g;
        $aa_residue =~ s/\*//g;
        $aa_residue =~ s/\-//g;
        print $wfh ">$idx\n";
        print $wfh "$aa_residue\n";
        $done{$gene_oid} = 1;
    }
    close $wfh;

    print "<p>running Multalin... <br/>";
    my $tmpOut = "$cgi_tmp_dir/$froot.out";

    chdir($cgi_tmp_dir);
    printMainForm();

    wunlink($tmpCfg);
    my $blosum62_file = "$cgi_dir/blosum62.txt";
    my $d_flag = "-d ";
    $d_flag = "" if $imageTree;
    my $cmd = "$ma_bin -c:$blosum62_file -q $d_flag $tmpFaa";
    runCmd($cmd);
    wunlink($tmpCfg);
    chdir($cgi_dir);

    printEndWorkingDiv();

# This info is already printed by default below tree:
#    print "<p>\n";
#    print "<font color='blue'>\n";
#    print "<pre>\n";
#    print "Multalin version 5.4.1<br/>"
#	. "Copyright I.N.R.A. France 1989, 1991, 1994, 1996<br/>"
#	. "Multiple sequence alignment with hierarchical clustering<br/>"
#	. "F. Corpet, 1988, Nucl. Acids Res., 16 (22), 10881-10890";
#    print "</pre>\n";
#    print "</font>\n";
#    print "<p>\n";

    if ($imageTree) {
        printImageTree( $tmpCl2, \%idx2GeneOid, \%geneOid2TaxonName, 
			\%geneOid2GeneName, \%geneOid2TaxonOid,
                        \%taxon_oids_h );
    } else {
        printTextTree( $tmpCl2, \%idx2GeneOid, \%geneOid2TaxonName,
		       \%geneOid2GeneName, \%geneOid2TaxonOid,
		       \%taxon_oids_h );
    }
    print end_form();

    print "<font color='blue'>\n";
    print "<pre>\n";
    my $rfh = newReadFileHandle( $tmpMsf, "printPhyloCogsMultalin" );
    my $inAln = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;

        if ( $s =~ /^\/\// ) {
            $inAln = 1;
            print "// MSF Output: \n";
        } elsif ( !$inAln && $s =~ /^\s*Name:/ ) {
            my $nstr = substr( $s, 0, 20 );
            my $tstr = substr( $s, 20 );
            $nstr =~ s/\s+//g;
            my ( $name, $idx ) = split( /:/, $nstr );
            my $gene_oid = $idx2GeneOid{$idx};
            printf "%-40s", " Name: $gene_oid";
            print "$tstr\n";
        } else {
            print "$s\n" if !$inAln;
        }
        next if !$inAln;
        my $idx = substr( $s, 0, 20 );
        $idx =~ s/\s+//g;
        my $tstr = substr( $s, 20 );
        my $gene_oid = $idx2GeneOid{$idx};
        $gene_oid = "Consensus"
          if $gene_oid eq ""
          && !intLineOnly($tstr)
          && !blankStr($s);
        printf "%40s", $gene_oid;
        print "$tstr\n";
    }
    close $rfh;
    print "</pre>\n";
    print "</font>\n";

    #$dbh->disconnect();

    wunlink($tmpBlosumFile);
    wunlink($tmpFaa);
    wunlink($tmpMsf);
    wunlink($tmpClu);
    wunlink($tmpCl2);
    wunlink($tmpCfg);
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printTextTree - Show multalin text tree.
############################################################################
sub printTextTree {
    my ( $inFile, $idx2GeneOid_ref, $geneOid2TaxonName_ref,
	 $geneOid2GeneName_ref, $geneOid2TaxonOid_ref, $taxon_oids_h_ref )
      = @_;

    printGeneCartFooter();
    print "<font color='blue'>\n";
    print "<pre>\n";
    my $rfh = newReadFileHandle( $inFile, "printTextTree" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;

        my $idx = substr( $s, 0, 8 );
        $idx =~ s/\s+//g;
        my $gene_oid          = $idx2GeneOid_ref->{$idx};
        my $tstr              = substr( $s, 8 );
        my $taxon_name        = $geneOid2TaxonName_ref->{$gene_oid};
        my $gene_display_name = $geneOid2GeneName_ref->{$gene_oid};
        my $g_taxon           = $geneOid2TaxonOid_ref->{$gene_oid};
        my $highlight         = 0;
        $highlight = 1 if $taxon_oids_h_ref->{$g_taxon};

        my $url = "$main_cgi?section=GeneDetail" 
	        . "&page=geneDetail&gene_oid=$gene_oid";
	if (!WebUtil::isInt($gene_oid)) {
	    $url .= "&taxon_oid=$g_taxon&data_type=assembled";
	}
        my $gene_oid2 = sprintf( "%010d", $gene_oid );
        my $gene_oid_link = $gene_oid2;
        $gene_oid_link = 
	    "<a href='$url' title='$gene_display_name'>$gene_oid2</a>"
	    if $g_taxon ne "";
        $taxon_name = colSized( $taxon_name, 30 );
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' /> ";
        print " ";
        print "$gene_oid_link ";
        print "<font color='red'>" if $highlight;
        print $taxon_name;
        print "</font>" if $highlight;
        print "$tstr\n";
    }
    close $rfh;
    print "<br/>\n";
    print "</pre>\n";
    print "</font>\n";
    printGeneCartFooter();
}

############################################################################
# printImageTree - Show multalin newick output in image tree.
############################################################################
sub printImageTree {
    my ( $inFile, $idx2GeneOid_ref, $geneOid2TaxonName_ref,
	 $geneOid2GeneName_ref, $geneOid2TaxonOid_ref, $taxon_oids_h_ref )
      = @_;

    my $newick = file2Str($inFile);
    webLog( $newick . "\n" );
    if ( blankStr($newick) ) {
        webError("Invalid newick '$newick' string.\n");
    }
    my %id2Rec;
    my @keys = sort( keys(%$idx2GeneOid_ref) );
    for my $k (@keys) {
        my $gene_oid          = $idx2GeneOid_ref->{$k};
        my $taxon_name        = $geneOid2TaxonName_ref->{$gene_oid};
        my $gene_display_name = $geneOid2GeneName_ref->{$gene_oid};
        my $taxon_oid         = $geneOid2TaxonOid_ref->{$gene_oid};
        my $highlight         = 0;
        $highlight = 1 if $taxon_oids_h_ref->{$taxon_oid};

        my $gene_oid_url = "$main_cgi?section=GeneDetail" 
	                 . "&page=geneDetail&gene_oid=$gene_oid";
	if (!WebUtil::isInt($gene_oid)) {
	    $gene_oid_url .= "&taxon_oid=$taxon_oid&data_type=assembled";
	}

        my $r;
        my $x;
        $x = " (*)" if $highlight;
        $r .= "$gene_oid $taxon_name$x\t";
        $r .= "$highlight\t";
        $r .= "$gene_oid $gene_display_name\t";
        $r .= "$gene_oid_url\t";
        $id2Rec{$k} = $r;
    }
    my $dt      = new DrawTree( $newick, \%id2Rec );
    my $tmpFile = "drawTree$$.png";
    my $outPath = "$tmp_dir/$tmpFile";
    my $outUrl  = "$tmp_url/$tmpFile";
    $dt->drawToFile($outPath);
    my $s = $dt->getMap( $outUrl, 0 );
    print "$s\n";
}

############################################################################
# intLineOnly - Line only has integers.
############################################################################
sub intLineOnly {
    my ($s) = @_;
    my @toks = split( / /, $s );
    my $intCount = 0;
    for my $t (@toks) {
        next if $t eq "";
        return 0 if !WebUtil::isInt($t);
    }
    return 1;
}

############################################################################
# colSized - Ensure column size.
############################################################################
sub colSized {
    my ( $s, $n ) = @_;
    $s = substr( $s, 0, $n );    # truncate
    my $len = length($s);
    if ( $len < $n ) {
        my $diff = $n - $len;
        $s .= " " x $diff;
    }
    return "$s";
}

1;

