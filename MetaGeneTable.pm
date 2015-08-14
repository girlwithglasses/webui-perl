###############################################################################
# MetaGeneTable.pm - multi column display for MER-FS selected genes
###############################################################################
package MetaGeneTable;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  printMetaGeneTableSelect
  printMetaGeneSearchSelect
);

my $section = "MetaGeneTable";

use strict;
use CGI qw( :standard );
use POSIX qw(ceil floor);
use LWP;
use HTTP::Request::Common qw( POST );
use Data::Dumper;
use Time::localtime;
use InnerTable;
use WebConfig;
use WebUtil;
use MetaUtil;
use HashUtil;
use QueryUtil;
use WorkspaceUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $inner_cgi            = $env->{inner_cgi};
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $preferences_url      = "$main_cgi?section=MyIMG&form=preferences";
my $cog_base_url         = $env->{cog_base_url};
my $kog_base_url         = $env->{kog_base_url};
my $pfam_base_url        = $env->{pfam_base_url};

my $include_bbh_lite = $env->{include_bbh_lite};
my $bbh_files_dir    = $env->{bbh_files_dir};
my $bbh_zfiles_dir   = $env->{bbh_zfiles_dir};

my $blast_server_url = $env->{blast_server_url};
my $img_lid_blastdb  = $env->{img_lid_blastdb};
my $img_iso_blastdb  = $env->{img_iso_blastdb};

my $YUI        = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

my $mer_data_dir = $env->{mer_data_dir};

my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

#######################################################################################
# dispatch
#######################################################################################
sub dispatch {
    my $sid  = getContactOid();
    my $page = param("page");

    #print "page: $page";

    if ( paramMatch("expandDisplay") ne "" || $page eq "expandDisplay" ) {
        my $expand = param("expand_display");

        #print "expand: $expand";
        if ( $expand eq "cog" ) {
            showCogAlignment();
        }
        elsif ( $expand eq "pfam" ) {
            showPfamAlignment();
        }
        elsif ( $expand eq "include" ) {
            showExpandGeneTable();
        }
    }
    elsif ( paramMatch("showExpandGeneTable") ne ""
        || $page eq "showExpandGeneTable" )
    {
        showExpandGeneTable();
    }
    elsif ( paramMatch("cogAlignment") ne "" || $page eq "cogAlignment" ) {
        showCogAlignment();
    }
    elsif ( paramMatch("pfamAlignment") ne "" || $page eq "pfamAlignment" ) {
        showPfamAlignment();
    }
    elsif ( paramMatch("showGeneSearchResult") ne ""
        || $page eq "showGeneSearchResult" )
    {
        showGeneSearchResult();
    }
    elsif ( paramMatch("showSimilarOccurrenceGenes") ne ""
        || $page eq "showSimilarOccurrenceGenes" )
    {
        showSimilarOccurrenceGenes();
    }
}

#######################################################################################
# printMetaGeneTableSelect
#######################################################################################
sub printMetaGeneTableSelect {
    print "<h2>Expand Gene Table Display</h2>\n";

    my $include_workspace_id = param('include_workspace_id');
    if ($include_workspace_id) {
        print hiddenVar( 'include_workspace_id', 1 );
    }

    printHint("Limit gene selection and display options to avoid timeout.");

    print "<p>\n";
    print "<b>Display Options for <i><u>Selected</u></i> Genes</b>:<br/>\n";

    print "<input type='radio' name='expand_display' value='cog' />";
    print "COG Alignment<br/>\n";
    print "<input type='radio' name='expand_display' value='pfam' />";
    print "Pfam Alignment<br/>\n";

    print "<input type='radio' name='expand_display' value='include' checked/>";
    print "Display by including the following information<br/>\n";

    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_info' checked>\n";
    print "Gene Detailed Information<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_scaf' checked>\n";
    print "Scaffold Information (for assembled only)<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_cog' checked>\n";
    print "COG Functions<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_pfam' checked>\n";
    print "Pfam Functions<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_tigr' checked>\n";
    print "TIGRfam Functions<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_ec' checked>\n";
    print "Enzyme Functions<br/>\n";
    print nbsp(4)
      . "<input type='checkbox' name='expand_gene_table' value='inc_gene_ko' checked>\n";
    print "KO Functions<br/>\n";

    print "<p>\n";

    print nbsp(1);
    my $name = "_section_${section}_expandDisplay";
    print submit(
        -name  => $name,
        -value => "Go",
        -class => "smdefbutton"
    );

    print "</p>\n";

}

