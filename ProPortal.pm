############################################################################
#
# $Id: ProPortal.pm 33462 2015-05-27 19:48:22Z klchu $
############################################################################
package ProPortal;

use strict;
use CGI qw( :standard );
use DBI;
use POSIX qw(ceil floor);
use HTML::Template;
use WebConfig;
use WebUtil;
use Data::Dumper;
use GenomeList;

my $section = 'ProPortal';
my $env                  = getEnv(); 
my $main_cgi             = $env->{main_cgi}; 
my $section_cgi          = "$main_cgi?section=$section"; 
my $verbose              = $env->{verbose}; 
my $base_url              = $env->{base_url};
my $base_dir                 = $env->{base_dir};

sub getDatamartEnv {
    my $e = {};

    $e->{name} = 'IMG ProPortal';
    $e->{main_label} = 'Marine Cyanobacterium';

    my @members = ( 'prochlorococcus', 'synechococcus', 'cyanophage' );
    $e->{members} = \@members;

    my %labels;
    $labels{'prochlorococcus'} = 'Prochlorococcus';
    $labels{'synechococcus'} = 'Synechococcus';
    $labels{'cyanophage'} = 'Cyanophage';
    $e->{member_labels} = \%labels;

    my %conds;
    $conds{'prochlorococcus'} = "lower(t.GENUS) like '%prochlorococcus%' and t.sequencing_gold_id in (select gold_id from gold_sequencing_project\@imgsg_dev where ecosystem_type = 'Marine')";
    $conds{'synechococcus'} = "lower(t.GENUS) like '%synechococcus%' and t.sequencing_gold_id in (select gold_id from gold_sequencing_project\@imgsg_dev where ecosystem_type = 'Marine')";
    $conds{'cyanophage'} = "lower(t.taxon_display_name) like '%cyanophage%' or lower(t.taxon_display_name) like '%prochlorococcus phage%' or lower(t.taxon_display_name) like '%synechococcus phage%'";
    $e->{member_conds} = \%conds;

    $e->{img_group_id} = 26;

    return $e;
}

sub dispatch {
    my $page = param('page');
    my $class = param("class");

    if($page eq 'genomeList') {
        printGenomes();
    } elsif ( $page eq "googlemap" ) { 
	   my $new_url = $section_cgi;
	   HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       googleMap_new($class, $new_url);
       HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "depthecotypemap" ) { 
	   my $new_url = $section_cgi;
       HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       depthEcotypeMap($class, $new_url);
       HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "depthclademap" ) { 
	   my $new_url = $section_cgi;
       HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       depthCladeMap($class, $new_url);
       HtmlUtil::cgiCacheStop();

    }  elsif($page eq 'kentesthomepage') {
         my $template = HTML::Template->new( filename => "$base_dir/homepage.html" );
         $template->param( base_url => $base_url );
         print $template->output;
    
    }  elsif($page eq 'kentestdiv') {
      
        print "done loading....<br>";


    } elsif ( $page eq "datatypegraph" ) { 
	   my $new_url = $section_cgi;
       HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       dataTypeGraph($new_url);
       HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "depthgraph" ) { 
	   my $new_url = $section_cgi;
       HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       depthGraph($new_url);
       HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "cladegraph" ) { 
	   my $new_url = $section_cgi;
       HtmlUtil::cgiCacheInitialize($page . "_" . $class);
       HtmlUtil::cgiCacheStart() or return;
       cladeGraph($new_url);
       HtmlUtil::cgiCacheStop();
    } 

}


##############################################################
# getDatamartStats: stats data
##############################################################
sub getDatamartStats { 
    my $dbh = dbLogin(); 
 
    my @color = ( "#ff99aa", "#ffcc00", "#99cc66", "#99ccff", "#ffdd99", "#bbbbbb" );
    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

    my %counts;
    my $total = 0;
    for my $x ( @$list ) {
	$counts{$x} = 0;
    }

    my $sql = "";
    for my $x ( @$list ) {
	if ( $sql ) {
	    $sql .= " union ";
	}
	$sql .= "select '" . $x .
	    "', t.taxon_oid, t.domain, t.taxon_display_name " .
	    "from taxon t " .
	    "where (" . $member_conds->{$x} . ") " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes'";
    }
 
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $class, $taxon_oid, $domain, $name ) = $cur->fetchrow(); 
        last if ( !$taxon_oid ); 

	$counts{$class} += 1;
	$total += 1;
    } 
    $cur->finish(); 
 
 
    my $str; 
    my $i               = 0; 
    foreach my $x (@$list) { 
        my $cnt = $counts{$x}; 
	my $name = $member_labels->{$x};
        my $tmp = $i % 6;    # for 6 possible colors
 
        my $url = "main.cgi?section=ProPortal&page=genomeList&class=$x"; 
        $url = alink($url, $cnt); 
        $str .= qq{<tr bgcolor=$color[$tmp]><td>$name</td><td align='right'>$url</td></tr> }; 
        $i++; 
    } 

    my $url = "main.cgi?section=ProPortal&page=genomeList&class=datamart"; 
    $url = alink($url, $total); 
    $str .= qq{<tr><td>Total Datasets</td><td align='right'>$url</td></tr> }; 
    return $str;
} 


###############################################################
# printAboutNews
###############################################################
sub printAboutNews {
    print "<p>\n";
    print "<fieldset class='aboutPortal' id='about_proportal'>\n";
    print qq{
        <legend class='aboutLegend'>About IMG/ProPortal</legend>
        The marine cyanobacterium <b><i>Prochlorococcus</i></b>, 
        which is abundant in the oceans, is a key model system in 
        microbial ecology. 
        <b>IMG/ProMod</b> provides <i>Prochlorococcus</i> and its closely
        related <i>Synechococcus</i> and <i>Cyanophage</i> genomes 
        integrated with a comprehensive set of  publicly 
        available isolate and single cell genomes, and a rich set 
        of publicly available metagenome samples. 
        <b>IMG/ProMod</b>  includes genomic, transcriptomic, 

        metagenomic and population data from both 
        cultivated strains and wild populations of cyanobacteria 
        and phage.<br> 
        <b>IMG/ProPortal</b> relies on IMG's data warehouse 
        and comparative analysis tools 
       (<a href='http://nar.oxfordjournals.org/content/42/D1/D560'>Nucleic Acids Research, Volume 42 Issue D1</a>) 
       and  is a descendant of <b>ProPortal</b>  
       (<a href='http://nar.oxfordjournals.org/content/40/D1/D632'>Nucleic Acids Research Volume 40 Issue D1</a>).
       </fieldset> 
    };

#    print qq{
#    <fieldset class='newsPortal'>
#    <legend class='aboutLegend'>News</legend>
#    <div id='news_proportal'> </div>
#    </fieldset>
#    };

    my $news = getNewsContents();
    print qq{
    <fieldset class='newsPortal'>
    <legend class='aboutLegend'>News</legend>
    <div id='news'> $news </div>
    </fieldset>
    };
}


############################################################
# getNewsContents
############################################################
sub getNewsContents {
    my $dbh = dbLogin();

    my $e = getDatamartEnv();
    my $group_id = $e->{img_group_id};
    if ( ! $group_id ) {
	$group_id = 0;
    }

    my $contact_oid = WebUtil::getContactOid(); 
    if ( ! $contact_oid ) {
	return "No News.";
    }

    my $super_user_flag = WebUtil::getSuperUser();
    my $sql = "select role from contact_img_groups\@imgsg_dev where contact_oid = ? and img_group = ? "; 

    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id ); 
    my ( $role ) = $cur->fetchrow(); 
    $cur->finish();

    my $cond = "and n.is_public = 'Yes'";
    if ( $super_user_flag eq 'Yes' || $role ) {
	# no condition
	$cond = "";
    }

    my $str = "";
    $sql = "select n.news_id, n.title, n.add_date " .
	"from img_group_news\@imgsg_dev n " .
	"where n.group_id = ? " . $cond .
	" order by 3 desc ";
    $cur = execSql( $dbh, $sql, $verbose, $group_id ); 
    for (;; ) {
	my ( $news_id, $title, $add_date ) = $cur->fetchrow(); 
	last if ! $news_id;

	my $url2 = "main.cgi?section=ImgGroup" .
	    "&page=showNewsDetail" . 
            "&group_id=$group_id&news_id=$news_id"; 
	if ( ! $str ) {
	    $str = "<ul>";
	}
	$str .= "<li>" . alink($url2, $title, '_blank') . " ($add_date) </li>\n";
    }
    $cur->finish();

    if ( $str ) {
	$str .= "</ul>";
    }
    else {
	$str = "No News.";
    }

    return $str;
}


###############################################################
# printGenomes: print genome list based on 'class'
###############################################################
sub printGenomes {
    my $class = param('class');

    my $additional_cond = ' ';
    my $include_min_depth = 0;
    my $include_max_depth = 1;

    my $genome_type = param('genome_type');
    if ( $genome_type ) {
	$genome_type =~ s/'/''/g;   # replace ' with ''
	$additional_cond .= " and t.genome_type = '$genome_type' ";
    }

    my $depth = param('depth');
    if ( length($depth) > 0 && isNumber($depth) ) {
	$depth =~ s/'/''/g;   # replace ' with ''
	my $depth_set = "('" . $depth . "m', '" . $depth . " m', '" .
	    $depth . " meters', '" . $depth . " meter'" . ")";
	$additional_cond .= " and t.sequencing_gold_id in (select p.gold_id from gold_sequencing_project\@imgsg_dev p where p.depth in $depth_set ) ";
    }
    my $min_depth = param('min_depth');
    my $max_depth = param('max_depth');
    my $ecotype = param('ecotype');
    if ( $ecotype eq 'H' ) {
	$ecotype = 'High light adapted (HL)';
    }
    elsif ( $ecotype eq 'L' ) {
	$ecotype = 'Low light adapted (LL)';
    }
    elsif ( $ecotype eq 'U' ) {
	$ecotype = 'Unknown';
    }
    my $clade = param('clade');

    WebUtil::printMainForm();
    if ( length($min_depth) > 0 || $max_depth ) {
	if ( $max_depth && ! $min_depth ) {
	    $min_depth = 0;
	}
	print "<h3>Depth: $min_depth";
	if ( ! $include_min_depth && $min_depth > 0 ) {
	    print "+";
	}
	if ( $max_depth ) {
	    if ( $include_max_depth ) {
		print " to " . $max_depth;
	    }
	    else {
		print " to <" . $max_depth;
	    }
	}
	print " m</h3>\n";
    }
    if ( length($depth) > 0 ) {
	print "<h3>Depth: $depth m</h3>\n";
    }
    if ( $ecotype ) {
	print "<h3>Ecotype: $ecotype</h3>\n";
    }
    if ( $clade ) {
	if ( $clade eq 'NA' ) {
	    print "<h3>Clade: NA (Not Available)</h3>\n";
	}
	else {
	    print "<h3>Clade: $clade</h3>\n";
	}
    }

    my $sql;
    my $e = getDatamartEnv();
    my $title = "";
    my $member_labels = $e->{member_labels};

    my @list = ();
    if ( $class eq 'datamart' ) {
	$title = "All " . $e->{main_label} . " Genome List";
	my $members = $e->{members};
	for my $x ( @$members ) {
	    push @list, ( $x );
	}
    }
    elsif ( $class eq 'marine_metagenome' ) {
	print "<h3>Marine Metagenome</h3>\n";
	$additional_cond .= " and t.genome_type = 'metagenome' and t.ir_order = 'Marine'";
    }
    elsif ( $class eq 'marine_other' ) {
	print "<h3>Other</h3>\n";
	$additional_cond .= " and t.genome_type = 'isolate' and t.sequencing_gold_id in (select gold_id from gold_sequencing_project\@imgsg_dev where ecosystem_type = 'Marine')";
    }
    elsif ( $class eq 'marine_all' ) {
	print "<h3>Marine Genomes and Metagenomes</h3>\n";
	$additional_cond .= " and t.sequencing_gold_id in (select gold_id from gold_sequencing_project\@imgsg_dev where ecosystem_type = 'Marine')";
    }
    else {
	print "<h3>" . $member_labels->{$class} . "</h3>\n";
	$title = $member_labels->{$class} . " Genome List";
	push @list, ( $class );
    }

    ## ecosystem subtype?
    my $ecosystem_subtype = param('ecosystem_subtype');
    if ( $ecosystem_subtype ) {
	print "<h3>Ecosystem Subtype: $ecosystem_subtype</h3>\n";
	my $db_subtype = $ecosystem_subtype;
	$db_subtype =~ s/'/''/g;   # replace ' with ''
	if ( lc($ecosystem_subtype) eq 'unclassified' ) {
	    $additional_cond .= " and t.sequencing_gold_id in (select p.gold_id from gold_sequencing_project\@imgsg_dev p where p.ecosystem_subtype is null or lower(p.ecosystem_subtype) = '" . lc($db_subtype) . "')";
	}
	else {
	    $additional_cond .= " and t.sequencing_gold_id in (select p.gold_id from gold_sequencing_project\@imgsg_dev p where p.ecosystem_subtype = '" .
		$db_subtype . "')";
	}
    }

    my $sql1 = "select t.taxon_oid, t.taxon_display_name, t.genus from taxon t " .
	"where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    if ( length($min_depth) > 0 || $max_depth || $ecotype || $clade ) {
	$sql1 = "select t.taxon_oid, t.taxon_display_name, t.genus, " .
	    "p.ecotype, p.depth, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and t.sequencing_gold_id = p.gold_id ";
    }

    my $member_conds = $e->{member_conds};
    for my $x ( @list ) {
	if ( $sql ) {
	    $sql .= " union ";
	}
	if ( $member_conds->{$x} ) {
	    $sql .= $sql1 .
		"and (" . $member_conds->{$x} . ") " .
		$additional_cond;
	}
	else {
	    $sql .= $sql1 . $additional_cond;
	}
    }

    if ( scalar(@list) == 0 &&
	 ($class eq 'marine_metagenome' || $class eq 'marine_other' ||
	 $class eq 'marine_all' )) {
	$sql = $sql1 . $additional_cond;
    }
	     
##    print "<p>SQL: $sql\n";
    if ( ! $sql ) {
	return;
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    my @taxon_list = ();
    my $cnt2 = 0;
    for (;;) {
	my ($taxon_oid, $taxon_name, $genus,
	    $eco_val, $depth_val, $clade_val) 
	    = $cur->fetchrow();
	last if ! $taxon_oid;

	## check ecotype
	if ( $ecotype ) {
	    if ( $ecotype eq 'Unknown' ) {
		if ( $eco_val ) {
		    next;
		}
	    }
	    else {
		if ( $eco_val ne $ecotype ) {
		    next;
		}
	    }
	}

	## check clade
	if ( $clade ) {
	    if ( $clade eq 'Unknown' || $clade eq 'NA' ) {
		if ( $clade_val ) {
		    next;
		}
	    }
	    else {
		if ( $clade =~ /^5/ ) {
		    if ( ! ($clade_val =~ /$clade/) ) {
			next;
		    }
		}
		elsif ( $clade_val ne $clade ) {
		    next;
		}
	    }
	}
	    
	# check depth
	if ( $min_depth || $max_depth ) {
	    if ( ! defined($depth_val) || length($depth_val) == 0 ) {
		next;
	    }
	    my $depth2 = convertDepth($depth_val);
	    if ( length($depth2) == 0 ) {
		next;
	    }
	    if ( $min_depth ) {
		if ( $depth2 < $min_depth ) {
		    next;
		}
		if ( ! $include_min_depth && $depth2 <= $min_depth ) {
		    next;
		}
	    }
	    if ( $max_depth ) {
		if ( $depth2 > $max_depth ) {
		    next;
		}
		if ( ! $include_max_depth && $depth2 >= $max_depth ) {
		    next;
		}
	    }
	}

	## check for others
	if ( $class eq 'marine_other' ) {
	    if ( lc($genus) =~ /prochlorococcus/ ) {
		next;
	    }
	    if ( lc($genus) =~ /synechococcus/ ) {
		next;
	    }
	    if ( lc($taxon_name) =~ /cyanophage/ ) {
		next;
	    }
	    if ( lc($taxon_name) =~ /prochlorococcus phage/ ) {
		next;
	    }
	    if ( lc($taxon_name) =~ /synechococcus phage/ ) {
		next;
	    }
	}

	push @taxon_list, ( $taxon_oid );
	$cnt2++;
    }
    $cur->finish();

    GenomeList::printGenomesViaList( \@taxon_list, '', '' );
    printStatusLine( "$cnt2 Loaded", 2 );
}


