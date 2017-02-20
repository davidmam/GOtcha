package GOdb;

#this encapsulates reading GO terms from a flat file database.
use FileHandle;
use GOterm;
use GOscore;
use GOseq;

use constant ROWSIZE => 40;

sub debug {
    my $text=shift;
	print STDERR "DEBUG/GOdb: $text\n";
}

    

sub new {
    my $class=shift;
    my $this={debug=>1,termcache=>{}};
    bless $this,$class;
    my $filename="";
    my $goindex=shift;
    my $seqindex=shift;
    my $scoreindex=shift;
    unless ($seqindex && $goindex && -e $seqindex && -e $goindex) {
	warn "No index files specified or index files do not exist\n";
	return;
    } 

#attempt to open GO database
    $this->{"goindex"} = FileHandle->new($goindex, "r");
    unless ($this->{"goindex"}) {
	warn "GO database index $goindex cannot be opened\n";
       
	return;
    }
    $this->{"goindex"}->sysseek(0,0);
    $this->{"goindex"}->sysread($read,ROWSIZE);
    ($this->{"GOrecords"},$this->{"indexyear"},$this->{"indexmonth"},$this->{"indexday"},$filename) =unpack "LSSSA30", $read;
    $this->_debug("GO filename: $filename",2);
    $this->_debug("GO index: $goindex",2);
    $this->{"gofile"}=$filename;
    if (rindex($goindex,'/') >0){
	substr($goindex,rindex($goindex,'/')+1)=rindex($filename,"/")>0?substr($filename,rindex($filename,"/")+1):$filename;
	$this->{"gofile"}=$goindex;
    #}else{
	#$this->{"gofile"}=$filename;
    }
	$this->_debug("GO index: $goindex",2);

	$this->_debug("GO database file ".$this->{"gofile"},2);


    unless (($this->{"gofile"} =~ m!^/!) || ! exists($ENV{GOTCHA_LIB})){
	$this->{"gofile"} = $ENV{GOTCHA_LIB}."/".$this->{"gofile"};
    }
    unless ($this->{"gofile"} && -e $this->{"gofile"}) {
	warn "Cannot find a GO database file $filename.".$this->{"gofile"}.":$!\n";
	return;
    }
    $this->{"gofh"}=FileHandle->new($this->{"gofile"},"r");
    unless (defined $this->{"gofh"}) {
	warn "GO database file could not be opened\n";
    }
# attempt to open sequence index
    $this->{"seqindex"}=FileHandle->new($seqindex,"r");
    unless (defined $this->{"seqindex"}) {
	warn "Sequence link index could not be opened\n";
	return;
    }
    $this->{"seqindex"}->sysseek(0,0);
    $this->{"seqindex"}->sysread($read,ROWSIZE);
    ($this->{"seqrecords"},$this->{"seqindexyear"},$this->{"seqindexmonth"},$this->{"seqindexday"},$filename) =unpack "LSSSA30", $read;
    $this->{"seqfile"}=$filename;
    if (rindex($seqindex,'/') >0){
	substr($seqindex,rindex($seqindex,'/')+1)=rindex($filename,"/") >0?substr($filename, rindex($filename,"/")+1):$filename;
	$this->{"seqfile"}=$seqindex;
        }

    unless ($this->{"seqfile"} =~ m!^/! || ! exists($ENV{GOTCHA_LIB})){
	$this->{"seqfile"} = $ENV{GOTCHA_LIB}."/".$this->{"seqfile"};
    }

    $this->{"seqfh"}= FileHandle->new($this->{"seqfile"},"r");
    unless (defined $this->{"seqfh"}) {
	warn "Could not open Sequence Data File ".$this->{'seqfile'}."\n";
	return;
    }
    $this->_debug("scoreindex is $scoreindex",2);
    if ($scoreindex && -e $scoreindex){
	$this->_debug("GODB: attempting to open scores file",2);
	$this->{"scoreindex"} = FileHandle->new($scoreindex, "r");
	unless ($this->{"scoreindex"}) {
	    warn "GO scores index $scoreindex cannot be opened\n";
	    return;
	}
	$this->{"scoreindex"}->sysseek(0,0);
	$this->{"scoreindex"}->sysread($read,ROWSIZE);
	($this->{"GOscores"},$this->{"scoreindexyear"},$this->{"scoreindexmonth"},$this->{"scoreindexday"},$sfilename) =unpack "LSSSA30", $read;
	$this->_debug("sfilename is $sfilename",3);
	if (index($sfilename,'/')>-1) {
		$sfilename=substr($sfilename,rindex($sfilename,'/')+1);
	}
	if (rindex($scoreindex,'/') >0){
	    substr($scoreindex,rindex($scoreindex,'/')+1)=$sfilename;
	    $this->{"scorefile"}=$scoreindex;
	    $this->_debug("GO scorefile file $scoreindex",3);
	}else{
	    $this->{"scorefile"}=$sfilename;
	    $this->_debug("GO scorefile file is $sfilename",3);
	}
	
	unless ($this->{"scorefile"} && -e $this->{"scorefile"}) {
	    warn "Cannot find a GO scores file $sfilename.\n";
	    return;
	}
	$this->_debug("GODB: attempting to open ".$this->{"scorefile"},3);
	$this->{"scorefh"}=FileHandle->new($this->{"scorefile"},"r");
	unless (defined $this->{"scorefh"}) {
	    warn "GO scores file could not be opened\n";
	}
    }
    return $this;
}

