# Makefile.PL for XML::Hash::XS.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
# Copyright 2012 Yuriy Ustushenko, all rights reserved.
#
# Derived from the module XML::LibXML
# Copyright 2001-2003 AxKit.com Ltd., 2002-2006 Christian Glahn, 2006-2009 Petr Pajas

use 5.008008;
use ExtUtils::MakeMaker;
use Config;
use Symbol;
use File::Spec;
use Cwd;

my (%config, $DEVNULL, $is_Win32, $DEBUG);

$| = 0;

$is_Win32 = ($^O =~ /Win32/);
if ($is_Win32) {
    $DEVNULL = 'DEVNULL';
}
else {
    $DEVNULL = eval { File::Spec->devnull };
    if ($@) { $DEVNULL = '/dev/null' }
}

# common information
my %INFO = (
    NAME          => 'XML::Hash::XS',
    VERSION_FROM  => 'lib/XML/Hash/XS.pm', # finds $VERSION
    ABSTRACT_FROM => 'lib/XML/Hash/XS.pm', # retrieve abstract from module
    AUTHOR        => 'Yuriy Ustushenko <yoreek@yahoo.com>',
    LICENSE       => "perl",
    PREREQ_PM     => {
        'Scalar::Util' => 0,
        'Test::More'   => 0,
    },
);

# read extra configurations from the commandline
{
    my %params;
    @params{qw(DEBUG DEFINE INC LIBS XMLPREFIX NO_THREADS LDFLAGS)}=();

    @ARGV = grep {
        my ($key, $val) = split(/=/, $_, 2);
        if (exists $params{$key}) {
            $config{$key} = $val; 0
        } else { 1 }
    } @ARGV;

    # switch Debugging messages on
    $DEBUG = delete $config{DEBUG};

    if ( $DEBUG and $is_Win32 ) {
        warn "win32 compile\n";
    }
}

# get the libxml2 configuration
unless ( $is_Win32 ) { # cannot get config in W32
    my $xml2cfg = "xml2-config";
    my $libprefix = $ENV{XMLPREFIX} || $config{XMLPREFIX};

    delete $config{XMLPREFIX}; # delete if exists, otherwise MakeMaker gets confused

    if ( defined $libprefix ) {
        $xml2cfg = $libprefix . '/bin/' . $xml2cfg;
    }

    # if a user defined INC and LIBS on the command line we must not
    # override them
    if ( not defined $config{LIBS} and not defined $config{INC} ) {
        print "running xml2-config...";
        eval {
            try_libconfig( $xml2cfg, \%config, @blacklist );
        };

        if ($@) {
            if ( not defined $config{LIBS} and not defined $config{INC} ) {
                warn "\nusing fallback values for LIBS and INC\n";
                $config{LIBS} = '-L/usr/local/lib -L/usr/lib -L/usr/pkg/lib -L/opt/local/lib -lxml2 -lm';
                $config{INC} = '-I/usr/include/libxml2 -I/usr/include '.
                               '-I/usr/local/include -I/usr/local/include/libxml2 '.
                               '-I/usr/pkg/include/libxml2 -I/usr/pkg/include '.
                               '-I/opt/local/include/libxml2 -I/opt/local/include';
                print <<OPT;
options:
  LIBS='$config{LIBS}'
  INC='$config{INC}'
If this is wrong, Re-run as:
  \$ $^X Makefile.PL LIBS='-L/path/to/lib' INC='-I/path/to/include'

OPT
            }
        }
    }
}

# fix the ld flags
if ($config{LIBS} !~ /\-l(?:lib)?xml2\b/) {
    # in this case we are not able to run xml2-config. therefore we need to
    # expand the libz as well.
    if ($is_Win32) {
        if( $ENV{ACTIVEPERL_MINGW} ) {
            $config{LIBS} .= ' -llibxml2.lib -lzlib.lib';
        } else {
            $config{LIBS} .= ' -llibxml2 -lzlib';
        }
    } else {
        $config{LIBS} .= ' -lxml2 -lz -lm';
    }
}

