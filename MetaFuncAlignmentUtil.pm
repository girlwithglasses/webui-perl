############################################################################
# MetaFuncAlignmentUtil.pm
#   Misc. utility functions to support HTML.
#   (file version)
# $Id: MetaFuncAlignmentUtil.pm 33190 2015-04-17 23:20:02Z jinghuahuang $
############################################################################
package MetaFuncAlignmentUtil;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
    printMetaCog
    printMetaPfam
);

use strict;
use CGI qw( :standard );
use CGI::Session;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use MetaUtil;
use HashUtil;


# Force flush
$| = 1;

my $env = getEnv();
my $main_cgi = $env->{main_cgi};
my $cog_base_url = $env->{cog_base_url};
my $pfam_base_url = $env->{pfam_base_url};
my $verbose = $env->{verbose};
my $mer_data_dir = $env->{mer_data_dir};

my $image_len = 150;

############################################################################
# printMetaCog - Show COG hit.
############################################################################
sub printMetaCog {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, 
	 $aa_seq_length, $cog_ref ) = @_;

    if ( ! $cog_ref || scalar(@$cog_ref) == 0 ) {
	return;
    }

    my $count = 0;
    my @recs;

    for my $line ( @$cog_ref ) {
	my ($gid2, $cog_id, $percent_identity, $align_length,
	    $query_start, $query_end, 
	    $subj_start, $subj_end, $evalue, $bit_score, $rank) =
		split(/\t/, $line);

	$count++;

	my $rec = "$gene_oid\t";
	$rec .= "$cog_id\t";
	$rec .= "$percent_identity\t";
	$rec .= "$query_start\t";
	$rec .= "$query_end\t";
	my $evalue2 = sprintf( "%.1e", $evalue );
	$rec .= "$evalue2\t";
	$rec .= "$bit_score\t";
	$rec .= "$taxon_oid";

	push( @recs, $rec );
    }

    my $hasGeneCol = 0;

    if ($hasGeneCol) {
        $count = prinMetaCogResults_YUI( $dbh, $aa_seq_length,
					 $count, \@recs);
    }
    else {
        $count = printMetaCogResults_classic( $dbh, $aa_seq_length,
					      $count, \@recs);
    }

    return $count;    
}

