package DAGnode;

#class to encapsulate a DAG node with multiple parents and children.
#
# create an instance with DAGnode->new(id); then add children. 
# Parents will be automatically added when it is added as a child.
#

sub new {
	my $class=shift;
	my $this={depth=>0, width=>0,mark=>0};
	$this->id = shift;
	%{$this->parents}=();
	%{$this->children}=();
	bless $this, $class;
	return $this;
}

sub addparent {
	$this=shift;
	$parent=shift;
	if ( ref($parent) == "DAGnode") {
		${$this->parent}{$parent->id()}=$parent;
	}
}

sub addchild {
	$this=shift;
	$child=shift;
	if ( ref($child) == "DAGnode") {
		${$this->children}{$child->id()}=$child;
		$child->addparent($this);
	}
}

sub measure {
	my $this=shift;
	$this->depth=0;
	$this->width = 0;
	if (scalar keys %{$this->children} == 0){
		$this->width=1;
	} else {	
		foreach my $c (values %{$this->children} ) {
			$c->measure();
			unless ($c->ismarked()){
				$this->width += $c->width();
				$c->mark();
			}
			if ($c->depth() >$this->depth){
				$this->depth=$c->depth();
			}
		}
	}
	
}

sub clearmarks {
    my $this=shift;
    $this->mark=0;
    foreach my $c (values %{$this->children} ) {
	$c->clearmarks();
    }
}

sub mark {
	my $this = shift;
	$this->mark=1;
}

sub ismarked {
	my $this=shift;
	return $this->mark;
}

sub depth {
	my $this=shift;
	return $this->depth + 1;
}

sub width {
	my $this=shift;
	return $this->width;
}

1;
