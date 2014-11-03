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
    if [ -d "/selinux" ]; then
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
        'rlFileRestore'
    assertTrue "rlFileBackup should fail and return 2 when no file/dir given" \
        'rlFileBackup; [ $? == 2 ]'
    assertRun 'rlFileBackup i-do-not-exist' 8 \
            "rlFileBackup should fail when given file/dir does not exist"

    assertTrue "rlFileBackup & rlFileRestore sanity test (needs to be root to run this)" BackupSanityTest
}

test_rlFileBackupSymlinkWarn() {
  assertTrue 'journalReset'
  FILE="$(mktemp)" # no-reboot
  SYMLINK="$FILE".symlink
  ln -s "$FILE" "$SYMLINK"
  assertRun "rlFileBackup '$FILE'"
  assertFalse "No symlink warn for a regular file" "rlJournalPrintText |grep 'Backup target is a symlink'"
  assertRun "rlFileBackup '$SYMLINK'"
  assertTrue "Warning issued when backing up a symlink" "rlJournalPrintText |grep 'Backup target is a symlink'"
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
    selinuxenabled && assertTrue "Changing selinux context" "chcon -t httpd_user_content_t subdir"
    assertTrue "Saving the old context" "ls -lZd subdir > old"
    assertRun "rlFileBackup $dir/subdir/missing" 8 "Backing up without --clean"
    assertRun "rlFileBackup --clean $dir/subdir/missing" 0 "Backing up --clean"
    assertRun "rlFileRestore" 2 "Restoring"
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

test_rlServiceRestore() {
    assertTrue "rlServiceRestore should fail and return 99 when no service given" \
        'rlServiceRestore; [ $? == 99 ]'

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
    [ -d "$MP" ] && rmdir "$MP"
    assertFalse "rlCheckMount returns non-0 on no-existing mount point" \
    "rlCheckMount server remotedir $MP"
    assertTrue "rlCheckMount returns 0 in existing mountpoint" \
      "rlCheckMount /proc"
    assertTrue "rlCheckMount returns 0 in existing mountpoint on existing target" \
      "rlCheckMount proc /proc"
    # no chance to test the third variant: no server-base mount is sure to be mounted
}
test_rlAssertMount(){
    mkdir "$MP"
    assertGoodBad "rlAssertMount server remote-dir $MP" 0 1
    assertFalse "rlAssertMount without paramaters doesn't succeed" \
    "rlAssertMount"
    rmdir "$MP" "remotedir"
}

test_rlSEBooleanTest() {
    if ! selinuxenabled
    then
      assertLog "SELinux disabled: test was not run" "WARN"
      return
    fi

    assertFalse "rlSEBooleanRestore should fail when no rlSEBoolean functions were run" \
        'rlSEBooleanRestore a-boolean; [ $? == 0 ]'
    assertFalse "rlSEBooleanOn should fail when no boolean is given" \
        'rlSEBooleanOn'
    assertFalse "rlSEBooleanOff should fail when no boolean is given" \
        'rlSEBooleanOff'
    assertFalse "rlSEBooleanOn should fail for non-existent boolean" \
        'rlSEBooleanOn i_do_not_exist'
    assertFalse "rlSEBooleanOff should fail for non-existent boolean" \
        'rlSEBooleanOff i_do_not_exist'

    local TESTED_BOOLEAN=daemons_dump_core
    local DIFFERENT_BOOLEAN=secure_mode
    assertTrue "rlSEBooleanOff $DIFFERENT_BOOLEAN" "rlSEBooleanOff $DIFFERENT_BOOLEAN"

    local OLDSTATE="$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )"
    assertTrue "rlSEBooleanOn is successful for $TESTED_BOOLEAN" "rlSEBooleanOn $TESTED_BOOLEAN"
    assertTrue "$TESTED_BOOLEAN is on after rlSEBooleanOn" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'on' ]"
    assertTrue "Parameterless rlSEBooleanRestore is successful after rlSEBooleanOn is run" "rlSEBooleanRestore"
    assertTrue "Parameterless rlSEBooleanRestore: state is successfuly restored" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == '$OLDSTATE' ]"
    assertTrue "rlSEBooleanOn is successful for $TESTED_BOOLEAN" "rlSEBooleanOn $TESTED_BOOLEAN"
    assertTrue "$TESTED_BOOLEAN is on after rlSEBooleanOn" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'on' ]"
    assertTrue "rlSEBooleanRestore of unrelated boolean is successful" "rlSEBooleanRestore $DIFFERENT_BOOLEAN"
    assertTrue "rlSEBooleanRestore of unrelated boolean does not affect $TESTED_BOOLEAN" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'on' ]"
    assertTrue "rlSEBooleanRestore of $TESTED_BOOLEAN is successful" "rlSEBooleanRestore $TESTED_BOOLEAN"
    assertTrue "rlSEBooleanRestore of $TESTED_BOOLEAN resets state" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == '$OLDSTATE' ]"

    assertTrue "rlSEBooleanOff is successful for $TESTED_BOOLEAN" "rlSEBooleanOff $TESTED_BOOLEAN"
    assertTrue "$TESTED_BOOLEAN is off after rlSEBooleanOff" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'off' ]"
    assertTrue "Parameterless rlSEBooleanRestore is successful after rlSEBooleanOff is run" "rlSEBooleanRestore"
    assertTrue "Parameterless rlSEBooleanRestore: state is successfuly restored" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == '$OLDSTATE' ]"
    assertTrue "rlSEBooleanOff is successful for $TESTED_BOOLEAN" "rlSEBooleanOff $TESTED_BOOLEAN"
    assertTrue "$TESTED_BOOLEAN is off after rlSEBooleanOff" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'off' ]"
    assertTrue "rlSEBooleanRestore of unrelated boolean is successful" "rlSEBooleanRestore $DIFFERENT_BOOLEAN"
    assertTrue "rlSEBooleanRestore of unrelated boolean does not affect $TESTED_BOOLEAN" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == 'off' ]"
    assertTrue "rlSEBooleanRestore of $TESTED_BOOLEAN is successful" "rlSEBooleanRestore $TESTED_BOOLEAN"
    assertTrue "rlSEBooleanRestore of $TESTED_BOOLEAN resets state" "[ '$( getsebool $TESTED_BOOLEAN | cut -d ' ' -f 3 )' == '$OLDSTATE' ]"
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
               "grep -q \"<message\ severity=\\\"WARNING\\\">rlCleanupAppend: Running outside of the test watcher\" \"$BEAKERLIB_JOURNAL\""

    silentIfNotDebug "rlCleanupAppend \"echo -n two >> '$tmpfile'\""

    silentIfNotDebug "rlJournalEnd"

    assertTrue "Temporary file should contain 'onetwo' after rlJournalEnd" "grep -q 'onetwo' < \"$tmpfile\"" || cat "$tmpfile"
    assertTrue "rlJournalEnd issued a warning (no testwatcher)" \
               "grep -q \"<message\ severity=\\\"WARNING\\\">rlJournalEnd: Not running in test watcher\" \"$BEAKERLIB_JOURNAL\""

    rm -f "$tmpfile"
}
test_rlCleanupPrepend()
{
    assertTrue 'journalReset'
    local tmpfile=$(mktemp)

    assertTrue "rlCleanupPrepend succeeds on initialized journal" "rlCleanupPrepend \"echo -n one >> \\\"$tmpfile\\\"\""
    assertTrue "rlCleanupPrepend issued a warning (no testwatcher)" \
               "grep \"<message\ severity=\\\"WARNING\\\">rlCleanupPrepend: Running outside of the test watcher\" \"$BEAKERLIB_JOURNAL\""

    silentIfNotDebug "rlCleanupPrepend \"echo -n two >> '$tmpfile'\""

    silentIfNotDebug "rlJournalEnd"

    assertTrue "Temporary file should contain 'twoone' after rlJournalEnd" "grep 'twoone' < \"$tmpfile\"" || cat "$tmpfile"
    assertTrue "rlJournalEnd issued a warning (no testwatcher)" \
               "grep \"<message\ severity=\\\"WARNING\\\">rlJournalEnd: Not running in test watcher\" \"$BEAKERLIB_JOURNAL\""

    rm -f "$tmpfile"
}

