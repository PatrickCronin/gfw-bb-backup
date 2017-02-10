package GFW::BBB::ProductionBackupCreator;

use Moose;

use GFW::BBB::Host::Factory;
use GFW::BBB::DataSet;
use MooseX::Types::Path::Tiny qw(Path);
use Lingua::EN::Inflect qw(NO);
use Path::Tiny qw(path);

has _production_host_path => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_production_host_path',
);

has _production_host => (
    is => 'ro',
    does => 'GFW::BBB::Role::Host',
    lazy => 1,
    builder => '_build_production_host',
);

has _production_dataset_members => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy => 1,
    builder => '_build_production_dataset_members'
);

has _production_dataset => (
    is => 'ro',
    isa => 'GFW::BBB::DataSet',
    lazy => 1,
    builder => '_build_production_dataset'
);

has test_required_modules => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'Test the Production Host has the requried modules and quit',
);

with qw(
    GFW::Role::HasConfig
    MooseX::Getopt::Dashes
);

sub _build_production_host_path {
    my $self = shift;

    my ($production_host_path) = $self->_config->get_host_paths(qw(
        create-new-production-backup
        production-backup
    ));

    return $production_host_path;
}

sub _build_production_host {
    my $self = shift;

    return GFW::BBB::Host::Factory->new->new_host_from_config(
        $self->_production_host_path->{host}
    );
}

sub _build_production_dataset_members {
    my $self = shift;
    
    my @required_extensions = GFW::BBB::DataSet->member_file_extensions;

    my @members = $self->_production_host->files_with_extensions(
        path($self->_production_host_path->{path}),
        @required_extensions
    );

    my %basename;
    my $alternation_string = join q{|}, @required_extensions;
    my $search_regex = qr/ \. (?:$alternation_string) \z/x;
    $basename{ $_->stringify =~ s{$search_regex}{}r }++ for @members;
    my @viable_basenames = grep {
        $basename{$_} == @required_extensions
    } keys %basename;

    die NO(' suitable backup set', scalar @viable_basenames)
        . ' were found on the production server at '
        . $self->_production_host_path->{path}
        if @viable_basenames != 1;

    return [ map { path($viable_basenames[0] . q{.} . $_) } @required_extensions ];
}

sub _build_production_dataset {
    my $self = shift;

    return GFW::BBB::DataSet->new(
        host => $self->_production_host,
        dataset_root => path($self->_production_host_path->{path}),
        members => $self->_production_dataset_members,
    );
}

sub run {
    my $self = shift;

    my $consistent_copy = $self->_production_dataset
        ->new_from_consistent_copy($self->_production_dataset);

    my $compressed_copy = $consistent_copy->compress;

    my @archive_host_paths = $self->_config->get_host_paths(qw(
        create-new-production-backup
        archives
    ));

    $self->_production_host->safe_transfer(
        $_->{host},
        $_->{path},
        $compressed_copy->path,
    ) for @archive_host_paths;
}

__PACKAGE__->meta->make_immutable;

1;
