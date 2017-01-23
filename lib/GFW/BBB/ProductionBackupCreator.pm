package GFW::BBB::ProductionBackupCreator;

use Moose;

use GFW::BBB::RemoteHost;
use GFW::BBB::RemoteBackupSet;
use GFW::BBB::Types qw(ArrayRef);
use Lingua::EN::Inflect qw(NO);

has _production_database_remote_host => (
    is => 'ro',
    isa => 'GFW::BBB::RemoteHost',
    lazy => 1,
    builder => '_build_production_database_remote_host',
);

has _production_backup_set_members => (
    is => 'ro',
    isa => ArrayRef,
    lazy => 1,
    builder => '_build_production_backup_set_members'
);

has _production_backup_set => (
    is => 'ro',
    isa => 'GFW::BBB::BackupSet',
    lazy => 1,
    builder => '_build_production_backup_set'
);

with 'GFW::BBB::Role::HasConfig';

sub _build_production_database_remote_host{
    my $self = shift;

    return GFW::BBB::RemostHost->new(
        ssh_host_config => $self->_config->{'Production Database SSH Host Config'}
    );
}

sub _build_production_backup_set_members {
    my $self = shift;
    
    my @required_extensions = GFW::BBB::RemoteBackupSet->member_file_extensions;

    my @members = $self->_production_database_remote_host
        ->files_with_extensions_in(
            $self->_config->{'Production Database'}->{backup_set_root},
            @required_extensions
        );

    my %basename;
    map { $basename{ s{$search_regex}{}r }++ } @files;
    my @viable_basenames = grep {
        $basename{$_} == @required_extensions
    } keys %basename;

    die NO(' suitable backup set', scalar @viable_basenames)
        . ' were found at on the production server at '
        . $self->_production_backup_set_location->path->stringify
        if @viable_basenames != 1;

    return [ map { $viable_basenames[0] . q{.} . $_ } @required_extensions ];
}

sub _build_production_backup_set {
    my $self = shift;

    return GFW::BBB::RemoteBackupSet->new(
        remote_host => $self->_production_database_remote_host,
        backup_set_root => $self->_config->{'Production Database'}->{fileset_path},
        members => $self->_production_backup_set_members,
    );
}

sub run {
    my $remote_tempdir = $self->_production_backup_set->remote_host->tempdir;
    $self->_production_backup_set
        ->new_from_consistent_copy($remote_tempdir)
        ->rsync_to_local($self->_config->{Archives}{local_archive_path});
}

__PACKAGE__->meta->make_immutable;

1;
