package GFW::BBB::Role::Host;

use Moose::Role;

has config_name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

requires qw(
    files_with_extensions
    md5
    tempdir
    copy
);

sub safe_transfer {
    my ($self, $target_host_config_name, $target_path, @source_files) = @_;

    # local => local
    # remote1 => remote1
    if ($self->config_name eq $target_host_config_name) {
        $self->copy($target_path, @source_files);
    }

    # remote => local
    elsif ($target_host_config_name eq 'local') {
        $self->rsync_get($target_path, @source_files);
    }

    # local => remote
    elsif ($self->config_name eq 'local') {
        GFW::BBB::HostFactory
            ->new_from_config($target_host_config_name)
            ->rsync_put($target_path, @source_files);
    }

    # remote1 => remote2
    else {
        die q{This scenario isn't implemented yet!};
    }
}

1;