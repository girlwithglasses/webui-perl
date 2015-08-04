# CircularMap - Generation of circular and linear maps of chromosomes
#    --km 10/24/2006
#
# $Id: CircularMap.pm 32833 2015-02-19 08:02:25Z jinghuahuang $
############################################################################
package CircularMap;
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use WebUtil;
use WebConfig;
use ImgTermCartStor;
use MetaUtil;
use QueryUtil;
use GraphUtil;

use POSIX qw(ceil floor);
use Math::Trig;
use Bio::Perl;
# use lib '/home/kmavromm/img_ui/';
use GeneCartChrViewer;
my $env = getEnv( );
my $verbose = $env->{ verbose };

my $tmp_pix_dir = $env->{ tmp_dir }; #new used for the directory that the picture will be stored
my $tmp_pix_url = $env->{ tmp_url };  #
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $cgi_dir = $env->{ cgi_dir };
my $base_url = $env->{base_url}; 
my $psu_diagram_dir = $env->{ psu_diagram_dir };
my $circular_bin="circular_diagram.pl";
my $linear_bin="linear_diagram.pl";
my $main_cgi = $env->{ main_cgi };
my $taxon_fna_dir = $env->{ taxon_fna_dir };
my $perl_bin = $env->{ perl_bin };
my $gs_bin = $env->{ gs_bin };
my $page = param( "page" );
my $section = "GeneCartChrViewer";
my $section_cgi = "$main_cgi?section=$section";
my $img_edu  = $env->{img_edu};
my $YUI = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};
my $in_file              = $env->{in_file};
my $mer_data_dir = $env->{ mer_data_dir };

my $contact_oid = WebUtil::getContactOid();
###############################################################################
# code added to show circular diagram of chromosome
# 24 Oct 2006
# 31 Mar 2008. bug fix. When multiple graphs are shown only the first map
#                       was used. Fixed by changing the USEMAP element
#
###############################################################################
# 1. extract the information for the genes from the database
# 2. call external program to create a postscript file with the circular diagram
# 3. convert the postscript to a graph file for the web page
# 4. create the image map of the diagram
###############################################################################

# read the information about the scaffold from the database
# returns the length, accession, taxon_oid and topology of the scaffold
sub get_scaffold_info {
    my ($scaffold, $taxon_oid, $in_file) = @_;

    my $length = 0;
    my $accession;
    my $taxon = $taxon_oid;
    my $topology = "linear";
    my $status = "";
    my $scaff_name = $scaffold;

    if ( $in_file ne 'Yes' && isInt($scaffold) ) {
    	$scaffold=sanitizeInt($scaffold);
    	my $dbh = dbLogin( );

    	my $sql=qq{
    	    select st.seq_length,s.ext_accession,s.taxon,
    	    s.mol_topology,t.seq_status,s.scaffold_name
    	    from scaffold s,scaffold_stats st, taxon t
    	    where s.scaffold_oid=st.scaffold_oid
    	    and s.taxon=t.taxon_oid
    	    and s.scaffold_oid = ?
    	};

    	my $cur = execSql( $dbh, $sql, $verbose, $scaffold );
    	($length,$accession,$taxon,$topology, $status,$scaff_name)
    	    =$cur->fetchrow_array();
    	$cur->finish();
    	#$dbh->disconnect();
    }
    else {
    	# MER-FS
    	my ($len, $gc, $n_genes) = MetaUtil::getScaffoldStats
    	    ($taxon_oid, 'assembled', $scaffold);
    	$length = $len;
    	$accession = $scaffold;
    }

    if (!defined($length) or !defined($taxon)) {
	   webError("Error: Unknown scaffold");
    }
    $length=sanitizeInt($length);
    
    $accession=~/^(\S+)/;
    if (length($1)>0) {
	   $accession=$1;
    } else {
	   webError("Error: Unknown accession");
    }
    $scaff_name=~/^([\S\s\d]+)/;
    if (length($1)>0) {
	   $scaff_name=$1;
    } else {
	   webError("Error: Unknown scaffold name");
    }
    $taxon=sanitizeInt($taxon);
    my $topo=$topology;
    if(lc($topo) eq 'linear' || lc($topo) eq 'circular'){$topology=$topo;}
    elsif($topo eq '' && lc($status) eq "finished") {$topology='circular';}
    elsif($topo eq '' && lc($status) eq "draft") {$topology ='linear';}
    else{webError("Error: Unknown scaffold topology");}

    return ($length,$accession,$taxon,$topology,$scaff_name);
}

