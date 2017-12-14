# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: libraries.sh - part of the BeakerLib project
#   Description: Functions for importing separate libraries
#
#   Author: Petr Muller <muller@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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

BeakerLib - libraries - mechanism for loading shared test code from libraries

=head1 DESCRIPTION

This file contains functions for bringing external code into the test
namespace.

=head1 FUNCTIONS

=cut

# Extract a list of required libraries from a Makefile
# Takes a directory where the library is placed

__INTERNAL_extractRequires(){
  local MAKEFILE="$1/Makefile"

  if [ -f "$MAKEFILE" ]
  then
    # 1) extract RhtsRequires lines, where RhtsRequires is not commented out
    # 2) extract test(/Foo/Bar/Library/Baz) patterns
    # 3) extract Bar/Baz from the patterns
    # 4) make a single line of space-separated library IDs
    __INTERNAL_LIBRARY_DEPS="$(grep -E '^[^#]*RhtsRequires' $MAKEFILE \
     | grep -E -o -e 'test\(/[^/)]+/[^/)]+/Library/[^/)]+\)' -e '[Ll]ibrary\([^)]*\)' \
     | sed -e 's|test(/[^/)]*/\([^/)]*\)/Library/\([^/)]*\))|\1/\2|g' -e 's|[Ll]ibrary(\(.*\))|\1|' \
     | tr '\n' ' ')"
  else
    __INTERNAL_LIBRARY_DEPS=""
  fi

  echo $__INTERNAL_LIBRARY_DEPS
}

# Extract a location of an original sourcing script from $0
__INTERNAL_extractOrigin(){
  local SOURCE

  if [ ! -e "$0" ]
  then
    SOURCE="$( readlink -f . )"
  else
    SOURCE="$( readlink -f $0 )"
  fi

  local DIR="$( dirname "$SOURCE" )"
  while [ -h "$SOURCE" ]
  do
      SOURCE="$(readlink -f "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
      DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
  done
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  echo "$DIR"
}
__INTERNAL_TraverseRoot="$(__INTERNAL_extractOrigin)"

# Traverse directories upwards and search for the matching path
__INTERNAL_rlLibraryTraverseUpwards() {
  local DIRECTORY="$1"
  local COMPONENT="$2"
  local LIBRARY="$3"

  while [ "$DIRECTORY" != "/" ]
  do
    DIRECTORY="$( dirname $DIRECTORY )"
    if [ -d "$DIRECTORY/$COMPONENT" ]
    then

      local CANDIDATE="$DIRECTORY/$COMPONENT/Library/$LIBRARY/lib.sh"
      if [ -f "$CANDIDATE" ]
      then
        LIBFILE="$CANDIDATE"
        break
      fi

      local CANDIDATE="$( echo $DIRECTORY/*/$COMPONENT/Library/$LIBRARY/lib.sh )"
      if [ -f "$CANDIDATE" ]
      then
        LIBFILE="$CANDIDATE"
        break
      fi
    fi
  done
}

__INTERNAL_rlLibrarySearchInRoot(){
  local COMPONENT="$1"
  local LIBRARY="$2"
  local BEAKERLIB_LIBRARY_PATH="${3:-/mnt/tests}"

  rlLogDebug "rlImport: Trying root: [$BEAKERLIB_LIBRARY_PATH]"

  local CANDIDATE="$BEAKERLIB_LIBRARY_PATH/$COMPONENT/Library/$LIBRARY/lib.sh"
  if [ -f "$CANDIDATE" ]
  then
    LIBFILE="$CANDIDATE"
    return
  fi

  local CANDIDATE="$( echo $BEAKERLIB_LIBRARY_PATH/*/$COMPONENT/Library/$LIBRARY/lib.sh )"
  if [ -f "$CANDIDATE" ]
  then
    LIBFILE="$CANDIDATE"
    return
  fi

  rlLogDebug "rlImport: Library not found in $BEAKERLIB_LIBRARY_PATH"
}

