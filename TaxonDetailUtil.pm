############################################################################
# Utility subroutines
# $Id: TaxonDetailUtil.pm 33689 2015-07-06 07:49:51Z jinghuahuang $
############################################################################
package TaxonDetailUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use WorkspaceUtil;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $in_file  = $env->{in_file};
my $user_restricted_site  = $env->{user_restricted_site};

my $max_gene_batch     = 900;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";

my $Protein_Coding_Genes_Title = 'Protein Coding Genes';
my $Genes_with_Function_Prediction_Title = 'Genes with Function Prediction';
my $Genes_without_Function_Prediction_Title = 'Genes without Function Prediction';
my $Non_KEGG_Genes_Title = 'Non-KEGG Genes';
my $Non_KO_Genes_Title = 'Non-KEGG Orthology (KO) Genes';
my $Non_MetaCyc_Genes_Title = 'Non-MetaCyc Genes';
my $Cassette_Genes_Title = 'Chromosomal Cassette Genes';
my $Signal_Genes_Title = 'Signal Peptide Genes';
my $Transmembrane_Genes_Title = 'Transmembrane Genes';

############################################################################
#  getProteinCodingGenesTitle
############################################################################
sub getProteinCodingGenesTitle {
    return $Protein_Coding_Genes_Title;
}

############################################################################
#  getGeneswithFunctionPredictionTitle
############################################################################
sub getGeneswithFunctionPredictionTitle {
    return $Genes_with_Function_Prediction_Title;
}

############################################################################
#  getGeneswithoutFunctionPredictionTitle
############################################################################
sub getGeneswithoutFunctionPredictionTitle {
    return $Genes_without_Function_Prediction_Title;
}

############################################################################
#  getNonKEGGGenesTitle
############################################################################
sub getNonKeggGenesTitle {
    return $Non_KEGG_Genes_Title;
}

############################################################################
#  getNonKoGenesTitle
############################################################################
sub getNonKoGenesTitle {
    return $Non_KO_Genes_Title;
}

############################################################################
#  getNonMetaCycGenesTitle
############################################################################
sub getNonMetaCycGenesTitle {
    return $Non_MetaCyc_Genes_Title;
}

############################################################################
#  getCassetteGenesTitle
############################################################################
sub getCassetteGenesTitle {
    return $Cassette_Genes_Title;
}

############################################################################
#  getSignalGenesTitle
############################################################################
sub getSignalGenesTitle {
    return $Signal_Genes_Title;
}

############################################################################
#  getTransmembraneGenesTitle
############################################################################
sub getTransmembraneGenesTitle {
    return $Transmembrane_Genes_Title;
}

############################################################################
#  fetchCogId2NameHash
############################################################################
sub fetchCogId2NameHash {
    my ( $dbh, $og, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select ${og}_id, ${og}_name 
        from $og 
        where ${og}_id in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        next if $funcId2Name_href->{$id} ne "";

        $funcId2Name_href->{$id} = escHtml($name);
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

sub fetchCogId2NameAndSeqLengthHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $funcId2Seqlength_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select cog_id, cog_name, seq_length 
        from cog
        where cog_id in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $seq_length ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = escHtml($name);
        $funcId2Seqlength_href->{$id} = $seq_length;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchPfamId2NameHash
############################################################################
sub fetchPfamId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select pf.ext_accession, pf.name, pf.description, pf.db_source
        from pfam_family pf
        where pf.ext_accession in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $ext_accession, $name, $desc, $db_source ) = $cur->fetchrow();
        last if !$ext_accession;
        next if $funcId2Name_href->{$ext_accession} ne "";

        my $x;
        $x = " - $desc" if $db_source =~ /HMM/;
        $funcId2Name_href->{$ext_accession} = escHtml($name) . $x;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchTIGRfamId2NameHash
############################################################################
sub fetchTIGRfamId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select tf.ext_accession, tf.expanded_name
        from tigrfam tf
        where tf.ext_accession in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $ext_accession, $name ) = $cur->fetchrow();
        last if !$ext_accession;
        next if $funcId2Name_href->{$ext_accession} ne "";

        $funcId2Name_href->{$ext_accession} = escHtml($name);
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchKoid2DefinitionHash
############################################################################
sub fetchKoid2NameDefHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $funcId2Def_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select ko_id, ko_name, definition
        from ko_term 
        where ko_id in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $koid, $name, $definition ) = $cur->fetchrow();
        last if !$koid;
        $funcId2Name_href->{$koid} = $name;
        $funcId2Def_href->{$koid} = $definition;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchEnzymeId2NameHash
