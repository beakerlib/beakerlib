# Copyright (c) 2012 Red Hat, Inc. All rights reserved. This copyrighted material
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
# Author: Petr Muller <muller@redhat.com>

__INTERNAL_TEST_PATH="tested/Sanity/dummy"
__INTERNAL_ILIB_PATH="tested/Library/dummy"
__INTERNAL_ELIB_PATH="external/Library/dummy"

__INTERNAL_TEST_TEMPLATE="`mktemp`" # no-reboot
__INTERNAL_LIB_TEMPLATE="`mktemp`" # no-reboot

__INTERNAL_ILIB_ID="tested/dummy"
__INTERNAL_ILIB_PREFIX="testedummy"

__INTERNAL_ELIB_ID="external/dummy"
__INTERNAL_ELIB_PREFIX="externaldummy"

createTemplate(){
  cat > $__INTERNAL_TEST_TEMPLATE << EOF
#!/bin/bash
export TESTID='library-test'
export TEST='beakerlib-library-test'

export BEAKERLIB=BEAKERLIB-ANCHOR
. BEAKERLIB-ANCHOR/beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"

RETVAL=0

rlJournalStart
  rlPhaseStartSetup
    if ! rlImport LIBRARY-ANCHOR
    then
      RETVAL=1
      echo "rlImport failed" >&2
    fi

    if [ "\$RETVAL" != 1 ] && ! eval PREFIX-ANCHORFunction
    then
      RETVAL=1
      echo "Function was not found even when rlImport PASSed" >&2
    fi
  rlPhaseEnd
rlJournalEnd

exit \$RETVAL
EOF
}

createLibraryTemplate(){
  cat > $__INTERNAL_LIB_TEMPLATE << EOF
#!/bin/bash
# library-prefix = PREFIX-ANCHOR

PREFIX-ANCHORFunction() { return 0; }
PREFIX-ANCHORVerify() { return 0; }
EOF
}

spawnTest(){
  local TESTFILE="$1"
  local BEAKERLIB_PATH="$2"
  local LIBRARY="$3"
  local PREFIX="$4"

  cat $__INTERNAL_TEST_TEMPLATE > $TESTFILE

  sed -i -e "s|PREFIX-ANCHOR|$PREFIX|g" $TESTFILE
  sed -i -e "s|LIBRARY-ANCHOR|$LIBRARY|g" $TESTFILE
  sed -i -e "s|BEAKERLIB-ANCHOR|$BEAKERLIB_PATH|g" $TESTFILE
  chmod a+x $TESTFILE
}

spawnLibrary(){
  local LIBDIR="$1"
  local PREFIX="$2"

  cat $__INTERNAL_LIB_TEMPLATE > $LIBDIR/lib.sh

  sed -i -e "s|PREFIX-ANCHOR|$PREFIX|g" $LIBDIR/lib.sh
}

spawnStructure(){
  local ROOTDIR="$1"

  local TESTDIR="${ROOTDIR}/${__INTERNAL_TEST_PATH}"
  local ILIBDIR="${ROOTDIR}/${__INTERNAL_ILIB_PATH}"
  local ELIBDIR="${ROOTDIR}/${__INTERNAL_ELIB_PATH}"

  mkdir -p $TESTDIR
  mkdir -p $ILIBDIR
  mkdir -p $ELIBDIR
}

genericSetup(){
  createTemplate
  createLibraryTemplate
  spawnStructure "$1"
}

genericTeardown(){
  rm -f ${__INTERNAL_TEST_TEMPLATE}
  rm -f ${__INTERNAL_LIB_TEMPLATE}
  rm -rf "$1"
}

templateTest(){
  local LIB_ID="$1"
  local LIB_PR="$2"
  local LIB_PA="$3"

  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"
  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$LIB_ID" "$LIB_PR"
  spawnLibrary "$ROOT/$LIB_PA" "$LIB_PR"
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  if [ $5 -eq 0 ]
  then
    assertTrue "Checking rlImport: $4" ./test.sh
  else
    assertFalse "Checking rlImport: $4" ./test.sh
  fi

  popd >/dev/null
  genericTeardown "$ROOT"
}

test_LibrarySimple(){
  templateTest "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX" "$__INTERNAL_ILIB_PATH" "Internal library" 0
  templateTest "$__INTERNAL_ELIB_ID" "$__INTERNAL_ELIB_PREFIX" "$__INTERNAL_ELIB_PATH" "External library" 0
  templateTest "$__INTERNAL_ILIB_ID" "666thebumberofthebeast" "$__INTERNAL_ILIB_PATH" "Fail for invalid prefix" 1
  templateTest "bad/path" "$__INTERNAL_ILIB_PREFIX" "$__INTERNAL_ILIB_PATH" "Fail for library not found" 1
  templateTest "invalid" "$__INTERNAL_ILIB_PREFIX" "$__INTERNAL_ILIB_PATH" "Fail for invalid ID 1" 1
  templateTest "$__INTERNAL_ILIB_ID/bad" "$__INTERNAL_ILIB_PREFIX" "$__INTERNAL_ILIB_PATH" "Fail for invalid ID 2" 1
}

test_OutsideTestRun(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"

  assertTrue "Checking rlImport: test run from outside its directory" $ROOT/$__INTERNAL_TEST_PATH/test.sh

  genericTeardown "$ROOT"
}

test_MissingVerifyInLib(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"
  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"
  sed -i -e 's/Verify/NoVerify/g' $ROOT/$__INTERNAL_ILIB_PATH/lib.sh
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  assertFalse "Checking rlImport: Fail if prefixVerify function is missing" ./test.sh

  popd >/dev/null
  genericTeardown "$ROOT"
}

test_MultipleImports(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID $__INTERNAL_ELIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ELIB_PATH" "$__INTERNAL_ELIB_PREFIX"
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  assertTrue "Checking rlImport: Multiple correct imports" ./test.sh

  popd >/dev/null
  genericTeardown "$ROOT"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID $__INTERNAL_ELIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ELIB_PATH" "$__INTERNAL_ELIB_PREFIX"
  sed -i -e 's/Verify/NoVerify/g' $ROOT/$__INTERNAL_ILIB_PATH/lib.sh
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  assertFalse "Checking rlImport: Fail for multiple imports, one of them bad" ./test.sh

  popd >/dev/null
  genericTeardown "$ROOT"

}
