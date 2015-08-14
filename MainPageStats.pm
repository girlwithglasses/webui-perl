############################################################################
# MainPageStats - Statistics for genomes in main/home page.
#    --es 02/01/2005
#
# $Id: MainPageStats.pm 33935 2015-08-07 18:26:22Z klchu $
############################################################################
package MainPageStats;
my $section = "MainPageStats";
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  mainPageStats
  tableRowStats
  getCountStr
  getSumStr
  getMergedSumStr
  replaceStatTableRows
);

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use ScaffoldPanel;
use WebConfig;
use WebUtil;
use DataEntryUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};
my $include_plasmids     = $env->{include_plasmids};
my $public_nologin_site  = $env->{public_nologin_site};
my $img_lite             = $env->{img_lite};
my $img_er               = $env->{img_er};
my $img_geba             = $env->{img_geba};
my $user_restricted_site = $env->{user_restricted_site};
my $base_url             = $env->{base_url};
my $use_img_gold         = $env->{use_img_gold};
my $img_hmp              = $env->{img_hmp};
my $img_ken              = $env->{img_ken};
my $nvl                  = getNvl();

# what names I found in gold to be human
#my $HUMAN_STR = "and p.host_name in ('Homo sapiend', 'Home sapiens', 'Homo sapiens', 'Human')";
my $HOST_NAME = "Homo sapiens";
my $HUMAN_STR = "and p.host_name = 'Homo sapiens'";

my $OTHER = "zzzOther";

