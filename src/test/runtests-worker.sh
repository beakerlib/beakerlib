#!/bin/bash
# We need to export the variables out of the oneTimeSetUp function
export BEAKERLIB=/home/afri/qa/beakerlib/src/test/'..'
export TEST='/CoreOS/distribution/beakerlib/unit-tests'
export OUTPUTFILE="/tmp/tmp.5B6Ihhh0lz"
export RECIPEID='123'
export TESTID='123456'

#include usefull functions
. library.sh

#mock report_result
report_result(){
 true;
}

oneTimeSetUp() {
  # Source script we are going to test
  . ../beakerlib.sh
  set +u
  rlJournalStart
  return 0
}
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Jan Hutar <jhutar@redhat.com>

test_BEAKERLIBVariableNotNull() {
  assertNotNull "BEAKERLIB variable is empty" "$BEAKERLIB"
}

test_BEAKERLIBVariableSane() {
  assertTrue "BEAKERLIB points to the non existing directory" "[ -d '$BEAKERLIB' ]"
}
#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Ales Zelinka <azelinka@redhat.com>

#tries to find test for every existing rl-function
test_coverage(){
	TEST_SCRIPTS=`ls *Test.sh|grep -v coverageTest.sh`
	#doesn't work with redirection, must use temp file instead
	declare -f |grep '^rl.* ()' |grep -v '^rlj'|cut -d ' ' -f 1 >fnc.list
	while read FUNCTION ; do
		assertTrue "function $FUNCTION found in testsuite" "grep -q $FUNCTION $TEST_SCRIPTS"
	done < fnc.list
	rm -f fnc.list
}
#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Petr Splichal <psplicha@redhat.com>

#
# rlFileBackup & rlFileRestore unit test
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# this test has to be run as root
# [to restore ownership, permissions and attributes]
# run with DEBUG=1 to get more details about progress

BackupSanityTest() {
    # detect selinux & acl support
    [ -d "/selinux" ] && local selinux=true || local selinux=false
    setfacl -m u:root:rwx $BEAKERLIB_DIR &>/dev/null \
            && local acl=true || local acl=false
    [ -d "$BEAKERLIB_DIR" ] && chmod -R 777 "$BEAKERLIB_DIR" \
            && rm -rf "$BEAKERLIB_DIR" && rlJournalStart
    score=0

    list() {
        ls -ld --full-time directory
        ls -lL --full-time directory
        $acl && getfacl -R directory
        $selinux && ls -Z directory
        cat directory/content
    }

    mess() {
        echo -e "\nBackupSanityTest: $1"
    }

    fail() {
        echo "BackupSanityTest FAIL: $1"
        ((score++))
    }

    # setup
    tmpdir=`mktemp -d /tmp/backup-test-XXXXXXX`
    pushd $tmpdir >/dev/null

    # create files
    mkdir directory
    pushd directory >/dev/null
    mkdir -p sub/sub/dir
    mkdir 'dir with spaces'
    mkdir 'another dir with spaces'
    touch file permissions ownership times context acl
    echo "hello" >content
    ln file hardlink
    ln -s file softlink
    chmod 750 permissions
    chown nobody.nobody ownership
    touch --reference /var/www times
    $acl && setfacl -m u:root:rwx acl
    $selinux && chcon --reference /var/www context
    popd >/dev/null

    # save details and backup
    list >original
    mess "Doing the backup"
    rlFileBackup directory || fail "Backup"

    # remove completely
    mess "Testing restore after complete removal "
    rm -rf directory
    rlFileRestore || fail "Restore after complete removal"
    list >removal
    diff original removal || fail "Restore after complete removal not ok, differences found"

    # remove some, change content
    mess "Testing restore after partial removal"
    rm -rf directory/sub/sub directory/hardlink directory/permissions 'dir with spaces'
    echo "hi" >directory/content
    rlFileRestore || fail "Restore after partial removal"
    list >partial
    diff original partial || fail "Restore after partial removal not ok, differences found"

    # attribute changes
    mess "Testing restore after attribute changes"
    pushd directory >/dev/null
    chown root ownership
    chown nobody file
    touch times
    chmod 777 permissions
    $acl && setfacl -m u:root:---
    $selinux && chcon --reference /home context
    popd >/dev/null
    rlFileRestore || fail "Restore attributes"
    list >attributes
    diff original attributes || fail "Restore attributes not ok, differences found"

    # acl check for correct path restore
    if $acl; then
        mess "Checking that path ACL is correctly restored"
        # create acldir with modified ACL
        pushd directory >/dev/null
        mkdir acldir
        touch acldir/content
        setfacl -m u:root:--- acldir
        popd >/dev/null
        list >original
        # backup it's contents (not acldir itself)
        rlFileBackup directory/acldir/content
        rm -rf directory/acldir
        # restore & check for differences
        rlFileRestore || fail "Restore path ACL"
        list >acl
        diff original acl || fail "Restoring correct path ACL not ok"
    fi

    # clean up
    popd >/dev/null
    rm -rf $tmpdir

    mess "Total score: $score"
    return $score
}


test_rlFileBackupAndRestore() {
    assertFalse "rlFileRestore should fail when no backup was done" \
        'rlFileRestore'
    assertTrue "rlFileBackup should fail and return 2 when no file/dir given" \
        'rlFileBackup; [ $? == 2 ]'
    assertFalse "rlFileBackup should fail when given file/dir does not exist" \
        'rlFileBackup i-do-not-exist'

    if [ "$DEBUG" == "1" ]; then
        BackupSanityTest
    else
        BackupSanityTest >/dev/null 2>&1
    fi
    assertTrue "rlFileBackup & rlFileRestore sanity test (needs to be root to run this)" $?
    chmod -R 777 "$BEAKERLIB_DIR/backup" && rm -rf "$BEAKERLIB_DIR/backup"
}

test_rlFileBackupCleanAndRestore() {
    test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX)
    date > "$test_dir/date1"
    date > "$test_dir/date2"
    if [ "$DEBUG" == "1" ]; then
        rlFileBackup --clean "$test_dir"
    else
        rlFileBackup --clean "$test_dir" >/dev/null 2>&1
    fi
    rm -f "$test_dir/date1"   # should be restored
    date > "$test_dir/date3"   # should be removed
    ###tree "$test_dir"
    if [ "$DEBUG" == "1" ]; then
        rlFileRestore
    else
        rlFileRestore >/dev/null 2>&1
    fi
    ###tree "$test_dir"
    assertTrue "rlFileBackup with '--clean' option adds" \
        "ls '$test_dir/date1'"
    assertFalse "rlFileBackup with '--clean' option removes" \
        "ls '$test_dir/date3'"
    chmod -R 777 "$BEAKERLIB_DIR/backup" && rm -rf "$BEAKERLIB_DIR/backup"
}

