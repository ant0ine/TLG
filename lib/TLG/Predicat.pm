package TLG::Predicat;



# TODO unmutqble class option
# if set, then can't be removed and is always considered as locked
use strict;
use warnings;

use base qw( TLG::Resource );

use TLG::Namespace;

our $CACHE = 1;

sub _scrub_args {
    my $class = shift;
    my $uri;
    if (@_ == 1) {
        ($uri) = @_;
        die 'uri required' unless $uri;
        $uri = TLG::Namespace->resolve($uri);
    }
    else {
        my ($prefix, $local_name) = @_;
        die 'namespace required' unless $prefix;
        die 'local_name required' unless $local_name;
        $prefix = TLG::Namespace->norm($prefix);
        $uri = $prefix.$local_name;
    }
    return $uri;
}

=head2 new

 my $res = TLG::Predicat->new('http://example.com/', 'property');

=cut

sub new {
    my $class = shift;
    my $ls = pop @_ if ref $_[$#_] eq 'TLG::LockSet' || !defined $_[$#_];
    my $uri = $class->_scrub_args(@_);
    return $class->SUPER::new($uri, $ls);
} 

=head2 load_by_uri

 my $res = TLG::Predicat->load_by_uri('http://example.com/', 'property');

=cut

sub load_by_uri {
    my $class = shift;
    my $uri = $class->_scrub_args(@_);
    return $class->SUPER::load_by_uri($uri);
}

1;