sub findgoterm {
    my $this=shift;
#method to retrieve a go term from the database.
    my $goid=shift;

    unless ( $goid ne "all" && $goid ) {
	$this->_debug("no valid GO id specified",1);
	return;
    }
$this->_debug("finding go term $goid",2);
    if (exists($this->{"termcache"}->{$goid}) ){
$this->_debug(" go term $goid found",2);
	return $this->{"termcache"}->{$goid};
    }
    my $max=$this->{"GOrecords"};
    my $min=1;
    my $name=0;
    my $pos=0;
    my $ont=0;
    my $curr=0;
    if (  $goid ==0) {
	warn "bad goid: $goid\n";
    }
    if ($goid=~m/^[^0a]/){
	$goid=substr("0000000".$goid,-7);
    }
    while ( $name != $goid && $max > $min+1 ) {
	$curr=$min+int (($max-$min)/2);
	$this->{"goindex"}->sysseek($curr * ROWSIZE,0);
	$this->{"goindex"}->sysread($read, ROWSIZE);
	($name,$pos,$ont)=unpack "A32LL",$read;
        $this->_debug("found GO term  $name looking for $goid",3);
	if ($name < $goid) { 
	    $min=$curr;
	}else{
	    $max=$curr;
	}
	
    }
    if ($name != $goid){

	$this->{"goindex"}->sysseek($max * ROWSIZE,0);
	$this->{"goindex"}->sysread($read, ROWSIZE);
	($name,$pos,$ont)=unpack "A32LL",$read;
	$this->_debug("found last GO term  $name looking for $goid",3);

    }
    if ($name==$goid) {
	$this->_debug("found this GO term  $name looking for $goid in ".$this->{"gofh"},3);
       	$this->{"gofh"}->sysseek($pos,0);
	$termdata="";
	    $this->{"gofh"}->sysread($tmp,512);
	    $termdata.=$tmp;
	$this->_debug("termdata= $termdata",4);
	$termend=index( $termdata,"\n//");
	$iter=0;
	while ($termend==-1){
	    $iter++;
	    $this->_debug("End of record not found in string of length ".length($termdata)." from ". $this->{"gofh"},4);
	    $this->_debug($termdata,5);
	    $this->{"gofh"}->sysread($tmp,512);
	    $termdata.=$tmp;
	    $termend=index( $termdata,"\n//");
	    die if $iter >8;
	}
	$this->_debug("read $termdata",4);
	    $termdata=substr($termdata,0,$termend);
	$this->_debug("trimmed $termdata",5);
	$goterm=$this->stringtogo($termdata);
	$this->addempscore($goterm);
	$this->{"termcache"}->{$goid}=$goterm;
	return $goterm;
    }
    warn "GO term $goid not found.\n";
}

