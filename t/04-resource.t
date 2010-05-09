use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 17 * 2;

use TLG;
use TLG::Resource;

TLG->boot( name => 'test' );

my $uri = 'http://example.com/'.time;

sub base_test {
    
    cmp_ok(TLG::Resource->role, 'eq', 'resource', 'role');
    
    # new
    my $resource = TLG::Resource->new($uri);
    isa_ok($resource, 'TLG::Resource');
    ok($resource->key, 'has a key');
    ok(!$resource->is_stored, 'not stored flag');

    # store
    ok($resource->store, 'store');
    ok($resource->is_stored, 'stored');

    # load by key
    my $resource2 = TLG::Resource->load_by_key($resource->key);
    isa_ok($resource2, 'TLG::Resource');
    ok($resource2->key, 'has key');
    ok($resource2->is_stored, 'stored flag');
    cmp_ok($resource2->uri, 'eq', $resource->uri, 'load by key');

    # load by uri
    my $resource3 = TLG::Resource->load_by_uri($uri);
    isa_ok($resource3, 'TLG::Resource');
    ok($resource3->key, 'has key');
    ok($resource3->is_stored, 'stored flag');
    cmp_ok($resource3->key, 'eq', $resource->key, 'load by uri');

    # TODO test blank node

    # remove
    ok($resource->remove, 'remove');
    ok(!$resource->is_stored, 'not stored flag');
}

diag( 'Cache disabled' );
$TLG::Resource::CACHE = 0;
ok(!TLG::Resource->cache_enabled, 'cache disabled');
base_test();

diag( 'Cache enabled' );
$TLG::Resource::CACHE = 1;
ok(TLG::Resource->cache_enabled, 'cache enabled');
base_test();
