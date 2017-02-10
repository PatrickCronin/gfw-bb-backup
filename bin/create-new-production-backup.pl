#!/usr/bin/env perl

use Modern::Perl;

use GFW::BBB::ProductionBackupCreator;

GFW::BBB::ProductionBackupCreator->new_with_options->run;
