package GOseq;

#this package acts as a wrapper for a sequence linked to GO terms

sub new {

    my $class=shift;
    my $this={};
    bless $this,$class;
    my $id=shift;
    if ($id){
	$this->{'id'}=$id;
    }
    return $this;
}

sub id {
    my $this=shift;
    my $id=shift;
    unless (exists $this->{'id'} && $this->{'id'} ) {
	$this->{'id'}=$id;
    }
    return $this->{'id'};
}

sub taxonomy {
    my $this=shift;
    my $ont=shift;
    unless (exists $this->{'taxon'} && $this->{'taxon'}) {
	$this->{'taxon'}=$ont;
    }
    return $this->{'taxon'};
}

sub source {
    my ($this, $val)=(@_);
    unless (exists $this->{'source'} && $this->{'source'}) {
	$this->{'source'}=$ont;
    }
    return $this->{'source'};
}

sub add_go {
#add a go term association to the sequence
    my $this=shift;
    my $term=shift;
    unless ($term){
	return;
    }
    ($goid,$evidence)=split " ",$term;
    unless ($evidence) { 
	return;
    }
    if (exists ${$this->{'go'}}{$goid}) {
	my @ecodes=split',',${$this->{'go'}}{$goid};
	my $match=0;
	foreach $c (@ecodes) {
	    if ( $c eq $evidence) {
		$match=1;
	    }
	}
	unless ($match) {
	    ${$this->{'go'}}{$goid}.=",".uc $evidence;
	}
    }else{
	${$this->{'go'}}{$goid}=uc $evidence;
    }
}

sub gobycode {
#retrieve go terms with specific evidence codes.
# call gobycode([includeonly],codelist)
# codelist is a list of evidence codes
# includeonly if true will only return go terms with evidence codes
#in the list, otherwise those not in the list.
    my $this=shift;
    my $not=shift;
    my @ecodes=shift;

    if ($not && scalar @ecodes == 0 ) {
	return;
    }
    my %evid=();
    my @codelist=();
    foreach $ev (@ecodes) {
	if ($ev) {
	    $evid{$ev}=1;
	}
    }
    foreach $goid (keys %{$this->{'go'}}){
	my $flag=0;
        @ec=split ",",${$this->{'go'}}{$goid};
	if ($not) {
	    foreach $e (@ec){
		if (exists $evid{$e} ) {
		    $flag=1;
		}
	    }
	}else {
	    foreach $e (@ec){
		if (!exists $evid{$e} ) {
		    $flag=1;
		}
	    }
	}
	if ($flag){
	    push @codelist,$goid;
	}
    }
    return @codelist;
}
sub evidence {
    my $this=shift;
    my $goid=shift;
    unless ($goid && exists ${$this->{'go'}}{$goid}) {
	return;
    }
    @e=split ",",${$this->{'go'}}{$goid};
    return @e;
}

sub write {
    my $this=shift;
    unless ($this->{'id'}) {
	return;
    }
    $outstr="";
    $outstr.="ID: $this->{'id'}\n";
    if (exists($this->{'source'})){
	$outstr.="SC: $this->{'source'}\n";
    }
    if ($this->{'taxon'}) {
	$outstr.="TX: $this->{'taxon'}\n";
    }
    foreach $goid (keys %{$this->{'go'}}) {
	@e=split ",",${$this->{'go'}}{$goid};
	foreach $ec (@e) {
	    $outstr .= "GO: $goid $ec\n";
	}
    }
    $outstr.="//\n";
    return $outstr;
}

1;
