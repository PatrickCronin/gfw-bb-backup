package GFW::Role::HasConfig;

use Moose::Role;

use GFW::Config;

has _config => (
    is => 'ro',
    isa => 'GFW::Config',
    lazy => 1,
    builder => '_build_config',
);

sub _build_config {
    return GFW::Config->instance;
}

1;