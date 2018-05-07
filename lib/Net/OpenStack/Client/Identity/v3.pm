package Net::OpenStack::Client::Identity::v3;

use strict;
use warnings;

use Set::Scalar;
use Readonly;

use Net::OpenStack::Client::API::Convert qw(convert);
use Net::OpenStack::Client::Identity::Tagstore;
use Net::OpenStack::Client::Request qw(mkrequest);

Readonly my $IDREG => qr{[0-9a-z]{33}};

# This list is ordered:
#  Configuration of n-th item does not require
#  configuration of any items after that
Readonly our @SUPPORTED_OPERATIONS => qw(
    region
    domain
    project
    user
    role
    group
    service
    endpoint
);

Readonly my %PARENT_ATTR => {
    region => 'parent_region_id',
    project => 'parent_id',
};

# tagstore cache
# key is project id; value is instance
my $_tagstores = {};

=head1 Functions

=over

=item sort_parent

Sort according to parent attribute.

=cut

# Use toposort?
# see https://rosettacode.org/wiki/Topological_sort#Perl

sub sort_parent
{
    # We assume that an empty string or number 0 is not a valid/used region name
    # force strings, so we can do eq tests
    my $ra = $a->{name};
    my $rb = $b->{name};
    my $pra = $a->{parent} || '';
    my $prb = $b->{parent} || '';

    my $res;
    if ($pra eq $rb) {
        # b is parent of a: order b a
        $res = 1;
    } elsif ($prb eq $ra) {
        # a is parent of b: order a b
        $res = -1;
    } elsif ($pra && !$prb) {
        # a has parent, b does not: order b a
        $res = 1;
    } elsif ($prb && !$pra) {
        # b has parent, a does not: order a b
        $res = -1;
    } else {
        # does not matter, use alphabetical sort
        $res = $ra cmp $rb;
    }

    return $res;
}

=item sort_parents

Sort arrayref of C<names> with data from C<items> using parent C<attr>.

=cut

sub sort_parents
{
    my ($names, $items, $attr) = @_;

    # Assume the id is equal to the name of the region
    my @snames = sort sort_parent (map {{name => $_, parent => $items->{$_}->{$attr}}} @$names);
    return map {$_->{name}} @snames;
}

=item rest

Convenience wrapper for direct REST calls
for C<method>, C<operation> and options C<ropts>.

=cut

sub rest
{
    my ($self, $method, $operation, %ropts) = @_;
    my $defropts = {
        method => $method,
        version => 'v3',
        service => 'identity',
    };

    %ropts = (%$defropts, %ropts);

    # generate raw data
    $ropts{raw} = {$operation => delete $ropts{data}} if ($ropts{data});

    my $endpoint = "${operation}s/" . (delete $ropts{what} || '') . "?name=name";

    return $self->rest(mkrequest($endpoint, $method, %ropts));
};

=item get_id

Return the ID of an C<operation>.
If the name is an ID, return the ID without a lookup.
If the operation is 'region', return the name.

=cut

sub get_id
{
    my ($self, $operation, $name) = @_;

    # region has no id (or no name, whatever you like)
    return $name if ($name =~ m/$IDREG/ || $operation eq 'region');

    # GET the list for name
    my $resp = $self->api_identity_rest('GET', $operation, result => "/${operation}s", params => {name => $name});

    my $id;
    if ($resp) {
        my @ids = (map {$_->{id}} @{$resp->result || []});
        my $msg = "ID found for $operation with name $name";
        if (scalar @ids > 1) {
            # what? do not return anything
            $self->error("More than one $msg: @ids");
        } elsif (@ids) {
            $id = $ids[0];
            $self->debug("ID $id $msg");
        } else {
            $self->debug("No ID $msg");
        }
    };

    return $id;
}


=pod

=back

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

Returns a hasref with responses for the created items. The keys are
C<create>, C<update> and C<delete> and the values an arrayref of responses.

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

=item tagstore: use project tagstore to track synced ids.
If no filter is set, the tagstore is used to filter known ids
as existing tags in the tagstore.

=back

=cut

