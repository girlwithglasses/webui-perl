############################################################################
# TaxonCircMaps.pm - Circular maps for one taxon.
#
# $Id: TaxonCircMaps.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package TaxonCircMaps;
my $section = "TaxonCircMaps";
use Data::Dumper;
use Archive::Zip;
use Storable;
use CGI qw( :standard );
use CGI::Carp 'fatalsToBrowser';
use WebUtil;
use WebConfig;
use ImgTermCartStor;
use CircularMap;
use MetaUtil;

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $verbose     = $env->{verbose};
my $tmp_pix_dir =
  $env->{tmp_dir};   #new used for the directory that the picture will be stored
my $tmp_pix_url = $env->{tmp_url};    #new
my $section     = "TaxonCircMaps";

my $mer_data_dir   = $env->{mer_data_dir};

my $max_scf_count = 1000;
my $maxScaffolds = 10;

############################################################################
# dispatch - Dispatch to right page.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( param("mscaffolds") ne "" ) {
        my @scaffolds = param("mscaffolds");
        check_scaffolds(@scaffolds);
        call_cirMap(@scaffolds);
    } elsif ( $page eq "circMaps" ) {
        printIndex();
    } else {
        webError("Please select 1 - $maxScaffolds scaffolds.");
    }
}

############################################################################
# printIndex - Root index page.
############################################################################
sub printIndex {
    my $taxon_oid = param("taxon_oid");

    my $formName = "selectScaffolds";
    print start_form( -action => $main_cgi, -name => $formName );

    print hiddenVar( "taxon_oid", $taxon_oid );

    my @scaffold_data = get_scaffolds($taxon_oid);
    my @scaffold_oids;

    # create a list with the scaffold oids
    for ( my $i = 0 ; $i < scalar(@scaffold_data) ; $i++ ) {
	if ( $i >= $max_scf_count ) {
	    print "<p style='color:red'>Too many scaffolds -- only $max_scf_count are displayed.</p>\n";
	    last;
	}
        push @scaffold_oids, $scaffold_data[$i][0];
    }

    if ( scalar(@scaffold_data) == 1 ) {
        # if the organism contains one scaffold no need for selections
        call_cirMap(@scaffold_oids);
    } else {
	# show a list with the scaffolds for the user to select
	my $scaffoldListName = "mscaffolds";
	my $scaffoldCntrId   = "scaffoldlist-counter";
	printJS($scaffoldListName, $scaffoldCntrId, $formName);

        print "<p>\n";
        print "Please select between 1 and $maxScaffolds scaffolds. ";
	print "<span id='$scaffoldCntrId'></span><br>\n";
        print "</p>\n";
        print "<select name=$scaffoldListName multiple size='10' onChange='return countSelected();'>\n";

        for ( my $i = 0 ; $i < scalar(@scaffold_data) ; $i++ ) {
            print "<option value=$scaffold_data[$i][0]>"
		. "$scaffold_data[$i][1]</option>\n";
        }
        print "</select>\n";
        print "<p>";

        ## Set parameters.
        print hiddenVar( "section", $section );
        print hiddenVar( "page",    $page );

        print submit(
	    -name    => "drawCircMap",
	    -value   => "Chromosome Map",
	    -class   => "meddefbutton",
	    -onClick => "return checkScaffoldList();"
        );
        print nbsp(1);
        print reset(
	    -name    => "Reset",
	    -value   => "Clear All",
	    -class   => "medbutton",
	    -onClick => "clearCounter();"
        );

        print end_form();
    }
    print "</p>\n";
}

###############################################################################
# calls the routine to draw circular map
# requires only the list of scaffold_oids..
# it DOES NOT check if it is a valid list
###############################################################################
sub call_cirMap {
    my @scaffold_oids = @_;
    my @batches       = ();
    my @batch_genes   = ();

    CircularMap::draw_pix( \@scaffold_oids, \@batches, \@batch_genes );
}

