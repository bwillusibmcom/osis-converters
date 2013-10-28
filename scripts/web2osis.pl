# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
#		 
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".	If not, see 
# <http://www.gnu.org/licenses/>.
#
########################################################################

&Log("-----------------------------------------------------\nSTARTING web2osis.pl\n\n");
open(OUTF, ">:encoding(UTF-8)", "$OUTPUTFILE") || die "Could not open web2osis output file $OUTPUTFILE\n";

&getCanon($VERSESYS, \%mycanon, \%mybookorder);

# Read the COMMANDFILE, converting each book as it is encountered
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open html2osis command file $COMMANDFILE\n";

$ClassInstructions = "CHAPTER_NUMBER|VERSE_NUMBER|BOLD|ITALIC|REMOVE|CROSSREF|CROSSREF_MARKER|FOOTNOTE|FOOTNOTE_MARKER|IGNORE|INTRO_PARAGRAPH|INTRO_TITLE_1|LIST_TITLE|LIST_ENTRY|TITLE_1|TITLE_2|CANONICAL_TITLE_1|CANONICAL_TITLE_2|BLANK_LINE|PARAGRAPH|POETRY_LINE_GROUP|POETRY_LINE";
$TagInstructions = "IGNORE_KEY_TAGS|IGNORE_KEY_TAG_ATTRIBUTES";
$TrueFalseInstructions = "ALLOW_OVERLAPPING_HTML_TAGS|ALLOW_REDUCED_TAG_CLASSES|GATHER_CLASS_INFO";
$SetInstructions = "addScripRefLinks|addDictLinks|addCrossRefs";
$SetTrueFalse = "addScripRefLinks|addDictLinks|addCrossRefs";

$InlineTags = "(span|font|sup|a|b|i)";

$R = 0;
$Filename = "";
$Linenum	= 0;
$line=0;
while (<COMF>) {
	$line++;
	
	if ($_ =~ /^\s*$/) {next;}
	elsif ($_ =~ /^#/) {next;}
	elsif ($_ =~ /^($ClassInstructions):\s*(\((.*?)\))?\s*$/) {if ($2) {$ClassInstruction{$1} = $3;}}
	elsif ($_ =~ /^($TagInstructions):\s*((<[^>]*>)+)?\s*$/) {if ($2) {$TagInstruction{$1} = $2;}}
	elsif ($_ =~ /^($TrueFalseInstructions):\s*(true|false)?\s*$/) {if ($2) {$TrueFalseInstruction{$1} = ($2 eq "true" ? 1:0);}}
	elsif ($_ =~ /^OSISBOOK:\s*(.*?)\s*=\s*(.*?)\s*$/) {$OsisBook{$1} = $2;}
	elsif ($_ =~ /^SPAN_CLASS:.*?(\S+)=((<[^>]*>)+)\s*$/) {$SpanClassName{$2} = $1;}
	elsif ($_ =~ /^DIV_CLASS:.*?(\S+)=((<[^>]*>)+)\s*$/) {$DivClassName{$2} = $1;}
	elsif ($_ =~ /^SET_($SetInstructions):(\s*(\S+)\s*)?$/) {
		if ($2) {
			my $par = $1;
			my $val = $3;
			$$par = $val;
			if ($par =~ /^($SetTrueFalse)$/) {
				$$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
			}
			&Log("INFO: Setting $par to $$par\n");
		}
	}
	elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
		my $htmlfile = $1;
		$htmlfile =~ s/\\/\//g;
		if ($htmlfile =~ /^\./) {
			chdir($INPD);
			$htmlfile = File::Spec->rel2abs($htmlfile);
			chdir($SCRD);
		}
		my $htmlfileName = $htmlfile;
		$htmlfileName =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
		if (exists($OsisBook{$htmlfileName}) && exists($mycanon{$OsisBook{$htmlfileName}})) {
			
			# process this book now...
			$TrueFalseInstruction{"GATHER_CLASS_INFO"} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} || !%SpanClassName && !%DivClassName);
			if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {&Log("INFO: Gathering class information. OUTPUT IS NOT OSIS!\n");}
			
			$Book = $OsisBook{$htmlfileName};
			
			my $osisfile = &HTMLtoOSIStags($htmlfile);
			
			&handleNotes("crossref", \$osisfile);
			&handleNotes("footnote", \$osisfile);
			
			my $tmpBook = "$OUTPUTFILE.1";
			open(OUTTMP, ">:encoding(UTF-8)", $tmpBook) || die "Could not open web2osis output file $tmpBook\n";
			print OUTTMP $osisfile;
			close(OUTTMP);
			
			my $swordOsis = &osis2SWORD($tmpBook);
			
			# save output for sorting and writing later
			$OsisBookText{$OsisBook{$htmlfileName}} = $swordOsis;
		}
		else {&Log("ERROR: SKIPPING \"$htmlfile\". Could not determine OSIS book.\n");}
	}
	else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}
