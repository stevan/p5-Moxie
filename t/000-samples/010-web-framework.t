#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('MOP');
}

# traits ...

package Entity::Traits::Provider {
    use M;

    use Method::Traits ':for_providers';

    sub JSONParameter { () }
}

package Service::Traits::Provider {
    use M;

    use Method::Traits ':for_providers';

    sub GET ($meta, $method_name, $path) { () }
    sub PUT ($meta, $method_name, $path) { () }

    sub consumes ($meta, $method_name, $media_type) { () }
    sub produces ($meta, $method_name, $media_type) { () }
}

# this is the entity class

package Todo {
    use M
        traits => [ 'Entity::Traits::Provider' ];

    extends 'M::Object';

    has 'description';
    has 'is_done';

    sub description : ro JSONParameter;
    sub is_done     : ro JSONParameter;
}

# this is the web-service for it

package TodoService {
    use M
        traits => [ 'Service::Traits::Provider' ];

    extends 'M::Object';

    has 'todos'        => sub { +{} };
    has 'entity_class' => sub { die 'An entity_class is required' };

    sub entity_class : ro;

    sub get_todo ($self, $id) : GET('/:id') produces('application/json') {
        $self->{todos}->{ $id };
    }

    sub update_todo ($self, $id, $todo) : PUT('/:id') consumes('application/json') {
        return unless $self->{todos}->{ $id };
        $self->{todos}->{ $id } = $todo;
    }
}

done_testing;


=pod
# this is what it ultimately generates ...
package TodoResource {
    use M;

    extends 'Web::Machine::Resource';

    has 'JSON'    => sub { JSONinator->new  };
    has 'service' => sub { TodoService->new };

    sub allowed_methods        { [qw[ GET PUT ]] }
    sub content_types_provided { [{ 'application/json' => 'get_as_json' }]}
    sub content_types_accepted { [{ 'application/json' => 'update_with_json' }]}

    sub get_as_json ($self) {
        my $id  = bind_path('/:id' => $self->request->path_info);
        my $res = $self->{service}->get_todo( $id );
        return \404 unless $res;
        return $self->{JSON}->collapse( $res );
    }

    sub update_with_json ($self) {
        my $id  = bind_path('/:id' => $self->request->path_info);
        my $e   = $self->{JSON}->expand( $self->{service}->entity_class, $self->request->content )
        my $res = $self->{service}->update_todo( $id, $e );
        return \404 unless $res;
        return;
    }
}
=cut

