package GONode;

	$outputtext .= $node->getsubtree();
    $output="<LI>".golink($node->id,$node->name())."(".int (100*$node->getRscore/$GOtotal)")\n";
    if ($node->childcount()) {
	foreach $child ($node->getchildren()){
	if ($node->toplevel()) {
	$node->description($result->getValue(0,0));
	    $node->addparent(makenode($pid));
	    $node->addchild($nodelist{$pid});



sub getsubtree {
#recursive algorithm to get all nodes in this subtree..
    $node=shift;
    $output="<LI>".golink($node->id,$node->name())."(".int (100*$node->getScore/$GOtotal)")\n";
    if ($node->childcount()) {
	$output .="<UL>\n";
	foreach $child ($node->getchildren()){
	    $output .=$child->getsubtree();
	}
	$output .="</UL>\n</LI>\n";
    }
    return $output;
}


sub golink{
    $id=shift;
    $text=shift;
    return "$id ($text)";
}
