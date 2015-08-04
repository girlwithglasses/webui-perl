###########################################################################
# $Id$
###########################################################################
package HistogramUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use CGI qw( :standard );
use POSIX qw(ceil floor);
use WebUtil;
use WebConfig;
use ChartUtil;
use InnerTable;
use HtmlUtil;
use OracleUtil;
use QueryUtil;
use MetaUtil;

$| = 1;

my $env                 = getEnv();
my $cgi_dir             = $env->{cgi_dir};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $cgi_url             = $env->{cgi_url};
my $main_cgi            = $env->{main_cgi};
my $inner_cgi           = $env->{inner_cgi};
my $tmp_url             = $env->{tmp_url};
my $base_url            = $env->{base_url};
my $verbose             = $env->{verbose};
my $include_metagenomes = $env->{include_metagenomes};
my $in_file             = $env->{in_file};
my $mer_data_dir        = $env->{mer_data_dir};
my $myimg_job           = $env->{myimg_job};
my $YUI                 = $env->{yui_dir_28};
my $yui_tables          = $env->{yui_tables};
my $img_internal        = $env->{img_internal};
my $scaffold_page_size  = $env->{scaffold_page_size};

######################################################################
# computeStats
######################################################################
sub computeStats {
    my ($val_aref) = @_;

    my %stats_h;
    my $count = scalar(@$val_aref);
    $stats_h{'count'} = $count;

    if ( $count == 0 ) {
        $stats_h{'sum'}    = 0;
        $stats_h{'mean'}   = 0;
        $stats_h{'median'} = 0;
        $stats_h{'stddev'} = 0;
        return %stats_h;
    }

    my @sortRecs = sort { $a <=> $b } (@$val_aref);
    my $m1       = ceil( $count / 2 );
    my $m2       = floor( $count / 2 );
    if ( $m1 == $m2 ) {
        $stats_h{'median'} = $sortRecs[$m1];
    }
    else {
        $stats_h{'median'} = ( $sortRecs[$m1] + $sortRecs[$m2] ) / 2;
    }

    my $sum = 0;
    for my $v (@sortRecs) {
        $sum += $v;
    }
    $stats_h{'sum'} = $sum;
    my $mean = $sum / $count;
    $stats_h{'mean'} = sprintf( "%.2f", $mean );

    # standard deviation
    my $sum2 = 0;
    for my $v (@sortRecs) {
        my $diff2 = $v - $mean;
        $sum2 += ( $diff2 * $diff2 );
    }
    my $stddev = sqrt( $sum2 / $count );
    $stats_h{'stddev'} = sprintf( "%.2f", $stddev );

    return %stats_h;
}

#############################################################################
# filterForValidMetaScaffoldAndInfo
#############################################################################
sub filterForValidMetaScaffoldAndInfo {
    my ( $metaOids_ref, $data_type ) = @_;
    my %scaf_id_h;
    foreach my $mOid (@$metaOids_ref) {
        my ( $taxon_oid2, $d2, $scaf_id2 ) = split( / /, $mOid );
        if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
            && ($d2 ne $data_type) ) {
	    next;
        }
        $scaf_id_h{$mOid} = 1;
    }

    my %scaffold_h;
    MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h );
    return (\%scaf_id_h, \%scaffold_h);
}

#############################################################################
# printScaffoldHistogram: scaffolds histogram
#############################################################################
sub printScaffoldHistogram {
    my ( $h_type, $scaffold_oids_ref, $data_type, $fname ) = @_;

    my ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max );
    if ( $h_type eq 'seq_length' ) {
        # sequence length
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max) 
            = getScaffoldSeqLengthRecs( $scaffold_oids_ref, $data_type );
    }
    elsif ( $h_type eq 'gc_percent' ) {
        # GC Content
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max) 
            = getScaffoldGCContentRecs( $scaffold_oids_ref, $data_type );
    }
    elsif ( $h_type eq 'read_depth' ) {
        # read depth
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max) 
            = getScaffoldReadDepthRecs( $scaffold_oids_ref );
    }
    else {
        # gene count
        $h_type = 'gene_count';
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max ) 
            = getScaffoldGeneCountRecs( $scaffold_oids_ref, $data_type );
    }
    drawScaffoldHistogram( $h_type, $recs_ref, $min, $max, $valid_scafs_href, 
        $scaffold_oids_ref, $data_type, $fname );   
}

#############################################################################
# printScafSetHistogram: scaffold set histogram
#############################################################################
sub printScafSetHistogram {
    my ( $h_type, $scaffold_oids_ref, $data_type, 
        $fname2scaffolds_href, $fname2shareSetName_href ) = @_;

    my ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max );
    if ( $h_type eq 'seq_length' ) {
        # sequence length
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max) 
            = getScaffoldSeqLengthRecs( $scaffold_oids_ref, $data_type );
    }
    elsif ( $h_type eq 'gc_percent' ) {
        # GC Content
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max) 
            = getScaffoldGCContentRecs( $scaffold_oids_ref, $data_type );
    }
    elsif ( $h_type eq 'read_depth' ) {
        # read depth
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max ) 
            = getScaffoldReadDepthRecs( $scaffold_oids_ref, $data_type );
    }
    else {
        # gene count
        $h_type = 'gene_count';
        ( $valid_scafs_href, $scaf2val_href, $recs_ref, $min, $max ) 
            = getScaffoldGeneCountRecs( $scaffold_oids_ref, $data_type );
    }
    #print "printScafSetHistogram() valid_scafs_href:<br/>\n";
    #print Dumper($valid_scafs_href);
    #print "<br/>\n";
    #print "printScafSetHistogram() scaf2val_href:<br/>\n";
    #print Dumper($scaf2val_href);
    #print "<br/>\n";
    #print "printScafSetHistogram() fname2scaffolds_href:<br/>\n";
    #print Dumper($fname2scaffolds_href);
    #print "<br/>\n";
    
    drawScafSetHistogram( $h_type, $recs_ref, $min, $max, 
			  $valid_scafs_href, $scaf2val_href, $data_type,
			  $fname2scaffolds_href, $fname2shareSetName_href );
}

#############################################################################
# getScaffoldGeneCountRecs
#############################################################################
sub getScaffoldGeneCountRecs {
    my ( $scaffold_oids_ref, $data_type ) = @_;
    
    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my %valid_scafs_h;
    my %scaf2val;
    my @recs;
    my $min = -1;
    my $max = 0;

    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $rclause   = WebUtil::urClause('scf.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

        my $sql = qq{ 
            select distinct ss.scaffold_oid, ss.count_total_gene 
            from scaffold_stats ss, scaffold scf
            where scf.scaffold_oid in ( $oid_str )
            and ss.scaffold_oid = scf.scaffold_oid 
            and scf.ext_accession is not null  
            and ss.seq_length > 0 
            $rclause
            $imgClause
        };
        # and ss.count_total_gene > 0

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
            last if !$scaffold_oid;

            # check range and save all values
            $min = $cnt if ( $min == -1 );
            $min = $cnt if ( $cnt <= $min );
            $max = $cnt if ( $cnt >= $max );

            $scaf2val{$scaffold_oid} = $cnt;
            $valid_scafs_h{$scaffold_oid} = 1;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );

        #in case of duplicate oid
        foreach my $dbOid ( @dbOids ) {
            my $cnt = $scaf2val{$dbOid};
            push( @recs, $cnt );                        
        }
    }

    if ( scalar(@metaOids) > 0 ) {
        my ($scaf_id_href, $scaf_info_href) 
            = filterForValidMetaScaffoldAndInfo( \@metaOids, $data_type );

        #in case of duplicate oid
        foreach my $mOid ( @metaOids ) {
            # scaffold
            if ( $scaf_id_href->{$mOid} ) {
                $valid_scafs_h{$mOid} = 1;

                my ( $seqlength, $gc_percent, $scaf_gene_cnt, $read_depth ) 
                    = split( /\t/, $scaf_info_href->{$mOid} );
    
                # check range and save all values
                $min = $scaf_gene_cnt if ( $min == -1 );
                $min = $scaf_gene_cnt if ( $scaf_gene_cnt <= $min );
                $max = $scaf_gene_cnt if ( $scaf_gene_cnt >= $max );
    
                $scaf2val{$mOid} = $scaf_gene_cnt;
                push( @recs, $scaf_gene_cnt );                
            }
        }
    }

    return (\%valid_scafs_h, \%scaf2val, \@recs, $min, $max);
}

