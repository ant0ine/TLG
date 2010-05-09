use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 17 * 2;
use Test::Exception;

use TLG;
use TLG::Literal;

TLG->boot( name => 'test' );

my $value = 'this is a test value';

sub base_test {

    cmp_ok(TLG::Literal->role, 'eq', 'literal', 'role');

    # new
    my $literal = TLG::Literal->new($value);
    isa_ok($literal, 'TLG::Literal');
    ok($literal->key, 'has a key');
    ok(!$literal->is_stored, 'no stored flag');

    # store
    ok($literal->store, 'store');
    ok($literal->is_stored, 'stored flag');

    # load by key
    my $literal2 = TLG::Literal->load_by_key($literal->key);
    isa_ok($literal2, 'TLG::Literal');
    ok($literal2->key, 'has key');
    ok($literal2->is_stored, 'stored flag');
    cmp_ok($literal2->value, 'eq', $literal->value, 'load by key');

    # load by value
    my $literal3 = TLG::Literal->load_by_value($value);
    isa_ok($literal3, 'TLG::Literal');
    ok($literal3->key, 'has key');
    ok($literal3->is_stored, 'stored flag');
    cmp_ok($literal3->key, 'eq', $literal->key, 'load by value');

    # remove
    ok($literal->remove, 'remove');
    ok(!$literal->is_stored, 'no stored flag');

}

diag( 'cache disabled' );
$TLG::Literal::CACHE = 0;
ok(!TLG::Literal->cache_enabled, 'cache disabled');
base_test();

diag( 'cache enabled' );
$TLG::Literal::CACHE = 1;
ok(TLG::Literal->cache_enabled, 'cache enabled');
base_test();

