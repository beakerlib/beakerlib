# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2008-2015 Red Hat, Inc. All rights reserved.
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

.PHONY: install clean

build:

install:
	@# usage examples
	mkdir -p $(PKGDOCDIR)/examples/
	mkdir -p $(PKGDOCDIR)/examples/simple
	mkdir -p $(PKGDOCDIR)/examples/phases
	mkdir -p $(PKGDOCDIR)/examples/apache
	install -p -m 644 examples/simple/* $(PKGDOCDIR)/examples/simple
	install -p -m 644 examples/phases/* $(PKGDOCDIR)/examples/phases
	install -p -m 644 examples/apache/* $(PKGDOCDIR)/examples/apache
	@# testwatcher design docs
	install -p -m 644 testwatcher.txt $(PKGDOCDIR)

clean:

test:
