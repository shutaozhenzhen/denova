#!/usr/bin/env bash
# Builds Denova for the local Termux (Android) host.
#
# Android seccomp blocks faccessat2, so a GOOS=linux binary aborts with SIGSYS
# on its first os/exec.LookPath call. The android target is therefore mandatory
# and is also Termux's Go default, so nothing here cross-compiles.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${ROOT_DIR}"

OUTPUT_DIR="output"
VERSION="${DENOVA_VERSION:-dev}"

info() { printf '==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_command go
require_command node
require_command pnpm

if [ "$(go env GOOS)" != "android" ]; then
    fail "Go targets $(go env GOOS)/$(go env GOARCH); this build must use the android target so the binary survives Android's seccomp policy (unset GOOS and GOARCH)"
fi

# pnpm 12 is a Rust binary whose store lock relies on File::lock_shared, which
# Rust reports as unsupported on Android. pnpm 11 is the version this repository
# pins and the highest one that can install packages on Termux.
pnpm_version="$(pnpm --version)"
pnpm_major="${pnpm_version%%.*}"
case "${pnpm_major}" in
    '' | *[!0-9]*)
        warn "could not determine the pnpm major version from '\''${pnpm_version}'\''"
        ;;
    *)
        if [ "${pnpm_major}" -ge 12 ]; then
            fail "pnpm ${pnpm_major} cannot acquire its store lock on Android; install pnpm 11 first: npm install -g pnpm@11"
        fi
        ;;
esac

if ! command -v rg >/dev/null 2>&1; then
    warn "ripgrep (rg) not found; the agent grep and glob tools need it (pkg install ripgrep)"
fi

info "installing frontend dependencies"
pnpm --dir web install --frozen-lockfile

info "building frontend"
pnpm --dir web build

if [ ! -s web/dist/index.html ]; then
    fail "the frontend build produced no web/dist/index.html"
fi

info "embedding frontend resources"
rm -rf internal/webfs/dist
cp -R web/dist internal/webfs/dist

info "compiling denova"
mkdir -p "${OUTPUT_DIR}"
CGO_ENABLED=0 go build -tags embedweb -trimpath \
    -ldflags "-s -w -X denova/internal/buildinfo.Version=${VERSION}" \
    -o "${OUTPUT_DIR}/denova" ./cmd/denova
CGO_ENABLED=0 go build -trimpath \
    -ldflags "-s -w -X denova/internal/buildinfo.Version=${VERSION}" \
    -o "${OUTPUT_DIR}/denova-updater" ./cmd/denova-updater
chmod 0755 "${OUTPUT_DIR}/denova" "${OUTPUT_DIR}/denova-updater"

info "build complete (version ${VERSION})"
ls -la "${OUTPUT_DIR}" | sed '1d'
printf '\nStart it with: ./scripts/termux-run.sh\n'
