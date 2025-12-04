# Copyright (c) 2021 Red Hat, Inc. All rights reserved. This copyrighted material
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
# Author: Ales Zelinka <azelinka@redhat.com>

test_rlAssertDiffer() {
  local FILE1="$(mktemp)" # no-reboot
  local FILE2="$(mktemp)" # no-reboot
  local FILE3="$(mktemp '/tmp/test rlAssertDiffer3-XXXXXX')" # no-reboot

  echo "AAA" > "$FILE1"
  echo "AAA" > "$FILE2"
  echo "AAA" > "$FILE3"

  assertFalse "rlAssertDiffer does not return 0 for the identical files"\
  "rlAssertDiffer $FILE1 $FILE2"
  assertGoodBad "rlAssertDiffer $FILE1 $FILE2" 0 1

  assertFalse "rlAssertDiffer does not return 0 for the identical files with spaces in name"\
  "rlAssertDiffer \"$FILE1\" \"$FILE3\""
  assertGoodBad "rlAssertDiffer \"$FILE1\" \"$FILE3\"" 0 1

  assertFalse "rlAssertDiffer does not return 0 for the same file"\
  "rlAssertDiffer $FILE1 $FILE1"
  assertGoodBad "rlAssertDiffer $FILE1 $FILE1" 0 1

  assertRun "rlAssertDiffer" 2 "rlAssertDiffer returns 2 when called without parameters"

  assertRun "rlAssertDiffer $FILE1" 2 "rlAssertDiffer returns 2 when called with only one parameter"

  echo "BBB" > "$FILE3"
  echo "BBB" > "$FILE2"

  assertTrue "rlAssertDiffer returns 0 for different files"\
  "rlAssertDiffer $FILE1 $FILE2"
  assertGoodBad "rlAssertDiffer $FILE1 $FILE2" 1 0

  assertTrue "rlAssertDiffer returns 0 for different files with space in name"\
  "rlAssertDiffer \"$FILE1\" \"$FILE3\""
  assertGoodBad "rlAssertDiffer \"$FILE1\" \"$FILE3\"" 1 0
  rm -f "$FILE1" "$FILE2" "$FILE3"
}

test_rlAssertNotDiffer() {
  local FILE1="$(mktemp)" # no-reboot
  local FILE2="$(mktemp)" # no-reboot
  local FILE3="$(mktemp '/tmp/test rlAssertNotDiffer3-XXXXXX')" # no-reboot

  echo "AAA" > "$FILE1"
  echo "AAA" > "$FILE2"
  echo "AAA" > "$FILE3"

  assertTrue "rlAssertNotDiffer returns 0 for the identical files"\
  "rlAssertNotDiffer $FILE1 $FILE2"
  assertGoodBad "rlAssertNotDiffer $FILE1 $FILE2" 1 0

  assertTrue "rlAssertNotDiffer returns 0 for the identical files with spaces in name"\
  "rlAssertNotDiffer \"$FILE1\" \"$FILE3\""
  assertGoodBad "rlAssertNotDiffer \"$FILE1\" \"$FILE3\"" 1 0

  assertTrue "rlAssertNotDiffer returns 0 for the same file"\
  "rlAssertNotDiffer $FILE1 $FILE1"
  assertGoodBad "rlAssertNotDiffer $FILE1 $FILE1" 1 0

  assertRun "rlAssertNotDiffer" 2 "rlAssertNotDiffer returns 2 when called without parameters"

  assertRun "rlAssertNotDiffer $FILE1" 2 \
        "rlAssertNotDiffer returns 2 when called with only one parameter"

  echo "BBB" > "$FILE3"
  echo "BBB" > "$FILE2"

  assertFalse "rlAssertNotDiffer does not return 0 for different files"\
  "rlAssertNotDiffer $FILE1 $FILE2"
  assertGoodBad "rlAssertNotDiffer $FILE1 $FILE2" 0 1

  assertFalse "rlAssertNotDiffer does not return 0 for different files with space in name"\
  "rlAssertNotDiffer \"$FILE1\" \"$FILE3\""
  assertGoodBad "rlAssertNotDiffer \"$FILE1\" \"$FILE3\"" 0 1
  rm -f "$FILE1" "$FILE2" "$FILE3"
}


test_rlAssertExists() {
  journalReset
  rlPhaseStartTest &> /dev/null
	local FILE="/tmp/test_rlAssertExists" # no-reboot

	touch $FILE
  assertTrue "rlAssertExists returns 0 on existing file" \
    "rlAssertExists $FILE"
	assertGoodBad "rlAssertExists $FILE" 1 0

	rm -f $FILE
  assertFalse "rlAssertExists returns 1 on non-existant file" \
    "rlAssertExists $FILE"
	assertGoodBad "rlAssertExists $FILE" 0 1
  assertFalse "rlAssertExists returns 1 when called without arguments" \
    "rlAssertExists"

  local FILE="/tmp/test rlAssertExists filename with spaces" # no-reboot
	touch "$FILE"
  assertTrue "rlAssertExists returns 0 on existing file with spaces in its name" \
  "rlAssertExists \"$FILE\""
  rm -f "$FILE"
  rlPhaseEnd &> /dev/null
}
test_rlAssertNotExists() {
    local FILE="/tmp/test_rlAssertNotExists filename with spaces" # no-reboot
    local FILE2="/tmp/test_rlAssertNotExists" # no-reboot
	touch "$FILE"
    assertFalse "rlAssertNotExists returns 1 on existing file" \
    "rlAssertNotExists \"$FILE\""
	assertGoodBad "rlAssertNotExists \"$FILE\"" 0 1
    assertFalse "rlAssertNotExists returns 1 when called without arguments" \
    "rlAssertNotExists"

	rm -f "$FILE"
	touch "$FILE2"
    assertTrue "rlAssertNotExists returns 0 on non-existing file" \
    "rlAssertNotExists \"$FILE\""
	assertGoodBad "rlAssertNotExists \"$FILE\"" 1 0
	rm -f "$FILE2"

}

