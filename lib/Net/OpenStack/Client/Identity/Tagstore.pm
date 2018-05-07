package Net::OpenStack::Client::Identity::Tagstore;

use strict;
use warnings;

use parent qw(Net::OpenStack::Client::Base);

use Readonly;

# Maximum tags per project
#   identity v3.10 has 80
#   leave a few empty for possible future extensions
Readonly our $MAXTAGS => 70;

=head1 DESCRIPTION

Make a simple storage-like object that uses the Identity v3 interface
based on project tags as a backend.

It allows you to store a list of strings, that can be encoded/decoded.

=head1 Methods

=over

=item _initialize

=over

=item client

The C<Net::OpenStack::Client> instance to use.
(It will also be used as the reporter instance.)

=item project

The base project (name or id) that will store the tags.
The project has to exist.

All tags are stored in child projects with name C<<project_<counter>>>.

=back

=cut

sub _initialize
{
    my ($self, $client, $project) = @_;

    # Use the client as reporter
    $self->{log} = $client;

    $self->{cache} = undef;
    $self->{counter} = undef; # counter of last child project
    $self->{client} = $client;
    $self->{project} = $project;
    $self->{id} = $self->{client}->api_identity_get_id('project', $project);
    if (defined($self->{id})) {
        $self->debug("Tagstore for $project intialised (id $self->{id})");
    } else {
        $self->error("No project id found for project $project");
        return;
    };

    return 1;
}

=item _tag

Interact with the API.

=cut

sub _tag
{
    my ($self, $oper, $project_id, $tag) = @_;

    my $method = "api_identity_";
    my %opts = (
        project_id => $project_id,
        );
    $opts{tag} = $tag if defined($tag);
    if ($oper eq 'get') {
        $method .= 'tag' . (defined($tag) ? 's' : '');
    } else {
        $method .= "${oper}_tag";
    }

    return $self->{client}->$method(%opts);
}

=item fetch

Fetch data and populate the cache (and counter).
If the cache already exists, it doesn't do anything.
If you want to renew the cache, flush it first.

=cut

sub fetch
{
    my $self = shift;

    if ($self->{cache}) {
        $self->debug("fetch: tagstore cache exists, not doing anything");
    } else {
        $self->debug("fetching tagstore data cache");
        # gather all projects with parent_id $self->{project}
        my $resp = $self->{client}->api_identity_projects(parent_id => $self->{id});
        if ($resp) {
            # get all tags for each project and add them to the cache
            $self->{cache} = {};
            $self->{counter} = 0; # init with 0, no child project will ever have this counter
            foreach my $proj (@{$resp->result || []}) {
                if ($proj->{name} =~ m/_(\d+)$/) {
                    $self->{counter} = $1 if $1 > $self->{counter};
                } else {
                    # this is not really a problem, as the the counter is only used
                    # to garantee uniqueness in the naming of the child projects
                    $self->warn("Child project of $self->{project} with name $proj->{name} ".
                                "(id $proj->{id}) does not match counter regex");
                }

                foreach my $tag (@{$proj->{tags} || []}) {
                    $self->{cache}->{$tag} = $proj->{id};
                }
            }
        } else {
            $self->error("Can't get all projects with parent $self->{project} (id $self->{id})");
        }
    }
    return $self->{cache};
}

=item flush

Flushes the cache.

=cut

sub flush
{
    my ($self) = @_;

    $self->{cache} = undef;
    $self->{counter} = undef;
    $self->info('flushed tagstore cache and counter');
}

=item get

Return (cached) data for C<tag>.
If C<tag> is not defined, return all (cached) data as a hashref
(key is tag, value is projectid that holds the tag).
Data is fetched if cache is undefined.

=cut

sub get
{
    my ($self, $tag) = @_;

    $self->fetch();

    if (defined($tag)) {
        # no autovivification
        return exists($self->{cache}->{$tag}) ? $self->{cache}->{$tag} : undef;
    } else {
        return $self->{cache};
    };
}

=item add

Add element (to store and cache).

=cut

sub add
{
    my ($self, $data) = @_;
    $self->fetch();

    # look for projectid that has tagspace left
    my %count;
    foreach my $v (values %{$self->{cache}}) {
         $count{$v}++;
    };
    my @avail = grep {$count{$_} < $MAXTAGS} sort keys %count;

    my $pid;
    if (@avail) {
        $pid = $avail[0];
        $self->debug("using existing project $pid for $data");
    } else {
        # make new subproject
        my $counter = $self->{counter};
        $counter++; # used counter is never 0

        my $resp = $self->{client}->api_identity_add_project(name => "$self->{project}_$counter", parent_id => $self->{id});
        if ($resp && $resp->result) {
            $pid = $resp->result->{id};
            $self->{counter} = $counter;
        } else {
            $self->error("Failed to create child project for counter $counter");
        }
    }

    # add tag to project
    my $resp = $self->_tag('add', $pid, $data);
    if ($resp) {
        # add tag to cache
        $self->{cache}->{$data} = $pid;
        $self->debug("added $data to tagstore");
    } else {
        $self->error("Failed to add $data to tagstore (project child id $pid)");
    }
}

=item delete

Delete item (from store and cache) if it exists in the cache.

=cut

sub delete
{
    my ($self, $data) = @_;

    $self->fetch();

    my $pid = $self->{cache}->{$data};
    if (defined($pid)) {
        # delete tag from project
        my $resp = $self->_tag('delete', $pid, $data);
        if ($resp) {
            # delete tag from cache
            delete $self->{cache}->{$data};
            $self->debug("deleted $data from tagstore");
        } else {
            $self->error("Failed to delete $data from tagstore (project child id $pid)");
        }
    }
}


=back

=cut


1;
