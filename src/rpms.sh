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
    if [ "$1" = "--all" ] ; then
        local packages="$PACKAGES $REQUIRES $COLLECTIONS"
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
Returns 1 and asserts FAIL if the specified binary does not  belong to (any of) the given package(s).
Returns 2 and asserts FAIL if the specified binary is not found.
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
    local status=0
    [ $# -eq 0 ] && {
       status=100
       rlLogError "rlAssertBinaryOrigin called without parameters"
       __INTERNAL_ConditionalAssert "Binary $CMD should belong to one rpm of: $PKGS" $status
       return $status
    }

    CMD=$1
    shift

    # if not given explicitly as param, take PKGS from $PACKAGES
    local PKGS=$@
    [ $# -eq 0 ] && PKGS=$PACKAGES

    status=2
    FULL_CMD=$(which $CMD) &>/dev/null && \
    {
        status=1
        # expand symlinks (if any)
        local BINARY=$(readlink -f $FULL_CMD)

        # get the rpm owning the binary
        local BINARY_RPM=$(rpm -qf $BINARY)

        for rpm in $PKGS ; do
            local TESTED_RPM=$(rpm -q $rpm) &>/dev/null && \
            if [ "$TESTED_RPM" = "$BINARY_RPM" ] ; then
                status=0
                echo $BINARY_RPM
                break
            fi
        done
    }

    [ $status -eq 2 ] && rlLogError "$CMD: command not found"

    __INTERNAL_ConditionalAssert "Binary $CMD should belong to one rpm of: $PKGS" $status
    return $status
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

=back

=cut
