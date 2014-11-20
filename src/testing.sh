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
    if [ -z "$3" ] ; then
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
    if [ -z "$3" ] ; then
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

Returns 0 and asserts PASS when C<value1 E<gt>= value2>.

=cut

rlAssertGreaterOrEqual() {
    __INTERNAL_ConditionalAssert "$1" "$([ "$2" -ge "$3" ]; echo $?)" "(Assert: \"$2\" should be >= \"$3\")"
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

    rlRun [-t] [-l] [-c] [-s] command [status[,status...]] [comment]

=over

=item -t

If specified, stdout and stderr of the command output will be tagged
with strigs 'STDOUT: ' and 'STDERR: '.

=item -l

If specified, output of the command (tagged, if -t was specified) is
logged using rlLog function. This is intended for short outputs, and
therefore only last 50 lines are logged this way. Longer outputs should
be analysed separately, or uploaded via rlFileSubmit or rlBundleLogs.

=item -c

Same as C<-l>, but only log the commands output if it failed.

=item -s

Store stdout and stderr to a file (mixed together, as the user would see
it on a terminal) and set $rlRun_LOG variable to name of the file. Caller
is responsible for removing the file. When -t option is used, the content
of the file becomes tagged too.

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
explain what are you doing here).

=back

Returns the exit code of the command run. Asserts PASS when
command\'s exit status is in the list of expected exit codes.

Note: The output of rlRun is buffered when using C<-t>, C<-l> or C<-s>
option (they use unix pipes, which are buffered by nature). If you
need an unbuffered output just make sure that C<expect> package is
installed on your system (its "unbuffer" tool will automatically
be used to produce unbuffered output).

B<Warning:> using C<unbuffer> tool is now disabled because of bug 547686.

=cut
#'

