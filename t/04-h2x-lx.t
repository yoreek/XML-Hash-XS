
use strict;
use warnings;

use Test::More tests => 12;

use XML::Hash::XS 'hash2xml';

$XML::Hash::XS::method = 'LX';
$XML::Hash::XS::trim   = 1;

our $xml_decl = qq{<?xml version="1.0" encoding="utf-8"?>\n};

{
    is
        hash2xml( { node => [ { -attr => "test < > & \" \t \n \r end" }, { sub => 'test' }, { tx => { '#text' => ' zzzz ' } } ] } ),
        qq{$xml_decl<node attr="test &lt; &gt; &amp; &quot; &#9; &#10; &#13; end"><sub>test</sub><tx>zzzz</tx></node>},
        'default 1',
    ;
}
{
    is
        hash2xml( { node => [ { _attr => "test" }, { sub => 'test' }, { tx => { '#text' => 'zzzz' } } ] }, attr => '_' ),
        qq{$xml_decl<node attr="test"><sub>test</sub><tx>zzzz</tx></node>},
        'attr _',
    ;
}
{
    is
        hash2xml( { node => [ { -attr => "test" }, { sub => 'test' }, { tx => { '~' => "zzzz < > & \r end" } } ] }, text => '~' ),
        qq{$xml_decl<node attr="test"><sub>test</sub><tx>zzzz &lt; &gt; &amp; &#13; end</tx></node>},
        'text ~',
    ;
}
{
    is
        hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 1 ),
        qq{$xml_decl<node><sub>test</sub></node>},
        'trim 1',
    ;
    is
        hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 0 ),
        qq{$xml_decl<node><sub> \t\ntest</sub></node>},
        'trim 0',
    ;
}
{
    is
        hash2xml( { node => { sub => { '@' => "cdata < > & \" \t \n \r end" } } }, cdata => '@' ),
        qq{$xml_decl<node><sub><![CDATA[cdata < > & \" \t \n \r end]]></sub></node>},
        'cdata @',
    ;
}
{
    is
        hash2xml( { node => { sub => { '/' => "comment < > & \" \t \n \r end" } } },comm => '/' ),
        qq{$xml_decl<node><sub><!--comment < > & \" \t \n \r end--></sub></node>},
        'comm /',
    ;
}
{
    is
        hash2xml( { node => { -attr => undef } } ),
        qq{$xml_decl<node attr=""></node>},
        'empty attr',
    ;
}
{
    is
        hash2xml( { node => { '#cdata' => undef } }, cdata => '#cdata' ),
        qq{$xml_decl<node></node>},
        'empty cdata',
    ;
}
{
    is
        hash2xml( { node => { '/' => undef } }, comm => '/' ),
        qq{$xml_decl<node><!----></node>},
        'empty comment',
    ;
}
{
    is
        hash2xml( { node => { x=>undef } } ),
        qq{$xml_decl<node><x/></node>},
        'empty tag',
    ;
}
SKIP: {
    my $data;
    eval { $data = hash2xml( { node => {  test => "Тест" } }, encoding => 'cp1251' ) };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $data,
        qq{<?xml version="1.0" encoding="cp1251"?>\n<node><test>\322\345\361\362</test></node>},
        'encoding support',
    ;
}
