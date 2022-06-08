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
    local selinux=false
    if [[ -e /selinux/enforce || -e /sys/fs/selinux/enforce ]]; then
      selinux=true
    fi

    local acl=false
    if setfacl -m u:root:rwx "$BEAKERLIB_DIR" &>/dev/null; then
      local acl=true
    fi

    [ -d "$BEAKERLIB_DIR" ] && chmod -R 777 "$BEAKERLIB_DIR" \
            && rm -rf "$BEAKERLIB_DIR" && rlJournalStart
    score=0

    list() {
        ls -ld --full-time directory
        ls -lL --full-time directory
        $acl && ( find directory | sort | getfacl - )
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
    tmpdir="$(mktemp -d /tmp/backup-test-XXXXXXX)" # no-reboot
    pushd "$tmpdir" >/dev/null

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
    diff -u original removal || fail "Restore after complete removal not ok, differences found"

    # remove some, change content
    mess "Testing restore after partial removal"
    rm -rf directory/sub/sub directory/hardlink directory/permissions 'dir with spaces'
    echo "hi" >directory/content
    rlFileRestore || fail "Restore after partial removal"
    list >partial
    diff -u original partial || fail "Restore after partial removal not ok, differences found"

    # attribute changes
    mess "Testing restore after attribute changes"
    pushd directory >/dev/null
    chown root ownership
    chown nobody file
    touch times
    chmod 777 permissions
    $acl && setfacl -m u:root:--- acl
    $selinux && chcon --reference /home context
    popd >/dev/null
    rlFileRestore || fail "Restore attributes"
    list >attributes
    diff -u original attributes || fail "Restore attributes not ok, differences found"

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
        diff -u original acl || fail "Restoring correct path ACL not ok"
    fi

    # clean up
    popd >/dev/null
    rm -rf "$tmpdir"

    mess "Total score: $score"
    return $score
}


test_rlFileBackupAndRestore() {
    assertFalse "rlFileRestore should fail when no backup was done" \
        'rlFileRestore' 2
    assertTrue "rlFileBackup should fail and return 2 when no file/dir given" \
        'rlFileBackup; [ $? == 2 ]'
    assertRun 'rlFileBackup i-do-not-exist' 8 \
            "rlFileBackup should fail when given file/dir does not exist"

    if [[ $UID -eq 0 ]]; then
      assertTrue "rlFileBackup & rlFileRestore sanity test" BackupSanityTest
    else
      assertLog "rlFileBackup & rlFileRestore sanity test is not meant to be executed under non-priviledged user" SKIP
    fi
}

test_rlFileBackupSymlinkWarn() {
  assertTrue 'journalReset'
  FILE="$(mktemp)" # no-reboot
  SYMLINK="$FILE".symlink
  ln -s "$FILE" "$SYMLINK"
  if [[ $UID -eq 0 ]]; then
    assertRun "rlFileBackup '$FILE'"
    assertFalse "No symlink warn for a regular file" "rlJournalPrintText |grep 'Backing up symlink (not its target)'"
    assertRun "rlFileBackup '$SYMLINK'"
    assertTrue "Warning issued when backing up a symlink" "rlJournalPrintText |grep 'Backing up symlink (not its target)'"
  else
    assertLog "rlFileBackup is not meant to be executed under non-priviledged user" SKIP
  fi
  rm -f "$FILE" "$SYMLINK"
}

test_rlFileBackupCleanAndRestore() {
    test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX) # no-reboot
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
        "test -f '$test_dir/date3'"
}

test_rlFileBackupCleanAndRestoreWhitespace() {
    test_dir=$(mktemp -d '/tmp/beakerlib-test-XXXXXX') # no-reboot

    mkdir "$test_dir/noclean"
    mkdir "$test_dir/noclean clean"
    date > "$test_dir/noclean/date1"
    date > "$test_dir/noclean clean/date2"

    silentIfNotDebug "rlFileBackup '$test_dir/noclean'"
    silentIfNotDebug "rlFileBackup --clean '$test_dir/noclean clean'"

    date > "$test_dir/noclean/date3"   # this should remain
    date > "$test_dir/noclean clean/date4"   # this should be removed

    silentIfNotDebug 'rlFileRestore'

    assertTrue "rlFileBackup without '--clean' do not remove in dir with spaces" \
        "test -f '$test_dir/noclean/date3'"
    assertFalse "rlFileBackup with '--clean' remove in dir with spaces" \
        "test -f '$test_dir/noclean clean/date4'"
}

