#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use Unicode::Stringprep;
use Unicode::Normalize;
use URI::Escape;

my $data_d = file (__FILE__)->dir->parent;
my $generated_d = $data_d->subdir ('generated');

use Char::Prop::Unicode::5_1_0::BidiClass;
use Char::Prop::Unicode::BidiClass;
use Char::Prop::Unicode::Age;

sub string_unicode_version ($) {
  my $s = shift;
  my $version = '1.1';
  for (split //, $s) {
    my $ver = unicode_age_c $_;
    undef $ver if $ver eq 'unassigned';
    if (defined $ver) {
      if (defined $version and $version < $ver) {
        $version = $ver;
      }
    } else {
      $version = undef;
    }
  }
  return $version;
} # string_unicode_version

sub is_rtl ($) {
  my $bidi = unicode_bidi_class_c $_[0];
  return {
    AL => 1,
    R => 1,
    AN => 1,
  }->{$bidi};
} # is_rtl

sub pe ($) {
  return URI::Escape::uri_escape_utf8 shift;
} # pe

sub uescape ($) {
  my $s = shift;
  return join '', map {
    my $c = ord $_;
    if ((0x41 <= $c and $c <= 0x5A) or
        (0x61 <= $c and $c <= 0x7A) or
        (0x30 <= $c and $c <= 0x39) or
        $c == 0x2D or
        $c == 0x2E or
        $c == 0x25 or
        $c == 0x5F) {
      $_;
    } else {
      if ($c > 0xFFFF) {
        sprintf '\U%08X', $c;
      } else {
        sprintf '\u%04X', $c;
      }
    }
  } split //, $s;
  return $s;
} # uescape

use Net::LibIDN;
sub to_punycode_with_prefix ($) {
  my $s = shift;
  return 'xn--' . Net::LibIDN::idn_punycode_encode $s, 'utf-8';
} # to_punycode_with_prefix

sub generate_from_map ($$;%) {
  my $map = shift;
  my $file_name = shift;
  my %args = @_;

  my $f = $generated_d->file ($file_name . '.dat');
  print $f->relative, "...\n";
  my $file = $f->openw;
  my @map = @$map;
  while (@map) {
    my $orig = chr shift @map;
    shift @map;
    my $new = $args{remove} ? '' : NFC lc uc NFKD $orig;
    
    my $punycoded = to_punycode_with_prefix 'a' . $new . 'b';
    $punycoded = 'a' . $new . 'b' if $punycoded =~ /-$/;
    my $gecko_host = $punycoded;
    $punycoded =~ s/ /%20/g;
    $gecko_host = 'a' . (pe $orig) . 'b' if $args{pe_input};
    $gecko_host =~ tr/A-Z/a-z/;
    my $ie_host = 'a' . $new . 'b';
    $ie_host = 'a' . (pe $orig) . 'b' if $args{pe_input};
    $ie_host =~ tr/A-Z/a-z/;
    my $ie_invalid = $ie_host =~ /\x20/;
    printf $file q{#data escaped
http://a%sb/
#canon escaped
http://%s/
#scheme http
#host escaped
%s
#path /
#gecko-canon escaped
http://%s/
#gecko-host escaped
%s
#ie-canon escaped
http://%s/
#ie-host escaped
%s
#ie-invalid %s

},
        ($args{pe_input} ? pe $orig : uescape $orig),
        uescape $punycoded,
        uescape $punycoded,
        uescape $gecko_host,
        uescape $gecko_host,
        uescape $ie_host,
        uescape $ie_host,
        $ie_invalid;
  }
  close $file;
} # generate_from_map

