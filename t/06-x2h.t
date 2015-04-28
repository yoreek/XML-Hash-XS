package main;
use strict;
use warnings;

use Test::More tests => 39;
use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Sortkeys = 1;

use XML::Hash::XS 'xml2hash';

our $xml_decl_utf8 = qq{<?xml version="1.0" encoding="utf-8"?>};

{
    is
        xml2hash("<cdata><![CDATA[\n\t  abcde!@#$%^&*<>\n\t   ]]></cdata>"),
        'abcde!@#0^&*<>',
        'cdata1',
    ;
}

{
    is
        xml2hash("<cdata><![CDATA[ [ abc ] ]> ]]]]]]></cdata>"),
        '[ abc ] ]> ]]]]',
        'cdata2',
    ;
}

{
    is
        xml2hash("<cdata><![CDATA[ ]]]></cdata>"),
        ']',
        'cdata3',
    ;
}

{
    is
        xml2hash("<cdata><![CDATA[]]></cdata>"),
        '',
        'cdata4',
    ;
}

{
    is
        Dumper(xml2hash('<root a="abc&#160;def&amp;&apos;&lt;&gt;&quot;"/>', utf8 => 0)),
        Dumper({ a => "abc\302\240def&\'<>\"" }),
        'reference in attr',
    ;
}

{
    is
        xml2hash('<root>abc&#160;def&amp;&lt;&gt;&quot;&apos;</root>', utf8 => 0),
        "abc\302\240def&<>\"'",
        'reference in text',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", keep_root => 1, content => 'text')),
<root attr1="1" attr2="2">
    <node1>value1</node1>
    <node2 attr1="1">value2</node2>
    <node3>
        content1
        <!-- comment -->
        content2
    </node3>
    <node4>
        content1
        <empty_node4/>
        content2
    </node4>
    <item>1</item>
    <item>2</item>
    <item>3</item>
    <cdata><![CDATA[
        abcde!@#$%^&*<>
    ]]></cdata>
    <cdata2><![CDATA[ abc ]]]></cdata2>
    <cdata3><![CDATA[ [ abc ] ]> ]]]]]]></cdata3>
</root>
XML
        Dumper({
root => {
    attr1  => '1',
    attr2  => '2',
    cdata  => 'abcde!@#0^&*<>',
    cdata2 => 'abc ]',
    cdata3 => '[ abc ] ]> ]]]]',
    item   => ['1', '2', '3'],
    node1  => 'value1',
    node2  => {
        attr1 => '1',
        text  => 'value2',
    },
    node3  => ['content1', 'content2'],
    node4  => {
        text        => ['content1', 'content2'],
        empty_node4 => '',
    },
}
}),
        'complex',
    ;
}

{
    is
        Dumper(xml2hash('t/test.xml', keep_root => 1)),
        Dumper({
root => {
    attr1 => '1',
    attr2 => '2',
    item  => ['1', '2', '3'],
    node1 => 'value1',
    node2 => {
        attr1   => '1',
        content => 'value2',
    }
}
}),
        'read from file',
    ;
}

SKIP: {
    use utf8;
    my $result = eval { xml2hash('t/test_cp1251.xml') };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        'Привет!',
        'test cp1251',
    ;
}

SKIP: {
    my $result = eval { xml2hash('t/test_cp1251.xml', utf8 => 0) };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        'Привет!',
        'test cp1251 utf8 off',
    ;
}

SKIP: {
    use utf8;
    my $result = eval { xml2hash('t/test_cp1251.xml', encoding => 'cp1251') };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        'Привет!',
        'test cp1251 with encoding',
    ;
}

SKIP: {
    my $result = eval { xml2hash('t/test_cp1251.xml', encoding => 'iso-8859-1', utf8 => 0) };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        'Ïðèâåò!',
        'test cp1251 without encoding',
    ;
}

SKIP: {
    my $result = eval { xml2hash('t/test_cp1251_wo_decl.xml', utf8 => 0) };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        "\317\360\350\342\345\362!",
        'test cp1251 wo decl',
    ;
}

SKIP: {
    use utf8;
    my $result = eval { xml2hash('t/test_cp1251_wo_decl.xml', encoding => 'cp1251') };
    my $err = $@;
    chomp $err;
    skip $err, 1 if $err;
    is
        $result,
        "Привет!",
        'test cp1251 wo decl with encoding',
    ;
}