test_rlFileBackupAndRestoreNamespaces() {
    test_file=$(mktemp '/tmp/beakerlib-test-XXXXXX') # no-reboot
    test_file2=$(mktemp '/tmp/beakerlib-test-XXXXXX') # no-reboot

    # namespaced backup should restore independently
    echo "abcde" > "$test_file"
    silentIfNotDebug "rlFileBackup '$test_file'"
    echo "fghij" > "$test_file2"
    silentIfNotDebug "rlFileBackup --namespace myspace1 '$test_file2'"
    echo "12345" > "$test_file"
    echo "67890" > "$test_file2"
    silentIfNotDebug "rlFileRestore"
    assertRun "grep 'abcde' '$test_file' && grep '67890' '$test_file2'" 0 \
        "Normal restore shouldn't restore namespaced backup"
    echo "12345" > "$test_file"
    echo "67890" > "$test_file2"
    silentIfNotDebug "rlFileRestore --namespace myspace1"
    assertRun "grep '12345' '$test_file' && grep 'fghij' '$test_file2'" 0 \
        "Namespaced restore shouldn't restore normal backup"

    # namespaced backup doesn't overwrite normal one
    echo "abcde" > "$test_file"
    silentIfNotDebug "rlFileBackup '$test_file'"
    echo "12345" > "$test_file"
    silentIfNotDebug "rlFileBackup --namespace myspace2 '$test_file'"
    silentIfNotDebug 'rlFileRestore'
    assertRun "grep 'abcde' '$test_file'" 0 \
        "Namespaced backup shouldn't overwrite normal one"

    rm -f "$test_file" "$test_file2"
}

test_rlFileBackup_MissingFiles() {
    local dir="$(mktemp -d)" # no-reboot
    assertTrue "Preparing the directory" "pushd $dir && mkdir subdir"
    [[ -e /selinux/enforce || -e /sys/fs/selinux/enforce ]] && assertTrue "Changing selinux context" "chcon -t httpd_user_content_t subdir"
    assertTrue "Saving the old context" "ls -lZd subdir > old"
    assertRun "rlFileBackup $dir/subdir/missing" 8 "Backing up without --clean"
    assertRun "rlFileBackup --missing-ok $dir/subdir/missing" 0 "Backing up with --missing-ok"
    assertRun "rlFileBackup --clean $dir/subdir/missing" 0 "Backing up with --clean"
    assertRun "rlFileBackup --clean --no-missing-ok $dir/subdir/missing" 8 "Backing up with --clean and --no-missing-ok"
    assertRun "rlFileRestore" 0 "Restoring"
    assertTrue "Saving the new context" "ls -lZd subdir > new"
    assertTrue "Checking security context (BZ#618269)" "diff old new"
    popd >/dev/null
    rm -rf "$dir"
}


# backing up symlinks [BZ#647231]
test_rlFileBackup_Symlinks() {
    local dir="$(mktemp -d)" #no-reboot
    assertTrue "Preparing files" "pushd $dir && touch file && ln -s file link"
    assertRun "rlFileBackup link" "[07]" "Backing up the link"
    assertTrue "Removing the link" "rm link"
    assertRun "rlFileRestore link" "[02]" "Restoring the link"
    assertTrue "Symbolic link should be restored" "test -L link"
    popd >/dev/null
    rm -rf "$dir"
}

# backing up dir with symlink in the parent dir [BZ#647231#c13]
test_rlFileBackup_SymlinkInParent() {
    local dir="$(mktemp -d)" #no-reboot
    assertTrue "Preparing tmp directory" "pushd $dir"
    assertTrue "Preparing target directory" 'mkdir target && touch target/file1 target/file2'
    assertTrue "Preparing linked directory" 'ln -s target link'
    assertRun "rlFileBackup link/file1" '[07]' "Backing up the link/file1"
    assertTrue "Removing link/file1" 'rm link/file1'
    assertRun "rlFileRestore" [02] "Restoring the file1"
    assertTrue "Testing that link points to target" 'readlink link | grep target'
    assertTrue "Testing that link/file1 was restored" 'test -f link/file1'
    assertTrue "Testing that link/file2 is still present" 'test -f link/file2'
    popd >/dev/null
    rm -rf "$dir"
}

