package GOscore;

#package to handle an empirical estimate scoring table for GOtcha

sub new {
    my $class=shift;
    my $title=shift;
    $title="Default scoring table title" unless $title;
    $this={ title =>$title,
	    total => 0,
	    mindata => 15,
	    imax=>0,
	    debug=>0,
	    cmax=>0
	    };
    @{$this->{"scores"}}=();
    @{$this->{"true"}}=();
    bless $this,$class;
    return $this;
}

sub debug {
	my $msg=shift;
	print STDERR "GOscore: $msg\n";
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
    $this->{'debug'}=shift;
}

sub debug_off {
    my $this=shift;
    $this->{'debug'}=0;
}

sub addbin {
    my $this=shift;
    my $iscore=shift;
    my $cscore=shift;
    my $freq=shift;
    my $true=shift;
    return unless ($iscore && $cscore && $iscore >= 0 && $cscore >= 0);
#print STDERR "FREQ:".ref($freq) ." :$freq\n";    
#$freq=0 unless ref($freq) eq "SCALAR" && $freq;
    $freq=0 unless $freq;
#print STDERR "TRUE:".ref($true) ." :$true\n";    
#    $true=0 unless ref($true) eq "SCALAR" && $true;
    $true=0 unless $true;
 #   print STDERR "TRUE: $true FREQ:$freq\n";
    $ival=int($iscore);
    $cval=int($cscore);
    $this->{"scores"}[$ival][$cval]=$freq;
    $this->{"true"}[$ival][$cval]=$true;
    if ($cval > $this->{"cmax"}) { $this->{"cmax"}=$cval;}
    if ($ival > $this->{"imax"}) { $this->{"imax"}=$ival;}
}

sub total {
    my $this=shift;
    my $tot=shift;
    if (defined $tot && $tot >0) {
	$this->{"total"}=$tot;
    }
    return $this->{"total"};
}

sub fullscore {
    my $this=shift;
    # return the derived score with additional information about the estimated score.
    # returns array containing score, datapoints, min iscore, max iscore, min cscore, max cscore;
#    return if scalar @{$this->{"scores"}}==0;
    my $iscore = shift;
    my $cscore=shift; # scores to generate accuracy estimate for
 $this->_debug("obtaining fullscore for $iscore and $cscore",2);
    my $count=0; # total corrected number of hits
    my $true=0; # total corrected true hits
    my $score=-1; #impossible score for score underterminable;
    
    my $steps=0;
    my $ivalh=int($iscore*10)+$steps;
    my $cvalh=int($cscore)+$steps;
    my $ivall=int($iscore*10)-$steps;
    my $cvall=int($cscore)-$steps;
    $this->_debug( "GOSCORE: Calculating scores for $iscore ($ivalh), $cscore ($cvalh)",3);
    $this->_debug("GOSCORE: imax: ".$this->{"imax"}." cmax: ".$this->{"cmax"},3);
    while ($count < $this->{"mindata"} && 
	   ($cvall >=0 || 
	    $cvalh <= $this->{"cmax"} || 
	    $ivall >=0 ||
	    $ivalh <= $this->{"imax"})
	   ){  
	
	$ivalh=int($iscore*10)+$steps;
	$cvalh=int($cscore)+$steps;
	$ivall=int($iscore*10)-$steps;
	$cvall=int($cscore)-$steps;
	$this->_debug("GOSCORE: Step $steps ih: $ivalh il: $ivall ch: $cvalh cl: $cvall c: $count t: $true",3);
	for (my $i = $ivall; $i <=$ivalh; $i++){
	    for (my $j = $cvall; $j <=$cvalh; $j++){
		
		if (defined $this->{"scores"}[$i][$j] && 
		    $i >=0 &&
		    $i <=$this->{"imax"} &&
		    $j >=0 &&
		    $j <=$this->{"cmax"} &&
		    ( $i== $ivall || $i==$ivalh || 
		      $j==$cvall || $j==$cvalh )
		    ) {
#		    if (ref($this->{"scores"}[$i][$j]) eq "SCALAR") {
		    	$count+= $this->{"scores"}[$i][$j]/2**$steps;
#		    }
#		    if (ref($this->{"true"}[$i][$j]) eq "SCALAR") {
		    	$true +=$this->{"true"}[$i][$j]/2**$steps;
#		    }
		}
	    }
	}
	$steps++;	
    }
    if ($count > $this->{"mindata"}){
	$score=$true/$count;
    }
    my @results=($score,$count,$true,$ivall,$ivalh,$cvall,$cvalh);
    $this->_debug("fullscore results are ".join(":",@results),3);
    return @results;

    
}

sub simplescore {
    my $this=shift;
    #just return the score without any extra information
    my $iscore=shift;
    my $cscore=shift;
    $this->_debug("GOSCORE: Calculating simple score for $iscore, $cscore",2);
    my @res=$this->fullscore($iscore,$cscore);
    return $res[0];

}

sub score {
    my $this=shift;
$this->_debug("calculating score for $iscore,$cscore",2);
    my $iscore=shift;
    my $cscore=shift;
    return $this->simplescore($iscore,$cscore);
}

sub mindatapoints {
    my $this=shift;
    my $min=shift;
    if (defined $min && $min >0) {
	$this->{"mindata"}=$min;
    }
    return $this->{"mindata"};
}

1;
