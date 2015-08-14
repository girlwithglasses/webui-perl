package IMG::Views::Menu;

use IMG::Util::Base;
use Role::Tiny;

my $url = {
	main_cgi_url => 'http://localhost/',
	server => 'http://img.jgi.doe.gov/',
	img_google_site => 'https://sites.google.com/a/lbl.gov/img-form/',
};

=head3 get_menus

Get the page menus

@param  $cfg     - config, e.g. from webEnv()
@param  $section - the section of the menu to display in the left-hand nav

@output hashref with structure
        menu_bar    => { data structure representing the menu bar }
        section_nav => {

=cut

sub get_menus {
	my $cfg = shift;
	my $section = shift;
#	say "cfg: " . Dumper $cfg;
	$url->{main_cgi_url} = $cfg->{main_cgi_url} if $cfg->{main_cgi_url}   ;

	if (! $section || $self->can( $section ) ) {
		carp "menu section $section does not exist!";
		return { menu_bar => $self->img_menu_bar };
	}

	return {
		menu_bar => $self->img_menu_bar,
		section_nav => $self->$section,
	};

}

=head3 img_menu_bar

Generate a data structure representing the IMG horizontal menu bar

This gets rendered by Template::Toolkit

=cut

sub img_menu_bar {

	my $cfg = shift;

	my $menu = {
		L => [
			$self->genomes,
			$self->genes,
			$self->functions,
			$self->compare_genomes,
			$self->analysis,
			$self->omics,
			$self->abc,
			$self->datamarts,
		],
		R => [
			$self->my_img,
			$self->using,
		]
	};
}

sub genomes {

	return

	{ url => $url->{main_cgi_url} . '?section=TreeFile&amp;page=domain&amp;domain=all', label => 'Find Genomes',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=TreeFile&amp;page=domain&amp;domain=all', label => 'Genome Browser' },
			{ url => $url->{main_cgi_url} . '?section=FindGenomes&amp;page=genomeSearch', label => 'Genome Search' },
			{ url => $url->{main_cgi_url} . '?section=TaxonDeleted', label => 'Deleted Genomes' },
			{ url => $url->{main_cgi_url} . '?section=ScaffoldSearch', label => 'Scaffold Search' },
		],
	};
}

sub genes {

	return
	{ url => $url->{main_cgi_url} . '?section=FindGenes&amp;page=findGenes', label => 'Find Genes',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=FindGenes&amp;page=geneSearch', label => 'Gene Search' },
			{ url => $url->{main_cgi_url} . '?section=GeneCassetteSearch&amp;page=form', label => 'Cassette Search' },
			{ url => $url->{main_cgi_url} . '?section=FindGenesBlast&amp;page=geneSearchBlast', label => 'BLAST' },
			{ url => $url->{main_cgi_url} . '?section=GeneCassetteProfiler&amp;page=genetools', label => 'Phylogenetic Profilers',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=PhylogenProfiler&amp;page=phyloProfileForm', label => 'Single Genes' },
					{ url => $url->{main_cgi_url} . '?section=GeneCassetteProfiler&amp;page=geneContextPhyloProfiler2', label => 'Gene Cassettes' },
				],
			},
		],
	};
}