############################################################################
# mainPageStats - main page statistics in body page. (To be replaced.)
############################################################################
sub mainPageStats {
    my $dbh = dbLogin();

    ## Number of JGI microbes
    my $rclause   = urClause("tx");
    my $imgclause = WebUtil::imgClause('tx');
    my $sql       = qq{
      select distinct tx.domain, nvl(tx.seq_center, 'na'), nvl(tx.seq_status, 'Draft'), count(*)
      from taxon tx
      where 1 = 1
      $rclause
      $imgclause
      and tx.domain is not null
      group by tx.domain, nvl(tx.seq_center, 'na'), nvl(tx.seq_status, 'Draft')
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %stats;
    my $abc = 0;
    for ( ; ; ) {
        my ( $domain, $seq_center, $seq_status, $count ) = $cur->fetchrow();
        last if !$domain;
        chomp $domain;
        chomp $seq_status;
        chomp $seq_center;
        $domain = "Plasmids"         if ( $domain =~ /^Plasmid/ );
        $domain = "Viruses"          if ( $domain =~ /^Vir/ );
        $domain = "Genome Fragments" if ( $domain =~ /^GFragment/ );

        if($seq_center =~ /JGI/) {
             $seq_center = "JGI"
        } else {
           $seq_center = "Other"; 
        }
        
        my $rec = "$domain\t$seq_center\t$seq_status";
        $stats{$rec} += $count;

        if (   $domain ne "Bacteria"
            && $domain ne "Archaea"
            && $domain ne "Eukaryota"
            && $domain ne "*Microbiome"
            && $domain !~ /^Vir/
            && $domain !~ /^Plasmid/
            && $domain !~ /Fragment/ )
        {
            webLog("WARNING: mainPageStats: bad domain='$domain'\n");
        }
        if ( $seq_status ne "Finished" && $seq_status ne "Draft" && $seq_status ne "Permanent Draft" ) {
            webLog("WARNING: mainPageStats: bad seq_status='$seq_status'\n");
        }
    }
    $cur->finish();

    $sql = qq{
      select count(*)
      from taxon tx
      where tx.seq_center like '%JGI%'
      $imgclause
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($nJgiMicrobes) = $cur->fetchrow();
    $cur->finish();
    $stats{nJgiMicrobes} = $nJgiMicrobes;

    #$dbh->disconnect();

    # Add derived stats.
    my %stats2  = %stats;
    my $derived = 1;
    for my $k ( sort( keys(%stats) ) ) {
        my ( $domain, $seq_center, $seq_status ) = split( /\t/, $k );
        my $count = $stats{$k};
       
        $stats2{$k} = $count;
        if ($derived) {
            if ( $seq_center eq "Other" ) {
                my $k2 = "$domain\t";
                $k2 .= "JGI\t";
                $k2 .= "$seq_status";
                my $count2 = $stats{$k2};
                $count2 = 0 if $count2 eq "";
                my $total_rec = "$domain\t";
                $total_rec .= "Total\t";
                $total_rec .= "$seq_status";
                my $total_count = $count + $count2;
                $stats2{$total_rec} = $total_count;
            }
            if ( $seq_center eq "JGI" ) {
                my $k2 = "$domain\t";
                $k2 .= "Other\t";
                $k2 .= "$seq_status";
                my $count2 = $stats{$k2};
                $count2 = 0 if $count2 eq "";
                my $total_rec = "$domain\t";
                $total_rec .= "Total\t";
                $total_rec .= "$seq_status";
                my $total_count = $count + $count2;
                $stats2{$total_rec} = $total_count;
            }
        }
    }
    my @seq_centers  = ( "JGI",      "Total" );
    my @seq_statuses = ( "Finished", "Draft", "Permanent Draft" );
    my @domains      = ( "Bacteria", "Archaea", "Eukaryota", "Viruses", "Plasmids", "Genome Fragments", "*Microbiome" );
    if ($derived) {
        for my $seq_center (@seq_centers) {
            my $seq_status_count = 0;
            for my $seq_status (@seq_statuses) {
                my $k2 = "All Genomes\t";
                $k2 .= "$seq_center\t";
                $k2 .= "$seq_status";
                my $domain_count = 0;
                for my $domain (@domains) {
                    my $k3 = "$domain\t";
                    $k3 .= "$seq_center\t";
                    $k3 .= "$seq_status";
                    my $cnt = $stats2{$k3};
                    $domain_count += $cnt;
                }
                $stats2{$k2} = $domain_count;
            }
        }
    }

    if ( $verbose >= 5 ) {
        my @keys = sort {
            my ( $domain1, $seq_center1, $seq_status1 ) = split( /\t/, $a );
            my ( $domain2, $seq_center2, $seq_status2 ) = split( /\t/, $b );
            $seq_status1 cmp $seq_status2
              || $domain1 cmp $domain2
              || $seq_center1 cmp $seq_center2;
        } ( keys(%stats2) );
        my $nKeys = @keys;
        for my $k (@keys) {
            my $cnt = $stats2{$k};
            my ( $domain, $seq_center, $seq_status ) = split( /\t/, $k );
            webLog "'$seq_status' '$domain' '$seq_center' => $cnt\n";
        }
        webLog "nKeys=$nKeys\n";
    }

    return %stats2;
}

############################################################################
# tableRowStats - Show one row in home page stats with genomes.
#    Inputs:
#       stats_ref - Stats data
#       domain - taxonomic domain
############################################################################
# v2.9 where the tree is the default view
sub tableRowStats {
    my ( $stats_ref, $domain, $genome_type ) = @_;
    my $bgcolor;
    $bgcolor = "bgcolor=#ffcc00" if $domain eq "Bacteria";
    $bgcolor = "bgcolor=#99cc66" if $domain eq "Archaea";
    $bgcolor = "bgcolor=#99ccff" if $domain eq "Eukaryota";
    $bgcolor = "bgcolor=#ffdd99" if $domain eq "Plasmids";
    $bgcolor = "bgcolor=#66ccff" if $domain eq "Viruses";
    $bgcolor = "bgcolor=#cc99ff" if $domain eq "Genome Fragments";
    $bgcolor = "bgcolor=#ffccff" if $domain eq "*Microbiome";

    my ( $countStrTotal, $rowSum ) = getCountStr( $stats_ref, $domain, "Total", $genome_type );

    # If count is zero, do not display row stats
    return if !$rowSum;

    my $s = "<tr $bgcolor>\n";

    # domain name link on main page
    #my $domainUrl = getTreeUrl( $domain, "" );
    my $domainUrl = getTableUrl( $domain, "" );

    my $domain2 = $domain;
    ## --es 01/02/2006 Kludges for names.
    $domain2 = "Eukarya"    if $domain =~ /^Euk/;
    $domain2 = "Metagenome" if $domain =~ /^\*Microbiome/;
    my $domainLink = $domain2; #alink( $domainUrl, $domain2 );
    $domainLink = $domain if $countStrTotal eq "0/0";
    $s .= "<td >$domainLink</td>\n";
    if ($img_hmp) {
        $s .= "<td align='right'> &nbsp; </td>\n";
    } else {
        #### Individual totals removed for IMG 3.5 -BSJ 08/02/11
        # $s .= "<td align='right'>$countStrTotal</td>\n";
        $s .= "<td align='right'> &nbsp; </td>\n";
    }
    $s .= "<td align='right'>$rowSum</td>\n";
    $s .= "</tr>\n";
    return $s;
}

sub getTreeUrl {
    my ( $domain, $seq_status ) = @_;

    my $url = "main.cgi?section=TreeFile&page=domain";
    $url .= "&seq_status=$seq_status" if ( $seq_status ne "" );
    if ( $domain eq "Bacteria" ) {
        $url .= "&domain=bacteria";
    } elsif ( $domain eq "Archaea" ) {
        $url .= "&domain=archaea";
    } elsif ( $domain eq "Eukaryota" ) {
        $url .= "&domain=eukaryota";
    } elsif ( $domain eq "Plasmids" ) {
        $url .= "&domain=plasmid";
    } elsif ( $domain eq "Viruses" ) {
        $url .= "&domain=viruses";
    } elsif ( $domain eq "Genome Fragments" ) {
        $url .= "&domain=GFragment";
    } elsif ( $domain eq "*Microbiome" ) {
        $url .= "&domain=*Microbiome";
    } else {
        $url .= "&domain=all";
    }
    return $url;
}

sub getTableUrl {
    my ( $domain, $seq_status ) = @_;

    my $alpha_url = "main.cgi?section=TaxonList&page=taxonListAlpha";

    if ( $domain eq "bacteria" || $domain eq "Bacteria" ) {
        $alpha_url .= "&domain=Bacteria";
    } elsif ( $domain eq "archaea" || $domain eq "Archaea" ) {
        $alpha_url .= "&domain=Archaea";
    } elsif ( $domain eq "eukaryota" || $domain eq "Eukaryota" ) {
        $alpha_url .= "&domain=Eukaryota";
    } elsif ( $domain eq "*Microbiome" ) {
        $alpha_url .= "&domain=*Microbiome";
    } elsif ( $domain eq "plasmid" || $domain eq "Plasmids" ) {
        $alpha_url .= "&domain=Plasmids";
    } elsif ( $domain eq "GFragment" || $domain eq "Genome Fragments" ) {
        $alpha_url .= "&domain=GFragment";
    } elsif ( $domain eq "viruses" || $domain eq "Viruses" ) {
        $alpha_url .= "&domain=Viruses";
    } else {
        $alpha_url .= "&domain=all";
    }

    $alpha_url .= "&seq_status=$seq_status" if ( $seq_status ne "" );

    #$alpha_url .= "&seq_center=$seq_center" if ( $seq_center ne "" );
    return $alpha_url;
}

############################################################################
# tableRowSumStats - Show summary stats with URL links.
#   Inputs:
#     stats_ref - stats data reference
#     domain - taxonomic domain
############################################################################
# for v2.9 show tree
sub tableRowSumStats_new {
    my ( $stats_ref, $domain ) = @_;
    my $s = "<tr>\n";

    my $domain2 = $domain;
    $domain2 = "Total Datasets" if $domain eq 'All Genomes';

    #my $domainUrl = getTreeUrl($domain, "");
    my $domainUrl = getTableUrl( $domain, "" );

    my $domainLink = $domain2; #alink( $domainUrl, $domain2 );
    $s .= "<td>$domainLink</td>\n";

    my ( $countStr, $rowSum ) = getSumStr_new( $stats_ref, $domain, "Total" );
    if ($img_hmp) {
        $s .= "<td align='right'> &nbsp; </td>\n";
    } else {
        #### Individual totals removed for IMG 3.5 -BSJ 08/02/11
        # $s .= "<td align='right'>$countStr</td>\n";
        $s .= "<td align='right'> &nbsp; </td>\n";
    }

    my $countStr = getMergedSumStr_new( $stats_ref, $domain, "Total" );
    $s .= "<td align='right'>$countStr</td>\n";

    $s .= "</tr>\n";
    return $s;
}

############################################################################
# getCountStr - Get finished/draft counts, handle hyperlinks.
#   Inputs:
#     stats_ref - stats data reference
#     domain - taxonomic domain
#     seq_center - sequencing center
############################################################################
# new for v2.9
sub getCountStr {
    my ( $stats_ref, $domain, $seq_center, $genome_type ) = @_;
    my $rec0 = "$domain\t";
    $rec0 .= "$seq_center\t";
    my $rec_finished = "$rec0";
    $rec_finished .= "Finished";
    my $rec_draft = "$rec0";
    $rec_draft .= "Draft";
    my $rec_pdraft = "$rec0";
    $rec_pdraft .= "Permanent Draft";

    my $finished_count = $stats_ref->{$rec_finished};
    $finished_count = 0 if $finished_count eq "";
    my $draft_count = $stats_ref->{$rec_draft};
    $draft_count = 0 if $draft_count eq "";

    my $pdraft_count = $stats_ref->{$rec_pdraft};
    $pdraft_count = 0 if $pdraft_count eq "";

    my $rowSum = $finished_count + $draft_count + $pdraft_count;

    my $finished_count_str = $finished_count;
    my $draft_count_str    = $draft_count;
    my $pdraft_count_str   = $pdraft_count;

    #my $url0 = getTreeUrl( $domain, "" );
    my $url0 = getTableUrl( $domain, "" );

    my $urlMetag = "$main_cgi?section=TaxonList" . "&page=restrictedMicrobes&domain=$domain&mainPageStats=1";

    if ( $finished_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Finished";
        } else {
            $url = "$url0&seq_status=Finished";
        }
        $finished_count_str = alink( $url, $finished_count );
    }
    if ( $draft_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Draft";
        } else {
            $url = "$url0&seq_status=Draft";
        }
        $draft_count_str = alink( $url, $draft_count );
    }
    if ( $pdraft_count > 0 ) {
        my $url;
        if ( $genome_type eq "metagenome" ) {
            if ( $seq_center eq "JGI" ) {
                $url = "$urlMetag&seq_center=JGI&seq_status=Permanent Draft";
            } else {
                $url = "$urlMetag&seq_status=Permanent Draft";
            }
        } else {
            if ( $seq_center eq "JGI" ) {
                $url = "$url0&seq_center=JGI&seq_status=Permanent Draft";
            } else {
                $url = "$url0&seq_status=Permanent Draft";
            }
        }
        $pdraft_count_str = alink( $url, $pdraft_count );
    }
    my $rowSum_str = "0";
    if ( $rowSum > 0 ) {
        my $url = "$url0";
        $rowSum_str = alink( $url, $rowSum );
    }

    if($domain eq 'Bacteria') {
        my $url = 'main.cgi?section=GenomeList&page=phylumList&domain=Bacteria&type=phylum';
        $rowSum_str = alink( $url, $rowSum );
    }

    return ( "$finished_count_str/$draft_count_str/$pdraft_count_str", $rowSum_str );
}