rlRun() {
    GETOPT=$(getopt -q -o lcts -- "$@")
    eval set -- "$GETOPT"

    local DO_LOG=false
    local DO_TAG=false
    local DO_KEEP=false
    local DO_CON=false
    local TAG_OUT=''
    local TAG_ERR=''
    local LOG_FILE=''

    while true ; do
        case "$1" in
            -l)
                DO_LOG=true;
                [ -n "$LOG_FILE" ] || LOG_FILE=$( mktemp --tmpdir=$__INTERNAL_PERSISTENT_TMP )
                shift;;
            -c)
                DO_LOG=true;
                DO_CON=true;
                [ -n "$LOG_FILE" ] || LOG_FILE=$( mktemp --tmpdir=$__INTERNAL_PERSISTENT_TMP )
                shift;;
            -t)
                DO_TAG=true;
                TAG_OUT='STDOUT: '
                TAG_ERR='STDERR: '
                shift;;
            -s)
                DO_KEEP=true
                [ -n "$LOG_FILE" ] || LOG_FILE=$( mktemp --tmpdir=$__INTERNAL_PERSISTENT_TMP )
                shift;;
            --)
                shift;
                break;;
            *)
                shift;;
        esac
    done

    if [ ! -e "$LOG_FILE" ]
    then
      if $DO_LOG || $DO_KEEP
      then
        rlFail "rlRun: Internal file creation failed"
        rlLogError "rlRun: Please report this issue to RH Bugzilla for Beakerlib component"
        rlLogError "rlRun: Turning off any -l, -c or -s options of rlRun"
        rlLogError "rlRun: Unless the test relies on them, rest of the test can be trusted."
        DO_LOG=false
        DO_KEEP=false
      fi
      LOG_FILE=/dev/null
    fi

    local command=$1
    local expected_orig=${2:-0}
    local expected=${2:-0}
    local comment
    local comment_begin
    if [[ -z "$3" ]]; then
      comment_begin="Running '$command'"
      comment="Command '$command'"
    else
      comment_begin="$3 :: actually running '$command'"
      comment="$3"
    fi

    # in case expected exit code is provided as "2-5,26", expand it to "2,3,4,5,26"
    while echo "$expected" | grep -q '[0-9]-[0-9]'; do
        local interval=$(echo "$expected" | sed "s/.*\(\<[0-9]\+-[0-9]\+\>\).*/\1/")
        if [ -z "$interval" ]; then
            rlLogWarning "rlRun: Something happened when getting interval, using '0-0'"
            interval='0-0'
        fi
        local interval_a=$(echo "$interval" | cut -d '-' -f 1)
        local interval_b=$(echo "$interval" | cut -d '-' -f 2)
        if [ -z "$interval_a" -o -z "$interval_b" ]; then
            rlLogWarning "rlRun: Something happened when getting boundaries of interval, using '0' and '0'"
            interval_a=0
            interval_b=0
        fi
        if [ $interval_a -gt $interval_b ]; then
            rlLogWarning "rlRun: First boundary have to be smaller then second one, using '$interval_b' and '$interval_b'"
            interval_a=$interval_b
        fi
        local replacement="$interval_a"
        let interval_a=$interval_a+1

        local i
        for i in $(seq $interval_a $interval_b); do
            replacement="$replacement,$i"
        done
        expected="${expected//$interval/$replacement/}"
    done

    rlLogDebug "rlRun: Running command: $command"

    rlLog "$comment_begin" "" "" "BEGIN"

    if $DO_LOG || $DO_TAG || $DO_KEEP; then
        local UNBUFFER=''
        ## This is disabled because of bug 547686
        #if which unbuffer 1>/dev/null 2>&1; then
        #        UNBUFFER='unbuffer '
        #fi
        if set -o | grep -q '^pipefail[[:space:]]'; then
          local pipefail=true
          if set -o | grep -q '^pipefail[[:space:]]*off$'; then
            set -o pipefail
            local pipefail=false
          fi
        else
          rlLogWarning "rlRun: \'set -o pipefail\' not supported, exit code of command will not be checked correctly."
        fi
        eval "$UNBUFFER$command" 2> >(sed -u -e "s/^/$TAG_ERR/g" |
                tee -a $LOG_FILE) 1> >(sed -u -e "s/^/$TAG_OUT/g" | tee -a $LOG_FILE)
        local exitcode=$?
        [ -n "$pipefail" ] && $pipefail || set +o pipefail
    else
        eval "$command"
        local exitcode=$?
    fi
    rlLogDebug "rlRun: command = '$command'; exitcode = $exitcode; expected = $expected"
    if $DO_LOG || $DO_TAG || $DO_KEEP; then
        sync
    fi

    echo "$expected" | grep -q "\<$exitcode\>"   # symbols \< and \> match the empty string at the beginning and end of a word
    local result=$?

    if $DO_LOG && ( ! $DO_CON || ( $DO_CON && [ $result -ne 0 ] ) ); then
        rlLog "Output of '$command':"
        rlLog "--------------- OUTPUT START ---------------"
        tail -n 50 "$LOG_FILE" | while read line
        do
          rlLog "$line"
        done
        rlLog "---------------  OUTPUT END  ---------------"
    fi
    if $DO_KEEP; then
        rlRun_LOG=$LOG_FILE
        export rlRun_LOG
    elif $DO_LOG; then
        rm $LOG_FILE
    fi

    rlLogDebug "rlRun: Command finished with exit code: $exitcode, expected: $expected_orig"
    __INTERNAL_ConditionalAssert "$comment" $result "(Expected $expected_orig, got $exitcode)" "$command"

    return $exitcode
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWatchdog
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlWatchdog

Run C<command>. If it does not finish in specified time, then kill
it using C<signal>.

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
            return 1
        fi
        sleep 1
    done
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

Result (one of PASS, WARN, FAIL). If called with something
else, will use WARN.

=item score

Test score (optional).

=item log

Optional log file to be submitted instead of default C<OUTPUTFILE>.

=back

=cut

rlReport() {
    # only PASS/WARN/FAIL is allowed
    local testname="$1"
    local result="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
    local score="$3"
    local logfile=${4:-$OUTPUTFILE}
    case "$result" in
          'PASS' | 'PASSED' | 'PASSING') result='PASS'; ;;
          'FAIL' | 'FAILED' | 'FAILING') result='FAIL'; ;;
          'WARN' | 'WARNED' | 'WARNING') result='WARN'; ;;
          *)
            rlLogWarning "rlReport: Only PASS/WARN/FAIL results are possible."
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
  local i ver1="$1" ver2="$2" type="${3:--}"

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
  __INTERNAL_version_cmp "$1" "$2"
  local res=$?
  case $res in
    0)
      echo '='
    ;;
    1)
      echo '>'
    ;;
    2)
      echo '<'
    ;;
    *)
      echo "!"
  esac
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

