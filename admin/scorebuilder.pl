#!/usr/bin/perl -w
use FileHandle;
#use lib "/homes/dmamartin/bonsai/bin/dist2/dist/lib";
use GOdb;
use Getopt::Long;
use strict;
#script to generate the scoring tables from results.

#if (scalar @ARGV <3) {
#    die "incorrect number of arguments\n"
#}
my $scoreindex="scores.idx";
my $scoredb="scores.dat";
my $goscoresfile="";
my $goscoresfilenoiea="";

unless ($ENV{GOTCHA_LIB}){
    die "GOTCHA_LIB not defined.\n";
}

GetOptions (
	    "scoreindex=s"=>\$scoreindex,
	    "scoredb=s"=>\$scoredb,
	    "scoresall=s"=>\$goscoresfile,
	    "scoresnoiea=s"=>\$goscoresfilenoiea,
	    );

unless ($scoreindex && $scoredb && $goscoresfile && $goscoresfilenoiea) {
    die "need calibration files\n";
}
unless ($scoreindex=~m!/!){
    $scoreindex=$ENV{GOTCHA_LIB}."/data/$scoreindex";
}
unless ($scoredb=~m!/!){
    $scoredb=$ENV{GOTCHA_LIB}."/data/$scoredb";
}


sysopen (GOIFH, $scoreindex, O_WRONLY|O_CREAT) or die "cannot open GOIFH $!\n";
sysopen (GODFH, $scoredb, O_WRONLY|O_CREAT) or die "cannot open GODFH$!\n";;
binmode GOIFH;
binmode GODFH;


my $godb=GOdb->new("$ENV{GOTCHA_LIB}/data/terms.idx", "$ENV{GOTCHA_LIB}/data/links.idx");
# calculate 2D distribution frequencies for score and conf
# params are score bins, conf bins (default 10)
my %true=();
my %onts=();
my %totals=();
my %ancount=();
my %scores=();
my %tables=();
my %tabletrue=();
open GOSCORE, $goscoresfile or die "cannot open data file: $!\n";
print STDERR "reading scores file\n";
while (<GOSCORE>){
    chomp;
    next if /^!/;
    unless (/^opening/) {
	chomp;
#	print "$_:\n";
	my @a=split /\t/,$_;
	unless ($a[7] eq "N"){
 	    my $score=int($a[2]*10);
	    my $conf=int($a[3]);
	    my $term=$a[1];
	    $term=~s/GO://;
	    $onts{$term}=$a[5];
	    next if $score <0 || $conf < 0;
	    unless (exists( $totals{$term})){
		$totals{$term}=0;
	    }
	    unless (exists( $totals{"all"})){
		$totals{"all"}=0;
	    }
	    unless ($scores{$term}[$score][$conf]){
		unless ($scores{'all'}[$score][$conf]){
		    $scores{'all'}[$score][$conf]=0;
		    $true{'all'}[$score][$conf]=0;
		}
		$scores{$term}[$score][$conf]=0;
		$true{$term}[$score][$conf]=0;
	    }
	    $scores{'all'}[$score][$conf]++;
	    $scores{$term}[$score][$conf]++;
	    $totals{'all'}++;
	    $totals{$term}++;
	    if ($a[6] eq "T") {
		$true{$term}[$score][$conf]++;
		$true{'all'}[$score][$conf]++;
	    }
	}
   }
}
close GOSCORE;
my $currentpos=0;
my %offsets=();
my %ontol=(C=>1,P=>2,F=>3);
my $table="";
#my $conn=Pg::connectdb("host=localhost dbname=godb user=$ENV{'USER'}");
#if ($conn->status==PGRES_CONNECTION_BAD) {
#    die "no database connection available. Exiting\n";
#}

print STDERR "writing datafile for all scores\n";