close(COMF);

# print out the OSIS file in v11n correct book order
&Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"defaultReferenceScheme\" xml:lang=\"$LANG\"><header><work osisWork=\"$MOD\"><title>$MOD Bible</title><identifier type=\"OSIS\">Bible.$MOD</identifier><refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n");
&Write("<div type=\"bookGroup\">\n");
foreach my $bk (sort {$mybookorder{$a} <=> $mybookorder{$b}} keys %OsisBookText) {
	if ($wasWritingOT && $mybookorder{$bk} > 39) {&Write("</div>\n<div type=\"bookGroup\">\n");}
	&Write($OsisBookText{$bk});
	$wasWritingOT = ($mybookorder{$bk} <= 39);
}
&Write("</div>\n</osisText>\n</osis>\n");
close (OUTF);

# log a bunch of stuff now...
&Log("\nLISTING OF SPAN CLASSES:\n");
foreach my $classTags (sort {$SpanClassCounts{$SpanClassName{$a}} <=> $SpanClassCounts{$SpanClassName{$b}}} keys %SpanClassName) {
	&Log(sprintf("SPAN_CLASS:%5i %3s=%s\n", $SpanClassCounts{$SpanClassName{$classTags}}, $SpanClassName{$classTags}, $classTags));
}

&Log("\nLISTING OF DIV CLASSES:\n");
foreach my $classTags (sort {$DivClassCounts{$DivClassName{$a}} <=> $DivClassCounts{$DivClassName{$b}}} keys %DivClassName) {
	&Log(sprintf("DIV_CLASS:%5i %3s=%s\n", $DivClassCounts{$DivClassName{$classTags}}, $DivClassName{$classTags}, $classTags));
}

if (!$TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
	&Log("\nLISTING OF UNUSED CLASSES:\n");
	foreach my $classTags (sort keys %SpanClassName) {
		if (!exists($UtilizedClasses{$SpanClassName{$classTags}})) {
			&Log(sprintf("SPAN_CLASS: %5s=%s\n", $SpanClassName{$classTags}, $classTags));
		}
	}
	foreach my $classTags (sort keys %DivClassName) {
		if (!exists($UtilizedClasses{$DivClassName{$classTags}})) {
			&Log(sprintf("DIV_CLASS: %5s=%s\n", $DivClassName{$classTags}, $classTags));
		}
	}
	
	&Log("\nLISTING OF OSIS TYPE X ATTRIBUTES IN OUTPUT:\n");
	foreach my $type (sort keys %XTypesInText) {
		&Log($type." ");
	}
	&Log("\n");
}

&Log("\nLISTING OF ALL HTML TAGS:\n");
foreach my $t (sort keys %AllHTMLTags) {
	&Log($t." ");
}
&Log("\nlisting complete\n");

1;

########################################################################
########################################################################

