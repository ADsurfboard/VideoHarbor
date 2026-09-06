#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/Resources/Tools"
WORK_DIR="$PROJECT_DIR/work"
YT_DLP_VERSION="2026.07.04"
NODE_VERSION="24.16.0"
MINIMUM_FREE_KB=1048576

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Bundled release tools currently require an Apple Silicon Mac." >&2
    exit 1
fi

for command_name in awk codesign curl file grep install install_name_tool otool python3 shasum tar tr; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
done

available_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR == 2 { print $4 }')"
if [[ ! "$available_kb" =~ ^[0-9]+$ ]] || (( available_kb < MINIMUM_FREE_KB )); then
    echo "At least 1 GiB of free disk space is required to prepare the toolchain." >&2
    exit 1
fi

mkdir -p "$TOOLS_DIR" "$WORK_DIR"
BOOTSTRAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/videoharbor-bootstrap.XXXXXX")"
TOOLS_STAGE="$(mktemp -d "$WORK_DIR/tools-staging.XXXXXX")"
TOOLS_BACKUP=""

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if (( status != 0 )) && [[ -n "$TOOLS_BACKUP" && -e "$TOOLS_BACKUP" && ! -e "$TOOLS_DIR" ]]; then
        mv "$TOOLS_BACKUP" "$TOOLS_DIR"
        echo "Toolchain update failed; restored the previous tools." >&2
    fi

    rm -rf -- "$BOOTSTRAP_DIR"
    if [[ -n "$TOOLS_STAGE" && -e "$TOOLS_STAGE" ]]; then
        rm -rf -- "$TOOLS_STAGE"
    fi
    if [[ -n "$TOOLS_BACKUP" && -e "$TOOLS_BACKUP" ]]; then
        rm -rf -- "$TOOLS_BACKUP"
    fi
    exit "$status"
}
trap cleanup EXIT INT TERM

# Preserve repository-owned documentation or future non-generated files while
# replacing only the generated toolchain as one verified unit.
cp -R "$TOOLS_DIR/." "$TOOLS_STAGE/"
for generated_entry in ffmpeg ffprobe lib node yt-dlp; do
    if [[ -e "$TOOLS_STAGE/$generated_entry" ]]; then
        rm -rf -- "$TOOLS_STAGE/$generated_entry"
    fi
done

CURL_OPTIONS=(
    --fail
    --location
    --retry 2
    --retry-all-errors
    --retry-max-time 600
    --connect-timeout 12
    --speed-limit 1024
    --speed-time 30
    --max-time 600
)

download_url() {
    local label="$1"
    local url="$2"
    local output="$3"
    echo "Downloading $label"
    curl "${CURL_OPTIONS[@]}" "$url" --output "$output"
}

download_github_asset() {
    local label="$1"
    local asset_id="$2"
    local output="$3"
    echo "Downloading $label through the GitHub API"
    curl "${CURL_OPTIONS[@]}" \
        --header 'Accept: application/octet-stream' \
        "https://api.github.com/repos/yt-dlp/yt-dlp/releases/assets/$asset_id" \
        --output "$output"
}

