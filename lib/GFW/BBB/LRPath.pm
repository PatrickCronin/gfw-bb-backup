package GFW::BBB::Path;

use Moose;

use MooseX::Types::Path::Tiny qw(Path);

has host => (
    is => 'ro',
    does => 'GFW::BBB::Role::Host',
    required => 1,
);

has path => (
    is => 'ro',
    isa => Path,
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;