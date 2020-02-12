<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:runtime="java:java.lang.Runtime"
 xmlns:uri="java:java.net.URI"
 xmlns:file="java:java.io.File"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 exclude-result-prefixes="#all">
  
  <!-- If script-specific config context is desired from oc:conf(), then the calling script must pass this SCRIPT_NAME parameter -->
  <param name="SCRIPT_NAME"/>
  
  <!-- If DICT-specific config context is desired from oc:conf(), then either the OSIS file header 
  and osisText elements must be marked-up as x-glossary type, OR the calling script must pass in DICTMOD -->
  <param name="DICTMOD" select="/osis/osisText/header/work[@osisWork=/osis/osisText/@osisIDWork][child::type[@type='x-glossary']]/@osisWork"/>
  
  <!-- The following config entries require a properly marked-up OSIS header, OR 
  the calling script must pass in their values (otherwise an error is thrown for oc:conf()) -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>
  <param name="TOC" select="oc:conf('TOC', /)"/>
  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>
  <param name="KeySort" select="oc:conf('KeySort', /)"/>
  
  <param name="uiIntroduction" 
    select="oc:sarg('uiIntroduction', /, concat('-- ', //header/work[child::type[@type='x-bible']]/title[1]))"/>
  <param name="uiDictionary" 
    select="oc:sarg('uiDictionary', /, concat('- ', //header/work[child::type[@type='x-glossary']]/title[1]))"/>
    
  
  <!-- Return a contextualized config entry value by reading the OSIS header.
       An error is thrown if requested entry is not found. -->
  <function name="oc:conf" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <variable name="result" select="oc:osisHeaderContext($entry, $anynode, 'no')"/>
    <call-template name="Note"><with-param name="msg" select="concat('(SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, ') Reading config.conf: ', $entry, ' = ', $result)"/></call-template>
    <choose>
      <when test="$result and oc:isValidConfigValue($entry, $result)"><value-of select="$result"/></when>
      <when test="$result"><value-of select="$result"/></when>
      <otherwise>
        <call-template name="Error">
          <with-param name="msg">Config parameter was not specified in OSIS header and was not passed to functions.xsl: <value-of select="$entry"/> (SCRIPT_NAME=<value-of select="$SCRIPT_NAME"/>, isDICTMOD=<value-of select="$DICTMOD"/>)</with-param>
          <with-param name="die">yes</with-param>
        </call-template>
      </otherwise>
    </choose>
  </function>
  
  <!-- Return a contextualized optional config ARG_entry value by reading the OSIS header. 
       The required default value is returned if ARG_entry is not found) -->
  <function name="oc:sarg" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <param name="default" as="xs:string?"/>
    <variable name="result0" select="oc:osisHeaderContext($entry, $anynode, 'yes')"/>
    <variable name="result">
      <choose>
        <when test="$result0"><value-of select="$result0"/></when>
        <otherwise><value-of select="$default"/></otherwise>
      </choose>
    </variable>
    <call-template name="Note"><with-param name="msg" select="concat('(SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, ') Reading config.conf: ARG_', $entry, ' = ', $result)"/></call-template>
    <value-of select="$result"/>
  </function>
    
  <!-- Return a config system value by reading the OSIS header.
       Nothing is returned if the requested param is not found. -->
  <function name="oc:csys" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <variable name="result" select="$anynode/root()/osis[1]/osisText[1]/header[1]/work[1]/description[@type=concat('x-config-system+', $entry)][1]/text()"/>
    <call-template name="Note"><with-param name="msg" select="concat('(SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, ') Reading system variable: ', $entry, ' = ', $result)"/></call-template>
    <value-of select="$result"/>
  </function>
  
  <!-- Return a contextualized config or argument value by reading the OSIS header -->
  <function name="oc:osisHeaderContext" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <param name="isarg" as="xs:string"/> <!-- either 'yes' this is a script argument or 'no' this is a regular config entry -->
    <variable name="entry2" select="concat((if ($isarg = 'yes') then 'ARG_' else ''), $entry)"/>
    <choose>
      <when test="$SCRIPT_NAME and boolean($anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $SCRIPT_NAME, '+', $entry2)])">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/work[1]/description[@type=concat('x-config-', $SCRIPT_NAME, '+', $entry2)][1]/text()"/>
      </when>
      <when test="$DICTMOD and boolean($anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $entry2)])">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/(work/description[@type=concat('x-config-', $entry2)])[last()]/text()"/>
      </when>
      <when test="$anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $entry2)]">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/(work/description[@type=concat('x-config-', $entry2)])[1]/text()"/>
      </when>
    </choose>
  </function>
  
  <function name="oc:isValidConfigValue" as="xs:boolean">
    <param name="entry" as="xs:string"/>
    <param name="value" as="xs:string"/>
    <choose>
      <when test="matches($entry, 'Title', 'i') and matches($value, ' DEF$')">
        <value-of select="false()"/>
        <call-template name="Error">
          <with-param name="msg">XSLT found default value '<value-of select="$value"/>' for config.conf title entry <value-of select="$entry"/>.</with-param>
          <with-param name="exp">Add <value-of select="$entry"/>=[localized-title] to the config.conf file.</with-param>
        </call-template>
      </when>
      <otherwise><value-of select="true()"/></otherwise>
    </choose>
  </function>
 
  <function name="oc:number-of-matches" as="xs:integer">
    <param name="arg" as="xs:string?"/>
    <param name="pattern" as="xs:string"/>
    <sequence select="count(tokenize($arg,$pattern)) - 1"/>
  </function>
  
  <function name="oc:index-of-node" as="xs:integer*">
    <param name="nodes" as="node()*"/>
    <param name="nodeToFind" as="node()"/>
    <sequence select="for $seq in (1 to count($nodes)) return $seq[$nodes[$seq] is $nodeToFind]"/>
  </function>
  
  <function name="oc:uniregex" as="xs:string">
    <param name="regex" as="xs:string"/>
    <choose>
      <when test="oc:unicode_Category_Regex_Support('')"><value-of select="replace($regex, '\{gc=', '{')"/></when>
      <when test="oc:unicode_Category_Regex_Support('gc=')"><value-of select="$regex"/></when>
      <otherwise>
        <call-template name="ErrorBug">
          <with-param name="msg">Your Java installation does not support Unicode character properties in regular expressions! This script will be aborted!</with-param>
          <with-param name="die" select="'yes'"/>
        </call-template>
      </otherwise>
    </choose>
  </function>
  <function name="oc:unicode_Category_Regex_Support" as="xs:boolean">
    <param name="gc" as="xs:string?"/>
    <variable name="unicodeLetters" select="'ᴴЦ'"/>
    <value-of select="matches($unicodeLetters, concat('\p{', $gc, 'L}')) and not(matches($unicodeLetters, concat('[^\p{', $gc, 'L}]'))) and not(matches($unicodeLetters, concat('\P{', $gc, 'L}')))"/>
  </function>
  
  <!-- Only output true if $glossaryEntry first letter matches that of the previous entry (case-insensitive)--> 
  <function name="oc:skipGlossaryEntry">
    <param name="glossaryEntry"/>
    <variable name="previousKeyword" select="$glossaryEntry/preceding::seg[@type='keyword'][1]/string()"/>
    <choose>
      <when test="not($previousKeyword)"><value-of select="false()"/></when>
      <otherwise><value-of select="boolean(upper-case(substring($glossaryEntry/text(), 1, 1)) = upper-case(substring($previousKeyword, 1, 1)))"/></otherwise>
    </choose>
  </function>
  
  <!-- Encode any UTF8 string value into a legal OSIS osisRef -->
  <function name="oc:encodeOsisRef">
    <param name="r"/>
    <value-of>
      <analyze-string select="$r" regex="."> 
        <matching-substring>
          <choose>
            <when test=". = ';'"> </when>
            <when test="string-to-codepoints(.)[1] &#62; 1103 or matches(., oc:uniregex('[^\p{gc=L}\p{gc=N}_]'))">
              <value-of>_<value-of select="string-to-codepoints(.)[1]"/>_</value-of>
            </when>
            <otherwise><value-of select="."/></otherwise>
          </choose>
        </matching-substring>
      </analyze-string>
    </value-of>
  </function>
  
  <!-- Decode a oc:encodeOsisRef osisRef to UTF8 -->
  <function name="oc:decodeOsisRef">
    <param name="osisRef"/>
    <value-of>
      <analyze-string select="$osisRef" regex="(_\d+_|.)">
        <matching-substring>
          <choose>
            <when test="matches(., '_\d+_')">
              <variable name="codepoint" select="xs:integer(number(replace(., '_(\d+)_', '$1')))"/>
              <value-of select="codepoints-to-string($codepoint)"/>
            </when>
            <otherwise><value-of select="."/></otherwise>
          </choose>
        </matching-substring>
      </analyze-string>
    </value-of>
  </function>
  
  <!-- Sort by an arbitrary character order: <sort select="oc:keySort($key)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <function name="oc:keySort" as="xs:string?">
    <param name="text" as="xs:string?"/>
    <if test="$KeySort and $text">
      <variable name="ignoreRegex" select="oc:getIgnoreRegex()" as="xs:string"/>
      <variable name="charRegexes" select="oc:getCharRegexes()" as="element(oc:regex)*"/>
      <!-- re-order from longest regex to shortest -->
      <variable name="long2shortCharRegexes" select="oc:getLong2shortCharRegexes($charRegexes)" as="element(oc:regex)*"/>
      <variable name="long2shortCharRegexeMono" select="concat('(', string-join($long2shortCharRegexes/@regex, '|'), ')')" as="xs:string"/>
      <variable name="textKeep" select="if ($ignoreRegex) then replace($text, $ignoreRegex, '') else $text"/>
      <variable name="result" as="xs:string">
        <value-of>
        <analyze-string select="$textKeep" regex="{$long2shortCharRegexeMono}">
          <matching-substring>
            <variable name="subst" select="."/>
            <for-each select="$long2shortCharRegexes">
              <if test="matches($subst, concat('^', @regex, '$'))">
                <value-of select="codepoints-to-string(xs:integer(number(@position) + 64))"/> <!-- 64 starts at character "A" -->
              </if>
            </for-each>
          </matching-substring>
          <non-matching-substring>
            <choose>
              <when test="matches(., oc:uniregex('\p{gc=L}'))">
                <call-template name="Error">
                  <with-param name="msg">keySort(): Cannot sort aggregate glossary entry '<value-of select="$text"/>'; 'KeySort=<value-of select="$KeySort"/>' is missing the character <value-of select="concat('&quot;', ., '&quot;')"/>.</with-param>
                  <with-param name="exp">Add the missing character to the config.conf file's KeySort entry. Place it where it belongs in the order of characters.</with-param>
                </call-template>
              </when>
              <otherwise><value-of select="."/></otherwise>
            </choose>
          </non-matching-substring>
        </analyze-string>
        </value-of>
      </variable>
      <value-of select="$result"/>
    </if>
    <if test="not($KeySort)">
      <call-template name="Warn"><with-param name="msg">keySort(): 'KeySort' is not specified in config.conf. Glossary entries will be ordered in Unicode order.</with-param></call-template>
      <value-of select="$text"/>
    </if>
  </function>
  <function name="oc:encodeKS" as="xs:string">
    <param name="str" as="xs:string"/>
    <value-of select="replace(replace(replace(replace($str, '\\\[', '_91_'), '\\\]', '_93_'), '\\\{', '_123_'), '\\\}', '_125_')"/>
  </function>
  <function name="oc:decodeKS" as="xs:string">
    <param name="str" as="xs:string"/>
    <value-of select="replace(replace(replace(replace($str, '_91_', '['), '_93_', ']'), '_123_', '{'), '_125_', '}')"/>
  </function>
  <function name="oc:getIgnoreRegex" as="xs:string">
    <variable name="ignores" as="xs:string*">
      <analyze-string select="oc:encodeKS($KeySort)" regex="{'\{([^\}]*)\}'}">
        <matching-substring><sequence select="regex-group(1)"/></matching-substring>
        </analyze-string>
    </variable>
    <value-of select="if ($ignores) then oc:decodeKS(concat('(', string-join($ignores, '|'), ')')) else ''"/>
  </function>
  <function name="oc:getCharRegexes" as="element(oc:regex)*">
    <!-- split KeySort string into 3 groups: chr | [] | {} -->
    <analyze-string select="oc:encodeKS($KeySort)" regex="{'([^\[\{]|(\[[^\]]*\])|(\{[^\}]*\}))'}">
      <matching-substring>
        <if test="not(regex-group(3))"><!-- if group(3) is non empty, this is an ignore group -->
          <oc:regex>
            <attribute name="regex" select="oc:decodeKS(if (regex-group(2)) then substring(., 2, string-length(.)-2) else .)"/>
            <attribute name="position" select="position()"/>
          </oc:regex>
        </if>
      </matching-substring>
    </analyze-string>
  </function>
  <function name="oc:getLong2shortCharRegexes" as="element(oc:regex)*">
    <param name="charRegexes" as="element(oc:regex)*"/>
    <for-each select="$charRegexes">     
      <sort select="string-length(./@regex)" data-type="number" order="descending"/> 
      <copy-of select="."/>
    </for-each>
  </function>
  
  <!-- Find the longest KeySort match at the beginning of a string, or else the first character. -->
  <function name="oc:longestStartingMatchKS" as="xs:string">
    <param name="text" as="xs:string"/>
    <choose>
      <when test="not($text)"><value-of select="''"/></when>
      <when test="$KeySort">
        <variable name="charRegexes" select="oc:getCharRegexes()" as="element(oc:regex)*"/>
        <variable name="ignoreRegex" select="oc:getIgnoreRegex()" as="xs:string"/>
        <variable name="textKeep" select="if ($ignoreRegex) then replace($text, $ignoreRegex, '') else $text"/>
        <variable name="result" select="replace($textKeep, concat('^(', string-join(oc:getLong2shortCharRegexes($charRegexes)/@regex, '|'), ').*?$'), '$1')"/>
        <value-of select="if ($result != $textKeep) then $result else substring($textKeep, 1, 1)"/>
      </when>
      <otherwise><value-of select="substring($text, 1, 1)"/></otherwise>
    </choose>
  </function>
  
  <!-- When a glossary has a TOC entry or main title, then get that title -->
  <function name="oc:getGlossaryTitle" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <value-of select="oc:titleCase(replace($glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]/@n)[1], '^(\[[^\]]*\])+', ''))"/>
  </function>
  
  <!-- When a glossary has a scope which is the same as a Sub-Publication's scope, then get the localized title of that Sub-Publication -->
  <function name="oc:getGlossaryScopeTitle" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <variable name ="pscope" select="replace($glossary/@scope, '\s', '_')"/>
    <variable name="title" select="root($glossary)//header//description[contains(@type, concat('TitleSubPublication[', $pscope, ']'))]"/>
    <value-of select="if ($title) then $title/text() else ''"/>
  </function>
  
  <function name="oc:getTocInstructions" as="xs:string*">
    <param name="tocElement" as="element()?"/>
    <variable name="result" as="xs:string*">
      <if test="$tocElement/@n">
        <analyze-string select="$tocElement/@n" regex="\[([^\]]*)\]"> 
          <matching-substring><value-of select="regex-group(1)"/></matching-substring>
        </analyze-string>
      </if>
    </variable>
    <value-of select="distinct-values($result)"/>
  </function>
  
  <function name="oc:titleCase" as="xs:string?">
    <param name="title" as="xs:string?"/>
    <choose>
      <when test="$TitleCase = '1'"><value-of select="string-join(oc:capitalize-first(tokenize($title, '\s+')), ' ')"/></when>
      <when test="$TitleCase = '2'"><value-of select="upper-case($title)"/></when>
      <otherwise><value-of select="$title"/></otherwise>
    </choose>
  </function>
  
  <function name="oc:capitalize-first" as="xs:string*">
    <param name="words" as="xs:string*"/>
    <for-each select="$words"><!-- but don't modify roman numerals! -->
      <sequence select="if (matches(., '^[IiVvLlXx]+$')) then . else concat(upper-case(substring(.,1,1)), lower-case(substring(.,2)))"/>
    </for-each>
  </function>
  
  <function name="oc:myWork" as="xs:string">
    <param name="node" as="node()"/>
    <value-of select="root($node)/osis[1]/osisText[1]/@osisIDWork"/>
  </function>
  
  <!-- Returns a list of links to glossary and introductory material, 
  including next/previous chapter/keyword links. -->
  <function name="oc:getNavmenuLinks" as="element(list)?">
    <param name="context" as="node()"/><!-- used to determine prev/next -->
    <param name="root" as="document-node()"/>
    <param name="skip"/><!-- is either empty, 'introduction', 'glossary' or 'prevnext' -->
    
    <variable name="bible" select="$root/descendant::work[child::type[@type='x-bible']][1]/@osisWork"/>
    <variable name="dict" select="$root/descendant::work[child::type[@type='x-glossary']][1]/@osisWork"/>
    <if test="$bible"><!-- return nothing for Children's Bibles -->
      <variable name="using_INT_feature" select="$root/descendant::*[@annotateType = 'x-feature'][@annotateRef = 'INT'][1]"/>
      
      <variable name="inBibleContext" select="oc:myWork($context) = $bible"/>
      <variable name="inKeyword" as="element(div)?"
        select="$context/ancestor-or-self::div[not($inBibleContext)][starts-with(@type,'x-keyword')][1]"/>
      <variable name="inBibleChapter" as="element(chapter)?"
        select="$context/(self::chapter[@eID] | following::chapter[@eID])[1]
                         [@eID=$context/preceding::chapter[1]/@sID]"/>
      <osis:list subType="x-navmenu" resp="x-oc">
        <if test="$inBibleContext">
          <attribute name="canonical">false</attribute>
        </if>
        <variable name="prev" as="xs:string?" select="
            if ($inKeyword) then 
              $inKeyword/preceding-sibling::div[1]/descendant::seg[@type='keyword'][1]/@osisID
            else if ($inBibleChapter) then 
              $inBibleChapter/preceding::chapter[ @osisID = string-join((
                tokenize( $inBibleChapter/@eID, '\.' )[1], 
                string(number(tokenize( $inBibleChapter/@eID, '\.' )[2])-1)), '.') ][1]/@osisID
            else ''"/>
        <variable name="next" as="xs:string?" select="
            if ($inKeyword) then 
              $inKeyword/following-sibling::div[1]/descendant::seg[@type='keyword'][1]/@osisID
            else if ($inBibleChapter) then 
              $inBibleChapter/following::chapter[ @osisID = string-join((
              tokenize( $inBibleChapter/@eID, '\.' )[1], 
              string(number(tokenize( $inBibleChapter/@eID, '\.' )[2])+1)), '.')][1]/@osisID
            else ''"/>
        <!-- NOTE: Really, links to the glossary from Bibles should be type=
        'x-glossary' but in the navmenus they are all 'x-glosslink' every-
        where, so as to be backward compatible with old CSS -->
        <if test="not(matches($skip, 'prevnext')) and ($prev or $next)">
          <osis:item subType="x-prevnext-link">
            <osis:p type="x-right">
              <if test="not($inBibleChapter)">
                <attribute name="subType">x-introduction</attribute>
              </if>
              <if test="$prev">
                <choose>
                  <when test="$inBibleChapter">
                    <osis:reference osisRef="{$bible}:{$prev}">
                      <text> ← </text>
                    </osis:reference>
                  </when>
                  <otherwise>
                    <osis:reference osisRef="{$dict}:{$prev}" type="x-glosslink" subType="x-target_self">
                      <text> ← </text>
                    </osis:reference>
                  </otherwise>
                </choose>
              </if>
              <if test="$next">
                <choose>
                  <when test="$inBibleChapter">
                    <osis:reference osisRef="{$bible}:{$next}">
                      <text> → </text>
                    </osis:reference>
                  </when>
                  <otherwise>
                    <osis:reference osisRef="{$dict}:{$next}" type="x-glosslink" subType="x-target_self">
                      <text> → </text>
                    </osis:reference>
                  </otherwise>
                </choose>
              </if>
            </osis:p>
          </osis:item>
        </if>
        
        <if test="not(matches($skip, 'introduction')) and 
                  not($inKeyword/descendant::seg[@type='keyword']
                                                [$using_INT_feature]
                                                [@osisID = oc:encodeOsisRef($uiIntroduction)])">
          <osis:item subType="x-introduction-link">
            <osis:p type="x-right">
              <if test="not($inBibleChapter)">
                <attribute name="subType">x-introduction</attribute>
              </if>
              <variable name="intref" 
                  select="if ($using_INT_feature) then 
                            concat($dict,':',oc:encodeOsisRef($uiIntroduction)) else 
                            concat($bible,':','BIBLE_TOP')"/>
              <osis:reference osisRef="{$intref}" type="x-glosslink" subType="x-target_self">
                <value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
              </osis:reference>
            </osis:p>
          </osis:item>
        </if>
        
        <if test="not(matches($skip, 'dictionary')) and $dict and 
                  not($inKeyword/descendant::seg[@type='keyword']
                                                [@osisID = oc:encodeOsisRef($uiDictionary)])">
          <osis:item subType="x-dictionary-link">
            <osis:p type="x-right" subType="x-introduction">
              <!-- a menu with the following osisRef is created by oc:getGlossaryMenu() -->
              <osis:reference osisRef="{$dict}:{oc:encodeOsisRef($uiDictionary)}" 
                type="x-glosslink" subType="x-target_self">
                <value-of select="replace($uiDictionary, '^[\-\s]+', '')"/>
              </osis:reference>
            </osis:p>
          </osis:item>
        </if>
        <osis:lb/>
        <osis:lb/>
      </osis:list>
    </if>
  </function>
  
  <!-- Returns a glossary div containing an auto generated menu system
  to act as an inline table-of-contents for another glossary or, if 
  $glossary is empty, for all glossaries in $dictroot. If 
  $includeGlossary is true then the glossary entries themselves will 
  also be output. -->
  <function name="oc:getGlossaryMenu" as="element(div)">
    <param name="glossary" as="element(div)?"/><!-- if empty, a TOC menu of all glossaries is returned -->
    <param name="dictroot" as="document-node()"/>
    <param name="osisID" as="xs:string"/>
    <param name="includeGlossary" as="xs:boolean"/>
    
    <variable name="dictmod" select="$dictroot/osis/osisText/@osisIDWork"/>

    <osis:div>
      <if test="$osisID">
        <attribute name="osisID" select="$osisID"/>
      </if>
      <attribute name="type">glossary</attribute>
      <attribute name="scope">NAVMENU</attribute>
      <attribute name="resp">x-oc</attribute>
      
      <variable name="uiDictionary" 
        select="oc:sarg('uiDictionary', $dictroot, concat('- ', $dictroot//header/work[child::type[@type='x-glossary']]/title[1]))"/>
      
      <variable name="glossaryNameKeyword" 
        select="if (not($glossary) or not(oc:getGlossaryTitle($glossary))) then 
                $uiDictionary else 
                oc:getGlossaryTitle($glossary)"/>
                
      <text>&#xa;</text>
      
      <choose>
        <!-- When $glossary is empty output a menu with a link to every glossary of dictroot -->
        <when test="not($glossary)">
          <osis:div type="x-keyword" subType="x-navmenu-dictionary-top">
            <osis:p>
              <osis:seg type="keyword" osisID="{oc:encodeOsisRef($uiDictionary)}">
                <value-of select="$uiDictionary"/>
              </osis:seg>
              <for-each select="$dictroot//div[@type='glossary']">
                <variable name="glossTitle" select="oc:getGlossaryTitle(.)"/>
                <osis:reference osisRef="{$dictmod}:{oc:encodeOsisRef($glossTitle)}" 
                  type="x-glosslink" subType="x-target_self">
                  <value-of select="$glossTitle"/>
                </osis:reference>
              </for-each>
            </osis:p>
            <sequence select="oc:getNavmenuLinks($dictroot, $dictroot, 'dictionary')"/>
          </osis:div>
        </when>
        <otherwise>
          <!-- Otherwise create a menu for the glossary with links to each letter (plus a link 
          to the A-Z menu) on it, plus separate letter menus for each letter -->        
          <variable name="allEntriesTitle" 
            select="concat(
                    '-', 
                    upper-case(oc:longestStartingMatchKS($glossary/descendant::seg[@type='keyword'][1])), 
                    '-', 
                    upper-case(oc:longestStartingMatchKS($glossary/descendant::seg[@type='keyword'][last()])))"/>
          <osis:div type="x-keyword" subType="x-navmenu-dictionary">
            <osis:p>
              <osis:seg type="keyword" osisID="{oc:encodeOsisRef($glossaryNameKeyword)}">
                <value-of select="$glossaryNameKeyword"/>
              </osis:seg>
            </osis:p>
            <sequence select="oc:getNavmenuLinks($glossary, $dictroot, 'dictionary')"/>
            <osis:reference osisRef="{$dictmod}:{oc:encodeOsisRef($allEntriesTitle)}" 
              type="x-glosslink" subType="x-target_self">
              <value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/>
            </osis:reference>
            <for-each select="$glossary//seg[@type='keyword']">
              <if test="oc:skipGlossaryEntry(.) = false()">
                <variable name="letter" select="upper-case(oc:longestStartingMatchKS(text()))"/>
                <osis:reference osisRef="{$dictmod}:_45_{oc:encodeOsisRef($letter)}" 
                  type="x-glosslink" subType="x-target_self">
                  <value-of select="$letter"/>
                </osis:reference>
              </if>
            </for-each>
          </osis:div>
          <call-template name="Note">
