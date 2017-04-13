#!/usr/bin/python

from lxml import etree
import os
import re
import sys
import types
import rpm
import time
import socket


timeFormat="%Y-%m-%d %H:%M:%S %Z"
xmlForbidden = (0,1,2,3,4,5,6,7,8,11,12,14,15,16,17,18,19,20,\
                21,22,23,24,25,26,27,28,29,30,31,0xFFFE,0xFFFF)
xmlTrans = dict([(x,None) for x in xmlForbidden])
termColors = {
  "PASS": "\033[0;32m",
  "FAIL": "\033[0;31m",
  "INFO": "\033[0;34m",
  "WARNING": "\033[0;33m" }



from xml.dom.minidom import getDOMImplementation
import xml.dom.minidom


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
    phaseName = phase.getAttribute("name")
    phaseResult = phase.getAttribute("result")
    starttime = phase.getAttribute("starttime")
    endtime = phase.getAttribute("endtime")
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
    for node in phase.childNodes:
      if node.nodeName == "message":
        if node.getAttribute("severity") in Journal.getAllowedSeverities(severity):
          text = Journal.__childNodeValue(node, 0)
          Journal.printLog(text, node.getAttribute("severity"))
      elif node.nodeName == "test":
        result = Journal.__childNodeValue(node, 0)
        if result == "FAIL":
          Journal.printLog("%s" % node.getAttribute("message"), "FAIL")
          failed += 1
        else:
          Journal.printLog("%s" % node.getAttribute("message"), "PASS")
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

  #@staticmethod
  def __childNodeValue(node, id=0):
    # ADDED
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
    #if node.hasChildNodes:
     # try:
      #  return node.childNodes[id].nodeValue
     # except IndexError:
       # return ''
   #else:
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

    for node in jrnl.childNodes[0].childNodes:
      if node.nodeName == "test_id":
        Journal.printLog("Test run ID   : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "package":
        Journal.printLog("Package       : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "testname":
        Journal.printLog("Test name     : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "pkgdetails":
        Journal.printLog("Installed     : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "release":
        Journal.printLog("Distro        : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "starttime":
        Journal.printLog("Test started  : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "endtime":
        Journal.printLog("Test finished : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "arch":
        Journal.printLog("Architecture  : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "hw_cpu" and full_journal:
        Journal.printLog("CPUs          : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "hw_ram" and full_journal:
        Journal.printLog("RAM size      : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "hw_hdd" and full_journal:
        Journal.printLog("HDD size      : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "beakerlib_rpm":
        Journal.printLog("beakerlib RPM : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "beakerlib_redhat_rpm":
        Journal.printLog("bl-redhat RPM : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "testversion":
        Journal.printLog("Test version  : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "testbuilt":
        Journal.printLog("Test built    : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "hostname":
        Journal.printLog("Hostname      : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "plugin":
        Journal.printLog("Plugin        : %s" % Journal.__childNodeValue(node, 0))
      elif node.nodeName == "purpose":
        Journal.printPurpose(Journal.__childNodeValue(node, 0))
      elif node.nodeName == "log":
        for nod in node.childNodes:
          if nod.nodeName == "message":
            if nod.getAttribute("severity") in Journal.getAllowedSeverities(severity):
              if (len(nod.childNodes) > 0):
                text = Journal.__childNodeValue(nod, 0)
              else:
                text = ""
              Journal.printLog(text, nod.getAttribute("severity"))
          elif nod.nodeName == "test":
            Journal.printLog("BEAKERLIB BUG: Assertion not in phase", "WARNING")
            result = Journal.__childNodeValue(nod, 0)
            if result == "FAIL":
              Journal.printLog("%s" % nod.getAttribute("message"), "FAIL")
            else:
              Journal.printLog("%s" % nod.getAttribute("message"), "PASS")
          elif nod.nodeName == "metric":
            Journal.printLog("%s: %s" % (nod.getAttribute("name"), Journal.__childNodeValue(nod, 0)), "METRIC")
          elif nod.nodeName == "phase":
            phasesProcessed += 1
            if Journal.printPhaseLog(nod,severity) > 0:
              phasesFailed += 1

    testName = Journal.__childNodeValue(jrnl.getElementsByTagName("testname")[0],0)
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

  #@staticmethod
  def getRpmVersion(xmldoc, package, rpm_ts):
    rpms = []
    # ADDED
    lxml_rpms = []
    mi = rpm_ts.dbMatch("name", package)
    if len(mi) == 0:
      if package != 'unknown':
        pkgDetailsEl = xmldoc.createElement("pkgnotinstalled")
        # ADDED
        lxml_pkgDetailsEl = etree.Element("pkgnotinstalled")
        pkgDetailsCon = xmldoc.createTextNode("%s" % package)
        # ADDED
        lxml_pkgDetailsCon = "%s" % package
        rpms.append((pkgDetailsEl, pkgDetailsCon))
        # ADDED
        lxml_rpms.append((lxml_pkgDetailsEl, lxml_pkgDetailsCon))
      else:
        return None

    for pkg in mi:
      # COMMENTED OUT
      #pkgDetailsEl = xmldoc.createElement("pkgdetails")
      #pkgDetailsEl.setAttribute('sourcerpm', pkg['sourcerpm'])
      #pkgDetailsCon = xmldoc.createTextNode("%(name)s-%(version)s-%(release)s.%(arch)s " % pkg)
      #rpms.append((pkgDetailsEl, pkgDetailsCon))
      # ADDED
      lxml_pkgDetailsEl = etree.Element("pkgdetails", sourcerpm=pkg['sourcerpm'])
      lxml_pkgDetailsCon = "%(name)s-%(version)s-%(release)s.%(arch)s " % pkg
      lxml_rpms.append((lxml_pkgDetailsEl, lxml_pkgDetailsCon))

    return rpms, lxml_rpms
  getRpmVersion = staticmethod(getRpmVersion)

  #@staticmethod
  def collectPackageDetails(xmldoc, packages):
    pkgdetails = []
    # ADDED
    lxml_pkgdetails = []
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
      rpmVersions, lxml_rpmVersions = Journal.getRpmVersion(xmldoc, pkgname, ts)
      if rpmVersions:
        pkgdetails.extend(rpmVersions)
      # ADDED
      if lxml_rpmVersions:
        lxml_pkgdetails.extend(lxml_rpmVersions)

    return pkgdetails, lxml_pkgdetails
  collectPackageDetails = staticmethod(collectPackageDetails)

  #@staticmethod
  def initializeJournal(test, package):

    # if the journal already exists, do not overwrite it
    try: jrnl = Journal._openJournal()
    except: pass
    else: return 0

    testid = os.environ.get("TESTID")

    impl = getDOMImplementation()
    newdoc = impl.createDocument(None, "BEAKER_TEST", None)

    top_element = newdoc.documentElement

    # ADDED
    lxml_top_element = etree.Element("BEAKER_TEST")

    if testid:
      testidEl    = newdoc.createElement("test_id")
      testidCon   = newdoc.createTextNode(str(testid))
      # ADDED
      lxml_testidEl = etree.Element("test_id")
      lxml_testidEl.text = str(testid)

    packageEl   = newdoc.createElement("package")
    # ADDED
    lxml_packageEl = etree.Element("package")
    if not package:
      package = "unknown"
    packageCon = newdoc.createTextNode(str(package))
    lxml_packageEl.text = str(package)

    ts = rpm.ts()
    mi = ts.dbMatch("name", "beakerlib")
    beakerlibRpmEl = newdoc.createElement("beakerlib_rpm")

    # ADDED
    lxml_beakerlibRpmEl = etree.Element("beakerlib_rpm")

    if mi:
      beakerlib_rpm = mi.next()
      beakerlibRpmCon = newdoc.createTextNode("%(name)s-%(version)s-%(release)s" % beakerlib_rpm)
      # ADDED
      lxml_beakerlibRpmEl.text = "%(name)s-%(version)s-%(release)s" % beakerlib_rpm
    else:
      beakerlibRpmCon = newdoc.createTextNode("not installed")
      # ADDED
      lxml_beakerlibRpmEl.text = "not installed"

    mi = ts.dbMatch("name", "beakerlib-redhat")
    beakerlibRedhatRpmEl = newdoc.createElement("beakerlib_redhat_rpm")

    # ADDED
    lxml_beakerlibRedhatRpmEl = etree.Element("beakerlib_redhat_rpm")

    if mi:
      beakerlib_redhat_rpm = mi.next()
      beakerlibRedhatRpmCon = newdoc.createTextNode("%(name)s-%(version)s-%(release)s" % beakerlib_redhat_rpm)
      # ADDED
      lxml_beakerlibRedhatRpmEl.text = "%(name)s-%(version)s-%(release)s" % beakerlib_redhat_rpm
    else:
      beakerlibRedhatRpmCon = newdoc.createTextNode("not installed")
      # ADDED
      lxml_beakerlibRedhatRpmEl.text = "not installed"

    testRpmVersion = os.getenv("testversion")
    if testRpmVersion:
        testVersionEl = newdoc.createElement("testversion")
        testVersionCon = newdoc.createTextNode(testRpmVersion)

        # ADDED
        lxml_testVersionEl = etree.Element("testversion")
        lxml_testVersionEl.text = testRpmVersion



    testRpmBuilt = Journal.getTestRpmBuilt(ts)
    if testRpmBuilt:
        testRpmBuiltEl = newdoc.createElement("testbuilt")
        testRpmBuiltCon = newdoc.createTextNode(testRpmBuilt)

        # ADDED
        lxml_testRpmBuildEl = etree.Element("testbuild")
        xml_testRpmBuildEl.text = testRpmBuilt

    # TODO WHY are these times here? they are identical
    startedEl   = newdoc.createElement("starttime")
    startedCon  = newdoc.createTextNode(time.strftime(timeFormat))

    # ADDED
    lxml_startedEl = etree.Element("starttime")
    lxml_startedEl.text = time.strftime(timeFormat)

    endedEl     = newdoc.createElement("endtime")
    endedCon    = newdoc.createTextNode(time.strftime(timeFormat))

    # ADDED
    lxml_endedEl = etree.Element("endtime")
    lxml_endedEl.text = time.strftime(timeFormat)


    hostnameEl     = newdoc.createElement("hostname")
    hostnameCon   = newdoc.createTextNode(socket.getfqdn())

    #ADDED
    lxml_hostnameEl = etree.Element("hostname")
    lxml_hostnameEl.text = socket.getfqdn()

    archEl     = newdoc.createElement("arch")
    archCon   = newdoc.createTextNode(os.uname()[-1])

    # ADDED
    lxml_archEl = etree.Element("arch")
    lxml_archEl.text = os.uname()[-1]

    hw_cpuEl    = newdoc.createElement("hw_cpu")
    hw_cpuCon   = newdoc.createTextNode(Journal.__get_hw_cpu())

    # ADDED
    lxml_hw_cpuEl = etree.Element("hw_cpu")
    lxml_hw_cpuEl.text = Journal.__get_hw_cpu()

    hw_ramEl    = newdoc.createElement("hw_ram")
    hw_ramCon   = newdoc.createTextNode(Journal.__get_hw_ram())

    # ADDED
    lxml_hw_ramEl = etree.Element("hw_ram")
    lxml_hw_ramEl.text = Journal.__get_hw_ram()

    hw_hddEl    = newdoc.createElement("hw_hdd")
    hw_hddCon   = newdoc.createTextNode(Journal.__get_hw_hdd())

    # ADDED
    lxml_hw_hddEl = etree.Element("hw_hdd")
    lxml_hw_hddEl.text = Journal.__get_hw_hdd()

    testEl      = newdoc.createElement("testname")
    # ADDED
    lxml_testEl = etree.Element("testname")
    if (test):
      testCon = newdoc.createTextNode(str(test))
      lxml_testEl.text = str(test)
    else:
      testCon = newdoc.createTextNode("unknown")
      lxml_testEl.text = "unknown"


    # TODO NEED TO CHANGE newdoc !!!
    pkgdetails, lxml_pkgdetails = Journal.collectPackageDetails(lxml_top_element, [package])

    releaseEl   = newdoc.createElement("release")
    # ADDED TODO add Con ^
    lxml_releaseEl = etree.Element("release")


    try:
      with open("/etc/redhat-release", "r") as release_file:
        release = release_file.read().strip()
    except IOError:
      release = "unknown"
    release = unicode(release, 'utf-8', errors='replace')
    releaseCon  = newdoc.createTextNode(release.translate(xmlTrans))
    #ADDED
    lxml_releaseEl.text = release.translate(xmlTrans)

    logEl = newdoc.createElement("log")

    # ADDED TODO
    lxml_logEl = etree.Element("log")

    purposeEl   = newdoc.createElement("purpose")

    # ADDED
    lxml_purposeEl = etree.Element("purpose")

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
    purposeCon  = newdoc.createTextNode(purpose.translate(xmlTrans))
    # ADDED
    lxml_purposeEl.text = purpose.translate(xmlTrans)

    shre = re.compile(".+\.sh$")
    bpath = os.environ["BEAKERLIB"]
    plugpath = os.path.join(bpath, "plugins") # TODO ERROR ? imho to ma byt plugins a ne plugin
    plugins = []
    # ADDED
    lxml_plugins=[]

    if os.path.exists(plugpath):
      for file in os.listdir(plugpath):
        if shre.match(file):
          plugEl = newdoc.createElement("plugin")
          # ADDED
          lxml_plugEl = etree.Element("plugin")
          lxml_plugEl.text = file

          plugCon = newdoc.createTextNode(file)
          plugins.append((plugEl, plugCon))
          # ADDED
          lxml_plugins.append((lxml_plugEl, lxml_plugEl.text))

    if testid:
      testidEl.appendChild(testidCon)
    packageEl.appendChild(packageCon)
    for installed_pkg in pkgdetails:
      installed_pkg[0].appendChild(installed_pkg[1])
    # ADDED
    for installed_pkg in lxml_pkgdetails:
        installed_pkg[0].text = installed_pkg[1]
    beakerlibRpmEl.appendChild(beakerlibRpmCon)
    beakerlibRedhatRpmEl.appendChild(beakerlibRedhatRpmCon)
    startedEl.appendChild(startedCon)
    endedEl.appendChild(endedCon)
    testEl.appendChild(testCon)
    releaseEl.appendChild(releaseCon)
    purposeEl.appendChild(purposeCon)
    hostnameEl.appendChild(hostnameCon)
    archEl.appendChild(archCon)
    hw_cpuEl.appendChild(hw_cpuCon)
    hw_ramEl.appendChild(hw_ramCon)
    hw_hddEl.appendChild(hw_hddCon)


    #"""
    #print top_element.toprettyxml()
    #print testVersionEl.toxml()
    #print testRpmBuiltEl.toxml()
    #print "----"
    #print etree.tostring(lxml_top_element, xml_declaration=True, pretty_print=True)
    #print etree.tostring(lxml_packageEl)
    #print etree.tostring(lxml_beakerlibRpmEl)
    #print etree.tostring(lxml_beakerlibRedhatRpmEl)
    #print etree.tostring(lxml_testVersionEl)
    #print etree.tostring(lxml_testRpmBuildEl)
    #"""


    for plug in plugins:
      plug[0].appendChild(plug[1])

    # ADDED
    for plug in lxml_plugins:
        plug[0].text = plug[1]

    if testid:
      top_element.appendChild(testidEl)
      # ADDED
      lxml_top_element.append(lxml_testidEl)
    top_element.appendChild(packageEl)
    # ADDED
    lxml_top_element.append(lxml_packageEl)
    for installed_pkg in pkgdetails:
      top_element.appendChild(installed_pkg[0])
    # ADDED
    for installed_pkg in lxml_pkgdetails:
        lxml_top_element.append(installed_pkg[0])

    top_element.appendChild(beakerlibRpmEl)
    top_element.appendChild(beakerlibRedhatRpmEl)

    # ADDED
    lxml_top_element.append(lxml_beakerlibRpmEl)
    lxml_top_element.append(lxml_beakerlibRedhatRpmEl)


    if testRpmVersion:
      testVersionEl.appendChild(testVersionCon)
      top_element.appendChild(testVersionEl)
      # ADDED
      lxml_top_element.append(lxml_testVersionEl)
    if testRpmBuilt:
      testRpmBuiltEl.appendChild(testRpmBuiltCon)
      top_element.appendChild(testRpmBuiltEl)
      # ADDED
      lxml_top_element.append(lxml_testRpmBuildEl)

    top_element.appendChild(startedEl)
    top_element.appendChild(endedEl)
    top_element.appendChild(testEl)
    top_element.appendChild(releaseEl)
    top_element.appendChild(hostnameEl)
    top_element.appendChild(archEl)
    top_element.appendChild(hw_cpuEl)
    top_element.appendChild(hw_ramEl)
    top_element.appendChild(hw_hddEl)

    for plug in plugins:
      top_element.appendChild(plug[0])
    top_element.appendChild(purposeEl)
    top_element.appendChild(logEl)

    # ADDED
    lxml_top_element.append(lxml_startedEl)
    lxml_top_element.append(lxml_endedEl)
    lxml_top_element.append(lxml_testEl)
    lxml_top_element.append(lxml_releaseEl)
    lxml_top_element.append(lxml_hostnameEl)
    lxml_top_element.append(lxml_archEl)
    lxml_top_element.append(lxml_hw_cpuEl)
    lxml_top_element.append(lxml_hw_ramEl)
    lxml_top_element.append(lxml_hw_hddEl)

    for plug in lxml_plugins:
      lxml_top_element.append(plug[0])
    lxml_top_element.append(lxml_purposeEl)
    lxml_top_element.append(lxml_logEl)

    return Journal.saveJournal(lxml_top_element)
  initializeJournal = staticmethod(initializeJournal)

  #@staticmethod
  def saveJournal(lxml_top_element):
    journal = os.environ['BEAKERLIB_JOURNAL']
    try:
      # COMMENTED OUT
      #output = open(journal, 'wb')
      #output.write(newdoc.toxml().encode('utf-8'))
      #output.close()
      # ADDED
      lxml_output = open(journal, 'wb')
      lxml_output.write(etree.tostring(lxml_top_element, xml_declaration=True, encoding='utf-8'))
      lxml_output.close()
      return 0
    except IOError, e:
      # COMMENTED OUT
      #Journal.printLog('Failed to save journal to %s: %s' % (journal, str(e)), 'BEAKERLIB_WARNING')
      # ADDED
      Journal.printLog('Failed to save journal to %s: %s' % (lxml_journal, str(e)), 'BEAKERLIB_WARNING')
      return 1
  saveJournal = staticmethod(saveJournal)

  #@staticmethod
  def _openJournal():
    journal = os.environ['BEAKERLIB_JOURNAL']
    #jrnl = xml.dom.minidom.parse(journal)
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
  #@staticmethod
  def getLogEl(jrnl):
    # ADDED
    node = jrnl.xpath('log')
    if node:
        return node[0]
    # TODO improve
    else:
        Journal.printLog("Failed to find \'log\' element")
        sys.exit(1)
    # COMMENTED OUT
    #for node in jrnl.getElementsByTagName('log'):
     # return node
  getLogEl = staticmethod(getLogEl)

  #@staticmethod
  def getLastUnfinishedPhase(tree):
    candidate = tree
    # ADDED
    for node in tree.xpath('phase'):
        if node.get('result') == 'unfinished':
            candidate = node
        return candidate
    # COMMENTED OUT
    #for node in tree.getElementsByTagName('phase'):
      #if node.getAttribute('result') == 'unfinished':
       # candidate = node
    #return candidate
  getLastUnfinishedPhase = staticmethod(getLastUnfinishedPhase)

  #@staticmethod
  def addPhase(name, phase_type):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    # COMMENTED OUT
    #phase = jrnl.createElement("phase")

    name = unicode(name, 'utf-8', errors='replace')
    # ADDED
    lxml_phase = etree.Element("phase")
    lxml_phase.set("name", name.translate(xmlTrans))
    lxml_phase.set("result", 'unfinished')
    # COMMENTED OUT
    #phase.setAttribute("name", name.translate(xmlTrans))
    #phase.setAttribute("result", 'unfinished')

    phase_type = unicode(phase_type, 'utf-8', errors='replace')
    # ADDED
    lxml_phase.set("type", phase_type.translate(xmlTrans))
    lxml_phase.set("starttime", time.strftime(timeFormat))
    lxml_phase.set("endtime", "")

    # COMMENTED OUT
    #phase.setAttribute("type", phase_type.translate(xmlTrans))
    #phase.setAttribute("starttime",time.strftime(timeFormat))
    #phase.setAttribute("endtime","")

    pkgdetails, lxml_pkgdetails = Journal.collectPackageDetails(jrnl, [])
    for installed_pkg in pkgdetails:
      installed_pkg[0].appendChild(installed_pkg[1])
    for installed_pkg in pkgdetails:
      phase.appendChild(installed_pkg[0])

    # ADDED / CHANGED
    log.append(lxml_phase)

    return Journal.saveJournal(jrnl)
  addPhase = staticmethod(addPhase)

  #@staticmethod
  def getPhaseState(phase):
    passed = failed = 0

    # COMMENTED OUT
    #for node in phase.childNodes:
     # if node.nodeName == "test":
      #  result = Journal.__childNodeValue(node, 0)
       # if result == "FAIL":
        #  failed += 1
       # else:
        # passed += 1

    # ADDED
    for node in phase:
        if node.tag == "test":
            result = Journal.__childNodeValue(node, 0)
            if result == "FAIL":
                failed += 1
            else:
                passed += 1
    return (passed, failed)
  getPhaseState = staticmethod(getPhaseState)

  #@staticmethod
  def finPhase():
    jrnl  = Journal.openJournal()
    phase = Journal.getLastUnfinishedPhase(Journal.getLogEl(jrnl))
    type  = phase.getAttribute('type')
    name  = phase.getAttribute('name')
    end   = jrnl.getElementsByTagName('endtime')[0]
    timeNow = time.strftime(timeFormat)
    end.childNodes[0].nodeValue = timeNow
    phase.setAttribute("endtime",timeNow)
    (passed,failed) = Journal.getPhaseState(phase)
    if failed == 0:
      phase.setAttribute("result", 'PASS')
    else:
      phase.setAttribute("result", type)

    phase.setAttribute('score', str(failed))
    Journal.saveJournal(jrnl)
    return (phase.getAttribute('result'), phase.getAttribute('score'), type, name)
  finPhase = staticmethod(finPhase)

  #@staticmethod
  def getPhase(tree):
    for node in tree.getElementsByTagName("phase"):
      if node.getAttribute("name") == name:
        return node
    return tree
  getPhase = staticmethod(getPhase)

  #@staticmethod
  def testState():
    jrnl  = Journal.openJournal()
    failed = 0
    # COMMENTED OUT
    #for phase in jrnl.getElementsByTagName('phase'):
    #  failed += Journal.getPhaseState(phase)[1]
    #if failed >255:
    #    failed = 255

    # ADDED
    # TODO maybe you will have to add // to every xpath query
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
    # COMMENTED OUT
    #msg = jrnl.createElement("message")
    #msg.setAttribute("severity", severity)

    # ADDED
    msg = etree.Element("message")
    msg.set("severity", severity)

    message = unicode(message, 'utf-8', errors='replace')

    # COMMENTED OUT
    #msgText = jrnl.createTextNode(message.translate(xmlTrans))
    #ADDED
    msgText = message.translate(xmlTrans)
    msg.text = msgText
    # COMMENTED OUT
    #msg.appendChild(msgText)
    #add_to.appendChild(msg)
    # ADDED
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

    #msg = jrnl.createElement("test")

    message = unicode(message, 'utf-8', errors='replace')

    #msg.setAttribute("message", message.translate(xmlTrans))

    # ADDED
    msg = etree.Element("test")
    msg.set("message", message.translate(xmlTrans))

    if command:
      command = unicode(command, 'utf-8', errors='replace')
      #msg.setAttribute("command", command.translate(xmlTrans))
      # ADDED
      msg.set("command", command.translate(xmlTrans))

    #msgText = jrnl.createTextNode(result)
    #msg.appendChild(msgText)

    # ADDED
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
    rpms, lxml_rpms = Journal.getRpmVersion(jrnl, package, ts)
    for pkg in rpms:
      pkgEl,pkgCon = pkg
      pkgEl.appendChild(pkgCon)
      add_to.appendChild(pkgEl)
    return Journal.saveJournal(jrnl)

  logRpmVersion = staticmethod(logRpmVersion)

  #@staticmethod
  def addMetric(type, name, value, tolerance):
    jrnl = Journal.openJournal()
    log = Journal.getLogEl(jrnl)
    add_to = Journal.getLastUnfinishedPhase(log)

    # COMMENTED OUT
    #for node in add_to.getElementsByTagName('metric'):
     # if node.getAttribute('name') == name:
      #    raise Exception("Metric name not unique!")

    #metric = jrnl.createElement("metric")
    #metric.setAttribute("type", type)
    #metric.setAttribute("name", name)
    #metric.setAttribute("tolerance", str(tolerance))

    #metricText = jrnl.createTextNode(str(value))
    #metric.appendChild(metricText)
    #add_to.appendChild(metric)

    # ADDED
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
      #print Journal.openJournal().toxml().encode("utf-8")
      # ADDED
      print etree.tostring(Journal.openJournal(), encoding="utf-8", xml_declaration=True)
    elif type == "pretty":
      #print Journal.openJournal().toprettyxml().encode("utf-8")
      # ADDED
      print etree.tostring(Journal.openJournal(), pretty_print=True, encoding="utf-8", xml_declaration=True)
    else:
      print "Journal dump error: bad type specification"
  dumpJournal = staticmethod(dumpJournal)

  def need(args):
      if None in args:
          print "Specified command is missing a required option"
          return 1


# TEMP setting environ vars for testing
os.environ['BEAKERLIB_JOURNAL']="/home/jheger/atmp/jrnl.lxml"
os.environ['TEST'] = "/CoreOS/bash/Regression/bz1172214-pattern-substitution-parameter-expansion-memleak"
os.environ['BEAKERLIB'] = "/usr/share/beakerlib"

jrnl = Journal()
jrnl.addPhase("phase1", "random_comm")
jrnl.addTest("lorem ipsum", result="FAIL", command="cat /etc/passwd")
jrnl.addTest("dolor sit amet", result="PASS", command="touch /etc/passwd")
jrnl.addTest("consectetur", result="FAIL", command="cp /etc/passwd .")
jrnl.addMessage("test", "LOG")
#jrnl.addMetric("tip", "testname", "testvalue", "testtolerance")

print "testState:", jrnl.testState()

exit(222)