# All this really does is convert HTML tags into OSIS tags according to
# ClassInstructions, and reformats the markup with one tag per line. 
# It does not output SWORD compatible OSIS markup, and it uses xCHx 
# and xVSx placeholders for verse and chapter.
sub HTMLtoOSIStags() {
	my $file = shift;
	
	my $outText = "";
	
	$Filename = $file;
	$Filename =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
	$Linenum = 0;
	
	&Log("Processing $Book\n");
	&normalizeNewLines($file);
	&logProgress($Book);
	
	open(INP1, "<:encoding(UTF-8)", $file) or print getcwd." ERROR: Could not open file $file.\n";
	my $processing = 0;
	my $text = "";
	while(<INP1>) {
		$Linenum++;
		$_ =~ s/[\n\l\r]+$//;
		
		if ($text) {$text .= " ";} # a previous line feed in text requires a space
		
		# process body only and ignore all else
		if ($_ =~ /<body[^>]*>(.*)$/i) {
			$_ = $1;
			$processing = 1;
		}
		if (!$processing) {next;}
		if ($_ =~ /^(.*)<\/body[> ]/i) {
			$_ = $1;
			$processing = 0;
		}
		
PROCESS_TEXT:
		while($_) {
			if ($_ =~ s/^([^<]+)(<|$)/$2/) {$text .= $1;}
			if ($_ =~ s/^(<[^>]*>)//) {
				my $tag = $1;
				
				# process previously collected text, adding Osis tags around applicable text
				$outText .= &getOsisText(\$text);
				
				# process the new tag
				my $tagname = $tag;
				$tagname =~ s/^<(\/)?(\w+)\s*([^>]*?)>$/$2/;
				my $isEndTag = ($1 ? 1:0);
				my $attribs = $3;
				
				# IGNORE_KEY_TAGS entries do not contribute to any tag's key, but are converted here straight to OSIS tags
				my @ignoreTags = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAGS"});
				foreach my $ignoreTag (@ignoreTags) {
					if (!$ignoreTag || $ignoreTag !~ /<(\w+)/) {next;}
					if (lc($1) eq lc($tagname)) {
						my $inlineTag;
						if (lc($tagname) eq "b") {$inlineTag= (!$isEndTag ? "<hi type=\"bold\">":"</hi>");}
						elsif (lc($tagname) eq "i") {$inlineTag= (!$isEndTag ? "<hi type=\"italic\">":"</hi>");}
						else {
							if (!exists($IgnoreTagErrorReported{$tagname})) {
								&Log("WARN: IGNORE_KEY_TAGS \"$tagname\" will be completely ignored.\n");
							}
							$IgnoreTagErrorReported{$tagname}++;
						}
						if ($inlineTag) {
							if (!$isEndTag) {$R++;} else {$R--;}
							$outText .= $inlineTag;
						}
						next PROCESS_TEXT;
					}
				}
				
				# get an OSIS tag and add this tag to the current tagstack used for creation of tag classes
				$outText .= &getStackTag($tag);
			}
		}
	}
	close(INP1);
	
	if ($text && $text !~ /^\s*$/) {&Log("ERROR: $file line $line: unwritten text \"$text\"\n");}
	if ($tagstack{"level"}) {&Log("ERROR: $file line $line: tag level not zero \"".$tagstack{"level"}."\"\n");}
	
	return $outText;
}

sub getOsisText(\$) {
	my $textP = shift;
	if (length($$textP) == 0) {return;}
	
	my $outText = "";
	my $class = "";
	
	if (!$TagStack{"level"} && $$textP !~ /^\s*$/) {
		&Log("WARN: $Filename line $Linenum: Top level text \"$$textP\"\n");
	}
	else {
		# create a key by combining all current tags
		my $key = "";
		my @tkeys;
		my %count;
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			my $ktagval = $TagStack{"tag-key"}{$i};
			if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
				if ($TagStack{"tag-name"}{$i} !~ /^$InlineTags$/i) {next;}
				if ($ktagval eq "" || exists($count{$ktagval})) {next;}
				$count{$ktagval}++;
			}
			push(@tkeys, $ktagval);
		}
		
		if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
			# then tkeys are sorted 
			foreach my $tkey (sort @tkeys) {$key .= $tkey;}
		}
		else {foreach my $tkey (@tkeys) {$key .= $tkey;}}

		if ($key ne "") {
			if (!exists($SpanClassName{$key})) {
				$ClassNumber++;
				$SpanClassName{$key} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} ? "s":"gs").$ClassNumber;
			}
			$SpanClassCounts{$SpanClassName{$key}}++;
			
			$class = $SpanClassName{$key};
		}
	}
	
	$outText = ($class ? &getOsisTag("span", $class, 0):"").$$textP.($class ? &getOsisTag("span", $class, 1):"").($R == 0 ? "\n":"");
	
	$$textP = "";
	return $outText;
}

