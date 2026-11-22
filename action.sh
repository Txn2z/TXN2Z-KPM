#!/bin/sh

if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    echo "- Launching WebUI in KSUWebUIStandalone..."
    am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "Txn2z-KPM"
    echo "- WebUI launched successfully."
else
    echo "! No WebUI app found"
    
fi
