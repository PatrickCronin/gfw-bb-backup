package GFW::Config;

use MooseX::Singleton;

use Config::INI::Reader;
use Hash::Merge qw(merge);
use List::Gather qw(gather take);
use List::Util qw(first);
use Path::Tiny qw(path);
use Try::Tiny qw(catch try);

has _parsed_config => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_parsed_config',
);

sub _build_parsed_config {
    my $self = shift;

    my @possible_config_paths = $self->_possible_config_paths;

    my ($selected_config) = first { $_->exists } @possible_config_paths
        or die "Could not find an existing file. Search at:\n\t-"
        . (join "\n\t-", @possible_config_paths);

    my $config = Config::INI::Reader->read_file( $selected_config );

    return merge($self->_default_config_values, $config);
        
}

sub _possible_config_paths {
    my @paths = (
        '~/gfw-config.ini',
        '/etc/gfw-config.ini',
    );

    return map { path($_) } @paths;
}

sub _default_config_values {
    return {
        host_defaults => {
            'path-to-tar' => 'tar',
            'path-to-ssh' => 'ssh',
        }
    };
}

sub get_value {
    my ($self, @key_path) = @_;

    return $self->_search($self->_parsed_config, @key_path);
}

sub get_host_paths {
    my $self = shift;

    my $host_path_line = $self->get_value(@_);

    my @host_paths = split /\s*,\s*/, $host_path_line;

    return gather {
        foreach my $host_path (@host_paths) {
            my ($host, $path) = split /\s*:\s*/, $host_path;
            take { host => $host, path => path($path) };
        }
    };
}

sub _search {
    my ($self, $tree, @key_path) = @_;

    return if ! @key_path;

    my $key = shift @key_path;
    return undef if ! exists $tree->{$key};
    return $tree->{$key} if ! @key_path;
    return $self->_search($tree->{$key}, @key_path);
}

sub load_host_config {
    my ($self, $host_config_name) = @_;

    my %config = %{
        merge(
            $self->get_value('host_defaults'),
            $self->get_value($host_config_name)
        )
    };

    # Rename values for Net::OpenSSH
    $config{ssh_cmd} = delete $config{'path-to-ssh'}
        if exists $config{'path-to-ssh'};

    # Change - to _ in keys
    $config{$_ =~ s/-/_/gr} = delete $config{$_}
        for grep { /-/ } keys %config;

    return \%config;
}

__PACKAGE__->meta->make_immutable;

1;
