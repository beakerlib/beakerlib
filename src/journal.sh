# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: journalling.sh - part of the BeakerLib project
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

# Initialization of variables holding current state of the test
INDENT_LEVEL=0
PHASE_OPENED=0
PHASES_FAILED=0
TESTS_FAILED=0
CURRENT_PHASE_TESTS_FAILED=0  # TODO remember to reset it when closing
CURRENT_PHASE_TYPE=""
CURRENT_PHASE_NAME=""

rlJournalStart(){
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

    [ -d "$BEAKERLIB_DIR" ] || mkdir -p "$BEAKERLIB_DIR"

    # set global BeakerLib journal and queue file variable for future use
    export BEAKERLIB_JOURNAL="$BEAKERLIB_DIR/journal.xml"
    export BEAKERLIB_METAFILE="$BEAKERLIB_DIR/journal.meta"

    # creating queue file
    touch $BEAKERLIB_METAFILE

    # make sure the directory is ready, otherwise we cannot continue
    if [ ! -d "$BEAKERLIB_DIR" ] ; then
        echo "rlJournalStart: Failed to create $BEAKERLIB_DIR directory."
        echo "rlJournalStart: Cannot continue, exiting..."
        exit 1
    fi

    # finally initialize the journal # SMAZAT ?
#    if $__INTERNAL_JOURNALIST init --test "$TEST" >&2; then
#        rlLogDebug "rlJournalStart: Journal successfully initilized in $BEAKERLIB_DIR"
#    else
#        echo "rlJournalStart: Failed to initialize the journal. Bailing out..."
#        exit 1
#    fi

    # Create Header for XML journal
    rljCreateHeader
    # Create log element for XML journal
    rljWriteToMetafile log
    # Increase level of indent
    let "INDENT_LEVEL=INDENT_LEVEL+1"

    # display a warning message if run in POSIX mode
    if [ $POSIXFIXED == "YES" ] ; then
        rlLogWarning "POSIX mode detected and switched off"
        rlLogWarning "Please fix your test to have /bin/bash shebang"
    fi

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
}

