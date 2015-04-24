# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

sub toVersificationBookOrder($$) {
  my $vsys = shift;
  my $osis = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nOrdering books in \"$osis\" according to versification = $vsys\n");

  my %canon;
  my %bookOrder;
  my %testament;
  
  if (&getCanon($vsys, \%canon, \%bookOrder, \%testament)) {
    use XML::LibXML;
    
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs('x', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
  
    my $parser = XML::LibXML->new();
    my $xml = $parser->parse_file($osis);
  
    # remove all books
    my @books = $xpc->findnodes('//x:div[@type="bookGroup"]/x:div[@type="book"]', $xml);
    if (!@books) {@books = $xpc->findnodes('//x:div[@type="book"]', $xml);}
    foreach my $bk (@books) {
      $bk = $bk->parentNode()->removeChild($bk);
    }
    
    # some OSIS files may not have book groups, then books are children of osisText
    my @bookGroup = $xpc->findnodes('//x:div[@type="bookGroup"]', $xml);
    my @osisText = $xpc->findnodes('//x:osisText', $xml);
      
    # place all books back in canon order
    foreach my $v11nbk (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %bookOrder) {
      foreach my $b (@books) {
        if (!$b || $b->findvalue('./@osisID') ne $v11nbk) {next;}
        my $i = ($testament{$v11nbk} eq 'OT' ? 0:1);
        if (!@bookGroup) {@osisText[0]->appendChild($b);}
        else {
          if (@bookGroup == 1) {$i = 0;}
          @bookGroup[$i]->appendChild($b);
        }
        
        $b = '';
        last;
      }
    }
    foreach my $bk (@books) {
      if ($bk ne '') {&Log("ERROR: Book \"$bk\" not found in $vsys Canon\n");}
    }
    
    my $t = $xml->toString();
    
    # removed books left a \n dangling, so remove it too
    $t =~ s/\n+/\n/gm;
    
    open(OUTF, ">$osis");
    print OUTF $t;
    close(OUTF);
  }
  else {&Log("ERROR: Not re-ordering books in OSIS file! (2)\n");}
}
1;
