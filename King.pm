############################################################################
# King.pm - 3D applet for PCA, PCoA, NMDR, etc.
#     -- anna 6/25/2012
# $Id: King.pm 33155 2015-04-11 04:44:14Z aratner $
############################################################################
package King;
 
use strict; 
use CGI qw( :standard );
use WebConfig; 
use WebUtil; 

my $env = getEnv(); 
my $base_url = $env->{ base_url }; 
my $main_cgi = $env->{ main_cgi }; 
my $cgi_dir = $env->{ cgi_dir };
my $cgi_url = $env->{ cgi_url }; 
my $tmp_dir = $env->{ tmp_dir };
my $tmp_url = $env->{ tmp_url };
 
# writes the input file for KiNG applet
sub writeKinInputFile { 
    my( $recs_ref, $kinFile, $connect_all, 
        $urlfrag1, $urlfrag2, $xlabel, $ylabel, $zlabel,
	$set2scafs_href ) = @_; 

    #########################################################
    # The items in recs_ref are already sorted correctly
    # DO NOT re-sort because the lineage will get messed up
    #########################################################

    my @colors = ("orange", "cyan", "yellow", "green", "red", "magenta", 
		  "blue", "pink", "purple", "brown", "hotpink", "gold");
    my %setColors; # for scaffold sets
    my $sidx = 0; 
    my $cnt = 0;
    my %not_unique_scafsets; 
    my %s2set; # anna: need a map of scaffold_oid:set

    if ($set2scafs_href) {
	print "<p>";
        foreach my $x (keys %$set2scafs_href) {
	    my $url = "$main_cgi?section=WorkspaceScafSet"
		    . "&page=showDetail&filename=$x&folder=scaffold";
	    my $color = $colors[$sidx];
	    my $link = alink($url, $x, "_blank");
	    print "<br/>" if $cnt > 0;
	    print "$link - "
		. "<span style='color:$color;background-color:black'>"
		. "<b>$color</b></span>";
	    $setColors{ $x } = $color;
	    $sidx++;
	    $cnt++;
	    $sidx = 0 if ($sidx == 12);

            my $scafs_ref = $set2scafs_href->{$x};
            foreach my $scaf_oid (@$scafs_ref) {
		if (exists $s2set{$scaf_oid}) {
		    $not_unique_scafsets{ $scaf_oid } = 1;
		}
                $s2set{$scaf_oid} = $x;
            }
        }
	print "</p>";
    }

    my $wfh = newWriteFileHandle( $kinFile, "writeKinInputFile" ); 
    print $wfh "\@text\n"; 
    print $wfh "$kinFile\n"; 
    print $wfh "\@kinemage 1\n"; 
    print $wfh "\@1viewid {original}\n"; 
    print $wfh "\@1zoom 1.0\n"; 
    print $wfh "\@1zslab 240\n"; 
    print $wfh "\@1center 0 0 0\n"; 
    print $wfh "\@2viewid {3-axes}\n"; 
    print $wfh "\@2zoom 1.0\n"; 
    print $wfh "\@2zslab 240\n"; 
    print $wfh "\@2center 0 0 0\n"; 
    print $wfh "\@2matrix 0.9 0 0.3 -0.01 0.9 0.1 -0.3 -0.1 0.9\n"; 
    print $wfh "\@thinline\n"; 
 
    my %domainColors; 
    my %phylumHash; 
    my %setHash;

    my $max1 = 0; my $max2 = 0; my $max3 = 0; 
    foreach my $r( @$recs_ref ) { 
        my( $id, $desc, $lineage, 
            $pc1, $pc2, $pc3, undef ) = split( /\t/, $r ); 
        #my $val = (abs($pc1)+abs($pc2)+abs($pc3))/3;
        #$max = $max1 > $val ? $max1 : $val;
        my $val1 = abs($pc1); 
        my $val2 = abs($pc2); 
        my $val3 = abs($pc3); 
        $max1 = $max1 > $val1 ? $max1 : $val1; 
        $max2 = $max2 > $val2 ? $max2 : $val2; 
        $max3 = $max3 > $val3 ? $max3 : $val3; 
    } 

    my $max = sprintf( "%.3f", ($max1+$max2+$max3)/3 ); 
    my $radius = $max/80;
    #print "<br/>ANNA: [$max]  radius=$radius";
 
    my $max_pc1 = -1000000000;
    my $max_pc2 = -1000000000; 
    my $max_pc3 = -1000000000;
    my $min_pc1 = 1000000000;
    my $min_pc2 = 1000000000; 
    my $min_pc3 = 1000000000; 
 
    # pass url as: "$cgi_url/$main_cgi?#$urlfrag1#$urlfrag2" 
    my $url_str = "$cgi_url/$main_cgi?"."#".$urlfrag1."#".$urlfrag2;
 
    my $idx = 0; 
    foreach my $r( @$recs_ref ) { 
        my( $id, $desc, $lineage, 
            $pc1, $pc2, $pc3, $connect, $url1, undef ) = split( /\t/, $r );
 
        $min_pc1 = $min_pc1 < $pc1 ? $min_pc1 : $pc1;
        $min_pc2 = $min_pc2 < $pc2 ? $min_pc2 : $pc2; 
        $min_pc3 = $min_pc3 < $pc3 ? $min_pc3 : $pc3;
        $max_pc1 = $max_pc1 > $pc1 ? $max_pc1 : $pc1;
        $max_pc2 = $max_pc2 > $pc2 ? $max_pc2 : $pc2;
        $max_pc3 = $max_pc3 > $pc3 ? $max_pc3 : $pc3;
 
	my $color = "";
	my $set = "";
	if ($set2scafs_href) {
	    my @sids = split("-", $id);
	    # metagenome taxon_oid data_type scaffold
	    my $scfid = join(" ", @sids); 
	    $set = $s2set{ $scfid };
	    if (!exists $setHash{ $set }) {
		print $wfh "\@group {$set}\n"; 
		$setHash{ $set } = 1;
	    }
	    $color = $setColors{ $set };
	    if (exists $not_unique_scafsets{ $scfid }) {
		$color = "white";
	    }
	}

        my ($domain, $phylum) = split(":", $lineage);
        if (!exists $domainColors{ $domain }) { 
	    if ($set2scafs_href) {
		print $wfh "\@subgroup {$domain}\n"; 
	    } else {
		print $wfh "\@group {$domain}\n"; 
	    }
            $domainColors{ $domain } = $colors[ $idx ]; 
            $idx++; 
            $idx = 0 if ($idx == 7);
        } 
        if (!exists $phylumHash{ $phylum} && $phylum ne "") {
            print $wfh "\@subgroup {$phylum}\n";
            $phylumHash{ $phylum } = 1; 
        }

        $color = $domainColors{ $domain } if $color eq ""; 

        my $d = substr( $domain, 0, 1 ); 
        if ($url1 ne "") {
            $url_str = "$cgi_url/$main_cgi?"."#".$url1."#".$urlfrag2; 
        }
	my $nobtn = "";
	$nobtn = "nobutton " if ($set2scafs_href);
        print $wfh "\@balllist {$desc \[$id\]} ".$nobtn
                 . "color=$color "
                 . "master= {Points} "
                 . "radius=$radius\n";
        #print $wfh "<"."$url_str"."#"."$id".":"."$set".">\n"; # comment field 
        print $wfh "<"."$url_str"."#"."$id".">\n"; # comment field 
        print $wfh "{$desc \[$id\]}$pc1 $pc2 $pc3\n";
    }

    if ($connect_all && $connect_all == 1) { 
        print $wfh "\@group {Draw Lines} nobutton\n";

        my $old_set;
        my $old_domain;

        foreach my $r( @$recs_ref ) {
            my( $id, $desc, $lineage,
                $pc1, $pc2, $pc3, $connect, undef ) = split( /\t/, $r );
            next if $connect eq "";

	    my $color = "";
            my $x = ""; 
            my ($domain, $phylum) = split(":", $lineage);

            if ($set2scafs_href) {
                my @sids = split("-", $id);
                # metagenome taxon_oid data_type scaffold
                my $scfid = join(" ", @sids);
                my $set = $s2set{ $scfid };
                $color = $setColors{ $set };
                if (exists $not_unique_scafsets{ $scfid }) {
                    $color = "white";
                }

                if ($old_set eq "" || $old_set ne $set) {
                    print $wfh "\@subgroup {Connect $set} nobutton "
                        . "master= {Draw Lines}\n";
                    print $wfh "\@vectorlist "
                        . "nobutton color=$color "
                        . "master= {Connect $set}\n";
                    $old_set = $set;
                }
            }
 
	    $color = $domainColors{ $domain } if $color eq ""; 
            if ($old_domain eq "" || $old_domain ne $domain) {
		if ($set2scafs_href) {
                    print $wfh "\@vectorlist "
                        . "nobutton color=$color "
                        . "master= {Connect $old_set}\n";
		} else {
		    print $wfh "\@subgroup {Connect $domain} nobutton "
			. "master= {Draw Lines}\n";
		    print $wfh "\@vectorlist " 
			. "nobutton color=$color " 
			. "master= {Connect $domain}\n";
		}
                $x = "P "; 
                $old_domain = $domain;
            } 

            print $wfh "{$id}$x$pc1 $pc2 $pc3\n";
        } 
    } 
 
    my $pc1lbl = "PC1"; 
    if ($xlabel ne "") { 
        $pc1lbl = $xlabel; 
    } 
    my $pc2lbl = "PC2"; 
    if ($ylabel ne "") { 
        $pc2lbl = $ylabel;
    }
    my $pc3lbl = "PC3"; 
    if ($zlabel ne "") {
        $pc3lbl = $zlabel; 
    } 
 
    print $wfh "\@group {Axes} nobutton\n";
    print $wfh "\@vectorlist nobutton color= white master= {Axes}\n"; 
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } $max_pc1, 0.000, 0.000\n";
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } 0.000, $max_pc2, 0.000\n";
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } 0.000, 0.000, $max_pc3\n";
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } $min_pc1, 0.000, 0.000\n"; 
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } 0.000, $min_pc2, 0.000\n";
    print $wfh "{                    } P 0.000, 0.000, 0.000\n";
    print $wfh "{                    } 0.000, 0.000, $min_pc3\n";
    print $wfh "\@group {Labels} nobutton\n";
    print $wfh "\@labellist nobutton color= white master= {Labels}\n";
    print $wfh "{$pc1lbl} $max_pc1, 0.000, 0.000\n";
    print $wfh "{$pc2lbl} 0.000, $max_pc2, 0.000\n"; 
    print $wfh "{$pc3lbl} 0.000, 0.000, $max_pc3\n"; 
    print $wfh "\@labellist nobutton color= white master= {Origin}\n"; 
    print $wfh "{(0 0 0)} 0.000, 0.000, 0.000\n"; 
    print $wfh "\@vectorlist nobutton color= white master= {ticks}\n";
 
    close $wfh;
}