<with-param name="msg">Added dictionary menu: <value-of select="replace($glossaryNameKeyword, '^[\-\s]+', '')"/></with-param>
          </call-template>
          
          <!-- Create a sub-menu with links to every keyword listed on it -->
          <text>&#xa;</text>
          <osis:div osisID="dictionaryAtoZ" type="x-keyword" subType="x-navmenu-atoz">
            <osis:p>
              <osis:seg type="keyword" osisID="{oc:encodeOsisRef($allEntriesTitle)}">
                <value-of select="$allEntriesTitle"/>
              </osis:seg>
            </osis:p>
            <sequence select="oc:getNavmenuLinks($glossary, $dictroot, 'prevnext')"/>
            <for-each select="$glossary//seg[@type='keyword']">
              <osis:reference osisRef="{$dictmod}:{@osisID}" type="x-glosslink" subType="x-target_self">
                <value-of select="text()"/>
              </osis:reference>
              <osis:lb/>
            </for-each>
          </osis:div>
          <call-template name="Note">
<with-param name="msg">Added dictionary sub-menu: <value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/></with-param>
          </call-template>
          
          <!-- Create separate sub-menus for each letter (plus A-Z) with links to keywords beginning with that letter -->
          <variable name="letterMenus" as="element()*">
            <for-each select="$glossary//seg[@type='keyword']">
              <if test="oc:skipGlossaryEntry(.) = false()">
                <osis:p>
                  <osis:seg type="keyword" osisID="_45_{oc:encodeOsisRef(upper-case(oc:longestStartingMatchKS(text())))}">
                    <value-of select="concat('-', upper-case(oc:longestStartingMatchKS(text())))"/>
                  </osis:seg>
                </osis:p>
                <sequence select="oc:getNavmenuLinks(., $dictroot, 'prevnext')"/>
              </if>
              <osis:reference osisRef="{$dictmod}:{@osisID}" 
                type="x-glosslink" subType="x-target_self">
                <value-of select="text()"/>
              </osis:reference>
              <osis:lb/>
            </for-each>
          </variable>
          
          <for-each-group select="$letterMenus" group-starting-with="p[child::*[1][self::seg[@type='keyword']]]">
            <text>&#xa;</text>
            <osis:div type="x-keyword" subType="x-navmenu-letter">
              <sequence select="current-group()"/>
            </osis:div>
            <call-template name="Note">
