#!/usr/bin/perl -w
#
unless ($ENV{GOTCHA_LIB}) {die "GOTCHA_LIB not set\n"};

my $rootdir="$ENV{GOTCHA_LIB}/goa/";
my $sourcefile="$ENV{GOTCHA_LIB}/data/links.dat";
open LINKS, $sourcefile or die "could not open $sourcefile: $! \n";

my %fh=();
my %terms=();
my $taxon=0;
my $id="";
while ($line=<LINKS>){
chomp $line;
  my ($key, $value, $code)= split / +/, $line;
  if ($key eq "ID:"){
  	$id=$value;
  } elsif ($key eq "TX:") {
   	$taxon=$value;
	unless (exists($fh{$taxon})){
	  open $fh{$taxon}, ">$rootdir"."db_$taxon.goa";
	}
  } elsif ($key eq "GO:"){
      $fo = $fh{$taxon};
    print $fo join("\t", "db_$taxon",$id,$id,"", "GO:".substr("0000000".$value, -7), "", $code,"","",$id, "protein","taxon:$taxon", "foo","gotcha")."\n"; 
    #Check to see which fields are really needed.
  } elsif ($key eq "//") {
    print STDERR "completed terms for $id in $taxon\n";
  }

}
