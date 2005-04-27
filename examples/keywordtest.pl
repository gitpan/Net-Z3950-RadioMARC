#!/usr/bin/perl -w

# $Id: keywordtest.pl,v 1.2 2004/12/17 04:41:22 quinn Exp $

use strict;
use warnings;
use Net::Z3950::RadioMARC;
my $pattern = 'rmFFF1S11r'; # This is the type of tokens we're using
my $combo;

my $hosturl = 'research.lis.unt.edu:2200/zinterop';

my ($host, $port, $dbname) = $hosturl =~ /(.*):(.*)\/(.*)/;
set host => $host, port => $port, db => $dbname;
set delay => 0;
set identityField => '001';
set verbosity => 1;

add 'record.mrc';

if (test('@attr 1=4 rm2451a11r', {ok=>''}) ne 'ok') {
  print "Test record not found in database -- unable to continue\n";
  exit 1;
}

my @types = (
  {
    'name' => 'author',
    'use' => 1003,
    'fields' => [
      '100$a', '100$d',
      '245$c',
      '700$a', '700$d',
      '710$a'
    ]
  },
  {
    'name' => 'title',
    'use' => 4,
    'fields' => [
      '245$a', '245$b',
      '440$a',
      '490$a'
    ],
  },
  {
    'name' => 'subject',
    'use' => 21,
    'fields' => [
      '600$a', '600$d',
      '650$a', '650$x', '650$v', '650$z',
      '653$a'
    ]
  }
);

# this function returns a MARC token for field$subfield in
# the global $pattern

sub radtoken {
  $_ = shift;
  my $ret = $pattern;

  my ($field, $subfield) = /(...)\$(.)/;
  $ret =~ s/FFF/$field/;
  $ret =~ s/S/$subfield/;
  return $ret;
}

sub runtest {
  my $combo = shift;
  my $list = shift;
  foreach (@{$list}) {
    my $search = "$combo " . radtoken $_;
    test $search, {
      ok=>"Search finds $_",
      notfound=>"Search does NOT find $_"
    };
  }
}

print "Testing Level 0 keyword searching.\n\n";
my $attributes_kw = '@attr 2=3 @attr 3=3 @attr 4=2 @attr 5=100 @attr 6=1';

foreach (@types) {
  my $combo = "\@attr 1=" . $_->{'use'} . " $attributes_kw";
  print "Testing: '" . $_->{name} . "' ($combo)\n";
  runtest $combo, $_->{fields};
  print "\n";
}

$combo = "\@attr 1=1016 $attributes_kw";
print "Testing: Any ($combo)\n";
foreach (@types) {
  runtest $combo, $_->{fields};
}

print "\nTesting Level 1 truncated keyword searching.\n\n";
my $attributes_kwt = '@attr 2=3 @attr 3=3 @attr 4=2 @attr 5=1 @attr 6=1';

foreach (@types) {
  my $combo = "\@attr 1=" . $_->{'use'} . " $attributes_kwt";
  print "Testing: '" . $_->{name} . "' ($combo)\n";
  runtest $combo, $_->{fields};
  print "\n";
}

$combo = "\@attr 1=1016 $attributes_kwt";
print "Testing: Any ($combo)\n";
foreach (@types) {
  runtest $combo, $_->{fields};
}

print "\nTesting level 1 exact author searches.\n\n";

$combo = '@attr 1=1003 @attr 2=3 @attr 3=1 @attr 4=1 @attr 5=100 @attr 6=3';
test "$combo {rm1001a11r, rm1001a21r}", {
  ok=>		'100$a with comma OK',
  notfound=>	'100$a with comma NOT FOUND'
}
