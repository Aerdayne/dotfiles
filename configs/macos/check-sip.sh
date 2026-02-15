#!/usr/bin/env bash
set -e

if ! csrutil status 2>&1 | grep -q "NVRAM Protections: disabled"; then
    echo "Error: SIP NVRAM protections not disabled. See configs/macos/disable-sip.sh"
    exit 1
fi

echo "SIP configured correctly"
