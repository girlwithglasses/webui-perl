###########################################################################
# MyBins - allow super users to save their scaffolds as a bin
#
# - ken
# $Id: MyBins.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package MyBins;

use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use OracleUtil;
use MerFsUtil;

$| = 1;

my $section              = "MyBins";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_internal         = $env->{img_internal};
my $img_er               = $env->{img_er};
my $img_ken              = $env->{img_ken};
my $tmp_dir              = $env->{tmp_dir};
my $public_nologin_site  = $env->{public_nologin_site};
my $enable_workspace     = $env->{enable_workspace};
my $workspace_dir        = $env->{workspace_dir};
my $enable_mybin         = $env->{enable_mybin};
my $formatdb_bin         = $env->{formatdb_bin};
my $mybin_blast_dir      = $env->{mybin_blast_dir};
my $filename_size        = 25;
my $filename_len         = 60;
my $preferences_url      = "$main_cgi?section=MyIMG&form=preferences";
my $max_gene_batch       = 900;
my $maxGeneListResults   = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

sub dispatch {
    return if ( !$enable_workspace );
    return if ( !$user_restricted_site );

    my $super_user_flag = getSuperUser();
    #    return if $super_user_flag ne 'Yes';

    my $dbh        = dbLogin();
    my $sid        = getContactOid();
    my $canEditBin = canEditBin( $dbh, $sid );
    #$dbh->disconnect();
    return if !$canEditBin;

    my $page = param("page");
    if ( paramMatch("saveScaffoldCart") ) {
        saveBin();
    } elsif ( paramMatch("update") ) {
        updateBin();
    } elsif ( $page eq 'delete' ) {
        deleteBin();
    } elsif ( $page eq 'view' ) {
        printView();
    } elsif ( $page eq 'genelistCog' ) {
        printGeneListCog();
    } elsif ( $page eq 'genelistPfam' ) {
        printGeneListPfam();
    } elsif ( $page eq 'genelistTigrFam' ) {
        printGeneListTigrFam();
    } elsif ( $page eq 'genelistEnzyme' ) {
        printGeneListEnzyme();
    } else {
        printMyBins();
    }
}

# TODO add taxon oid from bin_scaffolds table
sub printGeneListCog {
    my $bin_oid  = param('bin_oid');
    my $bin_name = param('bin_name');
    my $sql      = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, 
               gcg.cog, c.cog_name
        from gene g, bin_scaffolds bs, gene_cog_groups gcg, cog c
	where g.locus_type = 'CDS'
	and g.obsolete_flag = 'No'
	and g.scaffold = bs.scaffold
	and g.gene_oid = gcg.gene_oid
	and bs.bin_oid = ?
	and gcg.cog = c.cog_id      
    };

    # missing function name and id
    printGeneListSectionSorting
	( $sql, "My Bin $bin_name COG Genes", "", $bin_oid );
}

# TODO add taxon oid from bin_scaffolds table
sub printGeneListPfam {
    my $bin_oid  = param('bin_oid');
    my $bin_name = param('bin_name');
    my $sql      = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
               gpf.pfam_family, p.description
	from gene g, bin_scaffolds bs, gene_pfam_families gpf, pfam_family p
	where g.locus_type = 'CDS'
	and g.obsolete_flag = 'No'
	and g.scaffold = bs.scaffold
	and g.gene_oid = gpf.gene_oid
	and bs.bin_oid = ?
	and gpf.pfam_family = p.ext_accession
    };

    printGeneListSectionSorting
	( $sql, "My Bin $bin_name Pfam Genes", "", $bin_oid );
}

# TODO add taxon oid from bin_scaffolds table
sub printGeneListTigrFam {
    my $bin_oid  = param('bin_oid');
    my $bin_name = param('bin_name');
    my $sql      = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
               t.ext_accession, t.expanded_name
        from gene g, bin_scaffolds bs, gene_tigrfams gtf, tigrfam t
	where g.locus_type = 'CDS'
	and g.obsolete_flag = 'No'
	and g.scaffold = bs.scaffold
	and g.gene_oid = gtf.gene_oid
	and bs.bin_oid = ?
	and gtf.ext_accession = t.ext_accession   
    };

    printGeneListSectionSorting
	( $sql, "My Bin $bin_name TigrFam Genes", "", $bin_oid );
}

