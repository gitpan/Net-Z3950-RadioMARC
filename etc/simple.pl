#!/usr/bin/perl

# $Id: simple.pl,v 1.7 2004/11/23 17:06:27 mike Exp $

use strict;
use warnings;

use Net::Z3950::RadioMARC;


set host => 'indexdata.com', port => '210', db => 'gils';
set delay => 3;
set verbosity => 2;
set messages => { ok => "This is the default 'OK' message" };

add "etc/sample.marc";

test '@attr 1=4 data', { ok => '245$a is searchable as 1=4',
			 notfound => 'Search OK but record not found',
			 fail => '%{query}: search fails: %{errmsg}' };
test '@attr 1=999 data';
test '@attr 1=4 fruit';