test_rlFileRestore_ECs() {
    test_dir=$(mktemp -d /tmp/beakerlib-test-XXXXXX) # no-reboot
    date > "$test_dir/date1"
    date > "$test_dir/date2"
    assertRun "rlFileRestore --blabla" 1 "test invalid long option"
    assertRun "rlFileRestore -b" 1 "test invalid short option"
    assertRun "rlFileRestore" 2 "no backup done"
    assertRun "rlFileBackup --clean '$test_dir/date3'"
    date > "$test_dir/date3"
    chattr +i "$test_dir/date3"
    assertRun "rlFileRestore" 20 "could not cleanup file + not backed up files"
    assertRun "rlFileBackup '$test_dir/date2'"
    assertRun "rlFileRestore" 4 "could not cleanup file"
    chattr -i "$test_dir/date3"
    chattr +i "$test_dir/date2"
    assertRun "rlFileRestore" 8 "could not rewrite original file"
    chattr -i "$test_dir/date2"
    rm -rf $test_dir
}

test_rlServiceStart() {
    assertTrue "rlServiceStart should fail and return 99 when no service given" \
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
    assertTrue "rlServiceStop should fail and return 99 when no service given" \
        'rlServiceStop; [ $? == 99 ]'

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

test_rlServiceEnable() {
    assertTrue "rlServiceEnable should fail and return 99 when no service given" \
        'rlServiceEnable; [ $? == 99 ]'

    assertTrue "down-enabling-ok" \
        'chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 0;; esac; };
        rlServiceEnable disabled-enabling-ok'

    assertTrue "up-enabling-ok" \
        'chkconfig() { case $2 in "") return 0;; on) return 0;; off) return 0;; esac; };
        rlServiceEnable enabled-enabling-ok'

    assertTrue "weird-enabling-ok" \
        'chkconfig() { case $2 in "") return 11;; on) return 0;; off) return 0;; esac; };
        rlServiceEnable weird-enabling-ok'

    assertFalse "up-enabling-enable-ko" \
        'chkconfig() { case $2 in "") return 1;; on) return 1;; off) return 0;; esac; };
        rlServiceEnable up-enabling-enable-ko'
}

test_rlServiceDisable() {
    assertTrue "rlServiceDisable should fail and return 99 when no service given" \
        'rlServiceDisable; [ $? == 99 ]'

    assertTrue "enabled-disabling-ok" \
        'chkconfig() { case $2 in "") return 0;; on) return 0;; off) return 0;; esac; };
        rlServiceDisable enabled-disabling-ok'

    assertTrue "disabled-disabling-ok" \
        'chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 0;; esac; };
        rlServiceDisable disabled-disabling-ok'

    assertTrue "weird-disabling-ok" \
        'chkconfig() { case $2 in "") return 11;; on) return 0;; off) return 0;; esac; };
        rlServiceDisable weird-disabling-ok'

    assertFalse "up-disabling-disable-ko" \
        'chkconfig() { case $2 in "") return 0;; on) return 1;; off) return 1;; esac; };
        rlServiceDisable up-disabling-disable-ko'
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

    # verify that rlServiceRestore without arguments restores all services in reverse order
    __INTERNAL_SERVICES_LIST="$BEAKERLIB_DIR/services_list"
    rm -f $__INTERNAL_SERVICES_LIST
    # initial setup: service1 is running, service2 is stopped
    assertTrue "service1-is-up-stop" \
        'service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlServiceStop service1;'
    assertTrue "service1 status saved" \
        "grep -q 'service1' $__INTERNAL_SERVICES_LIST"  # verify that the initial status is properly saved
    assertTrue "service1-is-down-start-again" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart service1;'
    assertRun "[ '$(grep service1 $__INTERNAL_SERVICES_LIST | wc -l)' -eq '1' ]" 0
    assertTrue "service2-is-down-start" \
        'service() { case $2 in status) return 3;; start) return 0;; stop) return 0;; esac; };
        rlServiceStart service2;'
    assertTrue "service2 status saved" \
        "grep -q 'service2' $__INTERNAL_SERVICES_LIST"
    # at this moment service1 and service2 are running, we need to restore it properly into original setup
    TMP_FILE=`mktemp`
    assertTrue "restore all" \
        'service() { case $2 in status) return 0;; start) echo -n "starting $1;">>$TMP_FILE; return 0;; stop) echo -n "stopping $1;">>$TMP_FILE; return 0;; esac; };
        rlServiceRestore;'
    # proper restore sequence is: stop service2, stop service1, start service 1 again
    assertTrue "grep 'stopping service2;stopping service1;starting service1;' $TMP_FILE"
    rm -f $TMP_FILE
}

__INTERNAL_fake_release() {
    local release=${1}
    #######
    # TODO: this part is copypasted from testingTest.sh, it would probably be nice to have
    # it as it's own test function
    #fake beakerlib-lsb_release so we can control what rlIsRHEL sees
    local fake_release=$(mktemp)
   cat >beakerlib-lsb_release <<-EOF
#!/bin/bash
RELEASE="\$(<$fake_release)"
[ \$1 = "-ds" ] && {
    echo "Red Hat Enterprise Linux \$RELEASE (fakeone)"
    exit 0
}
[ \$1 = "-rs" ] && { echo "\$RELEASE" ; exit 0 ; }
echo invalid input, this stub might be out of date, please
echo update according to __INTERNAL_rlIsDistro usage of beakerlib-lsb_release
exit 1
EOF
    chmod a+x ./beakerlib-lsb_release
    local OLD_PATH=$PATH
    PATH="./:"$PATH

    echo "$release" > $fake_release
}

test_rlServiceRestore_persistence() {
    assertTrue "was-down-is-down-ok" \
        'chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 0;; esac; };
        rlServiceDisable was-down-is-down-ok;
        chkconfig() { case $2 in "") return 1;; on) return 1;; off) return 1;; esac; };
        rlServiceRestore was-down-is-down-ok'

    assertTrue "was-down-is-up-ok" \
        'chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 0;; esac; };
        rlServiceEnable was-down-is-up-ok;
        chkconfig() { case $2 in "") return 0;; on) return 1;; off) return 0;; esac; };
        rlServiceRestore was-down-is-up-ok'

    assertTrue "was-up-is-down-ok" \
        'chkconfig() { case $2 in "") return 0;; on) return 0;; off) return 0;; esac; };
        rlServiceDisable was-up-is-down-ok;
        chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 1;; esac; };
        rlServiceRestore was-up-is-down-ok'

    assertTrue "was-up-is-up-ok" \
        'chkconfig() { case $2 in "") return 0;; on) return 0;; off) return 0;; esac; };
        rlServiceEnable was-up-is-up-ok;
        chkconfig() { case $2 in "") return 0;; on) return 1;; off) return 1;; esac; };
        rlServiceRestore was-up-is-up-ok'

    assertFalse "was-down-is-up-stop-ko" \
        'chkconfig() { case $2 in "") return 1;; on) return 0;; off) return 1;; esac; };
        rlServiceEnable was-down-is-up-stop-ko;
        chkconfig() { case $2 in "") return 0;; on) return 0;; off) return 1;; esac; };
        rlServiceRestore was-down-is-up-stop-ko'

    assertFalse "was-up-is-down-start-ko" \
        'chkconfig() { case $2 in "") return 0;; on) return 1;; off) return 0;; esac; };
        rlServiceDisable was-up-is-down-start-ko;
        chkconfig() { case $2 in "") return 1;; on) return 1;; off) return 0;; esac; };
        rlServiceRestore was-up-is-down-start-ko'

}

