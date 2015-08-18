############################################################################
#   Misc. utility functions to support HTML.
# $Id: HtmlUtil.pm 33804 2015-07-24 20:07:15Z jinghuahuang $
############################################################################
package HtmlUtil;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Time::localtime;
use WebConfig;
use WebUtil;
use DBI;
use GD;
use CGI qw( :standard );
use MIME::Base64 qw( encode_base64 decode_base64 );
use FileHandle;
use Data::Dumper;
use LWP;
use HTTP::Request::Common qw( GET );
use CGI::Carp qw( carpout set_message  );
use Cwd;
use CGI::Cache;
use OracleUtil;
use MetaUtil;
use MerFsUtil;
use WorkspaceUtil;

# Force flush
$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $main_cgi             = $env->{main_cgi};
my $inner_cgi            = $env->{inner_cgi};
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};
my $web_data_dir         = $env->{web_data_dir};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $base_url             = $env->{base_url};
my $img_ken              = $env->{img_ken};
my $kegg_brite_tree_file = $env->{kegg_brite_tree_file};
my $preferences_url      = "$main_cgi?section=MyIMG&page=preferences";

my $maxGeneListResults = 1000;

my $cgi_cache_enable             = $env->{cgi_cache_enable};
my $cgi_cache_dir                = $env->{cgi_cache_dir};
my $cgi_cache_default_expires_in = $env->{cgi_cache_default_expires_in};
$cgi_cache_default_expires_in = 3600 if ( $cgi_cache_default_expires_in eq "" );
my $cgi_cache_size = $env->{cgi_cache_size};
$cgi_cache_size = 20 * 1024 * 1024 if ( $cgi_cache_size eq "" );

# user can disable cache for there session - ken
if ($cgi_cache_enable) {
    my $userCacheEnable = getSessionParam("userCacheEnable");
    $userCacheEnable = "Yes" if ( $userCacheEnable eq "" ); # it was never set
    if($userCacheEnable eq "No") {
        $cgi_cache_enable = 0;
    } else {
        $cgi_cache_enable = 1;
    }
    
    #webLog("======================================\n");
    #webLog(" >>$userCacheEnable<<   >>$cgi_cache_enable<< \n");
    #webLog("======================================\n");
}

#
# Is cgi cache enabled
#
# All tools / files should call this method for find out if to use cache.
# Never get cache flag from the WebConfig directly since 
# users can override cache flag in their prefs.
# MyIMG.pm is only file that should use the WebConfig cache flag to setup prefs correctly
# - ken
#
sub isCgiCacheEnable {
    return $cgi_cache_enable;
}

#
# intialize cache
# namespace - name the cache file
#
sub cgiCacheInitialize {
    my ( $namespace, $override_cache_size, $override_expires_time ) = @_;
    
    if($user_restricted_site) {
        # session cache
        my $sid = WebUtil::getSessionId();
        $namespace = $namespace . '_' . $sid;
    } else {
        # public system shared cache
        $namespace = $namespace . '_0';
    }
    

    if ($cgi_cache_enable) {
        my $query = WebUtil::getCgi();
        require MyIMG;
        my $prefs_href = MyIMG::getSessionParamHash();

        # user can change preferences so lets hack into
        # cgi params and set the hide prefs
        # the cgi cache system can decide to use cache or not - Ken
        my $params = $query->Vars;
        foreach my $key (keys %$prefs_href) {
            $params->{$key} = $prefs_href->{$key};
            #print "$key ".  $prefs_href->{$key} . " <br/>\n";
        }
        webLog("cache file namespace ====== $namespace \n");

        # Set up a cache in /tmp/CGI_Cache/demo_cgi, with publicly
        # unreadable cache entries, a maximum size of 20 megabytes,
        # and a time-to-live of 6 hours.
        #
        # default_expires_in in seconds can use
        # 10 minutes or 1 hours
        # http://search.cpan.org/dist/Cache-Cache/lib/Cache/Cache.pm
        # umask 022 == chmod 755
        # 002 == 775
        my $tmp_size = $cgi_cache_size;
        $tmp_size = $override_cache_size if ( $override_cache_size ne "" );
        my $tmp_time = $cgi_cache_default_expires_in;
        $tmp_time = $override_expires_time if ( $override_expires_time ne "" );
        CGI::Cache::setup(
	    {
		cache_options => {
		    cache_root         => "$cgi_cache_dir",
		    namespace          => "$namespace",
		    directory_umask    => 002,
		    max_size           => $tmp_size,
		    default_expires_in => "$tmp_time",
		}
	    }
	);

        my $myhashkey;
        my $params = $query->Vars;
        foreach my $key ( sort keys %$params ) {
            my $val = $params->{$key};
            #webLog("$key ==> $val \n") if ($img_ken);
            $myhashkey .= $key . $val;
        }

        # CGI::Vars requires CGI version 2.50 or better
        #CGI::Cache::set_key( $query->Vars );
        CGI::Cache::set_key($myhashkey);
        CGI::Cache::invalidate_cache_entry()
          if $query->param('force_regenerate') eq 'true';

        #CGI::Cache::start() or return;
    }
}

#
# return is 0 - use cache pages
# return is 1 continue running the program as usual
# usage
#   HtmlUtil::cgiCacheStart() or return;
#
sub cgiCacheStart {
    if ($cgi_cache_enable) {
        return CGI::Cache::start();
    } else {
        return 1;
    }
}

# stop caching pages
#The stop() routine tells us to stop capturing output. The argument
#"cache_output" tells us whether or not to store the captured output in the
#cache. By default this argument is 1, since this is usually what we want to
#do. In an error condition, however, we may not want to cache the output.
# A cache_output argument of 0 is used in this case.
# http://search.cpan.org/~dcoppit/CGI-Cache-1.4200/lib/CGI/Cache.pm
sub cgiCacheStop {
    my ($cache_output) = @_;
    if ($cgi_cache_enable) {
        if ( $cache_output ne "" ) {

            return CGI::Cache::stop($cgi_cache_enable);
        } else {
            return CGI::Cache::stop();
        }
    }
}

# pause caching
sub cgiCachePause {
    if ($cgi_cache_enable) {
        return CGI::Cache::pause();
    }
}

# continue caching from a pause
sub cgiCacheContinue {
    if ($cgi_cache_enable) {
        return CGI::Cache::continue();
    }
}


