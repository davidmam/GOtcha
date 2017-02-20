package BlastHit;

sub new {
    my $class=shift;
    my $this={};
$this->{'hitquery'}=shift;
$this->{'hitbitscore'}=shift;
$this->{'hitexpect'}=shift;
$this->{'hitquerystart'}=shift;
$this->{'hitqueryend'}=shift;
$this->{'hitsubjectid'}=shift;
$this->{'hitsubjectstart'}=shift;
$this->{'hitsubjectend'}=shift;
$this->{'hitsubjectdesc'}=shift;
$this->{'hitlength'}=shift;
$this->{'hitp'}=shift;

    #print STDERR $this->{'hitsubjectid'},"\n";
bless $this,$class;
return $this;
}

sub writesql {
    my $this=shift;
    my $id=shift;
    unless ($id) {
	$id=$this->{'hitquery'};
    }
    my $sql="INSERT into hits (blastdb,hitquery,hitbitscore,hitexpect,hitquerystart,hitqueryend,hitsubjectid,hitsubjectstart,hitsubjectend,hitsubjectdesc,hitlength,hitp) VALUES (BLASTDB,";
    $sql .=join ",",$id,$this->{'hitbitscore'},$this->{'hitexpect'},$this->{'hitquerystart'},$this->{'hitqueryend'};
    $sql .=",\'".$this->{'hitsubjectid'}."\',".$this->{'hitsubjectstart'}.",".$this->{'hitsubjectend'}.",\'";
    my $desc=uc $this->{'hitsubjectdesc'};
    $desc=~s/'/\\'/g;
    $sql .="$desc\',".$this->{'hitlength'}.",".$this->{'hitp'}.");\n";
    return $sql;
}

sub gethitname {
    my $this=shift;
    return $this->{'hitsubjectid'};
}

sub getRscore {
    my $this=shift;
    if ($this->{'hitexpect'} >1) {
	return 0;
    }
    if ($this->{'hitexpect'} >0 ){
	return -2.303*log($this->{'hitexpect'});
    }else {
	return 200;
    }
}
sub getgolist {
    my $this=shift;
    @golist=();
    open (ID,"getid.pl $this->{'hitsubjectid'} |" ) or return @golist;
    while (<ID>) {
	chomp;
	push @golist,$_;
    }
    return @golist;
}
sub tabstring {
    my $this=shift;

return $this->{'hitquery'}." ". 
$this->{'hitsubjectid'}." ".
$this->{'hitexpect'}." ".
$this->{'hitbitscore'}." ".
$this->{'hitquerystart'}." ".
$this->{'hitqueryend'}." ".
$this->{'hitsubjectstart'}." ".
$this->{'hitsubjectend'}." ".
$this->{'hitsubjectdesc'}." ".
$this->{'hitlength'}." ".
$this->{'hitp'}. "\n";
return $string;

}
sub gettaxon {
    my $this=shift;
    $taxon="0000";
    open (ID,"gettaxon.pl $this->{'hitsubjectid'} |" ) or return $taxon;
    $taxon=<ID>;
    close ID;
    chomp $taxon;
    return $taxon;
}






return 1;



