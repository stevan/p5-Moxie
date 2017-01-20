
package Moxie::Trait::Util;
# ABSTRACT: Traits system

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use B::CompilerPhase::Hook (); # multi-phase programming

use Moxie::Trait;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

## ...

our @TRAIT_PROVIDERS = ('Moxie::Trait');

our %__CODE_ATTRIBUTE_STORAGE__;

sub SCHEDULE_TRAIT_COLLECTION ( $meta ) {

    # It does not make any sense to create
    # something that is meant to run in the
    # BEGIN phase *after* that phase is done
    # so catch this and error ...
    die 'Trait collection must be scheduled during BEGIN time, not (' . ${^GLOBAL_PHASE}. ')'
        unless ${^GLOBAL_PHASE} eq 'START';

    # This next step, we want to do
    # immediately after this method
    # (and the BEGIN block it is
    # contained within) finishes.

    # Since these are BEGIN blocks,
    # they need to be enqueued in
    # the reverse order they will
    # run in order to have the method
    # not trip up role composiiton
    B::CompilerPhase::Hook::enqueue_BEGIN {
        # we remove the modifier, but leave
        # the fetcher because that is how
        # attributes::get will find this info
        $meta->delete_method_alias('MODIFY_CODE_ATTRIBUTES')
    };
    B::CompilerPhase::Hook::enqueue_BEGIN {
        $meta->alias_method(
            FETCH_CODE_ATTRIBUTES => sub ($pkg, $code) {
                return unless exists $__CODE_ATTRIBUTE_STORAGE__{ $code };
                return $__CODE_ATTRIBUTE_STORAGE__{ $code }->@*;
            }
        );
        $meta->alias_method(
            MODIFY_CODE_ATTRIBUTES => sub ($pkg, $code, @attrs) {

                # First lets parse the traits, currently
                # we are not terribly sophisticated, but
                # we accept `foo` calls (no-parens) and
                # we accept `foo(1, 2, 3)` calls (parens
                # with comma seperated args).

                # NOTE:
                # None of the args are eval-ed and they are
                # basically just a list of strings.
                my @traits = map {
                    if ( m/^([a-z_]*)\((.*)\)$/ ) {
                        [ $1, [ split /\,/ => $2 ], $_ ]
                    }
                    elsif ( m/^([a-z_]*)$/ ) {
                        [ $1, [], $_ ]
                    }
                } @attrs;

                #use Data::Dumper;
                #warn Dumper \@traits;

                # Now loop through the traits and look to
                # see if we have any ones we cannot handle
                # and collect them for later ...
                my @bad = grep {
                    my $stop;
                    foreach my $provider ( @TRAIT_PROVIDERS ) {
                        if ( $provider->can( $_->[0] ) ) {
                            $stop++;
                            last;
                        }
                    }
                    not( $stop );
                } @traits;

                #use Data::Dumper;
                #warn Dumper \@bad;

                # bad traits are bad, return the originals
                # that we do not handle
                return map $_->[2], @bad if @bad;

                # now we need to loop through the traits
                # that we parsed and apply the trait function
                # to our method accordingly

                my $method      = MOP::Method->new( $code );
                my $method_name = $method->name;
                foreach my $trait ( @traits ) {
                    my ($t, $args) = @$trait;
                    foreach my $provider ( @TRAIT_PROVIDERS ) {
                        if ( my $m = $provider->can( $t ) ) {
                            $m->( $meta, $method_name, @$args );
                            last;
                        }
                    }
                }

                # next we need to fetch the latest version
                # of the method installed in the stash, or
                # if that cannot be found, use the original
                # one, and we then need to store the info
                # about the traits so it can be retrieved
                # via attributes::get

                if ( my $generated = $meta->get_method( $method->name ) || $method ) {
                    $__CODE_ATTRIBUTE_STORAGE__{ $generated->body } = \@traits;
                }

                # all is well, so let the world know that ...
                return;
            }
        );
    };
}

1;

__END__

=pod

=head1 DESCRIPTION

Nothing to see here

=cut
