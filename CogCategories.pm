############################################################################
# CogCategories.pm : name -> category mapping 
# $Id: CogCategories.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package CogCategories;
use strict; 
use CGI qw( :standard );
use DBI;
 
$| = 1; 

my %colName2Label = (
    taxon_display_name           => "Genome Name", 
    domain                       => "D", 
    seq_status                   => "C", 
    phylum                       => "Phylum", 
    ir_class                     => "Class",
    ir_order                     => "Order", 
    family                       => "Family", 
    genus                        => "Genus",
    total_cog_gene_count         => "Total COG Genes", 
    #total_cog_gene_count_pc      => "Total COG Genes (percentage)",
    total_kog_gene_count         => "Total KOG Genes",
    #total_kog_gene_count_pc      => "Total KOG Genes (percentage)", 
    amino_acid_metabolism        => "Amino acid transport and metabolism", 
    amino_acid_metabolism_pc     => "Amino acid transport and metabolism (percentage)", 
    carbohydrate_metabolism      => "Carbohydrate transport and metabolism", 
    carbohydrate_metabolism_pc   => "Carbohydrate transport and metabolism (percentage)",
    cell_cycle                   => "Cell cycle control, cell division, chromosome partitioning", 
    cell_cycle_pc                => "Cell cycle contorl, cell division, chromosome partitioning (percentage)",
    cell_motility                => "Cell Motility",
    cell_motility_pc             => "Cell Motility (percentage)",
    cell_wall_biogenesis         => "Cell wall/membrane/envelope biogenesis",
    cell_wall_biogenesis_pc      => "Cell wall/membrane/envelope biogenesis (percentage)",
    chromatin_structure          => "Chromatin structure and dynamics",
    chromatin_structure_pc       => "Chromatin structure and dynamics (percentage)",
    coenzyme_transport           => "Coenzyme transport and metabolism",
    coenzyme_transport_pc        => "Coenzyme transport and metabolism (percentage)",
    cytoskeleton                 => "Cytoskeleton",
    cytoskeleton_pc              => "Cytoskeleton (percentage)",
    defense_mechanisms           => "Defense mechanisms",
    defense_mechanisms_pc        => "Defense mechanisms (percentage)",
    energy_production            => "Energy production and conversion",
    energy_production_pc         => "Energy production and conversion (percentage)",
    extracellular_structures     => "Extracellular structures",
    extracellular_structures_pc  => "Extracellular structures (percentage)",
    function_unknown             => "Function unknown",
    function_unknown_pc          => "Function unknown (percentage)",
    general_function_only        => "General function prediction only",
    general_function_only_pc     => "General function prediction only (percentage)",
    ion_transport                => "Inorganic ion transport and metabolism",
    ion_transport_pc             => "Inorganic ion transport and metabolism (percentage)",
    intracellular_trafficking    => "Intracellular trafficking, secretion, and vesicular transport",
    intracellular_trafficking_pc => "Intracellular trafficking, secretion, and vesicular transport (percentage)",
    lipid_metabolism             => "Lipid transport and metabolism",
    lipid_metabolism_pc          => "Lipid transport and metabolism (percentage)",
    nuclear_structure            => "Nuclear structure",
    nuclear_structure_pc         => "Nuclear structure (percentage)",
    nucleotide_metabolism        => "Nucleotide transport and metabolism",
    nucleotide_metabolism_pc     => "Nucleotide transport and metabolism (percentage)",
    posttrans_modification       => "Posttranslational modification, protein turnover, chaperones",
    posttrans_modification_pc    => "Posttranslational modification, protein turnover, chaperones (percentage)",
    rna_processing               => "RNA processing and modification",
    rna_processing_pc            => "RNA processing and modification (percentage)",
    replication_repair           => "Replication, recombination and repair",
    replication_repair_pc        => "Replication, recombination and repair (percentage)",
    secondary_metabolites        => "Secondary metabolites biosynthesis, transport and catabolism",
    secondary_metabolites_pc     => "Secondary metabolites biosynthesis, transport and catabolism (percentage)",
    signal_transduction          => "Signal transduction mechanisms",
    signal_transduction_pc       => "Signal transduction mechanisms (percentage)",
    transcription                => "Transcription",
    transcription_pc             => "Transcription (percentage)",
    translation                  => "Translation",
    translation_pc               => "Translation (percentage)",
);

sub getNameForCategory {
    my ($category) = @_;

    my $colName;
    for my $name (keys %colName2Label) {
        my $label = $colName2Label{$name};
        if ( $label eq $category ) {
            $colName = $name;
        }
    }

    return $colName;
}

sub getLabelForName {
    my ($name) = @_;

    return $colName2Label{$name};
}

sub getAllCogNames {
    my ($og, $include_lineage) = @_;

    my @a;
    if ($include_lineage ne "") {
	    push( @a,
	      "phylum", 
	      "ir_class", 
	      "ir_order", 
	      "family", 
	      "genus", 
	     );
    }
    push( @a, "total_${og}_gene_count", );
    push( @a, 
          "amino_acid_metabolism",     "amino_acid_metabolism_pc", 
          "carbohydrate_metabolism",   "carbohydrate_metabolism_pc", 
          "cell_cycle",                "cell_cycle_pc", 
          "cell_motility",             "cell_motility_pc", 
          "cell_wall_biogenesis",      "cell_wall_biogenesis_pc", 
          "chromatin_structure",       "chromatin_structure_pc",
          "coenzyme_transport",        "coenzyme_transport_pc",
          "cytoskeleton",              "cytoskeleton_pc",
          "defense_mechanisms",        "defense_mechanisms_pc", 
          "energy_production",         "energy_production_pc",
          "extracellular_structures",  "extracellular_structures_pc",
          "function_unknown",          "function_unknown_pc",
          "general_function_only",     "general_function_only_pc",
          "ion_transport",             "ion_transport_pc",
          "intracellular_trafficking", "intracellular_trafficking_pc",
          "lipid_metabolism",          "lipid_metabolism_pc",
          "nuclear_structure",         "nuclear_structure_pc",
          "nucleotide_metabolism",     "nucleotide_metabolism_pc",
          "posttrans_modification",    "posttrans_modification_pc", 
          "rna_processing",            "rna_processing_pc",
          "replication_repair",        "replication_repair_pc",
          "secondary_metabolites",     "secondary_metabolites_pc",
          "signal_transduction",       "signal_transduction_pc",
          "transcription",             "transcription_pc",
          "translation",               "translation_pc",
	); 
    return \@a;
}

sub loadName2Header { 
    my ($x) = @_; 

    for my $name (keys %colName2Label) {
        $x->{$name} = $colName2Label{$name};
    }

}

sub loadName2Description {
    my ($x) = @_;

    for my $name (keys %colName2Label) {
        $x->{$name} = $colName2Label{$name};
    }

}


1;
