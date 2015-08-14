package IMG::Views::Links;

use IMG::Util::Base;
use Role::Tiny;

=head3 $link_library

All links

=cut

my $link_library  = {

	abc =>                         { url => { section => 'np' }, label => 'ABC', },
	about_img_m er =>              { url => $url->{server} . '/mer/doc/about_index.html', title => 'Information about IMG', label => 'About IMG/M ER', },
	abundance_profiles =>          { url => { section => 'AbundanceProfiles', page => 'topPage' }, label => 'Abundance Profiles', },
	analysis_cart =>               { url => { section => 'GeneCartStor', page => 'geneCart' }, label => 'Analysis Cart', },
	ani_cliques =>                 { url => { section => 'ANI', page => 'overview' }, label => 'ANI Cliques' },
	annotations =>                 { url => { section => 'MyIMG', page => 'myAnnotationsForm' }, label => 'Annotations' },
	artemis_act =>                 { url => { section => 'Artemis', page => 'ACTForm' }, label => 'Artemis ACT' },
	average_nucleotide_identity => { url => { section => 'ANI' }, title => 'ANI', label => 'Average Nucleotide Identity', },
	biosynthetic_clusters =>       { url => { section => 'BiosyntheticStats', page => 'stats' }, label => 'Biosynthetic Clusters' },
	blast =>                       { url => { section => 'FindGenesBlast', page => 'geneSearchBlast' }, label => 'BLAST' },
	cassette_search =>             { url => { section => 'GeneCassetteSearch', page => 'form' }, label => 'Cassette Search' },
	citation =>                    { url => $url->{img_google_site} . 'using-img/citation', label => 'Citation' },
	cog =>                         { url => { section => 'FindFunctions', page => 'ffoAllCogCategories' }, label => 'COG', },
	cog_browser =>                 { url => { section => 'FindFunctions', page => 'ffoAllCogCategories' }, label => 'COG Browser' },
	cog_id_to_categories =>        { url => { section => 'FindFunctions', page => 'cogid2cat' }, label => 'COG Id to Categories' },
	cog_list =>                    { url => { section => 'FindFunctions', page => 'cogList' }, label => 'COG List' },
	cog_list_w_stats =>            { url => { section => 'FindFunctions', page => 'cogList', stats => '1' }, label => 'COG List w/ Stats' },
	collaborate_with_jgi =>        { url => 'http://jgi.doe.gov/collaborate-with-jgi/pmo-overview/policies/', label => 'Collaborate with JGI' },
	compare_genomes => { url => { section => 'CompareGenomes', page => 'compareGenomes' }, label => 'Compare Genomes', },
	contact_us => { url => $url->{img_google_site} . 'contact-us', label => 'Contact us' },
	credits => { url => $url->{img_google_site} . 'using-img/credits', label => 'Credits' },
	data_management_policy => { url => 'http://jgi.doe.gov/data-and-tools/data-management-policy-practices-resources/', label => 'Data Management Policy' },
	data_marts => { url => 'http://img.jgi.doe.gov/', label => 'Data Marts', },
	data_usage_policy => { url => { section => 'Help', page => 'policypage' }, label => 'Data Usage Policy' },
	deleted_genomes => { url => { section => 'TaxonDeleted' }, label => 'Deleted Genomes' },
	disclaimer => { url => 'http://jgi.doe.gov/disclaimer/', label => 'Disclaimer' },
	distance_tree => { url => { section => 'DistanceTree', page => 'tree' }, label => 'Distance Tree' },
	dot_plot => { url => { section => 'DotPlot', page => 'plot' }, label => 'Dot Plot' },
	downloads => { url => { section => 'Help', page => 'policypage' }, label => 'Downloads', },
	education => { url => $url->{server} . '/mer/doc/education.html', label => 'Education' },
	enzyme => { url => { section => 'FindFunctions', page => 'enzymeList' }, label => 'Enzyme' },
	export_workspace => { url => { section => 'Workspace' }, label => 'Export Workspace' },
	faq => { url => $url->{img_google_site} . 'faq', title => 'Frequently Asked Questions', label => 'FAQ' },
	find_functions => { url => { section => 'FindFunctions', page => 'findFunctions' }, label => 'Find Functions', },
	find_genes => { url => { section => 'FindGenes', page => 'findGenes' }, label => 'Find Genes', },
	find_genomes => { url => { section => 'TreeFile', page => 'domain', domain => 'all' }, label => 'Find Genomes', },
	function_category_comparisons => { url => { section => 'AbundanceComparisonsSub' }, label => 'Function Category Comparisons' },
	function_comparisons => { url => { section => 'AbundanceComparisons' }, label => 'Function Comparisons' },
	function_overview => { url => { section => 'AbundanceProfiles', page => 'mergedForm' }, label => 'Overview (All Functions)' },
	function_profile => { url => { section => 'FunctionProfiler', page => 'profiler' }, label => 'Function Profile' },
	function_search => { url => { section => 'FindFunctions', page => 'findFunctions' }, label => 'Function Search' },
	function_sets => { url => { section => 'WorkspaceFuncSet', page => 'home' }, label => 'Function Sets' },
	functions => { url => { section => 'FuncCartStor', page => 'funcCart' }, label => 'Functions' },
	gene_cassettes => { url => { section => 'GeneCassetteProfiler', page => 'geneContextPhyloProfiler2' }, label => 'Gene Cassettes' },
	gene_search => { url => { section => 'FindGenes', page => 'geneSearch' }, label => 'Gene Search' },
	gene_sets => { url => { section => 'WorkspaceGeneSet', page => 'home' }, label => 'Gene Sets' },
	genes => { url => { section => 'GeneCartStor', page => 'geneCart' }, label => 'Genes' },
	genome_annotation_sop => { url => $url->{server} . '/mer/doc/MGAandDI_SOP.pdf', title => 'Microbial Genome Annotation &amp; Data Integration SOP', label => 'Genome Annotation SOP' },
	genome_browser => { url => { section => 'TreeFile', page => 'domain', domain => 'all' }, label => 'Genome Browser' },
	genome_clustering => { url => { section => 'EgtCluster', page => 'topPage' }, label => 'Genome Clustering' },
	genome_gene_best_homologs => { url => { section => 'GenomeGeneOrtholog' }, label => 'Genome Gene Best Homologs' },
	genome_search => { url => { section => 'FindGenomes', page => 'genomeSearch' }, label => 'Genome Search' },
	genome_sets => { url => { section => 'WorkspaceGenomeSet', page => 'home' }, label => 'Genome Sets' },
	genome_statistics => { url => { section => 'CompareGenomes', page => 'compareGenomes' }, label => 'Genome Statistics' },
	genome_vs_metagenomes => { url => { section => 'GenomeHits' }, label => 'Genome vs Metagenomes' },
	genomes => { url => { section => 'GenomeCart', page => 'genomeCart' }, label => 'Genomes' },
	how_to_download => { url => 'https://groups.google.com/a/lbl.gov/d/msg/img-user-forum/o4Pjc_GV1js/EazHPcCk1hoJ', label => 'How to download' },
	img => { url => $url->{server} . '/w', label => 'IMG' },
	img => { url => $url->{server} . '/w', title => 'IMG isolates', label => 'IMG',
	img_abc => { url => '/abc', label => 'IMG ABC' },
	img_document_archive => { url => $url->{img_google_site} . 'documents', title => 'documents', label => 'IMG Document Archive' },
	img_edu => { url => $url->{server} . '/edu', title => 'IMG Education', label => '<abbr title="IMG Education">IMG EDU</abbr>' },
	img_er => { url => $url->{server} . '/er', title => 'IMG Expert Review', label => '<abbr title="IMG Expert Review">IMG ER</abbr>' },
	img_hmp_m => { url => 'https://img.jgi.doe.gov/cgi-bin/imgm_hmp/main.cgi', title => 'Human Microbiome Project Metagenomes', label => '<abbr title="Human Microbiome Project Metagenome">IMG HMP M</abbr>' },
	img_m => { url => $url->{server} . '/m', title => 'IMG Metagenomes', label => '<abbr title="IMG Metagenomes">IMG M</abbr>' },
	img_m_addendum => { url => $url->{server} . '/mer/doc/userGuide_m.pdf', title => 'User Manual IMG/M Addendum', label => 'IMG/M Addendum' },
	img_mer => { url => $url->{server} . '/mer/', title => 'Expert Review', label => '<abbr title="IMG Metagenome Expert Review">IMG MER</abbr>' },
	img_mission => { url => 'https://img.jgi.doe.gov/#IMGMission', label => 'IMG Mission' },
	img_network_browser => { url => { section => 'ImgNetworkBrowser', page => 'imgNetworkBrowser' }, label => 'IMG Network Browser' },
	img_networks => { url => { section => 'ImgNetworkBrowser', page => 'imgNetworkBrowser' }, label => 'IMG Networks', },
	img_parts_list => { url => { section => 'ImgPartsListBrowser', page => 'browse' }, label => 'IMG Parts List' },
	img_pathways => { url => { section => 'ImgPwayBrowser', page => 'imgPwayBrowser' }, label => 'IMG Pathways' },
	img_terms => { url => { section => 'ImgTermBrowser', page => 'imgTermBrowser' }, label => 'IMG Terms' },
	img_user_forum => { url => $url->{img_google_site} . 'questions', label => 'IMG User Forum' },
	interpro_browser => { url => { section => 'Interpro' }, label => 'InterPro Browser' },
	jgi_genome_portal => { url => 'http://genome.jgi-psf.org/', label => 'JGI Genome Portal' },
	kegg => { url => { section => 'FindFunctions', page => 'ffoAllKeggPathways', view => 'brite' }, label => 'KEGG', },
	kog => { url => { section => 'FindFunctions', page => 'ffoAllKogCategories' }, label => 'KOG', },
	kog_browser => { url => { section => 'FindFunctions', page => 'ffoAllKogCategories' }, label => 'KOG Browser' },
	kog_list => { url => { section => 'FindFunctions', page => 'kogList' }, label => 'KOG List' },
	kog_list_w_stats => { url => { section => 'FindFunctions', page => 'kogList', stats => '1' }, label => 'KOG List w/ Stats' },

	login =>  { label => 'Login' },

	logout => { url => $url->{main_cgi_url} . '?logout=1', label => 'Logout' },

	metagenome_sop => { url => $url->{server} . '/mer/doc/MetagenomeAnnotationSOP.pdf', title => 'Metagenome Annotation &amp; SOP for IMG', label => 'Metagenome SOP' },
	metagenomes_vs_genomes => { url => { section => 'MetagPhyloDist', page => 'form' }, title => 'Metagenome Phylogenetic Distribution', label => 'Metagenomes vs Genomes' },
	methylation => { url => { section => 'Methylomics', page => 'methylomics' }, label => 'Methylation' },
	mgm_workshop => { url => 'http://www.jgi.doe.gov/meetings/mgm/', label => 'MGM Workshop' },
	my_img => { url => { section => 'MyIMG' }, label => 'My IMG', },
	myimg_home => { url => { section => 'MyIMG', page => 'home' }, label => 'MyIMG Home' },
	myjob => { url => { section => 'MyIMG', page => 'myJobForm' }, label => 'MyJob' },
	omics => { url => { section => 'ImgStatsOverview#tabview=tab3' }, label => 'OMICS', },
	orthology_ko_terms => { url => { section => 'FindFunctions', page => 'ffoAllKeggPathways', view => 'brite' }, label => 'Orthology KO Terms' },
	pairwise_ani => { url => { section => 'ANI', page => 'pairwise' }, title => 'Pairwise', label => 'Pairwise ANI' },
	pathways_via_ko terms => { url => { section => 'FindFunctions', page => 'ffoAllKeggPathways', view => 'ko' }, label => 'Pathways via KO Terms' },
	pfam => { url => { section => 'FindFunctions', page => 'pfamCategories' }, label => 'Pfam', },
	pfam_browser => { url => { section => 'FindFunctions', page => 'pfamCategories' }, label => 'Pfam Browser' },
	pfam_clans => { url => { section => 'FindFunctions', page => 'pfamListClans' }, label => 'Pfam Clans' },
	pfam_list => { url => { section => 'FindFunctions', page => 'pfamList' }, label => 'Pfam List' },
	pfam_list_w_stats => { url => { section => 'FindFunctions', page => 'pfamList', stats => '1' }, label => 'Pfam List w/ Stats' },
	phenotypes => { url => { section => 'ImgPwayBrowser', page => 'phenoRules' }, label => 'Phenotypes' },
	phylogenetic_distribution => { url => { section => 'MetagPhyloDist', page => 'top' }, label => 'Phylogenetic Distribution', },
	phylogenetic_marker_cogs => { url => { section => 'PhyloCogs', page => 'phyloCogTaxonsForm' }, label => 'Phylogenetic Marker COGs' },
	phylogenetic_profilers => { url => { section => 'GeneCassetteProfiler', page => 'genetools' }, label => 'Phylogenetic Profilers', },
	preferences => { url => { section => 'MyIMG', page => 'preferences' }, label => 'Preferences' },
	protein => { url => { section => 'IMGProteins', page => 'proteomics' }, label => 'Protein' },
	publications => { url => $url->{img_google_site} . 'using-img/publication', label => 'Publications' },
	radial_tree => { url => { section => 'RadialPhyloTree' }, label => 'Radial Tree' },
	related_links => { url => $url->{img_google_site} . 'using-img/related-links', label => 'Related Links' },
	report_bugs_issues => { url => { page => 'questions' }, title => 'Report bugs or issues', label => 'Report Bugs / Issues' },
	rnaseq => { url => { section => 'RNAStudies', page => 'rnastudies' }, label => 'RNASeq Studies' },
	same_species_plot => { url => { section => 'ANI', page => 'doSameSpeciesPlot' }, label => 'Same Species Plot' },
	scaffold_search => { url => { section => 'ScaffoldSearch' }, label => 'Scaffold Search' },
	scaffold_sets => { url => { section => 'WorkspaceScafSet', page => 'home' }, label => 'Scaffold Sets' },
	scaffolds => { url => { section => 'ScaffoldCart', page => 'index' }, label => 'Scaffolds' },
	search => { url => { section => 'AbundanceProfileSearch' }, label => 'Search' },
	search_bc_sm_by_id => { url => { section => 'BcNpIDSearch&amp;option=np' }, label => 'Search <abbr title="Biosynthetic clusters">BC</abbr>/<abbr title="Secondary metabolites">SM</abbr> by ID' },
	search_biosynthetic_clusters => { url => { section => 'BcSearch', page => 'bcSearch' }, label => 'Search <abbr title="Biosynthetic clusters">BCs</abbr>' },
	search_pathways => { url => { section => 'AllPwayBrowser', page => 'allPwayBrowser' }, label => 'Search Pathways' },
	search_secondary_metabolites => { url => { section => 'BcSearch', page => 'npSearches' }, label => 'Search <abbr title="Secondary metabolites">SMs</abbr>' },
	secondary_metabolites => { url => { section => 'NaturalProd', page => 'list' }, label => 'Secondary Metabolites' },
	single_cell_data decontamination => { url => $url->{server} . '/mer/doc/SingleCellDataDecontamination.pdf', label => 'Single Cell Data Decontamination' },
	single_genes => { url => { section => 'PhylogenProfiler', page => 'phyloProfileForm' }, label => 'Single Genes' },
	site_map => { url => { section => 'Help' }, title => 'Contains links to all menu pages and documents', label => 'Site Map' },
	submit_data_set => { url => 'https://img.jgi.doe.gov/submit', label => 'Submit Data Set' },
	synteny_viewers => { url => { section => 'Vista', page => 'toppage' }, label => 'Synteny Viewers', },
	system_requirements => { url => $url->{server} . '/mer/doc/systemreqs.html', label => 'System Requirements' },
	tc_browser => { url => { section => 'FindFunctions', page => 'ffoAllTc' }, label => 'TC Browser' },
	tc_list => { url => { section => 'FindFunctions', page => 'tcList' }, label => 'TC List' },
	tigrfam => { url => { section => 'TigrBrowser', page => 'tigrBrowser' }, label => 'TIGRfam', },
	tigrfam_list => { url => { section => 'TigrBrowser', page => 'tigrfamList' }, label => 'TIGRfam List' },
	tigrfam_list_w_stats => { url => { section => 'TigrBrowser', page => 'tigrfamList', stats => '1' }, label => 'TIGRfam List w/ Stats' },
	tigrfam_roles => { url => { section => 'TigrBrowser', page => 'tigrBrowser' }, label => 'TIGRfam Roles' },
	transporter_class => { url => { section => 'FindFunctions', page => 'ffoAllTc' }, title => 'Transporter Classification (TC)', label => 'Transporter Classification', },
	tutorial => { url => $url->{img_google_site} . 'using-img/tutorial', label => 'Tutorial' },
	mer_user_guide => { url => $url->{server} . '/mer/doc/using_index.html', label => 'User Guide', },
	mer_user_interface_map => { url => $url->{server} . '/mer/doc/images/uiMap.pdf', label => 'User Interface Map' },
	using_img_mer => { url => $url->{server} . '/mer/doc/about_index.html', label => 'Using IMG',
	vista => { url => { section => 'Vista', page => 'vista' }, label => 'VISTA' },
	workspace => { url => { section => 'Workspace' }, title => 'My saved data: Genes, Functions, Scaffolds, Genomes', label => 'Workspace', },

	workspace_func_set => { url => { section => 'Workspace', page => 'WorkspaceFuncSet' }, label => 'Workspace Function Sets' },

	workspace_gene_set => { url => { section => 'Workspace', page => 'WorkspaceGeneSet' }, label => 'Workspace Gene Sets' },

	workspace_genome_set => { url => { section => 'Workspace', page => 'WorkspaceGenomeSet' }, label => 'Workspace Genome Sets' },

	workspace_rule_set => { url => { section => 'Workspace', page => 'WorkspaceRuleSet' }, label => 'Workspace Rule Sets' },

	workspace_scaf_set => { url => { section => 'Workspace', page => 'WorkspaceScafSet' }, label => 'Workspace Scaffold Sets' },

	workspace_job => { url => { section => 'Workspace', page => 'WorkspaceJob' }, label => 'Workspace Jobs' },
};

sub get_link {

	my $l = shift;
	return $link_library->{ $l } || undef;

}

=head3 proportal_links

Construct links for ProPortal pages

Takes the list of active components or a default set of components

@output $links          hash of link templates

=cut

sub proportal_links {
	my $self = shift;

	my $active = $self->config->{active_components} || [ qw( location clade data_type ) ];

	my %links;

	@links{ @$active } = map { $self->config->{pp_app} . $_ . "/" } @$active;

	return \%links;

}

=head3 img_links

Construct templates for internal (ProPortal) links

@param  $style  (opt)   the link style to construct. Will use the old school
                        param=value form unless specified otherwise
                        currently-valid values: 'new'

@output $output         hash of link templates

=cut

# links required: news

sub img_links {
	my $self = shift;
	my $style = shift || 'old';

	my $base = {
		old => $self->config->{main_cgi_url},
#		new => $self->config->{pp_app},
	};

	my $links = {
		taxon => {
			section => 'TaxonDetail',
			page => 'taxonDetail',
			taxon_oid => ''
		},
		genome_list => {
			section => 'ProPortal',
			page => 'genomeList',
			class => '',
		},
		genome_list_ecosystem => {
			section => 'ProPortal',
			page => 'genomeList',
			class => 'marine_metagenome',
			ecosystem_subtype => ''
		},
		genome_list_clade => {
			section => 'ProPortal',
			page => 'genomeList',
			metadata_col => 'p.clade',
			clade => ''
		},
		compare_genomes => {
			section => 'CompareGenomes',
			page => 'compareGenomes'
		},
		synteny_viewers => {
			section => 'Vista',
			page => 'toppage',
		},
		abundance_profiles => {
			section => 'AbundanceProfiles',
			page => 'topPage'
		},
		workspace_gene_set => {
#			url => {
			section => 'WorkspaceGeneSet'
#			},
#			title => 'Workspace Gene Sets',
		},
	};


	my $params = [ qw( section page class taxon_oid ecosystem_subtype metadata_col clade ) ];

	my $link_gen = {
		# new skool /section/page/class style
		'new' => sub {
			my $l_hash = shift;
			return join "", map { "/" . ( $l_hash->{$_} || "" ) } grep { exists $l_hash->{$_} } @$params;
		},

		# this constructs URLs in the old skool arg1=val1&arg2=val2 style
		'old' => sub {
			my $l_hash = shift;
			return
				$base->{old} . "?" . join "&amp;",
					map { $_ . "=" . ( $l_hash->{$_} || "" ) }
					grep { exists $l_hash->{$_} } @$params;
		}
	};

	if (! $link_gen->{$style}) {
		$style = 'old';
	}

	my %output;

	@output{ keys %$links } = map {
		$link_gen->{ $style }->( $_ );
	} values %$links;

	return \%output;
}









=head3 external_links

External links

=cut

my $external_links = {

	'sso_api_url' => 'https://signon.jgi-psf.org/api/sessions/',
	'sso_url' => 'https://signon.jgi-psf.org',
	'sso_user_info_url' => 'https://signon.jgi-psf.org/api/users/',

	'aclame_base_url' => 'http://aclame.ulb.ac.be/perl/Aclame/Genomes/prot_view.cgi?mode=genome&id=',
	'artemis_url' => 'http://www.sanger.ac.uk/Software/Artemis/',
	'blast_server_url' => 'https://img-worker.jgi-psf.org/cgi-bin/usearch/generic/hopsServer.cgi',
	'blastallm0_server_url' => 'https://img-worker.jgi-psf.org/cgi-bin/blast/generic/blastQueue.cgi',
	'cmr_jcvi_ncbi_project_id_base_url' => 'http://cmr.jcvi.org/cgi-bin/CMR/ncbiProjectId2CMR.cgi?ncbi_project_id=',
	'doi' => 'http://dx.doi.org/',
	'ebi_iprscan_url' => 'http://www.ebi.ac.uk/Tools/pfa/iprscan/',
	'enzyme_base_url' => 'http://www.genome.jp/dbget-bin/www_bget?',
	'flybase_base_url' => 'http://flybase.bio.indiana.edu/reports/',
	'gbrowse_base_url' => 'http://gpweb07.nersc.gov/',
	'gcat_base_url' => 'http://darwin.nox.ac.uk/gsc/gcat/report/',
	'geneid_base_url' => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&cmd=Retrieve&dopt=full_report&list_uids=',
	'go_base_url' => 'http://www.ebi.ac.uk/ego/DisplayGoTerm?id=',
	'go_evidence_url' => 'http://www.geneontology.org/GO.evidence.shtml',
	'gold_api_base_url' => 'https://gpweb08.nersc.gov:8443/',
	'gold_base_url' => 'http://genomesonline.org/',
	'gold_base_url_analysis' => 'https://gold.jgi-psf.org/analysis_projects?id=',
	'gold_base_url_project' => 'https://gold.jgi-psf.org/projects?id=',
	'gold_base_url_study' => 'https://gold.jgi-psf.org/study?id=',
	'greengenes_base_url' => 'http://greengenes.lbl.gov/cgi-bin/show_one_record_v2.pl?prokMSA_id=',
	'greengenes_blast_url' => 'http://greengenes.lbl.gov/cgi-bin/nph-blast_interface.cgi',
	'hgnc_base_url' => 'http://www.gene.ucl.ac.uk/nomenclature/data/get_data.php?hgnc_id=',
	'img_er_submit_project_url' => 'https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ProjectInfo&page=displayProject&project_oid=',
	'img_er_submit_url' => 'https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ERSubmission&page=displaySubmission&submission_id=',
	'img_mer_submit_url' => 'https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=MSubmission&page=displaySubmission&submission_id=',
	'img_submit_url' => 'https://img.jgi.doe.gov/submit',
	'ipr_base_url' => 'http://www.ebi.ac.uk/interpro/entry/',
	'ipr_base_url2' => 'http://supfam.cs.bris.ac.uk/SUPERFAMILY/cgi-bin/scop.cgi?ipid=',
	'ipr_base_url3' => 'http://prosite.expasy.org/',
	'ipr_base_url4' => 'http://smart.embl-heidelberg.de/smart/do_annotation.pl?ACC=',
	'jgi_project_qa_base_url' => 'http://cayman.jgi-psf.org/prod/data/QA/Reports/QD/',
	'kegg_module_url' => 'http://www.genome.jp/dbget-bin/www_bget?md+',
	'kegg_orthology_url' => 'http://www.genome.jp/dbget-bin/www_bget?ko+',
	'kegg_reaction_url' => 'http://www.genome.jp/dbget-bin/www_bget?rn+',
	'ko_base_url' => 'http://www.genome.ad.jp/dbget-bin/www_bget?ko+',
	'metacyc_url' => 'http://biocyc.org/META/NEW-IMAGE?object=',
	'mgi_base_url' => 'http://www.informatics.jax.org/searches/accession_report.cgi?id=MGI:',
	'ncbi_blast_server_url' => 'https://img-proportal-dev.jgi-psf.org/cgi-bin/ncbiBlastServer.cgi',
	'ncbi_blast_url' => 'http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?PAGE=Proteins&PROGRAM=blastp&BLAST_PROGRAMS=blastp&PAGE_TYPE=BlastSearch&SHOW_DEFAULTS=on',
	'ncbi_entrez_base_url' => 'http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?val=',
	'ncbi_mapview_base_url' => 'http://www.ncbi.nlm.nih.gov/mapview/map_search.cgi?direct=on&idtype=gene&id=',
	'ncbi_project_id_base_url' => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=genomeprj&cmd=Retrieve&dopt=Overview&list_uids=',
	'nice_prot_base_url' => 'http://www.uniprot.org/uniprot/',
	'pdb_base_url' => 'http://www.rcsb.org/pdb/explore.do?structureId=',
	'pdb_blast_url' => 'http://www.rcsb.org/pdb/search/searchSequence.do',
	'pfam_base_url' => 'http://pfam.sanger.ac.uk/family?acc=',
	'pfam_clan_base_url' => 'http://pfam.sanger.ac.uk/clan?acc=',
	'pirsf_base_url' => 'http://pir.georgetown.edu/cgi-bin/ipcSF?id=',
	'pubmed' => 'http://www.ncbi.nlm.nih.gov/pubmed/',
	'pubmed_base_url' => 'http://www.ncbi.nlm.nih.gov/entrez?db=PubMed&term=',
	'puma_base_url' => 'http://compbio.mcs.anl.gov/puma2/cgi-bin/search.cgi?protein_id_type=NCBI_GI&search=Search&search_type=protein_id&search_text=',
	'puma_redirect_base_url' => 'http://compbio.mcs.anl.gov/puma2/cgi-bin/puma2_url.cgi?gi=',
	'regtransbase_base_url' => 'http://regtransbase.lbl.gov/cgi-bin/regtransbase?page=geneinfo&protein_id=',
	'regtransbase_check_base_url' => 'http://regtransbase.lbl.gov/cgi-bin/regtransbase?page=check_gene_exp&protein_id=',
	'rfam_base_url' => 'http://rfam.sanger.ac.uk/family/',
	'rgd_base_url' => 'http://rgd.mcw.edu/tools/genes/genes_view.cgi?id=',
	'rna_server_url' => 'https://img-worker.jgi-psf.org/cgi-bin/blast/generic/rnaServer.cgi',
	'swiss_prot_base_url' => 'http://www.uniprot.org/uniprot/',
	'swissprot_source_url' => 'http://www.uniprot.org/uniprot/',
	'tair_base_url' => 'http://www.arabidopsis.org/servlets/TairObject?type=locus&name=',
	'taxonomy_base_url' => 'http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=',
	'tigrfam_base_url' => 'http://www.jcvi.org/cgi-bin/tigrfams/HmmReportPage.cgi?acc=',
	'unigene_base_url' => 'http://www.ncbi.nlm.nih.gov/UniGene/clust.cgi',
	'vimss_redirect_base_url' => 'http://www.microbesonline.org/cgi-bin/gi2vimss.cgi?gi=',
	'worker_base_url' => 'https://img-worker.jgi-psf.org',
	'wormbase_base_url' => 'http://www.wormbase.org/db/gene/gene?name=',
	'zfin_base_url' => 'http://zfin.org/cgi-bin/webdriver?MIval=aa-markerview.apg&OID=',
};


=head3 get_ext_link

Get an external link from the library

	my $link = IMG::Views::Links::get_ext_link( 'pubmed', '81274414' );
	# $link = http://www.ncbi.nlm.nih.gov/pubm40ted/81274414

@param  $target - the name of the link in the hash above
@param  $id     - any other params (optional)

@return $link   - text string that forms the link

=cut

sub get_ext_link {

	my $target = shift;
	return '' unless $external_links->{$target};

	# simple string; append any arguments to it
	if ( ! ref $external_links->{$target} ) {
		return $external_links->{$target} . ( $_[0] || "" );
	}
	# otherwise, it's a coderef
	elsif ( ref $external_links eq 'CODE' ) {
		return $external_links->{$target}->( @_ );
	}
	return '';
}

1;
