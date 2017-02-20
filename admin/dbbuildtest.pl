#!/usr/bin/perl -w
use Getopt::Long;

our $conn;
our %ensembl;
our %zfin;
our %seq_source;
require 'dblib.pl';

my @taxid=();
my $outdir=".";
# file to test all web database retrievals for the given taxa - reports on the broken ones.



$result=GetOptions("taxid=s"=>\@taxid,
		   "outdir=s"=>\$outdir,
		   );

@taxid=split(/,/,join(",", @taxid));

my $dbsql="select distinct xref_dbname from dbxref d inner join gene_product g on g.dbxref_id=d.id inner join species s on g.species_id=s.id where s.ncbi_taxa_id in(".join(",",@taxid).")";

my $refsql="select g.symbol, d.xref_key from dbxref d inner join gene_product g on g.dbxref_id=d.id inner join species s on g.species_id=s.id where s.ncbi_taxa_id in(".join(",",@taxid).") and d.xref_dbname = ? limit 400";



my $sth=$conn->prepare($dbsql);
$sth->execute();
my $dbh=$conn->prepare($refsql);
while (my $hr=$sth->fetchrow_hashref()){


    my $dbn=$hr->{xref_dbname};
    $dbh->execute($dbn);
    my $success=1;
    my $count=0;
    my $sr="";
    while ( $success && ($sr=$dbh->fetchrow_hashref())){
	my $dbr=$sr->{xref_key};
	my $dbs=$sr->{symbol};
	$count++;
#my $ncbi=shift @ARGV;
	if ($dbn && $dbr){
	    print STDERR "retrieving $dbr from $dbn\n";
	    my $dbname_short= uc $dbn;
	    print STDERR "retrieving from $dbname_short:";
	    $dbname_short=~s/^(GENEDB)_.*$/$1/;
	    print STDERR " $dbname_short\n";
	    unless (exists($seq_source{$dbname_short})){
		print STDERR "No method to retrieve sequences from $dbn\n";
		next;
	    }
	    my ($header,$seq)=&{$seq_source{$dbname_short}}($dbn,$dbr, $dbs);
	    unless ($seq){
		if ($header){
		    print STDERR "Error retrieving $dbr from $dbn ($header)\n";
		}else{
		    print STDERR "Error retrieving $dbr from $dbn\n";
		}
	      
	    } else {
		$success=0;
		my $l = length($seq);
		if ($l==length($dbr)) {$success=1;}
		my $display_id = join("_",$dbn, split(/:/, $dbr));
		
		print STDERR ">$display_id ($dbr) $header ";
		print STDERR "($l amino acids)\n";
		print  ">$display_id ($dbr) $header\n";
		my $a=0;
		for ($a=0 ; $a<$l-60;$a+=60) {
		    print substr($seq,$a,60)."\n";
		}
		print  substr($seq,$a)."\n";
		
	    }
	}
    }
    if ($success) {
	print "Error retrieving sequences from $dbn on $count attempts\n";
    }
    
    
} 
# ##################SUBROUTINES###################
