. $BEAKERLIB/beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"

rlJournalStart
  rlPhaseStartTest
    for msg in `seq $1`
    do
      [ "$(( $RANDOM % 2 ))" == "0"  ]
      rlAssert0 "Test $msg" $?
    done
  rlPass
  rlPhaseEnd
rlJournalEnd
