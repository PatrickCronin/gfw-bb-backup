package GFW::BBB::Role::Host;

use Moose::Role;

has config_name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has host_config => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_host_config',
);

requires qw(
    copy
    files_with_extensions
    md5
    _run_command
    tempdir
);

with 'GFW::Role::HasConfig';

sub host_config_value {
    my ($self, @key_paths) = @_;

    return $self->_config->get_value($self->config_name, @key_paths);
}

sub consistent_copy {
    my ($self, @source_target_pairs) = @_;

    my $max_attempts = $self->_config->get_value(qw(
        general
        max-consistent-copy-attempts
    ));

    my $current_attempt = 0;
    while ($current_attempt < $max_attempts) {
        my %source_md5 = $self->md5( map { $_->{source} } @source_target_pairs );

        $self->copy( $_ ) for @source_target_pairs;

        my %target_md5 = $self->md5( map { $_->{target} } @source_target_pairs );

        return if ! grep {
            $source_md5{ $_->{source} } ne $target_md5{ $_->{target} }
        } @source_target_pairs;

        $self->delete( map { $_->{target} } @source_target_pairs );

        $current_attempt++;
    };

    die "Failed to create a consistent copy within $max_attempts attempts.";
}

sub transfer {
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

sub compress {
    my ($self, $target, $source_root, @sources) = @_;

    return $self->_run_command(
        $self->host_config->{path_to_tar},
        '-c',
        '-j',
        '-C', $source_root->stringify,
        '-f', $target->stringify,
        map { $_->relative($source_root)->stringify } @sources
    );
}

1;