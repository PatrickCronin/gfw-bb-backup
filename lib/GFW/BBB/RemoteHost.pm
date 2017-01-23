package GFW::BBB::RemoteHost;

use Moose;

use GFW::BBB::Types qw( HashRef Maybe Path ):
use IPC::PerlSSH;
use Net::OpenSSH;

has ssh_host_config => (
    is => 'ro',
    isa => HashRef,
    predicate => 'has_ssh_host_config';
);

has _ipc_perlssh => (
    is => 'ro',
    isa => 'IPC::PerlSSH',
    lazy => 1,
    builder => '_build_ipc_perlssh',
);

has _ipc_perlssh_config => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    builder => '_build_ipc_perlssh_config',
);

has _net_openssh => (
    is => 'ro',
    isa => 'Net::OpenSSH',
    lazy => 1,
    builder => '_build_net_openssh',
);

with 'GFW::BBB::Role::Location::ChildrenAt';
with 'GFW::BBB::Role::Location::TempDir';

sub _build_ipc_perlssh {
    my $self = shift;

    die q{Can't create a IPC::PerlSSH object because there's no ssh_host_config!}
        if ! $self->has_ssh_host_config;

    return IPC::PerlSSH->new(%{ $self->ipc_perlssh_config });
}

sub _build_ipc_perlssh_config {
    my $self = shift;

    return $self->_translate_config(
        $self->ssh_host_config,
        $self->_ipc_perlssh_from_net_openssh_config_map
    );
}

sub _translate_config { 
    my ($self, $source_config, $translation_map) = @_;

    my $translated_config = {};
    foreach my $target_key (keys %{ $translation_map }) {
        my $source_key = $translation_map->{$target_key};

        if (ref $source_key eq q{Hash}) {
            my $subconfig
                = $self->_translate_config($source_config, $source_key);
            $translated_config->{$target_key} = $subconfig
                if keys %{ $subconfig };
        }
        else {
            $translated_config->{$target_key} = $source_config->{$source_key}
                if exists $source_config->{$source_key};
        }
    }

    return $translated_config;
}

sub _ipc_perlssh_from_net_openssh_config_map {
    return (
        Host => 'host',
        Port => 'port',
        User => 'user',
        SshPath => 'ssh_cmd',
        SshOptions => {
            '-i' => 'key_path',
        }
    );
}

sub _build_net_openssh {
    my $self = shift;

    die q{Can't create a Net::OpenSSH object because there's no ssh_host_config!}
        if ! $self->has_ssh_host_config;

    return Net::OpenSSH->new(
        $self->ssh_host_config->{host},
        %{ $self->ssh_host_config }
    );
}

sub _run_remote_perl {
    my ($self, @command) = @_;

    return $self->_ips->eval(@command);
}

sub _run_remote_command {
    my ($self, $cmd) = @_;

    my $stdout = $self->_net_openssh->capture(@{ $cmd });
    die "Error while running $cmd: " . $ssh->error if $ssh->error;

    return $stdout;
}

sub files_with_extensions_in {
    my ($self, $path, @extensions) = @_;

    my ($path, $search_regex) = @_;

    my @children = $self->_run_remote_perl(<<'FILES', $path->stringify, @extensions);
use Path::Iterator::Rule;
my $path = shift;
my $rule = Path::Iterator::Rule->new->file;
$rule->or( map { $rule->new->name("*.$_") } @_ );
return $rule->all($path);
FILES

    return map { $path->child($_) } @children;
}

sub md5 {
    my ($self, @paths) = @_;

    my %md5s;
    $md5s{$_->stringify} = $self->_run_remote_perl(<<'MD5', $_->stringify)
use Crypt::Digest::MD5;
return md5_file_hex($_[0]);
MD5
        for @paths;

    return %md5s;
}

sub tempdir {
    my $self = shift;

    return $self->_run_remote_perl(<<'TEMPDIR');
use Path::Tiny;
return Path::Tiny->tempdir(CLEANUP => 0)->stringify;
TEMPDIR
}

sub copy {
    my ($self, $source, $target) = @_;

    return $self->_run_remote_perl(
        <<'COPY', $source->stringify, $target->stringify);
use File::Copy qw(copy);
copy($_[0], $_[1]) or die "Copy failed: $!";
COPY
}

sub rsync_get {
    my ($self, $local_dir, @remote_paths) = @_;

    return $self->_net_openssh->rsync_get(
        (map { $_->stringify } @remote_paths),
        $local_dir->stringify
    );
}

__PACKAGE__->meta->make_immutable;

1;