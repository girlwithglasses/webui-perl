############################################################################
#
# $Id: GenomeList.pm 33841 2015-07-29 20:48:56Z klchu $
############################################################################
package GenomeList;

use strict;
use CGI qw( :standard );
use DBI;
use Date::Format;
use InnerTable;
use OracleUtil;
use DataEntryUtil;
use WebConfig;
use WebUtil;
use HtmlUtil;
use Data::Dumper;
use TabHTML;
use TaxonSearchUtil;
use AnalysisProject;

my $section                   = 'GenomeList';
my $env                       = getEnv();
my $main_cgi                  = $env->{main_cgi};
my $section_cgi               = "$main_cgi?section=$section";
my $base_dir                  = $env->{base_dir};
my $base_url                  = $env->{base_url};
my $verbose                   = $env->{verbose};
my $user_restricted_site      = $env->{user_restricted_site};
my $img_internal              = $env->{img_internal};
my $img_lite                  = $env->{img_lite};
my $img_hmp                   = $env->{img_hmp};
my $img_er                    = $env->{img_er};
my $include_metagenomes       = $env->{include_metagenomes};
my $cgi_tmp_dir               = $env->{cgi_tmp_dir};
my $taxonomy_base_url         = $env->{taxonomy_base_url};
my $ncbi_project_id_base_url  = $env->{ncbi_project_id_base_url};
my $img_mer_submit_url        = $env->{img_mer_submit_url};
my $img_er_submit_url         = $env->{img_er_submit_url};
my $img_er_submit_project_url = $env->{img_er_submit_project_url};
my $gold_base_url             = $env->{gold_base_url};
my $gold_base_url2            = $env->{gold_base_url_analysis};
my $img_ken                   = $env->{img_ken};
my $enable_interpro           = $env->{enable_interpro};
my $urlTag                    = $env->{urlTag};
my $dir                       = WebUtil::getSessionDir($section);
my $myTaxonPrefs              = 'myTaxonPrefs';                      # filename
my $myProjectPrefs            = 'myProjectPrefs';                    # filename
my $mySamplePrefs             = 'mySamplePrefs';                     # filename
my $myTaxonStatsPrefs         = 'myTaxonStatsPrefs';                 # filename

#my $projectMetadataDir                 = "/webfs/scratch/img/gold/";
#my $project_info_project_relevanceFile = $projectMetadataDir . 'project_info_project_relevance';
#my $project_info_cell_arrangementFile  = $projectMetadataDir . 'project_info_cell_arrangement';
#my $project_info_diseasesFile          = $projectMetadataDir . 'project_info_diseases';
#my $project_info_energy_sourceFile     = $projectMetadataDir . 'project_info_energy_source';
#my $project_info_metabolismFile        = $projectMetadataDir . 'project_info_metabolism';
#my $project_info_phenotypesFile        = $projectMetadataDir . 'project_info_phenotypes';
#my $project_info_habitatFile           = $projectMetadataDir . 'project_info_habitat';
#my $project_info_seq_methodFile        = $projectMetadataDir . 'project_info_seq_method';
#my $sample_body_siteFile               = $projectMetadataDir . 'sample_body_site';
#my $sample_body_subsiteFile            = $projectMetadataDir . 'sample_body_subsite';

my $cacheDir = "/webfs/scratch/img/gold/";
my $database = $cacheDir . "projectInfo2.db"; # see ../preComputedData/ProjectMetadata3.pl

#$dir .= "/$section";
#if ( !( -e "$dir" ) ) {
#    mkdir "$dir" or webError("Can not make $dir!");
#}
$cgi_tmp_dir = $dir;

# get the subdirectory of the file
sub getGenomeListDir {
    return $cgi_tmp_dir;
}

# ======================================================================================================
#
# start of configuration -
# to add more metadata display
# Note: the column names have the sql table alias
#
# ======================================================================================================
#
#
# columns that are always checked
# for the stats columns you have to make exceptions in the uncheck since the id has been used for count and percent
# - thus the check is in the javascript code - genomeConfig.js
my %alwaysChecked = (
    't.proposal_name'          => "id='always_checked' checked disabled",
    't.taxon_display_name'     => "id='always_checked' checked disabled",
    't.domain'                 => "id='always_checked' checked disabled",
    't.seq_center'             => "id='always_checked' checked disabled",
    't.seq_status'             => "id='always_checked' checked disabled",
    'ts.total_bases'           => "checked disabled",
    'ts.total_gene_count'      => "checked disabled",
    'sum(ts.total_bases)'      => "checked disabled",
    'sum(ts.total_gene_count)' => "checked disabled",

);

#
# column values that should be a url
#
# http://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=MSubmission&page=displaySubmission&submission_id=227
# http://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ERSubmission&page=displaySubmission&submission_id=2646
#
# t.submission_id - exception because there are two urls one for er and the other for mer
#
my %columnAsUrl = (
    't.taxon_display_name' => 'main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=',
    't.study_gold_id'            => $gold_base_url,

    't.sequencing_gold_id' => $gold_base_url,
    't.submission_id'                  => 'xxxxx',
    't.ncbi_taxon_id'                  => $taxonomy_base_url,
    't.gbk_project_id'                  => 'http://www.ncbi.nlm.nih.gov/bioproject/',
    't.refseq_project_id'              => $ncbi_project_id_base_url,
    'p.project_oid'                    => $img_er_submit_project_url,

    'ts.total_biosynthetic' => 'main.cgi?section=BiosyntheticDetail&page=biosynthetic_clusters&taxon_oid=',
    'p.ncbi_project_id'     => $ncbi_project_id_base_url,
    'en.project_info'       => $img_er_submit_project_url,
    't.analysis_project_id' => $gold_base_url2,
);

# ------------------------------------------------------------------------------------------------------
#
# IMG taxon table
#
# ===================
# order diplay columns selections
#
# key db column name => ui display name
# taxon t
# taxon_stats ts
# t.release_date
my @genomeColumnsOrder = (
    't.domain',                              't.seq_status',
    't.proposal_name',                       't.taxon_display_name',
    't.seq_center',                          't.phylum',
    't.ir_class',                            't.ir_order',
    't.family',                              't.genus',
    't.species',                             't.taxon_oid',
    't.ncbi_taxon_id',                       't.refseq_project_id',
    't.gbk_project_id',                      't.submission_id',
    't.jgi_project_id',                      't.study_gold_id',
    't.sequencing_gold_id',      't.analysis_project_id',
    'gap.gold_analysis_project_type',        'gap.is_gene_primp',  'gap.submission_type', 'gap.assembly_method',
    't.strain',                              't.funding_agency',
    't.is_public',                           't.comments',
    't.img_version',                         't.img_product_flag',
    't.high_quality_flag',                   "to_char(t.add_date, 'yyyy-mm-dd')",
    "to_char(t.release_date, 'yyyy-mm-dd')", "to_char(t.distmatrix_date, 'yyyy-mm-dd')"
);

if ($include_metagenomes) {
    push( @genomeColumnsOrder, 't.combined_sample_flag' );
}
if ($user_restricted_site) {
    push( @genomeColumnsOrder, 'c.username' );
}
if ( getSuperUser() eq 'Yes' ) {
    push( @genomeColumnsOrder, 'c.submittername' );
    push( @genomeColumnsOrder, 't.in_file' );
}

# genome file db column names and ui display label
my %genomeColumns = (
    't.taxon_oid'                              => 'IMG Genome ID (IMG Taxon ID)',
    't.taxon_display_name'                     => 'Genome Name / Sample Name',
    't.ncbi_taxon_id'                          => 'NCBI Taxon ID',
    't.refseq_project_id'                      => 'RefSeq Project ID',
    't.gbk_project_id'                         => 'NCBI Project ID',
    't.domain'                                 => 'Domain',
    't.phylum'                                 => 'Phylum',
    't.ir_class'                               => 'Class',
    't.ir_order'                               => 'Order',
    't.family'                                 => 'Family',
    't.genus'                                  => 'Genus',
    't.species'                                => 'Species',
    't.strain'                                 => 'Strain',
    't.seq_center'                             => 'Sequencing Center',
    't.funding_agency'                         => 'Funding Agency',
    "to_char(t.add_date, 'yyyy-mm-dd')"        => 'Add Date',
    't.is_public'                              => 'Is Public',
    "to_char(t.release_date, 'yyyy-mm-dd')"    => 'Release Date',
    't.img_version'                            => 'IMG Release',
    't.img_product_flag'                       => 'IMG Product Assignment',
    't.submission_id'                          => 'IMG Submission ID',
    't.proposal_name'                          => 'Study Name',
    't.study_gold_id'                          => 'GOLD Study ID',
    't.sequencing_gold_id'                     => 'GOLD Project ID',
    't.seq_status'                             => 'Status',
    't.combined_sample_flag'                   => 'Combined Sample',
    't.jgi_project_id'                         => 'JGI Project ID',
    't.comments'                               => 'Comments',
    't.high_quality_flag'                      => 'High Quality',
    "to_char(t.distmatrix_date, 'yyyy-mm-dd')" => 'Distance Matrix Calc. Date',
    't.analysis_project_id'                    => 'GOLD Analysis Project ID',
    'gap.gold_analysis_project_type'           => 'GOLD Analysis Project Type',
    'gap.submission_type'                      => 'Submission Type',
    'gap.is_gene_primp'                      => 'Gene Model QC',
    'gap.assembly_method' => 'Assembly Method',
);

if ($user_restricted_site) {

    #
    # EXCEPTION column - unfornately I had to do this for private genome list - ken
    # see getTaxonTableData or search for 'c.username'
    $genomeColumns{'c.username'} = 'User Access';
}

if ( getSuperUser() eq 'Yes' ) {
    $genomeColumns{'c.submittername'} = 'Submitter Name*';
    $genomeColumns{'t.in_file'}       = 'In File*';
}

# how to align data in the display table
my %genomeColumnsAlign = (
    't.taxon_oid'                              => 'num asc right',
    't.taxon_display_name'                     => 'char asc left',
    't.ncbi_taxon_id'                          => 'num asc right',
    't.refseq_project_id'                      => 'num asc right',
    't.gbk_project_id'                         => 'num asc right',
    't.domain'                                 => 'char asc left',
    't.phylum'                                 => 'char asc left',
    't.ir_class'                               => 'char asc left',
    't.ir_order'                               => 'char asc left',
    't.family'                                 => 'char asc left',
    't.genus'                                  => 'char asc left',
    't.species'                                => 'char asc left',
    't.strain'                                 => 'char asc left',
    't.seq_center'                             => 'char asc left',
    't.funding_agency'                         => 'char asc left',
    "to_char(t.add_date, 'yyyy-mm-dd')"        => 'char asc left',
    't.is_public'                              => 'char asc left',
    "to_char(t.release_date, 'yyyy-mm-dd')"    => 'char asc left',
    't.img_version'                            => 'num asc right',
    't.img_product_flag'                       => 'char asc left',
    't.submission_id'                          => 'num asc right',
    't.proposal_name'                          => 'char asc left',
    't.study_gold_id'                                => 'char asc left',
    't.sequencing_gold_id'                     => 'char asc left',
    't.seq_status'                             => 'char asc left',
    'c.username'                               => 'char asc left',
    'c.submittername'                          => 'char asc left',
    't.in_file'                                => 'char asc left',
    't.combined_sample_flag'                   => 'char asc left',
    't.jgi_project_id'                         => 'num asc right',
    't.comments'                               => 'char asc left',
    't.high_quality_flag'                      => 'char asc left',
    "to_char(t.distmatrix_date, 'yyyy-mm-dd')" => 'char asc left',
    't.analysis_project_id'                    => 'char asc left',
    'gap.gold_analysis_project_type'           => 'char asc left',
    'gap.submission_type'                      => 'char asc left',
    'gap.is_gene_primp'                      => 'char asc left',
    'gap.assembly_method'                      => 'char asc left',
);

# ------------------------------------------------------------------------------------------------------
#
# GOLD project_info table
#
# ===================
#
# project metadata
#
# ===================
# order diplay columns selections
#
# key db column name => ui display name
# taxon t
# taxon_stats ts
# t.release_date

my %projectMetadataColumns = (
'p.MOTILITY' => 'Motility',  
'p.TEMP_RANGE' => 'Temperature Range',  
'p.SALINITY' => 'Salinity',  
'p.SEQ_STATUS' => 'Seq Status',  
'p.ISO_COUNTRY' => 'Isolation Country',  
'p.DATE_COLLECTED' => 'Sample Collection Date ',  
'p.GEO_LOCATION' => 'Geographic Location', 
'p.LATITUDE' => 'Latitude',  
'p.LONGITUDE' => 'Longitude',  
'p.ALTITUDE' => 'Altitude',  
'p.GRAM_STAIN' => 'Gram Staining',  
'p.HOST_NAME' => 'Host Name',  
'p.HOST_GENDER' => 'Host Gender',      
'p.BIOTIC_REL' => 'Biotic Relationships',  
'p.HMP_ID' => 'HMP ID',     
'p.FUNDING_PROGRAM' => 'Funding Program',  
'p.TYPE_STRAIN' => 'Type Strain',   
'p.ECOSYSTEM' => 'Ecosystem',  
'p.ECOSYSTEM_CATEGORY' => 'Ecosystem Category',  
'p.ECOSYSTEM_TYPE' => 'Ecosystem Type',  
'p.ECOSYSTEM_SUBTYPE' => 'Ecosystem Subtype',  
'p.SPECIFIC_ECOSYSTEM' => 'Specific Ecosystem',  
'p.SAMPLE_BODY_SITE' => 'Sample Body Site',  
'p.SAMPLE_BODY_SUBSITE' => 'Sample Body Subsite',  
'p.MRN' => 'Medical Record Number',         
'p.VISIT_NUM' => 'Visits',         
'p.REPLICATE_NUM' => 'Replicate',         
'p.PMO_PROJECT_ID' => 'PMO ID',     
'p.CULTURED' => 'Cultured',   
'p.UNCULTURED_TYPE' => 'Uncultured Type',   
'p.CULTURE_TYPE' => 'Culture Type',   
'p.BIOPROJECT_ACCESSION' => 'Bioproject Accession',   
'p.BIOSAMPLE_ACCESSION' => 'Biosample Accession',  
'p.ITS_SPID' => 'ITS PID',         
'p.PI_EMAIL' => 'Contact Email',  
'p.PI_NAME' => 'Contact Name',
'p.name' => 'Alt. Contact Name', 
'p.email' => 'Alt. Contact Email',
'p.cell_shape'           => 'Cell Shape',
'p.ISOLATION'            => 'Isolation',
'p.oxygen_req'           => 'Oxygen Requirement',
'p.SPORULATION'          => 'Sporulation',
'p.DISPLAY_NAME'         => 'Project / Study Name',
'p.depth'                => 'Depth',

'p.clade' => 'Clade',
'p.ecotype' => 'Ecotype',
'p.longhurst_code' => 'Longhurst Code',
'p.longhurst_description' => 'Longhurst Description',

'p.SEQUENCING_STRATEGY' => 'GOLD Sequencing Strategy',
'p.SEQUENCING_QUALITY' =>'GOLD Sequencing Quality',
'p.SEQUENCING_DEPTH' => 'GOLD Sequencing Depth',

    'p.seq_method' => 'Sequencing Method',
    'p.project_relevance' => 'Relevance',
    'p.phenotypes' => 'Phenotype',
    'p.metabolism' => 'Metabolism',
    'p.habitat' => 'Habitat',
    'p.energy_source'        => 'Energy Source',
    'p.cell_arrangement' => 'Cell Arrangement',
    'p.diseases'             => 'Diseases',
);

# value sorted
my @projectMetadataColumnsOrder = sort { $projectMetadataColumns{$a} cmp $projectMetadataColumns{$b} } keys %projectMetadataColumns;

# default is     'p.biotic_rel'           => 'char asc left',
my %projectMetadataColumnsAlign = (
    'p.hmp_id'               => 'num asc right',
    'p.its_spid'             => 'num asc right',
    'p.pmo_project_id'       => 'num asc right',
);


