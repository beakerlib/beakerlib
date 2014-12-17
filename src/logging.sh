# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: logging.sh - part of the BeakerLib project
#   Description: Phases, logging & metrics related stuff
#
#   Author: Chris Ward <cward@redhat.com>
#   Author: Ondrej Hudlicky <ohudlick@redhat.com>
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

export __INTERNAL_DEFAULT_SUBMIT_LOG=__INTERNAL_FileSubmit

: <<'=cut'
=pod

=head1 NAME

BeakerLib - logging - phase support, logging functions and metrics

=head1 DESCRIPTION

Routines for creating various types of logs inside BeakerLib tests.
Implements also phase support with automatic assert evaluation.

=head1 FUNCTIONS

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal Stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

__INTERNAL_LogText() {
    local MESSAGE=${1:-"***BAD BEAKERLIB_HLOG CALL***"}
    local LOGFILE=${2:-$OUTPUTFILE}
    [ -z "$LOGFILE" ] && LOGFILE=$( mktemp --tmpdir=$__INTERNAL_PERSISTENT_TMP )
    [ ! -e "$LOGFILE" ] && touch "$LOGFILE"
    [ ! -w "$LOGFILE" ] && LOGFILE=$( mktemp --tmpdir=$__INTERNAL_PERSISTENT_TMP )
    echo -e "$MESSAGE" | tee -a $LOGFILE >&2
    return $?
}

