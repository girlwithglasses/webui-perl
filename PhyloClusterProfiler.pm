############################################################################
# PhyloClusterProfiler.pm - Phylogenetic profiler, except using
#    IMG clusters.         --es 07/13/11
#
# $Id: PhyloClusterProfiler.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package PhyloClusterProfiler;
my $section = "PhyloClusterProfiler";

use strict;
use CGI qw( :standard );
use DBI;
use ScaffoldPanel;
use Data::Dumper;
use Time::localtime;
use LwpHandle;
use WebConfig;
use WebUtil;
use GzWrap;
use ChartUtil;
use InnerTable;
use HtmlUtil;
use TaxonTarDir;

$| = 1;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $tmp_url              = $env->{tmp_url};
my $base_url             = $env->{base_url};
my $base_dir             = $env->{base_dir};
my $ava_batch_dir        = $env->{ava_batch_dir};
my $avagz_batch_dir      = $env->{avagz_batch_dir};
my $ava_server_url       = $env->{ava_server_url};
my $bbh_ava_dir          = $env->{bbh_ava_dir};
my $taxon_stats_dir      = $env->{taxon_stats_dir};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $img_internal         = $env->{img_internal};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_lite             = $env->{img_lite};
my $full_phylo_profiler  = $env->{full_phylo_profiler};
my $user_restricted_site = $env->{user_restricted_site};
my $myimg_job 		 = $env->{myimg_job};
my $myimg_jobs_dir 	 = $env->{myimg_jobs_dir};
my $use_img_clusters     = $env->{use_img_clusters};
my $taxonCluster_zfiles_dir = $env->{taxonCluster_zfiles_dir};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};

my $phyloProfiler_sets_file;    # make obsolete
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";

my $max_taxon_candidates = 300;
my $max_page_rows        = 1000;
my $max_gene_batch       = 500;
my $maxGeneListResults   = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
    $max_page_rows      = $maxGeneListResults;
}

my $org_browser_link =
  alink( "$main_cgi?section=TaxonList&page=taxonListAlpha", "Genome Browser" );
my $preferences_link =
  alink( "$main_cgi?section=MyIMG&page=preferencesForm", "Preferences" );
my $errorMsg =
    "Too many genomes selected. "
  . nbsp(1)
  . "Go to the $org_browser_link and select fewer than the current "
  . "limit, or go to $preferences_link and change the limit.";

my %obsoleteGenes;
my %pseudoGenes;
my $nvl = getNvl();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes
    $numTaxon = 0 if ( $numTaxon eq "" );
    my $sid  = getContactOid();
    my $page = param("page");

    if ( $page eq "phyloProfileFormFull"
         || paramMatch("phyloProfilerFormFull") ne "" )
    {
        #printPhyloProfileFormFull();
        # I need to test to see if there are user selected / saved
        # genomes - if yes do not use cache pages at all!
        my $ans = 1;        # do not use cache pages if $ans
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {

                # start cached page - all genomes
               HtmlUtil::cgiCacheInitialize( $section);
                HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloProfileFormFull();

        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );

    } elsif( $page eq "phyloProfileFormJob" ) {
        printPhyloProfileFormJob( );
#    } elsif ( $page eq "phyloProfileFormLite"
#              || paramMatch("PhyloProfilerFormLite") ne "" )
#    {
#        printPhyloProfileFormLite();
    } elsif ( $page eq "phyloProfileRun" ) {
        printPhyloProfileRun();
    } elsif ( $page eq "phyloProfileResultsPage" ) {
        printPhyloProfileResultsPage();
    } elsif ( $page eq "phyloProfileResultStat" ) {
        printPhyloProfileResultStat();
    } elsif ( $page eq "tblast" ) {
        blast();
    } elsif ( $page eq "cogs" ) {
        printCogs();
    } elsif ( $page eq "pfam" ) {
        printPfam();
    } elsif ( $page eq "tigrfam" ) {
        printTigrfam();
    } elsif ( $page eq "cogGeneList" ) {
        printCogGeneList();
    } elsif ( $page eq "pfamGeneList" ) {
        printPfamGeneList();
    } elsif ( $page eq "tigrfamGeneList" ) {
        printTIGRfamGeneList();
    } else {
        # I need to test to see if there are user selected / saved
        # genomes - if yes do not use cache pages at all!
        my $ans = 1;    # do not use cache pages if $ans
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
               HtmlUtil::cgiCacheInitialize( $section);
                HtmlUtil::cgiCacheStart() or return;
            }
        }
        printPhyloProfileFormFull();

        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    }
}

sub blast {
    my $gene_oid = param("gene_oid");
    my $genomes = param("genomes");

    print "<font color='red'><blink>Running TBlast...</blink></font>\n";
    print "<p><br/>Genome ID(s): $genomes <br/>\n";
    print "Gene ID: $gene_oid<br/></p>\n";

    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.aa_residue
        from  gene g
        where g.gene_oid = ?        
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($aa_residue) = $cur->fetchrow();
    $cur->finish();
    my $seq = wrapSeq($aa_residue);

    print "<p>Gene Amino Acid Sequence <br/> $seq</p>";

    #$dbh->disconnect();

    print qq{
        <form method="post" action="main.cgi" name="findGeneBlast">
        
        
    };

    my @gen = split( /,/, $genomes );
    foreach my $id (@gen) {
        print qq{<input type="hidden" name='imgBlastDb' value='$id' />};
    }

    print qq{
    <input type="hidden" name='fasta' value='$seq' />
    <input type="hidden" name='section' value='FindGenesBlast' />
    <input type="hidden" name='page' value='geneSearchBlastForm' />
    <input type="hidden" name='blast_evalue' value='1e-5' />    
    <input type="hidden" name='blast_program' value='tblastn' />
    <input type="hidden" name='gene_oid' value='$gene_oid' />
    
    <br/>
    <input type="hidden" name='ffgGeneSearchBlast' value='ffgGeneSearchBlast' />
    </form>
    
    <script language='JavaScript' type="text/javascript">
    function mysubmit() {
        document.findGeneBlast.submit();
    }
    
    mysubmit();
    </script>
    };
}

############################################################################
# printPhyloProfileFormFull - Show initial query form for phylo profiler.
############################################################################
sub printPhyloProfileFormFull {
    my $taxon_filter_oid_str = getSessionParam("taxon_filter_oid_str");
    my $base_taxon_oid       = param("taxon_oid");

    my $dbh = dbLogin();

    printStatusLine( "Loading ...", 1 );

    ## IMG-lite Phylogenetic sets qualification
#    my $set       = param("set");
    my $setClause;
    my @bindList = ();
#    if ( $set ne "" ) {
#        my ( $has_std_ref_genomes, @set_taxon_oids ) =
#          loadSetTaxonOids2( $dbh, $set );
#        my $set_taxon_oid_str = join( ',', @set_taxon_oids );
#        $setClause .= "and( ";
#        if ( !blankStr($set_taxon_oid_str) ) {
#            $setClause .= "tx.taxon_oid in( $set_taxon_oid_str ) ";
#        }
#        my $or;
#        if ( !blankStr($set_taxon_oid_str) && $has_std_ref_genomes eq "Yes" ) {
#            $or = " or ";
#        }
#        if ( $has_std_ref_genomes eq "Yes" ) {
#            $setClause .= "$or tx.taxon_oid in( ";
#            $setClause .= "select std.taxon_oid from taxon std ";
#            $setClause .= "where std.is_std_reference = ? ) ";
#            push(@bindList, 'Yes');
#        }
#        $setClause .= ")";
#    }
    if ( $img_lite && $setClause eq "" && !$full_phylo_profiler ) {
        webError("No phylogenetic sets defined.");
    }

    printMainForm();

    if ($include_metagenomes) { 
	WebUtil::printHeaderWithInfo 
	    ("Phylogenetic Profiler using IMG Clusters", '', 
	     "show description for this tool", "PPIC Info", 1); 
    } else { 
	WebUtil::printHeaderWithInfo 
	    ("Phylogenetic Profiler using IMG Clusters", '', 
	     "show description for this tool", "PPIC Info"); 
    }     
    
    if ( $taxon_filter_oid_str eq "" ) {
        #webError( $errorMsg );
    }
    my $maxProfileCandidateTaxons =
      getSessionParam("maxProfileCandidateTaxons");
    $max_taxon_candidates = $maxProfileCandidateTaxons
      if $maxProfileCandidateTaxons ne "";
    my @all_taxon_oids = split( /,/, $taxon_filter_oid_str );
    if (    scalar(@all_taxon_oids) > $max_taxon_candidates
         || scalar(@all_taxon_oids) < 1 )
    {
        #webError( $errorMsg );
    }

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    if ($hideViruses eq "Yes") {
        $virusClause = "and tx.domain not like ? ";
        push(@bindList, 'Vir%');
    }

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    if ($hidePlasmids eq "Yes"){
        $plasmidClause = "and tx.domain not like ? ";
        push(@bindList, 'Plasmid%');
    }

    my $gFragmentClause = '';
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    if ($hideGFragment eq "Yes"){
        $gFragmentClause = "and tx.domain not like ? ";
        push(@bindList, 'GFragment%');
    }

    my $metagClause = "and tx.genome_type != ? ";

    # Metagenomes no longer listed 
    #$metagClause = "" if  $use_img_clusters; # Removed -BSJ 05/11/12
    if ($metagClause =~ /tx.genome_type/) {
        push(@bindList, 'metagenome');  	
    }

    my $taxonClause = txsClause("", $dbh);

    my ($rclause, @bindList_ur) = urClauseBind();
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);    	
    }
    
    my $baseClause = "";
    if($base_taxon_oid ne "") {
        $baseClause = "or tx.taxon_oid = ? ";
        push(@bindList, $base_taxon_oid);
    }
    
    my $imgClusterClause;
    if( $use_img_clusters ) {
       $imgClusterClause = "and tx.taxon_oid in " .
         "( select distinct taxon_oid from dt_taxon_img_cluster )";
    }

    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, 
          tx.genus, tx.species, tx.strain, 
	      tx.taxon_display_name, tx.taxon_oid,
	      b.display_name, b.bin_oid, tx.seq_status
       from taxon tx
       left join env_sample_gold es
         on tx.env_sample = es.sample_oid
       left join bin b
         on es.sample_oid = b.env_sample
       where 1 = 1
       $setClause
       $virusClause
       $plasmidClause
       $gFragmentClause
       $metagClause
       $taxonClause
       $rclause
       $imgClause
       $baseClause
       order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, 
          tx.genus, tx.species, tx.strain, tx.taxon_display_name, 
	      b.display_name
    };

    my %defaultBins;
    getDefaultBins( $dbh, \%defaultBins );
    
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_oid;

    for ( ; ; ) {
        my (
             $domain,             $phylum,    $ir_class,         $ir_order,
             $family,             $genus,     $species,          $strain,
             $taxon_display_name, $taxon_oid, $bin_display_name, $bin_oid,
             $seq_status
          )
          = $cur->fetchrow();
        last if !$domain;
	next if $domain =~ /Microbiome/i; # hide Microbiomes
        if ( $old_domain ne $domain ) {
            my $rec = "domain\t";
            $rec .= "$domain\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            push( @recs, $rec );
        }
        if ( $old_phylum ne $phylum ) {
            my $rec = "phylum\t";
            $rec .= "$phylum\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum";
            push( @recs, $rec );
        }
        if ( $old_genus ne $genus ) {
            my $rec = "genus\t";
            $rec .= "$genus\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus";
            push( @recs, $rec );
        }
        if ( $old_taxon_oid ne $taxon_oid ) {
            my $rec = "taxon_display_name\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            push( @recs, $rec );
        }
        if ( $bin_display_name ne "" && $defaultBins{$bin_oid} ) {
            my $rec = "bin_display_name\t";
            $rec .= "$bin_display_name\t";
            $rec .= "\t";                      # null __lineRange__
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            $rec .= "$bin_display_name\t";
            $rec .= "$bin_oid";
            push( @recs, $rec );
        }
        $old_domain             = $domain;
        $old_phylum             = $phylum;
        $old_genus              = $genus;
        $old_taxon_oid          = $taxon_oid;
    }
    my @recs2 = fillLineRange( \@recs );
    print "<p>\n";
    print "Find genes in genome (bin) of interest "
      . "qualified by common clusters in other genomes (bins).<br/>"
      . "Only user-selected genomes appear in the profiler.";
    print "</p>\n";

    printHint( "* You must select exactly one genome (bin) of interest in the "
               . "\"Find Genes In\" column.<br/>"
               . "- If you want to check for the absence of a gene in the "
               . "genome (bin) of interest, "
               . "select an alternate genome (bin) of interest." );

    print "<p>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";

    print "<table class='img'   border='1'>\n";
    print "<th class='img'>Find<br/>Genes<br/>In*</th>\n";
    print "<th class='img'>With<br/>Clusters<br/>In</th>\n";
    print "<th class='img'>Without<br/>Clusters<br/>In</th>\n";
    print "<th class='img'>Ignoring</th>\n";
    print "<th class='img'>Taxon Name</th>\n";
    my $count = 0;

    for my $r (@recs2) {
        $count++;
        my ( $type, $type_value, $lineRange, $domain, undef ) =
          split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my ( $line1, $line2 ) = split( /:/, $lineRange );
            print "<tr class='highlight'>\n";
            my $func = "selectPhyloProfileErr($count)";
            print "<td class='img' >\n";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='toi' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,1)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='P'/>\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,2)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='N'/>\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,3)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='0' />\n";
            print "</td>\n";
            my $sp;
            $sp = nbsp(2) if $type eq "phylum";
            $sp = nbsp(4) if $type eq "genus";
            print "<td class='img' nowrap>\n";
            print $sp;
            my $incr = '+0';
            $incr = "+1" if $type eq "domain";
            $incr = "+1" if $type eq "phylum";
            print "<font size='$incr'>\n";
            print "<b>\n";
            print escHtml($type_value);
            print "</b>\n";
            print "</font>\n";
            print "</td>\n";
            print "</tr>\n";
        } elsif ( $type eq "taxon_display_name" && $domain eq '*Microbiome' ) {
            my (
                 $type,      $type_value,         $lineRange,
                 $domain,    $phylum,             $genus,
                 $taxon_oid, $taxon_display_name, $seq_status
              )
              = split( /\t/, $r );
            my ( $line1, $line2 ) = split( /:/, $lineRange );
            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' name='profile$taxon_oid.0' "
              . "value='toi' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,1)";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='P' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,2)";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='N'  />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,3)";
            print "  <input type='radio' name='profile$taxon_oid.0' value='0' ";
            print "   checked  />\n";
            print "</td>\n";
            print "<td class='img' nowrap>\n";
            print nbsp(6);
            my $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print "<b>[ ";
            print alink( $url, $taxon_display_name );
            print " ]</b>";
            print "</td>\n";
            print "</tr>\n";
        } elsif ( $type eq "taxon_display_name" && $domain ne '*Microbiome' ) {
            my (
                 $type,      $type_value,         $lineRange,
                 $domain,    $phylum,             $genus,
                 $taxon_oid, $taxon_display_name, $seq_status
              )
              = split( /\t/, $r );
            $seq_status = substr( $seq_status, 0, 1 );
            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' name='profile$taxon_oid.0' "
              . "value='toi' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='P' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='N' />\n";
            print "</td>\n";
            print "<td class='img' nowrap>\n";
            print "  <input type='radio' name='profile$taxon_oid.0' value='0' ";
            print "   checked />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print nbsp(6);
            my $c;
            $c = "[$seq_status]" if $seq_status ne "";
            my $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print alink( $url, "$taxon_display_name" );
            print nbsp(1) . $c;
            print "</td>\n";
            print "</tr>\n";
        } elsif ( $type eq "bin_display_name" ) {
            my (
                 $type,             $type_value,         $lineRange,
                 $domain,           $phylum,             $genus,
                 $taxon_oid,        $taxon_display_name, $seq_status,
                 $bin_display_name, $bin_oid
              )
              = split( /\t/, $r );
            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' name='profile$taxon_oid.$bin_oid' "
              . "value='toi' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.$bin_oid' "
              . "value='P' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.$bin_oid' "
              . "value='N' />\n";
            print "</td>\n";
            print "<td class='img' nowrap>\n";
            print "  <input type='radio' name='profile$taxon_oid.$bin_oid' "
              . "value='0'  checked />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print nbsp(8);
            my $url =
                "$main_cgi?section=Metagenome"
              . "&page=binDetail&bin_oid=$bin_oid";
            print alink( $url, $bin_display_name );
            print "</td>\n";
            print "</tr>\n";
        }
    }
    print "</table>\n";

    print "<p>\n";
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "phyloProfileRun" );
    print submit( -class => 'smdefbutton', -name => 'submit', -value => 'Go' );
    print nbsp(1);
    print reset( -class => 'smbutton' );

    #$dbh->disconnect();
    printStatusLine( "$count rows loaded.", 2 );
    printJavaScript();

    print end_form();
}

