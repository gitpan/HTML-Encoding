#!/usr/local/bin/perl -w

use strict;
use Test;
no warnings;

BEGIN { plan tests => 9 }

use HTML::Encoding 'get_encoding';

ok(1);

my $sample = do { local $/; <DATA> };
my $xmldecl = q(<?xml version='1.0' encoding='windows-1252'?>);
my $http = eval { require HTTP::Headers; };
my $mime = eval { require Mail::Header; };

# utf-16be BOM
ok(get_encoding(string => "\xfe\xff\x46\x47", check_meta => 0), 'utf-16be');

# utf-8 bom
ok(get_encoding(string => "\xef\xbb\xbf<?xml...", check_meta => 0), 'utf-8');

# no bom
ok(not defined get_encoding( string => "", check_meta => 0));

# meta
ok(get_encoding(string => $sample), 'iso-8859-2');

# xmldecl
ok(get_encoding( string => $xmldecl.$sample, check_xmldecl => 1), 'windows-1252');

# http-headers
skip(!$http, sub {return get_encoding( headers => HTTP::Headers->new(content_type=>"text/html;charset='koir-8'"))}, 'koir-8');
skip(!$http, sub {return get_encoding( headers => HTTP::Headers->new(content_type=>"text/html"),string=>$sample)}, 'iso-8859-2');

# mime headers
skip(!$mime, sub { return get_encoding( headers => Mail::Header->new(["content-type: charset=windows-1251\n\n"]))}, 'windows-1251')

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