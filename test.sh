#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/videoharbor-tests.XXXXXX")"
SDK_PATH="$(xcrun --show-sdk-path)"
ARCHITECTURE="$(uname -m)"
TARGET="$ARCHITECTURE-apple-macos14.0"

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    rm -rf -- "$BUILD_DIR"
    exit "$status"
}
trap cleanup EXIT INT TERM

swiftc \
    -swift-version 5 \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    "$PROJECT_DIR"/Sources/VideoHarborCore/*.swift \
    "$PROJECT_DIR/Tests/StandaloneTests/main.swift" \
    -o "$BUILD_DIR/VideoHarborCoreTests"

"$BUILD_DIR/VideoHarborCoreTests"