##############################################################################
# get scaffolds
# retrieves the scaffolds that correspond to this genome (taxon_oid)
##############################################################################
sub get_scaffolds {
    my $taxon_oid = $_[0];
    my @return_array;
    my $dbh = dbLogin();

    $taxon_oid = sanitizeInt($taxon_oid); 

    my $sql = qq{ 
        select is_pangenome, taxon_display_name, in_file
        from taxon 
        where taxon_oid = ? 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $is_pangenome, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();

    print "<h5>$taxon_name</h5>\n";

    my $count = 0;

    if (lc($is_pangenome) eq "yes") { 
    	my $sql = qq{ 
    	    select distinct pangenome_composition 
    	    from taxon_pangenome_composition 
    	    where taxon_oid = ? 
    	}; 
    	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    	my @taxon_oids; 
    	for ( ;; ) { 
    	    my ($id) = $cur->fetchrow();
    	    last if !$id;
    	    push( @taxon_oids, $id );
    	} 
    	$cur->finish(); 
    	my $taxon_str = join( ",", @taxon_oids );
    
    	my $sql = qq{ 
    	    select scaffold_oid, scaffold_name 
    	    from scaffold 
    	    where taxon in ($taxon_str) 
    	}; 
    
    	my $cur = execSql( $dbh, $sql, $verbose ); 
    	while ( my ( $scaffold_oid, $scaffold_name ) = $cur->fetchrow_array() ) { 
    	    push @return_array, [ $scaffold_oid, $scaffold_name ]; 
    	    $count++;
    	    if ( $count > $max_scf_count ) {
    		last;
    	    }
    	} 
    	$cur->finish();
    } elsif ( $in_file eq 'Yes' ) {

	   # MER-FS
	   my $t2 = 'assembled'; 
        my ($trunc, @lines) = MetaUtil::getScaffoldStatsForTaxon( $taxon_oid, $t2, 
            ' order by 4 desc ', $max_scf_count );
        for my $line (@lines) {
            my ( $scaffold_oid, $seq_len, $gc_percent, $n_genes ) = split( /\t/, $line );
    
            my $scaffold_name = $scaffold_oid . " (gene cnt: $n_genes)";
            push @return_array, [ $scaffold_oid, $scaffold_name ]; 
            $count++;
            if ( $count > $max_scf_count ) {
                last;
            }
        }
	   	
    } else {
    	my $sql = qq{
    	    select scaffold_oid, scaffold_name
    	    from scaffold
    	    where taxon = ?
    	};
    	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    	while ( my ( $scaffold_oid, $scaffold_name ) = $cur->fetchrow_array() ) {
    	    push @return_array, [ $scaffold_oid, $scaffold_name ];
    	    $count++;
    	    if ( $count > $max_scf_count ) {
    		    last;
    	    }
    	}
    	$cur->finish();
    }

    #$dbh->disconnect();

    return @return_array;
}

sub check_scaffolds {
    my @scaffolds = @_;
    if ( scalar(@scaffolds) > $maxScaffolds || scalar(@scaffolds) < 1 ) {
        webError("Please select 1 to $maxScaffolds scaffolds");
    }
}

##############################################################################
# printJS - JavaScript to validate number of scaffolds selected and
#           show a counter of scaffolds selected.
##############################################################################
sub printJS {
    my ($listName, $spanId, $form) = @_;
    print <<END_JS;

    <script language="javascript" type="text/javascript">

    function checkScaffoldList() {
	if (document.$form.$listName.selectedIndex < 0) {
	    alert("Please select at least ONE scaffold.");
	    return false;
	} else {
	    return countSelected(true);
	}
    }

    function clearCounter() {
	var oList = document.getElementById("$spanId");
	oList.innerHTML = "";
    }

    function countSelected(showAlert) {
	var cnt = 0;
	var el = document.$form.$listName;
	var oList = document.getElementById("$spanId");
	for (var i = 0; i < el.options.length; i++) {
	    if (el.options[i].selected) {
		cnt++;
	    }
	}
	if (cnt > $maxScaffolds) {
	    if (showAlert) {
		alert("You have selected " + cnt + " scaffolds. " +
		      "Please select a total of $maxScaffolds scaffolds or less.");
		return false;
	    } else {
		oList.style.color = "red";
		oList.style.fontWeight = "bold";
	    }
	} else {
	    oList.style.color = "";
	    oList.style.fontWeight = "bold";
	}
	if (cnt > 0)
	    oList.innerHTML = "(Scaffolds selected: " + cnt + ")";
	else
	    oList.innerHTML = "";
    }
    </script>

END_JS
}

1;