##################################################################################
# showExpandGeneTable
##################################################################################
sub showExpandGeneTable {
    printMainForm();

    print "<h1>Expanded Gene List</h1>\n";

    my $include_workspace_id = param('include_workspace_id');

    my @gene_oids = param('gene_oid');
    my %unique_genes;
    for my $g_id (@gene_oids) {

        #print "gene_oid: ".$g_id."<br/>\n";
        $unique_genes{$g_id} = 1;
    }

    if ($include_workspace_id) {
        my @workspace_ids = param('workspace_id');
        for my $id2 (@workspace_ids) {
            $unique_genes{$id2} = 1;
        }
    }

    @gene_oids = ( keys %unique_genes );
    if ( scalar(@gene_oids) == 0 ) {
        webError("No genes have been selected.");
        return;
    }

    my @options = param('expand_gene_table');
    if ( scalar(@options) == 0 ) {
        webError("No display options have been selected.");
        return;
    }

    timeout( 60 * $merfs_timeout_mins );
    printStatusLine( "Loading ...", 1 );

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my $dbh = dbLogin();

    my $it = new InnerTable( 1, "geneFuncStatsList$$", "geneFuncStatsList", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "char asc",   "left" );
    $it->addColSpec( "Gene Name",  "char asc",   "left" );
    $it->addColSpec( "Taxon ID",  "number asc", "left" );
    $it->addColSpec( "Assembled?", "char asc",   "left" );

    my $get_gene_info = 0;
    my $get_scaf_info = 0;
    my $get_gene_cog  = 0;
    my $get_gene_pfam = 0;
    my $get_gene_tigr = 0;
    my $get_gene_ec   = 0;
    my $get_gene_ko   = 0;
    my %cog_name_h;
    my %pfam_name_h;
    my %tigr_name_h;
    my %ec_name_h;
    my %ko_name_h;
    my %fs_id_h;

    for my $op2 (@options) {
        if ( $op2 eq 'inc_gene_info' ) {
            $get_gene_info = 1;
            $it->addColSpec( "Locus Type",      "char asc",   "right" );
            $it->addColSpec( "Start<br/>Coord", "number asc", "right" );
            $it->addColSpec( "End<br/>Coord",   "number asc", "right" );
            $it->addColSpec( "Gene<br/>Length", "number asc", "right" );
            $it->addColSpec( "Strand",          "char asc",   "left" );
        }
        elsif ( $op2 eq 'inc_gene_scaf' ) {
            $get_scaf_info = 1;
            $get_gene_info = 1;
            $it->addColSpec( "Scaffold",            "char asc",   "left" );
            $it->addColSpec( "Scaffold<br/>Length", "number asc", "right" );
            $it->addColSpec( "Scaffold<br/>GC",     "number asc", "right" );
            $it->addColSpec( "Scaffold<br/>Depth",  "number asc", "right" );
            $it->addColSpec( "# of Genes<br/>on Scaffold",
                "number asc", "right" );
        }
        elsif ( $op2 eq 'inc_gene_cog' ) {
            $get_gene_cog = 1;
            $it->addColSpec( "COG ID",       "char asc", "left" );
            $it->addColSpec( "COG Function", "char asc", "left" );

            print "Retrieving COG definition ...<br/>\n";
            QueryUtil::fetchAllCogIdNameHash( $dbh, \%cog_name_h );
        }
        elsif ( $op2 eq 'inc_gene_pfam' ) {
            $get_gene_pfam = 1;
            $it->addColSpec( "Pfam ID",       "char asc", "left" );
            $it->addColSpec( "Pfam Function", "char asc", "left" );

            print "Retrieving Pfam definition ...<br/>\n";
            QueryUtil::fetchAllPfamIdNameHash( $dbh, \%pfam_name_h );
        }
        elsif ( $op2 eq 'inc_gene_tigr' ) {
            $get_gene_tigr = 1;
            $it->addColSpec( "TIGRfam ID",       "char asc", "left" );
            $it->addColSpec( "TIGRfam Function", "char asc", "left" );

            print "Retrieving TIGRfam definition ...<br/>\n";
            QueryUtil::fetchAllTigrfamIdNameHash( $dbh, \%tigr_name_h );
        }
        elsif ( $op2 eq 'inc_gene_ec' ) {
            $get_gene_ec = 1;
            $it->addColSpec( "EC Number",       "char asc", "left" );
            $it->addColSpec( "Enzyme Function", "char asc", "left" );

            print "Retrieving Enzyme definition ...<br/>\n";
            QueryUtil::fetchAllEnzymeNumberNameHash( $dbh, \%ec_name_h );
        }
        elsif ( $op2 eq 'inc_gene_ko' ) {
            $get_gene_ko = 1;
            $it->addColSpec( "KO ID",       "char asc", "left" );
            $it->addColSpec( "KO Function", "char asc", "left" );

            print "Retrieving KO definition ...<br/>\n";
            QueryUtil::fetchAllKoIdNameDefHash( $dbh, \%ko_name_h );
        }
    }

    my $select_id_name = "gene_oid";

    my %genes_h;

    # get all MER-FS gene product names
    my $k = 0;
    for my $workspace_id (@gene_oids) {
        $genes_h{$workspace_id} = 1;
        my @vals = split( / /, $workspace_id );
        if ( scalar(@vals) >= 3 ) {

            # MER-FS
            $fs_id_h{$workspace_id} = 1;
            $k++;
            if ( $k > $maxGeneListResults ) {
                last;
            }
        }
    }

    my %gene_name_h;
    my %gene_info_h;
    my %scaf_id_h;
    if ($get_gene_info) {

        # only need to get FS gene product names
        if ( scalar( keys %fs_id_h ) > 0 ) {
            print "<p>Retrieving Gene Product Names ...<br/>\n";
            MetaUtil::getAllGeneNames( \%fs_id_h, \%gene_name_h, 1 );
        }
        MetaUtil::getAllGeneInfo( \%genes_h, \%gene_info_h, \%scaf_id_h, 1 );
    }
    else {

        # get all gene product names
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene Product Names ...<br/>\n";
            MetaUtil::getAllGeneNames( \%genes_h, \%gene_name_h, 1 );
        }
    }

    my %scaffold_h;
    if ($get_scaf_info) {
        if ( scalar( keys %scaf_id_h ) > 0 ) {
            print "<p>Retrieving Scaffold Information ...<br/>\n";
            MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h, 0, 1 );
        }
    }

    # gene-cog
    my %gene_cog_h;
    if ($get_gene_cog) {
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene COG annotation ...<br/>\n";
            MetaUtil::getAllMetaGeneFuncs( 'cog', '', \%genes_h, \%gene_cog_h, 1 );
        }
    }

    # gene-pfam
    my %gene_pfam_h;
    if ($get_gene_pfam) {
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene Pfam annotation ...<br/>\n";
            MetaUtil::getAllMetaGeneFuncs( 'pfam', '', \%genes_h, \%gene_pfam_h,
                1 );
        }
    }

    # gene-tigr
    my %gene_tigr_h;
    if ($get_gene_tigr) {
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene TIGRfam annotation ...<br/>\n";
            MetaUtil::getAllMetaGeneFuncs( 'tigr', '', \%genes_h, \%gene_tigr_h,
                1 );
        }
    }

    # gene-ec
    my %gene_ec_h;
    if ($get_gene_ec) {
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene Enzyme annotation ...<br/>\n";
            MetaUtil::getAllMetaGeneFuncs( 'ec', '', \%genes_h, \%gene_ec_h, 1 );
        }
    }

    # gene-ko
    my %gene_ko_h;
    if ($get_gene_ko) {
        if ( scalar( keys %genes_h ) > 0 ) {
            print "<p>Retrieving Gene KO annotation ...<br/>\n";
            MetaUtil::getAllMetaGeneFuncs( 'ko', '', \%genes_h, \%gene_ko_h, 1 );
        }
    }

    print "<p>Retrieving Gene Information ...<br/>\n";

    # save taxon display name to rpevent repeat retrieving
    my %taxon_name_h;

    my $trunc      = 0;
    my $gene_count = 0;
    for my $workspace_id (@gene_oids) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );

        if ( !$gene_oid && isInt($taxon_oid) ) {
            $gene_oid  = $taxon_oid;
            $data_type = 'database';
            $taxon_oid = 0;
        }

        my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name,
            $start_coord, $end_coord, $strand, $scaffold_oid );
        my ( $tid2, $dtype2 );
        if ($get_gene_info) {
            (
                $locus_type,   $locus_tag, $gene_display_name,
                $start_coord,  $end_coord, $strand,
                $scaffold_oid, $tid2,      $dtype2
              )
              = split( /\t/, $gene_info_h{$workspace_id} );
            if ( !$taxon_oid && $tid2 ) {
                $taxon_oid = $tid2;
            }
        }

        my $url;
        my $taxon_url;
        if ( $data_type eq 'database' ) {
            if ( !$taxon_oid ) {
                ($taxon_oid) =
                  QueryUtil::fetchSingleGeneTaxon( $dbh, $gene_oid );
            }

            $url =
                "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        else {
            $url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$taxon_oid&";
        }

        # gene_oid
        my $r = $sd
          . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";

        # gene name
        if ( $gene_name_h{$workspace_id} ) {
            $gene_display_name = $gene_name_h{$workspace_id};
        }
        if ( !$gene_display_name ) {
            $gene_display_name = 'hypothetical protein';
        }
        $r .= $gene_display_name . $sd . $gene_display_name . "\t";

        # taxon
        if ( !$taxon_name_h{$taxon_oid} ) {
            my $sql =
              "select taxon_display_name from taxon where taxon_oid = ?";
            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            my ($taxon_name) = $cur->fetchrow();
            $cur->finish();
            $taxon_name_h{$taxon_oid} = $taxon_name;
        }

        $r .=
            $taxon_oid . $sd
          . "<a href=\"$taxon_url\" title=\""
          . $taxon_name_h{$taxon_oid} . "\">"
          . $taxon_oid
          . "</a> \t";

        # data type
        if ( $data_type eq 'database' ) {
            $r .= 'assembled' . $sd . 'assembled' . "\t";
        }
        else {
            $r .= $data_type . $sd . $data_type . "\t";
        }

        for my $op2 (@options) {
            if ( $op2 eq 'inc_gene_info' ) {
                if ( $data_type ne 'database' ) {
                    $gene_display_name = 'hypothetical protein';
                    if ( $gene_name_h{$workspace_id} ) {
                        $gene_display_name = $gene_name_h{$workspace_id};
                    }
                }

                $r .= $locus_type . $sd . $locus_type . "\t";
                $r .= $start_coord . $sd . $start_coord . "\t";
                $r .= $end_coord . $sd . $end_coord . "\t";
                my $gene_length = $end_coord - $start_coord + 1;
                $r .= $gene_length . $sd . $gene_length . "\t";
                $r .= $strand . $sd . $strand . "\t";
            }
            elsif ( $op2 eq 'inc_gene_scaf' ) {
                my $scaf_len;
                my $scaf_gc;
                my $scaf_gene_cnt;
                my $scaf_depth = 1;
                if (   $data_type eq 'database'
                    && $scaffold_oid
                    && isInt($scaffold_oid) )
                {
                    my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
                    my $hashVal = $scaffold_h{$ws_scaf_id};

                    $hashVal = $scaffold_h{$scaffold_oid}
                            if ( $hashVal eq "" );
                    ( $scaf_len, $scaf_gc, $scaf_gene_cnt, $scaf_depth ) =
                      split( /\t/, $hashVal );
                    if ( !$scaf_depth ) {
                        $scaf_depth = 1;
                    }
                    $scaf_gc = sprintf( "%.2f", $scaf_gc );

                    my $scaf_url =
                        "$main_cgi?section=ScaffoldGraph"
                      . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
                    my $scaf_link = alink( $scaf_url, $scaffold_oid );
                    $r .= $scaffold_oid . $sd . $scaf_link . "\t";

                    my $scaf_len_url =
                        "$main_cgi?section=ScaffoldGraph"
                      . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid"
                      . "&start_coord=1&end_coord=$scaf_len"
                      . "&marker_gene=$gene_oid&seq_length=$scaf_len";
                    my $scaf_len_link = alink( $scaf_len_url, $scaf_len );
                    $r .= $scaf_len . $sd . $scaf_len_link . "\t";
                    $r .= $scaf_gc . $sd . $scaf_gc . "\t";
                    $r .= $scaf_depth . $sd . $scaf_depth . "\t";

                    my $scaf_gene_url =
                        "$main_cgi?section=ScaffoldGraph"
                      . "&page=scaffoldGenes&scaffold_oid=$scaffold_oid";
                    my $scaf_gene_link =
                      alink( $scaf_gene_url, $scaf_gene_cnt );
                    $r .= $scaf_gene_cnt . $sd . $scaf_gene_link . "\t";
                }
                elsif ( $data_type eq 'assembled' && $scaffold_oid ) {
                    my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
                    ( $scaf_len, $scaf_gc, $scaf_gene_cnt, $scaf_depth ) =
                      split( /\t/, $scaffold_h{$ws_scaf_id} );
                    if ( !$scaf_depth ) {
                        $scaf_depth = 1;
                    }
                    $scaf_gc = sprintf( "%.2f", $scaf_gc );

                    my $scaf_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldDetail&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid&data_type=$data_type";
                    my $scaf_link = alink( $scaf_url, $scaffold_oid );
                    $r .= $scaffold_oid . $sd . $scaf_link . "\t";

                    my $scaf_len_url =
                        "$main_cgi?section=MetaScaffoldGraph"
                      . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid"
                      . "&start_coord=1&end_coord=$scaf_len"
                      . "&marker_gene=$gene_oid&seq_length=$scaf_len";
                    my $scaf_len_link = alink( $scaf_len_url, $scaf_len );
                    $r .= $scaf_len . $sd . $scaf_len_link . "\t";
                    $r .= $scaf_gc . $sd . $scaf_gc . "\t";
                    $r .= $scaf_depth . $sd . $scaf_depth . "\t";

                    my $scaf_gene_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldGenes&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid";
                    my $scaf_gene_link =
                      alink( $scaf_gene_url, $scaf_gene_cnt );
                    $r .= $scaf_gene_cnt . $sd . $scaf_gene_link . "\t";
                }
                else {
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                }
            }
            elsif ( $op2 eq 'inc_gene_cog' ) {
                my @recs;
                my $cogs = $gene_cog_h{$workspace_id};
                if ($cogs) {
                    @recs = split( /\t/, $cogs );
                }

                my $cog_ids  = "";
                my $cog_name = "";
                for my $cog_id (@recs) {
                    if ($cog_ids) {
                        $cog_ids .= "; " . $cog_id;
                    }
                    else {
                        $cog_ids = $cog_id;
                    }

                    if ( $cog_name_h{$cog_id} ) {
                        if ($cog_name) {
                            $cog_name .= "; " . $cog_name_h{$cog_id};
                        }
                        else {
                            $cog_name = $cog_name_h{$cog_id};
                        }
                    }
                }

                $r .= $cog_ids . $sd . $cog_ids . "\t";
                $r .= $cog_name . $sd . $cog_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_pfam' ) {
                my @recs;
                my $pfams = $gene_pfam_h{$workspace_id};
                if ($pfams) {
                    @recs = split( /\t/, $pfams );
                }

                my $pfam_ids  = "";
                my $pfam_name = "";
                for my $pfam_id (@recs) {
                    if ($pfam_ids) {
                        $pfam_ids .= "; " . $pfam_id;
                    }
                    else {
                        $pfam_ids = $pfam_id;
                    }

                    if ( $pfam_name_h{$pfam_id} ) {
                        if ($pfam_name) {
                            $pfam_name .= "; " . $pfam_name_h{$pfam_id};
                        }
                        else {
                            $pfam_name = $pfam_name_h{$pfam_id};
                        }
                    }
                }

                $r .= $pfam_ids . $sd . $pfam_ids . "\t";
                $r .= $pfam_name . $sd . $pfam_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_tigr' ) {
                my @recs;
                my $tigrs = $gene_tigr_h{$workspace_id};
                if ($tigrs) {
                    @recs = split( /\t/, $tigrs );
                }

                my $tigr_ids  = "";
                my $tigr_name = "";
                for my $tigr_id (@recs) {
                    if ($tigr_ids) {
                        $tigr_ids .= "; " . $tigr_id;
                    }
                    else {
                        $tigr_ids = $tigr_id;
                    }

                    if ( $tigr_name_h{$tigr_id} ) {
                        if ($tigr_name) {
                            $tigr_name .= "; " . $tigr_name_h{$tigr_id};
                        }
                        else {
                            $tigr_name = $tigr_name_h{$tigr_id};
                        }
                    }
                }

                $r .= $tigr_ids . $sd . $tigr_ids . "\t";
                $r .= $tigr_name . $sd . $tigr_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_ec' ) {
                my @recs;
                my $ecs = $gene_ec_h{$workspace_id};
                if ($ecs) {
                    @recs = split( /\t/, $ecs );
                }

                my $ec_ids  = "";
                my $ec_name = "";
                for my $ec_id (@recs) {
                    if ($ec_ids) {
                        $ec_ids .= "; " . $ec_id;
                    }
                    else {
                        $ec_ids = $ec_id;
                    }

                    if ( $ec_name_h{$ec_id} ) {
                        if ($ec_name) {
                            $ec_name .= "; " . $ec_name_h{$ec_id};
                        }
                        else {
                            $ec_name = $ec_name_h{$ec_id};
                        }
                    }
                }

                $r .= $ec_ids . $sd . $ec_ids . "\t";
                $r .= $ec_name . $sd . $ec_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_ko' ) {
                my @recs;
                my $kos = $gene_ko_h{$workspace_id};
                if ($kos) {
                    @recs = split( /\t/, $kos );
                }

                my $ko_ids  = "";
                my $ko_name = "";
                for my $ko_id (@recs) {
                    if ($ko_ids) {
                        $ko_ids .= "; " . $ko_id;
                    }
                    else {
                        $ko_ids = $ko_id;
                    }

                    if ( $ko_name_h{$ko_id} ) {
                        if ($ko_name) {
                            $ko_name .= "; " . $ko_name_h{$ko_id};
                        }
                        else {
                            $ko_name = $ko_name_h{$ko_id};
                        }
                    }
                }

                $r .= $ko_ids . $sd . $ko_ids . "\t";
                $r .= $ko_name . $sd . $ko_name . "\t";
            }
        }

        $it->addRow($r);

        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        print ".";
        if ( ( $gene_count % 180 ) == 0 ) {
            print "<br/>\n";
        }
    }

    printEndWorkingDiv();
    #$dbh->disconnect();

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }
    
    WebUtil::printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    ## save to workspace
    if ( $gene_count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    print end_form();
}