# ------------------------------------------------------------------------------------------------------
#
# stats
#
# ------------------------------------------------------------------------------------------------------
my $total_coding_bases_pc     = 'round(ts.total_coding_bases  * 100 / decode(ts.total_gatc, 0, null, ts.total_gatc), 2)';
my $total_coding_bases_npd_pc = 'round(ts.total_coding_bases_npd  * 100 / decode(ts.total_gatc, 0, null, ts.total_gatc), 2)';
my $gene_wo_func_pred         = 'ts.cds_genes - ts.genes_w_func_pred';
my $gene_wo_func_pred_pc      = "round(($gene_wo_func_pred)  * 100 / ts.total_gene_count, 2)";
my @statsColumnsOrder         = (
    'ts.total_bases',              'ts.total_gene_count',
    'ts.n_scaffolds',              'ts.crispr_count',
    'ts.total_gc',                 'ts.gc_percent',
    'ts.total_coding_bases',       $total_coding_bases_pc,
    'ts.total_coding_bases_npd',   $total_coding_bases_npd_pc,
    'ts.cds_genes',                'ts.cds_genes_pc',
    'ts.rna_genes',                'ts.rna_genes_pc',
    'ts.rrna_genes',               'ts.rrna5s_genes',
    'ts.rrna16s_genes',            'ts.rrna18s_genes',
    'ts.rrna23s_genes',            'ts.rrna28s_genes',
    'ts.trna_genes',               'ts.other_rna_genes',
    'ts.pseudo_genes',             'ts.pseudo_genes_pc',
    'ts.uncharacterized_genes',    'ts.uncharacterized_genes_pc',
    'ts.dubious_genes',            'ts.dubious_genes_pc',
    'ts.genes_w_func_pred',        'ts.genes_w_func_pred_pc',
    $gene_wo_func_pred,            $gene_wo_func_pred_pc,
    'ts.genes_in_orthologs',       'ts.genes_in_orthologs_pc',
    'ts.genes_in_paralogs',        'ts.genes_in_paralogs_pc',
    'ts.genes_obsolete',           'ts.genes_obsolete_pc',
    'ts.genes_revised',            'ts.genes_revised_pc',
    'ts.fused_genes',              'ts.fused_genes_pc',
    'ts.fusion_components',        'ts.fusion_components_pc',
    'ts.genes_in_sp',              'ts.genes_in_sp_pc',
    'ts.genes_not_in_sp',          'ts.genes_not_in_sp_pc',
    'ts.genes_in_cog',             'ts.genes_in_cog_pc',
    'ts.genes_in_kog',             'ts.genes_in_kog_pc',
    'ts.genes_in_pfam',            'ts.genes_in_pfam_pc',
    'ts.genes_in_tigrfam',         'ts.genes_in_tigrfam_pc',
    'ts.genes_in_enzymes',         'ts.genes_in_enzymes_pc',
    'ts.genes_in_tc',              'ts.genes_in_tc_pc',
    'ts.genes_in_kegg',            'ts.genes_in_kegg_pc',
    'ts.genes_not_in_kegg',        'ts.genes_not_in_kegg_pc',
    'ts.genes_in_ko',              'ts.genes_in_ko_pc',
    'ts.genes_not_in_ko',          'ts.genes_not_in_ko_pc',
    'ts.genes_in_metacyc',         'ts.genes_in_metacyc_pc',
    'ts.genes_not_in_metacyc',     'ts.genes_not_in_metacyc_pc',
    'ts.genes_in_img_terms',       'ts.genes_in_img_terms_pc',
    'ts.genes_in_img_pways',       'ts.genes_in_img_pways_pc',
    'ts.genes_in_parts_list',      'ts.genes_in_parts_list_pc',
    'ts.genes_in_myimg',           'ts.genes_in_myimg_pc',
    'ts.genes_signalp',            'ts.genes_signalp_pc',
    'ts.genes_transmembrane',      'ts.genes_transmembrane_pc',
    'ts.genes_hor_transfer',       'ts.genes_hor_transfer_pc',
    'ts.genes_in_genome_prop',     'ts.genes_in_genome_prop_pc',
    'ts.ortholog_groups',          'ts.paralog_groups',
    'ts.cog_clusters',             'ts.kog_clusters',
    'ts.pfam_clusters',            'ts.tigrfam_clusters',
    'ts.genes_in_img_clusters',    'ts.genes_in_img_clusters_pc',
    'ts.genes_in_cassettes',       'ts.genes_in_cassettes_pc',
    'ts.total_cassettes',          'ts.genes_in_biosynthetic',
    'ts.genes_in_biosynthetic_pc', 'ts.total_biosynthetic',

);

if ($enable_interpro) {
    push( @statsColumnsOrder, 'ts.genes_in_ipr' );
    push( @statsColumnsOrder, 'ts.genes_in_ipr_pc' );
}

my %statsColumns = (
    'ts.n_scaffolds'              => 'Scaffold Count (Number of scaffolds)',
    'ts.crispr_count'             => 'CRISPR Count (Number of CRISPRs)',
    'ts.total_gc'                 => 'GC Count (Number of GC)',
    'ts.gc_percent'               => 'GC (GC % in fraction)',
    'ts.total_coding_bases'       => 'Coding Base Count (Total number of coding bases)',
    $total_coding_bases_pc        => 'Coding Base Count % (Percentage of Total number of coding bases)',
    'ts.total_coding_bases_npd'   => 'Coding Base Count NP (Total number of coding bases no pseudogenes)',
    $total_coding_bases_npd_pc    => 'Coding Base Count NP % (Percentage of Total number of coding bases no pseudogenes)',
    'ts.total_bases'              => 'Genome Size (Number of total bases)',
    'ts.total_gene_count'         => 'Gene Count (Number of total Genes)',
    'ts.cds_genes'                => 'CDS Count (Number of CDS genes)',
    'ts.cds_genes_pc'             => 'CDS % (Percentage of CDS genes)',
    'ts.rna_genes'                => 'RNA Count (Number of RNA genes)',
    'ts.rna_genes_pc'             => 'RNA %',
    'ts.rrna_genes'               => 'rRNA Count (Number of rRNA genes)',
    'ts.rrna5s_genes'             => '5S rRNA Count (Number of 5S rRNAs)',
    'ts.rrna16s_genes'            => '16S rRNA Count (Number of 16S rRNAs)',
    'ts.rrna18s_genes'            => '18S rRNA Count (Number of 18S rRNAs)',
    'ts.rrna23s_genes'            => '23S rRNA Count (Number of 23S rRNAs)',
    'ts.rrna28s_genes'            => '28S rRNA Count (Number of 28S rRNAs)',
    'ts.trna_genes'               => 'tRNA Count (Number of tRNA genes)',
    'ts.other_rna_genes'          => 'Other RNA Count (Number of other unclassified RNA genes)',
    'ts.pseudo_genes'             => 'Pseudo Genes Count (Number of pseudo genes)',
    'ts.pseudo_genes_pc'          => 'Pseudo Genes % (Percentage of pseudo genes)',
    'ts.uncharacterized_genes'    => 'Unchar Count (Number of uncharacerized genes)',
    'ts.uncharacterized_genes_pc' => 'Unchar % (Percentage of uncharacterized genes)',
    'ts.dubious_genes'            => 'Dubious Count',
    'ts.dubious_genes_pc'         => 'Dubious %',
    'ts.genes_w_func_pred'        => 'w/ Func Pred Count (Number of genes with predicted protein product)',
    'ts.genes_w_func_pred_pc'     => 'w/ Func Pred % (Percentage of genes with predicted protein product)',
    $gene_wo_func_pred            => 'w/o function prediction',
    $gene_wo_func_pred_pc         => 'w/o function prediction %',
    'ts.genes_in_orthologs'       => 'Orthologs Count',
    'ts.genes_in_orthologs_pc'    => 'Orthologs %',
    'ts.genes_in_paralogs'        => 'Paralogs Count',
    'ts.genes_in_paralogs_pc'     => 'Paralogs %',
    'ts.genes_obsolete'           => 'Obsolete Count (Number of obsolete genes)',
    'ts.genes_obsolete_pc'        => 'Obsolete % (Percentage of obsolete genes)',
    'ts.genes_revised'            => 'Revised Count (Number of revised genes)',
    'ts.genes_revised_pc'         => 'Revised % (Percentage of revised genes)',
    'ts.fused_genes'              => 'Fused Count (Number of fused genes)',
    'ts.fused_genes_pc'           => 'Fused % (Percentage of fused genes)',
    'ts.fusion_components'        => 'Fusion Component Count (Number of genes involved as fusion components)',
    'ts.fusion_components_pc'     => 'Fusion component % (Genes involved as fusion components percentage)',
    'ts.genes_in_sp'              => 'SwissProt Count (Number of genes in SwissProt protein product)',
    'ts.genes_in_sp_pc'           => 'SwissProt % (Percentage of genes in SwissProt protein product)',
    'ts.genes_not_in_sp'          => 'Not SwissProt Count (Number of genes not in SwissProt protein product)',
    'ts.genes_not_in_sp_pc'       => 'Not SwissProt % (Percentage of genes not in SwissProt protein product)',
    'ts.genes_in_cog'             => 'COG Count (Number of genes in COG)',
    'ts.genes_in_cog_pc'          => 'COG % (Percentage of genes in COG)',
    'ts.genes_in_kog'             => 'KOG Count (Number of genes in KOG)',
    'ts.genes_in_kog_pc'          => 'KOG % (Percentage of genes in KOG)',
    'ts.genes_in_pfam'            => 'Pfam Count (Number of genes in Pfam)',
    'ts.genes_in_pfam_pc'         => 'Pfam % (Percentage of genes in Pfam)',
    'ts.genes_in_tigrfam'         => 'TIGRfam Count (Number of genes in TIGRfam)',
    'ts.genes_in_tigrfam_pc'      => 'TIGRfam % (Percentage of genes in TIGRfam)',
    'ts.genes_in_enzymes'         => 'Enzyme Count (Number of genes assigned to enzymes)',
    'ts.genes_in_enzymes_pc'      => 'Enzyme % (Percentage of genes assigned to enzymes)',
    'ts.genes_in_tc'              => 'TC Count (Number of genes assigned to Transporter Classification)',
    'ts.genes_in_tc_pc'           => 'TC % (Percentage of genes assigned to Transporter Classification)',
    'ts.genes_in_kegg'            => 'KEGG Count (Number of genes in KEGG)',
    'ts.genes_in_kegg_pc'         => 'KEGG % (Percentage of genes in KEGG)',
    'ts.genes_not_in_kegg'        => 'Not KEGG Count (Number of genes not in KEGG)',
    'ts.genes_not_in_kegg_pc'     => 'Not KEGG % (Percentage of genes not in KEGG)',
    'ts.genes_in_ko'              => 'KO Count (Number of genes in KEGG Orthology (KO))',
    'ts.genes_in_ko_pc'           => 'KO % (Percentage of genes in KEGG Orthology (KO))',
    'ts.genes_not_in_ko'          => 'Not KO Count (Number of genes not in KEGG Orthology (KO))',
    'ts.genes_not_in_ko_pc'       => 'Not KO % (Percentage of genes not in KEGG Orthology (KO))',
    'ts.genes_in_metacyc'         => 'MetaCyc Count (Number of genes in MetaCyc)',
    'ts.genes_in_metacyc_pc'      => 'MetaCyc % (Percentage of genes in MetaCyc)',
    'ts.genes_not_in_metacyc'     => 'Not MetaCyc Count (Number of genes not in MetaCyc)',
    'ts.genes_not_in_metacyc_pc'  => 'Not MetaCyc % (Percentage of genes not in MetaCyc',
    'ts.genes_in_img_terms'       => 'IMG Term Count (Number of genes with IMG terms)',
    'ts.genes_in_img_terms_pc'    => 'IMG Term % (Percentage of genes with IMG terms)',
    'ts.genes_in_img_pways'       => 'IMG Pathwawy Count (Number of genes in IMG pathwawys)',
    'ts.genes_in_img_pways_pc'    => 'IMG Pathway % (Percentage of genes in IMG pathways)',
    'ts.genes_in_parts_list'      => 'IMG Parts List Count (Number of genes in IMG parts list)',
    'ts.genes_in_parts_list_pc'   => 'IMG Parts List % (Percentage of genes in IMG parts list)',
    'ts.genes_in_myimg'           => 'MyIMG Annotation Count',
    'ts.genes_in_myimg_pc'        => 'MyIMG Annotation %',
    'ts.genes_signalp'            => 'Signal Peptide Count (Number of genes coding signal peptides)',
    'ts.genes_signalp_pc'         => 'Signal Peptide % (Percentage of genes coding signal peptides)',
    'ts.genes_transmembrane'      => 'Transmembrane Count (Number of genes coding transmembrane proteins)',
    'ts.genes_transmembrane_pc'   => 'Transmembrane % (Percentage of genes coding transmembrane proteins)',
    'ts.genes_hor_transfer'       => 'Horizontally Transferred Count',
    'ts.genes_hor_transfer_pc'    => 'Horizontally Transferred %',
    'ts.genes_in_genome_prop'     => 'Genome Property Count (Number of genes in Genome Properties)',
    'ts.genes_in_genome_prop_pc'  => 'Genome Property % (Percentage of genes in Genome Properties)',
    'ts.ortholog_groups'          => 'Ortholog Group Count',
    'ts.paralog_groups'           => 'Paralog Group Count',
    'ts.cog_clusters'             => 'COG Cluster Count (Number of COG clusters)',
    'ts.kog_clusters'             => 'KOG Cluster Count (Number of KOG clusters)',
    'ts.pfam_clusters'            => 'Pfam Cluster Count (Number of Pfam clusters)',
    'ts.tigrfam_clusters'         => 'TIGRfam Cluster Count (Number of TIGRfam clusters)',
    'ts.genes_in_img_clusters'    => 'IMG Cluster Count',
    'ts.genes_in_img_clusters_pc' => 'IMG Cluster %',
    'ts.genes_in_cassettes'       => 'Chromosomal Cassette Gene Count',
    'ts.genes_in_cassettes_pc'    => 'Chromosomal Cassette Gene %',
    'ts.total_cassettes'          => 'Chromosomal Cassette Count',
    'ts.genes_in_biosynthetic'    => 'Biosynthetic Cluster Gene Count',
    'ts.genes_in_biosynthetic_pc' => 'Biosynthetic Cluster Gene %',
    'ts.total_biosynthetic'       => 'Biosynthetic Cluster Count',
    'ts.genes_in_ipr'             => 'InterPro Count (Number of genes in InterPro)',
    'ts.genes_in_ipr_pc'          => 'InterPro % (Percentage of genes in InterPro)',
);

if ($enable_interpro) {
    $statsColumns{'ts.genes_in_ipr'}    = 'InterPro Count (Number of genes in InterPro)';
    $statsColumns{'ts.genes_in_ipr_pc'} = 'InterPro % (Percentage of genes in InterPro)';
}

# all are numbers align right
my %statsColumnsAlign = ( 'num asc right' => 'num asc right' );