sub getStackTag($\%) {
	my $tag = shift;
	
	my $outText = "";
	
	if ($tag =~ /<br(\s+|>)/i) {
		$outText .= "<lb\/>\n";
		$AllHTMLTags{"br"}++;
		return;
	}
	
	# start tag
	if ($tag !~ /^<\/(\w+)/) {
		$tag =~ /^<(\w+)\s*(.*)?\s*>$/;
		my $tagname = $1;
		my $atts = $2;
		
		$AllHTMLTags{$tagname}++;
		
		my $tagkey = "<".lc($tagname);
		my $tagvalue = $tagkey;
		if ($atts) {
			# sort all attributes out
			my %attrib;
			if ($atts =~ /^((\w+)(=("([^"]*)"|[\w\d]+))?\s*)+$/) {
				while ($atts) {
					if ($atts =~ s/^(\w+)=("([^"]*)"|([\w\d]+))\s*//) {
						$attrib{$1} = ($3 ? $3:$4);
					}
					$atts =~ s/^\w+(\s+|$)//; # some HTML has empty attribs so just remove them
				}
			}
			else {&Log("ERROR: $Filename line $Linenum: bad tag attributes \"$atts\"\n");}
			
			
			my @ignoreAttribs = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAG_ATTRIBUTES"});
			
			foreach my $a (sort keys %attrib) {
				$tagvalue .= " ".lc($a)."=\"".$attrib{$a}."\"";
				my $skipme = 0;
				
				# skip listed tag/attribute pairs which are not relavent to key
				foreach my $ignoreAttrib (@ignoreAttribs) {
					if (!$ignoreAttrib) {next;}
					if ($ignoreAttrib !~ /^<([\w\*]+)\s+(\w+)\s*>$/) {
						&Log("ERROR: Bad IGNORE_KEY_TAG_ATTRIBUTES value \"$ignoreAttrib\"\n");
						next;
					}
					my $it = $1;
					my $ia = $2;
					if (lc($ia) eq lc($a) && ($it eq "*" || lc($it) eq lc($tagname))) {
						$skipme = 1;
					}
				}
				if ($skipme) {next;}
				
				# save attribute to key
				$tagkey .= " ".lc($a)."=\"".$attrib{$a}."\"";
			}
		}
		$tagkey .= ">";
		$tagvalue .= ">";
		
		# write out all block tags now, but inline tags will be handled in getOsisText()
		if ($tagname !~ /^$InlineTags$/i) {
			if (!exists($DivClassName{$tagkey})) {
				$DivClassNumber++;
				$DivClassName{$tagkey} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} ? "d":"gd").$DivClassNumber;
			}
			$DivClassCounts{$DivClassName{$tagkey}}++;
			
			$outText .= &getOsisTag($tagname, $DivClassName{$tagkey}, 0).($R == 0 ? "\n":"");
		}

		$TagStack{"level"}++;
		$TagStack{"tag-name"}{$TagStack{"level"}} = $tagname;
		$TagStack{"tag-key"}{$TagStack{"level"}} = $tagkey;
		$TagStack{"tag-value"}{$TagStack{"level"}} = $tagvalue;
	}
	
	#end tag
	else {
		my $tagname = $1;
		my $taglevel = $TagStack{"level"};
		
		$AllHTMLTags{$tagname}++;
		
		if ($tagname ne $TagStack{"tag-name"}{$TagStack{"level"}}) {
			if ($TrueFalseInstruction{"ALLOW_OVERLAPPING_HTML_TAGS"}) {
				for (my $i = $TagStack{"level"}; $i > 0; $i--) {
					if ($tagname eq $TagStack{"tag-name"}{$i}) {
						$taglevel = $i;
						last;
					}
				}
			}
			else {
				&Log("ERROR: $Filename line $Linenum: Bad tag stack \"$tag\" != \"".$TagStack{"tag-name"}{$TagStack{"level"}}."\"\n");
			}
		}
		
		# write out all block tags now, but inline tags will be handled in getOsisText()
		if ($tagname !~ /^$InlineTags$/i) {
			$outText .= &getOsisTag($tagname, $DivClassName{$TagStack{"tag-key"}{$taglevel}}, 1).($R == 0 ? "\n":"");
		}
		
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			if ($i == $taglevel) {
				delete($TagStack{"tag-name"}{$i});
				delete($TagStack{"tag-key"}{$i});
				delete($TagStack{"tag-value"}{$i});
			}
			if ($i > $taglevel) {
				$TagStack{"tag-name"}{$i-1} = $TagStack{"tag-name"}{$i};
				$TagStack{"tag-key"}{$i-1} = $TagStack{"tag-key"}{$i};
				$TagStack{"tag-value"}{$i-1} = $TagStack{"tag-value"}{$i};
			}
		}
		$TagStack{"level"}--;
	}
	
	return $outText;
}