# make equal size bins with upper value of each being the key
# input: numbins, lo value, hi value    --Anna
sub createBins { 
    my ($numbins, $lo, $hi) = @_;
    $numbins = 25 if $numbins == 0 || $numbins eq "";

    my $range = $hi - $lo + 1;
    my $binsize = ceil($range/$numbins);

    if ($hi < 1.00 && $hi > 0.00) {
	$range = $hi - $lo + 0.001;
	$binsize = sprintf( "%.3f", $range/$numbins);
    }

    my %bins;
    for (my $i = 1; $i <= $numbins; $i++) {
        my $key = $lo + $binsize * $i;
        if ($hi < $key) {
            $key = $hi;
        }
        $bins{$key} = 0;
        #print "<br/>BIN $i: $key";
    }

    return \%bins;
}

# distribute the items into bin ranges  --Anna
sub distribute2bins {
    my ($bins_href, $item2num_href, $lo, $hi, $use_log, $delim) = @_;

    $use_log = 0 if $use_log eq "";
    $delim = " to " if $delim eq "";

    my %item2num = %$item2num_href;
    my %bins = %$bins_href;
    my $numbins = scalar keys %bins;
    my $range = $hi - $lo + 1;
    my $binsize = ceil($range/$numbins);

    if ($hi < 1.000 && $hi > 0.000) {
    	$range = $hi - $lo + 0.001;
    	$binsize = sprintf( "%.3f", $range/$numbins);
    }

  OUTER: foreach my $item (keys %item2num) {
        my $val = $item2num{ $item };
    	for (my $i = 1 ; $i <= $numbins ; $i++) {
    	    my $bin = $lo + $binsize * $i;
    	    if ($hi < $bin) {
        		$bin = $hi;
    	    }
    	    if ($val <= $bin) {
        		$bins{$bin}++;
        		next OUTER;
    	    }
    	}
    }

    my $low = $lo;
    my @items;
    my @data;

    for (my $i = 1; $i <= $numbins; $i++) {
        my $bin = $lo + $binsize * $i;

        if ($hi < $bin) {
            $bin = $hi;
        }
        my $bincount = $bins{$bin};
        #print "distribute2bins() i=$i bincount=$bincount<br/>\n";
        if ( !$bincount ) {
            $bincount = 0;
        }

    	push @items, "$low".$delim."$bin";
    	push @data, $bincount;
    
    	if ($hi < 1.000 && $hi > 0.000) {
    	    $low = $bin + 0.001;
    	} else {
    	    $low = $bin + 1;
    	}
        last if $bin == $hi;
    }

    return (\@items, \@data);
}

# distribute the items into direct value bins  --Anna
sub distribute2vals {
    my ($values_aref, $item2num_href) = @_;

    my %item2num = %$item2num_href;
    my @bin_values = @$values_aref;
    my $total = scalar @bin_values;

    my %val_hash;
    my @data;
  OUTER: foreach my $item (keys %item2num) {
        my $val = $item2num{ $item };
    	for (my $i = 0; $i < $total ; $i++) {
    	    my $bin = $bin_values[$i];
    	    if ($val == $bin) {
        		$val_hash{$bin}++;
        		next OUTER;
    	    }
    	}
    }
    foreach my $key (@bin_values) {
    	my $item = $val_hash{ $key };
        #print "distribute2vals() key=$key item=$item<br/>\n";
        if ( !$item ) {
            $item = 0;
        }
    	push @data, $item;
    }

    return \@data;
}

#############################################################################
# computeScafSetHistogram
#############################################################################
sub computeScafSetHistogram {
    my ( $h_type, $recs_ref, $min, $max, $valid_scafs_href, 
        $scaf2val_href, $data_type, $fname2scaffolds_href ) = @_;

    my %binCount;
    foreach my $valStr (@$recs_ref) {
    	if ($h_type eq "read_depth") {
    	    my ($read_depth, $seqlength) = split( / /, $valStr );
    	    $binCount{$read_depth}++;
    	} elsif ($h_type eq "gc_percent") {
    	    my ($gc_percent, $seqlength) = split( / /, $valStr );
    	    $binCount{$gc_percent}++;
    	} else {
    	    $binCount{$valStr}++;
    	}
    }
    my @binKeys = sort { $a <=> $b } ( keys %binCount );

    # EQUAL WIDTH BINS
    my $numbins = 10;
    my $bins = createBins($numbins, $min, $max);
    my @items; # bin ranges

    my @series;
    my @chartdata;

    my %ss2data;
    my %ss2combined;

    foreach my $fname (sort keys %$fname2scaffolds_href) {
        push (@series, $fname);

        my $scafs_ref = $fname2scaffolds_href->{$fname};
    	my %s2val;
    	foreach my $scaf ( @$scafs_ref ) {
            next if ( ! $valid_scafs_href->{$scaf} );
    	    my $scaf_val = $scaf2val_href->{$scaf};
    	    if ($h_type eq "read_depth") {
        		my ($read_depth, $seqlength) = split( / /, $scaf_val );
        		$s2val{ $scaf } = $read_depth;
    	    } elsif ($h_type eq "gc_percent") {
        		my ($gc_percent, $seqlength) = split( / /, $scaf_val );
        		$s2val{ $scaf } = $gc_percent;
    	    } else {
        		$s2val{ $scaf } = $scaf_val;
    	    }
    	}

    	if ($numbins < scalar(keys %binCount)) {    
    	    my ($items_aref, $data_aref) 
        		= distribute2bins($bins, \%s2val, $min, $max);
            #print "computeScafSetHistogram() distribute2bins data_aref:<br/>\n";
            #print Dumper($data_aref);
            #print "<br/>\n";
    	    @items = @$items_aref;
    	    my @data = @$data_aref;

    	    $ss2data{ $fname } = $data_aref;

    	    if ($h_type eq "read_depth" ||
        		$h_type eq "gc_percent") {
        		my %bin2length;
        		my @lens;	# ordered list
        		foreach my $b (@items) {
        		    my ($lower, $upper) = split(" to ", $b);
        		    my $scafCombined = 0;
        		    foreach my $s (keys %s2val) {
            			my $valStr = $scaf2val_href->{ $s };
            			my ($cnt0, $seqlength) = split(/ /, $valStr);
            			if ($lower <= $cnt0 && $cnt0 <= $upper) {
            			    $scafCombined += $seqlength;
            			}
        		    }
        		    push @lens, $scafCombined;
        		    $bin2length{ $b } = $scafCombined;
        		    #print "<br/>bin:$b $scafCombined";
        		}

        		@data = @lens;
        		$ss2combined{ $fname } = \%bin2length;
        		#print "<br/> items: ".join(", ", @items);
        		#print "<br/> data: ".join(", ", @data); 
    	    }

    	    my $data_str = join(",", @data);
    	    push @chartdata, $data_str;

    	} else {
    	    my ($data_aref) = distribute2vals(\@binKeys, \%s2val);
            #print "computeScafSetHistogram() distribute2vals data_aref:<br/>\n";
            #print Dumper($data_aref);
            #print "<br/>\n";
            my @data = @$data_aref;
            my $data_str = join(",", @data);
            push @chartdata, $data_str;

    	    foreach my $binKey (@binKeys) {
        		my $geneCnt = sprintf("%d", $binKey);
        		push @items, $geneCnt;
    	    }

    	    @items = @binKeys;
            $ss2data{ $fname } = $data_aref;

    	    if ($h_type eq "read_depth" ||
    		$h_type eq "gc_percent") {
        		my %bin2length;
        		foreach my $b (@items) {
        		    my $scafCombined = 0;
        		    foreach my $s (keys %s2val) {
            			my $valStr = $scaf2val_href->{ $s };
            			my ($cnt0, $seqlength) = split( / /, $valStr );
            			if ($cnt0 == $b) {
            			    $scafCombined += $seqlength;
            			}
        		    }
        		    $bin2length{ $b } = $scafCombined;
        		    #print "<br/>bin:$b $scafCombined";
        		}
        
        		$ss2combined{ $fname } = \%bin2length;
    	    }
    	}
    }

    return ( \@series, \@items, \@chartdata, \%ss2data, \%ss2combined );
}