# ------------------------------------------------------------------------------------------------------
#
# stats for merfs
#
# ------------------------------------------------------------------------------------------------------
#
# valid columns in the table
#
my %statsColumnsMerfs = (
    'ts.n_scaffolds'             => 'Scaffold Count (Number of scaffolds)',
    'ts.crispr_count'            => 'CRISPR Count (Number of CRISPRs)',
    'ts.total_gc'                => 'GC Count (Number of GC)',
    'ts.gc_percent'              => 'GC (GC % in fraction)',
    'ts.total_bases'             => 'Genome Size (Number of total bases)',
    'ts.total_gene_count'        => 'Gene Count (Number of total Genes)',
    'ts.cds_genes'               => 'CDS Count (Number of CDS genes)',
    'ts.cds_genes_pc'            => 'CDS % (Percentage of CDS genes)',
    'ts.rna_genes'               => 'RNA Count (Number of RNA genes)',
    'ts.rna_genes_pc'            => 'RNA %',
    'ts.rrna_genes'              => 'rRNA Count (Number of rRNA genes)',
    'ts.rrna5s_genes'            => '5S rRNA Count (Number of 5S rRNAs)',
    'ts.rrna16s_genes'           => '16S rRNA Count (Number of 16S rRNAs)',
    'ts.rrna18s_genes'           => '18S rRNA Count (Number of 18S rRNAs)',
    'ts.rrna23s_genes'           => '23S rRNA Count (Number of 23S rRNAs)',
    'ts.rrna28s_genes'           => '28S rRNA Count (Number of 28S rRNAs)',
    'ts.trna_genes'              => 'tRNA Count (Number of tRNA genes)',
    'ts.other_rna_genes'         => 'Other RNA Count (Number of other unclassified RNA genes)',
    'ts.genes_w_func_pred'       => 'w/ Func Pred Count (Number of genes with predicted protein product)',
    'ts.genes_w_func_pred_pc'    => 'w/ Func Pred % (Percentage of genes with predicted protein product)',
    $gene_wo_func_pred           => 'w/o function prediction',
    $gene_wo_func_pred_pc        => 'w/o function prediction %',
    'ts.genes_in_cog'            => 'COG Count (Number of genes in COG)',
    'ts.genes_in_cog_pc'         => 'COG % (Percentage of genes in COG)',
    'ts.genes_in_pfam'           => 'Pfam Count (Number of genes in Pfam)',
    'ts.genes_in_pfam_pc'        => 'Pfam % (Percentage of genes in Pfam)',
    'ts.genes_in_tigrfam'        => 'TIGRfam Count (Number of genes in TIGRfam)',
    'ts.genes_in_tigrfam_pc'     => 'TIGRfam % (Percentage of genes in TIGRfam)',
    'ts.genes_in_enzymes'        => 'Enzyme Count (Number of genes assigned to enzymes)',
    'ts.genes_in_enzymes_pc'     => 'Enzyme % (Percentage of genes assigned to enzymes)',
    'ts.genes_in_kegg'           => 'KEGG Count (Number of genes in KEGG)',
    'ts.genes_in_kegg_pc'        => 'KEGG % (Percentage of genes in KEGG)',
    'ts.genes_not_in_kegg'       => 'Not KEGG Count (Number of genes not in KEGG)',
    'ts.genes_not_in_kegg_pc'    => 'Not KEGG % (Percentage of genes not in KEGG)',
    'ts.genes_in_ko'             => 'KO Count (Number of genes in KEGG Orthology (KO))',
    'ts.genes_in_ko_pc'          => 'KO % (Percentage of genes in KEGG Orthology (KO))',
    'ts.genes_not_in_ko'         => 'Not KO Count (Number of genes not in KEGG Orthology (KO))',
    'ts.genes_not_in_ko_pc'      => 'Not KO % (Percentage of genes not in KEGG Orthology (KO))',
    'ts.genes_in_metacyc'        => 'MetaCyc Count (Number of genes in MetaCyc)',
    'ts.genes_in_metacyc_pc'     => 'MetaCyc % (Percentage of genes in MetaCyc)',
    'ts.genes_not_in_metacyc'    => 'Not MetaCyc Count (Number of genes not in MetaCyc)',
    'ts.genes_not_in_metacyc_pc' => 'Not MetaCyc % (Percentage of genes not in MetaCyc',

    'ts.cog_clusters' => 'COG Cluster Count (Number of COG clusters)',

    'ts.pfam_clusters'            => 'Pfam Cluster Count (Number of Pfam clusters)',
    'ts.tigrfam_clusters'         => 'TIGRfam Cluster Count (Number of TIGRfam clusters)',
    'ts.genes_in_biosynthetic'    => 'Biosynthetic Cluster Gene Count',
    'ts.genes_in_biosynthetic_pc' => 'Biosynthetic Cluster Gene %',
    'ts.total_biosynthetic'       => 'Biosynthetic Cluster Count',
);

#
# end of stats for merfs
#
#

# ------------------------------------------------------------------------------------------------------
#
# stats column for phylum list display
#
# ------------------------------------------------------------------------------------------------------
my $phylum_gene_wo_func_pred = 'sum(ts.cds_genes) - sum(ts.genes_w_func_pred)';
my @phylumStatsColumnsOrder  = (
    'sum(ts.total_bases)',           'sum(ts.total_gene_count)',
    'sum(ts.n_scaffolds)',           'sum(ts.crispr_count)',
    'sum(ts.total_gc)',              'sum(ts.total_coding_bases_npd)',
    'sum(ts.total_coding_bases)',    'sum(ts.cds_genes)',
    'sum(ts.rna_genes)',             'sum(ts.rrna_genes)',
    'sum(ts.rrna5s_genes)',          'sum(ts.rrna16s_genes)',
    'sum(ts.rrna18s_genes)',         'sum(ts.rrna23s_genes)',
    'sum(ts.rrna28s_genes)',         'sum(ts.trna_genes)',
    'sum(ts.other_rna_genes)',       'sum(ts.pseudo_genes)',
    'sum(ts.uncharacterized_genes)', 'sum(ts.dubious_genes)',
    'sum(ts.genes_w_func_pred)',     $phylum_gene_wo_func_pred,
    'sum(ts.genes_in_orthologs)',    'sum(ts.genes_in_paralogs)',
    'sum(ts.genes_obsolete)',        'sum(ts.genes_revised)',
    'sum(ts.fused_genes)',           'sum(ts.fusion_components)',
    'sum(ts.genes_in_sp)',           'sum(ts.genes_not_in_sp)',
    'sum(ts.genes_in_cog)',          'sum(ts.genes_in_kog)',
    'sum(ts.genes_in_pfam)',         'sum(ts.genes_in_tigrfam)',
    'sum(ts.genes_in_enzymes)',      'sum(ts.genes_in_tc)',
    'sum(ts.genes_in_kegg)',         'sum(ts.genes_not_in_kegg)',
    'sum(ts.genes_in_ko)',           'sum(ts.genes_not_in_ko)',
    'sum(ts.genes_in_metacyc)',      'sum(ts.genes_not_in_metacyc)',
    'sum(ts.genes_in_img_terms)',    'sum(ts.genes_in_img_pways)',
    'sum(ts.genes_in_parts_list)',   'sum(ts.genes_in_myimg)',
    'sum(ts.genes_signalp)',         'sum(ts.genes_transmembrane)',
    'sum(ts.genes_hor_transfer)',    'sum(ts.genes_in_genome_prop)',
    'sum(ts.ortholog_groups)',       'sum(ts.paralog_groups)',
    'sum(ts.cog_clusters)',          'sum(ts.kog_clusters)',
    'sum(ts.pfam_clusters)',         'sum(ts.tigrfam_clusters)',
    'sum(ts.genes_in_img_clusters)', 'sum(ts.genes_in_cassettes)',
    'sum(ts.total_cassettes)',       'sum(ts.genes_in_biosynthetic)',
    'sum(ts.total_biosynthetic)',
);

my %phylumStatsColumns = (
    'sum(ts.n_scaffolds)'            => 'Scaffold Count (Number of scaffolds)',
    'sum(ts.crispr_count)'           => 'CRISPR Count (Number of CRISPRs)',
    'sum(ts.total_gc)'               => 'GC Count (Number of GC)',
    'sum(ts.total_coding_bases)'     => 'Coding Base Count (Total number of coding bases)',
    'sum(ts.total_coding_bases_npd)' => 'Coding Base Count NP (Total number of coding bases no pseudogenes)',
    'sum(ts.total_bases)'            => 'Genome Size (Number of total bases)',
    'sum(ts.total_gene_count)'       => 'Gene Count (Number of total Genes)',
    'sum(ts.cds_genes)'              => 'CDS Count (Number of CDS genes)',
    'sum(ts.rna_genes)'              => 'RNA Count (Number of RNA genes)',
    'sum(ts.rrna_genes)'             => 'rRNA Count (Number of rRNA genes)',
    'sum(ts.rrna5s_genes)'           => '5S rRNA Count (Number of 5S rRNAs)',
    'sum(ts.rrna16s_genes)'          => '16S rRNA Count (Number of 16S rRNAs)',
    'sum(ts.rrna18s_genes)'          => '18S rRNA Count (Number of 18S rRNAs)',
    'sum(ts.rrna23s_genes)'          => '23S rRNA Count (Number of 23S rRNAs)',
    'sum(ts.rrna28s_genes)'          => '28S rRNA Count (Number of 28S rRNAs)',
    'sum(ts.trna_genes)'             => 'sum(tRNA Count (Number of tRNA genes)',
    'sum(ts.other_rna_genes)'        => 'Other RNA Count (Number of other unclassified RNA genes)',
    'sum(ts.pseudo_genes)'           => 'Pseudo Genes Count (Number of pseudo genes)',
    'sum(ts.uncharacterized_genes)'  => 'Unchar Count (Number of uncharacerized genes)',
    'sum(ts.dubious_genes)'          => 'Dubious Count',
    'sum(ts.genes_w_func_pred)'      => 'w/ Func Pred Count (Number of genes with predicted protein product)',
    $phylum_gene_wo_func_pred        => 'w/o function prediction',
    'sum(ts.genes_in_orthologs)'     => 'Orthologs Count',
    'sum(ts.genes_in_paralogs)'      => 'Paralogs Count',
    'sum(ts.genes_obsolete)'         => 'Obsolete Count (Number of obsolete genes)',
    'sum(ts.genes_revised)'          => 'Revised Count (Number of revised genes)',
    'sum(ts.fused_genes)'            => 'Fused Count (Number of fused genes)',
    'sum(ts.fusion_components)'      => 'Fusion Component Count (Number of genes involved as fusion components)',
    'sum(ts.genes_in_sp)'            => 'SwissProt Count (Number of genes in SwissProt protein product)',
    'sum(ts.genes_not_in_sp)'        => 'Not SwissProt Count (Number of genes not in SwissProt protein product)',
    'sum(ts.genes_in_cog)'           => 'COG Count (Number of genes in COG)',
    'sum(ts.genes_in_kog)'           => 'KOG Count (Number of genes in KOG)',
    'sum(ts.genes_in_pfam)'          => 'Pfam Count (Number of genes in Pfam)',
    'sum(ts.genes_in_tigrfam)'       => 'TIGRfam Count (Number of genes in TIGRfam)',
    'sum(ts.genes_in_enzymes)'       => 'Enzyme Count (Number of genes assigned to enzymes)',
    'sum(ts.genes_in_tc)'            => 'TC Count (Number of genes assigned to Transporter Classification)',
    'sum(ts.genes_in_kegg)'          => 'KEGG Count (Number of genes in KEGG)',
    'sum(ts.genes_not_in_kegg)'      => 'Not KEGG Count (Number of genes not in KEGG)',
    'sum(ts.genes_in_ko)'            => 'KO Count (Number of genes in KEGG Orthology (KO))',
    'sum(ts.genes_not_in_ko)'        => 'Not KO Count (Number of genes not in KEGG Orthology (KO))',
    'sum(ts.genes_in_metacyc)'       => 'MetaCyc Count (Number of genes in MetaCyc)',
    'sum(ts.genes_not_in_metacyc)'   => 'Not MetaCyc Count (Number of genes not in MetaCyc)',
    'sum(ts.genes_in_img_terms)'     => 'IMG Term Count (Number of genes with IMG terms)',
    'sum(ts.genes_in_img_pways)'     => 'IMG Pathwawy Count (Number of genes in IMG pathwawys)',
    'sum(ts.genes_in_parts_list)'    => 'IMG Parts List Count (Number of genes in IMG parts list)',
    'sum(ts.genes_in_myimg)'         => 'MyIMG Annotation Count',
    'sum(ts.genes_signalp)'          => 'Signal Peptide Count (Number of genes coding signal peptides)',
    'sum(ts.genes_transmembrane)'    => 'Transmembrane Count (Number of genes coding transmembrane proteins)',
    'sum(ts.genes_hor_transfer)'     => 'Horizontally Transferred Count',
    'sum(ts.genes_in_genome_prop)'   => 'Genome Property Count (Number of genes in Genome Properties)',
    'sum(ts.ortholog_groups)'        => 'Ortholog Group Count',
    'sum(ts.paralog_groups)'         => 'Paralog Group Count',
    'sum(ts.cog_clusters)'           => 'COG Cluster Count (Number of COG clusters)',
    'sum(ts.kog_clusters)'           => 'KOG Cluster Count (Number of KOG clusters)',
    'sum(ts.pfam_clusters)'          => 'Pfam Cluster Count (Number of Pfam clusters)',
    'sum(ts.tigrfam_clusters)'       => 'TIGRfam Cluster Count (Number of TIGRfam clusters)',
    'sum(ts.genes_in_img_clusters)'  => 'IMG Cluster Count',
    'sum(ts.genes_in_cassettes)'     => 'Chromosomal Cassette Gene Count',
    'sum(ts.total_cassettes)'        => 'Chromosomal Cassette Count',
    'sum(ts.genes_in_biosynthetic)'  => 'Biosynthetic Cluster Gene Count',
    'sum(ts.total_biosynthetic)'     => 'Biosynthetic Cluster Count',
);

# merfs phylum
my %phylumStatsColumnsMerfs = (
    'sum(ts.n_scaffolds)'           => 'Scaffold Count (Number of scaffolds)',
    'sum(ts.crispr_count)'          => 'CRISPR Count (Number of CRISPRs)',
    'sum(ts.total_gc)'              => 'GC Count (Number of GC)',
    'sum(ts.total_bases)'           => 'Genome Size (Number of total bases)',
    'sum(ts.total_gene_count)'      => 'Gene Count (Number of total Genes)',
    'sum(ts.cds_genes)'             => 'CDS Count (Number of CDS genes)',
    'sum(ts.rna_genes)'             => 'RNA Count (Number of RNA genes)',
    'sum(ts.rrna_genes)'            => 'rRNA Count (Number of rRNA genes)',
    'sum(ts.rrna5s_genes)'          => '5S rRNA Count (Number of 5S rRNAs)',
    'sum(ts.rrna16s_genes)'         => '16S rRNA Count (Number of 16S rRNAs)',
    'sum(ts.rrna18s_genes)'         => '18S rRNA Count (Number of 18S rRNAs)',
    'sum(ts.rrna23s_genes)'         => '23S rRNA Count (Number of 23S rRNAs)',
    'sum(ts.rrna28s_genes)'         => '28S rRNA Count (Number of 28S rRNAs)',
    'sum(ts.trna_genes)'            => 'tRNA Count (Number of tRNA genes)',
    'sum(ts.other_rna_genes)'       => 'Other RNA Count (Number of other unclassified RNA genes)',
    'sum(ts.genes_w_func_pred)'     => 'w/ Func Pred Count (Number of genes with predicted protein product)',
    $phylum_gene_wo_func_pred       => 'w/o function prediction',
    'sum(ts.genes_in_cog)'          => 'COG Count (Number of genes in COG)',
    'sum(ts.genes_in_pfam)'         => 'Pfam Count (Number of genes in Pfam)',
    'sum(ts.genes_in_tigrfam)'      => 'TIGRfam Count (Number of genes in TIGRfam)',
    'sum(ts.genes_in_enzymes)'      => 'Enzyme Count (Number of genes assigned to enzymes)',
    'sum(ts.genes_in_kegg)'         => 'KEGG Count (Number of genes in KEGG)',
    'sum(ts.genes_not_in_kegg)'     => 'Not KEGG Count (Number of genes not in KEGG)',
    'sum(ts.genes_in_ko)'           => 'KO Count (Number of genes in KEGG Orthology (KO))',
    'sum(ts.genes_not_in_ko)'       => 'Not KO Count (Number of genes not in KEGG Orthology (KO))',
    'sum(ts.genes_in_metacyc)'      => 'MetaCyc Count (Number of genes in MetaCyc)',
    'sum(ts.genes_not_in_metacyc)'  => 'Not MetaCyc Count (Number of genes not in MetaCyc)',
    'sum(ts.cog_clusters)'          => 'COG Cluster Count (Number of COG clusters)',
    'sum(ts.pfam_clusters)'         => 'Pfam Cluster Count (Number of Pfam clusters)',
    'sum(ts.tigrfam_clusters)'      => 'TIGRfam Cluster Count (Number of TIGRfam clusters)',
    'sum(ts.genes_in_biosynthetic)' => 'Biosynthetic Cluster Gene Count',
    'sum(ts.total_biosynthetic)'    => 'Biosynthetic Cluster Count',
);

my $select_id_name = 'taxon_filter_oid';

# ======================================================================================================
#
# end of configuration
#
# ======================================================================================================

sub dispatch {
    my $page = param('page');

    if ( $page eq 'genomeList' ) {

        # redisplay
        my $from = param('from');
        param( -name => 'from', -value => 'orgsearch2' ) if ( $from eq 'orgsearch' );
        printRedisplay();

    } elsif ( $page eq 'phylumList' ) {
        printPhylumList2();

    } elsif ( $page eq 'phylumGenomeList' ) {
        printPhylumGenomeList();

    } elsif ( $page eq 'phylumCartList' ) {

        # genome cart group by phyla
        printCartPhylumList();

    } elsif ( $page eq 'phylumCartGenomeList' ) {

        # genome cart group by phyla
        printCartPhylumGenomeList();

    } else {

        #  test
        #        my $dbh = WebUtil::dbLogin();
        #        printGenomes( $dbh, 'Genome Browser', "and t.domain = '*Microbiome' and rownum < 25" );
        #        $dbh->disconnect();

    }
}

# clear any genome cache files
# - used for "add to genome cart" button we need to remove the filename params:
# - used for remove from genome cart
#
#
sub clearCache {
    webLog("clearing add to genome cart cache\n");

    my $genomeData_filename      = param('genomeData');
    my $sampleMetadata_filename  = param('sampleMetadata');
    my $projectMetadata_filename = param('projectMetadata');
    my $filename                 = param('genomeListFilename');

    if ( -e "$cgi_tmp_dir/$filename" ) {
        wunlink("$cgi_tmp_dir/$filename");
    }

    if ( -e "$cgi_tmp_dir/$genomeData_filename" ) {
        wunlink("$cgi_tmp_dir/$genomeData_filename");
    }

    if ( -e "$cgi_tmp_dir/$sampleMetadata_filename" ) {
        wunlink("$cgi_tmp_dir/$sampleMetadata_filename");
    }

    if ( -e "$cgi_tmp_dir/$projectMetadata_filename" ) {
        wunlink("$cgi_tmp_dir/$projectMetadata_filename");
    }
}