############################################################################
# flushGeneBatch - Flush (print) a batch of gene_oid's.
############################################################################
sub flushGeneBatch {
    my ( $dbh, $gene_oids_ref, $taxon_oid_ortholog, $showSeqLen ) = @_;

    my @gene_oids_select = param("gene_oid");
    my %geneOidsSelect  = array2Hash(@gene_oids_select);

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    #print "flushGeneBatch \$gene_oids_ref size: ".scalar(@$gene_oids_ref)."<br/>\n";

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type, 
         tx.taxon_oid, tx.ncbi_taxon_id, 
         tx.taxon_display_name, tx.genus, tx.species, 
         g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       order by tx.taxon_display_name, g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species, 
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gene_oid_str =~ /gtt_num_id/i );

    my $sit = new StaticInnerTable();
    $sit->addColSpec("Select");
    $sit->addColSpec( "Gene ID",                    "asc",  "right" );
    $sit->addColSpec( "Gene Product Name",          "asc",  "left", "", "", "wrap" );
    $sit->addColSpec( "Amino Acid Sequence Length", "desc", "left" );
    $sit->addColSpec( "Genome ID",                  "asc",  "right" );
    $sit->addColSpec( "Genome Name",                "asc",  "left", "", "", "wrap" );
    $sit->addColSpec( "Scaffold Info",              "asc",  "left", "", "", "wrap" );

    my %done;
    for my $r (@recs) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species,
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck  = "checked" if $geneOidsSelect{$gene_oid} ne "";
        my $row = qq{
            \u<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t
        };

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2              = escHtml($genus);
        my $species2            = escHtml($species);
        my $taxon_display_name2 = escHtml($taxon_display_name);
        my $orthStr;
        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }
        if ( $taxon_oid eq $taxon_oid_ortholog ) {
            $genus2   = "<font color='green'><b>" . escHtml($genus) . "</b></font>";
            $species2 = "<font color='green'><b>" . escHtml($species) . "</b></font>";
            $orthStr  = "<font color='green'>Ortholog in </font>";
        }

        $row .= alink( $url, $gene_oid ) . "\t";
        $row .= escHtml($gene_display_name) . "\t";

        if ($seqLen) {
            $row .= $seqLen . "\t";
        } else {
            $row .= "-\t";
        }

        $row .= $taxon_oid . "\t";
        $row .= $taxon_display_name2 . "\t";

        if ($scfInfo) {
            $row .= $scfInfo . "\t";
        } else {
            $row .= "-\t";
        }

        $done{$gene_oid} = 1;

        $sit->addRow($row);
    }
    $sit->printOuterTable(1);

}

sub flushGeneBatchSort {
    my ( $dbh, $gene_oids_ref, $it, $taxon_oid_ortholog, $showSeqLen ) = @_;
    
    my @gene_oids_select = param("gene_oid");
    my %geneOidsSelect  = WebUtil::array2Hash(@gene_oids_select);
    
    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    #print "flushGeneBatchSort \$gene_oids_ref size: ".scalar(@$gene_oids_ref)."<br/>\n";

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type, 
         tx.taxon_oid, tx.ncbi_taxon_id, 
         tx.taxon_display_name, tx.genus, tx.species, 
         g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       order by tx.taxon_display_name, g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species, 
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gene_oid_str =~ /gtt_num_id/i );

    my $sd = $it->getSdDelim();    # sort delimiter

    my %done;
    for my $r (@recs) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species, 
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck = "checked" if $geneOidsSelect{$gene_oid} ne "";

        my $row;
        $row .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />" . "\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2              = escHtml($genus);
        my $species2            = escHtml($species);
        my $taxon_display_name2 = escHtml($taxon_display_name);
        my $orthStr;
        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }
        if ( $taxon_oid eq $taxon_oid_ortholog ) {
            $genus2   = "<font color='green'><b>" . escHtml($genus) . "</b></font>";
            $species2 = "<font color='green'><b>" . escHtml($species) . "</b></font>";
            $orthStr  = "<font color='green'>Ortholog in </font>";
        }

        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        my $tmp = $gene_display_name . " ${seqLen} [$taxon_display_name2]$scfInfo";
        $row .= $tmp . $sd . $tmp;

        $done{$gene_oid} = 1;
        $it->addRow($row);
    }

}

#
# big gene batch more than 1000 genes to list
#
# added extra parameter for YUI - $it (InnerTable object) +BSJ 05/13/10
#
sub flushGeneBatchBig {
    my ( $dbh, $gene_oids_ref, $it, $taxon_oid_ortholog, $showSeqLen ) = @_;
    return if !$it;

    my @gene_oids    = param("gene_oid");
    my %geneOids     = array2Hash(@gene_oids);

    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);

    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type, 
         tx.taxon_oid, tx.ncbi_taxon_id, 
         tx.taxon_display_name, tx.genus, tx.species, 
         g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( _XXX_ )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
    };

    $sql = bigInQuery( $sql, "_XXX_", $gene_oids_ref );

    $sql = qq{
       select * 
       from (
           $sql
       )
       order by taxon_display_name, gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species, 
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    $cur->finish();

    my $sd = $it->getSdDelim();    # sort delimiter

    my %done;
    for my $r (@recs) {
        my (
            $gene_oid,      $gene_display_name,  $gene_symbol,   $locus_type, $taxon_oid,
            $ncbi_taxon_id, $taxon_display_name, $genus,         $species, 
            $aa_seq_length, $seq_status,         $ext_accession, $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck  = "checked" if $geneOids{$gene_oid} ne "";
        my $row = $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2              = escHtml($genus);
        my $species2            = escHtml($species);
        my $taxon_display_name2 = escHtml($taxon_display_name);
        my $orthStr;
        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }
        if ( $taxon_oid eq $taxon_oid_ortholog ) {
            $genus2   = "<font color='green'><b>" . escHtml($genus) . "</b></font>";
            $species2 = "<font color='green'><b>" . escHtml($species) . "</b></font>";
            $orthStr  = "<font color='green'>Ortholog in </font>";
        }
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        #escHtml( $gene_display_name ) .
        #   " ${seqLen} [$orthStr$genus2 $species2]$scfInfo";
        $row .= $gene_display_name . $sd . escHtml($gene_display_name) . " ${seqLen} $scfInfo\t";

        $row .= $taxon_oid . $sd . $taxon_oid . "\t";
        my $turl = "$main_cgi?section=TaxonDetail&page=taxonDetail" 
            . "&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $turl, $taxon_display_name2 ) . "\t";

        $it->addRow($row);
        $done{$gene_oid} = 1;
    }
}