############################################################################
# printPhyloProfileFormJob - Job submission results version.
############################################################################
sub printPhyloProfileFormJob {
    my $taxon_filter_oid_str = getSessionParam("taxon_filter_oid_str");
    my $base_taxon_oid       = param("taxon_oid");
    my $my_job_id            = param("my_job_id");

    my $dbh = dbLogin();

    printStatusLine( "Loading ...", 1 );

    printMainForm();

    my $setClause;
    my @bindList = ();

    my $sql = qq{
       select p.img_job_id, p.param_type, p.param_value
       from myimg_job_parameters p
       where p.img_job_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $my_job_id );
    my $jobToi;
    my %jobPos;
    my %jobNeg;
    for( ;; ) {
       my( $img_job_id, $param_type, $param_value ) = $cur->fetchrow( );
       last if !$img_job_id;
       if( $param_type eq "toi" ) {
	  my( $taxon_oid, $bin ) = split( /\./, $param_value );
          $jobToi = $taxon_oid;
       }
       elsif( $param_type eq "posProfileTaxonBinOids" ) {
	  my( $taxon_oid, $bin ) = split( /\./, $param_value );
          $jobPos{ $taxon_oid } = 1;
       }
       elsif( $param_type eq "negProfileTaxonBinOids" ) {
	  my( $taxon_oid, $bin ) = split( /\./, $param_value );
          $jobNeg{ $taxon_oid } = 1;
       }
    }
    $cur->finish( );

    print "<h1>Phylogenetic Profiler for Job (ID:$my_job_id)</h1>\n";
    if ( $taxon_filter_oid_str eq "" ) {

        #webError( $errorMsg );
    }
    my $maxProfileCandidateTaxons =
      getSessionParam("maxProfileCandidateTaxons");
    $max_taxon_candidates = $maxProfileCandidateTaxons
      if $maxProfileCandidateTaxons ne "";
    my @all_taxon_oids = split( /,/, $taxon_filter_oid_str );
    if (    scalar(@all_taxon_oids) > $max_taxon_candidates
         || scalar(@all_taxon_oids) < 1 )
    {

        #webError( $errorMsg );
    }

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    if ($hideViruses eq "Yes") {
        $virusClause = "and tx.domain not like ? ";
        push(@bindList, 'Vir%');
    }

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    if ($hidePlasmids eq "Yes"){
        $plasmidClause = "and tx.domain not like ? ";
        push(@bindList, 'Plasmid%');
    }

    my $gFragmentClause = '';
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    if ($hideGFragment eq "Yes"){
        $gFragmentClause = "and tx.domain not like ? ";
        push(@bindList, 'GFragment%');
    }

    my $metagClause;
    my $taxonClause = txsClause("", $dbh);

    my ($rclause, @bindList_ur) = urClauseBind();
    if (scalar(@bindList_ur) > 0) {
        push (@bindList, @bindList_ur);    	
    }
    
    my $baseClause = "";
    if($base_taxon_oid ne "") {
        $baseClause = "or tx.taxon_oid = ? ";
        push(@bindList, $base_taxon_oid);
    }
    
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, 
          tx.genus, tx.species, tx.strain, 
	      tx.taxon_display_name, tx.taxon_oid,
	      b.display_name, b.bin_oid, tx.seq_status
       from taxon tx
       left join env_sample_gold es
         on tx.env_sample = es.sample_oid
       left join bin b
         on es.sample_oid = b.env_sample
       where 1 = 1
       $setClause
       $virusClause
       $plasmidClause
       $gFragmentClause
       $taxonClause
       $metagClause
       $rclause
       $imgClause
       $baseClause
       order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, 
          tx.genus, tx.species, tx.strain, tx.taxon_display_name, 
	      b.display_name
    };

    my %defaultBins;
    getDefaultBins( $dbh, \%defaultBins );
    
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_display_name;
    my $old_taxon_oid;

    for ( ; ; ) {
        my (
             $domain,             $phylum,    $ir_class,         $ir_order,
             $family,             $genus,     $species,          $strain,
             $taxon_display_name, $taxon_oid, $bin_display_name, $bin_oid,
             $seq_status
          )
          = $cur->fetchrow();
        last if !$domain;
	next if $taxon_oid ne $jobToi && 
	     !$jobPos{ $taxon_oid } && !$jobNeg{ $taxon_oid };
	        
        if ( $old_domain ne $domain ) {
            my $rec = "domain\t";
            $rec .= "$domain\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            push( @recs, $rec );
        }
        if ( $old_phylum ne $phylum ) {
            my $rec = "phylum\t";
            $rec .= "$phylum\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum";
            push( @recs, $rec );
        }
        if ( $old_genus ne $genus ) {
            my $rec = "genus\t";
            $rec .= "$genus\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus";
            push( @recs, $rec );
        }

        if ( $old_taxon_oid ne $taxon_oid ) {
            my $rec = "taxon_display_name\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            push( @recs, $rec );
        }
        if ( $bin_display_name ne "" && $defaultBins{$bin_oid} ) {
            my $rec = "bin_display_name\t";
            $rec .= "$bin_display_name\t";
            $rec .= "\t";                      # null __lineRange__
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            $rec .= "$bin_display_name\t";
            $rec .= "$bin_oid";
            push( @recs, $rec );
        }
        $old_domain             = $domain;
        $old_phylum             = $phylum;
        $old_genus              = $genus;
        $old_taxon_display_name = $taxon_display_name;
        $old_taxon_oid          = $taxon_oid;
    }
    my @recs2 = fillLineRange( \@recs );
    print "<p>\n";
    print "Find genes in genome (bin) of interest "
      . "qualified by similarity to sequences in other genomes "
      . "(based on common clusters).<br/>Only user-selected genomes "
      . "appear in the profiler.";
    print "</p>\n";

    printHint( "* You must select exactly one genome (bin) of interest in the "
               . "\"Find Genes In\" column.<br/>"
               . "- If you want to check for the absence of a gene in the "
               . "genome (bin) of interest, "
               . "select an alternate genome (bin) of interest." );

    print "<p>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";

    print "<table class='img'   border='1'>\n";
    print "<th class='img'>Find<br/>Genes<br/>In*</th>\n";
    print "<th class='img'>With<br/>Homologs<br/>In</th>\n";
    print "<th class='img'>Without<br/>Homologs<br/>In</th>\n";
    print "<th class='img'>Ignoring</th>\n";
    print "<th class='img'>Taxon Name</th>\n";
    my $count = 0;

    for my $r (@recs2) {
        $count++;
        my ( $type, $type_value, $lineRange, $domain, undef ) =
          split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my ( $line1, $line2 ) = split( /:/, $lineRange );
            print "<tr class='highlight'>\n";
            my $func = "selectPhyloProfileErr($count)";
            print "<td class='img' >\n";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='toi' />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,1)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='P'/>\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,2)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='N'/>\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,3)";
            print "  <input type='radio' onClick='$func' "
              . "name='groupProfile.$count' value='0' />\n";
            print "</td>\n";
            my $sp;
            $sp = nbsp(2) if $type eq "phylum";
            $sp = nbsp(4) if $type eq "genus";
            print "<td class='img' nowrap>\n";
            print $sp;
            my $incr = '+0';
            $incr = "+1" if $type eq "domain";
            $incr = "+1" if $type eq "phylum";
            print "<font size='$incr'>\n";
            print "<b>\n";
            print escHtml($type_value);
            print "</b>\n";
            print "</font>\n";
            print "</td>\n";
            print "</tr>\n";
        } elsif ( $type eq "taxon_display_name" && $domain eq '*Microbiome' ) {
            my (
                 $type,      $type_value,         $lineRange,
                 $domain,    $phylum,             $genus,
                 $taxon_oid, $taxon_display_name, $seq_status
              )
              = split( /\t/, $r );
	    my( $toiSelection, $posSelection, $negSelection, $nulSelection );
	    $toiSelection = "checked" if $taxon_oid eq $jobToi;
	    $posSelection = "checked" if $jobPos{ $taxon_oid };
	    $negSelection = "checked" if $jobNeg{ $taxon_oid };
	    $nulSelection = "checked" if $toiSelection eq "" &&
	       $posSelection eq "" && $negSelection eq "";
            my ( $line1, $line2 ) = split( /:/, $lineRange );
            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' name='profile$taxon_oid.0' "
              . "value='toi' $toiSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,1)";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='P' $posSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,2)";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='N'  $negSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            my $func = "selectPhyloGroupProfile($line1,$line2,3)";
            print "  <input type='radio' name='profile$taxon_oid.0' value='0' ";
            print "   $nulSelection  />\n";
            print "</td>\n";
            print "<td class='img' nowrap>\n";
            print nbsp(6);
            my $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print "<b>[ ";
            print alink( $url, $taxon_display_name );
            print " ]</b>";
            print "</td>\n";
            print "</tr>\n";
        } elsif ( $type eq "taxon_display_name" && $domain ne '*Microbiome' ) {
            my (
                 $type,      $type_value,         $lineRange,
                 $domain,    $phylum,             $genus,
                 $taxon_oid, $taxon_display_name, $seq_status
              )
              = split( /\t/, $r );
            $seq_status = substr( $seq_status, 0, 1 );
	    my( $toiSelection, $posSelection, $negSelection, $nulSelection );
	    $toiSelection = "checked" if $taxon_oid eq $jobToi;
	    $posSelection = "checked" if $jobPos{ $taxon_oid };
	    $negSelection = "checked" if $jobNeg{ $taxon_oid };
	    $nulSelection = "checked" if $toiSelection eq "" &&
	       $posSelection eq "" && $negSelection eq "";
            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' name='profile$taxon_oid.0' "
              . "value='toi' $toiSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='P' $posSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid.0' "
              . "value='N' $negSelection />\n";
            print "</td>\n";
            print "<td class='img' nowrap>\n";
            print "  <input type='radio' name='profile$taxon_oid.0' value='0' ";
            print "   $nulSelection />\n";
            print "</td>\n";
            print "<td class='img' >\n";
            print nbsp(6);
            my $c;
            $c = "[$seq_status]" if $seq_status ne "";
            my $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print alink( $url, "$taxon_display_name" );
            print nbsp(1) . $c;
            print "</td>\n";
            print "</tr>\n";
        }
    }
    print "</table>\n";

    ## Cutoff parameters
    print "<h2>Similarity Cutoffs</h2>\n";
    print "<table class='img'  border=1>\n";

    if( $img_internal ) {
        print "<tr class='img' >\n";
        print "<th class='subhead'>Comparison Method</th>\n";
        print "<td class='img' >\n";
        print popup_menu(
                      -name    => "compMethod",
                      -values  => [ "BLASTP Pairwise", "IMG Clusters" ],
        );
        print "</td>\n";
        print "</tr>\n";

        print "<tr class='img' >\n";
        print "<th class='subhead'>Max. Cluster Rank</th>\n";
        print "<td class='img' >\n";
        print popup_menu(
                      -name    => "max_bs_rank",
                      -values  => [ 10000, 1000, 100, 10, 5, 3, 2, 1 ],
        );
        print "</td>\n";
        print "</tr>\n";

        print "<tr class='img' >\n";
        print "<th class='subhead'>" .  
	   "Min. Cluster Top Bit Score Percentage</th>\n";
        print "<td class='img' >\n";
        print popup_menu(
                      -name    => "min_top_bs_perc",
                      -values  => [ 0, 25, 50, 75, 80, 85, 90, 95, 100  ],
        );
        print "</td>\n";
        print "</tr>\n";
    }

    #
    print "<tr class='img' >\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img' >\n";
    print popup_menu(
                      -name    => "evalue",
                      -values  => [ "1e-2", "1e-5", "1e-10" ],
                      -default => "1e-5"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "<tr class='img' >\n";
    if ($img_internal) {
        print "<th class='subhead'>Min. Amino Acid Percent Identity</th>\n";
    } else {
        print "<th class='subhead'>Min. Percent Identity</th>\n";
    }
    print "<td class='img' >\n";
    print popup_menu(
            -name   => "percIdent",
            -values => [ "10", "20", "30", "40", "50", "60", "70", "80", "90", "100" ],
            -default => "30"
    );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead' valig='top'>Exclude Pseudo Genes</th>\n";
    print "<td class='img'>\n";
    print popup_menu( -name   => "excludePseudo",
                      -values => [ "No", "Yes" ], );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead' valig='top'>Algorithm</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name    => "algorithm",
                      -values  => [ "presentAbsent", "percent" ],
                      -default => "presentAbsent",
                      -labels  => {
                                  presentAbsent => "By Present/Absent Homologs",
                                  percent => "By Taxon Percent With Homologs",
                      }
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Taxon Percent With Homologs</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name     => "percWithHomologs",
                      -values   => [ 100, 90, 80, 70, 60, 50, 40, 30, 20, 10 ],
                      -default  => 100,
                      -onChange => "setAlgorithm(1)"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Taxon Percent Without Homologs</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name     => "percWithoutHomologs",
                      -values   => [ 100, 90, 80, 70, 60, 50, 40, 30, 20, 10 ],
                      -default  => 100,
                      -onChange => "setAlgorithm(1)"
    );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    print "<p>\n";
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "phyloProfileRun" );
    print hiddenVar( "my_job_id", "$my_job_id" );
    print submit( -class => 'smdefbutton', -name => 'submit', -value => 'Go' );
    print nbsp(1);
    print reset( -class => 'smbutton' );

    #$dbh->disconnect();
    printStatusLine( "$count rows loaded.", 2 );
    printJavaScript();

    if ( $myimg_job ) {
	### add computation on demand
	print "<h2>Request Recomputation</h2>\n";
	print "<p>\n"; 
	print "You can request the phylogenetic profiler to be recomputed.\n";
	print "<p>User Notes:";
	print nbsp( 1 );
	print "<input type='text' name='user_notes' value='' " .
	    "size='60' maxLength='800' />\n";
	print "<br/>";
	my $name = "_section_MyIMG_computePhyloProfOnDemand";
	print submit(
		     -name  => $name,
		     -value => "Request Recomputation",
		     -class => "meddefbutton"
		     );
	print "</p>\n";
    }

    print end_form();
}

