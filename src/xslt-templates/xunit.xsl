<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output encoding="UTF-8" />
  <xsl:preserve-space elements="*"/>
	<xsl:template match="/BEAKER_TEST">
		<testsuite name="{/BEAKER_TEST/testname}" tests="{count(./log/phase)}" failures="{count(./log/phase[@type = 'FAIL']/test[text() = 'FAIL'])}" errors="{count(./log/phase[@type = 'WARN']/test[text() = 'FAIL'])}" hostname="{/BEAKER_TEST/hostname}" id="{/BEAKER_TEST/test_id}" package="{/BEAKER_TEST/package}">
      <properties>
        <xsl:apply-templates select="./*" />
      </properties>
      <xsl:apply-templates select="/BEAKER_TEST/log/phase" />
    </testsuite>
	</xsl:template>

  <xsl:template match="/BEAKER_TEST/pkgnotinstalled">
    <property name="pkgnotinstalled" value="{/BEAKER_TEST/pkgnotinstalled}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/beakerlib_rpm">
    <property name="beakerlib_rpm" value="{/BEAKER_TEST/beakerlib_rpm}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/beakerlib_redhat_rpm">
    <property name="beakerlib_redhat_rpm" value="{/BEAKER_TEST/beakerlib_redhat_rpm}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/starttime">
    <property name="starttime" value="{/BEAKER_TEST/starttime}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/pkgdetails">
    <property name="pkgdetails" value="{/BEAKER_TEST/pkgdetails}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/endtime">
    <property name="endtime" value="{/BEAKER_TEST/endtime}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/release">
    <property name="release" value="{/BEAKER_TEST/release}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/arch">
    <property name="arch" value="{/BEAKER_TEST/arch}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/hw_cpu">
    <property name="hw_cpu" value="{/BEAKER_TEST/hw_cpu}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/hw_ram">
    <property name="hw_ram" value="{/BEAKER_TEST/hw_ram}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/hw_hdd">
    <property name="hw_hdd" value="{/BEAKER_TEST/hw_hdd}" />
  </xsl:template>

  <xsl:template match="/BEAKER_TEST/purpose">
    <property name="purpose" value="{/BEAKER_TEST/purpose}" />
  </xsl:template>

  <xsl:template match="phase">
  <testcase name="{@name}" assertions="{count(./test)}">
    <xsl:apply-templates select="./test" />
  </testcase>
  </xsl:template>

  <xsl:template match="phase[@type = 'FAIL']/test[text() = 'FAIL']">
    <error message="{@message}"></error>
  </xsl:template>

  <xsl:template match="phase[@type = 'WARN']/test[text() = 'FAIL']">
    <failure message="{@message}"></failure>
  </xsl:template>

  <xsl:template match="phase/test[text() = 'PASS']" />
  <xsl:template match="/BEAKER_TEST/*" />
</xsl:stylesheet>