#######################################################################################
# showCogAlignment
#######################################################################################
sub showCogAlignment {
    printMainForm();

    print "<h1>COG Alignment</h1>\n";

    my $image_len            = 150;
    my $include_workspace_id = param('include_workspace_id');

    my @gene_oids = param('gene_oid');
    if ($include_workspace_id) {
        my @workspace_ids = param('workspace_id');
        for my $id2 (@workspace_ids) {
            push @gene_oids, ($id2);
        }
    }

    if ( scalar(@gene_oids) == 0 ) {
        webError("No genes have been selected.");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    my $dbh = dbLogin();
    my %cog_name_h;
    my %cog_seq_length_h;
    my %cog_func_h;
    print "Retrieving COG definition ...<br/>\n";
    my $sql = qq{
            select c.cog_id, c.cog_name, c.seq_length, 
                   f.function_code, f.definition
            from cog c, cog_functions cf, cog_function f
            where c.cog_id = cf.cog_id
            and cf.functions = f.function_code
            };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_id, $cog_name, $seq_length, $func_code, $func_def ) =
          $cur->fetchrow();
        last if !$cog_id;
        $cog_name_h{$cog_id}       = $cog_name;
        $cog_seq_length_h{$cog_id} = $seq_length;
        $cog_func_h{$cog_id}       = $func_code . "\t" . $func_def;
    }

    my $it = new InnerTable( 1, "cogAlignment$$", "cogAlignment", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Gene ID",                           "char asc", "left" );
    $it->addColSpec( "Assembled?",                        "char asc", "left" );
    $it->addColSpec( "COG ID",                            "char asc", "left" );
    $it->addColSpec( "COG Name",                          "char asc", "left" );
    $it->addColSpec( "Consensus<br/>Sequence<br/>Length", "char asc", "left" );
    $it->addColSpec( "Percent<br/>Identity", "number asc", "right" );
    $it->addColSpec( "Query<br/>Start",      "number asc", "right" );
    $it->addColSpec( "Query<br/>End",        "number asc", "right" );
    $it->addColSpec( "Alignment On<br/>Query Gene", "desc" );
    $it->addColSpec( "Bit<br/>Score",               "number desc", "right" );
    $it->addColSpec( "Genome Name",                 "asc" );

    print "Retrieving Gene Information ...<br/>\n";

    # save taxon display name to prevent repeat retrieving
    my %taxon_name_h;

    my $trunc      = 0;
    my $gene_count = 0;
    for my $workspace_id (@gene_oids) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );
        if ( !$gene_oid && isInt($taxon_oid) ) {
            $gene_oid  = $taxon_oid;
            $data_type = 'database';
            $taxon_oid = 0;
        }

        my $url;
        my $taxon_url;
        if ( $data_type eq 'database' ) {
            if ( !$taxon_oid ) {
                my $sql = "select taxon from gene where gene_oid = ?";
                my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
                ($taxon_oid) = $cur->fetchrow();
                $cur->finish();
            }

            $url =
                "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        else {
            $url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$taxon_oid&";
        }

        my @recs;
        my $aa_seq_length;
        if ( $data_type eq 'database' && isInt($gene_oid) ) {
            my $sql = "select aa_seq_length from gene where gene_oid = ?";
            my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            ($aa_seq_length) = $cur->fetchrow();
            $cur->finish();

            $sql = qq{
                      select gene_oid, cog, percent_identity, align_length,
                             query_start, query_end, subj_start, subj_end,
                             evalue, bit_score, rank_order
                      from gene_cog_groups where gene_oid = ?
                      };
            $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            for ( ; ; ) {
                my (
                    $gid2,         $cog_id,  $perc_identity,
                    $align_length, $q_start, $q_end,
                    $s_start,      $s_end,   $evalue,
                    $bit_score,    $rank
                  )
                  = $cur->fetchrow();
                last if !$gid2;
                my $str =
                    "$gid2\t$cog_id\t$perc_identity\t$align_length\t"
                  . "$q_start\t$q_end\t$s_start\t$s_end\t$evalue\t$bit_score\t$rank";
                push @recs, ($str);
            }
            $cur->finish();
        }
        else {
            my $faa = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
            $aa_seq_length = length($faa);
            my ($recs_ref, $sdbFileExist) = MetaUtil::getGeneCogInfo( $gene_oid, $taxon_oid, $data_type );
            @recs = @$recs_ref;
        }
        my $cog_ids  = "";
        my $cog_name = "";

        for my $line (@recs) {
            my (
                $gid2,    $cog_id,    $perc_identity, $align_length,
                $q_start, $q_end,     $s_start,       $s_end,
                $evalue,  $bit_score, $rank
              )
              = split( /\t/, $line );
            my $r = $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
            if ( $data_type eq 'unassembled' ) {
                $r .= $data_type . $sd . $data_type . "\t";
            }
            else {
                $r .= "assembled" . $sd . "assembled" . "\t";
            }
            my $cog_url = $cog_base_url . $cog_id;
            $r .= $cog_id . $sd . alink( $cog_url, $cog_id ) . "\t";
            my ( $func_code, $func_def ) = split( /\t/, $cog_func_h{$cog_id} );
            my $cog_name =
              "[" . $func_code . "] " . $func_def . ": " . $cog_name_h{$cog_id};
            $r .= $cog_name . $sd . $cog_name . "\t";
            $r .=
                $cog_seq_length_h{$cog_id} . $sd
              . $cog_seq_length_h{$cog_id} . "\t";
            $r .= $perc_identity . $sd . $perc_identity . "\t";
            $r .= $q_start . $sd . $q_start . "\t";
            $r .= $q_end . $sd . $q_end . "\t";
            $r .=
                '' . $sd
              . alignImage( $q_start, $q_end, $aa_seq_length, $image_len )
              . "\t";
            $r .= $bit_score . $sd . $bit_score . "\t";

            if ( !$taxon_name_h{$taxon_oid} ) {
                my $sql =
                  "select taxon_display_name from taxon where taxon_oid = ?";
                my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
                my ($taxon_name) = $cur->fetchrow();
                $cur->finish();
                $taxon_name_h{$taxon_oid} = $taxon_name;
            }

            $r .=
              $taxon_name_h{$taxon_oid} . $sd
              . alink( $taxon_url, $taxon_name_h{$taxon_oid} ) . "\t";

            $it->addRow($r);
        }

        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        print ".";
        if ( ( $gene_count % 180 ) == 0 ) {
            print "<br/>\n";
        }
    }

    printEndWorkingDiv();

    #$dbh->disconnect();
    if ( !$gene_count ) {
        print "<p>None of the selected genes have COGs.\n";
        print end_form();
        return;
    }

    $it->printOuterTable(1);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    print end_form();
}

