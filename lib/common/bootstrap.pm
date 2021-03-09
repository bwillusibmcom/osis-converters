#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2018 John Austin (gpl.programs.info@gmail.com)
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

# This script might be run on Linux, MS-Windows, or MacOS operating systems.

# This is the starting point for all osis-converter scripts. Global 
# variables are initialized, the operating system is checked (and a Linux 
# VM is utilized with Vagrant if necessary) and finally init_linux_script() 
# is run to initialize the osis-converters script.

# Scripts are usually called the following way, having N replaced 
# by the calling script's proper sub-directory depth (and don't bother
# trying to shorten anything since 'require' only handles absolute 
# paths, and File::Spec->rel2abs(__FILE__) is the only way to get the 
# script's absolute path, and it must work on both host opsys and 
# Vagrant and the osis-converters installation directory name is 
# unknown):
# use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){N}$//; require "$SCRD/lib/common/bootstrap.pm"; &init(shift, shift);

use strict;
use Carp qw(longmess);
use Encode;
use File::Copy;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Spec;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

# These two globals must be initialized in the entry script:
our ($SCRIPT, $SCRD);

# DEBUG in config.conf is by set_system_globals()
#our $DEBUG = 1;

# Conversions to OSIS
# NOTE: 'osis' means sfm2osis unless the project has a source project, 
# in which case it means osis2osis.
our @CONV_OSIS = ('sfm2osis', 'osis2osis', 'osis');

# Conversions from OSIS to others
our @CONV_PUBS = ('sword', 'ebooks', 'gobible', 'html');

# Unsupported conversions of each module type
our %CONV_NOCANDO = (
  'bible'          => undef, 
  'childrensBible' => [ 'gobible' ],
  'dict'           => [ 'ebooks', 'gobible', 'html' ],
  'commentary'     => [ 'ebooks', 'gobible', 'html' ],
);

# Conversion dependencies
our %CONV_DEPENDENCIES = (
  # DICT are converted after MAIN, enabling DICT references to be checked
  'osis DICT'                     => [ 'osis MAIN' ],
  'osis MAIN(with-sourceProject)' => [ 'osis MAIN(sourceProject)', 
                                       'osis DICT(sourceProject)?' ],
  # don't need osis DICT(with-sourceProject) because of osis DICT => osis MAIN
  'sword MAIN'                    => [ 'osis MAIN' ],
  # sword DICT are converted after sword MAIN, enabling SWORD DICT references to be checked
  'sword DICT'                    => [ 'osis DICT', 
                                       'sword MAIN' ],
  'ebooks MAIN'                   => [ 'osis MAIN', 
                                       'osis DICT?' ],
  'html MAIN'                     => [ 'osis MAIN', 
                                       'osis DICT?' ],
  'gobible MAIN'                  => [ 'osis MAIN' ],
);

# Conversion output subdirectories (MOD will be replaced with $MOD)
our %CONV_OUTPUT_SUBDIR = (
  'osis2ebooks'  => 'eBook',
  'osis2html'    => 'html',
  'osis2gobible' => 'GoBible/MOD',
);

# Ouput files generated by each conversion (MOD will be replaced with $MOD)
our %CONV_OUTPUT_FILES = (
  'sfm2osis'     => [ 'MOD.xml' ],
  'osis2osis'    => [ 'MOD.xml' ],
  'osis2sword'   => [ 'MOD.zip',
                      'config.conf' ],
  'osis2ebooks'  => [ '*.epub', 
                      '*.azw3',
                      '*/*.epub', 
                      '*/*.azw3' ],
  'osis2html'    => [ '*/index.xhtml',
                      '*/*' ],
  'osis2gobible' => [ '*.jar', 
                      '*.jad' ],
);

# Types of publication output by each conversion: 'tran' is the entire
# Bible translation, 'subpub' is one of any SUB_PUBLICATIONS, 'tbook' is 
# a single Bible-book publication which is part of the 'tran' 
# publication and 'book' is a single Bible-book publication taken as a 
# part of the 'subpub'.
our %CONV_PUB_TYPES = (
  'sword'   => [ 'tran' ],
  'gobible' => [ 'tran' ], #  'SimpleChar', 'SizeLimited'
  'ebooks'  => [ 'tran', 'subpub', 'tbook', 'book' ],
  'html'    => [ 'tran', 'subpub', 'tbook', 'book' ],
);

{
my %h; 
foreach my $c (keys %CONV_PUB_TYPES) {map($h{$_}++, @{$CONV_PUB_TYPES{$c}});}
our @CONV_PUB_TYPES = (sort { length($b) <=> length($a) } keys %h);
}

# Conversion executable dependencies
our %CONV_BIN_DEPENDENCIES = (
  'all'          => [ 'SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2', 'JAVA' ],
  'sfm2osis'     => [ 'XMLLINT' ],
  'osis2osis'    => [ 'XMLLINT' ],
  'osis2sword'   => [ 'SWORD_BIN' ],
  'osis2ebooks'  => [ 'CALIBRE' ],
  'osis2gobible' => [ 'GO_BIBLE_CREATOR' ],
);

