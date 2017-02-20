package ClusterJob;
#// PHP class for managing cluster jobs
#// This class encapsulates submission of a job or series of jobs.
#// need to cope with command, resource requests, arrays, output and error 
#// directories, and basically everything qsub can do.
#// need to capture the job ID and provide a method for monitoring the job.
#//
#
#class ClusterJob {

sub new {
    my $class=shift;
    my $command=shift;
    my $this=(
	      command=>"", 
	      outdir=>"", 
	      errordir=>"", 
	      resources=>"",
	      mailaddr=>"", 
	      jobid=>"",
	      subreturncode=>"",
	      cwd=>"",
	      log=>"",
	      arraystart=>0,
	      arrayend=>0,
	      arraystep=>0,
	      qsubshell=>"/grid/default/common/settings.sh",
	      qsubdir=>"",
	      qsubcmd=>"qsub"
	      );
       
    $this->{"command"}=$command;	
    $this->{"log"} .= "New ClusterJob: command set to $command\n";
    %{$this->{"resources"}}=();
    %{$this->{"mailaddr"}}=();
    bless $this, $class;
    return $this;
}
sub lognote {
    my $this=shift;
    my $note=shift;
    $this->{"log"} .= "$note\n";
}

sub outpath {
    my $this=shift;
    my $dir=shift;
    if ($dir ) {
	$this->{"outdir"}=$dir;
	$this->lognote("outpath set to $dir");
    }
    return $this->{"outdir"};
}

sub mailaddress {
    my $this=shift;
    my $addr=shift;
    if ($addr) {
	unless (exists ${$this->{"mailaddr"}}{$addr}) {
	    ${$this->{"mailaddr"}}{$addr}=1;
	    $this->lognote("mailaddress  $addr added to list");
	}
    }
}
	
sub errorpath {
    my ($this, $dir)=@_;
    if ($dir) {
	$this->{"errordir"}=$dir;
	$this->lognote("errorpath set to $dir");
    }
    return $this->{"errordir"};
}

sub setexecdir {
    my ($this,$dir="")=@_;
    $this->{"qsubdir"}=$dir;
    $this->lognote( "execdir set to $dir");
    
    return $this->{"qsubdir"};
}

sub getexecdir {
    my ($this)=@_;
    return $this->{"qsubdir"};
}

sub setqsubenv {
    my ($this,$dir)=@_;
    unless ($dir) {$dir="";}	    
    
    $this->{"qsubshell"}=$dir;
    $this->lognote("qsubshell set to $dir");
    return $this->{"qsubshell"};
}

sub getqsubenv {
    my ($this)=@_;
    return $this->{"qsubshell"};
}

sub setcwd  {
    my ($this,$flag)=@_;
    unless ($flag) {$flag=0;}
    $this->{"cwd"}=$flag;
    $this->lognote("cwd set to $flag");
    return $this->{"cwd"};
}

sub getcwd  {
    my ($this)=@_;
    return $this->{"cwd"};
}

sub arrayjob {
    my ($this,%params)=@_;
    if (exists($params{"start"}) && exists($params{"end"}) && exists($params{"step"}) ){
	if ($params{"end"} >= $params{"start"} && $params{"start"} >0 && $params{"step"} < $params{"end"}-$params{"start"}) {
	    $this->{"arraystart"}=$params{"start"};
	    $this->{"arrayend"}=$params{"end"};
	    $this->{"arraystep"}=$params{"step"};
	    $this->lognote("array job set to start: $start; end: $end; step: $step");
	}
    }
}
sub get_arraystart  {
    my ($this)=@_;
    return $this->{"arraystart"};
}

sub get_arrayend  {
    my ($this)=@_;
    return $this->{"arrayend"};
}

sub get_arraystep  {
    my ($this)=@_;
    return $this->{"arraystep"};
}

sub set_qsub  {
    my ($this,$cmd)=@_;
    $this->{"qsubcmd"}=$cmd;
    return $this->{"qsubcmd"};
}

sub get_qsub  {
    my ($this)=@_;
    return $this->{"qsubcmd"};
}

sub add_resource  {
    my ($this,$key, $value)=@_;
    if ($key && $value){
	${$this->{"resources"}}{$key}=$value;
	$this->lognote("resource $key added with value $value");
    }
}

sub get_resource  {
    my ($this,$key)=@_;
    if (exists(${$this->{"resources"}}{$key})){
	return ${$this->{"resources"}}{$key};
    }
}

