#!/usr/bin/perl -w

use lib '/opt/perl/bioperl-live';
use lib '/opt/perl/ensembl/modules';
use lib '/opt/perl/ensembl-compara/modules';
use lib '/opt/perl/ensembl-functgenomics/modules';
use lib '/opt/perl/ensembl-variation/modules';

use DBI::DBD;
use LWP::UserAgent;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org',
    -user => 'anonymous'
);
my %ensembl=(rat=>Bio::EnsEMBL::Registry->get_adaptor("Rattus norvegicus", "core", "translation"),
	     human=>Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "translation"),
	     cow=>Bio::EnsEMBL::Registry->get_adaptor("Bos taurus", "core", "translation"),
#	     zebrafish_gene=>Bio::EnsEMBL::Registry->get_adaptor("Danio rerio", "core", "gene"),
#	     zebrafish=>Bio::EnsEMBL::Registry->get_adaptor("Danio rerio", "core", "translation"),
	     chicken=>Bio::EnsEMBL::Registry->get_adaptor("Gallus gallus", "core", "translation")
	     );


# Zebrafish data:

my %zfin=();

#my @db_adaptors = @{ $registry->get_all_DBAdaptors() };

#foreach my $db_adaptor (@db_adaptors) {
#    my $db_connection = $db_adaptor->dbc();#
#
#    printf(
#        "species/group\t%s/%s\ndatabase\t%s\nhost:port\t%s:%s\n\n",
#        $db_adaptor->species(),   $db_adaptor->group(),
#        $db_connection->dbname(), $db_connection->host(),
#        $db_connection->port()
#    );
#}


#exit;
=pod

=head2 Change these lines to suit

    my $gouser=""; #userid for accessing GO MySQLdb
    my $dbpass=""; #password for accessing GO database
    my $dbhost=""; # MySQL host with GO database
    my $dbname=""; # database name
    my $dbport=3306; #MySQL port.
    my $omnidb=""; # DB for the omniome

You will also need to change the various screenscraping methods below if they are now broken.
=cut
    my $gouser=""; #userid for accessing GO MySQLdb
    my $dbpass=""; #password for accessing GO database
    my $dbhost=""; # MySQL host with GO database
    my $dbname=""; # database name
    my $dbport=3306; #MySQL port.
    my $omnidb=""; # DB for the omniome 
     $conn= DBI->connect("DBI:mysql:database=$dbname;host=$dbhost;port=$dbport", $gouser,$dbpass, {AutoCommit =>1} ) or die 
	"could not open GO database: ".$DBI::errstr."\n";
    print STDERR "opened GO Database \n";
     $cmr_conn=DBI->connect("DBI:mysql:database=$omnidb;host=$dbhost;port=$dbport", $gouser,$dbpass, {AutoCommit =>1} ) or die 
	"could not open GO database: ".$DBI::errstr."\n";
    print STDERR "opened Database for omniome\n";


 %seq_source=(RGD=>\&getRGD,
	      MGI=>\&getMGI,
	      UNIPROT=>\&getUNIPROT,
	      UNIPROTKB=>\&getUNIPROT,
	      'UNIPROTKB/SWISS-PROT'=>\&getUNIPROT,
	      'UNIPROTKB/TREMBL'=>\&getUNIPROT,
	      TIGR_CMR=>\&getTIGR_CMR,
	      JCVI_CMR=>\&getTIGR_CMR,
	      TIGR_TBA1=>\&getTIGR_TBA1,
	      PDB=>\&getPDB,
	      NCBI=>\&getNCBI,
	      TAIR=>\&getTAIR,
	      ENSEMBL=>\&getENSEMBL,
	      GENEDB=>\&getGENEDB,
	      WB=>\&getWB,
	      ASPGD=>\&getASPGD,
	      SGD=>\&getSGD,
	      CGD=>\&getCGD,
	      FB=>\&getFB,
	      ZFIN=>\&getZFIN,
	      REFSEQ=>\&getREFSEQ,
	      'H-INVDB'=>\&getHINVDB,
	      VEGA=>\&getVEGA,
	      GR_PROTEIN=>\&getGRPROTEIN,
	      PSEUDOCAP=>\&getPSEUDOCAP,
	      DICTYBASE=>\&getDICTYBASE
	      );

 
# ##################SUBROUTINES###################