# writes the jnlp file for KiNG applet
sub writeKingJnlpFile { 
    my( $jnlpFile ) = @_; 
 
    my $wfh = newWriteFileHandle( $jnlpFile, "writeKingJnlpFile" );
    print $wfh "<?xml version='1.0' encoding='UTF-8'?>\n";
    print $wfh " <jnlp codebase='' href=''>\n";
    print $wfh "     <information>\n";
    print $wfh "       <title>3D Analysis using KiNG</title>\n";
    print $wfh "       <vendor>LBNL-JGI</vendor>\n";
    print $wfh "       <homepage href='http://img/jgi/doe.gov'></homepage>\n";
    print $wfh "     </information>\n"; 
    print $wfh "     <resources>\n"; 
    print $wfh "       <j2se version='1.6+'\n"; 
    print $wfh "        href='http://java.sun.com/products/autodl/j2se' />\n";
    print $wfh "       <jar href='$base_url/king.jar' />\n";
    print $wfh "     </resources>\n";
    print $wfh "     <applet-desc\n"; 
    print $wfh "        name='KiNG Applet'\n"; 
    print $wfh "        main-class='king.Kinglet'\n"; 
    print $wfh "        width='950'\n"; 
    print $wfh "        height='650'>\n"; 
    print $wfh "     </applet-desc>\n"; 
    print $wfh " </jnlp>\n"; 
    close $wfh; 
} 