############################################################################
# printJavaScript - Print javascript for this module.
############################################################################
sub printJavaScript {
    print "<script langugae='JavaScript' type='text/javascript'>\n";
    my $s = qq{
        function setAlgorithm( idx ) {
	    document.mainForm.algorithm.selectedIndex = idx;
        }
   };
    print "$s\n";
    print "</script>\n";
}

############################################################################
# fillLineRange - Fill __lineRange__ paramater in record for javascript.
############################################################################
sub fillLineRange {
    my ($recs_ref) = @_;
    my @recs2;
    my $nRecs = @$recs_ref;
    for ( my $i = 0 ; $i < $nRecs ; $i++ ) {
        my $r = $recs_ref->[$i];
        my ( $type, $type_val, $lineRange, $domain, $phylum, $genus, $taxon_oid,
             $taxon_display_name )
          = split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain, $phylum, $genus,
                     $taxon_oid, $taxon_display_name )
                  = split( /\t/, $r2 );
                last if ( $domain ne $type_val ) && $type eq "domain";
                last if ( $phylum ne $type_val ) && $type eq "phylum";
                last if ( $genus  ne $type_val ) && $type eq "genus";
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        if ( $type eq "taxon_display_name" && $domain eq "*Microbiome" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain2, $phylum2,
                     $genus2, $taxon_oid2, $taxon_display_name2 )
                  = split( /\t/, $r2 );
                last if ( $taxon_oid ne $taxon_oid2 );
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        push( @recs2, $r );
    }
    return @recs2;
}

############################################################################
# printPhyloProfileRun - Run the form selection and show results.
############################################################################
sub printPhyloProfileRun {
    my @all_taxon_bin_oids0;
    my $dbh         = dbLogin();

    my @bindList = ();
    my $taxonClause = txsClause("tx", $dbh);
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
      select distinct tx.taxon_oid
      from taxon tx
      where 1 = 1
      $taxonClause
      $rclause
      $imgClause
      order by tx.taxon_oid
    };

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        my $taxon_bin_oid = "$taxon_oid.0";
        push( @all_taxon_bin_oids0, $taxon_bin_oid );
    }
    $cur->finish();
    
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select distinct tx.taxon_oid, b.bin_oid
       from taxon tx, env_sample_gold es, bin b
       where tx.env_sample = es.sample_oid
       $rclause
       $imgClause
       and es.sample_oid = b.env_sample
       and b.bin_oid > 0
       and b.is_default = ? 
       order by tx.taxon_oid, b.bin_oid
    };

    my $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
    for ( ; ; ) {
        my ( $taxon_oid, $bin_oid ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $taxon_bin_oid = "$taxon_oid.$bin_oid";
        push( @all_taxon_bin_oids0, $taxon_bin_oid );
    }
    $cur->finish();

    my $toi;
    my @all_taxon_bin_oids;
    my @posProfileTaxonBinOids;
    my @negProfileTaxonBinOids;
    for my $taxon_bin_oid (@all_taxon_bin_oids0) {
        my $profileVal = param("profile$taxon_bin_oid");
        next if $profileVal eq "0" || $profileVal eq "";
        webLog "profileVal='$profileVal' taxon_bin_oid='$taxon_bin_oid'\n"
          if $verbose >= 1;
        push( @all_taxon_bin_oids,     $taxon_bin_oid );
        push( @posProfileTaxonBinOids, $taxon_bin_oid ) if $profileVal eq "P";
        push( @negProfileTaxonBinOids, $taxon_bin_oid ) if $profileVal eq "N";
        if ( $toi eq "" && $profileVal eq "toi" ) {
            $toi = $taxon_bin_oid;
        } elsif ( $toi ne "" && $profileVal eq "toi" ) {
            webLog("bad toi='$toi'\n");
            webError(   "Please select only one genome (bin) "
                      . "in the \"Find Genes In\" column." );
            return;
        }
    }
    if ( $toi eq "" ) {
        webLog("bad toi='$toi'\n");
        webError(   "Please select exactly one genome (bin) "
                  . "in the \"Find Genes In\" column." );
        return;
    }
    my $evalue    = param("evalue");
    my $percIdent = param("percIdent");
    runJob( $dbh, $toi, \@posProfileTaxonBinOids, \@negProfileTaxonBinOids,
            $evalue, $percIdent );
    #$dbh->disconnect();
}

############################################################################
# runJob - Old version of "runJob" revamped.  (The old version was
#   actually an asynchronous batch process.  The new version is fast
#   enough so a long runnnig batch process is no longer necessary.
#   The the function name is still kept around, and probably  should
#   be revised someday.)
#   Inputs:
#      dbh - database handle
#      posProfileTaxonBinOids_ref - Positive profiles (intersecting homologs)
#      negProfileTaxonBinOids_ref - Negative profiles (substract homologs)
#      evalue - max. evalue cutoff
#      percIdent - min. percent identity
############################################################################
sub runJob {
    my ( $dbh, $toi, $posProfileTaxonBinOids_ref, $negProfileTaxonBinOids_ref,
         $evalue, $percIdent )
      = @_;

    my $algorithm           = param("algorithm");
    my $percWithHomologs    = param("percWithHomologs");
    my $percWithoutHomologs = param("percWithoutHomologs");
    my $excludePseudo       = param("excludePseudo");
    my $compMethod          = param("compMethod");
    my $doPercentage        = 0;
    if (    $algorithm eq "percent"
         && $percWithHomologs    ne ""
         && $percWithoutHomologs ne "" )
    {
        $doPercentage = 1;
    }
    my %toiGene2Desc;
    my %taxonBinOid2Genes;
    my %taxonBinOid2Name;
    my %h;
    my @pos_reference_oids;
    my @neg_reference_oids;
    my @all_taxon_bin_oids;
    
    # TODO add Percent Identity column - ken
    my %genesPercentages;

    for my $i (@$posProfileTaxonBinOids_ref) {
        push( @pos_reference_oids, $i );
        push( @all_taxon_bin_oids, $i );
    }
    for my $i (@$negProfileTaxonBinOids_ref) {
        push( @neg_reference_oids, $i );
        push( @all_taxon_bin_oids, $i );
    }

    print "<h1>Phylogenetic Profiler using Clusters - Gene Results</h1>\n";

    # stop if any zip file can not be found
    my @check_zfiles = ($toi);
    for my $id ( @all_taxon_bin_oids ) {
        push( @check_zfiles, $id );
    }
    for my $id ( @check_zfiles ) {
        my $zfilename = getClusterZfileName( $id );
        unless ( -e  $zfilename ) {
            my( $taxon_oid, undef ) = split( /\./, $id );
            webError("Genome $taxon_oid is missing cluster data file.");
        }
    }

    my $nTaxons   = @all_taxon_bin_oids;
    my $nPositive = @pos_reference_oids;
    my $nNegative = @neg_reference_oids;

    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $s = "Processing $nTaxons comparison(s).";
    if ($include_metagenomes) {
        $s .= " (Please be patient for large metagenomic sets.)";
    } else {
        $s .= " (Please be patient.)" if $nTaxons > 100;
    }
    print "$s<br/>\n";

    loadTaxonBinNames( $dbh, \%taxonBinOid2Name );
    loadObsoleteGenes($dbh);
    loadPseudoGenes($dbh) if $excludePseudo eq "Yes";

    ## Get Genome Of Interest gene information.
    my ( $toi_taxon_oid, $toi_bin_oid ) = split( /\./, $toi );

    my $pseudoClause;
    my @bindList_pseu = ();
    if ($excludePseudo eq "Yes") {
        $pseudoClause = "and g.is_pseudogene != ? ";
        push(@bindList_pseu, 'Yes');
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_taxon = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name, 
          g.aa_seq_length, gcg.cog, ge.enzymes, gpf.pfam_family, giih.id,
          gkt.ko_terms, gtf.ext_accession, gc.cassette_oid, kp.kegg_id,
          kp.pathway_name, km.module_name
       from gene g
       left join gene_cog_groups gcg
          on g.gene_oid = gcg.gene_oid
       left join gene_ko_enzymes ge
          on g.gene_oid = ge.gene_oid
       left join gene_pfam_families gpf 
          on g.gene_oid = gpf.gene_oid
       left join gene_xref_families giih
          on g.gene_oid = giih.gene_oid
       left join gene_ko_terms gkt
          on g.gene_oid = gkt.gene_oid
       left join gene_tigrfams gtf
          on g.gene_oid = gtf.gene_oid
       left join gene_cassette_genes gc
          on g.gene_oid = gc.gene
       left join image_roi_ko_terms irk
          on gkt.ko_terms = irk.ko_terms
       left join image_roi roi
          on irk.roi_id = roi.roi_id
       left join kegg_pathway kp
          on roi.pathway = kp.pathway_oid
       left join kegg_pathway_modules kpm
          on kp.pathway_oid = kpm.pathway_oid
       left join kegg_module km
          on kpm.modules = km.module_id
       where giih.db_name = 'InterPro'
       and g.taxon = ?
       $rclause
       $imgClause
       and g.locus_type = ?
       and g.obsolete_flag = ?
       $pseudoClause
    };

    my @bindList_taxon = ($toi_taxon_oid, 'CDS', 'No');
    if (scalar(@bindList_pseu) > 0) {
    	push(@bindList_taxon, @bindList_pseu);
    }
    
    ## No need to filter on default bins, since these were preselected
    #  from the form.  --es 01/26/2006

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_bin = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name, 
          g.aa_seq_length, gcg.cog, ge.enzymes, gpf.pfam_family, giih.id,
          gkt.ko_terms, gtf.ext_accession, gc.cassette_oid, kp.kegg_id,
          kp.pathway_name, km.module_name
       from bin b, bin_scaffolds bs, gene g
       left join gene_cog_groups gcg
          on g.gene_oid = gcg.gene_oid
       left join gene_ko_enzymes ge
          on g.gene_oid = ge.gene_oid
       left join gene_pfam_families gpf 
          on g.gene_oid = gpf.gene_oid
       left join gene_xref_families giih
          on g.gene_oid = giih.gene_oid
       left join gene_ko_terms gkt
          on g.gene_oid = gkt.gene_oid
       left join gene_tigrfams gtf
          on g.gene_oid = gtf.gene_oid
       left join gene_cassette_genes gc
          on g.gene_oid = gc.gene
       left join kegg_module_ko_terms kmt
          on gkt.ko_terms = kmt.ko_terms
       left join kegg_pathway_modules kpm
          on kmt.module_id = kpm.modules
       left join kegg_pathway kp
          on kpm.pathway_oid = kp.pathway_oid
       left join kegg_module km
          on kpm.modules = km.module_id
       where giih.db_name = 'InterPro'
       and g.taxon = ? 
       $rclause
       $imgClause
       and g.scaffold = bs.scaffold
       and bs.bin_oid = b.bin_oid
       and b.bin_oid = ? 
       and g.locus_type = ? 
       and g.obsolete_flag = ? 
       $pseudoClause
    };

    my @bindList_bin = ($toi_taxon_oid, $toi_bin_oid, 'CDS', 'No');
    if (scalar(@bindList_pseu) > 0) {
        push(@bindList_bin, @bindList_pseu);
    }

    my $sql;
    my @bindList;
    if ($toi_bin_oid > 0) {
    	$sql = $sql_bin;
        @bindList = @bindList_bin;
    }
    else {
    	$sql = $sql_taxon;
        @bindList = @bindList_taxon;    	
    }
    
    my $cur = execSqlBind( $dbh, $sql, \@bindList, 1 );
    
    $taxonBinOid2Genes{$toi} = {};
    my $count = 0;
    my %toiGene2Cog;
    my %toiGene2CogDone;
    my %toiGene2Enzyme;
    my %toiGene2EnzymeDone;
    my %toiGene2Pfam;
    my %toiGene2PfamDone;
    my %toiGene2Ipr;
    my %toiGene2IprDone;
    my %toiBinGenes;
    my %toiGene2Ko;
    my %toiGene2KoDone;
    my %toiGene2Tigrfam;
    my %toiGene2TigrfamDone;
    my %toiGene2Cassette;
    my %toiGene2CassetteDone;
    my %toiGene2Kegg;
    my %toiGene2KeggDone;
    my %toiGene2KeggName;
    my %toiGene2KeggModule;

    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_display_name, $aa_seq_length, $cog,
             $enzyme, $pfam, $ipr, $ko_id, $tigrfam, $cassette, $kegg,
	     $kegg_name, $kegg_module )
          = $cur->fetchrow();
        last if !$gene_oid;

        $count++;
        $toiBinGenes{$gene_oid} = 1;
        my $rec = "$gene_oid\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$locus_tag\t";
        $rec .= "$gene_display_name";
        $toiGene2Desc{$gene_oid} = $rec;
        $taxonBinOid2Genes{$toi}->{$gene_oid} = 1;

        if ( $cog ne "" && $toiGene2CogDone{"$gene_oid:$cog"} eq "" ) {
            $toiGene2Cog{$gene_oid} .= "$cog ";
            $toiGene2CogDone{"$gene_oid:$cog"} = 1;
        }
        if ( $enzyme ne "" && $toiGene2EnzymeDone{"$gene_oid:$enzyme"} eq "" ) {
            $toiGene2Enzyme{$gene_oid} .= "$enzyme ";
            $toiGene2EnzymeDone{"$gene_oid:$enzyme"} = 1;
        }
        if ( $pfam ne "" && $toiGene2PfamDone{"$gene_oid:$pfam"} eq "" ) {
            $toiGene2Pfam{$gene_oid} .= "$pfam ";
            $toiGene2PfamDone{"$gene_oid:$pfam"} = 1;
        }
        if (    $ipr ne ""
             && $ipr ne "NULL"
             && $toiGene2IprDone{"$gene_oid:$ipr"} eq "" )
        {
            $toiGene2Ipr{$gene_oid} .= "$ipr ";
            $toiGene2IprDone{"$gene_oid:$ipr"} = 1;
        }
        if ( $ko_id ne "" && $toiGene2KoDone{"$gene_oid:$ko_id"} eq "" ) {
            $toiGene2Ko{$gene_oid} .= "$ko_id ";
            $toiGene2KoDone{"$gene_oid:$ko_id"} = 1;
        }
        if (    $tigrfam ne ""
             && $toiGene2TigrfamDone{"$gene_oid:$tigrfam"} eq "" )
        {
            $toiGene2Tigrfam{$gene_oid} .= "$tigrfam ";
            $toiGene2TigrfamDone{"$gene_oid:$tigrfam"} = 1;
        }
        if ( $cassette ne ""
	     && $toiGene2CassetteDone{"$gene_oid:$cassette"} eq "" ) {
            $toiGene2Cassette{$gene_oid} .= "$cassette ";
            $toiGene2CassetteDone{"$gene_oid:$cassette"} = 1;
        }
        if ( $kegg ne ""
	     && $toiGene2KeggDone{"$gene_oid:$kegg"} eq "" ) {
            $toiGene2Kegg{$gene_oid} .= "$kegg ";
            $toiGene2KeggName{$gene_oid} .= "$kegg_name<br><br>";
	    $toiGene2KeggModule{$gene_oid} .= "$kegg_module<br><br>";
            $toiGene2KeggDone{"$gene_oid:$kegg"} = 1;
        }
    }
    $cur->finish();
    my $genes_ref          = $taxonBinOid2Genes{$toi};
    my $count              = scalar( keys(%$genes_ref) );
    my $taxon_display_name = $taxonBinOid2Name{$toi};
    print "$count genes found for genome (bin) of interest, "
      . escHtml($taxon_display_name)
      . "<br/>\n";
    webLog "$count genes found for OOI taxon_bin_oid='$toi'\n";

    return if ( $count eq 0 );

    ## Get cluster sets.
    my %taxonBinOid2Clusters;
    loadClusters( $dbh, $toi, \%taxonBinOid2Clusters );
    my $toiClusters_ref = $taxonBinOid2Clusters{ $toi };
    if( !defined( $toiClusters_ref ) ) {
       webDie( "runJob: cannot find clusters for '$toi'\n" );
    }
    my @keys = keys( %$toiClusters_ref );
    my $count = @keys;
    print "$count clusters found for genome (bin) of interest, "
      . escHtml($taxon_display_name)
      . "<br/>\n";
    for my $i (@all_taxon_bin_oids) {
	loadClusters( $dbh, $i, \%taxonBinOid2Clusters );
    }

    ## Make copy of toi genes.
    my $x_ref        = $taxonBinOid2Genes{$toi};
    my $toiGenes_ref = {};
    my %withHomologsCount;
    my %withoutHomologsCount;
    my @keys = keys(%$x_ref);
    for my $k (@keys) {
        $toiGenes_ref->{$k}       = 1;
        $withHomologsCount{$k}    = 0;
        $withoutHomologsCount{$k} = 0;
    }


    ## 
    # Cluster intersection/subtraction version
    ## Do subtraction.
    for my $i (@neg_reference_oids) {
        $toiClusters_ref =
           doSubtraction( \%taxonBinOid2Clusters, \%taxonBinOid2Name,
                         $toiClusters_ref, $i );
    }
    ## Do intersection.
    for my $i (@pos_reference_oids) {
        $toiClusters_ref =
          doIntersection( \%taxonBinOid2Clusters, \%taxonBinOid2Name,
                          $toiClusters_ref, $i );
    }
    $toiGenes_ref = convertCluster2Genes( 
       $toi, $toiClusters_ref, $toiGenes_ref, $nPositive );

    my @genes = keys( %$toiGenes_ref );
    my $count = @genes;
    print "$count genes remaining in genome (bin) of interest, "
      . escHtml($taxon_display_name)
      . "<br/>\n";

    my %withHomologsPerc;
    my %withoutHomologsPerc;

    print "</p>\n";

    if ( scalar( keys(%$toiGenes_ref) ) == 0 ) {
        printStatusLine( "0 genes retrieved", 2 );
        return;
    }

    ## Load genes with no function and no similarity, unique genes in IMG.
