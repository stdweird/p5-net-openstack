package Net::OpenStack::API::Magic;

use strict;
use warnings;

use Module::Load;
use Net::OpenStack::Client::Request qw(@SUPPORTED_METHODS @METHODS_REQUIRE_OPTIONS);

use Readonly;
use version;

use base qw(Exporter);

our @EXPORT_OK = qw(retrieve version);

# hashref to store cached command data
my $cmd_cache = {};

=head2 Public functions

=over

=item flush_cache

Reset the cache

=cut

sub flush_cache
{
    $cmd_cache = {};
    return $cmd_cache;
}

=item cache

Given C<data> command hashref,
cache and return the relevant (filtered) command data.

=cut

sub cache
{
    my ($data) = @_;

    my $service = $data->{service};
    my $name = $data->{name};

    $cmd_cache->{$service}->{$name} = $data;

    return $data;
}

=item retrieve

Retrieve the command data for service C<service>, name C<name>
and version C<version>.

Returns the tuple with cache command hashref and undef errormessage on SUCCESS,
an emptyhashref and actual errormessage otherwise.
If the command is already in cache, returns the cached version
(and undef errormessage).

=cut

sub retrieve
{
    my ($service, $name, $version) = @_;

    # Return already cached data
    return ($cmd_cache->{$service}->{$name}, undef) if defined(($cmd_cache->{$service} || {})->{$name});

    if (ref($version) ne 'version') {
        $version = "v$version" if $version !~ m/^v/;
        $version = version->new($version);
    }

    my $err_prefix = "retrieve name $name for service $service version $version failed:";

    my $versionpackagename = "$version";
    $versionpackagename =~ s/[.]/DOT/g; # cannot have a . in the package name

    my $servicepackagename = ucfirst($service);
    my $package = "Net::OpenStack::API::${servicepackagename}::${versionpackagename}";

    local $@;
    eval {
        load $package;
    };
    if ($@) {
        return {}, "$err_prefix no module $package: $@";
    }

    my $varname = "${package}::API_DATA";
    my $apidata;
    eval {
        no strict 'refs';
        $apidata = ${$varname};
        use strict 'refs';
    };
    if ($@) {
        return {}, "$err_prefix somthing went wrong while looking for variable $varname: $@";
    } elsif (!defined $apidata) {
        return {}, "$err_prefix no variable $varname";
    } elsif (ref($apidata) ne 'HASH') {
        return {}, "$err_prefix variable $varname not a hash (got ".ref($apidata).")";
    };

    my $data = $apidata->{$name};
    if (! $data) {
        return {}, "$err_prefix no API data";
    }

    # data is a hashref
    # sanity check
    if (!exists($data->{endpoint})) {
        return {}, "$err_prefix data should at least contain the endpoint";
    }

    if (!exists($data->{method})) {
        return {}, "$err_prefix data should at least contain the method";
    }

    my $method = $data->{method};
    if (!grep {$_ eq $method} @SUPPORTED_METHODS) {
        return {}, "$err_prefix method $method is not supported";
    }
    if ((grep {$method eq $_} @METHODS_REQUIRE_OPTIONS) && !exists($data->{options})) {
        return {}, "$err_prefix data should contain options for method $method";
    }

    my $result = {
        name => $name, # human readable function/method name
        method => $method, # HTTP method
        service => $service,
        endpoint => $data->{endpoint},
        version => $version,
    };

    $result->{result} = $data->{result} if defined($data->{result});

    foreach my $k (qw(templates options)) {
        $result->{$k} = $data->{$k} if exists($data->{$k});
    }

    return cache($result), undef;
}


=pod

=back

=cut


1;