# writes the header for the applet 
sub writeKingHeader {
    my ($linked_file, $tool, $isSet) = @_;
    my $url = "http://kinemage.biochem.duke.edu/software/king.php";
    print "<p>";

    $tool = "view" if !$tool || $tool eq "";
    print "The 3D $tool below is generated using the "
        . alink($url, "KiNG", "_blank")." applet.<br/>"; 
    if ($isSet && $isSet ne "") {
	print "<span style='color:white;background-color:black'>"
	    . "<b>White dots</b></span>";
	print " represent scaffolds present in more than one set.<br/>";
    }
    if ($linked_file ne "") {
	print alink("$linked_file", "View R file", "_blank")
	          . " used to generate this plot.";
    }
    print "</p>";

    printHint 
        ("Mouse over a point to see item information.<br/>" .
         "Click on a point to see item details. If the tooltip for a point of interest does not show the coordinates, try rotating the plot until the coordinates appear.<br/>" .
         "Use drag to rotate. Use SHIFT-drag to select points. " .
         "Use CTRL-drag to reposition image. <br/>" .
         "Right-click to add selections to the cart.");
#### without the line below, prints an elusive 1 at the end
    return;
}

# writes the applet tag
sub writeKingApplet {
    my ($kingInputFile) = @_;

    my $jnlpFile = "$tmp_dir/king$$.jnlp";
    writeKingJnlpFile($jnlpFile);

    my $archive = "$base_url/king.jar, "
	        . "$base_url/itext.jar";
    print qq{
       <applet code="king/Kinglet.class" archive="$archive"
               width="1200" height="650"
               jnlp_href="$tmp_url/king$$.jnlp">
           <param name="mode" value="flat">
           <param name="king_prefs" value="king_prefs.txt">
           <param name="kinSource" value="$kingInputFile">
       </applet>
    }; 
}

