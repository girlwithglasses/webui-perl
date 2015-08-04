############################################################################
# Help.pm - site map for all documents in IMG
#
# $Id: Help.pm 33640 2015-06-24 21:06:45Z klchu $
############################################################################
package Help;
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;

$| = 1;

my $section                 = "Help";
my $env                     = getEnv();
my $cgi_dir                 = $env->{cgi_dir};
my $cgi_url                 = $env->{cgi_url};
my $cgi_tmp_dir             = $env->{cgi_tmp_dir};
my $main_cgi                = $env->{main_cgi};
my $base_url                = $env->{base_url};
my $base_dir                = $env->{base_dir};
my $tmp_url                 = $env->{tmp_url};
my $tmp_dir                 = $env->{tmp_dir};
my $verbose                 = $env->{verbose};
my $no_phyloProfiler        = $env->{no_phyloProfiler};
my $full_phylo_profiler     = $env->{full_phylo_profiler};
my $phyloProfiler_sets_file = $env->{phyloProfiler_sets_file};
my $scaffold_cart           = $env->{scaffold_cart};
my $img_pheno_rule          = $env->{img_pheno_rule};
my $img_pheno_rule          = $env->{img_pheno_rule};
my $include_metagenomes     = $env->{include_metagenomes};
my $include_tigrfams        = $env->{include_tigrfams};
my $include_img_terms       = $env->{include_img_terms};
my $img_edu                 = $env->{img_edu};
my $img_er                  = $env->{img_er};
my $img_lite                = $env->{img_lite};
my $img_internal            = $env->{img_internal};
my $user_restricted_site    = $env->{user_restricted_site};
my $public_nologin_site     = $env->{public_nologin_site};
my $show_myimg_login        = $env->{show_myimg_login};
my $enable_interpro         = $env->{enable_interpro};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param('page');

    if ( $page eq "sitemap" ) {
        printSiteMap();
    } elsif ( $page eq "ftppolicy" ) {
        printFtpPolicy();
    } elsif ( $page eq "ftpreadme" ) {
        printFtpReadMe();
    } elsif ( $page eq "policypage" ) {
        printFtpPolicyPage();
    } elsif ( $page eq 'cite' ) {
        printCite();

    } elsif ( $page eq 'docs' ) {
        printDocs();

    } elsif ( $page eq 'news' ) {
        printNews();

    } else {
        printSiteMap();
    }
}

sub printNews {
    print qq{
<h1>News</h1>
    };

    # read news  file
    my $file = '/webfs/scratch/img/news.html';
    if ( -e $file ) {
        my $line;
        my $rfh = newReadFileHandle($file);
        while ( $line = $rfh->getline() ) {
            print $line;
        }
        close $rfh;
    }
}

sub printDocs {
    print qq{
<h1>IMG Document Archive</h1>
         <p>
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#userguide">User Guide</a><br/>         
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#new">What's New in IMG</a><br/>
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#archive">Archive of past What's New</a><br/>
        </p>
        
    };

    print qq{
    <a name='userguide' href='#'><h2> User Guide </h2></a>
        <p>
        <a href="$base_url/doc/userGuide.pdf" onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide']);">
            <img src="$base_url/images/icon_pdf_medium.png" border="0" />
        </a>
        </p>
    };

    # SingleCellDataDecontamination.pdf

    printWhatsNew();
    printWhatsNewArchive();
}

sub printCite {
#    my $file = "$base_dir/cite.html";
#    my $s    = file2Str($file);
#    print "$s\n";
}

sub printFtpReadMe {
    printFtpDepreciated();

#    my $file = "$base_dir/ftp-readme.html";
#    my $s    = file2Str($file);
#    print "$s\n";
}

# the page without ok button to ftp site
sub printFtpPolicyPage {
    my $file = "$base_dir/ftp-policy.html";
    my $s    = file2Str($file);
    print "$s\n";
}

sub printFtpDepreciated {
    print qq{
<h3>IMG FTP Depreciated</h3>
<p>
<b>The IMG FTP site is being replaced with the <a href="http://genome.jgi.doe.gov/">JGI Genome Portal</a></b>
See <a href="https://groups.google.com/a/lbl.gov/forum/?hl=en#!searchin/img-user-forum/ftp/img-user-forum/Ivbo4ivK4j0/ufoMkiLTtzgJ"> our forum</a>
</p>
    };

}


# ok button before going to ftp sites
sub printFtpPolicy {
    printFtpDepreciated();

    printFtpPolicyPage();

    print qq{
<br/>
<div>
<input type="button" value="OK" onclick="javascript:window.open('ftp://ftp.jgi-psf.org/pub/IMG/','_self');" />
</div>        
    };
}

sub printSiteMap {
    print qq{
	<h1>Site Map</h1>
	    
	<p>
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#menu">Navigation Menus</a><br/>
&nbsp;&nbsp;&nbsp;&nbsp;<a href="#comp">sub-Pages and Components</a><br/>
        </p>
    };

    printNavigationMenus();
    printComponentPages();
}

sub printWhatsNew {

    print qq{
        <a name='new' href='#'><h2>What's New in IMG</h2></a>
        <table boder='0'>
        <tr>
        <td align="left" style="padding-right: 25px;">
        
        <a href="$base_url/doc/releaseNotes.pdf" onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'release notes']);">
            <img src="$base_url/images/icon_pdf_medium.png" border="0" />
        </a> <br/>
        &nbsp;
        </td>
    };

    if ($img_er) {

        # https://img-stage.jgi-psf.org/er/doc/userGuideER.pdf
        print qq{
            <td align="left" style="padding-right: 25px;">
        
        <a href="$base_url/doc/userGuideER.pdf" onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide er']);">
            <img src="$base_url/images/icon_pdf_medium.png" border="0" /> 
        </a> <br/>
        IMG/ER Tutorial
            </td>
        };
    }

    # http://localhost/~ken/web25m.htd/doc/userGuide_m.pdf
    if ($include_metagenomes) {
        print qq{
            <td align="left" style="padding-right: 25px;">
        
        <a href="$base_url/doc/userGuide_m.pdf" onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide m']);">
            <img src="$base_url/images/icon_pdf_medium.png" border="0" />  
        </a> <br/>
        IMG/M Addendum
        </td>

        };
    }

    print qq{
        </tr>
        </table>
    };
}

