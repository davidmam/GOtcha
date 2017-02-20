#!/usr/bin/perl -w

use DBI;
use Getopt::Long;

# use strict;
# script to run a series of jobs on the cluster.
# each dataset is in its own subdirectory: organism/vGSS or organism/peptide

# under this are /sequence
#               /blast
#               /gohst

=pod

=head1 gotcharunner.pl

Batch script for running GOtcha under SGE. 

./gotcharunner [options]
options:
    -path <path> #Additional directories to add to the system $PATH.
    -dataroot <path> # source of directories holding the seqindex file that lists all the sequences to be processed
    -seqtodo <int> # number of sequences to process per batch. 
    -seqtype [P|N|A] # Sequence type protein, Nucleic acid or Auto detect
    -gotchaconf <path to file> # Gotcha configuration file.
=cut

    my $dbtable="gotcharesults";
my $path="";
my $seqtodo=100;
my $seqtype="P";
my $gotchaconf="";
my $dataroot=".";
my $seqdb="";
my $tmpdir="";
my $dbiconn="";
my $dbuser="";
my $dbpass="";
GetOptions("path=s"=>\$path,
	   "tmpdir=s"=>\$tmpdir,
	   "dataroot=s"=>\$dataroot,
	   "seqtodo=i"=>\$seqtodo,
	   "seqtype=s"=>\$seqtype,
	   "seqdb=s"=>\$seqdb,
           "dbiconn=s"=>\$dbiconn,
           "dbuser=s"=>\$dbuser,
           "dbpass=s"=>\$dbpass,	   
           "gotchaconf=s"=>\$gotchaconf
	   );
print STDERR "job running on $ENV{'HOSTNAME'}\n";

print STDERR <<CONF;
path $path
dataroot $dataroot
seqtodo $seqtodo
seqtype $seqtype
gotchaconf $gotchaconf
CONF

    unless ($gotchaconf) {
	if (-e "$dataroot/gotcha.conf") {
	    $gotchaconf="$dataroot/gotcha.conf";
	    print STDERR "GOTCHACONF now $gotchaconf\n";
	} elsif (-e "$ENV{GOTCHA_LIB}/data/gotcha.conf"){
	    $gotchaconf="$ENV{GOTCHA_LIB}/data/gotcha.conf";
	    print STDERR "GOTCHACONF now $gotchaconf\n";
	}
    }

my $seqdbinf="";
if ($seqdb) {
    $seqdbinf="--seqdb $seqdb";
}
print STDERR "job running on $ENV{'HOSTNAME'}\n";
if ($path){
    $ENV{PATH}.=":$path";
    print STDERR "PATH now $ENV{PATH}\n";
}

my $rungotcha= `which rungotcha.pl`; 

unless ($rungotcha){
    die "cannot find rungotcha.pl\n";
}

my @seqindex=();

# force resync of required cluster packages

# foreach my $p (@cpkg) {
#    system ("/conf/cluster/bin/cpkg_get $p");
# }

# create a temporary fast directory.
#
#if (! -e "$tmpdir/bonsai/bin" ) {
#	mkdir "$tmpdir/bonsai/bin", 0755;
#}
unless ($ENV{GOTCHA_LIB}){
    $ENV{GOTCHA_LIB}="/homes/www-gotcha/dist";
}
unless ($ENV{GOTCHA_LIB} ) {
    die "GOTCHA_LIB not set\n";
}

$ENV{PERL5LIB}="/sw/lib/perl:/sw/lib/perl/arch/:$ENV{GOTCHA_LIB}/lib";
#unless ($ENV{BLASTMAT}){
#    $ENV{BLASTMAT}="/opt/BioBrew/NCBI/6.1.0/data";
#}
unless ($tmpdir){
    $tmpdir=$ENV{TMPDIR};
}
unless (-e "$tmpdir/bonsai") {
    mkdir "$tmpdir/bonsai", 0755;
}
# system("chmod 755 /tmp/bonsai");
# system "rsync -ra  $ENV{GOTCHA_LIB}/[^s]* /tmp/bonsai";

# $dataroot=shift @ARGV;

unless (-e $dataroot && -r $dataroot && -d $dataroot) {
    my $dr=$dataroot;
 if (-e $dataroot) {$dr.="-e";} 
 if (-r $dataroot) {$dr.="-r";} 
 if (-d $dataroot) {$dr.="-d";} 
    die "incorrectly specified data root $dr\n";
} 

unless (-e "$dataroot/seqindex"){
    die "no sequence index found\n";
}

# second arguement is the number of sequences to process

# $seqtodo=shift @ARGV;

# $seqtype=shift @ARGV;
print STDERR "reading SEQTYPE as $seqtype\n";
unless ($seqtodo) {
    $seqtodo=100;
}
# $workdir=shift @ARGV;

# $seqdb=shift @ARGV;

print STDERR "initialising\n";

#open (SEARCH, "$dataroot/searchdb") or die "no DB to search :$!\n";
#@searchdb=<SEARCH>;
#close SEARCH;
#for ($s=0; $s< scalar @searchdb; $s++) {
#    chomp $searchdb[$s];
#}
$searchdb=join ",",@searchdb;
print STDERR "searching $searchdb\n";

