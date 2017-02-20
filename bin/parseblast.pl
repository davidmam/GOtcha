#!/usr/bin/perl -w

use Bio::Tools::BPlite;

#script to extract sequences from a file, run BLAST then put the results 
#into the database.

#variables
require "parseblastlib.pl";
foreach $seqfile (@ARGV){

     @hitlist= parseblast($seqfile);
     foreach $hit (@hitlist) {
	 print $hit->tabstring;
     }
}