sub sync
{
    my ($self, $operation, $items, %opts) = @_;

    if (! grep {$_ eq $operation} @SUPPORTED_OPERATIONS) {
        $self->error("Unsupported operation $operation");
        return;
    }

    my $tagstore;
    if ($opts{tagstore}) {
        my $tagstore_proj = $opts{tagstore};
        if (!$_tagstores->{$tagstore_proj}) {
            my $tgst = Net::OpenStack::Client::Identity::Tagstore->new(
                $self,
                $tagstore_proj,
                );
            if ($tgst) {
                $_tagstores->{$tagstore_proj} = $tgst;
            } else {
                $self->error("sync: failed to create new tagstore for project $tagstore_proj");
                return;
            }
        }
        $tagstore = $_tagstores->{$tagstore_proj};
    }

    my $filter;
    if ($opts{filter}) {
        $filter = $opts{filter};
        if (ref($filter) ne 'CODE') {
            $self->error("Filter is not CODE");
            return;
        }
    } elsif ($tagstore) {
        $filter = sub {return $tagstore->get($_[0]->{id})};
    } else {
        $filter = sub {return 1};
    };

    # GET the list
    my $resp_list = $self->api_identity_rest('GET', $operation, result => "/${operation}s");

    my $nameattr = $operation eq 'region' ? 'id' : 'name';

    my $found = {
        map {$_->{$nameattr} => $_}
        grep {$filter->($_)}
        @{$resp_list->result || []}
    };

    my $existing = Set::Scalar->new(keys %$found);
    my $wanted = Set::Scalar->new(keys %$items);

    # Add default enabled=1 to all wanted operation
    foreach my $want (@$wanted) {
        $items->{$want}->{enabled} = convert(1, 'boolean') if ! exists($items->{$want}->{enabled});
    };

    # compare

    my @tocreate = sort @{$wanted - $existing};

    # regions and projects can have parent relations, so they need to be sorted accordingly
    # we only expect this to be important with creation, not for updates or deletes
    my $parentattr = $PARENT_ATTR{$operation};
    @tocreate = sort_parents(\@tocreate, $items, $parentattr) if $parentattr;

    my $res = {
        create => [],
        update => [],
        delete => [],
    };

    my $created = $self->api_identity_create($operation, \@tocreate, $items, $nameattr, $res) or return;
    # add to tagstore
    if ($tagstore) {
        foreach my $id (map {$_->{id}} @{$res->{create}}) {
            $tagstore->add($id);
        }
    }

    my @checkupdate = sort @{$wanted * $existing};
    $self->api_identity_update($operation, \@checkupdate, $found, $items, $res) or return;
    # no tagstore operations?

    my @toremove = sort @{$existing - $wanted};
    $self->api_identity_remove($operation, \@toremove, $found, \%opts, $res) or return;

    # remove from tagstore
    if ($tagstore) {
        foreach my $id (map {$_->{id}} @{$res->{delete}}) {
            $tagstore->delete($id);
        }
    }

    return $res;
}

=item create

Create C<operation> items in arrayref C<tocreate> from configured C<items>
(using name attriute C<nameattr>),
with result hashref C<res>. C<res> is updated in place.

=cut

sub create
{
    my ($self, $operation, $tocreate, $items, $nameattr, $res) = @_;

    my @tocreate = @$tocreate;

    if (@tocreate) {
        $self->info("Creating ${operation}s: @tocreate");
        foreach my $name (@tocreate) {
            # POST to create
            my $new = $items->{$name};
            $new->{$nameattr} = $name;
            my $resp = $self->api_identity_rest('POST', $operation, data => $new);
            push(@{$res->{create}}, $resp->result("/$operation"));
        }
    } else {
        $self->debug("No ${operation}s to create");
    }

    return 1;
}

=item update

Update C<operation> items in arrayref C<checkupdate> from C<found> items
with configured C<items>, with result hashref C<res>.
C<res> is updated in place.

=cut

sub update
{
    my ($self, $operation, $checkupdate, $found, $items, $res) = @_;

    my @checkupdate = @$checkupdate;

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
                my $resp = $self->api_identity_rest('PATCH', $operation, what => $found->{$name}->{id}, data => $update);
                push(@{$res->{update}}, $resp->result("/$operation"));
            }
        }
        $self->info(@toupdate ? "Updated existing ${operation}s: @toupdate" : "No existing ${operation}s updated");
    } else {
        $self->debug("No existing ${operation}s to update");
    }

    return 1;
}

=item remove

Remove (or disable) C<operation> items in arrayref C<toremove> from C<found>
existing items, with options C<opts> (for C<delete> and C<ignore>)
and result hashref C<res>. C<res> is updated in place.

When C<ignore> option is true, nothing will happen.
When C<delete> is true, items will be delete; when items will be disabled.

=cut

sub remove
{
    my ($self, $operation, $toremove, $found, $opts, $res) = @_;

    my @toremove = @$toremove;

    my $dowhat = $opts->{delete} ? 'delet' : 'disabl';

    if (@toremove) {
        if ($opts->{ignore}) {
            $self->info("Ignoring existing ${operation}s (instead of ${dowhat}ing): @toremove");
        } else {
            $self->info(ucfirst($dowhat)."ing existing ${operation}s: @toremove");
            foreach my $name (@toremove) {
                my $resp;
                if ($opts->{delete}) {
                    # DELETE to delete
                    $resp = $self->api_identity_rest('DELETE', $operation, what => $found->{$name}->{id});
                } else {
                    # PATCH to disable
                    # do not disable if already disabled
                    if ($found->{$name}->{enabled}) {
                        $resp = $self->api_identity_rest('PATCH', $operation,
                                                         what => $found->{$name}->{id},
                                                         data => {enabled => convert(0, 'boolean')});
                    } else {
                        $self->debug("Not disabling already disabled ".
                                     "$operation $name (id ".$found->{$name}->{id}.")");
                    }
                }
                push(@{$res->{delete}}, $resp->result("/$operation")) if defined($resp);
            }
        }
    } else {
        $self->debug("No existing ${operation}s to ${dowhat}e");
    }

    return 1;
}


=pod

=back

=cut

1;