#######################################################################################
# showPfamAlignment
#######################################################################################
sub showPfamAlignment {
    printMainForm();

    print "<h1>Pfam Alignment</h1>\n";

    my $image_len            = 150;
    my $include_workspace_id = param('include_workspace_id');

    my @gene_oids = param('gene_oid');
    if ($include_workspace_id) {
        my @workspace_ids = param('workspace_id');
        for my $id2 (@workspace_ids) {
            push @gene_oids, ($id2);
        }
    }

    if ( scalar(@gene_oids) == 0 ) {
        webError("No genes have been selected.");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    my $dbh = dbLogin();
    my %pfam_name_h;
    my %pfam_seq_length_h;
    print "Retrieving Pfam definition ...<br/>\n";
    my $sql = qq{
            select p.ext_accession, p.name, p.description, p.seq_length
            from pfam_family p
            };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $pfam_id, $pfam_name, $pfam_desc, $seq_length ) = $cur->fetchrow();
        last if !$pfam_id;
        if ($pfam_name) {
            if ($pfam_desc) {
                $pfam_name .= " - " . $pfam_desc;
            }
        }
        else {
            $pfam_name = $pfam_desc;
        }
        $pfam_name_h{$pfam_id}       = $pfam_name;
        $pfam_seq_length_h{$pfam_id} = $seq_length;
    }

    my $it = new InnerTable( 1, "pfamAlignment$$", "pfamAlignment", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Gene ID",    "char asc", "left" );
    $it->addColSpec( "Assembled?", "char asc", "left" );
    $it->addColSpec( "Pfam ID",    "char asc", "left" );
    $it->addColSpec( "Pfam Name",  "char asc", "left" );

#    $it->addColSpec( "Consensus<br/>Sequence<br/>Length",   "char asc", "left" );
    $it->addColSpec( "Percent<br/>Alignment<br/>On<br/>Query Gene",
        "number asc", "right" );
    $it->addColSpec( "Query<br/>Start", "number asc", "right" );
    $it->addColSpec( "Query<br/>End",   "number asc", "right" );
    $it->addColSpec( "Alignment On Query Gene", "desc" );
    $it->addColSpec( "HMM<br/>Score",           "number desc", "right" );
    $it->addColSpec( "Genome Name",             "asc" );

    print "Retrieving Gene Information ...<br/>\n";

    # save taxon display name to prevent repeat retrieving
    my %taxon_name_h;

    my $trunc      = 0;
    my $gene_count = 0;
    for my $workspace_id (@gene_oids) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );
        if ( !$gene_oid && isInt($taxon_oid) ) {
            $gene_oid  = $taxon_oid;
            $data_type = 'database';
            $taxon_oid = 0;
        }

        my $url;
        my $taxon_url;
        if ( $data_type eq 'database' ) {
            if ( !$taxon_oid ) {
                my $sql = "select taxon from gene where gene_oid = ?";
                my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
                ($taxon_oid) = $cur->fetchrow();
                $cur->finish();
            }

            $url =
                "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        else {
            $url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
            $taxon_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$taxon_oid&";
        }

        my @recs;
        my $aa_seq_length;
        if ( $data_type eq 'database' && isInt($gene_oid) ) {
            my $sql = "select aa_seq_length from gene where gene_oid = ?";
            my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            ($aa_seq_length) = $cur->fetchrow();
            $cur->finish();

            $sql = qq{
                      select gene_oid, pfam_family, percent_identity, align_length,
                             query_start, query_end, subj_start, subj_end,
                             evalue, bit_score
                      from gene_pfam_families where gene_oid = ?
                      };
            $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
            for ( ; ; ) {
                my (
                    $gid2,         $pfam_id, $perc_identity,
                    $align_length, $q_start, $q_end,
                    $s_start,      $s_end,   $evalue,
                    $bit_score
                  )
                  = $cur->fetchrow();
                last if !$gid2;
                my $str =
                    "$gid2\t$pfam_id\t$perc_identity\t$align_length\t"
                  . "$q_start\t$q_end\t$s_start\t$s_end\t$evalue\t$bit_score";
                push @recs, ($str);
            }
            $cur->finish();
        }
        else {
            my $faa = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
            $aa_seq_length = length($faa);
            my ($pfams_ref, $sdbFileExist) 
                = MetaUtil::getGenePfamInfo( $gene_oid, $taxon_oid, $data_type );
            for my $p2 (@$pfams_ref) {
                my (
                    $gid2,      $pfam_id, $perc_identity, $q_start,
                    $q_end,     $s_start, $s_end,         $evalue,
                    $bit_score, $t2
                  )
                  = split( /\t/, $p2 );
                my $align_length = $q_end - $q_start + 1;
                my $str          =
                    "$gid2\t$pfam_id\t$perc_identity\t$align_length\t"
                  . "$q_start\t$q_end\t$s_start\t$s_end\t$evalue\t$bit_score";
                push @recs, ($str);
            }
        }
        if ( !$aa_seq_length ) {
            next;
        }

        my $cog_ids  = "";
        my $cog_name = "";

        for my $line (@recs) {
            my (
                $gid2,    $pfam_id, $perc_identity, $align_length,
                $q_start, $q_end,   $s_start,       $s_end,
                $evalue,  $bit_score
              )
              = split( /\t/, $line );
            my $r = $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
            if ( $data_type eq 'unassembled' ) {
                $r .= $data_type . $sd . $data_type . "\t";
            }
            else {
                $r .= "assembled" . $sd . "assembled" . "\t";
            }
            my $pfam_url = $pfam_base_url . $pfam_id;
            $r .= $pfam_id . $sd . alink( $pfam_url, $pfam_id ) . "\t";
            my $pfam_name = $pfam_name_h{$pfam_id};
            $r .= $pfam_name . $sd . $pfam_name . "\t";

#	    $r .= $pfam_seq_length_h{$pfam_id} . $sd . $pfam_seq_length_h{$pfam_id} . "\t";

            if ( $q_start > $q_end ) {

                # swap
                my $tmp = $q_start;
                $q_start = $q_end;
                $q_end   = $tmp;
            }

            my $perc_alignment =
              ( ( $q_end - $q_start + 1 ) * 100.0 ) / $aa_seq_length;
            $perc_alignment = sprintf( "%.2f", $perc_alignment );
            $r .= $perc_alignment . $sd . $perc_alignment . "\t";

            #	    $r .= $perc_identity . $sd . $perc_identity . "\t";
            $r .= $q_start . $sd . $q_start . "\t";
            $r .= $q_end . $sd . $q_end . "\t";
            $r .=
                '' . $sd
              . alignImage( $q_start, $q_end, $aa_seq_length, $image_len )
              . "\t";
            $r .= $bit_score . $sd . $bit_score . "\t";

            if ( !$taxon_name_h{$taxon_oid} ) {
                my $sql =
                  "select taxon_display_name from taxon where taxon_oid = ?";
                my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
                my ($taxon_name) = $cur->fetchrow();
                $cur->finish();
                $taxon_name_h{$taxon_oid} = $taxon_name;
            }

            $r .=
              $taxon_name_h{$taxon_oid} . $sd
              . alink( $taxon_url, $taxon_name_h{$taxon_oid} ) . "\t";

            $it->addRow($r);
        }

        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        print ".";
        if ( ( $gene_count % 180 ) == 0 ) {
            print "<br/>\n";
        }
    }

    printEndWorkingDiv();

    #$dbh->disconnect();
    if ( !$gene_count ) {
        print "<p>None of the selected genes have Pfams.\n";
        print end_form();
        return;
    }

    $it->printOuterTable(1);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    print end_form();
}

#######################################################################################
# printMetaGeneSearchSelect
#######################################################################################
sub printMetaGeneSearchSelect {
    my $taxon_oid = param('taxon_oid');

    print "<p>\n";
    print "<h2>Search Protein Coding Genes</h2>\n";
    printHint(
"Genes with hypothetical protein are not included in the gene product name search result."
    );
    print "<p>\n";

    print "<table class='img'>\n";
    my $has_assembled = 0;
    print "<tr class='img'>\n";
    print "<td class='img'>Data Type</td>\n";
    print "<td class='img'>\n";
    print "<select name='geneSearchDataType' size='1'>\n";
    for my $t2 ( 'assembled', 'unassembled' ) {
        my $file =
          $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/taxon_stats.txt";
        if ( -e $file ) {
            print "<option value='$t2'>$t2</option>\n";
            if ( $t2 eq 'assembled' ) {
                $has_assembled = 1;
            }
        }
    }
    print "</select></td></tr>\n";

    print "<tr class='img'>\n";
    print "<td class='img'>Keyword</td>\n";
    print "<td class='img'>\n";
    print "<input type='text' name='geneSearchKeyword' size='60' />\n";
    print "</td></tr>\n";

    print "<tr class='img'>\n";
    print "<td class='img'>Filter</td>\n";
    print "<td class='img'>\n";
    print "<select name='geneSearchFilter' size='1'>\n";
    print
"<option value='gene_product_name'>Gene Product Name (inexact) * </option>\n";
    print
"<option value='gene_oid_merfs'>IMG Gene ID (list, case-sensitive for MER-FS) * </option>\n";
    print "</select></td></tr>\n";

    print "</table>\n";

    print "<p>Include the following information in the result:\n";

    print "<p>\n";
    print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_info' checked>\n";
    print nbsp(1);
    print "Gene Detailed Information<br/>\n";

    if ($has_assembled) {
        print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_scaf' checked>\n";
        print nbsp(1);
        print "Scaffold Information (for assembled only)<br/>\n";
    }

    print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_cog' checked>\n";
    print nbsp(1);
    print "COG Functions<br/>\n";
    print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_pfam' checked>\n";
    print nbsp(1);
    print "Pfam Functions<br/>\n";
    print
"<input type='checkbox' name=geneSearchDisplay' value='inc_gene_tigr' checked>\n";
    print nbsp(1);
    print "TIGRfam Functions<br/>\n";
    print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_ec' checked>\n";
    print nbsp(1);
    print "Enzyme Functions<br/>\n";
    print
"<input type='checkbox' name='geneSearchDisplay' value='inc_gene_ko' checked>\n";
    print nbsp(1);
    print "KO Functions<br/>\n";

    my $name = "_section_" . $section . "_showGeneSearchResult";
    print submit(
        -name  => $name,
        -value => "Search",
        -class => "smdefbutton"
    );
    print "</p>\n";

}