#    my %uniqueGenes;
#    loadUniqueGenes( $dbh, $toi, \%toiBinGenes, \%uniqueGenes )
#      if !$img_lite;

    ## Print out results.
    my @keys           = sort( keys(%$toiGenes_ref) );
    my $count          = @keys;
    my $cogCount       = 0;
    my $enzymeCount    = 0;
    my $pfamCount      = 0;
    my $iprCount       = 0;
    my $geneCount      = 0;
    my $noFuncHitCount = 0;
    my $uniqueCount    = 0;
    my $koCount        = 0;
    my $tigrfamCount   = 0;
    my $cassetteCount  = 0;
    my $keggCount      = 0;

    # Get the unique counts 
    my $uniqCogs       = countUniques(\%toiGene2Cog);
    my $uniqEnzymes    = countUniques(\%toiGene2Enzyme);
    my $uniqPfams      = countUniques(\%toiGene2Pfam);
    my $uniqIprs       = countUniques(\%toiGene2Ipr);
    my $uniqKos        = countUniques(\%toiGene2Ko);
    my $uniqTigrfams   = countUniques(\%toiGene2Tigrfam);
    my $uniqCassettes  = countUniques(\%toiGene2Cassette);
    my $uniqKeggs      = countUniques(\%toiGene2Kegg);


    my $tm               = time();
    my $cacheFile        = "phyloClusterProfile.$tm.$$.tab.txt";
    my $cachePath        = "$cgi_tmp_dir/$cacheFile";
    my $cacheResultsFile = "phyloClusterProfileResults$$";
    my $cacheResultsPath = "$cgi_tmp_dir/$cacheResultsFile";
    my $wfh              = newWriteFileHandle( $cachePath, "runJob" );
    my $res              = newWriteFileHandle( $cacheResultsPath, "runJob" );
    my $rowId            = 0;
    for my $k (@keys) {
        $rowId++;
        my $rec = $toiGene2Desc{$k};
        $geneCount++;
        my ( $gene_oid, $aa_seq_length, $locus_tag, $gene_display_name ) =
          split( /\t/, $rec );
        my $cogs     = $toiGene2Cog{$gene_oid};
        my $enzymes  = $toiGene2Enzyme{$gene_oid};
        my $pfams    = $toiGene2Pfam{$gene_oid};
        my $iprs     = $toiGene2Ipr{$gene_oid};
        my $kos      = $toiGene2Ko{$gene_oid};
        my $tigrfams = $toiGene2Tigrfam{$gene_oid};
	my $cassettes   = $toiGene2Cassette{$gene_oid};
	my $keggs       = $toiGene2Kegg{$gene_oid};
	my $keggnames   = $toiGene2KeggName{$gene_oid};
	my $keggmodules = $toiGene2KeggModule{$gene_oid};

        $cogCount++      if !blankStr($cogs);
        $enzymeCount++   if !blankStr($enzymes);
        $pfamCount++     if !blankStr($pfams);
        $iprCount++      if !blankStr($iprs);
        $koCount++       if !blankStr($kos);
        $tigrfamCount++  if !blankStr($tigrfams);
        $cassetteCount++ if !blankStr($cassettes);
        $keggCount++     if !blankStr($keggs);
        $noFuncHitCount++
          if blankStr($cogs)
          && blankStr($enzymes)
          && blankStr($pfams)
          && blankStr($iprs);
        my $perc_w_homologs  = sprintf( "%d", $withHomologsPerc{$k} * 100 );
        my $perc_wo_homologs = sprintf( "%d", $withoutHomologsPerc{$k} * 100 );
        my $argStr;
        $argStr .= "c" if !blankStr($cogs);
        $argStr .= "e" if !blankStr($enzymes);
        $argStr .= "p" if !blankStr($pfams);
        $argStr .= "i" if !blankStr($iprs);
        $argStr .= "k" if !blankStr($kos);
        $argStr .= "t" if !blankStr($tigrfams);
        $argStr .= "ca" if !blankStr($cassettes);
        $argStr .= "ke" if !blankStr($keggs);
#        $argStr .= "u" if $uniqueGenes{$gene_oid} ne "";
        print $wfh "$gene_oid\t";
        print $wfh "$argStr\n";

        print $res "$rowId\t";
        print $res "$gene_oid\t";
        print $res "$locus_tag\t";
        print $res "$gene_display_name\t";
        print $res "$aa_seq_length\t";
        print $res "$cogs\t";
        print $res "$enzymes\t";
        print $res "$pfams\t";
        print $res "$iprs\t";
        print $res "$kos\t";
        print $res "$tigrfams\t";
        print $res "$cassettes\t";
        print $res "$keggs\t";
        print $res "$keggnames\t";
	print $res "$keggmodules\t";

        my $uniqueInImg = "No";
#        if ( $uniqueGenes{$gene_oid} ne "" ) {
#            $uniqueInImg = "Yes";
#            $uniqueCount++;
#        }

        # Store in uniform format even if may not use.
        print $res "${perc_w_homologs}%\t";
        print $res "${perc_wo_homologs}%\t";

        print $res "$uniqueInImg\t";
        
        # TODO add Percent Identity column - ken
        my $p = $genesPercentages{$gene_oid};
        print $res "$p\n";
        
    }
    printStatusLine( "$count gene(s) retrieved", 2 );
    close $wfh;
    close $res;
    print "</p>\n";

    print "<h2>Summary Statistics</h2>\n";

    # If using YUI tables, apply YUI CSS
    if ($yui_tables) {
	print <<YUI;

	<link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

	 <style type="text/css">
	 .yui-skin-sam .yui-dt th .yui-dt-liner {
		white-space:normal;
         }
	 .img-hor-bgColor {
	    background-color: #DBEAFF;
	 }
	 </style>

	 <div class='yui-dt'>
	 <table style='font-size:12px'>
	 <th>
	 <div class='yui-dt-liner'>
	 <span>Feature</span>
	 </div>
	 </th>
	 <th>
	 <div class='yui-dt-liner'>
	 <span>Number</span>
	 </div>
	 </th>
	 <th>
	 <div class='yui-dt-liner'>
	 <span>Gene Number</span>
	 </div>
	 </th>
	 <th>
	 <div class='yui-dt-liner'>
	 <span>% of Total</span>
	 </div>
	 </th>
YUI
    } else {
	print <<IMG;
	<table class='img'  border='1'>
	<th class='img' ></th>
	<th class='img' >Number</th>
	<th class='img' >% of Total</th>
IMG
    }

    my $classStr;
    if ($yui_tables) {
	$classStr = "yui-dt-first img-hor-bgColor";
    } else {
	$classStr = "img";
    }

    # "Total number of genes"
    print "<tr class='$classStr'>\n";
    print "<td style='text-align:right' colspan=2>";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<b>Total number of genes<b>\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Total gene count
    print "<td style='text-align:right'>";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "$geneCount\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # % of Total
    print "<td style='text-align:right'>";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "100.00%\n";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    my $rowIdx = 0; # keep track of table rows
    printChartRow( "COG", "c", $uniqCogs, $cogCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "Enzyme", "e", $uniqEnzymes, $enzymeCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printChartRow( "Pfam", "p", $uniqPfams, $pfamCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "InterPro", "i", $uniqIprs, $iprCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "KO Term",  "k", $uniqKos, $koCount,  $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printChartRow( "Tigrfam", "t", $uniqTigrfams, $tigrfamCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "No Functional Hit",
                  "nf", "", $noFuncHitCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "Unique In IMG", "u", "", $uniqueCount, $geneCount, $cacheFile, $rowIdx)
      if !$img_lite;
    $rowIdx++;
    printStatRow( "Cassette", "ca", $uniqCassettes, $cassetteCount, $geneCount, $cacheFile, $rowIdx );
    $rowIdx++;
    printStatRow( "KEGG Map", "ke", $uniqKeggs, $keggCount, $geneCount, $cacheFile, $rowIdx );

    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "<br />\n";

    ## Print out table with button for more results.
    my $totalRows = $rowId;
    printPhyloProfileResultsPage( $cacheResultsFile, 0, $totalRows,
                                  $doPercentage, \@neg_reference_oids,
				  scalar(@pos_reference_oids)  );
}

############################################################################
# countUniques - Count the unique number of COGs, pfams, etc.
#   Input:
#     toiGene_hash - hash of gene_oid => function_id.
#                   See %toiGene2Cog, %toiGene2Pfam, etc. in runJob() above
############################################################################
sub countUniques {
    my ($toiGene_hash) = @_;
    my @uniques;
    
    for my $gene (keys %$toiGene_hash) {
	# $toiGene_hash->{$gene} can have multiple IDs
	# that are separated by space, so split them
	# +BSJ 14/12/11
	push @uniques, split(/ /, $toiGene_hash->{$gene});
    }
    my %hash = WebUtil::array2Hash(@uniques);
    @uniques = keys(%hash);
    return scalar(@uniques);
}

############################################################################
# intersectClusterGenes
############################################################################
sub intersectClusterGenes {
   my( $toi, $taxon_bin_oid, 
       $taxonBinOid2Name_href, $clusters2_href, $genes_href ) = @_;
   my( $taxon_oid1, $bin_oid1 ) = split( /\./, $toi );

   my $zipFile = "$taxonCluster_zfiles_dir/$taxon_oid1.zip";
   my $rfh = newUnzipFileHandle( $zipFile, $taxon_oid1,
       "intersectClusterGenes" );
   my $count1 = 0;
   my $count2 = 0;
   my %genes;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      $count1++;
      my( $taxon_oid, $cluster_id, @gene_oids ) = split( /\t/, $s );
      for my $g( @gene_oids ) {
         next if $g eq "";
         if( $clusters2_href->{ $cluster_id } && $genes_href->{ $g } ) {
	     $count2++;
             $genes{ $g } = 1
         }
      }
   }
   close $rfh;
   webLog( "$count1 clusters read from $taxon_oid1\n" );
   my $nKeys = keys( %genes );
   my $taxon_display_name = $taxonBinOid2Name_href->{$taxon_bin_oid};
    print "$nKeys genes remaining "
      . "after intersecting clusters in "
      . escHtml($taxon_display_name)
      . "<br/>\n";
   return \%genes;
}