test_rlAssertGrep() {
    echo yes > grepfile
    assertTrue "rlAssertGrep should pass when pattern present" \
        'rlAssertGrep yes grepfile; [ $? == 0 ]'
	assertGoodBad 'rlAssertGrep yes grepfile' 1 0
	assertGoodBad 'rlAssertGrep no grepfile' 0 1
	assertParameters 'rlAssertGrep yes grepfile'
    assertTrue "rlAssertGrep should return 1 when pattern is not present" \
        'rlAssertGrep no grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep should return 2 when file does not exist" \
        'rlAssertGrep no badfile; [ $? == 2 ]'
	assertGoodBad 'rlAssertGrep yes badfile' 0 1
    # without optional parameter
    assertTrue "rlAssertGrep without optional arg should not ignore case" \
        'rlAssertGrep YES grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep without optional arg should ignore extended regexp" \
        'rlAssertGrep "e{1,3}" grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep without optional arg should ignore perl regexp" \
        'rlAssertGrep "\w+" grepfile; [ $? == 1 ]'
    # with optional parameter
    assertTrue "rlAssertGrep with -i should ignore case" \
        'rlAssertGrep YES grepfile -i; [ $? == 0 ]'
    assertTrue "rlAssertGrep with -E should use extended regexp" \
        'rlAssertGrep "e{1,3}" grepfile -E; [ $? == 0 ]'
    assertTrue "rlAssertGrep with -P should use perl regexp" \
        'rlAssertGrep "\w+" grepfile -P; [ $? == 0 ]'
    rm -f grepfile
}

test_rlAssertNotGrep() {
    echo yes > grepfile
    assertTrue "rlAssertNotGrep should pass when pattern is not present" \
        'rlAssertNotGrep no grepfile; [ $? == 0 ]'
	assertGoodBad 'rlAssertNotGrep no grepfile' 1 0
	assertGoodBad 'rlAssertNotGrep yes grepfile' 0 1
	assertParameters 'rlAssertNotGrep no grepfile'
    assertTrue "rlAssertNotGrep should return 1 when pattern present" \
        'rlAssertNotGrep yes grepfile; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep should return 2 when file does not exist" \
        'rlAssertNotGrep no badfile; [ $? == 2 ]'
	assertGoodBad 'rlAssertNotGrep yes badfile' 0 1
    # without optional parameter
    assertTrue "rlAssertNotGrep without optional arg should not ignore case" \
        'rlAssertNotGrep YES grepfile; [ $? == 0 ]'
    assertTrue "rlAssertNotGrep without optional arg should ignore extended regexp" \
        'rlAssertNotGrep "e{1,3}" grepfile; [ $? == 0 ]'
    assertTrue "rlAssertNotGrep without optional arg should ignore perl regexp" \
        'rlAssertNotGrep "\w+" grepfile; [ $? == 0 ]'
    # with optional parameter
    assertTrue "rlAssertNotGrep with -i should ignore case" \
        'rlAssertNotGrep YES grepfile -i; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep with -E should use extended regexp" \
        'rlAssertNotGrep "e{1,3}" grepfile -E; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep with -P should use perl regexp" \
        'rlAssertNotGrep "\w+" grepfile -P; [ $? == 1 ]'
    rm -f grepfile
}


test_rlAssert0() {
	assertGoodBad 'rlAssert0 "abc" 0' 1 0
	assertGoodBad 'rlAssert0 "abc" 1' 0 1
	assertParameters 'rlAssert0 "comment" 0'
}

test_rlAssertEquals(){
	assertGoodBad 'rlAssertEquals "abc" "hola" "hola"' 1 0
	assertGoodBad 'rlAssertEquals "abc" "hola" "Hola"' 0 1
	assertParameters 'rlAssertEquals comment hola hola'
}
test_rlAssertNotEquals(){
	assertGoodBad 'rlAssertNotEquals "abc" "hola" "hola"' 0 1
	assertGoodBad 'rlAssertNotEquals "abc" "hola" "Hola"' 1 0
	assertParameters 'rlAssertNotEquals comment hola Hola'
}

test_rlAssertGreater(){
	assertGoodBad 'rlAssertGreater "comment" 999 1' 1 0
	assertGoodBad 'rlAssertGreater "comment" 1 -1' 1 0
	assertGoodBad 'rlAssertGreater "comment" 999 999' 0 1
	assertGoodBad 'rlAssertGreater "comment" 10 100' 0 1
	assertParameters 'rlAssertGreater comment -1 -2'
}
test_rlAssertGreaterOrEqual(){
	assertGoodBad 'rlAssertGreaterOrEqual "comment" 999 1' 1 0
	assertGoodBad 'rlAssertGreaterOrEqual "comment" 1 -1' 1 0
	assertGoodBad 'rlAssertGreaterOrEqual "comment" 999 999' 1 0
	assertGoodBad 'rlAssertGreaterOrEqual "comment" 10 100' 0 1
	assertParameters 'rlAssertGreaterOrEqual comment 10 10'
}

test_rlAssertLesser(){
	assertGoodBad 'rlAssertLesser "comment" 1 999' 1 0
	assertGoodBad 'rlAssertLesser "comment" -1 1' 1 0
	assertGoodBad 'rlAssertLesser "comment" 1000 999' 0 1
	assertGoodBad 'rlAssertLesser "comment" 100 10' 0 1
	assertGoodBad 'rlAssertLesser "comment" 0 0' 0 1
	assertGoodBad 'rlAssertLesser "comment" 8 8' 0 1
	assertGoodBad 'rlAssertLesser "comment" -5 -5' 0 1
	assertParameters 'rlAssertLesser comment -2 -1'
}

