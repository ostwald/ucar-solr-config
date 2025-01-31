<?xml version="1.0" encoding="UTF-8"?>
<!-- Basic MODS -->
<xsl:stylesheet version="1.0"
  xmlns:java="http://xml.apache.org/xalan/java"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:osm="http://nldr.library.ucar.edu/metadata/osm"
  exclude-result-prefixes="mods java">
  <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/manuscript_finding_aid.xslt"/>
  <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/slurp_MODS_fields_with_ALL_suffix_to_solr.xslt"/>

  <!-- HashSet to track single-valued fields. -->
  <xsl:variable name="single_valued_hashset" select="java:java.util.HashSet.new()"/>
  <xsl:key name="CN-lookup" match="row" use="collectionKey"/>
  <xsl:variable name="CNTable" select="document('/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/collectionKey.xml')/lookup"/>

  <xsl:template match="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]" name="index_MODS">
    <xsl:param name="content"/>
    <xsl:param name="prefix"></xsl:param>
    <xsl:param name="suffix">ms</xsl:param>

    <!-- Clearing hash in case the template is ran more than once. -->
    <xsl:variable name="return_from_clear" select="java:clear($single_valued_hashset)"/>

    <xsl:apply-templates mode="slurping_MODS" select="$content//mods:mods[1]">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="pid" select="../../@PID"/>
      <xsl:with-param name="datastream" select="../@ID"/>
    </xsl:apply-templates>
    <xsl:apply-templates mode="slurp_all_suffix" select="$content//mods:mods[1]"/>
  </xsl:template>

  <!-- Handle dates. -->
  <xsl:template match="mods:*[(@type='date') or (contains(translate(local-name(), 'D', 'd'), 'date'))][normalize-space(text())]" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>

    <xsl:variable name="rawTextValue" select="normalize-space(text())"/>

    <xsl:variable name="textValue">
      <xsl:call-template name="get_ISO8601_date">
        <xsl:with-param name="date" select="$rawTextValue"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
      </xsl:call-template>
    </xsl:variable>

    <!-- Use attributes in field name. -->
    <xsl:variable name="this_prefix">
      <xsl:value-of select="$prefix"/>
      <xsl:for-each select="@*">
        <xsl:sort select="concat(local-name(), namespace-uri(self::node()))"/>
        <xsl:value-of select="local-name()"/>
        <xsl:text>_</xsl:text>
        <xsl:value-of select="translate(., ' ', '_')"/>
        <xsl:text>_</xsl:text>
      </xsl:for-each>
    </xsl:variable>

    <!-- Prevent multiple generating multiple instances of single-valued fields
         by tracking things in a HashSet -->
    <xsl:variable name="field_name" select="normalize-space(concat($this_prefix, local-name()))"/>
    <!-- The method java.util.HashSet.add will return false when the value is
         already in the set. -->
    <xsl:if test="java:add($single_valued_hashset, $field_name)">
      <xsl:if test="not(normalize-space($textValue)='')">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($field_name, '_dt')"/>
          </xsl:attribute>
          <xsl:value-of select="$textValue"/>
        </field>
      </xsl:if>
      <xsl:if test="not(normalize-space($rawTextValue)='')">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($field_name, '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="$rawTextValue"/>
        </field>
      </xsl:if>
    </xsl:if>

    <xsl:if test="not(normalize-space($textValue)='')">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_mdt')"/>
        </xsl:attribute>
        <xsl:value-of select="$textValue"/>
      </field>
    </xsl:if>
    <xsl:if test="not(normalize-space($rawTextValue)='')">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_ms')"/>
        </xsl:attribute>
        <xsl:value-of select="$rawTextValue"/>
      </field>
    </xsl:if>
  </xsl:template>

  <!-- Avoid using text alone. -->
  <xsl:template match="text()" mode="slurping_MODS"/>

  <!-- Build up the list prefix with the element context. -->
  <xsl:template match="*" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(translate(@type, ' ', '_'), '_')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:call-template name="mods_language_fork">
      <xsl:with-param name="prefix" select="$this_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <!--
    The "eventType" attribute was introduce with MODS 3.5... Let's start
    exposing it for use.
  -->
  <xsl:template match="mods:originInfo" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:call-template name="mods_eventType_fork">
      <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_')"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Intercepting Corporate Names so we can create display names and sortable
        fields for primary authors -->
  <xsl:template match="mods:name[@type = 'corporate']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="node" select="current()"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>
    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(translate(@type, ' ', '_'), '_')"/>
      </xsl:if>
    </xsl:variable>
    <xsl:if test="((@usage = 'primary') or (@usage = 'Primary'))">
      <xsl:variable name="field_name">
        <xsl:value-of select="concat('ucar_', $this_prefix, translate(@usage, $uppercase, $lowercase), '_', translate(mods:role/mods:roleTerm[@type='text'], $uppercase, $lowercase), '_sort')"/>
      </xsl:variable>

      <field>
        <xsl:attribute name="name">
	  <xsl:choose>
            <xsl:when test="java:add($single_valued_hashset, string($field_name))">
              <xsl:value-of select="concat($field_name, '_s')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat($field_name, '_ms')"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="mods:namePart"/>
      </field>
    </xsl:if>
    <xsl:call-template name="mods_role_term">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="../.."/>
    </xsl:call-template>

  </xsl:template>

  <!-- Intercepting Personal Names so we can create display names and display
     names with affiliations-->
  <xsl:template match="mods:name[@type='personal']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>

    <xsl:if
      test="((mods:role/mods:roleTerm[@type='text']!='interviewer') and (mods:role/mods:roleTerm[@type='text']!='speaker')
      and (mods:role/mods:roleTerm[@type='text']!='sponser'))">

      <field>
        <xsl:attribute name="name">Creator_Lastname</xsl:attribute>
        <xsl:value-of select="mods:namePart[@type='family']"/>
      </field>
    </xsl:if>

    <field>
      <xsl:attribute name="name">Display_Name</xsl:attribute>
      <xsl:call-template name="mods_produce_name"/>
    </field>

    <field>
      <xsl:variable name="roleType">
        <xsl:value-of select="mods:role/mods:roleTerm[@type='text']"/>
      </xsl:variable>
      <xsl:attribute name="name">
        <xsl:value-of select="concat(translate($roleType, $uppercase, $lowercase), '_Display')"/>
      </xsl:attribute>
      <xsl:call-template name="mods_produce_name"/>
    </field>

    <field>
      <xsl:variable name="roleType">
        <xsl:value-of select="mods:role/mods:roleTerm[@type='text']"/>
      </xsl:variable>
      <xsl:attribute name="name"><xsl:value-of
          select="concat(translate($roleType, $uppercase, $lowercase), '_Display_with_Affiliation')"/>
      </xsl:attribute>
      <xsl:call-template name="mods_produce_name"/>
      <xsl:for-each select="mods:affiliation [text()[contains(.,'University Corporation For Atmospheric Research (UCAR)')]][1] ">
        <xsl:variable name="tempaffl">
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:variable>
        <xsl:if
          test="starts-with($tempaffl, 'University Corporation For Atmospheric Research (UCAR)')">
          <xsl:text>-NCAR/UCAR</xsl:text>
        </xsl:if>
      </xsl:for-each>
    </field>

    <field>
      <xsl:attribute name="name">Display_Name_with_Full_Affiliation</xsl:attribute>
      <xsl:call-template name="mods_produce_name"/>
      <xsl:text>-</xsl:text>
      <xsl:value-of select="normalize-space(mods:affiliation/text())"/>
    </field>

    <xsl:if test="@valueURI">
      <field>
        <xsl:attribute name="name">mods_upid_ms</xsl:attribute>
        <xsl:value-of select="@valueURI"/>
      </field>
    </xsl:if>

    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(translate(@type, ' ', '_'), '_')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:if test="((@usage='primary') or (@usage='Primary'))">
      <field>
        <xsl:variable name="roleType">
          <xsl:value-of select="mods:role/mods:roleTerm[@type='text']"/>
        </xsl:variable>
        <xsl:attribute name="name">
          <xsl:value-of select="concat(translate(@usage, $uppercase, $lowercase), '_', translate($roleType, $uppercase, $lowercase), '_Display')"/>
        </xsl:attribute>
        <xsl:call-template name="mods_produce_name"/>
      </field>
      <xsl:variable name="field_name">
        <xsl:value-of select="concat('ucar_', $this_prefix, translate(@usage, $uppercase, $lowercase), '_', translate(mods:role/mods:roleTerm[@type='text'], $uppercase, $lowercase), '_sort')"/>
      </xsl:variable>

      <field>
        <xsl:attribute name="name">
          <xsl:choose>
            <xsl:when test="java:add($single_valued_hashset, string($field_name))">
              <xsl:value-of select="concat($field_name, '_s')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat($field_name, '_ms')"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="mods:namePart[@type='family']"/>
        <xsl:if test="mods:namePart[@type='given']">
          <xsl:text>, </xsl:text>
        </xsl:if>
        <xsl:for-each select="mods:namePart[@type='given']">
          <xsl:value-of select="."/>
          <xsl:if test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </field>
    </xsl:if>

    <xsl:call-template name="mods_role_term">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="../.."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="mods:identifier[@type='uri']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">"pid"</xsl:param>
    <xsl:param name="datastream">'datastream'</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>

    <field>
      <xsl:variable name="identifierType">
        <xsl:value-of select="@type"/>
      </xsl:variable>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), '_type_', translate($identifierType, $uppercase, $lowercase))"/>
        <xsl:if test="@displayLabel">
          <xsl:value-of select="concat('_displayLabel_', translate(@displayLabel, ' ', '_'))"/>
        </xsl:if>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </field>
  </xsl:template>

  <xsl:template match="mods:identifier[@type='ark']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">"pid"</xsl:param>
    <xsl:param name="datastream">'datastream'</xsl:param>
    <xsl:param name="node" select="current()"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>

    <xsl:variable name="identifierType">
      <xsl:value-of select="@type"/>
    </xsl:variable>
    <xsl:variable name="thisprefix">
      <xsl:value-of select="concat($prefix, local-name(), '_', translate($identifierType, $uppercase, $lowercase), '_')"/>
    </xsl:variable>

    <field>
      <xsl:attribute name="name">mods_ark_uri</xsl:attribute>
      <xsl:value-of select="concat('http://n2t.net/', .)"/>
    </field>

    <xsl:variable name="value">
      <xsl:value-of select="."/>
    </xsl:variable>

    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="$thisprefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="mods:identifier[@type='doi']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">"pid"</xsl:param>
    <xsl:param name="datastream">'datastream'</xsl:param>
    <xsl:param name="node" select="current()"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>

    <xsl:variable name="identifierType">
      <xsl:value-of select="@type"/>
    </xsl:variable>
    <xsl:variable name="thisprefix">
      <xsl:value-of select="concat($prefix, local-name(), '_', translate($identifierType, $uppercase, $lowercase), '_')"/>
    </xsl:variable>

    <field>
      <xsl:attribute name="name">mods_doi_uri</xsl:attribute>
      <xsl:value-of select=" concat('http://dx.doi.org/', .)"/>
    </field>

    <xsl:variable name="value">
      <xsl:value-of select="."/>
    </xsl:variable>

    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="$thisprefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Intercept Collection Key to add an english readible name for
       faceting. -->
  <xsl:template match="mods:extension/osm:collectionKey" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="datastream">'datastream'</xsl:param>
    <xsl:param name="pid"/>
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="'mods_extension_collectionKey_ms'"/>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </field>

    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="'collectionName_ms'"/>
      </xsl:attribute>

      <xsl:variable name="CN" select="."/>

      <xsl:for-each select="$CNTable">
        <xsl:for-each select="key('CN-lookup', $CN)">
          <xsl:value-of select="collectionName"/>

        </xsl:for-each>
      </xsl:for-each>
    </field>

    <xsl:if test="((. = 'articles') or (. = 'technotes') or (. = 'books') or (. = 'conference') or (. = 'reports'))">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="'collectionLarge_ms'"/>
        </xsl:attribute>
        <xsl:value-of select="'Research'"/>
      </field>
    </xsl:if>

    <xsl:apply-templates mode="slurping_MODS">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="mods_produce_name">
    <xsl:for-each select="mods:namePart[@type='given']">
      <xsl:value-of select="."/>
      <xsl:text> </xsl:text>
    </xsl:for-each>
    <xsl:value-of select="mods:namePart[@type='family']"/>
    <xsl:if test="mods:namePart[@type='termsOfAddress']">
      <xsl:text>, </xsl:text>
      <xsl:value-of select="mods:namePart[@type='termsOfAddress']"/>
    </xsl:if>
  </xsl:template>

  <!-- Intercept names with role terms, so we can create copies of the fields
  including the role term in the name of generated fields. (Hurray, additional
  specificity!) -->
  <xsl:template name="mods_role_term">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:variable name="base_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(translate(@type, ' ', '_'), '_')"/>
      </xsl:if>
    </xsl:variable>
    <xsl:for-each select="mods:role/mods:roleTerm">
      <xsl:variable name="this_prefix" select="concat($base_prefix, translate(normalize-space(.), $uppercase, $lowercase), '_')"/>

      <xsl:call-template name="mods_language_fork">
        <xsl:with-param name="prefix" select="$this_prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="normalize-space(text())"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
        <xsl:with-param name="node" select="../.."/>
      </xsl:call-template>
    </xsl:for-each>

    <xsl:call-template name="mods_language_fork">
      <xsl:with-param name="prefix" select="$base_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Fields are duplicated for authority because searches across authorities are common. -->
  <xsl:template name="mods_authority_fork">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:param name="node" select="current()"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>

    <!-- Fields are duplicated for authority because searches across authorities are common. -->
    <xsl:if test="@authority">
      <xsl:call-template name="general_mods_field">
        <xsl:with-param name="prefix" select="concat($prefix, 'authority_', translate(@authority, $uppercase, $lowercase), '_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$value"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
        <xsl:with-param name="node" select="$node"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Fork on eventType to preserve legacy field names. -->
  <xsl:template name="mods_eventType_fork">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:param name="node" select="current()"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:call-template name="mods_language_fork">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>

    <xsl:if test="@eventType">
      <xsl:call-template name="mods_language_fork">
        <xsl:with-param name="prefix" select="concat($prefix, 'eventType_', translate(@eventType, $uppercase, $lowercase), '_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$value"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
        <xsl:with-param name="node" select="$node"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Want to include language in field names. -->
  <xsl:template name="mods_language_fork">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:param name="node" select="current()"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>

    <!-- Fields are duplicated for authority because searches across authorities are common. -->
    <xsl:if test="@lang">
      <xsl:call-template name="mods_authority_fork">
        <xsl:with-param name="prefix" select="concat($prefix, 'lang_', translate(@lang, $uppercase, $lowercase), '_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$value"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
        <xsl:with-param name="node" select="$node"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Handle the actual indexing of the majority of MODS elements, including
    the recursive step of kicking off the indexing of subelements. -->
  <xsl:template name="general_mods_field">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid"/>
    <xsl:param name="datastream"/>
    <xsl:param name="node" select="current()"/>

    <xsl:if test="$value">
      <field>
        <xsl:attribute name="name">
          <xsl:choose>
            <!-- Try to create a single-valued version of each field (if one
              does not already exist, that is). -->
            <!-- XXX: We make some assumptions about the schema here...
              Primarily, _s getting copied to the same places as _ms. -->
            <xsl:when test="$suffix='ms' and java:add($single_valued_hashset, string($prefix))">
              <xsl:value-of select="concat($prefix, 's')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat($prefix, $suffix)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="$value"/>
      </field>
    </xsl:if>
    <xsl:if test="normalize-space($node/@authorityURI)">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'authorityURI_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$node/@authorityURI"/>
      </field>
    </xsl:if>
    <xsl:if test="normalize-space($node/@valueURI)">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'valueURI_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$node/@valueURI"/>
      </field>
    </xsl:if>
    <xsl:if test="normalize-space($node/@xlink:href)">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'xlinkhref_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$node/@xlink:href"/>
      </field>
    </xsl:if>
    <xsl:if test="normalize-space($node/@displayLabel)">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'displayLabel_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$node/@displayLabel"/>
      </field>
    </xsl:if>
    <xsl:apply-templates select="$node/*" mode="slurping_MODS">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:apply-templates>
  </xsl:template>
</xsl:stylesheet>
