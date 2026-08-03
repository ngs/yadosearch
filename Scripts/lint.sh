#!/usr/bin/env bash
#
# SwiftLint wrapper: check (default), fix, or strict (what CI runs).

set -euo pipefail

if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint is not installed. Install it with: brew install swiftlint" >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

case "${1:-check}" in
    check)
        swiftlint lint --quiet
        ;;
    fix)
        swiftlint lint --fix --quiet
        ;;
    strict)
        swiftlint lint --strict
        ;;
    *)
        echo "Usage: $0 [check|fix|strict]" >&2
        exit 1
        ;;
esac
