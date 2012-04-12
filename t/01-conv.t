#!/use/bin/perl

use strict;
use warnings;

use Test::More tests => 18;
use File::Temp qw(tempfile);

use XML::Hash::XS 'hash2xml';

our $data;
our $xml = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    is
        $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] } ),
        qq{$xml\n<root><node1>value1</node1><node1><node2>value2</node2></node1></root>},
        'default',
    ;
}

{
    is
        $data = hash2xml( { node3 => 'value3', node1 => 'value1', node2 => 'value2' }, canonical => 1 ),
        qq{$xml\n<root><node1>value1</node1><node2>value2</node2><node3>value3</node3></root>},
        'canonical',
    ;
}

{
    is
        $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] }, indent => 2 ),
        <<"EOT",
$xml
<root>
  <node1>value1</node1>
  <node1>
    <node2>value2</node2>
  </node1>
</root>
EOT
        'indent',
    ;
}

{
    is
        $data = hash2xml( { node1 => [ 1, '2', '2' + 1 ] } ),
        qq{$xml\n<root><node1>1</node1><node1>2</node1><node1>3</node1></root>},
        'integer, string, integer + string',
    ;
}

{
    my $x = 1.1;
    my $y = '2.2';
    is
        $data = hash2xml( { node1 => [ $x, $y, $y + $x ] } ),
        qq{$xml\n<root><node1>1.1</node1><node1>2.2</node1><node1>3.3</node1></root>},
        'double, string, double + string',
    ;
}

{
    is
        $data = hash2xml( { 1 => 'value1' } ),
        qq{$xml\n<root><_1>value1</_1></root>},
        'quote tag name',
    ;
}

{
    is
        $data = hash2xml( { node1 => \'value1' } ),
        qq{$xml\n<root><node1>value1</node1></root>},
        'scalar reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { 'value1' } } ),
        qq{$xml\n<root><node1>value1</node1></root>},
        'code reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { undef } } ),
        qq{$xml\n<root><node1/></root>},
        'code reference with undef',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { [ 'value1' ] } } ),
        qq{$xml\n<root><node1>value1</node1></root>},
        'code reference with array',
    ;
}

{
    is
        $data = hash2xml( { node1 => 'Тест' }, encoding => 'cp1251' ),
        qq{<?xml version="1.0" encoding="cp1251"?>\n<root><node1>\322\345\361\362</node1></root>},
        'encoding support',
    ;
}

{
    is
        $data = hash2xml( { node1 => '&<>' } ),
        qq{$xml\n<root><node1>&amp;&lt;&gt;</node1></root>},
        'escaping',
    ;
}

{
    my $fh = tempfile();
    hash2xml( { node1 => 'value1' }, output => $fh );
    seek($fh, 0, 0);
    { local $/; $data = <$fh> }
    is
        $data,
        qq{$xml\n<root><node1>value1</node1></root>},
        'filehandle output',
    ;
}

{
    my $data = '';
    tie *STDOUT, "Trapper", \$data;
    hash2xml( { node1 => 'value1' }, output => \*STDOUT );
    untie *STDOUT;
    is
        $data,
        qq{$xml\n<root><node1>value1</node1></root>},
        'tied filehandle output',
    ;
}

{
    is
        $data = hash2xml(
            {
                node1 => 'value1"',
                node2 => 'value2&',
                node3 => { node31 => 'value31' },
                node4 => [ { node41 => 'value41' }, { node42 => 'value42' } ],
                node5 => [ 51, 52, { node53 => 'value53' } ],
                node6 => {},
                node7 => [],
            },
            use_attr  => 1,
            canonical => 1,
            indent    => 2,
        ),
        <<"EOT",
$xml
<root node1="value1&quot;" node2="value2&amp;">
  <node3 node31="value31"/>
  <node4 node41="value41"/>
  <node4 node42="value42"/>
  <node5>51</node5>
  <node5>52</node5>
  <node5 node53="value53"/>
  <node6/>
</root>
EOT
        'use attributes',
    ;
}

{
    is
        $data = hash2xml(
            {
                content => 'content&1',
                node2   => [ 21, { node22 => 'value23', 'content' => 'content2' } ],
            },
            use_attr  => 1,
            canonical => 1,
            indent    => 2,
            content   => 'content',
        ),
        <<"EOT",
$xml
<root>
  content&amp;1
  <node2>21</node2>
  <node2 node22="value23">
    content2
  </node2>
</root>
EOT
        'content',
    ;
}

{
    my $o = TestObject->new();
    is
        $data = hash2xml(
            { object => $o },
        ),
        qq{$xml\n<root><object><root attr="1">value1</root></object></root>},
        'object',
    ;
}

{
    $XML::Hash::XS::indent    = 2;
    $XML::Hash::XS::use_attr  = 1;
    $XML::Hash::XS::canonical = 1;
    $XML::Hash::XS::content   = 'content';
    is
        $data = hash2xml(
            {
                content => 'content&1',
                node2   => [ 21, { node22 => 'value23', 'content' => 'content2' } ],
            },
        ),
        <<"EOT",
$xml
<root>
  content&amp;1
  <node2>21</node2>
  <node2 node22="value23">
    content2
  </node2>
</root>
EOT
        'global options',
    ;
}

package TestObject;

sub new {
    return bless [], shift;
}

sub toString {
    return '<root attr="1">value1</root>';
}

package Trapper;

sub TIEHANDLE {
    my ($class, $str) = @_;
    return bless [$str], $class;
}

sub WRITE {
    my ($self, $buf, $len, $offset) = @_;

    $len    ||= length($buf);
    $offset ||= 0;

    ${$self->[0]} .= substr($buf, $offset, $len);

    return $len;
}

sub PRINT {
    ${shift->[0]} .= join('', @_);
}
