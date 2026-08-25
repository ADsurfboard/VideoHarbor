# Third-Party Notices

VideoHarbor release builds may include or invoke the following third-party tools.
Prebuilt copies are intentionally excluded from the source repository and can be
prepared with `scripts/bootstrap_tools.sh`:

- **yt-dlp 2026.07.04** — The Unlicense, with bundled Python dependencies under their respective licenses. Source: <https://github.com/yt-dlp/yt-dlp>.
- **FFmpeg 8.1.2 (Homebrew build)** — GPLv3 configuration with optional codec libraries. Source and build recipe: <https://github.com/Homebrew/homebrew-core/tree/master/Formula/f/ffmpeg.rb>. Full corresponding upstream source: <https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz>.
- **Node.js 24.16.0** — MIT license and bundled third-party notices. Source: <https://github.com/nodejs/node/tree/v24.16.0>.

VideoHarbor itself does not alter these tools' site extractors, media codecs, or
networking behavior. Each generated binary remains covered by its upstream
license. The exact FFmpeg build configuration is available from `ffmpeg -version`
in the app's Toolchain page or embedded binary.