sub addempscore {
#add the empirical score tables for a go term.
    my $this=shift;
    my $goterm=shift;
    $this->_debug("GODB: Adding scoring tables to go term",2);
    unless (ref($goterm) eq 'GOterm') {
	return;
    }
    my $go=$goterm->id();
    my $ancount=scalar $goterm->get_ancestorlist();
    my $table=$goterm->ontology()."_$ancount";
	$this->_debug("looking for score table $go",2);
    my $st=$this->findscoretable($go);
    if (ref($st) eq 'GOscore'){
	$this->_debug("score table $go found",3);
	$goterm->addtermtable($st,0);
    }
    $this->_debug("looking for score table $go"."_NOIEA",3);
    $st=$this->findscoretable($go."_NOIEA");
    if (ref($st) eq 'GOscore'){
	$this->_debug("NOIEA score table found",3);
	$goterm->addtermtable($st,1);
    }
	$this->_debug("looking for type table $table",3);
    $st=$this->findscoretable($table);
    if (ref($st) eq 'GOscore'){
	$this->_debug("type table $table found",3);
	$goterm->addtypetable($st,0);
    }
	$this->_debug("Looking for NOIEA type table $table",3);
    $st=$this->findscoretable($table."_NOIEA");
    if (ref($st) eq 'GOscore'){
	$this->_debug("NOIEA type table found",3);
	$goterm->addtypetable($st,1);
    }
    return;
}

sub _debug {
	my $this=shift;
	my $msg=shift;
	my $level=shift;
	if ($this->{'debug'} >=$level) {
		print STDERR "DEBUG/GOdb: $msg\n";
	}
}

sub debug_on {
    my $this=shift;
    $this->{'debug'}=shift;
}

sub debug_off {
    my $this=shift;
    $this->{'debug'}=0;
}

sub findscoretable {
    my $this=shift;
    return unless $this->{"scoreindex"};
    my $tableid=shift;
    $this->_debug("Looking for table id $tableid",2);
    my $max=$this->{"GOscores"};
    my $min=1;
    my $name="";
    my $pos=0;
    my $ont=0;
    my $curr=0;
    while ( uc $name ne uc $tableid && $max > $min+1 ) {
	$curr=$min+int (($max-$min)/2);
	$this->{"scoreindex"}->sysseek($curr * ROWSIZE,0);
	$this->{"scoreindex"}->sysread($read, ROWSIZE);
	$this->_debug("read ".(length $read)." bytes at ".($curr * ROWSIZE),4);
	($name,$pos,$ont)=unpack "A32LL",$read;
	@bytes=unpack "C".ROWSIZE, $read;
	$str="";
	foreach $b (@bytes){
		if ($b<32) {
			$str .=".$b ";
		}else{
			$str .=chr($b)." ";
		}
	}
	$this->_debug("read string is $str",4);
	$this->_debug("found GO term table $name at pos $pos with ont $ont looking for $tableid",4);
	$name=~s/GO://;
	$this->_debug("found GO term table $name at pos $pos with ont $ont looking for $tableid",4);
	$this->_debug("GODB: min $min max $max curr $curr",3);
	if ((uc "GO".$name )lt (uc "GO".$tableid)) { 
	    $this->_debug("$name gt $tableid :".((uc "GO".$name )gt (uc "GO".$tableid)),3);
	    $min=$curr;
	}else{
	    $this->_debug("$name lt $tableid :".((uc "GO".$name )gt (uc "GO".$tableid)),3);
	    $max=$curr;
	}
	
    }
    if (uc $name ne uc $tableid){

	$this->{"scoreindex"}->sysseek($max * ROWSIZE,0);
	$this->{"scoreindex"}->sysread($read, ROWSIZE);
	($name,$pos,$ont)=unpack "A32LL",$read;
	$this->_debug("found last GO term  $name",2);
	$this->_debug(" looking for table $tableid",2);

    }
    if ($name eq $tableid) {
	$tmp="";
	$this->_debug("found this GO term  $name looking for table $tableid",2);
       	$this->{"scorefh"}->sysseek($pos,0);
	$scoredata="";
	$this->{"scorefh"}->sysread($tmp,512);
	$this->_debug("GODB: scorefilepos: $pos : read : $tmp",4);
	$scoredata.=$tmp;
	$tableend=index( $scoredata,"//");
	while ($tableend==-1){
	    $this->{"scorefh"}->sysread($tmp,512);
	    $scoredata.=$tmp;
	    $tableend=index( $scoredata,"//");
	    $this->_debug( "GODB: reading score data\n$scoredata",5);
	}
	$this->_debug("read $scoredata",4);
	$scoredata=substr($scoredata,0,$tableend);
	return $this->stringtoscore($scoredata);
        $this->_debug("GODB: score data read \n$scoredata",5);
    }
    return;
    
}

