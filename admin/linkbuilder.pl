#!/usr/bin/perl -w
use FileHandle;
use GOterm;
use GOseq;
use DBI;
use Getopt::Long;
use strict;

#script to generate the databases and indices from the postgres database.

my $goindex="links.idx"; # index file filename
my $godb="links.dat"; # datafile filename.
my $outdir="$ENV{GOTCHA_LIB}/data"; # directory into which to write the links file 
my @ncbi=(); # comma separated list of NCBI taxonomic ids to build database for
my @seqdb=();
my $gouser=""; #userid for accessing GO MySQLdb
my $dbpass=""; #password for accessing GO database
my $dbhost=""; # MySQL host with GO database
my $dbname=""; # database name
my $dbport=3306; #MySQL port.
GetOptions(
	   "index=s"=>\$goindex,
	   "data=s"=>\$godb,
	   "outdir=s"=>\$outdir,
	   "taxid=s"=>\@ncbi,
	   "seqdb=s"=>\@seqdb,
	   "gouser=s"=>\$gouser,
	   "dbpass=s"=>\$dbpass,
	   "dbhost=s"=>\$dbhost,
	   "dbname=s"=>\$dbname,
	   "dbport=s"=>\$dbport
	   );

# now using 32bit record length


sysopen (SEQIFH, "$outdir/$goindex", O_WRONLY|O_CREAT) or die "cannot open SEQIFH $!\n";
binmode SEQIFH;
sysopen (SEQDFH, "$outdir/$godb", O_WRONLY|O_CREAT) or die "cannot open SEQDFH$!\n";;
binmode SEQDFH;
my %ontol=(C=>1,P=>2,F=>3);

my $conn= DBI->connect("DBI:mysql:database=$dbname;host=$dbhost;port=$dbport", $gouser,$dbpass, {AutoCommit =>1} ) or die 
"could not open GO database: ".$DBI::errstr."\n";

my $currentpos=0;

my @sp=split(",", join(",", @ncbi));
print STDERR "processing ".(scalar @sp)." species\n";
my $sth=$conn->prepare("select g.id, x.xref_key,x.xref_dbname, s.ncbi_taxa_id from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref as x on x.id=g.dbxref_id where  s.ncbi_taxa_id = ?"); 

my $dth=$conn->prepare("select g.id, x.xref_key,x.xref_dbname, s.ncbi_taxa_id from gene_product as g inner join species as s on g.species_id=s.id inner join dbxref as x on x.id=g.dbxref_id where  x.xref_dbname = ?"); 

my @db=split(",", join(",", @seqdb));
print STDERR "processing ".(scalar @db)." databases\n";


my %sequences=();
my %offsets=();
my %taxons=();
my $sql="select distinct t.acc, e.code from term as t inner join association as a  on (a.term_id=t.id) inner join evidence as e on (e.association_id =a.id) inner join gene_product as g on (g.id = a.gene_product_id)  where g.id = ?";
my $nth=$conn->prepare($sql);


foreach my $t (@sp){
print STDERR "processing annotations for species id $t\n";
    $sth->execute($t) or die "cannot retrieve gene product list with : $sql : ".$DBI::errstr."\n";
    
    while (my $seq=$sth->fetchrow_hashref()){
	my $id=$seq->{'id'};
	my $taxon=$seq->{ncbi_taxa_id};
	my $seqref=$seq->{xref_key};
	my $seqdb=$seq->{xref_dbname};
	my $seqid=join("_", $seqdb,split(/:/, $seqref));
	$seqid=~s/[-\\\.]/_/g;
	my $newseq=GOseq->new($seqid);
	$nth->execute($id) or warn "Could not get association data for $sql :: $id : ".$DBI::errstr."\n";
	my $el=$nth->fetchall_arrayref();
	
	if ($taxon){
	    $newseq->taxonomy($taxon);
	} 
	unless ($taxon) {print STDERR "no taxon for $seqid\n";}
	foreach my $g (@{$el}){
	    my ($junk,$gid)= split /:/, $g->[0];
	    $newseq->add_go($gid." ".$g->[1]);
	}
	
	
	$offsets{$seqid}=sysseek(SEQDFH, $currentpos,0);
	$taxons{$seqid}=$newseq->taxonomy();
	unless ($taxons{$seqid}) {
	    $taxons{$seqid}=0;
	}
	$currentpos += syswrite(SEQDFH,$newseq->write());
    }
}

foreach my $d (@db){
print STDERR "processing annotations for database $d\n";
    $dth->execute($d) or die "cannot retrieve gene product list with : $sql : ".$DBI::errstr."\n";
    
    while (my $seq=$dth->fetchrow_hashref()){
	my $id=$seq->{'id'};
	my $taxon=$seq->{ncbi_taxa_id};
	my $seqref=$seq->{xref_key};
	my $seqdb=$seq->{xref_dbname};
	my $seqid=join("_", split(/:/, $seqref));
	$seqid=~s/\./_/g;
	my $newseq=GOseq->new($seqid);
	$nth->execute($id) or warn "Could not get association data for $sql :: $id : ".$DBI::errstr."\n";
	my $el=$nth->fetchall_arrayref();
	
	if ($taxon){
	    $newseq->taxonomy($taxon);
	} 
	unless ($taxon) {print STDERR "no taxon for $seqid\n";}
	foreach my $g (@{$el}){
	    my ($junk,$gid)= split /:/, $g->[0];
	    $newseq->add_go($gid." ".$g->[1]);
	}
	
	
	$offsets{$seqid}=sysseek(SEQDFH, $currentpos,0);
	$taxons{$seqid}=$newseq->taxonomy();
	unless ($taxons{$seqid}) {
	    $taxons{$seqid}=0;
	}
	$currentpos += syswrite(SEQDFH,$newseq->write());
    }
}

close SEQDFH;
my $seqcount=scalar keys %offsets;
unless ( $seqcount && $godb) {
    print STDERR "$seqcount : $godb\n";
    exit;
}
my @t=localtime(time);
my $head=pack "LSSSA30", $seqcount,$t[3],$t[4],$t[5],$godb;
syswrite(SEQIFH,$head);
foreach my $ss (sort  {lc $a cmp lc $b } keys %offsets) {
    my $entry=pack "A32LL",$ss,$offsets{$ss},$taxons{$ss};
    syswrite(SEQIFH, $entry);
}
close SEQIFH; 



__END__

=head1 NAME

linkbuilder.pl

=head1 SYNOPSIS

Admin program for building the GO links database for GOtcha.

=head1 DESCRIPTION

This program should be called as linkbuilder.pl <options>

=head2 Options

 -index <filename> # [links.idx] index file filename
 -data <filename> # [links.dat] datafile filename.
 -outdir <path> # [$ENV{GOTCHALIB}/data] directory into which to write the links file 
 -taxid <taxid[,taxid[..]]> # comma separated list of NCBI taxonomic ids to build database for
 -seqdb <name> # Build links for a database, not just a taxonomic group.


=head1 AUTHOR

Dr David Martin

=head1 BUGS

The data file has a filename length limit of 32 characters. 

=head1 COPYRIGHT

This software is copyright 2009 David Martin and the University of Dundee. All rights reserved.

