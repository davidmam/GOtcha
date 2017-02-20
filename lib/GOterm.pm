package GOterm;

#this package acts as a wrapper for a GO term, 
#its description, synonyms and database cross references.
#
#It does not include inheritance details.

sub new {

    my $class=shift;
    my $this={debug=>1};
    bless $this,$class;
    my $id=shift;
    if ($id){
	$this->{'id'}=$id;
    }
    %{$this->{'synonyms'}}=();
    %{$this->{'parents'}}=();
    %{$this->{'crossrefs'}}=();
    %{$this->{'children'}}=();
    %{$this->{'ancestors'}}=();
    %{$this->{'defrefs'}}=();
    $this->{'description'}="No description available";
    $this->{'definition'}="No definition available";
    return $this;
}

sub _debug {
	my $this=shift;
	my $msg=shift;
	my $level=shift;
	if ($this->{'debug'} >=$level) {
		print STDERR "GOterm.pm: $msg\n";
	}
}

sub debug_on {
    my $this=shift;
    my $level=shift;
    $this->{'debug'}=$level;
}

sub debug_off {
    my $this=shift;
    $this->{'debug'}=0;
}

sub addtermtable {
    my $this=shift;
    my $table=shift;
    my $noiea=shift;
    if (ref($table) eq "GOscore") {
	if (defined $noiea && $noiea ){
	    $this->{"termscorenoiea"}=$table;
	}else{
	    $this->{"termscore"}=$table;
	}
    }
}

sub addtypetable {
    my $this=shift;
    my $table=shift;
    my $noiea=shift;
    if (ref($table) eq "GOscore") {
	if (defined $noiea && $noiea ){
	    $this->{"typescorenoiea"}=$table;
	}else{
	    $this->{"typescore"}=$table;
	}
    }
}

sub probscore {
# $goterm->probscore(iscore,cscore,noiea,mindatapoints)
    my $this=shift;
    my $iscore=shift;
    my $cscore=shift;
    my $noiea=shift;
    my $min=shift;
    my $mdp=0;
    my $suffix="noiea";
    my $score=-1;
$this->_debug("GOTERM: getting probability score for $iscore $cscore ",3);
    $suffix="" unless $noiea;
    if (exists($this->{"termscore".$suffix}) && ref($this->{"termscore".$suffix}) eq "GOscore") {
	$this->_debug("GOTERM: getting score from termscore$suffix",2);
	if ($min && $min >0) {	
	    $mdp=$min;
	}else{
	    $mdp= $this->{"termscore".$suffix}->mindatapoints();
	}
	$this->_debug("Min data points is $mdp",2);
	if ($this->{"termscore".$suffix}->total()>$mdp){
		$this->_debug("reading score",2);
	    $this->{"termscore".$suffix}->mindatapoints($mdp);
	    $score=$this->{"termscore".$suffix}->simplescore($iscore,$cscore);
		$this->_debug("score read as $score",2);
	}
    }
    if ($score <0){
	$this->_debug("GOTERM: noscore from termscore$suffix",2);
	if (exists($this->{"typescore".$suffix}) && ref($this->{"typescore".$suffix}) eq "GOscore") {
	$this->_debug("GOTERM: getting score from typescore$suffix",2);
	    if ($min && $min >0) {
		$mdp=$min;
	    }else{
		$mdp= $this->{"typescore".$suffix}->mindatapoints();
	    }
	    if ($this->{"typescore".$suffix}->total()>$mdp){
		$this->_debug("GOTERM: getting score from typescore..",2);
		$this->{"typescore".$suffix}->mindatapoints($mdp);
		$score=$this->{"typescore".$suffix}->simplescore($iscore,$cscore);
	    }
	}
    }
	$this->_debug("GOTERM: score is $score",2);
    return $score;

}

sub add_ancestorlist {
    my $this=shift;
    my $list=shift;
    @temlist=split",",$list;
    foreach $t (@temlist) {
	${$this->{'ancestors'}}{$t}=1;
    }
}

sub add_children {
        my $this=shift;
    my $list=shift;
    @temlist=split",",$list;
    foreach $t (@temlist) {
	${$this->{'children'}}{$t}=1;
    }
}

sub get_childlist {
    my $this=shift;
    @al=keys %{$this->{'children'}};
    return @al;
}

sub get_ancestorlist {
    my $this=shift;
    @al=keys %{$this->{'ancestors'}};
    return @al;
}

sub id {
    my $this=shift;
    my $id=shift;    
    $this->{'synonyms'}=();

    unless (exists $this->{'id'} && $this->{'id'} ) {
	$this->{'id'}=$id;
    }
    return $this->{'id'};
}

sub ontology {
    my $this=shift;
    my $ont=shift;
    unless (exists $this->{'ontology'} && $this->{'ontology'}) {
	$this->{'ontology'}=$ont;
    }
    return $this->{'ontology'};
}

