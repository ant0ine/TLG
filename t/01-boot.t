use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 14;

use TLG;
use TLG::Universe;

ok(TLG->boot( name => 'test' ), 'boot');

my $u = TLG->current_universe;

ok($u, 'current universe is set');
cmp_ok($u->{name}, 'eq', 'Test', 'this is the test universe');

my @res = TLG->current_universe->get_host_resources('localhost');
for my $r (qw( uri text triplet lock counter )) {
    my $f = grep { $_ eq $r } @res;
    ok( $f, "found $r resource" );
}

my $uri = $u->instanciate_driver('uri');
isa_ok($uri, 'TLG::Backend::TT');
isa_ok($uri->client, 'TokyoTyrant::RDBTBL');

if ($u->{resources}{memcache1}) {
    my $mem = $u->instanciate_driver('memcache1');
    isa_ok($mem, 'TLG::Cache::Memcache');
    isa_ok($mem->client, 'Cache::Memcached::Fast');
}
elsif ($u->{resources}{hardcache}) {
    my $hard = $u->instanciate_driver('hardcache');
    isa_ok($hard, 'TLG::Cache::TT');
    isa_ok($hard->client, 'TokyoTyrant::RDB');
}

my $bdriver = $u->backend_driver('literal');
isa_ok($bdriver, 'TLG::Backend::TT');

if ($u->{resources}{memcache1}) {
    my $cdriver = $u->cache_driver('literal');
    isa_ok($cdriver, 'TLG::Cache::Memcache');
}
elsif ($u->{resources}{hardcache}) {
    my $cdriver = $u->cache_driver('literal');
    isa_ok($cdriver, 'TLG::Cache::TT');
}

