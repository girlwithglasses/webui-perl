############################################################################
# TaxonSearchUtil.pm - share use
#
# $Id: TaxonSearchUtil.pm 33504 2015-06-03 20:00:02Z klchu $
############################################################################
package TaxonSearchUtil;
my $section = "TaxonSearchUtil";
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    getGenomeFieldAttrs
    getColName2Align_g
    getColName2Label_g
    getColName2SortQual_g
    getPreferenceRestrictClause
);

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $ncbi_project_id_base_url          = $env->{ncbi_project_id_base_url};
my $cmr_jcvi_ncbi_project_id_base_url = $env->{cmr_jcvi_ncbi_project_id_base_url};
my $include_metagenomes  = $env->{include_metagenomes};

### optional genome field columns to configuration and display 
my @gOptCols = (
    'taxon_oid',
    'ncbi_taxon_id', 
    'refseq_project_id',
    'gbk_project_id',
    'phylum',
    'ir_class',
    'ir_order',
    'family',
    'genus',
    'species',
    'strain',
    'seq_center',
    'funding_agency',
    'add_date',
    'is_public',
    'release_date',
    'img_version',
    'img_product_flag',
    'submission_id',
    'analysis_project_id',
    'study_gold_id',
    'sequencing_gold_id',
    'proposal_name',

);

if($include_metagenomes) {
    #push(@gOptCols,"sample_gold_id");
}

if ($img_internal) {
    my @gOptCols_internal = (
        'jgi_project_id',
    );
    splice(@gOptCols, 18, 0, @gOptCols_internal);

    if ($img_lite) {
        my @gOptCols_lite = (
            'is_std_reference',
        );
        splice(@gOptCols, 15, 0, @gOptCols_lite); #to place it ahead of 'jgi_project_id'
    }
}

### Maps database column name to UI friendly label.
my %colName2Label_g = (
    taxon_oid          => "Taxon ID",
    taxon_oid_display  => "Taxon ID",
    taxon_display_name => "Genome Name",
    ncbi_taxon_id      => "NCBI Taxon ID",
    refseq_project_id  => "RefSeq Project ID",
    gbk_project_id     => "GenBank Project ID",
    domain             => "Domain",
    phylum             => "Phylum",
    ir_class           => "Class",
    ir_order           => "Order",
    family             => "Family",
    genus              => "Genus",
    species            => "Species",
    strain             => "Strain",
    seq_status         => "Genome Completion",
    seq_center         => "Sequencing Center",
    finishing_group    => "Finishing Group",
    funding_agency     => "Funding Agency",
    add_date           => "Add Date",
    is_public          => "Is Public",
    release_date       => "Release Date",
    is_std_reference   => "Is Std. Reference Genome",
    img_version        => "IMG Release",
    img_product_flag   => "IMG Product Assignment",
    submission_id      => "IMG Submission ID",
    jgi_project_id     => "JGI Project ID",
    analysis_project_id            => "ANALYSIS PROJECT ID",
    proposal_name      => "Study Name",
    study_gold_id     => "STUDY GOLD ID",
    sequencing_gold_id     => "SEQUENCING_GOLD_ID",
    cog_cat_cnt        => "COG Category Count",
    kegg_cnt           => "KEGG Count",
    ext_accession      => "External Accession",
    scaffold_oid       => "Scaffold ID",
    sample_oid  => "IMG Sample ID",
    project_info => 'IMG Project ID',     
);

if($include_metagenomes)  {
    $colName2Label_g{phylum} =  "Phylum / Ecosystem";
    $colName2Label_g{ir_class} = "Class / Ecosystem Category";
    $colName2Label_g{ir_order} = "Order / Ecosystem Type";
    $colName2Label_g{family} = "Family / Ecosystem Subtype";    
    $colName2Label_g{genus} = "Genus / Specific Ecosystem";
    $colName2Label_g{species} = "Species / Study";
    $colName2Label_g{taxon_display_name} =  "Genome Name / Sample Name";
}

my %colName2Align_g = (
    taxon_oid          => "num asc right",
    taxon_oid_display  => "num asc right",
    taxon_display_name => "char asc left",
    ncbi_taxon_id      => "num asc right",
    refseq_project_id  => "num asc right",
    gbk_project_id     => "num asc right",
    domain             => "char asc left",
    phylum             => "char asc left",
    ir_class           => "char asc left",
    ir_order           => "char asc left",
    family             => "char asc left",
    genus              => "char asc left",
    species            => "char asc left",
    strain             => "char asc left",
    seq_status         => "char asc left",
    seq_center         => "char asc left",
    finishing_group    => "char asc left",
    funding_agency     => "char asc left",
    add_date           => "char desc left",
    is_public          => "char asc left",
    release_date       => "char desc left",
    is_std_reference   => "char asc left",
    img_version        => "char asc left",
    img_product_flag   => "char asc left",
    submission_id      => "num desc left",
    jgi_project_id     => "num asc right",
    analysis_project_id            => "char asc left",
    proposal_name      => "char asc left",
    study_gold_id     => "char asc left",
    sequencing_gold_id     => "char asc left",
    cog_cat_cnt        => "num desc right",   
    kegg_cnt           => "num desc right",   
    ext_accession      => "char asc left",
    sample_oid         => "num asc right",
    project_info      => "num asc right",    
);

