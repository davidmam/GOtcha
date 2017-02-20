use lib "/opt/bioperl-1.4/";
use BlastHit;
use Bio::Tools::BPlite;
sub parseblast {
    my @hitlist=();
    my $seqfile=shift;
    open (BLASTFIX, ">$seqfile.good");
    open (BLASTBAD, "$seqfile");
    while (my $line=<BLASTBAD>){
	$line=~s/([0-9]),/$1 ,/;
	print BLASTFIX $line;
    }
    close BLASTBAD;
    close BLASTFIX;
    #print STDERR "parsing $seqfile\n";
    my $blastrun=Bio::Tools::BPlite->new(-file=>"$seqfile.good");
    #print STDERR $blastrun,"\n";
    $hitquery=$blastrun->query();

    $hitquery =~ s/^(\w+) .*$/$1/;
    while(my $sbjct=$blastrun->nextSbjct()){
	#print STDERR "next subject\n";
	my $hitsubjectdesc=$sbjct->name();
	$hitsubjectdesc=~m/^(\w+)\W.*$/;
	$hitsubjectid=$1;
	while (my $hit=$sbjct->nextHSP()){
	    #print STDERR "next hit\n";
	    my $hitquerystart=$hit->query->start;
	    my $hitqueryend=$hit->query->end;
	    my $hitsubjectstart=$hit->subject->start;
	    my $hitsubjectend=$hit->subject->end;
	    my $hitbitscore=$hit->bits();
	    my $hitexpect=$hit->P();
	    my $hitlength=$hit->length();
	    push @hitlist,new BlastHit($hitquery,$hitbitscore,$hitexpect,$hitquerystart,$hitqueryend,$hitsubjectid,$hitsubjectstart,$hitsubjectend,$hitsubjectdesc) ;
	    #print STDERR "adding hit ", scalar @hitlist,"\n";
	} 
    }
return @hitlist;

}

return 1;
