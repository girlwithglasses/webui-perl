#!/usr/bin/env perl

use FindBin qw/ $Bin /;
use lib "$Bin/../";
use IMG::Util::Base 'Test';

use IMG::Util::Untaint;

use Test::Taint;

# use WebUtil qw( checkPath );

sub get_args {
	my $env = shift;

	say 'env: ' . Dumper $env;

	my $args = {
		title => 'Abundance Profile Search',
		current => "CompareGenomes",
		help => "userGuide_m.pdf#page="
	};
	$args->{help} .=
	( $env->{include_metagenomes} )
	?  "19"
	:  "51";

	return $args;
}

my $cfg = { include_metagenomes => 1, pip => 1 };

my $arg_h = get_args( $cfg );

say 'arg_h: ' . Dumper $arg_h;

ok( $arg_h->{help} eq 'userGuide_m.pdf#page=19' );

my $arg_h2 = get_args( { pop => 1, pip => 2 } );

ok( $arg_h2->{help} eq 'userGuide_m.pdf#page=51' );

my @server = split ':', '/usr/common/usg/languages/perl/5.16.0/bin:/usr/common/usg/languages/gcc/4.6.3_1/bin:/global/common/genepool/usg/languages/R/3.0.1/bin:/usr/common/usg/utilities/curl/7.26.0/bin:/usr/common/usg/languages/java/jdk/oracle/1.7.0_51_x86_64/bin:/usr/common/jgi/aligners/clustal-omega/1.1.0/bin:/usr/common/jgi/aligners/clustalw/2.1/bin:/usr/common/usg/languages/python/2.7.4/bin:/usr/common/usg/utilities/mysql/5.0.96_1/bin:/usr/common/jgi/frameworks/EMBOSS/6.4.0/bin:/global/homes/a/aireland/perl5/bin:/usr/common/usg/languages/python/2.7.4/bin:/usr/common/usg/languages/perl/5.16.0/bin:/usr/common/usg/utilities/mysql/5.0.96_1/bin:/usr/common/usg/languages/gcc/4.6.3_1/bin:/usr/common/jgi/oracle_client/11.2.0.3.0/client_1/bin:/usr/common/usg/languages/java/jdk/oracle/1.7.0_51_x86_64/bin:/usr/common/usg/bin:/usr/common/mss/bin:/usr/common/nsg/bin:/opt/uge/genepool/uge/bin/lx-amd64:/usr/syscom/nsg/bin:/usr/syscom/nsg/opt/Modules/3.2.10/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games';

my %paths = (
	invalid => [
		'not\ a\ valid\ path',
		'/files/html/*',
		'files/../html',
		'opt[local]lib',
		'this path is not valid',
	],
	valid => [
		'',
		'/',
		'~/files/html/',
		'/opt/local/files.html',
		'/opt/dir-name-with-hyphens/dot.com/',
		@server
	],
);

for my $p ( @{$paths{invalid}} ) {
	#simulate taint
	taint( $p );
	throws_ok { IMG::Util::Untaint::check_path( $p ) }
		qr/check_path: invalid path/,
		'Invalid path';

}

for my $p2 ( @{$paths{valid}} ) {
	taint( $p2 );
	my $res = IMG::Util::Untaint::check_path( $p2 );
	ok( $p2 eq $res && ! tainted( $res ), 'Checking path is identical and untainted' );
}

done_testing();
