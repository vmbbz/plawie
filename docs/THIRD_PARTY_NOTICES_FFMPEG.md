# Third-Party Notices: FFmpeg

OpenClaw bundles one APK-local FFmpeg executable for Android video frame
extraction.

```text
component: FFmpeg
version: 8.1.1
source: https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz
source sha256: b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
payload: assets/openclaw/vision-media/bin/ffmpeg
payload sha256: 5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
license mode: LGPL-only build
```

The payload is built from official FFmpeg source using
`scripts/vision_media/build_ffmpeg_android_arm64.sh`.

The build intentionally disables GPL and nonfree features:

```text
--disable-gpl
--disable-nonfree
```

No external codec libraries are enabled. The executable is used only as a
separate command-line process to extract JPEG frames from app-owned video files.

For FFmpeg licensing details, source code, and the full license texts, refer to:

- https://ffmpeg.org/legal.html
- https://ffmpeg.org/download.html

Release packaging must keep this notice and
`docs/ANDROID_VISION_MEDIA_FFMPEG_PAYLOAD.md` with the app's third-party notices
or source/provenance materials.