sub plotFile { 
    my ($inputKingFile, $set2scafs_href, $isSet) = @_;
    $set2scafs_href = 0 if !$isSet;

    my $header;
    my $labelx;
    my $labely;
    my $labelz;

    my $rfh = newReadFileHandle( $inputKingFile, "king-plotFile" ); 
    my @recs; 
    my $count = 0;

    while( my $s = $rfh->getline() ) { 
        chomp $s; 
	$count++;

	if ($count == 1) {
	    $header = $s;
	} elsif ($count == 2) {
	    $labelx = $s;
	} elsif ($count == 3) {
	    $labely = $s;
	} elsif ($count == 4) {
	    $labelz = $s;
	}

	next if ($count < 5);
        my( $id, $range, $name, 
            $pc1, $pc2, $pc3, $connect ) = split( /\t/, $s ); 
        my ($start, $end) = split("-", $range); 
        my $length = $end+30000; 
        my $surl = "section=ScaffoldGraph&color=cog" 
                 . "&start_coord=$start&end_coord=$end" 
                 . "&seq_length=$length&scaffold_oid="; 
        $s .= "\t" . $surl; 
        push( @recs, $s ); 
    } 
    close $rfh; 
 
    print "<h2>$header</h2>";
    writeKingHeader("", "", $isSet); 
 
    my $url_fragm1 = "section=ScaffoldGraph" 
	           . "&start_coord=&end_coord=&seq_length=&scaffold_oid="; 
    my $url_fragm2 = "section=ScaffoldCart&page=addToScaffoldCart&scaffolds="; 
 
    my $kinFile = $tmp_dir . "/pca$$.kin"; 
    writeKinInputFile(\@recs, $kinFile, 1, 
		      $url_fragm1, $url_fragm2, 
		      $labelx, $labely, $labelz,
		      $set2scafs_href);
    writeKingApplet("$tmp_url/pca$$.kin"); 
} 

1;

