package GFW::BBB::Host::Factory;

use Moose;

use GFW::BBB::Host::Local  ();
use GFW::BBB::Host::Remote ();

with 'GFW::Role::HasConfig';

sub new_host_from_config {
    my ($self, $host_config_name) = @_;

    my %common_args = ( config_name => $host_config_name );

    return GFW::BBB::Host::Local->new( %common_args )
        if $host_config_name eq 'local';

    return GFW::BBB::Host::Remote->new(
        %common_args,
        ssh_host_config => $self->_config->load_ssh_host_config(
            $host_config_name),
    );
}

__PACKAGE__->meta->make_immutable;

1;