#!/usr/bin/bash

OUTPUT=$( mktemp ) # no-reboot

find . -type f | grep -v -e runtest.sh -e check-tempfiles.sh -e '.git' -e '\.swp' -e 'src/test' -e '\.pyc' -e 'Build/' | \
  xargs grep -e mktemp -e mkstemp -e '/tmp/' | \
  grep -v -e "# no-reboot" -e "__INTERNAL_PERSISTENT_TMP" &> $OUTPUT

RC=$?

if [ $RC -eq 0 ]
then
  echo "Several non-annotated temporary file usages found:"
  echo "=================================================="
  cat $OUTPUT
  echo "=================================================="
  echo "Please annotate intentional /tmp directory usage with # no-reboot"
  echo "comment, or change the directory to \$__INTERNAL_PERSISTENT_TMP"
  rm -f $OUTPUT
  exit 1
fi

rm -f $OUTPUT
