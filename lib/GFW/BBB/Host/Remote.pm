package GFW::BBB::Host::Remote;

use Moose;

use IPC::PerlSSH;
use List::Gather qw(gather take);
use List::Util qw(pairs);
use Net::OpenSSH;
use Path::Tiny qw(path);
use Ref::Util qw(is_plain_arrayref);
use Try::Tiny qw(catch try);

has _ipc_perlssh => (
    is => 'ro',
    isa => 'IPC::PerlSSH',
    lazy => 1,
    builder => '_build_ipc_perlssh',
);

has _ipc_perlssh_config => (
    is => 'ro',
    isa => 'ArrayRef',
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

    return IPC::PerlSSH->new(@{ $self->_ipc_perlssh_config });
}

sub _build_ipc_perlssh_config {
    my $self = shift;

    return $self->_translate_config(
        $self->host_config,
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

    return [ gather {
        foreach my $pair (pairs @{ $translation_map }) {
            if (is_plain_arrayref($pair->[1])) {
                my $subconfig =
                    $self->_translate_config($source_config, $pair->[1]);
                take $pair->[0], $subconfig if @{ $subconfig };
            }
            else {
                take $pair->[0], $source_config->{$pair->[1]}
                    if exists $source_config->{$pair->[1]};
            }
        }
    } ];
}

sub _ipc_perlssh_from_net_openssh_config_map {
    return [
        Host => 'host',
        Port => 'port',
        User => 'user',
        SshPath => 'path_to_ssh',
        SshOptions => [
            '-i' => 'key_path',
        ],
        Perl => 'path_to_perl'
    ];
}

sub _build_net_openssh {
    my $self = shift;

    return Net::OpenSSH->new(
        $self->host_config->{host},
        map { $_ => $self->host_config->{$_} }
            grep { $_ !~ /path_to_/ }
            keys %{ $self->host_config }
    );
}

sub _run_perl {
    my ($self, @command) = @_;

    return $self->_ipc_perlssh->eval(@command);
}

sub _run_command {
    my ($self, @command) = @_;

    my $output = $self->_net_openssh->capture(@command);

    die "Error while running @command: " . $self->_net_openssh->error
        if $self->_net_openssh->error;

    die "@command failed: $output" if $?;

    return $output;
}

sub files_with_extensions {
    my ($self, $path, @extensions) = @_;

    my $script = 'use ' . $self->_required_modules->{find} . ';' . <<'SCRIPT';
        my $path = shift;
        my $rule = Path::Iterator::Rule->new->file->max_depth(1);
        $rule->or( map { $rule->new->name("*.$_") } @_ );
        return $rule->all($path);
SCRIPT

    my @children = $self->_run_perl($script, $path, @extensions);

    return map { path($_) } @children;
}

sub md5 {
    my ($self, @paths) = @_;

    my $script = 'use ' . $self->_required_modules->{md5}
         . ' qw(md5_file_hex);' . <<'SCRIPT';
        return md5_file_hex($_[0]);
SCRIPT

    my %md5s;
    $md5s{$_} = $self->_run_perl($script, $_->stringify) for @paths;

    return %md5s;
}

sub tempdir {
    my $self = shift;

    my $script = 'use ' . $self->_required_modules->{path} . ';' . <<'SCRIPT';
        return Path::Tiny->tempdir(CLEANUP => 0);
SCRIPT

    return path($self->_run_perl($script));
}

sub tempfile {
    my $self = shift;

    my $script = 'use ' . $self->_required_modules->{path} . ';' . <<'SCRIPT';
        return Path::Tiny->tempfile(CLEANUP => 0);
SCRIPT

    return path($self->_run_perl($script));
}

sub copy {
    my ($self, @source_target_pairs) = @_;

    my $script = 'use ' . $self->_required_modules->{copy} . ' qw(copy);'
        . <<'SCRIPT';
        use List::Util qw(pairs);
        my @source_target_pairs = @_;
        copy($_->[0], $_->[1]) or die "Copy failed: $!"
            for pairs @source_target_pairs;
SCRIPT

    return $self->_run_perl(
        $script,
        map { $_->{source}, $_->{target} } @source_target_pairs
    );
}

sub delete {
    my ($self, @paths) = @_;

    my $script = 'use ' . $self->_required_modules->{path} . ' qw(path);'
        . <<'SCRIPT';
        my @paths = @_;
        path($_)->remove for @paths;
SCRIPT
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
            $self->_run_perl('use ' . $module . ';');
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