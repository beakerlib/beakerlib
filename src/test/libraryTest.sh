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

__INTERNAL_TEST_TEMPLATE="$( mktemp )" # no-reboot
__INTERNAL_LIB_TEMPLATE="$( mktemp )" # no-reboot

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

DEBUG=1

COMMAND-ANCHOR

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
rm -rf \$BEAKERLIB_DIR
exit \$RETVAL
EOF
}

createLibraryTemplate(){
  cat > $__INTERNAL_LIB_TEMPLATE << EOF
#!/bin/bash
# library-prefix = PREFIX-ANCHOR

PREFIX-ANCHORFunction() { return 0; }
PREFIX-ANCHORLibraryLoaded() { return 0; }
EOF
}

spawnTest(){
  local TESTFILE="$1"
  local BEAKERLIB_PATH="$2"
  local LIBRARY="$3"
  local PREFIX="$4"
  local COMMAND="$5"
  local FUNCTION="$6"

  mkdir -p "$( dirname $TESTFILE )"
  cat $__INTERNAL_TEST_TEMPLATE > $TESTFILE

  [[ -n "$FUNCTION" ]] && sed -i -e "s|PREFIX-ANCHORFunction|$FUNCTION|g" $TESTFILE
  sed -i -e "s|PREFIX-ANCHOR|$PREFIX|g" $TESTFILE
  sed -i -e "s|LIBRARY-ANCHOR|$LIBRARY|g" $TESTFILE
  sed -i -e "s|BEAKERLIB-ANCHOR|$BEAKERLIB_PATH|g" $TESTFILE
  sed -i -e "s|COMMAND-ANCHOR|$COMMAND|g" $TESTFILE

  chmod a+x $TESTFILE
  [[ "$DEBUG" == "1" ]] && cat $TESTFILE
}

spawnLibrary(){
  local LIBDIR="$1"
  local PREFIX="$2"

  mkdir -p $LIBDIR

  cat $__INTERNAL_LIB_TEMPLATE > $LIBDIR/lib.sh

  sed -i -e "s|PREFIX-ANCHOR|$PREFIX|g" $LIBDIR/lib.sh

  [[ "$DEBUG" == "1" ]] && cat $LIBDIR/lib.sh
}

spawnStructure(){
  local ROOTDIR="$1"
  mkdir -p "$ROOTDIR"
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

test_WeirdNames(){
  for weird_character in "_" "-" "+" "5" "."
  do
    local weird_libname="weird${weird_character}library"
    local weird_component="weird${weird_character}component"

    templateTest "tested/$weird_libname" "weirdlib" "tested/Library/$weird_libname" "Library with '$weird_character' in name" 0
    templateTest "$weird_component/weirdlib" "weirdlib" "$weird_component/Library/weirdlib" "Library in component with '$weird_character' in name" 0
  done
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

test_ImportAllNoLib(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "--all" "$__INTERNAL_ILIB_PREFIX" '' true
  echo "" > "$ROOT/$__INTERNAL_TEST_PATH/Makefile"
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null
  assertTrue "Checking rlImport --all" ./test.sh
  popd >/dev/null

  genericTeardown "$ROOT"
}

test_ImportAll(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "--all" "$__INTERNAL_ILIB_PREFIX"
  echo "RhtsRequires: library($__INTERNAL_ILIB_ID)" > "$ROOT/$__INTERNAL_TEST_PATH/Makefile"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"

  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null
  assertTrue "Checking rlImport --all" ./test.sh
  popd >/dev/null

  genericTeardown "$ROOT"
}

test_ImportAllAfterPushd(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"

  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "--all" "$__INTERNAL_ILIB_PREFIX" "pushd $(mktemp -d)"
  echo "RhtsRequires: library($__INTERNAL_ILIB_ID)" > "$ROOT/$__INTERNAL_TEST_PATH/Makefile"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"

  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null
  assertTrue "Checking rlImport --all: test does pushd before rlImport --all" ./test.sh
  popd >/dev/null

  genericTeardown "$ROOT"
}

test_DifferentRoot(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"
  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"

  local DIFFERENT_ROOT=$(mktemp -d) # no-reboot
  mkdir -p $DIFFERENT_ROOT/tested/Library
  mv $ROOT/$__INTERNAL_ILIB_PATH $DIFFERENT_ROOT/tested/Library/

  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  export BEAKERLIB_LIBRARY_PATH=$DIFFERENT_ROOT
  assertTrue "Checking rlImport: Library in BEAKERLIB_LIBRARY_PATH is found" ./test.sh
  unset BEAKERLIB_LIBRARY_PATH

  popd >/dev/null
  genericTeardown "$ROOT"
  rm -rf $DIFFERENT_ROOT
}

test_DifferentRootWithNamespace(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"
  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"

  local DIFFERENT_ROOT=$(mktemp -d) # no-reboot
  mkdir -p $DIFFERENT_ROOT/CoreOS/tested/Library
  mv $ROOT/$__INTERNAL_ILIB_PATH $DIFFERENT_ROOT/CoreOS/tested/Library/

  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  export BEAKERLIB_LIBRARY_PATH=$DIFFERENT_ROOT
  assertTrue "Checking rlImport: Namespaced library in BEAKERLIB_LIBRARY_PATH is found" ./test.sh
  unset BEAKERLIB_LIBRARY_PATH

  popd >/dev/null
  genericTeardown "$ROOT"
  rm -rf $DIFFERENT_ROOT
}

test_MissingLibraryLoadedInLib(){
  local ROOT=$(mktemp -d) # no-reboot
  local TESTFILE="$ROOT/$__INTERNAL_TEST_PATH/test.sh"
  genericSetup "$ROOT"
  spawnTest "$TESTFILE" "$(pwd)/.." "$__INTERNAL_ILIB_ID" "$__INTERNAL_ILIB_PREFIX"
  spawnLibrary "$ROOT/$__INTERNAL_ILIB_PATH" "$__INTERNAL_ILIB_PREFIX"
  sed -i -e 's/LibraryLoaded/NoLibraryLoaded/g' $ROOT/$__INTERNAL_ILIB_PATH/lib.sh
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  assertFalse "Checking rlImport: Fail if prefixLibraryLoaded function is missing" ./test.sh

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
  sed -i -e 's/LibraryLoaded/NoLibraryLoaded/g' $ROOT/$__INTERNAL_ILIB_PATH/lib.sh
  pushd $ROOT/$__INTERNAL_TEST_PATH >/dev/null

  assertFalse "Checking rlImport: Fail for multiple imports, one of them bad" ./test.sh

  popd >/dev/null
  genericTeardown "$ROOT"

}
