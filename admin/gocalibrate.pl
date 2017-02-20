#!/usr/bin/perl -w

use GOdb;
use Getopt::Long;
use strict;

my %annotations=();

# $annofile= shift @ARGV; # name of file containing given annotations
# $resfile=shift @ARGV; # file containing predicted annotations.
# $exclcodes=shift @ARGV; # evidence codes to ignore (comma separated.)

my $annofile="";  # name of file containing given annotations
my $resfile=""; # file containing predicted annotations.
my @ecodes=(); # evidence codes to ignore (comma separated.)
my $outfile="calibfile";
GetOptions(
	   "annotations=s"=>\$annofile,
	   "results=s"=>\$resfile,
	   "outfile=s"=>\$outfile,
	   "evidence=s"=>\@ecodes
	   );

@ecodes=split /,/, join (",", @ecodes);
unless ($ENV{GOTCHA_LIB}) {
    die "GOTCHA_LIB not specified\n";
}

print STDERR "opening $annofile g_a $resfile pred \n";
open OUTFILE, ">$ENV{GOTCHA_LIB}/calibration/$outfile" or die "cannot open output file $outfile: $!\n";

my %exclude=();
my %seqonts=();
if (@ecodes) {
    foreach my $e (@ecodes){
	$exclude{$e}=1;
    }
}

# get a handle on a GO db. ###EDIT TO SUIT### 
my $godb=GOdb->new("$ENV{GOTCHA_LIB}/data/terms.idx", "$ENV{GOTCHA_LIB}/data/links.idx");
open (GOERROR, ">goerror.out") or warn "cannot open GO error file:$!\n";
open (ANNO, $annofile) or die "cannot open $annofile: $!\n";
while (<ANNO>) {
    chomp;
    next if /^!/;
    my @dat=split /\t/,$_;


    if (! exists($exclude{$dat[7]})){
	
    	if ($dat[4]=~m/GO:/){
	    my ($ont,$goid)=split /:/,$dat[4];
	    $goid=~s/^0+//;
	    my $goterm=$godb->findgoterm($goid);
	    if (ref($goterm ) eq "GOterm"){
		$seqonts{lc $dat[1]}{$goterm->ontology()}=1;
		my @ancestors=$goterm->get_ancestorlist();
		$annotations{lc $dat[1]}{$goid}=1;
		foreach my $a (@ancestors){
		    $annotations{lc $dat[1]}{$a}=1;
		}
	    }else{
		print GOERROR "Error retrieving GO term $goid\n";
	    }
	    
	}
    }
}
close ANNO;

check_unknowns();

open (SEQIDX, "$resfile") or die "cannot open seqindex file\n";
while (my $seqentry=<SEQIDX>){
    chomp $seqentry;
    my ($id,$seqdb,$seqname,$junk,$junkdb,$reprocess,$term,$score,$sd,$confidence,$pscore,$ont)=split /\t/,$seqentry;
print STDERR "Analysing results for $seqname\n";
    my $annotated="N";
    if (exists($annotations{lc $seqname})){
	$annotated="Y";
    }
    unless ($sd) { $sd=0; }
#note bug in output.. GO:GO: instead of GO: 
# may need to check for this ###FIX BUG HERE
	my ($txt, $goid) = split /:/,$term;
    $goid=~s/^0+//;
    if (exists($seqonts{lc $seqname}{$ont})){
	$annotated="Y";
    }else{
	$annotated="N";
	}
    print OUTFILE "$seqname\tGO:$goid\t$score\t$confidence\t$pscore\t$ont\t";
    if (exists($annotations{lc $seqname}{$goid})){
	print OUTFILE "T\t$annotated\n";
    }else{
	print OUTFILE "F\t$annotated\n";
    }
}
close SEQIDX;
close GOERROR;
close OUTFILE;

sub check_unknowns {

# need to remove sequence annotations where *_unknown is present.

    my %unknowns=(8372=>"C",5554=>"F",4=>"P");
    foreach my $s (keys %annotations) {
	foreach my $u (keys %unknowns) {
	    if (exists ($annotations{$s}{$u})){
		delete $seqonts{$s}{$unknowns{$u}};
	    }
	}
    }
}
