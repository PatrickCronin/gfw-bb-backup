package GFW::BBB::LRDataSet;

use Moose;

use GFW::BBB::LRPath ();
use Lingua::EN::Inflect qw(NO);
use MooseX::Types::Path::Tiny qw(Path Paths);

has host => (
	is => 'ro',
	does => 'GFW::BBB::Role::Host',
	required => 1,
);

has dataset_root => (
    is => 'ro',
    isa => Path,
    required => 1,
);

has members => (
    is => 'ro',
    isa => Paths,
    required => 1,
);

sub member_file_extensions {
    return qw(4dd 4DIndx Match);
}

sub new_from_consistent_copy_at {
	my ($self, $target_dir) = @_;

	my @source_target_pairs =
		map {
			{
				source => $_,
				target => $target_dir->child($_->basename)
			}
		} @{ $self->members };

	$self->host->consistent_copy(@source_target_pairs);

	return GFW::BBB::LRDataSet->new(
        host => $self->host,
        dataset_root => $target_dir,
        members => $self->members
    );
}

sub compress_to {
	my ($self, $target_file) = @_;

	$self->host->compress(
		$target_file,
		$self->dataset_root,
		@{ $self->members }
	);

	return GFW::BBB::LRPath->new(
		host => $self->host,
		path => $target_file
	);
}

sub delete {
	my $self = shift;

	$self->host->delete($_) for @{ $self->members }, $self->dataset_root;
}

__PACKAGE__->meta->make_immutable;

1;