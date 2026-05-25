# Android Avatar Graphics Strategy

Last updated: 2026-05-24

## Goal

Keep Plawie's avatar visually rich while preventing the avatar layer from starving
OpenClaw Gateway, WebSocket pairing, chat streaming, and tool execution.

The important correction is this: the avatar asset is not the whole gateway
problem. The current risk is the composition stack around it: Flutter UI effects
over an Android WebView running WebGL.

## What World-Class Android Avatar Apps Usually Do

Production-grade avatar apps avoid treating a WebView as the long-term 3D engine
inside a heavy native UI stack. The common pattern is:

- Render avatars in a dedicated native graphics surface or engine.
- Keep Flutter/Android UI overlays simple above the 3D surface.
- Avoid live blur, opacity groups, and transform animations across the 3D surface.
- Compress and budget textures before runtime.
- Pause rendering when hidden and release graphics resources aggressively.

Reference points:

- Android's own advanced graphics guidance points developers to OpenGL ES through
  `GLSurfaceView` and `GLSurfaceView.Renderer` for high-performance 3D drawing:
  https://developer.android.com/develop/ui/views/graphics/opengl/about-opengl
- Flutter Platform Views have performance tradeoffs; hybrid composition gives
  good Android view fidelity, but Flutter FPS can suffer and platform views
  should not be treated like cheap Flutter widgets:
  https://docs.flutter.dev/platform-integration/android/platform-views
- Flutter explicitly warns that `saveLayer()` allocates an offscreen buffer and
  can disrupt mobile GPU throughput. Widgets such as opacity, clipping,
  filters, shadows, and shader effects can indirectly trigger those expensive
  paths:
  https://docs.flutter.dev/perf/best-practices
- Google Filament is a small, efficient real-time physically based renderer for
  Android with glTF loading support:
  https://github.com/google/filament
- Unity as a Library is a recognized route for embedding Unity-powered 3D/AR
  features inside Android apps, with lifecycle controls and important limits:
  https://docs.unity.cn/Manual/UnityasaLibrary-Android.html
- VRM is based on glTF 2.0 / GLB, so the long-term native path should treat VRM
  as a glTF-family asset with VRM extensions:
  https://vrm.dev/vrm/gltf/format/
- Avatar ecosystems such as Ready Player Me ship SDKs for Unity, Unreal, web,
  desktop, mobile, and VR, and expose avatar performance configuration:
  https://docs.readyplayer.me/ready-player-me/what-is-ready-player-me

## What Plawie Was Doing Wrong

Current architecture before this cleanup:

- VRM avatar rendered through Chromium WebView + WebGL.
- WebView was placed under Flutter glass panels using `BackdropFilter`.
- The platform view was wrapped in fade/scale transitions during avatar swaps.
- Chat bubbles and panel overlays also used live blur.
- Home/dashboard cards ran continuous animation controllers and aura painters.
- The global `NebulaBg` animation repeated even when it was just decorative.

That combination can multiply memory far beyond the VRM file size. A 20 MB VRM
can decode to roughly 100-140 MB of texture data, then WebView/WebGL, mipmaps,
Flutter offscreen layers, platform-view composition buffers, and blur saveLayers
can push graphics memory into multi-GB territory.

Measured examples from local asset inspection:

- `assets/vrm/gemini.vrm`: about 18 MB file, about 108 MB decoded RGBA texture
  payload for one copy.
- `assets/vrm/cloud_vrms/gemini-pink.vrm`: about 20 MB file, about 140 MB
  decoded RGBA texture payload for one copy.
- The problem appears when that texture payload is multiplied by WebView and
  Flutter composition buffers, not from the VRM file alone.

## Immediate Android Runtime Contract

For the current Flutter + WebView bridge:

- Keep full-quality avatar assets.
- Do not place live `BackdropFilter` blur over Android WebView/PlatformView
  avatar surfaces.
- Do not animate Android PlatformViews with fade/scale transitions.
- Cap WebGL backbuffer DPR and frame rate to prevent uncontrolled render target
  growth.
- Stop decorative always-running home animations on Android.
- Keep the chat and home glass look through tint, gradients, borders, and static
  shadows instead of live blur.

## Long-Term Best Path

Preferred production direction:

1. Native Filament avatar renderer.
2. Load VRM as GLB/glTF plus VRM extension handling.
3. Use Android `SurfaceView`/`TextureView` and expose a small Flutter platform
   channel for avatar commands: load avatar, set expression, play gesture,
   speech intensity, pause/resume.
4. Keep Flutter responsible for chat UI and controls only.

Alternative if speed-to-feature-complete VRM support matters more than binary
size:

1. Unity as a Library.
2. UniVRM for VRM import/runtime animation.
3. One Unity runtime instance only.
4. Strict lifecycle management to load/unload scenes when leaving chat.

## Release Checklist

- Chat open should not push app graphics memory into multi-GB territory.
- Returning to home should pause/release avatar rendering.
- Avatar should remain crisp; no deliberately degraded/grainy fallback should be
  enabled by default.
- OpenClaw Gateway health checks should remain stable while chat is open.
- Chat should answer using cloud models without local NDK/Ollama memory pressure.
- Dashboard/home should not run decorative 60 FPS animations while idle.
