package Moxie::Object;
# ABSTRACT: Yet Another Base Class

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }

1;

__END__

=pod

=head1 DESCRIPTION

Extending L<UNIVERSAL::Object> for fun and profit?

=cut
