package Net::OpenStack::Client::API;

use strict;
use warnings;

use Net::OpenStack::API::Convert qw(process_args);
use Net::OpenStack::API::Magic qw(retrieve);

our $AUTOLOAD;

use Readonly;

Readonly our $API_METHOD_PREFIX => 'api_';

# This will add all AUTOLOADable functions as methods calls
# So only AUTOLOAD method with command name prefixed
# with api_, returns a C<$api_method> call

sub AUTOLOAD
{
    my $called = $AUTOLOAD;

    # Don't mess with garbage collection!
    return if $called =~ m{DESTROY};

    my $called_orig = $called;
    $called =~ s{^.*::}{};

    my ($self, @args) = @_;

    my ($cmd, $fail);
    my $api_pattern = "^${API_METHOD_PREFIX}([^_]+)_(.*)\$";
    if ($called =~ m/$api_pattern/) {
        ($cmd, $fail) = retrieve($1, $2, $self->{version});
    } else {
        # TODO:
        #    guess the service based on service + API version attribute
        $fail = "only $API_METHOD_PREFIX methods supported version $self->{version}";
    }

    if ($fail) {
        die "Unknown Net::OpenStack::API method: $called failed $fail (from original $called_orig)";
    } else {
        # Run the expected method.
        # AUTOLOAD with glob assignment and goto defines the autoloaded method
        # (so they are only autoloaded once when they are first called),
        # but that breaks inheritance.

        return $self->rpc(process_args($cmd, @args));
    }
}


1;