test_rlAssertLesserOrEqual(){
	assertGoodBad 'rlAssertLesserOrEqual "comment" 1 999' 1 0
	assertGoodBad 'rlAssertLesserOrEqual "comment" -1 1' 1 0
	assertGoodBad 'rlAssertLesserOrEqual "comment" 1000 999' 0 1
	assertGoodBad 'rlAssertLesserOrEqual "comment" 100 10' 0 1
	assertParameters 'rlAssertLesserOrEqual comment 10 10'
}

test_rlRun(){
	assertGoodBad 'rlRun /bin/true 0 comment' 1 0
	assertGoodBad 'rlRun /bin/true 3 comment' 0 1
	assertLog "rlRun with empty command should fail"
	assertFalse "rlRun with empty command should fail" "rlRun ''"
	assertGoodBad "rlRun ''" 0 1
	assertFalse "rlRun with just space in command should fail" "rlRun ' '"
	assertGoodBad "rlRun ' '" 0 1
	assertFalse "rlRun with just tab in command should fail" "rlRun '	'"
	assertGoodBad "rlRun '	'" 0 1
        assertTrue "rlRun with 1st parameter only assumes status = 0" \
	    'rlRun /bin/true'
	#more than one status
	assertGoodBad 'rlRun /bin/true 0,1,2 comment' 1 0
	assertGoodBad 'rlRun /bin/true 1,0,2 comment' 1 0
	assertGoodBad 'rlRun /bin/true 1,2,0 comment' 1 0
	assertGoodBad 'rlRun /bin/true 10,100,1000 comment' 0 1
	# more than one status with interval
	assertGoodBad 'rlRun /bin/false 0-2 comment' 1 0
	assertGoodBad 'rlRun /bin/false 5,0-2 comment' 1 0
	assertGoodBad 'rlRun /bin/false 0-2,5 comment' 1 0
	assertGoodBad 'rlRun /bin/false 5,0-2,7 comment' 1 0
	assertGoodBad 'rlRun /bin/false 5-10,0-2 comment' 1 0
	assertGoodBad 'rlRun /bin/false 0-2,5-10 comment' 1 0

    rlRun -t 'echo "foobar1"' 2>&1 | grep "^STDOUT: foobar1" --quiet
    assertTrue "rlRun tagging (stdout)" "[ $? -eq 0 ]"

    rlRun -t 'echo "foobar2" 1>&2' 2>&1 | grep "^STDERR: foobar2" --quiet
    assertTrue "rlRun tagging (stderr)" "[ $? -eq 0 ]"

    OUTPUTFILE_orig="$OUTPUTFILE"
    export OUTPUTFILE="$(mktemp)" # no-reboot

    PREFIX_REGEXP='^:: \[ [0-9]{2}:[0-9]{2}:[0-9]{2} \] :: \[   LOG    \] ::[[:space:]]+'

    silentIfNotDebug "rlRun -l 'echo \"foobar3\"'"
    grep 'echo "foobar3"' "$OUTPUTFILE" --quiet && grep -E "${PREFIX_REGEXP}"'foobar3' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging plain" "[ $? -eq 0 ]"

    rm -f foobar3
    assertLog "try to cat non-existing file"
    assertGoodBad "rlRun \"cat 'foobar3'\"" 0 1
    assertGoodBad "rlRun -l \"cat 'foobar3'\"" 0 1
    silentIfNotDebug "rlRun -l 'cat \"foobar3\"'"
    assertTrue "rlRun logging plain with bad exit code" "[ $? -eq 1 ]"

    silentIfNotDebug "rlRun -l -t 'echo \"foobar4\"'"
    grep 'echo "foobar4"' "$OUTPUTFILE" --quiet && grep -E "${PREFIX_REGEXP}"'STDOUT: foobar4' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging with tagging (stdout)" "[ $? -eq 0 ]"

    silentIfNotDebug "rlRun -l -t 'echo \"foobar5\" 1>&2'"
    grep 'echo "foobar5" 1>&2' "$OUTPUTFILE" --quiet && grep -E "${PREFIX_REGEXP}"'STDERR: foobar5' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging with tagging (stderr)" "[ $? -eq 0 ]"

    silentIfNotDebug "rlRun -s 'echo \"foobar6_stdout\"; echo \"foobar6_stderr\" 1>&2'"

    rlAssertGrep "foobar6_stdout" "$rlRun_LOG" &>/dev/null && rlAssertGrep "foobar6_stderr" "$rlRun_LOG" &>/dev/null
    assertTrue "rlRun -s - rlRun_LOG OK" "[ $? -eq 0 ]"
    rm -f $rlRun_LOG

    rm -f foobar7
    silentIfNotDebug "rlRun -c 'cat \"foobar7\"'"
    grep 'cat "foobar7"' "$OUTPUTFILE" --quiet && grep -E "${PREFIX_REGEXP}"'cat: foobar7: No such file or directory' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging plain" "[ $? -eq 0 ]"

    echo 'foobar8_content' > foobar8
    silentIfNotDebug "rlRun -c 'cat \"foobar8\"'"
    grep 'cat "foobar8"' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging records command" "[ $? -eq 0 ]"
    grep 'foobar8_content' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging do not record output when all is OK" "[ $? -ne 0 ]"
    rm -f foobar8

    rm -f foobar9
    silentIfNotDebug "rlRun -c -t 'cat \"foobar9\" 1>&2'"
    grep 'cat "foobar9" 1>&2' "$OUTPUTFILE" --quiet && grep -E "${PREFIX_REGEXP}"'STDERR: cat: foobar9: No such file or directory' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging with tagging (stderr)" "[ $? -eq 0 ]"

    assertGoodBad 'rlRun "false|true"' 1 0
    assertGoodBad 'rlRun -s "false|true"; rm -f $rlRun_LOG' 1 0

    #cleanup
    rm -rf "$OUTPUTFILE"
    export OUTPUTFILE="$OUTPUTFILE_orig"
}

watchdogCallback() {
  echo "$1" >> /tmp/watchdogCallback
}

