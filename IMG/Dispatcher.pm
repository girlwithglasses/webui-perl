############################################################################
#	IMG::Dispatcher.pm
#
#	Parse query params and run the appropriate code
#
#	$Id: Dispatcher.pm 33827 2015-07-28 19:36:22Z aireland $
############################################################################
package IMG::Dispatcher;

use IMG::Util::Base 'Class';

use Class::Load ':all';

use String::CamelCase qw( camelize decamelize );

#with IMG::Views::ViewMaker;

#use Role::Tiny::With;

#with 'IMG::Views::ViewMaker';

#with 'IMG::Util::Factory', 'IMG::Views::Links';
#use GenomeCart ();
use WebUtil qw();

has 'env' => (
	is => 'rw',
	isa => HashRef,
	required => 1,
);

has 'session' => (
	is => 'rw',
	required => 1,
);

has 'cgi' => (
	is => 'ro',
	required => 1,
);

has 'cgi_params' => (
	is => 'rw',
	lazy => 1,
	builder => 1,
);

sub BUILDARGS {

	my $class = shift;
	my $tmpl_args;

	warn "args: " . Dumper \@_;

	if ( @_ && 1 < scalar( @_ ) ) {
		( %$tmpl_args ) = @_;
	}
	else {
		$tmpl_args = shift;
	}

	return $tmpl_args;
}

sub _build_cgi_params {

	my $self = shift;

	my %params = $self->cgi->Vars;

	return \%params;
}

=head3 dispatch_page

@param n_taxa => number of taxa in the current cart

=cut

sub dispatch_page {

	my $self = shift;

	my $prep_args = $self->prepare;

	return $self->run( @_, %$prep_args );

}

=head3 prepare

Parse the input query params and find the appropriate module, subroutine,
template, and template arguments to use.

@return hashref with keys

		sub    - subroutine to run
		module - module to load
		tmpl   - outer page template to use (defaults to 'default')
		tmpl_args  - template arguments

=cut