#############################################################################
# printScafSetHistogramTable
#############################################################################
sub printScafSetHistogramTable {
    my ( $h_type, $items_aref, $chartdata_aref, $ss2data_href, 
    $ss2combined_href, $data_type, $fname2shareSetName_href ) = @_;

    my $data_str = $chartdata_aref->[0];
    my @items = @$items_aref;
    my @data = split(",", $data_str);
    my %ss2combined = %$ss2combined_href;
    my %ss2data = %$ss2data_href;

    my $name = name4type($h_type);
    my $pg;
    $pg = "scaffoldGeneCount" if $h_type eq "gene_count";
    $pg = "scaffoldSeqLength" if $h_type eq "seq_length";
    $pg = "scaffoldReadDepth" if $h_type eq "read_depth";
    $pg = "scaffoldGCPercent" if $h_type eq "gc_percent";

    printMainForm();

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( $name, "asc", "right" );

    foreach my $fname (sort keys %$ss2data_href) {
    	my $url2 = "$main_cgi?section=WorkspaceScafSet"
    	    . "&page=showOneScafSetHistogram"
    	    . "&histogram_type=$h_type"
    	    . "&filename=$fname";
        $url2 .= "&data_type=$data_type" if ( $data_type );
        my $shareSetName = $fname;
        if ( $fname2shareSetName_href ) {
            $shareSetName = $fname2shareSetName_href->{$fname};
        }
    	my $link = alink($url2, $shareSetName, "_blank");

    	$it->addColSpec # having a link in header does not work with InnerTable
    	    ( $link."<br/>Scaffold Count", "desc", "right", "",
    	      "Number of Scaffolds for $fname Set", "wrap" );

    	if ($h_type eq "read_depth" ||
    	    $h_type eq "gc_percent") {
    	    $it->addColSpec
    		( $link."<br/>Combined Seq Length", "desc", "right", "",
    		  "Combined Seq Length for $fname Set", "wrap" );
    	}
    }

    my $idx = 0;
    my $url = "$main_cgi?section=WorkspaceScafSet&page=$pg&isSet=1";
    $url .= "&data_type=$data_type" if ( $data_type );
    foreach my $item (@items) {
    	my ($lower, $upper) = split(" to ", $item);
    	$upper = $lower if ($upper eq ""); # when using distribute2vals

    	my $row = $sd."<input type='checkbox' name='range' value='$item'/>\t";
    	$row .= $idx.$sd.$item."\t";

    	my $cnt4row = 0;	# check for zero rows
    	foreach my $ss (sort keys %ss2data) {
    	    my $data_aref = $ss2data{ $ss };
    	    my $cnt = $data_aref->[$idx];
    	    $cnt4row = $cnt4row + $cnt;
    	}
    	if ($cnt4row == 0) {
    	    $idx++;
    	    next;
    	}

    	foreach my $ss (sort keys %ss2data) {
    	    my $data_aref = $ss2data{ $ss };
    	    my $cnt = $data_aref->[$idx];

    	    if ($cnt) {
        		my $range = $lower.":".$upper;
        		my $url2 = $url . "&range=$range"
        		    . "&isSet=1&scaf_set_name=$ss";
        		$row .= $idx.$sd.alink($url2, $cnt, "_blank") . "\t";
            	    } else {
        		$row .= "0" . "\t";
    	    }

    	    if ($h_type eq "read_depth" ||
        		$h_type eq "gc_percent") {
        		my $bin2length_href = $ss2combined{ $ss };
        		my $length = $bin2length_href->{ $item };
        		$row .= "$length"."\t";
    	    }
    	}

    	$it->addRow($row);
    	$idx++;
    }
    $it->printOuterTable(1);

    my @keys = keys %ss2data;
    print hiddenVar("type", $h_type);
    foreach my $key (@keys) {
    	print hiddenVar("scaf_set_name", $key);
    }
    my $label = "Edit Sets";
    $label = "Edit Set" if (scalar @keys == 1);
    my $class = "medbutton";
    my $name = "_section_WorkspaceScafSet_editScaffoldSets";
    print submit(
        -name  => $name,
        -value => $label,
        -class => $class
	);

    print end_form();
}

#############################################################################
# computeScaffoldHistogram
#############################################################################
sub computeScaffoldHistogram {
    my ( $h_type, $recs_ref, $min, $max, $scaffold_oids_ref ) = @_;

    my %binCount;
    foreach my $valStr (@$recs_ref) {
        if ($h_type eq "read_depth") {
            my ($read_depth, $seqlength) = split( / /, $valStr );
            $binCount{$read_depth}++;
        } elsif ($h_type eq "gc_percent") {
            my ($gc_percent, $seqlength) = split( / /, $valStr );
            $binCount{$gc_percent}++;
        } else {
            $binCount{$valStr}++;
        }
    }
    my @binKeys = sort { $a <=> $b } ( keys %binCount );

    my %s2val;
    my %s2fullval;
    my $i = 0;
    foreach my $scaf ( @$scaffold_oids_ref ) {
	my $scaf_val = $recs_ref->[$i];
	$s2fullval{ $scaf } = $scaf_val;
	if ($h_type eq "read_depth") {
	    my ($read_depth, $seqlength) = split( / /, $scaf_val );
	    $s2val{ $scaf } = $read_depth;
	} elsif ($h_type eq "gc_percent") {
	    my ($gc_percent, $seqlength) = split( / /, $scaf_val );
	    $s2val{ $scaf } = $gc_percent;
	} else {
	    $s2val{ $scaf } = $scaf_val;
	}
	$i++;
    }

    my @chartdata;
    my %bin2length;
    my @items;	  # bin ranges
    my @data;	  # values

    # EQUAL WIDTH BINS
    my $numbins = 10;
    my $bins = createBins($numbins, $min, $max);

    if ($numbins < scalar(keys %binCount)) {
	my ($items_aref, $data_aref) =
	    distribute2bins($bins, \%s2val, $min, $max);
	@items = @$items_aref;
	@data = @$data_aref;

	my $data_str;	
	if ($h_type eq "read_depth" ||
	    $h_type eq "gc_percent") {
	    my @lens;  # ordered list
	    foreach my $b (@items) {
		my ($lower, $upper) = split(" to ", $b);
		my $scafCombined = 0;
		foreach my $s (keys %s2val) {
		    my $valStr = $s2fullval{ $s };
		    my ($cnt0, $seqlength) = split(/ /, $valStr);
		    if ($lower <= $cnt0 && $cnt0 <= $upper) {
			$scafCombined += $seqlength;
		    }
		}
		push @lens, $scafCombined;
		$bin2length{ $b } = $scafCombined;
	    }

	    $data_str = join(",", @lens);
	} else {
	    $data_str = join(",", @data);
	}

	push @chartdata, $data_str;

    } else {
	my ($data_aref) = distribute2vals(\@binKeys, \%s2val);
	@data = @$data_aref;
	my $data_str = join(",", @data);
	push @chartdata, $data_str;

	foreach my $binKey (@binKeys) {
	    my $geneCnt = sprintf("%d", $binKey);
	    push @items, $geneCnt;
	}

	@items = @binKeys;
	if ($h_type eq "read_depth" ||
	    $h_type eq "gc_percent") {
	    foreach my $b (@items) {
		my $scafCombined = 0;
		foreach my $s (keys %s2val) {
		    my $valStr = $s2val{ $s };
		    my ($cnt0, $seqlength) = split( / /, $valStr );
		    if ($cnt0 == $b) {
			$scafCombined += $seqlength;
		    }
		}
		$bin2length{ $b } = $scafCombined;
		#print "<br/>bin:$b $scafCombined";
	    }
	}
    }

    return ( \@items, \@chartdata, \%bin2length);
}

