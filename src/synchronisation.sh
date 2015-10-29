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

# add ability to kill whole process tree
# unfortunately, because we're running inside bash script, we can't
# use the simple solution of process groups and `kill -s SIG -$pid`
# usage: __INTERNAL_killtree PID [SIGNAL]
# returns first failed kill return code or 0 if all returned success
__INTERNAL_killtree() {
    local _pid=$1
    if [[ ! -n $_pid ]]; then
        return 2
    fi
    local _sig=${2:-TERM}
    local _ret=
    kill -s SIGSTOP ${_pid} || : # prevent parent from forking
    local _children=$(pgrep -P ${_pid})
    local _pret=$?
    if [[ $_pret -ne 0 && $_pret -ne 1 ]]; then
        return 4
    fi

    local _child
    for _child in $_children; do
        __INTERNAL_killtree ${_child} ${_sig} || _ret=${_ret:-$?}
    done

    kill -s ${_sig} ${_pid} || _ret=${_ret:-$?}
    kill -s SIGCONT ${_pid} || : # allow for signal delivery to parent
    return ${_ret:-0}
}

# wrapper around bash builtin `wait', adds timeout capability
__INTERNAL_wait() {
    local timeout=30
    local sigspec=SIGTERM

    while true ; do
        case "$1" in
            -t) timeout="$2"; shift 2
                ;;
            -s) sigspec="$2"; shift 2
                ;;
            --) shift 1
                break;
                ;;
            *) rlLogError "rlWait: unrecognized option"
                return 128
                ;;
        esac
    done

    local pids="$@"

    (sleep $timeout && for pid in $pids; do __INTERNAL_killtree $pid "$sigspec"; done)&
    local watcher=$!
    disown $watcher

    wait "$@"
    local my_ret=$?

    __INTERNAL_killtree $watcher SIGKILL 2> /dev/null

    return $my_ret
}

# Since all "wait for something to happen" utilities are basically the same,
# use a generic routine that can do all their work
__INTERNAL_wait_for_cmd() {

    # don't wait more than this many seconds
    local timeout=120
    # delay between command invocations
    local delay=1
    # abort if this process terminates
    local proc_pid=1
    # command to run
    local cmd
    # maximum number of command invocations
    local max_invoc=""
    # expected return code of command
    local exp_retval=0
    # name of routine to return errors for
    local routine_name="$1"
    shift 1

    # that is the GNU extended getopt syntax!
    local TEMP=$(getopt -o t:p:m:d:r: -n '$routine_name' -- "$@")
    if [[ $? != 0 ]] ; then
        rlLogError "$routine_name: Can't parse command options, terminating..."
        return 127
    fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -t) timeout="$2"; shift 2
                ;;
            -p) proc_pid="$2"; shift 2
                ;;
            -m) max_invoc="$2"; shift 2
                ;;
            -d) delay="$2"; shift 2
                ;;
            -r) exp_retval="$2"; shift 2
                ;;
            --) shift 1
                break
                ;;
            *) rlLogError "$routine_name: unrecognized option"
                return 127
                ;;
        esac
    done
    cmd="$1"

    if [[ $routine_name == "rlWaitForCmd" ]]; then
        rlLogInfo "$routine_name: waiting for \`$cmd' to return $exp_retval in $timeout seconds"
    fi

    # the case statement is a portable way to check if variable contains only
    # digits (regexps are not available in old, RHEL3-era, bash)
    case "$timeout" in
        ''|*[!0-9]*) rlLogError "${routine_name}: Invalid timeout provided"
            return 127
            ;;
    esac
    case "$proc_pid" in
        ''|*[!0-9]*) rlLogError "${routine_name}: Invalid PID provided"
            return 127
            ;;
    esac
    if [[ -n "$max_invoc" ]]; then
        case "$max_invoc" in
            ''|*[!0-9]*) rlLogError "${routine_name}: Invalid maximum number of invocations provided"
                return 127
                ;;
        esac
    fi
    # delay can be fractional, so "." is OK
    case "$delay" in
        ''|*[!0-9.]*) rlLogError "${routine_name}: Invalid delay specified"
            return 127
            ;;
    esac
    case "$exp_retval" in
        ''|*[!0-9]*) rlLogError "${routine_name}: Invalid expected command return value provided"
            return 127
            ;;
    esac

    # we use two child processes to get the timeout and process execution
    # one (command_pid) runs the command until it returns expected return value
    # the other is just a timout (watcher)

    # run command in loop
    ( local i=0
    while [[ -n $max_invoc && $i -lt $max_invoc ]] || [[ ! -n $max_invoc ]]; do
        eval $cmd
        if [[ $? -eq $exp_retval ]]; then
            exit 0;
        else
            if [[ ! -e "/proc/$proc_pid" ]]; then
                exit 1;
            fi
            sleep $delay
        fi
        i=$((i+1))
    done
    exit 2) &
    local command_pid=$!

    # kill command running in background if the timout has elapsed
    __INTERNAL_wait -t $timeout -s SIGKILL -- $command_pid 2> /dev/null
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        rlLogInfo "${routine_name}: Wait successful!"
        return 0
    else
        case $ret in
            1)
                rlLogWarning "${routine_name}: specified PID was terminated!"
                ;;
            2)
                rlLogWarning "${routine_name}: Max number of test command invocations reached!"
                ;;
            143|137)
                rlLogWarning "${routine_name}: Timeout reached"
                ;;
            *)
                rlLogError "${routine_name}: Unknown termination cause! Return code: $ret"
        esac
        return 1
    fi
}

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
# rlWaitForCmd
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head2 Process Synchronisation