test_rlFileBackupCleanAndRestoreWhitespace() {
    test_dir=$(mktemp -d '/tmp/beakerlib-test-XXXXXX')
    mkdir "$test_dir/noclean"
    mkdir "$test_dir/noclean clean"
    mkdir "$test_dir/aaa"
    date > "$test_dir/noclean/date1"
    date > "$test_dir/noclean clean/date2"
    if [ "$DEBUG" == "1" ]; then
        rlFileBackup "$test_dir/noclean"
        rlFileBackup --clean "$test_dir/noclean clean"
        rlFileBackup --clean "$test_dir/aaa"
    else
        rlFileBackup "$test_dir/noclean" >/dev/null 2>&1
        rlFileBackup --clean "$test_dir/noclean clean" >/dev/null 2>&1
    fi
    ###tree "$test_dir"
    date > "$test_dir/noclean/date3"   # this should remain
    date > "$test_dir/noclean clean/date4"   # this should be removed
    ###tree "$test_dir"
    if [ "$DEBUG" == "1" ]; then
        rlFileRestore
    else
        rlFileRestore >/dev/null 2>&1
    fi
    ###tree "$test_dir"
    assertTrue "rlFileBackup without '--clean' do not remove in dir with spaces" \
        "ls '$test_dir/noclean/date3'"
    assertFalse "rlFileBackup with '--clean' remove in dir with spaces" \
        "ls '$test_dir/noclean clean/date4'"
    chmod -R 777 "$BEAKERLIB_DIR/backup" && rm -rf "$BEAKERLIB_DIR/backup"
}



test_rlServiceStart() {
    assertTrue "rlServiceStart should fail and return 99 when no service given" \
        'rlServiceStart; [ $? == 99 ]'
    assertTrue "rlServiceStop should fail and return 99 when no service given" \
        'rlServiceStart; [ $? == 99 ]'
    assertTrue "rlServiceRestore should fail and return 99 when no service given" \
        'rlServiceStart; [ $? == 99 ]'

    assertTrue "down-starting-pass" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlRun "rlServiceStart down-starting-pass"'

    assertTrue "down-starting-ok" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart down-starting-ok'

    assertTrue "up-starting-ok" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart up-starting-ok'

    assertTrue "weird-starting-ok" \
        'service() { case $2 in status) return 33;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart weird-starting-ok'

    assertFalse "up-starting-stop-ko" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 1;; esac; };
        rlServiceStart up-starting-stop-ko'

    assertFalse "up-starting-stop-ok-start-ko" \
        'service() { case $2 in status) return 0;; start) return 1;; stop) return 0;; esac; };
        rlServiceStart up-starting-stop-ok-start-ko'

    assertFalse "down-starting-start-ko" \
        'service() { case $2 in status) return 3;; start) return 1;; stop) return 0;; esac; };
        rlServiceStart down-starting-start-ko'

    assertFalse "weird-starting-start-ko" \
        'service() { case $2 in status) return 33;; start) return 1;; stop) return 0;; esac; };
        rlServiceStart weird-starting-start-ko'
}

test_rlServiceStop() {
    assertTrue "down-stopping-ok" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop down-stopping-ok'

    assertTrue "up-stopping-ok" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop up-stopping-ok'

    assertTrue "weird-stopping-ok" \
        'service() { case $2 in status) return 33;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop weird-stopping-ok'

    assertFalse "up-stopping-stop-ko" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 1;; esac; };
        rlServiceStop up-stopping-stop-ko'
}

test_rlServiceRestore() {
    assertTrue "was-down-is-down-ok" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop was-down-is-down-ok;
        service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceRestore was-down-is-down-ok'

    assertTrue "was-down-is-up-ok" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart was-down-is-up-ok;
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceRestore was-down-is-up-ok'

    assertTrue "was-up-is-down-ok" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop was-up-is-down-ok;
        service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceRestore was-up-is-down-ok'

    assertTrue "was-up-is-up-ok" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart was-up-is-up-ok;
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceRestore was-up-is-up-ok'

    assertFalse "was-up-is-up-stop-ko" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 1;; esac; };
        rlServiceStart was-up-is-up-stop-ko;
        service() { case $2 in status) return 0;; start) return 0;; stop) return 1;; esac; };
        rlServiceRestore was-up-is-up-stop-ko'

    assertFalse "was-down-is-up-stop-ko" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 1;; esac; };
        rlServiceStart was-down-is-up-stop-ko;
        service() { case $2 in status) return 0;; start) return 0;; stop) return 1;; esac; };
        rlServiceRestore was-down-is-up-stop-ko'

    assertFalse "was-up-is-down-start-ko" \
        'service() { case $2 in status) return 0;; start) return 1;; stop) return 0;; esac; };
        rlServiceStop was-up-is-down-start-ko;
        service() { case $2 in status) return 3;; start) return 1;; stop) return 0;; esac; };
        rlServiceRestore was-up-is-down-start-ko'

    assertFalse "was-up-is-up-start-ko" \
        'service() { case $2 in status) return 0;; start) return 1;; stop) return 0;; esac; };
        rlServiceStart was-up-is-up-start-ko;
        service() { case $2 in status) return 0;; start) return 1;; stop) return 0;; esac; };
        rlServiceRestore was-up-is-up-start-ko'
}


#FIXME: no idea how to really test these mount function
MP="beakerlib-test-mount-point"
[ -d "$MP" ] && rmdir "$MP"

test_rlMount(){
    mkdir "$MP"
    mount() { return 0 ; }
    assertTrue "rlMount returns 0 when internal mount succeeds" \
    "mount() { return 0 ; } ; rlMount server remote_dir $MP"
    assertFalse "rlMount returns 1 when internal mount doesn't succeeds" \
    "mount() { return 4 ; } ; rlMount server remote_dir $MP"
    rmdir "$MP"
}

test_rlMountAny(){
    assertTrue "rlmountAny is marked as deprecated" \
    "rlMountAny server remotedir $MP |grep -q deprecated "
}

test_rlAnyMounted(){
    assertTrue "rlAnymounted is marked as deprecated" \
    "rlAnyMounted server remotedir $MP |grep -q deprecated "
}

test_rlCheckMount(){
    [ -d "$MP" ] && rmdir "$MP"
    assertFalse "rlCheckMount returns non-0 on no-existing mount point" \
    "rlCheckMount server remotedir $MP"
}
test_rlAssertMount(){
    mkdir "$MP"
    __one_fail_one_pass "rlAssertMount server remote-dir $MP" "FAIL"
    assertFalse "rlAssertMount without paramaters doesn't succeed" \
    "rlAssertMount"
}


#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Authors:
#   Ales Zelinka <azelinka@redhat.com>
#   Petr Splichal <psplicha@redhat.com>

test_rlJournalStart(){
    [ -f $BEAKERLIB_JOURNAL ] && rm $BEAKERLIB_JOURNAL
    assertTrue "run id set" "[ -n '$BEAKERLIB_RUN' ]"
    assertTrue "journal started" "rlJournalStart"
    assertTrue "directory set & created" "[ -d $BEAKERLIB_DIR ]"
    assertTrue "journal file created" "[ -f $BEAKERLIB_JOURNAL ]"
    assertTrue "journal is well-formed XML" "xmllint $BEAKERLIB_JOURNAL >/dev/null"

    # existing journal is not overwritten
    rlLog "I am" &> /dev/null
    rlJournalStart
    assertTrue "existing journal not overwritten" \
            "grep 'I am' $BEAKERLIB_JOURNAL"

    # unless TESTID set a new random BeakerLib directory should be created
    local OLDTESTID=$TESTID
    local OLDDIR=$BEAKERLIB_DIR
    local OLDJOURNAL=$BEAKERLIB_JOURNAL
    unset TESTID
    rlJournalStart
    assertTrue "A new random dir created when no TESTID available" \
            "[ '$OLDDIR' != '$BEAKERLIB_DIR' -a -d $BEAKERLIB_DIR ]"
    assertTrue "A new journal created in random directory" \
            "[ '$OLDJOURNAL' != '$BEAKERLIB_JOURNAL' -a -f $BEAKERLIB_JOURNAL ]"
    rm -rf $BEAKERLIB_DIR
    export TESTID=$OLDTESTID
}