sub outputseq {
    my ($hr)=@_;
    my $seqid=$hr->{symbol};
    my $dbname=$hr->{xref_dbname};
    my $dbref=$hr->{xref_key};
    my $dbname_short= uc $dbname;

    $dbname_short=~s/(GENEDB)_.*/$1/;
    print STDERR "$dbname, $dbname_short, $seqid\n";
    my $header="";
    my $seq="";
    if (exists($seq_source{$dbname_short})){
	($header,$seq)=&{$seq_source{$dbname_short}}($dbname,$dbref);
	if ($seq){
	    $seqcount++;
	}else{
	    $seqerrcount++;
	    print SEQDBERR "Error retrieving $dbref from $dbname\n";
	    return;
	}
    } else {
	$seqerrcount++;
	print SEQDBERR "NO METHOD TO GET $dbref from $dbname\n";
	return;
    }
    my $l = length($seq);

    my $displaydb=$dbname;
    $displaydb=~s!\/!_!g;
    $display_id = join("_",$displaydb, split(/:/, $dbref));
    $seqid=~s/\./_/g;
    $display_id=~s/[-\.\/]/_/g;
    print STDERR ">$display_id ($seqid) $header ";
    print STDERR "($l amino acids)\n";
    print SEQDB  ">$display_id ($seqid) $header\n";
    my $a=0;
    for ($a=0 ; $a<$l-60;$a+=60) {
	print SEQDB substr($seq,$a,60)."\n";
    }
    print SEQDB substr($seq,$a)."\n";
    return $l;
}

sub getTIGR_TBA1 {
    my ($dbn, $dbr, $dbs) =@_;

    my($h, $s)= getEMBOSS($dbr, "tba1");
    unless ($h && $s) {
	($h, $s)=getEMBOSS($dbs, "tba1");
    }
    return ($h, $s);
    
}		

sub getPDB {
    my ($dbn, $dbr) =@_;
    # need to retrieve the sequence for a particular chain
    my $pdburl="http://www.pdb.org/pdb/download/downloadFile.do?fileFormat=fastachain&compression=NO&structureId=";
    my $chainid="";
    my ($struc, $chain)=split /_/, $dbr;
    if ($chain){
	$chainid="&chainId=$chain";
    }
    print STDERR "retrieving $dbr: $struc chain $chain\n";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's pdb seq searcher/0.1 ");
    my $req = HTTP::Request->new(GET => $pdburl.$struc.$chainid);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	my @lines = split /[\r\n]+/, $page;
	$header=shift @lines;
	$header =~s/>//;
	$seq=join "", @lines;
	if ($header =~/DOCTYPE/){ # warning message for too rapid access
	    sleep 20;
	    ($header,$seq)=getPDB($dbn, $dbr);
	}
	return ($header, $seq);

    }

}

sub getNCBI {
    my ($dbn, $dbr) =@_;
    if ($dbr=~m/^.P_*/){
	return getREFSEQ($dbn, $dbr);
    } else {
	my ($h,$s)=getEMBOSS($dbr, "uniprotsrs");
	return ("$dbr $h",$s);
       # Need to retrieve from genbank via accession number.
    }
}

sub getRGD {
    my ($dbn, $dbr) =@_;
    if ($dbr =~m/^ENSRN/) {
	print STDERR "Processing RGD peptide from ensEMBL\n";
	return getENSEMBL($dbn, $dbr);
    }
    my $raturl="http://rgd.mcw.edu/tools/genes/genes_view.cgi?id=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's rat retriever/0.1 ");
    my ($db, $id)=split /:/, $dbr;
    print STDERR "processing sequence $xref\n";
    my $req = HTTP::Request->new(GET => $raturl.$id);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	$page=~tr/\r/\n/;
	my @lines= split /\n/,$page;
	print STDERR (scalar @lines)." lines retrieved\n"; 
	my $i=0;
	my $ensref="";
	while ($i<scalar @lines && ! $ensref){
	    if ($lines[$i] =~m!<td>Ensembl Protein:</td><td><a href=\"http://www.ensembl.org/Rattus_norvegicus/protview\?db=core;peptide=(ENSRNOP\d+)!){
		$ensref=$1;
		print STDERR "found peptide $ensref\n";
	    }
	    $i++;
	}

	if ($ensref){
	     ($header, $seq)=getENSEMBL('ENSEMBL', $ensref);
	}
    }
    return ($header, $seq);
}

