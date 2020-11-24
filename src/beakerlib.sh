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
__INTERNAL_SOURCED=${__INTERNAL_SOURCED-}
echo "${__INTERNAL_SOURCED}" | grep -qF -- " ${BASH_SOURCE} " && return || __INTERNAL_SOURCED+=" ${BASH_SOURCE} "

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

=head1 OUTPUT FILES

Location of test results related output files can be configured by setting BEAKERLIB_DIR variable before running the test. If it is not set, temporary directory is created.

=head2 journal.txt

Journal in human readable form.

=head2 journal.xml

Journal in XML format, requires python. This dependency can be avoided if the test is run with variable BEAKERLIB_JOURNAL set to 0 in which case journal.xml is not created.

=head3 XSLT

XML journal can be transformed through XSLT template. Which template is used is configurable by setting BEAKERLIB_JOURNAL variable. Value can be either filename in which case beakerlib will try to use $INSTALL_DIR/xslt-template/$filename (e.g.: /usr/share/beakerlib/xstl-templates/xunit.xsl) or it can be path to a template anywhere on the system.

=head2 TestResults

Overall results of the test in a 'sourceable' form. Each line contains a pair VAR=VALUE. All variable names have 'TESTRESULT_' prefix.

=head3 List of variables:

TESTRESULT_RESULT_STRING - Result of the test in a string, e.g.: PASS, FAIL, WARN.

TESTRESULT_RESULT_ECODE - Result of the test as an integer, 0 equals to PASS.

TESTRESULT_PHASES_PASSED - Number of phases that ended with PASS.

TESTRESULT_PHASES_FAILED - Number of phases that ended with non-PASS result.

TESTRESULT_PHASES_SKIPPED - Number of skipped phases.

TESTRESULT_ASSERTS_FAILED - Number of asserts that ended with non-PASS result in the whole test.

TESTRESULT_STARTTIME - Time when test started in seconds since epoch.

TESTRESULT_ENDTIME - Time when test ended in seconds since epoch.

TESTRESULT_DURATION - Duration of the test run in seconds.

TESTRESULT_BEAKERLIB_DIR - Directory with test results files.

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

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   TEST PROTOCOL
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

        Package       : coreutils
        Installed     : coreutils-8.27-19.fc27.x86_64
        beakerlib RPM : beakerlib-1.17-6.fc27.noarch
        Test started  : 2018-02-08 15:43:03 CET
        Test finished : 2018-02-08 15:43:04 CET
        Test duration : 1 seconds
        Test name     : /examples/beakerlib/Sanity/phases
        Distro        : Fedora release 27 (Twenty Seven)
        Hostname      : localhost
        Architecture  : x86_64
        CPUs          : 4 x Intel Core Processor (Skylake)
        RAM size      : 1992 MB
        HDD size      : 17.55 GB

    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Test description
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    PURPOSE of /examples/beakerlib/Sanity/phases
    Description: Testing BeakerLib phases
    Author: Petr Splichal <psplicha@redhat.com>

    This example shows how the phases work in the BeakerLib on a
    trivial smoke test for the "touch", "ls" and "rm" commands from
    the coreutils package.



    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Setup
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [ 15:43:03 ] :: [   PASS   ] :: Checking for the presence of coreutils rpm
    :: [ 15:43:03 ] :: [   LOG    ] :: Package versions:
    :: [ 15:43:03 ] :: [   LOG    ] ::   coreutils-8.27-19.fc27.x86_64
    :: [ 15:43:03 ] :: [   PASS   ] :: Creating tmp directory (Expected 0, got 0)
    :: [ 15:43:03 ] :: [   PASS   ] :: Command 'pushd /tmp/tmp.MMQf7dj9QV' (Expected 0, got 0)
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Duration: 1s
    ::   Assertions: 3 good, 0 bad
    ::   RESULT: PASS


    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Test
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [ 15:43:04 ] :: [   PASS   ] :: Creating the foo test file (Expected 0, got 0)
    :: [ 15:43:04 ] :: [   PASS   ] :: File foo should exist
    :: [ 15:43:04 ] :: [   PASS   ] :: Listing the foo test file (Expected 0, got 0)
    :: [ 15:43:04 ] :: [   PASS   ] :: Removing the foo test file (Expected 0, got 0)
    :: [ 15:43:04 ] :: [   PASS   ] :: File foo should not exist
    :: [ 15:43:04 ] :: [   PASS   ] :: Listing foo should now report an error (Expected 2, got 2)
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Duration: 0s
    ::   Assertions: 6 good, 0 bad
    ::   RESULT: PASS


    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Cleanup
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [ 15:43:04 ] :: [   PASS   ] :: Command 'popd' (Expected 0, got 0)
    :: [ 15:43:04 ] :: [   PASS   ] :: Removing tmp directory (Expected 0, got 0)
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Duration: 0s
    ::   Assertions: 2 good, 0 bad
    ::   RESULT: PASS


    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   /examples/beakerlib/Sanity/phases
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    :: [ 15:43:04 ] :: [   LOG    ] :: JOURNAL XML: /var/tmp/beakerlib-pRiJfWE/journal.xml
    :: [ 15:43:04 ] :: [   LOG    ] :: JOURNAL TXT: /var/tmp/beakerlib-pRiJfWE/journal.txt
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ::   Duration: 1s
    ::   Phases: 3 good, 0 bad
    ::   OVERALL RESULT: PASS

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

Set DEBUG_TO_CONSOLE_ONLY=1 in conjuction with DEBUG=1 to avoid storing debug
messages in journal. This also speeds up the execution in debug mode as those
messages are not fully processed than.

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

https://github.com/beakerlib/beakerlib

=item Manual

https://github.com/beakerlib/beakerlib/wiki/man

=item Issues list

https://github.com/beakerlib/beakerlib/issues

=item Reporting issues

https://github.com/beakerlib/beakerlib/issues/new

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

=item *

Jakub Heger <jheger@redhat.com>

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
BEAKERLIB_DIR=${BEAKERLIB_DIR-}
TESTID=${TESTID-}
JOBID=${JOBID-}
RECIPEID=${RECIPEID-}
BEAKERLIB_JOURNAL=${BEAKERLIB_JOURNAL-}
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
. $BEAKERLIB/ya.sh
if [ -d $BEAKERLIB/plugins/ ] ; then
    __INTERNAL_IFS_OLD="$IFS"
    unset IFS
    for __INTERNAL_beakerlib_source_plugin in $BEAKERLIB/plugins/*.sh ; do
        . $__INTERNAL_beakerlib_source_plugin
    done
    IFS="$__INTERNAL_IFS_OLD"
fi

set +e
