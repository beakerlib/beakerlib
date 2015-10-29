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
