############################################################################
# TaxonTableConfiguration.pm - share use
#
# $Id: TaxonTableConfiguration.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package TaxonTableConfiguration;
#my $section = "TaxonTableConfiguration";

require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use DataEntryUtil;
use TaxonSearchUtil;
use TreeViewFrame;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $verbose = $env->{ verbose };

my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $include_metagenomes  = $env->{include_metagenomes};
my $include_img_terms    = $env->{include_img_terms};
my $img_er               = $env->{img_er};
my $show_myimg_login     = $env->{show_myimg_login};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};
my $include_kog              = $env->{include_kog};
### optional genome field columns to configuration and display 
my @gOptCols = getGenomeFieldAttrs();

# TODO
#push(@gOptCols,'sample_oid');
#push(@gOptCols,'project_info');

### optional metadata field columns to configuration and display 
my @mOptCols = DataEntryUtil::getGoldCondAttr();

### optional statistics field columns to configuration and display 
my @sOptCols = (
    'n_scaffolds',
    'crispr_count',
    'total_gc',
    'gc_percent',
    'total_coding_bases',

    'total_bases',
    'total_gene_count',
    'cds_genes',
    'cds_genes_pc',

    'rna_genes',
    'rrna_genes',
    'rrna5s_genes',
    'rrna16s_genes',
    'rrna18s_genes',
    'rrna23s_genes',
    'rrna28s_genes',
    'trna_genes',
    'other_rna_genes',

    #fused gene
    'fused_genes',
    'fused_genes_pc',
    'fusion_components',
    'fusion_components_pc',
    
    'pseudo_genes',
    'pseudo_genes_pc',
    'uncharacterized_genes',
    'uncharacterized_genes_pc',

    #'dubious_genes',
    #'dubious_genes_pc',

    'genes_obsolete',
    'genes_obsolete_pc',
    'genes_revised',
    'genes_revised_pc',

    'genes_w_func_pred',
    'genes_w_func_pred_pc',
    'genes_wo_func_pred_sim',
    'genes_wo_func_pred_sim_pc',
    'genes_wo_func_pred_no_sim',
    'genes_wo_func_pred_no_sim_pc',

    'genes_signalp',
    'genes_signalp_pc',
    'genes_transmembrane',
    'genes_transmembrane_pc',

    'genes_in_orthologs',     #40
    'genes_in_orthologs_pc',  #41
    'genes_in_paralogs',      #42
    'genes_in_paralogs_pc',   #43

    'ortholog_groups',    #44
    'paralog_groups',     #45

    #swissprot
    'genes_in_sp',
    'genes_in_sp_pc',
    'genes_not_in_sp',
    'genes_not_in_sp_pc',

    # seed
    'genes_in_seed',
    'genes_in_seed_pc',
    'genes_not_in_seed',
    'genes_not_in_seed_pc',

    'genes_in_cog',
    'genes_in_cog_pc',
    'genes_in_kog',
    'genes_in_kog_pc',
    'genes_in_pfam',
    'genes_in_pfam_pc',
    'genes_in_tigrfam',
    'genes_in_tigrfam_pc',

    'cog_clusters',
    'kog_clusters',
    'pfam_clusters',
    'tigrfam_clusters',

    'genes_in_ipr',
    'genes_in_ipr_pc',

    'genes_in_enzymes',
    'genes_in_enzymes_pc',

    'genes_in_tc',
    'genes_in_tc_pc',

    'genes_in_kegg',
    'genes_in_kegg_pc',
    'genes_not_in_kegg',
    'genes_not_in_kegg_pc',
    'genes_in_ko',
    'genes_in_ko_pc',
    'genes_not_in_ko',
    'genes_not_in_ko_pc',

    #metacyc
    'genes_in_metacyc',
    'genes_in_metacyc_pc',
    'genes_not_in_metacyc',
    'genes_not_in_metacyc_pc',

);

