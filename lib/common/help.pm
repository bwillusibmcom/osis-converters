#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

our ($SCRIPT_NAME, @CONV_OSIS, @CONV_PUBS);

# Argument globals
our ($HELP, $INPD, $LOGFILE, $NO_ADDITIONAL, $CONVERSION, $MODRE, $MAXTHREADS, $SKIPRE);

# Each script may take 3 kinds of arguments: 
# 'switch' (boolean), 'option' (anything) and 'argument' (file|dir)
# Each argument is specified in %ARG by: 
#   [ <global-name>, <default-value>, <short-description>, <documentation> ]
# A short-description of (file|dir) triggers argPath() pre-processing.
# An option whose short-description is enlosed by square brackets has 
# an optional value. Optional option values cannot begin with (-|.|/) or 
# else they will be interpereted as a separate argument, and its also
# required that 'argument' type arguments remain file|dir, though there
# is still a small ambinguity since argPath() does not require a leading 
# './' in file names.
our %ARG = (

  'all' => { # Arguments available to all scripts:
    
    'option' => {
    
      'h' => [ 'HELP', undef, '[key]', 'Show '.$SCRIPT_NAME.' synopsis or show help for key and exit. Key can be any control file entry name, control file, or executable name ('.join(', ', @CONV_OTHER, @CONV_OSIS, @CONV_PUBS).').' ],
    },
    
    'argument' => {
    
      'first' => [ 'INPD', '.', 'dir', 'Path to an osis-converters project directory. Default is the working directory.' ],
    
      'second' => [ 'LOGFILE', undef, 'file', 'Log file path. Default is LOG_'.$SCRIPT_NAME.'.txt in the project\'s output directory.' ],
    },
  },

  'convert' => { # Arguments available to only the 'convert' script:
  
    'switch' => {
    
      'n' => [ 'NO_ADDITIONAL', 0, 'boolean', 'No additional modules will be run to meet any dependencies.' ], 
    },
    
    'argument' => {
    
      # this overrides the second argument of 'all' above
      'second' => [ 'LOGFILE', './LOG_convert.txt', 'file', 'Log file path. Default is ./LOG_convert.txt in the working directory.' ],
    },
    
    'option' => {
      
      'c' => [ 'CONVERSION', 'sfm2all', 'conv', 'Conversion(s) to run. Default is sfm2all. Others are: ' . join(', ', sort keys %{&getConversionArgs()}) . '.' ],
      
      'm' => [ 'MODRE', '.+', 'rx', 'Regex matching modules to run. Default is all.' ],

      't' => [ 'MAXTHREADS', &numCPUs(), 'N', 'Number of threads to use. Default is '.&numCPUs() . '.' ],

      'x' => [ 'SKIPRE', undef, 'rx', 'Regex matching modules to skip. Default is none.' ],
    },
  },
);