<with-param name="msg">Added dictionary sub-menu: <value-of select="current-group()[1]"/></with-param>
            </call-template>
            <if test="$includeGlossary">
              <osis:lb/>
              <sequence select="$glossary/div[starts-with(@type,'x-keyword')]
                  [descendant::seg[@type='keyword'][1]/@osisID = current-group()/reference/@osisRef/(tokenize(.,':')[2])]"/>
            </if>
          </for-each-group>
          <text>&#xa;</text>
        </otherwise>
      </choose>
    </osis:div>

  </function>
  
  
  <!-- Use this function if an element must not contain other elements 
  (for EPUB2 etc. validation). Any element in $expel becomes a sibling 
  of the container $element, which is divided and duplicated accordingly. -->
  <function name="oc:expelElements">
    <param name="element" as="element()"/><!-- container -->
    <param name="expel" as="element()*"/> <!-- element(s) to be expelled -->
    <param name="quiet" as="xs:boolean"/>
    <choose>
      <when test="count($expel) = 0"><sequence select="$element"/></when>
      <otherwise>
        <variable name="pass1">
          <for-each-group select="$element" group-by="for $i in ./descendant-or-self::node() 
              return 2*count($i/preceding::node()[. intersect $expel]) + 
                     count($i/ancestor-or-self::node()[. intersect $expel])">
            <apply-templates mode="expel1" select="current-group()">
              <with-param name="expel" select="$expel" tunnel="yes"/>
            </apply-templates>
          </for-each-group>
        </variable>
        <!-- pass2 to insures id attributes are not duplicated and removes empty generated elements -->
        <variable name="pass2"><apply-templates mode="expel2" select="$pass1"/></variable>
        <if test="not($quiet) and count($element/node())+1 != count($pass2/node())">
          <call-template name="Note">