foreach my $r (sort keys %scores){
    print STDERR "writing data for $r\n";
    if ($currentpos) {
	$offsets{$r}=sysseek(GODFH,$currentpos,0);
    }else {
	$offsets{$r}=0;
    }
    print STDERR "OFFSET: $r ".$offsets{$r}."\n";
    $currentpos += syswrite(GODFH, "GO: ".(uc $r)."\n"); 
    $currentpos += syswrite(GODFH, "ET: $totals{$r}\n");
    my $maxconf=0;
    for (my $i=0;$i<scalar @{$scores{$r}};$i++){
	if (defined $scores{$r}[$i] && scalar @{$scores{$r}[$i]}>$maxconf){
	    $maxconf=@{$scores{$r}[$i]};
	}
    }
    print STDERR "Max conf determined for $r\n";
    my @ancs=();
    unless ($r eq'all' || $r eq '1'){
	my $goterm=$godb->findgoterm($r);
	print STDERR "GO term $r found - getting ancestors\n";
	@ancs=$goterm->get_ancestorlist();
	print STDERR "found ".(scalar @ancs)." ancestors\n";
    	$ancount{$r}=scalar @ancs;
        $table=$onts{$r}."_".$ancount{$r};
    }
    print STDERR "writing score header for $r\n";
    $currentpos += syswrite(GODFH, "SH: score\tconf\tfreq\ttrue\n");
    print STDERR "writing table of ".(scalar @{$scores{$r}})." rows and ".(int($maxconf))." columns\n";
    for (my $i=0;$i<scalar @{$scores{$r}};$i++){
       
	for (my $j=0;$j<$maxconf;$j++){
	    unless ($scores{$r}[$i][$j]){ $scores{$r}[$i][$j]=0;}
	    unless ($true{$r}[$i][$j]){ $true{$r}[$i][$j]=0;}
	    if ($ancount{$r}){
		unless ($tabletrue{$table}[$i][$j]){ $tabletrue{$table}[$i][$j]=0;}
		unless ($tables{$table}[$i][$j]){ $tables{$table}[$i][$j]=0;}
		unless ($totals{$table}){ $totals{$table}=0;}
		$tables{$table}[$i][$j] += $scores{$r}[$i][$j];
		$tabletrue{$table}[$i][$j] += $true{$r}[$i][$j];
		$totals{$table}+=$scores{$r}[$i][$j];
	    }
	    $currentpos += syswrite(GODFH,"$i\t$j\t$scores{$r}[$i][$j]\t$true{$r}[$i][$j]\n");
	}
    }
    $currentpos += syswrite(GODFH,"//\n");    
}

%scores=();
%true=();

print STDERR "reading NOIE scores\n";
open GOSCORE, $goscoresfilenoiea or die "cannot open NOIEA data file: $!\n";
while (<GOSCORE>){
    chomp;
    next if /^!/;
    unless (/^opening/) {

	chomp;
	my @a=split /\t/,$_;
	unless ($a[7] eq 'N'){
	  my $score=int($a[2]*10);
	  my $conf=int($a[3]);
	  my $term=$a[1];
	  $term=~s/GO://;
	  next unless $score >0 && $conf >0;
	  $onts{$term}=$a[5];
	  unless (exists($totals{'all_NOIEA'})){
	    $totals{"all_NOIEA"}=0;
	  }
	  unless (exists($totals{$term."_NOIEA"})){
	    $totals{$term."_NOIEA"}=0;
	  }
	  unless ($scores{$term}[$score][$conf]){
	    unless ($scores{'all'}[$score][$conf]){
		$scores{'all'}[$score][$conf]=0;
		$true{'all'}[$score][$conf]=0;
	    }
	    $scores{$term}[$score][$conf]=0;
	    $true{$term}[$score][$conf]=0;
	  }
	  $scores{'all'}[$score][$conf]++;
	  $scores{$term}[$score][$conf]++;
	  $totals{'all_NOIEA'}++;
	  $totals{$term."_NOIEA"}++;
	  if ($a[6] eq "T") {
	    $true{$term}[$score][$conf]++;
	    $true{'all_NOIEA'}[$score][$conf]++;
	  }
	}
   }
}
close GOSCORE;