## Sort qualifiation
my %colName2SortQual_g = (
    ncbi_taxon_id      => "asc",
    refseq_project_id  => "asc",
    gbk_project_id     => "asc",
    taxon_oid          => "asc",
    taxon_oid_display  => "asc",
    taxon_display_name => "asc",
    domain             => "asc, taxon_display_name",
    phylum             => "asc, taxon_display_name",
    ir_class           => "asc, taxon_display_name",
    ir_order           => "asc, taxon_display_name",
    family             => "asc, taxon_display_name",
    genus              => "asc, taxon_display_name",
    species            => "asc, taxon_display_name",
    strain             => "asc, taxon_display_name",
    seq_status         => "asc, taxon_display_name",
    seq_center         => "asc",
    finishing_group    => "asc",
    funding_agency     => "asc",
    add_date           => "desc",
    is_public          => "asc, taxon_display_name",
    release_date       => "desc",
    is_std_reference   => "asc",
    img_version        => "asc, taxon_display_name",
    img_product_flag   => "asc",
    submission_id      => "desc",
    jgi_project_id     => "asc",
    analysis_project_id            => "asc",
    proposal_name      => "asc",
    study_gold_id     => "asc",
    sequencing_gold_id     => "asc",
    sample_oid         => "asc",
    project_info      => "asc",    
);

sub getGenomeFieldAttrs {
    return @gOptCols;
}

sub getColName2Label_g {
	return %colName2Label_g;
}

sub getColName2Align_g {
    return %colName2Align_g;
}

sub getColName2SortQual_g {
    return %colName2Label_g;
}

############################################################################
# getPreferenceRestrictionClause - Get search restrictions due to preference
############################################################################
sub getPreferenceRestrictClause {

    my $restrictClause = '';
    my @bindList = ();
    my $mainPageStats = param("mainPageStats");
    if ( $mainPageStats eq "" ) {
        my $hideViruses = getSessionParam("hideViruses");
        $hideViruses = "Yes" if $hideViruses eq "";
        if ($hideViruses eq "Yes") {
            $restrictClause .= "and tx.domain not like ? ";
            push(@bindList, 'Vir%');
        }        
        my $hidePlasmids = getSessionParam("hidePlasmids");
        $hidePlasmids = "Yes" if $hidePlasmids eq "";
        if ($hidePlasmids eq "Yes") {
            $restrictClause .= "and tx.domain not like ? ";
            push(@bindList, 'Plasmid%');
        }     
        my $hideGFragment = getSessionParam("hideGFragment");
        $hideGFragment = "Yes" if $hideGFragment eq "";
        if ($hideGFragment eq "Yes") {
            $restrictClause .= "and tx.domain not like ? ";
            push(@bindList, 'GFragment%');
        }     
    }

    return ($restrictClause, @bindList);
}

############################################################################
# printNotes - Show additional notes.
############################################################################
sub printNotes {
    my ($useSimpleHint) = @_;
    if ($useSimpleHint == 1) {
        printHint( "Selections do not take effect until you save them. "
		 . "You must select at least one genome.<br/>" );       
    }
    else {
        printNotesHint();       
    }
    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "\n";
    print "</p>\n";
}

sub printNotesHint {
    my $url      = "$main_cgi?section=MyIMG&page=preferences";
    my $prefLink = alink( $url, "Preferences" );
    my $url      = "$main_cgi?page=home";
    my $homeLink = alink( $url, "IMG Genomes" );
    printHint
	( "Go to $prefLink to show or hide plasmids, GFragment and viruses.<br/>\n"
	. "Go to home page statistics under $homeLink "
        . "to select individual phylogenetic domains or all genomes.<br/>" );
}

############################################################################
# printButtonFooter - Print button footer.
############################################################################
sub printButtonFooter {
    my ($txTableName) = @_;
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'medbutton',
	          -onClick => "return isGenomeSelected('$txTableName');"
    );
    print nbsp( 1 );
    WebUtil::printButtonFooterInLine();
}

sub getNCBIProjectIdLink {
    my ($ncbi_pid) = @_;
    
    my $link = "$ncbi_pid";
    if ($ncbi_pid > 0) {
        my $url  = "$ncbi_project_id_base_url$ncbi_pid";
        $link = alink( $url, $ncbi_pid );
    }
    return $link;
}

1;
