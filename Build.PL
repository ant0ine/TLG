use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'TLG',
    license             => 'perl',
    dist_author         => 'Antoine Imbert <antoine.imbert@gmail.com>',
    dist_version_from   => 'lib/TLG.pm',
    build_requires => {
        'Test::More' => 0,
        'TokyoTyrantx::Instance' => 0,
        'TokyoTyrantx::Lock' => 0,
        'TokyoTyrantx::Counter' => 0,
        'Cache::Memcached::Fast' => 0,
    },
    add_to_cleanup      => [ 'TLG-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