watchdogCallbackTest() {
  local res=0
  rm -f /tmp/watchdogCallback
  rlWatchdog "sleep 10" "4" KILL "watchdogCallback" &
  sleep 3
  [ -e /tmp/watchdogCallback ] && res=1
  echo "res='$res'"
  sleep 3
  [ -s /tmp/watchdogCallback ] || res=1
  echo "res='$res'"
  rm -f /tmp/watchdogCallback

  return $res
}

test_rlWatchdog(){
	assertTrue "rlWatchDog detects when command end itself" 'rlWatchdog "sleep 3" 10'
	assertFalse "rlWatchDog kills command when time is up" 'rlWatchdog "sleep 10" 3'
	assertFalse "running rlWatchdog without timeout must not succeed" 'rlWatchdog "sleep 3"'
	assertFalse "running rlWatchdog without any parameters must not succeed" 'rlWatchdog '

  assertTrue "Callback functionality" "watchdogCallbackTest"
}

test_rlFail(){
    assertFalse "This should always fail" "rlFail 'sometext'"
    assertGoodBad "rlFail 'sometext'" 0 1
}

test_rlPass(){
    assertTrue "This should always pass" "rlPass 'sometext'"
    assertGoodBad "rlPass 'sometext'" 1 0
}

test_rlReport(){
  export BEAKERLIB_COMMAND_REPORT_RESULT=rhts-report-result
  journalReset
  silentIfNotDebug "rlPhaseStartSetup"

  for res in PASS FAIL WARN
  do
    OUT="$(rlReport TEST $res | grep 'ANCHOR NAME: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"ANCHOR NAME: TEST\" ]"
    OUT="$(rlReport TEST $res | grep 'RESULT: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"RESULT: $res\" ]"
    OUT="$(rlReport TEST $res | grep 'LOGFILE: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"LOGFILE: $OUTPUTFILE\" ]"
    OUT="$(rlReport TEST $res | grep 'SCORE: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"SCORE: \" ]"
    OUT="$(rlReport "TEST TEST" $res | grep 'ANCHOR NAME: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\" ]"
    OUT="$(rlReport "TEST TEST" $res | grep 'RESULT: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"RESULT: $res\" ]"
    OUT="$(rlReport "TEST TEST" $res | grep 'LOGFILE: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"LOGFILE: $OUTPUTFILE\" ]"
    OUT="$(rlReport "TEST TEST" $res | grep 'SCORE: ')"
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"SCORE: \" ]"
    OUT="$(rlReport "TEST" $res 5 "/tmp/logname" | grep 'ANCHOR NAME: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"ANCHOR NAME: TEST\" ]" # no-reboot
    OUT="$(rlReport "TEST" $res 5 "/tmp/logname" | grep 'RESULT: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"RESULT: $res\" ]" # no-reboot
    OUT="$(rlReport "TEST" $res 5 "/tmp/logname" | grep 'LOGFILE: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"LOGFILE: /tmp/logname\" ]" # no-reboot
    OUT="$(rlReport "TEST" $res 5 "/tmp/logname" | grep 'SCORE: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"SCORE: 5\" ]" # no-reboot
    OUT="$(rlReport "TEST TEST" $res 8 "/tmp/log name" | grep 'ANCHOR NAME: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\" ]" # no-reboot
    OUT="$(rlReport "TEST TEST" $res 8 "/tmp/log name" | grep 'RESULT: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"RESULT: $res\" ]" # no-reboot
    OUT="$(rlReport "TEST TEST" $res 8 "/tmp/log name" | grep 'LOGFILE: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"LOGFILE: /tmp/log name\" ]" # no-reboot
    OUT="$(rlReport "TEST TEST" $res 8 "/tmp/log name" | grep 'SCORE: ')" # no-reboot
    silentIfNotDebug 'echo "$OUT"'
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"SCORE: 8\" ]" # no-reboot
  done
  silentIfNotDebug "rlPhaseEnd"
}

test_rlAssert_OutsidePhase(){
  silentIfNotDebug "journalReset"

  silentIfNotDebug 'rlAssert0 "Good assert outside phase" 0'

  silentIfNotDebug 'rlPhaseStartSetup'
    silentIfNotDebug 'rlPass "Weeee"'
  silentIfNotDebug 'rlPhaseEnd'

  silentIfNotDebug 'rlAssert0 "Bad assert outside phase" 1'

  local TXTJRNL="$( mktemp )"
  rlJournalPrintText > "$TXTJRNL"

  assertTrue "Good assert outside phase is printed" "grep 'Good assert outside phase' '$TXTJRNL' | grep PASS"
  assertTrue "Bad assert outside phase is printed" "grep 'Bad assert outside phase' '$TXTJRNL' | grep FAIL"

  local rlfails="$(grep 'TEST BUG' $TXTJRNL | grep 'FAIL' | wc -l)"
  assertTrue "rlFail raised twice (once for both assertions outside a phase)" "[ '2' == '$rlfails' ]"

  local pseudophases="$(grep 'Asserts collected outside of a phase' $TXTJRNL | grep RESULT | wc -l)"
  assertTrue "Two phases created for asserts outside phases" "[ '2' == '$pseudophases' ]"

  rm -f "$TXTJRNL"
  silentIfNotDebug 'rlJournalEnd'

  silentIfNotDebug 'journalReset'
}

