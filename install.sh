#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: install.sh - part of the BeakerLib project
#   Description: Bash helper which allows installing beakerlib's shell
#       scripts directly from GitHub! WARNING: this script only installs
#       .sh files under `/usr/share/beakerlib`. It doesn't install
#       exacutables under `/usr/bin`.
#
#               Author: Alexander Todorov <atodorov@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017-2018 Red Hat, Inc. All rights reserved.
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



FILES="journal.sh\
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
    beakerlib.sh"


DESTDIR="$1/usr/share/beakerlib"


__DOWNLOAD() {
  local URL="$1"
  local FILE="$2"
  if which wget &> /dev/null; then
    wget --quiet -t 3 -T 180 -w 20 --waitretry=30 --no-check-certificate -O $FILE $URL
  elif which curl &> /dev/null; then
    curl $QUIET --silent --location --retry-connrefused --retry-delay 3 --retry-max-time 3600 --retry 3 --connect-timeout 180 --max-time 1800 --insecure -o $FILE "$URL"
  else
    echo "ERROR: wget or curl not available"
    exit 1
  fi
}

__INSTALL() {
    F=$1
    # if file not present locally on disk then we must be installing from web
    if [ ! -f $F ]; then
        __DOWNLOAD "https://raw.githubusercontent.com/beakerlib/beakerlib/master/src/$F" $DESTDIR/$F
        chmod 0644 $DESTDIR/$F
    else
        # otherwise we're building an RPM or installing via make
        install -p -m 644 $F $DESTDIR
    fi
}


mkdir -p $DESTDIR
for F in $FILES; do
    __INSTALL $F
done

} # this ensures the entire script is downloaded #
