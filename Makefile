# License: GPL v2
# Copyright Red Hat Inc. 2009

export PKGNAME := beakerlib
export PKGVERSION := $(shell cat VERSION )
export TAG := ${PKGVERSION}
ifndef DD
	DD:=/usr
endif

export DESTDIR := $(shell readlink -f -n $(DD))

ifndef PKGDOCDIR
	export PKGDOCDIR := $(DESTDIR)/share/doc/$(PKGNAME)/
endif

SUBDIRS := src

build:
	for i in $(SUBDIRS); do $(MAKE) -C $$i build; done

install: build
	mkdir -p  $(PKGDOCDIR)
	install -m 644 -p LICENSE $(PKGDOCDIR)
	install -m 644 -p README $(PKGDOCDIR)
	install -m 644 -p MAINTENANCE $(PKGDOCDIR)
	install -m 644 -p VERSION $(PKGDOCDIR)

	for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done

clean:
	rm -f *.tar.gz
	for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done

upstream-release:
	sh upstream-release.sh ${TAG}

testing-release:
	sh upstream-release.sh ${TAG} testing

experimental-release:
	sh upstream-release.sh ${TAG} experimental

check:
	sh check-tempfiles.sh
	make -C src check
	make -C src test AREA=$(AREA)

archive:
	git archive --prefix=beakerlib-$(TAG)/ -o beakerlib-$(TAG).tar.gz HEAD

test:
	for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done