sub stringtoscore {
    my $this=shift;
    #parse a string containing a scoring table entry and create a GOscore object. 
    my $ss=shift;
    $this->_debug("GODB: parsing score table",2);
    return unless $ss;
    $this->_debug("GODB: string received",3);
    my @l = split /\n/,$ss;
    my $id=shift @l; #first line should contain the GO: <entryid>
    return unless $id =~ m/^GO:/;
    $id =~ s/^GO:\s*(\w*)\s*$/$1/;
    my $st=GOscore->new($id);
    $st->debug_on($this->{debug});
    $this->_debug("GODB: score table id is $id",3);
    my $total=shift @l;
    return unless $total =~ m/^ET:/;
    $this->_debug("GODB: Score table: $total",3);
    $total=~s/^ET:\s*(\d+)\s*$/$1/;
    $st->total($total);
    $this->_debug("GODB: score table total is $total",3);
    my $sh=shift @l;
    while (! $sh =~m/^SH:/ && scalar @l){
	$sh=shift @l;
    }
    return unless $sh =~m/^SH:/;
    foreach my $s (@l){
	my ($sb,$cb,$fr,$true)=split /\t/,$s;
	$st->addbin($sb,$cb,$fr,$true);
    }
    $this->_debug("GODB:score table created",2);
    return $st;
}

sub stringtogo {
    my $this=shift;
#parse a string containing a database entry into a go term.
    my $gostring=shift;
    unless ($gostring){return;}
    $gostring =~ s/[\r]/\n/g;
    $gostring =~ s/\n+/\n/g;
    @lines = split "\n",$gostring;
    $elem=shift @lines;
    my $goterm;
   $this->_debug("first line $elem",3);
    if ($elem=~/^ID:/) {
	($tmp,$term)=split ": ",$elem;
	$goterm=GOterm->new($term);
	$goterm->debug_on($this->{debug});
    }else{
	return;
    }
    while (scalar @lines){
	$elem=shift @lines;
	($type,$term)=split ": ", $elem, 2;
	$this->_debug("updating term with $type",3);
	if ($type eq 'ON') {
	    $goterm->ontology($term);
	}elsif($type eq 'DE') {
	    $goterm->description($term);
	}elsif($type eq 'DF') {
	    $goterm->definition($term);
	}elsif($type eq 'SI') {
	    $goterm->add_secondary($term);
	}elsif($type eq 'SY') {
	    $goterm->add_synonym($term);
	}elsif($type eq 'XR') {
	    $goterm->add_dbxref($term);
	}elsif($type eq 'PT') {
	    $goterm->add_parent($term,1);
	}elsif($type eq 'PP') {
	    $goterm->add_parent($term,0);
	}elsif($type eq 'AN') {
	    $goterm->add_ancestorlist($term);
	}elsif($type eq 'CH') {
	    $goterm->add_children($term);
	}
    }
    return $goterm;
}
sub findseqref {
    my $this=shift;
#method to retrieve a go term from the database.
    my $seqid=shift;

    unless ($seqid) {
	warn "no sequence id specified\n";
	return;
    }
    $this->_debug( "searching for $seqid",2);
    my $max=$this->{"seqrecords"};
    my $min=1;
    my $name="XXX";
    my $pos=0;
    my $ont=0;
    my $curr=0;
    while ( lc $name ne lc $seqid && $max > $min+1 ) {
	$curr=$min+int (($max-$min)/2);
	$this->{"seqindex"}->sysseek($curr * ROWSIZE,0);
	$this->{"seqindex"}->sysread($read, ROWSIZE);
	($name,$pos,$ont)=unpack "A32LL",$read;
	$this->_debug("found $name  at pos $curr..",3);
	if (lc $name lt lc $seqid) { 
	    $min=$curr;
	}else{
	    $max=$curr;
	}
	
    }
    if (lc $name ne lc $seqid){
	$this->{"seqindex"}->sysseek($max * ROWSIZE,0);
	$this->{"seqindex"}->sysread($read, ROWSIZE);
	($name,$pos,$ont)=unpack "A32LL",$read;
	$this->_debug("last entry $name at $curr",3);
    }
    if (lc $name eq lc $seqid) {
	$this->_debug("found match to $name at pos $pos",3);
       	$this->{"seqfh"}->sysseek($pos,0);
	$termdata="";
	$this->_debug("reading entry",3);
	    $this->{"seqfh"}->sysread($tmp,512);
	    $termdata.=$tmp;
	$termend=index($termdata,"//");
	while ($termend==-1) {
	    $this->{"seqfh"}->sysread($tmp,512);
	    $this->_debug("reading entry",3);
	    $termdata.=$tmp;
	$termend=index($termdata,"//");
	}
$this->_debug("read string $termdata",4);
	$termdata=substr($termdata,0,$termend);
$this->_debug("entry string $termdata",4);
	
	return $this->stringtoseq($termdata);
    }
    warn "No associations found for sequence  $seqid.\n";
    return;
}