############################################################################
# flushGeneBatchSorting - a html table with sorting
############################################################################
sub flushGeneBatchSorting {
    my ( $dbh, $gene_oids_ref, $it, $showSeqLen, $hideGenome, 
        $extraColName, $extracolumn_href, $extracollink_href ) = @_;
   
    my @gene_oids_select = param("gene_oid");
    my %geneOidsSelect  = WebUtil::array2Hash(@gene_oids_select);

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    #print "flushGeneBatchSorting \$gene_oids_ref size: ".scalar(@$gene_oids_ref)."<br/>\n";

    my $geneInnerClause = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_tag, g.locus_type, 
               tx.taxon_oid, tx.ncbi_taxon_id, 
               tx.taxon_display_name, tx.genus, tx.species, 
               g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
        from taxon tx, scaffold scf, scaffold_stats ss, gene g
        where g.gene_oid in ( $geneInnerClause )
        and g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
    };
    # order by tx.taxon_display_name, g.gene_oid
    #print "flushGeneBatchSorting() sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,   $gene_display_name, $gene_symbol,   $locus_tag,
             $locus_type, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name,
             $genus,      $species,           $aa_seq_length,
             $seq_status, $ext_accession,     $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_tag\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $geneInnerClause =~ /gtt_num_id/i );

    # now print soriing html
    my $sd = $it->getSdDelim();

    #my $cnt = 0;
    my %done;
    for my $rec (@recs) {
        my (
             $gene_oid,   $gene_display_name, $gene_symbol,   $locus_tag,
             $locus_type, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name,
             $genus,      $species,           $aa_seq_length,
             $seq_status, $ext_accession,     $seq_length
          )
          = split( /\t/, $rec );
        next if $done{$gene_oid} ne "";
        my $ck = "checked" if $geneOidsSelect{$gene_oid} ne "";

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";

        $r .= $locus_tag . $sd . "$locus_tag\t";

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }

        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        my $tmpname = " ${seqLen} $scfInfo";
        if ( $gene_display_name ne "" ) {
            $tmpname = $gene_display_name . $tmpname;
        }
        $r .= $tmpname . $sd . "\t";

        if ( !$hideGenome ) {
            $r .= $taxon_oid . $sd . $taxon_oid . "\t";            
            my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            $url = alink( $url, "$taxon_display_name" );
            $r .= $taxon_display_name . $sd . $url . "\t";            
        }

        if ( $extraColName && defined $extracolumn_href) {
            if ( defined $extracolumn_href ) {
                my $extraColLabel = $extracolumn_href->{$gene_oid};
                if ( defined $extracollink_href ) {
                    my $extraColLink = $extracollink_href->{$gene_oid};
                    $r .= $extraColLabel . $sd . $extraColLink . "\t";
                } else {
                    $r .= $extraColLabel . $sd . $extraColLabel . "\t";
                }
            }
            else {
                $r .= $sd . "\t";                
            }
        }

        $it->addRow($r);
        #$cnt++;

        $done{$gene_oid} = 1;
    }

    # print "row cnt so far $cnt <br>\n";
}

############################################################################
# flushGeneBatchSorting2 - a html table with sorting plus extra column
############################################################################
sub flushGeneBatchSorting2 {
    my ( $dbh, $gene_oids_ref, $it, $showSeqLen, $extrasql, $extraurl ) = @_;
    
    my @gene_oids_select = param("gene_oid");
    my %geneOidsSelect  = WebUtil::array2Hash(@gene_oids_select);

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    #print "flushGeneBatchSorting2 \$gene_oids_ref size: ".scalar(@$gene_oids_ref)."<br/>\n";

    my $geneInnerClause = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my %extracolumn;
    my %extracollink;
    #$extrasql =~ s/__replace__/and g.gene_oid in ( $gene_oid_str )/;
    #$extrasql =~ s/__replace__/and g.gene_oid in ( select id from gtt_num_id )/;
    $extrasql =~ s/__replace__/and g.gene_oid in ( $geneInnerClause )/;

    my $cur = execSql( $dbh, $extrasql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $name ) = $cur->fetchrow();
        last if !$gene_oid;

    	my $link;
    	if ($extraurl ne "") {
    	    $link = alink($extraurl.$name, $name);
    	    if ( exists $extracollink{$gene_oid} ) {
    		$link = $extracollink{$gene_oid} . "<br/>" . $link;
    	    }
    	    $extracollink{$gene_oid} = $link;
    	}

        if ( exists $extracolumn{$gene_oid} ) {
            $name = $extracolumn{$gene_oid} . " <br/> " . $name;
        }
        $extracolumn{$gene_oid} = $name;
    }
    $cur->finish();

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_tag, g.locus_type, 
               tx.taxon_oid, tx.ncbi_taxon_id, 
               tx.taxon_display_name, tx.genus, tx.species, 
               g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
        from taxon tx, scaffold scf, scaffold_stats ss, gene g
        where g.gene_oid in ( $geneInnerClause )
        and g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
    };

    #print "flushGeneBatchSorting2 \$sql: $sql<br/>\n";

    # order by tx.taxon_display_name, g.gene_oid
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,   $gene_display_name, $gene_symbol,   $locus_tag,
             $locus_type, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name,
             $genus,      $species,           $aa_seq_length,
             $seq_status, $ext_accession,     $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_tag\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $geneInnerClause =~ /gtt_num_id/i );

    # now print soriing html
    my $sd = $it->getSdDelim();

    my %done;
    for my $r (@recs) {
        my (
             $gene_oid,   $gene_display_name, $gene_symbol,   $locus_tag,
             $locus_type, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name,
             $genus,      $species,           $aa_seq_length,
             $seq_status, $ext_accession,     $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck = "checked" if $geneOidsSelect{$gene_oid} ne "";

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck /> \t";

        my $url = "$main_cgi?section=GeneDetail" 
	        . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd
	    . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";
        $r .= $locus_tag . $sd . "$locus_tag\t";

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }

        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        my $tmpname = " ${seqLen} $scfInfo";
        if ( $gene_display_name ne "" ) {
            $tmpname = $gene_display_name . $tmpname;
        }

        $r .= $tmpname . $sd . "\t";

        my $extraColname = $extracolumn{$gene_oid};
    	if ($extraurl ne "") {
    	    my $extraCollink = $extracollink{$gene_oid};
    	    $r .= $extraColname . $sd . $extraCollink . "\t";
    	} else {
    	    $r .= $extraColname . $sd . $extraColname . "\t";
    	}

        $it->addRow($r);

        $done{$gene_oid} = 1;
    }
}