#
# user presses redisplay button
#
sub printRedisplay {
    my $title    = param('title');
    my $note     = param('note');
    my $filename = param('genomeListFilename');
    my $from     = param('from');

    if ($user_restricted_site) {
        my $genomeListColPrefs = getSessionParam("genomeListColPrefs");

        if ( $genomeListColPrefs eq 'Yes' ) {

            # save columns
            require Workspace;

            my @taxonColumns           = param('genome_field_col');
            my @projectMetadataColumns = param('metadata_col');
           
            my @statsColumns           = param('stats_col');

            #my %allCols;
            my %h = WebUtil::array2Hash(@taxonColumns);
            Workspace::saveUserPreferences( \%h, $myTaxonPrefs );

            %h = WebUtil::array2Hash(@projectMetadataColumns);
            Workspace::saveUserPreferences( \%h, $myProjectPrefs );

            %h = WebUtil::array2Hash(@statsColumns);
            Workspace::saveUserPreferences( \%h, $myTaxonStatsPrefs );
        }
    }

    my @taxon_oids = getTaxonsFromGenomeListFile($filename);
    if ( $from eq 'genomeCart' ) {

        # genome cart redisplay
        require GenomeCart;
        print "<h1>Genome Cart</h1>\n";
        printMainForm();
        GenomeCart::printCartJS();
        GenomeCart::printCartTab1Start();
        printGenomesViaList( \@taxon_oids, '', $title, $filename, $from, $note );
        GenomeCart::printCartTab1End();
        my $count = $#taxon_oids + 1;
        GenomeCart::printCartTab2($count);
        TabHTML::printTabDivEnd();
        print end_form();
    } else {
        printGenomesViaList( \@taxon_oids, '', $title, $filename, $from, $note );
    }
}

sub getTaxonsFromGenomeListFile {
    my ( $filename ) = @_;

    my $genomeListFilename = "$cgi_tmp_dir/$filename";
    #print "getTaxonsFromGenomeListFile() genomeListFilename=$genomeListFilename<br/>\n";
    if ( !-e $genomeListFilename ) {
        webError('Your session has expired.');
    }
    my $rfh = newReadFileHandle($genomeListFilename);
    my @taxon_oids;
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        push( @taxon_oids, $line );
    }
    close $rfh;

    return @taxon_oids;
}


################################################################
# print genomes from "quick search" tool
#
# $taxonOids_aref - list of taxon oids with found term
# $title - page title - optional
# $searchTerm - user's search term - what we will hightlight green
# $selectedCols_aref - database table's columns the term was found in
################################################################
sub printQuickSearchGenomes {
    my ( $taxonOids_aref, $title, $searchTerm, $selectedCols_aref ) = @_;
    my $page        = param("page");
    my $count       = scalar(@$taxonOids_aref);
    my $txTableName = "genomelist";

    print "<h1>$title</h1>\n" if ($title);
    TaxonSearchUtil::printNotes();

    my @selectedCols = ();
    if ( $selectedCols_aref ne "" ) {
        foreach my $c (@$selectedCols_aref) {

            # assuming that searchTerm is only search against genome fields
            if($c eq "to_char(t.add_date, 'yyyy-mm-dd')") {
                push( @selectedCols,  $c );
            } else {
                push( @selectedCols, 't.' . $c );
            }
        }
    }

    # prints genome list table as well as config table
    my $from = 'orgsearch';
    printGenomesViaList( $taxonOids_aref, \@selectedCols, '', '', $from );
    print hiddenVar( 'from',      $from );
    print hiddenVar( 'taxonTerm', $searchTerm );

    return;
}

################################################################
# Call to display genomes via sql
#
# $dbh - optional
# $sql - query to get the genome_oid - sub query do not use t alias
# $title - title of the page - default is Genome Browser if not from genomeCart
# $bindList_aref - bind list - optional
# $from - from which page eg genomeCart - optional
################################################################
sub printGenomesViaSql {
    my ( $dbh, $sql, $title, $bindList_aref, $from, $note ) = @_;

    $dbh = WebUtil::dbLogin() if ( $dbh eq '' );

    # get taxon oids
    my $str = "and t.taxon_oid in ($sql) ";
    printGenomes( $dbh, $title, $str, '', '', $bindList_aref, $from, $note );
}

# Call to display genomes via array list of taxon oids
#
# $list_aref - array ref list of genome oids
# $title - title of the page - default is Genome Browser if not from genomeCart
# $filename - genome list filename  - used by the cache redisplay - optional
# $from - from which page eg genomeCart - optional
sub printGenomesViaList {
    my ( $list_aref, $foundColumns_aref, $title, $filename, $from, $note ) = @_;

    if ( $#$list_aref < 0 ) {
        webError("Genomes list has zero size");
    }

    # - save the oids or sql as a session for re-display
    my $dbh      = WebUtil::dbLogin();
    my $list_str = OracleUtil::getNumberIdsInClause( $dbh, @$list_aref );
    my $str      = "and t.taxon_oid in ($list_str) ";

    OracleUtil::execDbmsStats( $dbh, 'img_core_v400', 'gtt_num_id' );

    printGenomes( $dbh, $title, $str, $foundColumns_aref, $filename, '', $from, $note );

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $list_str =~ /gtt_num_id/i );
}

sub hashKeyToArray {
    my ($href) = @_;
    my @a;
    foreach my $key ( sort keys %$href ) {
        push( @a, $key );
    }

    return @a;
}

# print genome list section
# you should not call this use instead printGenomesViaList or printGenomesViaSql methods
#
# $dbh
# $title - title of the page - default is Genome Browser if not from genomeCart
# $sql_clause - clause on which taxon oids to get
# $foundColumns_aref - columns in which search term is found - optional
# (used only by printQuickSearchGenomes)
# $filename - cached file of taxon oids for redisplay - optional
# $bindList_aref - bind list - optional
# $from - from which page, eg genomeCart
# $note - optional html blob
sub printGenomes {
    my ( $dbh, $title, $sql_clause, $foundColumns_aref, $filename, $bindList_aref, $from, $note ) = @_;

    if ( $title eq '' ) {
        if ( $from eq 'genomeCart' || $from eq 'orgsearch' ) {

            # printed outside this subroutine
        } elsif ( $from eq 'orgsearch2' ) {

            # redisplay
            $title = 'All Fields Genome Search Results';
        } else {
            $title = 'Genome Browser';
        }
    }
    print "<h1>$title</h1>\n" if $title ne '';
    print $note;
    TaxonSearchUtil::printNotes() if ( $from eq 'orgsearch2' );

    printStatusLine( "Loading ...", 1 );

    if ( $from eq 'genomeCart' ) {

        # no form here
    } else {
        printMainForm();
    }

    # TODO - pre check those in genome cart ???

    my @taxonColumns           = param('genome_field_col');
    my @projectMetadataColumns = param('metadata_col');

    my @statsColumns           = param('stats_col');

    #  save and load user preferred columns
    if ($user_restricted_site) {
        my $genomeListColPrefs = getSessionParam("genomeListColPrefs");

        if ( $genomeListColPrefs eq 'Yes' ) {
            require Workspace;
            my $href = Workspace::loadUserPreferences($myTaxonPrefs);
            my @a    = hashKeyToArray($href);
            @taxonColumns = @a;

            $href                   = Workspace::loadUserPreferences($myProjectPrefs);
            @a                      = hashKeyToArray($href);
            @projectMetadataColumns = @a;


            $href         = Workspace::loadUserPreferences($myTaxonStatsPrefs);
            @a            = hashKeyToArray($href);
            @statsColumns = @a;
        }
    }

    # columns always displayed
    # - I need to put this since its disabled in ui and its not on param
    my @defaults = ( 't.domain', 't.seq_status', 't.proposal_name', 't.taxon_display_name', 't.seq_center' );
    push( @defaults, @taxonColumns );

    # additional columns where search term is found
    # (only used in printQuickSearchGenomes)
    if ( $foundColumns_aref ne "" ) {
        foreach my $c (@$foundColumns_aref) {

            # assuming that searchTerm is only search against genome fields
            #my $colName = 't.' . $c;
            # ignore because this column is already in @defaults
            next if ( grep { $_ eq $c } (@defaults) );
            push( @defaults, $c );
        }
    }

    @taxonColumns = @defaults;
    @defaults = ( 'ts.total_bases', 'ts.total_gene_count' );
    push( @defaults, @statsColumns );
    @statsColumns = @defaults;

    my @taxonColumns2 = ( @taxonColumns, @statsColumns );

    ### hash of hashes
    # $taxon_data_href    taxon oid     => hash columns name to value
    # $goldId_href        gold id       => hash of taxon_oid
    # $taxon_public_href  taxon_oid => Yes or No
    my ( $taxon_data_href, $goldId_href, $taxon_public_href ) =
      getTaxonTableData( $dbh, $sql_clause, \@taxonColumns2, $bindList_aref );

    # get metadata
    webLog("try to connect to gold db\n");
    #my $dbh_gold = WebUtil::dbGoldLogin();
    webLog("done connect to gold db\n");
    if ( $#projectMetadataColumns > -1 ) {
        getProjectMetadata($taxon_data_href, $goldId_href  );
    }


    # get combined samples
    my $combinedSamples_href;    # = getCombinedSamples($dbh_gold);

    #$dbh_gold->disconnect();

    if ( $from eq 'genomeCart' ) {

        # do not print button
    } else {
        TaxonSearchUtil::printButtonFooter("taxontable");
        print nbsp(1);
    }
    printTreeButton($from);

    printTaxonList( \@taxonColumns, \@projectMetadataColumns, \@statsColumns, $taxon_data_href,
        $combinedSamples_href, $taxon_public_href );

    my $count = keys %$taxon_data_href;

    if ( $from eq 'genomeCart' || $count < 10 ) {

        # do not print button
    } else {
        TaxonSearchUtil::printButtonFooter("taxontable");
        print nbsp(1);
    }
    printTreeButton($from);

    print "<h2>Table Configuration</h2>";
    my $name = "_section_${section}_genomeList";
    print submit(
        -id    => "moreGo",
        -name  => $name,
        -value => "Display Genomes Again",
        -class => "meddefbutton"
    );

    printConfigDiv( \@taxonColumns, \@projectMetadataColumns,  \@statsColumns );

    print submit(
        -id    => "moreGo",
        -name  => $name,
        -value => "Display Genomes Again",
        -class => "meddefbutton"
    );

    # save taxon oids as a file for redisplay
    #
    # findGenomeResultsRedisplay - bug fix since the filename is ina subdirectory
    #
    if ( $filename eq '' || $from eq 'findGenomeResultsRedisplay' ) {
        my $session_id = getSessionId();
        my $process_id = $$;
        $filename = 'genomelist' . $process_id . '_' . $session_id;
        my $wfh = newWriteFileHandle("$cgi_tmp_dir/$filename");
        foreach my $taxon_oid ( keys %$taxon_data_href ) {
            print $wfh "$taxon_oid\n";
        }
        close $wfh;
    } else {
        WebUtil::fileTouch($filename);
    }

    print hiddenVar( 'page',               'genomeList' );
    print hiddenVar( 'section',            $section );
    print hiddenVar( 'genomeListFilename', $filename );
    print hiddenVar( 'title',              $title );
    print hiddenVar( 'note',               $note );
    print hiddenVar( 'taxonTerm',          param("taxonTerm") );
    if ( $from eq 'findGenomeResultsRedisplay' ) {
        print hiddenVar( 'from', '' );
    } else {
        print hiddenVar( 'from', $from );
    }

    if ( $from eq 'genomeCart' ) {
    } else {
        #WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
        WorkspaceUtil::printSaveGenomeToWorkspace_withAllBrowserGenomeList($select_id_name);            
        print end_form();
    }

    printStatusLine( "$count Loaded", 2 );
}

#
# prints genome list inner table
#
# $taxonColumns_aref - user's selected taxon columns

# $sampleMetadataColumns_aref - user's selected sample col
# $statsColumns_aref - user's selected stats col
# $taxon_data_href - genomes data from db
#
# $taxon_public_href - is genome public
sub printTaxonList {
    my ( $taxonColumns_aref, $projectMetadataColumns_aref, $statsColumns_aref, $taxon_data_href,
        $combinedSamples_href, $taxon_public_href )
      = @_;

    my $txTableName = "taxontable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd          = $it->getSdDelim();                                        # sort delimiter

    # columns headers
    $it->addColSpec("Select");
    if ( $#$taxonColumns_aref > -1 ) {
        printTaxonListColumnHeader( $it, $taxonColumns_aref, \%genomeColumns, \%genomeColumnsAlign );
    }
    if ( $#$projectMetadataColumns_aref > -1 ) {
        printTaxonListColumnHeader( $it, $projectMetadataColumns_aref, \%projectMetadataColumns,
            \%projectMetadataColumnsAlign );
    }


    if ( $#$statsColumns_aref > -1 ) {
        printTaxonListColumnHeader( $it, $statsColumns_aref, \%statsColumns, \%statsColumnsAlign );
    }

    my $searchTerm = param('taxonTerm');
    my $termLen    = length($searchTerm);

    #my $rownum = 0;
    foreach my $taxon_oid ( keys %$taxon_data_href ) {
        my $sub_href       = $taxon_data_href->{$taxon_oid};
        my $submissionId   = $sub_href->{submissionId};
        my $domain         = $sub_href->{'t.domain'};
        my $checked        = "";
        my $combinedSample = 0;

        #$combinedSample = 1 if(exists $combinedSamples_href->{$submissionId});

        my $row = $sd . "<input type='checkbox' name=$select_id_name " . " value='$taxon_oid' $checked />\t";

        foreach my $col (@$taxonColumns_aref) {
            my $value = $sub_href->{$col};
            $value = cellValueEscape($value);

            # highlighting
            my $valueHighlighted = $value;
            if ( $searchTerm ne "" ) {
                my $substrStart;
                my $substrLen;
                my @startIndices = ();

                # while and 'g' (global) are both needed
                push( @startIndices, $-[0] ) while ( $value =~ /\Q$searchTerm\E/ig );
                if ( scalar(@startIndices) ne 0 ) {
                    $substrStart      = 0;
                    $substrLen        = $startIndices[0];
                    $valueHighlighted = substr( $value, $substrStart, $substrLen );

                    for my $i ( 0 .. $#startIndices ) {
                        $substrStart = $startIndices[$i];
                        $substrLen   = $termLen;
                        $valueHighlighted .=
                          "<font color='green'><b>" . substr( $value, $substrStart, $substrLen ) . "</b></font>";

                        if ( $startIndices[ $i + 1 ] ) {
                            $substrStart = $startIndices[$i] + $termLen;
                            $substrLen   = $startIndices[ $i + 1 ] - $startIndices[$i] - $termLen;
                            $valueHighlighted .= substr( $value, $substrStart, $substrLen );

                        } else {
                            $substrStart = $startIndices[$i] + $termLen;
                            $valueHighlighted .= substr( $value, $substrStart );

                            # length not specified, meaning the substring
                            # goes to the end of the whole string

                        }
                    }
                }
            }
            if ( $col eq 't.submission_id' ) {
                if ( $domain eq '*Microbiome' ) {
                    $columnAsUrl{$col} = $img_mer_submit_url;
                } else {
                    $columnAsUrl{$col} = $img_er_submit_url;
                }
            }

            if ( $col eq 't.domain' || $col eq 't.seq_status' ) {
                $row .= $value . $sd . substr( $value, 0, 1 ) . "\t";
            } elsif (
                $col eq 't.seq_center'
                && (   $value =~ /(DOE Joint Genome Institute)/
                    || $value =~ /(JGI)/
                    || $value =~ /(DOE)/ )
              )
            {
                my $match  = $1;
                my $match2 = "";

                if ( $searchTerm ne '' && lc($match) eq lc($searchTerm) ) {
                    $match2 .= '<font color="green"><b>' . $match . "</b></font>";

                } elsif ( $searchTerm ne '' && $match =~ /$searchTerm/ig ) {
                    my @match_split = split /$searchTerm/i, $match;

                    if ( scalar(@match_split) eq 1 ) {
                        $match2 .= "<font color='red'>" . $match_split[0] . "</font>";
                        $match2 .= "<font color='green'><b>" . substr( $match, length( $match_split[0] ) ) . "</b></font>";

                    } else {
                        my $termPreserveCase = substr( $match, length( $match_split[0] ), $termLen );
                        $termPreserveCase = "<font color='green'><b>" . $termPreserveCase . "</b></font>";

                        foreach my $s (@match_split) {
                            $match2 .= $termPreserveCase if ( $match2 ne "" );
                            $match2 .= "<font color='red'>" . $s . "</font>";
                        }

                    }

                } else {
                    $match2 = "<font color='red'> $match </font>";
                }

                my $colVal2 = $value;
                $colVal2 =~ s/$match/$match2/;
                $row .= $value . $sd . $colVal2 . "\t";

                #if ($rownum < 10) {
                #    print "printTaxonList() searchTerm=$searchTerm; match=$match; match2=$match2;<br/>\n";
                #    print "printTaxonList() value=$value; colVal2=$colVal2<br/>\n";
                #}

            } elsif ( $value eq '' || blankStr($value) ) {
                my $tmp = $genomeColumnsAlign{$col};
                if ( $tmp =~ /^char/ ) {
                    $row .= 'zzz' . $sd . '_' . "\t";
                } else {
                    $row .= '0' . $sd . '_' . "\t";
                }
            } elsif ( exists $columnAsUrl{$col} && $col eq 't.analysis_project_id' ) {
                my $url = HtmlUtil::getGoldUrl($value);
                $url = "<a href='$url'>$valueHighlighted</a>";
                $row .= $value . $sd . $url . "\t";
            } elsif ( exists $columnAsUrl{$col} && ( $col eq 't.study_gold_id' || $col eq 't.sequencing_gold_id' ) ) {

                # Gs or Gp
                my $url = HtmlUtil::getGoldUrl($value);
                $url = "<a href='$url'>$valueHighlighted</a>";
                $row .= $value . $sd . $url . "\t";

            } elsif ( exists $columnAsUrl{$col} ) {
                my $url = $columnAsUrl{$col} . $value;
                if ( $col eq 't.taxon_display_name' ) {
                    $url = $columnAsUrl{$col} . $taxon_oid;
                }

                # DO NOT use alink here because html escape
                # will interfere with the font tags
                $url = "<a href='$url'>$valueHighlighted</a>";
                $row .= $value . $sd . $url . "\t";

            } else {
                $row .= $value . $sd . $valueHighlighted . "\t";
            }
        }

        # project
        foreach my $col (@$projectMetadataColumns_aref) {
            my $value = $sub_href->{$col};
            $value = cellValueEscape($value);
            if ( $value eq '' || blankStr($value) ) {
                my $tmp = $projectMetadataColumnsAlign{$col};
                
                if ($tmp eq ''  || $tmp =~ /^char/ ) {
                    $row .= 'zzz' . $sd . '_' . "\t";
                } else {
                    $row .= '0' . $sd . '_' . "\t";
                }

            } elsif ( exists $columnAsUrl{$col} ) {
                my $url = $columnAsUrl{$col} . $value;
                $url = alink( $url, $value );
                $row .= $value . $sd . $url . "\t";
            } else {
                $row .= $value . $sd . $value . "\t";
            }
        }

        # stats
        foreach my $col (@$statsColumns_aref) {
            my $value = $sub_href->{$col};
            $value = cellValueEscape($value);

            if ( $value eq '' || blankStr($value) ) {
                $row .= '0' . $sd . '_' . "\t";
            } elsif ( exists $columnAsUrl{$col} ) {
                my $url = $columnAsUrl{$col} . $value;
                if ( $col eq 'ts.total_biosynthetic' ) {
                    $url = $columnAsUrl{$col} . $taxon_oid;
                }
                $url = alink( $url, $value );
                $row .= $value . $sd . $url . "\t";

            } else {
                $row .= $value . $sd . $value . "\t";
            }

        }
        $it->addRow($row);

        #$rownum++;
    }

    $it->printOuterTable(1);
}