sub submit  {
    my ($this)=@_;
    #build the command
    $subcmd="source ".$this->{"qsubshell"}."; ";
    if ($this->{"qsubdir"}) {
	$subcmd.="cd ".$this->{"qsubdir"}."; ";
    }
    $subcmd.=$this->{"qsubcmd"}." ";
    if ($this->{"outdir"}) {
	$subcmd .= " -o ".$this->{"outdir"};
		}	
    if ($this->{"errordir"}) {
	$subcmd .= " -e ".$this->{"errordir"};
    }	
    if ($this->{"cwd"}) {
	$subcmd .= " -cwd";
    }	
    foreach my $k (keys %{$this->{"resources"}}){
	$subcmd .=" -l $k=".${$this->{"resources"}}{$k};
    }
    if ($this->{"arraystart"} && $this->{"arrayend"} && $this->{"arraystep"} && $this->{"arrayend"}-$this->{"arraystart"} >0) {
	$subcmd .=" -t ".$this->{"arraystart"}."-".$this->{"arrayend"}.":".$this->{"arraystep"};
    }
    if ( scalar keys %{$this->{"mailaddr"}}) {
	$subcmd .= " -M ".join(",",keys %{$this->{"mailaddr"}});
    }
    $subcmd .=" ".$this->{"command"};
    {
	local $/="\n";
	@subresult=qx/ $subcmd /;
    }
    $this->{"subreturncode"}=$?>>8;
    $this->lognote("command is $subcmd");

#    $subcmd,$subresult,$this->subreturncode);
    $this->lognote("output from qsub: ",join"\n",@subresult);
    $this->lognote("qsub return code ".$this->{"subreturncode"});
    my @line=split("/ +/",$subresult[0]);
    $this->lognote("Return code ".$this->{"subreturncode"});			
    $this->{"jobid"}=$line[2];
    $this->lognote("Grid Engine Job ID ". $this->{"jobid"});
    return $this->{"jobid"};
}

sub log {
    my ($this)=@_;
    return $this->{"log"};
}

sub arrayjobstatus {
    my ($this, $taskid, $jobid)=@_;
    if ($this->{"jobid"}) {
	$jobid=$this->{"jobid"};
    }
    if ($jobid){
	if (scalar keys %{$this->{"taskstatus"}} ==0 ) {
	    $this->jobstatus($jobid);
	}
	unless ($taskid <1 || $taskid >${$this->{"taskidstatus"}}[0]) {
	    return ${$this->{"taskidstatus"}}[$taskid];
	}
    }
    print STDERR "No such job $jobid or array task $taskid\n";
}

sub jobstatus  {
    my ($this,$job)=@_;
    my $status="";
    my $retval=0;
    %{$this->{"taskstatus"}}=();
    @{$this->{"taskidstatus"}}=();
    my @joblist=();
    $job=$job?$job:0;
    if ($job >0 || $this->{"jobid"}) {
	$joblist=array();
	if (!$job) {
	    $job=$this->{"jobid"};
	}
	if ($this->{"arraystop"}) {
	    ${$this->{"taskidstatus"}}[0]=$this->{"arraystop"};
	}
	{
	    local $\="\n";
	    @joblist= qx/"source /grid/default/common/settings.sh; qstat -s prszhuhohshjhah"/;
	    $retval=$?;
	}
	$this->lognote("QSTAT retval= $retval");
	shift @joblist; # get rid of the header line.
#FIXME from here#
# need to get lines corresponding to the job and deal with array jobs if necessary.
	while ( scalar @joblist){
	    my $line = shift @joblist;
	    my ($jid, $pri, $tname, $tuser, $status, $date, $time, $queue, $master,$ajobid) = unpack("A7 x A6 x A10 x A12 x A6 A10 x A8 x A10 x A6 x A*",$line);
	    $jid=~s/^ *(\d+) *$/$1/;
	    $this->lognote("QSTAT: $line");
	    if ($jid==$job) {
		$status=~tr/ //;
		$ajobid=~tr/ //;
		${$this->{"taskstatus"}}{$status}=1;
		if ($ajobid) { # this is an array job
		    $ajobid=~tr/ //;
		    @aj=split /,/,$ajobid; #sets of array jobs
		    foreach my $jl (@aj){
			my ($start,$end)=split "-", $jl;
			unless ($end) {
			    $end=$start;
			}
			for (my $j=$start; $j<$end+1;$j++){
			    ${$this->{"taskidstatus"}}[$j]=$status;
			}
			if ($end > ${$this->{"taskidstatus"}}[0]){
			    ${$this->{"taskidstatus"}}[0]=$end;
			}
		    }    
		}else{
		    @{$this->{"taskidstatus"}}=(1);
		    ${$this->{"taskidstatus"}}[1]= $status;
		    @joblist=(); #clear the joblist as we only need one entry.
		}
	    }
	}
	if (scalar @{$this->{"taskidstatus"}} == 0 && ! $this->{"arraystop"}) {
	    @{$this->{"taskidstatus"}}= (1,"x");
	    ${$this->{"taskstatus"}}{"x"}=1;
	} else {
	    for (my $i=1; $i<${$this->{"taskidstatus"}}[0]+1; $i++){
		unless (${$this->{"taskidstatus"}}[$i]){
		    ${$this->{"taskidstatus"}}[$i]="x";
		    ${$this->{"taskstatus"}}{"x"}=1;
		}
	    }
    }else {
	${$this->{"taskstatus"}}{"u"}=1;
    }
    $this->lognote(" tasks are in state ".join ",",keys %{$this->{"taskstatus"}});
	return keys %{$this->{"taskstatus"}};
}

sub jobstatustext {
    my ($this,$text=0)=@_;
    $this->lognote( "STATUSCODE: $text");
    $codes=array("Eqw" => "Error",
		 "qw"=>"Pending",
		 "t"=>"Preparing",
		 "r"=>"Running",
		 "u"=>"Unsubmitted",
		 "x"=>"Not pending, running or error");
    if (exists($codes{$text})) {
	return "Job status is $text (".$codes{$text}.")";
    }else {
	return "Job status is $text (Unrecognised)";
    }
}

return 1;
