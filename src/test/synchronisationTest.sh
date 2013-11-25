#!/bin/bash
# Copyright (c) 2013 Red Hat, Inc. All rights reserved. This copyrighted material
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Hubert Kario <hkario@redhat.com>

test_rlWaitForSocketPositive() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 5; nc -l 12345 > $test_dir/out) &
    local bg_pid=$!

    silentIfNotDebug "rlWaitForSocket 12345"
    local ret=$?
    assertTrue "Check if rlWaitForSocket return 0 when socket is opened" "[[ $ret -eq 0 ]]"

    silentIfNotDebug "echo 'hello world' | nc localhost 12345"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2

    assertTrue "Check if data was transferred" "grep 'hello world' $test_dir/out"

    rm -rf $test_dir
}

test_rlWaitForSocketClose() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (nc -l 12345 > $test_dir/out) &
    local bg_pid=$!

    (sleep 5; kill $bg_pid)&

    silentIfNotDebug "rlWaitForSocket 12345"
    local ret=$?
    assertTrue "Check if rlWaitForSocket return 0 when socket is opened" "[[ $ret -eq 0 ]]"

    silentIfNotDebug "echo 'hello world' | nc localhost 12345"

    silentIfNotDebug "rlWaitForSocket 12345 --close"
    local ret=$?
    assertTrue "Check if rlWaitForSocket return 0 when socket is closed" "[[ $ret -eq 0 ]]"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2

    assertTrue "Check if data was transferred" "grep 'hello world' $test_dir/out"

    rm -rf $test_dir
}

test_rlWaitForSocketTimeoutReached() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 10; nc -l 12345 > $test_dir/out) &
    local bg_pid=$!

    silentIfNotDebug "rlWaitForSocket -t 2 12345"
    local ret=$?
    assertTrue "Check if rlWaitForSocket returns 1 on reaching timeout" "[[ $ret -eq 1 ]]"

    silentIfNotDebug "echo 'hello world' | nc localhost 12345"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2

    assertFalse "Check if data was not transferred" "grep 'hello world' $test_dir/out || false"

    rm -rf $test_dir
}

test_rlWaitForSocketPIDKilled() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 10) &
    local bg_pid=$!
    (sleep 15; touch $test_dir/mark) &
    local bg2_pid=$!

    silentIfNotDebug "rlWaitForSocket -p $bg_pid 12345"
    local ret=$?
    assertTrue "Check if rlWaitForSocket returns 1 on PID exit" "[[ $ret -eq 1 ]]"

    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if rlWaitForSocket returned quickly after PID died" "[[ ! -e $test_dir/mark ]]"

    silentIfNotDebug "echo 'hello world' | nc localhost 12345"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2

    assertFalse "Check if data was not transferred" "grep 'hello world' $test_dir/out || false"

    rm -rf $test_dir
}

test_rlWaitForFilePositive() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 5; touch ${test_dir}/file)&
    local bg_pid=$!
    (sleep 10; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    silentIfNotDebug "rlWaitForFile $test_dir/file"
    local ret=$?
    assertTrue "Check if rlWaitForFile returned 0" "[[ $ret -eq 0 ]]"

    assertTrue "Check if file exists" "[[ -e $test_dir/file ]]"

    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if rlWaitForFile returned quickly after file was created" "[[ ! -e $test_dir/mark ]]"

    rm -rf $test_dir
}

test_rlWaitForFileNegative() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 5; touch ${test_dir}/file)&
    local bg_pid=$!
    (sleep 10; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    silentIfNotDebug "rlWaitForFile -t 2 $test_dir/file"
    local ret=$?
    assertTrue "Check if rlWaitForFile returned 1" "[[ $ret -eq 1 ]]"

    assertTrue "Check if file does not exists" "[[ ! -e $test_dir/file ]]"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2
    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if rlWaitForFile returned quickly after file was created" "[[ ! -e $test_dir/mark ]]"

    rm -rf $test_dir
}

test_rlWaitForFilePIDKilled() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 2)&
    local bg_pid=$!
    (sleep 5; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    silentIfNotDebug "rlWaitForFile -p $bg_pid $test_dir/file"
    local ret=$?
    assertTrue "Check if rlWaitForFile returned 1" "[[ $ret -eq 1 ]]"

    assertTrue "Check if file does not exists" "[[ ! -e $test_dir/file ]]"

    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2
    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if rlWaitForFile returned quickly after file was created" "[[ ! -e $test_dir/mark ]]"

    rm -rf $test_dir
}

