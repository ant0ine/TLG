package TLG::Literal;

use strict;
use warnings;

use base qw( TLG::Entity );

use Encode qw(encode_utf8);
use Digest::MD5 qw(md5_base64);
use Carp qw(cluck);
our $CACHE = 1;

# TODO type of literal: integer should not be saved ?

=head2 $class->new($value, $ls)

Generates the key from the value, and return the object.

=cut

sub new {
    my $class = shift;
    my ($value, $ls) = @_;
    cluck 'value required' unless $value;
    $value = encode_utf8($value);
    return $class->SUPER::new( { value => $value }, $ls );
}

=head2 $class->generate_key(%args)

For now MD5, but can be improved.

=cut

sub generate_key  {
    my $class = shift;
    my ($args) = @_;
    return unless $args->{value};
    return md5_base64($args->{value});
}

sub value { $_[0]->{value} }

=head2 load_by_value

alias of load

=cut

sub load_by_value { shift->load(@_); }

sub as_string { $_[0]->as_ntriples( shorten => 1 ) }

sub as_ntriples {
    my $self = shift;
    my %opts = @_;
    my $v = $self->value;
    $v =~ s/\\/\\\\/g;
    $v =~ s/\n/\\n/g;
    $v =~ s/\r/\\r/g;
    $v =~ s/\t/\\t/g;
    $v =~ s/\"/\\"/g;
    $v = substr($v, 0, 25) if $opts{shorten};
    return '""'.$v.'""';
}

1;