############################################################################
# flushMetagGeneBatch - Flush (print) a batch of metagenome gene_oid's.
############################################################################
sub flushMetagGeneBatch {
    my ( $dbh, $gene_oids_ref, $it, $taxonlink ) = @_;
    return if !$it;

    my @gene_oids    = param("gene_oid");
    my %geneOids     = array2Hash(@gene_oids);

    if ( $#$gene_oids_ref < 0 ) {
        return;
    }
    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_type,
               tx.taxon_oid, tx.ncbi_taxon_id, tx.taxon_display_name, 
               tx.genus, tx.species, g.aa_seq_length,
               tx.seq_status, scf.ext_accession, ss.seq_length,
           ss.gc_percent, scf.read_depth, g.est_copy
        from taxon tx, scaffold scf, scaffold_stats ss, gene g
        where g.taxon = tx.taxon_oid
        and g.gene_oid in ( $gene_oid_str )
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        order by tx.taxon_display_name, g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
            $gene_oid,       $gene_display_name,  $gene_symbol,       $locus_type,     $taxon_oid,
            $ncbi_taxon_id,  $taxon_display_name, $genus,             $species, 
            $aa_seq_length,  $seq_status,         $scf_ext_accession, $scf_seq_length, $scf_gc_percent,
            $scf_read_depth, $est_copy
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$scf_ext_accession\t";
        $rec .= "$scf_seq_length\t";
        $rec .= "$scf_gc_percent\t";
        $rec .= "$scf_read_depth\t";
        $rec .= "$est_copy\t";
        push( @recs, $rec );
    }
    $cur->finish();
    
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gene_oid_str =~ /gtt_num_id/i );

    my $sd           = $it->getSdDelim();    # sort delimiter
    my $sum_est_copy = 0;
    my $link;
    my %done;
    for my $r (@recs) {
        my (
            $gene_oid,       $gene_display_name,  $gene_symbol,       $locus_type,     $taxon_oid,
            $ncbi_taxon_id,  $taxon_display_name, $genus,             $species,        $enzyme,
            $aa_seq_length,  $seq_status,         $scf_ext_accession, $scf_seq_length, $scf_gc_percent,
            $scf_read_depth, $est_copy
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";

        my $ck = "checked" if $geneOids{$gene_oid} ne "";
        my $row .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

        my $seqLen;
        $seqLen = "${aa_seq_length}aa " if $aa_seq_length ne "";

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ($locus_type $gene_symbol) ";
        }

        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        my $depth;
        $scf_read_depth = sprintf( "%.2f", $scf_read_depth );
        $depth = " depth=$scf_read_depth" if $scf_read_depth > 0;
        my $scfInfo = "$scf_ext_accession " . "[${scf_seq_length}bp, gc=$scf_gc_percent$depth]";

        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $gene_display_name . $sd . $gene_display_name . "\t";
        $row .= "${seqLen} (est_copy=$est_copy) " . "\t";
        $row .= $scfInfo . "\t";

        my $turl = "$main_cgi?section=TaxonDetail&page=taxonDetail" 
            . "&taxon_oid=$taxon_oid";
        if ($taxonlink) {
            # genome column is not displayed if only single genome
            $link = alink( $turl, $taxon_display_name );
        } else {
            $row .= $taxon_oid . $sd . $taxon_oid . "\t";
            $row .= $taxon_display_name . $sd . alink( $turl, $taxon_display_name ) . "\t";
        }

        $it->addRow($row);

        $done{$gene_oid} = 1;
        $sum_est_copy += $est_copy;
    }

    if ($taxonlink) {
        print "<p>$link</p>";
    }
    return $sum_est_copy;
}


############################################################################
# flushMetaGeneBatchSorting - a html table for meta gene
############################################################################
sub flushMetaGeneBatchSorting {
    my ( $dbh, $meta_gene_oids_ref, $it, $hideGenome, $extraColName, $extracolumn_href, $extracollink_href ) = @_;

    if ( scalar(@$meta_gene_oids_ref) <= 0 ) {
        return;
    }

    my %genes_h;
    my %taxon_oid_h;
    for my $workspace_id ( @$meta_gene_oids_ref ) {
        $genes_h{$workspace_id} = 1;

        my @vals = split(/ /, $workspace_id);
        if ( scalar(@vals) >= 3 ) {
            $taxon_oid_h{$vals[0]} = 1; 
        }
    }
    my @taxonOids = keys(%taxon_oid_h);
    #print "flushMetaGeneBatchSorting() 0a " . currDateTime() . "<br/>\n";

    my %taxon_name_h;
    if (scalar(@taxonOids) > 0) {
        %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash($dbh, \@taxonOids);    
    }
    #print "flushMetaGeneBatchSorting() 0b " . currDateTime() . "<br/>\n";

    my %gene_name_h;
    my %gene_info_h;
    MetaUtil::getAllGeneNames(\%genes_h, \%gene_name_h);
    MetaUtil::getAllGeneInfo(\%genes_h, \%gene_info_h);
    #print "flushMetaGeneBatchSorting() 0c " . currDateTime() . "<br/>\n";

    my @recs;
    for my $workspace_id ( @$meta_gene_oids_ref ) {
        
        my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);
        if ( ! exists($taxon_name_h{$taxon_oid}) ) {
            #$taxon_oid not in hash, probably due to permission
            webLog("flushMetaGeneBatchSorting() $taxon_oid not retrieved from database, probably due to permission.");
            next;
        }

        my ($locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2) 
             = split(/\t/, $gene_info_h{$workspace_id});
        
        if ( !$taxon_oid && $tid2 ) {
            $taxon_oid = $tid2;
            if ( ! exists($taxon_name_h{$taxon_oid})) {
                my $taxon_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );
                # save taxon display name to prevent repeat retrieving
                $taxon_name_h{$taxon_oid} = $taxon_name;
            }
        }
        # taxon
        my $taxon_display_name = $taxon_name_h{$taxon_oid};
        $taxon_display_name = appendMetaTaxonNameWithDataType($taxon_display_name, $data_type);
        
        if ( $gene_name_h{$workspace_id} ) {
            $gene_display_name = $gene_name_h{$workspace_id};
        }
        if ( ! $gene_display_name ) {
            $gene_display_name = 'hypothetical protein';
        }
        
        my $rec = "$workspace_id\t";
        $rec .= "$gene_display_name\t";
        $rec .= "\t"; #gene_symbol
        $rec .= "$locus_tag\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "\t"; #ncbi_taxon_id
        $rec .= "$taxon_display_name\t";
        $rec .= "\t"; #genus
        $rec .= "\t"; #species
        $rec .= "\t"; #enzyme
        $rec .= "\t"; #aa_seq_length
        $rec .= "\t"; #seq_status
        $rec .= "\t"; #ext_accession
        $rec .= "\t"; #seq_length
        push( @recs, $rec );
        
        #print "flushMetaGeneBatchSorting() rec: ". $rec."<br/>\n";      
    }

    # now print soriing html
    my $sd = $it->getSdDelim();

    my %done;
    for my $rec (@recs) {
        my (
             $workspace_id, $gene_display_name, $gene_symbol,   $locus_tag,
             $locus_type, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name,
             $genus,      $species,           $enzyme,        $aa_seq_length,
             $seq_status, $ext_accession,     $seq_length
          )
          = split( /\t/, $rec );
        next if $done{$workspace_id} ne "";

        my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);

        my $r;
        $r = $sd . "<input type='checkbox' name='gene_oid' value='$workspace_id' />\t";

        my $gene_url = "$main_cgi?section=MetaGeneDetail" . 
            "&page=metaGeneDetail&data_type=$data_type" .
            "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        $r .= $workspace_id . $sd . alink( $gene_url, $gene_oid ) . "\t";

        $r .= $locus_tag . $sd . "$locus_tag\t";

        $r .= $gene_display_name . $sd . $gene_display_name . "\t";

        if ( !$hideGenome ) {
            $r .= $taxon_oid . $sd . $taxon_oid . "\t";            
            my $taxon_url = "$main_cgi?section=MetaDetail" . 
                "&page=metaDetail&taxon_oid=$taxon_oid";
            $r .= $taxon_display_name . $sd . alink( $taxon_url, $taxon_display_name ) . "\t";            
        }

        if ( $extraColName ) {
            if ( defined $extracolumn_href ) {
                my $extraColLabel = $extracolumn_href->{$workspace_id};
                if ( defined $extracollink_href ) {
                    my $extraColLink = $extracollink_href->{$workspace_id};
                    $r .= $extraColLabel . $sd . $extraColLink . "\t";
                } else {
                    $r .= $extraColLabel . $sd . $extraColLabel . "\t";
                }
            }
            else {
                $r .= $sd . "\t";                
            }
        }

        $it->addRow($r);

        $done{$workspace_id} = 1;
    }

}

