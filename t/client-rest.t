use strict;
use warnings;

use Test::More;
use JSON::XS;
use Net::OpenStack::Client::REST;

# paged metadata example
my $paged_json = <<EOF;
{
    "server": {
        "id": "52415800-8b69-11e0-9b19-734f6f006e54",
        "name": "Elastic",
        "metadata": {
            "Version": "1.3",
            "ServiceType": "Bronze"
        },
        "metadata_links": [
            {
                "rel": "next",
                "href": "https://servers.api.openstack.org/v2.1/servers/fc55acf4-3398-447b-8ef9-72a42086d775/meta?marker=ServiceType"
            }
        ],
        "links": [
            {
                "rel": "self",
                "href": "https://servers.api.openstack.org/v2.1/servers/fc55acf4-3398-447b-8ef9-72a42086d775"
            }
        ]
    }
}
EOF


=head1 _page_paths

=cut

my $response = {a => {
    b => {
        c => [1],
        c_links => [
            {rel => 'next', href => 'some/url'},
            {rel => 'previous', href => 'some/prevurl'},
        ],
    },
    d => ['a', 'b'],
    d_links => [{rel=> 'next', href => 'some/otherurl'}],
    e => ['a', 'b'],
    e_links => [{rel=> 'self', href => 'some/yetotherurl'}],
}};
my @paths = Net::OpenStack::Client::REST::_page_paths($response);
is_deeply(\@paths, [
              [[qw(a b c)], 'some/url'], 
              [[qw(a d)], 'some/otherurl']
          ], "_page_paths discovers all paths with links to next for pagination");


done_testing;
