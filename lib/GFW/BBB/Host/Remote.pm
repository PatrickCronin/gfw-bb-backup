package GFW::BBB::Host::Remote;

use Moose;

use IPC::PerlSSH;
use Net::OpenSSH;
use Try::Tiny qw(catch try);

has ssh_host_config => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_ssh_host_config',
);

has _ipc_perlssh => (
    is => 'ro',
    isa => 'IPC::PerlSSH',
    lazy => 1,
    builder => '_build_ipc_perlssh',
);

has _ipc_perlssh_config => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_ipc_perlssh_config',
);

has _net_openssh => (
    is => 'ro',
    isa => 'Net::OpenSSH',
    lazy => 1,
    builder => '_build_net_openssh',
);

has _required_modules => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
    builder => '_build_required_modules',
);

with 'GFW::BBB::Role::Host';

sub _build_ipc_perlssh {
    my $self = shift;

    die q{Can't create a IPC::PerlSSH object because there's no ssh_host_config!}
        if ! $self->has_ssh_host_config;

    return IPC::PerlSSH->new(%{ $self->_ipc_perlssh_config });
}

sub _build_ipc_perlssh_config {
    my $self = shift;

    return $self->_translate_config(
        $self->ssh_host_config,
        $self->_ipc_perlssh_from_net_openssh_config_map
    );
}

sub _build_required_modules {
    my $self = shift;

    return {
        copy => 'File::Copy',
        find => 'Path::Iterator::Rule',
        md5  => 'Crypt::Digest::MD5',
        path => 'Path::Tiny',
    };
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
    return {
        Host => 'host',
        Port => 'port',
        User => 'user',
        SshPath => 'ssh_cmd',
        SshOptions => {
            '-i' => 'key_path',
        },
        Perl => 'perl'
    };
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

    return $self->_ipc_perlssh->eval(@command);
}

sub _run_remote_command {
    my ($self, $cmd) = @_;

    my $stdout = $self->_net_openssh->capture(@{ $cmd });
    die "Error while running $cmd: " . $self->_net_openssh->error
        if $self->_net_openssh->error;

    return $stdout;
}

sub files_with_extensions {
    my ($self, $path, @extensions) = @_;

    my $script = 'use ' . $self->_required_modules->{find} . ';' . <<'SCRIPT';
my $path = shift;
my $rule = Path::Iterator::Rule->new->file;
$rule->or( map { $rule->new->name("*.$_") } @_ );
return $rule->all($path);
SCRIPT

    my @children = $self->_run_remote_perl(
        $script, $path->stringify, @extensions);

    return map { $path->child($_) } @children;
}

sub md5 {
    my ($self, @paths) = @_;

    my $script = 'use ' . $self->_required_modules->{md5} . ';' . <<'SCRIPT';
return md5_file_hex($_[0]);
SCRIPT

    my %md5s;
    $md5s{$_->stringify} = $self->_run_remote_perl($script, $_->stringify)
        for @paths;

    return %md5s;
}

sub tempdir {
    my $self = shift;

    my $script = 'use ' . $self->_required_modules->{path} . ';' . <<'SCRIPT';
return Path::Tiny->tempdir(CLEANUP => 0)->stringify;
SCRIPT

    return $self->_run_remote_perl($script);
}

sub copy {
    my ($self, $source, $target) = @_;

    my $script = 'use ' . $self->_required_modules->{copy} . ' qw(copy);'
        . <<'SCRIPT';
copy($_[0], $_[1]) or die "Copy failed: $!";
SCRIPT

    return $self->_run_remote_perl(
        $script, $source->stringify, $target->stringify);
}

sub rsync_put {
    my ($self, $target_path, @source_paths) = @_;

    return $self->_net_openssh->rsync_put(@source_paths, $target_path);
}

sub rsync_get {
    my ($self, $target_path, @source_paths) = @_;

    return $self->_net_openssh->rsync_get(@source_paths, $target_path);
}

sub test_required_modules {
    my $self = shift;

    my $errors;
    foreach my $module (values %{ $self->_required_modules }) {
        try {
            $self->_run_remote_perl('use ' . $module . ';');
            print "The remote host has $module.\n";
        }
        catch {
            print "The remote host does not have $module.\n";
            $errors++;
        };
    }
}

__PACKAGE__->meta->make_immutable;

1;