Name: beakerlib
Summary: An operating system integration testing harness
Version: 	1.0
Release:  1
License: 	GPLv2
Group: 		QA
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
Source0:	%{name}-%{version}.tar.gz
BuildArch:	noarch
URL:            https://fedorahosted.org/git/beakerlib.git
Obsoletes: rhtslib beaker-lib
Provides: rhtslib beaker-lib

%description
The BeakerLib project means to provide a library of various helpers,
which could be used when writing operating system level integration tests.

%prep
%setup -q

%build

%install
%makeinstall DESTDIR=$RPM_BUILD_ROOT
rm perl/docsjoin

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%files
/usr/share/rhts-library/rhtslib.sh
/usr/lib/beakerlib/testing.sh
/usr/lib/beakerlib/rpms.sh
/usr/lib/beakerlib/logging.sh
/usr/lib/beakerlib/journal.sh
/usr/lib/beakerlib/infrastructure.sh
/usr/lib/beakerlib/beakerlib.sh
/usr/lib/beakerlib/analyze.sh
/usr/lib/beakerlib/performance.sh
/usr/share/beakerlib/dictionary.vim
/usr/lib/beakerlib/virtualX.sh
/usr/lib/beakerlib/python/rlMemAvg.py*
/usr/lib/beakerlib/python/rlMemPeak.py*
/usr/lib/beakerlib/python/journalling.py*
/usr/lib/beakerlib/python/journal-compare.py*
/usr/lib/beakerlib/perl/deja-summarize
/usr/lib/beakerlib/test/README
/usr/lib/beakerlib/test/coverageTest.sh
/usr/lib/beakerlib/test/infrastructureTest.sh
/usr/lib/beakerlib/test/journalTest.sh
/usr/lib/beakerlib/test/library.sh
/usr/lib/beakerlib/test/loggingTest.sh
/usr/lib/beakerlib/test/beakerlibTest.sh
/usr/lib/beakerlib/test/rpmsTest.sh
/usr/lib/beakerlib/test/runtests.sh
/usr/lib/beakerlib/test/shunit2
/usr/lib/beakerlib/test/testingTest.sh
/usr/share/man/man1/beakerlib-rpms.1.gz
/usr/share/man/man1/beakerlib.1.gz
/usr/share/man/man1/beakerlib-virtualX.1.gz
/usr/share/man/man1/beakerlib-infrastructure.1.gz
/usr/share/man/man1/beakerlib-analyze.1.gz
/usr/share/man/man1/beakerlib-beakerlib.1.gz
/usr/share/man/man1/beakerlib-performance.1.gz
/usr/share/man/man1/beakerlib-testing.1.gz
/usr/share/man/man1/beakerlib-journal.1.gz
/usr/share/man/man1/beakerlib-logging.1.gz