sub cellValueEscape {
    my ($value) = @_;

    if (   $value eq '\r'
        || $value eq '\t'
        || $value eq '\n' )
    {
        $value = '&nbsp;';

    } else {

        if ( $value =~ /\r/ ) {
            $value =~ s/\r//g;
        }
        if ( $value =~ /\t/ ) {
            $value =~ s/\t//g;
        }
        if ( $value =~ /\n/ ) {
            $value =~ s/\n//g;
        }

    }

    return $value

}

# printTaxonList helper function to print table column headers
sub printTaxonListColumnHeader {
    my ( $it, $aref, $colLable_href, $sortAlign_href ) = @_;

    foreach my $key (@$aref) {
        my $value = $colLable_href->{$key};
        my $title;

        # for the stats column table header do not print the text with ( )
        my $i = index( $value, '(' );
        if ( $i > -1 ) {
            $title = $value;
            $value = substr( $value, 0, $i );
        }
        my $str = $sortAlign_href->{$key};
        if ( $str ne '' ) {
            my @a = split( /\s+/, $str );
            $it->addColSpec( $value, "$a[0] $a[1]", $a[2], '', $title );
        } else {

            # 'num asc right'
            $it->addColSpec( $value, 'num asc', 'right', '', $title );
        }
    }

}

# get all the combined samples
sub getCombinedSamples {
    my ($dbh) = @_;

    # hash of hashes
    # submission_id => sample_oid => sample_oid
    my %data;
    if ( !$include_metagenomes ) {
        return \%data;
    }

    my $sql = qq{
select ss1.submission_id, ss1.sample_oid
from submission_samples ss1
where ss1.submission_id in (
    select ss.submission_id
    from submission_samples ss
    group by ss.submission_id
    having count(*) > 1
)    
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $submission_id, $sample_oid ) = $cur->fetchrow();
        last if !$submission_id;
        if ( exists $data{$submission_id} ) {
            my $href = $data{$submission_id};
            $href->{$sample_oid} = $sample_oid;
        } else {
            my %tmp = ( $sample_oid => $sample_oid );
            $data{$submission_id} = \%tmp;
        }
    }

    print "<p>";
    print Dumper \%data;
    print "<p>";

    return \%data;
}

#
# Gets private genomes list of user who have access
#
sub getUsernameAccess {
    my ( $dbh, $taxon_data_href ) = @_;

    #my @oids    = keys %$taxon_data_href;
    #my $oid_str = OracleUtil::getTaxonIdsInClause( $dbh, @oids );
    #my $tclause = "and tx.taxon_oid in ($oid_str)";

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $clause;
    if ( $super_user ne "Yes" ) {
        my $str = qq{
        and tx.taxon_oid in (
          select ctp2.taxon_permissions
          from contact_taxon_permissions ctp2
          where ctp2.contact_oid = $contact_oid
        )
        };

        $clause = $str;    #"and ctp.contact_oid = '$contact_oid'";
    }

    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select distinct tx.taxon_oid, c.username
        from taxon tx, contact_taxon_permissions ctp, contact c
        where tx.taxon_oid = ctp.taxon_permissions
        and ctp.contact_oid = c.contact_oid
        and tx.is_public = 'No'
        $clause
        $imgClause
        order by c.username
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $username ) = $cur->fetchrow();
        last if !$taxon_oid;

        next if ( !exists $taxon_data_href->{$taxon_oid} );

        my $key      = 'c.username';
        my $sub_href = $taxon_data_href->{$taxon_oid};
        if ( exists $sub_href->{$key} ) {
            next if ( $sub_href->{$key} =~ /\Q$username\E/ );
            $sub_href->{$key} = $sub_href->{$key} . ", $username";
        } else {
            $sub_href->{$key} = $username;
        }
    }
    $cur->finish();

    #    OracleUtil::truncTable( $dbh, "gtt_taxon_oid" )
    #      if ( $oid_str =~ /gtt_taxon_oid/i );
}

sub getSubmitter {
    my ( $dbh, $taxon_data_href ) = @_;
    my $sql = qq{
        select s.submission_id, nvl(c.name, s.contact_email)
        from submission s left join contact c on s.contact = c.contact_oid
        where s.img_taxon_oid is not null
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %submitters;
    for ( ; ; ) {
        my ( $submission_id, $name ) = $cur->fetchrow();
        last if ( !$submission_id );
        $submitters{$submission_id} = $name;
    }
    $cur->finish();

    # c.submittername
    foreach my $taxon_oid ( keys %$taxon_data_href ) {
        my $sub_href = $taxon_data_href->{$taxon_oid};
        my $sub_id   = $sub_href->{'t.submission_id'};
        if ( $sub_id ne '' ) {
            my $name = $submitters{$sub_id};
            if ( $name ne '' ) {
                $sub_href->{'c.submittername'} = $name;
            }
        }
    }
}


# get data from gap table
# replaces getGeneModelQc, getSubmissionType, getProjectType
# add assembly_method
sub getGapData {
    my ( $dbh, $taxon_data_href ) = @_;
    my $sql = qq{
select gap.gold_id, 
t.submission_id, 
nvl(gap.is_gene_primp, 'No'),
gap.submission_type, 
gap.gold_analysis_project_type,
gap.assembly_method 
from gold_analysis_project gap, taxon t
where gap.gold_id = t.analysis_project_id
and gap.gold_id is not null
and t.OBSOLETE_FLAG = 'No'
   };

    my $list_aref = OracleUtil::execSqlCached( $dbh, $sql, 'GenomeListgetGapData' . $urlTag );
    my %data;
    foreach my $inner_aref (@$list_aref) {
        my ( $gaId, $submission_id, $qc, $submission_type, $project_type, $assembly_method ) = @$inner_aref;
        my @a = ($submission_id, $qc, $submission_type, $project_type, $assembly_method);
        $data{$gaId} = \@a;
    }

    foreach my $taxon_oid ( keys %$taxon_data_href ) {
        my $sub_href = $taxon_data_href->{$taxon_oid};
        my $gaId     = $sub_href->{'t.analysis_project_id'};
        if ( $gaId ne '' ) {
            my $aref = $data{$gaId};
            my($submission_id, $qc, $submission_type, $project_type, $assembly_method) = @$aref;
            $sub_href->{'gap.is_gene_primp'} = $qc if ( $qc ne '' );
            $sub_href->{'gap.submission_type'} = $submission_type if ( $submission_type ne '' );
            $sub_href->{'gap.gold_analysis_project_type'} = $project_type if ( $project_type ne '' );
            $sub_href->{'gap.assembly_method'} = $assembly_method if ( $assembly_method ne '' );
        }
    }
    
}

#sub getGeneModelQc {
#    my ( $dbh, $taxon_data_href ) = @_;
#    my $sql = qq{
#select gap.gold_id, t.submission_id, nvl(gap.is_gene_primp, 'No')
#from gold_analysis_project gap, taxon t
#where gap.gold_id = t.analysis_project_id
#and gap.gold_id is not null
#   };
#
#    my $list_aref = OracleUtil::execSqlCached( $dbh, $sql, 'GenomeListgetGeneModelQc' . $urlTag );
#    my %data;
#    foreach my $inner_aref (@$list_aref) {
#        my ( $gaId, $submission_id, $qc ) = @$inner_aref;
#        $data{$gaId} = $qc;
#    }
#
#    foreach my $taxon_oid ( keys %$taxon_data_href ) {
#        my $sub_href = $taxon_data_href->{$taxon_oid};
#        my $gaId     = $sub_href->{'t.analysis_project_id'};
#        if ( $gaId ne '' ) {
#            my $name = $data{$gaId};
#            if ( $name ne '' ) {
#                $sub_href->{'gap.is_gene_primp'} = $name;
#            }
#        }
#    }
#}
#
#
#sub getSubmissionType {
#    my ( $dbh, $taxon_data_href ) = @_;
#    my $sql = qq{
#select gap.gold_id, t.submission_id, gap.submission_type, gap.gold_analysis_project_type
#from gold_analysis_project gap, taxon t
#where gap.gold_id = t.analysis_project_id
#and gap.gold_id is not null
#   };
#
#    my $list_aref = OracleUtil::execSqlCached( $dbh, $sql, 'GenomeListgetSubmissionType2' . $urlTag );
#    my %data;
#    foreach my $inner_aref (@$list_aref) {
#        my ( $gaId, $submission_id, $submission_type, $project_type ) = @$inner_aref;
#        $data{$gaId} = $submission_type;
#    }
#
#    foreach my $taxon_oid ( keys %$taxon_data_href ) {
#        my $sub_href = $taxon_data_href->{$taxon_oid};
#        my $gaId     = $sub_href->{'t.analysis_project_id'};
#        if ( $gaId ne '' ) {
#            my $name = $data{$gaId};
#            if ( $name ne '' ) {
#                $sub_href->{'gap.submission_type'} = $name;
#            }
#        }
#    }
#}
#
#sub getProjectType {
#    my ( $dbh, $taxon_data_href ) = @_;
#    my $sql = qq{
#select gap.gold_id, t.submission_id, gap.submission_type, gap.gold_analysis_project_type
#from gold_analysis_project gap, taxon t
#where gap.gold_id = t.analysis_project_id
#and gap.gold_id is not null
#    };
#
#    my $list_aref = OracleUtil::execSqlCached( $dbh, $sql, 'GenomeListgetSubmissionType2' . $urlTag );
#    my %data;
#    foreach my $inner_aref (@$list_aref) {
#        my ( $gaId, $submission_id, $submission_type, $project_type ) = @$inner_aref;
#        $data{$gaId} = $project_type;
#    }
#
#    foreach my $taxon_oid ( keys %$taxon_data_href ) {
#        my $sub_href = $taxon_data_href->{$taxon_oid};
#        my $gaId     = $sub_href->{'t.analysis_project_id'};
#
#        if ( $gaId ne '' ) {
#            my $name = $data{$gaId};
#            if ( $name ne '' ) {
#                $sub_href->{'gap.gold_analysis_project_type'} = $name;
#            }
#        }
#    }
#}

#
# metadata is in a sqlite file which is a flatten out Gp to all metadata available
# columns with multple data have already been comma separated - see ../preComputedData/ProjectMetadata3.pl
#
sub dbLoginProject {
    my $driver   = "SQLite";
    my $dsn      = "DBI:$driver:dbname=$database";
    my $userid   = "";
    my $password = "";
    my $dbh      = DBI->connect( $dsn, $userid, $password, { RaiseError => 1 } ) or die $DBI::errstr;  
    return $dbh;  
}

#
# gets all project metadata - cache data for each session - expires after 90min
#
sub getProjectMetadata {
    my ( $taxon_data_href, $goldId_href) = @_;
    
    my $gid2projectMetadata_href = getGid2ProjectMetadata( $goldId_href, \@projectMetadataColumnsOrder );

    foreach my $taxon_oid (keys %$taxon_data_href) {
        my $href = $taxon_data_href->{$taxon_oid};
        my $gold_id = $href->{gold_id};
        my $cols_aref = $gid2projectMetadata_href->{$gold_id};        
        #webLog("$gold_id ==== \n");        
        getProjectMetadataHelper( $taxon_data_href, $taxon_oid, \@projectMetadataColumnsOrder, $cols_aref );
    }
}

sub getGid2ProjectMetadata {
    my ( $goldId_href, $cols_aref, $col_val, $noNullVal ) = @_;

    my $columns = join( ',', @$cols_aref );
    my $sql = qq{
        select gold_id, $columns
        from project_info p
    };
    #where p.gold_id in ($str)  
    
    if ( $goldId_href ) {
        my @goldOids = keys %$goldId_href;
        if ( scalar( @goldOids ) > 0 ) {
            my $str = WebUtil::joinSqlQuoted( ',', @goldOids );
            $sql .= qq{
                where p.gold_id in ($str)                  
            };
        }
    }
    if ( $noNullVal && scalar(@$cols_aref) == 1 ) {
        my $col = $cols_aref->[0];
        if ( ! $goldId_href ) {
            $sql .= qq{
                where 
            };        
        }
        $sql .= qq{
            $col is not null            
        };
    }    
    if ( $col_val && scalar(@$cols_aref) == 1 ) {
        my $col = $cols_aref->[0];
        if ( ! $goldId_href ) {
            $sql .= qq{
                where 
            };        
        }
        $sql .= qq{
            $col = '$col_val'
        };
    }    
    #webLog("$sql\n");
    #print "getGid2ProjectMetadata() sql=$sql<br/>\n";
    
    my $dbh = dbLoginProject();
    my $cur = $dbh->prepare($sql);
    $cur->execute();

    my %gid2projectMetadata;
    for ( ; ; ) {
        my ( $gid, @cols ) = $cur->fetchrow_array();
        last if !$gid;
        $gid2projectMetadata{$gid} = \@cols;
    }
    $cur->finish();
    $dbh->disconnect();

    return (\%gid2projectMetadata);
}


sub getProjectMetadataHelper {
    my ( $taxon_data_href, $taxon_oid, $all_columns_aref, $cols_aref ) = @_;

    my $sub_href = $taxon_data_href->{$taxon_oid};

    for ( my $i = 0 ; $i <= $#$all_columns_aref ; $i++ ) {
        my $key   = $all_columns_aref->[$i];
        my $value = $cols_aref->[$i];
        next if ( blankStr($value) );
        if ( exists $sub_href->{$key} ) {
            #Unmatched ( in regex; marked by <-- HERE  fix
            next if ( $sub_href->{$key} =~ /\Q$value\E/ );
            $sub_href->{$key} = $sub_href->{$key} . ", $value";
        } else {
            $sub_href->{$key} = $value;
        }
    }

}

#
# get taxon data
#
#
# $taxonColumns_aref - user's selected columns
sub getTaxonTableData {
    my ( $dbh, $clause, $taxonColumns_aref, $bindList_aref ) = @_;

    my $filename = param('genomeData');
    if ( $filename eq '' ) {
        my $session_id = getSessionId();
        $filename = 'genomeData' . $$ . '_' . $session_id;
    }
    print qq{
<input type="hidden" name='genomeData' value='$filename' />        
    };

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @all_columns;

    # username exception
    foreach my $x (@genomeColumnsOrder) {
        push( @all_columns, $x )
          if ( $x ne 'c.username'
            && $x ne 'c.submittername'
            && $x ne 'gap.gold_analysis_project_type'
            && $x ne 'gap.submission_type' 
            && $x ne 'gap.is_gene_primp' 
            && $x ne 'gap.assembly_method');
    }
    push( @all_columns, @statsColumnsOrder );

    # get taxon data and taxon stats
    my $columns = join( ',', @all_columns );
    $columns = ", $columns" if ( $columns ne '' );

    my $sql = qq{
        select t.taxon_oid, t.sequencing_gold_id, t.is_public
        $columns
        from taxon t, taxon_stats ts
        where t.taxon_oid = ts.taxon_oid (+)
        $clause
        $rclause
        $imgClause
    };

    my %taxon_data;           # hash of hashes taxon oid => hash columns name to value
    my %goldId_data;          # gold id => hash of taxon_oid
    my %taxon_public_data;    # taxon_oid => Yes or No for is public

    if ( -e "$cgi_tmp_dir/$filename" && HtmlUtil::isCgiCacheEnable() ) {
        webLog("reading cache file $filename\n");

        #print "getTaxonTableData() taxon_data cache file=$cgi_tmp_dir/$filename<br/>\n";

        # read cache file and do not query
        my $rfh = newReadFileHandle("$cgi_tmp_dir/$filename");
        while ( my $line = $rfh->getline() ) {
            chomp $line;
            my ( $taxon_oid, $gold_id, $is_public, @cols ) = split( /\t/, $line );

            $taxon_public_data{$taxon_oid}         = $is_public;

            my %hash;
            $hash{gold_id} = $gold_id;

            for ( my $i = 0 ; $i <= $#all_columns ; $i++ ) {
                my $key   = $all_columns[$i];
                my $value = $cols[$i];
                $hash{$key} = $value;
            }
            $taxon_data{$taxon_oid} = \%hash;

            if ( $gold_id ne '' ) {
                if ( exists $goldId_data{$gold_id} ) {
                    my $href = $goldId_data{$gold_id};
                    $href->{$taxon_oid} = 1;
                } else {
                    my %h = ( $taxon_oid => 1 );
                    $goldId_data{$gold_id} = \%h;
                }
            }
        }
        close $rfh;

    } else {
        my $wfh = newWriteFileHandle("$cgi_tmp_dir/$filename");

        my $cur;
        if ( $bindList_aref eq '' ) {
            $cur = execSql( $dbh, $sql, $verbose );
        } else {
            $cur = execSql( $dbh, $sql, $verbose, @$bindList_aref );
        }
        for ( ; ; ) {
            my ( $taxon_oid, $gold_id, $is_public, @cols ) = $cur->fetchrow();
            last if !$taxon_oid;
            print $wfh "$taxon_oid\t$gold_id\t$is_public\t";
            my $i = 0;
            foreach my $x (@cols) {
                print $wfh "$x\t";
                $i++;
            }
            print $wfh "\n";

            $taxon_public_data{$taxon_oid}         = $is_public;

            my %hash;
            $hash{gold_id} = $gold_id;
            
            for ( my $i = 0 ; $i <= $#all_columns ; $i++ ) {
                my $key = $all_columns[$i];
                my $value = $cols[$i];
                $hash{$key} = $value;
            }
            $taxon_data{$taxon_oid} = \%hash;

            if ( $gold_id ne '' ) {
                if ( exists $goldId_data{$gold_id} ) {
                    my $href = $goldId_data{$gold_id};
                    $href->{$taxon_oid} = 1;
                } else {
                    my %h = ( $taxon_oid => 1 );
                    $goldId_data{$gold_id} = \%h;
                }
            }
        }
        close $wfh;
        $cur->finish();
    }

    if ($user_restricted_site) {

        # run only if user selects username
        my $done = 0;
        foreach my $x (@$taxonColumns_aref) {
            if ( $x eq 'c.username' ) {
                getUsernameAccess( $dbh, \%taxon_data );

                #last;
            } elsif ( $x eq 'c.submittername' ) {
                getSubmitter( $dbh, \%taxon_data );
            } elsif (!$done && $x eq 'gap.submission_type' ) {
                getGapData( $dbh, \%taxon_data );
                $done = 1;
            } elsif (!$done && $x eq 'gap.gold_analysis_project_type' ) {
                getGapData( $dbh, \%taxon_data );
                $done = 1;
            } elsif(!$done && ($x eq 'gap.is_gene_primp' || $x eq 'gap.assembly_method')) {
                getGapData($dbh, \%taxon_data);
                $done = 1;
            } 
        }
    } else {
        my $done = 0;
        foreach my $x (@$taxonColumns_aref) {
            if (!$done &&  $x eq 'gap.submission_type' ) {
                getGapData( $dbh, \%taxon_data );
                $done = 1;
            } elsif (!$done &&  $x eq 'gap.gold_analysis_project_type' ) {
                getGapData( $dbh, \%taxon_data );
                $done = 1;
            } elsif(!$done &&  ($x eq 'gap.is_gene_primp'|| $x eq 'gap.assembly_method')) {
                getGapData($dbh, \%taxon_data);
                $done = 1;
            }
        }
    }

    if ($include_metagenomes) {

        # get metagenome stats
        getMetagenomeStats( $dbh, \%taxon_data );
    }

    return ( \%taxon_data, \%goldId_data, \%taxon_public_data, );
}

#
# get metagenome stats from the new table
#
#select t.taxon_oid, ts.GENES_IN_COG, ts.DATATYPE
#from taxon t left join taxon_stats_merfs ts
#on t.taxon_oid = ts.taxon_oid
#and ts.DATATYPE = 'unassembled'
#--and ts.DATATYPE = 'assembled'
#where t.taxon_oid in (3300000547, 7000000203, 3300001621, 3300000332)
#
sub getMetagenomeStats {
    my ( $dbh, $taxon_data_href ) = @_;
    my $dataType = param('merfs_data_type');

    my $orderByClause  = '';
    my $dataTypeClause = "and ts.datatype = 'assembled' ";
    if ( $dataType eq 'unassembled' ) {
        $dataTypeClause = "and ts.datatype = 'unassembled' ";
    } elsif ( $dataType eq 'both' ) {
        $dataTypeClause = '';
        $orderByClause  = 'order by t.taxon_oid';
    }

    my @taxons   = keys %$taxon_data_href;
    my $taxonStr = OracleUtil::getTaxonIdsInClause( $dbh, @taxons );

    my @columns = keys %statsColumnsMerfs;
    my $colStr  = join( ',', @columns );

    my $sql = qq{
select t.taxon_oid, $colStr
from taxon t left join taxon_stats_merfs ts 
on t.taxon_oid = ts.taxon_oid
$dataTypeClause
where t.taxon_oid in ($taxonStr)
and t.genome_type = 'metagenome'
$orderByClause
    };

    my %data;    # taxon oid => col => value
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, @cols ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( exists $data{$taxon_oid} ) {
            my $href = $data{$taxon_oid};
            for ( my $i = 0 ; $i <= $#columns ; $i++ ) {
                my $name  = $columns[$i];
                my $value = $cols[$i];
                $value = 0 if ( $value eq '' );
                $href->{$name} = $href->{$name} + $value;
            }
        } else {
            my %h;
            for ( my $i = 0 ; $i <= $#columns ; $i++ ) {
                my $name  = $columns[$i];
                my $value = $cols[$i];
                $value = 0 if ( $value eq '' );
                $h{$name} = $value;
            }
            $data{$taxon_oid} = \%h;
        }
    }

    # update the master data hash
    foreach my $taxonOid ( keys %data ) {
        my $data_href     = $data{$taxonOid};
        my $taxon_subhref = $taxon_data_href->{$taxonOid};

        foreach my $col ( keys %$data_href ) {
            my $value = $data_href->{$col};
            $taxon_subhref->{$col} = $value;
        }
    }
}

