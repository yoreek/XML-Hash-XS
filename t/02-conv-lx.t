#!/use/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use XML::Hash::XS 'hash2xml';

$XML::Hash::XS::method = 'LX';

our $xml = qq{<?xml version="1.0" encoding="utf-8"?>\n};
our $data;

{
	is
		$data = hash2xml( { node => [ { -attr => "test" }, { sub => 'test' }, { tx => { '#text' => ' zzzz ' } } ] } ),
		qq{$xml<node attr="test"><sub>test</sub><tx>zzzz</tx></node>},
		'default 1',
	;
}
{
	is
		$data = hash2xml( { node => [ { _attr => "test" }, { sub => 'test' }, { tx => { '#text' => 'zzzz' } } ] }, attr => '_' ),
		qq{$xml<node attr="test"><sub>test</sub><tx>zzzz</tx></node>},
		'attr _',
	;
}
{
	is
		$data = hash2xml( { node => [ { -attr => "test" }, { sub => 'test' }, { tx => { '~' => 'zzzz' } } ] }, text => '~' ),
		qq{$xml<node attr="test"><sub>test</sub><tx>zzzz</tx></node>},
		'text ~',
	;
}
{
	is
		$data = hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 1 ),
		qq{$xml<node><sub>test</sub></node>},
		'trim 0',
	;
	is
		$data = hash2xml( { node => { sub => [ " \t\n", 'test' ] } }, trim => 0 ),
		qq{$xml<node><sub> \t\ntest</sub></node>},
		'trim 1',
	;
}
{
	is
		$data = hash2xml( { node => { sub => { '@' => 'test' } } }, cdata => '@' ),
		qq{$xml<node><sub><![CDATA[test]]></sub></node>},
		'cdata @',
	;
}
{
	is
		$data = hash2xml( { node => { sub => { '/' => 'test' } } },comm => '/' ),
		qq{$xml<node><sub><!--test--></sub></node>},
		'comm /',
	;
}
{
	is
		$data = hash2xml( { node => { -attr => undef, '#cdata' => undef, '/' => undef, x=>undef } }, cdata => '#cdata', comm => '/' ),
		qq{$xml<node attr=""><!----><x/></node>},
		'empty attr',
	;
}
{
	is
		$data = hash2xml( { node => {  test => "Тест" } }, encoding => 'cp1251' ),
		qq{<?xml version="1.0" encoding="cp1251"?>\n<node><test>\322\345\361\362</test></node>},
		'encoding support',
	;
}