sub getMGI {
    my ($dbn, $dbr) =@_;
    if ($dbr=~m/^\d+$/) {
	$dbr="MGI:$dbr";
    }
    my $mgiurl="http://www.informatics.jax.org/searches/accession_report.cgi?format=pre&limit=500&submit=Search&id=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's mouse mangler/0.1 ");
    my $req = HTTP::Request->new(GET => $mgiurl.$dbr);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	$page=~tr/\r/\n/;
	my @lines= split /\n/,$page;
	print STDERR (scalar @lines)." lines retrieved\n"; 
	my $i=0;
	my $ensref="";
	my $uniprot="";
	while ($i<scalar @lines && ! $ensref){
	   # if ($lines[$i] =~m/RefSeq/) {print STDERR $lines[$i];}
	    if ($lines[$i] =~m{http://www.ncbi.nlm.nih.gov/entrez/viewer.cgi\?val=(NP_\d{6})}){	
		#if ($lines[$i] =~m!HREF=\'http://www.uniprot.org/entry/(.{6})\'>UniProt</A>!){
		$ensref=$1;
		print STDERR "found peptide $ensref\n";
	    }
	    $i++;
	
	    if ($lines[$i] =~m!HREF=\'http://www.uniprot.org/entry/(.{6})\'>UniProt</A>!){
		$uniprot=$1;
		print STDERR "found peptide $uniprot\n";
	    }
	}	
if ($ensref){
	     ($header, $seq)=getREFSEQ('REFSEQ', $ensref);
#	     ($header, $seq)=getUNIPROT('UNIPROT', $ensref);
	}
if ($uniprot){
	     #($header, $seq)=getREFSEQ('REFSEQ', $ensref);
	     ($header, $seq)=getUNIPROT('UNIPROT', $uniprot);
	}
    } else {
	print STDERR "HTTP Error\n";
    }
    return ($header, $seq);
}

sub getUNIPROT {
    my ($dbn, $dbr) =@_;
    $dbr=~s/-.*$//;
    my ($header, $seq)=getEMBOSS($dbr, "uniprotwww");

    return ($header, $seq);
}

sub getASPGD {
    my ($dbn, $dbr) =@_;
    $dbr=~s/-.*$//;
    my ($header, $seq)=getEMBOSS($dbr, "anidulans");

    return ($header, $seq);
}

sub getEMBOSS {
    my ($id, $embossdb)=@_;

    open EMBOSS, "/sw/bin/seqret $embossdb:$id -stdout -first -auto |";
    my $header=<EMBOSS>;
    chomp $header;
    $header=~s/>//;
    my $seq=<EMBOSS>;
    chomp $seq;
    while (my $line=<EMBOSS>){
	chomp $line;
	$seq .=$line;
    }
    close EMBOSS;
    return ($header, $seq);
}

sub getTREMBOSS {
    my ($id, $embossdb)=@_;

    open EMBOSS, "/sw/bin/transeq $embossdb:$id -stdout -first -auto |";
    my $header=<EMBOSS>;
    chomp $header;
    $header=~s/>//;
    my $seq=<EMBOSS>;
    chomp $seq;
    while (my $line=<EMBOSS>){
	chomp $line;
	$seq .=$line;
    }
    close EMBOSS;
    return ($header, $seq);
}

sub getTIGR_CMR {
    my ($dbn, $dbr) =@_;
    my $seq="";
    my $header="";
    my $sql="select protein from asm_feature where locus=?";
    my $sth=$cmr_conn->prepare($sql);
    $sth->execute($dbr);
    my $hr=$sth->fetchrow_hashref();
    if (exists($hr->{'protein'}) && $hr->{'protein'}){
	$seq=$hr->{'protein'};
	$header="from Omniome";
    } else {
	# no translated protein
	# get DNA sequence from omniome via EMBOSS and translate with transeq.
	($header, $seq)=getTREMBOSS($dbr, "omniomen");
	
    }
    return ($header, $seq);
}

