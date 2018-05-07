use strict;
use warnings;

use File::Basename;
use Test::More;

BEGIN {
    push(@INC, dirname(__FILE__));
}

use Test::MockModule;

use Net::OpenStack::Client;
use mock_rest qw(identity_v3);
use logger;


use Net::OpenStack::Client::Identity::v3;
is_deeply(\@Net::OpenStack::Client::Identity::v3::SUPPORTED_OPERATIONS,
   [qw(region domain project user role group service endpoint)],
   "ordered supported operations (order is meaningful, should not just change)");

my $items = {
    a => {par => 'c'},
    b => {par => 'f'},
    c => {},
    d => {par => 'e'},
    e => {par => 'c'},
    f => {},
    # filler, eg update or delete
    g => {},
    e => {par => 'g'},
};

my $res = [Net::OpenStack::Client::Identity::v3::sort_parents([qw(a b c d e f)], $items, 'par')];
diag "sort result ", explain $res;
is_deeply($res, [qw(c f a b e d)], "something sorted according to parenting");


my $openrcfn = dirname(__FILE__)."/openrc_example";
ok(-f $openrcfn, "example openrc file exists");


my $cl = Net::OpenStack::Client->new(log => logger->new(), debugapi => 1, openrc => $openrcfn);

# get_id

reset_method_history();
my $id = $cl->api_identity_get_id('user', 'existing');
dump_method_history;
ok(method_history_ok(['GET .*/users\?name=existing ']), "get_id uses name parameter");
is($id, 2, "get_id returns id");

# sync

reset_method_history();
$res = $cl->api_identity_sync('user', {
    anewuser => {description => 'new user', email => 'a@b'},
    existing => {description => 'existing user (managed by quattor)', email => 'e@b'},
    update => {description => 'to be updated (managed by quattor)', email => 'u@b'},
}, filter => sub {my $op = shift; return ($op->{description} || '') =~ m/managed by quattor/});

diag "sync result ", explain $res;
is_deeply($res, {
    create => [{id => 123}],
    update => [{id => 2}],
    delete => [{id => 4}],
}, "api_identity_sync user returns success");

dump_method_history;
ok(method_history_ok(
       [
        'GET .*/users/',
        'POST .*/users/ .*enabled":true.*name":"anewuser',
        'PATCH .*/users/2 .*description":',
        'PATCH .*/users/4 .*enabled":false',
       ],
       [
        'PATCH .*/users/[135]', # 1: nothing to update; 3: filtered out, 5: already disabled
        'PATCH .*/users/2 .*enabled', # only update what is required
       ]),
   "users created/updated/disabled; nothing done for certain existing users");

reset_method_history();
$res = $cl->api_identity_sync('region', {
    regone => {},
    a2nd => {parent_region_id => 'regone'},
    regtwo => {}}, tagstore => 'hoopla');

diag "region result ", explain $res;
is_deeply($res, {
    create => [{id => 'regone'}, {id => 'regtwo'}, {id => 'a2nd'}],
    update => [],
    delete => [],
}, "region sync ok");

dump_method_history;
ok(method_history_ok(
       [
        'GET .*/regions/',
        'POST .*/regions/ .*enabled":true.*"id":"regone',
        'POST .*/regions/ .*"id":"regtwo',
        'POST .*/regions/ .*"id":"a2nd".*parent_region_id":"regone"',
       ], [
        'POST .*/regions/ .*"parent"',
       ]),
   "regions created in order");

done_testing;
