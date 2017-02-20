
package GOresult;

#this package encapsulates a result obtained by gohst.

sub new {
    #call as 'GOresult->new($godb);' to get all the dot stuff to work.
    my $class=shift;
    $this={debug=>0};
    $this->{'godb'}=shift;
    %{$this->{'goterms'}}=();
    $this->{'maxscore'}=0;
    @{$this->{'C'}}=();
    $this->{'maxC'}=0;
    $this->{'maxP'}=0;
    $this->{'maxF'}=0;
    %{$this->{'termtypes'}}=();
    @{$this->{'P'}}=();
    @{$this->{'F'}}=();
    $this->{'tophit'}="";
    %{$this->{'dbhits'}}=();
    $this->{'dotfontpath'}="/usr/share/fonts/truetype";
    $this->{'dotfontname'}="Arial";
    bless $this,$class;
    return $this;
}

sub _debug {
	my $this=shift;
	my $msg=shift;
	if ($this->{'debug'}) {
		print STDERR "GOresult.pm: $msg\n";
	}
}

sub debug_on {
    my $this=shift;
    $this->{'debug'}=1;
}

sub debug_off {
    my $this=shift;
    $this->{'debug'}=0;
}

sub dotfontpath {
    my $this=shift;
    my $fp=shift;
    if (-e $fp && -d $fp){
	$this->{'dotfontpath'}=$fp;
    } else { 
	$this->_debug("Cannot find DOTFONTPATH $fp");
    }
    return $this->{'dotfontpath'};
}

sub dotfontname {
    my $this=shift;
    my $fn=shift;
    if (-e $this->{'dotfontpath'}."/$fn.ttf"){
	$this->{'dotfontname'}=$fn;
    } else { 
	$this->_debug("Cannot find font $fn in ".$this->{'dotfontpath'});
    }
    return $this->{'dotfontname'};
}

sub db {
    my $this=shift;
    my $db=shift;
    if ($db && ! exists $this->{'db'}) {
	$this->{'db'}=$db;
	$this->_debug("setting db to $db");
    } elsif (exists $this->{'db'}) {
	$this->_debug("db already set to $db");
	return $this->{'db'};
    }
    return; 
}

sub add_hit {
    my $this=shift;
    my $hitname=shift;
    my $hitscore=shift;
    if($hitscore && $hitname && !exists ${$this->{'dbhits'}}{$hitname}) {
	$this->_debug("Adding hit $hitname with score $hitscore");
	${$this->{'dbhits'}}{$hitname}=$hitscore;
	unless (exists (${$this->{'dbits'}}{$this->{'tophit'}}) && ${$this->{'dbhits'}}{$this->{'tophit'}} > ${$this->{'dbhits'}}{$hitname}) {
	    $this->{'tophit'}=$hitname;
		$this->_debug("hit is top hit");
	}   
    }
    return;
}

