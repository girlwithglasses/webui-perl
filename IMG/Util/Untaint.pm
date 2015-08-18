package IMG::Util::Untaint;

use IMG::Util::Base;

use Role::Tiny;


=head3 check_path

Check a path for dodgy characters, and return an untainted version of the path
if all looks OK. Croaks with a message on failure.

Allowed characters: a-z A-Z 0-9 _ - ~ . /

@param  $path

@return $sanitised_path

=cut

sub check_path {
    my $path = shift || return "";

	## Catch bad patterns first.
	if ( $path =~ /\.\./ ) {
		croak "check_path: invalid path contains '..': $path\n";
	}

	$path =~ m#([
		a-z0-9
		_
		\-
		~
		\.
		/
	]+)#xi;
    my $new_path = $1;

	if ( $new_path ne $path ) {
		croak "check_path: invalid path:\noriginal: $path\nchecked: $new_path";
	}

	return $new_path;
}

=head3 check_file_name

Check a file name (without path) for dodgy characters, and return an untainted
version of the name if all looks OK. Croaks with a message on failure.

Allowed characters: a-z A-Z 0-9 . _ -

@param  $f_name

@return $sanitised_name

=cut

sub check_file_name {
	my $f_name = shift || return "";

	$f_name =~ m#([
		a-z0-9
		\.
		_
		\-
	]+)#xi;

	my $new_name = $1;

	if ( $new_name ne $f_name ) {
		croak "check_file_name: invalid name:\noriginal: $f_name\nchecked: $new_name";
	}

	return $new_name;
}

=head3 unset_env

unset the usual tainted path suspects

=cut

sub unset_env {

	delete $ENV{qw( BASH_ENV CDPATH ENV IFS PATH )};

}


=head3 untaint_env

untaint all the environment paths that we might come across

runs everything through check_path

=cut

sub untaint_env {

	my @paths = qw( BASH_ENV CDPATH ENV IFS PATH );

	for my $p (@paths) {
		if ($ENV{ $p }) {

#			say STDERR "$p: paths: " . Dumper $ENV{ $p };

			# filter out everything that isn't in /usr, /global, or /opt
			my @p_arr = eval {
				map {
					local $@;
					my $new_path = check_path( $_ );
					( $@ ) ? return "" : $new_path;
				}
				grep { m#^/(usr|global|opt)# }
				split ":", $ENV{ $p };
			};

			if ( $@ ) {
				delete $ENV{ $p };
			}
			else {
				$ENV{ $p } = join ":", @p_arr;
			}
		}
	}
	return;
}

1;

=pod

=encoding UTF-8

=head1 NAME

IMG::Util::Untaint - untaint external data

=head2 SYNOPSIS

	use strict;
	use warnings;
	use IMG::Util::Untaint;

=cut