############################################################################
# getSumStr - Get finished/draft counts, handle hyperlinks.
#   This is done for "All Genomes", bottom line.
#   Inputs:
#     stats_ref - stats data reference
#     domain - taxonomic domain
#     seq_center - sequencing center
############################################################################
sub getSumStr {
    my ( $stats_ref, $domain, $seq_center ) = @_;
    my $rec0 = "$domain\t";
    $rec0 .= "$seq_center\t";
    my $rec_finished = "$rec0";
    $rec_finished .= "Finished";
    my $rec_draft = "$rec0";
    $rec_draft .= "Draft";

    my $finished_count = $stats_ref->{$rec_finished};
    $finished_count = 0 if $finished_count eq "";
    my $draft_count = $stats_ref->{$rec_draft};
    $draft_count = 0 if $draft_count eq "";

    my $rowSum = $finished_count + $draft_count;

    my $finished_count_str = $finished_count;
    my $draft_count_str    = $draft_count;
    my $url0               = "$main_cgi?section=TaxonList&page=restrictedMicrobes";
    $url0 .= "&mainPageStats=1";
    if ( $finished_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Finished";
        } else {
            $url = "$url0&seq_status=Finished";
        }
        $finished_count_str = alink( $url, $finished_count );
    }
    if ( $draft_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Draft";
        } else {
            $url = "$url0&seq_status=Draft";
        }
        $draft_count_str = alink( $url, $draft_count );
    }
    return ( "$finished_count_str/$draft_count_str", $rowSum );
}