__INTERNAL_FileSubmit() {
    local FILENAME="$4"
    local STORENAME="$__INTERNAL_PERSISTENT_TMP/BEAKERLIB_${TESTID}_STORED_$(basename $FILENAME)"
    if [ -z "$TESTID" ]
    then
        STORENAME="$__INTERNAL_PERSISTENT_TMP/BEAKERLIB_STORED_$(basename $FILENAME)"
    fi

    rlLog "File '$FILENAME' stored here: $STORENAME"
    cp -f "$FILENAME" "$STORENAME"
    return $?
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlLog*
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Logging

=head3 rlLog

=head3 rlLogDebug

=head3 rlLogInfo

=head3 rlLogWarning

=head3 rlLogError

=head3 rlLogFatal

Create a time/priority-labelled message in the log. There is a bunch of aliases
which can create messages formated as DEBUG/INFO/WARNING/ERROR or FATAL (but you
would probably want to use rlDie instead of the last one).

    rlLog message [logfile] [priority] [label]

=over

=item message

Message you want to show (use quotes when invoking).

=item logfile

Log file. If not supplied, OUTPUTFILE is assumed.

=item priority

Priority of the log.

=item label

Print this text instead of time in log label.

=back

=cut

__INTERNAL_CenterText() {
  local text="$1"
  local left=$(( ($2+${#text})/2 ))
  printf "%*s%*s" $left "${text}" $(( $2-$left ))
}; # end of __INTERNAL_CenterText

rlLog() {
    local message="$1"
    local logfile="$2"
    local prio="$3"
    local label="$4"
    __INTERNAL_LogText ":: [$(__INTERNAL_CenterText "${label:-$(date +%H:%M:%S)}" 10)] :: ${prio:+"$prio "}$message" "$logfile"
    if [[ -z "$prio" && -z "$label" ]]; then
        rljAddMessage "$message" "LOG"
    fi
}

rlLogDebug() {
  if [ "$DEBUG" == 'true' -o "$DEBUG" == '1' -o "$LOG_LEVEL" == "DEBUG" ]; then
    rlLog "$1" "$2" "[ DEBUG   ] ::" && rljAddMessage "$1" "DEBUG"
  fi
}
rlLogInfo()    { rlLog "$1" "$2" "[ INFO    ] ::"; rljAddMessage "$1" "INFO" ; }
rlLogWarning() { rlLog "$1" "$2" "[ WARNING ] ::"; rljAddMessage "$1" "WARNING" ; }
rlLogError()   { rlLog "$1" "$2" "[ ERROR   ] ::"; rljAddMessage "$1" "ERROR" ; }
rlLogFatal()   { rlLog "$1" "$2" "[ FATAL   ] ::"; rljAddMessage "$1" "FATAL" ; }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlDie
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlDie

Create a time-labelled message in the log, report test result,
upload logs, close unfinished phase and terminate the test.

    rlDie message [file...]

=over

=item message

Message you want to show (use quotes when invoking) - this
option is mandatory.

=item file

Files (logs) you want to upload as well. C<rlBundleLogs>
will be used for it. Files which are not readable will be
excluded before calling C<rlBundleLogs>, so it is safe to
call even with possibly not existent logs and it will
succeed.

=back

=cut

rlDie() {
    # handle mandatory comment
    local rlMSG="$1"
    shift
    # handle optional list of logs
    if [ -n "$*" ]; then
        local logs=''

        local log
        for log in "$@"; do
            [ -r "$log" ] && logs="$logs $log"
        done

        [ -n "$logs" ] && rlBundleLogs rlDieLogsBundling $logs
    fi
    # do the work
    rlLogFatal "$rlMSG"
    rlAssert0 "$rlMSG" 1
    rlPhaseEnd
    exit 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlHeadLog
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# obsoleted by phases
# : <<=cut
# =pod
#
# =head2 rlHeadLog
#
# Creates a header in the supplied log
#
#  * parameter 1: message you want to show (use quotes when invoking)
#  * optional parameter 2: log file. If not supplied, OUTPUTFILE is assumed
# =cut

rlHeadLog() {
    local text="$1"
    local logfile=${2:-""}
    __INTERNAL_LogText "\n::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::" "$logfile"
    rlLog "$text" "$logfile"
    __INTERNAL_LogText "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" "$logfile"
    rlLogWarning "rlHeadLog is obsoleted, use rlPhase* instead"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlBundleLogs
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlBundleLogs

Create a tarball of files (e.g. logs) and attach them to the test result.

    rlBundleLogs package file [file...]

=over

=item package

Name of the package. Will be used as a part of the tar-ball name.

=item file

File(s) to be packed and submitted.

=back

Returns result of submiting the tarball.

=cut

rlBundleLogs(){
    local BASENAME="$1"
    local LOGDIR="/tmp/$BASENAME" # no-reboot

    if [ -n "$JOBID" ]
    then
      LOGDIR="$LOGDIR-$JOBID"
    fi

    if [ -n "$RECIPEID" ]
    then
      LOGDIR="$LOGDIR-$RECIPEID"
    fi

    if [ -n "$TESTID" ]
    then
      LOGDIR="$LOGDIR-$TESTID"
    fi

    rlLog "Bundling logs"

    rlLogDebug "rlBundleLogs: Creating directory for logs: $LOGDIR"
    mkdir -p "$LOGDIR"

    local i
    for i in "${@:2}"; do
        local i_new="$( echo $i | sed 's|[/ ]|_|g' )"
        while [ -e "$LOGDIR/$i_new" ]; do
            i_new="${i_new}_next"
        done
        rlLogInfo "rlBundleLogs: Adding '$i' as '$i_new'"
        cp -r "$i" "$LOGDIR/$i_new"
        [ $? -eq 0 ] || rlLogError "rlBundleLogs: '$i' can't be packed"
    done

    local TARBALL="$LOGDIR.tar.gz"
    tar zcf "$TARBALL" "$LOGDIR"
    if [ ! $? -eq 0 ]; then
        rlLogError "rlBundleLogs: Packing was not successful"
        return 1
    fi

    rlFileSubmit "$TARBALL"
    SUBMITCODE=$?

    if [ ! $SUBMITCODE -eq 0 ]; then
        rlLogError "rlBundleLog: Submit wasn't successful"
    fi
    rlLogDebug "rlBundleLogs: Removing tmp: $TARBALL"
    rm -rf $TARBALL
    rlLogDebug "rlBundleLogs: Removing tmp: $LOGDIR"
    rm -rf $LOGDIR

    return $SUBMITCODE
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlFileSubmit
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlFileSubmit

Resolves absolute path to the file, replaces / for - and uploads this renamed
file using rhts-submit-log.
It also allows you to specify your custom name for the uploaded file.

    rlFileSubmit [-s sep] path_to_file [required_name]

=over

=item -s sep

Sets separator (i.e. the replacement of the /) to sep.

=item path_to_file

Either absolute or relative path to file. Relative path is converted
to absolute.

=item required_name

Default behavior renames file to full_path_to_file with / replaced for -,
if this does not suit your needs, you can specify the name using this
option.

Examples:

rlFileSubmit logfile.txt -> logfile.txt
cd /etc; rlFileSubmit ./passwd -> etc-passwd
rlFileSubmit /etc/passwd -> etc-passwd
rlFileSubmit /etc/passwd my-top-secret_file -> my-top-secret-file
rlFileSubmit -s '_' /etc/passwd -> etc_passwd

=back

=cut

rlFileSubmit() {
    GETOPT=$(getopt -q -o s: -- "$@")
    eval set -- "$GETOPT"

    SEPARATOR='-'
    while true ; do
        case "$1" in
            -s)
                SEPARATOR=$2;
                shift 2
                ;;
            --)  shift; break;;
            *)   shift;;
        esac
    done

    local RETVAL=255
    local FILE="$1"
    local ALIAS
    local TMPDIR="$(mktemp -d)" # no-reboot
    if [ -f "$FILE" ]; then
        if [ -n "$2" ]; then
            ALIAS="$2"
        else
            if echo "$FILE" | egrep -q "^\.(\.)?/"; then
                # ^ if the path is specified as relative ~ begins with ./ or ../
                local POM=$(dirname "$FILE")
                ALIAS=$(cd "$POM"; pwd)
                ALIAS="$ALIAS/$(basename $FILE)"
            else
                ALIAS=$1
            fi
            ALIAS=$(echo $ALIAS | tr '/' "$SEPARATOR" | sed "s/^${SEPARATOR}*//")
        fi
        rlLogInfo "Sending $FILE as $ALIAS"
        ln -s "$(readlink -f $FILE)" "$TMPDIR/$ALIAS"

        if [ -z "$BEAKERLIB_COMMAND_SUBMIT_LOG" ]
        then
          BEAKERLIB_COMMAND_SUBMIT_LOG="$__INTERNAL_DEFAULT_SUBMIT_LOG"
        fi

        $BEAKERLIB_COMMAND_SUBMIT_LOG -T "$TESTID" -l "$TMPDIR/$ALIAS"
        RETVAL=$?
    fi
    rm -rf $TMPDIR
    return $RETVAL
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlShowPkgVersion
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Info

=head3 rlShowPackageVersion

Shows a message about version of packages.

    rlShowPackageVersion package [package...]

=over

=item package

Name of a package(s) you want to log.

=back

=cut

rlShowPackageVersion()
{
    local score=0
    if [ $# -eq 0 ]; then
        rlLogWarning "rlShowPackageVersion: Too few options"
        return 1
    fi

    local pkg
    for pkg in "$@"; do
        if rpm -q $pkg &> /dev/null; then
            IFS=$'\n'
            local line
            for line in $(rpm -q $pkg --queryformat "$pkg RPM version: %{version}-%{release}.%{arch}\n")
            do
                rlLog $line
            done
            unset IFS
        else
            rlLogWarning "rlShowPackageVersion: Unable to locate package $pkg"
            let score+=1
        fi
    done
    [ $score -eq 0 ] && return 0 || return 1
}

# backward compatibility
rlShowPkgVersion() {
    rlLogWarning "rlShowPkgVersion is obsoleted by rlShowPackageVersion"
    rlShowPackageVersion "$@";
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetArch
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetArch

This function is deprecated. Use rlGetPrimaryArch or rlGetSecondaryArch
instead, or use uname. This function will be only kept for compatibility.

Return base arch for the current system (good when you need
base arch on a multilib system).

    rlGetArch

On an i686 system you will get i386, on a ppc64 you will get ppc.

=cut


rlGetArch() {
    local archi=$( uname -i 2>/dev/null || uname -m )
    case "$archi" in
        i486 | i586 | i686)
            archi='i386'
        ;;
        ppc64)
            archi='ppc'
        ;;
        '')
            rlLogWarning "rlGetArch: Do not know what the arch is ('$(uname -a)'), guessing 'i386'"
            archi='i386'
        ;;
    esac
    rlLogWarning "rlGetArch: This function is deprecated"
    rlLogWarning "rlGetArch: Update test to use rlGetPrimaryArch/rlGetSecondaryArch"
    rlLogDebug "rlGetArch: This is architecture '$archi'"
    echo "$archi"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetPrimaryArch
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetPrimaryArch

Return primary arch for the current system (good when you need
base arch on a multilib system).

    rlGetPrimaryArch

=cut


rlGetPrimaryArch() {
    local archi=$( uname -m )
    local rhelv=$( rlGetDistroRelease )

    if ! rlIsRHEL
    then
      rlLogError "rlGetPrimaryArch: Concept of primary and secondary architectures is defined on RHEL only"
    fi

    local retval=$archi

    case "$archi" in
        i386 | i486 | i586 | i686)
            case "$rhelv" in
                4 | 5)
                    retval='i386'
                ;;
                6)
                    retval='i686'
                ;;
                7)
                    retval=''
                ;;
                *)
                    retval=''
                ;;
            esac
        ;;
        ppc64)
            case "$rhelv" in
                4 | 5)
                    retval='ppc'
                ;;
                *)
                    retval='ppc64'
                ;;
            esac
        ;;
        x86_64)
            retval='x86_64'
        ;;
        s390x)
            retval='s390x'
        ;;
        s390)
            case "$rhelv" in
                4)
                    retval='s390'
                ;;
                *)
                    retval=''
                ;;
            esac
        ;;
        ia64)
            case "$rhelv" in
                4 | 5)
                    retval='ia64'
                ;;
                *)
                    retval=''
                ;;
            esac
        ;;
        aarch64)
            retval='aarch64'
        ;;
        ppc64le)
            retval='ppc64le'
        ;;
        *)
            rlLogError "rlGetPrimaryArch: Do not know what the arch is ('$(uname -a)')."
            retval=''
        ;;
    esac
    rlLogDebug "rlGetPrimaryArch: The primary architecture is '$retval'"
    echo "$retval"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetSecondaryArch
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetSecondaryArch

