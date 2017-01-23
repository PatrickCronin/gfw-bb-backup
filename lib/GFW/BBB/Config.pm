package GFW::BBB::Config;

use MooseX::Singleton;

use Config::INI;
use GFW::BBB::Types qw(HashRef);

has parsed_config => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    builder => '_build_parsed_config',
);

sub _build_parsed_config {
    my $self = shift;

    return Config::INI::Reader->read_file('etc/config.ini');
}

__PACKAGE__->meta->make_immutable;

1;
