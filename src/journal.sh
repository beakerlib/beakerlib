# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: journal.sh - part of the BeakerLib project
#   Description: Journalling functionality
#
#   Author: Petr Muller <pmuller@redhat.com>
#   Author: Jan Hutar <jhutar@redhat.com>
#   Author: Ales Zelinka <azelinka@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2010 Red Hat, Inc. All rights reserved.
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
echo "${__INTERNAL_SOURCED}" | grep -qF -- " ${BASH_SOURCE} " && return || __INTERNAL_SOURCED+=" ${BASH_SOURCE} "

: <<'=cut'
=pod

=head1 NAME

BeakerLib - journal - journalling functionality

=head1 DESCRIPTION

Routines for initializing the journalling features and pretty
printing journal contents.

=head1 FUNCTIONS

=cut

__INTERNAL_JOURNALIST=beakerlib-journalling
__INTERNAL_TIMEFORMAT_TIME="%H:%M:%S"
__INTERNAL_TIMEFORMAT_DATE_TIME="%Y-%m-%d %H:%M:%S %Z"
__INTERNAL_TIMEFORMAT_SHORT="$__INTERNAL_TIMEFORMAT_TIME"
__INTERNAL_TIMEFORMAT_LONG="$__INTERNAL_TIMEFORMAT_DATE_TIME"


