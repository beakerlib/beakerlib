# License: GPL v2
# Copyright Red Hat Inc. 2009

export PKGNAME := beakerlib
export PKGVERSION := $(shell cat VERSION )
export TAG := ${PKGNAME}-${PKGVERSION}
ifndef DD
	DD:=/
endif

export DESTDIR := $(shell readlink -f -n $(DD))

SUBDIRS := src

build:
	for i in $(SUBDIRS); do $(MAKE) -C $$i; done

install:
	mkdir -p  $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p LICENSE $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p README $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p MAINTENANCE $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p VERSION $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/

	for i in $(SUBDIRS); do $(MAKE) -C $$i install; done

clean:
	rm -f *.tar.gz
	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done

upstream-release:
	sh upstream-release.sh ${TAG}
