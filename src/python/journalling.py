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
import base64

# TODO fix xml pretty print


xmlForbidden = [0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 14, 15, 16, 17, 18, 19, 20,
                21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 0xFFFE, 0xFFFF]
xmlTrans = dict([(x, None) for x in xmlForbidden])


class Stack:
    def __init__(self):
        self.items = []

    def push(self, item):
        self.items.append(item)

    def pop(self):
        return self.items.pop()

    def peek(self):  # Returns top element without popping it
        return self.items[-1]


# Saves the XML journal to a file.
def saveJournal(journal, journal_path):
    try:
        output = open(journal_path, 'wb')
        output.write(etree.tostring(journal, xml_declaration=True, encoding='utf-8', pretty_print=True))
        output.close()
        return 0
    except IOError, e:
        sys.stderr.write('Failed to save journal to %s: %s' % (journal_path, str(e)))
        return 1


# Adds attributes starttime and endtime to a element.
def addStartEndTime(element, starttime, endtime):
    element.set("starttime", starttime)
    element.set("endtime", endtime)
    # Removing timestamp from paired element (not needed as it has start/endtime)
    # 'None' is to not raise an exception if attribute 'timestamp' does not exist
    element.attrib.pop("timestamp", None)
    return 0


# Find first and last timestamp to fill in starttime and endtime attributes of given element.
def getStartEndTime(element):
    starttime = ""
    endtime = ""
    for child in element.iter():
        if child.get("timestamp"):
            if starttime == "":
                starttime = child.get("timestamp")
            endtime = child.get("timestamp")

    return starttime, endtime


# Parses and decodes lines given to it
# Returns number of spaces before element, name of the element,
# its attributes in a dictionary, and content of the element.
def parseLine(line):
    TIME_FORMAT = "%Y-%m-%d %H:%M:%S %Z"
    CONTENT_FLAG = 0
    attributes = {}
    content = ""

    # Stripping comments
    line = line.split('#')[0]
    # Count number of leading spaces
    indent = len(line) - len(line.lstrip())

    # Splitting the line into a list
    splitted = line.split()

    # If the line is not empty
    if splitted:
        # If first 2 characters are '-', it is not new element, but ending of pair element
        if splitted[0][0] == '-' and splitted[0][1] == '-':
            element = ""
        else:
            element = splitted[0]
    # else it is ending line
    else:
        return 0, "", {}, ""

    # Parsing the rest of the line
    for part in splitted:
        # If flag is set, string is an elements content
        if CONTENT_FLAG == 1:
            # First and last characters (quotes) stripped and
            # string is decoded from base64
            try:
                content = base64.b64decode(part[1:-1])
            except TypeError, e:
                sys.stderr.write('Failed to decode string \'%s\' from base64.\
                        \nError: %s\nExiting unsuccessfully.\n' % (part[1:-1], e))
                exit(1)
            # End parsing after content is stored
            break
        # Test if string is an elements content indicator
        if part == '--':
            CONTENT_FLAG = 1
            continue

        # Test if string is the elements time attribute
        if re.match(r'^--timestamp=', part):
            attribute_name = "timestamp"
            # Value is string after '=' sign and without first and last char(quotes)
            attribute_value = part.split('=', 1)[1][1:-1]
            try:
                attributes[attribute_name] = time.strftime(TIME_FORMAT, time.localtime(int(attribute_value)))
            except ValueError, e:
                sys.stderr.write('Failed to convert timestamp attribute to int.\
                        \nError: %s\nExiting unsuccessfully.\n' % (e))
                exit(1)
            continue

        # Test if string is the elements regular attribute
        if re.match(r'^--[a-zA-Z0-9]+=', part):
            attribute_name = part.split('=', 1)[0][2:]
            # Value is string after '=' sign and without first and last char(quotes)
            attribute_value = part.split('=', 1)[1][1:-1]
            try:
                attributes[attribute_name] = base64.b64decode(attribute_value)
            except TypeError, e:
                sys.stderr.write('Failed to decode string \'%s\' from base64.\
                        \nError: %s\nExiting unsuccessfully.\n' % (attribute_value, e))
                exit(1)
            continue

    return indent, element, attributes, content


# Returns XML element created with
# information given as parameters
def createElement(element, attributes, content):
    element = unicode(element, 'utf-8', errors='replace').translate(xmlTrans)
    try:
        new_el = etree.Element(element)
    except ValueError, e:
        sys.stderr.write('Failed to create element with name %s\nError: %s\nExiting unsuccessfully.\n' % (element, e))
        exit(1)

    content = unicode(content, 'utf-8', errors='replace').translate(xmlTrans)
    new_el.text = content

    for key, value in attributes.iteritems():
        key = unicode(key, 'utf-8', errors='replace').translate(xmlTrans)
        value = unicode(value, 'utf-8', errors='replace').translate(xmlTrans)
        new_el.set(key, value)
    return new_el


