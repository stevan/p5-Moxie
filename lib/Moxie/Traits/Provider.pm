package Moxie::Traits::Provider;
# ABSTRACT: built in traits

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Method::Traits ':for_providers';

use Carp                   ();
use B::CompilerPhase::Hook (); # multi-phase programming
use PadWalker              (); # for generating lexical accessors

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub init_args ( $meta, $method_name, %init_args ) : OverwritesMethod {

    Carp::croak('The `init_arg` trait can only be applied to BUILDARGS')
        if $method_name ne 'BUILDARGS';

    $meta->add_method('BUILDARGS' => sub ($self, @args) {
        my $proto = $self->next::method( @args );

        #use Data::Dumper;
        #warn Dumper $proto;
        #warn Dumper \%init_args;

        foreach my $init_arg ( keys %init_args ) {
            if ( exists $proto->{ $init_arg } ) {
                if ( defined $init_args{ $init_arg } ) {
                    $proto->{ $init_args{ $init_arg } } = delete $proto->{ $init_arg };
                }
                else {
                    delete $proto->{ $init_arg };
                }
            }
        }
        return $proto;
    });
}

sub ro ( $meta, $method_name, @args ) : OverwritesMethod {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        if ( $method_name =~ /^get_(.*)$/ ) {
            $slot_name = $1;
        }
        else {
            $slot_name = $method_name;
        }
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub {
        Carp::croak("Cannot assign to `$slot_name`, it is a readonly") if scalar @_ != 1;
        $_[0]->{ $slot_name };
    });
}

sub rw ( $meta, $method_name, @args ) : OverwritesMethod {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        $slot_name = $method_name;
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub {
        $_[0]->{ $slot_name } = $_[1] if scalar( @_ ) > 1;
        $_[0]->{ $slot_name };
    });
}

sub wo ( $meta, $method_name, @args ) : OverwritesMethod {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        if ( $method_name =~ /^set_(.*)$/ ) {
            $slot_name = $1;
        }
        else {
            $slot_name = $method_name;
        }
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub {
        Carp::croak("You must supply a value to write to `$slot_name`") if scalar(@_) < 1;
        $_[0]->{ $slot_name } = $_[1];
    });
}

sub predicate ( $meta, $method_name, @args ) : OverwritesMethod {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        if ( $method_name =~ /^has_(.*)$/ ) {
            $slot_name = $1;
        }
        else {
            $slot_name = $method_name;
        }
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub { defined $_[0]->{ $slot_name } } );
}

sub clearer ( $meta, $method_name, @args ) : OverwritesMethod {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        if ( $method_name =~ /^clear_(.*)$/ ) {
            $slot_name = $1;
        }
        else {
            $slot_name = $method_name;
        }
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub { undef $_[0]->{ $slot_name } } );
}

sub private ( $meta, $method_name, @args ) {

    my $slot_name;
    if ( $args[0] ) {
        $slot_name = shift @args;
    }
    else {
        $slot_name = $method_name;
    }

    Carp::croak('Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    # NOTE:
    # These are lexical accessors ...

    # we should not be able to find it in the symbol table ...
    if ( $meta->has_method( $method_name ) || $meta->has_method_alias( $method_name ) || $meta->requires_method( $method_name ) ) {
        Carp::croak('Trying to install private (lexical) accessor for slot('.$slot_name.') named ('
            .$method_name.') and found a conflicting non-lexical method of that name');
    }
    else {
        # at this point we can assume that we have a lexical
        # method which we need to transform, and in order to
        # do that we need to look at all the methods in this
        # class and find all the ones who 'close over' the
        # lexical method and then re-write their lexical pad
        # to use the accessor method that I will generate.

        # NOTE:
        # we need to delay this until the UNITCHECK phase
        # because we need all the methods of this class to
        # have been compiled, at this moment, they are not.
        B::CompilerPhase::Hook::enqueue_UNITCHECK {
            # now check the class local methods ....
            foreach my $m ( $meta->methods ) {
                # get a HASH of the things the method closes over
                my $closed_over = PadWalker::closed_over( $m->body );

                #warn Data::Dumper::Dumper({
                #    class       => $meta->name,
                #    method      => $m->name,
                #    closed_over => $closed_over,
                #    looking_for => $method_name,
                #});

                # if the private method is used, then it will be
                # here with a prepended `&` sigil ...
                if ( exists $closed_over->{ '&' . $method_name } ) {
                    # now we know that we have someone using the
                    # lexical method inside the method body, so
                    # we need to generate our accessor accordingly
                    # then this is as simple as assigning the HASH key
                    $closed_over->{ '&' . $method_name } =  sub {
                        package DB; @DB::args = (); my () = caller(1);
                        my ($self)  = @DB::args;
                        $self->{ $slot_name } = $_[0] if scalar @_;
                        $self->{ $slot_name };
                    };

                    # okay, now restore the closed over vars
                    # with our new addition...
                    PadWalker::set_closed_over( $m->body, $closed_over );
                }
            }
        };
    }

}

1;

__END__

=pod

=head1 DESCRIPTION

This is a L<Method::Traits> provider module which L<Moxie> enables by
default. These are documented in the L<METHOD TRAITS> section of the
L<Moxie> documentation.

=cut