{
    use utf8;
    is
        xml2hash('t/test_utf8.xml'),
        "Привет!",
        'test utf8',
    ;
}

{
    use utf8;
    is
        xml2hash('t/test_utf8.xml', encoding => 'utf-8'),
        "Привет!",
        'test utf8 with encoding',
    ;
}

{
    is
        xml2hash('t/test_utf8.xml', utf8 => 0),
        "Привет!",
        'test utf8 with utf8 off',
    ;
}

{
    is
        xml2hash('<root>Привет!</root>', utf8 => 0),
        "Привет!",
        'test utf8 string with utf8 off',
    ;
}

{
    use utf8;
    is
        xml2hash('<root>Привет!</root>'),
        "Привет!",
        'test utf8 string with utf8 on',
    ;
}

{
    use utf8;
    is
        xml2hash('<root>Привет!</root>', buf_size => 2),
        "Привет!",
        'test with buf_size=2',
    ;
}

{
    use utf8;
    is
        xml2hash('<?xml version="1.0" encoding="utf-8"?><root>Привет!</root>', buf_size => 2),
        "Привет!",
        'test with buf_size=2 and xml decl',
    ;
}

{
    use utf8;
    ## no critic (InputOutput::ProhibitBarewordFileHandles)
    open(DATA, '<:encoding(UTF-8)', 't/test_utf8.xml') or die "Can't open file 't/test_utf8.xml'";
    ## use critic
    is
        xml2hash(*DATA),
        "Привет!",
        'read from file handle',
    ;
    close DATA;
}

{
    tie *DATA, 'MyReader', '<?xml version="1.0" encoding="utf-8"?><root>Привет!</root>';
    use utf8;
    is
        xml2hash(*DATA, buf_size => 2),
        "Привет!",
        'read from tied handle',
    ;
    untie *DATA;
}

{
    use utf8;
    my $xml = <<'XML';
<?xml version="1.0" encoding="UTF-8"?>
<note>Test</note>
XML
    no warnings qw(void);
    substr $xml, 0, 0; # this will cause error in XS param type definition
    is
        xml2hash(\$xml),
        'Test',
        'check validation parameters',
    ;
}

{
    my $xml=qq[<?xml version="1.0" encoding="utf-8"?>\x0D\x0A<aaaa>\x0D\x0Aasdasdsa\x0D\x0A</aaaa>];
    is
        xml2hash(\$xml),
        'asdasdsa',
        'bug RT#103002',
    ;
}

{
    my $xml=qq[<a>\x0D\x0Aasd\x0D\x0Aasd\x0D\x0D\x0Aasd\x0D\x0A</a>];
    is
        xml2hash(\$xml),
        "asd\x0Aasd\x0A\x0Aasd",
        'normalize line feeds',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML")),
<root>
    <aaa>bbb<!-- ccc -->ddd<eee>fff</eee>ggg</aaa>
</root>
XML
        Dumper({aaa => { content => ['bbb', 'ddd', 'ggg'], eee => 'fff' }}),
        'bug with many contents in the one node',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => 0)),
<root>
    <aaa>bbb</aaa>
    <ccc><ddd>ggg</ddd>eee<!-- -->fff</ccc>
</root>
XML
        Dumper({
            aaa => 'bbb',
            ccc => {'content' => ['eee', 'fff'], 'ddd' => 'ggg'},
        }),
        'unuse force_array option',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => 1)),
<root>
    <aaa>bbb</aaa>
    <ccc><ddd>ggg</ddd>eee<!-- -->fff</ccc>
</root>
XML
        Dumper({
            aaa => ['bbb'],
            ccc => [{'content' => ['eee', 'fff'], 'ddd' => ['ggg']}],
        }),
        'use force_array option',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => qr/aaa|ddd/)),
<root>
    <aaa>bbb</aaa>
    <ccc><ddd>ggg</ddd>eee<!-- -->fff</ccc>
</root>
XML
        Dumper({
            aaa => ['bbb'],
            ccc => {'content' => ['eee', 'fff'], 'ddd' => ['ggg']},
        }),
        'use force_array option with regexp',
    ;
}

{
    my $o = XML::Hash::XS->new(force_array => ['aaa', 'ddd']);
    is
        Dumper($o->xml2hash(<<"XML")),
<root>
    <aaa>bbb</aaa>
    <ccc><ddd>ggg</ddd>eee<!-- -->fff</ccc>
</root>
XML
        Dumper({
            aaa => ['bbb'],
            ccc => {'content' => ['eee', 'fff'], 'ddd' => ['ggg']},
        }),
        'use force_array option with array',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => 1, keep_root => 1)),