test_rlJournalPrint(){
    #add something to journal
    rlJournalStart
    rlPhaseStart FAIL       &> /dev/null
    rlAssert0 "failed" 1    &> /dev/null
    rlAssert0 "passed" 0    &> /dev/null
    rlPhaseEnd              &> /dev/null
    rlLog "loginek"         &> /dev/null
    assertTrue "rlJournalPrint dump is wellformed xml" \
            "rlJournalPrint |xmllint -"
    assertTrue "rlPrintJournal dump still works" \
            "rlPrintJournal | grep -v 'rlPrintJournal is obsoleted by rlJournalPrint' | xmllint -"
    assertTrue "rlPrintJournal emits obsolete warnings" \
            "rlPrintJournal | grep 'rlPrintJournal is obsoleted by rlJournalPrint' -q"
    rm -rf $BEAKERLIB_DIR
}

test_rlJournalPrintText(){
    #this fnc is used a lot in other function's tests
    #so here goes only some specific (regression?) tests

    #must not tracedump on an empty log message
    rlJournalStart          &> /dev/null
    #outside-of-phase log
    rlLog ""                &> /dev/null
    rlPhaseStart FAIL       &> /dev/null
    #inside-phase log
    rlLog ""                &> /dev/null
    assertFalse "no traceback during log creation" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rm -rf $BEAKERLIB_DIR

    #no traceback on non-ascii characters (bz471257)
    rlJournalStart
    rlPhaseStart FAIL               &> /dev/null
    rlLog "ščřžýáíéーれっどはっと"  &> /dev/null
    assertFalse "no traceback on non-ascii chars (unicode support)" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rm -rf $BEAKERLIB_DIR

    # no traceback on non-xml garbage
    rlJournalStart
    rlPhaseStart FAIL       &> /dev/null
    rlLog "`echo $'\x00'`"  &> /dev/null
    assertFalse "no traceback on non-xml characters [1]" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rlLog "`echo $'\x0c'`"  &> /dev/null
    assertFalse "no traceback on non-xml characters [2]" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rlLog "`echo $'\x1F'`"  &> /dev/null
    assertFalse "no traceback on non-xml characters [3]" \
            "rlJournalPrintText 2>&1 | grep Traceback"
    rm -rf $BEAKERLIB_DIR

    # multiline logs
    rlJournalStart
    rlLog "`echo -e 'line1\nline2'`" &> /dev/null
    rlJournalPrintText | grep -v "line2" | grep -q "LOG.*line1" &&
            rlJournalPrintText | grep -v "line1" | grep -q "LOG.*line2"
    assertTrue "multiline logs tagged on each line" "[ $? -eq 0 ]"
    rm -rf $BEAKERLIB_DIR
}
#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Jan Hutar <jhutar@redhat.com>

__testLogFce() {
  # This should help us to test various logging functions
  # which takes <message> and optional <logfile> parameters
  rlJournalStart
  local log=$( mktemp )
  local myfce=$1
  $myfce "MessageABC" &>/dev/null
  assertTrue "rlHeadLog to OUTPUTFILE" "grep -q 'MessageABC' $OUTPUTFILE"
  rm -f $log   # remove the log, so it have to be created
  $myfce "MessageDEF" $log &>/dev/null
  assertTrue "rlHeadLog to nonexisting log" "grep -q 'MessageDEF' $log"
  touch $log   # create the log if it still do not exists
  $myfce "MessageGHI" $log &>/dev/null
  assertTrue "rlHeadLog to existing log" "grep -q 'MessageGHI' $log"
  $myfce "MessageJKL" $log &>/dev/null
  assertTrue "rlHeadLog only adds to the log (do not overwrite it)" "grep -q 'MessageGHI' $log"
  assertTrue "rlHeadLog adds to the log" "grep -q 'MessageJKL' $log"
  assertTrue "$myfce logs to STDOUT" "$myfce $myfce-MNO |grep -q '$myfce-MNO'"
  assertTrue "$myfce creates journal entry" "rlJournalPrint |grep -q '$myfce-MNO'"
}

test_rlHeadLog() {
  __testLogFce rlHeadLog
}

test_rlLog() {
  __testLogFce rlLog
}
test_rlLogDebug() {
  #only works when DEBUG is set
  DEBUG=1
  __testLogFce rlLogDebug
  DEBUG=0
}
test_rlLogInfo() {
  __testLogFce rlLogInfo
}
test_rlLogWarning() {
  __testLogFce rlLogWarning
}
test_rlLogError() {
  __testLogFce rlLogError
}
test_rlLogFatal() {
  __testLogFce rlLogFatal
}

test_rlDie(){
	#dunno how to test this - it contains untestable helpers like rlBundleLogs and rlReport
	echo "rlDie skipped"
}

test_rlPhaseStartEnd(){
  rlJournalStart ; rlPhaseStart FAIL    &> /dev/null
  #counting passes and failures
  rlAssert0 "failed assert #1" 1        &> /dev/null
  rlAssert0 "successfull assert #1" 0   &> /dev/null
  rlAssert0 "failed assert #2" 1        &> /dev/null
  rlAssert0 "successfull assert #2" 0   &> /dev/null
  assertTrue "passed asserts were stored" "rlJournalPrintText |grep '2 good'"
  assertTrue "failed asserts were stored" "rlJournalPrintText |grep '2 bad'"
  #new phase resets score
  rlPhaseEnd &> /dev/null ; rlPhaseStart FAIL &> /dev/null
  assertTrue "passed asserts were reseted" "rlJournalPrintText |grep '0 good'"
  assertTrue "failed asserts were reseted" "rlJournalPrintText |grep '0 bad'"

  assertFalse "creating phase without type doesn't succeed" "rlPhaseEnd ; rlPhaseStart &> /dev/null"
  assertFalse "phase without type is not inserted into journal" "rlJournalPrint |grep -q '<phase.*type=\"\"'"
  assertFalse "creating phase with unknown type doesn't succeed" "rlPhaseEnd ; rlPhaseStart ZBRDLENI &> /dev/null"
  assertFalse "phase with unknown type is not inserted into journal" "rlJournalPrint |grep -q '<phase.*type=\"ZBRDLENI\"'"
  rm -rf $BEAKERLIB_DIR
}

test_rlPhaseStartShortcuts(){
  rlJournalStart
  rlPhaseStartSetup &> /dev/null
  assertTrue "setup phase with ABORT type found in journal" "rlJournalPrint |grep -q '<phase.*type=\"ABORT\"'"
  rm -rf $BEAKERLIB_DIR

  rlJournalStart
  rlPhaseStartTest &> /dev/null
  assertTrue "test phase with FAIL type found in journal" "rlJournalPrint |grep -q '<phase.*type=\"FAIL\"'"
  rm -rf $BEAKERLIB_DIR

  rlJournalStart
  rlPhaseStartCleanup &> /dev/null
  assertTrue "clean-up phase with WARN type found in journal" "rlJournalPrint |grep -q '<phase.*type=\"WARN\"'"
  rm -rf $BEAKERLIB_DIR
}

