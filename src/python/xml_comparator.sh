#!/bin/bash

FAILED=0

rm /home/jheger/atmp/jrnl.orig 2>/dev/null
rm /home/jheger/atmp/jrnl.lxml 2>/dev/null

/home/jheger/baka/new_breakerlib/beakerlib/src/python/journalling.py_TEST
if [ $? -ne 222 ]; then
    #echo "ERROR running r_journalling.py"
    FAILED=1
    #exit 1
else
    #echo "PASS running r_journaling.py"
    true
fi

/home/jheger/baka/new_breakerlib/beakerlib/src/python/journalling.py
if [ $? -ne 222 ]; then
    #echo "ERROR running lxml_test.py"
    #exit 1
    FAILED=1
else
    #echo "PASS running lxml_test.py"
    true
fi

if xmllint -c14n /home/jheger/atmp/jrnl.orig > /home/jheger/atmp/tmp/proccesed.orig; then true; else FAILED=1; fi 
if xmllint -c14n /home/jheger/atmp/jrnl.lxml > /home/jheger/atmp/tmp/proccesed.lxml; then true; else FAILED=1; fi 


if xmllint --format /home/jheger/atmp/tmp/proccesed.orig > /home/jheger/atmp/tmp/formatted.orig; then true; else FAILED=1; fi 
if xmllint --format /home/jheger/atmp/tmp/proccesed.lxml > /home/jheger/atmp/tmp/formatted.lxml; then true; else FAILED=1; fi 

diff /home/jheger/atmp/tmp/formatted.orig /home/jheger/atmp/tmp/formatted.lxml > /dev/null
if [ $? -eq 0 ]; then
    echo "PASS no diff"
else
    #gvimdiff /home/jheger/atmp/tmp/formatted.orig /home/jheger/atmp/tmp/formatted.lxml
    meld /home/jheger/atmp/tmp/formatted.orig /home/jheger/atmp/tmp/formatted.lxml
fi

if [ $FAILED -eq 1 ]; then
    echo "Overall ERROR"
else
    echo "Overall SUCCESS"
fi

mv /home/jheger/atmp/jrnl.orig /home/jheger/atmp/jrnl.lxml /home/jheger/atmp/tmp/
