package GFW::BBB::DataSet;

use Moose;

use Data::Compare;
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

sub new_from_consistent_copy {
	my ($self, $target_dir) = @_;

	# source member full path => target member full path
	my %members_map = map {
		$_ => $target_dir->child($_->basename)
	} $self->_full_path_members;

	my $max_attempts = $self->_config->get_value(qw(
		create-new-production-backup
		max-backup-attempts
	));
	my $current_attempt = 0;
	while ($current_attempt < $max_attempts) {
		my %source_md5s = $self->_trim_keys_to_basename(
			$self->host->md5( keys %members_map )
		);

		$self->host->copy( $_, $members_map{$_} )
			for keys %members_map;

		my %target_md5s = $self->_trim_keys_to_basename(
			$self->host->md5( values %members_map )
		);

		return GFW::BBB::DataSet->new(
	        host => $self->host,
	        dataset_root => $target_dir,
	        members => $self->members
	    ) if $self->_md5s_are_consistent(\%source_md5s, \%target_md5s);

		$current_attempt++;
	};

	die "Failed to create a consistent copy within $max_attempts attempts.";
}

sub _full_path_members {
	my $self = shift;

	return map { $self->dataset_root->child($_) } @{ $self->members };
}

sub _trim_keys_to_basename {
	my ($self, %hash) = @_;

	$hash{ $_->basename } = delete $hash{$_}
		for keys %hash;

	return %hash;
}

sub _md5s_are_consistent {
	my ($self, $source_md5s, $target_md5s) = @_;

	return Data::Compare->new->Cmp($source_md5s, $target_md5s);
}

sub rsync_to_local {
	my ($self, $local_dir) = @_;

	return $self->remote_host->rsync_get($local_dir, @{ $self->members });
}

__PACKAGE__->meta->make_immutable;

1;