sub prepare {

	my $self = shift;

	my $module;           # the module to load
	my %tmpl_args;        # arguments for populating page templates
	my $sub = 'dispatch'; # subroutine to run (if not dispatch)
	my $tmpl = 'default'; # which template to use for the page

	my $page = $self->cgi->param('page') || "";
	my $section = $self->cgi->param('section');

	my $section_table = {
        AbundanceProfileSearch => sub {
            %tmpl_args = ( title => 'Abundance Profile Search', current => "CompareGenomes", yui_js => 'genomeHeaderJson', help => "userGuide_m.pdf#page=" );
			$tmpl_args{help} .= ( $self->env->{include_metagenomes} )
            ? "19"
            : "51";
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        StudyViewer => sub {
            %tmpl_args = ( title => "Metagenome Study Viewer", current => "FindGenomes", include_scripts => 'treeview.tt', include_styles => 'treeview.tt' );
        },
        ANI => sub {
            %tmpl_args = ( title => 'ANI', current => "CompareGenomes" );
            if ( $page eq 'pairwise' ) {
                $tmpl_args{yui_js} = 'genomeHeaderJson';
            }
            elsif ( $page eq 'overview' ) {
                $tmpl_args{yui_js} = 'meshTreeHeader';
            }
        },
        Caliban => sub {
            return;
        },
        Portal => sub {
            %tmpl_args = ( current => "Find Genomes");
        },
        ProjectId => sub {
            %tmpl_args = ( title => "Project ID List", current => "FindGenomes" );
        },
        ScaffoldSearch => sub {
            %tmpl_args = ( title => 'Scaffold Search', current => "FindGenomes", yui_js => 'genomeHeaderJson' );
        },
        MeshTree => sub {
            %tmpl_args = ( title => "Mesh Tree", current => "FindFunctions", yui_js => 'meshTreeHeader' );
        },
        AbundanceProfiles => sub {
        	%tmpl_args = ( title => 'Abundance Profiles', current => "CompareGenomes", yui_js => 'genomeHeaderJson', help => "userGuide_m.pdf#page=" );
			$tmpl_args{help} .= ( $self->env->{include_metagenomes} )
            ? "18"
            : "49";
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceTest => sub {
            %tmpl_args = ( title => "Abundance Test", current => "CompareGenomes" );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceComparisons => sub {
            %tmpl_args = ( title => 'Abundance Comparisons', current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{help} = 'userGuide_m.pdf#page=20' if $self->env->{include_metagenomes};
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceComparisonsSub => sub {
            %tmpl_args = ( title => 'Function Category Comparisons', current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{help} = 'userGuide_m.pdf#page=23' if $self->env->{include_metagenomes};
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        AbundanceToolkit => sub {
            %tmpl_args = ( title => "Abundance Toolkit", current => "CompareGenomes" );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        Artemis => sub {
            %tmpl_args = ( title => 'Artemis', current => "FindGenomes", yui_js => 'genomeHeaderJson' );
            my $from = $self->cgi->param("from");
            if ( $from eq "ACT" || $page =~ /^ACT/ || $page =~ /ACT$/ ) {
                $tmpl_args{current} = "CompareGenomes";
            }
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ClustalW => sub {
            %tmpl_args = ( title => "Clustal - Multiple Sequence Alignment", current => "AnaCart", help => "DistanceTree.pdf#page=6" );
            $tmpl_args{timeout_mins} = 40;    # timeout in 40 minutes
        },
        CogCategoryDetail => sub {
            %tmpl_args = ( title => 'COG', current => "FindFunctions" );
            $tmpl_args{title} = 'KOG' if $page =~ /kog/i;
        },
        CompTaxonStats => sub {
            %tmpl_args = ( title => "Genome Statistics", current => "CompareGenomes" );
        },
        CompareGenomes => sub {
            if ( $self->paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%tmpl_args = ( filename => "stats_export$$.xls" );
            }
            else {
                %tmpl_args = ( title => 'Compare Genomes', current => "CompareGenomes" );
            }
        },
        GenomeGeneOrtholog => sub {
            %tmpl_args = ( title => 'Genome Gene Ortholog', current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
        },
        Pangenome => sub {
            if ( $self->paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%tmpl_args = ( filename => "stats_export$$.xls" );
            }
            else {
                %tmpl_args = ( title => 'Pangenome', current => "Pangenome" );
            }
        },
        CompareGeneModelNeighborhood => sub {
            %tmpl_args = ( title => "Compare Gene Models", current => "CompareGenomes" );
        },
        CuraCartStor => sub {
            %tmpl_args = ( title => 'Curation Cart', current => "AnaCart" );
            $self->session->param( "lastCart", "curaCart" );
        },
        CuraCartDataEntry => sub {
            %tmpl_args = ( title => "Curation Cart Data Entry", current => "AnaCart" );
            $self->session->param( "lastCart", "curaCart" );
        },
        DataEvolution => sub {
            %tmpl_args = ( title => "Data Evolution", current => "news" );
        },
        EgtCluster => sub {
            %tmpl_args = ( title => 'Genome Clustering', current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{help} = "DistanceTree.pdf#page=5" if $self->cgi->param('method') && $self->cgi->param('method') eq 'hier';
            $tmpl_args{timeout_mins} = 30;    # timeout in 30 minutes
        },
        EmblFile => sub {
            %tmpl_args = ( title => "EMBL File Export", current => "FindGenomes" );
        },
        BcSearch => sub {
            %tmpl_args = ( title => "Biosynthetic Cluster Search", current => "getsme", yui_js => 'meshTreeHeader' );
            $tmpl_args{title} = "Secondary Metabolite Search" if $page eq 'npSearches' || $page eq 'npSearchResult';
        },
        BiosyntheticStats => sub {
            %tmpl_args = ( title => "Biosynthetic Cluster Statistics", current => "getsme", yui_js => 'meshTreeHeader' );
        },
        BiosyntheticDetail => sub {
            %tmpl_args = ( title => "Biosynthetic Cluster", current => "getsme" );
        },
        NaturalProd => sub {
            %tmpl_args = ( title => "Secondary Metabolite Statistics", current => "getsme", yui_js => 'meshTreeHeader' );
        },
        BcNpIDSearch => sub {
            %tmpl_args = ( title => "Biosynthetic Cluster / Secondary Metabolite Search by ID", current => "getsme" );
        },
        FindFunctions => sub {
			%tmpl_args = ( title => 'Find Functions', current => "FindFunctions", yui_js => 'genomeHeaderJson' );
            if ( $page eq 'findFunctions' ) {
				$tmpl_args{help} = 'FunctionSearch.pdf';
            }
            elsif ( $page eq 'ffoAllSeed' ) {
				$tmpl_args{help} = 'SEED.pdf';
            }
            elsif ( $page eq 'ffoAllTc' ) {
                $tmpl_args{help} = 'TransporterClassification.pdf';
            }
        },
        FindFunctionMERFS => sub {
            %tmpl_args = ( title => "Find Functions", current => "FindFunctions" );
        },
        FindGenes => sub {
			%tmpl_args = ( title => 'Find Genes', current => "FindGenes", yui_js => 'genomeHeaderJson' );
            if (   $page eq 'findGenes'
                || $page eq 'geneSearch'
                || ( $page ne 'geneSearchForm' && ! $self->paramMatch("fgFindGenes") ) ) {
                $tmpl_args{help} = 'GeneSearch.pdf';
            }
        },
        FindGenesLucy => sub {
            %tmpl_args = ( title => "Find Genes by Keyword", current => "FindGenesLucy", help => 'GeneSearch.pdf' );
        },
        FindGenesBlast => sub {
            %tmpl_args = ( title => "Find Genes - BLAST", current => "FindGenes", yui_js => 'genomeHeaderJson', help => 'Blast.pdf' );
        },
        FindGenomes => sub {
            %tmpl_args = ( current => 'FindGenomes', title => 'Find Genomes' );
            if ( $page eq 'findGenomes' ) {
            	$tmpl_args{help} = 'GenomeBrowser.pdf';
            }
            elsif ( $page eq 'genomeSearch' ) {
				$tmpl_args{help} = 'GenomeSearch.pdf';
            }
        },
        FunctionAlignment => sub {
            %tmpl_args = ( title => "Function Alignment", current => "FindFunctions", help => 'FunctionAlignment.pdf' );
        },
        FuncCartStor => sub {
            %tmpl_args = ( current => 'AnaCart', help => 'FunctionCart.pdf', title => 'Function Cart' );
            $tmpl_args{title} = "Assertion Profile" if $self->paramMatch("AssertionProfile");

            if ( $page eq 'funcCart' && $self->env->{enable_genomelistJson} ) {
            ## Eh?!?!
            	$tmpl_args{help} = GenomeListJSON();
            }
            $self->session->param( "lastCart", "funcCart" );
        },
        FuncProfile => sub {
            %tmpl_args = ( title => "Function Profile", current => "AnaCart" );
        },
        FunctionProfiler => sub {
            %tmpl_args = ( title => 'Function Profile', current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
        },
        DotPlot => sub {
            %tmpl_args = ( title => 'Dotplot', current => "CompareGenomes", no_menu => "Synteny Viewers", yui_js => 'genomeHeaderJson', help => 'Dotplot.pdf' );
            $tmpl_args{timeout_mins} = 40;    # timeout in 40 minutes
        },
        DistanceTree => sub {
            %tmpl_args = ( title => 'Distance Tree', current => "CompareGenomes", yui_js => 'genomeHeaderJson', help => 'DistanceTree.pdf' );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        RadialPhyloTree => sub {
            %tmpl_args = ( title => "Radial Phylogenetic Tree", current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        Kmer => sub {
            %tmpl_args = ( title => "Kmer Frequency Analysis", current => "FindGenomes" ) if ! $self->paramMatch("export");
            $tmpl_args{timeout_mins} = 20;
        },
        GenBankFile => sub {
            %tmpl_args = ( title => "GenBank File Export", current => "FindGenomes" );
        },
        GeneAnnotPager => sub {
            %tmpl_args = ( title => "Comparative Annotations", current => "FindGenomes" );
        },
        GeneInfoPager => sub {
            %tmpl_args = ( title => "Download Gene Information", current => "FindGenomes" );
            $tmpl_args{timeout_mins} = 60;
        },
        GeneCartChrViewer => sub {
            %tmpl_args = ( title => "Circular Chromosome Viewer", current => "AnaCart" );
            $self->session->param( "lastCart", "geneCart" );
        },
        GeneCartDataEntry => sub {
            %tmpl_args = ( title => "Gene Cart Data Entry", current => "AnaCart" );
            $self->session->param( "lastCart", "geneCart" );
        },
        GeneCartStor => sub  {
            %tmpl_args = ( current =>  'AnaCart', title => 'Gene Cart' );
            my $last_cart = ( $self->paramMatch('addFunctionCart') )
            ? 'funcCart'
            : 'geneCart';
            $self->session->param( "lastCart", $last_cart );

            if ( $page eq 'geneCart' ) {
				$tmpl_args{help} = 'GeneCart.pdf';
                $tmpl_args{yui_js} = 'genomeHeaderJson' if $self->env->{enable_genomelistJson};
			}
        },
        MyGeneDetail => sub {
            %tmpl_args = ( title => "My Gene Detail", current => "FindGenes" );
        },
        Help => sub {
            %tmpl_args = ( title => "Help", current => "about" );
        },
        GeneDetail => sub {
            %tmpl_args = ( title => "Gene Details", current => "FindGenes" );
        },
        MetaGeneDetail => sub {
            %tmpl_args = ( title => "Metagenome Gene Details", current => "FindGenes" );
        },
        MetaGeneTable => sub {
            %tmpl_args = ( title => "Gene List", current => "FindGenes" );
        },
        GeneNeighborhood => sub {
            %tmpl_args = ( title => "Gene Neighborhood", current => "FindGenes" );
            $tmpl_args{timeout_mins} = 20;
        },
        FindClosure => sub {
            %tmpl_args = ( title => "Functional Closure", current => "AnaCart" );
        },
        GeneCassette => sub {
            %tmpl_args = ( title => "IMG Cassette", current => "CompareGenomes" );
            $tmpl_args{timeout_mins} = 20;
        },
        MetagPhyloDist => sub {
            %tmpl_args = ( title => "Phylogenetic Distribution", current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
        },
        Cart => sub {
            %tmpl_args = ( title => "My Cart", current => "AnaCart" );
        },
        GeneCassetteSearch => sub {
            %tmpl_args = ( title => "IMG Cassette Search", current => "FindGenes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{timeout_mins} = 20;
        },
        TreeFile => sub {
            %tmpl_args = ( title => "IMG Tree", current => "FindGenomes" );
        },
        HorizontalTransfer => sub {
            %tmpl_args = ( title => "Horizontal Transfer", current => "FindGenomes" );
        },
        ImgTermStats => sub {
            %tmpl_args = ( title => "IMG Term", current => "FindFunctions" );
        },
        KoTermStats => sub {
            %tmpl_args = ( title => "KO Stats", current => "FindFunctions" );
        },
        HmpTaxonList => sub {
            %tmpl_args = ( title => 'HMP Genome List', current => "FindGenomes" );
            if ( $self->paramMatch("_excel") ) {
                $tmpl = 'excel';
                %tmpl_args = ( filename => "genome_export$$.xls" );
            }
        },
        EggNog => sub {
            %tmpl_args = ( title => "EggNOG", current => "FindFunctions" );
        },
        Interpro => sub {
            %tmpl_args = ( title => "Interpro", current => "FindFunctions" );
        },
        MetaCyc => sub {
            %tmpl_args = ( title => "MetaCyc", current => "FindFunctions" );
        },
        Fastbit => sub {
            %tmpl_args = ( title => "Fastbit Test", current => "FindFunctions", yui_js => 'genomeHeaderJson' );
        },
        AnalysisProject => sub {
            %tmpl_args = ( title => "Analysis Project", current => "FindGenomes" );
        },
        GeneCassetteProfiler => sub {
            %tmpl_args = ( title => "Phylogenetic Profiler", current => "FindGenes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ImgStatsOverview => sub {
            %tmpl_args = ( title => "IMG Stats Overview", current => "ImgStatsOverview" );
            if ( $self->cgi->param('excel') && $self->cgi->param('excel') eq 'yes' ) {
            	$tmpl = 'excel';
            	%tmpl_args = ( filename => "stats_export$$.xls" );
            }
        },
        TaxonEdit => sub {
            %tmpl_args = ( title => "Taxon Edit", current => "Taxon Edit" );
        },
        GenePageEnvBlast => sub {
            %tmpl_args = ( title => "SNP BLAST",);
        },
        GeneProfilerStor => sub {
            %tmpl_args = ( title => "Gene Profiler", current => "AnaCart" );
            $self->session->param( "lastCart", "geneCart" );
        },
        GenomeProperty => sub {
            %tmpl_args = ( title => "Genome Property" );
        },
        HomologToolkit => sub {
            %tmpl_args = ( title => "Homolog Toolkit", current => "FindGenes" );
        },
        ImgCompound => sub {
            %tmpl_args = ( title => "IMG Compound", current => "FindFunctions", yui_js => 'meshTreeHeader' );
        },
        ImgCpdCartStor => sub {
            %tmpl_args = ( title => "IMG Compound Cart", current => "AnaCart" );
            $self->session->param( "lastCart", "imgCpdCart" );
        },
        ImgTermAndPathTab => sub {
            %tmpl_args = ( title => "IMG Terms & Pathways", current => "FindFunctions" );
        },
        ImgNetworkBrowser => sub {
            %tmpl_args = ( title => "IMG Network Browser", current => "FindFunctions", js => '', redirect_url => 'imgterms.html' );
        },
        ImgPwayBrowser => sub {
            %tmpl_args = ( title => "IMG Pathway Browser", current => "FindFunctions" );
        },
        ImgPartsListBrowser => sub {
            %tmpl_args = ( title => "IMG Parts List Browser", current => "FindFunctions" );
        },
        ImgPartsListCartStor => sub {
            %tmpl_args = ( title => "IMG Parts List Cart", current => "AnaCart" );
            $self->session->param( "lastCart", "imgPartsListCart" );
        },
        ImgPartsListDataEntry => sub {
            %tmpl_args = ( title => "IMG Parts List Data Entry", current => "AnaCart" );
            $self->session->param( "lastCart", "imgPartsListCart" );
        },
        ImgPwayCartDataEntry => sub {
            %tmpl_args = ( title => "IMG Pathway Cart Data Entry", current => "AnaCart" );
            $self->session->param( "lastCart", "imgPwayCart" );
        },
        ImgPwayCartStor => sub {
            %tmpl_args = ( title => "IMG Pathway Cart", current => "AnaCart" );
            $self->session->param( "lastCart", "imgPwayCart" );
        },
        ImgReaction => sub {
            %tmpl_args = ( title => "IMG Reaction", current => "FindFunctions" );
        },
        ImgRxnCartStor => sub {
            %tmpl_args = ( title => "IMG Reaction Cart", current => "AnaCart" );
            $self->session->param( "lastCart", "imgRxnCart" );
        },
        ImgTermBrowser => sub {
            %tmpl_args = ( title => "IMG Term Browser", current => "FindFunctions" );
        },
        ImgTermCartDataEntry => sub {
            %tmpl_args = ( title => "IMG Term Cart Data Entry", current => "AnaCart" );
            $self->session->param( "lastCart", "imgTermCart" );
        },
        ImgTermCartStor => sub {
            %tmpl_args = ( title => "IMG Term Cart", current => "AnaCart" );
            $self->session->param( "lastCart", "imgTermCart" );
        },
        KeggMap => sub {
            %tmpl_args = ( title => "KEGG Map", current => "FindFunctions" );
            $tmpl_args{timeout_mins} = 20;
        },
        KeggPathwayDetail => sub {
            %tmpl_args = ( title => "KEGG Pathway Detail", current => "FindFunctions", yui_js => 'genomeHeaderJson' );
        },
        PathwayMaps => sub {
            %tmpl_args = ( title => "Pathway Maps", current => "PathwayMaps" );
            $tmpl_args{timeout_mins} = 20;
        },
        Metagenome => sub {
            %tmpl_args = ( title => "Metagenome", current => "FindGenomes" );
        },
        AllPwayBrowser => sub {
            %tmpl_args = ( title => "All Pathways", current => "FindFunctions" );
        },
        MpwPwayBrowser => sub {
            %tmpl_args = ( title => "Mpw Pathway Browser", current => "FindFunctions" );
        },
        GenomeHits => sub {
            %tmpl_args = ( title => "Genome Hits", current => "CompareGenomes", yui_js => 'genomeHeaderJson' );
            $tmpl_args{timeout_mins} = 20;    # timeout in 20 minutes
        },
        ScaffoldHits => sub {
            %tmpl_args = ( title => 'Scaffold Hits', current => "AnaCart" );
        },
        ScaffoldCart => sub {
            %tmpl_args = ( title => 'Scaffold Cart', current => "AnaCart" );
            if (   $self->paramMatch("exportScaffoldCart")
                || $self->paramMatch("exportFasta") ) {
            	# export excel
                $self->session->param( "lastCart", "scaffoldCart" );
            }
            elsif ( ! $self->paramMatch("addSelectedToGeneCart") ) {
                $self->session->param( "lastCart", "scaffoldCart" );
            }
        },
        GenomeCart => sub {
            %tmpl_args = ( title => 'Genome Cart', current => "AnaCart" );
            $self->session->param( "lastCart", "genomeCart" );
        },
        MetagenomeHits => sub {
            %tmpl_args = ( title => 'Genome Hits', current => "FindGenomes" );
        },
        MetaFileHits => sub {
            %tmpl_args = ( title => 'Metagenome Hits', current => "FindGenomes" );
        },
        MetagenomeGraph => sub {
            %tmpl_args = ( title => 'Genome Graph', current => "FindGenomes" );
            $tmpl_args{timeout_mins} = 40;
        },
        MetaFileGraph => sub {
            %tmpl_args = ( title => 'Metagenome Graph', current => "FindGenomes" );
        },
        MissingGenes => sub {
            %tmpl_args = ( title => "MissingGenes", current => "AnaCart" );
        },
        MyFuncCat => sub {
            %tmpl_args = ( title => "My Functional Categories", current => "AnaCart" );
        },
        MyIMG => sub {
            %tmpl_args = ( title => 'My IMG', current => "MyIMG", help => 'MyIMG4.pdf' );
            if ( $page eq 'taxonUploadForm' ) {
            	delete $tmpl_args{help};
            	$tmpl_args{current} = 'AnaCart';
            }
        },
        ImgGroup => sub {
            %tmpl_args = ( title => "MyIMG", current => "MyIMG" );
        },
        MyBins => sub {
            %tmpl_args = ( title => "My Bins", current => "MyIMG" );
        },
        About => sub {
            %tmpl_args = ( title => "About", current => "about" );
        },
        NcbiBlast => sub {
            %tmpl_args = ( title => "NCBI BLAST", current => "FindGenes" );
        },
        NrHits => sub {
            %tmpl_args = ( title => "Gene Details" );
        },
        Operon => sub {
            %tmpl_args = ( title => "Operons", current => "FindGenes" );
        },
        OtfBlast => sub {
            %tmpl_args = ( title => 'Gene Details', current => "FindGenes", yui_js => 'genomeHeaderJson' );
        },
        PepStats => sub {
            %tmpl_args = ( title => "Peptide Stats", current => "FindGenes" );
        },
        PfamCategoryDetail => sub {
            %tmpl_args = ( title => "Pfam Category", current => "FindFunctions" );
        },
        PhyloCogs => sub {
            %tmpl_args = ( title => 'Phylogenetic Marker COGs', current => "CompareGenomes" );
        },
        PhyloDist => sub {
            %tmpl_args = ( title => "Phylogenetic Distribution", current => "FindGenes" );
        },
        PhyloOccur => sub {
            %tmpl_args = ( title => "Phylogenetic Occurrence Profile", current => "AnaCart" );
        },
        PhyloProfile => sub {
            %tmpl_args = ( title => "Phylogenetic Profile", current => "AnaCart" );
        },
        PhyloSim => sub {
            %tmpl_args = ( title => "Phylogenetic Similarity Search", current => "FindGenes" );
        },
        PhyloClusterProfiler => sub {
            %tmpl_args = ( title => 'Phylogenetic Profiler using Clusters', current => "FindGenes" );
        },
        PhylogenProfiler => sub {
            %tmpl_args = ( title => 'Phylogenetic Profiler', current => "FindGenes", yui_js => 'genomeHeaderJson' );
        },
        ProteinCluster => sub {
            %tmpl_args = ( title => "Protein Cluster", current => "FindGenes" );
        },
        ProfileQuery => sub {
            %tmpl_args = ( title => "Profile Query", current => "FindFunctions" );
        },
        Registration => sub {
            %tmpl_args = ( title => "Registration", current => "MyIMG" );
        },
        SixPack => sub {
            %tmpl_args = ( title => "Six Frame Translation", current => "FindGenes" );
        },
        Sequence => sub {
            %tmpl_args = ( title => "Six Frame Translation", current => "FindGenes" );
        },
        ScaffoldGraph => sub {
            %tmpl_args = ( title => "Chromosome Viewer", current => "FindGenomes" );
        },
        MetaScaffoldGraph => sub {
            %tmpl_args = ( title => "Chromosome Viewer", current => "FindGenomes" );
        },
        TaxonCircMaps => sub {
            %tmpl_args = ( title => "Circular Map", current => "FindGenomes" );
        },
        GenerateArtemisFile => sub {
            %tmpl_args = ( current => "FindGenomes" );
        },
        GenomeList => sub {
            %tmpl_args = ( title => "Genome List", current => "FindGenomes" );
        },
        TaxonDetail => sub {
			%tmpl_args = ( title => 'Taxon Details', current => "FindGenomes" );
            $tmpl_args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';
        },
        TaxonDeleted => sub {
            %tmpl_args = ( title => "Taxon Deleted", current => "FindGenomes" );
        },
        MetaDetail => sub {
			%tmpl_args = ( title => 'Microbiome Details', current => "FindGenomes" );
            $tmpl_args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';
        },
        TaxonList => sub {
			%tmpl_args = ( title => 'Taxon Browser', current => 'FindGenomes' );
			$tmpl_args{title} = 'Category Browser' if $page eq 'categoryBrowser';
            if ( $self->paramMatch("_excel") ) {
            	$tmpl = 'excel';
            	%tmpl_args = ( filename => "genome_export$$.xls" );
#                printExcelHeader("genome_export$$.xls");
            }
            elsif (   $page eq 'taxonListAlpha'
                    || $page eq 'gebaList'
                    || $page eq 'selected' ) {
				$tmpl_args{help} = 'GenomeBrowser.pdf';
            }
        },
        TaxonSearch => sub {
            %tmpl_args = ( title => "Taxon Search", current => "FindGenomes" );
        },
        TigrBrowser => sub {
            %tmpl_args = ( title => "TIGRfam Browser", current => "FindFunctions" );
        },
        TreeQ => sub {
            %tmpl_args = ( title => "Dynamic Tree View" );
        },
        Vista => sub {
            %tmpl_args = ( title => 'VISTA', current => "CompareGenomes" );
			$tmpl_args{title} = 'Synteny Viewers' if $page eq 'toppage';
        },
        IMGContent => sub {
            %tmpl_args = ( title => "IMG Content", current => "IMGContent" );
        },
        IMGProteins => sub {
            %tmpl_args = ( title => "Proteomics", current => "Proteomics", help => "Proteomics.pdf" );
        },
        Methylomics => sub {
            %tmpl_args = ( title => "Methylomics Experiments", current => "Methylomics", help => "Methylomics.pdf" );
        },
        RNAStudies => sub {
            %tmpl_args = ( title => "RNASeq Expression Studies", current => "RNAStudies", help => "RNAStudies.pdf" );
            $tmpl_args{timeout_mins} = 20;
            if ( $self->paramMatch("samplePathways") ) {
                $tmpl_args{title} = "RNASeq Studies: Pathways";
            }
            elsif ( $self->paramMatch("describeSamples") ) {
                $tmpl_args{title} = "RNASeq Studies: Describe";
            }
        },
        Questions => sub {
            %tmpl_args = ( title => "Questions and Comments", current => "about" );
		},
		Workspace => sub {
			%tmpl_args = ( title => 'Workspace', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => 'workspaceStyles' );
		},
		WorkspaceFuncSet => sub {
			%tmpl_args = ( title => 'Workspace Function Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => 'workspaceStyles' );
		},
		WorkspaceGeneSet => sub {
			%tmpl_args = ( title => 'Workspace Gene Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => 'workspaceStyles' );
		},
		WorkspaceGenomeSet => sub {
			%tmpl_args = ( title => 'Workspace Genome Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => 'workspaceStyles' );
		},
		WorkspaceJob => sub {
			%tmpl_args = ( title => 'Workspace Jobs', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' );
		},
		WorkspaceRuleSet => sub {
			%tmpl_args = ( title => 'Workspace Rule Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf' );
		},
		WorkspaceScafSet => sub {
			%tmpl_args = ( title => 'Workspace Scaffold Sets', current => "MyIMG", help => 'IMGWorkspaceUserGuide.pdf', yui_js => 'workspaceStyles' );
		},
        np => sub {
            $module = 'NaturalProd';
            %tmpl_args = ( title => "Biosynthetic Clusters and Secondary Metabolites", current => "getsme", help => 'GetSMe_intro.pdf' );
            $sub = 'printLandingPage';
        },
        GenomeListJSON => sub {
            %tmpl_args = ( current => "AnaCart", yui_js => 'genomeHeaderJson' );
#            GenomeListJSON::test();
			$module = 'GenomeListJSON';
			$sub = 'test';
        },
	};

	# extras that use existing data:
	$section_table->{ CompareGenomesTab } = sub {
		$module = 'CompareGenomes';
		$section_table->{ $module }->();
	};
	$section_table->{ FuncCartStorTab } = sub {
		$module = 'FuncCartStor';
		$section_table->{ $module }->();
	};
	$section_table->{ GeneCartStorTab } = sub {
		$module = 'GeneCartStor';
		$section_table->{ $module }->();
	};

	# extras that print headers:
	$section_table->{ EbiIprScan } = sub {
		%tmpl_args = ( title => 'EBI InterPro Scan' );
		print header( -header => "text/html" );
	};
	$section_table->{ GreenGenesBlast } = sub {
		%tmpl_args = ( title => 'Green Genes BLAST' );
		print header( -header => "text/html" );
	};
	$section_table->{ PdbBlast } = sub {
		%tmpl_args = ( title => 'Protein Data Bank BLAST' );
		print header( -header => "text/html" );
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
					delete $tmpl_args{yui_js};
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
					$tmpl_args{yui_js} = Workspace::getStyles();
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

		# no incidences
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

		# not found
        znormNote => sub {
			$module = 'WebUtil';
            %tmpl_args = ( title => "Z-normalization", current => "FindGenes" );
            $sub = 'printZnormNote';
        },

        # not found
        Imas => sub {
            $module = 'Imas';
            %tmpl_args = ( title => 'Imas', gwt_module => "Imas" );
            $sub = 'printForm';
        },

        # non-standard
        message => sub {
            %tmpl_args = ( title => 'Message', current => $self->cgi->param("menuSelection") );
			$module = 'IMG::Views::ViewMaker';
			$sub = 'print_message';
#			$sub = sub {
#				$module->print_message( undef, $self->cgi->param('message') );
#			};
        },
	};



	if ( $section && $section_table->{$section} ) {
		$module = $self->is_valid_module( $section ) if ! $module;
		croak "$section does not seem to be a valid module!" if ! $module;
		$section_table->{$section}->();
	}
	elsif ( $page && $page_table->{$page} ) {
		die "no module specified" unless $module;
		$page_table->{$page}->();
	}
	else {

		croak "No match found for cgi input: " . Dumper $self->cgi_params;

	}

	warn "Returning from prepare with args sub: $sub, module: $module, tmpl: $tmpl";

	return {
		sub       => $sub,
		module    => $module,
		tmpl_args => \%tmpl_args,
		tmpl      => $tmpl
	};

}

sub run {

	my $self = shift;
	my $arg_h;
	%$arg_h = @_;


#	warn "entering run; args: " . Dumper $arg_h;

	# make sure that we know how many taxa we have
	croak unless defined $arg_h->{n_taxa};

#	$tmpl_args{numTaxons} = get_n_taxa();

	my ($ok, $err) = try_load_class( $arg_h->{module} );
	$ok or croak "Unable to load class " . $arg_h->{module} . ": $err";

#	warn "Loaded module OK!";

	my $to_do;
	if (! ref $arg_h->{sub} ) {
		warn "Setting to_do to " . $arg_h->{module} .'::' . $arg_h->{sub};
		$to_do = \&{ $arg_h->{module} .'::' . $arg_h->{sub} };
	}
	else {
		$to_do = $arg_h->{sub};
	}

	if ($arg_h->{tmpl_args}{timeout_mins}) {
#		warn "setting timeout...";
		WebUtil::timeout( $arg_h->{tmpl_args}{timeout_mins} );
	}

#	warn "Running the sub";

	# capture output and save it to $output
	my $output;
	$| = 1;

	local $@;
	eval {

		open local *STDOUT, ">", \$output;

		$to_do->( $arg_h->{n_taxa} );

		close local *STDOUT;

	};

	if ($@) {
		croak $@;
	}

	$arg_h->{output} = $output;

	warn "I got this output: $output";

	return $arg_h;

#	if (! $cgi->param('noHeader') && 'default' eq $arg_h->{tmpl}) {
#		print_app_header( %tmpl_args );
#	}
#	return $output;

}

=cut

        # EXCEPTION
        elsif ( paramMatch("taxon_oid") && scalar( $cgi->param() ) < 2 ) {
            $module = 'TaxonDetail';
			%tmpl_args = ( title => 'Taxon Details', current => "FindGenomes" );
            $tmpl_args{help} = 'GenerateGenBankFile.pdf' if $page eq 'taxonArtemisForm';

            # if only taxon_oid is specified assume taxon detail page
            $self->session->param( "section", "TaxonDetail" );
            $self->session->param( "page",    "taxonDetail" );
#            TaxonDetail::dispatch();

        }
        # EXCEPTION!
        elsif ( $cgi->param("setTaxonFilter") && $self->env->{taxon_filter_oid_str} ) {
            $module = 'GenomeCart';
            %tmpl_args = ( title => 'Genome Cart', current => "AnaCart" );
            # add to genome cart - ken
            require GenomeList;
            GenomeList::clearCache();
            $self->session->param( "lastCart", "genomeCart" );
#            GenomeCart::dispatch();
        }
        # EXCEPTION!
        elsif (! $cgi->param("setTaxonFilter") && ! $self->env->{taxon_filter_oid_str} ) {

            %tmpl_args = ( title => "Genome Selection Message", current => "FindGenomes" );
            printMessage( "Saving 'no selections' is the same as selecting "
                  . "all genomes. Genome filtering is disabled.\n" );

        }
        # non-standard
        elsif ( paramMatch("uploadTaxonSelections") ) {
            $module = 'TaxonList';
            %tmpl_args = ( title => 'Genome Browser', current => "FindGenomes", help => 'GenomeBrowser.pdf' );
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
				%tmpl_args = ( filename => 'gene_export$$.xls' );
				$module = 'GeneCartStor';
				$sub = sub {
					$module::printGenesToExcelLarge( \@gene_oid );
				};
#				GeneCartStor::printGenesToExcelLarge( \@gene_oid ); };
#				WebUtil::webExit(0);
			}
			elsif ( 'nucleic' eq $et ) {
				$module = 'GenerateArtemisFile';
				%tmpl_args = ( title => "Gene Export" );
				$sub = sub {
					$module::prepareProcessGeneFastaFile();
				};
#				GenerateArtemisFile::prepareProcessGeneFastaFile();
			}
			elsif ( 'amino' eq $et ) {
				$module = 'GenerateArtemisFile';
				%tmpl_args = ( title => "Gene Export" );
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
        elsif ( ( $self->env->{public_login} || $self->env->{user_restricted_site} ) && $cgi->param("logout") ) {

            #        if ( !$oldLogin && $self->env->{sso_enabled} ) {
            #
            #            # do no login log here
            #        } else {
            #            WebUtil::loginLog( 'logout main.pl', 'img' );
            #        }

            $self->session->param( "blank_taxon_filter_oid_str", "1" );
            $self->session->param( "oldLogin",                   0 );
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
            if ( ! $self->env->{oldLogin} && $self->env->{sso_enabled} ) {
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
        if ( ( $self->env->{public_login} || $self->env->{user_restricted_site} ) && $rurl ) {
            redirecturl($rurl);
        }
        else {
            $self->env->{homePage} = 1;
            %tmpl_args = ( current => "Home" );
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
	$tmpl_args{numTaxons} = get_n_taxa();

	my ($ok, $err) = try_load_module( $module );
	$ok or croak "Unable to load class $module: $err";

	# capture output and save it to $output
	my $output;
	$| = 1;
	open local *STDOUT, ">", \$output;

	$module->dispatch( $tmpl_args{numTaxons}, $tmpl_args{numTaxons} );

	close local *STDOUT;

	if (! $cgi->param('noHeader') ) {
		print_app_header( %tmpl_args );
	}
=cut

sub paramMatch {

	my $self = shift;
	my $p = shift;

	carp "running paramMatch: p: $p";

	for my $k (keys %{$self->cgi_params}) {
		return $k if $k =~ /$p/;
	}
	return undef;

}

sub is_valid_module {
	my $self = shift;
	my $m = shift;
	my $valid = $self->valid_modules();
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