# Main loop of the program
# Reads metafile or stdin line by line and adds
# information from them into XML document
def createJournalXML(options):
    # If --metafile option is used read from it, else read standard input
    if options.metafile:
        try:
            fh = open(options.metafile, 'r+')
        except IOError, e:
            sys.stderr.write('Failed to open queue file with' + str(e), 'FAIL')
            return 1

        lines = fh.readlines()
        fh.close()
    else:
        lines = sys.stdin.readlines()

    # Indent level of previous line, initialized to -1
    old_indent = -1
    # Initialize root element
    previous_el = etree.Element("BEAKER_TEST")
    journal = previous_el
    # Stack of elements
    el_stack = Stack()

    # Main loop, going through lines of metafile, adding elements
    for line in lines:
        indent, element, attributes, content = parseLine(line)
        # Empty line is ignored
        if element == "" and attributes == {}:
            continue

        if indent > old_indent:
            # Creating new element
            new_el = createElement(element, attributes, content)
            # Putting previous element to the top of the stack
            el_stack.push(previous_el)
            # New element is now current element
            previous_el = new_el

        elif indent == old_indent:
            # TODO refactor
            # Closing element with updates to it with no elements inside it
            if element == "":
                # Updating start and end time
                starttime, endtime = getStartEndTime(previous_el)
                # If the closing element has a --timestamp, this value will be used as endtime
                if "timestamp" in attributes:
                    endtime = attributes["timestamp"]
                # Updating attributes found on closing line
                for key, value in attributes.iteritems():
                    previous_el.set(key, value)
                # Add start/end time and remove timestamp attribute
                addStartEndTime(previous_el, starttime, endtime)
            # New element is on the same level as previous one
            else:
                # Previous element has ended so it is appended to the element 1 level above
                el_stack.peek().append(previous_el)
                # Creating new element
                new_el = createElement(element, attributes, content)
                # New element is now current element
                previous_el = new_el

        # New element is on higher level than previous one
        elif indent < old_indent:
            # Difference between indent levels = how many paired elements will be closed
            indent_diff = old_indent - indent
            for _ in xrange(indent_diff):
                el_stack.peek().append(previous_el)
                previous_el = el_stack.pop()

            # Closing element with updates to it
            if element == "" and attributes != {}:
                # Updating start and end time
                starttime, endtime = getStartEndTime(previous_el)
                # If the closing element has a --timestamp, this value will be used as endtime
                if "timestamp" in attributes:
                    endtime = attributes["timestamp"]
                # Updating attributes found on closing line
                for key, value in attributes.iteritems():
                    previous_el.set(key, value)
                # Add start/end time and remove timestamp attribute
                addStartEndTime(previous_el, starttime, endtime)

            # Ending paired element and creating new one on the same level as the paired one that just ended
            elif element != "":
                # Updating start and end time
                starttime, endtime = getStartEndTime(previous_el)
                addStartEndTime(previous_el, starttime, endtime)
                # Appending previous element to the element 1 level above
                if el_stack.items:
                    el_stack.peek().append(previous_el)

                new_el = createElement(element, attributes, content)
                previous_el = new_el

        # Changing indent level to new value
        old_indent = indent

    # Final appending
    for _ in el_stack.items:
        el_stack.peek().append(previous_el)
        previous_el = el_stack.pop()
    if el_stack.items:
        el_stack.peek().append(previous_el)

    # Updating start and end time of last opened paired element(log)
    starttime, endtime = getStartEndTime(previous_el)
    addStartEndTime(previous_el, starttime, endtime)

    # Updating start/end time of the whole test
    starttime, endtime = getStartEndTime(journal)
    journal.xpath("starttime")[0].text = starttime
    journal.xpath("endtime")[0].text = endtime

    # XSL transformation
    try:
        if options.xslt:
            xslt = etree.parse(options.xslt)
            transform = etree.XSLT(xslt)
            journal = transform(journal)
    except etree.LxmlError:
        sys.stderr.write("\nTransformation template file " + options.xslt +
                         " could not be parsed.\nAborting journal creation.")
        return 1

    if options.journal:
        # Save journal to a file and return its exit code
        return saveJournal(journal, options.journal)
    else:
        # Write the XML on standard output
        return sys.stdout.write(etree.tostring(journal, xml_declaration=True, encoding='utf-8', pretty_print=True))


def main():
    DESCRIPTION = "Tool creating journal out of metafile."
    usage = __file__ + " --metafile=METAFILE --journal=JOURNAL"
    optparser = OptionParser(description=DESCRIPTION, usage=usage)

    optparser.add_option("-j", "--journal", default=None, dest="journal", metavar="JOURNAL")
    optparser.add_option("-m", "--metafile", default=None, dest="metafile", metavar="METAFILE")
    optparser.add_option("-x", "--xslt", default=None, dest="xslt", metavar="XSLT")

    (options, args) = optparser.parse_args()

    # If metafile option is used, check if the value exists
    if options.metafile and not os.path.exists(options.metafile):
        sys.stderr.write("Metafile " + options.metafile + " does not exist.\nExiting unsuccessfully.\n")
        exit(1)

    # Create journal
    return createJournalXML(options)


if __name__ == "__main__":
    sys.exit(main())