#############################################################################
# printScaffoldHistogramTable
#############################################################################
sub printScaffoldHistogramTable {
    my ( $h_type, $items_aref, $chartdata_aref,
	 $bin2length_href, $data_type ) = @_;

    my $data_str = $chartdata_aref->[0];
    my @items = @$items_aref;
    my @data = split(",", $data_str);
    my %bin2length = %$bin2length_href;

    my $name = name4type($h_type);
    my $pg;
    $pg = "scaffoldGeneCount" if $h_type eq "gene_count";
    $pg = "scaffoldSeqLength" if $h_type eq "seq_length";
    $pg = "scaffoldReadDepth" if $h_type eq "read_depth";
    $pg = "scaffoldGCPercent" if $h_type eq "gc_percent";

    my $url = "$main_cgi?section=WorkspaceScafSet&page=$pg";
    $url .= "&data_type=$data_type" if ( $data_type );

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec( $name, "asc", "right" );
    $it->addColSpec( "Scaffold Count", "desc", "right" );
    if ($h_type eq "read_depth" || $h_type eq "gc_percent") {
    	$it->addColSpec( "Combined Seq Length", "desc", "right" );
    }

    my $idx = 0;
    foreach my $item (@items) {
        my ($lower, $upper) = split(" to ", $item);
        $upper = $lower if ($upper eq ""); # when using distribute2vals

        my $row;
        $row .= $idx.$sd.$item."\t";

    	my $cnt = $data[$idx];
        if ($cnt == 0) {
            $idx++;
            next;
        }

    	if ($cnt) {
    	    my $range = $lower.":".$upper;
    	    my $url2 = $url . "&range=$range";
    	    my $func = "javascript:dosubmit('WorkspaceScafSet', '$pg', '$range', '$data_type');";
    	    my $link = "<a href=\"$func\">$cnt</a>";
    	    $row .= $idx.$sd.$link . "\t";
    	} else {
    	    $row .= "0" . "\t";
    	}

    	if ($h_type eq "read_depth" ||
    	    $h_type eq "gc_percent") {
    	    my $length = $bin2length{ $item };
    	    $row .= "$length"."\t";
    	}

        $it->addRow($row);
        $idx++;
    }

    $it->printOuterTable(1);
}

#############################################################################
# getScaffoldSeqLengthRecs
#############################################################################
sub getScaffoldSeqLengthRecs {
    my ( $scaffold_oids_ref, $data_type ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my %valid_scafs_h;
    my %scaf2val;
    my @recs;
    my $min = -1;
    my $max = 0;

    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $rclause   = WebUtil::urClause('scf.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

        my $sql = qq{ 
            select distinct ss.scaffold_oid, ss.seq_length 
            from scaffold_stats ss, scaffold scf
            where ss.scaffold_oid in ( $oid_str )
            and ss.scaffold_oid = scf.scaffold_oid 
            and scf.ext_accession is not null 
            and ss.seq_length > 0 
            $rclause
            $imgClause
            order by ss.seq_length asc 
        };

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $scaffold_oid, $seqlength ) = $cur->fetchrow();
            last if !$scaffold_oid;

            $min = $seqlength if ( $min == -1 );
            $min = $seqlength if ( $seqlength <= $min );
            $max = $seqlength if ( $seqlength >= $max );

            $scaf2val{$scaffold_oid} = $seqlength;
            $valid_scafs_h{$scaffold_oid} = 1;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );

        #in case of duplicate oid
        for my $dbOid ( @dbOids ) {
            my $seqlength = $scaf2val{$dbOid};
            push( @recs, $seqlength );
        }
    }
    #print "1min: $min; 1max: $max<br>";

    if ( scalar(@metaOids) > 0 ) {
        my ($scaf_id_href, $scaf_info_href) 
            = filterForValidMetaScaffoldAndInfo( \@metaOids, $data_type );

        #in case of duplicate oid
        for my $mOid ( @metaOids ) {
            # scaffold
            if ( $scaf_id_href->{$mOid} ) {
                $valid_scafs_h{$mOid} = 1;

                my ( $seqlength, $gc_percent, $scaf_gene_cnt, $read_depth ) 
                    = split( /\t/, $scaf_info_href->{$mOid} );

                $min = $seqlength if ( $min == -1 );
                $min = $seqlength if ( $seqlength <= $min );
                $max = $seqlength if ( $seqlength >= $max );

                $scaf2val{$mOid} = $seqlength;
                push( @recs, $seqlength );
            }
        }
    }
    #print "1min: $min; 1max: $max<br>";

    return (\%valid_scafs_h, \%scaf2val, \@recs, $min, $max);
}

#############################################################################
# getScaffoldGCContentRecs
#############################################################################
sub getScaffoldGCContentRecs {
    my ( $scaffold_oids_ref, $data_type ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my %valid_scafs_h;
    my %scaf2val;
    my @recs;
    my $min = -1;
    my $max = 0;

    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $rclause   = WebUtil::urClause('scf.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

        my $sql = qq{ 
            select distinct ss.scaffold_oid, ss.gc_percent, ss.seq_length
            from scaffold_stats ss, scaffold scf
            where ss.scaffold_oid in ( $oid_str )
            and ss.scaffold_oid = scf.scaffold_oid 
            and scf.ext_accession is not null  
            and ss.gc_percent > 0 
            $rclause
            $imgClause
            order by ss.gc_percent asc 
        };
        my $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ( $scaffold_oid, $gc_percent, $seqlength ) = $cur->fetchrow();
            last if !$scaffold_oid;

            # check range and save all values
            $min = $gc_percent if ( $min == -1 );
            $min = $gc_percent if ( $gc_percent <= $min );
            $max = $gc_percent if ( $gc_percent >= $max );

            $scaf2val{$scaffold_oid} = "$gc_percent $seqlength";
            $valid_scafs_h{$scaffold_oid} = 1;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );

        #in case of duplicate oid
        for my $dbOid ( @dbOids ) {
            my $gc_percent_seq_length = $scaf2val{$dbOid};
            push( @recs, $gc_percent_seq_length );
        }
    }
    #print "1min: $min; 1max: $max<br>";

    if ( scalar(@metaOids) > 0 ) {
        my ($scaf_id_href, $scaf_info_href) 
            = filterForValidMetaScaffoldAndInfo( \@metaOids, $data_type );

        #in case of duplicate oid
        for my $mOid ( @metaOids ) {
            # scaffold
            if ( $scaf_id_href->{$mOid} ) {
                $valid_scafs_h{$mOid} = 1;

                my ( $seqlength, $gc_percent, $scaf_gene_cnt, $read_depth ) 
                    = split( /\t/, $scaf_info_href->{$mOid} );

                # check range and save all values
                $min = $gc_percent if ( $min == -1 );
                $min = $gc_percent if ( $gc_percent <= $min );
                $max = $gc_percent if ( $gc_percent >= $max );

                my $gc_percent_seq_length = "$gc_percent $seqlength";
                $scaf2val{$mOid} = $gc_percent_seq_length;
                push( @recs, $gc_percent_seq_length );
            }
        }
    }

    return (\%valid_scafs_h, \%scaf2val, \@recs, $min, $max);
}

