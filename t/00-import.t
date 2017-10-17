use strict;
use warnings;

use Test::More;

my @mods = qw(
    API::Convert API::Magic
    Client::Request Client::Response Client::API
);

foreach my $mod (@mods) {
    my $fmod = "Net::OpenStack::$mod";
    use_ok($fmod);
};


done_testing;
