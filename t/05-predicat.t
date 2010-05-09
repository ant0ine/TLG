use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 16 * 2 + 2;

use TLG;
use TLG::Predicat;

TLG->boot( name => 'test' );

my $uri = 'http://example.com/'.time;

# TODO test scrub args

sub base_test {

    cmp_ok(TLG::Predicat->role, 'eq', 'predicat', 'role');

    # new
    my $predicat = TLG::Predicat->new($uri);
    isa_ok($predicat, 'TLG::Predicat');
    ok($predicat->key, 'has a key');
    ok(!$predicat->is_stored, 'no stored flag');

    # store
    ok($predicat->store, 'store');
    ok($predicat->is_stored, 'stored flag');

    # load by key
    my $predicat2 = TLG::Predicat->load_by_key($predicat->key);
    isa_ok($predicat2, 'TLG::Predicat');
    ok($predicat2->key, 'has key');
    ok($predicat2->is_stored, 'stored flag');
    cmp_ok($predicat2->uri, 'eq', $predicat->uri, 'load by key');

    # load by value
    my $predicat3 = TLG::Predicat->load_by_uri($uri);
    isa_ok($predicat3, 'TLG::Predicat');
    ok($predicat3->key, 'has key');
    ok($predicat3->is_stored, 'stored flag');
    cmp_ok($predicat3->key, 'eq', $predicat->key, 'load by uri');

    # remove
    ok($predicat->remove, 'remove');
    ok(!$predicat->is_stored, 'no stored flag');

}

diag( 'Cache disabled' );
$TLG::Predicat::CACHE = 0;
ok(!TLG::Predicat->cache_enabled, 'cache disabled');
base_test();

diag( 'Cache enabled' );
$TLG::Predicat::CACHE = 1;
ok(TLG::Predicat->cache_enabled, 'cache enabled');
base_test();
