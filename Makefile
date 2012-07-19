# License: GPL v2
# Copyright Red Hat Inc. 2009

export PKGNAME := beakerlib
export PKGVERSION := $(shell cat VERSION )
ifndef DD
	DD:=/
endif

export DESTDIR := $(shell readlink -f -n $(DD))

SCM_REMOTEREPO_RE := ^ssh://(.*@)?git.fedorahosted.org/git/$(PKGNAME).git$
UPLOAD_URL := ssh://fedorahosted.org/$(PKGNAME)

SUBDIRS := src

build:
	for i in $(SUBDIRS); do $(MAKE) -C $$i; done

include git_rules.mk
include upload_rules.mk

install:
	mkdir -p  $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/
	install -m 644 -p LICENSE $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/

	for i in $(SUBDIRS); do $(MAKE) -C $$i install; done

clean:
	rm -f *.tar.gz
	for i in $(SUBDIRS); do $(MAKE) -C $$i clean; done

upstream-release:
	# git pull (tags too)
	# check if a tag exists already
	# make tarball and put it on hosted
	# update the main page with new version
	# create release notes and put it online
	# tag as ready
