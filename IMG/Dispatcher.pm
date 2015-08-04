############################################################################
#	IMG::Dispatcher.pm
#
#	Parse query params and run the appropriate code
#
#	$Id: Dispatcher.pm 33827 2015-07-28 19:36:22Z aireland $
############################################################################
package IMG::Dispatcher;

use IMG::Util::Base;

use String::CamelCase qw( camelize decamelize );

use IMG::Views::ViewMaker;

#use Role::Tiny::With;

#with 'IMG::Util::Factory', 'IMG::Views::Links';

#use GenomeCart ();
#use WebUtil ();

my $env;
my $cgi;
my $session;
my %cgi_params;

sub section_decompress {

	my $s_name = shift;

	return ( $s_name =~ s/([a-z])([A-Z])/\1 \2/g );

}



sub genomeHeaderJson {
	return IMG::Views::ViewMaker::genomeHeaderJson;
}

sub meshTreeHeader {
	return IMG::Views::ViewMaker::meshTreeHeader;
}

=head3 dispatch_page

@param cgi
@param env

=cut

sub dispatch_page {

	my $arguments = shift;

	$env = $arguments->{env};
	$cgi = $arguments->{cgi};
	$session = $arguments->{session};
	%cgi_params = $cgi->Vars;
	IMG::Views::ViewMaker::init( $arguments );

	my $module;           # the module to load
	my %args;             # arguments for populating page templates
	my $sub = 'dispatch'; # subroutine to run (if not dispatch)
	my $tmpl = 'default'; # which template to use for the page

	my $page = $cgi->param('page') || "";
	my $section = $cgi->param('section');

	my $section_table = {
        AbundanceProfileSearch => sub {
            %args = ( title => 'Abundance Profile Search', current => "CompareGenomes", yui_js => genomeHeaderJson(), help => "userGuide_m.pdf#page=" );
			$args{help} .= ( $env->{include_metagenomes} )
            ? "19"
            : "51";
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        StudyViewer => sub {
            %args = ( title => "Metagenome Study Viewer", current => "FindGenomes", include_scripts => 'treeview.tt', include_styles => 'treeview.tt' );
        },
        ANI => sub {
            %args = ( title => 'ANI', current => "CompareGenomes" );
            if ( $page eq 'pairwise' ) {
                $args{yui_js} = genomeHeaderJson();
            }
            elsif ( $page eq 'overview' ) {
                $args{yui_js} = meshTreeHeader();
            }
        },
        Caliban => sub {
            return;
        },
        Portal => sub {
            %args = ( current => "Find Genomes");
        },
        ProjectId => sub {
            %args = ( title => "Project ID List", current => "FindGenomes" );
        },
        ScaffoldSearch => sub {
            %args = ( title => 'Scaffold Search', current => "FindGenomes", yui_js => genomeHeaderJson() );
        },
        MeshTree => sub {
            %args = ( title => "Mesh Tree", current => "FindFunctions", yui_js => meshTreeHeader() );
        },
        AbundanceProfiles => sub {
        	%args = ( title => 'Abundance Profiles', current => "CompareGenomes", yui_js => genomeHeaderJson(), help => "userGuide_m.pdf#page=" );
			$args{help} .= ( $env->{include_metagenomes} )
            ? "18"
            : "49";
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceTest => sub {
            %args = ( title => "Abundance Test", current => "CompareGenomes" );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceComparisons => sub {
            %args = ( title => 'Abundance Comparisons', current => "CompareGenomes", yui_js => genomeHeaderJson() );
            $args{help} = 'userGuide_m.pdf#page=20' if $env->{include_metagenomes};
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceComparisonsSub => sub {
            %args = ( title => 'Function Category Comparisons', current => "CompareGenomes", yui_js => genomeHeaderJson() );
            $args{help} = 'userGuide_m.pdf#page=23' if $env->{include_metagenomes};
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceToolkit => sub {
            %args = ( title => "Abundance Toolkit", current => "CompareGenomes" );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        Artemis => sub {
            %args = ( title => 'Artemis', current => "FindGenomes", yui_js => genomeHeaderJson() );
            my $from = $cgi->param("from");
            if ( $from eq "ACT" || $page =~ /^ACT/ || $page =~ /ACT$/ ) {
                $args{current} = "CompareGenomes";
            }
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ClustalW => sub {
            %args = ( title => "Clustal - Multiple Sequence Alignment", current => "AnaCart", help => "DistanceTree.pdf#page=6" );
            $args{timeout_mins} = 40;    # timeout in 40 minutes
        },
        CogCategoryDetail => sub {
            %args = ( title => 'COG', current => "FindFunctions" );
            $args{title} = 'KOG' if $page =~ /kog/i;
        },
        CompTaxonStats => sub {
            %args = ( title => "Genome Statistics", current => "CompareGenomes" );
        },
        CompareGenomes => sub {
            if ( paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%args = ( filename => "stats_export$$.xls" );
            }
            else {
                %args = ( title => 'Compare Genomes', current => "CompareGenomes" );
            }
        },
        GenomeGeneOrtholog => sub {
            %args = ( title => 'Genome Gene Ortholog', current => "CompareGenomes", yui_js => genomeHeaderJson() );
        },
        Pangenome => sub {
            if ( paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%args = ( filename => "stats_export$$.xls" );
            }
            else {
                %args = ( title => 'Pangenome', current => "Pangenome" );
            }
        },
        CompareGeneModelNeighborhood => sub {
            %args = ( title => "Compare Gene Models", current => "CompareGenomes" );
        },
        CuraCartStor => sub {
            %args = ( title => 'Curation Cart', current => "AnaCart" );
            $session->param( "lastCart", "curaCart" );
        },
        CuraCartDataEntry => sub {
            %args = ( title => "Curation Cart Data Entry", current => "AnaCart" );
            $session->param( "lastCart", "curaCart" );
        },
        DataEvolution => sub {
            %args = ( title => "Data Evolution", current => "news" );
        },
        EbiIprScan => sub {
			%args = ( title => 'EBI InterPro Scan' );
            print header( -header => "text/html" );
        },
        EgtCluster => sub {
            %args = ( title => 'Genome Clustering', current => "CompareGenomes", yui_js => genomeHeaderJson() );
            $args{help} = "DistanceTree.pdf#page=5" if $cgi->param('method') && $cgi->param('method') eq 'hier';
            $args{timeout_mins} = 30;    # timeout in 30 minutes
        },
        EmblFile => sub {
            %args = ( title => "EMBL File Export", current => "FindGenomes" );
        },
        BcSearch => sub {
            %args = ( title => "Biosynthetic Cluster Search", current => "getsme", yui_js => meshTreeHeader() );
            $args{title} = "Secondary Metabolite Search" if $page eq 'npSearches' || $page eq 'npSearchResult';
        },
        BiosyntheticStats => sub {
            %args = ( title => "Biosynthetic Cluster Statistics", current => "getsme", yui_js => meshTreeHeader() );
        },
        BiosyntheticDetail => sub {
            %args = ( title => "Biosynthetic Cluster", current => "getsme" );
        },
        NaturalProd => sub {
            %args = ( title => "Secondary Metabolite Statistics", current => "getsme", yui_js => meshTreeHeader() );
        },
        BcNpIDSearch => sub {
            %args = ( title => "Biosynthetic Cluster / Secondary Metabolite Search by ID", current => "getsme" );
        },
        FindFunctions => sub {
			%args = ( title => 'Find Functions', current => "FindFunctions", yui_js => genomeHeaderJson() );
            if ( $page eq 'findFunctions' ) {
				$args{help} = 'FunctionSearch.pdf';
            }
            elsif ( $page eq 'ffoAllSeed' ) {
				$args{help} = 'SEED.pdf';
            }
            elsif ( $page eq 'ffoAllTc' ) {
                $args{help} = 'TransporterClassification.pdf';
            }
        },
        FindFunctionMERFS => sub {
            %args = ( title => "Find Functions", current => "FindFunctions" );
        },
        FindGenes => sub {
			%args = ( title => 'Find Genes', current => "FindGenes", yui_js => genomeHeaderJson() );
            if (   $page eq 'findGenes'
                || $page eq 'geneSearch'
                || ( $page ne 'geneSearchForm' && ! paramMatch("fgFindGenes") ) ) {
                $args{help} = 'GeneSearch.pdf';
            }
        },
        FindGenesLucy => sub {
            %args = ( title => "Find Genes by Keyword", current => "FindGenesLucy", help => 'GeneSearch.pdf' );
        },
        FindGenesBlast => sub {
            %args = ( title => "Find Genes - BLAST", current => "FindGenes", yui_js => genomeHeaderJson(), help => 'Blast.pdf' );
        },
        FindGenomes => sub {
            %args = ( current => 'FindGenomes', title => 'Find Genomes' );
            if ( $page eq 'findGenomes' ) {
            	$args{help} = 'GenomeBrowser.pdf';
            }
            elsif ( $page eq 'genomeSearch' ) {
				$args{help} = 'GenomeSearch.pdf';
            }
        },
        FunctionAlignment => sub {
            %args = ( title => "Function Alignment", current => "FindFunctions", help => 'FunctionAlignment.pdf' );
        },
        FuncCartStor => sub {
            %args = ( current => 'AnaCart', help => 'FunctionCart.pdf', title => 'Function Cart' );
            $args{title} = "Assertion Profile" if paramMatch("AssertionProfile");

            if ( $page eq 'funcCart' && $env->{enable_genomelistJson} ) {
            ## Eh?!?!
            	$args{help} = GenomeListJSON();
            }
            $session->param( "lastCart", "funcCart" );
        },
        FuncProfile => sub {
            %args = ( title => "Function Profile", current => "AnaCart" );
        },
        FunctionProfiler => sub {
            %args = ( title => 'Function Profile', current => "CompareGenomes", yui_js => genomeHeaderJson() );
        },
        DotPlot => sub {
            %args = ( title => 'Dotplot', current => "CompareGenomes", no_menu => "Synteny Viewers", yui_js => genomeHeaderJson(), help => 'Dotplot.pdf' );
            $args{timeout_mins} = 40;    # timeout in 40 minutes
        },
        DistanceTree => sub {
            %args = ( title => 'Distance Tree', current => "CompareGenomes", yui_js => genomeHeaderJson(), help => 'DistanceTree.pdf' );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        RadialPhyloTree => sub {
            %args = ( title => "Radial Phylogenetic Tree", current => "CompareGenomes", yui_js => genomeHeaderJson() );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        Kmer => sub {
            %args = ( title => "Kmer Frequency Analysis", current => "FindGenomes" ) if ! paramMatch("export");
            $args{timeout_mins} = 20;
        },
        GenBankFile => sub {
            %args = ( title => "GenBank File Export", current => "FindGenomes" );
        },
        GeneAnnotPager => sub {
            %args = ( title => "Comparative Annotations", current => "FindGenomes" );
        },
        GeneInfoPager => sub {
            %args = ( title => "Download Gene Information", current => "FindGenomes" );
            $args{timeout_mins} = 60;
        },
        GeneCartChrViewer => sub {
            %args = ( title => "Circular Chromosome Viewer", current => "AnaCart" );
            $session->param( "lastCart", "geneCart" );
        },
        GeneCartDataEntry => sub {
            %args = ( title => "Gene Cart Data Entry", current => "AnaCart" );
            $session->param( "lastCart", "geneCart" );
        },
        GenomeListJSON => sub {
            %args = ( current => "AnaCart", yui_js => genomeHeaderJson() );
#            GenomeListJSON::test();
			$module = 'GenomeListJSON';
			$sub = sub {
				$module::test();
			};
        },
        GeneCartStor => sub  {
            %args = ( current =>  'AnaCart', title => 'Gene Cart' );
            my $last_cart = ( paramMatch('addFunctionCart') )
            ? 'funcCart'
            : 'geneCart';
            $session->param( "lastCart", $last_cart );

            if ( $page eq 'geneCart' ) {
				$args{help} = 'GeneCart.pdf';
                $args{yui_js} = genomeHeaderJson() if $env->{enable_genomelistJson};
			}
        },
        MyGeneDetail => sub {
            %args = ( title => "My Gene Detail", current => "FindGenes" );
        },
        Help => sub {
            %args = ( title => "Help", current => "about" );
        },
        GeneDetail => sub {
            %args = ( title => "Gene Details", current => "FindGenes" );
        },
        MetaGeneDetail => sub {
            %args = ( title => "Metagenome Gene Details", current => "FindGenes" );
        },
        MetaGeneTable => sub {
            %args = ( title => "Gene List", current => "FindGenes" );
        },
        GeneNeighborhood => sub {
            %args = ( title => "Gene Neighborhood", current => "FindGenes" );
            $args{timeout_mins} = 20;
        },
        FindClosure => sub {
            %args = ( title => "Functional Closure", current => "AnaCart" );
        },
        GeneCassette => sub {
            %args = ( title => "IMG Cassette", current => "CompareGenomes" );
            $args{timeout_mins} = 20;
        },
        MetagPhyloDist => sub {
            %args = ( title => "Phylogenetic Distribution", current => "CompareGenomes", yui_js => genomeHeaderJson() );
        },
        Cart => sub {
            %args = ( title => "My Cart", current => "AnaCart" );
        },
        GeneCassetteSearch => sub {
            %args = ( title => "IMG Cassette Search", current => "FindGenes", yui_js => genomeHeaderJson() );
            $args{timeout_mins} = 20;
        },
        TreeFile => sub {
            %args = ( title => "IMG Tree", current => "FindGenomes" );
        },
        HorizontalTransfer => sub {
            %args = ( title => "Horizontal Transfer", current => "FindGenomes" );
        },
        ImgTermStats => sub {
            %args = ( title => "IMG Term", current => "FindFunctions" );
        },
        KoTermStats => sub {
            %args = ( title => "KO Stats", current => "FindFunctions" );
        },
        HmpTaxonList => sub {
            %args = ( title => 'HMP Genome List', current => "FindGenomes" );
            if ( paramMatch("_excel") ) {
                $tmpl = 'excel';
                %args = ( filename => "genome_export$$.xls" );
            }
        },
        EggNog => sub {
            %args = ( title => "EggNOG", current => "FindFunctions" );
        },
        Interpro => sub {
            %args = ( title => "Interpro", current => "FindFunctions" );
        },
        MetaCyc => sub {
            %args = ( title => "MetaCyc", current => "FindFunctions" );
        },
        Fastbit => sub {
            %args = ( title => "Fastbit Test", current => "FindFunctions", yui_js => genomeHeaderJson() );
        },
        AnalysisProject => sub {
            %args = ( title => "Analysis Project", current => "FindGenomes" );
        },
        GeneCassetteProfiler => sub {
            %args = ( title => "Phylogenetic Profiler", current => "FindGenes", yui_js => genomeHeaderJson() );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ImgStatsOverview => sub {
            %args = ( title => "IMG Stats Overview", current => "ImgStatsOverview" );
            if ( $cgi->param('excel') && $cgi->param('excel') eq 'yes' ) {
            	$tmpl = 'excel';
            	%args = ( filename => "stats_export$$.xls" );
            }
        },
        TaxonEdit => sub {
            %args = ( title => "Taxon Edit", current => "Taxon Edit" );
        },
        GenePageEnvBlast => sub {
            %args = ( title => "SNP BLAST",);
        },
        GeneProfilerStor => sub {
            %args = ( title => "Gene Profiler", current => "AnaCart" );
            $session->param( "lastCart", "geneCart" );
        },
        GenomeProperty => sub {
            %args = ( title => "Genome Property" );
        },
        GreenGenesBlast => sub {
            %args = ( title => 'Green Genes BLAST' );
            print header( -header => "text/html" );
        },
        HomologToolkit => sub {
            %args = ( title => "Homolog Toolkit", current => "FindGenes" );
        },
        ImgCompound => sub {
            %args = ( title => "IMG Compound", current => "FindFunctions", yui_js => meshTreeHeader() );
        },
        ImgCpdCartStor => sub {
            %args = ( title => "IMG Compound Cart", current => "AnaCart" );
            $session->param( "lastCart", "imgCpdCart" );
        },
        ImgTermAndPathTab => sub {
            %args = ( title => "IMG Terms & Pathways", current => "FindFunctions" );
        },
        ImgNetworkBrowser => sub {
            %args = ( title => "IMG Network Browser", current => "FindFunctions", js => '', redirect_url => 'imgterms.html' );
        },
        ImgPwayBrowser => sub {
            %args = ( title => "IMG Pathway Browser", current => "FindFunctions" );
        },
        ImgPartsListBrowser => sub {
            %args = ( title => "IMG Parts List Browser", current => "FindFunctions" );
        },
        ImgPartsListCartStor => sub {
            %args = ( title => "IMG Parts List Cart", current => "AnaCart" );
            $session->param( "lastCart", "imgPartsListCart" );
        },
        ImgPartsListDataEntry => sub {
            %args = ( title => "IMG Parts List Data Entry", current => "AnaCart" );
            $session->param( "lastCart", "imgPartsListCart" );
        },
        ImgPwayCartDataEntry => sub {
            %args = ( title => "IMG Pathway Cart Data Entry", current => "AnaCart" );
            $session->param( "lastCart", "imgPwayCart" );
        },
        ImgPwayCartStor => sub {
            %args = ( title => "IMG Pathway Cart", current => "AnaCart" );
            $session->param( "lastCart", "imgPwayCart" );
        },
        ImgReaction => sub {
            %args = ( title => "IMG Reaction", current => "FindFunctions" );
        },
        ImgRxnCartStor => sub {
            %args = ( title => "IMG Reaction Cart", current => "AnaCart" );
            $session->param( "lastCart", "imgRxnCart" );
        },
        ImgTermBrowser => sub {
            %args = ( title => "IMG Term Browser", current => "FindFunctions" );
        },
        ImgTermCartDataEntry => sub {
            %args = ( title => "IMG Term Cart Data Entry", current => "AnaCart" );
            $session->param( "lastCart", "imgTermCart" );
        },
        ImgTermCartStor => sub {
            %args = ( title => "IMG Term Cart", current => "AnaCart" );
            $session->param( "lastCart", "imgTermCart" );
        },
        KeggMap => sub {
            %args = ( title => "KEGG Map", current => "FindFunctions" );
            $args{timeout_mins} = 20;
        },
        KeggPathwayDetail => sub {
            %args = ( title => "KEGG Pathway Detail", current => "FindFunctions", yui_js => genomeHeaderJson() );
        },
        PathwayMaps => sub {
            %args = ( title => "Pathway Maps", current => "PathwayMaps" );
            $args{timeout_mins} = 20;
        },
        Metagenome => sub {
            %args = ( title => "Metagenome", current => "FindGenomes" );
        },
        AllPwayBrowser => sub {
            %args = ( title => "All Pathways", current => "FindFunctions" );
        },
        MpwPwayBrowser => sub {
            %args = ( title => "Mpw Pathway Browser", current => "FindFunctions" );
        },
        GenomeHits => sub {
            %args = ( title => "Genome Hits", current => "CompareGenomes", yui_js => genomeHeaderJson() );
            $args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ScaffoldHits => sub {
            %args = ( title => 'Scaffold Hits', current => "AnaCart" );
        },
        ScaffoldCart => sub {
            %args = ( title => 'Scaffold Cart', current => "AnaCart" );
            if (   paramMatch("exportScaffoldCart")
                || paramMatch("exportFasta") ) {
            	# export excel
                $session->param( "lastCart", "scaffoldCart" );
            }
            elsif ( ! paramMatch("addSelectedToGeneCart") ) {
                $session->param( "lastCart", "scaffoldCart" );
            }
        },
        GenomeCart => sub {
            %args = ( title => 'Genome Cart', current => "AnaCart" );
            $session->param( "lastCart", "genomeCart" );
        },
        MetagenomeHits => sub {
            %args = ( title => 'Genome Hits', current => "FindGenomes" );
        },
        MetaFileHits => sub {
            %args = ( title => 'Metagenome Hits', current => "FindGenomes" );
        },
        MetagenomeGraph => sub {
            %args = ( title => 'Genome Graph', current => "FindGenomes" );
            $args{timeout_mins} = 40;
        },
        MetaFileGraph => sub {
            %args = ( title => 'Metagenome Graph', current => "FindGenomes" );
        },
        MissingGenes => sub {
            %args = ( title => "MissingGenes", current => "AnaCart" );
        },
        MyFuncCat => sub {
            %args = ( title => "My Functional Categories", current => "AnaCart" );
        },
        MyIMG => sub {
            %args = ( title => 'My IMG', current => "MyIMG", help => 'MyIMG4.pdf' );
            if ( $page eq 'taxonUploadForm' ) {
            	delete $args{help};
            	$args{current} = 'AnaCart';
            }
        },
        ImgGroup => sub {
            %args = ( title => "MyIMG", current => "MyIMG" );
        },
        MyBins => sub {
            %args = ( title => "My Bins", current => "MyIMG" );
        },
        About => sub {
            %args = ( title => "About", current => "about" );
        },
        NcbiBlast => sub {
            %args = ( title => "NCBI BLAST", current => "FindGenes" );
        },
        NrHits => sub {
            %args = ( title => "Gene Details" );
        },
        Operon => sub {
            %args = ( title => "Operons", current => "FindGenes" );
        },
        OtfBlast => sub {
            %args = ( title => 'Gene Details', current => "FindGenes", yui_js => genomeHeaderJson() );
        },
        PepStats => sub {
            %args = ( title => "Peptide Stats", current => "FindGenes" );
        },
        PfamCategoryDetail => sub {
            %args = ( title => "Pfam Category", current => "FindFunctions" );
        },
        PhyloCogs => sub {
            %args = ( title => 'Phylogenetic Marker COGs', current => "CompareGenomes" );
        },
        PhyloDist => sub {
            %args = ( title => "Phylogenetic Distribution", current => "FindGenes" );
        },
        PhyloOccur => sub {
            %args = ( title => "Phylogenetic Occurrence Profile", current => "AnaCart" );
        },
        PhyloProfile => sub {
            %args = ( title => "Phylogenetic Profile", current => "AnaCart" );
        },
        PhyloSim => sub {
            %args = ( title => "Phylogenetic Similarity Search", current => "FindGenes" );
        },
        PhyloClusterProfiler => sub {
            %args = ( title => 'Phylogenetic Profiler using Clusters', current => "FindGenes" );
        },
        PhylogenProfiler => sub {
            %args = ( title => 'Phylogenetic Profiler', current => "FindGenes", yui_js => genomeHeaderJson() );
        },
        ProteinCluster => sub {
            %args = ( title => "Protein Cluster", current => "FindGenes" );
        },
        ProfileQuery => sub {
            %args = ( title => "Profile Query", current => "FindFunctions" );
        },
        PdbBlast => sub {
            %args = ( title => 'Protein Data Bank BLAST' );
            print header( -header => "text/html" );
        },
        Registration => sub {
            %args = ( title => "Registration", current => "MyIMG" );
        },
        SixPack => sub {
            %args = ( title => "Six Frame Translation", current => "FindGenes" );
        },
        Sequence => sub {
            %args = ( title => "Six Frame Translation", current => "FindGenes" );
        },
        ScaffoldGraph => sub {
            %args = ( title => "Chromosome Viewer", current => "FindGenomes" );
        },
        MetaScaffoldGraph => sub {
            %args = ( title => "Chromosome Viewer", current => "FindGenomes" );
        },
        TaxonCircMaps => sub {
            %args = ( title => "Circular Map", current => "FindGenomes" );
        },
        GenerateArtemisFile => sub {
            %args = ( current => "FindGenomes" );
        },
        GenomeList => sub {
            %args = ( title => "Genome List", current => "FindGenomes" );
        },
        TaxonDetail => sub {
			%args = ( title => 'Taxon Details', current => "FindGenomes" );
            $args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';
        },
        TaxonDeleted => sub {
            %args = ( title => "Taxon Deleted", current => "FindGenomes" );
        },
        MetaDetail => sub {
			%args = ( title => 'Microbiome Details', current => "FindGenomes" );
            $args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';
        },
        TaxonList => sub {
			%args = ( title => 'Taxon Browser', current => 'FindGenomes' );
			$args{title} = 'Category Browser' if $page eq 'categoryBrowser';
            if ( paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%args = ( filename => "genome_export$$.xls" );
#                printExcelHeader("genome_export$$.xls");
            }
            elsif (   $page eq 'taxonListAlpha'
                    || $page eq 'gebaList'
                    || $page eq 'selected' ) {
				$args{help} = 'GenomeBrowser.pdf';
            }
        },
        TaxonSearch => sub {
            %args = ( title => "Taxon Search", current => "FindGenomes" );
        },
        TigrBrowser => sub {
            %args = ( title => "TIGRfam Browser", current => "FindFunctions" );
        },
        TreeQ => sub {
            %args = ( title => "Dynamic Tree View" );
        },
        Vista => sub {
            %args = ( title => 'VISTA', current => "CompareGenomes" );
			$args{title} = 'Synteny Viewers' if $page eq 'toppage';
        },
        IMGContent => sub {
            %args = ( title => "IMG Content", current => "IMGContent" );
        },
        IMGProteins => sub {
            %args = ( title => "Proteomics", current => "Proteomics", help => "Proteomics.pdf" );
        },
        Methylomics => sub {
            %args = ( title => "Methylomics Experiments", current => "Methylomics", help => "Methylomics.pdf" );
        },
        RNAStudies => sub {
            %args = ( title => "RNASeq Expression Studies", current => "RNAStudies", help => "RNAStudies.pdf" );
            $args{timeout_mins} = 20;
            if ( paramMatch("samplePathways") ) {
                $args{title} = "RNASeq Studies: Pathways";
            }
            elsif ( paramMatch("describeSamples") ) {
                $args{title} = "RNASeq Studies: Describe";
            }
        },
        Questions => sub {
            %args = ( title => "Questions and Comments", current => "about" );
		},
        np => sub {
            $module = 'NaturalProd';
            %args = ( title => "Biosynthetic Clusters and Secondary Metabolites", current => "getsme", help => 'GetSMe_intro.pdf' );
            $sub = sub {
            	$module::printLandingPage();
            };
        },
		Workspace => sub {
			%args = ( title => 'Workspace', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => Workspace::getStyles() );
		},
		WorkspaceFuncSet => sub {
			%args = ( title => 'Workspace Function Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => Workspace::getStyles() );
		},
		WorkspaceGeneSet => sub {
			%args = ( title => 'Workspace Gene Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => Workspace::getStyles() );
		},
		WorkspaceGenomeSet => sub {
			%args = ( title => 'Workspace Genome Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => Workspace::getStyles() );
		},
		WorkspaceJob => sub {
			%args = ( title => 'Workspace Jobs', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' );
		},
		WorkspaceRuleSet => sub {
			%args = ( title => 'Workspace Rule Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' );
		},
		WorkspaceScafSet => sub {
			%args = ( title => 'Workspace Scaffold Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => Workspace::getStyles() );
		},
	};

	# extras that use existing data:
	$section_table->{ CompareGenomesTab } = {
		$module = 'CompareGenomes';
		$section_table->{ $module }->();
	};
	$section_table->{ FuncCartStorTab } = {
		$module = 'FuncCartStor';
		$section_table->{ $module }->();
	};
	$section_table->{ GeneCartStorTab } = {
		$module = 'GeneCartStor';
		$section_table->{ $module }->();
	};


=cut
#					require WorkspaceRuleSet;
					$module = 'WorkspaceRuleSet';
									my $header = param("header");
					if ( paramMatch("wpload") )
					{    ##use 'wpload' since param 'uploadFile' interferes 'load'
							# no header
					}
					elsif ( param('header') eq "" && paramMatch("noHeader") eq "" ) {
						print_app_header( current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' )
					}
					WorkspaceRuleSet::dispatch();
				}
				elsif ( $1 eq "Job" ) {
					delete $args{yui_js};
#					require WorkspaceJob;
					$module = 'WorkspaceJob';
									my $header = param("header");
					if ( paramMatch("wpload") )
					{    ##use 'wpload' since param 'uploadFile' interferes 'load'
							# no header
					}
					elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
						print_app_header( current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' )
					}
					WorkspaceJob::dispatch();
				}
				elsif ( $1 eq 'FuncSet' || $1 eq 'GeneSet' || $1 eq 'GenomeSet' || $1 eq 'ScafSet' ) {
					$args{yui_js} = Workspace::getStyles();
				}
			}
#			elsif ( $section eq 'Workspace' ) {
#				require Workspace;
				$module = 'Workspace';
				my $ws_yui_js = Workspace::getStyles();
				$pageTitle = "Workspace";
				my $header = param("header");
				if ( paramMatch("wpload") ) {
					##use 'wpload' since param 'uploadFile' interferes 'load'
					# no header
				}
				elsif ( ! $header && paramMatch("noHeader") eq "" ) {
					print_app_header( current => "MyIMG", yui_js => $ws_yui_js, help => 'IMGWorkspaceUserGuide.pdf' )
				}
				Workspace::dispatch();
			}
#			elsif ( $section eq 'WorkspaceGeneSet' ) {
#				require WorkspaceGeneSet;
				$module = 'WorkspaceGeneSet';
				my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
				$pageTitle = "Workspace Gene Sets";
				my $header = param("header");
				if ( paramMatch("wpload") ) {
					##use 'wpload' since param 'uploadFile' interferes 'load'
						# no header
				}
				elsif ( ! $header && paramMatch("noHeader") eq "" ) {
					print_app_header( current => "MyIMG", yui_js => $ws_yui_js, help => 'IMGWorkspaceUserGuide.pdf' )
				}
				WorkspaceGeneSet::dispatch();
			}
#			elsif ( $section eq 'WorkspaceFuncSet' ) {
#				require WorkspaceFuncSet;
				$module = 'WorkspaceFuncSet';
				my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
				$pageTitle = "Workspace Function Sets";
				my $header = param("header");
				if ( paramMatch("wpload") )
				{    ##use 'wpload' since param 'uploadFile' interferes 'load'
						# no header
				}
				elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
					print_app_header( current => "MyIMG", yui_js => $ws_yui_js, help => 'IMGWorkspaceUserGuide.pdf' )
				}
				WorkspaceFuncSet::dispatch();
			}
#			elsif ( $section eq 'WorkspaceGenomeSet' ) {
#				require WorkspaceGenomeSet;
				$module = 'WorkspaceGenomeSet';
				my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
				$pageTitle = "Workspace Genome Sets";
				my $header = param("header");
				if ( paramMatch("wpload") )
				{    ##use 'wpload' since param 'uploadFile' interferes 'load'
						# no header
				}
				elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
					print_app_header( current => "MyIMG", yui_js => $ws_yui_js, help => 'IMGWorkspaceUserGuide.pdf' )
				}
				WorkspaceGenomeSet::dispatch();
			}
#			elsif ( $section eq 'WorkspaceScafSet' ) {
#				require WorkspaceScafSet;
				$module = 'WorkspaceScafSet';
				my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
				$pageTitle = "Workspace Scaffold Sets";
				my $header = param("header");
				if ( paramMatch("wpload") )
				{    ##use 'wpload' since param 'uploadFile' interferes 'load'
						# no header
				}
				elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
					print_app_header( current => "MyIMG", yui_js => $ws_yui_js, help => 'IMGWorkspaceUserGuide.pdf' )
				}
				WorkspaceScafSet::dispatch();
			}
=cut

	my $page_table = {

		questions => sub {
			$module = 'Questions';
			$section_table->{ $module }->();
		},

		metaDetail => sub {
			$module = 'MetaDetail';
			$section_table->{ $module }->();
		},

		taxonDetail => sub {
			$module = 'TaxonDetail';
			$section_table->{ $module }->();
		},

		geneDetail => sub {
			$module = 'GeneDetail';
			$section_table->{ $module }->();
		},

        znormNote => sub {
			$module = 'WebUtil';
            %args = ( title => "Z-normalization", current => "FindGenes" );
            $sub = sub {
            	$module::printZnormNote();
            };
        },
        Imas => sub {
            $module = 'Imas';
            %args = ( title => 'Imas', gwt_module => "Imas" );
            $sub = sub {
            	$module::printForm();
			};
        },

        # non-standard
        message => sub {
            %args = ( title => 'Message', current => $cgi->param("menuSelection") );
			$module = 'IMG::Views::ViewMaker';
			$sub = {
				$module::print_message( $cgi->param('message') );
			};
        },
	};


	if ( $section && $section_table->{$section} ) {
		$module = is_valid_module( $section ) if ! $module;
		croak "$section does not seem to be a valid module!" if ! $module;
		$section_table->{$section}->();
	}
	elsif ( $page && $page_table->{$page} ) {
		die "no module specified" unless $module;
		$page_table->{$page}->();
	}
	else {
		say "No match found! Crap!";
	}

#	$args{numTaxons} = get_n_taxa();

	my ($ok, $err) = try_load_module( $module );
	$ok or croak "Unable to load class $module: $err";

	# capture output and save it to $output
	my $output;
	$| = 1;
	open local *STDOUT, ">", \$output;

	if (! ref $sub ) {
		$module::dispatch( $args{numTaxons} );
	}
	else {
		&$sub->();
	}

	close local *STDOUT;

	if (! $cgi->param('noHeader') && 'default' eq $tmpl) {
		print_app_header( %args );
	}

	return $output;



=cut

        # EXCEPTION
        elsif ( paramMatch("taxon_oid") && scalar( $cgi->param() ) < 2 ) {
            $module = 'TaxonDetail';
			%args = ( title => 'Taxon Details', current => "FindGenomes" );
            $args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';

            # if only taxon_oid is specified assume taxon detail page
            $session->param( "section", "TaxonDetail" );
            $session->param( "page",    "taxonDetail" );
#            TaxonDetail::dispatch();

        }
        # EXCEPTION!
        elsif ( $cgi->param("setTaxonFilter") && $env->{taxon_filter_oid_str} ) {
            $module = 'GenomeCart';
            %args = ( title => 'Genome Cart', current => "AnaCart" );
            # add to genome cart - ken
            require GenomeList;
            GenomeList::clearCache();
            $session->param( "lastCart", "genomeCart" );
#            GenomeCart::dispatch();
        }
        # EXCEPTION!
        elsif (! $cgi->param("setTaxonFilter") && ! $env->{taxon_filter_oid_str} ) {

            %args = ( title => "Genome Selection Message", current => "FindGenomes" );
            printMessage( "Saving 'no selections' is the same as selecting "
                  . "all genomes. Genome filtering is disabled.\n" );

        }
        # non-standard
        elsif ( paramMatch("uploadTaxonSelections") ) {
            $module = 'TaxonList';
            %args = ( title => 'Genome Browser', current => "FindGenomes", help => 'GenomeBrowser.pdf' );
            $sub = 'printTaxonTable';
            my $taxon_filter_oid_str = TaxonList::uploadTaxonSelections();
            setTaxonSelections($taxon_filter_oid_str);
#            TaxonList::printTaxonTable();
        }
        elsif ( $cgi->param("exportGenes") ) {
        	my $et = $cgi->param('exportType');
        	if ( 'excel' eq $et ) {
#				my @gene_oid = $cgi->param("gene_oid");
#				if ( scalar(@gene_oid) == 0 ) {
#					print_app_header();
#					webError("You must select at least one gene to export.");
#				}
				$tmpl = 'excel';
				%args = ( filename => 'gene_export$$.xls' );
				$module = 'GeneCartStor';
				$sub = sub {
					$module::printGenesToExcelLarge( \@gene_oid );
				};
#				GeneCartStor::printGenesToExcelLarge( \@gene_oid ); };
#				WebUtil::webExit(0);
			}
			elsif ( 'nucleic' eq $et ) {
				$module = 'GenerateArtemisFile';
				%args = ( title => "Gene Export" );
				$sub = sub {
					$module::prepareProcessGeneFastaFile();
				};
#				GenerateArtemisFile::prepareProcessGeneFastaFile();
			}
			elsif ( 'amino' eq $et ) {
				$module = 'GenerateArtemisFile';
				%args = ( title => "Gene Export" );
				$sub = sub {
					$module::prepareProcessGeneAAFastaFile();
				};
#				GenerateArtemisFile::prepareProcessGeneFastaFile(1);
			}
			elsif ( 'tab' eq $et ) {
				print_app_header( title => "Gene Export",);
				print "<h1>Gene Export</h1>\n";
				my @gene_oid = $cgi->param("gene_oid");
				my $nGenes   = @gene_oid;
				if ( $nGenes == 0 ) {
					print "<p>\n";
					webErrorNoFooter("Select genes to export first.");
				}
				print "</font>\n";
				print "<p>\n";
				print "Export in tab-delimited format for copying and pasting.\n";
				print "</p>\n";
				print "<pre>\n";
				WebUtil::printGeneTableExport( \@gene_oid );
				print "</pre>\n";
			}
		}
        elsif ( ( $env->{public_login} || $env->{user_restricted_site} ) && $cgi->param("logout") ) {

            #        if ( !$oldLogin && $env->{sso_enabled} ) {
            #
            #            # do no login log here
            #        } else {
            #            WebUtil::loginLog( 'logout main.pl', 'img' );
            #        }

            $session->param( "blank_taxon_filter_oid_str", "1" );
            $session->param( "oldLogin",                   0 );
            setTaxonSelections("");
            print_app_header( current => "logout" );

            print "<div id='message'>\n";
            print "<p>\n";
            print "Logged out.\n";
            print "</p>\n";
            print "</div>\n";
            print qq{
				<p>
				<a href='main.cgi'>Sign in</a>
				</p>
			};

            # sso
            if ( ! $env->{oldLogin} && $env->{sso_enabled} ) {
                $module = 'Caliban';
                $sub = sub {
                	$module::sso_logout;
                };
#                Caliban::logout(1);
            }
            else {
                $module = 'Caliban';
                $sub = sub {
                	$module::logout;
                };
#                Caliban::logout();
            }
        }
    }
    else {
        my $rurl = $cgi->param("redirect");
        if ( ( $env->{public_login} || $env->{user_restricted_site} ) && $rurl ) {
            redirecturl($rurl);
        }
        else {
            $env->{homePage} = 1;
            %args = ( current => "Home" );
        }
    }





 'dispatch';
 'printLandingPage';
 'test';
 'printZnormNote';
 'prepareProcessGeneFastaFile';
 'prepareProcessGeneAAFastaFile';
 'sso_logout';
 'logout';
 'printTaxonTable';
 'printForm';
	$args{numTaxons} = get_n_taxa();

	my ($ok, $err) = try_load_module( $module );
	$ok or croak "Unable to load class $module: $err";

	# capture output and save it to $output
	my $output;
	$| = 1;
	open local *STDOUT, ">", \$output;

	$module->dispatch( $args{numTaxons}, $args{numTaxons} );

	close local *STDOUT;

	if (! $cgi->param('noHeader') ) {
		print_app_header( %args );
	}
=cut


	return;
}

sub paramMatch {

	my $p = shift;

	for my $k (keys %cgi_params) {
		return $k if $k =~ /$p/;
	}
	return undef;

}

sub is_valid_module {
	my $m = shift;

	my $valid = valid_modules();
	for (@$valid) {
		# untaint
		return $_ if $_ eq $m;
	}
	return 0;
}

sub valid_modules {

	return [ qw(
About
AbundanceComparisons
AbundanceComparisonsSub
AbundanceProfiles
AbundanceProfileSearch
AbundanceTest
AbundanceToolkit
AllPwayBrowser
AnalysisProject
ANI
Artemis
BcNpIDSearch
BcSearch
BiosyntheticDetail
BiosyntheticStats
Caliban
Cart
ClustalW
CogCategoryDetail
CompareGeneModelNeighborhood
CompTaxonStats
CuraCartDataEntry
CuraCartStor
DataEvolution
DistanceTree
DotPlot
EbiIprScan
EggNog
EgtCluster
EmblFile
Fastbit
FindClosure
FindFunctionMERFS
FindFunctions
FindGenes
FindGenesBlast
FindGenesLucy
FindGenomes
FuncProfile
FunctionAlignment
FunctionProfiler
GenBankFile
GeneAnnotPager
GeneCartChrViewer
GeneCartDataEntry
GeneCassette
GeneCassetteProfiler
GeneCassetteSearch
GeneInfoPager
GeneNeighborhood
GenePageEnvBlast
GeneProfilerStor
GenerateArtemisFile
GenomeCart
GenomeGeneOrtholog
GenomeHits
GenomeList
GenomeProperty
GreenGenesBlast
Help
HmpTaxonList
HomologToolkit
HorizontalTransfer
ImgCompound
IMGContent
ImgCpdCartStor
ImgGroup
ImgNetworkBrowser
ImgPartsListBrowser
ImgPartsListCartStor
ImgPartsListDataEntry
IMGProteins
ImgPwayBrowser
ImgPwayCartDataEntry
ImgPwayCartStor
ImgReaction
ImgRxnCartStor
ImgStatsOverview
ImgTermAndPathTab
ImgTermBrowser
ImgTermCartDataEntry
ImgTermCartStor
ImgTermStats
Interpro
KeggMap
KeggPathwayDetail
Kmer
KoTermStats
MeshTree
MetaCyc
MetaFileGraph
MetaFileHits
MetaGeneDetail
MetaGeneTable
Metagenome
MetagenomeGraph
MetagenomeHits
MetagPhyloDist
MetaScaffoldGraph
Methylomics
MissingGenes
MpwPwayBrowser
MyBins
MyFuncCat
MyGeneDetail
MyIMG
NaturalProd
NcbiBlast
NrHits
Operon
OtfBlast
Pangenome
PathwayMaps
PdbBlast
PepStats
PfamCategoryDetail
PhyloClusterProfiler
PhyloCogs
PhyloDist
PhylogenProfiler
PhyloOccur
PhyloProfile
PhyloSim
Portal
ProfileQuery
ProjectId
ProteinCluster
RadialPhyloTree
Registration
RNAStudies
ScaffoldCart
ScaffoldGraph
ScaffoldHits
ScaffoldSearch
Sequence
SixPack
StudyViewer
TaxonCircMaps
TaxonDeleted
TaxonEdit
TaxonList
TaxonSearch
TigrBrowser
TreeFile
TreeQ
Vista
)];
}


1;
