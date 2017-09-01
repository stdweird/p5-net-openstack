use strict;
use warnings;

use JSON::XS;

use Test::More;
use Test::MockModule;

use Net::OpenStack::API::Convert qw(process_args); # Test import

use Readonly;

=head2 convert

=cut

my $data = {
    int => 5,
    float => 10.5,
    str => 20,
    bool_false => 0,
    bool_true => 1,
    bool_list => [1, 0, 1],
    bool_hash => { a=>1, b=>0, c=>1},
    not_a_type => {a => 1},
};

my $new_data = {};
foreach my $key (keys %$data) {
    my $type = $key;
    $type =~ s/_\w+$//;
    $new_data->{$key} = Net::OpenStack::API::Convert::convert($data->{$key}, $type);
};

# Convert it in to non-pretty JSON string
my $j = JSON::XS->new();
$j->canonical(1); # sort the keys, to create reproducable results
is($j->encode($new_data),
   '{"bool_false":false,"bool_hash":{"a":true,"b":false,"c":true},"bool_list":[true,false,true],"bool_true":true,"float":10.5,"int":5,"not_a_type":{"a":1},"str":"20"}',
   "JSON string of converted data");

my $value;
local $@;
eval {
    $value = Net::OpenStack::API::Convert::convert('a', 'int');
};

like("$@", qr{^Argument "a" isn't numeric in addition}, "convert dies string->int");
ok(! defined($value), "value undefined on died convert string->int");

eval {
    $value = Net::OpenStack::API::Convert::convert('a', 'float');
};

like("$@", qr{^Argument "a" isn't numeric in multiplication}, "convert dies string->float");
ok(! defined($value), "value undefined on died convert string->float");

=head2 check_command

=cut

sub ct
{
    my ($cmd, $value, $where, $iserr, $exp, $msg) = @_;
    my $orig;
    $orig = $j->encode($where) if ref($where);
    my $err = Net::OpenStack::API::Convert::check_option($cmd, $value, $where);
    if ($iserr) {
        like($err, qr{$exp}, "error occurred $msg");
        is($j->encode($where), $orig, "where unmodified $msg") if ref($where);
    } else {
        is($j->encode($where), $exp, "where as expected $msg");
        ok(! defined($err), "no error $msg");
    }
}

ct({required => 1, name => 'abc'}, undef, {},
   1, 'name abc mandatory with undefined value', 'missing mandatory value');
ct({required => 0, name => 'abc'}, undef, {},
   0, '{}', 'missing non-required value');

ct({required => 1, name => 'abc'}, 1, '',
   1, 'name abc unknown where ref $', 'invalid where (only array and hash refs)');


ct({required => 1, name => 'abc', type => 'int'}, 'a', [],
   1, 'name abc where ref ARRAY died Argument "a" isn\'t numeric in addition', 'conversion died string->int');


ct({required => 1, name => 'abc', type => 'bool'}, 1, [1],
   0, '[1,true]', 'added non-multi bool to where list');

ct({required => 1, name => 'abc', type => 'bool'}, 1, {xyz => 2},
   0, '{"abc":true,"xyz":2}', 'added non-multi bool to where hash');

=head2 process_args

=cut

sub pat
{
    my ($res, $msg, $err, $tpls, $opts, $rpc, $jres) = @_;

    isa_ok($res, "Net::OpenStack::Client::Request", 'process_args returns Request instance');

    if($res) {
        ok(! $res->is_error(), "no error $msg");
        # Start with this before comparing individual values with is_deeply
        is($jres, $j->encode([$res->{tpls}, $res->{opts}]), "json/converted values $msg");

        is_deeply($res->{tpls}, $tpls, "templates $msg");
        is_deeply($res->{opts}, $opts, "options $msg");
        is_deeply($res->{rpc}, $rpc, "rpc options $msg");
    } else {
        $err = 'WILLNEVERMATCH' if ! defined($err);
        like($res->{error}, qr{$err}, "error $msg");
    }
}

# Has mandatory posarg, non-mandatory option
my $cmdhs = {
    method => 'POST',
    endpoint => '/do_{user}_something',
    templates => [qw(user)],
    options => [{
        name => 'test',
        type => 'int',
        required => 0,
    }]
};

pat(process_args($cmdhs),
    'templates check_option error propagated (no templates for endpoint)',
    'endpoint template user name user mandatory with undefined value');

# make version mandatory
$cmdhs->{options}->[0]->{required} = 1;
pat(process_args($cmdhs, user => 'auser'),
    'missing mandatory option',
    'option test name test mandatory with undefined value');
$cmdhs->{options}->[0]->{required} = 0;

pat(process_args($cmdhs, user => 'auser', test => 'a', abc => 10),
    'invalid option value conversion',
    'option test name test where ref HASH died Argument.*numeric in addition');

pat(process_args($cmdhs, user => 'auser', test => 2, abc => 10),
    'invalid option',
    'option invalid name abc');

pat(process_args($cmdhs, user => 'auser', test => 2, __abc => 10),
    'process_args returns 4 element tuple (incl __ stripped rpc opt)',
    undef, {user => 'auser'}, {test => 2}, {abc => 10}, '[{"user":"auser"},{"test":2}]');


done_testing();