sub getOsisTag($$$) {
	my $htmltagname = lc(shift);
	my $class = shift;
	my $isEndTag = shift;
	
	my $t = "";
	if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
		$t .= "<";
		if ($isEndTag) {$t .= "/";}
		$t .= $htmltagname;
		if (!$isEndTag && $class ne "") {$t .= " type=\"x-$class\"";}
		$t .= ">";
	}
	else {
		if ($class eq "") {
			if (!exists($ReportDroppedTag{"$htmltagname-$class"})) {
				&Log("INFO: Began dropping \"$htmltagname\" tags with null class.\n");
			}
			$ReportDroppedTag{"$htmltagname-$class"}++;
			return "";
		}
		$UtilizedClasses{$class}++;

		$t .= &getOsisTagForElement(&getOsisElementForClass($class, $htmltagname), $isEndTag);
	}
	
	return $t;
}

sub getOsisElementForClass($$) {
	my $class = shift;
	my $htmltagname = shift;

	# convert the tag class to an OsisElement based on CF_html2osis.txt ClassInstructions
	my $myOsisElement = "";
	foreach my $elem (keys %ClassInstruction) {
		my $c = $ClassInstruction{$elem};
		if ($class =~ /^($c)$/) {
			if ($myOsisElement) {&Log("ERROR: Multiple OSIS elements assigned to class \"$class\" (\"$myOsisElement\" and \"$elem\").\n");}
			$myOsisElement = $elem;
		}
	}
	if (!$myOsisElement) {
		$myOsisElement = "PARAGRAPH-".$class;
		if ($htmltagname =~ /^$InlineTags$/i) {$myOsisElement = "SEG-".$class;}
		if (!exists($DefErrorReported{$class})) {
			&Log("INFO: ($Filename line $Linenum) No OSIS element assigned to class \"$class\" using default: \"$myOsisElement\" ($class=".&getTagsOfClass($class).").\n");
		}
		$DefErrorReported{$class}++;
	}
	
	return $myOsisElement;
}

