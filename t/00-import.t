use strict;
use warnings;

use Test::More;

my @mods = qw(
    API::Convert API::Magic
    Request Response
    API REST Base
);

my $base = 'Net::OpenStack::Client';
foreach my $mod (@mods) {
    my $fmod = "${base}::$mod";
    use_ok($fmod);
};

use_ok($base);

done_testing;