if ($include_img_terms) {
    my @sOptCols_img = (
       'genes_in_img_terms',
       'genes_in_img_terms_pc',
       'genes_in_img_pways',
       'genes_in_img_pways_pc',
       'genes_in_parts_list',
       'genes_in_parts_list_pc',
    );
    push(@sOptCols, @sOptCols_img);  #add sOptCols_img
}
if ($show_myimg_login) {
    my @sOptCols_myimg = (
       'genes_in_myimg',
       'genes_in_myimg_pc',
    );
    push(@sOptCols, @sOptCols_myimg);  #add sOptCols_myimg
}
if ($img_internal) {
    my @sOptCols_internal = (
        'genes_in_genome_prop',
        'genes_in_genome_prop_pc',
        'genes_hor_transfer',
        'genes_hor_transfer_pc',
        'genes_in_img_clusters',
        'genes_in_img_clusters_pc',
    );
    push(@sOptCols, @sOptCols_internal);
}
if ($img_lite) {
    if ( !$img_internal ) {
	my @sOptCols_lite = (
	    'genes_in_genome_prop',
	    'genes_in_genome_prop_pc',
	);
	push(@sOptCols, @sOptCols_lite);  #add \@sOptCols_lite
    }
    splice(@sOptCols, 40, 6);  
    # remove 'genes_in_orthologs', 'genes_in_orthologs_pc', 
    # 'genes_in_paralogs', 'genes_in_paralogs_pc', 'ortholog_groups',
    # 'paralog_groups',
}
if ( !$include_metagenomes && !$img_er ) {
    my @sOptCols_public = (
        'genes_in_cassettes',
        'genes_in_cassettes_pc',
        'total_cassettes',
    );
    push(@sOptCols, @sOptCols_public);
}

if($include_kog) {
    
}

