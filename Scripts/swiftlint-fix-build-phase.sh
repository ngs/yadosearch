#!/usr/bin/env bash
#
# Build phase: auto-fix what SwiftLint can, then report what is left.
# Wired in by Project.swift as a pre-build script on the app target.

if which swiftlint >/dev/null; then
    swiftlint --fix --config "${SRCROOT}/.swiftlint.yml" \
        "${SRCROOT}/Sources" \
        "${SRCROOT}/Tests" 2>/dev/null

    swiftlint --config "${SRCROOT}/.swiftlint.yml" \
        "${SRCROOT}/Sources" \
        "${SRCROOT}/Tests"
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