test_oldMetrics(){
    assertTrue "rlLogHighMetric is marked as deprecated" \
        "rlLogHighMetric MTR-HIGH-OLD 1 |grep -q deprecated"
    assertTrue "rlLogLowMetric is marked as deprecated" \
        "rlLogLowMetric MTR-LOW-OLD 1 |grep -q deprecated"
}
test_rlShowPkgVersion(){
    assertTrue "rlShowPkgVersion is marked as deprecated" \
        "rlShowPkgVersion |grep -q obsoleted"
}


test_LogMetricLowHigh(){
    rlJournalStart ; rlPhaseStart FAIL &> /dev/null
    assertTrue "low metric inserted to journal" "rlLogMetricLow metrone 123 "
    assertTrue "high metric inserted to journal" "rlLogMetricHigh metrtwo 567"
    assertTrue "low metric found in journal" "rlJournalPrint |grep -q '<metric.*name=\"metrone\".*type=\"low\"'"
    assertTrue "high metric found in journal" "rlJournalPrint |grep -q '<metric.*name=\"metrtwo\".*type=\"high\"'"

    #second metric called metrone - must not be inserted to journal
    rlLogMetricLow metrone 345
    assertTrue "metric insertion fails when name's not unique inside one phase" \
            "[ `rlJournalPrint | grep -c '<metric.*name=.metrone.*type=.low.'` -eq 1 ]"
    rm -rf $BEAKERLIB_DIR

    #same name of metric but in different phases - must work
    rlJournalStart ; rlPhaseStartTest phase-1 &> /dev/null
    rlLogMetricLow metrone 345
    rlPhaseEnd &> /dev/null ; rlPhaseStartTest phase-2 &> /dev/null
    rlLogMetricLow metrone 345
    assertTrue "metric insertion succeeds when name's not unique but phases differ" \
            "[ `rlJournalPrint | grep -c '<metric.*name=.metrone.*type=.low.'` -eq 2 ]"
}

test_rlShowRunningKernel(){
	rlJournalStart; rlPhaseStart FAIL &> /dev/null
	rlShowRunningKernel &> /dev/null
	assertTrue "kernel version is logged" "rlJournalPrintText |grep -q `uname -r`"
}

__checkLoggedPkgInfo() {
  local log=$1
  local msg=$2
  local name=$3
  local version=$4
  local release=$5
  local arch=$6
  assertTrue "rlShowPackageVersion logs name $msg" "grep -q '$name' $log"
  assertTrue "rlShowPackageVersion logs version $msg" "grep -q '$version' $log"
  assertTrue "rlShowPackageVersion logs release $msg" "grep -q '$release' $log"
  assertTrue "rlShowPackageVersion logs arch $msg" "grep -q '$arch' $log"
}

test_rlShowPackageVersion() {
  local log=$( mktemp )
  local list=$( mktemp )

  # Exit value shoud be defined
  assertFalse "rlShowPackageVersion calling without options" "rlShowPackageVersion"
  : >$OUTPUTFILE

  rpm -qa --qf "%{NAME}\n" > $list
  local first=$( tail -n 1 $list )
  local first_n=$( rpm -q $first --qf "%{NAME}\n" | tail -n 1 )
  local first_v=$( rpm -q $first --qf "%{VERSION}\n" | tail -n 1 )
  local first_r=$( rpm -q $first --qf "%{RELEASE}\n" | tail -n 1 )
  local first_a=$( rpm -q $first --qf "%{ARCH}\n" | tail -n 1 )

  # Test with 1 package
  rlShowPackageVersion $first &>/dev/null
  __checkLoggedPkgInfo $OUTPUTFILE "of 1 pkg" $first_n $first_v $first_r $first_a
  : >$OUTPUTFILE

  # Test with package this_package_do_not_exist
  assertTrue 'rlShowPackageVersion returns 1 when package do not exists' 'rlShowPackageVersion this_package_do_not_exist; [ $? -eq 1 ]'   # please use "'" - we do not want "$?" to be expanded too early
  assertTrue 'rlShowPackageVersion logs warning about this_package_do_not_exist' "grep -q 'this_package_do_not_exist' $OUTPUTFILE"
  : >$OUTPUTFILE

  # Test with few packages
  local few=$( tail -n 10 $list )
  rlShowPackageVersion $few &>/dev/null
  for one in $few; do
    local one_n=$( rpm -q $one --qf "%{NAME}\n" | tail -n 1 )
    local one_v=$( rpm -q $one --qf "%{VERSION}\n" | tail -n 1 )
    local one_r=$( rpm -q $one --qf "%{RELEASE}\n" | tail -n 1 )
    local one_a=$( rpm -q $one --qf "%{ARCH}\n" | tail -n 1 )
    __checkLoggedPkgInfo $OUTPUTFILE "of few pkgs" $one_n $one_v $one_r $one_a
  done
  : >$OUTPUTFILE

  # Test with package this_package_do_not_exist
  assertTrue 'rlShowPackageVersion returns 1 when some packages do not exists' "rlShowPackageVersion this_package_do_not_exist $few this_package_do_not_exist_too; [ \$? -eq 1 ]"
  : >$OUTPUTFILE

  rm -f $list
}



test_rlGetArch() {
  local out=$(rlGetArch)
  assertTrue 'rlGetArch returns 0' "[ $? -eq 0 ]"
  [ "$out" = 'i386' ] && out='i.8.'   # funny reg exp here
  uname -a | grep -q "$out"
  assertTrue 'rlGetArch returns correct arch' "[ $? -eq 0 ]"
}

test_rlGetDistroRelease() {
  local out=$(rlGetDistroRelease)
  assertTrue 'rlGetDistroRelease returns 0' "[ $? -eq 0 ]"
  grep -q -i "$out" /etc/redhat-release
  assertTrue 'rlGetDistroRelease returns release which is in the /etc/redhat-release' "[ $? -eq 0 ]"
}

test_rlGetDistroVariant() {
  local out=$(rlGetDistroVariant)
  assertTrue 'rlGetDistroVariant returns 0' "[ $? -eq 0 ]"
  grep -q -i "$out" /etc/redhat-release
  assertTrue 'rlGetDistroRelease returns variant which is in the /etc/redhat-release' "[ $? -eq 0 ]"
}

test_rlBundleLogs() {
  local prefix=rlBundleLogs-unittest
  rm -rf $prefix* CP-$prefix*.tar.gz
  # Prepare files which will be backed up
  mkdir $prefix
  mkdir $prefix/first
  echo "hello" > $prefix/first/greet
  echo "world" > $prefix/first_greet
  export BEAKERLIB_COMMAND_SUBMIT_LOG=rhts_submit_log
  # Prepare fake rhts_submit_log utility

  cat <<EOF >$prefix/rhts_submit_log
#!/bin/sh
while [ \$# -gt 0 ]; do
  case "\$1" in
    -S|-T) shift; ;;
    -l) shift; cp "\$1" "CP-\`basename \$1\`";;
  esac
  shift
