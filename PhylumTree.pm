############################################################################
#
# Builds Phylum tree:
# Domain
#	+ phylum or ir class
#		+ Family
#			+ Genus Species
#
#
# $Id: PhylumTree.pm 31086 2014-06-03 19:14:00Z klchu $
#
package PhylumTree;


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
my $unknown  = "Unknown";
my $nvl      = getNvl( );

#
# configuration - location of yahoo's api
#
my $YUI = $env->{yui_dir_28};

sub dispatch {

	my $page = param("page");

	if ( $page eq "tree" ) {

		# yui api
		# lets try loading only one level of the tree at a time
		my $dbh = dbLogin();

		my $taxon_oid = param("taxon_oid");
		$taxon_oid = "2001000000" if ( $taxon_oid eq "" );

		# form's javascripts, i had to add them here too.
		MetagJavaScript::printMetagJS();
		MetagJavaScript::printMetagSpeciesPlotJS();

		# build tree
		TreeHTML::printYuiTreePageStart();
		yuiPrintTreeFolderDynamic( $dbh, $taxon_oid );

		my $taxonName = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

		TreeHTML::printYuiTreePageEnd( "", "", "", 1, $taxonName );

		#$dbh->disconnect();

	} elsif ( $page eq "xmlphylum" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlPhylum($dbh);

		#$dbh->disconnect();

	} elsif ( $page eq "xmlfamily" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlFamily($dbh);

		#$dbh->disconnect();
	} elsif ( $page eq "xmlspecies" ) {
		my $dbh = dbLogin();

		# get xml data
		getXmlSpecies($dbh);

		#$dbh->disconnect();
	}
}

