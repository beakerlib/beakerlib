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

  assertTrue "rlAssertRpm returns 0 on installed 'N' package" \
    "rlAssertRpm $first_n"
  assertTrue "rlAssertRpm returns 0 on installed 'NV' package" \
    "rlAssertRpm $first_n $first_v"
  assertTrue "rlAssertRpm returns 0 on installed 'NVR' package" \
    "rlAssertRpm $first_n $first_v $first_r"
  assertTrue "rlAssertRpm returns 0 on installed 'NVRA' package" \
    "rlAssertRpm $first_n $first_v $first_r $first_a"

  assertRun "rlAssertRpm" 100 \
        "rlAssertRpm returns 100 when invoked without parameters"

  assertFalse "rlAssertRpm returns non-0 on not-installed 'N' package" \
    "rlAssertRpm $first_n-not-installed-package"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NV' package" \
    "rlAssertRpm $first_n $first_v.1.2.3"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NVR' package" \
    "rlAssertRpm $first_n $first_v $first_r.1.2.3"
  assertFalse "rlAssertRpm returns non-0 on not-installed 'NVRA' package" \
    "rlAssertRpm $first_n $first_v $first_r ${first_a}xyz"

  assertGoodBad "rlAssertRpm ahsgqyrg" 0 1

  : > $OUTPUTFILE
  local PACKAGES=$( rpm -qa --qf "%{NAME} " | awk '{ print $1  " "  $2  }' )
  local PACKAGES2=$PACKAGES
  local COLLECTIONS=$( rpm -qa --qf "%{NAME} " | awk '{ print $3  " "  $4  }' )
  local REQUIRES=$( rpm -qa --qf "%{NAME} " | awk '{ print $5  " "  $6  }' )

  assertTrue "Running rlAssertRpm --all with PACKAGES=$PACKAGES COLLECTIONS=$COLLECTIONS REQUIRES=$REQUIRES" \
    "rlAssertRpm --all >$OUTPUTFILE"

  for pkg in $PACKAGES $COLLECTIONS $REQUIRES ; do
    assertTrue "Checking log for $pkg" \
        "grep -q '$pkg' $OUTPUTFILE"
  done

  unset PACKAGES
  assertTrue "Running rlAssertRpm --all with PACKAGES=$PACKAGES COLLECTIONS=$COLLECTIONS REQUIRES=$REQUIRES" \
    "rlAssertRpm --all >$OUTPUTFILE"

  for pkg in $PACKAGES $COLLECTIONS $REQUIRES ; do
    assertTrue "Checking log for $pkg" \
        "grep -q '$pkg' $OUTPUTFILE"
  done
  for pkg in $PACKAGES2 ; do
    assertFalse "Checking log for not containing $pkg" \
        "grep -q '$pkg' $OUTPUTFILE"
  done
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

  assertRun "rlAssertNotRpm" 100 \
    "rlAssertNotRpm returns 100 when run without parameters"

  assertTrue "rlAssertNotRpm returns 0 on not-installed 'N' package" \
    "rlAssertNotRpm $first_n-not-installed-package"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NV' package" \
    "rlAssertNotRpm $first_n $first_v.1.2.3"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NVR' package" \
    "rlAssertNotRpm $first_n $first_v $first_r.1.2.3"
  assertTrue "rlAssertNotRpm returns 0 on not-installed 'NVRA' package" \
    "rlAssertNotRpm $first_n $first_v $first_r ${first_a}xyz"

  assertGoodBad "rlAssertNotRpm $first_n" 0 1
}