sub getTAIR {
    my ($dbn, $dbr, $dbs) =@_;
    unless ($dbr=~m/:/) {
	return getUNIPROT($dbn, $dbr);
    }
    my $tairurl="http://www.arabidopsis.org/servlets/TairObject?accession=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's weed killer/0.1 ");
    my $req = HTTP::Request->new(GET => $tairurl.$dbr);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	$page=~tr/\r/\n/;
	my @lines= split /\n/,$page;
	print STDERR (scalar @lines)." lines retrieved\n"; 
	my $i=0;
	my $pepref="";
	while ($i<scalar @lines && ! $pepref){
	    if($lines[$i] && ($lines[$i]=~m!(/servlets/TairObject\?type=aa_sequence\&id=\d+)!)){
		$pepref="http://www.arabidopsis.org$1";
		print STDERR "Peptide at $pepref\n";
	    }
	    $i++;
	}
	if ($pepref){
	    $req=HTTP::Request->new(GET => $pepref);
	    $res=$ua->request($req);
	    if ($res->is_success) {
		$page=$res->content;
		$page=~tr/\r/\n/;
		@lines= split /\n/,$page;
		print STDERR (scalar @lines)." lines retrieved (peptide page)\n"; 
		$i=0;
		my $ensref="";
		while ($i<scalar @lines && ! $ensref){
		    if ($lines[$i]=~m!"+1">Protein: ([A-Z0-9]+)\.!){
			$header="$dbr $1";
		    }
		    if ($lines[$i] =~m!input type="hidden" name="sequence" value="([A-Z]+)"!){
			$ensref=$1;
			$seq=$ensref;
			print STDERR "found peptide $ensref\n";
		    }
		    $i++;
		}
		
		
		    
		
	    } else {
		print STDERR "Error retrieving peptide page from TAIR :$pepref:".$res->status_line()."\n";
	    }
	} else { 
	    print STDERR "No pepref found\n";
	}
    } else { 
	print STDERR "Error retrieving from TAIR :".$res->status_line()."\n";
    }

    return ($header, $seq);
}

sub getGENPEP {
    my ($gbid)=@_;
    my $gburl="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?cmd=text&db=protein&dopt=fasta&val=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's GB getter/0.1 ");
    my $req = HTTP::Request->new(GET => $gburl.$gbid);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	$page=~tr/\r/\n/;
	my @lines= split /\n+/,$page;
	$header=shift @lines;
	$header=~s/>//;
	$seq=join("",@lines);
	if ($seq=~m/Error/){
	    $seq="";
	}
     }
    return ($header, $seq);
}

sub getENSEMBL {
    my ($dbn, $dbr) =@_;
    my %species=(ENSRNOP0=>'rat',
		 ENSP0=>'human',
		 ENSGALP0=>'chicken',
		 ENSDARG=>'zebrafish',
		 ENSBTAP0=>'cow'
		 );
    my $start=$dbr;
    $start=~s/^(ENS[^0]*P0)\d+$/$1/;
    unless (exists($species{$start})){
	print STDERR "could not find species for $dbr as $start\n";
	return;
    }
    my %emboss=(chicken=>"enschick",
		cow=>"ensbull"
		);
    if (exists($emboss{$species{$start}})){
	return getEMBOSS($dbr,$emboss{$species{$start}});
    }else{
	my $adaptor=$ensembl{$species{$start}};
	print STDERR "$adaptor\n";
	my $feat=$adaptor->fetch_by_stable_id($dbr);
	my $seq=$feat->seq();
	return ($dbr, $seq);
    }
}

sub getGENEDB {
    my ($dbn, $dbr) =@_;
    my ($junk, $sp)=split/_/, $dbn;
    my $seq="";
    my $header="";
    my %orgs=(Pfalciparum=>'malaria',
	      Tbrucei=>'tryp',
	      Spombe=>'pombe'
	      );

    my $gdburl="http://www.genedb.org/genedb/Search?&view=seq&organism=".$orgs{ucfirst lc $sp}."&name=";
    print STDERR "retrieving from $gdburl\n";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's Genedb Getter/1.0");
    my $pr=HTTP::Request->new(GET => $gdburl.$dbr);
    my $seqpage=$ua->request($pr);
 
    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	my $flag="";
	my $i=scalar @lines;
	while (( ! $seq ) && $i>0){
	    $hline=shift @lines;
	    #print STDERR "HLINE: $hline\n";
	    if (index($hline,"a name=\"protein\"")>0){
		#print STDERR "Protein: $hline\n";
		$flag="protein";
		print STDERR "found protein section\n";
	    }
	    $i--;
	    if ($flag && $hline=~m/<pre>/){
		#print STDERR "HLINE2: $hline\n";
		#print STDERR "Found sequence header\n";
		$header=shift @lines;
		$seq=shift @lines;
		#print STDERR "$header\n";
	    }
	}
	while (index($seq,"</pre>")==-1 && @lines){
	    $seq .= shift @lines;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	$header=~s/>//;
	#print STDERR $aa;
    }
    return ($header, $seq);
}