# TODO add taxon oid from bin_scaffolds table
sub printGeneListEnzyme {
    my $bin_oid  = param('bin_oid');
    my $bin_name = param('bin_name');
    my $sql      = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
               ge.enzymes, e.enzyme_name,  ge.ko_id, k.definition
	from gene g, bin_scaffolds bs, gene_ko_enzymes ge, enzyme e, ko_term k
	where g.locus_type = 'CDS'
	and g.obsolete_flag = 'No'
	and g.scaffold = bs.scaffold
	and g.gene_oid = ge.gene_oid
	and bs.bin_oid = ?
	and ge.enzymes = e.ec_number
	and ge.ko_id = k.ko_id     
    };

    printGeneListSectionSorting
	( $sql, "My Bin $bin_name Enzyme Genes", 1, $bin_oid );
}

#
# prints gene list with sorting
#
sub printGeneListSectionSorting {
    my ( $sql, $title, $morecolumns, @binds ) = @_;

    printMainForm();
    print "<h1>$title</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printGeneCartFooter();
    print "<p>\n";

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $count = 0;

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Funcion ID",        "char asc",   "left" );
    $it->addColSpec( "Funcion Name",      "char asc",   "left" );
    if ($morecolumns) {
        $it->addColSpec( "Funcion ID",   "char asc", "left" );
        $it->addColSpec( "Funcion Name", "char asc", "left" );
    }
    my $sd = $it->getSdDelim();
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $geneName, $funcId, $funcName, @junk ) = $cur->fetchrow();
        last if ( !$gene_oid );

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";

        my $url = "main.cgi?section=GeneDetai&page=geneDetail&gene_oid=$gene_oid";
        $url = alink( $url, $gene_oid );
        $r .= $gene_oid . $sd . $url . "\t";
        $r .= $locus_tag . $sd . "$locus_tag\t";
        $r .= $geneName . $sd . "$geneName\t";
        $r .= $funcId . $sd . "$funcId\t";
        $r .= $funcName . $sd . "$funcName\t";
        if ($morecolumns) {
            foreach my $x (@junk) {
                $r .= $x . $sd . "$x\t";
            }
        }
        $it->addRow($r);
        $count++;
    }

    #$dbh->disconnect();
    $it->printOuterTable(1);
    printStatusLine( "$count Loaded", 2 );
    print "</p>\n";
    print end_form();
}

