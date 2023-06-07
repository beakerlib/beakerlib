# Authors:  Jiri Jaburek    <jjaburek@redhat.com>
#
# Description: Test watching wrapper for runtest.sh or similar runnable
#
# Copyright (c) 2013 Red Hat, Inc. All rights reserved. This copyrighted
# material is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

#
# test watcher - an idea
#
# LWD = Beaker Local Watchdog, expires when TestTime (Makefile) reaches zero
# EWD = Beaker External Watchdog, expires 30m after LWD expiration
#
# - set up a temporary file usable for cleanup file path transfer
#   and export its path via an env variable
# - hook LWD when run from Beaker
#   - this hook will send SIGHUP to the watcher on LWD expire and block
#     until the watcher process exits
# - set up SIGHUP handling, which
#   - sends SIGKILL to test if running
#   - sets up SIGALRM handler for EWD and schedules alarm(2)
#     - EWD handler SIGKILLs cleanup (if running)
# - run test
#   - if it finishes in time, do nothing (unset pid)
#   - if INT is received while it is running, SIGKILL the test, unset pid
# - execute possible cleanup
#   - if it still finishes in time (no HUP so far), do nothing (unset pid)
#   - if INT is received while it is running, SIGKILL cleanup, unset pid
# - exit cleanly
#
# Some considerations taken into account / tested:
#
# - SIGHUP is received while running cleanup (TestTime expired after test exit)
#   - testpid is already 0, only SIGALRM (cleanup kill) is scheduled, giving
#     the cleanup another ewd_maxsecs seconds to finish
# - SIGTERM is received at any time
#   - the only reasonable case is system reboot/poweroff, which we cannot
#     delay anyway (to allow cleanup execution), so just exit (SIG_DFL)
#     - this doesn't really damage anything, the test can be easily re-run and
#       continue creating the cleanup, if the previous cleanup state was saved
#       and the test sends the cleanup path to the watcher again


from __future__ import print_function
import os
import sys
import signal
import time
import errno
import fcntl
import tempfile


### CONFIG
#
# Beaker External watchdog = 30 minutes after LWD
# (25 minutes = 1500 secs by default, configurable via env)
if 'TESTWATCHER_EWD_SECS' in os.environ:
    ewd_maxsecs = int(os.environ['TESTWATCHER_EWD_SECS'])
    if ewd_maxsecs <= 0:
        raise Exception("invalid TESTWATCHER_EWD_SECS env var value")
else:
    ewd_maxsecs = 1500

# beah LWD hook
lwd_guard_file = '/usr/share/rhts/hooks/watchdog/testwatcher-cleanup-guard'

# file descriptor and file path (name) used for cleanup filename transfer
# via temporary file from test to watcher, the watcher expects the test
# to write path to cleanup executable into it, it's checked just before
# cleanup execution
clfd, clpath = tempfile.mkstemp(prefix='testwatcher-', dir='/var/tmp') # no-reboot
# env var containing the path, so the test can write to it
os.environ['TESTWATCHER_CLPATH'] = clpath
#
###

### GLOBALS
#
selfname = os.path.basename(__file__)

testpid = 0
cleanuppid = 0

if os.environ.get('TASKID'):
    beah = True
else:
    beah = False
#
###


### HELPERS
#
def debug(msg):
    print('TESTWATCHER: '+msg)
    sys.stdout.flush()


def fatal(msg):
    print('TESTWATCHER fatal: '+msg, file=sys.stderr)
    sys.stderr.flush()
    sys.exit(1)


def sigpgkill_safe(pid):
    # if pid does not exist / is not related, return
    try:
        os.kill(pid, 0)
    except:
        return
    os.killpg(pid, signal.SIGKILL)


def beah_warn(part):
    # python "subprocess" not on RHEL4
    os.system('rhts-report-result "TESTWATCHER ('+part+')" WARN /dev/null')
#
###

### BEAH LWD WATCHDOG
#
# custom shell-based watchdog guard
# (selfname[:15] works around 15-char /proc/pid/comm limitation)
watchdog_guard_cont = r"""
#!/bin/sh
rm -f "$0"
wrap_pid='"""+str(os.getpid())+r"""'
wrap_name="$(ps c --no-headers -o comm --pid $wrap_pid)"
[ $? -ne 0 ] && { echo "wrapper pid is not running"; exit 0; }
[ "$wrap_name" != '"""+selfname[:15]+r"""' ] && \
    { echo "wrapper pid not a testwatch process: $wrap_name"; exit 0; }
kill -HUP "$wrap_pid"
while ps --no-headers -o pid --pid $wrap_pid >/dev/null; do sleep 1; done;
"""