sub geneInfo {
    my (@batch_genes) = @_;
    
    my @return_array;
    my @return_scaffolds;

    my @db_batch_gene_data;
    my @meta_batch_gene_data;
    my %meta_genes_h;
    for ( my $j = 0 ; $j < scalar(@batch_genes) ; $j++ ) { 
        if (isInt($batch_genes[$j][0])) {
            push (@db_batch_gene_data, $batch_genes[$j]);
        }
        else {
            push (@meta_batch_gene_data, $batch_genes[$j]);
        	$meta_genes_h{$batch_genes[$j][0]} = 1;
        }
    }

    my %gene_idx;
    if (scalar(@db_batch_gene_data) > 0) {

        my $dbh = dbLogin();
    
        my $max_size=1000;
        my $thousands=ceil(scalar(@db_batch_gene_data)/$max_size);
        for (my $i=0;$i<$thousands;$i++) {
        	my $lower=$i*$max_size;
        	my $upper=($i+1) * $max_size;
        	if ($upper>scalar(@db_batch_gene_data)){
        	    $upper=scalar(@db_batch_gene_data);
        	}
        
        	my @gene1000;
        	my $bindTokens;
        	for (my $j=$lower;$j<$upper;$j++) {
        	    push @gene1000,$db_batch_gene_data[$j][0];
        	    $bindTokens .= "?";
        	    $bindTokens .= ", " if $j < $upper-1;
        	}
        	
        	my $sql=qq{
        	    select g.gene_oid,g.start_coord,g.end_coord,
        	           g.strand,g.locus_tag,g.scaffold,
        	           s.scaffold_name
        	    from gene g, scaffold s
        	    where g.scaffold=s.scaffold_oid
        	    and g.gene_oid in ($bindTokens)
        	};
        	
        	my $cur = execSql( $dbh, $sql, $verbose, @gene1000 );
        	while (my ($gene_oid,$start,$end,$strand,$locus_tag,$scaffold_oid,$scaffold)
        	       =$cur->fetchrow_array()) {
        	    $gene_idx{$gene_oid}=
            		$gene_oid.":".$start.":".$end.":"
            		.$strand.":".$locus_tag.":".$scaffold;
        		push(@return_scaffolds, $scaffold_oid);
        	}
        	$cur->finish();
        }
        #$dbh->disconnect();
    }

    if (scalar(@meta_batch_gene_data) > 0) {
        
        for ( my $k = 0 ; $k < scalar(@meta_batch_gene_data) ; $k++ ) {
            my $ws_gene_id = $meta_batch_gene_data[$k][0];
        	my ($taxon_oid, $data_type, $g_oid) = split(/ /, $ws_gene_id);

            my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, 
                $start, $end, $strand, $scaffold ) =
                MetaUtil::getGeneInfo( $g_oid, $taxon_oid, $data_type );

    	    $gene_idx{$ws_gene_id}=
        		$ws_gene_id.":".$start.":".$end.":"
        		.$strand.":".$locus_tag.":".$scaffold;

            my $ws_scaf_id = "$taxon_oid $data_type $scaffold";
            push (@return_scaffolds, $ws_scaf_id);
        }        
    }    
    

    # change the batch_genes array to incorporate the new information
    for (my $b=0;$b<scalar(@batch_genes);$b++) {
    	my ($gene_oid,$start,$end,$strand,$locus_tag,$scaffold);
    	if (defined($gene_idx{$batch_genes[$b][0]})) {
    	    ($gene_oid,$start,$end,$strand,$locus_tag,$scaffold)
    		=split(":",$gene_idx{$batch_genes[$b][0]});
    	}
    	else {
    	    ($gene_oid,$start,$end,$strand,$locus_tag,$scaffold)
    		=("","","","","","");
    	}
        push @return_array, [$batch_genes[$b][0],$batch_genes[$b][1],
            $batch_genes[$b][2], $start,$end,$strand,
            $locus_tag,$scaffold];

        #print("geneInfo() batch_genes: $batch_genes[$b][0],$batch_genes[$b][1], $batch_genes[$b][2], $start,$end,$strand, $locus_tag,$scaffold<br/>\n");
    }

    return (\@return_scaffolds, \@return_array);
}