Return base arch for the current system (good when you need
base arch on a multilib system).

    rlGetSecondaryArch

=cut


rlGetSecondaryArch() {
    local archi=$( uname -m )
    local rhelv=$( rlGetDistroRelease )

    if ! rlIsRHEL
    then
      rlLogError "rlGetSecondaryArch: Concept of primary and secondary architectures is defined on RHEL only"
    fi

    local retval=$archi

    case "$archi" in
        i386 | i486 | i586 | i686)
            retval=''
        ;;
        ppc64)
            case "$rhelv" in
                4 | 5)
                    retval='ppc64'
                ;;
                *)
                    retval='ppc'
                ;;
            esac
        ;;
        x86_64)
            case "$rhelv" in
                4 | 5)
                    retval='i386'
                ;;
                *)
                    retval='i686'
                ;;
            esac
        ;;
        s390x)
            retval='s390'
        ;;
        s390)
            retval=''
        ;;
        ia64)
            case "$rhelv" in
                4 | 5)
                    retval='i386'
                ;;
                *)
                    retval=''
                ;;
            esac
        ;;
        aarch64)
            retval=''
        ;;
        ppc64le)
            retval=''
        ;;
        *)
            rlLogError "rlGetSecondaryArch: Do not know what the arch is ('$(uname -a)')."
            retval=''
        ;;
    esac
    rlLogDebug "rlGetSecondaryArch: The secondary architecture is '$retval'"
    echo "$retval"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetDistroRelease, rlGetDistroVariant
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetDistroRelease

