#!/bin/bash

FAILED=0

rm /home/jheger/atmp/jrnl.orig 2>/dev/null
rm /home/jheger/atmp/jrnl.lxml 2>/dev/null

/home/jheger/baka/beakerlib/src/python/r_journalling.py
if [ $? -ne 222 ]; then
    #echo "ERROR running r_journalling.py"
    FAILED=1
    #exit 1
else
    #echo "PASS running r_journaling.py"
    true
fi

/home/jheger/atmp/lxml_test.py
if [ $? -ne 222 ]; then
    #echo "ERROR running lxml_test.py"
    #exit 1
    FAILED=1
else
    #echo "PASS running lxml_test.py"
    true
fi

if xmllint -c14n jrnl.orig > tmp/proccesed.orig; then true; else FAILED=1; fi 
if xmllint -c14n jrnl.lxml > tmp/proccesed.lxml; then true; else FAILED=1; fi 


if xmllint --format tmp/proccesed.orig > tmp/formatted.orig; then true; else FAILED=1; fi 
if xmllint --format tmp/proccesed.lxml > tmp/formatted.lxml; then true; else FAILED=1; fi 

diff tmp/formatted.orig tmp/formatted.lxml > /dev/null
if [ $? -eq 0 ]; then
    echo "PASS no diff"
else
    gvimdiff tmp/formatted.orig tmp/formatted.lxml
fi

if [ $FAILED -eq 1 ]; then
    echo "Overall ERROR"
else
    echo "Overall SUCCESS"
fi

mv jrnl.orig jrnl.lxml tmp/
