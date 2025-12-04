echo "${__INTERNAL_SOURCED}" | grep -qF -- " ${BASH_SOURCE} " && return || __INTERNAL_SOURCED+=" ${BASH_SOURCE} "
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: testing.sh - part of the BeakerLib project
#   Description: Asserting functions, watchdog and report
#
#   Author: Ondrej Hudlicky <ohudlick@redhat.com>
#   Author: Petr Muller <pmuller@redhat.com>
#   Author: Jan Hutar <jhutar@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#   Author: Ales Zelinka <azelinka@redhat.com>
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

export __INTERNAL_DEFAULT_REPORT_RESULT=/bin/true

: <<'=cut'
=pod

=head1 NAME

BeakerLib - testing - asserting functions, watchdog and report

=head1 DESCRIPTION

This file contains functions related directly to testing. These functions are
various asserts affecting final result of the phase. Watchdog and the report
result function is included as well.

=head1 FUNCTIONS

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Internal Stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. $BEAKERLIB/logging.sh
. $BEAKERLIB/journal.sh

__INTERNAL_LogAndJournalPass() {
    rljAddTest "$1 $2" "PASS" "$3"
}

__INTERNAL_LogAndJournalFail() {
    rljAddTest "$1 $2" "FAIL" "$3"
}

# __INTERNAL_ConditionalAssert comment status [failed-comment] [executed command-line]
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