sub printNavigationMenus {
    my $contact_oid = getContactOid();
    my $isEditor    = 0;
    if ($user_restricted_site) {
        my $dbh = dbLogin();
        $isEditor = isImgEditor( $dbh, $contact_oid );
    }

    print qq{
	<a name='menu' href='#'><h2>Navigation Menus</h2> </a>
        <table class='img'>
	    <th class='img'> Menu </th>
	    <th class='img'> Description </th>
	    <th class='img'> Document </th>
	      <tr class='highlight' valign='top'>
	      <td class='img'> <a href="$main_cgi"> <b>IMG Home</b> </a> </td>
	      <td class='img'> IMG home page </td>
	      <td class='img'></td>
	    </tr>
    };

    printFindGenomesMap();
    printFindGenesMap();
    printFindFunctionsMap();
    printCompareGenomesMap();
    printAnalysisCartMap($isEditor);
    printMyImgMap($contact_oid);

    printCompanionSystem();

    printUsingMap();

    print "</table>\n";
}

sub printFindGenomesMap {
    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=FindGenomes&page=findGenomes">
	    <b>Find Genomes</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=TaxonList&page=taxonListAlpha">
		Genome Browser </a>

	    </td>
	    <td class='img'>
	    &nbsp; 
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/GenomeBrowser.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'genome broeser']);">
	    <img width="20" height="14" border="0"
	    style="margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif"> 
	    </a>
	    </td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/binocular.png">
	    <a href="$main_cgi?section=FindGenomes&page=genomeSearch"> 
	    Genome Search </a>
	    </td>
	    <td class='img'>
	    By Fields <br/>
	    By Metadata <br/>
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/GenomeSearch.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'genome search']);">
	    <img width="20" height="14" border="0" 
	    style="margin-top: 10px;margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif"> 
	    </a>
	    </td>
	</tr>
    };

    if ($img_internal) {
        print qq{

            <tr class='img' valign="top">
                <td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=TaxonList&page=categoryBrowser">
		    Category Browser </a>
                </td>
                <td class='img'>
		View genomes organized by genome categories e.g. Oxygen Requirement, Ecosystem, etc.
		</td>
                <td class='img'></td>
            </tr>
        };
    }
}

sub printFindGenesMap {
    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=FindGenes&page=findGenes">
	    <b>Find Genes</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/binocular.png">
	    <a href="$main_cgi?section=FindGenes&page=geneSearch">
	    Gene Search </a>

	    </td>
	    <td class='img'>
	    Find genes in selected genomes by keyword.
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/GeneSearch.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'gene search']);">
	    <img width="20" height="14" border="0"
	    style="margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif"> 
	    </a>
	    </td>
	</tr>
    };

    if ( !$include_metagenomes && !$img_lite ) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=GeneCassetteSearch&page=form">
		    Cassette Search </a>
        <img width="45" height="14" border="0"
        style="margin-left: 5px;" src="$base_url/images/updated.bmp">		    
		</td>
		<td class='img'>
		&nbsp;
	        </td>
		<td class='img'></td>
	    </tr>
	};
    }

    print qq{
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/blast.ico">
	    <a href="$main_cgi?section=FindGenesBlast&page=geneSearchBlast">
	    BLAST </a>
	    </td>
	    <td class='img'>
	    Find sequence similarity in IMG database.
	    </td>
            <td class='img'>
	    <a href='$base_url/doc/Blast.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'blast']);">
	    <img width="20" height="14" border="0" 
	    style="margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif"> 
	    </a>
            </td>
	</tr>
    };

    if ( !$no_phyloProfiler ) {
        if ( !$img_lite || $full_phylo_profiler ) {
            if ( !$img_lite ) {
                print qq{
		<tr class='img' valign='top'>
		    <td class='img'> 
		    &nbsp; &nbsp; &nbsp; &nbsp;
		    <a href="$main_cgi?section=GeneCassetteProfiler&page=genetools">
			<b>Phylogenetic Profilers</b></a>
		    </td>
		    <td class='img'>
		    &nbsp;
		    </td>
		    <td class='img'></td>
		</tr>
		    
		<tr class='img' valign='top'>
		    <td class='img'> 
		    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
		    <a href="$main_cgi?section=PhylogenProfiler&page=phyloProfileForm"> Single Genes </a>
		    </td>
		    <td class='img'>
		    Find genes in genome (bin) of interest qualified by 
		    similarity to sequences in other genomes (based on BLASTP
		    alignments). Only user-selected genomes appear in the
		    profiler. 
		    </td>
		    <td class='img'></td>
		</tr>
		    
		<tr class='img' valign='top'>
		    <td class='img'> 
		    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
		    <a href="$main_cgi?section=GeneCassetteProfiler&page=geneContextPhyloProfiler2"> Genes Cassettes </a>
		    </td>
		    <td class='img'>
		    IMG Cassette Profiler. Find collocated genes that are part 
		    of a cassette in a query genome, that are also part of 
		    gene cassettes in other genomes of interest 
		    </td>
		    <td class='img'></td>
		</tr>
	    };

            } else {
                print qq{
		<tr class='img' valign='top'>
		    <td class='img'> 
		    &nbsp; &nbsp; &nbsp; &nbsp;
		    <a href="$main_cgi?section=PhylogenProfiler&page=phyloProfileForm"> Phylogenetic Profilers </a>
                    </td>
		    <td class='img'>
		    Find genes in genome (bin) of interest qualified by 
		    similarity to sequences in other genomes (based on 
		    BLASTP alignments). Only user-selected genomes appear 
		    in the profiler. 
		    </td>
		    <td class='img'></td>
                </tr>
	        };
            }
        }

        if (   $img_lite
            && -e $phyloProfiler_sets_file
            && !$full_phylo_profiler )
        {

            print qq{
	      <tr class='img' valign='top'>
		  <td class='img'> 
		  &nbsp; &nbsp; &nbsp; &nbsp;
	          <a href="$main_cgi?section=PhylogenProfiler&page=phyloProfileFormLite"> Phylogenetic Profilers </a>
		  </td>
		  <td class='img'>
		  &nbsp;
	          </td>
		  <td class='img'></td>
	      </tr>
	  };
        }
    }

    if ($img_internal) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=ProteinCluster">
		    Protein Clusters </a>
		</td>
		<td class='img'>
		&nbsp;
	        </td>
		<td class='img'></td>
	    </tr>
        };
    }
}