# view bin details
sub printView {
    print "<h1>My Bin Detail</h1>\n";
    my $username    = getUserName();
    my $contact_oid = getContactOid();
    my $bin_oid     = param('bin_oid');
    if ( blankStr($bin_oid) ) {
        webError("Bin oid cannot be null");
        return;
    }

    if ( blankStr($username) ) {
        webError("username cannot be null");
        return;
    }
    printStatusLine( "Loading", 1 );

    my $dbh = dbLogin();

    # all contacts info
    my %contacts;
    my $sql = qq{
select contact_oid, nvl(name, username)
from contact        
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cid, $name ) = $cur->fetchrow();
        last if !$cid;
        $contacts{$cid} = $name;
    }

    my $sql = qq{
        select to_char(b.add_date, 'yyyy-mm-dd'), bm.method_name, 
        to_char(bm.add_date, 'yyyy-mm-dd'), b.description, b.display_name,
bs.genes_in_cog, bs.genes_in_pfam, bs.genes_in_tigrfam, bs.genes_in_enzymes,
bm.contact
        from bin b, bin_method bm, bin_stats bs
        where b.bin_method = bm.bin_method_oid
        and b.bin_oid = bs.bin_oid
        and b.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my (
         $bin_create_date,  $method_name,  $method_create_date, $description,
         $display_name,     $genes_in_cog, $genes_in_pfam,      $genes_in_tigrfam,
         $genes_in_enzymes, $contact
      )
      = $cur->fetchrow();

    my $name = $contacts{$contact};

    printMainForm();
    print hiddenVar( "bin_oid", $bin_oid );

    print qq{
        <p>
                <table class='img'>
                <tr class='img'><th class="subhead"> Name</th> <td class='img'> <input type="text" size="$filename_size" maxLength="$filename_len" name="binfilename" value='$display_name'/> </td></tr>
                <tr class='img'><th class="subhead"> Description </th> <td class='img'> <input type="text" size="40" name="bindescription"value='$description'/> </td></tr>
                <tr class='img'><th class="subhead"> My Bin Created Date </th> <td class='img'>$bin_create_date    </td></tr>
                <tr class='img'><th class="subhead"> My Bin Method     </th> <td class='img'> <input type="text" size="40" name="binmethod" value='$method_name'/> </td></tr>
                <tr class='img'><th class="subhead"> My Bin Method Creator </th> <td class='img'>$name     </td></tr>
                <tr class='img'><th class="subhead"> My Bin Method Date  </th> <td class='img'>$method_create_date </td></tr>
                </table>        
        </p>
    };

    $genes_in_cog = alink( "$section_cgi&page=genelistCog&bin_oid=$bin_oid&bin_name=$display_name",
                           $genes_in_cog );
    $genes_in_pfam =
      alink( "$section_cgi&page=genelistPfam&bin_oid=$bin_oid&bin_name=$display_name",
             $genes_in_pfam );
    $genes_in_tigrfam =
      alink( "$section_cgi&page=genelistTigrFam&bin_oid=$bin_oid&bin_name=$display_name",
             $genes_in_tigrfam );
    $genes_in_enzymes =
      alink( "$section_cgi&page=genelistEnzyme&bin_oid=$bin_oid&bin_name=$display_name",
             $genes_in_enzymes );
    print qq{
                <p>
                <table class='img'>
                <th class='img'>My Bin Statistics</th>
                <th class='img'> Gene Count </th>
                <tr class='img'><td class='img'>COG</td> <td class='img' align='right'>$genes_in_cog</td></tr>
                <tr class='img'><td class='img'>Pfam</td> <td class='img' align='right'>$genes_in_pfam</td></tr>
                <tr class='img'><td class='img'>TigrFam</td> <td class='img' align='right'>$genes_in_tigrfam</td></tr>
                <tr class='img'><td class='img'>Enzyme</td> <td class='img' align='right'>$genes_in_enzymes</td></tr>
                </table>
                <br/>
            };

    # there should be only one taxon oid - all scaffolds from the same genome for now.
    my $a_taxon_oid;

    my $sql = qq{
select b.bin_oid, 
bsc.scaffold, s.scaffold_name,
t.taxon_oid, t.taxon_display_name
from bin b,  bin_scaffolds bsc, scaffold s, taxon t
where b.bin_oid = bsc.bin_oid
and bsc.scaffold = s.scaffold_oid
and s.taxon = t.taxon_oid
and b.bin_oid = ?        
    };
    my $it = new InnerTable( 0, "mybins$$", "mybins", 0 );
    $it->addColSpec("Select / Delete");
    $it->addColSpec( "Scaffold Name", "char asc", "left" );
    $it->addColSpec( "Genome Name",   "char asc", "left" );
    my $sd  = $it->getSdDelim();
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    my $count = 0;
    for ( ; ; ) {
        my ( $bin_oid, $scaffold, $scaffold_name, $taxon_oid, $taxon_display_name ) =
          $cur->fetchrow();
        last if ( !$bin_oid );
        my $r;
        $r .= $sd . "<input type='checkbox' name='scaffold_oid' " . "value='$scaffold' />" . "\t";
        $r .= $scaffold_name . $sd . "$scaffold_name\t";
        my $url = "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_display_name );
        $r .= $taxon_display_name . $sd . "$url\t";
        $it->addRow($r);
        $count++;

        $a_taxon_oid = $taxon_oid;
    }
    #$dbh->disconnect();

    $it->printOuterTable(1);

    print hiddenVar( "page",    "addToScaffoldCart" );
    print hiddenVar( "section", "ScaffoldCart" );

    print qq{
        <input type='submit' name='_section_ScaffoldCart_addToScaffoldCart'
        value='Add to Scaffold Cart' 
        class='meddefbutton' />
    };

    print nbsp(1);

    print qq{
        <input type='submit' name='_section_MyBins_update'
        value='Update' 
        class='meddefbutton' />
    };

    print nbsp(1);

    print "<input type='button' id='scaffold1' "
      . "name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' id='scaffold0' "
      . "name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print end_form();

    printStatusLine( "$count Loaded", 2 );
}

