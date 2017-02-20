#!/usr/bin/perl -w
our $conn;
our %ensembl;
our %zfin;
our %seq_source;

require 'dblib.pl';

use Getopt::Long;

my $taxid="";
my $db="";
my $outdir=".";
#my $datadir="./genome_specific";
my $test="";
my $seqtestcount=0;
my $seqcount=0;
my $seqerrcount=0;
my $dbn="";
my $dbr="";

$result=GetOptions("taxid=i"=>\$taxid,
		   "outdir=s"=>\$outdir,
		   "test"=>\$test,
 		   "dbn=s"=>\$dbn,
		   "dbr=s"=>\$dbr
		   );




#my $ncbi=shift @ARGV;
if ($dbn && $dbr){
    print STDERR "retrieving $dbr from $dbn\n";
    my $dbname_short= uc $dbn;
    print STDERR "retrieving from $dbname_short:";
    $dbname_short=~s/^(GENEDB)_.*$/$1/;
    print STDERR " $dbname_short\n";
    unless (exists($seq_source{$dbname_short})){
	print STDERR "No method to retrieve sequences from $dbn\n";
	exit;
    }
    my ($header,$seq)=&{$seq_source{$dbname_short}}($dbn,$dbr);
    unless ($seq){
	if ($header){
	    print STDERR "Error retrieving $dbr from $dbn ($header)\n";
	}else{
	    print STDERR "Error retrieving $dbr from $dbn\n";
	}
	exit;
    }
    $l = length($seq);
    $display_id = join("_",$dbn, split(/:/, $dbr));
    
    print STDERR ">$display_id ($dbr) $header ";
    print STDERR "($l amino acids)\n";
    print  ">$display_id ($dbr) $header\n";
    my $a=0;
    for ($a=0 ; $a<$l-60;$a+=60) {
	print substr($seq,$a,60)."\n";
    }
    print  substr($seq,$a)."\n";
 
}
unless ($taxid) {die "Must specify a taxonomic ID\n";}
my $dbtag="";
open SEQDBLOG, ">$outdir/db_$taxid$dbtag.log";
if ($test) { $dbtag="_test";}
open SEQDB, ">$outdir/db_$taxid$dbtag.fasta";
open SEQDBERR, ">$outdir/db_$taxid$dbtag.errors";
open SEQDBPROC, ">$outdir/db_$taxid$dbtag.proc";
print SEQDBPROC $ENV{JOB_ID};
close SEQDBPROC;
if ($test){
    my $sql="select distinct x.xref_dbname  from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref x on x.id=g.dbxref_id where s.ncbi_taxa_id = ?";
    my $sql2="select g.id, s.ncbi_taxa_id,  g.symbol, s.genus, s.species, s.common_name, g.full_name, x.xref_key, x.xref_dbname  from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref x on x.id=g.dbxref_id where s.ncbi_taxa_id = ? and x.xref_dbname=? limit 5";
    $sth=$conn->prepare($sql);
    $sr=$conn->prepare($sql2);
    $sth->execute($taxid);
    while (my $hr=$sth->fetchrow_hashref()){
	if (exists($hr->{xref_dbname}) && $hr->{xref_dbname}){
	    $sr->execute($taxid, $hr->{xref_dbname});
	    while (my $tr=$sr->fetchrow_hashref()){
		$seqtestcount++;
		if (outputseq($tr)){
		    $seqcount++;
		}else {
		    $seqerrcount++;
		} 
	    }
	}
    }
    
} else {

    my $sqlc="select count(*) as count from (select distinct g.id, s.ncbi_taxa_id,  g.symbol, s.genus, s.species, s.common_name, g.full_name, x.xref_key, x.xref_dbname  from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref x on x.id=g.dbxref_id where s.ncbi_taxa_id = ?)as foo";
    my $sql="select distinct g.id, s.ncbi_taxa_id,  g.symbol, s.genus, s.species, s.common_name, g.full_name, x.xref_key, x.xref_dbname  from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref x on x.id=g.dbxref_id where s.ncbi_taxa_id = ?";
    $seqcount=$conn->prepare($sqlc);
    $res=$seqcount->execute($taxid);
    $hr=$seqcount->fetchrow_hashref();
    if (exists($hr->{count})){
	print SEQDBLOG "Preparing to retrieve ".$hr->{count}." sequences\n";
    }
    $seqlist=$conn->prepare($sql);
    $res=$seqlist->execute($taxid);
    $cn="";
    print STDERR "DBSEARCH $res\n";
    while ($hr=$seqlist->fetchrow_hashref()){
	$seqtestcount++;
	if (outputseq($hr)){
	    $seqcount++;
	}else {
	    $seqerrcount++;
	} 
	
    }
}
close SEQDB;
close SEQDBERR;
print SEQDBLOG "Tried $seqtestcount, retrieved $seqcount sequences. Failed to retrieve $seqerrcount sequences\n";
close SEQDBLOG;
unless($test){
    $title="\'Tx:$taxid ($cn)\'";
    
    system ("/sw/bin/formatdb -p T -i $outdir/db_$taxid.fasta -n $outdir/db_$taxid -t $title");
}
 
unlink "$outdir/db_$taxid$dbtag.proc";


	
	
	

 
# ##################SUBROUTINES###################

__END__


=head1 NAME

seqdbbuilder.pl

=head1 SYNOPSIS

Admin program for building the sequence databases for GOtcha.

=head1 DESCRIPTION

This program should be called as seqdbbuilder.pl <options>

=head2 Options

 -taxid <taxid> # taxonomic ID for database
 -outdir <path> # [$ENV{GOTCHALIB}/data] directory into which to write the database file 
 -dbn <databsaename> # options to use for retrieving a single sequence
 -dbr <accession>  # options to use for retrieving a single sequence
 -test # limits the retrieval to 5 sequences - useful for testing the code.

=head1 AUTHOR

Dr David Martin

=head1 BUGS

The target DBs keep changing underfoot. This can be problematic and requires testing and revision of the code.

=head1 COPYRIGHT

This software is copyright 2009 David Martin and the University of Dundee. All rights reserved.

