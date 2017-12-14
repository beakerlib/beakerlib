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
echo "${__INTERNAL_SOURCED}" | grep -qF -- " ${BASH_SOURCE} " && return || __INTERNAL_SOURCED+=" ${BASH_SOURCE} "

: <<'=cut'
=pod

=head1 NAME

BeakerLib - storage - Internal storage helpers

=head1 DESCRIPTION

There are currently no public functions in this module

=cut


__INTERNAL_STORAGE_DEFAULT_SECTION="GENERIC"
__INTERNAL_STORAGE_DEFAULT_NAMESPACE="GENERIC"

__INTERNAL_ST_OPTION_PARSER='
  local namespace="$__INTERNAL_STORAGE_DEFAULT_NAMESPACE"
  local section="$__INTERNAL_STORAGE_DEFAULT_SECTION"
  local GETOPT=$(getopt -o : -l namespace:,section: -- "$@") || return 126
  eval set -- "$GETOPT"
  while true; do
    case $1 in
      --)          shift; break ;;
      --namespace) shift; namespace="$1" ;;
      --section)   shift; section="$1" ;;
    esac; shift
  done
  [[ -z "$1" ]] && {
    rlLogError "$FUNCNAME(): missing the Key!"
    return 1
  }
  local key="$1"
  local file="${BEAKERLIB_DIR}/storage/${namespace}/${section}/${key}"
  rlLogDebug "$FUNCNAME(): using file \"$file\""
'

__INTERNAL_ST_GET() {
  eval "$__INTERNAL_ST_OPTION_PARSER"
  if [[ -f "$file" && -r "$file" ]]; then
    local value="$(cat "$file")"
    rlLogDebug "$FUNCNAME(): got value '$value'"
    echo "$value"
  else
    rlLogDebug "$FUNCNAME(): reading unset key '$key' from section '$section' in namespace '$namespace', will return an empty string"
  fi
}

__INTERNAL_ST_PUT() {
  eval "$__INTERNAL_ST_OPTION_PARSER"
  local value="$2"
  mkdir -p "$(dirname "$file")"
  rlLogDebug "$FUNCNAME(): setting value '$value'"
  echo "$value" > "$file"
}

__INTERNAL_ST_PRUNE() {
  eval "$__INTERNAL_ST_OPTION_PARSER"
  rm -f "$file"
}