print STDERR "writing NOIEA data\n";
foreach my $r (sort keys %scores){
    $offsets{$r."_NOIEA"}=sysseek(GODFH,$currentpos,0);
    print STDERR "OFFSET: $r"."_NOIEA ".$offsets{$r."_NOIEA"}."\n";
    $currentpos += syswrite(GODFH, "GO: ".(uc $r)."_NOIEA\n"); 
    $currentpos += syswrite(GODFH, "ET: ".$totals{$r."_NOIEA"}."\n");
    my $maxconf=0;
    
    for (my $i=0;$i<scalar @{$scores{$r}};$i++){
	if (defined @{$scores{$r}[$i]} && scalar @{$scores{$r}[$i]}>$maxconf){
	    $maxconf=@{$scores{$r}[$i]};
	}
    }
    unless ($r eq "all" || $r eq "1"){
	my @ancs=();
    	unless (exists($ancount{$r})){
        	my $goterm=$godb->findgoterm($r);
        	print STDERR "GO term $r found - getting ancestors\n";
        	@ancs=$goterm->get_ancestorlist();
        	print STDERR "found ".(scalar @ancs)." ancestors\n";
        	$ancount{$r}=scalar @ancs;
	}
	$table=$onts{$r}."_".$ancount{$r}."_NOIEA";
    }
    $currentpos += syswrite(GODFH, "SH: score\tconf\tfreq\ttrue\n");
    for (my $i=0;$i<scalar @{$scores{$r}};$i++){
	for (my $j=0;$j<$maxconf;$j++){
	    unless ($scores{$r}[$i][$j]){ $scores{$r}[$i][$j]=0;}
	    unless ($true{$r}[$i][$j]){ $true{$r}[$i][$j]=0;}
	    if ($ancount{$r}){	
		unless ($tabletrue{$table}[$i][$j]){ $tabletrue{$table}[$i][$j]=0;}
		unless ($tables{$table}[$i][$j]){ $tables{$table}[$i][$j]=0;}
		unless ($totals{$table}){ $totals{$table}=0;}
		$tables{$table}[$i][$j] += $scores{$r}[$i][$j];
		$tabletrue{$table}[$i][$j] += $true{$r}[$i][$j];
		$totals{$table}+=$scores{$r}[$i][$j];
	    }
	    $currentpos += syswrite(GODFH,"$i\t$j\t".$scores{$r}[$i][$j]."\t".$true{$r}[$i][$j]."\n");
	}
    }
    $currentpos += syswrite(GODFH,"//\n");    
}

print STDERR "Writing aggregate tables\n";

foreach my $r (sort keys %tables){
    $offsets{$r}=sysseek(GODFH,$currentpos,0);
    print "OFFSET:$r $offsets{$r}\n";
    $currentpos += syswrite(GODFH, "GO: ".(uc $r)."\n"); 
    $currentpos += syswrite(GODFH, "ET: $totals{$r}\n");
    my $maxconf=0;
    for (my $i=0;$i<scalar @{$tables{$r}};$i++){
	if (scalar @{$tables{$r}[$i]}>$maxconf){
	    $maxconf=@{$tables{$r}[$i]};
	}
    }
    $currentpos += syswrite(GODFH, "SH: score\tconf\tfreq\ttrue\n");
    for (my $i=0;$i<scalar @{$tables{$r}};$i++){
	for (my $j=0;$j<$maxconf;$j++){
	    unless ($tabletrue{$r}[$i][$j]){ $tabletrue{$r}[$i][$j]=0;}
	    unless ($tables{$r}[$i][$j]){ $tables{$r}[$i][$j]=0;}
	    $currentpos += syswrite(GODFH,"$i\t$j\t$tables{$r}[$i][$j]\t$tabletrue{$r}[$i][$j]\n");
	}
    }
    $currentpos += syswrite(GODFH,"//\n");    
}

print STDERR "writing indices\n";
my $gocount=scalar keys %totals;
my @t=localtime(time);
my $scoredbfile=$scoredb;
$scoredbfile=~s!.*/!!;
my $head=pack "LSSSA30", $gocount,$t[3],$t[4],$t[5],$scoredbfile;
print "$gocount,$t[3],$t[4],$t[5],$scoredbfile\n";
my ($mc,$t3,$t4,$t5,$sc)= unpack "LSSSA30", $head;
if ($mc==$gocount &&
    $t3==$t[3] &&
    $t4 == $t[4] &&
    $t5 == $t[5] &&
    $scoredbfile eq $sc) {
    print "Header packed OK\n";
}else {
    print "Header failed to pack. gocount $gocount $mc: $t[3] - $t3 : $t[4] - $t4 : $t[5] - $t5 : $scoredbfile $sc\n";
    die "error packing head\n";
}
my $bytes=syswrite(GOIFH,$head);

print "HEAD $bytes bytes: $head\n";
my $wpos=0;
foreach my $go (sort {$a cmp $b} keys %totals) {
    $wpos++;
    print "Packing $wpos: $go, $offsets{$go},0\n";
    my $entry=pack "A32LL",$go,$offsets{$go},0;
    my ($g,$o,$n)= unpack "A32LL", $entry;
    if ($g eq $go &&
	$o == $offsets{$go} &&
	$n == 0 ){
	print "entry packed OK\n";
	my @bytes=unpack "C28", $entry;
	print join (":", @bytes)."\n";
    }else {
	print "error packing entry: $g - $go : $o - $offsets{$go} : $n - 0\n";
	die "Error packing entry\n";
    }
    sysseek(GOIFH,$wpos * 40,0);
    $bytes=syswrite(GOIFH,$entry);
    print "ENTRY $bytes bytes:$entry\n"; 

}
close GOIFH;

#######################################################