sub printMetaCogResults_classic {
    my ( $dbh, $aa_seq_length, $cnt, $recs_ref) = @_;
    my @recs = @$recs_ref;
    
    if ( $cnt == 0 ) {
	print "<p>No COG for this gene.\n";
	return;
    }

    my $hasGeneCol = 0;
    print "<table class='img' cellspacing='1' border='1'>\n" if ($hasGeneCol);
    print "<tr class='img'>\n";
    print "<th class='img'>Gene  ID</th>\n" if ($hasGeneCol);
    print "<th class='img'>COG ID</th>\n";
    print "<th class='img'>Consensus<br/>Sequence<br/>Length</th>\n";
    print "<th class='img'>Description</th>\n";
    print "<th class='img'>Percent<br/>Identity</th>\n";
    if ($hasGeneCol) {
	    print "<th class='img'>Query<br/>Start</th>\n";
	    print "<th class='img'>Query<br/>End</th>\n";
        print "<th class='img'>Alignment<br/>On Query Gene</th>\n";
    } else {
        print "<th class='img'>Alignment<br/>On<br/>Query<br/>Gene</th>\n";
        print "<th class='img'>E-value</th>\n";
    }
    print "<th class='img'>Bit<br/>Score</th>\n";
    print "<th class='img'>Genome</th>\n" if ($hasGeneCol);
    print "</tr>\n";

    my $count = 0;
    my $taxon_display_name = "";

    for my $r (@recs) {
        my (
             $gene_oid,         $cog_id,
             $percent_identity, $query_start, $query_end,
             $evalue,           $bit_score,   $taxon_oid )
          = split( /\t/, $r );
        #next if $done{$cog_id} ne "";
        $count++;

        print "<tr class='img'>\n";
        if ($hasGeneCol) {
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            my $geneLink .= alink( $url, $gene_oid );
            print "<td class='img'>$geneLink</td>\n";
        }
        print "<td class='img'>$cog_id</td>\n";

	my $sql = qq{
	    select c.seq_length, c.cog_name
		from cog c
		where c.cog_id = ?
	    };
    	my $cur = execSql ($dbh, $sql, $verbose, $cog_id);
	my ($seq_length, $cog_name) = $cur->fetchrow();
	$cur->finish();

        print "<td class='img'>$seq_length</td>\n";

        print "<td class='img' >\n";

	my $sql = qq{
	    select cfs.cog_id, cf.function_code, cf.definition
		from cog_function cf, cog_functions cfs
		where cf.function_code = cfs.functions
		and cfs.cog_id = ?
	    };
    	my $cur = execSql ($dbh, $sql, $verbose, $cog_id);
	for (;;) {
	    my ($c_id, $function_code, $definition) = $cur->fetchrow();
	    last if ! $c_id;

	    print "[$function_code] ";
	    my $url =
		"$main_cgi?section=CogCategoryDetail"
		. "&page=cogCategoryDetail";
	    $url .= "&function_code=$function_code";
	    print alink( $url, $definition ) . "<br/>\n";
	}
	$cur->finish();

        print nbsp(2) . escHtml($cog_name);
        print "</td>\n";
        print "<td class='img' align='right'>$percent_identity</td>\n";
        if ($hasGeneCol) {
	        print "<td class='img' align='right'>$query_start</td>\n";
	        print "<td class='img' align='right'>$query_end</td>\n";        	
	        print "<td class='img' align='middle' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length, $image_len )
	          . "</td>\n";
        }
        else {
	        print "<td class='img' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length )
	          . "</td>\n";        	
            print "<td class='img' align='left'>$evalue</td>\n";
        }
        $bit_score = sprintf( "%d", $bit_score );
        print "<td class='img' align='right'>$bit_score</td>\n";
        if ($hasGeneCol) {
	        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            my $genomeLink .= alink( $taxon_url, $taxon_display_name );
            print "<td class='img'>$genomeLink</td>\n";
        }
        print "</tr>\n";
    }
    print "</table>\n" if ($hasGeneCol); 
    
    return $count;
}