#  Host default paths to locally installed osis-converters executables
our %SYSTEM_DEFAULT_PATHS = (
  'MODULETOOLS_BIN'  => "~/.osis-converters/src/Module-tools/bin", 
  'GO_BIBLE_CREATOR' => "~/.osis-converters/GoBibleCreator.245", 
  'SWORD_BIN'        => "~/.osis-converters/src/sword/build/utilities",
);

# Compatibility tests for executable dependencies
our %CONV_BIN_TEST = (
  'SWORD_PERL'       => [ "perl -le 'use Sword; print \$Sword::SWORD_VERSION_STR'", 
                          "1.8.900" ], 
  'MODULETOOLS_BIN'  => [ "'MODULETOOLS_BIN/usfm2osis.py'",
                          "Revision: 491" ], 
  'XMLLINT'          => [ "xmllint --version",
                          "xmllint: using libxml" ],
  'SWORD_BIN'        => [ "'SWORD_BIN/osis2mod'",
                          "You are running osis2mod: \$Rev: 3431 \$" ],
  'CALIBRE'          => [ "ebook-convert --version",
                          "calibre 5" ],
  'GO_BIBLE_CREATOR' => [ "java -jar 'GO_BIBLE_CREATOR/GoBibleCreator.jar'", 
                          "Usage" ],
  # XSLT2 also requires that openjdk 10.0.1 is NOT being used 
  # because its Unicode character classes fail with saxonb-xslt.
  'XSLT2'            => [ 'saxonb-xslt',
                          "Saxon 9" ],
  'JAVA'             => [ 'java -version', 
                          "openjdk version \"10.", 1 ], # NOT openjdk 10.
);

require "$SCRD/lib/common/common_opsys.pm";
require "$SCRD/lib/common/help.pm";

# This sub will exit with 1 on error, or 0 on help or Vagrant-restart.
# Otherwise it will return if init completes.
sub init() {
  $SCRIPT =~ s/\\/\//g;
  $SCRD   =~ s/\\/\//g;
  
  our $SCRIPT_NAME = $SCRIPT;
  $SCRIPT_NAME =~ s/^.*\/([^\/]+)(\.[^\/\.]+)?$/$1/;
  
  # Global $forkScriptName will only be set when running in fork.pm, in  
  # which case SCRIPT_NAME is inherited for &conf() values to be correct.
  if (our $forkScriptName) {$SCRIPT_NAME = $forkScriptName;}
  
  our %ARGS = &arguments(@_);
  
  if (!%ARGS) {
    print &usage();
    exit 1;
  }
  elsif ($ARGS{'h'}) {
    print &usage();
    print "\n" . &help($SCRIPT_NAME);
    exit 0;
  }
  
  # If $LOGFILE is undef then a new log file named $SCRIPT_NAME will be 
  # started by init_linux_script().
  # If $LOGFILE is 'none' then no log file will be created but log info 
  # will be printed to the console.
  # If $LOGFILE is a file path then that file will be appended to.
  if (our $LOGFILE && $LOGFILE ne 'none') {
    if ($LOGFILE =~ /^\./) {
      $LOGFILE = File::Spec->rel2abs($LOGFILE);
    }
    $LOGFILE =~ s/\\/\//g;
  }
  
  if ($SCRIPT_NAME eq 'convert') {return;}
  
  my $error = &checkModuleDir(our $INPD);
  if ($error) {print $error."\n".&usage(); exit 1};
  
  # Set Perl globals associated with the project configuration
  &set_project_globals(our $INPD, our $LOGFILE);
  
  # Set Perl global variables defined in the [system] section of config.conf.
  &set_system_globals(our $MAINMOD);
  &set_system_default_paths();
  &DebugListVars("$SCRIPT_NAME globals", 'SCRD', 'SCRIPT', 
    'SCRIPT_NAME', 'MOD', 'MAINMOD', 'MAININPD', 'DICTMOD', 'DICTINPD', 
    our @OC_SYSTEM_PATH_CONFIGS, 'VAGRANT', 'NO_OUTPUT_DELETE');

  # Check that this is a provisioned Linux system (otherwise restart in 
  # Vagrant if possible, and then exit when Vagrant is finished).
  my $r = &init_opsys();
  if (!$r) {exit ($r == 0 ? 0:1);}
  
  # From here on out we're always running on a provisioned Linux system
  # (either natively or as a VM).
  require "$SCRD/lib/common/common.pm";
  
  if (our $OSIS2OSIS_PASS eq 'preinit') {return;}
  
  &init_linux_script();
  &DebugListVars("$SCRIPT_NAME globals", 'OUTDIR', 'MOD_OUTDIR', 
    'TMPDIR');
}

1;