<?xml version="1.0" encoding="utf-8"?>
<root>
    <node1>123</node1>
    <node3 attr1="attr1_content" subnode3="subnode30_content">
        node3_content_1
        <subnode3>
            subnode31_content
        </subnode3>
        node3_content_2
        <subnode3>
            subnode32_content
        </subnode3>
        <subnode3>
            subnode33_content
        </subnode3>
    </node3>
</root>
XML
        Dumper({
            'root' => {
                'node1' => ['123'],
                'node3' => [
                    {   'attr1'   => [ 'attr1_content' ],
                        'content' => [ 'node3_content_1', 'node3_content_2' ],
                        'subnode3' => [
                            'subnode30_content',
                            'subnode31_content',
                            'subnode32_content',
                            'subnode33_content',
                        ],
                    },
                ],
            },
        }),
        'use force_array option, issue #2',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => 1, force_content => 1, keep_root => 1)),
<?xml version="1.0" encoding="utf-8"?>
<root>
    <node1>123</node1>
    <node3 attr1="attr1_content" subnode3="subnode30_content">
        node3_content_1
        <subnode3>
            subnode31_content
        </subnode3>
        node3_content_2
        <subnode3>
            subnode32_content
        </subnode3>
        <subnode3>
            subnode33_content
        </subnode3>
    </node3>
</root>
XML
        Dumper({
            'root' => {
                'node1' => [ { content => '123' } ],
                'node3' => [
                    {   'attr1'   => [ { content => 'attr1_content' } ],
                        'content' => [ 'node3_content_1', 'node3_content_2' ],
                        'subnode3' => [
                            { content => 'subnode30_content' },
                            { content => 'subnode31_content' },
                            { content => 'subnode32_content' },
                            { content => 'subnode33_content' },
                        ],
                    },
                ],
            },
        }),
        'use force_content option',
    ;
}

{
    is
        Dumper(xml2hash(<<"XML", force_array => 1, force_content => 1, merge_text => 1, keep_root => 1)),
<?xml version="1.0" encoding="utf-8"?>
<root>
    <node1>123</node1>
    <node3 attr1="attr1_content" subnode3="subnode30_content">
        node3_content_1
        <subnode3>
            subnode31_content
        </subnode3>
        node3_content_2
        <subnode3>
            subnode32_content
            <!-- comment  -->
            subnode32_content2
        </subnode3>
        <subnode3>
            subnode33_content
        </subnode3>
    </node3>
</root>
XML
        Dumper({
            'root' => {
                'node1' => [ { content => '123' } ],
                'node3' => [
                    {   'attr1'   => [ { content => 'attr1_content' } ],
                        'content' => 'node3_content_1node3_content_2',
                        'subnode3' => [
                            { content => 'subnode30_content' },
                            { content => 'subnode31_content' },
                            { content => 'subnode32_contentsubnode32_content2' },
                            { content => 'subnode33_content' },
                        ],
                    },
                ],
            },
        }),
        'use merge_text option',
    ;
}

{
    eval { xml2hash("<root></root><root2></root2>") };
    ok($@, 'invalid xml');
}

{
    eval { xml2hash("<root></root><root2>") };
    ok($@, 'invalid xml2');
}

{
    eval { xml2hash("</root>") };
    ok($@, 'invalid xml3');
}

{
    eval { xml2hash("<root></root>text") };
    ok($@, 'invalid xml4');
}

{
    is
        xml2hash(" \r\n\t<root>boom</root>"),
        'boom',
        'ignore leading white spaces',
    ;
}


package MyReader;
use base 'Tie::Handle';

sub TIEHANDLE {
    my ($class, $str) = @_;
    bless {str => $str, pos => 0, len => length($str)}, $class;
}

sub READ {
    my $bufref = \$_[1];
    my ($self, undef, $len, $offset) = @_;

    $offset ||= 0;

    if (($self->{pos} + $len) > $self->{len}) {
        $len = $self->{len} - $self->{pos};
    }
    if ($len > 0) {
        $$bufref = substr($$bufref, 0, $offset) . substr($self->{str}, $self->{pos}, $len);
        $self->{pos} += $len;
    }
    return $len;
}

sub WRITE {}
sub PRINT {}