############################################################################
# printGeneListSection - Print gene list with footer.  Query must
#  retrieve only gene_oid's.   Common routine for showing gene lists
#  given SQL.  The more interactive version than retrieving large
#  batch first.
############################################################################
sub printGeneListSection {
    my ( $sql, $title, $notitlehtmlesc, @binds ) = @_;

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>\n";
    if ( defined $notitlehtmlesc && $notitlehtmlesc ne "" ) {
        print $title . "\n";
    } else {
        print escHtml($title) . "\n";
    }
    print "</h1>\n";

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }    

    my @gene_oids;
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    printGeneCartFooter() if ( $count > 10 );
    flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();
    
    if ( $trunc ) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }

    print end_form();
}

sub printGeneListSectionSort {
    my ( $it, $sql, $title, $notitlehtmlesc, @binds ) = @_;

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>\n";
    if ( defined $notitlehtmlesc ) {
        print $title . "\n";
    } else {
        print escHtml($title) . "\n";
    }
    print "</h1>\n";

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my @gene_oids;
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    flushGeneBatchSort( $dbh, \@gene_oids, $it );

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();
    
    if ( $trunc ) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print end_form();
}

############################################################################
# Handles lone gene in list and goes directly to GeneDetail.
############################################################################
sub printGeneListSectionBatch {
    my ( $sql, $title, @binds ) = @_;

    printStatusLine( "Loading ...", 1 );    
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }
        
    my @gene_oids;
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $gene_oid, undef ) = $cur->fetchrow();
        last if !$gene_oid;

        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    if ( $count == 0 ) {
        webError("No genes found.");
        return;
    }
    if ( $count == 1 ) {
        require GeneDetail;
        print GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    print "<h1>\n";
    print escHtml($title) . "\n";
    print "</h1>\n";

    printGeneCartFooter();
    flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    if ( $trunc ) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print end_form();
}

