use strict;
use warnings;

use Test::More;
use Test::MockModule;

use FindBin qw($Bin);
use lib "$Bin/testapi";

{
    package testclient;
    use parent qw(Net::OpenStack::Client::API);
    sub new
    {
        my ($this) = @_;
        my $class = ref($this) || $this;
        my $self = {};
        bless $self, $class;
        return $self;
    }
    sub rpc
    {
        my ($self, $req) = @_;
        # dummy rpc call, do nothing, just wrap teh request in simple hashref and return it
        return {req => $req};
    }

}

my $client = testclient->new();
$client->{version} = 'v3.1';
my $resp = $client->api_theservice_humanreadable();
isa_ok($resp->{req}, 'Net::OpenStack::Client::Request',
       "client method called returned AUTOLOADed response with call to rpc method");
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

done_testing;