# write out custom watchdog guard to beaker hooks dir,
# causing it to be launched when local watchdog expires
def beah_lwd_hook():
    debug('hooking beah LWD')
    try:
        os.makedirs(os.path.dirname(lwd_guard_file))
    except OSError as e:
        if e.errno == errno.EEXIST:
            pass
    f = open(lwd_guard_file, 'w')
    f.write(watchdog_guard_cont)
    f.close()
    os.chmod(lwd_guard_file, 0o755)


# called when EWD (external watchdog) is about to expire
def beah_ewd_action(signum, frame):
    debug('beah EWD is about to strike')
    global cleanuppid
    if cleanuppid != 0:
        sigpgkill_safe(cleanuppid)
    if beah:
        beah_warn('external watchdog')


# called when LWD expires
def beah_lwd_action(signum, frame):
    debug('beah LWD expired')
    global testpid
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    if testpid != 0:
        sigpgkill_safe(testpid)
        testpid = 0
    signal.signal(signal.SIGALRM, beah_ewd_action)
    signal.alarm(ewd_maxsecs)
    if beah:
        beah_warn('local watchdog')
#
###


### CLEANUP WATCHER
#
# executed by INT sent to the test watcher process
def cleanup_interrupt(signum, frame):
    debug('cleanup interrupted')
    global cleanuppid

    signal.signal(signal.SIGINT, signal.SIG_IGN)

    if cleanuppid != 0:
        sigpgkill_safe(cleanuppid)

    if beah:
        beah_warn('cleanup interrupt')


def exec_cleanup():
    global cleanuppid

    # no os.SEEK_SET on RHEL4
    os.lseek(clfd, 0, 0)

    filename = os.read(clfd, 1024).strip()

    # no cleanup
    if not filename:
        debug('no cleanup set')
        return

    if not os.path.isfile(filename) or not os.access(filename, os.X_OK):
        debug('cleanup file not found / not executable, skipping')
        return

    signal.signal(signal.SIGINT, cleanup_interrupt)

    cleanuppid = os.fork()
    if cleanuppid == 0:
        os.setpgrp()
        debug('executing cleanup at '+filename)
        os.execvp(filename, [filename])
    else:
        debug('parent waiting for cleanup '+str(cleanuppid))
        while cleanuppid != 0:
            try:
                os.waitpid(cleanuppid, 0)
                cleanuppid = 0
            except OSError as e:
                if e.errno == errno.EINTR:
                    pass
                if e.errno == errno.ECHILD:
                    cleanuppid = 0
#
###


### TEST WATCHER
#
# executed by INT sent to the test watcher process
def test_interrupt(signum, frame):
    debug('test interrupted')
    global testpid

    # ignore future INT
    signal.signal(signal.SIGINT, signal.SIG_IGN)

    # kill frozen test + its process group
    if testpid != 0:
        sigpgkill_safe(testpid)

    # log warn
    if beah:
        beah_warn('test interrupt')


def exec_test():
    # NOTE: signal handling can be set up before fork, it won't make it
    # past execve/execvp and it's safer this way
    # (the child can be killed via SIGINT received right after pid is available
    #  to the parent, ie. right after fork)

    # beaker LWD
    signal.signal(signal.SIGHUP, beah_lwd_action)
    # user interrupt
    signal.signal(signal.SIGINT, test_interrupt)

    # fork and exec the test, wait for it in the parent process
    global testpid
    testpid = os.fork()
    if testpid == 0:
        # become process group leader, so we can kill all related
        # processes (from the parent) when interrupted
        os.setpgrp()

        debug('executing test at '+' '.join(sys.argv[1:]))
        os.execvp(sys.argv[1], sys.argv[1:])

    else:
        debug('parent waiting for test '+str(testpid))
        while testpid != 0:
            try:
                # wait for entire process group
                os.waitpid(testpid, 0)
                testpid = 0
            except OSError as e:
                # no traceback if interrupted by a signal
                if e.errno == errno.EINTR:
                    pass
                # safety measure, shouldn't happen
                if e.errno == errno.ECHILD:
                    testpid = 0
#
###


### MAIN
#
# sanity check
def main():
    if len(sys.argv) < 2:
        fatal('usage: '+selfname+' <command> [args]')

    if beah:
        beah_lwd_hook()

    exec_test()
    debug('parent done waiting for test')

    exec_cleanup()
    debug('parent done waiting for cleanup')

    # remove temporary (mkstemp'ed) file # no-reboot
    os.unlink(clpath)

    debug('all done, finishing watcher')
    sys.exit(0)


if __name__ == "__main__":
    sys.exit(main())