if ($config{LIBS} !~ /\-lz\b/ and !($is_win32 && $config{LIBS} !~ /\-lzlib\b/)) {
    # note if libxml2 has not -lz within its cflags, we should not use
    # it! We should trust libxml2 and assume libz is not available on the
    # current system (this is ofcourse not true with win32 systems.
    # $config{LIBS} .= $is_Win32 ? ' -lzlib' :' -lz';
    if ( $config{DEBUG} ) {
        warn "zlib was not configured\n";
        warn "set zlib\n" if $is_Win32;
    }
    if ($is_Win32) {
        if( $ENV{ACTIVEPERL_MINGW} ) {
            $config{LIBS} .= ' -lzlib.lib';
        } else {
            $config{LIBS} .= ' -lzlib';
        }
    } else {
        $config{LIBS} .= ' -lz';
    }
}

# test if the libraries are really installed!
unless ( have_library("xml2") ) {
    print STDERR <<DEATH;
libxml2 not found
Try setting LIBS and INC values on the command line
Or get libxml2 from
  http://xmlsoft.org/
If you install via RPMs, make sure you also install the -devel
RPMs, as this is where the headers (.h files) are.

Also, you may try to run perl Makefile.PL with the DEBUG=1 parameter
to see the exact reason why the detection of libxml2 installation
failed or why Makefile.PL was not able to compile a test program.
DEATH
    exit 0; # 0 recommended by http://cpantest.grango.org (Notes for CPAN Authors)
}

# _NOW_ write the Makefile
my $ldflags = delete $config{LDFLAGS};
if ($ldflags) {
    $config{dynamic_lib} = { OTHERLDFLAGS => " $ldflags " };
}

WriteMakefile(
    %INFO,
    %config,
);


# Functions
#  - these should really be in MakeMaker... But &shrug;
sub rm_f {
    my @files = @_;
    my @realfiles;
    foreach (@files) {
        push @realfiles, glob($_);
    }
    if (@realfiles) {
        chmod(0777, @realfiles);
        unlink(@realfiles);
    }
}

sub rm_fr {
    my @files = @_;
    my @realfiles;
    foreach (@files) {
        push @realfiles, glob($_);
    }
    foreach my $file (@realfiles) {
        if (-d $file) {
            # warn("$file is a directory\n");
            rm_fr("$file/*");
            rm_fr("$file/.exists");
            rmdir($file) || die "Couldn't remove $file: $!";
        }
        else {
            # warn("removing $file\n");
            chmod(0777, $file);
            unlink($file);
        }
    }
}

sub xsystem {
    my $command = shift;
    if ($DEBUG) {
        print $command, "\n";
        if (system($command) != 0) {
            die "system call to '$command' failed";
        }
        return 1;
    }
    open(OLDOUT, ">&STDOUT");
    open(OLDERR, ">&STDERR");
    open(STDOUT, ">$DEVNULL");
    open(STDERR, ">$DEVNULL");
    my $retval = system($command);
    open(STDOUT, ">&OLDOUT");
    open(STDERR, ">&OLDERR");
    if ($retval != 0) {
        die "system call to '$command' failed";
    }
    return 1;
}

sub backtick {
    my $command = shift;
    if ($DEBUG) {
        print $command, "\n";
        my $results = `$command`;
        chomp $results;
        if ($? != 0) {
            die "backticks call to '$command' failed";
        }
        return $results;
    }
    open(OLDOUT, ">&STDOUT");
    open(OLDERR, ">&STDERR");
    open(STDOUT, ">$DEVNULL");
    open(STDERR, ">$DEVNULL");
    my $results = `$command`;
    my $retval = $?;
    open(STDOUT, ">&OLDOUT");
    open(STDERR, ">&OLDERR");
    if ($retval != 0) {
        die "backticks call to '$command' failed";
    }
    chomp $results;
    return $results;
}

