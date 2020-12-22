#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: ya.sh
#   Description: YAml parser in pure baSH
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   YAml parser in pure baSH
#
#   Copyright © 2020 Dalibor Pospisil <sopos@sopos.eu>
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to
#   deal in the Software without restriction, including without limitation the
#   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
#   sell copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#   IN THE SOFTWARE.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 NAME

BeakerLib - ya.sh - a YAml parser in pure baSH

=head1 DESCRIPTION

This file contains a yaml parser to help to handle yaml metadata.

=head1 FUNCTIONS

=cut

yashLog() {
  printf ":: [ %(%T)T ] :: [ %s ] :: " -1 "${2:-" LOG "}" >&2
  echo -e "$1" >&2
}

yashLogDebug() {
  [[ -n "$DEBUG" ]] && yashLog "${FUNCNAME[1]}(): $1" "DEBUG"
}

yashLogError() {
  yashLog "${FUNCNAME[1]}(): $1" "ERROR"
}

__INTERNAL_yash_get_next() {
  local line IFS=$'\n' buffer_item type_name="$1" item_name="$2" yaml_data_name="$3"
  [[ -z "${!yaml_data_name}" ]] && return 1
  {
    read -r line
    buffer_item="$line"$'\n'
    if [[ "${line:0:1}" == '-' ]]; then
      yashLogDebug "detected list item '$line'"
      eval "$type_name='index'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[ -z "$line" || "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    else
      yashLogDebug "detected associative array item '$line'"
      eval "$type_name='key'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[ -z "$line" || "${line:0:1}" == "-" || "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    fi
  } <<< "${!yaml_data_name}"
  eval "${item_name}=\"\${buffer_item::-1}\""
  eval "${yaml_data_name}=\"\${buffer_rest::-1}\""
}

__INTERNAL_yash_clean() {
  # remove comments
  local line IFS=$'\n' buffer non_space out="$1" in="$2"
  while read -r line; do
    [[ "$line" == "---" ]] && {
      buffer=''
      continue
    }
    # remove first empty lines
    [[ -z "$non_space" && "$line" =~ ^[[:space:]]*$ ]] && {
      non_space=1
      continue
    }
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    buffer+=$'\n'"$line"
  done <<< "$in"
  eval "$out=\"\${buffer:1}\""
}

__INTERNAL_yash_parse_item() {
  local IFS=$'\n' line buffer type_name="$1" key_name="$2" val_name="$3" item="$4" type
  {
    read -r line
    if [[ "${line:0:1}" == "-" ]]; then
      eval "$key_name=''"
      yashLogDebug "detected list item '${!key_name}'"
      type='list'
      buffer=" ${line:1}"$'\n'
    elif [[ "$line" =~ ^[[:space:]]*([^[:space:]][^:]*):(.*) ]]; then
      # strip starting spaces
      eval "$key_name=\"\${BASH_REMATCH[1]}\""
      yashLogDebug "detected associative array item '${!key_name}'"
      type='array'
      buffer="${BASH_REMATCH[2]}"$'\n'
      # strip trailing spaces
      [[ "${!key_name}" =~ (.*[^[:space:]])[[:space:]]*$ ]]
      eval "$key_name=\"\${BASH_REMATCH[1]}\""
    else
      yashLogError "could not parse item '$line'"
      return 1
    fi
    while read -r line; do
      buffer+="${line}"$'\n'
    done
  } <<< "$item"
  eval "$val_name=\"\${buffer::-1}\""
  yashLogDebug "  with value '${!val_name}'"
  __INTERNAL_yash_sanitize_value "${type_name}" "${val_name}" || return 1
}