sub generate_from_list ($$;%) {
  my $map = shift;
  my $file_name = shift;
  my %args = @_;

  my $file_index = 1;
  my $n = 0;
  my $f = $generated_d->file ($file_name . '-' . $file_index . '.dat');
  print $f->relative, "...\n";
  my $file = $f->openw;
  my @map = @$map;
  while (@map) {
    my $from = shift @map;
    my $to = shift @map || $from;
    for my $v ($from..$to) {
      next if 0xD840 < $v and $v < 0xDBC0;
      next if 0xDC40 < $v and $v < 0xDFC0;
      next if 0xE040 < $v and $v < 0xEFC0;
      next if 0xF040 < $v and $v < 0xF8C0;
      next if 0x30000 < $v and $v < 0xDFFFF and ($v & 0xFFFF) < 0xFFF0;
      next if 0xE00C0 < $v and $v < 0xEFFF0;
      next if 0xF0010 < $v and $v < 0xFFFF0;
      next if 0x100010 < $v and $v < 0x10FFF0;
      my $orig = $args{unsafe} ? "\x{FFFD}" : chr $v;
      my $new = NFC lc uc NFKD $orig;
      my $newc = {
          "\x00" => "\x{FFFD}", # This is wrong.
          "\x09" => '',
          "\x0A" => '',
          "\x0B" => '',
          "\x0C" => '',
          "\x0D" => '',
          "\x{200B}" => '', # ZERO WIDTH SPACE
          "\x{200C}" => '',
          "\x{200D}" => '',
          "\x{2028}" => $args{invalid} && $args{invalid} == 0.5 ? '' : undef,
          "\x{2029}" => $args{invalid} && $args{invalid} == 0.5 ? '' : undef,
          "\x{2060}" => '',
          "\x{FEFF}" => '',
      }->{$new};
      $new = $newc if defined $newc;

      # Firefox: U+03F9 (Unicode 4.0+) -> U+03C3 (NFKD > uc > lc > NFC)

      $n++;
      if ($n >= 1000) {
        $file_index++;
        $f = $generated_d->file ($file_name . '-' . $file_index . '.dat');
        print $f->relative, "...\n";
        $file = $f->openw;
        $n = 0;
      }

      my $BEFORE = 'a';
      my $AFTER = 'b';
      ($BEFORE, $AFTER) = ("\x{0640}", "\x{0641}") if is_rtl $orig;
      
      my $punycoded = pe ($BEFORE . $new . $AFTER);
      if ($v == 0x1680) {
        if ($args{pe_input}) {
          print $file q{#data escaped
http://a%E1%9A%80b/
#invalid 1
#scheme http
#path /
#chrome-invalid 1
#chrome-canon escaped
http://a%E1%9A%80b/
#gecko-not-invalid 1
#gecko-canon
http://a%e1%9a%80b/
#gecko-host
a%e1%9a%80b
#ie-canon
http://a%e1%9a%80b/
#ie-host
a%e1%9a%80b

};
        } else {
          print $file q{#data escaped
http://a\u1680b/
#invalid 1
#scheme http
#path /
#chrome-invalid 1
#chrome-canon escaped
http://a%E1%9A%80b/
#gecko-not-invalid 1
#gecko-canon escaped
http://a\u1680b/
#gecko-host escaped
a\u1680b
#ie-invalid 1

};
        }
      } elsif ($v == 0x0340) {
        if ($args{pe_input}) {
          print $file q{#data escaped
http://a%CD%80b/
#canon escaped
http://xn--b-rfa/
#scheme http
#host escaped
xn--b-rfa
#path /
#gecko-canon escaped
http://a%cd%80b/
#gecko-host escaped
a%cd%80b
#ie-canon escaped
http://a%cd%80b/
#ie-host escaped
a%cd%80b

};
        } else {
          print $file q{#data escaped
http://a\u0340b/
#canon escaped
http://xn--b-rfa/
#scheme http
#host escaped
xn--b-rfa
#path /
#gecko-canon escaped
http://a\u0340b/
#gecko-host escaped
a\u0340b
#ie-canon escaped
http://\u00E0b/
#ie-host escaped
\u00E0b

};
        }
      } elsif ($v == 0x0341) {
        if ($args{pe_input}) {
          print $file q{#data escaped
http://a%CD%81b/
#canon escaped
http://xn--b-tfa/
#scheme http
#host escaped
xn--b-tfa
#path /
#gecko-canon escaped
http://a%cd%81b/
#gecko-host escaped
a%cd%81b
#ie-canon escaped
http://a%cd%81b/
#ie-host escaped
a%cd%81b

};
        } else {
          print $file q{#data escaped
http://a\u0341b/
#canon escaped
http://xn--b-tfa/
#scheme http
#host escaped
xn--b-tfa
#path /
#gecko-canon escaped
http://a\u0341b/
#gecko-host escaped
a\u0341b
#ie-canon escaped
http://\u00E1b/
#ie-host escaped
\u00E1b

};
        }
      } elsif ($v == 0xFE13 and not $args{pe_input}) {
        print $file q{#data escaped
http://a\uFE13b/
#invalid 1
#scheme http
#path /
#chrome-not-invalid 1
#chrome-canon escaped
http://xn--ab-g82n/
#chrome-host escaped
xn--ab-g82n
#gecko-not-invalid 1
#gecko-canon escaped
http://a\u003Ab/
#gecko-host escaped
a\u003Ab
#ie-canon escaped
http://a\u003Ab/
#ie-host escaped
a\u003Ab
#ie-invalid 1

};
      } elsif (0 and $v == 0xFE14 and not $args{pe_input}) {
        print $file q{#data escaped
http://a\uFE14b/
#invalid 1
#scheme http
#path /
#chrome-not-invalid 1
#chrome-canon escaped
http://xn--ab-j82n/
#chrome-host escaped
xn--ab-j82n
#gecko-not-invalid 1
#gecko-canon escaped
http://a\u003Bb/
#gecko-host escaped
a\u003Bb
#ie-canon escaped
http://a\u003Bb/
#ie-host escaped
a\u003Bb
#ie-invalid 1

};
      } elsif (0 and $v == 0xFE16 and not $args{pe_input}) {
        print $file q{#data escaped
http://a\uFE16b/
#invalid 1
#scheme http
#path /
#chrome-not-invalid 1
#chrome-canon escaped
http://xn--ab-p82n/
#chrome-host escaped
xn--ab-p82n
#gecko-not-invalid 1
#gecko-canon escaped
http://a\u003Fb/
#gecko-host escaped
a\u003Fb
#ie-canon escaped
http://a\u003Fb/
#ie-host escaped
a\u003Fb
#ie-invalid 1

};
      } elsif ($v == 0xFE19 and not $args{pe_input}) {
        print $file q{#data escaped
http://a\uFE19b/
#invalid 1
#scheme http
#path /
#chrome-not-invalid 1
#chrome-canon escaped
http://xn--ab-y82n/
#chrome-host escaped
xn--ab-y82n
#gecko-canon escaped
http://a...b/
#gecko-host escaped
a...b
#ie-canon escaped
http://a...b/
#ie-host escaped
a...b
#ie-invalid 1

};
      } elsif (not ($punycoded =~ /\A(?:[\x20-\x24\x26-\x7E]|%[0-7][0-9A-F])+\z/) and
          ($args{unsafe} or $new ne "\x{FFFD}" or $v == 0xFFFD) and
          $v != 0x0340 and $v != 0x0341 and not $args{unassigned} and
          $args{invalid} and
          not ($args{invalid} == 0.5 and $new =~ /[\x80-\x9F]/)) {
        my $ie_host = uescape ($args{pe_input} ? $BEFORE . (lc pe (chr $v)) . $AFTER : $BEFORE . ($args{unsafe} && $args{unsafe} ne 'noncharacters' ? "\x{FFFD}" : chr $v) . $AFTER);
        my $ie_invalid = $args{pe_input} && $BEFORE eq 'a' ? '' : '1';
        if ($ie_host =~ s/\\uFD..|\\uFFF[EF]//g) {
          $ie_invalid = '';
        }
        printf $file q{#data escaped
http://%s%s%s/
#invalid 1
#scheme http
#path /
#chrome-invalid 1
#chrome-canon escaped
http://%s/
#gecko-not-invalid 1
#gecko-canon escaped
http://%s/
#gecko-host escaped
%s
#ie-canon escaped
http://%s/
#ie-host escaped
%s
#ie-invalid %s

},
            uescape $BEFORE,
            $args{pe_input} ? pe chr $v : $args{unsafe} ? sprintf '\U%08X', $v : uescape $orig,
            uescape $AFTER,
            uescape $punycoded,
            uescape ($args{pe_input} ? $BEFORE . (lc pe (chr $v)) . $AFTER : $BEFORE . ($args{unsafe} && $args{unsafe} ne 'noncharacters' || $v == 0xFFFE || $v == 0xFFFF ? "\x{FFFD}" : chr $v) . $AFTER),
            uescape ($args{pe_input} ? $BEFORE . (lc pe (chr $v)) . $AFTER : $BEFORE . ($args{unsafe} && $args{unsafe} ne 'noncharacters' || $v == 0xFFFE || $v == 0xFFFF ? "\x{FFFD}" : chr $v) . $AFTER),
            $ie_host,
            $ie_host,
            $ie_invalid;
      } else {
        my $host = $BEFORE . (defined $newc ? $newc : chr $v) . $AFTER;
        my $gecko_host;
        my $ie_invalid = $args{ie_invalid} && $v != 0x200B && !$args{pe_input} && $BEFORE eq 'a' ? '1' : '';
        if ($v == 0x0340 or $v == 0x0341) {
          $punycoded = to_punycode_with_prefix NFKC $host;
          $gecko_host = $host;
        } elsif ($args{unassigned}) {
          $punycoded = to_punycode_with_prefix $host;
          my $v_mod = NFKC chr $v;
          $v_mod =~ tr/\x{3002}/./;
          $v_mod = lc $v_mod if $v_mod ne chr $v;
          {
            $gecko_host = $BEFORE . ($v_mod) . $AFTER;
            my $ver = string_unicode_version (chr $v);
            $gecko_host = $BEFORE . (chr $v) . $AFTER 
                if not defined $ver or $ver > '4.1';
            $gecko_host = to_punycode_with_prefix $gecko_host
                if $gecko_host =~ /[^\x00-\x7F]/;
            $gecko_host =~ tr/A-Z/a-z/;
          }
          {
            $host = $BEFORE . ($v_mod) . $AFTER;
            $host = to_punycode_with_prefix $host
                if $host =~ /[^\x00-\x7F]/;
            $host =~ tr/A-Z/a-z/;

            $host =~ s{([\x00-\x2A\x2C\x2F\x3A-\x40\x5C\x5E\x60\x7B-\x7D\x7F])}{
              sprintf '%%%02X', ord $1;
            }ge;
          }
          $ie_invalid = 1;
        } else {
          $gecko_host = $host;
          ## Ad hoc fix...
          $host = $punycoded if $punycoded =~ /%20/ or $v == 0x200C or $v == 0x200D;
        }
        printf $file q{#data escaped
http://%s%s%s/
#canon escaped
http://%s/
#host escaped
%s
#chrome-canon escaped
http://%s/
#scheme http
#chrome-host escaped
%s
#path /
#gecko-canon escaped
http://%s/
#gecko-host escaped
%s
#ie-canon escaped
http://%s/
#ie-host escaped
%s
#ie-invalid %s

},
            uescape $BEFORE,
            $args{pe_input} ? pe chr $v : $args{unsafe} ? sprintf '\U%08X', $v : uescape $orig,
            uescape $AFTER,
            uescape $host,
            uescape $host,
            uescape $punycoded,
            uescape $punycoded,
            uescape ($args{pe_input} ? (lc pe ($BEFORE . (chr $v) . $AFTER)) : $gecko_host),
            uescape ($args{pe_input} ? (lc pe ($BEFORE . (chr $v) . $AFTER)) : $gecko_host),
            uescape ($args{pe_input} ? (lc pe ($BEFORE . (chr $v) . $AFTER)) : $gecko_host),
            uescape ($args{pe_input} ? (lc pe ($BEFORE . (chr $v) . $AFTER)) : $gecko_host),
            $ie_invalid;
      }
    } # $v
  }
  close $file;
} # generate_from_list

