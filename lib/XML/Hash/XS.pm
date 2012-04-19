package XML::Hash::XS;

use 5.008008;
use strict;
no strict 'refs';
use warnings;

use base 'Exporter';
our @EXPORT_OK = our @EXPORT = qw( hash2xml );

our $VERSION = '0.10';

require XSLoader;
XSLoader::load('XML::Hash::XS', $VERSION);

our $root      = 'root';
our $version   = '1.0';
our $encoding  = 'utf-8';
our $indent    = 0;
our $canonical = 0;
our $use_attr  = 0;
our $content   = undef;
our $xml_decl  = 1;

my @OPTIONS_LIST = qw/
    root
    version
    encoding
    indent
    canonical
    use_attr
    content
    xml_decl
/;

sub hash2xml {
	my ($hash, @options) = @_;

    my %options = (
        (map {$_ => ${$_}} @OPTIONS_LIST),
        output => 'string',
        @options,
    );

    my $output = $options{output};

    if ( $output eq 'string' ) {
        _hash2xml2string( $hash, @options{@OPTIONS_LIST} );
    }
    elsif ( ref($output) ) {
        _hash2xml2fh( $output, $hash, @options{@OPTIONS_LIST} );
    }
    else {
        die "Invalid output type";
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

    hash2xml
        {
            node1 => 'value1',
            node2 => [ 'value21', { node22 => 'value22' } ],
            node3 => \'value3',
            node4 => sub { return 'value4' },
            node5 => sub { return { node51 => 'value51' } },
        },
        canonical => 1,
        indent    => 2,
    ;

will convert to:

    <?xml version="1.0" encoding="utf-8"?>
    <root>
      <node1>value1</node1>
      <node2>value21</node2>
      <node2>
        <node22>value22</node22>
      </node2>
      <node3>value3</node3>
      <node4>value4</node4>
      <node5>
        <node51>value51</node51>
      </node5>
    </root>

and (use_attr=1):

    hash2xml
        {
            node1 => 'value1',
            node2 => [ 'value21', { node22 => 'value22' } ],
            node3 => \'value3',
            node4 => sub { return 'value4' },
            node5 => sub { return { node51 => 'value51' } },
        },
        use_attr  => 1,
        canonical => 1,
        indent    => 2,
    ;

will convert to:

    <?xml version="1.0" encoding="utf-8"?>
    <root node1="value1" node3="value3" node4="value4">
      <node2>value21</node2>
      <node2 node22="value22"/>
      <node5 node51="value51"/>
    </root>


=head1 OPTIONS

=over 4

=item root [ = 'root' ]

Root node name.

=item version [ = '1.0' ]

XML document version

=item encoding [ = 'utf-8' ]

XML output encoding

=item indent [ = 0 ]

if indent great than "0", XML output should be indented according to its hierarchic structure.
This value determines the number of spaces.

if indent is "0", XML output will all be on one line.

=item output [ = undef ]

XML output method

if output is undefined, XML document dumped into string.

if output is FH, XML document writes directly to a filehandle or a stream.

=item canonical [ = 0 ]

if canonical is "1", converter will be write hashes sorted by key.

if canonical is "0", order of the element will be pseudo-randomly.

=item use_attr [ = 0 ]

if use_attr is "1", converter will be use the attributes.

if use_attr is "0", converter will be use tags only.

=item content [ = undef ]

if defined that the key name for the text content(used only if use_attr=1).

=item xml_decl [ = 1 ]

if xml_decl is "1", output will start with the XML declaration '<?xml version="1.0" encoding="utf-8"?>'.

if xml_decl is "0", XML declaration will not be output.

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
