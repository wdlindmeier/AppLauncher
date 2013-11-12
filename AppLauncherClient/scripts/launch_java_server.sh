#!/bin/sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
/bin/sh $DIR/launch_mpe_server.sh "cd /Users/bill/Documents/ITP/BIG-MPE/MPE-Processing/Most-Pixels-Ever-Server/java/src && 
java mpe/server/MPEServer -xml../data/settings.debug.xml"
