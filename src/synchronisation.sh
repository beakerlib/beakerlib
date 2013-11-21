# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: synchronisation.sh - part of the BeakerLib project
#   Description: Process synchronisation routines
#
#   Author: Hubert Kario <hkario@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

getopt -T || ret=$?
if [ ${ret:-0} -ne 4 ]; then
    echo "ERROR: Non enhanced getopt version detected" 1>&2
    exit 1
fi

: <<'=cut'
=pod

=head1 NAME

BeakerLib - synchronisation - Process synchronisation routines

=head1 DESCRIPTION

This is a library of helpers for process synchronisation of applications.

NOTE: none of this commands will cause the test proper to fail, even in case
of critical errors during their invocation. If you want your test to fail
if those test fail, use their return codes and rlFail().

=head1 FUNCTIONS

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWaitForSocket
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Process Synchronisation

=head3 rlWaitForSocket

Pauses script execution until socket starts listening.
Returns 0 if socket started listening, 1 if timeout was reached or PID exited.
Return code is greater than 1 in case of error.

    rlWaitForSocket {port|path} [-p PID] [-t time]

=over

=item port|path

Network port to wait for opening or a path to UNIX socket.
Regular expressions are also supported.

=item -t time

Timeout in seconds (optional, default=120). If the socket isn't opened before
the time elapses the command returns 1.

=item -p PID

PID of the process that should also be running. If the process exits before
the socket is opened, the command returns with status code of 1.

=back

=cut

rlWaitForSocket(){

    local timeout=120
    local proc_pid=1
    local socket=""

    # that is the GNU extended getopt syntax!
    local TEMP=$(getopt -o t:p: -n 'rlWaitForSocket' -- "$@")
    if [[ $? != 0 ]] ; then
        rlLogError "rlWaitForSocket: Can't parse command options, terminating..."
        return 127
    fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -t) timeout="$2"; shift 2
                ;;
            -p) proc_pid="$2"; shift 2
                ;;
            --) shift 1
                break
                ;;
            *) rlLogError "rlWaitForSocket: unrecognized option"
                return 127
                ;;
        esac
    done
    socket="$1"

    # the case statement is a portable way to check if variable contains only
    # digits (regexps are not available in old, RHEL3-era, bash)
    case "$timeout" in
        ''|*[!0-9]*) rlLogError "rlWaitForSocket: Invalid timeout provided"
            return 127
            ;;
    esac
    case "$proc_pid" in
        ''|*[!0-9]*) rlLogError "rlWaitForSocket: Invalid PID provided"
            return 127
            ;;
    esac
    case "$socket" in
        *[0-9])
            #socket_type="network"
            local grep_opt="\:$socket[[:space:]]"
            ;;
        "") rlLogError "rlWaitForSocket: No socket specified"
            return 127
            ;;
        *)
            #socket_type="unix"
            local grep_opt="$socket"
            ;;
    esac
    rlLogInfo "rlWaitForSocket: Waiting max ${timeout}s for socket \`$socket' to start listening"

    ( while true ; do
        netstat -nl | grep -E "$grep_opt" >/dev/null
        if [[ $? -eq 0 ]]; then
            exit 0;
        else
            if [[ ! -e "/proc/$proc_pid" ]]; then
                exit 1;
            fi
            sleep 1
        fi
    done ) &
    local netstat_pid=$!

    ( sleep $timeout && kill -HUP -$netstat_pid ) 2>/dev/null &
    local watcher=$!

    wait $netstat_pid
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        kill -s SIGKILL $watcher 2>/dev/null
        rlLogInfo "rlWaitForSocket: Socket opened!"
        return 0
    else
        if [[ $ret -eq 1 ]]; then
            kill -s SIGKILL $watcher 2>/dev/null
            rlLogWarning "rlWaitForSocket: PID terminated!"
        else
            rlLogWarning "rlWaitForSocket: Timeout elapsed"
        fi
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Hubert Kario <hkario@redhat.com>

=back

=cut
