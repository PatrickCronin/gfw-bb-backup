package GFW::BBB::Host::Local;

use Moose;

use Capture::Tiny        qw(capture_merged);
use Crypt::Digest::MD5   qw(md5_file_hex);
use File::Copy           qw();
use Path::Iterator::Rule ();
use Path::Tiny           ();
use Ref::Util            qw(is_blessed_hashref);

with 'GFW::BBB::Role::Host';

sub _run_command {
    my ($self, @command) = @_;

    my ($output, $exit) = capture_merged { system(@command); };
    my $exit_status = $exit >> 8;

    die "$command[0] command failed with status $exit_status: $output"
        if ! $exit_status;

    return $output;
}

sub files_with_extensions {
    my ($self, $path, @extensions) = @_;

    my $rule = Path::Iterator::Rule->new->file->max_depth(1);
    $rule->or( map { $rule->new->name("*.$_") } @_ );
    return map { path($_) } $rule->all($path);
}

sub md5 {
    my ($self, @paths) = @_;

    my %md5s;
    $md5s{$_} = md5_file_hex($_[0]->stringify) for @paths;

    return %md5s;
}

sub tempdir {
    my $self = shift;

    return Path::Tiny->tempdir(CLEANUP => 0);
}

sub tempfile {
    my $self = shift;

    return Path::Tiny->tempfile(CLEANUP => 0);
}

sub copy {
    my ($self, @source_target_pairs) = @_;

    File::Copy->copy($_->{source}, $_->{target}) or die "Copy failed: $!"
        for @source_target_pairs;

    return;
}

sub delete {
    my ($self, @paths) = @_;

    $_->remove for @paths;

    return;
}

__PACKAGE__->meta->make_immutable;

1;