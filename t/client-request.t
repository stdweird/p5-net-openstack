use strict;
use warnings;

# does not test mkrequest auto-export via @EXPORT
use Net::OpenStack::Client::Request qw(mkrequest parse_endpoint @SUPPORTED_METHODS);

use REST::Client;
use Test::More;

my $r;

my $client = REST::Client->new();
foreach my $method (@SUPPORTED_METHODS) {
    ok($client->can($method), "REST::Client supports method $method");
}


=head1 init

=cut

$r = Net::OpenStack::Client::Request->new('c', 'POST');
isa_ok($r, 'Net::OpenStack::Client::Request', 'a Net::OpenStack::Client::Request instance created');


$r = mkrequest('c', 'POST');
isa_ok($r, 'Net::OpenStack::Client::Request', 'a Net::OpenStack::Client::Request instance created using mkrequest');

is($r->{endpoint}, 'c', 'endpoint set');
is($r->{method}, 'POST', 'method set');
is_deeply($r->{tpls}, {}, 'empty hash ref as tpls by default');
is_deeply($r->{opts}, {}, 'empty hash ref as opts by default');
is_deeply($r->{rpc}, {}, 'empty hash ref as rpc by default');
is_deeply($r->{post}, {}, 'empty hash ref as post by default');
ok(! defined($r->{error}), 'No error attribute set by default');
ok(! defined($r->{id}), 'No id attribute set by default');
ok(! $r->is_error(), 'is_error false');
ok($r, 'overloaded boolean = true if no error via is_error');

$r = mkrequest('d', 'PUT', tpls => {a => 2}, opts => {a => 3, b => 4}, error => 'message', rpc => {woo => 'hoo'}, post => {awe => 'some'}, id => 123);
is($r->{endpoint}, 'd', 'endpoint set 2');
is($r->{method}, 'PUT', 'method set 2');
is_deeply($r->{tpls}, {a => 2}, 'array ref as tpls');
is_deeply($r->{opts}, {a => 3, b => 4}, 'hash ref as opts');
is_deeply($r->{rpc}, {woo => 'hoo'}, 'hash ref as rpc');
is_deeply($r->{post}, {awe => 'some'}, 'hash ref as post');
is($r->{error}, 'message', 'error attribute set');
is($r->{id}, 123, 'id attribute set');
ok($r->is_error(), 'is_error true');
ok(! $r, 'overloaded boolean = false on error via is_error');

$r = Net::OpenStack::Client::Request->new('c', 'NOSUCHMETHOD');
isa_ok($r, 'Net::OpenStack::Client::Request', 'a Net::OpenStack::Client::Request instance created');
ok(!defined($r->{method}), "undefined method attribute with unsupported method");
ok(!$r, "false request with unsupported method");
is($r->{error}, "Unsupported method NOSUCHMETHOD", "error message with unsupported method");

=head1 endpoints

=cut

is_deeply(parse_endpoint("/a/b/c"), [], "endpoint w/o templates");
is_deeply(parse_endpoint("/a/{b}/c/{b}/{e}/"), [qw(b e)], "endpoint with templates");

my $endpt = 'd/{a}/b/{a}/c/{d}/e';
$r = mkrequest($endpt, 'PUSH', tpls => {a => 2, d => 'd'});
is($r->{endpoint}, $endpt, "endpoint before templating");
is($r->endpoint, 'd/2/b/2/c/d/e', "templated endpoint");
is($r->{endpoint}, $endpt, "endpoint after templating");

delete $r->{tpls}->{d};
ok(!defined($r->endpoint), "failed endpoint templating returns undef");
is($r->{endpoint}, $endpt, "endpoint after failed templating");
ok(!$r, "false request after failed templating");
is($r->{error}, "Missing template d data to replace endpoint d/{a}/b/{a}/c/{d}/e", "error after failed templating");

done_testing();
