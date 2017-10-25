package Net::OpenStack::Client::Auth;

use strict;
use warnings;

use Readonly;

Readonly my $OPENRC_REQUIRED => [qw(username password auth_url)];

Readonly my %OPENRC_DEFAULT => {
    identity_api_version => 3,
    project_domain_name => 'Default',
    user_domain_name => 'Default',
};

Readonly my $DEFAULT_ENDPOINT_INTERFACE_PREFERENCE => [qw(admin internal public)];

# read openrc file and extract the variables in hashref
sub _parse_openrc
{
    my ($self, $fn) = @_;

    my $res;
    if (open(my $fh, $fn)) {
        while (<$fh>) {
            chomp;
            if (m/^\s*(?:export\s+)(\w+)\s*=\s*(?:'|")?(.+)(?:'|")?\s*$/) {
                $res->{$1} = $2;
            }
        }
        close($fh);
        $self->debug("Parsed openrc file $fn: found variables ".join(',', sort keys %$res));
    } else {
        $self->error("Failed to openrc file $fn: $!");
    }
    return $res;
}


=head1 methods

=over

=item get_openrc

Given variable name, get OS_<uppercase variable name> from hashref C<data>.

Use default from OPENRC_DEFAULT, if none exists.
If none exists, and no default and in OPENRC_REQUIRED, report error.

=cut

sub get_openrc
{
    my ($self, $var, $data) = @_;

    my $full_var = "OS_".uc($var);
    if (exists($data->{$full_var})) {
        return $data->{$full_var};
    } elsif (exists($OPENRC_DEFAULT{$full_var})) {
        return $OPENRC_DEFAULT{$full_var};
    } else {
        my $method = (grep {$_ eq $var} @$OPENRC_REQUIRED) ? 'error' : 'debug';
        $self->$method("openrc required variable $var ($full_var) not found");
    }

    return;
}


=item login

Login and obtain token for further authentication.

Options:

=over

=item openrc: openrc file to parse to extract the login details.


=back

=cut

sub login
{
    my ($self, %opts) = @_;

    my $resp;
    if ($opts{openrc}) {
        my $openrc = $self->_parse_openrc($opts{openrc});

        my $os = sub {return $self->get_openrc(shift, $openrc)};

        my $version = version->new('v'.&$os('identity_api_version'));
        $self->{versions}->{identity} = $version;
        if ($self->{versions}->{identity} == 3) {
            $self->{services}->{identity} = &$os('auth_url');
            $resp = $self->api_identity_tokens(
                methods => ['password'],
                user_name => &$os('username'),
                user_domain_name => &$os('project_domain_name'),
                password => &$os('password'),
                project_domain_name => &$os('project_domain_name'),
                project_name => &$os('project_name'),
                );
            # token in result attr
            $self->{token} = $resp->result;

            # parse the catalog
            $self->services_from_catalog($resp->{data}->{token}->{catalog});
        } else {
            $self->error("Only identity v3 supported for now");
            return;
        }
    } else {
        $self->error("Only openrc supported for now");
        return;
    }

    return 1;
}

=item services_from_catalog

Parse the catalog arrayref, and build up the services attribute

=cut

sub services_from_catalog
{
    my ($self, $catalog) = @_;

    # TODO: allow to change this
    my @pref_intfs = (@$DEFAULT_ENDPOINT_INTERFACE_PREFERENCE);

    foreach my $service (@$catalog) {
        my $type = $service->{type};
        my $endpoint;
        foreach my $intf (@pref_intfs) {
            my @epts = grep {$_->{interface} eq $intf} @{$service->{endpoints}};
            if (@epts) {
                $endpoint = $epts[0]->{url};
                last;
            }
        }
        if ($endpoint) {
            $self->{services}->{$type} = $endpoint;
            $self->debug("Added endpoint $endpoint for service $type");
        } else {
            $self->error("No endpoint for service $type using preferred interfaces ".join(",", @pref_intfs));
        }
    }
}

=pod

=back

=cut

1;
