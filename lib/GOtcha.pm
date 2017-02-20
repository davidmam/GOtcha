package GOtcha;

use GOresult;
use GOdb;
#need to create a GOdb on creation so need to have DB info passed

sub new {
#call as GOtcha->new($godb); 
    $class=shift;
    $this={};
    $this->{'godb'}=shift;
    $this->{"noiea"}=shift;
    %{$this->{'goresults'}}=();
    $this->{'debug'}=0; # change to 0 for no debugging info
    %{$this->{'gotermscore'}}=();
    %{$this->{'gotermprobscore'}}=();
    %{$this->{'gotermavg'}}=();
    %{$this->{'gotermvar'}}=();
    $this->{'mindp'}=40;
    @{$this->{'C'}}=();
    @{$this->{'F'}}=();
    @{$this->{'P'}}=();
    $this->{'dotfontpath'}="/usr/share/fonts/truetype";
    $this->{'dotfontname'}="Arial";
    bless $this,$class;
    return $this;
}

sub _debug {
	my $this=shift;
	my $msg=shift;
	if ($this->{'debug'}) {
		print STDERR "GOTCHA.pm: $msg\n";
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

sub mindatapoints {
    my $this=shift;
    my $mindp=shift;
   
    if ($mindp && $mindp>0) {
    	$this->{'mindp'}=$mindp;
        $this->_debug("setting mindp to $mindp");
    }
    return $mindp;
}

sub getgoresult {

#access a specific result set.
    my $this=shift;
    my $dbname=shift;
$this->_debug("looking for goresult for $dbname");
    if (exists(${$this->{'goresults'}}{$dbname})) {
	$this->_debug("result found!");
	return ${$this->{'goresults'}}{$dbname};
    }
}

sub tophits {
    my $this=shift;
    my %th;
    foreach my $d (keys %{$this->{'goresults'}}){
	unless (${$this->{'goresults'}}{$d}->tophit() eq ""){
	    $th->{${$this->{'goresults'}}{$d}->tophit()}=${$this->{'goresults'}}{$d}->hitscore(${$this->{'goresults'}}{$d}->tophit());
	}
    }
    return %th;
}

sub dotfontpath {
    my $this=shift;
    my $fp=shift;
    if (-e $fp && -d $fp){
	$this->{'dotfontpath'}=$fp;
    } else { 
	print STDERR "Cannot find DOTFONTPATH $fp\n";
    }
    return $this->{'dotfontpath'};
}

sub dotfontname {
    my $this=shift;
    my $fn=shift;
    if (-e $this->{'dotfontpath'}."/$fn.ttf"){
	$this->{'dotfontname'}=$fn;
    } else { 
	print STDERR "Cannot find font $fn in ".$this->{'dotfontpath'}."\n";
    }
    return $this->{'dotfontname'};
}

sub writexref {
    my $this=shift;
    my $db=shift;
    my %ontologies =(
		     C=>"Cellular compartment",
		     F=>"Molecular function",
		     P=>"biological process"
		     );
	$this->_debug("writing XREF");
    $this->_buildgolist();
	$this->_debug("go list built");
    my $out="## GOtcha database links ##\n";
    foreach my $o (qw/C F P/){
	if (scalar @{$this->{$o}} >0) {
	    $out .= "# Results for Ontology $ontologies{$o}\n";
	    $out .= "# Database links for the following GO terms were observed:\n";
	    
	    foreach my $g (sort { my $s=(${$this->{'gotermprobscore'}}{$b}<=>${$this->{'gotermprobscore'}}{$a}); return $s==0?(${$this->{'gotermavg'}}{$b}<=>${$this->{'gotermavg'}}{$a}):$s; } @{$this->{$o}}) {
		$this->_debug("writing xref for $g");
		my $gt="GO:0000000";#pattern for GO term text 
		    substr($gt,0-length("".$g),length("".$g),"".$g); #text string for go term
		my $goterm=$this->{"godb"}->findgoterm($g);
		my $probscore=-1;
		$probscore=${$this->{'gotermprobscore'}}{$g};
		my @links=$goterm->dbrefs($db);
		if (scalar @links) {
		    foreach my $l (@links) {
			if ($l) {
				$out .= "$gt\t$probscore\t$l\n";
			}
		    }
		} 
	    }
	} else {
	    $out .= "\n# No matches observed to $ontologies{$o}\n\n";
	}
    }
    return $out;
}
sub countdb {
    my $this=shift;
	$this->_debug("counting databases as ".(scalar keys %{$this->{'goresults'}}));
    return scalar keys %{$this->{'goresults'}};
}

sub addgoresult {
    my $this=shift;
    my $dbname=shift;
    my $gores=shift;
    if ($dbname && $gores && ref($gores) eq 'GOresult') {
	$this->_debug("adding GO result $dbname $gores");
	if (exists (${$this->{'goresults'}}{$dbname})) {
	    print STDERR "results for database $dbname already exist\n";
	    $this->_debug( "results for database $dbname already exist");
	    return;
	}else{
	    ${$this->{'goresults'}}{$dbname}=$gores;
	    $this->{"update"}=0;
		$this->_debug("results added");
	}
    } else {
	$this->_debug( "GOTCHA: bad result type",2);
    }
}

sub listdatabases {
    my $this=shift;
    @dbnames=keys %{$this->{'goresults'}};
    return @dbnames;
}
sub count {
    my $this=shift;
    my $ont = shift;
    $this->_buildgolist();
    $this->_debug( "Counting entries in $ont");
    if ($ont) {
	return scalar @{$this->{$ont}};
    } 
    return scalar keys %{$this->{'gotermscore'}};
}

sub _buildgolist {
    my $this=shift;
	$this->_debug("rebuilding GO list");
    unless ($this->{"update"}){
	$this->_debug("update not set - recalculating");	
	my %rescount=(F=>0,C=>0,P=>0);
	foreach my $o (qw/F C P/){
		$this->_debug("building GO list for $o");
	    my %termlist=();

		
	    foreach my $d (values %{$this->{'goresults'}}){
		if (scalar $d->goterms($o)){
		    $rescount{$o}++;
		}
		foreach my $g ($d->goterms($o)){
		    $termlist{$g}=1;
		    ${$this->{'gotermscore'}}{$g}=0;
		    ${$this->{'gotermvar'}}{$g}=0;
		    ${$this->{'gotermprobscore'}}{$g}=0;
		}
	    }
	    @{$this->{$o}}=keys %termlist;
	}
	$this->_debug("Establishing averages");	
	foreach my $g (sort {${$this->{'gotermscore'}}{$b} <=>${$this->{'gotermscore'}}{$a}} keys %{$this->{'gotermscore'}}){
	    foreach my $d (values %{$this->{'goresults'}}){
		${$this->{'gotermscore'}}{$g}+=$d->goscore($g);
	    }
		$this->_debug("gotermscore for $g is ".${$this->{'gotermscore'}}{$g});
#	    ${$this->{'gotermavg'}}{$g}=${$this->{'gotermscore'}}{$g}/(scalar keys %{$this->{'goresults'}});
	    ${$this->{'gotermavg'}}{$g}=${$this->{'gotermscore'}}{$g}/($rescount{$this->{'godb'}->findgoterm($g)->ontology()});
		$this->_debug("gotermavg for $g is ".${$this->{'gotermscore'}}{$g});
		    
	    foreach my $d (values %{$this->{'goresults'}}){
		${$this->{'gotermvar'}}{$g} += ((${$this->{'gotermavg'}}{$g}-$d->goscore($g))*(${$this->{'gotermavg'}}{$g}-$d->goscore($g)));
	    }
#	$this->_debug("sum of squares for $g is ". ${$this->{'gotermvar'}}{$g}. " from ".(scalar keys %{$this->{'goresults'}})." results");	
	$this->_debug("sum of squares for $g is ". ${$this->{'gotermvar'}}{$g}. " from ".$rescount{$this->{'godb'}->findgoterm($g)->ontology()}." results");	
	
#	    ${$this->{'gotermvar'}}{$g}/=(scalar keys %{$this->{'goresults'}});
	    ${$this->{'gotermvar'}}{$g}/=($rescount{$this->{'godb'}->findgoterm($g)->ontology()});
	    ${$this->{'gotermvar'}}{$g}=sqrt(${$this->{'gotermvar'}}{$g});
	$this->_debug("variance for $g is ".${$this->{'gotermvar'}}{$g});	
	    $gt=$this->{"godb"}->findgoterm($g);
	if ($this->{'debug'}){
		$gt->debug_on();
	}else{
		$gt->debug_off();
	}
	    $ps=int(100*$gt->probscore(${$this->{'gotermavg'}}{$g}, $this->confidence($gt->ontology()),$this->{"noiea"},$this->{"mindp"}));
	$this->_debug("retrieving P-score for $g as $ps");	
	    if ((!exists(${$this->{'gotermprobscore'}}{$g}))|| 
		$ps > ${$this->{'gotermprobscore'}}{$g}){
#		$this->_debug("G: setting $g (".${$this->{'gotermprobscore'}}{$g}.")to $ps");
		${$this->{'gotermprobscore'}}{$g} = $ps;
	    }
	$this->_debug("Propagating probscore for $g");	
	    $this->_setparentprob($gt,$ps);

	}
	$this->_debug("setting update");	
	$this->{"update"}=1;
    }
}

sub _setparentprob {
    my $this=shift;
    my $gt=shift;
    my $ps=shift;
    unless ($gt){
	$this->_debug( "no go term defined",1);
	return;
    }
	$this->_debug("Updating parents of ".$gt->id);	
    foreach my $p ($gt->part_parents()){
	if ((!exists(${$this->{'gotermprobscore'}}{$p})) ||
	    ${$this->{'gotermprobscore'}}{$p} < $ps){
	    if (!exists(${$this->{'gotermprobscore'}}{$p})) {
		$this->_debug("P: No score set for $p - setting to $ps",3);
	    }else{
		$this->_debug("P: setting $p (".${$this->{'gotermprobscore'}}{$p}.")to $ps");
	    }
	    ${$this->{'gotermprobscore'}}{$p} = $ps;
	    my $pgt=$this->{"godb"}->findgoterm($p);
	    $this->_setparentprob($pgt,$ps);
	}
    }
    foreach my $p ($gt->type_parents()){
	if ((!exists(${$this->{'gotermprobscore'}}{$p})) ||
	    ${$this->{'gotermprobscore'}}{$p} < $ps ){
	    $this->_debug("T: setting $p (".${$this->{'gotermprobscore'}}{$p}.")to $ps");
	    ${$this->{'gotermprobscore'}}{$p} = $ps;
	    my $pgt=$this->{"godb"}->findgoterm($p);
	    $this->_setparentprob($pgt,$ps);	    
	}
    }
}

sub confidence {
    my $this=shift;
    my $ont=shift;
    $this->_debug("setting conf for $ont");
    my $conf=0;
    my $hits=0;
    if (scalar keys %{$this->{'goresults'}} >0) {
	foreach my $d (values %{$this->{'goresults'}}) {
	    if ($d->maxscore($ont)>0){
		$hits++;
		$conf += log ($d->maxscore($ont));
	    }
	}
	$conf /= $hits;
	$this->_debug("conf calculated as average of $hits hits");
    } 
    return $conf;
}

sub goscore {
    my $this=shift;
    my $goid=shift;
	$this->_debug("setting score for $goid");
    my @scores=();
    my $stderror=0;
    my @res=();
    unless ($goid){
	$this->_debug("goid not set");
	return;
    }
    my $score=0;
    foreach my $b (values %{$this->{'goresults'}}){
	$score += $b->goscore($goid);
	push @scores, $b->goscore($goid);
    }
	$this->_debug("calculating score for $goid as $score divided by ".(scalar keys %{$this->{'goresults'}}));
    $score /=(scalar keys %{$this->{'goresults'}});
    foreach my $s (@scores){
	$stderror+= ($s-$score)*($s-$score);
    }
    $stderror/=(scalar @scores);
    push @res, $score, $stderror;
	$this->_debug("score for $goid is $score with SE $stderror");
    return @res;
}

sub probscore {
    my $this=shift;
    my $goid=shift;
    my $scores;
    return unless $goid;
	$this->_debug("getting probscore for $goid");
    unless (exists(${$this->{'gotermprobscore'}}{$goid})){
	$this->_debug("probscore not calculated: building GO list");
	$this->_buildgolist();
    }
    if (exists(${$this->{'gotermprobscore'}}{$goid})){
	$this->_debug("probscore found for $goid");
	return ${$this->{'gotermprobscore'}}{$goid};
    }else{ 
	$this->_debug("probscore NOT found for $goid");
	return 0;
    }
}


sub write {
    my $this=shift;
    my %ontologies =(
		     C=>"Cellular compartment",
		     F=>"Molecular function",
		     P=>"biological process"
		     );
    $this->_debug("preparing to write output");
    $this->_buildgolist();
    $this->_debug("GO list prepared");
    my $out="## GOHST result ##\n";
    if (exists $this->{'db'}) {
	$out .= "# Databases containing hits: ".(join ",",$this->listdatabases())."\n";
    }

    foreach my $o (qw/C F P/){
	if (scalar @{$this->{$o}} >0) {
	    $out .= "# Results for Ontology $ontologies{$o}\n";
	    $out .= "# Matches to the following GO terms were observed:\n";
	    $cscore=$this->confidence($o);
	    $out .= "Mean Confidence: $cscore\n";
	    $this->_debug("writing GOterms for ontology $o");
	    foreach my $g (sort { my $s=(${$this->{'gotermprobscore'}}{$b}<=>${$this->{'gotermprobscore'}}{$a}); return $s==0?(${$this->{'gotermavg'}}{$b}<=>${$this->{'gotermavg'}}{$a}):$s; } @{$this->{$o}}) {
		my $gt="GO:0000000";#pattern for GO term text 
		    substr($gt,0-length("".$g),length("".$g),"".$g); #text string for go term
		my $score = ${$this->{'gotermavg'}}{$g};
		my $goterm=$this->{"godb"}->findgoterm($g);
		my $probscore=-1;
		my $description="";
		if (ref($goterm)eq "GOterm") {
		    $description=$goterm->description();
		}
		$probscore=${$this->{'gotermprobscore'}}{$g};
		my $scoretext=substr ($score,0,6);
		if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
		}
		my $var= ${$this->{'gotermvar'}}{$g};           
		my $vartext=substr ($var,0,6);
		if (index ($var,"e-") >0){
		    $vartext=substr($var,0,1).substr($var,index ($var,"e-"));
		}
		$out .= "$gt\t$scoretext\t$vartext\t$probscore\t$o\t$description\n";
	    } 
	} else {
	    $out .= "\n# No matches observed to $ontologies{$o}\n\n";
	}
    }
    return $out;
}
sub htmlhead {
    my $this=shift;
    my $out="<div style=\"text-align: left\"><h1>GOtcha results</h1>\n";
    $out .= "Databases containing hits: <ul>\n<li>".(join "</li>\n<li>",keys %{$this->{'goresults'}})."</li>\n</ul><p>\n";
    return $out;
}
sub writehtml {
    my $this=shift;
    my $ont=shift;
    my $linkstart=shift;
    my $linkend=shift;
    my $cutoff=shift;
    $cutoff=0 unless $cutoff && $cutoff >0 && $cutoff <=100;
    my %ontologies =(
		     C=>"Cellular compartment",
		     F=>"Molecular function",
		     P=>"biological process"
		     );
    $this->_buildgolist();
    @confdesc=("very poor", "poor", "low", "fair", "fairly good", "good", "high", "very high", "excellent");
    @bgcolor=qw/d3d3d3 add8e6 87cefa 00bfff 6495ed 4169e1 0000cd 4b0082 9400d3 800080 c71585  ff00ff ff1493 dc143c ff0000/;

    $cscore=$this->confidence($ont);
    $conftext=substr(" ".$cscore,1,3);
    if ($conftext>9) {
	$conftext .=" ($confdesc[9])";
    }else{
	$conftext .=" (".$confdesc[int($cscore)].")";
    }
    $out = "<p><b>Overall Confidence: $conftext</b><p>\n";
    $cotext="";
    if ($cutoff){
	$cotext="with a probability of greater than $cutoff\%";
    }
    if (scalar @{$this->{$ont}} >0) {
	$out .= " Matches to the following GO terms $cotext were observed:<p>\n<table border=1 cellpadding=4>\n<thead><th>&nbsp;</th><th>GO id</th><th>Score</th><th>SD</th><th>Est. likelyhood \%</th><th>Description</th></thead>\n";
	foreach my $g (sort { my $s=(${$this->{'gotermprobscore'}}{$b}<=>${$this->{'gotermprobscore'}}{$a}); return $s==0?(${$this->{'gotermavg'}}{$b}<=>${$this->{'gotermavg'}}{$a}):$s; } @{$this->{$ont}}) {
	    
	    my $gt="GO:0000000";#pattern for GO term text 
		substr($gt,0-length("".$g),length("".$g),"".$g); #text string for go term
	    my $score = ${$this->{'gotermavg'}}{$g};           
	    my $probscore=${$this->{'gotermprobscore'}}{$g};
	    my $goterm=$this->{"godb"}->findgoterm($g);
	    my $description="";
	    if (ref($goterm) eq "GOterm"){
		$description=$goterm->description();
		    }
	    my $colorval=0;
	    $colorval=int($probscore *14/100);
	    my $scoretext=substr ($score,0,6);
	    if (index ($score,"e-") >0){
		$scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
	    }
	    my $var= ${$this->{'gotermvar'}}{$g};           
	    my $vartext=substr ($var,0,6);
	    if (index ($var,"e-") >0){
		$vartext=substr($var,0,1).substr($var,index ($var,"e-"));
	    }
	    $linktext=$gt;
	    if ($linkstart || $linkend) {
		$linktext="<a href=$linkstart".$g."$linkend target=GODB>$gt</a>";
	    }
#	    print STDERR "GOTCHA: ".${$this->{'gotermprobscore'}}{$g}." $probscore : $cutoff\n";
	    if ($probscore >= $cutoff || !$cutoff){
		$out .= "<tr><td bgcolor=#$bgcolor[$colorval]><a name=\"$gt\">&nbsp;</a></td><td>$linktext</td><td>$scoretext</td><td>$vartext</td><td>$probscore</td><td>$description</td></tr>\n";
	    } 
	}
	$out.="</table>\n";
    }else {
	$out .="No matches to GO terms were identified in <i>$ontologies{$ont}</i>.<p>\n";
    }
    return $out;
}
sub writedot {
# generate an input file for DOT that can draw the graph.
    my $this=shift;
    my $ont=shift;
    my $cutoff=shift;
    $cutoff=0 unless $cutoff && $cutoff <=100 && $cutoff >0;
	$this->_debug("writing Dot file for ontology $ont with cutoff $cutoff");
    $this->_buildgolist();
$this->_debug("GO list built - writing dot file");
    my $out="#GOHST result dot input file\n";
    my %shapes=(
		C=>"ellipse",
		F=>"diamond",
		P=>"box"
		);
    my @gotermlist=();
    if ($ont eq 'C' || $ont eq 'F' || $ont eq 'P') {
	push @gotermlist, @{$this->{$ont}};
	$this->_debug("goterm list contains ".(scalar @gotermlist)." terms");
    }else {
	return "# No such ontology\n";
	$this->_debug("abort writing dot file - bad ontology");
    }
    if (scalar @gotermlist >0) {
	$out .= "digraph GO {\n";
	my $cscore=$this->confidence($ont);
	foreach my $g (@gotermlist) {
	$this->_debug("generating dot output for term $g");
	    my $gt="GO:0000000";#pattern for GO term text 
		substr($gt,0-length("".$g),length("".$g),"".$g); #text string for go term
	    my $score = ${$this->{'gotermavg'}}{$g};
	    my $goterm=$this->{"godb"}->findgoterm($g);
		$this->_debug("got goterm object $goterm");
	    my $probscore=${$this->{'gotermprobscore'}}{$g};
	    if ($probscore >= $cutoff || !$cutoff){
		$this->_debug("term has score $probscore");
		if ($probscore <0) {
		    $probscore = "-";
		}
		my $scoretext=substr ($score,0,6);
		if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
		}
		my $var= ${$this->{'gotermvar'}}{$g};           
		my $vartext=substr ($var,0,6);
		if (index ($var,"e-") >0){
		    $vartext=substr($var,0,1).substr($var,index ($var,"e-"));
		}
		$out .= "GO$g [shape=$shapes{$ont},fontname=".$this->{'dotfontname'}.",fontpath=\"".$this->{'dotfontpath'}."\",label=\"$gt\\n$probscore \%\",style=filled,fillcolor=".$this->_scoretocolour($probscore/100).",URL=\"javascript:getinfoforgo($g)\"]\n";
		$out .= "edge [style=solid]\n";
		foreach my $p ($goterm->type_parents()){
		$this->_debug("Adding type parent $p to $g");
		    $out .= "GO$p -> GO$g\n"; 
		}
		$out .= "edge [style=dashed]\n";
		foreach my $p ($goterm->part_parents()){
			$this->_debug("adding part parent $p to $g");
		    $out .= "GO$p -> GO$g\n"; 
		}
	    }
	}
	$out .= "}\n";
    }
	$this->_debug("Dot done");
    return $out;
}