#####################################################################
# show datasets on Google Map
#####################################################################
sub googleMap_new {
    my ($class, $new_url) = @_;


    if ( ! $class ) {
	$class = param('class');
    }

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

##    print "<h1>IMG Projects Map</h1>";

    $new_url = $section_cgi;

print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('googlemap', $class, $new_url);

    my @members = ();
    for my $x ( @$list ) {
	if ( $class && $x eq $class ) {
	    @members = ( $x );
	    last;
	}
	push @members, ( $x );
    }

    # get total count
    printStatusLine("Loading ...");
    my $dbh = dbLogin();

    my $sql = "";
    if ( $class eq 'all' ) {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    else {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") ";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $genome_cnt ) = $cur->fetchrow();
    $cur->finish();

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude\t$depth"
    # only public genomes
    if ( $class eq 'all' ) {
	$sql = "select t.taxon_oid, t.taxon_display_name, " .
	    "p.geo_location, p.latitude, p.longitude, " .
	    "p.altitude, p.depth, t.domain, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and p.latitude is not null and p.longitude is not null ";
    }
    else {
	$sql = "select t.taxon_oid, t.taxon_display_name, " .
	    "p.geo_location, p.latitude, p.longitude, " .
	    "p.altitude, p.depth, t.domain, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and p.latitude is not null and p.longitude is not null ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") and t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    $sql .= " order by 4, 5, 2";

    ### prepare data to be mapped
    my @recsToDisplay = ();
    $cur = execSql( $dbh, $sql, $verbose );
    my $cnt2 = 0;
    for ( ; ; ) {
	my ( $taxon_oid, @rest ) = $cur->fetchrow();
	last if ! $taxon_oid;

	my $line = $taxon_oid . "\t" . join("\t", @rest);
	push( @recsToDisplay, $line );
	$cnt2++;
	if ( $cnt2 > 100000 ) {
	    last;
	}
    }
    $cur->finish();

    my $gmapkey = getGoogleMapsKey();

    my $g_url = "main.cgi?section=ProPortal&page=genomeList&class=$class"; 
    $g_url = alink($g_url, $genome_cnt); 

    print qq{
        <p>
        There are $g_url public genomes;
        $cnt2 projects displayed.
        Only public projects that have longitude/latitude coordinates in 
        GOLD are displayed on this map.
        Some projects maybe rejected via Google Maps because of bad location coordinates. 
        Map pins represent location counts. Some pins may have multiple genomes.
        </p>
        };

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    print <<EOF;
<link href="https://code.google.com/apis/maps/documentation/javascript/examples/default.css" rel="stylesheet" type="text/css" />
<script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
<script type="text/javascript" src="$base_url/proportalmap.js"></script>
<script type="text/javascript" src="$base_url/markerclusterer.js"></script>

    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Sample Location</legend>
    <div id="map_canvas" style="width: 560px; height: 420px; position: relative;"></div>            
    </fieldset>       
    <script type="text/javascript">
        var map = createMap(2, 0, 0);    
EOF

    my $last_lat  = "";
    my $last_lon  = "";
    my $last_name = "";
    my $info      = "";
    my $customData = "";

    my $count_mappedSuccessfully = 0;
    my $count_rejected           = 0;

    my $recsToDisplay_aref = \@recsToDisplay;
    foreach my $line (@$recsToDisplay_aref) {
        my ( $taxon_oid, $name, $geo_location, $latitude, 
	     $longitude, $altitude, $depth, $domain, $clade ) =
		 split( /\t/, $line );
	$domain = substr($domain, 0, 1);
        $name = "[" . $domain . "] " . escapeHTML($name);
        my $tmp_geo_location = escHtml($geo_location);
###        my $tmp_altitude     = escHtml($altitude);
        my $tmp_altitude     = escHtml($depth);

	$longitude  = convertLatLong($longitude);
	$latitude = convertLatLong($latitude);

        # add geo location check too ? maybe not
        if ( ( $last_lat ne $latitude ) || ( $last_lon ne $longitude ) ) {
            if ( $info ne "" ) {

                # clean lat and long remove " ' , etc
                my $clat  = convertLatLong($last_lat);
                my $clong = convertLatLong($last_lon);

		if ( ! $customData ) {
		    $customData = "No data available";
		}

                print qq{
                    var contentString = "$info </div>";
                    var myData = "$customData";
                    addMarker(map, $clat, $clong, '$last_name', contentString, myData);
                };
                $count_mappedSuccessfully++;
            }

            # new point
            $info = "";
	    $customData = "";

            # clean lat and long remove " ' , etc
            my $clat  = convertLatLong($latitude);
            my $clong = convertLatLong($longitude);

            # some data is a space not a null
            if ( $clat eq "" || $clong eq "" ) {

                next;
            }

            $info = "<h1>$tmp_geo_location</h1> <div>$latitude, $longitude<br/>$tmp_altitude";
            $info .= "<br/><a href='$url$taxon_oid'>$name</a>";

            $customData = "<h1>$tmp_geo_location</h1> <div>$latitude, $longitude<br/>$tmp_altitude";
	    $customData .= "<h3>Ecological Data About Location</h3>";
	    $customData .= "(data not available ...)<br/>";

###	    my $alt2 = strTrim($altitude);
	    my $alt2 = strTrim($depth);
	    if ( ! $alt2 || blankStr($alt2) ) {
		$alt2 = "not available";
	    }

	    if ( $clade ) {
		$clade = " (" . $clade . ")";
	    }

	    my $url2 = $main_cgi . "?section=TaxonDetail&page=taxonDetail" .
		"&taxon_oid=" . $taxon_oid;
	    my $div_name = "t" . $taxon_oid;
            $customData .= "<br/>" .
		"<div id='$div_name' style='cursor:pointer;' " .
		"onclick=window.open('" . $url2 . "')" .
		"><u>" . $name . "</u>" .
#		"<a href='$url$taxon_oid'>$name</a>" .
###		" (Altitude: $alt2)</div>";
		" (Depth: $alt2)$clade</div>";
        } else {
            $info .= "<br/><a href='$url$taxon_oid'>$name</a>";
###	    my $alt2 = strTrim($altitude);
	    my $alt2 = strTrim($depth);
	    if ( ! $alt2 || blankStr($alt2) ) {
		$alt2 = "not available";
	    }
	    my $url2 = $main_cgi . "?section=TaxonDetail&page=taxonDetail" .
		"&taxon_oid=" . $taxon_oid;
	    my $div_name = "t" . $taxon_oid;

	    if ( $clade ) {
		$clade = " (" . $clade . ")";
	    }

            $customData .= "<br/>" .
		"<div id='$div_name' style='cursor:pointer;' " .
		"onclick=window.open('" . $url2 . "')" .
		"><u>" . $name . "</u>" .
#		"<a href='$url$taxon_oid'>$name</a>" .
###		" (Altitude: $alt2)</div>";
		" (Depth: $alt2)$clade</div>";
        }
        $last_lat = $latitude;
        $last_lon = $longitude;

        # $last_name = CGI::escape($name);
        $last_name = $name;
    }

    # last recrod
    if ( $#$recsToDisplay_aref > -1 && $info ne "" ) {
        my $clat  = convertLatLong($last_lat);
        my $clong = convertLatLong($last_lon);
        if ( $clat eq "" || $clong eq "" ) {

        } else {
	    if ( ! $customData ) {
		$customData = "No data available";
	    }

            print qq{
                var contentString = "$info";
                var myData = "$customData";
                addMarker(map, $clat, $clong, '$last_name', contentString, myData);
            };
            $count_mappedSuccessfully++;
        }
    }

    # finish map
    print qq{ 
        cluster(map);
        </script>  
    };

    print qq{
        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Sample Information</legend>
        <div id="detail_info_div" contenteditable="true">
        You can click on a marker to show detailed information ...
        </div></fieldset>
    };

    # no points to point
    if ( $#$recsToDisplay_aref < 0 ) {
        printStatusLine( "0 Locations", 2 );
    } else {
        printStatusLine( "$count_mappedSuccessfully Locations", 2 );
    }

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#####################################################################
# show datasets on Depth Heat Map (using ecotype)
#####################################################################
sub depthEcotypeMap {
    my ($class, $new_url) = @_;

#    print qq{
#        <div id="depthMap">
#    }; 

    if ( ! $class ) {
	$class = param('class');
    }

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

##    print "<h1>IMG Projects Map</h1>";
print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('depthecotypemap', $class, $new_url);

    my @members = ();
    for my $x ( @$list ) {
	if ( $class && $x eq $class ) {
	    @members = ( $x );
	    last;
	}
	push @members, ( $x );
    }

    # get total count
    printStatusLine("Loading ...");
    my $dbh = dbLogin();

    my $sql = "";
    if ( $class eq 'all' ) {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    else {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") ";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $genome_cnt ) = $cur->fetchrow();
    $cur->finish();

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude\t$depth"
    # only public genomes
    if ( $class eq 'all' ) {
	$sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, p.ecotype " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and p.depth is not null ";
    }
    else {
	$sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, p.ecotype " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and p.depth is not null ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") and t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    $sql .= " order by 4, 5, 2";

    ### prepare data to be mapped
    my $min_depth = 0;
    my $max_depth = 200;
    my $bucket = 8;
    my $step_depth = ceil($max_depth / $bucket);
    my @key_list = ();
    my %key_min;
    my %key_max;
    my $n = 0;
    my $lo = 0;
    while ( $n < $bucket ) {
	my $hi = $lo + $step_depth;
	my $key = $lo . " to <" . $hi . " m";
	push @key_list, ( $key );
	$key_min{$key} = $lo;
	$key_max{$key} = $hi;
	$n++;
	$lo = $hi;
    }

    my @recsToDisplay = ();
    my %depth_h;
    my %iso_depth_h;
    my %iso_detail_h;
    my %meta_depth_h;
    my %meta_detail_h;
    my %ecotype_h;
    my $unclassified = 0;
    my $iso_unclassified = 0;
    my $meta_unclassified = 0;
    $cur = execSql( $dbh, $sql, $verbose );
    my $cnt2 = 0;
    for ( ; ; ) {
	my ( $taxon_oid, @rest ) = $cur->fetchrow();
	last if ! $taxon_oid;

	my $line = $taxon_oid . "\t" . join("\t", @rest);
	push( @recsToDisplay, $line );

	my $genome_type = $rest[1];
	my $original_depth = $rest[-2];
	my $depth = convertDepth($original_depth);
	my $ecotype = $rest[-1];
	if ( ! $ecotype ) {
	    $ecotype = 'Unknown';
	}

	if ( $ecotype_h{$ecotype} ) {
	    $ecotype_h{$ecotype} += 1;
	}
	else {
	    $ecotype_h{$ecotype} = 1;
	}

	if ( length($depth) == 0 ) {
	    $unclassified += 1;
	    if ( $genome_type eq 'isolate' ) {
		$iso_unclassified += 1;
	    }
	    else {
		$meta_unclassified += 1;
	    }
	    next;
	}

	## determine which range
	my $depth_key = "";
	for my $k2 ( @key_list ) {
	    if ( $depth >= $key_min{$k2} && $depth < $key_max{$k2} ) {
		$depth_key = $k2;
		last;
	    }
	}
	
	if ( $depth_h{$depth_key} ) {
	    my $href = $depth_h{$depth_key};
	    if ( $href->{$ecotype} ) {
		$href->{$ecotype} += 1;
	    }
	    else {
		$href->{$ecotype} = 1;
	    }
	}
	else {
	    my %h2;
	    $h2{$ecotype} = 1;
	    $depth_h{$depth_key} = \%h2;
	}

	if ( $genome_type eq 'isolate' ) {
	    if ( $iso_depth_h{$depth_key} ) {
		my $href = $iso_depth_h{$depth_key};
		if ( $href->{$ecotype} ) {
		    $href->{$ecotype} += 1;
		}
		else {
		    $href->{$ecotype} = 1;
		}
	    }
	    else {
		my %h2;
		$h2{$ecotype} = 1;
		$iso_depth_h{$depth_key} = \%h2;
	    }

	    if ( $iso_detail_h{$depth_key} ) {
		my $href = $iso_detail_h{$depth_key};
		if ( $href->{$ecotype} ) {
		    $href->{$ecotype} .= "\t" . $depth;
		}
		else {
		    $href->{$ecotype} = $depth;
		}
	    }
	    else {
		my %h2;
		$h2{$ecotype} = $depth;
		$iso_detail_h{$depth_key} = \%h2;
	    }
	}
	elsif ( $genome_type eq 'metagenome' ) {
	    if ( $meta_depth_h{$depth_key} ) {
		my $href = $meta_depth_h{$depth_key};
		if ( $href->{$ecotype} ) {
		    $href->{$ecotype} += 1;
		}
		else {
		    $href->{$ecotype} = 1;
		}
	    }
	    else {
		my %h2;
		$h2{$ecotype} = 1;
		$meta_depth_h{$depth_key} = \%h2;
	    }

	    if ( $meta_detail_h{$depth_key} ) {
		my $href = $meta_detail_h{$depth_key};
		if ( $href->{$ecotype} ) {
		    $href->{$ecotype} .= "\t" . $depth;
		}
		else {
		    $href->{$ecotype} = $depth;
		}
	    }
	    else {
		my %h2;
		$h2{$ecotype} = $depth;
		$meta_detail_h{$depth_key} = \%h2;
	    }
	}

	$cnt2++;
	if ( $cnt2 > 100000 ) {
	    last;
	}
    }
    $cur->finish();

#    my $gmapkey = getGoogleMapsKey();

    my $g_url = "$main_cgi?section=ProPortal&page=genomeList&class=$class"; 
    $g_url = alink($g_url, $genome_cnt); 

    print qq{
        <p>
        There are $g_url public genomes;
        $cnt2 projects displayed.
        Only public projects that have depth
        from sea level to $max_depth m below (in meters) in 
        GOLD are displayed on this graph.
        </p>
        };

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $g_cnt_url = "$main_cgi?section=ProPortal&page=genomeList";
    if ( $class ) {
	$g_cnt_url .= "&class=$class";
    }

#    my $g_cnt_url = "https://img-stage.jgi-psf.org/cgi-bin/img_amy/main.cgi?section=FindGenomes&page=metadataCategoryOperationResults&altitude=";

##    my @key_list = sort { $a <=> $b }(keys %depth_h);
    my @eco_list = sort (keys %ecotype_h);

    my $num_row = scalar(@eco_list);
    if ( $num_row <= 0 ) {
	$num_row = 1;
    }
    my $dy = 22;
    my $y0 = 20;
    my $width = 560;
    my $height = $dy * (scalar(@key_list) / $num_row + 1) + $y0;
    if ( $height < 200 ) {
	$height = 200;
    }

    my $data = "";

    my $i = 0;
    my $j = 0;
    my $cnt2 = 0;
    my $max_val = 0;
    for my $k ( @key_list ) {
	my $depth_href = $depth_h{$k};
	if ( ! $depth_href ) {
	    next;
	}

	for my $m ( @eco_list ) {
	    if ( $data ) {
		$data .= ", ";
	    }
	    else {
		$data = "[";
	    }

	    my $combo_id = "$k ($m)";
	    my $combo_val = $depth_href->{$m};
	    if ( ! $combo_val ) {
		$combo_val = 0;
	    }

	    $data .= "{\"id\": \"" . $combo_id . "\", \"row\": $i, \"col\": $j, \"count\": " .
		$combo_val;

	    $data .= ", \"min_depth\": " . $key_min{$k};
	    $data .= ", \"max_depth\": " . $key_max{$k};
	    $data .= ", \"ecotype\": \"" . $m . "\"";
	    $data .= ", \"ecocode\": \"" . substr($m, 0, 1) . "\"";

	    if ( $iso_depth_h{$k} ) {
		if ( $iso_depth_h{$k}->{$m} ) {
		    $data .= ", \"iso_count\": " . $iso_depth_h{$k}->{$m};
		}
		else {
		    $data .= ", \"iso_count\": 0";
		}
	    }
	    else {
		$data .= ", \"iso_count\": 0";
	    }
	    if ( $iso_detail_h{$k} ) {
		if ( $iso_detail_h{$k}->{$m} ) {
		    my @vals = split(/\t/, $iso_detail_h{$k}->{$m});
		    my %val_h;
		    for my $v2 ( @vals ) {
			if ( $val_h{$v2} ) {
			    $val_h{$v2} += 1;
			}
			else {
			    $val_h{$v2} = 1;
			}
		    }
		    my $v_str = "";
		    for my $k (sort { $a <=> $b }(keys %val_h)) {
			if ( $v_str ) {
			    $v_str .= ", {\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
			else {
			    $v_str = "{\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
		    }
		    $data .= ", \"iso_detail\": [" . $v_str . "]";
		}
		else {
		    $data .= ", \"iso_detail\": []";
		}
	    }
	    else {
		$data .= ", \"iso_detail\": []";
	    }

	    if ( $meta_depth_h{$k} ) {
		if ( $meta_depth_h{$k}->{$m} ) {
		    $data .= ", \"meta_count\": " . $meta_depth_h{$k}->{$m};
		}
		else {
		    $data .= ", \"meta_count\": 0";
		}
	    }
	    else {
		$data .= ", \"meta_count\": 0";
	    }

	    if ( $meta_detail_h{$k} ) {
		if ( $meta_detail_h{$k}->{$m} ) {
		    my @vals = split(/\t/, $meta_detail_h{$k}->{$m});
		    my %val_h;
		    for my $v2 ( @vals ) {
			if ( $val_h{$v2} ) {
			    $val_h{$v2} += 1;
			}
			else {
			    $val_h{$v2} = 1;
			}
		    }
		    my $v_str = "";
		    for my $k (sort { $a <=> $b }(keys %val_h)) {
			if ( $v_str ) {
			    $v_str .= ", {\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
			else {
			    $v_str = "{\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
		    }
		    $data .= ", \"meta_detail\": [" . $v_str . "]";
		}
		else {
		    $data .= ", \"meta_detail\": []";
		}
	    }
	    else {
		$data .= ", \"meta_detail\": []";
	    }

	    $data .= "}";

	    if ( $combo_val > $max_val ) {
		$max_val = $combo_val;
	    }

	    $j++;
	    $cnt2++;
	    if ( $j >= $num_row ) {
		$j = 0;
		$i++;
	    }
	}
    }

    if ( $data ) {
	$data .= "]";
    }
    else {
	$data = "[{\"id\": \"No Data\", \"row\": 0, \"col\": 0, \"count\": " . "0}]";
    }

##    print "*** $data ***\n";

    print qq{
    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Depth &amp; Ecotype</legend>
      <div id='chart_div'>

    <script src='$base_url/d3.min.js'></script>
    <script>
    };

    print "    var data = " . $data . ";\n";
    print "    var top_label = ['" . join("', '", @eco_list) . "'];\n";
    print "    var left_label = ['" . join("', '", @key_list) . "'];\n";

    if ( $max_val < 1 ) {
	$max_val = 1;
    }

    print <<EOF;
var tooltip = d3.select("#chart_div")
    .append("div")
    .style("position", "absolute")  
    .style("z-index", "10")
    .style("visibility", "hidden")
    .style("border", "solid 1px #aaa")
    .style("background", "lightsteelblue")
    .html(function(d) {
        return "<b>a simple tooltip</b>";});                                               

var width = $width,
    height = $height,
    barHeight = 20,
    bar_x = 100,
    max_val = $max_val;

var max_n = $num_row;
var ratio = width / max_n;

var dx = (width - bar_x) / max_n;
var dy = $dy;
var y0 = $y0;
var genome_cnt_link = '$g_cnt_url';

var colors = [ "#E6F2E6", "#CCE6CC", "#B2D9B2", "#99CC99", "#80C080",
               "#66B366", "#4DA64D", "#339933", "#198D19", "#008000",
               "#007300", "#006600", "#005A00", "#004D00", "#004000",
               "#003300", "#002600" ];

var svg = d3.select("#chart_div").append("svg")
.attr("width", width)
    .attr("height", height);

var bars = svg.selectAll(".bar")
    .data(data)
    .enter()
    .append("rect")
    .attr("class", function(d, i) {return "bar " + d.id;})
    .attr("x", function(d, i) {return dx * d.col + bar_x - 10 ;})
    .attr("y", function(d, i) {return dy * d.row + y0 ;})
    .attr("width", function(d, i) {return dx - 1})
    .attr("height", dy - 1)
    .on("mouseover", function(d){
	if ( d.count > 0 ) {
	    return tooltip.style("visibility", "visible").html("genome:" + d.iso_count + "/metagenome: " + d.meta_count );
	}})
    .on("mousemove", function(){tooltip.style("cursor", "pointer").style("top",
              (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px");})     
    .on("mouseout", function(){return tooltip.style("visibility", "hidden");})
    .on("click", function(d, i) {
        var info_panel = document.getElementById("detail_info_div");
        var str1 =
	    "<div id='total_cnt' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + genome_cnt_link + "&min_depth=" + d.min_depth
	    + "&max_depth=" + d.max_depth
	    + "&metadata_col=p.depth"
	    + "&ecotype=" + d.ecocode
	    + "&metadata_col=p.ecotype"
	    + "')>" 
            + "<h3>Ecotype: " + d.ecotype + "</h3>"
            + "<h3>Depth: " + d.min_depth + " to <"
            + d.max_depth + " m</h3>" + "</div>";
	if ( d.iso_count > 0 ) {
	    str1 += "<div id='iso_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + "&genome_type=isolate"
		+ "&min_depth=" + d.min_depth
		+ "&max_depth=" + d.max_depth
		+ "&metadata_col=p.depth"
		+ "&ecotype=" + d.ecocode
		+ "&metadata_col=p.ecotype"
		+ "')>" 
		+ "<p>Genome: " 
		+ "<u>" + d.iso_count + "</u></div><ul>";
	    for (var i=0; i<d.iso_detail.length; i++) {
		var v1 = d.iso_detail[i];
		str1 += "<li>" 
		    + "<div id='iso_cnt_" + i
		    + "' style='cursor:pointer;' "
		    + "onclick=window.open('" 
		    + genome_cnt_link + "&genome_type=isolate"
		    + "&depth=" + v1.depth
		    + "&metadata_col=p.depth"
		    + "&ecotype=" + d.ecocode
		    + "&metadata_col=p.ecotype"
		    + "')>" + v1.depth + " m: <u>" 
		    + v1.count + "</u></div>"
		    + "</li>";
	    }
	    str1 += "</ul>";
	}
	else {
	    str1 += "<p>Genomes: " + d.iso_count;
	}
	if ( d.meta_count > 0 ) {
	    str1 += "<div id='meta_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + "&genome_type=metagenome"
		+ "&min_depth=" + d.min_depth
		+ "&max_depth=" + d.max_depth
		+ "&metadata_col=p.depth"
		+ "&ecotype=" + d.ecocode
		+ "&metadata_col=p.ecotype"
		+ "')>" 
		+ "<p>Metagenome: " 
		+ "<u>" + d.meta_count + "</u></div><ul>";
	    for (var i=0; i<d.meta_detail.length; i++) {
		var v1 = d.meta_detail[i];
		str1 += "<li>" 
		    + "<div id='meta_cnt_" + i
		    + "' style='cursor:pointer;' "
		    + "onclick=window.open('" 
		    + genome_cnt_link + "&genome_type=metagenome"
		    + "&depth=" + v1.depth
		    + "&metadata_col=p.depth"
		    + "&ecotype=" + d.ecocode
		    + "&metadata_col=p.ecotype"
		    + "')>" + v1.depth + " m: <u>" 
		    + v1.count + "</u></div>"
		    + "</li>";
	    }
	    str1 += "</ul>";
	}
	else {
	    str1 += "<p>Metagenomes: " + d.meta_count;
	}
        info_panel.innerHTML = str1;

        if ( d.count <= 0 ) {
	    info_panel.innerHTML = "No data available";
        }
      })
    .style("fill", function(d, i) {
	if ( d.count <= 0 ) {
	    return "#FFFFFF";
	}

        var c_tmp = Math.floor((d.count * 16) / max_val);
	if ( c_tmp > 16 ) {
	    c_tmp = 16;
	}
	if ( c_tmp < 0 ) {
	    c_tmp = 0;
	}
	return colors[c_tmp];
	});

var text0 = svg.selectAll("text0")
    .data(top_label)
    .enter()
    .append("text")
    .attr("x", function (d, i) { return dx * i + bar_x ; } )
    .attr("y", 10)
    .text( function(d) { return d ;});

var text1 = svg.selectAll("text1")
    .data(left_label)
    .enter()
    .append("text")
    .attr("x", 2)
    .attr("y", function (d, i) { return dy * i + 30 ; } )
    .attr("fill", '') 
    .text( function(d) { return d ;});

var text2 = svg.selectAll("text")
    .data(data)
    .enter()
    .append("text")
    .attr("class", function(d) {return "label " + d.id;})
    .attr("x", function (d) { return dx * d.col + bar_x ; } )
    .attr("y", function(d) {return dy * (d.row + 1) - 3 + y0 ;})
    .attr("fill", function(d) { 
        var c_tmp = Math.floor((d.count * 16) / max_val);
	if ( c_tmp > 7 ) { return "white"; }
        else { return "black"; } })
    .on("mousemove", function(d){
        if ( d.count > 0 ) { return this.style.cursor="pointer"; }})
    .on("click", function(d, i) {
        var info_panel = document.getElementById("detail_info_div");
        var str1 =
	    "<div id='total_cnt' style='cursor:pointer;' "
	    + "onclick=window.open('" 
            + genome_cnt_link + d.id
            + "')>" 
            + "<h4>Depth (in meters): " + d.id + ": "
            + "<u>" + d.count + "</u>"
            + "</h4>" + "</div>";
	if ( d.iso_count > 0 ) {
	    str1 += "<div id='iso_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + d.id + "&genome_type=isolate"
		+ "')>" 
		+ "<p>Genome: " 
		+ "<u>" + d.iso_count + "</u>"
		+ "</div>";
	}
	else {
	    str1 += "<p>Genomes: " + d.iso_count;
	}
	if ( d.meta_count > 0 ) {
	    str1 += "<div id='meta_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + d.id + "&genome_type=metagenome"
		+ "')>" 
		+ "<p>Metagenome: " 
		+ "<u>" + d.meta_count + "</u>"
		+ "</div>";
	}
	else {
	    str1 += "<p>Metagenomes: " + d.meta_count;
	}
        info_panel.innerHTML = str1;

        if ( d.count <= 0 ) {
	    info_panel.innerHTML = "No data available";
        }
      })
    .attr("font-size", "14px")
    .attr("style", "font-family: Sans-serif");

</script>
EOF
#    if ( $unclassified ) {
#	print "Unclassified: $unclassified\n";
#    }

    print "<script src='$base_url/overlib.js'></script>\n"; 
    my $text = "Examples: 10m, 10 m, 10 meters.";
    my $popup_header = "depth data format";

    my $info2 = 
        "onclick=\"return overlib('$text', " 
      . "RIGHT, STICKY, MOUSEOFF, "
      . "CAPTION, '$popup_header', "
      . "FGCOLOR, '#E0FFC2', "
      . "WIDTH, 200)\" " 
    . "onmouseout='return nd()' "; 

    print qq{
        </div>
</fieldset>

        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Ecotype</legend>
        <div id="detail_info_div" contenteditable="false">
        <b>Note: Only depth field values conform to specified
        <a $info2 style='cursor:pointer;'><u>formats</u></a>
        is used for range.</b>
        Depth is measured in meters.
        <p>You can click on a cell to show detailed information ...</p>
        </div>
        </fieldset>
    };

    printStatusLine( "$cnt2 Values", 2 );

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#####################################################################
# show datasets on Depth Heat Map (using clade)
#####################################################################
sub depthCladeMap {
    my ($class, $new_url) = @_;

#    print qq{
#        <div id="depthMap">
#    }; 

    if ( ! $class ) {
	$class = param('class');
    }

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

##    print "<h1>IMG Projects Map</h1>";
print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('depthclademap', $class, $new_url);

    my @members = ();
    for my $x ( @$list ) {
	if ( $class && $x eq $class ) {
	    @members = ( $x );
	    last;
	}
	push @members, ( $x );
    }

    # get total count
    printStatusLine("Loading ...");
    my $dbh = dbLogin();

    my $sql = "";
    if ( $class eq 'all' ) {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    else {
	$sql = "select count(*) from taxon t " .
	    "where t.obsolete_flag = 'No' and t.is_public = 'Yes' ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") ";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $genome_cnt ) = $cur->fetchrow();
    $cur->finish();

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude\t$depth"
    # only public genomes
    if ( $class eq 'all' ) {
	$sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and p.depth is not null ";
    }
    else {
	$sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and p.depth is not null ";

	my $is_first = 1;
	for my $x ( @members ) {
	    if ( $is_first ) {
		$sql .= " and ( ";
		$is_first = 0;
	    }
	    else {
		$sql .= " or ";
	    }
	    $sql .= $member_conds->{$x};
	}
	$sql .= ") and t.obsolete_flag = 'No' and t.is_public = 'Yes' ";
    }
    $sql .= " order by 4, 5, 2";

    ### prepare data to be mapped
    my $min_depth = 0;
    my $max_depth = 200;
    my $bucket = 8;
    my $step_depth = ceil($max_depth / $bucket);
    my @key_list = ();
    my %key_min;
    my %key_max;
    my $n = 0;
    my $lo = 0;
    while ( $n < $bucket ) {
	my $hi = $lo + $step_depth;
	my $key = $lo . " to <" . $hi . " m";
	push @key_list, ( $key );
	$key_min{$key} = $lo;
	$key_max{$key} = $hi;
	$n++;
	$lo = $hi;
    }

    my @recsToDisplay = ();
    my %depth_h;
    my %iso_depth_h;
    my %iso_detail_h;
    my %meta_depth_h;
    my %meta_detail_h;
    my %clade_h;
    my $unclassified = 0;
    my $iso_unclassified = 0;
    my $meta_unclassified = 0;
    $cur = execSql( $dbh, $sql, $verbose );
    my $cnt2 = 0;
    for ( ; ; ) {
	my ( $taxon_oid, @rest ) = $cur->fetchrow();
	last if ! $taxon_oid;

	my $line = $taxon_oid . "\t" . join("\t", @rest);
	push( @recsToDisplay, $line );

	my $genome_type = $rest[1];
	my $original_depth = $rest[-2];
	my $depth = convertDepth($original_depth);
	my $clade = $rest[-1];
	if ( ! $clade ) {
##	    $clade = 'Unknown';
	    $clade = 'NA';
	}

	if ( $clade_h{$clade} ) {
	    $clade_h{$clade} += 1;
	}
	else {
	    $clade_h{$clade} = 1;
	}

	if ( length($depth) == 0 ) {
	    $unclassified += 1;
	    if ( $genome_type eq 'isolate' ) {
		$iso_unclassified += 1;
	    }
	    else {
		$meta_unclassified += 1;
	    }
	    next;
	}

	## determine which range
	my $depth_key = "";
	for my $k2 ( @key_list ) {
	    if ( $depth >= $key_min{$k2} && $depth < $key_max{$k2} ) {
		$depth_key = $k2;
		last;
	    }
	}
	
	if ( $depth_h{$depth_key} ) {
	    my $href = $depth_h{$depth_key};
	    if ( $href->{$clade} ) {
		$href->{$clade} += 1;
	    }
	    else {
		$href->{$clade} = 1;
	    }
	}
	else {
	    my %h2;
	    $h2{$clade} = 1;
	    $depth_h{$depth_key} = \%h2;
	}

	if ( $genome_type eq 'isolate' ) {
	    if ( $iso_depth_h{$depth_key} ) {
		my $href = $iso_depth_h{$depth_key};
		if ( $href->{$clade} ) {
		    $href->{$clade} += 1;
		}
		else {
		    $href->{$clade} = 1;
		}
	    }
	    else {
		my %h2;
		$h2{$clade} = 1;
		$iso_depth_h{$depth_key} = \%h2;
	    }

	    if ( $iso_detail_h{$depth_key} ) {
		my $href = $iso_detail_h{$depth_key};
		if ( $href->{$clade} ) {
		    $href->{$clade} .= "\t" . $depth;
		}
		else {
		    $href->{$clade} = $depth;
		}
	    }
	    else {
		my %h2;
		$h2{$clade} = $depth;
		$iso_detail_h{$depth_key} = \%h2;
	    }
	}
	elsif ( $genome_type eq 'metagenome' ) {
	    if ( $meta_depth_h{$depth_key} ) {
		my $href = $meta_depth_h{$depth_key};
		if ( $href->{$clade} ) {
		    $href->{$clade} += 1;
		}
		else {
		    $href->{$clade} = 1;
		}
	    }
	    else {
		my %h2;
		$h2{$clade} = 1;
		$meta_depth_h{$depth_key} = \%h2;
	    }

	    if ( $meta_detail_h{$depth_key} ) {
		my $href = $meta_detail_h{$depth_key};
		if ( $href->{$clade} ) {
		    $href->{$clade} .= "\t" . $depth;
		}
		else {
		    $href->{$clade} = $depth;
		}
	    }
	    else {
		my %h2;
		$h2{$clade} = $depth;
		$meta_detail_h{$depth_key} = \%h2;
	    }
	}

	$cnt2++;
	if ( $cnt2 > 100000 ) {
	    last;
	}
    }
    $cur->finish();

#    my $gmapkey = getGoogleMapsKey();

    my $g_url = "$main_cgi?section=ProPortal&page=genomeList&class=$class"; 
    $g_url = alink($g_url, $genome_cnt); 

    print qq{
        <p>
        There are $g_url public genomes;
        $cnt2 projects displayed.
        Only public projects that have depth
        from sea level to $max_depth m below (in meters) in 
        GOLD are displayed on this graph.
        </p>
        };

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $g_cnt_url = "$main_cgi?section=ProPortal&page=genomeList";
    if ( $class ) {
	$g_cnt_url .= "&class=$class";
    }

#    my $g_cnt_url = "https://img-stage.jgi-psf.org/cgi-bin/img_amy/main.cgi?section=FindGenomes&page=metadataCategoryOperationResults&altitude=";

##    my @key_list = sort { $a <=> $b }(keys %depth_h);
    my @clade_list = sort (keys %clade_h);

    my $num_row = scalar(@clade_list);
    if ( $num_row <= 0 ) {
	$num_row = 1;
    }
    my $dy = 22;
    my $y0 = 25;
    my $width = 560;
    my $height = $dy * (scalar(@key_list) / $num_row + 1) + $y0;
    if ( $height < 200 ) {
	$height = 200;
    }

    my $data = "";

    my $i = 0;
    my $j = 0;
    my $cnt2 = 0;
    my $max_val = 0;
    for my $k ( @key_list ) {
	my $depth_href = $depth_h{$k};
	if ( ! $depth_href ) {
	    next;
	}

	for my $m ( @clade_list ) {
	    if ( $data ) {
		$data .= ", ";
	    }
	    else {
		$data = "[";
	    }

	    my $combo_id = "$k ($m)";
	    my $combo_val = $depth_href->{$m};
	    if ( ! $combo_val ) {
		$combo_val = 0;
	    }

	    $data .= "{\"id\": \"" . $combo_id . "\", \"row\": $i, \"col\": $j, \"count\": " .
		$combo_val;

	    $data .= ", \"min_depth\": " . $key_min{$k};
	    $data .= ", \"max_depth\": " . $key_max{$k};
	    $data .= ", \"clade\": \"" . $m . "\"";
	    my $clade_code = WebUtil::massageToUrl($m);
	    $data .= ", \"clade_code\": \"" . $clade_code . "\"";

	    if ( $iso_depth_h{$k} ) {
		if ( $iso_depth_h{$k}->{$m} ) {
		    $data .= ", \"iso_count\": " . $iso_depth_h{$k}->{$m};
		}
		else {
		    $data .= ", \"iso_count\": 0";
		}
	    }
	    else {
		$data .= ", \"iso_count\": 0";
	    }
	    if ( $iso_detail_h{$k} ) {
		if ( $iso_detail_h{$k}->{$m} ) {
		    my @vals = split(/\t/, $iso_detail_h{$k}->{$m});
		    my %val_h;
		    for my $v2 ( @vals ) {
			if ( $val_h{$v2} ) {
			    $val_h{$v2} += 1;
			}
			else {
			    $val_h{$v2} = 1;
			}
		    }
		    my $v_str = "";
		    for my $k (sort { $a <=> $b }(keys %val_h)) {
			if ( $v_str ) {
			    $v_str .= ", {\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
			else {
			    $v_str = "{\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
		    }
		    $data .= ", \"iso_detail\": [" . $v_str . "]";
		}
		else {
		    $data .= ", \"iso_detail\": []";
		}
	    }
	    else {
		$data .= ", \"iso_detail\": []";
	    }

	    if ( $meta_depth_h{$k} ) {
		if ( $meta_depth_h{$k}->{$m} ) {
		    $data .= ", \"meta_count\": " . $meta_depth_h{$k}->{$m};
		}
		else {
		    $data .= ", \"meta_count\": 0";
		}
	    }
	    else {
		$data .= ", \"meta_count\": 0";
	    }

	    if ( $meta_detail_h{$k} ) {
		if ( $meta_detail_h{$k}->{$m} ) {
		    my @vals = split(/\t/, $meta_detail_h{$k}->{$m});
		    my %val_h;
		    for my $v2 ( @vals ) {
			if ( $val_h{$v2} ) {
			    $val_h{$v2} += 1;
			}
			else {
			    $val_h{$v2} = 1;
			}
		    }
		    my $v_str = "";
		    for my $k (sort { $a <=> $b }(keys %val_h)) {
			if ( $v_str ) {
			    $v_str .= ", {\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
			else {
			    $v_str = "{\"depth\": $k, \"count\": " .
				$val_h{$k} . "}";
			}
		    }
		    $data .= ", \"meta_detail\": [" . $v_str . "]";
		}
		else {
		    $data .= ", \"meta_detail\": []";
		}
	    }
	    else {
		$data .= ", \"meta_detail\": []";
	    }

	    $data .= "}";

	    if ( $combo_val > $max_val ) {
		$max_val = $combo_val;
	    }

	    $j++;
	    $cnt2++;
	    if ( $j >= $num_row ) {
		$j = 0;
		$i++;
	    }
	}
    }

    if ( $data ) {
	$data .= "]";
    }
    else {
	$data = "[{\"id\": \"No Data\", \"row\": 0, \"col\": 0, \"count\": " . "0}]";
    }

##    print "*** $data ***\n";

    print qq{
    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Depth &amp; Clade</legend>
      <div id='chart_div'>

    <script src='$base_url/d3.min.js'></script>
    <script>
    };

    print "    var data = " . $data . ";\n";
    print "    var top_label = ['" . join("', '", @clade_list) . "'];\n";
    print "    var left_label = ['" . join("', '", @key_list) . "'];\n";

    if ( $max_val < 1 ) {
	$max_val = 1;
    }

    print <<EOF;
var tooltip = d3.select("#chart_div")
    .append("div")
    .style("position", "absolute")  
    .style("z-index", "10")
    .style("visibility", "hidden")
    .style("border", "solid 1px #aaa")
    .style("background", "lightsteelblue")
    .html(function(d) {
        return "<b>a simple tooltip</b>";});                                               

var width = $width,
    height = $height,
    barHeight = 20,
    bar_x = 100,
    max_val = $max_val;

var max_n = $num_row;
var ratio = width / max_n;

var dx = (width - bar_x) / max_n;
var dy = $dy;
var y0 = $y0;
var genome_cnt_link = '$g_cnt_url';

var colors = [ "#E6F2E6", "#CCE6CC", "#B2D9B2", "#99CC99", "#80C080",
               "#66B366", "#4DA64D", "#339933", "#198D19", "#008000",
               "#007300", "#006600", "#005A00", "#004D00", "#004000",
               "#003300", "#002600" ];

var svg = d3.select("#chart_div").append("svg")
.attr("width", width)
    .attr("height", height);

var bars = svg.selectAll(".bar")
    .data(data)
    .enter()
    .append("rect")
    .attr("class", function(d, i) {return "bar " + d.id;})
    .attr("x", function(d, i) {return dx * d.col + bar_x - 10 ;})
    .attr("y", function(d, i) {return dy * d.row + y0 ;})
    .attr("width", function(d, i) {return dx - 1})
    .attr("height", dy - 1)
    .on("mouseover", function(d){
	if ( d.count > 0 ) {
	    return tooltip.style("visibility", "visible").html("genome:" + d.iso_count + "/metagenome: " + d.meta_count );
	}})
    .on("mousemove", function(){tooltip.style("cursor", "pointer").style("top",
              (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px");})     
    .on("mouseout", function(){return tooltip.style("visibility", "hidden");})
    .on("click", function(d, i) {
        var info_panel = document.getElementById("detail_info_div");
        var str1 =
	    "<div id='total_cnt' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + genome_cnt_link + "&min_depth=" + d.min_depth
	    + "&max_depth=" + d.max_depth
	    + "&metadata_col=p.depth"
	    + "&clade=" + d.clade_code
	    + "&metadata_col=p.clade"
	    + "')>" 
            + "<h3>Clade: " + d.clade + "</h3>"
            + "<h3>Depth: " + d.min_depth + " to <"
            + d.max_depth + " m</h3>" + "</div>";
	if ( d.iso_count > 0 ) {
	    str1 += "<div id='iso_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + "&genome_type=isolate"
		+ "&min_depth=" + d.min_depth
		+ "&max_depth=" + d.max_depth
		+ "&metadata_col=p.depth"
		+ "&clade=" + d.clade_code
		+ "&metadata_col=p.clade"
		+ "')>" 
		+ "<p>Genome: " 
		+ "<u>" + d.iso_count + "</u></div><ul>";
	    for (var i=0; i<d.iso_detail.length; i++) {
		var v1 = d.iso_detail[i];
		str1 += "<li>" 
		    + "<div id='iso_cnt_" + i
		    + "' style='cursor:pointer;' "
		    + "onclick=window.open('" 
		    + genome_cnt_link + "&genome_type=isolate"
		    + "&depth=" + v1.depth
		    + "&metadata_col=p.depth"
		    + "&clade=" + d.clade_code
		    + "&metadata_col=p.clade"
		    + "')>" + v1.depth + " m: <u>" 
		    + v1.count + "</u></div>"
		    + "</li>";
	    }
	    str1 += "</ul>";
	}
	else {
	    str1 += "<p>Genomes: " + d.iso_count;
	}
	if ( d.meta_count > 0 ) {
	    str1 += "<div id='meta_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + "&genome_type=metagenome"
		+ "&min_depth=" + d.min_depth
		+ "&max_depth=" + d.max_depth
		+ "&metadata_col=p.depth"
		+ "&clade=" + d.clade_code
		+ "&metadata_col=p.clade"
		+ "')>" 
		+ "<p>Metagenome: " 
		+ "<u>" + d.meta_count + "</u></div><ul>";
	    for (var i=0; i<d.meta_detail.length; i++) {
		var v1 = d.meta_detail[i];
		str1 += "<li>" 
		    + "<div id='meta_cnt_" + i
		    + "' style='cursor:pointer;' "
		    + "onclick=window.open('" 
		    + genome_cnt_link + "&genome_type=metagenome"
		    + "&depth=" + v1.depth
		    + "&metadata_col=p.depth"
		    + "&clade=" + d.clade_code
		    + "&metadata_col=p.clade"
		    + "')>" + v1.depth + " m: <u>" 
		    + v1.count + "</u></div>"
		    + "</li>";
	    }
	    str1 += "</ul>";
	}
	else {
	    str1 += "<p>Metagenomes: " + d.meta_count;
	}
        info_panel.innerHTML = str1;

        if ( d.count <= 0 ) {
	    info_panel.innerHTML = "No data available";
        }
      })
    .style("fill", function(d, i) {
	if ( d.count <= 0 ) {
	    return "#FFFFFF";
	}

        var c_tmp = Math.floor((d.count * 16) / max_val);
	if ( c_tmp > 16 ) {
	    c_tmp = 16;
	}
	if ( c_tmp < 0 ) {
	    c_tmp = 0;
	}
	return colors[c_tmp];
	});

var text0 = svg.selectAll("text0")
    .data(top_label)
    .enter()
    .append("text")
    .attr("x", function (d, i) { return dx * i + bar_x - 10; } )
    .attr("y", function (d, i) {
	if ( dx > 80 ) {
	    return 15;
	}
	if ((i % 2) == 0) {
	    return 10;
	}
	else {
	    return 20;
	}
     } )
    .text( function(d) { return d ;});

var text1 = svg.selectAll("text1")
    .data(left_label)
    .enter()
    .append("text")
    .attr("x", 2)
    .attr("y", function (d, i) { return dy * i + 37 ; } )
    .attr("fill", '') 
    .text( function(d) { return d ;});

var text2 = svg.selectAll("text")
    .data(data)
    .enter()
    .append("text")
    .attr("class", function(d) {return "label " + d.id;})
    .attr("x", function (d) { return dx * d.col + bar_x ; } )
    .attr("y", function(d) {return dy * (d.row + 1) - 3 + y0 ;})
    .attr("fill", function(d) { 
        var c_tmp = Math.floor((d.count * 16) / max_val);
	if ( c_tmp > 7 ) { return "white"; }
        else { return "black"; } })
    .on("mousemove", function(d){
        if ( d.count > 0 ) { return this.style.cursor="pointer"; }})
    .on("click", function(d, i) {
        var info_panel = document.getElementById("detail_info_div");
        var str1 =
	    "<div id='total_cnt' style='cursor:pointer;' "
	    + "onclick=window.open('" 
            + genome_cnt_link + d.id
            + "')>" 
            + "<h4>Depth (in meters): " + d.id + ": "
            + "<u>" + d.count + "</u>"
            + "</h4>" + "</div>";
	if ( d.iso_count > 0 ) {
	    str1 += "<div id='iso_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + d.id + "&genome_type=isolate"
		+ "')>" 
		+ "<p>Genome: " 
		+ "<u>" + d.iso_count + "</u>"
		+ "</div>";
	}
	else {
	    str1 += "<p>Genomes: " + d.iso_count;
	}
	if ( d.meta_count > 0 ) {
	    str1 += "<div id='meta_cnt' style='cursor:pointer;' "
		+ "onclick=window.open('" 
		+ genome_cnt_link + d.id + "&genome_type=metagenome"
		+ "')>" 
		+ "<p>Metagenome: " 
		+ "<u>" + d.meta_count + "</u>"
		+ "</div>";
	}
	else {
	    str1 += "<p>Metagenomes: " + d.meta_count;
	}
        info_panel.innerHTML = str1;

        if ( d.count <= 0 ) {
	    info_panel.innerHTML = "No data available";
        }
      })
    .attr("font-size", "14px")
    .attr("style", "font-family: Sans-serif");

</script>
EOF
#    if ( $unclassified ) {
#	print "Unclassified: $unclassified\n";
#    }

    print "<script src='$base_url/overlib.js'></script>\n"; 
    my $text = "Examples: 10m, 10 m, 10 meters.";
    my $popup_header = "depth data format";

    my $info2 = 
        "onclick=\"return overlib('$text', " 
      . "RIGHT, STICKY, MOUSEOFF, "
      . "CAPTION, '$popup_header', "
      . "FGCOLOR, '#E0FFC2', "
      . "WIDTH, 200)\" " 
    . "onmouseout='return nd()' "; 

    print qq{
        </div>
</fieldset>

        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Clade</legend>
        <div id="detail_info_div" contenteditable="false">
        <b>Note: Only depth field values conform to specified
        <a $info2 style='cursor:pointer;'><u>formats</u></a>
        is used for range.</b>
        Depth is measured in meters.
        <p>You can click on a cell to show detailed information ...</p>
        </div>
        </fieldset>
    };

    printStatusLine( "$cnt2 Values", 2 );

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#####################################################################
# show Data Type Graph
#####################################################################
sub dataTypeGraph {
    my ($new_url) = @_;

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('datatypegraph', '', $new_url);

    my $dbh = dbLogin();
    my $sql = "";

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

    ## genomes
    my %counts;
    my $total = 0;
    for my $x ( @$list ) {
	$counts{$x} = 0;
    }

    my $sql = "";
    my %genome_h;
    for my $x ( @$list ) {
	my @arr = ();

	$sql = "select t.taxon_oid, t.taxon_display_name " .
	    "from taxon t " .
	    "where (" . $member_conds->{$x} . ") " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "order by 2";
 
	my $cur = execSql( $dbh, $sql, $verbose );
	for ( ; ; ) {
	    my ( $taxon_oid, $taxon_name ) = $cur->fetchrow(); 
	    last if ( !$taxon_oid ); 

	    my $t = $taxon_oid . "\t" . $taxon_name;
	    push @arr, ( $t );
	    $counts{$x} += 1;
	    $total += 1;
	} 
	$cur->finish(); 
	$genome_h{$x} = \@arr;
    }

    ## metagenomes
    my %metagenome_h;
    $sql = "select t.taxon_oid, t.taxon_display_name, t.family " .
	    "from taxon t " .
            "where t.genome_type = 'metagenome' " .
	    "and t.ir_order = 'Marine' " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and (t.combined_sample_flag is null or t.combined_sample_flag = 'No') " .
	    "order by 2";
 
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
	my ( $taxon_oid, $taxon_name, $family ) = $cur->fetchrow(); 
	last if ( !$taxon_oid ); 

	if ( ! $family ) {
	    $family = 'Unclassified';
	}

	my $t = $taxon_oid . "\t" . $taxon_name;
	$counts{$family} += 1;
	if ( $metagenome_h{$family} ) {
	    my $aref = $metagenome_h{$family};
	    push @$aref, ( $t );
	}
	else {
	    my @arr = ( $t );
	    $metagenome_h{$family} = \@arr;
	}
    }
    $cur->finish(); 

    print qq{
    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Data Type</legend>
      <div id='chart_div'>

<style>
<style type="text/css">

      .treeView{
        -moz-user-select:none;
        position:relative;
      }

      .treeView ul{
        margin:0 0 0 -1.5em;
        padding:0 0 0 1.5em;
      }

      .treeView li{
        margin:0;
        padding:0;
//        background:url('list-item-root.png') no-repeat top left;
        list-style-position:inside;
        list-style-image:url('button.png');
        cursor:auto;
      }

      .treeView li.collapsibleListOpen{
        list-style-image:url('$base_url/images/gray-plus.png');
        cursor:pointer;
      }

      .treeView li.collapsibleListClosed{
        list-style-image:url('$base_url/images/gray-minus.png');
        cursor:pointer;
      }

      .treeView li li{
        padding-left:1.5em;
      }

</style>

<script>var runOnLoad=function(c,o,d,e){function x(){for(e=1;c.length;)c.shift()()}o[d]?(document[d]('DOMContentLoaded',x,0),o[d]('load',x,0)):o.attachEvent('onload',x);return function(t){e?o.setTimeout(t,0):c.push(t)}}([],window,'addEventListener');</script>

<script src="/script/" async></script>
    <script src='$base_url/CollapsibleLists.js'></script>
    <script>
    };

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    print <<EOF;
runOnLoad(function(){ CollapsibleLists.apply(); });

</script>

   <div id="content">
      <ul class="treeView">
        <li>
          Genomes
          <ul class="collapsibleList">
EOF

    ## isolate
    for my $x ( @$list ) {
	my $label = $member_labels->{$x};
	my $count = $counts{$x};
	print "<li>" . $label . " ($count)<ul>\n";
	my $aref = $genome_h{$x};
	if ( $aref ) {
	    my $j = 0;
	    for my $y ( @$aref ) {
		my ($t_oid, $t_name) = split(/\t/, $y, 2);
		$j++;
		print "<li>" . alink($url . $t_oid, $t_name, '_blank') . 
		    "</li>\n";
	    }
	}
	print "</ul></li>\n";
    }

    print "</ul></li>\n";

    ## metagenome
    print "<li>Metagnomes\n";
    print "<ul class='collapsibleList'>\n";
    my @meta_list = sort (keys %metagenome_h);
    for my $x ( @meta_list ) {
	my $count = $counts{$x};
	print "<li>" . $x . " ($count)<ul>\n";
	my $aref = $metagenome_h{$x};
	if ( $aref ) {
	    my $j = 0;
	    for my $y ( @$aref ) {
		my ($t_oid, $t_name) = split(/\t/, $y, 2);
		$j++;
		print "<li>" . alink($url . $t_oid, $t_name, '_blank') . 
		    "</li>\n";
	    }
	}
	print "</ul></li>\n";
    }
    print "</ul></li>\n";

    ## others (for the future)
    print "<li>Gene Expression</li>\n";
    print "<li>Other?</li>\n";
    print "</ul></div>\n";


    ## information panel
    my $info_p = "<table class='img'>";
    my $g_cnt_url = "$main_cgi?section=ProPortal&page=genomeList";

    ## genome
    $info_p .= "<tr><th colspan='100%'>Genomes</th></tr>";
    for my $x ( @$list ) {
	my $label = $member_labels->{$x};
	my $count = $counts{$x};
	my $url2 = $g_cnt_url . "&class=$x";
	$info_p .= "<tr><td>" . $label . "</td><td align='right'>" . 
	    alink($url2, $count, '_blank') . "</td></tr>";
    }

    $info_p .= "<tr><th colspan='100%'><hr></th></tr>";

    ## metagenome
    $info_p .= "<tr><th colspan='100%'>Metagenomes</th></tr>";
    for my $x ( @meta_list ) {
	my $count = $counts{$x};
	my $url2 = $g_cnt_url . 
	    "&class=marine_metagenome&ecosystem_subtype=$x";
	$info_p .= "<tr><td>" . $x . "</td><td align='right'>" . 
	    alink($url2, $count, '_blank') . "</td></tr>";
    }

    $info_p .= "</table>";

    print qq{
        </div>
</fieldset>

        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Information</legend>
        <div id="detail_info_div" contenteditable="false">
        <p>The left panel lists public marine isolate genomes
        and metagenomes (excluding combined samples) in IMG. 
        Click on the list to expand.
        </p>
        $info_p
        </div>
        </fieldset>
    };

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#####################################################################
# show Depth Graph
#####################################################################
sub depthGraph {
    my ($new_url) = @_;

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('depthgraph', '', $new_url);

    printStatusLine("Loading ...");
    my $dbh = dbLogin();
    my $sql = "";

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude\t$depth"
    # only public marine prochlorococcus and synechococcus
    $sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, t.genus " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and p.ecosystem_type = 'Marine' " .
	    "and p.depth is not null ";
    $sql .= " order by 4, 5, 2";

    ### prepare data to be mapped
    my %depth_h;
    my %pro_h;
    my %syne_h;
    my %phage_h;
    my %meta_h;
    my %other_h;
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt2 = 0;
    my @recsToDisplay = ();
    for ( ; ; ) {
	my ( $taxon_oid, @rest ) = $cur->fetchrow();
	last if ! $taxon_oid;

	my $line = $taxon_oid . "\t" . join("\t", @rest);
	push( @recsToDisplay, $line );

	my $taxon_name = $rest[0];
	my $genome_type = $rest[1];
	my $original_depth = $rest[-2];
	my $depth = convertDepth($original_depth);
	my $genus = $rest[-1];

	if ( length($depth) <= 0 ) {
	    ## cannot interpret depth data
	    next;
	}

	my $scale = ceil($depth / 25);
	if ( $scale < 1 ) {
	    $scale = 1;
	}
	elsif ( $scale > 9 ) {
	    $scale = 9;
	}

	if ( $depth_h{$scale} ) {
	    $depth_h{$scale} += 1;
	}
	else {
	    $depth_h{$scale} = 1;
	}

	if ( $genome_type eq 'metagenome' ) {
	    # metagenome
	    if ( $meta_h{$scale} ) {
		$meta_h{$scale} += 1;
	    }
	    else {
		$meta_h{$scale} = 1;
	    }
	}
	elsif ( lc($genus) =~ /prochlorococcus/ ) {
	    if ( $pro_h{$scale} ) {
		$pro_h{$scale} += 1;
	    }
	    else {
		$pro_h{$scale} = 1;
	    }
	}
	elsif ( lc($genus) =~ /synechococcus/ ) {
	    if ( $syne_h{$scale} ) {
		$syne_h{$scale} += 1;
	    }
	    else {
		$syne_h{$scale} = 1;
	    }
	}
	elsif ( lc($taxon_name) =~ /cyanophage/ ||
		lc($taxon_name) =~ /prochlorococcus phage/ ||
		lc($taxon_name) =~ /synechococcus phage/ ) {
	    if ( $phage_h{$scale} ) {
		$phage_h{$scale} += 1;
	    }
	    else {
		$phage_h{$scale} = 1;
	    }
	}
	else {
	    # others
	    if ( $other_h{$scale} ) {
		$other_h{$scale} += 1;
	    }
	    else {
		$other_h{$scale} = 1;
	    }
	}

	$cnt2++;
	if ( $cnt2 > 100000 ) {
	    last;
	}
    }
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $g_cnt_url = "$main_cgi?section=ProPortal&page=genomeList";

    my @depth_list = ( '0 to 25m', '25+ to 50m', '50+ to 75 m',
		       '75+ to 100 m', '100+ to 125 m', '125+ to 150 m',
		       '150+ to 175 m', '175+ to 200 m', '200+ m' );
    my $data = "[ {\"id\": \"\", \"count\": 0}";
    my $max_val = 0;
    my $k = 0;
    for my $m ( @depth_list ) {
	my $min_range = $k * 25;
	$k++;
	my $max_range;
	if ( $k < scalar(@depth_list) ) {
	    $max_range = $k * 25;
	}
	my $val = $depth_h{$k};

	if ( ! $val ) {
	    $val = 0;
	}
	if ( $val > $max_val ) {
	    $max_val = $val;
	}

	$data .= ", {\"id\": \"" . $m . "\", \"count\": " . $val;
	$data .= ", \"min_depth\": $min_range";
	if ( $max_range ) {
	    $data .= ", \"max_depth\": $max_range";
	}

	if ( $val > 0 ) {
	    # add detail
	    if ( $pro_h{$k} ) {
		$data .= ", \"pro\": " . $pro_h{$k};
	    }
	    else {
		$data .= ", \"pro\": 0";
	    }
	    if ( $syne_h{$k} ) {
		$data .= ", \"syne\": " . $syne_h{$k};
	    }
	    else {
		$data .= ", \"syne\": 0";
	    }
	    if ( $phage_h{$k} ) {
		$data .= ", \"phage\": " . $phage_h{$k};
	    }
	    else {
		$data .= ", \"phage\": 0";
	    }
	    if ( $meta_h{$k} ) {
		$data .= ", \"meta\": " . $meta_h{$k};
	    }
	    else {
		$data .= ", \"meta\": 0";
	    }
	    if ( $other_h{$k} ) {
		$data .= ", \"other\": " . $other_h{$k};
	    }
	    else {
		$data .= ", \"other\": 0";
	    }
	}

	$data .= "}";
	$cnt2++;
    }

    $data .= "]";

##    print "<p>*** $data ***\n";

    if ( $max_val < 1 ) {
	$max_val = 1;
    }

    $max_val = ceil($max_val / 5) * 5 + 10;
    my $multi = 1.5;
    my $max_range = $max_val * $multi;

##    print "<p>max_val: $max_val, max_range: $max_range\n";

    print qq{
    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Depth</legend>
      <div id='chart_div'>

<style>
#xaxis .domain {
    fill:none;
    stroke:#000;
}
#xaxis text, #yaxis text {
    font-size: 12px;
}

#rectangle{
    width:12px;
    height:12px;
    background:blue;
}                
</style>

    <script src='$base_url/d3.min.js'></script>
    <script>
    };

    print "    var depth_list = [ ''";
    for my $m ( @depth_list ) {
	print ", '" . $m . "'";
    }
    print "];\n";
    print "    var data = " . $data . ";\n";

    print <<EOF;
var tooltip = d3.select("#chart_div")
    .append("div")
    .style("position", "absolute")  
    .style("z-index", "10")
    .style("visibility", "hidden")
    .style("border", "solid 1px #aaa")
    .style("background", "lightsteelblue")
    .html(function(d) {
        return "<b>a simple tooltip</b>";});

var max_val = $max_val,
    max_range = $max_range;

var max2 = 360;

var y0 = 10;
var genome_cnt_link = '$g_cnt_url';
var taxon_url = '$url';

// bar chart
    var color = d3.scale.category20();

    var grid = d3.range(25).map(function(i){
	return {'x1':0,'y1':0,'x2':0,'y2':max2};
				});

// tick values: 10, 20, 30 ...
    var tickVals = grid.map(function(d,i){
        return i*20;
    });

    var xscale = d3.scale.linear()
	.domain([0, max_val])
	.range([0, max_range]);

    var yscale = d3.scale.linear()
	.domain([0,depth_list.length])
	.range([0,max2]);

    var svg =  d3.select("#chart_div").append('svg')
	.attr({'width': 520, 'height':400});

    var grids = svg.append('g')
	.attr('id','grid')
	.attr('transform','translate(90,10)')
	.selectAll('line')
	.data(grid)
	.enter()
	.append('line')
	.attr({'x1':function(d,i){ return i*30; },
	       'y1':function(d){ return d.y1; },
	       'x2':function(d,i){ return i*30; },
	       'y2':function(d){ return d.y2; },
	      })
	.style({'stroke':'#adadad','stroke-width':'1px'});

    var xAxis = d3.svg.axis();
    xAxis
	.orient('bottom')
	.scale(xscale)
	.tickValues(tickVals);

    var yAxis = d3.svg.axis();
    yAxis
	.orient('left')
	.scale(yscale)
	.tickSize(2)
	.tickFormat(function(d,i){ return depth_list[i]; })
	.tickValues(d3.range(17));

    var y_xis = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','yaxis')
	.call(yAxis);

    var x_xis = svg.append('g')
	.attr("transform", "translate(90,360)")
	.attr('id','xaxis')
	.call(xAxis);

    // pro
    var chart = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','bars')
	.selectAll('rect')
	.data(data)
	.enter()
	.append('rect')
	.attr('height',19)
	.on("mouseover", function(d){ 
	    if ( d.pro > 0 ) { 
		return tooltip.style("visibility", "visible").html("prochlorococcus: " + d.pro ); 
	    }}) 
	.on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
									     (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px"); 
	    }) 
	.on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
        .on("click", function(d, i) { 
	    update_info(d); })
	.attr({'x':0,'y':function(d,i){ return yscale(i)-8; }})
	.style('fill',function(d,i){ return color(0); })
	.attr('width',function(d){ return xscale(d.pro); });

    // syne
    var chart2 = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','bars')
	.selectAll('rect')
	.data(data)
	.enter()
	.append('rect')
	.attr('height',19)
	.on("mouseover", function(d){ 
	    if ( d.syne > 0 ) { 
		return tooltip.style("visibility", "visible").html("synechococcus: " + d.syne ); 
	    }}) 
	.on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
									     (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px"); 
	    }) 
	.on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
        .on("click", function(d, i) { 
	    update_info(d); })
	.attr('x', function(d) { return xscale(d.pro); })
	.attr('y', function(d,i){ return yscale(i)-8; })
	.style('fill',function(d,i){ return color(1); })
	.attr('width',function(d){ return xscale(d.syne); });

    // phage
    var chart3 = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','bars')
	.selectAll('rect')
	.data(data)
	.enter()
	.append('rect')
	.attr('height',19)
	.on("mouseover", function(d){ 
	    if ( d.phage > 0 ) { 
		return tooltip.style("visibility", "visible").html("cyanophage: " + d.phage ); 
	    }}) 
	.on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
									     (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px"); 
	    }) 
	.on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
        .on("click", function(d, i) { 
	    update_info(d); })
	.attr('x', function(d) { return xscale(d.pro+d.syne); })
	.attr('y', function(d,i){ return yscale(i)-8; })
	.style('fill',function(d,i){ return color(2); })
	.attr('width',function(d){ return xscale(d.phage); });

    // meta
    var chart4 = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','bars')
	.selectAll('rect')
	.data(data)
	.enter()
	.append('rect')
	.attr('height',19)
	.on("mouseover", function(d){ 
	    if ( d.meta > 0 ) { 
		return tooltip.style("visibility", "visible").html("metagenome: " + d.meta ); 
	    }}) 
	.on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
									     (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px"); 
	    }) 
	.on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
        .on("click", function(d, i) { 
	    update_info(d); })
	.attr('x', function(d) { return xscale(d.pro+d.syne+d.phage); })
	.attr('y', function(d,i){ return yscale(i)-8; })
	.style('fill',function(d,i){ return color(3); })
	.attr('width',function(d){ return xscale(d.meta); });

    // other
    var chart2 = svg.append('g')
	.attr("transform", "translate(90,0)")
	.attr('id','bars')
	.selectAll('rect')
	.data(data)
	.enter()
	.append('rect')
	.attr('height',19)
	.on("mouseover", function(d){ 
	    if ( d.other > 0 ) { 
		return tooltip.style("visibility", "visible").html("other: " + d.other ); 
	    }}) 
	.on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
									     (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px"); 
	    }) 
	.on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
        .on("click", function(d, i) { 
	    update_info(d); })
	.attr('x', function(d) { return xscale(d.pro+d.syne+d.phage+d.meta); })
	.attr('y', function(d,i){ return yscale(i)-8; })
	.style('fill',function(d,i){ return color(4); })
	.attr('width',function(d){ return xscale(d.other); });

function update_info(d) {
   var info_panel = document.getElementById("detail_info_div");

   var link2 = genome_cnt_link + "&min_depth=" + d.min_depth
       + "&metadata_col=p.depth";
   if ( d.max_depth ) {
       link2 += "&max_depth=" + d.max_depth;
   }

   var str1 = "<h3>Depth: " + d.id + "</h3>";

   str1 += "<table class='img'>";
   if ( d.pro > 0 ) {
	var bgcolor = color(0);
	str1 += "<tr><td><div id='rectangle' style='background:" 
	    + bgcolor + "'></div></td>"
	    + "<td>Prochlorococcus</td>"
	    + "<td align='right'><div id='pro' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=prochlorococcus"
	    + "')>" + "<u>" + d.pro + "</u>" + "</div></td></tr>"; 
    }
   if ( d.syne > 0 ) {
	var bgcolor = color(1);
	str1 += "<tr><td><div id='rectangle' style='background:" 
	    + bgcolor + "'></div></td>"
	    + "<td>Synechococcus</td>"
	    + "<td align='right'><div id='syne' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=synechococcus"
	    + "')>" + "<u>" + d.syne + "</u>" + "</div></td></tr>"; 
    }
   if ( d.phage > 0 ) {
	var bgcolor = color(2);
	str1 += "<tr><td><div id='rectangle' style='background:" 
	    + bgcolor + "'></div></td>"
	    + "<td>Cyanophage</td>"
	    + "<td align='right'><div id='phage' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=cyanophage"
	    + "')>" + "<u>" + d.phage + "</u>" + "</div></td></tr>"; 
    }
   if ( d.meta > 0 ) {
	var bgcolor = color(3);
	str1 += "<tr><td><div id='rectangle' style='background:" 
	    + bgcolor + "'></div></td>"
	    + "<td>Metagenome</td>"
	    + "<td align='right'><div id='meta' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=marine_metagenome"
	    + "')>" + "<u>" + d.meta + "</u>" + "</div></td></tr>"; 
    }
   if ( d.other > 0 ) {
	var bgcolor = color(4);
	str1 += "<tr><td><div id='rectangle' style='background:" 
	    + bgcolor + "'></div></td>"
	    + "<td>Other</td>"
	    + "<td align='right'><div id='other' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=marine_other"
	    + "')>" + "<u>" + d.other + "</u>" + "</div></td></tr>"; 
    }
   if ( d.count > 0 ) {
	str1 += "<tr><td></td>"
	    + "<td>View All</td>"
	    + "<td align='right'><div id='viewall' style='cursor:pointer;' "
	    + "onclick=window.open('" 
	    + link2 + "&class=marine_all"
	    + "')>" + "<u>" + d.count + "</u>" + "</div></td></tr>"; 
    }
   str1 += "</table>";

   info_panel.innerHTML = str1; 
}

</script>
EOF
#    if ( $unclassified ) {
#	print "Unclassified: $unclassified\n";
#    }

    print "<script src='$base_url/overlib.js'></script>\n"; 
    my $text = "Examples: 10m, 10 m, 10 meters.";
    my $popup_header = "depth data format";

    my $info2 = 
        "onclick=\"return overlib('$text', " 
      . "RIGHT, STICKY, MOUSEOFF, "
      . "CAPTION, '$popup_header', "
      . "FGCOLOR, '#E0FFC2', "
      . "WIDTH, 200)\" " 
    . "onmouseout='return nd()' "; 

    print qq{
        </div>
</fieldset>

        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Statistics</legend>
        <div id="detail_info_div" contenteditable="false">
        <p>Click on a bar to show detailed statistics.</p>
        <b>Note:</b> This graph only shows public marine
        genomes and metagenomes. 
        <b> Only depth field values conform to specified
        <a $info2 style='cursor:pointer;'><u>formats</u></a>
        is used for range.</b>
        Depth is measured in meters.
        </p>
        </div>
        </fieldset>
    };

    printStatusLine( "$cnt2 Values", 2 );

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#####################################################################
# show Clade Graph
#####################################################################
sub cladeGraph {
    my ($new_url) = @_;

    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};
    my $member_conds = $e->{member_conds};

print qq{
    <div class="parentDashboard">
};

    showDataSetSelectionSection('cladegraph', '', $new_url);

    printStatusLine("Loading ...");
    my $dbh = dbLogin();
    my $sql = "";

    # should be: order by e.latitude, e.longitude, t.taxon_display_name
    # recs of
    # "$taxon_oid\t$name\t$geo_location\t$latitude\t$longitude\t$altitude\t$depth"
    # only public marine prochlorococcus and synechococcus
    $sql = "select t.taxon_oid, t.taxon_display_name, t.genome_type, " .
	    "p.geo_location, p.latitude, p.longitude, p.altitude, " .
	    "p.depth, p.clade " .
	    "from taxon t, gold_sequencing_project\@imgsg_dev p " .
	    "where t.sequencing_gold_id = p.gold_id " .
	    "and t.obsolete_flag = 'No' and t.is_public = 'Yes' " .
	    "and (lower(t.genus) like '%prochlorococcus%' or " .
	    " lower(t.genus) like '%synechococcus%') " .
	    "and p.ecosystem_type = 'Marine' " .
	    "and p.clade is not null ";
    $sql .= " order by 4, 5, 2";

    ### prepare data to be mapped
    my %clade_h;
    my %clade_genomes_h;
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt2 = 0;
    my @recsToDisplay = ();
    for ( ; ; ) {
	my ( $taxon_oid, @rest ) = $cur->fetchrow();
	last if ! $taxon_oid;

	my $line = $taxon_oid . "\t" . join("\t", @rest);
	push( @recsToDisplay, $line );

	my $taxon_name = $rest[0];
	my $genome_type = $rest[1];
#	my $original_depth = $rest[-2];
#	my $depth = convertDepth($original_depth);
	my $clade = $rest[-1];

	if ( $clade =~ /^5.1A/ ) {
	    $clade = '5.1A';
	}
	elsif ( $clade =~ /^5.1B/ ) {
	    $clade = '5.1B';
	}
	elsif ( $clade =~ /^5.2/ ) {
	    $clade = '5.2';
	}
	elsif ( $clade =~ /^5.3/ ) {
	    $clade = '5.3';
	}

	if ( $clade_h{$clade} ) {
	    $clade_h{$clade} += 1;
	}
	else {
	    $clade_h{$clade} = 1;
	}

	my $taxon = $taxon_oid . "\t" . $taxon_name;

	if ( $clade_genomes_h{$clade} ) {
	    my $aref = $clade_genomes_h{$clade};
	    push @$aref, ( $taxon );
	}
	else {
	    my @a2 = ( $taxon );
	    $clade_genomes_h{$clade} = \@a2;
	}

	$cnt2++;
	if ( $cnt2 > 100000 ) {
	    last;
	}
    }
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    my $g_cnt_url = "$main_cgi?section=ProPortal&page=genomeList";

    my @clade_list = ( 'HLI', 'HLII', 'LLI', 'LLII/III', 'LLIV', 
		       '5.1A', '5.1B', '5.2', '5.3' );
    my $data = "[ {\"id\": \"\", \"count\": 0}";
    my $max_val = 0;
    for my $m ( @clade_list ) {
	my $genus = "Prochlorococcus";
	if ( $m =~ /^5/ ) {
	    $genus = "Synechococcus";
	}

	my $val = $clade_h{$m};

	if ( ! $val ) {
	    $val = 0;
	}
	if ( $val > $max_val ) {
	    $max_val = $val;
	}

	$data .= ", {\"id\": \"" . $m . "\", \"genus\": \"" .
	    $genus . "\", \"count\": " . $val;

	if ( $val > 0 ) {
	    # add genome list
	    my $aref = $clade_genomes_h{$m};
	    my $g_list = "";
	    if ( $aref ) {
		for my $t ( @$aref ) {
		    my ($t_id, $t_name) = split(/\t/, $t, 2);
		    if ( $g_list ) {
			$g_list .= ", ";
		    }
		    $g_list .= "{\"taxon_oid\": $t_id, \"taxon_name\": \"" .
			$t_name . "\"}";
		}
	    }

	    if ( $g_list ) {
		$data .= ", \"genomes\": [" . $g_list . "]";
	    }
	}

	$data .= "}";
	$cnt2++;
    }

    $data .= "]";

##    print "<p>*** $data ***\n";

    if ( $max_val < 1 ) {
	$max_val = 1;
    }

    $max_val = ceil($max_val / 5) * 5 + 10;
    my $max_range = $max_val * 6;

    print qq{
    <fieldset class='googleMap'>
    <legend class='aboutLegend'>Clade</legend>
      <div id='chart_div'>

    <style>

 .node circle {
   fill: #fff;
   stroke: steelblue;
   stroke-width: 3px;
 }

 .node text { font: 12px sans-serif; }

 .link {
   fill: none;
   stroke: #ccc;
   stroke-width: 2px;
 }
 
    </style>

    <script src='$base_url/d3.min.js'></script>
    <script>
    };

    print "    var data = " . $data . ";\n";

    print <<EOF;
var tooltip = d3.select("#chart_div")
    .append("div")
    .style("position", "absolute")  
    .style("z-index", "10")
    .style("visibility", "hidden")
    .style("border", "solid 1px #aaa")
    .style("background", "lightsteelblue")
    .html(function(d) {
        return "<b>a simple tooltip</b>";});

//var width = 400,
//    height = 480,
//    barHeight = 20,
//    bar_x = 100,

var max_val = $max_val,
    max_range = $max_range;

var y0 = 10;
var genome_cnt_link = '$g_cnt_url';
var taxon_url = '$url';

// tree
var treeData = [
    {
    "name": "Level 1",
    "parent": "null",
    "x0": 320,
    "children": [
	{
        "name": "Level 1.1",
        "parent": "Top Level",
        "x0": 250,
        "children": [
	    {
            "name": "Level 1.1.1",
            "parent": "Level 1.1",
            "x0": 206,
	        "children": [
		    { "name": "P",
                   "parent": "Level 1.1.1",
                   "x0": 160,
                   "children": [
		       {"name": "P1",
                        "parent": "P",
                        "x0": 126,
                      "children": [
			  {"name": "P2",
                          "parent": "P1",
                          "x0": 100,
                          "children": [
			      {"name": "P3",
                              "parent": "P2",
                              "x0": 64, 
                              "children": [
				  {"name": "HLI",
                                  "parent": "P3",
				   "x0": 46 },
				  {"name": "HLII",
                                  "parent": "P3",
				   "x0": 82 } ]
                              },
			      {"name": "LLI",
                              "parent": "P2",
			       "x0": 120} ]
                          },
			  {"name": "LLII/III",
                          "parent": "P1",
			   "x0": 158 } ]
		       },
		       {"name": "LLIV",
                        "parent": "P",
			"x0": 190 } ]
		    },
		    {"name": "S1",
                   "parent": "Level 1.1.1",
                   "x0": 248,
                   "children": [
		       { "name": "5.1A",
                        "parent": "Level 1.1.1",
                        "x0": 226
		       },
		       { "name": "5.1B",
                        "parent": "Level 1.1.1",
                        "x0": 265
		       } ] }
                ]
	    },

	    {
            "name": "5.2",
            "parent": "Level 1.1",
            "x0": 300
	    }        ]
	},
	{
        "name": "5.3",
        "parent": "Top Level",
        "x0": 336
	}
    ]
    }
];

    var margin = {top: 10, right: 20, bottom: 10, left: 20},
    width = 400 - margin.right - margin.left,
    height = 420 - margin.top - margin.bottom;

//var svg =  d3.select("#chart_div").append('svg')
//    .attr({'width':width,'height':height});

var svg = d3.select("#chart_div").append('svg')
      .attr("width", width + margin.right + margin.left)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

var i = 0;

var tree = d3.layout.tree()
    .size([height, width]);

var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.y, d.x]; });

root = treeData[0];
  
update(root);

function update(source) {

  // Compute the new tree layout.
  var nodes = tree.nodes(root).reverse(),
   links = tree.links(nodes);

  // Normalize for fixed-depth.
  nodes.forEach(function(d) { d.y = d.depth * 12;
          if ( d.x0 ) {
              d.x = d.x0; }
        });

  // Declare the nodes
  var node = svg.selectAll("g.node")
   .data(nodes, function(d) { return d.id || (d.id = ++i); });

  // Enter the nodes.
  var nodeEnter = node.enter().append("g")
   .attr("class", "node")
   .attr("transform", function(d) { 
    return "translate(" + d.y + "," + d.x + ")"; });

//  nodeEnter.append("circle")
//   .attr("r", 10)
//   .style("fill", "#fff");
	       
  nodeEnter.append("text")
      .attr("x", function(d) { 
	  return d.children || d._children ? -13 : 13; })
   .attr("dy", ".35em")
   .attr("text-anchor", function(d) { 
       return d.children || d._children ? "end" : "start"; })
   .text(function(d) { return ''; })
   .style("fill-opacity", 1);

   // the horizonal lines
  var link1 = svg.selectAll(".link")
    .data(links)
    .enter().append("line")
    .attr("class", "link")
    .attr("x1", function(d) { return d.source.y; })
    .attr("y1", function(d) { return d.target.x; })
    .attr("x2", function(d) {
        if ( d.target.children ) {  return d.target.y; }
        else { return 80; } } )
    .attr("y2", function(d) { return d.target.x; });

  // the vertical lines
  var link2 = svg.selectAll(".link2")
    .data(links)
    .enter().append("line")
    .attr("class", "link")
    .style("fill", "#99ccff")
    .attr("x1", function(d) { return d.source.y; })
    .attr("y1", function(d) { return d.source.x; })
    .attr("x2", function(d) { return d.source.y; })
    .attr("y2", function(d) { return d.target.x; });

}

// genus gray boxes and text
var genusData = [
    { "name": "Prochlorococcus", "y0": 32, "h0": 170, "x1": 185 },
    { "name": "Synechococcus", "y0": 215, "h0": 140, "x1": 20 }
    ];

svg.selectAll("rect2")
    .data(genusData)
    .enter()
    .append("rect")
    .attr("x", "90")
    .attr("y", function(d) { return d.y0; })
    .attr("width", "30")
    .attr("height", function(d) { return d.h0; } )
    .attr("fill", "lightgray");

svg.selectAll("text2")
    .data(genusData)
    .enter()
    .append("text")
    .text(function(d) {
	return d.name;
	     })
    .attr("x", function(d) { return d.x1; })
    .attr("y", "60")
    .attr("text-anchor", "middle")
    .attr("font-family", "sans-serif")
    .attr("font-size", "12px")
    .attr("fill", "black")
    .attr("transform", "translate(50,300)rotate(270)");

// bar chart
var color = d3.scale.category20b();
var clades = [ '', 'HLI', 'HLII', 'LLI', 'LLII/III', 'LLIV', '5.1A', '5.1B', '5.2', '5.3'];

var grid = d3.range(25).map(function(i){
    return {'x1':0,'y1':0,'x2':0,'y2':360};
			    });

// tick values: 10, 20, 30, ...
var tickVals = grid.map(function(d,i){
    return i*10;
});

var xscale = d3.scale.linear()
    .domain([0,max_val])
    .range([0,max_range]);

var yscale = d3.scale.linear()
    .domain([0,clades.length])
    .range([0,360]);

var grids = svg.append('g')
    .attr('id','grid')
    .attr('transform','translate(160,10)')
    .selectAll('line')
    .data(grid)
    .enter()
    .append('line')
    .attr({'x1':function(d,i){ return i*30; },
	   'y1':function(d){ return d.y1; },
	   'x2':function(d,i){ return i*30; },
	   'y2':function(d){ return d.y2; },
	  })
    .style({'stroke':'#adadad','stroke-width':'1px'});

var xAxis = d3.svg.axis();
xAxis
    .orient('bottom')
    .scale(xscale)
    .tickValues(tickVals);

var yAxis = d3.svg.axis();
yAxis
    .orient('left')
    .scale(yscale)
    .tickSize(2)
    .tickFormat(function(d,i){ 
	if ( clades[i] ) {
	    return clades[i];
	}
	else {
	    return '';
	}})
    .tickValues(d3.range(17));

// show clades
var y_xis = svg.append('g')
    .attr("transform", "translate(160,10)")
    .attr('id','yaxis')
    .call(yAxis);

// show counts
var x_xis = svg.append('g')
    .attr("transform", "translate(160,360)")
    .attr('id','xaxis')
    .call(xAxis);

var chart = svg.append('g')
    .attr("transform", "translate(160,0)")
    .attr('id','bars')
    .selectAll('rect')
    .data(data)
    .enter()
    .append('rect')
    .attr('height',19)
    .on("mouseover", function(d){ 
	if ( d.count > 0 ) { 
            return tooltip.style("visibility", "visible").html("genome count: " + d.count ); 
	      }}) 
    .on("mousemove", function(){tooltip.style("cursor", "pointer").style("top", 
		       (d3.event.pageY-10)+"px").style("left",(d3.event.pageX+6)+"px");
	      }) 
    .on("mouseout", function(){return tooltip.style("visibility", "hidden");}) 
    .on("click", function(d, i) { 
	      var info_panel = document.getElementById("detail_info_div");
        var str1 = 
            "<div id='total_cnt' style='cursor:pointer;' "
            + "onclick=window.open('" 
            + genome_cnt_link 
            + "&clade=" + d.id 
            + "&metadata_col=p.clade" 
            + "')>" 
            + "<h3>" + d.genus + "</h3>"
            + "<h3>" + d.id + " Clade</h3>"
            + "<p>View All: <u>" + d.count + "</u>"
            + "</div>"; 
        if ( d.count > 0 ) {
	    for (var i=0; i < d.genomes.length; i++ ) {
		var t2 = d.genomes[i];
		str1 += "<div id='t_" + i
		    + "' style='cursor:pointer;' "
		    + "onclick=window.open('" 
		    + taxon_url + t2.taxon_oid
		    + "')>" 
		    + "<p><u>" + t2.taxon_name + "</u>"
		    + "</div>"; 
	    }
	}
        info_panel.innerHTML = str1; 
      })
    .attr({'x':0,'y':function(d,i){ return yscale(i)+2; }})
    .style('fill',function(d,i){ return color(i % 20); })
    .attr("width", function(d) {return xscale(d.count); });

</script>
EOF
#    if ( $unclassified ) {
#	print "Unclassified: $unclassified\n";
#    }

    print "<script src='$base_url/overlib.js'></script>\n"; 
    my $text = "Examples: 10m, 10 m, 10 meters.";
    my $popup_header = "depth data format";

    my $info2 = 
        "onclick=\"return overlib('$text', " 
      . "RIGHT, STICKY, MOUSEOFF, "
      . "CAPTION, '$popup_header', "
      . "FGCOLOR, '#E0FFC2', "
      . "WIDTH, 200)\" " 
    . "onmouseout='return nd()' "; 

    print qq{
        </div>
</fieldset>

        <fieldset class='googleMapRightPanel' id='right_panel'>
        <legend class='aboutLegend'>Genome List</legend>
        <div id="detail_info_div" contenteditable="false">
        <p>Click on a bar to show genome list.</p>
        <p><b>Note:</b> Clade information is only available for isolate genomes.</p>
        </div>
        </fieldset>
    };

    printStatusLine( "$cnt2 Values", 2 );

    # end Dashboard div
    print qq{
</div>
    };

    printAboutNews();
}


#################################################################
# showDataSetSelectionSection
#################################################################
sub showDataSetSelectionSection {
    my ($graph_type, $class, $new_url) = @_;
 
    my $e = getDatamartEnv();

    my $list = $e->{members};
    my $member_labels = $e->{member_labels};

    print "<div class='mapSelection'>\n"; 
 
    $new_url = $section_cgi;
    print "<p>\n";
    print nbsp(2);
    print "<b>Graph:</b> \n";
    print nbsp(2);
    print qq{
      <select name='openselect'
          onchange="window.location='$new_url&page=' + this.value;"
          style="width:200px;">
    };
 
##    my @graphs = ('googlemap', 'depthecotypemap', 'depthclademap', 'cladegraph');
    my @graphs = ('datatypegraph', 'googlemap', 'depthgraph', 'cladegraph');
    my %graph_name_h;
    $graph_name_h{'datatypegraph'} = 'Data Type';
    $graph_name_h{'googlemap'} = 'Location';
    $graph_name_h{'depthecotypemap'} = 'Depth & Ecotype';
    $graph_name_h{'depthclademap'} = 'Depth & Clade';
    $graph_name_h{'depthgraph'} = 'Depth';
    $graph_name_h{'cladegraph'} = 'Clade';
    for my $x ( @graphs ) {
        print "    <option value='$x' "; 
        if ( $x eq $graph_type ) {
            print " selected ";
        } 
 
        print ">" . $graph_name_h{$x} . "</option>\n"; 
    } 
    print "</select>\n"; 

    if ( $graph_type eq 'datatypegraph' ||
	 $graph_type eq 'depthgraph' ||
	 $graph_type eq 'cladegraph' ) {
	print "</div>\n";
	return "";
    }

    print nbsp(5);
    print "<b>Genomes:</b> \n";
    print nbsp(2);
    print qq{                                                                  
      <select name='openselect'                                                
          onchange="window.location='$new_url&page=$graph_type&class=' + this.value;"        
          style="width:200px;">                                                
    };
 
    print "    <option value='all' "; 
    if ( $class eq 'all' ) {
	print " selected ";
    } 
    print ">All IMG Datasets</option>\n"; 
    print "    <option value='datamart' "; 
    if ( !$class || $class eq 'datamart' ) {
	print " selected ";
    } 
    print ">" . $e->{main_label} . "</option>\n"; 
    for my $x ( @$list ) {
        print "    <option value='$x' "; 
        if ( $x eq $class ) {
            print " selected ";
        } 
 
        print ">" . $member_labels->{$x} . "</option>\n"; 
    } 
    print "</select>\n";
    
    
    print "</div>\n"; 
 
    return $class; 
}


####################################################################
# convertDepth: accept depth data in format: 10m, 10 m, 10 meters
#               return the numeric value
####################################################################
sub convertDepth {
    my ($input_str) = @_;

    $input_str = strTrim($input_str);
    if ( ! $input_str ) {
	return "";
    }

    if ( isNumber($input_str) ) {
	## no unit
	return "";
    }

    my ($v1, $v2, @rest) = split(/ /, $input_str);
    $v2 = lc($v2);
    if ( isNumber($v1) && scalar(@rest) == 0 &&
	 ($v2 eq 'm' || $v2 eq 'meters' || $v2 eq 'meter') ) {
	return $v1;
    }

    if ( $v2 ) {
	## different unit
	return "";
    }

    $v1 = lc($v1);
    $v1 =~ s/m//;
    if ( isNumber($v1) ) {
	return $v1;
    }

    return "";
}



1;
