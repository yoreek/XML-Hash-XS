use 5.008008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'XML::Hash::XS',
    VERSION_FROM  => 'lib/XML/Hash/XS.pm', # finds $VERSION
    ABSTRACT_FROM => 'lib/XML/Hash/XS.pm', # retrieve abstract from module
    PREREQ_PM     => {
        'Scalar::Util' => 0,
        'Test::More'   => 0,
    },
    AUTHOR        => 'Yuriy Ustushenko <yoreek@yahoo.com>',
    LIBS          => ['-lxml2'],
    INC           => '-I. -I/usr/include/libxml2',
);