############################################################################
sub fetchEnzymeId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select ez.ec_number, ez.enzyme_name
        from enzyme ez
        where ez.ec_number in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $ec_number, $name ) = $cur->fetchrow();
        last if !$ec_number;
        $funcId2Name_href->{$ec_number} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchTcId2NameHash
############################################################################
sub fetchTcId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select tc_family_num, tc_family_name
        from tc_family
        where tc_family_num in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $tc_number, $name ) = $cur->fetchrow();
        last if !$tc_number;
        $funcId2Name_href->{$tc_number} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchIprId2NameHash
############################################################################
sub fetchIprId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select giih.id, giih.description
        from gene_xref_families giih
        where giih.id in ($funcIdsInClause)
        and giih.db_name = 'InterPro'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchMetacycId2NameHash
############################################################################
sub fetchMetacycId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getFuncIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select bp.unique_id, bp.common_name
        from biocyc_pathway bp 
        where bp.unique_id in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $funcIdsInClause =~ /gtt_func_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchImgTermId2NameHash
############################################################################
sub fetchImgTermId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getNumberIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select it.term_oid, it.term
        from img_term it
        where it.term_oid in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $funcIdsInClause =~ /gtt_num_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchImgPathwayId2NameHash
############################################################################
sub fetchImgPathwayId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getNumberIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select ipw.pathway_oid, ipw.pathway_name
        from img_pathway ipw
        where ipw.pathway_oid in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $funcIdsInClause =~ /gtt_num_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchImgPartsListId2NameHash
############################################################################
sub fetchImgPartsListId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getNumberIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select ipl.parts_list_oid, ipl.parts_list_name
        from img_parts_list ipl
        where ipl.parts_list_oid in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $funcIdsInClause =~ /gtt_num_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  fetchImgClusterId2NameHash
############################################################################
sub fetchClusterId2NameHash {
    my ( $dbh, $ids_ref, $funcId2Name_href, $keepClause) = @_;

    my $funcIdsInClause = OracleUtil::getNumberIdsInClause( $dbh, @$ids_ref );
    my $sql = qq{
        select pg.group_oid, pg.group_name
        from paralog_group pg
        where pg.group_oid in ($funcIdsInClause)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name_href->{$id} = $name;
    }
    $cur->finish();

    if (!$keepClause) {
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $funcIdsInClause =~ /gtt_num_id/i );
        return '';
    }
    
    return $funcIdsInClause;
}