test_rlSocketStart_legacy() {
    local release=6.0
    __INTERNAL_fake_release $release

    assertTrue "rlSocketStart should fail and return 99 when no service given" \
        'rlSocketStart; [ $? == 99 ]'

    assertTrue "exists-started-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart exists-started-start-ok'

    assertTrue "exists-started-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 1;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart exists-started-start-ko'

    assertTrue "exists-stopped-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart exists-stopped-start-ok'

    assertFalse "exists-stopped-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 1;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart exists-stopped-start-ko'

    assertTrue "exists-weirded-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "unknown";return 5;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart exists-weirded-start-ok'

    assertFalse "notexists-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") return 1;; on) return 1;; off) return 1;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStart notexists-start-ko'

}

test_rlSocketStart_systemd() {
    local release=7.0
    __INTERNAL_fake_release $release

    assertTrue "rlSocketStart should fail and return 99 when no service given" \
        'rlSocketStart; [ $? == 99 ]'

    assertTrue "exists-started-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-start-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketStart exists-started-start-ok'

    assertTrue "exists-started-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-start-ko.socket";; start) return 1;; stop) return 1;;is-active) echo "active";return 0;; is-enabled) echo "enabled"; return 0;; esac; };
        rlSocketStart exists-started-start-ko'

    assertTrue "exists-stopped-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-start-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStart exists-stopped-start-ok'

    assertFalse "exists-stopped-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-start-ko.socket";; start) return 1;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStart exists-stopped-start-ko'

    assertTrue "exists-weirded-start-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-weirded-start-ok.socket";; start) return 0;; stop) return 0;;is-active) return 2;; is-enabled) return 0;; esac; };
        rlSocketStart exists-weirded-start-ok'

    assertFalse "notexists-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "failure";; start) return 1;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStart notexists-start-ko'

}

