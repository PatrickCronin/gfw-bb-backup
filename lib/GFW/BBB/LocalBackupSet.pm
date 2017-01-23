package GFW::BBB::LocalBackupSet;

use Moose;

with qw(
    GFW::BBB::Role::BackupSet
    GFW::BBB::Role::HasConfig
);


__PACKAGE__->meta->make_immutable;

1;