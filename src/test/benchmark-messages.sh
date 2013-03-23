. $BEAKERLIB/beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"

rlJournalStart
  rlPhaseStartTest
    for msg in `seq $1`
    do
      rlLog "Message $msg"
    done
  rlPass
  rlPhaseEnd
rlJournalEnd
