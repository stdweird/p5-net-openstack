use strict;
use warnings;

use Test::More;
use Test::MockModule;

use FindBin qw($Bin);
use lib "$Bin/testapi";

#use Net::OpenStack::API::theservice::v3DOT1;
#diag "API_DATA ", explain $Net::OpenStack::API::theservice::v3DOT1::API_DATA;

use JSON::XS;

use Net::OpenStack::API::Magic qw(retrieve);

use Readonly;

=head2 cache

=cut

my $data = {
    name => 'end',
    service => 'something',
    more_data => {whatever => 1}
};

my $c;
$c = Net::OpenStack::API::Magic::cache($data);
is_deeply($c, $data, "cache returns data");

=head2 retrieve

=cut

my $err;

($c, $err) = retrieve('theservice', 'humanreadable', 'v3.1');
is_deeply($c, {
    service => 'theservice',
    name => 'humanreadable',
    method => 'POST',
    endpoint => '/some/{user}/super',
    templates => [qw(user)],
    options => {
        'int' => {'type' => 'long','path' => ['something','int'], required => 1},
        'boolean' => {'path' => ['something','boolean'],'type' => 'boolean'},
        'name' => {'type' => 'string','path' => ['something','name']},
    },
}, 'theservice humanreadable retrieved');
ok(! defined($err), "No error");
#diag "retrieve ", explain $c, " error ", explain $err;

my $c2;
($c2, $err) = retrieve('theservice', 'humanreadable', 'v3.1');
# This is an identical test, not only content
is($c2, $c, 'user_add retrieved 2nd time is same data/instance (from cache)');
ok(! defined($err), "No error 2nd time");

($c, $err) = retrieve('noservice', 'certainlynomethod', 'v1.2.3');
is_deeply($c, {}, 'unknown service retrieves undef');
like($err,
     qr{retrieve name certainlynomethod for service noservice version v1.2.3 failed: no module Net::OpenStack::API::noservice::v1DOT2DOT3:},
     "retrieve of unknown service returns error message");

($c, $err) = retrieve('theservice', 'nomethod', 'v3.1');
is_deeply($c, {}, 'unknown name retrieves undef');
like($err,
   qr{retrieve name nomethod for service theservice version v3.1 failed: no API data},
   "retrieve of unknown name returns error message");

=head2 flush_cache

=cut

my $cache = Net::OpenStack::API::Magic::flush_cache();
is_deeply($cache, {}, "returned cache is emty");

my $c3;
($c3, $err) = retrieve('theservice', 'humanreadable', 'v3.1');
# This is an identical test, not only content
isnt($c3, $c2, 'user_add retrieved 3rd time after cache flush is not same data/instance');
is_deeply($c3, $c2, 'user_add retrieved 3rd time after cache flush has same data');


done_testing;
