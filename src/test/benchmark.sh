#!/usr/bin/bash

export BEAKERLIB="$PWD/.."
export TESTID='123456'
export TEST='beakerlib-benchmarks'
. ../beakerlib.sh

export TIMEFORMAT="System: %S seconds; User: %U seconds"
TIMEFILE=$( mktemp -u ) # no-reboot

for benchmark in messages tests
do
  for count in 100 200 300 400 500 600 700 800 900 1000 1100 1200
  do
    rm -rf /var/tmp/beakerlib-123456
    rm -f $TIMEFILE.$benchmark
    echo -n "Running $benchmark benchmark with $count records: "
    ( time ( { ./benchmark-$benchmark.sh $count &>/dev/null; } 2>&3 ) ) 3>&2 2>>$TIMEFILE.$benchmark
    cat $TIMEFILE.$benchmark
    OLDFILE=".benchmark-$count-$benchmark.old"
    if [ -e $OLDFILE ]
    then
      echo -n "                           With $count old was: "
      cat $OLDFILE
    fi
    rm -f $OLDFILE
    cp $TIMEFILE.$benchmark $OLDFILE
  done
done
