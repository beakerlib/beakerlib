# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: Makefile - part of the BeakerLib project
#   Description: The Makefile
#
#		Author: Petr Muller <pmuller@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2010 Red Hat, Inc. All rights reserved.
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

SCRIPTS=beakerlib.sh\
		journal.sh\
		logging.sh\
		testing.sh\
		rpms.sh\
		infrastructure.sh\
		performance.sh\
		analyze.sh\
		virtualX.sh
FILES=$(SCRIPTS)

MANDIR=docs/man
WIKIDIR=docs/wiki
WIKIPREFIX="Docs(2f)BeakerLib(2f)Manual(2f)"
WIKILOCATION="wikiadmin@docs.example.com:/var/www/moin/wiki/data/pages"

.PHONY: install clean test

build:
	@echo "Nothing to build"

install: $(FILES) docsman gendict
	mkdir -p $(DESTDIR)/usr/share/beakerlib
	mkdir -p $(DESTDIR)/usr/share/man/man1
	mkdir -p $(DESTDIR)/usr/bin
	mkdir -p $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/
	mkdir -p $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/simple
	mkdir -p $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/phases
	mkdir -p $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/apache

	install -p -m 644 examples/simple/* $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/simple
	install -p -m 644 examples/phases/* $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/phases
	install -p -m 644 examples/apache/* $(DESTDIR)/usr/share/doc/$(PKGNAME)-$(PKGVERSION)/examples/apache


	install -p -m 644 $(FILES) $(DESTDIR)/usr/share/beakerlib
	install -p -m 644 dictionary.vim $(DESTDIR)/usr/share/beakerlib

	install -p python/rlMemAvg.py $(DESTDIR)/usr/bin/beakerlib-rlMemAvg
	install -p python/rlMemPeak.py $(DESTDIR)/usr/bin/beakerlib-rlMemPeak
	install -p python/journalling.py $(DESTDIR)/usr/bin/beakerlib-journalling
	install -p python/journal-compare.py $(DESTDIR)/usr/bin/beakerlib-journalcmp
	install -p perl/deja-summarize $(DESTDIR)/usr/bin/beakerlib-deja-summarize

	install -p -m 644 $(MANDIR)/man1/* $(DESTDIR)/usr/share/man/man1

clean:
	rm -rf test/remotedir test/beakerlib-test-mount-point
	rm -f *.tar.gz
	rm -f test/runtests-worker.sh
	rm -rf docs/{man,wiki,html,pod}
	rm -f ./pod2htm*
	rm -f dictionary.vim

check:
	BEAKERLIB=. sh beakerlib.sh

test:
	cd test/; ./test.sh

docsjoin:
	rm -rf docs/pod
	mkdir -p docs/pod
	./perl/docsjoin $(SCRIPTS) >docs/pod/beakerlib.pod

docsman: $(SCRIPTS) docsjoin
	rm -rf docs/man
	mkdir -p docs/man/man1
	for i in $(SCRIPTS); do \
		name=`echo $$i | sed 's/\.sh//'`; \
	    pod2man $$i > docs/man/man1/beakerlib-$$name.1; \
	done
	pod2man docs/pod/beakerlib.pod > docs/man/man1/beakerlib.1
	gzip docs/man/man1/*.1

docshtml: $(SCRIPTS) docsjoin
	rm -rf docs/html
	mkdir -p docs/html
	for i in $(SCRIPTS); do \
		name=`echo $$i | sed 's/\.sh//'`; \
	    pod2html $$i > docs/html/beakerlib-$$name.html; \
	done
	pod2html docs/pod/beakerlib.pod > docs/html/beakerlib.html

docswiki: $(SCRIPTS) docsjoin
	rm -rf $(WIKIDIR)
	if ! type pod2wiki &>/dev/null; then \
	    echo "You need pod2wiki utility - see package 'perl-Pod-Simple-Wiki' or http://search.cpan.org/dist/Pod-Simple-Wiki/"; \
	    false; \
	fi
	if pod2wiki 2>&1 | grep -q "Can't locate Pod/Simple/Wiki"; then \
	    echo "You need Pod::Simple::Wiki module for converting to wiki"; \
	    echo "Try: yum install perl-CPAN && perl -MCPAN -e 'install \"Pod::Simple::Wiki\"'"; \
	    false; \
	fi
	cp docs/pod/beakerlib.pod BeakerLibManual
	for i in $(SCRIPTS) BeakerLibManual; do \
	    MODULE=`echo $$i | sed 's/^\(.*\).sh$$/\u\1/' | sed 's/-\([^-]\)/\u\1/g'`; \
	    MODULEDIR=$(WIKIDIR)/$(WIKIPREFIX)$$MODULE; \
	    mkdir -p $$MODULEDIR/revisions; \
		 echo 00000001 > $$MODULEDIR/current; \
		 echo '<<TableOfContents(4)>>' > $$MODULEDIR/revisions/00000001; \
	    pod2wiki --style moinmoin $$i >> $$MODULEDIR/revisions/00000001; \
	done
	rm BeakerLibManual

gendict:
	BEAKERLIB=. bash -c ". beakerlib.sh ; declare -f | \
		perl -e 'map { s/.*(obsolete|deprecate|^rlj).*//s; s/ .*/\n/s; print } \
		(join \"\", <>) =~ m/^rl.*?^}/msg;' > dictionary.vim"

wiki: $(SCRIPTS) docswiki
	scp -r $(WIKIDIR)/* $(WIKILOCATION)

docs: docshtml docsman wiki