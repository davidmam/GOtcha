#!/usr/bin/perl

use DBI;
use lib "/sw/perl";
use lib "/sw/lib/perl";

use strict;
use Getopt::Long;
	
my $dataroot=$ENV{GOTCHA_LIB};
my @taxa=();
my $dbiconn="";
my $dbuser="";
my $dbpass="";

GetOptions("dataroot=s"=>\$dataroot,
	   "dbiconn=s"=>\$dbiconn,
	   "dbuser=s"=>\$dbuser,
	   "dbpass=s"=>\$dbpass,
	   "taxa=s"=>\@taxa
	   );

@taxa=split/,/, join(",",@taxa);

#edit this line to get your DB connection
my $conn=DBI->connect($dbiconn,$dbuser, $dbpass, {AutoCommit => 1});
#should probably do some error checking here.
# bear in mind that Oracle defaults to upepr case field names, postgres to lower case when constructing the table.. 

my $sql = 'select * from gotcharesult where seqdb = ? and reprocess = ?';

my $sth=$conn->prepare($sql);

open (IEA, ">$dataroot/calibration/gotcha_iea") or die "could not open iea calibration file: $!\n";
open (NOIEA, ">$dataroot/calibration/gotcha_noiea") or die "could not open noiea calibration file: $!\n";

foreach my $dn (@taxa){
    next unless (-e "$dataroot/sequence/db_$dn");
    print STDERR "processing database results for db_$dn\n";
    my %seqidx=();
    open(SEQIDX, "$dataroot/sequence/db_$dn/seqindex" ) or die "could not open sequence index: $!\n";
    print STDERR "reading sequence index from $dataroot/sequence/$dn/seqindex\n";
    while (my $line=<SEQIDX>) {
	chomp $line;
	my ($key, $value)=split /\t/, $line;	
	unless ($value) {
	    print STDERR "error parsing seqindex file $line\n";
	}
	$seqidx{$key}=$value;
    }
    print STDERR (scalar keys %seqidx)." records from sequence index read\n";
    close SEQINDEX;
    $sth->execute("db_$dn", "noiea");
    my $reccount=0;
    while(my $hr=$sth->fetchrow_hashref()){
	if (exists($hr->{CONTIGID}) && $hr->{CONTIGID}){
	    $reccount++;
	    my $id=$hr->{CONTIGID};
	    my $seqdb=$hr->{SEQDB};
	    $seqdb=~s/^db_//;
	    my $seqname=$seqidx{$id};
	    my $reprocess=$hr->{REPROCESS};
	    my $term="GO:".$hr->{GOTERM};
	    my $score=$hr->{ISCORE};
	    my $sd=$hr->{VAR};
	    my $conf=$hr->{CSCORE};
	    my $pscore=$hr->{PSCORE};
	    my $ont=$hr->{ONTOLOGY};
	    print NOIEA join("\t",$id,$seqdb,$seqname,"","",$reprocess,$term,$score,$sd,$conf,$pscore,$ont)."\n";
	}
    }
    print STDERR "$reccount records for db_$dn (noiea)\n";
    $reccount=0;
    $sth->execute("db_$dn", "all");
    while(my $hr=$sth->fetchrow_hashref()){
	if (exists($hr->{CONTIGID}) && $hr->{CONTIGID}){
	    $reccount++;
	  my $id=$hr->{CONTIGID};
	    my $seqdb=$hr->{SEQDB};
	    $seqdb=~s/^db_//;
	    my $seqname=$seqidx{$id};
	    my $reprocess=$hr->{REPROCESS};
	    my $term="GO:".$hr->{GOTERM};
	    my $score=$hr->{ISCORE};
	    my $sd=$hr->{VAR};
	    my $conf=$hr->{CSCORE};
	    my $pscore=$hr->{PSCORE};
	    my $ont=$hr->{ONTOLOGY};
	    print IEA join("\t",$id,$seqdb,$seqname,"","",$reprocess,$term,$score,$sd,$conf,$pscore,$ont)."\n";
	}
    }
    print STDERR "$reccount records for db_$dn (all)\n";  
}

close IEA;
close NOIEA;
$conn->disconnect();
