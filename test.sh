#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/work/tests"
SDK_PATH="$(xcrun --show-sdk-path)"
ARCHITECTURE="$(uname -m)"
TARGET="$ARCHITECTURE-apple-macos14.0"

mkdir -p "$BUILD_DIR"

swiftc \
    -swift-version 5 \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    "$PROJECT_DIR"/Sources/VideoHarborCore/*.swift \
    "$PROJECT_DIR/Tests/StandaloneTests/main.swift" \
    -o "$BUILD_DIR/VideoHarborCoreTests"

"$BUILD_DIR/VideoHarborCoreTests"
