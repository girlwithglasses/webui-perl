package IMG::Util::DBIxConnector;

use IMG::Util::Base;

use DBIx::Connector;

=head3 get_dbix_connector

Create a database handle for a database using DBIx::Connector

@param      hash of params, including dsn  -- the database name
                                      options   -- DBH options

@output     $conn - database connection object

=cut

sub get_dbix_connector {
	my $arg_h = shift // croak "No connection parameters specified!";

	if (! ref $arg_h || ref $arg_h ne 'HASH' ) {
		croak "database connection params should be specified as a hash ref and include the key 'dsn'";
	}

	if (! $arg_h->{dsn} ) {
		if (! $arg_h->{database} || ! $arg_h->{driver} ) {

			croak __PACKAGE__ . ' ' . (caller(0))[3]
			. " requires either a DSN string or the database name and driver";
		}
		$arg_h->{dsn} = 'dbi'
			. ':' . $arg_h->{driver}
			. ':' . $arg_h->{database};
	}

	my $conn = DBIx::Connector->new(
		$arg_h->{dsn},
		$arg_h->{username} // $arg_h->{user} // undef,
		$arg_h->{password} // $arg_h->{pass} // undef,
		$arg_h->{options} // $arg_h->{dbi_params} // { RaiseError => 1 }
	) or die "Could not create a DB connection: $DBI::errstr";

	return $conn;

}

1;