#############################################################################
# getScaffoldReadDepthRecs
#############################################################################
sub getScaffoldReadDepthRecs {
    my ( $scaffold_oids_ref, $data_type ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my %valid_scafs_h;
    my %scaf2val;
    my @recs;
    my $min = -1; 
    my $max = 0;

    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $rclause   = WebUtil::urClause('scf.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

        my $sql = qq{ 
            select distinct ss.scaffold_oid, scf.read_depth, ss.seq_length
            from scaffold_stats ss, scaffold scf
            where ss.scaffold_oid in ( $oid_str )
            and ss.scaffold_oid = scf.scaffold_oid 
            $rclause
            $imgClause
            order by scf.read_depth asc 
        };
        #and scf.ext_accession is not null 
        #and scf.read_depth > 0
        #print "getScaffoldReadDepthRecs() sql=$sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ( $scaffold_oid, $read_depth, $seqlength ) = $cur->fetchrow();
            last if !$scaffold_oid;

            if ( !$read_depth ) {
                $read_depth = 1;
            }

            # check range and save all values
            $min = $read_depth if ( $min == -1 );
            $min = $read_depth if ( $read_depth <= $min );
            $max = $read_depth if ( $read_depth >= $max );

            $scaf2val{$scaffold_oid} = "$read_depth $seqlength";
            $valid_scafs_h{$scaffold_oid} = 1;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );

        #in case of duplicate oid
        for my $dbOid ( @dbOids ) {
            my $read_depth_seq_length = $scaf2val{$dbOid};
            push( @recs, $read_depth_seq_length );
        }
    }

    if ( scalar(@metaOids) > 0 ) {
        my ($scaf_id_href, $scaf_info_href) 
            = filterForValidMetaScaffoldAndInfo( \@metaOids, $data_type );

        #in case of duplicate oid
        for my $mOid ( @metaOids ) {
            # scaffold
            if ( $scaf_id_href->{$mOid} ) {
                $valid_scafs_h{$mOid} = 1;

                my ( $seqlength, $gc_percent, $scaf_gene_cnt, $read_depth ) 
                    = split( /\t/, $scaf_info_href->{$mOid} );

                # check range and save all values
                $min = $read_depth if ( $min == -1 );
                $min = $read_depth if ( $read_depth <= $min );
                $max = $read_depth if ( $read_depth >= $max );

                my $read_depth_seq_length = "$read_depth $seqlength";
                $scaf2val{$mOid} = $read_depth_seq_length;
                push( @recs, $read_depth_seq_length );
            }
        }
    }

    return (\%valid_scafs_h, \%scaf2val, \@recs, $min, $max);
}

sub printScaffoldHistogramTableTitle {
    my ($h_type, $recs_ref, $total_scaf_cnt, $vaild_scaf_cnt, $data_type) = @_;

    printHistogramTableTitle($h_type, $recs_ref, $total_scaf_cnt, $vaild_scaf_cnt, $data_type);
}


sub printScafSetHistogramTableTitle {
    my ( $h_type, $recs_ref, $valid_scafs_href, $data_type, 
        $fname2scaffolds_href, $fname2shareSetName_href ) = @_;

    my $hint1 = "Click on the <u>column header</u> for a scaffold set to see the distribution for that scaffold set only.";
    $hint1 .= "<br/>Click on the <u>count</u> for a scaffold set for a given range to view/remove the scaffolds in that range. ";
    $hint1 .= "Select multiple ranges and click on <font color='blue'><u>Edit Sets</u></font> to remove multiple scaffolds from sets after review.";

    my $hint2 = "Click on the <u>count</u> for a given range to view/remove the scaffolds in that range. Select multiple ranges and click on <font color='blue'><u>Edit Set</u></font> to remove multiple scaffolds after review.";

    my $total_scaf_cnt = 0;
    if ($fname2scaffolds_href ) {
    	my $sscnt = scalar keys %$fname2scaffolds_href;
    	printHint($hint1) if $sscnt > 1;
    	printHint($hint2) if $sscnt == 1;

    	if ($sscnt == 1) {
    	    foreach my $fname (keys %$fname2scaffolds_href) {
        		my $scafs_ref = $fname2scaffolds_href->{$fname};
                $total_scaf_cnt += scalar(@$scafs_ref);
    	    }
            my $vaild_scaf_cnt = scalar(keys %$valid_scafs_href);
            printHistogramTableTitle($h_type, $recs_ref, $total_scaf_cnt, 
				     $vaild_scaf_cnt, $data_type);
    	} else {
    	    print "<br/>";
    	}
    }
}

sub printHistogramTableTitle {
    my ($h_type, $recs_ref, $total_scaf_cnt, $vaild_scaf_cnt, $data_type) = @_;
    my $title = name4type($h_type);

    print "<p>";
    print "Total numbers of scaffolds: $total_scaf_cnt";
    if ( $data_type ) {
        print "<br/>Valid numbers of scaffolds in computation: $vaild_scaf_cnt";
    }
    #HtmlUtil::printMetaDataTypeSelection( $data_type, 1 );

    my @recs;
    if ( $h_type eq 'gc_percent' || $h_type eq 'read_depth' ) {
        foreach my $valStr (@$recs_ref) {
            my ($val, $seqlength) = split( / /, $valStr );
            push(@recs, $val);
        }
    }
    else {
        @recs = @$recs_ref;
    }

    my @stats_recs = sort { $a <=> $b } @recs;
    my %stats_h = computeStats( \@stats_recs );

    print "<br/>Statistics for <u>$title</u>:";
    print "<br/>";
    print nbsp(5);
    print "range: ";
    if ( $stats_recs[0] ) {
        print $stats_recs[0];
    }
    else {
        print "0";
    }
    if ( $stats_recs[-1] ) {
        print " to " . $stats_recs[-1];
    }
    print "<br/>\n";

    for my $s ( 'sum', 'median', 'mean', 'stddev' ) {
	my $val = $stats_h{$s};
        if ( $val ) {
            $val = sprintf( "%.2f", $val );
	    print nbsp(5);
            print "$s: " . $val . "<br/>\n";
        }
        else {
	    print nbsp(5);
            print "$s: 0<br/>\n";
        }
    }
    print "</p>\n";
}