sub getOsisTagForElement($$) {
	my $element = shift;
	my $isEndTag = shift;

	my $tagname = "";
	my $attribs = "";
	my $isMilestone = 0;

	if    ($element eq "VERSE_NUMBER") {$tagname = "verse";}
	elsif($element eq "CHAPTER_NUMBER") {$tagname = "chapter";}
	elsif($element eq "BOLD") {$tagname = "hi"; $attribs = "type=\"bold\"";}
	elsif($element eq "ITALIC") {$tagname = "hi"; $attribs = "type=\"italic\"";}
	elsif($element eq "REMOVE") {$tagname = "remove";}
	elsif($element eq "CROSSREF_MARKER") {$tagname = "OC_crossrefMarker"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$CrossRefMarkerID)."\"";}}
	elsif($element eq "CROSSREF") {$tagname = "OC_crossref"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$CrossRefID)."\"";}}
	elsif($element eq "FOOTNOTE_MARKER") {$tagname = "OC_footnoteMarker"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$FootnoteMarkerID)."\"";}}
	elsif($element eq "FOOTNOTE") {$tagname = "OC_footnote"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$FootnoteID)."\"";}}
	elsif($element eq "IGNORE") {return "";}
	elsif($element eq "INTRO_PARAGRAPH") {$tagname = "p"; $attribs = "type=\"x-intro\"";}
	elsif($element eq "INTRO_TITLE_1") {$tagname = "title"; $attribs = "type=\"x-intro\" level=\"1\"";}
	elsif($element eq "LIST_TITLE") {$tagname = "list"; $attribs = "type=\"x-intro\"";}
	elsif($element eq "LIST_ENTRY") {$tagname = "item"; $attribs = "type=\"x-listitem\"";}
	elsif($element eq "TITLE_1") {$tagname = "title"; $attribs = "level=\"1\"";}
	elsif($element eq "TITLE_2") {$tagname = "title"; $attribs = "level=\"2\"";}
	elsif($element eq "CANONICAL_TITLE_1") {$tagname = "title"; $attribs = "level=\"1\" canonical=\"true\"";}
	elsif($element eq "CANONICAL_TITLE_2") {$tagname = "title"; $attribs = "level=\"2\" canonical=\"true\"";}
	elsif($element eq "BLANK_LINE") {$isMilestone = 1; $tagname = ($isEndTag ? "lb":"skip");}
	elsif($element eq "PARAGRAPH") {$tagname = "p";}
	elsif($element =~ /^PARAGRAPH\-(.*?)$/) {$tagname = "p"; $attribs = "type=\"x-$1\"";}
	elsif($element eq "POETRY_LINE_GROUP") {$tagname = "lg";}
	elsif($element eq "POETRY_LINE") {$tagname = "l";}
	elsif($element =~ /^SEG\-(.*?)$/) {$tagname = "seg"; $attribs="type=\"x-$1\"";}
	
	if ($tagname eq "") {&Log("ERROR: No entry for OSIS element \"$element\"\n");}
	
	# notes should end up on a single line
	if (!$isEndTag && ($element eq "FOOTNOTE" || $element eq "CROSSREF")) {$R++;}
	if ($isEndTag  && ($element eq "FOOTNOTE" || $element eq "CROSSREF")) {$R--;}

	if ($tagname eq "skip") {return "";}
	
	my $ret = "<";
	if (!$isMilestone && $isEndTag) {$ret .= "/";}
	$ret .= $tagname;
	if (!$isEndTag && $attribs) {$ret .= " ".$attribs;}
	if ($isMilestone) {$ret .= "/";}
	$ret .= ">";
	
	return $ret;
}

sub handleNotes($\$) {
	my $type = shift;
	my $tP = shift;
	
	# find and convert each note body
	while ($$tP =~ s/(<OC_$type id="([^"]*)">(.*?)<\/OC_$type>)//) {
		my $bodyIndex = $-[1];
		my $id = $2;
		my $body = $3;
		
		my $note = "<note".($type eq "crossref" ? " type=\"crossReference\"":"");
		$note .= " osisRef=\"$Book.xCHx.xVSx\"";
		$note .= " osisID=\"$Book.xCHx.xVSx!".($type eq "crossref" ? "crossReference.":"")."n$id\"";
		$note .= " n=\"$id\"";
		$note .=">$body</note>";
		
		# place the note now
		if (exists($ClassInstruction{($type eq "crossref" ? "CROSSREF_MARKER":"FOOTNOTE_MARKER")})) {
			my $typeMarker = $type."Marker";
			if ($$tP !~ s/(<OC_$typeMarker id="$id">.*?<\/OC_$typeMarker>)/$note/) {
				&Log("ERROR: Could not find marker for $type \"$id\".\n");
			}
		}
		else {substr($$tP, $bodyIndex, 0) = $note;}
	}
	
	if ($$tP =~ /<OC_$type/) {&Log("ERROR: Unhandled note type $type \"$id\".\n");}
}

sub getCurrentNoteId($) {
	my $n = shift;
	return $n;
}

