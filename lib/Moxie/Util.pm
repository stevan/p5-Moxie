package Moxie::Util;
# ABSTRACT: Utils for Yet Another Moose Clone

use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use MOP;

## Inheriting required methods

sub INHERIT_REQUIRED_METHODS {
    my ($meta) = @_;
    foreach my $super ( map { MOP::Role->new( name => $_ ) } $meta->superclasses ) {
        foreach my $required_method ( $super->required_methods ) {
            $meta->add_required_method( $required_method->name )
                unless $meta->has_method( $required_method->name );
        }
    }
    return;
}

## Slot gathering ...

# NOTE:
# The %HAS variable will cache things much like
# the package stash method/cache works. It will
# be possible to distinguish the local slots
# from the inherited ones because the default sub
# will have a different stash name.

sub GATHER_ALL_SLOTS {
    my ($meta) = @_;
    foreach my $super ( map { MOP::Role->new( name => $_ ) } @{ $meta->mro } ) {
        foreach my $attr ( $super->slots ) {
            $meta->alias_slot( $attr->name, $attr->initializer )
                unless $meta->has_slot( $attr->name )
                    || $meta->has_slot_alias( $attr->name );
        }
    }
    return;
}

1;

__END__

=pod

=head1 DESCRIPTION

No user serviceable parts inside.

=cut
