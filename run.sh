#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/videoharbor-run.XXXXXX")"
EXECUTABLE="$RUN_DIR/VideoHarbor"
SDK_PATH="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macos14.0"
CHECK_ONLY=false

if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--check]" >&2
    exit 2
fi

cleanup() {
    local result=$?
    trap - EXIT INT TERM
    rm -rf -- "$RUN_DIR"
    exit "$result"
}
trap cleanup EXIT INT TERM

swiftc \
    -swift-version 5 \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -Onone \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework QuartzCore \
    -framework UniformTypeIdentifiers \
    "$PROJECT_DIR"/Sources/VideoHarborCore/*.swift \
    "$PROJECT_DIR"/Sources/VideoHarbor/*.swift \
    -o "$EXECUTABLE"

if [[ "$CHECK_ONLY" == true ]]; then
    file "$EXECUTABLE"
    echo "VideoHarbor development build passed."
else
    "$EXECUTABLE"
fi
