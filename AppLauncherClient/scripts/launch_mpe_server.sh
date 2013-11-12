#!/bin/sh
server_was_running=false

# Kill Python server if its running
if [ "$(/usr/bin/pgrep -f mpe_server.py)" ]; then
    server_was_running=true
    /usr/bin/pkill -f mpe_server.py
fi

# Kill Java server if its running
if [ "$(/usr/bin/pgrep -f MPEServer)" ]; then
    server_was_running=true
    /usr/bin/pkill -f MPEServer
fi

# Give the servers a second to wind down. 
# We don't want them to thwart our connection attempt.
if $server_was_running; then
    sleep 2
fi

# Launch the python server. 
# $1 is the script argument which should be the path to the server
# /Users/bill/Tools/cinder_master/blocks/Most-Pixels-Ever-Cinder/mpe-python-server/mpe_server.py
eval $1 &