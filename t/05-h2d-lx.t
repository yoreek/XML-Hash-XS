
use strict;
use warnings;

use Test::More;

use XML::Hash::XS;

our $c;
eval { $c = XML::Hash::XS->new(doc => 1, method => 'LX', trim => 1) };
if ($@) {
    plan skip_all => "Option 'doc' is not supported";
}
else {
    plan tests => 11;
    require XML::LibXML;
}

our $xml_decl = qq{<?xml version="1.0" encoding="utf-8"?>\n};

sub fix_xml($) { my $xml = shift; chomp $xml; $xml =~ s|(<\w[^</>]*[^/])></\w+>|$1/>|g; $xml }

{
    is
        fix_xml $c->hash2xml( { node => [ { -attr => "test < > & \" \t \n \r end" }, { sub => 'test' }, { tx => { '#text' => ' zzzz ' } } ] } )->toString(),
        qq{$xml_decl<node attr="test &lt; &gt; &amp; &quot; &#9; &#10; &#13; end"><sub>test</sub><tx>zzzz</tx></node>},
        'default 1',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => [ { _attr => "test" }, { sub => 'test' }, { tx => { '#text' => 'zzzz' } } ] }, attr => '_' )->toString(),
        qq{$xml_decl<node attr="test"><sub>test</sub><tx>zzzz</tx></node>},
        'attr _',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => [ { -attr => "test" }, { sub => 'test' }, { tx => { '~' => "zzzz < > & \r end" } } ] }, text => '~' )->toString(),
        qq{$xml_decl<node attr="test"><sub>test</sub><tx>zzzz &lt; &gt; &amp; &#13; end</tx></node>},
        'text ~',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 1 )->toString(),
        qq{$xml_decl<node><sub>test</sub></node>},
        'trim 1',
    ;
    is
        fix_xml $c->hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 0 )->toString(),
        qq{$xml_decl<node><sub> \t\ntest</sub></node>},
        'trim 0',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { sub => { '@' => "cdata < > & \" \t \n \r end" } } }, cdata => '@' )->toString(),
        qq{$xml_decl<node><sub><![CDATA[cdata < > & \" \t \n \r end]]></sub></node>},
        'cdata @',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { sub => { '/' => "comment < > & \" \t \n \r end" } } },comm => '/' )->toString(),
        qq{$xml_decl<node><sub><!--comment < > & \" \t \n \r end--></sub></node>},
        'comm /',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { -attr => undef, '#text' => 'text' } } )->toString(),
        qq{$xml_decl<node attr="">text</node>},
        'empty attr',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { '#cdata' => undef, '#text' => 'text' } }, cdata => '#cdata' )->toString(),
        qq{$xml_decl<node>text</node>},
        'empty cdata',
    ;
}
{
    is
        fix_xml $c->hash2xml( { node => { '/' => undef } }, comm => '/' )->toString(),
        qq{$xml_decl<node><!----></node>},
        'empty comment',
    ;
}
SKIP: {
    my $data;
    eval { $data = fix_xml $c->hash2xml( { node => {  test => "Тест" } }, encoding => 'cp1251' )->toString() };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    chomp $data;
    is
        $data,
        qq{<?xml version="1.0" encoding="cp1251"?>\n<node><test>\322\345\361\362</test></node>},
        'encoding support',
    ;
}
