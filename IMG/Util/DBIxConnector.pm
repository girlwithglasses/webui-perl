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

	if (! ref $arg_h || ref $arg_h ne 'HASH' || ! $arg_h->{dsn} ) {
		croak "database connection params should be specified as a hash ref and include the key 'dsn'";
	}

	my $conn = DBIx::Connector->new(
		$arg_h->{dsn},
		$arg_h->{username} // $arg_h->{user} // undef,
		$arg_h->{password} // undef,
		$arg_h->{options} // { RaiseError => 1 }
	) or die "Could not create a DB connection: $DBI::errstr";

	return $conn;

}

1;
