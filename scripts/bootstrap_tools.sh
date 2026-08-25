#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/Resources/Tools"
BOOTSTRAP_DIR="$PROJECT_DIR/work/tool-bootstrap"
YT_DLP_VERSION="2026.07.04"
NODE_VERSION="24.16.0"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Bundled release tools currently require an Apple Silicon Mac." >&2
    exit 1
fi

for command_name in curl shasum tar; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
done

mkdir -p "$TOOLS_DIR" "$BOOTSTRAP_DIR"

echo "[1/3] Fetching yt-dlp $YT_DLP_VERSION"
YT_DLP_ASSET="$BOOTSTRAP_DIR/yt-dlp_macos"
YT_DLP_SUMS="$BOOTSTRAP_DIR/yt-dlp-SHA2-256SUMS"
curl --fail --location --retry 3 \
    "https://github.com/yt-dlp/yt-dlp/releases/download/$YT_DLP_VERSION/yt-dlp_macos" \
    --output "$YT_DLP_ASSET"
curl --fail --location --retry 3 \
    "https://github.com/yt-dlp/yt-dlp/releases/download/$YT_DLP_VERSION/SHA2-256SUMS" \
    --output "$YT_DLP_SUMS"
(
    cd "$BOOTSTRAP_DIR"
    grep ' yt-dlp_macos$' "$(basename "$YT_DLP_SUMS")" | shasum -a 256 -c -
)
install -m 755 "$YT_DLP_ASSET" "$TOOLS_DIR/yt-dlp"

echo "[2/3] Fetching Node.js $NODE_VERSION"
NODE_ARCHIVE="node-v$NODE_VERSION-darwin-arm64.tar.gz"
NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION"
curl --fail --location --retry 3 "$NODE_BASE_URL/$NODE_ARCHIVE" \
    --output "$BOOTSTRAP_DIR/$NODE_ARCHIVE"
curl --fail --location --retry 3 "$NODE_BASE_URL/SHASUMS256.txt" \
    --output "$BOOTSTRAP_DIR/node-SHASUMS256.txt"
(
    cd "$BOOTSTRAP_DIR"
    grep " $NODE_ARCHIVE\$" node-SHASUMS256.txt | shasum -a 256 -c -
)
tar -xzf "$BOOTSTRAP_DIR/$NODE_ARCHIVE" -C "$BOOTSTRAP_DIR"
install -m 755 \
    "$BOOTSTRAP_DIR/node-v$NODE_VERSION-darwin-arm64/bin/node" \
    "$TOOLS_DIR/node"

echo "[3/3] Bundling FFmpeg"
if [[ -z "${FFMPEG_SOURCE:-}" || -z "${FFPROBE_SOURCE:-}" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew FFmpeg is required. Install it with: brew install ffmpeg" >&2
        exit 1
    fi
    if ! brew list --versions ffmpeg >/dev/null 2>&1; then
        echo "Homebrew FFmpeg is required. Install it with: brew install ffmpeg" >&2
        exit 1
    fi
    export FFMPEG_SOURCE="$(brew --prefix ffmpeg)/bin/ffmpeg"
    export FFPROBE_SOURCE="$(brew --prefix ffmpeg)/bin/ffprobe"
fi
"$PROJECT_DIR/scripts/bundle_ffmpeg.sh"

"$TOOLS_DIR/yt-dlp" --version
"$TOOLS_DIR/node" --version
echo "Toolchain prepared in $TOOLS_DIR"
