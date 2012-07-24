#!/bin/bash

UPLOAD_URL="ssh://fedorahosted.org/beakerlib"

doOrDie(){
  MESSAGE="$1"
  COMMAND="$2"
  STDOUT=`mktemp`
  STDERR=`mktemp`

  echo -n "$MESSAGE: "

  if eval "$COMMAND" >$STDOUT 2>$STDERR
  then
    echo "PASS"
    rm -f $STDOUT $STDERR
  else
    echo "FAIL"
    echo "=== STDOUT ==="
    cat $STDOUT
    echo "=== STDERR ==="
    cat $STDERR
    rm -f $STDOUT $STDERR
    exit 1
  fi

  return 0
}

main(){
  CHECKTAG="$1"

  doOrDie "Checking out master" "git checkout rpm-agnosticity"
  doOrDie "Pulling" "git pull"
  if git tag | grep -q -w $CHECKTAG
  then
    echo "Tag $CHECKTAG already exists: update VERSION accordingly"
    exit 1
  else
    echo "Tag $CHECKTAG does not exist: proceeding further"
  fi
  doOrDie "Creating an archive" "git archive --prefix=$CHECKTAG/ -o $CHECKTAG.tar.gz HEAD"
  # TODO: update the main page with new version
	# TODO: create release notes and put it online
  doOrDie "Attempting to publish the tarball" "scp $CHECKTAG.tar.gz fedorahosted.org:beakerlib"
  doOrDie "Tagging commit as $CHECKTAG" "git tag $CHECKTAG"
  doOrDie "Pushing tags out there" "git push --tags"
  rm -f $CHECKTAG.tar.gz
}

CHECKTAG="$1"

main "$CHECKTAG"
