#!/use/bin/perl

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);

use XML::Hash::XS;

our $c;
eval { $c = XML::Hash::XS->new(doc => 1) };
if ($@) {
    plan skip_all => "Option 'doc' is not supported";
}
else {
    plan tests => 11;
    require XML::LibXML;
}

our $data;
our $xml = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    $data = $c->hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>value1</node1><node1><node2>value2</node2></node1></root>},
        'default',
    ;
}

{
    $data = $c->hash2xml( { node3 => 'value3', node1 => 'value1', node2 => 'value2' }, canonical => 1 )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>value1</node1><node2>value2</node2><node3>value3</node3></root>},
        'canonical',
    ;
}

{
    $data = $c->hash2xml( { node1 => [ 1, '2', '2' + 1 ] } )->toString();
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
    $data = $c->hash2xml( { node1 => [ $x, $y, $y + $x ] } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>1.1</node1><node1>2.2</node1><node1>3.3</node1></root>},
        'double, string, double + string',
    ;
}

{
    $data = $c->hash2xml( { 1 => 'value1' } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><_1>value1</_1></root>},
        'quote tag name',
    ;
}

SKIP: {
    eval { $data = $c->hash2xml( { node1 => 'Тест' }, encoding => 'cp1251' )->toString(); chomp $data; };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $data,
        qq{<?xml version="1.0" encoding="cp1251"?>\n<root><node1>\322\345\361\362</node1></root>},
        'encoding support',
    ;
}

{
    $data = $c->hash2xml( { node1 => "< > & \r" } )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node1>&lt; &gt; &amp; &#13;</node1></root>},
        'escaping',
    ;
}

{
    $data = $c->hash2xml( { node => " \t\ntest "  }, trim => 0 )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node> \t\ntest </node></root>},
        'trim 0',
    ;
    $data = $c->hash2xml( { node => " \t\ntest "  }, trim => 1 )->toString();
    chomp $data;
    is
        $data,
        qq{$xml\n<root><node>test</node></root>},
        'trim 1',
    ;
}

{
    $data = $c->hash2xml(
        {
            node1 => 'value1"',
            node2 => 'value2&',
            node3 => { node31 => 'value31', t => [ 'text' ] },
            node4 => [ { node41 => 'value41', t => [ 'text' ] }, { node42 => 'value42', t => [ 'text' ] } ],
            node5 => [ 51, 52, { node53 => 'value53', t => [ 'text' ] } ],
            node6 => [],
        },
        use_attr  => 1,
        canonical => 1,
        indent    => 2,
    )->toString();
    is
        $data,
        <<"EOT",
$xml
<root node1="value1&quot;" node2="value2&amp;"><node3 node31="value31"><t>text</t></node3><node4 node41="value41"><t>text</t></node4><node4 node42="value42"><t>text</t></node4><node5>51</node5><node5>52</node5><node5 node53="value53"><t>text</t></node5></root>
EOT
        'use attributes',
    ;
}

{
    $data = $c->hash2xml(
        {
            content => 'content&1',
            node2   => [ 21, {
                node22  => "value22 < > & \" \t \n \r",
                content => "content < > & \r",
            } ],
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
<root>content&amp;1<node2>21</node2><node2 node22="value22 &lt; &gt; &amp; &quot; &#9; &#10; &#13;">content &lt; &gt; &amp; &#13;</node2></root>
EOT
        'content',
    ;
}
