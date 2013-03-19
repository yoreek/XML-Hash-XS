#!/use/bin/perl

use FindBin;
use lib ("$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch");
use strict;
use warnings;

use Test::More tests => 9;
use File::Temp qw(tempfile);

use XML::Hash::XS 'hash2xml';
use XML::LibXML;

$XML::Hash::XS::doc = 1;
our $data;
our $xml = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>value1</node1><node1><node2>value2</node2></node1></root>},
        'default',
    ;
}

{
    $data = hash2xml( { node3 => 'value3', node1 => 'value1', node2 => 'value2' }, canonical => 1 )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>value1</node1><node2>value2</node2><node3>value3</node3></root>},
        'canonical',
    ;
}

{
    $data = hash2xml( { node1 => [ 1, '2', '2' + 1 ] } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>1</node1><node1>2</node1><node1>3</node1></root>},
        'integer, string, integer + string',
    ;
}

{
    my $x = 1.1;
    my $y = '2.2';
    $data = hash2xml( { node1 => [ $x, $y, $y + $x ] } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>1.1</node1><node1>2.2</node1><node1>3.3</node1></root>},
        'double, string, double + string',
    ;
}

{
    $data = hash2xml( { 1 => 'value1' } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><_1>value1</_1></root>},
        'quote tag name',
    ;
}

{
    $data = hash2xml( { node1 => 'Тест' }, encoding => 'cp1251' )->toString();
    chomp $data;
    is
        $data,
        qq{<?xml version="1.0" encoding="cp1251"?>\n<root><node1>\322\345\361\362</node1></root>},
        'encoding support',
    ;
}

{
    $data = hash2xml( { node1 => '&<>' } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>&amp;&lt;&gt;</node1></root>},
        'escaping',
    ;
}

{
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
    )->toString();
    is
        $data,
        <<"EOT",
$xml
<root node1="value1&quot;" node2="value2&amp;"><node3 node31="value31"/><node4 node41="value41"/><node4 node42="value42"/><node5>51</node5><node5>52</node5><node5 node53="value53"/><node6/></root>
EOT
        'use attributes',
    ;
}

{
    $data = hash2xml(
        {
            content => 'content&1',
            node2   => [ 21, { node22 => 'value23', 'content' => 'content2' } ],
        },
        use_attr  => 1,
        canonical => 1,
        indent    => 2,
        content   => 'content',
    )->toString();
    is
        $data,
        <<"EOT",
$xml
<root>content&amp;1<node2>21</node2><node2 node22="value23">content2</node2></root>
EOT
        'content',
    ;
}
