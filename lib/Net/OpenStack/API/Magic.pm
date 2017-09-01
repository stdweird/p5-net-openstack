package Net::OpenStack::API::Magic;

use strict;
use warnings;

use Module::Load;
use Net::OpenStack::Client::Request qw(parse_endpoint @SUPPORTED_METHODS);

use Readonly;

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

    my $err_prefix = "retrieve name $name for service $service version $version failed:";

    my $versionpackagename = $version;
    $versionpackagename =~ s/[.]/DOT/g; # cannot have a . in the package name

    my $package = "Net::OpenStack::API::${service}::${versionpackagename}";

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
    if ($@ || !defined $apidata || ref($apidata) ne 'HASH') {
        return {}, "$err_prefix no variable $varname".($@ ? ": $@" : "");
    };

    my $data = $apidata->{$name};
    if (! $data) {
        return {}, "$err_prefix no API data";
    }

    # data is an arrayref
    # first element is method (GET/PUT/...)
    # 2nd element is endpoint URL -> command endpoint
    #    all template variables ({name}) to the command
    # remainder are options for JSON data
    #    start with '?' : optional -> required attr
    #    end with %type : type to use (for conversion) -> type attr
    my @data = @$data;

    if (scalar(@data) < 2) {
        return {}, "$err_prefix data should at least contain the method and URL, got @data";
    }

    my $method = shift @data;
    if (!grep {$_ eq $method} @SUPPORTED_METHODS) {
        return {}, "$err_prefix method $method is not supported";
    }

    my $endpoint = shift @data;
    my $result = {
        name => $name, # human readable function/method name
        method => $method, # HTTP method
        service => $service,
        endpoint => $endpoint,
        templates => parse_endpoint($endpoint),
    };

    my @opts;
    foreach my $attr (@data) {
        if ($attr =~ m/^([?])?(.*?)(?:%(\w+))?$/) {
            push(@opts, {
                name => $2,
                required => defined($1) ? 0 : 1,
                type => $3 || 'str', # default string type
            });
        }
    };
    $result->{options} = \@opts if @opts;

    return cache($result), undef;
}


=pod

=back

=cut


1;
