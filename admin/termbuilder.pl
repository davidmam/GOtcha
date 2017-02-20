#!/usr/bin/perl -w
use FileHandle;
use GOterm;
use GOseq;
use DBI;
use Getopt::Long;
use strict;

# UPDATED TO USE 32bit RECORD SIZE.

# script to generate the databases and indices from the postgres database.
# modified to work with the GO MySQL database.

# Data access variables.. set them here:
my $gouser=""; #userid for accessing GO MySQLdb
my $dbpass=""; #password for accessing GO database
my $host=""; # MySQL host with GO database
my $dbname=""; # database name
my $dbport=3306; # MySQL port
my $outdir="../data";
my $goindex="";
my $godb="";

GetOptions(
"godb=s"=>\$godb,
"goindex=s"=>\$goindex,
"outdir=s"=>\$outdir,
"gouser=s"=>\$gouser,
"dbpass=s"=>\$dbpass,
"host=s"=>\$host,
"dbname=s"=>\$dbname,
"dbport=s"=>\$dbport
	   );


unless ($goindex && $godb) {
    print STDERR "arguments must include -godb and -goindex\n"; 
    die "incorrect number of arguments\n"
}

# my $seqindex=shift @ARGV;
# my $seqdb=shift @ARGV;

##CHECK THIS FOR LATEST RELEASE

my $PARTOF=11;# relationship term type id from term
my $KINDOF=2;# relationship term type id from term

my %relationships =(is_a=>0,
		    has_part=>0,
		    negatively_regulates=>0,
		    part_of=>0,
		    positively_regulates=>0,
		    regulates=>0
		    );

my %rcodes=();
my %pcodes =(is_a=>"PT",
	     has_part=>"PH",
	     negatively_regulates=>"PD",
	     part_of=>"PP",
	     positively_regulates=>"PU",
	     regulates=>"PR"
	     );

my $rsql="Select * from term where term_type in ('relationship','gene_ontology')";




sysopen (GOIFH, "$outdir/$goindex", O_WRONLY|O_CREAT) or die "cannot open GOIFH $!\n";
binmode GOIFH;
sysopen (GODFH, "$outdir/$godb", O_WRONLY|O_CREAT) or die "cannot open GODFH$!\n";;
binmode GODFH;

my %ontol=(C=>1,P=>2,F=>3,O=>4);

my $conn= DBI->connect("DBI:mysql:database=$dbname;host=$host;port=$dbport", $gouser, $dbpass, { AutoCommit=>1, RaiseError=>1});


# $isql= "select id from term where name=?";
my $sth=$conn->prepare($rsql);
$sth->execute();

while (my $hr=$sth->fetchrow_hashref()){
    if (exists($hr->{name})){
	$relationships{$hr->{name}}=$hr->{id};
	$rcodes{$hr->{id}}=$hr->{name};
    }
}
# ($KINDOF)=$sth->fetchrow_array;
# $sth->execute("part_of");
# ($PARTOF)=$sth->fetchrow_array;


 
# Prepare a bunch of queries for reuse later.
 $sth=$conn->prepare("select distinct id, acc, term_type, name, term_definition from term inner join term_definition td on term.id=td.term_id where term_type in ('biological_process', 'cellular_component', 'molecular_function') and is_obsolete=0 and acc not in('part_of')");
my $secsearch=$conn->prepare("select term_synonym from term_synonym where term_id = ?"); 
my $parsearch=$conn->prepare("select acc, relationship_type_id from term as t, term2term as t2t where t2t.term1_id = t.id and t2t.term2_id = ?"); 
my $childsearch=$conn->prepare("select acc from term as t, term2term as t2t where t2t.term2_id = t.id and t2t.term1_id = ?"); 
my $xrefsearch=$conn->prepare("select db.xref_dbname ||':'|| db.xref_key from dbxref as db, term_dbxref as t where t.term_id = ? and t.dbxref_id = db.id and t.is_for_definition =0");
my $ancsearch=$conn->prepare("select t.acc from term as t, graph_path as g where g.term1_id = t.id and g.term2_id =? and t.acc <> 'all' and t.is_obsolete=0");
my $golist=$sth->execute();