done
EOF
  chmod +x $prefix/rhts_submit_log
  PATH_orig="$PATH"
  export PATH="$( pwd )/$prefix:$PATH"
  # Run the rlBundleLogs function
  rlBundleLogs $prefix $prefix/first/greet $prefix/first_greet &> /dev/null
  assertTrue 'rlBundleLogs <some files> returns 0' "[ $? -eq 0 ]"
  export PATH="$PATH_orig"
  # Check if it did everithing it should
  assertTrue 'rlBundleLogs creates *.tar.gz file' \
        "ls CP-tmp-$prefix*.tar.gz"
  mkdir $prefix-extracted
  tar xzf CP-tmp-$prefix*.tar.gz -C $prefix-extracted
  assertTrue 'rlBundleLogs included first/greet file' \
        "grep -qr 'hello' $prefix-extracted/*"
  assertTrue 'rlBundleLogs included first_greet file' \
        "grep -qr 'world' $prefix-extracted/*"
  # Cleanup
  rm -rf $prefix* CP-tmp-$prefix*.tar.gz
}

test_LOG_LEVEL(){
	unset LOG_LEVEL
	unset DEBUG

	assertFalse "rlLogInfo msg not in journal dump with default LOG_LEVEL" \
	"rlLogInfo 'lllll' ; rlJournalPrintText |grep 'lllll'"

	assertTrue "rlLogWarning msg in journal dump with default LOG_LEVEL" \
	"rlLogWarning 'wwwwww' ; rlJournalPrintText |grep 'wwwww'"

	DEBUG=1
	assertTrue "rlLogInfo msg  in journal dump with default LOG_LEVEL but DEBUG turned on" \
	"rlLogInfo 'lllll' ; rlJournalPrintText |grep 'lllll'"
	unset DEBUG

	local LOG_LEVEL="INFO"
	assertTrue "rlLogInfo msg in journal dump with LOG_LEVEL=INFO" \
	"rlLogInfo 'lllll' ; rlJournalPrintText |grep 'lllll'"

	local LOG_LEVEL="WARNING"
	assertFalse "rlLogInfo msg not in journal dump with LOG_LEVEL higher than INFO" \
	"rlLogInfo 'lllll' ; rlJournalPrintText |grep 'lllll'"

	unset LOG_LEVEL
	unset DEBUG
}

test_rlFileSubmit() {
  local main_dir=`pwd`
  local prefix=rlFileSubmit-unittest
  local upload_to=$prefix/uploaded
  local hlp_files=$prefix/hlp_files
  mkdir -p $upload_to
  mkdir -p $hlp_files
  sync
  # Prepare fake rhts_submit_log utility
  cat <<EOF >$prefix/rhts_submit_log
#!/bin/sh
while [ \$# -gt 0 ]; do
  case "\$1" in
    -S|-T) shift; ;;
    -l) shift; cp "\$1" "$main_dir/$upload_to/";;
  esac
  shift
done
EOF
  export BEAKERLIB_COMMAND_SUBMIT_LOG=rhts_submit_log
  chmod +x $prefix/rhts_submit_log
  ln -s rhts_submit_log $prefix/rhts-submit-log
  PATH_orig="$PATH"
  export PATH="$( pwd )/$prefix:$PATH"

  # TEST 1: No relative or absolute path specified
  local orig_file="$hlp_files/rlFileSubmit_test1.file"
  local alias="rlFileSubmit_test1.file"
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test1" > $orig_file

  cd $hlp_files
  rlFileSubmit rlFileSubmit_test1.file &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs file without relative or absolute path specified' "[ $? -eq 0 ]"

  # TEST 2: Relative path ./
  local orig_file="$hlp_files/rlFileSubmit_test2.file"
  local alias=`echo "$main_dir/$orig_file" | tr '/' "-" | sed "s/^-*//"`
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test2" > $orig_file

  cd $hlp_files
  rlFileSubmit ./rlFileSubmit_test2.file &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs relative path ./' "[ $? -eq 0 ]"

  # TEST 3: Relative path ../
  mkdir -p $hlp_files/directory/
  local orig_file="$hlp_files/rlFileSubmit_test3.file"
  local alias=`echo "$main_dir/$orig_file" | tr '/' "-" | sed "s/^-*//"`
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test3" > $orig_file

  cd $hlp_files/directory
  rlFileSubmit ../rlFileSubmit_test3.file &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs relative path ../' "[ $? -eq 0 ]"

  # TEST 4: Absolute path
  local orig_file="$hlp_files/rlFileSubmit_test4.file"
  local alias=`echo "$main_dir/$orig_file" | tr '/' "-" | sed "s/^-*//"`
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test4" > $orig_file

  rlFileSubmit $main_dir/$orig_file &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs absolute path' "[ $? -eq 0 ]"

  # TEST 5: Custom alias
  local orig_file="$hlp_files/rlFileSubmit_test5file"
  local alias="alias_rlFileSubmit_test5.file"
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test5" > $orig_file

  rlFileSubmit $orig_file $alias &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs custom alias' "[ $? -eq 0 ]"

  # TEST 6: Custom separator
  local orig_file="$hlp_files/rlFileSubmit_test6.file"
  local alias=`echo "$main_dir/$orig_file" | tr '/' "_" | sed "s/^_*//"`
  local expected_file="$upload_to/$alias"

  echo "rlFileSubmit_test6" > $orig_file

  rlFileSubmit -s '_' $main_dir/$orig_file &> /dev/null

  cd $main_dir
  local sum1=`md5sum $orig_file | cut -d " " -f 1`
  local sum2=`md5sum $expected_file | cut -d " " -f 1`

  [ -e $expected_file -a  "$sum1" = "$sum2" ]
  assertTrue 'rlBundleLogs absolute path' "[ $? -eq 0 ]"

  rm -f /tmp/BEAKERLIB_STORED_rlFileSubmit_test1.file
  unset BEAKERLIB_COMMAND_SUBMIT_LOG
  cd $hlp_files

  rlFileSubmit rlFileSubmit_test1.file &> /dev/null
  assertTrue "rlFileSubmit default function RC" "[ $? -eq 0 ]"
  assertTrue "rlFileSubmit default function file submitted" "[ -e /tmp/BEAKERLIB_STORED_rlFileSubmit_test1.file ]"
  cd $main_dir

  # Cleanup
  export PATH="$PATH_orig"
  rm -rf $prefix*
}
#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Jan Hutar <jhutar@redhat.com>

test_rlAssertRpm() {
  local first=$( rpm -qa --qf "%{NAME}.%{ARCH}\n" | tail -n 1 )
  local first_n=$( rpm -q $first --qf "%{NAME}\n" | tail -n 1 )
  local first_v=$( rpm -q $first --qf "%{VERSION}\n" | tail -n 1 )
  local first_r=$( rpm -q $first --qf "%{RELEASE}\n" | tail -n 1 )
  local first_a=$( rpm -q $first --qf "%{ARCH}\n" | tail -n 1 )
  rlJournalStart

  assertTrue "rlAssertRpm returns 0 on installed 'N' package" \
    "rlAssertRpm $first_n"
  assertTrue "rlAssertRpm returns 0 on installed 'NV' package" \
    "rlAssertRpm $first_n $first_v"
  assertTrue "rlAssertRpm returns 0 on installed 'NVR' package" \
    "rlAssertRpm $first_n $first_v $first_r"
  assertTrue "rlAssertRpm returns 0 on installed 'NVRA' package" \
    "rlAssertRpm $first_n $first_v $first_r $first_a"

  assertFalse "rlAssertRpm returns non-0 when invoked without parameters" \
    "rlAssertRpm"

  assertFalse "rlAssertRpm returns non-0 on not-installed 'N' package" \
    "rlAssertRpm $first_n-not-installed-package"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NV' package" \
    "rlAssertRpm $first_n $first_v.1.2.3"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NVR' package" \
    "rlAssertRpm $first_n $first_v $first_r.1.2.3"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NVRA' package" \
    "rlAssertRpm $first_n $first_v $first_r ${first_a}xyz"

  assertTrue "rlAssertRpm increases SCORE when package is not found" \
    "rlPhaseStart FAIL rpm-asserts; rlAssertRpm ahsgqyrg ; rlPhaseEnd ;rlJournalPrintText |
	 tail -2| head -n 1 | grep -q '1 bad' "
}

