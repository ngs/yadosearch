#!/usr/bin/env bash
#
# Prints the UDID of an available iPhone simulator on the newest iOS runtime
# that meets the app's deployment target.
#
# Needed because runner images keep older runtimes around: a plain "first iPhone
# in the list" picks an iOS 18 device, and `xcodebuild` then refuses the
# destination outright because the app requires iOS 26.

set -euo pipefail

MINIMUM_MAJOR="${1:-26}"

xcrun simctl list devices available --json | MINIMUM_MAJOR="$MINIMUM_MAJOR" python3 -c '
import json, os, re, sys

minimum = int(os.environ["MINIMUM_MAJOR"])
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    if version[0] < minimum:
        continue
    for device in entries:
        if not device.get("isAvailable") or "iPhone" not in device["name"]:
            continue
        if best is None or version > best[0]:
            best = (version, device["udid"], device["name"])

if best is None:
    sys.stderr.write(f"no available iPhone simulator on iOS {minimum} or newer\n")
    sys.exit(1)

sys.stderr.write(f"using {best[2]} (iOS {best[0][0]}.{best[0][1]})\n")
print(best[1])
'
