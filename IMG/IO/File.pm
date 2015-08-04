package IMG::IO::File;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";
use IMG::Util::Base;
use Role::Tiny;

=pod

=encoding UTF-8

=head1 NAME

IMG::IO::File - Miscellaneous file-related utility routines

=head2 SYNOPSIS

	use strict;
	use warnings;
	use IMG::IO::File;

	# read a file into an arrayref
	my $lines = IMG::IO::File::file_to_array( '/path/to/file' );
	for my $l (@$lines) {
		# do something with each line...
	}

	# parse a tab-delimited file into an array of arrays
	my $data = IMG::IO::File::file_to_aoa( '/my/file.tsv' );

	# get the fifth column on the third row
	my $cell = $data->[2][4];

	# get a file as a string
	my $str = IMG::IO::File::slurp( '/path/to/text/file.txt' );
	# $str will still have line endings embedded in it

	# parse a file of key-value data with ':' as the separator
	my $hashref = IMG::IO::File::file_to_hash( '/my/key/value/store.txt', ':' );
	if ( $hashref->{thing_of_interest} eq 'value of interest' ) {
		# do something
	}

=head3 slurp

slurp a file into a scalar (the file contents will be a single string)

=cut

=head3 file_to_array

read a file into an array

@param  $file       the file to parse (including path)

@return $arrayref   of non-blank lines in the file


=head3 file_to_hash

read a file and parse it into a hash

Identical keys are overwritten

@param  $file       the file to parse (including path)
@param  $sep        key / value separator; defaults to '='

@return $hashref


=head3 file_to_aoa

parse a file into an array of arrays

@param  $file       the file to parse (including path)
@param  $sep        record separator; defaults to "\t" (tab)

@return $arrayref of arrays

=cut


sub slurp {

	return _parse( 'slurp', @_ );

}

sub file_to_array {

	return _parse( 'file_to_array', @_ );

}

sub file_to_aoa {

	return _parse( 'file_to_aoa', @_ );

}

sub file_to_hash {

	return _parse( 'file_to_hash', @_ );

}


sub _parse {

	my $sub = shift || croak 'No file reading sub specified!';
	my $file = shift || croak 'No file specified!';

	open (my $fh, "<", $file) or croak "Could not open $file: $!";

	my $sub_h = {

		slurp => sub {
			local $/;
			my $contents = <$fh>;
			return $contents;
		},

		file_to_array => sub {
			my @contents;
			while (<$fh>) {
				next unless /\w/;
				chomp;
				push @contents, $_;
			}
			return [ @contents ];
		},

		file_to_aoa => sub {
			my $sep = shift // "\t";
			my @contents;
			while (<$fh>) {
				next unless /\w/;
				chomp;
				push @contents, [ split $sep, $_ ];
			}
			return [ @contents ];
		},

		file_to_hash => sub {
			my $sep = shift // '=';
			my %contents;
			while (<$fh>) {
				next unless /\w/;
				chomp;
				my ($k, $v) = split $sep, $_, 2;
				$contents{$k} = $v || undef;
			}
			return \%contents;
		},
	};

	croak 'invalid file parsing routine supplied' unless $sub_h->{$sub};

	return $sub_h->{ $sub }->( @_ );

}

1;