sub stringtoseq {
    my $this=shift;
    my $seqstring=shift;
#    #print STDERR 
    $this->_debug("processing $seqstring",3);
    $seqstring =~ tr/\r/\n/;
    $seqstring=~s/\n+/\n/g;
    @lines=split "\n",$seqstring;
#    #print STDERR 
    $this->_debug("string has ".( scalar @lines). " lines",3);
    $elem=shift @lines;
#    #print STDERR 
    $this->_debug("line 1 $elem",3);
    my $seq;
    ($type,$term)=split ": ",$elem;
#    #print STDERR 
    $this->_debug(" $type type and $term value",3);
    if ($type eq "ID"){
	$seq=GOseq->new($term);
    }else { 
	warn "No sequence ID\n";
	return;
    }
    $elem=shift @lines;
    ($type,$term)=split ": ",$elem;
    if ($type eq "TX"){
	$seq->taxonomy($term);
    }elsif ($type eq "GO") {
	$seq->add_go($term);
    }
    while (scalar @lines) {
	$elem=shift @lines;
	if ($elem=~/\/\//) {
	    @lines=();
	}
	($type,$term)=split ": ",$elem;
	if ($type eq "GO") {
	    $seq->add_go($term);
	}
    }
    return $seq;

}

sub getgoforid {
# return all ancestral go terms for a sequence id.
# getgoforid($id,[bool,[@codelist]])
# id is sequence identifier
# bool is exclude(false) or include(true) from list of evidence codes
#codelist is an array of evidence codes.
    my $this=shift;
    my $seqid=shift;
    my $includeonly=shift;
    my @codes=shift;
    my @anclist=();
    my %ancs=();
    $this->_debug("finding go terms for $seqid",2);
    my $seq=$this->findseqref($seqid);

    unless ($seq) {
	$this->_debug("Could not find sequence $seqid",2);
	return @anclist;
    }
#    my $seq=$this->stringtoseq($seqstring);
    if (!defined $seq) {
	$this->_debug("No sequence reference",2);
	return;
    }
    if ($includeonly &&  scalar @codes==0) {
	$this->_debug("No taxons included",2);
	return @anclist;
    }
    my @golist=$seq->gobycode($includeonly,@codes);
    
    push @anclist,@golist;
    foreach $g (@golist) {
	$this->_debug("looking for go term $g for seqid $seqid",3); 
	my $gt=$this->findgoterm($g);
	$this->_debug("processing goterm $gt",3);
	if ( ref($gt)eq "GOterm" ) {
		@gancs=$gt->get_ancestorlist();
	$this->_debug("found $gt,".(scalar @gancs)." ancestors",3);
	    push @anclist,@gancs;
	} 
    }
    
    foreach $a (@anclist) {
	$ancs{$a}=1;
    }
    my @gl=keys %ancs;
	$this->_debug("found total of ".(scalar @gl)." terms for $seqid",2);
    return @gl;
}
    


sub getseq {
    my $this=shift;
    my $seqid=shift;
    return $this->getseqref($seqid);
}

1;