<with-param name="msg">expelling<for-each select="$expel">: <value-of select="oc:printNode(.)"/></for-each></with-param>
          </call-template>
        </if>
        <sequence select="$pass2"/>
      </otherwise>
    </choose>
  </function>
  <template mode="expel1" match="@*"><copy/></template>
  <template mode="expel1" match="node()">
    <param name="expel" as="element()+" tunnel="yes"/>
    <variable name="nodesInGroup" select="descendant-or-self::node()[oc:expelGroupingKey(., $expel) = current-grouping-key()]" as="node()*"/>
    <variable name="expelElement" select="$nodesInGroup/ancestor-or-self::*[generate-id(.) = $expel/generate-id()][1]" as="element()?"/>
    <if test="$nodesInGroup"><!-- drop the context node if it has no descendants or self in the current group -->
      <choose>
        <when test="$expelElement and descendant::*[generate-id(.) = generate-id($expelElement)]"><apply-templates mode="expel1"/></when>
        <otherwise>
          <copy>
            <if test="child::node()[normalize-space()]"><attribute name="container"/></if><!-- used to remove empty generated containers in pass2 -->
            <if test="current-grouping-key() &#62; oc:expelGroupingKey(descendant::*[generate-id(.) = $expel/generate-id()][1], $expel)">
              <attribute name="class" select="'continuation'"/>
            </if>
            <apply-templates mode="expel1" select="node()|@*"/>
          </copy>
        </otherwise>
      </choose>
    </if>
  </template>
  <function name="oc:expelGroupingKey" as="xs:integer">
    <param name="node" as="node()?"/>
    <param name="expel" as="element()+"/>
    <value-of select="2*count($node/preceding::node()[generate-id(.) = $expel/generate-id()]) + count($node/ancestor-or-self::node()[generate-id(.) = $expel/generate-id()])"/>
  </function>
  <template mode="expel2" match="node()|@*"><copy><apply-templates mode="expel2" select="node()|@*"/></copy></template>
  <template mode="expel2" match="@container | *[@container and not(child::node()[normalize-space()])]"/>
  <template mode="expel2" match="@id"><if test="not(preceding::*[@id = current()][not(@container and not(child::node()[normalize-space()]))])"><copy/></if></template>
  
  <!-- oc:uri-to-relative-path ($base-uri, $rel-uri) this function converts a 
  URI to a relative path using another URI directory as base reference. -->
  <function name="oc:uri-to-relative-path" as="xs:string">
    <param name="base-uri-file" as="xs:string"/> <!-- the URI base (file or directory) -->
    <param name="rel-uri-file" as="xs:string"/>  <!-- the URI to be converted to a relative path from that base (file or directory) -->
    
    <!-- base-uri begins and ends with '/' or is just '/' -->
    <variable name="base-uri" select="replace(replace($base-uri-file, '^([^/])', '/$1'), '/[^/]*$', '')"/>
    
    <!-- for rel-uri, any '.'s at the start of rel-uri-file are IGNORED so it begins with '/' -->
    <variable name="rel-uri" select="replace(replace($rel-uri-file, '^\.+', ''), '^([^/])', '/$1')"/>
    <variable name="tkn-base-uri" select="tokenize($base-uri, '/')" as="xs:string+"/>
    <variable name="tkn-rel-uri" select="tokenize($rel-uri, '/')" as="xs:string+"/>
    <variable name="uri-parts-max" select="max((count($tkn-base-uri), count($tkn-rel-uri)))" as="xs:integer"/>
    <!--  count equal URI parts with same index -->
    <variable name="uri-equal-parts" select="for $i in (1 to $uri-parts-max) 
      return $i[$tkn-base-uri[$i] eq $tkn-rel-uri[$i]]" as="xs:integer*"/>
    <choose>
      <!--  both URIs must share the same URI scheme -->
      <when test="$uri-equal-parts[1] eq 1">
        <!-- drop directories that have equal names but are not physically equal, 
        e.g. their value should correspond to the index in the sequence -->
        <variable name="dir-count-common" select="max(
            for $i in $uri-equal-parts 
            return $i[index-of($uri-equal-parts, $i) eq $i]
          )" as="xs:integer"/>
        <!-- difference from common to URI parts to common URI parts -->
        <variable name="delta-base-uri" select="count($tkn-base-uri) - $dir-count-common" as="xs:integer"/>
        <variable name="delta-rel-uri" select="count($tkn-rel-uri) - $dir-count-common" as="xs:integer"/>    
        <variable name="relative-path" select="
          concat(
          (: dot or dot-dot :) if ($delta-base-uri) then string-join(for $i in (1 to $delta-base-uri) return '../', '') else './',
          (: path parts :) string-join(for $i in (($dir-count-common + 1) to count($tkn-rel-uri)) return $tkn-rel-uri[$i], '/')
          )" as="xs:string"/>
        <choose>
          <when test="starts-with($rel-uri, concat($base-uri, '#'))">
            <value-of select="concat('#', tokenize($rel-uri, '#')[last()])"/>
          </when>
          <otherwise>
            <value-of select="$relative-path"/>
          </otherwise>
        </choose>
      </when>
      <!-- if both URIs share no equal part (e.g. for the reason of different URI 
      scheme names) then it's not possible to create a relative path. -->
      <otherwise>
        <value-of select="$rel-uri"/>
        <call-template name="Error">
