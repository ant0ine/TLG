package TLG::Resource;

use strict;
use warnings;

use base qw( TLG::Entity );

use URI;
use Digest::MD5 qw(md5_base64);

our $CACHE = 1;

=head2 new

 my $res = TLG::Resource->new('http://example.com');

=cut

sub new {
    my $class = shift;
    my ($uri, $ls) = @_;

    if ($uri) {
        $uri = URI->new($uri)->canonical->as_string;
    }
    else {
        # TODO better handling of blank nodes
        $uri = 'http://blank.node/'.time.rand(100);
    }

    return $class->SUPER::new( { value => $uri }, $ls );
}

=head2 $class->generate_key($args)

For now MD5, but can be improved.

=cut

sub generate_key  {
    my $class = shift;
    my ($args) = @_;
    return unless $args->{value};
    return md5_base64($args->{value});
}

sub value { $_[0]->{value} }

sub uri { $_[0]->{value} }

=head2 load_by_uri

 my $res = TLG::Resource->load('http://example.com');

=cut

sub load_by_uri {
    my $class = shift;
    my ($uri) = @_;
    die 'uri required' unless $uri;
    $uri = URI->new($uri)->canonical->as_string;
    return $class->load($uri);
}

sub as_string { $_[0]->as_ntriples }

sub as_ntriples {
    my $self = shift;
    return '<'.$self->uri.'>';
}

1;