############################################################################
# subtractClusterGenes
############################################################################
sub subtractClusterGenes {
   my( $toi, $taxon_bin_oid, 
       $taxonBinOid2Name_href, $clusters2_href, $genes_href ) = @_;
   my( $taxon_oid1, $bin_oid1 ) = split( /\./, $toi );

   my $zipFile = "$taxonCluster_zfiles_dir/$taxon_oid1.zip";
   my $rfh = newUnzipFileHandle( $zipFile, $taxon_oid1,
       "subtractClusterGenes" );
   my $count1 = 0;
   my $count2 = 0;
   my %genes = %$genes_href;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      $count1++;
      my( $taxon_oid, $cluster_id, @gene_oids ) = split( /\t/, $s );
      for my $g( @gene_oids ) {
         next if $g eq "";
         if( $clusters2_href->{ $cluster_id } && $genes{ $g } ) {
	     $count2++;
             delete $genes{ $g }
         }
      }
   }
   close $rfh;
   webLog( "$count1 clusters read from $taxon_oid1\n" );
   my $taxon_display_name = $taxonBinOid2Name_href->{$taxon_bin_oid};
   my $nKeys = keys( %genes );
   print "$nKeys genes remaining "
      . "after subtracting clusters in "
      . escHtml($taxon_display_name)
      . "<br/>\n";
   return \%genes;
}

############################################################################
# printStatRow - Summary stats at bottom of run.
#   Inputs:
#     title - Title of stat row
#     code - code for stat
#     count - actual count of hits
#     total - total of all hits
#     cacheFile -  cache file for link out from results
############################################################################
sub printStatRow {
    my ( $title, $code, $uniques, $count, $total, $cacheFile, $idx ) = @_;

    my $classStr;
    if ($yui_tables) {
	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    } else {
	$classStr = "img";
    }
    my $url = "$section_cgi&page=phyloProfileResultStat";
    $url .= "&code=$code&cf=$cacheFile";
    my $s2 = alink( $url, $count );
    $s2 = $count if $count == 0;
    my $s = sprintf( "%.2f%%", ( $count / $total ) * 100 );

    print "<tr class='$classStr'>\n";

    # Feature
    print "<td>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print nbsp(2) . escHtml($title);
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Number
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $uniques;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Gene Number
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $s2;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # % of Total
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $s;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    print "</tr>\n";
}

sub printChartRow {
    my ( $title, $code, $uniques, $count, $total, $cacheFile, $idx ) = @_;
    my $classStr;

    if ($yui_tables) {
	$classStr = !$idx ? "yui-dt-first ":"";
	$classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    } else {
	$classStr = "img";
    }

    my $mypage;
    if ( $code eq "c" ) {
        $mypage = "cogs";
    } elsif ( $code eq "p" ) {
        $mypage = "pfam";
    } elsif ( $code eq "t" ) {
        $mypage = "tigrfam";
    }
    my $url = "$section_cgi&page=$mypage&code=$code&cf=$cacheFile";
    my $s2 = alink( $url, $count );
    $s2 = $count if $count == 0;
    my $s = sprintf( "%.2f%%", ( $count / $total ) * 100 );
    print "<tr class='$classStr'>\n";

    # Feature
    print "<td>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print nbsp(2) . escHtml($title);
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Number
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $uniques;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Gene Number
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $s2;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # % of Total
    print "<td>\n";
    print "<div class='yui-dt-liner' style='text-align: right;'>" if $yui_tables;
    print $s;
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    print "</tr>\n";
}

############################################################################
# printCogs - Show COG groups and count of genes.
############################################################################
sub printCogs {
    my $code      = param("code");
    my $cacheFile = param("cf");

    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $rfh = newReadFileHandle( $cachePath, "printCogs", 1 );
    if ( !$rfh ) {
        webLog "Cache '$cachePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }

    my $tm       = time();
    my $geneFile = "phyloProfile.$tm.$$.genes.txt";
    my $genePath = "$cgi_tmp_dir/$geneFile";
    my $wfh      = newWriteFileHandle( $genePath, "printCogs" );

    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+/ /g;
        my ( $gene_oid, $args ) = split( / /, $s );
        if ( $args =~ /$code/ ) {
            print $wfh "$gene_oid\n";
            push( @gene_oids, $gene_oid );

            $items++;
            if ( $items == 1000 ) {
                my @ids;
                foreach my $id (@gene_oids) {
                    push( @ids, $id );
                }
                my $genestr = join( ",", @ids );
                push( @allgenes, $genestr );
                @gene_oids = ();
                $items     = 0;
            }
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;
    close $wfh;
    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {
        printStatusLine( "0 genes retrieved", 2 );
        return;
    }
    printStatusLine( "Loading ...", 1 );

    my $url2 = "$section_cgi&page=cogGeneList&geneFile=$geneFile";

    print "<h1>Genes assigned to COGs</h1>\n";
    printStatusLine( "Loading ...", 1 );

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("function_code");
    my @chartseries;
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    #################################

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $count = 0;
    my $once  = 1;
    my @allcategories;
    my %dataHash;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select cf.definition, cf.function_code, count(distinct gcg.gene_oid)
		from gene_cog_groups gcg, cog c, gene g, cog_function cf,
		cog_functions cfs
		where gcg.cog = c.cog_id
		$rclause
		$imgClause
		and gcg.gene_oid = g.gene_oid
		and g.gene_oid in ($genes) 
		and g.locus_type = ? 
		and g.obsolete_flag = ? 
		and cfs.functions = cf.function_code
		and cfs.cog_id = c.cog_id
		group by cf.definition, cf.function_code
		having count(distinct gcg.gene_oid) > 0
	    };
        my @bindList = ('CDS', 'No');
        
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

        for ( ; ; ) {
            my ( $definition, $function_code, $gene_count ) = $cur->fetchrow();
            last if !$definition;
            last if !$function_code;

            if ($once) {
                $count++;
                push @allcategories, "$definition\t$function_code";
            }
            $dataHash{"$definition\t$function_code"} += $gene_count;
        }
        $cur->finish();
        $once = 0;
    }

    for my $key (@allcategories) {
        my ( $a, $b ) = split( /\t/, $key );
        push @chartcategories, "$a";
        push @functioncodes,   "$b";
        push @chartdata,       $dataHash{$key};
    }
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >COG Categories</th>\n";
    print "<th class='img' >Gene Count</th>\n";

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;
        my $url = "$section_cgi&page=cogGeneList";
        $url .= "&function_code=$functioncodes[$idx]";
        $url .= "&geneFile=$geneFile";
        print "<tr class='img' >\n";
        print "<td class='img' >\n";

        if ( $st == 0 ) {
            print "<a href='$url'>";
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "</a>";
            print "&nbsp;&nbsp;";
        }
        print escHtml($category1);
        print "</td>\n";
        print "<td class='img' align='right'>\n";
        print alink( $url, $chartdata[$idx] );

        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    print "</table>\n";
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printCogs", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";

    print "</td></tr>\n";
    print "</table>\n";
    printStatusLine( "$count COG assignments retrieved.", 2 );
}

############################################################################
# printPfam - Show Pfam groups and count of genes.
############################################################################
sub printPfam {
    my $code      = param("code");
    my $cacheFile = param("cf");

    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $rfh = newReadFileHandle( $cachePath, "printPfam", 1 );
    if ( !$rfh ) {
        webLog "Cache '$cachePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }

    my $tm       = time();
    my $geneFile = "phyloProfile.$tm.$$.genes.txt";
    my $genePath = "$cgi_tmp_dir/$geneFile";

    my $wfh = newWriteFileHandle( $genePath, "printPfam" );

    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+/ /g;
        my ( $gene_oid, $args ) = split( / /, $s );
        if ( $args =~ /$code/ ) {
            push( @gene_oids, $gene_oid );
            print $wfh "$gene_oid\n";

            $items++;
            if ( $items == 1000 ) {
                my @ids;
                foreach my $id (@gene_oids) {
                    push( @ids, $id );
                }
                my $genestr = join( ",", @ids );
                push( @allgenes, $genestr );
                @gene_oids = ();
                $items     = 0;
            }
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;
    close $wfh;

    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {
        printStatusLine( "0 genes retrieved", 2 );
        return;
    }

    my $url2 = "$section_cgi&page=pfamGeneList&geneFile=$geneFile";
    print "<h1>Genes assigned to Pfam</h1>\n";
    printStatusLine( "Loading ...", 1 );

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("function_code");
    my @chartseries;
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    #################################

    my $dbh                = dbLogin();
    my $count              = 0;
    my $unclassified_count = 0;
    my $unclassified_url;
    my $once = 1;
    my @allcategories;
    my %dataHash;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select $nvl(cf.function_code, '_'),
	    $nvl(cf.definition, '_'),
	    count( distinct g.gene_oid )
		from gene g, gene_pfam_families gpf 
		left join pfam_family_cogs pfc 
	        on gpf.pfam_family = pfc.ext_accession 
		left join cog_function cf 
	        on pfc.functions = cf.function_code
		where g.gene_oid = gpf.gene_oid
		$rclause
		$imgClause
		and g.gene_oid in ($genes)
		and g.locus_type = ? 
		and g.obsolete_flag = ? 
		group by cf.function_code, cf.definition
		order by cf.definition
	    };
        my @bindList = ('CDS', 'No');
        
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

        for ( ; ; ) {
            my ( $function_code, $name, $gene_count ) = $cur->fetchrow();
            last if !$function_code;
            last if !$name;

            if ( $name eq "_" ) {
                $name = "unclassified";
                $unclassified_count += $gene_count;
                if ($once) {
                    $unclassified_url = "$section_cgi&page=pfamGeneList";
                    $unclassified_url .= "&geneFile=$geneFile";
                    $unclassified_url .= "&function_code=$function_code";
                }
                next;
            }

            if ($once) {
                $count++;
                push @allcategories, "$name\t$function_code";
            }
            $dataHash{"$name\t$function_code"} += $gene_count;
        }
        $cur->finish();
        $once = 0;
    }

    for my $key (@allcategories) {
        my ( $a, $b ) = split( /\t/, $key );
        push @chartcategories, "$a";
        push @functioncodes,   "$b";
        push @chartdata,       $dataHash{$key};
    }

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Pfam Categories</th>\n";
    print "<th class='img' >Gene Count</th>\n";

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;
        my $url = "$section_cgi&page=pfamGeneList";
        $url .= "&geneFile=$geneFile";
        $url .= "&function_code=$functioncodes[$idx]";
        print "<tr class='img' >\n";
        print "<td class='img' >\n";

        if ( $st == 0 ) {
            print "<a href='$url'>";
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "</a>";
            print "&nbsp;&nbsp;";
        }
        print escHtml($category1);
        print "</td>\n";
        print "<td class='img' align='right'>\n";
        print alink( $url, $chartdata[$idx] );

        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    # add the unclassified row:
    print "<tr class='img' >";
    print "<td class='img' >";
    print "&nbsp;&nbsp;";
    print "&nbsp;&nbsp;";
    print "&nbsp;&nbsp;";
    print "unclassified";
    print "</td>";
    print "<td class='img' align='right'>";
    print alink( $unclassified_url, $unclassified_count );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printPfam", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";

    print "</td></tr>\n";
    print "</table>\n";
    printStatusLine( "$count Pfam categories retrieved.", 2 );
}

