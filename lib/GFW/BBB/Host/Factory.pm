package GFW::BBB::Host::Factory;

use Moose;

use GFW::BBB::Host::Local  ();
use GFW::BBB::Host::Remote ();

sub new_from_config {
    my ($self, $host_config_name, $host_config) = @_;

    my $host_package = $host_config_name eq 'local'
        ? 'GFW::BBB::Host::Local'
        : 'GFW::BBB::Host::Remote';

    return $host_package->new(
        config_name => $host_config_name,
        host_config => $host_config,
    );
}

__PACKAGE__->meta->make_immutable;

1;