test_rlCheckRpm() {
  local first=$( rpm -qa --qf "%{NAME}.%{ARCH}\n" | tail -n 1 )
  local first_n=$( rpm -q $first --qf "%{NAME}\n" | tail -n 1 )
  local first_v=$( rpm -q $first --qf "%{VERSION}\n" | tail -n 1 )
  local first_r=$( rpm -q $first --qf "%{RELEASE}\n" | tail -n 1 )
  local first_a=$( rpm -q $first --qf "%{ARCH}\n" | tail -n 1 )

  : > $OUTPUTFILE
  assertTrue "rlCheckRpm returns 0 on installed 'N' package" \
    "rlCheckRpm $first_n"
  assertTrue "rlCheckRpm returns 0 on installed 'NV' package" \
    "rlCheckRpm $first_n $first_v"
  assertTrue "rlCheckRpm returns 0 on installed 'NVR' package" \
    "rlCheckRpm $first_n $first_v $first_r"
  assertTrue "rlCheckRpm returns 0 on installed 'NVRA' package" \
    "rlCheckRpm $first_n $first_v $first_r $first_a"
  assertTrue "Checking log for $first_n" \
        "grep -q '$first_n' $OUTPUTFILE"

  assertRun "rlCheckRpm" 100 "rlCheckRpm returns non-0 when run without parameters"

  : > $OUTPUTFILE
  assertFalse "rlCheckRpm returns non-0 on not-installed 'N' package" \
    "rlCheckRpm $first_n-not-installed-package"
  assertFalse "rlCheckRpm returns non-0 on not-installed 'NV' package" \
    "rlCheckRpm $first_n $first_v.1.2.3"
  assertFalse "rlCheckRpm returns non-0 on not-installed 'NVR' package" \
    "rlCheckRpm $first_n $first_v $first_r.1.2.3"
  assertFalse "rlCheckRpm returns non-0 on not-installed 'NVRA' package" \
    "rlCheckRpm $first_n $first_v $first_r ${first_a}xyz"
  assertTrue "Checking log for $first_n" "grep -q '$first_n' $OUTPUTFILE"

  assertGoodBad "rlCheckRpm ahsgqyrg" 0 0
}

test_rlRpmPresent(){
    assertTrue "rlrpmPresent is reported to be obsoleted" "rlRpmPresent abcdefg 2>&1 >&- |grep -q obsolete"
}

test_rlAssertBinaryOrigin(){
  rlPhaseStartTest &>/dev/null
  #existing binary command
  assertTrue "rlAssertBinaryOrigin returns 0 on existing command owned by the package (param)" \
      "rlAssertBinaryOrigin bash bash"

  #existing binary command
  assertTrue "rlAssertBinaryOrigin returns 0 on existing command owned by the package (env)" \
      "PACKAGES='bash' rlAssertBinaryOrigin bash"

  #existing binary command in more packages
  assertTrue "rlAssertBinaryOrigin returns 0 on existing command owned by one of the packages" \
      "rlAssertBinaryOrigin bash bash ksh pdksh"

  #existing binary full path
  assertTrue "rlAssertBinaryOrigin returns 0 on existing full path command owned by the package" \
      "rlAssertBinaryOrigin /bin/bash bash"

  #exisiting alternative
  local PKG=$(rpm -qf --qf="%{name}\n" $( ls -l $( ls -l /usr/bin | grep alternatives | head -n1 | awk '{ print $NF }' ) | awk '{ print $NF }' ))
  local BIN1=$( ls -l /usr/bin | grep alternatives | head -n1 | awk '{ print $8 }' )
  local BIN2=$( ls -l /usr/bin | grep alternatives | head -n1 | awk '{ print $9 }' )
  if [ -e "/usr/bin/$BIN1" ]
  then
    BIN=$BIN1
  elif [ -e "/usr/bin/$BIN2" ]
  then
    BIN=$BIN2
  fi

  assertTrue "rlAssertBinaryOrigin returns 0 on existing alternative command owned by the packages" \
        "rlAssertBinaryOrigin $BIN $PKG"

  #binary not in package
  assertRun "rlAssertBinaryOrigin bash glibc" 1 \
        "rlAssertBinaryOrigin returns 1 on existing full path command owned by different package"
  #non-existing package
  assertRun "rlAssertBinaryOrigin bash rpm-not-found" 1 \
        "rlAssertBinaryOrigin returns 1 on non-existing package"
  #non-existing binary
  assertRun "rlAssertBinaryOrigin command-not-found bash" 2 \
        "rlAssertBinaryOrigin returns 2 on non-existing command"
  #no params
  assertRun "rlAssertBinaryOrigin" 100 \
        "rlAssertBinaryOrigin returns 100 when invoked without parameters"
  rlPhaseEnd &> /dev/null
}
