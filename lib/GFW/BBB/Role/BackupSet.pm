package GFW::BBB::Role::BackupSet;

use Moose::Role;

use GFW::BBB::Types qw(ArrayRef Path Str);

has backup_set_root => (
    is => 'ro',
    isa => Path,
    required => 1,
);

has members => (
    is => 'ro',
    isa => ArrayRef[ Str ],
    required => 1,
);

sub BUILD {
    my $self = shift;

    # May need to check that we have at least one member?
    die "No members provided" if ! scalar @{ $self->members };
}

sub member_file_extensions {
    return qw(4dd 4dIndex Match);
}

1;