#######################################################################################
# showGeneSearchResult
#######################################################################################
sub showGeneSearchResult {
    printMainForm();

    print "<h1>Metagenome Gene Search Result</h1>\n";

    my $taxon_oid = param('taxon_oid');
    $taxon_oid = sanitizeInt($taxon_oid);

    my $data_type = param('geneSearchDataType');
    $data_type = sanitizeVar($data_type);

    my $search_filter = param('geneSearchFilter');

    my @options = param('geneSearchDisplay');
    if ( scalar(@options) == 0 ) {
        webError("No display options have been selected.");
        return;
    }

    my $keyword = param('geneSearchKeyword');
    WebUtil::processSearchTermCheck($keyword);
    $keyword = WebUtil::processSearchTerm( $keyword, 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    # get taxon name
    my $sql = qq{
        select tx.taxon_display_name, t.total_gene_count 
        from taxon tx, taxon_stats t 
        where tx.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name, $total_gene_count) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    print "<h3>$taxon_name ($data_type)</h3>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    print "Retrieving Gene Information ...<br/>\n";

    my $trunc      = 0;
    my $gene_count = 0;
    my %gene_name_h;
    my %gene_info_h;

    my %results_h;
    if ( $search_filter eq 'gene_product_name' ) {
        if ( $data_type ne 'assembled' && $data_type ne 'unassembled' ) {
            webError("Incorrect data type: $data_type.");
            return;
        }

        my $tag = "gene_product";
        ( $gene_count, $trunc ) =
          MetaUtil::doGeneProdNameSearch( 
            1, 1, $taxon_oid, $data_type, $tag, $keyword, 
            \%gene_name_h, $gene_count, $trunc, $maxGeneListResults );
        foreach my $workspace_id ( keys(%gene_name_h) ) {
            $results_h{$workspace_id} = 1;
        }
    }
    elsif ( $search_filter eq 'gene_oid_merfs' ) {
        my @term_list = WebUtil::splitTerm( $keyword, 0, 0 );
        my $term_str = WebUtil::joinSqlQuoted( ',', @term_list );
        if ( blankStr($term_str) ) {
            webError(
                "Please enter a comma separated list of valid IMG Gene IDs.");
        }

        MetaUtil::doGeneIdSearch( 1, $taxon_oid, $data_type, \@term_list,
            \%gene_info_h );

        my %termFoundHash;
        foreach my $workspace_id ( keys(%gene_info_h) ) {
            $results_h{$workspace_id} = 1;
            my ( $tid2, $dType2, $oid ) = split( / /, $workspace_id );
            $termFoundHash{ lc($oid) } = 1;
        }

        #to minimize case-sensitive issue
        if ( scalar(@term_list) > scalar( keys(%termFoundHash) ) ) {
            my $tag = "gene";            
            ( $gene_count, $trunc ) = MetaUtil::doGeneIdSearchInProdFile(
                1,                   1,
                $taxon_oid,          $data_type,
                $total_gene_count,   $tag,                
                \@term_list,         \%termFoundHash, 
                \%gene_name_h,       $gene_count,         
                $trunc,              $maxGeneListResults
            );
            foreach my $workspace_id ( keys(%gene_name_h) ) {
                $results_h{$workspace_id} = 1;
            }
        }

    }
    print "<br/>\n";

    if ( scalar(keys %results_h) == 0 ) {
        printStatusLine( "Loaded", 2 );
        printEndWorkingDiv();
        print "<h5>No genes found!</h5>\n";
        print end_form();
        return;
    }

    my $it = new InnerTable( 1, "geneFuncStatsList$$", "geneFuncStatsList", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "char asc", "left" );
    $it->addColSpec( "Assembled?", "char asc", "left" );

    my $get_gene_info = 0;
    my %cog_name_h;
    my %pfam_name_h;
    my %tigr_name_h;
    my %ec_name_h;
    my %ko_name_h;
    for my $op2 (@options) {
        if ( $op2 eq 'inc_gene_info' ) {
            $get_gene_info = 1;
            $it->addColSpec( "Locus Tag",       "char asc",   "right" );
            $it->addColSpec( "Locus Type",      "char asc",   "right" );
            $it->addColSpec( "Gene Name",       "char asc",   "left" );
            $it->addColSpec( "Start<br/>Coord", "number asc", "right" );
            $it->addColSpec( "End<br/>Coord",   "number asc", "right" );
            $it->addColSpec( "Gene<br/>Length", "number asc", "right" );
            $it->addColSpec( "Strand",          "char asc",   "left" );
        }
        elsif ( $op2 eq 'inc_gene_scaf' ) {
            $get_gene_info = 1;
            $it->addColSpec( "Scaffold",            "char asc",   "right" );
            $it->addColSpec( "Scaffold<br/>Length", "number asc", "right" );
            $it->addColSpec( "Scaffold<br/>GC",     "number asc", "right" );
            $it->addColSpec( "Scaffold<br/>Depth",  "number asc", "right" );
            $it->addColSpec( "# of Genes<br/>on Scaffold",
                "number asc", "right" );
        }
        elsif ( $op2 eq 'inc_gene_cog' ) {
            $it->addColSpec( "COG ID",       "char asc", "left" );
            $it->addColSpec( "COG Function", "char asc", "left" );

            print "Retrieving COG definition ...<br/>\n";
            my $dbh = dbLogin();
            my $sql = "select cog_id, cog_name from cog";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $cog_id, $cog_name ) = $cur->fetchrow();
                last if !$cog_id;
                $cog_name_h{$cog_id} = $cog_name;
            }
            #$dbh->disconnect();
        }
        elsif ( $op2 eq 'inc_gene_pfam' ) {
            $it->addColSpec( "Pfam ID",       "char asc", "left" );
            $it->addColSpec( "Pfam Function", "char asc", "left" );

            print "Retrieving Pfam definition ...<br/>\n";
            my $dbh = dbLogin();
            my $sql = "select ext_accession, description from pfam_family";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $pfam_id, $pfam_name ) = $cur->fetchrow();
                last if !$pfam_id;
                $pfam_name_h{$pfam_id} = $pfam_name;
            }
            #$dbh->disconnect();
        }
        elsif ( $op2 eq 'inc_gene_tigr' ) {
            $it->addColSpec( "TIGRfam ID",       "char asc", "left" );
            $it->addColSpec( "TIGRfam Function", "char asc", "left" );

            print "Retrieving TIGRfam definition ...<br/>\n";
            my $dbh = dbLogin();
            my $sql = "select ext_accession, expanded_name from tigrfam";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $tigr_id, $tigr_name ) = $cur->fetchrow();
                last if !$tigr_id;
                $tigr_name_h{$tigr_id} = $tigr_name;
            }
            #$dbh->disconnect();
        }
        elsif ( $op2 eq 'inc_gene_ec' ) {
            $it->addColSpec( "EC Number",       "char asc", "left" );
            $it->addColSpec( "Enzyme Function", "char asc", "left" );

            print "Retrieving Enzyme definition ...<br/>\n";
            my $dbh = dbLogin();
            my $sql = "select ec_number, enzyme_name from enzyme";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $ec_id, $ec_name ) = $cur->fetchrow();
                last if !$ec_id;
                $ec_name_h{$ec_id} = $ec_name;
            }
            #$dbh->disconnect();
        }
        elsif ( $op2 eq 'inc_gene_ko' ) {
            $it->addColSpec( "KO ID",       "char asc", "left" );
            $it->addColSpec( "KO Function", "char asc", "left" );

            print "Retrieving KO definition ...<br/>\n";
            my $dbh = dbLogin();
            my $sql = "select ko_id, ko_name, definition from ko_term";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $ko_id, $ko_name, $ko_def ) = $cur->fetchrow();
                last if !$ko_id;
                if ( !$ko_name ) {
                    $ko_name_h{$ko_id} = $ko_def;
                }
                elsif ($ko_def) {
                    $ko_name_h{$ko_id} = $ko_def . " ($ko_name)";
                }
                else {
                    $ko_name_h{$ko_id} = $ko_name;
                }
            }
            #$dbh->disconnect();
        }
    }

    my $select_id_name = "gene_oid";

    print "<p>Preparing search results ...<br/>\n";
    $gene_count = 0;
    for my $workspace_id (keys %results_h) {
        my ( $t2, $d2, $gene_oid ) = split( / /, $workspace_id );
        my $url =
            "$main_cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&data_type=$data_type"
          . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        my $r = $sd
          . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";

        $r .= $data_type . $sd . $data_type . "\t";

        my (
            $gene_oid2,         $locus_type,   $locus_tag,
            $gene_display_name, $start_coord,  $end_coord,
            $strand,            $scaffold_oid, $tid2,
            $dType2
        );
        if ($get_gene_info) {
            if ( $gene_info_h{$workspace_id} ) {
                (
                    $locus_type,   $locus_tag, $gene_display_name,
                    $start_coord,  $end_coord, $strand,
                    $scaffold_oid, $tid2,      $dType2
                  )
                  = split( /\t/, $gene_info_h{$workspace_id} );
            }
            else {
                (
                    $gene_oid2, $locus_type, $locus_tag, $gene_display_name,
                    $start_coord, $end_coord, $strand, $scaffold_oid
                  )
                  = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
            }
        }

        for my $op2 (@options) {
            if ( $op2 eq 'inc_gene_info' ) {
                my $gene_prod_name = $gene_name_h{$workspace_id};
                if ( !$gene_prod_name ) {
                    $gene_prod_name =
                      MetaUtil::getGeneProdName( $gene_oid, $taxon_oid,
                        $data_type );
                }
                if ($gene_prod_name) {
                    $gene_display_name = $gene_prod_name;
                }

                $r .= $locus_tag . $sd . $locus_tag . "\t";
                $r .= $locus_type . $sd . $locus_type . "\t";
                my $nameMatchText =
                  highlightMatchHTML2( $gene_prod_name, $keyword );
                $r .= $gene_prod_name . $sd . $nameMatchText . "\t";
                $r .= $start_coord . $sd . $start_coord . "\t";
                $r .= $end_coord . $sd . $end_coord . "\t";
                my $gene_length = $end_coord - $start_coord + 1;
                $r .= $gene_length . $sd . $gene_length . "\t";
                $r .= $strand . $sd . $strand . "\t";
            }
            elsif ( $op2 eq 'inc_gene_scaf' ) {
                if ( $data_type eq 'assembled' && $scaffold_oid ) {
                    my ( $scaf_len, $scaf_gc, $scaf_gene_cnt ) =
                      MetaUtil::getScaffoldStats( $taxon_oid, $data_type, $scaffold_oid );
                    my $scaf_depth =
                      getScaffoldDepth( $taxon_oid, $data_type, $scaffold_oid );
                    my $scaf_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldDetail&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid&data_type=$data_type";
                    my $scaf_link = alink( $scaf_url, $scaffold_oid );
                    $r .= $scaffold_oid . $sd . $scaf_link . "\t";

                    my $scaf_len_url =
                        "$main_cgi?section=MetaScaffoldGraph"
                      . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid"
                      . "&start_coord=1&end_coord=$scaf_len"
                      . "&marker_gene=$gene_oid&seq_length=$scaf_len";
                    my $scaf_len_link = alink( $scaf_len_url, $scaf_len );
                    $r .= $scaf_len . $sd . $scaf_len_link . "\t";
                    $r .= $scaf_gc . $sd . $scaf_gc . "\t";
                    $r .= $scaf_depth . $sd . $scaf_depth . "\t";

                    my $scaf_gene_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldGenes&scaffold_oid=$scaffold_oid"
                      . "&taxon_oid=$taxon_oid";
                    my $scaf_gene_link =
                      alink( $scaf_gene_url, $scaf_gene_cnt );
                    $r .= $scaf_gene_cnt . $sd . $scaf_gene_link . "\t";
                }
                else {
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                    $r .= "-" . $sd . "-" . "\t";
                }
            }
            elsif ( $op2 eq 'inc_gene_cog' ) {
                my @recs =
                  MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
                my $cog_ids  = join( "; ", @recs );
                my $cog_name = "";
                for my $cog_id (@recs) {
                    if ( $cog_name_h{$cog_id} ) {
                        if ($cog_name) {
                            $cog_name .= "; " . $cog_name_h{$cog_id};
                        }
                        else {
                            $cog_name = $cog_name_h{$cog_id};
                        }
                    }
                }

                $r .= $cog_ids . $sd . $cog_ids . "\t";
                $r .= $cog_name . $sd . $cog_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_pfam' ) {
                my @recs = MetaUtil::getGenePfamId( $gene_oid, $taxon_oid, $data_type );
                my $pfam_ids = join( "; ", @recs );
                my $pfam_name = "";
                for my $pfam_id (@recs) {
                    if ( $pfam_name_h{$pfam_id} ) {
                        if ($pfam_name) {
                            $pfam_name .= "; " . $pfam_name_h{$pfam_id};
                        }
                        else {
                            $pfam_name = $pfam_name_h{$pfam_id};
                        }
                    }
                }

                $r .= $pfam_ids . $sd . $pfam_ids . "\t";
                $r .= $pfam_name . $sd . $pfam_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_tigr' ) {
                my @recs = MetaUtil::getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
                my $tigr_ids = join( "; ", @recs );
                my $tigr_name = "";
                for my $tigr_id (@recs) {
                    if ( $tigr_name_h{$tigr_id} ) {
                        if ($tigr_name) {
                            $tigr_name .= "; " . $tigr_name_h{$tigr_id};
                        }
                        else {
                            $tigr_name = $tigr_name_h{$tigr_id};
                        }
                    }
                }

                $r .= $tigr_ids . $sd . $tigr_ids . "\t";
                $r .= $tigr_name . $sd . $tigr_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_ec' ) {
                my @recs =
                  MetaUtil::getGeneEc( $gene_oid, $taxon_oid, $data_type );
                my $ec_ids = join( "; ", @recs );
                my $ec_name = "";
                for my $ec_id (@recs) {
                    if ( $ec_name_h{$ec_id} ) {
                        if ($ec_name) {
                            $ec_name .= "; " . $ec_name_h{$ec_id};
                        }
                        else {
                            $ec_name = $ec_name_h{$ec_id};
                        }
                    }
                }

                $r .= $ec_ids . $sd . $ec_ids . "\t";
                $r .= $ec_name . $sd . $ec_name . "\t";
            }
            elsif ( $op2 eq 'inc_gene_ko' ) {
                my @recs =
                  MetaUtil::getGeneKoId( $gene_oid, $taxon_oid, $data_type );
                my $ko_ids = join( "; ", @recs );
                my $ko_name = "";
                for my $ko_id (@recs) {
                    if ( $ko_name_h{$ko_id} ) {
                        if ($ko_name) {
                            $ko_name .= "; " . $ko_name_h{$ko_id};
                        }
                        else {
                            $ko_name = $ko_name_h{$ko_id};
                        }
                    }
                }

                $r .= $ko_ids . $sd . $ko_ids . "\t";
                $r .= $ko_name . $sd . $ko_name . "\t";
            }
        }

        $it->addRow($r);
        $gene_count++;

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $gene_count genes. "
              . "Only partial result is displayed.";
            last;
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    ## save to workspace
    if ( $gene_count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($timeout_msg) {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }
    elsif ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    print end_form();
}

#######################################################################################
# printMostSimilarPatternSection
#######################################################################################
sub printMostSimilarPatternSection {
    my ( $taxon_oid0, $data_type0, $gene_oid0 ) = @_;

    my $contact_oid = getContactOid();
    my $super_user  = 'No';
    if ($contact_oid) {
        $super_user = getSuperUser();
    }
    if ( $super_user ne 'Yes' ) {
        return;
    }

    my $web_data_dir  = $env->{web_data_dir};
    my $gene_hit_file =
      $web_data_dir . "/gene.hits.zfiles/" . $taxon_oid0 . ".zip";
    if ( !( -e $gene_hit_file ) ) {

        # no gene hit data
        return;
    }

    print start_form(
        -name   => "similarPatternForm",
        -action => $main_cgi
    );

    print "<p>\n";
    print
"<h2>Search Genes in the Same Genome with Similar Occurrence Pattern</h2>\n";

    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');
    my $gene_oid  = param('gene_oid');
    $taxon_oid = $taxon_oid0 if ( !$taxon_oid );
    $data_type = $data_type0 if ( !$data_type );
    $gene_oid  = $gene_oid0  if ( !$gene_oid );

    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'data_type', $data_type );
    print hiddenVar( 'gene_oid',  $gene_oid );

    print "<p>\n";

    print "<table class='img'>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img'>\n";
    my $maxEvalue = param("maxEvalue");
    print popup_menu(
        -name    => "maxEvalue",
        -values  => [ 1e-1, 1e-2, 1e-5, 1e-7, 1e-10, 1e-20, 1e-50 ],
        -default => $maxEvalue
    );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Percent Identity</th>\n";
    print "<td class='img'>\n";
    my $minPercIdent = param("minPercIdent");
    print popup_menu(
        -name    => "minPercIdent",
        -values  => [ 10, 20, 30, 40, 50, 60, 70, 80, 90 ],
        -default => $minPercIdent
    );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Percentage Cutoff</th>\n";
    print "<td class='img'>\n";
    print "<select name='similarityPercentage' size='1'>\n";
    print "<option value='70'>70</option>\n";
    print "<option value='80'>80</option>\n";
    print "<option value='85'>85</option>\n";
    print "<option value='90'>90</option>\n";
    print "<option value='93'>93</option>\n";
    print "<option value='95'>95</option>\n";
    print "<option value='96'>96</option>\n";
    print "<option value='97'>97</option>\n";
    print "<option value='98'>98</option>\n";
    print "<option value='99'>99</option>\n";
    print "<option value='100'>100</option>\n";
    print "</select></td></tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Show Only N Hits</th>\n";
    print "<td class='img'>\n";
    print "<select name='topHits' size='1'>\n";
    print "<option value='5'>5</option>\n";
    print "<option value='10'>10</option>\n";
    print "<option value='20'>20</option>\n";
    print "<option value='30'>30</option>\n";
    print "<option value='50'>50</option>\n";
    print "<option value='80'>80</option>\n";
    print "<option value='100'>100</option>\n";
    print "<option value='120'>120</option>\n";
    print "<option value='200'>200</option>\n";
    print "</select></td></tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Show Profile?</th>\n";
    print "<td class='img'>\n";
    print "<input type='checkbox' name='show_profile' value='1' checked /> \t";
    print "</td></tr>\n";

    print "</table>\n";

    my $name = "_section_" . $section . "_showSimilarOccurrenceGenes";
    print submit(
        -name  => $name,
        -value => "Search",
        -class => "smdefbutton"
    );
    print "</p>\n";
    print end_form();
}