sub writesql {
    my $this=shift;
    my ($id,$seqdb,$reprocess)=@_;
    my %ontologies =(
		     C=>"Cellular compartment",
		     F=>"Molecular function",
		     P=>"biological process"
		     );
    $this->_buildgolist();
    my $out="-- ## GOtcha result ##\n";
    if (exists $this->{'db'}) {
	$out .= "-- # Databases containing hits: ".(join ",",$this->listdatabases())."\n";
    }

    foreach my $o (qw/C F P/){
	if (scalar @{$this->{$o}} >0) {
	    $out .= "-- # Results for Ontology $ontologies{$o}\n";
	    $out .= "-- # Matches to the following GO terms were observed:\n";
	    $cscore=$this->confidence($o);
	    $out .= "-- Mean Confidence: $cscore\n";
	    
	    foreach my $g (sort { my $s=(${$this->{'gotermprobscore'}}{$b}<=>${$this->{'gotermprobscore'}}{$a}); return $s==0?(${$this->{'gotermavg'}}{$b}<=>${$this->{'gotermavg'}}{$a}):$s; } @{$this->{$o}}) {
		my $gt="GO:0000000";#pattern for GO term text 
		    substr($gt,0-length("".$g),length("".$g),"".$g); #text string for go term
		my $score = ${$this->{'gotermavg'}}{$g};
		my $goterm=$this->{"godb"}->findgoterm($g);
		my $probscore=-1;
		my $description="";
		if (ref($goterm)eq "GOterm") {
		    $description=$goterm->description();
		}
		$probscore=${$this->{'gotermprobscore'}}{$g};
		my $scoretext=substr ($score,0,6);
		if (index ($score,"e-") >0){
		    $scoretext=substr($score,0,1).substr($score,index ($score,"e-"));
		}
		my $var= ${$this->{'gotermvar'}}{$g};           
		my $vartext=substr ($var,0,6);
		if (index ($var,"e-") >0){
		    $vartext=substr($var,0,1).substr($var,index ($var,"e-"));
		}
		$out .= "INSERT into gotcharesult (contigid, seqdb, reprocess, goterm, iscore, var,cscore, pscore, ontology) values ( $id, \'$seqdb\', \'$reprocess\',  $g,$scoretext, $vartext, $cscore,  $probscore,\'$o\');\n";
	    } 
	} else {
	    $out .= "\n-- # No matches observed to $ontologies{$o}\n\n";
	}
    }
    return $out;
}

sub writesqldb {
    my $this=shift @_;
    my ($id,$seqdb,$reprocess)=@_;
    unless ($id){
	$id=0;
    }
    my $out="-- GOHST results from multiple databases \n";
    foreach my $d (values %{$this->{'goresults'}}) {
	$out .= $d->writesql($id, $seqdb, $reprocess);
    }
    return $out;
}

sub _scoretocolour {
    my $this=shift;
    my $score=shift;
    if ($score eq "-") {
	return "palegoldenrod";
    }else{
	$score= int($score*14);
	@colorlist=qw/lightgray lightblue lightskyblue deepskyblue cornflowerblue royalblue mediumblue indigo darkviolet purple mediumvioletred  magenta deeppink crimson red/;
	return $colorlist[$score];
    }
}

1;