# prepares the picture
# creates the files and the command line needed for the external script
# returns the filename with the postscript
# this routine requires
# 1. array with the names of the scaffolds
# 2. batches (i.e. different circles)
# 3. batch genes
sub draw_pix {
    my ( $s, $v1, $v2, $img ) = @_;

    my $taxon_oid = param("taxon_oid");

    if ( !$taxon_oid ) {
        $taxon_oid = 0;
    }

    my @scaffolds = @$s;
    my @batches   = @$v1, my @batch_genes = @$v2;

    print "<h1>Map of chromosome </h1>\n"  if scalar(@scaffolds) == 1;
    print "<h1>Map of chromosomes </h1>\n" if scalar(@scaffolds) > 1;

    if ( $img ne "" && $img_edu ) {
        print "</div>";    # end of ACT stuff
        print "<div id='content'>\n";
    }
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select t.taxon_display_name, 'No'
        from taxon t
        where t.taxon_oid = ?
    };
    if ($in_file) {
        $sql = qq{
            select t.taxon_display_name, t.$in_file
            from taxon t
            where t.taxon_oid = ?
        };
    }
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $in_file ) = $cur->fetchrow_array();
    $cur->finish();

    if ( !$in_file ) {
        $in_file = 'No';
    }

    foreach my $scaffold (@scaffolds) {
        #print "CircularMap::draw_pix() scaffold: $scaffold<br/>\n";

        my ( $t2, $d2, $s2 ) = split( / /, $scaffold );
        if ( $d2 eq 'assembled' ) {
            $taxon_oid = $t2;
            $in_file   = 'Yes';
            $scaffold  = $s2;
        }

        my ( $length, $accession, $taxon, $topology, $scaff_name ) =
          &get_scaffold_info( $scaffold, $taxon_oid, $in_file );
        #print "CircularMap::draw_pix() scaffold info: $scaffold, $length, $accession, $taxon, $topology, $scaff_name<br/>\n";

        my $border_width = 80;
        my $scale_mark   = 100000;

        if ( $length < 300000 ) { $scale_mark = 50000; }
        if ( $length < 100000 ) { $scale_mark = 10000; }

        my $scaffold2 = MetaUtil::sanitizeGeneId3($scaffold);
        my @program_param;
        my $outfile_ps =
          $tmp_pix_dir . "/" . $scaffold2 . "$$.ps";   #file that has the output
        my $outfile_ps_URL =
          $tmp_pix_url . "/" . $scaffold2 . "$$.ps";   #file that has the output
        my $outfile_jpg =
            $tmp_pix_dir . "/"
          . $scaffold2
          . "$$.jpg";    #file that will hold the jpeg image
        my $outfile_jpg_URL = $tmp_pix_url . "/" . $scaffold2 . "$$.jpg";
        my $outfile_tiff    =
            $tmp_pix_dir . "/"
          . $scaffold2
          . "$$.tiff";    #file that will hold the tiff image
        my $outfile_tiff_URL = $tmp_pix_url . "/" . $scaffold2 . "$$.tiff";
        my $start_circle     = 90;

        if ( $topology eq "circular" ) {
            push @program_param,
              "$psu_diagram_dir/bin/$circular_bin -border_width=$border_width";
        }
        else {
            push @program_param,
              "$psu_diagram_dir/bin/$linear_bin -border_width=$border_width";
        }
        push @program_param,
          " -scale_label_separation=$scale_mark -scale_mark_separation=10000";

        # kostas 5 Feb. Change size of image.
        my $page_width  = 600;
        my $page_height = 600;
        $page_height = 400 if $topology eq 'linear';
        push @program_param, " -label_distance=10 -page_width=$page_width -page_height=$page_height";

        my $param;

        #my $gap= " -end_gap=".$length;
        #push @program_param,$gap if $topology eq "linear";
        push @program_param, " -outfile=$outfile_ps";

        # get the nucleotide sequence of the scaffold
        my $dna_outfile = $cgi_tmp_dir . "/genomeCircMap$$.fna";
        my @genes       = ();
        my %cog_function;
        my @rna_genes = ();

        if ( $in_file eq 'Yes' ) {

            # MER-FS
            # load cog functions
            my $sql2 = "select cog_id, functions from cog_functions";
            my $cur2 = execSql( $dbh, $sql2, $verbose );
            for ( my $j = 0 ; $j < 1000000 ; $j++ ) {
                my ( $cog_id, $cog_func ) = $cur2->fetchrow();
                last if !$cog_id;
                $cog_function{$cog_id} = $cog_func;
            }
            $cur2->finish();

            # get scaffold info
            my $dna_wfh = newWriteFileHandle( $dna_outfile, "TaxonSequence" );
            my $seq =
              MetaUtil::getScaffoldFna( $taxon_oid, 'assembled', $scaffold );
            my $line = ">$scaffold";
            print $dna_wfh "$line\n";
            my $seq2 = wrapSeq($seq);
            print $dna_wfh "$seq2\n";
            close $dna_wfh;
            push @program_param, "$dna_outfile";

            # get the genes of this scaffold
            my @genes_on_s =
              MetaUtil::getScaffoldGenes( $taxon_oid, 'assembled', $scaffold );
            for my $s2 (@genes_on_s) {
                my (
                    $gene_oid,          $locus_type,  $locus_tag,
                    $gene_display_name, $start_coord, $end_coord,
                    $strand,            $seq_id,      $source
                  )
                  = split( /\t/, $s2 );
                if ( !$gene_oid ) {
                    next;
                }

                my @gene_cogs =
                  MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, 'assembled' );
                my $function = "";
                if ( scalar(@gene_cogs) > 0 ) {
                    my $cog_id = $gene_cogs[0];
                    $function = $cog_function{$cog_id};
                }
                push @genes,
                  [ $gene_oid, $start_coord, $end_coord, $function, $strand ];

                if ( $locus_type ne 'CDS' ) {
                    push @rna_genes, ("$locus_type,$start_coord,$end_coord");
                }
            }
        }
        else {

            # MER-Oracle
            my $dna_infile = "$taxon_fna_dir/$taxon.fna";
            my $dna_rfh = newReadFileHandle( $dna_infile, "TaxonSequence" );
            my $dna_wfh = newWriteFileHandle( $dna_outfile, "TaxonSequence" );
            #print "CircularMap::draw_pix() dna_infile: $dna_infile, dna_outfile: $dna_outfile<br/>\n";
            &extract_dna( $accession, $taxon, $dna_rfh, $dna_wfh );
            push @program_param, "$dna_outfile";
            close $dna_rfh;
            close $dna_wfh;

            # get the genes of this scaffold
            @genes = &get_genes( $scaffold, $dbh );
        }

        if ( scalar(@genes) == 0 && scalar(@rna_genes) == 0 ) {
            print "<p><font color='red'>This scaffold has no genes.</font>\n";
            next;
        }

        #create file for genes on cogplus and cog minus
        my $cogplus_outfile = $cgi_tmp_dir . "/CogPlusCircMap$$.tab";
        my $cogplus_wfh = newWriteFileHandle( $cogplus_outfile, "COGPlus" );
        &get_cog_plus( \@genes, $cogplus_wfh );
        push @program_param, "$cogplus_outfile $start_circle 10";
        $start_circle -= 10;

        my $cogminus_outfile = $cgi_tmp_dir . "/CogMinusCircMap$$.tab";
        my $cogminus_wfh = newWriteFileHandle( $cogminus_outfile, "COGMinus" );
        &get_cog_minus( \@genes, $cogminus_wfh );
        push @program_param, "$cogminus_outfile $start_circle 10";
        $start_circle -= 10;

        # create file for RNAs
        my $rna_outfile = $cgi_tmp_dir . "/table3CircMap$$.tab";
        my $rna_wfh = newWriteFileHandle( $rna_outfile, "RNAgenes" );
        if ( $in_file eq 'Yes' ) {

            # MER-FS
            for my $rna2 (@rna_genes) {
                my ( $type, $start, $end ) = split( /\,/, $rna2 );
                my $color;
                if    ( $type eq 'tRNA' ) { $color = "0    1   0"; }
                elsif ( $type eq 'rRNA' ) { $color = "1    0   0"; }
                else { $color = "1    1   1"; }
                print $rna_wfh "$start  $end    100 $color\n";
            }
        }
        else {
            &get_rna_genes( $scaffold, $rna_wfh, $dbh );
        }
        push @program_param, "$rna_outfile $start_circle 10 ";
        $start_circle -= 10;

        # if there are batches create the files for each batch
        if ( (@batches) && scalar(@batches) > 0 ) {
            $start_circle += 5;
            for ( my $b = 0 ; $b < scalar(@batches) ; $b++ ) {
                my $batch_outfile =
                  $cgi_tmp_dir . "/Batch" . $b . "CircMap$$.tab";

                #print "draw_pix() OUTFILE:  $batch_outfile<br/>";
                my $wfh_batch =
                  newWriteFileHandle( $batch_outfile, "Batchout" );
                &create_batch( \@genes, \@batch_genes, $batches[$b], $wfh_batch,
                    $b );
                my $command = $batch_outfile . " " . $start_circle . " 20";

                #print "draw_pix() COMMAND: $command<br/>";
                push @program_param, $command;
                close $wfh_batch;
                $start_circle -= 5;
            }
        }

        # parameter for GC% and GCdev
        push @program_param, "-gc $start_circle 10 10000 400";
        $start_circle -= 15;
        push @program_param, "-gcdev $start_circle 10 10000 500";

        # add gc and gcdev graphs

        my $cmd = join( " ", @program_param );
        #print "draw_pix() cmd: $cmd<br/>\n";
        $ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
        #print "outfile= $outfile_jpg<br>\n";
        #print "url=$outfile_jpg_URL<br>\n";
        #runCmd($cmd);
        # --es 11/17/2006 Need to include path for library.

        #print "draw_pix() runCmd: $perl_bin -I$psu_diagram_dir/lib $cmd<br/>\n";
        runCmd("$perl_bin -I$psu_diagram_dir/lib $cmd");
        #print "draw_pix() runCmd done<br/>\n";
        close $rna_wfh;
        close $cogminus_wfh;
        close $cogplus_wfh;

        # convert the image to JPG
        &convert_image( $outfile_ps, $outfile_jpg, $page_width, $page_height );
        &convert_image_tiff( $outfile_ps, $outfile_tiff, $page_width,
            $page_height );

        # show the image on the web page
        my $img_size =
          &show_image( $length, $topology, $scaffold, $outfile_jpg_URL,
            $page_width, $page_height );

        # create the image map
        # img_edu
        &make_map(
            $length,      $topology,     $page_width,
            $page_height, $border_width, $scaffold,
            $img,         $in_file,      $taxon_oid
        );

        #show link to file
        #&link_to_ps($outfile_ps_URL,$scaff_name);
        &link_to_downloads( $outfile_ps_URL, $outfile_tiff_URL, $scaff_name );
    }

    # write the legend
    # img_edu
    if ( $img eq "" ) {
        &print_legend( $dbh, @batches );
    }
    #$dbh->disconnect();

    print "<script src='$base_url/overlib.js'></script>\n";
    printStatusLine( "Loaded.", 2 );
}


