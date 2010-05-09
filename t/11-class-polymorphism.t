use strict;
use warnings;
use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 8 * 4;

use TLG::Class;

TLG->boot(name => 'test');

package User;
use base qw( TLG::Class );

use TLG::Namespace;

TLG::Namespace->register(app => 'urn:my-web-app:');

sub rdf_type { 'urn:my-web-app:User' }

package main;

sub class {

    diag( 'new' );

    my $u = User->new( 'http://antoine.my-web-app.com' );
    isa_ok($u, 'User');
    cmp_ok($u->get(rdf => 'type'), 'eq', $u->rdf_type, 'check rdf_type');

    diag( 'set' );
    ok($u->app_login('antoine'), 'set login');
    ok($u->foaf_name('Antoine'), 'set name');

    diag( 'store' );
    ok($u->store, 'store');

    diag( 'query' );
    my $r = User->query({});
    cmp_ok(scalar @$r, '==', 1, 'query result: all the users');
    
    $r = User->query({
        'app:login' => undef,
    });
    cmp_ok(scalar @$r, '==', 1, 'query result: users with a login defined');
    
    ok($u->remove, 'remove');
}

diag( 'Cache disabled' );
$TLG::Literal::CACHE = 0;
$TLG::Predicat::CACHE = 0;
$TLG::Resource::CACHE = 0;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 0;
class();

diag( 'Hash Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 0;
$TLG::Class::CACHE = 0;
class();

diag( 'Hash and Table Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
$TLG::Class::CACHE = 0;
class();

diag( 'Full Cache enabled' );
$TLG::Literal::CACHE = 1;
$TLG::Predicat::CACHE = 1;
$TLG::Resource::CACHE = 1;
$TLG::Triplet::CACHE = 1;
$TLG::Class::CACHE = 1;
class();