# osis-converters help documentation is stored in the following data structure:
# <script> => [ [ <heading>, [ [ sub-heading|para|list, value(s) ], ... ] ], ... ]
# where: list = [ 'list', [key-heading, description-heading], [ [ <name>, <description> ], ... ] ]
our %HELP = (

'convert' => [
  ['SYNOPSIS', [
    ['para', 'Convert Paratext [SFM](http://paratext.org/about/usfm#usfmDocumentation) to [OSIS](http://www.crosswire.org/osis/) XML, CrossWire [SWORD](http://www.crosswire.org/wiki/Main_Page) modules, [GoBible](http://www.crosswire.org/wiki/Projects:Go_Bible) Java-ME apps, html, epub and azw3 files.' ],
    ['para', 'Starting with [USFM](http://paratext.org/about/usfm#usfmDocumentation) files in a directory: `some-path/MODULE_NAME/sfm/`. At a Linux or Git Bash prompt run:
    \b\b `./bin/defaults ./some-path/MODULE_NAME`
    \b\b `./bin/convert ./some-path/MODULE_NAME`
    \b\b Will output:
    \b* One or two OSIS source files
    \b* Linked HTML
    \b* epub and azw3 eBook Bibles
    \b* A SWORD Bible module
    \b* A SWORD Dictionary module (if there are USFM glossary files)
    \b* GoBible Java-ME apps' ],
    ['sub-heading', 'DEFAULT CONTROL FILES' ],
    ['para', 'The entire conversion process is guided by control files. Default control files are located at PATH(SCRD/defaults) which may be overwritten by your own default files located at PATH(MAININPD/../defaults).' ],
    ['para', 'When the `defaults` program is run on a project, project control files will be created from default files which have been auto-customized according to the SFM found in the project. Project conversion is controlled by control files located in the project directory. A project is not ready to publish until there are no errors reported in LOG files, all warnings have been checked, and all desired material and meta-data has been added to the project.' ],
    ['sub-heading', 'LOG FILES' ],
    ['para', 'Log files report everything about the conversion process. They are written to the module\'s output directory and begin with `LOG_`. Each conversion step generates its own log file containing the following labels:' ],
    ['list', ['LABEL', 'DESCRIPTION'], [
      ['ERROR', 'Problems that must be fixed. A solution to the problem is also listed. Fix the first error, because this will often fix many following errors.' ],
      ['WARNING', 'Possible problems. Read the message and decide if anything needs to be done.' ],
      ['NOTE', 'Informative notes.' ],
      ['REPORT', 'Conversion reports. Helpful for comparing runs.' ],
    ]],
    ['sub-heading', 'CONVERT' ],
    ['para', 'The `convert` program will schedule and run conversions for one or more projects, with a single command. It takes care of scheduling and ordering any pre-requisite conversions insuring all publications are up-to-date. It is normally the last command run on a project before publication, while during development, running individual scripts may be more convenient. The following scripts are scheduled by `convert`, depending on its arguments and the projects chosen:' ],
    ['list', ['SCRIPT', 'DESCRIPTION'], &getList([@CONV_OSIS, @CONV_PUBS], [
      ['sfm2osis', 'Convert Paratext USFM and SFM to OSIS XML.' ],
      ['osis2osis', 'Convert an OSIS file from one script to another, or convert control files from one script to another.' ],
      ['osis2ebooks', 'Convert OSIS to eBook publications, including an entire translation eBook publication, sub-publication eBooks and single Bible book eBooks.' ],
      ['osis2html', 'Convert OSIS to HTML, including a table-of-contents and comprehensive navigational links.' ],
      ['osis2sword', 'Convert OSIS to CrossWire SWORD modules. A main module will be produced, as well as a linked dictionary module when applicable.' ],
      ['osis2gobible', 'Convert OSIS to Java-ME feature phone apps.' ],
    ], 1)],
    ['sub-heading', 'HELP' ],
    ['para', 'Run <script> -h to get help on any partiular script. Or run <any-script> -h <setting/file> to see help on any particular setting or control file.'],
  ]],
],

'defaults' => [
  ['SYNOPSIS', [
    ['para', 'For `defaults` help see `convert -h`' ]
  ]],
],

'sfm2osis' => [

  ['SYNOPSIS', [
    ['sub-heading', 'CONVERT PARATEXT FILES INTO OSIS XML' ],
    ['para', 'OSIS is an xml standard for encoding Bibles and related texts (see: [](http://crosswire.org/osis/)). The OSIS files generated by sfm2osis will include meta-data, explicit references, cross-references and textual information not present in the original Paratext Universal Standard Format Marker (USFM and SFM) sources. The resulting OSIS file is a more complete source text than the original Paratext files and is an excellent intermediate format, easily and reliably converted into any other format.' ],
    ['para', 'A project conversion creates a main OSIS file, which may contain a Bible, Children\'s Bible or commentary for instance. Any Paratext glossaries, maps and other reference materials are converted into a second OSIS file, whose contents may be referenced by the main OSIS file. These two conversions are treated as separate modules called MAINMOD and DICTMOD. If a project has a DICTMOD module, its module code is the MAINMOD code appended with \'DICT\', and it appears as a subdirectory of MAINMOD.' ],
    ['para', 'The SFM to OSIS conversion process is directed by the following control files:' ],
    ['list', ['FILE', 'DESCRIPTION'], &getList(\@CF_FILES, [
      ['config.conf', 'Configuration file with settings and meta-data for a project.' ],
      ['CF_sfm2osis.txt', 'Place and order converted SFM files within an OSIS file and record deviations from the standard markup and verse system.' ],
      ['CF_addScripRefLinks.txt', 'Control parsing of scripture references in the text and their conversion to working OSIS hyperlinks.' ],
      ['CF_addDictLinks.xml', 'Control parsing of reference material references in the text and their conversion to working OSIS hyperlinks.' ],
      ['CF_addFootnoteLinks.txt', 'Control parsing of footnote references from the text and their conversion to working OSIS hyperlinks.' ],
    ], 1)],
    ['para', 'Default control files are created by the \'defaults\' command. For help on an individual file or command use: ' . $SCRIPT_NAME . ' -h <key>' ],
    ['sub-heading', 'HOOKS' ],
    ['para', 'For situations when custom processing is required, hooks are provided for running custom Perl scripts and XSLT transforms. The Perl scripts should have two arguments: input OSIS file and output OSIS file, while XSLT transforms should utilze standard XML output. Use hooks only when EVAL_REGEX is insufficient, as hooks complicate project maintenance. Scripts with the following names in a module directory will be called at different points during the conversion to OSIS:' ],
    ['list', ['HOOK', 'WHEN CALLED'], [
      ['bootstrap.pl', 'Run by the sfm2osis and osis2osis scripts before conversion begins. It may only appear in the project (MAINMOD) directory, and it takes no arguments, but can be used to preprocess any project files etc.' ],
      ['preprocess.pl', 'Run after usfm2osis.py does the initial conversion to OSIS, before subsequent processing. Use EVAL_REGEX when preprocessing of SFM files would be sufficient.' ],
      ['preprocess.xsl', 'Same as preprocess.pl (after it, if it also exists).' ],
      ['postprocess.pl', 'Run after an OSIS file has been fully processed, but before OSIS validation and final checks.' ],
      ['postprocess.xsl', 'Same as postprocess.pl (after it, if it also exists).' ],
    ]],
  ]],
  
  ['config.conf', [
    ['para', ' Each project has a config.conf file located in its top directory. The configuration file contains conversion settings and meta-data for the project. A project consist of a single main module, and possibly a single dictionary module containing reference material. A config.conf file usually has multiple sections. The main section contains configuration settings applying to the entire project, while settings in other sections are effective in their particular context, overriding any matching settings of the main section. The \'system\' section is special because it contains global constants that are the same in any context. The following sections are recognized: '.join(', ', map("'$_'", @CONFIG_SECTIONS)). ' (MAINMOD is the project code and DICTMOD is the same project code suffixed with \'DICT\'). What follows are all settings available in the config.conf file. The letters in parenthesis indicate the following entry types:'],
    ['list', ['' ,''], 
    [
      ['(C)', 'Continuable from one line to the next using a backslash character.'],
      ['(L)', 'Localizable by appending underscore and language ISO code to the entry name.'],
      ['(P)', 'Path of a local file or directory.' ],
      ['(S)', 'System section only.'],
      ['(U)', 'A http(s) URL.' ],
      ['(W)', 'SWORD standard (see: [](https://wiki.crosswire.org/DevTools:conf_Files)).'],
    ]],
    ['list', ['ENTRY', 'DESCRIPTION'], &addConfigType(&getList(&configList(), [
      [ 'Abbreviation', 'A short localized name for the module.' ],
      [ 'About', 'Localized information about the module.' ],
      [ 'Description', 'A short localized description of the module.' ],
      [ 'KeySort', 'This entry enables localized list sorting by character collation. Square brackets are used to separate any arbitrary JDK 1.4 case sensitive regular expressions which are to be treated as single characters during the sort comparison. Also, a single set of curly brackets can be used around a regular expression which matches any characters/patterns that need to be ignored during the sort comparison. IMPORTANT: Any square or curly bracket within these regular expressions must have an ADDITIONAL \ before it.' ],
      [ 'AudioCode', 'A publication code for associated audio. Multiple modules having different scripts may reference the same audio.' ],
      [ 'AddScripRefLinks', 'Select whether to parse scripture references in the text and convert them to hyperlinks: (true | false | AUTO).' ],
      [ 'AddDictLinks' => 'Select whether to parse glossary references in the text and convert them to hyperlinks: (true | false | check | AUTO).' ],
      [ 'AddFootnoteLinks' => 'Select whether to parse footnote references in the text and convert them to hyperlinks: (true | false | AUTO).' ],
      [ 'AddCrossRefLinks' => 'Select whether to insert externally generated cross-reference notes into the text: (true | false |AUTO).' ],
      [ 'Versification' => 'The versification system of the project. All deviations from this verse system must be recorded in CF_sfm2osis.txt by VSYS instructions. Supported options are: '.join(', ', split(/\|/, $SWORD_VERSE_SYSTEMS)).'.' ],
      [ 'Encoding' => 'osis-converters only supports UTF-8 encoding.' ],
      [ 'TOC' => 'A number from 1 to 3 indicating which SFM tag to use for generating the Table Of Contents: \toc1, \toc2 or \toc3.' ],
      [ 'TitleCase' => 'A number from 0 to 2 selecting letter casing for the Table Of Contents: 0 is as-is, 1 is Like This, 2 is LIKE THIS.' ],
      [ 'TitleTOC' => 'A number from 1 to 3 indicating this SFM tag to use for generating the publication titles: \toc1, \toc2 or \toc3.' ],
      [ 'CreatePubTran' => 'Select whether to create a single ePublication containing everything in the OSIS file: (true | false | AUTO).'],
      [ 'CreatePubSubpub' => 'Select whether to create separate outputs for individual sub-publications within the OSIS file: (true | false | AUTO | <scope> | first | last).' ],
      [ 'CreatePubBook' => 'Select whether to create separate ePublications for individual Bible books within the OSIS file: (true | false | AUTO | <OSIS-book> | first | last).' ],
      [ 'CreateTypes' => 'Select which type, or types, of eBooks to create: (AUTO | epub | azw3 | fb2).' ],
      [ 'CombineGlossaries' => 'Set this to \'true\' to combine all glossaries into one, or false to keep them each as a separate glossary. \'AUTO\' let\'s osis-converters decide.' ],
      [ 'FullResourceURL' => 'Single Bible book eBooks often have links to other books. This URL is where the full publication may be found.' ],
      [ 'CustomBookOrder' => 'Set to true to allow Bible book order to remain as it appears in CF_sfm2osis.txt, rather than project versification order: (true | false).' ],
      [ 'ReorderGlossaryEntries' => 'Set to true and all glossaries will have their entries re-ordered according to KeySort, or else set to a regex to re-order only glossaries whose titles match: (true | <regex>).' ],
      [ 'CombinedGlossaryTitle' => 'A localized title for the combined glossary in the Table of Contents.' ],
      [ 'BookGroupTitle\w+' => 'A localized title to use for these book groups: '.&{sub {my $x=join(', ', @OSIS_GROUPS); $x=~s/_/ /g; return $x;}}().'. Example: `BookGroupNT=The New Testament` or BookGroupApocrypha=The Apocrypha`' ],
      [ 'BookGroupTitleOT' => 'A localized title for the New Testament in the Table of Contents.' ],
      [ 'BookGroupTitleNT' => 'A localized title for the Old Testament in the Table of Contents.' ],
      [ 'TranslationTitle' => 'A localized title for the entire translation.' ],
      [ 'IntroductionTitle' => 'A localized title for Bible book introductions.' ],
      [ 'TitleSubPublication\[\S+\]', 'A localized title for each sub-publication. A sub-publication is created when SFM files are placed within an sfm sub-directory. The name of the sub-directory must be the scope of the sub-publication, having spaces replaced by underscores.' ], 
      [ 'NormalizeUnicode' => 'Apply a Unicode normalization to all characters: (true | false | NFD | NFC | NFKD | NFKC | FCD).' ],
      [ 'Lang' => 'ISO language code and script code. Examples: tkm-Cyrl or tkm-Latn' ],
      [ 'ARG_\w+' => 'Config settings for undocumented fine control.' ],
      [ 'GlossaryNavmenuLink\[[1-9]\]' => 'Specify custom DICTMOD module navigation links.' ], 
      [ 'History_[\d\.]+' => 'Each version of released publications should have one of these entries describing what is new that version.' ],              
      [ 'Version', 'The version of the publication being produced. There should be a corresponding `History_<version>` entry stating what is new in this version.' ],
      [ 'COVERS', 'Location where cover images can be found. Cover images should be named: `<project-code>_<scope>.jpg` and will automatically be included in the appropriate OSIS files.' ],
      [ 'Copyright', 'Contains the copyright notice for the work, including the year of copyright and the owner of the copyright.' ],
      [ 'CopyrightContactAddress', 'Address of the copyright holder.' ],
      [ 'CopyrightContactEmail', 'Email address of the copyright holder.' ],
      [ 'CopyrightContactNotes', 'Notes concerning copyright holder contact.' ],
      [ 'CopyrightContactName', 'Name for copyright contact.' ],
      [ 'CopyrightDate', 'Four digit copyright year.' ],
      [ 'CopyrightHolder', 'Name of the copyright holder.' ],
      [ 'CopyrightNotes', 'Notes from the copyright holder.' ],
      [ 'DEBUG', 'Set to enable debugging log output.' ],
      [ 'Direction', 'LtoR (Left to Right), RtoL (Right to Left) or BiDi (Bidirectional)' ],
      [ 'DistributionLicense', 'see: [](https://wiki.crosswire.org/DevTools:conf_Files)' ],
      [ 'DistributionNotes', 'Additional distribution notes.' ],
      [ 'EBOOKS', 'Location where eBooks are published.' ],
      [ 'FONTS', 'Location where specified fonts are located for copying/download.' ],
      [ 'NO_FORKS', 'Set to disable the multi-thread fork feature. Doing so may increase conversion time.' ],
      [ 'OUTDIR', 'Location where output files should be written. OSIS, LOG and publication files will appear in a module subdirectory here. Default is an `output` subdirectory within the module.' ],
      [ 'Obsoletes', 'see: [](https://wiki.crosswire.org/DevTools:conf_Files)' ],
      [ 'REPOSITORY', 'Location where SWORD modules are published.' ],
      [ 'ShortCopyright', 'Short copyright string.' ],
      [ 'ShortPromo', 'A link to the home page for the module, perhaps with an encouragement to visit the site.' ],
      [ 'TextSource', 'Indicates a name or URL for the source of the text.' ],
    ]))],
  ]],
  
  ['CF_sfm2osis.txt', [
    ['para', 'This control file is required for all sfm2osis conversions. It should be located in each module\'s directory (both MAINMOD and DICTMOD if there is one). It controls what material appears in each module\'s OSIS file and in what order, and is used to apply Perl regular expressions for making changes to SFM files before conversion. ' ],
    ['para', 'Its other purpose is to describe deviations from the standard versification system that Bible translators made during translation. Translators nearly always deviate from the standard versification system in some way. It is imperative these deviations be recorded so references from external documents may be properly resolved, and parallel rendering together with other texts can be accomplished. Each verse must be identified according to the project\'s strictly defined standard versification scheme. The commands to accomplish this all begin with VSYS. Their proper use results in OSIS files which contain both a rendering of the translator\'s custom versification scheme and a rendering of the standard versification scheme. OSIS files can then be rendered in either scheme using an XSLT stylesheet. ' ],
    ['para', 'NOTES: Each VSYS instruction is evaluated in verse system order regardless of their order in the control file. A verse may be effected by multiple VSYS instructions. VSYS operations on entire chapters are not supported except for VSYS_EXTRA chapters at the end of a book (such as Psalm 151 of Synodal).'],
    ['list', ['COMMAND', 'DESCRIPTION'], &getList([@CF_SFM2OSIS, @VSYS_INSTRUCTIONS], [
      ['EVAL_REGEX', 'Any perl regular expression to be applied to source SFM files before conversion. An EVAL_REGEX instruction is only effective for the RUN statements which come after it. The EVAL_REGEX command may be suffixed with a label or path in parenthesis and must be followed by a colon. A label might make organizing various kinds of changes easier, while a file path makes the EVAL_REGEX effective on only a single file. If an EVAL_REGEX has no regular expression, all previous EVAL_REGEX commands sharing the same label are canceled. 
      \bExamples: 
      \b`EVAL_REGEX: s/^search/replace/gm`
      \b`EVAL_REGEX(myfix): s/^search/replace/gm` 
      \b`EVAL_REGEX(./sfm/file/path.sfm): s/^search/replace/gm`' ],
      ['RUN', 'Causes an SFM file to be converted and appended to the module\'s OSIS file. Each RUN must be followed by a colon and the file path of an SFM file to convert. RUN can be used more than once on the same file. IMPORTANT: Bible books are normally re-ordered according to the project\'s versification system. To maintain RUN Bible book order, `CustomBookOrder` must be set to true in config.conf.' ],
      ['SPECIAL_CAPITALS', 'Was used to enforce non-standard capitalizations. It should only be used if absolutely necessary, since Perl Unicode is now good at doing the right thing on its own. It is better to use EVAL_REGEX to replace offending characters with the proper Unicode character. For example: `SPECIAL_CAPITALS:i->İ ı->I`.' ],
      ['PUNC_AS_LETTER', 'Was used to treat a punctuation character as a letter for pattern matches. It is far better to use `EVAL_REGEX` to replace a punctuation character with the proper Unicode character, which will automatically be treated properly.' ],
      ['VSYS_MISSING', 'Specifies that this translation does not include a range of verses of the standard versification scheme. This instruction takes the form:
      \b\b`VSYS_MISSING: Josh.24.34.36`
      \bMeaning that Joshua 24:34-36 of the standard versification scheme has not been included in the custom scheme. When the OSIS file is rendered as the standard versification scheme, the preceeding verse\'s osisID will be modified to include the missing range. But any externally supplied cross-references that refer to the missing verses will be removed. If there are verses already sharing the verse numbers of the missing verses, then the standard versification rendering will renumber them and all following verses upward by the number of missing verses, and alternate verse numbers will be appended displaying the original verse numbers. References to affected verses will be tagged so as to render correctly in either the standard or custom versification scheme. An entire missing chapter is not supported unless it is the last chapter in the book.' ],
      ['VSYS_EXTRA', 'Used when translators inserted a range of verses that are not part of the project\'s versification scheme. This instruction takes the form:
      \b\b `VSYS_EXTRA: Prov.18.8 <- Synodal:Prov.18.8`
      \b The left side is a verse range specifying the extra verses in the custom verse scheme, and the right side range is an optional universal address for those extra verses. The universal address is used to record where the extra verses originated from. When the OSIS file is rendered in the standard versification scheme, the additional verses will become alternate verses appended to the preceding verse, and if there are verses following the extra verses, they will be renumbered downward by the number of extra verses, and alternate verse numbers will be appended displaying the custom verse numbers. References to affected verses will be tagged so as to render correctly in either the standard or custom versification scheme. The extra verse range may be an entire chapter if it occurs at the end of a book (such as Psalm 151). When rendered in the standard versification scheme, an alternate chapter number will then be inserted and the entire extra chapter will be appended to the last verse of the previous chapter.' ],
      ['VSYS_FROM_TO', 'This is usually not the right instruction to use; it is used internally as part of other instructions. It does not effect any verse or alternate verse markup. It could be used if a verse is marked in the text but is left empty, while there is a footnote about it in the previous verse (but see `VSYS_MISSING_FN` which is the more common case). '], 
      ['VSYS_EMPTY', 'Like `VSYS_MISSING`, but is only to be used if regular empty verse markers are included in the text. This instruction will only remove external scripture cross-references to the removed verses.' ],
      ['VSYS_MOVED', 'Used when translators moved a range of verses from the expected location within the project\'s versification scheme to another location. This instruction can have several forms:
      \b\b `VSYS_MOVED: Rom.14.24.26 -> Rom.16.25.27`
      \b Indicates the range of verses given on the left was moved from its expected location to a custom location given on the right. Rom.16.25.27 is Romans 16:25-27. Both ranges must cover the same number of verses. Either or both ranges may end with the keyword `PART` in place of the range\'s last verse, indicating only part of the verse was moved. All references to affected verses will be tagged so as to be correct in both the standard and the custom versification scheme. When verses are moved within the same book, the verses will be fit into the standard verse scheme. When verses are moved from one book to another, the effected verses will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as standard, or custom versification scheme, the verses will appear in one location or the other.
      \b\b `VSYS_MOVED: Tob -> Apocrypha[Tob]`
      \b Indicates the entire book on the left was moved from its expected location to a custom book-group[book] given on the right. See `%OSIS_GROUP` for supported book-groups and books. An index number may be used on the right side in place of the book name. The book will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as the standard, or custom versification scheme, the book will appear in one location or the other.
      \b\b `VSYS_MOVED: Apocrypha -> bookGroup[2]`
      \bIndicates the entire book-group on the left was moved from its expected location to a custom book-group index on the right. See `%OSIS_GROUP` for supported book-groups. The book-group will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as the standard, or custom versification scheme, the book-group will appear in one location or the other.' ],
      ['VSYS_MOVED_ALT', 'Like `VSYS_MOVED` but this should be used when alternate verse markup like `\va 2\va*` has been used by the translators for the verse numbers of the moved verses (rather than regular verse markers which is the more common case). If both regular verse markers (showing the source system verse number) and alternate verse numbers (showing the fixed system verse numbers) have been used, then `VSYS_MOVED` should be used. This instruction will not change the OSIS markup of alternate verses. '],
      ['VSYS_MISSING_FN', 'Like `VSYS_MISSING` but is only to be used if a footnote was included in the verse before the missing verses which gives the reason for the verses being missing. This instruction will simply link the verse having the footnote together with the missing verse.' ],
      ['VSYS_CHAPTER_SPLIT_AT', 'Used when the translators split a chapter of the project\'s versification scheme into two chapters. This instruction takes the form:
      \b\b `VSYS_CHAPTER_SPLIT_AT: Joel.2.28`
      \b When the OSIS file is rendered as the standard versification scheme, verses from the split onward will be appended to the end of the previous verse and given alternate chapter:verse designations. Verses of any following chapters will also be given alternate chapter:verse designations. All references to affected verses will be tagged so as to be correct in both the standard and the custom versification scheme.' ],
    ])],
  ]],
  
  ['CF_addScripRefLinks.txt', [
    ['para', 'Paratext publications typically contain localized scripture references found in cross-reference notes, footnotes, introductions and other reference material. These references are an invaluable study aid. However, they often are unable to function as hyperlinks until converted from localized textual references to strictly standardized references. This control file tells the parser how to search the text for textual scripture references, and how to translate them into standardized hyperlinks.' ],
    ['para', 'Some descriptions below refer to extended references. An extended reference is composed of a series of individual scripture references which together form a single contextual sentence. An example of an extended reference is: See also Gen 4:4-6, verses 10-14 and chapter 6. The parser searches the text for extended references, and then parses each reference individually, in order, remembering the book and chapter context of the previous reference.' ],
    ['list', ['SETTING', 'DESCRIPTION'], &getList([@CF_ADDSCRIPREFLINKS], [
      ['CONTEXT_BOOK', 'Textual references do not always include the book being referred to. Then the target book must be discovered from the context of the reference. Where the automated context search fails to discover the correct book, the `CONTEXT_BOOK` setting should be used. It takes the following form:
      \b\b`CONTEXT_BOOK: Gen if-xpath ancestor::div[1]`
      \bWhere Gen is any osis book abbreviation, `if-xpath` is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then the given book will be used as the context book for that reference.' ],
      ['WORK_PREFIX', 'Sometimes textual references are to another work. For instance a Children\'s Bible may contain references to an actual Bible translation. To change the work to which references apply, the WORK_PREFIX setting should be used. It takes the following form:
      \b\b`WORK_PREFIX: LEZ if-xpath //@osisIDWork=\'LEZCB\'`
      \bWhere LEZ is any project code to be referenced, `if-xpath` is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then LEZ will be used as the work prefix for that reference.' ],
      ['SKIP_XPATH', 'When a section or category of text should be skipped by the parser SKIP_XPATH can be used. It takes the following form:
      \b\b`SKIP_XPATH: ancestor::div[@type=\'introduction\']`
      \bThe given xpath expression will be evaluated for every suspected textual scripture reference, and if it evaluates as true, it will be left alone.' ],
      ['ONLY_XPATH', 'Similar to SKIP_XPATH but when used used, all suspected textual references will be skipped unless the given xpath expression evaluates as true.' ],
      ['CHAPTER_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "chapter". Example:
      \b`CHAPTER_TERMS:(psalm|chap)`' ],
      ['CURRENT_CHAPTER_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "the current chapter". Example:
      \b`CURRENT_CHAPTER_TERMS:(this chapter)`' ],
      ['CURRENT_BOOK_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "the current book". Example:
      \b`CURRENT_BOOK_TERMS:(this book)`' ],
      ['VERSE_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "verse". Example:
      \b`VERSE_TERMS:(verse)`' ],
      ['COMMON_REF_TERMS', 'A Perl regular expression matching phrases or characters which should be ignored within an extended textual reference. When an error is generated because an extended textual reference was incompletely parsed, parsing may have been terminated by a word or character which should instead be ignored. Adding it to COMMON_REF_TERMS may allow the textual reference to parse completely. Example:
      \b`COMMON_REF_TERMS:(but not|a|b)`' ],
      ['PREFIXES', 'A Perl regular expression matching characters or language prefixes that may appear before other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word they prefix but are otherwise ignored. Example:
      \b`PREFIXES:(\(|")`' ],
      ['REF_END_TERMS', 'A Perl regular expression matching characters that are required to end an extended textual reference. Example:
      \b`REF_END_TERMS:(\.|")`' ],
      ['SUFFIXES', 'A Perl regular expression matching characters or language suffixes that may appear after other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word that precedes them but are otherwise ignored. Some languages have many grammatical suffixes and including them in SUFFIXES can improve the parsability of such langauges. Example:
      \b`SUFFIXES:(\)|s)`' ],
      ['SEPARATOR_TERMS', 'A Perl regular expression matching words or characters that are to be understood as separating individual references within an extended reference. Example:
      \b`SEPARATOR_TERMS:(also|and|or|,)`' ],
      ['CHAPTER_TO_VERSE_TERMS', 'A Perl regular expression matching characters that are used to separate the chapter from the verse in textual references. Example:
      \b`CHAPTER_TO_VERSE_TERMS:(:)`' ],
      ['CONTINUATION_TERMS', 'A Perl regular expression matching characters that are used to indicate a chapter or verse range. Example:
      \b`CONTINUATION_TERMS:(to|-)`' ],
      ['FIX', 'If the parser fails to properly convert any particular textual reference, FIX can be used to correct or skip it. It has the following form:
      \b\b`FIX: Gen.1.5 Linking: "7:1-8" = "<r Gen.7.1>7:1</r><r Gen.8>-8</r>`"
      \bAfter FIX follows the line from the log file where the extended reference of concern was logged. Replace everything after the equal sign with a shorthand for the fix with the entire fix enclosed by double quotes. Or, remove everything after the equal sign to skip the extended reference entirely. The fix shorthand includes each reference enclosed in r tags with the correct osisID.' ],
      ['<osis-abbreviation>', 'To assign a localized book name or abbreviation to the corresponding osis book abbreviation, use the following form:
      \b\bGen = The book of Genesis
      \bThe osis abbreviation on the left of the equal sign may appear on multiple lines. Each line assigns a localized name or abbreviation on the right to its osis abbreviation on the left. Names on the right are not Perl regular expressions, but they are case insensitive. Listed book names do not need to include any prefixes of `PREFIXES` or suffixes of `SUFFIXES` for the book names to be parsed correctly.' ],
    ])],
  ]],
  
  ['CF_addFootnoteLinks.txt', [
    ['para', 'When translators include study notes that reference other study notes, this command file can be used to parse references to footnotes and convert them into working hyperlinks. This conversion requires that CF_addScripRefLinks.txt is also performed.' ],
    ['list', ['SETTING', 'DESCRIPTION'], &getList([@CF_ADDFOOTNOTELINKS], [
      ['ORDINAL_TERMS', 'A list of ordinal:term pairs where ordinal is ( \d | prev | next | last ) and term is a localization of that ordinal to be searched for in the text. Example:
      \b`ORDINAL_TERMS:(1:first|2:second|prev:preceding)`' ],
      ['FIX', 'Used to fix a problematic reference. Each instance has the form:
      \b\b`LOCATION=\'book.ch.vs\' AT=\'ref-text\' and REPLACEMENT=\'exact-replacement\'`
      \bWhere `LOCATION` is the context of the fix, AT is the text to be fixed, and `REPLACEMENT` is the fix. If `REPLACEMENT` is \'SKIP\', there will be no footnote reference link.' ],
      ['SKIP_XPATH', 'See CF_addScripRefLinks.txt'],
      ['ONLY_XPATH', 'See CF_addScripRefLinks.txt'],
      ['FOOTNOTE_TERMS', 'A Perl regular expression matching terms that are to be converted into footnote links.'],
      ['COMMON_TERMS', 'See CF_addScripRefLinks.txt'], 
      ['CURRENT_VERSE_TERMS', 'See CF_addScripRefLinks.txt'],
      ['SUFFIXES', 'See CF_addScripRefLinks.txt'],
      ['STOP_REFERENCE', 'A Perl regular expression matching where scripture references stop and footnote references begin. This is only needed if an error is generated because the parser cannot find the transition. For instance: \'See verses 16:1-5 and 16:14 footnotes\' might require the regular expression: `verses[\s\d:-]+and` to delineate between the scripture and footnote references.'],
    ])],
  ]],
  
  ['CF_addDictLinks.xml', [
    ['para', 'Many Bible translations are accompanied by reference materials, such as glossaries, maps and tables. Hyperlinks to this material, and between these materials, are helpful study aids. Translators may mark the words or phrases which reference a particular glossary entry or map. But often only the location of a reference is marked, while the exact target of the reference is not. Sometimes no references are marked, even though they exist throughout the translation. This command file\'s purpose is to convert all these kinds of textual references into strictly standardized working hyperlinks. '],
    ['para', 'IMPORTANT: For case insensitive matches to work, ALL match text MUST be surrounded by the \Q...\E quote operators. If a match is failing, consider this first. This is not a normal Perl rule, but is required because Perl doesn\'t properly handle case for some languages. Match patterns can be any Perl regex, but only the \'i\' flag is supported. The last matching parenthetical group will become the text of the link, unless there is a group named \'link\' (using Perl\'s ?\'link\' notation) in which case that group will become the text of the link.' ],
    ['para', 'References that are marked by translators are called explicit references. If the target of an explicit reference cannot be determined, a conversion error is logged. Marked and unmarked references are parsed from the text using the match elements of the CF_addDictLinks.xml file. Element attributes in this XML file are used to control where and how the match elements are to be used. Letters in parentheses indicate the following attribute value types:' ],
    ['list', ['' ,''], 
    [
      ['(A)', 'value is the accumulation of its own value and ancestor values. But a positive attribute (one whose name doesn\'t begin with \'not\') cancels negative attribute ancestors.' ],
      ['(B)', 'true or false' ],
      ['(C)', 'one or more space separated osisRef values OR one or more comma separated Paratext references.' ],
      ['(R)', 'one or more space separated osisRef values' ],
      ['(X)', 'xpath expression' ],
    ]],
    ['list', ['ATTRIBUTE', 'DESCRIPTION'], &addAttributeType(&getList([ keys %{$CF_ADDDICTLINKS{'attributes'}} ], [
      ['osisRef', 'This attribute is only allowed on entry elements and is required. It contains a space separated list of work prefixed osisRef values, which are the target(s) of an entry\'s links.' ],
      ['noOutboundLinks', 'This attribute is only allowed on entry elements. It prohibits the parser from parsing the entry\'s targets for links.' ],
      ['multiple', 'If false, only the first match candidate for an entry will be linked per chapter or keyword. If `match`, the first match condidate per match element may be linked per chapter or keyword. If true, there are no such limitations.' ],
      ['onlyExplicit', 'If true or else contains a context matching the text node, then match elements will only apply if that node is an explicitly marked reference.' ],
      ['notExplicit', 'If true or else contains a context matching the text node, then match elements will only apply if that node is not an explicitly marked reference.' ],
      ['context', 'If it contains a context matching the text node, match elements will be applied.' ],
      ['notContext', 'If it contains a context matching the text node, match elements will be not applied.' ],
      ['XPATH', 'If the xpath expression evaluates as true for the text node, then match elements will be applied.' ],
      ['notXPATH', 'If the xpath expression evaluates as true for the text node, then match elements will not be applied.' ],
      ['dontLink', 'If true, then match elements are used to undo any reference link.' ],
      ['onlyOldTestament', 'If true, text nodes which are not in the Old Testament, will not have match elements applied.' ],
      ['onlyNewTestament', 'If true, text nodes which are not in the New Testament, will not have match elements applied.' ],
    ]))],
    ['list', ['ELEMENT', 'DESCRIPTION'], &getList($CF_ADDDICTLINKS{'elements'}, [
      ['addDictLinks', 'The root element.' ],
      ['div', 'Used to organize groups of entries' ],
      ['entry', 'Text matching any child match element will be linked with the osisRef attribute value.' ],
      ['name', 'The name of the parent entry.' ],
      ['match', 'Contains a Perl regular expression used to search text for links to the parent entry. For a match element to create a link, all its attributes and those of ancestor elements must be properly satisfied.' ],
    ])],
  ]],
],

'osis2osis' => [

  ['SYNOPSIS', [
    ['para', 'When a translation is to be converted into multiple scripts, osis2osis can be used to simplify the work of conversion. The osis2osis program is flexible and controlled by CF_osis2osis.txt. Source script SFM may be converted using sfm2osis, then the resulting OSIS file and the source script config.conf can be converted directly to other scripts using osis2osis. The osis2osis script can also be used to convert just control files from one script to another, allowing sfm2osis create the OSIS file. This is useful when translators provide multiple sets of source files of different scripts, and control files alone need to be converted from one script to another. ' ],
  ]],
  
  ['CF_osis2osis.txt', [
    ['para', 'The following settings are supported:' ],
    ['list', ['SETTING', 'DESCRIPTION'], &getList(\@CF_OSIS2OSIS, [
      ['SET_CONFIG_<entry>', 'Set the value of a config entry. The config.conf file itself should be converted using `CC: config.conf`. An entry for a particular section can be set using `SET_CONFIG_<section>+<entry>: <value>`' ], 
      ['SKIP_NODES_MATCHING', 'Don\'t convert the text of nodes selected by an xpath expression.' ], 
      ['SKIP_STRINGS_MATCHING', 'Don\'t convert the text of strings matching a Perl regular expression.' ],
      ['CC', 'Convert control files using the previously selected MODE. Each control file has a `CC: <file>` line, and each path is relative to it\'s main project directory.' ],
      ['CCOSIS', 'Convert an OSIS file using the previously selected MODE. Examples: `CCOSIS: <code>` or `CCOSIS: <code>DICT`' ],
      ['SET_sourceProject', 'A required entry specifying the source project to convert from.' ],
      ['SET_MODE_CCTable', 'Use a CC table do the conversion. CC tables are no longer supported by SIL. Use SET_MODE_Script instead.' ],
      ['SET_MODE_Script', 'Use the given script to do the conversion. The script path is relative to the project directory. The script needs to take two arguments: input-file and output-file' ],
      ['SET_MODE_Transcode', 'Use the function `transcode(<string>)` defined in the Perl script whose path is given. Example: `SET_MODE_Transcode: script.pl`' ], 
      ['SET_MODE_Copy', 'Copy the listed file or file glob from the source project to the current project. Files could be images, css, etc. Paths are relative to their project main directory.' ],
    ])],
  ]],
],

'osis2ebooks' => [

  ['SYNOPSIS', [
    ['para', 'Create epub and azw3 eBooks from OSIS files. Once Paratext SFM files have been converted to OSIS XML, eBooks can be created from the OSIS sources. Both the MAINMOD and DICTMOD OSIS files are integrated into an eBook publication. If there are sub-publications as part of the translation, eBooks for each of these will also be created. Finally a separate eBook for each Bible book is created.' ],
    ['para', 'The following `config.conf` entries control eBook production:' ],
    ['list', ['ENTRY', 'DESCRIPTION'], [
      ['CreateTypes', 'HELP(sfm2osis;config.conf;CreateTypes)' ],
      ['CreatePubTran', 'HELP(sfm2osis;config.conf;CreatePubTran)' ],
      ['CreatePubSubpub', 'HELP(sfm2osis;config.conf;CreatePubSubpub)' ],
      ['CreatePubBook', 'HELP(sfm2osis;config.conf;CreatePubBook)' ],
    ]],
  ]],
  
],

'osis2html' => [

  ['SYNOPSIS', [
    ['para', 'Create HTML from OSIS files. Once Paratext SFM files have been converted to OSIS XML, HTML can be created from the OSIS sources. Both the MAINMOD and DICTMOD OSIS files are integrated together with a table-of-contents and comprehensive navigational links.' ],
  ]],
  
],

'osis2sword' => [

  ['SYNOPSIS', [
    ['para', 'Create CrossWire SWORD modules from OSIS files. Once Paratext files have been converted to OSIS XML, CrossWire SWORD modules may be created. A Bible, GenBook or Commentary SWORD module will be generated from the MAINMOD OSIS file. If there is a DICTMOD OSIS file it will be converted to a dictionary SWORD module. The two SWORD modules will be integrated together by a table-of-contents, glossary and navigational links that will appear in each Bible book introduction and dictionary keyword. '],
  ]],
  
],

'osis2gobible' => [

  ['SYNOPSIS', [
    ['para', 'Create Java-ME JAR apps from OSIS files. Once Paratext files have been converted to OSIS XML, osis2gobible utilizes Go Bible Creator to produce these apps for feature phones. '],
    ['para', 'Default control files will be copied from the defaults directory (see `convert -h` for their locations). This includes the Go Bible Creator user interface localization file and the app icon. These files can be customized per project, by placing them in PATH(MAINMOD/gobible) directory. Or customized for a group of projects, by placing them in PATH(MAINMOD/../defaults/gobible).' ],
    ['para', 'IMPORTANT: The collections.txt default file is just a template and should not be customized. The actual collections.txt control file is auto-generated at runtime.' ],
  ]],
  
],

'CrossWire' => [

  ['Non-standard config.conf entries', [
    ['para', 'The following are SWORD config.conf entries which are not part of the CrossWire standard.' ],
    ['list', ['ENRTY', 'DESCRIPTION'], &getList(\@SWORD_OC_CONFIGS, [
      ['KeySort', 'HELP(sfm2osis;config.conf;KeySort)' ],
      ['AudioCode', 'HELP(sfm2osis;config.conf;AudioCode)' ],
      ['Scope', 'Used to describe a Bible module\'s contents. It follows osisRef rules including the use of the \'-\' range character. Note that Scope range interpretation requires knowledge of the versification system. The Scope entry allows determination of a Bible module\'s contents before it is loaded.' ],
    ])],
  ]],
  ['Comparison of OSIS files to CrossWire OSIS', [
    ['para', 'Osis-converters utilizes CrossWire\'s [usfm2osis.py](https://github.com/refdoc/Module-tools) script for the initial USFM to OSIS conversion. The OSIS subType attribute is used to pass optional CSS classes to front-ends. '],
  ]],
  
],

);

# Search for a particular key in %HELP and return all matching values as 
# a formatted string. Key can be a script name, a heading, or the entry 
# part of any 'list'. Or, it can be a combination of each, separated by 
# semi-colons as: <script>;<heading>;<entry> where they must be included 
# in that order but entry is optional, and also 'all' can be used in 
# place of any particular value. If no key is provided, the entire help
# contents will be dumped.
# If $showcmd is set, a command which may be used to generate the help 
# message is also shown.
# If $errorOnFail is set and $lookup is not found, an error is thrown.
sub help {
  my $lookup = shift;
  my $showcmd = shift;
  my $errorOnFail = shift;
  my $returnListDescription = shift;
  
  if ($showcmd) {$showcmd = "$SCRIPT_NAME -h $lookup\n\n";}
  
  # Dump entire help documentation
  if (!$lookup) {
    %check = map {$_} keys %HELP;
    my $r;
    foreach my $s (@CONV_OTHER, @CONV_OSIS, @CONV_PUBS, 'CrossWire') {
      delete($check{$s});
      if ($HELP{$s}[0][1][0][1] =~ /^For \S+ help see/) {next;}
      my $t = ( $s eq 'convert' ? 'osis-converters' : $s );
      $r .= &format($t, 'title') . &help($s, undef, 1);
    }
    if (keys %check) {
      &ErrorBug("Extra help:" . join(', ', keys %check), 1);
    }
    
    return ($showcmd ? $showcmd : '') . $r;
  }
  
  # Find lookup's script/heading if given
  my ($script, $heading);
  my $key = $lookup;
  if ($lookup =~ /;/) {
    my @parts = split(/\s*;\s*/, $lookup);
    $key = @parts[$#parts];
    my @p = (\$script, \$heading);
    for (my $x=0; $x <= 1; $x++) {
      if (@parts[$x] && @parts[$x] ne 'all') {
        my $ptr = @p[$x];
        $$ptr = @parts[$x];
      }
    }
  }
 
  # Help for a given script
  if (!$script && !$heading && ref($HELP{$key})) {
    my $r; foreach (@{$HELP{$key}}) {$r .= &helpHeading($_);}
    return ($showcmd ? $showcmd : '') . $r;
  }
  
  # Help for any lookup combination
  my $r;
  my @scripts = ($script ? $script : sort keys %HELP);
  foreach my $s (@scripts) {
    foreach my $headP (@{$HELP{$s}}) {
      if ($heading && $headP->[0] !~ /^$heading$/i) {next;}
      if ($headP->[0] =~ /^$key$/i) {
        $r .= &helpHeading($headP);
        next;
      }
      foreach my $listP (@{$headP->[1]}) {
        if ($listP->[0] ne 'list') {next;}
        foreach my $rowP (@{$listP->[2]}) {
          if ($rowP->[0] =~ /^$key$/i) {
            $r .= &format($headP->[0], 'heading') . 
              &helpList($listP->[1], [[ $rowP->[0], $rowP->[1] ]]);
            if ($returnListDescription && $rowP->[1] !~ /HELP/) {
              return $rowP->[1];
            }
          }
        }
      }
    }
  }
  
  if (!$r) {
    $r = "No help available for '$lookup'.\n";
    if ($errorOnFail) {&Error($r);}
  }
  
  return ($showcmd ? $showcmd : '') . $r;
}

sub helpHeading {
  my $headingAP = shift;
  
  my $r = &format($headingAP->[0], 'heading');
    
  foreach my $s (@{$headingAP->[1]}) {
    if ($s->[0] eq 'list') {
      $r .= &helpList($s->[1], $s->[2]);
    }
    else {
      $r .= &format($s->[1], $s->[0]);
    }
  }
  
  return $r;
}

sub helpList {
  my $listheadAP = shift;
  my $listAP = shift;
  
  my $sep = ' -';
 
  # find column 1 width
  my $left = 0;
  foreach my $row (@{$listAP}) {
    if ($left < length($row->[0])) {$left = length($row->[0]);}
  }
  
  my $r = &helpListRow( $listheadAP->[0], 
                        $listheadAP->[1], 
                        $left, 
                        ' ' x length($sep));
                    
  foreach my $row (@{$listAP}) {
    $r .= &helpListRow($row->[0], $row->[1], $left, $sep) . "\n";
  }
  $r .= "\n";
  
  return $r;
}

sub helpListRow {
  my $key = shift;
  my $description = shift;
  my $left = shift;
  my $sep = shift;
  
  if (!$key && !$description) {return '';}
  
  if ($left > 28) {$left = 28;}

  return sprintf("%-${left}s%s%s", 
    $key,
    ($description ? $sep : ''),
    &para( $description, -1, $left + length($sep), undef, 1 ));
}

# Special help tags which can be rendered differently for various
# output formats, or else can use late rendering.
sub helpTags {
  my $t = shift;
  
  # Local file paths: PATH(<encoded-path>?)
  $t =~ s/PATH\(([^\)]*)\)/
    my $p = $1; 
    my $e; 
    my $r = &const($1,\$e); 
    '`' . &helpPath($e ? $r : &shortPath($r)) . '`'/seg;
  
  # Copy of help: HELP(<script>;<heading>;<key>?)
  $t =~ s/HELP\(([^\)]+)\)/&help($1,undef,1,1)/seg;
    
  # Hyperlinks: [<text>?](<href>)
  $t =~ s/\[([^\]]*)\]\(([^\)]+)\)/($1 ? $1:$2)/seg;
 
  return $t;
}

sub helpPath {
  my $p = shift;
 
  return join(' / ', split(/\s*[\/\\]\s*/, $p));
}

sub format {
  my $text = &helpTags(shift);
  my $type = shift;
  
  if (!$text) {return;}
  
  my @args; if ($type =~ s/:(.+)$//) {@args = split(/,/, $1);}
  
  if ($type eq 'title') {
    return "----- $text -----\n\n";
  }
  elsif ($type eq 'heading') {
    return $text . "\n" . '-' x length($text) . "\n";
  }
  elsif ($type eq 'sub-heading') {
    return $text . "\n";
  }
  elsif ($type eq 'para') {
    return &para($text, @args);
  }
  
  return $text;
}


# Return a formatted paragraph of string t. Whitespace is first norm-
# alized in the string. $indent is the first line indent, $left is the
# left margin, and $width is the width in characters of the paragraph.
# $indent of -1 means output starts with the first character of $t (or
# -$left in other words). The special tag \b will be rendered as a 
# blank line with the paragraph.
sub para {
  my $t = &helpTags(shift);
  my $indent = shift; if (!defined($indent)) {$indent = 0;}
  my $left   = shift; if (!defined($left))   {$left   = 0;}
  my $width  = shift; if (!defined($width))  {$width  = 72;}
  my $noBlankLine = shift;
  
  $t =~ s/\s*\n\s*/ /g;
  $t =~ s/(^\s*|\s*$)//g;
  
  if ($indent == -1) {
    $indent = 0;
  }
  else {
    $indent = $left + $indent;
  }
  if ($indent) {$t = ' ' x $indent . $t;}
  
  my $tab = ' ' x $left;
 
  my $w = $width - $left - 12;
  
  my $out;
  my $i = $w + $indent;
  foreach my $sec (split(/(\s*\\b\s*)/, $t)) {
    if ($sec =~ /\\b/) {$out .= ' ' x $left; next;}
    while ($sec =~ s/^(.{$i}\S*\s+)//) {
      $out .= "$1\n$tab";
      $i = $w
    }
    $out .= $sec . "\n";
  }
  if (!$noBlankLine) {$out .= "\n";}
  
  return $out;
}

# Return a pointer to an array of help-list rows. Each key in $keyAP 
# becomes the key of a new row in the help-list, while the description 
# is a combination of deprecation message, any matching key description 
# found in $descAP and any matching default value in %CONFIG_DEFAULTS. 
# Any unused descriptions left in $descAP will generate an error.
sub getList {
  my $keyAP = shift;
  my $descAP = shift;
  my $nosort = shift;
  
  my $refRE = &configRE(keys %CONFIG_DEFAULTS);
  my $depRE = &configRE(@CONFIG_DEPRECATED);
  
  my @out;
  # Go through all required keys (some may be MATCHES keys)
  foreach my $k ($nosort ? @{$keyAP} : sort @{$keyAP}) {
    my $key = $k;
    
    # Look for one or more matching description keys
    my @desc;
    if ($key =~ s/^MATCHES://) {
      foreach my $kdP (@{$descAP}) {
        if ($kdP->[0] =~ /^($key)$/ || $kdP->[0] eq $key) {
          push(@desc, $kdP->[0]);
        }
      }
    }
    else {push(@desc, $key);}
    
    # Output one row for each matching description
    foreach my $k2 (sort @desc) {
    
      my $descP; foreach my $kdP (@{$descAP}) {
        if ($kdP->[0] eq $k2) {$descP = $kdP; $kdP = undef;}
      }
      
      my $pkey = ($descP->[0] ? $descP->[0] : $key);
      
      my $pdep = ($key =~ /^($depRE)$/ ? 'DEPRECATED. ' : '');
      
      my $pdesc = ($descP->[1] ? $descP->[1] . ' ' : '');
      
      my $pdef;
      if ($key =~ /^($refRE)$/) {$pdef = $CONFIG_DEFAULTS{$key};}
      if ($pdef =~ /DEF$/) {$pdef = '';}
      $pdef = ($pdef ? "Default is '$pdef'.":'');
      
      push(@out, [ $pkey, $pdep.$pdesc.$pdef ]);
    }
  }
  
  foreach (@{$descAP}) {
    if (ref($_) && ($_->[0] || $_->[1])) {
      &ErrorBug("Unused description: '".$_->[0]."', '".$_->[1]."'\n");
    }
  }

  return \@out;
}

sub getConversionArgs {

  my %all;
  # 'osis' will be resolved later to the particular conversion required  
  # for a project.
  foreach ('osis', @CONV_OSIS) {
    $all{$_}++;
  }
  foreach ('all', &getPubTypes()) {
    $all{'sfm'.'2'.$_}++;
    $all{'osis'.'2'.$_}++;
  }
  
  return \%all;
}
sub getPubTypes {

  my @pubTypes;
  foreach (@CONV_PUBS) {
    my $pt = $_; $pt =~ s/^osis2//;
    push(@pubTypes, $pt);
  }
  return @pubTypes;
}

sub configList {
  my @list = (@SWORD_CONFIGS, 
              @SWORD_OC_CONFIGS, 
              @OC_CONFIGS, 
              @OC_SYSTEM_CONFIGS);
  
  # Subtract these entries from the list
  my $re = &configRE( @SWORD_AUTOGEN_CONFIGS, 
                      @SWORD_NOT_SUPPORTED, 
                      @OC_DEVEL_CONFIGS);
  
  return [ grep {$_ !~ /$re/} @list ];
}

# Adds an entry type code to each key of the config.conf list.
sub addConfigType {
  my $aP = shift;

  my @re = (
    ['S', &configRE(@OC_SYSTEM_CONFIGS)],
    ['L', &configRE(@SWORD_LOCALIZABLE_CONFIGS, @OC_LOCALIZABLE_CONFIGS)],
    ['C', &configRE(@CONTINUABLE_CONFIGS)],
    ['W', &configRE(@SWORD_CONFIGS)],
    ['P', &configRE(@OC_SYSTEM_PATH_CONFIGS)],
    ['U', &configRE(@OC_URL_CONFIGS)],
  );
  
  foreach my $rP (@{$aP}) {
    my @types;
    foreach my $t (sort { $a->[0] cmp $b->[0] } @re) {
      my $a = $t->[1];
      if ($rP->[0] =~ /$a/) {push(@types, $t->[0]);}
    }
    if (@types) {
      $rP->[0] .= ' ('.join('', @types).')';
    }
  }
  
  return $aP;
}

# Adds an attribute type code to each key of an attribute list.
sub addAttributeType {
  my $aP = shift;
  
  my %t = (
    'boolean'    => 'B', 
    'osisRef+'   => 'R', 
    'xpath'      => 'X', 
    'context'    => 'C', 
    'cumulative' => 'A',
    'match',
  );
  
  foreach my $rP (@{$aP}) {
    my %types;
    if ($CF_ADDDICTLINKS{'attributes'}{$rP->[0]}) {
      foreach my $at (split(/\|/, 
          $CF_ADDDICTLINKS{'attributes'}{$rP->[0]})) {
        $types{$at}++;
      }
    }
    
    if (! keys %types) {next;}
    
    my $ts = 
      join('', sort map((exists($t{$_}) ? $t{$_} : 'x'), keys %types));
    if ($ts) {$rP->[0] .= " ($ts)";}
    if ($ts =~ /x/) {
      &ErrorBug("Missing attribute type $ts: ".join(', ', keys %types), 1);
    }
  }
  
  return $aP;
}

sub usage {
  my $r = "\nUSAGE: $SCRIPT_NAME ";
    
  my %p; my $c;
  foreach my $t ('argument', 'option', 'switch') {
    foreach my $s ('all', $SCRIPT_NAME) {
      foreach my $a (sort keys %{$ARG{$s}{$t}}) {
        if ( $s eq 'all' && exists($ARG{$SCRIPT_NAME}{$t}{$a}) ) {
          next;
        }
        my @a = @{$ARG{$s}{$t}{$a}};
        
        my $sub = ( $t eq 'switch' ? "-$a" : 
                  ( $t eq 'option' ? "-$a ".@a[2] : @a[2] ));
               
        # Set the sort order using numbered hash keys
        my $k1 = ($t eq 'switch'   ? 100 : ($t eq 'option' ? 1000: 10000));
        my $k2 = ($t eq 'argument' ? 100 : ($t eq 'switch' ? 1000: 10000));
        
        $p{'tem'}{ ($k1 + $c) } = "[$sub]";
        $p{'exp'}{ ($k2 + $c) }{$sub} = @a[3];
        $c++;
      }
    }
  }
  
  my $l = 0; foreach (keys %{$p{'tem'}}) {
    if ($l < length($p{'tem'}{$_})-2) {$l = length($p{'tem'}{$_})-2;}
  }
  
  my $tem = 
    join(' ', map($p{'tem'}{$_}, sort {$a <=> $b} keys %{$p{'tem'}}));
    
  my $exp;
  foreach my $i (sort {$a <=> $b} keys %{$p{'exp'}}) {
    foreach my $s (sort keys %{$p{'exp'}{$i}}) {
      $exp .= sprintf('%-'.$l."s : %s\n", 
              $s, &usagePrint(($l+3), 72, $p{'exp'}{$i}{$s}));
    }
  }
  
  $r .= "$tem\n\n$exp\n";
  
  return $r;
}

sub usagePrint {
  my $tablen = shift;
  my $width = shift;
  my $string = shift;
  
  my $chars = ($width - 12 - $tablen);
  my $tab = (' ' x $tablen);
  $string =~ s/(.{$chars}\S*)\s/$1\n$tab/g;
  
  return $string;
}

# Read all arguments in @_ and set all argument globals. Return a hash 
# containing supplied arguments. If unexpected arguments are found an 
# abort message is printed and an abort flag is set.
sub arguments {
  no strict 'refs';
  
  # First set globals to default values
  foreach my $s ('all', $SCRIPT_NAME) {
    foreach my $t (sort keys %{$ARG{$s}}) {
      foreach my $a (sort keys %{$ARG{$s}{$t}}) {
        my $n = @{$ARG{$s}{$t}{$a}}[0];
        my $v = @{$ARG{$s}{$t}{$a}}[1];
        if (@{$ARG{$s}{$t}{$a}}[2] =~ /^(file|dir)$/) {
          $$n = &argPath($v);
        }
        else {$$n = $v;}
      }
    }
  }
  
  my $switchRE = join('|', map(keys %{$ARG{$_}{'switch'}}, 'all', $SCRIPT_NAME));
  my $optionRE = join('|', map(keys %{$ARG{$_}{'option'}}, 'all', $SCRIPT_NAME));
  
  my %args = ( 'abort' => 1 );
  
  # Now update globals based on the provided arguments.
  my $argv = shift;
  my @a = ('first', 'second'); $a = 0;
  my ($aP, $arg, $value, $type);
  while ($argv) {
    if ($argv =~ /^\-(\S*)/) {
      my $f = $1;
      if ($f =~ /^($switchRE)$/) {
        $arg = $1;
        $type = 'switch';
        $aP = &getArg($type, $arg);
        $value = undef;
      }
      elsif ($f =~ /^($optionRE)$/) {
        $arg = $1;
        $type = 'option';
        $aP = &getArg($type, $arg);
        if ($aP->[2] =~ /^\[/ && 
            ( !defined(@_[0]) || @_[0] =~ /^[-\.\/]/) ) {$value = undef;}
        else {
          $value = shift;
          if (!$value || $value =~ /^\-/) {
            print "\nABORT: option -$f needs a value\n";
            return %args;
          }
        }
      }
      else {
        print "\nABORT: unhandled option: $argv\n";
        return %args;
      }
    }
    else {
      $arg = @a[$a];
      $value = $argv;
      $type = 'argument';
      $aP = &getArg($type, $arg);
      if (@a[$a]) {$a++;}
      else {
        print "\nABORT: too many arguments.\n";
        return %args;
      }
    }
    
    my $var = $aP->[0];
    
    if ($type eq 'switch') {$value = !$$var;}
    
    elsif ($aP->[2] =~ /^(file|dir)$/) {$value = &argPath($value);}
    
    $$var = $value;
    $args{$arg} = $value;
    
    $argv = shift;
  }
  delete($args{'abort'});
  
  &DebugListVars("AFTER &arguments() WHERE\n$SCRIPT_NAME arguments", 'HELP', 
    'INPD', 'LOGFILE', 'NO_ADDITIONAL', 'CONVERSION', 'MODRE', 
    'MAXTHREADS', 'SKIPRE');
  
  return %args;
}

# Write an argument hash $hP as a command line string.
sub writeArgs {
  my $hP = shift;
 
  my $cmd;
  foreach my $a (sort keys %{$hP}) {
    if (&optType($a) eq 'argument') {next;}
    
    $cmd .= "-$a ";
    if (&optType($a) eq 'option') {
      $cmd .= "$hP->{$a} ";
    }
  }
  foreach my $a (sort keys %{$hP}) {
    if (!$hP->{$a} || &optType($a) ne 'argument') {next;}
    $cmd .= "'$hP->{$a}' ";
  }
  
  return $cmd;
}

# Get the current type of a given argument name
sub optType {
  my $as = shift;
  
  my $r;
  foreach my $s ('all', $SCRIPT_NAME) {
    foreach my $t (sort keys %{$ARG{$s}}) {
      foreach my $a (sort keys %{$ARG{$s}{$t}}) {
        if ($a eq $as) {$r = $t;}
      }
    }
  }
  
  return $r;
}

# Get the current %ARG definition for a given type and argument name.
sub getArg {
  my $type = shift;
  my $arg = shift;
  
  my $aP = $ARG{$SCRIPT_NAME}{$type}{$arg};
  if (!ref($aP)) {
    $aP = $ARG{'all'}{$type}{$arg};
  }
  
  return $aP;
}
