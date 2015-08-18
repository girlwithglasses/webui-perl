package IMG::Util::Timed;

use IMG::Util::Base;

use POSIX;

=head3 timed_function

Run a timed function of some sort.

@param  $args   - hashref with keys
	# required:
	fn            - coderef - the function to run
	fn_timeout    - how long to allow the function to run before timing out (default: 10sec)

	# optional:
	handler       - coderef to handle failure of fn; should die with an appropriate error
	old_timeout   - setting to restore the timeout to (if applicable)


=cut

sub timed_function {
	# allow hash or hashref args
	my $args = ( @_ && 1 < scalar(@_) ) ? { @_ } : shift || {};

	die "Missing required arguments for timed_test" unless defined $args->{ fn } && defined $args->{ fn_timeout };

	die "test must be a coderef" unless 'CODE' eq ref( $args->{ fn } );

	my $handler = ( defined $args->{ handler } && 'CODE' eq ref( $args->{ handler }) )
	? $args->{handler}
	: sub { die "Operation timed out"; };

	my $mask   = POSIX::SigSet->new( SIGALRM );    # signals to mask in the handler
	my $action = POSIX::SigAction->new( $handler, $mask );
	my $oldaction = POSIX::SigAction->new();
	sigaction( SIGALRM, $action, $oldaction );
	local $@;
	my $result;
	eval {
		eval {
			alarm( $args->{fn_timeout} || 10 );    # seconds before time out
			# run the test.
			$result = $args->{ fn }->();
		};
		alarm(0);                  # cancel alarm (if connect worked fast)
		die $@ if $@;
    };
    if ($@) {
        # eval failed
        return { error => $@ };
    }

    # restore original signal handler, restore timeout
    sigaction( SIGALRM, $oldaction );
    alarm( $args->{old_timeout} // 0 );
    return { result => $result };

}


# method modifier version
sub timed_mm {
	my $orig = shift;
	my $self = shift;
	return timed_function( @_, fn => $orig );
}


1;