=head3 rlWaitForCmd

Pauses script execution until command exit status is the expeced value.
Logs a WARNING and returns 1 if the command didn't exit successfully
before timeout elapsed or a maximum number of invocations has been
reached.

    rlWaitForCmd command [-p PID] [-t time] [-m count] [-d delay] [-r retval]

=over

=item command

Command that will be executed until its return code is equal 0 or value
speciefied as option to `-r'.

=item -t time

Timeout in seconds, default=120. If the command doesn't return 0
before time elapses, the command will be killed.

=item -p PID

PID of the process to check before running command. If the process
exits before the socket is opened, the command will log a WARNING.

=item -m count

Maximum number of `command' executions before continuing anyway. Default is
infite. Returns 1 if the maximum was reached.

=item -d delay

Delay between `command' invocations. Default 1.

=item -r retval

Expected return value of command. Default 0.

=back

=cut
rlWaitForCmd() {
    __INTERNAL_wait_for_cmd rlWaitForCmd "$@"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWaitForFile
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlWaitForFile

Pauses script execution until specified file or directory starts existing.
Returns 0 if file started existing, 1 if timeout was reached or PID exited.
Return code is greater than 1 in case of error.

    rlWaitForFile path [-p PID] [-t time] [-d delay]

=over

=item path

Path to file that should start existing.

=item -t time

Timeout in seconds (optional, default=120). If the file isn't opened before
the time elapses the command returns 1.

=item -p PID

PID of the process that should also be running. If the process exits before
the file is created, the command returns with status code of 1.

=item -d delay

Delay between subsequent checks for existence of file. Default 1.

=back
=cut
rlWaitForFile() {
    local timeout=120
    local proc_pid=1
    local delay=1
    local file=""

    # that is the GNU extended getopt syntax!
    local TEMP=$(getopt -o t:p:d: -n 'rlWaitForFile' -- "$@")
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
            -d) delay="$2"; shift 2
                ;;
            --) shift 1
                break
                ;;
            *) rlLogError "rlWaitForFile: unrecognized option"
                return 127
                ;;
        esac
    done
    file="$1"

    rlLogInfo "rlWaitForFile: Waiting max ${timeout}s for file  \`$file' to start existing"

    local cmd="[[ -e '$file' ]]"

    __INTERNAL_wait_for_cmd "rlWaitForFile" "${cmd}" -t "$timeout" -p "$proc_pid" -d "$delay"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWaitForSocket
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlWaitForSocket

Pauses script execution until socket starts listening.
Returns 0 if socket started listening, 1 if timeout was reached or PID exited.
Return code is greater than 1 in case of error.

    rlWaitForSocket {port|path} [-p PID] [-t time] [-d delay] [--close]

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

=item -d delay

Delay between subsequent checks for availability of socket. Default 1.

=item --close

Wait for the socket to stop listening.

=back

=cut

rlWaitForSocket(){

    local timeout=120
    local proc_pid=1
    local delay=1
    local socket=""
    local close=""

    # that is the GNU extended getopt syntax!
    local TEMP=$(getopt -o t:p:d: --longoptions close -n 'rlWaitForSocket' -- "$@")
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
            -d) delay="$2"; shift 2
                ;;
            --close) close="true"; shift 1
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

    local cmd="netstat -nl | grep -E '$grep_opt' >/dev/null"

    if [[ ${close:-false} == true ]]; then
        rlLogInfo "rlWaitForSocket: Waiting max ${timeout}s for socket \`$socket' to close"
        __INTERNAL_wait_for_cmd "rlWaitForSocket" "${cmd}" -t $timeout -p $proc_pid -d $delay -r 1
    else
        rlLogInfo "rlWaitForSocket: Waiting max ${timeout}s for socket \`$socket' to start listening"
        __INTERNAL_wait_for_cmd "rlWaitForSocket" "${cmd}" -t $timeout -p $proc_pid -d $delay
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlWait
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlWait

Wrapper around bash builtin `wait' command. See bash_builtins(1) man page.
Kills the process and all its children if the timeout elapses.

    rlWaitFor [n ...] [-s SIGNAL] [-t time]

=over

=item n

List of PIDs to wait for. They need to be background tasks of current shell.
See bash_builtins(1) section for `wait' command/

=item -t time

Timeout in seconds (optional, default=30). If the wait isn't successful
before the time elapses then all specified tasks are killed.

=item -s SIGNAL

Signal used to kill the process, optional SIGTERM by default.

=back

=cut

rlWait() {
    # that is the GNU extended getopt syntax!
    local TEMP=$(getopt -o t:s: -n 'rlWait' -- "$@")
    if [[ $? != 0 ]]; then
        rlLogError "rlWait: Can't parse command options, terminating..."
        return 128
    fi

    eval set -- "$TEMP"

    __INTERNAL_wait "$@"

    return $?
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
