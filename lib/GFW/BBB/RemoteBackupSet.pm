package GFW::BBB::RemoteBackupSet;

use Moose;

use Data::Compare ();
use Lingua::EN::Inflect qw(NO);

has remote_host => (
	is => 'ro',
	isa => 'GFW::BBB::RemoteHost',
	required => 1,
);

with qw(
	GFW::BBB::Role::BackupSet
	GFW::BBB::Role::HasConfig
);

sub new_from_consistent_copy {
	my ($self, $target_dir) = @_;

	# source member full path => target member full path
	my %members_map = map {
		$_ => $target_dir->child($_->basename)
	} $self->_full_path_members;

	my $max_attempts = $self->_config->{'Production Database Settings'}
		->{max_backup_attempts};
	my $current_attempt = 0;

	while ($current_attempt < $max_attempts) {
		my %source_md5s = $self->_trim_keys_to_basename(
			$self->remote_host->md5( keys %members_map )
		);

		$self->remote_host->copy( $_, $members_map{$_} )
			for keys %members_map;

		my %target_md5s = $self->_trim_keys_to_basename(
			$self->remote_host->md5( values %members_map )
		);

		return GFW::BBB::RemoteBackupSet->new(
	        remote_host => $self->remote_host,
	        backup_set_root => $target_dir,
	        members => $self->members
	    ) if $self->_md5s_are_consistent(\%source_md5s, \%target_md5s);

		$current_attempt++;
	};

	die "Failed to create a consistent copy within $max_attempt attempts.";
}

sub _full_path_members {
	my $self = shift;

	return map { $self->backup_set_root->child($_) } @{ $self->members };
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