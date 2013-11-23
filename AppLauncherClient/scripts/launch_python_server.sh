#!/bin/sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
/bin/sh $DIR/launch_mpe_server.sh "/Users/bill/Tools/cinder_master/blocks/Most-Pixels-Ever-Cinder/mpe-python-server/mpe_server.py --screens 3"