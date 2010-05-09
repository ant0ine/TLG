use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 3 * 27;
use Test::Exception;

use TLG;
use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;
use TLG::Triplet;
use TLG::Namespace;
use TLG::Unmutable;

TLG::Namespace->register( ns => 'http://my.namespace.org/' );

TLG->boot(name => 'test');

my $note = {
    uri => 'http://example.com/#'.time,
    title => 'My title '.time,
    content => 'the content',
    score => 2,
    date => time,
};

sub lock_test {

    my $ls = TLG::LockSet->new;
    my $triplet = TLG::Triplet->new($note->{uri}, [ ns => 'title' ], $note->{title}, $ls);
    isa_ok($triplet, 'TLG::Triplet');
    ok($ls->locked($triplet->lock_key), 'locked');
    ok($ls->locked($triplet->subject->lock_key), 'locked');
    ok($ls->locked($triplet->predicat->lock_key), 'locked');
    ok($ls->locked($triplet->object->lock_key), 'locked');
    cmp_ok($ls->lock_count, '==', 4, ' 4 locks');
    ok($triplet->store, 'store');

    my $key = $triplet->key;

    my $ls2 = TLG::LockSet->new;
    throws_ok { TLG::Triplet->load_by_key($key, $ls2) }
        qr/taken/, 'resource taken';

    $ls = undef; # release the lock
    
    my $ls4 = TLG::LockSet->new;
    my ($triplet4) =  @{ TLG::Triplet->query( undef, 'ns:title', $note->{title}, $ls4 ) };
    isa_ok($triplet4, 'TLG::Triplet');
    ok($ls4->locked($triplet4->lock_key), 'locked');
    ok($ls4->locked($triplet4->subject->lock_key), 'locked');
    ok($ls4->locked($triplet4->predicat->lock_key), 'locked');
    ok($ls4->locked($triplet4->object->lock_key), 'locked');
    cmp_ok($ls4->lock_count, '==', 4, ' 4 locks');
    
    $ls4 = undef; # release the lock

    my $ls3 = TLG::LockSet->new;
    my $triplet3 = TLG::Triplet->load_by_key($key, $ls3);
    isa_ok($triplet3, 'TLG::Triplet');
    ok($ls3->locked($triplet3->lock_key), 'locked');
    ok($ls3->locked($triplet3->subject->lock_key), 'locked');
    ok($ls3->locked($triplet3->predicat->lock_key), 'locked');
    ok($ls3->locked($triplet3->object->lock_key), 'locked');
    cmp_ok($ls3->lock_count, '==', 4, ' 4 locks');

    $ls3 = undef;

    diag('now with the unmutables');
    TLG::Unmutable->set_unmutable(class => 'TLG::Predicat');
    $ls4 = TLG::LockSet->new;
    $triplet4 = TLG::Triplet->load_by_key($key, $ls4);
    isa_ok($triplet4, 'TLG::Triplet');
    ok($ls4->locked($triplet4->lock_key), 'locked');
    ok($ls4->locked($triplet4->subject->lock_key), 'locked');
    ok(!$ls4->locked($triplet4->predicat->lock_key), 'not locked');
    ok($ls4->locked($triplet4->object->lock_key), 'locked');
    cmp_ok($ls4->lock_count, '==', 3, '3 locks');
    ok($triplet4->remove, 'remove');
    TLG::Unmutable->clear_unmutables;
}

diag( 'cache disabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
lock_test();

diag( 'triplet cache enabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 1;
lock_test();

diag( 'full cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
lock_test();
