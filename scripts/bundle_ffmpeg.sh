#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/Resources/Tools"
LIB_DIR="$TOOLS_DIR/lib"
FFMPEG_SOURCE="${FFMPEG_SOURCE:-/opt/homebrew/bin/ffmpeg}"
FFPROBE_SOURCE="${FFPROBE_SOURCE:-/opt/homebrew/bin/ffprobe}"

if [[ ! -x "$FFMPEG_SOURCE" || ! -x "$FFPROBE_SOURCE" ]]; then
    echo "ffmpeg or ffprobe source is missing" >&2
    exit 1
fi

mkdir -p "$TOOLS_DIR" "$LIB_DIR"
cp -L "$FFMPEG_SOURCE" "$TOOLS_DIR/ffmpeg"
cp -L "$FFPROBE_SOURCE" "$TOOLS_DIR/ffprobe"
chmod +x "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe"

queue=("$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe")
seen="|$TOOLS_DIR/ffmpeg|$TOOLS_DIR/ffprobe|"
index=0

while [[ $index -lt ${#queue[@]} ]]; do
    file="${queue[$index]}"
    index=$((index + 1))

    while IFS= read -r dependency; do
        [[ -n "$dependency" ]] || continue
        basename="$(basename "$dependency")"
        destination="$LIB_DIR/$basename"
        if [[ ! -f "$destination" ]]; then
            cp -L "$dependency" "$destination"
            chmod u+w "$destination"
        fi

        if [[ "$file" == "$LIB_DIR"/* ]]; then
            replacement="@loader_path/$basename"
        else
            replacement="@loader_path/lib/$basename"
        fi
        install_name_tool -change "$dependency" "$replacement" "$file"

        if [[ "$seen" != *"|$destination|"* ]]; then
            queue+=("$destination")
            seen="${seen}${destination}|"
        fi
    done < <(otool -L "$file" | tail -n +2 | awk '{print $1}' | grep '^/opt/homebrew/' || true)

    if [[ "$file" == "$LIB_DIR"/* ]]; then
        install_name_tool -id "@loader_path/$(basename "$file")" "$file" 2>/dev/null || true
    fi
done

for file in "${queue[@]}"; do
    if otool -L "$file" | grep -q '^\s*/opt/homebrew/'; then
        echo "Unresolved Homebrew dependency: $file" >&2
        otool -L "$file" >&2
        exit 1
    fi
done

"$TOOLS_DIR/ffmpeg" -version | head -n 3
"$TOOLS_DIR/ffprobe" -version | head -n 1
echo "Bundled ${#queue[@]} ffmpeg files"
