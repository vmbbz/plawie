# Third-Party Notices: Songsee

OpenClaw bundles one APK-local Android arm64 `songsee` executable for audio
visualization under the `android-audio-runtime` lane.

```text
component: songsee
source: https://github.com/steipete/songsee
source commit: 41d27ea22771ba447bdfb8b6adac2e6599601634
payload: assets/openclaw/audio-runtime/bin/songsee
payload sha256: 98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
license: MIT License
```

The payload is built from source using
`scripts/audio_runtime/build_songsee_android_arm64.ps1`.

Songsee's direct Go dependencies at this pinned commit are:

```text
github.com/alecthomas/kong v1.15.0
github.com/hajimehoshi/go-mp3 v0.3.4
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
`docs/ANDROID_AUDIO_RUNTIME_SONGSEE_PAYLOAD.md` with the app's third-party
notices or source/provenance materials.