sub drawScaffoldHistogram {
    my ( $h_type, $recs_ref, $min, $max, $valid_scafs_href,
	 $scaffold_oids_ref, $data_type, $fname ) = @_;
        
    my $text = name4type($h_type);
    print "<h1>Scaffolds by $text Histogram</h1>\n";
    print "<p>Histogram is based on <u>selected</u> scaffolds.";

    use TabHTML;
    TabHTML::printTabAPILinks("scafhistogramTab");

    my @tabIndex = ( "#scaftab1", "#scaftab2" );
    my @tabNames = ( "Chart by $text", "Scaffolds by $text" );
    TabHTML::printTabDiv("scafhistogramTab", \@tabIndex, \@tabNames);

    print "<div id='scaftab1'>";
    my ( $chartcategories_ref, $chartdata_ref, $bin2length_href )
	= computeScaffoldHistogram
	( $h_type, $recs_ref, $min, $max, $scaffold_oids_ref );

    my @chartseries;
    my $title = name4type($h_type);
    push @chartseries, "Combined $title of Scaffolds";

    my $datastr = join( ",", @$chartdata_ref );
    my @datas = ($datastr);
    drawHistogramChart
	($h_type, \@chartseries, $chartcategories_ref, \@datas, 0, $data_type);
    print "</div>"; # end scaftab1

    print "<div id='scaftab2'>";
    my $total_scaf_cnt = scalar(@$scaffold_oids_ref);
    my $vaild_scaf_cnt = scalar(keys %$valid_scafs_href);
    printScaffoldHistogramTableTitle
	( $h_type, $recs_ref, $total_scaf_cnt, $vaild_scaf_cnt, $data_type );

    printScaffoldJavaScript();
    printScaffoldHistogramTable
	($h_type, $chartcategories_ref, $chartdata_ref, 
	 $bin2length_href, $data_type);
    print "</div>"; # end scaftab2

    TabHTML::printTabDivEnd();
}

sub printScaffoldJavaScript {
    print hiddenVar("range", "");
    print qq{
        <script language="JavaScript" type="text/javascript">
        function dosubmit(section, pg, range, datatype) {
            var oForm = document.createElement("form");
            oForm.method = "post";
            oForm.enctype="multipart/form-data";
            oForm.action = "main.cgi";
            oForm.appendChild(hidEl("section", section));
            oForm.appendChild(hidEl("page", pg));
            oForm.appendChild(hidEl("range", range));
            oForm.appendChild(hidEl("data_type", datatype));

            for (var i=0; i<document.mainForm.elements.length; i++) {
                var el = document.mainForm.elements[i];
                if (el.type == "hidden") {
                    if (el.name == "range") {
                        el.value = range;
                    }
                    if (el.name == "scaffold_oid") {
                        oForm.appendChild(hidEl("scaffold_oid", el.value));
                    }
                }
            }

            document.body.appendChild(oForm);
            oForm.submit();
            document.body.removeChild(oForm);

            //document.mainForm.submit();
        }

        function hidEl(name, value) {
            var inp = document.createElement("input");
            inp.type = "hidden";
            inp.name = name;
            inp.value = value;
            inp.id = name + "-" + value;
            return inp;
        }

        </script>
    };
}

sub name4type {
    my ($h_type) = @_;

    my $text;
    if ( $h_type eq 'gene_count' ) {
    	$text = "Gene Count";
    } elsif ( $h_type eq 'seq_length' ) {
    	$text = "Sequence Length";
    } elsif ( $h_type eq 'gc_percent' ) {
    	$text = "GC Percent";
    } elsif ( $h_type eq 'read_depth' ) {
    	$text = "Read Depth";
    }

    return $text;
}

sub drawScafSetHistogram {
    my ( $h_type, $recs_ref, $min, $max, $valid_scafs_href, $scaf2val_href, 
	   $data_type, $fname2scaffolds_href, $fname2shareSetName_href ) = @_;

    my $text = name4type($h_type);
    print "<h1>Scaffold Sets by $text Histogram</h1>";
    print "<p>Histogram is based on all <u>valid</u> genes in each scaffold set.";
    HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    print "<br/>";

    my @filenames = keys %$fname2scaffolds_href;
    if (scalar(@filenames) > 0) {
        for my $fname (@filenames) {
            my $shareSetName = $fname;
            if ( $fname2shareSetName_href ) {
                $shareSetName = $fname2shareSetName_href->{$fname};                
            }
            my $url2 = "$main_cgi?section=WorkspaceScafSet"
                . "&page=showDetail&filename=$fname&folder=scaffold";
            my $link = alink($url2, $shareSetName, "_blank");
            print "<br/>$link";
        }
    }
    print "</p>";

    use TabHTML;
    TabHTML::printTabAPILinks("scafsethistogramTab");

    my @tabIndex = ( "#scafsettab1", "#scafsettab2" );
    my @tabNames = ( "Chart by $text", "Scaffolds by $text" );
    TabHTML::printTabDiv("scafsethistogramTab", \@tabIndex, \@tabNames);

    print "<div id='scafsettab1'>";
    my $hint = "Click on the <u>bar</u> for a given range for a scaffold set to view/remove the scaffolds in that range after review.";
    printHint($hint);

    my ( $series_ref, $chartcategories_ref, $chartdata_ref,
	 $ss2data_href, $ss2combined_href )
	= computeScafSetHistogram( $h_type, $recs_ref, $min, $max, 
				   $valid_scafs_href, $scaf2val_href, $data_type,
				   $fname2scaffolds_href );

    #print "drawScafSetHistogram() series_ref:<br/>\n";
    #print Dumper($series_ref);
    #print "<br/>\n";
    #print "drawScafSetHistogram() chartcategories_ref:<br/>\n";
    #print Dumper($chartcategories_ref);
    #print "<br/>\n";
    #print "drawScafSetHistogram() chartdata_ref:<br/>\n";
    #print Dumper($chartdata_ref);
    #print "<br/>\n";
        
    drawHistogramChart( $h_type, $series_ref, $chartcategories_ref,
			$chartdata_ref, 1, $data_type, $fname2shareSetName_href  );
    print "</div>";		# end scafsettab1

    print "<div id='scafsettab2'>";
    printScafSetHistogramTableTitle( $h_type, $recs_ref, $valid_scafs_href,
	   $data_type, $fname2scaffolds_href, $fname2shareSetName_href  );

    printScafSetHistogramTable( $h_type, $chartcategories_ref, $chartdata_ref,
				$ss2data_href, $ss2combined_href, $data_type, $fname2shareSetName_href  );
    print "</div>";		# end scafsettab2

    TabHTML::printTabDivEnd();

}