test_rlCmpVersion() {
  local exp_res=0 res res_part ver1 ver2 op op2
  while read -r exp_res ver1 op ver2; do
    assertLog "testing rlCmpVersion '$ver1' '$ver2'"
    op2=$(rlCmpVersion "$ver1" "$ver2")
    res=$?
    assertTrue "test exit code" "[[ '$res' == '$exp_res' ]]"
    assertTrue "test printed character" "[[ '$op' == '$op2' ]]"
  done << 'EOF'
0  1               =  1
2  2.1             <  2.2
1  3.0.4.10        >  3.0.4.2
2  4.08            <  4.08.01
1  3.2.1.9.8144    >  3.2
2  3.2             <  3.2.1.9.8144
2  1.2             <  2.1
1  2.1             >  1.2
0  5.6.7           =  5.6.7
0  1.01.1          =  1.1.1
0  1.1.1           =  1.01.1
0  1               =  1.0
0  1.0             =  1
0  1.0.2.0         =  1.0.2
0  1..0            =  1.0
0  1.0             =  1..0
0  0.0             =  0
2  0.1             <  1
2  4.8             <  4.08.01
0  5.5-49.el6_5.3  =  5.5-49.el6_5.3
1  5.5-50.el6      >  5.5-49.el6_5.3
2  5.5-49.el6_5.3  <  5.5-49.el6_5.4
1  5.6-49.el6_5.3  >  5.5-49.el6_5.4
2  5.5-49.el6_5.3  <  5.5-49.el7_5.3
EOF
}

test_rlTestVersion() {
  local exp_res=0 res res_part ver1 op ver2
  while read -r exp_res ver1 op ver2; do
    assertRun "rlTestVersion '$ver1' '$op' '$ver2'" $exp_res
  done << 'EOF'
0  1            =  1
0  2.1          <  2.2
0  3.0.4.10     >  3.0.4.2
0  4.08         <  4.08.01
0  3.2.1.9.8144 >  3.2
0  3.2          <  3.2.1.9.8144
0  1.2          <  2.1
0  2.1          >  1.2
0  5.6.7        =  5.6.7
0  1.01.1       =  1.1.1
0  1.1.1        =  1.01.1
0  1            =  1.0
0  1.0          =  1
0  1.0.2.0      =  1.0.2
0  1..0         =  1.0
0  1.0          =  1..0
1  1            >  1
1  0.0         !=  0
0  0.1         !=  1
0  4.8          <  4.08.01
0  5.5-49.el6_5.3  =  5.5-49.el6_5.3
0  5.5-50.el6      >  5.5-49.el6_5.3
0  5.5-49.el6_5.3  <  5.5-49.el6_5.4
0  5.6-49.el6_5.3  >  5.5-49.el6_5.4
0  5.5-49.el6_5.3  <  5.5-49.el7_5.3
0  5.3.2.2-22.el5_10.1 < 5.5-49.el6_5.3
0  5.5-49.el6_5.3 < 5.7.2-18.el7
EOF
}


# fake os-release so we can control what rlIsOS and others see
fake_os_release(){
export BEAKERLIB_OS_RELEASE=/tmp/fake-os-release
if [[ ! -e "/etc/os-release.bac" ]]; then
  mv /etc/os-release /etc/os-release.bac
fi
if [[ -n "$1" ]]; then
  ## clean up after intial use of function
  if [[ "$1" == "--clean_up" && -e "/etc/os-release.bac" ]]; then
    rm -f "/etc/os-release" $BEAKERLIB_OS_RELEASE
    mv /etc/os-release.bac /etc/os-release
    return
  fi
  ## creates and fills fake os-release
  touch /etc/os-release $BEAKERLIB_OS_RELEASE
  cat > $BEAKERLIB_OS_RELEASE <<EOF
ID="$1"
VERSION_ID="$3"
EOF

  if [[ $2 != "" ]]; then
    cat >> $BEAKERLIB_OS_RELEASE <<EOF
ID_LIKE="$2"
EOF
  fi

  cp $BEAKERLIB_OS_RELEASE /etc/os-release

#without args, it only backups os-release so the functions cannot find it
fi
}


# fake beakerlib-lsb_release so we can control what rlIsRHEL and others sees
fake_lsb_release(){
   cat >beakerlib-lsb_release <<-EOF
#!/bin/bash
DISTRO="$1"
RELEASE="$2"
[ \$1 = "-ds" ] && {
    echo "\$DISTRO \$RELEASE (fakeone)"
    exit 0
}
[ \$1 = "-rs" ] && { echo "\$RELEASE" ; exit 0 ; }
echo invalid input, this stub might be out of date, please
echo update according to __INTERNAL_rlIsDistro usage of beakerlib-lsb_release
exit 1
EOF
    chmod a+x ./beakerlib-lsb_release
}


#auxiliary function for test_rlIsRHEL, used with fake_os_release and fake_lsb_release (with arguments for distro id)
aux_rlIsRHEL(){
    # pretend we're RHEL 6.5
    "$@" "6.5"
    assertTrue "major.minor detected correctly" "rlIsRHEL 6.5"
    assertTrue "major detected correctly" "rlIsRHEL 6"
    assertFalse "incorrect minor" "rlIsRHEL 6.3"
    assertFalse "incorrect major" "rlIsRHEL 5.5"
    assertTrue "multiple majors, one correct" "rlIsRHEL 4.5 5.5 6.5 7.5"
    assertTrue "multiple minors, one correct" "rlIsRHEL 6.3 6.4 6.5 6.6"
    assertFalse "multiple args, none correct" "rlIsRHEL 4.5 6.4 7.0"
    assertTrue "space after opreator: superfluous space #1" "rlIsRHEL '>= 6.3'"
    assertFalse "syntax error: superfluous space #2" "rlIsRHEL '>=' '6.3'"
    assertFalse "syntax error: operators only" "rlIsRHEL '<='"
    assertFalse "syntax error: unknown operator" "rlIsRHEL '*6.5'"
    assertTrue "syntax error: no input - checking RHEL only" "rlIsRHEL"

    # pretend we're RHEL 5.10
    "$@" "5.10"
    assertFalse "<5" "rlIsRHEL '<5'"
    assertFalse "<5.0" "rlIsRHEL '<5.0'"
    assertFalse "<5.1" "rlIsRHEL '<5.1'"
    assertFalse "<5.10" "rlIsRHEL '<5.10'"
    assertTrue "<5.11" "rlIsRHEL '<5.11'"
    assertFalse ">5" "rlIsRHEL '>5'"
    assertTrue ">5.0" "rlIsRHEL '>5.0'"
    assertTrue ">5.1" "rlIsRHEL '>5.1'"
    assertTrue ">5.9" "rlIsRHEL '>5.9'"
    assertFalse ">5.10" "rlIsRHEL '>5.10'"
    assertTrue "<6" "rlIsRHEL '<6'"
    assertTrue ">4" "rlIsRHEL '>4'"

    assertTrue "<=5" "rlIsRHEL '<=5'"
    assertFalse "<=5.0" "rlIsRHEL '<=5.0'"
    assertFalse "<=5.1" "rlIsRHEL '<=5.1'"
    assertTrue "<=5.10" "rlIsRHEL '<=5.10'"
    assertTrue "<=5.11" "rlIsRHEL '<=5.11'"
    assertTrue ">=5" "rlIsRHEL '>=5'"
    assertTrue ">=5.0" "rlIsRHEL '>=5.0'"
    assertTrue ">=5.1" "rlIsRHEL '>=5.1'"
    assertTrue ">=5.9" "rlIsRHEL '>=5.9'"
    assertTrue ">=5.10" "rlIsRHEL '>=5.10'"
    assertFalse ">=5.11" "rlIsRHEL '>=5.11'"
    assertTrue "<=6" "rlIsRHEL '<=6'"
    assertTrue ">=4" "rlIsRHEL '>=4'"
}