__INTERNAL_rlLibrarySearch() {

  local COMPONENT="$1"
  local LIBRARY="$2"

  rlLogDebug "rlImport: Looking if we got BEAKERLIB_LIBRARY_PATH"

  if [ -n "$BEAKERLIB_LIBRARY_PATH" ]
  then
    rlLogDebug "rlImport: BEAKERLIB_LIBRARY_PATH is set: trying to search in it"

    __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY" "$BEAKERLIB_LIBRARY_PATH"
    if [ -n "$LIBFILE" ]
    then
      local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT/$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
      rlLogInfo "rlImport: Found '$COMPONENT/$LIBRARY'$VERSION in BEAKERLIB_LIBRARY_PATH"
      return
    fi
  else
    rlLogDebug "rlImport: No BEAKERLIB_LIBRARY_PATH set: trying default"
  fi

  __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY"
  if [ -n "$LIBFILE" ]
  then
    local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT/$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
    rlLogInfo "rlImport: Found '$COMPONENT/$LIBRARY'$VERSION in /mnt/tests"
    return
  fi

  __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY" "/usr/share/beakerlib-libraries"
  if [ -n "$LIBFILE" ]
  then
    local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT/$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
    rlLogInfo "rlImport: Found '$COMPONENT/$LIBRARY'$VERSION in /usr/share/beakerlib-libraries"
    return
  fi

  if [ -n "$__INTERNAL_TraverseRoot" ]
  then
    rlLogDebug "rlImport: Trying to find the library in directories above test"
    rlLogDebug "rlImport: Starting search at: $__INTERNAL_TraverseRoot"
    __INTERNAL_rlLibraryTraverseUpwards "$__INTERNAL_TraverseRoot" "$COMPONENT" "$LIBRARY"

    if [ -n "$LIBFILE" ]
    then
      local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT/$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
      rlLogInfo "rlImport: Found '$COMPONENT/$LIBRARY'$VERSION during upwards traversal"
      return
    fi
  fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlImport
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlImport

Imports code provided by one or more libraries into the test namespace.
The library search mechanism is based on Beaker test hierarchy system, i.e.:

/component/type/test-name/test-file

When test-file calls rlImport with 'foo/bar' parameter, the directory path
is traversed upwards, and a check for presence of the test /foo/Library/bar/
will be performed. This means this function needs to be called from
the test hierarchy, not e.g. the /tmp directory.

Once library is found, it is sourced and a verifier function is called.
The verifier function is cunstructed by composing the library prefix and
LibraryLoaded. Library prefix can be defined in the library itself.
If the verifier passes the library is ready to use. Also variable
B<E<lt>PREFIXE<gt>LibraryDir> is created and it points to the library folder.

Usage:

    rlImport --all
    rlImport LIBRARY [LIBRARY2...]

=over

=item --all

Read Makefile in current/original directory, pick library requirements up and
import them all.

=item LIBRARY

Must have 'component/library' format. Identifies the library to import.

=back

Returns 0 if the import of all libraries was successful. Returns non-zero
if one or more library failed to import.

=cut

__INTERNAL_first(){
  echo $1
}

__INTERNAL_tail(){
  shift
  echo $*
}

__INTERNAL_envdebugget() {
  local tmp="$(set | sed -r '/^.*\S+ \(\).$/,$d;/^(_|BASH_.*|FUNCNAME|LINENO|PWD|__INTERNAL_LIBRARY_IMPORTS_.*|__INTERNAL_envdebug.*)=/d')"
  if [[ -z "$1" ]]; then
    __INTERNAL_envdebugvariables="$tmp"
    __INTERNAL_envdebugfunctions="$(declare -f)"
  else
    echo "$tmp"
  fi
}

__INTERNAL_envdebugdiff() {
  rlLogDebug "rlImport: library $1 changes following environment; changed functions are marked with asterisk (*)"
  diff -U0 <(echo "$__INTERNAL_envdebugvariables") <(__INTERNAL_envdebugget 1) | tail -n +3 | grep -E -v '^@@'
  local line fn print='' print2 LF=$'\n'
  local IFS

  while read -r line; do
    [[ "$line" =~ ^(.)([^[:space:]]+)[[:space:]]\(\) ]] && {
      [[ -n "$print" ]] && {
        echo "$fn"
        print=''
      }
      print2=''
      local tmp="${BASH_REMATCH[1]}"
      [[ "$tmp" == " " ]] && {
        print2=1
        tmp='*'
      }
      fn="$tmp${BASH_REMATCH[2]}()"
      continue
    }
    [[ "${line:0:1}" != " " ]] && print=1
    [[ "$DEBUG" =~ ^[0-9]+$ ]] && [[ -n "$print2" &&  $DEBUG -ge 2 || $DEBUG -ge 3 ]] && fn="$fn$LF$line"
  done < <(diff -U100000 <(echo "$__INTERNAL_envdebugfunctions") <(declare -f) | tail -n +3 | grep -E -v '^@@'; echo " _ ()")
  unset __INTERNAL_envdebugfunctions __INTERNAL_envdebugvariables
}

__INTERNAL_extractLibraryVersion() {
  local LIBFILE=$1
  local LIBNAME=$2
  local VERSION=""
  local RESULT=""

  # Search in lib.sh
  VERSION="${VERSION:+"$VERSION, "}$( grep -E '^#\s*library-version = \S*' $LIBFILE | sed 's|.*library-version = \(\S*\).*|\1|')"

  # Search lib in rpms and get version
  if RESULT=( $(rpm -q --queryformat "%{NAME} %{VERSION}-%{RELEASE}\n" --whatprovides "library($LIBNAME)") ); then
    # Found library-version, set $VERSION
    while [[ -n "$RESULT" ]]; do
      rljRpmLog $RESULT
      RESULT=( "${RESULT[@]:1}" )
      VERSION="${VERSION:+"$VERSION, "}$RESULT"
      RESULT=( "${RESULT[@]:1}" )
    done
  fi

  echo "$VERSION"
  return 0
} #end __INTERNAL_extractLibraryVersion

rlImport() {
  local RESULT=0

  if [ -z "$1" ]
  then
    rlLogError "rlImport: At least one argument needs to be provided"
    return 1
  fi

  local WORKLIST="$*"
  if [ "$1" == '--all' ]; then
    rlLogDebug "Try to import all libraries specified in Makefile"
    WORKLIST=$(__INTERNAL_extractRequires "${__INTERNAL_TraverseRoot}")

    if [ -z "$WORKLIST" ]
    then
      rlLogInfo "rlImport: No libraries found in Makefile"
      return 0
    fi
  fi

  local PROCESSING="x"
  local LIBS_TO_LOAD=''

  # Process all arguments
  while true
  do
    rlLogDebug "rlImport: WORKLIST [$WORKLIST]"
    # Pick one library  from the worklist
    PROCESSING="$(__INTERNAL_first $WORKLIST)"
    WORKLIST=$(__INTERNAL_tail $WORKLIST)

    if [ -z "$PROCESSING" ]
    then
      break
    fi

    LIBS_TO_LOAD="$PROCESSING $LIBS_TO_LOAD"

    # Extract two identifiers from an 'component/library' argument
    local COMPONENT=$( echo $PROCESSING | cut -d '/' -f 1 )
    local LIBRARY=$( echo $PROCESSING | cut -d '/' -f 2 )

    local COMPONENT_hash=$( rlHash --algorithm hex "$COMPONENT" )
    local LIBRARY_hash=$( rlHash --algorithm hex "$LIBRARY" )
    local LOCATIONS_varname="__INTERNAL_LIBRARY_LOCATIONS_C${COMPONENT_hash}_L${LIBRARY_hash}"
    local IMPORTS_varname="__INTERNAL_LIBRARY_IMPORTS_C${COMPONENT_hash}_L${LIBRARY_hash}"

    # If the lib was already processed, do nothing
    if [ -n "${!IMPORTS_varname}" ]
    then
      continue
    fi

    if [ -z "$COMPONENT" ] || [ -z "$LIBRARY" ] || [ "$COMPONENT/$LIBRARY" != "$PROCESSING" ]
    then
      rlLogError "rlImport: Malformed argument [$PROCESSING]"
      eval $IMPORTS_varname="FAIL"
      RESULT=1
      continue;
    fi

    rlLogDebug "rlImport: Searching for library $COMPONENT/$LIBRARY"

    # LIBFILE is set inside __INTERNAL_rlLibrarySearch if a suitable path is found
    local LIBFILE=""
    __INTERNAL_rlLibrarySearch $COMPONENT $LIBRARY

    if [ -z "$LIBFILE" ]
    then
      rlLogError "rlImport: Could not find library $PROCESSING"
      eval $IMPORTS_varname="FAIL"
      RESULT=1
      continue;
    else
      rlLogInfo "rlImport: Will try to import $COMPONENT/$LIBRARY from $LIBFILE"
    fi

    rlLogDebug "rlImport: Collecting dependencies for library $COMPONENT/$LIBRARY"
    local LIBDIR="$(dirname $LIBFILE)"
    if ! eval $LOCATIONS_varname='$LIBDIR'
    then
      rlLogError "rlImport: Error processing: $LOCATIONS_varname='$LIBDIR'"
      RESULT=1
      continue
    fi
    WORKLIST="$WORKLIST $(__INTERNAL_extractRequires $LIBDIR )"
    if ! eval $IMPORTS_varname="LOC"
    then
      rlLogError "rlImport: Error processing: $IMPORTS_varname='LOC'"
      RESULT=1
      continue
    fi
  done

  rlLogDebug "rlImport: LIBS_TO_LOAD='$LIBS_TO_LOAD'"
  local library
  for library in $LIBS_TO_LOAD
  do
    local COMPONENT=$( echo $library | cut -d '/' -f 1 )
    local LIBRARY=$( echo $library | cut -d '/' -f 2 )
    local COMPONENT_hash=$( rlHash --algorithm hex "$COMPONENT" )
    local LIBRARY_hash=$( rlHash --algorithm hex "$LIBRARY" )
    local LOCATIONS_varname="__INTERNAL_LIBRARY_LOCATIONS_C${COMPONENT_hash}_L${LIBRARY_hash}"
    local IMPORTS_varname="__INTERNAL_LIBRARY_IMPORTS_C${COMPONENT_hash}_L${LIBRARY_hash}"
    [ "${!IMPORTS_varname}" != "LOC" ] && {
      rlLogDebug "rlImport: skipping $library as it is already processed"
      continue
    }
    local LIBFILE="${!LOCATIONS_varname}/lib.sh"

    # Try to extract a prefix comment from the file found
    # Prefix comment looks like this:
    # library-prefix = wee
    local PREFIX="$( grep -E "library-prefix = [a-zA-Z_][a-zA-Z0-9_]*.*" $LIBFILE | sed 's|.*library-prefix = \([a-zA-Z_][a-zA-Z0-9_]*\).*|\1|')"
    if [ -z "$PREFIX" ]
    then
      rlLogError "rlImport: Could not extract prefix from library $library"
      RESULT=1
      continue;
    fi

    # Construct the validating function
    # Its supposed to be called 'prefixLibraryLoaded'
    local VERIFIER="${PREFIX}LibraryLoaded"
    rlLogDebug "rlImport: Constructed verifier function: $VERIFIER"

    local SOURCEDEBUG=''
    # Try to source the library
    bash -n $LIBFILE && {
      [[ -n "$DEBUG" ]] && {
        SOURCEDEBUG=1
        __INTERNAL_envdebugget
      }
      . $LIBFILE
    }

    # Call the validation callback of the function
    if ! eval $VERIFIER
    then
      rlLogError "rlImport: Import of library $library was not successful (callback failed)"
      RESULT=1
      eval $IMPORTS_varname='FAIL'
      [[ -n "$SOURCEDEBUG" ]] && {
        __INTERNAL_envdebugdiff "$library"
      }
      continue;
    fi
    eval ${PREFIX}LibraryDir="$(dirname $LIBFILE)"
    eval $IMPORTS_varname='PASS'
    [[ -n "$SOURCEDEBUG" ]] && {
      __INTERNAL_envdebugdiff "$library"
    }
  done

  return $RESULT
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Petr Muller <muller@redhat.com>

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut
