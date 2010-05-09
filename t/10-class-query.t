use strict;
use warnings;
use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 17 * 2;

use TLG::Class;

my $myns1 = 'http://my.namespace.org/1/';
my $myns2 = 'http://my.namespace.org/2/';

TLG->boot(name => 'test');


my $note1 = {
    uri => 'http://example.com/'.time,
    title => 'My title'.time,
    content => 'the content',
    score => 2,
    html => 'http://example.com/'.time.'/html',
};

my $note2 = {
    uri => 'http://example.com/2/'.time,
    title => 'My title 2'.time,
    content => 'the content',
    score => 5,
    flag => 1,
};

# XXX clean
my $r = TLG::Class->query({
    $myns1.'title' => undef,
});
$_->remove for @$r;

sub nodes {

    diag('setup the nodes');

    my $node1 = TLG::Class->new( $note1->{uri} );
    $node1->set( $myns1 => title => $note1->{title});
    $node1->set( $myns1 => content => $note1->{content});
    $node1->set( $myns2 => score => $note1->{score});
    $node1->set( $myns1 => html => $note1->{html});
    $node1->store;

    my $node2 = TLG::Class->new( $note2->{uri} );
    $node2->set( $myns1, title => $note2->{title});
    $node2->set( $myns1, content => $note2->{content});
    $node2->set( $myns2, score => $note2->{score});
    $node2->set( $myns2, flag => $note2->{flag});
    $node2->store;


    diag('one term: '.$note1->{title});
    my $r = TLG::Class->query({
        $myns1.'title' => $note1->{title},
    });
    cmp_ok(scalar @$r, '==', 1, 'query result 1 node');
    cmp_ok($r->[0]->uri, 'eq', $node1->uri, 'the correct one');
    cmp_ok(TLG::Class->count({
        $myns1.'title' => $note1->{title},
    }), '==', 1, 'count 1 node');


    diag('two terms (AND)');
    $r = TLG::Class->query({
        $myns1.'title' => $note1->{title},
        $myns2.'score' => 2,
    });
    cmp_ok(scalar @$r, '==', 1, 'query result 1 node');
    cmp_ok($r->[0]->uri, 'eq', $node1->uri, 'the correct one');
    cmp_ok(TLG::Class->count({
        $myns1.'title' => $note1->{title},
        $myns2.'score' => 2,
    }), '==', 1, 'count 1 node');


    diag('title defined');
    $r = TLG::Class->query({
        $myns1.'title' => undef,
    });
    cmp_ok(scalar @$r, '==', 2, 'query result 2 nodes');
    cmp_ok(TLG::Class->count({
        $myns1.'title' => undef,
    }), '==', 2, 'count 2 nodes');


    diag('limit 1');
    $r = TLG::Class->query({
        $myns1.'title' => undef,
    }, {
        limit => 1,   
    });
    cmp_ok(scalar @$r, '==', 1, 'query result 1 node');

=cut
    diag('sort asc');
    $r = TLG::Class->query({}, {
        sort => {
            predicat => $myns2.'score',
            order => 'asc',
        }
    });
    cmp_ok(scalar @$r, '==', 2, 'query result 2 nodes');
    cmp_ok($r->[0]->uri, 'eq', $node1->uri, 'the first one');
    cmp_ok($r->[1]->uri, 'eq', $node2->uri, 'the second one');
=cut

    diag('sort asc with terms');
    $r = TLG::Class->query({
        $myns2.'score' => undef,
        }, {
        sort => {
            predicat => $myns2.'score',
            order => 'asc',
        }
    });
    cmp_ok(scalar @$r, '==', 2, 'query result 2 nodes');
    cmp_ok($r->[0]->uri, 'eq', $node1->uri, 'the first one');
    cmp_ok($r->[1]->uri, 'eq', $node2->uri, 'the second one');

    diag('sort desc with terms');
    $r = TLG::Class->query({
        $myns2.'score' => undef,
        }, {
        sort => {
            predicat => $myns2.'score',
            order => 'desc',
        }
    });
    cmp_ok(scalar @$r, '==', 2, 'query result 2 nodes');
    cmp_ok($r->[1]->uri, 'eq', $node1->uri, 'the first one');
    cmp_ok($r->[0]->uri, 'eq', $node2->uri, 'the second one');
=cut
    diag('query 2 node');

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
=cut

    diag('remove nodes');

    ok($node1->remove, 'remove');
    ok($node2->remove, 'remove');
}

diag( 'Cache disabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 0;
nodes();

diag( 'Cache enabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 1;
nodes();