__INTERNAL_yash_sanitize_value() {
  local IFS=$'\n' line buffer type_name="$1" val_name="$2" indent space=' ' skip_last buffer2 i item2
  {
    while read -r line; do
      [[ "$line" =~ ^[[:space:]]*$ ]] || break
    done
    if [[ "$line" =~ ^[[:space:]]*\|([+-]?)[[:space:]]*$ ]]; then
      skip_last="${BASH_REMATCH[1]}"
      yashLogDebug "multiline text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      buffer+=$'\n'"${line:$indent}"
      while read -r line; do
        buffer+=$'\n'"${line:$indent}"
      done
      buffer+=$'\n'
      i=${#buffer}
      let i--
      while [[ $i -ge 0 && "${buffer:$i:1}" == $'\n' ]]; do let i--; done; let i++
      if [[ "$skip_last" == "-" ]]; then
        buffer="${buffer:0:$i}"
      elif [[ "$skip_last" == "" ]]; then
        let i++
        buffer="${buffer:0:$i}"
      fi
    elif [[ "$line" =~ ^[[:space:]]*\>([+-]?)[[:space:]]*$ ]]; then
      skip_last="${BASH_REMATCH[1]}"
      yashLogDebug "wrapped text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer+="${space}${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        [[ -z "${line:$indent}" ]] && {
          buffer+=$'\n'
          space=''
          :
        } || {
          [[ "${line:$indent:1}" == " " ]] && buffer+=$'\n'
          buffer+="${space}${line:$indent}"
          space=' '
        }
      done
      buffer+=$'\n'
      i=${#buffer}
      let i--
      while [[ $i -ge 0 && "${buffer:$i:1}" == $'\n' ]]; do let i--; done; let i++
      if [[ "$skip_last" == "-" ]]; then
        buffer="${buffer:0:$i}"
      elif [[ "$skip_last" == "" ]]; then
        let i++
        buffer="${buffer:0:$i}"
      fi
    elif [[ "$line" =~ ^[[:space:]]*(\[|\{) ]]; then
      local json_begin json_end json_prefix
      if [[ "${BASH_REMATCH[1]}" == "[" ]]; then
        yashLogDebug "json list"
        json_begin='[' json_end=']' json_prefix='- '
      else
        yashLogDebug "json dict"
        json_begin='{' json_end='}'
      fi
      eval "${type_name}=struct"
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer+="${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+=$'\n'"${line:$indent}"
      done
      eval "[[ \"\$buffer\" =~ ^[^$json_begin]*\\$json_begin(.*)\\$json_end[^$json_end]*\$ ]]"
      buffer2="${BASH_REMATCH[1]}"
      buffer=''
      item2=''
      while read -r -N 1 line; do
        yashLogDebug "processing element '$line'"
        [[ "$line" == "," ]] && {
          while read -r -N 1 line; do
            [[ "$line" == " " ]] || break
          done
          yashLogDebug "processing element '$line'"
          buffer+=$'\n'"$json_prefix$item2"
          item2=''
        }
        [[ "$line" == '[' || "$line" == '{' ]] && {
          i=1;
          item2+="$line"
          while read -r -N 1 line; do
            yashLogDebug "processing brackets inside '$line'"
            [[ "$line" == '[' || "$line" == '{' ]] && let i++
            [[ "$line" == ']' || "$line" == '}' ]] && let i--
            item2+="$line"
            [[ $i -eq 0 ]] && break
          done
          continue
        }
        item2+="$line"
      done <<< "$buffer2"
      [[ -n "$item2" && ! "$item2" =~ ^[[:space:]]*$ ]] && buffer+=$'\n'"$json_prefix$item2"
    elif [[ "$line" =~ ^[[:space:]]*-([[:space:]]|$) || "$line" =~ ^[^:]*:([[:space:]]|$) ]]; then
      yashLogDebug "sub-structure"
      eval "${type_name}=struct"
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer+=$'\n'"${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+=$'\n'"${line:$indent}"
      done
    else
      yashLogDebug "simple string"
      eval "${type_name}=text"
      [[ "$line" =~ ^[[:space:]]$ ]] && read -r line
      [[ "$line" =~ ^[[:space:]]*([^[:space:]].*)$ ]]
      line="${BASH_REMATCH[1]}"
      [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
      buffer+="${space}${BASH_REMATCH[1]}"
      while read -r line; do
        [[ "$line" =~ ^[[:space:]]*(.*)$ ]]
        line="${BASH_REMATCH[1]}"
        [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
        [[ -n "${BASH_REMATCH[1]}" ]] && \
        buffer+="${space}${BASH_REMATCH[1]}"
      done
    fi
  } <<< "${!val_name}"
  eval "$val_name=\"\${buffer:1}\""
}

__INTERNAL_yash_unquote() {
  local var_name="$1"
  if [[ "${!var_name}" =~ ^[[:space:]]*\".*\"[[:space:]]*$ ]] || [[ "${!var_name}" =~ ^[[:space:]]*\'.*\'[[:space:]]*$ ]]; then #"
    eval "$var_name=${!var_name}" || {
      yashLogError "could not unquote ${!var_name}"
      return 1
    }
  fi
}

: <<'=cut'
=pod

=head3 yash_parse

Parse yaml data to the associative array.

    yash_parse VAR_NAME YAML_DATA

=over

=item VAR_NAME

Name of the variable to which the yaml structure will be saved.

Note that the variable needs to be predeclared as an associative array.

=item YAML_DATA

The actual yaml data.

=back

=cut

yash_parse() {
  local yaml_data item key value data_type item_type item_type_prev prefix="$3" index=0 yaml_name="$1" res=0
  __INTERNAL_yash_clean yaml_data "$2"

  yashLogDebug "$yaml_data"
  yashLogDebug "============================="
  yashLogDebug ""

  while __INTERNAL_yash_get_next item_type item yaml_data; do
    [[ -n "$item_type_prev" ]] && {
      [[ "$item_type_prev" == "$item_type" ]] || { yashLogError "invalid input - different item types in one list"; return 1; }
    }
    item_type_prev="$item_type"
    __INTERNAL_yash_parse_item data_type key value "$item" || return 1
    [[ "$item_type" == "index" ]] && key=$((index++))
    __INTERNAL_yash_unquote key || return 1
    yashLogDebug "$prefix$key ($data_type):"
    yashLogDebug "$value'"
    yashLogDebug "-----------------------------"
    [[ "$data_type" != "struct" ]] && {
      [[ -z "$value" ]] && {
        eval "${yaml_name}['$prefix$key']='null'"
      } || {
        __INTERNAL_yash_unquote value || return 1
        eval "${yaml_name}['$prefix$key']=\"\${value}\""
      }
    }
    if [[ "$data_type" == "struct" ]]; then
      yashLogDebug "_____________________________"
      yash_parse "$yaml_name" "$value" "$prefix$key." || return 1
    fi
  done
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <sopos@sopos.eu>

=back

=cut
