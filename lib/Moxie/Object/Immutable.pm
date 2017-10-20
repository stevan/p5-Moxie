package Moxie::Object::Immutable;
# ABSTRACT: Yet Another (Immutable) Base Class

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use UNIVERSAL::Object::Immutable;

our $VERSION   = '0.05';
our $AUTHORITY = 'cpan:STEVAN';

our @ISA; BEGIN {
    @ISA = (
        'UNIVERSAL::Object::Immutable',
        'Moxie::Object',
    );
}

1;

__END__

=pod

=head1 DESCRIPTION

This is an extension of L<UNIVERSAL::Object::Immutable> and
L<Moxie::Object>.

=cut