#
# Created XML data objects for phylum names
#
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
#	<response>
#	<method>xmlAddChildren</method>
#	<label name="Alcaligenaceae">
#   	<id>Alcaligenaceae</id>
#		<href> javascript:remoteSend(%22inner.cgi?xxxx%22)</href>
#		<url>xml.cgi?section=TestTree&xxxxx</url>
#	</label>
#   </response>
#
# if
#
# param $dbh - database handler
# param others from URL
# 		if domain is define in the url the phylum names are restricted to
#		that domain
#see getPhylumNames
sub getXmlPhylum {
	my ($dbh) = @_;

	my $taxon_oid = param("taxon_oid");

	# get phylum names
	my $aref = getPhylumNames( $dbh, $taxon_oid );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $phylumRec (@$aref) {
		my ( $domain, $phylum, $ir_class ) = split( /\t/, $phylumRec );

		# domain letter
		#my $domainLetter = substr( $domain, 0, 1 );

		# phylum / class column
		my $phylumClass = $phylum;
		$phylumClass = $ir_class if $ir_class ne "";
		$phylumClass = escHtml($phylumClass);

		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=family"
		  . "&taxon_oid=$taxon_oid"
		  . "&domain=$domain"
		  . "&phylum=$phylum";
		$url .= "&ir_class=$ir_class" if $ir_class ne "";
		$url .= "')";

		$url = escapeHTML($url);

		my $url2 = "xml.cgi?section=PhylumTree";
		$url2 .= "&page=xmlfamily";
		$url2 .= "&taxon_oid=$taxon_oid";
		$url2 .= "&domain=$domain";
		$url2 .= "&phylum=$phylum";
		$url2 .= "&ir_class=$ir_class" if $ir_class ne "";

		$url2 = escapeHTML($url2);

		#print "<label name=\"$domainLetter - $phylumClass\">\n";
		print "<label name=\"$phylumClass\">\n";
		print "<id>$phylumClass</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# Created XML data objects with family names
#
# param $dbh - database handler
# param others from URL
#
sub getXmlFamily {
	my ($dbh) = @_;

	my $taxon_oid = param("taxon_oid");
	my $domain    = param("domain");
	my $phylum    = param("phylum");
	my $ir_class  = param("ir_class");

	# get phylum names
	my $aref =
	  getPhylumFamilyNames( $dbh, $taxon_oid, $domain, $phylum, $ir_class );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $family (@$aref) {
		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=species"
		  . "&taxon_oid=$taxon_oid"
		  . "&domain=$domain"
		  . "&phylum=$phylum";
		$url .= "&ir_class=$ir_class" if $ir_class ne "";
		$url .= "&family=$family"     if $family   ne "";
		$url .= "')";

		$url = escapeHTML($url);

		my $url2 = "xml.cgi?section=PhylumTree";
		$url2 .= "&page=xmlspecies";
		$url2 .= "&taxon_oid=$taxon_oid";
		$url2 .= "&domain=$domain";
		$url2 .= "&phylum=$phylum";
		$url2 .= "&ir_class=$ir_class" if $ir_class ne "";
		$url2 .= "&family=$family" if $family ne "";

		$url2 = escapeHTML($url2);

		$family = escapeHTML($family);

		print "<label name=\"$family\">\n";
		print "<id>$family</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# Created XML data objects with species names
#
# param $dbh - database handler
# param others from URL
#
sub getXmlSpecies {
	my ($dbh) = @_;

	my $taxon_oid = param("taxon_oid");
	my $domain    = param("domain");
	my $phylum    = param("phylum");
	my $ir_class  = param("ir_class");
	my $family    = param("family");

	# get phylum names
	my $aref =
	  getSpeciesNames( $dbh, $taxon_oid, $domain, $phylum, $ir_class,
							 $family );

	print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
	print "\n<response>\n";

	foreach my $key (@$aref) {
		my ( $genus, $species ) = split( /\t/, $key );

		my $url =
		    "javascript:remoteSend('inner.cgi?section=MetagenomeHits"
		  . "&page=speciesForm"
		  . "&taxon_oid=$taxon_oid"
		  . "&domain=$domain"
		  . "&phylum=$phylum";
		$url .= "&ir_class=$ir_class" if $ir_class ne "";
		$url .= "&family=$family"     if $family   ne "";
		$url .= "&genus=$genus";
		$url .= "&species=$species"   if $species  ne "";
		$url .= "')";

		$url = escapeHTML($url);

		# its a leaf node, set it to mynull
		my $url2 = "mynull";

		my $genusSpecies = escapeHTML("$genus $species");

		print "<label name=\"$genusSpecies\">\n";
		print "<id>$genusSpecies</id>\n";
		print "<href>$url</href>\n";
		print "<url>$url2</url>\n";
		print "</label>\n";
	}

	print "</response>\n";
}

#
# database query to get species names
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
# param $domain - domain name
# param $phylum - phylum name
# param $ir_class - ir class name
# param $family - homolog's family name
# return list of names delimited by \t for genus and species
sub getSpeciesNames {
	my ( $dbh, $taxon_oid, $domain, $phylum, $ir_class, $family ) = @_;

    my @binds = ($taxon_oid, $domain, $phylum, $family);
    
	my $irclause = " and dt.ir_class = ? ";
	if ( !defined($ir_class) || $ir_class eq "" ) {
		$irclause = " and dt.ir_class is null ";
	} else {
	    push(@binds, $ir_class);
	}
	
	my $rclause   = WebUtil::urClause('t');
	my $imgClause = WebUtil::imgClause('t');
	my $sql = qq{
		select distinct $nvl(t.genus, '$unknown'), $nvl(t.species, '$unknown')
		from dt_phylum_dist_genes dt, taxon t
		where dt.homolog_taxon = t.taxon_oid
			$rclause
			$imgClause
			and dt.taxon_oid = ?
			and dt.domain = ?
			and dt.phylum = ?
			and t.family = ?
			$irclause
		order by 1, 2
	};
	my @names;

	my $cur = execSql( $dbh, $sql, $verbose, @binds  );
	for ( ; ; ) {
		my ( $genus, $species ) = $cur->fetchrow();
		last if !$genus;
		push( @names, "$genus\t$species" );
	}
	$cur->finish();

	return \@names;
}

#
# database query to get family names
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
# param $domain - domain name
# param $phylum - phylum name
# param $ir_class - ir class name
# return list of family names
sub getPhylumFamilyNames {
	my ( $dbh, $taxon_oid, $domain, $phylum, $ir_class ) = @_;

    my @binds = ($taxon_oid, $domain, $phylum);
    
	my $irclause = " and dt.ir_class = ? ";
	if ( !defined($ir_class) || $ir_class eq "" ) {
		$irclause = " and dt.ir_class is null ";
	} else {
	    push(@binds, $ir_class);
	}

	my $rclause   = WebUtil::urClause('t');
	my $imgClause = WebUtil::imgClause('t');
	my $sql = qq{
        select distinct $nvl(t.family, '$unknown')
		from dt_phylum_dist_genes dt, taxon t
		where dt.homolog_taxon = t.taxon_oid
		$rclause
		$imgClause
		and dt.taxon_oid = ?
		and dt.domain = ?
		and dt.phylum = ?
		$irclause
		order by 1
	};
	my @names;

	my $cur = execSql( $dbh, $sql, $verbose, @binds );
	for ( ; ; ) {
		my ($family) = $cur->fetchrow();
		last if !$family;
		push( @names, $family );
	}
	$cur->finish();

	return \@names;
}

#
# database query to get phylum names
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
# param others from URL
# 		if domain is define in the url the phylum names are restricted to
#		that domain
# return list of names
sub getPhylumNames {
	my ( $dbh, $taxon_oid ) = @_;

	my $mydomain = param("domain");

    my @binds = ($taxon_oid);

	if ( $mydomain ne "" ) {
		$mydomain = "and domain = ? ";
		push(@binds, $mydomain);
	} else {
		$mydomain = "";
	}

	my @names;

	my $sql = qq{
       select distinct dt.domain, dt.phylum, dt.ir_class
       from dt_phylum_dist_genes dt
       where dt.taxon_oid = ?
       $mydomain
       order by dt.domain, dt.phylum, dt.ir_class
   };
	my $cur = execSql( $dbh, $sql, $verbose, @binds );

	for ( ; ; ) {
		my ( $domain, $phylum, $ir_class ) = $cur->fetchrow();
		last if !$domain;

		my $r = "$domain\t";
		$r .= "$phylum\t";
		$r .= "$ir_class";
		push( @names, $r );
	}
	$cur->finish();

	return \@names;
}

#
# database query to get domain names
#
# param $dbh - database handler
# param $taxon_oid - metag taxon oid
#
# return list of names
sub getDomainNames {
	my ( $dbh, $taxon_oid ) = @_;

	my @names;

	my $sql = qq{
       select distinct dt.domain
       from dt_phylum_dist_genes dt
       where dt.taxon_oid = ?
       order by dt.domain
   };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

	for ( ; ; ) {
		my ($domain) = $cur->fetchrow();
		last if !$domain;

		push( @names, $domain );
	}
	$cur->finish();

	return \@names;
}

#
# Create my js tree
#
sub yuiPrintTreeFolderDynamic {
	my ( $dbh, $taxon_oid ) = @_;

	my $domain_aref = getDomainNames( $dbh, $taxon_oid );

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

	my $url2 = "mynull"
	  ;    #"xml.cgi?section=PhylumTree&page=xmlphylum&taxon_oid=$taxon_oid";

	my $url =
	    "javascript:remoteSend(%22inner.cgi?section=MetagenomeHits"
	  . "&page=metagenomeStats"
	  . "&taxon_oid=$taxon_oid%22)";

	# root node
	print "var myobj = { label: \"Phylum Tree\", id:\"$taxon_oid\", "
	  . "href:\"$url\", url:\"$url2\"};\n";
	print "var rootNode = new YAHOO.widget.TextNode(myobj, root, false);\n";

	#print "alert(rootNode.data.label);\n";
	#print "rootNode.data.label = 'changed';\n";
	#print "alert(rootNode.data.label);\n";
	# it did not change the label, data has changed 
	#     but ui still shows Phylum Tree
	#	  becuz html code has been reneder
	#print "rootNode.data.href = \"javascript:noop()\";\n";


	print "var node;\n";

	# add domain as children
	foreach my $domain (@$domain_aref) {
		my $url2 =
		    "xml.cgi?section=PhylumTree"
		  . "&page=xmlphylum&taxon_oid=$taxon_oid&domain=$domain";
		print "myobj = { label: \"$domain\", id:\"$domain\", "
		  . "href:\"javascript:noop()\", url:\"$url2\"};\n";
		print "node = new YAHOO.widget.TextNode(myobj, rootNode, false);\n";

	}

	# end function
	print <<EOF;


	//tree.expand(rootNode);
	rootNode.expand();
	tree.draw();
	var id = 'tooltipid';
	var tt = new YAHOO.widget.Tooltip("tt", { context:id,
		text:"Domain<br>+- Phlyum (IR Class)<br>+-- Family<br>+--- Genus Species" } );
}

</script>
EOF
}

1;
