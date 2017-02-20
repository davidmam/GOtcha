package DAG;

# class for encapsulating a DAG in GO

use DAGnode;

# basic structure is to hold a list of nodes so that 
# adding nodes becomes easy. Just recurse and multiple parentage is
# taken care of as nodes are reused if they are already found.

sub new { 
    my $class=shift;
    my $this={};
    %{$this->nodes}=();
    bless $this, $class;
    return $this;
}

sub countnodes {
    my $this=shift;
    return scalar keys %{$this->nodes};
}

sub setroot {
    my $this= shift;
    my $root=shift;
    unless ($root) {
	warn "No object to set as root\n";
	return;
    }
    if (ref($root)=="DAGnode") { #node object passed as arguement
	$this->root=$root;
    } else { #node id passed as arguement
	$this->root=$this->getnode($root);
    }
}

sub getnode {
    my $this=shift;
    my $id=shift;
    if ($id) {
	unless (exists(${$this->nodes}{lc $id})) {
	    ${$this->nodes}{lc $id}=DAGnode->new($id);
	}
	return ${$this->nodes}{lc $id};
    }
}

sub getroot {
    my $this=shift;
    if (defined $this->root){
	return $this->root;
    }
}

sub measure {
    my $this=shift;
    if (defined $this->root) {
	$this->root->clearmarks();
	$this->root->measure();
	$this->root->mark();
    }
    
}

sub width {
    my $this=shift;
    if (defined $this->root) {
	unless( $this->root->ismarked()) {
	    $this->measure();
	}
	return $this->root->width();
    }
}

sub depth {
    my $this=shift;
    if (defined $this->root) {
	unless( $this->root->ismarked()) {
	    $this->root->measure();
	}
	return $this->root->depth();
    }
}
1;
