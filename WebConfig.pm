# Put configuration parameters here.
#
# $Id: WebConfig.pm 33827 2015-07-28 19:36:22Z aireland $
#
package WebConfig;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( getEnv );

use WebConfigCommon;
use strict;
my $base = '/global/homes/a/aireland/';

# on img-edge*
#
# /opt/img/temp
# and
# /opt/img/logs
# are speical locations where the img ui can write to.
# - ken

sub getEnv {
    my $e = WebConfigCommon::common();

    # TODO - Companion systems url
#    $e->{ domain_name } = "img-stage.jgi-psf.org";
	$e->{domain_name} = 'img-proportal-dev.jgi-psf.org';
    $e->{ http } = "https://";
    $e->{ top_base_url } = $e->{ http }. $e->{ domain_name } . "/";

#    my $urlTag = "amelia"; # sub url directory e.g. img_ken
	my $urlTag = '';
    $e->{ urlTag } = $urlTag;
    my $dbTag = $e->{ dbTag };

    $e->{ base_url } = $e->{ http }. $e->{ domain_name } . "/$urlTag";
    $e->{ arch } = "x86_64-linux";

    #
    # DO NOT update base_dir base_dir_stage cgi_url cgi_dir cgi_dir_stage
    # - ken
    #
#    my $webfsVhostDir = '/webfs/projectdirs/microbial/img/public-web/vhosts/';
#    my $apacheVhostDir = '/opt/apache/content/vhosts/';  # this redirects to webfsVhostDir
	my $webfsVhostDir = '/global/homes/a/aireland/';
	my $apacheVhostDir = '/global/homes/a/aireland/';
    $e->{ base_dir } = $apacheVhostDir . $e->{ domain_name } . "/htdocs"; #/$urlTag";
    $e->{ base_dir_stage } = $webfsVhostDir .$e->{ domain_name } . "/htdocs"; #/$urlTag";
    $e->{ cgi_url } = $e->{ http } . $e->{ domain_name } . "/cgi-bin"; # /$urlTag";
    $e->{ cgi_dir } = $apacheVhostDir . $e->{ domain_name } . "/cgi-bin"; # /$urlTag";
    $e->{ cgi_dir_stage } = $webfsVhostDir . $e->{ domain_name } . "/cgi-bin"; # /$urlTag";

    $e->{ main_cgi } = "main.cgi";
    $e->{ inner_cgi } = "inner.cgi";

    #my $log_dir = "/opt/img/logs";
    #my $log_dir = "/webfs/scratch/img/logs";
    my $log_dir = '/global/homes/a/aireland/log';
    $e->{ log_dir } = $log_dir;
    $e->{ web_log_file } = "$log_dir/" . $e->{ domain_name } . $dbTag . "_" . $urlTag . ".log";
    $e->{ err_log_file } = "$log_dir/" . $e->{ domain_name } . $dbTag . "_" . $urlTag . ".err.log";
    $e->{ login_log_file } = "";

    $e->{ cgi_tmp_dir } = "/opt/img/temp/" . $e->{ domain_name } .  "_"  . $urlTag;
    $e->{ifs_tmp_dir} = $e->{ifs_tmp_dir} . "/" . $urlTag;

    # optional precomputed homologs server with -m 0 output
    $e->{ img_lid_blastdb } = "${dbTag}_lid";
    # IMG long ID (<gene_oid>_<taxon>_<aa_seq_length>)
    # BLAST database.
    $e->{ img_iso_blastdb } = "${dbTag}_iso";
    # IMG long ID (<gene_oid>_<taxon>_<aa_seq_length>)
	# Isolate BLAST database.
    $e->{ img_rna_blastdb } = "${dbTag}_rna.fna";
    # IMG long ID (<gene_oid>_<taxon>_<aa_seq_length>_<geneSymbol>)
    # Meta RNA BLAST database.
    $e->{ img_meta_rna_blastdb } = "metag_rna.fna";
    # IMG long ID (<taxon>.a:<gene_oid>_<aa_seq_length>)
	# BLAST database.
    $e->{ ncbi_blast_server_url } = $e->{ cgi_url } . "/ncbiBlastServer.cgi";
    # Client web server to NCBI BLAST.

    $e->{ vista_url_map_file } = $e->{ cgi_dir } . "/vista.tab.txt";
    $e->{ vista_sets_file } = $e->{ cgi_dir } . "/vista.sets.txt";

    $e->{ otf_phyloProfiler_method } = "usearch";
    	# On the fly usearch

    $e->{ include_metagenomes } = 1;
        # Include metagenome configuration.

    $e->{enable_workspace} = 1;

    # kog is for 3.4 not 3.3
    $e->{ include_kog } = 1;
    $e->{ include_bbh_lite } = 0; # Include BBH lite files.

    $e->{ img_internal } = 0;
            # Add internal for IMG/I.

    # added cassette bbh selection to the ui
    $e->{ enable_cassette } = 1; # new for 3.4
    $e->{ include_cassette_bbh } = 0;
    $e->{ include_cassette_pfam  } = 1; # used by profiler for now - ken
    $e->{ enable_cassette_fastbit } = 1;

    $e->{ img_geba } = 1;
            # show GEBA genomes and stats

     $e->{img_proportal} = 1;

    $e->{ img_er } = 0;
            # IMG/ER isolate specific features.

    $e->{ include_ht_homologs } = 1;
                # Mark horizontal transfers in gene page homologs.
    $e->{ include_ht_stats } = 2;
                # Show horizontal transfers in genome details page.

    $e->{ show_myimg_login } = 0;
            # Show login for MyIMG.

    $e->{ show_mygene } = 0;
    		# Show mygene setup.

    $e->{ show_mgdist_v2 } = 1;
                # Show version 2 of metagenome distribution.

    $e->{ user_restricted_site } = 0;
            # Restrict site requiring individual permissions.

    # not for 3.3
    $e->{ snp_enabled } = 0;       # SNP

    # mpw - ken
    $e->{mpw_pathway } = 1;

    $e->{ oracle_config } = $e->{ oracle_config_dir } . "web.$dbTag.config";
    $e->{ img_er_oracle_config } = $e->{ oracle_config_dir } . "web.$dbTag.config";
    $e->{ img_gold_oracle_config } = $e->{ oracle_config_dir } . "web.imgsg_dev.config";
    $e->{ img_i_taxon_oracle_config } = $e->{ oracle_config_dir } . "web.img_i_taxon.config";

    $e->{ myimg_job } = 0;
    $e->{ myimg_jobs_dir } = $e->{ web_data_dir } . "/myimg.jobs";
    		# Results of job submissions

    $e->{ all_faa_blastdb } = $e->{ web_data_dir } . "/all.faa.blastdbs/all_$dbTag";
    $e->{ all_fna_blastdb } = $e->{ web_data_dir } .  "/all.fna.blastdbs/all_$dbTag";

                # Name of all protein and nucleic acid BLAST databases.
                # Need to customize for subset.

    $e->{ phyloProfile_file } = $e->{ web_data_dir } . "/phyloProfile.$dbTag.txt";

                # Phylogenetic profile file.

    $e->{ include_taxon_phyloProfiler } = 1;
    		# Phylo profiler at taxon level.

    $e->{ taxon_stats_dir } = $e->{ web_data_dir } . "/taxon.stats.$dbTag";

    ##################
    $e->{ bin_dir } = $e->{ cgi_dir } . "/bin/" . $e->{ arch };
    $e->{ bl2seq_bin } = $e->{ bin_dir } . "/bl2seq";
    $e->{ fastacmd_bin } = $e->{ bin_dir } . "/fastacmd";
    $e->{ formatdb_bin } = $e->{ bin_dir } . "/formatdb";
    $e->{ megablast_bin } = $e->{ bin_dir } .  "/megablast";
    $e->{ clustalw_bin } = $e->{ bin_dir } . "/clustalw";
    $e->{ snpCount_bin } = $e->{ bin_dir } . "/snpCount";
    $e->{ grep_bin } = $e->{ bin_dir } . "/grep";
    $e->{ findHit_bin } = $e->{ bin_dir } . "/findHit";
    $e->{ mview_bin } = $e->{ bin_dir } . "/mview";
    $e->{ phyloSim_bin } =  $e->{ bin_dir } . "/phyloSim";
    $e->{ wsimHomologs_bin } = $e->{ bin_dir } . "/wsimHomologs";
    $e->{ cluster_bin } =  $e->{ bin_dir } . "/cluster";
    $e->{ ma_bin } = $e->{ bin_dir } . "/ma";
    $e->{ raxml_bin } = $e->{ bin_dir } . "/raxml";

    $e->{ tmp_url } = $e->{ base_url } . "/tmp";
    $e->{ tmp_dir } = $e->{ base_dir } . "/tmp";
    $e->{ small_color_array_file } = $e->{ cgi_dir } . "/color_array.txt";
    $e->{ large_color_array_file } = $e->{ cgi_dir } . "/rgb.scrambled.txt";
    $e->{dark_color_array_file} = $e->{cgi_dir} . "/dark_color.txt";
    $e->{ green2red_array_file } = $e->{ cgi_dir } . "/green2red_array.txt";


    $e->{ verbose } = 1;
            # General verbosity level. 0 - very little, 1 - normal,
        #   >1 more verbose.
        # -1 to turn off webLog - ken

    $e->{ show_sql_verbosity_level } = 1;
            # Minimum verbosity level before SQL is logged.
        # Set to 2 or above to avoid getting most SQL queries logged,
        # for e.g., in production systems.

    ## Charting parameters

    # location of the runchart.sh script
    # IF blank "" the charting feature will be DISABLED
    $e->{ chart_exe } = $e->{ cgi_dir } . "/bin/runchart.sh";

    # chart script logging feature - used only of debugging
    # best to leave it blank "" or "/dev/null"
    $e->{ chart_log } = "";

    # new for 3.2
    # decorator.sh
    #
    $e->{ decorator_exe } = $e->{ cgi_dir } . "/bin/decorator.sh";
    # location of jar files
    $e->{ decorator_lib } = $e->{ base_dir };
    # decorator script logging feature - used only of debugging
    # best to leave it blank "" or "/dev/null"
    $e->{ decorator_log } = "";
    #$e->{newick_all} = "/home/aratner/newick-all.txt";
    $e->{newick_all} = $e->{ web_data_dir } . "/newick/newick-all.3.3.txt";


    # new for 3.1 cgi caching
    # enable cgi cache 0 to disable
    $e->{ cgi_cache_enable } = 1;
    # location of cache directory - this should be a unique directory
    # for each web site
    $e->{ cgi_cache_dir } =  $e->{ cgi_tmp_dir } . "/CGI_Cache";
    # cache expire time in seconds 1 hour = 60 * 60
    # should be less the purge tmp and cgi_tmp times
    $e->{ cgi_cache_default_expires_in } = 3600;
    # max cache size in bytes 20 MB
    # changed max cache to 1 GB - ken
    $e->{cgi_cache_size} = 1000 * 1024 * 1024;

    # for 3.3 test to see if we can cache blast output for public sites
    # for it to work both cgi_cache_enable must be 1
    #     AND cgi_blast_cache_enable = 1
    # this should help during the workshops - Ken
    $e->{ cgi_blast_cache_enable } = 1;

    # ssl enable - only for er and mer on merced - new for v3.3 - ken
    #
    # see https_cgi_url
    $e->{ssl_enabled} = 1;

    # new for 3.3 only for img system: mer and er and server merced. Its not for spock
    # because spock has no ssl cert. - Ken
    #
    # see ssl_enabled
    $e->{ https_cgi_url } = "https://". $e->{ domain_name } . "/cgi-bin/$urlTag/" . $e->{ main_cgi };

    # new for 3.3 - ken
    # if blank it will run the old way as in 3.2
    $e->{ blast_wrapper_script } = $e->{ cgi_dir } . "/bin/blastwrapper.sh";

    $e->{ scriptEnv_script } = $e->{ cgi_dir } . "/bin/scriptEnv.sh";

    # new for 3.3 - ken
    $e->{ dblock_file } = $e->{dbLock_dir} . $dbTag;

    # to put a special message in the message area below the menu
    # leave it blank to display no message
	$e->{message} = "beta test site";


    # caliban sso
    # if null do not use sso
    #
    # for stage web farm MUST change url to .jgi-psf.org
    #
    $e->{sso_enabled} = 1;
    $e->{sso_domain} = ".jgi-psf.org";
    $e->{sso_url} = "https://signon" . $e->{sso_domain};
    $e->{sso_cookie_name} = "jgi_return";
    $e->{sso_session_cookie_name} = "jgi_session"; # cookie that stores the caliban session id is has the format of "/api/sessions/30a6fa0dc58d3708"
    $e->{sso_api_url} =  $e->{sso_url} . "/api/sessions/"; # "https://signon.jgi-psf.org/api/sessions/"; # session id from cookie jgi_session
    $e->{sso_user_info_url} = $e->{sso_url} . '/api/users/';

    # public sites now with login required
    $e->{public_login} = 0;

    $e->{ rnaseq } = 1; # only er - ken


    # find function static pages
    $e->{cog_data_file}     = $e->{ webfs_data_dir } . "hmp/img_w_cog.txt";
    $e->{kog_data_file}     = $e->{ webfs_data_dir } . "hmp/img_w_kog.txt";
    $e->{pfam_data_file}    = $e->{ webfs_data_dir } . "hmp/img_w_pfam.txt";
    $e->{tigrfam_data_file} = $e->{ webfs_data_dir } . "hmp/img_w_tigrfam.txt";
    $e->{enzyme_data_file}  = $e->{ webfs_data_dir } . "hmp/img_w_enzymes.txt";
    $e->{figfams_data_file} = $e->{ webfs_data_dir } . "hmp/img_w_figfams.txt";
    $e->{tc_data_file}      = $e->{ webfs_data_dir } . "hmp/img_w_tc.txt";

    # domain_stats_file
    $e->{domain_stats_file} = $e->{ webfs_data_dir } . "ui/prod/domain_stats_w_v400.txt";
    WebConfigCommon::postFix($e);

	my %h = (
  base_dir => $base . "/webUI/webui.htd",

  base_dir_stage => $base . "/webUI/webui.htd",

  base_url => "https://img-proportal-dev.jgi-psf.org/",

  bin_dir => $base . "/webUI/webui.cgi/bin/x86_64-linux",

  bl2seq_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/bl2seq",

  blast_wrapper_script => $base . "/webUI/webui.cgi/bin/blastwrapper.sh",

  cgi_cache_dir => "/opt/img/temp/img-proportal-dev.jgi-psf.org_/CGI_Cache",

  cgi_dir => $base . "/webUI/webui.cgi",

  cgi_dir_stage => $base . "/webUI/webui.cgi",

  cgi_tmp_dir => "/opt/img/temp/img-proportal-dev.jgi-psf.org_",

  cgi_url => "https://img-proportal-dev.jgi-psf.org/cgi-bin",

  chart_exe => $base . "/webUI/webui.cgi/bin/runchart.sh",

  clustalw_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/clustalw",

  cluster_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/cluster",

  dark_color_array_file => $base . "/webUI/webui.cgi/dark_color.txt",

  decorator_exe => $base . "/webUI/webui.cgi/bin/decorator.sh",

  decorator_lib => $base . "/webUI/webui.htd",

  domain_name => "img-proportal-dev.jgi-psf.org",

  err_log_file => $base . "/log/img_core_v400_.err.log",

  fastacmd_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/fastacmd",

  findHit_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/findHit",

  formatdb_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/formatdb",

  green2red_array_file => $base . "/webUI/webui.cgi/green2red_array.txt",

  grep_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/grep",

  https_cgi_url => "https://img-proportal-dev.jgi-psf.org/cgi-bin/main.cgi",

  large_color_array_file => $base . "/webUI/webui.cgi/rgb.scrambled.txt",

  ma_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/ma",

  megablast_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/megablast",

  mview_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/mview",

  ncbi_blast_server_url => "https://img-proportal-dev.jgi-psf.org/cgi-bin/ncbiBlastServer.cgi",

  phyloSim_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/phyloSim",

  raxml_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/raxml",

  scriptEnv_script => $base . "/webUI/webui.cgi/bin/scriptEnv.sh",

  small_color_array_file => $base . "/webUI/webui.cgi/color_array.txt",
  snpCount_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/snpCount",
  tmp_dir => $base . "/tmp",
  tmp_url => "https://img-proportal-dev.jgi-psf.org/tmp",
  top_base_url => "https://img.jgi.doe.gov/",

  vista_sets_file => $base . "/webUI/webui.cgi/vista.sets.txt",

  vista_url_map_file => $base . "/webUI/webui.cgi/vista.tab.txt",

  web_log_file => $base . "/log/img_core_v400_.log",

  wsimHomologs_bin => $base . "/webUI/webui.cgi/bin/x86_64-linux/wsimHomologs",

  merfs_timeout_mins => 0,

  dev_site => 1

	);

	@$e{ keys %h } = values %h;


	my @c1 = caller(1);
	my @c2 = caller(2);
	if ( open( my $fh, ">>", '/global/homes/a/aireland/log/webEnvLog' ) ) {

		print { $fh } "webEnv called by " . $c1[0] . "::" . $c1[3] . " then " . $c2[0] . "::" . $c2[3] . "\n";
	}

    return $e;
}


1;