sub printFindFunctionsMap {
    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=FindFunctions&page=findFunctions">
	    <b>Find Functions</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=FindFunctions&page=findFunctions">
		Function Search </a>
		<img width="45" height="14" border="0" 
		style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	    </td>
	    <td class='img'>
	    Find functions in selected genomes by keyword.
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/FunctionSearch.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'function search']);">
	    <img width="20" height="14" border="0"  
	    style="margin-left: 20px; vertical-align:middle" 
	    src="$base_url/images/help_book.gif"> 
	    </a>
	    </td>
	</tr>
	
    };

    #    print qq{
    #        <tr class='img' valign='top'>
    #            <td class='img'>
    #                &nbsp; &nbsp; &nbsp; &nbsp;
    #                <a href="$main_cgi?section=AllPwayBrowser&page=allPwayBrowser"> Search Pathways </a>
    #            </td>
    #            <td class='img'></td>
    #            <td class='img'></td>
    #        </tr>
    #    };

    if ($include_metagenomes) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=PhyloCogs&page=phyloCogTaxonsForm">
		    Phylogenetic Marker COGs </a>
		</td>
		<td class='img'>
		List of COGs 
		</td>
		<td class='img'></td>
	    </tr>
        };
    }

    # <img width="25" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/new.gif">

    print qq{
    <tr class='img' valign='top'>
	<td class='img'> 
	&nbsp; &nbsp; &nbsp; &nbsp;
        <a href="$main_cgi?section=FindFunctions&page=ffoAllCogCategories"> COG </a>
	</td>
	<td class='img'>
	List of COGs 
	</td>
	<td class='img'></td>
    </tr>

    <tr class='img' valign='top'>
        <td class='img'> 
        &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="$main_cgi?section=FindFunctions&page=ffoAllKogCategories"> KOG </a>
                
        </td>
        <td class='img'> </td>
        <td class='img'> </td>
    </tr>
	
    <tr class='img' valign='top'>
        <td class='img'>
	&nbsp; &nbsp; &nbsp; &nbsp;
        <img class="menuimg" src="$base_url/images/pfam.png">
	<a href="$main_cgi?section=FindFunctions&page=pfamCategories">
	Pfam </a>
	</td>
	<td class='img'>
	Pfam list
	</td>
	<td class='img'></td>
    </tr>
    };

    if ($include_tigrfams) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=TigrBrowser&page=tigrBrowser">
		    TIGRfam </a>
		</td>
		<td class='img'>
		TIGRfam roles and list
		</td>
		<td class='img'></td>
	    </tr>
        };
    }

  #    print qq{
  #
  #    <tr class='img' valign='top'>
  #        <td class='img'>
  #        &nbsp; &nbsp; &nbsp; &nbsp;
  #        <a href="$main_cgi?section=FindFunctions&page=ffoAllSeed">
  #        SEED </a>
  #        </td>
  #        <td class='img'>
  #        List of SEED product names and subsystems.
  #        </td>
  #            <td class='img'>
  #        <a href='$base_url/doc/SEED.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'seed']);">
  #        <img width="20" height="14" border="0"
  #        style="margin-left: 20px; vertical-align:middle"
  #        src="$base_url/images/help_book.gif">
  #        </a>
  #            </td>
  #    </tr>
  #    };

    print qq{
	<tr class='img' valign='top'>
	    <td class='img' NOWRAP> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=FindFunctions&page=ffoAllTc">
		Transporter Classification </a>
	    </td>
	    <td class='img'>
	    List of Transporter Classification families
	    </td>
            <td class='img'>
	    <a href='$base_url/doc/TransporterClassification.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'transporter class']);">
	    <img width="20" height="14" border="0" 
	    style="margin-left: 20px; vertical-align:middle" 
	    src="$base_url/images/help_book.gif"> 
	    </a>
            </td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=FindFunctions&page=ffoAllKeggPathways&view=brite"> KEGG </a>
        <img width="45" height="14" border="0" 
        style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	    
	    </td>
	    <td class='img'>
	    KEGG Orthology (KO) Terms and Pathways <br/>
	    KO Term Distribution <br/>
	    KEGG Orthology (KO) Terms
	    </td>
	    <td class='img'></td>
	</tr>
    };

    if ($include_img_terms) {
        print qq{
        <tr class='img' valign='top'>
        <td class='img' nowrap='nowrap'> 
        &nbsp; &nbsp; &nbsp; &nbsp;
            <img class="menuimg" src="$base_url/favicon.ico">
        <a href="$main_cgi?section=ImgNetworkBrowser&page=imgNetworkBrowser"> <b>IMG Network</b> </a>
        </td>
        <td class='img'>
        IMG Network Browser <br/>
        IMG Parts List <br/>
        IMG Pathways <br/>
        IMG Terms
        </td>
        <td class='img'></td>
        </tr>
            
            <tr class='img' valign='top'>
                <td class='img' nowrap='nowrap'> 
                    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <img class="menuimg" src="$base_url/favicon.ico">
                    <a href="main.cgi?section=ImgNetworkBrowser&page=imgNetworkBrowser"> IMG Network Browser </a>
                </td>
                <td class='img'></td>
                <td class='img'></td>
            </tr>
                
            <tr class='img' valign='top'>
                <td class='img'> 
                    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <img class="menuimg" src="$base_url/favicon.ico">
                    <a href="main.cgi?section=ImgPartsListBrowser&page=browse"> IMG Parts List </a>
                </td>
                <td class='img'></td>
                <td class='img'></td>
            </tr>
                
            <tr class='img' valign='top'>
                <td class='img'> 
                    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <img class="menuimg" src="$base_url/favicon.ico">
                    <a href="main.cgi?section=ImgPwayBrowser&page=imgPwayBrowser"> IMG Pathways </a>
                </td>
                <td class='img'>
                </td>
                <td class='img'></td>
            </tr>
                
            <tr class='img' valign='top'>
                <td class='img'> 
                    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <img class="menuimg" src="$base_url/favicon.ico">
                    <a href="main.cgi?section=ImgTermBrowser&page=imgTermBrowser"> IMG Terms </a>
                </td>
                <td class='img'></td>
                <td class='img'></td>
            </tr>
        };
    }

    print qq{
    <tr class='img' valign='top'>
        <td class='img'> 
        &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="$main_cgi?section=FindFunctions&page=enzymeList">
        Enzyme </a>
        </td>
        <td class='img'>
        List of Enzymes, EC numbers
        </td>
        <td class='img'></td>
    </tr>    
};

    if ( !$include_metagenomes ) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=MetaCyc"> MetaCyc </a>
		</td>
		<td class='img'>
		MetaCyc Pathways
		</td>
		<td class='img'></td>
	    </tr>
        };
    }

    if ($img_pheno_rule) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=ImgPwayBrowser&page=phenoRules">
		    Phenotypes </a>
	        </td>
		<td class='img'></td>
		<td class='img'></td>
	    </tr>
        };
    }

    if ($enable_interpro) {
        print qq{
        <tr class='img' valign='top'>
            <td class='img'> 
                &nbsp; &nbsp; &nbsp; &nbsp;
                <a href="$main_cgi?section=Interpro"> InterPro List </a>
                <img width="25" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/new.gif">
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
    };
    }

    print qq{
        <tr class='img' valign='top'>
            <td class='img' nowrap> 
                &nbsp; &nbsp; &nbsp; &nbsp;
                <a href="$main_cgi?section=ImgTermStats&page=functionCompare"> Protein Family Comparison </a>
                <img width="25" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/new.gif">
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
    };
}

