#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Unit testing library for BeakerLib
#   Author: Ales Zelinka <azelinka@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a simple unit testing library for BeakerLib.
#   Have a look at the README file to learn more about it.


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Global variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TotalFailed="0"
TotalPassed="0"
FileList=""
TestList=""

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertLog comment [result] --- log a comment (with optional result)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertLog() {
    local comment="$1"
    local result="${2:-INFO}"

    # colorify known results if run on terminal
    if [ -t 1 ]; then
        case $result in
            INFO) result="\033[0;34mINFO\033[0m";;
            PASS) result="\033[0;32mPASS\033[0m";;
            FAIL) result="\033[0;31mFAIL\033[0m";;
            WARN) result="\033[0;33mWARN\033[0m";;
            SKIP) result="\033[0;37mSKIP\033[0m"
                  ((__INTERNAL_ASSERT_SKIPPED++))
                  ((TotalSkipped++))
                ;;
        esac
    fi

    # echo!
    echo -e " [ $result ] $comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertRun command [status] [comment] --- run command, check status, log
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertRun() {
    local command="$1"
    local expected="${2:-0}"
    local comment="${3:-Running $command}"

    # no output unless in debug mode
    if [ "$DEBUG" == "1" ]; then
        eval "$command"
    else
        eval "$command" &> /dev/null
    fi
    local status=$?

    # check status
    if [[ "$status" =~ ^$expected$ ]]; then
        assertLog "$comment" 'PASS'
        ((__INTERNAL_ASSERT_PASSED++))
        ((TotalPassed++))
    else
        assertLog "$comment" 'FAIL'
        ((__INTERNAL_ASSERT_FAILED++))
        ((TotalFailed++))
        [ "$DEBUG" == "1" ] && assertLog "Expected $expected, got $status"
    fi
}

silentIfNotDebug() {
    local command="$1"
    if [ "$DEBUG" == "1" ]
    then
      eval "$command"
    else
      eval "$command" &> /dev/null
    fi
}

