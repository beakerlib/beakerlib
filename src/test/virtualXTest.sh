#/bin/bash

test_rlVirtXGetCorrectID(){

    local output=$(rlVirtXGetCorrectID "mytestID123")

    assertTrue "Correct ID for mytestID123" '[ "mytestID123" == "$output" ]'

    

    output=$(rlVirtXGetCorrectID "mytest.ID123!")

    assertTrue "Correct ID for mytest.ID123!" '[ "mytestID123" == "$output" ]'

    

    output=$(rlVirtXGetCorrectID "mytest ID 123")

    assertTrue "Correct ID for mytest ID 123" '[ "mytestID123" == "$output" ]'

} 

GLOBAL_TEST_BASE_ID="beakerlib_virtx_test_$(date +%s)"
_LAST_STARTED_DISPLAY_ID=""
_LAST_STARTED_DISPLAY_NUM=""
_START_DISPLAY_NUM=""
_START_DISPLAY_ID=""

trap 'pkill -9 Xvfb 2>/dev/null ; rm -rf /tmp/beakerlib_virtx_test_*' EXIT



test_rlVirtualXStart() {

    local test_id="${GLOBAL_TEST_BASE_ID}_start"
    local corrected_id=$(rlVirtXGetCorrectID "$test_id")
    local display_num=1
    assertLog "Attempting to start X server for ID: $test_id on display $display_num" "INFO"

    assertTrue "rlVirtualXStart should successfully start the virtual X server" \
        "rlVirtualXStart '$test_id' '$display_num'"

    # Verify side effects: Check for Xvfb process and PID file
    local pid_path="/tmp/$corrected_id/pid"
    local xvfb_pid=""

    # Give Xvfb a moment to start and write PID
    sleep 1

    assertTrue "PID file for $test_id should exist after start" "[ -f '$pid_path' ]"
    xvfb_pid=$(cat "$pid_path")
    assertLog "Xvfb PID for $test_id: $xvfb_pid" "INFO"
    assertTrue "Xvfb process for $test_id should be running (check ps)" \
        'ps -p '$xvfb_pid' -o cmd= | grep -q Xvfb'
    
    _START_DISPLAY_NUM="$display_num"
    _START_DISPLAY_ID="$corrected_id"
}


test_rlVirtXStartDisplay() {

    # For robust testing, we ensure no Xvfb processes are running before this specific test.
	#    pkill -9 Xvfb 2>/dev/null

    local test_id="${GLOBAL_TEST_BASE_ID}_display"
    local corrected_id=$(rlVirtXGetCorrectID "$test_id")
    local display_num=2
    assertLog "Attempting to start X display for ID: $test_id on display $display_num" "INFO"

    # Call rlVirtXStartDisplay and check its success
    assertTrue "rlVirtXStartDisplay should successfully start the display" \
        'rlVirtXStartDisplay '$test_id' '$display_num''

    # Verify side effects (PID file and running process)
    local pid_path="/tmp/$corrected_id/pid"
    local xvfb_pid=""
    sleep 1 # Give Xvfb time to write PID

    assertTrue "PID file for $test_id should exist after StartDisplay" "[ -f '$pid_path' ]"
    xvfb_pid=$(cat "$pid_path")
    assertLog "Xvfb PID for $test_id: $xvfb_pid" "INFO"
    assertTrue "Xvfb process for $test_id should be running (check ps after StartDisplay)" \
        'ps -p '$xvfb_pid' -o cmd= | grep -q Xvfb'

    _LAST_STARTED_DISPLAY_ID="$corrected_id"
    _LAST_STARTED_DISPLAY_NUM="$display_num"
}


test_rlVirtualXGetDisplay() {
    # This test relies on an X server started by test_rlVirtXStartDisplay or similar.

    local out=$(rlVirtualXGetDisplay "$_LAST_STARTED_DISPLAY_ID")
    local expected_display_output=":$_LAST_STARTED_DISPLAY_NUM" 

    assertTrue "rlVirtualXGetDisplay should return the correct display string" \
        '[ "$expected_display_output" == "$out" ]'

    out=$(rlVirtualXGetDisplay "$_START_DISPLAY_ID")
    expected_display_output=":$_START_DISPLAY_NUM" 

    assertTrue "rlVirtualXGetDisplay should return the correct display string" \
        '[ "$expected_display_output" == "$out" ]'

    # Test for non-existent display (should return empty output and non-zero code)
    local non_existent_id="non-existent-display"
    local output_no_display=$(rlVirtualXGetDisplay "$non_existent_id")
    
   
    assertTrue "rlVirtualXGetDisplay should return nothing for non-existent display" ' [ ""  == "$output_no_display" ] '
    assertFalse "rlVirtualXGetDisplay should return non-zero for non-existent display" ' rlVirtualXGetDisplay "$non_existent_id" '
}



test_rlVirtXGetPid() {

    assertFalse "rlVirtXGetPid non-existent-display" 'rlVirtXGetPid "non-existent-display"'
    
    local out=$(rlVirtXGetPid "$_START_DISPLAY_ID")
    local exp=$( cat "/tmp/$_START_DISPLAY_ID/pid")

    assertTrue "rlVirtXGetPid start" '[ "$out" == $exp  ]'
    
    out=$(rlVirtXGetPid "$_LAST_STARTED_DISPLAY_ID")
    exp=$( cat "/tmp/$_LAST_STARTED_DISPLAY_ID/pid")

    assertTrue "rlVirtXGetPid display" '[ "$out" == $exp  ]'
}


test_rlVirtualXStop() {

    local pid_path1="/tmp/$_START_DISPLAY_ID/pid"
    local pid_path2="/tmp/$_LAST_STARTED_DISPLAY_ID/pid"

    # Execute rlVirtualXStop
    assertTrue "rlVirtualXStop should successfully stop _START_DISPLAY_ID" \
        'rlVirtualXStop "$_START_DISPLAY_ID"' 

    # Verify cleanup: Processes should be killed and PID files/directories removed
    sleep 1 # Give time for processes to terminate

    assertFalse "First Xvfb process should be killed after stop" \
        'ps -p $(cat $pid_path1 2>/dev/null || echo '0') -o cmd= | grep -q Xvfb'
    

    assertTrue "rlVirtualXStop should successfully stop _LAST_STARTED_DISPLAY_ID" \
        'rlVirtualXStop "$_LAST_STARTED_DISPLAY_ID"' 
    
    sleep 1
    
    assertFalse "Second Xvfb process should be killed after stop" \
        'ps -p $(cat $pid_path2 2>/dev/null || echo '0') -o cmd= | grep -q Xvfb'
}