sub functions {

	return
	{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=findFunctions', label => 'Find Functions',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=findFunctions', label => 'Function Search' },
			{ url => $url->{main_cgi_url} . '?section=AllPwayBrowser&amp;page=allPwayBrowser', label => 'Search Pathways' },
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllCogCategories', label => 'COG',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllCogCategories', label => 'COG Browser' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=cogList', label => 'COG List' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=cogList&amp;stats=1', label => 'COG List w/ Stats' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=cogid2cat', label => 'COG Id to Categories' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllKogCategories', label => 'KOG',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllKogCategories', label => 'KOG Browser' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=kogList', label => 'KOG List' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=kogList&amp;stats=1', label => 'KOG List w/ Stats' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=pfamCategories', label => 'Pfam',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=pfamCategories', label => 'Pfam Browser' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=pfamList', label => 'Pfam List' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=pfamList&amp;stats=1', label => 'Pfam List w/ Stats' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=pfamListClans', label => 'Pfam Clans' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=TigrBrowser&amp;page=tigrBrowser', label => 'TIGRfam',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=TigrBrowser&amp;page=tigrBrowser', label => 'TIGRfam Roles' },
					{ url => $url->{main_cgi_url} . '?section=TigrBrowser&amp;page=tigrfamList', label => 'TIGRfam List' },
					{ url => $url->{main_cgi_url} . '?section=TigrBrowser&amp;page=tigrfamList&amp;stats=1', label => 'TIGRfam List w/ Stats' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllTc', title => 'Transporter Classification (TC)', label => 'Transporter Class.',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllTc', label => 'TC Browser' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=tcList', label => 'TC List' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllKeggPathways&amp;view=brite', label => 'KEGG',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllKeggPathways&amp;view=brite', label => 'Orthology KO Terms' },
					{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=ffoAllKeggPathways&amp;view=ko', label => 'Pathways via KO Terms' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=ImgNetworkBrowser&amp;page=imgNetworkBrowser', label => 'IMG Networks',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=ImgNetworkBrowser&amp;page=imgNetworkBrowser', label => 'IMG Network Browser' },
					{ url => $url->{main_cgi_url} . '?section=ImgPartsListBrowser&amp;page=browse', label => 'IMG Parts List' },
					{ url => $url->{main_cgi_url} . '?section=ImgPwayBrowser&amp;page=imgPwayBrowser', label => 'IMG Pathways' },
					{ url => $url->{main_cgi_url} . '?section=ImgTermBrowser&amp;page=imgTermBrowser', label => 'IMG Terms' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=FindFunctions&amp;page=enzymeList', label => 'Enzyme' },
			{ url => $url->{main_cgi_url} . '?section=ImgPwayBrowser&amp;page=phenoRules', label => 'Phenotypes' },
			{ url => $url->{main_cgi_url} . '?section=Interpro', label => 'InterPro Browser' },
		],
	};
}

sub compare_genomes {

	return
	{ url => $url->{main_cgi_url} . '?section=CompareGenomes&amp;page=compareGenomes', label => 'Compare Genomes',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=CompareGenomes&amp;page=compareGenomes', label => 'Genome Statistics' },
			{ url => $url->{main_cgi_url} . '?section=Vista&amp;page=toppage', label => 'Synteny Viewers',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=Vista&amp;page=vista', label => 'VISTA' },
					{ url => $url->{main_cgi_url} . '?section=DotPlot&amp;page=plot', label => 'Dot Plot' },
					{ url => $url->{main_cgi_url} . '?section=Artemis&amp;page=ACTForm', label => 'Artemis ACT' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=AbundanceProfiles&amp;page=topPage', label => 'Abundance Profiles',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=AbundanceProfiles&amp;page=mergedForm', label => 'Overview (All Functions)' },
					{ url => $url->{main_cgi_url} . '?section=AbundanceProfileSearch', label => 'Search' },
					{ url => $url->{main_cgi_url} . '?section=AbundanceComparisons', label => 'Function Comparisons' },
					{ url => $url->{main_cgi_url} . '?section=AbundanceComparisonsSub', label => 'Function Category Comparisons' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=MetagPhyloDist&amp;page=top', label => 'Phylogenetic Distribution',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=MetagPhyloDist&amp;page=form', title => 'Metagenome Phylogenetic Distribution', label => 'Metagenomes vs Genomes' },
					{ url => $url->{main_cgi_url} . '?section=GenomeHits', label => 'Genome vs Metagenomes' },
					{ url => $url->{main_cgi_url} . '?section=RadialPhyloTree', label => 'Radial Tree' },
				],
			},

			{ url => $url->{main_cgi_url} . '?section=ANI', title => 'ANI', label => 'Average Nucleotide Identity',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=ANI&amp;page=pairwise', title => 'Pairwise', label => 'Pairwise ANI' },
					{ url => $url->{main_cgi_url} . '?section=ANI&amp;page=doSameSpeciesPlot', label => 'Same Species Plot' },
					{ url => $url->{main_cgi_url} . '?section=ANI&amp;page=overview', label => 'ANI Cliques' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=DistanceTree&amp;page=tree', label => 'Distance Tree' },
			{ url => $url->{main_cgi_url} . '?section=FunctionProfiler&amp;page=profiler', label => 'Function Profile' },
			{ url => $url->{main_cgi_url} . '?section=EgtCluster&amp;page=topPage', label => 'Genome Clustering' },
			{ url => $url->{main_cgi_url} . '?section=GenomeGeneOrtholog', label => 'Genome Gene Best Homologs' },
			{ url => $url->{main_cgi_url} . '?section=PhyloCogs&amp;page=phyloCogTaxonsForm', label => 'Phylogenetic Marker COGs' },
		],
	};
}