#######################################################################################
# showSimilarOccurrenceGenes
#######################################################################################
sub showSimilarOccurrenceGenes {
    printMainForm();

    print "<h1>Genes in the Same Genome with Similar Occurrence Pattern</h1>\n";

    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');
    if ( !$data_type ) {
        $data_type = 'database';
    }
    my $gene_oid          = param('gene_oid');
    my $maxEvalue         = param("maxEvalue");
    my $minPercIdent      = param("minPercIdent");
    my $pc                = param('similarityPercentage');
    my $topHits           = param('topHits');
    my $gene_display_name = $gene_oid;

    # find gene product name and taxon_oid for query gene
    my $dbh = dbLogin();
    if ( $data_type eq 'database' && isInt($gene_oid) ) {
        my $sql =
          "select gene_display_name, taxon from gene where gene_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ( $gene_display_name, $taxon_oid ) = $cur->fetchrow();
        $cur->finish();
    }
    else {
        my ( $gene_prod_name, $prod_src ) =
          MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
        $gene_display_name = $gene_prod_name;
    }

    # display query gene
    print "<p>\n";
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        print
"<input type='checkbox' name='gene_oid' value='$taxon_oid $data_type $gene_oid' /> \t";
    }
    elsif ( isInt($gene_oid) ) {
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' /> \t";
    }
    print nbsp(1);
    print "<b>Gene ($gene_oid): $gene_display_name</b>\n";
    print "<p>Max evalue: $maxEvalue, Min perc identity: $minPercIdent, "
      . "Similarity cutoff: $pc\n";

    my $web_data_dir  = $env->{web_data_dir};
    my $gene_hit_file =
      $web_data_dir . "/gene.hits.zfiles/" . $taxon_oid . ".zip";
    if ( !( -e $gene_hit_file ) ) {

        # no gene hit data
        print "<p><b>No precomputed homolog data.</b>\n";
        print end_form();
        return;
    }

    my $contact_oid = getContactOid();
    if ( $contact_oid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    # check genome carts
    my $use_genome_cart = 0;
    require GenomeCart;
    my $genome_cart_oids = GenomeCart::getAllGenomeOids();
    my %genome_cart_h;
    if ( $genome_cart_oids && scalar(@$genome_cart_oids) > 0 ) {
        $use_genome_cart = 1;
        for my $t2 (@$genome_cart_oids) {
            $genome_cart_h{$t2} = 1;
        }
    }

    # get all qualified taxons
    my %validTaxons_h;
    my $rclause = urClause("t.taxon_oid");
    my $sql     =
        "select t.taxon_oid from taxon t where "
      . "t.domain in ('Archaea','Bacteria', 'Eukaryota') "
      . $rclause
      . " order by 1";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($tid) = $cur->fetchrow();
        last if !$tid;

        if ( ( !$use_genome_cart ) || $genome_cart_h{$tid} ) {
            $validTaxons_h{$tid} = 1;
        }
    }
    $cur->finish();
    if ( scalar( keys %validTaxons_h ) == 0 ) {
        print "<p><b>No Archaea, Bacteria or Eukaryota is selected.</b>\n";
        print end_form();
        return;
    }

    my $validTaxons_str = join( ',', ( keys %validTaxons_h ) );

    # find all homologs above cutoff
    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    my $it = new InnerTable( 1, "geneSet$$", "geneSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",       "char asc",   "left" );
    $it->addColSpec( "Gene Name",     "char asc",   "left" );
    $it->addColSpec( "Similarity \%", "number asc", "right" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my @idRecs;
    my %idRecsHash;

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    WebUtil::unsetEnvPath();

    my %gene_hits_h;
    my $cmd           = "/usr/bin/unzip -p $gene_hit_file";
    my $rfh           = newCmdFileHandle( $cmd, "getGeneHitsRows" );
    my $prev_gene_oid = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my (
            $qid,       $sid,   $percIdent, $alen,
            $nMisMatch, $nGaps, $qstart,    $qend,
            $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $s );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        if ( $qgene_oid != $prev_gene_oid ) {
            print "Processing gene $qgene_oid ...<br/>\n";
            $prev_gene_oid = $qgene_oid;
        }

        if ( $evalue > $maxEvalue ) {
            next;
        }
        if ( $percIdent < $minPercIdent ) {
            next;
        }

        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        if ( !$validTaxons_h{$staxon} ) {
            next;
        }

        if ( $gene_hits_h{$qgene_oid} ) {
            my $h_ref = $gene_hits_h{$qgene_oid};
            $h_ref->{$staxon} = 1;
        }
        else {
            my %href2 = { $staxon => 1 };
            $gene_hits_h{$qgene_oid} = \%href2;
        }
    }
    close $rfh;
    WebUtil::resetEnvPath();

    if ( !$gene_hits_h{$gene_oid} ) {
        printEndWorkingDiv();
        print "<p><b>No similar data for query gene.</b>\n";
        print end_form();
        return;
    }

    # insert query gene
    my $rh = {
        id   => $gene_oid,
        name => $gene_display_name,
        url  => "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid",
        taxonOidHash => $gene_hits_h{$gene_oid},
    };
    push( @idRecs, $rh );
    $idRecsHash{$gene_oid} = $rh;

    my $cnt        = 0;
    my $high_score = 0;
    my $rclause    = urClause("t.taxon_oid");
    for my $id1 ( keys %gene_hits_h ) {
        if ( $id1 eq $gene_oid ) {
            next;
        }

        my $score =
          getSimilarityScore( $validTaxons_str, $gene_hits_h{$gene_oid},
            $gene_hits_h{$id1} );
        $score = sprintf( "%.2f", $score );
        print "  similarity: $score<br/>\n";

        if ( $score > $high_score ) {
            $high_score = $score;
        }

        if ( $score < $pc ) {
            next;
        }

        my $sql = "select gene_display_name from gene where gene_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $id1 );
        my ($gene_name) = $cur->fetchrow();
        $cur->finish();

        my $r =
          $sd . "<input type='checkbox' name='$select_id_name' value='$id1' /> \t";
        my $url =
          "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$id1";
        $r .= $id1 . $sd . alink( $url, $id1 ) . "\t";
        $r .= $gene_name . $sd . $gene_name . "\t";
        $r .= $score . $sd . $score . "\t";
        $it->addRow($r);

        $cnt++;

        $gene_name .= " (similarity " . $score . "\%)";
        my $rh = {
            id   => $id1,
            name => $gene_name,
            url  => "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$id1",
            taxonOidHash => $gene_hits_h{$id1}
        };
        push( @idRecs, $rh );
        $idRecsHash{$id1} = $rh;

        if ( $cnt >= $topHits ) {
            last;
        }

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $id1. "
              . "Only partial result is displayed.";
            last;
        }
    }

    printEndWorkingDiv();
    #$dbh->disconnect();

    printStatusLine( "$cnt gene(s) with similarity found.", 2 );

    if ( $contact_oid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    printMessage( "Highest similarity percentage: " . $high_score . "\%." );

    if ($cnt) {
        WebUtil::printGeneCartFooter() if ( $cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        printMetaGeneTableSelect();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);

    }

    my $show_profile = param('show_profile');
    if ($show_profile) {
        ## Print it out as an alignment.
        print "<hr>\n";
        require PhyloOccur;
        my $s = getPhyloOccurPanelDesc(); 
        PhyloOccur::printAlignment( '', \@idRecs, $s );
    }

    printStatusLine( "Loaded.", 2 );

    print end_form();
}

