############################################################################
# GeneCartChrViewer.pm - Gene cart chromosome viewer for Kostos.
#   --es 09/28/2006 to be turrned over to imachen.
#
# Notes to Amy on developing on durian:
#   1.  You can view messages, e.g. for debugging,
#       by openeing a window on durian, and doing
#           % tail -f /var/log/apache/error.log
#       If you
#           print STDERR "my debugging/error statement\n"
#       in Perl, you can see messages there.
#   2.  Similarly you can use the webLog( "..." ) function
#       to view application log entries in the file specified
#       by WebConfig.pm: $e->{ web_log_file }.
#
# $Id: GeneCartChrViewer.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package GeneCartChrViewer;
my $section = "GeneCartChrViewer";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use CGI::Carp 'fatalsToBrowser';
use InnerTable;
use WebUtil;
use WebConfig;
use ImgTermCartStor;
use Math::Trig;
use Bio::Perl;

# use lib '/home/kmavromm/img_ui/';
use CircularMap;
use OracleUtil;
use MerFsUtil;

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $verbose     = $env->{verbose};
my $tmp_pix_dir = $env->{tmp_dir};   # directory where the picture will be stored
my $tmp_pix_url = $env->{tmp_url};
my $section     = "GeneCartChrViewer";

my $max_item_count        = 200;     # limit the number of returned IMG terms
my $max_upload_line_count = 1000;    # limit the number of lines in file upload
my $maxScaffolds          = 10;

my $module_name  = "drawCircMap";
my $NUM_OF_BANDS = 8;

############################################################################
# dispatch - Dispatch to pages for this section.
############################################################################
sub dispatch {
    my $dbh = dbLogin();
    checkDomain($dbh);

    my $page = param("page");
    ## Massage submit button to use same "page" convention.
    if ( $page eq "" ) {
        if ( paramMatch("index") ne "" ) {
            $page = "index";
            showForm($dbh);
            #$dbh->disconnect();
        } elsif ( paramMatch($module_name) ne "" ) {
            #$dbh->disconnect();
            $page = "index";
            showPIX();
        }
    } else {
         #$dbh->disconnect();
    }
    webLog("Dispatch to page '$page'\n");
}

############################################################################
# dispatchPixGeneration - Decides if it will ask for the assignment of
# genes to circles or it will draw the map
############################################################################
#sub dispatchPixGeneration {

sub showForm {
    my ($dbh) = @_;
    printMainForm();

    my @data_basket = GetCartGenes();
    #print "GeneCartChrViewer::showForm GetCartGenes() done<br/>\n";
    my ( $v1, $v2 ) = check_genes( $dbh, \@data_basket );
    #print "GeneCartChrViewer::showForm check_genes() done<br/>\n";
    print_form( $v1, $v2 );
    print end_form();
}

sub showPIX {
    # if there is information about the genes to be drawn
    # proceed in finding the genes that belong to each circle
    # and create the tables that are necessary for the drawing
    # of the circle

    printMainForm();
    my @batch_genes;
    my @circle_batch;
    my @scaffolds;
    my @circles; # = ( 'Circle1', 'Circle2', 'Circle3', 'Circle4',
                 #     'Circle5', 'Circle6', 'Circle7', 'Circle8' );
    for (my $i=1; $i<=$NUM_OF_BANDS; $i++) {
        my $tmp = 'Circle' . $i;
        push(@circles, $tmp);
    }
    
    for ( my $c = 1 ; $c <= scalar(@circles) ; $c++ ) {
        my $circle = $circles[ $c - 1 ];
        if (    param($circle)
             && param('scaffolds') ) {   # genes that belong to circle 1.
            my @circle_genes = param($circle);
            foreach my $gene (@circle_genes) {
                push @batch_genes, [ $gene, $c ];
            }
            push @circle_batch, $c;
        }
    }

    if ( param('scaffolds') ) {
        @scaffolds = split( ":", param('scaffolds') );
    }
    if ( scalar(@batch_genes) > 0 && scalar(@scaffolds) > 0 ) {
        CircularMap::draw_pix( \@scaffolds, \@circle_batch, \@batch_genes );
    }

    print end_form();
}

