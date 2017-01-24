# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: beakerlib.sh - part of the BeakerLib project
#   Description: The main BeakerLib script
#
#   Author: Petr Muller <pmuller@redhat.com>
#   Author: Ondrej Hudlicky <ohudlick@redhat.com>
#   Author: Jan Hutar <jhutar@redhat.com>
#   Author: Petr Splichal <psplicha@redhat.com>
#   Author: Ales Zelinka <azelinka@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#   Author: Martin Kyral <mkyral@redhat.com>
#   Author: Jakub Prokes <jprokes@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2012 Red Hat, Inc. All rights reserved.
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

=for comment beakerlib-manual-header

=head1 NAME

BeakerLib - a shell-level integration testing library

=head1 DESCRIPTION

BeakerLib is a shell-level integration testing library, providing
convenience functions which simplify writing, running and analysis of
integration and blackbox tests.

The essential features include:

=over

=item

B<Journal> - uniform logging mechanism (logs & results saved in flexible XML
format, easy to compare results & generate reports)

=item

B<Phases> - logical grouping of test actions, clear separation of setup / test
/ cleanup (preventing false fails)

=item

B<Asserts> - common checks affecting the overall results of the individual
phases (checking for exit codes, file existence & content...)

=item

B<Helpers> - convenience functions for common operations such as managing
services, backup & restore

=back

The main script sets the C<BEAKERLIB> variable and sources other scripts where
the actual functions are defined. You should source it at the beginning of your
test with:

    . /usr/share/beakerlib/beakerlib.sh

See the EXAMPLES section for quick start inspiration.

See the BKRDOC section for more information about Automated documentation generator for BeakerLib tests.

=cut

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# beakerlib-manual-include
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:<<'=cut'

=pod

=for comment beakerlib-manual-footer

=head1 EXAMPLES

=head2 Simple

A minimal BeakerLib test can look like this:

    . /usr/share/beakerlib/beakerlib.sh

    rlJournalStart
        rlPhaseStartTest
            rlAssertRpm "setup"
            rlAssertExists "/etc/passwd"
            rlAssertGrep "root" "/etc/passwd"
        rlPhaseEnd
    rlJournalEnd

=head2 Phases

Here comes a bit more interesting example of a test which sets all
the recommended variables and makes use of the phases:

    # Include the BeakerLib environment
    . /usr/share/beakerlib/beakerlib.sh

    # Set the full test name
    TEST="/examples/beakerlib/Sanity/phases"

    # Package being tested
    PACKAGE="coreutils"

    rlJournalStart
        # Setup phase: Prepare test directory
        rlPhaseStartSetup
            rlAssertRpm $PACKAGE
            rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory' # no-reboot
            rlRun "pushd $TmpDir"
        rlPhaseEnd

        # Test phase: Testing touch, ls and rm commands
        rlPhaseStartTest
            rlRun "touch foo" 0 "Creating the foo test file"
            rlAssertExists "foo"
            rlRun "ls -l foo" 0 "Listing the foo test file"
            rlRun "rm foo" 0 "Removing the foo test file"
            rlAssertNotExists "foo"
            rlRun "ls -l foo" 2 "Listing foo should now report an error"
        rlPhaseEnd

        # Cleanup phase: Remove test directory
        rlPhaseStartCleanup
            rlRun "popd"
            rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlPhaseEnd
    rlJournalEnd

    # Print the test report
    rlJournalPrintText

The ouput of the rlJournalPrintText command would produce an
output similar to the following:

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: TEST PROTOCOL
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   LOG    ] :: Test run ID   : debugging
    :: [   LOG    ] :: Package       : coreutils
    :: [   LOG    ] :: Installed:    : coreutils-7.6-9.fc12.i686
    :: [   LOG    ] :: Test started  : 2010-02-08 14:55:44
    :: [   LOG    ] :: Test finished : 2010-02-08 14:55:50
    :: [   LOG    ] :: Test name     : /examples/beakerlib/Sanity/phases
    :: [   LOG    ] :: Distro:       : Fedora release 12 (Constantine)
    :: [   LOG    ] :: Hostname      : localhost
    :: [   LOG    ] :: Architecture  : i686

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Test description
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    PURPOSE of /examples/beakerlib/Sanity/phases
    Description: Testing BeakerLib phases
    Author: Petr Splichal <psplicha@redhat.com>

    This example shows how the phases work in the BeakerLib on a
    trivial smoke test for the "touch", "ls" and "rm" commands from
    the coreutils package.


    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Setup
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   PASS   ] :: Checking for the presence of coreutils rpm
    :: [   PASS   ] :: Creating tmp directory
    :: [   PASS   ] :: Running 'pushd /tmp/tmp.IcluQu5GVS' # no-reboot
    :: [   LOG    ] :: Duration: 0s
    :: [   LOG    ] :: Assertions: 3 good, 0 bad
    :: [   PASS   ] :: RESULT: Setup

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Test
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   PASS   ] :: Creating the foo test file
    :: [   PASS   ] :: File foo should exist
    :: [   PASS   ] :: Listing the foo test file
    :: [   PASS   ] :: Removing the foo test file
    :: [   PASS   ] :: File foo should not exist
    :: [   PASS   ] :: Listing foo should now report an error
    :: [   LOG    ] :: Duration: 1s
    :: [   LOG    ] :: Assertions: 6 good, 0 bad
    :: [   PASS   ] :: RESULT: Test

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :: [   LOG    ] :: Cleanup
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [   PASS   ] :: Running 'popd'
    :: [   PASS   ] :: Removing tmp directory
    :: [   LOG    ] :: Duration: 1s
    :: [   LOG    ] :: Assertions: 2 good, 0 bad
    :: [   PASS   ] :: RESULT: Cleanup

