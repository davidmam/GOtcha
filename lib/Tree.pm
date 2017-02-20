package JON::Tree;
use strict;
use Carp;
use Data::Dumper;
use Hash::Util qw(lock_keys);

=head1 $node = Tree->new(name => "node name")

Creates a node with a label of "node name".

=cut

my @keys = qw(mark name daughters parents verbose had_d);

sub new {
	my ($class, %args)= @_;

	croak "Constructer lacks 'name' argument" unless defined $args{name};

	my $self = {};
	@{$self}{@keys}; 
	bless $self, ref($class) || $class;
	lock_keys(%{$self}, @keys);

	$self->name($args{name});
	$self->_init(%args);
	return $self;
}

sub _init { }

=head1 $string = $node->name

Accessor method for the node name.

=cut

sub name {
	my ($self, $name) = @_;
	defined $name ? $self->{name} = $name : return $self->{name};
}

=head1 $node->add_daughter($daughter_node);

Adds a daughter node to the current node. $daughter_node is a Tree object.

=cut

sub add_daughter {
	my ($self, $node) = @_;
	croak "Method add_daughter lacks a daughter node" unless defined $node;

	return if grep { $_ eq $node } $self->get_daughters;
	push @{$self->{daughters}}, $node;

	$node->add_parent($self);
	$node->had_daughter(1);
}


sub had_daughter {
	my ($self, $arg) = @_;
	defined $arg and $arg ? $self->{had_d} = 1 : return $self->{had_d};
}

=head1 $node->add_parent($node);

Adds a parent node to the current node.

=cut

sub add_parent {
	my ($self, $node) = @_;
	croak "Method add_daughter lacks a daughter node" unless defined $node;

	return if grep { $_ eq $node } $self->get_parents;
	
	push @{$self->{parents}}, $node;
	$node->add_daughter($self);
}

sub verbose {
	my ($self, $arg) = @_;
	$arg ? $self->{verbose} = 1 : return $self->{verbose};
}

sub get_parents {
	my ($self) = @_;
	if (exists $self->{parents}) { return @{$self->{parents}} }
	else { return }
}

=head1 $int = $node->del_daughter($daughter_node);

Removes the daughter relationship for the node from the current node. Returns the number of nodes removed, can be more than one if, for some reason, you added more than one node. Returns false if the node doesn't contain that daughter node. This actually deletes the objects.

=cut

sub del_daughter {
	my ($self, $node) = @_;
	croak "Method del_daughter lacks a node" unless defined $node;

	my $flag = 0;

	foreach (0..$#{$self->{daughters}}) {
		if (${$self->{daughters}}[$_] eq $node) {
			splice @{$self->{daughters}}, $_, 1;
			$flag++;
		}
	}
	return $flag;
}

sub del_parent {
	my ($self, $node) = @_;
	croak "Method del_parent lacks a node" unless defined $node;

	my $flag = 0;
	foreach (0..$#{$self->{parents}}) {
		if (${$self->{parents}}[$_] eq $node) {
			splice @{$self->{parents}}, $_, 1;
			$flag++;
		}
	}
	return $flag;
}

=head1 @tree_obj = $node->get_daughters

Returns an array of Tree objects that are daughters of the $node. This is empty if there are no daughters.

=cut

sub get_daughters {
	my ($self) = @_;
	if (exists $self->{daughters}) { return @{$self->{daughters}} }
	else { return }
}

=head1 $node->del_tree;

Deletes all the children nodes beneath the node. This doesn't just remove the relationship, it actually deletes the members.

=cut

sub del_tree {
	my ($self) = @_;

	my @daughters = $self->get_daughters;
	$_->del_tree for @daughters;
	$self->del_daughter($_) for @daughters;

	my @parents = $self->get_parents;
	$_->del_parent($self) for @parents;
}

sub del_node {
	my ($self) = @_;
	$_->del_parent($self) for $self->get_daughters;
	$_->del_daughter($self) for $self->get_parents;
	undef $self;
}

=head1 $array_ref = $node->tree_to_lol

Returns a list of list (of lists...) of the tree structure.

=cut

sub tree_to_lol {
	my ($self) = @_;
	
	my $new;
	push @{$new}, $self->name;
	push @{$new}, $_->tree_to_lol($new) foreach $self->get_daughters;
	return $new;
}

=head1 $string = $node->tree_to_eval

Returns a string of the list of list of the tree, which can be eval'd to recreate the list.

=cut

sub tree_to_eval {
	my ($self) = @_;
	my $dd = Data::Dumper->new([$self->tree_to_lol]);
	$dd->Indent(0);
	return ${[($dd->Dump =~ /\$VAR1 = (.*);$/)]}[0];
}

=head1 $node->lol_to_tree($array_ref)

Constructor to converts a list of lists to a tree.

=cut

sub lol_to_tree {
	my ($class, $lol) = @_;

	croak "Constructer lacks list of list argument" unless defined $lol;

	my $self = {};
	bless $self, ref($class) || $class;

	$self->_lol_to_tree($lol);
	return $self;
}

# Actual method for creating a tree from lol
sub _lol_to_tree {
	my ($self, $lol) = @_;

	my ($node_name) = grep { not ref $_ eq 'ARRAY' } @{$lol};
	my $node = Tree->new(name => $node_name);
	$self->add_daughter($node);

	$node->_lol_to_tree($_) foreach grep { ref $_ eq 'ARRAY' } @{$lol};
}

=head1 $int = $node->find_depth

Returns the maximum depth of the tree under the node.

=cut

sub find_depth {
	my ($self, $depth, $max_depth) = @_;
	$depth = 0 unless defined $depth++ and $depth > 0;
	$max_depth = $depth unless defined $max_depth;

	foreach ($self->get_daughters) {
		my $temp_m = $_->find_depth($depth, $depth + 1);
		$max_depth = $temp_m if $temp_m > $max_depth;
	}
	return $max_depth;
}

sub find_parents {
	my ($self) = @_;

	my @parents = $self->get_parents;
	push @parents, $_->find_parents for @parents;
	return @parents;
}

=head1 $node->get_size

Finds the number of nodes under any particular node.

=cut

sub get_size {
	my ($self, $size) = @_;
	$size = 1 unless defined $size and $size > 0;

	foreach ($self->get_daughters) {
		$size = $_->get_size(++$size)
	}
	return $size;
}

=head1 $node->print_tree

Draws the tree, with indentation showing the relationship between nodes.

=cut

sub print_tree {
	my ($self, $depth) = @_;
	$depth = 0 unless defined $depth and $depth > 0;

	print '  ' x $depth++, $self->name, "\n";
	$_->print_tree($depth) foreach $self->get_daughters;
}

sub find_node {
	my ($self, $method, $value) = @_;
	my @results;

	croak "No such method '$method'" unless $self->can($method);

	push @results, $self if $self->$method eq $value;
	push @results, $_->find_node($method, $value) for $self->get_daughters;
	return @results;
}

sub mark_node {
	my ($self, $mark) = @_;
	$mark ? $self->{mark} = 1 : return $self->{mark};
}

sub address { return $_->[0] }

1;