generate_from_map
    \@Unicode::Stringprep::Mapping::B1
    => 'decomps-authority-stringprep-b1',
    remove => 1;
generate_from_map
    \@Unicode::Stringprep::Mapping::B1
    => 'decomps-authority-stringprep-b1-pe',
    remove => 1,
    pe_input => 1;
generate_from_map
    \@Unicode::Stringprep::Mapping::B2
    => 'decomps-authority-stringprep-b2';
generate_from_map
    \@Unicode::Stringprep::Mapping::B2
    => 'decomps-authority-stringprep-b2-pe',
    pe_input => 1;
#generate_from_map
#    \@Unicode::Stringprep::Mapping::B3
#    => 'decomps-authority-stringprep-b3';

#generate_from_list
#    \@Unicode::Stringprep::Prohibited::C11
#    => 'decomps-authority-stringprep-c11';
generate_from_list
    \@Unicode::Stringprep::Prohibited::C12
    => 'decomps-authority-stringprep-c12',
    ie_invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C12
    => 'decomps-authority-stringprep-c12-pe',
    pe_input => 1;
#generate_from_list
#    \@Unicode::Stringprep::Prohibited::C21
#    => 'decomps-authority-stringprep-c21';
generate_from_list
    \@Unicode::Stringprep::Prohibited::C22
    => 'decomps-authority-stringprep-c22',
    invalid => 1; # chrome/ie -> 1, gecko -> 0, opera -> 0.5