journalReset() {
  [ -e "$BEAKERLIB_JOURNAL" ] && rm $BEAKERLIB_JOURNAL
  [ -e "$BEAKERLIB_DIR" ] && ( chmod -R 777 $BEAKERLIB_DIR ; rm -rf $BEAKERLIB_DIR; )
  unset __INTERNAL_RPM_ASSERTED_PACKAGES
  silentIfNotDebug 'rlJournalStart'
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertStart name --- start an assert phase
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertStart() {
    local phase="$1"
    echo
    assertLog "Testing $phase"
    __INTERNAL_ASSERT_PHASE="$phase"
    __INTERNAL_ASSERT_PASSED="0"
    __INTERNAL_ASSERT_FAILED="0"
    __INTERNAL_ASSERT_SKIPPED="0"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertEnd --- short phase summary (returns number of failed asserts)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertEnd() {
    local failed="$__INTERNAL_ASSERT_FAILED"
    local passed="$__INTERNAL_ASSERT_PASSED"
    local skipped="$__INTERNAL_ASSERT_SKIPPED"
    local name="$__INTERNAL_ASSERT_PHASE"

    if [ "$failed" -gt "0" ]; then
        assertLog "Testing $name finished: $passed passed, $failed failed, $skipped skipped" "FAIL"
    elif [ "$passed" -gt "0" ]; then
        assertLog "Testing $name finished: $passed passed, $failed failed, $skipped skipped" "PASS"
    else
        assertLog "Testing $name finished: No assserts run" "WARN"
    fi

    printf "%i:%i:%i\n" $__INTERNAL_ASSERT_PASSED $__INTERNAL_ASSERT_FAILED $__INTERNAL_ASSERT_SKIPPED>> $SCOREFILE
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertTrue comment command --- check that command succeeded
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertTrue() {
    local comment="$1"
    local command="$2"

    assertRun "$command" 0 "$comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertFalse comment command --- check that command failed
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertFalse() {
    local comment="$1"
    local command="$2"
    local expects="${3:-1}"

    assertRun "$command" "$expects" "$comment"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertGoodBad command good bad --- check for good/bad asserts in journal
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertGoodBad() {
    local command="$1"
    local good="$2"
    local bad="$3"

    if [[ -n "$good" ]]; then
        rm $BEAKERLIB_JOURNAL; rlJournalStart
        assertTrue "$good good logged for '$command'" \
                "rlPhaseStart FAIL; $command; rlPhaseEnd;
                rlJournalPrintText | egrep 'Assertions: *$good *good, *[0-9]+ *bad'"
    fi

    if [[ -n "$bad" ]]; then
        rm $BEAKERLIB_JOURNAL; rlJournalStart
        assertTrue "$bad bad logged for '$command'" \
                "rlPhaseStart FAIL; $command; rlPhaseEnd;
                rlJournalPrintText | egrep 'Assertions: *[0-9]+ *good, *$bad *bad'"
    fi
    rm $BEAKERLIB_JOURNAL; rlJournalStart
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   assertParameters assert --- check missing parameters
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

assertParameters() {
	rm $BEAKERLIB_JOURNAL; rlJournalStart
	assertTrue "running '$1' (all parameters) must succeed" \
	"rlPhaseStart FAIL; $1 ; rlPhaseEnd ;  rlJournalPrintText |grep '1 *good'"
	local CMD=""
	for i in $1 ; do
		CMD="${CMD}${i} "
		if [ "x$CMD" == "x$1 " ] ; then break ; fi
		#echo "--$1-- --$CMD--"
		rm $BEAKERLIB_JOURNAL; rlJournalStart
		assertFalse "running just '$CMD' (missing parameters) must not succeed" \
	    "rlPhaseStart FAIL; $CMD ; rlPhaseEnd ;  rlJournalPrintText |grep '1 *good'"
	done
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Fake rhts-report-result
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rhts-report-result(){
  echo "ANCHOR NAME: $1\nRESULT: $2\n LOGFILE: $3\nSCORE: $4"
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Self test --- run a simple self test if called as 'test.sh test'
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [ "$1" == "test" ]; then
    assertStart "logging"
        assertLog "Some comment with a pass" "PASS"
        assertLog "Some comment with a fail" "FAIL"
    assertEnd

    assertStart "passing asserts"
        assertRun "true"
        assertRun "true" 0
        assertRun "true" 0 "Checking true with assertRun"
        assertRun "false" 1
        assertRun "false" 1 "Checking false with assertRun"
        assertTrue "Checking true with assertTrue" "true"
        assertFalse "Checking false with assertFalse" "false"
    assertEnd

    assertStart "failing asserts"
        assertRun "false"
        assertRun "false" 0
        assertRun "false" 0 "Checking false with assertRun"
        assertRun "true" 1
        assertRun "true" 1 "Checking true with assertRun"
        assertTrue "Checking false with assertTrue" "false"
        assertFalse "Checking true with assertFalse" "true"
    assertEnd

    [ $TotalPassed == 7 -a $TotalFailed == 7 ] && exit 0 || exit 1
fi



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Run the tests
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# set important variables & start journal
export BEAKERLIB="$PWD/.."
export TESTID='123456'
export TEST='beakerlib-unit-tests'
. ../beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"
export __INTERNAL_STORAGE_BIN="$BEAKERLIB/python/bstor.py"
export OUTPUTFILE=$(mktemp) # no-reboot
export SCOREFILE=$(mktemp) # no-reboot
rlJournalStart

# check parameters for test list
for arg in "$@"; do
    # selected test function
    if [[ "$arg" =~ 'test_' ]]; then
        TestList="$TestList $arg"
    # test file
    elif [[ "$arg" =~ 'Test.sh' ]]; then
        FileList="$FileList $arg"
    else
        echo "What do you mean by $arg?"
        exit 1
    fi
done

# unless test files specified run all available
[[ -z "$FileList" ]] && FileList="$(ls *Test.sh)"

# load all test functions
for file in $FileList; do
    . $file || { echo "Could not load $file"; exit 1; }
done

assessFile(){
    local file="$1"
    assertStart ${file%Test.sh}
    for test in $(grep --text -o '^test_[^ (]*' $file); do
        assertLog "Running $test"
        silentIfNotDebug "journalReset"
        $test
    done
    assertEnd
}

export TIMEFORMAT="System: %S seconds; User: %U seconds"
TIMEFILE=$( mktemp -u ) # no-reboot
# run all tests
if [[ -z "$TestList" ]]; then
    for file in $FileList; do
      (time ( { assessFile $file; } 2>&3 ) ) 3>&2 2>>$TIMEFILE.$( basename $file )
      OLDTIMEFILE=".$( basename $file)-perf.old"
      if [ -e $OLDTIMEFILE ]
      then
        OLDPERF="$( cat $OLDTIMEFILE )"
      fi
      assertLog "Measurement: $( cat $TIMEFILE.$( basename $file ) )"
      if [ -n "$OLDPERF" ]
      then
        assertLog "        Was: $OLDPERF"
      fi
    done
# run selected tests only
else
    for test in $TestList; do
        assertStart "$test"
        silentIfNotDebug "journalReset"
        $test
        assertEnd
    done
fi

# clean up
rm -rf $BEAKERLIB_DIR

# print summary
echo
for file in $( ls ${TIMEFILE}* 2>/dev/null )
do
    OLDTIMEFILE=".${file#$TIMEFILE.}-perf.old"
    assertLog "${file#$TIMEFILE.} performance: $( cat $file )"
    if [ -e $OLDTIMEFILE ]
    then
      assertLog "${file#$TIMEFILE.}   Was:       $( cat $OLDTIMEFILE )"
    fi
    cat $file > $OLDTIMEFILE
done

while read line
do
  PASS=$( echo $line | cut -d ':' -f 1)
  FAIL=$( echo $line | cut -d ':' -f 2 )
  SKIP=$( echo $line | cut -d ':' -f 3 )
  TotalPassed=$(( $TotalPassed+$PASS ))
  TotalFailed=$(( $TotalFailed+$FAIL ))
  TotalSkipped=$(( $TotalSkipped+$SKIP ))
done < $SCOREFILE

rm -rf $TIMEFILE* $SCOREFILE

if [ $TotalPassed -gt 0 -a $TotalFailed == 0 ]; then
    assertLog "Total summary: $TotalPassed passed, $TotalFailed failed, $TotalSkipped skipped\n" "PASS"
    exit 0
else
    assertLog "Total summary: $TotalPassed passed, $TotalFailed failed, $TotalSkipped skipped\n" "FAIL"
    exit 1
fi
