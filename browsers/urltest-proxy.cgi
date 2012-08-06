#!/usr/bin/perl
use strict;
use warnings;
use Encode;

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/\x22/&quot;/g;
  return $s;
} # htescape

my $q = $ENV{QUERY_STRING} || '';

if ($q =~ /^c=([^&]+)&u=([^&]+)&b=([^&]+)$/) {
  my $charset = {
    'euc-jp' => ['euc-jp', 'euc-jp'],
    'utf-16' => ['utf-16', 'utf-16'],
    'iso-2022-jp' => ['iso-2022-jp', 'iso-2022-jp'],
    'shift_jis' => ['shift_jis', 'shift_jis'],
    'ibm037' => ['ibm037', 'cp37'],
  }->{$1} || ['utf-8', 'utf-8'];
  my $url = $2;
  my $base = $3;
  for ($url, $base) {
    s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
    $_ = decode 'utf-8', $_;
  }
  my $s = sprintf q{<!DOCTYPE HTML><base href="%s"><a href="%s">xx</a>},
      htescape $base, htescape $url;
  print "Content-Type: text/html; charset=$charset->[0]\n\n";
  print scalar encode $charset->[1], $s;
} else {
  print "Status: 404 Not found\n\n";
}

## License: Public Domain.
