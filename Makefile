# License: GPL v2
# Copyright Red Hat Inc. 2009

export PKGNAME=beakerlib

SCM_REMOTEREPO_RE = ^ssh://(.*@)?git.fedorahosted.org/git/$(PKGNAME).git$
UPLOAD_URL = ssh://fedorahosted.org/$(PKGNAME)

SUBDIRS := src

build:
	for i in $(SUBDIRS); do $(MAKE) -C $$i; done

include rpmspec_rules.mk
include git_rules.mk
include upload_rules.mk

export PKGVERSION

install:
	mkdir -p  $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p LICENSE $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/

	for i in $(SUBDIRS); do $(MAKE) -C $$i install; done

clean:
	rm -rf rpm-build
	rm -f *.tar.gz
	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done

srpm: clean snaparchive
	mkdir -p rpm-build
	rpmbuild --define "_topdir %(pwd)/rpm-build" \
	--define "_builddir %{_topdir}" \
	--define "_rpmdir %{_topdir}" \
	--define "_srcrpmdir %{_topdir}" \
	--define "_specdir %{_topdir}" \
	--define "_sourcedir  %{_topdir}" \
	--define "dist .el7" \
	$(RPMBUILDOPTS) -ts $(PKGNAME)-$(PKGVERSION).tar.gz

rpm: clean snaparchive
	mkdir -p rpm-build
	rpmbuild --define "_topdir %(pwd)/rpm-build" \
	--define "_builddir %{_topdir}" \
	--define "_rpmdir %{_topdir}" \
	--define "_srcrpmdir %{_topdir}" \
	--define "_specdir %{_topdir}" \
	--define "_sourcedir  %{_topdir}" \
	--define "dist .el7" \
	$(RPMBUILDOPTS) -tb $(PKGNAME)-$(PKGVERSION).tar.gz

rpms: rpm
