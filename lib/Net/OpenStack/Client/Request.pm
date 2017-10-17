package Net::OpenStack::Client::Request;

use strict;
use warnings;

use base qw(Exporter);
use Readonly;

Readonly our @SUPPORTED_METHODS => qw(DELETE GET PATCH POST PUT);
Readonly our @METHODS_REQUIRE_OPTIONS => qw(PATCH POST PUT);

our @EXPORT = qw(mkrequest);
our @EXPORT_OK = qw(parse_endpoint @SUPPORTED_METHODS @METHODS_REQUIRE_OPTIONS);

use overload bool => '_boolean';

=head1 NAME

Net::OpenStack::Client::Request is an request class for Net::OpenStack.

Boolean logic is overloaded using C<_boolean> method (as inverse of C<is_error>).

=head2 Public functions

=over

=item mkrequest

A C<Net::OpenStack::Client::Request> factory

=cut

sub mkrequest
{
    return Net::OpenStack::Client::Request->new(@_);
}

=item parse_endpoint

Parse C<endpoint> and look for templates.

Return arrayref of template names.

=cut

sub parse_endpoint
{
    my ($endpoint) = @_;

    # List of key names that have to be passed
    my @templates;
    foreach my $template ($endpoint =~ m#\{([^/]+)}#g) {
        # only add once; order is not that relevant
        push(@templates, $template) if (!grep {$_ eq $template} @templates);
    };

    return \@templates;
}


=pod

=back

=head2 Public methods

=over

=item new

Create new request instance from options for command C<endpoint>
and REST HTTP C<method>.

The C<endpoint> is the URL to use (can be templated with C<tpls>)

Options

=over

=item tpls: template names and values

=item opts: optional arguments

=item error: an error (no default)

=item id: id (no default)

=back

=cut

sub new
{
    my ($this, $endpoint, $method, %opts) = @_;
    my $class = ref($this) || $this;
    my $self = {
        endpoint => $endpoint,

        tpls => $opts{tpls} || {},
        opts => $opts{opts} || {},

        rpc => $opts{rpc} || {}, # options for rpc
        post => $opts{post} || {}, # options for post

        error => $opts{error}, # no default
        id => $opts{id}, # no default
    };

    if (grep {$method eq $_} @SUPPORTED_METHODS) {
        $self->{method} = $method;
    } else {
        $self->{error} = "Unsupported method $method";
    }

    bless $self, $class;

    return $self;
};

=item endpoint

Parses the endpoint attribute, look for any templates, and replace them with values
from C<tpls> attribute hashref.

The data can contain more keys than what is required
for templating, those keys and their values will be ignored.

This does not modify the endpoint attribute.

Return templated endpoint on success or undef on failure.

=cut

sub endpoint
{
    my ($self) = @_;

    # reset error attribute
    $self->{error} = undef;

    # Do not modify the endpoint attribute
    my $endpoint = $self->{endpoint};

    my $templates = parse_endpoint($self->{endpoint});
    foreach my $template (@$templates) {
        my $pattern = '\{' . $template . '\}';
        if (exists($self->{tpls}->{$template})) {
            $endpoint =~ s#$pattern#$self->{tpls}->{$template}#g;
        } else {
            $self->{error} = "Missing template $template data to replace endpoint $self->{endpoint}";
            return;
        }
    }

    return $endpoint;
}



=item is_error

Test if this is an error or not (based on error attribute).

=cut

sub is_error
{
    my $self = shift;
    return $self->{error} ? 1 : 0;
}

# Overloaded boolean, inverse of is_error
sub _boolean
{
    my $self = shift;
    return ! $self->is_error();
}

=pod

=back

=cut

1;
