package GFW::BBB::LRPath;

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

sub delete {
    my $self = shift;

    $self->host->delete($self->path);
}

__PACKAGE__->meta->make_immutable;

1;