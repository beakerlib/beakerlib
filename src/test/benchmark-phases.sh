. $BEAKERLIB/beakerlib.sh
export __INTERNAL_JOURNALIST="$BEAKERLIB/python/journalling.py"

rlJournalStart
  for msg in `seq $1`
  do
    rlPhaseStartTest
      rlLog "Message $msg"
      rlPass
    rlPhaseEnd
  done
rlJournalEnd
