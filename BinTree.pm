############################################################################
#
# Builds Bin tree:
# Bin Method
#	+ Bin
#		+ Family
#			+ Genus Species
#
# $Id: BinTree.pm 31086 2014-06-03 19:14:00Z klchu $
#
package BinTree;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MetagJavaScript;
use MetagenomeGraph;
use TreeHTML;
use QueryUtil;


$| = 1;

my $env      = getEnv();
my $cgi_dir  = $env->{cgi_dir};
my $cgi_url  = $env->{cgi_url};
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};

#
# configuration - location of yahoo's api
#
my $YUI = $env->{yui_dir_28};

my $unknown = "Unknown";

sub dispatch {

	my $page = param("page");

	if ( $page eq "treebin" ) {

		# yui api
		# lets try loading only one level of the tree at a time
		my $dbh = dbLogin();

		my $taxon_oid = param("taxon_oid");
		$taxon_oid = "2001000000" if ( $taxon_oid eq "" );

		# build tree page
		TreeHTML::printYuiTreePageStart();
		yuiPrintTreeFolderDynamic( $dbh, $taxon_oid );
		my $taxonName = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

		# turn on tree label tool tip
		TreeHTML::printYuiTreePageEnd( "", "", "", 1, $taxonName );

		#$dbh->disconnect();

	} elsif ( $page eq "xmlbinmethod" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlBinMethod($dbh);

		#$dbh->disconnect();

	} elsif ( $page eq "xmlbin" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlBin($dbh);

		#$dbh->disconnect();

	} elsif ( $page eq "xmlbinfamily" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlBinFamily($dbh);

		#$dbh->disconnect();

	} elsif ( $page eq "xmlbinspecies" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlBinSpecies($dbh);

		#$dbh->disconnect();

	}

}