# converts the image from postscript to jpg
sub convert_image {
    my ($ps,$jpg,$page_width,$page_height)=@_;
    # kostas 5 Feb. Change size of image.
    my $cmd="$gs_bin -q -sDEVICE=jpeg -sOutputFile=$jpg " . 
	"-dNOPAUSE -dBATCH -dJPEGQ=100 -dFIXEDMEDIA "  . 
	"-g".$page_width."x".$page_height." -f $ps";
    runCmd($cmd);
}

sub convert_image_tiff {
    my ($ps,$outFile,$page_width,$page_height)=@_;
    my $cmd="$gs_bin -q -sDEVICE=tiff24nc -sOutputFile=$outFile " . 
	"-dNOPAUSE -dBATCH "  . 
	"-g".$page_width."x".$page_height .
	" -f $ps";
    runCmd($cmd);
}

######################################################################
# extract information from the database or files
######################################################################
sub extract_dna {
    my $accession=$_[0];	
    my $taxon=$_[1];
    my $rfh=$_[2];
    my $wfh=$_[3];

    my $write;
    while (my $line=$rfh->getline()) {
    	chomp $line;
    	if ($line=~/^>/) {
            #if ($line=~/\s*$accession\s*/) {
    	    if ($line=~/^>$accession\s/) {
        		$write=1;
    	    }
    	    else {
        		$write=0;
    	    }
    	}
    	if ($write==1) {
    	    print $wfh "$line\n";
    	}
    }
}