=head3 rlGetDistroVariant

Return release or variant of the distribution on the system.

    rlGetDistroRelease
    rlGetDistroVariant

For example on the RHEL-4-AS you will get release 4 and variant AS,
on the RHEL-5-Client you will get release 5 and variant Client.

=cut

__rlGetDistroVersion() {
    local version=0
    if rpm -q redhat-release &>/dev/null; then
        version=$( rpm -q --qf="%{VERSION}" redhat-release )
    elif rpm -q fedora-release &>/dev/null; then
        version=$( rpm -q --qf="%{VERSION}" fedora-release )
    elif rpm -q centos-release &>/dev/null; then
        version=$( rpm -q --qf="%{VERSION}" centos-release )
    elif rpm -q --whatprovides redhat-release &>/dev/null; then
        version=$( rpm -q --qf="%{VERSION}" --whatprovides redhat-release )
    else
        version="unknown"
    fi
    rlLogDebug "__rlGetDistroVersion: This is distribution version '$version'"
    echo "$version"
}
rlGetDistroRelease() {
    __rlGetDistroVersion | sed "s/^\([0-9.]\+\)[^0-9.]\+.*$/\1/" | sed "s/6\.9[0-9]/7/" | cut -d '.' -f 1
}
rlGetDistroVariant() {
    VARIANT="$(__rlGetDistroVersion | sed "s/^[0-9.]\+\(.*\)$/\1/")"
    if [ -z "$VARIANT" ]; then
      rpm -q --qf="%{NAME}" --whatprovides redhat-release | cut -c 16- | sed 's/.*/\u&/'
    else
      echo $VARIANT
    fi
}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlShowRunningKernel
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlShowRunningKernel

