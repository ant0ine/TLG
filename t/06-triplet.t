use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 3 * 47;
use Test::Exception;

use TLG;
use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;
use TLG::Triplet;
use TLG::Namespace;

TLG::Namespace->register( ns => 'http://my.namespace.org/' );

TLG->boot(name => 'test');

my $note = {
    uri => 'http://example.com/#'.time,
    title => 'My title '.time,
    content => 'the content',
    score => 2,
    date => time,
};

sub base_test {
    diag('triplet API level 1');

    my $subject = TLG::Resource->new($note->{uri});
    isa_ok($subject, 'TLG::Resource');

    my $predicat = TLG::Predicat->new(ns => 'title');
    isa_ok($predicat, 'TLG::Predicat');

    my $object = TLG::Literal->new($note->{title});
    isa_ok($object, 'TLG::Literal');

    my $triplet = TLG::Triplet->new($subject, $predicat, $object);
    isa_ok($triplet, 'TLG::Triplet');

    ok($triplet->store, 'title');

    $predicat = TLG::Predicat->new(ns => 'content');
    isa_ok($subject, 'TLG::Resource');

    $object = TLG::Literal->new($note->{content});
    isa_ok($object, 'TLG::Literal');

    $triplet = TLG::Triplet->new($subject, $predicat, $object);
    isa_ok($triplet, 'TLG::Triplet');

    ok($triplet->store, 'content');

    $predicat = TLG::Predicat->new(ns => 'score');
    isa_ok($subject, 'TLG::Resource');

    $triplet = TLG::Triplet->new($subject, $predicat, $note->{score});
    isa_ok($triplet, 'TLG::Triplet');
    cmp_ok($triplet->object, '==', $note->{score}, 'num');

    ok($triplet->store, 'score');

    diag('triplet API level 2');

    my $title = TLG::Triplet->new($note->{uri}, [ ns => 'title' ], $note->{title});
    isa_ok($title, 'TLG::Triplet');
    isa_ok($title->subject, 'TLG::Resource');
    isa_ok($title->predicat, 'TLG::Predicat');
    isa_ok($title->object, 'TLG::Literal');
    ok($title->store, 'title');
    my $content = TLG::Triplet->new($note->{uri}, [ ns => 'content' ], $note->{content});
    isa_ok($content, 'TLG::Triplet');
    ok($content->store, 'content');
    my $score = TLG::Triplet->new($note->{uri}, [ ns => 'score' ], $note->{score});
    ok($score->store, 'score');
    my $date = TLG::Triplet->new($note->{uri}, [ ns => 'date' ], $note->{date});
    ok($date->store, 'date');

    diag('load');

    my $s = TLG::Resource->new($note->{uri});
    isa_ok($s, 'TLG::Resource');
    my $p = TLG::Predicat->load_by_uri(ns => 'title');
    isa_ok($p, 'TLG::Predicat');
    my $l = TLG::Literal->load_by_value($note->{title});
    isa_ok($l, 'TLG::Literal');
    my $r = TLG::Triplet->load( $s, $p, $l );
    cmp_ok($r->{key}, 'eq', $title->{key}, 'right triplet');

    diag('query');

    my @r = map { $_->subject } @{ TLG::Triplet->query( undef, 'ns:title', $note->{title} ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');

    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'score'], $note->{score} ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');
    
    @r = map { $_->subject } @{ TLG::Triplet->query( $note->{uri}, [ ns => 'score'], undef ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');
    
    @r = map { $_->subject } @{ TLG::Triplet->query( $note->{uri}, undef, $note->{score} ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');
    
    @r = map { $_->subject } @{ TLG::Triplet->query( $note->{uri}, 'ns:title', $note->{title} ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');

    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'date'], { op => '>=', value => $note->{date} } ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');

#    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'date'], { order => 'asc' } ) };
#    cmp_ok(scalar @r, '==', 1, 'one resource');
#    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');

    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'date'], { op => '>=', value => $note->{date}, order => 'asc' } ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');
    cmp_ok($r[0]->uri, 'eq', $note->{uri}, 'the right one');

    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'date'], { op => '>=', value => $note->{date}, order => 'asc', limit => 10 } ) };
    cmp_ok(scalar @r, '==', 1, 'one resource');

    @r = map { $_->subject } @{ TLG::Triplet->query( undef, [ ns => 'unknown_predicat'], undef ) };
    cmp_ok(scalar @r, '==', 0, 'no resource');
    
    my $keys = TLG::Triplet->query_subject_keys( undef, 'ns:title', $note->{title} );
    cmp_ok(scalar @$keys, '==', 1, 'one resource key');

    diag('remove');

    ok($title->remove, 'remove title');
    ok($content->remove, 'remove content');
    ok($score->remove, 'remove score');
    ok($date->remove, 'remove date');

}

diag( 'cache disabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
base_test();

diag( 'triplet cache enabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 1;
base_test();

diag( 'full cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
base_test();