test_rlSocketStop_legacy() {
    local release=6.0
    __INTERNAL_fake_release $release

    assertTrue "rlSocketStop should fail and return 99 when no service given" \
        'rlSocketStop; [ $? == 99 ]'

    assertTrue "exists-started-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop exists-started-start-ok'

    assertFalse "exists-started-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 1;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop exists-started-start-ko'

    assertTrue "exists-stopped-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop exists-stopped-start-ok'

    assertTrue "exists-stopped-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 1;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop exists-stopped-start-ko'

    assertTrue "exists-weirded-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") echo "unknown";return 5;; on) return 0;; off) return 0;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop exists-weirded-start-ok'

    assertTrue "notexists-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        chkconfig() { case $2 in "") return 1;; on) return 1;; off) return 1;; esac; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        rlSocketStop notexists-start-ko'

}

test_rlSocketStop_systemd() {
    local release=7.0
    __INTERNAL_fake_release $release

    assertTrue "rlSocketStop should fail and return 99 when no service given" \
        'rlSocketStop; [ $? == 99 ]'

    assertTrue "exists-started-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-stop-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketStop exists-started-stop-ok'

    assertFalse "exists-started-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-stop-ko.socket";; start) return 0;; stop) return 1;;is-active) echo "active";return 0;; is-enabled) echo "enabled"; return 0;; esac; };
        rlSocketStop exists-started-stop-ko'

    assertTrue "exists-stopped-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-stop-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStop exists-stopped-stop-ok'

    assertTrue "exists-stopped-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-stop-ko.socket";; start) return 0;; stop) return 1;;is-active) return 1;; is-enabled) return 1;; esac; };
        rlSocketStop exists-stopped-stop-ko'

    assertTrue "exists-weirded-stop-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-weirded-stop-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStop exists-weirded-stop-ok'

    assertTrue "notexists-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "failure";; start) return 1;; stop) return 1;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStop notexists-stop-ko'

}

test_rlSocketRestore_legacy() {
    local release=6.0
    __INTERNAL_fake_release $release

    assertTrue "rlSocketStart should fail and return 99 when no service given" \
        'rlSocketStart; [ $? == 99 ]'

    assertTrue "exists-started-started-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 0;; esac; };
        rlSocketStart exists-started-started-ok;
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 1;; off) return 1;; esac; };
        rlSocketRestore exists-started-started-ok'

    assertTrue "exists-started-stopped-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 0;; esac; };
        rlSocketStop exists-started-stopped-ok;
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 1;; esac; };
        rlSocketRestore exists-started-stopped-ok'

    assertFalse "exists-started-stopped-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 0;; esac; };
        rlSocketStop exists-started-stopped-start-ko;
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 1;; off) return 0;; esac; };
        rlSocketRestore exists-started-stopped-start-ko'

    assertTrue "exists-stopped-started-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 0;; esac; };
        rlSocketStart exists-stopped-started-ok;
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 1;; off) return 0;; esac; };
        rlSocketRestore exists-stopped-started-ok'

    assertFalse "exists-stopped-started-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 0;; esac; };
        rlSocketStart exists-started-started-ok;
        chkconfig() { case $2 in "") echo "on";return 0;; on) return 0;; off) return 1;; esac; };
        rlSocketRestore exists-stopped-started-stop-ko'

    assertTrue "exists-stopped-stopped-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 1; };
        service() { case $2 in status) return 0;; start) return 0;; stop) return 0;; esac; };
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 0;; off) return 0;; esac; };
        rlSocketStop exists-stopped-stopped-ok;
        chkconfig() { case $2 in "") echo "off";return 1;; on) return 1;; off) return 1;; esac; };
        rlSocketRestore exists-stopped-stopped-ok'

}