### Maps database column name to header
my %colName2Label_s = (
    n_scaffolds        => "Scaffold Count",
    crispr_count       => "CRISPR Count",
    total_gc           => "GC Count",
    gc_percent         => "GC %",
    total_coding_bases => "Coding Base Count",

    total_bases        => "Genome Size",
    total_gene_count   => "Gene Count",
    cds_genes          => "CDS Count",
    cds_genes_pc       => "CDS %",

    rna_genes          => "RNA Count",
    rna_genes_pc       => "RNA %",
    rrna_genes         => "rRNA Count",
    rrna5s_genes       => "5S rRNA Count",
    rrna16s_genes      => "16S rRNA Count",
    rrna18s_genes      => "18S rRNA Count",
    rrna23s_genes      => "23S rRNA Count",
    rrna28s_genes      => "28S rRNA Count",
    trna_genes         => "tRNA Count",
    other_rna_genes    => "Other RNA Count",
    pseudo_genes       => "Pseudo Count",
    pseudo_genes_pc    => "Pseudo %",
    uncharacterized_genes => "Unchar Count",
    uncharacterized_genes_pc => "Unchar %",

    dubious_genes      => "Dubious Count",
    dubious_genes_pc   => "Dubious %",
    genes_w_func_pred  => "w/ Func Pred Count",
    genes_w_func_pred_pc => "w/ Func Pred %",
    genes_wo_func_pred_sim => "w/o Func Pred Sim Count",
    genes_wo_func_pred_sim_pc => "w/o Func Pred Sim %",
    genes_wo_func_pred_no_sim => "w/o Func Pred No Sim Count",
    genes_wo_func_pred_no_sim_pc => "w/o Func Pred No Sim %",

    genes_in_orthologs => "Orthologs Count",
    genes_in_orthologs_pc => "Orthologs %`",
    genes_in_paralogs  => "Paralogs Count",
    genes_in_paralogs_pc => "Paralogs %",

    genes_obsolete     => "Obsolete Count",
    genes_obsolete_pc  => "Obsolete %",
    genes_revised      => "Revised Count",
    genes_revised_pc   => "Revised %",

    fused_genes        => "Fused Count",
    fused_genes_pc     => "Fused %",
    fusion_components  => "Fusion Component Count",
    fusion_components_pc => "Fusion component %",

    genes_in_sp        => "SwissProt Count",
    genes_in_sp_pc     => "SwissProt %",
    genes_not_in_sp    => "Not SwissProt Count",
    genes_not_in_sp_pc => "Not SwissProt %",

    genes_in_seed      => "SEED Count",
    genes_in_seed_pc   => "SEED %",
    genes_not_in_seed  => "Not SEED Count",
    genes_not_in_seed_pc => "Not SEED %",

    genes_in_cog       => "COG Count",
    genes_in_cog_pc    => "COG %",
    genes_in_kog       => "KOG Count",
    genes_in_kog_pc    => "KOG %",
    genes_in_pfam      => "Pfam Count",
    genes_in_pfam_pc   => "Pfam %",
    genes_in_tigrfam   => "TIGRfam Count",
    genes_in_tigrfam_pc => "TIGRfam %",

    genes_in_ipr       => "InterPro Count",
    genes_in_ipr_pc    => "InterPro %",

    genes_in_enzymes   => "Enzyme Count",
    genes_in_enzymes_pc => "Enzyme %",

    genes_in_tc        => "TC Count",
    genes_in_tc_pc     => "TC %",

    genes_in_kegg      => "KEGG Count",
    genes_in_kegg_pc   => "KEGG %",
    genes_not_in_kegg  => "Not KEGG Count",
    genes_not_in_kegg_pc => "Not KEGG %",
    genes_in_ko        => "KO Count",
    genes_in_ko_pc     => "KO %",
    genes_not_in_ko    => "Not KO Count",
    genes_not_in_ko_pc => "Not KO %",

    genes_in_metacyc   => "MetaCyc Count",
    genes_in_metacyc_pc => "MetaCyc %",
    genes_not_in_metacyc => "Not MetaCyc Count",
    genes_not_in_metacyc_pc => "Not MetaCyc %",

    genes_in_img_terms => "IMG Term Count",
    genes_in_img_terms_pc => "IMG Term %",
    genes_in_img_pways => "IMG Pathwawy Count",
    genes_in_img_pways_pc => "IMG Pathway %",
    genes_in_parts_list => "IMG Parts List Count",
    genes_in_parts_list_pc => "IMG Parts List %",

    genes_in_myimg     => "MyIMG Annotation Count",
    genes_in_myimg_pc  => "MyIMG Annotation %",

    genes_signalp      => "Signal Peptide Count",
    genes_signalp_pc   => "Signal Peptide %",

    genes_transmembrane => "Transmembrane Count",
    genes_transmembrane_pc => "Transmembrane %",

    genes_hor_transfer => "Horizontally Transferred Count",
    genes_hor_transfer_pc => "Horizontally Transferred %",

    genes_in_genome_prop => "Genome Property Count",
    genes_in_genome_prop_pc => "Genome Property %",

    ortholog_groups    => "Ortholog Group Count",
    paralog_groups     => "Paralog Group Count",

    cog_clusters       => "COG Cluster Count",
    kog_clusters       => "KOG Cluster Count",
    pfam_clusters      => "Pfam Cluster Count",
    tigrfam_clusters   => "TIGRfam Cluster Count",

    genes_in_img_clusters => "IMG Cluster Count",
    genes_in_img_clusters_pc => "IMG Cluster %",

    genes_in_cassettes => "Chromosomal Cassette Gene Count",
    genes_in_cassettes_pc => "Chromosomal Cassette Gene %",
    total_cassettes    => "Chromosomal Cassette Count",
);

my %colName2Label_g = getColName2Label_g();
my %colName2Label_m = DataEntryUtil::getGoldAttrDisplay();
my %colName2Label = (%colName2Label_g, %colName2Label_m, %colName2Label_s);

