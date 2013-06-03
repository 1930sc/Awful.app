#!/usr/bin/env bash
set -e
SCRIPTDIR=$( cd "$(dirname "$0")"; pwd -P )
cd Xcode

XCODEFLAGS=(-configuration "App Store" -sdk iphonesimulator TEST_AFTER_BUILD=YES)

xcodebuild -alltargets clean "${XCODEFLAGS[@]}"
xcodebuild -target ParsingTests "${XCODEFLAGS[@]}" 2>&1 | awk -f "$SCRIPTDIR/xcodebuild.awk"