sub get_rna_genes {
    my ($scaffold, $wfh, $dbh) = @_;
    print $wfh "\# RNA genes on both strands\n";

    my $sql=qq{
	select g.gene_oid,g.start_coord,g.end_coord,g.locus_type
	from gene g
	where g.scaffold = ?
	and g.locus_type <> ?
	order by g.start_coord
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold, 'CDS' );

    while(my($gene,$start,$end,$type)=$cur->fetchrow_array()) {
	my $color;
	if($type eq 'tRNA')   {$color="0	1	0";}
	elsif($type eq 'rRNA'){$color="1	0	0";}
	else                  {$color="1	1	1";}
	print $wfh "$start	$end	100	$color\n";
    }
    $cur->finish();
}

sub get_genes {
    my ($scaffold, $dbh)  = @_;

    my @gene_data;
#    my $sql_old=qq{
#    	select g.gene_oid,g.start_coord,g.end_coord,cf.functions,g.strand
#    	from gene g, gene_cog_groups gcg,cog_functions cf
#    	where g.gene_oid=gcg.gene_oid(+)
#    	and gcg.cog=cf.cog_id(+)
#    	and (gcg.rank_order =1  OR gcg.rank_order is null)
#    	and g.scaffold = ?
#    	and g.locus_type = ?
#    	order by g.start_coord
#    };
    my $sql=qq{
    	select g.gene_oid,g.start_coord,g.end_coord,
    	   cf.functions,g.strand
    	from gene g
    	left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
    	left join cog_functions cf on gcg.cog = cf.cog_id
    	where (gcg.rank_order =1  OR gcg.rank_order is null)
    	and g.scaffold = ?
    	and g.locus_type = ?
    	order by g.start_coord
    };
    #print "CircularMap::get_genes() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold, 'CDS' );

    while (my($gene,$start,$end,$function,$strand)=$cur->fetchrow_array()) {
    	if (!defined($function)){$function="NA";}
    	push @gene_data,[$gene,$start,$end,$function,$strand];
    }
    $cur->finish();
    return @gene_data;
}