my %colName2Label_s_tooltip = (
    n_scaffolds        => "Number of scaffolds",
    crispr_count       => "Number of CRISPR's",
    total_gc           => "Number of GC",
    gc_percent         => "Percentage of GC",
    total_coding_bases => "Total number of coding bases",

    total_bases        => "Number of total bases",
    total_gene_count   => "Number of total Genes",
    cds_genes          => "Number of CDS genes",
    cds_genes_pc       => "Percentage of CDS genes",

    rna_genes          => "Number of RNA genes",
    rna_genes_pc       => "Percentage of RNA genes",
    rrna_genes         => "Number of rRNA genes",
    rrna5s_genes       => "Number of 5S rRNA's",
    rrna16s_genes      => "Number of 16S rRNA's",
    rrna18s_genes      => "Number of 18S rRNA's",
    rrna23s_genes      => "Number of 23S rRNA's",
    rrna28s_genes      => "Number of 28S rRNA's",
    trna_genes         => "Number of tRNA genes",
    other_rna_genes    => "Number of other (unclassified) RNA genes",
    pseudo_genes       => "Number of pseudo genes",
    pseudo_genes_pc    => "Percentage of pseudo genes",
    uncharacterized_genes => "Number of uncharacerized genes",
    uncharacterized_genes_pc => "Percentage of uncharacterized genes",

    dubious_genes      => "Number of dubious ORFs",
    dubious_genes_pc   => "Percentage of dubious ORFs",
    genes_w_func_pred  => "Number of genes with predicted protein product",
    genes_w_func_pred_pc => "Percentage of genes with predicted protein product",
    genes_wo_func_pred_sim => "Number of genes without function prediction with similarity",
    genes_wo_func_pred_sim_pc => "Percentage of genes without predicted protein product with similarity",
    genes_wo_func_pred_no_sim => "Number of genes without function prediction without similarity",
    genes_wo_func_pred_no_sim_pc => "Percentage of genes without function prediction without similarity",

    genes_in_enzymes   => "Number of genes assigned to enzymes",
    genes_in_enzymes_pc => "Percentage of genes assigned to enzymes",

    genes_in_tc        => "Number of genes assigned to Transporter Classification",
    genes_in_tc_pc     => "Percentage of genes assigned to Transporter Classification",

    genes_in_kegg      => "Number of genes in KEGG",
    genes_in_kegg_pc   => "Percentage of genes in KEGG",
    genes_not_in_kegg  => "Number of genes not in KEGG",
    genes_not_in_kegg_pc => "Percentage of genes not in KEGG",
    genes_in_ko        => "Number of genes in KEGG Orthology (KO)",
    genes_in_ko_pc     => "Percentage of genes in KEGG Orthology (KO)",
    genes_not_in_ko    => "Number of genes not in KEGG Orthology (KO)",
    genes_not_in_ko_pc => "Percentage of genes not in KEGG Orthology (KO)",

    genes_in_orthologs => "Number of genes in orthologs",
    genes_in_orthologs_pc => "Percentage of genes in orthologs",
    genes_in_paralogs  => "Number of genes in paralogs",
    genes_in_paralogs_pc => "Percentage of genes in paralogs",

    genes_in_cog       => "Number of genes in COG",
    genes_in_cog_pc    => "Percentage of genes in COG",
    genes_in_kog       => "Number of genes in KOG",
    genes_in_kog_pc    => "Percentage of genes in KOG",
    genes_in_pfam      => "Number of genes in Pfam",
    genes_in_pfam_pc   => "Percentage of genes in Pfam",
    genes_in_tigrfam   => "Number of genes in TIGRfam",
    genes_in_tigrfam_pc => "Percentage of genes in TIGRfam",

    genes_signalp      => "Number of genes coding signal peptides",
    genes_signalp_pc   => "Percentage of genes coding signal peptides",
    genes_transmembrane => "Number of genes coding transmembrane proteins",
    genes_transmembrane_pc => "Percentage of genes coding transmembrane proteins",
    genes_in_ipr       => "Number of genes in InterPro",
    genes_in_ipr_pc    => "Percentage of genes in InterPro",

    genes_obsolete     => "Number of obsolete genes",
    genes_obsolete_pc  => "Percentage of obsolete genes",
    genes_revised      => "Number of revised genes",
    genes_revised_pc   => "Percentage of revised genes",

    cog_clusters       => "Number of COG clusters",
    kog_clusters       => "Number of KOG clusters",
    pfam_clusters      => "Number of Pfam clusters",
    tigrfam_clusters   => "Number of TIGRfam clusters",
    ortholog_groups    => "Number of ortholog groups",
    paralog_groups     => "Number of paralog groups",

    fused_genes        => "Number of fused genes",
    fused_genes_pc     => "Percentage of fused genes",
    fusion_components  => "Number of genes involved as fusion components",
    fusion_components_pc => "Genes involved as fusion components (%)",

    genes_in_metacyc   => "Number of genes in MetaCyc",
    genes_in_metacyc_pc => "Percentage of genes in MetaCyc",
    genes_not_in_metacyc => "Number of genes not in MetaCyc",
    genes_not_in_metacyc_pc => "Percentage of genes not in MetaCyc",

    genes_in_sp        => "Number of genes in SwissProt protein product",
    genes_in_sp_pc     => "Percentage of genes in SwissProt protein product",
    genes_not_in_sp    => "Number of genes not in SwissProt protein product",
    genes_not_in_sp_pc => "Percentage of genes not in SwissProt protein product",

    genes_in_seed      => "Number of genes in SEED",
    genes_in_seed_pc   => "Percentage of genes in SEED",
    genes_not_in_seed  => "Number of genes not in SEED",
    genes_not_in_seed_pc => "Percentage of genes not in SEED",

    genes_in_img_terms => "Number of genes with IMG terms",
    genes_in_img_terms_pc => "Percentage of genes with IMG terms",
    genes_in_img_pways => "Number of genes in IMG pathwawys",
    genes_in_img_pways_pc => "Percentage of genes in IMG pathways",
    genes_in_parts_list => "Number of genes in IMG parts list",
    genes_in_parts_list_pc => "Percentage of genes in IMG parts list",

    genes_in_myimg     => "Number of genes with IMG annotations",
    genes_in_myimg_pc  => "Percentage of genes with IMG annotations",

    genes_in_genome_prop => "Number of genes in Genome Properties",
    genes_in_genome_prop_pc => "Percentage of genes in Genome Properties",
    genes_hor_transfer => "Number of horizontally transferred genes",
    genes_hor_transfer_pc => "Percentage of horizontally transferred genes",
    genes_in_img_clusters => "Number of genes in IMG clusters",
    genes_in_img_clusters_pc => "Percentage of genes in IMG clusters",

    genes_in_cassettes => "Number of genes in chromosomal cassette",
    genes_in_cassettes_pc => "Percentage of genes in chromosomal cassette",
    total_cassettes    => "Total number of chromosomal cassettes",
);