Note that the detailed test description is read from a separate
file PURPOSE placed in the same directory as the test itself.

A lot of useful debugging information is reported on the DEBUG level.
You can run your test with C<DEBUG=1 make run> to get them.

Verbosity of the test logging may be altered also by setting the LOG_LEVEL
variable. Possible values are "ERROR", "WARNING", "INFO" and "DEBUG". You will
see messages like the ones below.

    :: [ WARNING  ] :: rlGetArch: Update test to use rlGetPrimaryArch/rlGetSecondaryArch
    :: [  DEBUG   ] :: rlGetArch: This is architecture 'x86_64'
    :: [  ERROR   ] :: this function was dropped as its development is completely moved to the beaker library
    :: [   INFO   ] :: if you realy on this function and you really need to have it present in core beakerlib, file a RFE, please

Setting LOG_LEVEL="DEBUG" is equivalent to DEBUG=1.

=head1 BKRDOC

=over

=item Description

Bkrdoc is a documentation generator from tests written using BeakerLib
library. This generator makes documentation from test code with and also
without any documentation markup.

=item What it's good for

For fast, brief and reliable documentation creation. It`s good for
quick start with unknown BeakerLib test. Created documentations provides
information about the documentation credibility. Also created documentations
shows environmental variables and helps reader to run test script from
which was documentation created.

=item Bkrdoc project page

https://github.com/rh-lab-q/bkrdoc

=back

=head1 LINKS

=over

=item Project Page

https://fedorahosted.org/beakerlib/

=item Manual

https://fedorahosted.org/beakerlib/wiki/Manual

=item Reporting bugs

https://bugzilla.redhat.com/enter_bug.cgi?product=Fedora&component=beakerlib

=back

=head1 AUTHORS

=over

=item *

Petr Muller <pmuller@redhat.com>

=item *

Ondrej Hudlicky <ohudlick@redhat.com>

=item *

Jan Hutar <jhutar@redhat.com>

=item *

Petr Splichal <psplicha@redhat.com>

=item *

Ales Zelinka <azelinka@redhat.com>

=item *

Dalibor Pospisil <dapospis@redhat.com>

=item *

Martin Kyral <mkyral@redhat.com>

=item *

Jakub Prokes <jprokes@redhat.com>

=back

=cut

if set -o | grep posix | grep on ; then
    set +o posix
    export POSIXFIXED="YES"
else
    export POSIXFIXED="NO"
fi

export __INTERNAL_PERSISTENT_TMP=/var/tmp

# export COBBLER_SERVER for the usage in tests
test -f /etc/profile.d/cobbler.sh && . /etc/profile.d/cobbler.sh

set -e
export BEAKERLIB=${BEAKERLIB:-"/usr/share/beakerlib"}
. $BEAKERLIB/storage.sh
. $BEAKERLIB/infrastructure.sh
. $BEAKERLIB/journal.sh
. $BEAKERLIB/libraries.sh
. $BEAKERLIB/logging.sh
. $BEAKERLIB/rpms.sh
. $BEAKERLIB/testing.sh
. $BEAKERLIB/analyze.sh
. $BEAKERLIB/performance.sh
. $BEAKERLIB/virtualX.sh
. $BEAKERLIB/synchronisation.sh
if [ -d $BEAKERLIB/plugins/ ] ; then
    for __INTERNAL_beakerlib_source_plugin in $BEAKERLIB/plugins/*.sh ; do
        . $__INTERNAL_beakerlib_source_plugin
    done
fi
set +e