sub getPLASMODB {
    my ($id)=@_;
    $purl="http://plasmodb.org/plasmodb/servlet/sv?page=gene&source_id=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's Plasmodb puller/1.0");
    my $pr=HTTP::Request->new(GET => $purl.$id);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	while ( ! $seq && ($hline=shift @lines)){
	    if (!$header && $hline=~m!<title>!){
		$header=shift @lines;
	    }
	    if ($hline=~m/<div id="proteinSequence" class="boggle">/){
		shift @lines;
		$seq=shift @lines;
	    }
	}
	while (!$seq =~m!</pre>!){
	    $seq .= shift @lines;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	#print STDERR $aa;
    }

    return ($header, $seq);

}

sub getWB {
    my ($dbn, $dbr) =@_;
    my $wburl="http://wormbase.org/db/seq/protein?class=Protein&name=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's Worm Charmer/1.0");
    my $pr=HTTP::Request->new(GET => $wburl.$dbr);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	while ( ! $seq && ($hline=shift @lines)){
	    if ($hline=~m!<title>Protein Report for: WP:(.*)</title>!){
		$header=$1;
	    }
	    if ($hline=~m/Amino Acid Sequence/){
		print STDERR "Protein section found\n";
		$seq=shift @lines;
	    }
	}
	while ($seq && index($seq,"</pre>")==-1 && @lines){
	    $seq .= shift @lines;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	#print STDERR $aa;
    } else {
	print STDERR "Error retrieving page: ".$seqpage->status_line()."\n"; 
    }
    return ($header, $seq);
}

sub getSGD {
    my ($dbn, $dbr) =@_;
    my $sgdurl="http://db.yeastgenome.org/cgi-bin/getSeq?format=FASTA&seqtype=ORF%20Translation&query=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's Yeast Yanker/1.0");
    my $pr=HTTP::Request->new(GET => $sgdurl.$dbr);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	while ( ! $header && ($hline=shift @lines)){
	    if ($hline=~m!<h2>Sequence for a region of (.+)</h2>!){
		$header=$1;
	    }
	}
	while ((!($seq =~m!<!)) &&($hline=shift @lines)){
	    $seq .= $hline;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	$seq=~s/\*//g;
	#print STDERR $aa;
    }
    return ($header, $seq);
}

sub getCGD {
    my ($dbn, $dbr) =@_;
    my $cgdurl="http://www.candidagenome.org/cgi-bin/getSeq?map=p3map&seq_source=Assembly%2021&seq=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("Canestan is my friend/1.0");
    my $pr=HTTP::Request->new(GET => $cgdurl.$dbr);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	while ( ! $header && ($hline=shift @lines)&& @lines){
	    if ($hline=~m!Protein translation of the coding sequence!){
		#print STDERR "header found\n";
		$header=$hline;
		$header=~s/^.*>([^>]*)$/$1/;
		#print STDERR "$header\n";
	    }
	}
	$hline=shift @lines;
	while (index($hline,"</pre>")==-1 && @lines) {
	#					    hlines =~m!<! && ($hline=shift @lines)){
	    $seq .= $hline;
	    $hline=shift @lines;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	$seq=~s/\*//g;
	#print STDERR $aa;
    }
    return ($header, $seq);
}