<with-param name="msg">Indeterminate path:"<value-of select="$rel-uri"/>" is not relative to "<value-of select="$base-uri"/>"</with-param>
        </call-template>
      </otherwise>
    </choose>
  </function>
  
  <function name="oc:printNode" as="text()">
    <param name="node" as="node()?"/>
    <choose>
      <when test="not($node)">NULL</when>
      <when test="$node[self::element()]">
        <value-of>element <value-of select="$node/name()"/><for-each select="$node/@*"><value-of select="concat(' ', name(), '=&#34;', ., '&#34;')"/></for-each></value-of>
      </when>
      <when test="$node[self::text()]"><value-of select="concat('text-node: ', $node)"/></when>
      <when test="$node[self::comment()]"><value-of select="concat('comment-node: ', $node)"/></when>
      <when test="$node[self::attribute()]"><value-of select="concat('attribute-node: ', name($node), ' = ', $node)"/></when>
      <when test="$node[self::document-node()]"><value-of select="concat('document-node: ', base-uri($node))"/></when>
      <when test="$node[self::processing-instruction()]"><value-of select="concat('processing-instruction: ', $node)"/></when>
      <otherwise><value-of select="concat('other?:', $node)"/></otherwise>
    </choose>
  </function>
  
  <!-- The following extension allows XSLT to read binary files into base64 strings. The reasons for the munge are:
  - Only Java functions are supported by saxon.
  - Java exec() immediately returns, without blocking, making another blocking method a necessity.
  - Saxon seems to limit Java exec() so it can only be run by <message>, meaning there is no usable return value of any kind,
    thus no way to monitor the process, nor return data from exec(), other than having it always write to a file.
  - XSLT's unparsed-text-available() is its only file existence check, and it only works on text files (not binaries).
  - Bash shell scripting provides all necessary functionality, but XSLT requires it to be written while the context is 
    outside of any temporary trees (hence the need to call prepareRunTime and cleanupRunTime at the proper moment). -->
  <variable name="DOCDIR" select="tokenize(document-uri(/), '[^/]+$')[1]" as="xs:string"/>
  <variable name="runtimeDir" select="file:new(uri:new($DOCDIR))"/>
  <variable name="envp" as="xs:string +"><value-of select="''"/></variable>
  <variable name="readBinaryResource" select="concat(replace($DOCDIR, '^file:', ''), 'tmp_osis2fb2.xsl.rbr.sh')" as="xs:string"/>
  <variable name="tmpResult" select="concat(replace($DOCDIR, '^file:', ''), 'tmp_osis2fb2.xsl.txt')" as="xs:string"/>
  <function name="oc:read-binary-resource">
    <param name="resource" as="xs:string"/>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ($readBinaryResource, $resource), $envp, $runtimeDir)"/>: Read <value-of select="$resource"/></message>
    <call-template name="sleep"/>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="100"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="1000"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="10000"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="Error"><with-param name="msg" select="'Failed writing tmpResult'"/></call-template></if>
    <variable name="result">
      <if test="unparsed-text-available($tmpResult)"><value-of select="unparsed-text($tmpResult)"/></if>
    </variable>
    <if test="starts-with($result, 'nofile')"><call-template name="Error"><with-param name="msg" select="concat('Failed to locate: ', $resource)"/></call-template></if>
    <if test="not(starts-with($result, 'nofile'))"><value-of select="$result"/></if>
  </function>
  <template name="oc:prepareRunTime">
    <result-document href="{$readBinaryResource}" method="text">#!/bin/bash