sub drawHistogramChart {
    my ( $h_type, $series_ref, $chartcategories_ref, $chartdata_ref,
	 $isSet, $data_type, $fname2shareSetName_href ) = @_;

    my $title = name4type($h_type);
    my $y_axis;
    my $pg;
    if ( $h_type eq 'gene_count' ) {
        $y_axis = "Number of Scaffolds";
    	$pg = "scaffoldGeneCount";
    }
    elsif ( $h_type eq 'seq_length' ) {
        $y_axis = "Number of Scaffolds";
    	$pg = "scaffoldSeqLength";
    }
    elsif ( $h_type eq 'gc_percent' ) {
        $y_axis = "Combined Sequence Length of Scaffolds";
    	$pg = "scaffoldGCPercent";
    }
    elsif ( $h_type eq 'read_depth' ) {
        $y_axis = "Combined Sequence Length of Scaffolds";
    	$pg = "scaffoldReadDepth";
    }

    my $width = scalar(@$chartcategories_ref) * 30 * scalar(@$series_ref);
    if ( $width < 800 ) {
        $width = 800;
    }
    my $table_width = $width + 100;

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td padding=0 valign=top align=left>\n";

    # PREPARE THE BAR CHART
    my $chart = newBarChart();
    $chart->WIDTH($width);
    $chart->HEIGHT(550);
    $chart->DOMAIN_AXIS_LABEL("$title");
    $chart->RANGE_AXIS_LABEL("$y_axis");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->SERIES_NAME($series_ref);
    $chart->CATEGORY_NAME($chartcategories_ref);
    $chart->DATA($chartdata_ref);

    if ($isSet) {
    	my $url = "$main_cgi?section=WorkspaceScafSet&page=$pg&isSet=1";
        $url .= "&data_type=$data_type" if ( $data_type );
    	$chart->INCLUDE_URLS("yes");
    	$chart->ITEM_URL($url);
    }

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html",
		  "printScaffoldSetDistribution", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }

    print "</td>\n";
    print "<td>\n";

    if (scalar @$series_ref > 1) {
    	print "<table border='0'>\n";    
    	my $idx = 0;
    	foreach my $series1 (@$series_ref) {
    	    last if !$series1;

    	    print "<tr>\n";
    	    print "<td align=left style='font-family: Calibri, Arial, Helvetica; "
    		. "white-space: nowrap;'>\n";
    	    if ( $st == 0 ) {
        		print "<img src='$tmp_url/"
        		    . $chart->FILE_PREFIX
        		    . "-color-"
        		    . $idx
        		    . ".png' border=0>";
        		print "&nbsp;&nbsp;";
    	    }

            my $seriesName = $series1;
            if ( $fname2shareSetName_href ) {
                $seriesName = $fname2shareSetName_href->{$series1};
            }
    	    print $seriesName;
    	    print "</td>\n";
    	    print "</tr>\n";
    	    $idx++;
    	}
    	print "</table>\n";
    }

    print "</td>\n";
    print "</tr>\n";
    print "</table>\n";
}

sub getHistogramScaffoldList {
    my ( $scaffold_oids_ref, $h_type, $lower, $upper, $scaf_set_name, $data_type ) = @_;

    my $colAttr;
    if ( $h_type eq 'gene_count' ) {
        $colAttr .= "st.count_total_gene";
    }
    elsif ( $h_type eq 'seq_length' ) {
        $colAttr .= "st.seq_length";
    }
    elsif ( $h_type eq 'gc_percent' ) {
        $colAttr .= "st.gc_percent";
    }
    elsif ( $h_type eq 'read_depth' ) {
        $colAttr .= "s.read_depth";
    }
    else {
        return;
    }

    my $range_cond = $colAttr;
    if ( blankStr($lower) ) {
        if ( blankStr($upper) ) {
            # no condition
            $range_cond = "";
        }
        else {
            if ( isNumber($upper) ) {            
                $range_cond .= " <= $upper";
            }
            else {
                webError("Incorrect upper bound: $upper");
                return;
            }            
        }
    }
    else {

        if ( isNumber($lower) ) {
            if ( blankStr($upper) ) {
                $range_cond .= " >= $lower";
            }
            elsif ( !isNumber($upper) ) {
                webError("Incorrect upper bound: $upper");
                return;
            }
            elsif ( $upper == $lower ) {
                $range_cond .= " = $lower";
            }
            else {
                $range_cond .= " between $lower and $upper";
            }

            if ( $h_type eq 'read_depth' && $lower == 1 ) {
                $range_cond = "( $range_cond or $colAttr is null )";
            }            
        }
        else {
            webError("Incorrect lower bound: $lower");
            return;            
        }
    }

    my $rangeCondClause;
    if ( $range_cond ) {
        $rangeCondClause = " and " . $range_cond;        
    }
    #print "printHistogramScaffoldList() rangeCondClause: $rangeCondClause<br/>\n";

    #print "printHistogramScaffoldList() scaffold_oids_ref: @$scaffold_oids_ref<br/>\n";
    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my $dbh = dbLogin();

    my @selected = ();
    my $last_oid = 0;

    if ( scalar(@dbOids) > 0 ) {
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
        my $sql       = qq{
            select s.scaffold_oid, s.scaffold_name, 
                   s.ext_accession, s.taxon, st.seq_length,
                   st.gc_percent, s.read_depth, s.mol_topology,
                   st.count_total_gene, t.taxon_display_name
	    from scaffold s, scaffold_stats st, taxon t
	    where s.scaffold_oid in ($oid_str)
	    and s.scaffold_oid = st.scaffold_oid
	    and s.taxon = t.taxon_oid
	    $rclause
	    $imgClause
	    $rangeCondClause
        };
        #print "getHistogramScaffoldList() sql=$sql<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my (
                $s_oid,      $scaffold_name, $ext_acc,
                $taxon_oid,  $seq_length,    $gc_percent,
                $read_depth, $mol_topo,      $gene_count,    
                $taxon_display_name
		)
		= $cur->fetchrow();
            last if !$s_oid;
            #print "printHistogramScaffoldList() s_oid=$s_oid<br/>\n";

            my $r =
                "$s_oid\t$scaffold_name\t$ext_acc\t$taxon_oid\t$seq_length\t"
		. "$gc_percent\t$read_depth\t$mol_topo\t$gene_count\t"
		. "$taxon_display_name";
            determineAddToSelection
		( \@selected, $h_type, $lower, $upper, 
		  $gene_count, $seq_length, $gc_percent, $read_depth, $r );
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );
    }

    if ( scalar(@metaOids) > 0 ) {
        my %scaf_id_h;
        my %taxon_oid_h;
        foreach my $mOid (@metaOids) {
            my ( $taxon_oid, $d2, $scaf_oid ) = split( / /, $mOid );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
		 && ($d2 ne $data_type) ) {
		next;
            }
            $taxon_oid_h{ $taxon_oid } = 1;
            $scaf_id_h{$mOid} = 1;
        }
        my @taxonOids = keys(%taxon_oid_h);

        my %taxon_name_h;
        if ( scalar(@taxonOids) > 0 ) {
            %taxon_name_h =
		QueryUtil::fetchTaxonOid2NameHash( $dbh, \@taxonOids );
        }

        my %scaffold_h;
        MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h );

        foreach my $mOid (@metaOids) {
            # scaffold
            my ( $taxon_oid, $d2, $scaf_oid ) = split( / /, $mOid );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
		 && ($d2 ne $data_type) ) {
		next;
            }
            if ( !exists( $taxon_name_h{$taxon_oid} ) ) {
                #$taxon_oid not in hash, probably due to permission
                webLog("ScaffoldCart printScaffoldList:: $taxon_oid not retrieved from database, probably due to permission.");
                next;
            }

            my $taxon_display_name = $taxon_name_h{$taxon_oid};
            my ( $seq_length, $gc_percent, $gene_count, $read_depth ) 
                = split( /\t/, $scaffold_h{$mOid} );


            #empty scaffold_name and ext_accession
            my $r =
                "$mOid\t\t\t$taxon_oid\t$seq_length\t"
		. "$gc_percent\t$read_depth\tlinear\t$gene_count\t"
		. "$taxon_display_name";

            determineAddToSelection
		( \@selected, $h_type, $lower, $upper, 
		  $gene_count, $seq_length, $gc_percent, $read_depth, $r );
        }
    }

    return \@selected;
}