test_rlSocketRestore_systemd() {
    local release=7.0

    __INTERNAL_fake_release $release
    assertTrue "rlSocketStart should fail and return 99 when no service given" \
        'rlSocketStart; [ $? == 99 ]'

    assertTrue "exists-started-started-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-started-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketStart exists-started-started-ok;
        systemctl() { case $2 in list-sockets) echo "exists-started-started-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-started-started-ok'

    assertTrue "exists-started-stopped-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-stopped-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketStop exists-started-stopped-ok;
        systemctl() { case $2 in list-sockets) echo "exists-started-stopped-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-started-stopped-ok'

    assertFalse "exists-started-stopped-start-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-started-stopped-start-ko.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketStop exists-started-stopped-start-ko;
        systemctl() { case $2 in list-sockets) echo "exists-started-stopped-start-ko.socket";; start) return 1;; stop) return 1;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-started-stopped-start-ko'

    assertTrue "exists-stopped-started-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-started-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStart exists-stopped-started-ok;
        systemctl() { case $2 in list-sockets) echo "exists-stopped-started-ok.socket";; start) return 0;; stop) return 0;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-stopped-started-ok'

    assertFalse "exists-stopped-started-stop-ko" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-started-stop-ko.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStart exists-stopped-started-stop-ko;
        systemctl() { case $2 in list-sockets) echo "exists-stopped-started-stop-ko.socket";; start) return 1;; stop) return 1;;is-active) return 0;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-stopped-started-stop-ko'

    assertTrue "exists-stopped-stopped-ok" \
        '__INTERNAL_SOCKET_get_handler() { return 0; };
        systemctl() { case $2 in list-sockets) echo "exists-stopped-stopped-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketStop exists-stopped-stopped-ok;
        systemctl() { case $2 in list-sockets) echo "exists-stopped-stopped-ok.socket";; start) return 0;; stop) return 0;;is-active) return 1;; is-enabled) return 0;; esac; };
        rlSocketRestore exists-stopped-stopped-ok'
    assertTrue "rlSocketStart should fail and return 99 when no service given" \
        'rlSocketStart; [ $? == 99 ]'

}

__INTERNAL_fake_release() {
    local release=${1}
    #######
    # TODO: this part is copypasted from testingTest.sh, it would probably be nice to have
    # it as it's own test function
    #fake beakerlib-lsb_release so we can control what rlIsRHEL sees
    local fake_release=$(mktemp)
   cat >beakerlib-lsb_release <<-EOF
#!/bin/bash
RELEASE="\$(<$fake_release)"
[ \$1 = "-ds" ] && {
    echo "Red Hat Enterprise Linux \$RELEASE (fakeone)"
    exit 0
}
[ \$1 = "-rs" ] && { echo "\$RELEASE" ; exit 0 ; }
echo invalid input, this stub might be out of date, please
echo update according to __INTERNAL_rlIsDistro usage of beakerlib-lsb_release
exit 1
EOF
    chmod a+x ./beakerlib-lsb_release
    local OLD_PATH=$PATH
    PATH="./:"$PATH

    echo "$release" > $fake_release
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
    unset mount
}

test_rlMountAny(){
    assertTrue "rlmountAny is marked as deprecated" \
    "rlMountAny server remotedir $MP 2>&1 >&- |grep -q deprecated "
}

test_rlAnyMounted(){
    assertTrue "rlAnymounted is marked as deprecated" \
    "rlAnyMounted server remotedir $MP 2>&1 >&- |grep -q deprecated "
}