sub analysis {

	return
	{ url => $url->{main_cgi_url} . '?section=GeneCartStor&amp;page=geneCart', label => 'Analysis Cart',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=GeneCartStor&amp;page=geneCart', label => 'Genes' },
			{ url => $url->{main_cgi_url} . '?section=FuncCartStor&amp;page=funcCart', label => 'Functions' },
			{ url => $url->{main_cgi_url} . '?section=GenomeCart&amp;page=genomeCart', label => 'Genomes' },
			{ url => $url->{main_cgi_url} . '?section=ScaffoldCart&amp;page=index', label => 'Scaffolds' },
		],
	};
}

sub omics {

	return
	{ url => $url->{main_cgi_url} . '?section=ImgStatsOverview#tabview=tab3', label => 'OMICS',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=IMGProteins&amp;page=proteomics', label => 'Protein' },
			{ url => $url->{main_cgi_url} . '?section=RNAStudies&amp;page=rnastudies', label => 'RNASeq' },
			{ url => $url->{main_cgi_url} . '?section=Methylomics&amp;page=methylomics', label => 'Methylation' },
		],
	};
}

sub abc {

	return
	{ url => $url->{main_cgi_url} . '?section=np', label => 'ABC',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=BcNpIDSearch&amp;option=np', label => 'Search <abbr title="Biosynthetic clusters">BC</abbr>/<abbr title="Secondary metabolites">SM</abbr> by ID' },
			{ url => $url->{main_cgi_url} . '?section=BiosyntheticStats&amp;page=stats', label => 'Biosynthetic Clusters' },
			{ url => $url->{main_cgi_url} . '?section=BcSearch&amp;page=bcSearch', label => 'Search <abbr title="Biosynthetic clusters">BCs</abbr>' },
			{ url => $url->{main_cgi_url} . '?section=NaturalProd&amp;page=list', label => 'Secondary Metabolites' },
			{ url => $url->{main_cgi_url} . '?section=BcSearch&amp;page=npSearches', label => 'Search <abbr title="Secondary metabolites">SMs</abbr>' },
		],
	};
}

sub datamarts {

	return
	{ url => 'http://img.jgi.doe.gov/', label => 'Data Marts',
		submenu =>
		[
			{ url => $url->{server} . '/w', title => 'IMG isolates', label => 'IMG',
				submenu =>
				[
					{ url => $url->{server} . '/w', label => 'IMG' },
					{ url => $url->{server} . '/er', title => 'IMG Expert Review', label => '<abbr title="IMG Expert Review">IMG ER</abbr>' },
					{ url => $url->{server} . '/edu', title => 'IMG Education', label => '<abbr title="IMG Education">IMG EDU</abbr>' },
				],
			},
			{ url => $url->{server} . '/m', title => 'IMG Metagenomes', label => '<abbr title="IMG Metagenomes">IMG M</abbr>',
				submenu =>
				[
					{ url => $url->{server} . '/m', title => 'IMG Metagenomes', label => '<abbr title="IMG Metagenomes">IMG M</abbr>' },
					{ url => $url->{server} . '/mer/', title => 'Expert Review', label => '<abbr title="IMG Metagenome Expert Review">IMG MER</abbr>' },
					{ url => 'https://img.jgi.doe.gov/cgi-bin/imgm_hmp/main.cgi', title => 'Human Microbiome Project Metagenomes', label => '<abbr title="Human Microbiome Project Metagenome">IMG HMP M</abbr>' },
				],
			},
			{ url => '/abc', label => 'IMG ABC' },
			{ url => 'https://img.jgi.doe.gov/submit', label => 'Submit Data Set' },
		],
	};
}

sub my_img {

	return

	{ url => $url->{main_cgi_url} . '?section=MyIMG', label => 'My IMG',
		submenu =>
		[
			{ url => $url->{main_cgi_url} . '?section=MyIMG&amp;page=home', label => 'MyIMG Home' },
			{ url => $url->{main_cgi_url} . '?section=MyIMG&amp;page=myAnnotationsForm', label => 'Annotations' },
			{ url => $url->{main_cgi_url} . '?section=MyIMG&amp;page=myJobForm', label => 'MyJob' },
			{ url => $url->{main_cgi_url} . '?section=MyIMG&amp;page=preferences', label => 'Preferences' },
			{ url => $url->{main_cgi_url} . '?section=Workspace', title => 'My saved data: Genes, Functions, Scaffolds, Genomes', label => 'Workspace',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=WorkspaceGeneSet&amp;page=home', label => 'Gene Sets' },
					{ url => $url->{main_cgi_url} . '?section=WorkspaceFuncSet&amp;page=home', label => 'Function Sets' },
					{ url => $url->{main_cgi_url} . '?section=WorkspaceGenomeSet&amp;page=home', label => 'Genome Sets' },
					{ url => $url->{main_cgi_url} . '?section=WorkspaceScafSet&amp;page=home', label => 'Scaffold Sets' },
					{ url => $url->{main_cgi_url} . '?section=Workspace', label => 'Export Workspace' },
				],
			},
			{ url => $url->{main_cgi_url} . '?logout=1', label => 'Logout' },
		],
	};
}

