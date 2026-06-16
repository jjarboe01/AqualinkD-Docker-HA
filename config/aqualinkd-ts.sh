#!/bin/bash
# Always overwrite the persisted aqexec-pre.sh with the version baked into this image
cp /usr/local/bin/aqexec-pre-impl.sh /aquadconf/aqexec-pre.sh
chmod +x /aquadconf/aqexec-pre.sh
# Start aqualinkd with timestamp logging
/usr/local/bin/aqualinkd-docker 2>&1 | awk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush()}'