sub printCompareGenomesMap {
    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=CompareGenomes&page=compareGenomes">
	    <b>Compare Genomes</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=CompareGenomes&page=compareGenomes">
		Genome Statistics </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=Vista&page=toppage">
		<b>Synteny Viewers</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/vista.ico">
	    <a href="$main_cgi?section=Vista&page=vista"> VISTA </a>
	    </td>
	    <td class='img'>
	    VISTA is used for alignemt of full scaffolds between multiple genomes.
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=DotPlot&page=plot"> Dotplot </a>
	    <!-- <img width="45" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	    -->
	    </td>
	    <td class='img'>
	    Dot Plot employs Mummer to generate dotplot diagrams between two genomes.  
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/Dotplot.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'dot plot']);">
	    <img width="20" height="14" border="0" 
	    style="margin-left: 20px; vertical-align:middle" 
	    src="$base_url/images/help_book.gif">
	    </a>
	    </td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/sanger-ico.png">
	    <a href="$main_cgi?section=Artemis&page=ACTForm"> Artemis ACT </a>
	    </td>
	    <td class='img'>
	    ACT (Artemis Comparison Tool) is a viewer based on Artemis for 
	    pair-wise genome DNA sequence comparisons, whereby comparisons 
	    are usually the result of running Mega BLAST search. 
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=DistanceTree&page=tree">
		Distance Tree </a>
        <!-- <img width="45" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/updated.bmp">
        -->
	    </td>
	    <td class='img'>
	    Circular phylogenetic tree for selected genomes.
	    </td>
	    <td class='img'>
	    <a href='$base_url/doc/DistanceTree.pdf' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'distance tree']);"> 
	    <img width="20" height="14" border="0" 
	    style="margin-left: 20px; vertical-align:middle" 
	    src="$base_url/images/help_book.gif"> 
	    </td>
	</tr>

	<tr class='img' valign="top">
            <td class='img' nowrap='nowrap'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
            <a href="$main_cgi?section=RadialPhyloTree"> Radial Phylogenetic Tree </a>
                    
	    </td>
	    <td class='img'> </td>
	    <td class='img'> </td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=AbundanceProfiles&page=topPage">
		<b>Abundance Profiles</b> </a>
	    </td>
	    <td class='img'>
	    The following tools operate on functional profiles of multiple genomes.
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=AbundanceProfiles&page=mergedForm">
		Overview (All Functions) </a>
	    </td>
	    <td class='img'>
	    View abundance for all functions across selected genomes.
	    </td>
	    <td class='img'> 
	};

    if ($include_metagenomes) {
        print
qq{<a href='$base_url/doc/userGuide_m.pdf#page=18' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide m']);">};
    } else {
        print
qq{<a href='$base_url/doc/userGuide.pdf#page=49' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide']);">};
    }

    print qq{
	    <img width="20" height="14" border="0"
	    style="margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif">
	    </a> 
	    </td> 
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=AbundanceProfileSearch"> Search </a>
	    </td>
	    <td class='img'>
	    Search for functions based on over or under abundance in other genomes.
	    </td>
	    <td class='img'> 
	};

    if ($include_metagenomes) {
        print
qq{<a href='$base_url/doc/userGuide_m.pdf#page=19' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide m']);">};
    } else {
        print
qq{<a href='$base_url/doc/userGuide.pdf#page=51' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'help', 'user guide']);">};
    }

    print qq{
	    <img width="20" height="14" border="0"
	    style="margin-left: 20px; vertical-align:middle"
	    src="$base_url/images/help_book.gif">
	    </a> 
	    </td> 
	</tr>
    };

    if ($include_metagenomes) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=AbundanceComparisons">
		    Function Comparisons </a>
	        </td>
		<td class='img'>
		Compare metagenomes in terms of relative abundance of COGs, Pfams, TIGRFams, and Enzymes.
		</td>
                <td class='img'>
                <a href='$base_url/doc/userGuide_m.pdf#page=20' target='_help'>
                <img width="20" height="14" border="0"
                style="margin-left: 20px; vertical-align:middle"
                src="$base_url/images/help_book.gif"> 
                </a> 
                </td>
	    </tr>

            <tr class='img' valign='top'>
                <td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp;
  	        <a href="$main_cgi?section=AbundanceComparisonsSub">
		    Function Category Comparisons </a>
                </td>
                <td class='img'>
		Compare metagenomes in terms of relative abundance of genes assigned to different functional categories.
		</td>
		<td class='img'> 
                <a href='$base_url/doc/userGuide_m.pdf#page=23' target='_help'>
                <img width="20" height="14" border="0"
                style="margin-left: 20px; vertical-align:middle"
                src="$base_url/images/help_book.gif">
                </a>
		</td>
            </tr>
        };
    }

    print qq{
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=FunctionProfiler&page=profiler">
		Function Profile </a>
	    </td>
	    <td class='img'>
	    Display the count (abundance) of genes associated with 
	    a given function and a given genome.
	    </td>
	    <td class='img'>
                <a href='$base_url/doc/releaseNotes2-7.pdf#page=6' target='_help'> 
                <img width="20" height="14" border="0" 
                style="margin-left: 20px; vertical-align:middle" 
                src="$base_url/images/help_book.gif">
                </a> 
	    </td>
	</tr>
	    
	<tr class='img' valign='top'>
	    <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=EgtCluster&page=topPage">
		Genome Clustering </a>
	    </td>
	    <td class='img'>
	    Cluster samples (genomes) based on similar COG, Pfam, or enzyme profiles.
	    </td>
	    <td class='img'></td>
	</tr>
    };

    #    if ($img_edu) {
    #        print qq{
    #            <tr class='img' valign='top'>
    #                <td class='img'>
    #		&nbsp; &nbsp; &nbsp; &nbsp;
    #	        <a href="$main_cgi?section=CompareGeneModels&page=topPage">
    #		    Compare Gene Models </a>
    #                </td>
    #                <td class='img'></td>
    #                <td class='img'></td>
    #            </tr>
    #        };
    #    }
    if ($include_metagenomes) {
        print qq{
	    <tr class='img' valign="top">
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=MetagPhyloDist&page=top">
		    <b>Phylogenetic Distribution</b> </a>
	        </td>
		<td class='img'></td>
		<td class='img'></td>
	    </tr>
	    
	    <tr class='img' valign="top">
	        <td class='img' nowrap="nowrap"> 
		&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="main.cgi?section=MetagPhyloDist&page=form">
		    Metagenome Phylogenetic Distribution </a>
	        </td>
		<td class='img'></td>
		<td class='img'></td>
	    </tr>

            <tr class='img' valign="top">
                <td class='img' nowrap="nowrap"> 
                    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <a href="main.cgi?section=GenomeHits"> Genome vs Metagenomes </a>
                </td>
                <td class='img'></td>
                <td class='img'></td>
            </tr>
        };
    }
    print qq{
        <tr class='img' valign='top'>
            <td class='img'> 
                &nbsp; &nbsp; &nbsp; &nbsp;
                <a href="$main_cgi?section=GenomeGeneOrtholog"> Genome Gene Ortholog </a>
                <img width="25" height="14" border="0" style="margin-left: 5px;" src="$base_url/images/new.gif">
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
    };

}

