# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Authors:
#   Ales Zelinka <azelinka@redhat.com>
#   Petr Splichal <psplicha@redhat.com>

test_rlStartJournal(){ return 0; } # this is tested below, we keep this just for
                                   # compatibility
test_rlJournalStart(){
    assertTrue "journal started" "rlJournalStart"
    assertTrue "directory set & created" "[ -d $BEAKERLIB_DIR ]"
    assertTrue "journal file created" "[ -f $BEAKERLIB_JOURNAL ]"
    assertTrue "journal is well-formed XML" "xmllint $BEAKERLIB_JOURNAL >/dev/null"

    # existing journal is not overwritten
    silentIfNotDebug 'rlLog "I am"'
    rlJournalStart
    assertTrue "existing journal not overwritten" \
            "grep 'I am' $BEAKERLIB_JOURNAL"

    # if TESTID is unset, use user-provided BEAKERLIB_DIR, if available
    local OLDTESTID="$TESTID"
    unset TESTID
    local OLDDIR="$BEAKERLIB_DIR"
    local NEWDIR="$( mktemp -d /tmp/beakerlib-test-XXXXXXXX )" # no-reboot
    export BEAKERLIB_DIR="$NEWDIR"
    local OLDJOURNAL="$BEAKERLIB_JOURNAL"

    journalReset
    assertTrue "A new user-provided dir created when no TESTID available" \
            "[ '$BEAKERLIB_DIR' = '$NEWDIR' -a -d $BEAKERLIB_DIR ]"
    assertTrue "A new journal created in user-provided directory" \
	    "[ '$BEAKERLIB_JOURNAL' != '$OLDJOURNAL' -a -f $BEAKERLIB_JOURNAL ]"

    rm -rf "$NEWDIR"
    export TESTID="$OLDTESTID"
    export BEAKERLIB_DIR="$OLDDIR"
    export BEAKERLIB_JOURNAL="$OLDJOURNAL"
    unset OLDTESTID OLDDIR NEWDIR OLDJOURNAL

    # if both TESTID and BEAKERLIB_DIR are unset, a temp dir should be created
    local OLDTESTID="$TESTID"
    unset TESTID
    local OLDDIR="$BEAKERLIB_DIR"
    unset BEAKERLIB_DIR
    local OLDJOURNAL="$BEAKERLIB_JOURNAL"

    journalReset
    assertTrue "A new random dir created when no TESTID available" \
            "[ '$BEAKERLIB_DIR' -a -d $BEAKERLIB_DIR ]"
    assertTrue "A new journal created in random directory" \
	    "[ '$BEAKERLIB_JOURNAL' != '$OLDJOURNAL' -a -f $BEAKERLIB_JOURNAL ]"

    rm -rf "$BEAKERLIB_DIR"
    export TESTID="$OLDTESTID"
    export BEAKERLIB_DIR="$OLDDIR"
    export BEAKERLIB_JOURNAL="$OLDJOURNAL"
    unset OLDTESTID OLDDIR OLDJOURNAL
}

test_rlJournalPrint(){
    #add something to journal
    silentIfNotDebug "rlPhaseStart FAIL"
    silentIfNotDebug 'rlAssert0 "failed" 1'
    silentIfNotDebug 'rlAssert0 "passed" 0'
    silentIfNotDebug 'rlPhaseEnd'
    silentIfNotDebug 'rlLog "loginek"'
    assertTrue "rlJournalPrint dump is wellformed xml" \
            "rlJournalPrint |xmllint -"
    assertTrue "rlPrintJournal dump still works" \
            "rlPrintJournal | grep -v 'rlPrintJournal is obsoleted by rlJournalPrint' | xmllint -"
    assertTrue "rlPrintJournal emits obsolete warnings" \
            "rlPrintJournal | grep 'rlPrintJournal is obsoleted by rlJournalPrint' -q"
    rm -rf $BEAKERLIB_DIR
}

