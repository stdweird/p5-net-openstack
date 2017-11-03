package Net::OpenStack::Client::Identity::v3;

use strict;
use warnings;

use Set::Scalar;
use Readonly;

use Net::OpenStack::Client::Request qw(mkrequest);

Readonly my @SUPPORTED_OPERATIONS => qw(
    user group
    service endpoint
    project domain
    );

=head1 Methods

=over

=item sync

For an C<operation> (like C<user>, C<group>, C<service>, ...),
given an hashref of C<items> (key is the name),
compare it with all existing items:

=over

=item Non-existing ones are added/created

=item Existing ones are possibly updated

=item Existing ones that are not requested are disbaled

=back

Following options are supported:

=over

=item filter: a function to filter the existing items.
Return a true value to keep the existing item (false will ignore it).
By default, all existing items are considered.

=item delete: when the delete option is true, existing items that are
not in the C<items> hashref, will be deleted (instead of disabled).

=item keep: when the keep option is true, existing items that are
not in the C<items> hashref are ignored.
This precedes any value of C<delete> option.

=back

=cut

sub sync
{
    my ($self, $operation, $items, %opts) = @_;

    if (! grep {$_ eq $operation} @SUPPORTED_OPERATIONS) {
        $self->error("Unsupported operation $operation");
        return;
    }

    my $rest = sub {
        my ($method, %ropts) = @_;
        my $defropts = {
            method => $method,
            version => 'v3',
            service => 'identity',
        };

        %ropts = (%$defropts, %ropts);

        # generate raw data
        $ropts{raw} = {$operation => delete $ropts{data}} if ($ropts{data});

        my $endpoint = "${operation}s/" . (delete $ropts{what} || '');

        return $self->rest(mkrequest($endpoint, $method, %ropts));
    };

    # GET the list
    my $resp_list = &$rest('GET', result => "/${operation}s");

    my $found = {
        map {$_->{name} => $_}
        grep {$opts{filter} ? $opts{filter}->($_) : 1}
        @{$resp_list->result || []}
    };

    my $existing = Set::Scalar->new(keys %$found);
    my $wanted = Set::Scalar->new(keys %$items);

    # Add default enabled=1 to all wanted operation
    foreach my $want (@$wanted) {
        $items->{$want}->{enabled} = 1 if ! exists($items->{$want}->{enabled});
    };

    # compare

    my @tocreate = sort @{$wanted - $existing};
    if (@tocreate) {
        $self->info("Creating ${operation}s: @tocreate");
        foreach my $name (@tocreate) {
            # POST to create
            my $new = $items->{$name};
            $new->{name} = $name;
            my $resp = &$rest('POST', data => $new);
        }
    } else {
        $self->debug("No ${operation}s to create");
    }

    my @checkupdate = sort @{$wanted * $existing};
    if (@checkupdate) {
        $self->info("Possibly updating existing ${operation}s: @checkupdate");
        my @toupdate;
        foreach my $name (@checkupdate) {
            # anything to update?
            my $update;
            foreach my $attr (sort keys %{$items->{$name}}) {
                my $wa = $items->{$name}->{$attr};
                my $fo = $found->{$name}->{$attr};
                my $action = $attr eq 'enabled' ? ($wa xor $fo): ($wa ne $fo);
                # hmmm, how to keep this JSON safe?
                $update->{$attr} = $wa if $action;
            }
            if (scalar keys %$update) {
                push(@toupdate, $name);
                my $resp = &$rest('PATCH', what => $found->{$name}->{id}, data => $update);
            }
        }
        $self->info(@toupdate ? "Updated existing ${operation}s: @toupdate" : "No existing ${operation}s updated");
    } else {
        $self->debug("No existing ${operation}s to update");
    }

    my @toremove = sort @{$existing - $wanted};
    my $dowhat = $opts{delete} ? 'delet' : 'disabl';

    if (@toremove) {
        if ($opts{ignore}) {
            $self->info("Ignoring existing ${operation}s (instead of ${dowhat}ing): @toremove");
        } else {
            $self->info(ucfirst($dowhat)."ing existing ${operation}s: @toremove");
            foreach my $name (@toremove) {
                if ($opts{delete}) {
                    # DELETE to delete
                    my $resp = &$rest('DELETE', what => $found->{$name}->{id});
                } else {
                    # PATCH to disable
                    # do not disable if already disabled
                    my $resp = &$rest('PATCH', what => $found->{$name}->{id}, data => {enabled => 0})
                        if $found->{$name}->{enabled};
                }
            }
        }
    } else {
        $self->debug("No existing ${operation}s to ${dowhat}e");
    }
}

=pod

=back

=cut

1;