#
# list user's bins
#
sub printMyBins {
    print "<h1>My Bins</h1>\n";
    printStatusLine( "Loading", 1 );

    #my $username = getUserName();
    my $contact_oid = getContactOid();
    my $dbh         = dbLogin();

    # TODO add taxon oid from bin_scaffolds table
    my $sql = qq{
        select b.bin_oid, b.display_name, bm.method_name, count(bs.scaffold)
        from bin b, bin_scaffolds bs, bin_method bm
        where b.bin_oid = bs.bin_oid
        and b.bin_method = bm.bin_method_oid
        and bm.contact = ?
        group by b.bin_oid, b.display_name, bm.method_name
    };

    print "<table class='img'>\n";
    print qq{
       <th class='img'> Bin Name </th>
       <th class='img'> Bin Method Name </th>  
       <th class='img'> Number of Scaffolds </th>
       <th class='img'> Blast </th>
       <th class='img'> &nbsp; </th>
    };

    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ( $oid, $name, $method_name, $count ) = $cur->fetchrow();
        last if !$oid;
        my $blast =
          alink( "main.cgi?section=FindGenesBlast&page=geneSearchBlast&taxon_oid=bin_" . "$oid",
                 'Blast' );
        my $view   = alink( "$section_cgi&page=view&bin_oid=$oid",   'View/Edit' );
        my $delete = alink( "$section_cgi&page=delete&bin_oid=$oid", 'Delete' );
        print qq{
            <tr class='img'>
                <td class='img'> $name </td>
                <td class='img'> $method_name </td>
                <td class='img' align='right'> $count </td>
                <td class='img'> $blast </td>
                <td class='img'> $view &nbsp; $delete </td>
            </tr>
        };
    }
    print "</table>\n";

    #$dbh->disconnect();
    printStatusLine( "Loaded", 2 );
}

sub printSaveBinToWorkspace {
    my $super_user_flag = getSuperUser();

    #    return if $super_user_flag ne 'Yes';
    my $contact_oid = getContactOid();
    return if ( !$contact_oid );

    my $dbh = dbLogin();
    my $canEditBin = canEditBin( $dbh, $contact_oid );
    #$dbh->disconnect();
    return if !$canEditBin;

    # workspace
    if ($enable_mybin) {
	print "<h2>Save My Bin</h2>";
        my $mybinurl =
            "<a href=\"$main_cgi?section=MyBin\">My Bin</a>"; 
        print qq{
        <p>
        You may create $mybinurl with selected scaffolds.<br/>
        All selected scaffolds must be from the same genome. 
        <br/><font color='red'>*</font> - required
        };

        print "<p>\n";
        print qq{
        <table border='0'>
        <tr><td align='right'>Bin name:</td>
            <td><input type="text" size="$filename_size" 
                 maxLength="$filename_len" name="binfilename"/>
            <font color='red'>*</font></td></tr>
        <tr><td align='right'>Description:</td>
            <td><input type="text" size="40" name="bindescription"/></td></tr>
        <tr><td align='right'>Bin Method name:</td>
            <td><input type="text" size="40" name="binmethod"/>
            <font color='red'>*</font></td></tr>
        </table>        
        };

        my $name = "_section_MyBins_saveScaffoldCart";
        print submit(
                      -name  => $name,
                      -value => "Create Bin",
                      -class => "medbutton"
        );

        print "</p>\n";
    }
}

#
# edit bin
#
sub editBin {
    my $bin_oid     = param('bin_oid');
    my $contact_oid = getContactOid();
    my $username    = getUserName();
    return if !$contact_oid;

    my $dbh = dbLogin();
    my $canEditBin = canEditBin( $dbh, $contact_oid );
    #$dbh->disconnect();
    return if !$canEditBin;

    if ( blankStr($bin_oid) ) {
        webError("Bin oid cannot be null");
        return;
    }

    if ( !isInt($bin_oid) ) {
        webError("Bin oid must be a number");
        return;
    }

    if ( blankStr($username) ) {
        webError("username cannot be null");
        return;
    }

}