test_rlCheckMount(){
    MP1=$(readlink -m $MP)
    [ -d "$MP" ] && rmdir "$MP1"
    assertFalse "rlCheckMount returns non-0 on no-existing mount point" \
    "rlCheckMount server remotedir $MP1"
    test_img=$( mktemp )
    dd if=/dev/zero of=$test_img count=1 bs=1 seek=1G
    mkfs.ext4 -F $test_img
    mkdir -p $MP1
    mount -o loop,noexec,rw $test_img $MP
    mount
    assertTrue "rlCheckMount returns 0 in existing mountpoint" \
      "rlCheckMount $MP1"
    assertTrue "rlCheckMount returns 0 in existing mountpoint on existing target" \
      "rlCheckMount $test_img $MP1"
    # no chance to test the third variant: no server-base mount is sure to be mounted
    assertTrue "rlCheckMount returns 0 in existing mountpoint with correct option" \
      "rlCheckMount -o rw $MP1"
    assertTrue "rlCheckMount returns 0 in existing mountpoint with correct options" \
      "rlCheckMount -o rw,noexec $MP1"
    assertTrue "rlCheckMount returns 0 in existing mountpoint with correct options, reverted order" \
      "rlCheckMount -o noexec,rw $MP1"
    assertTrue "rlCheckMount returns 0 in existing mountpoint with correct option" \
      "rlCheckMount -o rw $MP1"
    assertTrue "rlCheckMount returns 0 in existing mountpoint and target with correct option" \
      "rlCheckMount -o rw $test_img $MP1"
    assertFalse "rlCheckMount returns non-0 in existing mountpoint with incorrect option" \
      "rlCheckMount -o ro $MP1" 2
    assertFalse "rlCheckMount returns non-0 in existing mountpoint with incorrect options" \
      "rlCheckMount -o ro,nodev $MP1" 2
    assertFalse "rlCheckMount returns non-0 in existing mountpoint and target with incorrect options" \
      "rlCheckMount -o ro $test_img $MP1" 2
    umount $test_img
    rm -f $test_img
    rmdir "$MP1"
}

test_rlAssertMount(){
    mkdir "$MP"
    assertGoodBad "rlAssertMount server remote-dir $MP" 0 1
    assertFalse "rlAssertMount without paramaters doesn't succeed" \
    "rlAssertMount"
    rmdir "$MP" "remotedir"
}

test_rlSEBooleanTest() {
  # this feature was dropped, now it is not tested
  assertLog "skipping rlSEBooleanOn" SKIP
  assertLog "skipping rlSEBooleanOff" SKIP
  assertLog "skipping rlSEBooleanRestore" SKIP
}

# NOTE: these two tests (Append/Prepend) verify ONLY the "no testwatcher"
#       (bash only) scenario as incorporating the test watcher in this suite
#       would be rather difficult
test_rlCleanupAppend()
{
    assertTrue 'journalReset'
    local tmpfile=$(mktemp)

    assertTrue "rlCleanupAppend succeeds on initialized journal" "rlCleanupAppend \"echo -n one >> \\\"$tmpfile\\\"\""
    assertTrue "rlCleanupAppend issued a warning (no testwatcher)" \
               "rlJournalPrint | grep -q \"<message.*severity=\\\"WARNING\\\">rlCleanupAppend: Running outside of the test watcher\""

    silentIfNotDebug "rlCleanupAppend \"echo -n two >> '$tmpfile'\""

    silentIfNotDebug "rlJournalEnd"

    assertTrue "Temporary file should contain 'onetwo' after rlJournalEnd" "grep -q 'onetwo' < \"$tmpfile\"" || cat "$tmpfile"
    assertTrue "rlJournalEnd issued a warning (no testwatcher)" \
               "rlJournalPrint | grep -q \"<message.*severity=\\\"WARNING\\\">rlJournalEnd: Not running in test watcher\""

    rm -f "$tmpfile"
}
test_rlCleanupPrepend()
{
    assertTrue 'journalReset'
    local tmpfile=$(mktemp)

    assertTrue "rlCleanupAppend succeeds on initialized journal" "rlCleanupAppend \"echo -n one >> \\\"$tmpfile\\\"\""
    assertTrue "rlCleanupAppend issued a warning (no testwatcher)" \
               "rlJournalPrint | grep -q \"<message.*severity=\\\"WARNING\\\">rlCleanupAppend: Running outside of the test watcher\""

    silentIfNotDebug "rlCleanupAppend \"echo -n two >> '$tmpfile'\""

    #silentIfNotDebug "rlJournalEnd"
    rlJournalEnd &> /dev/null

    assertTrue "Temporary file should contain 'twoone' after rlJournalEnd" "grep -q 'onetwo' < \"$tmpfile\"" || cat "$tmpfile"
    assertTrue "rlJournalEnd issued a warning (no testwatcher)" \
               "rlJournalPrint | grep -q \"<message.*severity=\\\"WARNING\\\">rlJournalEnd: Not running in test watcher\""

    rm -f "$tmpfile"
}
