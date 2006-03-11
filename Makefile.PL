#!/usr/bin/perl

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;

eval q{
    use Apache::TestMM qw(test clean);

    # accept the configs from command line
    Apache::TestMM::filter_args();
    Apache::TestMM::generate_script('t/TEST');
};

WriteMakefile(
    NAME              => 'Apache2::JSONRPC',
    VERSION_FROM      => 'lib/Apache2/JSONRPC.pm', # finds $VERSION
    PREREQ_PM         => {
        'mod_perl2'     =>      2.000001,
        'JSON::Syck'    =>      0,
        'Apache::Test'  =>      0,
    },
    clean             => { FILES => "@{ clean_files() }" },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Apache2/JSONRPC.pm', # retrieve abstract from module
       AUTHOR         => 'Tyler MacDonald <japh@crackerjack.net>') : ()),
);

            
sub clean_files {
    return [ 't/TEST' ];
}
