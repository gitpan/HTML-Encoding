#!/usr/local/bin/perl -w

use strict;
use Test;
no warnings;

BEGIN { plan tests => 10 }

use HTML::Encoding 'get_encoding';

ok(1);

my $sample = do { local $/; <DATA> };
my $xmldecl = q(<?xml version='1.0' encoding='windows-1252'?>);
my $ebcdic = join "", map { chr hex } qw/
  4C 6F A7 94 93 40 A5 85 99 A2 89 96 95 40 7E 40
  7D F1 4B F0 7D 40 85 95 83 96 84 89 95 87 40 7E
  40 7F C5 C2 C3 C4 C9 C3 60 C1 E3 60 C4 C5 60 C1
  7F 40 6F 6E
/;

my $http = eval { require HTTP::Headers; };
my $mime = eval { require Mail::Header; };
my $meta = eval { require HTML::HeadParser; };

# utf-16be BOM
ok(get_encoding(string => "\xfe\xff\x46\x47", check_meta => 0), 'utf-16be');

# utf-8 bom
ok(get_encoding(string => "\xef\xbb\xbf<?xml...", check_meta => 0), 'utf-8');

# no bom
ok(not defined get_encoding( string => "", check_meta => 0));

# meta
skip(!$meta, sub { get_encoding(string => $sample) }, 'iso-8859-2');

# xmldecl
ok(get_encoding( string => $xmldecl.$sample, check_xmldecl => 1), 'windows-1252');

# http-headers
skip(!$http, sub {return get_encoding( headers => HTTP::Headers->new(content_type=>"text/html;charset='koir-8'"))}, 'koir-8');
skip((!$http or !$meta), sub {return get_encoding( headers => HTTP::Headers->new(content_type=>"text/html"),string=>$sample)}, 'iso-8859-2');

# mime headers
skip(!$mime, sub { return get_encoding( headers => Mail::Header->new(["content-type: charset=windows-1251\n\n"]))}, 'windows-1251');

# ebcdic xml declaration
ok(get_encoding( string => $ebcdic, check_xmldecl => 1, check_meta => 0), 'ebcdic-at-de-a');

__DATA__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="content-type" content='text/html;charset="iso-8859-2"' />
    <title></title>
  </head>
  <body>
  </body>
</html>