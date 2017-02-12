package GFW::BBB::ProductionBackupCreator;

use Moose;

use GFW::BBB::Host::Factory;
use GFW::BBB::LRDataSet;
use MooseX::Types::Path::Tiny qw(Path);
use Lingua::EN::Inflect qw(NO);
use Path::Tiny qw(path);
use Try::Tiny qw(catch try);

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

has _production_dataset => (
    is => 'ro',
    isa => 'GFW::BBB::LRDataSet',
    lazy => 1,
    builder => '_build_production_dataset',
);

has _consistent_dataset_copy => (
    is => 'ro',
    isa => 'GFW::BBB::LRDataSet',
    lazy => 1,
    builder => '_build_consistent_dataset_copy',
    predicate => '_has_consistent_dataset_copy',
);

has _compressed_dataset_copy => (
    is => 'ro',
    isa => 'GFW::BBB::LRPath',
    lazy => 1,
    builder => '_build_compressed_dataset_copy',
    predicate => '_has_compressed_dataset_copy',
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

sub DEMOLISH {
    my $self = shift;

    $self->_consistent_dataset_copy->delete
        if $self->_has_consistent_dataset_copy;

    $self->_compressed_dataset_copy->delete
        if $self->_has_compressed_dataset_copy;
};

sub _build_production_host_path {
    my $self = shift;

    return (
        $self->_config->get_host_paths(qw(
            create-new-production-backup
            production-backup
        ))
    )[0];
}

sub _build_production_host {
    my $self = shift;

    return GFW::BBB::Host::Factory->new_from_config(
        $self->_production_host_path->{host},
        $self->_config->load_host_config(
            $self->_production_host_path->{host}
        )
    );
}

sub _build_production_dataset {
    my $self = shift;

    return GFW::BBB::LRDataSet->new(
        host => $self->_production_host,
        dataset_root => $self->_production_host_path->{path},
        members => $self->_find_production_dataset_members,
    );
}

sub _build_consistent_dataset_copy {
    my $self = shift;

    return $self->_production_dataset->new_from_consistent_copy_at(
        $self->_production_host->tempdir
    );
}

sub _build_compressed_dataset_copy {
    my $self = shift;

    return $self->_consistent_dataset_copy->compress_to(
        $self->_production_host->tempfile
    );
}

sub _find_production_dataset_members {
    my $self = shift;
    
    my @required_extensions = GFW::BBB::LRDataSet->member_file_extensions;

    my @found = $self->_production_host->files_with_extensions(
        $self->_production_host_path->{path},
        @required_extensions
    );

    my $alternation_string = join q{|}, @required_extensions;
    my $search_regex = qr/ \. (?:$alternation_string) \z/x;

    my %basename;
    $basename{ $_->basename =~ s{$search_regex}{}r }++ for @found;

    my @viable_basenames = grep {
        $basename{$_} == @required_extensions
    } keys %basename;

    die NO(' suitable backup set', scalar @viable_basenames)
        . ' were found on the production server at '
        . $self->_production_host_path->{path}
        if @viable_basenames != 1;

    return [
        map { 
            $self->_production_host_path->{path}
                ->child($viable_basenames[0] . q{.} . $_)
        } @required_extensions
    ];
}

sub run {
    my $self = shift;

    try {
        $self->_compressed_dataset_copy->transfer_to($_)
            for $self->_config->get_host_paths(qw(
                create-new-production-backup
                archives
            ));
    }
    catch {
        warn $_;
    };
}

__PACKAGE__->meta->make_immutable;

1;