sub get_cog_minus {
    my ($v1,$wfh)=@_;
    my @genes=@$v1;

    print $wfh "\# Cog asignment on the minus strand\n";
    for (my $i=0;$i<scalar(@genes);$i++) {
	my ($gene,$start,$end,$function,$strand)
	    =($genes[$i][0],$genes[$i][1],$genes[$i][2],$genes[$i][3],$genes[$i][4]);
	if ($strand ne '-') {
	    next;
	}

	my $color;
	if(!defined($function)){$color="1	1	1";}
	elsif   ($function eq 'A'){$color=".51	.55	.91";} #82 d8 e7
	elsif($function eq 'B'){$color=".74	.94	.56";} #bc ef 8e
	elsif($function eq 'C'){$color=".43	.62	.79";} #6e 9d c9
	elsif($function eq 'D'){$color=".66	.68	.84";} #a9 ae d5
	elsif($function eq 'E'){$color=".77	.42	.48";} #c4 6c 7a
	elsif($function eq 'F'){$color=".48	.75	.80";} #7a c0 cb
	elsif($function eq 'G'){$color=".88	.73	.71";} #e0 b9 b6
	elsif($function eq 'H'){$color=".46	.57	.57";} #75 92 92
	elsif($function eq 'I'){$color=".47	.44	.97";} #78 71 f9
	elsif($function eq 'J'){$color=".51	.40	.87";} #82 67 df
	elsif($function eq 'K'){$color=".60	.75	.45";} #99 c0 73
	elsif($function eq 'L'){$color=".96	.95	.68";} #f6 f2 ad
	elsif($function eq 'M'){$color=".69	.53	.44";} #af 88 6f
	elsif($function eq 'N'){$color=".93	.79	.78";} #ec ca c8
	elsif($function eq 'O'){$color=".58	.82	.41";} #94 d0 68
	elsif($function eq 'P'){$color=".91	.57	.42";} #e7 92 6c
	elsif($function eq 'Q'){$color=".59	1.0	.46";} #97 fe 75
	elsif($function eq 'R'){$color=".69	.46	.74";} #b1 75 bd
	elsif($function eq 'S'){$color=".47	.59	.75";} #79 97 be
	elsif($function eq 'T'){$color=".56	.50	.51";} #90 7f 82
	elsif($function eq 'U'){$color=".68	.78	.99";} #ad c6 fc
	elsif($function eq 'V'){$color=".67	.85	.90";} #ac da e6
	elsif($function eq 'W'){$color=".79	.55	.99";} #c9 8b fc
	elsif($function eq 'X'){$color="0.4	0.6	1";} #
	elsif($function eq 'Y'){$color=".96	.46	.45";} #f5 76 72
	elsif($function eq 'Z'){$color=".60	.96	.62";} #99 f4 9e
	print $wfh "$start	$end	100	$color\n";
    }	
}

sub get_cog_plus {
    my ($v1,$wfh)=@_;
    my @genes=@$v1;

    print $wfh "\# Cog asignment on the plus strand\n";
    for (my $i=0;$i<scalar(@genes);$i++) {
    	my ($gene,$start,$end,$function,$strand)
    	    =($genes[$i][0],$genes[$i][1],$genes[$i][2],$genes[$i][3],$genes[$i][4]);
    	if ($strand ne '+') {
    	    next;
    	}

    	my $color;
    	if (!defined($function)){$color="1	1	1";}
    	elsif   ($function eq 'A'){$color=".51	.55	.91";} #82 d8 e7
    	elsif($function eq 'B'){$color=".74	.94	.56";} #bc ef 8e
    	elsif($function eq 'C'){$color=".43	.62	.79";} #6e 9d c9
    	elsif($function eq 'D'){$color=".66	.68	.84";} #a9 ae d5
    	elsif($function eq 'E'){$color=".77	.42	.48";} #c4 6c 7a
    	elsif($function eq 'F'){$color=".48	.75	.80";} #7a c0 cb
    	elsif($function eq 'G'){$color=".88	.73	.71";} #e0 b9 b6
    	elsif($function eq 'H'){$color=".46	.57	.57";} #75 92 92
    	elsif($function eq 'I'){$color=".47	.44	.97";} #78 71 f9
    	elsif($function eq 'J'){$color=".51	.40	.87";} #82 67 df
    	elsif($function eq 'K'){$color=".60	.75	.45";} #99 c0 73
    	elsif($function eq 'L'){$color=".96	.95	.68";} #f6 f2 ad
    	elsif($function eq 'M'){$color=".69	.53	.44";} #af 88 6f
    	elsif($function eq 'N'){$color=".93	.79	.78";} #ec ca c8
    	elsif($function eq 'O'){$color=".58	.82	.41";} #94 d0 68
    	elsif($function eq 'P'){$color=".91	.57	.42";} #e7 92 6c
    	elsif($function eq 'Q'){$color=".59	1.0	.46";} #97 fe 75
    	elsif($function eq 'R'){$color=".69	.46	.74";} #b1 75 bd
    	elsif($function eq 'S'){$color=".47	.59	.75";} #79 97 be
    	elsif($function eq 'T'){$color=".56	.50	.51";} #90 7f 82
    	elsif($function eq 'U'){$color=".68	.78	.99";} #ad c6 fc
    	elsif($function eq 'V'){$color=".67	.85	.90";} #ac da e6
    	elsif($function eq 'W'){$color=".79	.55	.99";} #c9 8b fc
    	elsif($function eq 'X'){$color="0.4	0.6	1";} #
    	elsif($function eq 'Y'){$color=".96	.46	.45";} #f5 76 72
    	elsif($function eq 'Z'){$color=".60	.96	.62";} #99 f4 9e
    	print $wfh "$start	$end	100	$color\n";

    	#if ($function eq 'S'){
    	#    print "get_cog_plus() gene oid: $gene, start: $start, end: $end, function: $function, strand: $strand<br/>\n";
    	#}
    }	
}

sub create_batch {
    my ($v1,$v2,$batch,$wfh,$batch_idx)=@_;
    my @genes=@$v1;
    my @batch_genes=@$v2;
    my %batch_idx;

    for (my $b=0;$b<scalar(@batch_genes);$b++) {
	$batch_idx{$batch_genes[$b][0]}=1 if $batch_genes[$b][1] == $batch;
	# create a hash with the gene_oids 
	# of the genes that belong to this batch
    }
    for (my $g=0;$g<scalar(@genes);$g++) {
	if(defined($batch_idx{$genes[$g][0]})) {
	    my $color='.50	.50	.50'; # generic grey color
	    $color='.90	.0	.0'   if $batch_idx==0; # red color
	    $color='.0	.70	.0'   if $batch_idx==1;	# green color
	    $color='.0	.0	.70'  if $batch_idx==2;	# blue color
	    $color='.70	.0	.70'  if $batch_idx==3;	# magenta color
	    $color='.0	.70	.70'  if $batch_idx==4;	# light blue color
	    $color='.70	.70	.0'   if $batch_idx==5;	# ocre color
	    $color='.90	.50	.0'   if $batch_idx==6;	# orange color
	    $color='.90	.90	.0'   if $batch_idx==7;	# yellow color
	    
	    my $start=$genes[$g][1];
	    my $end=$genes[$g][2];
	    print $wfh "$start	$end	100	$color\n";
	}
    }
}

###############################################################################
#            functions that create the web page
###############################################################################

sub show_image {
    my ($length,$topology,$scaffold,$pix_file,$page_width,$page_height)=@_;
    print "<img src=\"$pix_file\" alt=\"\" "
	. "width=$page_width height=$page_height "
	. "USEMAP=\"#genome_map_$scaffold\">\n";
}

sub make_map {
    my ($length,$topology,$page_width,$page_height,
	$border_width,$scaffold,$img,$in_file,$taxon_oid)=@_;

    # img_edu
    my $myimg = "";
    if ($img ne "") {
	$myimg = "&img=$img";
    }
    my $URL="$main_cgi?section=ScaffoldGraph"
	. "&page=scaffoldGraph&scaffold_oid=$scaffold"
	. "&seq_length=$length$myimg";

    if ( $in_file eq 'Yes' ) {
	# MER-FS
        $URL = "$main_cgi?section=MetaScaffoldGraph" .
            "&page=metaScaffoldGraph&scaffold_oid=$scaffold" .
            "&taxon_oid=$taxon_oid&seq_length=$length";
    }

    print "<map name=\"genome_map_$scaffold\">\n";

    # CIRCULAR MAP    
    # calculate the map elements (triangles every 50000 nucleotides	
    if ($topology eq 'circular') {
	my $img_size=$page_width;
	my $triangles=int($length/50000) +1;
	for (my $step=0;$step<$triangles;$step++) {
	    # print a polygon
	    my @points; #holds the points of the polygon
	    my $radius=$img_size/2;
	    my $center=int($img_size/2);
	    push @points,[$center,$center]; # the center of the image
	    
	    my $step1=$step*50000 + 1;
	    my $step2=($step+1)*50000; 
	    if ($step2> $length && $topology eq 'circular'){$step2=$length;}
	    if ($step2> $length/2 && $topology eq 'linear'){$step2=int($length/2);}
	    my $angleA= (2* pi) * $step1/$length;  
	    # angle for the first coordinate of this element in radians
	    my $angleB= (2* pi) * $step2/$length; 
	    # angle for the last coordinate of this element in radians
	    
	    if ($topology eq "linear") {$angleA += (pi/2);$angleB += (pi/2);}
	    for (my $a=$angleA;$a<$angleB;$a+=pi/20) {
		my $cos=cos($a);
		my $sin=sin($a);
		push @points,[$center+int($sin*$radius),$center-int($cos*$radius)];
	    } # add the points to create the arc
	    my $cos=cos($angleB);
	    my $sin=sin($angleB);
	    push @points,[$center+int($sin*$radius),$center-int($cos*$radius)];
	    
	    print "<area shape =poly coords=\"";
	    print "$points[0][0],$points[0][1]";
	    for (my $p=1;$p<scalar(@points);$p++) {
		print ",$points[$p][0],$points[$p][1]";
	    }
	    my $s = "onMouseOver=\"return overlib('coordinates $step1-$step2')\" ";
	    $s .= "onMouseOut=\"return nd()\" ";

	    print "\" alt=\"$step1 - $step2\" $s"
		. "href=\"$URL&start_coord=$step1&end_coord=$step2\">\n";
	}
    }
    # LINEAR MAP
    else {
	my $hor_size=($page_width-2 * $border_width)/ $length * 50000;
	# the size in pixels of the 50000nt regions 	
	my $rects=int($length/50000); #number of rectangles in the picture
	my $offset=($page_width - 2 * $border_width) / $length * 50000; 
	# width of each rectangle in pixels
	for (my $step=0; $step<=$rects;$step++) {
	    my $x1=$border_width+ $step * $offset;
	    my $x2=$border_width + ($step + 1) * $offset; 
	    if ($x2> $page_width-$border_width){$x2=$page_width-$border_width;}
	    my $step1 = $step * 50000 +1;
	    my $step2= ($step+1) * 50000;
	    if ($step2> $length){$step2=$length;}
	    print "<area shape = rect coords=\" $x1 , 0 , $x2 , $page_height\"";
	    print "\" alt=\" $step1 - $step2\" href=\"$URL&start_coord=$step1&end_coord=$step2\">\n";
	}
    }	
    print "</map>\n";
}

sub print_legend {
    my ($dbh, @batches)=@_;
    print "<h2>Legend</h2>";

    print "<p>";
    print "From outside to the center:<br>\n";
    print "Genes on forward strand (color by COG categories)<br>\n";
    print "Genes on reverse strand (color by COG categories)<br>\n";
    print "RNA genes (tRNAs green, rRNAs red, other RNAs black)<br>\n";
    for (my $i=0;$i<scalar(@batches);$i++) {
	print "User selection from gene cart. Genes in band $batches[$i]<br>\n";
    }
    print "GC content<br>\n";
    print "GC skew <br>\n";
    print "</p>";

    print <<HEAD;
        <h2>COG Coloring Selection</h2>
	<p>
	Color code of function category for top COG hit is shown below.<br/>
	</p>
HEAD
    if ($yui_tables) {
	print <<YUI;

       <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

	<style type="text/css">
	    .yui-skin-sam .yui-dt th .yui-dt-liner {
		white-space:normal;
	    }
	</style>

	<div class='yui-dt'>
	<table style='font-size:12px'>
	<th>
	<div class='yui-dt-liner'>
	<span>COG Code</span>
	</div>
	</th>
	<th>
	<div class='yui-dt-liner'>
	<span>COG Function Definition</span>
	</div>
	</th>
YUI
    } else {
	print <<IMG;
	<table class='img'  border=1>
	<th class='img' >COG Code</th>
	<th class='img' >COG Function Definition</th>
IMG
    }

    my @color_array = GraphUtil::loadColorArrayFile( $env->{small_color_array_file} );
    my %cogFunction = QueryUtil::getCogFunction($dbh);
    my @keys        = sort( keys(%cogFunction) );

    my $idx = 0;
    my $classStr;

    for my $COGCode (@keys) {
        last if !$COGCode;

	if ($yui_tables) {
	    $classStr = !$idx ? "yui-dt-first ":"";
	    $classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
	} else {
	    $classStr = "img";
	}

        my ($COGDefinition, $count) = split( /\t/, $cogFunction{$COGCode} );
        my $color = $color_array[$count];
        my ( $r, $g, $b ) = split( /,/, $color );
        my $COGcolor = sprintf( "#%02x%02x%02x", $r, $g, $b );

        print "<tr class='$classStr'>\n";
        print "<td class='$classStr'\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print qq{ <span style='border-left:1em solid $COGcolor;padding-left:0.5em; margin-left:0.5em' />\n };
	print "[$COGCode]";
	print "</div>\n" if $yui_tables;
        print "</td>\n";

        print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print escHtml($COGDefinition);
	print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";

	$idx++;
    }

    #Not Assigned
    print "<tr class='$classStr'>\n";
    print "<td class='$classStr'\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{ <span style='border-left:1em solid #555555;padding-left:0.5em; margin-left:0.5em' />\n };
    print "[NA]";
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    print "<td class='$classStr'>\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Not Assigned";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "<p>\n";
}

sub link_to_ps {
    my ($outfile_ps_URL,$scaff_name)=@_;
    print "<p><b>Map of $scaff_name</b><br/>\n";
    print "Download <a href=\"$outfile_ps_URL\" onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link Map of $scaff_name']);\" >publication quality image </a> of the above diagram</p>";
}

sub link_to_downloads {
    my( $outfile_ps_URL, $outfile_tiff_URL, $scaff_name ) = @_;
    print "<p>";
    print "<b>Map of $scaff_name</b><br/>\n";
    print "Download publication quality ";
    print "<a href=\"$outfile_ps_URL\" onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link PS Map of $scaff_name']);\" >Postscript file</a> or \n";
    print "<a href=\"$outfile_tiff_URL\" onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link TIFF Map of $scaff_name']);\" >TIFF file</a>.<br/>\n";
    print "</p>";
}

sub unique {
    my ($array,$size)=@_;
    my @a1=@$array;
    my $un_sep="UN~:~SEP";
    my %check=();
    my @uniq=();

    if ($size >1) {
    	for (my $i=0;$i<scalar(@a1);$i++) {
    	    my $string;
    	    for (my $j=0;$j<$size;$j++) {
    	        $string.=$a1[$i][$j].$un_sep;
    	    }
    	    unless($check{$string}) {
        		my @temp_array=split($un_sep,$string);
        		push @uniq,[@temp_array];
        		$check{$string}=1;
    	    }
    	}
    }
    elsif ($size==1) {
    	foreach my $e(@a1) {
    	    if (defined($e)) {
        		unless(defined($check{$e})) {
        		    push @uniq,$e;
        		    $check{$e}=1;
        		}
    	    }
    	}
    }
    return @uniq;
}

1;
