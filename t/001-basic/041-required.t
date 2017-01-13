#!perl

use strict;
use warnings;

use Test::More;

package Foo {
    use Moxie;

    extends 'UNIVERSAL::Object';

    has 'foo' => (default => sub{ 'DFOO' } );
    has 'bar' => (required => 1);

    sub foo ($self) { $self->{foo} }
    sub bar ($self) { $self->{bar} }
}

{
    my $foo = Foo->new(foo => 'FOO', bar => 'BAR');
    is($foo->foo, 'FOO', 'slot with default and arg');
    is($foo->bar, 'BAR', 'required slot with arg');
}

{
    my $foo = Foo->new(bar => 'BAR');
    is($foo->foo, 'DFOO', 'slot with default and no arg');
    is($foo->bar, 'BAR', 'required slot with arg');
}

eval { Foo->new };
like( $@,
      qr/^The slot \'bar\' is required/,
      'missing required slot throws an exception'
);


done_testing;