__INTERNAL_ConditionalAssert() {
    if [ "$2" == "0" ]; then
        __INTERNAL_LogAndJournalPass "$1" "$3" "$4"
        return 0
    else
        __INTERNAL_LogAndJournalFail "$1" "$3" "$4"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlPass
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Manual Asserts

=head3 rlPass

Manual assertion, asserts and logs PASS.

    rlPass comment

=over

=item comment

Short test summary.

=back

Returns 0 and asserts PASS.

=cut

rlPass() {
    __INTERNAL_LogAndJournalPass "$1"
    return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlFail
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlFail

Manual assertion, asserts and logs FAIL.

    rlFail comment

=over

=item comment

Short test summary.

=back

Returns 1 and asserts FAIL.

=cut

rlFail() {
    __INTERNAL_LogAndJournalFail "$1"
    return 1
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssert0
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Arithmetic Asserts

=head3 rlAssert0

Assertion checking for the equality of parameter to zero.

    rlAssert0 comment value

=over

=item comment

Short test summary, e.g. "Test if compilation ended successfully".

=item value

Integer value (usually return code of a command).

=back

Returns 0 and asserts PASS when C<value == 0>.

=cut

rlAssert0() {
    __INTERNAL_ConditionalAssert "$1" "$2" "(Assert: expected 0, got $2)"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertEquals
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertEquals

Assertion checking for the equality of two parameters.

    rlAssertEquals comment value1 value2

=over

=item comment

Short test summary, e.g. "Test if all 3 packages have been downloaded".

=item value1

First parameter to compare, can be a number or a string

=item value2

Second parameter to compare, can be a number or a string

=back

Returns 0 and asserts PASS when C<value1 == value2>.

=cut

rlAssertEquals() {
    if [ $# -lt 3 ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertEquals called without all needed parameters" ""
        return 1
    fi
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" == "$3" ]; echo $?)" "(Assert: '$2' should equal '$3')"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertNotEquals
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertNotEquals

Assertion checking for the non-equality of two parameters.

    rlAssertNotEquals comment value1 value2

=over

=item comment

Short test summary, e.g. "Test if return code is not 139".

=item value1

First parameter to compare, can be a number or a string

=item value2

Second parameter to compare, can be a number or a string

=back

Returns 0 and asserts PASS when C<value1 != value2>.

=cut

rlAssertNotEquals() {
    if [ $# -lt 3 ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertNotEquals called without all needed parameters" ""
        return 1
    fi
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" != "$3" ]; echo $?)" "(Assert: \"$2\" should not equal \"$3\")"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertGreater
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertGreater

Assertion checking whether first parameter is greater than the second one.

    rlAssertGreater comment value1 value2

=over

=item comment

Short test summary, e.g. "Test whether there are running more instances of program."

=item value1

Integer value.

=item value2

Integer value.

=back

Returns 0 and asserts PASS when C<value1 E<gt> value2>.

=cut

rlAssertGreater() {
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" -gt "$3" ]; echo $?)" "(Assert: \"$2\" should be greater than \"$3\")"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertGreaterOrEqual
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertGreaterOrEqual

Assertion checking whether first parameter is greater or equal to the second one.

    rlAssertGreaterOrEqual comment value1 value2

=over

=item comment

Short test summary (e.g. "There should present at least one...")

=item value1

Integer value.

=item value2

Integer value.

=back

Returns 0 and asserts PASS when C<value1 E<ge>= value2>.

=cut

rlAssertGreaterOrEqual() {
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" -ge "$3" ]; echo $?)" "(Assert: \"$2\" should be >= \"$3\")"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertLesser
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertLesser

Assertion checking whether first parameter is lesser than the second one.

    rlAssertLesser comment value1 value2

=over

=item comment

Short test summary, e.g. "Test whether there are running more instances of program."

=item value1

Integer value.

=item value2

Integer value.

=back

Returns 0 and asserts PASS when C<value1 E<lt> value2>.

=cut

rlAssertLesser() {
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" -lt "$3" ]; echo $?)" "(Assert: \"$2\" should be lesser than \"$3\")"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertLesserOrEqual
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertLesserOrEqual

Assertion checking whether first parameter is lesser or equal to the second one.

    rlAssertLesserOrEqual comment value1 value2

=over

=item comment

Short test summary (e.g. "There should present at least one...")

=item value1

Integer value.

=item value2

Integer value.

=back

Returns 0 and asserts PASS when C<value1 E<le>= value2>.

=cut

rlAssertLesserOrEqual() {
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" -le "$3" ]; echo $?)" "(Assert: \"$2\" should be <= \"$3\")"
    return $?
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertExists
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 File Asserts

=head3 rlAssertExists

Assertion checking for the existence of a file or a directory.

    rlAssertExists file|directory

=over

=item file|directory

Path to the file or directory.

=back

Returns 0 and asserts PASS when C<file> exists.

=cut

rlAssertExists(){
    if [ -z "$1" ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertExists called without parameter" ""
        return 1
    fi
    local FILE="File"
    if [ -d "$1" ] ; then
        FILE="Directory"
    fi
    __INTERNAL_ConditionalAssert "$FILE $1 should exist" "$([ -e "$1" ]; echo $?)"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertNotExists
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head3 rlAssertNotExists

Assertion checking for the non-existence of a file or a directory.

    rlAssertNotExists file|directory

=over

=item file|directory

Path to the file or directory.

=back

Returns 0 and asserts PASS when C<file> does not exist.

=cut

rlAssertNotExists(){
    if [ -z "$1" ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertNotExists called without parameter" ""
        return 1
    fi
    local FILE="File"
    if [ -d "$1" ] ; then
        FILE="Directory"
    fi
    __INTERNAL_ConditionalAssert "$FILE $1 should not exist" "$([ ! -e "$1" ]; echo $?)"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertGrep
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertGrep

Assertion checking if the file contains a pattern.

    rlAssertGrep pattern file [options]

=over

=item pattern

Regular expression to be searched for.

=item file

Path to the file.

=item options

Optional parameters to be passed to grep, default is C<-q>. Can be
used to perform case insensitive matches (-i), or using
extended (-E) or perl (-P) regular expressions.

=back

Returns 0 and asserts PASS when C<file> exists and contains given
C<pattern>.

=cut

rlAssertGrep(){
    if [ ! -e "$2" ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertGrep: failed to find file $2"
        return 2
    fi
    local options=${3:--q}
    grep $options -- "$1" "$2"
    __INTERNAL_ConditionalAssert "File '$2' should contain '$1'" $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertNotGrep
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertNotGrep

Assertion checking that the file does not contain a pattern.

    rlAssertNotGrep pattern file [options]

=over

=item pattern

Regular expression to be searched for.

=item file

Path to the file.

=item options

Optional parameters to be passed to grep, default is C<-q>. Can be
used to perform case insensitive matches (-i), or using
extended (-E) or perl (-P) regular expressions.

=back

Returns 0 and asserts PASS when C<file> exists and does not
contain given C<pattern>.

=cut
rlAssertNotGrep(){
    if [ ! -e "$2" ] ; then
        __INTERNAL_LogAndJournalFail "rlAssertNotGrep: failed to find file $2"
        return 2
    fi
    local options=${3:--q}
    ! grep $options -- "$1" "$2"
    __INTERNAL_ConditionalAssert "File '$2' should not contain '$1'" $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertDiffer
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertDiffer

Assertion checking that two files differ (are not identical).

    rlAssertDiffer file1 file2

=over

=item file1

Path to first file1

=item file2

Path to second file

=back

Returns 0 and asserts PASS when C<file1> and C<file2> differs.

=cut

rlAssertDiffer(){
    local file
    local IFS
    for file in "$1" "$2"; do
        if [ ! -e "$file" ]; then
            __INTERNAL_LogAndJournalFail "rlAssertDiffer: file $file was not found"
            return 2
        fi
    done
    ! cmp -s "$1" "$2"
    __INTERNAL_ConditionalAssert "Files $1 and $2 should differ" $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertNotDiffer
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertNotDiffer

Assertion checking that two files do not differ (are identical).

    rlAssertNotDiffer file1 file2

=over

=item file1

Path to first file1

=item file2

Path to second file

=back

Returns 0 and asserts PASS when C<file1> and C<file2> do not differ.

=cut

rlAssertNotDiffer() {
    local file
    local IFS
    for file in "$1" "$2"; do
        if [ ! -e "$file" ]; then
            __INTERNAL_LogAndJournalFail "rlAssertNotDiffer: file $file was not found"
            return 2
        fi
    done

    cmp -s "$1" "$2"
    __INTERNAL_ConditionalAssert "Files $1 and $2 should not differ" $?
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlRun
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Run, Watch, Report

=head3 rlRun

Run command with optional comment and make sure its exit code
matches expectations.

    rlRun [-t] [-l] [-c] [-s] command [status[,status...] [comment]]

=over

=item -t

If specified, stdout and stderr of the command output will be tagged
with strings 'STDOUT: ' and 'STDERR: '.

=item -l

If specified, output of the command (tagged, if -t was specified) is
logged using rlLog function. This is intended for short outputs, and
therefore only last 50 lines are logged this way. Longer outputs should
be analysed separately, or uploaded via rlFileSubmit or rlBundleLogs.

=item -c

Same as C<-l>, but only log the command output if it failed.

=item -s

Store stdout and stderr to a file (mixed together, as the user would see
it on a terminal) and set $rlRun_LOG variable to name of the file. $rlRun_LOG
is now actually an array where the first index holds the last reference to the file.
Thus its behavior is not changed if used without an index. The array is consumed by
the rlJournalEnd function to remove the leftover files, so no manual files removal
is needed anymore.
Note that if you need to use such a file after calling the rlJournalEnd function
you need to create your own copy of the respective file.
When -t option is used, the content of the file becomes tagged too.

If the -s option is not used, $rlRun_LOG is not modified and keeps its
content from the last "rlRun -s".

=item command

Command to run.

=item status

Expected exit code(s). Optional, default 0. If you expect more
exit codes, separate them with comma (e.g. "0,1" when both 0 and 1
are OK and expected), or use from-to notation (i.e. "2-5" for "2,3,4,5"),
or combine them (e.g. "2-4,26" for "2,3,4,26").

=item comment

Short summary describing the action (optional, but recommended -
explain what you are doing here).

=back

Returns the exit code of the command run. Asserts PASS when
command\'s exit status is in the list of expected exit codes.

Note:

=over

=item

The output of rlRun is buffered when using C<-t>, C<-l> or C<-s>
option (they use unix pipes, which are buffered by nature). If you
need an unbuffered output just make sure that C<expect> package is
installed on your system (its "unbuffer" tool will automatically
be used to produce unbuffered output).

=item

Be aware that there are some variables which can collide with your code executed
within rlRun. You should avoid using __INTERNAL_rlRun_* variables.

=item

When any of C<-t> C<-l>, C<-c>, or C<-s> option is used, special file
descriptors 111 and 112 are used to avoid the issue with incomplete log file,
bz1361246. As there might be an indefinite loop, there's a timeout of two
minutes implemented as a fix for bz1416796. Also an error message is issued to
signal the possibility of running subprocess which keeps the file descriptors
open.

Do not use these options if you expect process forking and continuouse run. Try
your own apropriate solution instead.

=back

B<Warning:> using C<unbuffer> tool is now disabled because of bug 547686.

=cut
#'

rlRun() {
    local __INTERNAL_rlRun_GETOPT=$($__INTERNAL_GETOPT_CMD -o lcts -- "$@" 2> >(while read -r line; do rlLogError "$FUNCNAME: $line"; done))
    eval set -- "$__INTERNAL_rlRun_GETOPT"

    local __INTERNAL_rlRun_DO_LOG=false
    local __INTERNAL_rlRun_DO_TAG=false
    local __INTERNAL_rlRun_DO_KEEP=false
    local __INTERNAL_rlRun_DO_CON=false
    local __INTERNAL_rlRun_TAG_OUT=''
    local __INTERNAL_rlRun_TAG_ERR=''
    local __INTERNAL_rlRun_LOG_FILE=''
    local IFS

    while true ; do
        case "$1" in
            -l)
                __INTERNAL_rlRun_DO_LOG=true;
                shift;;
            -c)
                __INTERNAL_rlRun_DO_LOG=true;
                __INTERNAL_rlRun_DO_CON=true;
                shift;;
            -t)
                __INTERNAL_rlRun_DO_TAG=true;
                __INTERNAL_rlRun_TAG_OUT='STDOUT: '
                __INTERNAL_rlRun_TAG_ERR='STDERR: '
                shift;;
            -s)
                __INTERNAL_rlRun_DO_KEEP=true
                shift;;
            --)
                shift;
                break;;
            *)
                shift;;
        esac
    done

    local __INTERNAL_rlRun_command=$1
    local __INTERNAL_rlRun_expected_orig=${2:-0}
    local __INTERNAL_rlRun_expected=${2:-0}
    local __INTERNAL_rlRun_comment
    local __INTERNAL_rlRun_comment_begin
    if [[ -z "$3" ]]; then
      __INTERNAL_rlRun_comment_begin="Running '$__INTERNAL_rlRun_command'"
      __INTERNAL_rlRun_comment="Command '$__INTERNAL_rlRun_command'"
    else
      __INTERNAL_rlRun_comment_begin="$3 :: actually running '$__INTERNAL_rlRun_command'"
      __INTERNAL_rlRun_comment="$3"
    fi

    # here we can do various sanity checks of the $command
    if [[ "$__INTERNAL_rlRun_command" =~ ^[[:space:]]*$ ]] ; then
      rlFail "rlRun: got empty or blank command '$__INTERNAL_rlRun_command'!"
      return 1
    elif false ; then
      # this an example check
      rlFail "rlRun: sanity check of command '$__INTERNAL_rlRun_command' failed!"
      return 1
    fi

    # create __INTERNAL_rlRun_LOG_FILE if needed
    if $__INTERNAL_rlRun_DO_LOG || $__INTERNAL_rlRun_DO_KEEP
    then
      __INTERNAL_rlRun_LOG_FILE=$( mktemp -p $__INTERNAL_PERSISTENT_TMP rlRun_LOG.XXXXXXXX )
      if [ ! -e "$__INTERNAL_rlRun_LOG_FILE" ]
      then
        rlFail "rlRun: Internal file creation failed"
        rlLogError "rlRun: Please report this issue to RH Bugzilla for Beakerlib component"
        rlLogError "rlRun: Turning off any -l, -c or -s options of rlRun"
        rlLogError "rlRun: Unless the test relies on them, rest of the test can be trusted."
        __INTERNAL_rlRun_DO_LOG=false
        __INTERNAL_rlRun_DO_KEEP=false
        __INTERNAL_rlRun_LOG_FILE=/dev/null
      fi
    fi

    # in case expected exit code is provided as "2-5,26", expand it to "2,3,4,5,26"
    while echo "$__INTERNAL_rlRun_expected" | grep -q '[0-9]-[0-9]'; do
        local __INTERNAL_rlRun_interval=$(echo "$__INTERNAL_rlRun_expected" | sed "s/.*\(\<[0-9]\+-[0-9]\+\>\).*/\1/")
        if [ -z "$__INTERNAL_rlRun_interval" ]; then
            rlLogWarning "rlRun: Something happened when getting interval, using '0-0'"
            __INTERNAL_rlRun_interval='0-0'
        fi
        local __INTERNAL_rlRun_interval_a=$(echo "$__INTERNAL_rlRun_interval" | cut -d '-' -f 1)
        local __INTERNAL_rlRun_interval_b=$(echo "$__INTERNAL_rlRun_interval" | cut -d '-' -f 2)
        if [ -z "$__INTERNAL_rlRun_interval_a" -o -z "$__INTERNAL_rlRun_interval_b" ]; then
            rlLogWarning "rlRun: Something happened when getting boundaries of interval, using '0' and '0'"
            __INTERNAL_rlRun_interval_a=0
            __INTERNAL_rlRun_interval_b=0
        fi
        if [ $__INTERNAL_rlRun_interval_a -gt $__INTERNAL_rlRun_interval_b ]; then
            rlLogWarning "rlRun: First boundary has to be smaller than second one, using '$__INTERNAL_rlRun_interval_b' and '$__INTERNAL_rlRun_interval_b'"
            __INTERNAL_rlRun_interval_a=$__INTERNAL_rlRun_interval_b
        fi
        local __INTERNAL_rlRun_replacement="$__INTERNAL_rlRun_interval_a"
        let __INTERNAL_rlRun_interval_a=$__INTERNAL_rlRun_interval_a+1

        local __INTERNAL_rlRun_i
        for __INTERNAL_rlRun_i in $(seq $__INTERNAL_rlRun_interval_a $__INTERNAL_rlRun_interval_b); do
            __INTERNAL_rlRun_replacement="$__INTERNAL_rlRun_replacement,$__INTERNAL_rlRun_i"
        done
        __INTERNAL_rlRun_expected="${__INTERNAL_rlRun_expected//$__INTERNAL_rlRun_interval/$__INTERNAL_rlRun_replacement/}"
    done

    rlLogDebug "rlRun: Running command: $__INTERNAL_rlRun_command"

    __INTERNAL_PrintText "$__INTERNAL_rlRun_comment_begin" "BEGIN"

    if $__INTERNAL_rlRun_DO_LOG || $__INTERNAL_rlRun_DO_TAG || $__INTERNAL_rlRun_DO_KEEP; then
        # handle issue with incomplete logs (bz1361246), this could be improved using coproc
        # in RHEL-6 and higher
        # open file descriptors to parsing processes
        exec 111> >(sed -u -e "s/^/$__INTERNAL_rlRun_TAG_OUT/g" | tee -a $__INTERNAL_rlRun_LOG_FILE)
        local __INTERNAL_rlRun_OUTpid=$!
        exec 112> >(sed -u -e "s/^/$__INTERNAL_rlRun_TAG_ERR/g" | tee -a $__INTERNAL_rlRun_LOG_FILE)
        local __INTERNAL_rlRun_ERRpid=$!
        eval "$__INTERNAL_rlRun_command" 2>&112 1>&111
        local __INTERNAL_rlRun_exitcode=$?
        # close parsing processes
        exec 111>&-
        exec 112>&-
        # wait for parsing processes to finish their job
        local __INTERNAL_rlRun_counter=0
        while kill -0 $__INTERNAL_rlRun_OUTpid 2>/dev/null || kill -0 $__INTERNAL_rlRun_ERRpid 2>/dev/null; do
          [[ $((__INTERNAL_rlRun_counter++)) -gt 12000 ]] && {
            rlLogError "waiting for flushing the output timed out"
            rlLogError "  check whether the command you run is not forking to background which causes the output pipe to be kept open"
            rlLogError "  if there are such processes, their outputs might not be complete"
            break
          }
          sleep 0.01;
        done
        rlLogDebug "waiting for parsing processes took $__INTERNAL_rlRun_counter cycles"
    else
        eval "$__INTERNAL_rlRun_command"
        local __INTERNAL_rlRun_exitcode=$?
    fi
    rlLogDebug "rlRun: command = '$__INTERNAL_rlRun_command'; exitcode = $__INTERNAL_rlRun_exitcode; expected = $__INTERNAL_rlRun_expected"
    if $__INTERNAL_rlRun_DO_LOG || $__INTERNAL_rlRun_DO_TAG || $__INTERNAL_rlRun_DO_KEEP; then
        sync
    fi

    echo "$__INTERNAL_rlRun_expected" | grep -q "\<$__INTERNAL_rlRun_exitcode\>"   # symbols \< and \> match the empty string at the beginning and end of a word
    local __INTERNAL_rlRun_result=$?

    if $__INTERNAL_rlRun_DO_LOG && ( ! $__INTERNAL_rlRun_DO_CON || ( $__INTERNAL_rlRun_DO_CON && [ $__INTERNAL_rlRun_result -ne 0 ] ) ); then
        rlLog "Output of '$__INTERNAL_rlRun_command':"
        rlLog "--------------- OUTPUT START ---------------"
        local __INTERNAL_rlRun_line
        tail -n 50 "$__INTERNAL_rlRun_LOG_FILE" | while read -r __INTERNAL_rlRun_line || [[ -n "$__INTERNAL_rlRun_line" ]]
        do
          rlLog "$__INTERNAL_rlRun_line"
        done
        rlLog "---------------  OUTPUT END  ---------------"
    fi
    if $__INTERNAL_rlRun_DO_KEEP; then
        rlRun_LOG=( "$__INTERNAL_rlRun_LOG_FILE" "${rlRun_LOG[@]}" )
        export rlRun_LOG
    elif $__INTERNAL_rlRun_DO_LOG; then
        rm $__INTERNAL_rlRun_LOG_FILE
    fi

    rlLogDebug "rlRun: Command finished with exit code: $__INTERNAL_rlRun_exitcode, expected: $__INTERNAL_rlRun_expected_orig"
    __INTERNAL_ConditionalAssert "$__INTERNAL_rlRun_comment" $__INTERNAL_rlRun_result "(Expected $__INTERNAL_rlRun_expected_orig, got $__INTERNAL_rlRun_exitcode)" "$__INTERNAL_rlRun_command"

    return $__INTERNAL_rlRun_exitcode
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWatchdog
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlWatchdog

Run C<command>. If it does not finish in specified time, then kill
it using C<signal>.
Note that the command is executed in a sub-shell so modified environment
(e.g. set variables) is not relfected in the test environment.

    rlWatchdog command timeout [signal] [callback]

=over

=item command

Command to run.

=item timeout

Timeout to wait, in seconds.

=item signal

Signal to use (optional, default KILL).

=item callback

Callback function to be called before the signal is send (optional, none
by default). The callback function will have one argument available -- PGID
of the process group.

=back

Returns 0 if the command ends normally, without need to be killed.

=cut

rlWatchdog() {
    # Save current shell options
    local shell_options=$(set +o)

    set -m
    local command=$1
    local timeout=$2
    local killer=${3:-"KILL"}
    local callback=${4:-""}
    rm -f __INTERNAL_FINISHED __INTERNAL_TIMEOUT
    rlLog "Runnning $command, with $timeout seconds timeout"
    eval "$command; touch __INTERNAL_FINISHED" &
    local pidcmd=$!
    eval "sleep $timeout; touch __INTERNAL_TIMEOUT" &
    local pidsleep=$!

    while true; do
        if [ -e __INTERNAL_FINISHED ]; then
            rlLog "Command ended itself, I am not killing it."
            /bin/kill -- -$pidsleep
            sleep 1
            rm -f __INTERNAL_FINISHED __INTERNAL_TIMEOUT
            # Restore previous shell options
            eval "$shell_options"
            return 0
        elif [ -e __INTERNAL_TIMEOUT ]; then
            rlLog "Command is still running, I am killing it with $killer"
            if [ -n "$callback" ] \
               && type $callback 2>/dev/null | grep -q "$callback is a function"
            then
                rlLog "Function $callback is present, I am calling it"
                $callback $pidcmd
            fi
            /bin/kill -$killer -- -$pidcmd
            sleep 1
            rm -f __INTERNAL_FINISHED __INTERNAL_TIMEOUT
            eval "$shell_options"
            return 1
        fi
        sleep 1
    done
    eval "$shell_options"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlReport
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlReport

Report test result to the test harness. The command to be used for
reporting is set by the respective plugin. You can also use the
C<$BEAKERLIB_COMMAND_REPORT_RESULT> variable to use your custom
command.

    rlReport name result [score] [log]

=over

=item name

Name of the test result.

=item result

Result (one of PASS, WARN, FAIL, SKIP). If called with something
else, will use WARN.

=item score

Test score (optional).

=item log

Optional log file to be submitted instead of default C<OUTPUTFILE>.

=back

=cut

rlReport() {
    # only PASS/WARN/FAIL/SKIP is allowed
    local IFS
    local testname="$1"
    local result="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
    local score="$3"
    local logfile=${4:-$OUTPUTFILE}
    case "$result" in
          'PASS' | 'PASSED' | 'PASSING') result='PASS'; ;;
          'FAIL' | 'FAILED' | 'FAILING') result='FAIL'; ;;
          'WARN' | 'WARNED' | 'WARNING') result='WARN'; ;;
          'SKIP' | 'SKIPPED' | 'SKIPPING') result='SKIP'; ;;
          *)
            rlLogWarning "rlReport: Only PASS/WARN/FAIL/SKIP results are possible."
            result='WARN'
          ;;
        esac
    rlLogDebug "rlReport: result: $result, score: $score, log: $logfile"
    if [ -z "$BEAKERLIB_COMMAND_REPORT_RESULT" ]; then
      local BEAKERLIB_COMMAND_REPORT_RESULT="$__INTERNAL_DEFAULT_REPORT_RESULT"
    fi

    # report the result only if TESTID is set
    if [ -n "$TESTID" ] ; then
        $BEAKERLIB_COMMAND_REPORT_RESULT "$testname" "$result" "$logfile" "$score" \
            || rlLogError "rlReport: Failed to report the result"
    fi
}

__INTERNAL_version_cmp() {
  if [[ "$1" == "$2" ]]; then
    return 0
  fi
  local i ver1="$1" ver2="$2" type="${3:-:}"

  ver1=($(echo "$ver1" | tr "$type" ' ')) ver2=($(echo "$ver2" | tr "$type" ' '))
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z "${ver2[i]}" ]]; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    case $type in
      :)
        __INTERNAL_version_cmp "${ver1[i]}" "${ver2[i]}" - || return $?
      ;;
      -)
        __INTERNAL_version_cmp "${ver1[i]}" "${ver2[i]}" _ || return $?
      ;;
      _)
        __INTERNAL_version_cmp "${ver1[i]}" "${ver2[i]}" . || return $?
      ;;
      .)
        if ((36#${ver1[i]} > 36#${ver2[i]})); then
          return 1
        fi
        if ((36#${ver1[i]} < 36#${ver2[i]})); then
          return 2
        fi
      ;;
    esac
  done
  return 0
}; # end of __INTERNAL_version_cmp

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCmpVersion
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlCmpVersion

Compare two given versions composed by numbers and letters divided by dot (.),
underscore (_), or dash (-).

    rlCmpVersion ver1 ver2

If ver1 = ver2, sign '=' is printed to stdout and 0 is returned.
If ver1 > ver2, sign '>' is printed to stdout and 1 is returned.
If ver1 < ver2, sign '<' is printed to stdout and 2 is returned.

=cut

rlCmpVersion() {
  rlLogDebug "$FUNCNAME(): comparing '$1' and '$2'"
  __INTERNAL_version_cmp "$1" "$2"
  local res=$?
  local text_res
  case $res in
    0)
      text_res='='
    ;;
    1)
      text_res='>'
    ;;
    2)
      text_res='<'
    ;;
    *)
      text_res="!"
  esac
  rlLogDebug "$FUNCNAME(): relation is: '$1' $text_res '$2'"
  echo "$text_res"
  return $res
}; # end of rlCmpVersion


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlTestVersion
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlTestVersion

Test releation between two given versions based on given operator.

    rlTestVersion ver1 op ver2

=over

=item op

Operator defining the logical expression.
It can be '=', '==', '!=', '<', '<=', '=<', '>', '>=', or '=>'.

=back

Returns 0 if the expresison ver1 op ver2 is true; 1 if the expression is false
and 2 if something went wrong.

=cut

rlTestVersion() {
  [[ " = == != < <= =< > >= => " =~ \ $2\  ]] || return 2
  rlLogDebug "$FUNCNAME(): is '$1' $2 '$3' true?"
  local res=$(rlCmpVersion $1 $3)
  if [[ "$2" == "!=" ]]; then
    if [[ "$res" == "=" ]]; then
      rlLogDebug "$FUNCNAME(): no"
      return 1
    else
      rlLogDebug "$FUNCNAME(): yes"
      return 0
    fi
  elif [[ "$2" =~ $res ]]; then
    rlLogDebug "$FUNCNAME(): yes"
    return 0
  else
    rlLogDebug "$FUNCNAME(): no"
    return 1
  fi
}; # end of rlTestVersion

__INTERNAL_rlIsDistro(){
  local distro="$(beakerlib-lsb_release -ds)"
  local whole="$(beakerlib-lsb_release -rs)"
  local major="$(beakerlib-lsb_release -rs | cut -d '.' -f 1)"
  local IFS

  rlLogDebug "distro='$distro'"
  rlLogDebug "major='$major'"
  rlLogDebug "whole='$whole'"

  echo $distro | grep -q "$1" || return 1
  shift

  [[ -z "$1" ]] && return 0

  __INTERNAL_OScmpVersion "$whole" "$@"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsRHEL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head2 Release Info

Can use environment variable BEAKERLIB_OS_RELEASE for alternative os-release information.
You can either supply a file path (recognised by starting with "/") or directly as
a list of environment variables.

Example:

    BEAKERLIB_OS_RELEASE="ID=rhel VERSION_ID=42" rlIsRHEL 42

=head3 rlIsRHEL

    rlIsRHEL [VERSION_SPEC]...

=over

=item VERSION_SPEC

Argument specifies version of particular RHEL distribution, eg. 8, 8.4 ">8.4".

For more details see description of L</rlIsOSVersion>.

=back

Returns 0 when we're running on RHEL.
With given version specification in arguments returns 0 if the particular RHEL version is running.

Prototype:

    rlIsRHEL

  Returns 0 if we are running on RHEL.

    rlIsRHEL 7 '>=8.5'

  Returns 0 if we are running any RHEL 7 or RHEL 8.5 and higher.

=cut
#'

rlIsRHEL(){
  local res=0
  local __INTERNAL_rlIsOS_suppress_error=1
  rlIsOS rhel && rlIsOSVersion "$@"
  res=$?
  if [[ $res -le 1 ]]; then
    return $res
  else
    rlLogDebug "$FUNCNAME(): fallback to __INTERNAL_rlIsDistro"
    __INTERNAL_rlIsDistro "Red Hat Enterprise Linux" "$@" \
      || __INTERNAL_rlIsDistro "Red Hat Desktop release" "$@"
  fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsFedora
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsFedora

    rlIsFedora [VERSION_SPEC]...

=over

=item VERSION_SPEC

Argument specifies version of particular Fedora distribution, eg. 30, ">30".

For more details see description of L</rlIsOSVersion>.

=back

Returns 0 when we're running on Fedora.
With given version specification in arguments returns 0 if the particular Fedora version is running.

Prototype:

    rlIsFedora

  Returns 0 if we are running on Fedora.

    rlIsFedora 30 32

  Returns 0 if we are running Fedora 30 or 32.

=cut
#'

rlIsFedora(){
  local res=0
  local __INTERNAL_rlIsOS_suppress_error=1
  rlIsOS fedora && rlIsOSVersion "$@"
  res=$?
  if [[ $res -le 1 ]]; then
    return $res
  else
    rlLogDebug "$FUNCNAME(): fallback to __INTERNAL_rlIsDistro"
    __INTERNAL_rlIsDistro "Fedora" "$@"
  fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsCentOS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsCentOS

    rlIsCentOS [VERSION_SPEC]...

=over

=item VERSION_SPEC

Argument specifies version of particular CentOS distribution, eg. 7, ">7".

For more details see description of L</rlIsOSVersion>.

=back

Returns 0 when we're running on CentOS.
With given version specification in arguments returns 0 if the particular CentOS version is running.

Prototype:

    rlIsCentOS

  Returns 0 if we are running on CentOS.

    rlIsCentOS 7.1 6

  Returns 0 if we are running CentOS 7.1 or any CentOS 6.

=cut
#'

rlIsCentOS(){
  local res=0
  local __INTERNAL_rlIsOS_suppress_error=1
  rlIsOS centos && rlIsOSVersion "$@"
  res=$?
  if [[ $res -le 1 ]]; then
    return $res
  else
    rlLogDebug "$FUNCNAME(): fallback to __INTERNAL_rlIsDistro"
    __INTERNAL_rlIsDistro "CentOS" "$@"
  fi
}


__INTERNAL_rlGetOSReleaseItem(){
  local osrelease_file=${BEAKERLIB_OS_RELEASE:-/etc/os-release} item="$1" value res=0
  if [[ ! -e $osrelease_file ]]; then
    if [[ "$osrelease_file" =~ ^/ ]]; then
        rlLogDebug "could not find file $osrelease_file"
        res=2
    fi
  else
    osrelease_file=$(cat "$osrelease_file" || exit 3)
    res=$?
  fi
  if [[ $res == 0 ]]; then
    value=$(eval "$osrelease_file" || exit 3; [[ -n "${!item+x}" ]] || exit 1; eval "echo \"\$${item}\"")
    res=$?
  fi
  case $res in
    0)
      echo "$value"
      rlLogDebug "$FUNCNAME(): parsed $item=$value from $osrelease_file"
      ;;
    3)
      rlLogError "could not parse the $osrelease_file"
      ;;
    1)
      rlLogDebug "could not find $item"
      ;;
  esac
  return $res
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsOS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsOS

    rlIsOS ID

=over

=item ID

Argument is based on contents of /etc/os-release.
Possible options of ID are e.g. fedora, rhel, centos, ol.

=back

Returns 0 when we're running on system with respective ID.
Returns 1 when parameter does not match with ID in os-release.
Returns 2 when there is no ID defined.
Returns 3 when no argument is given.

Prototype:

    rlIsOS rhel

  Returns 0 if we are running on RHEL.

=cut
#'

rlIsOS() {
  local ID exp_id="$1"
  local __INTERNAL_rlIsOS_suppress_error=${__INTERNAL_rlIsOS_suppress_error-}
  [[ -z "$exp_id" ]] && {
    rlLogError "one argument is required"
    return 3
  }
  ID=$(__INTERNAL_rlGetOSReleaseItem ID) || {
    if [[ -n "$__INTERNAL_rlIsOS_suppress_error" ]]; then
      rlLogDebug "could not get OS ID"
    else
      rlLogError "could not get OS ID"
    fi
    return 2
  }
  [[ "${ID^^}" == "${exp_id^^}" ]] || {
    rlLogDebug "OS '$ID' do not match '$exp_id'"
    return 1
  }
  return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsOSLike
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsOSLike

    rlIsOSLike ID_LIKE

=over

=item ID_LIKE

Argument is based on contents of /etc/os-release.
Possible options of ID_LIKE are e.g. fedora, rhel.

=back

Returns 0 when we're running on system with requested ID_LIKE.
Returns 1 when parameter does not match with ID nor ID_LIKE in os-release.
Returns 2 when there is no ID or ID_LIKE defined.
Returns 3 when no argument is given.

Prototype:

    rlIsOSLike rhel

  Returns 0 if we are running on RHEL, CentOS, Rocky Linux, etc..

    rlIsOSLike fedora

  Returns 0 if we are running on Fedora, RHEL, CentOS, Oracle Linux, etc..

=cut
#'

rlIsOSLike() {
  local ID exp_id="$1"
  [[ -z "$exp_id" ]] && {
    rlLogError "one argument is required"
    return 3
  }
  ID="$(__INTERNAL_rlGetOSReleaseItem ID_LIKE) $(__INTERNAL_rlGetOSReleaseItem ID)" || {
    rlLogError "could not find ID_LIKE nor ID"
    return 2
  }
  [[ "${ID^^}" =~ $(echo "\<${exp_id^^}\>") ]] || {
    rlLogDebug "OS '$ID' do not match '$exp_id'"
    return 1
  }
  return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsOSVersion
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsOSVersion

    rlIsOsVersion VERSION_SPEC...

=over

=item VERSION_SPEC

Parameter is based on VERSION_ID in /etc/os-release.
It consists of either C<major> or C<major>.C<minor> refering to a particular release.

It accepts multiple arguments separated by space (8.1 8.2 8.3 9).

To specify a group of distributions optional operator can be passed in argument
together with the version number as one string ('>8.5').
Operator can be '<', '<=', '=<', '=', '>', '>=' matching whether the currently
installed version is lesser, lesser or equal, equal, equal or greater, greater
than the version number supplied as second half of the argument.

Note that when using >/< operators you have to either put the argument in quotes
or escape the operators to avoid them being interpreted as bash redirection operator.

=back

Returns 0 when we're running distribution of the particular version requested by the argument.

It usually follows after C<rlIsOS> and C<rlIsOSLike>.

Be cautious when using together with C<rlIsOSLike> as different distributions may use different versioning schema.

Prototype:

   rlIsOSVersion 6 7 9

  Returns 0 if we are running distribution with VERSION_ID 6, 7 or 9.

    rlIsOSVersion 7.8 8

  Returns 0 if we are running distribution 7.8 or any 8.

    rlIsOSVersion ">=7.5" or rlIsOSVersion \>=7.5

  Returns 0 if we are running distribution 7.5 or higher (both minors or majors).

Note:

    rlIsOSVersion '<7.5' || rlIsOSVersion '<8.5'

  would also cover 7.9 as it is less than 8.5, which is not what you want.
  So if you want to construct a condition for a distribution <7.5 within the major 7 or
  a distribution <8.5 within the major 8 you actually need to use following construct:

    rlIsOSVersion 7 && rlIsOSVersion '<7.5' || rlIsOSVersion 8 && rlIsOSVersion '<8.5'

  This returns 0 when running distribution less than 7.5 and less then 8.5, but not 7.9 (nor 6.9).

=cut
#'

rlIsOSVersion() {
  [[ -z "$1" ]] && {
    rlLogDebug "$FUNCNAME(): no version specified, acting as noop"
    return 0
  }
  local res=1 arg
  local VERSION_ID
  VERSION_ID=$(__INTERNAL_rlGetOSReleaseItem VERSION_ID) || {
    rlLogDebug "could not get VERSION_ID"
    return 3
  }
  __INTERNAL_OScmpVersion "$VERSION_ID" "$@"
}

__INTERNAL_OScmpVersion() {
  local VERSION_ID="$1"
  local res=1
  rlLogDebug "$FUNCNAME(): args: $*"
  [[ "$VERSION_ID" =~ $(echo '^([0-9]+)(\.([0-9]+))?') ]] || {
    rlLogError "unexpected OS version format '$VERSION_ID'"
    rlLogDebug "$FUNCNAME(): res=2"
    return 2
  }
  local major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[3]}
  rlLogDebug "$FUNCNAME(): major=$major, minor=$minor"
  shift
  while [[ -n "$1" ]]; do
    arg="$1"
    rlLogDebug "$FUNCNAME(): processing '$arg'"
    shift
    [[ "$arg" =~ $(echo '^([!<=>]*)?\s*([0-9]+)(\.([0-9]+))?') ]] || {
      rlLogError "unexpected version format '$arg'"
      continue
    }
    local op=${BASH_REMATCH[1]} exp_major=${BASH_REMATCH[2]} exp_minor=${BASH_REMATCH[4]}
    if [[ -z "$exp_major" ]]; then
      rlLogError "unexpected version format '$arg'"
      continue
    fi
    # no operator means equal
    [[ -z "$op" ]] && {
      rlLogDebug "$FUNCNAME(): no relation specified, falling back to equal '=$arg'"
      op='='
    }
    # if minor is not given, ignore it when comparing
    [[ -z "$exp_minor" ]] && {
      rlLogDebug "$FUNCNAME(): comparing major verions only"
      minor=''
    }
    # test current version against the expected one
    rlTestVersion "$major${minor:+.$minor}" "$op" "$exp_major${exp_minor:+.$exp_minor}" && {
      res=0
      break
    }
  done
  rlLogDebug "$FUNCNAME(): res=$res"
  return $res
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsRHELLike
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsRHELLike

    rlIsRHELLike [VERSION_SPEC]...

=over

=item VERSION_SPEC

Argument specifies version of particular RHEL distribution, eg. 8, 8.4 ">8.4".

For more details see description of L</rlIsOSVersion>.

=back

Returns 0 when we're running on RHEL-like distribution.
These are considered to be RHEL, CentOS, Rocky Linux, etc..
With given version specification in arguments returns 0 if the particular
version of RHEL-like distribution is running.

Prototype:

    rlIsRHELLike

  Returns 0 if we are running on RHEL-like system.

    rlIsRHELLike ">=6"

  Returns 0 if we are running on RHEL-like distribution of version 6.0 or higher.

=cut
#'

rlIsRHELLike(){
  rlIsRHEL "$@" || {
    rlIsOSLike rhel && rlIsOSVersion "$@"
  }
}

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Ondrej Hudlicky <ohudlick@redhat.com>

=item *

Petr Muller <pmuller@redhat.com>

=item *

Jan Hutar <jhutar@redhat.com>

=item *

Petr Splichal <psplicha@redhat.com>

=item *

Ales Zelinka <azelinka@redhat.com>

=back

=cut