# v2.9 tree
sub getSumStr_new {
    my ( $stats_ref, $domain, $seq_center ) = @_;
    my $rec0 = "$domain\t";
    $rec0 .= "$seq_center\t";
    my $rec_finished = "$rec0";
    $rec_finished .= "Finished";
    my $rec_draft = "$rec0";
    $rec_draft .= "Draft";
    my $rec_pdraft = "$rec0";
    $rec_pdraft .= "Permanent Draft";

    my $finished_count = $stats_ref->{$rec_finished};
    $finished_count = 0 if $finished_count eq "";
    my $draft_count = $stats_ref->{$rec_draft};
    $draft_count = 0 if $draft_count eq "";

    my $pdraft_count = $stats_ref->{$rec_pdraft};
    $pdraft_count = 0 if $pdraft_count eq "";

    my $rowSum = $finished_count + $draft_count + $pdraft_count;

    my $finished_count_str = $finished_count;
    my $draft_count_str    = $draft_count;
    my $pdraft_count_str   = $pdraft_count;

    #my $url0 = getTreeUrl($domain, "");
    my $url0 = getTableUrl( $domain, "" );

    if ( $finished_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Finished";
        } else {
            $url = "$url0&seq_status=Finished";
        }
        $finished_count_str = alink( $url, $finished_count );
    }
    if ( $draft_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Draft";
        } else {
            $url = "$url0&seq_status=Draft";
        }
        $draft_count_str = alink( $url, $draft_count );
    }
    if ( $pdraft_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI&seq_status=Permanent Draft";
        } else {
            $url = "$url0&seq_status=Permanent Draft";
        }
        $pdraft_count_str = alink( $url, $pdraft_count );
    }

    return ( "$finished_count_str/$draft_count_str/$pdraft_count_str", $rowSum );
}

