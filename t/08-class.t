use strict;
use warnings;
use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 62 * 4;

use TLG::Class;

my $myns1 = 'http://my.namespace.org/1/';
my $myns2 = 'http://my.namespace.org/2/';

TLG->boot(name => 'test');


my $note = {
    uri => 'http://example.com/'.time,
    title => 'My title'.time,
    content => 'the content',
    score => 2,
    html => 'http://example.com/'.time.'/html',
};

sub nodes {

    diag('new');

    my $node = TLG::Class->new( $note->{uri} );
    isa_ok($node, 'TLG::Class');
    isa_ok($node->subject, 'TLG::Resource');
    like($node->_cache_key, qr/^TLG::Class-test/, 'the node cache key looks good');

    diag('set');

    ok($node->set( $myns1 => title => $note->{title}), 'set title');
    ok($node->set( $myns1 => content => $note->{content}), 'set content');
    ok($node->set( $myns2 => score => $note->{score}), 'set score');
    ok($node->set( $myns1 => html => $note->{html}), 'set html');

    diag('get');

    cmp_ok($node->get( $myns1 => 'title'), 'eq', $note->{title}, 'get title');
    cmp_ok($node->get( $myns1 => 'content'), 'eq', $note->{content}, 'get content');
    cmp_ok($node->get( $myns2 => 'score'), '==', $note->{score}, 'get score');
    cmp_ok($node->get( $myns1 => 'html'), 'eq', $note->{html}, 'get html');

    diag('store');
    
    cmp_ok(scalar(keys %{ $node->{__new_properties} }), '==', 4, '4 new properties');
    cmp_ok(scalar(keys %{ $node->{__properties} }), '==', 0, '0 properties');
    ok($node->store, 'store');
    cmp_ok(scalar(keys %{ $node->{__new_properties} }), '==', 0, '0 new properties');
    cmp_ok(scalar(keys %{ $node->{__properties} }), '==', 4, '4 properties');

    diag('get again');

    cmp_ok($node->get( $myns1 => 'title'), 'eq', $note->{title}, 'get title');
    cmp_ok($node->get( $myns1 => 'content'), 'eq', $note->{content}, 'get content');
    cmp_ok($node->get( $myns2 => 'score'), '==', $note->{score}, 'get score');
    cmp_ok($node->get( $myns1 => 'html'), 'eq', $note->{html}, 'get html');

    diag('add');

    ok( $node->add( $myns2, score => 3), 'add score');
    my @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 2, '2 scores');

    ok($node->store, 'store');

    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 2, '2 scores');
    
    diag('del');
    
    ok( $node->del( $myns2, score => 3), 'del score');
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 1, '1 score');
    cmp_ok($scores[0], '==', 2, 'the right one');
    
    ok($node->store, 'store');
    
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 1, '1 score');
    cmp_ok($scores[0], '==', 2, 'the right one');

    diag('set (replace)');

    ok( $node->set( $myns2 => score => 4), 'replace score');
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 1, '1 score');

    ok( $node->set( $myns1 => content => 'test'), 'replace content');
    my @contents = $node->get( $myns1 => 'content');
    cmp_ok(scalar @contents, '==', 1, '1 content');
    
    ok($node->store, 'store');
    
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 1, '1 score');

    diag('set (remove)');

    ok( $node->set( $myns2 => score => undef), 'remove score');
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 0, '0 score');

    cmp_ok(scalar(keys %{ $node->{__new_properties} }), '==', 1, 'the undef property');
    cmp_ok(scalar(keys %{ $node->{__properties} }), '==', 4, '4 properties');
    ok($node->store, 'store');
    
    @scores = $node->get( $myns2 => 'score');
    cmp_ok(scalar @scores, '==', 0, '0 score');

    diag('load');

    my $loaded = TLG::Class->load($note->{uri});
    isa_ok($loaded, 'TLG::Class');
    is_deeply($loaded->properties, $node->properties, 'same properties');
    
    #use Data::Dumper; print Dumper($loaded);

    diag('query 1 node');

    ok($node->set( $myns2 => score => 4 ), 'set score');
    ok($node->store, 'store');

    my $r = TLG::Class->query({
        $myns1.'title' => $note->{title},
        $myns2.'score' => 4,
    });
    cmp_ok(scalar @$r, '==', 1, 'query result 1 node');
    cmp_ok($r->[0]->uri, 'eq', $node->uri, 'the correct one');

    $r = TLG::Class->query({
        $myns1.'title' => $note->{title},
        $myns2.'score' => undef,
    });
    cmp_ok(scalar @$r, '==', 1, 'query result');
    cmp_ok($r->[0]->uri, 'eq', $node->uri, 'the correct one');

    diag('query 2 node');

    my $note2 = {
        uri => 'http://example.com/2/'.time,
        title => 'My title'.time,
        content => 'the content',
        score => 5,
        flag => 1,
    };

    my $node2 = TLG::Class->new( $note2->{uri} );
    isa_ok($node2, 'TLG::Class');
    ok($node2->set( $myns1, title => $note2->{title}), 'set title');
    ok($node2->set( $myns1, content => $note2->{content}), 'set content');
    ok($node2->set( $myns2, score => $note2->{score}), 'set score');
    ok($node2->set( $myns2, flag => $note2->{flag}), 'set flag');
    ok($node2->store, 'store');

    # print $node2->as_string;

    $r = TLG::Class->query({
        $myns2.'score' => undef,
    });
    cmp_ok(scalar @$r, '==', 2, 'query result: has score');

    $r = TLG::Class->query({
        OR => {
            $myns1.'content' => 'test',
            $myns2.'score' => 5,
        }
    });
    cmp_ok(scalar @$r, '==', 2, 'query result: OR');

    # node that has a score but no flag
    $r = TLG::Class->query({
        DIFF => [
            $myns2.'score' => undef,
            $myns2.'flag' => undef,
        ]
    });
    cmp_ok(scalar @$r, '==', 1, 'query result: DIFF');
    cmp_ok($r->[0]->uri, 'eq', $note->{uri}, 'note1');

    ok($node->remove, 'remove');
    ok($node2->remove, 'remove');
}

diag( 'Cache disabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 0;
nodes();

diag( 'Hash Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 0;
nodes();

diag( 'Hash and Table Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
$TLG::Class::CACHE = 0;
nodes();

diag( 'Full Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
$TLG::Class::CACHE = 1;
nodes();

