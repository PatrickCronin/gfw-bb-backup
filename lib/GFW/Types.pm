package GFW::Types;

use MooseX::Types::Moose qw(ArrayRef HashRef Str Maybe);
use MooseX::Types::Path::Tiny qw(Path Paths);

use MooseX::Types -declare => [
	qw(
		ArrayRef
        HashRef
		Maybe
		Path
		Paths
		Str
	)
];

# subtype NonEmptyArrayRefOfPaths,
#	as ArrayRef[Path],
#	where { scalar @$_ > 0 };

1;