############################################################################
# getMergedSumStr - Get finished/draft counts, handle hyperlinks.
#   This is done for "All Genomes", bottom line.
#   Inputs:
#     stats_ref - stats data reference
#     domain - taxonomic domain
#     seq_center - sequencing center
############################################################################
sub getMergedSumStr {
    my ( $stats_ref, $domain, $seq_center ) = @_;
    my $rec0 = "$domain\t";
    $rec0 .= "$seq_center\t";
    my $rec_finished = "$rec0";
    $rec_finished .= "Finished";
    my $rec_draft = "$rec0";
    $rec_draft .= "Draft";

    my $finished_count = $stats_ref->{$rec_finished};
    $finished_count = 0 if $finished_count eq "";
    my $draft_count = $stats_ref->{$rec_draft};
    $draft_count = 0 if $draft_count eq "";

    my $comb_count     = $finished_count + $draft_count;
    my $comb_count_str = $comb_count;
    my $url0           = "$main_cgi?section=TaxonList&page=restrictedMicrobes";
    $url0 .= "&mainPageStats=1";
    if ( $comb_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI";
        } else {
            $url = "$url0";
        }
        $comb_count_str = alink( $url, $comb_count );
    }
    return $comb_count_str;
}

# new for v2.9 tree
sub getMergedSumStr_new {
    my ( $stats_ref, $domain, $seq_center ) = @_;
    my $rec0 = "$domain\t";
    $rec0 .= "$seq_center\t";
    my $rec_finished = "$rec0";
    $rec_finished .= "Finished";
    my $rec_draft = "$rec0";
    $rec_draft .= "Draft";
    my $rec_pdraft = "$rec0";
    $rec_pdraft .= "Permanent Draft";

    my $finished_count = $stats_ref->{$rec_finished};
    $finished_count = 0 if $finished_count eq "";
    my $draft_count = $stats_ref->{$rec_draft};
    $draft_count = 0 if $draft_count eq "";

    my $pdraft_count = $stats_ref->{$rec_pdraft};
    $pdraft_count = 0 if $pdraft_count eq "";

    my $comb_count     = $finished_count + $draft_count + $pdraft_count;
    my $comb_count_str = $comb_count;

    
    my $url0 = getTableUrl( $domain, "" );
    $url0 = getTreeUrl($domain, "") if ($domain eq 'All Genomes');

    if ( $comb_count > 0 ) {
        my $url;
        if ( $seq_center eq "JGI" ) {
            $url = "$url0&seq_center=JGI";
        } else {
            $url = "$url0";
        }
        $comb_count_str = alink( $url, $comb_count );
    }
    return $comb_count_str;
}
############################################################################
# replaceStatTableRows - Replace template string for stat table rows.
############################################################################
# new
sub replaceStatTableRows {
    my $hmp = "";

    #
    # SEE HmpTaxonList::printTaxonList query for major body site
    #
    my %major_body_site = (
        'Airways'                => 0,
        'Gastrointestinal tract' => 0,
        'Oral'                   => 0,
        'Skin'                   => 0,
        'Urogenital tract'       => 0,
        $OTHER                   => 0,
    );

    # hmp stats - where do the count links go?
    if ($img_hmp) {
        my $dbh     = dbLogin();
        my $dbhgold = WebUtil::dbGoldLogin();

        my $data_href = getHmpStats_new( $dbh, $dbhgold );

        #$dbh->disconnect();
        #$dbhgold->disconnect();

        # get all body_site cat.
        my %body_site_total_cnt = %major_body_site;    # cat. => total count
        my %body_site_iso_cnt   = %major_body_site;    # cat. => hmp isolate count
        my %body_site_metag_cnt = %major_body_site;    # cat. => hmp metag count

        foreach my $key ( keys %$data_href ) {
            my $tmp_href = $data_href->{$key};

            my $body_site    = $tmp_href->{body_site};
            my $show_in_dacc = $tmp_href->{show_in_dacc};
            my $genome_type  = $tmp_href->{genome_type};

            next if ( $body_site eq "" );

            if ( exists $body_site_total_cnt{$body_site} ) {
                $body_site_total_cnt{$body_site} = $body_site_total_cnt{$body_site} + 1;
            } else {
                $body_site_total_cnt{$OTHER} = $body_site_total_cnt{$OTHER} + 1;
            }

            if ( $genome_type eq "isolate" && lc($show_in_dacc) eq "yes" ) {
                if ( exists $body_site_iso_cnt{$body_site} ) {
                    $body_site_iso_cnt{$body_site} = $body_site_iso_cnt{$body_site} + 1;
                } else {
                    $body_site_iso_cnt{$OTHER} = $body_site_iso_cnt{$OTHER} + 1;
                }
            } elsif ( lc($show_in_dacc) eq "yes" ) {
                if ( exists $body_site_metag_cnt{$body_site} ) {
                    $body_site_metag_cnt{$body_site} = $body_site_metag_cnt{$body_site} + 1;
                } else {
                    $body_site_metag_cnt{$OTHER} = $body_site_metag_cnt{$OTHER} + 1;
                }
            }
        }

        my @color = ( "#ff99aa", "#ffcc00", "#99cc66", "#99ccff", "#ffdd99", "#bbbbbb" );
        my $x;
        my $i               = 0;
        my $total_iso_cnt   = 0;
        my $total_metag_cnt = 0;
        my $total_all_cnt   = 0;
        foreach my $name ( sort keys %body_site_total_cnt ) {

            my $display_name = $name;
            $display_name = "Other" if ( $display_name eq $OTHER );

            my $totalCnt = $body_site_total_cnt{$name};
            my $isoCnt   = $body_site_iso_cnt{$name};
            my $metagCnt = $body_site_metag_cnt{$name};
            $isoCnt   = 0 if ( $isoCnt   eq "" );
            $metagCnt = 0 if ( $metagCnt eq "" );

            my $tmp = $i % 6;    # for 6 possible colors

            $total_iso_cnt   = $total_iso_cnt + $isoCnt;
            $total_metag_cnt = $total_metag_cnt + $metagCnt;
            $total_all_cnt   = $total_all_cnt + $totalCnt;

            my $url1 = "$main_cgi?section=HmpTaxonList&page=list&funded=all&genome_type=all&body_site=$name";
            my $url2 = "$main_cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=isolate&body_site=$name";
            my $url3 = "$main_cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=metag&body_site=$name";

            $isoCnt   = alink( $url2, $isoCnt )   if ( $isoCnt != 0 );
            $metagCnt = alink( $url3, $metagCnt ) if ( $metagCnt != 0 );
            $totalCnt = alink( $url1, $totalCnt ) if ( $totalCnt != 0 );

            if ($include_metagenomes) {
                $x .= qq{
<tr bgcolor=$color[$tmp]>               
<td> $display_name </td>
<td align='right' style="padding-right: 5px;" > $isoCnt </td>
<td align='right'> $metagCnt </td>
</tr>  
            };

                #            $x .= qq{
                #<tr bgcolor=$color[$tmp]>
                #<td> $display_name </td>
                #<td align='right' style="padding-right: 5px;" > $isoCnt / $metagCnt  </td>
                #<td align='right'> $totalCnt </td>
                #</tr>
                #            };
            } else {
                $x .= qq{
<tr bgcolor=$color[$tmp]>               
<td> $display_name </td>
<td align='right' style="padding-right: 5px;"> $isoCnt </td>
<td align='right'> $totalCnt </td>
</tr>  
            };
            }

            $i++;
        }

        my $url1 = "$main_cgi?section=HmpTaxonList&page=list&funded=all&genome_type=all";
        my $url2 = "$main_cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=isolate";
        my $url3 = "$main_cgi?section=HmpTaxonList&page=list&funded=hmp&genome_type=metag";

        $total_iso_cnt   = alink( $url2, $total_iso_cnt )   if ( $total_iso_cnt != 0 );
        $total_metag_cnt = alink( $url3, $total_metag_cnt ) if ( $total_metag_cnt != 0 );
        $total_all_cnt   = alink( $url1, $total_all_cnt )   if ( $total_all_cnt != 0 );

        $x .= qq{
<tr>               
<td title='Count of distinct projects'> <b>Total </b> </td>
        };
        if ($include_metagenomes) {

            #            $x .= qq{
            #<td align='right' style="padding-right: 5px;" >  $total_iso_cnt / $total_metag_cnt </td>
            #        };
            $x .= qq{
<td align='right' style="padding-right: 5px;" >  $total_iso_cnt </td>
<td align='right' >  $total_metag_cnt </td>
        };

        } else {
            $x .= qq{
<td align='right' style="padding-right: 5px;" >  $total_iso_cnt </td>
        };
        }

        if ( !$include_metagenomes ) {
            $x .= qq{
<td align='right'>  $total_all_cnt </td>
</tr> 
       };
        }
        $hmp = $x;
    }

    my $x;
    my %stats = mainPageStats();

    $x .= tableRowStats( \%stats, "Bacteria" );
    $x .= tableRowStats( \%stats, "Archaea" );
    $x .= tableRowStats( \%stats, "Eukaryota" );
    $x .= tableRowStats( \%stats, "Plasmids" ) if $include_plasmids;
    $x .= tableRowStats( \%stats, "Viruses" );
    $x .= tableRowStats( \%stats, "Genome Fragments" );
    $x .= tableRowStats( \%stats, "*Microbiome", "metagenome" )
      if $include_metagenomes;

    if ($include_metagenomes) {
        $x .= tableRowSumStats_new( \%stats, "All Genomes" );
    } else {

        # normal img system
        $x .= tableRowSumStats_new( \%stats, "All Genomes" );
    }

    $x .= tablePrivateGenomeStats();

#    if ($img_geba) {
#
#        #print "replaceStatTableRows() start getGebaStats()<br/>\n";
#        $x .= getGebaStats();
#
#        #print "replaceStatTableRows() done getGebaStats()<br/>\n";
#    }

    return ( $x, $hmp );
}

