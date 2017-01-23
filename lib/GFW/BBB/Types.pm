package GFW::BBB::Types;

use MooseX::Types -declare => [
	qw(
		ArrayRef
        HashRef
		Location
		NonEmptyArrayRefOfPaths
		Path
		Paths
	)
];

use MooseX::Types::Moose qw(ArrayRef HashRef);
use MooseX::Types::Path::Tiny qw(Path Paths);

subtype NonEmptyArrayRefOfPaths,
	as ArrayRef[Path],
	where { scalar @$_ > 0 };