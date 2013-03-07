#!/usr/bin/env perl

use FindBin;
use LWP::Simple 'get';
use XML::Hash::LX;
use XML::Hash;
use XML::Simple;
use XML::Hash::XS qw();
use Benchmark qw(:all);

my $xml_converter = XML::Hash->new();
my $xml = getXml();
my $xh_hash = $xml_converter->fromXMLStringtoHash($xml);
my $lx_hash = xml2hash($xml);
my $xs_hash = XMLin($xml);

cmpthese timethese 1000, {
	'Hash' => sub {
		my $oxml = $xml_converter->fromHashtoXMLString($xh_hash);
	},
	'Simple' => sub {
		my $oxml = XMLout($xs_hash);
	},
	'Hash::LX' => sub {
		my $oxml = hash2xml($lx_hash);
	},
	'Hash::XS' => sub {
		my $oxml = XML::Hash::XS::hash2xml($xs_hash);
	},
	'Hash::XS(LX)' => sub {
		my $oxml = XML::Hash::XS::hash2xml($lx_hash, mode => 'LX');
	},
};

sub getXml {
	my $fn = "$FindBin::Bin/uploads.rdf";
	open my $f, '<',$fn  or return do {
		warn "Fetching file\n";
		my $data = get 'http://search.cpan.org/uploads.rdf';
		open my $fo, '>', $fn;
		print $fo $data;
		close $fo;
		$data;
	};
	warn "Have preloaded file\n";
	local $/;
	<$f>
}
