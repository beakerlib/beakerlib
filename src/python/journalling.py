#!/usr/bin/python

# Authors:  Jakub Heger        <jheger@redhat.com>
#           Dalibor Pospisil   <dapospis@redhat.com>
#           Ales Zelinka       <azelinka@redhat.com>
#
# Description: Translates Beakerlibs metafile into XML Journal
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


import sys
import os
import time
import re
from optparse import OptionParser
from lxml import etree
import shlex
import base64

TIME_FORMAT = "%Y-%m-%d %H:%M:%S %Z"  # TODO move to parseLine() if used nowhere else

#### MEETING ####
# starttime endtime of phases and other elements, how to make them? can I count of timestamp on every line? should I search for first/last occurrence of timestamp? = possibly incorrect values
# BEAKERLIB_JOURNAL is an environmental var, keep it that way or parameter as well as meta,xslt?
# HEX: echo -n "Hello" | od -A n -t x1    however it produces spaces, either leave them or get rid of them using sed...another program
# base64: dependency needed?
# speed: simple speed testing in files ~/atmp/base64time.sh and ~/atmp/hextime.sh
#### END ####

#### metafile format guidelines ####
# indent must be consistent in which whitespace char is used - currently using spaces, may be changed to tabs
# indent difference must be done with 1 whitespace char
# BEAKER_TEST element is included in python, do not use it again in metafile
# closing a paired element(1 indent less than previous indent) must be done with 1) new element, 2) attribute (e.g.: --result="...") #TODO new element closing not tested
# last line of metafile must be an empty line (or a comment) - possibly
# "header" must contain <starttime> <endtime> elements, which are updated at the end of the journal creation
# attribute must match regex --[a-zA-Z0-9]+= (= only containing letters and digits, starts with -- and end with =)
# attribute --timestamp must contain value of integer representing seconds (UNIX time)
#### END ####


class Stack:
    def __init__(self):
        self.items = []

    def push(self, item):
        self.items.append(item)

    def pop(self):
        return self.items.pop()

    def peek(self):  # Returns top element without popping it
        return self.items[-1]


def saveJournal(journal):
    journal_path = os.environ['BEAKERLIB_JOURNAL']
    try:
        output = open(journal_path, 'wb')
        output.write(etree.tostring(journal, xml_declaration=True, encoding='utf-8'))
        output.close()
        return 0
    except IOError, e:
        sys.stderr.write('Failed to save journal to %s: %s' % (journal, str(e)))
        return 1


# MEETING first and last doesn't necessarily have to be correct (if missing - however that should not happen)
# Find first and last timestamp to fill in starttime and endtime elements of given element
def updateStartEndTime(element):
    starttime=""
    endtime=""
    starttime = ""
    endtime = ""
    for child in element.iter():
        if child.get("timestamp"):
            if starttime == "":
                starttime = child.get("timestamp")
            endtime=child.get("timestamp")

    element.xpath("starttime")[0].text = starttime
    element.xpath("endtime")[0].text = endtime


# Parses and decodes lines given to it
# Returns number of spaces before element, name of the element,
# its attributes in a dictionary, and content of the element
def parseLine(line):
    CONTENT_FLAG = 0
    attributes = {}
    content = ""

    # Stripping comments
    line = line.split('#')[0]
    # Count number of leading spaces
    indent = len(line) - len(line.lstrip())

    # using shlex to get rid of the quotes
    splitted = shlex.split(line)

    # if the line is not empty
    if splitted:
        # if first 2 characters are '-', it is not new element, but ending of pair element
        if splitted[0][0] == '-' and splitted[0][1] == '-':
            element = ""
        else:
            element = splitted[0]
    # else it is ending line
    else:
        return 0, "", {}, ""

    # parsing the rest of the line
    for part in splitted:
        # if flag is set, string is an elements content
        if CONTENT_FLAG == 1:
            content = base64.b64decode(part)
            CONTENT_FLAG = 0
            continue
        # test if string is an elements content indicator
        if part == '--':
            CONTENT_FLAG = 1
            continue
        # test if string is an elements time attribute
        if re.match(r'^--timestamp=', part):
            attribute_name = part.split('=', 1)[0][2:]
            attribute_value = part.split('=', 1)[1]
            attributes[attribute_name] = time.strftime(TIME_FORMAT, time.localtime(int(attribute_value)))
            continue
        # test if string is an elements regular attribute
        if re.match(r'^--[a-zA-Z0-9]+=', part):
            attribute_name = part.split('=', 1)[0][2:]
            attribute_value = part.split('=', 1)[1]
            attributes[attribute_name] = base64.b64decode(attribute_value)
            continue

    return indent, element, attributes, content