sub printAnalysisCartMap {
    my ($isEditor) = @_;

    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=GeneCartStor&page=geneCart">
	    <b>Analysis Cart</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=GeneCartStor&page=geneCart"> Genes </a>
            <img width="45" height="14" border="0"
	    style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	    </td>
	    <td class='img'>
	        Gene List <br/>
		Function Cart <br/>
		Upload Gene Cart from File <br/>
		Export Genes <br/>
		Chromosome Map <br/>
		Sequence Alignments <br/>
		Gene Neighborhoods <br/>
		Gene Profile <br/>
		Occurrence Profile <br/>
		Function Alignment
	    </td>
            <td class='img'>
                <a href='$base_url/doc/GeneCart.pdf' target='_help'>
                <img width="20" height="14" border="0" 
		style="margin-left: 20px; vertical-align:middle" 
		src="$base_url/images/help_book.gif"> 
                </a>
            </td>
	    </tr>
	
	    <tr class='img' valign='top'>
	        <td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=FuncCartStor&page=funcCart">
		    Functions </a>
                <img width="45" height="14" border="0"
		style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	        </td>
	        <td class='img'>
	            Function List  <br/>
	            Upload Function Cart from File  <br/>
	            Export Functions <br/>
	            Function Profile  <br/>
	            Occurrence Profiles  <br/>
	            Function Alignment <br/>
	            Gene Cart
	        </td>
            <td class='img'>
                <a href='$base_url/doc/FunctionCart.pdf' target='_help'>
                <img width="20" height="14" border="0"
		style="margin-left: 20px; vertical-align:middle" 
		src="$base_url/images/help_book.gif"> 
                </a>
            </td>
	    </tr>

        <tr class='img' valign='top'>
            <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=MyIMG&page=taxonUploadForm">
		Genomes </a>
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
    };

    if ($scaffold_cart) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=ScaffoldCart&page=index">
		    Scaffolds </a>
            <img width="45" height="14" border="0"
        style="margin-left: 5px;" src="$base_url/images/updated.bmp">		    
		</td>
		<td class='img'>
		Scaffold List <br/>
		Scaffold Cart Name <br/>
		Function Profile <br/>
		Export and Import Scaffold Data <br/>
		Histogram <br/>
		Phylogenetic Distribution of Genes <br/> 
		</td>
		<td class='img'></td>
	    </tr>
        };
    }

    if ($isEditor) {
        print qq{
            <tr class='img' valign='top'>
                <td class='img'> 
                    &nbsp; &nbsp; &nbsp; &nbsp;
	            <a href="$main_cgi?section=CuraCartStor&page=curaCart">
			Curation </a>
                </td>
                <td class='img'></td>
                <td class='img'></td>
            </tr>
        };
    }

}