#######################################################################################
# showSimilarOccurrenceGenes_old
#######################################################################################
sub showSimilarOccurrenceGenes_old {
    printMainForm();

    print "<h1>Genes with Similar Occurrence Pattern</h1>\n";

    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');
    if ( !$data_type ) {
        $data_type = 'database';
    }
    my $gene_oid          = param('gene_oid');
    my $maxEvalue         = param("maxEvalue");
    my $minPercIdent      = param("minPercIdent");
    my $pc                = param('similarityPercentage');
    my $topHits           = param('topHits');
    my $gene_display_name = $gene_oid;

    my $dbh = dbLogin();
    if ( $data_type eq 'database' && isInt($gene_oid) ) {
        my $sql =
          "select gene_display_name, taxon from gene where gene_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ( $gene_display_name, $taxon_oid ) = $cur->fetchrow();
        $cur->finish();
    }
    else {
        my ( $gene_prod_name, $prod_src ) =
          MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
        $gene_display_name = $gene_prod_name;
    }

    # check genome carts
    my $use_genome_cart = 0;
    require GenomeCart;
    my $genome_cart_oids = GenomeCart::getAllGenomeOids();
    my %genome_cart_h;
    if ( $genome_cart_oids && scalar(@$genome_cart_oids) > 0 ) {
        $use_genome_cart = 1;
        for my $t2 (@$genome_cart_oids) {
            $genome_cart_h{$t2} = 1;
        }
    }

    my @validTaxons_arr = ();
    my $rclause         = urClause("t.taxon_oid");
    my $sql             =
        "select t.taxon_oid from taxon t where "
      . "t.domain in ('Archaea','Bacteria', 'Eukaryota') "
      . $rclause
      . " order by 1";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($tid) = $cur->fetchrow();
        last if !$tid;

        if ( ( !$use_genome_cart ) || $genome_cart_h{$tid} ) {
            push @validTaxons_arr, ($tid);
        }
    }
    $cur->finish();
    my $validTaxons_str = join( ',', @validTaxons_arr );

    print "<p>\n";
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        print
"<input type='checkbox' name='gene_oid' value='$taxon_oid $data_type $gene_oid' /> \t";
    }
    elsif ( isInt($gene_oid) ) {
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' /> \t";
    }
    print nbsp(1);
    print "<b>Gene ($gene_oid): $gene_display_name</b>\n";
    print "<p>Max evalue: $maxEvalue, Min perc identity: $minPercIdent, "
      . "Similarity cutoff: $pc\n";

    my $contact_oid = getContactOid();
    if ( $contact_oid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    my $it = new InnerTable( 1, "geneSet$$", "geneSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",       "char asc",   "left" );
    $it->addColSpec( "Gene Name",     "char asc",   "left" );
    $it->addColSpec( "Genome",        "char asc",   "left" );
    $it->addColSpec( "Similarity \%", "number asc", "right" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    my @idRecs;
    my %idRecsHash;

    my @hits = ();
    my %processed;
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        $processed{$workspace_id} = 1;
        @hits = getGeneHits(
            $workspace_id, $maxEvalue, $minPercIdent,
            1000,          $validTaxons_str
        );
    }
    else {
        $processed{$gene_oid} = 1;
        @hits = getGeneHits(
            $gene_oid, $maxEvalue, $minPercIdent,
            $gene_oid, $validTaxons_str
        );
    }

    my %taxons;
    for my $id2 (@hits) {
        my ( $homolog, $staxon, undef ) = split( /_/, $id2 );
        $taxons{$staxon} = 1;
    }
    my $rh = {
        id   => $gene_oid,
        name => $gene_display_name,
        url  => "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid",
        taxonOidHash => \%taxons,
    };
    push( @idRecs, $rh );
    $idRecsHash{$gene_oid} = $rh;

    my $cnt        = 0;
    my $high_score = 0;
    my $rclause    = urClause("t.taxon_oid");
    for my $id1 (@hits) {
        my ( $homolog, $staxon, undef ) = split( /_/, $id1 );
        if ( $processed{$homolog} ) {
            next;
        }
        $processed{$homolog} = 1;
        my @hits2 =
          getGeneHits( $homolog, $maxEvalue, $minPercIdent, $homolog,
            $validTaxons_str );
        my %taxons2;
        for my $id2 (@hits2) {
            my ( $g2, $staxon, undef ) = split( /_/, $id2 );
            $taxons2{$staxon} = 1;
        }

        my $score = getSimilarityScore( $validTaxons_str, \%taxons, \%taxons2 );
        $score = sprintf( "%.2f", $score );
        print "  similarity: $score<br/>\n";

        if ( $score > $high_score ) {
            $high_score = $score;
        }

        if ( $score < $pc ) {
            next;
        }

        my $sql = "select gene_display_name from gene where gene_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $homolog );
        my ($gene_name) = $cur->fetchrow();
        $cur->finish();
        $sql =
            "select t.taxon_oid, t.taxon_display_name from taxon t "
          . "where t.taxon_oid = ? "
          . $rclause;
        $cur = execSql( $dbh, $sql, $verbose, $staxon );
        my ( $tid2, $taxon_name ) = $cur->fetchrow();

        if ( !$tid2 ) {
            next;
        }
        $cur->finish();

        my $r =
          $sd . "<input type='checkbox' name='$select_id_name' value='$homolog' /> \t";
        my $url =
          "$main_cgi?section=GeneDetail" 
          . "&page=geneDetail&gene_oid=$homolog";
        $r .= $homolog . $sd . alink( $url, $homolog ) . "\t";
        $r .= $gene_name . $sd . $gene_name . "\t";
        my $taxon_url =
            "$main_cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$staxon";
        $r .=
            $taxon_name . $sd
          . "<a href=\"$taxon_url\" >"
          . $taxon_name
          . "</a> \t";
        $r .= $score . $sd . $score . "\t";
        $it->addRow($r);

        $cnt++;

        $gene_name .= " (similarity " . $score . "\%)";
        my $rh = {
            id   => $homolog,
            name => $gene_name,
            url  => "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$homolog",
            taxonOidHash => \%taxons2,
        };
        push( @idRecs, $rh );
        $idRecsHash{$homolog} = $rh;

        if ( $cnt >= $topHits ) {
            last;
        }

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $homolog. "
              . "Only partial result is displayed.";
            last;
        }
    }

    printEndWorkingDiv();
    #$dbh->disconnect();

    printStatusLine( "$cnt gene(s) with similarity found.", 2 );

    if ( $contact_oid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    printMessage( "Highest similarity percentage: " . $high_score . "\%." );

    if ($cnt) {
        
        WebUtil::printGeneCartFooter() if ( $cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        printMetaGeneTableSelect();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    my $show_profile = param('show_profile');
    if ($show_profile) {
        ## Print it out as an alignment.
        print "<hr>\n";
        require PhyloOccur;
        my $s = getPhyloOccurPanelDesc(); 
        PhyloOccur::printAlignment( '', \@idRecs, $s );
    }

    printStatusLine( "Loaded.", 2 );

    print end_form();
}


sub getPhyloOccurPanelDesc {

    my $s =
      "Profiles are based on bidirectional best hit orthologs.<br/>\n";
    $s .=
      "A dot '.' means there are no bidirectional best hit orthologs \n";
    $s .= "for the genome.<br/>\n";
        
    return $s;
}


############################################################################
# getGeneHits
############################################################################
sub getGeneHits {
    my ( $gene_oid, $maxEvalue, $minPercIdent, $blast_gene_oid, $taxon_str ) =
      @_;

    my %validTaxons;
    if ( $taxon_str ) {
        my @taxons = split( /\,/, $taxon_str );
        for my $t1 (@taxons) {
            $validTaxons{$t1} = 1;
        }
    }
    else {
        my $dbh = dbLogin();
        %validTaxons = WebUtil::getAllTaxonsHashed($dbh);
    }

    print "<p>processing gene $gene_oid ... \n";

    my @hits = ();

    if ( $include_bbh_lite && $bbh_zfiles_dir ne "" ) {
        my @recs = getBBHLiteRows($gene_oid);
        for my $r (@recs) {
            my (
                $qid,       $sid,   $percIdent, $alen,
                $nMisMatch, $nGaps, $qstart,    $qend,
                $sstart,    $send,  $evalue,    $bitScore
              )
              = split( /\t/, $r );

            my ( $q_gene_oid, $q_taxon_oid, $q_val ) = split( /\_/, $qid );
            my ( $s_gene_oid, $s_taxon_oid, $s_val ) = split( /\_/, $sid );

            if ( $q_gene_oid ne $gene_oid ) {

                # same gene
                next;
            }

            if ( $evalue > $maxEvalue ) {
                next;
            }
            if ( $percIdent < $minPercIdent ) {
                next;
            }

            # push @hits, ( $s_gene_oid );
            # print "$s_gene_oid<br/>\n";
            push @hits, ($sid);
        }

        return @hits;
    }

    # blast on the fly
    my $seq = "";
    if ( isInt($gene_oid) ) {

        # DB gene
        my $dbh = dbLogin();
        my $sql =
            "select g.locus_type, g.gene_display_name, g.aa_residue "
          . "from gene g where g.gene_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        my ( $locus_type, $gene_display_name, $aa_seq ) = $cur->fetchrow();
        $cur->finish();
        #$dbh->disconnect();
        if ( $locus_type ne 'CDS' ) {
            return @hits;
        }
        $seq = $aa_seq;
    }
    else {
        my ( $taxon_oid, $data_type, $g2 ) = split( / /, $gene_oid );
        $seq = MetaUtil::getGeneFaa( $g2, $taxon_oid, $data_type );
    }

    if ( !$seq ) {
        return @hits;
    }

    my $top_n           = 200;
    my $blast_url       = $blast_server_url;    
    webLog("blast url: $blast_server_url\n");

    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->timeout(1000);
    $ua->agent("img2.x/genePageTopHits");
    my $db = $img_lid_blastdb;
    $db = $img_iso_blastdb;

    my $req = POST $blast_url, [
        gene_oid    => $blast_gene_oid,
        seq         => $seq,
        db          => $db,
        top_n       => $top_n,              # make large number
    ];

    my %done;
    my $res = $ua->request($req);
    if ( $res->is_success() ) {
        my @lines = split( /\n/, $res->content );
        my $idx = 0;
        for my $s (@lines) {
            if ( $s =~ /ERROR:/ ) {
                return @hits;
            }
            my (
                $qid,    $sid,      $percIdent, $alen,   $nMisMatch,
                $nGaps,  $qstart,   $qend,      $sstart, $send,
                $evalue, $bitScore, $opType
              )
              = split( /\t/, $s );

            my ( $homolog, $staxon, undef ) = split( /_/, $sid );
            next if !$validTaxons{$staxon};
            next if $done{$sid};

            # check evalue
            if ( $maxEvalue && $evalue > $maxEvalue ) {
                next;
            }

            # check percent identity
            if ( $minPercIdent && $percIdent < $minPercIdent ) {
                next;
            }

            # push @hits, ( $homolog );
            # print "$sid<br/>\n";
            push @hits, ($sid);
        }
    }

    return @hits;
}

############################################################################
# getSimilarityScore
############################################################################
sub getSimilarityScore {
    my ( $taxon_str, $href_1, $href_2 ) = @_;

    my @taxons = split( /\,/, $taxon_str );
    my $cnt = 0;
    for my $taxon_oid (@taxons) {
        if ( $href_1->{$taxon_oid} && $href_2->{$taxon_oid} ) {
            $cnt++;
        }
        elsif ( !$href_1->{$taxon_oid} && !$href_2->{$taxon_oid} ) {
            $cnt++;
        }
    }

    #    print " ($cnt / " . scalar(@taxons) . ") ";
    if ( scalar(@taxons) > 0 ) {
        return ( ( $cnt * 100.00 ) / scalar(@taxons) );
    }
    else {
        return 0.0;
    }
}

1;
