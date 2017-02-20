#!/usr/bin/perl -w

use strict;

while (my $line=<STDIN>){
    if ($line =~m/^>/){
	unless ($line=~m/\(PDB_/){
	    print STDERR $line;
	    $line=~s/>((?:GENEDB_)?(?:TIGR_)?(?:JCVI_)?[^_]+)_([^ ]+)/>$2 $1/;
	    print STDERR "fixed: $line";
	}
    }
    print $line;
}