sub tophit {
    my $this=shift;
    return $this->{'tophit'};
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
		$this->_debug("setting goterm $goterm description $godesc");
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
	if ($goscore){
	$this->_debug("setting goscore $goscore for term $goterm");
	}else{	
$this->_debug("getting goscore for term $goterm");
	}
$this->_debug("looking for go term $goterm to add score");
    my $gt=$this->{'godb'}->findgoterm($goterm);
    unless (ref($gt) eq "GOterm"){
	$this->_debug("term $goterm not a go term.");
	return;
    }
    if ($goterm ) {
	$this->_debug("GOterm $goterm found");
	unless (exists(${$this->{'termtypes'}}{$goterm}) ){ 
	    ${$this->{'termtypes'}}{$goterm}=$gt->ontology();
	    push @{$this->{ ${$this->{'termtypes'}}{$goterm}}}, $goterm;
	    $this->_debug("assigning ontology  ${$this->{'termtypes'}}{$goterm} to $goterm");
	}
    }
    if ($goterm && $goscore && ($goscore > 0)) {
	# add score to running total
	unless (${$this->{'termtypes'}}{$goterm} eq "O"){
	    if (exists ${$this->{'goterms'}}{$goterm} ){	
		${$this->{'goterms'}}{$goterm} += $goscore;
	$this->_debug("Goterm $goterm exists and adding $goscore to it gives ". ${$this->{'goterms'}}{$goterm});
	    }else {
		${$this->{'goterms'}}{$goterm}=$goscore;
	$this->_debug("Goterm $goterm does not exist and is initialised to $goscore");
	    }
	    if (${$this->{'goterms'}}{$goterm} >$this->{'max'.${$this->{'termtypes'}}{$goterm}}) {
		$this->{'max'.${$this->{'termtypes'}}{$goterm}}= ${$this->{'goterms'}}{$goterm};
		$this->_debug("goterm $goterm is max in this ontology");
	    }
	    if (${$this->{'goterms'}}{$goterm} >$this->{'maxscore'}){
		$this->{'maxscore'}= ${$this->{'goterms'}}{$goterm};
	    }
	}
    }elsif ($goterm) {
	unless (exists ${$this->{'goterms'}}{$goterm}){
		$goterm=~s/^0*//;
		$this->_debug("trimming leading 0s from goterm");
	}
	if ( exists ${$this->{'goterms'}}{$goterm}){
	$this->_debug("retrieving score for $goterm:". (${$this->{'goterms'}}{$goterm}/$this->{'max'.${$this->{'termtypes'}}{$goterm}}));
        return ${$this->{'goterms'}}{$goterm}/$this->{'max'.${$this->{'termtypes'}}{$goterm}};
	} else {
	$this->_debug("term $goterm not annotated - returning 0");
		return 0;
	}
    }else {
	$this->_debug("term $goterm not annotated - returning 0");
        return 0;
    }
}

sub maxscore {
    my $this=shift;
    my $ont=shift;
    if ($ont && exists($this->{'max'.$ont})){
	return $this->{'max'.$ont};
    }
    return $this->{'maxscore'};
}

sub goterms {
    my $this=shift;
    my $ont=shift;
    $this->_debug("retrieving terms for $ont");
    if ($ont eq 'C' || $ont eq 'P' || $ont eq 'F'){
	$this->_debug((scalar @{$this->{$ont}} )." terms in $ont");
	return @{$this->{$ont}};
    }
    return keys %{$this->{'goterms'}};
}

sub hits {
    my $this=shift;
    return keys %{$this->{'dbhits'}};
}