# 1 - get all genomes from img isolates and metagenomes
sub getHmpStats_new {
    my ($dbh) = @_;

    # hash of taxon oid => hash of metadata => value
    my %datahash;

    # from gold get isolate meta data
    my $sql = qq{
select t.taxon_oid, t.gold_id, t.sample_gold_id, t.submission_id, t.genome_type, 
p.project_oid, p.gold_stamp_id, nvl(p.hmp_isolation_bodysite, '$OTHER'), p.show_in_dacc
from taxon t, project_info_gold p
where t.gold_id = p.gold_stamp_id
and t.is_public = 'Yes'
and t.obsolete_flag = 'No'
and p.hmp_id is not null
and t.domain in ('Bacteria', 'Archaea' ,'Eukaryota')
and p.host_name = '$HOST_NAME'
        };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
            $taxon_oid,   $gold_id,       $sample_gold_id, $submission_id, $genome_type,
            $project_oid, $gold_stamp_id, $body_site,      $show_in_dacc
          )
          = $cur->fetchrow();
        last if !$taxon_oid;
        my %tmphash = (
            taxon_oid      => $taxon_oid,
            gold_id        => $gold_id,
            sample_gold_id => $sample_gold_id,
            submission_id  => $submission_id,
            genome_type    => $genome_type,
            project_oid    => $project_oid,
            body_site      => $body_site,
            show_in_dacc   => $show_in_dacc,

        );
        $datahash{$taxon_oid} = \%tmphash;
    }
    $cur->finish();

    # metagenomes
    # TODO hard coded project id for
    if ($include_metagenomes) {
        my $sql = qq{
select t.taxon_oid, t.gold_id, t.sample_gold_id, t.submission_id, t.genome_type, 
p.project_oid, es.gold_id, nvl(es.body_site, '$OTHER'), p.show_in_dacc
from project_info_gold p, env_sample_gold es, taxon t
where p.project_oid = es.project_info
and es.host_name = '$HOST_NAME'
and es.gold_id = t.sample_gold_id
and t.is_public = 'Yes'
and t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and p.project_oid = 18646
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my (
                $taxon_oid,   $gold_id,       $sample_gold_id, $submission_id, $genome_type,
                $project_oid, $gold_stamp_id, $body_site,      $show_in_dacc
              )
              = $cur->fetchrow();
            last if !$taxon_oid;
            my %tmphash = (
                taxon_oid      => $taxon_oid,
                gold_id        => $gold_id,
                sample_gold_id => $sample_gold_id,
                submission_id  => $submission_id,
                genome_type    => $genome_type,
                project_oid    => $project_oid,
                body_site      => $body_site,
                show_in_dacc   => 'Yes',

            );
            $datahash{$taxon_oid} = \%tmphash;

        }
        $cur->finish();
    }

    return \%datahash;
}