###############################################################################
# show a table with the genes and allow the user to select the circle
# that each gene should be drawn
# --- batches removed, Gene Cart no longer support batch id
###############################################################################
sub print_form {
    my ( $v1, $v2 ) = @_;

    my ($scaffolds_ref, $batch_genes_ref) = CircularMap::geneInfo(@$v2);
    my @scaffolds = @$scaffolds_ref;
    my @batch_genes = @$batch_genes_ref;

    @scaffolds = &CircularMap::unique( \@scaffolds, 1 );
    #print "scaffolds size: ".scalar(@scaffolds)."<br/>\n";
    if ( scalar(@scaffolds) > $maxScaffolds ) {
        webError("Too many scaffolds: Please select genes from no more than "
         . $maxScaffolds . " scaffolds");
    }

    print start_form( -action => $main_cgi, -name => "selectScaffolds" );

    # show the table with the selections
    print "<h1>Choromosome Map</h1>\n";
    my @batches = @$v1;
    if ( scalar(@batches) > $NUM_OF_BANDS ) { 
    	print "<p>";
    	print "Note: there are too many batches, only the first "
    	    . $NUM_OF_BANDS . " will be selected.";
    	print "</p>";
    }
    
    printStatusLine( "Loading ...", 1 );
    
    my $it = new InnerTable(1, "chromMap$$", "chromMap", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Gene ID", "asc", "right", "", "", "wrap" );
    $it->addColSpec( "Locus Tag", "asc", "left" ); 
    $it->addColSpec( "Product Name", "asc", "left" ); 
    $it->addColSpec( "Start", "asc", "left" ); 
    $it->addColSpec( "End", "asc", "left" ); 
    $it->addColSpec( "Strand", "asc", "left" ); 
    $it->addColSpec( "Scaffold", "asc", "left" ); 
    $it->addColSpec( "Batch", "asc", "left" ); 
    for (my $i=1; $i<= $NUM_OF_BANDS; $i++) { 
    	$it->addColSpec( "Band ".$i, "", "", "", "", "wrap" ); 
    } 

    my $cnt = 0; 
    for ( my $i = 0 ; $i < scalar(@batch_genes) ; $i++ ) {
        $cnt++; 

        my $row; 
        if (isInt($batch_genes[$i][0])) {
            $row .= $batch_genes[$i][0]."\t";
        }
        else {
        	my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $batch_genes[$i][0]);
            $row .= $gene_oid."\t";
        }
        
        $row .= $batch_genes[$i][6]."\t";
        $row .= $batch_genes[$i][1]."\t";
        $row .= $batch_genes[$i][3]."\t";
        $row .= $batch_genes[$i][4]."\t";
        $row .= $batch_genes[$i][5]."\t";
        $row .= $batch_genes[$i][7]."\t";
        $row .= $batch_genes[$i][2]."\t";

        my $circle; 
        for ( my $ci = 1 ; $ci <= $NUM_OF_BANDS ; $ci++ ) {
            $circle = $ci if $batch_genes[$i][1] == $batches[$ci-1];
        } 
        for ( my $ch = 1 ; $ch <= $NUM_OF_BANDS ; $ch++ ) {
            my $check_box_name = "Circle" . $ch;

    	    $row .= $sd."<input type='checkbox' " 
                      . "name=\"$check_box_name\" "
                      . "value=\"$batch_genes[$i][0]\" ";
    	    $row .= " checked " if ($ch) == $circle;
    	    $row .= "/>\t";
        } 
        $it->addRow($row);
    } 
    $it->printOuterTable("nopage");

    print hiddenVar( "section", $section );
    #print hiddenVar("page",$page);
    my $scaffold_str = join( ":", @scaffolds );
    print hiddenVar( "scaffolds", $scaffold_str );

    print submit( -name  => $module_name,
                  -value => "Draw Map",
                  -class => "smdefbutton"
    );
    print end_form();    
    printStatusLine( "$cnt Loaded.", 2 );
}

############################################################################
# GetCartGenes - Get the information we need from the gene cart.
############################################################################
sub GetCartGenes {
    my $gc   = new GeneCartStor();
    my $recs = $gc->readCartFile();          # get records

    my @gene_oids = sort { $a <=> $b } keys(%$recs);

    # The keys for the records are gene_oids.
    # But we want them sorted.

    ## --es 09/30/2006 Retrieve selections from previous form's
    #    checkboxes having the name 'gene_oid', of which there are many,
    #    hence, an array.  We make a hash for easy lookup for selection.
    my @selected_gene_oids = param("gene_oid");

    my %selected_gene_oids_h;
    for my $gene_oid (@selected_gene_oids) {
        $selected_gene_oids_h{$gene_oid} = 1;
    }

    my @data_basket;    # contains the information about the genes
                        # add the information we need into the array databasket
    for my $gene_oid (@gene_oids) {
        my $r = $recs->{$gene_oid};
        my (
             $gene_oid,  $locus_tag,  $desc, $desc_orig,          
             $taxon_oid, $taxon_display_name,$batch_id, $scaffold,
             @outColVals
          )
          = split( /\t/, $r );
        push @data_basket, [ $gene_oid, $desc, $batch_id ]
          if $selected_gene_oids_h{$gene_oid} == 1;
    }
    return (@data_basket);
}

