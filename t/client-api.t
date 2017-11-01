use strict;
use warnings;

use File::Basename;
BEGIN {
    push(@INC, dirname(__FILE__));
}

use Test::More;
use Test::MockModule;

use testapi;

my $client = testapi->new();
$client->{versions}->{theservice} = 'v3.1';
my $resp = $client->api_theservice_humanreadable();
isa_ok($resp->{req}, 'Net::OpenStack::Client::Request',
       "client method called returned AUTOLOADed response with call to rest method");
like($resp->{req}->{error},
     qr{endpoint template user name user mandatory},
     "used request missing templates");

$resp = $client->api_theservice_humanreadable(user => 'auser');
like($resp->{req}->{error},
     qr{option int name int mandatory},
     "used request missing mandatory options");

$resp = $client->api_theservice_humanreadable(user => 'auser', int => 1, name => 'thename');
my $req = $resp->{req};
ok($req, "returned response used request has no error");
is($req->{method}, 'POST', 'used request has POST method');
is($req->{endpoint}, '/some/{user}/super', 'used request has endpoint');

# custom client code

my $custom_result = $client->api_theservice_custom_method("a", "b");
is_deeply($custom_result, [qw(a b)], "custom_method from client module returns whatever it returns");

done_testing;