############################################################################
#  print2ColGeneCountTable - Print 2 column table with
#   1. function name
#   2. gene count
############################################################################
sub print2ColGeneCountTable {
    my ( $type, $rows_aref, $nameCol ) = @_;

    if ($nameCol eq '') {
        $nameCol = 'Name';
    }

    my $count = 0;
    my $it = new InnerTable( 1, "$type$$", $type, 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "$nameCol",           "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );
    for my $r (@$rows_aref) {
        $it->addRow($r);
        $count++;
    }

    $it->printOuterTable(1);

}

############################################################################
#  print3ColGeneCountTable - Print 3 column table with
#   1. function id
#   2. function name
#   3. gene count
############################################################################
sub print3ColGeneCountTable {
    my ( $type, $rows_aref, $idCol, $nameCol, $section, $buttonName, $buttonValue) = @_;

    if ($idCol eq '') {
        $idCol = 'ID';
    }
    if ($nameCol eq '') {
        $nameCol = 'Name';
    }

    my $count = 0;
    my $it = new InnerTable( 1, "$type$$", $type, 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "$idCol",             "asc",  "left" );
    $it->addColSpec( "$nameCol",           "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );
    
    for my $r (@$rows_aref) {
        $it->addRow($r);
        $count++;
    }

    if ($count > 10) {
        printCartButtons($section, $buttonName, $buttonValue);
    }
    $it->printOuterTable(1);
    printCartButtons($section, $buttonName, $buttonValue);

    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace('func_id');
    }
    
}

sub printCartButtons {
    my ( $section, $buttonName, $buttonValue, $noGeneButton, $noFuncButton ) = @_;
    #print "printCartButtons: $section<br/>\n";
    
    if ( $buttonName ne '' && $buttonValue ne '') {
        print submit(
            -name  => $buttonName,
            -value => $buttonValue,
            -class => "smdefbutton"
        );
        print nbsp(1);
    }
    if ($section ne '' && !$noGeneButton) {
        printAddToGeneCartButton($section);
    }
    if ($noFuncButton) {
        WebUtil::printButtonFooter();        
    }
    else {
        WebUtil::printFuncCartFooter();
    }
}

sub printAddToGeneCartButton {
    my ( $section ) = @_;
    #print "printAddToGeneCartButton section: $section<br/>\n";

    my $id          = "_section_${section}_addGeneCart";
    my $buttonLabel = "Add Selected to Gene Cart";
    my $buttonClass = "meddefbutton";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    print "\n";
}

# instead of a sql to gene_oid, send a gene array list, aref
#
sub printGeneListSectionSortingNoSql {
    my ( $gene_list_aref, $title, $notitlehtmlesc ) = @_;

    printMainForm();
    print "<h1>\n";
    if ( defined $notitlehtmlesc ) {
        print $title . "\n";
    } else {
        print escHtml($title) . "\n";
    }
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";

    my $dbh = dbLogin();

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome ID",       "char asc", "right" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );

    my @gene_oids;
    my $count = 0;
    foreach my $gene_oid (@$gene_list_aref) {
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
    }

    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print "</p>\n";

    print end_form();

}

#
# prints gene list with sorting
#
sub printGeneListSectionSorting {
    my ( $sql, $title, $notitlehtmlesc, @binds ) = @_;

    return printGeneListSectionSorting1( '', $sql, $title, $notitlehtmlesc, @binds );
}

#
# prints gene list with sorting1
#
sub printGeneListSectionSorting1 {
    my ( $taxon_oid, $sql, $title, $notitlehtmlesc, @binds ) = @_;

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );

    if ( $title ne "" ) {
        print "<h1>\n";
        if ( defined $notitlehtmlesc && $notitlehtmlesc ne "" ) {
            print $title . "\n";
        } else {
            print escHtml($title) . "\n";
        }
        print "</h1>\n";
    }
    printStatusLine( "Loading ...", 1 );

    my ( $count, $s ) = printGeneListSectionSortingCore( $sql, @binds );

    if ($count > 0) {
        my $select_id_name = 'gene_oid';
        if ( $title eq $Protein_Coding_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllCDSGeneList($select_id_name);            
        }
        elsif ( $title eq $Genes_with_Function_Prediction_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneProdList($select_id_name);
        }
        elsif ( $title eq $Genes_without_Function_Prediction_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneWithoutFuncList($select_id_name);
        }
        elsif ( $title eq $Non_KEGG_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllNonKeggGeneList($select_id_name);
        }
        elsif ( $title eq $Non_KO_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllNonKoGeneList($select_id_name);
        }
        elsif ( $title eq $Non_MetaCyc_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllNonMetacycGeneList($select_id_name);
        }
        elsif ( $title eq $Cassette_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllCassetteGenes($select_id_name);
        }
        elsif ( $title eq $Signal_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllSignalGenes($select_id_name);
        }
        elsif ( $title eq $Transmembrane_Genes_Title ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllTransmembraneGenes($select_id_name);
        }
        else {
            WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);            
        }
    }

    printStatusLine( $s, 2 );    
    print end_form();
    
    return ( $count, $s );
}

#
# print gene list with sorting core
#
sub printGeneListSectionSortingCore {
    my ( $sql, @binds ) = @_;

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my @gene_oids;
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );

    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    my $s = "";
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) 
        . " to change \"Max. Gene List Results\" limit. )\n";
    } else {
        $s = "$count gene(s) retrieved.";
    }
    
    return ( $count, $s );
}


# extra column for gene list
sub printGeneListSectionSorting2 {
    my ( $taxon_oid, $sql, $title, $notitlehtmlesc, 
	 $extraColName, $extrasql, $extraurl ) = @_;

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );

    if ( $title ne "" ) {
        print "<h1>\n";
        if ( defined $notitlehtmlesc && $title ne "" ) {
            print $title . "\n";
        } elsif ( $title ne "" ) {
            print escHtml($title) . "\n";
        }
        print "</h1>\n";
    }
    printStatusLine( "Loading ...", 1 );

    my ( $count, $s ) = printGeneListSectionSortingCore2( $sql, $extraColName, $extrasql, $extraurl );

    if ($count > 0) {
        my $select_id_name = 'gene_oid';
        if ( $title eq "Biosynthetic Cluster Genes" ) {
            WorkspaceUtil::printSaveGeneToWorkspace_withAllBiosyntheticGenes($select_id_name);
        }
        else {
            WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);            
        }
    }

    printStatusLine( $s, 2 );
    print end_form();
    
    return ( $count, $s );
}

sub printGeneListSectionSortingCore2 {
    my ( $sql, $extraColName, $extrasql, $extraurl ) = @_;

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my @gene_oids;
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "$extraColName",     "char asc",   "left" );
    
    HtmlUtil::flushGeneBatchSorting2( $dbh, \@gene_oids, $it, 0, 
                      $extrasql, $extraurl );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    my $s = "";
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) 
        . " to change \"Max. Gene List Results\" limit. )\n";
    } else {
        $s = "$count gene(s) retrieved.";
    }
    
    return ( $count, $s );
}


