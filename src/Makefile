# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: Makefile - part of the BeakerLib project
#   Description: The Makefile
#
#		Author: Petr Muller <pmuller@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2013 Red Hat, Inc. All rights reserved.
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

SUBDIRS := extradocs

MODULES=journal.sh\
		logging.sh\
		testing.sh\
		rpms.sh\
		infrastructure.sh\
		performance.sh\
		analyze.sh\
		libraries.sh\
		storage.sh \
		synchronisation.sh\
		virtualX.sh\
		ya.sh

FILES=$(MODULES) beakerlib.sh
DEFDOCS=dictionary.vim docsman

.PHONY: install clean test

ya.sh:
	cp yash/ya.sh ./
	patch < yash/yash.patch

build: $(FILES) $(DEFDOCS)
	@for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done

install:
	mkdir -p $(DESTDIR)/usr/share/beakerlib
	mkdir -p $(DESTDIR)/usr/share/beakerlib/xslt-templates
	mkdir -p $(DESTDIR)/usr/share/man/man1
	mkdir -p $(DESTDIR)/usr/bin
	mkdir -p $(DESTDIR)/usr/share/vim/vimfiles/after/ftdetect
	mkdir -p $(DESTDIR)/usr/share/vim/vimfiles/after/syntax

	install -p -m 644 $(FILES) $(DESTDIR)/usr/share/beakerlib
	install -p -m 644 dictionary.vim $(DESTDIR)/usr/share/beakerlib

	install -p -m 644 xslt-templates/* $(DESTDIR)/usr/share/beakerlib/xslt-templates

	install -p -m 644 vim/ftdetect/beakerlib.vim $(DESTDIR)/usr/share/vim/vimfiles/after/ftdetect
	install -p -m 644 vim/syntax/beakerlib.vim $(DESTDIR)/usr/share/vim/vimfiles/after/syntax

	install -p python/rlMemAvg.py $(DESTDIR)/usr/bin/beakerlib-rlMemAvg
	install -p python/rlMemPeak.py $(DESTDIR)/usr/bin/beakerlib-rlMemPeak
	install -p python/journalling.py $(DESTDIR)/usr/bin/beakerlib-journalling
	install -p python/journal-compare.py $(DESTDIR)/usr/bin/beakerlib-journalcmp
	install -p python/testwatcher.py $(DESTDIR)/usr/bin/beakerlib-testwatcher
	install -p perl/deja-summarize $(DESTDIR)/usr/bin/beakerlib-deja-summarize
	install -p lsb_release $(DESTDIR)/usr/bin/beakerlib-lsb_release

	install -p -m 644 $(MANDIR1)/* $(DESTDIR)/usr/share/man/man1

	@for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done

clean:
	rm -rf test/remotedir test/beakerlib-test-mount-point
	rm -f *.tar.gz
	rm -f test/runtests-worker.sh
	rm -rf docs/{man,wiki,html,pod}
	rm -f ./pod2htm*
	rm -f dictionary.vim
	@for i in $(SUBDIRS); do $(MAKE) -C $$i $(MAKECMDGOALS); done
	rm -f ya.sh

check:
	BEAKERLIB=. sh beakerlib.sh

test:
	make -C test test

benchmark:
	cd test/; ./benchmark.sh

# == DOCS GENERATION MACHINERY == #

.PHONY: all-documentation docsman docshtml docswiki pod2wiki

all-documentation: docsman docshtml dictionary.vim docswiki

DOCDIR=docs
PODDIR=$(DOCDIR)/pod
MANDIR1=$(DOCDIR)/man/man1
WIKIDIR=$(DOCDIR)/wiki
HTMLDIR=$(DOCDIR)/html

DOCSJOIN=perl/docsjoin
PODFILE=docs/pod/beakerlib.pod

MANPAGE=$(MANDIR1)/beakerlib.1
HTMLPAGE=$(HTMLDIR)/beakerlib.html
WIKIPAGE=beakerLibManual
WIKIREV=00000001

WIKIPREFIX="Docs(2f)BeakerLib(2f)Manual(2f)"
WIKILOCATION="wikiadmin@docs.example.com:/var/www/moin/wiki/data/pages"

$(PODDIR):
	mkdir -p $(PODDIR)

$(MANDIR1):
	mkdir -p $(MANDIR1)

$(HTMLDIR):
	mkdir -p $(HTMLDIR)

$(PODFILE): $(FILES) $(PODDIR)
	$(DOCSJOIN) $(FILES) >$@

$(MANPAGE): $(PODFILE) $(MANDIR1)
	pod2man $(PODFILE) >$@

$(MANDIR1)/beakerlib-%.1: %.sh $(MANDIR1)
	pod2man $*.sh >$@

%.1.gz: %.1
	gzip --force $<

$(HTMLPAGE): $(PODFILE) $(HTMLDIR)
	pod2html $(PODFILE) >$@

$(HTMLDIR)/beakerlib-%.html: %.sh $(HTMLDIR)
	pod2html $*.sh >$@

$(WIKIDIR)/$(WIKIPREFIX)/%: %.sh
	mkdir -p $@

$(WIKIDIR)/$(WIKIPREFIX)/$(WIKIPAGE):
	mkdir -p $@

$(WIKIDIR)/$(WIKIPREFIX)/%/current: $(WIKIDIR)/$(WIKIPREFIX)/%
	echo $(WIKIREV) > $@

$(WIKIDIR)/$(WIKIPREFIX)/%/revisions/$(WIKIREV): $(WIKIDIR)/$(WIKIPREFIX)/% pod2wiki
	mkdir -p $(WIKIDIR)/$/$(WIKIPREFIX)/$*/revisions
	echo '<<TableOfContents(4)>>' >$@; \
		pod2wiki --style moinmoin $*.sh >> $@ 2>/dev/null || pod2wiki --style moinmoin $(PODFILE) >> $@