#
# prints table column configuration section
#
sub printConfigDiv {
    my (
        $taxonColumnsChecked_aref,          $projectMetadataColumnsChecked_aref,
        $statsColumnsChecked_aref
      )
      = @_;

    my $fileTime = fileAtime($database);

    # Date format: ddd, mmm d yyyy hh:mm am/pm (LC_DATE locale format)
    $fileTime = Date::Format::time2str( "%b %e %Y", $fileTime );

    print qq{
        <div id='genomeConfiguration'>      
          <script type='text/javascript' src='$base_url/genomeConfig.js'></script>

          <table border='0'>
            <tr>
            <td>
              <span class='hand' id='plus_minus_span1' onclick="javascript:showFilter(1, '$base_url')">
                <img id='plus_minus1' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Genome Field
            </td>
            <td>
              <span class='hand' id='plus_minus_span2' onclick="javascript:showFilter(2, '$base_url')">
                <img id='plus_minus2' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Metadata (<i>Updated $fileTime</i>)
            </td>
    };


    print qq{
            <td style='width:550px;'>
              <span class='hand' id='plus_minus_span4' onclick="javascript:showFilter(4, '$base_url')">
                <img id='plus_minus4' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Data Statistics
            </td>
    };

    print "</tr><tr>";

    # "Genome Field Div"
    print qq{ 
            <td>
              <div id='genomeField' class='myborder'>
                <input type="button" value="All"   onclick="selectObject(1, 'genome_field_col')">
                <input type="button" value="Clear" onclick="selectObject(0, 'genome_field_col')">
                <br/>
    };

    # taxon attributes have a pre-defined sort order
    foreach my $key (@genomeColumnsOrder) {
        my $value = $genomeColumns{$key};
        my $str   = $alwaysChecked{$key};

        if ( $str eq '' ) {

            # checked to see if it was checked before
            $str = existsInArray( $key, $taxonColumnsChecked_aref );
        }
        print qq{
            <input type="checkbox" value="$key" name="genome_field_col" $str> $value <br/>
        };
    }
    print qq{
              </div>
            </td>

    };    # end of "Genome Field Div"

    # "Project Metadata Div"
    print qq{
            <td>
              <div id='projectMetadata' class='myborder'>
                <input type="button" value="All" onclick="selectObject(1, 'metadata_col')">
                <input type="button" value="Clear" onclick="selectObject(0, 'metadata_col')">
                <br/>
    };

    # sort by the label not the keys
    foreach my $key (@projectMetadataColumnsOrder) {
        my $value = $projectMetadataColumns{$key};
        my $str   = $alwaysChecked{$key};

        if ( $str eq '' ) {

            # checked to see if it was checked before
            $str = existsInArray( $key, $projectMetadataColumnsChecked_aref );
        }

        print qq{
            <input type="checkbox" value="$key" name="metadata_col" $str > $value <br/>
        };
    }

    print qq{
              </div>
            </td>
    };    # end of "Project Metadata Div"


    # "Data Statistics Div"
    print qq{
            <td>
              <div id='statistics' class='myborder' >
                <input type="button" value="All" onclick="selectCount(1);selectPercent(1);">
                <input type="button" value="Clear" onclick="selectCount(0);selectPercent(0);">
                <input type="button" value="Select Counts" onclick="selectCount(1)">
                <input type="button" value="Select Percentage" onclick="selectPercent(1)" >
    };

    if ($include_metagenomes) {
        my $dataType = param('merfs_data_type');
        my $chk1     = '';
        my $chk2     = '';
        my $chk3     = '';

        if ( $dataType eq 'unassembled' ) {
            $chk2 = 'selected';
        } elsif ( $dataType eq 'both' ) {
            $chk3 = 'selected';
        } else {
            $chk1 = 'selected';
        }

        print qq{
<select name="merfs_data_type" title='Applies only to metagenomes'>
            <option value="assembled" $chk1>* Assembled (Metagenomes)</option>
            <option value="unassembled" $chk2>* Unassembled</option>
             <option value="both" $chk3>* Both</option>
</select>
};
    }

    print qq{                
              <br/>
    };

    # stats have a pre-defined sort order
    foreach my $key (@statsColumnsOrder) {
        my $value = $statsColumns{$key};
        my $id    = 'count';
        $id = 'percent' if ( $value =~ /\%/ );
        my $str = $alwaysChecked{$key};

        if ( $str eq '' ) {

            # checked to see if it was checked before
            $str = existsInArray( $key, $statsColumnsChecked_aref );
        }

        my $star;
        if ( $include_metagenomes && exists $statsColumnsMerfs{$key} ) {
            $star = '*';
        }

        print qq{ 
          <input id='$id' type="checkbox" value="$key" name="stats_col" $str />$star $value <br/>
        };
    }

    print qq{
              </div>
            </td>
    };    # end of "Data Statistics Div"

    print qq{
          </tr>
        </table>
      </div>\n
    };

}

#
# helper method to find if the column was checked by the user before
#
sub existsInArray {
    my ( $x, $aref ) = @_;

    foreach my $y (@$aref) {
        if ( $x eq $y ) {
            return "checked";
        }
    }
    return "";
}

#
# for the genome list from the domain counts, home page,
# print button to view as a tree
#
sub printTreeButton {
    my ($from) = @_;
    return if ( $from eq 'genomeCart' );

    my $seq_status = param("seq_status");
    my $seq_center = param("seq_center");
    my $domain     = param("domain");

    return if ( $domain eq '' );

    my $url = "main.cgi?section=TreeFile&page=domain";
    $url .= "&seq_status=$seq_status" if ( $seq_status ne "" );
    $url .= "&seq_center=$seq_center" if ( $seq_center ne "" );
    if ( $domain eq "Bacteria" ) {
        $url .= "&domain=bacteria";
    } elsif ( $domain eq "Archaea" ) {
        $url .= "&domain=archaea";
    } elsif ( $domain eq "Eukaryota" ) {
        $url .= "&domain=eukaryota";
    } elsif ( $domain eq "*Microbiome" ) {
        $url .= "&domain=*Microbiome";
    } elsif ( $domain eq "Plasmids" ) {
        $url .= "&domain=plasmid";
    } elsif ( $domain eq "GFragment" ) {
        $url .= "&domain=GFragment";
    } elsif ( $domain eq "Viruses" ) {
        $url .= "&domain=viruses";
    } else {
        $url .= "&domain=all";
    }

    if ( $from ne 'printPhylumGenomeList' && $from ne 'printCartPhylumGenomeList' ) {
        print buttonUrl( $url, "View Phylogenetically", "medbutton" );
    }
    if ( $from eq 'TaxonList' && $domain ne 'all' ) {

        # print groupy by phyla button
        my $url2 = 'main.cgi?section=GenomeList&page=phylumList';
        if ( $domain eq "Bacteria" ) {
            $url2 .= "&domain=Bacteria";
        } elsif ( $domain eq "Archaea" ) {
            $url2 .= "&domain=Archaea";
        } elsif ( $domain eq "Eukaryota" ) {
            $url2 .= "&domain=Eukaryota";
        } elsif ( $domain eq "*Microbiome" ) {
            $url2 .= "&domain=*Microbiome";
        } elsif ( $domain eq "Plasmids" ) {
            $url2 .= "&domain=Plasmids";
        } elsif ( $domain eq "GFragment" ) {
            $url2 .= "&domain=GFragment";
        } elsif ( $domain eq "Viruses" ) {
            $url2 .= "&domain=Viruses";
        }
        print "&nbsp;";
        print buttonUrl( $url2, "Group by Phyla", "medbutton" );
    }

    print qq{
<input type="hidden" name='seq_status' value='$seq_status' />
    } if ( $seq_status ne '' );

    print qq{
<input type="hidden" name='seq_center' value='$seq_center' />
    } if ( $seq_center ne '' );

    print qq{
<input type="hidden" name='domain' value='$domain' />
    } if ( $domain ne '' );

}

