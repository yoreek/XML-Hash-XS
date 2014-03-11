package XML::Hash::XS;

use 5.008008;
use strict;
no strict 'refs';
use warnings;

use vars qw($VERSION @EXPORT @EXPORT_OK);

use base 'Exporter';
@EXPORT_OK = @EXPORT = qw( hash2xml );

$VERSION = '0.25';

require XSLoader;
XSLoader::load('XML::Hash::XS', $VERSION);

use vars qw($method $output $root $version $encoding $indent $canonical
    $use_attr $content $xml_decl $doc $max_depth $attr $text $trim $cdata $comm
);

# 'NATIVE' or 'LX'
our $method    = 'NATIVE';

# native options
$output    = undef;
$root      = 'root';
$version   = '1.0';
$encoding  = 'utf-8';
$indent    = 0;
$canonical = 0;
$use_attr  = 0;
$content   = undef;
$xml_decl  = 1;
$doc       = 0;
$max_depth = 1024;
$trim      = 0;

# XML::Hash::LX options
$attr      = '-';
$text      = '#text';
$cdata     = undef;
$comm      = undef;

1;
__END__
=head1 NAME

XML::Hash::XS - Simple and fast hash to XML conversion written in C

=head1 SYNOPSIS

    use XML::Hash::XS;

    my $xmlstr = hash2xml \%hash;
    hash2xml \%hash, output => $FH;

Or OOP way:

    use XML::Hash::XS qw();

    my $conv = XML::Hash::XS->new([<options>])
    my $xmlstr = $conv->hash2xml(\%hash, [<options>]);

=head1 DESCRIPTION

This module implements simple hash to XML conversion written in C.

During conversion uses minimum of memory, XML is generated as string or written directly to output file without building DOM.

Some features are optional and are available with appropriate libraries:

=over 2

=item * XML::LibXML library is required  in order to build DOM

=item * ICU or iconv library is required in order to perform charset conversions

=back

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

=item doc [ => 0 ]

if doc is '1', then returned value is L<XML::LibXML::Document>.

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

=item trim [ = 1 ]

Trim leading and trailing whitespace from text nodes

=item method [ = 'NATIVE' ]

experimental support the conversion methods other libraries

if method is 'LX' then conversion result is the same as using L<XML::Hash::LX> library

Note: for 'LX' method following additional options are available:
    attr
    cdata
    text
    comm

=back

=head1 OBJECT_SERIALISATION

=over 2

=item 1. When object has a "toString" method

In this case, the <toString> method of object is invoked in scalar context.
It must return a single scalar that can be directly encoded into XML.

Example:

    use XML::LibXML;
    local $XML::LibXML::skipXMLDeclaration = 1;
    my $doc = XML::LibXML->new->parse_string('<foo bar="1"/>');
    print hash2xml({ doc => $doc }, indent => 2, xml_decl => 0);
    =>
    <root>
      <doc><foo bar="1"/></doc>
    </root>

=item 2. When object has a "iternext" method ("NATIVE" method only)

In this case, the <iternext> method method will invoke a few times until the return value is not undefined.

Example:

    my $count = 0;
    my $o = bless {}, 'Iterator';
    *Iterator::iternext = sub { $count++ < 3 ? { count => $count } : undef };
    print hash2xml({ item => $o }, use_attr => 1, indent => 2, xml_decl => 0);
    =>
    <root>
      <item count="1"/>
      <item count="2"/>
      <item count="3"/>
    </root>

This can be used to generate a large XML using minimum memory, example with DBI:

    my $sth = $dbh->prepare('SELECT * FROM foo WHERE bar=?');
    $sth->execute(...);
    my $o = bless {}, 'Iterator';
    *Iterator::iternext = sub { $sth->fetchrow_hashref() };
    open(my $fh, '>', 'data.xml');
    hash2xml({ row => $o }, use_attr => 1, indent => 2, xml_decl => 0, output => $fh);
    =>
    <root>
      <row bar="..." ... />
      <row bar="..." ... />
      ...
    </root>

=back

=head1 BENCHMARK

Performance benchmark in comparison with some popular modules:

                    Rate     XML::Hash XML::Hash::LX   XML::Simple XML::Hash::XS
    XML::Hash     65.0/s            --           -6%          -37%          -99%
    XML::Hash::LX 68.8/s            6%            --          -33%          -99%
    XML::Simple    103/s           58%           49%            --          -98%
    XML::Hash::XS 4879/s         7404%         6988%         4658%            --

Benchmark was done on L<http://search.cpan.org/uploads.rdf>

=head1 AUTHOR

Yuriy Ustushenko, E<lt>yoreek@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 Yuriy Ustushenko

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
