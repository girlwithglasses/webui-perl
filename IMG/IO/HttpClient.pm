package IMG::IO::HttpClient;

use IMG::Util::Base;

use HTTP::Tiny;
use IO::Socket::SSL;
use Net::SSLeay;

use Role::Tiny;

has 'http_ua' => (
	is => 'lazy',
);

sub _build_http_ua {
	my $self = shift;
	return HTTP::Tiny->new( @_ );
}

1;
