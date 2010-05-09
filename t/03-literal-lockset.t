use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 7 * 2 + 10 * 2;
use Test::Exception;

use TLG;
use TLG::Literal;

TLG->boot( name => 'test' );

my $value = 'this is a test value';

sub race_test {

    # prove the race problem
    my $literal = TLG::Literal->new($value);
    isa_ok($literal, 'TLG::Literal');
    ok($literal->store, 'store');

    my $literal2 = TLG::Literal->load_by_key($literal->key);
    isa_ok($literal2, 'TLG::Literal');

    ok($literal->remove, 'remove');

    ok($literal2->store, 'store');

    ok(!TLG::Literal->load_by_key($literal->key), 'literal doesn\'t exist');

}

diag( 'cache disabled' );
$TLG::Literal::CACHE = 0;
ok(!TLG::Literal->cache_enabled, 'cache disabled');
race_test();

diag( 'cache enabled' );
$TLG::Literal::CACHE = 1;
ok(TLG::Literal->cache_enabled, 'cache enabled');
race_test();

sub lock_test {

    my $ls = TLG::LockSet->new;
    my $literal = TLG::Literal->new($value, $ls);
    isa_ok($literal, 'TLG::Literal');
    ok($ls->locked($literal->lock_key), 'locked');
    cmp_ok($ls->lock_count, '==', 1, '1 lock');
    ok($literal->store, 'store');

    my $key = $literal->key;

    my $ls2 = TLG::LockSet->new;
    throws_ok { TLG::Literal->load_by_key($key, $ls2) }
        qr/taken/, 'resource taken';

    throws_ok { TLG::Literal->load_by_value($value, $ls2) }
        qr/taken/, 'resource taken';
    
    $ls = undef; # release the lock

    my $ls3 = TLG::LockSet->new;
    my $literal3 = TLG::Literal->load_by_key($key, $ls3);
    isa_ok($literal3, 'TLG::Literal');
    ok($ls3->locked($literal3->lock_key), 'locked');
    ok($literal3->remove, 'remove');

}

diag( 'cache disabled' );
$TLG::Literal::CACHE = 0;
ok(!TLG::Literal->cache_enabled, 'cache disabled');
lock_test();

diag( 'cache enabled' );
$TLG::Literal::CACHE = 1;
ok(TLG::Literal->cache_enabled, 'cache enabled');
lock_test();
