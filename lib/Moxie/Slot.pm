package Moxie::Slot;
# ABSTRACT: Slots in a Moxie World

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

use overload '&{}' => 'to_code', fallback => 1;

our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }
our %HAS; BEGIN {
    %HAS = (
        default => sub { die 'A `default` value is required' }
    )
}

sub to_code ($self, @) {
    return $self->{default};
}

1;

__END__

=pod

=head1 DESCRIPTION

Slots in the Moxie World (sung to the tune of "Spirits in the
Material World" by the Police), more details later ...

=cut