my $termcount=0;
my $termvalsref=$sth->fetchrow_hashref();
my %termvals=%$termvalsref;
my %onts=(molecular_function=>"F",
       biological_process=>"P",
       cellular_component=>"C",
	  gene_ontology=>"O"
       ); #simple lookup table from brain dead ontology implemetnation in GO
my %ontologies=();
my %offsets=();
my %term2id=(); #link term acc and id
my $currentpos=0;

while (scalar keys %termvals) {
    my $dbid=$termvals{"id"}; #internal table id for the GO term.Need this for future referencing.
    my $id=$termvals{"acc"};
    $id=~s/GO://;
    $term2id{$dbid}=$id;
    my $desc=$termvals{"name"};
    my $def=$termvals{"term_definition"};
    my $ont=$onts{lc $termvals{"term_type"}};
    my $goterm=GOterm->new($id);
    $goterm->description($desc);
    $goterm->definition($def);
    $goterm->ontology($ont);
    $secsearch->execute($dbid);
    $ontologies{$id}=$ontol{$ont};
    $offsets{$id}=sysseek(GODFH,$currentpos,0);
    my @secs=$secsearch->fetchrow_array;
    while (scalar @secs){
	my $cid=$secs[0];
	if ($cid=~m/GO:/){
	    $cid=~s/GO://;
	    $ontologies{$cid}=$ontol{$ont};
	    $offsets{$cid}=sysseek(GODFH,$currentpos,0);
	    $goterm->add_secondary($cid);
	} else {
	    $goterm->add_synonym($cid);
	}
	@secs=$secsearch->fetchrow_array();
    }


    $parsearch->execute($dbid); 
    while (my $pr=$parsearch->fetchrow_hashref()){
	my $parid=$pr->{acc};
	my $relid=$pr->{relationship_type_id};
	$parid=~s/GO://;
	$goterm->add_parent($parid,$pcodes{$rcodes{$relid}});
    }
#   $parsearch->execute($dbid,$KINDOF); 
#   @pars=$parsearch->fetchrow_array();
#   while (scalar @pars){
#	$parid=$pars[0];
#	$parid=~s/GO://;
#	$goterm->add_parent($parid,0);
#	@pars=$parsearch->fetchrow_array();
#   }
    $childsearch->execute($dbid);
    my @kids=$childsearch->fetchrow_array();
    while (scalar @kids) {
	my $kidid=$kids[0];
	$kidid=~s/GO://;
	$goterm->add_children($kidid);
	@kids=$childsearch->fetchrow_array();
    }
    $xrefsearch->execute($dbid);
    my @xrefs=$xrefsearch->fetchrow_array();
    while (scalar @xrefs) {
	$goterm->add_dbxref($xrefs[0]);
	@xrefs=$xrefsearch->fetchrow_array();
    }
    $ancsearch->execute($dbid);
    my @ancs=$ancsearch->fetchrow_array();
    while (scalar @ancs) {
	my $anc=$ancs[0];
	$anc=~s/GO://;
	$goterm->add_ancestorlist($anc);
	@ancs=$ancsearch->fetchrow_array();
    }
    $currentpos +=syswrite(GODFH, $goterm->output());
    if(my $termvalsref=$sth->fetchrow_hashref()){
	%termvals=%$termvalsref;
    } else {
	%termvals=();
    }
}

close GODFH;

my $gocount=scalar keys %ontologies;
my @t=localtime(time);
my $head=pack "LSSSA30", $gocount,$t[3],$t[4],$t[5],$godb;
syswrite(GOIFH,$head);
foreach my $go (sort {$a <=>$b} keys %ontologies) {
#    print STDERR "go $go ,off$offsets{$go},ont $ontologies{$go}";
    my $entry=pack "A32LL",$go,$offsets{$go},$ontologies{$go};
    syswrite(GOIFH,$entry);
}
close GOIFH;

