Name:       beakerlib
Summary:    A shell-level integration testing library, usable for writing operating system scope tests
Version:    1.0
Release:    1
License:    GPLv2
Group:      Development/Libraries
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
Source0:    %{name}-%{version}.tar.gz
BuildArch:  noarch
URL:        https://fedorahosted.org/beakerlib/attachment/wiki/tarballs/beakerlib-1.0.tar.gz
Obsoletes:  rhtslib beaker-lib
Provides:   rhtslib beaker-lib

%description
The BeakerLib project means to provide a library of various helpers,
which could be used when writing operating system level integration tests.

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT;

%files
%defattr(-,root,root,-)
/usr/share/rhts-library/rhtslib.sh
/usr/lib/beakerlib/*.sh
/usr/share/beakerlib/dictionary.vim
/usr/lib/beakerlib/virtualX.sh
/usr/lib/beakerlib/python/rlMemAvg.py*
/usr/lib/beakerlib/python/rlMemPeak.py*
/usr/lib/beakerlib/python/journalling.py*
/usr/lib/beakerlib/python/journal-compare.py*
/usr/lib/beakerlib/perl/deja-summarize
/usr/share/man/man1/beakerlib*1.gz

%changelog
* Wed Jan 27 2010 Petr Muller <pmuller@redhat.com> - 1.0-1
- genesis of the standalone BeakerLib
