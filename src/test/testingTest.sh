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
  silentIfNotDebug 'journalReset'
  silentIfNotDebug 'rlPhaseStartTest'
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
  rlPhaseEnd
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

    PREFIX_REGEXP='^:: \[ [0-9]{2}:[0-9]{2}:[0-9]{2} \] ::[[:space:]]+'

    rlRun -l 'echo "foobar3"' &>/dev/null
    grep 'echo "foobar3"' "$OUTPUTFILE" --quiet && egrep "${PREFIX_REGEXP}"'foobar3' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging plain" "[ $? -eq 0 ]"

    rm -f foobar3
    rlRun -l 'cat "foobar3"' &>/dev/null
    assertTrue "rlRun logging plain with bad exit code" "[ $? -eq 1 ]"

    rlRun -l -t 'echo "foobar4"' &>/dev/null
    grep 'echo "foobar4"' "$OUTPUTFILE" --quiet && egrep "${PREFIX_REGEXP}"'STDOUT: foobar4' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging with tagging (stdout)" "[ $? -eq 0 ]"

    rlRun -l -t 'echo "foobar5" 1>&2' &>/dev/null
    grep 'echo "foobar5" 1>&2' "$OUTPUTFILE" --quiet && egrep "${PREFIX_REGEXP}"'STDERR: foobar5' "$OUTPUTFILE" --quiet
    assertTrue "rlRun logging with tagging (stderr)" "[ $? -eq 0 ]"

    rlRun -s 'echo "foobar6_stdout"; echo "foobar6_stderr" 1>&2' &>/dev/null

    rlAssertGrep "foobar6_stdout" "$rlRun_LOG" &>/dev/null && rlAssertGrep "foobar6_stderr" "$rlRun_LOG" &>/dev/null
    assertTrue "rlRun -s - rlRun_LOG OK" "[ $? -eq 0 ]"

    rm -f foobar7
    rlRun -c 'cat "foobar7"' &>/dev/null
    grep 'cat "foobar7"' "$OUTPUTFILE" --quiet && egrep "${PREFIX_REGEXP}"'cat: foobar7: No such file or directory' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging plain" "[ $? -eq 0 ]"

    echo 'foobar8_content' > foobar8
    rlRun -c 'cat "foobar8"' &>/dev/null
    grep 'cat "foobar8"' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging records command" "[ $? -eq 0 ]"
    grep 'foobar8_content' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging do not record output when all is OK" "[ $? -ne 0 ]"
    rm -f foobar8

    rm -f foobar9
    rlRun -c -t 'cat "foobar9" 1>&2' &>/dev/null
    grep 'cat "foobar9" 1>&2' "$OUTPUTFILE" --quiet && egrep "${PREFIX_REGEXP}"'STDERR: cat: foobar9: No such file or directory' "$OUTPUTFILE" --quiet
    assertTrue "rlRun conditional logging with tagging (stderr)" "[ $? -eq 0 ]"

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
  rlPhaseStartSetup &> /dev/null

  for res in PASS FAIL WARN
  do
    OUT="$(rlReport TEST $res | grep ANCHOR)"
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"ANCHOR NAME: TEST\nRESULT: $res\n LOGFILE: $OUTPUTFILE\nSCORE: \" ]"
    OUT="$(rlReport "TEST TEST" $res | grep ANCHOR)"
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\nRESULT: $res\n LOGFILE: $OUTPUTFILE\nSCORE: \" ]"
    OUT="$(rlReport "TEST" $res 5 "/tmp/logname" | grep ANCHOR)" # no-reboot
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"ANCHOR NAME: TEST\nRESULT: $res\n LOGFILE: /tmp/logname\nSCORE: 5\" ]" # no-reboot
    OUT="$(rlReport "TEST TEST" $res 8 "/tmp/log name" | grep ANCHOR)" # no-reboot
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\nRESULT: $res\n LOGFILE: /tmp/log name\nSCORE: 8\" ]" # no-reboot
  done
  rlPhaseEnd &> /dev/null
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

  local pseudophases="$(grep 'Asserts collected outside of a phase' $TXTJRNL | grep LOG | wc -l)"
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

test_rlIsRHEL(){
    # pretend we're RHEL6.5
    local OLD_PATH=$PATH
    PATH="./:"$PATH
    fake_lsb_release "Red Hat Enterprise Linux Server" "6.5"

    assertTrue "major.minor detected correctly" "rlIsRHEL 6.5"
    assertTrue "major detected correctly" "rlIsRHEL 6"
    assertFalse "incorrect minor" "rlIsRHEL 6.3"
    assertFalse "incorrect major" "rlIsRHEL 5.5"
    assertTrue "multiple majors, one correct" "rlIsRHEL 4.5 5.5 6.5 7.5"
    assertTrue "multiple minors, one correct" "rlIsRHEL 6.3 6.4 6.5 6.6"
    assertFalse "multiple args, none correct" "rlIsRHEL 4.5 6.4 7.0"
    assertFalse "syntax error: superfluous space #1" "rlIsRHEL '>= 6.3'"
    assertFalse "syntax error: superfluous space #2" "rlIsRHEL '>=' '6.3'"
    assertFalse "syntax error: operators only" "rlIsRHEL '<='"
    assertFalse "syntax error: unknown operator" "rlIsRHEL '*6.5'"
    assertTrue "syntax error: no input - checking RHEL only" "rlIsRHEL"

    fake_lsb_release "Red Hat Enterprise Linux Server" "5.10"
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

    #clean up the fake command
    PATH=$OLD_PATH
    rm -f "./beakerlib-lsb_release"
}

# just test that CentOS is recognized, operators are tested in rlIsRHEL
test_rlIsCentOS(){
    # pretend we're CentOS7.1
    local OLD_PATH=$PATH
    PATH="./:"$PATH
    # yup, centos 7.1 has the build number (or what that 1503 is) in release
    fake_lsb_release "CentOS" "7.1.1503"

    assertTrue "major.minor CentOS7.1 detected correctly" "rlIsCentOS 7.1"
    assertTrue "major CentOS7 detected correctly" "rlIsCentOS 7"

    assertFalse "CentOS7.1 not mistaken for RHEL7.1" "rlIsRHEL 7.1"
    assertFalse "CentOS7 not mistaken for RHEL7" "rlIsRHEL 7"


    fake_lsb_release "CentOS" "5.11"
    assertTrue "major.minor CentOS5.11 detected correctly" "rlIsCentOS 5.11"

    fake_lsb_release "CentOS" "6.6"
    assertTrue "major.minor CentOS6.6 detected correctly" "rlIsCentOS 6.6"

    #clean up the fake command
    PATH=$OLD_PATH
    rm -f "./beakerlib-lsb_release"
}