sub printMyImgMap {
    my ($contact_oid) = @_;

    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="$main_cgi?section=MyIMG"> <b>MyIMG</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=MyIMG&page=home"> MyIMG Home </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
    };

    if ( $contact_oid > 0 && $show_myimg_login && !$public_nologin_site ) {
        print qq{
	    <tr class='img' valign='top'>
		<td class='img'> 
		&nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="$main_cgi?section=MyIMG&page=myAnnotationsForm">
		    Annotations </a>
	        </td>
		<td class='img'>
		&nbsp;
	        </td>
	        <td class='img'></td>
	    </tr>
        };
    }

    print qq{
	<tr class='img' valign='top'>
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=MyIMG&page=preferences">
		Preferences </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
    };

    if ($user_restricted_site) {
        print qq{
            <tr class='img' valign='top'>
                <td class='img'> 
                    &nbsp; &nbsp; &nbsp; &nbsp;
                    <a href="$main_cgi?section=Workspace"> Workspace </a>
                </td>
                <td class='img'>
                    My saved data Genes, Functions, Scaffolds, Genomes
                </td>
                <td class='img'></td>
            </tr>
        };
    }
}

sub printCompanionSystem {
    print qq{
    <tr class='highlight' valign='top'>
        <td class='img'> 
        <a href="/"> <b>Companion Systems</b> </a>
            <img width="45" height="14" border="0" 
        style="margin-left: 5px;" src="$base_url/images/updated.bmp">        
        </td>
        <td class='img'>
        &nbsp;
        </td>
        <td class='img'></td>
    </tr>
    
    
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/w"> <b>IMG</b> </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>    


    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/w"> IMG </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>    
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="https://img.jgi.doe.gov/er"> IMG/ER </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>   
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/geba"> IMG/GEBA </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr> 
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="http://img.jgi.doe.gov/img_hmp"> IMG/HMP </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr> 
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/edu"> IMG/EDU IMG/ACT </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>     
    
    
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/m"> <b>IMG/M</b> </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>    
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="/m"> IMG/M </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>        
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="https://img.jgi.doe.gov/mer"> IMG/MER </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>        
    <tr class='img' valign="top">
        <td class='img'> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
        <a href="http://img.jgi.doe.gov/imgm_hmp"> IMG/HMPM </a>
        </td>
        <td class='img'> &nbsp; </td>
        <td class='img'> &nbsp; </td>
    </tr>        

    };
}

sub printUsingMap {
    print qq{
	<tr class='highlight' valign='top'>
	    <td class='img'> 
	    <a href="about_index.html"> <b>Using IMG</b> </a>
	    </td>
	    <td class='img'>
	    &nbsp;
	    </td>
	    <td class='img'></td>
	</tr>
	 
	<tr class='img' valign="top">
	    <td class='img'> 
	        &nbsp; &nbsp; &nbsp; &nbsp;
	        <img class="menuimg" src="$base_url/images/information.png">
		<a href="about_index.html"> <b>About IMG</b> </a>
	    </td>
	    <td class='img'>
	    Information about IMG
	    </td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$base_url/doc/mission.html"> IMG Mission </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$base_url/doc/faq.html"> FAQ </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$base_url/doc/related.html"> Related Links </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$base_url/doc/credits.html"> Credits </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img'> 
	    &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/question.png">
	    <a href="using_index.html"> User Guide </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$base_url/doc/systemreqs.html"> System Requirements </a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <a href="$main_cgi?section=Help"> Site Map </a>
            <img width="45" height="14" border="0" 
	    style="margin-left: 5px;" src="$base_url/images/updated.bmp">
	    </td>
	    <td class='img'>
	    Contains links to all tools and documents, including an archive of past What's New documents
	    </td>
            <td class='img'>
                <a href='$base_url/doc/SiteMap.pdf' target='_help'>
                <img width="20" height="14" border="0" 
                style="margin-left: 20px; vertical-align:middle"
                src="$base_url/images/help_book.gif"> 
                </a>
            </td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	    <img class="menuimg" src="$base_url/images/icon_pdf.gif">
	    <a href="$base_url/doc/images/uiMap.pdf"> User Interface Map</a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
	
	<tr class='img' valign="top">
	    <td class='img' nowrap="nowrap"> 
	        &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	        <img class="menuimg" src="$base_url/images/icon_pdf.gif">
	        <a href="$base_url/doc/userGuide.pdf">
                IMG User Manual</a>
	    </td>
	    <td class='img'></td>
	    <td class='img'></td>
	</tr>
    };

    if ($img_er) {
        print qq{
    <tr class='img' valign="top">
        <td class='img' nowrap="nowrap"> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
            <img class="menuimg" src="$base_url/images/icon_pdf.gif">
            <a href="$base_url/doc/userGuideER.pdf">
                IMG ER Tutorial</a>
        </td>
        <td class='img'></td>
        <td class='img'></td>
    </tr>
        };
    }

    if ($include_metagenomes) {
        print qq{
    <tr class='img' valign="top">
        <td class='img' nowrap="nowrap"> 
            &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
            <img class="menuimg" src="$base_url/images/icon_pdf.gif">
            <a href="$base_url/doc/userGuide_m.pdf">
                IMG/M Addendum</a>
        </td>
        <td class='img'></td>
        <td class='img'></td>
    </tr>
        };
    }

    print qq{
        <tr class='img' valign='top'>
            <td class='img' nowrap> 
                &nbsp; &nbsp; &nbsp; &nbsp;
                <img src="$base_url/images/download_icon.png"/>
                <a href="$main_cgi?section=Help&page=policypage"> <b> Downloads </b> </a>
                <!--
                <img width="25" height="14" border="0" 
                style="margin-left: 5px;" src="$base_url/images/new.gif">
                -->
            </td>
            <td class='img'>
                Download public genome sequence files used in 
                <a href='http://img.jgi.doe.gov/'> IMG/W </a>
            </td>
            <td class='img'></td>
        </tr>
        <tr class='img' valign='top'>
            <td class='img' nowrap> 
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                <a href="$main_cgi?section=Help&page=policypage"> Data Usage Policy </a>
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
        <tr class='img' valign='top'>
            <td class='img' nowrap> 
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                <a href="http://genome.jgi-psf.org/"> JGI Genome Portal </a>
            </td>
            <td class='img'></td>
            <td class='img'></td>
        </tr>
	
	<tr class='img' valign='top'>
	    <td class='img'> 
	        &nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="education.html"> Education </a>
	    </td>
	    <td class='img'>
	        &nbsp;
	    </td>
	    <td class='img'></td>
        </tr>
	
        <tr class='img' valign='top'>
	    <td class='img'> 
	        &nbsp; &nbsp; &nbsp; &nbsp;
	        <a href="http://img.jgi.doe.gov/publication.html"> Publications </a>
            </td>
	    <td class='img'>
	        &nbsp;
            </td>
	    <td class='img'></td>
	</tr> 
    };

    if ($user_restricted_site) {
        print qq{
	    <tr class='img' valign='top'>
	        <td class='img'> 
	            &nbsp; &nbsp; &nbsp; &nbsp;
	            <a href="http://img.jgi.doe.gov/submit">Submit Genome</a>
	        </td>
	        <td class='img'>
	        &nbsp;
	        </td>
	        <td class='img'></td>
	    </tr>
        };
    }

    print qq{
         <tr class='img' valign='top'>
            <td class='img' NOWRAP> 
                &nbsp; &nbsp; &nbsp; &nbsp;
                <img class="menuimg" src="$base_url/images/mail.png">
                <a href="$main_cgi?page=questions"> Questions/Comments</a>
                <!--
                <img width="45" height="14" border="0" 
                style="margin-left: 5px;" src="$base_url/images/updated.bmp">
                -->
            </td>
            <td class='img' >
                Quesions, comments or feedfack
            </td>
            <td class='img'></td>
        </tr>
    };
}

