# Android Vision Media FFmpeg Payload

This document records the provenance for the APK-local
`android-vision-media-runtime` FFmpeg payload used by `video-frames`.

## Payload

```text
binary: assets/openclaw/vision-media/bin/ffmpeg
payload bytes: 3287176
payload sha256: 5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
verified format: ELF64 little-endian AArch64
runtime lane: android-vision-media-runtime
provided binary: ffmpeg
```

## Source

```text
project: FFmpeg 8.1.1
source url: https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz
source sha256: b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
source signature: https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz.asc
```

## Build

```text
script: scripts/vision_media/build_ffmpeg_android_arm64.sh
host: WSL2 Ubuntu 24.04.2 LTS
Android NDK: /home/cosyc/.plawie/android/android-ndk-r28c
Android API: 29
target: aarch64-linux-android
license mode: LGPL-only
external libraries: none
programs: ffmpeg only
```

The build script configures FFmpeg with:

```text
--target-os=android
--arch=aarch64
--cpu=armv8-a
--enable-cross-compile
--disable-autodetect
--disable-gpl
--disable-nonfree
--disable-iconv
--disable-doc
--disable-debug
--disable-ffplay
--disable-ffprobe
--disable-network
--disable-everything
--enable-avcodec
--enable-avformat
--enable-avfilter
--enable-swscale
--enable-swresample
--enable-ffmpeg
--enable-protocol=file
--enable-demuxer=mov
--enable-demuxer=matroska
--enable-demuxer=avi
--enable-muxer=image2
--enable-decoder=h264
--enable-decoder=hevc
--enable-decoder=mpeg4
--enable-decoder=mjpeg
--enable-parser=h264
--enable-parser=hevc
--enable-parser=mpeg4video
--enable-parser=mjpeg
--enable-encoder=mjpeg
--enable-filter=fps
--enable-filter=scale
--enable-filter=format
--enable-small
```

Build command:

```bash
ANDROID_NDK_HOME="$HOME/.plawie/android/android-ndk-r28c" \
  PLAWIE_ALLOW_NETWORK=1 \
  INSTALL_ASSET=1 \
  JOBS=4 \
  bash ./scripts/vision_media/build_ffmpeg_android_arm64.sh
```

The helper refuses network download unless `PLAWIE_ALLOW_NETWORK=1` is set,
verifies the source tarball SHA-256 before extraction, and verifies the final
payload is ELF64 little-endian AArch64 before installing into the APK asset
lane.

## License Posture

This payload is built in LGPL mode:

- `--disable-gpl`
- `--disable-nonfree`
- no external libraries
- no `x264`, `x265`, `fdk-aac`, or other GPL/nonfree codec libraries

The payload is distributed as a separate executable, not linked into Flutter or
the Android app process. Preserve the FFmpeg license notices in
`docs/THIRD_PARTY_NOTICES_FFMPEG.md` and keep this source/build recipe available
with the release.

## Device Smoke Evidence

Verified on 2026-06-09 against device `RZCX30KA9AW` / Samsung `SM-A556E`
after debug APK reinstall with data preserved:

```text
provisioning/bin/ffmpeg bytes: 3287176
managed .openclaw/bin/ffmpeg bytes: 3287176
managed .openclaw/bin/ffmpeg sha256:
5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e

ffmpeg -version: exit 0, FFmpeg 8.1.1
tiny mpeg4 MP4 -> frame_001.jpg: 1740 bytes
JPEG header: ff d8 ff

/device/health video-frames:
runtimeStatus: ready
provisioningStatus: ready
ready: true

/device/health gifgrep at this FFmpeg-only checkpoint:
ready: false
provisioningStatus: missing_binary
dependencyGateMessage: No Native dependency pack advertises binary "gifgrep" for arm64-v8a.
```

Later Phase 5K added a separate real `gifgrep` payload under the same
vision-media lane. This FFmpeg payload still does not satisfy `gifgrep`; the
new `gifgrep` binary does.

## Required Release Smokes

Before moving release counts, prove on a freshly installed APK:

```text
.openclaw/bin/ffmpeg -version
video-frames tiny MP4 fixture -> at least one JPEG frame
/device/health: video-frames ready
/device/health: gifgrep ready only when the separate gifgrep payload is bundled
```

These checks passed on the debug APK smoke above. Repeat them for the signed
release APK before store submission.
