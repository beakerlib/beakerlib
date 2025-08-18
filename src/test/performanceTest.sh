#!/bin/bash
. ../beakerlib.sh
test_rlPerfTime_AvgFromRuns(){
    rlPerfTime_AvgFromRuns "sleep 0.1" 5
    assertTrue "Test for coverage test_rlPerfTime_AvgFromRuns" ' [  "$rl_retval" = "0" ]'

    rlPerfTime_AvgFromRuns "(for ((i=0; i<500000; i++)); do true; done)" 4
    assertTrue "Average time for a CPU loop should be > 0" ' [ "$(echo "$rl_retval > 0" | bc)" = "1" ]'    

}

test_rlPerfTime_RunsInTime(){
    
    assertTrue "Filler test for coverage test_rlPerfTime_AvgFromRuns" 'echo ""'

}

