#!/bin/bash
#
# Authors:  Jiri Jaburek    <jjaburek@redhat.com>
#
# Description: A one-file test suite for testwatcher.py
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
# this is a testing script for the test watcher tool (python/testwatcher.sh),
# the goal being verification in a standalone, beakerlib-independent fashion,
# since the tool is also standalone by design
#
# beakerlib side is covered by infrastructureTest.sh to some extent, the TODO
# being combination of test watcher with the beakerlib rlCleanup* functions,
# somehow
#
# also note that while testwatcher.py has a certain logic of detecting whether
# the beaker harness (beah) is running, this logic is only used for very beah
# specific things like reportning WARN to journal and hooking the LWD, neither
# of which is directly related to handling the test/cleanup pair
# therefore, we don't stimulate that beah logic here, at least for now

error()
{
    echo "error: $@" 1>&2
    exit 1
}
FAILED=0
fail()
{
    (( FAILED++ ))
    echo -e "\e[1;31m:::::::: FAILED ::::::::\e[0m"
}
testcase()
{
    echo
    echo -e "\e[1;34m--------------------------------------------------------------------------------\e[0m"
    echo -e "\e[1;34mtestcase:\e[0m $1"
    echo
}
mktest()
{
    filename="$1"
    shift
    {
        echo "#!/bin/bash"
        while [ $# -gt 0 ]; do
            echo "$1"
            shift
        done;
    } > "$filename"
    chmod +x "$filename"
}
+()
{
    local rc=
    local PS4="\e[1;33m+\e[0m "
    { set -x; } 2>/dev/null
    "$@"
    { rc=$?; set +x; } 2>/dev/null
    return $rc
}


# be strict during setup
set -e

tmpdir=$(mktemp -d)
trap "rm -rf \"$tmpdir\"" EXIT

#copy testwatcher.py
watcherloc="../python/testwatcher.py"
[ -f "$watcherloc" ] || watcherloc="python/testwatcher.py"
[ -f "$watcherloc" ] || error "could not find testwatcher.py"
cp "$watcherloc" "$tmpdir/."
cd "$tmpdir"

chmod +x testwatcher.py

set +e


################################################################################

#
# basic sanity success operations:
# - test successful, cleanup not set up
# - test successful, cleanup successful
########
testcase "sanity: test successful, cleanup not set up"
mktest test.sh 'echo end > test.log'
+ ./testwatcher.py ./test.sh
+ grep 'end' test.log || fail
rm -f test.sh test.log

########
testcase "sanity: test successful, cleanup successful"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo end > test.log'
mktest cleanup.sh 'echo end > cleanup.log'
+ ./testwatcher.py ./test.sh
+ grep 'end' test.log || fail
+ grep 'end' cleanup.log || fail
rm -f test.sh test.log cleanup.sh cleanup.log

#
# extended sanity testing:
# - arguments with spaces
# - ...
# TODO more sanity here (no argument passed, ...)
########
testcase "sanity: successful execution with passed arguments"
mktest test.sh 'while [ $# -gt 0 ]; do echo "> $1" >> test.log; shift; done;'
+ ./testwatcher.py ./test.sh "first argument" "second argument"
+ grep '^> first argument' test.log || fail
+ grep '^> second argument' test.log || fail
rm -f test.sh test.log

#
# user-controlled (no beah) scenarios (SIGINT):
# - test interrupted, cleanup not set up
# - test interrupted, cleanup successful
# - test successful,  cleanup interrupted
# - test interrupted, cleanup interrupted
########
testcase "user(SIGINT): test interrupted, cleanup not set up"
mktest test.sh 'echo start > test.log; sleep 10; echo end >> test.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -INT -P $!  # $! is the '+' function, parent of tw.py
wait
+ grep 'start' test.log || fail
+ grep 'end' test.log && fail  # test is supposed to be killed before end!
rm -f test.sh test.log

########
testcase "user(SIGINT): test interrupted, cleanup successful"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo start > test.log; sleep 10; echo end >> test.log'
mktest cleanup.sh 'echo end > cleanup.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -INT -P $!
wait
+ grep 'start' test.log || fail
+ grep 'end' test.log && fail
+ grep 'end' cleanup.log || fail
rm -f test.sh test.log cleanup.sh cleanup.log

########
testcase "user(SIGINT): test successful, cleanup interrupted"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo end > test.log'
mktest cleanup.sh 'echo start > cleanup.log; sleep 10; echo end >> cleanup.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -INT -P $!
wait
+ grep 'end' test.log || fail
+ grep 'start' cleanup.log || fail
+ grep 'end' cleanup.log && fail  # cleanup is supposed to be killed
rm -f test.sh test.log cleanup.sh cleanup.log

########
testcase "user(SIGINT): test interrupted, cleanup interrupted"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo start > test.log; sleep 10; echo end >> test.log'
mktest cleanup.sh 'echo start > cleanup.log; sleep 10; echo end >> cleanup.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -INT -P $!
sleep 1
+ pkill -INT -P $!
wait
+ grep 'start' test.log || fail
+ grep 'end' cleanup.log && fail
+ grep 'start' cleanup.log || fail
+ grep 'end' cleanup.log && fail
rm -f test.sh test.log cleanup.sh cleanup.log

#
# beaker-controlled (beah) scenarios (SIGHUP/SIGTERM):
# - test successful,  cleanup successful, LWD expired during cleanup
# - test interrupted (LWD), cleanup not set up
# - test interrupted (LWD), cleanup successful
# - test successful,  cleanup interrupted (EWD)
# - test interrupted (LWD), cleanup interrupted (EWD)
########
testcase "beah(SIGHUP): test successful, cleanup successful, LWD during cleanup"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo end > test.log'
mktest cleanup.sh 'echo start > cleanup.log; sleep 2; echo end >> cleanup.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -HUP -P $!  # only schedules EWD kill in 1 more sec
wait
+ grep 'end' test.log || fail
+ grep 'start' cleanup.log || fail
+ grep 'end' cleanup.log || fail
rm -f test.sh test.log cleanup.sh cleanup.log

########
testcase "beah(SIGHUP): test interrupted (LWD), cleanup not set up"
mktest test.sh 'echo start > test.log; sleep 10; echo end >> test.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -HUP -P $!
wait
+ grep 'start' test.log || fail
+ grep 'end' test.log && fail
rm -f test.sh test.log

########
testcase "beah(SIGHUP): test interrupted (LWD), cleanup successful"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo start > test.log; sleep 10; echo end >> test.log'
mktest cleanup.sh 'echo end > cleanup.log'
+ ./testwatcher.py ./test.sh &
sleep 1
+ pkill -HUP -P $!
wait
+ grep 'start' test.log || fail
+ grep 'end' test.log && fail
+ grep 'end' cleanup.log || fail
rm -f test.sh test.log cleanup.sh cleanup.log

########
testcase "beah(SIGHUP): test successful, cleanup interrupted (EWD)"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo end > test.log'
mktest cleanup.sh 'echo start > cleanup.log; sleep 10; echo end >> cleanup.log'
TESTWATCHER_EWD_SECS=1 + ./testwatcher.py ./test.sh &
sleep 1
+ pkill -HUP -P $!  # only schedules EWD kill in 1 more sec
wait
+ grep 'end' test.log || fail
+ grep 'start' cleanup.log || fail
+ grep 'end' cleanup.log && fail
rm -f test.sh test.log cleanup.sh cleanup.log

########
testcase "beah(SIGHUP): test interrupted (LWD), cleanup interrupted (EWD)"
mktest test.sh 'echo ./cleanup.sh > "$TESTWATCHER_CLPATH"' \
               'echo start > test.log; sleep 10; echo end >> test.log'
mktest cleanup.sh 'echo start > cleanup.log; sleep 10; echo end >> cleanup.log'
TESTWATCHER_EWD_SECS=1 + ./testwatcher.py ./test.sh &
sleep 1
+ pkill -HUP -P $!
#sleep 1
#+ pkill -HUP -P $! testwatcher.py  # not needed, first HUP scheduled EWD kill
wait
+ grep 'start' test.log || fail
+ grep 'end' cleanup.log && fail
+ grep 'start' cleanup.log || fail
+ grep 'end' cleanup.log && fail
rm -f test.sh test.log cleanup.sh cleanup.log



################################################################################

echo
echo
echo "=========="
echo "FAILED: $FAILED"
exit $FAILED

# vim: sts=4 sw=4 et :
