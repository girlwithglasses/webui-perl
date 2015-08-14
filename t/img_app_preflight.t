#!/usr/bin/env perl

use FindBin qw/ $Bin /;
use lib "$Bin/../";
use IMG::Util::Base 'Test';
use File::Temp qw/ tempfile tempdir /;

use IMG::App::Core;
use IMG::App::PreFlight;

{
	package TestApp;
	use IMG::Util::Base 'Class';
	extends 'IMG::App::Core';
	with 'IMG::App::PreFlight';
}


my $errors = {
	db_offline => sub {
		return {
			status => 503,
			title  => 'Service Unavailable',
			message => 'The database is currently being serviced; we apologise for the inconvenience. Please try again later.',
		};
	},
	unavailable_msg => sub {
		my $msg = shift;
		return {
			status => 503,
			title  => 'Service Unavailable',
			message => $msg,
		};
	},
	service_unavailable => sub {
		return {
			status => 503,
			title  => 'Service Unavailable',
			message => 'The IMG servers are currently overloaded and unable to process your request. Please try again later.',
		};
	},
	too_many_requests => sub {
		return {
			status => 429,
			title  => 'Too Many Requests',
			message => 'There have been too many requests from your IP address, so it has blocked.',
		};
	},
	forbidden => sub {
		return {
			status  => 403,
			title   => 'Forbidden',
			message => 'Bots are forbidden from accessing this area of IMG.',
		};
	},
};

sub gen_env {

	my $args = shift;

	return {
		bot_patterns => [ qw(
			accelobot
			AI-Agent
			Axel
			BecomeBot
			bot
			crawler
			curl
			Darwin
			FirstGov
			Java
			Jeeves
			libwww
			lwp
			Mechanize
			linkout link check
			NimbleCrawler
			Python
			slurp
			Sphider
			wget
			ysearch
		) ],
		allow_hosts => [ qw( 100.99.88.77 ) ],
		%$args
	};

}

# fake a dblock file, test the response

subtest 'db_lock_check' => sub {

	my ($fh, $fn) = tempfile();

	run_test({
		env => gen_env({ dblock_file => $fn }),
		http_params => {},
		err => $errors->{db_offline}->(),
		msg => 'DB offline'
	});

	# add a message to the db lock file
	open $fh, ">", $fn or die "Could not open $fn: $!";
	my $msg = 'We have consulted the Oracle, and it is silent.';
	print { $fh } $msg;
	close $fh;

	run_test({
		env => gen_env({ dblock_file => $fn }),
		http_params => {},
		err => $errors->{unavailable_msg}->( $msg ),
		msg => 'DB offline with message'
	});

};

subtest 'block_bots' => sub {

	# set up some ENV variables
	$ENV{HTTP_USER_AGENT} = 'MECHANIZE';
	$ENV{REMOTE_ADDR} = '1.2.3.4';
#	$q->http('X-Forwarded-For');

	my ($fh, $fn) = tempfile();

	run_test({
		env => gen_env({
			block_ip_address_file => $fn,
			allow_hosts => [ qw(
				127.0.0.1
				1.2.3.45
			) ],
		}),
		http_params => {},
		err => $errors->{forbidden}->(),
		msg => 'bot blocker'
	});

	run_test({
		env => gen_env({
			block_ip_address_file => $fn,
		}),
		http_params => { page => 'home' },
		err => undef,
		msg => 'bot allowed on home page'
	});

	run_test({
		env => gen_env({
			allow_hosts => [ qw(
				127.0.0.1
				1.2.3.4
				22.44.66.88
			)],
		}),
		http_params => {},
		err => undef,
		msg => 'bot allowed by allow_hosts setting'
	});

	run_test({
		env => gen_env({
			allow_hosts => [ qw(
				127.0.0.1
				1.2.*
			)],
		}),
		http_params => {},
		err => undef,
		msg => 'bot allowed by allow_hosts wildcard setting'
	});

	# NCBI Linkout bot
	$ENV{HTTP_USER_AGENT} = 'LinkOut Link Check Utility';
	$ENV{REMOTE_ADDR} = '130.14.25.148';
	run_test({
		env => gen_env({
			block_ip_address_file => $fn,
		}),
		http_params => {},
		err => undef,
		msg => 'NCBI linkout bot'
	});

	# NCBI linkout bot with incorrect IP
	$ENV{REMOTE_ADDR} = '128.55.71.37';
	run_test({
		env => gen_env({
			block_ip_address_file => $fn,
		}),
		http_params => {},
		err => $errors->{forbidden}->(),
		msg => 'NCBI linkout bot blocked (wrong IP)'
	});

};


