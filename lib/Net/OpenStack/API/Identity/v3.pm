#
# This module is generated with gen.pl
# Do not modify.
#

package Net::OpenStack::API::Identity::v3;

use strict;
use warnings;

use version;
our $VERSION = version->new("v3");

use Readonly;

Readonly our %API_DATA => {
    
    add_domain => {
        method => 'POST',
        endpoint => '/domains',
        
        options => {    
            'description' => {'type' => 'string','path' => ['domain','description']},
            'enabled' => {'path' => ['domain','enabled'],'type' => 'boolean'},
            'name' => {'type' => 'string','path' => ['domain','name']},
        },
    },
    
    domain => {
        method => 'GET',
        endpoint => '/domains/{domain_id}',
        templates => ['domain_id'],
        
    
    },
    
    domains => {
        method => 'GET',
        endpoint => '/domains',
        
    
    },

};

1;
