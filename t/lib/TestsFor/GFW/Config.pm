package TestsFor::GFW::Config;

use Test::Class::Moose;

use GFW::Config;

sub test_config {
    my $self = shift;

    use_ok('GFW::Config');
    my $conf_obj = new_ok('GFW::Config', config_file => 'share/config.ini' );
    my $config = $conf_obj->parsed_config;
    is( ref $config, 'HashRef', 'parsed_config returns a hashref' );

    my %required_sections => (
        'Production SSH Host Config' => '_ssh_host_config',
        'Remote Archive SSH Host Config' => '_ssh_host_config',
        'Production Database' => '_production_database',
        'Archives' => '_archives',
        'Create New Production Backup' => '_create_new_production_backup',
    );
    foreach my $section (keys %required_sections) {
        if (ok( exists $config->{$_}, "Section `$_` exists in the config" )) {
            $self->{ $required_sections{$section} }
        }
        

    }

    


)


}