generate_from_list
    \@Unicode::Stringprep::Prohibited::C22
    => 'decomps-authority-stringprep-c22-pe',
    pe_input => 1,
    invalid => 1; # chrome/ie -> 1, gecko -> 0, opera -> 0.5
generate_from_list
    \@Unicode::Stringprep::Prohibited::C3
    => 'decomps-authority-stringprep-c3',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C3
    => 'decomps-authority-stringprep-c3-pe',
    pe_input => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C4
    => 'decomps-authority-stringprep-c4',
    unsafe => 'noncharacters',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C4
    => 'decomps-authority-stringprep-c4-pe',
    pe_input => 1,
    unsafe => 'noncharacters',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C5
    => 'decomps-authority-stringprep-c5',
    unsafe => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C5
    => 'decomps-authority-stringprep-c5-pe',
    pe_input => 1,
    unsafe => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C6
    => 'decomps-authority-stringprep-c6',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C6
    => 'decomps-authority-stringprep-c6-pe',
    pe_input => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C7
    => 'decomps-authority-stringprep-c7',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C7
    => 'decomps-authority-stringprep-c7-pe',
    pe_input => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C8
    => 'decomps-authority-stringprep-c8',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C8
    => 'decomps-authority-stringprep-c8-pe',
    pe_input => 1,
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C9
    => 'decomps-authority-stringprep-c9',
    invalid => 1;
generate_from_list
    \@Unicode::Stringprep::Prohibited::C9
    => 'decomps-authority-stringprep-c9-pe',
    pe_input => 1,
    invalid => 1;

generate_from_list
    \@Unicode::Stringprep::Unassigned::A1,
    => 'decomps-authority-stringprep-a1',
    unassigned => 1;

__END__

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