############################################################################
# printSearchGeneForm - Show search gene form.
############################################################################
sub printSearchGeneForm {
    print "<h2>Search Gene</h2>\n";

    print "<p>\n";
    print "Enter Search Term.  Use % for wildcard.\n";
    print "</p>\n";
    print "<input type='text' name='searchTerm' size='50' />\n";
    print "<br/>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print submit(
                  -name  => "searchGeneResults",
                  -value => "Go",
                  -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
}

############################################################################
# printExtTool - Example of external tool.
############################################################################
sub printExtTool {
    print "<h2>External Tools</h2>\n";

    print "<p>\n";
    print "Running external tools or writing to external files ";
    print "is tricky when runing in Perl taint ";
    print "mode.<br/>\n";
    print "All CGI variables are hackable and need to be 'checked' or ";
    print "'untained' for security reasons.<br/>\n";
    print "E.g., look at code such as WebUtil::sanitizeInt( ), e.g. to ";
    print "makes sure the value is an integer,<br/>not directory path ";
    print "name, etc. before using it in external files or tools.</br>\n";
    print "</p>\n";

    ## Set parameters.
    print hiddenVar( "section", $section );
    print submit(
                  -name  => "copyScaffoldOids",
                  -value => "Show Scaffold ID's",
                  -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
}

############################################################################
# printSearchGeneResults - Show results of term search.
############################################################################
sub printSearchGeneResults {
    print "<h1>Search Gene Results</h1>\n";
    printMainForm();
    my $dbh = dbLogin();

    my $searchTerm = param("searchTerm");

    ## Massage for SQL.
    #  Get rid of preceding and lagging spaces.
    #  Escape SQL quotes.
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    printStatusLine( "Loading ...", 1 );


    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
       select g.gene_oid, g.gene_display_name
       from gene g
       where lower( g.gene_display_name ) like lower( '%$searchTerm%' )
       $rclause
       $imgClause
       order by lower( g.gene_display_name )
    };
    my $cur = execSql( $dbh, $sql, $verbose, "%$searchTermLc%" );
    my $count = 0;
    print "<p>\n";
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > 200 ) {
            print "<br/>\n";
            print "Results truncated at 200 rows\n";
            print "<br/>\n";
            last;
        }
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid );
        print nbsp(1);
        print escHtml($gene_display_name);
        print "<br/>\n";
    }
    $cur->finish();
    print "</p>\n";
    #$dbh->disconnect();
    printStatusLine( "$count gene(s) found.", 2 );
}

############################################################################
# printCopyScaffoldOids - Copy taxon oids.  Use external tool "cp",
#   write and read a file.
############################################################################
sub printCopyScaffoldOids {
    print "<h1>Copied Scaffold ID's</h1>\n";
    my @selected_gene_oids = param("gene_oid");

    my $gc   = new GeneCartStor();
    my $recs = $gc->readCartFile();          # get records
    my @scaffold_oids;
    my %done;
    for my $gene_oid (@selected_gene_oids) {
        my $r = $recs->{$gene_oid};
        my (
             $gene_oid,  $locus_tag,   $desc, $desc_orig,          
             $taxon_oid, $taxon_display_name, $batch_id,  $scaffold,  
             @outColVals
          )
          = split( /\t/, $r );
        next if $done{$scaffold};

        # take only one copy ; could've also used hash.
        push( @scaffold_oids, $scaffold );
        $done{$scaffold} = 1;
    }
    my $tmpFile1 = "$cgi_tmp_dir/t1$$.txt";
    my $tmpFile2 = "$cgi_tmp_dir/t2$$.txt";
    my $wfh      = newWriteFileHandle( $tmpFile1, "copyScaffoldOids" );
    for my $scaffold_oid (@scaffold_oids) {
        print $wfh "$scaffold_oid\n";
    }
    close $wfh;

    WebUtil::unsetEnvPath();
    runCmd("/bin/cp $tmpFile1 $tmpFile2");
    WebUtil::resetEnvPath();

    print "<p>\n";
    my $rfh = newReadFileHandle( $tmpFile2, "copyScaffoldOids" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "scaffold_oid=$s<br/>\n";
    }
    close $rfh;
    print "</p>\n";
    wunlink($tmpFile1);
    wunlink($tmpFile2);
}

