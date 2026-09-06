#!/bin/bash

set -u

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_MODE=false
errors=0
warnings=0

if [[ "${1:-}" == "--release" ]]; then
    RELEASE_MODE=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--release]" >&2
    exit 2
fi

pass() {
    printf 'PASS  %s\n' "$1"
}

warn() {
    printf 'WARN  %s\n' "$1"
    warnings=$((warnings + 1))
}

fail() {
    printf 'FAIL  %s\n' "$1"
    errors=$((errors + 1))
}

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
    pass "Apple Silicon macOS"
else
    fail "VideoHarbor release builds currently require Apple Silicon macOS"
fi

required_commands=(awk bash codesign curl file grep iconutil install install_name_tool otool plutil python3 shasum sips swift swiftc tar tr xcrun)
for command_name in "${required_commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
        pass "$command_name is available"
    else
        fail "missing command: $command_name"
    fi
done

if sdk_version="$(xcrun --show-sdk-version 2>/dev/null)"; then
    sdk_major="${sdk_version%%.*}"
    if [[ "$sdk_major" =~ ^[0-9]+$ ]] && (( sdk_major >= 26 )); then
        pass "macOS SDK $sdk_version can build the full GUI"
    else
        warn "macOS SDK $sdk_version can test Core, but the full GUI needs SDK 26 or newer"
    fi
else
    fail "unable to locate the active macOS SDK"
fi

scripts_valid=true
for shell_script in "$PROJECT_DIR/build.sh" "$PROJECT_DIR/run.sh" "$PROJECT_DIR/test.sh" "$PROJECT_DIR"/scripts/*.sh; do
    if ! bash -n "$shell_script"; then
        scripts_valid=false
    fi
done
if [[ "$scripts_valid" == true ]]; then
    pass "release scripts have valid shell syntax"
else
    fail "one or more release scripts have invalid shell syntax"
fi

if plutil -lint "$PROJECT_DIR/Resources/Info.plist" >/dev/null; then
    pass "Resources/Info.plist is valid"
else
    fail "Resources/Info.plist is invalid"
fi

available_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR == 2 { print $4 }')"
if [[ "$available_kb" =~ ^[0-9]+$ ]] && (( available_kb >= 1048576 )); then
    pass "at least 1 GiB of disk space is available"
else
    fail "less than 1 GiB of disk space is available"
fi

if command -v brew >/dev/null 2>&1 && brew list --versions ffmpeg >/dev/null 2>&1; then
    pass "Homebrew FFmpeg is installed"
elif [[ "$RELEASE_MODE" == true ]]; then
    fail "Homebrew FFmpeg is required to prepare a release toolchain"
else
    warn "Homebrew FFmpeg is only required for a self-contained release build"
fi

toolchain_complete=true
for tool_name in yt-dlp ffmpeg ffprobe node; do
    if [[ ! -x "$PROJECT_DIR/Resources/Tools/$tool_name" ]]; then
        toolchain_complete=false
    fi
done

if [[ "$toolchain_complete" == true ]]; then
    if "$PROJECT_DIR/Resources/Tools/yt-dlp" --version >/dev/null 2>&1 \
        && "$PROJECT_DIR/Resources/Tools/node" --version >/dev/null 2>&1 \
        && "$PROJECT_DIR/Resources/Tools/ffmpeg" -version >/dev/null 2>&1 \
        && "$PROJECT_DIR/Resources/Tools/ffprobe" -version >/dev/null 2>&1; then
        pass "bundled release toolchain starts successfully"
    else
        fail "one or more bundled release tools cannot start"
    fi
elif [[ "$RELEASE_MODE" == true ]]; then
    fail "bundled tools are missing; run ./scripts/bootstrap_tools.sh"
else
    warn "bundled tools are absent; Core development can continue"
fi

printf '\nDoctor result: %d error(s), %d warning(s)\n' "$errors" "$warnings"
(( errors == 0 ))
