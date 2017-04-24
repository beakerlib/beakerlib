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

__INTERNAL_RpmPresent() {
    local assert=$1
    local name=$2
    local version=$3
    local release=$4
    local arch=$5

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

Prints comma separated list of requirements defined in Makefile using 'Requires'
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
name.

=back

Returns number of unsatisfied requirements.

=cut
#'

rlCheckRequirements() {
  local req res=0 package binary provides LOG=() LOG2 l=0 ll
  for req in "$@"; do
    package="$(rpm -q "$req" 2> /dev/null)"
    if [[ $? -eq 0 ]]; then
      LOG=("${LOG[@]}" "$package" "covers requirement '$req'")
      rljRpmLog "$package"
    else
      binary="$(which "$req" 2> /dev/null)"
      if [[ $? -eq 0 ]]; then
        package="$(rpm -qf "$binary")"
        LOG=("${LOG[@]}" "$package" "covers requirement '$req' by binary '$binary' from package '$package'")
        rljRpmLog "$package"
      else
        package="$(rpm -q --whatprovides "$req" 2> /dev/null)"
        if [[ $? -eq 0 ]]; then
          LOG=("${LOG[@]}" "$package" "covers requirement '$req'")
          rljRpmLog "$package"
        else
          rlLogWarning "requirement '$req' not satisfied"
          let res++
        fi
      fi
    fi
  done
  LOG2=("${LOG[@]}")
  while [[ ${#LOG2[@]} -gt 0 ]]; do
    [[ ${#LOG2} -gt $l ]] && l=${#LOG2}
    LOG2=("${LOG2[@]:2}")
  done
  local spaces=''
  for ll in `seq $l`; do spaces="$spaces "; done
  while [[ ${#LOG[@]} -gt 0 ]]; do
    let ll=$l-${#LOG}+1
    rlLog "package '$LOG' ${spaces:0:$ll} ${LOG[1]}"
    LOG=("${LOG[@]:2}")
  done
  return $res
}; # end of rlCheckRequirements


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlCheckMakefileRequires
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlCheckMakefileRequires

This is just a bit smarted wrapper of

C<rlCheckRequirements $(rlGetMakefileRequires)>

=head3 Example

    rlRun "rlCheckMakefileRequires"

Return 255 if requirements could not be retrieved, 0 if all requirements are
satisfied or number of unsatisfied requirements.



=cut

rlCheckMakefileRequires() {
  local req
  req="$(rlGetMakefileRequires)" || return 255
  eval rlCheckRequirements $req
}; # end of rlCheckMakefileRequires


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlAssertRequired
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<=cut
=pod

=head3 rlAssertRequired

Ensures that all Requires, specified in beakerlib-style beaker-wizard layout
Makefile, are installed.

    rlAssertRequired

Prints out a verbose list of installed/missing packages during operation.

Returns 0 if all required packages are installed, 1 if one
or more packages are missing or if no Makefile is present.

=cut

rlAssertRequired(){
    local MAKEFILE="Makefile"

    if [ ! -e "$MAKEFILE" ]; then
        rlLogError "rlAssertRequired: $MAKEFILE not present"
        return 1
    fi

    list="$(grep 'Requires:' $MAKEFILE)"
    if [ -z "$list" ]; then
        rlLogError "rlAssertRequired: $MAKEFILE does not contain 'Requires:'"
        return 1
    fi

    list=$(echo "$list" | sed -r 's/^[ \t]+@echo "Requires:[ \t]+([^"]+)" >> \$\(METADATA\)$/\1/' | tr '\n' ' ')

    rpm -q $list

    __INTERNAL_ConditionalAssert "Assert required packages installed" $?

    return $?
}


: <<=cut
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

Use yumdownloader.

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
__INTERNAL_rpmGetPackageInfo() {
    local package_info package_info_raw res=0
    rlLogDebug "${FUNCNAME}(): getting package info for '$1'"
    package_info_raw="$(rpm --qf "%{name} %{version} %{release} %{arch} %{sourcerpm}\n" -q "$1")" || {
        rlLogDebug "${FUNCNAME}(): package_info_raw: '$package_info_raw'"
        rlLogInfo "rpm '$1' not installed, trying repoquery"
        package_info_raw="$(repoquery --qf "%{name} %{version} %{release} %{arch} %{sourcerpm}\n" -q "$1")"
    } || {
        rlLogDebug "${FUNCNAME}(): package_info_raw: '$package_info_raw'"
        rlLogError "rpm '$1' not available in any repository"
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
        echo "$package_info"
    fi
    rlLogDebug "${FUNCNAME}(): returning $res"
    return $res
}


__INTERNAL_getNVRA() {
    rlLogDebug "${FUNCNAME}(): parsing NVRA for '$1'"
    local pat='(.+)-([^-]+)-(.+)\.([^.]+)$'
    [[ "$1" =~ $pat ]] && echo "${BASH_REMATCH[@]:1}"
}


__INTERNAL_rpmGetPath() {
    local source=''
    [[ "$1" == "--source" ]] && {
        source="$1"
        shift
    }
    local package="$1"
    local N V R A CN CV CR CA res=0 nil
    if IFS=' ' read N V R A < <(__INTERNAL_getNVRA "$package"); then
        rlLogDebug "${FUNCNAME}(): getting component for $N-$V-$R.$A"
        IFS=' ' read nil nil nil nil CN CV CR CA < <(__INTERNAL_rpmGetPackageInfo "$N") || \
        let res++
    else
        rlLogDebug "${FUNCNAME}(): getting component, N, V, R, and A for $1"
        IFS=' ' read N V R A CN CV CR CA < <(__INTERNAL_rpmGetPackageInfo "$package") || \
        let res++
    fi
    if [[ $res -eq 0 ]]; then
        if [[ -z "$source" ]]; then
            echo "$CN/$CV/$CR/$A/$N-$V-$R.$A.rpm"
        else
            echo "$CN/$CV/$CR/src/$CN-$CV-$CR.src.rpm"
        fi
    else
        rlLogError "rpm path counld not be constructed"
    fi
    rlLogDebug "${FUNCNAME}(): returning $res"
    return $res
}


BEAKERLIB_rpm_fetch_base_url=( "https://kojipkgs.fedoraproject.org/packages" )

__INTERNAL_rpmDirectDownload() {
    local res=0 url pkg baseurl path
    path="$(__INTERNAL_rpmGetPath "$@")" || return 1
    for baseurl in "${BEAKERLIB_rpm_fetch_base_url[@]}"; do
        url="$baseurl/$path"
        local pkg=$(basename "$url")
        rlLog "trying download from '$url'"
        if wget --no-check-certificate -O $pkg "$url" >&2; then
            rlLogDebug "$FUNCNAME(): package '$pkg' was successfully downloaded"
            echo "$pkg"
            return 0
        else
            rlLogDebug "$FUNCNAME(): package '$pkg' was not successfully downloaded"
            let res++
        fi
    done
    rlLogDebug "${FUNCNAME}(): returning $res"
    return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# __INTERNAL_rpmGetWithYumDownloader
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  Download package(s) using yumdownloader

__INTERNAL_rpmGetWithYumDownloader() {
    local source=''
    [[ "$1" == "--source" ]] && {
      source="$1"
      shift
    }
    local package="$1"     # list of packages to download

    rlLogDebug "${FUNCNAME}(): Trying yumdownloader to download $package"
    if ! which yumdownloader &> /dev/null ; then
        rlLog "yumdownloader not installed: attempting to install yum-utils"
        yum install -y yum-utils >&2
    fi

    if ! which yumdownloader &> /dev/null ; then
        rlLogError "yumdownloader not installed even after instalation attempt"
        return 1
    else
        local tmp
        if tmp=$(mktemp -d); then
            rlLogDebug "$FUNCNAME(): downloading package to tmp dir '$tmp'"
            ( cd $tmp; yumdownloader -y $source $package >&2 ) || {
                rlLogError "yum downloader failed"
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
            rlLogDebug "$FUNCNAME(): moving package to local dir"
            mv $tmp/* ./
            rlLogDebug "$FUNCNAME(): removing tmp dir '$tmp'"
            rm -rf $tmp
            rlLogDebug "$FUNCNAME(): Download with yumdownloader successful"
            echo "$pkg"
            return 0
        else
            rlLogError "could not create tmp dir"
            return 1
        fi
    fi
}

# magic to allow this:
# BEAKERLIB_RPM_DOWNLOAD_METHODS="yum ${BEAKERLIB_RPM_DOWNLOAD_METHODS/yum/}"
__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default='direct yum'
__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd="BEAKERLIB_RPM_DOWNLOAD_METHODS=\"${BEAKERLIB_RPM_DOWNLOAD_METHODS:-$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default}\""
BEAKERLIB_RPM_DOWNLOAD_METHODS=$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_default
eval "$__INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd"
unset __INTERNAL_BEAKERLIB_RPM_DOWNLOAD_METHODS_cmd

__INTERNAL_rpmDownload() {
    local method rpm res

    rlLogDebug "$FUNCNAME(): trying $* with methods '$BEAKERLIB_RPM_DOWNLOAD_METHODS'"

    for method in $BEAKERLIB_RPM_DOWNLOAD_METHODS; do
        rlLogInfo "trying to get the package using method '$method'"
        case $method in
            direct)
                if rpm="$(__INTERNAL_rpmDirectDownload "$@")"; then
                    res=0
                    break
                else
                    rlLogWarning "could not get package unsing method '$method'"
                    let res++
                fi
            ;;
            yum)
                if rpm="$(__INTERNAL_rpmGetWithYumDownloader "$@")"; then
                    res=0
                    break
                else
                    rlLogWarning "could not get package unsing method '$method'"
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

    rlRpmInstall package version release arch

=over

=item package

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package arch like C<i386>

=back

Returns 0 if specified package was installed succesfully.

=cut

rlRpmInstall(){

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
        local tmp=$(mktemp -d)
        ( cd $tmp; __INTERNAL_rpmDownload "$N-$V-$R.$A" )
        if [ $? -eq 0 ]; then
            rlLog "RPM: $N-$V-$R.$A.rpm"
            rpm -Uhv --oldpackage "$tmp/$N-$V-$R.$A.rpm"
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

    rlRpmDownload package version release arch
    rlRpmDownload --source package version release
    rlRpmDownload N-V-R.A
    rlRpmDownload --source N-V-R

=over

=item package

Package name like C<kernel>

=item version

Package version like C<2.6.25.6>

=item release

Package release like C<55.fc9>

=item arch

Package arch like C<i386>

=back

Returns 0 if specified package was downloaded succesfully.

=cut

rlRpmDownload(){
    local source='' NVRA res pkg
    [[ "$1" == "--source" ]] && {
      source="$1"
      shift
    }
    if [[ $# -eq 1 ]]; then
        local package="$1"
        [[ -n "$source" ]] && package="$package.src"
        if ! __INTERNAL_getNVRA "$package" > /dev/null; then
            rlLogError "$FUNCNAME: Bad N.V.R-A format"
            return 1
        fi
       NVRA="$1"
    elif [[ -z "$source" && $# -eq 4 ]]; then
        NVRA="$1-$2-$3.$4"
    elif [[ -n "$source" && $# -ge 3 ]]; then
        NVRA="$1-$2-$3"
    else
        rlLogError "$FUNCNAME: invalid parameter(s)"
        return 1
    fi

    rlLog "$FUNCNAME: Fetching ${source:+source }RPM $NVRA"

    if pkg=$(__INTERNAL_rpmDownload $source "$NVRA"); then
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

    rlFetchSrcForInstalled package

=over

=item package

Installed package name like C<kernel>. It accepts in-direct names.
Eg for the package name C<krb5-libs> will the function download
the C<krb5> source rpm.

=back

Returns 0 if the source package was succesfully downloaded.

=cut

rlFetchSrcForInstalled(){
    local PKGNAME=$1 srcrpm
    if ! PKG=$(rpm -q ${PKGNAME}); then
        rlLogError "$FUNCNAME: The package is not installed, can't download the source"
        return 1
    fi
    rlLog "$FUNCNAME: Fetching source rpm for installed $PKG"

    if srcrpm="$(__INTERNAL_rpmDownload --source "$PKG")"; then
        echo "$srcrpm"
        return 0
    else
        rlLogError "$FUNCNAME: could not get package"
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