############################################################################
# printTigrfam - Show TIGRfam groups and count of genes.
############################################################################
sub printTigrfam {
    my $code      = param("code");
    my $cacheFile = param("cf");

    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $rfh       = newReadFileHandle( $cachePath, "printTigrfam", 1 );

    if ( !$rfh ) {
        webLog "Cache '$cachePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }

    my $tm       = time();
    my $geneFile = "phyloProfile.$tm.$$.genes.txt";
    my $genePath = "$cgi_tmp_dir/$geneFile";

    my $wfh = newWriteFileHandle( $genePath, "printTigrfam" );

    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+/ /g;
        my ( $gene_oid, $args ) = split( / /, $s );
        if ( $args =~ /$code/ ) {
            push( @gene_oids, $gene_oid );
            print $wfh "$gene_oid\n";

            $items++;
            if ( $items == 1000 ) {
                my @ids;
                foreach my $id (@gene_oids) {
                    push( @ids, $id );
                }
                my $genestr = join( ",", @ids );
                push( @allgenes, $genestr );
                @gene_oids = ();
                $items     = 0;
            }
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;
    close $wfh;

    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {
        printStatusLine( "0 genes retrieved", 2 );
        return;
    }

    my $url2 = "$section_cgi&page=tigrfamGeneList&geneFile=$geneFile";
    print "<h1>Genes assigned to TIGRfam</h1>\n";
    printStatusLine( "Loading ...", 1 );

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("role");
    my @chartseries;
    my @chartcategories;
    my @roles;
    my @chartdata;
    #################################

    my $dbh                = dbLogin();
    my $count              = 0;
    my $unclassified_count = 0;
    my $unclassified_url;
    my $once = 1;
    my @allcategories;
    my %dataHash;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select $nvl(tr.main_role, '_'),
	    count(distinct gtf.gene_oid)
		from gene g, gene_tigrfams gtf 
		left join tigrfam_roles trs 
	        on gtf.ext_accession = trs.ext_accession
		left join tigr_role tr 
	        on trs.roles = tr.role_id
		where g.gene_oid = gtf.gene_oid
		$rclause
		$imgClause
		and g.gene_oid in ($genes)
		group by tr.main_role
	    };

        my $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ( $name, $gene_count ) = $cur->fetchrow();
            last if !$name;

            if ( $name eq "_" ) {
                $name = "unclassified";
                $unclassified_count += $gene_count;
                if ($once) {
                    $unclassified_url = "$section_cgi&page=tigrfamGeneList";
                    $unclassified_url .= "&geneFile=$geneFile";
                    $unclassified_url .= "&role=$name";
                }
                next;
            }

            if ($once) {
                $count++;
                push @allcategories, "$name\t$name";
            }
            $dataHash{"$name\t$name"} += $gene_count;
        }
        $cur->finish();
        $once = 0;
    }

    for my $key (@allcategories) {
        my ( $a, $b ) = split( /\t/, $key );
        push @chartcategories, "$a";
        push @roles,           "$b";
        push @chartdata,       $dataHash{$key};
    }

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@roles );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    print "<table class='img'  border='1'>\n";
    print "<th class='img' >TIGRfam Roles</th>\n";
    print "<th class='img' >Gene Count</th>\n";

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;
        my $url = "$section_cgi&page=tigrfamGeneList";
        $url .= "&geneFile=$geneFile";
        $url .= "&role=$roles[$idx]";
        print "<tr class='img' >\n";
        print "<td class='img' >\n";

        if ( $st == 0 ) {
            print "<a href='$url'>";
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "</a>";
            print "&nbsp;&nbsp;";
        }
        print escHtml($category1);
        print "</td>\n";
        print "<td class='img' align='right'>\n";
        print alink( $url, $chartdata[$idx] );

        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    # add the unclassified row:
    print "<tr class='img' >";
    print "<td class='img' >";
    print "&nbsp;&nbsp;";
    print "&nbsp;&nbsp;";
    print "&nbsp;&nbsp;";
    print "unclassified";
    print "</td>";
    print "<td class='img' align='right'>";
    print alink( $unclassified_url, $unclassified_count );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printTigrfam", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";

    print "</td></tr>\n";
    print "</table>\n";
    printStatusLine( "$count TIGRfam roles retrieved.", 2 );
}

############################################################################
# printCogGeneList - prints the gene list assigned to the specific cog
############################################################################
sub printCogGeneList {
    my $geneFile      = param("geneFile");
    my $function_code = param("function_code");

    my $genePath = "$cgi_tmp_dir/$geneFile";
    my $rfh = newReadFileHandle( $genePath, "printCogs", 1 );
    if ( !$rfh ) {
        webLog "Cache '$genePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }
    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @gene_oids, $s );

        $items++;
        if ( $items == 1000 ) {
            my @ids;
            foreach my $id (@gene_oids) {
                push( @ids, $id );
            }
            my $genestr = join( ",", @ids );
            push( @allgenes, $genestr );
            @gene_oids = ();
            $items     = 0;
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
	select definition
	    from cog_function
	    where function_code = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    my @oids;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select distinct g.gene_oid
		from gene_cog_groups gcg, cog c, cog_function cf,
		cog_functions cfs, gene g
		where gcg.cog = c.cog_id
		$rclause
		$imgClause
		and g.locus_type = ? 
		and g.obsolete_flag = ? 
		and gcg.gene_oid = g.gene_oid
		and g.gene_oid in ($genes)
		and cfs.functions = cf.function_code
		and cfs.cog_id = c.cog_id
		and cf.function_code = ? 
		order by g.gene_oid
	    };
        my @bindList = ('CDS', 'No', $function_code);
        
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @oids, $oid );
        }
        $cur->finish();
    }

    my $title = "Genes assigned to COG: $definition";
    HtmlUtil::printGeneListHtmlTable( $title, '', $dbh, \@oids );
}

############################################################################
# printPfamGeneList - prints the gene list assigned to the specific Pfam
############################################################################
sub printPfamGeneList {
    my $geneFile      = param("geneFile");
    my $function_code = param("function_code");

    my $genePath = "$cgi_tmp_dir/$geneFile";
    my $rfh      = newReadFileHandle( $genePath, "printPfam", 1 );

    if ( !$rfh ) {
        webLog "Cache '$genePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }
    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @gene_oids, $s );

        $items++;
        if ( $items == 1000 ) {
            my @ids;
            foreach my $id (@gene_oids) {
                push( @ids, $id );
            }
            my $genestr = join( ",", @ids );
            push( @allgenes, $genestr );
            @gene_oids = ();
            $items     = 0;
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    my $clause = "and cf.function_code is null";
    my @bindList_clause = ();
    if ( $function_code ne "_" ) {
        $clause = "and cf.function_code = ? ";
        push(@bindList_clause, $function_code);
    }

    my $sql = qq{ 
        select definition 
            from cog_function 
            where function_code = ? 
        };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();
    if ( $definition eq '' ) {
        $definition = 'unclassified';
    }

    my @oids;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select distinct g.gene_oid
		from gene g, gene_pfam_families gpf
		left join pfam_family_cogs pfc 
	        on gpf.pfam_family = pfc.ext_accession
		left join cog_function cf 
	        on pfc.functions = cf.function_code
		where g.gene_oid = gpf.gene_oid
		$rclause
		$imgClause
		and g.gene_oid in ($genes) 
		and g.locus_type = ? 
		and g.obsolete_flag = ? 
		$clause
	    };
        my @bindList = ('CDS', 'No');
        if(scalar(@bindList_clause) > 0) {
        	push(@bindList, @bindList_clause);        	
        }
        
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @oids, $oid );
        }
        $cur->finish();
    }

    my $title = "Genes assigned to Pfam: $definition";
    HtmlUtil::printGeneListHtmlTable( $title, '', $dbh, \@oids );

}

############################################################################
# printTIGRfamGeneList - prints gene list assigned to the specific tigrfam
############################################################################
sub printTIGRfamGeneList {
    my $geneFile = param("geneFile");
    my $role     = param("role");

    my $genePath = "$cgi_tmp_dir/$geneFile";

    my $rfh = newReadFileHandle( $genePath, "printTigrfam", 1 );
    if ( !$rfh ) {
        webLog "Cache '$genePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }
    my @gene_oids;
    my @allgenes;
    my $items = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @gene_oids, $s );

        $items++;
        if ( $items == 1000 ) {
            my @ids;
            foreach my $id (@gene_oids) {
                push( @ids, $id );
            }
            my $genestr = join( ",", @ids );
            push( @allgenes, $genestr );
            @gene_oids = ();
            $items     = 0;
        }
    }
    if ( $items > 0 ) {
        my $genestr = join( ",", @gene_oids );
        push( @allgenes, $genestr );
    }
    close $rfh;

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    my $clause = "";
    my @bindList = ();
    if ( $role eq "_" || $role eq "unclassified" ) {
        $clause = "and tr.main_role is null";
    }
    else {
    	$clause = "and tr.main_role = ? ";
    	push(@bindList, $role);
    }

    my @oids;

    ### in query list cannot be more than 1000 items, so need to loop:
    for my $genes (@allgenes) {
        last if !$genes;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
	    select distinct gtf.gene_oid
		from gene g, gene_tigrfams gtf 
		left join tigrfam_roles trs
	        on gtf.ext_accession = trs.ext_accession
		left join tigr_role tr on trs.roles = tr.role_id
		where g.gene_oid = gtf.gene_oid
		$rclause
		$imgClause
		and g.gene_oid in ($genes)
		$clause
	    };

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @oids, $oid );
        }
        $cur->finish();
    }

    my $title = "Genes assigned to TIGRfam: $role";
    HtmlUtil::printGeneListHtmlTable( $title, '', $dbh, \@oids );

}

############################################################################
# printGeneList - prints the profiler's gene list
############################################################################
sub printGeneList {
    my ( $dbh, $gene_oids_ref ) = @_;

    printMainForm();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    my @oids;
    my $count = 0;
    my $trunc = 0;
    if ( scalar(@$gene_oids_ref) <= $maxGeneListResults ) {
        @oids = @$gene_oids_ref;
        $count = scalar(@$gene_oids_ref);
    }
    else {
        foreach my $oid (@$gene_oids_ref) {
            last if !$oid;
            $count++;
            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
            push( @oids, $oid );
        }        
    }
    HtmlUtil::flushGeneBatchSort( $dbh, \@oids, $it );

    printGeneCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    printGeneCartFooter();
    
    if ( $trunc ) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# loadTaxonBinNames - Load all descriptive taxon mapping information.
#   Inputs:
#     dbh - database handle
#     taxonBinOid2Name_ref - taxon/bin oid map to name reference
############################################################################
sub loadTaxonBinNames {
    my ( $dbh, $taxonBinOid2Name_ref ) = @_;

    my @bindList_txs = ();
    my $taxonClause = txsClause("tx", $dbh);
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql         = qq{
       select tx.taxon_oid, tx.taxon_display_name
       from taxon tx
       where 1 = 1
       $rclause
       $imgClause
       $taxonClause
    };
    my $cur = execSqlBind( $dbh, $sql, \@bindList_txs, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonBinOid2Name_ref->{"$taxon_oid.0"} = $taxon_display_name;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name, b.bin_oid, b.display_name
		from taxon tx, env_sample_gold es, bin b
		where 1 = 1
		$rclause
		$imgClause
		and tx.env_sample = es.sample_oid
		and es.sample_oid = b.env_sample
		and b.is_default = ? 
		$taxonClause
    };
    my @bindList = ('Yes');
    if (scalar(@bindList_txs) > 0) {
    	push(@bindList, @bindList_txs);
    }
    my $cur = execSqlBind( $dbh, $sql, \@bindList, 0 );

    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $bin_oid, $bin_display_name ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        $bin_oid = "0" if $bin_oid eq "";
        my $name = $taxon_display_name;
        $name = $bin_display_name if $bin_oid > 0;
        $taxonBinOid2Name_ref->{"$taxon_oid.$bin_oid"} = $name;
    }
}

############################################################################
# loadObsoleteGenes - Load list of obsolete gene_oid's.
############################################################################
sub loadObsoleteGenes {
    my ($dbh) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.gene_oid
		from gene g
		where g.obsolete_flag = ? 
		$rclause
		$imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        $obsoleteGenes{$gene_oid} = 1;
    }
    $cur->finish();
    webLog "$count obsolete genes found\n"
      if $verbose >= 1;
}

############################################################################
# loadPseudoGenes - Load list of pseudo gene_oid's.
############################################################################
sub loadPseudoGenes {
    my ($dbh) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.gene_oid
		from gene g
		where g.is_pseudogene = ? 
		$rclause
		$imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        $pseudoGenes{$gene_oid} = 1;
    }
    $cur->finish();
    webLog "$count pseudo genes found\n"
      if $verbose >= 1;
}

############################################################################
# getClusterZfileName
#    compose taxon cluster zfile name using taxon_bin_oid.
############################################################################
sub getClusterZfileName {
    my ( $taxon_bin_oid ) = @_;
    my( $taxon_oid, $bin_oid ) = split( /\./, $taxon_bin_oid );
    my $fpath = "$taxonCluster_zfiles_dir/$taxon_oid.zip";
    return $fpath;
}

############################################################################
# loadClusters - Load clusters for a taxon.
#    Subset the taxon clusters if it's really a bin (bin_oid > 0);
############################################################################
sub loadClusters {
    my( $dbh, $taxon_bin_oid,  $taxonBinOid2Clusters_href ) = @_;

    my( $taxon_oid, $bin_oid ) = split( /\./, $taxon_bin_oid );

    # stop if zip file can not be found
    my $fpath = getClusterZfileName($taxon_bin_oid);
    unless ( -e  $fpath ) {
        webError("The phylogenetic clusters data is not available for this genome ($taxon_oid).");
    }

    my $rfh = newUnzipFileHandle( $fpath, "", "loadClusters" );
    my %geneClusters;
    my $geneClusters_href = \%geneClusters;
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	my( $taxon, $clusterId, @genes ) = split( /\s+/, $s );
	next if $taxon ne $taxon_oid;
	for my $g( @genes ) {
	   $geneClusters_href->{ $g }->{ $clusterId } = 1
	      if $bin_oid > 0;
	}
	$taxonBinOid2Clusters_href->{ $taxon_bin_oid }->{ $clusterId } = 1;
    }
    $rfh->close( );

    ## Get initial count based on taxon
    my $clusters_href = $taxonBinOid2Clusters_href->{ $taxon_bin_oid };
    if( defined( $clusters_href ) ) {
       my @keys = keys( %$clusters_href );
       my $count = @keys;
       webLog( "loadClusters[1]: " . 
          "$count clusters found for taxon_oid=$taxon_oid\n" );
    }

    return if $bin_oid == 0;

    ## Handle bin subset of clusters
    #  from bin inside a taxon.
    #
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
       select distinct g.gene_oid
       from gene g, bin_scaffolds bs
       where g.scaffold = bs.scaffold
       $rclause
       $imgClause
       and g.taxon = ?
       and bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $bin_oid );
    my %binGenes;
    for( ;; ) {
       my( $gene_oid ) = $cur->fetchrow( );
       last if !$gene_oid;
       $binGenes{ $gene_oid } = 1;
    }
    $cur->finish( );

    my @taxonClusterGenes = sort( keys( %$geneClusters_href ) );
    my %binClusters;
    for my $cg( @taxonClusterGenes ) {
       next if !binGenes{ $cg };
       my $clusters_href = $geneClusters_href->{ $cg };
       next if !defined( $clusters_href );
       my @clusters = keys( %$clusters_href );
       for my $c( @clusters ) {
           $binClusters{ $c } = 1;
       }
    }
    $taxonBinOid2Clusters_href->{ $taxon_bin_oid } = \%binClusters;

    ## Get subset count based on taxon.bin_oid
    my $clusters_href = $taxonBinOid2Clusters_href->{ $taxon_bin_oid };
    if( defined( $clusters_href ) ) {
       my @keys = keys( %$clusters_href );
       my $count = @keys;
       webLog( "loadClusters[2]: " . 
          "$count clusters in subset taxon_bin_oid=$taxon_bin_oid\n" );
    }
}