# $1 - var name to the the output to
# $2 - format string
# $3 - data
__INTERNAL_format_time() {
  printf -v ${1} "%(${2})T" "${3}"
}
printf "%(%s)T" -1 >& /dev/null || __INTERNAL_format_time() {
  local t
  [[ "$3" == "-1" ]] && t='' || t="-d \"@${3}\""
  eval "${1}=\$(date +\"${2}\" ${t})"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlJournalStart
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Journalling

=head3 rlJournalStart

Initialize the journal file.

    rlJournalStart

Run on the very beginning of your script to initialize journalling
functionality.

=cut

rlJournalStart(){
    __INTERNAL_SET_TIMESTAMP
    export __INTERNAL_STARTTIME="$__INTERNAL_TIMESTAMP"
    export __INTERNAL_ENDTIME=""
    # test-specific temporary directory for journal/metadata
    if [ -n "$BEAKERLIB_DIR" ]; then
        # try user-provided temporary directory first
        true
    elif [ -n "$TESTID" ]; then
        # if available, use TESTID for the temporary directory
        # - this is useful for preserving metadata through a system reboot
        export BEAKERLIB_DIR="$__INTERNAL_PERSISTENT_TMP/beakerlib-$TESTID"
    else
        # else generate a random temporary directory
        export BEAKERLIB_DIR=$(mktemp -d $__INTERNAL_PERSISTENT_TMP/beakerlib-XXXXXXX)
    fi

    [ -d "$BEAKERLIB_DIR" ] || mkdir -p "$BEAKERLIB_DIR" || {
      __INTERNAL_LogText "could not create BEAKERLIB_DIR $BEAKERLIB_DIR" FATAL
      exit 1
    }

    # set global internal BeakerLib journal and metafile variables
    export __INTERNAL_BEAKERLIB_JOURNAL="$BEAKERLIB_DIR/journal.xml"
    export __INTERNAL_BEAKERLIB_METAFILE="$BEAKERLIB_DIR/journal.meta"
    export __INTERNAL_BEAKERLIB_JOURNAL_TXT="$BEAKERLIB_DIR/journal.txt"
    export __INTERNAL_BEAKERLIB_JOURNAL_COLORED="$BEAKERLIB_DIR/journal_colored.txt"

    # make sure the directory is ready, otherwise we cannot continue
    if [ ! -d "$BEAKERLIB_DIR" ] ; then
        echo "rlJournalStart: Failed to create $BEAKERLIB_DIR directory."
        echo "rlJournalStart: Cannot continue, exiting..."
        exit 1
    fi

    # creating queue file
    touch $__INTERNAL_BEAKERLIB_METAFILE || {
      __INTERNAL_LogText "could not write to BEAKERLIB_DIR $BEAKERLIB_DIR" FATAL
      exit 1
    }

    # Initialization of variables holding current state of the test
    export __INTERNAL_METAFILE_INDENT_LEVEL=0
    __INTERNAL_PHASE_TYPE=()
    __INTERNAL_PHASE_NAME=()
    export __INTERNAL_PERSISTENT_DATA="$BEAKERLIB_DIR/PersistentData"
    export __INTERNAL_TEST_RESULTS="$BEAKERLIB_DIR/TestResults"
    export __INTERNAL_JOURNAL_OPEN=''
    export __INTERNAL_PHASES_FAILED=0
    export __INTERNAL_PHASES_PASSED=0
    export __INTERNAL_PHASES_SKIPPED=0
    export __INTERNAL_PHASES_WORST_RESULT='PASS'
    export __INTERNAL_TEST_STATE=0
    __INTERNAL_PHASE_TXTLOG_START=()
    __INTERNAL_PHASE_FAILED=()
    __INTERNAL_PHASE_PASSED=()
    __INTERNAL_PHASE_STARTTIME=()
    __INTERNAL_PHASE_METRICS=()
    export __INTERNAL_PHASE_OPEN=0
    __INTERNAL_PersistentDataLoad

    if [[ -z "$__INTERNAL_JOURNAL_OPEN" ]]; then
      # Create Header for XML journal
      __INTERNAL_CreateHeader
      # Create log element for XML journal
      __INTERNAL_WriteToMetafile log || {
        __INTERNAL_LogText "could not write to metafile" FATAL
        exit 1
      }
      __INTERNAL_JOURNAL_OPEN=1
      # Increase level of indent
      __INTERNAL_METAFILE_INDENT_LEVEL=1
    fi

    # display a warning message if run in POSIX mode
    if [ $POSIXFIXED == "YES" ] ; then
        rlLogWarning "POSIX mode detected and switched off"
        rlLogWarning "Please fix your test to have /bin/bash shebang"
    fi

    # Check BEAKERLIB_JOURNAL parameter
    [ -n "$BEAKERLIB_JOURNAL" ] && __INTERNAL_JournalParamCheck

    # final cleanup file (atomic updates)
    export __INTERNAL_CLEANUP_FINAL="$BEAKERLIB_DIR/cleanup.sh"
    # cleanup "buffer" used for append/prepend
    export __INTERNAL_CLEANUP_BUFF="$BEAKERLIB_DIR/clbuff"

    if touch "$__INTERNAL_CLEANUP_FINAL" "$__INTERNAL_CLEANUP_BUFF"; then
        rlLogDebug "rlJournalStart: Basic cleanup infrastructure successfully initialized"

        if [ -n "$TESTWATCHER_CLPATH" ] && \
           echo "$__INTERNAL_CLEANUP_FINAL" > "$TESTWATCHER_CLPATH"; then
            rlLogDebug "rlJournalStart: Running in test watcher and setup was successful"
            export __INTERNAL_TESTWATCHER_ACTIVE=true
        else
            rlLogDebug "rlJournalStart: Not running in test watcher or setup failed."
        fi
    else
        rlLogError "rlJournalStart: Failed to set up cleanup infrastructure"
    fi
    __INTERNAL_PersistentDataSave
}

# backward compatibility
rlStartJournal() {
    rlJournalStart
    rlLogWarning "rlStartJournal is obsoleted by rlJournalStart"
}

# Check if XML journal is to be created and if so
# whether it should be xsl transformed and how.
# Sets BEAKERLIB_JOURNAL and __INTERNAL_XSLT vars.
__INTERNAL_JournalParamCheck(){
    __INTERNAL_XSLT=''
    if [[ "$BEAKERLIB_JOURNAL" != "0" ]]; then
        if [[ -r "$BEAKERLIB/xslt-templates/$BEAKERLIB_JOURNAL" ]]; then
            __INTERNAL_XSLT="--xslt $BEAKERLIB/xslt-templates/$BEAKERLIB_JOURNAL"
        elif [[ -r "$BEAKERLIB_JOURNAL" ]]; then
            __INTERNAL_XSLT="--xslt $BEAKERLIB_JOURNAL"
        else
            rlLogError "xslt file '$BEAKERLIB_JOURNAL' is not readable"
            BEAKERLIB_JOURNAL="0"
        fi
    else
        rlLogInfo "skipping xml journal creation"
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlJournalEnd
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlJournalEnd

Summarize the test run and upload the journal file.

    rlJournalEnd

Run on the very end of your script to print summary of the whole test run,
generate OUTPUTFILE and include journal in Beaker logs.

=cut

rlJournalEnd(){
    if [ -z "$__INTERNAL_TESTWATCHER_ACTIVE" ] && [ -s "$__INTERNAL_CLEANUP_FINAL" ] && \
       [ -z "$__INTERNAL_CLEANUP_FROM_JOURNALEND" ]
    then
      rlLogWarning "rlJournalEnd: Not running in test watcher and rlCleanup* functions were used"
      rlLogWarning "rlJournalEnd: Executing prepared cleanup"
      rlLogWarning "rlJournalEnd: Please fix the test to use test watcher"

      # The executed cleanup will always run rlJournalEnd, so we need to prevent
      # infinite recursion. rlJournalEnd runs the cleanup only when
      # __INTERNAL_CLEANUP_FROM_JOURNALEND is not set (see above).
      __INTERNAL_CLEANUP_FROM_JOURNALEND=1 "$__INTERNAL_CLEANUP_FINAL"

      # Return, because the rest of the rlJournalEnd was already run inside the cleanup
      return $?
    fi

    if [ -z "$BEAKERLIB_COMMAND_SUBMIT_LOG" ]
    then
      local BEAKERLIB_COMMAND_SUBMIT_LOG="$__INTERNAL_DEFAULT_SUBMIT_LOG"
    fi

    __INTERNAL_SET_TIMESTAMP
    __INTERNAL_ENDTIME=$__INTERNAL_TIMESTAMP
    __INTERNAL_update_journal_txt

    __INTERNAL_PrintHeadLog "${__INTERNAL_TEST_NAME}" 2>&1

    if [ -n "$TESTID" ] ; then
        __INTERNAL_JournalXMLCreate
        $BEAKERLIB_COMMAND_SUBMIT_LOG -l $__INTERNAL_BEAKERLIB_JOURNAL \
        || rlLogError "rlJournalEnd: Submit wasn't successful"
    else
        [[ "$BEAKERLIB_JOURNAL" == "0" ]] || rlLog "JOURNAL XML: $__INTERNAL_BEAKERLIB_JOURNAL"
        rlLog "JOURNAL TXT: $__INTERNAL_BEAKERLIB_JOURNAL_TXT"
    fi

    echo "#End of metafile" >> $__INTERNAL_BEAKERLIB_METAFILE

    __INTERNAL_PrintFootLog $__INTERNAL_STARTTIME \
                            $__INTERNAL_ENDTIME \
                            Phases \
                            $__INTERNAL_PHASES_PASSED \
                            $__INTERNAL_PHASES_FAILED \
                            $__INTERNAL_PHASES_WORST_RESULT \
                            "OVERALL" \
                            "($__INTERNAL_TEST_NAME)"

    __INTERNAL_JournalXMLCreate
    __INTERNAL_TestResultsSave
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# __INTERNAL_JournalXMLCreate
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#: <<'=cut'
#=pod
#
#=head3 __INTERNAL_JournalXMLCreate
#
#Create XML version of the journal from internal structure.
#
#    __INTERNAL_JournalXMLCreate
#
#=cut

__INTERNAL_JournalXMLCreate() {
    local res=0
    [[ "$BEAKERLIB_JOURNAL" == "0" ]] || {
      if which python &> /dev/null; then
        $__INTERNAL_JOURNALIST $__INTERNAL_XSLT --metafile \
          "$__INTERNAL_BEAKERLIB_METAFILE" --journal "$__INTERNAL_BEAKERLIB_JOURNAL"
        res=$?
        if [[ $res -eq 2 ]]; then
          rlLogWarning "cannot create journal.xml due to missing some python module"
        elif [[ $res -eq 3 ]]; then
          rlLogWarning "cannot create journal.xml due to missing python lxml module"
        elif [[ $res -ne 0 ]]; then
          rlLogError "journal.xml creation failed!"
        fi
      else
        rlLogWarning "cannot create journal.xml due to missing python interpreter"
        let res++
      fi
    }
    return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlJournalPrint
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlJournalPrint

Print the content of the journal in pretty xml format.

    rlJournalPrint [type]

=over

=item type

Can be either 'raw' or 'pretty', with the latter as a default.
Raw: xml is in raw form, no indentation etc
Pretty: xml is pretty printed, indented, with one record per line

=back

Example:

    <?xml version="1.0"?>
    <BEAKER_TEST>
      <test_id>debugging</test_id>
      <package>setup</package>
      <pkgdetails>setup-2.8.9-1.fc12.noarch</pkgdetails>
      <starttime>2010-02-08 15:17:47</starttime>
      <endtime>2010-02-08 15:17:47</endtime>
      <testname>/examples/beakerlib/Sanity/simple</testname>
      <release>Fedora release 12 (Constantine)</release>
      <hostname>localhost</hostname>
      <arch>i686</arch>
      <purpose>PURPOSE of /examples/beakerlib/Sanity/simple
        Description: Minimal BeakerLib sanity test
        Author: Petr Splichal &lt;psplicha@redhat.com&gt;

        This is a minimal sanity test for BeakerLib. It contains a single
        phase with a couple of asserts. We Just check that the "setup"
        package is installed and that there is a sane /etc/passwd file.
      </purpose>
      <log>
        <phase endtime="2010-02-08 15:17:47" name="Test" result="PASS"
                score="0" starttime="2010-02-08 15:17:47" type="FAIL">
          <test message="Checking for the presence of setup rpm">PASS</test>
          <test message="File /etc/passwd should exist">PASS</test>
          <test message="File '/etc/passwd' should contain 'root'">PASS</test>
        </phase>
      </log>
    </BEAKER_TEST>

=cut

# cat generated text version
rlJournalPrint(){
  __INTERNAL_JournalXMLCreate
  if [[ "$1" == "raw" ]]; then
    cat $__INTERNAL_BEAKERLIB_JOURNAL
  else
    cat $__INTERNAL_BEAKERLIB_JOURNAL | xmllint --format -
  fi
}

# backward compatibility
rlPrintJournal() {
    rlLogWarning "rlPrintJournal is obsoleted by rlJournalPrint"
    rlJournalPrint
}


__INTERNAL_update_journal_txt() {
  local textfile
  local endtime
  local IFS
  __INTERNAL_DURATION=$(($__INTERNAL_TIMESTAMP - $__INTERNAL_STARTTIME))
  __INTERNAL_format_time endtime "$__INTERNAL_TIMEFORMAT_LONG" "$__INTERNAL_TIMESTAMP"
  endtime="$endtime (still running)"
  [[ -n "$__INTERNAL_ENDTIME" ]] && __INTERNAL_format_time endtime "$__INTERNAL_TIMEFORMAT_LONG" "$__INTERNAL_ENDTIME"
  local sed_patterns="0,/    Test finished : /s/^(    Test finished : ).*\$/\1$endtime/;0,/    Test duration : /s/^(    Test duration : ).*\$/\1$__INTERNAL_DURATION seconds/"
  for textfile in "$__INTERNAL_BEAKERLIB_JOURNAL_COLORED" "$__INTERNAL_BEAKERLIB_JOURNAL_TXT"; do
    sed -r -i "$sed_patterns" "$textfile"
  done

}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlJournalPrintText
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlJournalPrintText

Print the content of the journal in pretty text format.

    rlJournalPrintText [--full-journal]

=over

=item --full-journal

The options is now deprecated, has no effect and will be removed in one
of future versions.

=back

Example:

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: TEST PROTOCOL
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   LOG    ] :: Test run ID   : debugging
    :: [   LOG    ] :: Package       : debugging
    :: [   LOG    ] :: Test started  : 2010-02-08 14:45:57
    :: [   LOG    ] :: Test finished : 2010-02-08 14:45:58
    :: [   LOG    ] :: Test name     :
    :: [   LOG    ] :: Distro:       : Fedora release 12 (Constantine)
    :: [   LOG    ] :: Hostname      : localhost
    :: [   LOG    ] :: Architecture  : i686

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Test description
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    PURPOSE of /examples/beakerlib/Sanity/simple
    Description: Minimal BeakerLib sanity test
    Author: Petr Splichal <psplicha@redhat.com>

    This is a minimal sanity test for BeakerLib. It contains a single
    phase with a couple of asserts. We Just check that the "setup"
    package is installed and that there is a sane /etc/passwd file.


    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Test
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   PASS   ] :: Checking for the presence of setup rpm
    :: [   PASS   ] :: File /etc/passwd should exist
    :: [   PASS   ] :: File '/etc/passwd' should contain 'root'
    :: [   LOG    ] :: Duration: 1s
    :: [   LOG    ] :: Assertions: 3 good, 0 bad
    :: [   PASS   ] :: RESULT: Test

=cut
# call rlJournalPrint
rlJournalPrintText(){
    __INTERNAL_PersistentDataLoad
    __INTERNAL_update_journal_txt

    echo -e "\n\n\n\n"
    local textfile
    [[ -t 1 ]] && textfile="$__INTERNAL_BEAKERLIB_JOURNAL_COLORED" || textfile="$__INTERNAL_BEAKERLIB_JOURNAL_TXT"
    cat "$textfile"

    return 0
}


# Creation of TestResults file
# Each line of the file contains TESTRESULT_VAR=$RESULT_VALUE
# so the file can be sourced afterwards
__INTERNAL_TestResultsSave(){
    # Set exit code of the test according to worst phase result
    case "$__INTERNAL_PHASES_WORST_RESULT" in
    PASS)
        __TESTRESULT_RESULT_ECODE="0"
        ;;
    WARN)
        __TESTRESULT_RESULT_ECODE="10"
        ;;
    FAIL)
        __TESTRESULT_RESULT_ECODE="20"
        ;;
    *)
        __TESTRESULT_RESULT_ECODE="30"
        ;;
    esac

    cat > "$__INTERNAL_TEST_RESULTS" <<EOF