sub printComponentPages {
    print qq{
	<a name='comp' href='#'><h2>sub-Pages and Components</h2> </a>
	<p>
	List of important sub-pages and components that are not covered by navigation menus.
	</p>
	<table class='img'>
	    <th class='img'> Page </th>
	    <th class='img'> Description </th>
	    <th class='img'> Document </th>
    };

    printGenomeDetailMap();
    printGeneDetailMap();
    printOtherTools();

    print "</table>\n";

}

sub printGenomeDetailMap {
    print qq{
        <tr class='highlight' valign='top'>
            <td class='img'> 
                 <b>Genome Detail Page</b> 
            </td>
            <td class='img'>
                &nbsp;
            </td>
            <td class='img'></td>
        </tr>
    
        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Organism Information 
            </td>
	    <td class='img'>
	    [ <a href="$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=643348509">see example</a> ]
            </td>
	    <td class='img'></td>
        </tr>

	<tr class='img' valign='top'>
	    <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; Genome Statistics 
	    </td>
	    <td class='img'>
	    [ <a href="$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=643348509#statistics">see example</a> ]
            </td>
	    <td class='img'></td>
	</tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Phylogenetic Distribution of Genes 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=643348509#bin">
                see example</a> ]
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img' NOWRAP>
	    &nbsp; &nbsp; &nbsp; &nbsp; Putative Horizontally Transferred Genes 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=643348509#hort">
                see example</a> ] 
             </td>
            <td class='img'></td>
        </tr>
    
        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; <b>Genome Viewers</b> 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>
    
        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Scaffolds and Contigs 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=TaxonDetail&page=scaffolds&taxon_oid=643348509">
                see example</a> ]
             </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Chromosome Maps 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=TaxonCircMaps&page=circMaps&taxon_oid=643348509">
                see example</a> ] 
             </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Web Artemis 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=Artemis&page=form&taxon_oid=643348509">
                see example</a> ] 
             </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Compare Gene Annotations 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Download Gene Information 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; <b>Export Genome Data</b> 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; FASTA 
            </td>
        <td class='img' valign='top'>
            FASTA nucleic acid file for all scaffolds <br/>
            FASTA amino acid file for all proteins <br/>
            FASTA nucleic acid file for all genes <br/>
            FASTA intergenic sequences
        </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Tab Delimited 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Genbank 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Generate GenBank File 
            </td>
            <td class='img'> &nbsp; </td>
            <td class='img'>
                <a href='$base_url/doc/GenerateGenBankFile.pdf' target='_help'>
                <img width="20" height="14" border="0"
		style="margin-left: 20px; vertical-align:middle"
		src="$base_url/images/help_book.gif"> 
                </a>
            </td>
        </tr>
    };
}

