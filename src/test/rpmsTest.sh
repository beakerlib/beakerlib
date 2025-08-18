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
  local path=$( ls -l /usr/bin | grep alternatives | head -n1 | awk '{ print $NF }' ) 
  local PKG
 
  if [ -f "$path" ]; then
	PKG=$(rpm -qf --qf="%{name}\n" $( ls -l $path | awk '{ print $NF }' ))
  fi
  
  if [ ! -f  "$path" ]; then
	PKG=$(rpm -qf --qf="%{name}\n" $( ls -l /usr/bin/$path | awk '{ print $NF }' ))
  fi

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
test_rlRpmDownload(){
  v=$(rpm -q beakerlib | head -n1)
  assertTrue "rlRpmDownload successfully downloads beakerlib" "rlRpmDownload --quiet $v"
  assertTrue "Check for downloaded file" "ls $v.rpm"
  rm -f beakerlib-*
}

test_rlRpmInstall(){
        rpm_string=$(rpm -q beakerlib | head -n1)

	parsed_string=$(echo "$rpm_string" | sed -r 's/^beakerlib-([0-9]+\.[0-9]+\.[0-9]+)-([^-]+)\.([^-]+)$/v=\1 d=\2 a=\3/')

	eval "$parsed_string"

	assertTrue "rlRpmInstall successfully installs beakerlib" "rlRpmInstall --quiet beakerlib $v $d $a"
  	assertTrue "Check for installed package" "rlCheckRpm beakerlib $v $d $a"
}

test_rlGetRequired(){
        echo '  @echo "Requires: selinux-policy"' >> Makefile 
        local MY_DEPS
        rlGetRequired MY_DEPS
        assertTrue "rlGetRequired should find 'selinux-policy'" '[ "${MY_DEPS[*]}" == "selinux-policy" ]'
#       echo "Dependencies found (1): ${MY_DEPS[*]}"
        head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"

        echo '  @echo "Requires: selinux-policy bash"' >> Makefile
        local MY_DEPS # Re-declare local to ensure it's empty
        rlGetRequired MY_DEPS
        assertTrue "rlGetRequired should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'
#       echo "Dependencies found (2): ${MY_DEPS[*]}"
        head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"

        echo '  @echo "Requires: selinux-policy"' >> Makefile
        echo '  @echo "Requires: bash"' >> Makefile
        local MY_DEPS # Re-declare local
        rlGetRequired MY_DEPS
        assertTrue "rlGetRequired should find 'selinux-policy bash' from two lines" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'
#       echo "Dependencies found (3): ${MY_DEPS[*]}"    
        head -n -2 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"
}

test_rlGetRecommended(){
    local lib="$BEAKERLIB_DIR/metadata.yaml"
    echo 'recommend: [ selinux-policy ]"' >> $lib 
    local MY_DEPS
    rlGetRecommended MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetRecommended should find 'selinux-policy'" '[ "${MY_DEPS[*]}" == "selinux-policy" ]'
    
    echo 'recommend: [ selinux-policy, bash ]"' >> $lib 
    local MY_DEPS
    rlGetRecommended MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetRecommended should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'

    echo 'recommend:' >> $lib 
    echo '  - selinux-policy' >> $lib 
    echo '  - bash' >> $lib 
    local MY_DEPS
    rlGetRecommended MY_DEPS
    head -n -3 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetRecommended should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'
}

test_rlGetYAMLdeps(){
    local lib="$BEAKERLIB_DIR/metadata.yaml"
    echo 'recommend: [ selinux-policy ]"' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'recommend' MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'recommend' should find 'selinux-policy'" '[ "${MY_DEPS[*]}" == "selinux-policy" ]'

    echo 'recommend: [ selinux-policy, bash ]"' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'recommend' MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'recommend' should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'

    echo 'recommend:' >> $lib 
    echo '  - selinux-policy' >> $lib 
    echo '  - bash' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'recommend' MY_DEPS
    head -n -3 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'recommend' should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "bash selinux-policy" ]'

    echo 'require: [ selinux-policy ]"' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'require' MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'require' should find 'selinux-policy'" '[ "${MY_DEPS[*]}" == "selinux-policy" ]'

    echo 'require: [ selinux-policy, bash ]"' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'require' MY_DEPS
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'require' should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "selinux-policy bash" ]'

    echo 'require:' >> $lib 
    echo '  - selinux-policy' >> $lib 
    echo '  - bash' >> $lib 
    local MY_DEPS
    rlGetYAMLdeps 'require' MY_DEPS
    head -n -3 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
    assertTrue "rlGetYAMLdeps 'require' should find 'selinux-policy bash'" '[ "${MY_DEPS[*]}" == "selinux-policy bash" ]'

}


test_rlGetMakefileRequires(){
    echo '  @echo "Requires: selinux-policy"' >> Makefile
    local MY_DEPS=$(rlGetMakefileRequires)
    assertTrue "rlGetMakefileRequires should find 'selinux-policy'" '[ $MY_DEPS == "selinux-policy" ]'
    head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"

    echo '  @echo "Requires: selinux-policy bash"' >> Makefile
    local MY_DEPS=$(rlGetMakefileRequires)
    assertTrue "rlGetMakefileRequires should find 'selinux-policy bash'" '[ "$MY_DEPS" == "bash selinux-policy" ]'
    head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"

    echo '  @echo "Requires: selinux-policy"' >> Makefile
    echo '  @echo "Requires: bash"' >> Makefile
    local MY_DEPS=$(rlGetMakefileRequires)
    assertTrue "rlGetMakefileRequires should find 'selinux-policy bash' from two lines" '[ "$MY_DEPS" == "bash selinux-policy" ]'
    head -n -2 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"

}


