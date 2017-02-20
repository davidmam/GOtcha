package GOresultHSW;

#this package encapsulates a result obtained by gohst.

sub new {
    my $class=shift;
    $this={};
    %{$this->{'goterms'}}=();
    $this->{'maxscore'}=0;
    $this->{'bighit'}=0;
    %{$this->{'dbhits'}}=();
    bless $this,$class;
    return $this;
}

sub db {
    my $this=shift;
    my $db=shift;
    if ($db && ! exists $this->{'db'}) {
	$this->{'db'}=$db;
    } elsif (exists $this->{'db'}) {
	return $this->{'db'};
    }
    return; 
}

sub add_hit {
    my $this=shift;
    my $hitname=shift;
    my $hitscore=shift;
    if($hitscore && $hitname && !exists ${$this->{'dbhits'}}{$hitname}) {
	${$this->{'dbhits'}}{$hitname}=$hitscore;
    }
    return;
}
sub hitscore {
    my $this=shift;
    my $hitname=shift;
    if ($hitname && exists ${$this->{'dbhits'}}{$hitname}) {
        return ${$this->{'dbhits'}}{$hitname};
    }
    return;
}

sub godesc {
	my $this=shift;
	my $goterm=shift;
	my $godesc=shift;
	if ($godesc && $goterm) {
		${$this->{'godesc'}}{$goterm}=$godesc;
	}
	if ($goterm && exists(${$this->{'godesc'}}{$goterm})) {
		return ${$this->{'godesc'}}{$goterm};
	}

}

sub goscore {
    my $this=shift;
    my $goterm=shift;
    my $goscore=shift;
    if ($goterm && $goscore) {
	# add score to running total
	if (exists ${$this->{'goterms'}}{$goterm} ){
	    ${$this->{'goterms'}}{$goterm} += $goscore;
        }else {
	    ${$this->{'goterms'}}{$goterm}=$goscore;
        }
        if (${$this->{'goterms'}}{$goterm} >$this->{'maxscore'}) {
            $this->{'maxscore'}= ${$this->{'goterms'}}{$goterm};
        }
        if ($goscore > $this->{'bighit'}) {
            $this->{'bighit'}=$goscore;
        }
    }elsif ($goterm && exists ${$this->{'goterms'}}{$goterm}){
        return ${$this->{'goterms'}}{$goterm}/$this->{'maxscore'};
    }else {
        return 0;
    }
}

sub maxscore {
    my $this=shift;
    return $this->{'maxscore'};
}

sub goterms {
    my $this=shift;
    return keys %{$this->{'goterms'}};
}

sub hits {
    my $this=shift;
    return keys %{$this->{'dbhits'}};
}

sub write {
    my $this=shift;
    my $out="## GOHST result ##\n";
    if (exists $this->{'db'}) {
	$out .= "# Database searched: ".$this->{'db'}."\n";
    }
    if (scalar keys %{$this->{'dbhits'}} >0) {
	$out .="# Matches to the following sequences were recorded:\n";
	foreach $h (sort {${$this->{'dbhits'}}{$b} <=> ${$this->{'dbhits'}}{$a}} keys %{$this->{'dbhits'}}) {
	    $out .="# $h\t".${$this->{'dbhits'}}{$h}."\n";
        }
    }
    if (scalar keys %{$this->{'goterms'}} >0) {
        $out .= "# Matches to the following GO terms were observed:\n";
        foreach $g (sort { ${$this->{'goterms'}}{$b}<=>${$this->{'goterms'}}{$a} } keys %{$this->{'goterms'}}) {
            $score = $this->{'bighit'} * ${$this->{'goterms'}}{$g}/$this->{'maxscore'};           
            $scoretext=substr ($score,0,6);
            if (index ($score,"e-") >0){
		$scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
            }
	    $description="";
	    if (exists(${$this->{'godesc'}}{$g})){
	    	$description=${$this->{'godesc'}}{$g};
	    }
            $out .= "GO:$g\t$scoretext\t$description\n";
        } 
    }
    return $out;
}
sub writesql {
    my $this=shift;
    my $id=shift;
    unless ($id){
	$id=0;
    }
    my $out="-- GOHST result \n";
    my $dbname="unrecorded";
    if (exists $this->{'db'}) {
	$dbname=$this->{'db'};
	$out .= "-- Database searched: $dbname\n";
    }
    if (scalar keys %{$this->{'dbhits'}} >0) {
	$out .="-- Matches to the following sequences were recorded:\n";
	foreach $h (sort {${$this->{'dbhits'}}{$b} <=> ${$this->{'dbhits'}}{$a}} keys %{$this->{'dbhits'}}) {
	    $out .="-- $h\t".${$this->{'dbhits'}}{$h}."\n";
        }
    }
    if (scalar keys %{$this->{'goterms'}} >0) {
        $out .= "--Matches to the following GO terms were observed:\n";
        foreach $g (sort { ${$this->{'goterms'}}{$b}<=>${$this->{'goterms'}}{$a} } keys %{$this->{'goterms'}}) {
            $score = $this->{'bighit'} * ${$this->{'goterms'}}{$g}/$this->{'maxscore'};           
            $scoretext=substr ($score,0,6);
            if (index ($score,"e-") >0){
		$scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
            }
            $out .= "INSERT into gohits (seqid, dbname, goid, score ) values ( $id, \'$dbname\',$g, $scoretext);\n";
        } 
    }
    return $out;
}
1;