sub getFB {
    my ($dbn, $dbr) =@_;
    my $fburl="http://www.flybase.org/reports/";
#my $ncbiurl="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=protein&amp;tool=FlyBase&amp;val=%09AAF46121"
    
    my  $ua = LWP::UserAgent->new;  
    my $pr=HTTP::Request->new(GET => $fburl.$dbr.".html");
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	print STDERR "FB access success\n";
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	while (@lines) {
	    my $hline=shift @lines;
	    if ($hline=~m!db=protein[^\"]*val=([^\"]*)\"!){
		my $ncbiurl="http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?cmd=text&db=protein&dopt=fasta&amp;tool=FlyBase&amp;val=".$1;
		print STDERR  "Found entrex ref $ncbiurl\n";
		$ncbiurl.='&cmd=text&dopt=fasta';
		my $sr=HTTP::Request->new(GET => $ncbiurl);
		my $seqinfo=$ua->request($sr);
		if ($seqinfo->is_success) {
		    my $saa=$seqinfo->content;
		    $saa=~tr/\r/\n/;
		    $saa=~s/\n+/\n/g;
		    my @slines = split /\n+/, $saa;
		    $header=shift @slines;
		    $seq=join "", @slines;
		    if ($header=~m!DOCTYPE!) {
			$seq="";
			$header="";
		    }
		    
		    #print STDERR $aa;
		    $header=~s/>//;
		    $seq=~s/>.*//; #remove all but the first sequence.
		    if ($seq && $header){
			return ($header,$seq);
		    }
		}
	    }
	}
    }
    return ($header, $seq);
}

sub getZFIN {
    my ($dbn, $dbr) =@_;
    
    if (scalar keys %zfin ==0) {
	open (ZFIN, "$ENV{GOTCHA_LIB}/db/zfin_refseq.txt") or return;
	while (my $line=<ZFIN>){
	    $line=~s/[\r\n]//g;
	    my @z=split /[ \t]/, $line;
	    if ($z[2]=~m/^NP_/){
		$zfin{$z[0]}=$z[2];
	    }
	}
    }
    if (exists($zfin{$dbr})){
	my ($head, $seq)=getREFSEQ($dbn, $zfin{$dbr});
	my $header="$dbr $head";
	return $header, $seq;
	
    }
    return; 
    
}


sub getREFSEQ {
    my ($dbn, $dbr) =@_;
    my ($header, $seq)=getEMBOSS($dbr, "refseqwww");
    return ($header, $seq);
}

sub getHINVDB {
    my ($dbn, $dbr) =@_;

    my $hinvurl="http://www.jbirc.aist.go.jp/hinv/spsoup/transcript_view?status=prt&dl=prt&hit_id=";
    my  $ua = LWP::UserAgent->new;  
    my $pr=HTTP::Request->new(GET => $hinvurl.$dbr);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	$header=shift @lines;
	$seq=join "", @lines;
	#print STDERR $aa;
	my $seqid=$db."_$id";
	$header=~s/>//;
	$seq=~s/>.*//; #remove all but the first sequence.
    }
    return ($header, $seq);
}

sub getGRPROTEIN {
    my ($dbn, $dbr) =@_;

    my ($header, $seq)=getUNIPROT($dbn, $dbr);

    return ($header, $seq);
}
sub getVEGA {
    my ($dbn, $dbr) =@_;

    my  $ua = LWP::UserAgent->new;  
    my $ensurl="/exportview?type1=peptide&type2=bp&format=fasta&action=export&_format=Text&options=peptide&output=txt&submit=Continue+%3E%3E&anchor1=";
    my %species=(OTTRNOP0=>'Rattus_norvegicus',
		 OTTHUMP0=>'Homo_sapiens'
		 );
    my $start=$dbr;
    $start=~s/^(OTT[^0]*P0)\d+$/$1/;
    my $header="";
    my $seq="";
    unless (exists($species{$start})){
	print STDERR "could not find species for $dbr as $start\n";
	return;
    }
    my $fullurl="http://vega.sanger.ac.uk/".$species{$start}.$ensurl;
    my $pr=HTTP::Request->new(GET => $fullurl.$dbr);
    my $seqpage=$ua->request($pr);

    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	$header=shift @lines;
	if ($header =~m/DOCTYPE/){
	    print STDERR "Error retrieving $dbr from ENSEMBL\n";
	    return;
	}
	$seq=join "", @lines;
	#print STDERR $aa;
#	my $seqid=$db."_$id";
	$header=~s/>//;
    }

    return ($header, $seq);
}