# geba stats
sub getGebaStats {
    my $dbh = dbLogin();

    # use c2.username = 'GEBA' causing invalid username/password
    # use c1.contact_oid = c2.contact_oid = 3031 instead
    my $sql = qq{
        select t.seq_status, count(distinct t.taxon_oid)
        from taxon t, contact_taxon_permissions c1
        where c1.contact_oid = 3031
        and c1.taxon_permissions = t.taxon_oid
        and t.obsolete_flag = 'No'
        group by t.seq_status
    };

    my %geba_counts;
    my $cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $seq_status, $seq_cnt ) = $cur->fetchrow();
        last if ( !$seq_status );
        $geba_counts{$seq_status} = $seq_cnt;
        $cnt += $seq_cnt;
    }
    $cur->finish();

    #$dbh->disconnect();

    # Draft
    my $dcnt     = $geba_counts{"Draft"};
    my $durl     = "$main_cgi?section=TaxonList&page=gebaList&seq_status=Draft&mainPageStats=1";
    my $dcntLink = alink( $durl, $dcnt );

    # Finished
    my $fcnt     = $geba_counts{"Finished"};
    my $furl     = "$main_cgi?section=TaxonList&page=gebaList&seq_status=Finished&mainPageStats=1";
    my $fcntLink = alink( $furl, $fcnt );

    # Permanent Draft
    my $pdcnt     = $geba_counts{"Permanent Draft"};
    my $pdurl     = "$main_cgi?section=TaxonList&page=gebaList&seq_status=Permanent Draft&mainPageStats=1";
    my $pdcntLink = alink( $pdurl, $pdcnt );
    $pdcntLink = 0 if ( $pdcnt == 0 || $pdcnt eq "" );

    # total
    my $url     = "$main_cgi?section=TaxonList&page=gebaList&mainPageStats=1";
    my $cntLink = alink( $url, $cnt );

    my $s = "<tr>\n";
    $s .= "<td>GEBA</td>\n";

    if ($img_hmp) {
        $s .= "<td align='right'> &nbsp; </td>\n";
    } else {
        #### Individual totals removed for IMG 3.5 -BSJ 08/02/11
        # $s .= "<td align='right'> $fcntLink/$dcntLink/$pdcntLink </td>\n";
        $s .= "<td align='right'> &nbsp; </td>\n";
    }
    $s .= "<td align='right'> $cntLink </td>\n";
    $s .= "</tr>\n";

    return $s;
}

