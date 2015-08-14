############################################################################
#	IMG::App.pm
#
#	Core IMG application to run pre-flight checks, check the user, initiate
#	the session, parse params, and dispatch the appropriate app.
#
#	$Id: App.pm 33827 2015-07-28 19:36:22Z aireland $
############################################################################
package IMG::App;

use IMG::Util::Base 'Class';

extends 'IMG::App::Core';

with 'IMG::App::PreFlight',
#'IMG::App::User';
'IMG::App::Dispatcher';

use WebUtil qw();

has 'tmpl_args' => (
	is => 'rw',
	predicate => 1,
	writer => 'set_tmpl_args',
);

has 'renderer' => (
	is => 'lazy',
);

sub _build_renderer {



}


sub run {
	my $self = shift;

	say "I'm running!";

	my $err = $self->run_checks({
		check_dir => $env->{ifs_tmp_parent_dir}
	});

	die $err if $err;

	# set up session, run user checks

	local $@;

	my $run_args = eval { $self->prepare_dispatch; };

	if ($@) {

		# error!

	}

#		sub    - subroutine to run
#		module - module to load
#		tmpl   - outer page template to use (defaults to 'default')
#		tmpl_args  - template arguments
#		sub_to_run - reference to the subroutine to run

	my $sub = $run_args->{sub_to_run};
	# is this a long-running script?
	if ($run_args->{tmpl_args}{timeout_mins}) {
#		warn "setting timeout...";
		WebUtil::timeout( $run_args->{tmpl_args}{timeout_mins} );
	}

	$self->renderer->prepare;

#	warn "Running the sub";
	# capture output and save it to $output
	my $output;
	$| = 1;

	local $@;
	eval {

		open local *STDOUT, ">", \$output;

		$to_do->( $arg_h->{n_taxa} );

		close local *STDOUT;

	};

	if ($@) {
		croak $@;
	}

	warn "I got this output: $output";

	$self->render( $output );

}

1;