subtest 'block_ip_address' => sub {

	my ($fh, $fn) = tempfile();
	open $fh, ">", $fn or die "Could not open $fn: $!";
	print { $fh } q{1.2.3.4=in order
127.0.0.1=no place like it
256.0.8.64=powerful
};
	close $fh;

	delete @ENV{ qw( HTTP_USER_AGENT HTTP_X_FORWARDED_FOR REMOTE_ADDR ) };

	$ENV{HTTP_USER_AGENT} = 'Mozilla';
	$ENV{HTTP_X_FORWARDED_FOR} = '1.2.3.45';

	run_test({
		env => { block_ip_address_file => $fn },
		http_params => {},
		err => undef,
		msg => 'IP address OK',
	});

	$ENV{HTTP_X_FORWARDED_FOR} = '127.0.0.1';

	run_test({
		env => { block_ip_address_file => $fn },
		http_params => {},
		err => $errors->{too_many_requests}->(),
		msg => 'IP address blocked',
	});

	delete $ENV{HTTP_X_FORWARDED_FOR};
	$ENV{REMOTE_ADDR} = '256.0.8.64';

	run_test({
		env => { block_ip_address_file => $fn },
		http_params => { page => 'home' },
		err => $errors->{too_many_requests}->(),
		msg => 'IP address blocked',
	});


};

subtest 'max_cgi_process_check' => sub {

	# this seems a bit pointless.
	run_test({
		env => { max_cgi_procs => 1 },
		http_params => {},
		err => $errors->{service_unavailable}->(),
		msg => 'Exceeded max processes',
	});

	run_test({
		env => { max_cgi_procs => 10 },
		http_params => {},
		err => undef,
		msg => 'All is well',
	});


};

subtest 'directory_exists' => sub {

	my ($fh, $fn) = tempfile();
	my $dir = File::Temp->newdir();

	#
	run_test({
		env => {},
		http_params => {},
		err => $errors->{unavailable_msg}->( 'The IMG file system is not available. Please try again later.' ),
		msg => 'testing file (not directory)',
		check_args => {
			check_dir => $fn
		}
	});

	run_test({
		env => {},
		http_params => {},
		err => $errors->{unavailable_msg}->( 'The IMG file system is not available. Please try again later.' ),
		msg => 'made up directory',
		check_args => {
			check_dir => 'i/made/up/this/directory',
		}
	});

	run_test({
		env => {},
		http_params => {},
		err => undef,
		msg => 'directory is OK!',
		check_args => {
			check_dir => '/',
		}
	});

	# TO DO: make this test work!!
	run_test({
		env => {},
		http_params => {},
		err => $errors->{unavailable_msg}->( 'The IMG file system is not available. Please try again later.' ),
		msg => 'timeout',
		check_args => {
			check_dir => '',
		}
	});

};


sub run_test {

	my $args = shift;

	my $app = TestApp->new( env => $args->{env}, http_params => $args->{http_params} );

#	say Dumper $app;

	my $resp = $app->run_checks( $args->{check_args} || {} );

	is_deeply( $resp, $args->{err}, $args->{msg} );

}

done_testing();