sub printGeneDetailMap {
    print qq{
        <tr class='highlight' valign='top'>
            <td class='img'> 
	    <b>Gene Detail Page</b> 
            </td>
            <td class='img'>
	    &nbsp;
            </td>
            <td class='img'></td>
        </tr>
    
        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Gene Information 
            </td>
            <td class='img'>
                [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#information">
                see example</a> ]
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Add to Gene Cart 
            </td>
            <td class='img'>
	    Click on \"Add To Gene Cart\" button under Gene Information section to add this gene to the gene cart 
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Find Candidate Enzymes 
            </td>
            <td class='img'>
	    Click on \"Find Candidate Enzymes\" button under Gene Information section to find candidate enzymes for this gene
            </td>
            <td class='img'></td>
        </tr>
    
        <tr class='img' valign='top'>
            <td class='img' NOWRAP>
                &nbsp; &nbsp; &nbsp; &nbsp; Find Candidate Product Name 
            </td>
            <td class='img'>
                Find candidate product name for this gene. 
                [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#candidate">
                see example</a> ] 
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; <b>Evidence For Function Predictions</b> 
            </td>
            <td class='img'>
	    [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#evidence">
	      see example</a> ] 
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Neighborhood 
            </td>
	    <td class='img'>
	    Sequence Viewer For Alternate ORF Search 
	    [ <a href="$main_cgi?section=Sequence&page=queryForm&genePageGeneOid=643580707">see example</a> ]<br/>
	    Chromosome Viewer (colored by COG, GC, KEGG, Pfam TIGRfam, Expression) 
	    [ <a href="$main_cgi?section=ScaffoldGraph&page=scaffoldGraph&scaffold_oid=643348665&start_coord=1&end_coord=158475&marker_gene=643580707&seq_length=158475">see example</a> ] 
	    </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Conserved Neighborhood 
            </td>
            <td class='img'>
	    Ortholog Neighborhood Viewer <br/>
	    Chromosomal Cassette Viewer (COG, IMG Ortholog Cluster, Pfam)
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; External Sequence Search 
            </td>
	    <td class='img'>
	    [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#tools1.1">see example</a> ]<br/>
	    NCBI BLAST <br/>
	    EBI InterPro Scan <br/>
	    Protein Data Bank BLAST
	    </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; IMG Sequence Search
            </td>
	    <td class='img'>
	    [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#tools1.1">see example</a> ]<br/>
	    IMG Genome BLAST <br/>
	    Phylogenetic Profile Similarity Search
	    </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Homolog Display 
            </td>
	    <td class='img'>
	    [ <a href="$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=643580707#homolog">see example</a> ] <br/>
	    Customized Homolog Display <br/>
	    Homolog Selection (Paralogs / Orthologs, Top IMG Homolog Hits) 
	    [ <a href="$main_cgi?section=GeneDetail&page=homolog&gene_oid=643580707&homologs=otfBlast">see example</a> ] 
	    </td>
            <td class='img'></td>
        </tr>
    };
}

sub printOtherTools {
    print qq{
        <tr class='highlight' valign='top'>
            <td class='img'> 
                 <b>Missing?</b> 
            </td>
            <td class='img'>
                &nbsp;
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
	    &nbsp; &nbsp; &nbsp; &nbsp; Missing Gene 
            </td>
	    <td class='img'>
	    Gene Details Page -> Neighborhood Viewer or <br/>
	    Chromosome Viewer -> Click intergenic region or <br/>
	    Find Genes -> Phylogenetic Profilers -> Single Genes see <a href="$base_url/doc/releaseNotes2-7.pdf">IMG 2.7 release notes</a> 
	    </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'>
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Missing Enzymes 
            </td>
	    <td class='img'>
	    See <a href="$base_url/doc/releaseNotes2-7.pdf">IMG 2.7 release notes</a> 
	    </td>
            <td class='img'></td>
        </tr>

        <tr class='highlight' valign='top'> 
            <td class='img'> 
                <b>Miscellaneous</b> 
            <td class='img'>
                &nbsp;
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'> 
            <td class='img'>
                &nbsp; &nbsp; &nbsp; &nbsp; Protein Expression Studies 
                <img width="45" height="14" border="0" 
		style="margin-left: 5px;" src="$base_url/images/updated.bmp"> 
            <td class='img'> 
                Example: 
                <a href="$main_cgi?section=IMGProteins&page=genomeexperiments&exp_oid=1&taxon_oid=643348509">Arthrobacter Study</a> 
            </td> 
            <td class='img'> 
                <a href='$base_url/doc/Proteomics.pdf' target='_help'> 
                <img width="20" height="14" border="0" 
		style="margin-left: 20px; vertical-align:middle" 
		src="$base_url/images/help_book.gif"> 
            </td> 
        </tr>
    };

    my $rnaseq = $env->{rnaseq};
    if ($rnaseq) {
        print qq{
        <tr class='img' valign='top'> 
            <td class='img'> 
	        &nbsp; &nbsp; &nbsp; &nbsp; RNASeq Expression Studies
                <img width="45" height="14" border="0" 
                style="margin-left: 5px;" src="$base_url/images/updated.bmp">
            <td class='img'>
	        Example: 
                <a href="$main_cgi?section=RNAStudies&page=experiments&exp_oid=3&taxon_oid=641522654">Synechococcus sp. Study</a> 
            </td> 
            <td class='img'> 
                <a href='$base_url/doc/RNAStudies.pdf' target='_help'> 
                <img width="20" height="14" border="0"
                style="margin-left: 20px; vertical-align:middle"
                src="$base_url/images/help_book.gif">
            </td>
        </tr> 
    };
    }

    print qq{
        <tr class='highlight' valign='top'> 
            <td class='img'> 
                <b>Component</b> 
            <td class='img'>
                &nbsp;
            </td>
            <td class='img'></td>
        </tr>

        <tr class='img' valign='top'> 
            <td class='img'> 
                &nbsp; &nbsp; &nbsp; &nbsp; Genome Filter 
            <td class='img'> 
                Residing in pages of Gene Search, Blast, Find Functions --> Keyword Search, Function Alignment Search, and many other area.
            </td> 
            <td class='img'>
                <a href='$base_url/doc/GenomeFilter.pdf' target='_help'>
                <img width="20" height="14" border="0"
		style="margin-left: 20px; vertical-align:middle"
		src="$base_url/images/help_book.gif"> 
                </a>
            </td>
        </tr>

    };
}

sub printWhatsNewArchive {
    print qq{
	<a name='archive' href='#'><h2> Archive of past What's New </h2></a>
        <p>
        <div class="pdflink">
        <ul>
    <li> <a href="$base_url/doc/releaseNotes4-0-0.pdf">IMG 4.0.0</a></li>        
    <li> <a href="$base_url/doc/releaseNotes3-5.pdf">IMG 3.5</a></li>
    <li> <a href="$base_url/doc/releaseNotes3-4.pdf">IMG 3.4</a></li>
    <li> <a href="$base_url/doc/releaseNotes3-3.pdf">IMG 3.3</a></li>
    <li> <a href="$base_url/doc/releaseNotes3-2.pdf">IMG 3.2</a></li>
    <li> <a href="$base_url/doc/releaseNotes3-1.pdf">IMG 3.1</a></li>
    <li> <a href="$base_url/doc/releaseNotes3-0.pdf">IMG 3.0</a></li>
    <li> <a href="$base_url/doc/releaseNotes2-9.pdf">IMG 2.9</a></li>
    <li> <a href="$base_url/doc/releaseNotes2-8.pdf">IMG 2.8</a></li>
    <li> <a href="$base_url/doc/releaseNotes2-7.pdf">IMG 2.7</a></li>
    <li> <a href="$base_url/doc/releaseNotes2-6.pdf">IMG 2.6</a></li>
        </ul>
        </div>
        </p>
    };
}

1;
