Name:       beakerlib
Summary:    A shell-level integration testing library
Version:    1.3
Release:    7%{?dist}
License:    GPLv2
Group:      Development/Libraries
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
Source0:    https://fedorahosted.org/released/%{name}/%{name}-%{version}.tar.gz
BuildArch:  noarch
URL:        https://fedorahosted.org/%{name}
Requires:   nfs-utils
Requires:   python2
Obsoletes:  rhtslib beaker-lib
Provides:   rhtslib beaker-lib
Requires:   redhat-lsb


%description
The BeakerLib project means to provide a library of various helpers, which
could be used when writing operating system level integration tests.


%prep
%setup -q


%build
# This section is empty because this package ccontains shell scripts
# to be sourced: there's nothing to build

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%dir %{_datadir}/%{name}
%dir %{_docdir}/%{name}-%{version}
%dir %{_docdir}/%{name}-%{version}/examples
%dir %{_docdir}/%{name}-%{version}/examples/*
%{_datadir}/%{name}/dictionary.vim
%{_datadir}/%{name}/*.sh
%{_bindir}/%{name}-*
%{_mandir}/man1/%{name}*1*
%doc %{_docdir}/%{name}-%{version}/LICENSE
%doc %{_docdir}/%{name}-%{version}/examples/*/*

%changelog
* Thu Apr 29 2011 Petr Muller <pmuller@redhat.com> - 1.3-7
- rlCheckMount: Fix mounts mounted from different place (Branislav Nater)
- rlWatchdog: Now correctly kills the command (Miroslav Franc)
- rlLog functions: give output to STDERR
- generic: get rid of the ABORT phase type (Branislav Nater)
- journal: Fix tracebacks related to colorizing output
- rlFileBackup: Use parameters supported even on old RHELs (Petr Splichal)

* Thu Mar 24 2011 Petr Muller <pmuller@redhat.com> - 1.3-6
- rlGetDistroVersion: fix the return value for RHEL6 (Jan Pazdziora)

* Thu Mar 03 2011 Petr Muller <pmuller@redhat.com> - 1.3-5
- fixed bug when rlRun with -l param didn't work properly (Jan Hutar)
- fixed selinux context problems in rlFileRestore (Petr Splichal)
- added rlIsXXXX functions from RH internal (Petr Muller)
- added COBBLER_SERVER function export if available (Marian Ganisin)
- unified bash syntax (Roman Rakus)
- INFO logs are now shown by default (Petr Splichal)
- rlFileBackup of symlinks improvements (Petr Splichal)
- added a dep on redhat-lsb to accomodate rlIsXXXX
- log colorizing (Petr Splichal)
- fix rlFileRestore problems with symlinks (Filip Skola)
- added timezone information to start/end time

* Fri Oct 01 2010 Petr Muller <pmuller@redhat.com> - 1.3-4
- fixed bug when rlRun with -l param didn't work properly (Jan Hutar)
- fixed selinux context problems in rlFileRestore (Petr Splichal)

* Wed Jun 09 2010 Petr Muller <pmuller@redhat.com> - 1.3-3
- packaging fix (remove the unnecessary tag from release)

* Wed Jun 09 2010 Petr Muller <pmuller@redhat.com> - 1.3-2
- functions for determining current test status (Ales Zelinka, Petr Splichal]
- removal of unnecessary sync in rlRun (Petr Splichal)
- packaging tuned for rhel6

* Wed May 12 2010 Petr Muller <pmuller@redhat.com> - 1.3-1
- packaging fixes: permission fixes, added dep on python2,
- added examples as documentation files

* Thu Apr 29 2010 Petr Muller <pmuller@redhat.com> - 1.2-1
- packaging fixes: docdir change, specfile tweaks
- using consistently install -p everywhere

* Thu Apr 08 2010 Petr Muller <pmuller@redhat.com> - 1.2-0
- disable the testsuite and removed a 3rd party lib from the tree

* Mon Mar 22 2010 Petr Muller <pmuller@redhat.com> - 1.1-0
- packaging fixes

* Fri Feb 12 2010 Petr Muller <pmuller@redhat.com> - 1.0-3
- fixed bad path preventing tests from running

* Fri Feb 12 2010 Petr Muller <pmuller@redhat.com> - 1.0-2
- zillion of specfile tweaks for Fedora inclusion
- staf-rhts files were removed
- added a LICENSE file
- added a better package summary
- directory structure revamped
- improved rLDejaSum

* Wed Jan 27 2010 Petr Muller <pmuller@redhat.com> - 1.0-1
- genesis of the standalone BeakerLib
