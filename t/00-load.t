#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'GFW::BBB::Config' ) || print "Bail out!\n";
    use_ok( 'GFW::BBB::BackupSet' ) || print "Bail out!\n";
    use_ok( 'GFW::BBB::ISOImage' ) || print "Bail out!\n";
}

diag( "Testing GFW::BBB::Config $GFW::BBB::Config::VERSION, Perl $], $^X" );