# backward compatibility
rlStartJournal() {
    rlJournalStart
    rlLogWarning "rlStartJournal is obsoleted by rlJournalStart"
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
    local journal="$BEAKERLIB_JOURNAL"
    local journaltext="$BEAKERLIB_DIR/journal.txt"
    #rlJournalPrintText > $journaltext # TODO_IMP implement creation of journal.txt
    journaltext=""  # TODO_IMP SMAZAT

    if [ -z "$BEAKERLIB_COMMAND_SUBMIT_LOG" ]
    then
      local BEAKERLIB_COMMAND_SUBMIT_LOG="$__INTERNAL_DEFAULT_SUBMIT_LOG"
    fi

    if [ -n "$TESTID" ] ; then
        $BEAKERLIB_COMMAND_SUBMIT_LOG -T $TESTID -l $journal \
        || rlLogError "rlJournalEnd: Submit wasn't successful"
    else
        rlLog "JOURNAL XML: $journal"
        rlLog "JOURNAL TXT: $journaltext"
    fi

    echo "#End of metafile" >> $BEAKERLIB_METAFILE
    $__INTERNAL_JOURNALIST --metafile "$BEAKERLIB_METAFILE"

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

# TODO_IMP implement with metafile solution
rlJournalPrint(){
    local TYPE=${1:-"pretty"}
    $__INTERNAL_JOURNALIST dump --type "$TYPE"
}

# TODO_IMP implement with metafile solution
# backward compatibility
rlPrintJournal() {
    rlLogWarning "rlPrintJournal is obsoleted by rlJournalPrint"
    rlJournalPrint
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

With this option, additional items like some HW information
will be printed in the journal.

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
# TODO_IMP implement with metafile solution
rlJournalPrintText(){
    local SEVERITY=${LOG_LEVEL:-"INFO"}
    local FULL_JOURNAL=''
    [ "$1" == '--full-journal' ] && FULL_JOURNAL='--full-journal'
    [ "$DEBUG" == 'true' -o "$DEBUG" == '1' ] && SEVERITY="DEBUG"
    #$__INTERNAL_JOURNALIST printlog --severity $SEVERITY $FULL_JOURNAL
}

# TODO_IMP implement with metafile solution
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

    rlGetTestState
=cut

rlGetTestState(){
    #$__INTERNAL_JOURNALIST teststate >&2
    # TODO_IMP implement overflow for all counters (maybe increment/decrement function?)
    ECODE="$TESTS_FAILED"
    rlLogDebug "rlGetTestState: $ECODE failed assert(s) in test"
    return $ECODE
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetPhaseState
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlGetPhaseState

Returns number of failed asserts in current phase so far, 255 if there are more then 255 failures.

    rlGetPhaseState
=cut

rlGetPhaseState(){
    #$__INTERNAL_JOURNALIST phasestate >&2
    #ECODE=$?
    ECODE="$CURRENT_PHASE_TESTS_FAILED"
    rlLogDebug "rlGetPhaseState: $ECODE failed assert(s) in phase"
    return $ECODE
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal Stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rljAddPhase(){
    local MSG=${2:-"Phase of $1 type"}
    rlLogDebug "rljAddPhase: Phase $MSG started"
    rljWriteToMetafile phase --name="$MSG" --type="$1" >&2

    # MEETING Can't PHASE_OPENED be deduced from INDENT_LEVEL? Or will there be other elements increasing indent?
    # MEETING For nested phases to work CURRENT_PHASE_TYPE/NAME has to be implemented as stacks, other than that
    # MEETING ...it seems beakerlib is ready, don't know about Beaker though.
    let "PHASE_OPENED=PHASE_OPENED+1"
    let "INDENT_LEVEL=INDENT_LEVEL+1"
    CURRENT_PHASE_TYPE="$1"
    CURRENT_PHASE_NAME="$MSG"

    # TODO probably runs again pointlessly, it should be enough to have it run in header-creation and save it into global
    package=$(rljDeterminePackage)
    # MEETING Anyway, is this needed at all? Why does every phase have pkgdetails again when it is in the header?
    # Write package details (rpm, srcrpm) into metafile
    rljGetPackageDetails $package
}

rljClosePhase(){
    local logfile="$BEAKERLIB_DIR/journal.txt"

    local score="$CURRENT_PHASE_TESTS_FAILED"
    # Result
    if [ "$CURRENT_PHASE_TESTS_FAILED" -eq 0 ]; then
        result="PASS"
    else
        result="$CURRENT_PHASE_TYPE"
        let "PHASES_FAILED=PHASES_FAILED+1"
    fi

    local name="$CURRENT_PHASE_NAME"

    rlLogDebug "rljClosePhase: Phase $name closed"
    #rlJournalPrintText > $logfile
    logfile=""  # TODO_IMP implement creation of logfile!
    rlReport "$name" "$result" "$score" "$logfile"

    # Reset of state variables
    let "PHASE_OPENED=PHASE_OPENED-1"
    let "INDENT_LEVEL=INDENT_LEVEL-1"
    CURRENT_PHASE_TYPE=""
    CURRENT_PHASE_NAME=""
    CURRENT_PHASE_TESTS_FAILED=0
    # Updating phase element
    rljWriteToMetafile --result="$result" --score="$score"
}

rljAddTest(){
    if [ "$PHASE_OPENED" -eq 0 ]; then
        rljAddPhase "FAIL" "Asserts collected outside of a phase"
        rljWriteToMetafile test --message="TEST BUG: Assertion not in phase" -- "FAIL" >&2
        rljWriteToMetafile test --message="$1" -- "$2" >&2
        rljClosePhase
        # MEETING check logic of adding failed test to both current phase and overall counter
        let "TESTS_FAILED=TESTS_FAILED+1"
        let "CURRENT_PHASE_TESTS_FAILED=CURRENT_PHASE_TESTS_FAILED+1"
    else
        #echo "DEBUG: $1 $2 $3"  # SMAZAT
        rljWriteToMetafile test --message="$1" -- "$2" ${3:+--command="$3"} >&2
        if [ "$2" != "PASS" ]; then
            let "TESTS_FAILED=TESTS_FAILED+1"
            let "CURRENT_PHASE_TESTS_FAILED=CURRENT_PHASE_TESTS_FAILED+1"
        fi
    fi
}

rljAddMetric(){
    local MID="$2"
    local VALUE="$3"
    local TOLERANCE=${4:-"0.2"}
    if [ "$MID" == "" ] || [ "$VALUE" == "" ]
    then
        rlLogError "TEST BUG: Bad call of rlLogMetric"
        return 1
    fi
    rlLogDebug "rljAddMetric: Storing metric $MID with value $VALUE and tolerance $TOLERANCE"
    rljWriteToMetafile metric --type="$1" --name="$MID" \
        --value="$VALUE" --tolerance="$TOLERANCE" >&2
    return $?
}

rljAddMessage(){
    rljWriteToMetafile message --message="$1" --severity="$2" >&2
}

rljRpmLog(){
    rljWriteToMetafile rpm --package="$1" >&2
}


# TODO comment
rljGetRPM() {
    echo $(rpm -q $1)
    [ $? -ne 0 ] && return 1
    return 0
}

# TODO comment
rljGetSRCRPM() {
    echo $(rpm -q $1 --qf '%{SOURCERPM}')
    [ $? -ne 0 ] && return 1
    return 0
}

# TODO comment
rljGetPackageDetails(){
    # RPM and SRCRPM version of the package
    if [ "$1" != "unknown" ]; then
        rpm=$(rljGetRPM $1)
        if [ $? -ne 0 ]; then
            rljWriteToMetafile pkgnotinstalled -- "$1"
        else
            srcrpm=$(rljGetSRCRPM $1)
            rljWriteToMetafile pkgdetails --sourcerpm="$srcrpm" -- "$rpm"
        fi
    fi
    return 0
}

# TODO comment
rljDeterminePackage(){
    if [ "$PACKAGE" == "" ]; then
        if [ "$TEST" == "" ]; then
            package="unknown"
        else
            arrPac=(${TEST//// })
            package=${arrPac[1]}
        fi
    else
        package="$PACKAGE"
    fi
    echo "$package"
    return 0
}

# MEETING check logic of individual operations
# Creates header
rljCreateHeader(){

    # Determine package which is tested
    package=$(rljDeterminePackage)
    rljWriteToMetafile package -- "$package"

    # Write package details (rpm, srcrpm) into metafile
    rljGetPackageDetails $package

    # RPM version of beakerlib
    beakerlib_rpm=$(rljGetRPM beakerlib)
    [ $? -eq 0 ] && rljWriteToMetafile beakerlib_rpm -- "$beakerlib_rpm"

    # RPM version of beakerlib-redhat
    beakerlib_redhat_rpm=$(rljGetRPM beakerlib-redhat)
    [ $? -eq 0 ] && rljWriteToMetafile beakerlib_redhat_rpm -- "$beakerlib_redhat_rpm"


    # Starttime and endtime
    rljWriteToMetafile starttime
    rljWriteToMetafile endtime

    # Test name
    [ "$TEST" == ""  ] && TEST="unknown"
    rljWriteToMetafile testname -- "$TEST"

    # OS release
    release=$(cat /etc/redhat-release)
    [ "$release" != "" ] && rljWriteToMetafile release -- "$release"

    # Hostname # MEETING is there a better way?
    hostname=$(python -c 'import socket; print(socket.getfqdn())')
    [ "$hostname" != "" ] && rljWriteToMetafile hostname -- "$hostname"

    # Architecture # MEETING is it the correct way?
    arch=$(arch)
    [ "$arch" != "" ] && rljWriteToMetafile arch -- "$arch"

    # CPU info
    if [ -f "/proc/cpuinfo" ]; then
        count=0
        type=""
        cpu_regex="^model\sname.*: (.*)$"
        while read line; do
            if [[ "$line" =~ $cpu_regex ]]; then    # MEETING bash construct, is it ok?
                type="${BASH_REMATCH[1]}"
                let "count=count+1"
            fi
        done < "/proc/cpuinfo"
        rljWriteToMetafile hw_cpu -- "$count x $type"
    fi

    # RAM size
     if [ -f "/proc/meminfo" ]; then
        size=0
        ram_regex="^MemTotal: *(.*) kB$"
        while read line; do
            if [[ "$line" =~ $ram_regex ]]; then   # MEETING bash construct, is it ok?
                size=`expr ${BASH_REMATCH[1]} / 1024`
                break
            fi
        done < "/proc/meminfo"
        rljWriteToMetafile hw_ram -- "$size MB"
    fi

    # HDD size
    size=0
    hdd_regex="^(/[^ ]+) +([0-9]+) +[0-9]+ +[0-9]+ +[0-9]+% +[^ ]+$"
    while read -r line ; do
        if [[ "$line" =~ $hdd_regex ]]; then   # MEETING bash construct, is it ok?
            let "size=size+${BASH_REMATCH[2]}"
         fi
    done < <(df -k -P --local --exclude-type=tmpfs)
    [ "$size" -ne 0 ] && rljWriteToMetafile hw_hdd -- "$(echo "scale=2;$size/1024/1024" | bc) GB"

    # Purpose
    purpose=""
    [ -f 'PURPOSE' ] && purpose=$(cat PURPOSE)
    rljWriteToMetafile purpose -- "$purpose"

    return 0
}


# Encode arguments' values into base64
# Adds --timestamp argument and indent
# writes it into metafile
rljWriteToMetafile(){
    CONTENT_FLAG=0
    attr_regex="^--[a-zA-Z0-9]+="
    content_regex="^--$"
    line=""

    for arg in "$@"; do
        if [ $CONTENT_FLAG -eq 1 ]; then
            based=$(echo -n $arg | base64 -w 0)
            line="$line\"$based\" "
            CONTENT_FLAG=0
            continue
        elif [[ "$arg" =~ $content_regex ]]; then
            CONTENT_FLAG=1
            line="$line$arg "
            continue
        elif [[ "$arg" =~ $attr_regex ]]; then
            arrArg=(${arg//=/ })
            based=$(echo -n "${arrArg[@]: 1}" | base64 -w 0)  # TODO check if working in older versions of bash
            based="${arrArg[0]}=\"$based\""
            line="$line$based "
        else
            line="$line$arg "
        fi
    done

    if [ $INDENT_LEVEL -eq 0 ]; then
        indent=""
    else
        indent=$(printf '%0.s ' $(seq 1 $INDENT_LEVEL))
    fi

    timestamp=$(date +%s)
    line="$indent$line--timestamp=\"$timestamp\""
    #line="$indent$line"
    echo "$line" >> $BEAKERLIB_METAFILE
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

=back

=cut
