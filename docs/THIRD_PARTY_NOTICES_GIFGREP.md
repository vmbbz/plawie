# Third-Party Notices: Gifgrep

OpenClaw bundles one APK-local Android arm64 `gifgrep` executable for local GIF
inspection under the `android-vision-media-runtime` lane.

```text
component: gifgrep
source: https://github.com/steipete/gifgrep
source commit: 72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc
payload: assets/openclaw/vision-media/bin/gifgrep
payload sha256: 5fcd1be3ddd9b7708dfb0a29f1fdfdb33ff5fe9bca242089998bfcaf998b3691
license: MIT License
```

The payload is built from source using
`scripts/vision_media/build_gifgrep_android_arm64.ps1`.

Gifgrep's direct Go dependencies at this pinned commit are:

```text
github.com/alecthomas/kong v1.15.0
github.com/mattn/go-runewidth v0.0.23
github.com/mattn/go-sixel v0.0.9
golang.org/x/term v0.42.0
```

## MIT License

```text
Copyright (c) 2026 Peter Steinberger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Release packaging must keep this notice and
`docs/ANDROID_VISION_MEDIA_GIFGREP_PAYLOAD.md` with the app's third-party
notices or source/provenance materials.
