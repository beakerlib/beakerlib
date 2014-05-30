# Copyright (c) 2013 Red Hat, Inc. All rights reserved. This copyrighted material 
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
# Author: Petr Muller <muller@redhat.com>

test_storageBasics(){
	local VALUEKEY="$( __INTERNAL_ST_GET key )"
	assertTrue "GET of non-PUT value is empty string" "[ '$VALUEKEY' == '' ]"

	__INTERNAL_ST_PUT key value
	VALUEKEY="$( __INTERNAL_ST_GET key )"
	assertTrue "GET of PUT value is correct" "[ '$VALUEKEY' == 'value' ]"

	__INTERNAL_ST_PUT key newvalue
	VALUEKEY="$( __INTERNAL_ST_GET key )"
	assertTrue "GET of PUT value can be overwritten" "[ '$VALUEKEY' == 'newvalue' ]"

	__INTERNAL_ST_PUT newkey value
	VALUEKEY="$( __INTERNAL_ST_GET key )"
	local VALUENEWKEY="$( __INTERNAL_ST_GET newkey )"
	assertTrue "PUTs of different keys do not interfere" "[ '$VALUEKEY' == 'newvalue' ]"
	assertTrue "PUTs of different keys do not interfere" "[ '$VALUENEWKEY' == 'value' ]"

	__INTERNAL_ST_PRUNE newkey
	VALUEKEY="$( __INTERNAL_ST_GET key )"
	local VALUENEWKEY="$( __INTERNAL_ST_GET newkey )"
	assertTrue "PRUNE does not delete unrelated records" "[ '$VALUEKEY' == 'newvalue' ]"
	assertTrue "PRUNE deletes an appropriate record" "[ '$VALUENEWKEY' == '' ]"
}

test_storageSections(){
  local KEY="key"
  local SEC1="section1"
  local SEC2="section2"

  local V1="value1"
  local V2="value2"

  __INTERNAL_ST_PUT $KEY foo
  __INTERNAL_ST_PUT $KEY $V1 --section="$SEC1"
  __INTERNAL_ST_PUT $KEY $V2 --section="$SEC2"

  assertTrue "Same key, different section: SEC1" "[ '$( __INTERNAL_ST_GET $KEY --section=$SEC1)' == '$V1' ]"
  assertTrue "Same key, different section: SEC2" "[ '$( __INTERNAL_ST_GET $KEY --section=$SEC2)' == '$V2' ]"
  assertTrue "PUT with --section do not interfere with generic section" "[ '$( __INTERNAL_ST_GET $KEY )' == 'foo' ]"

  __INTERNAL_ST_PRUNE $KEY --section=$SEC1
  assertTrue "PRUNE with --section clears appropriate record" "[ '$( __INTERNAL_ST_GET $KEY --section=$SEC1)' == '' ]"
  assertTrue "PRUNE with --section does not interfere with other sections" "[ '$( __INTERNAL_ST_GET $KEY --section=$SEC2)' == '$V2' ]"
  assertTrue "PRUNE with --section do not interfere with generic section" "[ '$( __INTERNAL_ST_GET $KEY )' == 'foo' ]"
}

test_storageNamespaces(){
  local KEY="key"
  local SECTION="section"

  local NS1="namespace1"
  local NS2="namespace2"

  local V1="value1"
  local V2="value2"
  local V3="value3"
  local V4="value4"

  __INTERNAL_ST_PUT $KEY foo
  __INTERNAL_ST_PUT $KEY $V1 --namespace=$NS1
  __INTERNAL_ST_PUT $KEY $V2 --namespace=$NS2
  __INTERNAL_ST_PUT $KEY $V3 --namespace=$NS1 --section=$SECTION
  __INTERNAL_ST_PUT $KEY $V4 --namespace=$NS2 --section=$SECTION

  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [GENERIC]" "[ '$(__INTERNAL_ST_GET $KEY)' == 'foo' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1)' == '$V1' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2)' == '$V2' ]"
  assertTrue "Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1 --section=$SECTION)' == '$V3' ]"
  assertTrue "Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2 --section=$SECTION)' == '$V4' ]"

  __INTERNAL_ST_PRUNE $KEY --namespace=$NS1
  assertTrue "!PRUNED! Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1)' == '' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [GENERIC]" "[ '$(__INTERNAL_ST_GET $KEY)' == 'foo' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2)' == '$V2' ]"
  assertTrue "Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1 --section=$SECTION)' == '$V3' ]"
  assertTrue "Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2 --section=$SECTION)' == '$V4' ]"

  __INTERNAL_ST_PRUNE $KEY --namespace=$NS2 --section=$SECTION
  assertTrue "!PRUNED! Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1)' == '' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [GENERIC]" "[ '$(__INTERNAL_ST_GET $KEY)' == 'foo' ]"
  assertTrue "Key: [$KEY] | Section: [GENERIC] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2)' == '$V2' ]"
  assertTrue "Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS1]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS1 --section=$SECTION)' == '$V3' ]"
  assertTrue "!PRUNED! Key: [$KEY] | Section: [$SECTION] | Namespace: [$NS2]" "[ '$(__INTERNAL_ST_GET $KEY --namespace=$NS2 --section=$SECTION)' == '' ]"
}
