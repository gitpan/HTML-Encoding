#!/usr/local/bin/perl -w

# this should be dramatically improved

use strict;
use Test;
no warnings;

BEGIN { plan tests => 4 }

use HTML::Encoding 'get_encoding';

ok(1);

# utf-16be BOM
ok(get_encoding(string => "\xfe\xff\x46\x47", check_meta => 0) eq 'utf-16be');

# utf-8 bom
ok(get_encoding(string => "\xef\xbb\xbf<?xml...", check_meta => 0) eq 'utf-8');

# no bom
ok(not defined get_encoding( string => "", check_meta => 0));