test_rlCheckRequirements(){
    assertTrue "rlCheckRequirements bash" 'rlCheckRequirements "bash"'
	assertTrue "rlCheckRequirements bash >= 4.4" 'rlCheckRequirements "bash >= 4.4"'
	assertTrue "rlCheckRequirements bash > 4.4" 'rlCheckRequirements "bash > 4.4"'
	assertFalse "rlCheckRequirements bash <= 4.4" 'rlCheckRequirements "bash <= 4.4"'
	assertFalse "rlCheckRequirements bash < 4.4" 'rlCheckRequirements "bash < 4.4"'
	assertFalse "rlCheckRequirements bash = 4.4" 'rlCheckRequirements "bash == 4.4"'
	assertFalse "rlCheckRequirements EMPTY" 'rlCheckRequirements ""'
	assertTrue "rlCheckRequirements more" 'rlCheckRequirements "bash" "nc" "Xvfb" "chkconfig" "patch"'
}

test_rlCheckRequired(){
	assertTrue "rlCheckRequired EMPTY" 'rlCheckRequired'
 	
	local lib="$BEAKERLIB_DIR/metadata.yaml"

	echo '  @echo "Requires: htop"' >> Makefile 
    echo 'require: [ bash ]"' >> $lib 

	assertFalse "rlCheckRequired should fail due to htop" 'rlCheckRequired'
	head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"
	assertTrue "rlCheckRequired bash" 'rlCheckRequired'
	head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"

}

test_rlCheckRecommended(){
	
    local lib="$BEAKERLIB_DIR/metadata.yaml"
	echo 'recommend: ' >> $lib
    echo '  - python3' >> $lib
    echo '  - selinux-policy' >> $lib	
    echo 'recommend: [ bash ]' >> $lib # Note the tab
	
    rlGetRecommended vr
    assertTrue "rlCheckRecommended bash" 'rlCheckRecommended'
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
        
	echo 'recommend: [ bash, htop ]' >> $lib # Note the tab 
	assertFalse "rlCheckRecommended bash" 'rlCheckRecommended'
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
	
	echo 'recommend: ' >> $lib
	echo '  - bash' >> $lib
	echo '  - selinux-policy' >> $lib
	assertTrue "rlCheckRecommended more lines" 'rlCheckRecommended'
    head -n -3 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"

}

test_rlCheckMakefileRequires(){
	assertTrue "rlCheckMakefileRequires EMPTY" 'rlCheckMakefileRequires'

    local lib="$BEAKERLIB_DIR/metadata.yaml"

    echo '  @echo "Requires: htop"' >> Makefile 
    echo 'require: [ bash ]' >> $lib 

    assertFalse "rlCheckMakefileRequires should fail due to htop" 'rlCheckMakefileRequires'
    head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"
    assertTrue "rlCheckMakefileRequires bash" 'rlCheckMakefileRequires'
    head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"

}

test_rlCheckDependencies(){
		
    local lib="$BEAKERLIB_DIR/metadata.yaml"
    echo '  @echo "Requires: htop"' >> Makefile 
    echo 'require:' >> $lib 
	echo '  - bash' >> $lib

	assertFalse 'rlCheckDependencies should fail' 'rlCheckDependencies'

    head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"


	assertTrue 'rlCheckDependencies only bash' 'rlCheckDependencies'
    echo 'recommend:' >> $lib
	echo '  - htop' >> $lib

	assertFalse 'rlCheckDependencies should fail' 'rlCheckDependencies'
	
	head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
	echo '  - python3' >> $lib
	
	assertTrue 'rlCheckDependencies only bash' 'rlCheckDependencies'

    echo '  @echo "Requires: htop"' >> Makefile 

	assertFalse 'rlCheckDependencies should fail' 'rlCheckDependencies'
    head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"
	head -n -4 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"
}

test_rlAssertRequired(){
	assertTrue "rlAssertRequired EMPTY" 'rlAssertRequired'
 	
	local lib="$BEAKERLIB_DIR/metadata.yaml"

	echo '  @echo "Requires: htop"' >> Makefile 
    echo 'require: [ bash ]' >> $lib 

	assertFalse "rlAssertRequired should fail due to htop" 'rlAssertRequired'
	head -n -1 "Makefile" > "temp.txt" && mv "temp.txt" "Makefile"
	assertTrue "rlAssertRequired bash" 'rlAssertRequired'
	head -n -1 "$lib" > "$BEAKERLIB_DIR/temp.txt" && mv "$BEAKERLIB_DIR/temp.txt" "$lib"

}
test_rlFetchSrcForInstalled(){

    assertTrue "rlFetchSrcForInstalled succesfully downloads beakerlib" 'rlFetchSrcForInstalled --quiet beakerlib'
    assertTrue "Check for file" 'ls beakerlib*.rpm'
	rm -f beakerlib*.rpm

}

test_rlYash_parse(){
	assertTrue "coverd by test_rlGetYAMLdeps and any test_rlGetRecommend or rlGetRequire" 'echo ""'
}
