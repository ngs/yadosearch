#!/usr/bin/env bash
#
# Generates the Xcode project with the Jalan Web Service key wired in.
#
# The key never lives in the repository. Locally it comes from `.env`
# (gitignored); in CI it arrives as the JALAN_API_KEY environment variable,
# fed from a repository secret. Without one the generated app still builds —
# it just reports the missing key instead of making requests that would all
# come back rejected.
#
#   Scripts/generate.sh            # generate and open the workspace
#   Scripts/generate.sh --no-open  # what CI runs

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

export TUIST_JALAN_API_KEY="${JALAN_API_KEY:-}"

if [ -z "$TUIST_JALAN_API_KEY" ]; then
    echo "warning: JALAN_API_KEY is unset — the app will build but cannot search." >&2
    echo "         Put JALAN_API_KEY=… in .env (see README)." >&2
fi

exec tuist generate "$@"