sub try_link0 {
    my ($src, $opt) = @_;
    my $cfile = gensym();
    #local $config{LIBS};
    #$config{LIBS} .= $opt;
    unless (mkdir(".testlink", 0777)) {
        rm_fr(".testlink");
        mkdir(".testlink", 0777) || die "Cannot create .testlink dir: $!";
    }
    chdir(".testlink");
    open($cfile, ">Conftest.xs") || die "Cannot write to file Conftest.xs: $!";
print $cfile <<EOT;
#ifdef __cplusplus
extern "C" {
#endif
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#ifdef __cplusplus
}
#endif

EOT
    print $cfile $src;
    print $cfile <<EOT;

MODULE = Conftest          PACKAGE = Conftest

PROTOTYPES: DISABLE

EOT
    close($cfile);
    open($cfile, ">Conftest.pm") || die "Cannot write to file Conftest.pm: $!";
    print $cfile <<'EOT';
package Conftest;
$VERSION = 1.0;
require DynaLoader;
@ISA = ('DynaLoader');
bootstrap Conftest $VERSION;
1;
EOT
    close($cfile);
    open($cfile, ">Makefile.PL") || die "Cannot write to file Makefile.PL: $!";
    print $cfile <<'EOT';
use ExtUtils::MakeMaker;
my %config;
while($_ = shift @ARGV) {
    my ($k, $v) = split /=/, $_, 2;
    warn("$k = $v\n");
    $config{$k} = $v;
}
WriteMakefile(NAME => "Conftest", VERSION_FROM => "Conftest.pm", %config);
EOT
    close($cfile);
    open($cfile, ">test.pl") || die "Cannot write to file test.pl: $!";
    print $cfile <<EOT;
use Test; BEGIN { plan tests => 1; } END { ok(\$loaded) }
use Conftest; \$loaded++;
EOT
    close($cfile);
    my $quote = $is_Win32 ? '"' : "'";
    xsystem("$^X Makefile.PL " . join(' ', map { "${quote}$_=$config{$_}${quote}" } keys %config));

    # I am not shure if OTHERLDFLAGS is really required - at least the
    # libraries to include do not belong here!
    # I would assume a user to set OTHERLDFLAGS in the %config if they are
    # really required. if done so, we don't have to pass them here ...
    xsystem("$Config{make} test ${quote}OTHERLDFLAGS=${opt}${quote}");
} # end try_link0

sub try_link {
    my $start_dir = cwd();
    my $result = eval {
        try_link0(@_);
    };
    warn $@ if $DEBUG && $@;
    chdir($start_dir);
    rm_fr(".testlink");
    return $result;
}

sub have_library {
    my ($lib, $func) = (@_, "blank");
    printf("checking for %s() in -l%s... ", $func, $lib) if $func ne "blank";
    printf("looking for -l%s... ", $lib) if $func eq "blank";

    my $result;
    if ($func) {
        my $libs = $is_Win32 ? " $lib.lib  " : "-l$lib";
#        my $libs = "-l$lib";
        if ($is_Win32) {
            $result = try_link(<<"SRC", undef);
#include <windows.h>
#include <winsock.h>
#include <libxml/parser.h>
blank() { xmlInitParser(); return 0; }
int t() { ${func}(); return 0; }
SRC
            unless ($result) {
                $result = try_link(<<"SRC", undef);
#include <windows.h>
#include <winsock.h>
#include <libxml/parser.h>
blank() { xmlInitParser(); return 0; }
int t() { void ((*p)()); p = (void ((*)()))${func}; return 0; }
SRC
            }
        }
        else {
            $result = try_link(<<"SRC", undef);
#include <libxml/parser.h>
blank() { xmlInitParser(); return 0; }
int t() { ${func}(); return 0; }
SRC
        }
    }

    unless ($result) {
        print "no\n";
        return 0;
    }

    if ($func ne "main") {
        $config{DEFINE} .= uc(" -Dhave_$func");
    }

    print "yes\n";
    return 1;
}

# try_libconfig class a generic config file and requests --version, --libs and
# --cflags
sub try_libconfig {
    my $cfgscript = shift;
    my $config = shift;

    my $ver = backtick("$cfgscript --version");
    if ( defined $ver ) {
        $config->{LIBS} = backtick("$cfgscript --libs");
        $config->{INC}  = backtick("$cfgscript --cflags");

        print "ok ($ver)\n";
    }
    else {
        print "failed\n";
        die "FAILED\n"; # strange error
    }
}