############################################################################
# convertCluster2Genes - Convert cluster to genes for TOI.
############################################################################
sub convertCluster2Genes {
    my( $toi, $toiClusters_href,  $toiGenes_href, $nPosRef ) = @_;
    my( $taxon_oid, $bin_oid ) = split( /\./, $toi );
    my $fpath = "$taxonCluster_zfiles_dir/$taxon_oid.zip";

    # --es 12/14/11
    #my $rfh = newUnzipFileHandle( $fpath, $taxon_oid, "convertCluster2Genes" );
    my $rfh = newUnzipFileHandle( $fpath, "", "convertCluster2Genes" );
    my %allGenes;
    my %genes;
    my $count = 0;
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	$count++;
	my( $taxon, $clusterId, @genes ) = split( /\s+/, $s );
	for my $g( @genes ) {
	   $allGenes{ $g } = 1;
	}
	next if !$toiClusters_href->{ $clusterId };
	for my $g( @genes ) {
	   # Should not need this.
	   next if !$toiGenes_href->{ $g };
	   $genes{ $g } = 1;
	}
    }
    $rfh->close( );

    # If no intersections, just subtractions,
    # add genes that do not belong to any cluster.
    if( $nPosRef == 0 ) {
       my @toiGenes = keys( %$toiGenes_href );
       for my $toiGene( @toiGenes ) {
          next if $allGenes{ $toiGene };
	  $genes{ $toiGene } = 1;
       }
    }
    return \%genes;
}

############################################################################
# printHashKeys
############################################################################
sub printHashKeys {
   my( $hash_href, $outFile ) = @_;

   my @keys = sort( keys( %$hash_href ) );
   my $wfh = newWriteFileHandle( $outFile, "printHashKeys" );
   for my $k( @keys ) {
      print $wfh "$k\n";
   }
   close $wfh;
}

############################################################################
# loadBinGenes - Load valid genes from a given bin.
############################################################################
sub loadBinGenes {
    my ( $dbh, $bin_oid, $binGenes_ref ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct g.gene_oid
		from bin b, bin_scaffolds bs, scaffold scf, gene g
		where b.bin_oid = ? 
		$rclause
		$imgClause
		and g.obsolete_flag = ? 
		and b.bin_oid = bs.bin_oid
		and bs.scaffold = scf.scaffold_oid
		and g.scaffold = scf.scaffold_oid
		and b.is_default = ? 
    };

    my @bindList = ($bin_oid, 'No', 'Yes');
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        $binGenes_ref->{$gene_oid} = 1;
    }
    $cur->finish();
    webLog "$count bin genes retrieved for bin_oid=$bin_oid\n"
      if $verbose >= 1;
}

############################################################################
# doSubstraction - Code to subtract out clusters from taxon of interest (toi)
#   given another taxon.
#    Inputs:
#      taxonBinOids2Clusters_ref - taxon object identifer to cluster list map
#      taxonBinOid2Name_ref - taxon object identifer to taxon name map
#      toiClusters_ref - taxon of interest clusters
#      taxon_bin_oid - taxon.bin object identifier
############################################################################
sub doSubtraction {
    my ( $taxonBinOid2Clusters_ref, $taxonBinOid2Name_ref, $toiClusters_ref,
         $taxon_bin_oid )
      = @_;
    my %clusters;
    my $extClusterList_ref = $taxonBinOid2Clusters_ref->{$taxon_bin_oid};
    my @toiClusters        = keys(%$toiClusters_ref);
    my $count           = 0;
    for my $c (@toiClusters) {
        next if $extClusterList_ref->{$c} ne "";
        $count++;
        $clusters{$c} = 1;
    }
    my @keys               = keys(%clusters);
    my $nKeys              = @keys;
    my $taxon_display_name = $taxonBinOid2Name_ref->{$taxon_bin_oid};
    print "$nKeys clusters remaining "
      . "after subtracting clusters in "
      . escHtml($taxon_display_name)
      . "<br/>\n";
    return \%clusters;
}

############################################################################
# doPercSubstraction - Code to count substraction of clusters
#   given another taxon for "percentage" algorithm.
#    Inputs:
#      taxonBinOids2Clusters_ref - taxon object identifer to cluster list map
#      taxonBinOid2Name_ref - taxon object identifer to taxon name map
#      toiClusterCount_ref - taxon of interest clusters
#      taxon_bin_oid - taxon bin object identifier
############################################################################
sub doPercSubtraction {
    my (
         $taxonBinOid2Clusters_ref, $taxonBinOid2Name_ref,
         $toiClusterCount_ref,      $taxon_bin_oid
      )
      = @_;
    my %clusters;
    my $extClusterList_ref    = $taxonBinOid2Clusters_ref->{$taxon_bin_oid};
    my $taxon_display_name = $taxonBinOid2Name_ref->{$taxon_bin_oid};
    my %done;
    my @toiClusters = keys(%$toiClusterCount_ref);
    for my $c (@toiClusters) {
        next if $extClusterList_ref->{$c} ne "";
        next if $done{$c};
        $toiClusterCount_ref->{$c}++;
        $done{$c} = 1;
    }
    my $count = keys(%done);
    print "$count clusters processed by subtracting from "
      . escHtml($taxon_display_name)
      . "<br/>\n";
}

############################################################################
# doIntersection - Code to intersect clusters between taxons.
#    Inputs:
#       taxonBinOid2Clusters_ref - taxon object identifer to clusters map
#       taxonBinOid2Name_ref - taxon object identifier to name map
#       toiClusters_ref - taxon of interest clusters
#       taxon_bin_oid - taxon bin object identifier
############################################################################
sub doIntersection {
    my ( $taxonBinOid2Clusters_ref, $taxonBinOid2Name_ref, $toiClusters_ref,
         $taxon_bin_oid )
      = @_;
    my %clusters;
    my $extClusterList_ref = $taxonBinOid2Clusters_ref->{$taxon_bin_oid};
    my @toiClusters        = keys(%$toiClusters_ref);
    my $count           = 0;
    for my $c (@toiClusters) {
        next if $extClusterList_ref->{$c} eq "";
        $count++;
        $clusters{$c} = 1;
    }
    my $taxon_display_name = $taxonBinOid2Name_ref->{$taxon_bin_oid};
    my @keys               = keys(%clusters);
    my $nKeys              = @keys;
    print "$nKeys clusters remaining "
      . "after intersecting with clusters in "
      . escHtml($taxon_display_name)
      . "<br/>\n";
    return \%clusters;
}

############################################################################
# doPercIntersection - Code to count substraction of clusters
#   given another taxon for "percentage" algorithm.
#    Inputs:
#      taxonBinOids2Clusters_ref - taxon object identifer to cluster list map
#      taxonBinOid2Name_ref - taxon object identifer to taxon name map
#      toiClusterCount_ref - taxon of interest clustere
#      taxon_oid - taxon object identifier
############################################################################
sub doPercIntersection {
    my (
         $taxonBinOid2Clusters_ref, $taxonBinOid2Name_ref,
         $toiClusterCount_ref,      $taxon_bin_oid
      )
      = @_;
    my %clusters;
    my $extClusterList_ref    = $taxonBinOid2Clusters_ref->{$taxon_bin_oid};
    my $taxon_display_name = $taxonBinOid2Name_ref->{$taxon_bin_oid};
    my %done;
    my @toiClusters = keys(%$toiClusterCount_ref);
    for my $c (@toiClusters) {
        next if $extClusterList_ref->{$c} eq "";
        next if $done{$c};
        $toiClusterCount_ref->{$c}++;
        $done{$c} = 1;
    }
    my $count = keys(%done);
    print "$count clusters processed by intersecting with "
      . escHtml($taxon_display_name)
      . "<br/>\n";
}

############################################################################
# doPercEvaluation - Do percentage evaluation.
#  Inputs:
#    withHomologsCount_ref - Hash gene_oid with homologs => count
#    withoutHomologsCount_ref - Hash gene_oid without homolog => count
#    percWithHomologs - percentage with homologs cutoff
#    percWithoutHomologs - percentage without homologs cutoff
#    nPositive - Number of intersecting homologs to try
#    nNegative - Number of subtracting homologs to try
#    nTaxons - number of taxons
#  Outputs:
#    withHomologsPerc_ref - gene_oid with homologs => percentage
#    withoutHomologsPerc_ref - gene_oid without homologs => percentage
#  Returns:
#    genes - List of gene_oid's qualifying for the threshold.
############################################################################
sub doPercEvaluation {
    my (
         $withHomologsCount_ref, $withoutHomologsCount_ref,
         $percWithHomologs,      $percWithoutHomologs,
         $nPositive,             $nNegative,
         $withHomologsPerc_ref,  $withoutHomologsPerc_ref
      )
      = @_;

    ## Find genes with homologs that qualify
    if ( $nPositive > 0 ) {
        my @keys = keys(%$withHomologsCount_ref);
        for my $g (@keys) {
            my $cnt  = $withHomologsCount_ref->{$g};
            my $perc = $cnt / $nPositive;
            next if $perc < ( $percWithHomologs / 100 );
            $withHomologsPerc_ref->{$g} = $perc;
        }
    }
    my $nGenes = keys(%$withHomologsPerc_ref);

    #print "$nGenes qualify with homologs<br/>\n";

    ## Find genes without homologs that qualify
    if ( $nNegative > 0 ) {
        my @keys = keys(%$withoutHomologsCount_ref);
        for my $g (@keys) {
            my $cnt  = $withoutHomologsCount_ref->{$g};
            my $perc = $cnt / $nNegative;
            next if $perc < ( $percWithoutHomologs / 100 );
            $withoutHomologsPerc_ref->{$g} = $perc;
        }
    }
    my $nGenes = keys(%$withoutHomologsPerc_ref);

    #print "$nGenes qualify without homologs<br/>\n";

    ## Find intersection of genes that qualify
    my %genes;
    if ( $nPositive > 0 && $nNegative > 0 ) {
        for my $g ( keys(%$withHomologsPerc_ref) ) {
            my $perc2 = $withoutHomologsPerc_ref->{$g};
            next if $perc2 eq "";
            $genes{$g} = 1;
        }
    } elsif ( $nPositive > 0 ) {
        for my $g ( keys(%$withHomologsPerc_ref) ) {
            $genes{$g} = 1;
        }
    } elsif ( $nNegative > 0 ) {
        for my $g ( keys(%$withoutHomologsPerc_ref) ) {
            $genes{$g} = 1;
        }
    }
    my $nGenes = keys(%genes);
    print "$nGenes remain after combined percentage evaluation<br/>\n";
    return \%genes;
}

############################################################################
# getPair2Path - Use directory organization.
############################################################################
sub getPair2Path {
    my ($pair) = @_;
    my ( $taxon1, $taxon2 ) = split( /-/, $pair );

    my $path;
    if ( $avagz_batch_dir ne "" ) {
        $path = "$avagz_batch_dir/$taxon1/$pair.m8.txt.gz";
    } elsif ( $ava_batch_dir ne "" ) {
        $path = "$ava_batch_dir/$taxon1/$pair.m8.txt";
    } else {
        webDie(   "getPair2Path: neither "
                . "avagz_batch_dir or ava_batch_dir is set\n" );
    }
    if ( !( -e $path ) ) {
        webLog("getPair2Path: WARNING: '$path' does not exist\n");
        return "";
    }
    return $path;
}

############################################################################
# loadUniqueGenes
#   Inputs:
#     taxon_oid - taxon object identifier
#     uniqueGene_ref - output list of unique genes
############################################################################
#sub loadUniqueGenes {
#    my ( $dbh, $taxon_bin_oid, $toiBinGenes_ref, $uniqueGenes_ref ) = @_;
#    my ( $taxon_oid, $bin_oid ) = split( /\./, $taxon_bin_oid );
#
#    my $sql = qq{
#       select dt.gene_oid
#       from dt_genes_wo_func dt
#       where dt.taxon = ?
#       and dt.similarity = 0
#   };
#    my $cur      = execSql( $dbh, $sql, $verbose, $taxon_bin_oid );
#    my $nSkipped = 0;
#    my $count    = 0;
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        if ( $bin_oid > 0 && $toiBinGenes_ref->{$gene_oid} eq "" ) {
#            $nSkipped++;
#            next;
#        }
#        $count++;
#        $uniqueGenes_ref->{$gene_oid} = $gene_oid;
#    }
#    $cur->finish();
#    webLog "loadUnqiueGenes: loaded=$count skipped=$nSkipped\n"
#      if $verbose >= 1;
#}

############################################################################
# printPhyloProfileResultStat
#   stat codes: (c)og, (e)nzyme, (p)fam, (u)nique, nf = no function.
#               (ca) cassette, (ke) kegg.
#   Show gene list from cache file.
#   Inputs:
#      code - stat code
#      cacheFile - name of cache file
############################################################################
sub printPhyloProfileResultStat {
    my $code      = param("code");
    my $cacheFile = param("cf");

    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $rfh = newReadFileHandle( $cachePath, "printPhyloProfileResultSet", 1 );
    if ( !$rfh ) {
        webLog "Cache '$cachePath' no longer exists\n"
          if $verbose >= 1;
        webError("This link has expired. Please run the profiler again.");
        return;
    }
    my @gene_oids;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/\s+/ /g;
        my ( $gene_oid, $args ) = split( / /, $s );
        if ( $code eq "nf" && $args !~ /[cepi]/ ) {
            push( @gene_oids, $gene_oid );
        } elsif ( $args =~ /$code/ ) {
            push( @gene_oids, $gene_oid );
        }
    }
    close $rfh;
    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {
        printStatusLine( "0 genes retrieved", 2 );
        return;
    }
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $title;
    $title = "Genes assigned to COGs"     if $code eq "c";
    $title = "Genes assigned to Enzymes"  if $code eq "e";
    $title = "Genes assigned to Pfam"     if $code eq "p";
    $title = "Genes assigned to InterPro" if $code eq "i";
    $title = "Genes assigned to KO term"  if $code eq "k";
    $title = "Genes with no function"     if $code eq "nf";
    $title = "Genes unqiue to IMG"        if $code eq "u";
    $title = "Genes assigned to Cassettes" if $code eq "ca";
    $title = "Genes assigned to KEGG Maps" if $code eq "ke";

    HtmlUtil::printGeneListHtmlTable( $title, '', $dbh, \@gene_oids );
}