############################################################################
# printFromGeneOids - Print gene list with footer.  Query must
#  retrieve only gene_oid's.
############################################################################
sub printFromGeneOids {
    my ( $gene_oids_ref, $title ) = @_;

    printMainForm();
    if ( $title ne "" ) {
        print "<h1>\n";
        print escHtml($title) . "\n";
        print "</h1>\n";
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome ID",         "number asc", "right" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );

    my $count = 0;
    my @gene_oids;
    for my $gene_oid (@$gene_oids_ref) {
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
    }

    if ( $count > $maxGeneListResults ) {
        printTruncatedStatus($maxGeneListResults);
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }

    print end_form();
}

#####################################################################
# printCatGeneListTable
#####################################################################
sub printCatGeneListTable {
    my ( $dbh, $sql, @binds ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @recs;
    my %gene2func;
    my %genefuncDone;
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_display_name, $func_id, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        my $rec;
        $rec .= "$gene_oid\t";
        $rec .= "$locus_tag\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$func_id";
        push( @recs, $rec );

        my $gfKey = "$gene_oid:$func_id";
        $gene2func{$gene_oid} .= "$func_id,"
          if !blankStr($func_id) && !$genefuncDone{$gfKey};
        $genefuncDone{$gfKey} = 1;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Name", "asc", "left"  );
    $it->addColSpec( "Function", "asc", "left"  );
    my $sd = $it->getSdDelim();

    my %done;
    my $count = 0;
    for my $r (@recs) {
        my ( $gene_oid, $locus_tag, $gene_display_name, $func_id ) =
          split( /\t/, $r );
        next if ( $done{$gene_oid} );
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid'/>" . "\t";

        my $url = "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . "<a href='" . $url . "'>$gene_oid</a>" . "\t";

        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $gene_display_name . $sd . $gene_display_name . "\t";

        my $funcList;
        if ( $gene_display_name ) {
            $funcList = $gene2func{$gene_oid};
            chop $funcList;
        }
        $r .= $funcList . $sd . $funcList . "\t";

        $it->addRow($r);
        $done{$gene_oid} = 1;
    }

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    return $count;
}

#####################################################################
# getSubmissionType
#####################################################################
sub getSubmissionType {
    my ($dbh, $analysis_project_id) = @_;
    my $sql = qq{
select gap.submission_type, gap.gold_analysis_project_type
from gold_analysis_project gap
where gap.gold_id = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $analysis_project_id );
    my ($st, $pt) = $cur->fetchrow();

    return ($pt, $st);
}


#####################################################################
# printTaxonPublications
#####################################################################
sub printTaxonPublications {
    my ($dbh, $taxon_oid, $label, $table_name) = @_;

    ## get GOLD SP ID
    my $sql = "select sequencing_gold_id from taxon where taxon_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($gold_sp_id) = $cur->fetchrow();
    $cur->finish();

    return if ! $gold_sp_id;

    $sql = "select count(*) from $table_name where gold_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $gold_sp_id );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    return if ! $cnt;

    print "<tr class='img'>\n";
    print "<td class='img'><b>$label</b></th>";
    print "<td class='img'><table class='img'>\n";
    my @flds = ('pubmed_id', 'journal_name', 'volume', 'issue',
		'page', 'title', 'publication_date', 'doi');
    $sql = "select gold_id, " . join(", ", @flds) .
	" from $table_name " .
	" where gold_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $gold_sp_id );
    for (;;) {
	my ($id2, @rest) = $cur->fetchrow();
	last if ! $id2;
	my $k = 0;
	for my $fld ( @flds ) {
	    my $val = "";
	    if ( $k < scalar(@rest) ) {
		$val = $rest[$k];
	    }
	    $k++;
	    if ( ! $val ) {
		next;
	    }

	    my $fld_label = ucfirst($fld);
	    if ( $fld eq 'pubmed_id' ) {
		$fld_label = 'Pubmed ID';
	    }
	    elsif ( $fld eq 'journal_name' ) {
		$fld_label = 'Journal Name';
	    }
	    elsif ( $fld eq 'publication_date' ) {
		$fld_label = 'Publication Date';
	    }
	    print "<tr class='img'>\n";
	    print "<td class='img'><b>$fld_label</b></td>\n";
	    print "<td class='img'>$val</td>\n";
	    print "</tr>\n";
	}
    }
    $cur->finish();

    print "</table></td>\n";
    print "</tr>\n";
}


1;