# -------------------------------------------------------------------------------------
#
# phylum list
#
# -------------------------------------------------------------------------------------
sub printPhylumList2 {
    my $domain       = param("domain");
    my $phylum       = param("phylum");
    my $ir_class     = param("ir_class");
    my $ir_order     = param("ir_order");
    my $family       = param("family");
    my $genus        = param("genus");
    my $species      = param("species");
    my $type         = param('type');
    my @statsColumns = param('stats_col');
    @statsColumns = ( 'sum(ts.total_bases)', 'sum(ts.total_gene_count)', @statsColumns );
    $type = 'domain' if ( $type eq '' );

    print qq{
<h1>Genome Phylum List</h1>
<p>
$domain group by: $type
</p>
    };

    # button back to alpha list
    my $alpha_url = "main.cgi?section=TaxonList&page=taxonListAlpha";
    if ( $domain ne "all" ) {
        if ( $domain eq "Bacteria" ) {
            $alpha_url .= "&domain=Bacteria";
        } elsif ( $domain eq "Archaea" ) {
            $alpha_url .= "&domain=Archaea";
        } elsif ( $domain eq "eukaryota" ) {
            $alpha_url .= "&domain=Eukaryota";
        } elsif ( $domain eq "*Microbiome" ) {
            $alpha_url .= "&domain=*Microbiome";
        } elsif ( $domain eq "Plasmid" ) {
            $alpha_url .= "&domain=Plasmids";
        } elsif ( $domain eq "GFragment" ) {
            $alpha_url .= "&domain=GFragment";
        } elsif ( $domain eq "Viruses" ) {
            $alpha_url .= "&domain=Viruses";
        }
    }
    print buttonUrl( $alpha_url, "View Domain Alphabetically", "smbutton" );
    print "&nbsp;";

    my $url = "main.cgi?section=TreeFile&page=domain";
    if ( $domain eq "Bacteria" ) {
        $url .= "&domain=bacteria";
    } elsif ( $domain eq "Archaea" ) {
        $url .= "&domain=archaea";
    } elsif ( $domain eq "Eukaryota" ) {
        $url .= "&domain=eukaryota";
    } elsif ( $domain eq "*Microbiome" ) {
        $url .= "&domain=*Microbiome";
    } elsif ( $domain eq "Plasmids" ) {
        $url .= "&domain=plasmid";
    } elsif ( $domain eq "GFragment" ) {
        $url .= "&domain=GFragment";
    } elsif ( $domain eq "Viruses" ) {
        $url .= "&domain=viruses";
    } else {
        $url .= "&domain=all";
    }

    print buttonUrl( $url, "View Phylogenetically", "medbutton" );

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    print qq{
        <p>
        Group by: &nbsp;
        <select id="phylagroup" name="phylagroup" onchange="phylaGroup();">
        <option selected="selected" value="label">--- Select a Phylum ---</option>
        <option value="reset">Reset</option>
        <option value="phylum">Phylum</option>
        <option value="ir_class">Class</option>
        <option value="ir_order">Order</option>
        <option value="family">Family</option>
        <option value="genus">Genus</option>
        <option value="species">Species</option>
        </select>
        </p>
    };

    print <<EOF;
        <script language='javascript' type='text/javascript'>
        function phylaGroup() {
            var e =  document.mainForm.phylagroup;
            if(e.value == 'label') {
                return;
            }
            if(e.value == 'reset') {
                var url = "main.cgi?section=GenomeList&page=phylumList&domain=$domain";
                window.open( url, '_self' );
                return;
            }
            var url = "main.cgi?section=GenomeList&page=phylumList&domain=$domain&type=";
            url +=  e.value;
            window.open( url, '_self' );
        }
        </script>

EOF

    #
    my $count     = 0;
    my $dbh       = WebUtil::dbLogin();
    my $data_href = getPhylumData2($dbh);

    #print "<pre>\n";
    #print Dumper $data_href;
    #print "</pre>\n";

    my $txTableName = "phylumtable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    if ( $type ne '' ) {
        $it->addColSpec( $type, 'char asc', 'left' );
    } else {
        $it->addColSpec( 'Phyla', 'char asc', 'left' );
    }
    $it->addColSpec( 'Genomes Count', 'num asc', 'right' );
    if ( $#statsColumns > -1 ) {
        printTaxonListColumnHeader( $it, \@statsColumns, \%phylumStatsColumns, \%statsColumnsAlign );
    }

    foreach my $key ( sort keys %$data_href ) {
        my @phylaKeys = split( /\t/, $key );
        my $href      = $data_href->{$key};
        my $genomeCnt = $href->{'Genome Count'};

        # 0 - domain
        # 1 - phylum
        # 2 - ir_class
        # 3 - ir_order
        # 4 - family
        # 5 - genus
        # 6 - species
        my $text = $key;

        # $text =~ s/\t/ /;
        # remove the domain name from the phyla name
        my @tmp = split( /\t/, $text );
        $text = $tmp[$#tmp];

        my $phylum2;
        my $ir_class2;
        my $ir_order2;
        my $family2;
        my $genus2;
        my $species2;

        my $domain2  = $phylaKeys[0];
        my $nextType = 'phylum';
        if ( $type eq 'phylum' ) {
            $phylum2  = $phylaKeys[1];
            $nextType = 'ir_class';
        } elsif ( $type eq 'ir_class' ) {
            $ir_class2 = $phylaKeys[1];
            $nextType  = 'ir_order';
        } elsif ( $type eq 'ir_order' ) {
            $ir_order2 = $phylaKeys[1];
            $nextType  = 'family';
        } elsif ( $type eq 'family' ) {
            $family2  = $phylaKeys[1];
            $nextType = 'genus';
        } elsif ( $type eq 'genus' ) {
            $genus2   = $phylaKeys[1];
            $nextType = 'species';
        } elsif ( $type eq 'species' ) {
            $species2 = $phylaKeys[1];
        }

        my $url = $section_cgi . '&page=phylumList';
        $url .= "&domain=$domain2";
        $url .= "&type=$nextType" if ( $nextType ne '' );
        if ( $phylum2 ne '' ) {
            $url .= '&phylum=' . $phylum2;
        } elsif ( $phylum ne '' ) {
            $url .= '&phylum=' . $phylum;
        }
        if ( $ir_class2 ne '' ) {
            $url .= '&ir_class=' . $ir_class2;
        } elsif ( $ir_class ne '' ) {
            $url .= '&ir_class=' . $ir_class;
        }

        if ( $ir_order2 ne '' ) {
            $url .= '&ir_order=' . $ir_order2;
        } elsif ( $ir_order ne '' ) {
            $url .= '&ir_order=' . $ir_order;
        }
        if ( $family2 ne '' ) {
            $url .= '&family=' . $family2;
        } elsif ( $family ne '' ) {
            $url .= '&family=' . $family;
        }
        if ( $genus2 ne '' ) {
            $url .= '&genus=' . $genus2;
        } elsif ( $genus ne '' ) {
            $url .= '&genus=' . $genus;
        }
        if ( $species2 ne '' ) {
            $url .= '&species=' . $species2;
        } elsif ( $species ne '' ) {
            $url .= '&species=' . $species;
        }

        my $url2 = alink( $url, $text );
        if ( $type eq 'species' ) {
            $url2 = $text;
        }

        # phyla name
        my $row = $text . $sd . $url2 . "\t";

        # genome count column
        $url2 = $url;
        $url2 =~ s/phylumList/phylumGenomeList/;
        $url2 = alink( $url2, $genomeCnt );
        $row .= $genomeCnt . $sd . $url2 . "\t";

        foreach my $col (@statsColumns) {

            #my $displayName = $phylumStatsColumns{$col};
            my $value = $href->{$col};
            $row .= $value . $sd . $value . "\t";
        }
        $it->addRow($row);

        $count++;
    }

    $it->printOuterTable(1);

    print "<h2>Table Configuration</h2>";
    my $name = "_section_${section}_phylumList";
    print submit(
        -name  => $name,
        -value => "Redisplay",
        -class => "meddefbutton"
    );
    printConfigDiv2( \@statsColumns );
    print submit(
        -name  => $name,
        -value => "Redisplay ",
        -class => "meddefbutton"
    );

    print hiddenVar( 'page',     'phylumList' );
    print hiddenVar( 'section',  $section );
    print hiddenVar( 'domain',   $domain );
    print hiddenVar( 'phylum',   $phylum );
    print hiddenVar( 'ir_class', $ir_class );
    print hiddenVar( 'ir_order', $ir_order );
    print hiddenVar( 'family',   $family );
    print hiddenVar( 'genus',    $genus );
    print hiddenVar( 'species',  $species );
    print hiddenVar( 'type',     $type );
    print end_form();
    printStatusLine( "$count Loaded", 2 );
}

sub getPhylumData2 {
    my ($dbh)    = @_;
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");
    my $type     = param('type');
    $type = 'domain' if ( $type eq '' );

    my $merfs_data_type = param('merfs_data_type');
    $merfs_data_type = 'assembled' if ( $merfs_data_type eq '' );

    my @bind;
    my @all_columns;
    my $urclause  = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause('t');

    my $phylumClause;

    if ( $domain =~ "^Pla" ) {
        $phylumClause .= "and t.domain like 'Plasmid%'";
    } elsif ( $domain =~ "^GFr" ) {
        $phylumClause .= "and t.domain like 'GFragment%'";
    } elsif ( $domain =~ "^Vir" ) {
        $phylumClause .= "and t.domain like 'Vir%'";
    } else {
        $phylumClause .= "and t.domain = ? ";
        push( @bind, $domain );
    }

    #    if ( $domain ne '' ) {
    #        $phylumClause .= "and t.domain = ? ";
    #        push( @bind, $domain );
    #    }
    if ( $phylum ne '' ) {
        $phylumClause .= "and nvl(t.phylum, 'unclassified') = ? ";
        push( @bind, $phylum );
    }
    if ( $ir_class ne '' ) {
        $phylumClause .= "and nvl(t.ir_class, 'unclassified') = ? ";
        push( @bind, $ir_class );
    }
    if ( $ir_order ne '' ) {
        $phylumClause .= "and nvl(t.ir_order, 'unclassified') = ? ";
        push( @bind, $ir_order );
    }
    if ( $family ne '' ) {
        $phylumClause .= "and nvl(t.family, 'unclassified') = ? ";
        push( @bind, $family );
    }
    if ( $genus ne '' ) {
        $phylumClause .= "and nvl(t.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    }
    if ( $species ne '' ) {
        $phylumClause .= "and nvl(t.species, 'unclassified') = ? ";
        push( @bind, $species );
    }

    push( @all_columns, @phylumStatsColumnsOrder );
    my $columns = join( ',', @all_columns );
    $columns = ", $columns" if ( $columns ne '' );

    my $column1 = 't.domain';
    if ( $type ne 'domain' ) {
        $column1 = 't.domain ||' . "'\t'" . '|| nvl(t.' . $type . ", 'unclassified')";
    }

    my $sql = qq{
select $column1, count(*)  $columns
from taxon t, taxon_stats ts
where t.TAXON_OID = ts.TAXON_OID
$phylumClause
$urclause
$imgClause
group by $column1
    };

    my %phylumData;    # hash of hashes
    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my ( $domain2, $genomeCnt, @cols ) = $cur->fetchrow();
        last if !$domain2;

        my $key1 = "$domain2";

        my %hash = ( 'Genome Count' => $genomeCnt );
        for ( my $i = 0 ; $i <= $#all_columns ; $i++ ) {
            my $key   = $all_columns[$i];
            my $value = $cols[$i];
            $hash{$key} = $value;
        }

        $phylumData{$key1} = \%hash;
    }

    if ($include_metagenomes) {
        my @all_columns_merfs = keys %phylumStatsColumnsMerfs;
        my $columns           = join( ',', @all_columns_merfs );

        my $sql = qq{
select $column1, count(*),  $columns
from taxon t left join taxon_stats_merfs ts 
on t.taxon_oid = ts.taxon_oid
where t.genome_type = 'metagenome'
and ts.datatype = '$merfs_data_type'
$phylumClause
$urclause
$imgClause
group by $column1
        };

        my $cur = execSql( $dbh, $sql, $verbose, @bind );
        for ( ; ; ) {
            my ( $domain2, $genomeCnt, @cols ) = $cur->fetchrow();
            last if !$domain2;

            my $key1 = "$domain2";

            my %hash = ( 'Genome Count' => $genomeCnt );
            for ( my $i = 0 ; $i <= $#all_columns_merfs ; $i++ ) {
                my $key   = $all_columns_merfs[$i];
                my $value = $cols[$i];
                $hash{$key} = $value;
            }

            $phylumData{$key1} = \%hash;
        }
    }

    return \%phylumData;
}

#
# phylum stats config table
#
sub printConfigDiv2 {
    my ($statsColumnsChecked_aref) = @_;

    print qq{
        <div id='genomeConfiguration'>      
          <script type='text/javascript' src='$base_url/genomeConfig.js'></script>

          <table border='0'>
            <tr>
            <td style='width:550px;'>
              <span class='hand' id='plus_minus_span4' onclick="javascript:showFilter(4, '$base_url')">
                <img id='plus_minus4' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Data Statistics
            </td>

          </tr>

          <tr>
    };

    # "Data Statistics Div"
    print qq{
            <td>
              <div id='statistics' class='myborder' >
                <input type="button" value="All" onclick="selectCountPhylum(1);">
                <input type="button" value="Clear" onclick="selectCountPhylum(0);">
    };

    if ($include_metagenomes) {
        my $dataType = param('merfs_data_type');
        my $chk1     = '';
        my $chk2     = '';
        my $chk3     = '';

        if ( $dataType eq 'unassembled' ) {
            $chk2 = 'selected';
        } elsif ( $dataType eq 'both' ) {
            $chk3 = 'selected';
        } else {
            $chk1 = 'selected';
        }

        print qq{
<select name="merfs_data_type" title='Applies only to metagenomes'>
            <option value="assembled" $chk1>* Assembled (Metagenomes)</option>
            <option value="unassembled" $chk2>* Unassembled</option>
             <option value="both" $chk3>* Both</option>
</select>
};
    }

    print "<br/>\n";

    # stats have a pre-defined sort order
    foreach my $key (@phylumStatsColumnsOrder) {
        my $value = $phylumStatsColumns{$key};
        my $id    = 'count';
        my $str   = $alwaysChecked{$key};

        if ( $str eq '' ) {

            # checked to see if it was checked before
            $str = existsInArray( $key, $statsColumnsChecked_aref );
        }

        my $star;
        if ( $include_metagenomes && exists $phylumStatsColumnsMerfs{$key} ) {
            $star = '*';
        }

        print qq{ 
          <input id='$id' type="checkbox" value="$key" name="stats_col" $str />$star $value <br/>
        };
    }

    print qq{
              </div>
            </td>
    };    # end of "Data Statistics Div"

    print qq{
          </tr>
        </table>
      </div>\n
    };
}

