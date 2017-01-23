package GFW::BBB::Role::HasConfig;

use Moose::Role;

use GFW::BBB::Config;

has _config => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    builder => '_build_config',
);

sub _build_config {
    return GFW::BBB::Config->instance->parsed_config;
}