test_rlIsRHEL(){
  ## with os-release
    assertLog "approach through 'os-release'"
    # calling test function (with first two arguments)
    aux_rlIsRHEL fake_os_release "rhel" ""
    # clean up
    fake_os_release --clean_up

  ## callback without os-release
    assertLog "approach through 'lsb-release' (callback)"
    # init
    fake_os_release   # makes back-up of os-release
    local OLD_PATH=$PATH
    PATH="./:"$PATH
    # calling test function (with first argument)
    aux_rlIsRHEL fake_lsb_release "Red Hat Enterprise Linux Server"
    # clean up
    fake_os_release --clean_up
    PATH=$OLD_PATH
    rm -f "./beakerlib-lsb_release"
}


# axuliary function for test_rlIsCentOS
# just test that CentOS is recognized, operators are tested in rlIsOSVersion
aux_rlIsCentOS(){
    # pretend we're CentOS 7.1
    "$@" "7.1"
    # note: in lsb-release is also etc. "7.1.1503" as the 'build number' of centos 7.1 but this would not work with function based on os-release
    assertTrue "major.minor CentOS7.1 detected correctly" "rlIsCentOS 7.1"
    assertTrue "major CentOS7 detected correctly" "rlIsCentOS 7"
    assertFalse "CentOS 7.1 not mistaken for RHEL7.1" "rlIsRHEL 7.1"
    assertFalse "CentOS 7 not mistaken for RHEL7" "rlIsRHEL 7"

    # pretend we're CentOS 5.11
    "$@" "5.11"
    assertTrue "major.minor CentOS 5.11 detected correctly" "rlIsCentOS 5.11"

    # pretend we're CentOS 6.6
    "$@" "6.6"
    assertTrue "major.minor CentOS 6.6 detected correctly" "rlIsCentOS 6.6"
}


test_rlIsCentOS(){
  ## with os-release
    assertLog "approach through 'os-release'"
    # calling test function (with first two arguments)
    aux_rlIsCentOS fake_os_release "centos" ""
    # clean up
    fake_os_release --clean_up

  ## callback without os-release
    assertLog "approach through 'lsb-release' (callback)"
    # init
    fake_os_release   # makes back-up of os-release
    local OLD_PATH=$PATH
    PATH="./:"$PATH
    # calling test function (with first argument)
    aux_rlIsCentOS fake_lsb_release "CentOS"
    # clean up
    fake_os_release --clean_up
    PATH=$OLD_PATH
    rm -f "./beakerlib-lsb_release"
}


# axuliary function for test_rlIsFedora
# just test that Fedora is recognized, operators are tested in rlIsOSVersion
aux_rlIsFedora(){
    # pretend we're Fedora 25
    "$@" "25"
    assertTrue "major Fedora 25 detected correctly" "rlIsFedora 25"
    # pretend we're Fedora 26
    "$@" "26"
    assertTrue "major Fedora 26 detected correctly" "rlIsFedora 26"
}


test_rlIsFedora(){
  ## with os-release
    assertLog "approach through 'os-release'"
    # calling test function (with first two arguments)
    aux_rlIsFedora fake_os_release "fedora" ""
    # clean up
    fake_os_release --clean_up

  ## callback without os-release
    assertLog "approach through 'lsb-release' (callback)"
    # init
    fake_os_release   # makes back-up of os-release
    local OLD_PATH=$PATH
    PATH="./:"$PATH
    # calling test function (with first argument)
    aux_rlIsFedora fake_lsb_release "Fedora"
    # clean up
    fake_os_release --clean_up
    PATH=$OLD_PATH
    rm -f "./beakerlib-lsb_release"
}


test_rlIsOS(){
    # there is no os-release
    fake_os_release
    assertRun "rlIsOS rhel" "2" "os-release does not exist"

    #there is wrong os-release file
    touch /etc/os-release
    assertRun "rlIsOS fedora" "2" "there is no ID defined"
    fake_os_release "" "fedora" ""
    assertRun "rlIsOS fedora" "2" "there is no match with ID"

    # pretend we're RHEL 8.6 (fedora-like)
    fake_os_release "rhel" "fedora" "8.6"

    assertTrue "ID detected correctly" "rlIsOS rhel"
    assertFalse "incorrect distro ID" "rlIsOS fedora"
    assertRun "rlIsOS" "3" "no argument given"

    # pretend we're Fedora 36
    fake_os_release "fedora" "" "36"

    assertTrue "ID detected correctly" "rlIsOS fedora"
    assertFalse "incorrect ID" "rlIsOS centos"

    # pretend we're CentOS Linux 8
    fake_os_release "centos" "rhel fedora" "8"

    assertTrue "ID detected correctly" "rlIsOS centos"
    assertFalse "incorrect ID" "rlIsOS fedora"
    assertFalse "incorrect ID" "rlIsOS rhel"

    # pretend we're Oracle Linux
    fake_os_release "ol" "fedora" "8.3"

    assertTrue "ID detected correctly" "rlIsOS ol"
    assertFalse "incorrect ID" "rlIsOS fedora"

    #clean up fake os-release
    fake_os_release --clean_up
}