test_rlAssertNotRpm() {
  local first=$( rpm -qa --qf "%{NAME}.%{ARCH}\n" | tail -n 1 )
  local first_n=$( rpm -q $first --qf "%{NAME}\n" | tail -n 1 )
  local first_v=$( rpm -q $first --qf "%{VERSION}\n" | tail -n 1 )
  local first_r=$( rpm -q $first --qf "%{RELEASE}\n" | tail -n 1 )
  local first_a=$( rpm -q $first --qf "%{ARCH}\n" | tail -n 1 )

  assertFalse "rlAssertNotRpm returns non-0 on installed 'N' package" \
    "rlAssertNotRpm $first_n"
  assertFalse "rlAssertNotRpm returns non-0 on installed 'NV' package" \
    "rlAssertNotRpm $first_n $first_v"
  assertFalse "rlAssertNotRpm returns non-0 on installed 'NVR' package" \
    "rlAssertNotRpm $first_n $first_v $first_r"
  assertFalse "rlAssertNotRpm returns non-0 on installed 'NVRA' package" \
    "rlAssertNotRpm $first_n $first_v $first_r $first_a"

  assertFalse "rlAssertNotRpm returns non-0 when run without parameters" \
    "rlAssertNotRpm"

  assertTrue "rlAssertNotRpm returns 0 on not-installed 'N' package" \
    "rlAssertNotRpm $first_n-not-installed-package"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NV' package" \
    "rlAssertNotRpm $first_n $first_v.1.2.3"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NVR' package" \
    "rlAssertNotRpm $first_n $first_v $first_r.1.2.3"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NVRA' package" \
    "rlAssertNotRpm $first_n $first_v $first_r ${first_a}xyz"

  assertTrue "rlAssertNotRpm increases SCORE when package is found" \
  "rlPhaseStart FAIL rpm-not-asserts; rlAssertNotRpm $first_n ; rlPhaseEnd ;rlJournalPrintText |
	 tail -2| head -1 | grep -q '1 bad' "

  assertTrue "rlAssertNotRpm increases SCORE when package is found" \
  "rlPhaseStart FAIL rpm-not-asserts; rlAssertNotRpm $first_n ; rlPhaseEnd ;rlCreateLogFromJournal |
	 tail -2| head -1 | grep -q '1 bad' "
}

test_rlCheckRpm() {
  local first=$( rpm -qa --qf "%{NAME}.%{ARCH}\n" | tail -n 1 )
  local first_n=$( rpm -q $first --qf "%{NAME}\n" | tail -n 1 )
  local first_v=$( rpm -q $first --qf "%{VERSION}\n" | tail -n 1 )
  local first_r=$( rpm -q $first --qf "%{RELEASE}\n" | tail -n 1 )
  local first_a=$( rpm -q $first --qf "%{ARCH}\n" | tail -n 1 )

  : > $OUTPUTFILE
  assertTrue "rlRpmPresent returns 0 on installed 'N' package" \
    "rlRpmPresent $first_n"
  assertTrue "rlRpmPresent returns 0 on installed 'NV' package" \
    "rlRpmPresent $first_n $first_v"
  assertTrue "rlRpmPresent returns 0 on installed 'NVR' package" \
    "rlRpmPresent $first_n $first_v $first_r"
  assertTrue "rlRpmPresent returns 0 on installed 'NVRA' package" \
    "rlRpmPresent $first_n $first_v $first_r $first_a"
  __checkLoggedText $first_n $OUTPUTFILE

  assertFalse "rlRpmPresent returns non-0 when run without parameters" \
    "rlRpmPresent"

  : > $OUTPUTFILE
  assertFalse "rlRpmPresent returns non-0 on not-installed 'N' package" \
    "rlRpmPresent $first_n-not-installed-package"
  assertFalse "rlRpmPresent returns non-0 on not-installed 'NV' package" \
    "rlRpmPresent $first_n $first_v.1.2.3"
  assertFalse "rlRpmPresent returns non-0 on not-installed 'NVR' package" \
    "rlRpmPresent $first_n $first_v $first_r.1.2.3"
  assertFalse "rlRpmPresent returns non-0 on not-installed 'NVRA' package" \
    "rlRpmPresent $first_n $first_v $first_r ${first_a}xyz"
  __checkLoggedText $first_n $OUTPUTFILE

  assertTrue "rlRpmPresent doesn't increase SCORE when package is not found" \
    "rlPhaseStart FAIL rpm-present; rlRpmPresent ahsgqyrg ; rlPhaseEnd ;rlJournalPrintText |
	 tail -2| head -n 1 | grep -q '0 bad' "
}

test_rlRpmPresent(){
    assertTrue "rlrpmPresent is reported to be obsoleted" "rlRpmPresent abcdefg |grep -q obsolete"
}


__checkLoggedText() {
  local msg="$1"
  local log="$2"
  assertTrue "__checkLoggedText logs '$msg' to the '$log'" "grep -q '$msg' $log"
}
#=================================================
#=================================================
# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Ales Zelinka <azelinka@redhat.com>

test_rlAssertDiffer() {
  local FILE1="`mktemp`"
  local FILE2="`mktemp`"
  local FILE3="`mktemp '/tmp/test rlAssertDiffer3-XXXXXX'`"

  echo "AAA" > "$FILE1"
  echo "AAA" > "$FILE2"
  echo "AAA" > "$FILE3"

  assertFalse "rlAssertDiffer does not return 0 for the identical files"\
  "rlAssertDiffer $FILE1 $FILE2"
  __one_fail_one_pass "rlAssertDiffer $FILE1 $FILE2" FAIL

  assertFalse "rlAssertDiffer does not return 0 for the identical files with spaces in name"\
  "rlAssertDiffer \"$FILE1\" \"$FILE3\""
  __one_fail_one_pass "rlAssertDiffer \"$FILE1\" \"$FILE3\"" FAIL

  assertFalse "rlAssertDiffer does not return 0 for the same file"\
  "rlAssertDiffer $FILE1 $FILE1"
  __one_fail_one_pass "rlAssertDiffer $FILE1 $FILE1" FAIL

  assertFalse "rlAssertDiffer does not return 0 when called without parameters"\
  "rlAssertDiffer"

  assertFalse "rlAssertDiffer does not return 0 when called with only one parameter"\
  "rlAssertDiffer $FILE1"

  echo "BBB" > "$FILE3"
  echo "BBB" > "$FILE2"

  assertTrue "rlAssertDiffer returns 0 for different files"\
  "rlAssertDiffer $FILE1 $FILE2"
  __one_fail_one_pass "rlAssertDiffer $FILE1 $FILE2" PASS

  assertTrue "rlAssertDiffer returns 0 for different files with space in name"\
  "rlAssertDiffer \"$FILE1\" \"$FILE3\""
  __one_fail_one_pass "rlAssertDiffer \"$FILE1\" \"$FILE3\"" PASS
  rm -f "$FILE1" "$FILE2" "$FILE3"
}