# read in the sequence index file.
open (SEQIN, "$dataroot/seqindex") or die "cannot open $dataroot/seqindex:$!\n";
while (<SEQIN>){
    chomp;
    my ($num,$id,$junk)=split /[ \t]+/,$_;
  #  print STDERR "$id, $num, $junk\n"; 
    if($num){
	$seqindex[$num]=$id;
    }else {
	push @seqindex, $id;
    }
}
close SEQIN;
my $seqtotal=$#seqindex;

$startseq=$ENV{'SGE_TASK_ID'};

unless ($startseq) {
    $startseq=$ENV{'COD_TASK_ID'};
}

$startseq=($startseq-1)*$seqtodo +1;
my $conn=DBI->connect($dbiconn, $dbuser, $dbpass, {AutoCommit => 1});
print STDERR "DBI connection $conn status ".$conn->errstr()."\n";
die $conn->errstr()."\n" if $conn->errstr; 


print STDERR "starting at $startseq\n";
for (my $s=$startseq;$s<=$seqtotal && $s<$startseq+$seqtodo;$s++){

    rungotcha($s);

}
$conn->disconnect();

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
	if (-e "$tmpdir/gotcha/$seq") {
	    system("rm -rf $tmpdir/gotcha/$seq");
	}
	
  #  my @gotcha_param=(
  #		      "--searchdb $searchdb",
  #		      "--linkprefix=./",
  #		      "--goidx /tmp/bonsai/data/terms.idx",
  #		      "--linkidx /tmp/bonsai/data/links.idx",
  #		      "--scoreidx /tmp/bonsai/data/scores.idx",
  #		      "--blastdb /tmp/bonsai/db",
  #		      "--blastmat $ENV{BLASTMAT}",
  #		      "--xref EC",
  #		      "--seqdb $seqdb",
  #		      "--seqtype $seqtype",
  #		      "--nopng",
  #		     # "--debug",
  #		      "--embosspath=/sw/bin",
  #		      "--contigid $s"
 #		      );
#	my @archpar=(	
#	"--tar $dataroot/gotcha/$seq.tar.gz",
#	"--outcomp 1",
#	"--incomp 1"
#			);
	print STDERR `which rungotcha.pl`;
	print STDERR "rungotcha.pl --infile=$seqfile --outfile $tmpdir/gotcha/$seq --config $gotchaconf --contigid $s ; rungotcha.pl --infile=$seqfile --outfile $tmpdir/gotcha/$seq --reprocess all  --contigid $s --config $gotchaconf; rungotcha.pl --infile=$seqfile --reprocess noiea --contigid $s --config $gotchaconf --excludecode IEA --outfile $tmpdir/gotcha/$seq; \n";
#	print STDERR "cd /tmp/bonsai/bin; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq --reprocess all ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --reprocess noiea --excludecode IEA --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."\n";
	system("rungotcha.pl --infile=$seqfile --contigid $s --outfile $tmpdir/gotcha/$seq --config $gotchaconf ; rungotcha.pl --infile=$seqfile --contigid $s --outfile $tmpdir/gotcha/$seq --reprocess all --config $gotchaconf $seqdbinf; rungotcha.pl --contigid $s --infile=$seqfile --reprocess noiea --config $gotchaconf --excludecode IEA --outfile $tmpdir/gotcha/$seq $seqdbinf; ");
#	system("cd /tmp/bonsai/bin; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --outfile /tmp/gotcha/$seq --reprocess all ".join (" ", @gotcha_param,@archpar)."; ./rungotcha.pl --infile=$seqfile --reprocess noiea --excludecode IEA --outfile /tmp/gotcha/$seq ".join (" ", @gotcha_param,@archpar));
	
# read in sqlfiles here and put in database.
	foreach  my $r (qw/all noiea/){ 
	    print STDERR "SQL: opening $tmpdir/gotcha/$seq/gotcha.sql.$r\n";
	    
	    unless (0){    open (SQL, "$tmpdir/gotcha/$seq/gotcha.sql.$r") or warn "cound not open $tmpdir/gotcha/$seq/gotcha.sql.$r :$!\n";
			   print STDERR "SQLCONN: $conn".$conn->state()."\n";
			   while (<SQL>){
			       chomp;
			       unless (m/^--/){
				   print STDERR "SQL:$_\n";
				   if ($_=~/INSERT/){
				       eval {
					   s/;//;
					   $sth=$conn->prepare($_);
					   $rv=$sth->execute();
					   print STDERR "SQL return $rv ".$sth->errstr."\n";	
				       };

				       if ($@){ print STDERR $@."\n";}
				   }
			       }

			   }
			   
			   
			   close SQL;
		       }
	    # system( "cat /tmp/gotcha/$seq/gotcha.sql.$r |ssh kinshar bonsai/bin/newbuilder/dbloader.pl");
	    
	    
	}
	system("rm -rf $tmpdir/gotcha/$seq");
	
	
    }else {
	print STDERR "$seqfile not found\n";
    }
    
    
}








