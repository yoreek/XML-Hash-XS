package XML::Hash::XS;

use 5.008008;
use strict;
use warnings;

use Scalar::Util qw(openhandle);
use base 'Exporter';
our @EXPORT_OK = our @EXPORT = qw( hash2xml );

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('XML::Hash::XS', $VERSION);

sub hash2xml {
	my ($hash, %options) = @_;

    $options{root}     ||= 'root';
    $options{version}  ||= '1.0';
    $options{encoding} ||= 'utf-8';
    $options{indent}     = $options{indent} ? 1 : 0;

    my $output = $options{output} || 'string';

    if ( $output eq 'string' ) {
        _hash2xml2string( $hash, @options{qw( root version encoding indent )} );
    }
    elsif ( my $fh = $output ) {
        _hash2xml2fh( $fh, $hash, @options{qw( root version encoding indent )} );
    }
    else {
        die "Invalid output type: '".ref($output)."'";
    }
}

sub __write {
    if ( ref( $_[0] ) ) {
        $_[0]->write( $_[1], $_[2] );
    }
    else {
        $_[0]->write( $_[1] );
    }
}

1;
__END__
=head1 NAME

XML::Hash::XS - Simple and fast hash to XML conversion

=head1 SYNOPSIS

    use XML::Hash::XS;

    my $xmlstr = hash2xml \%hash;
    hash2xml \%hash, output => $FH;

=head1 DESCRIPTION

This module implements simple hash to XML converter written in C using libxml2 library.

=head1 FUNCTIONS

=head2 hash2xml $hash, [ %options ]

$hash is reference to hash

=head1 OPTIONS

=over 4

=item root [ = 'root' ]

Root node name.

=item version [ = '1.0' ]

XML document version

=item encoding [ = 'utf-8' ]

XML output encoding

=item indent [ = 0 ]

if idnent is "1", XML output should be indented according to its hierarchic structure.

if indent is "0", XML output will all be on one line.

=item output [ = undef ]

XML output method

if output is undefined, XML document dumped into string.

if output is FH, XML document writes directly to a filehandle or a stream.

=back

=head1 AUTHOR

=over 4

Yuriy Ustushenko, E<lt><yoreek@yahoo.com>E<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 Yuriy Ustushenko

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
