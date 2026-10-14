#!/usr/bin/env bash
# Starts the Termux build of Denova and forwards extra arguments to the backend.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${ROOT_DIR}"

if [ ! -x output/denova ]; then
    printf 'No build found; running scripts/termux-build.sh first\n'
    "${ROOT_DIR}/scripts/termux-build.sh"
fi

if ! command -v rg >/dev/null 2>&1; then
    printf 'Warning: ripgrep (rg) not found; run "pkg install ripgrep" for the agent grep and glob tools\n' >&2
fi

if ! command -v termux-open-url >/dev/null 2>&1; then
    printf 'Note: run "pkg install termux-api" and install the Termux:API app to let Denova open the browser automatically\n' >&2
fi

printf 'Starting Denova. Keep Termux alive with "termux-wake-lock" if you switch to the browser.\n'
./output/denova "$@"