sub getPSEUDOCAP {
    my ($dbn, $dbr) =@_;
    my $pcapurl="http://www.pseudomonas.com/getAnnotation.do?locusID=";

    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's bug bringer/0.1 ");
    my $req = HTTP::Request->new(GET => $pcapurl.$dbr);
    $req->header(Connection=>'close');
    my $res = $ua->request($req);
    my $header="";
    my $seq="";
    if ($res->is_success) {
	my $page=$res->content;
	$page=~tr/\r/\n/;
	my @lines= split /\n/,$page;
	print STDERR (scalar @lines)." lines retrieved\n"; 
	my $i=0;
	my $pepref="";
	while ($i<scalar @lines && ! $pepref){
	    if($lines[$i]=~m!http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi\?db=protein\&val=(\d+)!){
		$pepref="$1";
	    }
	    $i++;
	}
	if ($pepref){
	    ($header, $seq)=getGENPEP($pepref);
	}
    }



    return ($header, $seq);
}

sub getDICTYBASE {
    my $credit =<<DICTY;
Eichinger L, Pachebat JA, Glockner G, Rajandream MA, Sucgang R, Berriman M, Song J, Olsen R, Szafranski K, Xu Q, Tunggal B, Kummerfeld S, Madera M, Konfortov BA, Rivero F, Bankier AT, Lehmann R, Hamlin N, Davies R, Gaudet P, Fey P, Pilcher K, Chen G, Saunders D, Sodergren E, Davis P, Kerhornou A, Nie X, Hall N, Anjard C, Hemphill L, Bason N, Farbrother P, Desany B, Just E, Morio T, Rost R, Churcher C, Cooper J, Haydock S, van Driessche N, Cronin A, Goodhead I, Muzny D, Mourier T, Pain A, Lu M, Harper D, Lindsay R, Hauser H, James K, Quiles M, Madan Babu M, Saito T, Buchrieser C, Wardroper A, Felder M, Thangavelu M, Johnson D, Knights A, Loulseged H, Mungall K, Oliver K, Price C, Quail MA, Urushihara H, Hernandez J, Rabbinowitsch E, Steffen D, Sanders M, Ma J, Kohara Y, Sharp S, Simmonds M, Spiegler S, Tivey A, Sugano S, White B, Walker D, Woodward J, Winckler T, Tanaka Y, Shaulsky G, Schleicher M, Weinstock G, Rosenthal A, Cox EC, Chisholm RL, Gibbs R, Loomis WF, Platzer M, Kay RR, Williams J, Dear PH, Noegel AA, Barrell B, Kuspa A. (2005)  The genome of the social amoeba Dictyostelium discoideum. Nature 435(7038): 43-57.
DICTY

    my ($dbn, $dbr) =@_;
    return getEMBOSS($dbr, "dicty");

    my $dburl="http://www.dictybase.org/db/cgi-bin/feature_page.pl?primary_id=";
    my  $ua = LWP::UserAgent->new;  
    $ua->agent("David's slimy searcher/1.0");
    my $pr=HTTP::Request->new(GET => $dburl.$dbr);
    my $seqpage=$ua->request($pr);
    my $header="";
    my $seq="";
    print STDERR "retrieving page $dburl.$dbr\n";
    if ($seqpage->is_success) {
	my $aa=$seqpage->content;
	$aa=~tr/\r/\n/;
	$aa=~s/\n+/\n/g;
	my @lines = split /\n+/, $aa;
	my $hline="";
	while ( ! $header && ($hline=shift @lines)){
	    if ($hline=~m!<pre>>.*Protein!){
		print STDERR "found header $hline\n"; 
		$header=$hline;
		$header=~s/^.*>([^>]*)$/$1/;
	    }
	}
	while ((!($seq =~m!<!)) && ($hline=shift @lines)){
	    $seq .= $hline;
	}
	$seq=~s/ //g;
	$seq=~s/<[^>]+>//g;
	$seq=~s/\*//g;
	#print STDERR $aa;
    }    return ($header, $seq);
}

    
1;


__END__

=head1 NAME

dblib.pl

=head1 SYNOPSIS

Library of routines for retrieving sequence info from public databases.

=head1 DESCRIPTION

The library contains a set of routines which all take the same two arguments:
C<getDBNAME($dbn, $dbr)> 

 $dbn is the database name
 $dbr is the record accession
 DBNAME is the name of the resource at which the record can be found and is linked from the %seq_source hash as a reference to the subroutine. eg DBNAME=>\&getDBNAME

Each method returns the header and sequence as a 2 element array.


=head1 AUTHOR

Dr David Martin

=head1 BUGS


=head1 COPYRIGHT

This software is copyright 2009 David Martin and the University of Dundee. All rights reserved.


