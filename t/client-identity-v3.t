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

my $openrcfn = dirname(__FILE__)."/openrc_example";
ok(-f $openrcfn, "example openrc file exists");


my $cl = Net::OpenStack::Client->new(log => logger->new(), debugapi => 1, openrc => $openrcfn);
$cl->api_identity_sync('user', {
    anewuser => {description => 'new user', email => 'a@b'},
    existing => {description => 'existing user (managed by quattor)', email => 'e@b'},
    update => {description => 'to be updated (managed by quattor)', email => 'u@b'},
}, filter => sub {my $operator = shift; return ($operator->{description} || '') =~ m/managed by quattor/});

dump_method_history;
ok(method_history_ok(
       [
        'GET .*/users/',
        'POST .*/users/ .*enabled":1.*name":"anewuser',
        'PATCH .*/users/2 .*description":',
        'PATCH .*/users/4 .*enabled":0',
       ],
       [
        'PATCH .*/users/[135]', # 1: nothing to update; 3: filtered out, 5: already disabled
        'PATCH .*/users/2 .*enabled', # only update what is required
       ]),
   "users created/updated/disabled; nothing done for certain existing users");



done_testing;