my %colName2Align_m = (
    biotic_rel          => "char asc left", 
    sample_body_site    => "char asc left", 
    sample_body_subsite => "char asc left",
    #body_product       => "char asc left",
    cell_arrangement    => "char asc left", 
    cell_shape          => "char asc left",
    diseases            => "char asc left",
    energy_source       => "char asc left",
    ecosystem           => "char asc left",
    ecosystem_category  => "char asc left",
    ecosystem_type      => "char asc left",
    ecosystem_subtype   => "char asc left",
    isolation           => "char asc left",    
    specific_ecosystem  => "char asc left",
    gram_stain          => "char asc left",
    #habitat            => "char asc left",
    host_name           => "char asc left",
    host_gender         => "char asc left",
    motility            => "char asc left",
    metabolism          => "char asc left",
    oxygen_req          => "char asc left",
    phenotypes          => "char asc left",
    project_relevance   => "char asc left",
    salinity            => "char asc left", 
    sporulation         => "char asc left",
    temp_range          => "char asc left",
    mrn                 => "num asc right",
    date_collected      => "char asc left",
    sample_oid          => "num asc right",
    project_info        => "num asc right",
    contact_name        => "char asc left",
    contact_email       => "char asc left",
    funding_program     => "char asc left",    
);

my %colName2Align_s = (
    n_scaffolds        => "num asc right",
    crispr_count       => "num asc right",
    total_gc           => "num asc right",
    gc_percent         => "num asc right",
    total_coding_bases => "num asc right",

    total_bases        => "num asc right",
    total_gene_count   => "num asc right",
    cds_genes          => "num asc right",
    cds_genes_pc       => "num asc right",

    rna_genes          => "num asc right",
    rna_genes_pc       => "num asc right",
    rrna_genes         => "num asc right",
    rrna5s_genes       => "num asc right",
    rrna16s_genes      => "num asc right",
    rrna18s_genes      => "num asc right",
    rrna23s_genes      => "num asc right",
    rrna28s_genes      => "num asc right",
    trna_genes         => "num asc right",
    other_rna_genes    => "num asc right",
    pseudo_genes       => "num asc right",
    pseudo_genes_pc    => "num asc right",
    uncharacterized_genes => "num asc right",
    uncharacterized_genes_pc => "num asc right",

    dubious_genes      => "num asc right",
    dubious_genes_pc   => "num asc right",
    genes_w_func_pred  => "num asc right",
    genes_w_func_pred_pc => "num asc right",
    genes_wo_func_pred_sim => "num asc right",
    genes_wo_func_pred_sim_pc => "num asc right",
    genes_wo_func_pred_no_sim => "num asc right",
    genes_wo_func_pred_no_sim_pc => "num asc right",

    genes_in_enzymes   => "num asc right",
    genes_in_enzymes_pc => "num asc right",

    genes_in_tc        => "num asc right",
    genes_in_tc_pc     => "num asc right",

    genes_in_kegg      => "num asc right",
    genes_in_kegg_pc   => "num asc right",
    genes_not_in_kegg  => "num asc right",
    genes_not_in_kegg_pc => "num asc right",
    genes_in_ko        => "num asc right",
    genes_in_ko_pc     => "num asc right",
    genes_not_in_ko    => "num asc right",
    genes_not_in_ko_pc => "num asc right",

    genes_in_orthologs => "num asc right",
    genes_in_orthologs_pc => "num asc right",
    genes_in_paralogs  => "num asc right",
    genes_in_paralogs_pc => "num asc right",

    genes_in_cog       => "num asc right",
    genes_in_cog_pc    => "num asc right",
    genes_in_kog       => "num asc right",
    genes_in_kog_pc    => "num asc right",
    genes_in_pfam      => "num asc right",
    genes_in_pfam_pc   => "num asc right",
    genes_in_tigrfam   => "num asc right",
    genes_in_tigrfam_pc => "num asc right",

    genes_signalp      => "num asc right",
    genes_signalp_pc   => "num asc right",
    genes_transmembrane => "num asc right",
    genes_transmembrane_pc => "num asc right",
    genes_in_ipr       => "num asc right",
    genes_in_ipr_pc    => "num asc right",

    genes_obsolete     => "num asc right",
    genes_obsolete_pc  => "num asc right",
    genes_revised      => "num asc right",
    genes_revised_pc   => "num asc right",

    cog_clusters       => "num asc right",
    kog_clusters       => "num asc right",
    pfam_clusters      => "num asc right",
    tigrfam_clusters   => "num asc right",
    ortholog_groups    => "num asc right",
    paralog_groups     => "num asc right",

    fused_genes        => "num asc right",
    fused_genes_pc     => "num asc right",
    fusion_components  => "num asc right",
    fusion_components_pc => "num asc right",

    genes_in_metacyc   => "num asc right",
    genes_in_metacyc_pc => "num asc right",
    genes_not_in_metacyc => "num asc right",
    genes_not_in_metacyc_pc => "num asc right",

    genes_in_sp        => "num asc right",
    genes_in_sp_pc     => "num asc right",
    genes_not_in_sp    => "num asc right",
    genes_not_in_sp_pc => "num asc right",

    genes_in_seed      => "num asc right",
    genes_in_seed_pc   => "num asc right",
    genes_not_in_seed  => "num asc right",
    genes_not_in_seed_pc => "num asc right",

    genes_in_img_terms => "num asc right",
    genes_in_img_terms_pc => "num asc right",
    genes_in_img_pways => "num asc right",
    genes_in_img_pways_pc => "num asc right",
    genes_in_parts_list => "num asc right",
    genes_in_parts_list_pc => "num asc right",

    genes_in_myimg     => "num asc right",
    genes_in_myimg_pc  => "num asc right",

    genes_in_genome_prop => "num asc right",
    genes_in_genome_prop_pc => "num asc right",
    genes_hor_transfer => "num asc right",
    genes_hor_transfer_pc => "num asc right",
    genes_in_img_clusters => "num asc right",
    genes_in_img_clusters_pc => "num asc right",

    genes_in_cassettes => "num asc right",
    genes_in_cassettes_pc => "num asc right",
    total_cassettes    => "num asc right",
);