Log a message with version of the currently running kernel.

    rlShowRunningKernel

=cut

rlShowRunningKernel() {
    rlLog "Kernel version: $(uname -r)"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlPhaseStart
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Phases

=head3 rlPhaseStart

Starts a phase of a specific type. The final phase result is based
on all asserts included in the phase.  Do not forget to end phase
with C<rlPhaseEnd> when you are done.

    rlPhaseStart type [name]

=over

=item type

Type of the phase, one of the following:

=over

=item FAIL

When assert fails here, phase will report a FAIL.

=item WARN

When assert fails here, phase will report a WARN.

=back

=item name

Optional name of the phase (if not provided, one will be generated).

=back

If all asserts included in the phase pass, phase reports PASS.

=cut

rlPhaseStart() {
    if [ "x$1" = "xFAIL" -o "x$1" = "xWARN" ] ; then
        rljAddPhase "$1" "$2"
        return $?
    else
        rlLogError "rlPhaseStart: Unknown phase type: $1"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlPhaseEnd
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlPhaseEnd

End current phase, summarize asserts included and report phase result.

    rlPhaseEnd

Final phase result is based on included asserts and phase type.

=cut

rlPhaseEnd() {
    rljClosePhase
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlPhaseStart*
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlPhaseStartSetup

=head3 rlPhaseStartTest

=head3 rlPhaseStartCleanup

Start a phase of the specified type: Setup -> WARN, Test -> FAIL, Cleanup -> WARN.

    rlPhaseStartSetup [name]
    rlPhaseStartTest [name]
    rlPhaseStartCleanup [name]

=over

=item name

Optional name of the phase. If not specified, default Setup/Test/Cleanup are
used.

=back

If you do not want these shortcuts, use plain C<rlPhaseStart> function.

=cut

rlPhaseStartSetup() {
    rlPhaseStart "WARN" "${1:-Setup}"
}
rlPhaseStartTest() {
    rlPhaseStart "FAIL" "${1:-Test}"
}
rlPhaseStartCleanup() {
    rlPhaseStart "WARN" "${1:-Cleanup}"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlLogLowMetric
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Metric

=head3 rlLogMetricLow

Log a metric, which should be as low as possible to the journal.
(Example: memory consumption, run time)

    rlLogMetricLow name value [tolerance]

=over

=item name

Name of the metric. It has to be unique in a phase.

=item value

Value of the metric.

=item tolerance

It is used when comparing via rcw. It means how larger can the
second value be to not trigger a FAIL. Default is 0.2

=back

When comparing FIRST, SECOND, then:

    FIRST >= SECOND means PASS
    FIRST+FIRST*tolerance >= SECOND means WARN
    FIRST+FIRST*tolerance < SECOND means FAIL

B<Example:> Simple benchmark is compared via this metric type in
rcw.  It has a tolerance of 0.2. First run had 1 second. So:

    For PASS, second run has to be better or equal to first.
            So any value of second or less is a PASS.
    For WARN, second run can be a little worse than first.
            Tolerance is 0.2, so anything lower than 1.2 means WARN.
    For FAIL, anything worse than 1.2 means FAIL.

=cut

rlLogMetricLow() {
    rljAddMetric "low" "$1" "$2" "$3"
}

rlLogLowMetric() {
    rlLogWarning "rlLogLowMetric is deprecated, use rlLogMetricLow instead"
    rljAddMetric "low" "$1" "$2" "$3"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlLogMetricHigh
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlLogMetricHigh

Log a metric, which should be as high as possible to the journal.
(Example: number of executions per second)

    rlLogMetricHigh name value [tolerance]

=over

=item name

Name of the metric. It has to be unique in a phase.

=item value

Value of the metric.

=item tolerance

It is used when comparing via rcw. It means how lower can the
second value be to not trigger a FAIL. Default is 0.2

=back

When comparing FIRST, SECOND, then:

    FIRST <= SECOND means PASS
    FIRST+FIRST*tolerance <= SECOND means WARN
    FIRST+FIRST*tolerance > SECOND means FAIL

=cut

rlLogMetricHigh() {
    rljAddMetric "high" "$1" "$2" "$3"
}

rlLogHighMetric() {
    rlLogWarning "rlLogHighMetric is deprecated, use rlLogMetricHigh instead"
    rljAddMetric "high" "$1" "$2" "$3"
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
