package Net::OpenStack::Client;

use strict;
use warnings;

use parent qw(
    Net::OpenStack::Client::Base
    Net::OpenStack::Client::REST
    Net::OpenStack::Client::API
);

=head1 NAME

Net::OpenStack::Client

=head2 Public methods

=over

=item new

Options

=over

=item log

An instance that can be used for logging (with error/warn/info/debug methods)
(e.g. L<LOG::Log4perl>).

=item debugapi

When true, log the request and response body and headers with debug.

=back

=cut

# return 1 on success
sub _initialize
{
    my ($self, %opts) = @_;

    $self->{log} = delete $opts{log};
    $self->{debugapi} = delete $opts{debugapi};

    $self->_new_client();

    return 1;
}

=pod

=back

=cut

1;