#
# delete a bin
#
sub deleteBin {
    my $super_user_flag = getSuperUser();

    #    return if $super_user_flag ne 'Yes';
    my $sid = getContactOid();
    return if !$sid;
    my $contact_oid = $sid;

    my $dbh = dbLogin();
    my $canEditBin = canEditBin( $dbh, $sid );
    #$dbh->disconnect();
    return if !$canEditBin;

    my $username = getUserName();    # bin method

    my $bin_oid = param('bin_oid');
    if ( blankStr($bin_oid) ) {
        webError("Bin oid cannot be null");
        return;
    }

    if ( !isInt($bin_oid) ) {
        webError("Bin oid must be a number");
        return;
    }

    if ( blankStr($username) ) {
        webError("username cannot be null");
        return;
    }

    $bin_oid = each %{ { $bin_oid, 0 } };    #untaint the string

    printStatusLine( "Loading", 1 );
    print "Deleting bin<br/>\n";
    my $dbh = dbLogin();
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    # delete bin stats
    my $sql = qq{
        delete from bin_stats
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    # delete bin
    my $sql = qq{
        delete from bin_scaffolds
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    my $sql = qq{
        delete from bin
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    # no need to delete bin method since its just username

    # delete blast
    if ( $sid == 0 ) {
        webError("Contact oid cannot be 0!");
    }

    # check to see user's folder has been created
    if ( !-e "$workspace_dir" ) {
        mkdir "$workspace_dir" or webError("Workspace is down!");
    }

    my $blastOutputDir = "$mybin_blast_dir";
    if ( !-e $blastOutputDir ) {
        mkdir $blastOutputDir or webError("User blast Workspace is down!");
    }

    chdir $blastOutputDir or webError("Cannot change to User blast Workspace!");

    print "Delete blast files in $blastOutputDir <br/>\n";

    my @fileext = (
                    '.faa', '.faa.phr', '.faa.pin', '.faa.psd', '.faa.psi', '.faa.psq',
                    '.fna', '.fna.nhr', '.fna.nin', '.fna.nsd', '.fna.nsi', '.fna.nsq'
    );

    foreach my $f (@fileext) {
        unlink "$blastOutputDir/$bin_oid${f}" or print "Cannot delete $f <br/>\n";
    }

    print "Done deleting blast files <br/>\n";

    $dbh->commit;
    #$dbh->disconnect();
    print "Deleted bin<br/>\n";
    printStatusLine( "Deleted", 2 );
}

#
# save a new bin
#
sub saveBin {
    my $super_user_flag = getSuperUser();

    #    return if $super_user_flag ne 'Yes';

    my $dbh        = dbLogin();
    my $sid        = getContactOid();
    my $canEditBin = canEditBin( $dbh, $sid );
    #$dbh->disconnect();
    return if !$canEditBin;

    my @oids      = param("scaffold_oid");
    my $filename  = param("binfilename");
    my $descr     = param("bindescription");
    my $binmethod = param("binmethod");

    if ( blankStr($filename) ) {
        webError("Bin name cannot be null");
        return;
    }

    if ( blankStr($binmethod) ) {
        webError("Bin method cannot be null");
        return;
    }

    if ( $#oids < 0 ) {
        webError("Please select some scaffolds to save.");
        return;
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@oids);
    if ( scalar(@$metaOids_ref) > 0 ) {
        my $extracted_oids_str = MerFsUtil::getExtractedMetaOidsJoinString(@$metaOids_ref);
        webError("You have selected scaffolds ($extracted_oids_str), which are New MER-FS metagenomes from file.  They are not permitted in Bins.");
        return;
    }

    printStatusLine( "Loading", 1 );
    my $dbh = dbLogin();

    # taxon check
    # all scaffolds must be for the same genome
    my $ans = checkScaffolds( $dbh, \@oids );
    if ( $ans > 1 ) {
        #$dbh->disconnect();
        webError("Please make sure all scaffolds are from the same genome.");
        return;
    }

    # start a transaction
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    print "Creating new bin";

    # do insert here
    my $new_bin_oid = insertBin( $dbh, \@oids, $filename, $descr, $binmethod );

    # get and create stats
    my $cogCnt     = getStatsCog( $dbh,     $new_bin_oid );
    my $pfamCnt    = getStatsPfam( $dbh,    $new_bin_oid );
    my $tigrfamCnt = getStatsTigrfam( $dbh, $new_bin_oid );
    my $enzymeCnt  = getStatsEnzyme( $dbh,  $new_bin_oid );

    createStats( $dbh, $new_bin_oid, $cogCnt, $pfamCnt, $tigrfamCnt, $enzymeCnt );

    # TODO create blast db files
    createBlastFiles( $dbh, $new_bin_oid, \@oids );

    $dbh->commit;
    #$dbh->disconnect();
    printStatusLine( "Created", 2 );
}

#
# update my bin
#
sub updateBin {

    my $dbh        = dbLogin();
    my $sid        = getContactOid();
    my $canEditBin = canEditBin( $dbh, $sid );
    if ( !$canEditBin ) {
        #$dbh->disconnect();
        return;
    }

    my @oids        = param("scaffold_oid");
    my $displayname = param("binfilename");      # bin display name
    my $descr       = param("bindescription");
    my $binmethod   = param("binmethod");
    my $bin_oid     = param("bin_oid");


    if ( blankStr($bin_oid) ) {
        webError("Bin oid cannot be null");
        return;
    }

    if ( blankStr($displayname) ) {
        webError("Bin name cannot be null");
        return;
    }

    if ( blankStr($binmethod) ) {
        webError("Bin method cannot be null");
        return;
    }

    if ( $#oids < 0 ) {
        webError("Please select some scaffolds to save.");
        return;
    }

    print qq{
        <h1>Updating My Bin</h1>
        <p> 
        $displayname: $bin_oid
        </p> 
    };
    printStatusLine( "Updating", 1 );

    # start a transaction
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    # get bin method oid
    my $sql = qq{
        select bin_method
        from bin
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($bin_method_oid) = $cur->fetchrow();

    # update bin method
    my $sql = qq{
        update bin_method
        set method_name = ?
        where bin_method_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $binmethod, $bin_method_oid );

    # update bin
    my $sql = qq{
        update bin
        set display_name = ?, 
        description = ? 
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $displayname, $descr, $bin_oid );

    # now update bin_scaffolds
    # it might be easier to delete all scaffolds and insert new scaffolds?
    # or maybe delete the user selected ones ?
    my $sql = qq{
        delete from bin_scaffolds
        where bin_oid = ?
        and scaffold = ?
    };
    my $cur = $dbh->prepare($sql)
      or webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");
    foreach my $scaffold_oid (@oids) {
        webLog("deleting $bin_oid, $scaffold_oid\n");
        $cur->bind_param( 1, $bin_oid ) or webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 2, $scaffold_oid )
          or webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->execute() or webDie("execSqlBind: cannot execute: $DBI::errstr\n");
    }

    # get and create stats
    my $cogCnt     = getStatsCog( $dbh,     $bin_oid );
    my $pfamCnt    = getStatsPfam( $dbh,    $bin_oid );
    my $tigrfamCnt = getStatsTigrfam( $dbh, $bin_oid );
    my $enzymeCnt  = getStatsEnzyme( $dbh,  $bin_oid );

    my $sql = qq{
        delete from bin_stats where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    # create new stats
    createStats( $dbh, $bin_oid, $cogCnt, $pfamCnt, $tigrfamCnt, $enzymeCnt );

    # get list of updated scaffolds
    my @update_scaffold_oids;
    my $sql = qq{
        select scaffold
        from bin_scaffolds
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    for ( ; ; ) {
        my ($soid) = $cur->fetchrow();
        last if ( !$soid );
        push( @update_scaffold_oids, $soid );
    }

    # re-create blast db files
    createBlastFiles( $dbh, $bin_oid, \@update_scaffold_oids );

    $dbh->commit;
    #$dbh->disconnect();
    printStatusLine( "updated", 2 );
}

#
# check to make sure all scaffolds are from the same genome
sub checkScaffolds {
    my ( $dbh, $scaffold_aref ) = @_;

    my $str;
    if ( OracleUtil::useTempTable( $#$scaffold_aref + 1 ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_func_id", $scaffold_aref );
        $str = "select id from gtt_func_id";
    } else {
        $str = "'" . join( "','", @$scaffold_aref ) . "'";
    }

    my $sql = qq{
      select count(distinct taxon)
      from scaffold
      where scaffold_oid in ($str)  
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    return $cnt;

}

# we now user bin_stats instead of dt_bin_Stats for single cell
sub createStats {
    my ( $dbh, $bin_oid, $cogCnt, $pfamCnt, $tigrfamCnt, $enzymeCnt ) = @_;

    print "Create bin stats $bin_oid, $cogCnt, $pfamCnt, $tigrfamCnt, $enzymeCnt <br/>\n";

    my $sql = qq{
        insert into bin_stats
        (bin_oid, genes_in_cog, genes_in_pfam, genes_in_tigrfam, genes_in_enzymes,
        mod_date)
        values
        (?,?,?,?,?,
        sysdate)
    };
    webLog("$sql\n");
    my $cur = $dbh->prepare($sql) or webDie("cannot preparse statement: $DBI::errstr\n");
    my $i = 1;
    $cur->bind_param( $i++, $bin_oid )    or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $cogCnt )     or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $pfamCnt )    or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $tigrfamCnt ) or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $enzymeCnt )  or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->execute() or webDie("cannot execute: $DBI::errstr\n");
}

# TODO add taxon oid from bin_scaffolds table
sub getStatsCog {
    my ( $dbh, $new_bin_oid ) = @_;

    print "Get bin cog stats <br/>\n";

    my $sql = qq{
select count( distinct g.gene_oid )
from gene g, bin_scaffolds bs, gene_cog_groups gcg
where g.locus_type = 'CDS'
and g.obsolete_flag = 'No'
and g.scaffold = bs.scaffold
and g.gene_oid = gcg.gene_oid
and bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $new_bin_oid );
    my ($cnt) = $cur->fetchrow();
    return $cnt;
}

# TODO add taxon oid from bin_scaffolds table
sub getStatsPfam {
    my ( $dbh, $new_bin_oid ) = @_;

    print "Get bin pfam stats <br/>\n";

    my $sql = qq{
select count( distinct g.gene_oid )
from gene g, bin_scaffolds bs, gene_pfam_families gpf
where g.locus_type = 'CDS'
and g.obsolete_flag = 'No'
and g.scaffold = bs.scaffold
and g.gene_oid = gpf.gene_oid
and bs.bin_oid = ?  
    };
    my $cur = execSql( $dbh, $sql, $verbose, $new_bin_oid );
    my ($cnt) = $cur->fetchrow();
    return $cnt;
}

# TODO add taxon oid from bin_scaffolds table
sub getStatsTigrfam {
    my ( $dbh, $new_bin_oid ) = @_;

    print "Get bin tigrfam stats <br/>\n";

    my $sql = qq{
select count( distinct g.gene_oid )
from gene g, bin_scaffolds bs, gene_tigrfams gtf
where g.locus_type = 'CDS'
and g.obsolete_flag = 'No'
and g.scaffold = bs.scaffold
and g.gene_oid = gtf.gene_oid
and bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $new_bin_oid );
    my ($cnt) = $cur->fetchrow();
    return $cnt;
}

# TODO add taxon oid from bin_scaffolds table
sub getStatsEnzyme {
    my ( $dbh, $new_bin_oid ) = @_;

    print "Get bin enzyme stats <br/>\n";

    my $sql = qq{
select count( distinct g.gene_oid )
from gene g, bin_scaffolds bs, gene_ko_enzymes ge
where g.locus_type = 'CDS'
and g.obsolete_flag = 'No'
and g.scaffold = bs.scaffold
and g.gene_oid = ge.gene_oid
and bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $new_bin_oid );
    my ($cnt) = $cur->fetchrow();
    return $cnt;
}

#
# insert new bin into db
#
sub insertBin {
    my ( $dbh, $scaffold_oids_aref, $filename, $descr, $binmethod ) = @_;
    my $new_bin_oid = getNewBinOid($dbh);

    #my $username = getUserName();    # bin method

    # create a new bin method
    my $new_bin_method_oid = getBinMethod( $dbh, $binmethod );
    if ( $new_bin_method_oid eq "" ) {
        $new_bin_method_oid = getNewMethodBinOid($dbh);
        my $contact_oid = getContactOid();
        my $sql         = qq{
        insert into bin_method
        (bin_method_oid, method_name, description, add_date, contact)
        values
        (?,?,?, sysdate, ?)
        };
        webLog("$sql\n");
        my $cur = $dbh->prepare($sql) or webDie("cannot preparse statement: $DBI::errstr\n");
        my $i = 1;
        $cur->bind_param( $i++, $new_bin_method_oid )
          or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->bind_param( $i++, $binmethod )   or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->bind_param( $i++, 'My Bins' )    or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->bind_param( $i++, $contact_oid ) or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->execute() or webDie("cannot execute: $DBI::errstr\n");
    }

    # create a new bin
    my $sql = qq{
        insert into bin
        (bin_oid, display_name, description, bin_method, add_date, is_default)
        values
        (?,?,?,?, sysdate, 'Yes')
    };
    webLog("$sql\n");
    my $cur = $dbh->prepare($sql) or webDie("cannot preparse statement: $DBI::errstr\n");
    my $i = 1;
    $cur->bind_param( $i++, $new_bin_oid ) or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $filename )    or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $descr )       or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->bind_param( $i++, $new_bin_method_oid )
      or webDie("$i-1 cannot bind param: $DBI::errstr\n");
    $cur->execute() or webDie("cannot execute: $DBI::errstr\n");

    # create bin with scaffolds
    my $taxon_oid = scaffoldOid2TaxonOid( $dbh, $scaffold_oids_aref->[0] );
    my $sql       = qq{
        insert into bin_scaffolds
        (bin_oid, scaffold, taxon)
        values
        (?,?, $taxon_oid)
    };
    webLog("$sql\n");
    my $cur = $dbh->prepare($sql) or webDie("cannot preparse statement: $DBI::errstr\n");
    my $count = 0;
    foreach my $soid (@$scaffold_oids_aref) {
        $cur->bind_param( 1, $new_bin_oid ) or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 2, $soid )        or webDie("$i-1 cannot bind param: $DBI::errstr\n");
        $cur->execute() or webDie("execSqlBind: cannot execute: $DBI::errstr\n");
        $count++;
    }

    print "$count++ scaffolds added to bin $filename <br/>\n";
    return $new_bin_oid;
}