test_rlIsOSLike(){
    # there is no os-release
    fake_os_release
    assertRun "rlIsOSLike rhel" "2" "os-release does not exist"

    #there is wrong os-release file
    touch /etc/os-release
    assertRun "rlIsOSLike fedora" "2" "there is no ID_LIKE nor ID defined"
    fake_os_release "" "" ""
    assertRun "rlIsOSLike fedora" "2" "there is no match with ID_LIKE or ID"

    # pretend we're RHEL 8.6 (fedora-like)
    fake_os_release "rhel" "fedora" "8.6"

    assertTrue "ID_LIKE detected correctly" "rlIsOSLike fedora"
    assertTrue "when wrong ID_LIKE, ID is detected correctly" "rlIsOSLike rhel"
    assertRun "rlIsOSLike" "3" "no argument given"    

    # pretend we're Fedora 36
    fake_os_release "fedora" "" "36"

    assertTrue "no ID_LIKE, but ID is detected correctly" "rlIsOSLike fedora"
    assertFalse "incorrect ID_LIKE" "rlIsOSLike centos"

    # pretend we're CentOS Linux 8
    fake_os_release "centos" "rhel fedora" "8"

    assertTrue "when wrong ID_LIKE ID is detected correctly" "rlIsOSLike centos"
    assertTrue "ID_LIKE detected correctly"  "rlIsOSLike fedora"
    assertTrue "ID_LIKE detected correctly"  "rlIsOSLike rhel"
    assertFalse "incorrect distro ID_LIKE" "rlIsOSLike ol"

    # pretend we're Oracle Linux
    fake_os_release "ol" "fedora" "8.3"

    assertTrue "ID_LIKE detected correctly" "rlIsOSLike fedora"
    assertTrue "when wrong ID_LIKE, ID is detected correctly" "rlIsOSLike ol"
    assertFalse "incorrect distro ID_LIKE" "rlIsOSLike centos"

    #clean up fake os-release
    fake_os_release --clean_up
}



test_rlIsOSVersion(){
    # there is no os-release
    fake_os_release
     assertRun "rlIsOSVersion 8.6" "3" "os-release does not exist"

    #there is wrong os-release file
    touch /etc/os-release
    assertRun "rlIsOSVersion 8.6" "3" "there is no VERSION_ID defined"
    fake_os_release "rhel" "fedora" ""
    assertRun "rlIsOSVersion 8.6" "2" "there is no match with VERSION_ID"

    # pretend we're RHEL 8.6 (fedora-like)
    fake_os_release "rhel" "fedora" "8.6"

    assertTrue "correct major" "rlIsOSVersion 8"
    assertFalse "incorrect major" "rlIsOSVersion 9"
    assertTrue "correct major.minor" "rlIsOSVersion 8.6"
    assertFalse "incorrect minor" "rlIsOSVersion 8.5"
    assertFalse "incorrect major" "rlIsOSVersion 7.6"
    assertTrue "multiple majors, one correct" "rlIsOSVersion 6.6 7.6 8.6 9.6"
    assertTrue "multiple minors, one correct" "rlIsOSVersion 8.6 8.5 8.4 8.3"
    assertFalse "multiple args, none correct" "rlIsOSVersion 6.5 7.4 8.0"

    assertTrue "<9 (escaped)" "rlIsOSVersion \<9"
    assertFalse "<8" "rlIsOSVersion '<8'"
    assertFalse "<8.6" "rlIsOSVersion '<8.6'"
    assertTrue "<8.7" "rlIsOSVersion '<8.7'"
    assertTrue ">7 (escaped)" "rlIsOSVersion \>7"
    assertTrue ">7.7" "rlIsOSVersion '>7.7'"
    assertFalse ">8" "rlIsOSVersion '>8'"
    assertTrue ">8.0" "rlIsOSVersion '>8.0'"
    assertTrue ">8.5" "rlIsOSVersion '>8.5'"
    assertFalse ">8.6" "rlIsOSVersion '>8.6'"

    assertTrue "=8" "rlIsOSVersion '=8'" # new implementation compares it as major (not as 8.0)
    assertTrue "<=8" "rlIsOSVersion '<=8'"
    assertTrue "=<8" "rlIsOSVersion '=<8'"
    assertTrue "<=9" "rlIsOSVersion '<=9'"
    assertFalse ">=9" "rlIsOSVersion '>=9'"
    assertTrue ">=5" "rlIsOSVersion '>=5'"
    assertFalse "<=8.0" "rlIsOSVersion '<=8.0'"
    assertTrue "<=8.6" "rlIsOSVersion '<=8.6'"
    assertTrue "<=9.5" "rlIsOSVersion '<=9.5'"
    assertTrue ">=8" "rlIsOSVersion '>=8'"
    assertTrue "=>8" "rlIsOSVersion '=>8'"
    assertTrue ">=8.0" "rlIsOSVersion '>=8.0'"
    assertTrue ">=8.5" "rlIsOSVersion '>=8.5'"
    assertTrue "=>7.0" "rlIsOSVersion '=>7.0'"
    assertTrue ">=7.0 (escaped)" "rlIsOSVersion \>=7.0"
    assertTrue ">=8.6" "rlIsOSVersion '>=8.6'"
    assertFalse ">=8.7" "rlIsOSVersion '>=8.7'"

    assertTrue ">=8.6 and others" "rlIsOSVersion '>=8.6' =9 8.5 \<7.9"
    assertFalse ">8.6 and others" "rlIsOSVersion '>8.6' =9 8.5 \<7.9"
    assertTrue "<8.5 || <9.5 (within both majors and minors)" "rlIsOSVersion '<8.5' || rlIsOSVersion '<9.5'"
    assertFalse "<8.5 || <9.5 (within minors)" "rlIsOSVersion 8 && rlIsOSVersion '<8.5' || rlIsOSVersion 9 && rlIsOSVersion '<9.5'"

    assertTrue "syntax error: superfluous space #1" "rlIsOSVersion '>= 8.5'" # works in new implementation
    assertFalse "syntax error: superfluous space #2" "rlIsOSVersion '>=' '8.5'"
    assertFalse "syntax error: operators only" "rlIsOSVersion '<='"
    assertFalse "syntax error: unknown operator" "rlIsOSVersion '*8.5'"
    assertTrue "syntax error: no arguments" "rlIsOSVersion" # no error in new implementation (acting as noop)

    # pretend we're Fedora 36
    fake_os_release "fedora" "" "36"

    assertTrue "36" "rlIsOSVersion 36"
    assertTrue "=36" "rlIsOSVersion =36"
    assertTrue "<36.1" "rlIsOSVersion \<36.1"
    assertTrue ">35.7" "rlIsOSVersion \>35.7"

    #clean up fake os-release
    fake_os_release --clean_up
}