test_rlAssertNotDiffer() {
  local FILE1="`mktemp`"
  local FILE2="`mktemp`"
  local FILE3="`mktemp '/tmp/test rlAssertNotDiffer3-XXXXXX'`"

  echo "AAA" > "$FILE1"
  echo "AAA" > "$FILE2"
  echo "AAA" > "$FILE3"

  assertTrue "rlAssertNotDiffer returns 0 for the identical files"\
  "rlAssertNotDiffer $FILE1 $FILE2"
  __one_fail_one_pass "rlAssertNotDiffer $FILE1 $FILE2" PASS

  assertTrue "rlAssertNotDiffer returns 0 for the identical files with spaces in name"\
  "rlAssertNotDiffer \"$FILE1\" \"$FILE3\""
  __one_fail_one_pass "rlAssertNotDiffer \"$FILE1\" \"$FILE3\"" PASS

  assertTrue "rlAssertNotDiffer returns 0 for the same file"\
  "rlAssertNotDiffer $FILE1 $FILE1"
  __one_fail_one_pass "rlAssertNotDiffer $FILE1 $FILE1" PASS

  assertFalse "rlAssertNotDiffer does not return 0 when called without parameters"\
  "rlAssertNotDiffer"

  assertFalse "rlAssertNotDiffer does not return 0 when called with only one parameter"\
  "rlAssertNotDiffer $FILE1"

  echo "BBB" > "$FILE3"
  echo "BBB" > "$FILE2"

  assertFalse "rlAssertNotDiffer does not return 0 for different files"\
  "rlAssertNotDiffer $FILE1 $FILE2"
  __one_fail_one_pass "rlAssertNotDiffer $FILE1 $FILE2" FAIL

  assertFalse "rlAssertNotDiffer does not return 0 for different files with space in name"\
  "rlAssertNotDiffer \"$FILE1\" \"$FILE3\""
  __one_fail_one_pass "rlAssertNotDiffer \"$FILE1\" \"$FILE3\"" FAIL
  rm -f "$FILE1" "$FILE2" "$FILE3"
}


test_rlAssertExists() {
	local FILE="/tmp/test_rlAssertExists"

	touch $FILE
    assertTrue "rlAssertExists returns 0 on existing file" \
    "rlAssertExists $FILE"
	__one_fail_one_pass "rlAssertExists $FILE" PASS

	rm -f $FILE
    assertFalse "rlAssertExists returns 1 on non-existant file" \
    "rlAssertExists $FILE"
	__one_fail_one_pass "rlAssertExists $FILE" FAIL
    assertFalse "rlAssertExists returns 1 when called without arguments" \
    "rlAssertExists"

    local FILE="/tmp/test rlAssertExists filename with spaces"
	touch "$FILE"
    assertTrue "rlAssertExists returns 0 on existing file with spaces in its name" \
    "rlAssertExists \"$FILE\""
    rm -f "$FILE"
}
test_rlAssertNotExists() {
    local FILE="/tmp/test_rlAssertNotExists filename with spaces"
    local FILE2="/tmp/test_rlAssertNotExists"
	touch "$FILE"
    assertFalse "rlAssertNotExists returns 1 on existing file" \
    "rlAssertNotExists \"$FILE\""
	__one_fail_one_pass "rlAssertNotExists \"$FILE\"" FAIL
    assertFalse "rlAssertNotExists returns 1 when called without arguments" \
    "rlAssertNotExists"

	rm -f "$FILE"
	touch "$FILE2"
    assertTrue "rlAssertNotExists returns 0 on non-existing file" \
    "rlAssertNotExists \"$FILE\""
	__one_fail_one_pass "rlAssertNotExists \"$FILE\"" PASS
	rm -f "$FILE2"

}

test_rlAssertGrep() {
    echo yes > grepfile
    assertTrue "rlAssertGrep should pass when pattern present" \
        'rlAssertGrep yes grepfile; [ $? == 0 ]'
	__one_fail_one_pass 'rlAssertGrep yes grepfile' PASS
	__one_fail_one_pass 'rlAssertGrep no grepfile' FAIL
	__low_on_parameters 'rlAssertGrep yes grepfile'
    assertTrue "rlAssertGrep should return 1 when pattern is not present" \
        'rlAssertGrep no grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep should return 2 when file does not exist" \
        'rlAssertGrep no badfile; [ $? == 2 ]'
	__one_fail_one_pass 'rlAssertGrep yes badfile' FAIL
    # without optional parameter
    assertTrue "rlAssertGrep without optional arg should not ignore case" \
        'rlAssertGrep YES grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep without optional arg should ignore extended regexp" \
        'rlAssertGrep "e{1,3}" grepfile; [ $? == 1 ]'
    assertTrue "rlAssertGrep without optional arg should ignore perl regexp" \
        'rlAssertGrep "\w+" grepfile; [ $? == 1 ]'
    # with optional parameter
    assertTrue "rlAssertGrep with -i should ignore case" \
        'rlAssertGrep YES grepfile -i; [ $? == 0 ]'
    assertTrue "rlAssertGrep with -E should use extended regexp" \
        'rlAssertGrep "e{1,3}" grepfile -E; [ $? == 0 ]'
    assertTrue "rlAssertGrep with -P should use perl regexp" \
        'rlAssertGrep "\w+" grepfile -P; [ $? == 0 ]'
    rm -f grepfile
}

test_rlAssertNotGrep() {
    echo yes > grepfile
    assertTrue "rlAssertNotGrep should pass when pattern is not present" \
        'rlAssertNotGrep no grepfile; [ $? == 0 ]'
	__one_fail_one_pass 'rlAssertNotGrep no grepfile' PASS
	__one_fail_one_pass 'rlAssertNotGrep yes grepfile' FAIL
	__low_on_parameters 'rlAssertNotGrep no grepfile'
    assertTrue "rlAssertNotGrep should return 1 when pattern present" \
        'rlAssertNotGrep yes grepfile; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep should return 2 when file does not exist" \
        'rlAssertNotGrep no badfile; [ $? == 2 ]'
	__one_fail_one_pass 'rlAssertNotGrep yes badfile' FAIL
    # without optional parameter
    assertTrue "rlAssertNotGrep without optional arg should not ignore case" \
        'rlAssertNotGrep YES grepfile; [ $? == 0 ]'
    assertTrue "rlAssertNotGrep without optional arg should ignore extended regexp" \
        'rlAssertNotGrep "e{1,3}" grepfile; [ $? == 0 ]'
    assertTrue "rlAssertNotGrep without optional arg should ignore perl regexp" \
        'rlAssertNotGrep "\w+" grepfile; [ $? == 0 ]'
    # with optional parameter
    assertTrue "rlAssertNotGrep with -i should ignore case" \
        'rlAssertNotGrep YES grepfile -i; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep with -E should use extended regexp" \
        'rlAssertNotGrep "e{1,3}" grepfile -E; [ $? == 1 ]'
    assertTrue "rlAssertNotGrep with -P should use perl regexp" \
        'rlAssertNotGrep "\w+" grepfile -P; [ $? == 1 ]'
    rm -f grepfile
}


test_rlAssert0() {
	__one_fail_one_pass 'rlAssert0 "abc" 0' PASS
	__one_fail_one_pass 'rlAssert0 "abc" 1' FAIL
	__low_on_parameters 'rlAssert0 "comment" 0'
}