sub printMetaCogResults_YUI {
    my ( $dbh, $aa_seq_length, $cnt, $recs_ref, $cogId2Func_ref) = @_;
    my @recs = @$recs_ref;
    my %cogId2Func = %$cogId2Func_ref;

    if ( $cnt == 0 ) {
	print "<p>No COG for this gene.\n";
	return;
    }

    #test use, keep it for future
    #print "content-type: text/html<br/>\n"; 
    #print "Size of INC is: ".scalar(@INC)."<br/>\n"; 
    #print "Value of INC is: @INC<br/>\n"; 
    #print "DOCUMENT_ROOT is: $ENV{'DOCUMENT_ROOT'}<br/>\n"; 
    #my $dbh = dbLogin();
    #my @gene_oids = ('638154501', '638154502', '641228483');
    #require HtmlUtil;
    #HtmlUtil::printGeneListHtmlTable("test", 'subtest', $dbh, \@gene_oids);

    my $it = new InnerTable( 1, "cogAlignment$$", "cogAlignment", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

#    $it->addColSpec( "Gene ID", "number asc", "center" );
    $it->addColSpec( "COG ID", "asc", "center" );
    $it->addColSpec( "COG Name", "asc" );
    $it->addColSpec( "Consensus<br/>Sequence<br/>Length", "number asc", "right" );
    $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    $it->addColSpec( "Query<br/>Start", "number asc", "right" );
    $it->addColSpec( "Query<br/>End", "number desc", "right" );
    $it->addColSpec( "Alignment On Query Gene", "desc" );
    $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    $it->addColSpec( "Genome", "asc" );

    my $count = 0;
    my $taxon_display_name = "";

    for my $r (@recs) {
        my (
             $gene_oid,         $cog_id,
             $percent_identity, $query_start, $query_end,
             $evalue,           $bit_score,   $taxon_oid )
          = split( /\t/, $r );
        #next if $done{$cog_id} ne "";
        $count++;

        my $row;
        my $gene_url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ). "\t";

        my $url = "$cog_base_url$cog_id";
        $row .= $cog_id . $sd . alink( $url, $cog_id ) . "\t";

	my $sql = qq{
	    select c.seq_length, c.cog_name
		from cog c
		where c.cog_id = ?
	    };
    	my $cur = execSql ($dbh, $sql, $verbose, $cog_id);
	my ($seq_length, $cog_name) = $cur->fetchrow();
	$cur->finish();

	my $sql = qq{
	    select cfs.cog_id, cf.function_code, cf.definition
		from cog_function cf, cog_functions cfs
		where cf.function_code = cfs.functions
		and cfs.cog_id = ?
	    };
    	my $cur = execSql ($dbh, $sql, $verbose, $cog_id);
	my $cog_desc = "";
	for (;;) {
	    my ($c_id, $function_code, $definition) = $cur->fetchrow();
	    last if ! $c_id;

	    my $url = "$main_cgi?section=CogCategoryDetail&page=cogCategoryDetail";
	    $url .= "&function_code=$function_code";
	    $cog_desc .= "[$function_code] ". alink( $url, $definition ) . "<br/>\n";
	}
	$cur->finish();

        $cog_desc .= escHtml($cog_name);
        $row .= $cog_name . $sd . $cog_desc . "\t";
        
        $row .= $seq_length . $sd . $seq_length . "\t";
        $row .= $percent_identity . $sd . $percent_identity . "\t";
        $row .= $query_start . $sd . $query_start . "\t";
        $row .= $query_end . $sd . $query_end . "\t";
        $row .= '' . $sd . alignImage( $query_start, $query_end, $aa_seq_length, $image_len ) . "\t";

        $bit_score = sprintf( "%d", $bit_score );
        $row .= $bit_score . $sd . $bit_score . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $taxon_url, escHtml($taxon_display_name) ) . "\t";

        $it->addRow($row);
    }
    #$it->printOuterTable(1);
    $it->printOuterTable(1, "history-min.js"); #"history-min.js" from yui-table affects the tabview
    
    return $count;
}

############################################################################
# printMetaPfam - Show Protein Family hits.
# (file version)
############################################################################
sub printMetaPfam {
    my ( $dbh, $gene_oid, $taxon_oid, $data_type, 
	 $aa_seq_length, $pfam_ref ) = @_;

    if ( ! $pfam_ref || scalar(@$pfam_ref) == 0 ) {
	return;
    }

    my $count = 0;
    my @recs;

    my $pfam_str = ""; 
    for my $line ( @$pfam_ref ) {
        chomp($line); 
        my ($gid2, $ext_accession, $percent_identity, $query_start, $query_end,
	    $subj_start, $subj_end, $evalue, $bit_score, $align_length) = 
		split(/\t/, $line); 

        $count++;

        my $rec = "$gene_oid\t";
        $rec .= "$ext_accession\t";
        $rec .= "$percent_identity\t";
        $rec .= "$query_start\t";
        $rec .= "$query_end\t";
        my $evalue2 = sprintf( "%.1e", $evalue );
        $rec .= "$evalue2\t";
        $rec .= "$bit_score\t";
	$rec .= "$taxon_oid";

        push( @recs, $rec );
    }

    my $hasGeneCol = 0;
    if ($hasGeneCol) {
        $count = printMetaPfamResults_YUI( $dbh, $aa_seq_length,
					   $count, \@recs, $hasGeneCol);
    }
    else {
        $count = printMetaPfamResults_classic($dbh, $aa_seq_length,
					      $count, \@recs);
    }
    #print "printPfamResults \$count: $count<br/>\n";

    return $count;    
}

