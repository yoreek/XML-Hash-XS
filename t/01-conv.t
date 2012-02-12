#!/use/bin/perl

use strict;
use warnings;

use Test::More tests => 11;
use File::Temp qw(tempfile);

use XML::Hash::XS 'hash2xml';

our $data;
our $xml = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    is
        $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] } ),
        qq{$xml\n<root><node1><item>value1</item><item><node2>value2</node2></item></node1></root>\n},
        'default',
    ;
}

{
    is
        $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] }, indent => 1 ),
        <<"EOT",
$xml
<root>
  <node1>
    <item>value1</item>
    <item>
      <node2>value2</node2>
    </item>
  </node1>
</root>
EOT
        'indent',
    ;
}

{
    is
        $data = hash2xml( { node1 => [ 1, '2', '2' + 1 ] } ),
        qq{$xml\n<root><node1><item>1</item><item>2</item><item>3</item></node1></root>\n},
        'integer, string, integer + string',
    ;
}

{
    my $x = 1.1;
    my $y = '2.2';
    is
        $data = hash2xml( { node1 => [ $x, $y, $y + $x ] } ),
        qq{$xml\n<root><node1><item>1.1</item><item>2.2</item><item>3.3</item></node1></root>\n},
        'double, string, double + string',
    ;
}

{
    is
        $data = hash2xml( { 1 => 'value1' } ),
        qq{$xml\n<root><_1>value1</_1></root>\n},
        'quote tag name',
    ;
}

{
    is
        $data = hash2xml( { node1 => \'value1' } ),
        qq{$xml\n<root><node1>value1</node1></root>\n},
        'scalar reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { 'value1' } } ),
        qq{$xml\n<root><node1>value1</node1></root>\n},
        'code reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { undef } } ),
        qq{$xml\n<root><node1/></root>\n},
        'code reference with undef',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { [ 'value1' ] } } ),
        qq{$xml\n<root><node1><item>value1</item></node1></root>\n},
        'code reference with array',
    ;
}

{
    is
        $data = hash2xml( { node1 => 'Тест' }, encoding => 'cp1251' ),
        qq{<?xml version="1.0" encoding="cp1251"?>\n<root><node1>\322\345\361\362</node1></root>\n},
        'encoding support',
    ;
}

{
    my $fh = tempfile();
    hash2xml( { node1 => 'value1' }, output => $fh );
    seek($fh, 0, 0);
    { local $/; $data = <$fh> }
    is
        $data,
        qq{$xml\n<root><node1>value1</node1></root>\n},
        'filehandle output',
    ;
}