#
# get proPortal stats
sub getProPortalStats {
    my $dbh = dbLogin();

    my @color = ( "#ff99aa", "#ffcc00", "#99cc66", "#99ccff", "#ffdd99", "#bbbbbb" );
    my @list = ( 'prochlorococcus', 'synechococcus', 'cyanophage' );
    my %counts = ( 'prochlorococcus' => 0, 'synechococcus' => 0, 'cyanophage' => 0 );

    my $sql = qq{
select 'prochlorococcus', t.taxon_oid, t.domain, t.taxon_display_name
from taxon t
where lower(t.GENUS) like '%prochlorococcus%'
and t.obsolete_flag = 'No'
and t.is_public     = 'Yes'
union
select 'synechococcus', t.taxon_oid, t.domain, t.taxon_display_name
from taxon t
where lower(t.GENUS) like '%synechococcus%'
and t.obsolete_flag = 'No'
and t.is_public     = 'Yes'
union
select 'cyanophage', t.taxon_oid,  t.domain, t.taxon_display_name
from taxon t
where (lower(t.taxon_display_name) like '%cyanophage%'
or lower(t.taxon_display_name) like '%prochlorococcus phage%'
or lower(t.taxon_display_name) like '%synechococcus phage%')
and t.obsolete_flag = 'No'
and t.is_public     = 'Yes'
     };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $class, $taxon_oid, $domain, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        if($class eq 'prochlorococcus') {
            $counts{prochlorococcus} = $counts{prochlorococcus} + 1; 
        } elsif($class eq 'synechococcus') {
            $counts{synechococcus} = $counts{synechococcus} + 1;
        } elsif($class eq 'cyanophage') {
            $counts{cyanophage} = $counts{cyanophage} + 1;
        }
    }
    $cur->finish();


    my $str;
    my $i               = 0;
    foreach my $x (@list) {
        my $cnt = $counts{$x};
        my $name = ucfirst($x);
        my $tmp = $i % 6;    # for 6 possible colors
        
        my $url = "main.cgi?section=ProPortal&page=genomeList&class=$x";
        $url = alink($url, $cnt);
        $str .= qq{<tr bgcolor=$color[$tmp]><td>$name</td><td align='right'>$url</td></tr> };
        $i++;
    }
    return $str;
}

############################################################################
# tablePrivateGenomeStats - Show stats for private genomes.
############################################################################
sub tablePrivateGenomeStats {

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();

    return "" if !$contact_oid;
    return "" if !$user_restricted_site;

    my $dbh = dbLogin();

    my $username = getUserName();

    my $tclause = "and ctp.contact_oid = $contact_oid";
    $tclause = "" if $super_user eq "Yes";
    my $imgclause = WebUtil::imgClause('tx');
    my $sql       = qq{
	select count( distinct ctp.taxon_permissions )
	from contact_taxon_permissions ctp, taxon tx
	where ctp.taxon_permissions = tx.taxon_oid
	and tx.is_public = 'No'
	$tclause
	$imgclause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

webLog("done my private genome sql \n");

    my $s = "<tr >\n";
    $s .= "<td colspan='2'>My Private Datasets</td>\n";
    my $url = "$main_cgi?section=TaxonList&page=privateGenomeList";
    my $cntLink = alink( $url, $cnt );
    $cntLink = $cnt if $cnt == 0;
    $s .= "<td align='right'>$cntLink</td>\n";
    $s .= "</tr>\n";

    #$dbh->disconnect();
    return $s;
}

1;