sub printMetaPfamResults_classic {
    my ( $dbh, $aa_seq_length, $cnt, $recs_ref, $hasGeneCol ) = @_;
    my @recs = @$recs_ref;

    if ( $cnt == 0 ) {
	print "<p>No Pfam for this gene.\n";
	return;
    }

    my $doHmm = 1;

    print "<table class='img' cellspacing='1' border='1'>\n" if ($hasGeneCol);
    print "<tr class='img'>\n";
    print "<th class='img'>Gene ID</th>\n" if ($hasGeneCol);
    print "<th class='img'>Pfam Domain</th>\n";
    if ($doHmm) {
        print "<th class='img'>HMM Pfam Hit</th>\n";
    } else {
        print "<th class='img'>CDD Pfam Hit</th>\n";
    }
    print "<th class='img'>Description</th>\n";
    if ($doHmm) {
        print "<th class='img'>Percent<br/>Alignment<br/>"
          . "On<br/>Query Gene</th>\n";
    } else {
        print "<th class='img'>Percent<br/>Identity</th>\n";
    }
    if ($hasGeneCol) {
	    print "<th class='img'>Query<br/>Start</th>\n";
	    print "<th class='img'>Query<br/>End</th>\n";
        print "<th class='img'>Alignment<br/>On Query Gene</th>\n";
    } else {
        print "<th class='img'>Alignment<br/>On<br/>Query<br/>Gene</th>\n";
        print "<th class='img'>E-value</th>\n";
    }
    if ($doHmm) {
        print "<th class='img'>HMM<br/>Score</th>\n";
    } else {
        print "<th class='img'>Bit Score</th>\n";
    }
    print "<th class='img'>Genome</th>\n" if ($hasGeneCol);
    print "</tr>\n";

    my $count = 0;
    my $taxon_display_name = "";

    #my %done;
    for my $r (@recs) {
        my (
             $gene_oid,    $ext_accession,
             $percent_identity, $query_start,
             $query_end,  $evalue,      $bit_score,
             $taxon_oid ) 
	    = split( /\t/, $r );
        # --es 04/14/08 Allow for multiple same Pfam hits, along diff. coordinates
        #next if $done{ $ext_accession } ne "";
        $count++;

        print "<tr class='img'>\n";

        if ($hasGeneCol) {
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
            my $geneLink .= alink( $url, $gene_oid );
            print "<td class='img' >$geneLink</td>\n";
        }

	my $sql = qq{
	    select pf.name, pf.description
		from pfam_family pf
		where pf.ext_accession = ?
	    };
	my $cur = execSql ($dbh, $sql, $verbose, $ext_accession);
	my ($name, $description) = $cur->fetchrow();
	$cur->finish();

        print "<td class='img' >" . escHtml($name) . "</td>\n";

        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        print "<td class='img' >" . alink( $url, $ext_accession ) . "</td>\n";

        my @sentences = split( /\. /, $description );
        my $description2 = $sentences[0];
        print "<td class='img' >" . escHtml($description2) . "</td>\n";

        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $perc_alignment =
          ( ( $query_end - $query_start + 1 ) / $aa_seq_length ) * 100;
        $perc_alignment = sprintf( "%.2f", $perc_alignment );
        $percent_identity = $perc_alignment if $doHmm;
        print "<td class='img' align='right'>"
          . escHtml($percent_identity)
          . "</td>\n";

        if ($hasGeneCol) {
            print "<td class='img' align='right'>$query_start</td>\n";
            print "<td class='img' align='right'>$query_end</td>\n";           
	        print "<td class='img' align='middle' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length, $image_len )
	          . "</td>\n";
        }
        else {
	        print "<td class='img' nowrap>"
	          . alignImage( $query_start, $query_end, $aa_seq_length )
	          . "</td>\n";        	
            print "<td class='img'>" . escHtml($evalue) . "</td>\n";
        }

        $bit_score = sprintf( "%d", $bit_score );
        print "<td class='img' align='right'>"
          . escHtml($bit_score)
          . "</td>\n";

        if ($hasGeneCol) {
            my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            my $genomeLink .= alink( $taxon_url, $taxon_display_name );
            print "<td class='img'>$genomeLink</td>\n";
        }
        print "</tr>\n";

        #$done{ $ext_accession } = 1;
    }
    print "</table>\n" if ($hasGeneCol); 

    return $count;
}