sub write {
    my $this=shift;
    my $out="## GOHST result ##\n";
    my %ontologies =(
		     C=>"Cellular component",
		     F=>"Molecular function",
		     P=>"Biological process"
		     );
    if (exists $this->{'db'}) {
	$out .= "# Database searched: ".$this->{'db'}."\n";
    }
    if (scalar keys %{$this->{'dbhits'}} >0) {
	$out .="# Matches to the following sequences were recorded:\n";
	foreach $h (sort {${$this->{'dbhits'}}{$b} <=> ${$this->{'dbhits'}}{$a}} keys %{$this->{'dbhits'}}) {
	    $out .="# $h\t".${$this->{'dbhits'}}{$h}."\n";
        }
    }
    foreach my $o (keys %ontologies){
	if (scalar @{$this->{$o}} >0) {
	    $out .= "#\n#  Terms found in $ontologies{$o}\n";
	    $out .= "# Matches to the following GO terms were observed:\n";
	    $out .= "Confidence: ".$this->{'max'.$o}."\n";
	    $cscore=log($this->{'max'.$o});
	    foreach my $g (sort { ${$this->{'goterms'}}{$b}<=>${$this->{'goterms'}}{$a} } @{$this->{$o}}) {
		
		$score = ${$this->{'goterms'}}{$g}/$this->{'max'.$o};           
		$goterm=$this->{"godb"}->findgoterm($g);
		$probscore=-1;
		if (ref($goterm) eq "GOterm"){
		    $probscore=$goterm->probscore($score,$cscore);
	 	    $this->_debug("fetching probscore of $probscore for term $g with score $score and C-score $cscore");
		}
		if ($probscore <0) {
		    $probscore="-";
		}else {
		    $probscore = int( $probscore *100);
		}
		$scoretext=substr ($score,0,6);
		if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
		}
		$this->_debug("probscore set to $scoretext for output");
		$description="";
		if (exists(${$this->{'godesc'}}{$g})){
		    $description=${$this->{'godesc'}}{$g};
		}
		$out .= "GO:$g\t$scoretext\t($probscore)\t$description\n";
	    } 
	}
    }
	return $out;
}
sub writedot {
# generate an input file for DOT that can draw the graph.
    my $this=shift;
    my @ont=shift;
    my $out="#GOHST result dot input file\n";
    my %shapes=(
		C=>"elipse",
		F=>"diamond",
		P=>"box"
		);
    my @gotermlist=();
    if (scalar @ont >0 ){
	foreach my $o (@ont) {
	    if ($o eq 'C' || $o eq 'F' || $o eq 'P') {
		push @gotermlist, @{$this->{$o}};
	    }
	}
    }else {
	push @gotermlist,keys %{$this->{'goterms'}};
    }
    if (scalar @gotermlist >0) {
	$out .= "digraph GO {\n";
	foreach my $g (@gotermlist) {
 	    $goterm=$this->{'godb'}->findgoterm($g);
	    $score = ${$this->{'goterms'}}{$g}/$this->{'max'.$goterm->ontology()};
	    $probscore=$goterm->probscore($score,log($this->{'max'.$goterm->ontology()}));
	    if ($probscore <0) {
		$probscore="-";
	    }else{
		$probscore=int($probscore*100);
	    }
	    $scoretext=substr ($score,0,6);
	    if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
		}
	    
	    $out .= "GO$g [shape=".$shapes{$goterm->ontology()}.",fontname=".$this->{'dotfontname'}.",fontpath=\"".$this->{'dotfontpath'}."\",label=\"GO:$g\\n$probscore\",style=filled,fillcolor=".$this->_scoretocolour($probscore).",URI=\"javascript:getinfoforgo($g)\"]\n";
	    $out .= "edge [style=solid]\n";
	    foreach my $p (@{$goterm->type_parents()}){
		$out .= "GO$p -> GO$g\n"; 
	    }
	    $out .= "edge [style=dashed]\n";
	    foreach my $p (@{$goterm->part_parents()}){
		    $out .= "GO$p -> GO$g\n"; 
		}
	    
	}
	$out .= "}\n";
    }
    return $out;
}

sub writesql {
    my $this=shift;
    my ($id, $seqdb, $reprocess)=@_;
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
            my $gt=$this->{'godb'}->findgoterm($g);
	    if (ref($gt)eq "GOterm"){
		$score =  ${$this->{'goterms'}}{$g}/$this->{'max'.$gt->ontology()};           
		$probscore=$gt->probscore($score,log($this->{'max'.$gt->ontology()}));
		if ($probscore <0) {$probscore="-";}
                $scoretext=substr ($score,0,6);
                if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
                }

                $out .= "INSERT into gohits (seqid, dbname, reprocess, goid, score, maxscore,ontology ) values ( $id, \'$seqdb\',\'$reprocess\',$g, $scoretext,".$this->{'maxscore'}.",'".$gt->ontology()."');\n";
           }
       }
    }
    return $out;
}

sub _scoretocolour {
    my $this=shift;
    my $score=shift;
    if ($score eq "-") {
	return "palegoldenrod";
    }else{
	$score= int($score*10);
	@colorlist=qw/lightgray lightblue cornflowerblue mediumblue blueviolet orchid magenta palevioletred 
	    mediumvioletred deeppink crimson/;
	return $colorlist[$score];
    }
}
1;