test_rlWaitForCmdPositive() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    touch ${test_dir}/file
    (sleep 5; echo mark > ${test_dir}/file)&
    local bg_pid=$!
    (sleep 10; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file exists" "[[ -e $test_dir/file ]]"
    assertFalse "Check if doesn't contain 'mark' string" "grep mark $test_dir/file"

    silentIfNotDebug "rlWaitForCmd 'grep mark $test_dir/file'"
    local ret=$?
    assertTrue "Check if rlWaitForCmd returned 0" "[[ $ret -eq 0 ]]"

    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if file contains 'mark' string" "grep mark $test_dir/file"
    assertTrue "Check if rlWaitForCmd returned quickly" "[[ ! -e $test_dir/mark ]]"

    rm -rf $test_dir
}

test_rlWaitForCmdMaxInvoc() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 10; echo mark > ${test_dir}/file)&
    local bg_pid=$!
    (sleep 15; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    silentIfNotDebug "rlWaitForCmd 'echo line >> $test_dir/counter; grep mark $test_dir/file 2>/dev/null' -m 4"
    local ret=$?
    assertTrue "Check if rlWaitForCmd returned 1" "[[ $ret -eq 1 ]]"

    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2
    kill -s SIGKILL $bg_pid 2>/dev/null 1>&2
    wait $bg_pid 2>/dev/null 1>&2

    assertTrue "Check if WaitForCmd returned quickly" "[[ ! -e $test_dir/mark ]]"
    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    local lines=$(wc -l < $test_dir/counter)
    assertTrue "Check if the command was executed 4 times" "[[ $lines -eq 4 ]]"

    rm -rf $test_dir
}

test_rlWaitForCmdDelay() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 4; echo mark > ${test_dir}/file)&
    local bg_pid=$!
    (sleep 15; touch ${test_dir}/mark)&
    local bg2_pid=$!

    assertTrue "Check if file does not exist" "[[ ! -e $test_dir/file ]]"

    silentIfNotDebug "rlWaitForCmd 'echo line >> $test_dir/counter; grep mark $test_dir/file 2>/dev/null' -d 6"
    local ret=$?
    assertTrue "Check if rlWaitForCmd returned 0" "[[ $ret -eq 0 ]]"

    kill -s SIGKILL $bg2_pid 2>/dev/null 1>&2
    wait $bg2_pid 2>/dev/null 1>&2

    assertTrue "Check if WaitForCmd returned quickly" "[[ ! -e $test_dir/mark ]]"
    assertTrue "Check if file does exist" "[[ -e $test_dir/file ]]"

    local lines=$(wc -l < $test_dir/counter)
    assertTrue "Check if the command was executed 2 times" "[[ $lines -eq 2 ]]"
    # two executions because the command is executed first, then sleep

    rm -rf $test_dir
}

test_rlWaitPositive() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 4; touch ${test_dir}/file; exit 4)&

    rlWait $!
    ret=$?

    assertTrue "Check if background task executed correctly" "[[ -e ${test_dir}/file ]]"
    assertTrue "Check if returned value comes from background task" "[[ $ret -eq 4 ]]"

    rm -rf $test_dir
}

test_rlWaitNoPIDs() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 4; touch ${test_dir}/file; exit 4)&

    rlWait
    ret=$?

    assertTrue "Check if background task executed correctly" "[[ -e ${test_dir}/file ]]"
    # when you `wait' for all tasks (no id specified), then wait always returns 0
    assertTrue "Check if returned value is correct" "[[ $ret -eq 0 ]]"

    rm -rf $test_dir
}

test_rlWaitNegative() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 20; touch ${test_dir}/file; exit 4)&

    rlWait $! -t 1
    ret=$?

    assertTrue "Check if background task didn't execute" "[[ ! -e ${test_dir}/file ]]"
    assertTrue "Check if returned value indicates the task was killed" "[[ $ret -eq $((128+15)) ]]"

    rm -rf $test_dir
}

test_rlWaitKill() {
    local test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)

    (sleep 20; touch ${test_dir}/file; exit 4)&

    rlWait $! -t 1 -s SIGKILL
    ret=$?

    assertTrue "Check if background task didn't execute" "[[ ! -e ${test_dir}/file ]]"
    assertTrue "Check if returned value indicates the task was killed by custom signal" "[[ $ret -eq $((128+9)) ]]"

    rm -rf $test_dir
}
