#
# $Id: Encoding.pm,v 0.03 2001/08/02 06:30:16 bjoern Exp $
#

package HTML::Encoding;

# note: should this module be compatible with Perl 5.005 or below?
# currently we aren't...

require 5.006;
use strict;
use warnings;
use UNIVERSAL;
use Exporter;
use base qw/Exporter/;
no utf8;

# exportable constants

use constant FROM_META        => 1;
use constant FROM_BOM         => 2;
use constant FROM_XMLDECL     => 3;
use constant FROM_HEADER      => 4;

# BOM bytes to encoding name map

use constant BOM_MAP => {
  qr/^(\x00\x00\xfe\xff)/, 'ISO-10646-UCS-4', # big endian
  qr/^(\xff\xfe\x00\x00)/, 'ISO-10646-UCS-4', # little endian
  qr/^(\x00\x00\xff\xfe)/, 'ISO-10646-UCS-4', # unusal
  qr/^(\xfe\xff\x00\x00)/, 'ISO-10646-UCS-4', # unusal 
  qr/^(\xfe\xff)((?:[^\x00][\x00-\xff])|(?:[\x00-\xff][^\x00]))/, 'UTF-16BE',
  qr/^(\xff\xfe)((?:[^\x00][\x00-\xff])|(?:[\x00-\xff][^\x00]))/, 'UTF-16LE',
  qr/^(\xef\xbb\xbf)/, 'UTF-8'
};

# export declarations

our @EXPORT = qw/get_encoding/;
our @EXPORT_OK = qw/FROM_HEADER FROM_BOM FROM_XMLDECL FROM_META/;
our %EXPORT_TAGS = (constants => [ @EXPORT_OK ]);

# our version :-)

our $VERSION = 0.03;

# EBCDIC to US-ASCII table for characters in the XML declaration

my %ebcdic2asciimap;
@ebcdic2asciimap{
  map { chr hex }
  qw/
    05 25 0D 40 7F 7D 60 4B F0 F1 F2 F3 F4 F5 F6 F7
    F8 F9 7A 4C 7E 6E 6F C1 C2 C3 C4 C5 C6 C7 C8 C9
    D1 D2 D3 D4 D5 D6 D7 D8 D9 E2 E3 E4 E5 E6 E7 E8
    E9 6D 81 82 83 84 85 86 87 88 89 91 92 93 94 95
    96 97 98 99 A2 A3 A4 A5 A6 A7 A8 A9/} =
  map { chr hex }
  qw/
    09 0A 0D 20 22 27 2D 2E 30 31 32 33 34 35 36 37
    38 39 3A 3C 3D 3E 3F 41 42 43 44 45 46 47 48 49
    4A 4B 4C 4D 4E 4F 50 51 52 53 54 55 56 57 58 59
    5A 5F 61 62 63 64 65 66 67 68 69 6A 6B 6C 6D 6E
    6F 70 71 72 73 74 75 76 77 78 79 7A
/;

# private function to extract the charset parameter

