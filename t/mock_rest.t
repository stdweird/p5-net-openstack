use strict;
use warnings;

use File::Basename;
use Test::More;

BEGIN {
    push(@INC, dirname(__FILE__));
}

use Test::MockModule;

use Net::OpenStack::Client;
use mock_rest qw(example);
use logger;

# Load test api
use FindBin qw($Bin);
use lib "$Bin/testapi";

=head2 import

=cut

is(scalar keys %mock_rest::cmds, 2, "imported example data");

=head2 Test the mock_rest test module

=cut

my $cl = Net::OpenStack::Client->new(log => logger->new(), debugapi => 1);
$cl->{versions}->{theservice} = 'v3.1';
isa_ok($cl, 'Net::OpenStack::Client', 'Net::OpenStack::Client instance');

my $resp = $cl->api_theservice_humanreadable(user => 'auser', int => 1, name => 'thename');
isa_ok($resp, 'Net::OpenStack::Client::Response', 'got valid response');

is_deeply($resp->{data}, {woo => 'hoo'}, "Correct data from POST");
is_deeply($resp->{headers}, {'Content-Type' => 'application/json'}, "Correct (default) headers");
ok(!$resp->{error}, "response error is false");
ok($resp, "response is not an error");

$resp = $cl->api_theservice_simple();
is_deeply($resp->{data}, {success => 1}, "Correct (default) data from GET");
is_deeply($resp->{headers}, {'Content-Type' => 'application/json', 'Special' => 123}, "Correct headers");

my @hist = find_method_history(''); # empty string matches everything
#diag "whole history ", explain \@hist;
is_deeply(\@hist, [
    'POST /some/auser/super {"something":{"name":"thename"}} Accept=application/json, text/plain,Accept-Encoding=identity, gzip, deflate, compress,Content-Type=application/json',
    'GET /simple  Accept=application/json, text/plain,Accept-Encoding=identity, gzip, deflate, compress,Content-Type=application/json'
], "method history: one POST call");

ok(method_history_ok(['POST /some/auser/super', 'GET']), "call history ok");

# Tests the order
ok(! method_history_ok(['GET', 'POST']), "GET not called before POST");

# Test not_commands
ok(method_history_ok(['POST', 'GET'], ['PATCH']), "no PATCH called (in method history)");
ok(!method_history_ok(['POST'], ['GET']), "no no GET called (i.e. GET called in method history)");

reset_method_history;

@hist = find_method_history('');
is_deeply(\@hist, [], "method history empty after reset");

done_testing();