sub add_synonym {
    my $this=shift;
    my $syn=shift;
    if ($syn){
	${$this->{'synonyms'}}{$syn}=1;
    }
}

sub delete_synonym {
    my $this=shift;
    my $syn=shift;
    if ($syn && exists ${$this->{'synonyms'}}{$syn} ){
	delete ${$this->{'synonyms'}}{$syn};
    }
}

sub add_dbxref {
    my $this=shift;
    my $xref=shift;
    if ($xref){
	${$this->{'crossrefs'}}{$xref}=1;
    }
}

sub delete_dbxref  {
    my $this=shift;
    my $xref=shift;
    if ($xref&& exists ${$this->{'crossrefs'}}{$xref} ){
	delete ${$this->{'crossrefs'}}{$xref};
    }

}

sub add_defref {
    my $this=shift;
    my $dref=shift;
    if ($dref){
	${$this->{'defrefs'}}{$dref}=1;
    }
}

sub delete_defref  {
    my $this=shift;
    my $dref=shift;
    if ($dref&& exists ${$this->{'defrefs'}}{$dref} ){
	delete ${$this->{'defrefs'}}{$dref};
    }

}

sub description {
    my $this=shift;
    my $desc = shift;
    if ($desc) {
	$this->{'description'} =$desc;
    }
    return $this->{'description'};
}

sub definition {
    my $this=shift;
    my $def=shift;
    if ($def){
	$this->{'definition'}=$def;
    }
    return $this->{'definition'};
}


sub synonyms {
    my $this=shift;
    my @syn=keys %{$this->{'synonyms'}};
    return @syn;
}

sub dbrefs {
    my $this=shift;
    my $db=shift;
    my @syn=keys %{$this->{'crossrefs'}};
    if ($db) {
	my @sdb=map { m/^$db:/?$_:""; } @syn;
	return @sdb;
    }
    return @syn;

}

sub defrefs {
    my $this=shift;
    my @syn=keys %{$this->{'defrefs'}};
    return @syn;
}

sub add_secondary {
    my $this=shift;
    @secondaries=shift;
    foreach $s (@scondaries) {
	${$this->{'secondary'}}{$s}=1;
    }
}

sub delete_secondary {
    my $this=shift;
    my $sec=shift;
    if ($sec && exists ${$this->{'secondary'}}{$sec}) {
	delete ${$this->{'secondary'}}{$sec};
    }
}

sub secondaries {
    my $this=shift;
    @sec = keys %{$this->{'secondary'}};
    return @sec;
}

sub add_parent {
    my $this=shift;
    my $par=shift;
    my $type=shift;
	$this->_debug("adding parent $par of type $type to ".$this->id,3);
    if ($par) {
	${$this->{'parents'}}{$par}= $type?'part':'type';
    }
}

sub type_parents {
    my $this=shift;
    my @par=();
    foreach $parent (keys %{$this->{'parents'}}) {
	if (${$this->{'parents'}}{$parent} eq 'type'){
	    push @par,$parent;
	}
    }
    return @par;
}

sub part_parents {
    my $this=shift;
    my @par=();
	$this->_debug("getting part parents",2);
	$this->_debug((scalar keys %{$this->{'parents'}})." parents for term ".$this->id,3 );
    foreach $parent (keys %{$this->{'parents'}}) {
	if (${$this->{'parents'}}{$parent} eq 'part'){
	    push @par,$parent;
	}
    }
	$this->_debug((scalar @par)." part parents found",3);
    return @par;
}

sub countparents {
    my $this=shift;
    return scalar keys %{$this->{'parents'}};
}

sub delete_parent {
    my $this=shift;
}

sub output {
    my $this=shift;

#default output is in database form.
#other options are HTML, plain

    $output="ID: $this->{'id'}\n";
    foreach $sec (keys %{$this->{'secondary'}}) {
	$output .= "SI: $sec\n";
    }
    $output.= "ON: ".$this->{'ontology'}."\n";
    $output.="DE: ".$this->{'description'}."\n";
    $output .="DF: ".$this->{'definition'}."\n";
    foreach my $dr (keys %{$this->{'defrefs'}}){ 
	$output .= "DR: $dr\n";
    }
    foreach my $syn (keys %{$this->{'synonyms'}}){ 
	$output .= "SY: $syn\n";
    }
    foreach my $xref ( keys %{$this->{'crossrefs'}}){
	$output .="XR: $xref\n";
    }
    foreach $par (keys %{$this->{'parents'}}){
	if (${$this->{'parents'}}{$par} eq 'type' ){
	    $output .= "PT: $par\n";
	}else{
	    $output.="PP: $par\n";
	}
    }

    $al = join "," , keys %{$this->{'ancestors'}};
    $output .="AN: $al\n";
    $cl = join ",", keys %{$this->{'children'}};
    $output .= "CH: $cl\n";
    $output .="//\n";
    return $output;
}

1;
