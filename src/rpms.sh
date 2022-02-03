# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: rpms.sh - part of the BeakerLib project
#   Description: Package manipulation helpers
#
#   Author: Petr Muller <pmuller@redhat.com>
#   Author: Jan Hutar <jhutar@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#   Author: Ales Zelinka <azelinka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2010 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo "${__INTERNAL_SOURCED}" | grep -qF -- " ${BASH_SOURCE} " && return || __INTERNAL_SOURCED+=" ${BASH_SOURCE} "

: <<'=cut'
=pod

=head1 NAME

BeakerLib - rpms - Package manipulation helpers

=head1 DESCRIPTION

Functions in this BeakerLib script are used for RPM manipulation.

=head1 FUNCTIONS

=cut

. $BEAKERLIB/testing.sh
. $BEAKERLIB/infrastructure.sh

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal Stuff
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# variable indicates presence of 'dnf' on system
which dnf &>/dev/null && __INTERNAL_DNF="dnf" || __INTERNAL_DNF=""

__INTERNAL_RpmPresent() {
    local assert=$1
    local name=$2
    local version=$3
    local release=$4
    local arch=$5
    local IFS

    local package=$name-$version-$release.$arch
    [ "$arch"    == "" ] && package=$name-$version-$release
    [ "$release" == "" ] && package=$name-$version
    [ "$version" == "" ] && package=$name

    export __INTERNAL_RPM_ASSERTED_PACKAGES="$__INTERNAL_RPM_ASSERTED_PACKAGES $name"
    rljRpmLog "$name"

    if [ -n "$package" ]; then
        rpm -q $package
        local status=$?
    else
        local status=100
    fi

    if [ "$assert" == "assert" ] ; then
        __INTERNAL_ConditionalAssert "Checking for the presence of $package rpm" $status
    elif [ "$assert" == "assert_inverted" ] ; then
        if [ $status -eq 1 ]; then
            status=0
        elif [ $status -eq 0 ]; then
            status=1
        fi
        __INTERNAL_ConditionalAssert "Checking for the non-presence of $package rpm" $status
    elif [ $status -eq 0 ] ; then
        rlLog "Package $package is present"
    else
        rlLog "Package $package is not present"
    fi

    if rpm -q --quiet $package
    then
      rlLog "Package versions:"
      rpm -q --qf '%{name}-%{version}-%{release}.%{arch}\n' $package | while read line
      do
        rlLog "  $line"
      done
    fi

    return $status
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckRpm
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head2 Rpm Handling

=head3 rlCheckRpm

Check whether a package is installed.

    rlCheckRpm name [version] [release] [arch]

=over

=item name

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package architucture like C<i386>

=back

Returns 0 if the specified package is installed.

=cut

rlCheckRpm() {
    __INTERNAL_RpmPresent noassert $1 $2 $3 $4
}

# backward compatibility
rlRpmPresent() {
    rlLogWarning "rlRpmPresent is obsoleted by rlCheckRpm"
    __INTERNAL_RpmPresent noassert $1 $2 $3 $4
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertRpm
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertRpm

Assertion making sure that a package is installed.

    rlAssertRpm name [version] [release] [arch]>
    rlAssertRpm --all

=over

=item name

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package architucture like C<i386>

=item --all

Assert all packages listed in the $PACKAGES $REQUIRES and $COLLECTIONS
environment variables.

=back

Returns 0 and asserts PASS if the specified package is installed.

=cut

rlAssertRpm() {
    local package packages
    local IFS
    if [ "$1" = "--all" ] ; then
        packages="$PACKAGES $REQUIRES $COLLECTIONS"
        if [ "$packages" = "  " ] ; then
            __INTERNAL_ConditionalAssert "rlAssertRpm: No package provided" 1
            return
        fi
        for package in $packages ; do
            rlAssertRpm $package
        done
    else
        __INTERNAL_RpmPresent assert $1 $2 $3 $4
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertNotRpm
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertNotRpm

Assertion making sure that a package is not installed. This is
just inverse of C<rlAssertRpm>.

    rlAssertNotRpm name [version] [release] [arch]>

=over

=item name

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package architucture like C<i386>

=back

Returns 0 and asserts PASS if the specified package is not installed.

=head3 Example

Function C<rlAssertRpm> is useful especially in prepare phase
where it causes abort if a package is missing, while
C<rlCheckRpm> is handy when doing something like:

    if ! rlCheckRpm package; then
         yum install package
         rlAssertRpm package
    fi

=cut

rlAssertNotRpm() {
    __INTERNAL_RpmPresent assert_inverted $1 $2 $3 $4
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertBinaryOrigin
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlAssertBinaryOrigin

Assertion making sure that given binary is owned by (one of) the given
package(s).

    rlAssertBinaryOrigin binary package [package2 [...]]
    PACKAGES=... rlAssertBinaryOrigin binary

=over

=item binary

Binary name like C<ksh> or C</bin/ksh>

=item package

List of packages like C<ksh mksh>. The parameter is optional. If missing,
contents of environment variable $PACKAGES are taken into account.

=back

Returns 0 and asserts PASS if the specified binary belongs to (one of) the given package(s).
Returns 1 and asserts FAIL if the specified binary does not belong to (any of) the given package(s).
Returns 2 and asserts FAIL if the specified binary is not found.
Returns 3 and asserts FAIL if no packages are given.
Returns 100 and asserts FAIL if invoked with no parameters.

=head3 Example

Function C<rlAssertBinaryOrigin> is useful especially in prepare phase
where it causes abort if a binary is missing or is owned by different package:

    PACKAGES=mksh rlAssertBinaryOrigin ksh
    or
    rlAssertBinaryOrigin ksh mksh

Returns true if ksh is owned by the mksh package (in this case: /bin/ksh is a
symlink pointing to /bin/mksh).

=cut

rlAssertBinaryOrigin() {
    # without parameters, exit immediatelly
    local status CMD FULL_CMD
    local IFS
    status=0
    [ $# -eq 0 ] && {
       status=100
       rlLogError "rlAssertBinaryOrigin called without parameters"
       __INTERNAL_ConditionalAssert "rlAssertBinaryOrigin: No binary given" $status
       return $status
    }

    CMD=$1
    shift

    # if not given explicitly as param, take PKGS from $PACKAGES
    local PKGS=$@
    [ $# -eq 0 ] && PKGS=$PACKAGES
    if [ -z "$PKGS" ]; then
        status=3
       __INTERNAL_ConditionalAssert "rlAssertBinaryOrigin: No packages given" $status
       return $status
   fi

    status=2
    FULL_CMD=$(which $CMD) &>/dev/null && \
    {
        status=1
        # expand symlinks (if any)
        local BINARY=$(readlink -f $FULL_CMD)

        # get the rpm owning the binary
        local BINARY_RPM=$(rpm -qf --qf="%{name}\n" $BINARY | uniq)

        rlLogDebug "Binary rpm: $BINARY_RPM"

        local TESTED_RPM
        for TESTED_RPM in $PKGS ; do
            if [ "$TESTED_RPM" = "$BINARY_RPM" ] ; then
                status=0
                echo $BINARY_RPM
                break
            fi
        done
    }

    [ $status -eq 2 ] && rlLogError "$CMD: command not found"
    [ $status -eq 1 ] && rlLogError "$BINARY belongs to $BINARY_RPM"

    __INTERNAL_ConditionalAssert "Binary '$CMD' should belong to: $PKGS" $status
    return $status
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetMakefileRequires
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetMakefileRequires

Prints space separated list of requirements defined in Makefile using 'Requires'
attribute.

Return 0 if success.

=cut

rlGetMakefileRequires() {
  [[ -s ./Makefile ]] || {
    rlLogError "Could not find ./Makefile or the file is empty"
    return 1
  }
  grep '"Requires:' Makefile | sed -e 's/.*Requires: *\(.*\)".*/\1/' | tr ' ' '\n' | sort | uniq | tr '\n' ' ' | sed -r 's/^ +//;s/ +$//;s/ +/ /g'
  return 0
}; # end of rlGetMakefileRequires


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetYAMLdeps
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlGetYAMLdeps

Prints space separated list of requirements defined in metadata.yaml using
'require' and / or 'recommend' attribute.

Full fmf ids and library references are to be ignored.

    rlGetYAMLdeps DEP_TYPE [array_var_name]

=over

=item DEP_TYPE

Dependency type defined as a regexp. Expected values are 'require', 'recommend',
or 'require|recommend'. The matching attribute values are then processed.
Defaults to 'require'.

=item array_var_name

Name of the variable to put the output to in a form of an array. This can hold
also dependencies with specific version.
If used, the output to stdout is suppressed.

=back

Return 0 if success.

=cut

rlGetYAMLdeps() {
  local file yaml __deps_var_name __deps type
  __deps_var_name=${2:-__deps}
  eval "$__deps_var_name=()"
  type="${1:-require}"
  file="$BEAKERLIB_DIR/metadata.yaml"
  [[ -s "$file" ]] || {
    rlLogInfo "Could not find $file or the file is empty"
    return 1
  }
  declare -A yaml
  rlYash_parse yaml "$(cat $file)" || return 1
  local i
  for i in `echo " ${!yaml[@]} " | grep -E -o "($type)\.[0-9]+ "`; do
    [[ "${yaml[$i]}" =~ library\(([^\)]+)\) ]] || eval "$__deps_var_name+=( \"\${yaml[\$i]}\" )"
  done

  rlLogDebug "$FUNCNAME(): found deps: `declare -p $__deps_var_name`"
  if [[ -z "$2" ]]; then
    eval "echo \"\${$__deps_var_name[*]}\"" | tr ' ' '\n' | sort | uniq | tr '\n' ' ' | sed -r 's/^ +//;s/ +$//;s/ +/ /g'
  fi
  return 0
}; # end of rlGetYAMLdeps


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckRequirements
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlCheckRequirements

Check that all given requirements are covered eigther by installed package or by
binary available in PATHs or by some package's provides.

    rlRun "rlCheckRequirements REQ..."

=over

=item REQ

Requirement to be checked. It can be package name, provides string or binary
name. Moreover, the requirement can be written the same way as the Require
in the spec file, including the version specification, e.g. "bash >= 4.4".
The comparsion operator may be any of supported by rlTestVersion(), see its
manual.

=back

Returns number of unsatisfied requirements.

=cut
#'

__INTERNAL_req_check() {
  # $1 - a sub-string of a log message
  local msg="$1"

  # note that variables NEVRA, op, res, and LOG are in the local scope of
  # rlCheckRequirements, thus global-like here

  [[ ${NEVRA[1]} == "(none)" ]] && NEVRA[1]=''
  local package="${NEVRA[0]}-${NEVRA[1]:+${NEVRA[1]}:}${NEVRA[2]}-${NEVRA[3]}.${NEVRA[4]}"
  # construct a log message for a requirement
  LOG+=("$package")
  if [[ -n "$ver" ]]; then
    # in case of version specification, construct the found NEVRA (ver1)
    local ver1="${NEVRA[1]:+${NEVRA[1]}:}${NEVRA[2]}-${NEVRA[3]}" ver2="$ver"
    # and add epoch if not present in the versions, defaul epoch is 0
    [[ "$ver1" =~ : ]] || ver1="0:$ver1"
    [[ "$ver2" =~ : ]] || ver2="0:$ver2"
    # do a version relation check, based on the provided operator (op)
    if rlTestVersion "$ver1" "$op" "$ver2"; then
      # construct a log message for a positive version test
      LOG+=("covers $msg '$req $op $ver'" 0 )
    else
      # construct a log message for a negative version test
      LOG+=("does not cover $msg '$req $op $ver'" 1 )
      # propagate the version mismatch to the overall result
      let res++
    fi
  else
    # construct a log message without a version test
    LOG+=("covers $msg '$req'" 0 )
  fi
  # log the package information to journal anyway
  rljRpmLog "$package"
}

rlCheckRequirements() {
  local req ver op res=0 package binary LOG=() LOG2 l=0 ll NEVRA
  local IFS
  for req in "$@"; do
    # parse the requirement to see if there a version specification
    read -r req op ver <<< "$req"
    # query rpm for a package, get NEVRA
    NEVRA=( $(rpm -q --qf "%{name} %{epoch} %{version} %{release} %{arch}" "$req" 2> /dev/null) )
    if [[ $? -eq 0 ]]; then
      # the requirement is a package and it is available, let's process it
      __INTERNAL_req_check 'required package'
    else
      # the requirement is not a package, try a binary presence
      binary="$(command -v "$req")"
      if [[ $? -eq 0 ]]; then
        # the binary is present, let's see what package provides it, get NEVRA
        NEVRA=( $(rpm -q --qf "%{name} %{epoch} %{version} %{release} %{arch}" -f "$binary") )
        # and process it
        __INTERNAL_req_check 'required binary'
      else
        # the requirement was not a command neither, try generic rpm require, get NEVRA
        NEVRA=( $(rpm -q --qf "%{name} %{epoch} %{version} %{release} %{arch}" --whatprovides "$req" 2> /dev/null) )
        if [[ $? -eq 0 ]]; then
          # the requirement is known by rpm, process it
          __INTERNAL_req_check 'requirement'
        else
          # no package nor binary nor generic requirement was found
          rlLogWarning "requirement '$req' not satisfied"
          let res++
        fi
      fi
    fi
  done
  # find the longest package name
  LOG2=("${LOG[@]}")
  while [[ ${#LOG2[@]} -gt 0 ]]; do
    [[ ${#LOG2} -gt $l ]] && l=${#LOG2}
    LOG2=("${LOG2[@]:3}")
  done
  local spaces=''
  for ll in `seq $l`; do spaces="$spaces "; done
  # print all the prepared logs aligned to two columns
  while [[ ${#LOG[@]} -gt 0 ]]; do
    let ll=$l-${#LOG}+1
    if [[ "${LOG[2]}" -eq 0 ]]; then
      rlLogInfo "package '$LOG' ${spaces:0:$ll} ${LOG[1]}"
    else
      rlLogWarning "package '$LOG' ${spaces:0:$ll} ${LOG[1]}"
    fi
    LOG=("${LOG[@]:3}")
  done
  return $res
}; # end of rlCheckRequirements


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckMakefileRequires
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlCheckMakefileRequires

Check presence of required packages / binaries defined in B<metadata.yaml> provided
by C<tmt> or Makefile of the test.

Also check presence of recommended packages / binaries defined in B<metadata.yaml>
provided by C<tmt>. These however do not participate on the return code, these
are just informative.

=head3 Example

    rlRun "rlCheckMakefileRequires"

Return 255 if requirements could not be retrieved, 0 if all requirements are
satisfied or number of unsatisfied requirements.



=cut

rlCheckMakefileRequires() {
  rlLogWarning "$FUNCNAME: considering FMF dependencies through metadata.yaml will be removed in near future"
  rlLogWarning "$FUNCNAME:   use rlCheckDependencies or tandem rlCheckRequired / rlCheckRecommended instead"
  local res=0 req=()
  rlGetRecommended req
  if [[ -n "$req" ]]; then
    rlLogInfo "recommended:"
    rlCheckRequirements "${req[@]}"
  fi
  rlGetRequired req
  res=$?
  if [[ -n "$req" ]]; then
    rlLogInfo "required:"
    rlCheckRequirements "${req[@]}"
    res=$?
  fi
  return $res
}; # end of rlCheckMakefileRequires


: <<'=cut'
=pod

=head3 rlGetRequired
=head3 rlGetRecommended

Get a list of required or recommended packages / binaries defined in
B<metadata.yaml> provided by C<tmt> or in a Makefile of the test.

    rlGetRequired [ARRAY_VAR_NAME]
    rlGetRecommended [ARRAY_VAR_NAME]

=over

=item I<ARRAY_VAR_NAME>

If provided the variable is populated as an array with the respective
dependencies. Otherwise the dependencies are printed out to the I<STDOUT>.

=back

Return 255 if requirements could not be retrieved, 0 otherwise.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetRequired
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rlGetRequired() {
  local __res=0 IFS __deps_var_name ___deps
  __deps_var_name=${1:-___deps}
  eval "$__deps_var_name=()"
  rlGetYAMLdeps 'require' $__deps_var_name || let __res++
  eval "$__deps_var_name+=( \$(rlGetMakefileRequires) ) || let __res++"
  if [[ $__res -lt 2 ]]; then
    if [[ -z "$1" ]]; then
      eval "echo \"\${$__deps_var_name[*]}\""
    fi
    return 0
  else
    return 255
  fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlGetRecommended
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rlGetRecommended() {
  local __res=0 IFS __deps_var_name ___deps
  __deps_var_name=${1:-___deps}
  eval "$__deps_var_name=()"
  rlGetYAMLdeps 'recommend' $__deps_var_name || let __res++
  if [[ $__res -lt 1 ]]; then
    if [[ -z "$1" ]]; then
      eval "echo \"\${$__deps_var_name[*]}\""
    fi
    return 0
  else
    return 255
  fi
}


: <<'=cut'
=pod

=head3 rlCheckRequired
=head3 rlCheckRecommended
=head3 rlCheckDependencies

Check presence of required, recommended or both packages / binaries defined in
B<metadata.yaml> provided by C<tmt> or in a Makefile of the test.

=head3 Example

    rlRun "rlCheckRequired"
    rlRun "rlCheckRecommended"
    rlRun "rlCheckDependencies"

Return 255 if requirements could not be retrieved, 0 if all requirements are
satisfied or number of unsatisfied requirements.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckRequired
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rlCheckRequired() {
  local req=() res
  rlGetRequired req
  res=$?
  if [[ -n "$req" ]]; then
    rlCheckRequirements "${req[@]}"
    res=$?
  fi
  return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckRecommended
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rlCheckRecommended() {
  local req=() res
  rlGetRecommended req
  res=$?
  if [[ -n "$req" ]]; then
    rlCheckRequirements "${req[@]}"
    res=$?
  fi
  return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckDependencies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rlCheckDependencies() {
  local res=0 req=()
  rlGetRecommended req
  res=$?
  if [[ -n "$req" ]]; then
    rlLogInfo "recommended:"
    rlCheckRequirements "${req[@]}"
    res=$?
  fi
  rlGetRequired req
  let res+=$?
  if [[ -n "$req" ]]; then
    rlLogInfo "required:"
    rlCheckRequirements "${req[@]}"
    let res+=$?
  fi
  [[ $res -gt 255 ]] && res=255
  return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertRequired
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlAssertRequired

Ensures that all required packages provided in either metadata.yaml or Makefile
are installed.

    rlAssertRequired

Prints out a verbose list of installed/missing packages during operation.

Returns 0 if all required packages are installed, 1 if one
or more packages are missing or if no Makefile is present.

=cut

rlAssertRequired(){
    local res
    rlCheckRequired
    res=$?

    __INTERNAL_ConditionalAssert "Assert required packages installed" $res

    return $res
}


: <<'=cut'
=pod

=head2 Getting RPMs

=head3 Download methods

Functions handling rpm downloading/installing can use more methods for actual
download of the rpm.

Currently there are two download methonds available:

=over

=item direct

Use use dirct download from build system (brew).

=item yum

Use yumdownloader or dnf download.

=back

The methods and their order are defined by BEAKERLIB_RPM_DOWNLOAD_METHODS
variable as space separated list. By default it is 'direct yum'. This can be
overridden by user.
There may be done also additions  or changes to the original value,
e.g. BEAKERLIB_RPM_DOWNLOAD_METHODS='yum ${BEAKERLIB_RPM_DOWNLOAD_METHODS/yum/}'

=head3

Beakerlib is prepared for more Koji-based sources of packages while usigng
direct download method. By default packages are fetched from Koji, particularly
from https://kojipkgs.fedoraproject.org/packages.

=cut


# return information of the first matching package
# $1 - method (rpm | repoquery)
# $2 - packages (NVR)
__INTERNAL_rpmGetPackageInfo() {
  local tool package_info package_info_raw res=0
  rlLogDebug "${FUNCNAME}(): getting package info for '$2'"

  # On newer systems, repoquery is called with 'dnf repoquery' syntax
  # instead of just 'repoquery'.
  [[ "$1" == "repoquery" ]] && tool="$__INTERNAL_DNF $1" || tool=$1
  package_info_raw="$($tool --qf "%{name} %{version} %{release} %{arch} %{sourcerpm}\n" -q "$2")"

  [[ $? -ne 0 || -z "$package_info_raw" ]] && {
    rlLogDebug "${FUNCNAME}(): package_info_raw: '$package_info_raw'"
    rlLogInfo "rpm '$2' not available using '$tool' tool"
    let res++
  }
  if [[ $res -eq 0 ]]; then
    rlLogDebug "${FUNCNAME}(): package_info_raw: '$package_info_raw'"
    # get first package
    local tmp=( $(echo "$package_info_raw" | head -n 1 ) )
    # extract component name from source_rpm
    package_info="${tmp[@]:0:4} $(__INTERNAL_getNVRA "${tmp[4]/.rpm}")" || {
      rlLogError "parsing package info '$package_info_raw' failed"
      let res++
    }
    rlLogDebug "${FUNCNAME}(): package_info: '$package_info'"
    rlLogDebug "got rpm info for '$2' via '$tool'"
    echo "$package_info"
  fi
  rlLogDebug "${FUNCNAME}(): returning $res"
  return $res
}


BEAKERLIB_rpm_fetch_base_url=( "https://kojipkgs.fedoraproject.org/packages" )
BEAKERLIB_rpm_packageinfo_base_url=( "http://koji.fedoraproject.org/koji" )

# generate combinations for various methods and parameters of finding the package
__INTERNAL_rpmInitUrl() {
    local i j k
    local IFS

    rlLogDebug "${FUNCNAME}(): preparing download variants"

    __INTERNAL_rpmGetNextUrl_phase=()
    for k in rpm repoquery; do
      for j in nvr n; do
        for i in "${BEAKERLIB_rpm_fetch_base_url[@]}"; do
          __INTERNAL_rpmGetNextUrl_phase+=( "$k" ); # tool
          __INTERNAL_rpmGetNextUrl_phase+=( "$j" ); # package_spec
          __INTERNAL_rpmGetNextUrl_phase+=( "$i" ); # base_url
        done
      done
    done
    for j in koji; do
      for i in "${BEAKERLIB_rpm_packageinfo_base_url[@]}"; do
        __INTERNAL_rpmGetNextUrl_phase+=( "$j" ) ; # tool
        __INTERNAL_rpmGetNextUrl_phase+=( "nvra.rpm" )   ; # package_spec
        __INTERNAL_rpmGetNextUrl_phase+=( "$i" ) ; # base_url
      done
    done
    rlLogDebug "${FUNCNAME}(): $(set | grep ^__INTERNAL_rpmGetNextUrl_phase=)"
}


__INTERNAL_WGET() {
  local QUIET CONNREFUSED
  [[ "$1" == "--quiet" ]] && { QUIET=1; shift; }
  local FILE="$1"
  local URL="$2"
  local res=0
  if which curl &> /dev/null; then
    rlLogDebug "$FUNCNAME(): using curl for download"
    QUIET="${QUIET:+--silent}"
    [[ -t 2 ]] || QUIET="${QUIET:---silent --show-error}"
    CONNREFUSED="--retry-connrefused"
    curl --help | grep -q -- $CONNREFUSED || CONNREFUSED=''
    curl --fail $QUIET --location $CONNREFUSED --retry-delay 3 --retry-max-time 3600 --retry 3 --connect-timeout 180 --max-time 1800 --insecure -o $FILE "$URL" || let res++
  elif which wget &> /dev/null; then
    rlLogDebug "$FUNCNAME(): using wget for download"
    QUIET="${QUIET:+--quiet}"
    wget $QUIET -t 3 -T 180 -w 20 --waitretry=30 --no-check-certificate --progress=dot:giga -O $FILE $URL || let res++
  else
    rlLogError "$FUNCNAME(): no tool for downloading web content is available"
    let res++
  fi
  return $res
}

# __INTERNAL_rpmGetNextUrl N V R A | --source N V R
__INTERNAL_rpmGetNextUrl() {
    local source=''
    [[ "$1" == "--source" ]] && {
        source="$1"
        shift
    }
    local N=$1 V=$2 R=$3 A=$4 nil res url
    rlLogDebug "${FUNCNAME}(): process $N-$V-$R.$A"
    while [[ -n "$__INTERNAL_rpmGetNextUrl_phase" ]]; do
      res=0
      local tool=${__INTERNAL_rpmGetNextUrl_phase[0]}
      local package_spec=${__INTERNAL_rpmGetNextUrl_phase[1]}
      local base_url=${__INTERNAL_rpmGetNextUrl_phase[2]}
      #rlLogDebug "${FUNCNAME}(): $(set | grep ^__INTERNAL_rpmGetNextUrl_phase=)"
      rlLogDebug "${FUNCNAME}(): remove first three indices of __INTERNAL_rpmGetNextUrl_phase"
      __INTERNAL_rpmGetNextUrl_phase=( "${__INTERNAL_rpmGetNextUrl_phase[@]:3}" )
      rlLogDebug "trying tool $tool with $package_spec"
      case $tool,$package_spec in
        *,nvr)
          IFS=' ' read nil nil nil nil CN CV CR CA < <(__INTERNAL_rpmGetPackageInfo $tool "$N-$V-$R")
          res=$?
          if [[ -n "$source" ]]; then
            url="$base_url/$CN/$CV/$CR/src/$CN-$CV-$CR.src.rpm"
          else
            url="$base_url/$CN/$CV/$CR/$A/$N-$V-$R.$A.rpm"
          fi
          ;;
        *,n)
          IFS=' ' read nil nil nil nil CN CV CR CA < <(__INTERNAL_rpmGetPackageInfo $tool "$N")
          res=$?
          if [[ -n "$source" ]]; then
            url="$base_url/$CN/$V/$R/src/$CN-$V-$R.src.rpm"
          else
            url="$base_url/$CN/$V/$R/$A/$N-$V-$R.$A.rpm"
          fi
          ;;
        koji,nvra.rpm)
          rlLogDebug "$FUNCNAME(): get rpm info"
          local rpm_info
          if [[ -n "$source" ]]; then
            rpm_info=$(__INTERNAL_WGET - "$base_url/search?match=exact&type=rpm&terms=$N-$V-$R.src.rpm")
          else
            rpm_info=$(__INTERNAL_WGET - "$base_url/search?match=exact&type=rpm&terms=$N-$V-$R.$A.rpm")
          fi
          [[ $? -ne 0 || -z "$rpm_info" ]] && {
            rlLogError "could not download rpm information"
            let res++
            continue
          }
          #[[ "$DEBUG" ]] && rlLogDebug "rpm_info='$rpm_info'"
          local buildurl=$(echo "$rpm_info" | grep Version | grep -o '[^"]*buildID=[^"]*')
          [[ $? -ne 0 || -z "$buildurl" ]] && {
            rlLogError "could not find buildID"
            let res++
            continue
          }
          rlLogDebug "$FUNCNAME(): extracted buildurl='$buildurl'"
          [[ "$buildurl" =~ http ]] || buildurl="$base_url/$buildurl"
          rlLogDebug "$FUNCNAME(): using buildurl='$buildurl'"
          local buildinfo=$(__INTERNAL_WGET - "$buildurl")
          [[ $? -ne 0 || -z "$buildinfo" ]] && {
            rlLogError "could not download build information"
            let res++
            continue
          }
          #[[ -n "$DEBUG" ]] && rlLogDebug "buildinfo='$buildinfo'"
          if [[ -n "$source" ]]; then
            url=$(echo "$buildinfo" | grep download | grep -o 'http[^"]*.src.rpm')
          else
            url=$(echo "$buildinfo" | grep download | grep -o "http[^\"]*/$N-$V-$R.$A.rpm")
          fi
          [[ $? -ne 0 ]] && {
            rlLogError "could not find package url"
            let res++
            continue
          }
          ;;
        *)
          rlLogDebug "$FUNCNAME(): unknown case"
          rlLogError "there's a bug in the code, unknown case!"
          let res++
          break
      esac
      [[ $res -eq 0 ]] && break
    done

    [[ -z "$url" ]] && {
      rlLogError "could not find package url"
      let res++
    }

    rlLogDebug "$FUNCNAME(): using url='$url'"

    [[ $res -eq 0 ]] && __INTERNAL_RETURN_VALUE="$url"

    rlLogDebug "${FUNCNAME}(): returning $res"
    return $res
}


__INTERNAL_getNVRA() {
    rlLogDebug "${FUNCNAME}(): parsing NVRA for '$1'"
    local pat='(.+)-([^-]+)-(.+)\.([^.]+)$'
    [[ "$1" =~ $pat ]] && echo "${BASH_REMATCH[@]:1}"
}


__INTERNAL_rpmDirectDownload() {
    local url pkg quiet=''
    [[ "$1" == "--quiet" ]] && {
      quiet="$1"
      shift
    }

    __INTERNAL_rpmInitUrl
    while __INTERNAL_rpmGetNextUrl "$@"; do
        url="$__INTERNAL_RETURN_VALUE"; unset __INTERNAL_RETURN_VALUE
        local pkg=$(basename "$url")
        rlLog "trying download from '$url'"
        if __INTERNAL_WGET $quiet $pkg "$url"; then
            rlLogDebug "$FUNCNAME(): package '$pkg' was successfully downloaded"
            echo "$pkg"
            return 0
        fi
        rm -f "$pkg"
        rlLogWarning "package '$pkg' was not successfully downloaded"
    done
    rlLogError "package '$pkg' was not successfully downloaded"
    rlLogDebug "${FUNCNAME}(): returning 1"
    return 1
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# __INTERNAL_rpmGetWithYumDownloader
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  Download package using yumdownloader or dnf download

__INTERNAL_rpmGetWithYumDownloader() {
    local source='' quiet='' tool=''
    while [[ "${1:0:2}" == "--" ]]; do
      case $1 in
        --quiet)
          quiet="$1"
        ;;
        --source)
          source="$1"
        ;;
      esac
      shift
    done

    local package="$1-$2-$3.$4"
    [[ -n "$source" ]] && package="$1-$2-$3"

    # Choosing which downloader to use
    tool="yumdownloader"
    # If dnf is on the system, use dnf download
    if [[ "$__INTERNAL_DNF" == "dnf" ]]; then
        tool="dnf download"
    # Otherwise yumdownloader is presumed, check if it's present
    elif ! which yumdownloader &> /dev/null; then
        # If not, try to install it
        rlLogInfo "yumdownloader not installed: attempting to install yum-utils"
        yum install $quiet -y yum-utils >&2
        if ! which yumdownloader &> /dev/null; then
            rlLogError "yumdownloader not installed even after instalation attempt"
            return 1
        fi
    fi

    rlLogDebug "${FUNCNAME}(): Trying '$tool' to download $package"
    local tmp
    if tmp=$(mktemp -d); then
        rlLogDebug "$FUNCNAME(): downloading package to tmp dir '$tmp'"
        ( cd $tmp; $tool $quiet -y $source $package >&2 ) || {
            rlLogError "'$tool' failed"
            rm -rf $tmp
            return 1
        }
        local pkg=$( ls -1 $tmp )
        rlLogDebug "$FUNCNAME(): got '$pkg'"
        local pkg_cnt=$( echo "$pkg" | wc -w )
        rlLogDebug "$FUNCNAME(): pkg_cnt=$pkg_cnt"
        [[ $pkg_cnt -eq 0 ]] && {
            rlLogError "did not download anything"
            rm -rf $tmp
            return 1
        }
        [[ $pkg_cnt -gt 1 ]] && rlLogWarning "got more than one package"
        rm -f $pkg
        rlLogDebug "$FUNCNAME(): moving package to local dir"
        mv $tmp/* ./
        rlLogDebug "$FUNCNAME(): removing tmp dir '$tmp'"
        rm -rf $tmp
        rlLogDebug "$FUNCNAME(): Download with '$tool' successful"
        echo "$pkg"
        return 0
    else
        rlLogError "could not create tmp dir"
        return 1
    fi
}

# magic to allow this:
# BEAKERLIB_RPM_DOWNLOAD_METHODS='yum ${BEAKERLIB_RPM_DOWNLOAD_METHODS/yum/}'
__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default='direct yum'
__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd="BEAKERLIB_RPM_DOWNLOAD_METHODS=\"${BEAKERLIB_RPM_DOWNLOAD_METHODS:-$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default}\""
BEAKERLIB_RPM_DOWNLOAD_METHODS=$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default
eval "$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd"
unset __INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd

__INTERNAL_rpmDownload() {
    local method rpm res
    local IFS

    rlLogDebug "$FUNCNAME(): trying $* with methods '$BEAKERLIB_RPM_DOWNLOAD_METHODS'"

    for method in $BEAKERLIB_RPM_DOWNLOAD_METHODS; do
        rlLogDebug "trying to get the package using method '$method'"
        case $method in
            direct)
                if rpm="$(__INTERNAL_rpmDirectDownload "$@")"; then
                    res=0
                    break
                else
                    rlLogWarning "could not get package using method '$method'"
                    let res++
                fi
            ;;
            yum)
                if rpm="$(__INTERNAL_rpmGetWithYumDownloader "$@")"; then
                    res=0
                    break
                else
                    rlLogWarning "could not get package using method '$method'"
                    let res++
                fi
            ;;
            *)
                rlLogError "invalid fetch method '$method'"
                return 1
            ;;
        esac
    done
    [[ $res -eq 0 ]] && echo "$rpm"
    rlLogDebug "$FUNCNAME(): returning $res"
    return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlRpmInstall
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlRpmInstall

Try to install specified package from local Red Hat sources.

    rlRpmInstall [--quiet] package version release arch

=over

=item --quiet

Make the download and the install process be quiet.

=item package

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package arch like C<i386>

=back

Returns 0 if specified package was installed successfully.

=cut

rlRpmInstall(){
    local quiet=''
    [[ "$1" == "--quiet" ]] && {
      quiet="$1"
      shift
    }

    if [ $# -ne 4 ]; then
        rlLogError "Missing parameter(s)"
        return 1
    fi

    local N=$1;
    local V=$2;
    local R=$3;
    local A=$4;
    rlLog "Installing RPM $N-$V-$R.$A"

    if rlCheckRpm $N $V $R $A; then
        rlLog "$FUNCNAME: $N-$V-$R.$A already present. Doing nothing"
        return 0
    else
        local tmp
        tmp=$(mktemp -d)
        ( cd $tmp; __INTERNAL_rpmDownload $quiet $N $V $R $A )
        if [ $? -eq 0 ]; then
            rlLog "RPM: $N-$V-$R.$A.rpm"
            if [[ -z "$quiet" ]]; then
              rpm -Uhv --oldpackage "$tmp/$N-$V-$R.$A.rpm"
            else
              rpm -Uq --oldpackage "$tmp/$N-$V-$R.$A.rpm"
            fi
            local ECODE=$?
            if [ $ECODE -eq 0 ] ; then
                rlLogInfo "$FUNCNAME: RPM installed successfully"
            else
                rlLogError "$FUNCNAME: RPM installation failed"
            fi
            rm -rf "$tmp"
            return $ECODE
        else
           rlLogError "$FUNCNAME: RPM not found"
        fi
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlRpmDownload
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlRpmDownload

Try to download specified package.

    rlRpmDownload [--quiet] {package version release arch|N-V-R.A}
    rlRpmDownload [--quiet] --source {package version release|N-V-R}

=over

=item --quiet

Make the download process be quiet.

=item package

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package arch like C<i386>

=back

Returns 0 if specified package was downloaded successfully.

=cut

rlRpmDownload(){
    local source='' res pkg N V R A quiet=''
    while [[ "${1:0:2}" == "--" ]]; do
      case $1 in
        --quiet)
          quiet="$1"
        ;;
        --source)
          source="$1"
        ;;
      esac
      shift
    done

    if [[ $# -eq 1 ]]; then
        local package="$1"
        [[ -n "$source" ]] && package="$package.src"
        if ! IFS=' ' read N V R A < <(__INTERNAL_getNVRA "$package"); then
            rlLogError "$FUNCNAME: Bad N.V.R-A format"
            return 1
        fi
    elif [[ -z "$source" && $# -eq 4 ]]; then
        N="$1"
        V="$2"
        R="$3"
        A="$4"
    elif [[ -n "$source" && $# -ge 3 ]]; then
        N="$1"
        V="$2"
        R="$3"
        A=""
    else
        rlLogError "$FUNCNAME: invalid parameter(s)"
        return 1
    fi

    rlLog "$FUNCNAME: Fetching ${source:+source }RPM $N-$V-$R.$A"

    if pkg=$(__INTERNAL_rpmDownload $quiet $source $N $V $R $A); then
        rlLog "RPM: $pkg"
        echo "$pkg"
        return 0
    else
        rlLogError "$FUNCNAME: RPM download failed"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlFetchSrcForInstalled
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlFetchSrcForInstalled

Tries various ways to download source rpm for specified installed rpm.

    rlFetchSrcForInstalled [--quiet] package

=over

=item --quiet

Make the download process be quiet.

=item package

Installed package name like C<kernel>. It accepts in-direct names.
E.g. for the package name C<krb5-libs> the function will download
the C<krb5> source rpm.

=back

Returns 0 if the source package was successfully downloaded.

=cut

rlFetchSrcForInstalled(){
    local quiet=''
    [[ "$1" == "--quiet" ]] && {
      quiet="$1"
      shift
    }

    local PKGNAME=$1 srcrpm
    local N V R nil

    if ! IFS=' ' read N V R nil < <((__INTERNAL_rpmGetPackageInfo rpm "$PKGNAME")); then
        rlLogError "${FUNCNAME[0]}: The package is not installed, can't download the source"
        return 1
    fi
    rlLog "${FUNCNAME[0]}: Fetching source rpm for installed $N-$V-$R"

    if srcrpm="$(__INTERNAL_rpmDownload $quiet --source $N $V $R)"; then
        echo "$srcrpm"
        return 0
    else
        rlLogError "${FUNCNAME[0]}: could not get package"
        return 1
    fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Petr Muller <pmuller@redhat.com>

=item *

Jan Hutar <jhutar@redhat.com>

=item *

Petr Splichal <psplicha@redhat.com>

=item *

Ales Zelinka <azelinka@redhat.com>

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut
