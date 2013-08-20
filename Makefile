# License: GPL v2
# Copyright Red Hat Inc. 2009

export PKGNAME := beakerlib
export PKGVERSION := $(shell cat VERSION )
export TAG := ${PKGNAME}-${PKGVERSION}
ifndef DD
	DD:=/
endif

ifndef PKGDOCDIR
	export PKGDOCDIR := /usr/share/doc/$(PKGNAME)/
endif

export DESTDIR := $(shell readlink -f -n $(DD))

SUBDIRS := src

build:
	for i in $(SUBDIRS); do $(MAKE) -C $$i; done

install:
	mkdir -p  $(DESTDIR)$(PKGDOCDIR)
	install -m 644 -p LICENSE $(DESTDIR)$(PKGDOCDIR)
	install -m 644 -p README $(DESTDIR)$(PKGDOCDIR)
	install -m 644 -p MAINTENANCE $(DESTDIR)$(PKGDOCDIR)
	install -m 644 -p VERSION $(DESTDIR)$(PKGDOCDIR)

	for i in $(SUBDIRS); do $(MAKE) -C $$i install; done

clean:
	rm -f *.tar.gz
	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done

upstream-release:
	sh upstream-release.sh ${TAG}

testing-release:
	sh upstream-release.sh ${TAG} testing

check:
	./check-tempfiles.sh
	make -C src check
	make -C src test AREA=$(AREA)
