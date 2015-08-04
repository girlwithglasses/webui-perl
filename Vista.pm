############################################################################
# Vista.pm - Page to link to VISTA and display sets of genomes
#   that were aligned together.
#    --es 07/07/2005
############################################################################
package Vista;
my $section = "Vista";
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    printVistaStartPage
    loadSets
);
use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use ScaffoldPanel;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $vista_url_map_file = $env->{ vista_url_map_file };
my $vista_sets_file = $env->{ vista_sets_file };
my $vista_home = "http://genome.lbl.gov/vista";
my $include_metagenomes = $env->{include_metagenomes};

# Used for YUI CSS
my $YUI = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if($page eq "toppage") {
        printTopPage();
    } elsif( $page eq "vista" ) {
        printVistaStartPage( );
    }
    else {
        printVistaStartPage( );
    }
}

sub printTopPage {
    print "<h1>Synteny Viewers</h1>\n";

    print "<p>\n";
    print "<p>\n";
    print "<p>\n";

    # Use YUI css
    if ($yui_tables) {
	print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Tool</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Description</span>
	    </div>
	</th>

YUI
    } else {
	print "<table class='img' border='1'>\n";
	print "<th class='img'>Tool</th>\n";
	print "<th class='img'>Description</th>\n";
    }

    my $idx = 0;
    my $classStr;

    if ($yui_tables) {
	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    } else {
	$classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;

    my $url = "$main_cgi?section=Vista&page=vista";
    $url = alink( $url, "VISTA" );
    print $url;
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "VISTA allows you to do full scaffold alignments between genomes.";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    require DotPlot;

    $idx++;
    if ($yui_tables) {
	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    } else {
	$classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    my $url = "$main_cgi?section=DotPlot&page=plot";
    $url = alink( $url, "Dotplot" );
    print $url;
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print DotPlot::getNote();
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    } else {
	$classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    my $url = "$main_cgi?section=Artemis&page=ACTForm";
    $url = alink( $url, "Artemis ACT" );
    print $url;
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{
    ACT (Artemis Comparison Tool) is a viewer based on Artemis for pair-wise 
    genome DNA sequence comparisons, whereby comparisons are usually the result
    of running Mega BLAST search.        
    };
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "</p>\n";
}

############################################################################
# printVistaStartPage - Start page to link to VISTA.
############################################################################
sub printVistaStartPage {
    my $link1 =
	"<a href=http://pipeline.lbl.gov/vista_help/help.html#vistapoint>"
      . "VISTA-Point help pages</a>";
    my $link2 = "<a href=$vista_home>VISTA</a>";
    my $link3 = "<a href=mailto:vista\@lbl.gov>VISTA Questions/Comments</a>";

    my $text = 
	"VISTA allows you to do full scaffold alignments between genomes. "
      . "The current sets of alignments are precomputed for select genomes "
      . "listed here.";
    my $description = 
        "$text Clicking on any of these genomes launches VISTA directly.<br/>"
      . "For updated genomes, go to $link2. "
      . "For more information, consult with $link1 or contact $link3.";

    if ($include_metagenomes) {
	WebUtil::printHeaderWithInfo 
	    ("Vista", $description,
	     "show description for this tool", "Vista Info", 1);
    } else { 
	WebUtil::printHeaderWithInfo
	    ("Vista", $description,
	     "show description for this tool", "Vista Info");
    } 

    print "<p>$text</p>\n";
    printMainForm( );

    my %sets = loadSets( );
    my $dbh = dbLogin( );

    my %taxonOid2Url;
    my $rfh = newReadFileHandle( $vista_url_map_file, "printVistaStartPage" );
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $taxon_oid, $url ) = split( /\t/, $s );
       $taxonOid2Url{ $taxon_oid } = $url;
    }
    close $rfh;
    my @setNames = sort( keys( %sets ) );
    for my $setName( @setNames ) {
	my $taxon_oid_str = $sets{ $setName };
	chop $taxon_oid_str;
        my $rclause = urClause( "tx" );
        my $imgclause = WebUtil::imgClause('tx');
        my $sql = qq{
           select tx.taxon_oid, tx.taxon_display_name
           from taxon tx
           where tx.taxon_oid in( $taxon_oid_str )
           $rclause
           $imgclause
           order by tx.taxon_display_name
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        print "<p>\n";
        for( ;; ) {
           my( $taxon_oid, $taxon_display_name ) = $cur->fetchrow( );
           last if !$taxon_oid;
           my $url = $taxonOid2Url{ $taxon_oid };
	   if( $url eq "" ) {
	       webLog( "printVistaPage: cannot find URL for '$taxon_oid'\n" );
	       next;
	   }
           print alink( $url, $taxon_display_name ) . "<br/>\n";
        }
        $cur->finish( );
        print "</p>\n";
    }
    #$dbh->disconnect();
    print end_form( );
    printHint( "You may search for a coordinate position by entering " .
	       "the gene_oid (Gene ID)." );
}

############################################################################
# loadSets - Load comparision sets of genomes.
############################################################################
sub loadSets {
    my %sets;
    my $rfh = newReadFileHandle( $vista_sets_file, "loadSets" );
    my $curr_set;
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       $s =~ s/^\s+//;
       $s =~ s/\s+$//;
       next if $s =~ /^#/;
       next if blankStr( $s );
       if( $s =~ /^\.set / ) {
          my( $tag, $val ) = split( / /, $s );
	  $curr_set = $val;
       }
       elsif( $s =~ /^\.setEnd/ ) {
          $curr_set = "";
       }
       elsif( $curr_set ne "" ) {
	  $s =~ s/^\s+//;
	  my( $tok0, undef ) = split( /\s+/, $s );
          $sets{ $curr_set } .= "$tok0,";
       }
    }
    close $rfh;
    return %sets;
}

1;