############################################################################
# printHistogramScaffoldList
############################################################################
sub printHistogramScaffoldList {
    my ( $scaffold_oids_ref, $h_type, $lower, $upper, $data_type, 
        $scaf_set_name, $scaf_set_share_name ) = @_;

    my $selected_aref = getHistogramScaffoldList
    ($scaffold_oids_ref, $h_type, $lower, $upper, $scaf_set_name, $data_type);
    my $cnt = scalar(@$selected_aref);
    if ( $cnt == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    my $title = name4type($h_type);
    print "<h1>Scaffolds with $title</h1>\n";

    print "<p>";
    if ($scaf_set_name) {
    	my $scfurl = "$main_cgi?section=WorkspaceScafSet"
	    . "&page=showDetail&folder=scaffold&filename=$scaf_set_name";
        print "Scaffold Set: ".alink($scfurl, $scaf_set_share_name)."<br/>";
    }
    else {
        print "All selected scaffolds in Scaffold Cart<br/>";
    }
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
    print "$title: ";
    if ( $lower && $upper ) {
        if ( $lower == $upper ) {
            print "$lower";
        }
        else {
            print "$lower to $upper";
        }
    }
    elsif ($lower) {
        print ">= $lower";
    }
    elsif ($upper) {
        print "<= $upper";
    }
    print "</p>"; # paragraph section puts text in proper font.

    printStatusLine( "$cnt scaffolds selected", 2 );
    if ( !$cnt ) {
        print end_form();
    }

    printSelectedScaffoldsTable($selected_aref, $scaf_set_name, $data_type);
}

sub printSelectedScaffoldsTable {
    my ( $selected_aref, $scaf_set_name, $data_type ) = @_;

    print hiddenVar("filename", $scaf_set_name);
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    my ($owner, $set_name) = WorkspaceUtil::splitOwnerFileset( '', $scaf_set_name );
    my $tblname = "scafSet_".$set_name; # must be same as form name
    #my $tblname = "scafSet_".$scaf_set_name; # must be same as form name
    my $it = new InnerTable( 1, $tblname."$$", $tblname, 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold ID",              "asc", "left" );
    $it->addColSpec( "Scaffold Name",            "asc", "left" );
    $it->addColSpec( "Genome",                   "asc", "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "asc", "right" );
    $it->addColSpec( "GC Content",               "asc", "right" );
    $it->addColSpec( "Read Depth",               "asc", "right" );
    $it->addColSpec( "Gene Count",               "asc", "right" );
    $it->addColSpec( "Topology",                 "asc", "left" );

    my $select_id_name = "scaffold_oid";
    my $cnt = 0;
    for my $r (@$selected_aref) {
        my (
            $workspace_id, $scaffold_name, $ext_acc,
            $taxon_oid,    $seq_length,    $gc_percent,
            $read_depth,   $mol_topo,      $gene_count,
            $taxon_display_name
          )
          = split( /\t/, $r );

        my $r;
        $r .=
            "$sd<input type='checkbox' name='$select_id_name' "
          . "value='$workspace_id' checked />\t";

        my $d2;
        my $scaffold_oid;
        if ( $workspace_id && isInt($workspace_id) ) {
            $scaffold_oid = $workspace_id;
            $d2 = 'database';
        }
        else {
            my $t_oid;
            ( $t_oid, $d2, $scaffold_oid ) = split( / /, $workspace_id );
        }

        my $scaffold_url;
        if ( $d2 eq 'database' && isInt($scaffold_oid) ) {
            $scaffold_url = "$main_cgi?section=ScaffoldCart"
                  . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
        }
        else {
            $scaffold_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaScaffoldDetail&scaffold_oid=$scaffold_oid"
              . "&taxon_oid=$taxon_oid&data_type=$d2";
        }

        $r .= $workspace_id . $sd . alink($scaffold_url, $scaffold_oid) . "\t";
        #print "workspace_id=$workspace_id, scaffold_oid=$scaffold_oid<br/>\n";
        $r .= "$scaffold_name\t";

        my $taxon_url;
        if ( $d2 eq 'database' ) {
            $taxon_url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        else {
            $taxon_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$taxon_oid";
        }
        $r .= $taxon_display_name . $sd
	    . alink($taxon_url, $taxon_display_name) . "\t";
        $r .= "$seq_length\t";

        if ( $gc_percent ) {
            $gc_percent = sprintf( "%.2f", $gc_percent );            
        }
        $r .= "$gc_percent\t";
        $r .= "$read_depth\t";

        my $scaf_gene_url;
        if ( $d2 eq 'database' && isInt($scaffold_oid) ) {
            $scaf_gene_url = "$main_cgi?section=TaxonDetail"
		. "&page=dbScaffoldGenes" 
                . "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        }
        else {
            $scaf_gene_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaScaffoldGenes&scaffold_oid=$scaffold_oid"
              . "&taxon_oid=$taxon_oid";
        }
        if ( $gene_count ) {
            $r .= $gene_count.$sd.alink($scaf_gene_url, $gene_count)."\t";
        }
        else {
            if ( $d2 eq 'assembled' ) {
                $r .= '0' . $sd . '0' . "\t";                
            }
            else {
                $r .= $gene_count . "\t";
            }
        }

        if ( !$mol_topo ) {
            $mol_topo = "linear";
        }
        $r .= $mol_topo . $sd . $mol_topo . "\t";

        $it->addRow($r);

        $cnt++;
    }

    if ( $cnt == 0 ) {
        print "<p>No scaffolds have been selected.</p>\n";
        return;
    }

    my $name = "_section_ScaffoldCart_addSelectedToGeneCart_noHeader";
    if ($cnt > 10) {
	print submit(
	    -name  => $name,
	    -value => "Add Genes of Selected Scaffolds To Cart",
	    -class => 'lgdefbutton'
	);
	print nbsp(1);
	WebUtil::printButtonFooterInLineWithToggle($tblname);
    if ( $set_name eq $scaf_set_name && $scaf_set_name ) { #own scafset
    	print submit(
    	    -name    => "_section_Workspace_removeAndSaveScaffolds",
    	    -value   => "Remove Selected and Resave",
    	    -class   => "medbutton"
            );
        }
    }

    $it->printOuterTable(1);

    print submit(
        -name  => $name,
        -value => "Add Genes of Selected Scaffolds To Cart",
        -class => 'lgdefbutton'
    );
    print nbsp(1);
    WebUtil::printButtonFooterInLineWithToggle($tblname);
    if ( $set_name eq $scaf_set_name && $scaf_set_name ) { #own scafset
        print submit(
    	-name    => "_section_Workspace_removeAndSaveScaffolds",
    	-value   => "Remove Selected and Resave",
    	-class   => "medbutton"
        );
    }

    WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
}

sub determineAddToSelection {
    my ( $selected_ref, $h_type, $lower, $upper, 
        $gene_count, $seq_length, $gc_percent, $read_depth, $r ) = @_;

    my $item;
    if ( $h_type eq 'gene_count' ) {
        $item = $gene_count;
    } elsif ( $h_type eq 'seq_length' ) {
        $item = $seq_length;
    } elsif ( $h_type eq 'gc_percent' ) {
        $item = $gc_percent;
    } elsif ( $h_type eq 'read_depth' ) {
        $item = $read_depth;
    }

    #determine whether to add data into select array
    if ( blankStr($lower) ) {
        if ( blankStr($upper) ) {
            if ( $item && $h_type && $h_type ne 'read_depth'  ) {
                #skip
            }
            else {
                # no condition
                push( @$selected_ref, $r );                
            }
        }
        elsif ( isNumber($upper) ) {
            if ($item <= $upper) {
                push( @$selected_ref, $r );
            }
        }
    }
    elsif ( isNumber($lower) ) {
        if ( $h_type eq 'read_depth' && $lower == 1 && !$item ) {
            push( @$selected_ref, $r );
            return;
        }

        if ( blankStr($upper) ) {
            if ( $item >= $lower ) {
                push( @$selected_ref, $r );
            }
        }
        elsif ( isNumber($upper) ) {
            if ( $upper == $lower ) {
                if ( $item == $lower ) {
                    push( @$selected_ref, $r );
                }
            }
            else {
                if ( $item >= $lower && $item <= $upper ) {
                    push( @$selected_ref, $r );
                }
            }
        }
    }
}

1;