# based on the username get bin method oid if it exists
sub getBinMethod {
    my ( $dbh, $binmethod ) = @_;

    #my $username = getUserName();    # bin method
    my $contact_oid = getContactOid();
    my $sql         = qq{
        select bin_method_oid
        from bin_method
        where contact = ?
        and method_name = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $binmethod );
    my ($oid) = $cur->fetchrow();
    return $oid;
}

#
# create bin blast files
#
sub createBlastFiles {
    my ( $dbh, $bin_oid, $scaffold_oids_aref ) = @_;
    
    # untaint
    if ( $bin_oid =~ /^(.*)$/ ) { $bin_oid = $1; }
    
    my $sid = getContactOid();
    if ( $sid == 0 ) {
        webError("Contact oid cannot be 0!");
    }

    # check to see user's folder has been created
    if ( !-e "$workspace_dir" ) {
        mkdir "$workspace_dir" or webError("Workspace is down!");
    }

    #    if ( !-e "$workspace_dir/$sid" ) {
    #        mkdir "$workspace_dir/$sid" or webError("User Workspace is down!");
    #    }

    my $blastOutputDir = "$mybin_blast_dir";
    if ( !-e $blastOutputDir ) {
        mkdir $blastOutputDir or webError("User blast Workspace is down!");
    }

    # get scaffold seq
    my $newSeq;
    foreach my $scaffold_oid (@$scaffold_oids_aref) {
        print "scaffold $scaffold_oid \n";
        my $seq = getScaffoldSeq( $dbh, $scaffold_oid );
        print " with seq length found: " . length($seq) . " <br/>\n";
        $newSeq .= "$seq\n";
    }

    $newSeq = wrapSeq($newSeq);

    chdir $blastOutputDir or webError("Cannot change to User blast Workspace!");
    my $file = "$blastOutputDir/$bin_oid" . ".fna";
    my $wfh = newWriteFileHandle( $file, "createBlastFiles" );
    print $wfh "$newSeq\n";
    close $wfh;

    # nucleotide
    print "Create blast nucleotide <br/>\n";
    my $cmd = "$formatdb_bin -i $file -p F -o T";
    runCmd($cmd);

    my $new_aa_seq;
    foreach my $scaffold_oid (@$scaffold_oids_aref) {
        print "scaffold $scaffold_oid \n";
        my $seq = getScaffoldAaResidue( $dbh, $scaffold_oid );
        print " with seq length found: " . length($seq) . " <br/>\n";
        $new_aa_seq .= "$seq\n";
    }
    my $file = "$blastOutputDir/$bin_oid" . ".faa";
    my $wfh = newWriteFileHandle( $file, "createBlastFiles" );
    print $wfh "$new_aa_seq\n";
    close $wfh;

    # protein
    print "Create blast protein <br/>\n";
    my $cmd = "$formatdb_bin -i $bin_oid" . ".faa -p T -o T";
    runCmd($cmd);
}

sub getScaffoldAaResidue {
    my ( $dbh, $scafold_oid ) = @_;

    my $sql = qq{
select g.gene_oid, g.aa_residue
from gene g
where g.scaffold = ?
and g.aa_residue is not null
and g.obsolete_flag = 'No'
order by g.start_coord        
    };

    my $aa;
    my $cur = execSql( $dbh, $sql, $verbose, $scafold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $seq ) = $cur->fetchrow();
        last if ( !$gene_oid );
        if ( !blankStr($seq) ) {
            $aa .= ">$gene_oid\n";
            $seq = wrapSeq($seq);
            $aa .= "$seq\n";
        }
    }

    return $aa;
}

sub getNewBinOid {
    my ($dbh) = @_;
    my $sql = qq{
        select max(bin_oid)
        from bin
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($oid_max) = $cur->fetchrow();
    $oid_max++;
    return $oid_max;
}

sub getNewMethodBinOid {
    my ($dbh) = @_;
    my $sql = qq{
        select max(bin_method_oid)
        from bin_method
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($oid_max) = $cur->fetchrow();
    $oid_max++;
    return $oid_max;
}

1;
