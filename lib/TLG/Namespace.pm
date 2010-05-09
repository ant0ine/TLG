package TLG::Namespace;

use strict;
use warnings;

use Exporter qw( import );
use URI;

my %Ns = (
    dc      => 'http://purl.org/dc/elements/1.1/',
    rdf     => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    foaf    => 'http://xmlns.com/foaf/0.1/',
    rss     => 'http://purl.org/rss/1.0/',
);

sub register {
    my $class = shift;
    my ($prefix, $uri) = @_;
    die 'prefix required' unless $prefix;
    die 'uri required' unless $uri;
    $uri = URI->new($uri)->canonical->as_string;
    $Ns{$prefix} = $uri;
    return 1;
}

sub norm {
    my $class = shift;
    my ($prefix) = @_;
    return $Ns{$prefix} if $Ns{$prefix};
    return $prefix;
}

sub resolve {
    my $class = shift;
    my ($local) = @_;
    if ($local =~ /^([a-zA-Z0-9]+)[:_](\w+)$/) {
        if ($Ns{$1} ) {
            return $Ns{$1}.$2;
        }
    }
    return $local; 
}

1;