# This is a result file of the test in a 'sourceable' form.
# Description of individual variables can be found in beakerlib man page.
TESTRESULT_RESULT_STRING=$__INTERNAL_PHASES_WORST_RESULT
TESTRESULT_RESULT_ECODE=$__TESTRESULT_RESULT_ECODE
TESTRESULT_PHASES_PASSED=$__INTERNAL_PHASES_PASSED
TESTRESULT_PHASES_FAILED=$__INTERNAL_PHASES_FAILED
TESTRESULT_PHASES_SKIPPED=$__INTERNAL_PHASES_SKIPPED
TESTRESULT_ASSERTS_FAILED=$__INTERNAL_TEST_STATE
TESTRESULT_STARTTIME=$__INTERNAL_STARTTIME
TESTRESULT_ENDTIME=$__INTERNAL_ENDTIME
TESTRESULT_DURATION=$__INTERNAL_DURATION
TESTRESULT_BEAKERLIB_DIR=$BEAKERLIB_DIR
EOF
}

# backward compatibility
rlCreateLogFromJournal(){
    rlLogWarning "rlCreateLogFromJournal is obsoleted by rlJournalPrintText"
    rlJournalPrintText
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetTestState
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlGetTestState

Returns number of failed asserts in so far, 255 if there are more then 255 failures.
The precise number is set to ECODE variable.

    rlGetTestState
=cut

rlGetTestState(){
    __INTERNAL_PersistentDataLoad
    ECODE=$__INTERNAL_TEST_STATE
    rlLogDebug "rlGetTestState: $ECODE failed assert(s) in test"
    [[ $ECODE -gt 255 ]] && return 255 || return $ECODE
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetPhaseState
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlGetPhaseState

Returns number of failed asserts in current phase so far, 255 if there are more then 255 failures.
The precise number is set to ECODE variable.

    rlGetPhaseState
=cut

rlGetPhaseState(){
    __INTERNAL_PersistentDataLoad
    ECODE=$__INTERNAL_PHASE_FAILED
    rlLogDebug "rlGetPhaseState: $ECODE failed assert(s) in phase"
    [[ $ECODE -gt 255 ]] && return 255 || return $ECODE
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal Stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rljAddPhase(){
    __INTERNAL_PersistentDataLoad
    local MSG=${2:-"Phase of $1 type"}
    local TXTLOG_START=$(cat $__INTERNAL_BEAKERLIB_JOURNAL_TXT | wc -l)
    rlLogDebug "$FUNCNAME(): $(set | grep ^__INTERNAL_BEAKERLIB_JOURNAL_TXT=)"
    rlLogDebug "$FUNCNAME(): $(set | grep ^TXTLOG_START=)"
    rlLogDebug "rljAddPhase: Phase $MSG started"
    __INTERNAL_WriteToMetafile phase --name "$MSG" --type "$1" >&2
    # Printing
    __INTERNAL_PrintHeadLog "$MSG"

    if [[ "$BEAKERLIB_NESTED_PHASES" == "0" ]]; then
      __INTERNAL_METAFILE_INDENT_LEVEL=2
      __INTERNAL_PHASE_TYPE=( "$1" )
      __INTERNAL_PHASE_NAME=( "$MSG" )
      __INTERNAL_PHASE_FAILED=( 0 )
      __INTERNAL_PHASE_PASSED=( 0 )
      __INTERNAL_PHASE_STARTTIME=( $__INTERNAL_TIMESTAMP )
      __INTERNAL_PHASE_TXTLOG_START=( $TXTLOG_START )
      __INTERNAL_PHASE_OPEN=${#__INTERNAL_PHASE_NAME[@]}
      __INTERNAL_PHASE_METRICS=( "" )
    else
      let __INTERNAL_METAFILE_INDENT_LEVEL++
      __INTERNAL_PHASE_TYPE=( "$1" "${__INTERNAL_PHASE_TYPE[@]}" )
      __INTERNAL_PHASE_NAME=( "$MSG" "${__INTERNAL_PHASE_NAME[@]}" )
      __INTERNAL_PHASE_FAILED=( 0 "${__INTERNAL_PHASE_FAILED[@]}" )
      __INTERNAL_PHASE_PASSED=( 0 "${__INTERNAL_PHASE_PASSED[@]}" )
      __INTERNAL_PHASE_STARTTIME=( $__INTERNAL_TIMESTAMP "${__INTERNAL_PHASE_STARTTIME[@]}" )
      __INTERNAL_PHASE_TXTLOG_START=( $TXTLOG_START "${__INTERNAL_PHASE_TXTLOG_START[@]}" )
      __INTERNAL_PHASE_OPEN=${#__INTERNAL_PHASE_NAME[@]}
      __INTERNAL_PHASE_METRICS=( "" "${__INTERNAL_PHASE_METRICS[@]}" )
    fi
    __INTERNAL_PersistentDataSave
}

__INTERNAL_SET_WORST_PHASE_RESULT() {
    local results='PASS WARN FAIL'
    [[ "$results" =~ $(echo "$__INTERNAL_PHASES_WORST_RESULT(.*)") ]] && {
      local possible_results="${BASH_REMATCH[1]}"
      rlLogDebug "$FUNCNAME(): possible worse results are now $possible_results, current result is $1"
      [[ "$possible_results" =~ $1 ]] && {
          rlLogDebug "$FUNCNAME(): changing worst phase result from $__INTERNAL_PHASES_WORST_RESULT to $1"
          __INTERNAL_PHASES_WORST_RESULT="$1"
      }
    }
}

rljClosePhase(){
    __INTERNAL_PersistentDataLoad
    [[ $__INTERNAL_PHASE_OPEN -eq 0 ]] && {
      rlLogError "nothing to close - no open phase"
      return 1
    }
    local result

    local score=$__INTERNAL_PHASE_FAILED
    # Result
    if [ $score -eq 0 ]; then
        result="PASS"
        let __INTERNAL_PHASES_PASSED++
    else
        result="$__INTERNAL_PHASE_TYPE"
        let __INTERNAL_PHASES_FAILED++
    fi

    __INTERNAL_SET_WORST_PHASE_RESULT "$result"

    local name="$__INTERNAL_PHASE_NAME"

    rlLogDebug "rljClosePhase: Phase $name closed"
    __INTERNAL_SET_TIMESTAMP
    local endtime="$__INTERNAL_TIMESTAMP"
    __INTERNAL_PrintFootLog $__INTERNAL_PHASE_STARTTIME \
                            $endtime \
                            Assertions \
                            $__INTERNAL_PHASE_PASSED \
                            $__INTERNAL_PHASE_FAILED \
                            "$result" \
                            '' \
                            "($name)"
    local logfile="$(mktemp)"
    tail -n +$((__INTERNAL_PHASE_TXTLOG_START+1)) $__INTERNAL_BEAKERLIB_JOURNAL_TXT > $logfile
    rlReport "$(echo "${name//[^[:alnum:]]/-}" | tr -s '-')" "$result" "$score" "$logfile"
    rm -f $logfile

    # Reset of state variables
    if [[ "$BEAKERLIB_NESTED_PHASES" == "0" ]]; then
      __INTERNAL_METAFILE_INDENT_LEVEL=1
      __INTERNAL_PHASE_TYPE=()
      __INTERNAL_PHASE_NAME=()
      __INTERNAL_PHASE_FAILED=()
      __INTERNAL_PHASE_PASSED=()
      __INTERNAL_PHASE_STARTTIME=()
      __INTERNAL_PHASE_TXTLOG_START=()
      __INTERNAL_PHASE_METRICS=()
    else
      let __INTERNAL_METAFILE_INDENT_LEVEL--
      unset __INTERNAL_PHASE_TYPE[0]; __INTERNAL_PHASE_TYPE=( "${__INTERNAL_PHASE_TYPE[@]}" )
      unset __INTERNAL_PHASE_NAME[0]; __INTERNAL_PHASE_NAME=( "${__INTERNAL_PHASE_NAME[@]}" )
      [[ ${#__INTERNAL_PHASE_FAILED[@]} -gt 1 ]] && let __INTERNAL_PHASE_FAILED[1]+=__INTERNAL_PHASE_FAILED[0]
      unset __INTERNAL_PHASE_FAILED[0]; __INTERNAL_PHASE_FAILED=( "${__INTERNAL_PHASE_FAILED[@]}" )
      [[ ${#__INTERNAL_PHASE_PASSED[@]} -gt 1 ]] && let __INTERNAL_PHASE_PASSED[1]+=__INTERNAL_PHASE_PASSED[0]
      unset __INTERNAL_PHASE_PASSED[0]; __INTERNAL_PHASE_PASSED=( "${__INTERNAL_PHASE_PASSED[@]}" )
      unset __INTERNAL_PHASE_STARTTIME[0]; __INTERNAL_PHASE_STARTTIME=( "${__INTERNAL_PHASE_STARTTIME[@]}" )
      unset __INTERNAL_PHASE_TXTLOG_START[0]; __INTERNAL_PHASE_TXTLOG_START=( "${__INTERNAL_PHASE_TXTLOG_START[@]}" )
      unset __INTERNAL_PHASE_METRICS[0]; __INTERNAL_PHASE_METRICS=( "${__INTERNAL_PHASE_METRICS[@]}" )
    fi
    rlLogDebug "$FUNCNAME(): $(set | grep ^__INTERNAL_PHASE_)"
    __INTERNAL_PHASE_OPEN=${#__INTERNAL_PHASE_NAME[@]}
    # Updating phase element
    __INTERNAL_WriteToMetafile --result "$result" --score "$score"
    __INTERNAL_PersistentDataSave
}

# $1 message
# $2 result
# $3 command
rljAddTest(){
    local IFS
    __INTERNAL_PersistentDataLoad
    if [ $__INTERNAL_PHASE_OPEN -eq 0 ]; then
        rlPhaseStart "FAIL" "Asserts collected outside of a phase"
        rlFail "TEST BUG: Assertion not in phase"
        rljAddTest "$@"
        rlPhaseEnd
    else
        __INTERNAL_LogText "$1" "$2"
        __INTERNAL_WriteToMetafile test --message "$1" ${3:+--command "$3"} -- "$2" >&2
        if [ "$2" == "PASS" ]; then
            let __INTERNAL_PHASE_PASSED++
        else
            let __INTERNAL_TEST_STATE++
            let __INTERNAL_PHASE_FAILED++
        fi
    fi
    __INTERNAL_PersistentDataSave
}

rljAddMetric(){
    __INTERNAL_PersistentDataLoad
    local MID="$2"
    local VALUE="$3"
    local TOLERANCE=${4:-"0.2"}
    local res=0
    if [ "$MID" == "" ] || [ "$VALUE" == "" ]
    then
        rlLogError "TEST BUG: Bad call of rlLogMetric"
        return 1
    fi
    if [[ "$__INTERNAL_PHASE_METRICS" =~ \ $MID\  ]]; then
        rlLogError "$FUNCNAME: Metric name not unique!"
        let res++
    else
        rlLogDebug "rljAddMetric: Storing metric $MID with value $VALUE and tolerance $TOLERANCE"
        __INTERNAL_PHASE_METRICS="$__INTERNAL_PHASE_METRICS $MID "
        __INTERNAL_WriteToMetafile metric --type "$1" --name "$MID" \
            --value "$VALUE" --tolerance "$TOLERANCE" >&2 || let res++
        __INTERNAL_PersistentDataSave
    fi
    return $?
}

rljAddMessage(){
    __INTERNAL_WriteToMetafile message --severity "$2" -- "$1" >&2
}

__INTERNAL_GetPackageDetails() {
    rpm -q "$1" --qf "%{name}-%{version}-%{release}.%{arch} %{sourcerpm}"
}

rljRpmLog(){
    local package_details
    if package_details=( $(__INTERNAL_GetPackageDetails "$1") ); then
        __INTERNAL_WriteToMetafile pkgdetails --sourcerpm "${package_details[1]}" -- "${package_details[0]}"
    else
        __INTERNAL_WriteToMetafile pkgnotinstalled -- "$1"
    fi
}

# determine SUT package
__INTERNAL_DeterminePackage(){
    local package
    if [[ -z "$TEST" ]]; then
        if [[ -z "$PACKAGE" ]]; then
            if [[ -z "$PACKAGES" ]]; then
                package="unknown"
            else
                package="$PACKAGES"
            fi
        else
            package="$PACKAGE"
        fi
    elif [[ -n "$TESTPACKAGE" ]]; then
        package="$TESTPACKAGE"
    else
        local arrPac=(${TEST//// })
        package=${arrPac[1]}
    fi
    echo "$package"
    return 0
}

# Creates header
__INTERNAL_CreateHeader(){
    local IFS

    __INTERNAL_PrintHeadLog "TEST PROTOCOL" 2> /dev/null

    [[ -n "$TESTID" ]] && {
        __INTERNAL_WriteToMetafile test_id -- "$TESTID"
        __INTERNAL_LogText "    Test run ID   : $TESTID" 2> /dev/null
    }

    # Determine package which is tested
    local package=$(__INTERNAL_DeterminePackage)
    local arrPac=(${package// / })
    __INTERNAL_WriteToMetafile package -- "$package"
    __INTERNAL_LogText "    Package       : $package" 2> /dev/null

    # Write package details (rpm, srcrpm) into metafile
    rljRpmLog "${arrPac[0]}"
    package=( $(__INTERNAL_GetPackageDetails "${arrPac[0]}") ) && \
        __INTERNAL_LogText "    Installed     : ${package[0]}" 2> /dev/null

    # RPM version of beakerlib
    package=( $(__INTERNAL_GetPackageDetails "beakerlib") ) && {
        __INTERNAL_WriteToMetafile beakerlib_rpm -- "${package[0]}"
        __INTERNAL_LogText "    beakerlib RPM : ${package[0]}" 2> /dev/null
    }

    # RPM version of beakerlib-redhat
    package=( $(__INTERNAL_GetPackageDetails "beakerlib-redhat") ) && {
        __INTERNAL_WriteToMetafile beakerlib_redhat_rpm -- "${package[0]}"
        __INTERNAL_LogText "    bl-redhat RPM : ${package[0]}" 2> /dev/null
    }

    # Test name
    __INTERNAL_TEST_NAME="${TEST:-unknown}"
    [[ "$__INTERNAL_TEST_NAME" == "unknown" && -e $BEAKERLIB_DIR/metadata.yaml ]] && {
      local yaml
      declare -A yaml
      rlYash_parse yaml "$(cat $BEAKERLIB_DIR/metadata.yaml)"
      __INTERNAL_TEST_NAME="${yaml[name]}"
    }
    __INTERNAL_WriteToMetafile testname -- "${__INTERNAL_TEST_NAME}"
    __INTERNAL_LogText "    Test name     : ${__INTERNAL_TEST_NAME}" 2> /dev/null

    local test_version="${testversion:-$TESTVERSION}"
    local test_rpm
    # get number of items of BASH_SOURCE-1 to get last item of the array
    test_rpm=$(rpm -qf ${BASH_SOURCE[$((${#BASH_SOURCE[@]}-1))]} 2> /dev/null) \
      && test_version=$(rpm --qf "%{version}-%{release}" -q $test_rpm 2> /dev/null)

    [[ -n "$test_version" ]] && {
        __INTERNAL_WriteToMetafile testversion -- "$test_version"
        __INTERNAL_LogText "    Test version  : $test_version" 2> /dev/null
    }

    package="${packagename:-$test_rpm}"
    local test_built
    [[ -n "$package" ]] && test_built=$(rpm -q --qf '%{BUILDTIME}\n' $package 2> /dev/null) && {
      test_built="$(echo "$test_built" | head -n 1 )"
      __INTERNAL_format_time test_built "$__INTERNAL_TIMEFORMAT_LONG" "$test_built"
      __INTERNAL_WriteToMetafile testversion -- "$test_built"
      __INTERNAL_LogText "    Test built    : $test_built" 2> /dev/null
    }


    # Starttime and endtime
    __INTERNAL_WriteToMetafile starttime
    __INTERNAL_WriteToMetafile endtime
    local starttime
    __INTERNAL_format_time starttime "$__INTERNAL_TIMEFORMAT_LONG" $__INTERNAL_STARTTIME
    __INTERNAL_LogText "    Test started  : $starttime" 2> /dev/null
    __INTERNAL_LogText "    Test finished : " 2> /dev/null
    __INTERNAL_LogText "    Test duration : " 2> /dev/null

    # OS release
    local release=$(cat /etc/redhat-release)
    [[ -n "$release" ]] && {
        __INTERNAL_WriteToMetafile release -- "$release"
        __INTERNAL_LogText "    Distro        : ${release}" 2> /dev/null
    }

    # Hostname
    local hostname=""
    # Try hostname command or /etc/hostname if both fail skip it
    if which hostname &> /dev/null; then
        hostname=$(hostname --fqdn)
    elif [[ -f "/etc/hostname" ]]; then
        hostname=$(cat /etc/hostname)
    fi

    [[ -n "$hostname" ]] && {
        __INTERNAL_WriteToMetafile hostname -- "$hostname"
        __INTERNAL_LogText "    Hostname      : ${hostname}" 2> /dev/null
    }

    # Architecture
    local arch=$(uname -i 2>/dev/null || uname -m)
    [[ -n "$arch" ]] && {
        __INTERNAL_WriteToMetafile arch -- "$arch"
        __INTERNAL_LogText "    Architecture  : ${arch}" 2> /dev/null
    }

    local line size
    # CPU info
    if [ -f "/proc/cpuinfo" ]; then
        local cpu_regex count type
        cpu_regex="^model\sname.*: (.*)$"
        count=$(grep -cE "$cpu_regex" /proc/cpuinfo)
        type="$(grep -E -m 1 "$cpu_regex" /proc/cpuinfo | sed -r "s/$cpu_regex/\1/")"
        __INTERNAL_WriteToMetafile hw_cpu -- "$count x $type"
        __INTERNAL_LogText "    CPUs          : $count x $type" 2> /dev/null
    fi

    # RAM size
     if [[ -f "/proc/meminfo" ]]; then
        size=0
        local ram_regex="^MemTotal: *(.*) kB$"
        while read -r line; do
            if [[ "$line" =~ $ram_regex ]]; then
                size=`expr ${BASH_REMATCH[1]} / 1024`
                break
            fi
        done < "/proc/meminfo"
        __INTERNAL_WriteToMetafile hw_ram -- "$size MB"
        __INTERNAL_LogText "    RAM size      : ${size} MB" 2> /dev/null
    fi

    # HDD size
    size=0
    local hdd_regex="^(/[^ ]+) +([0-9]+) +[0-9]+ +[0-9]+ +[0-9]+% +[^ ]+$"
    while read -r line ; do
        if [[ "$line" =~ $hdd_regex ]]; then
            let size+=BASH_REMATCH[2]
        fi
    done < <(df -k -P --local --exclude-type=tmpfs)
    [[ -n "$size" ]] && {
        size="$(echo "$((size*100/1024/1024))" | sed -r 's/..$/.\0/') GB"
        __INTERNAL_WriteToMetafile hw_hdd -- "$size"
        __INTERNAL_LogText "    HDD size      : ${size}" 2> /dev/null
    }

    # Purpose
    [[ -f 'PURPOSE' ]] && {
        local purpose tmp
        purpose="$(cat PURPOSE)"$'\n'
        __INTERNAL_WriteToMetafile purpose -- "$purpose"
        __INTERNAL_PrintHeadLog "Test description" 2> /dev/null
        __INTERNAL_LogText "$purpose" 2> /dev/null
    }

    return 0
}


__INTERNAL_SET_TIMESTAMP() {
    __INTERNAL_format_time __INTERNAL_TIMESTAMP "%s" "-1"
}


# Encode arguments' values into base64
# Adds --timestamp argument and indent
# writes it into metafile
# takes [element] --attribute1 value1 --attribute2 value2 .. [-- "content"]
__INTERNAL_WriteToMetafile(){
    __INTERNAL_SET_TIMESTAMP
    local indent
    local line=""
    local lineraw=''
    local ARGS=("$@")
    local element=''

    [[ "${1:0:2}" != "--" ]] && {
      local element="$1"
      shift
    }
    local arg
    while [[ $# -gt 0 ]]; do
      case $1 in
      --)
        line+=" -- $(echo -n "$2" | base64 -w 0)"
        printf -v lineraw "%s -- %q" "$lineraw" "$2"
        shift 2
        break
        ;;
      --*)
        line+=" $1=$(echo -n "$2" | base64 -w 0)"
        printf -v lineraw "%s %s=%q" "$lineraw" "$1" "$2"
        shift
        ;;
      *)
        __INTERNAL_LogText "unexpected meta input format"
        set | grep ^ARGS=
        exit 124
        ;;
      esac
      shift
    done
    [[ $# -gt 0 ]] && {
      __INTERNAL_LogText "unexpected meta input format"
      set | grep ^ARGS=
      exit 125
    }

    printf -v indent '%*s' $__INTERNAL_METAFILE_INDENT_LEVEL

    line="$indent${element:+$element }--timestamp=${__INTERNAL_TIMESTAMP}$line"
    lineraw="$indent${element:+$element }--timestamp=${__INTERNAL_TIMESTAMP}$lineraw"
    [[ -n "$DEBUG" ]] && echo "#${lineraw:1}" >> $__INTERNAL_BEAKERLIB_METAFILE
    echo "$line" >> $__INTERNAL_BEAKERLIB_METAFILE
}

__INTERNAL_PrintHeadLog() {
    __INTERNAL_LogText "\n::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    __INTERNAL_LogText "::   $1"
    __INTERNAL_LogText "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
}


# $1 - start time
# $2 - end time
# $3 - stat name
# $4 - stat good
# $5 - stat bad
# $6 - result
# $7 - result prefix '<PREFIX> RESULT: <RESULT>'
# $8 - result suffix 'RESULT: <RESULT> <SUFFIX>'
__INTERNAL_PrintFootLog(){
  local result_colored
  local starttime="$1"
  local endtime="$2"
  local stat_name="$3"
  local stat_good="$4"
  local stat_bad="$5"
  local result="$6"
  local result_pref="${7:+"$7 "}"
  local result_suff="${8:+" $8"}"
  __INTERNAL_colorize_prio "$result" result_colored
  __INTERNAL_LogText "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
  __INTERNAL_LogText "::   Duration: $((endtime - starttime))s"
  __INTERNAL_LogText "::   $stat_name: $stat_good good, $stat_bad bad"
  __INTERNAL_LogText "::   ${result_pref}RESULT: ${result}${result_suff}" '' '' \
                     "::   ${result_pref}RESULT: ${result_colored}${result_suff}"
  __INTERNAL_LogText ''
}


# whenever any of the persistent variable is touched,
# functions __INTERNAL_PersistentDataLoad and __INTERNAL_PersistentDataSave
# should be called before and after that respectively.

__INTERNAL_PersistentDataSave_sed='s/^declare/\0 -g/'
# ugly workaround for bash-4.1.2 and older, where -g does not exist
# there might be an issue when there's a line break in the variables and there's
# "")'" or "()'" at the end of the line. This should not never happen, the worst
# case might happen in the phase name but is is not expected to contain line
# breaks
declare -g &> /dev/null || __INTERNAL_PersistentDataSave_sed="s/^declare\s+-a\s+/eval /;s/^declare\s+\S+\s+//"

__INTERNAL_PersistentDataSave() {
  declare -p \
    __INTERNAL_STARTTIME \
    __INTERNAL_TEST_STATE \
    __INTERNAL_PHASES_PASSED \
    __INTERNAL_PHASES_FAILED \
    __INTERNAL_PHASES_SKIPPED \
    __INTERNAL_JOURNAL_OPEN \
    __INTERNAL_PHASE_OPEN \
    __INTERNAL_PHASES_WORST_RESULT \
    __INTERNAL_METAFILE_INDENT_LEVEL \
    __INTERNAL_PHASE_TYPE \
    __INTERNAL_PHASE_NAME \
    __INTERNAL_PHASE_FAILED \
    __INTERNAL_PHASE_PASSED \
    __INTERNAL_PHASE_STARTTIME \
    __INTERNAL_PHASE_TXTLOG_START \
    __INTERNAL_PHASE_METRICS \
    __INTERNAL_TEST_NAME \
    | sed -r "$__INTERNAL_PersistentDataSave_sed" > "$__INTERNAL_PERSISTENT_DATA"
}

__INTERNAL_PersistentDataLoad() {
  [[ -r "$__INTERNAL_PERSISTENT_DATA" ]] && . "$__INTERNAL_PERSISTENT_DATA"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Petr Muller <pmuller@redhat.com>

=item *

Jan Hutar <jhutar@redhat.com>

=item *

Ales Zelinka <azelinka@redhat.com>

=item *

Petr Splichal <psplicha@redhat.com>

=item *

Dalibor Pospisil <dapospis@redhat.com>

=item *

Jakub Heger <jheger@redhat.com>

=back

=cut