sub printMetaPfamResults_YUI {
    my ( $dbh, $aa_seq_length, $cnt, $recs_ref ) = @_;
    my @recs = @$recs_ref;

    if ( $cnt == 0 ) {
	print "<p>No Pfam for this gene.\n";
	return;
    }

    my $it = new InnerTable( 1, "pfamAlignment$$", "pfamAlignment", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $doHmm = 1;

    $it->addColSpec( "Gene ID", "number asc", "center" );
    $it->addColSpec( "Pfam ID", "asc", "center" );
    $it->addColSpec( "Pfam Name", "asc" );
    if ($doHmm) {
        $it->addColSpec( "Percent<br/>Alignment<br/>On<br/>Query Gene", "number desc", "right" );
    } else {
        $it->addColSpec( "Percent<br/>Identity", "number desc", "right" );
    }
    $it->addColSpec( "Query<br/>Start", "number asc", "right" );
    $it->addColSpec( "Query<br/>End", "number desc", "right" );
    $it->addColSpec( "Alignment On Query Gene", "desc" );
    if ($doHmm) {
        $it->addColSpec( "HMM<br/>Score", "number desc", "right" );
    } else {
        $it->addColSpec( "Bit<br/>Score", "number desc", "right" );
    }
    $it->addColSpec( "Genome", "asc" );

    my $count = 0;
    my $taxon_display_name;

    #my %done;
    for my $r (@recs) {
        my (
             $gene_oid,    $ext_accession,
             $percent_identity, $query_start,
             $query_end, $evalue,      $bit_score,
             $taxon_oid ) = split( /\t/, $r );
        # --es 04/14/08 Allow for multiple same Pfam hits, along diff. coordinates
        #next if $done{ $ext_accession } ne "";
        $count++;

        my $row;
        my $gene_url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $gene_url, $gene_oid ). "\t";

	my $sql = qq{
	    select pf.name, pf.description
		from pfam_family pf
		where pf.ext_accession = ?
	    };
	my $cur = execSql ($dbh, $sql, $verbose, $ext_accession);
	my ($name, $description) = $cur->fetchrow();
	$cur->finish();

        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        $row .= $ext_accession . $sd . alink( $url, $ext_accession ) . "\t";

        my $x;
        $x = " - $description" if $doHmm;
        $row .= "$name$x" . $sd . "$name$x" . "\t";

        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $perc_alignment =
          ( ( $query_end - $query_start + 1 ) / $aa_seq_length ) * 100;
        $perc_alignment = sprintf( "%.2f", $perc_alignment );
        $percent_identity = $perc_alignment if $doHmm;
        $row .= $percent_identity . $sd . escHtml($percent_identity) . "\t";

        $row .= $query_start . $sd . $query_start . "\t";
        $row .= $query_end . $sd . $query_end . "\t";
        $row .= '' . $sd . alignImage( $query_start, $query_end, $aa_seq_length, $image_len ) . "\t";

        $bit_score = sprintf( "%d", $bit_score );
        $row .= $bit_score . $sd . escHtml($bit_score) . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_display_name . $sd . alink( $taxon_url, escHtml($taxon_display_name) ) . "\t";

        $it->addRow($row);
        #$done{ $ext_accession } = 1;
    }
    #$it->printOuterTable(1);
    #$it->printOuterTable(1, "history-min.js", '<script type="text/javascript">', '<script type="text/javascript" id="evalMe">'); #callback not working
    $it->printOuterTable(1, "history-min.js"); #"history-min.js" from yui-table affects the tabview

    return $count;
}

1;