###############################################################################
# check if all the genes are on the same scaffold
# and that the batch number is smaller that the maximum
# --- batches removed, Gene Cart no longer support batch id
###############################################################################
sub check_genes {
    my ( $dbh, $gene_oids_aref ) = @_;
    my @gene_oids = @$gene_oids_aref;

    my @batches;
    my @batch_genes;

    my @db_gene_data;
    my @meta_gene_data;
    for ( my $j = 0 ; $j < scalar(@gene_oids); $j++ ) { 
        #each $gene_oids[$j] is one data_basket item
        if (isInt($gene_oids[$j][0])) {
            push (@db_gene_data, $gene_oids[$j]);
        }
        else {
            push (@meta_gene_data, $gene_oids[$j]);
        }
    }
    
    if (scalar(@db_gene_data) > 0) {
        @gene_oids = @db_gene_data;

        ###########################################################################
        # code added by Kostas 21 Feb 2007
        # use database to verify that the genes are present in current version
        # it will cause a delay but it will help avoid the problem when a user
        # changes database
        ###########################################################################
    
        my @tgene;
        my %good_genes;
    
        for ( my $j = 0 ; $j < scalar(@gene_oids) ; $j++ ) {
            push @tgene, $gene_oids[$j][0];
            if ( $j % 1000 == 0 or $j == scalar(@gene_oids) - 1 ) {
                # create an sql command
                my $gene_str = join( qq{','}, @tgene );
                @tgene = ();
    
                my $rclause   = WebUtil::urClause('g.taxon');
                my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
                my $sql = qq{
            		select g.gene_oid
            		from gene g
                    where g.gene_oid in ('$gene_str')
                    $rclause
                    $imgClause
        	    };
        	    my $cur = execSql( $dbh, $sql, $verbose );
        	    while ( my ($good_gene_oid) = $cur->fetchrow() ) {
            		$good_genes{$good_gene_oid} = 1;
        	    }
                $cur->finish();
            }
        }
    
        for ( my $g = 0 ; $g < scalar(@gene_oids) ; $g++ ) {
            if ( !defined( $good_genes{ $gene_oids[$g][0] } ) ) {
                webError("Gene $gene_oids[$g][0] does not exist in the database.");
            }
            #print "gene_oids[$g][0]: $gene_oids[$g][0]<br/>\n";
            #print "gene_oids[$g][1]: $gene_oids[$g][1]<br/>\n";
            #print "gene_oids[$g][2]: $gene_oids[$g][2]<br/>\n";

            my $gene_oid  = sanitizeInt( $gene_oids[$g][0] );
            my $gene_desc = $gene_oids[$g][1];
            
            my $batch_id = sanitizeInt( $gene_oids[$g][2] );
            push @batches, $batch_id;

            push @batch_genes, [ $gene_oid, $gene_desc, $batch_id ];
        }
    }
    
    if (scalar(@meta_gene_data) > 0) {
        for ( my $g = 0 ; $g < scalar(@meta_gene_data) ; $g++ ) {
            #print "meta_gene_data[$g][0]: $meta_gene_data[$g][0]<br/>\n";
            #print "meta_gene_data[$g][1]: $meta_gene_data[$g][1]<br/>\n";
            #print "meta_gene_data[$g][2]: $meta_gene_data[$g][2]<br/>\n";

            my $ws_gene_id = $meta_gene_data[$g][0];
        	my ($taxon_oid, $data_type, $g_oid) = split(/ /, $ws_gene_id);
            if ( $data_type ne 'assembled' ) {
                next;
            }
            my $gene_desc = $meta_gene_data[$g][1];

            my $batch_id = $meta_gene_data[$g][2];
            push (@batches, $batch_id);
            
            push @batch_genes, [ $ws_gene_id, $gene_desc, $batch_id ];
        }        
    }

#    if ( scalar(@batches) > $NUM_OF_BANDS ) {
#        # there are too many batches
#        # collapse all batches into one
#        for ( my $i = 0 ; $i < scalar(@batch_genes) ; $i++ ) {
#            $batch_genes[$i][1] = 1;
#        }
#        @batches = (1);
#    }
    if ( scalar(@batch_genes) <= 0 ) {
        webError("No genes selected: "
	       . "please select genes from the gene cart. Only assembled metagenome genes are supported.");
    }

    return ( \@batches, \@batch_genes );
}

############################################################################
# checkDomain - Check that the domain is Bacteria or Archaea.
#   We don't want to deal with the large Euks here.
############################################################################
sub checkDomain {
    my ($dbh) = @_;
    my @gene_oids = param("gene_oid");

    return if (scalar(@gene_oids) == 0);

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if (scalar(@dbOids) > 0) {
        my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );
    
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
    
        my $sql = qq{
           select tx.domain, g.gene_oid
           from gene g, taxon tx
           where g.taxon = tx.taxon_oid
           and g.gene_oid in( $gene_oid_str )
           $rclause
           $imgClause
           order by g.gene_oid
        };
    	webLog( "GeneCartChrViewer checkdomain sql: $sql\n" );
    
        my @bad_oids;
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $domain, $gene_oid ) = $cur->fetchrow();
            last if !$gene_oid;
            next if $domain ne "Eukaryota";
            push( @bad_oids, $gene_oid );
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $gene_oid_str =~ /gtt_num_id/i );
    
        my $bad_oid_str = join( ',', @bad_oids );
        return if blankStr($bad_oid_str);
        webError(   "Eukaryotes are not supported for this viewer. "
                  . "Check gene_oids $bad_oid_str." );

    }

}

1;
