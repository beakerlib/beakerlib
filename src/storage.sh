# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: storage.sh - part of the BeakerLib project
#   Description: An interface to journal persistent storage capabilities
#
#   Author: Petr Muller <muller@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

: <<'=cut'
=pod

=head1 NAME

BeakerLib - storage - Internal storage helpers

=head1 DESCRIPTION

There are currently no public functions in this module

=cut


__INTERNAL_STORAGE_BIN=beakerlib-storage

__INTERNAL_ST_GET() {
	$__INTERNAL_STORAGE_BIN get $@
}

__INTERNAL_ST_PUT() {
	$__INTERNAL_STORAGE_BIN put $@
}

__INTERNAL_ST_PRUNE() {
	$__INTERNAL_STORAGE_BIN prune $@
}
