#!/bin/bash


pushd /home/jheger/baka/new_breakerlib/beakerlib

checkout=$(git checkout jheger 2>&1 >/dev/null)
echo $checkout

if echo $checkout | egrep "Already"; then
    git checkout devel
fi

make 
make install 


popd
