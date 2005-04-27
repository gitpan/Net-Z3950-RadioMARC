# $Id: IndexMARC.pm,v 1.6 2004/12/16 17:34:32 quinn Exp $

package Net::Z3950::IndexMARC;

use 5.008;
use strict;
use warnings;

use MARC::Record;


=head1 NAME

Net::Z3950::IndexMARC - Comprehensive but inefficent index for MARC records

=head1 SYNOPSIS

 $file = MARC::File::USMARC->in($filename);
 $index = new Net::Z3950::IndexMARC();
 while ($marc = $file->next()) {
     $index->add($marc);
 }
 $index->dump(\*STDOUT);
 $hashref = $index->find('@attr 1=4 dinosaur');
 foreach $i (keys %$hashref) {
    $rec = $index->fetch($i);
    print $rec->as_formatted();
 }

=head1 DESCRIPTION

This module provides a comprehensive inverted index across a set of
MARC records, allowing simple keyword retrieval down to the level of
individual field and subfields.  However, it does this by building a
big Perl data-structure (hash of hashes of arrays) in memory, and
makes no efforts whatsoever towards optimisation.  So this is only
appropriate for small collections of records.

=head1 METHODS

=cut


=head2 new()

 $index = new Net::Z3950::IndexMARC();

Creates a new IndexMARC object.  Takes no parameters, and returns the
new object.

=cut

sub new {
    my $class = shift();

    return bless {
	records => [],
	index => {},		# maps queryable terms into records[]
    }, $class;
}


=head2 add()

 $record = new MARC::Record();
 $record->append_fields(...);
 $index->add($record);

Adds a single MARC record to the specified index.  A reference to the
record itself is also added, so the record object will not be garbage
collected until (at least) the index goes out of scope.  The record
passed in must be of the type MARC::Record.

=cut

sub add {
    my $this = shift();
    my($marc) = @_;

    my $reccount = @{ $this->{records} };
    push @{ $this->{records} }, $marc;
    my $index = $this->{index};

    foreach my $field ($marc->fields()) {
	my $tag = $field->tag();
	if ($tag < "010") {
	    # Control fields must be handled separately, or ignored
	    next;
	}

	my @subfields = $field->subfields();
	foreach my $ref (@subfields) {
	    my($subtag, $value) = @$ref;

	    ### We might consider a more sophisticated word-parsing scheme
	    my @words = split /[\s+,\.:\/]/, $value;
	    for (my $pos = 1; $pos <= @words; $pos++) {
		my $word = $words[$pos-1];
		my $indexentry = [ $tag, $subtag, $pos ];

		$word = lc($word); # case-insensitive indexing
		my $wordref = $index->{$word};
		if (!defined $wordref) {
		    # It's the first we've seen this word in any record
		    $index->{$word} = { $reccount => [ $indexentry ] };
		    next;
		}

		my $recref = $wordref->{$reccount};
		if (!defined $recref) {
		    # First time we've seen the word in this record
		    $wordref->{$reccount} = [ $indexentry ];
		    next;
		}

		# Second or subsequent occurrence of word in record
		push @$recref, $indexentry;
	    }
	}
    }
}


=head2 dump()

 $index->dump(\*STDOUT);

Dumps the contents of the specified index to the specified
stream in human-readable form.  Takes no arguments.  Should only be
used for debugging.

=cut

sub dump {
    my $this = shift();
    my($stream) = @_;

    my $index = $this->{index};
    foreach my $word (sort keys %$index) {
	my $wordref = $index->{$word};
	my $gotWord = 0;
	foreach my $reccount (sort { $a <=> $b } keys %$wordref) {
	    print $stream sprintf("%-30s", $gotWord++ ? "" : "'$word'");
	    my $recref = $wordref->{$reccount};
	    my $gotRec = 0;
	    foreach my $indexentry (@$recref) {
		print $stream sprintf("%-8s",
				      $gotRec++ ? " " x 38 : "rec $reccount");
		my($tag, $subtag, $pos) = @$indexentry;
		print $stream "$tag\$$subtag word $pos\n";
	    }
	}
    }
}


=head2 find()

 $hithash = $index->find("@and fruit fish");

Finds records satisfying the specified PQF query, and returns a
reference to a hash consisting of one element for each matching
record.

Each key in the returned hash is a record number, and the
corresponding values contains details of the hits in that record.  The
record number is an integer counting the records in the order in which
they were added to the index, starting at zero.  It can subsequently
be used to retrieve the record itself.

The hit details consist of an array of arbitrary length, one element
per occurrence in the record of the searched-for term.  Each element
of this array is itself an array of three elements: the tag of the
field in which the term exist [0], the tag of the subfield [2], and
the word-number within the field, starting from word 1 [3].

PQF is Prefix Query Format, as described in the ``Tools'' section of
the YAZ manual; however, this module does not perform field-specific
searching since to do so would necessarily involve a mapping between
Type-1 query access points and MARC fields, which we want to avoid
having to assume anything about.  Accordingly, I<all> attributes are
ignored.  Further, at present boolean operations are also ignores, and
only the last term in the query is used as a single lookup point.

=cut

sub find {
    my $this = shift();
    my($pqf) = @_;

    ### This is the world's worst PQF implementation
    my $term = $pqf;
    $term =~ s/.* //;

    my $index = $this->{index};
    my $wordref = $index->{lc($term)};
    return {} if !defined $wordref;
    return $wordref;
}


=head2 fetch()

 $marc = $index->fetch($recordNumber);

Returns the MARC::Record object corresponding to the specified record
number, as returned from find().

=cut

sub fetch {
    my $this = shift();
    my($num) = @_;

    my $records = $this->{records};
    my $count = scalar(@$records);
    die "record number $num out of range 0.." . ($count-1)
	if $num < 0 || $num >= $count;
    return $records->[$num];
}


=head1 PROVENANCE

This module is part of the Net::Z3950::RadioMARC distribution.  The
copyright, authorship and licence are all as for the distribution.

=cut


1;
