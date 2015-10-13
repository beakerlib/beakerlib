# Copyright (c) 2012 Red Hat, Inc. All rights reserved. This copyrighted material
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Jakub Prokes <jprokes@redhat.com>

test_allFunctionsHiglight() {
    local hiFunctions="$(sed -n \
      '/syn keyword/{s/syn\s\+keyword\s\+bl[[:alnum:]]\+\s\+//; s/\s\+/\n/gp}' \
      ../vim/syntax/beakerlib.vim)"

    while read fName; do
        [[ $fName =~ EOF|^[[:space:]]*$ ]] && continue;
        for hiFunction in $hiFunctions; do
            [[ $fName == $hiFunction ]] && break;
        done;
        assertTrue "Function $fName covered." "[[ $fName == $hiFunction ]]";
    done < <(bash -c "source ../beakerlib.sh; declare -f | \
      perl -e 'map { s/.*(obsolete|deprecate|^rlj).*//s; s/ .*/\n/s; print } \
      (join \"\", <>) =~ m/^rl.*?^}/msg;'");
}