sub printPhylumGenomeList {
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");
    my $type     = param('type');

    print qq{
        <p>
$domain $phylum $ir_class $ir_order $family $genus $species
</p>
    };

    my @bind;
    my $phylumClause;

    if ( $domain =~ "^Pla" ) {
        $phylumClause .= "and t.domain like 'Plasmid%'";
    } elsif ( $domain =~ "^GFr" ) {
        $phylumClause .= "and t.domain like 'GFragment%'";
    } elsif ( $domain =~ "^Vir" ) {
        $phylumClause .= "and t.domain like 'Vir%'";
    } else {
        $phylumClause .= "and t.domain = ? ";
        push( @bind, $domain );
    }

    if ( $phylum ne '' ) {
        $phylumClause .= "and nvl(t2.phylum, 'unclassified') = ? ";
        push( @bind, $phylum );
    }
    if ( $ir_class ne '' ) {
        $phylumClause .= "and nvl(t2.ir_class, 'unclassified') = ? ";
        push( @bind, $ir_class );
    }
    if ( $ir_order ne '' ) {
        $phylumClause .= "and nvl(t2.ir_order, 'unclassified') = ? ";
        push( @bind, $ir_order );
    }
    if ( $family ne '' ) {
        $phylumClause .= "and nvl(t2.family, 'unclassified') = ? ";
        push( @bind, $family );
    }
    if ( $genus ne '' && $type eq '' ) {
        $phylumClause .= "and nvl(t2.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    } elsif ( $genus ne '' && $type ne '' ) {
        $phylumClause .= "and nvl(t2.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    }

    if ( $species ne '' && $type eq '' ) {
        $phylumClause .= "and nvl(t2.species, 'unclassified') = ? ";
        push( @bind, $species );
    } elsif ( $species ne '' && $type ne '' ) {
        $phylumClause .= "and nvl(t2.species, 'unclassified') = ? ";
        push( @bind, $species );
    }

    my $sql = qq{
      select t2.taxon_oid
      from taxon t2
      where 1 = 1
      $phylumClause
    };

    printGenomesViaSql( '', $sql, 'Phyla Genome List', \@bind, 'printPhylumGenomeList' );
}

# -------------------------------------------------------------------------------------
#
# phylum genome cart list
#
# -------------------------------------------------------------------------------------

# print cart phyla list
sub printCartPhylumList {
    my $domain       = param("domain");
    my $phylum       = param("phylum");
    my $ir_class     = param("ir_class");
    my $ir_order     = param("ir_order");
    my $family       = param("family");
    my $genus        = param("genus");
    my $species      = param("species");
    my $type         = param('type');
    my @statsColumns = param('stats_col');
    @statsColumns = ( 'sum(ts.total_bases)', 'sum(ts.total_gene_count)', @statsColumns );
    $type = 'domain' if ( $type eq '' );

    print qq{
<h1>Genome Cart Phylum List</h1>
<p>
Group by: $type
</p>
    };

    require GenomeCart;
    my $taxons_aref = GenomeCart::getAllGenomeOids();
    if ( $#$taxons_aref < 0 ) {
        webError("No genomes in genome cart");
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    print qq{
        <p>
        Group Genome Cart by: &nbsp;
        <select id="phylagroup" name="phylagroup" onchange="phylaGroup();">
        <option selected="selected" value="label">--- Select a Phylum ---</option>
        <option value="domain">Domain</option>
        <option value="phylum">Phylum</option>
        <option value="ir_class">Class</option>
        <option value="ir_order">Order</option>
        <option value="family">Family</option>
        <option value="genus">Genus</option>
        <option value="species">Species</option>
        </select>
        </p>
    };

    print <<EOF;
        <script language='javascript' type='text/javascript'>
        function phylaGroup() {
            var e =  document.mainForm.phylagroup;
            if(e.value == 'label') {
                return;
            }
            var url = "main.cgi?section=GenomeList&page=phylumCartList&type=";
            url +=  e.value;
            window.open( url, '_self' );
        }
        </script>

EOF

    #
    my $count     = 0;
    my $dbh       = WebUtil::dbLogin();
    my $data_href = getCartPhylumData($dbh);

    #print "<pre>\n";
    #print Dumper $data_href;
    #print "</pre>\n";

    my $txTableName = "phylumtable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    if ( $type ne '' ) {
        $it->addColSpec( $type, 'char asc', 'left' );
    } else {
        $it->addColSpec( 'Phyla', 'char asc', 'left' );
    }
    $it->addColSpec( 'Genomes Count', 'num asc', 'right' );
    if ( $#statsColumns > -1 ) {
        printTaxonListColumnHeader( $it, \@statsColumns, \%phylumStatsColumns, \%statsColumnsAlign );
    }

    foreach my $key ( sort keys %$data_href ) {
        my @phylaKeys = split( /\t/, $key );
        my $href      = $data_href->{$key};
        my $genomeCnt = $href->{'Genome Count'};

        # 0 - domain
        # 1 - phylum
        # 2 - ir_class
        # 3 - ir_order
        # 4 - family
        # 5 - genus
        # 6 - species
        my $text = $key;
        $text =~ s/\t/ /;

        my $phylum2;
        my $ir_class2;
        my $ir_order2;
        my $family2;
        my $genus2;
        my $species2;

        my $domain2  = $phylaKeys[0];
        my $nextType = 'phylum';
        if ( $type eq 'phylum' ) {
            $phylum2  = $phylaKeys[1];
            $nextType = 'ir_class';
        } elsif ( $type eq 'ir_class' ) {
            $ir_class2 = $phylaKeys[1];
            $nextType  = 'ir_order';
        } elsif ( $type eq 'ir_order' ) {
            $ir_order2 = $phylaKeys[1];
            $nextType  = 'family';
        } elsif ( $type eq 'family' ) {
            $family2  = $phylaKeys[1];
            $nextType = 'genus';
        } elsif ( $type eq 'genus' ) {
            $genus2   = $phylaKeys[1];
            $nextType = 'species';
        } elsif ( $type eq 'species' ) {
            $species2 = $phylaKeys[1];
        }

        my $url = $section_cgi . '&page=phylumCartList';
        $url .= "&domain=$domain2";
        $url .= "&type=$nextType" if ( $nextType ne '' );
        if ( $phylum2 ne '' ) {
            $url .= '&phylum=' . $phylum2;
        } elsif ( $phylum ne '' ) {
            $url .= '&phylum=' . $phylum;
        }
        if ( $ir_class2 ne '' ) {
            $url .= '&ir_class=' . $ir_class2;
        } elsif ( $ir_class ne '' ) {
            $url .= '&ir_class=' . $ir_class;
        }

        if ( $ir_order2 ne '' ) {
            $url .= '&ir_order=' . $ir_order2;
        } elsif ( $ir_order ne '' ) {
            $url .= '&ir_order=' . $ir_order;
        }
        if ( $family2 ne '' ) {
            $url .= '&family=' . $family2;
        } elsif ( $family ne '' ) {
            $url .= '&family=' . $family;
        }
        if ( $genus2 ne '' ) {
            $url .= '&genus=' . $genus2;
        } elsif ( $genus ne '' ) {
            $url .= '&genus=' . $genus;
        }
        if ( $species2 ne '' ) {
            $url .= '&species=' . $species2;
        } elsif ( $species ne '' ) {
            $url .= '&species=' . $species;
        }

        my $url2 = alink( $url, $text );
        if ( $type eq 'species' ) {
            $url2 = $text;
        }

        # phyla name
        my $row = $text . $sd . $url2 . "\t";

        # genome count column
        $url2 = $url;
        $url2 =~ s/phylumCartList/phylumCartGenomeList/;
        $url2 = alink( $url2, $genomeCnt );
        $row .= $genomeCnt . $sd . $url2 . "\t";

        foreach my $col (@statsColumns) {

            #my $displayName = $phylumStatsColumns{$col};
            my $value = $href->{$col};
            $row .= $value . $sd . $value . "\t";
        }
        $it->addRow($row);

        $count++;
    }

    $it->printOuterTable(1);

    print "<h2>Table Configuration</h2>";
    my $name = "_section_${section}_phylumList";
    print submit(
        -name  => $name,
        -value => "Redisplay",
        -class => "meddefbutton"
    );
    printConfigDiv2( \@statsColumns );
    print submit(
        -name  => $name,
        -value => "Redisplay ",
        -class => "meddefbutton"
    );

    print hiddenVar( 'page',     'phylumCartList' );
    print hiddenVar( 'section',  $section );
    print hiddenVar( 'domain',   $domain );
    print hiddenVar( 'phylum',   $phylum );
    print hiddenVar( 'ir_class', $ir_class );
    print hiddenVar( 'ir_order', $ir_order );
    print hiddenVar( 'family',   $family );
    print hiddenVar( 'genus',    $genus );
    print hiddenVar( 'species',  $species );
    print hiddenVar( 'type',     $type );
    print end_form();
    printStatusLine( "$count Loaded", 2 );
}

sub getCartPhylumData {
    my ($dbh)    = @_;
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");
    my $type     = param('type');
    $type = 'domain' if ( $type eq '' );

    my $merfs_data_type = param('merfs_data_type');
    $merfs_data_type = 'assembled' if ( $merfs_data_type eq '' );

    my $taxonClause = txsClause( 't', $dbh );
    my @bind;
    my @all_columns;

    my $phylumClause;
    if ( $domain ne '' ) {
        $phylumClause .= "and t.domain = ? ";
        push( @bind, $domain );
    }
    if ( $phylum ne '' ) {
        $phylumClause .= "and nvl(t.phylum, 'unclassified') = ? ";
        push( @bind, $phylum );
    }
    if ( $ir_class ne '' ) {
        $phylumClause .= "and nvl(t.ir_class, 'unclassified') = ? ";
        push( @bind, $ir_class );
    }
    if ( $ir_order ne '' ) {
        $phylumClause .= "and nvl(t.ir_order, 'unclassified') = ? ";
        push( @bind, $ir_order );
    }
    if ( $family ne '' ) {
        $phylumClause .= "and nvl(t.family, 'unclassified') = ? ";
        push( @bind, $family );
    }
    if ( $genus ne '' ) {
        $phylumClause .= "and nvl(t.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    }
    if ( $species ne '' ) {
        $phylumClause .= "and nvl(t.species, 'unclassified') = ? ";
        push( @bind, $species );
    }

    push( @all_columns, @phylumStatsColumnsOrder );
    my $columns = join( ',', @all_columns );
    $columns = ", $columns" if ( $columns ne '' );

    my $column1 = 't.domain';
    if ( $type ne 'domain' ) {

        #$column1 = 't.domain ||' . "'\t'" . '|| t.' . $type;
        $column1 = 't.domain ||' . "'\t'" . '|| nvl(t.' . $type . ", 'unclassified')";
    }

    my $sql = qq{
select $column1, count(*)  $columns
from taxon t, taxon_stats ts
where t.TAXON_OID = ts.TAXON_OID
$taxonClause
$phylumClause
group by $column1
    };

    my %phylumData;    # hash of hashes
    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my ( $domain2, $genomeCnt, @cols ) = $cur->fetchrow();
        last if !$domain2;

        my $key1 = "$domain2";

        my %hash = ( 'Genome Count' => $genomeCnt );
        for ( my $i = 0 ; $i <= $#all_columns ; $i++ ) {
            my $key   = $all_columns[$i];
            my $value = $cols[$i];
            $hash{$key} = $value;
        }

        $phylumData{$key1} = \%hash;
    }

    if ($include_metagenomes) {
        my @all_columns_merfs = keys %phylumStatsColumnsMerfs;
        my $columns           = join( ',', @all_columns_merfs );

        my $sql = qq{
select $column1, count(*),  $columns
from taxon t left join taxon_stats_merfs ts 
on t.taxon_oid = ts.taxon_oid
where t.genome_type = 'metagenome'
and ts.datatype = '$merfs_data_type'
$taxonClause
$phylumClause
group by $column1
        };

        my $cur = execSql( $dbh, $sql, $verbose, @bind );
        for ( ; ; ) {
            my ( $domain2, $genomeCnt, @cols ) = $cur->fetchrow();
            last if !$domain2;

            my $key1 = "$domain2";

            my %hash = ( 'Genome Count' => $genomeCnt );
            for ( my $i = 0 ; $i <= $#all_columns_merfs ; $i++ ) {
                my $key   = $all_columns_merfs[$i];
                my $value = $cols[$i];
                $hash{$key} = $value;
            }

            $phylumData{$key1} = \%hash;
        }
    }

    return \%phylumData;
}

sub printCartPhylumGenomeList {
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");
    my $type     = param('type');

    require GenomeCart;
    my $taxons_aref = GenomeCart::getAllGenomeOids();
    if ( $#$taxons_aref < 0 ) {
        webError("No genomes in genome cart");
    }

    print qq{
        <p>
$domain $phylum $ir_class $ir_order $family $genus $species
</p>
    };

    my @bind = ($domain);
    my $phylumClause;
    if ( $phylum ne '' ) {
        $phylumClause .= "and nvl(t2.phylum, 'unclassified') = ? ";
        push( @bind, $phylum );
    }
    if ( $ir_class ne '' ) {
        $phylumClause .= "and nvl(t2.ir_class, 'unclassified') = ? ";
        push( @bind, $ir_class );
    }
    if ( $ir_order ne '' ) {
        $phylumClause .= "and nvl(t2.ir_order, 'unclassified') = ? ";
        push( @bind, $ir_order );
    }
    if ( $family ne '' ) {
        $phylumClause .= "and nvl(t2.family, 'unclassified') = ? ";
        push( @bind, $family );
    }
    if ( $genus ne '' && $type eq '' ) {
        $phylumClause .= "and nvl(t2.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    } elsif ( $genus ne '' && $type ne '' ) {
        $phylumClause .= "and nvl(t2.genus, 'unclassified') = ? ";
        push( @bind, $genus );
    }

    if ( $species ne '' && $type eq '' ) {
        $phylumClause .= "and nvl(t2.species, 'unclassified') = ? ";
        push( @bind, $species );
    } elsif ( $species ne '' && $type ne '' ) {
        $phylumClause .= "and nvl(t2.species, 'unclassified') = ? ";
        push( @bind, $species );
    }

    my $dbh         = WebUtil::dbLogin();
    my $taxonClause = txsClause( 't2', $dbh );
    my $sql         = qq{
      select t2.taxon_oid
      from taxon t2
      where t2.domain = ?
      $taxonClause
      $phylumClause
    };

    printGenomesViaSql( '', $sql, 'Genome Cart Phyla Genome List', \@bind, 'printCartPhylumGenomeList' );

}


sub getProjectMetadataAttrs {

    # remove 'gap.gold_analysis_project_type', 'gap.submission_type'

    return @projectMetadataColumnsOrder;
}

sub getProjectMetadataColumns {

    # remove 'gap.gold_analysis_project_type', 'gap.submission_type'

    return %projectMetadataColumns;
}

sub getProjectMetadataColName {
    my ($col) = @_;
    return $projectMetadataColumns{$col};
}


sub getProjectMetadataColAlign {
    my ($col) = @_;
    my $x = $projectMetadataColumnsAlign{$col}; 
    
    $x = 'char asc left' if $x eq '';
    return $x;
}

sub getColumnAsUrl {
    return %columnAsUrl;
}

sub getColAsUrl {
    my ($col) = @_;
    return $columnAsUrl{$col};
}

sub isProjectMetadataAttr {
    my ($col) = @_;

    if (exists $projectMetadataColumns{$col}) {
        return 1;
    }
    #if ( grep $_ eq $col, @projectMetadataColumnsOrder ) {
    #    return 1;
    #}
    return 0;
}

##########################################################################
# getMetadataCategoryTaxonCount
# only work for single-valued attr.
##########################################################################
sub getMetadataCategoryTaxonCount {
    my ( $dbh, $category, $domain ) = @_;

    my %dist_count;

    if ( WebUtil::blankStr($category) ) {
        return %dist_count;
    }

    my @metadataCols = ( $category );
    my $gid2projectMetadata_href = getGid2ProjectMetadata( '', \@metadataCols, '', 1 );
    #print "getMetadataCategoryTaxonCount() gid2projectMetadata_href: <br/>\n";
    #print Dumper($gid2projectMetadata_href);
    #print "<br/>\n";

    my @gids = keys %$gid2projectMetadata_href;
    my $taxon_gidInfo_href = QueryUtil::getTaxonForGids( $dbh, \@gids, $domain );    

    foreach my $taxon_oid (keys $taxon_gidInfo_href) {
        my $gold_id = $taxon_gidInfo_href->{$taxon_oid};
        my $cols_aref = $gid2projectMetadata_href->{$gold_id};
        #print "getMetadataCategoryTaxonCount() gold_id=$gold_id, cols_aref=@$cols_aref<br/>\n";

        #my %sub_h;
        for ( my $i = 0 ; $i < scalar(@metadataCols); $i++ ) {
            my $key = @metadataCols[$i];
            my $val = $cols_aref->[$i];
            #print "getMetadataCategoryTaxonCount() key=$key, val=$val<br/>\n";
            next if ( WebUtil::blankStr($val) );
            if ( $key eq $category ) {
                if ( $dist_count{$val} ) {
                    $dist_count{$val} += 1;
                }
                else {
                    $dist_count{$val} = 1;
                }
            }

            #for future, no use here
            #if ( exists $sub_h{$key} ) {
            #    #Unmatched ( in regex; marked by <-- HERE  fix
            #    next if ( $sub_h{$key} =~ /\Q$val\E/ );
            #    $sub_h{$key} = $sub_h{$key} . ", $val";
            #} else {
            #    $sub_h{$key} = $val;
            #}

        }
    }
    #print "getMetadataCategoryTaxonCount() dist_count: <br/>\n";
    #print Dumper(\%dist_count);
    #print "<br/>\n";

    return %dist_count;
}

##########################################################################
# getMetadataCategoryGids
##########################################################################
sub getMetadataCategoryGids {
    my ( $category, $categoryVal ) = @_;

    my @gids = ();

    if ( WebUtil::blankStr($category) ) {
        return @gids;
    }

    my @metadataCols = ( $category );
    my $gid2projectMetadata_href = getGid2ProjectMetadata( '', \@metadataCols, $categoryVal );
    #print "getMetadataCategoryTaxonCount() gid2projectMetadata_href: <br/>\n";
    #print Dumper($gid2projectMetadata_href);
    #print "<br/>\n";
    
    @gids = keys %$gid2projectMetadata_href;
    return @gids;
}


1;
