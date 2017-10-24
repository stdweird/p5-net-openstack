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
            'description' => {'path' => ['domain','description'],'type' => 'string'},
            'enabled' => {'path' => ['domain','enabled'],'type' => 'boolean'},
            'name' => {'path' => ['domain','name'],'type' => 'string'},
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
    
    tokens => {
        method => 'POST',
        endpoint => '/auth/tokens',
        
        options => {    
            'domain_name' => {'path' => ['auth','identity','password','user','domain','name'],'type' => 'string'},
            'methods' => {'islist' => 1,'path' => ['auth','identity','methods'],'type' => 'string'},
            'password' => {'path' => ['auth','identity','password','user','password'],'type' => 'string'},
            'user_name' => {'path' => ['auth','identity','password','user','name'],'type' => 'string'},
        },
    },

};

1;