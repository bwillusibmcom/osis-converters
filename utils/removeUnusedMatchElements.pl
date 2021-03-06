#!/usr/bin/perl

@ARGV[1] = 'none'; # no log file, just print to screen
use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/lib/common/bootstrap.pm"; &init(shift, shift);

my $dwfPath = "$INPD/CF_addDictLinks.xml";

my $alog = "$MOD_OUTDIR/LOG_sfm2osis_$MOD.txt";
my $msg = "Rerun sfm2osis on $MOD to create a new log file, and then rerun this script on $MOD.";
if (!open(OUT, $READLAYER, $alog)) {
  &Error("The log file $alog is required to run this script.", $msg, 1);
}

&Note("Reading log file:\n$alog");
my ($expected, $state, %unusedMatches);
while(<OUT>) {
  if ($_ =~ /^\S+ REPORT: Unused match elements in CF_addDictLinks\.xml: \((\d+) instances\)/) {
    $expected = $1;
    $state = 1;
    next;
  }
  if (!$state) {next;}
  if ($_ !~ /^(.*?)\s+(<match[^>]*>.*?<\/match>)\s*$/) {
    if ($state == 2) {$state = 0;}
    next;
  }
  $state = 2;
  my $osisRef = $1; my $m = $2;
  $osisRef = "$DICTMOD:$osisRef";
  if (!$unusedMatches{$osisRef}) {$unusedMatches{$osisRef} = ();}
  push(@{$unusedMatches{$osisRef}}, $m);
}
close(OUT);
if (!%unusedMatches) {&Log("\nThere are no unused match elements to remove. Exiting...\n"); exit;}

&Note("Modifying CF_addDictLinks.xml:\n$dwfPath\n");
my $count = 0;
my $xml = $XML_PARSER->parse_file($dwfPath);
my @matchElements = $XPC->findnodes("//dw:match", $xml);
foreach my $osisRef (sort keys %unusedMatches) {
  # Because of chars like ' xpath had trouble finding unusedMatch, but this munge does it:
  foreach my $unusedMatch (@{$unusedMatches{$osisRef}}) {
    my $ingoingCount = $count;
    foreach my $m (@matchElements) {
      if ($m eq 'unbound' || $m->toString() ne $unusedMatch) {next;}
      my $entry = @{$XPC->findnodes("./ancestor::dw:entry[1]", $m)}[0];
      if ($entry->getAttribute('osisRef') ne $osisRef) {next;}
      $m->unbindNode(); $count++; $m = 'unbound';
    }
    if ($ingoingCount == $count) {
      &Error("Match element \"$unusedMatch\" could not be located in CF_addDictLinks.xml.", $msg, 1);
    }
  }
}
if (!$count) {&Error("Did not locate any unused match elements.", $msg, 1);}
elsif ($count != $expected) {&Error("Did not find $expected unused match elements. Instead found $count", $msg, 1);}
else {&Note("All $expected unused match elements were located.");}

move($dwfPath, "$dwfPath.old");

&writeXMLFile($xml, $dwfPath);

&Report("Removed $count unused match elements from $dwfPath.");

1;
