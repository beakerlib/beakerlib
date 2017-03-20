#!/bin/bash

UPLOAD_URL="ssh://fedorahosted.org/beakerlib"

doOrDie(){
  local MESSAGE="$1"
  local COMMAND="$2"
  local STDOUT="$(mktemp)" # no-reboot
  local STDERR="$(mktemp)" # no-reboot

  echo -n "$MESSAGE: "

  if eval "$COMMAND" >"$STDOUT" 2>"$STDERR"
  then
    echo "PASS"
    rm -f "$STDOUT" "$STDERR"
  else
    echo "FAIL"
    echo "=== STDOUT ==="
    cat "$STDOUT"
    echo "=== STDERR ==="
    cat "$STDERR"
    rm -f "$STDOUT" "$STDERR"
    exit 1
  fi

  return 0
}

checkOrDie(){
  if ! eval "$1"
  then
    echo -e "$2"
    exit 1
  fi
}

experimental(){
  local CHECKTAG="$1"
  local BRANCH="$2"

  checkOrDie "echo '$BRANCH' | grep -q -v devel" "Experimental release should not be done from devel branch"
  doOrDie "Creating an archive" "git archive --prefix=${CHECKTAG}${BRANCH}/ -o ${CHECKTAG}${BRANCH}.tar.gz HEAD"
}

checkTag() {
  local CHECKTAG="$1"

  if git tag | grep -q -w $CHECKTAG
  then
    echo "Tag $CHECKTAG already exists: update VERSION accordingly"
    exit 1
  else
    echo "Tag $CHECKTAG does not exist: proceeding further"
  fi
}

testing(){
  local CHECKTAG="$1"
  local BRANCH="$2"

  checkOrDie "echo '$CHECKTAG' | grep -q '\.99'" "Version for testing should contain .99 substring\nGot: $CHECKTAG"
  checkOrDie "echo '$BRANCH' | grep -q master" "Testing release should be done from master branch\nGot: $BRANCH"

  doOrDie "Pulling" "git pull"

  checkTag "$CHECKTAG"

  doOrDie "Creating an archive" "git archive --prefix=$CHECKTAG/ -o $CHECKTAG.tar.gz HEAD"
  doOrDie "Tagging commit as $CHECKTAG" "git tag $CHECKTAG"
  doOrDie "Pushing tags out there" "git push --tags"
}

upstream(){
  local CHECKTAG="$1"
  local BRANCH="$2"

  checkOrDie "echo '$CHECKTAG' | grep -q -v '\.99'" "Version for testing should not contain .99 substring\nGot: $CHECKTAG"
  checkOrDie "echo '$BRANCH' | grep -q master" "Testing release should be done from master branch\nGot: $BRANCH"

  doOrDie "Pulling" "git pull"

  checkTag "$CHECKTAG"

  doOrDie "Creating an archive" "git archive --prefix=$CHECKTAG/ -o $CHECKTAG.tar.gz HEAD"
  # TODO: update the main page with new version
	# TODO: create release notes and put it online
  doOrDie "Attempting to publish the tarball" "scp $CHECKTAG.tar.gz fedorahosted.org:beakerlib"
  doOrDie "Tagging commit as $CHECKTAG" "git tag $CHECKTAG"
  doOrDie "Pushing tags out there" "git push --tags"
  rm -f "$CHECKTAG.tar.gz"
}

CHECKTAG="$1"
RELEASE="$2"
BRANCH="$( git rev-parse --abbrev-ref HEAD)"

case "$RELEASE" in
  "experimental")
    experimental "$CHECKTAG" "$BRANCH"
    ;;
  "testing")
    testing "$CHECKTAG" "$BRANCH"
    ;;
  *)
    upstream "$CHECKTAG" "$BRANCH"
    ;;
esac
