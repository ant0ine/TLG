use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More qw(no_plan);

use_ok('TLG');
use_ok('TLG::Universe');
use_ok('TLG::Entity');
use_ok('TLG::Namespace');
use_ok('TLG::Cache::Memcache');
use_ok('TLG::Cache::Local');
use_ok('TLG::Cache::TT');
use_ok('TLG::Backend::TT');
use_ok('TLG::Backend::MySQL');
use_ok('TLG::Resource');
use_ok('TLG::Predicat');
use_ok('TLG::Literal');
use_ok('TLG::Triplet');
use_ok('TLG::Class');
use_ok('TLG::LockSet');
use_ok('TLG::TXN');
use_ok('TLG::Unmutable');
use_ok('TLG::GC');
