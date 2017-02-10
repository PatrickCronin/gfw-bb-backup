package GFW::Config;

use MooseX::Singleton;

use Config::INI::Reader;
use List::Gather qw(gather take);
use List::Util qw(any);
use Path::Tiny qw(path);

has _parsed_config => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_parsed_config',
);

sub _build_parsed_config {
    my $self = shift;

    my @possible_config_paths = $self->_possible_config_paths;

    my ($selected_config) = grep { $_->exists } @possible_config_paths;

    return Config::INI::Reader->read_file( $selected_config )
        if $selected_config;

    die "Could not find an existing file. Search at:\n\t-"
        . (join "\n\t-", @possible_config_paths);
}

sub _possible_config_paths {
    my @paths = (
        '~/gfw-config.ini',
        '/etc/gfw-config.ini',
    );

    return map { path($_) } @paths;
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
            take { host => $host, path => $path };
        }
    };
}

sub _search {
    my ($self, $tree, @key_path) = @_;

    return if ! @key_path;

    my $key = shift @key_path;
    die "Could not find key $key" if ! exists $tree->{$key};
    return $tree->{$key} if ! @key_path;
    return $self->_search($tree->{$key}, @key_path);
}


sub load_ssh_host_config {
    my ($self, $host_config_name) = @_;

    my %config;

    my $ssh_cmd = $self->get_value(qw( general ssh-cmd ));
    $config{ssh_cmd} = $ssh_cmd if $ssh_cmd;

    my $host_config = $self->get_value($host_config_name);

    for my $configured_key (keys %{ $host_config }) {
        $config{$configured_key =~ s/-/_/r}
            = $host_config->{$configured_key}
    }

    return \%config;
}

__PACKAGE__->meta->make_immutable;

1;
