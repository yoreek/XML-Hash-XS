package main;
use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Sortkeys = 1;

use XML::Hash::XS 'xml2hash';

our $xml_decl_utf8 = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    is
        Dumper(xml2hash(<<"XML", filter => '/root/node1', keep_root => 1)),
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
        Dumper([
    { node1  => 'value1' },
]),
        'filter1',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", filter => ['/root/node1', '/root/node2'], keep_root => 1)),
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
        Dumper([
    { node1  => 'value1' },
    { node2  => {
        attr1   => '1',
        content => 'value2',
    }},
]),
        'filter2',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", filter => qr[^/root/node\d+$], keep_root => 1)),
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
        Dumper([
    { node1  => 'value1' },
    { node2  => {
        attr1   => '1',
        content => 'value2',
    }},
    { node3  => 'value3' },
]),
        'filter3',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", filter => ['/root/node1', qr[node3$]], keep_root => 1)),
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
        Dumper([
    { node1  => 'value1' },
    { node3  => 'value3' },
]),
        'filter4',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", filter => ['/root/node5'], keep_root => 1)),
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
        Dumper([]),
        'filter5',
    ;
}

{
    my @nodes;
    xml2hash(<<"XML", filter => qr[^/root/node\d+$], keep_root => 1, cb => sub { push @nodes, $_[0] });
$xml_decl_utf8
<root>
    <node1>value1</node1>
    <node2 attr1="1">
        value2
    </node2>
    <node3>value3</node3>
</root>
XML
    is
        Dumper(\@nodes),
        Dumper([
    { node1  => 'value1' },
    { node2  => {
        attr1   => '1',
        content => 'value2',
    }},
    { node3  => 'value3' },
]),
        'filter6',
    ;
}