test_rlIsRHELLike(){
    # there is no os-release
    fake_os_release
    assertRun "rlIsRHELLike 7" "2" "os-release does not exist"

    # pretend we're RHEL 8.6 (fedora-like)
    fake_os_release "rhel" "fedora" "8.6"

    assertTrue "rhel-like distro and its version detected correctly" "rlIsRHELLike '>=8'"
    assertFalse "rhel-like distro but wrong version" "rlIsRHELLike '<8'"
    assertTrue "rhel-like distro detected correctly, no arg for version" "rlIsRHELLike"

    # pretend we're Fedora 36
    fake_os_release "fedora" "" "36"

    assertFalse "it is not rhel-like distro nor version from the range" "rlIsRHELLike '>=8'"
    assertFalse "it is not rhel-like distro" "rlIsRHELLike"

    # pretend we're CentOS Linux 8
    fake_os_release "centos" "rhel fedora" "8"

    assertTrue "rhel-like distro and its version detected correctly" "rlIsRHELLike '>=8'"
    assertFalse "rhel-like distro but wrong version" "rlIsRHELLike '<8'"
    assertTrue "rhel-like distro detected correctly, no arg for version" "rlIsRHELLike"

    # pretend we're Oracle Linux 8.3
    fake_os_release "ol" "fedora" "8.3"

    assertFalse "it is not rhel-like distro nor version from the range" "rlIsRHELLike '>=8'"
    assertFalse "it is not rhel-like distro" "rlIsRHELLike"

    #clean up fake os-release
    fake_os_release --clean_up
}


test_rlHash(){
    local STRING="string to be hashed"
    local STRING_HEX=$(echo -n $STRING | od -A n -t x1 -v | tr -d ' \n\t')
    local STRING_BASE64=$(echo -n  $STRING | base64)
    local STRING_BASE64_=$(echo -n  $STRING | base64 | tr '=' '_')

    # rlHash
    local rlHashed=$(rlHash "$STRING")
    assertTrue "rlHash default algorithm" "[[ $rlHashed == $STRING_HEX ]]"

    local rlHashed=$(rlHash --algorithm=hex "$STRING")
    assertTrue "rlHash hex algorithm" "[[ $rlHashed == $STRING_HEX ]]"

    local rlHashed=$(rlHash --algorithm=base64 "$STRING")
    assertTrue "rlHash base64 algorithm" "[[ $rlHashed == $STRING_BASE64 ]]"

    local rlHashed=$(rlHash --algorithm=base64_ "$STRING")
    assertTrue "rlHash base64_ algorithm" "[[ $rlHashed == $STRING_BASE64_ ]]"

    # rlHash --decode
    local rlHashed=$(rlHash --decode "$STRING_HEX")
    assertTrue "rlHash --decode default algorithm" "[[ \"$rlHashed\" == \"$STRING\" ]]"

    local rlHashed=$(rlHash --decode --algorithm=hex "$STRING_HEX")
    assertTrue "rlHash --decode hex algorithm" "[[ \"$rlHashed == $STRING\" ]]"

    local rlHashed=$(rlHash --decode --algorithm=base64 "$STRING_BASE64")
    assertTrue "rlHash --decode  base64 algorithm" "[[ \"$rlHashed\" == \"$STRING\" ]]"

    local rlHashed=$(rlHash --decode --algorithm=base64_ "$STRING_BASE64_")
    assertTrue "rlHash --decode base64_ algorithm" "[[ \"$rlHashed\" == \"$STRING\" ]]"
}

test_rlUnhash(){
    local STRING="string to be unhashed"
    local STRING_HEX=$(echo -n $STRING | od -A n -t x1 -v | tr -d ' \n\t')
    local STRING_BASE64=$(echo -n  $STRING | base64)
    local STRING_BASE64_=$(echo -n  $STRING | base64 | tr '=' '_')

    local rlUnhashed=$(rlUnhash "$STRING_HEX")
    assertTrue "rlUnhash default algorithm" "[[ \"$rlUnhashed\" == \"$STRING\" ]]"

    local rlUnhashed=$(rlUnhash --algorithm=hex "$STRING_HEX")
    assertTrue "rlUnhash hex algorithm" "[[ \"$rlUnhashed == $STRING\" ]]"

    local rlUnhashed=$(rlUnhash --algorithm=base64 "$STRING_BASE64")
    assertTrue "rlUnhash base64 algorithm" "[[ \"$rlUnhashed\" == \"$STRING\" ]]"

    local rlUnhashed=$(rlUnhash --algorithm=base64_ "$STRING_BASE64_")
    assertTrue "rlUnhash base64_ algorithm" "[[ \"$rlUnhashed\" == \"$STRING\" ]]"
}