sub osis2SWORD($) {
	my $bkfile = shift;
	
	my $s = "<div type=\"book\" osisID=\"$Book\" canonical=\"true\">\n";
	
	open(IBK, "<:encoding(UTF-8)", $bkfile) || die "Could not open $bkfile\n";

	my $chapter = 0;
	my $verse = 0;

	my $verseEnd = "";
	my $sectionEnd = "";
	my $chapterEnd = "";

	while (<IBK>) {
		$_ =~ s/[\n\l\r]+$//;
		
		if ($_ =~ /<chapter>(.*?)<\/chapter>/) {
			my $ch = $1;
			$verse = 0;
			
			$s .= $verseEnd.$sectionEnd.$chapterEnd;
			$verseEnd = "";
			$sectionEnd = "";
			$chapterEnd = "</chapter>\n";
			
			if ($ch =~ /^\s*(\d+)\s*/) {$chapter = $1;}
			else {&Log("ERROR: Could not parse chapter \"$ch\".\n");}
			
			$s .= "<chapter osisID=\"$Book.$chapter\" n=\"$chapter\">\n";
			next;
		}
		elsif ($_ =~ /<verse>(.*?)<\/verse>/) {
			my $vs = $1;
			
			$s .= $verseEnd;
			
			if ($vs =~ /^\s*(\d+)\s*(-\s*(\d+))?/) {$verse = $1.($2 ? "-$3":"");}
			else {&Log("ERROR: Could not parse verse \"$vs\".\n");}
			$verseEnd = "<verse eID=\"$Book.$chapter.$verse\" />\n";
			
			my $osisID = "$Book.$chapter.$verse";
			if ($verse =~ /^(\d+)\-(\d+)$/) {
				my $v1 = $1;
				my $v2 = $2;
				my $sep = " ";
				for (my $i=$v1; $i<=$v2; $i++) {
					$osisID .= $sep."$Book.$chapter.$i";
					$sep = " ";
				}
			}
			$s .= "<verse sID=\"$Book.$chapter.$verse\" osisID=\"$osisID\" n=\"$verse\" />";
			next;
		}
		
		if ($_ =~ /<remove>(.*?)<\/remove>/) {
			&Log(($Chapter ? "WARN":"INFO").": Removed \"$_\" from \"$Book.$chapter.$verse\".\n");
			next;
		}
		
		if ($_ =~ /^(.*)(<title [^>]*>)(.*?)(<\/title>)(.*)$/) {
			my $tp = $1; my $ts = $2; my $t = $4; my $te = $5; my $tx = $6;
			my $drop = "$tp$tx";
			while ($t =~ s/(<[^>]*>)//) {$drop .= $1;}
			if ($drop ne "") {&Log("INFO: Dropping \"$drop\" from title.\n");}
			$_ = $ts.$t.$te; # this strips off illegal inline hi elements etc from titles.
			$s .= $verseEnd.$sectionEnd;
			$verseEnd = "";
			$sectionEnd = "";
			
			if ($chapter) {
				$sectionEnd = "</div>\n";
				$s .= "<div type=\"section\">\n";
			}
		}
		
		# final text modifications
		$_ =~ s/\s+/ /g;
		$_ =~ s/&nbsp;/ /g;
		$_ =~ s/xCHx/$chapter/g;
		$_ =~ s/xVSx/$verse/g;
		$_ =~ s/(<lb\s*\/>)/$1\n/g;

		# final output checking
		my $check = $_;
		while ($check =~ s/<([^\s>]+)[^>]*?type="(x\-[^"]*)"//) {
			$XTypesInText{$1."(".$2.")"}++;
			if (!exists($ReportXType{$1."(".$2.")"})) {
				&Log("INFO: First $1($2) found in $Book.$Chapter.$Verse\n");
			}
			$ReportXType{$1."(".$2.")"}++;
		}
		
		$s .= $_;
	}
	close(IBK);
	
	$s .= $verseEnd.$sectionEnd.$chapterEnd;
	$s .= "</div>\n";
	
	return $s;
}

sub getTagsOfClass($) {
	my $class = shift;
	foreach my $classTag (keys %SpanClassName) {if ($SpanClassName{$classTag} eq $class) {return $classTag;}}
	foreach my $classTag (keys %DivClassName) {if ($DivClassName{$classTag} eq $class) {return $classTag;}}
	&Log("ERROR: Unknown class tags for \"$class\".\n");
	return "";
}
	
sub Write($) {
	my $print = shift;
	print OUTF $print;
}