Operator definitng the logical expression.
It can be '=', '==', '!=', '<', '<=', '=<', '>', '>=', or '=>'.

=back

Returns 0 if the expresison ver1 op ver2 is true; 1 if the expression is false
and 2 if something went wrong.

=cut

rlTestVersion() {
  [[ " = == != < <= =< > >= => " =~ \ $2\  ]] || return 2
  local res=$(rlCmpVersion $1 $3)
  if [[ "$2" == "!=" ]]; then
    if [[ "$res" == "=" ]]; then
      return 1
    else
      return 0
    fi
  elif [[ "$2" =~ $res ]]; then
    return 0
  else
    return 1
  fi
}; # end of rlTestVersion

__INTERNAL_rlIsDistro(){
  local distro="$(beakerlib-lsb_release -ds)"
  local whole="$(beakerlib-lsb_release -rs)"
  local major="$(beakerlib-lsb_release -rs | cut -d '.' -f 1)"
  
  rlLogDebug "distro='$distro'"
  rlLogDebug "major='$major'"
  rlLogDebug "whole='$whole'"

  echo $distro | grep -q "$1" || return 1
  shift

  [[ -z "$1" ]] && return 0

  local arg
  for arg in "$@"
  do
    # sanity check - version needs to consist of numbers/dots/<=>
    [[ "$arg" =~ ^([\<=\>]*)([0-9][0-9\.]*)$ ]] || {
      rlLogError "unexpected argument format '$arg'"
      return 1
    }

    sign="${BASH_REMATCH[1]}"
    arg="${BASH_REMATCH[2]}"
    rlLogDebug "sign='$sign'"
    if [[ -z "$sign" ]]; then
      if [[ "$arg" == "$major" || "$arg" == "$whole" ]]
      then
        return 0
      fi
    else
      rlLogDebug "arg='$arg'"
      if [[ "$arg" =~ [.] ]]; then
        rlLogDebug 'evaluation whole version (including minor)'
        rlLogDebug "executing rlTestVersion \"$whole\" \"$sign\" \"$arg\""
        rlTestVersion "$whole" "$sign" "$arg"
      else
        rlLogDebug 'evaluation major version part only'
        rlLogDebug "executing rlTestVersion \"$major\" \"$sign\" \"$arg\""
        rlTestVersion "$major" "$sign" "$arg"
      fi
      res=$?
      rlLogDebug "result of rlTestVersion is '$res'"
      return $res
    fi
  done
  return 1
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsRHEL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head2 Release Info

=head3 rlIsRHEL

Check whether we're running on RHEL.
With given number of version as parameter returns 0 if the particular
RHEL version is running. Multiple arguments can be passed separated
with space as well as any particular release (5.1 5.2 5.3).
Each version can have a prefix consisting of '<', '<=', '=', '>=', '>',
matching whenever the currently installed version is lesser, lesser or equal,
equal, equal or greater, greater than the version specified as argument.
Note that ie. '=5' (unlike just '5') matches exactly 5 (5.0),
not 5.N, where N > 0.

    rlIsRHEL

Returns 0 if we are running on RHEL.

    rlIsRHEL 4.8 5

Returns 0 if we are running RHEL 4.8 or any RHEL 5.

=cut
#'

rlIsRHEL(){
  __INTERNAL_rlIsDistro "Red Hat Enterprise Linux" "$@" \
    || __INTERNAL_rlIsDistro "Red Hat Desktop release" "$@"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlIsFedora
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlIsFedora

Check whether we're running on Fedora.
With given number of version as parameter returns 0 if the particular Fedora
version is running.
Range matching can be used in the form used by rlIsRHEL.

    rlIsFedora

Returns 0 if we are running on Fedora.

    rlIsFedora 9 10

Returns 0 if we are running Fedora 9 or 10.

=cut
#'

rlIsFedora(){
  __INTERNAL_rlIsDistro "Fedora" "$@"
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