test_rlJournalPrintText(){
    #this fnc is used a lot in other function's tests
    #so here goes only some specific (regression?) tests

    #must not tracedump on an empty log message
    #outside-of-phase log
    silentIfNotDebug 'rlLog ""'
    silentIfNotDebug 'rlPhaseStart FAIL'
    #inside-phase log
    silentIfNotDebug 'rlLog ""'
    assertFalse "no traceback during log creation" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rm -rf $BEAKERLIB_DIR
    silentIfNotDebug rlJournalStart

    #no traceback on non-ascii characters (bz471257)
    silentIfNotDebug 'rlPhaseStart FAIL'
    assertTrue "no traceback on non-ascii chars (rlLog)" \
      'rlLog "Å¡ÄÅ™Å¾Ã½Ã¡Ã­Ã©ãƒ¼ã‚Œã£ã©ã¯ã£ã¨"'
    assertFalse "no traceback on non-ascii chars (rlJournalPrintText)" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rm -rf $BEAKERLIB_DIR

    # no traceback on non-xml garbage
    journalReset
    silentIfNotDebug 'rlPhaseStart FAIL'
    local X00="$( echo $'\x00' )"
    assertTrue "no traceback on non-xml characters [1] (rlLog)" "rlLog '$X00'"
    assertFalse "no traceback on non-xml characters [1] (rlJournalPrintText)" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    local X0C="$( echo $'\x0c' )"
    assertTrue "no traceback on non-xml characters [2] (rlLog)" "rlLog '$X0C'"
    assertFalse "no traceback on non-xml characters [2] (rlJournalPrintText)" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    local X1F="$( echo $'\x1F' )"
    assertTrue "no traceback on non-xml characters [3] (rlLog)" "rlLog '$X1F'"
    assertFalse "no traceback on non-xml characters [3] (rlJournalPrintText)" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    local FF="$( echo $'\xFF' )"
    assertTrue "rlLog '\\xFF' does not give a traceback" \
               "rlLog '$FF' &> /dev/null"
    assertTrue "rlPass '\\xFF' does not give a traceback" \
               "rlPass '$FF' &> /dev/null"
    local A2=$(mktemp)
    cat > $A2 << EOF
in: 0x2083010, size: 12, use: 8
out: 0x2083060, size: 24, use: 0
handler: 0x2083be0, name: ISO-8859-5, input: (nil), iconv_in: 0x2083c30
xmlCharEncInFunc result: 21
out: 0x2083060, size: 24, use: 21
e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) e2 (â) 84 („) 96 (–) 
EOF
    assertTrue "rlLog with specific UTF-8 characters won't give a traceback" \
               "rlLog '$(cat $A2 )' &>/dev/null"
    assertFalse "rlJournalPrintText won't give a traceback" \
               "rlJournalPrintText 2>&1 | grep Traceback"
    rm -f $A2
    rm -rf $BEAKERLIB_DIR

    # multiline logs
    journalReset

    local MULTILINE="$( echo -e 'line1\nline2' )"
    silentIfNotDebug "rlLog '$MULTILINE'"
    rlJournalPrintText | grep -v "line2" | grep -q "LOG.*line1" &&
            rlJournalPrintText | grep -v "line1" | grep -q "LOG.*line2"
    assertTrue "multiline logs tagged on each line" "[ $? -eq 0 ]"
    rm -rf $BEAKERLIB_DIR

    # obsoleted rlCreateLogFromJournal still works
    journalReset
    assertTrue "Checking the rlCreateLogFromJournal still works" \
            "rlCreateLogFromJournal | grep -q 'TEST PROTOCOL'"
    assertTrue "Obsoleted message for rlCreateLogFromJournal" \
            "rlCreateLogFromJournal | grep -q 'obsoleted by rlJournalPrintText'"
    rm -rf $BEAKERLIB_DIR

    # whole test summary (Bug 464155 -  [RFE] summary of phase results in logfile)
    ( journalReset
      rlPhaseStart FAIL failed ; rlAssert0 "assert" 1 ; rlAssert0 "assert" 1 ; rlPhaseEnd;
      rlPhaseStart FAIL failed2 ; rlAssert0 "assert" 1 ; rlPhaseEnd;
      rlJournalEnd; ) &>/dev/null
    assertTrue "failed test counted in summary" "rlJournalPrintText |grep 'Phases: 0 good, 2 bad'"
    assertTrue "whole test reported as FAILed" "rlJournalPrintText |grep '\[ *FAIL *\].* RESULT: beakerlib-unit-tests'"
    rm -rf $BEAKERLIB_DIR
    ( journalReset
      rlPhaseStart FAIL passed ; rlAssert0 "assert" 0 ; rlPhaseEnd
      rlPhaseStart FAIL passed2 ; rlAssert0 "assert" 0 ; rlPhaseEnd
      rlJournalEnd; ) &>/dev/null
    assertTrue "passed test counted in summary" "rlJournalPrintText |grep 'Phases: 2 good, 0 bad'"
    assertTrue "whole test reported as PASSed" "rlJournalPrintText |grep '\[ *PASS *\].* RESULT: beakerlib-unit-tests'"
    rm -rf $BEAKERLIB_DIR
    ( journalReset
      rlPhaseStart FAIL passed ; rlAssert0 "assert" 0 ; rlPhaseEnd
      rlPhaseStart FAIL failed ; rlAssert0 "assert" 1 ; rlPhaseEnd
      rlPhaseStart FAIL passed2 ; rlAssert0 "assert" 0 ; rlPhaseEnd
      rlJournalEnd; ) &>/dev/null
    assertTrue "both failed and passed phases counted in summary" "rlJournalPrintText |grep 'Phases: 2 good, 1 bad'"
    assertTrue "whole test reported as FAILed" "rlJournalPrintText |grep '\[ *FAIL *\].* RESULT: beakerlib-unit-tests'"
    rm -rf $BEAKERLIB_DIR

    # --full-journal shows fields
    journalReset &>/dev/null
    silentIfNotDebug 'rlRun "true"'
    rlJournalEnd &>/dev/null

    assertFalse "Checking the rlJournalPrintText does not show CPU line" \
        "rlJournalPrintText | grep 'CPUs'"
    assertFalse "Checking the rlJournalPrintText does not show RAM line" \
        "rlJournalPrintText | grep 'RAM size'"
    assertFalse "Checking the rlJournalPrintText does not show HDD line" \
        "rlJournalPrintText | grep 'HDD size'"
    assertTrue "Checking the rlJournalPrintText --full-journal shows CPU line" \
        "rlJournalPrintText --full-journal | grep 'CPUs'"
    assertTrue "Checking the rlJournalPrintText --full-journal shows RAM line" \
        "rlJournalPrintText --full-journal | grep 'RAM size'"
    assertTrue "Checking the rlJournalPrintText --full-journal shows HDD line" \
        "rlJournalPrintText --full-journal | grep 'HDD size'"
}

