package GFW::BBB::Host::Local;

use Moose;

use Crypt::Digest::MD5   qw(md5_file_hex);
use File::Copy           ();
use Path::Iterator::Rule ();
use Path::Tiny           ();
use Ref::Util            qw(is_blessed_hashref);

with 'GFW::BBB::Role::Host';

sub files_with_extensions {
    my ($self, $path, @extensions) = @_;

    my $rule = Path::Iterator::Rule->new->file;
    $rule->or( map { $rule->new->name("*.$_") } @_ );
    return map { $path->child($_) } $rule->all($path);
}

sub md5 {
    my ($self, @paths) = @_;

    my %md5s;
    $md5s{$_->stringify} = md5_file_hex($_[0]->stringify) for @paths;

    return %md5s;
}

sub tempdir {
    my $self = shift;

    return Path::Tiny->tempdir(CLEANUP => 0);
}

sub copy {
    my ($self, $source, $target) = @_;

    my $result = File::Copy->copy($source, $target) or die "Copy failed: $!";

    return $result;
}

__PACKAGE__->meta->make_immutable;

1;