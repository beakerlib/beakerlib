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
  local metadata_yaml="$1/metadata.yaml"
  local main_fmf="$1/main.fmf"
  local yaml_file
  local __INTERNAL_LIBRARY_DEPS

  [[ -f "$metadata_yaml" ]] && yaml_file="$metadata_yaml"
  [[ -f "$main_fmf" ]] && yaml_file="$main_fmf"
  if [ -f "$yaml_file" ]; then
    rlLogDebug "$FUNCNAME(): parsing yaml metadata ($yaml_file)"
    local yaml
    declare -A yaml
    rlYash_parse yaml "$(cat $yaml_file)"
    local i
    for i in `echo "${!yaml[@]}" | grep -E -o -e 'require\S*' -e 'recommend\S*'`; do
      [[ "${yaml[$i]}" =~ library\(([^\)]+)\) ]] && __INTERNAL_LIBRARY_DEPS+=" ${BASH_REMATCH[1]}"
    done
  elif [ -f "$MAKEFILE" ]; then
    # 1) extract RhtsRequires lines, where RhtsRequires is not commented out
    # 2) extract test(/Foo/Bar/Library/Baz) patterns
    # 3) extract Bar/Baz from the patterns
    # 4) make a single line of space-separated library IDs
    rlLogDebug "$FUNCNAME(): parsing Makefile metadata"
    __INTERNAL_LIBRARY_DEPS="$(grep -E '^[^#]*RhtsRequires' $MAKEFILE \
     | grep -E -o -e 'test\(/[^/)]+/[^/)]+/Library/[^/)]+\)' -e '[Ll]ibrary\([^)]*\)' \
     | sed -e 's|test(/[^/)]*/\([^/)]*\)/Library/\([^/)]*\))|\1/\2|g' -e 's|[Ll]ibrary(\(.*\))|\1|' \
     | tr '\n' ' ')"
  else
    return 1
  fi

  rlLogInfo "found dependencies: '$__INTERNAL_LIBRARY_DEPS'"
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
    LIBFILE="$(__INTERNAL_rlLibrarySearchInDir "$DIRECTORY" "$COMPONENT" "$LIBRARY")" && return
  done
  LIBFILE=''
}