my %colName2Align = getColName2Align_g();
%colName2Align = (%colName2Align, %colName2Align_m, %colName2Align_s);

my %colName2SortQual = getColName2SortQual_g();

############################################################################
# findColType - Find col belonging to which type
############################################################################
sub findColType {
    my ($col) = @_;

    if (grep $_ eq $col, @gOptCols) {
    	return 'g';
    }
    elsif (grep $_ eq $col, @mOptCols) {
    	return 'm';
    }
    elsif (grep $_ eq $col, @sOptCols) {
        return 's';
    }
    return '';
}

############################################################################
# getColLabel - get label for col
############################################################################
sub getColLabel {
    my ($col) = @_;

    my $val = $colName2Label{$col}; 
    return $col if ($val eq '');
    return $val;
}

############################################################################
# getColTooltip - get tooltip for col
############################################################################
sub getColTooltip {
    my ($col) = @_;
    
    my $val = $colName2Label_s_tooltip{$col};
    return $val;
}

############################################################################
# getColAlign - get Align for col
############################################################################
sub getColAlign {
    my ($col) = @_;
    
    my $val = $colName2Align{$col};
    return $val;
}

############################################################################
# getColSortQual - get Sort Qual for col
############################################################################
sub getColSortQual {
    my ($col) = @_;
    
    my $val = $colName2SortQual{$col};
    return $val;
}

############################################################################
# getOptStatsAttrs - get optional stats cols
############################################################################
sub getOptStatsAttrs {
    return @sOptCols;
}

############################################################################
# appendTaxonTableConfiguration - Print output attributtes for optional
#   configuration information.
############################################################################
sub appendTaxonTableConfiguration {
    my ( $outputColHash_ref, $name ) = @_;

    printTreeViewMarkup();

    print "<h2>Table Configuration</h2>\n";

    printDisplayAgainButtons($name);

    print "<table id='configurationTable' class='img' border='0'>\n";
    print qq{
        <tr class='img'>
        <th class='img' colspan='3' nowrap>Additional Output Columns<br />
            <input type='button' class='khakibutton' 
	    id='moreExpand' name='expand' value='Expand All'>
            <input type='button' class='khakibutton'
	    id='moreCollapse' name='collapse' value='Collapse All'>
        </th>
        </tr>
    };

    print "<tr valign='top'>\n";
    my @categoryNames = ( "Genome Field", "Metadata Category", 
			  "Statistics Data" );
    my $numCategories = scalar(@categoryNames);
    my @categoryOptCols = (\@gOptCols, \@mOptCols, \@sOptCols);
    my %categories = ();
    for ( my $i = 0 ; $i < $numCategories; $i++ ) {
        my $treeId = $categoryNames[$i];
        print "<td class='img' nowrap>\n";
        print "<div id='$treeId' class='ygtv-checkbox'>\n";

        my $jsObject = "{label:'<b>$treeId</b>', children: [";
        my $categoryOptCols_ref = $categoryOptCols[$i];
        my @optCols = @$categoryOptCols_ref;
        my $hiLiteCnt = 0;
	for (my $j = 0; $j < scalar(@optCols); $j++) {
	    my $key = $optCols[$j];
	    next if ($key eq 'taxon_display_name' 
		     || $key eq 'domain'
		     || $key eq 'seq_status');
	    
	    if ($j != 0) {
		$jsObject .= ", ";
	    }
	    my $val = $colName2Label{$key};
	    my $tooltip = getColTooltip($key);
	    my $tp = 0;
	    if ($tooltip ne '') {
		$val .= " <font color='LightSeaGreen'>("
		          .$tooltip.")</font>";
		if ($tooltip =~ /number/i) {
		    $tp = 1;
		}
		elsif ($tooltip =~ /percentage/i) {
		    $tp = 2;            		
		}
	    }
	    $jsObject .= "{id:\"$key\", label:\"$val\"";
	    if ($tp != 0) {
		$jsObject .= ", tp:$tp";
	    }
	    if ($outputColHash_ref->{$key} ne "") {
		$jsObject .= ", highlightState:1";
		$hiLiteCnt++;
	    }
	    $jsObject .= "}";
	}
	$jsObject .= "]";

        if ($hiLiteCnt > 0) {
	    if ($hiLiteCnt == scalar(@optCols)) {
                $jsObject .= ", highlightState:1";        		
	    }
	    else {
                $jsObject .= ", highlightState:2";        		
	    }
        }
        $jsObject .= "}";
	
        $categories{ $categoryNames[$i] } = $jsObject;
        print "</div></td>\n";
    }
    print "</tr>\n";
    print "</table>\n";

    my $categoriesObj = "{category:[";
    for ( my $i = 0 ; $i < $numCategories ; $i++ ) {
        $categoriesObj .= "{name:'$categoryNames[$i]', ";
        #$categoriesObj .= "value : $categories{$categoryNames[$i]}}";
        $categoriesObj .= "value:[" . $categories{$categoryNames[$i]} . "]}";
        if ($i != $numCategories-1) {
            $categoriesObj .= ", ";
        }
    }
    $categoriesObj .= "]}";
    setJSObjects( $categoriesObj );
    printDisplayAgainButtons($name);
}

