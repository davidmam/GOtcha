#!/usr/bin/perl -w

use DBI;
#use strict;
#script to run a series of jobs on the cluster.
# each dataset is in its own subdirectory: organism/vGSS or organism/peptide

#under this are /sequence
#               /blast
#               /gohst

# call program as 'iprscanner.pl /path/to/data seqtodo seqtype '

print STDERR "job running on $ENV{'HOSTNAME'}\n";
$ENV{PATH}.=":/sw/bin";

my @seqindex=();
#GOHST will be found in /software/gohst
#Swissprot should be in /software/swissprot_blast
#my @cpkg=qw/gohst/;

#force resync of required cluster packages

#foreach my $p (@cpkg) {
#    system ("/conf/cluster/bin/cpkg_get $p");
#}

#create a temporary fast directory.
#
if (! -e "/tmp/bonsai/bin" ) {
	mkdir "/tmp/bonsai/bin", 0755;
}
$ENV{GOTCHA_LIB}="/homes/dmamartin/bonsai/bin/newbuilder/NOBACK/go_build";
unless ($ENV{GOTCHA_LIB} ) {
    die "GOTCHA_LIB not set\n";
}
$ENV{PERLLIB}="/sw/lib/perl:/sw/lib/perl/arch/:$ENV{GOTCHA_LIB}/lib";
$ENV{BLASTMAT}="/opt/BioBrew/NCBI/6.1.0/data";
$tmpdir="/tmp";
unless (-e "/tmp/bonsai") {
    mkdir "/tmp/bonsai", 0755;
}
system("chmod 755 /tmp/bonsai");
system "rsync -ra  $ENV{GOTCHA_LIB}/[^s]* /tmp/bonsai";

$dataroot=shift @ARGV;

unless (-e $dataroot && -r $dataroot && -d $dataroot) {
    die "incorrectly specified data root \n";
} 

unless (-e "$dataroot/seqindex"){
    die "no sequence index found\n";
}

# second arguement is the number of sequences to process

$seqtodo=shift @ARGV;

$seqtype=shift @ARGV;
print STDERR "reading SEQTYPE as $seqtype\n";
unless ($seqtodo) {
    $seqtodo=100;
}
# $workdir=shift @ARGV;

$seqdb=shift @ARGV;

print STDERR "initialising\n";

open (SEARCH, "$dataroot/searchdb") or die "no DB to search :$!\n";
@searchdb=<SEARCH>;
close SEARCH;
for ($s=0; $s< scalar @searchdb; $s++) {
    chomp $searchdb[$s];
}
$searchdb=join ",",@searchdb;
print STDERR "searching $searchdb\n";

#read in the sequence index file.
open (SEQIN, "$dataroot/seqindex") or die "cannot open $dataroot/seqindex:$!\n";
while (<SEQIN>){
    chomp;
    my ($num,$id,$junk)=split /\t/,$_;
    $seqindex[$num]=$id;
}
close SEQIN;
my $seqtotal=$#seqindex;

$startseq=$ENV{'SGE_TASK_ID'};

unless ($startseq) {
    $startseq=$ENV{'COD_TASK_ID'};
}

$startseq=($startseq-1)*$seqtodo +1;
my $conn=DBI->connect("dbi:Pg:dbname=dmamartin;host=postgres.compbio.dundee.ac.uk", "dmamartin", "BeepwiUt", {AutoCommit => 0});
print STDERR "starting at $startseq\n";
for (my $s=$startseq;$s<=$seqtotal && $s<$startseq+$seqtodo;$s++){

    rungotcha($s);

}


sub rungotcha {
    my $s=shift;
    my $seq =$seqindex[$s];
	
    
    my $seqfile="$dataroot/sequence/$seq.fasta";
    if ($seq=~m/:/) {
	my ($db,$id)=split /:/, $seq;
	$seqfile="$dataroot/sequence/$id.fasta";
	system ("/sw/bin/seqret $seq $seqfile -osf fasta -auto");
	$seq=$id;
    }
    if (-e $seqfile ) {
	unless (-e "$dataroot/gotcha") {
	    system("mkdir -p $dataroot/gotcha");
	}
	if (-e "/tmp/gotcha/$seq") {
	    system("rm -rf /tmp/gotcha/$seq");
	}
	
    my @gotcha_param=(
		      "--searchdb $searchdb",
		      "--linkprefix=./",
		      "--goidx /tmp/bonsai/data/terms.idx",
		      "--linkidx /tmp/bonsai/data/links.idx",
		      "--scoreidx /tmp/bonsai/data/scores.idx",
		      "--blastdb /tmp/bonsai/db",
		      "--blastmat $ENV{BLASTMAT}",
		      "--xref EC",
		      "--seqdb $seqdb",
		      "--seqtype $seqtype",
		      "--nopng",
		     # "--debug",
		      "--embosspath=/sw/bin",
		      "--contigid $s"
		      );
	my @archpar=(	
#	"--tar $dataroot/gotcha/$seq.tar.gz",
#	"--outcomp 1",
#	"--incomp 1"
			);
	print STDERR "cd /tmp/bonsai/bin; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq --reprocess all ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --reprocess noiea --excludecode IEA --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."\n";
	system("cd /tmp/bonsai/bin; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq --reprocess all ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --reprocess noiea --excludecode IEA --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar));
	
# read in sqlfiles here and put in database.
	foreach  my $r (qw/all noiea/){ 
	    print STDERR "SQL: opening /tmp/gotcha/$seq/gotcha.sql.$r\n";
	    
	    unless (1){    open (SQL, "/tmp/gotcha/$seq/gotcha.sql.$r") or warn "cound not open /tmp/gotcha/$seq/gotcha.sql.$r :$!\n";
			   print STDERR "SQLCONN: $conn".$conn->state."\n";
			   while (<SQL>){
			       chomp;
			       unless (m/^--/){
				   print STDERR "SQL:$_\n";
				   $sth=$conn->prepare($_);
				   $rv=$sth->execute();
				   print STDERR "SQL return $rv ".$sth->errstr."\n";	
			       }
			   }
			   
			   
			   close SQL;
		       }
	    system( "cat /tmp/gotcha/$seq/gotcha.sql.$r |ssh kinshar bonsai/bin/newbuilder/dbloader.pl");
	    
	    
	}
	system("rm -rf /tmp/gotcha/$seq");
	
	
    }else {
	print STDERR "$seqfile not found\n";
    }
    
    
}