sub using {

return
	{ url => $url->{server} . '/mer/doc/about_index.html', label => 'Using IMG',
		submenu =>
		[
			{ url => $url->{server} . '/mer/doc/about_index.html', title => 'Information about IMG', label => 'About IMG/M ER',
				submenu =>
				[
					{ url => 'https://img.jgi.doe.gov/#IMGMission', label => 'IMG Mission' },
					{ url => $url->{img_google_site} . 'faq', title => 'Frequently Asked Questions', label => 'FAQ' },
					{ url => $url->{img_google_site} . 'using-img/related-links', label => 'Related Links' },
					{ url => $url->{img_google_site} . 'using-img/credits', label => 'Credits' },
					{ url => $url->{img_google_site} . 'documents', title => 'documents', label => 'IMG Document Archive' },
				],
			},
			{ url => $url->{server} . '/mer/doc/using_index.html', label => 'User Guide',
				submenu =>
				[
					{ url => $url->{server} . '/mer/doc/systemreqs.html', label => 'System Requirements' },
					{ url => $url->{main_cgi_url} . '?section=Help', title => 'Contains links to all menu pages and documents', label => 'Site Map' },
					{ url => $url->{img_google_site} . 'using-img/tutorial', label => 'Tutorial' },
					{ url => $url->{server} . '/mer/doc/images/uiMap.pdf', label => 'User Interface Map' },
					{ url => $url->{server} . '/mer/doc/SingleCellDataDecontamination.pdf', label => 'Single Cell Data Decontamination' },
					{ url => $url->{server} . '/mer/doc/userGuide_m.pdf', title => 'User Manual IMG/M Addendum', label => 'IMG/M Addendum' },
				],
			},
			{ url => $url->{main_cgi_url} . '?section=Help&amp;page=policypage', label => 'Downloads',
				submenu =>
				[
					{ url => $url->{main_cgi_url} . '?section=Help&amp;page=policypage', label => 'Data Usage Policy' },
					{ url => 'http://jgi.doe.gov/data-and-tools/data-management-policy-practices-resources/', label => 'Data Management Policy' },
					{ url => 'http://jgi.doe.gov/collaborate-with-jgi/pmo-overview/policies/', label => 'Collaborate with JGI' },
					{ url => 'https://groups.google.com/a/lbl.gov/d/msg/img-user-forum/o4Pjc_GV1js/EazHPcCk1hoJ', label => 'How to download' },
					{ url => 'http://genome.jgi-psf.org/', label => 'JGI Genome Portal' },
				],
			},
			{ url => $url->{img_google_site} . 'using-img/citation', label => 'Citation' },
			{ url => $url->{server} . '/mer/doc/MGAandDI_SOP.pdf', title => 'Microbial Genome Annotation &amp; Data Integration SOP', label => 'Genome Annotation SOP' },
			{ url => $url->{server} . '/mer/doc/MetagenomeAnnotationSOP.pdf', title => 'Metagenome Annotation &amp; SOP for IMG', label => 'Metagenome SOP' },
			{ url => $url->{server} . '/mer/doc/education.html', label => 'Education' },
			{ url => $url->{img_google_site} . 'using-img/publication', label => 'Publications' },
			{ url => 'http://www.jgi.doe.gov/meetings/mgm/', label => 'MGM Workshop' },
			{ url => $url->{img_google_site} . 'questions', label => 'IMG User Forum' },
			{ url => $url->{main_cgi_url} . '?page=questions', title => 'Report bugs or issues', label => 'Report Bugs / Issues' },
			{ url => $url->{img_google_site} . 'contact-us', label => 'Contact us' },
			{ url => 'http://jgi.doe.gov/disclaimer/', label => 'Disclaimer' },
		],
	};
}


1;