sub printDisplayAgainButtons {
    my ( $name ) = @_;

    print submit(
                  -id  => "moreGo",
                  -name  => $name,
                  -value  => "Display Genomes Again",
                  -class => "meddefbutton"
    );
    print nbsp(1);

    # Added non-blank id attribute in <input> statements below
    # to uniqely identify table buttons
    # Used by datatable.html to track multiple tables
    print "<input id='selAll' type=button name=SelectAll value='Select All' class='smbutton' />\n";
    print nbsp(1);
    print "<input id='selCnt' type=button name='SelectCount' value='Select Counts Only' class='smbutton' />\n";
    print nbsp(1);
    print "<input id='selPerc' type=button name='SelectPerc' value='Select Percentage Only' class='smbutton' />\n";
    print nbsp(1);
    print "<input id='clrAll' type=button name=ClearAll value='Clear All' class='smbutton' />\n";
}

sub printTreeViewMarkup {
    printTreeMarkup();
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/metadataTree.js'>
        </script>
    };
}

sub setJSObjects {
    my ( $categoriesObj ) = @_;

    print qq{
        <script type="text/javascript">
           setMoreJSObjects($categoriesObj);
           setExpandAll();
           moreTreeInit();
        </script>
    };
}

############################################################################
# printNotes - Show additional notes.
############################################################################
sub printNotes {
    my ($useSimpleHint) = @_;
    TaxonSearchUtil::printNotes($useSimpleHint);
}

sub printNotesHint {
    TaxonSearchUtil::printNotesHint();
}

sub getNCBIProjectIdLink {
    my ($ncbi_pid) = @_;
    return TaxonSearchUtil::getNCBIProjectIdLink($ncbi_pid);
}

1;
