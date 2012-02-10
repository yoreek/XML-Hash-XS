#!/use/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use File::Temp qw(tempfile);

use XML::Hash::XS 'hash2xml';

our $data;
our $xml = qq{<?xml version="1.0" encoding="utf-8"?>\n};

{
    is
        $data = hash2xml( { node1 => [ 'value1', { node2 => 'value2' } ] } ),
        qq{$xml<root><node1><item>value1</item><item><node2>value2</node2></item></node1></root>\n},
        'default 1',
    ;
}

{
    is
        $data = hash2xml( { node1 => \'value1' } ),
        qq{$xml<root><node1>value1</node1></root>\n},
        'scalar reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { 'value1' } } ),
        qq{$xml<root><node1>value1</node1></root>\n},
        'code reference',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { undef } } ),
        qq{$xml<root><node1/></root>\n},
        'code reference with undef',
    ;
}

{
    is
        $data = hash2xml( { node1 => sub { [ 'value1' ] } } ),
        qq{$xml<root><node1><item>value1</item></node1></root>\n},
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
        qq{$xml<root><node1>value1</node1></root>\n},
        'filehandle output',
    ;
}
