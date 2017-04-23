#!/usr/bin/python

# Authors:  Petr Muller     <pmuller@redhat.com>
#           Petr Splichal   <psplicha@redhat.com>
#           Ales Zelinka    <azelinka@redhat.com>
#           Martin Kudlej   <mkudlej@redhat.com>
#
# Description: Provides journalling capabilities for BeakerLib
#
# Copyright (c) 2008 Red Hat, Inc. All rights reserved. This copyrighted
# material is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.


from optparse import OptionParser
import sys
import os
import time
import re
import rpm
import socket
import types
from lxml import etree

timeFormat="%Y-%m-%d %H:%M:%S %Z"
xmlForbidden = (0,1,2,3,4,5,6,7,8,11,12,14,15,16,17,18,19,20,\
                21,22,23,24,25,26,27,28,29,30,31,0xFFFE,0xFFFF)
xmlTrans = dict([(x,None) for x in xmlForbidden])
termColors = {
  "PASS": "\033[0;32m",
  "FAIL": "\033[0;31m",
  "INFO": "\033[0;34m",
  "WARNING": "\033[0;33m" }

class Journal(object):
  #@staticmethod
  def wrap(text, width):
    return reduce(lambda line, word, width=width: '%s%s%s' %
                  (line,
                   ' \n'[(len(line)-line.rfind('\n')-1
                         + len(word.split('\n',1)[0]
                              ) >= width)],
                   word),
                  text.split(' ')
                 )
  wrap = staticmethod(wrap)

  #for output redirected to file, we must not rely on python's
  #automagic encoding detection - enforcing utf8 on unicode
  #@staticmethod
  def _print(message):
    if isinstance(message,types.UnicodeType):
      print message.encode('utf-8','replace')
    else:
      print message
  _print = staticmethod(_print)

  #@staticmethod
  def printPurpose(message):
    Journal.printHeadLog("Test description")
    Journal._print(Journal.wrap(message, 80))
  printPurpose = staticmethod(printPurpose)

  #@staticmethod
  def printLog(message, prefix="LOG"):
    color = uncolor = ""
    if sys.stdout.isatty() and prefix in ("PASS", "FAIL", "INFO", "WARNING"):
      color = termColors[prefix]
      uncolor = "\033[0m"
    for line in message.split("\n"):
      Journal._print(":: [%s%s%s] :: %s" % (color, prefix.center(10), uncolor, line))
  printLog = staticmethod(printLog)

  #@staticmethod
  def printHeadLog(message):
    print "\n::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    Journal.printLog(message)
    print "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
  printHeadLog = staticmethod(printHeadLog)

  #@staticmethod
  def getAllowedSeverities(treshhold):
    severities ={"DEBUG":0, "INFO":1, "WARNING":2, "ERROR":3, "FATAL":4, "LOG":5}
    allowed_severities = []
    for i in severities:
      if (severities[i] >= severities[treshhold]): allowed_severities.append(i)
    return allowed_severities
  getAllowedSeverities = staticmethod(getAllowedSeverities)

  #@staticmethod
  def printPhaseLog(phase,severity):
    phaseName = phase.get("name")
    phaseResult = phase.get("result")
    starttime = phase.get("starttime")
    endtime = phase.get("endtime")
    if endtime == "":
       endtime = time.strftime(timeFormat)
    try:
      duration = time.mktime(time.strptime(endtime,timeFormat)) - time.mktime(time.strptime(starttime,timeFormat))
    except ValueError:
    # I know about two occurences:
    #   - timezones / time messed with in the test
    #   - python cannot handle the format (probably a python bug)
      duration = None
    Journal.printHeadLog(phaseName)
    passed = 0
    failed = 0
    for node in phase.iterchildren():
      if node.tag == "message":
        if node.get("severity") in Journal.getAllowedSeverities(severity):
          text = Journal.__childNodeValue(node, 0)
          Journal.printLog(text, node.get("severity"))
      elif node.tag == "test":
        result = Journal.__childNodeValue(node, 0)
        if result == "FAIL":
          Journal.printLog("%s" % node.get("message"), "FAIL")
          failed += 1
        else:
          Journal.printLog("%s" % node.get("message"), "PASS")
          passed += 1
    if duration is not None:
      formatedDuration = ''
      if (duration // 3600 > 0):
          formatedDuration = "%ih " % (duration // 3600)
          duration = duration % 3600
      if (duration // 60 > 0):
          formatedDuration += "%im " % (duration // 60)
          duration = duration % 60
      formatedDuration += "%is" % duration
    else:
      formatedDuration = "duration unknown (error when computing)"
    Journal.printLog("Duration: %s" % formatedDuration)
    Journal.printLog("Assertions: %s good, %s bad" % (passed, failed))
    Journal.printLog("RESULT: %s" % phaseName, phaseResult)
    return failed
  printPhaseLog = staticmethod(printPhaseLog)

  # @staticmethod
  def __childNodeValue(node, id=0):
      # TODO THIS MIGHT BE WRONG !! NEEDS FURTHER TESTING
      if etree.iselement(node):
          try:
              return node.text
          except IndexError:
              return ''
      else:
          return ''

      # COMMENTED OUT
      """Safe variant for node.childNodes[id].nodeValue()"""
      # TODO WTF? is this test to check if method exists? shouldn't there be parentheses?
      # if node.hasChildNodes:
      # try:
      #  return node.childNodes[id].nodeValue
      # except IndexError:
      # return ''
      # else:
      #  return ''

  __childNodeValue = staticmethod(__childNodeValue)

  #@staticmethod
  def __get_hw_cpu():
    """Helper to read /proc/cpuinfo and grep count and type of CPUs from there"""
    count = 0
    type = 'unknown'
    try:
      fd = open('/proc/cpuinfo')
      expr = re.compile('^model name[\t ]+: +(.+)$')
      for line in fd.readlines():
        match = expr.search(line)
        if match != None:
          count += 1
          type = match.groups()[0]
      fd.close()
    except:
      pass
    return "%s x %s" % (count, type)
  __get_hw_cpu = staticmethod(__get_hw_cpu)

  #@staticmethod
  def __get_hw_ram():
    """Helper to read /proc/meminfo and grep size of RAM from there"""
    size = 'unknown'
    try:
      fd = open('/proc/meminfo')
      expr = re.compile('^MemTotal: +([0-9]+) +kB$')
      for line in fd.readlines():
        match = expr.search(line)
        if match != None:
          size = int(match.groups()[0])/1024
          break
      fd.close()
    except:
      pass
    return "%s MB" % size
  __get_hw_ram = staticmethod(__get_hw_ram)

  #@staticmethod
  def __get_hw_hdd():
    """Helper to parse size of disks from `df` output"""
    size = 0.0
    try:
      import subprocess
      output = subprocess.Popen(['df', '-k', '-P', '--local', '--exclude-type=tmpfs'], stdout=subprocess.PIPE).communicate()[0]
      output = output.split('\n')
    except ImportError:
      output = os.popen('df -k -P --local --exclude-type=tmpfs')
      output = output.readlines()
    expr = re.compile('^(/[^ ]+) +([0-9]+) +[0-9]+ +[0-9]+ +[0-9]+% +[^ ]+$')
    for line in output:
      match = expr.search(line)
      if match != None:
        size = size + float(match.groups()[1])/1024/1024
    if size == 0:
      return 'unknown'
    else:
      return "%.1f GB" % size
  __get_hw_hdd = staticmethod(__get_hw_hdd)

  #@staticmethod
  def createLog(severity, full_journal=False):
    jrnl = Journal.openJournal()
    Journal.printHeadLog("TEST PROTOCOL")
    phasesFailed = 0
    phasesProcessed = 0

    for node in jrnl.iter():
      if node.tag == "test_id":
        Journal.printLog("Test run ID   : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "package":
        Journal.printLog("Package       : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "testname":
        Journal.printLog("Test name     : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "pkgdetails":
        Journal.printLog("Installed     : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "release":
        Journal.printLog("Distro        : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "starttime":
        Journal.printLog("Test started  : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "endtime":
        Journal.printLog("Test finished : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "arch":
        Journal.printLog("Architecture  : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "hw_cpu" and full_journal:
        Journal.printLog("CPUs          : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "hw_ram" and full_journal:
        Journal.printLog("RAM size      : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "hw_hdd" and full_journal:
        Journal.printLog("HDD size      : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "beakerlib_rpm":
        Journal.printLog("beakerlib RPM : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "beakerlib_redhat_rpm":
        Journal.printLog("bl-redhat RPM : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "testversion":
        Journal.printLog("Test version  : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "testbuilt":
        Journal.printLog("Test built    : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "hostname":
        Journal.printLog("Hostname      : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "plugin":
        Journal.printLog("Plugin        : %s" % Journal.__childNodeValue(node, 0))
      elif node.tag == "purpose":
        Journal.printPurpose(Journal.__childNodeValue(node, 0))
      elif node.tag == "log":
        for nod in node.iterchildren():
          if nod.tag == "message":
            if nod.get("severity") in Journal.getAllowedSeverities(severity):
              # TODO Might be problematic len()
              if (len(nod) > 0):
                text = Journal.__childNodeValue(nod, 0)
              else:
                text = ""
              Journal.printLog(text, nod.get("severity"))
          elif nod.tag == "test":
            Journal.printLog("BEAKERLIB BUG: Assertion not in phase", "WARNING")
            result = Journal.__childNodeValue(nod, 0)
            if result == "FAIL":
              Journal.printLog("%s" % nod.get("message"), "FAIL")
            else:
              Journal.printLog("%s" % nod.get("message"), "PASS")
          elif nod.tag == "metric":
            Journal.printLog("%s: %s" % (nod.get("name"), Journal.__childNodeValue(nod, 0)), "METRIC")
          elif nod.tag == "phase":
            phasesProcessed += 1
            if Journal.printPhaseLog(nod,severity) > 0:
              phasesFailed += 1
    # TODO xpath problem?
    testName = Journal.__childNodeValue(jrnl.xpath("testname")[0],0)
    Journal.printHeadLog(testName)
    Journal.printLog("Phases: %d good, %d bad" % ((phasesProcessed - phasesFailed),phasesFailed))
    Journal.printLog("RESULT: %s" % testName, (phasesFailed == 0 and "PASS" or "FAIL"))
  createLog = staticmethod(createLog)


  #@staticmethod
  def getTestRpmBuilt(ts):
    package = os.getenv("packagename")
    if not package:
      return None

    testInfo = ts.dbMatch("name", package)
    if not testInfo:
      return None

    buildtime = time.gmtime(int(testInfo.next().format("%{BUILDTIME}")))
    return time.strftime(timeFormat, buildtime)
  getTestRpmBuilt = staticmethod(getTestRpmBuilt)

  #@staticmethod
  def determinePackage(test):
    envPackage = os.environ.get("PACKAGE")
    if not envPackage:
      try:
        envPackage = test.split("/")[2]
      except IndexError:
        envPackage = None
    return envPackage
  determinePackage = staticmethod(determinePackage)

  # @staticmethod
  def getRpmVersion(xmldoc, package, rpm_ts):
      rpms = []
      mi = rpm_ts.dbMatch("name", package)
      if len(mi) == 0:
          if package != 'unknown':
              pkgDetailsEl = etree.Element("pkgnotinstalled")
              pkgDetailsCon = "%s" % package
              rpms.append((pkgDetailsEl, pkgDetailsCon))
          else:
              return None

      for pkg in mi:
          pkgDetailsEl = etree.Element("pkgdetails", sourcerpm=pkg['sourcerpm'])
          pkgDetailsCon = "%(name)s-%(version)s-%(release)s.%(arch)s " % pkg
          rpms.append((pkgDetailsEl, pkgDetailsCon))

      return rpms
  getRpmVersion = staticmethod(getRpmVersion)

  #@staticmethod
  def collectPackageDetails(xmldoc, packages):
    pkgdetails = []
    pkgnames = packages

    if 'PKGNVR' in os.environ:
      for p in os.environ['PKGNVR'].split(','):
        pkgnames.append(p)
    if 'PACKAGES' in os.environ:
      for p in os.environ['PACKAGES'].split():
        if p not in pkgnames:
          pkgnames.append(p)
    if '__INTERNAL_RPM_ASSERTED_PACKAGES' in os.environ:
      for p in os.environ["__INTERNAL_RPM_ASSERTED_PACKAGES"].split():
        if p not in pkgnames:
          pkgnames.append(p)

    ts = rpm.ts()
    for pkgname in pkgnames:
      rpmVersions = Journal.getRpmVersion(xmldoc, pkgname, ts)
      if rpmVersions:
        pkgdetails.extend(rpmVersions)

    return pkgdetails
  collectPackageDetails = staticmethod(collectPackageDetails)

  #@staticmethod
  def initializeJournal(test, package):

    # if the journal already exists, do not overwrite it
    try: jrnl = Journal._openJournal()
    except: pass
    else: return 0

    testid = os.environ.get("TESTID")
    top_element = etree.Element("BEAKER_TEST")

    if testid:
      testidEl = etree.Element("test_id")
      testidEl.text = str(testid)

    packageEl = etree.Element("package")
    if not package:
      package = "unknown"
    packageEl.text = str(package)

    ts = rpm.ts()
    mi = ts.dbMatch("name", "beakerlib")

    beakerlibRpmEl = etree.Element("beakerlib_rpm")

    if mi:
      beakerlib_rpm = mi.next()
      beakerlibRpmEl.text = "%(name)s-%(version)s-%(release)s" % beakerlib_rpm
    else:
      beakerlibRpmEl.text = "not installed"

    mi = ts.dbMatch("name", "beakerlib-redhat")

    beakerlibRedhatRpmEl = etree.Element("beakerlib_redhat_rpm")

    if mi:
      beakerlib_redhat_rpm = mi.next()
      beakerlibRedhatRpmEl.text = "%(name)s-%(version)s-%(release)s" % beakerlib_redhat_rpm
    else:
      beakerlibRedhatRpmEl.text = "not installed"

    testRpmVersion = os.getenv("testversion")
    if testRpmVersion:
        testVersionEl = etree.Element("testversion")
        testVersionEl.text = testRpmVersion


    testRpmBuilt = Journal.getTestRpmBuilt(ts)
    if testRpmBuilt:
        testRpmBuildEl = etree.Element("testbuild")
        testRpmBuildEl.text = testRpmBuilt

    startedEl = etree.Element("starttime")
    startedEl.text = time.strftime(timeFormat)

    endedEl = etree.Element("endtime")
    endedEl.text = time.strftime(timeFormat)

    hostnameEl = etree.Element("hostname")
    hostnameEl.text = socket.getfqdn()

    archEl = etree.Element("arch")
    archEl.text = os.uname()[-1]

    hw_cpuEl = etree.Element("hw_cpu")
    hw_cpuEl.text = Journal.__get_hw_cpu()

    hw_ramEl = etree.Element("hw_ram")
    hw_ramEl.text = Journal.__get_hw_ram()

    hw_hddEl = etree.Element("hw_hdd")
    hw_hddEl.text = Journal.__get_hw_hdd()

    testEl = etree.Element("testname")
    if (test):
      testEl.text = str(test)
    else:
      testEl.text = "unknown"

    pkgdetails = Journal.collectPackageDetails(top_element, [package])

    releaseEl = etree.Element("release")

    try:
      with open("/etc/redhat-release", "r") as release_file:
        release = release_file.read().strip()
    except IOError:
      release = "unknown"
    release = unicode(release, 'utf-8', errors='replace')
    releaseEl.text = release.translate(xmlTrans)

    logEl = etree.Element("log")

    purposeEl = etree.Element("purpose")

    if os.path.exists("PURPOSE"):
      try:
        purpose_file = open("PURPOSE", 'r')
        purpose = purpose_file.read()
        purpose_file.close()
      except IOError:
        print("Cannot read PURPOSE file: %s" % sys.exc_info()[1])
        return 1
    else:
      purpose = ""

    purpose = unicode(purpose, 'utf-8', errors='replace')
    purposeEl.text = purpose.translate(xmlTrans)

    shre = re.compile(".+\.sh$")
    bpath = os.environ["BEAKERLIB"]
    plugpath = os.path.join(bpath, "plugins") # TODO ERROR ? imho to ma byt plugins a ne plugin
    plugins=[]

    if os.path.exists(plugpath):
      for file in os.listdir(plugpath):
        if shre.match(file):
          plugEl = etree.Element("plugin")
          plugEl.text = file
          plugins.append((plugEl, plugEl.text))

    for installed_pkg in pkgdetails:
        installed_pkg[0].text = installed_pkg[1]

    for plug in plugins:
        plug[0].text = plug[1]

    if testid:
      top_element.append(testidEl)

    top_element.append(packageEl)
    for installed_pkg in pkgdetails:
        top_element.append(installed_pkg[0])

    top_element.append(beakerlibRpmEl)
    top_element.append(beakerlibRedhatRpmEl)


    if testRpmVersion:
      top_element.append(testVersionEl)
    if testRpmBuilt:
      top_element.append(testRpmBuildEl)

    top_element.append(startedEl)
    top_element.append(endedEl)
    top_element.append(testEl)
    top_element.append(releaseEl)
    top_element.append(hostnameEl)
    top_element.append(archEl)
    top_element.append(hw_cpuEl)
    top_element.append(hw_ramEl)
    top_element.append(hw_hddEl)

    for plug in plugins:
      top_element.append(plug[0])
    top_element.append(purposeEl)
    top_element.append(logEl)

    return Journal.saveJournal(top_element)
  initializeJournal = staticmethod(initializeJournal)

  #@staticmethod
  def saveJournal(top_element):
    journal = os.environ['BEAKERLIB_JOURNAL']
    try:
      output = open(journal, 'wb')
      output.write(etree.tostring(top_element, xml_declaration=True, encoding='utf-8'))
      output.close()
      return 0
    except IOError, e:
      Journal.printLog('Failed to save journal to %s: %s' % (top_element, str(e)), 'BEAKERLIB_WARNING')
      return 1
  saveJournal = staticmethod(saveJournal)

  #@staticmethod
  def _openJournal():
    journal = os.environ['BEAKERLIB_JOURNAL']
    jrnl = etree.parse(journal)
    return jrnl
  _openJournal = staticmethod(_openJournal)

  #@staticmethod
  def openJournal():
    try:
      jrnl = Journal._openJournal()
    except (IOError, EOFError):
      Journal.printLog('Journal not initialised? Trying it now.', 'BEAKERLIB_WARNING')
      envTest = os.environ.get("TEST")
      package = Journal.determinePackage(envTest)
      Journal.initializeJournal(envTest, package)
      jrnl = Journal._openJournal()
    return jrnl
  openJournal = staticmethod(openJournal)

  # TODO WHY? for always returns first one, and what if none there? and if always only 1 why then for loop?
  # @staticmethod
  def getLogEl(jrnl):
      node = jrnl.xpath('//log')
      if node:
          return node[0]
      # TODO improve
      else:
          Journal.printLog("Failed to find \'log\' element")
          sys.exit(1)
  getLogEl = staticmethod(getLogEl)

  #@staticmethod
  def getLastUnfinishedPhase(tree):
    candidate = tree
    for node in tree.xpath('//phase'):
        if node.get('result') == 'unfinished':
            candidate = node
        return candidate
  getLastUnfinishedPhase = staticmethod(getLastUnfinishedPhase)

  #@staticmethod
  def addPhase(name, phase_type):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)

    name = unicode(name, 'utf-8', errors='replace')

    phase = etree.Element("phase")
    phase.set("name", name.translate(xmlTrans))
    phase.set("result", 'unfinished')

    phase_type = unicode(phase_type, 'utf-8', errors='replace')
    phase.set("type", phase_type.translate(xmlTrans))
    phase.set("starttime", time.strftime(timeFormat))
    phase.set("endtime", "")

    pkgdetails = Journal.collectPackageDetails(jrnl, [])

    for installed_pkg in pkgdetails:
      phase.append(installed_pkg[0])

    log.append(phase)

    return Journal.saveJournal(jrnl)
  addPhase = staticmethod(addPhase)

  #@staticmethod
  def getPhaseState(phase):
    passed = failed = 0
    for node in phase:
        if node.tag == "test":
            result = Journal.__childNodeValue(node, 0)
            if result == "FAIL":
                failed += 1
            else:
                passed += 1
    return (passed, failed)
  getPhaseState = staticmethod(getPhaseState)

  # @staticmethod
  def finPhase():
      jrnl = Journal.openJournal()
      phase = Journal.getLastUnfinishedPhase(Journal.getLogEl(jrnl))
      type = phase.get('type')
      name = phase.get('name')
      # TODO xpath problem
      end = jrnl.xpath('endtime')
      timeNow = time.strftime(timeFormat)
      end[0].text = timeNow
      phase.set("endtime", timeNow)
      (passed, failed) = Journal.getPhaseState(phase)
      if failed == 0:
          phase.set("result", 'PASS')
      else:
          phase.set("result", type)

      phase.set('score', str(failed))
      Journal.saveJournal(jrnl)
      return (phase.get('result'), phase.get('score'), type, name)
  finPhase = staticmethod(finPhase)

  # TODO not used? Error in  'name' var
  #@staticmethod
  def getPhase(tree):
    for node in tree.xpath("phase"):
      if node.getAttribute("name") == name:
        return node
    return tree
  getPhase = staticmethod(getPhase)

  #@staticmethod
  def testState():
    jrnl  = Journal.openJournal()
    failed = 0

    for phase in jrnl.xpath('//phase'):
      failed += Journal.getPhaseState(phase)[1]
    if failed >255:
        failed = 255
    return failed
  testState = staticmethod(testState)

  #@staticmethod
  def phaseState():
    jrnl  = Journal.openJournal()
    phase = Journal.getLastUnfinishedPhase(Journal.getLogEl(jrnl))
    failed = Journal.getPhaseState(phase)[1]
    if failed >255:
        failed = 255
    return failed
  phaseState = staticmethod(phaseState)

  #@staticmethod
  def addMessage(message, severity):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    add_to = Journal.getLastUnfinishedPhase(log)

    msg = etree.Element("message")
    msg.set("severity", severity)

    message = unicode(message, 'utf-8', errors='replace')

    msgText = message.translate(xmlTrans)
    msg.text = msgText

    add_to.append(msg)
    return Journal.saveJournal(jrnl)
  addMessage = staticmethod(addMessage)

  #@staticmethod
  def addTest(message, result="FAIL", command=None):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    add_to = Journal.getLastUnfinishedPhase(log)

    if add_to == log: # no phase open
      return 1

    message = unicode(message, 'utf-8', errors='replace')
    msg = etree.Element("test")
    msg.set("message", message.translate(xmlTrans))

    if command:
      command = unicode(command, 'utf-8', errors='replace')
      msg.set("command", command.translate(xmlTrans))

    msg.text = result
    add_to.append(msg)

    return Journal.saveJournal(jrnl)
  addTest = staticmethod(addTest)

  #@staticmethod
  def logRpmVersion(package):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    add_to = Journal.getLastUnfinishedPhase(log)
    ts = rpm.ts()
    rpms = Journal.getRpmVersion(jrnl, package, ts)
    for pkg in rpms:
      pkgEl, pkgCon = pkg
      pkgEl.text = pkgCon
      add_to.append(pkgEl)
    return Journal.saveJournal(jrnl)
  logRpmVersion = staticmethod(logRpmVersion)

  #@staticmethod
  def addMetric(type, name, value, tolerance):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    add_to = Journal.getLastUnfinishedPhase(log)

    for node in add_to.xpath('metric'):
      if node.get('name') == name:
        raise Exception("Metric name not unique!")

    metric = etree.Element("metric")
    metric.set("type", type)
    metric.set("name", name)
    metric.set("tolerance", str(tolerance))

    metric.text = str(value)
    add_to.append(metric)

    return Journal.saveJournal(jrnl)
  addMetric = staticmethod(addMetric)

  #@staticmethod
  def dumpJournal(type):
    if type == "raw":
      print etree.tostring(Journal.openJournal(), encoding="utf-8", xml_declaration=True)
    elif type == "pretty":
      print etree.tostring(Journal.openJournal(), pretty_print=True, encoding="utf-8", xml_declaration=True)
    else:
      print "Journal dump error: bad type specification"
  dumpJournal = staticmethod(dumpJournal)

  def need(args):
      if None in args:
          print "Specified command is missing a required option"
          return 1

def need(args):
  if None in args:
    print "Specified command is missing a required option"
    return 1

def main(_1='', _2='', _3='', _4='', _5='', _6='', _7='', _8='', _9='', _10=''):
  DESCRIPTION = "Wrapper for operations above BeakerLib journal"
  optparser = OptionParser(description=DESCRIPTION)

  optparser.add_option("-p", "--package", default=None, dest="package", metavar="PACKAGE")
  optparser.add_option("-t", "--test", default=None, dest="test", metavar="TEST")
  optparser.add_option("-n", "--name", default=None, dest="name", metavar="NAME")
  optparser.add_option("-s", "--severity", default=None, dest="severity", metavar="SEVERITY")
  optparser.add_option("-f", "--full-journal", action="store_true", default=False, dest="full_journal", metavar="FULL_JOURNAL")
  optparser.add_option("-m", "--message", default=None, dest="message", metavar="MESSAGE")
  optparser.add_option("-r", "--result", default=None, dest="result")
  optparser.add_option("-v", "--value", default=None, dest="value")
  optparser.add_option("--tolerance", default=None, dest="tolerance")
  optparser.add_option("--type", default=None, dest="type")
  optparser.add_option("-c", "--command", default=None, dest="command", metavar="COMMAND")

  args_in = [_1, _2, _3, _4, _5, _6, _7, _8, _9, _10]
  if len(reduce(lambda x, y: x + y, args_in)) > 0:
    (options, args) = optparser.parse_args(args_in)
  else:
    (options, args) = optparser.parse_args()

  if len(args) != 1:
    print "Non-option arguments present, argc: %s" % len(args)
    return 1

  if not 'BEAKERLIB_JOURNAL' in os.environ:
    print "BEAKERLIB_JOURNAL not defined in the environment"
    return 1

  command = args[0]

  if command == "init":
    ret_need = need((options.test, ))
    if ret_need > 0:
      return ret_need
    package = Journal.determinePackage(options.test)
    return Journal.initializeJournal(options.test, package)
  elif command == "dump":
    ret_need = need((options.type, ))
    if ret_need > 0:
      return ret_need
    Journal.dumpJournal(options.type)
  elif command == "printlog":
    ret_need = need((options.severity, options.full_journal))
    if ret_need > 0:
      return ret_need
    Journal.createLog(options.severity, options.full_journal)
  elif command == "addphase":
    ret_need = need((options.name, options.type))
    if ret_need > 0:
      return ret_need
    ret_need = Journal.addPhase(options.name, options.type)
    if ret_need > 0:
      return ret_need
    Journal.printHeadLog(options.name)
  elif command == "log":
    ret_need = need((options.message, ))
    if ret_need > 0:
      return ret_need
    severity = options.severity
    if severity is None:
      severity = "LOG"
    return Journal.addMessage(options.message, severity)
  elif command == "test":
    ret_need = need((options.message, ))
    if ret_need > 0:
      return ret_need
    result = options.result
    if result is None:
      result = "FAIL"
    if Journal.addTest(options.message, result, options.command):
      return 1
    Journal.printLog(options.message, result)
  elif command == "metric":
    ret_need = need((options.name, options.type, options.value, options.tolerance))
    if ret_need > 0:
      return ret_need
    try:
      return Journal.addMetric(options.type, options.name, float(options.value), float(options.tolerance))
    except:
      return 1
  elif command == "finphase":
    result, score, type_r, name = Journal.finPhase()
    Journal._print("%s:%s:%s" % (type_r, result, name))
    try:
      return int(score)
    except:
      return 1
  elif command == "teststate":
    failed = Journal.testState()
    return failed
  elif command == "phasestate":
    failed = Journal.phaseState()
    return failed
  elif command == "rpm":
    ret_need = need((options.package, ))
    if ret_need > 0:
      return ret_need
    # TODO SMAZAT
    #with open('/home/jheger/counter.txt', 'a') as the_file:
     #   the_file.write('logRpmVersion() 880')
    Journal.logRpmVersion(options.package)
  return 0

if __name__ == "__main__":
    """
    # TEMP setting environ vars for testing
    os.environ['BEAKERLIB_JOURNAL'] = "/home/jheger/atmp/jrnl.lxml"
    os.environ['TEST'] = "/CoreOS/bash/Regression/bz1172214-pattern-substitution-parameter-expansion-memleak"
    os.environ['BEAKERLIB'] = "/usr/share/beakerlib"

    jrnl = Journal()
    jrnl.addPhase("phase1", "random_comm")
    jrnl.addTest("lorem ipsum", result="FAIL", command="cat /etc/passwd")
    jrnl.addTest("dolor sit amet", result="PASS", command="touch /etc/passwd")
    jrnl.addTest("consectetur", result="FAIL", command="cp /etc/passwd .")
    jrnl.addMessage("testmessaegaa", "LOG")
    jrnl.finPhase()
    # jrnl.addMetric("tip", "testname", "testvalue", "testtolerance")
    # print "testState:", jrnl.testState()

    #jrnl.createLog("LOG", full_journal=True)

    jrnl.dumpJournal("pretty")
    exit(222)
    """
    sys.exit(main())