sub _extract_charset
{
  local $_ = shift;
  return undef unless s/^.*?charset=(['"]?)//i;
  if (length $1) { return lc $1 if m(^(.+?)\s*$1.*$)}
  else           { return lc $1 if m(^([^\s;]+))   }
  return undef;
}

sub get_encoding
{
  my %vars = @_;

  # initialize defaults

  $vars{check_bom}     = 1 unless defined $vars{check_bom};

  # check for BOM is default for XHTML documents
  $vars{check_bom}     = 1 if $vars{check_xmldecl};
  $vars{check_xmldecl} = 0 unless defined $vars{check_xmldecl};
  $vars{check_meta}    = 1 unless defined $vars{check_meta};

  my $bom_length = 0;
  my @encodings;

  # check in this order
  # check HTTP/MIME headers
  # check the byte order mark
  # check XML declaration
  # check meta element

  if (defined $vars{headers} and
      UNIVERSAL::isa($vars{headers}, "HTTP::Headers"))
  {
      # note: the content-type header may originate
      # from the meta element if the document was
      # retrieved with $ua->parse_head set; asked Gisle
      # to indicate if this is true in HTTP::Headers

      my $charset = (grep { /^charset=/i } $vars{headers}->content_type)[0];
      if (defined $charset) {
          my $e = _extract_charset($charset);
          push @encodings, { source => FROM_HEADER, encoding => $e } if defined $e;
      }
  } elsif (defined $vars{headers} and
           UNIVERSAL::isa($vars{headers}, "Mail::Header"))
  {
      my $charset = $vars{headers}->get('content-type');
      if (defined $charset) {
          my $e = _extract_charset($charset);
          push @encodings, { source => FROM_HEADER, encoding => lc $e } if defined $e;
      }
  }

  if (defined $vars{string})
  {

      if ($vars{check_bom})
      {
          foreach (keys %{&BOM_MAP})
          {
              if ($vars{string} =~ m($_)) {
                  $bom_length = length $1;
                  push @encodings, { source => FROM_BOM, encoding => lc BOM_MAP->{$_} };
              }
          }
      }

      if ($vars{check_xmldecl})
      {
          local $_ = substr $vars{string}, $bom_length, 4;

          my $concatenate = 0;
          my $ebcdic = 0;
          my $has_decl = 1;
  
          if (/^\x3c[\x00]{3}/     or
              /^\x00\x3c\x00{2}/   or
              /^[\x00]{2}\x3c\x00/ or 
              /^[\x00]{3}\x3c/)          {
  
              # UCS-4 or other encoding with a 32-bit code unit and ASCII
              # characters encoded as ASCII values, in respectively little-
              # endian (4321), two unusual byte orders (3412 and 2143) and
              # big-endian (1234)
  
              $concatenate = 1;
  
          } elsif (/^\x00\x3c\x00\x3f/)  {
  
              # UTF-16BE or big-endian ISO-10646-UCS-2 or other encoding
              # with a 16-bit code unit in big-endian order and ASCII
              # characters encoded as ASCII values
  
              $concatenate = 1;
  
          } elsif (/^\x3c\x00\x3f\x00/) {
  
              # UTF-16LE or little-endian ISO-10646-UCS-2 or other encoding
              # with a 16-bit code unit in little-endian order and ASCII
              # characters encoded as ASCII values
  
              $concatenate = 1;
  
          } elsif (/^\x3c\x3f\x78\x6d/) {
  
              # UTF-8, ISO 646, ASCII, some part of ISO 8859, Shift-JIS,
              # EUC, or any other 7-bit, 8-bit, or mixed-width encoding
              # which ensures that the characters of ASCII have their normal
              # positions, width, and values

              # do nothing
  
          } elsif (/^\x4c\x6f\xa7\x94/) {
  
              # EBCDIC in some flavour
  
              $ebcdic = 1;
  
          } else {
              # no xml declaration
  
              $has_decl = 0;
          }
  
          if ($has_decl) {

              # find the XML declaration and "recode" it to US-ASCII
              my $xmldecl;

              if ($ebcdic) {

                $xmldecl = substr $vars{string}, 0, index($vars{string}, "\x6e");
                $xmldecl =~ s/(.)/$ebcdic2asciimap{$1}/g;

              } else {

                $xmldecl = substr $vars{string}, 0, index($vars{string}, '>');
                $xmldecl =~ s/\x00+//g if $concatenate;
              }

              if ($xmldecl =~ m/encoding\s*=\s*['"](.*?)['"]/) {
                  push @encodings, { source => FROM_XMLDECL, encoding => lc $1 };
              }
          }
      }
  
      if ($vars{check_meta})
      {
          # note: check if HTML::HeadParser is alread loaded
  
          eval { require HTML::HeadParser; };
          unless ($@) {
  
              # TODO: insure that we pass only ascii compatible
              # characters to HTML::HeadParser; it cannot handle
              # others; maybe HTML::HeadParser should do this and
              # accept an encoding parameter; if we don't have
              # any encoding information we are lost anyway; maybe
              # this needs some customizable default we could
              # recode from...

              my $p = HTML::HeadParser->new;
              $p->parse($vars{string});
              my $charset = $p->header('Content-Type');
              if (defined $charset) {
                  my $e = _extract_charset($charset);
                  push @encodings, { source => FROM_META, encoding => $e } if defined $e;
              }
          }
      }
  }

  @encodings = sort { $b->{source} <=> $a->{source} } @encodings;

  return undef unless defined $encodings[0];
  return wantarray ? @encodings : $encodings[0]->{encoding};
}

1;
__END__
=head1 NAME

HTML::Encoding - Determine the encoding of (X)HTML documents

=head1 SYNOPSIS

  use HTML::Encoding;
  # ...
  my $encoding = get_encoding

    headers       => $r->headers,
    string        => $r->content,
    check_bom     => 1,
    check_xmldecl => 0,
    check_meta    => 1

=head1 DESCRIPTION

This module can be used to determine the encoding of HTML and XHTML files. It
reports I<explicitly> given encoding informations, i.e.

=over 2

=item *

the HTTP Content-Type headers charset parameter

=item *

the XML declaration

=item *

the byte order mark (BOM)

=item *

the meta element with http-equiv set to Content-Type

=back

=over 4

=item get_encoding( %options )

This function takes a hash as argument that stores all configuration
options. The following are available:

=over 4

=item string

A string containing the (X)HTML document. The function assumes that all
possibly applied Content-(Transfer-)Encodings are removed.

=item headers

An HTTP::Headers or Mail::Header object to extract the Content-Type
header. Please note that LWP::UserAgent stores header values from
meta elements by default in the response header. To turn this of
call the $ua->parse_head() method with a false value. get_encoding()
always uses only the first given Content-Type: header; this should
be the one given in the original HTTP header in most cases.

=item check_xmldecl

Checks the document for an XML declaration. If one is found, it tries to
extract the value of the C<encoding> pseudo-attribute. Please note that
the XML declaration must not be preceded by any character. The default is
no.

=item check_bom

Checks the document for a byte order mark (BOM). The default is yes; it's
always yes if check_xmldecl is set to a true value.

=item check_meta

Checks the document for a meta element like

  <meta http-equiv='Content-Type'
        content='text/html;charset=iso-8859-1'>

using HTML::HeadParser (or does nothing if it fails to load
that module). The default is yes.

=back

In list context it returns a list of hash refernces. Each hash references
consists of two key/value pairs, e.g.

  [
    { source => 4, encoding => 'utf-8' },
    { source => 1, encoding => 'utf-8' }
  ]

The source value is mapped to one of the constants FROM_META, FROM_BOM,
FROM_XMLDECL and FROM_HEADER. You can import these constants solely
into your namespace or using the C<:constants> symbol, e.g.

  use HTML::Encoding ':constants';

In scalar context it returns the value of the encoding key from the first
entry in the list. The list is sorted according to the origin of the encoding
information, see the list at the beginning of this document.

If no I<explicit> encoding information is found, it returns undef. It's up to
you to implement defaulting behaivour if this is applicable.

=back

=head1 BUGS

=over 2

=item *

The module does not recode the content before passing
it to C<HTML::HeadParser> (that only supports US-ASCII compatible
encodings).

=back

=head1 WARNING

This module is currently at alpha stage, please note that the interface
may change in subsequent versions.

=head1 SEE ALSO

=over 2

=item *

http://www.w3.org/TR/REC-xml-20001006.htm#sec-guessing

=item *

http://www.w3.org/TR/1999/REC-html401-19991224/charset.html#h-5.2

=item *

http://www.ietf.org/rfc/rfc2854.txt

=item *

http://www.ietf.org/rfc/rfc2616.txt

=item *

RFC 2045 - RFC 2049

=back

=head1 COPYRIGHT

Copyright (c) 2001 BjE<ouml>rn HE<ouml>hrmann

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

BjE<ouml>rn HE<ouml>hrmann E<lt>bjoern@hoehrmann.deE<gt>

=cut