install_verified_local_file() {
    local label="$1"
    local source_path="$2"
    local expected_sha256="$3"
    local output="$4"
    local actual_sha256
    local normalized_expected

    if [[ ! -f "$source_path" ]]; then
        echo "$label source does not exist: $source_path" >&2
        exit 1
    fi
    if [[ ! "$expected_sha256" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "$label local reuse requires an explicit 64-character SHA-256." >&2
        exit 1
    fi

    actual_sha256="$(shasum -a 256 "$source_path" | awk '{ print $1 }')"
    normalized_expected="$(printf '%s' "$expected_sha256" | tr '[:upper:]' '[:lower:]')"
    if [[ "$actual_sha256" != "$normalized_expected" ]]; then
        echo "$label SHA-256 mismatch." >&2
        exit 1
    fi
    install -m 755 "$source_path" "$output"
}

echo "[1/3] Fetching yt-dlp $YT_DLP_VERSION"
if [[ -n "${YT_DLP_SOURCE:-}" ]]; then
    echo "Reusing a locally supplied yt-dlp after SHA-256 verification"
    install_verified_local_file \
        "yt-dlp" \
        "$YT_DLP_SOURCE" \
        "${YT_DLP_SHA256:-}" \
        "$TOOLS_STAGE/yt-dlp"
else
    YT_DLP_RELEASE_JSON="$BOOTSTRAP_DIR/yt-dlp-release.json"
    download_url \
        "yt-dlp release metadata" \
        "https://api.github.com/repos/yt-dlp/yt-dlp/releases/tags/$YT_DLP_VERSION" \
        "$YT_DLP_RELEASE_JSON"
    asset_ids="$(python3 - "$YT_DLP_RELEASE_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    release = json.load(handle)
assets = {asset["name"]: asset["id"] for asset in release.get("assets", [])}
required = ("yt-dlp_macos", "SHA2-256SUMS")
missing = [name for name in required if name not in assets]
if missing:
    raise SystemExit("Missing release assets: " + ", ".join(missing))
print(assets["yt-dlp_macos"], assets["SHA2-256SUMS"])
PY
)"
    read -r yt_dlp_asset_id yt_dlp_sums_id <<< "$asset_ids"
    YT_DLP_ASSET="$BOOTSTRAP_DIR/yt-dlp_macos"
    YT_DLP_SUMS="$BOOTSTRAP_DIR/SHA2-256SUMS"
    download_github_asset "yt-dlp_macos" "$yt_dlp_asset_id" "$YT_DLP_ASSET"
    download_github_asset "yt-dlp checksums" "$yt_dlp_sums_id" "$YT_DLP_SUMS"
    (
        cd "$BOOTSTRAP_DIR"
        grep ' yt-dlp_macos$' "$(basename "$YT_DLP_SUMS")" | shasum -a 256 -c -
    )
    install -m 755 "$YT_DLP_ASSET" "$TOOLS_STAGE/yt-dlp"
fi

echo "[2/3] Fetching Node.js $NODE_VERSION"
if [[ -n "${NODE_SOURCE:-}" ]]; then
    echo "Reusing a locally supplied Node.js binary after SHA-256 verification"
    install_verified_local_file \
        "Node.js" \
        "$NODE_SOURCE" \
        "${NODE_SHA256:-}" \
        "$TOOLS_STAGE/node"
else
    NODE_ARCHIVE="node-v$NODE_VERSION-darwin-arm64.tar.gz"
    NODE_BASE_URL="https://nodejs.org/dist/v$NODE_VERSION"
    download_url "Node.js" "$NODE_BASE_URL/$NODE_ARCHIVE" "$BOOTSTRAP_DIR/$NODE_ARCHIVE"
    download_url "Node.js checksums" "$NODE_BASE_URL/SHASUMS256.txt" "$BOOTSTRAP_DIR/node-SHASUMS256.txt"
    (
        cd "$BOOTSTRAP_DIR"
        grep " $NODE_ARCHIVE\$" node-SHASUMS256.txt | shasum -a 256 -c -
    )
    tar -xzf "$BOOTSTRAP_DIR/$NODE_ARCHIVE" \
        -C "$BOOTSTRAP_DIR" \
        "node-v$NODE_VERSION-darwin-arm64/bin/node"
    install -m 755 \
        "$BOOTSTRAP_DIR/node-v$NODE_VERSION-darwin-arm64/bin/node" \
        "$TOOLS_STAGE/node"
fi

echo "[3/3] Bundling FFmpeg"
if [[ -z "${FFMPEG_SOURCE:-}" || -z "${FFPROBE_SOURCE:-}" ]]; then
    if ! command -v brew >/dev/null 2>&1 || ! brew list --versions ffmpeg >/dev/null 2>&1; then
        echo "Homebrew FFmpeg is required. Install it with: brew install ffmpeg" >&2
        exit 1
    fi
    export FFMPEG_SOURCE="$(brew --prefix ffmpeg)/bin/ffmpeg"
    export FFPROBE_SOURCE="$(brew --prefix ffmpeg)/bin/ffprobe"
fi
TOOLS_DIR_OVERRIDE="$TOOLS_STAGE" "$PROJECT_DIR/scripts/bundle_ffmpeg.sh"

while IFS= read -r -d '' binary; do
    if file -b "$binary" | grep -q 'Mach-O'; then
        if ! codesign --verify --strict "$binary" >/dev/null 2>&1; then
            codesign --force --sign - "$binary"
        fi
        codesign --verify --strict "$binary"
    fi
done < <(find "$TOOLS_STAGE" -type f -print0)

[[ "$($TOOLS_STAGE/yt-dlp --version)" == "$YT_DLP_VERSION" ]]
[[ "$($TOOLS_STAGE/node --version)" == "v$NODE_VERSION" ]]
"$TOOLS_STAGE/ffmpeg" -version >/dev/null
"$TOOLS_STAGE/ffprobe" -version >/dev/null

TOOLS_BACKUP="$WORK_DIR/tools-backup.$$.old"
mv "$TOOLS_DIR" "$TOOLS_BACKUP"
if ! mv "$TOOLS_STAGE" "$TOOLS_DIR"; then
    mv "$TOOLS_BACKUP" "$TOOLS_DIR"
    TOOLS_BACKUP=""
    exit 1
fi
TOOLS_STAGE=""
rm -rf -- "$TOOLS_BACKUP"
TOOLS_BACKUP=""

echo "Toolchain prepared and verified in $TOOLS_DIR"
