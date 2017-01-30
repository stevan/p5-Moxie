#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('MOP');
}

=pod

This just shows that we can apply our
annotations and add others in if we want

=cut

{
    package Bar::Annotation::Provider;
    use strict;
    use warnings;

    our $ANNOTATION_USED = 0;

    sub Bar { $ANNOTATION_USED++; return }

    package Foo;
    use Moxie
        annotations => ['Bar::Annotation::Provider'];

    extends 'Moxie::Object';

    has foo => sub { 'FOO' };

    sub foo : ro Bar;
}

BEGIN {
    is($Bar::Annotation::Provider::ANNOTATION_USED, 1, '...the annotation was used in BEGIN');
}

{
    my $foo = Foo->new;
    isa_ok($foo, 'Foo');
    can_ok($foo, 'foo');

    is($foo->foo, 'FOO', '... the generated accessor worked as expected');
}

{
    my $method = MOP::Class->new( 'Foo' )->get_method('foo');
    isa_ok($method, 'MOP::Method');
    is_deeply(
        [ $method->get_code_attributes ],
        [qw[ ro Bar ]],
        '... got the expected attributes'
    );
}

done_testing;