MANPAGES = $(addprefix $(MANDIR1)/beakerlib-, $(MODULES:.sh=.1.gz)) $(MANPAGE).gz
HTMLPAGES = $(addprefix $(HTMLDIR)/beakerlib-, $(MODULES:.sh=.html)) $(HTMLPAGE)
WIKIREVFILES = $(addsuffix /revisions/$(WIKIREV), $(MODULES:.sh=) $(WIKIPAGE))
WIKICURFILES = $(addsuffix /current, $(MODULES:.sh=) $(WIKIPAGE))
WIKISUBDIRS = $(WIKIREVFILES) $(WIKICURFILES)
WIKIFILES = $(addprefix $(WIKIDIR)/$(WIKIPREFIX)/, $(WIKISUBDIRS))

docsman: $(MANPAGES)
docshtml: $(HTMLPAGES)
docswiki: $(WIKIFILES)
	for wikidir in $(shell ls $(WIKIDIR)/$(WIKIPREFIX)); do \
		newdir=`basename $$wikidir | sed -e 's|\(.*\)|\u\1|'`; \
		mv $(WIKIDIR)/$(WIKIPREFIX)/$$wikidir $(WIKIDIR)/$(WIKIPREFIX)/$$newdir; \
	done

dictionary.vim: $(FILES)
	BEAKERLIB=. bash -c ". beakerlib.sh ; declare -f | \
		perl -e 'map { s/.*(obsolete|deprecate|^rlj).*//s; s/ .*/\n/s; print } \
		(join \"\", <>) =~ m/^rl.*?^}/msg;' > $@"

pod2wiki:
	if ! type pod2wiki &>/dev/null; then \
	    echo "You need pod2wiki utility - see package 'perl-Pod-Simple-Wiki' or http://search.cpan.org/dist/Pod-Simple-Wiki/"; \
	    false; \
	fi
	if pod2wiki 2>&1 | grep -q "Can't locate Pod/Simple/Wiki"; then \
	    echo "You need Pod::Simple::Wiki module for converting to wiki"; \
	    echo "Try: yum install perl-CPAN && perl -MCPAN -e 'install \"Pod::Simple::Wiki\"'"; \
	    false; \
	fi

wiki: $(FILES) docswiki
	scp -r $(WIKIDIR)/* $(WIKILOCATION)
