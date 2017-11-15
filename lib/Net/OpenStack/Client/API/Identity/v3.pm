#
# This module is generated with gen.pl
# Do not modify.
#

package Net::OpenStack::Client::API::Identity::v3;

use strict;
use warnings;

use version;
our $VERSION = version->new("v3");

use Readonly;

Readonly our $API_DATA => {
    
    add_domain => {
        method => 'POST',
        endpoint => '/domains',
        
        options => {    
            'description' => {'path' => ['domain','description'],'type' => 'string'},
            'enabled' => {'path' => ['domain','enabled'],'type' => 'boolean'},
            'name' => {'path' => ['domain','name'],'type' => 'string'},
        },
    
    },
    
    catalog => {
        method => 'GET',
        endpoint => '/auth/catalog',
        
        
        result => '/catalog',
    
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
            'methods' => {'islist' => 1,'path' => ['auth','identity','methods'],'type' => 'string'},
            'password' => {'path' => ['auth','identity','password','user','password'],'type' => 'string'},
            'project_domain_name' => {'path' => ['auth','scope','project','domain','name'],'type' => 'string'},
            'project_name' => {'path' => ['auth','scope','project','name'],'type' => 'string'},
            'user_domain_name' => {'path' => ['auth','identity','password','user','domain','name'],'type' => 'string'},
            'user_name' => {'path' => ['auth','identity','password','user','name'],'type' => 'string'},
        },
        result => 'X-Subject-Token',
    
    },

};

1;