# TODO comment
def createElement(element, attributes, content):
    new_el = etree.Element(element)
    new_el.text = content
    for key, value in attributes.iteritems():
        new_el.set(key, value)
    return new_el


# TODO comment
def createJournalXML(options):
    try:
        fh = open(options.metafile, 'r+')
    except IOError as e:
        sys.stderr.write('Failed to open queue file with' + str(e), 'FAIL')
        return 1

    lines = fh.readlines()
    fh.close()

    # Indent level of previous line, initialized as -1
    old_indent = -1
    # Initialize root element
    previous_el = etree.Element("BEAKER_TEST")
    journal = previous_el
    # Stack of elements
    el_stack = Stack()

    # Main loop, going through lines of metafile, adding elements
    for line in lines:
        indent, element, attributes, content = parseLine(line)

        if indent > old_indent:
            # Creating new element
            new_el = createElement(element, attributes, content)
            # Putting previous element to the top of the stack
            el_stack.push(previous_el)
            # New element is now current element
            previous_el = new_el

        # New element is on the same level as previous one
        elif indent == old_indent:
            # Previous element has ended so it is appended to the element 1 level above
            el_stack.peek().append(previous_el)
            # Creating new element
            new_el = createElement(element, attributes, content)
            # New element is now current element
            previous_el = new_el

        # TODO starttime, endtime u fazi, momentalne maji faze 1 timestamp a to ending one
        # New element is on higher level than previous one
        elif indent < old_indent:
            # Difference between indent levels = how many paired elements will be closed
            indent_diff = old_indent - indent
            for _ in xrange(indent_diff):
                el_stack.peek().append(previous_el)
                previous_el = el_stack.pop()

            # End of metafile
            if element == "" and attributes == {}:
                if not el_stack.items:  # FIXME workaround
                    break
                # Appending previous element to the element 1 level above
                el_stack.peek().append(previous_el)
            # Updating previous element
            elif element == "" and attributes != {}:
                for key, value in attributes.iteritems():
                    previous_el.set(key, value)
            # Ending paired element and creating new one on the same level as the paired one that just ended
            elif element != "":  # FIXME possibly breaks stuff, inspect with ^FIXME
                new_el = createElement(element, attributes, content)
                previous_el = new_el

        # Changing indent level to new value
        old_indent = indent

       #  # SMAZAT
       # # print etree.tostring(journal, pretty_print=True)
       # # raw_input()
       #
       #
       #  # SMAZAT
       #  if journal.xpath("log"):
       #      el=journal.xpath("log")[0]
       #      if el.xpath("phase"):
       #          print "found"
       #      # print type(journal.xpath("test")[0])
       #      # for elem in journal.xpath("test")[0].iter():
       #      #     print elem


    updateStartEndTime(journal)


    # XSL transformation
    if options.xslt:
        xslt = etree.parse(options.xslt)
        transform = etree.XSLT(xslt)
        journal = transform(journal)

    #print etree.tostring(journal, pretty_print=True)  # SMAZAT
    print(etree.tostring(journal, pretty_print=True).decode())
    #exit(79) # SMAZAT

    # Save journal to a file and return its exit code
    return saveJournal(journal)


def main():

    # SMAZAT
    if 'BEAKERLIB_JOURNAL' not in os.environ:
        os.environ['BEAKERLIB_JOURNAL'] = '/home/jheger/atmp/journal.xml.example'


    if 'BEAKERLIB_JOURNAL' not in os.environ:
        sys.stderr.write("BEAKERLIB_JOURNAL variable not defined in the environment.\n"
                         "Exiting unsuccessfully.\n")
        exit(1)

    # TODO write help, usage?
    DESCRIPTION = "Tool to create XML journal out of metafile"
    optparser = OptionParser(description=DESCRIPTION)

    optparser.add_option("-m", "--metafile", default=None, dest="metafile", metavar="METAFILE")
    optparser.add_option("-x", "--xslt", default=None, dest="xslt", metavar="XSTL")

    (options, args) = optparser.parse_args()

    if options.metafile is None:
        sys.stderr.write("--metafile option not provided.\nExiting unsuccessfully.\n")
        exit(1)
    elif not os.path.exists(options.metafile):
        sys.stderr.write("Metafile " + options.metafile + " does not exist.\nExiting unsuccessfully.\n")
        exit(1)

    # Create journal
    return createJournalXML(options)


if __name__ == "__main__":
    sys.exit(main())
