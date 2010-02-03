Name: beakerlib
Summary: An operating system integration testing harness
Version: 	1.0
Release:  1
License: 	GPLv2
Group: 		Development/Libraries
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
Source0:	%{name}-%{version}.tar.gz
BuildArch:	noarch
URL:            https://fedorahosted.org/git/beakerlib.git
Obsoletes: rhtslib beaker-lib

%description
The BeakerLib project means to provide a library of various helpers,
which could be used when writing operating system level integration tests.

%prep
%setup -q

%build

%install
%makeinstall DESTDIR=$RPM_BUILD_ROOT

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && [ -d $RPM_BUILD_ROOT ] && rm -rf $RPM_BUILD_ROOT;

%files
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