test_rlGetTestState(){
    #test this in developer mode to verify BZ#626953
    TESTID_BACKUP=$TESTID
    unset TESTID
    journalReset
    assertRun "rlPhaseStart FAIL phase1"
    rlGetTestState ; assertTrue "rlGetTestState return 0 at the beginning of the test" "[ $? -eq 0 ]"
    rlGetPhaseState ; assertTrue "rlGetPhaseState return 0 at the beginning of the test" "[ $? -eq 0 ]"
    assertRun 'rlAssert0 "failing assert#1" 1' 1
    rlGetTestState ; assertTrue "rlGetTestState return 1 after assert failed" "[ $? -eq 1 ]"
    rlGetPhaseState ; assertTrue "rlGetPhaseState return 1 after assert failed" "[ $? -eq 1 ]"
    assertRun 'rlAssert0 "failing assert#2" 1' 1
    rlGetTestState ; assertTrue "rlGetTestState return 2 after assert failed" "[ $? -eq 2 ]"
    rlGetPhaseState ; assertTrue "rlGetPhaseState return 2 after assert failed" "[ $? -eq 2 ]"
    assertRun 'for i in $(seq 3 260) ; do rlAssert0 "failing assert#$i" 1; done' 1 "Creating 260 failed asserts"
    rlGetTestState ; assertTrue "rlGetTestState return 255 after more that 255 asserts failed" "[ $? -eq 255 ]"
    rlGetPhaseState ; assertTrue "rlGetPhaseState return 255 after more that 255 asserts failed" "[ $? -eq 255 ]"
    assertRun "rlPhaseEnd"

    assertRun "rlPhaseStart FAIL phase2"
    rlGetTestState ; assertTrue "rlGetTestState return non-zero in passing phase but failing test" "[ $? -ne 0 ]"
    rlGetPhaseState ; assertTrue "rlGetPhaseState return 0 in passing phase but failing test" "[ $? -eq 0 ]"
    assertRun "rlPhaseEnd"
    TESTID=$TESTID_BACKUP
}

test_rlGetPhaseState(){
    assertLog "Tests for this function are included in rlGetTestState since it is more or less the same"
}
