use strict;

use FindBin qw( $Bin );
use Cwd;
use lib Cwd::realpath("$Bin/../lib");

use Test::More tests => 6 * 8;

use TLG;
use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;
use TLG::Triplet;
use TLG::Namespace;

TLG::Namespace->register( ns => 'http://my.namespace.org/' );

TLG->boot(name => 'test');

my $time = time;

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/link> <http://example.com/'.$time.'/2> .';
    
    diag('import');
    my $link = TLG::Triplet->new_from_ntriples($import);
    ok($link, 'parse successful');
    isa_ok($link, 'TLG::Triplet');
    isa_ok($link->subject, 'TLG::Resource');
    isa_ok($link->predicat, 'TLG::Predicat');
    isa_ok($link->object, 'TLG::Resource');
    ok($link->store, 'title');

    diag('export');
    my $export = $link->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($link->remove, 'remove link');
}

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/title> ""My Title"" .';
    
    diag('import');
    my $title = TLG::Triplet->new_from_ntriples($import);
    ok($title, 'parse successful');
    isa_ok($title, 'TLG::Triplet');
    isa_ok($title->subject, 'TLG::Resource');
    isa_ok($title->predicat, 'TLG::Predicat');
    isa_ok($title->object, 'TLG::Literal');
    ok($title->store, 'title');

    diag('export');
    my $export = $title->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($title->remove, 'remove title');
}

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/content> ""My content\n\twith break, a tab, a double quote \", and a backslash \\\\ "" .';
    
    diag('import');
    my $content = TLG::Triplet->new_from_ntriples($import);
    ok($content, 'parse successful');
    isa_ok($content, 'TLG::Triplet');
    isa_ok($content->subject, 'TLG::Resource');
    isa_ok($content->predicat, 'TLG::Predicat');
    cmp_ok($content->object->value, 'eq', "My content\n\twith break, a tab, a double quote \", and a backslash \\ ", 'correct object');
    ok($content->store, 'content');

    diag('export');
    my $export = $content->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($content->remove, 'remove content');
}

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/integer> ""2"" .';
    
    diag('import');
    my $integer = TLG::Triplet->new_from_ntriples($import);
    ok($integer, 'parse successful');
    isa_ok($integer, 'TLG::Triplet');
    isa_ok($integer->subject, 'TLG::Resource');
    isa_ok($integer->predicat, 'TLG::Predicat');
    cmp_ok($integer->object, '==', 2, 'correct object');
    ok($integer->store, 'integer');

    diag('export');
    my $export = $integer->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($integer->remove, 'remove integer');
}

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/content> ""test bad html >"" .';
    
    diag('import');
    my $integer = TLG::Triplet->new_from_ntriples($import);
    ok($integer, 'parse successful');
    isa_ok($integer, 'TLG::Triplet');
    isa_ok($integer->subject, 'TLG::Resource');
    isa_ok($integer->predicat, 'TLG::Predicat');
    cmp_ok($integer->object->value, 'eq', 'test bad html >', 'html');
    ok($integer->store, 'html content');

    diag('export');
    my $export = $integer->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($integer->remove, 'remove html content');
}

{
    my $import = '<http://example.com/'.$time.'> <http://my.namespace.org/content> ""multiple \\\\\\\\ backslashes"" .';
    
    diag('import');
    my $integer = TLG::Triplet->new_from_ntriples($import);
    ok($integer, 'parse successful');
    isa_ok($integer, 'TLG::Triplet');
    isa_ok($integer->subject, 'TLG::Resource');
    isa_ok($integer->predicat, 'TLG::Predicat');
    cmp_ok($integer->object->value, 'eq', "multiple \\\\ backslashes", 'backslash');
    ok($integer->store, 'html content');

    diag('export');
    my $export = $integer->as_ntriples;
    cmp_ok($export, 'eq', $import, 'export match import');
    
    diag('remove');

    ok($integer->remove, 'remove content');
}