rm -r <value-of select="$tmpResult"/>
touch <value-of select="$tmpResult"/>
chmod -r <value-of select="$tmpResult"/>
if [ -s $1 ]; then
  base64 $1 > <value-of select="$tmpResult"/>
else
  echo nofile > <value-of select="$tmpResult"/>
fi
chmod +r <value-of select="$tmpResult"/>
  </result-document>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('chmod', '+x', $readBinaryResource), $envp, $runtimeDir)"/>: Write runtime executable</message>
  </template>
  <template name="oc:cleanupRunTime">
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('rm', $readBinaryResource), $envp, $runtimeDir)"/>: Delete runtime executable</message>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('rm', '-r', $tmpResult), $envp, $runtimeDir)"/>: Delete tmpResult</message>
  </template>
  <template name="sleep" xmlns:thread="java.lang.Thread">
    <param name="ms" select="10"/>
    <if test="$ms!=10"><call-template name="Warn"><with-param name="msg" select="concat('Sleeping ', $ms, 'ms')"/></call-template></if>
    <message select="thread:sleep($ms)"/>     
  </template>
  
  <!-- The following messaging functions match those in common_opsys.pl for reporting consistency -->
  <template name="Error">
    <param name="msg"/>
    <param name="exp"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}">
      <text>&#xa;</text>ERROR: <value-of select="$msg"/><text>&#xa;</text>
      <if test="$exp">SOLUTION: <value-of select="$exp"/><text>&#xa;</text></if>
    </message>
  </template>
  <template name="ErrorBug">
    <param name="msg"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}">
      <text>&#xa;</text>ERROR (UNEXPECTED): <value-of select="$msg"/><text>&#xa;</text>
      <text>Backtrace: </text><value-of select="oc:printNode(.)"/><text>&#xa;</text>
      <text>Please report the above unexpected ERROR to osis-converters maintainer.</text><text>&#xa;</text>
    </message>
  </template>
  <template name="Warn">
    <param name="msg"/>
    <param name="exp"/>
    <message>
      <text>&#xa;</text>WARNING: <value-of select="$msg"/>
      <if test="$exp"><text>&#xa;</text>CHECK: <value-of select="$exp"/></if>
    </message>
  </template>
  <template name="Note">
    <param name="msg"/>
    <message>NOTE: <value-of select="$msg"/></message>
  </template>
  <template name="Debug">
    <param name="msg"/>
    <if test="$DEBUG"><message>DEBUG: <value-of select="$msg"/></message></if>
  </template>
  <template name="Report">
    <param name="msg"/>
    <message><value-of select="//osisText[1]/@osisIDWork"/> REPORT: <value-of select="$msg"/></message>
  </template>
  <template name="Log">
    <param name="msg"/>
    <message><value-of select="$msg"/></message>
  </template>
  
</stylesheet>