test_rlAssertEquals(){
	__one_fail_one_pass 'rlAssertEquals "abc" "hola" "hola"' PASS
	__one_fail_one_pass 'rlAssertEquals "abc" "hola" "Hola"' FAIL
	__low_on_parameters 'rlAssertEquals comment hola hola'
}
test_rlAssertNotEquals(){
	__one_fail_one_pass 'rlAssertNotEquals "abc" "hola" "hola"' FAIL
	__one_fail_one_pass 'rlAssertNotEquals "abc" "hola" "Hola"' PASS
	__low_on_parameters 'rlAssertNotEquals comment hola Hola'
}

test_rlAssertGreater(){
	__one_fail_one_pass 'rlAssertGreater "comment" 999 1' PASS
	__one_fail_one_pass 'rlAssertGreater "comment" 1 -1' PASS
	__one_fail_one_pass 'rlAssertGreater "comment" 999 999' FAIL
	__one_fail_one_pass 'rlAssertGreater "comment" 10 100' FAIL
	__low_on_parameters 'rlAssertGreater comment -1 -2'
}
test_rlAssertGreaterOrEqual(){
	__one_fail_one_pass 'rlAssertGreaterOrEqual "comment" 999 1' PASS
	__one_fail_one_pass 'rlAssertGreaterOrEqual "comment" 1 -1' PASS
	__one_fail_one_pass 'rlAssertGreaterOrEqual "comment" 999 999' PASS
	__one_fail_one_pass 'rlAssertGreaterOrEqual "comment" 10 100' FAIL
	__low_on_parameters 'rlAssertGreaterOrEqual comment 10 10'
}

test_rlRun(){
	__one_fail_one_pass 'rlRun /bin/true 0 comment' PASS
	__one_fail_one_pass 'rlRun /bin/true 3 comment' FAIL
    assertTrue "rlRun with 1st parameter only assumes status = 0 " \
        'rlRun /bin/true'
	#more than one status
	__one_fail_one_pass 'rlRun /bin/true 0,1,2 comment' PASS
	__one_fail_one_pass 'rlRun /bin/true 1,0,2 comment' PASS
	__one_fail_one_pass 'rlRun /bin/true 1,2,0 comment' PASS
	__one_fail_one_pass 'rlRun /bin/true 10,100,1000 comment' FAIL
	# more than one status with interval
	__one_fail_one_pass 'rlRun /bin/false 0-2 comment' PASS
	__one_fail_one_pass 'rlRun /bin/false 5,0-2 comment' PASS
	__one_fail_one_pass 'rlRun /bin/false 0-2,5 comment' PASS
	__one_fail_one_pass 'rlRun /bin/false 5,0-2,7 comment' PASS
	__one_fail_one_pass 'rlRun /bin/false 5-10,0-2 comment' PASS
	__one_fail_one_pass 'rlRun /bin/false 0-2,5-10 comment' PASS
    
    rlRun -t 'echo "foobar1"' | grep "^STDOUT: foobar1" 1>/dev/null
    assertTrue "rlRun tagging (stdout)" "[ $? -eq 0 ]"

    rlRun -t 'echo "foobar2" 1>&2' | grep "^STDERR: foobar2"  1>/dev/null
    assertTrue "rlRun tagging (stderr)" "[ $? -eq 0 ]"
 
    OUTPUTFILE_orig="$OUTPUTFILE"
    export OUTPUTFILE="`mktemp`"
    
    rlRun -l 'echo "foobar3"' 2>&1 1>/dev/null
    grep 'echo "foobar3"' $OUTPUTFILE 1>/dev/null && egrep '^foobar3' $OUTPUTFILE 1>/dev/null
    assertTrue "rlRun logging plain" "[ $? -eq 0 ]"

    rlRun -l -t 'echo "foobar4"' 2>&1 1>/dev/null
    grep 'echo "foobar4"' $OUTPUTFILE 1>/dev/null && egrep '^STDOUT: foobar4' $OUTPUTFILE 1>/dev/null
    assertTrue "rlRun logging with tagging (stdout)" "[ $? -eq 0 ]"

    rlRun -l -t 'echo "foobar5" 1>&2' 2>&1 1>/dev/null
    grep 'echo "foobar5" 1>&2' $OUTPUTFILE 1>/dev/null && egrep '^STDERR: foobar5' $OUTPUTFILE 1>/dev/null
    assertTrue "rlRun logging with tagging (stderr)" "[ $? -eq 0 ]"

    rlRun -s 'echo "foobar6_stdout"; echo "foobar6_stderr" 1>&2' 2>&1 1>/dev/null

    rlAssertGrep "foobar6_stdout" $rlRun_LOG 2>&1 1>/dev/null && rlAssertGrep "foobar6_stderr" $rlRun_LOG 2>&1 1>/dev/null
    assertTrue "rlRun -s - rlRun_LOG OK" "[ $? -eq 0 ]"

    #cleanup
    rm -rf $OUTPUTFILE
    export OUTPUTFILE="$OUTPUTFILE_orig"
}


test_rlWatchdog(){
	assertTrue "rlWatchDog detects when command end itself" 'rlWatchdog "sleep 3" 10'
	assertFalse "rlWatchDog kills command when time is up" 'rlWatchdog "sleep 10" 3'
	assertFalse "running rlWatchdog without timeout must not succeed" 'rlWatchDog "sleep 3"'
	assertFalse "running rlWatchdog without any parameters must not succeed" 'rlWatchDog '
}

test_rlFail(){
    assertFalse "This should always fail" "rlFail 'sometext'"
    __one_fail_one_pass "rlFail 'sometext'" FAIL
}

test_rlPass(){
    assertTrue "This should always pass" "rlPass 'sometext'"
    __one_fail_one_pass "rlPass 'sometext'" PASS
}

test_rlReport(){
  export BEAKERLIB_COMMAND_REPORT_RESULT=rhts-report-result
  rlJournalStart
  rlPhaseStartSetup

  for res in PASS FAIL WARN
  do
    OUT="`rlReport TEST $res | grep ANCHOR`"
    assertTrue "testing basic rlReport functionality" "[ \"$OUT\" == \"ANCHOR NAME: TEST\nRESULT: $res\n LOGFILE: $OUTPUTFILE\nSCORE: \" ]"
    OUT="`rlReport \"TEST TEST\" $res | grep ANCHOR`"
    assertTrue "testing if rlReport can handle spaces in test name" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\nRESULT: $res\n LOGFILE: $OUTPUTFILE\nSCORE: \" ]"
    OUT="`rlReport \"TEST\" $res 5 \"/tmp/logname\" | grep ANCHOR`"
    assertTrue "testing if rlReport can handle all arguments" "[ \"$OUT\" == \"ANCHOR NAME: TEST\nRESULT: $res\n LOGFILE: /tmp/logname\nSCORE: 5\" ]"
    OUT="`rlReport \"TEST TEST\" $res 8 \"/tmp/log name\" | grep ANCHOR`"
    assertTrue "testing if rlReport can handle spaces in test name and log file" "[ \"$OUT\" == \"ANCHOR NAME: TEST TEST\nRESULT: $res\n LOGFILE: /tmp/log name\nSCORE: 8\" ]"
  done
  rlPhaseEnd
}
#=================================================
. shunit2