############################################################################
# prinPhyloProfileResultsPage -
#   Print one page till reach end of file, or max no. of
#   rows.  If max no. of rows reached, show "more" button with file
#   name and next start position (in characters).
############################################################################
sub printPhyloProfileResultsPage {
    my ( $cacheFile, $startPos, $totalRows, $doPercentage,
         $neg_reference_oids_aref, $showPercIdCol )
      = @_;
    $cacheFile    = param("cf")           if $cacheFile    eq "";
    $startPos     = param("startPos")     if $startPos     eq "";
    $totalRows    = param("totalRows")    if $totalRows    eq "";
    $doPercentage = param("doPercentage") if $doPercentage eq "";

    my $path = "$cgi_tmp_dir/$cacheFile";
    $path = checkTmpPath($path);
    if ( !( -e $path ) ) {
        webError("Session has expired.  Please start over.");
        return;
    }

    my $rfh = newReadFileHandle( $path, "printResultsPage" );
    seek( $rfh, $startPos, 0 );
    my $count = 0;

    if ( $startPos > 0 ) {
        print
"<h1>Phylogenetic Profiler using Clusters - Gene Results (continued)</h1>\n";
    }

    printMainForm();

    # KEN - blast
    my $genomes = param("genomes");
    if ( $neg_reference_oids_aref ne "" || $genomes ne "" ) {
        if ( $neg_reference_oids_aref ne "" ) {
            my @a;
            foreach my $id (@$neg_reference_oids_aref) {
                my @tmp = split( /\./, $id );
                push( @a, $tmp[0] );
            }

            $genomes = join( ',', @a );
        }

        if ( $genomes ne "" ) {
            print qq{
            <script>
            function blast() {
                var f = document.mainForm;
                var gene = "";
                for( var i = 0; i < f.length; i++ ) {
                var e = f.elements[ i ];
                    if( e.type == "checkbox" && e.checked) {
                        gene = e.value;
                        break;
                    }
                }
                if(gene != "") {
                    //alert("gene oid = " + gene);
                    window.open("main.cgi?section=PhylogenProfiler&page=tblast&gene_oid="+gene+"&genomes=$genomes", "_self");
                } else {
                    alert("Please select a gene.");
                }
            }
            </script>
        };

            print qq{
            <p>
            <table border='0'>
            <tr>
            <td>
        <input type='button' class='smbutton' value='Missing Gene?'
        onClick='javascript:blast();' />
        </td>
        <td>      
        
        TBlastn of the <b>first selected gene</b> in the list below against 
        the genomes selected in <i>Without Homologs In Genomes</i>.
        </td>
        </tr>
        </table>
          </p>
        };
        }
    }

    printGeneCartFooter();

    my $it = new InnerTable( 1, "phylogenprofiler$$", "phylogenprofiler", 1 );
    my $sd = $it->getSdDelim();    # sort delimit
    
    $it->addColSpec("Select");
    
    $it->addColSpec( "Result",     "number asc", "right" );
    $it->addColSpec( "Gene<br/>Object<br/>ID", "number asc", "right" );
    $it->addColSpec( "Locus Tag",   "char asc", "left" );
    $it->addColSpec( "Gene Name",   "char asc", "left" );
    $it->addColSpec("Length",   "number asc", "right" );
    $it->addColSpec("COG");
    $it->addColSpec("Enzyme");
    $it->addColSpec("Pfam");
    $it->addColSpec("InterPro");
    $it->addColSpec("KO Term");
    $it->addColSpec("Tigrfam");
    $it->addColSpec("Gene Cassette ID");
    $it->addColSpec("KEGG Map Name", "", "", "", "", "", (200,400));
    $it->addColSpec("KEGG Module Name", "", "", "", "", "", (200,400));
    if ($doPercentage) {
        $it->addColSpec("With<br/>Homologs");
        $it->addColSpec("Without<br/>Homologs");
    }
    $it->addColSpec("Unique<br/>In<br/>IMG") if !$img_lite;
    # TODO add Percent Identity column - ken
    # --es 08/11/11 Not relevant here
    #$it->addColSpec( "Percent Identity", "number asc", "right", "", 'Only highest percentage found shown' );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $count     = 0;
    while ( my $s = $rfh->getline() ) {
        my (
	    $rowId,             $gene_oid,       $locus_tag,
	    $gene_display_name, $aa_seq_length,  $cogs,
	    $enzymes,           $pfams,          $iprs,
	    $kos,               $tigrfams,       $cassettes,
	    $keggs,             $keggnames,      $keggmodules,
	    $wHomologsPerc,     $woHomologsPerc, $uniqueInImg, $per
          )

          = split( /\t/, $s );
        $count++;

        if ( $count > $maxGeneListResults ) {
            last;
        }
        
        # checkbox
        my $r .= $sd
          . "<input type='checkbox' name='gene_oid' "
          . "value='$gene_oid' />" . "\t";
        $r .= $rowId . $sd . $rowId . "\t";
         
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        $url = alink( $url, $gene_oid );
        $r .= $gene_oid . $sd . $url . "\t";

        $locus_tag = "-" if blankStr($locus_tag);
        $r .= $locus_tag . $sd . $locus_tag . "\t";

	$keggnames =~ s/<br><br>$//;
        $gene_display_name = "-" if blankStr($gene_display_name);
        $cogs              = "-" if blankStr($cogs);
        $enzymes           = "-" if blankStr($enzymes);
        $pfams             = "-" if blankStr($pfams);
        $iprs              = "-" if blankStr($iprs);
        $kos               = "-" if blankStr($kos);
        $tigrfams          = "-" if blankStr($tigrfams);
        $cassettes         = "-" if blankStr($cassettes);
        $keggnames         = "-" if blankStr($keggnames);
        $keggmodules       = "-" if blankStr($keggmodules);

        $r .= $gene_display_name . $sd . $gene_display_name . "\t";
        $r .= $aa_seq_length . $sd . $aa_seq_length . "\t";
        $r .= $cogs . $sd . $cogs . "\t";
        $r .= $enzymes . $sd . $enzymes . "\t";
        $r .= $pfams . $sd . $pfams . "\t";
        $r .= $iprs . $sd . $iprs . "\t";
        $r .= $kos . $sd . $kos . "\t";
        $r .= $tigrfams . $sd . $tigrfams . "\t";
        $r .= $cassettes . $sd . $cassettes . "\t";
        $r .= $keggnames . $sd . $keggnames . "\t";
        $r .= $keggmodules . $sd . $keggmodules . "\t";

        if ($doPercentage) {
            $r .= $wHomologsPerc . $sd . $wHomologsPerc . "\t";
            $r .= $woHomologsPerc . $sd . $woHomologsPerc . "\t";
        }
        $r .= $uniqueInImg . $sd . $uniqueInImg . "\t" if !$img_lite;

        # TODO add Percent Identity column- ken
	# --es 08/11/11 Not relevant here
        #$r .= $per . $sd . $per . "\t";

        $it->addRow($r);
    }
    close $rfh;

    $it->printOuterTable(1);
    
    printGeneCartFooter() if $count > 50;
    print hiddenVar( "doPercentage", $doPercentage );

    if ( $count > $maxGeneListResults ) {
        printTruncatedStatus($maxGeneListResults);
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# printPhyloProfileFormLite - Print initial lite version of phylogenetic
#   profiler where taxons are organized and computed together in "groups".
############################################################################
#sub printPhyloProfileFormLite_old {
#
#    print "<h1>Phylogenetic Profiler for IMG-Lite</h1>\n";
#    print "<p>\n";
#    print "The current groups of precomputed similarities ";
#    print "may be used for the following sets of genomes (bins).<br/>\n";
#    print "A (+) indicates <i>Standard Reference Genomes</i> ";
#    print "is included in the group.<br/>\n";
#    print "Click on a group or member name to start the profiler.<br/>\n";
#    print "</p>\n";
#
#    my $dbh         = dbLogin();
#    my $contact_oid = getContactOid();
#    my $super_user  = getSuperUser();
#    my @sets;
#    @sets = getUserSets( $dbh, $contact_oid )
#      if $contact_oid > 0 && $super_user ne "Yes";
#    my $setStr = joinSqlQuoted( ",", @sets );
#    my $sclause;
#    $sclause = "and grp.group_id in( $setStr )" if $setStr ne "";
#    $sclause = "and 1 = 0"
#      if $setStr eq ""
#      && $contact_oid > 0
#      && $super_user ne "Yes";
#    my ($rclause, @bindList_ur) = urClauseBind("tx.taxon_oid");
#    my $sql     = qq{
#        select grp.group_id, grp.group_name, grp.has_std_ref_genomes,
#	   tx.taxon_oid, tx.taxon_display_name
#	from taxon_comparison_group grp
#	join taxon_comparison_group_taxons txs
#	   on grp.group_id = txs.group_id
#        join taxon tx
#	   on txs.taxons = tx.taxon_oid
#	where 1 = 1
#	$rclause
#	$sclause
#	order by grp.group_id, tx.taxon_display_name
#    };
#    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );
#
#    print "<p>\n";
#    my $old_group_id;
#    for ( ; ; ) {
#        my (
#             $group_id,  $group_name, $has_std_ref_genomes,
#             $taxon_oid, $taxon_display_name
#          )
#          = $cur->fetchrow();
#        last if !$group_id;
#        my $url = "$section_cgi&page=phyloProfileFormFull";
#        $url .= "&set=$group_id";
#        if ( $old_group_id ne $group_id ) {
#            print "<br/>\n" if $old_group_id ne "";
#            print "<b>\n";
#            print "Group ";
#            print alink( $url, $group_id );
#            print "</b>\n";
#            if ( $has_std_ref_genomes eq "Yes" ) {
#                print "(+)";
#            }
#            print "<br/>\n";
#        }
#        print nbsp(2);
#        print alink( $url, $taxon_display_name )
#          if $taxon_display_name ne "";
#        print "<br/>\n";
#        $old_group_id = $group_id;
#    }
#    $cur->finish();
#
#    my $sql = qq{
#	select grp.group_id, grp.group_name
#	from taxon_comparison_group grp
#        where grp.has_std_ref_genomes = ? 
#	   and grp.group_id not in(
#	    select txs.group_id
#	    from taxon_comparison_group_taxons txs
#	)
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
#    my ( $group_id, $group_name ) = $cur->fetchrow();
#    if ( $group_id ne "" ) {
#        my $url = "$section_cgi&page=phyloProfileFormFull";
#        $url .= "&set=$group_id";
#        print "<br/>\n" if $old_group_id ne "";
#        print "<b>\n";
#        print "Group ";
#        print alink( $url, "Standard Reference Genomes" );
#        print "</b> (+)\n";
#        print "<br/>\n";
#    }
#    $cur->finish();
#    print "</p>\n";
#
#    #$dbh->disconnect();
#    print "<br/>\n";
#    print "<hr/>\n";
#    print "<p>\n";
#    print "If you want a new precomputed similarity group added, or a ";
#    print "genome added to an existing group,<br/>\n";
#    print "please contact your IMG-lite administrator.<br/>\n";
#    print "</p>\n";
#}

############################################################################
# loadSetTaxonOids - Load taxon_oids belonging to a set.
############################################################################
#sub loadSetTaxonOids {
#    my ( $dbh, $setName ) = @_;
#
#    my @taxon_oids;
#
#    my $sql = qq{
#       select has_std_ref_genomes
#       from taxon_comparison_group
#       where group_id = ?
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $setName );
#    my ($has_std_ref_genomes) = $cur->fetchrow();
#    $cur->finish();
#
#    my $hideViruses = getSessionParam("hideViruses");
#    $hideViruses = "Yes" if $hideViruses eq "";
#
#    if ( $has_std_ref_genomes eq "Yes" ) {
#        my $virusClause;
#        my @bindList_vir = ();
#        if ($hideViruses eq "Yes") {
#            $virusClause = "and domain not like ? ";
#            push(@bindList_vir, 'Vir%');
#        }
#                
#        my $sql = qq{
#		    select taxon_oid
#		    from taxon
#		    where is_std_reference = ?
#		    $virusClause
#		    order by taxon_oid
#	    };
#
#	    my @bindList = ('Yes');
#	    if (scalar(@bindList_vir) > 0) {
#	    	push(@bindList, @bindList_vir);
#	    }
#        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
#        for ( ; ; ) {
#            my ($taxon_oid) = $cur->fetchrow();
#            last if !$taxon_oid;
#            push( @taxon_oids, $taxon_oid );
#        }
#        $cur->finish();
#    }
#
#    my $sql = qq{
#        select taxons
#		from taxon_comparison_group_taxons
#		where group_id = ? 
#		order by taxons
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $setName );
#    for ( ; ; ) {
#        my ($taxons) = $cur->fetchrow();
#        last if !$taxons;
#        push( @taxon_oids, $taxons );
#    }
#    $cur->finish();
#    return @taxon_oids;
#}

############################################################################
# loadSetTaxonOids2 - Load taxon_oid's belonging to a set.
#   This version just returns a flag for standard reference genomes.
############################################################################
#sub loadSetTaxonOids2 {
#    my ( $dbh, $setName ) = @_;
#
#    my @taxon_oids;
#
#    my $sql = qq{
#       select has_std_ref_genomes
#       from taxon_comparison_group
#       where group_id = ?
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $setName );
#    my ($has_std_ref_genomes) = $cur->fetchrow();
#    $cur->finish();
#
#    my $sql = qq{
#        select taxons
#		from taxon_comparison_group_taxons
#		where group_id = ? 
#		order by taxons
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $setName );
#    for ( ; ; ) {
#        my ($taxons) = $cur->fetchrow();
#        last if !$taxons;
#        push( @taxon_oids, $taxons );
#    }
#    $cur->finish();
#    return ( $has_std_ref_genomes, @taxon_oids );
#}

############################################################################
# getUserSets - Get only sets that the user has access to.
#    Users have access to a set if they own at least one private genome
#    in it.
#    Return list of set ID's that are valid.
############################################################################
#sub getUserSets {
#    my ( $dbh, $contact_oid ) = @_;
#    my $sql = qq{
#        select distinct group_id
#	from taxon_comparison_group_taxons tcgt, contact_taxon_permissions ctp
#	where tcgt.taxons = ctp.taxon_permissions
#	and ctp.contact_oid = ?
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
#    my @sets;
#    for ( ; ; ) {
#        my ($group_id) = $cur->fetchrow();
#        last if !$group_id;
#        push( @sets, $group_id );
#    }
#    $cur->finish();
#    return @sets;
#}

1;