__INTERNAL_rlLibrarySearchInDir(){
  local DIRECTORY="$1"
  local COMPONENT="$2"
  local LIBRARY="$3"

  local CANDIDATE
  for CANDIDATE in \
    "$DIRECTORY/$COMPONENT/Library$LIBRARY/lib.sh" \
    "$DIRECTORY/$COMPONENT$LIBRARY/lib.sh" \
    "$DIRECTORY/libs/$COMPONENT$LIBRARY/lib.sh" \
    $DIRECTORY/*/$COMPONENT/Library$LIBRARY/lib.sh \
    $DIRECTORY/libs/*/$COMPONENT/Library$LIBRARY/lib.sh \
    $DIRECTORY/libs/*/$COMPONENT$LIBRARY/lib.sh
  do
    rlLogDebug "$FUNCNAME(): trying '$CANDIDATE'"
    if [[ -f "$CANDIDATE" ]]; then
      echo "$CANDIDATE"
      return 0
    fi
  done

  rlLogDebug "rlImport: Library not found in $BEAKERLIB_LIBRARY_PATH"
  return 1
}

__INTERNAL_rlLibrarySearchInRoot(){
  local COMPONENT="$1"
  local LIBRARY="$2"
  local BEAKERLIB_LIBRARY_PATH="${3:-/mnt/tests}"

  rlLogDebug "rlImport: Trying root: [$BEAKERLIB_LIBRARY_PATH]"

  LIBFILE="$(__INTERNAL_rlLibrarySearchInDir "$BEAKERLIB_LIBRARY_PATH" "$COMPONENT" "$LIBRARY")" && return

  LIBFILE=''
}

__INTERNAL_rlLibrarySearch() {

  local COMPONENT="$1"
  local LIBRARY="$2"

  rlLogDebug "rlImport: Looking if we got BEAKERLIB_LIBRARY_PATH"

  if [ -n "$BEAKERLIB_LIBRARY_PATH" ]
  then
    rlLogDebug "rlImport: BEAKERLIB_LIBRARY_PATH='$BEAKERLIB_LIBRARY_PATH'"
    local paths=( ${BEAKERLIB_LIBRARY_PATH//:/ } )
    while [[ -n "$paths" ]]; do
      rlLogDebug "$FUNCNAME(): trying $paths component of BEAKERLIB_LIBRARY_PATH"
      __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY" "$paths"
      if [ -n "$LIBFILE" ]
      then
        local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT$LIBRARY")"
        VERSION=${VERSION:+", version '$VERSION'"}
        rlLogInfo "rlImport: Found '$COMPONENT$LIBRARY'$VERSION in BEAKERLIB_LIBRARY_PATH"
        return
      fi
      paths=( "${paths[@]:1}" )
    done
  else
    rlLogDebug "rlImport: No BEAKERLIB_LIBRARY_PATH set: trying default"
  fi

  __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY"
  if [ -n "$LIBFILE" ]
  then
    local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
    rlLogInfo "rlImport: Found '$COMPONENT$LIBRARY'$VERSION in /mnt/tests"
    return
  fi

  __INTERNAL_rlLibrarySearchInRoot "$COMPONENT" "$LIBRARY" "/usr/share/beakerlib-libraries"
  if [ -n "$LIBFILE" ]
  then
    local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
    rlLogInfo "rlImport: Found '$COMPONENT$LIBRARY'$VERSION in /usr/share/beakerlib-libraries"
    return
  fi

  if [ -n "$__INTERNAL_TraverseRoot" ]
  then
    rlLogDebug "rlImport: Trying to find the library in directories above test"
    rlLogDebug "rlImport: Starting search at: $__INTERNAL_TraverseRoot"
    __INTERNAL_rlLibraryTraverseUpwards "$__INTERNAL_TraverseRoot" "$COMPONENT" "$LIBRARY"

    if [ -n "$LIBFILE" ]
    then
      local VERSION="$(__INTERNAL_extractLibraryVersion "$LIBFILE" "$COMPONENT$LIBRARY")"
      VERSION=${VERSION:+", version '$VERSION'"}
      rlLogInfo "rlImport: Found '$COMPONENT$LIBRARY'$VERSION during upwards traversal"
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

When test-file calls rlImport with 'foo/bar' parameter, the libraries are searched
in following locations:
these are the possible path prefixes

    - colon-separated paths from $BEAKERLIB_LIBRARY_PATH
    - /mnt/tests
    - /usr/share/beakerlib-libraries

the next component of the path is one of the following:

    - /foo/Library/bar
    - /foo/bar
    - /libs/foo/bar
    - /*/foo/Library/bar
    - /libs/*/foo/Library/bar
    - /libs/*/foo/bar

the directory path is then constructed as prefix/path/lib.sh
If the library is still not found an upwards directory traversal is used, and a
check for presence of the library in the above mentioned possible paths is to be
performed. This means this function needs to be called from the test hierarchy,
not e.g. the /tmp directory.

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

Read $BEAKERLIB_DIR/metadata.yaml or ./Makefile, pickup the library requirements
up and import them all.

=item LIBRARY

Must have 'component[/path]' format. Identifies the library to import.

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
  local IFS
  local RESULT=0

  if [ -z "$1" ]
  then
    rlLogError "rlImport: At least one argument needs to be provided"
    return 1
  fi

  local WORKLIST="$*"
  if [ "$1" == '--all' ]; then
    rlLogDebug "Try to import all libraries specified in fmf metadata or Makefile"
    WORKLIST=$(__INTERNAL_extractRequires "$BEAKERLIB_DIR") || \
    WORKLIST=$(__INTERNAL_extractRequires "${__INTERNAL_TraverseRoot}")

    if [ -z "$WORKLIST" ]
    then
      rlLogInfo "rlImport: No libraries found in metadata.yaml nor Makefile"
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

    # Extract two identifiers from an 'component/library' argument,
    # note that the 'library' may containg further slashes (/)
    [[ "$PROCESSING" =~ ^([^/]+)(/.*)? ]]
    local COMPONENT=${BASH_REMATCH[1]}
    local LIBRARY=${BASH_REMATCH[2]}

    local COMPONENT_hash=$( rlHash --algorithm hex "$COMPONENT" )
    local LIBRARY_hash=$( rlHash --algorithm hex "$LIBRARY" )
    local LOCATIONS_varname="__INTERNAL_LIBRARY_LOCATIONS_C${COMPONENT_hash}_L${LIBRARY_hash}"
    local IMPORTS_varname="__INTERNAL_LIBRARY_IMPORTS_C${COMPONENT_hash}_L${LIBRARY_hash}"

    # If the lib was already processed, do nothing
    if [ -n "${!IMPORTS_varname}" ]
    then
      continue
    fi

    if [ -z "$COMPONENT" ] || [[ "$COMPONENT$LIBRARY" != "$PROCESSING" ]]
    then
      rlLogError "rlImport: Malformed argument [$PROCESSING]"
      eval $IMPORTS_varname="FAIL"
      RESULT=1
      continue;
    fi

    rlLogDebug "rlImport: Searching for library $COMPONENT$LIBRARY"

    # LIBFILE is set inside __INTERNAL_rlLibrarySearch if a suitable path is found
    local LIBFILE=""
    __INTERNAL_rlLibrarySearch "$COMPONENT" "$LIBRARY"

    if [ -z "$LIBFILE" ]
    then
      rlLogError "rlImport: Could not find library $PROCESSING"
      eval $IMPORTS_varname="FAIL"
      RESULT=1
      continue;
    else
      rlLogInfo "rlImport: Will try to import $COMPONENT$LIBRARY from $LIBFILE"
    fi

    rlLogDebug "rlImport: Collecting dependencies for library $COMPONENT$LIBRARY"
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
    [[ "$library" =~ ^([^/]+)(/.*)? ]]
    local COMPONENT=${BASH_REMATCH[1]}
    local LIBRARY=${BASH_REMATCH[2]}
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
    eval ${PREFIX}LibraryDir="${!LOCATIONS_varname}"
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
      eval unset ${PREFIX}LibraryDir
      continue;
    fi
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