#
# Created XML data objects for bin method data
#
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
#	<response>
#	<label name="binmethod name">
#   	<id>id here</id>
#		<href>javascript:remoteSend(%22inner.cgi?xxxx%22)</href>
#		<url>xml.cgi?section=TestTree%26xxxxx</url>
#	</label>
#   </response>
#
# param $dbh - database handler
#
sub getXmlBinMethod {
	my ($dbh) = @_;

	my $taxon_oid = param("taxon_oid");

	# get phylum names
	my $aref = getBinMethodNames( $dbh, $taxon_oid );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $rec (@$aref) {
		my ( $method_oid, $method ) = split( /\t/, $rec );

		# either use %22 for " or use '
		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=binmethodstats"
		  . "&method_oid=$method_oid"
		  . "&taxon_oid=$taxon_oid')";

		$url = escapeHTML($url);

		my $url2 = "xml.cgi?section=BinTree";
		$url2 .= "&page=xmlbin";
		$url2 .= "&taxon_oid=$taxon_oid";
		$url2 .= "&method_oid=$method_oid";

		$url2 = escapeHTML($url2);

		print "<label name=\"" . escapeHTML($method) . "\">\n";
		print "<id>$method_oid</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# database query to get bin methods
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
# return list of names
sub getBinMethodNames {
	my ( $dbh, $taxon_oid ) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
	my $sql = qq{
        select distinct bm.bin_method_oid, bm.method_name
        from taxon tx, env_sample es, bin b, bin_method bm
        where tx.env_sample = es.sample_oid
        and b.env_sample_gold = es.sample_oid
        and tx.taxon_oid = ?
        and b.bin_method = bm.bin_method_oid
        and b.is_default = ?
        $rclause
        $imgClause
        order by 2
   };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'Yes' );

	my @names;
	for ( ; ; ) {
		my ( $method_oid, $method ) = $cur->fetchrow();
		last if !$method_oid;

		push( @names, "$method_oid\t$method" );
	}
	$cur->finish();

	return \@names;
}

#
# Created XML data objects for bin data
#
# param $dbh - database handler
# param others from URL
#
sub getXmlBin {
	my ($dbh) = @_;

	my $taxon_oid  = param("taxon_oid");
	my $method_oid = param("method_oid");

	my $aref = getBinNames( $dbh, $taxon_oid, $method_oid );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $rec (@$aref) {

		my ( $oid, $name ) = split( /\t/, $rec );

		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=binfamilystats"
		  . "&method_oid=$method_oid"
		  . "&bin_oid=$oid"
		  . "&taxon_oid=$taxon_oid')";

		$url = escapeHTML($url);

		my $url2 = "xml.cgi?section=BinTree";
		$url2 .= "&page=xmlbinfamily";
		$url2 .= "&taxon_oid=$taxon_oid";
		$url2 .= "&method_oid=$method_oid";
		$url2 .= "&bin_oid=$oid";

		$url2 = escapeHTML($url2);

		print "<label name=\"" . escapeHTML($name) . "\">\n";
		print "<id>$oid</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# database query to get bin names
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
# return list of names
sub getBinNames {
	my ( $dbh, $taxon_oid,, $method_oid ) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
	my $sql = qq{
        select b.bin_oid, b.display_name
        from taxon tx, env_sample_gold es, bin b, bin_method bm
        where tx.env_sample = es.sample_oid
        and b.env_sample = es.sample_oid
        and tx.taxon_oid = ?
        and b.bin_method = bm.bin_method_oid
        and b.is_default = ?
        and bm.bin_method_oid = ?
        $rclause
        $imgClause
        order by 2
    };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'Yes', $method_oid);

	my @names;
	for ( ; ; ) {
		my ( $bin_oid, $name ) = $cur->fetchrow();
		last if !$bin_oid;

		push( @names, "$bin_oid\t$name" );
	}
	$cur->finish();

	return \@names;
}

#
# Created XML data objects for bin family data
#
# param $dbh - database handler
# param other from URL
#
sub getXmlBinFamily {
	my ($dbh) = @_;

	my $taxon_oid  = param("taxon_oid");
	my $method_oid = param("method_oid");
	my $bin_oid    = param("bin_oid");

	# get phylum names
	my $aref = getBinFamilyNames( $dbh, $taxon_oid, $method_oid, $bin_oid );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $name (@$aref) {

		# form to plot scatter plot ?
		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=binscatter"
		  . "&method_oid=$method_oid"
		  . "&bin_oid=$bin_oid"
		  . "&family=$name"
		  . "&taxon_oid=$taxon_oid')";

		$url = escapeHTML($url);

		# species chlidren
		my $url2 = "xml.cgi?section=BinTree";
		$url2 .= "&page=xmlbinspecies";
		$url2 .= "&taxon_oid=$taxon_oid";
		$url2 .= "&method_oid=$method_oid";
		$url2 .= "&bin_oid=$bin_oid";
		$url2 .= "&family=$name";

		$url2 = escapeHTML($url2);

		print "<label name=\"" . escapeHTML($name) . "\">\n";
		print "<id>$bin_oid" . "_" . escapeHTML($name) . "</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# database query to get bin families
#
# param $dbh - database handler
# param taxon_oid - metag taxon id
# param method_oid - bin method oid
# param bin_oid - bin oid
# return list of names
sub getBinFamilyNames {
	my ( $dbh, $taxon_oid, $method_oid, $bin_oid ) = @_;
    require MetagenomeHits;
	my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

	my $sql = qq{
        select distinct tx.family
        from bin b, bin_method bm, bin_scaffolds bs, gene g,
        dt_phylum_dist_genes dt, gene g2, taxon tx
        where b.env_sample = ?
        and b.bin_method = bm.bin_method_oid
        and b.is_default = ?
        and bm.bin_method_oid = ?
        and b.bin_oid = ?
        and b.bin_oid = bs.bin_oid
        and g.scaffold = bs.scaffold
        and g.taxon = ?
        and dt.taxon_oid = ?
        and g.taxon = dt.taxon_oid
        and dt.gene_oid = g.gene_oid
        and dt.homolog = g2.gene_oid
        and dt.homolog_taxon = tx.taxon_oid
        and g2.taxon = tx.taxon_oid
        $rclause
        $imgClause
        order by 1
    };
	my $cur = execSql( $dbh, $sql, $verbose, $env_sample, 'Yes', $method_oid, $bin_oid, $taxon_oid, $taxon_oid );

	my @names;
	for ( ; ; ) {
		my ($name) = $cur->fetchrow();
		last if !$name;

		push( @names, "$name" );
	}
	$cur->finish();

	return \@names;
}

#
# Created XML data objects for bin species data
#
# param $dbh - database handler
# param others from URL
sub getXmlBinSpecies {
	my ($dbh) = @_;

	my $taxon_oid  = param("taxon_oid");
	my $method_oid = param("method_oid");
	my $bin_oid    = param("bin_oid");
	my $family     = param("family");

	# get phylum names
	my $aref =
	  getBinSpecies( $dbh, $taxon_oid, $method_oid, $bin_oid, $family );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $name (@$aref) {

		my ( $genus, $species ) = split( /\t/, $name );

		# form to plot scatter plot
		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=binspecies"
		  . "&method_oid=$method_oid"
		  . "&bin_oid=$bin_oid"
		  . "&family=$family"
		  . "&genus=$genus";
		$url .= "&species=$species" if ( $species ne "" );
		$url .= "&taxon_oid=$taxon_oid')";

		$url = escapeHTML($url);

		# no chlidren
		my $url2 = "mynull";

		print "<label name=\"" . escapeHTML("$genus $species") . "\">\n";
		print "<id>" . escapeHTML("$genus $species") . "</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# database query to get bin families
#
# param $dbh - database handler
# param taxon_oid - metag taxon id
# param method_oid - bin method oid
# param bin_oid - bin oid
# param family - ref gene (homolog) family name
# return list of names tab delimited genus species
sub getBinSpecies {
	my ( $dbh, $taxon_oid, $method_oid, $bin_oid, $family ) = @_;

	my $env_sample = QueryUtil::getTaxonEnvSample( $dbh, $taxon_oid );

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

	my $sql = qq{
        select distinct tx.genus, tx.species
        from bin b, bin_scaffolds bs, gene g,
        dt_phylum_dist_genes dt, gene g2, taxon tx
        where b.env_sample = ?
        and b.bin_method = ?
        and b.is_default = ?
        and b.bin_oid = ?
        and b.bin_oid = bs.bin_oid
        and g.scaffold = bs.scaffold
        and g.taxon = ?
        and dt.taxon_oid = ?
        and g.taxon = dt.taxon_oid
        and dt.gene_oid = g.gene_oid
        and dt.homolog = g2.gene_oid
        and dt.homolog_taxon = tx.taxon_oid
        and g2.taxon = tx.taxon_oid
        and tx.family = ?
        $rclause
        $imgClause
        order by 1, 2
    };
	my $cur = execSql( $dbh, $sql, $verbose, $env_sample, $method_oid, 'Yes', $bin_oid, $taxon_oid, $taxon_oid, $family );

	my @names;
	for ( ; ; ) {
		my ( $genus, $species ) = $cur->fetchrow();
		last if !$genus;

		push( @names, "$genus\t$species" );
	}
	$cur->finish();

	return \@names;
}

#
# create custon section to build javascript tree
#
# param dbh - database handler
# param taxon_oid - metag taxon oid
#
sub yuiPrintTreeFolderDynamic {
	my ( $dbh, $taxon_oid ) = @_;

	print "<script src = \"$base_url/xml.js\" ></script>\n";

	# tool tips
#	print <<EOF;
#<!-- CSS -->
#<link rel="stylesheet" type="text/css" href="$YUI/build/container/assets/container.css">
#
#<!-- Dependencies -->
#<script type="text/javascript" src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
#
#<!-- Source file -->
#<script type="text/javascript" src="$YUI/build/container/container-min.js"></script>
#EOF

	print "<script language='JavaScript' type='text/javascript'>\n";
	print <<EOF;

function initializeDocument() {
   tree = new YAHOO.widget.TreeView("tree");
   tree.setDynamicLoad(loadDataForNode);
   var root = tree.getRoot();

EOF

	my $url2 = "xml.cgi?section=BinTree&page=xmlbinmethod&taxon_oid=$taxon_oid";

	my $url =
	    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
	  . "&page=binstats"
	  . "&taxon_oid=$taxon_oid')";

	# root node
	print "var myobj = { label: \"Bin Method\", id:\"$taxon_oid\", "
	  . "href:\"$url\", url:\"$url2\"};\n";
	print "var rootNode = new YAHOO.widget.TextNode(myobj, root, false);\n";

	# end function
	print <<EOF;


	//tree.expand(rootNode);
	rootNode.expand();
	tree.draw();

	//var id = rootNode.getElId();
	var id = 'tooltipid';
	var tt = new YAHOO.widget.Tooltip("tt", { context:id,
		text:"Bin Method<br>+- Bin<br>+-- Family<br>+--- Genus Species" } );
}


</script>
EOF
}

1;
