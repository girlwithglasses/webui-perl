#!/usr/bin/env perl

use FindBin qw/ $Bin /;
use lib "$Bin/../";
use IMG::Util::Base 'Test';

use IMG::Dispatcher;
use CGI;

use Test::Taint;

=cut

For each of a set of URL params, compare the module and sub run and the other changes made by main.pl vs Dispatcher.pm




=cut

my $cgi = CGI->new();

$cgi->param('section', 'StudyViewer');

IMG::Dispatcher::dispatch_page({ env => {}, cgi => $cgi, session => {} });

$cgi->param('section', 'GenomeListJSON');

IMG::Dispatcher::dispatch_page({ env => {}, cgi => $cgi, session => {} });



done_testing();