############################################################################
# printMetagGeneListSection - Print gene list with footer.  Query must
#  retrieve only gene_oid's.   Common routine for showing gene lists
#  given SQL.  Metagenomic version.
############################################################################
sub printMetagGeneListSection {
    my ( $sql, $title, $taxonlink, @binds ) = @_;

    printMainForm();
    print "<h1>\n";
    print escHtml($title) . "\n";
    print "</h1>\n";

    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    require InnerTable;
    my $it = new InnerTable( 1, "MetagGenes$$", "MetagGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Gene Product Name", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Gene Info",         "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Scaffold Info",     "asc", "left", "", "", "wrap" );
    if ( !$taxonlink ) {
        $it->addColSpec( "Genome ID", "asc", "right" );
        $it->addColSpec( "Genome Name", "asc", "left", "", "", "wrap" );
    }

    my $dbh   = dbLogin();
    my $cur   = execSql( $dbh, $sql, $verbose, @binds );

    my @gene_oids;
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    if ( !@gene_oids ) {
        printMessage("There are no genes that satisfy this criteria.");
    } else {
        flushMetagGeneBatch( $dbh, \@gene_oids, $it, $taxonlink );
        printGeneCartFooter();
        $it->printOuterTable(1);
        printGeneCartFooter() if ( scalar @gene_oids > 10 );
    }

    if ( $trunc ) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print "</p>\n";

    print end_form();
}

############################################################################
# printGeneListHtmlTable
############################################################################
sub printGeneListHtmlTable {
    my ( $title, $subtitle, $dbh, $genes_ref, $meta_genes_ref, $hideGenome, 
        $extraColName, $extracolumn_href, $extracollink_href ) = @_;

    my @gene_oids;
    if ($genes_ref ne '') {
        @gene_oids = @$genes_ref;
    }
    my @meta_gene_oids;
    if ($meta_genes_ref ne '') {
        @meta_gene_oids = @$meta_genes_ref;
    }

    if ( scalar(@gene_oids) == 1 && scalar(@meta_gene_oids) == 0) {
        #$dbh->disconnect();
        require GeneDetail;
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    if ( $title ne '' ) {
        print "<h1>\n";
        print escHtml($title) . "\n";
        print "</h1>\n";
    }
    if ( $subtitle ne '' ) {
        print "<p>\n";
        print $subtitle . "\n";
        print "</p>\n";
    }

    if ( scalar(@gene_oids) == 0 && scalar(@meta_gene_oids) == 0) {
        #$dbh->disconnect();
        print "<p>\n";
        print "No genes found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    printStatusLine( "Loading ...", 1 );

    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    if ( !$hideGenome ) {
        $it->addColSpec( "Genome ID",   "asc", "right" );        
        $it->addColSpec( "Genome Name",   "asc", "left" );        
    }
    if ( $extraColName ) {
        $it->addColSpec( "$extraColName", "asc", "left" );        
    }

    my $count = 0;
    if (scalar(@gene_oids) > 0) {
        my @batch;
        if ( ($count + scalar(@gene_oids)) > $maxGeneListResults ) {
            for my $gene_oid (@gene_oids) {
                push( @batch, $gene_oid );
                $count++;
                if ( $count >= $maxGeneListResults ) {
                    last;
                }
            }
        }
        else {
            @batch = @gene_oids;
            $count += scalar(@gene_oids);
        }
        flushGeneBatchSorting( $dbh, \@batch, $it, '', $hideGenome, $extraColName, $extracolumn_href, $extracollink_href );        
    }

    if (scalar(@meta_gene_oids) > 0) {
        my @batch;
        if ( ($count + scalar(@meta_gene_oids)) > $maxGeneListResults ) {
            for my $gene_oid (@meta_gene_oids) {
                push( @batch, $gene_oid );
                $count++;
                if ( $count >= $maxGeneListResults ) {
                    last;
                }
            }            
        }
        else {
            @batch = @meta_gene_oids;
            $count += scalar(@meta_gene_oids);
        }
        flushMetaGeneBatchSorting( $dbh, \@batch, $it, $hideGenome, $extraColName, $extracolumn_href, $extracollink_href );
    }

    if ( $count > 10 ) {
        printGeneCartFooter();
    }
    $it->printOuterTable(1);
    printGeneCartFooter();

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

############################################################################
# fetchGeneList
# How much efficiency we can improve if we merge fetchGeneList into printGeneListHtmlTable
# to avoid going through two loops?
############################################################################
sub fetchGeneList {
    my ( $dbh, $sql, $verbose, @args ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @args );
    my @gene_oids;
    my %done;
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid} ne '';
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();

    return @gene_oids;
}

############################################################################
# printGenomeListHtmlTable
############################################################################
sub printGenomeListHtmlTable {
    my ( $title, $subtitle, $dbh, $taxon_oids_aref, $notitlehtmlesc, $disableFormPrint,
        $extraColName, $extracolumn_href, $extracollink_href, $extracol_position ) = @_;

    printMainForm() if(!$disableFormPrint);
    printStatusLine( "Loading ...", 1 );
        
    if ( $title ne '' ) {
        print "<h1>\n";
        if ( defined $notitlehtmlesc ) {
            print $title . "\n";
        } else {
            print escHtml($title) . "\n";
        }
        print "</h1>\n";
    }
    if ( $subtitle ne '' ) {
        print "<p>\n";
        print $subtitle . "\n";
        print "</p>\n";
    }

    if ( scalar(@$taxon_oids_aref) == 0 ) {
        print "<p>\n";
        print "No genomes found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
    #print "printGenomeListHtmlTable taxon_oids size: ".scalar(@$taxon_oids_aref)."<br/>\n";

    my $genomeInnerClause = OracleUtil::getNumberIdsInClause( $dbh, @$taxon_oids_aref );

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select tx.taxon_oid, tx.domain, tx.seq_status, tx.taxon_display_name
        from taxon tx
        where tx.taxon_oid in ( $genomeInnerClause )
        $rclause
        $imgClause
    };
    #print "printGenomeListHtmlTable() sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs = ();
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $r = "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $genomeInnerClause =~ /gtt_num_id/i );
    #$dbh->disconnect();

    my $it = new InnerTable( 1, "genomelist$$", "genomelist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "",
                     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome ID", "asc", "left" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    if ( $extraColName ) {
        $extracol_position = "left" if ( !$extracol_position ); 
        $it->addColSpec( "$extraColName", "asc", "$extracol_position" );        
    }

    my $select_id_name = "taxon_filter_oid";

    my $count = 0;
    foreach my $r (@recs) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name ) =
	    split( /\t/, $r );
        $count++;

        my $row;
        $row .= $sd
          . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' />\t"
          . $domain
          . $sd
          . substr( $domain, 0, 1 ) . "\t"
          . $seq_status
          . $sd
          . substr( $seq_status, 0, 1 ) . "\t";

        $row .= $taxon_oid . $sd . $taxon_oid . "\t";

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ( $extraColName && defined $extracolumn_href) {
            if ( defined $extracolumn_href ) {
                my $extraColLabel = $extracolumn_href->{$taxon_oid};
                if ( defined $extracollink_href ) {
                    my $extraColLink = $extracollink_href->{$taxon_oid};
                    $row .= $extraColLabel . $sd . $extraColLink . "\t";
                } else {
                    $row .= $extraColLabel . $sd . $extraColLabel . "\t";
                }
            }
            else {
                $row .= $sd . "\t";                
            }
        }

        $it->addRow($row);
    }
    
    my $txTableName = "taxontable";    # name of current instance of taxon table
    if ($count > 10) {
        print submit(
              -name    => 'setTaxonFilter',
              -value   => 'Add Selected to Genome Cart',
              -class   => 'meddefbutton',
              -onClick => "return isGenomeSelected('$txTableName');"
        );
        print nbsp(2);
        WebUtil::printButtonFooter();
    }    
    $it->printOuterTable(1);
    print submit(
          -name    => 'setTaxonFilter',
          -value   => 'Add Selected to Genome Cart',
          -class   => 'meddefbutton',
          -onClick => "return isGenomeSelected('$txTableName');"
    );
    print nbsp(2);
    WebUtil::printButtonFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form() if(!$disableFormPrint);
}

############################################################################
# fetchGenomeList
############################################################################
sub fetchGenomeList {
    my ( $dbh, $sql, $verbose, @args ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @args );
    my @taxon_oids;
    my %done;
    for ( ; ; ) {
        my ( $taxon_oid, @junk ) = $cur->fetchrow();
        last if !$taxon_oid;
        next if $done{$taxon_oid} ne '';
        push( @taxon_oids, $taxon_oid );
        $done{$taxon_oid} = 1;
    }
    $cur->finish();

    return @taxon_oids;
}

#----------------------------------------------------------------------
#
# Color section
#
#-------------------------------------------------------------------------

#
# gets rgb color codes hash using the html color code hash
#
# param  hash ref key => html color code -  20  => "#0000FF"
# return hash ref key => rbg color - 20 => 0,0,255
sub getRGBColor {
    my ($color_href) = @_;

    my %rgb;

    foreach my $key ( keys %$color_href ) {
        my $htmlcolor = $color_href->{$key};

        $htmlcolor =~ s/#//;
        my @chars = split( "", $htmlcolor );

        my $count = 0;
        my $str   = "";
        foreach my $c (@chars) {
            if ( $count < 2 ) {
                $str .= $c;
            } else {
                my $dec = hex $str;
                $rgb{$key} = $rgb{$key} . "," . $dec;
                $count     = 0;
                $str       = $c;
            }
            $count++;
        }

        my $dec = hex $str;
        $rgb{$key} = $rgb{$key} . "," . $dec;
        my $tmp = $rgb{$key};
        $tmp =~ s/,//;    # remove the 1st comma
        $rgb{$key} = $tmp;
    }

    return \%rgb;
}

# param - rgb color 255,255,255
# return - FFFFFF
sub getRgbToHex {
    my ($rgb_color) = @_;
    $rgb_color =~ s/\s//g;
    my @a = split( ",", $rgb_color );
    my $hex_str;
    foreach my $color (@a) {
        my $hexval = sprintf( "%x", $color );
        $hex_str .= $hexval;
    }
    return $hex_str;
}

#
# given the kegg id get the color
# kegg id example = 03050
sub getKeggColor {
    my ( $sp, $kegg_id ) = @_;

    return getTigrfamCatColor( $sp, $kegg_id );

    #    my $color_array = $sp->{color_array};
    #    my $color;
    #
    #    if ( $kegg_id eq "" ) {
    #        return $sp->{color_yellow};
    #    }

    # max number
    # 9 * 2^4 + 9 * 2^3 + 9 * 2^2  +9 * 2^1 + 9 * 2^0 = 279
    # but the rgb.scrambled.txt only has 246 color
    #
    # BUT right now I'm using triary not binary base 3 not 2
    # BECAUSE there are not that many kegg ids yet so the color
    # range does not very much with binary
    #
    # split by char
    #    my @a = split( / */, $kegg_id );
    #    @a = reverse(@a);
    #
    #    #print Dumper \@a;
    #    my $sum = 0;
    #    my $i   = 0;
    #    foreach my $x (@a) {
    #        $sum = $sum + ( $x * ( 2**$i ) );
    #        $i++;
    #    }
    #
    #    # array size 246
    #    # array index 0 to 245
    #    if ( $sum >= 245 ) {
    #        $sum = 245;
    #    }
    #
    #    $color = $color_array->[$sum];
    #
    #    return ( $color, $sum );
}

# get pfam colors
sub getPfamColor {
    my ( $sp, $pfam ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    if ( $pfam eq "" ) {

        #webLog("No cog color is yellow\n");
        return $sp->{color_yellow};
    }

    # remove pfam from pfam00923

    my $pfam_num = substr( $pfam, 4 );
    my @a = split( / */, $pfam_num );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {
        #print "yellow found<br>";
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

# get pfam cat colors
sub getPfamCatColor {
    my ( $sp, $pfamcat ) = @_;
    my $color_array = $sp->{color_array};
    if ( $pfamcat eq "" ) {
        return $sp->{color_yellow};
    }

    my $idx   = ord($pfamcat);
    my $color = $color_array->[$idx];
    if ( $color == $sp->{color_yellow} ) {
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

# get tigrfam cat colors
sub getTigrfamCatColor {
    my ( $sp, $tfamcat ) = @_;
    my $color_array = $sp->{color_array};
    if ( $tfamcat eq "" ) {
        return $sp->{color_yellow};
    }

    my $idx   = $tfamcat % 255;
    my $color = $color_array->[$idx];
    if ( $color == $sp->{color_yellow} ) {
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

# tigrfam color
sub getTigrfamColor {
    my ( $sp, $fam ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    if ( $fam eq "" ) {

        #webLog("No cog color is yellow\n");
        return $sp->{color_yellow};
    }

    # remove TIGR from TIGR02532
    my $fam_num = substr( $fam, 4 );
    my @a = split( / */, $fam_num );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {

        #print "yellow found<br>";
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

# kegg color, use the level 03 as cat. to color a group of ko ids
#
# kegg brite tree cat.
# we want to read the level 3 cat. so all level 4 sum up to
#
# return
#   hash of hash - ko_oid => hash of kegg_oid => kegg_oid's name
#   hash - kegg_oid => name
#
# ko_id === KO:K00845
# kegg_oid === 00010
#
sub readKeggTreeFile {

    # hash of hash
    # ko_oid => hash of kegg_oid => $a[2] - kegg_oid's name
    my %data;

    # kegg_oid => name;
    my %cat_level;

    # now read tree file
    # branch level (A,B,C, D)
    # A kegg_id name
    # B kegg_id name
    # C kegg_id name
    # D ko_id   name
    my $fh = newReadFileHandle($kegg_brite_tree_file);

    my $last_kegg_oid;
    my $last_kegg_name;
    while ( my $line = $fh->getline() ) {
        chomp $line;
        my @a = split( /\t/, $line );
        if ( $a[0] eq "A" ) {
            next;
        } elsif ( $a[0] eq "B" ) {
            next;
        } elsif ( $a[0] eq "C" ) {

            # leve 03
            # C
            $last_kegg_oid = $a[1];
            my @tmp = split( /\[/, $a[2] );
            $last_kegg_name = $tmp[0];

            $cat_level{$last_kegg_oid} = $last_kegg_name;

        } elsif ( $a[0] eq "D" ) {

            # level 04
            my $ko_oid = addIdPrefix( $a[1], 1 );
            if ( exists $data{$ko_oid} ) {
                my $href = $data{$ko_oid};
                $href->{$last_kegg_oid} = $last_kegg_name;
            } else {
                my %hash;
                $hash{$last_kegg_oid} = $last_kegg_name;
                $data{$ko_oid}        = \%hash;
            }
        }
    }
    close $fh;

    # test section
    #    print $kegg_brite_tree_file . "<br/>\n";
    #    my $size = keys %cat_level;
    #    print "cat $size <br/>\n";
    #    print "<p>\n";
    #
    #    my $args = {
    #                 id                 => "$$",
    #                 start_coord        => 1,
    #                 end_coord          => 10,
    #                 coord_incr         => 1,
    #                 title              => "a",
    #                 strand             => "+",
    #                 has_frame          => 1,
    #                 gene_page_base_url => "",
    #                 color_array_file   => $env->{large_color_array_file},
    #                 tmp_dir            => $tmp_dir,
    #                 tmp_url            => $tmp_url,
    #    };
    #    require GeneCassettePanel2;
    #    my $sp          = new GeneCassettePanel2($args);
    #
    #    foreach my $key (sort keys %cat_level) {
    #        my ($color, $binary) = getKeggColor($sp, $key);
    #        print "$key === $binary === $color <br/>\n";
    #    }
    #
    #    print "<p>\n";
    #    print Dumper \%data;
    #    print "<p>\n";
    #    print Dumper \%cat_level;
    # test section

    return ( \%data, \%cat_level );
}

###################################################################
# Remove duplicates from an array of arrays. i.e. make an array of
# arrays unique based on a desired key element (or "column")
#
# $col = index of the element (key) of
#          sub array to make unique
# @arr = array of arrays
###################################################################

sub uniqAoA {
    my ( $col, @arr ) = @_;

    my @unique = ();
    my %dup    = ();
    foreach my $elem (@arr) {
        next if $dup{ $elem->[$col] }++;
        push @unique, $elem;
    }
    return @unique;
}

###################################################################
#
# Extract value from HTML attribute in tag
# e.g. <input type='checkbox' name='sometext' ... / >
# Inputs: $name = name string for the required value (e.g. "type")
#         $tagStr = entire HTML tag containing the all name value pairs
# Returns: string value without quotes (e.g. "checkbox")
#
###################################################################

sub getHTMLAttrValue {
    my ( $name, $tagStr ) = @_;
    my @htmlTokens = split( /\s+/, $tagStr );
    my %hashValues;

    foreach my $el (@htmlTokens) {
        my @key = split( /\s*=\s*/, $el );
        $hashValues{ $key[0] } = $key[1];
        $hashValues{ $key[0] } =~ s/('|")//gi;
    }
    return $hashValues{$name};
}

sub printTaxonName {
    my ( $taxon_oid, $taxon_name, $noEndTag ) = @_;

    print "<p style='width: 650px;'>\n";
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url, $taxon_name, "_blank" );
    if ( ! $noEndTag ) {
        print "</p>\n";        
    }

    return $taxon_name;
}

sub printMetaTaxonName {
    my ( $taxon_oid, $taxon_name, $data_type, $noEndTag ) = @_;

    $taxon_name = appendMetaTaxonNameWithDataType( $taxon_name, $data_type );

    print "<p style='width: 650px;'>\n";
    my $url = "$main_cgi?section=MetaDetail&page=metaDetail&taxon_oid=$taxon_oid";
    print "Genome: " . alink( $url, $taxon_name, "_blank" );
    if ( ! $noEndTag ) {
        print "</p>\n";        
    }
    
    return $taxon_name;
}

sub printEndTag {
    print "</p>\n";
}

sub printTaxonNameWithDataType {
    my ( $dbh, $taxon_oid, $taxon_name, $data_type ) = @_;

    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    if ( $isTaxonInFile ) {
        $taxon_name = printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );
    }
    else {
        printTaxonName( $taxon_oid, $taxon_name );
    }
    
    return $taxon_name;
}

sub appendMetaTaxonNameWithDataType {
    my ( $taxon_name, $data_type ) = @_;

    $taxon_name .= " (MER-FS)";
    if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
        $taxon_name .= " ($data_type)";
    }
    
    return ($taxon_name);
}

sub appendMetaTaxonNameWithDataTypeAtBreak {
    my ( $taxon_name, $data_type ) = @_;

    $taxon_name .= "<br/>(MER-FS)";
    if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
        $taxon_name .= "<br/>($data_type)";
    }
    
    return ($taxon_name);
}

sub printMetaDataTypeChoice {
    my ( $suffix, $noBoth, $assembledOnly, $noPageTag ) = @_;

    if ( $include_metagenomes ) {
        if ( !$noPageTag ) {
            print qq{
                <p>
            };
        }
        print qq{
            MER-FS Metagenome: &nbsp; 
            <select name="data_type$suffix" >
            <option value="assembled" > Assembled </option>
        };
        if ( ! $assembledOnly ) {
            print qq{
                <option value="unassembled" > Unassembled (slow) </option>
            };
            if ( ! $noBoth ) {
                print qq{
                    <option value="both" > Both (very slow) </option>
                };        
            }
        }
        print qq{
            </select>
        };
        if ( !$noPageTag ) {
            print qq{
                </p>
            };
        }
    }
}

sub printMetaDataTypeSelection {
    my ( $data_type, $breakPosition ) = @_;
    #$breakPosition: 0 or empty no break; 1 before; 2 after;

    if ( $include_metagenomes && $data_type ) {
        #if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
            print "<br/>\n" if ( $breakPosition == 1 );
            print "MER-FS Metagenome: " . $data_type;
            print "<br/>\n" if ( $breakPosition == 2 );
        #}
    }
}

# google event tracker for an url
#
#<a href='forgot.cgi' onClick="_gaq.push(['_trackEvent', 'Password', 'IMG Account', 'reset']);">
# Reset IMG Account Password</a> 
#
# Export, user contact oid, what was exported
# eg Export, 3038, yui table ....
# eg Export, 3038, img button ....
#
#
# my $contact_oid = WebUtil::getContactOid();
# my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");
# print qq{
#   <input id='exportButton$tabpage' class='lgdefbutton' name='$name' type="submit" value="Export Tab Delimited To Excel" $str>
# };
#  
sub trackEvent {
    my ( $action, $opt_label, $opt_value, $postJS) = @_;
    
    # 'Password', 'IMG Account', 'reset'
    my $str = qq{
onClick="_gaq.push(['_trackEvent', '$action', '$opt_label', '$opt_value']); $postJS"
    };
    
    return $str;
}

# given Gp... pr Gs or Ga
# return the correct url
#   Gp => https://gold.jgi-psf.org/projects?id=Gp....
#   Where the leadingGp and zero have been removed
sub getGoldUrl {
    my ($goldId) = @_;

    my $tmp = $goldId;
    #$tmp =~ s/^G\w[0]+//; # remove the Gx00...
    # Gold now supports the full id Gp001234 etc
    
    my $url;
    if ( $goldId =~ /^Gp/ ) {
        $url = $env->{gold_base_url_project} . $tmp;
    } elsif($goldId =~ /^Ga/) {
        $url = $env->{gold_base_url_analysis} . $tmp;
    } elsif($goldId =~ /^Gs/) {
        $url = $env->{gold_base_url_study} . $tmp;
    }

    return $url;
}


1;
